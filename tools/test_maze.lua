-- Pure-Lua test suite for MazeGen. Run with:  python3 tools/test_maze.py
-- The driver inlines src/shared/MazeGen.lua and appends this file, so `MazeGen`
-- is already in scope. Any failed assert aborts with a Lua error.

local pass, checked = 0, 0
local function ok(cond, msg)
	checked = checked + 1
	if not cond then
		error("[FAIL] " .. msg, 0)
	end
	pass = pass + 1
end

local function build(seed, wide, deep, rooms)
	return MazeGen.new({
		cellsWide = wide or 21,
		cellsDeep = deep or 21,
		seed = seed,
		braid = 0.55,
		rooms = rooms or 6,
	})
end

local function runSeeds(fn, count, seedStep)
	seedStep = seedStep or 7919
	for i = 1, count do
		fn(build(i * seedStep), i)
	end
end

---------------------------------------------------------------------
-- 1. determinism: same seed -> same maze, different seed -> different maze
---------------------------------------------------------------------
local a = build(4242, 9, 9, 3)
local b = build(4242, 9, 9, 3)
local c = build(4243, 9, 9, 3)
ok(a:toString() == b:toString(), "same seed must produce an identical maze")
ok(a:toString() ~= c:toString(), "different seed should produce a different maze")
ok(MazeGen.hashString("blacksite-v1") == MazeGen.hashString("blacksite-v1"), "hash must be stable")
ok(MazeGen.hashString("blacksite-v1") ~= MazeGen.hashString("blacksite-v2"), "hash must vary with input")

---------------------------------------------------------------------
-- 2. connectivity: every cell reachable from the airlock (12 seeds)
---------------------------------------------------------------------
runSeeds(function(maze, seed)
	local dist = maze:flowField(maze.entryX, maze.entryY)
	ok(dist ~= nil, "flow field from the entry must exist (seed " .. seed .. ")")
	local cells = 0
	for gy = 1, maze.gridH, 2 do
		for gx = 1, maze.gridW, 2 do
			ok(maze:walkable(gx, gy), "cell " .. gx .. "," .. gy .. " must be open (seed " .. seed .. ")")
			ok(dist[gy][gx] ~= nil, "cell " .. gx .. "," .. gy .. " unreachable (seed " .. seed .. ")")
			cells = cells + 1
		end
	end
	ok(cells == maze.cellsWide * maze.cellsDeep, "expected every cell to be visited")
end, 12)

---------------------------------------------------------------------
-- 3. structural invariants
---------------------------------------------------------------------
runSeeds(function(maze, seed)
	ok(maze.gridW == maze.cellsWide * 2 - 1, "grid width must be 2W-1")
	ok(maze.gridH == maze.cellsDeep * 2 - 1, "grid height must be 2D-1")
	ok(maze:isSolid(0, 5) and maze:isSolid(maze.gridW + 1, 5), "virtual border must read as solid")
	ok(maze:isSolid(5, 0) and maze:isSolid(5, maze.gridH + 1), "virtual border must read as solid (vertical)")
	ok(maze:walkable(maze.entryX, maze.entryY), "entry airlock tile must be open")
	ok(maze:walkable(2, 1) == (not maze.solid[1][2]), "walkable must agree with solid")
end, 4)

---------------------------------------------------------------------
-- 4. line of sight agrees with the grid
---------------------------------------------------------------------
runSeeds(function(maze, seed)
	local pairs, blockedByWall = 0, 0
	for gy = 1, maze.gridH do
		for gx = 1, maze.gridW - 2 do
			if maze:walkable(gx, gy) and maze:walkable(gx + 2, gy) then
				local expected = not maze:isSolid(gx + 1, gy)
				local got = maze:lineOfSight(gx, gy, gx + 2, gy)
				ok(got == expected, "LOS across one wall tile wrong at " .. gx .. "," .. gy .. " (seed " .. seed .. ")")
				if not expected then
					blockedByWall = blockedByWall + 1
				end
				pairs = pairs + 1
			end
		end
	end
	ok(pairs > 60, "sanity: LOS test covered plenty of corridor pairs")
	ok(blockedByWall > 5, "sanity: LOS test covered wall-blocked pairs")

	-- A wall between two tiles always blocks, even on a longer line.
	for gy = 2, maze.gridH - 1 do
		for gx = 2, maze.gridW - 1 do
			if maze:isSolid(gx, gy) and maze:walkable(gx - 1, gy) and maze:walkable(gx + 1, gy) then
				ok(not maze:lineOfSight(gx - 1, gy, gx + 1, gy), "wall must block LOS at " .. gx .. "," .. gy)
			end
		end
	end

	-- Open sight down a corridor must survive a long distance.
	local far = maze:lineOfSight(1, maze.entryY, maze.gridW, maze.entryY)
	if far then
		for gx = 2, maze.gridW - 1 do
			ok(not maze:isSolid(gx, maze.entryY), "long LOS implies a clear row (seed " .. seed .. ")")
		end
	end
end, 4)

---------------------------------------------------------------------
-- 5. flow field descent steps downhill by exactly 1 and reaches the target
---------------------------------------------------------------------
runSeeds(function(maze, seed)
	local tx, ty = 13, 17
	local dist = maze:flowField(tx, ty)
	ok(dist ~= nil and dist[ty][tx] == 0, "target distance must be zero")
	local x, y = 1, 1
	local steps = 0
	while dist[y] and dist[y][x] ~= nil and dist[y][x] > 0 do
		local before = dist[y][x]
		local nx, ny = maze:descend(dist, x, y)
		ok(nx ~= nil, "descend must find a downhill step (seed " .. seed .. ")")
		ok(dist[ny][nx] == before - 1, "descend must reduce distance by exactly 1 (seed " .. seed .. ")")
		ok(maze:walkable(nx, ny), "descend must stay on walkable tiles")
		x, y = nx, ny
		steps = steps + 1
		if steps > 20000 then
			error("descend looped forever")
		end
	end
	ok(x == tx and y == ty, "greedy descent must arrive at the target (seed " .. seed .. ")")
	ok(dist[1][1] == steps, "path length must equal the flow distance (seed " .. seed .. ")")

	-- descend at the target is a no-op, and unreachable targets report nil
	ok(maze:descend(dist, tx, ty) == nil, "descend at the target must return nil")
	ok(maze:descend(nil, 1, 1) == nil, "descend with no field must return nil")
end, 6)

---------------------------------------------------------------------
-- 6. greedy meshing covers the solid set exactly and compresses it
---------------------------------------------------------------------
runSeeds(function(maze, seed)
	local rects = maze:solidRects()
	local cover, total = {}, 0
	for gy = 1, maze.gridH do
		cover[gy] = {}
		for gx = 1, maze.gridW do
			if maze:isSolid(gx, gy) then
				total = total + 1
			end
		end
	end

	local sum = 0
	for i = 1, #rects do
		local r = rects[i]
		ok(r.w > 0 and r.h > 0, "rect must have positive extent")
		for dy = 0, r.h - 1 do
			for dx = 0, r.w - 1 do
				local gx, gy = r.gx + dx, r.gy + dy
				ok(maze:isSolid(gx, gy), "rect covers a non-solid tile (seed " .. seed .. ")")
				ok(not cover[gy][gx], "rects must not overlap, clash at " .. gx .. "," .. gy .. " (seed " .. seed .. ")")
				cover[gy][gx] = true
				sum = sum + 1
			end
		end
	end
	ok(sum == total, "rects must cover every solid tile exactly once (seed " .. seed .. ")")
	local ratio = #rects / math.max(1, total)
	print(string.format("  mesh: %d solid tiles -> %d boxes (%.0f%% of naive)", total, #rects, ratio * 100))
	ok(ratio < 0.75, "greedy meshing should cut the part count well below naive")
end, 4)

---------------------------------------------------------------------
-- 7. tile <-> world round trip
---------------------------------------------------------------------
runSeeds(function(maze, seed)
	local tile = 12
	for _ = 1, 400 do
		local gx = maze.rng.int(maze.gridW)
		local gy = maze.rng.int(maze.gridH)
		local wx, wz = maze:tileToWorld(gx, gy, tile)
		local rx, ry = maze:worldToTile(wx, wz, tile)
		ok(rx == gx and ry == gy, "world/tile round trip broke at " .. gx .. "," .. gy .. " (seed " .. seed .. ")")
		-- Anywhere inside the tile (up to half a tile off centre) must still map back.
		local jitter = (maze.rng.float() - 0.5) * (tile - 0.2)
		rx, ry = maze:worldToTile(wx + jitter, wz - jitter, tile)
		ok(rx == gx and ry == gy, "jittered position must map to the same tile")
	end
end, 4)

---------------------------------------------------------------------
-- 8. rooms are carved and centred on open floor
---------------------------------------------------------------------
do
	local maze = build(99, 15, 15, 5)
	ok(#maze.rooms == 5, "should have carved the requested number of rooms")
	for i = 1, #maze.rooms do
		local room = maze.rooms[i]
		ok(maze:walkable(room.cx, room.cy), "room centre must be open floor")
		ok(room.gx0 % 2 == 1 and room.gy0 % 2 == 1, "room corners must sit on cell centres")
		ok(room.gx1 <= maze.gridW and room.gy1 <= maze.gridH, "room must stay in bounds")
		for gy = room.gy0, room.gy1 do
			for gx = room.gx0, room.gx1 do
				ok(maze:walkable(gx, gy), "room interior must be fully carved")
			end
		end
	end
end

---------------------------------------------------------------------
-- 9. shuffledOpenTiles returns only walkable tiles
---------------------------------------------------------------------
do
	local maze = build(7777, 11, 11, 3)
	local tiles = maze:shuffledOpenTiles()
	ok(#tiles == maze:openCount(), "shuffled list must cover every open tile")
	for i = 1, #tiles do
		ok(maze:walkable(tiles[i][1], tiles[i][2]), "shuffled list must not contain solid tiles")
	end
end

---------------------------------------------------------------------
-- 10. perf smoke test: build + 400 flow fields must stay trivial for 20 Hz
---------------------------------------------------------------------
do
	local maze = build(555, 21, 21, 6)
	local t0 = os and os.clock and os.clock() or 0
	local fieldCount = 400
	for i = 1, fieldCount do
		maze:flowField(1 + (i % maze.gridW), 1 + ((i * 7) % maze.gridH))
	end
	local dt = (os and os.clock) and (os.clock() - t0) or 0
	if dt > 6 then
		error("400 flow fields took " .. dt .. "s - too slow for a 20 Hz server tick")
	end
	print(string.format("  perf: %d flow fields on a %dx%d grid in %.3fs", fieldCount, maze.gridW, maze.gridH, dt))
end

print(string.format("MazeGen: %d/%d checks passed", pass, checked))
