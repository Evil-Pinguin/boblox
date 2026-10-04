--[[
	MazeGen - deterministic, dependency-free maze generator.

	Deliberately pure Lua (no Roblox globals) so it can be unit-tested outside of
	Studio (see tools/test_maze.py). Everything works on a GRID of tiles:

		+-----------------------------> gx
		|   . # . # . # .                 odd,odd   = cell (always open, walkable)
		|   # # # # # #                   even,*    = wall between two cells
		|   . # . . . #                   out of range = solid (virtual border)
		|   # # # # # #
		|   . # . # . #
		v   . # . # . .
		gy

		gx ranges 1..(2*cellsWide-1), gy ranges 1..(2*cellsDeep-1). Wall thickness and
		corridor width are both one tile, which keeps every query (line of sight,
		pathfinding, world<->tile conversion) integer and cheap.

	World mapping: gx -> Roblox X, gy -> Roblox Z.
]]

local MazeGen = {}
MazeGen.__index = MazeGen

-- 32-bit LCG (numerical recipes). The largest intermediate product is
-- 1664525 * 4294967296 ~= 7.15e15, which is still exact in a Lua double, so the
-- modulo is precise. Do not raise the multiplier without re-checking that.
local function makeRng(seed)
	local s = math.floor(seed) % 4294967296
	if s < 0 then
		s = s + 4294967296
	end
	local function nextU32()
		s = (s * 1664525 + 1013904223) % 4294967296
		return s
	end
	return {
		next = nextU32,
		float = function()
			return nextU32() / 4294967296
		end,
		int = function(n)
			if n < 1 then
				n = 1
			end
			return nextU32() % n + 1
		end,
		chance = function(p)
			return nextU32() / 4294967296 < p
		end,
	}
end

--- Stable string -> int, so a shared round seed can be derived from a place id.
function MazeGen.hashString(str)
	local h = 2166136261
	for i = 1, #str do
		h = (h * 31 + string.byte(str, i)) % 2147483647
	end
	return h
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

--- opts = { cellsWide, cellsDeep, seed, braid, rooms }
function MazeGen.new(opts)
	opts = opts or {}
	local cellsWide = math.max(3, math.floor(opts.cellsWide or 21))
	local cellsDeep = math.max(3, math.floor(opts.cellsDeep or 21))

	local self = setmetatable({}, MazeGen)
	self.cellsWide = cellsWide
	self.cellsDeep = cellsDeep
	self.gridW = cellsWide * 2 - 1
	self.gridH = cellsDeep * 2 - 1
	self.tileScale = 1
	self.rng = makeRng(opts.seed or 1337)

	self.solid = {}
	for gy = 1, self.gridH do
		local row = {}
		for gx = 1, self.gridW do
			-- Cells are open, everything between them starts out solid.
			row[gx] = (gx % 2 == 0) or (gy % 2 == 0)
		end
		self.solid[gy] = row
	end

	self:dig()
	self:braid(opts.braid or 0.55)
	self:carveRooms(opts.rooms or 5)

	-- Airlock tile: middle of the west edge. The exit gate is built here, so the
	-- objective loop is always "go deep, come back".
	self.entryX = 1
	self.entryY = 2 * math.floor(self.cellsDeep / 2) + 1
	if self.entryY > self.gridH then
		self.entryY = self.gridH
	end
	self.solid[self.entryY][self.entryX] = false

	return self
end

--- Randomised depth-first search: carve a spanning tree over the cells, opening
--- the wall tile between each pair of cells we step to.
function MazeGen:dig()
	local rng = self.rng
	local visited = {}
	for gy = 1, self.gridH do
		visited[gy] = {}
	end

	local stack = { { 1, 1 } }
	visited[1][1] = true

	while #stack > 0 do
		local cur = stack[#stack]
		local cx, cy = cur[1], cur[2]

		-- Fisher-Yates over the four cell steps.
		local dirs = { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }
		for i = #dirs, 2, -1 do
			local j = rng.int(i)
			dirs[i], dirs[j] = dirs[j], dirs[i]
		end

		local advanced = false
		for i = 1, 4 do
			local dx, dy = dirs[i][1], dirs[i][2]
			local nx, ny = cx + dx, cy + dy
			local inside = nx >= 1 and ny >= 1 and nx <= self.gridW and ny <= self.gridH
			if inside and not visited[ny][nx] then
				visited[ny][nx] = true
				self.solid[cy + dy / 2][cx + dx / 2] = false
				table.insert(stack, { nx, ny })
				advanced = true
				break
			end
		end

		if not advanced then
			table.remove(stack)
		end
	end
end

--- Braid: knock out some dead ends so a chase can loop instead of ending in a trap.
function MazeGen:braid(amount)
	if not amount or amount <= 0 then
		return
	end
	local rng = self.rng
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for cy = 1, self.gridH, 2 do
		for cx = 1, self.gridW, 2 do
			local open = 0
			local closed = {}
			for i = 1, 4 do
				local ox, oy = offsets[i][1], offsets[i][2]
				local nx, ny = cx + ox * 2, cy + oy * 2
				if nx >= 1 and ny >= 1 and nx <= self.gridW and ny <= self.gridH then
					if self.solid[cy + oy][cx + ox] then
						table.insert(closed, { cx + ox, cy + oy })
					else
						open = open + 1
					end
				end
			end
			if open <= 1 and #closed > 0 and rng.chance(amount) then
				local pick = closed[rng.int(#closed)]
				self.solid[pick[2]][pick[1]] = false
			end
		end
	end
end

--- Replace a block of walls with an open hall. Rooms are where props go.
function MazeGen:carveRooms(count)
	self.rooms = {}
	if not count or count <= 0 then
		return self.rooms
	end
	local rng = self.rng
	for _ = 1, count do
		local w = rng.int(2) + 1 -- 2..3 cells
		local h = rng.int(2) + 1
		local ci = rng.int(math.max(1, self.cellsWide - w + 1)) - 1
		local cj = rng.int(math.max(1, self.cellsDeep - h + 1)) - 1
		local x0, y0 = ci * 2 + 1, cj * 2 + 1
		local x1, y1 = (ci + w - 1) * 2 + 1, (cj + h - 1) * 2 + 1
		for y = y0, y1 do
			for x = x0, x1 do
				if x >= 1 and y >= 1 and x <= self.gridW and y <= self.gridH then
					self.solid[y][x] = false
				end
			end
		end
		table.insert(self.rooms, {
			gx0 = x0,
			gy0 = y0,
			gx1 = x1,
			gy1 = y1,
			w = x1 - x0 + 1,
			h = y1 - y0 + 1,
			cx = math.floor((x0 + x1) / 2),
			cy = math.floor((y0 + y1) / 2),
		})
	end
	return self.rooms
end

---------------------------------------------------------------------------
-- queries
---------------------------------------------------------------------------

function MazeGen:inBounds(gx, gy)
	return gx >= 1 and gy >= 1 and gx <= self.gridW and gy <= self.gridH
end

--- Out of bounds counts as solid: the virtual border keeps everything inside.
function MazeGen:isSolid(gx, gy)
	if not self:inBounds(gx, gy) then
		return true
	end
	return self.solid[gy][gx]
end

function MazeGen:walkable(gx, gy)
	return self:inBounds(gx, gy) and not self.solid[gy][gx]
end

function MazeGen:setSolid(gx, gy, value)
	if self:inBounds(gx, gy) then
		self.solid[gy][gx] = not not value
	end
end

--- Grid -> world (Roblox X / Z) for a tile centre.
function MazeGen:tileToWorld(gx, gy, tile)
	return (gx - (self.gridW + 1) / 2) * tile, (gy - (self.gridH + 1) / 2) * tile
end

--- World (Roblox X / Z) -> grid tile.
function MazeGen:worldToTile(wx, wz, tile)
	return math.floor(wx / tile + (self.gridW + 1) / 2 + 0.5),
			math.floor(wz / tile + (self.gridH + 1) / 2 + 0.5)
end

--- Amanatides & Woo voxel traversal between two world-space points expressed in
--- tile units. Returns false as soon as a solid tile is entered.
function MazeGen:lineOfSight(ax, ay, bx, by)
	local startX, startY = math.floor(ax + 0.5), math.floor(ay + 0.5)
	local endX, endY = math.floor(bx + 0.5), math.floor(by + 0.5)
	if startX == endX and startY == endY then
		return true
	end

	local dx, dy = bx - ax, by - ay
	local stepX = dx > 0 and 1 or (dx < 0 and -1 or 0)
	local stepY = dy > 0 and 1 or (dy < 0 and -1 or 0)
	local dtx = dx ~= 0 and math.abs(1 / dx) or math.huge
	local dty = dy ~= 0 and math.abs(1 / dy) or math.huge
	-- Inputs are tile centres, so the first boundary is half a tile away.
	local tMaxX, tMaxY = dtx * 0.5, dty * 0.5

	local maxSteps = self.gridW + self.gridH + 8
	for _ = 1, maxSteps do
		if self:isSolid(startX, startY) then
			return false
		end
		if startX == endX and startY == endY then
			return true
		end
		if tMaxX < tMaxY then
			tMaxX = tMaxX + dtx
			startX = startX + stepX
		else
			tMaxY = tMaxY + dty
			startY = startY + stepY
		end
	end
	return false
end

--- Breadth-first distance field from a target tile: every reachable tile learns how
--- far it is from the target, so a chaser only has to step downhill. O(tiles).
function MazeGen:flowField(tx, ty, blocked)
	if not self:walkable(tx, ty) then
		return nil
	end

	local dist = {}
	for gy = 1, self.gridH do
		dist[gy] = {}
	end
	dist[ty][tx] = 0

	local queueX, queueY = { tx }, { ty }
	local head = 1
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

	while head <= #queueX do
		local cx, cy = queueX[head], queueY[head]
		head = head + 1
		local base = dist[cy][cx]
		for i = 1, 4 do
			local nx, ny = cx + offsets[i][1], cy + offsets[i][2]
			if self:walkable(nx, ny) and dist[ny][nx] == nil and not (blocked and blocked(nx, ny)) then
				dist[ny][nx] = base + 1
				table.insert(queueX, nx)
				table.insert(queueY, ny)
			end
		end
	end

	return dist
end

--- One step downhill on a flow field. nil when already there or unreachable.
function MazeGen:descend(dist, x, y)
	if dist == nil or not dist[y] or dist[y][x] == nil then
		return nil
	end
	local best = dist[y][x]
	if best == 0 then
		return nil
	end
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local bx, by
	for i = 1, 4 do
		local nx, ny = x + offsets[i][1], y + offsets[i][2]
		local d = dist[ny] and dist[ny][nx]
		if d ~= nil and d < best and (bx == nil or d < dist[by][bx]) then
			bx, by = nx, ny
		end
	end
	if bx == nil then
		return nil
	end
	return bx, by
end

--- Distance from a tile to the entry airlock, or nil. Convenience for placement.
function MazeGen:distanceFromEntry()
	return self:flowField(self.entryX, self.entryY)
end

--- Greedy meshing: collapse solid tiles into as few boxes as possible so the maze
--- costs a couple hundred parts instead of a couple thousand.
--- Returns { { gx, gy, w, h }, ... } in tiles.
function MazeGen:solidRects()
	local used = {}
	for gy = 1, self.gridH do
		used[gy] = {}
	end

	local rects = {}
	for gy = 1, self.gridH do
		for gx = 1, self.gridW do
			if self.solid[gy][gx] and not used[gy][gx] then
				local w = 1
				while gx + w <= self.gridW and self.solid[gy][gx + w] and not used[gy][gx + w] do
					w = w + 1
				end
				local h = 1
				local growing = true
				while growing and gy + h <= self.gridH do
					for i = 0, w - 1 do
						if not (self.solid[gy + h][gx + i] and not used[gy + h][gx + i]) then
							growing = false
							break
						end
					end
					if growing then
						h = h + 1
					end
				end
				for yy = 0, h - 1 do
					for xx = 0, w - 1 do
						used[gy + yy][gx + xx] = true
					end
				end
				table.insert(rects, { gx = gx, gy = gy, w = w, h = h })
			end
		end
	end
	return rects
end

--- Every open tile, shuffled. Handy for scattering props without repeats.
function MazeGen:shuffledOpenTiles()
	local out = {}
	for gy = 1, self.gridH do
		for gx = 1, self.gridW do
			if not self.solid[gy][gx] then
				table.insert(out, { gx, gy })
			end
		end
	end
	local rng = self.rng
	for i = #out, 2, -1 do
		local j = rng.int(i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

function MazeGen:openCount()
	local n = 0
	for gy = 1, self.gridH do
		for gx = 1, self.gridW do
			if not self.solid[gy][gx] then
				n = n + 1
			end
		end
	end
	return n
end

--- ASCII render, used by the test harness and by `tools/preview_maze.py`.
function MazeGen:toString()
	local lines = {}
	for gy = 1, self.gridH do
		local chars = {}
		for gx = 1, self.gridW do
			chars[gx] = self.solid[gy][gx] and "#" or "."
		end
		table.insert(lines, table.concat(chars))
	end
	return table.concat(lines, "\n")
end

return MazeGen
