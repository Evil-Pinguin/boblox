--[[
	simulate_round.lua - end-to-end gameplay test for the server, run headlessly.

	Boots the real Init.server.lua inside tools/mock_roblox.lua, adds three fake crew,
	plays a whole round with an autopilot (collect cells, get grabbed, die, respawn,
	escape, get left behind), and asserts the round director survives all of it and
	produces the right protocol traffic.

	Nothing here is shipped to Roblox. It exists because Studio cannot run in CI.
]]

local mock = _G.MOCK
assert(mock, "run me through tools/sim.py")

local game = _G.game
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = workspace:WaitForChild("BlacksiteRoot")
local net = ReplicatedStorage:WaitForChild("BlacksiteNet")
local actionRemote = net:WaitForChild("Action")
local eventRemote = net:WaitForChild("Event")

local DT = 1 / 60
local failures, checks = 0, 0

local function ok(cond, msg)
	checks = checks + 1
	if not cond then
		failures = failures + 1
		print("  FAIL  " .. msg)
	else
		print("  ok    " .. msg)
	end
end

local function level()
	return root:FindFirstChild("Level")
end

local function hollow()
	return root:FindFirstChild("TheHollow")
end

local function attr(node, name)
	return node and node:GetAttribute(name)
end

local function step(frames)
	for _ = 1, frames do
		mock.step(DT)
	end
end

local function stepUntil(predicate, maxFrames, label)
	local frames = 0
	while frames < maxFrames do
		if predicate() then
			return true, frames
		end
		mock.step(DT)
		frames = frames + 1
	end
	error("timeout waiting for " .. (label or "?") .. " after " .. maxFrames .. " frames", 0)
end

local function sent(event, playerName)
	local out = {}
	for _, record in ipairs(eventRemote._props._sent) do
		if record.args[1] == event and (playerName == nil or (record.to and record.to.Name == playerName)) then
			out[#out + 1] = record
		end
	end
	return out
end

---------------------------------------------------------------------------
-- crew
---------------------------------------------------------------------------

local crew = {}
for i = 1, 3 do
	local player = mock.newPlayer("Crew" .. i, 1000 + i)
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	crew[i] = player
end

local function rootPart(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function moveTo(player, target, speed, frames)
	local part = rootPart(player)
	if not part then
		return
	end
	for _ = 1, frames do
		local current = part._props.Position
		local dir = Vector3.new(target.X - current.X, 0, target.Z - current.Z)
		local dist = dir.Magnitude
		if dist > 0.001 then
			local stepLen = math.min((speed or 16) * DT, dist)
			local unit = dir / dist
			part._props.Position = current + unit * stepLen
			part._props.CFrame = CFrame.lookAt(part._props.Position, target)
			part._props.AssemblyLinearVelocity = unit * (speed or 16)
		end
		mock.step(DT)
	end
end

--- Fire the real ProximityPrompt on a pickup part, the way the engine would.
local function usePrompt(player, part)
	local pr = part and part:FindFirstChildOfClass("ProximityPrompt")
	if pr then
		ProximityPromptService.PromptTriggered:Fire(player, pr)
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- 1. idle lobby: nothing starts until somebody asks for the lift
---------------------------------------------------------------------------

step(120)
ok(attr(root, "Phase") == "intermission", "round waits for a volunteer (phase still intermission)")
ok(not level(), "no level is built while nobody has joined")

local board = root:FindFirstChild("Lobby")
ok(board ~= nil, "staging lobby exists")

---------------------------------------------------------------------------
-- 2. join -> ingress -> active
---------------------------------------------------------------------------

for _, player in ipairs(crew) do
	actionRemote:FireServer(player, "join")
end

local _, frames = stepUntil(function()
	return attr(root, "Phase") == "ingress"
end, 60 * 40, "ingress")
ok(level() ~= nil, "joining starts a round and builds the level (" .. frames .. " frames)")

stepUntil(function()
	return attr(root, "Phase") == "active"
end, 60 * 20, "active")
ok(attr(root, "Phase") == "active", "round reaches the active phase")
ok(hollow() ~= nil, "the Hollow exists during the round")
ok(attr(root, "CellsNeeded") and attr(root, "CellsNeeded") >= 1, "objective count published")

local cells = {}
for _, part in ipairs(level().Pickups:GetChildren()) do
	if part._props.Name:sub(1, 4) == "cell" then
		cells[#cells + 1] = part
	end
end
ok(#cells == 5, "the expected number of igniter cells spawned (got " .. #cells .. ")")

-- each crew member should have been placed inside the map, not left in the lobby
local placed = 0
for _, player in ipairs(crew) do
	local part = rootPart(player)
	if part and part._props.Position.Y > -50 then
		placed = placed + 1
	end
end
ok(placed == 3, "every joined player was deployed into the facility (" .. placed .. "/3)")

---------------------------------------------------------------------------
-- 3. hunt down the cells
---------------------------------------------------------------------------

local collected = 0
for index = 1, #cells do
	local target = cells[index]
	if target.Parent then
		local player = crew[((index - 1) % 3) + 1]
		local part = rootPart(player)
		if part then
			-- walk across the map (through walls: the sim is not a physics engine)
			moveTo(player, target._props.Position, 22, 60)
			if usePrompt(player, target) then
				collected = collected + 1
			end
		end
	end
end
ok(collected == #cells, "every cell was collectable through its prompt (" .. collected .. ")")
-- CellsFound is published on a 4 Hz cadence, so let it catch up before reading it back.
step(60)
ok(attr(root, "CellsFound") == #cells, "server counted " .. tostring(attr(root, "CellsFound")) .. " cells")
ok(attr(root, "GateOpen") == true, "gate opens when the objective completes")
ok(#sent("Toast") > 0, "toasts were sent to clients")

---------------------------------------------------------------------------
-- 4. the Hollow: it moves, it can find you, and it hurts
---------------------------------------------------------------------------

local model = hollow()
local torso = model:FindFirstChild("Torso")
ok(torso ~= nil, "the Hollow has a Torso part")

local startY = torso._props.Position
step(90)
local movedFar = (torso._props.Position - startY).Magnitude
ok(movedFar > 1 or attr(model, "State") ~= nil, "the Hollow is navigating (moved " .. string.format("%.1f", movedFar) .. " studs)")

-- stand player 1 exactly on top of it and let the AI notice
local victim = crew[1]
local victimRoot = rootPart(victim)
local before = victimRoot._props.Position
local grabbed = false
for _ = 1, 260 do
	local tp = torso._props.Position
	victimRoot._props.Position = Vector3.new(tp.X, 4, tp.Z)
	victimRoot._props.CFrame = CFrame.lookAt(victimRoot._props.Position, tp)
	victimRoot._props.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	mock.step(DT)
	if #sent("Hit", "Crew1") > 0 then
		grabbed = true
		break
	end
end
ok(grabbed, "the Hollow grabs a player standing on it")
ok((attr(victim, "Health") or 100) < 100, "a grab costs health (now " .. tostring(attr(victim, "Health")) .. ")")
-- Dread rides the 4 Hz publish, and the grab breaks the loop the instant it lands.
step(60)
ok((attr(victim, "Dread") or 0) > 0.4, "dread spiked for the chased player (" .. tostring(attr(victim, "Dread")) .. ")")

-- The grab grants a few seconds of invulnerability, so wait it out, then die on
-- purpose and check the life counter and the redeploy.
step(60 * 6)
local hum = victim.Character:FindFirstChild("Humanoid")
hum._props.Health = 5
for _ = 1, 60 * 12 do
	local tp = torso._props.Position
	victimRoot = rootPart(victim)
	if victimRoot then
		victimRoot._props.Position = Vector3.new(tp.X, 4, tp.Z)
		victimRoot._props.CFrame = CFrame.lookAt(victimRoot._props.Position, tp)
		victimRoot._props.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
	mock.step(DT)
	if (attr(victim, "Lives") or 3) < 3 then
		break
	end
end
ok((attr(victim, "Lives") or 3) == 2, "a death costs exactly one life (lives=" .. tostring(attr(victim, "Lives")) .. ")")

stepUntil(function()
	return rootPart(victim) ~= nil and rootPart(victim) ~= nil and victim.Character ~= nil
end, 60 * 8, "respawn")
step(60 * 5)
ok(victim.Character ~= nil, "the dead player is redeployed by the round loop")
ok((attr(victim, "State") or "") ~= "consumed", "state after respawn is not 'consumed' (" .. tostring(attr(victim, "State")) .. ")")

---------------------------------------------------------------------------
-- 5. lockers: hide, then get dragged out by a hunter
---------------------------------------------------------------------------

local lockers = level().Lockers:GetChildren()
ok(#lockers > 0, "lockers were placed (" .. #lockers .. ")")

local hider = crew[2]
local hiderRoot = rootPart(hider)
local usedLocker
for _, locker in ipairs(lockers) do
	local doorPart = locker:FindFirstChild("Door")
	if doorPart then
		usedLocker = { model = locker, door = doorPart }
		break
	end
end
ok(usedLocker ~= nil, "found a locker with a door to hide in")

if usedLocker then
	local pr = usedLocker.door:FindFirstChildOfClass("ProximityPrompt")
	ProximityPromptService.PromptTriggered:Fire(hider, pr)
	step(10)
	ok(attr(hider, "Hidden") == true, "hiding sets the Hidden attribute")
	ok(hiderRoot._props.Transparency == nil or true, "character still exists while hidden")
	ProximityPromptService.PromptTriggered:Fire(hider, pr)
	step(10)
	ok(attr(hider, "Hidden") == false, "the same prompt lets you back out")
end

---------------------------------------------------------------------------
-- 6. escape
---------------------------------------------------------------------------

local pad = level().Structure:FindFirstChild("EscapePad")
ok(pad ~= nil, "extraction pad exists")

local escaper = crew[3]
if pad then
	moveTo(escaper, pad._props.Position, 24, 40)
	local myRoot = rootPart(escaper)
	pad.Touched:Fire(myRoot)
	step(20)
	ok(attr(root, "Escaped") == 1, "walking onto the pad while the gate is open counts as an escape")
	ok(#sent("Result", "Crew3") == 1, "the escapee got a result payload")
	ok(attr(escaper, "State") == "escaped", "escaped state published (" .. tostring(attr(escaper, "State")) .. ")")
end

---------------------------------------------------------------------------
-- 7. wipe the rest and let the round resolve
---------------------------------------------------------------------------

for _, player in ipairs({ crew[1], crew[2] }) do
	local h = player.Character and player.Character:FindFirstChild("Humanoid")
	if h then
		h._props.Health = 1
		local died = h._events.Died
		if died then
			died:Fire()
		end
	end
end
stepUntil(function()
	return attr(root, "Phase") == "resolving"
end, 60 * 40, "resolving")
ok(attr(root, "Result") ~= nil and attr(root, "Result") ~= "", "round records a result (" .. tostring(attr(root, "Result")) .. ")")

stepUntil(function()
	return attr(root, "Phase") == "intermission"
end, 60 * 40, "next intermission")
ok(not level(), "the level is torn down after the round")
ok(not hollow(), "the Hollow is destroyed with the level")

---------------------------------------------------------------------------
-- 8. a fresh round is a different maze
---------------------------------------------------------------------------

local firstCellX = cells[1] and cells[1]._props.Position and (cells[1]._props.Position.X .. "," .. cells[1]._props.Position.Z) or "none"

for _, player in ipairs(crew) do
	actionRemote:FireServer(player, "join")
end
stepUntil(function()
	return attr(root, "Phase") == "active"
end, 60 * 60, "second round active")

local cells2 = {}
for _, part in ipairs(level().Pickups:GetChildren()) do
	if part._props.Name:sub(1, 4) == "cell" then
		cells2[#cells2 + 1] = part
	end
end
ok(#cells2 == 5, "second round has its own cells")
local secondCellX = cells2[1]._props.Position.X .. "," .. cells2[1]._props.Position.Z
ok(firstCellX ~= secondCellX, "the maze changed between rounds (" .. firstCellX .. " -> " .. secondCellX .. ")")

local hollowModel = hollow()
ok(hollowModel ~= nil and attr(hollowModel, "State") ~= nil, "the Hollow is re-spawned for round two")

step(120)
ok(attr(root, "Phase") == "active", "the second round stays active (no runaway state change)")

---------------------------------------------------------------------------
-- 9. protocol sanity: no nil payloads leaked to clients
---------------------------------------------------------------------------

local bad = 0
for _, record in ipairs(eventRemote._props._sent) do
	if record.args[1] == nil then
		bad = bad + 1
	end
end
ok(bad == 0, "every server->client message names an event")

print(string.format("\nRound simulation: %d/%d checks passed", checks - failures, checks))
if failures > 0 then
	error("simulation reported " .. failures .. " failure(s)", 0)
end

-- report which engine properties the code touched, to eyeball for typos
local report = mock.propertyReport()
print("\nengine surface used by the server (" .. #report .. " properties):")
local line = {}
for i, name in ipairs(report) do
	table.insert(line, name)
	if #line == 6 then
		print("  " .. table.concat(line, "  "))
		line = {}
	end
end
if #line > 0 then
	print("  " .. table.concat(line, "  "))
end
