-- The STORE's catalogue: gem packs for Robux, and items for gems. Gems are the game's main currency: Robux
-- buys gems, gems buy things. (The game passes are Config.Passes; the window shows them in a third tab.)
-- The server sells from these tables (src/server/Features/Store.luau); the window reads them
-- (src/client/Windows.luau).
local Store = {}

-- product is the developer product's id from the Creator Hub, in the group's experience: 0 means not created
-- yet, and the pack is shown but cannot be bought. The first pack a player ever buys gives double.
Store.GemPacks = {
	{ id = "gems1", name = "Handful of Gems", gems = 250, robux = 49, product = 0 },
	{ id = "gems2", name = "Pouch of Gems", gems = 700, robux = 129, product = 0 },
	{ id = "gems3", name = "Bag of Gems", gems = 1_500, robux = 249, product = 0 },
	{ id = "gems4", name = "Chest of Gems", gems = 3_500, robux = 499, product = 0 },
	{ id = "gems5", name = "Vault of Gems", gems = 8_000, robux = 999, product = 0 },
	{ id = "gems6", name = "Mountain of Gems", gems = 21_000, robux = 2_499, product = 0 },
}
Store.FIRST_PACK_MULTIPLIER = 2

-- Backpack items for gems, as many as the player likes. item is the id of a feature's item (Items.get);
-- amount is how many one purchase gives.
Store.Items = {
	{ id = "key", item = "enchantkey", amount = 1, gems = 50, note = "Use it at the Enchanting Table on The Sun's island" },
	{ id = "shinykey", item = "shinykey", amount = 1, gems = 1_000, note = "3 enchantments, at least two of them level III" },
	{ id = "chest", item = "bosschest", amount = 1, gems = 100, note = "Open it from your BACKPACK" },
	{ id = "power", item = "power2x", amount = 6, gems = 30, note = "6 x 5 minutes of double damage" },
	{ id = "coins", item = "coins2x", amount = 6, gems = 30, note = "6 x 5 minutes of double coins" },
}

function Store.pack(id: unknown)
	for _, pack in Store.GemPacks do
		if pack.id == id then
			return pack
		end
	end
	return nil
end

function Store.item(id: unknown)
	for _, item in Store.Items do
		if item.id == id then
			return item
		end
	end
	return nil
end

-- What a pack gives a player who has bought `bought` packs before.
function Store.gemsFor(pack, bought: number): number
	return pack.gems * (if bought < 1 then Store.FIRST_PACK_MULTIPLIER else 1)
end

return Store
