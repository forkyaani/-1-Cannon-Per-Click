-- Towers, client side: the TOWER window that a pad's prompt opens, and what the player reads on their own
-- pads. The server owns the pads and the towers (docs/DEFENSE_SPEC.md 5 and 6); this shows State.meta.pads,
-- State.meta.towers and State.meta.padPrice, and asks with buyPad, buildTower, upgradeTower and sellTower.
--   * A pad that is not the player's yet: its price and BUY PAD.
--   * An empty pad: every kind of tower as a row (what it does, its cost, or what unlocks it).
--   * A tower: its numbers now and at the next level, UPGRADE +1 / +10 / MAX with what each press costs, SELL
--     with the refund, and its range drawn on the ground for as long as the window is open.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Layout"))

local NAME = "TOWER" -- the window's title, and the name it opens by
local MAX_LEVELS = 1000 -- what the server takes for "as many as the coins allow"
local SELL_CONFIRM_SECONDS = 3 -- SELL has to be pressed twice within this: a slip of the thumb costs half a tower
local SIGN_DISTANCE = 110 -- studs from which a pad's text can be read
local KIND_ROW = 84
local RETRY_SECONDS = 1 -- how often the pads are looked for again while the plot has not loaded

local Feature = {}

function Feature.start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local player = Players.LocalPlayer
	local kinds = Config.Towers
	if not kinds then
		return -- no tower table in Config: there is nothing to build
	end
	local left, right = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right

	------------------------------------------------------------------------------------------------
	-- What the server says, and what things cost
	------------------------------------------------------------------------------------------------
	local function owns(pad: number): boolean
		return table.find(State.meta.pads or {}, pad) ~= nil
	end

	-- The tower on a pad: { kind, level }, or nil.
	local function towerOn(pad: number)
		local tower = (State.meta.towers or {})[tostring(pad)]
		return if typeof(tower) == "table" and kinds[tower.kind] then tower else nil
	end

	local function towerCount(): number
		local count = 0
		for _ in State.meta.towers or {} do
			count += 1
		end
		return count
	end

	local function padPrice(): number
		return State.meta.padPrice or Config.padPrice(#(State.meta.pads or {}) + 1)
	end

	-- The kinds in shop order.
	local function kindOrder(): { string }
		if Config.TowerOrder then
			return Config.TowerOrder
		end
		local order = {}
		for kind in kinds do
			table.insert(order, kind)
		end
		table.sort(order, function(a, b)
			return if kinds[a].cost == kinds[b].cost then a < b else kinds[a].cost < kinds[b].cost
		end)
		return order
	end

	-- 2.5 stays 2.5; big numbers get their suffix.
	local function short(value: number): string
		if value >= 100 or value % 1 == 0 then
			return Format.abbreviate(value)
		end
		return string.format("%.1f", value)
	end

	local function percent(share: number): string
		return `{math.floor(share * 100 + 0.5)}%`
	end

	-- One shot's damage with the player's multipliers in it, as the server deals it before features.
	local function damageAt(kind: string, level: number): number
		return Config.towerDamage(kind, level) * State.get("PowerMult", 1)
	end

	-- What makes a kind special, in a few words.
	local function specials(def): string
		local parts = {}
		if def.splash then
			table.insert(parts, `Splash {short(def.splash)}`)
		end
		if def.slow then
			table.insert(parts, `Slows {percent(def.slow)} for {short(def.slowSeconds or 0)}s`)
		end
		if def.burn then
			table.insert(parts, `Burns {percent(def.burn)}/s for {short(def.burnSeconds or 0)}s`)
		end
		if def.chain then
			table.insert(parts, `Jumps to {def.chain} more`)
		end
		if def.boss then
			table.insert(parts, `x{short(def.boss)} to bosses`)
		end
		return table.concat(parts, "  •  ")
	end

	-- What the player's bonuses do to every tower (the server's `towerRate` and `towerRange`: mastery,
	-- enchants, powerups). The window's rate and range and the ring on the ground are the real ones.
	local function rateMult(): number
		return State.get("TowerRate", 1)
	end
	local function rangeMult(): number
		return State.get("TowerRange", 1)
	end

	local function facts(def): string
		local rate, range = def.rate * rateMult(), def.range * rangeMult()
		local text = `{short(rate)} {if rate == 1 then "shot" else "shots"}/s  •  range {short(range)}`
		local special = specials(def)
		return if special ~= "" then `{text}  •  {special}` else text
	end

	-- "Iron Gatling": the style of the tower's tier in front of its kind.
	local function towerName(def, level: number): string
		local tier = Config.Cannons[Config.towerTier(level)]
		return if tier then `{tier.short} {def.name}` else def.name
	end

	-- What a press on an upgrade button gets with the coins there are: how many levels, and for how much.
	local function reach(kind: string, level: number, levels: number, coins: number): (number, number)
		local bought, spent = 0, 0
		while bought < levels do
			-- UpgradeCost: what the server multiplies upgrade prices by for this player (a discount from a feature).
			local cost = Config.towerUpgradeCost(kind, level + bought, State.get("UpgradeCost", 1))
			if not cost or spent + cost > coins then
				break
			end
			spent += cost
			bought += 1
		end
		return bought, spent
	end

	------------------------------------------------------------------------------------------------
	-- The window
	------------------------------------------------------------------------------------------------
	local window = UI.window(NAME, 640, 480)
	local padLabel = UI.label({
		Size = UDim2.new(0.6, 0, 0, 30),
		Font = UI.TITLE_FONT,
		TextSize = 26,
		TextXAlignment = left,
		Parent = window.body,
	})
	local coinLabel = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 0, 30),
		TextSize = 26,
		TextColor3 = Colors.gold,
		TextXAlignment = right,
		Parent = window.body,
	})
	local function page(): Frame
		return UI.make("Frame", {
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 1, -38),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = window.body,
		})
	end

	local selected = 1 -- the pad the window is about

	-- Page 1: the pad is for sale.
	local salePage = page()
	UI.label({
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 40),
		Font = UI.TITLE_FONT,
		TextSize = 36,
		Stroke = 3,
		Text = "THIS PAD IS FOR SALE",
		Parent = salePage,
	})
	UI.label({
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 56),
		TextSize = 24,
		TextColor3 = Colors.text,
		TextWrapped = true,
		Text = "Buy it, then build a cannon tower on it.\nEvery pad costs more than the last.",
		Parent = salePage,
	})
	local buyPadButton = UI.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 156),
		Size = UDim2.fromOffset(360, 104),
		Parent = salePage,
	})
	local padsLabel = UI.label({
		Position = UDim2.fromOffset(0, 278),
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 24,
		TextColor3 = Colors.text,
		Parent = salePage,
	})
	buyPadButton.Activated:Connect(function()
		ctx.act("buyPad", selected)
	end)

	-- Page 2: an empty pad. One row per kind of tower.
	local buildPage = page()
	local kindList = UI.scroll(buildPage)
	local kindRows = {} -- [kind] = { row, stats }

	-- A row is added the first time a kind is seen, so kinds a feature defines after start-up still show.
	local function ensureKindRows()
		for index, kind in kindOrder() do
			local def = kinds[kind]
			if def and not kindRows[kind] then
				local row = UI.row(kindList, KIND_ROW, index)
				row.icon.BackgroundColor3 = def.color or Colors.gold
				row.setIcon("tower_" .. kind)
				row.title.Text = def.name
				local stats = UI.text({
					Size = UDim2.new(1, -212, 0, 20),
					Position = UDim2.fromOffset(58, 33),
					TextXAlignment = left,
					TextColor3 = Colors.gold,
					MaxSize = 15,
					Parent = row.frame,
				})
				row.sub.Position = UDim2.fromOffset(58, 56)
				row.sub.Size = UDim2.new(1, -212, 0, 20)
				row.button.Activated:Connect(function()
					ctx.act("buildTower", { pad = selected, kind = kind })
				end)
				kindRows[kind] = { row = row, stats = stats }
			end
		end
	end

	-- Page 3: a tower.
	local towerPage = page()
	local nameLabel = UI.label({
		Size = UDim2.new(1, -170, 0, 38),
		Font = UI.TITLE_FONT,
		TextSize = 34,
		Stroke = 3,
		TextXAlignment = left,
		Parent = towerPage,
	})
	local levelLabel = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(170, 38),
		Font = UI.TITLE_FONT,
		TextSize = 34,
		Stroke = 3,
		TextColor3 = Colors.gold,
		TextXAlignment = right,
		Parent = towerPage,
	})
	-- The way to the AMMO window from where the player looks at a cannon: its menu button is easy to miss.
	-- Shown only when the Ammo feature has registered its window (it may load after this one).
	local AMMO_BUTTON = Vector2.new(124, 34)
	local ammoButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 38),
		Size = UDim2.fromOffset(AMMO_BUTTON.X, AMMO_BUTTON.Y),
		Text = "🔥 AMMO",
		TextSize = 20,
		BackgroundColor3 = Color3.fromRGB(225, 95, 45),
		Visible = false,
		Parent = towerPage,
	})
	ammoButton.Activated:Connect(function()
		local ammoWindow = ctx.Windows.byName.AMMO
		if ammoWindow then
			ammoWindow.open()
		end
	end)
	local descLabel = UI.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, -AMMO_BUTTON.X - 8, 0, 26),
		TextSize = 24,
		TextColor3 = Colors.text,
		TextXAlignment = left,
		Parent = towerPage,
	})
	-- Now against the next level, as a small table on a dark inset.
	local statsPanel = UI.make("Frame", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 172),
		BackgroundColor3 = Colors.dark,
		BorderSizePixel = 0,
		Parent = towerPage,
	}, { UI.corner(14) })
	local COLUMNS = { 250, 420 } -- where the NOW and NEXT LEVEL columns start
	local function cell(x: number, y: number, width: number, props)
		props.Position = UDim2.fromOffset(x, y)
		props.Size = UDim2.fromOffset(width, 30)
		props.TextXAlignment = props.TextXAlignment or left
		props.Parent = statsPanel
		return UI.label(props)
	end
	cell(COLUMNS[1], 8, 160, { Text = "NOW", TextSize = 24, TextColor3 = Colors.text })
	cell(COLUMNS[2], 8, 180, { Text = "NEXT LEVEL", TextSize = 24, TextColor3 = Colors.green })
	cell(16, 44, 230, { Text = "Damage a shot", TextSize = 24 })
	cell(16, 82, 230, { Text = "Damage a second", TextSize = 24 })
	local damageNow = cell(COLUMNS[1], 44, 160, { TextSize = 28 })
	local damageNext = cell(COLUMNS[2], 44, 180, { TextSize = 28, TextColor3 = Colors.green })
	local dpsNow = cell(COLUMNS[1], 82, 160, { TextSize = 28 })
	local dpsNext = cell(COLUMNS[2], 82, 180, { TextSize = 28, TextColor3 = Colors.green })
	local factsLabel = UI.text({
		Position = UDim2.fromOffset(16, 122),
		Size = UDim2.new(1, -32, 0, 40),
		TextXAlignment = left,
		TextColor3 = Colors.gold,
		TextWrapped = true,
		MaxSize = 20,
		Parent = statsPanel,
	})

	local BUTTON = Vector2.new(146, 88)
	local function actionButton(index: number): TextButton
		return UI.button({
			Position = UDim2.new(0, (index - 1) * (BUTTON.X + 10), 1, -BUTTON.Y - 8),
			Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			Parent = towerPage,
		})
	end
	local upgradeButton = actionButton(1)
	local upgradeTenButton = actionButton(2)
	local upgradeMaxButton = actionButton(3)
	local sellButton = actionButton(4)

	for levels, button in { [1] = upgradeButton, [10] = upgradeTenButton, [MAX_LEVELS] = upgradeMaxButton } do
		button.Activated:Connect(function()
			ctx.act("upgradeTower", { pad = selected, levels = levels })
		end)
	end

	local sellArmed = { pad = 0, at = -math.huge } -- the first of the two presses that sell
	local function sellIsArmed(): boolean
		return sellArmed.pad == selected and os.clock() - sellArmed.at <= SELL_CONFIRM_SECONDS
	end

	------------------------------------------------------------------------------------------------
	-- The range on the ground: a flat glowing disc under the tower the window is about.
	------------------------------------------------------------------------------------------------
	local ring = UI.make("Part", {
		Name = "TowerRange",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2, 2),
		Material = Enum.Material.Neon,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	})

	local function showRange()
		local tower = if window.frame.Visible then towerOn(selected) else nil
		local slot = State.get("Slot", nil)
		if not tower or not slot then
			ring.Transparency = 1
			return
		end
		local def = kinds[tower.kind]
		local range = def.range * rangeMult()
		ring.Size = Vector3.new(0.2, range * 2, range * 2)
		-- A cylinder lies along its X axis: stood on end it is a disc.
		ring.CFrame = CFrame.new(Layout.padPosition(slot, selected) + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = def.color or Colors.gold
		ring.Transparency = 0.78
	end
	window.frame:GetPropertyChangedSignal("Visible"):Connect(showRange)

	------------------------------------------------------------------------------------------------
	local function setButton(button: TextButton, text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	local function refresh()
		local pad = selected
		local coins = State.get("Coins", 0)
		local tower = towerOn(pad)
		local owned = owns(pad)
		padLabel.Text = `PAD {pad} OF {Layout.PAD_COUNT}`
		coinLabel.Text = `★ {Format.abbreviate(coins)}`
		salePage.Visible = tower == nil and not owned
		buildPage.Visible = tower == nil and owned
		towerPage.Visible = tower ~= nil
		ammoButton.Visible = ctx.Windows.byName.AMMO ~= nil
		showRange()

		if tower then
			local def = kinds[tower.kind]
			local kind, level = tower.kind, tower.level
			nameLabel.Text = string.upper(towerName(def, level))
			levelLabel.Text = `LEVEL {level}`
			descLabel.Text = def.desc or ""
			local now, nextLevel = damageAt(kind, level), damageAt(kind, level + 1)
			damageNow.Text = short(now)
			damageNext.Text = short(nextLevel)
			dpsNow.Text = short(now * def.rate * rateMult())
			dpsNext.Text = short(nextLevel * def.rate * rateMult())
			-- Every ten levels a tower moves up a tier: a new look and a new name.
			local nextName = towerName(def, level + 1)
			factsLabel.Text = if nextName ~= towerName(def, level)
				then `{facts(def)}\nNext level it becomes a {nextName}!`
				else facts(def)

			local one = Config.towerUpgradeCost(kind, level, State.get("UpgradeCost", 1))
			setButton(upgradeButton, `UPGRADE\n★ {Format.abbreviate(one)}`, if coins >= one then Colors.green else Colors.grey)
			-- +10 and MAX buy as many levels as the coins reach, so each says where its press lands.
			local ten, tenCost = reach(kind, level, 10, coins)
			if ten >= 2 then
				setButton(upgradeTenButton, `+{ten} LEVELS\n★ {Format.abbreviate(tenCost)}`, Colors.blue)
			else
				local _, full = reach(kind, level, 10, math.huge)
				setButton(upgradeTenButton, `+10 LEVELS\n★ {Format.abbreviate(full)}`, Colors.grey)
			end
			local most, mostCost = reach(kind, level, MAX_LEVELS, coins)
			if most >= 2 then
				setButton(upgradeMaxButton, `MAX +{most}\n★ {Format.abbreviate(mostCost)}`, Colors.blue)
			else
				setButton(upgradeMaxButton, "MAX", Colors.grey)
			end

			-- A discount on upgrades is taken off the refund too, as the server does.
			local discount = math.min(1, State.get("UpgradeCost", 1))
			local refund = math.floor(Config.towerInvested(kind, level) * ((Config.Defense or {}).sellRefund or 0.5) * discount)
			if towerCount() <= 1 then
				setButton(sellButton, "YOUR LAST\nTOWER", Colors.grey)
			elseif sellIsArmed() then
				setButton(sellButton, `SURE? TAP\n+★ {Format.abbreviate(refund)}`, Colors.red)
			else
				setButton(sellButton, `SELL\n+★ {Format.abbreviate(refund)}`, Colors.red)
			end
		elseif owned then
			ensureKindRows()
			local best = State.get("BestCleared", 0)
			for kind, entry in kindRows do
				local def = kinds[kind]
				local row = entry.row
				entry.stats.Text = `{short(damageAt(kind, 1))} damage  •  {facts(def)}`
				if best < (def.unlock or 0) then
					-- Config.waveLabel still says "wave"; the game calls them levels now.
					row.sub.Text = `Clear {(string.gsub(Config.waveLabel(def.unlock), " wave ", " level "))} to unlock`
					row.sub.TextColor3 = Colors.red
					setButton(row.button, "🔒 LOCKED", Colors.grey)
				else
					row.sub.Text = def.desc or ""
					row.sub.TextColor3 = Colors.text
					setButton(row.button, `BUILD\n★ {Format.abbreviate(def.cost)}`, if coins >= def.cost then Colors.green else Colors.grey)
				end
			end
		else
			local price = padPrice()
			setButton(buyPadButton, `BUY PAD\n★ {Format.abbreviate(price)}`, if coins >= price then Colors.green else Colors.grey)
			padsLabel.Text = `You own {#(State.meta.pads or {})} of {Layout.PAD_COUNT} pads`
		end
	end

	sellButton.Activated:Connect(function()
		if not towerOn(selected) or towerCount() <= 1 then
			return
		end
		if sellIsArmed() then
			sellArmed.at = -math.huge
			ctx.act("sellTower", selected)
			return
		end
		sellArmed.pad, sellArmed.at = selected, os.clock()
		refresh()
		-- The question goes away by itself.
		task.delay(SELL_CONFIRM_SECONDS + 0.1, function()
			if window.frame.Visible then
				refresh()
			end
		end)
	end)

	ctx.Windows.register(NAME, window, refresh)

	------------------------------------------------------------------------------------------------
	-- The player's own pads. Each one gets a sign only this player sees ("FOR SALE" with the next price, or the
	-- tower's name and level), and its prompt says what a press will do.
	------------------------------------------------------------------------------------------------
	local playerGui = player:WaitForChild("PlayerGui")
	local signs = {} -- [pad] = { gui, title, detail }

	local function signFor(pad: number, part: BasePart)
		local sign = signs[pad]
		if not sign then
			local title = UI.make("TextLabel", {
				Size = UDim2.fromScale(1, 0.55),
				BackgroundTransparency = 1,
				Font = UI.TITLE_FONT,
				TextScaled = true,
				TextColor3 = Colors.white,
				TextStrokeColor3 = Colors.ink,
				TextStrokeTransparency = 0,
			})
			local detail = UI.make("TextLabel", {
				Position = UDim2.fromScale(0, 0.55),
				Size = UDim2.fromScale(1, 0.45),
				BackgroundTransparency = 1,
				Font = UI.FONT,
				TextScaled = true,
				TextColor3 = Colors.text,
				TextStrokeColor3 = Colors.ink,
				TextStrokeTransparency = 0,
			})
			local gui = UI.make("BillboardGui", {
				Name = "PadSign",
				Size = UDim2.fromScale(9, 2.6), -- in studs, so it shrinks with distance like a real sign
				LightInfluence = 0,
				MaxDistance = SIGN_DISTANCE,
				ResetOnSpawn = false,
				Parent = playerGui,
			}, { title, detail })
			sign = { gui = gui, title = title, detail = detail }
			signs[pad] = sign
		end
		sign.gui.Adornee = part
		return sign
	end

	local shownMeta, shownAfford, complete = nil, nil, false

	local function refreshPads()
		local meta = State.meta
		local price = padPrice()
		local affordable = State.get("Coins", 0) >= price
		-- Coins change with every kill; the pads only change with the Meta table or when the price comes in reach.
		if complete and meta == shownMeta and affordable == shownAfford then
			return
		end
		local slot = State.get("Slot", nil)
		local all = workspace:FindFirstChild("Plots")
		local plot = slot and all and all:FindFirstChild("Plot_" .. slot)
		local pads = plot and plot:FindFirstChild("Pads")
		if not pads then
			complete = false
			return
		end
		local towers = plot:FindFirstChild("Towers")
		local found = 0
		for pad = 1, Layout.PAD_COUNT do
			local part = pads:FindFirstChild("Pad_" .. pad)
			if not part or not part:IsA("BasePart") then
				continue
			end
			found += 1
			local sign = signFor(pad, part)
			local tower = towerOn(pad)
			local action, object
			local height = 4.5
			if tower then
				local def = kinds[tower.kind]
				sign.title.Text = string.upper(towerName(def, tower.level))
				sign.title.TextColor3 = Colors.white
				sign.detail.Text = `Level {tower.level}`
				sign.detail.TextColor3 = Colors.gold
				action, object = "Upgrade", def.name
				-- Over the tower's head, once its model has arrived.
				local model = towers and towers:FindFirstChild("Tower_" .. pad)
				if model and model:IsA("Model") then
					height = model:GetExtentsSize().Y + 2.5
				else
					found -= 1 -- looked at again when the model is there
				end
			elseif owns(pad) then
				sign.title.Text = "EMPTY PAD"
				sign.title.TextColor3 = Colors.white
				sign.detail.Text = "Build a tower"
				sign.detail.TextColor3 = Colors.green
				action, object = "Build", "tower"
			else
				sign.title.Text = "FOR SALE"
				sign.title.TextColor3 = Colors.gold
				sign.detail.Text = `★ {Format.abbreviate(price)}`
				sign.detail.TextColor3 = if affordable then Colors.green else Colors.text
				action, object = "Buy", "pad"
			end
			sign.gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.ActionText = action
				prompt.ObjectText = object
			end
		end
		complete = found == Layout.PAD_COUNT
		shownMeta, shownAfford = meta, affordable
	end
	State.onChange(refreshPads)
	-- The plot may still be arriving when this starts, and a tower's model arrives after the news of it.
	task.spawn(function()
		while true do
			refreshPads()
			task.wait(RETRY_SECONDS)
		end
	end)

	------------------------------------------------------------------------------------------------
	-- Prompts: a pad of the player's own opens the window; a pad on somebody else's plot is not offered at all.
	------------------------------------------------------------------------------------------------
	local function padOf(prompt: ProximityPrompt): (number?, boolean)
		local pad, slot = prompt:GetAttribute("Pad"), prompt:GetAttribute("Slot")
		if typeof(pad) ~= "number" or not Layout.PADS[pad] then
			return nil, false
		end
		return pad, slot == State.get("Slot", nil)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		local pad, mine = padOf(prompt)
		if who ~= player or not pad or not mine then
			return
		end
		selected = pad
		window.open()
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local pad, mine = padOf(prompt)
		if pad and not mine and State.get("Slot", nil) ~= nil then
			prompt.Enabled = false
		end
	end)
end

return Feature
