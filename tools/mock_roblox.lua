--[[
	mock_roblox.lua - just enough of the Roblox engine to run the server for real.

	This is a test rig, not an emulator: instances are property bags, events are
	lists of callbacks, and CFrame keeps yaw only (positions stay exact, which is all
	the gameplay code actually depends on). What it buys us is the ability to execute
	MapBuilder + Round + Entity against a fake server and catch the class of bug that
	syntax checking cannot see: nil indexes, misspelled methods, and logic that only
	breaks on the fourth player to die in the ninth second.
]]

local mock = {}

---------------------------------------------------------------------------
-- signals
---------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

local function newSignal(kind)
	return setmetatable({ _handlers = {}, _kind = kind or "signal" }, Signal)
end

function Signal:Connect(fn)
	local conn = { _fn = fn, _connected = true }
	table.insert(self._handlers, conn)
	return setmetatable({
		Disconnect = function(s)
			s._live._connected = false
		end,
		_live = conn,
	}, { __index = { Disconnect = function(s)
		s._live._connected = false
	end } })
end

Signal.connect = Signal.Connect

function Signal:Once(fn)
	local wrapped
	wrapped = function(...)
		fn(...)
	end
	return self:Connect(wrapped)
end

function Signal:Fire(...)
	for _, conn in ipairs(self._handlers) do
		if conn._connected then
			conn._fn(...)
		end
	end
end

function Signal:Wait()
	return nil
end

function Signal:Disconnect()
	self._handlers = {}
end

---------------------------------------------------------------------------
-- math types. Exact for everything the gameplay code actually uses: positions,
-- planar distances, yaw rotation, dot/cross.
---------------------------------------------------------------------------

local VMT
local CMT

local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, VMT)
end

local function rotYaw(v, yaw)
	if yaw == 0 then
		return v
	end
	local c, s = math.cos(yaw), math.sin(yaw)
	return vec(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end

VMT = {
	__type = "Vector3",
	__index = function(t, k)
		if k == "Magnitude" then
			return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		elseif k == "Unit" then
			local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
			if m == 0 then
				return vec(0, 0, 0)
			end
			return vec(t.X / m, t.Y / m, t.Z / m)
		elseif k == "Dot" then
			return function(a, b)
				return a.X * b.X + a.Y * b.Y + a.Z * b.Z
			end
		elseif k == "Cross" then
			return function(a, b)
				return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
			end
		end
		return rawget(t, k) or VMT[k]
	end,
	__add = function(a, b)
		return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end,
	__sub = function(a, b)
		return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end,
	__mul = function(a, b)
		if type(b) == "number" then
			return vec(a.X * b, a.Y * b, a.Z * b)
		end
		return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end,
	__div = function(a, b)
		if type(b) == "number" then
			return vec(a.X / b, a.Y / b, a.Z / b)
		end
		return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
	end,
	__unm = function(a)
		return vec(-a.X, -a.Y, -a.Z)
	end,
	__eq = function(a, b)
		return a.X == b.X and a.Y == b.Y and a.Z == b.Z
	end,
	__tostring = function(a)
		return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z)
	end,
}

Vector3 = {
	new = vec,
	zero = vec(0, 0, 0),
	xAxis = vec(1, 0, 0),
	yAxis = vec(0, 1, 0),
	zAxis = vec(0, 0, 1),
}

local function cframe(pos, rx, ry, rz)
	return setmetatable({ Position = pos, _rx = rx or 0, _ry = ry or 0, _rz = rz or 0 }, CMT)
end

CMT = {
	__type = "CFrame",
	__add = function(a, b)
		return cframe(a.Position + b, a._rx, a._ry, a._rz)
	end,
	__sub = function(a, b)
		return cframe(a.Position - b, a._rx, a._ry, a._rz)
	end,
	__mul = function(a, b)
		if b.__type == "CFrame" then
			return cframe(a.Position + rotYaw(b.Position, a._ry), a._rx + b._rx, a._ry + b._ry, a._rz + b._rz)
		end
		return a.Position + rotYaw(b, a._ry)
	end,
	__tostring = function(a)
		return "CFrame(" .. tostring(a.Position) .. ")"
	end,
}

CMT.__index = function(t, k)
	if k == "LookVector" then
		return rotYaw(vec(0, 0, -1), t._ry)
	elseif k == "RightVector" then
		return rotYaw(vec(1, 0, 0), t._ry)
	elseif k == "ToEulerAnglesYXZ" then
		return function(cf)
			return cf._rx, cf._ry, cf._rz
		end
	elseif k == "ToWorldSpace" or k == "PointToWorldSpace" then
		return function(cf, v)
			return rotYaw(v, cf._ry)
		end
	elseif k == "inverse" or k == "Orthonormalize" or k == "Perspective" then
		return function(cf)
			return cf
		end
	end
	return rawget(t, k) or CMT[k]
end

CFrame = {
	new = function(a, b, c, d, e, f)
		if type(a) == "table" and a.X ~= nil then
			return cframe(vec(a.X, a.Y, a.Z), b or 0, c or 0, d or 0)
		end
		return cframe(vec(a or 0, b or 0, c or 0), d or 0, e or 0, f or 0)
	end,
	Angles = function(rx, ry, rz)
		return cframe(vec(0, 0, 0), rx or 0, ry or 0, rz or 0)
	end,
	lookAt = function(eye, target)
		local d = target - eye
		local yaw = math.atan2(-d.X, -d.Z)
		return cframe(vec(eye.X, eye.Y, eye.Z), 0, yaw, 0)
	end,
}
CFrame.identity = cframe(vec(0, 0, 0))

Color3 = {
	fromRGB = function(r, g, b)
		return setmetatable({ R = r / 255, G = g / 255, B = b / 255,
			__tostring = function() return "Color3" end }, { __index = { __tostring = function()
			return "Color3"
		end } })
	end,
	fromHSV = function()
		return Color3.fromRGB(0, 0, 0)
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}

--- Roblox class constructors are callable *and* carry a .new; both spellings appear
--- in real code, so the mock has to answer both.
local function callable(ctor)
	local cls = { new = function(...)
		return ctor(nil, ...)
	end }
	return setmetatable(cls, { __call = function(_, ...)
		return ctor(nil, ...)
	end })
end

TweenInfo = callable(function(_, ...)
	return { _args = { ... }, Time = select(1, ...) or 1 }
end)
UDim = { new = function(s, o)
	return { Scale = s, Offset = o }
end }
UDim2 = {
	new = function(a, b, c, d)
		return { X = { Scale = a, Offset = b }, Y = { Scale = c, Offset = d } }
	end,
	fromOffset = function(x, y)
		return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
	end,
	fromScale = function(x, y)
		return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }
	end,
	fromSize = function(x, y)
		return { X = x, Y = y }
	end,
}
NumberSequence = callable(function(_, ...)
	return { _args = { ... } }
end)
NumberSequenceKeypoint = callable(function(_, t, v)
	return { Time = t, Value = v }
end)
NumberRange = callable(function(_, a, b)
	return { Min = a, Max = b }
end)
Rect = callable(function(_)
	return {}
end)

--- 2-D UI coordinates
local V2MT
local function vec2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2MT)
end
V2MT = {
	__type = "Vector2",
	__add = function(a, b)
		return vec2(a.X + b.X, a.Y + b.Y)
	end,
	__sub = function(a, b)
		return vec2(a.X - b.X, a.Y - b.Y)
	end,
	__mul = function(a, b)
		if type(b) == "number" then
			return vec2(a.X * b, a.Y * b)
		end
		return vec2(a.X * b.X, a.Y * b.Y)
	end,
	__index = function(t, k)
		if k == "Magnitude" or k == "MagnitudeSquared" then
			return math.sqrt(t.X * t.X + t.Y * t.Y)
		end
		return rawget(t, k) or V2MT[k]
	end,
}
Vector2 = {
	new = vec2,
	zero = vec2(0, 0),
	xAxis = vec2(1, 0),
	yAxis = vec2(0, 1),
}

Random = {}
do
	local RNG = {}
	RNG.__index = RNG
	function Random.new(seed)
		return setmetatable({ _r = math.random }, RNG)
	end
	function RNG:NextNumber(a, b)
		local lo, hi = a or 0, b or 1
		if a and not b then
			lo, hi = 0, a
		end
		return lo + math.random() * (hi - lo)
	end
	function RNG:NextInteger(a, b)
		return math.floor(a + math.random() * (b - a + 1))
	end
	function RNG:Unit()
		return vec2(math.random() * 2 - 1, math.random() * 2 - 1)
	end
end

ColorSequence = {
	new = function(a, b)
		if type(a) == "number" then
			return { Gamma = false, Keypoints = { { Time = 0, Value = b or a }, { Time = 1, Value = b or a } } }
		end
		return { Gamma = false, Keypoints = a or {} }
	end,
}
ColorSequenceKeypoint = {
	new = function(t, c)
		return { Time = t, Value = c }
	end,
}

-- Enum items in Roblox are objects (`.Name`, `.Value`), and code like
-- `Enum.RenderPriority.Camera.Value + 30` depends on that. Items are cached so
-- `Enum.Material.Neon == Enum.Material.Neon` holds.
local function enumItem(enumName, itemName)
	local key = tostring(itemName)
	local value = 0
	for i = 1, #key do
		value = (value + key:byte(i) * i) % 4096
	end
	return setmetatable({ Name = key, Value = value, EnumType = enumName }, {
		__tostring = function()
			return tostring(enumName) .. "." .. key
		end,
		__eq = function(a, b)
			return a.Name == b.Name and a.EnumType == b.EnumType
		end,
	})
end

Enum = setmetatable({}, {
	__index = function(t, k)
		local inner = setmetatable({}, {
			__index = function(tt, kk)
				local cache = rawget(tt, "_items")
				if not cache then
					cache = {}
					rawset(tt, "_items", cache)
				end
				local item = cache[kk]
				if not item then
					item = enumItem(k, kk)
					cache[kk] = item
				end
				return item
			end,
			__tostring = function()
				return tostring(k)
			end,
		})
		rawset(t, k, inner)
		return inner
	end,
})


---------------------------------------------------------------------------
-- instances
---------------------------------------------------------------------------

local SUPER = {
	Part = { BasePart = true, PVInstance = true, Instance = true },
	SpawnLocation = { BasePart = true, PVInstance = true, Instance = true },
	WedgePart = { BasePart = true, Instance = true },
	MeshPart = { BasePart = true, Instance = true },
	BasePart = { PVInstance = true, Instance = true },
	Model = { PVInstance = true, Instance = true },
	Folder = { Instance = true },
	Script = { LuaSourceContainer = true, Instance = true },
	LocalScript = { LuaSourceContainer = true, Instance = true },
	ModuleScript = { LuaSourceContainer = true, Instance = true },
	RemoteEvent = { Instance = true },
	ProximityPrompt = { GUIComponent = true, Instance = true },
	PointLight = { Light = true, Instance = true },
	SpotLight = { Light = true, Instance = true },
	Highlight = { ClassItem = true, Instance = true },
	SurfaceGui = { LayerCollector = true, Instance = true },
	ScreenGui = { LayerCollector = true, Instance = true },
	TextLabel = { GuiObject = true, GuiBase2d = true, Instance = true },
	Frame = { GuiObject = true, GuiBase2d = true, Instance = true },
	TextButton = { GuiButton = true, GuiObject = true, Instance = true },
	ImageLabel = { GuiImage = true, GuiObject = true, Instance = true },
	Humanoid = { Instance = true },
	Player = { Instance = true },
	Atmosphere = { Instance = true },
	BloomEffect = { PostEffect = true, Instance = true },
	BlurPostEffect = { PostEffect = true, Instance = true },
	ColorCorrectionEffect = { PostEffect = true, Instance = true },
	Attachment = { Instance = true },
	Cameras = { Instance = true },
	Camera = { PVInstance = true, Instance = true },
	UIGradient = { Instance = true },
	UIStroke = { UIComponent = true, Instance = true },
	UICorner = { UIComponent = true, Instance = true },
	UIListLayout = { UIComponent = true, Instance = true },
	Decal = { Instance = true },
	Sound = { Instance = true },
	Sparkles = { Instance = true },
	Truss = { BasePart = true, Instance = true },
	Alignment = { Instance = true },
	WrapLayer = { Instance = true },
}

local classCount = {}
local propLog = {}
mock.sentLog = {}

local function logProp(cls, key)
	local t = propLog[cls]
	if not t then
		t = {}
		propLog[cls] = t
	end
	t[key] = (t[key] or 0) + 1
end

-- Only these keys are treated as Signals. Everything else that is unknown reads
-- back as nil, so a misspelled property in the game code fails loudly here instead
-- of quietly returning an event object.
local EVENTS = {}
for _, name in ipairs({
	"Touched", "Died", "Ended", "Changed", "Destroying", "AncestryChanged",
	"ChildAdded", "ChildRemoved", "DescendantAdded",
	"OnServerEvent", "OnClientEvent", "ServerEvent", "ClientEvent",
	"PromptTriggered", "PromptButtonHoldBegan", "PromptButtonHoldEnded",
	"PromptShown", "PromptHidden", "Triggered",
	"PlayerAdded", "PlayerRemoving", "CharacterAdded", "CharacterRemoving",
	"InputBegan", "InputEnded", "Heartbeat", "RenderStepped", "Stepped",
	"MouseButton1Click", "MouseEnter", "MouseLeave", "Activated", "Deactivated", "Changed",
}) do
	EVENTS[name] = true
end

local InstanceMethods

local function newInstance(className, name)
	local self = {
		_class = className,
		_props = { Name = name or className, _sent = {}, _events = nil },
		_children = {},
		_parent = nil,
		_attrs = {},
		_events = {},
	}
	return setmetatable(self, InstanceMethods)
end

local function addChild(parent, child)
	for i, other in ipairs(parent._children) do
		if other == child then
			table.remove(parent._children, i)
			break
		end
	end
	table.insert(parent._children, child)
	child._parent = parent
	if parent._events.ChildAdded then
		parent._events.ChildAdded:Fire(child)
	end
end

InstanceMethods = {
	__index = function(inst, key)
		-- real methods
		local m = InstanceMethods[key]
		if m ~= nil and type(m) == "function" then
			return m
		end

		local props = rawget(inst, "_props")
		if props and props[key] ~= nil then
			return props[key]
		end

		-- Instance children are addressable by name in Roblox
		local kids = rawget(inst, "_children")
		if kids then
			for _, child in ipairs(kids) do
				if child._props.Name == key then
					return child
				end
			end
		end

		if EVENTS[key] then
			local events = rawget(inst, "_events")
			if not events[key] then
				events[key] = newSignal(key)
			end
			return events[key]
		end

		-- unknown and not an event: real nil, so typos surface as errors
		return nil
	end,
	__newindex = function(inst, key, value)
		if InstanceMethods[key] ~= nil and type(InstanceMethods[key]) == "function" then
			error("cannot overwrite method " .. tostring(key), 0)
		end
		-- Mirroring these two is what real parts do; MapBuilder places geometry with
	-- CFrame and then reads .Position back.
	local props = rawget(inst, "_props")
	if key == "CFrame" then
		props.CFrame = value
		if value ~= nil and value.Position ~= nil then
			props.Position = value.Position
		end
		return
	end

	if key == "Position" then
		props.Position = value
		local cf = props.CFrame
		if cf ~= nil and cf.Position ~= nil then
			props.CFrame = CFrame.new(value)
		else
			props.CFrame = CFrame.new(value)
		end
		return
	end

	if key == "Parent" then
			local events = rawget(inst, "_events")
			rawset(inst, "_props", inst._props)
			inst._props.Parent = value
			if value then
				addChild(value, inst)
			end
			return
		end
		logProp(inst._class, key)
		inst._props[key] = value
	end,
	__tostring = function(inst)
		if inst._class then
			return inst._class .. "(" .. tostring(inst._props and inst._props.Name) .. ")"
		end
		return "mock-value"
	end,
}

function InstanceMethods.ClassName_get(inst)
	return inst._class
end

local mtIndexForClass = {}

-- expose ClassName as a plain field read
local realIndex = InstanceMethods.__index
InstanceMethods.__index = function(inst, key)
	if key == "ClassName" then
		return inst._class
	end
	return realIndex(inst, key)
end
local realNew = newInstance

function InstanceMethods:IsA(other)
	if self._class == other then
		return true
	end
	local supers = SUPER[self._class]
	return supers ~= nil and supers[other] == true
end

function InstanceMethods:GetChildren()
	return self._children
end

function InstanceMethods:GetDescendants()
	local out = {}
	local function walk(node)
		for _, child in ipairs(node._children) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function InstanceMethods:FindFirstChild(name)
	for _, child in ipairs(self._children) do
		if child._props.Name == name then
			return child
		end
	end
	return nil
end

function InstanceMethods:FindFirstChildOfClass(cls)
	for _, child in ipairs(self._children) do
		if child._class == cls then
			return child
		end
	end
	return nil
end

function InstanceMethods:FindFirstChildWhichIsA(cls)
	for _, child in ipairs(self._children) do
		if child:IsA(cls) then
			return child
		end
	end
	return nil
end

function InstanceMethods:FindFirstAncestorOfClass(cls)
	local node = self._parent
	while node do
		if node._class == cls then
			return node
		end
		node = node._parent
	end
	return nil
end

function InstanceMethods:WaitForChild(name, timeout)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	-- tests never yield; a missing child is a real bug worth seeing
	error("WaitForChild timed out in the mock: " .. tostring(self._props.Name) .. " has no child named " .. tostring(name), 0)
end

function InstanceMethods:GetPropertyChangedSignal(name)
	if not self._events[name .. "_changed"] then
		self._events[name .. "_changed"] = newSignal(name)
	end
	return self._events[name .. "_changed"]
end

function InstanceMethods:SetAttribute(name, value)
	self._attrs[name] = value
	local sig = self._events[name .. "_attr"]
	if sig then
		sig:Fire(value)
	end
end

function InstanceMethods:GetAttribute(name)
	return self._attrs[name]
end

function InstanceMethods:GetAttributeChangedSignal(name)
	if not self._events[name .. "_attr"] then
		self._events[name .. "_attr"] = newSignal(name)
	end
	return self._events[name .. "_attr"]
end

function InstanceMethods:Destroy()
	self._props._destroyed = true
	local kids = {}
	for _, child in ipairs(self._children) do
		table.insert(kids, child)
	end
	for _, child in ipairs(kids) do
		child:Destroy()
	end
	local parent = self._parent
	if parent then
		for i, other in ipairs(parent._children) do
			if other == self then
				table.remove(parent._children, i)
				break
			end
		end
		if parent._events.ChildRemoved then
			parent._events.ChildRemoved:Fire(self)
		end
	end
end

function InstanceMethods:Clone()
	local copy = realNew(self._class, self._props.Name)
	for k, v in pairs(self._props) do
		copy._props[k] = v
	end
	copy._props.Name = self._props.Name
	copy._attrs = {}
	for k, v in pairs(self._attrs) do
		copy._attrs[k] = v
	end
	return copy
end

--- Roblox translates every descendant part by the offset a Model's pivot travelled.
--- Entity animation and character placement both depend on that, so the mock must too.
function InstanceMethods:PivotTo(cf)
	local target = nil
	if type(cf) == "table" and cf.Position ~= nil then
		target = cf.Position
	end
	if target == nil or target.X == nil then
		return
	end
	local before = self._props.Position or (self:GetPivot() and self:GetPivot().Position)
	local dx, dy, dz = target.X, target.Y, target.Z
	if before then
		dx = target.X - before.X
		dy = target.Y - before.Y
		dz = target.Z - before.Z
	end
	self._props.Position = target
	self._props.CFrame = cframe(target)
	if math.abs(dx) + math.abs(dy) + math.abs(dz) > 1e-9 then
		local function shift(node)
			for _, child in ipairs(node._children) do
				if child._class == "Part" or child._class == "MeshPart" then
					local pos = child._props.Position
					if pos then
						child._props.Position = vec(pos.X + dx, pos.Y + dy, pos.Z + dz)
					end
				end
				shift(child)
			end
		end
		shift(self)
	end
end

function InstanceMethods:GetPivot()
	local pos = self._props.Position
	if not pos then
		for _, child in ipairs(self._children) do
			if child._props.Position ~= nil then
				pos = child._props.Position
				break
			end
		end
	end
	return cframe(pos or vec(0, 0, 0))
end

function InstanceMethods:MoveTo(pos)
	self._props.Position = pos
end

function InstanceMethods:TweenInfo()
	return nil
end

function InstanceMethods:TweenSizeAndPosition()
	return true
end

function InstanceMethods:TweenSize()
	return true
end

function InstanceMethods:Play() end
function InstanceMethods:Stop() end
function InstanceMethods:PlaySound() end

function InstanceMethods:TakeDamage(amount)
	if self._class ~= "Humanoid" then
		return
	end
	self._props.Health = math.max(0, (self._props.Health or 100) - amount)
	if self._props.Health <= 0 then
		local died = self._events.Died
		if died then
			died:Fire()
		end
	end
end

function InstanceMethods:ChangeState()
	return true
end

function InstanceMethods:SetStateDescription() end
function InstanceMethods:GetDebugId()
	return tostring(self._props.Name)
end

function InstanceMethods:GetPlayerFromCharacter(model)
	for _, child in ipairs(self._children) do
		if child._class == "Player" and child._props.Character == model then
			return child
		end
	end
	return nil
end

function InstanceMethods:SetCoreGuiEnabled() end
function InstanceMethods:SetCore() end
function InstanceMethods:GetPlayers()
	local out = {}
	for _, child in ipairs(self._children) do
		if child._class == "Player" then
			table.insert(out, child)
		end
	end
	return out
end

function InstanceMethods:UnbindFromRenderStep() end
function InstanceActions() end
function InstanceMethods:CaptureFocus() end

-- (ContextActionService bindings are recorded on the service itself, see boot)
function InstanceMethods:GetFocusedTextBox()
	return nil
end
function InstanceMethods:IsKeyDown()
	return false
end
function InstanceMethods:ClearAllChildren()
	for i = #self._children, 1, -1 do
		self._children[i]:Destroy()
	end
end
function InstanceMethods:GetMouse()
	return setmetatable({ _props = {}, _events = {} }, { __index = InstanceMethods })
end
function InstanceMethods:Remove()
	self:Destroy()
end

function InstanceMethods:LoadCharacter()
	local player = self
	local old = player._props.Character
	if old then
		old:Destroy()
	end
	local char = mock.newCharacter(player)
	char.Parent = mock.workspace
	local removing = player._events.CharacterRemoving
	if removing then
		removing:Fire(old)
	end
	local added = player._events.CharacterAdded
	if added then
		added:Fire(char)
	end
	return char
end

--- RemoteEvent: remember every payload so scenarios can assert on the protocol.
function InstanceMethods:OnServerEvent_new() end

--- Delivered to the simulated LocalPlayer's OnClientEvent, so client scripts really run.
function InstanceMethods:FireClient(player, ...)
	table.insert(self._props._sent, { to = player, args = { ... } })
	if player ~= nil and player == mock.localPlayer() then
		local sig = rawget(self, "_events").OnClientEvent
		if sig then
			sig:Fire(...)
		end
	end
end

function InstanceMethods:FireAllClients(...)
	table.insert(self._props._sent, { to = nil, args = { ... } })
	local sig = rawget(self, "_events").OnClientEvent
	if sig then
		sig:Fire(...)
	end
end

-- A client calls FireServer(action, ...) and the engine prepends the player; a test may
-- also call it with an explicit player. Accept both shapes.
function InstanceMethods:FireServer(first, ...)
	local player = first
	local args = { ... }
	if not (typeof(first) == "Instance" and first._class == "Player") then
		table.insert(args, 1, first)
		player = mock.localPlayer()
	end
	-- Record what the server handler actually receives: (player, action, ...)
	table.insert(args, 1, player)
	table.insert(self._props._sent, { from = player, args = args })
	local sig = rawget(self, "_events").OnServerEvent
	if sig then
		-- args already begins with the player: that is exactly what OnServerEvent sees
		sig:Fire(table.unpack(args))
	end
end

function InstanceMethods:FireRepl() end

-- services that the game code calls methods on
function InstanceMethods:SetCoreGuiEnabled() end
function InstanceMethods:SetCore() end
function InstanceMethods:AddTag() end
function InstanceMethods:GetTagged()
	return {}
end
function InstanceMethods:HasTag()
	return false
end
function InstanceMethods:Play() end

---------------------------------------------------------------------------
-- services + data model
---------------------------------------------------------------------------

local services = {}
local function service(name, extra)
	local inst = realNew(name, name)
	for k, v in pairs(extra or {}) do
		inst._props[k] = v
	end
	services[name] = inst
	return inst
end

function mock.schedule(seconds, fn)
	table.insert(mock.queue, { at = mock.time + (seconds or 0), fn = fn, args = {} })
end

mock.newPlayer = function(name, userId)
	local player = realNew("Player", name)
	local playersService = services.Players
	if playersService._props.LocalPlayer == nil then
		playersService._props.LocalPlayer = player
	end
	player._props.UserId = userId or 100
	local gui = realNew("PlayerGui", "PlayerGui")
	gui.Parent = player
	player._props.Character = nil
	player._props.HealthDisplayDistanceType = "None"
	player._props.CameraMode = "Classic"
	return player
end

mock.newCharacter = function(player)
	local char = realNew("Model", player._props.Name)
	local root = realNew("Part", "HumanoidRootPart")
	root._props.Position = vec(0, 4, 0)
	root._props.CFrame = cframe(vec(0, 4, 0))
	root._props.AssemblyLinearVelocity = vec(0, 0, 0)
	root._props.Anchored = false
	root.Parent = char

	local head = realNew("Part", "Head")
	head._props.Position = vec(0, 5, 0)
	head.Parent = char

	local hum = realNew("Humanoid", "Humanoid")
	hum._props.Health = 100
	hum._props.MaxHealth = 100
	hum._props.WalkSpeed = 16
	hum._props.JumpPower = 50
	hum._props.PlatformStand = false
	hum.Parent = char

	char._props.Humanoid = hum
	char._props.HumanoidRootPart = root
	player._props.Character = char
	if not player:FindFirstChild("PlayerGui") then
		local gui = realNew("PlayerGui", "PlayerGui")
		gui.Parent = player
	end
	return char
end

function mock.localPlayer()
	local players = services.Players
	return players and players._props.LocalPlayer
end

--- Simulate a key press through the recorded ContextActionService bindings.
function mock.pressKey(key, state)
	state = state or Enum.UserInputState.Begin
	for _, action in ipairs(mock.actions) do
		for _, bound in ipairs(action.keys) do
			if bound == key then
				action.fn(action.name, state, {
					Keycode = key,
					UserInputType = Enum.UserInputType.Keyboard,
					Position = vec2(0, 0),
				})
				return true
			end
		end
	end
	return false
end

function mock.hasBinding(name)
	for _, action in ipairs(mock.actions) do
		if action.name == name then
			return true
		end
	end
	return false
end

function mock.boot(opts)
	opts = opts or {}
	mock.queue = {}
	mock.time = 0
	mock.sentLog = {}
	mock.actions = {}

	InstanceMethods.ClassName = nil

	local dataModel = realNew("DataModel", "Game")

	local playersService = service("Players", { LocalPlayer = nil, CharacterAutoLoads = true, RespawnTime = 5, MaxPlayers = 8 })
	service("Workspace", { CurrentCamera = nil, StreamingEnabled = false, Gravity = 196.2 })
	service("Lighting")
	service("ReplicatedStorage")
	service("ServerScriptService")
	service("ServerStorage")
	service("StarterGui")
	service("StarterPlayer")
	service("SoundService")
	service("CollectionService", {
		GetTagged = function()
			return {}
		end,
		AddTag = function() end,
	})
	service("ProximityPromptService")
	service("ContextActionService")
	service("UserInputService", { GamepadEnabled = false, KeyboardEnabled = true })
	local tweenService = service("TweenService")
	service("RunService", {
		IsStudio = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		IsServer = function()
			return true
		end,
	})
	service("Debris", {
		AddItem = function(_, inst, time)
			mock.schedule(time, function()
				if inst and inst.Destroy then
					inst:Destroy()
				end
			end)
		end,
	})
	service("HttpService")
	service("PathfindingService")
	service("MessagingService")
	service("TextService")
	service("CoreGui")

	-- RemoteEvent: keep a record of what was sent so tests can assert on it
	tweenService._props.Create = function(_, inst, info, props)
		local tween = { _inst = inst, _info = info, _props = props }
		function tween:Play()
			-- Applied instantly: the sim has no interpolated time.
			if type(props) == "table" and inst and inst._props then
				for key, value in pairs(props) do
					if type(key) == "string" then
						inst._props[key] = value
					end
				end
			end
		end
		function tween:Cancel() end
		function tween:Pause() end
		function tween:Destroy() end
		return tween
	end

	local workspace = services.Workspace
	local camera = realNew("Camera", "Camera")
	camera._props.CFrame = cframe(vec(0, 4, 0))
	camera._props.FieldOfView = 70
	camera._props.ViewportSize = vec(1280, 720, 0)
	camera.Parent = workspace
	workspace._props.CurrentCamera = camera

	local heartbeat = newSignal("Heartbeat")
	local renderStepped = newSignal("RenderStepped")
	local runService = services.RunService
	runService._events = { Heartbeat = heartbeat, RenderStepped = renderStepped, Stepped = newSignal("Stepped") }
	-- Each bind gets its own slot, tagged by name so Unbind can remove just that one.
	runService._props.BindToRenderStep = function(_, name, priority, fn)
		table.insert(renderStepped._handlers, { _fn = fn, _connected = true, _name = name })
	end
	runService._props.UnbindFromRenderStep = function(_, name)
		for i = #renderStepped._handlers, 1, -1 do
			if renderStepped._handlers[i]._name == name then
				table.remove(renderStepped._handlers, i)
			end
		end
	end

	local game = {
		GetService = function(_, name)
			if not services[name] then
				services[name] = service(name)
			end
			return services[name]
		end,
		FindFirstChild = function(_, name)
			return nil
		end,
		WaitForChild = function(_, name)
			return nil
		end,
		BindToClose = function() end,
		GetChildren = function()
			local out = {}
			for _, inst in pairs(services) do
				table.insert(out, inst)
			end
			return out
		end,
	}
	setmetatable(game, {
		__index = function(t, k)
			if services[k] then
				return services[k]
			end
			return nil
		end,
	})

	mock.time = 0
	mock.queue = {}
	local cas = services.ContextActionService or service("ContextActionService")
	cas._props.BindAction = function(_, name, fn, createButton, ...)
		table.insert(mock.actions, { name = name, fn = fn, keys = { ... }, touch = createButton })
	end
	cas._props.BindActionAtPriority = function(_, name, fn, createButton, priority, ...)
		table.insert(mock.actions, { name = name, fn = fn, keys = { ... }, touch = createButton, priority = priority })
	end
	cas._props.UnbindAction = function(_, name)
		for i = #mock.actions, 1, -1 do
			if mock.actions[i].name == name then
				table.remove(mock.actions, i)
			end
		end
	end
	cas._props.SetTitle = function() end
	cas._props.SetPosition = function() end

	mock.heartbeat = heartbeat
	runServiceEvents = runService._events
	mock.renderStepped = renderStepped
	mock.services = services
	mock.players = playersService
	mock.workspace = workspace
	mock.camera = camera
	mock.propLog = propLog
	mock.newPlayer = mock.newPlayer
	mock.newCharacter = mock.newCharacter

	---------------------------------------------------------------------
	-- task / scheduling
	---------------------------------------------------------------------
	local task = {}
	function task.wait(seconds)
		-- the sim is synchronous: a bare wait just returns
		return seconds or 0
	end
	function task.spawn(fn, ...)
		if type(fn) == "function" then
			fn(...)
		end
	end
	function task.defer(fn, ...)
		task.spawn(fn, ...)
	end
	function task.delay(seconds, fn, ...)
		table.insert(mock.queue, { at = mock.time + (seconds or 0), fn = fn, args = { ... } })
	end
	function task.kill() end
	_G.task = task

	---------------------------------------------------------------------
	-- engine globals
	---------------------------------------------------------------------
	_G.game = game
	_G.workspace = workspace
	_G.Vector3 = Vector3
	_G.CFrame = CFrame
	_G.Color3 = Color3
	_G.UDim = UDim
	_G.UDim2 = UDim2
	_G.Enum = Enum
	_G.TweenInfo = TweenInfo
	_G.NumberSequence = NumberSequence
	_G.NumberSequenceKeypoint = NumberSequenceKeypoint
	_G.NumberRange = NumberRange
	_G.Rect = Rect
	_G.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring(select(i, ...))
		end
		print("[warn] " .. table.concat(parts, " "))
	end
	_G.tick = function()
		return mock.time
	end
	_G.delay = task.delay
	_G.spawn = task.spawn
	_G.wait = task.wait

	_G.Instance = {
		new = function(cls, parent)
			classCount[cls] = (classCount[cls] or 0) + 1
			local inst = realNew(cls, cls)
			if parent then
				inst.Parent = parent
			end
			return inst
		end,
		getPropertiesChangedSignal = function()
			return newSignal()
		end,
	}

	-- Lua 5.5 dropped math.atan2; Luau still has it, so the game code is right and
	-- only the mock needs the alias.
	if not math.atan2 then
		math.atan2 = function(y, x)
			return math.atan(y, x)
		end
	end
	math.lerp = math.lerp or function(a, b, t)
		return a + (b - a) * t
	end
	math.sign = math.sign or function(v)
		return v > 0 and 1 or (v < 0 and -1 or 0)
	end
	math.wrap = math.wrap or function(x, min, max)
		local range = max - min
		return ((x - min) % range) + min
	end
	table.clear = table.clear or function(t)
		for k in pairs(t) do
			t[k] = nil
		end
	end
	table.find = table.find or function(haystack, needle)
		for i, v in ipairs(haystack) do
			if v == needle then
				return i
			end
		end
		return nil
	end
	warn = function(...)
		local n = select("#", ...)
		local parts = {}
		for i = 1, n do
			parts[i] = tostring(select(i, ...))
		end
		print("warn: " .. table.concat(parts, "  "))
	end
	print = print
	tick = function()
		return mock.time
	end
	_G["typeof"] = function(v)
		if type(v) == "table" then
			if v.__type then
				return v.__type
			end
			if v._class then
				return "Instance"
			end
			if getmetatable(v) and getmetatable(v).__type then
				return getmetatable(v).__type
			end
		end
		return type(v)
	end

	if not math.noise then
		math.noise = function(x, y, z)
			x, y, z = x or 0, y or 0, z or 0
			return math.sin(x * 12.9898 + y * 78.233 + z * 37.71) * 0.5
		end
	end

	return mock
end

---------------------------------------------------------------------------
-- module loading
---------------------------------------------------------------------------

--- serviceFolder("StarterPlayer", "StarterPlayerScripts", "Blacksite")
function mock.serviceFolder(serviceName, ...)
	local node = services[serviceName]
	if not node then
		node = service(serviceName)
	end
	for _, name in ipairs({ ... }) do
		local child = node:FindFirstChild(name)
		if not child then
			child = realNew("Folder", name)
			child.Parent = node
		end
		node = child
	end
	return node
end

function mock.pathTo(parentPath)
	local node = nil
	if parentPath:sub(1, 4) == "game" then
		node = { GetService = function(_, name)
			return services[name]
		end }
	end
	local current
	for part in parentPath:gmatch("[^%.]+") do
		if part == "game" then
			current = nil
		elseif not current then
			current = services[part] or services.ReplicatedStorage
		else
			current = current:FindFirstChild(part)
		end
	end
	return current
end

local modulesByName = {}

--- serviceName, folderName (or nil), script class, instance name, source
function mock.register(serviceName, className, name, source, ...)
	local parent = mock.serviceFolder(serviceName, ...)
	local inst = realNew(className, name)
	inst._props._source = source
	inst._props._loaded = false
	inst._props._value = nil
	inst.Parent = parent
	modulesByName[inst] = inst
	return inst
end

local scriptStack = {}

function mock.require(inst)
	if inst._loaded then
		return inst._value
	end
	local fn, err = load(inst._props._source, "@" .. inst._props.Name)
	assert(fn, "compile failed for " .. inst._props.Name .. ": " .. tostring(err))
	table.insert(scriptStack, _G.script)
	_G.script = inst
	local ok, value = pcall(fn)
	_G.script = table.remove(scriptStack)
	if not ok then
		error("module " .. inst._props.Name .. " errored: " .. tostring(value), 0)
	end
	inst._loaded = true
	inst._value = value
	return value
end

_G.require = mock.require

function mock.runScript(serviceName, name, source, ...)
	local inst = mock.register(serviceName, "Script", name, source, ...)
	local fn, err = load(source, "@" .. name)
	assert(fn, "compile failed: " .. tostring(err))
	local prev = _G.script
	_G.script = inst
	local ok, e = pcall(fn)
	_G.script = prev
	if not ok then
		error("script error: " .. tostring(e), 0)
	end
end

---------------------------------------------------------------------------
-- stepping
---------------------------------------------------------------------------

function mock.step(dt)
	mock.time = mock.time + (dt or 1 / 60)

	local due = {}
	for i = #mock.queue, 1, -1 do
		local job = mock.queue[i]
		if job.at <= mock.time then
			table.insert(due, job)
			table.remove(mock.queue, i)
		end
	end
	for _, job in ipairs(due) do
		job.fn(table.unpack(job.args))
	end

	local function fire(sig)
		if sig then
			local handlers = sig._handlers
			for i = 1, #handlers do
				local conn = handlers[i]
				if conn._connected then
					conn._fn(dt)
				end
			end
		end
	end
	-- RenderStepped before Heartbeat: the client sends movement intent on the render step
	-- and the server consumes it on the next heartbeat, which is the real ordering.
	fire(mock.renderStepped)
	fire(runServiceEvents.Stepped)
	fire(mock.heartbeat)
end

function mock.propertyReport()
	local lines = {}
	for cls, props in pairs(propLog) do
		for prop in pairs(props) do
			table.insert(lines, cls .. "." .. prop)
		end
	end
	table.sort(lines)
	return lines
end

mock.vec = vec
mock.cframe = cframe
mock.signal = newSignal
mock.instance = realNew
mock.modules = modulesByName

return mock
