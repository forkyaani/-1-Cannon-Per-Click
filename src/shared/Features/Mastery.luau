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
Mastery.SAVED = { levels = {}, spent = 0 } -- data.features.mastery: [track id] = level, and the gems spent

-- The window's tabs, in order.
Mastery.Groups = {
	{ id = "tower", name = "TOWER", color = Color3.fromRGB(255, 138, 31) },
	{ id = "mini", name = "MINI CANNON", color = Color3.fromRGB(47, 168, 255) },
	{ id = "economy", name = "ECONOMY", color = Color3.fromRGB(255, 198, 26) },
	{ id = "survival", name = "SURVIVAL", color = Color3.fromRGB(95, 224, 58) },
}

-- The tracks, in the window's order.
--   kind     the modifier it changes (Game.modify), so the STATS window lists it as a source
--   how      what a level does to that number:
--              "more"  x (1 + per x level)             "less"  x (1 - per x level)
--              "add"   + per x level
--              "slots" + 1 equip slot at each level of `at`
--   cap      the last level
--   base, growth   the gem price of level n is base x growth ^ (n - 1), rounded to 5
--   text     how the effect reads; %s is the amount
-- Everything maxed: x2 tower damage from Attack, x1.3 mini cannon damage from Bond, x1.3 fire rate, +20% range, x1.5 coins,
-- upgrades 20% cheaper. A track costs 2,400 to 7,500 gems; a free player earns about 100 a day and has
-- about a third of one group by the last world (docs/BALANCE.md): the sizes are half the first draft's,
-- so that a player who skips the shrine is not left several times behind one who does not.
-- Offline raises the hours of offline earnings (Features/Offline.luau; the `offlineCap` modifier, in hours):
-- 8 hours becomes 12 with the track maxed. The share that is paid stays what it is.
Mastery.Tracks = {
	{ id = "attack", group = "tower", name = "Attack", kind = "power", how = "more", per = 0.05, cap = 20, base = 40, growth = 1.2, text = "+%s%% tower damage" },
	{ id = "rate", group = "tower", name = "Fire Rate", kind = "towerRate", how = "more", per = 0.03, cap = 10, base = 60, growth = 1.4, text = "+%s%% tower fire rate" },
	{ id = "range", group = "tower", name = "Range", kind = "towerRange", how = "more", per = 0.02, cap = 10, base = 40, growth = 1.4, text = "+%s%% tower range" },
	{ id = "boss", group = "tower", name = "Boss Damage", kind = "bossDamage", how = "more", per = 0.05, cap = 10, base = 50, growth = 1.4, text = "+%s%% damage to bosses" },

	-- Bond grew the mini cannons' bonus while that multiplied tower damage; it grows their damage per second now.
	{ id = "bond", group = "mini", name = "Bond", kind = "petDps", how = "more", per = 0.03, cap = 10, base = 60, growth = 1.4, text = "+%s%% mini cannon DPS" },
	{ id = "rapid", group = "mini", name = "Rapid", kind = "petShots", how = "more", per = 0.05, cap = 10, base = 40, growth = 1.4, text = "+%s%% mini cannon shots" },
	{ id = "slots", group = "mini", name = "Slots", kind = "equipSlots", how = "slots", at = { 3, 6, 9 }, cap = 9, base = 150, growth = 1.35, text = "+%s equip slots" },

	{ id = "coins", group = "economy", name = "Coins", kind = "coins", how = "more", per = 0.05, cap = 10, base = 60, growth = 1.4, text = "+%s%% coins per kill" },
	{ id = "luck", group = "economy", name = "Luck", kind = "luck", how = "more", per = 0.05, cap = 10, base = 50, growth = 1.4, text = "+%s%% egg luck" },
	{ id = "discount", group = "economy", name = "Discount", kind = "upgradeCost", how = "less", per = 0.02, cap = 10, base = 40, growth = 1.4, text = "tower upgrades %s%% cheaper" },

	{ id = "lives", group = "survival", name = "Lives", kind = "lives", how = "add", per = 1, cap = 5, base = 150, growth = 1.6, text = "+%s lives per level" },
	{ id = "slow", group = "survival", name = "Slow", kind = "monsterSpeed", how = "less", per = 0.01, cap = 10, base = 50, growth = 1.4, text = "monsters walk %s%% slower" },
	{ id = "offline", group = "survival", name = "Offline", kind = "offlineCap", how = "add", per = 1, cap = 4, base = 300, growth = 1.6, text = "+%s hours of offline earnings" },
}

Mastery.byId = {}
for _, track in Mastery.Tracks do
	Mastery.byId[track.id] = track
end

local ROMAN = {
	{ 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" },
}

-- 4 -> "IV". Levels stay under 40.
function Mastery.roman(n: number): string
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

-- The amount a level is worth, as the window writes it: a percentage, or a count for lives and slots.
function Mastery.amount(id: string, level: number): number
	local track = Mastery.byId[id]
	if not track then
		return 0
	elseif track.how == "slots" then
		return Mastery.slots(level)
	elseif track.how == "add" then
		return track.per * level
	end
	return math.floor(track.per * level * 1000 + 0.5) / 10 -- a percentage with one decimal
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
		return value * (1 - track.per * level)
	elseif how == "add" then
		return value + track.per * level
	elseif how == "slots" then
		return value + Mastery.slots(level)
	end
	return value
end

return Mastery
