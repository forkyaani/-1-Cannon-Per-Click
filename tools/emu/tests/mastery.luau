-- Mastery (docs/BUILD_QUEUE.md, section 3): the numbers of the tracks, the shrine on the Mars island, the
-- masteryBuy action and its validation, what every track does to the game's own numbers, and the window.
-- Run with: python3 run.py --all-features tests/mastery.luau
local T = harness.load("_prelude.luau")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local Config, Game = T.Config, T.Game
local player, data, state = T.player, T.data, T.state
local check, eq, act, run = T.check, T.eq, T.act, T.run
local Mastery = require(ReplicatedStorage.Shared.Features.Mastery)
local Feature = require(Server.Features.Mastery)
local Islands = require(Server.Islands)

local function near(actual: number, expected: number, what: string)
	if math.abs(actual - expected) > 1e-6 * math.max(1, math.abs(expected)) then
		error(`CHECK FAILED: {what}: expected {expected}, got {actual}`)
	end
	T.checks += 1
	print(`  ok: {what} = {actual}`)
end
local function meta()
	return HttpService:JSONDecode(player:GetAttribute("Meta_mastery"))
end
local function level(id: string): number
	return Mastery.level(data.features.mastery, id)
end
-- Whether one of the last few toasts says it (another feature may toast in between).
local function toastSays(word: string): boolean
	for index = #T.toasts, math.max(1, #T.toasts - 3), -1 do
		if string.find(T.toasts[index].text, word, 1, true) then
			return true
		end
	end
	return false
end

T.section("the tracks' numbers")
eq(#Mastery.Tracks, 18, "tracks (13 before the rework of 7 Oct, and Tower Crit, Crit Power, Crate Finder, Gem Hunter, Night Shift)")
eq(#Mastery.Groups, 4, "groups")
-- Ids players own: a saved level is kept under its id, so none of these may ever go or change.
for _, id in { "attack", "rate", "range", "boss", "bond", "rapid", "slots", "coins", "luck", "discount", "lives", "slow", "offline" } do
	check(Mastery.byId[id] ~= nil, `the track "{id}" of older saves is still there`)
end
-- The caps of the build before: a cap is only ever raised, or a saved level would be cut.
for id, cap in { attack = 20, rate = 10, range = 10, boss = 10, bond = 10, rapid = 10, slots = 9, coins = 10, luck = 10, discount = 10, lives = 5, slow = 10, offline = 4 } do
	check(Mastery.byId[id].cap >= cap, `{id}'s cap ({Mastery.byId[id].cap}) is not under the old one ({cap})`)
end
local everything = 0
local perGroup = {}
for _, track in Mastery.Tracks do
	local total = Mastery.total(track.id)
	everything += total
	perGroup[track.group] = (perGroup[track.group] or 0) + 1
	check(total >= 2000 and total <= 40000, `{track.name} costs thousands of gems in all ({total})`)
	for step = 2, track.cap do
		check(Mastery.cost(track.id, step) > Mastery.cost(track.id, step - 1), `{track.name} {step} costs more than {step - 1}`)
	end
	-- A free player earns about 100 gems a day: a first level is a day or two, the last one weeks, not years.
	check(Mastery.cost(track.id, 1) <= 150, `{track.name}'s first level is cheap ({Mastery.cost(track.id, 1)})`)
	check(Mastery.cost(track.id, track.cap) <= 3000, `{track.name}'s last level is a sink, not a wall ({Mastery.cost(track.id, track.cap)})`)
	check(Mastery.cost(track.id, track.cap + 1) == nil and Mastery.cost(track.id, 0) == nil and Mastery.cost(track.id, 1.5) == nil, `{track.name} has no price outside its levels`)
	check(Mastery.cost(track.id, 1) % 5 == 0, `{track.name}'s first price is a round number`)
	local found = false
	for _, group in Mastery.Groups do
		found = found or group.id == track.group
	end
	check(found, `{track.name} is in a group`)
	check(Mastery.describe(track.id, 0) == "No bonus yet" and #Mastery.describe(track.id, track.cap) > 4, `{track.name} describes itself`)
	check(not string.find(Mastery.describe(track.id, track.cap), "%s", 1, true), `{track.name}'s text is filled in ({Mastery.describe(track.id, track.cap)})`)
	if track.how == "less" then
		-- 1 - per x level must stay a real discount: never free, never negative.
		check(track.per * track.cap <= 0.6, `{track.name} maxed leaves something (x{1 - track.per * track.cap})`)
	end
	if track.needs then
		check(Mastery.byId[track.needs] ~= nil, `{track.name} needs a track that exists`)
	end
	print(`  {track.name}: cap {track.cap}, maxed "{Mastery.describe(track.id, track.cap)}", {total} gems, last level {Mastery.cost(track.id, track.cap)}`)
end
for _, group in Mastery.Groups do
	check((perGroup[group.id] or 0) >= 4, `the {group.name} tab has {perGroup[group.id]} tracks`)
end
print(`  every track maxed: {everything} gems`)
local fake = { equipped = {}, towerNames = {} }
near(Mastery.apply("attack", 50, 1, fake), 7, "Attack maxed: x7 (x2 before)")
near(Mastery.apply("rate", 25, 1, fake), 2, "Fire Rate maxed: x2 (x1.3 before)")
near(Mastery.apply("range", 25, 1, fake), 1.5, "Range maxed: +50% (+20% before)")
near(Mastery.apply("boss", 30, 1, fake), 4, "Boss Damage maxed: x4 (x1.5 before)")
near(Mastery.apply("crit", 30, 0, fake), 0.3, "Tower Crit maxed: a 30% chance")
near(Mastery.apply("bond", 40, 100, fake), 500, "Bond maxed: x5 mini cannon DPS (x1.3 before)")
near(Mastery.apply("rapid", 25, 0, fake), 0.5, "Mini Crit maxed: a 50% chance")
near(Mastery.apply("rapid", 10, 0, fake), 0.2, "a Rapid X of an older save is a 20% crit chance")
near(Mastery.apply("critpower", 20, 2, fake), 4, "Crit Power maxed: crits hit x4, not x2")
near(Mastery.apply("coins", 30, 1, fake), 4, "Coins maxed: x4 (x1.5 before)")
near(Mastery.apply("luck", 30, 1, fake), 2.5, "Luck maxed: x2.5 (x1.5 before)")
near(Mastery.apply("discount", 30, 1, fake), 0.55, "Discount maxed: 45% cheaper (20% before)")
near(Mastery.apply("crates", 25, 1, fake), 2, "Crate Finder maxed: x2")
near(Mastery.apply("gems", 20, 0, fake), 2, "Gem Hunter maxed: +2 gems a boss")
eq(Mastery.perDay("gems", 20), 60, "and at most 60 gems a day")
near(Mastery.apply("lives", 5, 10, fake), 15, "Lives maxed: +5, as before (it must not grow)")
near(Mastery.apply("slow", 30, 1, fake), 0.7, "Slow maxed: 30% slower (10% before)")
near(Mastery.apply("offline", 16, 8, fake), 24, "Offline maxed: a whole day (12 hours before)")
near(Mastery.apply("nightshift", 25, 0.5, fake), 0.75, "Night Shift maxed: 75% is paid, not 50%")
near(Mastery.apply("slots", 20, 3, fake), 8, "Slots maxed: +5 (+3 before)")
eq(Mastery.slots(2), 0, "slots at level 2")
eq(Mastery.slots(3), 1, "slots at level 3")
eq(Mastery.slots(9), 3, "slots at level 9: what a maxed track of an older save gave")
eq(Mastery.slots(14), 4, "slots at level 14")
eq(Mastery.slots(20), 5, "slots at level 20")
eq(Mastery.nextSlot(3), 6, "the next slot after level 3")
eq(Mastery.nextSlot(9), 14, "the next slot after level 9")
eq(Mastery.nextSlot(20), nil, "no slot is left after level 20")
eq(Mastery.describe("attack", 3), "+36% tower damage", "Attack III reads")
eq(Mastery.describe("range", 1), "+2% tower range", "Range I reads")
eq(Mastery.describe("rate", 5), "+20% tower fire rate", "Fire Rate V reads")
eq(Mastery.describe("crit", 12), "12% of tower shots crit (x2 damage)", "Tower Crit XII reads")
eq(Mastery.describe("rapid", 10), "20% of mini cannon shots crit", "Mini Crit X reads")
eq(Mastery.describe("nightshift", 25), "offline pays +25% of your earnings", "Night Shift XXV reads")
eq(Mastery.describe("gems", 3), "bosses drop +0.3 gems (up to 9 a day)", "Gem Hunter III reads")
eq(Mastery.describe("gems", 10), "bosses drop +1 gem (up to 30 a day)", "Gem Hunter X reads")
eq(Mastery.describe("lives", 1), "+1 life per level", "Lives I reads")
eq(Mastery.describe("offline", 16), "+16 hours of offline earnings", "Offline XVI reads")
eq(Mastery.describe("slots", 2), "No slot yet", "Slots II reads")
eq(Mastery.describe("slots", 3), "+1 equip slot", "Slots III reads")
eq(Mastery.describe("slots", 20), "+5 equip slots", "Slots XX reads")
eq(Mastery.label("attack", 4), "Mastery: Attack IV", "the STATS label")
eq(Mastery.roman(19), "XIX", "roman 19")
eq(Mastery.roman(39), "XXXIX", "roman 39")
eq(Mastery.roman(40), "40", "from 40 on a level is a plain number")
eq(Mastery.label("attack", 50), "Mastery: Attack 50", "the STATS label of a level past 39")
eq(Mastery.level({ levels = { attack = 1e9 } }, "attack"), 50, "a level over the cap is the cap")
eq(Mastery.level({ levels = { attack = 20 } }, "attack"), 20, "the old cap of Attack is a level like any other now")
eq(Mastery.level({ levels = { attack = 3.7 } }, "attack"), 3, "a broken level is a whole one")
eq(Mastery.level({ levels = { attack = -2 } }, "attack"), 0, "a negative level is 0")
eq(Mastery.level({ levels = { attack = "x" } }, "attack"), 0, "a level that is not a number is 0")
eq(Mastery.level(nil, "attack"), 0, "no save is level 0")
eq(Mastery.level({ levels = { nope = 3 } }, "nope"), 0, "an unknown track is level 0")
near(Mastery.apply("nope", 3, 7, fake), 7, "and changes nothing")

T.section("the shrine")
local folder = Islands.container(Mastery.ISLAND)
local shrine = folder and folder:FindFirstChild("MasteryShrine")
check(shrine ~= nil, "the shrine stands on the Mars island")
local prompt = Feature.prompt
check(prompt ~= nil and prompt:GetAttribute("Window") == Mastery.WINDOW, "its prompt opens MASTERY")
local spot = Islands.spot(Mastery.ISLAND, "mastery")
for _, part in shrine:GetChildren() do
	local offset = spot:PointToObjectSpace(part.Position)
	check(math.abs(offset.X) <= 6 and math.abs(offset.Z) <= 6, `{part.Name} is inside the reserved spot`)
end
for index in Config.Worlds do
	if index ~= Mastery.ISLAND then
		check(Islands.container(index):FindFirstChild("MasteryShrine") == nil, `island {index} has no shrine`)
	end
end

T.section("locked until Mars")
-- The Huge every pass owner gets in Studio stays: Bond must leave its multiplier alone.
data.bestCleared = 0
data.diamonds = 1_000_000
act("masteryBuy", "attack")
eq(level("attack"), 0, "nothing is sold before Mars")
check(toastSays("Reach"), "and the toast says why")
data.bestCleared = (Mastery.ISLAND - 1) * Config.WavesPerWorld
act("masteryBuy", "attack")
eq(level("attack"), 0, "nothing is sold away from the shrine")
check(toastSays("Shrine"), "and the toast says where")
act("goIsland", Mastery.ISLAND)
eq(state.island, Mastery.ISLAND, "the player is on the Mars island")
for _, junk in { 5, {}, "nope", true, "", "ATTACK" } do
	act("masteryBuy", junk)
end
act("masteryBuy", nil)
eq(data.diamonds, 1_000_000, "junk arguments buy nothing")
check(harness.errors() == 0, "and raise no errors")

T.section("buying")
local power = Game.value(player, "power")
act("masteryBuy", "attack")
eq(level("attack"), 1, "Attack I is bought")
eq(data.diamonds, 1_000_000 - Mastery.cost("attack", 1), "for its price")
near(Game.value(player, "power"), power * 1.12, "the power multiplier is 12% up")
eq(meta().levels.attack, 1, "the client is told")
eq(player:GetAttribute("Diamonds"), data.diamonds, "and sees the gems go")
local listed = false
for _, source in Game.breakdown(player, "power").sources do
	if source.label == "Mastery: Attack I" then
		listed = true
		near(source.mult, 1.12, "the STATS source's multiplier")
	end
end
check(listed, "STATS lists Mastery: Attack I as a source of power")
data.diamonds = Mastery.cost("attack", 2) - 1
act("masteryBuy", "attack")
eq(level("attack"), 1, "one gem short buys nothing")
check(toastSays("Not enough gems"), "and the toast says so")
data.diamonds = Mastery.cost("attack", 2)
act("masteryBuy", "attack")
eq(level("attack"), 2, "the exact price buys it")
eq(data.diamonds, 0, "and leaves nothing")

T.section("the window")
harness.runClient()
local Client = player.PlayerScripts.Client
local Windows = require(Client.Windows)
local window = Windows.byName[Mastery.WINDOW]
check(window ~= nil, "the MASTERY window is registered")
data.diamonds = 1_000_000
Game.sync(player)
window.open()
run(1)
check(window.frame.Visible, "it opens at the shrine")
local function buttons(prefix: string)
	local found = {}
	for _, item in window.frame:GetDescendants() do
		if item:IsA("TextButton") and string.sub(item.Text, 1, #prefix) == prefix and item.Parent.Visible then
			table.insert(found, item)
		end
	end
	return found
end
eq(#buttons("BUY"), 5, "BUY buttons on the TOWER tab")
local before = data.diamonds
harness.click(buttons("BUY")[1])
run(1)
check(data.diamonds < before, "pressing BUY buys a level")
for _, group in Mastery.Groups do
	local tab = buttons(group.name)[1]
	check(tab ~= nil, `the {group.name} tab is there`)
	harness.click(tab)
	run(0.5)
	local shown = 0
	for _, track in Mastery.Tracks do
		if track.group == group.id then
			shown += 1
		end
	end
	eq(#buttons("BUY") + #buttons("COMING") + #buttons("MAX") + #buttons("NEEDS"), shown, `cards on the {group.name} tab`)
	eq(#buttons("COMING"), 0, `every track on the {group.name} tab is on sale`)
end
-- Bigger caps: a card writes its level as "Lv 2/50" and draws ONE bar, not a pip per level (50 pips were
-- 950 px in a 400 px card), and the cards are in a list that scrolls.
do
	harness.click(buttons(Mastery.Groups[1].name)[1])
	run(0.5)
	local bars, pips, attackTitle, scroller = 0, 0, nil, nil
	for _, item in window.frame:GetDescendants() do
		if item.Name == "Levels" then
			bars += 1
			check(item.Size.X.Offset <= 0 and item.Size.X.Scale == 1, "a level bar is as wide as its card's text, whatever the cap")
			local fill = item:FindFirstChild("Fill")
			check(fill ~= nil and fill.Size.X.Scale >= 0 and fill.Size.X.Scale <= 1, "and its fill stays inside it")
		elseif item.Name == "Pips" then
			pips += 1
		elseif item:IsA("TextLabel") and string.find(item.Text, "ATTACK", 1, true) then
			attackTitle = item.Text
		elseif item:IsA("ScrollingFrame") then
			scroller = item
		end
	end
	eq(bars, #Mastery.Tracks, "level bars, one per track")
	eq(pips, 0, "strips of pips")
	local owned = level("attack")
	check(attackTitle ~= nil and string.find(attackTitle, `Lv {owned}/50`, 1, true) ~= nil, `Attack's card reads Lv {owned}/50 ({attackTitle})`)
	check(scroller ~= nil and scroller.AutomaticCanvasSize == Enum.AutomaticSize.Y, "the cards are in a list that scrolls")
	-- A level past 39 in the window and in a toast: plain numbers.
	data.features.mastery.levels.attack = 44
	data.diamonds = 1_000_000
	Game.sync(player)
	act("masteryBuy", "attack")
	run(0.5)
	eq(level("attack"), 45, "level 45 of Attack is bought")
	check(toastSays("Attack 45: +540% tower damage"), "and the toast writes it as a plain number")
	local title = nil
	for _, item in window.frame:GetDescendants() do
		if item:IsA("TextLabel") and string.find(item.Text, "ATTACK", 1, true) then
			title = item.Text
		end
	end
	check(title ~= nil and string.find(title, "Lv 45/50", 1, true) ~= nil, `the card reads Lv 45/50 ({title})`)
end
-- Crit Power does nothing before Mini Crit: its card says what to buy first, and the server refuses it.
do
	data.features.mastery.levels = {}
	data.diamonds = 1_000_000
	Game.sync(player)
	harness.click(buttons("MINI CANNON")[1])
	run(0.5)
	eq(#buttons("NEEDS"), 1, "one card on the MINI CANNON tab needs another track first")
	act("masteryBuy", "critpower")
	eq(level("critpower"), 0, "Crit Power is not sold before Mini Crit")
	eq(data.diamonds, 1_000_000, "and costs nothing")
	check(toastSays("Mini Crit"), "the toast says what to buy first")
	act("masteryBuy", "rapid")
	act("masteryBuy", "critpower")
	eq(level("critpower"), 1, "with a level of Mini Crit it is sold")
	run(0.5)
	eq(#buttons("NEEDS"), 0, "and the card offers BUY")
end
check(harness.errors() == 0, "no errors in the window")

T.section("the Slots track")
-- Sold like every other track: the core has the `equipSlots` modifier, so nothing is "coming soon".
check(not Feature.off.slots and next(meta().off) == nil, "no track is switched off")
data.features.mastery.levels = {}
data.diamonds = 1_000_000
local slotsBefore = Game.value(player, "equipSlots")
check(slotsBefore + 5 <= 20, `the core's limit of 20 slots leaves room for the track's 5 ({slotsBefore} before)`)
T.debug("pet:wooden", slotsBefore + 6) -- more mini cannons than there will be slots
Game.sync(player)
eq(#state.equipped, slotsBefore, "every slot is full")
for step = 1, Mastery.byId.slots.cap do
	local gems = data.diamonds
	act("masteryBuy", "slots")
	eq(level("slots"), step, `Slots {Mastery.roman(step)} is bought`)
	eq(data.diamonds, gems - Mastery.cost("slots", step), "for its price")
	local earned = Mastery.slots(step)
	eq(Game.value(player, "equipSlots"), slotsBefore + earned, `{earned} more equip slots at level {step}`)
	eq(#state.equipped, slotsBefore + earned, "and a mini cannon is equipped into each")
	eq(HttpService:JSONDecode(player:GetAttribute("Meta")).slots, slotsBefore + earned, "the client is told the slots")
end
local slotsListed = false
for _, source in Game.breakdown(player, "equipSlots").sources do
	slotsListed = slotsListed or source.label == "Mastery: Slots XX"
end
check(slotsListed, "STATS lists Mastery: Slots XX as a source of equip slots")
eq(Game.value(player, "equipSlots"), slotsBefore + 5, "5 more equip slots with the track maxed")
local gemsAtCap = data.diamonds
act("masteryBuy", "slots")
eq(data.diamonds, gemsAtCap, "a level past the cap is not sold")
check(toastSays("maxed"), "and the toast says it is maxed")
check(harness.errors() == 0, "no errors while buying slots")

----------------------------------------------------------------------------------------------------
-- Every track, one at a time: bought at the shrine, and what it did measured in the game itself.
----------------------------------------------------------------------------------------------------
local Offline = require(Server.Features.Offline)
-- The Huge every pass owner gets fires shots of its own and multiplies tower damage: the tracks are measured
-- without it, on two ordinary mini cannons.
for _, id in Config.Huges do
	Game.pets.remove(player, id, Game.pets.count(data, id))
end
while #data.pets > 0 do
	Game.pets.remove(player, data.pets[1], 1)
end
T.debug("pet:wooden", 2)
eq(#state.equipped, 2, "two ordinary mini cannons are equipped")

-- What the shots of a fight were worth: counted by a `shot` hook, as a feature would see them.
local seen = { tower = 0, towerDamage = 0, towerCrits = 0, towerPlain = 0, pet = 0, petDamage = 0, petCrits = 0, petPlain = 0, rewards = {} }
local function forget()
	seen.tower, seen.towerDamage, seen.towerCrits, seen.towerPlain = 0, 0, 0, 0
	seen.pet, seen.petDamage, seen.petCrits, seen.petPlain = 0, 0, 0, 0
	table.clear(seen.rewards)
end
Game.on("shot", function(_player, _data, _state, shot)
	if shot.source == "tower" then
		seen.tower += 1
		seen.towerDamage += shot.damage
		if shot.crit then
			seen.towerCrits += 1
		else
			seen.towerPlain = shot.damage -- an ordinary shot of the one tower
		end
	elseif shot.source == "pet" then
		seen.pet += 1
		seen.petDamage += shot.damage
		if shot.crit then
			seen.petCrits += 1
		else
			seen.petPlain = shot.damage
		end
	end
end)
Game.on("kill", function(_player, _data, _state, info)
	table.insert(seen.rewards, info.reward)
end)

local NORMAL, BOSS = 61, 60 -- an ordinary level and a giant's (a boss level)
eq(Config.waveKind(NORMAL), "normal", `level {NORMAL} is an ordinary level`)
check(Config.waveKind(BOSS) ~= "normal", `level {BOSS} is a boss level`)
local TANK = 400 -- a level whose monsters outlive a long measurement
local function fight(wave: number, seconds: number)
	T.debug("wave", wave)
	forget()
	run(seconds)
end
local function attribute(name: string): number
	Game.sync(player)
	return player:GetAttribute(name)
end
-- Twenty hours away, as the offline feature would pay them right now.
local function away()
	local result = Offline.estimate(player, data, state, 20 * 3600)
	assert(result, "offline earnings could not be estimated")
	return result
end
-- One boss killed: the gems it dropped, with the part of a gem still owed.
local function bossGems(): number
	T.debug("wave", BOSS)
	run(1)
	local before = data.diamonds + state.gemsOwed
	Game.damage(player, 1e30)
	return data.diamonds + state.gemsOwed - before
end

-- What each track is measured by: a number of the game that the track must move. `first` = whether one level
-- must be visible in it (a few are whole numbers that one small level cannot move: those are measured maxed).
local PROBES = {
	attack = function() -- the damage of one tower shot
		fight(TANK, 4)
		return seen.towerPlain
	end,
	rate = function() -- tower shots in a fixed time
		fight(TANK, 40)
		return seen.tower
	end,
	range = function()
		return attribute("TowerRange")
	end,
	boss = function() -- one mini cannon shot on a boss level
		T.debug("wave", BOSS)
		return Game.shotDamage(player)
	end,
	crit = function() -- the towers' half of Cannon Power counts crits as what they add on average
		return attribute("TowerDps")
	end,
	bond = function() -- the damage of one mini cannon shot
		fight(TANK, 4)
		return seen.petPlain
	end,
	rapid = function() -- the mini cannons' half of Cannon Power, crits counted
		return attribute("PetDps")
	end,
	critpower = function()
		return attribute("PetDps")
	end,
	slots = function()
		return #state.equipped
	end,
	coins = function() -- the coins of one kill
		fight(NORMAL, 3)
		table.clear(seen.rewards)
		Game.damage(player, 1e30)
		return seen.rewards[1]
	end,
	luck = function()
		return Game.luck(player, data, state)
	end,
	discount = function()
		return attribute("UpgradeCost")
	end,
	crates = function()
		return Game.value(player, "crateDrops")
	end,
	gems = bossGems,
	lives = function() -- the lives a level starts with
		T.debug("wave", NORMAL)
		return state.livesMax
	end,
	slow = function() -- how far the first monster has walked after three seconds
		T.debug("wave", TANK)
		run(3)
		local far = 0
		for _, monster in state.monsters do
			far = math.max(far, monster.d)
		end
		return far
	end,
	offline = function() -- the seconds of twenty hours away that are paid
		return away().seconds
	end,
	nightshift = function() -- the coins of eight hours away
		return away().coins
	end,
}
-- What one level makes of the probe's number (nil: checked by hand below).
local AFTER_ONE = {
	attack = 1.12, range = 1.02, boss = 1.1, crit = 1.01, bond = 1.1, luck = 1.05, discount = 0.985,
	crates = 1.04, slow = 0.99,
}

T.section("every track, bought once and measured")
data.bestCleared = Config.TotalWaves -- nothing below is a first clear
bossGems() -- (the first kill of that boss may pay a first-clear reward: not what is measured)
for _, track in Mastery.Tracks do
	local id = track.id
	local probe = PROBES[id]
	check(probe ~= nil, `{track.name} has a measurement`)
	data.features.mastery.levels = if track.needs then { [track.needs] = 5 } else {}
	data.features.mastery.gemDay, data.features.mastery.gems = 0, 0
	data.diamonds = 1_000_000
	Game.refreshPets(player)
	Game.sync(player)
	local before = probe()
	local steps = if id == "slots" then 3 else 1 -- Slots gives its first slot at level 3
	if id == "slots" then
		T.debug("pet:wooden", 25) -- more mini cannons than slots: every slot is full
		before = probe()
		eq(before, Game.value(player, "equipSlots"), "every equip slot is full")
	end
	for step = 1, steps do
		local gems = data.diamonds
		act("masteryBuy", id)
		eq(level(id), step, `{track.name} {Mastery.roman(step)} is bought`)
		eq(data.diamonds, gems - Mastery.cost(id, step), "for its price")
	end
	eq(meta().levels[id], steps, "the client is told")
	local after = probe()
	check(typeof(before) == "number" and typeof(after) == "number", `{track.name}'s measurement is a number`)
	local factor = AFTER_ONE[id]
	if factor then
		near(after, before * factor, `{track.name} I: x{factor} ({before} -> {after})`)
	elseif id == "rate" then
		check(after > before, `Fire Rate I: more tower shots in the same time ({before} -> {after})`)
	elseif id == "rapid" then
		near(after, before * 1.02, `Mini Crit I: a 2% crit chance is +2% mini cannon DPS on average ({before} -> {after})`)
		near(Game.value(player, "petCrit"), 0.02, "the crit chance")
	elseif id == "critpower" then
		-- With Mini Crit V (10%): crits go from x2 to x2.1, so the average from x1.10 to x1.11.
		near(after, before * 1.11 / 1.10, `Crit Power I: crits are worth 5% more ({before} -> {after})`)
		near(Game.value(player, "petCritDamage"), 2.1, "a crit's multiplier")
	elseif id == "slots" then
		eq(after, before + 1, "Slots III: one more mini cannon is equipped")
		Game.pets.remove(player, "wooden", Game.pets.count(data, "wooden") - 2)
		eq(#state.equipped, 2, "(back to two mini cannons)")
	elseif id == "coins" then
		-- (A kill pays whole coins.)
		eq(after, math.floor(Config.levelPlan(NORMAL).coins * Game.value(player, "coins")), "Coins I: a kill pays the level's coins x the multiplier")
		check(after >= before * 1.09 and after <= before * 1.11, `which is 10% more ({before} -> {after})`)
	elseif id == "nightshift" then
		-- (Whole coins are paid.) 51% of what the towers would have earned instead of 50%.
		check(math.abs(after - before * 0.51 / 0.5) <= 2, `Night Shift I: twenty hours away pay 2% more ({before} -> {after})`)
	elseif id == "gems" then
		near(after, before + 0.1, `Gem Hunter I: a boss drops a tenth of a gem more ({before} -> {after})`)
	elseif id == "lives" then
		eq(after, before + 1, "Lives I: a level starts with one more life")
	elseif id == "offline" then
		eq(after, before + 3600, "Offline I: one more hour of twenty away is paid")
	else
		error(`CHECK FAILED: {track.name} is not checked`)
	end
	check(after ~= before, `{track.name} changes what it is measured by`)
	-- And the STATS window can name it: the track is a labelled source of its number.
	local listed = false
	for _, source in Game.breakdown(player, track.kind).sources do
		listed = listed or source.label == Mastery.label(id, steps)
	end
	check(listed, `STATS lists {Mastery.label(id, steps)} as a source of {track.kind}`)
end
check(harness.errors() == 0, "no errors while measuring")

T.section("Mini Crit (the track that was Rapid) changes the damage dealt")
do
	local saved = data.features.mastery
	-- No crit: every mini cannon shot is the same.
	saved.levels = {}
	Game.sync(player)
	local flat = attribute("PetDps")
	local power = attribute("CannonPower")
	fight(TANK, 30)
	local plain = seen.petPlain
	eq(seen.petCrits, 0, "no mini cannon shot crits without the track")
	check(seen.pet >= 50, `the mini cannons fired ({seen.pet} shots)`)
	near(seen.petDamage, seen.pet * plain, "and every shot dealt the same")
	near(Game.value(player, "petShots"), 1, "the dead `petShots` number is left alone")
	-- A Rapid X bought before the rework: 20% of the shots are crits, worth double.
	saved.levels = { rapid = 10 }
	near(attribute("PetDps"), flat * 1.2, "a saved Rapid X: mini cannon DPS is 20% up on average")
	near(attribute("CannonPower"), power + flat * 0.2, "and the headline number, Cannon Power, shows it")
	fight(TANK, 150)
	check(seen.pet >= 250, `the mini cannons fired ({seen.pet} shots)`)
	local share = seen.petCrits / seen.pet
	check(share > 0.1 and share < 0.3, `about 20% of them were crits ({seen.petCrits} of {seen.pet})`)
	near(seen.petDamage, (seen.pet + seen.petCrits) * plain, "a crit dealt double, the others what they did")
	check(seen.petDamage > seen.pet * plain * 1.1, `the same shots dealt more damage ({seen.petDamage} against {seen.pet * plain})`)
	-- Maxed, with Crit Power maxed: half the shots, worth x4.
	saved.levels = { rapid = 25, critpower = 20 }
	near(attribute("PetDps"), flat * 2.5, "Mini Crit and Crit Power maxed: x2.5 mini cannon DPS on average")
	fight(TANK, 150)
	share = seen.petCrits / seen.pet
	check(share > 0.38 and share < 0.62, `about half of the shots were crits ({seen.petCrits} of {seen.pet})`)
	near(seen.petDamage, (seen.pet + 3 * seen.petCrits) * plain, "and a crit dealt four times an ordinary shot")
	-- Offline earnings count the crits too.
	saved.levels = {}
	-- (More damage farms a higher level, or the same one faster. A higher level is not always more coins an
	-- hour, a boss level is one monster, so it is the level and the pace that are compared.)
	local without = away()
	saved.levels = { rapid = 25, critpower = 20, crit = 30 }
	local with = away()
	check(with.level > without.level or (with.level == without.level and with.clearSeconds < without.clearSeconds),
		`offline earnings count crits (level {without.level} in {without.clearSeconds} s -> level {with.level} in {with.clearSeconds} s)`)
	-- Tower Crit: 30% of tower shots are double.
	saved.levels = {}
	local towers = attribute("TowerDps")
	saved.levels = { crit = 30 }
	near(attribute("TowerDps"), towers * 1.3, "Tower Crit maxed: +30% tower damage on average")
	fight(TANK, 200)
	check(seen.tower >= 80, `the tower fired ({seen.tower} shots)`)
	share = seen.towerCrits / seen.tower
	check(share > 0.15 and share < 0.45, `about 30% of its shots were crits ({seen.towerCrits} of {seen.tower})`)
	near(seen.towerDamage, (seen.tower + seen.towerCrits) * seen.towerPlain, "and a crit dealt double")
	saved.levels = {}
	check(harness.errors() == 0, "no errors while critting")
end

T.section("Gem Hunter stops at its gems a day")
do
	local saved = data.features.mastery
	saved.levels = { gems = 10 } -- +1 gem a boss, 30 a day
	saved.gemDay, saved.gems = 0, 0
	local nothing = (function()
		saved.levels = {}
		local gems = bossGems()
		saved.levels = { gems = 10 }
		return gems
	end)()
	near(bossGems(), nothing + 1, "Gem Hunter X: a boss drops one more gem")
	eq(saved.gemDay, Config.dayNumber(os.time()), "the day is noted")
	near(saved.gems, 1, "and the gem counted")
	saved.gems = 29
	near(bossGems(), nothing + 1, "the thirtieth gem of the day drops")
	check(toastSays("all 30 gems found today"), "and the toast says it was the last")
	near(bossGems(), nothing, "the next boss drops none")
	local stillListed = false
	for _, source in Game.breakdown(player, "gems").sources do
		stillListed = stillListed or string.find(source.label, "Gem Hunter", 1, true) ~= nil
	end
	check(not stillListed, "STATS does not list it while it gives nothing")
	saved.gemDay -= 1
	near(bossGems(), nothing + 1, "and on the next day they drop again")
	near(saved.gems, 1, "counted from nothing")
	saved.levels = {}
end

T.section("the Silver tier's perk is more DPS")
do
	local silver = Config.FuseTiers[1]
	eq(silver.id, "silver", "the tier keeps its id (it is part of saved mini cannon ids)")
	eq(silver.name, "Silver", "and its name")
	eq(silver.perk, "Overcharge", "its perk is Overcharge (Rapid Fire fired twice as fast and dealt nothing more)")
	eq(silver.fireRate, nil, "the dead fire rate is gone")
	eq(Config.perkText(silver), "+25% DPS", "the MINI CANNONS and FUSE windows read")
	local wooden, fused = Config.Pets.wooden, Config.Pets.wooden_silver
	near(fused.dps, wooden.dps * silver.bonus * 1.25, "a Silver mini cannon: its tier's bonus, and 25% on top")
	near(fused.bonus, wooden.bonus * silver.bonus, "its bonus number is the tier's own")
	eq(fused.fireRate, 1, "it fires once a second like any other")
	eq(fused.perks[1], "Overcharge", "and lists the perk")
	near(Config.Pets.wooden_gold.dps, wooden.dps * Config.FuseTiers[2].bonus * 1.25, "Gold keeps the perk of the tier below")
	near(Config.Pets.wooden_diamond.dps, wooden.dps * Config.FuseTiers[3].bonus * 1.25, "and so does Diamond")
	check(Config.Pets.wooden_gold.coinBonus > 0 and Config.Pets.wooden_diamond.healCut > 0, "the other perks are what they were")
	-- In the game: one Silver in place of one ordinary mini cannon.
	local one = attribute("PetDps") / 2 -- two Mini Wooden Cannons are equipped
	Game.pets.remove(player, "wooden", 1)
	T.debug("pet:wooden_silver", 1)
	eq(#state.equipped, 2, "a Silver mini cannon is equipped beside an ordinary one")
	near(attribute("PetDps"), one + one * silver.bonus * 1.25, "mini cannon DPS: the perk's 25% is in it")
	fight(TANK, 30)
	near(seen.petDamage / seen.pet, (one + one * silver.bonus * 1.25) / 2, "and in the damage their shots deal")
	Game.pets.remove(player, "wooden_silver", 1)
	T.debug("pet:wooden", 1)
	check(harness.errors() == 0, "no errors")
end

T.section("every track, maxed")
local KINDS = {
	"power", "towerRate", "towerRange", "bossDamage", "towerCrit", "petDps", "petCrit", "petCritDamage", "coins", "luck",
	"upgradeCost", "crateDrops", "gems", "lives", "monsterSpeed", "equipSlots", "offlineCap", "offlineShare",
}
for _, track in Mastery.Tracks do
	check(table.find(KINDS, track.kind) ~= nil, `{track.name}'s number ({track.kind}) is checked below`)
end
data.features.mastery.levels = {}
data.features.mastery.gemDay, data.features.mastery.gems = 0, 0
Game.refreshPets(player)
Game.sync(player)
local base = {}
for _, kind in KINDS do
	base[kind] = Game.value(player, kind)
end
local shotsBefore = PROBES.rate()
local awayBefore = away()
data.features.mastery.spent = 0
data.diamonds = 1_000_000
local sold = 0
for _, track in Mastery.Tracks do
	if track.needs then
		eq(level(track.needs), Mastery.byId[track.needs].cap, `{Mastery.byId[track.needs].name} comes before {track.name} in the window`)
	end
	for _ = 1, track.cap + 1 do -- one press too many: it must be refused
		act("masteryBuy", track.id)
	end
	if Feature.off[track.id] then
		eq(level(track.id), 0, `{track.name} is not sold while the core cannot apply it`)
	else
		eq(level(track.id), track.cap, `{track.name} stops at its cap`)
		sold += Mastery.total(track.id)
	end
end
eq(next(Feature.off), nil, "the core can apply every track")
eq(sold, everything, "every track was sold to its last level")
eq(data.diamonds, 1_000_000 - sold, "gems spent are the tracks' totals")
eq(data.features.mastery.spent, sold, "and the save counts them")
-- Bond grows the mini cannons' own damage per second and leaves tower damage alone.
local _, ownDps = T.Config.petDpsList(state.equipped, state.towerNames)
check(ownDps > 0, "mini cannons are equipped")
near(Game.value(player, "petDps"), ownDps * 5, "mini cannon DPS: Bond x5")
near(Game.value(player, "power"), base.power * 7, "power: Attack x7, and nothing from Bond")
near(Game.value(player, "towerRate"), base.towerRate * 2, "fire rate x2")
near(Game.value(player, "towerRange"), base.towerRange * 1.5, "range +50%")
near(Game.value(player, "bossDamage"), base.bossDamage * 4, "boss damage x4")
near(Game.value(player, "towerCrit"), 0.3, "tower crit chance 30%")
near(Game.value(player, "petCrit"), 0.5, "mini cannon crit chance 50%")
near(Game.value(player, "petCritDamage"), 4, "mini cannon crits x4")
near(Game.value(player, "petShots"), 1, "mini cannon shots: no track touches the dead number")
near(Game.value(player, "coins"), base.coins * 4, "coins x4")
near(Game.value(player, "luck"), base.luck * 2.5, "luck x2.5")
near(Game.value(player, "upgradeCost"), base.upgradeCost * 0.55, "upgrades 45% cheaper")
near(Game.value(player, "crateDrops"), base.crateDrops * 2, "crate drops x2")
near(Game.value(player, "gems"), base.gems + 2, "2 more gems a boss")
near(Game.value(player, "monsterSpeed"), base.monsterSpeed * 0.7, "monsters 30% slower")
eq(Game.value(player, "lives"), base.lives + 5, "5 more lives")
eq(Game.value(player, "offlineCap"), base.offlineCap + 16, "16 more hours of offline earnings")
near(Game.value(player, "offlineShare"), base.offlineShare + 0.25, "a quarter more of them is paid")
near(player:GetAttribute("TowerRate"), Game.value(player, "towerRate"), "the client is told the fire rate")
eq(Game.value(player, "equipSlots"), base.equipSlots + 5, "5 more equip slots")
eq(HttpService:JSONDecode(player:GetAttribute("Meta")).slots, base.equipSlots + 5, "and the client is told")
check(#state.equipped <= base.equipSlots + 5, "the mini cannons are equipped into them")
-- No number is stopped by one of the core's limits: every level that is sold does something.
for _, kind in KINDS do
	local breakdown = Game.breakdown(player, kind)
	local last = breakdown.sources[#breakdown.sources]
	check(last ~= nil and math.abs(last.value - breakdown.total) <= 1e-6 * math.max(1, math.abs(last.value)), `{kind} is not cut by a limit of the core ({breakdown.total})`)
end
-- Cannon Power, the headline number: both halves, with crits as what they add on average.
Game.sync(player)
local towerBase = 0
for _, tower in state.towerList do
	towerBase += tower.base * tower.def.rate
end
near(player:GetAttribute("TowerDps"), towerBase * base.power * 7 * 2 * 1.3, "the towers' half: Attack x Fire Rate x Tower Crit")
near(player:GetAttribute("PetDps"), ownDps * 5 * 2.5, "the mini cannons' half: Bond x crits")
near(player:GetAttribute("CannonPower"), player:GetAttribute("TowerDps") + player:GetAttribute("PetDps"), "Cannon Power is the two")
-- In the fight: twice the fire rate (and half as much range again) is at least twice the shots.
local shotsAfter = PROBES.rate()
check(shotsAfter >= shotsBefore * 1.9, `the tower fires about twice as often or more ({shotsBefore} -> {shotsAfter} shots)`)
-- Away from the game: 24 hours are paid instead of 8, at 75% instead of 50%.
local awayAfter = away()
eq(awayBefore.seconds, 8 * 3600, "eight of twenty hours away were paid")
eq(awayAfter.seconds, 20 * 3600, "all twenty are paid now (24 would be)")
eq(awayBefore.coins, math.floor(awayBefore.seconds / awayBefore.clearSeconds * awayBefore.perClear * 0.5), "half of what the towers would have earned was paid")
eq(awayAfter.coins, math.floor(awayAfter.seconds / awayAfter.clearSeconds * awayAfter.perClear * 0.75), "three quarters are paid now")
check(awayAfter.level >= awayBefore.level, `and the towers farm a level at least as high (level {awayBefore.level} -> {awayAfter.level})`)
-- The STATS window gets the crit sections, and its Cannon Power is the core's.
do
	local Stats = require(Server.Features.Stats)
	local shot = Stats.snapshot(Game, player, data, state)
	near(shot.power, player:GetAttribute("CannonPower"), "STATS' Cannon Power is the HUD's")
	local byId = {}
	for _, section in shot.sections do
		byId[section.id] = section
	end
	check(byId.towerCrit ~= nil and byId.towerCrit.unit == "chance", "STATS has a TOWER CRIT CHANCE section")
	near(byId.towerCrit.total, 0.3, "at 30%")
	eq(byId.towerCrit.sources[1].label, "Mastery: Tower Crit XXX", "from the track")
	near(byId.petCrit.total, 0.5, "MINI CANNON CRIT CHANCE is 50%")
	eq(byId.petCrit.sources[1].label, "Mastery: Mini Crit XXV", "from the track that was Rapid")
	near(byId.petCritDamage.total, 4, "MINI CANNON CRIT DAMAGE is x4")
	near(shot.chain[#shot.chain].value, shot.towerPower, "the chain of the towers ends at their half, crits included")
	local running = 0
	for _, line in shot.pets.lines do
		running += line.dps
	end
	for _, bonus in shot.pets.bonuses do
		running += bonus.add
	end
	near(running, shot.pets.dps, "the mini cannons' lines add up to their half, crits included")
end
check(harness.errors() == 0, "no errors while buying everything")

T.section("leaving, and a rebirth")
window.open()
run(1)
act("goHome")
run(1)
check(not window.frame.Visible, "the window closes when the player leaves the island")
T.debug("wave", data.wave) -- starts a level
run(1)
eq(state.livesMax, base.lives + 5, "a level started after Lives was bought has the extra lives")
local rebirths = data.rebirths
data.cleared = Config.rebirthWave(data.rebirths)
act("rebirth", true)
eq(data.rebirths, rebirths + 1, "the player rebirthed")
eq(level("attack"), Mastery.byId.attack.cap, "mastery is kept through a rebirth")
act("goIsland", Mastery.ISLAND)
eq(state.island, Mastery.ISLAND, "and the shrine is still open")
check(harness.errors() == 0, "no errors")

T.section("a save from another build")
do
	-- What a player of the build before the rework could have, a level above a cap, a level of a track this
	-- build does not know, and junk: all of it must load, and nothing bought may be thrown away.
	data.features.mastery = {
		levels = { attack = 20, rate = 10, rapid = 10, slots = 9, offline = 4, lives = 99, range = 3.9, removed = 7, coins = "many", luck = -3 },
		spent = 12345,
	}
	data.diamonds = 500
	harness.removePlayer(player)
	run(1)
	local again = harness.addPlayer("Tester", 1)
	harness.flush()
	local saved, session = Game.data(again), Game.state(again)
	assert(saved and session, "the player did not load again")
	T.release(again)
	local kept = saved.features.mastery
	local function owned(id: string): number
		return Mastery.level(kept, id)
	end
	eq(owned("attack"), 20, "Attack XX (the old cap) is level 20 of 50")
	eq(owned("rate"), 10, "Fire Rate X is kept")
	eq(owned("rapid"), 10, "Rapid X is Mini Crit X")
	eq(owned("slots"), 9, "Slots IX is kept")
	eq(owned("offline"), 4, "Offline IV is kept")
	eq(owned("lives"), 5, "a level above the cap counts as the cap")
	eq(kept.levels.lives, 99, "and is left in the save as it was")
	eq(owned("range"), 3, "a broken level is a whole one")
	eq(owned("coins"), 0, "junk is no level")
	eq(owned("luck"), 0, "a negative level is none")
	eq(kept.levels.removed, 7, "a level of a track this build does not know stays in the save")
	eq(owned("removed"), 0, "and does nothing")
	eq(kept.spent, 12345, "the gems spent are remembered")
	eq(kept.gems, 0, "an older save gets Gem Hunter's counter")
	eq(saved.diamonds, 500, "and no gems are taken or given")
	local attackMult = nil
	for _, source in Game.breakdown(again, "power").sources do
		if source.label == "Mastery: Attack XX" then
			attackMult = source.mult
		end
	end
	check(attackMult ~= nil, "STATS lists Mastery: Attack XX")
	near(attackMult, 3.4, "Attack XX is +240% now (it was +100%)")
	near(Game.value(again, "petCrit"), 0.2, "the saved Rapid X is a 20% mini cannon crit chance")
	near(Game.value(again, "towerRate"), 1.4, "Fire Rate X is +40% (it was +30%)")
	near(Game.value(again, "offlineCap"), Config.Offline.capHours + 4, "Offline IV is still 4 hours")
	local slotsNow, slotsBare = Game.value(again, "equipSlots"), nil
	kept.levels.slots = nil
	slotsBare = Game.value(again, "equipSlots")
	kept.levels.slots = 9
	eq(slotsNow, slotsBare + 3, "Slots IX still gives its 3 slots")
	eq(Game.value(again, "lives"), Config.Defense.lives + 5, "the level above the cap gives the cap's 5 lives")
	-- The client is told the same levels, and the next level of a raised cap can be bought.
	local told = HttpService:JSONDecode(again:GetAttribute("Meta_mastery"))
	eq(Mastery.level(told, "attack"), 20, "the window is told Attack 20")
	saved.diamonds = 1_000_000
	saved.bestCleared = math.max(saved.bestCleared, (Mastery.ISLAND - 1) * Config.WavesPerWorld)
	harness.advance(0.1)
	T.Remotes.Action:FireServer("goIsland", Mastery.ISLAND)
	harness.flush()
	harness.advance(0.1)
	T.Remotes.Action:FireServer("masteryBuy", "attack")
	harness.flush()
	eq(owned("attack"), 21, "level 21 of Attack is sold to a player who had maxed it")
	eq(saved.diamonds, 1_000_000 - Mastery.cost("attack", 21), "for the price of level 21")
	harness.advance(0.1)
	T.Remotes.Action:FireServer("masteryBuy", "lives")
	harness.flush()
	eq(kept.levels.lives, 99, "a track above its cap sells nothing")
	check(harness.errors() == 0, "no errors with an old save")
end

print(`PASSED ({T.checks} checks)`)
