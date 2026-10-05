-- A long first session (run with --all-features): a new player idles for 10 minutes, then for 30 more
-- buys what they can afford once a minute. Prints the pace; fails on any error.
local T = harness.load("_prelude.luau")
local Config, Layout, Game = T.Config, T.Layout, T.Game
local player, data, state = T.player, T.data, T.state
local act, run = T.act, T.run

local failedLevels, clearedLevels, leaks = 0, 0, 0
T.Remotes.Feature.OnClientEvent:Connect(function(channel, what)
	if channel == "defense" then
		if what == "failed" then failedLevels += 1 elseif what == "cleared" then clearedLevels += 1 elseif what == "leak" then leaks += 1 end
	end
end)

local function towerCount()
	local n = 0
	for _ in data.towers do n += 1 end
	return n
end

local function line(minute)
	local levels = {}
	for pad, tower in data.towers do table.insert(levels, `{pad}:{tower.kind}{tower.level}`) end
	table.sort(levels)
	print(string.format("  min %2d  level %3d (cleared %3d)  coins %-9s gems %d  pads %d  dps %-8s auto %s  fails %d  towers %s",
		minute, data.wave, data.cleared, T.Format.abbreviate(data.coins), data.diamonds, #data.pads,
		T.Format.abbreviate(player:GetAttribute("Dps")), tostring(data.autoAdvance), failedLevels, table.concat(levels, " ")))
end

T.section("idle for 10 minutes")
for minute = 1, 10 do
	run(60)
	line(minute)
end
T.check(harness.errors() == 0, "no errors while idle")
local idleLevel, idleCoins = data.cleared, data.coins

-- The best unlocked kind by damage per second per coin... a player picks the newest they can afford.
local function bestKind()
	local best
	for _, kind in Config.TowerOrder do
		local def = Config.Towers[kind]
		if data.bestCleared >= def.unlock and data.coins >= def.cost then
			best = kind
		end
	end
	return best
end

local failsSeen, dpsAtFail, lastShopDps = 0, 0, nil
local function shop()
	-- 1. A new pad when it is in reach, and a tower on every empty pad.
	for _ = 1, 16 do
		local price = Config.padPrice(#data.pads + 1)
		if data.coins < price then break end
		local free
		for pad = 1, Layout.PAD_COUNT do
			if not table.find(data.pads, pad) then free = pad break end
		end
		if not free then break end
		act("buyPad", free)
	end
	for _, pad in data.pads do
		if not data.towers[tostring(pad)] then
			local kind = bestKind()
			if kind then act("buildTower", { pad = pad, kind = kind }) end
		end
	end
	-- 2. The rest into upgrades, cheapest tower first, ten levels at a time.
	for _ = 1, 40 do
		local cheapest, cost = nil, math.huge
		for key, tower in data.towers do
			local c = Config.towerUpgradeCost(tower.kind, tower.level)
			if tower.level < Config.TowerMaxLevel and c < cost then cheapest, cost = tonumber(key), c end
		end
		if not cheapest or data.coins < cost then break end
		act("upgradeTower", { pad = cheapest, levels = 10 })
	end
	-- 3. Back to pushing, once the towers are a quarter stronger than when the level was lost.
	local dps = player:GetAttribute("Dps")
	if failedLevels > failsSeen then
		failsSeen, dpsAtFail = failedLevels, math.max(dpsAtFail, dps / 1.0001)
		if lastShopDps then dpsAtFail = lastShopDps end
	end
	lastShopDps = dps
	if not data.autoAdvance and dps >= dpsAtFail * 1.25 then
		act("toggleAuto")
		if data.wave <= data.cleared then
			act("nextWave")
		end
	end
end

T.section("30 minutes of buying once a minute")
for minute = 11, 40 do
	shop()
	run(60)
	line(minute)
end
T.check(harness.errors() == 0, "no errors in the whole session")
print(`RESULT idle 10 min: cleared {idleLevel}, coins {T.Format.abbreviate(idleCoins)}`)
print(`RESULT 40 min: on level {data.wave}, cleared {data.cleared} ({Config.waveLabel(math.max(1, data.cleared))}), coins {T.Format.abbreviate(data.coins)}, gems {data.diamonds}, pads {#data.pads}, towers {towerCount()}, kills {data.totalKills}, levels cleared {clearedLevels}, failed {failedLevels}, leaks {leaks}, pets {#data.pets}`)
