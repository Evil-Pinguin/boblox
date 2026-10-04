--[[
	Attributes - the replication layer.

	Rather than streaming a table of HUD numbers over a RemoteEvent every tick, the
	server writes them onto the Player and round Folder as attributes and the client
	just reads them. This module exists so nothing writes an attribute without first
	checking that it changed - an unthrottled SetAttribute at 20 Hz is 20 packets per
	property per player, which is how horror games turn into lag simulators.
]]

local Attributes = {}

local EPSILON = 0.02

--- Write a number/string/bool attribute only if it meaningfully changed.
function Attributes.set(inst, name, value, tolerance)
	if not inst then
		return
	end

	local old = inst:GetAttribute(name)

	if type(value) == "number" and type(old) == "number" then
		if math.abs(old - value) < (tolerance or EPSILON) then
			return
		end
	elseif old == value then
		return
	end

	inst:SetAttribute(name, value)
end

function Attributes.get(inst, name, default)
	if not inst then
		return default
	end
	local value = inst:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

--- Convenience for the client: read a number attribute with a fallback.
function Attributes.num(inst, name, default)
	local value = inst and inst:GetAttribute(name)
	if type(value) ~= "number" then
		return default or 0
	end
	return value
end

return Attributes
