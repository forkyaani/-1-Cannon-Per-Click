-- All balance numbers and content tables. Server and client both read this.
-- The game is an idle defence: monsters walk a path on the player's plot and cannon towers on pads shoot them
-- (docs/IDLE_DEFENSE.md, docs/DEFENSE_SPEC.md). How the numbers were chosen: docs/BALANCE.md; the simulator that
-- plays them is tools/balance/sim.py, and tools/balance/model.py repeats the formulas below in Python
-- (`python3 tools/balance/sim.py --check` compares the two), so change both together.
-- Levels are numbered globally: world 1 is levels 1-50, world 2 is 51-100, and so on. The code and the save
-- call a level a `wave`, as they did when the game was a clicker.
local Config = {}

-- What the game is called, wherever it names itself.
Config.GameName = "+1 Cannon Per Click"

local rgb = Color3.fromRGB

-- Rounds to two significant digits so generated prices look hand-picked.
local function nice(n: number): number
	if n < 100 then
		return math.floor(n)
	end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / magnitude + 0.5) * magnitude
end

----------------------------------------------------------------------------------------------------
-- Worlds and monsters
-- Each world has WavesPerWorld levels. A new monster type appears every 10 levels.
-- Every 5th level is a single giant monster; level 25 is the mid boss and level 50 the world boss.
-- shape is one of the monster archetypes: blob, biped, floater, crawler, jelly, spiker.
-- Every world plays by a twist of its own. twist is the line the WORLDS window shows; rules holds the numbers
-- behind it, which Config.levelPlan applies (a world without rules plays plain):
--   hp, coins   multiply every monster's HP and coins
--   speed       multiplies how fast every monster walks
--   regen       share of its max HP every monster heals per second (nothing heals without it)
--   boss        hp, coins and regen again, for single-monster levels (giants, mid boss, world boss): hp and
--               coins multiply on top of the world-wide ones, regen replaces the world-wide one
--   bossEvery   how often a level is one giant monster, in place of Config.BossEvery
-- Saved data holds global level numbers, so new worlds only ever go at the end.
----------------------------------------------------------------------------------------------------
Config.WavesPerWorld = 50
Config.LevelMonsters = 10 -- monsters in an ordinary level (a swarm has twice as many, a pack of tanks half)
Config.BossEvery = 5

Config.Worlds = {
	{
		name = "Earth",
		twist = "Home turf: no special rules",
		floor = rgb(70, 122, 72),
		backdrop = rgb(120, 175, 225),
		sky = { clock = 14, brightness = 2.5, ambient = rgb(120, 120, 120) },
		monsters = {
			{ name = "Slime", shape = "blob", color = rgb(90, 200, 90), accent = rgb(60, 150, 60) },
			{ name = "Goblin", shape = "biped", color = rgb(100, 150, 70), accent = rgb(120, 80, 50) },
			{ name = "Rock Crab", shape = "crawler", color = rgb(220, 100, 70), accent = rgb(170, 60, 40) },
			{ name = "Wisp", shape = "floater", color = rgb(150, 220, 255), accent = rgb(90, 160, 220) },
			{ name = "Troll", shape = "biped", color = rgb(110, 130, 150), accent = rgb(70, 80, 90) },
		},
		midBoss = { name = "Ogre Chief", shape = "biped", color = rgb(170, 125, 80), accent = rgb(100, 60, 40) },
		finalBoss = { name = "Earth Titan", shape = "biped", color = rgb(120, 110, 100), accent = rgb(70, 160, 70) },
	},
	{
		name = "Moon",
		twist = "Low gravity: monsters walk 20% slower, but have 1.5x HP",
		rules = { speed = 0.8, hp = 1.5 },
		floor = rgb(150, 150, 160),
		backdrop = rgb(28, 28, 50),
		sky = { clock = 0, brightness = 1.5, ambient = rgb(150, 150, 175) },
		monsters = {
			{ name = "Moon Rockling", shape = "blob", color = rgb(170, 170, 180), accent = rgb(110, 110, 120) },
			{ name = "Crater Crawler", shape = "crawler", color = rgb(200, 200, 215), accent = rgb(120, 120, 150) },
			{ name = "Lunar Bat", shape = "floater", color = rgb(90, 70, 130), accent = rgb(50, 40, 80) },
			{ name = "Astro Ghost", shape = "floater", color = rgb(235, 240, 255), accent = rgb(150, 170, 220) },
			{ name = "Moon Golem", shape = "biped", color = rgb(130, 140, 165), accent = rgb(80, 90, 110) },
		},
		midBoss = { name = "Dark Side Stalker", shape = "crawler", color = rgb(60, 60, 80), accent = rgb(170, 60, 200) },
		finalBoss = { name = "Moon Colossus", shape = "biped", color = rgb(200, 205, 220), accent = rgb(90, 110, 190) },
	},
	{
		name = "Mars",
		twist = "War zone: bosses have 2x HP and pay 3x coins",
		rules = { boss = { hp = 2, coins = 3 } },
		floor = rgb(190, 90, 50),
		backdrop = rgb(235, 150, 90),
		sky = { clock = 17.6, brightness = 2, ambient = rgb(150, 110, 90) },
		monsters = {
			{ name = "Martian Grunt", shape = "biped", color = rgb(90, 190, 110), accent = rgb(50, 120, 70) },
			{ name = "Sand Worm", shape = "blob", color = rgb(215, 170, 110), accent = rgb(160, 110, 70) },
			{ name = "Red Scorpion", shape = "crawler", color = rgb(200, 50, 40), accent = rgb(120, 30, 20) },
			{ name = "Dust Devil", shape = "floater", color = rgb(225, 190, 140), accent = rgb(170, 130, 90) },
			{ name = "Rover Bot", shape = "crawler", color = rgb(160, 170, 180), accent = rgb(230, 190, 60) },
		},
		midBoss = { name = "Martian Warlord", shape = "biped", color = rgb(60, 150, 80), accent = rgb(200, 60, 40) },
		finalBoss = { name = "Olympus Guardian", shape = "biped", color = rgb(150, 60, 40), accent = rgb(240, 200, 90) },
	},
	{
		name = "Neptune",
		twist = "Deep freeze: monsters have 2x HP and pay 1.5x coins, but walk 25% slower",
		rules = { hp = 2, coins = 1.5, speed = 0.75 },
		floor = rgb(200, 230, 255),
		backdrop = rgb(50, 100, 200),
		sky = { clock = 7, brightness = 2.2, ambient = rgb(130, 150, 190) },
		monsters = {
			{ name = "Frost Imp", shape = "biped", color = rgb(150, 210, 255), accent = rgb(80, 140, 220) },
			{ name = "Snow Blob", shape = "blob", color = rgb(245, 250, 255), accent = rgb(190, 215, 240) },
			{ name = "Ice Wraith", shape = "floater", color = rgb(110, 230, 240), accent = rgb(60, 150, 200) },
			{ name = "Glacier Crab", shape = "crawler", color = rgb(80, 140, 230), accent = rgb(200, 235, 255) },
			{ name = "Yeti", shape = "biped", color = rgb(235, 240, 245), accent = rgb(140, 180, 220) },
		},
		midBoss = { name = "Blizzard Wraith", shape = "floater", color = rgb(190, 235, 255), accent = rgb(70, 110, 220) },
		finalBoss = { name = "Frost Giant", shape = "biped", color = rgb(120, 190, 250), accent = rgb(240, 250, 255) },
	},
	{
		name = "The Sun",
		twist = "Scorching heat: monsters heal 1% of their HP every second",
		rules = { regen = 0.01 },
		floor = rgb(120, 40, 20),
		backdrop = rgb(255, 140, 40),
		sky = { clock = 12, brightness = 3.5, ambient = rgb(190, 130, 90) },
		monsters = {
			{ name = "Magma Blob", shape = "blob", color = rgb(255, 120, 30), accent = rgb(200, 60, 20) },
			{ name = "Fire Imp", shape = "biped", color = rgb(230, 60, 40), accent = rgb(255, 190, 60) },
			{ name = "Lava Crab", shape = "crawler", color = rgb(150, 40, 30), accent = rgb(255, 130, 30) },
			{ name = "Flare Spirit", shape = "floater", color = rgb(255, 220, 90), accent = rgb(255, 140, 40) },
			{ name = "Cinder Golem", shape = "biped", color = rgb(60, 50, 50), accent = rgb(255, 100, 30) },
		},
		midBoss = { name = "Inferno Hound", shape = "crawler", color = rgb(90, 30, 20), accent = rgb(255, 160, 40) },
		finalBoss = { name = "Solar Titan", shape = "biped", color = rgb(255, 180, 50), accent = rgb(255, 80, 30) },
	},
	{
		name = "The Void",
		twist = "The Void: monsters have 3x HP and pay 3x coins",
		rules = { hp = 3, coins = 3 },
		floor = rgb(34, 22, 56),
		backdrop = rgb(12, 6, 24),
		sky = { clock = 0, brightness = 1, ambient = rgb(130, 100, 170) },
		monsters = {
			{ name = "Shadow Wisp", shape = "floater", color = rgb(110, 70, 170), accent = rgb(60, 30, 110) },
			{ name = "Null Blob", shape = "blob", color = rgb(40, 30, 60), accent = rgb(160, 80, 230) },
			{ name = "Rift Stalker", shape = "crawler", color = rgb(130, 60, 200), accent = rgb(230, 120, 255) },
			{ name = "Void Eye", shape = "floater", color = rgb(25, 15, 40), accent = rgb(220, 60, 120) },
			{ name = "Abyss Knight", shape = "biped", color = rgb(50, 45, 70), accent = rgb(120, 220, 255) },
		},
		midBoss = { name = "Rift Warden", shape = "biped", color = rgb(90, 40, 150), accent = rgb(255, 120, 220) },
		finalBoss = { name = "Void King", shape = "biped", color = rgb(20, 12, 34), accent = rgb(255, 60, 90) },
	},
	{
		name = "Nebula",
		twist = "Cloud bodies: monsters walk 30% faster and heal 1.5% of their HP every second",
		rules = { speed = 1.3, regen = 0.015 },
		floor = rgb(84, 62, 150),
		backdrop = rgb(232, 112, 196),
		sky = { clock = 6.2, brightness = 2, ambient = rgb(190, 140, 200) },
		monsters = {
			{ name = "Stardust Mite", shape = "crawler", color = rgb(240, 215, 255), accent = rgb(150, 95, 215) },
			{ name = "Gas Puff", shape = "blob", color = rgb(160, 245, 205), accent = rgb(90, 190, 150) },
			{ name = "Nebula Jelly", shape = "jelly", color = rgb(110, 215, 240), accent = rgb(240, 125, 220) },
			{ name = "Plasma Sprite", shape = "floater", color = rgb(255, 240, 110), accent = rgb(255, 150, 60) },
			{ name = "Star Hatchling", shape = "biped", color = rgb(235, 245, 255), accent = rgb(255, 205, 80) },
		},
		midBoss = { name = "Cloud Leviathan", shape = "jelly", color = rgb(70, 60, 170), accent = rgb(120, 230, 255) },
		finalBoss = { name = "Nebula Queen", shape = "biped", color = rgb(110, 50, 190), accent = rgb(255, 215, 90) },
	},
	{
		name = "Crystal Belt",
		twist = "Crystal armour: monsters have 4x HP and pay 4x coins",
		rules = { hp = 4, coins = 4 },
		floor = rgb(64, 190, 184),
		backdrop = rgb(22, 52, 86),
		sky = { clock = 21, brightness = 1.6, ambient = rgb(130, 185, 195) },
		monsters = {
			{ name = "Shardling", shape = "spiker", color = rgb(250, 250, 255), accent = rgb(160, 110, 240) },
			{ name = "Quartz Crab", shape = "crawler", color = rgb(250, 190, 215), accent = rgb(255, 255, 255) },
			{ name = "Prism Bat", shape = "floater", color = rgb(200, 120, 240), accent = rgb(120, 240, 230) },
			{ name = "Geode Roller", shape = "blob", color = rgb(150, 130, 160), accent = rgb(200, 100, 235) },
			{ name = "Crystal Golem", shape = "biped", color = rgb(250, 200, 90), accent = rgb(255, 245, 210) },
		},
		midBoss = { name = "Shard Sentinel", shape = "spiker", color = rgb(170, 100, 235), accent = rgb(250, 250, 255) },
		finalBoss = { name = "Crystal Monarch", shape = "biped", color = rgb(240, 250, 255), accent = rgb(250, 130, 230) },
	},
	{
		name = "Robot Factory",
		twist = "Assembly line: a giant rolls out every 2 levels",
		rules = { bossEvery = 2 },
		floor = rgb(84, 90, 100),
		backdrop = rgb(238, 186, 52),
		sky = { clock = 16.5, brightness = 2.2, ambient = rgb(150, 145, 135) },
		monsters = {
			{ name = "Scrap Bot", shape = "biped", color = rgb(150, 110, 85), accent = rgb(90, 80, 75) },
			{ name = "Welder Drone", shape = "floater", color = rgb(70, 130, 200), accent = rgb(255, 120, 40) },
			{ name = "Saw Crawler", shape = "crawler", color = rgb(200, 205, 215), accent = rgb(230, 70, 50) },
			{ name = "Spike Mine", shape = "spiker", color = rgb(50, 55, 65), accent = rgb(255, 70, 50) },
			{ name = "Guard Mech", shape = "biped", color = rgb(60, 100, 170), accent = rgb(235, 240, 245) },
		},
		midBoss = { name = "Crusher Tank", shape = "crawler", color = rgb(190, 70, 40), accent = rgb(50, 50, 60) },
		finalBoss = { name = "Factory Overlord", shape = "biped", color = rgb(40, 45, 58), accent = rgb(80, 255, 170) },
	},
	{
		name = "Alien Jungle",
		twist = "Overgrowth: bosses heal 1% of their HP every second, but pay 5x coins",
		rules = { boss = { regen = 0.01, coins = 5 } },
		floor = rgb(34, 104, 72),
		backdrop = rgb(170, 222, 84),
		sky = { clock = 9.5, brightness = 2.4, ambient = rgb(125, 165, 120) },
		monsters = {
			{ name = "Spore Puff", shape = "floater", color = rgb(240, 120, 200), accent = rgb(150, 60, 130) },
			{ name = "Vine Creeper", shape = "crawler", color = rgb(150, 80, 190), accent = rgb(250, 190, 80) },
			{ name = "Snap Pod", shape = "blob", color = rgb(225, 60, 90), accent = rgb(60, 140, 70) },
			{ name = "Thorn Beast", shape = "spiker", color = rgb(120, 80, 50), accent = rgb(250, 235, 170) },
			{ name = "Jungle Stalker", shape = "biped", color = rgb(30, 70, 110), accent = rgb(250, 150, 50) },
		},
		midBoss = { name = "Venom Hydra", shape = "jelly", color = rgb(110, 50, 150), accent = rgb(250, 240, 90) },
		finalBoss = { name = "Jungle Behemoth", shape = "biped", color = rgb(110, 60, 40), accent = rgb(240, 80, 140) },
	},
	{
		name = "Black Hole",
		twist = "Time warp: monsters walk 40% faster and have 2x HP, but pay 3x coins",
		rules = { hp = 2, speed = 1.4, coins = 3 },
		floor = rgb(22, 20, 30),
		backdrop = rgb(150, 28, 58),
		sky = { clock = 0, brightness = 0.9, ambient = rgb(160, 110, 120) },
		monsters = {
			{ name = "Dark Matter Blob", shape = "blob", color = rgb(120, 80, 220), accent = rgb(255, 150, 60) },
			{ name = "Gravity Mite", shape = "crawler", color = rgb(255, 200, 110), accent = rgb(255, 255, 255) },
			{ name = "Time Eater", shape = "jelly", color = rgb(240, 235, 255), accent = rgb(255, 150, 70) },
			{ name = "Warp Wraith", shape = "floater", color = rgb(90, 220, 230), accent = rgb(40, 110, 160) },
			{ name = "Horizon Knight", shape = "biped", color = rgb(250, 160, 50), accent = rgb(40, 34, 60) },
		},
		midBoss = { name = "Graviton", shape = "spiker", color = rgb(235, 235, 245), accent = rgb(255, 170, 70) },
		finalBoss = { name = "Star Devourer", shape = "blob", color = rgb(8, 8, 12), accent = rgb(255, 140, 40) },
	},
	{
		name = "The Big Bang",
		twist = "The final test: 5x HP, 20% faster, healing 1% a second, 10x coins",
		rules = { hp = 5, speed = 1.2, regen = 0.01, coins = 10 },
		floor = rgb(255, 214, 110),
		backdrop = rgb(255, 250, 235),
		sky = { clock = 12, brightness = 4, ambient = rgb(225, 215, 190) },
		monsters = {
			{ name = "Quark", shape = "blob", color = rgb(235, 70, 80), accent = rgb(255, 230, 140) },
			{ name = "Atom Spinner", shape = "spiker", color = rgb(50, 140, 235), accent = rgb(20, 50, 130) },
			{ name = "Photon Sprite", shape = "floater", color = rgb(255, 150, 30), accent = rgb(200, 60, 30) },
			{ name = "Antimatter Jelly", shape = "jelly", color = rgb(60, 30, 95), accent = rgb(40, 200, 180) },
			{ name = "Proto Titan", shape = "biped", color = rgb(150, 60, 200), accent = rgb(255, 140, 40) },
		},
		midBoss = { name = "Chaos Herald", shape = "jelly", color = rgb(200, 50, 150), accent = rgb(70, 30, 110) },
		finalBoss = { name = "Genesis Titan", shape = "biped", color = rgb(50, 30, 110), accent = rgb(255, 170, 30) },
	},
}
Config.TotalWaves = #Config.Worlds * Config.WavesPerWorld

-- Monsters get faster with every world: an ordinary monster crosses the path in CrossSeconds[1] on the
-- first world, a little less on each world after it, down to CrossSeconds[2] on the last.
Config.CrossSeconds = { 20, 10 }

-- Per level kind: HP, coin and walking-speed multipliers, and the scale of the monster's model.
-- A boss is slow: it is on the path for most of a minute, and what counts is whether the towers get through
-- its HP before it reaches the gate.
Config.WaveKinds = {
	normal = { hp = 1, coins = 1, speed = 1, scale = 1.5 },
	boss = { hp = 6, coins = 15, speed = 0.7, scale = 3.3 },
	mid = { hp = 9, coins = 25, speed = 0.65, scale = 3.9 },
	final = { hp = 14, coins = 40, speed = 0.6, scale = 4.5 },
}

-- Whether a player whose best-ever cleared level is `bestCleared` has reached a world: its island and its
-- eggs open with it. The first world is always open.
function Config.worldUnlocked(index: number, bestCleared: number): boolean
	return Config.Worlds[index] ~= nil and bestCleared >= (index - 1) * Config.WavesPerWorld
end

-- Returns the world index and the level number inside that world.
function Config.worldOf(wave: number): (number, number)
	local index = math.clamp(math.ceil(wave / Config.WavesPerWorld), 1, #Config.Worlds)
	return index, wave - (index - 1) * Config.WavesPerWorld
end

local NO_RULES: { [string]: any } = {}

-- The rules of the world a level is in. A world without any plays plain.
local function rulesOf(wave: number): { [string]: any }
	return Config.Worlds[Config.worldOf(wave)].rules or NO_RULES
end

function Config.waveKind(wave: number): string
	local _, localWave = Config.worldOf(wave)
	if localWave == Config.WavesPerWorld then
		return "final"
	elseif localWave == Config.WavesPerWorld / 2 then
		return "mid"
	elseif localWave % (rulesOf(wave).bossEvery or Config.BossEvery) == 0 then
		return "boss"
	end
	return "normal"
end

-- "Earth level 25" style label for a global level number.
function Config.waveLabel(wave: number): string
	if wave <= 0 then
		return "the start"
	end
	local index, localWave = Config.worldOf(wave)
	return `{Config.Worlds[index].name} level {localWave}`
end

-- What to draw for a level. key changes whenever the monster models must be rebuilt.
function Config.monsterFor(wave: number)
	local index, localWave = Config.worldOf(wave)
	local world = Config.Worlds[index]
	local kind = Config.waveKind(wave)
	local tier = math.clamp(math.ceil(localWave / 10), 1, #world.monsters)
	local base = world.monsters[tier]
	local name = base.name
	if kind == "boss" then
		name = "Giant " .. base.name
	elseif kind == "mid" then
		base = world.midBoss
		name = base.name
	elseif kind == "final" then
		base = world.finalBoss
		name = base.name
	end
	return {
		name = name,
		shape = base.shape,
		color = base.color,
		accent = base.accent,
		kind = kind,
		scale = Config.WaveKinds[kind].scale,
		key = `{index}:{tier}:{kind}`,
	}
end

----------------------------------------------------------------------------------------------------
-- The defence: lives, the simulation's clock, what is sent to clients (docs/DEFENSE_SPEC.md, section 3).
----------------------------------------------------------------------------------------------------
Config.Defense = {
	lives = 10, -- per level
	-- Lives a boss costs when it reaches the gate: every life there can be (the `lives` modifiers stop at 999),
	-- so a boss that gets through fails the level whatever mastery or an enchantment added to the lives. At 10,
	-- one extra life let every boss walk through and the level still counted as cleared.
	bossLives = 999,
	tick = 0.1, -- seconds per simulation step
	syncHz = 5, -- field messages per second, per plot
	breakSeconds = 2, -- pause between two levels
	-- Studs around the player in which their mini cannons are DRAWN shooting, and in which a Huge fires its Huge
	-- Shot. The mini cannons' own damage needs no range: it lands on the lead monster of the base wherever the
	-- player is (Config.petDps).
	petRange = 40,
	sellRefund = 0.5, -- share of the coins put into a tower that selling gives back
	failShare = 0.5, -- a boss that gets through pays this share of its coins, times the share of its health shot off
	watchDistance = 260, -- a client is sent the field of plots whose origin is within this of their character
	chainRange = 16, -- studs a chaining shot (Tesla) can jump from one monster to the next
}

----------------------------------------------------------------------------------------------------
-- Levels. An ordinary monster of level L has  hp * L^hpPower * hpGrowth^(L - 1)  health and pays coins the
-- same way; the level's kind (Config.WaveKinds), its variant and the world's rules multiply that.
-- HP grows faster than coins on purpose (and coinPower is negative: the first levels are generous): the
-- further in, the more levels have to be farmed to get past the next boss. docs/BALANCE.md has the pace this
-- gives. The balance is on a knife's edge: a coinGrowth of 1.1445 instead of 1.1455 is a game 40% longer.
-- Change a number here only with the simulator open.
----------------------------------------------------------------------------------------------------
Config.Level = {
	-- hpGrowth was 1.172 until 6 Oct: monsters outgrew the towers from the second world on (the Moon 12 hours,
	-- Mars 92). At 1.1365 sim.py gives 52 hours for the twelve worlds; 1.1355 gives 32 and 1.1375 gives 80.
	hp = 10, hpPower = 0.5, hpGrowth = 1.1365,
	-- Coins. Every world has an anchor of its own: what an ordinary monster of its first level pays. Inside
	-- the world a monster pays  anchor * (level / first)^coinPower * coinGrowth^(level - first).
	-- tools/balance/fit.py sets the anchors, one world at a time, so that every world takes the simulated
	-- player its target time (docs/BALANCE.md).
	worldPay = { 15, 5000, 2.553e6, 1.845e9, 1.981e12, 1.268e15, 1.655e18, 1.002e21, 8.768e23, 1.149e27, 6.779e29, 6.504e32 },
	coinPower = -0.25, coinGrowth = 1.1455,
	-- Coin multipliers of the very first levels: a new player's first minutes pay well, so the tutorial's
	-- pads and towers come quickly, and the grind sets in as the head start runs out.
	headStart = {},
	speed = 18, -- studs per second; the path is Layout.PATH_LENGTH (359) studs long
	gap = 1.25, -- seconds between two spawns
	-- HP multipliers of the very first levels. A brand-new player who touches nothing must not be stopped by
	-- the first swarm (level 3) or the first tanks (level 4): the free starter cannon, never upgraded, clears
	-- up to level 4. The first giant (level 5) is the first wall, and the tutorial has paid for an upgrade, a
	-- pad and a second cannon by then.
	easeIn = { 1, 1, 0.75, 0.4 },
}

-- Of every five levels the third is a swarm and the fourth a pack of tanks (the fifth is a giant):
-- count, hp, coins, speed and gap multiply the ordinary level's. The level pays the same coins in all.
-- No level has more than 20 monsters: the field message (Game.luau) has to stay small.
local VARIANTS = {
	[3] = { name = "swarm", count = 2, hp = 0.5, coins = 0.5, speed = 1.25, gap = 0.5 },
	[4] = { name = "tanks", count = 0.5, hp = 2, coins = 2, speed = 0.8, gap = 2 },
}

local function baseHP(level: number): number
	local curve = Config.Level
	return curve.hp * level ^ curve.hpPower * curve.hpGrowth ^ (level - 1)
end

local function baseCoins(level: number): number
	local curve = Config.Level
	local world = Config.worldOf(level)
	local first = (world - 1) * Config.WavesPerWorld + 1
	local anchor = curve.worldPay[world] or curve.worldPay[#curve.worldPay]
	return anchor * (level / first) ^ curve.coinPower * curve.coinGrowth ^ (level - first) * (curve.headStart[level] or 1)
end

-- What an ordinary level pays in all, before the player's coin multiplier: the measure for the prices of
-- pads, eggs, island shops and crates, and for the coins the story and the crates pay. The world's own coin
-- rule counts (a world that pays 3x coins has 3x prices), so a "clear" is the same effort in every world.
-- Level 0 counts as level 1.
local function levelCoins(level: number): number
	level = math.max(1, level)
	return Config.LevelMonsters * baseCoins(level) * (rulesOf(level).coins or 1)
end
Config.levelCoins = levelCoins

-- Everything about a level (docs/DEFENSE_SPEC.md, section 3):
--   kind     normal, boss, mid or final        count   monsters in the level
--   hp       each                              coins   each, before the player's coin multiplier
--   speed    studs per second                  gap     seconds between two spawns
--   regen    share of max HP healed per second (0 in most worlds)
--   leak     lives one monster costs when it reaches the gate
--   variant  "swarm" or "tanks" on those levels, nil otherwise
--   monster  Config.monsterFor(level): name, shape, colours, kind, scale, key
function Config.levelPlan(level: number)
	local _, localWave = Config.worldOf(level)
	local rules = rulesOf(level)
	local kind = Config.waveKind(level)
	local kindDef = Config.WaveKinds[kind]
	local boss = if kind == "normal" then NO_RULES else rules.boss or NO_RULES
	local curve = Config.Level
	local hp = baseHP(level) * kindDef.hp * (rules.hp or 1) * (boss.hp or 1) * (curve.easeIn[level] or 1)
	local coins = baseCoins(level) * kindDef.coins * (rules.coins or 1) * (boss.coins or 1)
	local worldShare = (Config.worldOf(level) - 1) / math.max(1, #Config.Worlds - 1)
	local cross = Config.CrossSeconds[1] + (Config.CrossSeconds[2] - Config.CrossSeconds[1]) * worldShare
	local speed = curve.speed * kindDef.speed * (rules.speed or 1) * Config.CrossSeconds[1] / cross
	local count, gap, leak, variantName = 1, curve.gap, Config.Defense.bossLives, nil
	if kind == "normal" then
		count = Config.LevelMonsters
		local variant = VARIANTS[localWave % 5]
		if variant then
			variantName = variant.name
			count = math.floor(count * variant.count)
			hp *= variant.hp
			coins *= variant.coins
			speed *= variant.speed
			gap *= variant.gap
		end
		-- Half of an ordinary level may get through; one more and it is lost.
		leak = math.max(1, math.floor(Config.Defense.lives * 2 / count))
	end
	return {
		kind = kind,
		count = count,
		hp = math.max(1, math.floor(hp)),
		coins = math.max(1, math.floor(coins)),
		speed = speed,
		gap = gap,
		regen = boss.regen or rules.regen or 0,
		leak = leak,
		variant = variantName,
		monster = Config.monsterFor(level),
	}
end

Config.MilestoneEvery = 25 -- first-ever clear of each 25th level pays diamonds
Config.MilestoneDiamonds = 15
-- Game.damage (abilities, burns from features): damage left over from a kill carries into the next monster.
-- One call kills at most this many, so the server's work per call stays bounded.
Config.MaxChainKills = 50

----------------------------------------------------------------------------------------------------
-- Tier styles: the look and the name a tower takes on as it is upgraded (Config.towerTier), five per world.
-- A mini cannon whose short name matches the tier name of one of the player's towers gets Config.SetBonus.
----------------------------------------------------------------------------------------------------
local CANNON_STYLES = {
	{ "Wooden", rgb(133, 94, 66) }, { "Iron", rgb(120, 124, 130) }, { "Steel", rgb(176, 190, 204) },
	{ "Gold", rgb(255, 200, 40) }, { "Diamond", rgb(80, 220, 255) },
	{ "Moonrock", rgb(170, 170, 185) }, { "Crater", rgb(110, 110, 130) }, { "Lunar", rgb(215, 220, 240) },
	{ "Astro", rgb(90, 120, 220) }, { "Stellar", rgb(250, 240, 170) },
	{ "Rust", rgb(180, 90, 50) }, { "Dune", rgb(225, 185, 120) }, { "Martian", rgb(90, 190, 110) },
	{ "Rover", rgb(200, 205, 210) }, { "Warlord", rgb(190, 40, 40) },
	{ "Frost", rgb(170, 220, 255) }, { "Glacier", rgb(90, 160, 235) }, { "Crystal", rgb(120, 240, 245) },
	{ "Blizzard", rgb(235, 245, 255) }, { "Aurora", rgb(120, 255, 200) },
	{ "Ember", rgb(255, 140, 60) }, { "Magma", rgb(230, 80, 30) }, { "Obsidian", rgb(45, 35, 55) },
	{ "Inferno", rgb(255, 60, 20) }, { "Solar", rgb(255, 215, 80) },
	{ "Shadow", rgb(60, 50, 85) }, { "Rift", rgb(140, 60, 210) }, { "Abyss", rgb(25, 25, 70) },
	{ "Singularity", rgb(245, 245, 255) }, { "Omega", rgb(255, 60, 120) },
	{ "Stardust", rgb(232, 196, 255) }, { "Plasma", rgb(255, 110, 200) }, { "Nova", rgb(120, 215, 255) },
	{ "Pulsar", rgb(150, 255, 225) }, { "Quasar", rgb(255, 240, 170) },
	{ "Shard", rgb(150, 235, 230) }, { "Quartz", rgb(246, 236, 250) }, { "Amethyst", rgb(170, 90, 225) },
	{ "Opal", rgb(190, 245, 225) }, { "Radiant", rgb(255, 170, 240) },
	{ "Scrap", rgb(150, 120, 95) }, { "Gear", rgb(205, 165, 80) }, { "Piston", rgb(170, 180, 190) },
	{ "Chrome", rgb(225, 235, 245) }, { "Reactor", rgb(110, 255, 120) },
	{ "Moss", rgb(110, 150, 70) }, { "Thorn", rgb(125, 90, 60) }, { "Venom", rgb(150, 235, 60) },
	{ "Orchid", rgb(222, 110, 212) }, { "Apex", rgb(255, 150, 50) },
	{ "Gravity", rgb(96, 84, 140) }, { "Vortex", rgb(125, 60, 205) }, { "Eclipse", rgb(40, 34, 50) },
	{ "Neutron", rgb(190, 230, 255) }, { "Horizon", rgb(255, 120, 60) },
	{ "Quark", rgb(255, 120, 110) }, { "Atom", rgb(110, 210, 255) }, { "Photon", rgb(255, 250, 190) },
	{ "Cosmic", rgb(190, 110, 255) }, { "Big Bang", rgb(255, 235, 150) },
}
Config.CannonsPerWorld = 5
Config.Cannons = {}
for tier, style in CANNON_STYLES do
	Config.Cannons[tier] = {
		short = style[1],
		name = style[1] .. " Cannon",
		color = style[2],
		-- Dead with the big cannon. The core never reads them; they stay, as harmless numbers, until the
		-- clicker's HUD (which prints them) and its tutorial (which pays `cost` as a reward) are replaced.
		mult = 1,
		cost = if tier == 1 then 0 else 150,
	}
end

----------------------------------------------------------------------------------------------------
-- Towers: what stands on the pads. Config.TowerOrder lists the kinds in shop order.
--   cost     coins to build at level 1          damage   per shot at level 1, before multipliers
--   rate     shots per second                   range    studs, from the pad's centre
--   unlock   best-ever level cleared needed to build it
-- Specials (all optional):
--   splash                the shot also hits everything this many studs from the target
--   slow, slowSeconds     0.4 = the target walks 40% slower for that long
--   burn, burnSeconds     share of the shot's damage dealt again every second for that long
--   chain                 the shot jumps to this many more monsters (each within Defense.chainRange of the last)
--   boss                  damage multiplier on single-monster (boss) levels
-- Every level multiplies damage by TowerCurve.damage, every tenth level (a new tier) by TowerCurve.tier as
-- well; an upgrade costs TowerCurve.cost times the one before. Cost outgrows damage, so spreading coins over
-- many towers beats pouring them into one.
----------------------------------------------------------------------------------------------------
Config.TowerMaxLevel = 750
Config.TowerCurve = {
	damage = 1.10, -- per level
	tier = 1.3, -- per tier, on top
	cost = 1.15, -- per level
	upgrade = 0.5, -- the first upgrade's price, as a share of the build cost
}

Config.Towers = {
	cannon = {
		name = "Cannon", desc = "A steady all-rounder", color = rgb(133, 94, 66),
		cost = 50, damage = 36, rate = 1, range = 30, unlock = 0,
	},
	gatling = {
		name = "Gatling", desc = "Small shots, very fast, short range", color = rgb(150, 160, 175),
		cost = 100, damage = 16, rate = 5, range = 22, unlock = 3,
	},
	mortar = {
		name = "Mortar", desc = "Slow shells that hit every monster near the target", color = rgb(90, 110, 80),
		cost = 150, damage = 168, rate = 0.3, range = 45, unlock = 8, splash = 10,
	},
	sniper = {
		name = "Sniper", desc = "Reaches most of the plot and hits bosses 2.5x as hard", color = rgb(60, 90, 150),
		cost = 250, damage = 240, rate = 0.2, range = 90, unlock = 14, boss = 2.5,
	},
	frost = {
		name = "Frost", desc = "Slows what it hits by 40%", color = rgb(150, 215, 255),
		cost = 300, damage = 40, rate = 1, range = 28, unlock = 22, slow = 0.4, slowSeconds = 2.5,
	},
	flame = {
		name = "Flame", desc = "Sets monsters on fire: they keep burning for 3 seconds", color = rgb(255, 120, 40),
		cost = 400, damage = 44, rate = 4, range = 20, unlock = 55, burn = 0.25, burnSeconds = 3,
	},
	tesla = {
		name = "Tesla", desc = "Lightning that jumps to 3 more monsters", color = rgb(120, 200, 255),
		cost = 600, damage = 160, rate = 1.2, range = 30, unlock = 105, chain = 3,
	},
	rocket = {
		name = "Rocket", desc = "Long range blast that leaves everything burning", color = rgb(210, 60, 60),
		cost = 1000, damage = 680, rate = 0.4, range = 60, unlock = 160, splash = 12, burn = 0.2, burnSeconds = 3,
	},
}
Config.TowerOrder = { "cannon", "gatling", "mortar", "sniper", "frost", "flame", "tesla", "rocket" }

-- The look and the name of a tower of this level: an index into Config.Cannons. A new one every ten levels.
function Config.towerTier(level: number): number
	return math.min(#Config.Cannons, 1 + (level - 1) // 10)
end

-- Damage of one shot, before the player's multipliers. The tier bonus keeps coming every ten levels, also
-- past the last tier style (level 591): there the tower stops changing its look, not its strength.
function Config.towerDamage(kind: string, level: number): number
	local curve = Config.TowerCurve
	return Config.Towers[kind].damage * curve.damage ^ (level - 1) * curve.tier ^ ((level - 1) // 10)
end

-- Coins to go from `level` to `level + 1`. mult is the player's upgrade-cost multiplier (the `upgradeCost`
-- modifiers; the client reads it as the UpgradeCost attribute): 1 when left out.
function Config.towerUpgradeCost(kind: string, level: number, mult: number?): number
	local curve = Config.TowerCurve
	local cost = nice(Config.Towers[kind].cost * curve.upgrade * curve.cost ^ (level - 1))
	return if mult and mult ~= 1 then math.max(1, nice(cost * mult)) else cost
end

-- The build cost plus every upgrade so far: what selling refunds a share of.
function Config.towerInvested(kind: string, level: number): number
	local total = Config.Towers[kind].cost
	for below = 1, level - 1 do
		total += Config.towerUpgradeCost(kind, below)
	end
	return total
end

-- Buying upgrades one at a time from `level` for as long as `coins` last, `levels` of them at most:
-- the level reached and what they cost together. The server buys and the tower window previews from here.
function Config.towerUpgrades(kind: string, level: number, coins: number, levels: number, mult: number?): (number, number)
	local spent = 0
	for _ = 1, levels do
		if level >= Config.TowerMaxLevel then
			break
		end
		local cost = Config.towerUpgradeCost(kind, level, mult)
		if spent + cost > coins then
			break
		end
		spent += cost
		level += 1
	end
	return level, spent
end

-- Pads: the count-th pad a player buys costs PadClears clears of the level it is meant for. The first is free.
local PAD_LEVELS = { 0, 1, 4, 7, 11, 16, 23, 32, 43, 60, 85, 115, 145, 190, 240, 290 }
Config.PadClears = 0.5

-- Coins for the player's `count`-th pad. Past the last pad there is nothing to buy: infinite.
function Config.padPrice(count: number): number
	if count <= 1 then
		return 0
	end
	local level = PAD_LEVELS[count]
	return if level then nice(Config.PadClears * levelCoins(level)) else math.huge
end

-- The tier names of a player's towers, as a set: { Wooden = true, Gold = true }. towers is the saved table
-- (or the one in State.meta): [pad] = { kind, level }.
function Config.towerNames(towers): { [string]: boolean }
	local names = {}
	for _, tower in towers do
		names[Config.Cannons[Config.towerTier(tower.level)].short] = true
	end
	return names
end

----------------------------------------------------------------------------------------------------
-- Mini cannons (pets) and the eggs they hatch from.
-- A mini cannon deals damage of its own: its bonus times PetDps is its damage per second while it is equipped
-- (bonus 1.29 = +677 DPS; every entry carries it as `dps`). It is flat: it multiplies nothing and no tower
-- multiplier touches it (the Veteran level, rebirths, 2x Power and a Huge's x3 are all tower damage). The
-- server deals it to the lead monster of the owner's base all the time, wherever the player is, in shots of
-- DPS / shots per second, so firing faster changes how it looks and not what it adds up to. (Until 5 Oct the
-- bonus was a multiplier on all tower damage: +129%. The numbers are the same; what they do is far less.)
-- A mini cannon named like the tier of one of the player's towers (Mini Gold Cannon + a Gold tower) gets
-- SetBonus: the hidden buff.
--
-- How the bonuses scale: every coin egg is EggCurve.step (2.5x) stronger than the one before it. That was
-- tuned for the multiplier: as flat DPS it falls behind the towers world by world, and docs/BALANCE.md,
-- section 3, says what has to be measured again.
----------------------------------------------------------------------------------------------------
Config.SetBonus = 1.5
Config.PetDps = 525 -- damage per second of a mini cannon per 1 of its bonus (100 until 6 Oct: 3.5x, then 1.5x)
Config.EggCurve = {
	base = 0.05, -- the Common of the first egg: +26 DPS
	step = 2.5, -- every coin egg's mini cannons are this many times as strong as the last egg's
	clears = 2.5, -- an egg costs this many clears of the level that unlocks it
	first = 500, -- except the first
}
Config.MaxEquipped = 3
Config.MaxExtraSlots = 3
Config.MaxPets = 50
Config.AutoShotsPerPet = 1 -- automatic shots per second from each equipped mini cannon

Config.RarityColors = {
	Common = rgb(190, 190, 190),
	Uncommon = rgb(90, 210, 110),
	Rare = rgb(80, 150, 255),
	Epic = rgb(190, 90, 255),
	Legendary = rgb(255, 200, 40),
	Exclusive = rgb(255, 80, 120),
	Secret = rgb(255, 60, 220),
	Mythical = rgb(255, 90, 40), -- Huge cannons
}

Config.Pets = {}
Config.Eggs = {}
Config.EggById = {}

local SLOT_RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local SLOT_WEIGHT = { 50, 30, 15, 4.5, 0.5 } -- adds up to 100, so a weight is also the % chance
local SLOT_BONUS = { 1, 1.6, 3, 6, 16 }

local function petId(short: string): string
	return (string.lower(short):gsub("[^%a]", ""))
end

-- Two significant digits, at any size.
local function round2(n: number): number
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / magnitude + 0.5) * magnitude
end

-- Bonuses set by hand (the gem egg, the event eggs, the Exclusives) were chosen on the clicker's curve, where
-- every egg was 16x the one before and the first egg's Legendary was +400%. onCurve puts one at the same place
-- on today's curve: as many eggs up the game as it was then.
local function onCurve(old: number): number
	local eggs = math.log(old / 4) / math.log(16)
	return round2(Config.EggCurve.base * SLOT_BONUS[#SLOT_BONUS] * Config.EggCurve.step ^ eggs)
end

local function definePet(short: string, rarity: string, bonus: number, color: Color3): string
	local id = petId(short)
	assert(not Config.Pets[id], "duplicate pet " .. id)
	Config.Pets[id] = { short = short, name = `Mini {short} Cannon`, rarity = rarity, bonus = bonus, color = color }
	return id
end

-- Huge cannons: Mythical, four times the size of a mini cannon, never fused. The strongest thing in the game.
-- A Huge multiplies ALL tower damage by `power` (Config.hugeMult), so it is worth as much in the last world
-- as in the first, and each different Huge multiplies again. It is the one mini cannon that still multiplies.
-- Its bonus is infinite only so that everything that asks "which one is stronger" (what to
-- release when storage is full, how the mini cannons window sorts) puts a Huge on top.
-- x3 is about 7 levels of monster health (it was x100 in the clicker: 29 levels and several hours of play,
-- which no balance survives).
-- Its own damage per second (it fires like any mini cannon) is modest: as much as the strongest ordinary mini
-- cannon equipped beside it, and never under HugeDps (Config.petDpsList).
-- Every equipped Huge also fires a Huge Shot of its own (Config.HugeShot; the server half is
-- src/server/Features/Huge.luau), and has a special feature while it is equipped: src/shared/Features/Huge.luau.
Config.HugePower = 3
Config.HugeDps = 262.5 -- the least a Huge's own shots deal a second (one with no ordinary mini cannon beside it)
-- The Huge Shot: every `seconds` each equipped Huge fires one giant shot worth `shots` mini cannon shots (hero
-- shots) at once, at the monster furthest along within Defense.petRange of the player, like the mini cannons'
-- own shots: only while the player is on their plot and near the fight.
Config.HugeShot = { seconds = 2, shots = 5 }

-- The Huge Shot in a few words, written from its numbers.
function Config.hugeShotText(): string
	return `Huge Shot every {Config.HugeShot.seconds}s worth {Config.HugeShot.shots} shots`
end
Config.Huges = {} -- their ids, in the order they are defined

local function defineHuge(short: string, color: Color3, accent: Color3): string
	local id = "huge" .. petId(short)
	assert(not Config.Pets[id], "duplicate pet " .. id)
	Config.Pets[id] = {
		short = short,
		name = `Huge {short} Cannon`,
		rarity = "Mythical",
		bonus = math.huge,
		power = Config.HugePower,
		color = color,
		accent = accent, -- its glowing bands and halo
		huge = true,
	}
	table.insert(Config.Huges, id)
	return id
end

-- Coin eggs take these in turn (the first egg hatches the first, the eighth the first again).
local COIN_HUGES = {
	defineHuge("Storm", rgb(70, 150, 255), rgb(255, 240, 120)),
	defineHuge("Gatling", rgb(150, 160, 175), rgb(255, 70, 60)),
	defineHuge("Hex", rgb(140, 60, 200), rgb(120, 255, 140)),
	defineHuge("Slayer", rgb(200, 30, 40), rgb(240, 235, 220)),
	defineHuge("Clover", rgb(40, 200, 90), rgb(255, 215, 80)),
	defineHuge("Golden Goose", rgb(255, 205, 60), rgb(255, 250, 235)),
	defineHuge("Executioner", rgb(35, 30, 40), rgb(255, 50, 60)),
}
local GEM_HUGE = defineHuge("Gemstone", rgb(90, 225, 255), rgb(255, 150, 255))
local HALLOWEEN_HUGE = defineHuge("Pumpkin", rgb(255, 130, 30), rgb(70, 160, 60))
-- The one Huge that is bought (the hugeStarter game pass) instead of hatched, so it cannot be traded.
Config.Pets[defineHuge("Tycoon", rgb(235, 240, 250), rgb(255, 205, 60))].tradable = false
-- The prize of the Halloween leaderboard (Features/Event.luau): no egg hides it and nothing sells it, so the
-- only ones in the game are the top three's. It can be traded.
defineHuge("Spectre", rgb(150, 255, 205), rgb(150, 80, 230))

-- Every egg also hides two Secret mini cannons, far stronger than its own Legendary, and one Huge cannon.
-- Its stand lists each of them as "???" with its real chance: what it is stays a mystery until one is hatched.
--   chance  per cent, before luck: 0.01 is 1 in 10,000
--   bonus   times the bonus of the egg's own strongest mini cannon
--   color   blended with the egg's colour, so every egg's Secrets have a shade of their own
local SECRETS = {
	{ prefix = "Glitched", chance = 0.01, bonus = 25, color = rgb(60, 255, 190) },
	{ prefix = "Forbidden", chance = 0.0001, bonus = 250, color = rgb(150, 20, 40) },
}
Config.HugeChance = 0.000001 -- per cent: 1 in 100,000,000 from any egg, whatever the player's luck

local coinEggs = 0
local topBonus = 0 -- the strongest ordinary mini cannon a coin egg hatches

-- pets: five { short name, color } entries, weakest first. bonuses: five numbers on the clicker's curve
-- (onCurve moves them), or a base scaled by SLOT_BONUS.
-- egg.weights replaces SLOT_WEIGHT for an egg with odds of its own. egg.huge is the Huge it hides; an egg
-- without one takes the next of COIN_HUGES.
local function defineEgg(egg, pets, bonuses)
	local weights = egg.weights or SLOT_WEIGHT
	local strongest = 0
	egg.pets = {}
	for slot, pet in pets do
		local bonus = if typeof(bonuses) == "table" then onCurve(bonuses[slot]) else bonuses * SLOT_BONUS[slot]
		strongest = math.max(strongest, bonus)
		egg.pets[slot] = { id = definePet(pet[1], SLOT_RARITY[slot], bonus, pet[2]), weight = weights[slot] }
	end
	if egg.currency == "coins" and not egg.event then
		topBonus = math.max(topBonus, strongest)
	end

	local hidden = {}
	local short = string.gsub(egg.name, " Egg$", "")
	for _, secret in SECRETS do
		local color = secret.color:Lerp(egg.color, 0.3)
		local id = definePet(`{secret.prefix} {short}`, "Secret", strongest * secret.bonus, color)
		table.insert(hidden, { id = id, weight = secret.chance })
	end
	if not egg.huge then
		egg.huge = COIN_HUGES[coinEggs % #COIN_HUGES + 1]
		coinEggs += 1
	end
	table.insert(hidden, { id = egg.huge, weight = Config.HugeChance })
	for _, entry in hidden do
		-- hidden: egg stands and the index show it as "???" until the player has found one.
		Config.Pets[entry.id].hidden = true
		-- The Common gives up the chance the hidden ones take, so the weights still add up to 100.
		egg.pets[1].weight -= entry.weight
		table.insert(egg.pets, entry)
	end

	table.insert(Config.Eggs, egg)
	Config.EggById[egg.id] = egg
end

-- Two coin eggs per world. The first holds minis matching that world's tower tiers; the second is stronger.
-- unlock = best-ever global level cleared.
local WORLD_EGGS = {
	{ "Basic Egg", nil, "Forest Egg", {
		{ "Leaf", rgb(110, 190, 90) }, { "Vine", rgb(60, 140, 70) }, { "Mushroom", rgb(210, 70, 60) },
		{ "Honey", rgb(245, 190, 60) }, { "Jade", rgb(60, 200, 150) },
	} },
	{ "Moon Egg", nil, "Comet Egg", {
		{ "Dust", rgb(190, 185, 175) }, { "Comet", rgb(150, 210, 255) }, { "Meteor", rgb(130, 100, 90) },
		{ "Star", rgb(255, 235, 130) }, { "Galaxy", rgb(110, 80, 210) },
	} },
	{ "Mars Egg", nil, "Dune Egg", {
		{ "Sand", rgb(220, 190, 140) }, { "Cactus", rgb(70, 160, 80) }, { "Scorpion", rgb(140, 60, 30) },
		{ "Pharaoh", rgb(250, 210, 80) }, { "Sandstorm", rgb(200, 150, 90) },
	} },
	{ "Frost Egg", nil, "Blizzard Egg", {
		{ "Snow", rgb(240, 248, 255) }, { "Icicle", rgb(150, 215, 255) }, { "Penguin", rgb(40, 45, 60) },
		{ "Yeti", rgb(225, 235, 245) }, { "Polar", rgb(120, 190, 250) },
	} },
	{ "Ember Egg", nil, "Solar Egg", {
		{ "Spark", rgb(255, 230, 120) }, { "Flame", rgb(255, 120, 40) }, { "Lava", rgb(210, 60, 20) },
		{ "Phoenix", rgb(255, 170, 50) }, { "Supernova", rgb(255, 250, 220) },
	} },
	{ "Shadow Egg", nil, "Omega Egg", {
		{ "Phantom", rgb(170, 160, 210) }, { "Nightmare", rgb(70, 20, 60) }, { "Paradox", rgb(60, 220, 200) },
		{ "Infinity", rgb(240, 240, 255) }, { "Godly", rgb(255, 215, 90) },
	} },
	{ "Nebula Egg", nil, "Starlight Egg", {
		{ "Twinkle", rgb(255, 245, 200) }, { "Stargazer", rgb(90, 110, 205) }, { "Zodiac", rgb(165, 90, 225) },
		{ "Constellation", rgb(120, 200, 255) }, { "Celestial", rgb(255, 215, 250) },
	} },
	{ "Shard Egg", nil, "Geode Egg", {
		{ "Pebble", rgb(150, 142, 136) }, { "Garnet", rgb(170, 40, 62) }, { "Topaz", rgb(255, 190, 70) },
		{ "Onyx", rgb(32, 32, 40) }, { "Moonstone", rgb(200, 222, 255) },
	} },
	{ "Scrap Egg", nil, "Circuit Egg", {
		{ "Bolt", rgb(190, 196, 206) }, { "Circuit", rgb(60, 200, 110) }, { "Turbo", rgb(255, 120, 40) },
		{ "Laser", rgb(255, 50, 80) }, { "Cyber", rgb(60, 240, 255) },
	} },
	{ "Jungle Egg", nil, "Bloom Egg", {
		{ "Fern", rgb(90, 170, 90) }, { "Bamboo", rgb(175, 200, 90) }, { "Lotus", rgb(250, 160, 200) },
		{ "Viper", rgb(60, 140, 60) }, { "Raptor", rgb(205, 80, 50) },
	} },
	{ "Gravity Egg", nil, "Warp Egg", {
		{ "Warp", rgb(130, 90, 230) }, { "Tachyon", rgb(120, 255, 200) }, { "Wormhole", rgb(70, 40, 125) },
		{ "Quantum", rgb(90, 200, 255) }, { "Dark Matter", rgb(60, 24, 100) },
	} },
	{ "Cosmic Egg", nil, "Genesis Egg", {
		{ "Proton", rgb(255, 90, 90) }, { "Electron", rgb(90, 160, 255) }, { "Eternal", rgb(255, 200, 90) },
		{ "Alpha", rgb(255, 255, 255) }, { "Genesis", rgb(255, 240, 200) },
	} },
}
for worldIndex, def in WORLD_EGGS do
	local world = Config.Worlds[worldIndex]
	local firstWave = (worldIndex - 1) * Config.WavesPerWorld
	local matching = {}
	for i = 1, Config.CannonsPerWorld do
		local cannon = Config.Cannons[(worldIndex - 1) * Config.CannonsPerWorld + i]
		matching[i] = { cannon.short, cannon.color }
	end
	for half, pets in { matching, def[4] } do
		local step = (worldIndex - 1) * 2 + (half - 1)
		local unlock = firstWave + (half - 1) * Config.WavesPerWorld / 2
		defineEgg({
			id = petId(def[if half == 1 then 1 else 3]),
			name = def[if half == 1 then 1 else 3],
			world = worldIndex,
			currency = "coins",
			-- Priced at the first level its owner plays next: a world's first egg unlocks with the last level
			-- of the world before, and every world has a coin anchor of its own.
			cost = if step == 0 then Config.EggCurve.first else nice(Config.EggCurve.clears * levelCoins(unlock + 1)),
			unlock = unlock,
			color = if half == 1 then world.floor else world.backdrop,
		}, pets, Config.EggCurve.base * Config.EggCurve.step ^ step)
	end
end

-- Premium egg: costs diamonds, strong for an early player.
defineEgg({ id = "gem", name = "Gem Egg", currency = "diamonds", cost = 60, unlock = 0, color = rgb(80, 220, 255), huge = GEM_HUGE }, {
	{ "Gem", rgb(120, 230, 255) }, { "Ruby", rgb(230, 40, 70) }, { "Sapphire", rgb(40, 90, 230) },
	{ "Emerald", rgb(40, 200, 110) }, { "Prismatic", rgb(255, 150, 255) },
}, { 200, 400, 900, 2_500, 15_000 })

-- Halloween eggs: only hatchable while the event is live. They all hide the same Huge.
defineEgg({ id = "pumpkin", name = "Pumpkin Egg", currency = "coins", cost = 1_500, unlock = 5, color = rgb(255, 130, 30), event = true, huge = HALLOWEEN_HUGE }, {
	{ "Pumpkin", rgb(255, 130, 30) }, { "Bat", rgb(60, 50, 70) }, { "Ghost", rgb(235, 240, 255) },
	{ "Witch", rgb(110, 60, 160) }, { "Jack-O-Lantern", rgb(255, 170, 40) },
}, { 3, 5, 9, 20, 80 })
defineEgg({ id = "haunted", name = "Haunted Egg", currency = "candy", cost = 150, unlock = 0, color = rgb(110, 60, 160), event = true, huge = HALLOWEEN_HUGE }, {
	{ "Skeleton", rgb(230, 225, 210) }, { "Zombie", rgb(110, 150, 90) }, { "Vampire", rgb(150, 20, 40) },
	{ "Reaper", rgb(30, 30, 40) }, { "Headless Horseman", rgb(255, 110, 20) },
}, { 30, 55, 110, 300, 1_500 })
defineEgg({ id = "crypt", name = "Crypt Egg", currency = "candy", cost = 1_000, unlock = 50, color = rgb(95, 105, 115), event = true, huge = HALLOWEEN_HUGE }, {
	{ "Tombstone", rgb(130, 135, 140) }, { "Spider", rgb(45, 40, 50) }, { "Mummy", rgb(225, 215, 185) },
	{ "Gargoyle", rgb(90, 110, 130) }, { "Lich", rgb(120, 255, 200) },
}, { 2_000, 3_500, 7_000, 15_000, 60_000 })
-- The finale egg: its Rare, Epic and Legendary are more likely than in any other egg.
defineEgg({
	id = "bloodmoon",
	name = "Blood Moon Egg",
	currency = "candy",
	cost = 2_500,
	unlock = 100,
	color = rgb(170, 20, 30),
	event = true,
	huge = HALLOWEEN_HUGE,
	weights = { 45, 30, 17, 6, 2 },
}, {
	{ "Crow", rgb(30, 30, 40) }, { "Scarecrow", rgb(200, 150, 70) }, { "Werewolf", rgb(110, 90, 80) },
	{ "Banshee", rgb(190, 230, 235) }, { "Blood Moon", rgb(220, 30, 40) },
}, { 40_000, 70_000, 150_000, 350_000, 1_500_000 })

-- Exclusive mini cannons: shops and daily rewards only.
definePet("Calendar", "Exclusive", onCurve(60), rgb(255, 255, 255))
definePet("Neon", "Exclusive", onCurve(500), rgb(60, 255, 160))
definePet("Royal Guard", "Exclusive", onCurve(2_000), rgb(200, 30, 40))
definePet("Mecha", "Exclusive", onCurve(8_000), rgb(90, 100, 120))
definePet("Dragon", "Exclusive", onCurve(30_000), rgb(220, 50, 30))
definePet("Candy Corn", "Exclusive", onCurve(40), rgb(255, 200, 60))
definePet("Cauldron", "Exclusive", onCurve(400), rgb(60, 200, 90))
definePet("Pumpkin King", "Exclusive", onCurve(3_000), rgb(255, 110, 20))

-- Halloween crate jackpots (src/shared/Features/Crates.luau): Secret, and a mystery until won, like the eggs' own.
-- Their strength is measured against the whole game instead of being a fixed number, so they stay worth
-- winning as worlds are added: a quarter of the way up the coin eggs, half way up, and past the top.
for _, def in {
	{ "Candy Skull", topBonus ^ 0.25, rgb(255, 235, 245) },
	{ "Bone Dragon", topBonus ^ 0.5, rgb(235, 230, 210) },
	{ "Witching Hour", topBonus * 5, rgb(120, 40, 200) },
} do
	Config.Pets[definePet(def[1], "Secret", nice(def[2]), def[3])].hidden = true
end

-- The permanent crates' own mini cannons (src/shared/Features/Crates.luau). Three Exclusive prizes, and four
-- Secret jackpots measured against the whole game like the Halloween ones above.
definePet("Crate", "Exclusive", onCurve(150), rgb(176, 124, 76))
definePet("Treasure", "Exclusive", onCurve(6_000), rgb(255, 205, 60))
definePet("Vault", "Exclusive", onCurve(250_000), rgb(120, 200, 255))
for _, def in {
	{ "Mimic", topBonus ^ 0.3, rgb(170, 60, 70) },
	{ "Fortune", topBonus ^ 0.5, rgb(90, 255, 170) },
	{ "Jackpot", topBonus ^ 0.75, rgb(255, 215, 60) },
	{ "Motherlode", topBonus * 10, rgb(255, 250, 235) },
} do
	Config.Pets[definePet(def[1], "Secret", nice(def[2]), def[3])].hidden = true
end

----------------------------------------------------------------------------------------------------
-- Fusing: FuseCount identical mini cannons make one of the next tier. Eggs, shops and rewards only give base ones.
-- id is part of the saved pet ids (wooden_silver), so never change the id of a tier players already own.
-- bonus multiplies the base mini cannon's bonus (and so its DPS). color is the trim on its model and in the inventory.
-- Each tier adds a perk and keeps the perks of the tiers below it:
--   fireRate   that mini cannon auto-fires this many times as fast, in shots that are as much smaller: its
--              damage per second stays what it is
--   coinBonus  extra coins from monsters (0.25 = +25%), added up over the equipped mini cannons
--   healCut    how much slower monsters heal (0.2 = 20%), multiplied over the equipped mini cannons
----------------------------------------------------------------------------------------------------
Config.FuseCount = 3
Config.MinHealShare = 0.2 -- healCut never takes healing below this share of the wave's normal rate
Config.FuseTiers = {
	{ id = "silver", name = "Silver", bonus = 3.5, color = rgb(205, 212, 224), perk = "Rapid Fire", fireRate = 2 },
	{ id = "gold", name = "Gold", bonus = 12, color = rgb(255, 205, 60), perk = "Coin Magnet", coinBonus = 0.25 },
	{ id = "diamond", name = "Diamond", bonus = 40, color = rgb(110, 230, 255), perk = "Heal Block", healCut = 0.2 },
}

-- What a tier's own perk does, in a few words: "fires 2x as fast".
function Config.perkText(tier): string
	local parts = {}
	if tier.fireRate then
		table.insert(parts, `fires {tier.fireRate}x as fast`)
	end
	if tier.coinBonus then
		table.insert(parts, `+{math.floor(tier.coinBonus * 100 + 0.5)}% coins`)
	end
	if tier.healCut then
		table.insert(parts, `monsters heal {math.floor(tier.healCut * 100 + 0.5)}% slower`)
	end
	return table.concat(parts, ", ")
end

-- Every mini cannon gets a fused version per tier: wooden -> wooden_silver -> wooden_gold -> wooden_diamond.
-- All of them, fused or not, end up with: tier (0 = not fused), base (the id of the unfused one), next (the id
-- it fuses into, nil at the top tier), perks (the names of its perks) and the three perk numbers above.
-- A Huge has no fused versions and no next. Its tier is -1, a tier nothing fuses or counts as fused.
local baseIds = {}
for id, pet in Config.Pets do
	pet.tier, pet.base, pet.perks = if pet.huge then -1 else 0, id, {}
	pet.plain = id -- the id without enchantments (see "Enchanted mini cannons" below)
	pet.fireRate, pet.coinBonus, pet.healCut = 1, 0, 0
	-- Its own damage per second. A Huge's depends on what is equipped beside it (Config.petDpsList): nil here.
	pet.dps = if pet.huge then nil else pet.bonus * Config.PetDps
	if not pet.huge then
		table.insert(baseIds, id)
	end
end
for _, baseId in baseIds do
	local base = Config.Pets[baseId]
	local below = base
	for index, tier in Config.FuseTiers do
		local id = `{baseId}_{tier.id}`
		local perks = table.clone(below.perks)
		table.insert(perks, tier.perk)
		Config.Pets[id] = {
			short = base.short, -- unchanged, so the set bonus still finds the matching cannon
			name = `{tier.name} {base.name}`,
			rarity = base.rarity,
			bonus = base.bonus * tier.bonus,
			dps = base.bonus * tier.bonus * Config.PetDps,
			color = base.color,
			tier = index,
			base = baseId,
			plain = id,
			perks = perks,
			fireRate = tier.fireRate or below.fireRate,
			coinBonus = tier.coinBonus or below.coinBonus,
			healCut = tier.healCut or below.healCut,
		}
		below.next = id
		below = Config.Pets[id]
	end
end

-- The world whose island has the Fusion Machine (src/shared/Features/Fuse.luau): fusing opens when that
-- world is reached, and the story asks for no fusing before it.
Config.FuseIsland = 5

----------------------------------------------------------------------------------------------------
-- Enchanted mini cannons (docs/BUILD_QUEUE.md, section 4; the enchantments themselves, what they cost and
-- what they do are in src/shared/Features/Enchant.luau).
--
-- The save keeps mini cannons as id strings, so an enchanted one is its id plus a suffix:
--   wooden_gold~greed1.sharp3      a Gold Mini Wooden Cannon with Greed I and Sharp III
-- "~", then up to MaxEnchants enchantments joined by ".", each an enchantment id (lower case letters) and
-- its level (1 to MaxEnchantLevel), in alphabetical order (Config.enchantedId writes them that way, so the
-- same enchantments always make the same id and stack in the inventory).
--
-- Config.Pets resolves such an id when it is asked for: the entry has everything the plain mini cannon's
-- has (it reads through to it, so `tier`, `base`, `next`, `bonus`, `tradable` ... are the plain one's) plus
--   plain      the id without the suffix ("wooden_gold"; every entry has it, a plain one's is its own id)
--   enchants   { { id = "greed", level = 1 }, { id = "sharp", level = 3 } }
--   enchanted  true
--   name       "Enchanted Gold Mini Wooden Cannon"
-- `base` stays what it was: the id of the mini cannon it was fused from ("wooden"), which the index of found
-- mini cannons and the trade rules go by.
-- Enchanted entries are not stored in Config.Pets, so `for id, pet in Config.Pets` still walks the plain
-- ones only. An id whose suffix is not written like the above, or whose mini cannon does not exist, is nil.
-- An enchantment this build no longer knows still resolves (a save must never hold an id that is nil); the
-- Enchant feature just finds nothing to apply for it. One that was taken out of the game on purpose
-- (Config.RetiredEnchants) is dropped from `enchants` as the id resolves: the id stays what the save holds,
-- and nothing lists, counts or applies that enchantment. A mini cannon left with none reads as a plain one.
----------------------------------------------------------------------------------------------------
Config.EnchantIsland = 5 -- the world whose island has the enchanting table
Config.MaxEnchants = 3 -- enchantments on one mini cannon
Config.MaxEnchantLevel = 3 -- levels I to III
Config.ENCHANT_MARK = "~"
-- Enchantments that no longer exist. Quick Draw (+mini cannon shots) went on 5 Oct: mini cannons deal flat
-- damage per second, so firing faster added nothing.
Config.RetiredEnchants = { quickdraw = true }

-- "greed1.sharp3" -> { { id = "greed", level = 1 }, { id = "sharp", level = 3 } }, or nil when it is not
-- written like that. The same enchantment twice is not an id.
function Config.parseEnchants(suffix: string): { { id: string, level: number } }?
	local enchants, seen = {}, {}
	for _, part in string.split(suffix, ".") do
		local id, digit = string.match(part, "^(%l+)(%d)$")
		local level = tonumber(digit)
		if not id or not level or level < 1 or level > Config.MaxEnchantLevel or seen[id] or #enchants >= Config.MaxEnchants then
			return nil
		end
		seen[id] = true
		table.insert(enchants, { id = id, level = level })
	end
	return if #enchants > 0 then enchants else nil
end

-- A mini cannon's id without its enchantments, and the suffix (nil for a plain one): "wooden~sharp1" ->
-- "wooden", "sharp1". Works on any string: it does not say the mini cannon exists.
function Config.splitPetId(id: string): (string, string?)
	local plain, suffix = string.match(id, "^([^~]+)~(.+)$")
	if plain then
		return plain, suffix
	end
	return id, nil
end

-- The id of the mini cannon `plainId` carrying `enchants` ({ { id, level } }), written the one way an
-- enchanted id is written. With no enchantments it is the plain id.
function Config.enchantedId(plainId: string, enchants: { { id: string, level: number } }?): string
	if not enchants or #enchants == 0 then
		return plainId
	end
	local parts = {}
	for _, enchant in enchants do
		table.insert(parts, `{enchant.id}{enchant.level}`)
	end
	table.sort(parts)
	return plainId .. Config.ENCHANT_MARK .. table.concat(parts, ".")
end

-- What the enchantments are called: [enchantment id] = "Sharp". Filled in by the Enchant feature's shared
-- module, so that anything that names a mini cannon can write its enchantments without knowing that feature.
Config.EnchantNames = {}
local ENCHANT_ROMAN = { "I", "II", "III" }

-- A mini cannon's enchantments in words: "Greed I, Sharp III" ("" for a plain one). An enchantment without a
-- name (a build without the feature) is written by its id.
function Config.enchantText(petId: string, separator: string?): string
	local pet = Config.Pets[petId]
	if not pet or not pet.enchants then
		return ""
	end
	local parts = {}
	for _, enchant in pet.enchants do
		table.insert(parts, `{Config.EnchantNames[enchant.id] or enchant.id} {ENCHANT_ROMAN[enchant.level] or enchant.level}`)
	end
	return table.concat(parts, separator or ", ")
end

-- The enchantments of a mini cannon id: {} for a plain one or an id nobody knows.
function Config.petEnchants(id: string): { { id: string, level: number } }
	local pet = Config.Pets[id]
	return if pet and pet.enchants then pet.enchants else {}
end

do
	-- Resolved entries are remembered, up to a limit: ids come from saves and from clients, and a table that
	-- only ever grows would be a way to fill the server's memory.
	local RESOLVED_LIMIT = 4_000
	local resolved, count = {}, 0
	setmetatable(Config.Pets, {
		__index = function(pets, id: any)
			if typeof(id) ~= "string" then
				return nil
			end
			local known = resolved[id]
			if known then
				return known
			end
			local plainId, suffix = string.match(id, "^([^~]+)~(.+)$")
			if not plainId then
				return nil
			end
			local plain = pets[plainId]
			local enchants = plain and Config.parseEnchants(suffix)
			if not plain or not enchants then
				return nil
			end
			local kept, score = {}, 0
			for _, enchant in enchants do
				if not Config.RetiredEnchants[enchant.id] then
					table.insert(kept, enchant)
					score += enchant.level
				end
			end
			local any = #kept > 0
			local entry = setmetatable({
				plain = plainId,
				enchants = if any then kept else nil,
				enchanted = if any then true else nil,
				enchantScore = score, -- its levels added up: of two equal mini cannons the better enchanted one is equipped
				name = if any then `Enchanted {plain.name}` else plain.name,
			}, { __index = plain })
			if count >= RESOLVED_LIMIT then
				resolved, count = {}, 0
			end
			resolved[id] = entry
			count += 1
			return entry
		end,
	})
end

----------------------------------------------------------------------------------------------------
-- Diamonds: daily rewards, daily missions, weekly shop
----------------------------------------------------------------------------------------------------
-- What each currency is called on screen. The save and the code say diamonds; players see gems.
Config.CurrencyNames = { coins = "coins", diamonds = "gems", candy = "candy" }

Config.Boosts = {
	power2x = { name = "2x Power" },
	coins2x = { name = "2x Coins" },
}

-- One entry per streak day. After day 7 the streak loops back to day 1.
Config.Daily = {
	{ diamonds = 10 },
	{ diamonds = 15 },
	{ diamonds = 20, boost = "power2x", minutes = 15 },
	{ diamonds = 25 },
	{ diamonds = 30, boost = "coins2x", minutes = 15 },
	{ diamonds = 40 },
	{ diamonds = 75, pet = "calendar" },
}

-- Daily missions, reset at 00:00 UTC. key is the progress counter the server tracks.
Config.Missions = {
	{ id = "upgrades", key = "upgrades", text = "Upgrade your towers 25 times", goal = 25, reward = 10 },
	{ id = "kills", key = "kills", text = "Defeat 400 monsters", goal = 400, reward = 10 },
	{ id = "bosses", key = "bosses", text = "Defeat 15 bosses", goal = 15, reward = 15 },
	{ id = "waves", key = "waves", text = "Clear 30 levels", goal = 30, reward = 10 },
	{ id = "hatches", key = "hatches", text = "Hatch 5 eggs", goal = 5, reward = 15 },
}

-- Weekly diamond shop: one featured exclusive rotates each week (Thursday 00:00 UTC), the rest stay.
-- limit = purchases allowed per week.
Config.WeeklyFeatured = {
	{ id = "pet_neon", name = "Mini Neon Cannon", desc = "Exclusive mini cannon", cost = 150, kind = "pet", pet = "neon", limit = 1 },
	{ id = "pet_guard", name = "Mini Royal Guard Cannon", desc = "Exclusive mini cannon", cost = 300, kind = "pet", pet = "royalguard", limit = 1 },
	{ id = "pet_mecha", name = "Mini Mecha Cannon", desc = "Exclusive mini cannon", cost = 500, kind = "pet", pet = "mecha", limit = 1 },
	{ id = "pet_dragon", name = "Mini Dragon Cannon", desc = "Exclusive mini cannon", cost = 800, kind = "pet", pet = "dragon", limit = 1 },
}
Config.WeeklyFixed = {
	{ id = "slot", name = "+1 Mini Cannon Slot", desc = "Equip one more mini cannon, forever", cost = 250, kind = "slot", limit = 1 },
	{ id = "boost_power", name = "2x Power (30 min)", desc = "Doubles all tower damage", cost = 30, kind = "boost", boost = "power2x", minutes = 30, limit = 3 },
	{ id = "boost_coins", name = "2x Coins (30 min)", desc = "Doubles coins from monsters", cost = 30, kind = "boost", boost = "coins2x", minutes = 30, limit = 3 },
}

----------------------------------------------------------------------------------------------------
-- Game passes (Robux). id = the pass id from the Creator Hub; 0 means not on sale yet.
-- price is only shown in the store window; the real price is whatever the pass is set to on Roblox.
-- What each pass does is implemented where it applies; ownership is checked with Passes.owns on the server
-- and State.meta.passes on the client.
----------------------------------------------------------------------------------------------------
Config.Passes = {
	tripleHatch = { id = 0, order = 1, name = "x3 Egg Opener", desc = "Hatch 3 eggs at once", price = 349 },
	tripleLuck = { id = 0, order = 2, name = "x3 Luck", desc = "Rare mini cannons hatch 3x more often", price = 449 },
	-- slots = extra mini cannon equip slots while owned; these stack with each other and with the weekly shop's.
	slots3 = { id = 0, order = 3, name = "+3 Mini Cannon Slots", desc = "Equip 3 more mini cannons", price = 299, slots = 3 },
	slots5 = { id = 0, order = 4, name = "+5 Mini Cannon Slots", desc = "Equip 5 more mini cannons", price = 549, slots = 5 },
	-- Order 5 was Auto Rebirth. Rebirth is back as a rare prestige, but nothing does it for the player:
	-- offline earnings is the candidate for the place.
	-- storage = extra mini cannon storage on top of MaxPets while owned.
	storage500 = { id = 0, order = 6, name = "+500 Mini Cannon Storage", desc = "Store 500 more mini cannons", price = 249, storage = 500 },
	-- The game speed button (Game.luau's setSpeed): 2x is free for everyone, 3x is this pass. Without it a plot
	-- runs at 2x at most, whatever the save says.
	gameSpeed = { id = 0, order = 7, name = "3x Speed", desc = "Run your plot at 3x game speed", price = 99 },
}

----------------------------------------------------------------------------------------------------
-- The fan bonus (Features/Tutorial.luau): a thank-you for joining the game's Roblox group, paid once per
-- save. It is for the group only: a game cannot see a like or a favourite, and Roblox does not allow paying
-- for one, so nothing here may ever be tied to rating the game.
----------------------------------------------------------------------------------------------------
Config.Fan = {
	groupId = 230235107, -- the Roblox group's id (the number in its page's address). 0 = no group yet: nothing can be claimed
	groupName = "Astral Crafts", -- how the welcome card names it: put the group's real name here with its id
	gems = 250, -- paid once
	coins = 0.10, -- +10% coins from every monster, for good. STATS lists it as "Fan bonus"
}

----------------------------------------------------------------------------------------------------
-- Offline earnings (Features/Offline.luau): what the towers earn while the player is away, paid on the
-- welcome-back card. These are the starting numbers of the `offlineCap` and `offlineShare` modifiers
-- (Game.modify), so a pass or a Mastery track raises them without touching this table.
----------------------------------------------------------------------------------------------------
Config.Offline = {
	minSeconds = 60, -- a shorter absence pays nothing
	capHours = 8, -- earnings stop after this long away
	share = 0.5, -- the share of what the towers would have earned: playing must stay better than not playing
}

----------------------------------------------------------------------------------------------------
-- Halloween event: candy drops from monsters, Halloween eggs and a candy shop, until the end of October.
----------------------------------------------------------------------------------------------------
Config.Halloween = {
	endsAt = 1793491200, -- 2026-11-01 00:00 UTC
	candyPerKill = 1,
	candyPerBoss = 10,
}
Config.EventShop = {
	{ id = "h_candycorn", name = "Mini Candy Corn Cannon", desc = "Halloween exclusive", cost = 300, kind = "pet", pet = "candycorn", limit = 1 },
	{ id = "h_cauldron", name = "Mini Cauldron Cannon", desc = "Halloween exclusive", cost = 1_500, kind = "pet", pet = "cauldron", limit = 1 },
	{ id = "h_king", name = "Mini Pumpkin King Cannon", desc = "Halloween exclusive", cost = 6_000, kind = "pet", pet = "pumpkinking", limit = 1 },
	{ id = "h_power", name = "2x Power (15 min)", desc = "Doubles all tower damage", cost = 200, kind = "boost", boost = "power2x", minutes = 15, limit = 99 },
	{ id = "h_diamonds", name = "25 Gems", desc = "Trade candy for gems", cost = 500, kind = "diamonds", amount = 25, limit = 10 },
}

function Config.halloweenActive(now: number): boolean
	return now < Config.Halloween.endsAt
end

function Config.dayNumber(now: number): number
	return math.floor(now / 86_400)
end

function Config.weekNumber(now: number): number
	return math.floor(now / 604_800)
end

function Config.weeklyItems(week: number)
	local items = { Config.WeeklyFeatured[week % #Config.WeeklyFeatured + 1] }
	for _, item in Config.WeeklyFixed do
		table.insert(items, item)
	end
	return items
end

----------------------------------------------------------------------------------------------------
-- Formulas
----------------------------------------------------------------------------------------------------
Config.VeteranBonusPerLevel = 0.1
Config.LuckPassMultiplier = 3 -- the x3 Luck pass: Rare and better mini cannons hatch this many times as often

-- Every kill raises the player's Veteran level: +VeteranBonusPerLevel tower damage per level. (It was called
-- Cannon Mastery; "Mastery" is now the gem-bought tracks of the Mars island. The save still counts the kills
-- as masteryKills.) Returns level, kills into the current level, kills needed for the next.
function Config.veteranLevel(kills: number): (number, number, number)
	local level, need = 0, 25
	while kills >= need do
		kills -= need
		level += 1
		need *= 3
	end
	return level, kills, need
end

-- How luck treats a rarity when an egg is hatched. Lucky ones drop `luck` times as often. A Huge (Mythical)
-- never moves: it is 1 in 100,000,000 for everybody. The others (Common, Uncommon) shrink to make room.
local LUCKY_RARITIES = { Rare = true, Epic = true, Legendary = true, Secret = true }
local FIXED_RARITIES = { Mythical = true }

-- An egg's mini cannons in their own order, each with its chance: { { id, chance } }.
-- chance is a percentage and the chances add up to 100. luck (1 when left out, never less) multiplies the
-- chance of every lucky one, and the Common and Uncommon chances shrink in proportion. With so much luck that
-- the lucky ones would pass 100%, the rarest keep their full multiplier and the least rare get what is left.
-- The roll and the odds shown on the egg stands both come from here, so they can never disagree.
function Config.eggOdds(egg, luck: number?): { { id: string, chance: number } }
	local boost = math.max(1, luck or 1)
	local total, plain, fixed = 0, 0, 0
	for _, entry in egg.pets do
		local rarity = Config.Pets[entry.id].rarity
		total += entry.weight
		if FIXED_RARITIES[rarity] then
			fixed += entry.weight
		elseif not LUCKY_RARITIES[rarity] then
			plain += entry.weight
		end
	end
	-- Shares are in weights: a share times 100 / total is a percentage.
	-- The lucky ones take theirs from the rarest (the end of the list) down, out of what the fixed ones leave.
	local room = total - fixed
	local shares = {}
	for index = #egg.pets, 1, -1 do
		local entry = egg.pets[index]
		if LUCKY_RARITIES[Config.Pets[entry.id].rarity] then
			shares[index] = math.min(entry.weight * boost, room)
			room -= shares[index]
		end
	end
	-- The plain ones split what is left in proportion to their weights.
	local plainScale = if plain > 0 then room / plain else 0
	local odds = {}
	for index, entry in egg.pets do
		local share = shares[index]
		if not share then
			share = if FIXED_RARITIES[Config.Pets[entry.id].rarity] then entry.weight else entry.weight * plainScale
		end
		odds[index] = { id = entry.id, chance = share * 100 / total }
	end
	return odds
end

-- roll is a random number in [0, 1). The same roll and luck always pick the same mini cannon.
-- Returns its id and the chance it had, as a percentage.
function Config.rollEgg(egg, roll: number, luck: number?): (string, number)
	local odds = Config.eggOdds(egg, luck)
	local remaining = roll * 100
	local picked = odds[1]
	-- Rarest first, so the tiny chances sit at the low end of the roll, where a number is at its most exact:
	-- a roll under 0.00000001 is the Huge. A mini cannon with no chance is never picked, and if rounding leaves
	-- the chances a hair short of 100, the roll lands on the most common one that can drop, never on a rare one.
	for index = #odds, 1, -1 do
		local entry = odds[index]
		if entry.chance > 0 then
			picked = entry
			remaining -= entry.chance
			if remaining < 0 then
				break
			end
		end
	end
	return picked.id, picked.chance
end

-- A chance (a percentage) as text, however small: 25 -> "25%", 49.9899 -> "49.99%", 0.000001 -> "0.000001%".
-- Four significant digits and no exponent, so something that can drop never reads "0%".
function Config.chanceText(chance: number): string
	if chance <= 0 then
		return "0%"
	end
	local decimals = math.clamp(3 - math.floor(math.log10(chance)), 0, 99)
	local text = string.format(`%.{decimals}f`, chance)
	if decimals > 0 then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return text .. "%"
end

-- The same chance as odds: 0.01 -> "1 in 10,000".
function Config.oneIn(chance: number): string
	local digits = string.format("%d", math.max(1, math.floor(100 / chance + 0.5)))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "%d%d%d", "%0,")))
	return "1 in " .. string.gsub(grouped, "^,", "")
end

-- The mini cannons to equip out of a list of pet ids: the strongest that fit in `slots`.
-- Huge cannons go first, one of each (a second copy of the same Huge adds nothing). One slot is always kept
-- for the strongest ordinary mini cannon: a Huge's own damage per second is that one's.
function Config.equippedPets(petIds: { string }, slots: number): { string }
	local huges, others = {}, {}
	for _, id in petIds do
		local pet = Config.Pets[id]
		if pet then
			table.insert(if pet.huge then huges else others, id)
		end
	end
	-- Of two that are equally strong the better enchanted one goes first (an enchanted mini cannon is as
	-- strong as its plain twin: its enchantments only count while it is equipped), then by id, so the choice
	-- is the same every time.
	local function better(a: string, b: string, key: string): boolean
		local petA, petB = Config.Pets[a], Config.Pets[b]
		if petA[key] ~= petB[key] then
			return petA[key] > petB[key]
		end
		local scoreA, scoreB = petA.enchantScore or 0, petB.enchantScore or 0
		return if scoreA == scoreB then a < b else scoreA > scoreB
	end
	table.sort(huges, function(a, b)
		return better(a, b, "power")
	end)
	table.sort(others, function(a, b)
		return better(a, b, "bonus")
	end)
	-- One of each Huge, whatever its enchantments: the rest are spares.
	local firsts, spares, seen = {}, {}, {}
	for _, id in huges do
		local plain = Config.Pets[id].plain
		table.insert(if seen[plain] then spares else firsts, id)
		seen[plain] = true
	end
	local hugeSlots = if #others > 0 then slots - 1 else slots
	local equipped = {}
	for index, id in firsts do
		table.insert(if index <= hugeSlots then equipped else spares, id)
	end
	-- Then the ordinary ones, and a Huge that was left out only where a slot would otherwise stay empty.
	for _, list in { others, spares } do
		for _, id in list do
			if #equipped >= slots then
				return equipped
			end
			table.insert(equipped, id)
		end
	end
	return equipped
end

-- What the equipped Huges multiply all tower damage by: each different Huge its `power` (x3), a second copy
-- of the same one nothing, enchanted or not. 1 without a Huge. Ordinary mini cannons are not in it: they deal
-- damage of their own (Config.petDpsList).
function Config.hugeMult(equipped: { string }): number
	local power = 1
	local counted = {} -- [a Huge's plain id] = true
	for _, id in equipped do
		local pet = Config.Pets[id]
		if pet and pet.huge and not counted[pet.plain] then
			counted[pet.plain] = true
			power *= pet.power
		end
	end
	return power
end

-- One ordinary mini cannon's own damage per second: its bonus times Config.PetDps, with SetBonus when a tower
-- of the player's wears the tier of the same name (towerNames is Config.towerNames). 0 for a Huge.
function Config.petDps(id: string, towerNames: { [string]: boolean }?): number
	local pet = Config.Pets[id]
	if not pet or pet.huge then
		return 0
	end
	return if towerNames and towerNames[pet.short] then pet.dps * Config.SetBonus else pet.dps
end

-- The damage per second of each equipped mini cannon, in the order of `equipped`, and all of it added up,
-- before what features add (the `petDps` modifiers: Bond). The server deals it and STATS lists it from here.
--   an ordinary one   Config.petDps
--   a Huge            as much as the strongest ordinary one in the list, at least Config.HugeDps, times the
--                     shots a second its feature gives it (the Huge Gatling fires five: five times that).
--                     A second copy of the same Huge deals nothing, as it multiplies nothing
function Config.petDpsList(equipped: { string }, towerNames: { [string]: boolean }?): ({ number }, number)
	local list, best = {}, 0
	for index, id in equipped do
		local own = Config.petDps(id, towerNames)
		list[index] = own
		best = math.max(best, own)
	end
	local counted = {}
	local total = 0
	for index, id in equipped do
		local pet = Config.Pets[id]
		if pet and pet.huge then
			if counted[pet.plain] then
				list[index] = 0
			else
				counted[pet.plain] = true
				list[index] = math.max(best, Config.HugeDps) * pet.fireRate
			end
		end
		total += list[index]
	end
	return list, total
end

----------------------------------------------------------------------------------------------------
-- Rebirth: a rare prestige. It is allowed once the final boss of world (rebirths + 1) is beaten in this run:
-- the first after Earth, the second after the Moon ... so a whole playthrough holds a handful. It resets the
-- levels, the coins, the pads and the towers; it keeps mini cannons, gems, items, everything the features
-- saved (mastery, enchants, the story) and the Veteran level. There is no auto-rebirth.
----------------------------------------------------------------------------------------------------
Config.Rebirth = {
	damage = 0.05, -- tower damage every rebirth adds, for good: +5%
	gems = 100, -- paid by each rebirth
}

-- The level that has to be cleared, in this run, before the next rebirth. One past the end when every
-- world's rebirth has been taken: there are no more.
function Config.rebirthWave(rebirths: number): number
	if rebirths >= #Config.Worlds then
		return Config.TotalWaves + 1
	end
	return (rebirths + 1) * Config.WavesPerWorld
end

-- What the player's rebirths multiply all tower damage by.
function Config.rebirthMult(rebirths: number): number
	return 1 + math.max(0, rebirths) * Config.Rebirth.damage
end

-- The multiplier on all tower damage, before boosts and features: the Huges, the Veteran level, rebirths.
-- (Ordinary mini cannons are not in it since 5 Oct: Config.petDpsList.)
function Config.powerMult(equipped: { string }, veteranLevel: number, rebirths: number?): number
	return Config.hugeMult(equipped)
		* (1 + veteranLevel * Config.VeteranBonusPerLevel)
		* Config.rebirthMult(rebirths or 0)
end

----------------------------------------------------------------------------------------------------
-- Left over from the clicker. The core no longer uses any of this; it is here so the clicker's HUD and the
-- features written for it (Story, Crates, Huge) still load until they are adapted. Delete each with its last use.
----------------------------------------------------------------------------------------------------
Config.MonstersPerWave = 5 -- the clicker's lane had five monsters; Config.LevelMonsters is the real count
Config.MaxClicksPerSecond = 20

function Config.monsterHP(wave: number): number
	return Config.levelPlan(wave).hp
end

function Config.monsterCoins(wave: number): number
	return Config.levelPlan(wave).coins
end

function Config.regenRate(wave: number): number
	return Config.levelPlan(wave).regen
end

-- Levels are not timed.
function Config.waveTime(_wave: number): number
	return 0
end

-- There is no cannon shop: nothing is ever in reach.
function Config.affordableCannon(tier: number, coins: number): (number, number)
	return tier, coins
end

return Config
