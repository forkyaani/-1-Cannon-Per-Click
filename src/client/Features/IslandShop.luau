-- The island shops, client side: the ISLAND SHOP window, opened by the stall on a world's island (its prompt
-- carries Window = "ISLAND SHOP"). Three rows: the world's ammo, the day's powerup and the Boss Chest, each
-- with its price in coins; and, on the islands that sell it, the Enchantment Key for gems. What is sold, the prices and the limits come from the shared module, which is
-- what the server sells from; the server checks everything again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("IslandShop"))

local ROW_HEIGHT = 92
local HEADER_HEIGHT = 50
local ROW_TITLES = { ammo = "AMMO", powerup = "TODAY'S POWERUP", chest = "BOSS CHEST", key = "ENCHANTMENT KEY", shiny = "SHINY ENCHANTMENT KEY" }
local ROW_NOTES = {
	ammo = "Yours to keep: load it in the AMMO window",
	powerup = "One a day on every island. It goes to your BACKPACK",
	chest = "One a day. Open it from your BACKPACK",
	key = "For gems, as many as you like. Use it at the Enchanting Table",
	shiny = "For gems, as many as you like. Use it at the Enchanting Table",
}
local CURRENCY_ICON = { coins = "💰", diamonds = "💎" }
local CURRENCY_ATTRIBUTE = { coins = "Coins", diamonds = "Diamonds" }
local CHEST_LOOT = "crate:" .. Shop.Chest -- the Boss Chest's table in the loot viewer

local function start(ctx)
	local Config, Format, Items, State, UI = ctx.Config, ctx.Format, ctx.Items, ctx.State, ctx.UI
	local Colors = UI.Colors
	local left = Enum.TextXAlignment.Left

	local window = UI.window(Shop.WINDOW, 640, 470)
	local title = UI.text({ Size = UDim2.new(1, -8, 0, 26), TextColor3 = Colors.gold, Parent = window.body })
	local stockLine = UI.text({
		Size = UDim2.new(1, -8, 0, 18),
		Position = UDim2.fromOffset(0, 28),
		TextColor3 = Colors.text,
		MaxSize = 15,
		Parent = window.body,
	})
	local list = UI.scroll(window.body, { Position = UDim2.fromOffset(0, HEADER_HEIGHT), Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT) })

	-- The island the window is showing: the one the player stands on.
	local function island(): number
		local index = State.get("Island", 0)
		return if State.get("Place", "plot") == "island" and Config.Worlds[index] then index else 0
	end

	local rows = {}
	for order, kind in Shop.ROWS do
		local row = UI.row(list, ROW_HEIGHT, order)
		-- What the row is, in small letters over the item's own name.
		row.kind = UI.text({
			Size = UDim2.new(1, -212, 0, 16),
			Position = UDim2.fromOffset(58, 5),
			TextXAlignment = left,
			TextColor3 = Colors.gold,
			MaxSize = 14,
			Text = ROW_TITLES[kind],
			Parent = row.frame,
		})
		row.title.Position = UDim2.fromOffset(58, 21)
		row.sub.Position = UDim2.fromOffset(58, 48)
		row.sub.Size = UDim2.new(1, -212, 0, ROW_HEIGHT - 54)
		row.button.Activated:Connect(function()
			local index = island()
			if index > 0 then
				ctx.act("islandBuy", { island = index, kind = kind })
			end
		end)
		rows[kind] = row
	end
	-- The chest holds random rewards: its row says where the odds are, and a small button opens them.
	local inside = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 8),
		Size = UDim2.fromOffset(120, 34),
		Text = "WHAT'S INSIDE?",
		BackgroundColor3 = Colors.blue,
		Parent = rows.chest.frame,
	})
	inside.Activated:Connect(function()
		ctx.Loot.open(CHEST_LOOT)
	end)
	rows.chest.title.Size = UDim2.new(1, -340, 0, 26)
	rows.chest.kind.Size = UDim2.new(1, -340, 0, 16)

	local function setButton(button: TextButton, text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	local function refresh()
		local index = island()
		local world = Config.Worlds[index]
		if not world then
			title.Text = "Visit a world's island to shop here"
			stockLine.Text = "Islands open from the WORLDS window"
			for _, row in rows do
				row.frame.Visible = false
			end
			return
		end
		title.Text = `{string.upper(world.name)} ISLAND SHOP`
		local day = Config.dayNumber(State.now())
		local stock = Shop.stock(index, day)
		local bought = State.feature("islandShop")
		local counts = State.feature("items")
		local cleared = State.get("Cleared", 0)
		for kind, row in rows do
			local id = stock[kind]
			local item = id and Items.get(id) :: any
			local cost = id and Shop.price(kind, id, index, cleared)
			row.frame.Visible = item ~= nil and cost ~= nil
			if not item or not cost then
				continue
			end
			row.icon.BackgroundColor3 = item.color or Colors.white
			row.setIcon(id)
			row.title.Text = item.name
			row.title.TextColor3 = Config.RarityColors[item.rarity] or Colors.white
			row.sub.Text = `{item.desc or ""}\n{ROW_NOTES[kind]}`
			local currency = Shop.currency(kind)
			local balance = State.get(CURRENCY_ATTRIBUTE[currency], 0)
			local price = `{Format.abbreviate(cost)} {CURRENCY_ICON[currency]}`
			if kind == "ammo" and (counts[id] or 0) > 0 then
				setButton(row.button, "OWNED", Colors.grey)
			elseif Shop.soldOut(kind, id, index, bought, day) then
				setButton(row.button, "SOLD OUT\nback tomorrow", Colors.grey)
			else
				setButton(row.button, `BUY\n{price}`, if balance >= cost then Colors.green else Colors.grey)
			end
		end
	end

	ctx.Windows.register(Shop.WINDOW, window, refresh)

	-- The countdown to new stock, while the window is open. (Windows.tick only knows the core's own windows.)
	task.spawn(function()
		while true do
			if window.frame.Visible and island() > 0 then
				local now = State.now()
				local nextDay = (Config.dayNumber(now) + 1) * 86_400
				stockLine.Text = `New stock in {Format.duration(nextDay - now)}  •  prices in coins, keys in gems`
			end
			task.wait(0.5)
		end
	end)

	-- Walking off the island (the portal home, the travel button) closes its shop.
	State.onChange(function()
		if window.frame.Visible and island() == 0 then
			window.close()
		end
	end)
end

return { start = start }
