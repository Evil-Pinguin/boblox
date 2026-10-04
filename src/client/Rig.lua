--[[
	Rig - the camera.

	Runs just after the built-in camera script (RenderPriority.Camera + 30) and layers
	three things on top of it: a shake whose floor is driven by dread, a walk bob whose
	amplitude is driven by speed, and a FOV that opens when you sprint, so panic is felt
	in the widest possible way. The base CFrame is read and modified in place, so the
	default camera keeps full control of where the player is looking.
]]

local RunService = game:GetService("RunService")

--[[ Shared modules live in ReplicatedStorage.Blacksite. Addressed through the service rather
     than script.Parent.Parent, because these folders are siblings, not ancestors. ]]
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Blacksite")
local Config = require(shared:WaitForChild("Config"))
local Attributes = require(shared:WaitForChild("Attributes"))
local Util = require(shared:WaitForChild("Util"))

local Rig = {}
Rig.__index = Rig

local noise = math.noise or function(a, b)
	return math.sin(a * 12.9 + b * 78.2) * 0.5
end

function Rig.new(deps)
	local self = setmetatable({}, Rig)
	self.camera = deps.camera
	self.player = deps.player
	self.effects = deps.effects
	self.phase = 0
	self.time = 0
	self.shakeSeed = math.random(1, 900)
	self.fov = Config.Camera.Fov
	self.bound = false
	return self
end

function Rig:start()
	if self.bound then
		return
	end
	self.bound = true
	local self2 = self
	RunService:BindToRenderStep("BlacksiteRig", Enum.RenderPriority.Camera.Value + 30, function(dt)
		self2:update(dt)
	end)
end

function Rig:stop()
	if not self.bound then
		return
	end
	self.bound = false
	pcall(function()
		RunService:UnbindFromRenderStep("BlacksiteRig")
	end)
end

function Rig:update(dt)
	local camera = self.camera
	if not camera or not camera.Parent then
		return
	end

	self.time = self.time + dt

	local player = self.player
	local dread = Attributes.num(player, "Dread", 0)
	local hidden = Attributes.get(player, "Hidden", false)

	local char = player.Character
	local humanoid = char and char:FindFirstChild("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")

	local allowedSpeed = humanoid and humanoid.WalkSpeed or Config.Player.WalkSpeed
	local camSpeed = 0
	if root then
		local v = root.AssemblyLinearVelocity
		camSpeed = math.sqrt(v.X * v.X + v.Z * v.Z)
	end

	local camCfg = Config.Camera

	-- FOV: opening up when sprinting makes the corridors feel like they are fleeing.
	local targetFov = camCfg.Fov
	if allowedSpeed >= Config.Player.SprintSpeed - 1 and camSpeed > 12 then
		targetFov = camCfg.SprintFov
	end
	if hidden then
		targetFov = camCfg.HiddenFov
	end
	targetFov = targetFov + dread * 3
	self.fov = Util.damp(self.fov, targetFov, 0.16, dt)
	camera.FieldOfView = self.fov

	-- Walk bob, tied to actual ground speed rather than an input flag, so crouch-walking
	-- and being knocked around both read correctly.
	local moving = camSpeed > 2 and not hidden
	if moving then
		self.phase = self.phase + dt * (camCfg.BobFrequency * (0.6 + camSpeed / Config.Player.SprintSpeed * 0.7))
	else
		self.phase = self.phase + dt * 0.7
	end

	local bobWeight = (moving and Util.clamp(camSpeed / Config.Player.WalkSpeed, 0.2, 1.5) or 0.12)
	local up = math.sin(self.phase * 2) * camCfg.BobHeight * bobWeight
	local side = math.sin(self.phase) * camCfg.BobSide * bobWeight
	local roll = math.sin(self.phase) * camCfg.BobTurn * bobWeight

	-- Shake: a decaying impulse from the effects layer plus a permanent floor of dread,
	-- so the screen is never perfectly still once it is close.
	local amp = (self.effects and self.effects.shake or 0) + dread * 0.055
	local t = self.time
	local sx = noise(self.shakeSeed, t * 22) * amp
	local sy = noise(self.shakeSeed + 31, t * 26) * amp
	local sr = noise(self.shakeSeed + 77, t * 17) * amp * 0.55

	-- Breathing. Standing still is supposed to be uncomfortable.
	local breath = math.sin(self.phase * 0.5) * (0.02 + dread * 0.09)
	if hidden then
		breath = math.sin(self.phase * 0.32) * (0.06 + dread * 0.12)
	end

	camera.CFrame = camera.CFrame * CFrame.new(side, up + breath, 0) * CFrame.Angles(sx, sy, roll)
end

return Rig
