-- Fusing: three mini cannons of the same kind and tier make one of the next tier, at the Fusion Machine on
-- The Sun's island (docs/BUILD_QUEUE.md, section 5). The tiers and what each gives are Config.FuseTiers; this
-- file holds the rules of one fusion. The server half (src/server/Features/Fuse.luau) checks a request with
-- the same functions the FUSE window (src/client/Features/Fuse.luau) offers picks with.
--
-- The player picks the three themselves. Enchanted ones can be picked: the result keeps the enchantments of
-- the first pick, and those of the other two are lost.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Fuse = {}

Fuse.WINDOW = "FUSE"
Fuse.ISLAND = Config.FuseIsland -- the world whose island has the machine; fusing opens when it is reached
Fuse.COUNT = Config.FuseCount

-- Whether the player has reached the machine's world. It reads the highest level ever, so it stays open
-- after a rebirth.
function Fuse.unlocked(bestCleared: number): boolean
	return Config.worldUnlocked(Fuse.ISLAND, bestCleared)
end

-- Whether a mini cannon can go into the machine at all: a Huge and a top tier one cannot.
function Fuse.fusable(petId: string): boolean
	local pet = Config.Pets[petId]
	return pet ~= nil and not pet.huge and pet.next ~= nil
end

-- Whether two mini cannons are the same kind and tier, whatever their enchantments.
function Fuse.matches(a: string, b: string): boolean
	local petA, petB = Config.Pets[a], Config.Pets[b]
	return petA ~= nil and petB ~= nil and petA.plain == petB.plain
end

-- What fusing these picks makes: the id of the result, or nil and why not. picks is a list of mini cannon
-- ids in the order they were picked. Owning them is the server's to check.
function Fuse.result(picks: { string }): (string?, string?)
	if typeof(picks) ~= "table" or #picks ~= Fuse.COUNT then
		return nil, `Pick {Fuse.COUNT} mini cannons`
	end
	local first = if typeof(picks[1]) == "string" then Config.Pets[picks[1]] else nil
	if not first then
		return nil, "Pick a mini cannon"
	end
	if first.huge then
		return nil, "A Huge cannot be fused"
	end
	if not first.next then
		return nil, `{Config.Pets[first.plain].name} is at the top tier already`
	end
	for index = 2, Fuse.COUNT do
		local id = picks[index]
		if typeof(id) ~= "string" or not Fuse.matches(picks[1], id) then
			return nil, "All three must be the same mini cannon and tier"
		end
	end
	-- The next tier of the plain mini cannon, with the first pick's enchantments.
	local result = Config.enchantedId(first.next, first.enchants)
	if not Config.Pets[result] then
		return nil, "That cannot be fused"
	end
	return result, nil
end

-- How many of the picks lose their enchantments: the enchanted ones after the first.
function Fuse.lost(picks: { string }): number
	local lost = 0
	for index = 2, #picks do
		local pet = Config.Pets[picks[index]]
		if pet and pet.enchanted then
			lost += 1
		end
	end
	return lost
end

-- The FILL button. counts is what the player owns ({ [mini cannon id] = count }), picks what is in the
-- machine so far (a list, in the order picked; it may be empty). Returns a full list of picks, or nil and
-- why not.
--   with picks   they stay, and the free slots are filled with mini cannons like the first that have no
--                enchantments
--   with none    three of the strongest mini cannon the player can fuse, none of them enchanted
-- It never picks an enchanted one by itself, so FILL can never lose an enchantment the player did not put in.
function Fuse.fill(counts: { [string]: number }, picks: { string }): ({ string }?, string?)
	local plainId: string? = nil
	if #picks > 0 then
		local first = Config.Pets[picks[1]]
		if not first or not Fuse.fusable(picks[1]) then
			return nil, "That mini cannon cannot be fused"
		end
		plainId = first.plain
	else
		-- The strongest plain mini cannon there are three of.
		for id, count in counts do
			local pet = Config.Pets[id]
			if pet and not pet.enchanted and Fuse.fusable(id) and typeof(count) == "number" and count >= Fuse.COUNT then
				local best = plainId and Config.Pets[plainId]
				if not best or pet.bonus > best.bonus or (pet.bonus == best.bonus and id < (plainId :: string)) then
					plainId = id
				end
			end
		end
		if not plainId then
			return nil, `Nothing to fill with: it takes {Fuse.COUNT} of the same mini cannon without enchantments`
		end
	end
	local kind = plainId :: string
	local filled = table.clone(picks)
	-- The plain ones already in the machine are not there to be picked again.
	local have = counts[kind] or 0
	for _, id in picks do
		if id == kind then
			have -= 1
		end
	end
	local need = Fuse.COUNT - #filled
	if have < need then
		return nil, `You need {need - math.max(0, have)} more {Config.Pets[kind].name} without enchantments`
	end
	for _ = 1, need do
		table.insert(filled, kind)
	end
	return filled, nil
end

return Fuse
