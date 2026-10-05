-- The loot viewer: one window that shows what a player can get from opening something, as a grid of cards
-- with every chance, and a catalogue of everything that can be opened (eggs, crates ...).
--
--   Loot.register(source)  adds something to the catalogue (see docs/ARCHITECTURE.md for the shape)
--   Loot.open(id)          opens the viewer on a registered source; with no id, on the catalogue
--   Loot.show(spec)        shows a one-off table
--
-- The eggs are registered at the bottom of this file. Their chances come from Config.eggOdds, the function
-- the server rolls with: Roblox requires the odds shown for random items to be the real ones.
-- Cards and tiles are made once and reused; a refresh only rewrites them when something on them changed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Windows = require(script.Parent.Windows)

local Colors = UI.Colors

local Loot = {}

local NAME = "LOOT" -- the window's title, its menu button and its name in Windows.byName
local WINDOW = Vector2.new(800, 600)
local LIST_WIDTH = WINDOW.X - 24 - 10 -- the window's body, less the scroll bar
local INSET = 3 -- cards and tiles start this far in, so their borders are not cut off by the list's edge
local GAP = 8
local HEADER_HEIGHT = 84
local CARD_COLUMNS = 4
local CARD_SIZE = Vector2.new(math.floor((LIST_WIDTH - INSET - (CARD_COLUMNS - 1) * GAP) / CARD_COLUMNS), 213)
local TILE_COLUMNS = 5
local TILE_SIZE = Vector2.new(math.floor((LIST_WIDTH - INSET - (TILE_COLUMNS - 1) * GAP) / TILE_COLUMNS), 96)
local MAX_PREVIEWS = 16 -- 3D previews in one table; the cards after that get the plain icon
local RENDER_GAP = 0.2 -- state changes many times a second (coins); the viewer follows at most this often
local ONE_IN_BELOW = 0.1 -- per cent: anything rarer than 1 in 1,000 also reads as "1 in N"

local NEUTRAL = Color3.fromRGB(160, 166, 182) -- rewards without a rarity, or with one this game does not know
local MYSTERY_BACK = Color3.fromRGB(26, 27, 34)
local SILHOUETTE = Color3.fromRGB(12, 12, 18)
local LUCK_GREEN = Color3.fromRGB(46, 140, 70)
local ICONS = { coins = "💰", diamonds = "💎", candy = "🍬" }
local BALANCE_ATTRIBUTE = { coins = "Coins", diamonds = "Diamonds", candy = "Candy" }

----------------------------------------------------------------------------------------------------
-- What the player has: owned counts and the index of what they have found
----------------------------------------------------------------------------------------------------
local countedMeta = nil -- the State.meta the counts below were made from (a new table after every change)
local ownedByBase: { [string]: number } = {}

-- How many of a mini cannon the player owns, fused ones included (wooden_silver counts as wooden).
function Loot.owned(petId: string): number
	if State.meta ~= countedMeta then
		countedMeta = State.meta
		ownedByBase = {}
		local pets = State.meta.pets
		if typeof(pets) == "table" then
			for id, count in pets do
				local pet = Config.Pets[id]
				if pet and typeof(count) == "number" then
					local base = pet.base or id
					ownedByBase[base] = (ownedByBase[base] or 0) + count
				end
			end
		end
	end
	local pet = Config.Pets[petId]
	return ownedByBase[if pet then pet.base or petId else petId] or 0
end

-- Whether the player has ever had this mini cannon: a hidden one stops being "???" once this is true.
function Loot.found(petId: string): boolean
	if Loot.owned(petId) > 0 then
		return true
	end
	local pet = Config.Pets[petId]
	local found = State.feature("huge").found
	return typeof(found) == "table" and found[if pet then pet.base or petId else petId] == true
end

-- The player's luck when hatching. The server sends the real number (the x3 Luck pass times every luck boost)
-- as the Luck attribute; until that arrives, the pass alone decides.
function Loot.luck(): number
	local luck = State.get("Luck", nil)
	if typeof(luck) == "number" then
		return math.max(1, luck)
	end
	return if (State.meta.passes or {}).tripleLuck then Config.LuckPassMultiplier else 1
end

-- A luck multiplier without long decimals: 3 -> "3", 2.5 -> "2.5".
function Loot.luckText(luck: number): string
	return (string.gsub(string.format("%.2f", luck), "%.?0+$", ""))
end

-- How many of an egg's mini cannons the player has found, and how many it holds.
function Loot.collected(egg): (number, number)
	local found = 0
	for _, entry in egg.pets do
		if Loot.found(entry.id) then
			found += 1
		end
	end
	return found, #egg.pets
end

----------------------------------------------------------------------------------------------------
-- 3D previews: a mini cannon built from the same parts as the ones on the plots (Plots.buildPets), shown
-- in a ViewportFrame. A hidden one is a dark silhouette with glowing eyes.
----------------------------------------------------------------------------------------------------
local MINI_DIRECTION = Vector3.new(0, 0.2, 1).Unit
local VIEW_DIRECTION = Vector3.new(0.8, 0.5, -0.75).Unit -- from behind and to one side: the eyes are at the back
local NEON_RARITIES = { Legendary = true, Exclusive = true, Secret = true, Mythical = true }
local WHEEL = Color3.fromRGB(40, 40, 40)

-- A cylinder's long axis is its X axis; this points that axis along `direction`.
local function along(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
end

local function buildMini(pet, silhouette: boolean): Model
	local model = Instance.new("Model")
	local modelled = require(ReplicatedStorage.Shared.Models).mini(pet, 0.85)
	if modelled then
		-- Turned to face the camera. A hidden one is the same shape painted dark.
		if silhouette then
			modelled.Color = SILHOUETTE
		end
		modelled:PivotTo(CFrame.Angles(0, math.rad(90), 0))
		modelled.Parent = model
		return model
	end
	local function part(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, neon: boolean?): Part
		local piece = Instance.new("Part")
		piece.Anchored = true
		piece.CanCollide = false
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece.Shape = shape
		piece.Size = size
		piece.CFrame = cframe
		piece.Color = if silhouette then SILHOUETTE else color
		piece.Material = if neon and not silhouette then Enum.Material.Neon else Enum.Material.SmoothPlastic
		piece.Parent = model
		return piece
	end
	local cylinder, ball = Enum.PartType.Cylinder, Enum.PartType.Ball
	local direction = MINI_DIRECTION
	local accent = pet.accent or Colors.gold

	part(cylinder, Vector3.new(2.2, 1, 1), along(Vector3.zero, direction), pet.color, NEON_RARITIES[pet.rarity])
	if pet.huge then
		for _, offset in { 0.85, 0.2, -0.75 } do
			part(cylinder, Vector3.new(0.16, 1.2, 1.2), along(direction * offset, direction), accent, true)
		end
		-- A cylinder lies along its X axis: stood on end it is a flat disc, floating over the eyes.
		local halo = part(cylinder, Vector3.new(0.07, 1.3, 1.3), CFrame.new(0, 1.05, -0.1) * CFrame.Angles(0, 0, math.rad(90)), accent, true)
		halo.Transparency = 0.3
	end
	-- A fused one wears one band per tier, in its tier's colour.
	local tier = Config.FuseTiers[pet.tier or 0]
	if tier then
		for band = 1, pet.tier do
			part(cylinder, Vector3.new(0.18, 1.28, 1.28), along(direction * (1.19 - band * 0.29), direction), tier.color, true)
		end
	end
	local glow = Config.RarityColors[pet.rarity] or NEUTRAL
	for _, side in { -1, 1 } do
		part(cylinder, Vector3.new(0.25, 0.9, 0.9), CFrame.new(side * 0.62, -0.35, -0.2), WHEEL)
		local eye = part(ball, Vector3.one * 0.36, CFrame.new(side * 0.24, 0.42, -0.6), Colors.white)
		if silhouette then
			-- All that shows of a hidden one: its shape, and its eyes glowing in its rarity's colour.
			eye.Color = glow
			eye.Material = Enum.Material.Neon
		else
			part(ball, Vector3.one * 0.18, CFrame.new(side * 0.24, 0.5, -0.74), Color3.new(0, 0, 0))
		end
	end
	return model
end

----------------------------------------------------------------------------------------------------
-- The window: a table page (header and cards) and a catalogue page (tiles in groups)
----------------------------------------------------------------------------------------------------
local window = UI.window(NAME, WINDOW.X, WINDOW.Y)
local left = Enum.TextXAlignment.Left

-- A scrolling area under `top`. Everything in it is placed by hand, and its canvas height is set by hand as
-- well as left to grow by itself: whichever of the two comes out taller wins, so the last row is always in reach.
local function scroller(parent: Instance, top: number): ScrollingFrame
	return UI.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
end

-- The picture of what is opened: an egg is a tall pill, anything else a rounded box.
local function emblem(parent: Instance, position: UDim2, scale: number)
	local corner = UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) })
	local frame = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		BackgroundColor3 = NEUTRAL,
		Parent = parent,
	}, {
		corner,
		UI.stroke(2),
		-- Lighter at the top left, so the flat colour reads as something round.
		UI.make("UIGradient", { Rotation = 55, Color = ColorSequence.new(Colors.white, Color3.fromRGB(150, 150, 160)) }),
	})
	local function set(shape: string?, color: Color3)
		if shape == "egg" then
			frame.Size = UDim2.fromOffset(46 * scale, 60 * scale)
			corner.CornerRadius = UDim.new(0.5, 0)
		else
			frame.Size = UDim2.fromOffset(54 * scale, 54 * scale)
			corner.CornerRadius = UDim.new(0.22, 0)
		end
		frame.BackgroundColor3 = color
	end
	return frame, set
end

local tablePage = UI.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = window.body })
local header = UI.make("Frame", {
	Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
	BackgroundColor3 = Colors.dark,
	Parent = tablePage,
}, { UI.corner(12) })
local backButton = UI.button({
	Position = UDim2.fromOffset(8, 10),
	Size = UDim2.fromOffset(104, HEADER_HEIGHT - 20),
	Text = "< ALL\nLOOT",
	BackgroundColor3 = Colors.blue,
	Parent = header,
})
local _, setHeaderEmblem = emblem(header, UDim2.fromOffset(150, HEADER_HEIGHT / 2), 1)
local TEXT_LEFT = 188
local CHIP_WIDTH = 178
local titleLabel = UI.text({
	Position = UDim2.fromOffset(TEXT_LEFT, 6),
	Size = UDim2.new(1, -TEXT_LEFT - CHIP_WIDTH - 20, 0, 32),
	TextXAlignment = left,
	TextColor3 = Colors.gold,
	Parent = header,
})
local subtitleLabel = UI.text({
	Position = UDim2.fromOffset(TEXT_LEFT, 40),
	Size = UDim2.new(1, -TEXT_LEFT - CHIP_WIDTH - 20, 0, 20),
	TextXAlignment = left,
	MaxSize = 17,
	Parent = header,
})
local noteLabel = UI.text({
	Position = UDim2.fromOffset(TEXT_LEFT, 62),
	Size = UDim2.new(1, -TEXT_LEFT - CHIP_WIDTH - 20, 0, 16),
	TextXAlignment = left,
	TextColor3 = Colors.text,
	MaxSize = 13,
	Parent = header,
})
local luckChip = UI.make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(CHIP_WIDTH, 46),
	BackgroundColor3 = LUCK_GREEN,
	Visible = false,
	Parent = header,
}, { UI.corner(12), UI.stroke(2) })
local luckLabel = UI.text({ Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -12), Parent = luckChip })

local grid = scroller(tablePage, HEADER_HEIGHT + GAP)
local emptyLabel = UI.text({
	Position = UDim2.fromOffset(0, HEADER_HEIGHT + 60),
	Size = UDim2.new(1, 0, 0, 30),
	TextColor3 = Colors.text,
	MaxSize = 20,
	Visible = false,
	Parent = tablePage,
})

local cataloguePage = UI.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = window.body })
UI.text({
	Size = UDim2.new(1, 0, 0, 22),
	TextColor3 = Colors.text,
	MaxSize = 16,
	Text = "Pick anything to see what is inside it, with every chance.",
	Parent = cataloguePage,
})
local list = scroller(cataloguePage, 28)

----------------------------------------------------------------------------------------------------
-- Cards: one per reward. Made as they are needed and reused for every table.
----------------------------------------------------------------------------------------------------
local cards = {}
local previewsWork = true -- false after a preview failed to build: every card then keeps the plain icon

local function cardAt(index: number)
	local card = cards[index]
	if card then
		return card
	end
	local column, line = (index - 1) % CARD_COLUMNS, (index - 1) // CARD_COLUMNS
	local frame = UI.make("Frame", {
		Position = UDim2.fromOffset(INSET + column * (CARD_SIZE.X + GAP), INSET + line * (CARD_SIZE.Y + GAP)),
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		BackgroundColor3 = Colors.row,
		Parent = grid,
	}, { UI.corner(12) })
	local border = UI.stroke(2.5)
	border.Parent = frame
	-- The picture: a panel shaded in the rarity's colour, with the preview on it.
	local shade = UI.make("UIGradient", { Rotation = 90 })
	local art = UI.make("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 84),
		BackgroundColor3 = Colors.white,
		Parent = frame,
	}, { UI.corner(10), shade })
	local disc = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(58, 58),
		Parent = art,
	}, {
		UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		UI.stroke(2),
		UI.make("UIGradient", { Rotation = 55, Color = ColorSequence.new(Colors.white, Color3.fromRGB(150, 150, 160)) }),
	})
	local glyph = UI.text({ Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), Text = "", Parent = disc })
	local owned = UI.text({
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(86, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = Colors.green,
		MaxSize = 13,
		ZIndex = 3,
		Visible = false,
		Parent = art,
	})
	UI.corner(8).Parent = owned

	local name = UI.text({
		Position = UDim2.fromOffset(6, 92),
		Size = UDim2.new(1, -12, 0, 34),
		TextWrapped = true,
		MaxSize = 17,
		Parent = frame,
	})
	local rarity = UI.text({ Position = UDim2.fromOffset(6, 127), Size = UDim2.new(1, -12, 0, 16), MaxSize = 14, Parent = frame })
	local detail = UI.text({
		Position = UDim2.fromOffset(6, 144),
		Size = UDim2.new(1, -12, 0, 16),
		TextColor3 = Colors.text,
		MaxSize = 14,
		Parent = frame,
	})
	local chanceBox = UI.make("Frame", {
		Position = UDim2.fromOffset(6, 164),
		Size = UDim2.new(1, -12, 0, 43),
		BackgroundColor3 = Colors.dark,
		Parent = frame,
	}, { UI.corner(8) })
	local chance = UI.text({ Parent = chanceBox })
	local oneIn = UI.text({
		Position = UDim2.fromOffset(4, 26),
		Size = UDim2.new(1, -8, 0, 14),
		TextColor3 = Colors.text,
		MaxSize = 13,
		Parent = chanceBox,
	})
	card = {
		frame = frame,
		border = border,
		shade = shade,
		art = art,
		disc = disc,
		glyph = glyph,
		owned = owned,
		name = name,
		rarity = rarity,
		detail = detail,
		chance = chance,
		oneIn = oneIn,
		viewport = nil :: ViewportFrame?,
		camera = nil :: Camera?,
		model = nil :: Model?,
		previewKey = "",
	}
	cards[index] = card
	return card
end

-- Puts the 3D mini cannon on a card. Only rebuilt when the card shows a different one.
local function showModel(card, pet, key: string, silhouette: boolean)
	if not card.viewport then
		local viewport = UI.make("ViewportFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(112, 84),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(175, 175, 175),
			LightColor = Color3.fromRGB(150, 150, 150),
			LightDirection = Vector3.new(-0.3, -1, 0.8),
			Parent = card.art,
		})
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		card.viewport, card.camera = viewport, camera
	end
	if card.previewKey ~= key or not card.model then
		if card.model then
			card.model:Destroy()
			card.model = nil
		end
		local model = buildMini(pet, silhouette)
		model.Parent = card.viewport
		card.model = model
		card.previewKey = key
		-- A Huge has a halo over it: look a little higher, from a little further.
		local target = Vector3.new(0, if pet.huge then 0.22 else 0.02, 0)
		card.camera.CFrame = CFrame.lookAt(target + VIEW_DIRECTION * (if pet.huge then 5.3 else 4.8), target)
	end
	card.viewport.Visible = true
end

local function hideModel(card)
	if card.viewport then
		card.viewport.Visible = false
	end
	if card.model then
		card.model:Destroy()
		card.model = nil
	end
	card.previewKey = ""
end

----------------------------------------------------------------------------------------------------
-- Tables: turning what a source's build returned into cards
----------------------------------------------------------------------------------------------------
-- One row of a table as what its card shows, or nil for a row that cannot be shown.
local function describe(row)
	if typeof(row) ~= "table" then
		return nil
	end
	local chance = row.chance
	if typeof(chance) ~= "number" or chance ~= chance then
		return nil
	end
	local data = {
		chance = chance,
		chanceText = Config.chanceText(chance),
		oneIn = if chance > 0 and chance < ONE_IN_BELOW then Config.oneIn(chance) else "",
		owned = 0,
		mystery = false,
		glyph = "",
	}
	local petId = if typeof(row.pet) == "string" then row.pet else nil
	local pet = petId and Config.Pets[petId]
	if pet then
		local base = Config.Pets[pet.base or petId] or pet
		data.pet, data.petId = pet, petId
		data.color = pet.color
		data.rarityColor = Config.RarityColors[pet.rarity] or NEUTRAL
		data.rarityText = string.upper(tostring(pet.rarity))
		data.owned = Loot.owned(petId)
		if base.hidden and not Loot.found(petId) then
			-- Its chance is always shown. What it is stays a mystery until the player has found one.
			data.mystery = true
			data.name = "???"
			data.detail = "Find one to reveal it"
			data.glyph = "?"
		else
			data.name = pet.name
			if pet.huge then
				-- A Huge multiplies all tower damage (Config.hugeMult); the others add damage of their own.
				data.rarityText ..= `  •  {Format.petPower(pet)} tower damage`
				data.detail = if typeof(pet.feature) == "string" then pet.feature else "Huge cannon"
			else
				data.detail = Format.petPower(pet)
			end
		end
	else
		local rarity = if typeof(row.rarity) == "string" then row.rarity else nil
		data.name = tostring(row.name or petId or "???")
		data.color = if typeof(row.color) == "Color3" then row.color else NEUTRAL
		data.rarityColor = if rarity then Config.RarityColors[rarity] or NEUTRAL else NEUTRAL
		data.rarityText = if rarity then string.upper(rarity) else ""
		data.detail = if row.detail ~= nil then tostring(row.detail) else ""
		data.glyph = if typeof(row.icon) == "string" then row.icon else ""
	end
	data.signature = table.concat({
		data.petId or "",
		data.name,
		data.chanceText,
		tostring(data.owned),
		data.rarityText,
		data.detail,
		data.glyph,
		data.color:ToHex(),
	}, "|")
	return data
end

local function fillCard(card, data, allowModel: boolean)
	local rarityColor = data.rarityColor
	card.frame.BackgroundColor3 = if data.mystery then MYSTERY_BACK else Colors.row
	card.border.Color = rarityColor
	card.shade.Color = ColorSequence.new(rarityColor:Lerp(Colors.dark, 0.3), rarityColor:Lerp(Colors.dark, 0.82))
	card.name.Text = data.name
	card.name.TextColor3 = if data.mystery then rarityColor else Colors.white
	card.rarity.Text = data.rarityText
	card.rarity.TextColor3 = rarityColor
	card.detail.Text = data.detail
	card.owned.Visible = data.owned > 0
	card.owned.Text = `OWNED x{data.owned}`

	card.chance.Text = data.chanceText
	card.chance.TextColor3 = if data.oneIn ~= "" then rarityColor else Colors.white
	if data.oneIn ~= "" then
		card.chance.Position = UDim2.fromOffset(4, 2)
		card.chance.Size = UDim2.new(1, -8, 0, 24)
	else
		card.chance.Position = UDim2.fromOffset(4, 7)
		card.chance.Size = UDim2.new(1, -8, 1, -14)
	end
	card.oneIn.Text = data.oneIn
	card.oneIn.Visible = data.oneIn ~= ""

	-- The preview: a 3D mini cannon when it can be built, a round icon in the reward's colour otherwise.
	local modelled = false
	if data.pet and allowModel and previewsWork then
		local key = data.petId .. (if data.mystery then "?" else "")
		local ok, err = pcall(showModel, card, data.pet, key, data.mystery)
		if ok then
			modelled = true
		else
			previewsWork = false
			warn(`[Loot] 3D previews are off, a preview could not be built: {err}`)
		end
	end
	if not modelled then
		hideModel(card)
	end
	card.disc.Visible = not modelled
	card.disc.BackgroundColor3 = if data.mystery then SILHOUETTE else data.color
	card.glyph.Text = data.glyph
end

----------------------------------------------------------------------------------------------------
-- Sources and the catalogue
----------------------------------------------------------------------------------------------------
local sources = {} -- [id] = { id, group, name, color, order, build, info, shape }
local groupOrder: { string } = {} -- the catalogue's sections, in the order they were first registered
local groupLabels: { [string]: TextLabel } = {}
local tiles = {} -- [source id] = its tile in the catalogue
local catalogueDirty = true -- a source was added: the tiles need placing again
local catalogueVisit = 0 -- goes up every time the catalogue is opened

local view = { kind = "catalogue" } :: { kind: string, id: string?, spec: any }
local viewSerial = 0 -- goes up every time the viewer is pointed at something
local shownSerial = -1
local shownSignature = nil :: string?
local warned = {} -- [source id] = true once its build has been reported as broken

local function tileFor(id: string)
	local tile = tiles[id]
	if tile then
		return tile
	end
	local button = UI.make("TextButton", {
		Size = UDim2.fromOffset(TILE_SIZE.X, TILE_SIZE.Y),
		BackgroundColor3 = Colors.row,
		AutoButtonColor = true,
		Text = "",
		Parent = list,
	}, { UI.corner(10) })
	local border = UI.stroke(2)
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- on a button, a stroke outlines the text unless told
	border.Parent = button
	local icon, setIcon = emblem(button, UDim2.fromOffset(26, 30), 0.7)
	local lock = UI.text({ Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), Text = "🔒", Visible = false, Parent = icon })
	tile = {
		button = button,
		border = border,
		setIcon = setIcon,
		lock = lock,
		name = UI.text({
			Position = UDim2.fromOffset(50, 5),
			Size = UDim2.new(1, -56, 0, 46),
			TextXAlignment = left,
			TextWrapped = true,
			MaxSize = 16,
			Parent = button,
		}),
		status = UI.text({
			Position = UDim2.fromOffset(8, 56),
			Size = UDim2.new(1, -16, 0, 18),
			TextXAlignment = left,
			MaxSize = 15,
			Parent = button,
		}),
		sub = UI.text({
			Position = UDim2.fromOffset(8, 76),
			Size = UDim2.new(1, -16, 0, 14),
			TextXAlignment = left,
			TextColor3 = Colors.text,
			MaxSize = 12,
			Parent = button,
		}),
		visit = -1,
		fallbackStatus = "",
	}
	button.Activated:Connect(function()
		Loot.open(id)
	end)
	tiles[id] = tile
	return tile
end

-- Places every group's heading and tiles. Only needed after a source was registered.
local function layoutCatalogue()
	local members: { [string]: { any } } = {}
	for _, source in sources do
		members[source.group] = members[source.group] or {}
		table.insert(members[source.group], source)
	end
	local y = INSET
	for _, group in groupOrder do
		local inGroup = members[group] or {}
		table.sort(inGroup, function(a, b)
			if a.order ~= b.order then
				return a.order < b.order
			end
			return a.id < b.id
		end)
		local label = groupLabels[group]
		if not label then
			label = UI.text({ Size = UDim2.fromOffset(LIST_WIDTH - INSET, 26), TextXAlignment = left, TextColor3 = Colors.gold, Parent = list })
			groupLabels[group] = label
		end
		label.Visible = #inGroup > 0
		if #inGroup > 0 then
			label.Position = UDim2.fromOffset(INSET, y)
			label.Text = `{string.upper(group)}  •  {#inGroup}`
			y += 32
			for index, source in inGroup do
				local column, line = (index - 1) % TILE_COLUMNS, (index - 1) // TILE_COLUMNS
				tileFor(source.id).button.Position = UDim2.fromOffset(INSET + column * (TILE_SIZE.X + GAP), y + line * (TILE_SIZE.Y + GAP))
			end
			y += math.ceil(#inGroup / TILE_COLUMNS) * (TILE_SIZE.Y + GAP) + 6
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, y + INSET)
end

-- What a tile says under its name: the source's own info when it has one (the eggs do), otherwise the
-- subtitle of its table, looked up once per visit to the catalogue.
local function tileInfo(source, tile)
	if typeof(source.info) == "function" then
		local ok, info = pcall(source.info)
		if ok and typeof(info) == "table" then
			return info
		end
	end
	if tile.visit ~= catalogueVisit then
		tile.visit = catalogueVisit
		tile.fallbackStatus = ""
		local ok, spec = pcall(source.build)
		if ok and typeof(spec) == "table" and typeof(spec.subtitle) == "string" then
			tile.fallbackStatus = spec.subtitle
		end
	end
	return { status = tile.fallbackStatus }
end

local function renderCatalogue()
	if catalogueDirty then
		catalogueDirty = false
		layoutCatalogue()
	end
	for id, source in sources do
		local tile = tileFor(id)
		local info = tileInfo(source, tile)
		local locked = info.locked == true
		tile.button.BackgroundColor3 = if locked then Colors.dark else Colors.row
		tile.border.Color = if locked then Color3.new(0, 0, 0) else source.color:Lerp(Color3.new(0, 0, 0), 0.35)
		tile.setIcon(source.shape, if locked then source.color:Lerp(Colors.dark, 0.7) else source.color)
		tile.lock.Visible = locked
		tile.name.Text = source.name
		tile.name.TextColor3 = if locked then Colors.text else Colors.white
		tile.status.Text = if typeof(info.status) == "string" then info.status else ""
		tile.status.TextColor3 = if typeof(info.statusColor) == "Color3" then info.statusColor else Colors.white
		tile.sub.Text = if typeof(info.sub) == "string" then info.sub else ""
		tile.sub.TextColor3 = if typeof(info.subColor) == "Color3" then info.subColor else Colors.text
	end
end

-- Shows a table: `spec` is what a build returned (or what Loot.show was given), `source` what it came from.
local function renderTable(spec, source)
	local failed = typeof(spec) ~= "table"
	if failed then
		spec = {}
	end
	local rows = {}
	if typeof(spec.rows) == "table" then
		for _, row in spec.rows do
			local data = describe(row)
			if data then
				data.index = #rows + 1
				table.insert(rows, data)
			end
		end
	end
	-- Most common first, rarest last, unless the table says its own order is the one to show.
	if spec.keepOrder ~= true then
		table.sort(rows, function(a, b)
			if a.chance ~= b.chance then
				return a.chance > b.chance
			end
			return a.index < b.index
		end)
	end

	local title = tostring(spec.title or (source and source.name) or "Loot")
	local subtitle = if failed then "" elseif spec.subtitle ~= nil then tostring(spec.subtitle) else ""
	local note = if typeof(spec.note) == "string" then spec.note else ""
	local color = if typeof(spec.color) == "Color3" then spec.color elseif source then source.color else NEUTRAL
	local subtitleColor = if typeof(spec.subtitleColor) == "Color3" then spec.subtitleColor else Colors.white
	local luck = if typeof(spec.luck) == "number" then spec.luck else nil
	local shape = if typeof(spec.shape) == "string" then spec.shape elseif source then source.shape else nil

	local parts = { title, subtitle, note, color:ToHex(), subtitleColor:ToHex(), tostring(luck), tostring(shape), tostring(failed) }
	for _, data in rows do
		table.insert(parts, data.signature)
	end
	local signature = table.concat(parts, "\n")
	if signature == shownSignature and shownSerial == viewSerial then
		return
	end
	shownSignature = signature

	titleLabel.Text = string.upper(title)
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = subtitleColor
	noteLabel.Text = note
	setHeaderEmblem(shape, color)
	luckChip.Visible = luck ~= nil
	if luck then
		luckLabel.Text = `🍀 x{Loot.luckText(luck)} LUCK`
		luckChip.BackgroundColor3 = if luck > 1 then LUCK_GREEN else Colors.grey
	end

	local previews = 0
	for index, data in rows do
		local allowModel = data.pet ~= nil and previews < MAX_PREVIEWS
		if allowModel then
			previews += 1
		end
		local card = cardAt(index)
		card.frame.Visible = true
		fillCard(card, data, allowModel)
	end
	for index = #rows + 1, #cards do
		cards[index].frame.Visible = false
		hideModel(cards[index])
	end
	grid.CanvasSize = UDim2.fromOffset(0, INSET * 2 + math.ceil(#rows / CARD_COLUMNS) * (CARD_SIZE.Y + GAP) - GAP)
	emptyLabel.Visible = #rows == 0
	emptyLabel.Text = if failed then "This loot table could not be loaded." else "Nothing to show here yet."
	-- A different table starts at its top; the same one, refreshed, stays where the player scrolled to.
	if shownSerial ~= viewSerial then
		shownSerial = viewSerial
		grid.CanvasPosition = Vector2.zero
	end
end

local lastRender = 0
local renderQueued = false

local function render()
	lastRender = os.clock()
	if not window.frame.Visible then
		return
	end
	local source = if view.kind == "source" then sources[view.id] else nil
	if view.kind == "catalogue" or (view.kind == "source" and not source) then
		tablePage.Visible = false
		cataloguePage.Visible = true
		renderCatalogue()
		return
	end
	cataloguePage.Visible = false
	tablePage.Visible = true
	local spec = view.spec
	if source then
		-- A build that errors or returns nonsense must not take the viewer down with it.
		local ok, result = pcall(source.build)
		spec = if ok then result else nil
		if (not ok or typeof(result) ~= "table") and not warned[source.id] then
			warned[source.id] = true
			warn(`[Loot] the table of {source.id} could not be built: {result}`)
		end
	end
	renderTable(spec, source)
end

-- Follows the player's state (luck, what they own, what they can afford) while the viewer is open.
function Loot.refresh()
	if not window.frame.Visible then
		return
	end
	local due = RENDER_GAP - (os.clock() - lastRender)
	if due <= 0 then
		render()
	elseif not renderQueued then
		renderQueued = true
		task.delay(due, function()
			renderQueued = false
			render()
		end)
	end
end

local function present()
	viewSerial += 1
	if not window.frame.Visible then
		window.open()
	end
	render()
end

----------------------------------------------------------------------------------------------------
-- The API (ctx.Loot)
----------------------------------------------------------------------------------------------------
-- Adds something that can be opened to the catalogue, or replaces the one with the same id.
-- Can be called at any time, also after the viewer was first opened.
function Loot.register(source)
	if typeof(source) ~= "table" or typeof(source.id) ~= "string" then
		warn("[Loot] register needs a table with an id")
		return
	end
	local group = if typeof(source.group) == "string" and source.group ~= "" then source.group else "Other"
	sources[source.id] = {
		id = source.id,
		group = group,
		name = tostring(source.name or source.id),
		color = if typeof(source.color) == "Color3" then source.color else NEUTRAL,
		order = if typeof(source.order) == "number" then source.order else 1000,
		build = source.build,
		info = source.info,
		shape = if typeof(source.shape) == "string" then source.shape else nil,
	}
	if not table.find(groupOrder, group) then
		table.insert(groupOrder, group)
	end
	warned[source.id] = nil
	catalogueDirty = true
	Loot.refresh()
end

-- Opens the viewer on a registered source. With no id (or one nobody registered), on the catalogue.
function Loot.open(id: string?)
	if typeof(id) == "string" and sources[id] then
		view = { kind = "source", id = id }
	else
		view = { kind = "catalogue" }
		catalogueVisit += 1
	end
	present()
end

-- Shows a one-off table: the same shape a source's build returns.
function Loot.show(spec)
	view = { kind = "spec", spec = spec }
	present()
end

backButton.Activated:Connect(function()
	Loot.open()
end)

Windows.register(NAME, window, Loot.refresh)
Hud.addMenuButton(NAME, Color3.fromRGB(150, 95, 210), 15, function()
	if window.frame.Visible then
		window.close()
	else
		Loot.open()
	end
end)

----------------------------------------------------------------------------------------------------
-- The eggs
----------------------------------------------------------------------------------------------------
local function eventLive(): boolean
	local event = State.meta.event
	if typeof(event) == "table" then
		return event.active == true
	end
	return Config.halloweenActive(State.now())
end

for index, egg in Config.Eggs do
	local price = `{Format.abbreviate(egg.cost)} {ICONS[egg.currency] or ""}`

	-- Where the player stands with this egg: what to say about it, in which colour, and whether it is locked.
	local function standing(): (string, Color3, boolean)
		if egg.event and not eventLive() then
			return "Event is over", Colors.text, true
		elseif State.get("BestCleared", 0) < egg.unlock then
			return `🔒 Clear {Config.waveLabel(egg.unlock)}`, Colors.red, true
		end
		local affordable = State.get(BALANCE_ATTRIBUTE[egg.currency] or "Coins", 0) >= egg.cost
		return price, if affordable then Colors.green else Colors.white, false
	end

	Loot.register({
		id = "egg:" .. egg.id,
		group = "Eggs",
		name = egg.name,
		color = egg.color,
		order = index,
		shape = "egg",
		info = function()
			local status, color, locked = standing()
			local found, total = Loot.collected(egg)
			return {
				status = status,
				statusColor = color,
				locked = locked,
				sub = if egg.event then `EVENT  •  {found}/{total} found` else `{found}/{total} found`,
				subColor = if egg.event then Colors.orange else Colors.text,
			}
		end,
		build = function()
			local luck = Loot.luck()
			local status, color, locked = standing()
			local found, total = Loot.collected(egg)
			local rows = {}
			for _, entry in Config.eggOdds(egg, luck) do
				table.insert(rows, { chance = entry.chance, pet = entry.id })
			end
			return {
				title = egg.name,
				subtitle = if locked then `{status}  •  {price} each` else `{price} each  •  {found}/{total} found`,
				subtitleColor = color,
				color = egg.color,
				shape = "egg",
				luck = luck,
				note = if luck > 1
					then "Your luck is already in these chances. A Huge's chance never changes."
					else "Luck makes Rare and better hatch more often. A Huge's chance never changes.",
				keepOrder = true, -- an egg lists its own from Common up to its Huge, whatever luck does to the chances
				rows = rows,
			}
		end,
	})
end

return Loot
