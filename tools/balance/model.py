"""The numbers of the idle defence game, as the simulator sees them.

Two sources:
  * from_config(): reads them out of src/shared/Config.luau and Layout.luau through the offline Luau
    emulator, so the simulator plays the game that ships. This is the default.
  * draft(knobs): the same formulas written in Python, for trying numbers out before they go into Config.

Both return a Model. `python3 sim.py --check` compares the two for every level, tower level, pad and egg.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

WAVES_PER_WORLD = 50
WORLDS = 12
TOTAL = WAVES_PER_WORLD * WORLDS
MAX_TOWER_LEVEL = 750


def nice(n):
    """Config.luau's `nice`: two significant digits, so generated prices look hand-picked."""
    if n < 100:
        return math.floor(n)
    magnitude = 10 ** (math.floor(math.log10(n)) - 1)
    return math.floor(n / magnitude + 0.5) * magnitude


class Model:
    """Plain tables. Lists indexed by level are 1-based with a dummy at 0."""

    def __init__(self):
        self.defense = {}
        self.path = []  # [(x, z)]
        self.pads = []  # [(x, z)]
        self.plans = [None]  # plans[level] = dict(kind, count, hp, coins, speed, gap, regen, leak)
        self.towers = {}  # kind -> dict(cost, damage, rate, range, unlock, splash, slow, ...)
        self.tower_order = []
        self.damage = {}  # kind -> [None, damage at level 1, ...]
        self.upgrade = {}  # kind -> [None, cost of level 1 -> 2, ...]
        self.pad_price = [None]  # pad_price[count] = price of the count-th pad
        self.eggs = []  # coin eggs in order: dict(id, cost, unlock, pets=[(weight, bonus)])
        self.fuse = []  # [(bonus multiplier, fireRate, coinBonus)] per fuse tier
        self.fuse_count = 3
        self.max_equipped = 3
        self.mastery_bonus = 0.1
        self.auto_shots = 1
        self.chain_range = 16
        self.max_tower_level = MAX_TOWER_LEVEL
        self.tiers = []  # the 60 tier names a tower wears as it is levelled: a mini cannon of that name gets the set bonus
        self.level_coins = [None]  # level_coins[level] = Config.levelCoins: what shops, crates and the story price in
        self.features = {}  # every number of the systems around the fight (FEATURES below), always from Config


# ---------------------------------------------------------------------------------------------------
# From Config.luau
# ---------------------------------------------------------------------------------------------------
DUMP = r"""
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)

local out = { defense = Config.Defense, path = {}, pads = {}, plans = {}, towers = {}, order = Config.TowerOrder,
	damage = {}, upgrade = {}, padPrice = {}, eggs = {}, fuse = {}, fuseCount = Config.FuseCount,
	maxEquipped = Config.MaxEquipped, mastery = Config.VeteranBonusPerLevel, autoShots = Config.AutoShotsPerPet,
	maxLevel = Config.TowerMaxLevel, total = Config.TotalWaves, tiers = {}, levelCoins = {} }
for index, cannon in Config.Cannons do
	out.tiers[index] = cannon.short
end
for level = 1, Config.TotalWaves do
	out.levelCoins[level] = Config.levelCoins(level)
end
for _, point in Layout.PATH do
	table.insert(out.path, { point.X, point.Y })
end
for _, point in Layout.PADS do
	table.insert(out.pads, { point.X, point.Y })
end
for level = 1, Config.TotalWaves do
	local plan = Config.levelPlan(level)
	out.plans[level] = { kind = plan.kind, count = plan.count, hp = plan.hp, coins = plan.coins, speed = plan.speed,
		gap = plan.gap, regen = plan.regen, leak = plan.leak }
end
for kind, tower in Config.Towers do
	out.towers[kind] = { cost = tower.cost, damage = tower.damage, rate = tower.rate, range = tower.range,
		unlock = tower.unlock, splash = tower.splash, slow = tower.slow, slowSeconds = tower.slowSeconds,
		burn = tower.burn, burnSeconds = tower.burnSeconds, chain = tower.chain, boss = tower.boss }
	local damage, upgrade = {}, {}
	for level = 1, Config.TowerMaxLevel do
		damage[level] = Config.towerDamage(kind, level)
		upgrade[level] = Config.towerUpgradeCost(kind, level)
	end
	out.damage[kind] = damage
	out.upgrade[kind] = upgrade
end
for count = 1, Layout.PAD_COUNT do
	out.padPrice[count] = Config.padPrice(count)
end
for _, egg in Config.Eggs do
	if egg.currency == "coins" and not egg.event then
		local pets = {}
		for _, entry in Config.eggOdds(egg, 1) do
			local pet = Config.Pets[entry.id]
			-- A Huge's bonus is infinite and its chance is 1 in 100,000,000: the simulator never hatches one.
			if not pet.huge then
				table.insert(pets, { entry.chance, pet.bonus, pet.rarity, pet.short })
			end
		end
		table.insert(out.eggs, { id = egg.id, cost = egg.cost, unlock = egg.unlock, pets = pets })
	end
end
for _, tier in Config.FuseTiers do
	table.insert(out.fuse, { tier.bonus, tier.fireRate or 0, tier.coinBonus or 0 })
end
return HttpService:JSONEncode(out)
"""


def from_config(src=None):
    sys.path.insert(0, os.path.join(ROOT, "tools", "emu"))
    from luau_emu import first  # noqa: E402
    from roblox_emu import World  # noqa: E402

    src = src or os.path.join(ROOT, "src")
    world = World()
    world.load_dir(os.path.join(src, "shared"), "Shared", set()).set_parent(world.service("ReplicatedStorage"))
    world.service("HttpService")
    raw = json.loads(first(world.interp.run(DUMP, "balance-dump", {})))

    model = Model()
    model.defense = raw["defense"]
    model.path = [tuple(p) for p in raw["path"]]
    model.pads = [tuple(p) for p in raw["pads"]]
    model.plans = [None] + raw["plans"]
    model.towers = raw["towers"]
    model.tower_order = raw["order"]
    model.damage = {kind: [None] + values for kind, values in raw["damage"].items()}
    model.upgrade = {kind: [None] + values for kind, values in raw["upgrade"].items()}
    model.pad_price = [None] + raw["padPrice"]
    model.eggs = [dict(id=e["id"], cost=e["cost"], unlock=e["unlock"], pets=[tuple(p) for p in e["pets"]]) for e in raw["eggs"]]
    model.fuse = [tuple(t) for t in raw["fuse"]]
    model.fuse_count = raw["fuseCount"]
    model.max_equipped = raw["maxEquipped"]
    model.mastery_bonus = raw["mastery"]
    model.auto_shots = raw["autoShots"]
    model.max_tower_level = raw["maxLevel"]
    model.chain_range = raw["defense"].get("chainRange", 16)
    model.tiers = raw["tiers"]
    model.level_coins = [None] + raw["levelCoins"]
    model.features = features(src)
    return model


# ---------------------------------------------------------------------------------------------------
# The systems around the fight: Huges, rebirth, mastery, powerups, ammo, the island shops, crates, the story,
# the daily gems and the passes. Their numbers are read out of Config.luau and src/shared/Features every time
# (the draft uses them too): there is no Python copy to keep in step.
# ---------------------------------------------------------------------------------------------------
FEATURES = r"""
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local function feature(name)
	local module = Shared.Features:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok then result else nil
end
local Huge, Mastery, Powerups, Ammo = feature("Huge"), feature("Mastery"), feature("Powerups"), feature("Ammo")
local IslandShop, Crates, Story = feature("IslandShop"), feature("Crates"), feature("Story")

local out = {
	hugePower = Config.HugePower, hugeShot = Config.HugeShot, rebirth = Config.Rebirth, setBonus = Config.SetBonus,
	petDps = Config.PetDps, hugeDps = Config.HugeDps,
	maxExtraSlots = Config.MaxExtraSlots, luckPass = Config.LuckPassMultiplier, minHealShare = Config.MinHealShare,
	milestoneEvery = Config.MilestoneEvery, milestoneGems = Config.MilestoneDiamonds,
	daily = {}, missions = {}, weeklyFixed = {}, weeklyPets = {}, passSlots = {}, pets = {}, gemEgg = nil,
	huges = {}, mastery = nil, powerups = nil, ammo = nil, shop = nil, crates = {}, story = nil, tiers = {},
}
for index, cannon in Config.Cannons do
	out.tiers[index] = cannon.short
end
for index, day in Config.Daily do
	out.daily[index] = { gems = day.diamonds or 0, boost = day.boost, minutes = day.minutes, pet = day.pet }
end
for index, mission in Config.Missions do
	out.missions[index] = mission.reward
end
for index, item in Config.WeeklyFixed do
	out.weeklyFixed[index] = { id = item.id, cost = item.cost, kind = item.kind, boost = item.boost, minutes = item.minutes, limit = item.limit }
end
for index, item in Config.WeeklyFeatured do
	out.weeklyPets[index] = { cost = item.cost, pet = item.pet }
end
for key, pass in Config.Passes do
	if pass.slots then
		out.passSlots[key] = pass.slots
	end
end
-- Every mini cannon that is not fused and not a Huge: what a shop, a crate or the story can hand out.
for id, pet in Config.Pets do
	if pet.tier == 0 then
		out.pets[id] = { bonus = pet.bonus, rarity = pet.rarity, short = pet.short }
	end
end
local gem = Config.EggById.gem
if gem then
	local pets = {}
	for _, entry in Config.eggOdds(gem, 1) do
		local pet = Config.Pets[entry.id]
		if not pet.huge then
			table.insert(pets, { entry.chance, pet.bonus, pet.rarity, pet.short })
		end
	end
	out.gemEgg = { cost = gem.cost, pets = pets }
end
if Huge then
	out.passPet = Huge.PassPet
	for id, f in Huge.Features do
		out.huges[id] = { coins = f.coins, heal = f.heal, luck = f.luck, bossDamage = f.bossDamage, fireRate = f.fireRate,
			multiChance = f.multiHit and f.multiHit.chance, multiHits = f.multiHit and f.multiHit.hits, execute = f.execute,
			freeEgg = f.freeEgg, bossGems = f.bossGems, gemsPerDay = f.gemsPerDay, crateDrops = f.crateDrops }
	end
end
if Mastery then
	local tracks = {}
	for index, track in Mastery.Tracks do
		local costs = {}
		for level = 1, track.cap do
			costs[level] = Mastery.cost(track.id, level)
		end
		tracks[index] = { id = track.id, kind = track.kind, how = track.how, per = track.per, cap = track.cap, at = track.at, costs = costs }
	end
	out.mastery = { island = Mastery.ISLAND, tracks = tracks }
end
if Powerups then
	local list, boosts = {}, {}
	for index, p in Powerups.List do
		list[index] = { id = p.id, boosts = p.boosts, seconds = p.seconds, weight = p.weight, event = p.event or false, rarity = p.rarity }
	end
	for id, b in Powerups.Boosts do
		boosts[id] = { luck = b.luck, fireRate = b.fireRate, damage = b.damage, slow = b.slow, heal = b.heal }
	end
	local bundles = {}
	for index, bundle in Powerups.Bundles do
		bundles[index] = { id = bundle.id, items = bundle.items, event = bundle.event or false }
	end
	out.powerups = { list = list, boosts = boosts, maxUses = Powerups.MaxUses, drops = Powerups.Drops, bundles = bundles }
end
if Ammo then
	local types = {}
	for index, def in Ammo.Types do
		types[index] = { id = def.id, rarity = def.rarity, damage = def.damage, bossDamage = def.bossDamage,
			doubleChance = def.doubleChance, critChance = def.critChance, critDamage = def.critDamage, burn = def.burn,
			slow = def.slow, slowChance = def.slowChance, coins = def.coins, healCut = def.healCut,
			price = def.price, dropOneIn = def.dropOneIn, event = def.event or false }
	end
	out.ammo = { types = types, dropCooldown = Ammo.DROP_COOLDOWN }
end
if IslandShop then
	out.shop = { ammo = IslandShop.Ammo, ammoLevel = IslandShop.AmmoLevel, ammoClears = IslandShop.AmmoClears,
		powerups = IslandShop.Powerups, powerupClears = IslandShop.PowerupClears, chest = IslandShop.Chest,
		chestClears = IslandShop.ChestClears }
end
if Crates then
	for _, crate in Crates.List do
		local rows = {}
		for index, entry in Crates.odds(crate) do
			local row = entry.row
			rows[index] = { chance = entry.chance, gems = row.gems, coins = row.coins, candy = row.candy, pet = row.pet,
				egg = row.egg, item = row.item, amount = row.amount }
		end
		out.crates[crate.id] = { rows = rows, price = crate.price, drop = crate.drop, daily = crate.daily or false }
	end
	out.crateDrops = Crates.Drops
end
if Story then
	local rewards = {}
	for key, reward in Story.Rewards do
		local items = {}
		for index, item in reward.items or {} do
			items[index] = { id = item.id, category = item.category, amount = item.amount, event = item.event or false }
		end
		rewards[key] = { gems = reward.gems or 0, clears = reward.clears or 0, items = items, pet = reward.pet or false }
	end
	local gifts = {}
	for chapter, gift in Story.ChapterGifts do
		gifts[tostring(chapter)] = gift.id
	end
	local pets = {}
	for chapter, pet in Story.ChapterPets do
		pets[tostring(chapter)] = pet
	end
	out.story = { rewards = rewards, gifts = gifts, pets = pets }
end
return HttpService:JSONEncode(out)
"""

_FEATURES = {}


def features(src=None):
    """The table FEATURES builds, read once per process."""
    src = src or os.path.join(ROOT, "src")
    if src not in _FEATURES:
        sys.path.insert(0, os.path.join(ROOT, "tools", "emu"))
        from luau_emu import first  # noqa: E402
        from roblox_emu import World  # noqa: E402

        world = World()
        world.load_dir(os.path.join(src, "shared"), "Shared", None).set_parent(world.service("ReplicatedStorage"))
        world.service("HttpService")
        raw = json.loads(first(world.interp.run(FEATURES, "balance-features", {})))

        def table(value):
            # An empty Luau table comes out of JSONEncode as a list.
            return value if isinstance(value, dict) else {}

        raw["passSlots"] = table(raw.get("passSlots"))
        for key in ("pets", "huges", "crates"):
            raw[key] = {name: table(entry) for name, entry in table(raw.get(key)).items()}
        if raw.get("powerups"):
            raw["powerups"]["boosts"] = {name: table(entry) for name, entry in table(raw["powerups"]["boosts"]).items()}
        if raw.get("story"):
            raw["story"]["gifts"], raw["story"]["pets"] = table(raw["story"]["gifts"]), table(raw["story"]["pets"])
        _FEATURES[src] = raw
    return _FEATURES[src]


# ---------------------------------------------------------------------------------------------------
# The draft: the same game from a table of knobs. Keep the formulas in step with Config.luau.
# ---------------------------------------------------------------------------------------------------
PATH = [(0, 145), (0, 128), (-38, 128), (-38, 98), (38, 98), (38, 68), (-38, 68), (-38, 38), (0, 38), (0, 14)]
PADS = [(-14, 26), (14, 26), (-8, 53), (8, 53), (-24, 53), (24, 53), (-8, 83), (8, 83), (-24, 83), (24, 83),
        (-20, 113), (4, 113), (24, 113), (-50, 53), (50, 83), (-50, 113)]


KNOBS = {
    # rules per world, as in Config.Worlds[...].rules
    "rules": [
        {},
        {"speed": 0.8, "hp": 1.5},
        {"boss": {"hp": 2, "coins": 3}},
        {"hp": 2, "coins": 1.5, "speed": 0.75},
        {"regen": 0.01},
        {"hp": 3, "coins": 3},
        {"speed": 1.3, "regen": 0.015},
        {"hp": 4, "coins": 4},
        {"bossEvery": 2},
        {"boss": {"regen": 0.01, "coins": 5}},
        {"hp": 2, "speed": 1.4, "coins": 3},
        {"hp": 5, "regen": 0.01, "coins": 10, "speed": 1.2},
    ],
    # levels: an ordinary monster has hp * level^hpPower * hpGrowth^(level - 1) health
    "hp": 10.0, "hpPower": 0.5, "hpGrowth": 1.172,
    # coins: every world has an anchor of its own, what an ordinary monster of its first level pays (worldPay).
    # Inside the world a monster pays  anchor * (level / first)^coinPower * coinGrowth^(level - first).
    # fit.py sets the anchors, one world at a time, so that every world takes its target time.
    "worldPay": [1.2, 77.7, 1.76e+04, 1.26e+07, 7.77e+09, 9.39e+12, 5.52e+15, 2.68e+18, 2.07e+21, 2.29e+24, 2.05e+27, 8.64e+29],
    "coinPower": -0.25, "coinGrowth": 1.1455,
    # coin multipliers of the very first levels (Config.Level.headStart): a new player's first minutes are quick
    "headStart": [4.83, 4.22, 3.68, 3.21, 2.81, 2.45, 2.14, 1.87, 1.63, 1.42, 1.24, 1.08],
    "speed": 18.0, "gap": 1.25, "count": 10,
    # an ordinary monster crosses the path in crossSeconds[0] on the first world, down to [1] on the last
    # (Config.CrossSeconds): every world's monsters walk a little faster
    "crossSeconds": [20, 10],
    # HP multipliers of the very first levels (Config.Level.easeIn): the starter cannon alone clears up to level 4
    "easeIn": [1, 1, 0.75, 0.4],
    "kinds": {
        "normal": {"hp": 1, "coins": 1, "speed": 1},
        "boss": {"hp": 6, "coins": 15, "speed": 0.7},
        "mid": {"hp": 9, "coins": 25, "speed": 0.65},
        "final": {"hp": 14, "coins": 40, "speed": 0.6},
    },
    # every fifth level of a world is a boss; the third of each five is a swarm and the fourth a pack of tanks
    "variants": {3: {"count": 2, "hp": 0.5, "coins": 0.5, "speed": 1.25, "gap": 0.5},
                 4: {"count": 0.5, "hp": 2, "coins": 2, "speed": 0.8, "gap": 2}},
    # towers
    "dmgStep": 1.10, "tierStep": 1.3, "costStep": 1.15, "upgradeShare": 0.5,
    "towers": {
        "cannon": {"cost": 50, "damage": 9, "rate": 1, "range": 30, "unlock": 0},
        "gatling": {"cost": 100, "damage": 4, "rate": 5, "range": 22, "unlock": 3},
        "mortar": {"cost": 150, "damage": 42, "rate": 0.3, "range": 45, "unlock": 8, "splash": 10},
        "sniper": {"cost": 250, "damage": 60, "rate": 0.2, "range": 90, "unlock": 14, "boss": 2.5},
        "frost": {"cost": 300, "damage": 10, "rate": 1, "range": 28, "unlock": 22, "slow": 0.4, "slowSeconds": 2.5},
        "flame": {"cost": 400, "damage": 11, "rate": 4, "range": 20, "unlock": 55, "burn": 0.25, "burnSeconds": 3},
        "tesla": {"cost": 600, "damage": 40, "rate": 1.2, "range": 30, "unlock": 105, "chain": 3},
        "rocket": {"cost": 1000, "damage": 170, "rate": 0.4, "range": 60, "unlock": 160, "splash": 12,
                   "burn": 0.2, "burnSeconds": 3},
    },
    "order": ["cannon", "gatling", "mortar", "sniper", "frost", "flame", "tesla", "rocket"],
    # pads: the count-th pad costs padClears clears of the level it is meant for
    "padLevels": [0, 1, 4, 7, 11, 16, 23, 32, 43, 60, 85, 115, 145, 190, 240, 290],
    "padClears": 0.5,
    # eggs
    "eggBase": 0.05, "eggStep": 2.5, "eggClears": 2.5, "firstEgg": 500,
    "slotBonus": [1, 1.6, 3, 6, 16], "slotWeight": [50, 30, 15, 4.5, 0.5],
    "secrets": [(0.01, 25), (0.0001, 250)], "hugeChance": 0.000001,
    # fusing: (bonus multiplier, fireRate, coinBonus) per tier, as Config.FuseTiers
    "fuse": [[3.5, 2, 0], [12, 0, 0.25], [40, 0, 0]],
    "defense": {"lives": 10, "bossLives": 999, "tick": 0.1, "syncHz": 5, "breakSeconds": 2, "petRange": 40,
                "sellRefund": 0.5, "failShare": 0.5, "watchDistance": 260, "chainRange": 16},
}


def world_of(level):
    index = min(WORLDS, max(1, math.ceil(level / WAVES_PER_WORLD)))
    return index, level - (index - 1) * WAVES_PER_WORLD


def wave_kind(level, knobs=KNOBS):
    index, local = world_of(level)
    rules = knobs["rules"][index - 1]
    if local == WAVES_PER_WORLD:
        return "final"
    if local == WAVES_PER_WORLD // 2:
        return "mid"
    if local % rules.get("bossEvery", 5) == 0:
        return "boss"
    return "normal"


def base_hp(level, knobs=KNOBS):
    return knobs["hp"] * level ** knobs["hpPower"] * knobs["hpGrowth"] ** (level - 1)


def base_coins(level, knobs=KNOBS):
    index = world_of(level)[0]
    first = (index - 1) * WAVES_PER_WORLD + 1
    start = knobs.get("headStart", [])
    head = start[level - 1] if level <= len(start) else 1
    return knobs["worldPay"][index - 1] * (level / first) ** knobs["coinPower"] * knobs["coinGrowth"] ** (level - first) * head


def level_plan(level, knobs=KNOBS):
    index, local = world_of(level)
    rules = knobs["rules"][index - 1]
    kind = wave_kind(level, knobs)
    k = knobs["kinds"][kind]
    boss = rules.get("boss", {}) if kind != "normal" else {}
    ease = knobs.get("easeIn", [])
    hp = base_hp(level, knobs) * k["hp"] * rules.get("hp", 1) * boss.get("hp", 1) * (ease[level - 1] if level <= len(ease) else 1)
    coins = base_coins(level, knobs) * k["coins"] * rules.get("coins", 1) * boss.get("coins", 1)
    first, last = knobs.get("crossSeconds", [1, 1])
    cross = first + (last - first) * (index - 1) / max(1, WORLDS - 1)
    speed = knobs["speed"] * k["speed"] * rules.get("speed", 1) * first / cross
    count, gap = knobs["count"], knobs["gap"]
    if kind == "normal":
        variant = knobs["variants"].get(local % 5)
        if variant:
            count = int(count * variant["count"])
            hp *= variant["hp"]
            coins *= variant["coins"]
            speed *= variant["speed"]
            gap *= variant["gap"]
        leak = max(1, math.floor(knobs["defense"]["lives"] * 2 / count))
    else:
        count = 1
        leak = knobs["defense"]["bossLives"]
    regen = boss.get("regen", rules.get("regen", 0))
    return {"kind": kind, "count": count, "hp": max(1, math.floor(hp)), "coins": max(1, math.floor(coins)),
            "speed": speed, "gap": gap, "regen": regen, "leak": leak}


def level_coins(level, knobs=KNOBS):
    """What an ordinary level pays in all, the world's coin rule included: the measure for every price."""
    level = max(1, level)
    return knobs["count"] * base_coins(level, knobs) * knobs["rules"][world_of(level)[0] - 1].get("coins", 1)


def tower_step(level):
    """Config.towerStep: how many tens of levels a tower has behind it. Its look (Config.towerTier) stops at 60."""
    return (level - 1) // 10


RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]


def draft(knobs=KNOBS):
    model = Model()
    model.features = features()
    model.tiers = model.features["tiers"]
    model.level_coins = [None] + [level_coins(level, knobs) for level in range(1, TOTAL + 1)]
    model.defense = knobs["defense"]
    model.chain_range = knobs["defense"]["chainRange"]
    model.path = PATH
    model.pads = PADS
    model.plans = [None] + [level_plan(level, knobs) for level in range(1, TOTAL + 1)]
    model.towers = knobs["towers"]
    model.tower_order = knobs["order"]
    for kind, tower in knobs["towers"].items():
        damage, upgrade = [None], [None]
        for level in range(1, MAX_TOWER_LEVEL + 1):
            damage.append(tower["damage"] * knobs["dmgStep"] ** (level - 1) * knobs["tierStep"] ** tower_step(level))
            upgrade.append(nice(tower["cost"] * knobs["upgradeShare"] * knobs["costStep"] ** (level - 1)))
        model.damage[kind] = damage
        model.upgrade[kind] = upgrade
    model.pad_price = [None, 0]
    for count in range(2, len(PADS) + 1):
        model.pad_price.append(nice(knobs["padClears"] * level_coins(knobs["padLevels"][count - 1], knobs)))
    for step in range(WORLDS * 2):
        world, half = step // 2, step % 2
        unlock = world * WAVES_PER_WORLD + half * WAVES_PER_WORLD // 2
        cost = knobs["firstEgg"] if step == 0 else nice(knobs["eggClears"] * level_coins(unlock + 1, knobs))
        base = knobs["eggBase"] * knobs["eggStep"] ** step
        # A world's first egg hatches mini cannons named like that world's five tower tiers (the set bonus).
        names = [model.tiers[world * 5 + slot] if half == 0 and world * 5 + slot < len(model.tiers) else "" for slot in range(5)]
        pets = [(w, base * b, r, n) for w, b, r, n in zip(knobs["slotWeight"], knobs["slotBonus"], RARITIES, names)]
        strongest = base * max(knobs["slotBonus"])
        for chance, mult in knobs["secrets"]:
            pets.append((chance, strongest * mult, "Secret", ""))
            pets[0] = (pets[0][0] - chance,) + pets[0][1:]
        # The Huge every egg hides takes its 1 in 100,000,000 from the Common too. The simulator never hatches one.
        pets[0] = (pets[0][0] - knobs["hugeChance"],) + pets[0][1:]
        model.eggs.append(dict(id="egg%d" % step, cost=cost, unlock=unlock, pets=pets))
    model.fuse = [tuple(tier) for tier in knobs["fuse"]]
    return model
