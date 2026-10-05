-- Trading rules both sides read: the limits (the server enforces them, the client shows them) and what can be
-- traded at all. The server half is src/server/Features/Trading.luau, the window src/client/Features/Trading.luau.
-- An offer, one player's side of a trade, is { pets = { [mini cannon id] = count }, items = { [item id] = count } }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

local Trading = {}

Trading.RequestSeconds = 20 -- a request nobody answers goes away
Trading.RequestGapSeconds = 3 -- between two requests from the same player
Trading.DeclinedSeconds = 30 -- after a request ran out, before the same player can be asked again
Trading.MaxIncoming = 5 -- requests one player can have waiting
Trading.MaxStacks = 8 -- different things on one side of a trade
Trading.MaxPets = 30 -- mini cannons on one side of a trade
Trading.MaxItemCount = 1_000 -- of one item on one side of a trade
Trading.ReadyLockSeconds = 3 -- after any change to an offer, before READY can be pressed
Trading.CountdownSeconds = 5 -- from both ready to the swap
Trading.CooldownSeconds = 10 -- after a finished trade, before the next one
Trading.HistorySize = 20 -- finished trades remembered per player

-- kind is "pets" or "items": the two halves of an offer. Looked up when asked, so mini cannons and items that
-- other features define later count too. Currencies are neither, so they can never be offered.
function Trading.canTrade(kind: string, id: string): boolean
	if kind == "pets" then
		local pet = Config.Pets[id]
		if not pet or pet.tradable == false then
			return false
		end
		-- A fused mini cannon is only as tradable as the one it was fused from: fusing must not be a way
		-- around tradable = false, which is set on the unfused one.
		local base = Config.Pets[pet.base]
		return base == nil or base.tradable ~= false
	end
	local item = Items.get(id)
	return item ~= nil and item.tradable == true
end

-- How many things a { [id] = count } table holds in all.
function Trading.total(counts: { [string]: number }): number
	local total = 0
	for _, count in counts do
		total += count
	end
	return total
end

-- How many different things an offer holds.
function Trading.stacks(offer): number
	local stacks = 0
	for _ in offer.pets do
		stacks += 1
	end
	for _ in offer.items do
		stacks += 1
	end
	return stacks
end

return Trading
