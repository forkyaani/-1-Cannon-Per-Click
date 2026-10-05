-- Cannon ammo: collectible shells a player loads into one of two slots. The towers' slot covers every shot of
-- every tower, the mini cannons' slot covers the shots of the mini cannons that follow the player. Loading
-- does not use an ammo up; owning one is enough.
-- Every ammo type and every number it uses is in TYPES below. The server feature applies the effects and the
-- client feature draws the AMMO window, both from this module.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)

local Ammo = {}

local rgb = Color3.fromRGB

Ammo.STANDARD = "standard" -- the free ammo every slot falls back to
Ammo.BURN_SECONDS = 3 -- a burn deals its damage evenly over this long, to the monster the shot hit
-- Seconds between one player's boss-drop rolls. Drops are paid for time, not kills: without this, parking on
-- an easy boss (dozens of kills a second) would flood the market with rare ammo.
Ammo.DROP_COOLDOWN = 10

-- key is what the save, the equipAmmo action and the client state use ("big" was the clicker's big cannon and
-- stays the key so saved choices keep working: it is the towers' slot now). short goes on the window's buttons.
Ammo.Slots = {
	{ key = "big", name = "TOWERS", short = "TOWERS", hint = "every tower's shots" },
	{ key = "mini", name = "MINI CANNONS", short = "MINI", hint = "their shots" },
}

-- An ammo's effect only applies to shots from the slot it is loaded in. Leave out what it does not do.
--   damage        multiplies every shot
--   bossDamage    multiplies shots fired on a boss level
--   doubleChance  chance that a shot hits twice
--   critChance    chance that a shot hits critDamage times as hard
--   burn          sets the monster the shot hits on fire: extra damage, as a share of the shot's own, dealt
--                 over BURN_SECONDS
--   slow          a hit has slowChance to make the monster it hits walk this much slower (0.3 = 30%) for
--                 slowSeconds. Weaker than a Frost tower's slow on purpose, and the two do not add up
--   coins, candy  extra coins and Halloween candy (0.5 = +50%) from the monsters this slot's shots defeat
--   healCut       a hit has healChance to make monsters heal this much slower (1 = not at all) for healSeconds.
--                 Only some worlds' monsters heal, so no ammo does this alone
-- Looks: color and size restyle the shots of the player's own mini cannons when it is in their slot (tower
-- shots keep their kind's look); rainbow changes the colour with every shot.
-- Coin prices are sized on the tower game's coin curve (Config.levelCoins): about 20 clears of level 15 and
-- 30 clears of level 30.
-- Getting it: price is what the Ammo Forge charges, and it only sells to a player who owns none.
--   dropOneIn   a boss kill's drop roll gives it 1 time in this many
--   event       it only drops while the Halloween event is live
--   announce    a drop is told to the whole server
local TYPES = {
	{ id = Ammo.STANDARD, name = "Standard Ammo", rarity = "Common", color = rgb(150, 155, 165), free = true },
	{
		id = "ammo_double", name = "Double Shot Ammo", rarity = "Uncommon", color = rgb(205, 215, 230), size = 1.5,
		doubleChance = 0.25,
		price = { currency = "coins", cost = 10_000 },
	},
	{
		id = "ammo_golden", name = "Golden Ammo", rarity = "Uncommon", color = rgb(255, 205, 60), size = 1.5,
		coins = 0.25,
		price = { currency = "coins", cost = 100_000 },
	},
	{
		id = "ammo_flame", name = "Flame Ammo", rarity = "Rare", color = rgb(255, 110, 30), size = 1.7,
		burn = 0.3,
		price = { currency = "diamonds", cost = 200 },
		dropOneIn = 400,
	},
	{
		id = "ammo_poison", name = "Poison Ammo", rarity = "Rare", color = rgb(170, 70, 220), size = 1.6,
		slow = 0.15, slowChance = 1, slowSeconds = 3, healCut = 0.5, healChance = 1, healSeconds = 3,
		price = { currency = "diamonds", cost = 200 },
		dropOneIn = 400,
	},
	{
		id = "ammo_frost", name = "Frost Ammo", rarity = "Epic", color = rgb(140, 220, 255), size = 1.6,
		slow = 0.3, slowChance = 0.25, slowSeconds = 2,
		dropOneIn = 3_000,
	},
	{
		id = "ammo_lucky", name = "Lucky Ammo", rarity = "Epic", color = rgb(70, 220, 110), size = 1.6,
		critChance = 0.1, critDamage = 4,
		dropOneIn = 3_000,
	},
	{
		id = "ammo_boss", name = "Boss Breaker Ammo", rarity = "Epic", color = rgb(220, 50, 50), size = 2,
		bossDamage = 1.5,
		dropOneIn = 3_000,
	},
	{
		id = "ammo_candy", name = "Candy Ammo", rarity = "Exclusive", color = rgb(255, 120, 190), size = 1.6,
		candy = 1,
		dropOneIn = 1_000, event = true,
	},
	{
		id = "ammo_void", name = "Void Ammo", rarity = "Legendary", color = rgb(130, 60, 255), size = 2.2,
		damage = 1.5, healCut = 1, healChance = 1, healSeconds = 3,
		dropOneIn = 40_000, announce = true,
	},
	{
		id = "ammo_rainbow", name = "Rainbow Ammo", rarity = "Legendary", color = rgb(255, 245, 250), size = 2.2, rainbow = true,
		damage = 1.5, coins = 0.5, candy = 1,
		dropOneIn = 40_000, announce = true,
	},
}

local ICONS = { coins = "💰", diamonds = "💎" }

local function percent(share: number): string
	return `{math.floor(share * 100 + 0.5)}%`
end

-- 40000 -> "40,000". Odds read better in full than abbreviated ("1 in 3.00K").
local function commas(n: number): string
	local text, swaps = tostring(n), 0
	repeat
		text, swaps = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
	until swaps == 0
	return text
end

-- What an ammo does, in a few words. Written from its numbers, so the text can never disagree with them.
local function effectText(def): string
	local parts = {}
	if def.damage then
		table.insert(parts, `{def.damage}x damage`)
	end
	if def.bossDamage then
		table.insert(parts, `{def.bossDamage}x damage on boss levels`)
	end
	if def.doubleChance then
		table.insert(parts, `{percent(def.doubleChance)} chance to hit twice`)
	end
	if def.critChance then
		table.insert(parts, `{percent(def.critChance)} chance of {def.critDamage}x damage`)
	end
	if def.burn then
		table.insert(parts, `burns what it hits for +{percent(def.burn)} damage over {Ammo.BURN_SECONDS}s`)
	end
	if def.slow then
		local what = `slows what it hits by {percent(def.slow)} for {def.slowSeconds}s`
		table.insert(parts, if def.slowChance >= 1 then what else `{percent(def.slowChance)} chance: {what}`)
	end
	if def.coins then
		table.insert(parts, `+{percent(def.coins)} coins`)
	end
	if def.candy then
		table.insert(parts, `+{percent(def.candy)} candy`)
	end
	if def.healCut then
		local what = if def.healCut >= 1 then "monsters cannot heal" else `monsters heal {percent(def.healCut)} slower`
		table.insert(parts, if def.healChance >= 1 then what else `{percent(def.healChance)} chance: {what} for {def.healSeconds}s`)
	end
	if #parts == 0 then
		return "No special effect"
	end
	return (string.gsub(table.concat(parts, ", "), "^%l", string.upper))
end

-- "1 in 40,000": an ammo's chance on a boss kill's drop roll.
function Ammo.oddsText(def): string
	return `1 in {commas(def.dropOneIn)}`
end

-- How a player gets an ammo, in a few words.
local function sourceText(def): string
	if def.free then
		return "Free: always loaded when nothing else is"
	end
	local parts = {}
	if def.price then
		table.insert(parts, `Ammo Forge {Format.abbreviate(def.price.cost)} {ICONS[def.price.currency]}`)
	end
	if def.dropOneIn then
		table.insert(parts, `{if def.event then "Halloween boss" else "Boss"} drop {Ammo.oddsText(def)}`)
	end
	return table.concat(parts, "  •  ")
end

-- Every type in catalogue order, and by id. Each gets order, desc (its effect) and source (how to get it).
-- All but the free one are backpack items: category "ammo", tradable, so crates and trading find them by id.
Ammo.Types = TYPES
Ammo.byId = {}
for order, def in TYPES do
	def.order = order
	def.desc = effectText(def)
	def.source = sourceText(def)
	Ammo.byId[def.id] = def
	if not def.free then
		def.category = "ammo"
		def.tradable = true
		Items.define(def.id, def)
	end
end

-- The ammo a slot fires: the player's choice while they still own one of it, otherwise Standard.
-- choice is { [slot key] = ammo id } and counts is { [item id] = how many the player owns }.
function Ammo.loaded(choice: { [string]: string }, counts: { [string]: number }, slot: string)
	local def = Ammo.byId[choice[slot]]
	if def and (def.free or (counts[def.id] or 0) >= 1) then
		return def
	end
	return Ammo.byId[Ammo.STANDARD]
end

return Ammo
