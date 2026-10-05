-- STATS, server half (docs/BUILD_QUEUE.md, section 6): every number of the player and exactly where it comes
-- from, published as Meta_stats for the STATS window (src/client/Features/Stats.luau).
--
-- Nothing is worked out here that the game does not apply: every line is a source of Game.breakdown, every
-- total is Game.value, and the towers are the core's own (state.towerList). The window only draws.
--
-- It is published only while the window is open (the client says so with the `statsWatch` action and keeps
-- saying so every few seconds), and at most once a second.
--
-- This file also keeps the lifetime totals the save did not hold: bosses defeated, levels cleared and the
-- time played (`data.features.stats`).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PUBLISH_SECONDS = 1 -- the shortest time between two Meta_stats
local WATCH_SECONDS = 12 -- a watch the client has not renewed for this long has ended (the client renews every 4)
local LIMIT_LABEL = "Game limit" -- the line for what the core's own limits took off (or put on) a number
local BIG = 1e300 -- numbers past this are sent as this: JSON has no infinity

-- The sections of the window, in its order.
--   kinds     the derived numbers it lists (Game.breakdown), in the order they multiply. Two kinds make one
--             section when the game multiplies them together: the total is their product
--   unit      how the total reads: "x" a multiplier, "count" a whole number, "rate" per second,
--             "share" a percentage per second
--   add       [kind] = true for a kind whose sources add (lives, slots): the line says "+2", not "x1.2"
--   lowGood   a lower number is the better one (monster speed, prices)
--   extra     listed only while something changes it
local SECTIONS = {
	{ id = "damage", name = "TOWER DAMAGE", unit = "x", kinds = { "power", "damage" } },
	{ id = "rate", name = "FIRE RATE", unit = "x", kinds = { "towerRate" } },
	{ id = "range", name = "RANGE", unit = "x", kinds = { "towerRange" } },
	{ id = "boss", name = "BOSS DAMAGE", unit = "x", kinds = { "bossDamage" } },
	{ id = "coins", name = "COINS", unit = "x", kinds = { "coins" } },
	{ id = "luck", name = "LUCK", unit = "x", kinds = { "luck" } },
	{ id = "lives", name = "LIVES", unit = "count", kinds = { "lives" }, add = { lives = true } },
	{ id = "speed", name = "MONSTER SPEED", unit = "x", kinds = { "monsterSpeed" }, lowGood = true },
	-- The mini cannons' own damage per second: a line per mini cannon, then what features add to it.
	{ id = "petDps", name = "MINI CANNON DPS", unit = "rate", kinds = { "petDps" }, add = { petDps = true } },
	{ id = "shots", name = "MINI CANNON SHOTS", unit = "rate", kinds = { "autoShots", "petShots" }, add = { autoShots = true } },
	{ id = "petRange", name = "MINI CANNON RANGE", unit = "x", kinds = { "petRange" }, extra = true },
	{ id = "slots", name = "EQUIP SLOTS", unit = "count", kinds = { "equipSlots" }, add = { equipSlots = true } },
	{ id = "price", name = "UPGRADE PRICE", unit = "x", kinds = { "upgradeCost" }, lowGood = true, extra = true },
	{ id = "gems", name = "GEMS PER BOSS", unit = "count", kinds = { "gems" }, add = { gems = true }, extra = true },
	{ id = "crates", name = "CRATE DROPS", unit = "x", kinds = { "crateDrops" }, extra = true },
	{ id = "heal", name = "MONSTER HEALING", unit = "share", kinds = { "heal" }, lowGood = true, extra = true },
	-- Offline earnings (Features/Offline.luau): the hours away that are paid, and the share that is paid.
	{ id = "offlineCap", name = "OFFLINE HOURS", unit = "count", kinds = { "offlineCap" }, add = { offlineCap = true } },
	{ id = "offlineShare", name = "OFFLINE EARNINGS", unit = "x", kinds = { "offlineShare" } },
}

local Feature = {}
Feature.SECTIONS = SECTIONS

-- A number JSON can carry, or nil.
local function finite(value: any): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(value, -BIG, BIG)
end

-- "2x Power (12:40 left)" -> "2x Power", "12:40": a timed source's countdown is shown on its own.
-- A label that names several timed sources is left as it is.
local function countdown(label: string): (string, string?)
	local name, left = string.match(label, "^(.-) %(([^()]*) left%)$")
	if name and name ~= "" and not string.find(name, " left)", 1, true) then
		return name, left
	end
	return label, nil
end

-- The sources of one kind as the window lists them, and the number the game applies.
--   { label, left = countdown or nil, mult, add, value, how = "mult" | "add" }
local function sourcesOf(Game, player: Player, kind: string, adds: boolean, into: { any }): (number, number)
	local breakdown = Game.breakdown(player, kind)
	if not breakdown then
		return 0, 0
	end
	local base = finite(breakdown.base) or 0
	local last = base
	local function line(label: string, left: string?, entry)
		local mult, add = finite(entry.mult), finite(entry.add)
		table.insert(into, {
			label = label,
			left = left,
			mult = mult,
			add = add,
			value = finite(entry.value),
			-- A source that started from nothing has no multiplier to show.
			how = if adds or not mult then "add" else "mult",
		})
	end
	for _, entry in breakdown.sources do
		local label, left = countdown(tostring(entry.label))
		line(label, left, entry)
		last = finite(entry.value) or last
	end
	local total = finite(breakdown.total) or 0
	-- What the core's limits changed (a fire rate past its cap, lives rounded to a whole one).
	if math.abs(total - last) > 1e-9 * math.max(1, math.abs(last)) then
		line(LIMIT_LABEL, nil, { mult = if last ~= 0 then total / last else nil, add = total - last, value = total })
	end
	return total, base
end

-- Everything the window shows, from the game's own numbers.
local function snapshot(Game, player: Player, data, state)
	local sections = {}
	local byKind = {} -- [kind] = its sources, for the headline's chain
	for _, def in SECTIONS do
		local sources = {}
		local total, base = 1, 1
		for index, kind in def.kinds do
			local own = {}
			local value, start = sourcesOf(Game, player, kind, def.add ~= nil and def.add[kind] == true, own)
			byKind[kind] = own
			table.move(own, 1, #own, #sources + 1, sources)
			total = if index == 1 then value else total * value
			base = if index == 1 then start else base * start
		end
		if not def.extra or #sources > 0 or (def.id == "heal" and base > 0) then
			table.insert(sections, {
				id = def.id,
				name = def.name,
				unit = def.unit,
				lowGood = def.lowGood,
				base = finite(base),
				total = finite(total),
				sources = sources,
			})
		end
	end

	-- Cannon Power, as the core counts it: every tower's damage x rate, x the power multiplier x the fire rate,
	-- plus the mini cannons' own damage per second, which no multiplier of the towers touches.
	-- (The per-shot `damage` modifiers are not in it: the game does not count them in either.)
	local power = Game.value(player, "power")
	local rate = Game.value(player, "towerRate")
	local reach = Game.value(player, "towerRange")
	local baseDps = 0
	for _, tower in state.towerList do
		baseDps += tower.base * tower.def.rate
	end
	local towerPower = baseDps * power * rate
	local petPower = Game.value(player, "petDps")
	local cannonPower = towerPower + petPower
	-- The chain, written out: the towers' own damage per second, then every source of the power multiplier,
	-- then every source of the fire rate. `value` is the towers' damage per second after that source; the last
	-- one is `towers`. The mini cannons are not in the chain: they are lines of their own, added after it.
	local chain = {}
	for _, source in byKind.power do
		table.insert(chain, { label = source.label, left = source.left, mult = source.mult, value = finite(baseDps * (source.value or 0)) })
	end
	for _, source in byKind.towerRate do
		table.insert(chain, { label = source.label, left = source.left, mult = source.mult, value = finite(baseDps * power * (source.value or 0)) })
	end

	local towers = {}
	for _, tower in state.towerList do
		local damage = tower.base * power
		local shots = tower.def.rate * rate
		local dps = damage * shots
		table.insert(towers, {
			pad = tower.pad,
			kind = tower.kind,
			level = tower.level,
			damage = finite(damage),
			rate = finite(shots),
			range = finite(tower.def.range * reach),
			dps = finite(dps),
			share = if cannonPower > 0 then finite(dps / cannonPower) else 0,
		})
	end

	-- The mini cannons, one line each: what it deals a second on its own (the core's own list), then what the
	-- features made of all of them together (the `petDps` modifiers: Bond, Long Shot). The core lists a source
	-- per mini cannon that deals damage before any modifier, so the modifiers' lines are the ones after those.
	local petLines, petBonuses = {}, {}
	for index, id in state.equipped do
		local own = state.petOwn[index] or 0
		if own > 0 then
			local pet = Config.Pets[id]
			table.insert(petLines, { label = if pet then pet.name else id, dps = finite(own), huge = pet ~= nil and pet.huge == true })
		end
	end
	for index, source in byKind.petDps do
		if index > #petLines and source.label ~= LIMIT_LABEL then
			table.insert(petBonuses, { label = source.label, left = source.left, mult = source.mult, add = source.add, value = source.value })
		end
	end

	local saved = Game.feature(data, "stats", Feature.SAVED)
	return {
		at = os.time(),
		power = finite(cannonPower),
		base = finite(baseDps),
		towerPower = finite(towerPower), -- the towers' half of Cannon Power: the end of the chain
		chain = chain,
		sections = sections,
		towers = towers,
		-- The mini cannons: their damage per second (the other half of Cannon Power), each one's own line, what
		-- features add, how many shots a second it comes in, and one average shot.
		pets = {
			dps = finite(petPower),
			lines = petLines,
			bonuses = petBonuses,
			damage = finite(Game.shotDamage(player)),
			shots = finite(Game.value(player, "autoShots") * Game.value(player, "petShots")),
			equipped = #state.equipped,
		},
		speed = Game.speed(player), -- what the plot runs at: 1 without the speed pass
		totals = {
			kills = data.totalKills,
			bosses = saved.bosses,
			hatches = data.totalHatches,
			levels = saved.levels,
			seconds = math.floor(saved.seconds),
			best = data.bestCleared,
			rebirths = data.rebirths,
		},
	}
end
Feature.snapshot = snapshot

-- data.features.stats: the lifetime totals the core does not count.
Feature.SAVED = { bosses = 0, levels = 0, seconds = 0, seeded = false }

local function count(value: any): number
	return if typeof(value) == "number" and value == value and value >= 0 then value else 0
end

function Feature.start(Game)
	local watching = {} -- [player] = os.clock() until which the window counts as open
	local published = {} -- [player] = os.clock() of the last Meta_stats

	local function publish(player: Player, data, state)
		published[player] = os.clock()
		local ok, result = pcall(snapshot, Game, player, data, state)
		if ok then
			Game.setMeta(player, "stats", result)
		else
			warn(`[Stats] the breakdown could not be built: {result}`)
		end
	end
	Feature.publish = publish

	-- argument: true while the STATS window is open, anything else when it closes.
	Game.actions.statsWatch = function(player: Player, data, state, argument: unknown)
		if argument ~= true then
			watching[player] = nil
			return
		end
		local now = os.clock()
		local fresh = not watching[player]
		watching[player] = now + WATCH_SECONDS
		-- Opening the window shows the numbers at once, but never more often than the limit.
		if fresh and now - (published[player] or -math.huge) >= PUBLISH_SECONDS then
			publish(player, data, state)
		end
	end

	Game.on("ready", function(_player: Player, data)
		local saved = Game.feature(data, "stats", Feature.SAVED)
		saved.bosses, saved.levels, saved.seconds = count(saved.bosses), count(saved.levels), count(saved.seconds)
		if saved.seeded ~= true then
			-- A save from before these were counted: at least every level up to the furthest one was cleared
			-- once, and every boss on the way was beaten once.
			saved.seeded = true
			local bosses = 0
			for level = 1, math.min(data.bestCleared, Config.TotalWaves) do
				if Config.waveKind(level) ~= "normal" then
					bosses += 1
				end
			end
			saved.levels = math.max(saved.levels, data.bestCleared)
			saved.bosses = math.max(saved.bosses, bosses)
		end
	end)

	Game.on("kill", function(_player: Player, data, _state, info)
		if info.kind ~= "normal" then
			local saved = data.features.stats
			if saved then
				saved.bosses = count(saved.bosses) + 1
			end
		end
	end)

	Game.on("waveCleared", function(_player: Player, data)
		local saved = data.features.stats
		if saved then
			saved.levels = count(saved.levels) + 1
		end
	end)

	Game.on("tick", function(player: Player, data, state, dt: number)
		local saved = data.features.stats
		if saved and typeof(dt) == "number" and dt == dt and dt > 0 then
			saved.seconds = count(saved.seconds) + math.min(dt, 5) -- a frozen server is not time played
		end
		local untilTime = watching[player]
		if not untilTime then
			return
		end
		local now = os.clock()
		if now > untilTime then
			watching[player] = nil
		elseif now - (published[player] or -math.huge) >= PUBLISH_SECONDS then
			publish(player, data, state)
		end
	end)

	Game.on("leave", function(player: Player)
		watching[player] = nil
		published[player] = nil
	end)
end

return Feature
