-- The FIRE button (run with --all-features): what a shot is worth, how many count, how it levels up, and where
-- it does nothing. The numbers are src/shared/Features/Blast.luau.
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
local all = 0
for level = 0, Blast.MAX_LEVEL - 1 do
	all += Blast.need(level)
end
eq(all, 52000, "fifty levels take 52,000 shots")
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
eq(meta().xp, 1, "it is one shot towards the next level")
eq(meta().shots, 1, "and one shot counted")

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
save.xp = Blast.need(0) - 1
harness.advance(2)
act("blast", 1)
eq(meta().level, 1, "the last shot of a level levels the button up")
eq(meta().xp, 0, "and the next level starts at nothing")
local toasted = false
for _, toast in T.toasts do
	toasted = toasted or string.find(toast.text, "FIRE level 1", 1, true) ~= nil
end
check(toasted, "with a toast")
harness.advance(2)
before = health()
act("blast", 1)
check(math.abs((before - health()) - dps * Blast.share(1)) < dps * 0.001 + 1e-6, "a level-1 shot is worth more")
save.level, save.xp = Blast.MAX_LEVEL, 0
harness.advance(2)
act("blast", 1)
eq(meta().level, Blast.MAX_LEVEL, "the last level is the last")
eq(meta().xp, 0, "and collects nothing more")

T.section("where it does nothing")
save.level, save.xp = 3, 0
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
