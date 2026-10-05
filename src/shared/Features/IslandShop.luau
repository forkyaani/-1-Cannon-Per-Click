-- The island shops: every world's island (src/server/Islands.luau) has a stall that sells three things for
-- coins: that world's ammo, one powerup that changes every day, and a Boss Chest. From The Sun's island on,
-- where enchanting is, a stall also sells Enchantment Keys for gems.
-- Every number of the shop is in this file. The server half (src/server/Features/IslandShop.luau) sells from
-- these functions and the ISLAND SHOP window (src/client/Features/IslandShop.luau) lists from them, so the
-- window can never show a price the server would not take.
--
-- The things sold are other features' backpack items (ammo, powerups, the Boss Chest crate). They are looked
-- up in the item registry when an offer is asked for: an item that does not exist in this build is left out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

-- The features that define what the shop sells. Requiring them here makes their items known whichever
-- feature starts first; one that is missing only empties its row.
for _, name in { "Ammo", "Powerups", "Crates", "Enchant" } do
	local module = script.Parent:FindFirstChild(name)
	if module then
		pcall(require, module)
	end
end

local IslandShop = {}

IslandShop.WINDOW = "ISLAND SHOP"
IslandShop.KINDS = { "ammo", "powerup", "chest" } -- the three rows every island sells for coins
IslandShop.ROWS = { "ammo", "powerup", "chest", "key" } -- every row there is, in the window's order

-- Coin prices are in clears: what clearing one ordinary level pays (Config.levelCoins), the measure pads,
-- eggs and crates are priced in.

-- Ammo: the ammo each world's island sells, by world. An ammo's price belongs to the ammo, not the island:
-- it is `clears` (by rarity) clears of level AMMO_LEVEL of the first world that sells it, and never more
-- than the Ammo Forge asks in coins. Like the forge, an island only sells an ammo to a player who owns none
-- of it (loading does not use an ammo up, so one is all anybody needs), and once a day.
IslandShop.Ammo = {
	"ammo_double", -- Earth
	"ammo_golden", -- Moon
	"ammo_boss", -- Mars: the war zone's bosses
	"ammo_frost", -- Neptune
	"ammo_flame", -- The Sun
	"ammo_lucky", -- The Void
	"ammo_poison", -- Nebula: its monsters heal
	"ammo_boss", -- Crystal Belt
	"ammo_double", -- Robot Factory
	"ammo_poison", -- Alien Jungle: its bosses heal
	"ammo_void", -- Black Hole
	"ammo_rainbow", -- The Big Bang
}
IslandShop.AmmoLevel = 15 -- the level of its world an ammo is priced at
IslandShop.AmmoClears = { Uncommon = 20, Rare = 30, Epic = 40, Legendary = 150 }

-- The powerup: every island sells one of these a day, a different one each day and on each island. One per
-- island per day. Its price follows the buyer: `clears` (by rarity) clears of the furthest level they have
-- cleared in this run, and never less than the island's own first level, so a boost costs the same effort
-- in the first world and the last. The premium powerups (Supercharge, Mega Luck) are not sold for coins.
IslandShop.Powerups = { "power2x", "coins2x", "luck2x", "autotap", "megadamage", "healfreeze" }
IslandShop.PowerupClears = { Common = 20, Uncommon = 20, Rare = 20, Epic = 4 }

-- The Boss Chest: one a day, on whichever island the player buys it. Priced like the powerup. It pays back
-- about 1.8 clears in coins on average, plus its powerups, ammo and mini cannons (Features/Crates.luau).
IslandShop.Chest = "bosschest"
IslandShop.ChestClears = 4

-- The Enchantment Key (src/shared/Features/Enchant.luau): the one row sold for gems, on the islands from
-- `from` on (the enchanting table's island and every later one). `perDay` a day in all, on whichever
-- islands the player buys them. The Shiny key is not sold here.
IslandShop.Key = { item = "enchantkey", gems = 40, perDay = 3, from = Config.EnchantIsland }

-- What a row is paid in: the save's own name for it ("diamonds" are the gems).
function IslandShop.currency(kind: string): string
	return if kind == "key" then "diamonds" else "coins"
end

-- Rounds to two significant digits so generated prices look hand-picked (as Config does).
local function nice(n: number): number
	if n < 100 then
		return math.max(1, math.floor(n))
	end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / magnitude + 0.5) * magnitude
end

local function firstLevel(index: number): number
	return (index - 1) * Config.WavesPerWorld + 1
end

-- The level a following price is measured at: the furthest level cleared, but at least the island's first.
local function buyerLevel(index: number, cleared: number): number
	return math.max(firstLevel(index), cleared)
end

-- The first world whose island sells an ammo.
local function ammoWorld(id: string): number
	for index, other in IslandShop.Ammo do
		if other == id then
			return index
		end
	end
	return 1
end

-- What the island of world `index` sells on UTC day `day`: the item id of each row, or nil for a row this
-- build has no item for (or, the key, an island that does not sell it). { ammo = id?, powerup = id?,
-- chest = id?, key = id? }
function IslandShop.stock(index: number, day: number): { [string]: string }
	local stock = {}
	local ammo = IslandShop.Ammo[(index - 1) % #IslandShop.Ammo + 1]
	if Items.get(ammo) then
		stock.ammo = ammo
	end
	local powerups = {}
	for _, id in IslandShop.Powerups do
		if Items.get(id) then
			table.insert(powerups, id)
		end
	end
	if #powerups > 0 then
		stock.powerup = powerups[(day + index) % #powerups + 1]
	end
	if Items.get(IslandShop.Chest) then
		stock.chest = IslandShop.Chest
	end
	if index >= IslandShop.Key.from and Items.get(IslandShop.Key.item) then
		stock.key = IslandShop.Key.item
	end
	return stock
end

-- What a row costs (in coins; the key in gems: IslandShop.currency) on the island of world `index`, for a
-- player whose furthest cleared level of this run is `cleared`. Nil for an item the shop does not know.
function IslandShop.price(kind: string, id: string, index: number, cleared: number): number?
	local item = Items.get(id) :: any
	if not item then
		return nil
	end
	if kind == "ammo" then
		local clears = IslandShop.AmmoClears[item.rarity] or IslandShop.AmmoClears.Legendary
		local level = firstLevel(ammoWorld(id)) - 1 + IslandShop.AmmoLevel
		local cost = nice(clears * Config.levelCoins(level))
		local forge = item.price
		if typeof(forge) == "table" and forge.currency == "coins" then
			cost = math.min(cost, forge.cost)
		end
		return cost
	elseif kind == "powerup" then
		local clears = IslandShop.PowerupClears[item.rarity] or IslandShop.PowerupClears.Epic
		return nice(clears * Config.levelCoins(buyerLevel(index, cleared)))
	elseif kind == "chest" then
		return nice(IslandShop.ChestClears * Config.levelCoins(buyerLevel(index, cleared)))
	elseif kind == "key" then
		return IslandShop.Key.gems
	end
	return nil
end

-- Whether a row is sold out for today. `bought` is what the server keeps and publishes for the day:
-- { day, ammo = { [ammo id] = true }, powerups = { [island as a string] = true }, chest = boolean,
--   keys = how many keys }.
-- A table for another day counts as empty.
function IslandShop.soldOut(kind: string, id: string, index: number, bought, day: number): boolean
	if typeof(bought) ~= "table" or bought.day ~= day then
		return false
	end
	if kind == "ammo" then
		return typeof(bought.ammo) == "table" and bought.ammo[id] == true
	elseif kind == "powerup" then
		return typeof(bought.powerups) == "table" and bought.powerups[tostring(index)] == true
	elseif kind == "key" then
		return typeof(bought.keys) == "number" and bought.keys >= IslandShop.Key.perDay
	end
	return bought.chest == true
end

return IslandShop
