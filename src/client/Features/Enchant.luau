-- Enchanting, client side: the ENCHANT window, opened by the table on The Sun's island (its prompt carries
-- Window = "ENCHANT"). The first tab lists the player's mini cannons; picking one shows what it carries, what
-- a roll costs and a button per key. The second tab is the small print: the odds of each key, the gem prices
-- and all twenty enchantments with their three levels.
-- Everything shown comes from the shared module, which is what the server rolls from; the server checks
-- every request again. Enchanting a mini cannon that is enchanted already replaces what it had: the window
-- says so and takes a second press before it asks the server (which refuses a request without it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enchant = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Enchant"))

local ROW_HEIGHT = 62
local TAB_TOP = 26
local TAB_HEIGHT = 34
local PAGE_TOP = TAB_TOP + TAB_HEIGHT + 6
local PANEL_HEIGHT = 190
local CONFIRM_SECONDS = 5 -- how long the first of the two presses that replace enchantments stays armed
local MAGIC = Color3.fromRGB(226, 170, 255)

local function start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local left = Enum.TextXAlignment.Left
	local world = Config.Worlds[Enchant.ISLAND]

	local window = UI.window(Enchant.WINDOW, 700, 540)
	local headline = UI.text({
		Size = UDim2.new(1, -8, 0, 22),
		TextXAlignment = left,
		TextColor3 = Colors.gold,
		MaxSize = 18,
		Parent = window.body,
	})

	-- Two tabs, side by side.
	local TABS = { { id = "pick", name = "ENCHANT" }, { id = "odds", name = "ODDS AND LIST" } }
	local selectedTab = "pick"
	local tabs, pages = {}, {}
	local refresh
	for index, tab in TABS do
		local share = 1 / #TABS
		local button = UI.button({
			Position = UDim2.new((index - 1) * share, 2, 0, TAB_TOP),
			Size = UDim2.new(share, -6, 0, TAB_HEIGHT),
			Text = tab.name,
			BackgroundColor3 = Colors.grey,
			Parent = window.body,
		})
		button.Activated:Connect(function()
			selectedTab = tab.id
			refresh()
		end)
		tabs[tab.id] = button
		pages[tab.id] = UI.make("Frame", {
			Name = tab.id,
			Position = UDim2.fromOffset(0, PAGE_TOP),
			Size = UDim2.new(1, 0, 1, -PAGE_TOP),
			BackgroundTransparency = 1,
			Parent = window.body,
		})
	end

	------------------------------------------------------------------------------------------------
	-- The first tab: the mini cannons, and the one that is picked.
	------------------------------------------------------------------------------------------------
	local list = UI.scroll(pages.pick, { Size = UDim2.new(1, 0, 1, -PANEL_HEIGHT - 6) })
	local emptyLabel = UI.text({
		Size = UDim2.new(1, -10, 0, 40),
		LayoutOrder = 0,
		TextColor3 = Colors.text,
		MaxSize = 16,
		Text = "No mini cannons yet. Hatch an egg on a world's island!",
		Visible = false,
		Parent = list,
	})
	local panel = UI.make("Frame", {
		Name = "Picked",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, PANEL_HEIGHT),
		BackgroundColor3 = Colors.dark,
		BorderSizePixel = 0,
		Parent = pages.pick,
	}, { UI.corner(14), UI.stroke(3) })
	local pickedName = UI.text({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0.55, -18, 0, 24),
		TextXAlignment = left,
		Parent = panel,
	})
	local pickedNow = UI.text({
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(0.55, -18, 0, 56),
		TextXAlignment = left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = MAGIC,
		MaxSize = 15,
		Parent = panel,
	})
	local warning = UI.text({
		Position = UDim2.fromOffset(12, 90),
		Size = UDim2.new(0.55, -18, 0, 34),
		TextXAlignment = left,
		TextWrapped = true,
		TextColor3 = Colors.red,
		MaxSize = 15,
		Parent = panel,
	})
	local resultLabel = UI.text({
		Position = UDim2.fromOffset(12, 126),
		Size = UDim2.new(0.55, -18, 0, 22),
		TextXAlignment = left,
		TextColor3 = Colors.gold,
		MaxSize = 16,
		Text = "",
		Parent = panel,
	})
	-- The odds of both keys, where the roll is bought (Roblox asks for them there). The second tab has more.
	local oddsLines = {}
	for _, key in Enchant.Keys do
		table.insert(oddsLines, Enchant.oddsShort(key.id))
	end
	table.insert(oddsLines, `Every one of the {#Enchant.List} enchantments is equally likely`)
	UI.text({
		Position = UDim2.fromOffset(12, 150),
		Size = UDim2.new(1, -24, 0, 36),
		TextXAlignment = left,
		TextWrapped = true,
		TextColor3 = Colors.text,
		MaxSize = 12,
		Text = "ODDS  •  " .. table.concat(oddsLines, "\n"),
		Parent = panel,
	})
	local costLabel = UI.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.new(0.45, -6, 0, 22),
		TextColor3 = Colors.text,
		MaxSize = 16,
		Parent = panel,
	})
	local keyButtons = {}
	for index, key in Enchant.Keys do
		keyButtons[key.id] = UI.button({
			AnchorPoint = Vector2.new(1, 0),
			-- Side by side: the ordinary key on the left.
			Position = UDim2.new(1, -12 - (#Enchant.Keys - index) * 152, 0, 32),
			Size = UDim2.fromOffset(146, 56),
			Parent = panel,
		})
	end
	local product = Enchant.ShinyProduct
	local shinyName = Enchant.KeyById[product.key].name
	local buyButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 94),
		Size = UDim2.fromOffset(298, 34),
		Text = if product.product == 0 then `{string.upper(shinyName)}: NOT ON SALE YET` else `GET A {string.upper(shinyName)}  •  {product.price} R$`,
		BackgroundColor3 = if product.product == 0 then Colors.grey else Colors.premium,
		Parent = panel,
	})
	buyButton.Activated:Connect(function()
		ctx.act("enchantBuyKey")
	end)

	local picked: string? = nil -- the id of the mini cannon in the panel
	local armed = { pet = "", key = "", at = -math.huge } -- the first of the two presses that replace enchantments
	local lastResult = { pet = "", text = "" } -- what the last roll gave, shown while that mini cannon stays picked

	local function atTable(): boolean
		return State.get("Place", "plot") == "island" and State.get("Island", 0) == Enchant.ISLAND
	end

	local function setButton(button: TextButton, text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	for _, key in Enchant.Keys do
		keyButtons[key.id].Activated:Connect(function()
			local id = picked
			local pet = id and Config.Pets[id]
			if not id or not pet then
				return
			end
			local replace = pet.enchanted == true
			-- An enchanted one: the first press only arms the button and says what would be lost.
			if replace and not (armed.pet == id and armed.key == key.id and os.clock() - armed.at <= CONFIRM_SECONDS) then
				armed.pet, armed.key, armed.at = id, key.id, os.clock()
				refresh()
				return
			end
			armed.at = -math.huge
			ctx.act("enchant", { pet = id, key = key.id, replace = replace })
		end)
	end

	-- One row per different mini cannon the player owns. A row is made the first time its mini cannon is seen
	-- and kept (hidden while the player owns none), so a button never vanishes under a finger.
	local rows = {}
	local function rowFor(id: string)
		local row = rows[id]
		if not row then
			row = UI.row(list, ROW_HEIGHT, 0)
			-- Two lines under the name: what it is, and what it carries.
			row.title.Position = UDim2.fromOffset(58, 3)
			row.title.Size = UDim2.new(1, -212, 0, 22)
			row.sub.Position = UDim2.fromOffset(58, 26)
			row.sub.Size = UDim2.new(1, -212, 0, ROW_HEIGHT - 30)
			row.button.Activated:Connect(function()
				picked = id
				armed.at = -math.huge
				refresh()
			end)
			rows[id] = row
		end
		return row
	end

	local shownCounts = nil -- the table of counts the list was last ordered for

	local function refreshList(counts)
		local ids = {}
		for id, count in counts do
			if Config.Pets[id] and typeof(count) == "number" and count > 0 then
				table.insert(ids, id)
			end
		end
		if counts ~= shownCounts then
			shownCounts = counts
			-- Strongest first; equal ones by id, so the list keeps its order.
			table.sort(ids, function(a, b)
				local bonusA, bonusB = Config.Pets[a].strength, Config.Pets[b].strength
				return if bonusA == bonusB then a < b else bonusA > bonusB
			end)
			local owned = {}
			for order, id in ids do
				owned[id] = true
				rowFor(id).frame.LayoutOrder = order
			end
			for id, row in rows do
				row.frame.Visible = owned[id] == true
			end
		end
		emptyLabel.Visible = #ids == 0
		for _, id in ids do
			local pet = Config.Pets[id]
			local row = rows[id]
			if not row then
				continue
			end
			row.icon.BackgroundColor3 = pet.color
			row.title.Text = `{pet.name}  x{counts[id]}`
			row.title.TextColor3 = Config.RarityColors[pet.rarity] or Colors.white
			local magic = Enchant.summary(id)
			row.sub.Text = `{pet.rarity}  •  {Format.petPower(pet)}{if pet.huge then " tower damage" else ""}  •  {Enchant.cost(id) or 0} 💎\n{if magic ~= "" then "✨ " .. magic else "No enchantments"}`
			row.sub.TextColor3 = if magic ~= "" then MAGIC else Colors.text
			setButton(row.button, if id == picked then "PICKED" else "PICK", if id == picked then Colors.gold else Colors.blue)
		end
	end

	local function refreshPanel(counts, unlocked: boolean, here: boolean)
		local id = picked
		local pet = id and Config.Pets[id]
		if not id or not pet or (counts[id] or 0) < 1 then
			picked = nil
			pickedName.Text = "Pick a mini cannon"
			pickedName.TextColor3 = Colors.white
			pickedNow.Text = "Its enchantments work while it is equipped, and add up over every equipped mini cannon."
			warning.Text = ""
			resultLabel.Text = ""
			costLabel.Text = "One key and some gems per roll"
			for _, key in Enchant.Keys do
				setButton(keyButtons[key.id], key.name, Colors.grey)
			end
			return
		end
		local items = State.feature("items")
		local gems = State.get("Diamonds", 0)
		local cost = Enchant.cost(id) or 0
		pickedName.Text = pet.name
		pickedName.TextColor3 = Config.RarityColors[pet.rarity] or Colors.white
		local lines = Enchant.lines(id)
		pickedNow.Text = if #lines > 0 then table.concat(lines, "\n") else "No enchantments yet"
		warning.Text = if pet.enchanted
			then "Enchanting again REPLACES these enchantments with new random ones. Press a key button twice to confirm."
			else ""
		resultLabel.Text = if lastResult.pet == id then lastResult.text else ""
		costLabel.Text = `Cost: {Format.abbreviate(cost)} 💎 gems + 1 key`
		for _, key in Enchant.Keys do
			local have = items[key.id] or 0
			local button = keyButtons[key.id]
			local isArmed = armed.pet == id and armed.key == key.id and os.clock() - armed.at <= CONFIRM_SECONDS
			if isArmed then
				setButton(button, "REPLACE?\nPRESS AGAIN", Colors.red)
			else
				local ready = unlocked and here and have > 0 and gems >= cost
				setButton(button, `{string.upper(key.name)}\nyou have {have}`, if ready then Colors.green else Colors.grey)
			end
		end
	end

	------------------------------------------------------------------------------------------------
	-- The second tab: the odds, the prices and every enchantment. Written once: none of it changes.
	------------------------------------------------------------------------------------------------
	do
		local info = UI.scroll(pages.odds)
		local order = 0
		local function block(title: string, color: Color3, lines: { string }, lineHeight: number)
			order += 1
			local height = 26 + #lines * lineHeight + 8
			local frame = UI.make("Frame", {
				Size = UDim2.new(1, -10, 0, height),
				BackgroundColor3 = Colors.row,
				BorderSizePixel = 0,
				LayoutOrder = order,
				Parent = info,
			}, { UI.corner(10) })
			UI.text({
				Position = UDim2.fromOffset(10, 3),
				Size = UDim2.new(1, -20, 0, 22),
				TextXAlignment = left,
				TextColor3 = color,
				MaxSize = 17,
				Text = title,
				Parent = frame,
			})
			UI.text({
				Position = UDim2.fromOffset(10, 26),
				Size = UDim2.new(1, -20, 0, #lines * lineHeight),
				TextXAlignment = left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				TextColor3 = Colors.text,
				MaxSize = 14,
				Text = table.concat(lines, "\n"),
				Parent = frame,
			})
		end
		for _, key in Enchant.Keys do
			block(`{string.upper(key.name)}: THE ODDS`, key.color, Enchant.oddsLines(key.id), 18)
		end
		block("WHAT A ROLL COSTS", Colors.gem, {
			"One key, and gems by the mini cannon's rarity:",
			Enchant.costLine(),
			`A mini cannon holds up to {Enchant.MAX} enchantments. Enchanting it again replaces them all.`,
		}, 18)
		for _, def in Enchant.List do
			block(`{def.name}  •  levels I / II / III`, MAGIC, { Enchant.describeLevels(def.id) }, 18)
		end
	end

	------------------------------------------------------------------------------------------------
	function refresh()
		for _, tab in TABS do
			tabs[tab.id].BackgroundColor3 = if tab.id == selectedTab then Colors.blue else Colors.grey
			pages[tab.id].Visible = tab.id == selectedTab
		end
		local unlocked = Enchant.unlocked(State.get("BestCleared", 0))
		local here = atTable()
		local items = State.feature("items")
		local restricted = State.feature("enchant").restricted == true
		if not unlocked then
			headline.Text = `Reach {world.name} to unlock enchanting`
		elseif restricted then
			headline.Text = "Enchanting cannot be offered in your region"
		elseif not here then
			headline.Text = `Enchant at the Enchanting Table on the {world.name} island`
		else
			local keys = {}
			for _, key in Enchant.Keys do
				table.insert(keys, `{items[key.id] or 0} {key.name}{if (items[key.id] or 0) == 1 then "" else "s"}`)
			end
			headline.Text = `💎 {Format.abbreviate(State.get("Diamonds", 0))} gems  •  {table.concat(keys, "  •  ")}`
		end
		local counts = State.meta.pets
		if typeof(counts) ~= "table" then
			counts = {}
		end
		buyButton.Visible = not restricted
		refreshPanel(counts, unlocked and not restricted, here)
		refreshList(counts)
	end

	ctx.Windows.register(Enchant.WINDOW, window, refresh)

	-- The server's answer to a roll: the new mini cannon stays picked, and the panel says what it got.
	ctx.on("enchant", function(result)
		if typeof(result) ~= "table" or typeof(result.pet) ~= "string" or not Config.Pets[result.pet] then
			return
		end
		picked = result.pet
		lastResult.pet = result.pet
		lastResult.text = `NEW: {Enchant.summary(result.pet)}`
		armed.at = -math.huge
		if window.frame.Visible then
			refresh()
		end
	end)

	-- An armed button goes back by itself; walking off the island (the portal home, the travel button)
	-- closes the table's window.
	task.spawn(function()
		while true do
			if window.frame.Visible and armed.at > 0 and os.clock() - armed.at > CONFIRM_SECONDS then
				armed.at = -math.huge
				refresh()
			end
			task.wait(0.5)
		end
	end)
	local wasHere = false
	State.onChange(function()
		local here = atTable()
		if window.frame.Visible and wasHere and not here then
			window.close()
		end
		wasHere = here
	end)
end

return { start = start }
