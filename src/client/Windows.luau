-- Pop-up windows: mini cannons, worlds (with the REBIRTH row), shop, game passes, missions, daily rewards and
-- leaderboards.
-- (Eggs have no window: they are hatched at their stands, on the world islands and in the marketplace.)
-- Rows are built once and only their text and colours are refreshed, so buttons never vanish mid-click.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Colors = UI.Colors
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Action")

local Windows = {}

local ICONS = { coins = "💰", diamonds = "💎", candy = "🍬" }
local BALANCE_ATTRIBUTE = { coins = "Coins", diamonds = "Diamonds", candy = "Candy" }

local function balance(currency: string): number
	return State.get(BALANCE_ATTRIBUTE[currency], 0)
end

local function act(name: string, argument: any?)
	actionRemote:FireServer(name, argument)
end

local function setButton(button: TextButton, text: string, color: Color3)
	button.Text = text
	button.BackgroundColor3 = color
end

-- The MINI CANNONS window is a feature of its own: src/client/Features/Minis.luau.

----------------------------------------------------------------------------------------------------
-- Worlds
----------------------------------------------------------------------------------------------------
local worldsWindow = UI.window("WORLDS", 640, 470)
local worldsList = UI.scroll(worldsWindow.body)
local worldRows = {}
-- Each world's row has two buttons: TRAVEL picks the world's levels to fight on the plot, ISLAND takes the
-- player to the world's island (its eggs and shop; src/server/Islands.luau).
local ISLAND_BUTTON_WIDTH = 104
local WORLD_TEXT_TRIM = 212 + ISLAND_BUTTON_WIDTH + 8 -- what the two buttons and the icon take from a row's width
local WORLD_ROW_HEIGHT = 104 -- room for a twist of two lines
for index, world in Config.Worlds do
	-- A row: the world's name, its twist, then the player's progress in it.
	local row = UI.row(worldsList, WORLD_ROW_HEIGHT, index)
	row.icon.BackgroundColor3 = world.floor
	row.setIcon("world_" .. string.lower((string.gsub(world.name, "%s", ""))))
	row.title.Text = `{index}. {world.name}`
	row.title.Size = UDim2.new(1, -WORLD_TEXT_TRIM, 0, 26)
	UI.text({
		Size = UDim2.new(1, -WORLD_TEXT_TRIM, 0, 40),
		Position = UDim2.fromOffset(58, 33),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = Colors.gold,
		MaxSize = 15,
		Text = world.twist,
		Parent = row.frame,
	})
	row.sub.Position = UDim2.fromOffset(58, 76)
	row.sub.Size = UDim2.new(1, -WORLD_TEXT_TRIM, 0, 20)
	row.button.Activated:Connect(function()
		act("travel", index)
	end)
	row.island = UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -150, 0.5, 0),
		Size = UDim2.fromOffset(ISLAND_BUTTON_WIDTH, WORLD_ROW_HEIGHT - 18),
		Parent = row.frame,
	})
	row.island.Activated:Connect(function()
		-- Locked until the world is reached; the server says so too.
		if Config.worldUnlocked(index, State.get("BestCleared", 0)) then
			act("goIsland", index)
			UI.closeWindows()
		end
	end)
	worldRows[index] = row
end

-- The REBIRTH row, above the worlds. Rebirth is a rare prestige (Config.Rebirth): the row says what it gives,
-- what it keeps and what it resets, and its button needs a second, confirming press.
local REBIRTH_HEIGHT = 156
local REBIRTH_CONFIRM_SECONDS = 4 -- how long the button waits for the second press
local rebirthRow = UI.row(worldsList, REBIRTH_HEIGHT, 0)
rebirthRow.icon.BackgroundColor3 = Colors.gold
rebirthRow.setIcon("rebirth")
local rebirthGives = UI.text({
	Size = UDim2.new(1, -212, 0, 20),
	Position = UDim2.fromOffset(58, 33),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Colors.gold,
	MaxSize = 15,
	Parent = rebirthRow.frame,
})
rebirthRow.sub.Position = UDim2.fromOffset(58, 56)
rebirthRow.sub.Size = UDim2.new(1, -212, 0, REBIRTH_HEIGHT - 62)
local rebirthArmedUntil = 0 -- os.clock() until which the next press confirms

-- Whether the player can rebirth now, and the level that has to be cleared for it (nil when none are left).
local function rebirthState(): (boolean, number?)
	local need = Config.rebirthWave(State.get("Rebirths", 0))
	if need > Config.TotalWaves then
		return false, nil
	end
	return State.get("Cleared", 0) >= need, need
end

rebirthRow.button.Activated:Connect(function()
	if not rebirthState() then
		return
	end
	if os.clock() < rebirthArmedUntil then
		rebirthArmedUntil = 0
		act("rebirth", true)
	else
		rebirthArmedUntil = os.clock() + REBIRTH_CONFIRM_SECONDS
		-- The button goes back to REBIRTH by itself when the second press does not come.
		task.delay(REBIRTH_CONFIRM_SECONDS + 0.1, function()
			Windows.refresh()
		end)
	end
	Windows.refresh()
end)

local function refreshRebirth()
	local rebirths = State.get("Rebirths", 0)
	local ready, need = rebirthState()
	local percent = math.floor(Config.Rebirth.damage * 100 + 0.5)
	local now = math.floor((Config.rebirthMult(rebirths) - 1) * 100 + 0.5)
	rebirthRow.title.Text = if rebirths > 0 then `REBIRTH  •  {rebirths} so far (+{now}% damage)` else "REBIRTH"
	rebirthGives.Text = `GIVES: +{percent}% tower damage forever and {Config.Rebirth.gems} gems`
	local keeps = "KEEPS: mini cannons, gems, items, mastery, enchants, story and every unlock"
	local resets = "RESETS: levels, coins, pads and towers. You start again at Earth level 1"
	if not need then
		rebirthRow.sub.Text = "You have taken every rebirth there is."
		setButton(rebirthRow.button, "MAX", Colors.grey)
	elseif not ready then
		local boss = Config.Worlds[Config.worldOf(need)].finalBoss.name
		rebirthRow.sub.Text = `{keeps}\n{resets}\nBeat {boss} ({Config.waveLabel(need)}) to rebirth.`
		setButton(rebirthRow.button, "LOCKED", Colors.grey)
	elseif os.clock() < rebirthArmedUntil then
		rebirthRow.sub.Text = `{keeps}\n{resets}\nPress again to confirm: this cannot be undone.`
		setButton(rebirthRow.button, "SURE?\nPRESS AGAIN", Colors.red)
	else
		rebirthRow.sub.Text = `{keeps}\n{resets}`
		setButton(rebirthRow.button, "REBIRTH", Colors.gold)
	end
end

-- The list is longer than the window, so it opens with the player's own world near the top: one row is left
-- showing above it. With a rebirth to take, it opens at the top, on the REBIRTH row.
worldsWindow.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if worldsWindow.frame.Visible then
		rebirthArmedUntil = 0
		local here = Config.worldOf(State.get("Wave", 1))
		local above = worldRows[math.max(1, here - 1)].frame
		local offset = above.AbsolutePosition.Y - worldsList.AbsolutePosition.Y + worldsList.CanvasPosition.Y
		worldsList.CanvasPosition = Vector2.new(0, if rebirthState() or here <= 2 then 0 else math.max(0, offset))
	end
end)

local function refreshWorlds()
	refreshRebirth()
	local cleared = State.get("Cleared", 0)
	local here = Config.worldOf(State.get("Wave", 1))
	local best = State.get("BestCleared", 0)
	local onIsland = if State.get("Place", "plot") == "island" then State.get("Island", 0) else 0
	for index, world in Config.Worlds do
		local row = worldRows[index]
		-- The island opens when the world is reached for the first time, and stays open after a rebirth.
		if not Config.worldUnlocked(index, best) then
			setButton(row.island, "🔒\nISLAND", Colors.grey)
		elseif index == onIsland then
			setButton(row.island, "ON THIS\nISLAND", Colors.blue)
		else
			setButton(row.island, "🏝️\nISLAND", Colors.gold)
		end
		local first = (index - 1) * Config.WavesPerWorld
		local done = math.clamp(cleared - first, 0, Config.WavesPerWorld)
		if cleared < first then
			row.sub.Text = `Clear {(string.gsub(Config.waveLabel(first), " wave ", " level "))} to unlock`
			setButton(row.button, "LOCKED", Colors.grey)
		else
			row.sub.Text = `{done}/{Config.WavesPerWorld} levels cleared  •  boss: {world.finalBoss.name}`
			if index == here then
				setButton(row.button, "YOU ARE HERE", Colors.blue)
			else
				setButton(row.button, "TRAVEL", Colors.green)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Shop: weekly diamond shop and the Halloween candy shop
----------------------------------------------------------------------------------------------------
local shopWindow = UI.window("SHOP", 640, 450)
local shopList = UI.scroll(shopWindow.body)
local weeklyHeader = UI.header(shopList, 1)
local eventHeader = UI.header(shopList, 100)
local weeklyRows, eventRows = {}, {}

local function shopRow(item, order: number, action: string)
	local row = UI.row(shopList, 70, order)
	row.title.Text = item.name
	row.icon.BackgroundColor3 = if item.pet then Config.Pets[item.pet].color else Colors.gold
	-- A boost, a slot, gems or a backpack item has a picture; a mini cannon keeps its colour.
	row.setIcon(if item.kind == "boost" then item.boost elseif item.kind == "slot" then "slot" elseif item.kind == "diamonds" then "gem" elseif item.kind == "item" then item.item else nil)
	row.button.Activated:Connect(function()
		act(action, item.id)
	end)
	return row
end
do
	local order = 2
	for _, group in { Config.WeeklyFeatured, Config.WeeklyFixed } do
		for _, item in group do
			weeklyRows[item.id] = shopRow(item, order, "buyWeekly")
			order += 1
		end
	end
	for index, item in Config.EventShop do
		eventRows[item.id] = shopRow(item, 100 + index, "buyEvent")
	end
end

local function describe(item, bought: number): string
	local text = item.desc
	if item.pet then
		text ..= `  •  {Format.petPower(Config.Pets[item.pet])}`
	end
	return `{text}\nBought {bought}/{item.limit}`
end

local function refreshShopRow(row, item, bought: number, currency: string)
	row.sub.Text = describe(item, bought)
	if bought >= item.limit then
		setButton(row.button, "SOLD OUT", Colors.grey)
	else
		local affordable = balance(currency) >= item.cost
		setButton(row.button, `BUY\n{Format.abbreviate(item.cost)} {ICONS[currency]}`, if affordable then Colors.green else Colors.grey)
	end
end

local function refreshShop()
	local weekly = State.meta.weekly or {}
	local event = State.meta.event or {}
	local week = weekly.week or Config.weekNumber(State.now())
	local live = {}
	for _, item in Config.weeklyItems(week) do
		live[item.id] = item
	end
	for id, row in weeklyRows do
		row.frame.Visible = live[id] ~= nil
		if live[id] then
			refreshShopRow(row, live[id], (weekly.bought or {})[id] or 0, "diamonds")
		end
	end
	eventHeader.Visible = event.active == true
	for _, item in Config.EventShop do
		local row = eventRows[item.id]
		row.frame.Visible = event.active == true
		refreshShopRow(row, item, (event.bought or {})[item.id] or 0, "candy")
	end
end

----------------------------------------------------------------------------------------------------
-- Store: three tabs. GEMS (gem packs for Robux), ITEMS (backpack items for gems) and PASSES (Robux, one row
-- per entry in Config.Passes). The catalogue of the first two is src/shared/Features/Store.luau.
----------------------------------------------------------------------------------------------------
local Store = require(ReplicatedStorage.Shared:WaitForChild("Features"):WaitForChild("Store"))
local Items = require(ReplicatedStorage.Shared:WaitForChild("Items"))

local STORE_TABS = { "GEMS", "ITEMS", "PASSES" }
local PASS_ICONS = {
	tripleHatch = "pass_triplehatch", tripleLuck = "pass_tripleluck", slots3 = "pass_slots", slots5 = "pass_slots",
	storage500 = "pass_storage", gameSpeed = "pass_speed", hugeStarter = "pass_huge",
}
-- 21000 -> "21,000": prices and pack sizes are shown in full.
local function commas(n: number): string
	local text = tostring(math.floor(n))
	local grouped = string.gsub(string.reverse(text), "(%d%d%d)", "%1,")
	return (string.gsub(string.reverse(grouped), "^,", ""))
end
local STORE_TAB_HEIGHT = 44
local GEM_BLUE = Color3.fromRGB(90, 225, 255)
local storeWindow = UI.window("STORE", 640, 480)
local storeTab = "GEMS"
local storeTabs, storeLists = {}, {}
local refreshStore
for index, name in STORE_TABS do
	local button = UI.button({
		Position = UDim2.new((index - 1) / #STORE_TABS, 2, 0, 0),
		Size = UDim2.new(1 / #STORE_TABS, -4, 0, STORE_TAB_HEIGHT - 6),
		Text = name,
		Parent = storeWindow.body,
	})
	button.Activated:Connect(function()
		storeTab = name
		refreshStore()
	end)
	storeTabs[name] = button
	storeLists[name] = UI.scroll(storeWindow.body, { Position = UDim2.fromOffset(0, STORE_TAB_HEIGHT), Size = UDim2.new(1, 0, 1, -STORE_TAB_HEIGHT) })
end

local packRows = {}
for order, pack in Store.GemPacks do
	local row = UI.row(storeLists.GEMS, 86, order)
	row.icon.BackgroundColor3 = GEM_BLUE
	row.setIcon(pack.id)
	row.button.Activated:Connect(function()
		act("storeBuyPack", pack.id)
	end)
	packRows[pack.id] = row
end

local itemRows = {}
for order, entry in Store.Items do
	local row = UI.row(storeLists.ITEMS, 86, order)
	row.button.Activated:Connect(function()
		act("storeBuyItem", entry.id)
	end)
	itemRows[entry.id] = row
end

-- A row is added the first time a pass is seen, so passes a feature defines after start-up still show up.
local passRows = {}
local function ensurePassRows()
	for key, pass in Config.Passes do
		if not passRows[key] then
			local row = UI.row(storeLists.PASSES, 86, pass.order)
			row.icon.BackgroundColor3 = Colors.gold
			row.setIcon(PASS_ICONS[key])
			row.title.Text = pass.name
			row.sub.Text = pass.desc
			row.button.Activated:Connect(function()
				act("buyPass", key)
			end)
			passRows[key] = row
		end
	end
end

function refreshStore()
	for name, button in storeTabs do
		button.BackgroundColor3 = if name == storeTab then Colors.blue else Colors.grey
		storeLists[name].Visible = name == storeTab
	end

	-- Gem packs: the first one a player buys gives double.
	local bought = (State.feature("store") or {}).packs or 0
	for _, pack in Store.GemPacks do
		local row = packRows[pack.id]
		local gems = Store.gemsFor(pack, bought)
		row.title.Text = `{commas(gems)} Gems`
		row.title.TextColor3 = GEM_BLUE
		row.sub.Text = if gems > pack.gems then `{pack.name}  •  DOUBLE on your first pack (usually {commas(pack.gems)})` else pack.name
		setButton(row.button, `{commas(pack.robux)} R$`, Colors.green)
	end

	-- Items for gems.
	local gemsOwned = State.get("Diamonds", 0)
	for _, entry in Store.Items do
		local row = itemRows[entry.id]
		local item = Items.get(entry.item) :: any
		row.frame.Visible = item ~= nil
		if item then
			row.icon.BackgroundColor3 = item.color or Colors.white
			row.setIcon(entry.item)
			row.title.Text = if entry.amount > 1 then `{item.name} x{entry.amount}` else item.name
			row.title.TextColor3 = Config.RarityColors[item.rarity] or Colors.white
			row.sub.Text = entry.note
			setButton(row.button, `{commas(entry.gems)} 💎`, if gemsOwned >= entry.gems then Colors.green else Colors.grey)
		end
	end

	ensurePassRows()
	local owned = State.meta.passes or {}
	for key, row in passRows do
		if owned[key] then
			setButton(row.button, "OWNED", Colors.grey)
		else
			setButton(row.button, `{Config.Passes[key].price} R$`, Colors.green)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Daily missions
----------------------------------------------------------------------------------------------------
local missionsWindow = UI.window("MISSIONS", 560, 420)
local missionsList = UI.scroll(missionsWindow.body)
local missionsHeader = UI.header(missionsList, 1)
local missionRows = {}
for index, mission in Config.Missions do
	local row = UI.row(missionsList, 60, index + 1)
	row.title.Text = mission.text
	row.icon.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
	row.setIcon("mission_" .. mission.key)
	row.button.Activated:Connect(function()
		act("claimMission", mission.id)
	end)
	missionRows[mission.id] = row
end

local function missionState(mission): (number, boolean, boolean)
	local missions = State.meta.missions or {}
	local progress = math.min((missions.progress or {})[mission.key] or 0, mission.goal)
	local claimed = (missions.claimed or {})[mission.id] == true
	return progress, claimed, progress >= mission.goal and not claimed
end

local function refreshMissions()
	for _, mission in Config.Missions do
		local row = missionRows[mission.id]
		local progress, claimed, ready = missionState(mission)
		row.sub.Text = `{Format.abbreviate(progress)} / {Format.abbreviate(mission.goal)}`
		if claimed then
			setButton(row.button, "DONE", Colors.grey)
		elseif ready then
			setButton(row.button, `CLAIM\n+{mission.reward} 💎`, Colors.green)
		else
			setButton(row.button, `+{mission.reward} 💎`, Colors.grey)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Daily rewards
----------------------------------------------------------------------------------------------------
local dailyWindow = UI.window("DAILY REWARDS", 620, 250)
local dayBoxes = {}
for index, reward in Config.Daily do
	local extra = ""
	if reward.boost then
		extra = `\n{Config.Boosts[reward.boost].name}`
	elseif reward.pet then
		extra = `\n{Config.Pets[reward.pet].short} mini`
	end
	dayBoxes[index] = UI.text({
		Size = UDim2.fromOffset(78, 96),
		Position = UDim2.fromOffset((index - 1) * 85, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Colors.row,
		Text = `Day {index}\n{reward.diamonds} 💎{extra}`,
		MaxSize = 18,
		Parent = dailyWindow.body,
	})
	UI.corner(10).Parent = dayBoxes[index]
end
local dailyButton = UI.button({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 112),
	Size = UDim2.fromOffset(300, 56),
	Parent = dailyWindow.body,
})
dailyButton.Activated:Connect(function()
	act("claimDaily")
end)

local function refreshDaily()
	local daily = State.meta.daily or {}
	local index = daily.index or 1
	for day, box in dayBoxes do
		if day < index or (day == index and daily.claimed) then
			box.BackgroundColor3 = Colors.dark
			box.TextColor3 = Colors.grey
		elseif day == index then
			box.BackgroundColor3 = Colors.green
			box.TextColor3 = Colors.white
		else
			box.BackgroundColor3 = Colors.row
			box.TextColor3 = Colors.white
		end
	end
	if daily.claimed then
		setButton(dailyButton, `DAY {index % #Config.Daily + 1} UNLOCKS TOMORROW`, Colors.grey)
	else
		setButton(dailyButton, `CLAIM DAY {index}`, Colors.green)
	end
end

----------------------------------------------------------------------------------------------------
-- Leaderboards
----------------------------------------------------------------------------------------------------
local topWindow = UI.window("TOP PLAYERS", 780, 430)
-- One column per board the server publishes in ReplicatedStorage.Leaderboards (a StringValue each): Gems,
-- Rebirths, Cannon Power. A board's place is its Order attribute and its heading its Title attribute, so a
-- board can be renamed or replaced on the server without this window being touched; the headings listed here
-- only stand in for a board that came without one.
local BOARD_TITLES = { Gems = "MOST GEMS", Rebirths = "MOST REBIRTHS", Power = "MOST CANNON POWER" }
local BOARD_COLUMNS = 3 -- the boards that are always there
local MAX_BOARD_COLUMNS = 4 -- with an event's board beside them (Features/Event.luau)
local NOTE_HEIGHT = 74
-- For features: [board id] = function() -> text?, a few lines shown under that board's heading (an event's
-- board: the time left, the prizes, the player's own place).
Windows.boardNotes = {} :: { [string]: () -> string? }
local boardColumns = {}
for column = 1, MAX_BOARD_COLUMNS do
	local frame = UI.make("Frame", {
		BackgroundColor3 = Colors.dark,
		Visible = column <= BOARD_COLUMNS,
		Parent = topWindow.body,
	}, { UI.corner(10) })
	boardColumns[column] = {
		frame = frame,
		title = UI.text({ Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 6), TextColor3 = Colors.gold, Text = "", Parent = frame }),
		note = UI.text({
			Size = UDim2.new(1, -16, 0, NOTE_HEIGHT),
			Position = UDim2.fromOffset(8, 34),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Colors.cream,
			MaxSize = 13,
			Text = "",
			Visible = false,
			Parent = frame,
		}),
		rows = UI.text({
			Size = UDim2.new(1, -20, 1, -44),
			Position = UDim2.fromOffset(10, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = Colors.text,
			MaxSize = 16,
			Text = "Loading...",
			Parent = frame,
		}),
	}
end

local function refreshTop()
	local folder = ReplicatedStorage:FindFirstChild("Leaderboards")
	local boards = {}
	for _, value in if folder then folder:GetChildren() else {} do
		if value:IsA("StringValue") then
			table.insert(boards, value)
		end
	end
	table.sort(boards, function(a, b)
		local orderA, orderB = a:GetAttribute("Order") or math.huge, b:GetAttribute("Order") or math.huge
		return if orderA == orderB then a.Name < b.Name else orderA < orderB
	end)
	-- The columns share the window: three as a rule, four while an event's board is up.
	local shown = math.clamp(#boards, BOARD_COLUMNS, MAX_BOARD_COLUMNS)
	for column, entry in boardColumns do
		local value = boards[column]
		entry.frame.Visible = column <= shown
		entry.frame.Size = UDim2.new(1 / shown, -6, 1, 0)
		entry.frame.Position = UDim2.new((column - 1) / shown, 3, 0, 0)
		entry.title.Text = if value then value:GetAttribute("Title") or BOARD_TITLES[value.Name] or string.upper(value.Name) else ""
		local noteOf = if value then Windows.boardNotes[value.Name] else nil
		local fine, note = pcall(function(): string?
			return if noteOf then noteOf() else nil
		end)
		local noted = fine and typeof(note) == "string" and note ~= ""
		entry.note.Visible = noted
		entry.note.Text = if noted then note else ""
		local top = if noted then 38 + NOTE_HEIGHT + 4 else 38
		entry.rows.Position = UDim2.fromOffset(10, top)
		entry.rows.Size = UDim2.new(1, -20, 1, -top - 6)
		local ok, rows = pcall(function()
			return HttpService:JSONDecode(value.Value)
		end)
		if not ok or typeof(rows) ~= "table" or #rows == 0 then
			entry.rows.Text = if value then "No scores yet - be the first!" else ""
			continue
		end
		local lines = {}
		for rank, row in rows do
			table.insert(lines, `{rank}. {row.name}\n      {row.text}`)
		end
		entry.rows.Text = table.concat(lines, "\n")
	end
end

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("Leaderboards")
	local function watch(value: Instance)
		if value:IsA("StringValue") then
			value.Changed:Connect(refreshTop)
		end
	end
	for _, value in folder:GetChildren() do
		watch(value)
	end
	-- A board that is put up later: an event that starts while the server runs.
	folder.ChildAdded:Connect(function(value: Instance)
		watch(value)
		refreshTop()
	end)
	refreshTop()
end)

----------------------------------------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------------------------------------
local REFRESHERS = {
	{ storeWindow, refreshStore },
	{ worldsWindow, refreshWorlds },
	{ shopWindow, refreshShop },
	{ missionsWindow, refreshMissions },
	{ dailyWindow, refreshDaily },
	{ topWindow, refreshTop },
}
-- Keyed by the HUD menu button names (and the Window attribute on marketplace prompts).
Windows.byName = {
	STORE = storeWindow,
	WORLDS = worldsWindow,
	SHOP = shopWindow,
	MISSIONS = missionsWindow,
	DAILY = dailyWindow,
	["TOP PLAYERS"] = topWindow,
}

for _, entry in REFRESHERS do
	local refreshWindow = entry[2]
	entry[1].onOpen = function()
		refreshWindow()
		Windows.tick()
	end
end

-- For features: a window of their own. It opens by name (a menu button, or a marketplace prompt whose
-- Window attribute is that name) and is refreshed with the others while it is open.
function Windows.register(name: string, window, refresh: () -> ())
	table.insert(REFRESHERS, { window, refresh })
	Windows.byName[name] = window
	window.onOpen = function()
		refresh()
		Windows.tick()
	end
end

-- For features: function(currency) -> text?, added to the heading of the event shop that sells for that
-- currency.
Windows.shopNote = nil :: ((currency: string) -> string?)?

-- Refreshes whichever window is open.
function Windows.refresh()
	for _, entry in REFRESHERS do
		if entry[1].frame.Visible then
			entry[2]()
		end
	end
end

-- Countdown headers, updated a few times a second while their window is open.
function Windows.tick()
	local now = State.now()
	if shopWindow.frame.Visible then
		local nextWeek = (Config.weekNumber(now) + 1) * 604_800
		weeklyHeader.Text = `💎 WEEKLY SHOP  •  new stock in {Format.duration(nextWeek - now)}`
		-- What the player has earned in the event and their rank on its board, when a feature knows (Features/Event.luau).
		local ok, note = pcall(function(): string?
			return if Windows.shopNote then Windows.shopNote("candy") else nil
		end)
		local own = if ok and typeof(note) == "string" then `  •  {note}` else ""
		eventHeader.Text = `🎃 HALLOWEEN SHOP  •  ends in {Format.duration(Config.Halloween.endsAt - now)}{own}`
	end
	if missionsWindow.frame.Visible then
		local nextDay = (Config.dayNumber(now) + 1) * 86_400
		missionsHeader.Text = `Daily missions  •  new ones in {Format.duration(nextDay - now)}`
	end
end

-- Which menu buttons should show a "!" because something can be claimed.
function Windows.flags(): { [string]: boolean }
	local missionReady = false
	for _, mission in Config.Missions do
		local _, _, ready = missionState(mission)
		missionReady = missionReady or ready
	end
	local daily = State.meta.daily
	-- Nudge new players to the WORLDS window (its ISLAND button leads to the first egg) until they have
	-- hatched one.
	local firstEgg = Config.Eggs[1]
	local eggReady = State.meta.hatches == 0 and balance(firstEgg.currency) >= firstEgg.cost
	return {
		WORLDS = eggReady,
		MISSIONS = missionReady,
		DAILY = daily ~= nil and not daily.claimed,
	}
end

return Windows
