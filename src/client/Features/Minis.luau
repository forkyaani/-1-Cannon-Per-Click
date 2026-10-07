-- The MINI CANNONS window (docs/MINI_CANNON_REVAMP.md): the player's mini cannons as a grid of picture cards
-- with a detail pane. Equip and unequip by hand, delete one or many, lock, search, sort, filter, three
-- loadouts and a storage bar. The rules are the shared module's, which is what the server checks with.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Minis = require(Shared:WaitForChild("Features"):WaitForChild("Minis"))
local Models = require(Shared:WaitForChild("Models"))

local CARD = Vector2.new(106, 112)
local GAP = 6
local COLUMNS = 5
local GRID_WIDTH = COLUMNS * CARD.X + (COLUMNS - 1) * GAP + 12
local GRID_TOP = 74
local BAR_HEIGHT = 40
local PANE_X = GRID_WIDTH + 6
local MAX_PREVIEWS = 30 -- cards with a 3D picture; the ones after that show a ball of the mini cannon's colour
local CONFIRM_SECONDS = 5 -- how long the first of two presses on a delete that needs two stays armed
local STORAGE_PASS = "storage500"
local MAGIC = Color3.fromRGB(226, 170, 255)
local FILTERS = { "all", "equipped", "enchanted", "fused" }
for _, rarity in Minis.RARITIES do
	table.insert(FILTERS, rarity)
end

local function start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local left = Enum.TextXAlignment.Left

	-- Which egg a kind of mini cannon hatches from, for the search box and the detail pane.
	local eggOf: { [string]: string } = {}
	for _, egg in Config.Eggs do
		for _, entry in egg.pets do
			eggOf[entry.id] = eggOf[entry.id] or egg.name
		end
	end
	local function baseOf(pet): string
		local plain = Config.Pets[pet.plain]
		return (plain and plain.base) or pet.plain
	end

	local window = UI.window(Minis.WINDOW, 800, 540)
	local body = window.body
	local refresh

	local selected: string? = nil
	local sort, filter, query = 1, 1, ""
	local deleting = false
	local marked: { [string]: boolean } = {} -- delete mode: the kinds ticked
	local saving = false -- SAVE was pressed: the next loadout number stores instead of equipping
	local armed, armedFor = -math.huge, "" -- a delete that takes two presses, and what it was for

	------------------------------------------------------------------------------------------------
	-- Top line: what is equipped, and the storage bar.
	------------------------------------------------------------------------------------------------
	local headline = UI.text({ Size = UDim2.fromOffset(330, 26), TextXAlignment = left, MaxSize = 18, Parent = body })
	local storage = UI.bar({
		parent = body,
		position = UDim2.fromOffset(338, 1),
		size = UDim2.fromOffset(250, 24),
		color = Colors.green,
		textSize = 15,
	})
	local passButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -2),
		Size = UDim2.fromOffset(178, 30),
		Text = "",
		BackgroundColor3 = Colors.premium,
		Parent = body,
	})
	passButton.Activated:Connect(function()
		ctx.act("buyPass", STORAGE_PASS)
	end)

	------------------------------------------------------------------------------------------------
	-- Toolbar: search, sort, filter.
	------------------------------------------------------------------------------------------------
	local boxOutline = UI.stroke(3)
	boxOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local searchBox: TextBox = UI.make("TextBox", {
		Name = "Search",
		Position = UDim2.fromOffset(2, 34),
		Size = UDim2.fromOffset(246, 32),
		BackgroundColor3 = Colors.cream,
		BorderSizePixel = 0,
		Font = UI.FONT,
		Text = "",
		PlaceholderText = "Search name, rarity or egg",
		PlaceholderColor3 = Colors.grey,
		TextColor3 = Colors.ink,
		TextSize = 18,
		ClearTextOnFocus = false,
		Parent = body,
	}, { UI.corner(10), boxOutline })
	local sortButton = UI.button({ Position = UDim2.fromOffset(256, 32), Size = UDim2.fromOffset(150, 36), Text = "", BackgroundColor3 = Colors.blue, Parent = body })
	local filterButton = UI.button({ Position = UDim2.fromOffset(412, 32), Size = UDim2.fromOffset(154, 36), Text = "", BackgroundColor3 = Colors.blue, Parent = body })
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		query = string.lower(searchBox.Text)
		refresh()
	end)
	sortButton.Activated:Connect(function()
		sort = sort % #Minis.SORTS + 1
		refresh()
	end)
	filterButton.Activated:Connect(function()
		filter = filter % #FILTERS + 1
		refresh()
	end)

	------------------------------------------------------------------------------------------------
	-- The grid. Cards are made as they are needed and reused; each is placed by hand.
	------------------------------------------------------------------------------------------------
	local grid: ScrollingFrame = UI.make("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, GRID_TOP),
		Size = UDim2.new(0, GRID_WIDTH, 1, -GRID_TOP - BAR_HEIGHT - 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Colors.ink,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	})
	local empty = UI.text({
		Position = UDim2.fromOffset(0, GRID_TOP + 40),
		Size = UDim2.fromOffset(GRID_WIDTH, 50),
		TextColor3 = Colors.text,
		MaxSize = 18,
		Text = "",
		Visible = false,
		Parent = body,
	})

	local cards = {}
	local function cardAt(index: number)
		local card = cards[index]
		if card then
			return card
		end
		local column, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
		local button = UI.make("TextButton", {
			Name = "Card",
			Position = UDim2.fromOffset(4 + column * (CARD.X + GAP), 4 + row * (CARD.Y + GAP)),
			Size = UDim2.fromOffset(CARD.X, CARD.Y),
			BackgroundColor3 = Colors.row,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = grid,
		})
		local outline = UI.stroke(3)
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Parent = button
		UI.corner(14).Parent = button
		UI.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Colors.white, Color3.fromRGB(196, 190, 214)), Parent = button })
		-- What stands in for the 3D picture past MAX_PREVIEWS, or for a mini cannon without a model.
		local ball = UI.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(52, 52),
			BorderSizePixel = 0,
			Parent = button,
		}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(3) })
		card = {
			button = button,
			outline = outline,
			ball = ball,
			view = if index <= MAX_PREVIEWS then UI.preview({ Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 76), Parent = button }) else nil,
			name = UI.text({ Position = UDim2.new(0, 4, 1, -34), Size = UDim2.new(1, -8, 0, 16), MaxSize = 13, ZIndex = 2, Parent = button }),
			power = UI.text({ Position = UDim2.new(0, 4, 1, -19), Size = UDim2.new(1, -8, 0, 16), MaxSize = 13, ZIndex = 2, Parent = button }),
			count = UI.text({ Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(44, 18), TextXAlignment = left, MaxSize = 15, ZIndex = 3, Parent = button }),
			worn = UI.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 3), Size = UDim2.fromOffset(52, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Colors.green, MaxSize = 14, ZIndex = 3, Parent = button }),
			marks = UI.text({ Position = UDim2.fromOffset(6, 56), Size = UDim2.fromOffset(60, 18), TextXAlignment = left, MaxSize = 14, ZIndex = 3, Parent = button }),
			shown = "",
			id = nil :: string?,
		}
		button.Activated:Connect(function()
			local id = card.id
			if not id then
				return
			end
			if deleting then
				if (State.feature("minis").locked or {})[id] then
					return
				end
				marked[id] = if marked[id] then nil else true
			else
				selected = id
			end
			refresh()
		end)
		cards[index] = card
		return card
	end

	------------------------------------------------------------------------------------------------
	-- The detail pane: the selected mini cannon and what can be done with it.
	------------------------------------------------------------------------------------------------
	local pane = UI.make("Frame", {
		Name = "Detail",
		Position = UDim2.fromOffset(PANE_X, 32),
		Size = UDim2.new(1, -PANE_X, 1, -32 - BAR_HEIGHT - 8),
		BackgroundColor3 = Colors.dark,
		BorderSizePixel = 0,
		Parent = body,
	}, { UI.corner(14) })
	local paneView = UI.preview({ Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 120), Parent = pane })
	local paneName = UI.text({ Position = UDim2.fromOffset(6, 122), Size = UDim2.new(1, -12, 0, 22), MaxSize = 17, Parent = pane })
	local paneRarity = UI.text({ Position = UDim2.fromOffset(6, 145), Size = UDim2.new(1, -12, 0, 18), MaxSize = 14, Parent = pane })
	local paneFacts = UI.text({
		Position = UDim2.fromOffset(8, 166),
		Size = UDim2.new(1, -16, 0, 96),
		TextXAlignment = left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Colors.text,
		TextWrapped = true,
		MaxSize = 13,
		Parent = pane,
	})
	local function paneButton(y: number, color: Color3): TextButton
		return UI.button({ Position = UDim2.new(0, 8, 1, y), Size = UDim2.new(1, -16, 0, 34), Text = "", BackgroundColor3 = color, Parent = pane })
	end
	local equipButton = paneButton(-116, Colors.green)
	local lockButton = paneButton(-78, Colors.blue)
	local deleteButton = paneButton(-40, Colors.red)
	local paneShown = ""

	equipButton.Activated:Connect(function()
		if selected then
			local worn = Minis.counts(State.meta.equipped or {})[selected] or 0
			local have = (State.meta.pets or {})[selected] or 0
			-- One more while there is one to equip; once every copy is equipped the button takes one off.
			ctx.act(if worn >= have then "minisUnequip" else "minisEquip", selected)
		end
	end)
	lockButton.Activated:Connect(function()
		if selected then
			ctx.act("minisLock", selected)
		end
	end)
	deleteButton.Activated:Connect(function()
		local id = selected
		if not id or (State.feature("minis").locked or {})[id] then
			return
		end
		if Minis.precious(id) and not (armedFor == id and os.clock() - armed <= CONFIRM_SECONDS) then
			armed, armedFor = os.clock(), id
			refresh()
			return
		end
		armed, armedFor = -math.huge, ""
		ctx.act("minisDelete", { [id] = 1 })
	end)

	------------------------------------------------------------------------------------------------
	-- Bottom bar: equip best, unequip all, delete many, loadouts.
	------------------------------------------------------------------------------------------------
	local function barButton(x: number, width: number, text: string, color: Color3): TextButton
		return UI.button({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, x, 1, 0),
			Size = UDim2.fromOffset(width, BAR_HEIGHT),
			Text = text,
			BackgroundColor3 = color,
			Parent = body,
		})
	end
	local bestButton = barButton(0, 136, "EQUIP BEST", Colors.green)
	local noneButton = barButton(142, 136, "UNEQUIP ALL", Colors.orange)
	local manyButton = barButton(284, 150, "DELETE MANY", Colors.red)
	local cancelButton = barButton(440, 110, "CANCEL", Colors.grey)
	local loadoutButtons = {}
	for slot = 1, Minis.LOADOUTS do
		local button = barButton(440 + (slot - 1) * 56, 50, tostring(slot), Colors.blue)
		button.Activated:Connect(function()
			ctx.act("minisLoadout", { slot = slot, save = saving })
			saving = false
			refresh()
		end)
		loadoutButtons[slot] = button
	end
	local saveButton = barButton(440 + Minis.LOADOUTS * 56, 100, "SAVE", Colors.gold)
	UI.text({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -2),
		Size = UDim2.new(1, -(440 + Minis.LOADOUTS * 56 + 108), 0, BAR_HEIGHT - 4),
		TextColor3 = Colors.text,
		MaxSize = 13,
		TextWrapped = true,
		Text = "LOADOUTS: a number equips it. SAVE, then a number, stores what is equipped now.",
		Parent = body,
	})
	bestButton.Activated:Connect(function()
		ctx.act("minisBest")
	end)
	noneButton.Activated:Connect(function()
		ctx.act("minisUnequipAll")
	end)
	saveButton.Activated:Connect(function()
		saving = not saving
		refresh()
	end)
	cancelButton.Activated:Connect(function()
		deleting = false
		table.clear(marked)
		refresh()
	end)
	manyButton.Activated:Connect(function()
		if not deleting then
			deleting = true
			table.clear(marked)
			refresh()
			return
		end
		local counts = State.meta.pets or {}
		local wanted, precious, total = {}, false, 0
		for id in marked do
			if (counts[id] or 0) > 0 then
				wanted[id] = counts[id]
				total += counts[id]
				precious = precious or Minis.precious(id)
			end
		end
		if total == 0 then
			return
		end
		if precious and not (armedFor == "many" and os.clock() - armed <= CONFIRM_SECONDS) then
			armed, armedFor = os.clock(), "many"
			refresh()
			return
		end
		armed, armedFor = -math.huge, ""
		deleting = false
		table.clear(marked)
		ctx.act("minisDelete", wanted)
	end)

	------------------------------------------------------------------------------------------------
	-- Drawing
	------------------------------------------------------------------------------------------------
	local function matches(id: string, pet, worn: number): boolean
		local kind = FILTERS[filter]
		if kind == "equipped" and worn == 0 then
			return false
		elseif kind == "enchanted" and not pet.enchanted then
			return false
		elseif kind == "fused" and not pet.tier then
			return false
		elseif kind ~= "all" and kind ~= "equipped" and kind ~= "enchanted" and kind ~= "fused" and pet.rarity ~= kind then
			return false
		end
		if query == "" then
			return true
		end
		local text = string.lower(`{pet.name} {pet.rarity} {eggOf[baseOf(pet)] or ""}`)
		return string.find(text, query, 1, true) ~= nil
	end

	local function marksOf(pet, locked: boolean): string
		local text = ""
		if locked then
			text ..= "🔒"
		end
		if pet.enchanted then
			text ..= "✨"
		end
		return text
	end

	local function drawPane(counts, wornCounts, locked)
		local id = selected
		local pet = id and Config.Pets[id]
		local have = if id then counts[id] or 0 else 0
		if not id or not pet or have == 0 then
			selected = nil
			paneView.show(nil)
			paneShown = ""
			paneName.Text = "Pick a mini cannon"
			paneRarity.Text = ""
			paneFacts.Text = "Tap a card to see it here, equip it, lock it or delete it."
			equipButton.Visible, lockButton.Visible, deleteButton.Visible = false, false, false
			return
		end
		if paneShown ~= id then
			paneShown = id
			local model = Models.mini(pet, 1)
			if model then
				model:PivotTo(CFrame.Angles(0, math.rad(90), 0)) -- its face and barrel towards the camera
			end
			paneView.show(model)
		end
		local worn = wornCounts[id] or 0
		local tier = Config.FuseTiers[pet.tier]
		paneName.Text = pet.name
		paneName.TextColor3 = Config.RarityColors[pet.rarity] or Colors.white
		paneRarity.Text = if tier then `{pet.rarity}  •  {tier.name}` else pet.rarity
		paneRarity.TextColor3 = if tier then tier.color else Colors.text
		local lines = { if pet.huge then `{Format.petPower(pet)} ALL tower damage` else Format.petPower(pet) }
		table.insert(lines, `Owned x{have}  •  equipped x{worn}`)
		local magic = Config.enchantText(id, "  •  ")
		if magic ~= "" then
			table.insert(lines, "✨ " .. magic)
		end
		if tier then
			table.insert(lines, `{tier.perk}: {Config.perkText(tier)}`)
		elseif pet.feature then
			table.insert(lines, pet.feature)
		end
		local egg = eggOf[baseOf(pet)]
		if egg then
			table.insert(lines, "From the " .. egg)
		end
		paneFacts.Text = table.concat(lines, "\n")
		equipButton.Visible, lockButton.Visible, deleteButton.Visible = true, true, true
		if worn >= have then
			equipButton.Text, equipButton.BackgroundColor3 = "UNEQUIP", Colors.orange
		else
			local full = #(State.meta.equipped or {}) >= (State.meta.slots or 0)
			equipButton.Text = if worn > 0 then "EQUIP ANOTHER" else "EQUIP"
			equipButton.BackgroundColor3 = if full then Colors.grey else Colors.green
		end
		lockButton.Text = if locked[id] then "UNLOCK" else "LOCK"
		if locked[id] then
			deleteButton.Text, deleteButton.BackgroundColor3 = "LOCKED", Colors.grey
		elseif armedFor == id and os.clock() - armed <= CONFIRM_SECONDS then
			deleteButton.Text, deleteButton.BackgroundColor3 = "SURE? PRESS AGAIN", Colors.red
		else
			deleteButton.Text, deleteButton.BackgroundColor3 = "DELETE 1", Colors.red
		end
	end

	function refresh()
		local meta = State.meta
		local counts = meta.pets or {}
		local equipped = meta.equipped or {}
		local wornCounts = Minis.counts(equipped)
		local setup = State.feature("minis")
		local locked = setup.locked or {}

		-- Top line and storage.
		local slots = meta.slots or Config.MaxEquipped
		headline.Text = `Equipped {#equipped}/{slots}  •  {Format.dps(State.get("PetDps", 0))}{if setup.manual then "" else "  •  auto"}`
		local stored, room = meta.petCount or 0, math.max(1, meta.storage or Config.MaxPets)
		storage.set(stored / room, `{stored} / {room} stored`)
		storage.setColor(if stored >= room then Colors.red elseif stored / room >= Minis.STORAGE_WARN then Colors.orange else Colors.green)
		local pass = Config.Passes[STORAGE_PASS]
		passButton.Visible = pass ~= nil and not (meta.passes or {})[STORAGE_PASS]
		if pass then
			passButton.Text = `+{pass.storage} STORAGE  {pass.price} R$`
		end
		sortButton.Text = "SORT: " .. string.upper(Minis.SORTS[sort])
		filterButton.Text = "SHOW: " .. string.upper(FILTERS[filter])

		-- The kinds to show, sorted. Equipped ones come first whatever the sort.
		local ids = {}
		for id, count in counts do
			local pet = Config.Pets[id]
			if pet and count > 0 and matches(id, pet, wornCounts[id] or 0) then
				table.insert(ids, id)
			end
		end
		local key = Minis.SORTS[sort]
		table.sort(ids, function(a, b)
			local wornA, wornB = (wornCounts[a] or 0) > 0, (wornCounts[b] or 0) > 0
			if wornA ~= wornB then
				return wornA
			end
			local petA, petB = Config.Pets[a], Config.Pets[b]
			if key == "damage" and petA.strength ~= petB.strength then
				return petA.strength > petB.strength
			elseif key == "rarity" and Minis.rarityRank(petA) ~= Minis.rarityRank(petB) then
				return Minis.rarityRank(petA) > Minis.rarityRank(petB)
			elseif key == "name" and petA.name ~= petB.name then
				return petA.name < petB.name
			elseif key == "count" and counts[a] ~= counts[b] then
				return counts[a] > counts[b]
			end
			return if petA.strength == petB.strength then a < b else petA.strength > petB.strength
		end)

		for index, id in ids do
			local pet = Config.Pets[id]
			local card = cardAt(index)
			local tier = Config.FuseTiers[pet.tier]
			local worn = wornCounts[id] or 0
			card.id = id
			card.button.Visible = true
			if card.shown ~= id then
				card.shown = id
				local model = if card.view then Models.mini(pet, 1) else nil
				if model then
					model:PivotTo(CFrame.Angles(0, math.rad(90), 0))
				end
				if card.view then
					card.view.show(model)
				end
				card.ball.Visible = model == nil
				card.ball.BackgroundColor3 = pet.color
				card.name.Text = pet.short or pet.name
				card.name.TextColor3 = Config.RarityColors[pet.rarity] or Colors.white
				card.power.Text = Format.petPower(pet)
			end
			card.count.Text = "x" .. counts[id]
			card.worn.Text = if worn > 0 then (if worn > 1 then `✔ x{worn}` else "✔") else ""
			card.marks.Text = marksOf(pet, locked[id] == true)
			card.marks.TextColor3 = MAGIC
			-- The frame says what the card is: ticked for deleting, selected, fused, or plain.
			if deleting and marked[id] then
				card.outline.Color, card.outline.Thickness = Colors.red, 5
				card.button.BackgroundColor3 = Colors.row:Lerp(Colors.red, 0.45)
			elseif not deleting and selected == id then
				card.outline.Color, card.outline.Thickness = Colors.gold, 5
				card.button.BackgroundColor3 = Colors.row:Lerp(Colors.white, 0.18)
			else
				card.outline.Color = if tier then tier.color else Colors.ink
				card.outline.Thickness = 3
				card.button.BackgroundColor3 = if worn > 0 then Colors.row:Lerp(Colors.green, 0.3) else Colors.row
			end
		end
		for index = #ids + 1, #cards do
			cards[index].button.Visible = false
			cards[index].id = nil
		end
		local rows = math.ceil(#ids / COLUMNS)
		grid.CanvasSize = UDim2.fromOffset(0, rows * (CARD.Y + GAP) + 8)
		empty.Visible = #ids == 0
		empty.Text = if next(counts) == nil then "No mini cannons yet: hatch an egg on a world's island" else "Nothing matches. Clear the search or press SHOW."

		drawPane(counts, wornCounts, locked)

		-- The bottom bar.
		local picked, total = 0, 0
		for id in marked do
			if (counts[id] or 0) > 0 and not locked[id] then
				picked += 1
				total += counts[id]
			else
				marked[id] = nil
			end
		end
		cancelButton.Visible = deleting
		saveButton.Visible = not deleting
		for _, button in loadoutButtons do
			button.Visible = not deleting
			button.BackgroundColor3 = if saving then Colors.gold else Colors.blue
		end
		for slot, button in loadoutButtons do
			local loadout = (setup.loadouts or {})[tostring(slot)]
			button.Text = if typeof(loadout) == "table" and #loadout > 0 then tostring(slot) else `{slot}·`
		end
		saveButton.Text = if saving then "PICK 1-3" else "SAVE"
		if not deleting then
			manyButton.Text, manyButton.BackgroundColor3 = "DELETE MANY", Colors.red
		elseif armedFor == "many" and os.clock() - armed <= CONFIRM_SECONDS then
			manyButton.Text, manyButton.BackgroundColor3 = "SURE? AGAIN", Colors.red
		else
			manyButton.Text = if total > 0 then `DELETE {total}` else "TAP CARDS"
			manyButton.BackgroundColor3 = if total > 0 then Colors.red else Colors.grey
		end
	end

	ctx.Windows.register(Minis.WINDOW, window, refresh)
end

return { start = start }
