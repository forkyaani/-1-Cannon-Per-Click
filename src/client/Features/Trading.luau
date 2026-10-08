-- The TRADE window: who is in the marketplace, incoming requests, the trade itself and the history.
-- The server runs every trade (src/server/Features/Trading.luau). This file draws what it publishes
-- (State.feature("trade") and "tradeHistory") and turns presses into requests; the limits are in the shared module.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Trading"))

local player = Players.LocalPlayer

local TICK_SECONDS = 0.25 -- countdowns, and the player list (other players come and go without a state change)
local CLOCK_SLACK = 0.3 -- this client's idea of the server clock can run a little ahead of the server's
-- How many one tap adds or takes back. The server trims every amount to what is owned and allowed, so ALL
-- only has to be a big number.
local AMOUNTS = {
	{ pick = "x1", take = "-1", value = 1 },
	{ pick = "x10", take = "-10", value = 10 },
	{ pick = "ALL", take = "-ALL", value = 1e6 },
}
local GIVE_COLOR = Color3.fromRGB(255, 150, 140)
local GET_COLOR = Color3.fromRGB(140, 235, 150)
local BLACK = Color3.new(0, 0, 0)

local Trading = {}

function Trading.start(ctx)
	local Config, Format, Items, State, UI = ctx.Config, ctx.Format, ctx.Items, ctx.State, ctx.UI
	local Colors = UI.Colors
	local act = ctx.act

	local function corner(radius: number): UICorner
		return UI.make("UICorner", { CornerRadius = UDim.new(0, radius) })
	end

	local function setButton(button: TextButton, text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	-- A round colour swatch: the icon of a mini cannon or an item. Its ring takes a fused tier's colour.
	local function swatch(parent: Instance, size: number, x: number, y: number): (Frame, UIStroke)
		local ring = UI.make("UIStroke", { Thickness = 2, Color = BLACK })
		local dot = UI.make("Frame", {
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(x, y),
			Parent = parent,
		}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), ring })
		return dot, ring
	end

	------------------------------------------------------------------------------------------------
	-- Mini cannons and items as the lists show them
	------------------------------------------------------------------------------------------------
	-- kind is "pets" or "items". Looked up when asked: other features define theirs after this file loads,
	-- and none of their fields is trusted to be filled in.
	local function describe(kind: string, id: string)
		if kind == "pets" then
			local pet = Config.Pets[id]
			if pet then
				local tier = Config.FuseTiers[pet.tier]
				-- "+129 DPS", or "x3 tower damage" for a Huge: it has no damage per second to add up.
				local power = if pet.huge then `{Format.petPower(pet)} tower damage` else Format.petPower(pet)
				-- An enchanted one says which enchantments it carries, wherever it is listed.
				local enchants = if pet.enchants then Config.enchantText(id) else ""
				local magic = if enchants ~= "" then `  •  ✨ {enchants}` else ""
				return {
					name = pet.name,
					color = pet.color,
					ring = pet.accent or (tier and tier.color),
					text = Config.RarityColors[pet.rarity] or Colors.white, -- the rarity's colour
					detail = `{pet.rarity}  •  {power}{magic}`,
					short = power .. magic,
					magic = if enchants ~= "" then ` ({enchants})` else nil, -- for an offer written as a sentence
					group = "",
					sort = pet.bonus,
					bonus = if pet.huge then 0 else (pet.dps or 0), -- its damage per second: an offer's are added up
					huge = pet.huge == true,
				}
			end
		else
			local item = Items.get(id)
			if item then
				local label = item.rarity or item.category or "item"
				return {
					name = item.name or id,
					color = item.color or Colors.white,
					text = Config.RarityColors[item.rarity] or Colors.white,
					detail = if item.rarity and item.category then `{item.rarity} {item.category}` else label,
					short = label,
					group = item.category or "",
					sort = -(item.order or 0),
					bonus = 0,
				}
			end
		end
		-- Something this build no longer knows (an old trade in the history): its id is better than nothing.
		return { name = id, color = Colors.grey, text = Colors.white, detail = "", short = "", group = "~", sort = 0, bonus = 0 }
	end

	-- Everything in an offer (or in the backpack) as a sorted list: mini cannons first, the strongest on top,
	-- then items by category.
	local function listed(offer)
		local things = {}
		for _, kind in { "pets", "items" } do
			for id, count in (offer or {})[kind] or {} do
				table.insert(things, { key = `{kind}:{id}`, kind = kind, id = id, count = count, info = describe(kind, id) })
			end
		end
		table.sort(things, function(a, b): boolean
			if a.kind ~= b.kind then
				return a.kind == "pets"
			elseif a.info.group ~= b.info.group then
				return a.info.group < b.info.group
			elseif a.info.sort ~= b.info.sort then
				return a.info.sort > b.info.sort
			end
			return a.key < b.key
		end)
		return things
	end

	-- An offer in words: "Mini Gold Cannon x2, 2x Power x5".
	local function sentence(offer): string
		local parts = {}
		for _, thing in listed(offer) do
			table.insert(parts, `{thing.info.name}{thing.info.magic or ""} x{thing.count}`)
		end
		return if #parts > 0 then table.concat(parts, ", ") else "nothing"
	end

	-- Keeps one entry per thing in `pool`: makes the missing ones, updates them all in order and removes those
	-- whose thing is gone. An entry that stays is never rebuilt, so its button does not vanish under a finger.
	local function arrange(pool, things, create, update)
		local kept = {}
		for order, thing in things do
			kept[thing.key] = true
			local entry = pool[thing.key]
			if not entry then
				entry = create(thing)
				pool[thing.key] = entry
			end
			entry.frame.LayoutOrder = order
			update(entry, thing)
		end
		for key, entry in pool do
			if not kept[key] then
				entry.frame:Destroy()
				pool[key] = nil
			end
		end
	end

	-- Fills in an entry made of a swatch, a name and a line of detail.
	local function paint(entry, info, name: string, detail: string)
		entry.dot.BackgroundColor3 = info.color
		entry.ring.Color = info.ring or BLACK
		entry.ring.Thickness = if info.ring then 3 else 2
		entry.name.Text = name
		entry.name.TextColor3 = info.text
		entry.detail.Text = detail
	end

	------------------------------------------------------------------------------------------------
	-- The window: two tabs outside a trade, the trade screen during one, the result right after one
	------------------------------------------------------------------------------------------------
	local window = UI.window("TRADE", 800, 560)
	local body = window.body

	local function pane(top: number): Frame
		return UI.make("Frame", {
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 1, -top),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = body,
		})
	end

	local tabBar = UI.make("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = body })
	local playersTab = UI.button({ Size = UDim2.fromOffset(130, 36), Text = "PLAYERS", Parent = tabBar })
	local historyTab = UI.button({
		Size = UDim2.fromOffset(130, 36),
		Position = UDim2.fromOffset(138, 0),
		Text = "HISTORY",
		Parent = tabBar,
	})
	-- Whether this player can trade, and if not, why.
	local statusLabel = UI.text({
		Size = UDim2.new(1, -284, 1, 0),
		Position = UDim2.fromOffset(280, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = true,
		MaxSize = 16,
		Parent = tabBar,
	})
	local playersPane, historyPane, tradePane, donePane = pane(44), pane(44), pane(0), pane(0)
	local tab = "players"
	local done = nil -- the trade that just finished, while its result is on screen

	------------------------------------------------------------------------------------------------
	-- PLAYERS: everyone else in the marketplace, with a button to ask them (or to answer them)
	------------------------------------------------------------------------------------------------
	local playerList = UI.scroll(playersPane)
	local nobodyLabel = UI.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -80, 0, 70),
		TextColor3 = Colors.text,
		TextWrapped = true,
		MaxSize = 20,
		Text = "Nobody else is in the marketplace right now.\nBring a friend here to trade!",
		Parent = playersPane,
	})
	local playerRows = {} -- [user id] = row

	local function playerRow(other: Player)
		local id = other.UserId
		local row = UI.row(playerList, 60, 0)
		-- Narrower text: the NO button sits beside the main one.
		row.title.Size = UDim2.new(1, -276, 0, 26)
		row.sub.Size = UDim2.new(1, -276, 0, 20)
		row.icon.BackgroundColor3 = Color3.fromHSV(id % 360 / 360, 0.55, 0.95)
		UI.face(row, id)
		row.no = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -150, 0.5, 0),
			Size = UDim2.fromOffset(56, 42),
			Text = "NO",
			BackgroundColor3 = Colors.red,
			Parent = row.frame,
		})
		row.asked = false -- whether this player has a request waiting for an answer
		row.button.Activated:Connect(function()
			act(if row.asked then "tradeAccept" else "tradeRequest", id)
		end)
		row.no.Activated:Connect(function()
			act("tradeDecline", id)
		end)
		playerRows[id] = row
		return row
	end

	local function refreshPlayers(info)
		local time = State.now()
		local asking = {} -- [user id] = the request that player has waiting here
		for _, request in info.requests or {} do
			asking[request.id] = request
		end
		local others = {}
		for _, other in Players:GetPlayers() do
			-- Place, not InMarket: that one is true on a world's island too, and trading is the square's.
			if other ~= player and other:GetAttribute("Place") == "market" then
				table.insert(others, other)
			end
		end
		-- Whoever is asking comes first, then by name.
		table.sort(others, function(a: Player, b: Player): boolean
			local askingA, askingB = asking[a.UserId] ~= nil, asking[b.UserId] ~= nil
			if askingA ~= askingB then
				return askingA
			end
			local nameA, nameB = string.lower(a.DisplayName), string.lower(b.DisplayName)
			if nameA ~= nameB then
				return nameA < nameB
			end
			return a.UserId < b.UserId
		end)

		-- The button is only green when a press would really send a request.
		local canAsk = info.reason == nil and math.max(info.cooldown or 0, info.nextAsk or 0) <= time
		local sent, later = info.sent or {}, info.later or {}
		local shown = {}
		for order, other in others do
			local id = other.UserId
			local row = playerRows[id] or playerRow(other)
			local request = asking[id]
			local sentUntil, askAt = sent[tostring(id)], later[tostring(id)]
			shown[id] = true
			row.frame.LayoutOrder = order
			row.asked = request ~= nil
			row.no.Visible = request ~= nil
			row.title.Text = other.DisplayName
			row.title.TextColor3 = if request then Colors.gold else Colors.white
			if request then
				row.sub.Text = `@{other.Name}  •  wants to trade with you!`
				setButton(row.button, "ACCEPT", Colors.green)
			elseif other:GetAttribute("InTrade") == true then
				row.sub.Text = `@{other.Name}  •  in a trade`
				setButton(row.button, "BUSY", Colors.grey)
			elseif sentUntil and sentUntil > time then
				row.sub.Text = `@{other.Name}  •  waiting for an answer`
				setButton(row.button, `ASKED\n{math.ceil(sentUntil - time)}s`, Colors.grey)
			elseif askAt and askAt > time then
				row.sub.Text = `@{other.Name}  •  you asked a moment ago`
				setButton(row.button, `ASK AGAIN\nIN {math.ceil(askAt - time)}s`, Colors.grey)
			else
				row.sub.Text = `@{other.Name}`
				setButton(row.button, "TRADE", if canAsk then Colors.green else Colors.grey)
			end
		end
		for id, row in playerRows do
			if not shown[id] then
				row.frame:Destroy()
				playerRows[id] = nil
			end
		end
		nobodyLabel.Visible = #others == 0
	end

	-- The line beside the tabs: why this player cannot trade, or how long until they can again.
	local function refreshStatus(info)
		local left = (info.cooldown or 0) - State.now()
		if info.reason then
			statusLabel.Text = info.reason
			statusLabel.TextColor3 = Colors.red
		elseif left > 0 then
			statusLabel.Text = `You can trade again in {math.ceil(left)}s`
			statusLabel.TextColor3 = Colors.text
		else
			statusLabel.Text = "Ask a player to trade. Both of you must be in the marketplace."
			statusLabel.TextColor3 = Colors.text
		end
	end

	------------------------------------------------------------------------------------------------
	-- HISTORY: the last trades, newest first
	------------------------------------------------------------------------------------------------
	local historyList = UI.scroll(historyPane)
	local historyHeader = UI.header(historyList, 0)
	local historyRows = {}
	local historyShown = nil -- the published table the rows were last written from

	local function historyRow(order: number)
		local frame = UI.make("Frame", {
			Size = UDim2.new(1, -10, 0, 98),
			BackgroundColor3 = Colors.row,
			LayoutOrder = order,
			Parent = historyList,
		}, { corner(10) })
		local function line(top: number, height: number, color: Color3, size: number): TextLabel
			return UI.text({
				Size = UDim2.new(1, -24, 0, height),
				Position = UDim2.fromOffset(12, top),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				TextColor3 = color,
				MaxSize = size,
				Parent = frame,
			})
		end
		return {
			frame = frame,
			title = line(6, 22, Colors.white, 18),
			gave = line(30, 30, GIVE_COLOR, 15),
			got = line(63, 30, GET_COLOR, 15),
		}
	end

	local function refreshHistory()
		local history = State.feature("tradeHistory")
		if history == historyShown then
			return
		end
		historyShown = history
		local list = history.list or {}
		historyHeader.Text = if #list == 0
			then "No trades yet. Every trade you finish is listed here."
			else `Your recent trades  •  {history.total or #list} in all`
		for index, entry in list do
			local row = historyRows[index]
			if not row then
				row = historyRow(index)
				historyRows[index] = row
			end
			row.frame.Visible = true
			row.title.Text = `{entry.name} (@{entry.user})  •  {os.date("%d %b %H:%M", entry.at)}`
			row.gave.Text = `You gave:  {sentence(entry.gave)}`
			row.got.Text = `You got:  {sentence(entry.got)}`
		end
		for index = #list + 1, #historyRows do
			historyRows[index].frame.Visible = false
		end
	end

	------------------------------------------------------------------------------------------------
	-- The trade: both offers side by side, under them the backpack to pick from (or, once this player is
	-- ready, the summary and the countdown), and CANCEL and READY at the bottom
	------------------------------------------------------------------------------------------------
	local PANEL_TOP, PANEL_HEIGHT = 30, 190 -- three rows of an offer show without scrolling
	local LOWER_TOP, LOWER_HEIGHT = 250, 184
	local amount = AMOUNTS[1]

	local tradeTitle = UI.text({
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.gold,
		Parent = tradePane,
	})

	local function offerPanel(title: string, right: boolean)
		local frame = UI.make("Frame", {
			Position = if right then UDim2.new(0.5, 6, 0, PANEL_TOP) else UDim2.fromOffset(0, PANEL_TOP),
			Size = UDim2.new(0.5, -6, 0, PANEL_HEIGHT),
			BackgroundColor3 = Colors.dark,
			Parent = tradePane,
		}, { corner(10) })
		return {
			title = title,
			-- The title and what the mini cannons in the offer add up to, so the two sides can be compared.
			header = UI.text({
				Size = UDim2.new(1, -150, 0, 22),
				Position = UDim2.fromOffset(10, 5),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxSize = 18,
				Parent = frame,
			}),
			tag = UI.text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 5),
				Size = UDim2.fromOffset(130, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				MaxSize = 16,
				Parent = frame,
			}),
			list = UI.scroll(frame, { Position = UDim2.fromOffset(6, 32), Size = UDim2.new(1, -12, 1, -38) }),
			empty = UI.text({
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(1, 0, 0, 22),
				TextColor3 = Colors.text,
				MaxSize = 16,
				Text = "Nothing yet",
				Parent = frame,
			}),
			rows = {},
		}
	end
	local givePanel = offerPanel("YOU GIVE", false)
	local getPanel = offerPanel("YOU GET", true)

	-- One thing in an offer. This player's own rows are buttons, big enough for a thumb: a tap takes some back,
	-- and the red tag says how many.
	local function offerRow(panel, thing, mine: boolean)
		local props = {
			Size = UDim2.new(1, -10, 0, 44),
			BackgroundColor3 = Colors.row,
			BorderSizePixel = 0,
			Parent = panel.list,
		}
		if mine then
			props.Text = ""
		end
		local frame = UI.make(if mine then "TextButton" else "Frame", props, { corner(8) })
		local dot, ring = swatch(frame, 26, 8, 9)
		local width = if mine then -108 else -48
		local row = {
			frame = frame,
			dot = dot,
			ring = ring,
			name = UI.text({
				Size = UDim2.new(1, width, 0, 22),
				Position = UDim2.fromOffset(42, 2),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxSize = 17,
				Parent = frame,
			}),
			detail = UI.text({
				Size = UDim2.new(1, width, 0, 17),
				Position = UDim2.fromOffset(42, 25),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Colors.text,
				MaxSize = 14,
				Parent = frame,
			}),
		}
		if mine then
			row.take = UI.text({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(54, 28),
				BackgroundTransparency = 0,
				BackgroundColor3 = Colors.red,
				Text = amount.take,
				MaxSize = 17,
				Parent = frame,
			})
			corner(6).Parent = row.take
			frame.Activated:Connect(function()
				act("tradeOffer", { kind = thing.kind, id = thing.id, add = -amount.value })
			end)
		end
		return row
	end

	local function fillOffer(panel, offer, mine: boolean, isReady: boolean)
		local things = listed(offer)
		local worth, huges = 0, 0
		arrange(panel.rows, things, function(thing)
			return offerRow(panel, thing, mine)
		end, function(row, thing)
			paint(row, thing.info, `{thing.info.name}  x{thing.count}`, thing.info.detail)
			worth += thing.info.bonus * thing.count
			if thing.info.huge then
				huges += thing.count
			end
		end)
		panel.empty.Visible = #things == 0
		local header = { panel.title }
		if worth > 0 then
			table.insert(header, Format.dps(worth))
		end
		if huges > 0 then
			table.insert(header, `{huges} Huge`)
		end
		panel.header.Text = table.concat(header, "  •  ")
		panel.tag.Text = if isReady then "READY" else "NOT READY"
		panel.tag.TextColor3 = if isReady then Colors.green else Colors.text
	end

	-- What stands in the way of the trade, or what the player should know before agreeing to it.
	local noteLabel = UI.text({
		Position = UDim2.fromOffset(0, PANEL_TOP + PANEL_HEIGHT + 4),
		Size = UDim2.new(1, 0, 0, 20),
		MaxSize = 17,
		Parent = tradePane,
	})

	local function note(trade): (string, Color3)
		local gives, gets = Rules.total(trade.give.pets), Rules.total(trade.get.pets)
		if gets > 0 and gets - gives > trade.room then
			return `Your storage is full: make room for {gets - gives - trade.room} more mini cannons`, Colors.red
		elseif gives > 0 and gives - gets > trade.theirRoom then
			return `{trade.partner.name} has no room for all of these mini cannons`, Colors.red
		elseif Rules.stacks(trade.give) > 0 and Rules.stacks(trade.get) == 0 then
			return "You get NOTHING back for this. Only go on if it is a gift!", Colors.red
		elseif trade.theirReady and not trade.ready then
			return `{trade.partner.name} is ready. Check both sides, then press READY.`, Colors.gold
		end
		return "Any change un-readies both players.", Colors.text
	end

	-- The backpack: everything this player can trade, as a grid of cells. A tap adds to the offer.
	local backpack = UI.make("Frame", {
		Position = UDim2.fromOffset(0, LOWER_TOP),
		Size = UDim2.new(1, 0, 0, LOWER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = tradePane,
	})
	UI.text({
		Size = UDim2.new(1, -250, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.gold,
		MaxSize = 18,
		Text = "YOUR BACKPACK  •  tap to add",
		Parent = backpack,
	})
	local amountButtons = {}
	local grid = UI.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = backpack,
	}, {
		UI.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(186, 54),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local emptyBackpack = UI.text({
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = Colors.text,
		TextWrapped = true,
		MaxSize = 18,
		Text = "Nothing you own can be traded yet.\nHatch eggs here in the marketplace to get mini cannons.",
		Parent = backpack,
	})
	local cells = {}

	local function pickAmount(picked)
		amount = picked
		for index, button in amountButtons do
			button.BackgroundColor3 = if AMOUNTS[index] == picked then Colors.blue else Colors.grey
		end
		for _, row in givePanel.rows do
			row.take.Text = picked.take
		end
	end
	for index, entry in AMOUNTS do
		amountButtons[index] = UI.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(#AMOUNTS - index) * 78, 0, 0),
			Size = UDim2.fromOffset(72, 28),
			Text = entry.pick,
			Parent = backpack,
		})
		amountButtons[index].Activated:Connect(function()
			pickAmount(entry)
		end)
	end
	pickAmount(amount)

	local function cell(thing)
		local frame = UI.make("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BorderSizePixel = 0,
			BackgroundColor3 = Colors.row,
			Parent = grid,
		}, { corner(8) })
		local dot, ring = swatch(frame, 28, 8, 13)
		frame.Activated:Connect(function()
			act("tradeOffer", { kind = thing.kind, id = thing.id, add = amount.value })
		end)
		return {
			frame = frame,
			dot = dot,
			ring = ring,
			name = UI.text({
				Size = UDim2.new(1, -50, 0, 24),
				Position = UDim2.fromOffset(44, 4),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxSize = 16,
				Parent = frame,
			}),
			detail = UI.text({
				Size = UDim2.new(1, -50, 0, 19),
				Position = UDim2.fromOffset(44, 30),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Colors.text,
				MaxSize = 14,
				Parent = frame,
			}),
		}
	end

	local function fillBackpack(trade)
		local owned = { pets = {}, items = {} }
		for id, count in State.meta.pets or {} do
			if Rules.canTrade("pets", id) then
				owned.pets[id] = count
			end
		end
		for id, count in State.feature("items") do
			if count > 0 and Rules.canTrade("items", id) then
				owned.items[id] = count
			end
		end
		local things = listed(owned)
		arrange(cells, things, cell, function(entry, thing)
			-- What is already on the table is not in the backpack any more.
			local left = math.max(0, thing.count - (trade.give[thing.kind][thing.id] or 0))
			paint(entry, thing.info, thing.info.name, `x{left}  •  {thing.info.short}`)
			entry.frame.BackgroundColor3 = if left > 0 then Colors.row else Colors.dark
		end)
		emptyBackpack.Visible = #things == 0
	end

	-- Once this player is ready the backpack makes way for what they agreed to, in plain words.
	local summary = UI.make("Frame", {
		Position = UDim2.fromOffset(0, LOWER_TOP),
		Size = UDim2.new(1, 0, 0, LOWER_HEIGHT),
		BackgroundColor3 = Colors.dark,
		Visible = false,
		Parent = tradePane,
	}, { corner(10) })
	local countdownLabel = UI.text({
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 8),
		TextColor3 = Colors.gold,
		Parent = summary,
	})
	local function summaryLine(top: number): TextLabel
		return UI.text({
			Position = UDim2.fromOffset(14, top),
			Size = UDim2.new(1, -28, 0, 58),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			MaxSize = 20,
			Parent = summary,
		})
	end
	local summaryGive, summaryGet = summaryLine(54), summaryLine(118)
	summaryGive.TextColor3 = GIVE_COLOR

	local cancelButton = UI.button({
		Position = UDim2.new(0, 0, 1, -56),
		Size = UDim2.fromOffset(170, 54),
		Text = "CANCEL",
		BackgroundColor3 = Colors.red,
		Parent = tradePane,
	})
	local readyButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -56),
		Size = UDim2.fromOffset(290, 54),
		Parent = tradePane,
	})
	UI.text({
		Position = UDim2.new(0, 182, 1, -56),
		Size = UDim2.new(1, -484, 0, 54),
		TextColor3 = Colors.text,
		TextWrapped = true,
		MaxSize = 15,
		Text = `When both are READY a {Rules.CountdownSeconds} second countdown starts. Nothing moves before it ends.`,
		Parent = tradePane,
	})
	cancelButton.Activated:Connect(function()
		act("tradeCancel")
	end)
	readyButton.Activated:Connect(function()
		local trade = State.feature("trade").trade
		if trade then
			-- READY names the offers it was pressed for; false takes it back.
			act("tradeReady", if trade.ready then false else trade.version)
		end
	end)

	local function refreshTrade(trade)
		tradeTitle.Text = `Trading with {trade.partner.name} (@{trade.partner.user})`
		fillOffer(givePanel, trade.give, true, trade.ready)
		fillOffer(getPanel, trade.get, false, trade.theirReady)
		noteLabel.Text, noteLabel.TextColor3 = note(trade)
		backpack.Visible = not trade.ready
		summary.Visible = trade.ready
		if trade.ready then
			local gift = Rules.stacks(trade.get) == 0
			summaryGive.Text = `YOU GIVE:  {sentence(trade.give)}`
			summaryGet.Text = if gift then "YOU GET:  NOTHING" else `YOU GET:  {sentence(trade.get)}`
			summaryGet.TextColor3 = if gift then Colors.red else GET_COLOR
		else
			fillBackpack(trade)
		end
	end

	-- The parts of the trade screen that change with the clock.
	local function tickTrade(trade)
		local time = State.now()
		local locked = trade.readyAt + CLOCK_SLACK - time
		if trade.ready then
			setButton(readyButton, "NOT READY", Colors.orange)
		elseif Rules.stacks(trade.give) + Rules.stacks(trade.get) == 0 then
			setButton(readyButton, "ADD SOMETHING FIRST", Colors.grey)
		elseif locked > 0 then
			setButton(readyButton, `READY IN {math.max(1, math.ceil(trade.readyAt - time))}`, Colors.grey)
		else
			setButton(readyButton, "READY", Colors.green)
		end
		if trade.endsAt > 0 then
			local left = trade.endsAt - time
			countdownLabel.Text = if left > 0 then `TRADING IN {math.ceil(left)}` else "TRADING..."
		else
			countdownLabel.Text = `Waiting for {trade.partner.name} to press READY`
		end
	end

	------------------------------------------------------------------------------------------------
	-- The result, shown in place of the trade when it went through
	------------------------------------------------------------------------------------------------
	UI.text({
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 50),
		TextColor3 = Colors.green,
		Text = "TRADE COMPLETE!",
		Parent = donePane,
	})
	local doneWith = UI.text({
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = Colors.text,
		Parent = donePane,
	})
	local function doneLine(top: number, color: Color3): TextLabel
		return UI.text({
			Position = UDim2.fromOffset(40, top),
			Size = UDim2.new(1, -80, 0, 110),
			TextWrapped = true,
			TextColor3 = color,
			MaxSize = 22,
			Parent = donePane,
		})
	end
	local doneGave, doneGot = doneLine(124, GIVE_COLOR), doneLine(248, GET_COLOR)
	local doneButton = UI.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(260, 56),
		Text = "OK",
		BackgroundColor3 = Colors.green,
		Parent = donePane,
	})

	------------------------------------------------------------------------------------------------
	-- Refreshing
	------------------------------------------------------------------------------------------------
	-- What the trade screen was last built from. The server publishes a new table with every change, so
	-- comparing the tables themselves tells whether anything has to be rebuilt.
	local builtTrade, builtMeta, builtItems = nil, nil, nil

	local function refresh()
		local info = State.feature("trade")
		local trade = info.trade
		local lobby = trade == nil and done == nil
		tabBar.Visible = lobby
		playersPane.Visible = lobby and tab == "players"
		historyPane.Visible = lobby and tab == "history"
		tradePane.Visible = trade ~= nil
		donePane.Visible = trade == nil and done ~= nil
		playersTab.BackgroundColor3 = if tab == "players" then Colors.blue else Colors.grey
		historyTab.BackgroundColor3 = if tab == "history" then Colors.blue else Colors.grey
		if trade then
			local items = State.feature("items")
			if info ~= builtTrade or State.meta ~= builtMeta or items ~= builtItems then
				builtTrade, builtMeta, builtItems = info, State.meta, items
				refreshTrade(trade)
			end
			tickTrade(trade)
		elseif lobby then
			refreshStatus(info)
			if tab == "players" then
				refreshPlayers(info)
			else
				refreshHistory()
			end
		end
	end

	playersTab.Activated:Connect(function()
		tab = "players"
		refresh()
	end)
	historyTab.Activated:Connect(function()
		tab = "history"
		refresh()
	end)
	doneButton.Activated:Connect(function()
		done = nil
		refresh()
	end)
	-- A result nobody dismissed should not be the first thing the window shows next time.
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.frame.Visible then
			done = nil
		end
	end)

	ctx.on("tradeDone", function(result)
		-- With the window closed the server's toast has already said it.
		if not window.frame.Visible or typeof(result) ~= "table" then
			return
		end
		done = result
		doneWith.Text = `with {result.name} (@{result.user})`
		doneGave.Text = `YOU GAVE:  {sentence(result.gave)}`
		doneGot.Text = `YOU GOT:  {sentence(result.got)}`
		refresh()
	end)

	------------------------------------------------------------------------------------------------
	-- The prompt near the top of the screen for a request that came in
	------------------------------------------------------------------------------------------------
	local promptText = UI.text({
		Size = UDim2.new(1, -196, 1, -12),
		Position = UDim2.fromOffset(14, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		MaxSize = 20,
	})
	local promptYes = UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -76, 0.5, 0),
		Size = UDim2.fromOffset(100, 44),
		Text = "ACCEPT",
		BackgroundColor3 = Colors.green,
	})
	local promptNo = UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(60, 44),
		Text = "NO",
		BackgroundColor3 = Colors.red,
	})
	-- Under the toast line (which ends at 218 on the biggest screens), and in front of the windows: one that is
	-- open could otherwise cover half of it. The TRADE window lists the same request itself.
	local prompt = UI.panel({
		Name = "TradeRequest",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 222),
		Size = UDim2.fromOffset(470, 60),
		ZIndex = 20,
		Visible = false,
	}, {
		UI.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.panel, Active = true }, {
			corner(12),
			UI.make("UIStroke", { Thickness = 2, Color = BLACK }),
			promptText,
			promptYes,
			promptNo,
		}),
	})
	-- Under BACK TO CANNON, above the toast line.
	ctx.Hud.onLayout(function(layout)
		prompt.Position = UDim2.new(0.5, 0, 0, (layout.top + 104) * layout.s)
	end)
	local promptFrom = nil -- the user id of the player the prompt is about

	local function refreshPrompt(info)
		local request = (info.requests or {})[1]
		local left = if request then request.expires - State.now() else 0
		prompt.Visible = left > 0
			and info.trade == nil
			and not window.frame.Visible
			and State.get("Place", "plot") == "market"
		if prompt.Visible then
			promptFrom = request.id
			promptText.Text = `🤝 {request.name} wants to trade  ({math.ceil(left)}s)`
		end
	end
	promptYes.Activated:Connect(function()
		act("tradeAccept", promptFrom)
	end)
	promptNo.Activated:Connect(function()
		act("tradeDecline", promptFrom)
	end)

	------------------------------------------------------------------------------------------------
	-- Wiring
	------------------------------------------------------------------------------------------------
	ctx.Windows.register("TRADE", window, refresh)
	ctx.Hud.addMenuButton("TRADE", Color3.fromRGB(235, 100, 160), 12, window.toggle, "market")
	-- "!" while somebody is asking, or while a trade is waiting behind a closed window.
	ctx.flag("TRADE", function(): boolean
		local info = State.feature("trade")
		return #(info.requests or {}) > 0 or (info.trade ~= nil and not window.frame.Visible)
	end)

	-- A trade that starts opens the window by itself, for the player who asked as well.
	local trading = false
	State.onChange(function()
		local info = State.feature("trade")
		local started = info.trade ~= nil
		if started and not trading then
			done = nil
			window.open()
		end
		trading = started
		refreshPrompt(info)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			refreshPrompt(State.feature("trade"))
			if window.frame.Visible then
				refresh()
			end
		end
	end)
end

return Trading
