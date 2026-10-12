-- Worlds 13 to 15 (Multiverse, Time Warp, Infinity), on the real plots:
--   python3 run.py --all-features --real-plots tests/worlds15.luau
-- A save from the twelve-world game (worlds15.pre.luau: level 600 of 600, not cleared yet) loads, clearing
-- it opens the Multiverse, a level of each new world is played, the last level of all is cleared and nothing
-- offers a sixteenth world, every new egg hatches, and every number up there is finite and has a name.
-- The emulator has no rendering: how the islands, the bases and the monsters LOOK needs Studio.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local T = harness.load("_prelude.luau")
local Config, Game, Format, Layout = T.Config, T.Game, T.Format, T.Layout
local player, data, state = T.player, T.data, T.state
local check, eq, act, debug, run = T.check, T.eq, T.act, T.debug, T.run
local Islands = require(game:GetService("ServerScriptService").Server.Islands)
local Story = require(ReplicatedStorage.Shared.Features.Story)
local Models = require(ReplicatedStorage.Shared.Models)

local NEW = { 13, 14, 15 }
local NAMES = { [13] = "Multiverse", [14] = "Time Warp", [15] = "Infinity" }
local OLD_TOTAL = 600 -- the last level of the twelve-world game

local function noErrors(what: string)
	check(harness.errors() == 0, "no errors after " .. what)
end

local function finite(n: any): boolean
	return typeof(n) == "number" and n == n and n > -math.huge and n < math.huge
end

-- A number as the game writes it has a name: digits and a suffix of letters, never an exponent or MAX.
local function named(n: number): boolean
	local text = Format.abbreviate(n)
	return string.match(text, "^[%d%.]+%a*$") ~= nil and text ~= "MAX"
end

local function toastWith(from: number, word: string): boolean
	for index = from, #T.toasts do
		if string.find(T.toasts[index].text, word, 1, true) then
			return true
		end
	end
	return false
end

-- Plays `level` until it is cleared: the towers shoot, and an ability (Game.damage) finishes what they leave.
local function clear(level: number)
	debug("wave", level)
	eq(data.wave, level, `level {level} starts`)
	local plan = Config.levelPlan(level)
	eq(state.plan.kind, plan.kind, `it is a {plan.kind} level`)
	eq(state.plan.monster.name, plan.monster.name, "with the world's own monster")
	local kills = data.totalKills
	for _ = 1, 40 do
		run(1)
		Game.damage(player, 1e300)
		if data.cleared >= level then
			break
		end
	end
	check(data.cleared >= level, `level {level} ({plan.monster.name}) is cleared`)
	check(data.totalKills > kills, "its monsters were defeated")
	check(finite(data.coins) and data.coins >= 0, `the coins are still a number ({Format.abbreviate(data.coins)})`)
end

-- The player's own plot, as the real Plots.luau built it.
local plot = workspace.Plots:FindFirstChild("Plot_" .. state.slot)
local function plotSays(text: string): boolean
	for _, item in plot:GetDescendants() do
		if item:IsA("TextLabel") and item.Text == text then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------------------------------------
T.section("the game has fifteen worlds")
eq(#Config.Worlds, 15, "worlds")
eq(Config.TotalWaves, 750, "levels")
for _, index in NEW do
	eq(Config.Worlds[index].name, NAMES[index], `world {index}`)
end
eq(Config.Worlds[16], nil, "there is no world 16")
eq(#Config.Cannons, 75, "tier styles: five per world")
eq(Config.towerTier(741), 75, "the last style is worn from level 741")
eq(Config.towerTier(Config.TowerMaxLevel), 75, "and at the highest tower level")
eq(Config.Cannons[Config.towerTier(600)].short, "Big Bang", "a level 600 tower looks as it did")
eq(Layout.ISLAND_COUNT, 15, "islands")

T.section("nothing of the first twelve worlds moved")
do
	-- Numbers of the twelve-world game, written down before the new worlds went in.
	local plan = Config.levelPlan(600)
	eq(plan.kind, "final", "level 600 is still The Big Bang's boss")
	eq(plan.monster.name, "Genesis Titan", "the Genesis Titan")
	-- Monsters of world 12 cross the path in CrossSeconds[2], as they did when it was the last world.
	local ordinary = Config.levelPlan(596)
	check(math.abs(ordinary.speed - Config.Level.speed * 1.2 * Config.CrossSeconds[1] / Config.CrossSeconds[2]) < 1e-9, "The Big Bang's monsters walk as fast as before")
	local moon = Config.levelPlan(56)
	local cross = Config.CrossSeconds[1] + (Config.CrossSeconds[2] - Config.CrossSeconds[1]) * 1 / 11
	check(math.abs(moon.speed - Config.Level.speed * 0.8 * Config.CrossSeconds[1] / cross) < 1e-9, "and so do the Moon's")
	for index = 1, 12 do
		local a, b = Layout.islandCFrame(index).Position, Vector3.new(((index - 1) % 6 - 2.5) * 420, 0, 1200 + ((index - 1) // 6 - 0.5) * 420)
		check((a - b).Magnitude < 1e-6, `island {index} stands where it stood`)
	end
	eq(Config.EggById.genesisegg.unlock, 575, "the Genesis Egg still unlocks at level 575")
	eq(Config.Eggs[24].id, "genesisegg", "and is still the 24th egg")
end

----------------------------------------------------------------------------------------------------
T.section("a save at level 600 loads")
eq(data.wave, OLD_TOTAL, "the player stands on level 600")
eq(data.cleared, OLD_TOTAL - 1, "with 599 cleared")
for _, id in { "genesis", "genesis_gold", "bigbang" } do
	check(table.find(data.pets, id) ~= nil, `and keeps their {Config.Pets[id].name}`)
end
check(not Config.worldUnlocked(13, data.bestCleared), "the Multiverse is still locked")
act("travel", 13)
eq(data.wave, OLD_TOTAL, "and cannot be travelled to")
act("goIsland", 13)
check(player:GetAttribute("Island") ~= 13, "nor its island")
noErrors("loading the old save")

T.section("clearing level 600 opens world 13")
data.autoAdvance = true
local before = #T.toasts
clear(OLD_TOTAL)
check(toastWith(before, "Multiverse unlocked"), "the player is told the Multiverse is unlocked")
check(Config.worldUnlocked(13, data.bestCleared), "world 13 is open")
run(4) -- the break between two levels
eq(data.wave, OLD_TOTAL + 1, "auto-advance walks on into level 601")
eq((Config.worldOf(data.wave)), 13, "which is in world 13")
check(plotSays("MULTIVERSE"), "the base is dressed as the Multiverse")
act("goIsland", 13)
eq(player:GetAttribute("Island"), 13, "and its island can be visited")
act("goHome")
noErrors("walking into world 13")

----------------------------------------------------------------------------------------------------
T.section("a level in each new world")
-- Build something to shoot with, at the highest level there is.
data.coins = 1e60
for pad = 2, 4 do
	act("buyPad", pad)
end
for pad, kind in { [2] = "gatling", [3] = "mortar", [4] = "sniper" } do
	act("buildTower", { pad = pad, kind = kind })
end
debug("towers", Config.TowerMaxLevel)
-- 603 is a giant only by the Multiverse's own rule (one every 3 levels), 675 the Time Warp's mid boss (it
-- heals), 741 an ordinary level of Infinity.
for _, level in { 601, 603, 625, 650, 651, 675, 700, 701, 741 } do
	clear(level)
	local index = Config.worldOf(level)
	check(plotSays(string.upper(NAMES[index])), `the base wears {NAMES[index]}`)
end
eq(Config.levelPlan(603).kind, "boss", "the Multiverse sends a giant every 3 levels")
check(Config.levelPlan(675).regen > 0, "the Time Warp's bosses heal")
check(Config.levelPlan(741).regen > 0 and Config.levelPlan(741).speed > Config.levelPlan(596).speed, "Infinity's monsters heal and are faster than The Big Bang's")
for _, index in NEW do
	act("travel", index)
	eq((Config.worldOf(data.wave)), index, `TRAVEL goes to {NAMES[index]}`)
end
noErrors("playing worlds 13 to 15")

T.section("the last level of all")
before = #T.toasts
clear(Config.TotalWaves)
eq(data.cleared, Config.TotalWaves, "level 750 is cleared")
run(4)
eq(data.wave, Config.TotalWaves, "and the game does not walk on past it")
act("nextWave")
eq(data.wave, Config.TotalWaves, "NEXT does nothing there")
check(not toastWith(before, "unlocked!"), "no world is said to be unlocked")
act("travel", 16)
eq(data.wave, Config.TotalWaves, "there is no world 16 to travel to")
act("goIsland", 16)
check(player:GetAttribute("Island") ~= 16, "and no island 16")
check(not Config.worldUnlocked(16, data.bestCleared), "Config.worldUnlocked(16) is false")
eq((Config.worldOf(Config.TotalWaves + 50)), 15, "a level past the end still reads as the last world")
noErrors("clearing level 750")

----------------------------------------------------------------------------------------------------
T.section("every new egg hatches a mini cannon")
local hatched = {}
Game.on("hatch", function(who: Player, _data, _state, egg, results)
	if who == player then
		hatched[egg.id] = results
	end
end)
local newEggs = {}
for _, egg in Config.Eggs do
	if egg.world and egg.world >= 13 then
		table.insert(newEggs, egg)
	end
end
eq(#newEggs, 6, "two coin eggs per new world")
for order, egg in newEggs do
	local world = 13 + (order - 1) // 2
	eq(egg.world, world, `{egg.name} is on the island of {NAMES[world]}`)
	eq(egg.unlock, (world - 1) * 50 + (order - 1) % 2 * 25, "and unlocks with the world, or with its mid boss")
	check(finite(egg.cost) and egg.cost > 0 and named(egg.cost), `it costs {Format.abbreviate(egg.cost)} coins`)
	eq(#egg.pets, 8, "it holds five mini cannons, two Secrets and a Huge")
	local odds = 0
	for slot, entry in egg.pets do
		local pet = Config.Pets[entry.id]
		check(pet ~= nil, `{entry.id} exists`)
		odds += entry.weight
		if slot <= 5 then
			eq(pet.rarity, ({ "Common", "Uncommon", "Rare", "Epic", "Legendary" })[slot], `{pet.name}`)
			check(finite(pet.dps) and named(pet.dps), `deals {Format.petPower(pet)}`)
			-- Fused and enchanted, it is still a number with a name.
			local diamond = Config.Pets[entry.id .. "_diamond"]
			check(diamond ~= nil and finite(diamond.dps) and named(diamond.dps * Config.SetBonus), `and {Format.petPower(diamond)} as a Diamond`)
		elseif not pet.huge then
			check(finite(pet.dps) and named(pet.dps), `{pet.name} deals {Format.petPower(pet)}`)
		end
	end
	check(math.abs(odds - 100) < 1e-9, "its chances add up to 100%")
	local prompt = T.Marketplace.promptFor[egg.id]
	check(prompt ~= nil, "its stand is built")
	local owned = #data.pets
	data.coins = egg.cost * 3
	harness.advance(0.5)
	harness.fire(prompt, "Triggered", player)
	harness.flush()
	local results = hatched[egg.id]
	check(results ~= nil and #results == 1, "the hatch happened")
	local got = Config.Pets[results[1].pet]
	check(got ~= nil, `it gave a {got.name}`)
	local found = false
	for _, entry in egg.pets do
		found = found or entry.id == results[1].pet
	end
	check(found, "which is one of the egg's own")
	eq(#data.pets, owned + 1, "and it is in the storage")
	check(data.coins < egg.cost * 3 and finite(data.coins), "the price was paid")
end
-- The first egg of each world hatches the mini cannons named like that world's tower tiers: the set bonus.
for _, index in NEW do
	local egg = newEggs[(index - 13) * 2 + 1]
	for slot = 1, 5 do
		local cannon = Config.Cannons[(index - 1) * 5 + slot]
		eq(Config.Pets[egg.pets[slot].id].short, cannon.short, `{egg.name} slot {slot} matches the {cannon.name}`)
	end
end
do
	local names = Config.towerNames({ { kind = "cannon", level = 745 } })
	check(names.Ultimate == true, "a level 745 tower is an Ultimate one")
	eq(Config.petDps("ultimate", names), Config.Pets.ultimate.dps * Config.SetBonus, "and the Mini Ultimate Cannon gets the set bonus beside it")
end
noErrors("hatching the new eggs")

----------------------------------------------------------------------------------------------------
T.section("the numbers up to level 750 are finite and have names")
do
	local biggest = 0
	for level = OLD_TOTAL + 1, Config.TotalWaves do
		local plan = Config.levelPlan(level)
		local coins = Config.levelCoins(level)
		if not (finite(plan.hp) and finite(plan.coins) and finite(plan.speed) and finite(coins) and named(plan.hp) and named(plan.coins * 1e6) and named(coins)) then
			error(`CHECK FAILED: level {level}: hp {plan.hp}, coins {plan.coins}, levelCoins {coins}`)
		end
		if level > OLD_TOTAL + 1 and Config.worldOf(level) == Config.worldOf(level - 1) and plan.kind == "normal" and not plan.variant then
			-- Inside a world an ordinary level is never easier, and never pays less, than the last ordinary one.
			local last = level - 1
			while Config.levelPlan(last).kind ~= "normal" or Config.levelPlan(last).variant do
				last -= 1
			end
			if Config.worldOf(last) == Config.worldOf(level) then
				local below = Config.levelPlan(last)
				if not (plan.hp > below.hp and plan.coins > below.coins) then
					error(`CHECK FAILED: level {level} is not above level {last}`)
				end
			end
		end
		biggest = math.max(biggest, plan.hp)
	end
	T.checks += 1
	print(`  ok: levels 601 to 750: every HP and coin number is finite and named; the biggest HP is {Format.abbreviate(biggest)}`)
	local last = Config.levelPlan(Config.TotalWaves)
	print(`  level 750: {last.monster.name}, {Format.abbreviate(last.hp)} HP, {Format.abbreviate(last.coins)} coins, {last.regen * 100}% healing a second`)
	eq(last.kind, "final", "level 750 is a world boss")
	eq(last.monster.name, "The Last Titan", "The Last Titan")
	-- A long way under what a double holds (1.8e308), with every multiplier a player can stack on top.
	check(last.hp < 1e100 and last.coins * 1e6 < 1e100, "and nowhere near the end of a double")

	for _, kind in Config.TowerOrder do
		local damage = Config.towerDamage(kind, Config.TowerMaxLevel)
		local cost = Config.towerUpgradeCost(kind, Config.TowerMaxLevel - 1)
		local invested = Config.towerInvested(kind, Config.TowerMaxLevel)
		if not (finite(damage) and finite(cost) and finite(invested) and named(damage) and named(cost) and named(invested)) then
			error(`CHECK FAILED: {kind} at level {Config.TowerMaxLevel}: damage {damage}, upgrade {cost}, invested {invested}`)
		end
	end
	T.checks += 1
	print("  ok: every tower's damage, upgrade price and worth at level 750")

	local top = 0
	for id, pet in Config.Pets do
		if not pet.huge then
			if not (finite(pet.dps) and finite(pet.bonus) and finite(pet.strength)) then
				error(`CHECK FAILED: mini cannon {id}: dps {pet.dps}`)
			end
			top = math.max(top, pet.dps)
		end
	end
	T.checks += 1
	print(`  ok: every mini cannon's DPS is finite; the strongest deals {Format.dps(top)}`)
	check(named(top * Config.SetBonus * 1e3), "and still has a name with the set bonus and a thousandfold of boosts")
end

T.section("what the player is told, and what is saved")
do
	-- The strongest things there are, all at once.
	debug("towers", Config.TowerMaxLevel)
	debug("pet:forbiddeneternity_diamond", 3)
	run(2)
	local power = player:GetAttribute("CannonPower")
	check(finite(power) and power > 0 and named(power), `Cannon Power reads {Format.abbreviate(power)}`)
	-- The leaderboards hold whole numbers that an OrderedDataStore can take (under 2^63): levels as they are,
	-- Cannon Power as a logarithm (src/server/Leaderboard.luau).
	check(math.floor(math.log10(power) * 1000) < 2 ^ 53, "its leaderboard score is a small whole number")
	check(data.bestCleared == 750 and data.bestCleared % 1 == 0, "the level board's score is 750")
	data.coins = Config.levelPlan(Config.TotalWaves).coins * 1e9
	local encoded = HttpService:JSONEncode(data)
	check(string.find(encoded, "inf", 1, true) == nil and string.find(encoded, "nan", 1, true) == nil, "the save has no infinity and no NaN in it")
	local back = HttpService:JSONDecode(encoded)
	eq(back.cleared, 750, "and reads back")
	check(finite(back.coins) and back.coins > 1e40, `with its {Format.abbreviate(back.coins)} coins`)
	for key in back do
		check(data[key] ~= nil, `the save's "{key}" is a field the game knows`)
	end

	-- Offline earnings on the last level: a number, or nothing, never an infinity.
	local Offline = require(ReplicatedStorage.Shared.Features.Offline)
	local estimate = Offline.estimate({
		away = 8 * 3600, best = Config.TotalWaves, capHours = 8, share = 0.5, coinMult = 4,
		dpsOf = function()
			return power
		end,
	})
	check(estimate ~= nil and finite(estimate.coins) and named(estimate.coins), `eight hours away pay {Format.abbreviate(estimate.coins)} coins (level {estimate.level})`)
	check(estimate.level > OLD_TOTAL, "farmed in the new worlds")
end
noErrors("the big numbers")

----------------------------------------------------------------------------------------------------
T.section("the islands and the bases")
do
	local root = workspace:FindFirstChild("Islands")
	eq(#root:GetChildren(), 15, "fifteen islands are built")
	local function count(folder: Instance, name: string): number
		local found = 0
		for _, child in folder:GetChildren() do
			if child.Name == name then
				found += 1
			end
		end
		return found
	end
	for _, index in NEW do
		local folder = Islands.container(index)
		check(folder ~= nil and folder:GetAttribute("World") == index, `island {index} has its folder`)
		local middle = Layout.islandCFrame(index).Position
		for other = 1, index - 1 do
			check((Layout.islandCFrame(other).Position - middle).Magnitude >= Layout.ISLAND_SPACING, `islands {other} and {index} are apart`)
		end
		for slot = 1, Layout.PLOT_COUNT do
			check((Layout.plotCFrame(slot).Position - middle).Magnitude > 1500, `island {index} is far from plot {slot}`)
		end
		local ground = folder:FindFirstChild("Ground")
		check(ground ~= nil and ground.Color == Config.Worlds[index].floor, "its ground has the world's colour")
		eq(count(folder, "Rim"), 16, "its rim wall is whole")
		check(Islands.returnPrompts[index] ~= nil and Islands.shopPrompts[index] ~= nil, "it has a portal home and a shop stall")
		check(Islands.spot(index, "mastery") ~= nil and Islands.spot(index, "enchant") ~= nil, "and the two reserved spots")
		if index == 14 then
			-- worlds15.pre.luau put a model named "Time Warp" in IslandModels: the island wears it.
			check(folder:FindFirstChild("Scenery") ~= nil, "the Time Warp island wears its Blender model")
			eq(ground.Transparency, 1, "over the part-built ground, which stays as the floor")
			check(ground.CanCollide, "and still holds the player up")
		else
			check(folder:FindFirstChild("Scenery") == nil, `{NAMES[index]} has no model: it is built from parts`)
			eq(ground.Transparency, 0, "with a ground to see")
			check(count(folder, "Spire") + count(folder, "Orb") + count(folder, "Machine") >= 12, "and its ring of props")
		end
	end
	-- The island-bound features stay where they are.
	eq(Config.FuseIsland, 5, "the Fusion Machine is still on The Sun's island")
	eq(Config.EnchantIsland, 5, "and so is the enchanting table")
	local Shop = require(ReplicatedStorage.Shared.Features.IslandShop)
	for _, index in NEW do
		local stock = Shop.stock(index, Config.dayNumber(os.time()))
		check(stock.ammo ~= nil and stock.powerup ~= nil and stock.chest ~= nil, `the shop on {NAMES[index]} sells ammo, a powerup and the chest`)
		check(stock.key ~= nil and stock.shiny ~= nil, "and both enchantment keys")
	end

	-- The base: Infinity has a stand-in Blender base (worlds15.pre.luau), the other two are built from parts.
	for _, index in NEW do
		act("travel", index)
		run(1)
		check(plotSays(string.upper(NAMES[index])), `the base says {string.upper(NAMES[index])}`)
		local decor = plot:FindFirstChild("Decor")
		check(decor ~= nil and #decor:GetChildren() > 0, "and has its props")
		local ground = plot:FindFirstChild("Ground", true)
		check(ground ~= nil and ground.Color == Config.Worlds[index].floor, "on ground of the world's colour")
		eq(plot:FindFirstChild("Dress") ~= nil, index == 15, if index == 15 then "Infinity wears its Blender base" else "no model: the part-built base shows")
	end

	-- A monster with a template of its own name uses it; the others are built from parts by their shape.
	local titan = Models.monster(Config.monsterFor(700))
	check(titan:FindFirstChild("Body") ~= nil and titan:FindFirstChild("Body"):IsA("MeshPart"), "Father Time uses the creature template of his name")
	for _, index in NEW do
		local world = Config.Worlds[index]
		for _, def in { world.monsters[1], world.monsters[5], world.midBoss, if index == 14 then world.monsters[3] else world.finalBoss } do
			local built = Models.monster({ name = def.name, shape = def.shape, color = def.color, accent = def.accent, kind = "normal", scale = 1.5 })
			check(built:IsA("Model") and #built:GetDescendants() > 2, `{def.name} is built from parts ({def.shape})`)
		end
	end
	for _, level in { 601, 605, 741 } do
		local tower = Models.tower("cannon", level)
		eq(tower:GetAttribute("Tier"), Config.towerTier(level), `a level {level} tower is built as a {Config.Cannons[Config.towerTier(level)].name}`)
	end
end
noErrors("the islands and the bases")

----------------------------------------------------------------------------------------------------
T.section("the story")
eq(#Story.Chapters, 15, "fifteen chapters")
for _, index in NEW do
	local chapter = Story.Chapters[index]
	eq(chapter.world, NAMES[index], `chapter {index}`)
	eq(chapter.last, index * 50, "ends with its world")
	check(#chapter.intro >= 2 and #chapter.outro >= 2 and #chapter.quests == 7, `"{chapter.title}" has its lines and seven quests`)
	check(not string.find(chapter.blurb, "<", 1, true), "its blurb names its boss")
end
-- A line the guide says is a plain string.
check(string.find(Story.Chapters[12].outro[2], "New worlds", 1, true) ~= nil, "The Big Bang's chapter now leads on")
check(string.find(Story.Chapters[14].outro[2], "Father Time says", 1, true) ~= nil, "Father Time is named without a \"the\"")
check(string.find(Story.Chapters[15].outro[1], "every world, everywhere", 1, true) ~= nil, "and Infinity's has the ending")

T.section("the client")
harness.runClient()
noErrors("starting the client in world 15")
do
	local Client = player.PlayerScripts.Client
	local Windows = require(Client.Windows)
	local worlds = Windows.byName.WORLDS
	worlds.open()
	run(0.5)
	local texts = {}
	for _, item in worlds.frame:GetDescendants() do
		if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text ~= "" then
			table.insert(texts, item.Text)
		end
	end
	local all = table.concat(texts, " | ")
	for _, index in NEW do
		check(string.find(all, `{index}. {NAMES[index]}`, 1, true) ~= nil, `WORLDS lists "{index}. {NAMES[index]}"`)
		check(string.find(all, Config.Worlds[index].twist, 1, true) ~= nil, "with its twist")
	end
	check(string.find(all, "16. ", 1, true) == nil, "and no world 16")
	check(string.find(all, "50/50 levels cleared  •  boss: The Last Titan", 1, true) ~= nil, "Infinity reads 50/50 levels cleared")
	check(string.find(all, "LOCKED", 1, true) == nil, "nothing is locked for a player who finished")
	-- The top bar's line: the world's name and the level in it.
	local hud = {}
	for _, item in player.PlayerGui:GetDescendants() do
		if item:IsA("TextLabel") and item.Text ~= "" then
			hud[item.Text] = true
		end
	end
	check(hud["INFINITY"] == true, "the top bar says INFINITY")
	local UI = require(Client.UI)
	for _, name in { "world_multiverse", "world_timewarp", "world_infinity" } do
		-- With no atlas uploaded (the emulator) UI.icon gives nothing and the row keeps its coloured oval;
		-- with one, the alias picks a picture that is on a sheet. Either way it must not error.
		local ok = pcall(UI.icon, name, {})
		check(ok, `UI.icon("{name}") does not error`)
	end
end
noErrors("the WORLDS window")

print(`worlds15.luau: {T.checks} checks passed`)
