-- The CRATES window, opened at the crate stand in the marketplace: the crate shop. One row per crate with
-- its price or how it is got, how many the player holds, and buttons to buy it, open it and see its loot.
-- A crate that is opened as it is bought (the coin crate, the free daily one) has OPEN buttons with a price.
-- What a crate holds is shown by the loot viewer (ctx.Loot) when the game has one, and by a plain list in
-- this window when it has not. Either way the table is Crates.odds, the same list the server rolls on, and a
-- Secret mini cannon is listed as "???" until the player has found one: its chance is shown, what it is
-- stays a mystery.
-- What comes out of a crate is shown by src/client/Features/CrateOpening.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Crates"))

local NAME = "CRATES" -- the window's title, and the Window attribute of the stand's prompt
local ROW_HEIGHT = 100
local BUTTON_HEIGHT = 40
local BUTTON_WIDTH = 112
local BUTTON_GAP = 4
local BUTTON_TOP = 8
local COLUMN_X = { 328, 446, 564 } -- two columns of buy and open buttons, then VIEW LOOT
local LINE_HEIGHT = 30 -- a line of the plain loot list
local LIST_TOP = 42
local TICK_SECONDS = 1 -- the daily crate's countdown changes without any state change
local DAY_SECONDS = 86_400
local BALANCE_ATTRIBUTE = { coins = "Coins", diamonds = "Diamonds", candy = "Candy" }

local Crates = {}

function Crates.start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local batch = Shared.MaxPerPress
	local left = Enum.TextXAlignment.Left

	local window = UI.window(NAME, 720, 480)
	-- Two pages in one window: the shop, and the plain loot list of one crate.
	local shopPage = UI.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = window.body })
	local lootPage = UI.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = window.body })

	------------------------------------------------------------------------------------------------
	-- What a crate holds
	------------------------------------------------------------------------------------------------
	-- A crate's table for the loot viewer, written for the player as they are now: coins follow the level they have reached.
	local function lootSpec(crate)
		local best = State.get("Cleared", 0)
		local rows = {}
		for _, entry in Shared.odds(crate) do
			local reward = Shared.reward(entry.row, best)
			if reward.kind == "pet" then
				-- The viewer knows mini cannons: it fills in the name, the colour, and "???" for a Secret.
				table.insert(rows, { chance = entry.chance, pet = reward.id })
			else
				local view = Shared.view(reward)
				table.insert(rows, { chance = entry.chance, name = view.name, color = view.color, rarity = view.rarity, detail = view.detail })
			end
		end
		return { title = crate.name, subtitle = Shared.sourceText(crate, best), color = crate.color, rows = rows }
	end

	-- The loot viewer is another feature and may be missing, or start after this one: it is looked for again
	-- whenever it is needed. Returns whether the crates are in it.
	local registered = false
	local refused = false -- the viewer was there but would not take the crates: it is not asked again
	local function registerLoot(): boolean
		local Loot = ctx.Loot
		if registered or refused or not Loot then
			return registered
		end
		local ok, err = pcall(function()
			for order, crate in Shared.List do
				-- A Robux crate without a product id is not on sale, so it is not listed.
				local price = crate.price
				if price and price.currency == "robux" and price.product == 0 then
					continue
				end
				Loot.register({
					id = "crate:" .. crate.id,
					group = "Crates",
					name = crate.name,
					color = crate.color,
					order = order,
					build = function()
						return lootSpec(crate)
					end,
				})
			end
		end)
		if not ok then
			warn(`[Crates] the loot viewer did not take the crates, so the plain list is used: {err}`)
		end
		registered, refused = ok, not ok
		return registered
	end

	-- The plain list: one line per loot row, made as they are needed and reused for every crate.
	local listed = nil -- the crate the plain list is showing
	local backButton = UI.button({ Size = UDim2.fromOffset(100, 34), Text = "< BACK", BackgroundColor3 = Colors.blue, Parent = lootPage })
	local lootTitle = UI.text({
		Position = UDim2.fromOffset(112, 0),
		Size = UDim2.new(1, -112, 0, 34),
		TextXAlignment = left,
		TextColor3 = Colors.gold,
		MaxSize = 18,
		Parent = lootPage,
	})
	local lootList = UI.scroll(lootPage, { Position = UDim2.fromOffset(0, LIST_TOP), Size = UDim2.new(1, 0, 1, -LIST_TOP) })
	local lines = {}
	local function lineAt(index: number)
		if not lines[index] then
			local frame = UI.make("Frame", {
				Size = UDim2.new(1, -10, 0, LINE_HEIGHT),
				BackgroundColor3 = Colors.row,
				LayoutOrder = index,
				Parent = lootList,
			}, { UI.corner(8) })
			lines[index] = {
				frame = frame,
				reward = UI.text({
					Position = UDim2.fromOffset(10, 3),
					Size = UDim2.new(0.6, -10, 1, -6),
					TextXAlignment = left,
					MaxSize = 17,
					Parent = frame,
				}),
				chance = UI.text({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -10, 0, 3),
					Size = UDim2.new(0.4, -10, 1, -6),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = Colors.text,
					MaxSize = 17,
					Parent = frame,
				}),
			}
		end
		return lines[index]
	end

	local written = "" -- what the plain list was last written for
	local function refreshLoot()
		local crate = listed
		if not crate then
			return
		end
		local best = State.get("Cleared", 0)
		local found = State.feature("huge").found or {}
		local key = `{crate.id} {best} {found}`
		if key == written then
			return
		end
		written = key
		lootTitle.Text = `{string.upper(crate.name)}: what one gives, and how often`
		local odds = Shared.odds(crate)
		for index, entry in odds do
			local line, row = lineAt(index), entry.row
			local view = Shared.view(Shared.reward(row, best))
			local mystery = view.secret and not found[row.pet]
			line.frame.Visible = true
			line.reward.Text = if mystery then "???" else Shared.rewardText(row, best)
			line.reward.TextColor3 = if view.rarity then Config.RarityColors[view.rarity] or Colors.white else Colors.white
			-- Anything rarer than 1 in 1,000 also reads as odds.
			local chance = Config.chanceText(entry.chance)
			line.chance.Text = if entry.chance < 0.1 then `{chance}  •  {Config.oneIn(entry.chance)}` else chance
		end
		for index = #odds + 1, #lines do
			lines[index].frame.Visible = false
		end
	end

	local function showShop()
		listed = nil
		lootPage.Visible = false
		shopPage.Visible = true
	end
	backButton.Activated:Connect(showShop)

	local function showLoot(crate)
		if registerLoot() then
			local ok, err = pcall(ctx.Loot.open, "crate:" .. crate.id)
			if ok then
				return
			end
			warn(`[Crates] the loot viewer could not open {crate.id}: {err}`)
		end
		listed = crate
		shopPage.Visible = false
		lootPage.Visible = true
		refreshLoot()
	end

	------------------------------------------------------------------------------------------------
	-- The shop: one row per crate, built once
	------------------------------------------------------------------------------------------------
	local balance = UI.text({ Size = UDim2.new(1, 0, 0, 22), TextColor3 = Colors.text, MaxSize = 17, Parent = shopPage })
	local list = UI.scroll(shopPage, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28) })

	-- line is 1 or 2. A wide button takes both columns, a tall one both lines.
	local function place(button: TextButton, column: number, line: number, wide: boolean?, tall: boolean?)
		button.Position = UDim2.fromOffset(COLUMN_X[column], BUTTON_TOP + (line - 1) * (BUTTON_HEIGHT + BUTTON_GAP))
		button.Size = UDim2.fromOffset(
			if wide then COLUMN_X[2] - COLUMN_X[1] + BUTTON_WIDTH else BUTTON_WIDTH,
			if tall then BUTTON_HEIGHT * 2 + BUTTON_GAP else BUTTON_HEIGHT
		)
	end

	local rows = {}
	for index, crate in Shared.List do
		local frame = UI.make("Frame", {
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
			BackgroundColor3 = Colors.row,
			LayoutOrder = index,
			Parent = list,
		}, { UI.corner(10) })
		-- The crate, drawn small in its own colours.
		local icon = UI.make("Frame", {
			Position = UDim2.fromOffset(10, 18),
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = crate.color,
			BorderSizePixel = 0,
			Parent = frame,
		}, { UI.corner(8), UI.stroke(2) })
		for _, y in { 0.12, 0.7 } do
			UI.make("Frame", {
				Position = UDim2.fromScale(0, y),
				Size = UDim2.fromScale(1, 0.16),
				BackgroundColor3 = crate.color:Lerp(Color3.new(0, 0, 0), 0.55),
				BorderSizePixel = 0,
				Parent = icon,
			})
		end
		UI.text({ Position = UDim2.fromScale(0.25, 0.28), Size = UDim2.fromScale(0.5, 0.44), Text = "?", ZIndex = 2, Parent = icon })

		-- The server checks every press: what the buttons say is only what it will most likely answer.
		local function button(action: string, count: number): TextButton
			local made = UI.button({ Parent = frame })
			made.Activated:Connect(function()
				ctx.act(action, { id = crate.id, count = count })
			end)
			return made
		end
		local row: { [string]: any } = {
			crate = crate,
			frame = frame,
			title = UI.text({
				Position = UDim2.fromOffset(84, 6),
				Size = UDim2.fromOffset(236, 24),
				TextXAlignment = left,
				TextColor3 = Config.RarityColors[crate.rarity] or Colors.white,
				Parent = frame,
			}),
			price = UI.text({
				Position = UDim2.fromOffset(84, 74),
				Size = UDim2.fromOffset(236, 20),
				TextXAlignment = left,
				TextColor3 = Colors.gold,
				MaxSize = 15,
				Parent = frame,
			}),
		}
		-- buyOne, buyBatch, openOne and openBatch join it below: a crate only has the buttons it can use.
		UI.text({
			Position = UDim2.fromOffset(84, 31),
			Size = UDim2.fromOffset(236, 40),
			TextXAlignment = left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = Colors.text,
			MaxSize = 14,
			Text = crate.desc,
			Parent = frame,
		})
		if crate.daily then
			row.buyOne = button("buyCrates", 1)
			place(row.buyOne, 1, 1, true, true)
		elseif crate.instant then
			row.buyOne, row.buyBatch = button("buyCrates", 1), button("buyCrates", batch)
			place(row.buyOne, 1, 1, true)
			place(row.buyBatch, 1, 2, true)
		else
			local price = crate.price
			if price then
				row.buyOne = button("buyCrates", 1)
				-- A Robux crate is one developer product: one crate a purchase.
				if price.currency == "robux" then
					place(row.buyOne, 1, 1, false, true)
				else
					place(row.buyOne, 1, 1)
					row.buyBatch = button("buyCrates", batch)
					place(row.buyBatch, 1, 2)
				end
			end
			row.openOne, row.openBatch = button("openCrates", 1), button("openCrates", batch)
			place(row.openOne, if price then 2 else 1, 1, price == nil)
			place(row.openBatch, if price then 2 else 1, 2, price == nil)
		end
		local viewButton = UI.button({ Text = "VIEW\nLOOT", BackgroundColor3 = Colors.blue, Parent = frame })
		place(viewButton, 3, 1, false, true)
		viewButton.Activated:Connect(function()
			showLoot(crate)
		end)
		rows[index] = row
	end

	local function setButton(button: TextButton?, text: string, ready: boolean)
		if button then
			button.Text = text
			button.BackgroundColor3 = if ready then Colors.green else Colors.grey
		end
	end

	local function refresh()
		local items = State.feature("items")
		local meta = State.feature("crates")
		local best = State.get("Cleared", 0)
		local now = State.now()
		local today = Config.dayNumber(now)
		local eventLive = (State.meta.event or {}).active == true
		local boughtToday = if meta.buyDay == today and typeof(meta.bought) == "table" then meta.bought else {}

		local funds = `💰 {Format.abbreviate(State.get("Coins", 0))}    💎 {Format.abbreviate(State.get("Diamonds", 0))}`
		if eventLive then
			funds ..= `    🍬 {Format.abbreviate(State.get("Candy", 0))}`
		end
		balance.Text = funds

		for _, row in rows do
			local crate, price = row.crate, row.crate.price
			local held = items[crate.id] or 0
			local source = Shared.sourceText(crate, best)
			-- An event crate leaves the shop with the event, unless the player still has some to open.
			-- A Robux crate without a product id is not on sale yet: hidden too, unless some are held.
			local unsold = price ~= nil and price.currency == "robux" and price.product == 0
			row.frame.Visible = (not unsold or held > 0) and (not (price and price.event) or eventLive or held > 0)
			row.title.Text = if crate.instant then crate.name else `{crate.name}  x{held}`

			if crate.daily then
				if meta.claimDay == today then
					setButton(row.buyOne, `NEXT ONE IN\n{Format.duration((today + 1) * DAY_SECONDS - now)}`, false)
				else
					setButton(row.buyOne, "OPEN TODAY'S\nFREE CRATE", true)
				end
			elseif price then
				local each = Shared.price(crate, best) or 0
				local icon = Shared.Currency[price.currency].icon
				local verb = if crate.instant then "OPEN" else "BUY"
				if Shared.Paid[price.currency] and meta.restricted == true then
					-- Roblox does not allow paid random items to be sold in this player's region.
					setButton(row.buyOne, "NOT SOLD IN\nYOUR REGION", false)
					setButton(row.buyBatch, "NOT SOLD IN\nYOUR REGION", false)
				elseif price.event and not eventLive then
					-- Crates of the event are only sold during it. The ones a player still holds can always be opened.
					setButton(row.buyOne, "EVENT\nOVER", false)
					setButton(row.buyBatch, "EVENT\nOVER", false)
				elseif price.currency == "robux" then
					if price.product == 0 then
						setButton(row.buyOne, "NOT ON\nSALE YET", false)
					else
						setButton(row.buyOne, `BUY 1\n{price.cost} {icon}`, true)
					end
				else
					local owned = State.get(BALANCE_ATTRIBUTE[price.currency], 0)
					local stock = if price.perDay then math.max(0, price.perDay - (boughtToday[crate.id] or 0)) else math.huge
					if price.perDay then
						source ..= `  •  {stock} left today`
					end
					if stock < 1 then
						setButton(row.buyOne, "SOLD OUT\nTODAY", false)
						setButton(row.buyBatch, "SOLD OUT\nTODAY", false)
					else
						-- The batch button buys a full batch, or what is left of today's stock.
						local many = math.min(batch, stock)
						setButton(row.buyOne, `{verb} 1\n{Format.abbreviate(each)} {icon}`, owned >= each)
						setButton(row.buyBatch, `{verb} {many}\n{Format.abbreviate(each * many)} {icon}`, owned >= each * many)
					end
				end
				if crate.drop then
					source ..= "  •  bosses drop it too"
				end
			end
			row.price.Text = source
			setButton(row.openOne, "OPEN 1", held >= 1)
			-- The batch button opens what the player has, up to a full batch.
			setButton(row.openBatch, `OPEN {if held >= 2 then math.min(held, batch) else batch}`, held >= 2)
		end
		refreshLoot()
	end

	ctx.Windows.register(NAME, window, refresh)

	-- The window always opens on the shop.
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.frame.Visible then
			showShop()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			if window.frame.Visible then
				refresh()
			end
		end
	end)

	-- The crates go into the loot viewer now if it is there, and a moment later if it starts after this feature.
	registerLoot()
	task.defer(registerLoot)
end

return Crates
