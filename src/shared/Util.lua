--[[
	Util - small shared helpers.

	Safe to require from both sides. Anything touching the DataModel is guarded so
	these stay usable in plain Lua too (the maze test harness imports nothing from
	here, but designers often do).
]]

local Util = {}

function Util.clamp(v, lo, hi)
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

--- Frame-rate independent exponential smoothing. `halfLife` is how long an error
--- takes to shrink to half, in seconds.
function Util.damp(current, target, halfLife, dt)
	if halfLife <= 0 then
		return target
	end
	return Util.lerp(current, target, 1 - 0.5 ^ (dt / halfLife))
end

function Util.round(v, step)
	if step and step > 0 then
		return math.floor(v / step + 0.5) * step
	end
	return math.floor(v + 0.5)
end

--- mm:ss, used all over the HUD.
function Util.formatTime(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

--- 128 studs -> "26 m" so the compass reads like a facility, not a baseplate.
function Util.studsToMeters(studs)
	return math.floor(studs * 0.2 + 0.5)
end

function Util.percent(v)
	return math.floor(Util.clamp(v, 0, 100) + 0.5) .. "%"
end

--- Random element without disturbing a caller's math.random sequence.
function Util.pick(list, rng)
	if #list == 0 then
		return nil
	end
	if rng then
		return list[rng.int(#list)]
	end
	return list[math.random(#list)]
end

function Util.shuffle(list, rng)
	for i = #list, 2, -1 do
		local j = (rng and rng.int(i)) or math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

--- Squared planar distance (no Y), used constantly by the AI.
function Util.dist2D(a, b)
	local dx, dz
	if typeof and typeof(a) == "Vector3" then
		dx, dz = a.X - b.X, a.Z - b.Z
	else
		dx, dz = a[1] - b[1], a[2] - b[2]
	end
	return dx * dx + dz * dz
end

function Util.safeParent(instance, parent)
	if parent then
		instance.Parent = parent
	end
	return instance
end

--- Instance.new with a property table, the one syntax worth keeping around.
function Util.new(className, props)
	local inst = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				inst[key] = value
			end
		end
		if props.Parent then
			inst.Parent = props.Parent
		end
	end
	return inst
end

--- Deep-ish copy for config tables handed to builders.
function Util.shallowCopy(src)
	local out = {}
	for k, v in pairs(src) do
		out[k] = v
	end
	return out
end

return Util
