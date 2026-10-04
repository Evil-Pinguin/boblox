--[[
	Blacksite - client entry point.

	Glue only: it builds the local rig (HUD, effects, flashlight, camera), binds input,
	and forwards the server's event stream into those modules. If you want to change how
	the game *feels*, this file is where you decide which module hears which signal.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

--[[ Shared modules live in ReplicatedStorage.Blacksite. Addressed through the service rather
     than script.Parent.Parent, because these folders are siblings, not ancestors. ]]
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Blacksite")
local Config = require(shared:WaitForChild("Config"))
local Attributes = require(shared:WaitForChild("Attributes"))
local Remotes = require(shared:WaitForChild("Remotes"))

local container = script.Parent
local HUD = require(container:WaitForChild("HUD"))
local Effects = require(container:WaitForChild("Effects"))
local Rig = require(container:WaitForChild("Rig"))
local Flashlight = require(container:WaitForChild("Flashlight"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 60) or player.PlayerGui
local camera = Workspace.CurrentCamera
while not camera do
	task.wait()
	camera = Workspace.CurrentCamera
end
local root = workspace:WaitForChild("BlacksiteRoot", 60)
local remotes = Remotes.get()

---------------------------------------------------------------------------
-- strip the default UI. A horror game lives or dies on never seeing the backpack.
---------------------------------------------------------------------------
task.spawn(function()
	local ok = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	if not ok then
		for _, item in ipairs({ "Backpack", "Health", "Chat", "PlayerList", "InfoButton", "EmotesMenu", "StatsTable", "BuyButton" }) do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[item], false)
			end)
		end
	end
end)

---------------------------------------------------------------------------
-- modules
---------------------------------------------------------------------------

local effects = Effects.new({
	player = player,
	root = root,
	camera = camera,
	playerGui = playerGui,
	container = camera,
})

local hud = HUD.new({
	player = player,
	root = root,
	playerGui = playerGui,
	remotes = remotes,
})

local rig = Rig.new({
	camera = camera,
	player = player,
	effects = effects,
})
rig:start()

local light = Flashlight.new({
	player = player,
	camera = camera,
	root = root,
})

---------------------------------------------------------------------------
-- audio
--
-- Every id comes from Config.Sounds and an empty id is a silent no-op, so the game
-- is fully playable with zero uploaded assets and gets footsteps, stingers and a
-- heartbeat the moment someone pastes ids in.
---------------------------------------------------------------------------

local muted = false
local tracked = {}

local function track(sound)
	tracked[#tracked + 1] = { sound = sound, volume = sound.Volume }
	if #tracked > 12 then
		table.remove(tracked, 1)
	end
	return sound
end

local function setMuted(value)
	muted = value
	for _, entry in ipairs(tracked) do
		local sound = entry.sound
		if sound and sound.Parent then
			sound.Volume = muted and 0 or entry.volume
		end
	end
end

local function playSound(name, options)
	options = options or {}
	local id = Config.Sounds[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Blacksite_" .. name
	sound.SoundId = id
	sound.Volume = (options.volume or 0.7) * (Config.SoundVolumes[name] or 1)
	sound.PlaybackSpeed = options.speed or 1
	sound.Looped = options.loop == true
	sound.Parent = camera
	if options.stopExisting then
		for _, entry in ipairs(tracked) do
			if entry.sound.Name == "Blacksite_" .. name then
				entry.sound:Stop()
				entry.sound:Destroy()
			end
		end
	end
	track(sound)
	sound.Ended:Connect(function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	sound:Play()
	return sound
end

-- Heartbeat is the one sound worth rigging properly: dread drives its volume and its
-- rate, which is the cheapest, most effective horror trick in the medium.
local heartbeat
local function heartbeatFor(dread)
	if Config.Sounds.Heartbeat == "" or muted then
		return
	end
	if not heartbeat or not heartbeat.Parent then
		heartbeat = playSound("Heartbeat", { volume = 0, loop = true })
		if not heartbeat then
			return
		end
	end
	heartbeat.Volume = dread * dread * (Config.SoundVolumes.Heartbeat or 0.5)
	heartbeat.PlaybackSpeed = 0.8 + dread * 0.75
end

---------------------------------------------------------------------------
-- input
---------------------------------------------------------------------------

local wantSprint, wantCrouch = false, false
local moveDirty = false
local firstPerson = true

local function pushMove()
	moveDirty = true
end

local function sendMove()
	if not moveDirty or not remotes then
		return
	end
	moveDirty = false
	Remotes.fire(remotes, Remotes.Actions.Move, wantSprint == true, wantCrouch == true)
end

local function setFirstPerson(on)
	pcall(function()
		player.CameraMode = on and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
	end)
end

local function toggleFlash()
	local nextOn = not Attributes.get(player, "FlashOn", false)
	if remotes then
		Remotes.fire(remotes, Remotes.Actions.Flash, nextOn)
	end
	-- Optimistic: the attribute round trip is a frame or two, and a flashlight that
	-- arrives two frames late feels broken. The server's value wins either way.
	Attributes.set(player, "FlashOn", nextOn)
end

ContextActionService:BindAction("BlacksiteFlash", function(actionName, state)
	if state == Enum.UserInputState.Begin then
		toggleFlash()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

ContextActionService:BindAction("BlacksiteSprint", function(_, state)
	if state == Enum.UserInputState.Begin then
		wantSprint = true
		pushMove()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		wantSprint = false
		pushMove()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR1)

ContextActionService:BindAction("BlacksiteCrouch", function(_, state)
	if state == Enum.UserInputState.Begin then
		wantCrouch = true
		pushMove()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		wantCrouch = false
		pushMove()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL1)

ContextActionService:BindAction("BlacksiteView", function(_, state)
	if state == Enum.UserInputState.Begin then
		firstPerson = not firstPerson
		setFirstPerson(firstPerson)
		hud:toast("VIEW: " .. (firstPerson and "FIRST PERSON" or "THIRD PERSON"), "info")
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.V, Enum.KeyCode.ButtonY)

pcall(function()
	ContextActionService:SetTitle("BlacksiteFlash", "LIGHT")
	ContextActionService:SetTitle("BlacksiteSprint", "RUN")
	ContextActionService:SetTitle("BlacksiteCrouch", "SNEAK")
	ContextActionService:SetPosition("BlacksiteFlash", UDim2.new(0.9, 0, 0.42, 0))
	ContextActionService:SetPosition("BlacksiteSprint", UDim2.new(0.9, 0, 0.28, 0))
	ContextActionService:SetPosition("BlacksiteCrouch", UDim2.new(0.78, 0, 0.28, 0))
end)

local function watchKey(code, onDown)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == code and not processed then
			onDown()
		end
	end)
end

watchKey(Enum.KeyCode.M, function()
	setMuted(not muted)
	hud:toast(muted and "LOCAL AUDIO OFF" or "LOCAL AUDIO ON", "info")
end)

---------------------------------------------------------------------------
-- menu buttons
---------------------------------------------------------------------------

hud.onJoin = function()
	if remotes then
		Remotes.fire(remotes, Remotes.Actions.Join)
	end
	hud.menu.Enabled = false
	effects:fade("black")
end

hud.onNextRound = function()
	if remotes then
		Remotes.fire(remotes, Remotes.Actions.Restart)
	end
	hud.results.Enabled = false
end

hud.onViewMode = function(on)
	firstPerson = on
	setFirstPerson(on)
end

---------------------------------------------------------------------------
-- the Hollow, as seen from here
---------------------------------------------------------------------------

local hollow

local function hookHollow(model)
	local highlight = model:FindFirstChild("Reveal")
	if not highlight then
		return
	end
	model:GetAttributeChangedSignal("Revealed"):Connect(function()
		if model:GetAttribute("Revealed") then
			highlight.OutlineTransparency = 0
			highlight.FillTransparency = 0.84
			TweenService:Create(highlight, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				OutlineTransparency = 0.5,
				FillTransparency = 1,
			}):Play()
			effects:kick(0.5)
			playSound("Scream", { volume = 0.5, speed = 0.78 })
		else
			highlight.OutlineTransparency = 1
			highlight.FillTransparency = 1
		end
	end)
end

local function refreshHollow()
	local model = root and root:FindFirstChild("TheHollow")
	if model ~= hollow then
		hollow = model
		if model then
			hookHollow(model)
		end
	end
end

if root then
	root.ChildAdded:Connect(refreshHollow)
	root.ChildRemoved:Connect(function(child)
		if child == hollow then
			hollow = nil
		end
	end)
	refreshHollow()
end

---------------------------------------------------------------------------
-- hidden state: first person makes the locker gap the whole viewport
---------------------------------------------------------------------------

player:GetAttributeChangedSignal("Hidden"):Connect(function()
	local hidden = Attributes.get(player, "Hidden", false)
	if hidden then
		setFirstPerson(true)
		effects:showCard(Config.Copy.Hidden, 1.8)
		playSound("LockerClose", { volume = 0.8 })
	else
		setFirstPerson(firstPerson)
		playSound("LockerOpen", { volume = 0.8 })
	end
end)

---------------------------------------------------------------------------
-- server events
---------------------------------------------------------------------------

if remotes then
	remotes.Event.OnClientEvent:Connect(function(event, payload, extra)
		if event == "Toast" then
			hud:toast(payload, extra or "info")
		elseif event == "Scare" then
			effects:scare(payload)
			if payload and payload.kind == "grab" then
				playSound("Scream", { volume = 1, speed = 0.85 })
			elseif payload and payload.kind == "blink" then
				playSound("Scream", { volume = 0.35, speed = 1.4 })
			elseif payload and payload.kind == "gate" then
				playSound("GateOpen", { volume = 0.9 })
			end
		elseif event == "Hit" then
			effects:hit()
			playSound("Grab", { volume = 0.95 })
		elseif event == "Fade" then
			effects:fade(payload)
		elseif event == "Result" then
			hud:showResults(payload)
		elseif event == "Sound" then
			playSound(payload)
		elseif event == "Reveal" then
			effects:kick(0.3)
		end
	end)
end

if root then
	root:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = Attributes.get(root, "Phase", "intermission")
		if phase == "ingress" then
			effects:showCard("SUBLEVEL 7  //  POWER OFFLINE", 3.4)
		elseif phase == "active" then
			playSound("Ambience", { volume = 0.3, loop = true, stopExisting = true })
		elseif phase == "intermission" or phase == "resolving" then
			for _, entry in ipairs(tracked) do
				if entry.sound.Name == "Blacksite_Ambience" and entry.sound.IsPlaying then
					entry.sound:Stop()
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- footsteps
--
-- The noise model is the core stealth mechanic and it is completely invisible, so a
-- footstep is played on the same cadence the server uses to emit a noise ping. Silent
-- when no id is configured, which is why this is a nicety and not a dependency.
---------------------------------------------------------------------------

local stepClock = 0

local function footstepsFor(dt)
	if Attributes.num(player, "Hidden", 0) > 0.5 then
		stepClock = 0
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end
	local velocity = rootPart.AssemblyLinearVelocity
	local planar = math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z)
	if planar < 2 then
		stepClock = 0
		return
	end

	local cadence = 0.44
	if wantCrouch then
		cadence = 0.72
	elseif wantSprint then
		cadence = 0.3
	end
	stepClock = stepClock + dt
	if stepClock < cadence then
		return
	end
	-- Reset rather than subtract: a frame-rate dip should drop a step, not fire a burst.
	stepClock = 0
	playSound(wantSprint and "Sprint" or "FootstepConcrete", {
		volume = wantCrouch and 0.25 or (wantSprint and 0.75 or 0.5),
		speed = 0.94 + math.random() * 0.12,
	})
end

-- frame
---------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.2)
	-- movement intent is a state, not a stream: batched with the frame
	sendMove()
	effects:update(dt)
	light:update(dt)
	hud:update(dt)
	hud:updateToasts(dt)
	hud:updateResults(dt)
	heartbeatFor(Attributes.num(player, "Dread", 0))
	footstepsFor(dt)
end)
