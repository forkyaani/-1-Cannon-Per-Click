-- The MINI CANNONS window's rules (docs/MINI_CANNON_REVAMP.md): which mini cannons are equipped when the
-- player picks them by hand, what may be deleted, and the loadouts. The server
-- (src/server/Features/Minis.luau) decides with these; the window (src/client/Features/Minis.luau) shows
-- the same answers before asking.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Minis = {}

Minis.WINDOW = "MINI CANNONS"
Minis.LOADOUTS = 3
Minis.STORAGE_WARN = 0.85 -- the storage bar turns orange from this share
Minis.DELETE_LIMIT = 2_000 -- mini cannons in one delete request: more than any storage holds
Minis.SORTS = { "damage", "rarity", "name", "count" }
Minis.RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Exclusive", "Secret", "Mythical" }

local RARITY_RANK = {}
for rank, name in Minis.RARITIES do
	RARITY_RANK[name] = rank
end

function Minis.rarityRank(pet): number
	return RARITY_RANK[pet.rarity] or 0
end

-- How many of each id are in a list.
function Minis.counts(ids: { string }): { [string]: number }
	local counts = {}
	for _, id in ids do
		counts[id] = (counts[id] or 0) + 1
	end
	return counts
end

-- The mini cannons that are equipped when the player has picked by hand: every pick they still own, in the
-- order picked, `slots` at most and one of each Huge at most. A pick that is gone (fused, enchanted, traded,
-- deleted) is replaced by another of the same kind and tier if one is free, else dropped.
function Minis.resolve(owned: { string }, picks: { string }, slots: number): { string }
	local free = Minis.counts(owned)
	local result, huges = {}, {}
	for _, pick in picks do
		if #result >= slots then
			break
		end
		local pet = if typeof(pick) == "string" then Config.Pets[pick] else nil
		if not pet then
			continue
		end
		local id: string? = if (free[pick] or 0) > 0 then pick else nil
		if not id then
			-- The same kind and tier with other enchantments, the best enchanted first.
			for other, count in free do
				local twin = Config.Pets[other]
				if count > 0 and twin and twin.plain == pet.plain then
					local best = id and Config.Pets[id]
					if not best or (twin.enchantScore or 0) > (best.enchantScore or 0) or ((twin.enchantScore or 0) == (best.enchantScore or 0) and other < (id :: string)) then
						id = other
					end
				end
			end
		end
		if id then
			local chosen = Config.Pets[id]
			if chosen.huge then
				if huges[chosen.plain] then
					continue
				end
				huges[chosen.plain] = true
			end
			free[id] -= 1
			table.insert(result, id)
		end
	end
	return result
end

-- Whether one more `id` can be equipped: nil, or why not. `equipped` is what is equipped now.
function Minis.cannotEquip(owned: { string }, equipped: { string }, slots: number, id: string): string?
	local pet = Config.Pets[id]
	if not pet then
		return "No such mini cannon"
	end
	local have, worn = Minis.counts(owned)[id] or 0, Minis.counts(equipped)[id] or 0
	if have <= worn then
		return if have == 0 then "You do not own that mini cannon" else "All of those are equipped already"
	end
	if pet.huge then
		for _, other in equipped do
			if Config.Pets[other].plain == pet.plain then
				return "One of each Huge at most"
			end
		end
	end
	if #equipped >= slots then
		return "No free slot: unequip one first"
	end
	return nil
end

-- Whether deleting this one takes a second press: the ones a player would cry over.
function Minis.precious(id: string): boolean
	local pet = Config.Pets[id]
	return pet ~= nil and (pet.huge == true or pet.hidden == true or pet.enchanted == true or (pet.tier or 0) >= 2)
end

-- A delete request checked: `wanted` is { [id] = how many }. Returns the clean request and its total, or nil
-- and why not. Locked kinds are refused, and so is asking for more than is owned.
function Minis.checkDelete(owned: { string }, locked: { [string]: boolean }, wanted: unknown): ({ [string]: number }?, number | string)
	if typeof(wanted) ~= "table" then
		return nil, "Nothing to delete"
	end
	local have = Minis.counts(owned)
	local clean, total = {}, 0
	for id, amount in wanted :: any do
		if typeof(id) ~= "string" or typeof(amount) ~= "number" or amount % 1 ~= 0 or amount < 1 or not Config.Pets[id] then
			return nil, "Nothing to delete"
		end
		if locked[id] then
			return nil, `{Config.Pets[id].name} is locked`
		end
		if (have[id] or 0) < amount then
			return nil, "You do not own that many"
		end
		clean[id] = amount
		total += amount
	end
	if total < 1 or total > Minis.DELETE_LIMIT then
		return nil, "Nothing to delete"
	end
	return clean, total
end

return Minis
