--[[
	Blacksite - server entry point.

	Thin on purpose: services, world setup, the remote door, and one Heartbeat beat
	that drives the round director. All gameplay decisions live in Round.lua.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local shared = game:GetService("ReplicatedStorage"):WaitForChild("Blacksite")
local Config = require(shared:WaitForChild("Config"))
local Remotes = require(shared:WaitForChild("Remotes"))

local container = script.Parent
local MapBuilder = require(container:WaitForChild("MapBuilder"))
local Round = require(container:WaitForChild("Round"))

---------------------------------------------------------------------------
-- world setup
--
-- Everything here is set from code instead of saved into the place file, so the
-- .rbxlx stays a thin container for scripts and can be regenerated at any time.
---------------------------------------------------------------------------

local function setupAtmosphere()
	local fx = Config.Effects
	Lighting.Ambient = fx.Ambient
	Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.FogColor = fx.FogColor
	Lighting.FogStart = fx.FogStart
	Lighting.FogEnd = fx.FogEnd
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0

	-- Future technology is what makes the flashlight's shadows and per-pixel
	-- lighting work; Legacy would flatten the whole beam mechanic into a foggy mush.
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	pcall(function()
		Lighting.ShadowSoftness = 0.45
	end)
	pcall(function()
		local air = Lighting:FindFirstChild("BlacksiteAir") or Instance.new("Atmosphere")
		air.Name = "BlacksiteAir"
		air.Density = 0.3
		air.Offset = Vector3.new(0, -2, 0)
		air.Color = Color3.fromRGB(24, 26, 30)
		air.Decay = Color3.fromRGB(12, 12, 14)
		air.Glare = 0
		air.Haze = 1.2
		air.Parent = Lighting
	end)
end

local function setupWorkspace()
	Workspace.StreamingEnabled = false

	local root = Workspace:FindFirstChild("BlacksiteRoot")
	if not root then
		root = Instance.new("Folder")
		root.Name = "BlacksiteRoot"
		root.Parent = Workspace
	end

	-- A valid spawn is required before the first round moves anyone anywhere.
	if not Workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "BlacksiteSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(24, 1, 24)
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Parent = Workspace
	end

	return root
end

local root = setupWorkspace()
setupAtmosphere()

local remotes = Remotes.ensure()
local lobby = MapBuilder.buildLobby(root, { y = -120 })

local spawnLocation = Workspace:FindFirstChild("BlacksiteSpawn")
if spawnLocation then
	spawnLocation.Position = Vector3.new(0, lobby.y - 1, 0)
end

-- The round loop owns respawning: lives, airlock redeploy, elimination.
Players.CharacterAutoLoads = false

local round = Round.new({
	root = root,
	remotes = remotes,
	lobby = lobby,
})

root:SetAttribute("Version", Config.Meta.Version)
root:SetAttribute("Title", Config.Meta.Title)
root:SetAttribute("Studio", RunService:IsStudio())

---------------------------------------------------------------------------
-- players
---------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	round:attach(player)

	-- Anyone arriving mid-round waits in staging like the rest of the crew.
	if round.phase ~= "intermission" then
		task.defer(function()
			local st = round.players[player]
			if st and not st.joined then
				round:placeCharacter(player, st, true)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	round:detach(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	round:attach(player)
end

---------------------------------------------------------------------------
-- the remote door
---------------------------------------------------------------------------

-- Server-side only rate limit. Kept off the Player instance on purpose: an attribute
-- used as a throttle would replicate to every client 20 times a second.
local actionStamp = {}

remotes.Action.OnServerEvent:Connect(function(player, action, arg, arg2)
	if typeof(action) ~= "string" then
		return
	end
	local now = tick()
	-- Default far in the past: with `or 0` the very first action of a session - the
	-- one that asks for the lift - would be swallowed by the throttle.
	local last = actionStamp[player] or -1e9
	if now - last < 0.05 then
		return
	end
	actionStamp[player] = now
	round:action(player, action, arg, arg2)
end)

Players.PlayerRemoving:Connect(function(player)
	actionStamp[player] = nil
end)

---------------------------------------------------------------------------
-- the beat
---------------------------------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
	round:update(dt)
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		task.wait(0.2)
	end
end)
