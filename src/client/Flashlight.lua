--[[
	Flashlight - a beam that is also a resource, a weapon the monster can see, and
	the only thing between you and a black screen.

	Implementation notes:
	  * the light lives on a client-created Part in Workspace. Instances a client
		creates are not replicated under FilteringEnabled, so this is a private light
		that still lights the shared, server-authored maze - which is exactly what a
		flashlight is.
	  * it follows workspace.CurrentCamera rather than the Head, so the beam goes where
		you look in first person and stays usable in third person.
	  * Enabled is driven by the replicated FlashOn attribute. The server owns the
		battery, because the Hollow reacts to your beam and that cannot be client-side.
]]

local Workspace = game:GetService("Workspace")

--[[ Shared modules live in ReplicatedStorage.Blacksite. Addressed through the service rather
     than script.Parent.Parent, because these folders are siblings, not ancestors. ]]
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Blacksite")
local Config = require(shared:WaitForChild("Config"))
local Attributes = require(shared:WaitForChild("Attributes"))
local Util = require(shared:WaitForChild("Util"))

local Flashlight = {}
Flashlight.__index = Flashlight

local noise = math.noise or function(a, b)
	return math.sin((a or 0) * 3.1 + (b or 0) * 11.7)
end

function Flashlight.new(deps)
	local self = setmetatable({}, Flashlight)
	self.player = deps.player
	self.camera = deps.camera
	self.time = 0
	self.strength = 0

	local part = Instance.new("Part")
	part.Name = "BlacksiteLight"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Massless = true
	part.Position = Vector3.new(0, -1000, 0)
	part.Parent = Workspace
	self.part = part

	self.spot = Instance.new("SpotLight")
	self.spot.Name = "Beam"
	self.spot.Face = Vector3.new(0, 0, -1)
	self.spot.Angle = Config.Light.SpotAngle
	self.spot.Range = Config.Light.SpotRange
	self.spot.Brightness = Config.Light.SpotBrightness
	self.spot.Color = Config.Light.SpotColor
	self.spot.Enabled = false
	self.spot.Parent = part
	pcall(function()
		self.spot.ShadowEnable = true
	end)

	-- A whisper of personal light so the beam is not the only thing you own: hands,
	-- feet and the floor immediately under you stay just legible.
	self.point = Instance.new("PointLight")
	self.point.Name = "Glow"
	self.point.Range = Config.Light.PointRange
	self.point.Brightness = 0
	self.point.Color = Color3.fromRGB(150, 160, 170)
	self.point.Shadows = false
	self.point.Parent = part

	return self
end

--- Flicker curve: the beam is healthy until the cell gets low, then it starts to beg.
function Flashlight:flicker(battery, dread)
	local low = 1
	if battery < Config.Light.FlickerStart then
		local t = 1 - battery / Config.Light.FlickerStart
		low = 1 - t * 0.72
		local stutter = noise(self.time * (2.4 + t * 9), battery * 0.1, 0)
		low = low * (0.62 + 0.38 * math.abs(stutter))
		if battery < Config.Light.FlickerDeath and stutter > 0.35 then
			low = 0
		end
	end

	-- the beam is a living thing when it is close; that is the whole horror beat
	local fear = 1 - dread * 0.28 * (0.5 + 0.5 * noise(self.time * 5.5, dread * 3, 1))
	return Util.clamp(low * fear, 0, 1)
end

function Flashlight:update(dt)
	self.time = self.time + dt

	local camera = self.camera
	if not camera or not camera.Parent then
		return
	end

	self.part.CFrame = camera.CFrame

	local player = self.player
	local wantOn = Attributes.get(player, "FlashOn", false)
	local battery = Attributes.num(player, "Battery", 0)
	local dread = Attributes.num(player, "Dread", 0)
	local hidden = Attributes.get(player, "Hidden", false)
	local phase = Attributes.get(Workspace:FindFirstChild("BlacksiteRoot") or camera, "Phase", "active")

	local on = wantOn and battery > 0 and not hidden
	local target = on and 1 or 0
	self.strength = Util.damp(self.strength, target, 0.06, dt)

	local level = self:flicker(battery, dread) * self.strength
	self.spot.Enabled = self.strength > 0.02
	self.spot.Brightness = Config.Light.SpotBrightness * level
	self.spot.Angle = Config.Light.SpotAngle - (1 - level) * 8
	self.point.Brightness = Config.Light.PointBrightness * self.strength * (0.6 + 0.4 * level)

	if on then
		self.part.Position = camera.CFrame.Position
	else
		self.part.Position = camera.CFrame.Position
	end
end

--- Cheap readout for the HUD's "light is a noise source" hint.
function Flashlight:isOn()
	return self.strength > 0.5
end

function Flashlight:destroy()
	if self.part then
		self.part:Destroy()
		self.part = nil
	end
end

return Flashlight
