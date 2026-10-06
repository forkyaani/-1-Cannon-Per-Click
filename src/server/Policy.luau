-- Paid random items: who may be sold one. Roblox does not allow them to be sold to players in some regions
-- (or under some ages) and says which through PolicyService. A random result paid for with Robux, or with a
-- currency Robux can buy (Config.PaidCurrencies), is one: a gem egg, a gem or Robux crate, an enchant roll.
-- So is something bought to change the odds (the x3 Luck pass). This is the one place that asks: the eggs and
-- the passes (Game.luau), Features/Crates.luau and Features/Enchant.luau all read the answer here.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")

local Policy = {}

local restricted = {} -- [player] = whether they may not buy paid random items; nil until Roblox has answered
local asking = {} -- [player] = true while the question is on its way
local changed = Instance.new("BindableEvent")

-- Fires with the player when Roblox has answered for them.
Policy.changed = changed.Event

-- true: may not be sold a paid random item. false: may. nil: Roblox has not answered (not yet, or the lookup
-- failed). Only false is a yes: in a live game no answer means no sale.
function Policy.restricted(player: Player): boolean?
	return restricted[player]
end

-- Asks Roblox about the player. The answer is remembered while they stay, so this asks once. It does not
-- yield. Call it when they join, and again whenever a sale had to be refused for want of an answer.
function Policy.ask(player: Player)
	if asking[player] or restricted[player] ~= nil then
		return
	end
	asking[player] = true
	task.spawn(function()
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		asking[player] = nil
		if not player.Parent then
			return
		end
		if ok and typeof(info) == "table" then
			restricted[player] = info.ArePaidRandomItemsRestricted == true
		elseif RunService:IsStudio() then
			-- Only a play test may go on without an answer.
			restricted[player] = false
		else
			warn(`[Policy] lookup failed for {player.Name}: {info}`)
			return
		end
		changed:Fire(player)
	end)
end

-- Whether a paid random item may be sold to the player right now. When it may not, the second and third
-- results are the toast to show. `what` starts it: "The Gem Egg" gives "The Gem Egg cannot be sold in your
-- region" (`verb` replaces "sold"). With no answer yet it asks again rather than guess.
function Policy.maySell(player: Player, what: string, verb: string?): (boolean, string?, string?)
	local answer = restricted[player]
	if answer == false then
		return true
	end
	local offered = verb or "sold"
	if answer then
		return false, `{what} cannot be {offered} in your region`, "bad"
	end
	Policy.ask(player)
	local lower = string.lower(string.sub(what, 1, 1)) .. string.sub(what, 2)
	return false, `Still checking whether {lower} can be {offered} in your region. Try again in a moment`, "info"
end

Players.PlayerRemoving:Connect(function(player: Player)
	restricted[player], asking[player] = nil, nil
end)

return Policy
