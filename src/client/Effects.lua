--[[
	Effects - everything between the raw render and your eyeball.

	Post-effect instances are parented to the Camera rather than Lighting on purpose:
	anything a client puts in Lighting or SoundService replicates to the server and
	then to everybody, which would apply one player's panic blur to the whole crew.
	The Camera is player-owned, so its children stay local.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

--[[ Shared modules live in ReplicatedStorage.Blacksite. Addressed through the service rather
     than script.Parent.Parent, because these folders are siblings, not ancestors. ]]
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Blacksite")
local Config = require(shared:WaitForChild("Config"))
local Attributes = require(shared:WaitForChild("Attributes"))
local Util = require(shared:WaitForChild("Util"))

local Effects = {}
Effects.__index = Effects

local noise = math.noise or function()
	return 0
end

local function vignetteSequence(strength)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1 - strength * 0.12),
		NumberSequenceKeypoint.new(0.7, 1 - strength * 0.58),
		NumberSequenceKeypoint.new(1, 1 - strength),
	})
end

function Effects.new(deps)
	local self = setmetatable({}, Effects)
	self.player = deps.player
	self.root = deps.root
	self.camera = deps.camera
	self.shake = 0
	self.time = 0
	self.lighting = Lighting
	self.barSeeds = {}

	---------------------------------------------------------------------
	-- post effects (local: parented to the camera)
	---------------------------------------------------------------------
	local container = deps.container or Workspace.CurrentCamera or Workspace

	self.color = Instance.new("ColorCorrectionEffect")
	self.color.Name = "BlacksiteGrade"
	self.color.Brightness = -0.04
	self.color.Contrast = 0.24
	self.color.Saturation = -0.32
	self.color.Tint = Color3.fromRGB(128, 128, 128)
	self.color.Parent = container

	self.bloom = Instance.new("BloomEffect")
	self.bloom.Name = "BlacksiteBloom"
	self.bloom.Intensity = 0.5
	self.bloom.Size = 30
	self.bloom.Threshold = 0.82
	self.bloom.Parent = container

	self.blur = Instance.new("BlurPostEffect")
	self.blur.Name = "BlacksiteBlur"
	self.blur.Size = 0
	self.blur.Parent = container

	---------------------------------------------------------------------
	-- overlays
	---------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "BlacksiteOverlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = deps.playerGui

	self.vignette = Instance.new("Frame")
	self.vignette.Name = "Vignette"
	self.vignette.Size = UDim2.fromScale(1, 1)
	self.vignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	self.vignette.BackgroundTransparency = 0
	self.vignette.BorderSizePixel = 0
	self.vignette.Parent = gui
	self.vignetteGrad = Instance.new("UIGradient")
	self.vignetteGrad.Type = Enum.GradientType.Radial
	self.vignetteGrad.Transparency = vignetteSequence(0.2)
	self.vignetteGrad.Parent = self.vignette

	self.tint = Instance.new("Frame")
	self.tint.Name = "Tint"
	self.tint.Size = UDim2.fromScale(1, 1)
	self.tint.BackgroundColor3 = Color3.fromRGB(120, 8, 8)
	self.tint.BackgroundTransparency = 1
	self.tint.BorderSizePixel = 0
	self.tint.Parent = gui

	self.dark = Instance.new("Frame")
	self.dark.Name = "Fade"
	self.dark.Size = UDim2.fromScale(1, 1)
	self.dark.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	self.dark.BackgroundTransparency = 0
	self.dark.BorderSizePixel = 0
	self.dark.Parent = gui

	-- VHS-ish interference: a handful of moving bars, no textures needed.
	self.bars = {}
	for i = 1, Config.Effects.GrainBars do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0, 2)
		bar.Position = UDim2.new(0, 0, math.random(), 0)
		bar.BackgroundColor3 = Color3.fromRGB(190, 200, 205)
		bar.BackgroundTransparency = 1
		bar.BorderSizePixel = 0
		bar.Parent = gui
		self.bars[i] = bar
		self.barSeeds[i] = math.random(1, 999)
	end

	-- Title card: the "02:14 AM" beat that sells the descent.
	self.card = Instance.new("TextLabel")
	self.card.Name = "Card"
	self.card.BackgroundTransparency = 1
	self.card.Size = UDim2.new(1, 0, 0, 60)
	self.card.Position = UDim2.new(0, 0, 0.36, 0)
	self.card.Font = Enum.Font.Code
	self.card.TextSize = 30
	self.card.TextColor3 = Color3.fromRGB(214, 218, 220)
	self.card.TextXAlignment = Enum.TextXAlignment.Center
	self.card.TextTransparency = 1
	self.card.TextStrokeTransparency = 0.7
	self.card.Parent = gui

	-- The place starts faded to black and fades up on load, so the lobby reveal reads
	-- as an arrival rather than a pop.
	self.fadeTarget = 1
	self.fadeSpeed = 0.9

	return self
end

---------------------------------------------------------------------------
-- public nudges
---------------------------------------------------------------------------

function Effects:kick(magnitude)
	self.shake = math.min(2.4, self.shake + magnitude)
end

function Effects:tintPulse(color, alpha, seconds)
	self.tint.BackgroundColor3 = color
	self.tint.BackgroundTransparency = 1 - alpha
	TweenService:Create(self.tint, TweenInfo.new(seconds or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

function Effects:scare(payload)
	local m = payload and payload.m or 0.5
	local kind = payload and payload.kind
	self:kick(0.5 + m)
	if kind == "grab" then
		self:tintPulse(Color3.fromRGB(120, 6, 6), 0.62, 0.75)
		self.hitPulse = 1
	elseif kind == "blink" then
		self:tintPulse(Color3.fromRGB(4, 4, 6), 0.85, 0.35)
		self.dropOut = 0.35
	elseif kind == "gate" then
		self:tintPulse(Color3.fromRGB(40, 200, 140), 0.3, 0.9)
	else
		self:tintPulse(Color3.fromRGB(90, 6, 6), 0.35 * m, 0.5)
	end
end

function Effects:hit()
	self:tintPulse(Color3.fromRGB(120, 10, 10), 0.5, 0.7)
	self:kick(1.1)
	self.hitPulse = 1
end

--- Fade choreography for the lift.
function Effects:fade(kind)
	if kind == "black" then
		self.dark.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		self.fadeTarget = 0
		self.fadeSpeed = 7
	elseif kind == "clear" then
		self.dark.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		self.fadeTarget = 1
		self.fadeSpeed = 1.15
	elseif kind == "white" then
		self.dark.BackgroundColor3 = Color3.fromRGB(232, 238, 238)
		self.fadeTarget = 0
		self.fadeSpeed = 12
		task.delay(0.3, function()
			self.dark.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			self.fadeTarget = 1
			self.fadeSpeed = 1.7
		end)
	end
end

function Effects:showCard(text, seconds)
	self.card.Text = text or ""
	self.card.TextTransparency = 0
	task.delay(seconds or 2.6, function()
		TweenService:Create(self.card, TweenInfo.new(0.7), { TextTransparency = 1 }):Play()
	end)
end

---------------------------------------------------------------------------
-- per-frame
---------------------------------------------------------------------------

function Effects:update(dt)
	self.time = self.time + dt
	local player = self.player
	local dread = Attributes.num(player, "Dread", 0)
	local battery = Attributes.num(player, "Battery", 100)
	local hidden = Attributes.get(player, "Hidden", false)
	local purge = Attributes.get(self.root, "Purge", false)
	local phase = Attributes.get(self.root, "Phase", "intermission")

	-- shake decays; dread keeps a permanent low rumble underneath it
	self.shake = math.max(0, self.shake - dt * Config.Camera.ShakeDecay)
	self.shake = math.max(self.shake, dread * 0.055)
	self.hitPulse = math.max(0, (self.hitPulse or 0) - dt * 2.2)
	self.dropOut = math.max(0, (self.dropOut or 0) - dt)

	-- grade
	local grade = self.color
	grade.Contrast = 0.24 + dread * 0.4 + (purge and 0.1 or 0)
	grade.Saturation = -0.32 - dread * 0.3
	local thump = math.sin(self.time * (2.2 + dread * 5))
	grade.Brightness = -0.04 + thump * dread * 0.05 - (hidden and 0.05 or 0)
	if purge then
		grade.Tint = Color3.fromRGB(150, 108, 104)
	else
		grade.Tint = Color3.fromRGB(128, 128, 128)
	end

	-- bloom: the cells and the eyes are the only clean light in this place
	self.bloom.Intensity = 0.45 + dread * 0.55 + (self.dropOut > 0 and 0.6 or 0)

	-- blur: vision tunnels as it closes in, and while you hold still in a locker
	local target = dread * Config.Effects.BlurMax + (hidden and 5 or 0)
	if phase == "intermission" then
		target = 0
	end
	self.blur.Size = Util.damp(self.blur.Size, target, 0.24, dt)

	-- vignette
	local vign = Util.clamp(0.16 + dread * Config.Effects.VignetteMax, 0, 1)
	if math.abs(vign - (self.lastVign or -1)) > 0.02 then
		self.lastVign = vign
		self.vignetteGrad.Transparency = vignetteSequence(vign)
	end

	-- interference bars
	local grain = Util.clamp((dread - 0.2) * 1.4 + (battery < Config.Light.FlickerStart and 0.12 or 0) + (self.dropOut or 0), 0, 1)
	if grain > 0.01 then
		for i, bar in ipairs(self.bars) do
			local seed = self.barSeeds[i]
			local n = noise(seed, self.time * (1.6 + grain * 5), 0.5)
			bar.BackgroundTransparency = 1 - grain * (0.28 + 0.4 * math.abs(n))
			bar.Position = UDim2.new(0, 0, (n * 0.5 + 0.5), 0)
			bar.Size = UDim2.new(1, 0, 0, 1 + math.floor(math.abs(noise(seed + 4, self.time * 3, 0)) * 4))
		end
	else
		if not self.barsHidden then
			self.barsHidden = true
			for _, bar in ipairs(self.bars) do
				bar.BackgroundTransparency = 1
			end
		end
	end
	if grain > 0.01 then
		self.barsHidden = false
	end

	-- fog tightens with panic, which is the cheapest way to make the flashlight feel
	-- like the only thing between you and a black screen. Lighting is one of the
	-- filtered services, so these writes stay local to this client.
	local lighting = self.lighting
	local fog = Config.Effects.FogEnd - dread * 26
	if math.abs((self.lastFog or 0) - fog) > 2 then
		self.lastFog = fog
		lighting.FogEnd = fog
		lighting.FogStart = Config.Effects.FogStart
	end
	if purge then
		lighting.FogColor = Config.Effects.PurgeFogColor
	else
		lighting.FogColor = Config.Effects.FogColor
	end

	-- fade (BackgroundTransparency: 1 = clear screen, 0 = fully covered)
	if self.fadeTarget then
		local current = self.dark.BackgroundTransparency
		local goal = self.fadeTarget
		local value = current + (goal - current) * math.min(1, dt * self.fadeSpeed)
		if math.abs(value - goal) < 0.02 then
			value = goal
			self.fadeTarget = nil
		end
		self.dark.BackgroundTransparency = value
	end
end

function Effects:destroy()
	for _, inst in ipairs({ self.color, self.bloom, self.blur }) do
		if inst then
			inst:Destroy()
		end
	end
end

return Effects
