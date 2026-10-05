-- Cannon ammo, client side: the AMMO window (what each slot fires, every ammo type, the forge's BUY buttons)
-- and the look of the player's own mini cannon shots. The ammo types live in the shared Ammo module.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ammo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Ammo"))

local ICONS = { coins = "💰", diamonds = "💎" }
local BALANCE_ATTRIBUTE = { coins = "Coins", diamonds = "Diamonds" }
local MUTED = Color3.fromRGB(140, 145, 158) -- the name of an ammo the player does not own
local UNOWNED_ORDER = 100 -- added to a row's order, so owned ammo is listed first
local LIST_TOP = 86
local ROW_HEIGHT = 64
local BUTTON_SIZE = Vector2.new(98, 46)
local BUTTON_GAP = 6
local SIDE = 10 -- between the buttons and the right edge of their row
-- Every row keeps room for one button per slot on its right, whichever buttons it shows.
local BUTTONS_WIDTH = #Ammo.Slots * (BUTTON_SIZE.X + BUTTON_GAP) - BUTTON_GAP
local TEXT_LEFT = 58
local TEXT_TRIM = TEXT_LEFT + BUTTONS_WIDTH + SIDE + 4

local function start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local left = Enum.TextXAlignment.Left

	local function setButton(button: TextButton, text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	local window = UI.window("AMMO", 640, 470)

	-- Top: what each slot fires.
	local panels = {}
	for index, slot in Ammo.Slots do
		local frame = UI.make("Frame", {
			Size = UDim2.new(0.5, -4, 0, 58),
			Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 4, 0, 0),
			BackgroundColor3 = Colors.dark,
			Parent = window.body,
		}, { UI.corner(10) })
		UI.text({
			Size = UDim2.new(1, -58, 0, 16),
			Position = UDim2.fromOffset(50, 4),
			TextXAlignment = left,
			TextColor3 = Colors.gold,
			MaxSize = 14,
			Text = `{slot.name}  •  {slot.hint}`,
			Parent = frame,
		})
		panels[slot.key] = {
			dot = UI.make("Frame", {
				Size = UDim2.fromOffset(30, 30),
				Position = UDim2.fromOffset(10, 14),
				Parent = frame,
			}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(2) }),
			name = UI.text({
				Size = UDim2.new(1, -58, 0, 20),
				Position = UDim2.fromOffset(50, 20),
				TextXAlignment = left,
				Parent = frame,
			}),
			effect = UI.text({
				Size = UDim2.new(1, -58, 0, 15),
				Position = UDim2.fromOffset(50, 41),
				TextXAlignment = left,
				TextColor3 = Colors.text,
				MaxSize = 13,
				Parent = frame,
			}),
		}
	end
	UI.text({
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 63),
		TextColor3 = Colors.text,
		MaxSize = 14,
		Text = `Bosses can drop rare ammo (one roll every {Ammo.DROP_COOLDOWN}s). Own one of an ammo to load it in both slots.`,
		Parent = window.body,
	})

	-- One row per ammo type: icon, name and count over rarity, effect and where it comes from. On the right,
	-- a LOAD button per slot once it is owned; before that BUY if the forge sells it, or a note if it does not.
	local list = UI.scroll(window.body, { Position = UDim2.fromOffset(0, LIST_TOP), Size = UDim2.new(1, 0, 1, -LIST_TOP) })
	local rows = {}
	for _, def in Ammo.Types do
		local frame = UI.make("Frame", { Size = UDim2.new(1, -10, 0, ROW_HEIGHT), Parent = list }, { UI.corner(10) })
		local row = {
			frame = frame,
			icon = UI.make("Frame", {
				Size = UDim2.fromOffset(36, 36),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				BackgroundColor3 = def.color,
				Parent = frame,
			}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(2) }),
			title = UI.text({
				Size = UDim2.new(1, -TEXT_TRIM, 0, 24),
				Position = UDim2.fromOffset(TEXT_LEFT, 5),
				TextXAlignment = left,
				Parent = frame,
			}),
			equip = {},
			buy = nil :: TextButton?,
			locked = nil :: TextLabel?,
		}
		UI.text({
			Size = UDim2.new(1, -TEXT_TRIM, 0, ROW_HEIGHT - 34),
			Position = UDim2.fromOffset(TEXT_LEFT, 30),
			TextXAlignment = left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = Colors.text,
			MaxSize = 14,
			Text = `{def.rarity}  •  {def.desc}\n{def.source}`,
			Parent = frame,
		})
		for index, slot in Ammo.Slots do
			local button = UI.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -SIDE - (#Ammo.Slots - index) * (BUTTON_SIZE.X + BUTTON_GAP), 0.5, 0),
				Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
				Parent = frame,
			})
			button.Activated:Connect(function()
				ctx.act("equipAmmo", { slot = slot.key, id = def.id })
			end)
			row.equip[slot.key] = button
		end
		if def.price then
			local buy = UI.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -SIDE, 0.5, 0),
				Size = UDim2.fromOffset(BUTTONS_WIDTH, BUTTON_SIZE.Y),
				Parent = frame,
			})
			buy.Activated:Connect(function()
				ctx.act("buyAmmo", def.id)
			end)
			row.buy = buy
		elseif not def.free then
			row.locked = UI.text({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -SIDE, 0.5, 0),
				Size = UDim2.fromOffset(BUTTONS_WIDTH, BUTTON_SIZE.Y),
				TextColor3 = MUTED,
				MaxSize = 18,
				Text = "🔒 BOSS DROP ONLY",
				Parent = frame,
			})
		end
		rows[def.id] = row
	end

	-- Rows are put in order (owned first) only when the window opens, so a row never slides under a finger:
	-- right after a BUY, the next row's BUY button would otherwise move into its place.
	local reorder = true
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		reorder = true
	end)

	local function refresh()
		local choice, counts = State.feature("ammo"), State.feature("items")
		local arrange = reorder
		reorder = false
		local loaded = {}
		for _, slot in Ammo.Slots do
			local def = Ammo.loaded(choice, counts, slot.key)
			local panel = panels[slot.key]
			loaded[slot.key] = def
			panel.dot.BackgroundColor3 = def.color
			panel.name.Text = def.name
			panel.name.TextColor3 = Config.RarityColors[def.rarity] or Colors.white
			panel.effect.Text = def.desc
		end
		for _, def in Ammo.Types do
			local row = rows[def.id]
			local count = counts[def.id] or 0
			local owned = def.free == true or count > 0
			if arrange then
				row.frame.LayoutOrder = if owned then def.order else UNOWNED_ORDER + def.order
			end
			row.frame.BackgroundColor3 = if owned then Colors.row else Colors.dark
			row.icon.BackgroundTransparency = if owned then 0 else 0.6
			row.title.Text = if count > 0 then `{def.name}  x{count}` else def.name
			row.title.TextColor3 = if owned then Config.RarityColors[def.rarity] or Colors.white else MUTED
			for _, slot in Ammo.Slots do
				local button = row.equip[slot.key]
				local on = loaded[slot.key] == def
				button.Visible = owned
				setButton(button, if on then `{slot.short}\nLOADED` else `LOAD\n{slot.short}`, if on then Colors.green else Colors.blue)
			end
			if row.buy then
				local price = def.price
				local affordable = State.get(BALANCE_ATTRIBUTE[price.currency], 0) >= price.cost
				local text = `BUY  {Format.abbreviate(price.cost)} {ICONS[price.currency]}`
				row.buy.Visible = not owned
				setButton(row.buy, text, if affordable then Colors.green else Colors.grey)
			end
			if row.locked then
				row.locked.Visible = not owned
			end
		end
	end

	ctx.Windows.register("AMMO", window, refresh)
	ctx.Hud.addMenuButton("AMMO", Color3.fromRGB(225, 95, 45), 11, window.toggle)

	-- The mini cannons' shots (the hero shots Effects draws) wear the ammo in their slot. Standard leaves the
	-- mini cannon's own colour and size. Tower shots are drawn by Field in their kind's look.
	local projectile = ctx.Effects.projectile
	local rainbow = false
	local hue = 0
	local lookChoice, lookCounts = nil, nil
	local function applyLook()
		-- State hands out the same table until the server sends a new one, so this is cheap on every change.
		local choice, counts = State.feature("ammo"), State.feature("items")
		if choice == lookChoice and counts == lookCounts then
			return
		end
		lookChoice, lookCounts = choice, counts
		local def = Ammo.loaded(choice, counts, "mini")
		rainbow = def.rainbow == true
		projectile.color = if def.free then nil else def.color
		projectile.size = def.size
	end
	State.onChange(applyLook)
	applyLook()

	-- Rainbow ammo: every shot takes the next colour.
	ctx.Effects.onFire(function()
		if rainbow then
			hue = (hue + 0.09) % 1
			projectile.color = Color3.fromHSV(hue, 0.85, 1)
		end
	end)
end

return { start = start }
