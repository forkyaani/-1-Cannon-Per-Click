-- The three tower kinds of 12 Oct (Update 1): Drill, Wildfire and Quake. Their place in the tables, the level
-- that unlocks each, and what each one's special does to the monsters in a real fight.
-- Run with: python3 run.py --all-features tests/new_towers.luau
local T = harness.load("_prelude.luau")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config, Game = T.Config, T.Game
local player, data, state = T.player, T.data, T.state
local check, eq, act, debug, run = T.check, T.eq, T.act, T.debug, T.run
local Models = require(ReplicatedStorage.Shared.Models)

local NEW = { "drill", "wildfire", "quake" }
local PADS = { drill = 2, wildfire = 3, quake = 4 }

local function near(actual: number, expected: number, what: string)
	if math.abs(actual - expected) > 1e-6 * math.max(1, math.abs(expected)) then
		error(`CHECK FAILED: {what}: expected {expected}, got {actual}`)
	end
	T.checks += 1
	print(`  ok: {what} = {actual}`)
end

T.section("the tables")
eq(#Config.TowerOrder, 17, "tower kinds on sale")
-- Towers are saved by kind id: none of these may ever go or change.
for _, kind in { "cannon", "gatling", "mortar", "sniper", "frost", "flame", "tesla", "rocket", "laser", "venom", "blizzard", "railgun", "storm", "meteor" } do
	check(Config.Towers[kind] ~= nil and table.find(Config.TowerOrder, kind) ~= nil, `the {kind} of older saves is still there`)
end
eq(Config.TowerOrder[1], "cannon", "the first kind")
eq(Config.TowerOrder[2], "gatling", "the second kind (the tutorial and the story build it)")
local listed = 0
for _ in Config.Towers do
	listed += 1
end
eq(listed, #Config.TowerOrder, "every kind is in the shop order")
for index = 2, #Config.TowerOrder do
	local before, kind = Config.Towers[Config.TowerOrder[index - 1]], Config.Towers[Config.TowerOrder[index]]
	check(kind.unlock > before.unlock, `{kind.name} unlocks after {before.name}`)
end
local taken = {}
for _, kind in Config.TowerOrder do
	local name = Config.Towers[kind].name
	check(not taken[name], `only one tower is called {name}`)
	taken[name] = true
end
for _, kind in NEW do
	local def = Config.Towers[kind]
	check(def ~= nil, `{kind} is a tower`)
	check(not string.find(def.name, " ", 1, true) and #def.name <= 9, `{def.name} is one short word`)
	check(typeof(def.desc) == "string" and #def.desc > 10 and #def.desc <= 64, `{def.name} says what it does ("{def.desc}")`)
	check(typeof(def.color) == "Color3", `{def.name} has a colour`)
	local clash = nil
	for _, style in Config.Cannons do
		clash = clash or (style.short == def.name and style.name)
	end
	for _, pet in Config.Pets do
		clash = clash or ((pet.name == def.name or pet.name == `Mini {def.name} Cannon`) and pet.name)
	end
	check(not clash, `{def.name} is no tier's name and no mini cannon's ({tostring(clash)})`)
	-- Upgrades and damage follow the common curve.
	near(Config.towerDamage(kind, 1), def.damage, `{def.name}'s first shot`)
	check(Config.towerUpgradeCost(kind, 1) > 0 and Config.towerInvested(kind, 3) > def.cost, `{def.name} can be upgraded`)
	local model = Models.tower(kind, 1, nil)
	check(model:FindFirstChild("Turret") ~= nil and model:FindFirstChild("Muzzle", true) ~= nil, `{def.name} has a turret and a muzzle`)
	eq(model:GetAttribute("Kind"), kind, `{def.name}'s model says its kind`)
	model:Destroy()
end
local drill, wildfire, quake = Config.Towers.drill, Config.Towers.wildfire, Config.Towers.quake
check(drill.unlock >= 40 and drill.unlock <= 50, `the Drill is for the early game (level {drill.unlock})`)
check(wildfire.unlock >= 220 and wildfire.unlock <= 240, `the Wildfire is for the middle (level {wildfire.unlock})`)
check(quake.unlock > 600 and quake.unlock <= 750, `the Quake is for worlds 13 to 15 (level {quake.unlock})`)
check(drill.ramp ~= nil and drill.rampMax > 1, "the Drill ramps")
check(wildfire.chain ~= nil and wildfire.burn ~= nil and wildfire.burnSeconds ~= nil, "the Wildfire jumps and burns")
check(quake.splash ~= nil and quake.slow ~= nil and quake.slowSeconds ~= nil and quake.boss ~= nil, "the Quake splashes, slows and hunts bosses")
check(quake.slow < Config.Towers.blizzard.slow, "the Blizzard keeps the strongest slow")

T.section("each is built from the level that unlocks it")
data.coins = 1e60
for pad = 2, 4 do
	act("buyPad", pad)
end
for _, kind in NEW do
	local def, pad = Config.Towers[kind], PADS[kind]
	data.bestCleared = def.unlock - 1
	act("buildTower", { pad = pad, kind = kind })
	check(data.towers[tostring(pad)] == nil, `no {def.name} at level {def.unlock - 1}`)
	data.bestCleared = def.unlock
	act("buildTower", { pad = pad, kind = kind })
	eq(data.towers[tostring(pad)] and data.towers[tostring(pad)].kind, kind, `built at level {def.unlock}, on pad {pad}`)
	eq(data.towers[tostring(pad)].level, 1, "at level 1")
end
-- The test's player owns every pass, and with them the Huge that upgrades towers by itself: switched off, the
-- towers stay at level 1 and a shot's damage only changes by what the kinds themselves do.
check(data.features.huge ~= nil, "the Huge feature keeps its switch in the save")
data.features.huge.autoUpgrade = false
data.coins = 0
Game.sync(player)
local dps = 0
for _, tower in data.towers do
	dps += Config.towerDamage(tower.kind, tower.level) * Config.Towers[tower.kind].rate
end
-- Cannon Power counts a ramping tower's first shot: no splash, burn or ramp is in it.
near(player:GetAttribute("TowerDps") / player:GetAttribute("PowerMult"), dps, "Cannon Power's tower half is damage x rate of all four")

-- Every tower shot, as the core is about to land it. The Drill's are checked one by one: a shot is its first
-- shot's damage times 1 + ramp for every shot in a row on the same monster before it, up to rampMax.
local shots = { drill = 0, wildfire = 0, quake = 0 }
local value = { boss = {}, normal = {} } -- [kind] = an uncritical shot's damage on such a level
local drillOn, drillHits, drillTop, drillChanges = nil, 0, 0, 0
local drillBase = {} -- [level] = the first shot's damage there
local drillWrong: string? = nil
Game.on("shot", function(_player, _data, shotState, shot)
	if shot.source ~= "tower" or shots[shot.kind] == nil then
		return
	end
	shots[shot.kind] += 1
	local bossLevel = shotState.plan.kind ~= "normal"
	if shot.kind == "drill" then
		if drillOn == shot.target.id then
			drillHits += 1
		else
			if drillOn ~= nil then
				drillChanges += 1
			end
			drillOn, drillHits = shot.target.id, 0
		end
		local mult = math.min(drill.rampMax, 1 + drill.ramp * drillHits)
		drillTop = math.max(drillTop, mult)
		if not shot.crit then
			local level = _data.wave
			local base = shot.damage / mult
			drillBase[level] = drillBase[level] or base
			if math.abs(base - drillBase[level]) > 1e-6 * drillBase[level] and not drillWrong then
				-- (Kept for a check below: the core swallows an error thrown inside a hook.)
				drillWrong = `shot {drillHits + 1} in a row on level {level} dealt x{shot.damage / drillBase[level]}, not x{mult}`
			end
		end
	elseif not shot.crit then
		value[if bossLevel then "boss" else "normal"][shot.kind] = shot.damage
	end
end)

-- Monsters that are slowed, and burning, right now.
local function marked(): (number, number, number)
	local slowed, burning, slow = 0, 0, 0
	for _, monster in state.monsters do
		if not monster.dead then
			if state.clock < monster.slowUntil then
				slowed += 1
				slow = math.max(slow, monster.slow)
			end
			if state.clock < monster.burnUntil and monster.burn > 0 then
				burning += 1
			end
		end
	end
	return slowed, burning, slow
end

T.section("a swarm: the Wildfire jumps and burns, the Quake slows a crowd, the Drill starts over")
-- Level 1 towers cannot clear a level this deep (the second world's): there is always something to shoot.
data.autoAdvance = false
local swarm = 98
eq(Config.levelPlan(swarm).kind, "normal", `level {swarm} is an ordinary level`)
check(Config.levelPlan(swarm).count >= 20, "a swarm")
local mostSlowed, mostBurning, strongest, hurtAtOnce = 0, 0, 0, 0
for _ = 1, 4 do
	debug("wave", swarm)
	for _ = 1, 60 do
		run(0.5)
		local slowed, burning, slow = marked()
		mostSlowed, mostBurning, strongest = math.max(mostSlowed, slowed), math.max(mostBurning, burning), math.max(strongest, slow)
		local hurt = 0
		for _, monster in state.monsters do
			if not monster.dead and monster.hp < monster.max then
				hurt += 1
			end
		end
		hurtAtOnce = math.max(hurtAtOnce, hurt)
	end
	if mostSlowed >= 2 and mostBurning >= 2 and drillChanges >= 1 then
		break
	end
end
for _, kind in NEW do
	check(shots[kind] > 0, `the {Config.Towers[kind].name} fired ({shots[kind]} shots)`)
end
check(hurtAtOnce >= 2, `monsters were hurt ({hurtAtOnce} at once)`)
-- The Cannon on pad 1 neither burns nor slows: every burn is the Wildfire's, every slow the Quake's.
check(mostBurning >= 2, `the Wildfire's fire jumped: {mostBurning} monsters burned at once`)
check(mostBurning <= 1 + wildfire.chain + 20, "and the burn is a monster's own")
check(mostSlowed >= 2, `the Quake slowed a crowd: {mostSlowed} monsters at once`)
near(strongest, quake.slow, "by its own slow")
check(not drillWrong, `every Drill shot so far dealt what its place in the row says ({tostring(drillWrong)})`)
check(drillChanges >= 1, `the Drill changed its monster ({drillChanges} times) and started over each time`)
check(value.normal.wildfire ~= nil and value.normal.quake ~= nil, "both shot on an ordinary level")

T.section("a boss: the Drill winds up to its top, the Quake hits twice as hard")
local boss = 100
check(Config.levelPlan(boss).kind ~= "normal", `level {boss} is a boss`)
for _ = 1, 6 do
	debug("wave", boss)
	-- A boss takes most of a minute to walk the path, and the Drill's pad is near its end. One that gets
	-- through fails the level, and the player drops back: then it is asked for again.
	for _ = 1, 160 do
		run(0.5)
		if (drillTop >= drill.rampMax and value.boss.quake) or data.wave ~= boss then
			break
		end
	end
	if drillTop >= drill.rampMax and value.boss.quake then
		break
	end
end
check(not drillWrong, `every Drill shot on the boss dealt what its place in the row says ({tostring(drillWrong)})`)
near(drillTop, drill.rampMax, "the Drill reached its top on one monster, and no more")
check(state.towers[PADS.drill].rampHits >= 1, "the server's own count agrees")
check(value.boss.quake ~= nil, "the Quake shot the boss")
near(value.boss.quake / value.normal.quake, quake.boss * Game.value(player, "bossDamage"), "the Quake's shot on a boss level, against an ordinary one")
if value.boss.wildfire then
	near(value.boss.wildfire / value.normal.wildfire, Game.value(player, "bossDamage"), "the Wildfire has no boss bonus")
end

T.section("upgrading and selling")
debug("towers", 25)
eq(data.towers[tostring(PADS.quake)].level, 25, "the new kinds level like the others")
check(state.towers[PADS.drill].def == drill, "and keep their kind")
near(state.towers[PADS.drill].base, Config.towerDamage("drill", 25), "a level 25 Drill's first shot")
run(5)
act("sellTower", PADS.wildfire)
check(data.towers[tostring(PADS.wildfire)] == nil, "a new kind can be sold")
print(`new_towers: {T.checks} checks passed`)
