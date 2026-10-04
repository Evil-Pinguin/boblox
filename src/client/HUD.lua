--[[
	HUD - every pixel of client UI.

	Built entirely in code (no image assets, no StarterGui contents) so the place file
	stays a container for scripts. It reads nothing but replicated attributes, which
	means the HUD cannot desync from the server's idea of your battery or lives.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

--[[ Shared modules live in ReplicatedStorage.Blacksite. Addressed through the service rather
     than script.Parent.Parent, because these folders are siblings, not ancestors. ]]
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Blacksite")
local Config = require(shared:WaitForChild("Config"))
local Attributes = require(shared:WaitForChild("Attributes"))
local Util = require(shared:WaitForChild("Util"))

local HUD = {}
HUD.__index = HUD

local INK = Color3.fromRGB(214, 218, 220)
local DIM = Color3.fromRGB(120, 128, 132)
local PANEL = Color3.fromRGB(8, 9, 11)
local ACCENT = Color3.fromRGB(74, 226, 200)
local DANGER = Color3.fromRGB(198, 52, 42)
local WARN = Color3.fromRGB(228, 172, 62)
local GOOD = Color3.fromRGB(104, 226, 160)

local KIND_COLOR = {
	info = ACCENT,
	good = GOOD,
	warn = WARN,
	bad = DANGER,
}

---------------------------------------------------------------------------
-- widget helpers
---------------------------------------------------------------------------

local function create(cls, props, parent)
	local inst = Instance.new(cls)
	if props then
		for key, value in pairs(props) do
			if key ~= "Parent" then
				inst[key] = value
			end
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function label(props, parent)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextColor3 = INK,
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = false,
		TextStrokeTransparency = 0.55,
		RichText = false,
	}
	for key, value in pairs(defaults) do
		if props[key] == nil then
			props[key] = value
		end
	end
	return create("TextLabel", props, parent)
end

local function panel(props, parent)
	local defaults = {
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
	}
	for k, v in pairs(defaults) do
		if props[k] == nil then
			props[k] = v
		end
	end
	local f = create("Frame", props, parent)
	create("UIStroke", { Color = Color3.fromRGB(60, 66, 70), Thickness = 1, Transparency = 0.45 }, f)
	return f
end

local function bar(width, height, color, parent)
	local track = panel({ Size = UDim2.fromOffset(width, height), BackgroundTransparency = 0.55 }, parent)
	local fill = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		BackgroundTransparency = 0,
	}, track)
	create("UICorner", { CornerRadius = UDim.new(0, 2) }, track)
	create("UICorner", { CornerRadius = UDim.new(0, 2) }, fill)
	return track, fill
end

local function button(text, size, parent, color)
	local btn = create("TextButton", {
		Text = text,
		Font = Enum.Font.Code,
		TextSize = 18,
		TextColor3 = color or INK,
		BackgroundColor3 = Color3.fromRGB(16, 18, 20),
		Size = size,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 3) }, btn)
	create("UIStroke", { Color = color or ACCENT, Thickness = 1.4, Transparency = 0.25 }, btn)
	return btn
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function HUD.new(deps)
	-- builders below run as methods, so anything they need has to live on self
	local self = setmetatable({}, HUD)
	self.player = deps.player
	self.playerGui = deps.playerGui
	self.root = deps.root
	self.remotes = deps.remotes
	self.toasts = {}

	local gui = create("ScreenGui", {
		Name = "BlacksiteHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = true,
	}, deps.playerGui)
	self.gui = gui

	self:buildHud()
	self:buildPrompt()
	self:buildToasts()
	self:buildMenu()
	self:buildResults()
	self:buildDown()

	self:hookAttributes()
	self:hookPrompts()

	return self
end

function HUD:buildHud()
	local hud = panel({ Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false }, self.gui)
	hud.BackgroundTransparency = 1
	self.hud = hud

	-- objective card, top left
	local card = panel({ Name = "Objective", Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(232, 96) }, hud)
	self.txtTitle = label({ Text = Config.Meta.Title .. "  //  SUBLEVEL 7", TextSize = 12, TextColor3 = DIM, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 14) }, card)
	self.txtCells = label({ Text = "CELLS 0 / 5", TextSize = 26, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 32) }, card)
	self.txtTimer = label({ Text = "--:--", TextSize = 15, TextColor3 = DIM, Position = UDim2.new(1, -78, 0, 10), Size = UDim2.fromOffset(64, 18), TextXAlignment = Enum.TextXAlignment.Right }, card)

	-- lives pips
	local livesRow = create("Frame", { Name = "Lives", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 66), Size = UDim2.new(1, -20, 0, 18) }, card)
	self.pips = {}
	for i = 1, 3 do
		local pip = create("Frame", {
			Size = UDim2.fromOffset(26, 7),
			Position = UDim2.fromOffset((i - 1) * 32, 4),
			BackgroundColor3 = DANGER,
			BorderSizePixel = 0,
		}, livesRow)
		create("UICorner", { CornerRadius = UDim.new(0, 2) }, pip)
		self.pips[i] = pip
	end
	label({ Text = "RUNS", TextSize = 11, TextColor3 = DIM, Position = UDim2.fromOffset(0, -12), Size = UDim2.fromOffset(60, 12) }, livesRow)

	-- meters, bottom left
	local meters = panel({ Name = "Meters", Position = UDim2.fromOffset(18, -124), Size = UDim2.fromOffset(232, 106) }, hud)
	meters.AnchorPoint = Vector2.new(0, 1)
	label({ Text = "LIGHT CELL", TextSize = 11, TextColor3 = DIM, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(120, 12) }, meters)
	self.batteryTrack, self.batteryFill = bar(212, 9, ACCENT, meters)
	self.batteryTrack.Position = UDim2.fromOffset(10, 24)
	self.txtBattery = label({ Text = "100%", TextSize = 11, TextColor3 = DIM, Position = UDim2.new(1, -50, 0, 6), Size = UDim2.fromOffset(40, 12), TextXAlignment = Enum.TextXAlignment.Right }, meters)

	label({ Text = "BREATH", TextSize = 11, TextColor3 = DIM, Position = UDim2.fromOffset(10, 44), Size = UDim2.fromOffset(120, 12) }, meters)
	self.staminaTrack, self.staminaFill = bar(212, 9, GOOD, meters)
	self.staminaTrack.Position = UDim2.fromOffset(10, 60)

	label({ Text = "PROXIMITY", TextSize = 11, TextColor3 = DIM, Position = UDim2.fromOffset(10, 78), Size = UDim2.fromOffset(140, 12) }, meters)
	self.dreadTrack, self.dreadFill = bar(212, 5, DANGER, meters)
	self.dreadTrack.Position = UDim2.fromOffset(10, 92)
	self.dreadTrack.BackgroundTransparency = 0.75

	-- signal / compass, bottom right
	local compass = panel({ Name = "Signal", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(-18, -18), Size = UDim2.fromOffset(196, 74) }, hud)
	self.txtSignal = label({ Text = "NO SIGNAL", TextSize = 13, TextColor3 = DIM, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 16) }, compass)
	self.txtBearing = label({ Text = "???", TextSize = 30, Position = UDim2.fromOffset(10, 26), Size = UDim2.fromOffset(90, 40) }, compass)
	self.txtDistance = label({ Text = "---", TextSize = 16, TextColor3 = DIM, Position = UDim2.new(1, -80, 0, 34), Size = UDim2.fromOffset(70, 20), TextXAlignment = Enum.TextXAlignment.Right }, compass)

	-- key legend
	local legend = panel({ Name = "Keys", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(-18, 16), Size = UDim2.fromOffset(216, 74), BackgroundTransparency = 0.55 }, hud)
	label({
		Text = "F  LIGHT      SHIFT  RUN\nCTRL  CROUCH    E      INTERACT\nV  CAMERA     M  MUTE",
		TextSize = 12,
		TextColor3 = DIM,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 1, -16),
	}, legend)

	-- threat banner
	self.banner = label({
		Text = "",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.fromOffset(520, 24),
		TextColor3 = DANGER,
		TextStrokeTransparency = 0.2,
	}, hud)

	-- hidden-state panel
	self.hiddenPanel = panel({
		Name = "Hidden",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(300, 58),
		Visible = false,
	}, hud)
	self.txtHidden = label({ Text = "HOLD STILL", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 18) }, self.hiddenPanel)
	self.foundTrack, self.foundFill = bar(260, 7, DANGER, self.hiddenPanel)
	self.foundTrack.Position = UDim2.fromOffset(20, 34)
	self.foundFill.BackgroundColor3 = DANGER

	-- crosshair
	self.dot = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(230, 230, 230),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, hud)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, self.dot)
end

function HUD:buildPrompt()
	local prompt = panel({
		Name = "Prompt",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(300, 54),
		Visible = false,
	}, self.hud)
	self.promptPanel = prompt

	self.promptKey = label({
		Text = "E",
		TextSize = 18,
		TextColor3 = PANEL,
		BackgroundColor3 = ACCENT,
		Size = UDim2.fromOffset(30, 28),
		Position = UDim2.fromOffset(12, 13),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 1,
	}, prompt)
	create("UICorner", { CornerRadius = UDim.new(0, 3) }, self.promptKey)

	self.promptAction = label({ Text = "TAKE", TextSize = 16, Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -62, 0, 18) }, prompt)
	self.promptObject = label({ Text = "", TextSize = 12, TextColor3 = DIM, Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -62, 0, 16) }, prompt)
	self.holdTrack, self.holdFill = bar(236, 4, WARN, prompt)
	self.holdTrack.Position = UDim2.fromOffset(52, 46)
	self.holdTrack.Visible = false
end

function HUD:buildToasts()
	local holder = create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -186),
		Size = UDim2.fromOffset(460, 1),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, self.hud)
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	self.toastHolder = holder
end

function HUD:buildMenu()
	local menu = create("ScreenGui", {
		Name = "BlacksiteMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		Enabled = false,
	}, self.playerGui)
	self.menu = menu

	local bg = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 5, 6), BorderSizePixel = 0 }, menu)
	create("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.35),
	}), Rotation = 90 }, bg)

	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 420),
		BackgroundTransparency = 1,
	}, bg)

	local title = label({ Text = Config.Meta.Title, TextSize = 74, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 86), Position = UDim2.fromOffset(0, 0), TextStrokeTransparency = 0.85 }, holder)
	self.menuTitle = title
	label({ Text = Config.Meta.Subtitle, TextSize = 16, TextColor3 = DANGER, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 88) }, holder)

	label({
		Text = "Five igniter cells. One blast door. One thing in the dark with you.\n"
			.. "\n"
			.. "It hears movement and it sees your beam. Sprint and it will find you;\n"
			.. "shine the light on it and you will see it clearly, once, too clearly.\n"
			.. "When it is close, get in a locker and hold still.",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(168, 174, 178),
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 108),
		Position = UDim2.fromOffset(0, 130),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, holder)

	self.menuButton = button(Config.Copy.Menu, UDim2.new(1, 0, 0, 46), holder, ACCENT)
	self.menuButton.Position = UDim2.fromOffset(0, 258)

	self.viewButton = button("VIEW: FIRST PERSON", UDim2.new(1, 0, 0, 32), holder, DIM)
	self.viewButton.Position = UDim2.fromOffset(0, 312)

	self.menuStatus = label({
		Text = "",
		TextSize = 13,
		TextColor3 = DIM,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 356),
	}, holder)

	self.viewFirstPerson = true
	self.viewButton.MouseButton1Click:Connect(function()
		self.viewFirstPerson = not self.viewFirstPerson
		self.viewButton.Text = "VIEW: " .. (self.viewFirstPerson and "FIRST PERSON" or "THIRD PERSON")
		self.viewButton.TextColor3 = DIM
		if self.onViewMode then
			self.onViewMode(self.viewFirstPerson)
		end
	end)

	self.menuButton.MouseButton1Click:Connect(function()
		if self.onJoin then
			self.onJoin()
		end
	end)
end

function HUD:buildResults()
	local gui = create("ScreenGui", {
		Name = "BlacksiteResults",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		Enabled = false,
	}, self.playerGui)
	self.results = gui

	local bg = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 5, 6), BorderSizePixel = 0, BackgroundTransparency = 0.08 }, gui)

	local head = label({ Text = "", TextSize = 54, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.28, 0), Size = UDim2.new(1, 0, 0, 70), TextStrokeTransparency = 0.9 }, bg)
	self.resultHead = head
	self.resultSub = label({ Text = "", TextSize = 16, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.28, 72), Size = UDim2.new(1, 0, 0, 24) }, bg)
	self.resultBody = label({
		Text = "",
		TextSize = 15,
		TextWrapped = true,
		Position = UDim2.new(0.5, -160, 0.42, 0),
		Size = UDim2.fromOffset(320, 140),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, bg)

	self.resultButton = button("READY FOR THE NEXT LIFT", UDim2.fromOffset(300, 44), bg, ACCENT)
	self.resultButton.Position = UDim2.new(0.5, -150, 0.42, 152)
	self.resultButton.MouseButton1Click:Connect(function()
		if self.onNextRound then
			self.onNextRound()
		end
		self.results.Enabled = false
	end)

	self.resultCount = label({ Text = "", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0.5, -150, 0.42, 206), Size = UDim2.fromOffset(300, 20) }, bg)
end

function HUD:buildDown()
	local gui = create("ScreenGui", {
		Name = "BlacksiteDown",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 35,
		Enabled = false,
	}, self.playerGui)
	self.down = gui
	local bg = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 2, 2), BackgroundTransparency = 0.18, BorderSizePixel = 0 }, gui)
	self.downText = label({ Text = "YOU WERE TAKEN", TextSize = 42, TextColor3 = DANGER, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.4, 0), Size = UDim2.new(1, 0, 0, 56), TextStrokeTransparency = 0.75 }, bg)
	self.downSub = label({ Text = "", TextSize = 15, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.4, 60), Size = UDim2.new(1, 0, 0, 22) }, bg)
end

---------------------------------------------------------------------------
-- data binding
---------------------------------------------------------------------------

function HUD:hookAttributes()
	local player = self.player
	local root = self.root

	self.lastPhase = Attributes.get(root, "Phase", "intermission")

	player:GetAttributeChangedSignal("State"):Connect(function()
		self:syncState()
	end)
	root:GetAttributeChangedSignal("Phase"):Connect(function()
		self.lastPhase = Attributes.get(root, "Phase", "intermission")
		self:syncState()
	end)

	root:GetAttributeChangedSignal("CellsFound"):Connect(function()
		self:syncObjective()
	end)
	root:GetAttributeChangedSignal("GateOpen"):Connect(function()
		self:syncObjective()
	end)
	root:GetAttributeChangedSignal("Countdown"):Connect(function()
		self:syncObjective()
	end)
	root:GetAttributeChangedSignal("TimeLeft"):Connect(function()
		self:syncObjective()
	end)
	root:GetAttributeChangedSignal("Purge"):Connect(function()
		self:syncObjective()
	end)
	self:syncState()
	self:syncObjective()
end

function HUD:stateForPhase()
	return Attributes.get(self.root, "Phase", "intermission")
end

function HUD:syncState()
	local name = Attributes.get(self.player, "State", "menu")
	local phase = self:stateForPhase()

	local inMenu = name == "menu" or name == "lobby"
	self.menu.Enabled = inMenu and phase ~= "resolving"
	if inMenu then
		local waiting = Attributes.num(self.root, "Waiting", 0)
		if name == "lobby" then
			self.menuStatus.Text = "IN STAGING  -  LIFT IN " .. Attributes.num(self.root, "Countdown", 0) .. "s   |   " .. waiting .. " READY"
			self.menuButton.Text = "WAITING FOR THE LIFT"
		else
			self.menuStatus.Text = "The lift is ready when you are. Nobody waits for you down there."
			self.menuButton.Text = Config.Copy.Menu
		end
	end

	self.down.Enabled = name == "down" or name == "consumed"
	if name == "down" then
		self.downText.Text = "DRAGGED UNDER"
		self.downSub.Text = "redeploying at the airlock..."
	elseif name == "consumed" then
		self.downText.Text = "NO RUNS LEFT"
		self.downSub.Text = "the sublevel keeps you. spectating the crew."
	end

	local hideHud = inMenu
	self.hud.Visible = not hideHud
	self.hiddenPanel.Visible = Attributes.get(self.player, "Hidden", false) and true or false
end

function HUD:syncObjective()
	local found = Attributes.num(self.root, "CellsFound", 0)
	local needed = Attributes.num(self.root, "CellsNeeded", Config.Round.CellsNeeded)
	local gateOpen = Attributes.get(self.root, "GateOpen", false)
	local purge = Attributes.get(self.root, "Purge", false)
	local timeLeft = Attributes.num(self.root, "TimeLeft", 0)

	if gateOpen then
		self.txtCells.Text = "GET OUT"
		self.txtCells.TextColor3 = GOOD
	else
		self.txtCells.Text = "CELLS " .. found .. " / " .. needed
		self.txtCells.TextColor3 = INK
	end

	self.txtTitle.Text = Config.Meta.Title .. "  //  SUBLEVEL 7" .. (purge and "   [PURGE]" or "")
	if purge then
		self.txtTitle.TextColor3 = DANGER
	else
		self.txtTitle.TextColor3 = DIM
	end

	if Attributes.get(self.root, "Phase") == "intermission" then
		self.txtTimer.Text = "T-" .. math.max(0, Attributes.num(self.root, "Countdown", 0)) .. "s"
	else
		self.txtTimer.Text = Util.formatTime(timeLeft)
	end
	self.txtTimer.TextColor3 = timeLeft < Config.Round.PurgeWarn and DANGER or DIM

	local lives = Attributes.num(self.player, "Lives", Config.Player.Lives)
	for i = 1, #self.pips do
		self.pips[i].BackgroundTransparency = i <= lives and 0 or 0.85
	end
end

--- Per-frame bits that must feel analogue: meters, dread, banner.
function HUD:update(dt)
	self.time = (self.time or 0) + dt
	local p = self.player

	local battery = Attributes.num(p, "Battery", 100)
	local stamina = Attributes.num(p, "Stamina", 100)
	local dread = Attributes.num(p, "Dread", 0)
	local found = Attributes.num(p, "Found", 0)
	local hidden = Attributes.get(p, "Hidden", false)
	local signal = Attributes.num(p, "Signal", 0)

	self.batteryFill.Size = UDim2.fromScale(Util.clamp(battery / 100, 0, 1), 1)
	self.batteryFill.BackgroundColor3 = battery < 20 and DANGER or (battery < 45 and WARN or ACCENT)
	self.txtBattery.Text = math.floor(battery + 0.5) .. "%"

	self.staminaFill.Size = UDim2.fromScale(Util.clamp(stamina / 100, 0, 1), 1)
	self.staminaFill.BackgroundColor3 = stamina < 15 and WARN or GOOD

	self.dreadFill.Size = UDim2.fromScale(Util.clamp(dread, 0, 1), 1)

	if self.foundFill then
		self.foundFill.Size = UDim2.fromScale(Util.clamp(found, 0, 1), 1)
	end
	if hidden ~= self.hiddenShown then
		self.hiddenShown = hidden
		self.hiddenPanel.Visible = hidden and true or false
	end

	-- threat banner
	local text, color
	if dread > 0.93 then
		text = Config.Entity.Name .. " HAS YOU"
		color = DANGER
	elseif dread > 0.66 then
		text = Config.Entity.Name .. " IS CLOSE"
		color = DANGER
	elseif dread > 0.34 then
		text = "MOVEMENT NEARBY"
		color = WARN
	elseif hidden then
		text = "HIDDEN"
		color = GOOD
	end
	if text ~= self.bannerText then
		self.bannerText = text
		self.banner.Text = text or ""
		self.banner.TextColor3 = color or DANGER
	end
	self.banner.TextTransparency = 0.1 + 0.35 * (0.5 + 0.5 * math.sin(self.time * (6 + dread * 12)))

	-- compass
	local distance = Attributes.num(p, "Distance", 0)
	local bearing = Attributes.num(p, "Bearing", 0)
	local kind = Attributes.get(p, "SignalKind", "")
	if signal > 0.02 then
		local arrow = "???"
		local b = (bearing + 540) % 360 - 180
		if b < -135 or b > 135 then
			arrow = "DOWN"
		elseif b < -45 then
			arrow = "LEFT"
		elseif b > 45 then
			arrow = "RIGHT"
		else
			arrow = "AHEAD"
		end
		if arrow ~= self.lastArrow then
			self.lastArrow = arrow
			self.txtBearing.Text = arrow
		end
		self.txtDistance.Text = Util.studsToMeters(distance) .. "m"
		local prefix = kind == "gate" and "EXIT BEARING" or "CELL SIGNAL"
		self.txtSignal.Text = prefix .. "  " .. string.rep("=", math.floor(signal * 6) + 1) .. string.rep("-", 6 - math.floor(signal * 6))
		self.txtSignal.TextColor3 = signal > 0.7 and ACCENT or DIM
	else
		self.txtSignal.Text = "NO SIGNAL"
		self.txtBearing.Text = "---"
		self.txtDistance.Text = ""
	end

	self.dot.BackgroundTransparency = 0.35 + dread * 0.4
end

---------------------------------------------------------------------------
-- prompts
---------------------------------------------------------------------------

function HUD:hookPrompts()
	local current
	local function show(prompt)
		current = prompt
		self.promptPanel.Visible = true
		self.promptAction.Text = string.upper(prompt.ActionText)
		self.promptObject.Text = prompt.ObjectText
		self.promptKey.BackgroundTransparency = 0
		local hold = prompt.HoldDuration or 0
		self.holdTrack.Visible = hold > 0
		self.holdFill.Size = UDim2.fromScale(0, 1)
	end

	local function hide()
		current = nil
		self.promptPanel.Visible = false
		self.holdTrack.Visible = false
		self.holdTween = nil
	end

	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == current then
			hide()
		end
	end)

	local ok = pcall(function()
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
			if prompt ~= current or not (prompt.HoldDuration and prompt.HoldDuration > 0) then
				return
			end
			self.holdFill.Size = UDim2.fromScale(0, 1)
			TweenService:Create(self.holdFill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
				Size = UDim2.fromScale(1, 1),
			}):Play()
		end)
		ProximityPromptService.PromptButtonHoldEnded:Connect(function()
			self.holdFill.Size = UDim2.fromScale(0, 1)
		end)
	end)
	self.holdsSupported = ok

	self.hidePrompt = hide
end

---------------------------------------------------------------------------
-- toasts
---------------------------------------------------------------------------

function HUD:toast(text, kind)
	local tint = KIND_COLOR[kind] or ACCENT
	local frame = panel({
		Size = UDim2.fromOffset(440, 30),
		BackgroundTransparency = 0.15,
	}, self.toastHolder)
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = tint
		stroke.Transparency = 0.1
	end
	label({
		Text = text,
		TextSize = 14,
		TextColor3 = tint,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextYAlignment = Enum.TextYAlignment.Center,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.7,
	}, frame)
	table.insert(self.toasts, { frame = frame, life = 3.2 })
	self:trimToasts()
end

function HUD:trimToasts()
	while #self.toasts > 4 do
		local old = table.remove(self.toasts, 1)
		old.frame:Destroy()
	end
end

function HUD:updateToasts(dt)
	for i = #self.toasts, 1, -1 do
		local item = self.toasts[i]
		item.life = item.life - dt
		if item.life <= 0.5 and not item.fading then
			item.fading = true
			TweenService:Create(item.frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			local stroke = item.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
			for _, child in ipairs(item.frame:GetChildren()) do
				if child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				end
			end
		end
		if item.life <= 0 then
			table.remove(self.toasts, i)
			item.frame:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- results / flash overlays
---------------------------------------------------------------------------

function HUD:showResults(payload)
	payload = payload or {}
	local kind = payload.kind or "consumed"
	local head, tint, sub
	if kind == "escaped" then
		head, tint, sub = "YOU ARE OUT", GOOD, "the door seals behind you"
	elseif kind == "partial" then
		head, tint, sub = "SIGNAL RECOVERED", GOOD, "not everyone made the lift"
	elseif kind == "purged" then
		head, tint, sub = "SUBLEVEL SEALED", DANGER, "the purge ran with you inside"
	else
		head, tint, sub = "NO SIGNAL", DANGER, "the sublevel keeps what it takes"
	end

	self.resultHead.Text = head
	self.resultHead.TextColor3 = tint
	self.resultSub.Text = sub

	local lines = {
		"CELLS SECURED     " .. (payload.cells or 0) .. " / " .. Config.Round.CellsNeeded,
		"TIME INSIDE       " .. Util.formatTime(payload.time or 0),
		"RUNS LEFT         " .. (payload.lives or 0),
		"EXPEDITIONS       " .. (payload.rounds or 0),
	}
	if payload.best then
		lines[#lines + 1] = "BEST EXFIL        " .. Util.formatTime(payload.best)
	end
	self.resultBody.Text = table.concat(lines, "\n")

	self.results.Enabled = true
	self.resultsCountdown = Config.Round.ResolveTime
	self.resultCount.Text = "lift returns in " .. math.ceil(self.resultsCountdown) .. "s"
end

function HUD:updateResults(dt)
	if self.results.Enabled and self.resultsCountdown and self.resultsCountdown > 0 then
		self.resultsCountdown = self.resultsCountdown - dt
		self.resultCount.Text = "ready up for the next lift"
		if self.resultsCountdown <= 0 then
			self.results.Enabled = false
		end
	end
end

--- One-frame flash used by hits, grabs and the reveal sting.
function HUD:flash(color, alpha, seconds)
	local frame = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - alpha,
		BorderSizePixel = 0,
	}, self.gui)
	TweenService:Create(frame, TweenInfo.new(seconds or 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	game:GetService("Debris"):AddItem(frame, (seconds or 0.45) + 0.1)
end

return HUD
