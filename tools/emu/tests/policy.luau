-- Paid random items (release plan B9): the odds that are shown are the odds that are rolled, and nothing
-- random is sold for gems or Robux to a player Roblox says may not buy paid random items.
-- Run with: python3 run.py --all-features tests/policy.luau
local T = harness.load("_prelude.luau")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local Config, Game = T.Config, T.Game
local player, data, state = T.player, T.data, T.state
local check, eq, act, debug = T.check, T.eq, T.act, T.debug
local Crates = require(ReplicatedStorage.Shared.Features.Crates)
local Enchant = require(ReplicatedStorage.Shared.Features.Enchant)
local Policy = require(Server.Policy)

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end
local function feature(who: Player, key: string)
	return HttpService:JSONDecode(who:GetAttribute("Meta_" .. key))
end
local function toasted(text: string, since: number): boolean
	for index = since + 1, #T.toasts do
		if string.find(T.toasts[index].text, text, 1, true) then
			return true
		end
	end
	return false
end
local function prompts(): number
	return #harness.prompts()
end
-- One press of an egg stand's prompt (triple: its "Hatch x3").
local function hatch(who: Player, eggId: string, triple: boolean?)
	harness.advance(0.1)
	local prompt = T.Marketplace.promptFor[eggId]
	if triple then
		for candidate, id in T.Marketplace.tripleEggPrompts do
			if id == eggId then
				prompt = candidate
			end
		end
	end
	harness.fire(prompt, "Triggered", who)
end

T.section("the odds shown are the odds rolled")
for _, egg in Config.Eggs do
	for _, luck in { 1, Config.LuckPassMultiplier, Config.LuckPassMultiplier * 1.15, 50 } do
		local total = 0
		local odds = Config.eggOdds(egg, luck)
		for _, entry in odds do
			total += entry.chance
		end
		if not near(total, 100) then
			error(`CHECK FAILED: the {egg.name}'s chances add up to {total} at luck {luck}`)
		end
		-- The roll picks from the same list: a roll at the top lands on the first entry, with its chance.
		local picked, chance = Config.rollEgg(egg, 0.999999, luck)
		local shown
		for _, entry in odds do
			if entry.id == picked then
				shown = entry.chance
			end
		end
		if shown ~= chance or chance <= 0 then
			error(`CHECK FAILED: the {egg.name} rolled {picked} at {chance}% but shows {shown}%`)
		end
	end
end
check(true, `every egg's chances add up to 100 at any luck, and a roll reports the chance that is shown`)
for _, crate in Crates.List do
	local total = 0
	for _, entry in Crates.odds(crate) do
		total += entry.chance
	end
	if not near(total, 100) then
		error(`CHECK FAILED: the {crate.name}'s chances add up to {total}`)
	end
end
check(true, "every crate's chances add up to 100")
for _, key in Enchant.Keys do
	local odds = Enchant.odds(key.id)
	for _, name in { "count", "levels" } do
		local total = 0
		for _, entry in odds[name] do
			total += entry.chance
		end
		if not near(total, 100) then
			error(`CHECK FAILED: the {key.name}'s {name} chances add up to {total}`)
		end
	end
end
check(true, "every enchantment key's chances add up to 100")
-- The egg stands work their odds out from the Luck attribute: it must be the luck the server rolls with.
-- (The server sends it on its next tick, half a second at most after the luck changed.)
harness.step(0.5)
eq(player:GetAttribute("Luck"), Game.luck(player, data, state), "the luck the client is told")
check(Game.luck(player, data, state) >= Config.LuckPassMultiplier, "which has the x3 Luck pass in it")
debug("pass:tripleLuck", 0)
harness.step(0.5)
eq(player:GetAttribute("Luck"), Game.luck(player, data, state), "and follows when the pass goes")
check(Config.Passes.tripleLuck.odds == true, "x3 Luck is marked as a pass that changes the odds")
for key, pass in Config.Passes do
	if key ~= "tripleLuck" and pass.odds then
		error(`CHECK FAILED: {key} is marked as changing the odds`)
	end
end

T.section("a player who may buy paid random items")
eq(Policy.restricted(player), false, "Roblox was asked when they joined")
check(feature(player, "crates").restricted == false and feature(player, "enchant").restricted == false, "the windows are told")
debug("diamonds", 1e6)
debug("coins", 1e30)
local gem = Config.EggById.gem
local hatches = data.totalHatches
hatch(player, "gem")
eq(data.totalHatches, hatches + 1, "the Gem Egg hatches")
eq(data.diamonds, 1e6 - gem.cost, "and is paid for")
local before = prompts()
act("buyPass", "tripleLuck")
eq(prompts(), before + 1, "x3 Luck is offered")

T.section("a player who may not")
harness.setPolicy(true)
local barred = harness.addPlayer("Barred", 2) -- the remotes speak for the newest player from here on
local theirs, theirState = Game.data(barred), Game.state(barred)
assert(theirs and theirState, "the second player did not load")
eq(Policy.restricted(barred), true, "Roblox was asked when they joined")
eq(Policy.restricted(player), false, "the first player's answer is their own")
check(feature(barred, "crates").restricted == true and feature(barred, "enchant").restricted == true, "the windows are told")
debug("diamonds", 1e6)
debug("coins", 1e60)
debug("wave", Config.TotalWaves)
for key in Config.Passes do
	debug("pass:" .. key, 0)
end
debug("pass:tripleHatch", 1)

local function refused(what: string, toast: string, attempt: () -> ())
	local pets, gems, hatched, asked, since = #theirs.pets, theirs.diamonds, theirs.totalHatches, prompts(), #T.toasts
	attempt()
	check(#theirs.pets == pets and theirs.diamonds == gems and theirs.totalHatches == hatched, `{what}: nothing is taken or given`)
	eq(prompts(), asked, `{what}: no Robux prompt`)
	check(toasted(toast, since), `{what}: the toast says "{toast}"`)
end
refused("the Gem Egg", "The Gem Egg cannot be sold in your region", function()
	hatch(barred, "gem")
end)
refused("the Gem Egg x3", "The Gem Egg cannot be sold in your region", function()
	hatch(barred, "gem", true)
end)
refused("x3 Luck", "x3 Luck cannot be sold in your region", function()
	act("buyPass", "tripleLuck")
end)
refused("a gem crate", "cannot be sold in your region", function()
	act("buyCrates", { id = "gemcrate", count = 1 })
end)
refused("a Robux crate", "cannot be sold in your region", function()
	act("buyCrates", { id = "royalcrate", count = 1 })
end)
debug("pet:wooden", 1)
debug("item:enchantkey", 3)
act("goIsland", Enchant.ISLAND)
eq(theirState.island, Enchant.ISLAND, "they are at the Enchanting Table")
local keys = Game.items.count(theirs, "enchantkey")
refused("an enchant roll", "Enchanting cannot be offered in your region", function()
	act("enchant", { pet = "wooden", key = "enchantkey" })
end)
eq(Game.items.count(theirs, "enchantkey"), keys, "and the key is kept")
act("goMarket")

-- What is earned by playing stays open to them.
local coinEgg
for _, egg in Config.Eggs do
	if egg.currency == "coins" and not egg.event then
		coinEgg = egg
		break
	end
end
hatches = theirs.totalHatches
hatch(barred, coinEgg.id)
eq(theirs.totalHatches, hatches + 1, `a coin egg ({coinEgg.name}) still hatches`)
hatch(barred, coinEgg.id, true)
eq(theirs.totalHatches, hatches + 4, "and so does its x3")
act("buyCrates", { id = "woodcrate", count = 1 })
eq(feature(barred, "crates").bought.woodcrate, 1, "a coin crate is still sold")
before = prompts()
act("buyPass", "gameSpeed")
eq(prompts(), before + 1, "a pass that changes no odds is still offered")
harness.removePlayer(barred)
eq(Policy.restricted(barred), nil, "their answer is forgotten when they leave")

T.section("no answer from Roblox is a no, outside Studio")
harness.setStudio(false)
harness.setPolicy(nil)
local waiting = harness.addPlayer("Waiting", 3)
local waitingData = Game.data(waiting)
assert(waitingData, "the third player did not load")
eq(Policy.restricted(waiting), nil, "the lookup failed")
waitingData.diamonds = 1e6
local since = #T.toasts
hatch(waiting, "gem")
eq(waitingData.diamonds, 1e6, "the Gem Egg is not sold")
check(toasted("Still checking whether the Gem Egg can be sold in your region", since), "and the toast says it is still being checked")
-- The refusal asked again. Roblox answers now.
harness.setPolicy(false)
hatch(waiting, "gem")
harness.flush()
eq(Policy.restricted(waiting), false, "asked again, Roblox says yes")
hatch(waiting, "gem")
check(waitingData.diamonds < 1e6, "and the Gem Egg is sold")
harness.setStudio(true)

eq(harness.errors(), 0, "errors in spawned threads")
print(`{T.checks} checks`)
