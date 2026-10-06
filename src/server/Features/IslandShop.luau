-- The island shops, server half: the `islandBuy` action. What each island sells, for how much and how often
-- is in the shared module (src/shared/Features/IslandShop.luau); this file checks and sells.
-- The stalls themselves are built with the islands (src/server/Islands.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)
local Shop = require(ReplicatedStorage.Shared.Features.IslandShop)

-- This feature's saved table: what was bought on UTC day `day`.
--   ammo       [ammo id] = true            powerups   [island, as a string] = true (JSON has no number keys)
--   chest      the day's Boss Chest is bought      keys   Enchantment Keys bought that day
local SAVED = { day = 0, ammo = {}, powerups = {}, chest = false, keys = 0 }

local KINDS = {}
for _, kind in Shop.ROWS do
	KINDS[kind] = true
end

local Feature = {}

function Feature.start(Game)
	-- The saved table, emptied once the UTC day has rolled over. Also returns the day.
	local function today(data)
		local saved = Game.feature(data, "islandShop", SAVED)
		local day = Config.dayNumber(os.time())
		if saved.day ~= day or typeof(saved.ammo) ~= "table" or typeof(saved.powerups) ~= "table" then
			saved.day, saved.ammo, saved.powerups, saved.chest, saved.keys = day, {}, {}, false, 0
		end
		if typeof(saved.keys) ~= "number" or saved.keys ~= saved.keys then
			saved.keys = 0
		end
		return saved, day
	end

	local published = {} -- [player] = the day their client was last told about

	local function publish(player: Player, data)
		local saved, day = today(data)
		published[player] = day
		Game.setMeta(player, "islandShop", {
			day = saved.day,
			ammo = saved.ammo,
			powerups = saved.powerups,
			chest = saved.chest,
			keys = saved.keys,
		})
	end

	-- argument: { island = world index, kind = "ammo" | "powerup" | "chest" | "key" }. The player must be standing on
	-- that island; what the row holds and what it costs are worked out here, never taken from the client.
	Game.actions.islandBuy = function(player: Player, data, state, argument: unknown)
		if typeof(argument) ~= "table" then
			return
		end
		local index, kind = (argument :: any).island, (argument :: any).kind
		if typeof(index) ~= "number" or index % 1 ~= 0 or not Config.Worlds[index] or typeof(kind) ~= "string" or not KINDS[kind] then
			return
		end
		if state.place ~= "island" or state.island ~= index or not Config.worldUnlocked(index, data.bestCleared) then
			Game.notify(player, "Visit that island's shop to buy from it", "bad")
			return
		end
		local saved, day = today(data)
		local id = Shop.stock(index, day)[kind]
		local item = id and Items.get(id)
		local cost = id and Shop.price(kind, id, index, data.cleared)
		if not id or not item or typeof(cost) ~= "number" or cost ~= cost or cost < 1 then
			Game.notify(player, "The shop has none of that today", "info")
			return
		end
		if kind == "ammo" and Game.items.count(data, id) > 0 then
			Game.notify(player, `You already own {item.name}`, "info")
			return
		end
		if Shop.soldOut(kind, id, index, saved, day) then
			Game.notify(player, "Sold out for today. New stock tomorrow", "bad")
			return
		end
		-- Coins, or gems for the key: the currency is the save's own field.
		local currency = Shop.currency(kind)
		if data[currency] < cost then
			local icon = if currency == "diamonds" then "💎" else "💰"
			Game.notify(player, `Not enough {Config.CurrencyNames[currency]} for {item.name} ({Format.abbreviate(cost)} {icon})`, "bad")
			return
		end
		data[currency] -= cost
		if kind == "ammo" then
			saved.ammo[id] = true
		elseif kind == "powerup" then
			saved.powerups[tostring(index)] = true
		elseif kind == "chest" then
			saved.chest = true
		end
		Game.items.give(player, id, 1)
		publish(player, data)
		local how = if kind == "ammo"
			then "Load it in the AMMO window"
			elseif kind == "key" or kind == "shiny" then "Use it at the Enchanting Table"
			else "It is in your BACKPACK"
		Game.notify(player, `Bought {item.name}! {how}`, "good")
	end

	Game.on("ready", function(player: Player, data)
		publish(player, data)
	end)

	-- New stock at midnight UTC: tell the clients of the players who are online then.
	Game.on("tick", function(player: Player, data)
		if published[player] ~= Config.dayNumber(os.time()) then
			publish(player, data)
		end
	end)

	Game.on("leave", function(player: Player)
		published[player] = nil
	end)
end

return Feature
