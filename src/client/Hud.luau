-- The HUD: stat pills, wave cluster, action buttons, menu orbs, toasts and floating numbers (docs/UI_VISION.md 4.1).
-- The middle of the screen belongs to the cannon and the monster, so everything here sits on the edges.
-- In the marketplace the battle pieces hide and a BACK TO CANNON button takes the top centre.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Colors = UI.Colors
local hex = Color3.fromHex
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Action")

local Hud = {}

local MARGIN = 16
local inMarket = false

----------------------------------------------------------------------------------------------------
-- Left: Cannon Power, per click and mastery, then the currencies
----------------------------------------------------------------------------------------------------
local PILL_LOOK = { top = Colors.row, bottom = Colors.pillBottom, lip = hex("#1F0F45") }

local stats = UI.slot({ Name = "Stats", Size = UDim2.fromOffset(320, 400) })
local powerPill = UI.pill({
	parent = stats,
	position = UDim2.fromOffset(10, 4),
	size = Vector2.new(300, 72),
	look = UI.Variants.travel,
	iconName = "power",
	icon = "⚡",
	iconColor = Colors.blue,
	textSize = 44,
})
local perClickLabel = UI.label({
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 22),
	TextSize = 20,
	TextColor3 = Colors.ink,
	TextXAlignment = Enum.TextXAlignment.Left,
	Stroke = 0,
})
local perClickChip = UI.chip({ Position = UDim2.fromOffset(40, 78), Size = UDim2.fromOffset(250, 56) }, { perClickLabel })
local masteryBar = UI.bar({
	parent = perClickChip,
	position = UDim2.fromOffset(10, 30),
	size = UDim2.new(1, -20, 0, 20),
	color = Colors.gold,
	textSize = 14,
})
perClickChip.Parent = stats

local coinPill = UI.pill({
	parent = stats,
	position = UDim2.fromOffset(10, 148),
	size = Vector2.new(250, 58),
	look = PILL_LOOK,
	iconName = "coin",
	icon = "★",
	iconColor = Colors.gold,
	glyphColor = hex("#FFF3A8"),
	textSize = 34,
})
local gemPill = UI.pill({
	parent = stats,
	position = UDim2.fromOffset(10, 216),
	size = Vector2.new(250, 58),
	look = PILL_LOOK,
	iconName = "gem",
	icon = "💎",
	iconColor = hex("#1A8FE0"),
	textSize = 34,
})
local candyPill = UI.pill({
	parent = stats,
	position = UDim2.fromOffset(10, 284),
	size = Vector2.new(250, 58),
	look = PILL_LOOK,
	iconName = "candy",
	icon = "🍬",
	iconColor = Colors.witch,
	textSize = 34,
})
local boostLabel = UI.text({
	Size = UDim2.fromOffset(300, 44),
	TextColor3 = Colors.gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	MaxSize = 18,
	Text = "",
	Parent = stats,
})

-- In the marketplace the stack becomes one slim row, so the screen is free for walking.
local slim = UI.slot({ Name = "SlimStats", Size = UDim2.fromOffset(760, 60), Visible = false })
local function slimPill(index: number, look, name: string, icon: string, iconColor: Color3, glyphColor: Color3?)
	return UI.pill({
		parent = slim,
		iconName = name,
		position = UDim2.fromOffset(10 + (index - 1) * 188, 4),
		size = Vector2.new(170, 50),
		look = look,
		icon = icon,
		iconColor = iconColor,
		glyphColor = glyphColor,
		textSize = 28,
	})
end
local slimPower = slimPill(1, UI.Variants.travel, "power", "⚡", Colors.blue)
local slimCoins = slimPill(2, PILL_LOOK, "coin", "★", Colors.gold, hex("#FFF3A8"))
local slimGems = slimPill(3, PILL_LOOK, "gem", "💎", hex("#1A8FE0"))
local slimCandy = slimPill(4, PILL_LOOK, "candy", "🍬", Colors.witch)

----------------------------------------------------------------------------------------------------
-- Top centre: world, wave, the five monsters of the wave, and the timer as a burning fuse
----------------------------------------------------------------------------------------------------
-- One accent per world; worlds past the list take their floor colour.
local WORLD_ACCENTS = { hex("#6BD63A"), hex("#B9A8FF"), hex("#FF6A3D"), hex("#35D8F0"), hex("#FFB01F"), hex("#9B3DFF") }
local PIPS = 5

local wave = UI.slot({ Name = "Wave", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(584, 206) })
local wavePanel = UI.make("Frame", {
	Position = UDim2.fromOffset(92, 0),
	Size = UDim2.fromOffset(400, 124),
	BackgroundTransparency = 1,
	Parent = wave,
})
UI.sticker(wavePanel, UI.Variants.panel, { radius = 26, lip = 6, outline = 4, gloss = false })

-- The world tab is a button: it opens the WORLDS window (wired in init.client).
local worldTab = UI.make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(210, 32),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 2,
	Parent = wavePanel,
})
local worldSticker = UI.sticker(worldTab, UI.shade(WORLD_ACCENTS[1]), { radius = 32, lip = 3, gloss = false })
local worldLabel = UI.label({ Size = UDim2.new(1, 0, 1, -2), Font = UI.TITLE_FONT, TextSize = 20, Parent = worldSticker.face })
Hud.worldTab = worldTab

local waveLabel = UI.label({
	Position = UDim2.fromOffset(0, 43),
	Size = UDim2.new(1, 0, 0, 38),
	Font = UI.TITLE_FONT,
	TextSize = 36,
	Stroke = 3,
	ZIndex = 2,
	Parent = wavePanel,
})

local pipRow = UI.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 82),
	Size = UDim2.fromOffset(PIPS * 30 - 8, 22),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = wavePanel,
})
local pips: { Frame } = {}
for index = 1, PIPS do
	local outline = UI.stroke(2.5)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pips[index] = UI.make("Frame", {
		Position = UDim2.fromOffset((index - 1) * 30, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Colors.dark,
		BorderSizePixel = 0,
		Parent = pipRow,
	}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), outline })
end

-- Straddles the panel's bottom edge. It drains as the wave's time runs out.
local fuse = UI.bar({
	parent = wave,
	anchor = Vector2.new(0.5, 0),
	position = UDim2.new(0.5, 0, 0, 106),
	size = UDim2.fromOffset(340, 30),
	color = Colors.orange,
	textSize = 20,
})
fuse.frame.ZIndex = 3

local prevButton = UI.button({ Position = UDim2.fromOffset(14, 28), Size = UDim2.fromOffset(68, 68), Text = "<", BackgroundColor3 = Colors.blue, Parent = wave })
local nextButton = UI.button({ Position = UDim2.fromOffset(502, 28), Size = UDim2.fromOffset(68, 68), Text = ">", BackgroundColor3 = Colors.blue, Parent = wave })

-- Under the cluster: push on or farm, and how fast the monsters heal.
local autoToggle = UI.toggle({ parent = wave, position = UDim2.fromOffset(112, 146), size = Vector2.new(170, 56), textSize = 26 })
local healLabel = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 18, TextColor3 = Colors.ink, Stroke = 0 })
UI.chip({ Position = UDim2.fromOffset(294, 154), Size = UDim2.fromOffset(180, 40), Parent = wave }, { healLabel })

----------------------------------------------------------------------------------------------------
-- Bottom right: the main actions
----------------------------------------------------------------------------------------------------
local actions = UI.slot({
	Name = "Actions",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
	Size = UDim2.fromOffset(320, 190),
})
local rebirthButton = UI.button({ Size = UDim2.fromOffset(200, 84), Parent = actions })
local autoRebirthButton = UI.button({ Position = UDim2.fromOffset(208, 0), Size = UDim2.fromOffset(112, 84), Parent = actions })
local upgradeButton = UI.button({ Position = UDim2.fromOffset(0, 94), Size = UDim2.fromOffset(320, 96), Parent = actions })

Hud.actions = {
	buyCannon = upgradeButton,
	rebirth = rebirthButton,
	toggleAuto = autoToggle.button,
	prevWave = prevButton,
	nextWave = nextButton,
}

local function ownsAutoRebirth(): boolean
	return (State.meta.passes or {}).autoRebirth == true
end

-- Not in Hud.actions: what a press asks for depends on whether the Auto Rebirth pass is owned.
autoRebirthButton.Activated:Connect(function()
	if ownsAutoRebirth() then
		actionRemote:FireServer("toggleAutoRebirth")
	else
		actionRemote:FireServer("buyPass", "autoRebirth")
	end
end)

----------------------------------------------------------------------------------------------------
-- Bottom: first-time hint, and the way to the marketplace
----------------------------------------------------------------------------------------------------
local hintChip = UI.chip({ Size = UDim2.fromScale(1, 1) }, {
	UI.label({ Size = UDim2.fromScale(1, 1), Text = "👆 Tap anywhere to fire your cannon!", TextSize = 22, TextColor3 = Colors.ink, Stroke = 0 }),
})
local hint = UI.slot({
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -116),
	Size = UDim2.fromOffset(430, 46),
}, { hintChip })

function Hud.hideHint()
	hintChip.Visible = false
end

local travel = UI.slot({
	Name = "Travel",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, MARGIN, 1, -MARGIN),
	Size = UDim2.fromOffset(260, 84),
})

-- A little cannon drawn from frames, for the button that goes back to it.
local function cannonIcon(parent: Instance, position: UDim2): Frame
	local holder = UI.make("Frame", { Position = position, Size = UDim2.fromOffset(64, 58), BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
	local function piece(props, radius: UDim)
		local outline = UI.stroke(3)
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		props.BorderSizePixel = 0
		props.Parent = holder
		UI.make("Frame", props, { UI.make("UICorner", { CornerRadius = radius }), outline })
	end
	piece({ Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(50, 22), Rotation = -22, BackgroundColor3 = hex("#4A4466") }, UDim.new(0.45, 0))
	piece({ Position = UDim2.fromOffset(6, 30), Size = UDim2.fromOffset(44, 14), BackgroundColor3 = hex("#B9783F") }, UDim.new(0, 5))
	piece({ Position = UDim2.fromOffset(4, 34), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = hex("#8A5A2B") }, UDim.new(0.5, 0))
	piece({ Position = UDim2.fromOffset(32, 36), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = hex("#8A5A2B") }, UDim.new(0.5, 0))
	return holder
end

-- Marketplace: the way back to the cannon.
local market = UI.slot({ Name = "Market", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(270, 92), Visible = false })
local backButton = UI.button({ Size = UDim2.fromOffset(270, 92), Text = "BACK TO\nCANNON", BackgroundColor3 = Colors.orange, Parent = market })
do
	local label = backButton:FindFirstChild("Label", true) :: TextLabel
	label.Position = UDim2.fromOffset(88, 6)
	label.Size = UDim2.new(1, -102, 1, -12)
	local drawn = cannonIcon(label.Parent :: Instance, UDim2.fromOffset(16, 13))
	UI.icon("cannon", { Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(78, 78), ZIndex = 3, Parent = label.Parent }, drawn)
end
Hud.backButton = backButton

----------------------------------------------------------------------------------------------------
-- Right: menu orbs, in a block above the action buttons. The top-right corner is left to Roblox's player list.
-- Five are pinned per view; the rest live in a drawer behind MORE.
-- Buttons are added with Hud.addMenuButton: by init.client for the core windows, by features for their own.
----------------------------------------------------------------------------------------------------
local CELL = Vector2.new(112, 104)
local ORB = 70
local MENU_COLUMNS = 3
-- What each known button looks like as an orb. A name not listed keeps its own colour and shows its first letter.
local ORBS = {
	STORE = { color = hex("#FF5FA8"), icon = "🛍️", picture = "store" },
	["MINI CANNONS"] = { label = "MINIS", color = hex("#FFC61A"), icon = "💣", picture = "minicannon" },
	MISSIONS = { color = hex("#7C8CFF"), icon = "📜", picture = "missions" },
	DAILY = { color = hex("#5FE03A"), icon = "🎁", picture = "gift" },
	TRADE = { color = hex("#7C4DFF"), icon = "⇄", picture = "trade" },
	BACKPACK = { label = "BAG", color = hex("#35D8F0"), icon = "🎒", picture = "backpack" },
	WORLDS = { color = hex("#FF8A1F"), icon = "🌍", picture = "worlds" },
	["TOP PLAYERS"] = { label = "TOP", color = hex("#A64BFF"), icon = "🏆", picture = "trophy" },
	AMMO = { color = hex("#FF6A3D"), icon = "💥", picture = "ammo" },
	STORY = { color = hex("#FFC61A"), icon = "📖", picture = "story" },
	INDEX = { color = hex("#FF6FB5"), icon = "📇", picture = "index" },
	LOOT = { color = hex("#2FA8FF"), icon = "🎲", picture = "loot" },
	MARKET = { color = hex("#FF9A3D"), icon = "🏪", picture = "market" },
	BASE = { color = hex("#FF9A3D"), icon = "🏰", picture = "cannon" },
	SETTINGS = { color = hex("#97A0B9"), icon = "⚙️", picture = "gear" },
	STATS = { color = hex("#FFC61A"), icon = "S", picture = "upgrade" },
	VISIT = { color = hex("#46C896"), icon = "V", picture = "base" },
	CODES = { color = hex("#5FC878"), icon = "C", picture = "enchantkey" },
	MORE = { color = Colors.cream, dots = true },
}
Hud.PINNED = {
	cannon = { "STORE", "MINI CANNONS", "MISSIONS", "DAILY", "WORLDS" },
	market = { "TRADE", "STORE" },
}
local DRAWER_COLUMNS = 3

Hud.menu = {}
local menuOrder: { [string]: number } = {}
local badges: { [string]: Frame } = {}

local menuGrid = UI.slot({ Name = "Menu", Size = UDim2.fromOffset(CELL.X * MENU_COLUMNS, CELL.Y * 2), ZIndex = 4 })
-- Catches the tap that closes the drawer, so it does not fire the cannon.
local drawerBackdrop = UI.make("TextButton", {
	Name = "DrawerBackdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	Visible = false,
	ZIndex = 2,
	Parent = menuGrid.Parent,
})
-- In the marketplace the orbs stand in one column inside a dark capsule.
local capsuleLine = UI.stroke(3, Colors.cream)
capsuleLine.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local capsule = UI.make("Frame", {
	Name = "Capsule",
	Position = UDim2.fromOffset(-6, -8),
	Size = UDim2.new(1, 12, 1, 14),
	BackgroundColor3 = Colors.ink,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 0,
	Parent = menuGrid,
}, { UI.corner(54), capsuleLine })
local drawer = UI.slot({ Name = "Drawer", Visible = false, ZIndex = 3 })
UI.sticker(drawer, { top = Colors.cream, bottom = Colors.cream, lip = Colors.creamShade }, { radius = 24, lip = 6, outline = 4, gloss = false })
local drawerBody = UI.make("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -26), BackgroundTransparency = 1, ZIndex = 2, Parent = drawer })

local function orb(name: string, color: Color3): TextButton
	local look = ORBS[name] or { color = color, icon = string.sub(name, 1, 1) }
	local button: TextButton = UI.make("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(CELL.X, CELL.Y),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	local circle = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(ORB, ORB),
		BackgroundTransparency = 1,
		Parent = button,
	})
	local squash = UI.make("UIScale", { Parent = circle })
	local sticker = UI.sticker(circle, UI.shade(look.color), { radius = ORB, lip = 5, outline = 4 })
	if look.dots then
		-- Four dots: "there is more in here".
		for index = 0, 3 do
			local dot = UI.stroke(2.5)
			dot.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			UI.make("Frame", {
				Position = UDim2.fromOffset(18 + (index % 2) * 19, 15 + math.floor(index / 2) * 19),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = Colors.creamShade,
				BorderSizePixel = 0,
				Parent = sticker.face,
			}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), dot })
		end
	else
		local glyph = UI.text({ Position = UDim2.fromScale(0.2, 0.17), Size = UDim2.fromScale(0.6, 0.6), Text = look.icon, Parent = sticker.face })
		UI.icon(look.picture, { Position = UDim2.fromScale(0.11, 0.07), Size = UDim2.fromScale(0.78, 0.78), Parent = sticker.face }, glyph)
	end
	badges[name] = UI.badge(circle)

	local text = look.label or name
	local width = math.min(CELL.X - 4, TextService:GetTextSize(text, 20, UI.FONT, Vector2.new(400, 30)).X + 26)
	local plateOutline = UI.stroke(3)
	plateOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UI.make("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, ORB - 4),
		Size = UDim2.fromOffset(width, 30),
		BackgroundColor3 = Colors.dark,
		BorderSizePixel = 0,
		Parent = button,
	}, {
		UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		plateOutline,
		UI.text({ Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 1, -6), Text = text, MaxSize = 20 }),
	})

	button.MouseButton1Down:Connect(function()
		TweenService:Create(squash, UI.Motion.press, { Scale = 0.92 }):Play()
	end)
	local function release()
		TweenService:Create(squash, UI.Motion.release, { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return button
end

local function setDrawer(open: boolean)
	drawer.Visible = open
	drawerBackdrop.Visible = open
end
drawerBackdrop.Activated:Connect(function()
	setDrawer(false)
end)

local moreButton = orb("MORE", Colors.cream)
moreButton.Activated:Connect(function()
	setDrawer(not drawer.Visible)
end)

local travelButton: TextButton? = nil
local flagged: { [string]: boolean } = {}

local function layoutMenu()
	local view = if inMarket then "market" else "cannon"
	local columns = if inMarket then 1 else MENU_COLUMNS
	local pinned: { [string]: boolean } = {}
	local cell = 0
	local function place(button: TextButton, parent: Instance, columns: number)
		button.Position = UDim2.fromOffset((cell % columns) * CELL.X, math.floor(cell / columns) * CELL.Y)
		button.Parent = parent
		button.Visible = true
		cell += 1
	end
	for _, name in Hud.PINNED[view] do
		local button = Hud.menu[name]
		local where = button and button:GetAttribute("View")
		if button and (where == "both" or where == view) then
			pinned[name] = true
			place(button, menuGrid, columns)
		end
	end
	place(moreButton, menuGrid, columns)
	menuGrid.Size = UDim2.fromOffset(CELL.X * columns, CELL.Y * math.ceil(cell / columns))
	capsule.Visible = inMarket

	-- Everything else, in the order it was registered with.
	local rest = {}
	for name, button in Hud.menu do
		local where = button:GetAttribute("View")
		if button ~= travelButton and not pinned[name] then
			button.Visible = false
			if where == "both" or where == view then
				table.insert(rest, name)
			end
		end
	end
	table.sort(rest, function(a, b)
		return menuOrder[a] < menuOrder[b]
	end)
	cell = 0
	local moreFlagged = false
	for _, name in rest do
		place(Hud.menu[name], drawerBody, DRAWER_COLUMNS)
		moreFlagged = moreFlagged or flagged[name] == true
	end
	local rows = math.max(1, math.ceil(#rest / DRAWER_COLUMNS))
	drawer.Size = UDim2.fromOffset(DRAWER_COLUMNS * CELL.X + 20, rows * CELL.Y + 26)
	badges.MORE.Visible = moreFlagged
	moreButton.Visible = #rest > 0
	if travelButton then
		travelButton.Visible = not inMarket
	end
end

-- order sorts the buttons, low first. view is "both" (default), "cannon" or "market": where the button shows.
function Hud.addMenuButton(name: string, color: Color3, order: number, onClick: () -> (), view: string?): TextButton
	local button: TextButton
	if name == "MARKETPLACE" then
		-- Travelling is not a window: it is the orange button in the bottom-left corner.
		button = UI.button({ Size = UDim2.fromOffset(260, 84), Text = name, BackgroundColor3 = Colors.orange, Parent = travel })
		local label = button:FindFirstChild("Label", true) :: TextLabel
		local glyph = UI.text({ Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(52, 50), Text = "🏪", Parent = label.Parent })
		UI.icon("market", { Position = UDim2.fromOffset(6, 2), Size = UDim2.fromOffset(72, 72), ZIndex = 3, Parent = label.Parent }, glyph)
		label.Position = UDim2.fromOffset(76, 6)
		label.Size = UDim2.new(1, -86, 1, -12)
		badges[name] = UI.badge(button)
		travelButton = button
	else
		button = orb(name, color)
	end
	button:SetAttribute("View", view or "both")
	button.Activated:Connect(function()
		setDrawer(false)
		onClick()
	end)
	Hud.menu[name] = button
	menuOrder[name] = order
	layoutMenu()
	return button
end

-- "!" on menu buttons that have something to claim. MORE carries it for the buttons in the drawer.
function Hud.setFlags(flags: { [string]: boolean })
	flagged = flags
	local moreFlagged = false
	for name, button in Hud.menu do
		local on = flags[name] == true
		badges[name].Visible = on
		if on and button.Parent == drawerBody and button.Visible then
			moreFlagged = true
		end
	end
	badges.MORE.Visible = moreFlagged
end

----------------------------------------------------------------------------------------------------
-- Layout: what depends on the screen's width and on the Roblox top bar
----------------------------------------------------------------------------------------------------
local toastPanel: Frame
local layoutHooks: { (layout: any) -> () } = {}
local layout = { s = 1, W = 1280, T = 58, top = 8, stack = 66, toast = 252, noteRight = 16, noteTop = 12 }

local function relayout()
	local s, W, T = UI.scale(), UI.W(), UI.T()
	-- The cluster sits at the very top unless Roblox's own buttons are in its way.
	local inset = GuiService.TopbarInset
	local clusterLeft, clusterRight = (W / 2 - 292) * s, (W / 2 + 292) * s
	local clear = inset.Width == 0 or (clusterLeft >= inset.Min.X and clusterRight <= inset.Max.X)
	local top = if clear then 8 else T + 8
	-- On a narrow screen the left stack would run into the wave arrows, so it starts below them.
	local stack = if W < 1200 then math.max(T + 8, top + 132) else T + 8

	layout.s, layout.W, layout.T, layout.top, layout.stack = s, W, T, top, stack
	layout.toast = top + 244
	stats.Position = UDim2.fromOffset(MARGIN, stack)
	wave.Position = UDim2.new(0.5, 0, 0, top)
	market.Position = UDim2.new(0.5, 0, 0, top)
	-- At the cannon the menu sits on the action buttons. In the marketplace it is a column on the right edge,
	-- above the jump button.
	local anchor = if inMarket then Vector2.new(1, 0.5) else Vector2.new(1, 1)
	local y = if inMarket then UDim.new(0.45, 0) else UDim.new(1, -(MARGIN + 190 + 10))
	local right = if inMarket then MARGIN + 6 else MARGIN
	local columns = if inMarket then 1 else MENU_COLUMNS
	menuGrid.AnchorPoint, drawer.AnchorPoint = anchor, anchor
	menuGrid.Position = UDim2.new(UDim.new(1, -right), y)
	drawer.Position = UDim2.new(UDim.new(1, -right - CELL.X * columns - 18), y)
	slim.Position = UDim2.fromOffset(MARGIN, T + 8)
	-- Notifications hang in the top-right corner, left of the menu column when that stands on the right edge.
	layout.noteRight = if inMarket then right + CELL.X * columns + 18 else MARGIN
	layout.noteTop = 12
	if toastPanel then
		toastPanel.Position = UDim2.new(1, -layout.noteRight * s, 0, layout.noteTop * s)
	end
	for _, hook in layoutHooks do
		hook(layout)
	end
end

-- For features with HUD pieces of their own: fn(layout) runs now and whenever the layout changes.
-- layout: s (screen scale), W (canvas width), T (top bar height), top (y of the wave cluster),
-- stack (y of the left stack), toast (y of the old toast line under the cluster), noteRight and noteTop (the
-- top-right corner of the notification stack, from the screen's right and top edges).
-- All but s are in design px (720 tall).
function Hud.onLayout(fn: (layout: any) -> ())
	table.insert(layoutHooks, fn)
	fn(layout)
end

function Hud.setMode(marketMode: boolean)
	inMarket = marketMode
	wave.Visible = not marketMode
	actions.Visible = not marketMode
	hint.Visible = not marketMode
	market.Visible = marketMode
	stats.Visible = not marketMode
	slim.Visible = marketMode
	setDrawer(false)
	layoutMenu()
	relayout()
end

----------------------------------------------------------------------------------------------------
-- Notifications: server messages and level news, stacked in the top-right corner beside the menu, out of the
-- way of the fight. The newest is on top; each pops in and leaves on its own.
----------------------------------------------------------------------------------------------------
local NOTE_KINDS = {
	good = { look = UI.Variants.primary, disc = hex("#1C7A14"), glyph = "✓" },
	bad = { look = UI.Variants.danger, disc = hex("#8A1026"), glyph = "!" },
	info = { look = PILL_LOOK, disc = Colors.blue, glyph = "i" },
}
local NOTE_WIDTH = 440 -- the widest a notification gets
local NOTE_HEIGHT = 48
local NOTE_GAP = 8
local NOTE_MAX = 4
-- In front of the windows: a notification is never hidden behind one.
toastPanel = UI.panel({ Name = "Notifications", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(NOTE_WIDTH, 300), ZIndex = 30 })

local notes = {} -- on screen, newest first
local noteInset = 0 -- design px kept free at the top of the stack (the story's dialogue box sits there)

local function restack()
	for index, note in notes do
		local y = noteInset + (index - 1) * (NOTE_HEIGHT + NOTE_GAP)
		TweenService:Create(note.frame, UI.Motion.glide, { Position = UDim2.new(1, 0, 0, y) }):Play()
	end
end

local function dismiss(note)
	local index = table.find(notes, note)
	if not index then
		return
	end
	table.remove(notes, index)
	TweenService:Create(note.pop, UI.Motion.press, { Scale = 0.6 }):Play()
	task.delay(0.07, function()
		note.frame:Destroy()
	end)
	restack()
end

-- For a feature that puts something of its own at the head of the stack: keeps `height` design px free there.
function Hud.reserveNotices(height: number)
	if height ~= noteInset then
		noteInset = height
		restack()
	end
end

-- kind: good, bad or info.
function Hud.toast(message: string, kind: string?)
	local look = NOTE_KINDS[kind or "info"] or NOTE_KINDS.info
	if kind == "bad" then
		UI.sound("error")
	end
	local textWidth = TextService:GetTextSize(message, 22, UI.FONT, Vector2.new(2000, NOTE_HEIGHT)).X
	local frame = UI.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, noteInset),
		Size = UDim2.fromOffset(math.clamp(textWidth + 76, 170, NOTE_WIDTH), NOTE_HEIGHT),
		BackgroundTransparency = 1,
		Parent = toastPanel,
	})
	local pop = UI.make("UIScale", { Scale = 0.6, Parent = frame })
	local sticker = UI.sticker(frame, look.look, { radius = NOTE_HEIGHT, lip = 4, outline = 3, gloss = false })
	UI.disc({ Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(36, 36), ZIndex = 2, Parent = sticker.face }, look.disc, look.glyph)
	UI.text({
		Position = UDim2.fromOffset(48, 4),
		Size = UDim2.new(1, -62, 1, -12),
		Text = message,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = 22,
		ZIndex = 2,
		Parent = sticker.face,
	})
	local note = { frame = frame, pop = pop }
	table.insert(notes, 1, note)
	while #notes > NOTE_MAX do
		dismiss(notes[#notes])
	end
	restack()
	TweenService:Create(pop, UI.Motion.pop, { Scale = 1 }):Play()
	-- Longer lines stay longer.
	task.delay(math.clamp(2.2 + #message * 0.03, 2.4, 5), function()
		dismiss(note)
	end)
end
Hud.notify = Hud.toast

----------------------------------------------------------------------------------------------------
-- Floating numbers: a small pool of labels, so a fast tapper creates nothing
----------------------------------------------------------------------------------------------------
local POPUPS = 16
local popups: { { label: TextLabel, tween: Tween? } } = {}
local nextPopup = 1
for index = 1, POPUPS do
	popups[index] = {
		label = UI.make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = UI.FONT,
			TextScaled = true,
			TextStrokeColor3 = Colors.ink,
			Visible = false,
			ZIndex = 5,
			Parent = UI.gui,
		}),
	}
end

-- A number that floats up from a screen position and fades.
function Hud.popup(position: Vector2 | Vector3, message: string, color: Color3?)
	local popup = popups[nextPopup]
	nextPopup = nextPopup % POPUPS + 1
	if popup.tween then
		popup.tween:Cancel()
	end
	local s = UI.scale()
	local label = popup.label
	label.Text = message
	label.TextColor3 = color or Colors.power
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0
	label.Size = UDim2.fromOffset(220 * s, 44 * s)
	label.Position = UDim2.fromOffset(position.X + math.random(-24, 24), position.Y - 30)
	label.Rotation = math.random(-8, 8)
	label.Visible = true
	local tween = TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 90 * s),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	popup.tween = tween
	tween:Play()
end

----------------------------------------------------------------------------------------------------
local lastCoins: number? = nil
local shownWorld = 0

function Hud.refresh()
	local coins = State.get("Coins", 0)
	local waveNumber = State.get("Wave", 1)
	local cleared = State.get("Cleared", 0)
	local rebirths = State.get("Rebirths", 0)
	local worldIndex, localWave = Config.worldOf(waveNumber)
	local world = Config.Worlds[worldIndex]
	local monster = Config.monsterFor(waveNumber)
	local eventOn = State.meta.event ~= nil and State.meta.event.active == true

	powerPill.label.Text = Format.abbreviate(State.get("Power", 0))
	coinPill.label.Text = Format.abbreviate(coins)
	gemPill.label.Text = Format.abbreviate(State.get("Diamonds", 0))
	candyPill.label.Text = Format.abbreviate(State.get("Candy", 0))
	candyPill.frame.Visible = eventOn
	slimPower.label.Text = powerPill.label.Text
	slimCoins.label.Text = coinPill.label.Text
	slimGems.label.Text = gemPill.label.Text
	slimCandy.label.Text = candyPill.label.Text
	slimCandy.frame.Visible = eventOn
	boostLabel.Position = UDim2.fromOffset(4, if eventOn then 352 else 284)
	perClickLabel.Text = `+{Format.abbreviate(State.get("PerClick", 1))} per click`
	local into, need = State.get("MasteryInto", 0), State.get("MasteryNeed", 25)
	masteryBar.set(into / math.max(1, need), `Mastery Lv {State.get("MasteryLevel", 0)}`)

	-- Coins earned since the last refresh float up next to the pill.
	if lastCoins and coins > lastCoins then
		local frame = coinPill.frame
		local at = frame.AbsolutePosition + Vector2.new(frame.AbsoluteSize.X + 60 * UI.scale(), frame.AbsoluteSize.Y / 2 + 30)
		Hud.popup(at, `+{Format.abbreviate(coins - lastCoins)}`, Colors.gold)
	end
	lastCoins = coins

	if worldIndex ~= shownWorld then
		shownWorld = worldIndex
		worldSticker.set(UI.shade(WORLD_ACCENTS[worldIndex] or world.floor:Lerp(Colors.white, 0.25)))
	end
	worldLabel.Text = string.upper(world.name)
	local kindText = if monster.kind == "final" then "WORLD BOSS" elseif monster.kind == "normal" then `WAVE {localWave}/{Config.WavesPerWorld}` else `BOSS {localWave}/{Config.WavesPerWorld}`
	waveLabel.Text = kindText
	waveLabel.TextColor3 = if monster.kind == "normal" then Colors.white else hex("#FFD0D6")
	prevButton.BackgroundColor3 = if waveNumber > 1 then Colors.blue else Colors.grey
	nextButton.BackgroundColor3 = if waveNumber <= cleared and waveNumber < Config.TotalWaves then Colors.blue else Colors.grey

	-- One pip per monster in the wave; a boss is a single wide pip.
	local count, index = State.get("TargetCount", 1), State.get("TargetIndex", 1)
	local shown = math.min(count, PIPS)
	local pipWidth = if shown == 1 then PIPS * 30 - 8 else 22
	for pipIndex, pip in pips do
		pip.Visible = pipIndex <= shown
		pip.Size = UDim2.fromOffset(pipWidth, 22)
		pip.BackgroundColor3 = if shown == 1 then Colors.red elseif pipIndex < index then Colors.green elseif pipIndex == index then Colors.gold else Colors.dark
	end

	-- One press buys every cannon the coins reach, so the button shows where that press lands.
	local cannon = State.get("Cannon", 1)
	local reach, coinsLeft = Config.affordableCannon(cannon, coins)
	local target = Config.Cannons[math.max(reach, cannon + 1)]
	if target then
		local several = reach > cannon + 1
		local title = if several then `BUY {reach - cannon} CANNONS` else string.upper(target.name)
		local cost = if several then coins - coinsLeft else target.cost
		upgradeButton.Text = `{title}\n★ {Format.abbreviate(cost)}  •  x{Format.abbreviate(target.mult)} power`
		upgradeButton.BackgroundColor3 = if reach > cannon then Colors.green else Colors.grey
	else
		upgradeButton.Text = "CANNON MAXED"
		upgradeButton.BackgroundColor3 = Colors.grey
	end

	local rebirthNeed = Config.rebirthWave(rebirths)
	if cleared >= rebirthNeed then
		rebirthButton.Text = `REBIRTH NOW\nx{rebirths + 2} power forever`
		rebirthButton.BackgroundColor3 = Colors.gold
	else
		rebirthButton.Text = `REBIRTH\nClear {Config.waveLabel(rebirthNeed)}`
		rebirthButton.BackgroundColor3 = Colors.grey
	end

	-- Owners get an on/off switch; for everyone else it is locked and a press offers the pass.
	if ownsAutoRebirth() then
		local on = State.get("AutoRebirth", true)
		autoRebirthButton.Text = if on then "AUTO\nREBIRTH\nON" else "AUTO\nREBIRTH\nOFF"
		autoRebirthButton.BackgroundColor3 = if on then Colors.blue else Colors.grey
	else
		autoRebirthButton.Text = "🔒 AUTO\nREBIRTH"
		autoRebirthButton.BackgroundColor3 = Colors.premium
	end

	local auto = State.get("AutoAdvance", true)
	autoToggle.set(auto, if auto then "AUTO" else "FARM", if auto then UI.Variants.primary else UI.Variants.gold)
end

-- What changes without any state change: the wave timer and the boosts' countdowns.
function Hud.tick()
	local now = State.now()
	local endsAt = State.get("WaveEndsAt", 0)
	-- The server sends the real rate: it can be lower than the wave's base rate (mini cannon perks).
	local regen = math.floor(State.get("HealRate", Config.regenRate(State.get("Wave", 1))) * 1000 + 0.5) / 10
	healLabel.Text = `HEALS {regen}%/S`
	if endsAt > 0 then
		local left = math.max(0, endsAt - now)
		local total = math.max(1, Config.waveTime(State.get("Wave", 1)))
		fuse.set(left / total, `{math.floor(left / 60)}:{string.format("%02d", math.ceil(left) % 60)}`)
		fuse.setColor(if left <= 10 then Colors.red else Colors.orange)
	else
		fuse.set(1, "TAP TO START")
		fuse.setColor(Colors.orange)
	end

	local parts = {}
	for id, boost in Config.Boosts do
		local expires = State.meta.boosts and State.meta.boosts[id]
		if expires and expires > now then
			table.insert(parts, `{boost.name} {Format.duration(expires - now)}`)
		end
	end
	table.sort(parts)
	boostLabel.Text = table.concat(parts, "  •  ")
end

UI.onLayout(relayout)

return Hud
