-- Mastery: permanent tracks bought level by level with gems at the shrine on the Mars island
-- (docs/BUILD_QUEUE.md, section 3). Every number of it is in this file. The server half
-- (src/server/Features/Mastery.luau) sells and applies from these functions and the MASTERY window
-- (src/client/Features/Mastery.luau) lists from them, so the window can never show a price or an effect the
-- server would not give.
--
-- Not to be confused with Veteran, the kill-based bonus of the core that used to be called Cannon Mastery.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Mastery = {}

Mastery.WINDOW = "MASTERY"
Mastery.ISLAND = 3 -- the world whose island has the shrine; mastery opens when that world is reached
-- data.features.mastery: [track id] = level, the gems spent, and what Gem Hunter has dropped today
-- (gemDay is the UTC day number that `gems` counts for).
Mastery.SAVED = { levels = {}, spent = 0, gemDay = 0, gems = 0 }

-- The window's tabs, in order.
Mastery.Groups = {
	{ id = "tower", name = "TOWER", color = Color3.fromRGB(255, 138, 31) },
	{ id = "mini", name = "MINI CANNON", color = Color3.fromRGB(47, 168, 255) },
	{ id = "economy", name = "ECONOMY", color = Color3.fromRGB(255, 198, 26) },
	{ id = "survival", name = "SURVIVAL", color = Color3.fromRGB(95, 224, 58) },
}

-- The tracks, in the window's order.
--   id       the key of the saved level. NEVER change or reuse one players own, and only ever raise a cap:
--            that is all it takes for old saves to keep every level they bought
--   kind     the modifier it changes (Game.modify), so the STATS window lists it as a source
--   how      what a level does to that number:
--              "more"    x (1 + per x level)             "less"  x (1 - per x level): per x cap stays under 1
--              "add"     + per x level, read as a count (lives, hours, gems)
--              "points"  + per x level, read as a percentage (a chance or a share that starts near 0:
--                        0.02 a level is +2% crit chance)
--              "slots"   + 1 equip slot at each level of `at`
--   cap      the last level
--   base, growth   the gem price of level n is base x growth ^ (n - 1), rounded to 5
--   text     how the effect reads; %s is the amount
--   perDay   (Gem Hunter) the gems a level may drop per UTC day: a faucet must cap itself (docs/GEMS.md)
--   needs    the id of a track that must have a level first: without it this one would do nothing (Crit Power
--            multiplies crits, and there are none before Mini Crit). Only the first purchase asks; a level
--            already in a save keeps counting
--
-- The rework of 7 Oct (docs/BALANCE.md 5c has the table): a maxed track is worth several times what it was
-- (Attack x7, not x2), caps are 16 to 50 levels instead of 4 to 20, and the price curve is much flatter
-- (growth 1.08 to 1.2, not 1.4) so the last level of a track costs 1,000 to 3,000 gems instead of the
-- hundreds of thousands the old curve would ask at level 30. A free player earns about 100 gems a day: the
-- first levels (40 to 150 gems) are a day's play each, the last ones weeks.
--
-- What stayed, and why:
--   Lives is still +5. A whole ordinary level leaking costs 20 lives, so past 20 lives no ordinary level can
--   be lost: this is the one track that must not grow.
--   Fire Rate stops at x2: the core stops `towerRate` at x10 for every source together.
--   Slots keeps its first slots at levels 3, 6 and 9, so a saved level still gives what it gave.
--
-- "rapid" was Rapid: +5% mini cannon shots a level, which did nothing once mini cannon damage became flat
-- (more shots of less damage). It is Mini Crit now, under the same id, so every level a player bought counts.
Mastery.Tracks = {
	{ id = "attack", group = "tower", name = "Attack", kind = "power", how = "more", per = 0.12, cap = 50, base = 60, growth = 1.08, text = "+%s%% tower damage" },
	{ id = "rate", group = "tower", name = "Fire Rate", kind = "towerRate", how = "more", per = 0.04, cap = 25, base = 60, growth = 1.15, text = "+%s%% tower fire rate" },
	{ id = "range", group = "tower", name = "Range", kind = "towerRange", how = "more", per = 0.02, cap = 25, base = 40, growth = 1.15, text = "+%s%% tower range" },
	{ id = "boss", group = "tower", name = "Boss Damage", kind = "bossDamage", how = "more", per = 0.1, cap = 30, base = 50, growth = 1.13, text = "+%s%% damage to bosses" },
	{ id = "crit", group = "tower", name = "Tower Crit", kind = "towerCrit", how = "points", per = 0.01, cap = 30, base = 60, growth = 1.13, text = "%s%% of tower shots crit (x2 damage)" },

	{ id = "bond", group = "mini", name = "Bond", kind = "petDps", how = "more", per = 0.1, cap = 40, base = 60, growth = 1.1, text = "+%s%% mini cannon DPS" },
	{ id = "rapid", group = "mini", name = "Mini Crit", kind = "petCrit", how = "points", per = 0.02, cap = 25, base = 40, growth = 1.15, text = "%s%% of mini cannon shots crit" },
	{ id = "critpower", group = "mini", name = "Crit Power", kind = "petCritDamage", how = "more", needs = "rapid", per = 0.05, cap = 20, base = 60, growth = 1.17, text = "+%s%% mini cannon crit damage" },
	{ id = "slots", group = "mini", name = "Slots", kind = "equipSlots", how = "slots", at = { 3, 6, 9, 14, 20 }, cap = 20, base = 150, growth = 1.17, text = "+%s equip slots" },

	{ id = "coins", group = "economy", name = "Coins", kind = "coins", how = "more", per = 0.1, cap = 30, base = 60, growth = 1.13, text = "+%s%% coins per kill" },
	{ id = "luck", group = "economy", name = "Luck", kind = "luck", how = "more", per = 0.05, cap = 30, base = 50, growth = 1.13, text = "+%s%% egg luck" },
	{ id = "discount", group = "economy", name = "Discount", kind = "upgradeCost", how = "less", per = 0.015, cap = 30, base = 40, growth = 1.13, text = "tower upgrades %s%% cheaper" },
	{ id = "crates", group = "economy", name = "Crate Finder", kind = "crateDrops", how = "more", per = 0.04, cap = 25, base = 50, growth = 1.15, text = "+%s%% crate drops from bosses" },
	{ id = "gems", group = "economy", name = "Gem Hunter", kind = "gems", how = "add", per = 0.1, perDay = 3, cap = 20, base = 80, growth = 1.15, text = "bosses drop +%s gems" },

	{ id = "lives", group = "survival", name = "Lives", kind = "lives", how = "add", per = 1, cap = 5, base = 150, growth = 1.6, text = "+%s lives per level" },
	{ id = "slow", group = "survival", name = "Slow", kind = "monsterSpeed", how = "less", per = 0.01, cap = 30, base = 50, growth = 1.13, text = "monsters walk %s%% slower" },
	{ id = "offline", group = "survival", name = "Offline", kind = "offlineCap", how = "add", per = 1, cap = 16, base = 150, growth = 1.2, text = "+%s hours of offline earnings" },
	{ id = "nightshift", group = "survival", name = "Night Shift", kind = "offlineShare", how = "points", per = 0.01, cap = 25, base = 60, growth = 1.15, text = "offline pays +%s%% of your earnings" },
}

Mastery.byId = {}
for _, track in Mastery.Tracks do
	Mastery.byId[track.id] = track
end

local ROMAN = {
	{ 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" },
}

-- 4 -> "IV". There is no roman numeral here past XXXIX: from 40 on the level is written as a plain number.
function Mastery.roman(n: number): string
	if typeof(n) ~= "number" or n ~= n or n < 1 or n >= 40 then
		return tostring(n)
	end
	n = math.floor(n)
	local text = ""
	for _, pair in ROMAN do
		while n >= pair[1] do
			text ..= pair[2]
			n -= pair[1]
		end
	end
	return text
end

-- Whether the player has reached the shrine's world. It reads the highest level ever, so it stays open
-- after a rebirth.
function Mastery.unlocked(bestCleared: number): boolean
	return Config.worldUnlocked(Mastery.ISLAND, bestCleared)
end

-- The level of a track in a saved table (data.features.mastery, or what the client is told): a whole number
-- from 0 to the track's cap, whatever the table holds.
function Mastery.level(saved, id: string): number
	local track = Mastery.byId[id]
	local levels = typeof(saved) == "table" and saved.levels
	local level = typeof(levels) == "table" and levels[id]
	if not track or typeof(level) ~= "number" or level ~= level then
		return 0
	end
	return math.clamp(math.floor(level), 0, track.cap)
end

-- The track that must be bought first, when this one would do nothing without it and it has no level yet.
-- Nil when the track can be bought as far as that goes.
function Mastery.missing(saved, id: string)
	local track = Mastery.byId[id]
	local needs = track and track.needs and Mastery.byId[track.needs]
	return if needs and Mastery.level(saved, needs.id) <= 0 then needs else nil
end

-- The gem price of buying level `level` of a track (1 = the first). Nil past the cap or for an unknown track.
function Mastery.cost(id: string, level: number): number?
	local track = Mastery.byId[id]
	if not track or level < 1 or level > track.cap or level % 1 ~= 0 then
		return nil
	end
	return math.floor(track.base * track.growth ^ (level - 1) / 5 + 0.5) * 5
end

-- What a whole track costs, first level to last.
function Mastery.total(id: string): number
	local track = Mastery.byId[id]
	local sum = 0
	for level = 1, if track then track.cap else 0 do
		sum += Mastery.cost(id, level) :: number
	end
	return sum
end

-- The equip slots a level of the Slots track has earned.
function Mastery.slots(level: number): number
	local count = 0
	for _, at in Mastery.byId.slots.at do
		if level >= at then
			count += 1
		end
	end
	return count
end

-- The level at which the Slots track gives its next slot, or nil when there is none left.
function Mastery.nextSlot(level: number): number?
	for _, at in Mastery.byId.slots.at do
		if at > level then
			return at
		end
	end
	return nil
end

-- The amount a level is worth, as the window writes it: a percentage, or a count for lives, hours, gems and
-- slots.
function Mastery.amount(id: string, level: number): number
	local track = Mastery.byId[id]
	if not track then
		return 0
	elseif track.how == "slots" then
		return Mastery.slots(level)
	elseif track.how == "add" then
		return math.floor(track.per * level * 100 + 0.5) / 100
	end
	return math.floor(track.per * level * 1000 + 0.5) / 10 -- a percentage with one decimal
end

-- The gems Gem Hunter may drop in one UTC day at that level. 0 for a track without a daily limit.
function Mastery.perDay(id: string, level: number): number
	local track = Mastery.byId[id]
	return if track and track.perDay then track.perDay * math.max(0, level) else 0
end

-- "+30% tower damage". Level 0 reads "No bonus yet".
function Mastery.describe(id: string, level: number): string
	local track = Mastery.byId[id]
	if not track or level <= 0 then
		return "No bonus yet"
	end
	local amount = Mastery.amount(id, level)
	if track.how == "slots" and amount == 0 then
		return "No slot yet"
	end
	local number = if amount % 1 == 0 then string.format("%d", amount) else string.format("%.1f", amount)
	local text = string.format(track.text, number)
	if amount == 1 then
		text = string.gsub(text, "slots", "slot") -- "+1 equip slot"
		text = string.gsub(text, "lives", "life")
		text = string.gsub(text, "hours", "hour")
		text = string.gsub(text, "gems", "gem")
	end
	if track.perDay then
		text ..= ` (up to {Mastery.perDay(id, level)} a day)`
	end
	return text
end

-- What the STATS window calls a track's modifier: "Mastery: Attack IV".
function Mastery.label(id: string, level: number): string
	local track = Mastery.byId[id]
	return `Mastery: {if track then track.name else id} {Mastery.roman(level)}`
end

-- A number of the track's kind after `level` levels of it. `state` is the player's session state (no track
-- reads it today).
function Mastery.apply(id: string, level: number, value: number, state): number
	local track = Mastery.byId[id]
	if not track or level <= 0 then
		return value
	end
	local how = track.how
	if how == "more" then
		return value * (1 + track.per * level)
	elseif how == "less" then
		return value * math.max(0, 1 - track.per * level) -- never below nothing, whatever a table says
	elseif how == "add" or how == "points" then
		return value + track.per * level
	elseif how == "slots" then
		return value + Mastery.slots(level)
	end
	return value
end

return Mastery
