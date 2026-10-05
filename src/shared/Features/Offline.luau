-- Offline earnings: what a player's towers and mini cannons earn while they are away, worked out once when
-- they come back. "The towers' damage per second" below is Cannon Power: the towers' plus the mini cannons'
-- own (they hit the base's lead monster wherever the player is, so they count while away too).
-- A calculation, not a simulation: the towers farm the highest level the player has cleared (or the highest
-- one they can still clear) over and over for the time away, and a share of the coins is paid.
--
--   one clear   = the longer of (spawning the level + one walk down the path) and (all its health / the
--                 towers' damage per second), plus the break between two levels
--   coins       = time away (capped) / one clear x monsters x coins per monster x the coin multiplier x share
--
-- Only coins: no gems, no candy, no kills, no missions. Game speed does not count.
-- The starting cap and share are Config.Offline; the `offlineCap` and `offlineShare` modifiers raise them.
-- The server half (src/server/Features/Offline.luau) feeds this the player's real numbers and pays; the
-- welcome-back card (src/client/Features/Offline.luau) only shows what the server worked out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)

local Offline = {}

-- data.features.offline. coins, seconds, away and level describe earnings that wait for CLAIM (coins 0 = none);
-- earned is the lifetime total paid.
Offline.SAVED = { coins = 0, seconds = 0, away = 0, level = 0, earned = 0 }

local MAX_COINS = 1e300 -- a number past this is not paid: the save is JSON

local function usable(value: any): boolean
	return typeof(value) == "number" and value == value and value > 0 and value < math.huge
end

-- How long the towers take to clear one level and start the next, or nil when they cannot clear it: every
-- monster must be dead before it has walked the path, the first one and the last one.
--   plan    Config.levelPlan(level)
--   dps     the towers' damage per second on that level
--   walk    the multiplier on how fast monsters walk (the `monsterSpeed` modifiers; 1)
--   heal    the share of its health a monster of that level heals per second (0 in most worlds)
function Offline.clearSeconds(plan, dps: number, walk: number?, heal: number?): number?
	local speed = plan.speed * (if usable(walk) then walk :: number else 1)
	if not usable(dps) or not usable(speed) then
		return nil
	end
	-- What is left of the damage once the monster being shot has healed.
	local net = dps - plan.hp * (if usable(heal) then heal :: number else 0)
	if not usable(net) then
		return nil
	end
	local cross = Layout.PATH_LENGTH / speed -- one monster's walk from the spawn to the gate
	local spawning = (plan.count - 1) * plan.gap
	local killing = plan.count * plan.hp / net
	if plan.hp / net > cross or killing > spawning + cross then
		return nil
	end
	return math.max(spawning + cross, killing) + Config.Defense.breakSeconds
end

-- The level that is farmed: `best` (the highest level ever cleared, at least 1) if the towers can clear it,
-- else the highest one below it they can. Returns the level and the seconds one clear takes, or nil when the
-- towers clear nothing at all.
--   dpsOf(plan) -> damage per second on that level     healOf(plan) -> healing share per second (optional)
function Offline.farmLevel(best: number, dpsOf, walk: number?, healOf): (number?, number?)
	local top = math.clamp(math.floor(if best == best then best else 1), 1, Config.TotalWaves)
	for level = top, 1, -1 do
		local plan = Config.levelPlan(level)
		local seconds = Offline.clearSeconds(plan, dpsOf(plan), walk, if healOf then healOf(plan) else 0)
		if seconds then
			return level, seconds
		end
	end
	return nil, nil
end

-- What being away for `away` seconds pays, or nil for nothing.
--   input = { away, best, capHours, share, coinMult, walk, dpsOf, healOf }
-- Returns { coins, seconds = the time paid for, away, level, clearSeconds, perClear = coins of one clear
-- before the share, capped = whether the cap cut the time }.
function Offline.estimate(input)
	local away = input.away
	if typeof(away) ~= "number" or away ~= away or away < Config.Offline.minSeconds then
		return nil
	end
	local cap = (if usable(input.capHours) then input.capHours else 0) * 3600
	local share = if usable(input.share) then math.min(input.share, 1) else 0
	local seconds = math.min(away, cap)
	if seconds <= 0 or share <= 0 or not usable(input.coinMult) then
		return nil
	end
	local level, clearSeconds = Offline.farmLevel(input.best, input.dpsOf, input.walk, input.healOf)
	if not level or not clearSeconds then
		return nil
	end
	local plan = Config.levelPlan(level)
	-- One kill pays floor(coins x multiplier), as in the fight itself.
	local perClear = plan.count * math.floor(plan.coins * input.coinMult)
	local coins = math.floor(seconds / clearSeconds * perClear * share)
	if not usable(coins) or coins > MAX_COINS then
		return nil
	end
	return {
		coins = coins,
		seconds = seconds,
		away = away,
		level = level,
		clearSeconds = clearSeconds,
		perClear = perClear,
		capped = away > cap,
	}
end

-- "8 hours", "1 hour", "90 minutes": the cap as the card writes it.
function Offline.hoursText(hours: number): string
	if hours % 1 ~= 0 then
		return `{math.floor(hours * 60 + 0.5)} minutes`
	end
	return if hours == 1 then "1 hour" else `{hours} hours`
end

return Offline
