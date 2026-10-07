-- Offline earnings, server half: when a player comes back after more than a minute away, work out once what
-- their towers and mini cannons earned farming their best level (src/shared/Features/Offline.luau has the calculation), keep
-- it in the save and pay it when they press CLAIM on the welcome-back card (the `offlineClaim` action).
--
-- The time away is state.away: the core reads the save's lastSeen when it loads, and Data.luau stamps
-- lastSeen on every save and on leave. The amount is fixed here, at join; the client only shows it.
-- The cap (hours) and the share are the `offlineCap` and `offlineShare` modifiers, so a pass or a Mastery
-- track raises them with Game.modify; Feature.estimate is the whole sum, for anything that wants to wrap it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Offline = require(ReplicatedStorage.Shared.Features.Offline)

local Feature = {}

-- A saved number that can be counted with: 0 for anything else.
local function count(value: any): number
	return if typeof(value) == "number" and value == value and value >= 0 and value < math.huge then value else 0
end

function Feature.start(Game)
	-- What `away` seconds away pay this player, with the towers and bonuses they have right now, or nil.
	-- (Shared's Offline.estimate describes the result.) Game speed is not in it.
	function Feature.estimate(player: Player, data, state, away: number)
		local power = Game.value(player, "power")
		local rate = Game.value(player, "towerRate")
		local bossDamage = Game.value(player, "bossDamage")
		-- The mini cannons' own damage per second: they hit the base's lead monster wherever the player is, away
		-- from the game too, so it counts in full. It is flat: the towers' multipliers do not touch it.
		-- Crits count as what they add on average (Game.critMean), as in Cannon Power.
		local towerCrit, petCrit = 1, 1
		if typeof(Game.critMean) == "function" then
			towerCrit, petCrit = Game.critMean(player)
		end
		local pets = Game.value(player, "petDps") * petCrit
		-- Cannon Power as the core counts it, and the same on a boss level (a Sniper hits bosses harder).
		local normal, boss = 0, 0
		for _, tower in state.towerList do
			local own = tower.base * tower.def.rate
			normal += own * towerCrit
			boss += own * towerCrit * (tower.def.boss or 1)
		end
		-- What the player's bonuses leave of a level's healing (Heal Block, Hex). It can only be read off a
		-- level that heals: on any other the farmed level's healing counts in full.
		local healShare = 1
		if state.plan.regen > 0 then
			healShare = math.clamp(Game.value(player, "heal") / state.plan.regen, 0, 1)
		end
		return Offline.estimate({
			away = away,
			best = data.bestCleared,
			capHours = Game.value(player, "offlineCap"),
			share = Game.value(player, "offlineShare"),
			coinMult = Game.value(player, "coins"),
			walk = Game.value(player, "monsterSpeed"),
			dpsOf = function(plan): number
				return if plan.kind == "normal" then normal * power * rate + pets else (boss * power * rate + pets) * bossDamage
			end,
			healOf = function(plan): number
				return plan.regen * healShare
			end,
		})
	end

	local function publish(player: Player, data)
		local saved = Game.feature(data, "offline", Offline.SAVED)
		Game.setMeta(player, "offline", {
			coins = saved.coins, -- waiting for CLAIM; 0 = nothing
			seconds = saved.seconds, -- the time that was paid for
			away = saved.away, -- the time away
			level = saved.level, -- the level the towers farmed
			capHours = Game.value(player, "offlineCap"),
			share = Game.value(player, "offlineShare"),
			earned = saved.earned,
		})
	end

	-- CLAIM on the welcome-back card. No argument: the amount is the one worked out at join, and it is paid once.
	Game.actions.offlineClaim = function(player: Player, data)
		local saved = Game.feature(data, "offline", Offline.SAVED)
		local coins = math.floor(count(saved.coins))
		if coins <= 0 then
			return
		end
		saved.coins, saved.seconds, saved.away, saved.level = 0, 0, 0, 0
		local total = data.coins + coins
		if total ~= total or total == math.huge then
			return
		end
		data.coins = total
		saved.earned = count(saved.earned) + coins
		publish(player, data)
		Game.notify(player, `Welcome back! Your towers earned {Format.abbreviate(coins)} coins while you were away`, "good")
	end

	Game.on("ready", function(player: Player, data, state)
		local saved = Game.feature(data, "offline", Offline.SAVED)
		for key in Offline.SAVED do
			saved[key] = count(saved[key])
		end
		saved.level = math.clamp(math.floor(saved.level), 0, Config.TotalWaves)
		local ok, result = pcall(Feature.estimate, player, data, state, count(state.away))
		if not ok then
			warn(`[Offline] the earnings could not be worked out: {result}`)
		elseif result then
			-- Earnings that were never claimed are kept: the new ones join them.
			saved.coins += result.coins
			saved.seconds += result.seconds
			saved.away += result.away
			saved.level = result.level
		end
		publish(player, data)
	end)
end

return Feature
