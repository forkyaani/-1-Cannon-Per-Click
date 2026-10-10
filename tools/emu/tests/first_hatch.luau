-- A save's first hatch (run with --all-features): never a Common or an Uncommon, always something the egg
-- itself holds, and only that one hatch. Forty new players hatch the Basic Egg twice.
local T = harness.load("_prelude.luau")
local Game, Config = T.Game, T.Config
local check, eq = T.check, T.eq

local egg = Config.Eggs[1]
local inEgg = {}
for _, entry in egg.pets do
	inEgg[entry.id] = true
end
local hatched = {} -- [player] = the ids of what they hatched, in order
Game.on("hatch", function(who: Player, _data, _state, _egg, results)
	hatched[who] = hatched[who] or {}
	for _, result in results do
		table.insert(hatched[who], result.pet)
	end
end)

T.section("forty first hatches")
local firsts, seconds = {}, {}
for id = 101, 140 do
	local who = harness.addPlayer("New" .. id, id)
	harness.flush()
	local data = Game.data(who)
	assert(data, "the player did not load")
	eq(data.totalHatches, 0, `player {id} has never hatched`)
	data.coins = egg.cost * 2
	for _ = 1, 2 do
		harness.advance(0.5)
		harness.fire(T.Marketplace.promptFor[egg.id], "Triggered", who)
	end
	local got = hatched[who] or {}
	eq(#got, 2, `player {id} hatched twice`)
	firsts[Config.Pets[got[1]].rarity] = (firsts[Config.Pets[got[1]].rarity] or 0) + 1
	seconds[Config.Pets[got[2]].rarity] = (seconds[Config.Pets[got[2]].rarity] or 0) + 1
	check(inEgg[got[1]] == true, `player {id}'s first is a mini cannon of that egg`)
	harness.removePlayer(who)
end
print("  first hatches: " .. game:GetService("HttpService"):JSONEncode(firsts))
print("  second hatches: " .. game:GetService("HttpService"):JSONEncode(seconds))
eq(firsts.Common, nil, "no first hatch was a Common")
eq(firsts.Uncommon, nil, "nor an Uncommon")
check((firsts.Rare or 0) >= 30, "most were the egg's Rare")
check((seconds.Common or 0) + (seconds.Uncommon or 0) >= 20, "the second hatch is an ordinary roll again")

print(`first_hatch.luau: {T.checks} checks passed`)
