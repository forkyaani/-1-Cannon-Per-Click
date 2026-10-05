-- Powerups, server half: what USE does, what the boosts do while they run, how powerups are found by playing,
-- and the Robux bundles. The numbers are all in the shared module (src/shared/Features/Powerups.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Powerups = require(ReplicatedStorage.Shared.Features.Powerups)

local Drops = Powerups.Drops
-- The kinds of Game.modify a boost can change: a boost with one of these as a key multiplies that number
-- while it runs. A boost's fireRate is the core's towerRate.
local MODIFIERS = { "perClick", "damage", "coins", "heal", "autoShots", "luck", "fireRate" }
local KIND_OF = { fireRate = "towerRate" }
-- This feature's saved table: the UTC day the two counters are for, and when a boss may drop a powerup again.
-- rebirthGifts counts the day's first-clear gifts: the key is from the clicker, where a rebirth gave them.
local SAVED = { day = 0, bossDrops = 0, rebirthGifts = 0, nextDrop = 0 }
local SLOW_HOLD = 1 -- seconds Deep Freeze lasts on a monster: renewed every tick while the boost runs
local HOW_TO_USE = "Use it from your BACKPACK"

local Feature = {}

function Feature.start(Game)
	-- The saved table, with the counters back at 0 once the UTC day has rolled over (like the daily missions).
	local function today(data)
		local saved = Game.feature(data, "powerups", SAVED)
		local day = Config.dayNumber(os.time())
		if saved.day ~= day then
			saved.day, saved.bossDrops, saved.rebirthGifts = day, 0, 0
		end
		return saved
	end

	-- Puts one random powerup in the backpack and returns it, for the toast.
	local function giveRandom(player: Player)
		local powerup = Powerups.roll(Game.random:NextNumber(), Config.halloweenActive(os.time()))
		Game.items.give(player, powerup.id, 1)
		return powerup
	end

	------------------------------------------------------------------------------------------------
	-- USE: starts every boost of the powerup, or adds to the time they have left.
	------------------------------------------------------------------------------------------------
	local function use(player: Player, data, _state, powerup): boolean
		local now = os.time()
		if powerup.event and not Config.halloweenActive(now) then
			Game.notify(player, "The Halloween event has ended", "bad")
			return false
		end
		if Powerups.isFull(powerup, data.boosts, now) then
			local left = Format.duration(Powerups.timeLeft(powerup, data.boosts, now))
			Game.notify(player, `{powerup.name} still has {left} left - save this one for later`, "info")
			return false
		end
		for _, id in powerup.boosts do
			Game.boosts.add(player, id, powerup.seconds)
		end
		local left = Format.duration(Powerups.timeLeft(powerup, data.boosts, now))
		Game.notify(player, `{powerup.name} is on! {left} left`, "good")
		return true
	end
	-- Registered per item, not for the whole category: another feature's powerup brings its own handler.
	for _, powerup in Powerups.List do
		Game.onUse(powerup.id, use)
	end

	------------------------------------------------------------------------------------------------
	-- What the boosts do
	------------------------------------------------------------------------------------------------
	-- One modifier for each kind that some boost changes. Its label, for the STATS window, names the boosts
	-- of that kind that are running, each with the time it has left.
	for _, kind in MODIFIERS do
		for _, boost in Powerups.Boosts do
			if boost[kind] then
				Game.modify(KIND_OF[kind] or kind, function(_player: Player, data, _state, value: number): number
					return value * Powerups.multiplier(kind, data.boosts, os.time())
				end, function(_player: Player, data): string?
					local now = os.time()
					local running = {}
					for id, other in Powerups.Boosts do
						local left = (data.boosts[id] or 0) - now
						if other[kind] and left > 0 then
							table.insert(running, `{other.name} ({Format.duration(left)} left)`)
						end
					end
					table.sort(running)
					return if #running > 0 then table.concat(running, ", ") else nil
				end)
				break
			end
		end
	end

	-- Deep Freeze works on the fight itself, twice a second: it puts its slow on every monster, unless a
	-- stronger one (a Frost tower's) is running on it. (The core's monsterSpeed modifier would stack with a
	-- Frost tower instead, and the monsters would not show as slowed.)
	Game.on("tick", function(_player: Player, data, state, _dt: number)
		if state.phase ~= "fight" then
			return
		end
		local now = os.time()
		local slow = Powerups.slow(data.boosts, now)
		if slow > 0 then
			local clock = state.clock
			for _, monster in state.monsters do
				if not monster.dead and (clock >= monster.slowUntil or monster.slow <= slow) then
					monster.slow = slow
					monster.slowUntil = clock + SLOW_HOLD
				end
			end
		end
	end)

	------------------------------------------------------------------------------------------------
	-- Monsters: extra candy while a candy boost runs, and bosses that drop a powerup now and then.
	-- Runs for every kill, up to 50 times in one shot, so the common case does next to nothing.
	------------------------------------------------------------------------------------------------
	Game.on("kill", function(player: Player, data, _state, info)
		local now = os.time()
		-- The core has paid the normal candy already; this adds the boost's share on top.
		if Config.halloweenActive(now) then
			local extra = Powerups.multiplier("candy", data.boosts, now) - 1
			if extra > 0 then
				local base = if info.kind == "normal" then Config.Halloween.candyPerKill else Config.Halloween.candyPerBoss
				data.candy += math.floor(base * extra + 0.5)
			end
		end

		local chance = Drops.boss.chance[info.kind]
		if not chance then
			return
		end
		local saved = today(data)
		if saved.bossDrops >= Drops.boss.perDay or now < saved.nextDrop or Game.random:NextNumber() >= chance then
			return
		end
		saved.bossDrops += 1
		saved.nextDrop = now + Drops.boss.cooldown
		local powerup = giveRandom(player)
		Game.notify(player, `{Config.monsterFor(info.wave).name} dropped {powerup.name}! {HOW_TO_USE}`, "good")
	end)

	-- The first time a boss level is cleared, a powerup comes with it: twice a day at most.
	Game.on("waveCleared", function(player: Player, data, _state, wave: number, firstClear: boolean)
		if not firstClear or Config.waveKind(wave) == "normal" then
			return
		end
		local saved = today(data)
		if saved.rebirthGifts >= Drops.firstClear.perDay then
			return
		end
		saved.rebirthGifts += 1
		local powerup = giveRandom(player)
		Game.notify(player, `First clear gift: {powerup.name}! {HOW_TO_USE}`, "good")
	end)

	------------------------------------------------------------------------------------------------
	-- Robux bundles
	------------------------------------------------------------------------------------------------
	for _, bundle in Powerups.Bundles do
		if bundle.product ~= 0 then
			Game.products[bundle.product] = function(player: Player): boolean
				for _, entry in bundle.items do
					Game.items.give(player, entry[1], entry[2])
				end
				Game.notify(player, `{bundle.name} bought! Your powerups are in your BACKPACK`, "good")
				return true
			end
		end
	end

	-- The GET MORE buttons in the backpack.
	Game.actions.buyPowerups = function(player: Player, _data, _state, bundleId: unknown)
		for _, bundle in Powerups.Bundles do
			if bundle.id == bundleId then
				if bundle.event and not Config.halloweenActive(os.time()) then
					Game.notify(player, "The Halloween event has ended", "bad")
				elseif bundle.product == 0 then
					Game.notify(player, `{bundle.name} is not on sale yet`, "info")
				else
					Game.promptProduct(player, bundle.product)
				end
				return
			end
		end
	end
end

return Feature
