-- Registry of stackable items a player can hold in their backpack: powerups, ammo, crates and so on.
-- A feature defines its items in its own shared module (src/shared/Features); the server keeps how many a
-- player has in data.items[id], and the client reads the counts from State.feature("items").
local Items = {}

export type Item = {
	id: string,
	name: string,
	desc: string,
	category: string, -- groups items in the backpack, e.g. "powerup", "ammo", "crate"
	color: Color3,
	rarity: string?, -- a key of Config.RarityColors, when the item has a rarity
	usable: boolean?, -- shows a USE button in the backpack (the server decides what using it does)
	tradable: boolean?,
	order: number?, -- position inside its category, low first
}

local defs: { [string]: Item } = {}

function Items.define(id: string, def): Item
	assert(not defs[id], "duplicate item " .. id)
	def.id = id
	defs[id] = def
	return def
end

function Items.get(id: string): Item?
	return defs[id]
end

function Items.all(): { [string]: Item }
	return defs
end

return Items
