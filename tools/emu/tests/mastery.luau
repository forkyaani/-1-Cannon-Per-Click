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
local function toastSays(word: string): boolean
	return string.find(T.lastToast(), word, 1, true) ~= nil
end

T.section("the tracks' numbers")
eq(#Mastery.Tracks, 13, "tracks (with Offline: +1 hour of offline earnings a level)")
eq(#Mastery.Groups, 4, "groups")
local everything = 0
for _, track in Mastery.Tracks do
	local total = Mastery.total(track.id)
	everything += total
	check(total >= 2000 and total <= 8000, `{track.name} costs thousands of gems in all ({total})`)
	for step = 2, track.cap do
		check(Mastery.cost(track.id, step) > Mastery.cost(track.id, step - 1), `{track.name} {step} costs more than {step - 1}`)
	end
	check(Mastery.cost(track.id, track.cap + 1) == nil and Mastery.cost(track.id, 0) == nil and Mastery.cost(track.id, 1.5) == nil, `{track.name} has no price outside its levels`)
	check(Mastery.cost(track.id, 1) % 5 == 0, `{track.name}'s first price is a round number`)
	local found = false
	for _, group in Mastery.Groups do
		found = found or group.id == track.group
	end
	check(found, `{track.name} is in a group`)
	check(Mastery.describe(track.id, 0) == "No bonus yet" and #Mastery.describe(track.id, track.cap) > 4, `{track.name} describes itself`)
end
print(`  every track maxed: {everything} gems`)
local fake = { equipped = {}, towerNames = {} }
near(Mastery.apply("attack", 20, 1, fake), 3, "Attack maxed")
near(Mastery.apply("rate", 10, 1, fake), 1.5, "Fire Rate maxed")
near(Mastery.apply("range", 10, 1, fake), 1.25, "Range maxed")
near(Mastery.apply("coins", 10, 1, fake), 2, "Coins maxed")
near(Mastery.apply("lives", 5, 10, fake), 15, "Lives maxed")
near(Mastery.apply("bond", 10, 100, fake), 100 * (1 + Mastery.byId.bond.per * 10), "Bond maxed: that much more mini cannon DPS")
check(Mastery.apply("attack", 20, 1, fake) * 1.3 <= 4, "damage with everything maxed is at most x4")
eq(Mastery.slots(2), 0, "slots at level 2")
eq(Mastery.slots(3), 1, "slots at level 3")
eq(Mastery.slots(9), 3, "slots at level 9")
eq(Mastery.nextSlot(3), 6, "the next slot after level 3")
eq(Mastery.describe("attack", 3), "+30% tower damage", "Attack III reads")
eq(Mastery.describe("range", 1), "+2.5% tower range", "Range I reads")
eq(Mastery.describe("lives", 1), "+1 life per level", "Lives I reads")
eq(Mastery.describe("slots", 3), "+1 equip slot", "Slots III reads")
eq(Mastery.label("attack", 4), "Mastery: Attack IV", "the STATS label")
eq(Mastery.roman(19), "XIX", "roman 19")
eq(Mastery.level({ levels = { attack = 1e9 } }, "attack"), 20, "a level over the cap is the cap")
eq(Mastery.level({ levels = { attack = "x" } }, "attack"), 0, "a level that is not a number is 0")
eq(Mastery.level(nil, "attack"), 0, "no save is level 0")
eq(Mastery.level({ levels = { nope = 3 } }, "nope"), 0, "an unknown track is level 0")

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
near(Game.value(player, "power"), power * 1.1, "the power multiplier is 10% up")
eq(meta().levels.attack, 1, "the client is told")
eq(player:GetAttribute("Diamonds"), data.diamonds, "and sees the gems go")
local listed = false
for _, source in Game.breakdown(player, "power").sources do
	if source.label == "Mastery: Attack I" then
		listed = true
		near(source.mult, 1.1, "the STATS source's multiplier")
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
eq(#buttons("BUY"), 4, "BUY buttons on the TOWER tab")
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
	eq(#buttons("BUY") + #buttons("COMING") + #buttons("MAX"), shown, `cards on the {group.name} tab`)
end
check(harness.errors() == 0, "no errors in the window")

T.section("every track, maxed")
local KINDS = { "power", "towerRate", "towerRange", "bossDamage", "petShots", "coins", "luck", "upgradeCost", "lives", "monsterSpeed", "equipSlots" }
data.features.mastery.levels = {}
T.debug("pet:wooden", 2) -- ordinary mini cannons, for Bond to work on
Game.sync(player)
local base = {}
for _, kind in KINDS do
	base[kind] = Game.value(player, kind)
end
data.features.mastery.spent = 0
data.diamonds = 1_000_000
local sold = 0
for _, track in Mastery.Tracks do
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
eq(data.diamonds, 1_000_000 - sold, "gems spent are the tracks' totals")
eq(data.features.mastery.spent, sold, "and the save counts them")
-- Bond grows the mini cannons' own damage per second and leaves tower damage (and a Huge's multiplier) alone.
local _, ownDps = T.Config.petDpsList(state.equipped, state.towerNames)
check(ownDps > 0, "mini cannons are equipped")
near(Game.value(player, "petDps"), ownDps * (1 + Mastery.byId.bond.per * Mastery.byId.bond.cap), "mini cannon DPS: Bond")
near(Game.value(player, "power"), base.power * 3, "power: Attack x3, and nothing from Bond")
check(Game.value(player, "power") <= base.power * 4, "damage is at most x4")
near(Game.value(player, "towerRate"), base.towerRate * 1.5, "fire rate x1.5")
near(Game.value(player, "towerRange"), base.towerRange * 1.25, "range +25%")
near(Game.value(player, "bossDamage"), base.bossDamage * 1.5, "boss damage x1.5")
near(Game.value(player, "petShots"), base.petShots * 1.5, "mini cannon shots x1.5")
near(Game.value(player, "coins"), base.coins * 2, "coins x2")
near(Game.value(player, "luck"), base.luck * 1.5, "luck x1.5")
near(Game.value(player, "upgradeCost"), base.upgradeCost * 0.7, "upgrades 30% cheaper")
near(Game.value(player, "monsterSpeed"), base.monsterSpeed * 0.85, "monsters 15% slower")
eq(Game.value(player, "lives"), base.lives + 5, "5 more lives")
near(player:GetAttribute("TowerRate"), Game.value(player, "towerRate"), "the client is told the fire rate")
check(not Feature.off.slots, "Slots is on sale: the core has the equipSlots modifier")
eq(Game.value(player, "equipSlots"), base.equipSlots + 3, "3 more equip slots")
eq(HttpService:JSONDecode(player:GetAttribute("Meta")).slots, base.equipSlots + 3, "and the client is told")
check(#state.equipped <= base.equipSlots + 3, "the mini cannons are equipped into them")
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

print(`PASSED ({T.checks} checks)`)
