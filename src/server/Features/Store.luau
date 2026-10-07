-- The STORE, server half: gem packs (Robux developer products) and items for gems. The catalogue is the
-- shared module (src/shared/Features/Store.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)
local Store = require(ReplicatedStorage.Shared.Features.Store)
local Policy = require(script.Parent.Parent.Policy)

local SAVED = { packs = 0 } -- how many gem packs the player has ever bought

local Feature = {}

function Feature.start(Game)
	local function publish(player: Player, data)
		Game.setMeta(player, "store", { packs = Game.feature(data, "store", SAVED).packs })
	end

	for _, pack in Store.GemPacks do
		if pack.product ~= 0 then
			-- A purchase that was made is always granted.
			Game.products[pack.product] = function(player: Player): boolean
				local data = Game.data(player)
				if not data then
					return false -- the save is not loaded: Roblox asks again later
				end
				local saved = Game.feature(data, "store", SAVED)
				local gems = Store.gemsFor(pack, saved.packs)
				saved.packs += 1
				data.diamonds += gems
				publish(player, data)
				Game.notify(player, `+{Format.abbreviate(gems)} gems! Thank you`, "good")
				return true
			end
		end
	end

	-- argument: a gem pack's id. Gems buy random items (eggs, crates, enchantments), so a pack is not sold
	-- where paid random items are restricted, as the x3 Luck pass is not.
	Game.actions.storeBuyPack = function(player: Player, _data, _state, argument: unknown)
		local pack = Store.pack(argument)
		if not pack then
			return
		end
		if pack.product == 0 then
			Game.notify(player, "Gem packs are not on sale yet", "info")
			return
		end
		local ok, why, kind = Policy.maySell(player, pack.name)
		if not ok then
			Game.notify(player, why, kind)
			return
		end
		Game.promptProduct(player, pack.product)
	end

	-- argument: an item row's id. Paid in gems, given to the backpack.
	Game.actions.storeBuyItem = function(player: Player, data, _state, argument: unknown)
		local row = Store.item(argument)
		local item = row and Items.get(row.item) :: any
		if not row or not item then
			return
		end
		if data.diamonds < row.gems then
			Game.notify(player, `Not enough gems for {item.name} ({Format.abbreviate(row.gems)} 💎)`, "bad")
			return
		end
		data.diamonds -= row.gems
		Game.items.give(player, row.item, row.amount)
		Game.notify(player, `Bought {if row.amount > 1 then `{row.amount} x ` else ""}{item.name}! It is in your BACKPACK`, "good")
	end

	Game.on("ready", function(player: Player, data)
		publish(player, data)
	end)
end

return Feature
