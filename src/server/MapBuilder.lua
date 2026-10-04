--[[
	MapBuilder - procedurally builds the facility out of primitives.

	Everything is authored at runtime from the maze grid, which is what makes every
	round a different floorplan without anyone hand-placing a part. It also keeps the
	shipped place file tiny: the .rbxlx holds scripts, not geometry.

	Three rules keep this cheap and safe:
	  * walls are greedy-merged boxes, so a 41x41 grid costs ~250 parts, not ~750
	  * decorative clutter never collides, so it can never trap a player
	  * gameplay props only ever live on grid tiles, so the AI's tile maths stay exact
]]

local TweenService = game:GetService("TweenService")

--[[ Shared modules live in ReplicatedStorage.Blacksite. Addressed through the service rather
     than script.Parent.Parent, because these folders are siblings, not ancestors. ]]
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Blacksite")
local Config = require(shared:WaitForChild("Config"))
local MazeGen = require(shared:WaitForChild("MazeGen"))

local MapBuilder = {}
MapBuilder.__index = MapBuilder

local noise = math.noise or function()
	return 0
end

local CLOSED_PAD = Color3.fromRGB(74, 22, 22)
local OPEN_PAD = Color3.fromRGB(74, 226, 158)

---------------------------------------------------------------------------
-- primitive helpers
---------------------------------------------------------------------------

--- Axis-aligned box from two corners. The only geometry primitive needed here.
local function box(parent, a, b, opts)
	opts = opts or {}
	local size = b - a
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))
	part.CFrame = CFrame.new((a + b) / 2)
	part.Name = opts.Name or "Box"
	part.Material = opts.Material or Enum.Material.Concrete
	part.Color = opts.Color or Config.World.WallPalette[1]
	part.CanCollide = opts.CanCollide ~= false
	part.CanQuery = opts.CanQuery ~= false
	part.CastShadow = opts.CastShadow == true
	part.Transparency = opts.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	if opts.Tag then
		part:SetAttribute("Tag", opts.Tag)
	end
	part.Parent = parent
	return part
end

--- Deterministic 0..1 value from two grid coords, for colour / material variety.
--  Plain arithmetic (no Luau bit operators) so this file can also be parsed by the
--  Lua 5.1 tooling in tools/.
local function tileHash(gx, gy)
	local h = (gx * 73856093 + gy * 19349663) % 1048576
	return h / 1048576
end

local function tileColor(gx, gy)
	local palette = Config.World.WallPalette
	return palette[math.floor(tileHash(gx, gy) * #palette) % #palette + 1]
end

local function tileMaterial(gx, gy)
	local list = Config.World.WallMaterials
	return list[math.floor(tileHash(gx + 7, gy + 3) * #list) % #list + 1]
end

--- Custom-styled prompts: the server keeps the logic, the client draws the UI.
local function prompt(parent, action, object, distance, hold)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = distance or 12
	p.HoldDuration = hold or 0
	p.RequiresLineOfSight = false
	p.RequiresFreeLook = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- build
---------------------------------------------------------------------------

--- root: Folder to build into. opts = { seed }
function MapBuilder.build(root, opts)
	opts = opts or {}
	local world = Config.World

	local maze = MazeGen.new({
		cellsWide = world.CellsWide,
		cellsDeep = world.CellsDeep,
		seed = opts.seed or 1337,
		braid = world.Braid,
		rooms = world.Rooms,
	})

	local self = setmetatable({}, MapBuilder)
	self.maze = maze
	self.seed = opts.seed or 1337
	self.tile = world.Tile
	self.wallHeight = world.WallHeight
	self.boundT = 8
	self.halfW = maze.gridW * self.tile / 2
	self.halfH = maze.gridH * self.tile / 2
	self.used = {}
	self.promptIndex = {}
	self.cells = {}
	self.supplies = {}
	self.lockers = {}
	self.lamps = {}
	self._seq = 0

	local level = Instance.new("Folder")
	level.Name = "Level"
	level.Parent = root
	self.folder = level
	-- The replicated root the client watches for round attributes. Kept separate from
	-- self.folder on purpose: parenting geometry must never move these writes.
	self.net = root

	self.folders = {}
	for _, name in ipairs({ "Walls", "Structure", "Props", "Pickups", "Lockers", "Lamps" }) do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = level
		self.folders[name] = f
	end

	self:buildFloorAndRoof()
	self:buildWalls()
	self:buildAirlock()
	self:buildPerimeter()
	self:buildProps()

	return self
end

function MapBuilder:worldOf(gx, gy, y)
	local x, z = self.maze:tileToWorld(gx, gy, self.tile)
	return Vector3.new(x, y or 0, z)
end

function MapBuilder:tileOf(position)
	return self.maze:worldToTile(position.X, position.Z, self.tile)
end

function MapBuilder:markUsed(gx, gy)
	if not self.used[gy] then
		self.used[gy] = {}
	end
	self.used[gy][gx] = true
end

function MapBuilder:isFree(gx, gy)
	if not self.maze:walkable(gx, gy) then
		return false
	end
	return not (self.used[gy] and self.used[gy][gx])
end

---------------------------------------------------------------------------

function MapBuilder:buildFloorAndRoof()
	local world = Config.World
	local pad = self.boundT + 16
	local parent = self.folders.Structure

	box(parent, Vector3.new(-self.halfW - pad, -2, -self.halfH - pad), Vector3.new(self.halfW + pad, 0, self.halfH + pad), {
		Name = "Floor",
		Material = Enum.Material.Slate,
		Color = world.FloorColor,
		Tag = "floor",
	})

	box(parent, Vector3.new(-self.halfW - pad, world.RoofHeight, -self.halfH - pad), Vector3.new(self.halfW + pad, world.RoofHeight + 4, self.halfH + pad), {
		Name = "Ceiling",
		Material = Enum.Material.CorrodedMetal,
		Color = world.RoofColor,
		Tag = "ceiling",
	})
end

function MapBuilder:buildWalls()
	local maze = self.maze
	local tile = self.tile
	local parent = self.folders.Walls

	for _, rect in ipairs(maze:solidRects()) do
		local cx, cz = maze:tileToWorld(rect.gx + (rect.w - 1) / 2, rect.gy + (rect.h - 1) / 2, tile)
		local hx = rect.w * tile / 2
		local hz = rect.h * tile / 2
		box(parent, Vector3.new(cx - hx, 0, cz - hz), Vector3.new(cx + hx, self.wallHeight, cz + hz), {
			Name = "Wall",
			Material = tileMaterial(rect.gx, rect.gy),
			Color = tileColor(rect.gx, rect.gy),
			Tag = "wall",
		})
	end
end

--- Widen the entry cell into a bay big enough for a whole team.
function MapBuilder:buildAirlock()
	local maze = self.maze
	local ex, ey = maze.entryX, maze.entryY

	for gy = ey - 2, ey + 2 do
		for gx = ex, ex + 3 do
			maze:setSolid(gx, gy, false)
		end
	end

	self.entryTile = { gx = ex + 1, gy = ey }
	self.spawnCFs = {}
	for i = -2, 2 do
		local row = math.floor((i + 2) / 2)
		self.spawnCFs[#self.spawnCFs + 1] = CFrame.new(self:worldOf(ex + 1 + row, ey + i, 4))
	end
	self.entryCFrame = CFrame.new(self:worldOf(self.entryTile.gx, self.entryTile.gy, 4))
end

--- Sealing wall with a doorway cut into the west face, plus the extraction dock.
function MapBuilder:buildPerimeter()
	local tile = self.tile
	local t = self.boundT
	local height = self.wallHeight + 10
	local parent = self.folders.Structure
	local maze = self.maze

	local westOut, westIn = -self.halfW - t, -self.halfW
	local eastIn, eastOut = self.halfW, self.halfW + t
	local northOut, northIn = -self.halfH - t, -self.halfH
	local southIn, southOut = self.halfH, self.halfH + t

	local _, gateZ = maze:tileToWorld(maze.entryX, maze.entryY, tile)
	local gapA, gapB = gateZ - tile / 2, gateZ + tile / 2
	self.gateZ = gateZ

	box(parent, Vector3.new(westOut, 0, northOut), Vector3.new(westIn, height, gapA), { Name = "Seal_N", Color = tileColor(1, 1) })
	box(parent, Vector3.new(westOut, 0, gapB), Vector3.new(westIn, height, southOut), { Name = "Seal_S", Color = tileColor(1, 9) })
	box(parent, Vector3.new(eastIn, 0, northOut), Vector3.new(eastOut, height, southOut), { Name = "Seal_E", Color = tileColor(9, 3) })
	box(parent, Vector3.new(westOut, 0, northOut), Vector3.new(eastOut, height, northIn), { Name = "Seal_W", Color = tileColor(5, 5) })
	box(parent, Vector3.new(westOut, 0, southIn), Vector3.new(eastOut, height, southOut), { Name = "Seal_S2", Color = tileColor(6, 2) })

	-- dock outside the gate
	local dockX = westOut - 26
	box(parent, Vector3.new(dockX, -2, gateZ - 14), Vector3.new(westOut + 0.5, 0, gateZ + 14), {
		Name = "Dock",
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(34, 36, 38),
	})
	box(parent, Vector3.new(dockX - 1, 0, gateZ - 15), Vector3.new(westOut, 12, gateZ - 14), {
		Name = "DockRail",
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(40, 42, 44),
	})
	box(parent, Vector3.new(dockX - 1, 0, gateZ + 14), Vector3.new(westOut, 12, gateZ + 15), {
		Name = "DockRail",
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(40, 42, 44),
	})

	self.pad = box(parent, Vector3.new(dockX + 2, 0, gateZ - 6), Vector3.new(westOut - 6, 1.2, gateZ + 6), {
		Name = "EscapePad",
		Material = Enum.Material.Neon,
		Color = CLOSED_PAD,
		Transparency = 0.25,
		Tag = "escapePad",
	})
	self.padLight = Instance.new("PointLight")
	self.padLight.Range = 36
	self.padLight.Brightness = 0.5
	self.padLight.Color = Color3.fromRGB(130, 40, 40)
	self.padLight.Shadows = false
	self.padLight.Parent = self.pad

	self.gate = box(parent, Vector3.new(westOut + 0.4, 0, gapA - 0.3), Vector3.new(westIn - 0.4, self.wallHeight + 2, gapB + 0.3), {
		Name = "BlastDoor",
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(52, 50, 46),
		Tag = "gate",
	})
	self.gateClosedPos = self.gate.Position
	self.gateOpenPos = self.gate.Position + Vector3.new(0, self.wallHeight + 14, 0)
	self.gateOpen = false

	self.escapeCFrame = CFrame.new((dockX + westOut) / 2, 3, gateZ)

	local sign = self:makeSignPart("EXTRACTION", Color3.fromRGB(200, 70, 58), Vector3.new(0.6, 4, 14))
	sign.CFrame = CFrame.new(westOut - 0.4, 8.5, gateZ) * CFrame.Angles(0, math.rad(90), 0)
end

--- Free-standing label board. SurfaceGui.CFrame is read-only, so the *part* is
--- what gets placed and the gui is stuck to its front face.
function MapBuilder:makeSignPart(text, color, size, face)
	local parent = self.folders.Structure
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Name = "Sign_" .. text
	part.Size = size
	part.Material = Enum.Material.Slate
	part.Color = Color3.fromRGB(16, 17, 19)
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.PixelsPerStud = 64
	gui.BackgroundTransparency = 1
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.Code
	label.TextColor3 = color
	label.TextTransparency = 0.08
	label.TextScaled = true
	label.Parent = gui

	return part
end

---------------------------------------------------------------------------
-- props
---------------------------------------------------------------------------

--- Score every free tile by depth from the airlock, then take the best `count`
--- with at least `separation` tiles between them. Deep + spread = no free wins.
function MapBuilder:scoredTiles(count, separation, minDepth)
	local maze = self.maze
	local field = maze:distanceFromEntry()
	local candidates = {}

	for gy = 1, maze.gridH do
		for gx = 1, maze.gridW do
			if self:isFree(gx, gy) then
				local depth = field[gy][gx]
				if depth and depth >= (minDepth or 0) then
					candidates[#candidates + 1] = { gx = gx, gy = gy, depth = depth }
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.depth == b.depth then
			return a.gx + a.gy < b.gx + b.gy
		end
		return a.depth > b.depth
	end)

	local chosen = {}
	local sep2 = (separation or 0) ^ 2
	for _, cand in ipairs(candidates) do
		if #chosen >= count then
			break
		end
		local far = true
		for _, other in ipairs(chosen) do
			local dx, dy = other.gx - cand.gx, other.gy - cand.gy
			if dx * dx + dy * dy < sep2 then
				far = false
				break
			end
		end
		if far then
			chosen[#chosen + 1] = cand
			self:markUsed(cand.gx, cand.gy)
		end
	end
	return chosen
end

function MapBuilder:buildProps()
	local round = Config.Round

	for _, spot in ipairs(self:scoredTiles(round.CellsSpawned, 12, 16)) do
		self.cells[#self.cells + 1] = self:addPickup("cell", spot.gx, spot.gy)
	end
	for _, spot in ipairs(self:scoredTiles(round.Batteries, 6, 4)) do
		self.supplies[#self.supplies + 1] = self:addPickup("battery", spot.gx, spot.gy)
	end
	for _, spot in ipairs(self:scoredTiles(round.Bandages, 6, 4)) do
		self.supplies[#self.supplies + 1] = self:addPickup("bandage", spot.gx, spot.gy)
	end

	self.lockers = self:buildLockers(round.Lockers)
	self.lamps = self:buildLamps(round.Lamps)
	self:buildClutter()
end

local PICKUP_STYLE = {
	cell = {
		size = Vector3.new(2.4, 2.4, 2.4),
		color = Color3.fromRGB(74, 226, 200),
		action = "TAKE CELL",
		object = "Igniter cell",
		light = 2.1,
		hold = 0.7,
	},
	battery = {
		size = Vector3.new(1.6, 2.2, 1.6),
		color = Color3.fromRGB(198, 206, 92),
		action = "TAKE CELL",
		object = "Spare cell",
		light = 0.8,
		hold = 0.35,
	},
	bandage = {
		size = Vector3.new(2.2, 1.2, 1.6),
		color = Color3.fromRGB(224, 224, 228),
		action = "USE MEDKIT",
		object = "Field dressing",
		light = 0.35,
		hold = 0.6,
	},
}

function MapBuilder:addPickup(kind, gx, gy)
	local style = PICKUP_STYLE[kind]
	local parent = self.folders.Pickups
	local pos = self:worldOf(gx, gy, 3.1)
	self._seq = self._seq + 1

	local part = Instance.new("Part")
	part.Name = kind .. "_" .. self._seq
	part.Anchored = true
	part.CanCollide = false
	part.Size = style.size
	part.Position = pos
	part.Material = Enum.Material.Neon
	part.Color = style.color
	part.Transparency = kind == "bandage" and 0.2 or 0
	part.CastShadow = false
	part.Parent = parent

	local light = Instance.new("PointLight")
	light.Range = kind == "cell" and 26 or 12
	light.Brightness = style.light
	light.Color = style.color
	light.Shadows = false
	light.Parent = part

	local halo
	if kind == "cell" then
		-- Slow breathe, so a cell you have not reached yet still reads as alive.
		TweenService:Create(light, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Brightness = style.light * 0.3,
		}):Play()
		halo = Instance.new("Part")
		halo.Anchored = true
		halo.CanCollide = false
		halo.CanQuery = false
		halo.Name = "Halo"
		halo.Size = Vector3.new(4.6, 4.6, 4.6)
		halo.Material = Enum.Material.Neon
		halo.Color = style.color
		halo.Transparency = 0.84
		halo.Shape = Enum.PartType.Ball
		halo.Position = pos
		halo.CastShadow = false
		halo.Parent = parent
	end

	local pr = prompt(part, style.action, style.object, 11, style.hold)
	pr:SetAttribute("kind", kind)

	local record = {
		kind = kind,
		part = part,
		halo = halo,
		light = light,
		prompt = pr,
		tile = { gx, gy },
		taken = false,
	}
	self.promptIndex[pr] = record
	return record
end

--- Consume a pickup: kill the prompt first so a held E cannot double-fire.
function MapBuilder:takePickup(pickup)
	if pickup.taken then
		return
	end
	pickup.taken = true
	if pickup.prompt then
		pickup.prompt.Enabled = false
	end
	if pickup.halo then
		pickup.halo:Destroy()
		pickup.halo = nil
	end
	if pickup.part then
		pickup.part:Destroy()
		pickup.part = nil
	end
	pickup.light = nil
end

--- Cabinets stood against a wall, one tile deep, peek camera baked into attributes.
function MapBuilder:buildLockers(count)
	local lockers = {}
	for _, spot in ipairs(self:scoredTiles(count, 5, 5)) do
		local dir = self:wallNeighbour(spot.gx, spot.gy)
		if dir then
			lockers[#lockers + 1] = self:buildLocker(spot.gx, spot.gy, dir.X, dir.Z)
		end
	end
	return lockers
end

function MapBuilder:buildLocker(gx, gy, ox, oy)
	local tile = self.tile
	local center = self:worldOf(gx, gy, 0)
	local wall = Vector3.new(ox, 0, oy) -- into the wall
	local side = Vector3.new(-wall.Z, 0, wall.X)
	local depth, width, height = 3.2, 5.6, 8.6
	local flush = tile / 2 -- back panel sits on the wall face
	local along = flush - depth / 2

	local shell = Instance.new("Model")
	shell.Name = "Locker_" .. gx .. "_" .. gy
	shell.PrimaryPart = nil
	shell.Parent = self.folders.Lockers

	local color = Color3.fromRGB(44, 48, 47)
	local mat = Enum.Material.CorrodedMetal

	local function shellPart(size, alongC, sideC, yC)
		local sx, sz = size.X, size.Z
		if ox == 0 then
			sx, sz = size.Z, size.X
		end
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(sx, size.Y, sz)
		p.CFrame = CFrame.new(center + wall * alongC + side * sideC + Vector3.new(0, yC, 0))
		p.Material = mat
		p.Color = color
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = shell
		return p
	end

	shellPart(Vector3.new(0.4, height, width), flush - 0.2, 0, height / 2) -- back
	shellPart(Vector3.new(depth, height, 0.4), along, width / 2 - 0.2, height / 2) -- left
	shellPart(Vector3.new(depth, height, 0.4), along, -width / 2 + 0.2, height / 2) -- right
	shellPart(Vector3.new(depth, 0.4, width), along, 0, height - 0.2) -- top

	local door = Instance.new("Part")
	door.Anchored = true
	door.Name = "Door"
	door.Material = Enum.Material.DiamondPlate
	door.Color = Color3.fromRGB(58, 60, 62)
	door.Transparency = 0.55
	door.CanCollide = false
	door.CastShadow = false
	local doorAlong = flush - depth - 0.15
	if ox ~= 0 then
		door.Size = Vector3.new(0.35, height - 0.4, width - 0.3)
	else
		door.Size = Vector3.new(width - 0.3, height - 0.4, 0.35)
	end
	door.CFrame = CFrame.new(center + wall * doorAlong + Vector3.new(0, height / 2, 0))
	door.Parent = shell

	local pr = prompt(door, "HIDE", "Locker", 13, 0)
	pr:SetAttribute("kind", "locker")

	local inside = center + wall * along + Vector3.new(0, 3, 0)
	local exitPos = center - wall * 2.4 + Vector3.new(0, 4, 0)
	local peekEye = center + wall * (along + 0.5) + Vector3.new(0, 4.2, 0)

	local locker = {
		model = shell,
		door = door,
		prompt = pr,
		tile = { gx, gy },
		occupied = nil,
		insideCF = CFrame.new(inside),
		exitCF = CFrame.new(exitPos),
		peekCF = CFrame.lookAt(peekEye, center - wall * 12 + Vector3.new(0, 4.2, 0)),
		wall = wall,
	}

	-- Parts are authored straight into world space, so no PivotTo here: calling it
	-- after placement would displace the whole cabinet.
	shell.PrimaryPart = door
	locker.tileKey = gx .. "_" .. gy
	if not self.lockerByTile then
		self.lockerByTile = {}
	end
	self.lockerByTile[locker.tileKey] = locker
	self.promptIndex[pr] = { kind = "locker", locker = locker }

	return locker
end

--- Ceiling lamps. Roughly a third are dying, which is the entire point of the fog.
function MapBuilder:buildLamps(count)
	local maze = self.maze
	local lamps = {}
	local spots = { { maze.entryX + 1, maze.entryY } }

	for _, room in ipairs(maze.rooms) do
		spots[#spots + 1] = { room.cx, room.cy }
		spots[#spots + 1] = { math.floor((room.gx0 + room.cx) / 2), math.floor((room.gy0 + room.cy) / 2) }
		spots[#spots + 1] = { math.floor((room.gx1 + room.cx) / 2), math.floor((room.gy1 + room.cy) / 2) }
	end
	for _, tilePos in ipairs(maze:shuffledOpenTiles()) do
		spots[#spots + 1] = tilePos
	end

	local seen = {}
	for i = 1, #spots do
		if #lamps >= count then
			break
		end
		local gx, gy = spots[i][1], spots[i][2]
		local key = gx .. "_" .. gy
		if not seen[key] and maze:walkable(gx, gy) then
			seen[key] = true
			lamps[#lamps + 1] = self:addLamp(gx, gy)
		end
	end
	return lamps
end

function MapBuilder:addLamp(gx, gy)
	local pos = self:worldOf(gx, gy, self.wallHeight - 0.9)
	local housing = box(self.folders.Lamps, pos - Vector3.new(1.6, 0.4, 1.6), pos + Vector3.new(1.6, 0.4, 1.6), {
		Name = "Lamp",
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(38, 38, 40),
		CanCollide = false,
	})

	local bulb = Instance.new("Part")
	bulb.Anchored = true
	bulb.CanCollide = false
	bulb.CanQuery = false
	bulb.Name = "Bulb"
	bulb.Size = Vector3.new(1.5, 0.5, 1.5)
	bulb.Material = Enum.Material.Neon
	bulb.Color = Color3.fromRGB(255, 224, 168)
	bulb.CFrame = CFrame.new(pos - Vector3.new(0, 0.6, 0))
	bulb.CastShadow = false
	bulb.Parent = self.folders.Lamps

	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.1
	light.Color = Color3.fromRGB(255, 226, 178)
	light.Shadows = false
	light.Parent = bulb

	local lamp = {
		light = light,
		bulb = bulb,
		housing = housing,
		base = 0.7 + tileHash(gx, gy) * 0.5,
		phase = tileHash(gx + 13, gy + 5) * 40,
		broken = tileHash(gx + 3, gy + 17) < 0.34,
		tile = { gx, gy },
	}
	if lamp.broken then
		light.Brightness = 0
		bulb.Transparency = 0.6
		bulb.Color = Color3.fromRGB(92, 88, 84)
	end
	return lamp
end

--- Pipes overhead, crates against room walls. Only the crates collide, and they are
--- always pushed into a wall so a corridor is never narrowed.
function MapBuilder:buildClutter()
	local maze = self.maze
	local tile = self.tile
	local parent = self.folders.Props

	for _, room in ipairs(maze.rooms) do
		-- one pipe run along the room's north edge
		local a = self:worldOf(room.gx0, room.gy0, self.wallHeight - 2.2)
		local b = self:worldOf(room.gx1, room.gy0, self.wallHeight - 2.2)
		local length = (b - a).Magnitude
		if length > 2 then
			local pipe = Instance.new("Part")
			pipe.Anchored = true
			pipe.CanCollide = false
			pipe.CanQuery = false
			pipe.Name = "Pipe"
			pipe.Shape = Enum.PartType.Cylinder
			pipe.Size = Vector3.new(length, 0.9, 0.9)
			pipe.CFrame = CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.rad(90))
			pipe.Material = Enum.Material.CorrodedMetal
			pipe.Color = Color3.fromRGB(52, 46, 42)
			pipe.CastShadow = false
			pipe.Parent = parent
		end

		for _, slot in ipairs({ { room.gx0, room.gy0 + 1 }, { room.gx1, room.gy1 - 1 } }) do
			local gx, gy = slot[1], slot[2]
			if maze:walkable(gx, gy) then
				local pos = self:worldOf(gx, gy, 0)
				local dir = self:wallNeighbour(gx, gy)
				if dir then
					pos = pos + dir * 3
				end
				local crate = box(parent, pos + Vector3.new(-2, 0, -2), pos + Vector3.new(2, 4, 2), {
					Name = "Crate",
					Material = Enum.Material.Wood,
					Color = Color3.fromRGB(58, 45, 33),
					Tag = "clutter",
				})
				if dir then
					crate.CFrame = crate.CFrame * CFrame.Angles(0, math.rad(tileHash(gx, gy) * 30 - 15), 0)
				end
			end
		end
	end
end

--- First solid neighbour direction, used to hug clutter against walls.
function MapBuilder:wallNeighbour(gx, gy)
	local offsets = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
	for i = 1, 4 do
		local ox, oy = offsets[i][1], offsets[i][2]
		if self.maze:isSolid(gx + ox, gy + oy) then
			return Vector3.new(ox, 0, oy)
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- runtime behaviour
---------------------------------------------------------------------------

function MapBuilder:openGate()
	if self.gateOpen then
		return
	end
	self.gateOpen = true
	self.gate.Position = self.gateOpenPos
	self.pad.Color = OPEN_PAD
	self.padLight.Color = OPEN_PAD
	self.padLight.Brightness = 2.4
	self.net:SetAttribute("GateOpen", true)
end

function MapBuilder:closeGate()
	self.gateOpen = false
	if self.gate then
		self.gate.Position = self.gateClosedPos
		self.pad.Color = CLOSED_PAD
		self.padLight.Color = Color3.fromRGB(130, 40, 40)
		self.padLight.Brightness = 0.5
	end
	self.net:SetAttribute("GateOpen", false)
end

function MapBuilder:setPurge(active)
	self.purge = active and true or false
end

--- Lamp flicker. Cheap, and it is the whole "this place is still alive" feel.
function MapBuilder:tick(time)
	for _, lamp in ipairs(self.lamps) do
		if lamp.broken then
			lamp.light.Brightness = noise(lamp.phase, time * 2.4, 0) > 0.86 and 0.9 or 0
		else
			local wobble = 0.82 + 0.18 * noise(lamp.phase, time * 1.1, 0)
			if self.purge then
				lamp.light.Color = Color3.fromRGB(196, 44, 36)
				wobble = 0.4 + 0.6 * math.abs(math.sin(time * 3 + lamp.phase))
			else
				lamp.light.Color = Color3.fromRGB(255, 226, 178)
			end
			lamp.light.Brightness = lamp.base * wobble
		end
	end
end

function MapBuilder:destroy()
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
	self.cells = {}
	self.supplies = {}
	self.lockers = {}
	self.lamps = {}
end

---------------------------------------------------------------------------
-- staging lobby (built once; lives under the map, out of the maze's sightlines)
---------------------------------------------------------------------------

function MapBuilder.buildLobby(parent, opts)
	local world = Config.World
	local size = world.LobbySize
	local optsY = (opts and opts.y) or -120

	local root = Instance.new("Folder")
	root.Name = "Lobby"
	root.Parent = parent

	box(root, Vector3.new(-size, optsY - 2, -size), Vector3.new(size, optsY, size), {
		Name = "LobbyFloor",
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(40, 42, 44),
	})
	box(root, Vector3.new(-size, optsY + world.WallHeight + 6, -size), Vector3.new(size, optsY + world.WallHeight + 9, size), {
		Name = "LobbyRoof",
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(24, 25, 27),
	})
	for _, s in ipairs({ -1, 1 }) do
		box(root, Vector3.new(-size - 1, optsY, s * size - 1), Vector3.new(size + 1, optsY + world.WallHeight + 6, s * size + 1), { Name = "LobbyWall" })
		box(root, Vector3.new(s * size - 1, optsY, -size - 1), Vector3.new(s * size + 1, optsY + world.WallHeight + 6, size + 1), { Name = "LobbyWall" })
	end

	for _, off in ipairs({ -size / 2, size / 2 }) do
		local lamp = Instance.new("Part")
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.CanQuery = false
		lamp.Size = Vector3.new(3, 0.6, 3)
		lamp.Material = Enum.Material.Neon
		lamp.Color = Color3.fromRGB(120, 230, 170)
		lamp.Position = Vector3.new(off, optsY + world.WallHeight + 4, 0)
		lamp.CastShadow = false
		lamp.Parent = root
		local light = Instance.new("PointLight")
		light.Range = 68
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(150, 240, 190)
		light.Shadows = false
		light.Parent = lamp
	end

	local board = Instance.new("Part")
	board.Anchored = true
	board.Size = Vector3.new(20, 9, 0.6)
	board.Material = Enum.Material.Slate
	board.Color = Color3.fromRGB(18, 20, 22)
	board.Position = Vector3.new(0, optsY + 7.5, -size + 1)
	board.Parent = root

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 46
	gui.BackgroundColor3 = Color3.fromRGB(8, 10, 11)
	gui.BackgroundTransparency = 0.2
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 30)
	title.Position = UDim2.new(0, 8, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextColor3 = Color3.fromRGB(140, 240, 190)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "BLACKSITE // STAGING"
	title.Parent = gui

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -16, 1, -50)
	body.Position = UDim2.new(0, 8, 0, 42)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Code
	body.TextColor3 = Color3.fromRGB(198, 202, 204)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = "waiting for crew..."
	body.Parent = gui

	return {
		root = root,
		y = optsY,
		size = size,
		boardGui = gui,
		boardBody = body,
		spawnCFs = (function()
			local list = {}
			for i = 0, 7 do
				local angle = (i / 8) * math.pi * 2
				list[#list + 1] = CFrame.new(math.cos(angle) * size / 2.2, optsY + 4, math.sin(angle) * size / 2.2)
			end
			return list
		end)(),
		centre = CFrame.new(0, optsY + 4, 0),
	}
end

return MapBuilder
