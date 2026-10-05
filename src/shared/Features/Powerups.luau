-- Powerups: backpack items that start a timed boost when they are used.
-- Every number of the feature is in this file: what each boost does, how long one item lasts, how often they
-- drop and what the Robux bundles hold. The server half is src/server/Features/Powerups.luau; the backpack
-- window that lists and uses them is src/client/Features/Backpack.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

local Powerups = {}

local rgb = Color3.fromRGB

----------------------------------------------------------------------------------------------------
-- Boosts: timed effects. The core keeps them as data.boosts[id] = the unix time it runs out.
-- name is what the HUD shows next to the time left: the name of the powerup that starts it, so the two are
-- easy to connect. The other keys are what the boost does while it runs:
--   perClick, damage, coins, heal, autoShots, luck   multiplies that number (the Game.modify kinds; perClick
--                                                    is the multiplier on all damage, damage one shot's)
--   candy                                            multiplies the Halloween candy monsters drop
--   fireRate                                         every tower fires this many times as fast (the core's
--                                                    towerRate modifier)
--   slow                                             every monster on the plot walks this much slower
--                                                    (0.5 = 50%); the strongest slow on a monster counts
-- 2x Power (power2x) and 2x Coins (coins2x) are not listed: they are the core's own boosts, named in
-- Config.Boosts and applied by Game.luau (2x Power doubles the damage of every tower: the power multiplier, which the mini cannons' own damage is not in).
-- The ids autotap and healfreeze are from the clicker (Auto Tap, Heal Freeze): they are what saves, crates
-- and the story name, so they stay; what the player sees is Overdrive and Deep Freeze.
----------------------------------------------------------------------------------------------------
Powerups.Boosts = {
	luck2x = { name = "2x Luck", luck = 2 },
	megaluck = { name = "Mega Luck", luck = 5 },
	candy2x = { name = "2x Candy", candy = 2 },
	autotap = { name = "Overdrive", fireRate = 2 },
	megadamage = { name = "Mega Damage", damage = 3 },
	healfreeze = { name = "Deep Freeze", slow = 0.5, heal = 0 },
}
-- The HUD lists every running boost it finds a name for in Config.Boosts.
for id, boost in Powerups.Boosts do
	Config.Boosts[id] = boost
end

----------------------------------------------------------------------------------------------------
-- The powerups: one backpack item each. Using one starts every boost in `boosts` for `seconds`, or adds that
-- long to the time they have left. Descriptions that hold a number take it from the boost above.
-- " for 5 min" is added to each description from seconds. The times are real time: a plot at 3x game speed
-- fights three times as many levels under one boost, which is why they are a third of the clicker's.
--   weight   chance out of 100 that a random powerup (boss drop, first-clear gift) is this one. They add up to 100.
--   event    only drops and only works while the Halloween event is live (the others share its chance after)
-- The shops and the daily reward (Config.WeeklyFixed, Config.EventShop, Config.Daily) name a boost and minutes.
-- Game.luau hands out the powerup with that boost's id instead, as many as cover the minutes (30 min = 2).
----------------------------------------------------------------------------------------------------
local OVERDRIVE, MEGA, FREEZE = Powerups.Boosts.autotap, Powerups.Boosts.megadamage, Powerups.Boosts.healfreeze
Powerups.List = {
	{
		id = "power2x", name = "2x Power", desc = "Double all damage: towers and mini cannons", rarity = "Common", color = rgb(255, 120, 60),
		boosts = { "power2x" }, seconds = 300, weight = 28,
	},
	{
		id = "coins2x", name = "2x Coins", desc = "Double coins from monsters", rarity = "Common", color = rgb(255, 205, 60),
		boosts = { "coins2x" }, seconds = 300, weight = 28,
	},
	{
		id = "candy2x", name = "2x Candy", desc = "Double candy from monsters", rarity = "Uncommon", color = rgb(255, 130, 200),
		boosts = { "candy2x" }, seconds = 300, weight = 12, event = true,
	},
	{
		id = "luck2x", name = "2x Luck", desc = "Rare or better hatch 2x as often", rarity = "Rare", color = rgb(90, 210, 110),
		boosts = { "luck2x" }, seconds = 300, weight = 10,
	},
	{
		id = "autotap", name = OVERDRIVE.name, desc = `Every tower fires {OVERDRIVE.fireRate}x as fast`, rarity = "Rare", color = rgb(80, 170, 255),
		boosts = { "autotap" }, seconds = 300, weight = 8,
	},
	{
		id = "megadamage", name = MEGA.name, desc = `Every tower and mini cannon shot deals {MEGA.damage}x damage`, rarity = "Epic", color = rgb(230, 60, 60),
		boosts = { "megadamage" }, seconds = 60, weight = 6,
	},
	{
		id = "healfreeze", name = FREEZE.name, desc = `Monsters walk {FREEZE.slow * 100}% slower and cannot heal`, rarity = "Epic", color = rgb(140, 230, 255),
		boosts = { "healfreeze" }, seconds = 60, weight = 6,
	},
	-- Premium: three boosts from one item, and the strongest luck there is.
	{
		id = "supercharge", name = "Supercharge", desc = `2x Power, 2x Coins and {OVERDRIVE.name}`, rarity = "Legendary", color = rgb(190, 90, 255),
		boosts = { "power2x", "coins2x", "autotap" }, seconds = 600, weight = 1.5,
	},
	{
		id = "megaluck", name = "Mega Luck", desc = "Rare or better hatch 5x as often", rarity = "Legendary", color = rgb(60, 255, 160),
		boosts = { "megaluck" }, seconds = 300, weight = 0.5,
	},
}
-- Each entry is also its item definition in the shared registry (category "powerup"), listed in this order.
for order, powerup in Powerups.List do
	local seconds = powerup.seconds
	powerup.desc ..= if seconds % 60 == 0 then ` for {seconds // 60} min` else ` for {seconds} sec`
	powerup.category = "powerup"
	powerup.usable = true
	powerup.tradable = true
	powerup.order = order
	for _, id in powerup.boosts do
		assert(Config.Boosts[id], `powerup {powerup.id} starts unknown boost {id}`)
	end
	Items.define(powerup.id, powerup)
end

-- A powerup's time can be stacked this many uses deep (4 x 5 min = 20 minutes of 2x Power). USE is refused
-- beyond that, so a whole stack cannot be burnt by pressing USE too often: boost time runs out in real time,
-- also while the player is away.
Powerups.MaxUses = 4

----------------------------------------------------------------------------------------------------
-- Finding powerups by playing. Both ways are capped per UTC day, so neither can be farmed without end.
----------------------------------------------------------------------------------------------------
Powerups.Drops = {
	-- A defeated boss can drop one random powerup. chance is per kill, by level kind (Config.WaveKinds).
	-- cooldown is the seconds after a drop before the next one can fall.
	boss = { chance = { boss = 0.04, mid = 0.12, final = 0.3 }, cooldown = 600, perDay = 2 },
	-- The first boss levels a player clears for the first time each day come with one random powerup.
	firstClear = { perDay = 1 },
}

----------------------------------------------------------------------------------------------------
-- Robux bundles (developer products), listed under GET MORE POWERUPS in the backpack.
-- product is the developer product id from the Creator Hub; 0 means not on sale yet (as in Config.Passes).
-- price is only what the button shows: the real price is whatever the product is set to on Roblox.
-- items is exactly what one purchase gives: { item id, how many }. Nothing in a bundle is random, and none
-- of it changes hatching luck: luck sold for Robux falls under Roblox's paid random item rules (docs/GEMS.md).
-- event bundles are only shown and sold while the Halloween event is live.
----------------------------------------------------------------------------------------------------
Powerups.Bundles = {
	{ id = "boost", product = 0, price = 49, name = "Boost Pack", items = { { "power2x", 5 }, { "coins2x", 5 } } },
	{ id = "boss", product = 0, price = 129, name = "Boss Buster Pack", items = { { "megadamage", 5 }, { "healfreeze", 5 }, { "autotap", 3 } } },
	{
		id = "mega", product = 0, price = 399, name = "Mega Pack",
		items = { { "supercharge", 3 }, { "power2x", 15 }, { "coins2x", 15 }, { "autotap", 10 }, { "megadamage", 10 }, { "healfreeze", 10 } },
	},
	{ id = "candy", product = 0, price = 79, name = "Candy Pack", event = true, items = { { "candy2x", 8 } } },
}
for _, bundle in Powerups.Bundles do
	for _, entry in bundle.items do
		assert(Items.get(entry[1]), `bundle {bundle.id} holds unknown item {entry[1]}`)
	end
end

----------------------------------------------------------------------------------------------------
-- Formulas. boosts is a player's { [boost id] = unix time it runs out }: data.boosts on the server,
-- State.meta.boosts on the client.
----------------------------------------------------------------------------------------------------
-- What the running boosts multiply `kind` by (a key from the list above Powerups.Boosts): 1 when none does.
function Powerups.multiplier(kind: string, boosts: { [string]: number }, now: number): number
	local value = 1
	for id, boost in Powerups.Boosts do
		if boost[kind] and (boosts[id] or 0) > now then
			value *= boost[kind]
		end
	end
	return value
end

-- How much slower the running boosts make every monster walk: the strongest one, 0 when none does.
function Powerups.slow(boosts: { [string]: number }, now: number): number
	local slow = 0
	for id, boost in Powerups.Boosts do
		if boost.slow and (boosts[id] or 0) > now then
			slow = math.max(slow, boost.slow)
		end
	end
	return slow
end

-- Seconds a powerup still has to run: the least of the boosts it starts, so 0 unless all of them are on.
function Powerups.timeLeft(powerup, boosts: { [string]: number }, now: number): number
	local left = math.huge
	for _, id in powerup.boosts do
		left = math.min(left, (boosts[id] or 0) - now)
	end
	return math.max(0, left)
end

-- Whether USE is refused for now (see MaxUses).
function Powerups.isFull(powerup, boosts: { [string]: number }, now: number): boolean
	return Powerups.timeLeft(powerup, boosts, now) + powerup.seconds > Powerups.MaxUses * powerup.seconds
end

-- A random powerup, by weight. roll is a random number in [0, 1). Event powerups are left out unless eventLive.
function Powerups.roll(roll: number, eventLive: boolean)
	local total = 0
	for _, powerup in Powerups.List do
		if eventLive or not powerup.event then
			total += powerup.weight
		end
	end
	local remaining = roll * total
	local picked = Powerups.List[1]
	for _, powerup in Powerups.List do
		if powerup.weight > 0 and (eventLive or not powerup.event) then
			picked = powerup
			remaining -= powerup.weight
			if remaining < 0 then
				break
			end
		end
	end
	return picked
end

return Powerups
