-- Analytics (run with --all-features): every funnel step is logged once, in whatever order the player reaches
-- them, and never again after a rejoin; an older save stays out of the funnel; purchases are logged; a logger
-- that fails or is missing breaks nothing. The logger is the fake of analytics.pre.luau.
local T = harness.load("_prelude.luau")
local Game, Config = T.Game, T.Config
local player, data = T.player, T.data
local check, eq = T.check, T.eq
local Analytics = require(game:GetService("ServerScriptService").Server.Features.Analytics)
local Passes = require(game:GetService("ServerScriptService").Server.Passes)
local fake = Analytics.logger

-- How often each funnel step was logged for a user: { [step number] = times }, and how many in all.
local function funnel(user: number)
	local times, total = {}, 0
	for _, call in fake.calls do
		if call.kind == "funnel" and call.user == user then
			times[call.step] = (times[call.step] or 0) + 1
			total += 1
		end
	end
	return times, total
end

local function custom(user: number, name: string, field: string?): number
	local count = 0
	for _, call in fake.calls do
		if call.kind == "custom" and call.user == user and call.name == name and (field == nil or call.field == field) then
			count += 1
		end
	end
	return count
end

local function logged(id: string): number
	local times = funnel(player.UserId)
	return times[Analytics.STEPS[id].step] or 0
end

local function once(id: string, what: string)
	eq(logged(id), 1, what)
end

local function never(id: string, what: string)
	eq(logged(id), 0, what)
end

T.section("the steps")
do
	local seen, count = {}, 0
	for _, step in Analytics.STEPS do
		check(seen[step.step] == nil and step.step >= 1 and step.step <= 7, `step {step.step} has a number of its own: {step.name}`)
		seen[step.step] = true
		count += 1
	end
	eq(count, 7, "steps in the funnel")
end

T.section("joining")
once("joined", "joined is logged on the first join")
eq(select(2, funnel(1)), 1, "and nothing else yet")
eq(data.features.analytics.done.joined, true, "it is in the save")
T.run(2)
eq(select(2, funnel(1)), 1, "standing around logs nothing")

T.section("purchases: game passes")
do
	-- The prelude gave this player every pass through the Studio override: each is a pass they did not have.
	local passes = 0
	for key in Config.Passes do
		passes += 1
		eq(custom(1, "PassBought", key), 1, `pass {key} was logged once`)
	end
	eq(custom(1, "PassBought"), passes, "one event per pass")
	for _, call in fake.calls do
		if call.kind == "custom" and call.field == "gameSpeed" then
			eq(call.value, Config.Passes.gameSpeed.price, "the event carries the price in Robux")
		end
	end
	Passes.setForTesting(player, "gameSpeed", true)
	harness.flush()
	eq(custom(1, "PassBought", "gameSpeed"), 1, "a pass the player has already is not logged again")
end

T.section("the steps, out of order")
T.act("goMarket")
once("market", "the marketplace, first")
T.debug("coins", 1e6)
harness.advance(0.2) -- past the action cooldown
harness.fire(T.Marketplace.promptFor[Config.Eggs[1].id], "Triggered", player)
harness.flush()
check(data.totalHatches >= 1, "an egg hatched")
once("hatch", "then the first hatch")
T.act("goHome")
never("tower", "the starter cannon alone is not a tower built")
T.act("upgradeTower", { pad = 1, levels = 1 })
check(data.towers["1"].level >= 2, "the cannon was upgraded")
once("tower", "then the first upgrade")
never("level5", "level 5 is not cleared yet")
never("welcome", "the welcome is not done yet")

T.section("levels, cleared by playing")
T.debug("towers", 60)
T.debug("wave", 5)
do
	local seconds = 0
	while data.bestCleared < 5 and seconds < 240 do
		T.run(2)
		seconds += 2
	end
	check(data.bestCleared >= 5, `level 5 was cleared ({seconds} s)`)
	once("level5", "level 5 cleared is logged")
	T.debug("wave", 10)
	seconds = 0
	while data.bestCleared < 10 and seconds < 240 do
		T.run(2)
		seconds += 2
	end
	check(data.bestCleared >= 10, `level 10 was cleared ({seconds} s)`)
	once("level10", "level 10 cleared is logged")
end

T.section("the welcome, last")
T.act("tutorialWelcome", "skip")
eq(data.features.tutorial.welcomed, true, "the welcome cards are done")
once("welcome", "welcome done is logged")
do
	local times, total = funnel(1)
	eq(total, 7, "funnel events in all")
	for step = 1, 7 do
		eq(times[step], 1, `step {step} was logged once`)
	end
end

T.section("doing it all again logs nothing")
T.act("goMarket")
harness.advance(0.2)
harness.fire(T.Marketplace.promptFor[Config.Eggs[1].id], "Triggered", player)
harness.flush()
T.act("goHome")
T.act("upgradeTower", { pad = 1, levels = 1 })
T.run(4)
eq(select(2, funnel(1)), 7, "still seven")

T.section("a rejoin")
harness.removePlayer(player)
T.run(1)
player = harness.addPlayer("Tester", 1)
harness.flush()
data = Game.data(player)
assert(data and Game.state(player), "the player did not load again")
eq(data.features.analytics.done.market, true, "the steps came back with the save")
T.run(2)
T.act("goMarket")
T.act("goHome")
T.act("upgradeTower", { pad = 1, levels = 1 })
T.run(4)
eq(select(2, funnel(1)), 7, "not one step is logged a second time")

T.section("purchases: developer products")
do
	local granted = 0
	Game.products[777] = function(_buyer: Player): boolean
		granted += 1
		return true
	end
	Game.products[778] = function(_buyer: Player): boolean
		return false
	end
	-- Products are wrapped when a player becomes ready (the features registered theirs long before).
	local buyer = harness.addPlayer("Buyer", 5)
	harness.flush()
	local decision = harness.receipt(buyer, 777, "receipt-1")
	check(string.find(decision, "PurchaseGranted", 1, true) ~= nil, "the purchase is granted as before: " .. decision)
	eq(granted, 1, "by the feature's own handler")
	eq(custom(5, "ProductBought", "777"), 1, "and logged with the product's id")
	harness.receipt(buyer, 777, "receipt-1")
	eq(granted, 1, "the same receipt again grants nothing")
	eq(custom(5, "ProductBought", "777"), 1, "and logs nothing")
	harness.receipt(buyer, 778, "receipt-2")
	eq(custom(5, "ProductBought", "778"), 0, "a purchase that was not granted is not logged")
	local times, total = funnel(5)
	eq(total, 1, "the new player is in the funnel")
	eq(times[1], 1, "at joined")
	harness.removePlayer(buyer)
end

T.section("an older save stays out of the funnel")
do
	local old = harness.addPlayer("Veteran", 3)
	harness.flush()
	local saved = Game.data(old)
	assert(saved and Game.state(old), "the older save did not load")
	eq(saved.bestCleared, 12, "it is the save from before")
	T.run(2)
	eq(select(2, funnel(3)), 0, "nothing is logged for it")
	eq(saved.features.analytics.old, true, "and the save says why")
	harness.removePlayer(old)
	T.run(1)
	old = harness.addPlayer("Veteran", 3)
	harness.flush()
	T.run(2)
	eq(select(2, funnel(3)), 0, "nor on a later join")
	harness.removePlayer(old)
end

T.section("a logger that fails")
do
	fake.fail = true
	local unlucky = harness.addPlayer("Unlucky", 6)
	harness.flush()
	local saved = Game.data(unlucky)
	assert(saved and Game.state(unlucky), "the player did not load")
	T.run(2)
	eq(select(2, funnel(6)), 0, "nothing arrived")
	eq(saved.features.analytics.done.joined, nil, "so the step is not marked as logged")
	harness.removePlayer(unlucky)
	T.run(1)
	fake.fail = false
	unlucky = harness.addPlayer("Unlucky", 6)
	harness.flush()
	T.run(1)
	eq(funnel(6)[1], 1, "the next join logs it")
	harness.removePlayer(unlucky)
end

T.section("no logger at all (Studio, the emulator)")
do
	Analytics.logger = nil
	local before = #fake.calls
	local quiet = harness.addPlayer("Quiet", 7)
	harness.flush()
	local saved = Game.data(quiet)
	assert(saved and Game.state(quiet), "the player did not load")
	T.run(2)
	Passes.setForTesting(quiet, "gameSpeed", true)
	harness.flush()
	eq(#fake.calls, before, "nothing is sent")
	eq(saved.features.analytics, nil, "and nothing is saved: a later live join still starts the funnel")
	harness.removePlayer(quiet)
	Analytics.logger = fake
end

check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
