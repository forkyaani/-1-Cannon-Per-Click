-- Trading rules both sides read: the limits (the server enforces them, the client shows them) and what can be
-- traded at all. The server half is src/server/Features/Trading.luau, the window src/client/Features/Trading.luau.
-- An offer, one player's side of a trade, is
-- { pets = { [mini cannon id] = count }, items = { [item id] = count }, gems = whole number }.
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
Trading.MaxGems = 1_000_000_000 -- gems on one side of a trade (and never more than the player holds)
Trading.ReadyLockSeconds = 3 -- after any change to an offer, before READY can be pressed
Trading.CountdownSeconds = 5 -- from both ready to the swap
Trading.CooldownSeconds = 10 -- after a finished trade, before the next one
Trading.HistorySize = 20 -- finished trades remembered per player

-- kind is "pets" or "items": the two halves of an offer. Looked up when asked, so mini cannons and items that
-- other features define later count too. Coins and candy are neither, so they can never be offered; gems are
-- not a kind either: an offer carries them as one number (offer.gems), checked with Trading.gemAmount.
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

-- The gems in an offer. A trade in the history from before gems could be traded has none.
function Trading.gems(offer): number
	local gems = offer and offer.gems
	return if typeof(gems) == "number" then gems else 0
end

-- Whether nothing at all is on this side of the table.
function Trading.empty(offer): boolean
	return Trading.stacks(offer) == 0 and Trading.gems(offer) == 0
end

-- The amount of gems a client asked to offer, or nil when it is not one: only a whole number from 0 to
-- MaxGems is. (NaN fails every comparison and infinity the upper one, so both are turned away.)
function Trading.gemAmount(value: unknown): number?
	if typeof(value) ~= "number" or not (value >= 0 and value <= Trading.MaxGems) or value % 1 ~= 0 then
		return nil
	end
	return value
end

-- "1,250 gems": written out in full wherever a trade shows them, so 1,000 and 10,000 are never mistaken.
function Trading.gemText(gems: number): string
	local digits = string.format("%d", gems)
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then
		grouped = string.sub(grouped, 2)
	end
	return `{grouped} {if gems == 1 then "gem" else "gems"}`
end

return Trading
