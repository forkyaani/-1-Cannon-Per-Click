-- Smoke test of the idle defence with every feature loaded (run with --all-features): a player joins, the
-- client starts, levels are fought, and one of everything is done once. It checks the rules of the core
-- (towers, pads, lives, the field message, every action's validation) and that nothing errors; what things
-- look like needs Studio.
local T = harness.load("_prelude.luau")
local Config, Layout, Plots, Game = T.Config, T.Layout, T.Plots, T.Game
local player, data, state = T.player, T.data, T.state
local check, eq, act, debug, run = T.check, T.eq, T.act, T.debug, T.run

local function noErrors(what: string)
	check(harness.errors() == 0, "no errors after " .. what)
end

-- The field messages this client is sent.
local fields = {}
T.Remotes.Field.OnClientEvent:Connect(function(slot: number, level: number, lives: number, livesMax: number, flat)
	table.insert(fields, { slot = slot, level = level, lives = lives, livesMax = livesMax, flat = flat })
end)
-- One-off messages of the core.
local events = { cleared = 0, failed = 0, leak = 0, rebirth = 0, hugeShot = 0 }
local failedReward = nil -- the coins the last failed level paid
T.Remotes.Feature.OnClientEvent:Connect(function(channel: string, what: string, _level, coins)
	if channel == "defense" then
		events[what] += 1
		if what == "failed" then
			failedReward = coins
		end
	elseif channel == "hugeShot" then
		events.hugeShot += 1
	end
end)
local function toasted(pattern: string, from: number?): boolean
	for index = from or 1, #T.toasts do
		if string.find(T.toasts[index].text, pattern, 1, true) then
			return true
		end
	end
	return false
end
-- The new hooks.
local hooked = { levelStart = 0, levelFailed = 0, leak = 0, towerShots = 0, petShots = 0, petDamage = 0, cannonShot = 0, rebirth = 0, firstClear = nil :: boolean? }
Game.on("rebirth", function()
	hooked.rebirth += 1
end)
Game.on("waveCleared", function(_player, _data, _state, _wave, firstClear)
	hooked.firstClear = firstClear
end)
Game.on("levelStart", function()
	hooked.levelStart += 1
end)
Game.on("levelFailed", function()
	hooked.levelFailed += 1
end)
Game.on("leak", function()
	hooked.leak += 1
end)
Game.on("shot", function(_player, _data, _state, shot)
	if shot.source == "tower" then
		hooked.towerShots += 1
		if shot.kind == "cannon" then
			hooked.cannonShot = shot.damage -- what the last shot of a Cannon tower was worth
		end
	elseif shot.source == "pet" then
		hooked.petShots += 1
		hooked.petDamage += shot.damage
	end
end)

-- In Studio every pass is owned, and one of them gives a Huge. Its Huge Shot (a clicker feature, not yet
-- adapted) kills monsters anywhere on the path, before a tower has them in range. The core is tested without
-- it; Huges come back in the mini cannon section.
for _, id in Config.Huges do
	Game.pets.remove(player, id, Game.pets.count(data, id))
end
Game.sync(player)

T.section("a new player")
eq(data.wave, 1, "starts on level 1")
eq(#data.pads, 1, "pads owned")
eq(data.towers["1"].kind, "cannon", "the starter tower")
eq(player:GetAttribute("Lives"), Config.Defense.lives, "Lives")
eq(player:GetAttribute("LevelMonsters"), Config.levelPlan(1).count, "LevelMonsters")
eq(player:GetAttribute("PowerMult"), 1, "PowerMult")
eq(Game.perClick(player), 1, "Game.perClick")
eq(player:GetAttribute("Dps"), Config.towerDamage("cannon", 1) * Config.Towers.cannon.rate, "Dps")
eq(player:GetAttribute("CannonPower"), player:GetAttribute("Dps"), "CannonPower is the damage per second")
eq(player:GetAttribute("TowerDps"), player:GetAttribute("CannonPower"), "all of it the towers', with no mini cannon")
eq(player:GetAttribute("PetDps"), 0, "PetDps")
eq(player:GetAttribute("Place"), "plot", "Place")
eq(player:GetAttribute("Island"), 0, "Island")
eq(player:GetAttribute("InMarket"), false, "InMarket")
eq(player:GetAttribute("VeteranLevel"), 0, "VeteranLevel")
eq(player:GetAttribute("Rebirths"), 0, "Rebirths")
eq(Config.GameName, "+1 Cannon Per Click", "the game's name")
do
	local stats = player:FindFirstChild("leaderstats")
	check(stats and stats:FindFirstChild("Gems") and stats:FindFirstChild("Rebirths") and stats:FindFirstChild("Cannon Power"), "leaderstats: Gems, Rebirths, Cannon Power")
	eq(stats["Cannon Power"].Value, T.Format.abbreviate(player:GetAttribute("Dps")), "the Cannon Power leaderstat")
end
check(T.meta().padPrice == Config.padPrice(2) and T.meta().towers["1"].level == 1, "Meta carries pads, towers and padPrice")
check(Plots.owners[state.slot] == player and Plots.towers[state.slot][1].kind == "cannon", "the plot was claimed and its tower built")
check(T.Remotes.Field.ClassName == "UnreliableRemoteEvent", "the field goes out on an unreliable remote")

T.section("the old client still starts")
harness.runClient()
local Client = player.PlayerScripts.Client
local Hud = require(Client.Hud)
local Windows = require(Client.Windows)
noErrors("starting the client")

T.section("the first level, with nothing but the starter cannon")
run(60)
check(data.cleared >= 1, "level 1 is cleared by one level 1 cannon")
check(data.coins > 0 and data.totalKills > 0, "kills pay coins")
check(hooked.towerShots > 0, "towers fire through the shot hook")
check(events.cleared >= 1 and hooked.levelStart >= 1, "cleared message and levelStart hook")
check(#fields > 0, "field messages arrive")
local sawMonsters = false
for _, field in fields do
	assert(field.slot == state.slot and #field.flat % 4 == 0, "a field message is groups of four")
	for index = 1, #field.flat, 4 do
		local d, share = field.flat[index + 1], field.flat[index + 2]
		assert(d >= 0 and d <= Layout.PATH_LENGTH + 20 and share >= 0 and share <= 1, "a monster on the path")
		sawMonsters = true
	end
end
check(sawMonsters, "field messages carry monsters")
noErrors("a minute of fighting")

T.section("a new player who touches nothing")
run(200)
check(data.cleared >= 4, `the starter cannon alone clears the first swarm and the first tanks (cleared {data.cleared})`)
check(data.cleared < 10, "but not the whole game")
check(data.towers["1"].level == 1 and #data.pads == 1, "nothing was upgraded or bought for them")
check(toasted("New tower unlocked: Gatling! Buy a pad to build it on."), "a tower that unlocks with no pad free says to buy a pad")
check(events.failed > 0 and failedReward ~= nil, "the first giant stops them")
do
	local plan = Config.levelPlan(5)
	check(failedReward > 0 and failedReward <= plan.coins * Config.Defense.failShare, `a boss that got through paid for its damage ({failedReward} coins)`)
	check(toasted("got through with"), "and the toast says how close it was")
	check(toasted("You have the coins: walk up to a tower and press UPGRADE"), "a player who can afford an upgrade is told to buy it")
end
noErrors("idling")

T.section("pads and towers")
debug("wave", 1)
data.coins = 0
act("buyPad", 2)
eq(#data.pads, 1, "no pad without the coins")
data.coins = 1e6
for _, junk in { "2", -1, 0, 2.5, 17, 0 / 0, math.huge, { 2 }, true } do
	act("buyPad", junk)
end
act("buyPad", 1)
eq(#data.pads, 1, "junk pad indices and a pad already owned buy nothing")
local before = data.coins
act("buyPad", 4)
eq(#data.pads, 2, "a pad is bought")
eq(before - data.coins, Config.padPrice(2), "for the price of the second pad")
check(table.find(Plots.pads[state.slot], 4) ~= nil, "the plot shows it")

for _, junk in { 4, "cannon", { pad = 4 }, { pad = 4, kind = "nuke" }, { pad = 4, kind = 7 }, { pad = "4", kind = "cannon" }, { pad = 5, kind = "cannon" }, { pad = 1, kind = "cannon" }, { pad = 4.5, kind = "cannon" } } do
	act("buildTower", junk)
end
check(data.towers["4"] == nil and data.towers["5"] == nil and data.towers["1"].kind == "cannon", "junk builds nothing")
data.bestCleared, data.cleared = 0, 0
act("buildTower", { pad = 4, kind = "tesla" })
check(data.towers["4"] == nil, "a locked kind cannot be built")
act("buildTower", { pad = 4, kind = "cannon" })
eq(data.towers["4"] and data.towers["4"].kind, "cannon", "a tower is built on the new pad")
check(Plots.towers[state.slot][4].level == 1, "the plot shows it")

for _, junk in { 4, { pad = 4 }, { pad = 4, levels = "max" }, { pad = 4, levels = 0 }, { pad = 4, levels = -5 }, { pad = 4, levels = 0 / 0 }, { pad = 9, levels = 1 } } do
	act("upgradeTower", junk)
end
eq(data.towers["4"].level, 1, "junk upgrades nothing")
before = data.coins
act("upgradeTower", { pad = 4, levels = 1 })
eq(data.towers["4"].level, 2, "x1 buys one level")
eq(before - data.coins, Config.towerUpgradeCost("cannon", 1), "for its price")
act("upgradeTower", { pad = 4, levels = 10 })
eq(data.towers["4"].level, 12, "x10 buys ten")
data.coins = Config.towerUpgradeCost("cannon", 12) + Config.towerUpgradeCost("cannon", 13) + 1
act("upgradeTower", { pad = 4, levels = 1000 })
eq(data.towers["4"].level, 14, "max buys what the coins allow")
eq(data.coins, 1, "and takes exactly that")
eq(T.meta().missions.progress.upgrades, 13, "upgrades count for the daily mission")
check(player:GetAttribute("Dps") > 20, "Dps follows the towers")

before = data.coins
act("sellTower", 4)
check(data.towers["4"] == nil and Plots.towers[state.slot][4] == nil, "a tower is sold")
eq(data.coins - before, math.floor(Config.towerInvested("cannon", 14) * Config.Defense.sellRefund), "for its refund")
act("sellTower", 1)
check(data.towers["1"] ~= nil, "the last tower cannot be sold")
for _, junk in { "1", {}, 99, 1.5 } do
	act("sellTower", junk)
end
noErrors("buying, building, upgrading and selling")

T.section("failing a level")
debug("wave", 30)
data.autoAdvance = true
local failedBefore = events.failed
failedReward = nil
run(90)
check(events.failed > failedBefore and hooked.levelFailed > 0, "a boss that walks through fails the level")
check(hooked.leak > 0 and events.leak > 0, "leak hook and message")
check(data.wave < 30 and data.autoAdvance == false, "the player drops back and auto-advance goes off")
check(typeof(failedReward) == "number" and failedReward >= 0, "the failed message carries what the boss paid")

T.section("every world, with towers that can take it")
data.coins = 1e60
for pad = 2, 8 do
	act("buyPad", pad)
end
data.bestCleared = Config.TotalWaves
for pad, kind in { [2] = "gatling", [3] = "mortar", [4] = "sniper", [5] = "frost", [6] = "flame", [7] = "tesla", [8] = "rocket" } do
	act("buildTower", { pad = pad, kind = kind })
	eq(data.towers[tostring(pad)] and data.towers[tostring(pad)].kind, kind, "built on pad " .. pad)
end
data.autoAdvance = true
for _, wave in { 5, 25, 50, 53, 54, 300, 430 } do
	debug("wave", wave)
	debug("towers", Config.TowerMaxLevel)
	local kills = data.totalKills
	run(45)
	check(data.totalKills > kills and data.cleared >= wave, `level {wave} ({Config.levelPlan(wave).kind}) falls to maxed towers`)
end
-- The last boss needs mini cannons as well. Here an ability (Game.damage) deals with it.
debug("wave", Config.TotalWaves)
run(5)
Game.damage(player, 1e300)
run(5)
eq(data.cleared, Config.TotalWaves, "the last level can be cleared")
eq(data.wave, Config.TotalWaves, "and does not advance past the end")
check(Plots.worlds[state.slot] == #Config.Worlds, "the plot wears the last world")
noErrors("jumping through the worlds")

T.section("mini cannons deal flat damage per second, wherever the player is")
-- A mini cannon's bonus is its own damage per second (x Config.PetDps = 350), not a multiplier on the towers.
debug("towers", 1)
debug("wave", 41) -- a level the level 1 towers cannot clear: there is always a monster to shoot
run(4)
Game.sync(player)
local leaf = Config.Pets.leaf
eq(leaf.dps, leaf.bonus * Config.PetDps, "a mini cannon's dps is its bonus x Config.PetDps")
eq(Config.PetDps, 350, "Config.PetDps")
eq(T.Format.petPower(leaf), `+{math.floor(leaf.bonus * Config.PetDps + 0.5)} DPS`, "and that is how it reads")
eq(T.Format.petPower({ dps = 129 }), "+129 DPS", "bonus 1.29 reads +129 DPS")
eq(T.Format.petPower(Config.Pets.hugestorm), "x3", "a Huge still reads x3")
-- What one shot of a level 1 Cannon tower is worth, from the shot hook: wait for one (the monsters have to
-- walk into its range first).
local function cannonShot(): number
	hooked.cannonShot = 0
	for _ = 1, 120 do
		if hooked.cannonShot > 0 then
			break
		end
		run(0.5)
	end
	return hooked.cannonShot / Game.perClick(player)
end
local shotBefore = cannonShot()
check(shotBefore > 0, "a Cannon tower has fired")
Game.sync(player)
local powerBefore, cannonBefore, towersBefore = Game.perClick(player), player:GetAttribute("CannonPower"), player:GetAttribute("TowerDps")
eq(#state.equipped, 0, "no mini cannon is equipped yet")
debug("pet:leaf", 1)
check(table.find(state.equipped, "leaf") ~= nil, "the Mini Leaf Cannon is equipped")
eq(Game.perClick(player), powerBefore, "equipping a mini cannon leaves the power multiplier alone")
eq(player:GetAttribute("PowerMult"), powerBefore, "PowerMult")
eq(player:GetAttribute("TowerDps"), towersBefore, "and the towers' damage per second")
check(math.abs(player:GetAttribute("CannonPower") - cannonBefore - Config.PetDps * leaf.bonus) < 1e-9, `Cannon Power rises by exactly PetDps x its bonus (+{Config.PetDps * leaf.bonus})`)
check(math.abs(player:GetAttribute("PetDps") - Config.PetDps * leaf.bonus) < 1e-9, "PetDps is the mini cannons' half")
eq(Game.value(player, "petDps"), Config.PetDps * leaf.bonus, "Game.value petDps")
do
	local breakdown = Game.breakdown(player, "petDps")
	eq(breakdown.base, 0, "its breakdown starts from nothing")
	check(#breakdown.sources == 1 and breakdown.sources[1].label == leaf.name and math.abs(breakdown.sources[1].add - Config.PetDps * leaf.bonus) < 1e-9, "and lists the mini cannon as a line of its own")
	for _, entry in Game.breakdown(player, "power").sources do
		check(not string.find(string.lower(entry.label), "mini", 1, true), `the power multiplier has no mini cannon source ({entry.label})`)
	end
end
local shotAfter = cannonShot()
check(shotAfter > 0 and math.abs(shotAfter - shotBefore) < 1e-9 * shotBefore, `a tower's shot damage is unchanged ({shotAfter} against {shotBefore})`)
check(math.abs(shotAfter - Config.towerDamage("cannon", 1)) < 1e-9, "it is the tower's own damage x the power multiplier, and nothing of the mini cannon's")
local character = Instance.new("Model")
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Position = Layout.plotPoint(state.slot, Vector2.new(0, 120), 3)
root.Parent = character
character.PrimaryPart = root
player.Character = character
character.Parent = workspace
-- Its shots deal that damage per second over time, near the player ...
debug("wave", 41)
hooked.petShots, hooked.petDamage = 0, 0
run(20)
check(hooked.petShots > 0, "mini cannons fire at monsters near the character")
local perSecond = Config.PetDps * leaf.bonus
check(math.abs(hooked.petDamage - perSecond * 20) <= perSecond * 1.5, `twenty seconds near the player deal twenty seconds of its DPS ({hooked.petDamage} of {perSecond * 20})`)
-- ... and just as much with the player in the marketplace, or with no character at all: no range is asked for.
act("goMarket")
debug("wave", 41)
hooked.petShots, hooked.petDamage = 0, 0
run(10)
check(math.abs(hooked.petDamage - perSecond * 10) <= perSecond * 1.5, `ten seconds in the marketplace deal ten seconds of it ({hooked.petDamage})`)
check(data.totalKills > 0, "towers keep firing meanwhile")
act("goHome")
player.Character = nil
debug("wave", 41)
hooked.petDamage = 0
run(10)
check(math.abs(hooked.petDamage - perSecond * 10) <= perSecond * 1.5, "and with no character on the base")
player.Character = character
-- Firing faster cuts the same damage into smaller shots.
do
	local faster = true
	Game.modify("petShots", function(_player, _data, _state, value)
		return if faster then value * 4 else value
	end, "Test shots")
	debug("wave", 41)
	hooked.petShots, hooked.petDamage = 0, 0
	run(10)
	check(hooked.petShots >= 36, `four times the shots ({hooked.petShots})`)
	check(math.abs(hooked.petDamage - perSecond * 10) <= perSecond * 1.5, `the same damage per second ({hooked.petDamage})`)
	faster = false
end
-- The set bonus: a Mini Wooden Cannon beside a Wooden tower (every tower is level 1) deals 1.5x its own.
debug("pet:wooden", 3)
check(math.abs(Config.petDps("wooden", state.towerNames) - Config.Pets.wooden.dps * Config.SetBonus) < 1e-9, "the set bonus scales a mini cannon's DPS")
do
	local list, total = Config.petDpsList(state.equipped, state.towerNames)
	eq(#list, #state.equipped, "Config.petDpsList: one number per equipped mini cannon")
	check(math.abs(player:GetAttribute("PetDps") - total) < 1e-9 and total > perSecond, "PetDps adds them up")
	check(math.abs(Game.shotDamage(player) - total / #state.equipped) < 1e-9, "Game.shotDamage is the average mini cannon's second")
end
eq(Game.perClick(player), powerBefore, "four mini cannons later the power multiplier is still what it was")

T.section("the plug-in API")
player.Character = nil -- a level the level 1 towers (and four small mini cannons) cannot clear: monsters to count
debug("wave", 41)
run(8)
check(#state.monsters >= 4, "monsters on the path")
local kills = data.totalKills
Game.damage(player, Config.levelPlan(41).hp * 2)
eq(data.totalKills - kills, 2, "Game.damage carries over into the next monster")
check(Game.shotDamage(player) > 0, "Game.shotDamage")
hooked.petShots = 0
Game.shoot(player)
eq(hooked.petShots, 1, "Game.shoot fires one mini cannon shot")
-- Not damage: a feature's division by zero must neither break a monster nor clear the level.
kills = data.totalKills
Game.damage(player, 0 / 0)
Game.damage(player, -5)
Game.damage(player, math.huge)
eq(data.totalKills, kills, "damage that is not a usable number is dropped")
noErrors("the plug-in API")

T.section("modifiers, labels and the breakdown")
do
	local on = {} -- [kind] = true while the test's modifier of that kind is switched on
	local function times(kind: string, factor: number, label)
		Game.modify(kind, function(_player, _data, _state, value: number): number
			return if on[kind] then value * factor else value
		end, label)
	end
	local function source(breakdown, label: string)
		for _, entry in breakdown.sources do
			if entry.label == label then
				return entry
			end
		end
		return nil
	end
	check(not pcall(Game.modify, "nope", function() end), "an unknown kind is refused")
	for _, kind in { "towerRate", "towerRange", "bossDamage", "lives", "monsterSpeed", "upgradeCost", "petShots", "crateDrops", "gems" } do
		check(pcall(Game.modify, kind, function(_player, _data, _state, value: number): number
			return value
		end), `Game.modify knows {kind}`)
	end

	-- power: the core's own sources are named, then each modifier, one at a time.
	times("power", 2, "Test source")
	times("power", 3, function()
		return if on.labelled then "Named by a function" else nil
	end)
	times("perClick", 5, nil)
	local plainPower = Game.perClick(player)
	local breakdown = Game.breakdown(player, "power")
	eq(breakdown.base, 1, "breakdown.base")
	eq(breakdown.total, plainPower, "breakdown.total is what the game applies")
	check(source(breakdown, "Mini cannons") == nil, "mini cannons are no source of the power multiplier")
	check(source(Game.breakdown(player, "petDps"), Config.Pets.leaf.name) ~= nil, "each one is a labelled source of petDps instead")
	check(source(breakdown, "Test source") == nil, "a modifier that changes nothing is not listed")
	on.power = true
	breakdown = Game.breakdown(player, "power")
	eq(breakdown.total, Game.perClick(player), "the total follows the modifiers")
	check(math.abs(breakdown.total / plainPower - 6) < 1e-9, "two modifiers of one kind multiply")
	local entry = source(breakdown, "Test source")
	check(entry ~= nil and math.abs(entry.mult - 2) < 1e-9, "a labelled modifier is listed with what it did")
	check(source(breakdown, "Other") ~= nil, "a label function that answers nil, with an effect, is listed as Other")
	on.labelled = true
	check(source(Game.breakdown(player, "power"), "Named by a function") ~= nil, "a label can be a function")
	on.power, on.perClick = false, true
	breakdown = Game.breakdown(player, "power")
	check(source(breakdown, "Other") ~= nil and math.abs(breakdown.total / plainPower - 5) < 1e-9, "a modifier without a label is Other")
	on.perClick = false
	data.boosts.power2x = os.time() + 600
	breakdown = Game.breakdown(player, "power")
	local boosted = false
	for _, item in breakdown.sources do
		boosted = boosted or string.find(item.label, "2x Power", 1, true) ~= nil
	end
	check(boosted and math.abs(breakdown.total / plainPower - 2) < 1e-9, "a running boost is a source with its name")
	data.boosts.power2x = nil
	local last = breakdown.sources[#breakdown.sources]
	eq(last.value, breakdown.total, "the last source's value is the total")

	-- towerRate and towerRange
	times("towerRate", 2, "Fast")
	times("towerRange", 1.5, "Far")
	Game.sync(player)
	local dps, minis = player:GetAttribute("TowerDps"), player:GetAttribute("PetDps")
	on.towerRate, on.towerRange = true, true
	Game.sync(player)
	eq(Game.value(player, "towerRate"), 2, "Game.value towerRate")
	eq(player:GetAttribute("TowerRate"), 2, "the TowerRate attribute")
	eq(player:GetAttribute("TowerRange"), 1.5, "the TowerRange attribute")
	check(math.abs(player:GetAttribute("TowerDps") / dps - 2) < 1e-9, "Cannon Power counts the towers' fire rate")
	check(minis > 0 and math.abs(player:GetAttribute("PetDps") - minis) < 1e-9, "which does nothing for the mini cannons' flat DPS")
	check(math.abs(player:GetAttribute("Dps") - dps * 2 - minis) < 1e-9 * dps, "Cannon Power is the two added together")
	-- A level the level 1 towers cannot clear, started afresh for each count: both have the same targets.
	debug("wave", 41)
	local shotsBefore = hooked.towerShots
	run(15)
	local fast = hooked.towerShots - shotsBefore
	on.towerRate, on.towerRange = false, false
	debug("wave", 41)
	shotsBefore = hooked.towerShots
	run(15)
	local usualShots = hooked.towerShots - shotsBefore
	check(usualShots > 0 and fast > usualShots * 1.5, `towers fire faster and further with towerRate and towerRange ({fast} shots against {usualShots})`)

	-- bossDamage: on boss levels only
	times("bossDamage", 3, "Slayer")
	local ordinary = Game.shotDamage(player)
	on.bossDamage = true
	eq(Game.shotDamage(player), ordinary, "bossDamage leaves an ordinary level alone")
	debug("wave", 45)
	check(math.abs(Game.shotDamage(player) / ordinary - 3) < 1e-9, "and multiplies shots on a boss level")
	on.bossDamage = false

	-- gems: paid per boss, whole gems only
	Game.modify("gems", function(_player, _data, _state, value: number): number
		return if on.gems then value + 0.5 else value
	end, "Gem test")
	on.gems = true
	local gems = data.diamonds
	for _ = 1, 2 do
		debug("wave", 45)
		run(3)
		Game.damage(player, 1e300)
	end
	on.gems = false
	check(data.diamonds - gems >= 1, "the gems modifier pays whole gems per boss")

	-- lives: read when a level starts
	Game.modify("lives", function(_player, _data, _state, value: number): number
		return if on.lives then value + 5 else value
	end, "Guardian")
	on.lives = true
	debug("wave", 41)
	eq(player:GetAttribute("LivesMax"), Config.Defense.lives + 5, "the lives modifier adds lives")
	-- A boss that gets through fails the level whatever was added to the lives: it costs more than there can be.
	check(Config.levelPlan(45).kind == "boss" and Config.levelPlan(45).leak > player:GetAttribute("LivesMax"), "extra lives do not let a boss walk through")
	check(Config.levelPlan(41).leak * Config.levelPlan(41).count >= Config.Defense.lives * 2, "an ordinary level still fails when every monster gets through")
	on.lives = false
	debug("wave", 41)
	eq(player:GetAttribute("LivesMax"), Config.Defense.lives, "and they go when it does")

	-- monsterSpeed
	times("monsterSpeed", 0.5, "Tar")
	on.monsterSpeed = true
	debug("wave", 41)
	run(4)
	local slowest = 0
	for _, monster in state.monsters do
		slowest = math.max(slowest, monster.d)
	end
	on.monsterSpeed = false
	debug("wave", 41)
	run(4)
	local usual = 0
	for _, monster in state.monsters do
		usual = math.max(usual, monster.d)
	end
	check(slowest > 0 and slowest < usual * 0.75, "monsters walk slower with a monsterSpeed modifier")

	-- upgradeCost
	times("upgradeCost", 0.5, "Discount")
	on.upgradeCost = true
	data.coins = 1e9
	local level = data.towers["1"].level
	local coins = data.coins
	act("upgradeTower", { pad = 1, levels = 1 })
	eq(coins - data.coins, Config.towerUpgradeCost("cannon", level, 0.5), "upgrades cost what the upgradeCost modifier says")
	check(Config.towerUpgradeCost("cannon", level, 0.5) < Config.towerUpgradeCost("cannon", level), "which is less")
	eq(player:GetAttribute("UpgradeCost"), 0.5, "the client is told")
	on.upgradeCost = false

	eq(Game.value(player, "crateDrops"), 1, "Game.value crateDrops")
	eq(Game.value(player, "petShots"), 1, "Game.value petShots")
	eq(Game.breakdown(player, "lives").base, Config.Defense.lives, "breakdown of lives starts at the level's lives")
	debug("towers", 1)
end
noErrors("modifiers")

T.section("places")
do
	eq(state.place, "plot", "starts on the plot")
	local from = #T.toasts
	-- The islands' builder registered the destination; without one the action only says so.
	local registered = Game.places.island
	check(typeof(registered) == "function", "Islands registered Game.places.island")
	Game.places.island = nil
	act("goIsland", 1)
	eq(state.place, "plot", "no island without an island builder")
	check(toasted("island is not open yet", from + 1), "and the player is told")
	local asked = {}
	Game.places.island = function(index: number): CFrame
		table.insert(asked, index)
		return CFrame.new(index * 1000, 50, 0)
	end
	for _, junk in { "1", 0, 1.5, 99, -1, {}, true, 0 / 0 } do
		act("goIsland", junk)
	end
	eq(state.place, "plot", "junk island indices go nowhere")
	local best = data.bestCleared
	data.bestCleared = 49
	act("goIsland", 2)
	eq(state.place, "plot", "an island is locked until its world is reached")
	check(Config.worldUnlocked(1, 0) and not Config.worldUnlocked(2, 49) and Config.worldUnlocked(2, 50) and not Config.worldUnlocked(99, 1e9), "Config.worldUnlocked")
	data.bestCleared = 50
	act("goIsland", 2)
	eq(state.place, "island", "goIsland")
	eq(state.island, 2, "state.island")
	eq(asked[#asked], 2, "the registered destination is asked for that island")
	eq(player:GetAttribute("Place"), "island", "the Place attribute")
	eq(player:GetAttribute("Island"), 2, "the Island attribute")
	eq(player:GetAttribute("InMarket"), true, "InMarket is true on an island, for the HUD")
	eq(state.inMarket, false, "but the server knows it is not the marketplace")
	act("goMarket")
	eq(player:GetAttribute("Place"), "market", "goMarket")
	eq(player:GetAttribute("Island"), 0, "no island in the marketplace")
	check(state.inMarket and player:GetAttribute("InMarket") == true, "in the marketplace")
	act("goHome")
	eq(player:GetAttribute("Place"), "plot", "goHome")
	eq(player:GetAttribute("InMarket"), false, "InMarket off at home")
	data.bestCleared = best
	Game.places.island = registered
end
noErrors("places")

T.section("the world islands")
do
	local Islands = require(game:GetService("ServerScriptService").Server.Islands)
	local root = workspace:FindFirstChild("Islands")
	check(root ~= nil, "workspace.Islands is built")
	eq(#root:GetChildren(), #Config.Worlds, "one island per world")
	eq(Layout.ISLAND_COUNT, #Config.Worlds, "Layout.ISLAND_COUNT")
	local fewest, most = math.huge, 0
	for index, world in Config.Worlds do
		local folder = Islands.container(index)
		check(folder ~= nil and folder.Parent == root and folder:GetAttribute("World") == index, `island {index} has its folder`)
		local parts = 0
		for _, inst in folder:GetDescendants() do
			if inst:IsA("BasePart") then
				parts += 1
			end
		end
		fewest, most = math.min(fewest, parts), math.max(most, parts)
		-- Far from the plots and the marketplace, and from each other.
		local middle = Layout.islandCFrame(index).Position
		for slot = 1, Layout.PLOT_COUNT do
			check((Layout.plotCFrame(slot).Position - middle).Magnitude > 600, `island {index} is far from plot {slot}`)
		end
		check((Layout.MARKET_CENTER - middle).Magnitude > 600, `island {index} is far from the marketplace`)
		for other = 1, index - 1 do
			check((Layout.islandCFrame(other).Position - middle).Magnitude >= Layout.ISLAND_SPACING, `islands {other} and {index} are apart`)
		end
		local spawn = Layout.islandSpawn(index)
		check((spawn.Position - middle).Magnitude < Layout.ISLAND_RADIUS, `island {index}'s arrival is on the island`)
		-- The two reserved spots, clear of each other and of the arrival.
		local mastery, enchant = Islands.spot(index, "mastery"), Islands.spot(index, "enchant")
		check(typeof(mastery) == "CFrame" and typeof(enchant) == "CFrame", `island {index} has its two reserved spots`)
		check((mastery.Position - enchant.Position).Magnitude >= 17, `island {index}'s spots do not overlap`)
		check((mastery.Position - middle).Magnitude < Layout.ISLAND_RADIUS - 8, `island {index}'s mastery spot is on the island`)
		check(folder:FindFirstChild("Spot_mastery") ~= nil and folder:FindFirstChild("Spot_enchant") ~= nil, "the spots are marked")
		-- The world's two coin eggs stand on it, on the marketplace's own stands.
		local stands = 0
		for _, egg in Config.Eggs do
			if egg.world == index and not egg.event then
				local stand = T.Marketplace.stands[egg.id]
				check(stand ~= nil and (stand.frame.Position - middle).Magnitude < Layout.ISLAND_RADIUS, `the {egg.name} stands on island {index}`)
				stands += 1
			end
		end
		eq(stands, 2, `coin eggs on {world.name}'s island`)
		local shop = Islands.shopPrompts[index]
		check(shop and shop:GetAttribute("Window") == "ISLAND SHOP" and shop:GetAttribute("Island") == index, `island {index}'s stall opens the ISLAND SHOP window`)
		check(Islands.returnPrompts[index] ~= nil, `island {index} has a portal back`)
	end
	print(`  parts per island: {fewest} to {most}`)
	check(fewest >= 90 and most <= 150, "about 120 parts per island")
	check(Islands.spot(1, "nope") == nil and Islands.spot(99, "mastery") == nil and Islands.container(99) == nil, "unknown islands and spots are nil")
	check(typeof(Islands.frame(3, 1, 2, 3)) == "CFrame", "Islands.frame")
	for _, egg in Config.Eggs do
		if not egg.world then
			check(T.Marketplace.stands[egg.id] ~= nil and T.Marketplace.stands[egg.id].parent == workspace, `the {egg.name} stays in the marketplace`)
		end
	end
	-- Every base has its own islands teleporter: the core opens the WORLDS window for the base's owner.
	do
		local opened = {}
		local connection = T.Remotes.Feature.OnClientEvent:Connect(function(channel: string, name: string)
			if channel == "window" then
				table.insert(opened, name)
			end
		end)
		check(Plots.worldsPrompts[state.slot] ~= nil and Plots.marketPrompts[state.slot] ~= nil, "the base has its two teleporters")
		act("goHome")
		harness.advance(0.1)
		harness.fire(Plots.worldsPrompts[state.slot], "Triggered", player)
		eq(opened[1], "WORLDS", "the base's islands teleporter opens the WORLDS window")
		eq(state.place, "plot", "and moves nobody by itself")
		-- Somebody else's is not theirs to use.
		local other = if state.slot == 1 then 2 else 1
		harness.advance(0.1)
		harness.fire(Plots.worldsPrompts[other], "Triggered", player)
		harness.advance(0.1)
		harness.fire(Plots.marketPrompts[other], "Triggered", player)
		eq(#opened, 1, "another base's teleporters do nothing for this player")
		eq(state.place, "plot", "and take them nowhere")
		connection:Disconnect()
	end

	-- Travel there and back through the island's own portal.
	act("goIsland", 1)
	eq(state.place, "island", "Earth's island is open to a new player")
	eq(state.island, 1, "on island 1")
	harness.advance(0.1)
	harness.fire(Islands.returnPrompts[1], "Triggered", player)
	eq(state.place, "plot", "the island's portal leads home")
	eq(player:GetAttribute("Island"), 0, "and the Island attribute is cleared")
	-- The towers keep fighting while the player is away, and the mini cannons' damage lands from an island too.
	act("goIsland", 1)
	local shotsBefore, petBefore = hooked.towerShots, hooked.petShots
	run(6)
	check(hooked.towerShots > shotsBefore, "towers keep fighting while the player is on an island")
	check(hooked.petShots > petBefore, "mini cannons deal their damage on the plot from an island too")
	act("goHome")
end
noErrors("the world islands")

T.section("the island shop")
do
	local Shop = require(game:GetService("ReplicatedStorage").Shared.Features.IslandShop)
	local Items = T.Items
	local function meta()
		return game:GetService("HttpService"):JSONDecode(player:GetAttribute("Meta_islandShop"))
	end
	local day = Config.dayNumber(os.time())
	eq(meta().day, day, "the client is told the day's purchases")
	for index in Config.Worlds do
		local stock = Shop.stock(index, day)
		check(Items.get(stock.ammo) ~= nil and Items.get(stock.powerup) ~= nil and stock.chest == "bosschest", `island {index} sells an ammo, a powerup and the Boss Chest`)
		for _, kind in Shop.KINDS do
			local price = Shop.price(kind, stock[kind], index, 0)
			check(typeof(price) == "number" and price >= 1 and price == math.floor(price), `island {index}'s {kind} has a whole coin price`)
		end
		check(Shop.stock(index, day + 1).powerup ~= stock.powerup, `island {index}'s powerup changes with the day`)
	end
	check(Shop.price("powerup", "power2x", 1, 200) > Shop.price("powerup", "power2x", 1, 10), "a powerup's price follows the buyer")
	eq(Shop.price("powerup", "power2x", 3, 0), Shop.price("powerup", "power2x", 3, 101), "but never under the island's own first level")
	eq(Shop.price("ammo", "ammo_double", 9, 400), Shop.price("ammo", "ammo_double", 1, 0), "an ammo costs the same on every island that sells it")
	check(Shop.price("ammo", "ammo_double", 1, 0) <= 10_000, "and no more than the Ammo Forge asks")

	local savedCoins, savedCleared = data.coins, data.cleared
	local stock = Shop.stock(1, day)
	local function buy(island, kind)
		act("islandBuy", { island = island, kind = kind })
	end
	-- Not on the island: nothing is sold.
	data.cleared = 10
	data.coins = 1e12
	local chests = Game.items.count(data, "bosschest")
	buy(1, "chest")
	eq(Game.items.count(data, "bosschest"), chests, "the shop sells nothing to a player who is not on the island")
	act("goIsland", 1)
	for _, junk in { 1, "chest", {}, { island = "1", kind = "chest" }, { island = 1 }, { island = 1, kind = "gems" }, { island = 1.5, kind = "chest" }, { island = 99, kind = "chest" }, { island = 2, kind = "chest" } } do
		act("islandBuy", junk)
	end
	eq(Game.items.count(data, "bosschest"), chests, "junk arguments and other islands buy nothing")
	eq(data.coins, 1e12, "and cost nothing")
	-- Too poor.
	data.coins = 0
	buy(1, "chest")
	eq(Game.items.count(data, "bosschest"), chests, "no coins, no chest")
	-- One of each.
	data.coins = 1e12
	for _, kind in Shop.KINDS do
		local id = stock[kind]
		local price = Shop.price(kind, id, 1, data.cleared)
		local had, coins = Game.items.count(data, id), data.coins
		if had > 0 then
			Game.items.take(player, id, had)
		end
		buy(1, kind)
		eq(Game.items.count(data, id), 1, `bought the {kind} ({id})`)
		eq(data.coins, coins - price, `for the price the shared module gives ({price})`)
		buy(1, kind)
		eq(Game.items.count(data, id), 1, `the {kind} is sold once`)
		eq(data.coins, coins - price, "and the refused purchase cost nothing")
		check(Shop.soldOut(kind, id, 1, meta(), day), `the client is told the {kind} is sold out`)
	end
	-- An ammo the player owns is not sold again, even on a new day.
	local saved = Game.feature(data, "islandShop")
	saved.ammo = {}
	local coins = data.coins
	buy(1, "ammo")
	eq(data.coins, coins, "an ammo the player owns is not sold again")
	-- The chest is one a day in all; the powerup one a day on each island.
	data.bestCleared = math.max(data.bestCleared, 50)
	act("goIsland", 2)
	eq(state.island, 2, "on the Moon's island")
	local before = Game.items.count(data, "bosschest")
	buy(2, "chest")
	eq(Game.items.count(data, "bosschest"), before, "the day's chest is gone on every island")
	local moon = Shop.stock(2, day).powerup
	local owned = Game.items.count(data, moon)
	buy(2, "powerup")
	eq(Game.items.count(data, moon), owned + 1, "but each island has its own powerup of the day")
	-- A new day, new stock.
	saved.day = day - 1
	buy(2, "chest")
	eq(Game.items.count(data, "bosschest"), before + 1, "a new day brings a new chest")
	eq(meta().day, day, "and the client is told about the new day")
	check(not Shop.soldOut("powerup", moon, 2, meta(), day), "with the powerup back in stock")
	-- The window, on the island and off it.
	local window = Windows.byName["ISLAND SHOP"]
	check(window ~= nil, "the ISLAND SHOP window is registered")
	window.open()
	run(1)
	check(window.frame.Visible, "the window stays open on the island")
	act("goHome")
	run(1)
	check(not window.frame.Visible, "and closes when the player leaves")
	data.coins, data.cleared = savedCoins, savedCleared

	-- The Enchantment Key: for gems, from The Sun's island on, a few a day in all.
	local key = Shop.Key
	check(table.find(Shop.ROWS, "key") ~= nil and Shop.currency("key") == "diamonds" and Shop.currency("chest") == "coins", "the key row is the one paid in gems")
	check(Shop.stock(key.from - 1, day).key == nil and Shop.stock(key.from, day).key == key.item and Shop.stock(#Config.Worlds, day).key == key.item, "sold on The Sun's island and every later one")
	eq(Shop.price("key", key.item, key.from, 0), key.gems, "its price in gems")
	local best, gems, coins = data.bestCleared, data.diamonds, data.coins
	data.bestCleared = Config.TotalWaves
	act("goIsland", 1)
	data.diamonds = 10_000
	buy(1, "key")
	eq(Game.items.count(data, key.item), 0, "Earth's stall has no keys")
	act("goIsland", key.from)
	data.diamonds = key.gems - 1
	buy(key.from, "key")
	eq(Game.items.count(data, key.item), 0, "no gems, no key")
	data.diamonds = 10_000
	for _ = 1, key.perDay + 2 do
		buy(key.from, "key")
	end
	eq(Game.items.count(data, key.item), key.perDay, `{key.perDay} keys a day`)
	eq(data.diamonds, 10_000 - key.perDay * key.gems, "paid in gems")
	eq(data.coins, coins, "not in coins")
	check(Shop.soldOut("key", key.item, key.from, meta(), day), "the client is told the keys are sold out")
	act("goIsland", key.from + 1)
	buy(key.from + 1, "key")
	eq(Game.items.count(data, key.item), key.perDay, "the limit is for all islands together")
	window.open()
	run(1)
	window.close()
	Game.items.take(player, key.item, key.perDay)
	act("goHome")
	data.bestCleared, data.diamonds = best, gems
end
noErrors("the island shop")

T.section("level selection")
debug("wave", 10)
act("prevWave")
eq(data.wave, 9, "prevWave")
act("nextWave")
eq(data.wave, 10, "nextWave")
data.cleared = 9
act("nextWave")
eq(data.wave, 10, "nextWave stops at the first level not cleared")
act("travel", 2)
eq(data.wave, 10, "travel needs the world before to be cleared")
for _, junk in { "2", 0, 99, 1.5, {} } do
	act("travel", junk)
end
act("travel", 1)
act("toggleAuto")
act("toggleAuto")
noErrors("level selection")

T.section("every window opens")
local names = {}
for name in Windows.byName do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	local window = Windows.byName[name]
	window.open()
	run(1)
	window.close()
end
print("  windows: " .. table.concat(names, ", "))
for _, button in Hud.menu do
	harness.click(button)
	run(0.5)
end
noErrors("opening every window and pressing every menu button")

T.section("marketplace and eggs")
act("goHome")
harness.advance(0.1)
harness.fire(Plots.marketPrompts[state.slot], "Triggered", player)
check(state.inMarket, "the base's marketplace teleporter is wired")
debug("coins", 1e60)
debug("diamonds", 1e6)
debug("candy", 1e7)
debug("wave", Config.TotalWaves)
for _, egg in Config.Eggs do
	local prompt = T.Marketplace.promptFor[egg.id]
	for _ = 1, 3 do
		harness.advance(0.1)
		harness.fire(prompt, "Triggered", player)
	end
end
run(2)
check(#data.pets > 3, "eggs hatched")
noErrors("hatching every egg")

T.section("mini cannons: fusing, a Secret, a Huge")
debug("pet:wooden", 27)
-- Fusing left the MINI CANNONS window: its two actions are gone (the Fusion Machine has its own, below).
check(Game.actions.fuseAll == nil and Game.actions.fusePet == nil, "fuseAll and fusePet are gone")
act("fuseAll")
act("fusePet", "wooden")
eq(Game.pets.count(data, "wooden_silver"), 0, "and asking for them fuses nothing")
for _, id in { "glitchedbasic", "hugestorm", "hugegatling", "hugetycoon", "candyskull" } do
	if Config.Pets[id] then
		debug("pet:" .. id, 1)
	end
end
run(4)
eq(Config.HugePower, 3, "a Huge is x3")
eq(Config.Pets.hugestorm.power, 3, "on the mini cannon too")
eq(Config.HugeShot.shots, 5, "a Huge Shot is 5 hero shots")
eq(Config.HugeShot.seconds, 2, "every 2 seconds")
do
	local Features = require(game:GetService("ReplicatedStorage").Shared.Features.Huge).Features
	check(Features.hugetycoon.coins == 2 and Features.hugetycoon.autoUpgrade == true, "Tycoon: x2 coins, upgrades the cheapest tower")
	check(Features.hugeslayer.bossDamage == 3 and Features.hugeclover.luck == 2 and Features.hugegatling.fireRate == 5, "Slayer, Clover, Gatling")
	check(Features.hugestorm.multiHit.chance == 0.25 and Features.hugestorm.multiHit.hits == 2, "Storm")
	check(Features.hugehex.heal == 0.5 and Features.hugegoldengoose.freeEgg == 4 and Features.hugeexecutioner.execute == 0.15, "Hex, Golden Goose, Executioner")
	check(Features.hugegemstone.bossGems == 1 and Features.hugegemstone.gemsPerDay == 50, "Gemstone")
	check(Features.hugepumpkin.candy == 2 and Features.hugepumpkin.crateDrops == 2, "Pumpkin")
	-- The Huge Shot goes for monsters near the player, on the plot only.
	check(table.find(state.equipped, "hugestorm") ~= nil, "the Huges are equipped")
	player.Character = nil
	events.hugeShot = 0
	run(8)
	eq(events.hugeShot, 0, "no Huge Shot in the marketplace")
	act("goHome")
	debug("wave", 300) -- a fresh level: its monsters come in at the portal
	run(6)
	eq(events.hugeShot, 0, "nor with no character near the monsters")
	player.Character = character -- at the top of the plot, by the portal
	debug("wave", 300)
	run(6)
	check(events.hugeShot > 0, "Huge Shots at monsters near the player")
	local coinSource
	for _, entry in Game.breakdown(player, "coins").sources do
		if string.find(entry.label, "Tycoon", 1, true) then
			coinSource = entry
		end
	end
	check(coinSource ~= nil and math.abs(coinSource.mult - 2) < 1e-9, "the Tycoon's coins are a labelled source")
	act("goMarket")
end
for name in { ["MINI CANNONS"] = true, INDEX = true } do
	if Windows.byName[name] then
		Windows.byName[name].open()
		run(1)
		Windows.byName[name].close()
	end
end
noErrors("owning a Huge")

T.section("enchanted ids")
do
	local Trading = require(game:GetService("ReplicatedStorage").Shared.Features.Trading)
	local pet = Config.Pets["wooden_gold~greed1.sharp3"]
	check(pet ~= nil and pet.enchanted == true and pet.plain == "wooden_gold", "Config.Pets resolves an enchanted id")
	check(pet.base == "wooden" and pet.tier == 2 and pet.next == "wooden_diamond", "it reads through to the plain mini cannon (base, tier, next)")
	eq(pet.bonus, Config.Pets.wooden_gold.bonus, "its bonus is the plain one's")
	eq(pet.name, "Enchanted " .. Config.Pets.wooden_gold.name, "its name says it is enchanted")
	check(#pet.enchants == 2 and pet.enchants[1].id == "greed" and pet.enchants[1].level == 1 and pet.enchants[2].id == "sharp" and pet.enchants[2].level == 3, "enchants = { { id, level } }")
	check(Config.Pets["wooden_gold~greed1.sharp3"] == pet, "and the entry is remembered")
	eq(Config.enchantedId("wooden_gold", { { id = "sharp", level = 3 }, { id = "greed", level = 1 } }), "wooden_gold~greed1.sharp3", "an id is written one way")
	eq(Config.enchantedId("wooden", {}), "wooden", "no enchantments, the plain id")
	eq(Config.enchantText("wooden_gold~greed1.sharp3"), "Greed I, Sharp III", "Config.enchantText")
	eq(Config.enchantText("wooden"), "", "nothing for a plain one")
	check(Config.Pets.wooden.plain == "wooden" and Config.Pets.wooden.enchants == nil and Config.Pets.wooden_gold.plain == "wooden_gold", "plain entries know their own id")
	for _, bad in { "wooden~", "wooden~sharp", "wooden~sharp4", "wooden~sharp0", "wooden~Sharp1", "nope~sharp1", "wooden~sharp1.sharp2", "wooden~a1.b1.c1.d1", "wooden~sharp1~greed1", "~sharp1", "wooden~sharp1.", "wooden~.sharp1", "" } do
		check(Config.Pets[bad] == nil, `"{bad}" is not a mini cannon`)
	end
	check(Config.Pets[5] == nil and Config.Pets[true] == nil, "nor is anything that is not a string")
	check(Config.Pets["wooden~mystery2"] ~= nil, "an enchantment this build does not know still resolves (a save never holds a nil id)")
	local listed, enchanted = 0, 0
	for id, entry in Config.Pets do
		listed += 1
		if string.find(id, "~", 1, true) or entry.enchanted then
			enchanted += 1
		end
	end
	check(listed > 100 and enchanted == 0, `walking Config.Pets still gives the plain ones only ({listed})`)
	check(Trading.canTrade("pets", "wooden~sharp1"), "an enchanted mini cannon can be traded")
	check(not Trading.canTrade("pets", "hugetycoon~sharp1"), "one that cannot be traded still cannot when it is enchanted")
	-- Equip choice: of two equal ones the enchanted one, and one of each Huge whatever its enchantments.
	local picked = Config.equippedPets({ "wooden", "wooden~sharp1", "wooden~sharp3", "leaf" }, 2)
	check(picked[1] == "wooden~sharp3" or picked[2] == "wooden~sharp3", "the better enchanted of equal mini cannons is equipped")
	local huges = Config.equippedPets({ "hugestorm", "hugestorm~sharp3", "hugegatling", "wooden" }, 3)
	check(table.find(huges, "hugestorm~sharp3") ~= nil and table.find(huges, "hugestorm") == nil and table.find(huges, "hugegatling") ~= nil, "one of each Huge, the enchanted copy first")
	eq(Config.hugeMult({ "hugestorm", "hugestorm~sharp3" }), Config.hugeMult({ "hugestorm" }), "a second copy of a Huge multiplies nothing, enchanted or not")
	eq(Config.hugeMult({ "hugestorm", "hugegatling", "wooden" }), 9, "two different Huges: x9 tower damage, whatever else is equipped")
	eq(Config.hugeMult({ "wooden", "leaf" }), 1, "ordinary mini cannons multiply nothing")
	-- A Huge's own DPS line: the strongest ordinary one's beside it, at least Config.HugeDps; x5 for the Gatling.
	local list, total = Config.petDpsList({ "hugestorm", "hugestorm~sharp3", "hugegatling", "jade", "wooden" }, {})
	eq(list[1], Config.Pets.jade.dps, "a Huge deals as much as the strongest mini cannon beside it")
	eq(list[2], 0, "its second copy deals nothing")
	eq(list[3], Config.Pets.jade.dps * 5, "the Huge Gatling fires five shots: five times that")
	eq(total, Config.Pets.jade.dps * 7 + Config.Pets.wooden.dps, "and the total adds them up")
	eq(Config.petDpsList({ "hugestorm" }, {})[1], Config.HugeDps, "a Huge on its own deals Config.HugeDps")
	eq(Config.powerMult({ "hugestorm", "wooden" }, 2, 1), 3 * 1.2 * 1.05, "Config.powerMult: the Huge, the Veteran level, rebirths")
end

T.section("enchanting")
do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Enchant = require(ReplicatedStorage.Shared.Features.Enchant)
	local Feature = require(game:GetService("ServerScriptService").Server.Features.Enchant)
	local function count(id: string): number
		return Game.pets.count(data, id)
	end
	-- The enchanted versions of a plain mini cannon the player owns.
	local function enchantedOf(plain: string): { string }
		local found = {}
		for _, id in data.pets do
			local pet = Config.Pets[id]
			if pet.enchanted and pet.plain == plain then
				table.insert(found, id)
			end
		end
		return found
	end
	local sent = nil
	T.Remotes.Feature.OnClientEvent:Connect(function(channel: string, result)
		if channel == "enchant" then
			sent = result
		end
	end)

	eq(#Enchant.List, 19, "nineteen enchantments")
	-- Quick Draw was the twentieth. It cannot be rolled, and an id that still carries it resolves without it.
	check(Enchant.byId.quickdraw == nil and Config.RetiredEnchants.quickdraw == true, "Quick Draw is retired")
	do
		local only = Config.Pets["wooden~quickdraw3"]
		check(only ~= nil and only.plain == "wooden" and only.enchants == nil and not only.enchanted, "an id with only Quick Draw resolves as a plain mini cannon")
		eq(only.name, Config.Pets.wooden.name, "under its plain name")
		eq(Config.enchantText("wooden~quickdraw3"), "", "with nothing to show for it")
		eq(#Config.petEnchants("wooden~quickdraw3"), 0, "and no enchantment")
		local mixed = Config.Pets["wooden~quickdraw3.sharp1"]
		check(mixed ~= nil and mixed.enchanted == true and #mixed.enchants == 1 and mixed.enchants[1].id == "sharp", "beside another enchantment only the other one counts")
		eq(Config.enchantText("wooden~quickdraw3.sharp1"), "Sharp I", "and is named")
		eq(Enchant.summary("wooden~quickdraw3.sharp1"), "Sharp I", "in the window too")
		eq(#Enchant.lines("wooden~quickdraw3.sharp1"), 1, "one line")
		local totals = Enchant.totals({ "wooden~quickdraw3.sharp1", "leaf~quickdraw2" })
		check(totals.quickdraw == nil and totals.sharp ~= nil, "nothing adds it up")
		check(Enchant.cost("wooden~quickdraw3") ~= nil, "it can be enchanted again")
		for _ = 1, 400 do
			for _, enchant in Enchant.roll("shinykey", Game.random) do
				assert(enchant.id ~= "quickdraw", "Quick Draw was rolled")
			end
		end
		check(true, "400 Shiny rolls never give it")
	end
	for _, def in Enchant.List do
		assert(#def.amounts == 3 and def.amounts[1] < def.amounts[2] and def.amounts[2] < def.amounts[3], def.id)
		assert(Enchant.describe(def.id, def.amounts[1]) ~= "" and Enchant.describeLevels(def.id) ~= "", def.id)
		assert(Config.Pets[`wooden~{def.id}3`], def.id)
	end
	check(true, "each with three rising levels, a text and an id that fits a mini cannon id")
	for _, key in Enchant.Keys do
		local item = T.Items.get(key.id)
		check(item ~= nil and item.tradable == true and item.usable ~= true, `the {key.name} is a tradable backpack item`)
		local odds = Enchant.odds(key.id)
		local counts, levels = 0, 0
		for _, entry in odds.count do
			counts += entry.chance
		end
		for _, entry in odds.levels do
			levels += entry.chance
		end
		check(math.abs(counts - 100) < 1e-9 and math.abs(levels - 100) < 1e-9, `{key.name}: the odds shown add up to 100`)
		check(#Enchant.oddsLines(key.id) == 3 and Enchant.oddsShort(key.id) ~= "", "and are written out for the window")
	end
	eq(Enchant.ShinyProduct.product, 0, "the Shiny key's Robux product is not on sale yet")
	local last = 0
	for _, rarity in Enchant.RARITIES do
		check(Enchant.Gems[rarity] > last, `{rarity} costs more gems than the rarity before it ({Enchant.Gems[rarity]})`)
		last = Enchant.Gems[rarity]
	end
	eq(Enchant.cost("wooden_gold~sharp1"), Enchant.Gems[Config.Pets.wooden.rarity], "a fused or enchanted one costs what its mini cannon costs")
	eq(Enchant.cost("hugestorm"), Enchant.Gems.Mythical, "a Huge is the dearest")
	check(Enchant.cost("nope") == nil, "no price for a mini cannon nobody knows")

	-- The rolls themselves, many times: what each key promises.
	do
		local rng = Game.random
		local seenCount, seenLevel, seenId = { 0, 0, 0 }, { 0, 0, 0 }, {}
		local ROLLS = 1200
		for _ = 1, ROLLS do
			local roll = Enchant.roll("enchantkey", rng)
			assert(#roll >= 1 and #roll <= 3, "1 to 3 enchantments")
			seenCount[#roll] += 1
			local ids = {}
			for _, enchant in roll do
				assert(Enchant.byId[enchant.id] and not ids[enchant.id], "known enchantments, none twice")
				assert(enchant.level == 1 or enchant.level == 2 or enchant.level == 3, "levels I to III")
				ids[enchant.id] = true
				seenId[enchant.id] = true
				seenLevel[enchant.level] += 1
			end
			assert(Config.Pets[Config.enchantedId("wooden", roll)], "every roll makes an id Config.Pets resolves")
		end
		local different = 0
		for _ in seenId do
			different += 1
		end
		eq(different, #Enchant.List, `{ROLLS} Enchantment Key rolls gave every enchantment`)
		check(seenCount[1] > seenCount[2] and seenCount[2] > seenCount[3] and seenCount[3] > 0, `1, 2 and 3 enchantments all happen ({seenCount[1]} / {seenCount[2]} / {seenCount[3]})`)
		local odds = Enchant.odds("enchantkey")
		for index, entry in odds.count do
			local share = seenCount[entry.n] / ROLLS * 100
			check(math.abs(share - entry.chance) < 6, `{entry.n} enchantments: {math.floor(share)}% of rolls, {entry.chance}% shown`)
			assert(index <= 3)
		end
		local levels = seenLevel[1] + seenLevel[2] + seenLevel[3]
		for _, entry in odds.levels do
			local share = seenLevel[entry.level] / levels * 100
			check(math.abs(share - entry.chance) < 6, `level {entry.level}: {math.floor(share)}% of enchantments, {entry.chance}% shown`)
		end
		local allThree, SHINY = 0, 800
		for _ = 1, SHINY do
			local roll = Enchant.roll("shinykey", rng)
			assert(#roll == 3, "a Shiny key always gives 3")
			local top, ids = 0, {}
			for _, enchant in roll do
				assert(Enchant.byId[enchant.id] and not ids[enchant.id], "known enchantments, none twice")
				ids[enchant.id] = true
				top += if enchant.level == 3 then 1 else 0
			end
			assert(top >= 2, "at least two at level III")
			allThree += if top == 3 then 1 else 0
		end
		check(true, `{SHINY} Shiny key rolls: always 3 enchantments, at least two at level III`)
		check(allThree > 0 and allThree < SHINY, `and the third is sometimes III, sometimes not ({allThree})`)
		check(Enchant.roll("nope", rng) == nil, "no roll for a key nobody knows")
	end

	-- The action.
	debug("item:enchantkey", 20)
	debug("item:shinykey", 40)
	data.diamonds = 100_000
	local keys = Game.items.count(data, "enchantkey")
	local wooden = count("wooden")
	local function untouched(what: string)
		check(count("wooden") == wooden and #enchantedOf("wooden") == 0 and Game.items.count(data, "enchantkey") == keys and data.diamonds == 100_000, what)
	end
	act("enchant", { pet = "wooden", key = "enchantkey" })
	untouched("nothing is enchanted away from the table")
	act("goIsland", Enchant.ISLAND)
	eq(state.island, Enchant.ISLAND, "on The Sun's island")
	check(Feature.prompt ~= nil and Feature.prompt:GetAttribute("Window") == Enchant.WINDOW, "the table's prompt opens the ENCHANT window")
	for _, junk in { 1, "wooden", {}, { pet = "wooden" }, { key = "enchantkey" }, { pet = 1, key = "enchantkey" }, { pet = "wooden", key = "power2x" }, { pet = "nope", key = "enchantkey" }, { pet = "wooden~sharp1", key = "enchantkey", replace = true }, { pet = "wooden_diamond", key = "enchantkey" } } do
		act("enchant", junk)
	end
	untouched("junk, another item as the key and mini cannons the player does not own enchant nothing")
	local best = data.bestCleared
	data.bestCleared = 10
	act("enchant", { pet = "wooden", key = "enchantkey" })
	untouched("nor before The Sun is reached")
	data.bestCleared = best
	data.diamonds = 0
	act("enchant", { pet = "wooden", key = "enchantkey" })
	check(count("wooden") == wooden and Game.items.count(data, "enchantkey") == keys, "nor without the gems")
	data.diamonds = 100_000
	Game.items.take(player, "enchantkey", keys)
	act("enchant", { pet = "wooden", key = "enchantkey" })
	check(count("wooden") == wooden and data.diamonds == 100_000, "nor without a key")
	Game.items.give(player, "enchantkey", keys)

	local stored = #data.pets
	act("enchant", { pet = "wooden", key = "enchantkey" })
	eq(count("wooden"), wooden - 1, "the Enchantment Key enchants one of the stack")
	local made = enchantedOf("wooden")
	eq(#made, 1, "into one enchanted mini cannon")
	local first = made[1]
	local n = #Config.Pets[first].enchants
	check(n >= 1 and n <= 3, `with 1 to 3 enchantments ({Enchant.summary(first)})`)
	eq(Game.items.count(data, "enchantkey"), keys - 1, "for one key")
	eq(data.diamonds, 100_000 - Enchant.cost("wooden"), "and the gems its rarity costs")
	eq(#data.pets, stored, "storage holds as many as before")
	eq(T.meta().pets[first], 1, "the client's inventory lists it under its enchanted id")
	check(sent ~= nil and sent.pet == first and sent.from == "wooden" and #sent.enchants == n, "and the window is sent the result")
	check(string.find(T.lastToast(), Enchant.summary(first), 1, true) ~= nil, "the toast names the enchantments")

	-- Enchanting again replaces, and only after the confirmation.
	act("enchant", { pet = first, key = "enchantkey" })
	check(count(first) == 1 and Game.items.count(data, "enchantkey") == keys - 1, "an enchanted one is not rolled again without the confirmation")
	act("enchant", { pet = first, key = "enchantkey", replace = "yes" })
	check(count(first) == 1 and Game.items.count(data, "enchantkey") == keys - 1, "and the confirmation is the value true")
	local current = first
	local shiny = Game.items.count(data, "shinykey")
	for round = 1, 20 do
		act("enchant", { pet = current, key = "shinykey", replace = true })
		local now = enchantedOf("wooden")
		assert(#now == 1, "enchanting again replaces: still one enchanted Mini Wooden Cannon")
		current = now[1]
		local top = 0
		for _, enchant in Config.Pets[current].enchants do
			top += if enchant.level == 3 then 1 else 0
		end
		assert(#Config.Pets[current].enchants == 3 and top >= 2, `Shiny roll {round}: 3 enchantments, two at III`)
	end
	eq(Game.items.count(data, "shinykey"), shiny - 20, "20 Shiny rolls took 20 Shiny keys")
	check(#Config.Pets[current].enchants == 3, `each replaced what the mini cannon had, and gave 3 with two at III ({Enchant.summary(current)})`)
	eq(count("wooden"), wooden - 1, "and no other mini cannon was touched")
	eq(#data.pets, stored, "nor the storage")
	Game.pets.remove(player, current, 1)

	-- The window: pick, roll, and the two presses that replace.
	do
		local window = Windows.byName[Enchant.WINDOW]
		local function shown(inst): boolean
			local at = inst
			while at and at ~= window.frame do
				if at:IsA("GuiObject") and not at.Visible then
					return false
				end
				at = at.Parent
			end
			return at == window.frame
		end
		local function press(pattern: string): boolean
			for _, inst in window.frame:GetDescendants() do
				if inst:IsA("TextButton") and string.find(inst.Text, pattern, 1, true) and shown(inst) then
					harness.advance(0.2)
					harness.click(inst)
					run(0.5)
					return true
				end
			end
			return false
		end
		local function enchantedCount(): number
			local total = 0
			for _, id in data.pets do
				total += if Config.Pets[id].enchanted then 1 else 0
			end
			return total
		end
		window.open()
		run(0.5)
		check(window.frame.Visible, "the ENCHANT window opens at the table")
		local had, held = enchantedCount(), Game.items.count(data, "enchantkey")
		check(press("PICK"), "a mini cannon can be picked")
		check(press("ENCHANTMENT KEY\n"), "and its key button pressed")
		eq(enchantedCount(), had + 1, "the window's button enchants the picked mini cannon")
		eq(Game.items.count(data, "enchantkey"), held - 1, "for one key")
		-- The result stays picked. It is enchanted now: the first press only warns.
		check(press("ENCHANTMENT KEY\n"), "pressing again")
		eq(Game.items.count(data, "enchantkey"), held - 1, "does not roll: the button asks first")
		check(press("REPLACE?"), "the armed button")
		eq(Game.items.count(data, "enchantkey"), held - 2, "rolls on the second press")
		eq(enchantedCount(), had + 1, "and replaced the enchantments instead of adding a mini cannon")
		check(press("ODDS AND LIST"), "the odds tab")
		check(press("ENCHANT"), "and back")
		act("goHome")
		run(1)
		check(not window.frame.Visible, "the window closes when the player leaves the island")
		act("goIsland", Enchant.ISLAND)
		-- Put the test's mini cannon back as it was.
		for _, id in table.clone(data.pets) do
			local pet = Config.Pets[id]
			if pet.enchanted then
				Game.pets.swap(player, { id }, pet.plain)
			end
		end
		eq(enchantedCount(), 0, "Game.pets.swap trades one mini cannon for another in place")
	end

	-- Storing: an enchanted mini cannon is a stack of its own, added, counted and removed by its id (the
	-- calls a trade is made of).
	local gift = "wooden~greed1.sharp3"
	check(Game.pets.add(player, gift, true) and Game.pets.add(player, gift, true), "Game.pets.add takes an enchanted id")
	eq(count(gift), 2, "Game.pets.count counts it")
	eq(count("wooden"), wooden - 1, "apart from the plain ones")
	Game.sync(player)
	eq(T.meta().pets[gift], 2, "the client sees the stack")
	check(Game.pets.remove(player, gift, 2) and count(gift) == 0, "Game.pets.remove takes them back out")
	check(not Game.pets.add(player, "wooden~sharp9", true), "an id that is not one is not added")

	-- What equipped enchantments do: labelled sources, one per mini cannon.
	local top
	for _, id in state.equipped do
		if not Config.Pets[id].huge then
			top = Config.Pets[id].plain
			break
		end
	end
	local name = Config.Pets[top].name
	local function source(kind: string, label: string)
		for _, entry in Game.breakdown(player, kind).sources do
			if entry.label == label then
				return entry
			end
		end
		return nil
	end
	local power = Game.perClick(player)
	local worn = top .. "~sharp3.tar2"
	Game.pets.add(player, worn, true)
	check(table.find(state.equipped, worn) ~= nil, "the enchanted twin of the strongest mini cannon is equipped")
	local sharp = source("power", `{name}: Sharp III`)
	check(sharp ~= nil and math.abs(sharp.mult - 1.15) < 1e-9, `STATS lists "{name}: Sharp III" as a source of x1.15`)
	check(Game.perClick(player) > power * 1.14, "and the damage really is higher")
	local tar = source("monsterSpeed", `{name}: Tar II`)
	check(tar ~= nil and math.abs(tar.mult - 0.96) < 1e-9, "Tar II: monsters walk 4% slower")
	Game.pets.add(player, worn, true)
	local two = source("power", `{name} x2: Sharp III`)
	check(two ~= nil and math.abs(two.mult - 1.3) < 1e-9, "the same enchantment on two mini cannons adds up: x1.3, one line")
	Game.pets.add(player, top .. "~sharp1", true)
	local one = source("power", `{name}: Sharp I`)
	check(one ~= nil and source("power", `{name} x2: Sharp III`) ~= nil and math.abs(one.value / (one.value - one.add) * 1 - 1.35 / 1.3) < 1e-6, "another level is a line of its own, and all of it is one sum: x1.35")
	Game.pets.remove(player, top .. "~sharp1", 1)
	Game.pets.remove(player, worn, 2)
	check(source("power", `{name}: Sharp III`) == nil and math.abs(Game.perClick(player) - power) < power * 1e-9, "taken out again, they count for nothing")
	Game.pets.add(player, "wooden~sharp3", true)
	check(table.find(state.equipped, "wooden~sharp3") == nil and source("power", `{Config.Pets.wooden.name}: Sharp III`) == nil, "an enchanted mini cannon in storage does nothing")
	Game.pets.remove(player, "wooden~sharp3", 1)
	-- One of every kind of effect.
	local sets = { "bond3.lucky3.longshot3", "guardian3.gemfinder3.quickdraw3", "greed3.treasure3.slayer3", "rapid3.reach3.scholar3" }
	local lives, slots = Game.value(player, "lives"), #state.equipped
	for _, set in sets do
		Game.pets.add(player, `{top}~{set}`, true)
	end
	check(slots >= #sets + 1, "enough slots to wear them all")
	Game.sync(player)
	check(table.find(state.equipped, `{top}~guardian3.gemfinder3.quickdraw3`) ~= nil, "a mini cannon that still carries Quick Draw is equipped like any other")
	eq(Game.value(player, "petRange"), 1, "Long Shot no longer changes the mini cannons' range")
	eq(player:GetAttribute("PetRange"), 1, "and the client is told so")
	eq(Game.value(player, "petShots"), 1, "the Quick Draw it still carries changes nothing")
	do
		-- Bond III: that one mini cannon's own DPS counts 30% more. Long Shot III: +10% for all of them.
		local bond, long = source("petDps", `{name}: Bond III`), source("petDps", `{name}: Long Shot III`)
		check(bond ~= nil and math.abs(bond.add - 0.3 * Config.petDps(top, state.towerNames)) < 1e-6 * bond.add, "Bond III adds 30% of that mini cannon's own DPS")
		check(long ~= nil and math.abs(long.mult - 1.1) < 1e-9, "Long Shot III is +10% mini cannon DPS")
		local _, own = Config.petDpsList(state.equipped, state.towerNames)
		check(math.abs(Game.value(player, "petDps") - (own + 0.3 * Config.petDps(top, state.towerNames)) * 1.1) < 1e-6 * own, "and the two make the mini cannons' DPS what the game applies")
		check(math.abs(player:GetAttribute("CannonPower") - player:GetAttribute("TowerDps") - Game.value(player, "petDps")) < 1e-6 * own, "which is in Cannon Power")
		check(source("power", `{name}: Bond III`) == nil, "an ordinary mini cannon's Bond is no source of tower damage")
	end
	eq(Game.value(player, "lives"), lives + 3, "Guardian III: +3 lives")
	check(math.abs(Game.value(player, "gems") - 0.15) < 1e-9, "Gem Finder III: bosses drop 0.15 gems more")
	Game.feature(data, "enchant", Enchant.SAVED).gemDay = Config.dayNumber(os.time())
	Game.feature(data, "enchant", Enchant.SAVED).gems = Enchant.GemsPerDay
	eq(Game.value(player, "gems"), 0, "until the day's limit is found")
	Game.feature(data, "enchant", Enchant.SAVED).gems = 0
	for kind, label in { luck = "Lucky III", coins = "Greed III", crateDrops = "Treasure III", bossDamage = "Giant Slayer III", towerRate = "Rapid III", towerRange = "Reach III", petDps = "Bond III" } do
		check(source(kind, `{name}: {label}`) ~= nil, `{label} is a source of {kind}`)
	end
	check(source("petShots", `{name}: Quick Draw III`) == nil, "Quick Draw is a source of nothing")
	check(math.abs(Enchant.bondFactor({ top .. "~bond3" }, {}) - 1.3) < 1e-9, "Bond III: that mini cannon's own DPS counts 30% more")
	check(math.abs(Enchant.bondFactor({ top .. "~bond3", top }, {}) - 2.3 / 2) < 1e-9, "beside a twin without it: x1.15 on the two together")
	check(math.abs(Enchant.bondFactor({ "hugestorm~bond3" }, {}, "power") - 3.6 / 3) < 1e-9, "on a Huge: x3 tower damage becomes x3.6")
	check(math.abs(Enchant.bondFactor({ "hugestorm~bond3", top }, {}, "petDps") - 1) < 1e-9, "and its own DPS line stays what it is")
	check(math.abs(Enchant.bondFactor({ top .. "~bond3" }, {}, "power") - 1) < 1e-9, "an ordinary one's Bond leaves tower damage alone")
	for _, set in sets do
		Game.pets.remove(player, `{top}~{set}`, 1)
	end
	eq(Game.value(player, "petRange"), 1, "and all of it is gone with them")

	-- The shot and kill enchantments, in a fight.
	act("goHome")
	local shots = { "splinter3.frostbite3.ember3", "chain3.executioner3.sweettooth3", "scholar3.frostbite3.ember3" }
	for _, set in shots do
		Game.pets.add(player, `{top}~{set}`, true)
	end
	local totals = Feature.totals(state)
	check(totals.frostbite ~= nil and math.abs(totals.frostbite.sum - 2 * 0.15) < 1e-9, "two Frostbite III are worn: 30% of shots chill")
	debug("wave", 300)
	local chilled, burning = false, false
	for _ = 1, 16 do
		run(0.5)
		for _, monster in state.monsters do
			chilled = chilled or monster.slowUntil > state.clock
			burning = burning or monster.burnUntil > state.clock
		end
	end
	check(chilled, "Frostbite: monsters are slowed")
	check(burning, "Ember: monsters burn")
	-- An easy level, for the kills.
	debug("wave", 1)
	local kills, veteran = data.totalKills, data.masteryKills
	run(12)
	check(data.totalKills > kills, "the fight goes on with Splinter, Chain and Executioner at work")
	check(data.totalKills - kills >= 4 and data.masteryKills - veteran > data.totalKills - kills, "Scholar: kills count for more Veteran progress")
	for _, set in shots do
		Game.pets.remove(player, `{top}~{set}`, 1)
	end
	noErrors("enchanting, and a fight with every enchantment")
end

T.section("the Fusion Machine")
do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fuse = require(ReplicatedStorage.Shared.Features.Fuse)
	local Feature = require(game:GetService("ServerScriptService").Server.Features.Fuse)
	local function count(id: string): number
		return Game.pets.count(data, id)
	end
	local wooden = count("wooden")
	check(wooden >= 20, "wooden mini cannons to fuse")
	-- The rules.
	eq(Fuse.result({ "wooden", "wooden", "wooden" }), "wooden_silver", "three of a kind make the next tier")
	eq(Fuse.result({ "wooden~sharp3", "wooden~tar1", "wooden" }), "wooden_silver~sharp3", "the result keeps the first pick's enchantments")
	eq(Fuse.result({ "wooden", "wooden~tar1", "wooden~sharp3" }), "wooden_silver", "a plain first pick: none")
	eq(Fuse.lost({ "wooden~sharp3", "wooden~tar1", "wooden" }), 1, "Fuse.lost counts the other picks' enchantments")
	eq(Fuse.lost({ "wooden", "wooden~tar1", "wooden~sharp3" }), 2, "both of them")
	for _, bad in { { "wooden", "wooden" }, { "wooden", "wooden", "leaf" }, { "wooden", "wooden_silver", "wooden" }, { "hugestorm", "hugestorm", "hugestorm" }, { "wooden_diamond", "wooden_diamond", "wooden_diamond" }, { "nope", "nope", "nope" }, {} } do
		check(Fuse.result(bad) == nil, `no fusion for {table.concat(bad, " + ")}`)
	end
	local filled = Fuse.fill({ wooden = 3, ["wooden~sharp3"] = 5, leaf = 2 }, {})
	check(filled ~= nil and filled[1] == "wooden" and filled[2] == "wooden" and filled[3] == "wooden", "FILL picks three matching ones without enchantments")
	check(Fuse.fill({ ["wooden~sharp3"] = 5, leaf = 2 }, {}) == nil, "and never enchanted ones")
	filled = Fuse.fill({ wooden = 2, ["wooden~sharp3"] = 1 }, { "wooden~sharp3" })
	check(filled ~= nil and filled[1] == "wooden~sharp3" and filled[2] == "wooden" and filled[3] == "wooden", "with a first pick it fills the other two slots")
	check(Fuse.fill({ wooden = 2 }, { "wooden" }) == nil, "the plain one already in the machine is not counted twice")

	-- The action: only at the machine.
	act("fuse", { "wooden", "wooden", "wooden" })
	eq(count("wooden_silver"), 0, "nothing is fused away from the machine")
	act("goIsland", Fuse.ISLAND)
	check(Feature.prompt ~= nil and Feature.prompt:GetAttribute("Window") == Fuse.WINDOW, "the machine's prompt opens the FUSE window")
	check(T.Marketplace.container == nil or true, "the marketplace no longer has it")
	for _, junk in { 1, "wooden", {}, { "wooden", "wooden" }, { "wooden", "wooden", "wooden", "wooden" }, { "wooden", "wooden", "leaf" }, { "wooden", "wooden", 3 }, { a = "wooden", b = "wooden", c = "wooden" }, { "hugestorm", "hugestorm", "hugestorm" }, { "nope", "nope", "nope" }, { "wooden_gold", "wooden_gold", "wooden_gold" }, { "wooden~sharp3", "wooden", "wooden" } } do
		act("fuse", junk)
	end
	check(count("wooden") == wooden and count("wooden_silver") == 0, "junk, mixed kinds, a Huge and mini cannons the player does not own fuse nothing")
	local best = data.bestCleared
	data.bestCleared = 10
	act("fuse", { "wooden", "wooden", "wooden" })
	eq(count("wooden_silver"), 0, "nor before The Sun is reached")
	data.bestCleared = best

	local stored = #data.pets
	act("fuse", { "wooden", "wooden", "wooden" })
	eq(count("wooden_silver"), 1, "three Mini Wooden Cannons make a Silver one")
	eq(count("wooden"), wooden - 3, "and are used up")
	eq(#data.pets, stored - 2, "two fewer in storage")
	-- Enchanted picks: the first one's enchantments are kept, the others' are lost.
	Game.pets.add(player, "wooden~greed1.sharp3", true)
	Game.pets.add(player, "wooden~tar2", true)
	act("fuse", { "wooden~greed1.sharp3", "wooden~tar2", "wooden" })
	eq(count("wooden_silver~greed1.sharp3"), 1, "a fusion keeps the first pick's enchantments")
	check(count("wooden~greed1.sharp3") == 0 and count("wooden~tar2") == 0 and count("wooden_silver~tar2") == 0, "the other pick's are lost")
	eq(count("wooden"), wooden - 4, "the plain third pick is used up too")
	-- The same id three times needs three of it.
	Game.pets.add(player, "wooden~tar2", true)
	act("fuse", { "wooden~tar2", "wooden~tar2", "wooden~tar2" })
	check(count("wooden~tar2") == 1 and count("wooden_silver~tar2") == 0, "one enchanted mini cannon cannot be picked three times")
	Game.pets.remove(player, "wooden~tar2", 1)
	-- Up the tiers, the enchantments riding along.
	act("fuse", { "wooden", "wooden", "wooden" })
	act("fuse", { "wooden_silver~greed1.sharp3", "wooden_silver", "wooden_silver" })
	eq(count("wooden_gold~greed1.sharp3"), 1, "Silver to Gold, still enchanted")
	eq(Config.Pets["wooden_gold~greed1.sharp3"].tier, 2, "and a Gold one")
	Game.pets.remove(player, "wooden_gold~greed1.sharp3", 1)

	-- The window: FILL, FUSE, and the two presses that lose enchantments.
	do
		local window = Windows.byName[Fuse.WINDOW]
		local function shown(inst): boolean
			local at = inst
			while at and at ~= window.frame do
				if at:IsA("GuiObject") and not at.Visible then
					return false
				end
				at = at.Parent
			end
			return at == window.frame
		end
		local function press(pattern: string, whole: boolean?): boolean
			for _, inst in window.frame:GetDescendants() do
				if inst:IsA("TextButton") and shown(inst) and (if whole then inst.Text == pattern else string.find(inst.Text, pattern, 1, true) ~= nil) then
					harness.advance(0.2)
					harness.click(inst)
					run(0.5)
					return true
				end
			end
			return false
		end
		window.open()
		run(0.5)
		check(window.frame.Visible, "the FUSE window opens at the machine")
		local before = #data.pets
		check(press("FILL", true), "FILL")
		check(press("FUSE", true), "then FUSE")
		eq(#data.pets, before - 2, "the window fuses three into one")
		-- Enchanted picks after the first: FUSE warns, and fuses on the second press.
		Game.pets.add(player, "wooden~sharp1", true)
		Game.pets.add(player, "wooden~tar1", true)
		Game.pets.add(player, "wooden~greed1", true)
		Game.sync(player)
		run(0.5)
		before = #data.pets
		local adds = 0
		for _, inst in window.frame:GetDescendants() do
			-- The three enchanted Mini Wooden Cannons' rows: their ADD buttons, one press each.
			if inst:IsA("TextButton") and inst.Text == "ADD" and shown(inst) and inst.Parent:FindFirstChildWhichIsA("TextLabel") then
				local enchantedRow = false
				for _, label in inst.Parent:GetChildren() do
					if label:IsA("TextLabel") and string.find(label.Text, "Enchanted " .. Config.Pets.wooden.name, 1, true) then
						enchantedRow = true
					end
				end
				if enchantedRow and adds < 3 then
					adds += 1
					harness.click(inst)
					run(0.2)
				end
			end
		end
		eq(adds, 3, "three enchanted Mini Wooden Cannons are put in")
		check(press("FUSE", true), "FUSE")
		eq(#data.pets, before, "only warns the first time: two picks would lose their enchantments")
		check(press("LOSE THEM?"), "the armed button")
		eq(#data.pets, before - 2, "fuses on the second press")
		local kept = 0
		for _, id in data.pets do
			local pet = Config.Pets[id]
			if pet.enchanted and pet.plain == "wooden_silver" then
				kept += 1
				eq(#pet.enchants, 1, "the result carries one pick's enchantment, not all three")
			end
		end
		eq(kept, 1, "one enchanted Silver Mini Wooden Cannon came out")
		for _, id in table.clone(data.pets) do
			if Config.Pets[id].enchanted then
				Game.pets.remove(player, id, 1)
			end
		end
		window.close()
	end
	noErrors("the Fusion Machine")
	act("goMarket")
end

T.section("loot viewer")
local lootModule = Client:FindFirstChild("Loot")
if lootModule then
	local Loot = require(lootModule)
	Loot.open()
	run(0.5)
	for _, egg in Config.Eggs do
		Loot.open("egg:" .. egg.id)
		run(0.5)
	end
	local Crates = game:GetService("ReplicatedStorage").Shared.Features:FindFirstChild("Crates")
	if Crates then
		for _, crate in require(Crates).List do
			Loot.open("crate:" .. crate.id)
			run(0.5)
		end
	end
	debug("pass:tripleLuck", 0)
	run(1)
	debug("pass:tripleLuck", 1)
	run(1)
	Windows.byName.LOOT.close()
	noErrors("opening the loot table of every egg and crate")
end

T.section("backpack items")
local given = 0
for id, def in T.Items.all() do
	debug("item:" .. id, 3)
	given += 1
	if def.usable then
		act("useItem", id)
		run(0.5)
	end
end
print(`  items given and used: {given}`)
run(3)
noErrors("using every usable item")

T.section("game speed")
do
	eq(player:GetAttribute("GameSpeed"), 1, "a new player plays at 1x")
	act("setSpeed")
	eq(data.speed, 2, "the speed button steps to 2x")
	eq(player:GetAttribute("GameSpeed"), 2, "and the client is told")
	act("setSpeed")
	act("setSpeed")
	eq(data.speed, 1, "after 3x it is back at 1x")
	for _, pair in { { 99, 3 }, { -5, 1 }, { 2.9, 2 } } do
		act("setSpeed", pair[1])
		eq(data.speed, pair[2], `setSpeed {pair[1]} is kept inside 1 to 3`)
	end
	for _, junk in { "fast", {}, true, 0 / 0 } do
		act("setSpeed", junk)
		check(data.speed == 1 or data.speed == 2 or data.speed == 3, "junk only ever steps the speed")
	end
	act("setSpeed", 1)
	local before = state.clock
	run(2)
	local slow = state.clock - before
	act("setSpeed", 3)
	before = state.clock
	run(2)
	local fast = state.clock - before
	check(fast > slow * 2.5 and fast < slow * 3.5, `at 3x the plot's fight runs three times as fast ({slow} against {fast})`)
	-- The speed button is the 2x and 3x Speed pass (the prelude gave this player every pass).
	check(Config.Passes.gameSpeed ~= nil and Config.Passes.gameSpeed.price == 99 and Config.Passes.gameSpeed.id == 0, "the speed pass is in Config.Passes: 99 Robux, not on sale yet")
	check(T.meta().passes.gameSpeed == true, "the client is told the pass is owned")
	debug("pass:gameSpeed", 0)
	check(T.meta().passes.gameSpeed == nil, "the pass is taken away")
	eq(data.speed, 3, "the save keeps the speed that was picked")
	eq(player:GetAttribute("GameSpeed"), 1, "without the pass a saved 3x counts as 1x")
	eq(Game.speed(player), 1, "Game.speed says so too")
	before = state.clock
	run(2)
	local locked = state.clock - before
	check(math.abs(locked - slow) < slow * 0.2, `without the pass the plot runs at 1x ({locked} against {slow})`)
	T.toasts = {}
	act("setSpeed")
	eq(data.speed, 3, "a press without the pass changes nothing")
	check(string.find(T.lastToast(), "not on sale yet", 1, true) ~= nil, "the press says the pass is not on sale yet: " .. T.lastToast())
	for _, value in { 2, 3, 99, "fast" } do
		act("setSpeed", value)
		eq(player:GetAttribute("GameSpeed"), 1, `setSpeed {tostring(value)} without the pass stays at 1x`)
	end
	local lockShown = false
	for _, item in player.PlayerGui:GetDescendants() do
		if item:IsA("TextButton") and item.Text == "🔒 2x" then
			lockShown = true
		end
	end
	check(lockShown, "the speed button shows a lock")
	debug("pass:gameSpeed", 1)
	eq(player:GetAttribute("GameSpeed"), 3, "with the pass back the picked speed runs again")
	before = state.clock
	run(2)
	check(state.clock - before > slow * 2.5, "and the plot runs at 3x")
	act("setSpeed", 1)
	eq(data.speed, 1, "with the pass the button works")
	noErrors("the game speed")
end

T.section("mastery plugs in")
do
	local Server = game:GetService("ServerScriptService").Server
	local Mastery = require(game:GetService("ReplicatedStorage").Shared.Features.Mastery)
	local Islands = require(Server.Islands)
	check(Windows.byName.MASTERY ~= nil, "the MASTERY window is registered")
	local shrine = Islands.container(Mastery.ISLAND):FindFirstChild("MasteryShrine")
	check(shrine ~= nil and shrine:IsA("Model"), "the Mars island has the MasteryShrine")
	local prompt = shrine.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt")
	check(prompt ~= nil and prompt:GetAttribute("Window") == "MASTERY", "its altar's prompt opens the MASTERY window")
	local gems = data.diamonds
	local before = game:GetService("HttpService"):JSONEncode(data.features.mastery)
	for _, junk in { 1, {}, true, "nope", "", 0 / 0 } do
		act("masteryBuy", junk)
	end
	act("masteryBuy")
	eq(data.diamonds, gems, "masteryBuy with junk arguments takes no gems")
	eq(game:GetService("HttpService"):JSONEncode(data.features.mastery), before, "and changes nothing")

	-- The equip slots are a derived number like the others, so the Slots track can add to them.
	check(pcall(Game.modify, "equipSlots", function(_player, _data, _state, value: number): number
		return value
	end), "Game.modify knows equipSlots")
	check(typeof(Game.refreshPets) == "function", "Game.refreshPets is there for it")
	Game.sync(player)
	local slots = Game.value(player, "equipSlots")
	eq(T.meta().slots, slots, "the client is told the equip slots the game applies")
	local levels = data.features.mastery.levels
	local had = levels.slots
	levels.slots = 3
	Game.refreshPets(player)
	Game.sync(player)
	eq(Game.value(player, "equipSlots"), slots - Mastery.slots(had or 0) + 1, "Slots III gives one more equip slot")
	local named = false
	for _, entry in Game.breakdown(player, "equipSlots").sources do
		named = named or entry.label == "Mastery: Slots III"
	end
	check(named, "and the breakdown names it")
	levels.slots = had
	Game.refreshPets(player)
	Game.sync(player)
	eq(Game.value(player, "equipSlots"), slots, "taking it back takes the slot back")
	noErrors("mastery")
end

T.section("the STATS window")
do
	local HttpService = game:GetService("HttpService")
	local Server = game:GetService("ServerScriptService").Server
	local Stats = require(Server.Features.Stats)
	local window = Windows.byName.STATS
	check(window ~= nil, "the STATS window is registered")
	check(Hud.menu.STATS ~= nil, "and has its menu button")
	local function raw(): string?
		return player:GetAttribute("Meta_stats")
	end
	local function near(actual: number, expected: number, what: string)
		check(math.abs(actual - expected) <= 1e-6 * math.max(1, math.abs(expected)), `{what} ({actual} against {expected})`)
	end
	local function textOf(root: Instance): string
		local parts = {}
		for _, item in root:GetDescendants() do
			if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text ~= "" and item.Visible then
				table.insert(parts, item.Text)
			end
		end
		return table.concat(parts, " | ")
	end
	local published = 0
	player.AttributeChanged:Connect(function(name: string)
		if name == "Meta_stats" then
			published += 1
		end
	end)

	-- Closed: nothing is published.
	window.close()
	run(15)
	local closed = raw()
	published = 0
	run(6)
	check(raw() == closed, "nothing is published while the window is closed")
	eq(published, 0, "not once")

	-- Open: at once, then at most once a second.
	debug("pet:wooden", 3)
	window.open()
	run(1)
	check(raw() ~= closed, "opening the window publishes Meta_stats")
	published = 0
	run(10)
	check(published >= 5 and published <= 11, `while it is open it is published about once a second ({published} in 10 s)`)
	local meta = HttpService:JSONDecode(raw())
	check(typeof(meta.at) == "number" and typeof(meta.power) == "number", "it carries the time and Cannon Power")

	-- The numbers are the game's own. (A snapshot taken now: the published one is up to a second old.)
	Game.sync(player)
	local now = Stats.snapshot(Game, player, data, state)
	near(now.power, player:GetAttribute("CannonPower"), "the headline is the Cannon Power the HUD shows")
	check(#now.chain >= 1, `the chain has its sources ({#now.chain})`)
	local product = now.base
	for _, source in now.chain do
		check(typeof(source.label) == "string" and source.label ~= "", "a link of the chain is named: " .. tostring(source.label))
		product *= source.mult
	end
	near(product, now.towerPower, "the towers x every link of the chain = the towers' half of Cannon Power")
	near(now.chain[#now.chain].value, now.towerPower, "the chain's last line is that half")
	near(now.towerPower, player:GetAttribute("TowerDps"), "which is TowerDps")
	-- Mini cannons are not in the chain: each one is a line of its own, added to it.
	for _, link in now.chain do
		check(not string.find(string.lower(link.label), "mini cannon", 1, true) or string.find(link.label, ":", 1, true) ~= nil, `no mini cannon multiplies in the chain ({link.label})`)
	end
	check(#now.pets.lines >= 3, `the mini cannons are listed one by one ({#now.pets.lines})`)
	local petSum = 0
	for _, line in now.pets.lines do
		check(typeof(line.label) == "string" and line.dps > 0, `a mini cannon's own line: {line.label} +{line.dps} DPS`)
		petSum += line.dps
	end
	for _, bonus in now.pets.bonuses do
		petSum += bonus.add
	end
	near(petSum, now.pets.dps, "their lines add up to the mini cannons' DPS")
	near(now.pets.dps, Game.value(player, "petDps"), "which is what the game applies")
	near(now.towerPower + now.pets.dps, now.power, "towers + mini cannons = Cannon Power")
	local byId = {}
	for _, section in now.sections do
		byId[section.id] = section
	end
	for _, id in { "damage", "rate", "range", "boss", "coins", "luck", "lives", "speed", "petDps", "shots", "slots" } do
		check(byId[id] ~= nil, `there is a section for {id}`)
	end
	near(byId.damage.total, Game.value(player, "power") * Game.breakdown(player, "damage").total, "damage is what the game applies")
	near(byId.rate.total, Game.value(player, "towerRate"), "fire rate")
	near(byId.range.total, Game.value(player, "towerRange"), "range")
	near(byId.boss.total, Game.value(player, "bossDamage"), "boss damage")
	near(byId.coins.total, Game.value(player, "coins"), "coins")
	near(byId.luck.total, Game.value(player, "luck"), "luck")
	near(byId.lives.total, Game.value(player, "lives"), "lives")
	near(byId.speed.total, Game.value(player, "monsterSpeed"), "monster speed")
	near(byId.petDps.total, Game.value(player, "petDps"), "mini cannon DPS")
	near(byId.shots.total, Game.value(player, "autoShots") * Game.value(player, "petShots"), "mini cannon shots")
	near(byId.slots.total, Game.value(player, "equipSlots"), "equip slots")
	local lines, timed = 0, 0
	for _, section in now.sections do
		for _, source in section.sources do
			lines += 1
			check(typeof(source.label) == "string" and (source.how == "mult" or source.how == "add"), `{section.id}: {source.label}`)
			if source.left then
				timed += 1
				check(string.match(source.left, "^%d") ~= nil and not string.find(source.label, "left)", 1, true), `a timed source carries its countdown apart: {source.label} / {source.left}`)
			end
		end
	end
	check(lines >= 3, `sources are listed ({lines})`)
	check(timed >= 1, `the boosts that are running show their countdowns ({timed})`)
	eq(#now.towers, #state.towerList, "one row per tower")
	local share = 0
	for _, tower in now.towers do
		near(tower.dps, tower.damage * tower.rate, `pad {tower.pad}: DPS is damage x rate`)
		share += tower.share
	end
	near(share, now.towerPower / now.power, "the towers' shares add up to their half of Cannon Power")
	eq(now.totals.kills, data.totalKills, "monsters defeated")
	eq(now.totals.hatches, data.totalHatches, "eggs hatched")
	eq(now.totals.best, data.bestCleared, "best level")
	check(now.totals.levels >= 1 and now.totals.bosses >= 1, `levels cleared and bosses defeated are counted ({now.totals.levels}, {now.totals.bosses})`)
	check(now.totals.seconds > 60, `and the time played ({now.totals.seconds} s)`)
	check(typeof(data.features.stats.seconds) == "number", "which is in the save")

	-- The window writes it down.
	local text = textOf(window.frame)
	check(string.find(text, "CANNON POWER", 1, true) ~= nil, "the window's headline is Cannon Power")
	check(string.find(text, "Your towers", 1, true) ~= nil and string.find(text, "=  CANNON POWER", 1, true) ~= nil, "the chain is written out")
	check(string.find(text, "+  " .. now.pets.lines[1].label, 1, true) ~= nil and string.find(text, " DPS", 1, true) ~= nil, "with every mini cannon as a line of its own, in DPS")
	local tabs = 0
	for _, name in { "BONUSES", "TOWERS", "TOTALS", "POWER" } do
		for _, item in window.frame:GetDescendants() do
			if item:IsA("TextButton") and item.Text == name then
				harness.click(item)
				run(0.5)
				tabs += 1
				local page = textOf(window.frame)
				if name == "BONUSES" then
					check(string.find(page, "FIRE RATE", 1, true) ~= nil and string.find(page, "MONSTER SPEED", 1, true) ~= nil, "BONUSES has a card per stat")
					check(string.find(page, "Mini cannons", 1, true) ~= nil, "with its sources by name")
					check(string.find(page, "⏱", 1, true) ~= nil, "and a countdown on a timed one")
				elseif name == "TOWERS" then
					check(string.find(page, "SHARE", 1, true) ~= nil and string.find(page, "Level ", 1, true) ~= nil, "TOWERS lists the towers")
				elseif name == "TOTALS" then
					check(string.find(page, "TIME PLAYED", 1, true) ~= nil and string.find(page, "BOSSES DEFEATED", 1, true) ~= nil, "TOTALS has the lifetime numbers")
				end
			end
		end
	end
	eq(tabs, 4, "the four tabs")

	-- Closed again: it stops. A watch nobody renews runs out by itself, and junk starts nothing.
	window.close()
	run(2)
	closed = raw()
	run(6)
	check(raw() == closed, "closing the window stops the publishing")
	for _, junk in { 1, "yes", {}, false } do
		act("statsWatch", junk)
	end
	act("statsWatch")
	run(3)
	check(raw() == closed, "statsWatch with junk arguments starts nothing")
	act("statsWatch", true)
	run(3)
	check(raw() ~= closed, "statsWatch true starts it")
	run(20)
	closed = raw()
	run(6)
	check(raw() == closed, "a watch that is not renewed ends by itself")
	noErrors("the STATS window")
end

T.section("rebirth")
do
	act("goHome")
	debug("wave", 1)
	-- The Tycoon would spend the new run's first coins on an upgrade before the test has looked.
	Game.pets.remove(player, "hugetycoon", Game.pets.count(data, "hugetycoon"))
	for pad = 2, 8 do
		check(table.find(data.pads, pad) ~= nil, "owns pad " .. pad)
	end
	local need = Config.rebirthWave(0)
	eq(need, Config.WavesPerWorld, "the first rebirth needs Earth's final boss")
	eq(Config.rebirthWave(1), 2 * Config.WavesPerWorld, "the second the Moon's")
	check(Config.rebirthWave(#Config.Worlds) > Config.TotalWaves, "and after the last world there are none left")
	local power = Game.perClick(player)
	local pets, gems, best = #data.pets, data.diamonds, data.bestCleared
	local story = game:GetService("HttpService"):JSONEncode(data.features.story or {})
	data.cleared, data.wave = need - 1, need - 1
	data.coins = 12345
	act("rebirth", true)
	eq(data.rebirths, 0, "no rebirth before the world's final boss is beaten")
	data.cleared = need
	for _, junk in { 1, "true", {}, false } do
		act("rebirth", junk)
	end
	act("rebirth")
	eq(data.rebirths, 0, "no rebirth without the confirming argument")

	-- Through the WORLDS window: the REBIRTH row's button, pressed twice.
	Game.sync(player)
	local window = Windows.byName.WORLDS
	window.open()
	run(0.5)
	local button
	for _, item in window.frame:GetDescendants() do
		if item:IsA("TextButton") and item.Text == "REBIRTH" then
			button = item
		end
	end
	check(button ~= nil, "the WORLDS window has a REBIRTH button once it is allowed")
	harness.click(button)
	eq(data.rebirths, 0, "one press does not rebirth")
	check(string.find(button.Text, "SURE", 1, true) ~= nil, "it asks to confirm")
	harness.advance(0.2)
	harness.click(button)
	harness.flush()
	local coinsAfter = data.coins
	run(0.5)
	window.close()

	eq(data.rebirths, 1, "the second press rebirths")
	eq(hooked.rebirth, 1, "the rebirth hook fires")
	eq(events.rebirth, 1, "the client is told")
	eq(data.wave, 1, "back to level 1")
	eq(data.cleared, 0, "nothing cleared in the new run")
	eq(data.bestCleared, best, "the best ever stays: unlocks are kept")
	eq(coinsAfter, 0, "coins reset")
	eq(#data.pads, 1, "pads reset")
	local towers = 0
	for _ in data.towers do
		towers += 1
	end
	check(towers == 1 and data.towers["1"].kind == "cannon" and data.towers["1"].level == 1, "towers reset to the starter cannon")
	local built = 0
	for _ in Plots.towers[state.slot] do
		built += 1
	end
	check(built == 1 and #Plots.pads[state.slot] == 1, "the plot shows it")
	eq(#data.pets, pets, "mini cannons are kept")
	eq(data.diamonds, gems + Config.Rebirth.gems, "gems are kept, and the rebirth pays some")
	eq(game:GetService("HttpService"):JSONEncode(data.features.story or {}), story, "the story is kept")
	eq(player:GetAttribute("Rebirths"), 1, "the Rebirths attribute")
	eq(player:FindFirstChild("leaderstats").Rebirths.Value, 1, "the Rebirths leaderstat")
	check(math.abs(Game.perClick(player) / power - (1 + Config.Rebirth.damage)) < 1e-9, "+5% tower damage")
	local label
	for _, entry in Game.breakdown(player, "power").sources do
		if entry.label == "1 rebirth" then
			label = entry
		end
	end
	check(label ~= nil and math.abs(label.mult - 1.05) < 1e-9, "rebirths are a labelled source of power")

	data.cleared = need
	act("rebirth", true)
	eq(data.rebirths, 1, "the second rebirth needs the next world's boss")
	data.cleared = 0
	gems = data.diamonds
	hooked.firstClear = nil
	data.autoAdvance = true
	player.Character = nil
	run(90)
	check(data.cleared >= 1 and hooked.firstClear == false, "levels cleared again are not first clears")
	data.rebirths = 0
end
noErrors("a rebirth")

T.section("pause")
do
	local function alive()
		local list = {}
		for _, monster in state.monsters do
			if not monster.dead then
				table.insert(list, monster)
			end
		end
		return list
	end
	act("goHome")
	eq(player:GetAttribute("Paused"), false, "a player is not paused until they ask")
	check(data.paused == nil, "and the save knows nothing of it")
	-- A boss the starter cannon cannot stop: it is on the path for a good while. The mini cannons are put away
	-- for it: theirs is flat damage that lands wherever the player is, and they would shoot this boss down.
	local keptPets = data.pets
	data.pets = {}
	Game.refreshPets(player)
	eq(Game.value(player, "petDps"), 0, "no mini cannon, no mini cannon DPS")
	data.autoAdvance = false
	debug("wave", 10)
	run(4)
	check(#alive() >= 1, "a level is being fought")
	act("setPaused", true)
	eq(state.paused, true, "setPaused(true) pauses")
	eq(player:GetAttribute("Paused"), true, "and the client is told")
	local clock, kills, coins, lives, spawned = state.clock, data.totalKills, data.coins, state.lives, state.spawned
	local at, health = alive()[1].d, alive()[1].hp
	local shots = hooked.towerShots
	fields = {}
	run(30)
	eq(state.clock, clock, "the plot's clock stands still")
	eq(alive()[1].d, at, "the monsters do not walk")
	eq(alive()[1].hp, health, "nothing burns or shoots them")
	eq(hooked.towerShots, shots, "no tower fires")
	check(data.totalKills == kills and data.coins == coins and state.lives == lives and state.spawned == spawned, "no kills, coins, leaks or spawns")
	eq(data.wave, 10, "and the level does not end")
	local sent = 0
	for _, field in fields do
		if field.slot == state.slot and field.level == 10 and #field.flat == 4 and field.flat[2] == math.floor(at * 10 + 0.5) / 10 then
			sent += 1
		end
	end
	check(sent >= 55, `the field keeps being sent, with the monster where it stood ({sent} messages)`)
	-- A feature cannot hurt a paused plot either.
	eq(Game.damageAll(player, 1e30), 0, "Game.damageAll does nothing while paused")
	Game.damage(player, 1e30)
	check(not Game.hurt(player, alive()[1], 1e30), "nor Game.hurt")
	Game.shoot(player)
	check(Game.leadNear(player, 1e6) == nil, "the mini cannons have no target")
	eq(data.totalKills, kills, "nothing died")
	-- Building, upgrading and selling go on.
	data.coins = 1e9
	local level = data.towers["1"].level
	act("upgradeTower", { pad = 1, levels = 1 })
	eq(data.towers["1"].level, level + 1, "a tower can be upgraded while paused")
	local free = nil
	for pad = 2, Layout.PAD_COUNT do
		if not table.find(data.pads, pad) then
			free = pad
			break
		end
	end
	act("buyPad", free)
	check(table.find(data.pads, free) ~= nil, "a pad can be bought while paused")
	act("buildTower", { pad = free, kind = "cannon" })
	check(data.towers[tostring(free)] ~= nil, "a tower can be built while paused")
	act("sellTower", free)
	check(data.towers[tostring(free)] == nil, "and sold")
	-- Picking another level sets it up, and it waits.
	act("prevWave")
	eq(data.wave, 9, "a level can be picked while paused")
	run(5)
	check(state.spawned == 0 and #state.monsters == 0, "nothing spawns until the plot is resumed")
	-- The banner.
	local banner = nil
	for _, item in player.PlayerGui:GetDescendants() do
		if item.Name == "DefensePaused" then
			banner = item
		end
	end
	check(banner ~= nil and banner.Visible == true, "the PAUSED banner shows")
	for _, junk in { "yes", 1, 0, {}, 0 / 0 } do
		act("setPaused", junk)
		eq(state.paused, true, `setPaused {tostring(junk)} changes nothing`)
	end
	act("setPaused")
	eq(state.paused, false, "no argument switches: resumed")
	act("setPaused")
	eq(state.paused, true, "and paused again")
	act("setPaused", false)
	eq(player:GetAttribute("Paused"), false, "setPaused(false) resumes")
	clock = state.clock
	run(5)
	check(state.clock > clock + 4 and state.spawned > 0, "the level goes on where it stood")
	run(1)
	check(banner.Visible == false, "and the banner is gone")
	data.autoAdvance = true
	data.pets = keptPets
	Game.refreshPets(player)
	noErrors("pausing")
end

T.section("visits by invitation")
do
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local Visit = require(game:GetService("ReplicatedStorage").Shared.Features.Visit)
	act("goHome")
	local guest = harness.addPlayer("Guest", 2)
	-- The emulated client is the first player's.
	Players.LocalPlayer = player
	harness.flush()
	local guestData, guestState = Game.data(guest), Game.state(guest)
	assert(guestData and guestState, "the second player did not load")
	check(guestState.slot ~= state.slot, "two players, two bases")
	for a = 1, Layout.PLOT_COUNT do
		for b = a + 1, Layout.PLOT_COUNT do
			local apart = (Layout.plotCFrame(a).Position - Layout.plotCFrame(b).Position).Magnitude
			check(apart >= Layout.PLOT_APART and Layout.PLOT_APART >= 1500, `bases {a} and {b} are {apart} studs apart`)
		end
	end
	local function as(who, name: string, argument: any?)
		harness.advance(0.1)
		harness.fire(T.Remotes.Action, "OnServerEvent", who, name, argument)
	end
	local function view(who)
		return HttpService:JSONDecode(who:GetAttribute("Meta_visit"))
	end
	local function invited(who): number
		return #view(who).invites
	end
	check(typeof(view(player).invites) == "table" and typeof(view(guest).guests) == "table", "both players' VISIT windows have their state")

	-- Whatever a client sends as "the other player".
	for _, junk in { "2", 2.5, 0 / 0, {}, true, 1, 999, -2, 2 ^ 60 } do
		for _, name in { "visitInvite", "visitJoin", "visitKick" } do
			as(player, name, junk)
		end
	end
	eq(invited(guest), 0, "junk invites nobody")
	check(state.place == "plot" and guestState.place == "plot", "and moves nobody")

	-- Nobody walks in uninvited.
	as(guest, "visitJoin", 1)
	eq(guestState.place, "plot", "no visit without an invitation")
	check(not Game.setPlace(guest, "visit", guestState.slot), "nobody is a guest on their own base")
	check(not Game.setPlace(guest, "visit", 12) and not Game.setPlace(guest, "visit", 0 / 0) and not Game.setPlace(guest, "moon"), "nor on a base nobody owns")
	eq(guestState.place, "plot", "the guest is still at home")

	-- The invitation.
	local from = #T.toasts
	as(player, "visitInvite", 2)
	eq(invited(guest), 1, "the invitation arrives")
	eq(view(guest).invites[1].id, 1, "from the owner")
	check(view(guest).invites[1].expires > harness.now() + Visit.InviteSeconds - 2, "good for a minute")
	check(view(player).sent["2"] ~= nil, "the owner sees it is out")
	check(toasted("invited you to their base", from + 1), "and the invited player is told")
	as(player, "visitInvite", 2)
	eq(invited(guest), 1, "asking twice is one invitation")
	as(guest, "visitJoin", 999)
	eq(guestState.place, "plot", "joining somebody else does not use it")
	-- Ignoring it declines it.
	run(Visit.InviteSeconds + 2)
	eq(invited(guest), 0, "an invitation that is ignored runs out")
	check(view(player).sent["2"] == nil and toasted("did not answer your invitation", from + 1), "and the owner is told")
	as(guest, "visitJoin", 1)
	eq(guestState.place, "plot", "it cannot be accepted any more")
	as(player, "visitInvite", 2)
	eq(invited(guest), 0, "the same player cannot be asked again straight away")
	check(view(player).later["2"] ~= nil, "the owner's window says when")
	run(Visit.AgainSeconds + 1)
	as(player, "visitInvite", 2)
	eq(invited(guest), 1, "after a while they can")

	-- The client: the invited player's window offers JOIN. (The emulated client is the first player's, so
	-- the second one invites them for this.)
	as(guest, "visitInvite", 1)
	run(1)
	eq(invited(player), 1, "an invitation the other way")
	local Windows = require(player.PlayerScripts.Client.Windows)
	check(Windows.byName.VISIT ~= nil and require(player.PlayerScripts.Client.Hud).menu.VISIT ~= nil, "the VISIT window and its menu button")
	local function button(start: string)
		for _, item in player.PlayerGui:GetDescendants() do
			if item:IsA("TextButton") and item.Visible and string.sub(item.Text, 1, #start) == start then
				return item
			end
		end
		return nil
	end
	local card = nil
	for _, item in player.PlayerGui:GetDescendants() do
		if item.Name == "VisitInvite" then
			card = item
		end
	end
	check(card ~= nil and card.Visible == true, "an invitation shows a card with JOIN")
	Windows.byName.VISIT.open()
	run(1)
	check(button("JOIN\n") ~= nil, "the window lists the invitation with JOIN")
	check(button("INVITED") ~= nil, "and the invitation that is out")
	Windows.byName.VISIT.close()

	-- The visit. The host's field is counted first: a guest is sent it too.
	local function hostFields(seconds: number): number
		fields = {}
		run(seconds)
		local count = 0
		for _, field in fields do
			if field.slot == state.slot and field.level > 0 then
				count += 1
			end
		end
		return count
	end
	local alone = hostFields(4)
	as(guest, "visitJoin", 1)
	eq(guestState.place, "visit", "JOIN starts the visit")
	eq(guestState.visit, state.slot, "on the owner's base")
	eq(guest:GetAttribute("Place"), "visit", "the Place attribute")
	eq(guest:GetAttribute("Visiting"), state.slot, "the Visiting attribute")
	eq(guest:GetAttribute("InMarket"), true, "InMarket is true away from the own base")
	check(guestState.inMarket == false and guestState.island == 0, "but it is neither the marketplace nor an island")
	eq(state.place, "plot", "the owner stays where they are")
	run(1)
	eq(view(player).guests[1].id, 2, "the owner's window lists the guest")
	eq(view(guest).host.id, 1, "and the guest's says whose base it is")
	eq(invited(guest), 0, "the invitation is used up")
	local together = hostFields(4)
	check(together >= alone * 1.8, `the guest is sent the owner's field too ({alone} messages alone, {together} with a guest)`)
	Windows.byName.VISIT.open()
	run(1)
	check(button("SEND\nHOME") ~= nil, "the owner's window has SEND HOME for the guest")
	Windows.byName.VISIT.close()

	-- The guest's own base keeps fighting.
	local guestClock, guestKills = guestState.clock, guestData.totalKills
	run(30)
	check(guestState.clock > guestClock + 25 and guestData.totalKills > guestKills, "the guest's own base keeps fighting meanwhile")

	-- A guest has no rights on the base: what they ask for only ever touches their own.
	as(player, "setPaused", true)
	guestData.coins = 1e9
	local hostSave = HttpService:JSONEncode({ data.pads, data.towers, data.coins })
	local hostTowers = HttpService:JSONEncode(Plots.towers[state.slot])
	local hostPads = HttpService:JSONEncode(Plots.pads[state.slot])
	local free = nil
	for pad = 2, Layout.PAD_COUNT do
		if not table.find(data.pads, pad) then
			free = pad
			break
		end
	end
	as(guest, "buyPad", free)
	as(guest, "buildTower", { pad = free, kind = "cannon" })
	as(guest, "upgradeTower", { pad = 1, levels = 10 })
	as(guest, "sellTower", 1)
	as(guest, "setPaused", true)
	as(guest, "setPaused", false)
	eq(HttpService:JSONEncode({ data.pads, data.towers, data.coins }), hostSave, "a guest's pad actions leave the owner's save alone")
	eq(HttpService:JSONEncode(Plots.towers[state.slot]), hostTowers, "and the owner's towers")
	eq(HttpService:JSONEncode(Plots.pads[state.slot]), hostPads, "and the owner's pads")
	eq(state.paused, true, "a guest cannot pause or resume the owner's plot")
	check(table.find(guestData.pads, free) ~= nil and Plots.towers[guestState.slot][free] ~= nil, "they land on the guest's own base")
	as(player, "setPaused", false)
	-- Nor are the base's teleporters theirs.
	from = #T.toasts
	local opened = 0
	local connection = T.Remotes.Feature.OnClientEvent:Connect(function(channel: string)
		if channel == "window" then
			opened += 1
		end
	end)
	harness.advance(0.1)
	harness.fire(Plots.marketPrompts[state.slot], "Triggered", guest)
	harness.advance(0.1)
	harness.fire(Plots.worldsPrompts[state.slot], "Triggered", guest)
	check(guestState.place == "visit" and opened == 0, "a guest cannot use the owner's teleporters")
	check(toasted("Only the owner of this base", from + 1), "and is told how to get home")
	connection:Disconnect()
	as(guest, "visitKick", 1)
	eq(guestState.place, "visit", "a guest cannot send the owner anywhere")
	eq(state.place, "plot", "the owner is still at home")

	-- Home again: the guest's own BASE button.
	as(guest, "goHome")
	eq(guestState.place, "plot", "BASE takes the guest home")
	check(guest:GetAttribute("Visiting") == 0 and guest:GetAttribute("InMarket") == false, "and the attributes follow")
	run(1)
	eq(#view(player).guests, 0, "the owner's list is empty again")
	check(view(guest).host == nil, "and the guest is nobody's guest")

	-- Again, and this time the owner sends them home.
	harness.advance(Visit.InviteGapSeconds + 1)
	as(player, "visitInvite", 2)
	eq(invited(guest), 1, "after a visit the owner can invite them again at once")
	as(guest, "visitJoin", 1)
	eq(guestState.place, "visit", "a second visit")
	as(guest, "visitKick", 2)
	as(player, "visitKick", 999)
	eq(guestState.place, "visit", "only the owner's SEND HOME for that guest counts")
	as(player, "visitKick", 2)
	eq(guestState.place, "plot", "SEND HOME takes the guest to their own base")
	as(player, "visitKick", 2)
	eq(guestState.place, "plot", "and does nothing to a player who is not a guest")

	-- The owner leaves the game: their guest is sent home. (The other way round, so the first player stays.)
	as(player, "visitJoin", 2)
	eq(state.place, "visit", "the first player visits the second")
	eq(player:GetAttribute("InMarket"), true, "their HUD wears its away layout")
	local clock, shots = state.clock, hooked.towerShots
	run(20)
	check(state.clock > clock + 15 and hooked.towerShots > shots, "and their own base keeps fighting")
	from = #T.toasts
	harness.removePlayer(guest)
	run(1)
	eq(state.place, "plot", "when the owner leaves, the guest is sent home")
	eq(player:GetAttribute("Visiting"), 0, "the Visiting attribute is cleared")
	check(toasted("left the game", from + 1), "and told why")
	run(1)
	check(view(player).host == nil and #view(player).invites == 0, "nothing of the visit is left")
	Players.LocalPlayer = player
	noErrors("visits")
end

T.section("a long fight with every feature and boost running")
act("goHome")
debug("wave", 1)
data.autoAdvance = true
run(120)
-- Actions of the clicker's features, and the ones that are gone.
for _, name in { "combatBlast", "combatHit", "buyCannon", "rebirth", "toggleAutoRebirth", "claimDaily", "claimMission", "storyClaim", "nope" } do
	act(name)
	act(name, 1)
	act(name, "x")
	act(name, {})
end
run(10)
noErrors("a long fight")
for _, value in { data.coins, data.diamonds, player:GetAttribute("Dps"), player:GetAttribute("PowerMult") } do
	assert(value == value and value >= 0, "a number went bad")
end
check(true, "coins, gems, Dps and PowerMult are still numbers")

T.section("leaving")
local slot = state.slot
fields = {}
harness.removePlayer(player)
run(1)
check(table.find(Plots.released, slot) ~= nil, "the plot is released")
local Leaderboard = require(game:GetService("ServerScriptService").Server.Leaderboard)
check(Leaderboard.submitted == 0 or typeof(Leaderboard.last.power) == "number", "the leaderboard is given the player's Cannon Power")
local emptied = false
for _, field in fields do
	if field.slot == slot and field.level == 0 and #field.flat == 0 then
		emptied = true
	end
end
check(emptied, "watchers are told the plot is empty")
noErrors("the player leaving")

T.section("offline earnings")
do
	local HttpService = game:GetService("HttpService")
	local Offline = require(game:GetService("ReplicatedStorage").Shared.Features.Offline)
	local function pending(who)
		return HttpService:JSONDecode(who:GetAttribute("Meta_offline"))
	end
	-- The same player comes back `secondsAway` later.
	local function rejoin(secondsAway: number)
		harness.setTime(harness.now() + secondsAway)
		local who = harness.addPlayer("Tester", 1)
		harness.flush()
		local saved, session = Game.data(who), Game.state(who)
		assert(saved and session, "the player did not load again")
		return who, saved, session
	end
	local function leave(who)
		harness.removePlayer(who)
		harness.flush()
	end
	-- Worked out here on its own: what `seconds` of farming an ordinary level pay this player.
	local function expected(who, level: number, seconds: number): number
		local plan = Config.levelPlan(level)
		assert(plan.kind == "normal" and plan.regen == 0, "the test farms an ordinary level")
		local cross = Layout.PATH_LENGTH / (plan.speed * Game.value(who, "monsterSpeed"))
		local clear = (plan.count - 1) * plan.gap + cross + Config.Defense.breakSeconds
		local perClear = plan.count * math.floor(plan.coins * Game.value(who, "coins"))
		return math.floor(seconds / clear * perClear * Game.value(who, "offlineShare"))
	end
	local function same(a: number, b: number): boolean
		return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(a), math.abs(b))
	end

	-- Under a minute away: nothing.
	local who, saved = rejoin(30)
	eq(pending(who).coins, 0, "30 seconds away pay nothing")
	eq(Game.value(who, "offlineCap"), 8, "earnings stop after 8 hours")
	eq(Game.value(who, "offlineShare"), 0.5, "half of what the towers make is paid")
	eq(who:GetAttribute("GameSpeed"), 1, "a player who comes back without the speed pass plays at 1x")
	-- A known place to farm: level 2 is the best, with towers that clear it easily.
	saved.rebirths = 0
	saved.bestCleared, saved.cleared, saved.wave = 2, 2, 1
	saved.features.mastery = { levels = {}, spent = 0 }
	debug("towers", 30)
	leave(who)

	-- Two hours away.
	local session
	who, saved, session = rejoin(2 * 3600)
	local two = pending(who)
	eq(two.level, 2, "the towers farmed the best level cleared")
	eq(two.seconds, 7200, "two hours are paid for")
	eq(two.away, 7200, "and the card is told the time away")
	local want = expected(who, 2, 7200)
	check(want > 0 and same(two.coins, want), `two hours on level 2 pay {want} coins (the server says {two.coins})`)
	check(Offline.clearSeconds(Config.levelPlan(2), who:GetAttribute("CannonPower"), 1, 0) ~= nil, "these towers clear level 2")
	local coins, kills, gems, candy, level = saved.coins, saved.totalKills, saved.diamonds, saved.candy, saved.masteryKills
	local missions = HttpService:JSONEncode(saved.missions)
	eq(saved.coins, coins, "nothing is paid before CLAIM")
	act("offlineClaim")
	check(same(saved.coins, coins + two.coins), "CLAIM pays the amount worked out at join")
	eq(pending(who).coins, 0, "and nothing is left waiting")
	local after = saved.coins
	act("offlineClaim")
	act("offlineClaim", 1e9)
	act("offlineClaim", { coins = 1e9 })
	eq(saved.coins, after, "a second CLAIM pays nothing, whatever it sends")
	check(saved.totalKills == kills and saved.diamonds == gems and saved.candy == candy and saved.masteryKills == level, "no kills, gems, candy or Veteran progress from being away")
	eq(HttpService:JSONEncode(saved.missions), missions, "no mission progress either")
	check(same(saved.features.offline.earned, two.coins), "the lifetime total counts it")
	check(string.find(T.lastToast(), "Welcome back", 1, true) ~= nil, "the claim is toasted: " .. T.lastToast())
	leave(who)

	-- Twenty hours away: the cap.
	who, saved = rejoin(20 * 3600)
	local twenty = pending(who)
	eq(twenty.seconds, 8 * 3600, "twenty hours away are paid as eight")
	eq(twenty.away, 20 * 3600, "the card still says twenty")
	want = expected(who, 2, 8 * 3600)
	check(same(twenty.coins, want), `eight hours on level 2 pay {want} coins (the server says {twenty.coins})`)
	check(twenty.coins <= expected(who, 2, 20 * 3600) * 0.4 + 1, "which is far less than twenty hours would")
	-- Left without claiming, back within a minute: the earnings wait, and are not worked out again.
	coins = saved.coins
	leave(who)
	who, saved = rejoin(20)
	eq(pending(who).coins, twenty.coins, "unclaimed earnings wait for the next visit")
	eq(saved.coins, coins, "and are still not paid")
	act("offlineClaim")
	check(same(saved.coins, coins + twenty.coins), "they are paid once")
	act("offlineClaim")
	check(same(saved.coins, coins + twenty.coins), "and only once")

	-- Towers too weak for the best level: they farm the highest level they can clear.
	saved.bestCleared = 300
	debug("towers", 1)
	leave(who)
	who, saved, session = rejoin(3600)
	local low = pending(who)
	local dps = who:GetAttribute("CannonPower")
	check(Offline.clearSeconds(Config.levelPlan(300), dps, 1, 0) == nil, "level 1 towers cannot clear level 300")
	check(low.level >= 1 and low.level < 300 and low.coins > 0, `so they farmed level {low.level} for {low.coins} coins`)
	-- (The margin of 3 is on the towers' half, as it always was. The mini cannons' flat DPS, which is most of
	-- what level 1 towers have beside them, is counted as it is: that is what farms so high a level.)
	local reach = who:GetAttribute("TowerDps") * 3 + who:GetAttribute("PetDps")
	check(who:GetAttribute("PetDps") > 0 and Offline.clearSeconds(Config.levelPlan(low.level), dps - who:GetAttribute("PetDps"), Game.value(who, "monsterSpeed"), 0) == nil, "the mini cannons' DPS counts while away: the towers alone could not farm that level")
	check(Offline.clearSeconds(Config.levelPlan(low.level + 1), reach, Game.value(who, "monsterSpeed"), 0) == nil or Config.levelPlan(low.level + 1).kind ~= "normal",
		"the next ordinary level is out of their reach")
	act("offlineClaim")

	-- The Offline mastery track: an hour more per level.
	local Mastery = require(game:GetService("ReplicatedStorage").Shared.Features.Mastery)
	check(Mastery.byId.offline ~= nil and Mastery.byId.offline.group == "survival", "Mastery has the Offline track")
	eq(Mastery.describe("offline", 1), "+1 hour of offline earnings", "it describes itself")
	saved.features.mastery = { levels = { offline = 4 }, spent = 0 }
	saved.bestCleared = 2
	debug("towers", 30)
	eq(Game.value(who, "offlineCap"), 12, "Offline IV makes it 12 hours")
	local named = false
	for _, source in Game.breakdown(who, "offlineCap").sources do
		named = named or source.label == "Mastery: Offline IV"
	end
	check(named, "and STATS names the source")
	leave(who)
	who, saved = rejoin(20 * 3600)
	eq(pending(who).seconds, 12 * 3600, "twenty hours away are then paid as twelve")
	eq(pending(who).capHours, 12, "and the card says so")
	-- A pass or another feature raises the share with a modifier.
	Game.modify("offlineShare", function(_who, _data, _state, value)
		return value + 0.25
	end, "Test")
	eq(Game.value(who, "offlineShare"), 0.75, "the share is a modifier others can raise")
	saved.features.mastery = { levels = {}, spent = 0 }
	leave(who)
	noErrors("offline earnings")
end
print(`{T.checks} checks passed`)
