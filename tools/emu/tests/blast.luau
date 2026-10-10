-- The FIRE button (run with --all-features): what a shot is worth, how many count, how its levels are bought
-- with coins or gems, and where it does nothing. The numbers are src/shared/Features/Blast.luau.
local T = harness.load("_prelude.luau")
local Game, Config = T.Game, T.Config
local player, data, state = T.player, T.data, T.state
local check, eq, act, run = T.check, T.eq, T.act, T.run
local Http = game:GetService("HttpService")
local Blast = require(game:GetService("ReplicatedStorage").Shared.Features.Blast)

local function meta()
	return Http:JSONDecode(player:GetAttribute("Meta_blast"))
end
local function alive()
	local list = {}
	for _, monster in state.monsters do
		if not monster.dead then
			table.insert(list, monster)
		end
	end
	return list
end
local function health(): number
	local total = 0
	for _, monster in alive() do
		total += monster.hp
	end
	return total
end

T.section("the numbers")
check(math.abs(Blast.share(0) - 0.04) < 1e-9 and math.abs(Blast.share(Blast.MAX_LEVEL) - 0.10) < 1e-9, "a shot is 4% of damage per second at level 0 and 10% at the last level")
check(Blast.RATE * Blast.share(Blast.MAX_LEVEL) <= 0.5 + 1e-9, "pressing flat out adds 50% damage at most")
check(Blast.RATE * Blast.share(0) <= 0.2 + 1e-9, "and 20% for a new player")
local gemsForAll, last = 0, 0
for level = 1, Blast.MAX_LEVEL do
	gemsForAll += Blast.cost(level, "gems")
	local coins = Blast.cost(level, "coins")
	check(coins >= last * 1.2, `level {level} costs more coins than the one before ({coins})`)
	last = coins
end
eq(gemsForAll, 1525, "fifty levels cost 1,525 gems")
check(math.abs(Blast.cost(1, "coins") - Config.levelCoins(3)) < Config.levelCoins(3) * 0.05, "the first level costs what clearing Earth level 3 pays")
check(Blast.cost(0, "coins") == nil and Blast.cost(Blast.MAX_LEVEL + 1, "gems") == nil and Blast.cost(1, "candy") == nil, "nothing else has a price")
eq(meta().level, 0, "a new player's button is level 0")

T.section("a shot")
-- A level far too hard for a starter cannon: its monsters stay alive to be counted.
T.debug("wave", 40)
harness.advance(2)
run(6)
check(#alive() > 0, "monsters are on the path")
local dps = player:GetAttribute("CannonPower")
check(dps > 0, "the player has damage per second")
local before, coins, gems = health(), data.coins, data.diamonds
act("blast", 1)
local dealt = before - health()
check(math.abs(dealt - dps * Blast.share(0)) < dps * 0.001 + 1e-6, `one shot takes {Blast.share(0) * 100}% of the damage per second off the lead monster (took {dealt}, dps {dps})`)
eq(data.diamonds, gems, "and pays no gems by itself")
eq(meta().level, 0, "nor a level, however many are fired")
eq(meta().xp, nil, "there is no xp any more")
eq(meta().shots, 1, "one shot is counted")

T.section("how many count")
harness.advance(5)
before = health()
act("blast", 16)
dealt = before - health()
check(math.abs(dealt - dps * Blast.share(0) * Blast.BURST) < dps * 0.001 + 1e-6, `sixteen presses at once count as {Blast.BURST}`)
before = health()
act("blast", 5)
check(before - health() < dps * Blast.share(0) * 1.01, "and right after that almost nothing counts: the allowance fills at 5 a second")
for _, junk in { 0, -3, 1.5, 17, 1e9, "5", true, { 5 } } do
	harness.advance(2)
	before = health()
	act("blast", junk)
	eq(health(), before, "a junk count deals nothing")
end

T.section("levels")
local save = data.features.blast
save.xp = 40 -- a save from the build that levelled by pressing
local price = Blast.cost(1, "coins")
data.coins = price - 1
act("blastBuy", "coins")
eq(meta().level, 0, "a level is not sold for less than its price")
eq(data.coins, price - 1, "and nothing is taken")
data.coins = price + 7
act("blastBuy", "coins")
eq(meta().level, 1, "coins buy the first level")
eq(data.coins, 7, "for exactly its price")
eq(save.xp, nil, "the old xp is gone from the save")
local toasted = false
for _, toast in T.toasts do
	toasted = toasted or string.find(toast.text, "FIRE level 1", 1, true) ~= nil
end
check(toasted, "with a toast")
harness.advance(2)
before = health()
act("blast", 1)
check(math.abs((before - health()) - dps * Blast.share(1)) < dps * 0.001 + 1e-6, "a level-1 shot is worth more")
data.diamonds = Blast.cost(2, "gems") - 1
act("blastBuy", "gems")
eq(meta().level, 1, "nor for fewer gems than its price")
data.diamonds = Blast.cost(2, "gems") + 3
coins = data.coins
act("blastBuy", "gems")
eq(meta().level, 2, "gems buy the next level")
eq(data.diamonds, 3, "for exactly its price")
eq(data.coins, coins, "and no coins")
for _, junk in { "candy", 1, true, { "coins" } } do
	act("blastBuy", junk)
	eq(meta().level, 2, "a junk currency buys nothing")
end
save.level = Blast.MAX_LEVEL
data.coins, data.diamonds = 1e300, 1e6
act("blastBuy", "coins")
act("blastBuy", "gems")
eq(save.level, Blast.MAX_LEVEL, "the last level is the last")
eq(data.diamonds, 1e6, "and takes nothing")

T.section("where it does nothing")
save.level = 3
data.coins = 0
local shots = save.shots
act("setPaused", true)
harness.advance(2)
before = health()
act("blast", 3)
eq(health(), before, "a paused base is not shot at")
eq(save.shots, shots, "and the presses are not counted")
act("setPaused", false)
act("goMarket")
harness.advance(2)
before = health()
act("blast", 3)
eq(health(), before, "nor from the marketplace")
eq(save.shots, shots, "nor counted there")
act("goHome")

T.section("the button")
harness.runClient()
check(harness.errors() == 0, "the client starts with it and nothing errors")

print(`blast.luau: {T.checks} checks passed`)
