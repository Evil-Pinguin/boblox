--[[
	Round - the director.

 Owns the phase machine (intermission -> ingress -> active -> resolving), every
 player's run state, the objective loop, the hide/eject logic and the attribute
 pipeline the HUD reads. Entity.lua answers to this; nothing else talks to players.

 Design note: the *server* owns flashlight battery, stamina and lives. The client
 only renders them. That keeps the Hollow's behaviour (which reacts to your beam)
 honest, and means a curious exploiter cannot simply switch their light off
 server-side and walk around invisible.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

--[[ Shared modules live in ReplicatedStorage.Blacksite. Addressed through the service rather
     than script.Parent.Parent, because these folders are siblings, not ancestors. ]]
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Blacksite")
local Config = require(shared:WaitForChild("Config"))
local Attributes = require(shared:WaitForChild("Attributes"))
local Remotes = require(shared:WaitForChild("Remotes"))
local Util = require(shared:WaitForChild("Util"))
local MazeGen = require(shared:WaitForChild("MazeGen"))

local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local Entity = require(script.Parent:WaitForChild("Entity"))

local Round = {}
Round.__index = Round

Round.Phase = {
	Intermission = "intermission",
	Ingress = "ingress",
	Active = "active",
	Resolving = "resolving",
}

local Think = 1 / 20
local MAX_DT = 0.1

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------

--- deps = { root = Folder, remotes = Remotes, lobby = buildLobby result }
function Round.new(deps)
	local self = setmetatable({}, Round)
	self.root = deps.root
	self.remotes = deps.remotes
	self.lobby = deps.lobby

	self.phase = Round.Phase.Intermission
	self.phaseTime = 0
	self.now = 0
	self.countdown = Config.Round.Intermission
	self.seedSeq = MazeGen.hashString(Config.Meta.SeedSalt) % 100000
	self.players = {}
	self.spawnCursor = 0
	self.thinkIn = 0
	self.publishIn = 0
	self.boardIn = 0
	self.statIn = 0

	-- Players already in the room when the script starts have missed PlayerAdded.
	for _, player in ipairs(Players:GetPlayers()) do
		self:attach(player)
	end

	self.cellsFound = 0
	self.cellsNeeded = Config.Round.CellsNeeded
	self.timeLeft = Config.Round.Limit
	self.gateOpen = false
	self.purging = false
	self.livesLost = 0
	self.result = nil
	self.level = nil
	self.entity = nil

	self.stats = { rounds = 0, escapes = 0, deaths = 0, best = nil, cells = 0 }

	self.root:SetAttribute("Phase", self.phase)
	self.root:SetAttribute("Countdown", self.countdown)
	self.root:SetAttribute("CellsFound", 0)
	self.root:SetAttribute("CellsNeeded", self.cellsNeeded)
	self.root:SetAttribute("TimeLeft", self.timeLeft)
	self.root:SetAttribute("GateOpen", false)
	self.root:SetAttribute("Purge", false)
	self.root:SetAttribute("Alive", 0)
	self.root:SetAttribute("Escaped", 0)
	self.root:SetAttribute("Waiting", 0)
	self.root:SetAttribute("Result", "")

	self:connectPrompts()
	return self
end

function Round:connectPrompts()
	-- One server-side connection for every prompt the level spawns, present and future.
	ProximityPromptService.PromptTriggered:Connect(function(player, prompt)
		self:onPrompt(player, prompt, "trigger")
	end)

	-- Holding a prompt should be loud: it is the moment the run gets decided.
	local ok = pcall(function()
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(player, prompt)
			self:onPrompt(player, prompt, "hold")
		end)
	end)
	self.holdsSupported = ok
end

---------------------------------------------------------------------------
-- player bookkeeping
---------------------------------------------------------------------------

function Round:attach(player)
	if self.players[player] then
		return self.players[player]
	end

	local self2 = self
	local st = {
		player = player,
		joined = false,
		alive = true,
		escaped = false,
		eliminated = false,
		lives = Config.Player.Lives,
		battery = Config.Player.BatteryMax,
		stamina = Config.Player.StaminaMax,
		flashOn = false,
		wantSprint = false,
		wantCrouch = false,
		sprintLock = 0,
		dread = 0,
		found = 0,
		speed = 0,
		mode = "still",
		noiseIn = 0,
		pos = Vector3.zero,
		look = Vector3.new(0, 0, -1),
		tx = 1,
		ty = 1,
		dist = nil,
		seen = false,
		atDoor = false,
		hiddenLock = nil,
		character = nil,
		humanoid = nil,
		root = nil,
		invulnUntil = 0,
		contributed = 0,
		grabs = 0,
		timeIn = 0,
		cellsSpawned = 0,
	}
	self.players[player] = st

	st.addedConn = player.CharacterAdded:Connect(function(char)
		self:onCharacter(player, st, char)
	end)
	st.removingConn = player.CharacterRemoving:Connect(function()
		self:onCharacter(player, st, nil)
	end)
	if player.Character then
		self:onCharacter(player, st, player.Character)
	end

	self:publish(st, true)
	self:refreshLobby()
	return st
end

function Round:detach(player)
	local st = self.players[player]
	if not st then
		return
	end
	if st.hiddenLock then
		st.hiddenLock.occupied = nil
	end
	if st.addedConn then
		st.addedConn:Disconnect()
	end
	if st.diedConn then
		st.diedConn:Disconnect()
	end
	if st.removingConn then
		st.removingConn:Disconnect()
	end
	self.players[player] = nil
	self:refreshLobby()
end

function Round:eachPlayer()
	return pairs(self.players)
end

function Round:participantCount()
	local n = 0
	for _ in pairs(self.players) do
		n = n + 1
	end
	return n
end

--- LoadCharacter yields, so never call it inline from the Heartbeat thread.
function Round:loadCharacter(player)
	task.spawn(function()
		local ok, err = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			-- LoadCharacter also raises CharacterAdded, so a silent pcall here would
			-- hide any fault in the spawn path as a player standing in a void.
			warn("[Blacksite] could not redeploy " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

function Round:joinedCount()
	local n = 0
	for _, st in pairs(self.players) do
		if st.joined then
			n = n + 1
		end
	end
	return n
end

function Round:nextSpawn()
	self.spawnCursor = self.spawnCursor % 8 + 1
	return self.spawnCursor
end

--- The old rig is gone (CharacterRemoving, a leave, a reset). Drop every reference
--- to it so no tick tries to drive a destroyed character.
function Round:clearCharacter(st)
	if st.diedConn then
		st.diedConn:Disconnect()
		st.diedConn = nil
	end
	if st.hiddenLock then
		st.hiddenLock.occupied = nil
		st.hiddenLock = nil
	end
	st.character = nil
	st.humanoid = nil
	st.root = nil
	st.dist = nil
	st.seen = false
	st.atDoor = false
end

function Round:onCharacter(player, st, char)
	if not char then
		-- CharacterRemoving fires right before the respawn, so a nil character here is
		-- routine and not an error.
		self:clearCharacter(st)
		return
	end
	st.character = char
	local humanoid = char:WaitForChild("Humanoid", 6)
	if not humanoid then
		return
	end
	st.humanoid = humanoid
	st.root = char:WaitForChild("HumanoidRootPart", 6)

	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.JumpPower = Config.Player.JumpEnabled and 50 or 0
	humanoid.UseJumpPower = true
	pcall(function()
		humanoid.JumpHeight = Config.Player.JumpEnabled and 7 or 0
	end)

	if st.diedConn then
		st.diedConn:Disconnect()
	end
	local self2 = self
	st.diedConn = humanoid.Died:Connect(function()
		self2:onDied(player, st)
	end)

	st.alive = true
	self:applyMovement(st)
	if self.phase == Round.Phase.Intermission then
		st.needsDeploy = true
	end
	self:placeCharacter(player, st)
end

function Round:placeCharacter(player, st, forceLobby)
	local char = st.character
	if not char then
		return
	end
	local list, index
	local inMap = (self.phase == Round.Phase.Active or self.phase == Round.Phase.Ingress) and not forceLobby
	if inMap then
		if self.level then
			list = self.level.spawnCFs
		end
	else
		list = self.lobby and self.lobby.spawnCFs
	end
	-- A character that arrives before the phase flips cannot be placed in the map yet.
	-- needsDeploy stays set until one is actually put inside, so activate() can finish
	-- the job for anyone the async LoadCharacter left behind in the lift.
	index = self:nextSpawn()
	local cf
	if list and list[index] then
		cf = list[index]
	elseif inMap and self.level then
		cf = self.level.entryCFrame
	elseif self.lobby then
		cf = self.lobby.centre
	end
	if not cf then
		return
	end
	char:PivotTo(cf + Vector3.new(0, 0.5, 0))
	if inMap then
		st.needsDeploy = nil
		st.timeIn = self.now
	end
end

function Round:onDied(player, st)
	st.alive = false
	st.seen = false
	if st.hiddenLock then
		st.hiddenLock.occupied = nil
		st.hiddenLock = nil
		self:setCloak(st, false)
		st.found = 0
	end

	if st.escaped or self.phase ~= Round.Phase.Active then
		return
	end

	st.lives = st.lives - 1
	self.livesLost = self.livesLost + 1
	self.stats.deaths = self.stats.deaths + 1
	self:toast(player, "DRAGGED UNDER - " .. st.lives .. " RUNS LEFT", "bad")
	self:toastAll(Config.Entity.Name .. " TOOK " .. player.Name, "warn")

	if st.lives > 0 then
		local self2 = self
		task.delay(2.4, function()
			if st.lives > 0 and self2.phase == Round.Phase.Active and player.Parent then
				st.invulnUntil = self2.now + Config.Player.InvulnAfterGrab
				self2:loadCharacter(player)
				self2:toast(player, "PATCHED UP AT THE AIRLOCK", "good")
			end
		end)
	else
		st.eliminated = true
		self:toast(player, "YOU ARE PART OF THE SUBLEVEL NOW", "bad")
		self.remotes:toClient(player, "Fade", "black")
	end
end

function Round:setCloak(st, on)
	local char = st.character
	if not char then
		return
	end
	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") or inst:IsA("Decal") then
			inst.Transparency = on and 1 or (inst:IsA("BasePart") and 0 or 1)
		end
	end
end

--- Snap a world position onto the nearest walkable tile the grid knows about.
function Round:nearestWalkable(maze, gx, gy)
	if maze:walkable(gx, gy) then
		return gx, gy
	end
	for r = 1, 3 do
		for dy = -r, r do
			for dx = -r, r do
				if math.max(math.abs(dx), math.abs(dy)) == r then
					local nx, ny = gx + dx, gy + dy
					if maze:walkable(nx, ny) then
						return nx, ny
					end
				end
			end
		end
	end
	return gx, gy
end

---------------------------------------------------------------------------
-- client input
---------------------------------------------------------------------------

function Round:action(player, name, arg, arg2)
	local st = self.players[player]
	if not st then
		return
	end

	if name == Remotes.Actions.Join then
		st.joined = true
		if self.phase == Round.Phase.Active or self.phase == Round.Phase.Ingress then
			-- late join: drop them straight into the airlock
			st.eliminated = false
			st.lives = math.max(1, st.lives)
			st.escaped = false
			st.needsDeploy = true
			if not st.character or not st.character.Parent then
				self:loadCharacter(player)
			end
			self:placeCharacter(player, st)
		end
		self:refreshLobby()
		self:publish(st, true)
	elseif name == Remotes.Actions.Flash then
		if self.now - (st.flashT or 0) < 0.15 then
			return
		end
		st.flashT = self.now
		local want = not not arg
		if want and st.battery <= 0.5 then
			self:toast(player, "DEAD CELL - FIND A SPARE", "bad")
			return
		end
		if want and st.hiddenLock then
			return
		end
		st.flashOn = want
		if want then
			self:noise(st, Config.Noise.Locker * 0.8)
		end
		self:publish(st)
	elseif name == Remotes.Actions.Restart then
		st.joined = true
		st.lives = Config.Player.Lives
		st.escaped = false
		st.eliminated = false
		st.alive = true
		st.battery = Config.Player.BatteryMax
		st.stamina = Config.Player.StaminaMax
		self:placeCharacter(player, st)
		self:refreshLobby()
		self:publish(st, true)
	elseif name == Remotes.Actions.Move then
		local sprint = not not arg
		local crouch = not not arg2
		if st.wantSprint ~= sprint or st.wantCrouch ~= crouch then
			st.wantSprint = sprint
			st.wantCrouch = crouch
			self:applyMovement(st)
		end
	elseif name == "leave" then
		st.joined = false
		if st.hiddenLock then
			self:unhide(player, st, true)
		end
		self:placeCharacter(player, st, true)
		self:refreshLobby(true)
	end
end

function Round:applyMovement(st)
	local humanoid = st.humanoid
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local speed
	if st.hiddenLock then
		speed = 0
	elseif st.wantCrouch then
		speed = Config.Player.CrouchSpeed
	elseif st.wantSprint and st.stamina > Config.Player.MinSprintCost then
		speed = Config.Player.SprintSpeed
	else
		speed = Config.Player.WalkSpeed
	end
	st.appliedSpeed = speed
	humanoid.WalkSpeed = speed
end

---------------------------------------------------------------------------
-- prompts
---------------------------------------------------------------------------

function Round:onPrompt(player, promptObj, kind)
	if self.phase ~= Round.Phase.Active then
		return
	end
	local st = self.players[player]
	if not st or not st.alive or st.escaped then
		return
	end
	local level = self.level
	if not level then
		return
	end
	local entry = level.promptIndex and level.promptIndex[promptObj]
	if not entry then
		return
	end

	if entry.kind == "locker" then
		if kind == "trigger" then
			self:toggleLocker(player, st, entry.locker)
		end
		return
	end

	local pickup = entry
	if pickup.taken then
		return
	end
	if kind == "hold" then
		-- the noise happens while you struggle, not after: that is the whole game
		self:noise(st, Config.Noise.Interact)
		return
	end
	self:takePickup(player, st, pickup)
end

function Round:takePickup(player, st, pickup)
	self.level:takePickup(pickup)
	self:noise(st, Config.Noise.Interact * 0.7)

	if pickup.kind == "cell" then
		self.cellsFound = self.cellsFound + 1
		st.contributed = st.contributed + 1
		self.stats.cells = self.stats.cells + 1
		self:toastAll("CELL SECURED  " .. self.cellsFound .. "/" .. self.cellsNeeded, "good")
		if self.cellsFound >= self.cellsNeeded then
			self:openGate()
		end
	elseif pickup.kind == "battery" then
		st.battery = Util.clamp(st.battery + Config.Player.BatteryFromPickup, 0, Config.Player.BatteryMax)
		self:toast(player, "SPARE CELL  +" .. Config.Player.BatteryFromPickup .. "%", "good")
	elseif pickup.kind == "bandage" then
		if st.humanoid then
			st.humanoid.Health = math.min(st.humanoid.MaxHealth, st.humanoid.Health + 45)
		end
		self:toast(player, "BLEEDING STOPPED", "good")
	end
	self:publish(st)
end

function Round:openGate()
	self.gateOpen = true
	self.level:openGate()
	self.root:SetAttribute("GateOpen", true)
	self:toastAll(Config.Copy.Escaping, "good")
	self:scare(1.6, "gate")
	if self.entity then
		self.entity:enroll()
	end
end

---------------------------------------------------------------------------
-- lockers
---------------------------------------------------------------------------

function Round:toggleLocker(player, st, locker)
	if st.hiddenLock then
		self:unhide(player, st, false)
		return
	end
	if not st.alive or st.escaped then
		return
	end
	if locker.occupied and locker.occupied ~= player then
		self:toast(player, "SOMEONE IS IN THERE", "warn")
		return
	end
	self:hide(player, st, locker)
end

function Round:hide(player, st, locker)
	local char = st.character
	if not char or not locker.insideCF then
		return
	end

	st.hiddenLock = locker
	st.hiddenSince = self.now
	st.found = 0
	locker.occupied = player
	locker.prompt.ActionText = "LEAVE"
	locker.door.Transparency = 0.2

	if st.humanoid then
		st.humanoid.PlatformStand = true
	end
	char:PivotTo(locker.insideCF)
	self:setCloak(st, true)
	self:applyMovement(st)
	st.savedFlash = st.flashOn
	st.flashOn = false
	self:noise(st, Config.Noise.Locker)
	self:publish(st, true)
end

function Round:unhide(player, st, forced)
	local locker = st.hiddenLock
	if not locker then
		return
	end
	st.hiddenLock = nil
	locker.occupied = nil
	locker.prompt.ActionText = "HIDE"
	locker.door.Transparency = 0.55
	st.found = 0

	if st.humanoid then
		st.humanoid.PlatformStand = false
	end
	if st.character and locker.exitCF then
		st.character:PivotTo(locker.exitCF)
	end
	self:setCloak(st, false)
	self:applyMovement(st)
	if not forced and st.savedFlash and st.battery > 1 then
		st.flashOn = true
	end
	st.savedFlash = nil
	self:noise(st, Config.Noise.Locker)
	self:publish(st, true)
end

--- A Hollow standing at your locker door with a hunt running will tear it off.
function Round:houndLocks(dt)
	for player, st in self:eachPlayer() do
		if st.hiddenLock then
			local hunting = self.entity and self.entity.state == "hunt" and self.entity.targetPlayer == player
			if hunting and st.atDoor then
				st.found = Util.clamp(st.found + dt / Config.Entity.KickInTime, 0, 1)
				if st.found >= 1 then
					self:unhide(player, st, true)
					self:toast(player, "FOUND", "bad")
					if st.humanoid then
						st.humanoid:TakeDamage(20)
					end
					if self.entity then
						self.entity:beginFeed()
					end
				end
			else
				st.found = Util.clamp(st.found - dt * 0.5, 0, 1)
			end
		end
	end
end

---------------------------------------------------------------------------
-- phases
---------------------------------------------------------------------------

function Round:setPhase(nextPhase)
	self.phase = nextPhase
	self.phaseTime = 0
	self.root:SetAttribute("Phase", nextPhase)
end

function Round:begin()
	self.seedSeq = (self.seedSeq * 31 + 7919) % 2147483647
	self.level = MapBuilder.build(self.root, { seed = self.seedSeq })

	self.entity = Entity.new({ round = self, level = self.level, root = self.root })
	self.entity:setState("dormant")
	self.entity:reposition(22)

	self.cellsFound = 0
	self.cellsNeeded = math.max(1, #self.level.cells)
	self.timeLeft = Config.Round.Limit
	self.livesLost = 0
	self.gateOpen = false
	self.purging = false
	self.result = nil
	self.roundStart = self.now

	self.root:SetAttribute("CellsNeeded", self.cellsNeeded)
	self.root:SetAttribute("CellsFound", 0)
	self.root:SetAttribute("GateOpen", false)
	self.root:SetAttribute("Purge", false)
	self.root:SetAttribute("Result", "")

	local self2 = self
	self.padConn = self.level.pad.Touched:Connect(function(other)
		local model = other:FindFirstAncestorOfClass("Model")
		if not model then
			return
		end
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			self2:escape(player)
		end
	end)

	for player, st in self:eachPlayer() do
		if st.joined then
			st.lives = Config.Player.Lives
			st.escaped = false
			st.eliminated = false
			st.contributed = 0
			st.alive = true
			st.battery = Config.Player.BatteryMax
			st.stamina = Config.Player.StaminaMax
			st.flashOn = true
			st.found = 0
			st.invulnUntil = self.now + 3
			st.noiseIn = 0
			if not st.character or not st.character.Parent then
				self:loadCharacter(player)
			else
				self:setCloak(st, false)
				self:placeCharacter(player, st)
			end
		else
			self:placeCharacter(player, st, true)
		end
		self:publish(st, true)
	end

	self.stats.rounds = self.stats.rounds + 1
	self:setPhase(Round.Phase.Ingress)
	self.remotes:toAll("Fade", "black")
	self:toastAll(Config.Copy.Objective .. "  x" .. self.cellsNeeded, "info")
	self:refreshLobby()
end

function Round:activate()
	self:setPhase(Round.Phase.Active)

	-- Anyone whose body finished loading while the phase was still intermission was put
	-- in the staging lift by default. Deploy them before the Hollow starts hunting.
	for player, st in self:eachPlayer() do
		if st.joined and st.needsDeploy and st.alive and not st.escaped then
			self:placeCharacter(player, st)
		end
	end
	self.remotes:toAll("Fade", "clear")
	if self.entity then
		self.entity:setState("patrol")
	end
	for _, st in self:eachPlayer() do
		self:publish(st, true)
	end
end

function Round:update(dt)
	dt = math.min(dt, MAX_DT)
	self.now = self.now + dt
	self.phaseTime = self.phaseTime + dt

	local phase = self.phase

	if phase == Round.Phase.Intermission then
		self.countdown = self.countdown - dt
		if self.countdown <= 0 then
			if self:joinedCount() >= Config.Round.MinPlayerCount then
				self:begin()
			else
				self.countdown = 5
			end
		end
		self:refreshLobby()
		self:publishTick(dt)
		return
	end

	if phase == Round.Phase.Ingress then
		if self.level then
			self.level:tick(self.now)
		end
		if self.entity then
			self.entity:advance(dt)
		end
		if self.phaseTime >= Config.Round.Ingress then
			self:activate()
		end
		self:publishTick(dt)
		return
	end

	if phase == Round.Phase.Resolving then
		if self.level then
			self.level:tick(self.now)
		end
		if self.phaseTime >= Config.Round.ResolveTime then
			self:reset()
		end
		self:publishTick(dt)
		return
	end

	-- active
	if self.timeLeft > 0 then
		self.timeLeft = self.timeLeft - dt
		if not self.purging and self.timeLeft <= Config.Round.PurgeWarn then
			self:startPurge()
		end
		if self.timeLeft <= 0 then
			self:purge()
			return
		end
	end

	for player, st in self:eachPlayer() do
		self:updatePlayer(st, dt)
	end

	self.thinkIn = self.thinkIn - dt
	if self.entity then
		if self.thinkIn <= 0 then
			self.thinkIn = Think
			self.entity:tick(Think)
		end
		self.entity:advance(dt)
		self:houndLocks(dt)
	end

	if self.level then
		self.level:tick(self.now)
	end

	self:checkEnd()
	self:publishTick(dt)
end

function Round:updatePlayer(st, dt)
	local player = st.player
	local char = st.character
	if not player or not player.Parent then
		return
	end
	if not st.joined then
		-- still in staging, out of the Hollow's world entirely
		st.dread = 0
		st.alive = true
		return
	end
	if not char or not char.Parent then
		st.alive = false
		return
	end
	if st.escaped then
		return
	end

	st.timeIn = st.timeIn + dt

	local root = st.root or char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	st.root = root
	st.pos = root.Position
	local look = root.CFrame.LookVector
	local lx, lz = look.X, look.Z
	local lm = math.sqrt(lx * lx + lz * lz)
	if lm > 0.001 then
		st.look = Vector3.new(lx / lm, 0, lz / lm)
	end

	local gx, gy = self.level:tileOf(root.Position)
	gx, gy = self:nearestWalkable(self.level.maze, gx, gy)
	st.tx, st.ty = gx, gy

	local vel = root.AssemblyLinearVelocity
	st.speed = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)

	if st.hiddenLock then
		st.mode = "hidden"
	elseif st.speed > 20 then
		st.mode = "sprint"
	elseif st.speed > 11 then
		st.mode = "walk"
	elseif st.speed > 1.5 then
		st.mode = "crouch"
	else
		st.mode = "still"
	end

	-- What the Hollow can hear.
	if not st.hiddenLock then
		if st.mode == "sprint" then
			st.noiseIn = st.noiseIn - dt
			if st.noiseIn <= 0 then
				st.noiseIn = Config.Noise.JogLoop
				self:noise(st, Config.Noise.Sprint)
			end
		elseif st.mode == "walk" then
			st.noiseIn = st.noiseIn - dt
			if st.noiseIn <= 0 then
				st.noiseIn = 0.85
				self:noise(st, Config.Noise.Walk)
			end
		end
		if self.entity and self.entity.state == "hunt" then
			-- it is already on you; it does not need to hear you any more
			st.noiseIn = math.max(st.noiseIn, 0.2)
		end
	end

	-- Stamina.
	local moving = st.mode ~= "still"
	if st.hiddenLock then
		st.stamina = Util.clamp(st.stamina - Config.Player.HoldBreathDrain * dt, 0, Config.Player.StaminaMax)
	elseif st.mode == "sprint" and st.wantSprint then
		st.stamina = Util.clamp(st.stamina - Config.Player.StaminaDrain * dt, 0, Config.Player.StaminaMax)
		st.sprintLock = Config.Player.StaminaRecoverLock
	else
		st.sprintLock = math.max(0, st.sprintLock - dt)
		if st.sprintLock <= 0 then
			local bonus = st.mode == "crouch" and (1 + Config.Player.CrouchRegenBonus / 100) or 1
			st.stamina = Util.clamp(st.stamina + Config.Player.StaminaRegen * bonus * dt, 0, Config.Player.StaminaMax)
		end
	end

	-- Battery.
	if st.flashOn then
		st.battery = Util.clamp(st.battery - Config.Player.BatteryDrain * dt, 0, Config.Player.BatteryMax)
		if st.battery <= 0 then
			st.flashOn = false
			self:toast(player, "BATTERY DEAD - FIND A SPARE CELL", "bad")
		end
	end

	self:applyMovement(st)

	-- Being pinned inside a locker has to be re-asserted: Roblox physics is eager to
	-- push a character out of a shell it did not author.
	if st.hiddenLock then
		local locker = st.hiddenLock
		if not locker.occupied or locker.occupied ~= player then
			st.hiddenLock = nil
			self:setCloak(st, false)
			if st.humanoid then
				st.humanoid.PlatformStand = false
			end
			self:applyMovement(st)
		else
			local target = locker.insideCF
			if (root.Position - target.Position).Magnitude > 0.35 then
				char:PivotTo(target)
			end
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end

	-- Objective guidance: a bearing and a proximity read, so the maze is frightening
	-- but never unwinnable.
	local signalPos, signalLabel = self:objectiveFor(st)
	if signalPos then
		local to = signalPos - st.pos
		local right = st.look:Cross(Vector3.new(0, 1, 0))
		local ahead = st.look
		st.bearing = math.deg(math.atan2(to.X * right.X + to.Z * right.Z, to.X * ahead.X + to.Z * ahead.Z))
		local dist = math.sqrt(to.X * to.X + to.Z * to.Z)
		st.distance = dist
		st.signal = Util.clamp(1 - dist / 220, 0, 1)
		st.signalLabel = signalLabel
	else
		st.signal = 0
		st.distance = nil
	end

	self:safetyCheck(st)
end

function Round:objectiveFor(st)
	if self.gateOpen then
		return self.level.escapeCFrame.Position, "gate"
	end
	local best, bestDist
	for _, pickup in ipairs(self.level.cells) do
		if not pickup.taken and pickup.part then
			local d = (pickup.part.Position - st.pos).Magnitude
			if d < (bestDist or math.huge) then
				best, bestDist = pickup.part.Position, d
			end
		end
	end
	return best, "cell"
end

--- Falling out of the world should never be a way to lose a life.
function Round:safetyCheck(st)
	local pos = st.pos
	if not pos then
		return
	end
	local lobbyY = self.lobby and self.lobby.y or -120
	if pos.Y < lobbyY - 140 or pos.Y > Config.World.RoofHeight + 90 then
		self:placeCharacter(st.player, st)
	end
end

function Round:noise(st, radius)
	if self.entity and st.pos then
		self.entity:hear(st.pos, radius)
	end
end

function Round:startPurge()
	self.purging = true
	self.root:SetAttribute("Purge", true)
	if self.level then
		self.level:setPurge(true)
	end
	self:toastAll(string.format(Config.Copy.PurgeWarn, Util.formatTime(Config.Round.PurgeWarn)), "bad")
	self.remotes:toAll("Sound", "Alarm")
end

function Round:purge()
	for _, st in self:eachPlayer() do
		if not st.escaped and st.alive then
			st.eliminated = true
			st.alive = false
			if st.humanoid then
				st.humanoid.Health = 0
			end
		end
	end
	self:finish("purged")
end

function Round:escape(player)
	local st = self.players[player]
	if not st or st.escaped or not self.gateOpen or self.phase ~= Round.Phase.Active then
		return
	end
	if not st.alive or st.eliminated then
		return
	end
	st.escaped = true
	st.alive = false
	st.joined = true
	st.dread = 0
	if st.hiddenLock then
		self:unhide(player, st, true)
	end
	self.stats.escapes = self.stats.escapes + 1
	local elapsed = self.now - (self.roundStart or self.now)
	if self.stats.best == nil or elapsed < self.stats.best then
		self.stats.best = elapsed
	end
	self:placeCharacter(player, st, true)
	self:toastAll(player.Name .. " IS OUT", "good")
	self.remotes:toClient(player, "Fade", "white")
	self.remotes:toClient(player, "Result", {
		kind = "escaped",
		cells = st.contributed,
		lives = st.lives,
		time = math.floor(elapsed),
		rounds = self.stats.rounds,
	})
	self:publish(st, true)
	self:checkEnd()
end

function Round:checkEnd()
	if self.phase ~= Round.Phase.Active then
		return
	end
	local live, out = 0, 0
	for _, st in self:eachPlayer() do
		if st.joined then
			if st.escaped then
				out = out + 1
			elseif st.alive and not st.eliminated then
				live = live + 1
			end
		end
	end
	if live == 0 then
		self:finish(out > 0 and "partial" or "consumed")
	end
end

function Round:finish(kind)
	if self.phase ~= Round.Phase.Active then
		return
	end
	self.result = kind
	self.root:SetAttribute("Result", kind)
	self:setPhase(Round.Phase.Resolving)

	local escaped = 0
	local total = 0
	for _, st in self:eachPlayer() do
		if st.joined then
			total = total + 1
			if st.escaped then
				escaped = escaped + 1
			end
		end
		self.remotes:toClient(st.player, "Result", {
			kind = st.escaped and "escaped" or (st.eliminated and "consumed" or kind),
			cells = st.contributed,
			lives = st.lives,
			time = math.floor(st.timeIn),
			escaped = st.escaped,
			rounds = self.stats.rounds,
			best = self.stats.best,
		})
	end

	self:toastAll(kind == "purged" and "SUBLEVEL SEALED" or (escaped > 0 and "SIGNAL RECOVERED" or "NO SIGNAL"), escaped > 0 and "good" or "bad")
	self.remotes:toAll("Sound", escaped > 0 and "Win" or "Lose")
	self:refreshLobby()
end

function Round:reset()
	if self.padConn then
		self.padConn:Disconnect()
		self.padConn = nil
	end
	if self.entity then
		self.entity:destroy()
		self.entity = nil
	end
	if self.level then
		self.level:destroy()
		self.level = nil
	end

	for player, st in self:eachPlayer() do
		st.hiddenLock = nil
		st.escaped = false
		st.eliminated = false
		st.alive = true
		st.lives = Config.Player.Lives
		st.battery = Config.Player.BatteryMax
		st.stamina = Config.Player.StaminaMax
		st.flashOn = false
		st.dread = 0
		st.found = 0
		st.contributed = 0
		st.timeIn = 0
		if st.humanoid then
			pcall(function()
				st.humanoid.PlatformStand = false
			end)
		end
		self:setCloak(st, false)
		if not st.character or not st.character.Parent then
			self:loadCharacter(player)
		end
		self:placeCharacter(player, st)
		self:publish(st, true)
	end

	self.cellsFound = 0
	self.gateOpen = false
	self.purging = false
	self.countdown = Config.Round.Intermission
	self.root:SetAttribute("CellsFound", 0)
	self.root:SetAttribute("GateOpen", false)
	self.root:SetAttribute("Purge", false)
	self:setPhase(Round.Phase.Intermission)
	self.remotes:toAll("Fade", "clear")
	self:refreshLobby()
end

---------------------------------------------------------------------------
-- messaging
---------------------------------------------------------------------------

function Round:toast(player, text, kind)
	if player then
		self.remotes:toClient(player, "Toast", text, kind or "info")
	else
		self:toastAll(text, kind)
	end
end

function Round:toastAll(text, kind)
	self.remotes:toAll("Toast", text, kind or "info")
end

--- Jump-scare sting. magnitude 0..1, kind for flavour.
function Round:scare(magnitude, kind, onlyPlayer)
	local payload = { m = Util.clamp(magnitude, 0, 1), kind = kind }
	if onlyPlayer then
		self.remotes:toClient(onlyPlayer, "Scare", payload)
	else
		self.remotes:toAll("Scare", payload)
	end
end

function Round:revealFlash(player)
	self.remotes:toClient(player, "Reveal")
end

function Round:grab(player, st, entity)
	if self.phase ~= Round.Phase.Active or not st.alive or st.escaped then
		return
	end
	if self.now < st.invulnUntil then
		return
	end

	entity:beginFeed()
	st.invulnUntil = self.now + Config.Player.InvulnAfterGrab
	st.grabs = st.grabs + 1

	if st.root then
		local push = st.pos - entity.pos
		local flat = Vector3.new(push.X, 0, push.Z)
		if flat.Magnitude > 0.2 then
			st.root.AssemblyLinearVelocity = flat.Unit * 44 + Vector3.new(0, 16, 0)
		end
	end

	local health = st.humanoid and st.humanoid.Health or 100
	if st.humanoid then
		st.humanoid:TakeDamage(Config.Player.GrabDamage)
	end

	self.remotes:toClient(player, "Hit", { health = health, dread = 1 })
	self.remotes:toClient(player, "Scare", { m = 1, kind = "grab" })
	self:toast(player, Config.Copy.Found, "bad")
	self:publish(st, true)
end

---------------------------------------------------------------------------
-- replication
---------------------------------------------------------------------------

function Round:publish(st, force)
	local player = st.player
	if not player or not player.Parent then
		return
	end
	local stateName = "lobby"
	if not st.joined then
		stateName = "menu"
	elseif self.phase == Round.Phase.Active then
		if st.escaped then
			stateName = "escaped"
		elseif not st.alive then
			stateName = st.eliminated and "consumed" or "down"
		else
			stateName = "active"
		end
	elseif self.phase == Round.Phase.Ingress then
		stateName = "ingress"
	elseif self.phase == Round.Phase.Resolving then
		stateName = "resolving"
	end

	Attributes.set(player, "State", stateName)
	Attributes.set(player, "Lives", st.lives, 0.5)
	Attributes.set(player, "Battery", st.battery, force and 0 or 0.4)
	Attributes.set(player, "Stamina", st.stamina, force and 0 or 0.8)
	Attributes.set(player, "Dread", st.dread, force and 0 or 0.03)
	Attributes.set(player, "FlashOn", st.flashOn)
	Attributes.set(player, "Hidden", st.hiddenLock ~= nil)
	Attributes.set(player, "Found", st.found, force and 0 or 0.02)
	Attributes.set(player, "Invuln", self.now < st.invulnUntil)
	Attributes.set(player, "Health", st.humanoid and math.floor(st.humanoid.Health) or 100, 0.5)
	Attributes.set(player, "Cells", st.contributed, 0.5)
	Attributes.set(player, "Signal", st.signal or 0, force and 0 or 0.02)
	Attributes.set(player, "Bearing", st.bearing or 0, force and 0 or 2)
	Attributes.set(player, "Distance", st.distance or 0, force and 0 or 1.5)
	Attributes.set(player, "SignalKind", st.signalLabel or "")
end

function Round:publishTick(dt)
	self.publishIn = self.publishIn - dt
	if self.publishIn <= 0 then
		self.publishIn = 1 / 12
		for _, st in self:eachPlayer() do
			self:publish(st)
		end
	end

	self.statIn = self.statIn - dt
	if self.statIn <= 0 then
		self.statIn = 0.25
		local alive, escaped = 0, 0
		for _, st in self:eachPlayer() do
			if st.joined then
				if st.escaped then
					escaped = escaped + 1
				elseif st.alive and not st.eliminated then
					alive = alive + 1
				end
			end
		end
		Attributes.set(self.root, "Countdown", math.max(0, math.ceil(self.countdown)), 0.5)
		Attributes.set(self.root, "TimeLeft", math.max(0, math.ceil(self.timeLeft)), 0.5)
		Attributes.set(self.root, "CellsFound", self.cellsFound, 0.5)
		Attributes.set(self.root, "Alive", alive, 0.5)
		Attributes.set(self.root, "Escaped", escaped, 0.5)
		Attributes.set(self.root, "Waiting", self:joinedCount(), 0.5)
		Attributes.set(self.root, "Phase", self.phase)
	end
end

--- The one surface every waiting player reads, in world space.
function Round:refreshLobby(force)
	if not force and self.now < (self.boardAt or 0) + 1 then
		return
	end
	self.boardAt = self.now
	if not self.lobby or not self.lobby.boardBody then
		return
	end

	local lines = {}
	if self.phase == Round.Phase.Intermission then
		lines[#lines + 1] = "LIFT IN " .. math.max(0, math.ceil(self.countdown)) .. "s"
		lines[#lines + 1] = "CREW READY: " .. self:joinedCount() .. " / " .. self:participantCount()
		lines[#lines + 1] = "OBJECTIVE: RECOVER " .. self.cellsNeeded .. " IGNITER CELLS"
		lines[#lines + 1] = "TIME LIMIT " .. Util.formatTime(Config.Round.Limit) .. "   LIVES " .. Config.Player.Lives
	else
		lines[#lines + 1] = "RUN IN PROGRESS"
		lines[#lines + 1] = "CELLS " .. self.cellsFound .. " / " .. self.cellsNeeded
		lines[#lines + 1] = "INSIDE " .. self.root:GetAttribute("Alive") .. "   OUT " .. self.root:GetAttribute("Escaped")
		if self.gateOpen then
			lines[#lines + 1] = "GATE OPEN - EXTRACT"
		end
	end
	lines[#lines + 1] = string.format("ROUNDS %d   ESCAPES %d   LOST %d", self.stats.rounds, self.stats.escapes, self.stats.deaths)
	if self.stats.best then
		lines[#lines + 1] = "BEST EXFIL " .. Util.formatTime(self.stats.best)
	end
	self.lobby.boardBody.Text = table.concat(lines, "\n")
end

return Round
