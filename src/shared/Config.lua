--[[
	Blacksite - shared tunables.

	Every number a designer would want to poke lives here. Distances are Roblox
	studs (roughly 0.2 m each) and speeds are studs per second.

	Nothing in this module may touch the DataModel, so it stays require-able from
	both sides and testable from plain Lua.
]]

local Config = {}

Config.Meta = {
	Title = "BLACKSITE",
	Subtitle = "SIGNAL LOST",
	Version = "1.0.0",
	-- Rotating this reshapes every maze on the next server start.
	SeedSalt = "blacksite-v1",
}

---------------------------------------------------------------------------
-- world
---------------------------------------------------------------------------

Config.World = {
	CellsWide = 21, -- grid is (2*CellsWide-1) tiles across, so 41 here
	CellsDeep = 21,
	Tile = 12, -- corridor width, in studs
	WallHeight = 11,
	RoofHeight = 26,
	Rooms = 6,
	Braid = 0.55, -- how many dead ends get opened into loops
	FloorColor = Color3.fromRGB(26, 27, 30),
	RoofColor = Color3.fromRGB(18, 19, 21),
	-- Small per-tile colour jitter keeps flat concrete from looking like a shoebox.
	WallPalette = {
		Color3.fromRGB(48, 49, 54),
		Color3.fromRGB(41, 42, 47),
		Color3.fromRGB(54, 51, 46),
		Color3.fromRGB(36, 40, 42),
	},
	WallMaterials = {
		Enum.Material.Concrete,
		Enum.Material.Slate,
		Enum.Material.CorrodedMetal,
		Enum.Material.DiamondPlate,
	},
	LobbySize = 26,
}

---------------------------------------------------------------------------
-- round flow
---------------------------------------------------------------------------

Config.Round = {
	Intermission = 18, -- seconds in the lobby before the lift drops
	Ingress = 4, -- fade-in / "you just woke up" beat
	Limit = 360, -- hard time limit before the facility purges
	PurgeWarn = 60, -- red lights + faster entity for the last minute
	ResolveTime = 8, -- results screen
	CellsNeeded = 5,
	CellsSpawned = 5,
	Batteries = 6,
	Bandages = 4,
	Lockers = 12,
	Lamps = 10,
	MinPlayerCount = 1, -- starts as soon as this many people are waiting
}

---------------------------------------------------------------------------
-- the player
---------------------------------------------------------------------------

Config.Player = {
	WalkSpeed = 16,
	SprintSpeed = 27,
	CrouchSpeed = 7.5,
	JumpEnabled = false,
	Lives = 3,
	StaminaMax = 100,
	StaminaDrain = 26,
	StaminaRegen = 15,
	StaminaRecoverLock = 0.8, -- pause before regen resumes after sprinting
	CrouchRegenBonus = 10,
	BatteryMax = 100,
	BatteryDrain = 3.1,
	BatteryFromPickup = 45,
	GrabDamage = 34,
	InvulnAfterGrab = 4.5,
	RespawnHealth = 100,
	MinSprintCost = 12, -- sprinting below this stamina is not allowed
	HoldBreathDrain = 4, -- stamina cost per second while hidden (dread, not air)
}

---------------------------------------------------------------------------
-- the Hollow
---------------------------------------------------------------------------

Config.Entity = {
	Name = "THE HOLLOW",
	Speeds = {
		patrol = 9.5,
		investigate = 14,
		hunt = 18.6,
	},
	SightRange = 96,
	CloseSenseRange = 34, -- inside this it no longer needs line of sight
	FaceAngle = 100, -- degrees of forward vision
	ContactRange = 7.5,
	AttackCooldown = 2.6,
	RepathInterval = 0.28,
	SightMemory = 4.5, -- keeps hunting for this long after losing you
	InvestigateTime = 7,
	EnragePerLife = 1.35, -- speed added for every life the team has burned
	PurgeSpeedBonus = 1.4,
	RevealHold = 1.1, -- how long it stays outlined after your light catches it
	KickInTime = 3.2, -- hunting at your locker for this long drags you out
	KickRange = 15,
	PatrolPickRadius = 9,
	TeleportCooldown = 12, -- it repositions when it has been useless for a while
	BodyColor = Color3.fromRGB(19, 19, 22),
	EyeColor = Color3.fromRGB(206, 42, 34),
	FadeTransparency = 0.62, -- unseen: barely a smudge
	RevealTransparency = 0.04,
}

---------------------------------------------------------------------------
-- noise: what the Hollow hears
---------------------------------------------------------------------------

Config.Noise = {
	Sprint = 84,
	Walk = 36,
	Crouch = 11,
	Interact = 58, -- grabbing a cell is loud
	Locker = 30,
	JogLoop = 0.42, -- how often sprinting re-emits a noise ping
	HuntGain = 1.15, -- noise radius multiplier while it is already hunting
}

-- How the 0..1 "dread" value fed to the client is assembled.
Config.Dread = {
	Radius = 105,
	HuntMult = 1,
	InvestigateMult = 0.62,
	PatrolMult = 0.36,
	ProximityFalloff = 0.55, -- weight of pure closeness vs weight of state
}

---------------------------------------------------------------------------
-- flashlight + camera feel
---------------------------------------------------------------------------

Config.Light = {
	SpotAngle = 44,
	SpotRange = 186,
	SpotBrightness = 3.4,
	SpotColor = Color3.fromRGB(252, 240, 214),
	PointBrightness = 0.42,
	PointRange = 13,
	FlickerStart = 28, -- battery percent where the beam starts to struggle
	FlickerDeath = 8,
}

Config.Camera = {
	Fov = 70,
	SprintFov = 79,
	HiddenFov = 52,
	BobFrequency = 8.5,
	BobHeight = 0.32,
	BobSide = 0.24,
	BobTurn = 0.018,
	Sway = 0.02,
	ShakeDecay = 6,
}

Config.Effects = {
	FogStart = 14,
	FogEnd = 118,
	FogColor = Color3.fromRGB(6, 7, 9),
	Ambient = Color3.fromRGB(3, 4, 6),
	PurgeFogColor = Color3.fromRGB(16, 3, 4),
	BlurMax = 6,
	VignetteMax = 0.92,
	GrainBars = 12,
	DreadShake = 1.15,
}

---------------------------------------------------------------------------
-- optional audio
---------------------------------------------------------------------------

-- Roblox has no runtime audio synthesis and this repo ships zero uploaded assets,
-- so every id starts empty and every call site is pcall-guarded. Paste rbxassetid
-- strings here (Creator Store > find a sound > copy the id) and the game instantly
-- gets footsteps, a heartbeat, stingers and the Hollow's scream.
Config.Sounds = {
	Heartbeat = "",
	Scream = "",
	Grab = "",
	FootstepConcrete = "",
	Sprint = "",
	LockerOpen = "",
	LockerClose = "",
	CellTaken = "",
	GateOpen = "",
	Alarm = "",
	Ambience = "",
	StaticLoop = "",
	Win = "",
	Lose = "",
}
Config.SoundVolumes = {
	Heartbeat = 0.55,
	Ambience = 0.4,
	Scream = 1,
	Alarm = 0.85,
}

-- SurfaceGui copy uses this; keeps text out of the Lua where possible.
Config.Copy = {
	Objective = "RECOVER THE IGNITER CELLS",
	Escaping = "THE GATE IS OPEN - RUN",
	PurgeWarn = "PURGE IN %s - LEAVE NOW",
	Hidden = "HOLD STILL",
	Found = "IT HAS YOU",
	Menu = "CLICK TO BEGIN",
}

return Config
