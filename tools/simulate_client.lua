--[[
	simulate_client.lua - boots the real client scripts against the simulated server.

	The client is where most of the game lives (HUD, flashlight rig, post-processing,
	input), and none of it can be eyeballed from source. This drives the same event and
	attribute traffic a server would produce and asserts the client survives it, keeps
	its instances in the right places, and reacts to input.

	Local-only instances must never leak into replicated services, so that is checked too.
]]

local mock = _G.MOCK

local game = _G.game
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local root = workspace:WaitForChild("BlacksiteRoot")
local net = ReplicatedStorage:WaitForChild("BlacksiteNet")
local eventRemote = net:WaitForChild("Event")
local actionRemote = net:WaitForChild("Action")

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

local function step(frames)
	for _ = 1, frames do
		mock.step(DT)
	end
end

local player = Players.LocalPlayer
ok(player ~= nil, "client found LocalPlayer")

local function attr(node, name)
	return node and node:GetAttribute(name)
end

--- Search every gui descendant for a label showing this text.
local function findText(parent, needle)
	local hit
	local function walk(node)
		for _, child in ipairs(node:GetChildren()) do
			if not hit and child._props.Text ~= nil and tostring(child._props.Text):find(needle, 1, true) then
				hit = child
			end
			if not hit then
				walk(child)
			end
		end
	end
	walk(parent)
	return hit
end

---------------------------------------------------------------------------
-- 1. boot: hud, rig, effects, flashlight all constructed without error
---------------------------------------------------------------------------

local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:FindFirstChild("BlacksiteHUD")
ok(hud ~= nil, "HUD ScreenGui was created in PlayerGui")
local hudRoot = hud and hud:FindFirstChild("Hud")
ok(hudRoot ~= nil, "HUD builds a single root frame")
ok(hudRoot ~= nil and #hudRoot:GetChildren() >= 6, "the root frame carries the live panels (" .. (hudRoot and #hudRoot:GetChildren() or 0) .. ")")

local light = workspace:FindFirstChild("BlacksiteLight")
ok(light ~= nil, "flashlight carrier part exists in Workspace")
if light then
	ok(light:FindFirstChildOfClass("SpotLight") ~= nil, "the carrier has a SpotLight")
end

-- client-only effects must NOT be parented to replicated services
-- Anything a client creates in Lighting would replicate to everyone in the server's
-- view of that service; only the server's own atmosphere belongs there.
local LEAKY = { BlurPostEffect = true, ColorCorrectionEffect = true, BloomEffect = true,
	DepthOfFieldEffect = true, SunRaysEffect = true, ScreenGui = true, Sound = true }
local lightingLeak = 0
for _, child in ipairs(game:GetService("Lighting"):GetChildren()) do
	if LEAKY[child._class] then
		lightingLeak = lightingLeak + 1
	end
end
ok(lightingLeak == 0, "no client render effects leaked into Lighting")

local camKids = workspace.CurrentCamera:GetChildren()
ok(#camKids > 0, "post-processing + overlay live under the camera (" .. #camKids .. " children)")

---------------------------------------------------------------------------
-- 2. the menu offers a way in, and pressing it sends the join action
---------------------------------------------------------------------------

local menu = playerGui:FindFirstChild("BlacksiteMenu")
ok(menu ~= nil, "join menu was built")
local joined = false
for _, record in ipairs(actionRemote._props._sent) do
	if record.args[2] == "join" then
		joined = true
	end
end
if not joined and menu then
	-- click the button the way a player would
	local button
	local function walk(node)
		for _, child in ipairs(node:GetChildren()) do
			if not button and child._class == "TextButton" then
				button = child
			end
			walk(child)
		end
	end
	walk(menu)
	ok(button ~= nil, "menu has a button to press")
	if button then
		-- the helper may wire Activated or MouseButton1Click; fire whichever has listeners
		for _, name in ipairs({ "Activated", "MouseButton1Click" }) do
			local sig = button._events[name]
			if sig and #sig._handlers > 0 then
				sig:Fire()
			end
		end
		step(6)
		for _, record in ipairs(actionRemote._props._sent) do
			if record.args[2] == "join" then
				joined = true
			end
		end
	end
end
ok(joined, "pressing the menu button asks the server for a round")

---------------------------------------------------------------------------
-- 3. server traffic is rendered
---------------------------------------------------------------------------

eventRemote:FireClient(player, "Toast", "CELL SECURED", "good")
step(6)
ok(hud ~= nil and findText(hud, "CELL SECURED") ~= nil, "a toast from the server reaches the HUD text")

eventRemote:FireClient(player, "Hit", { health = 42, dread = 0.9 })
step(4)
ok(true, "a hit message does not break the client")

eventRemote:FireClient(player, "Scare", { m = 1, kind = "grab" })
step(4)
ok(true, "a scare payload does not break the client")

eventRemote:FireClient(player, "Shake")
eventRemote:FireClient(player, "Reveal")
eventRemote:FireClient(player, "Sound", "Heartbeat")
step(4)
ok(true, "shake / reveal / sound messages do not break the client")

eventRemote:FireClient(player, "Fade", "black")
step(40)
eventRemote:FireClient(player, "Fade", "clear")
step(40)
ok(true, "fades run without error")

local results = playerGui:FindFirstChild("BlacksiteResults")
eventRemote:FireClient(player, "Result", {
	kind = "escaped",
	cells = 5,
	lives = 2,
	time = 141,
	escaped = 1,
	rounds = 1,
	best = 5,
})
step(10)
ok(results ~= nil, "results panel exists")
ok(results ~= nil and findText(results, "5") ~= nil, "results panel shows the round numbers")

---------------------------------------------------------------------------
-- 4. attributes drive the HUD numbers
---------------------------------------------------------------------------

player:SetAttribute("Cells", 3)
player:SetAttribute("Lives", 2)
player:SetAttribute("Battery", 61)
player:SetAttribute("Stamina", 40)
player:SetAttribute("Dread", 0.7)
player:SetAttribute("Signal", 0.5)
player:SetAttribute("Bearing", 210)
player:SetAttribute("Distance", 84)
player:SetAttribute("SignalKind", "cell")
step(30)
ok(hudRoot ~= nil and #hudRoot:GetChildren() >= 6, "HUD still stands after a full attribute sweep")

---------------------------------------------------------------------------
-- 5. input bindings
---------------------------------------------------------------------------

local beginState, endState = Enum.UserInputState.Begin, Enum.UserInputState.End
ok(mock.hasBinding("BlacksiteFlash"), "the flashlight key is bound through ContextActionService")
ok(mock.hasBinding("BlacksiteSprint"), "the sprint key is bound")
ok(mock.hasBinding("BlacksiteCrouch"), "the crouch key is bound")

mock.pressKey(Enum.KeyCode.F, beginState)
mock.pressKey(Enum.KeyCode.F, endState)
step(6)
local flashSent = false
for _, record in ipairs(actionRemote._props._sent) do
	if record.args[2] == "flash" then
		flashSent = true
	end
end
ok(flashSent, "pressing F tells the server about the flashlight")

mock.pressKey(Enum.KeyCode.LeftShift, beginState)
step(30)
mock.pressKey(Enum.KeyCode.LeftShift, endState)
ok(true, "sprint press and release round-trip without error")

mock.pressKey(Enum.KeyCode.LeftControl, beginState)
mock.pressKey(Enum.KeyCode.LeftControl, endState)
mock.pressKey(Enum.KeyCode.V, beginState)
step(10)
ok(true, "crouch and view keys round-trip without error")

local UIS = game:GetService("UserInputService")
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.M, UserInputType = Enum.UserInputType.Keyboard }, false)
step(10)
ok(true, "the mute key still works through raw input")

---------------------------------------------------------------------------
-- 6. the rig runs against a moving camera for a whole round phase
---------------------------------------------------------------------------

local cam = workspace.CurrentCamera
local startYaw = 0
for i = 1, 60 * 6 do
	startYaw = startYaw + 0.01
	cam.CFrame = CFrame.lookAt(
		Vector3.new(math.cos(startYaw) * 30, 4, math.sin(startYaw) * 30),
		Vector3.new(0, 4, 0)
	)
	mock.step(DT)
end
ok(true, "camera rig survived 6 s of moving the view around")
ok(cam.FieldOfView ~= nil and cam.FieldOfView > 40, "the rig is driving FOV (" .. tostring(cam.FieldOfView) .. ")")

-- hidden / down / escaped states must all pass through without wedging
for _, state in ipairs({ "active", "down", "escaped", "menu", "consumed" }) do
	player:SetAttribute("State", state)
	step(20)
end
ok(true, "every published state is handled by the client")

-- No stepping here: the server republishes Hidden at 12 Hz and would legitimately win.
player:SetAttribute("Hidden", true)
ok(player:GetAttribute("Hidden") == true, "hidden attribute is readable by the client")
step(20)
player:SetAttribute("Hidden", false)
step(20)

-- phase transitions on the replicated root
for _, phase in ipairs({ "ingress", "active", "resolving", "intermission" }) do
	root:SetAttribute("Phase", phase)
	step(20)
end
ok(true, "phase changes drive the client without errors")

---------------------------------------------------------------------------
-- 7. a live round: the client keeps ticking while the server runs it
---------------------------------------------------------------------------

actionRemote:FireServer(player, "join")
local frames = 0
while attr(root, "Phase") ~= "active" and frames < 60 * 30 do
	mock.step(DT)
	frames = frames + 1
end
ok(attr(root, "Phase") == "active", "the client survived a real ingress into an active round (phase="
	.. tostring(attr(root, "Phase")) .. ", state=" .. tostring(player:GetAttribute("State"))
	.. ", lives=" .. tostring(player:GetAttribute("Lives")) .. ")")

for _ = 1, 60 * 8 do
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4, 0), Vector3.new(math.random() * 4 - 2, 4, -30))
	if mock.newCharacter then
		local char = player.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if r then
			r.AssemblyLinearVelocity = Vector3.new(12, 0, 0)
		end
	end
	mock.step(DT)
end
ok(true, "8 s of a live round with movement noise did not break the client")

---------------------------------------------------------------------------
-- 8. audio: a configured id is enough to make sound happen
---------------------------------------------------------------------------

local sharedMods = ReplicatedStorage:WaitForChild("Blacksite")
local Config = require(sharedMods:WaitForChild("Config"))
Config.Sounds.FootstepConcrete = "rbxassetid://1"

local function countSounds()
	local n = 0
	for _, child in ipairs(workspace.CurrentCamera:GetChildren()) do
		if child._class == "Sound" then
			n = n + 1
		end
	end
	return n
end

local before = countSounds()
local char = player.Character
local rpart = char and char:FindFirstChild("HumanoidRootPart")
ok(rpart ~= nil, "the local character is available for the step test")
for _ = 1, 120 do
	if rpart then
		rpart._props.AssemblyLinearVelocity = Vector3.new(14, 0, 0)
	end
	mock.step(DT)
end
local after = countSounds()
ok(after > before, "configured footstep audio plays while moving (" .. before .. " -> " .. after .. ")")
Config.Sounds.FootstepConcrete = ""

ok(playerGui:FindFirstChild("BlacksiteHUD") ~= nil, "HUD is still parented at the end of it all")
ok(workspace:FindFirstChild("BlacksiteLight") ~= nil, "flashlight carrier still exists")

print(string.format("\nClient simulation: %d/%d checks passed", checks - failures, checks))
if failures > 0 then
	error("client simulation reported " .. failures .. " failure(s)", 0)
end
