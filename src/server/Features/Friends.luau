-- Friend bonus: every Roblox friend on the same server adds Gifts.FRIEND_COINS to the coins a player earns, up
-- to Gifts.FRIEND_MAX friends (src/shared/Features/Gifts.luau). Who is whose friend is asked of Roblox when
-- somebody joins, and kept: nothing is asked while the game runs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gifts = require(ReplicatedStorage.Shared.Features.Gifts)

local Feature = {}

-- Whether two players are friends, as Roblox says. A test puts its own answer here.
function Feature.areFriends(a: Player, b: Player): boolean
	local ok, yes = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	return ok and yes == true
end

function Feature.start(Game)
	local friends = {} -- [player] = { [other player] = true }

	local function countOf(player: Player): number
		local n = 0
		for other in friends[player] or {} do
			if other.Parent == Players then
				n += 1
			end
		end
		return math.min(n, Gifts.FRIEND_MAX)
	end
	Feature.count = countOf

	local function tell(player: Player)
		if Game.data(player) then
			Game.setMeta(player, "friends", { count = countOf(player), each = Gifts.FRIEND_COINS, max = Gifts.FRIEND_MAX })
		end
	end

	Game.modify("coins", function(player: Player, _data, _state, value: number): number
		local n = countOf(player)
		return if n > 0 then value * (1 + n * Gifts.FRIEND_COINS) else value
	end, "Friend bonus")

	Game.on("ready", function(player: Player)
		friends[player] = friends[player] or {}
		tell(player)
		-- Asked off the join's own thread: Roblox can take its time, and a failed answer is simply "no".
		task.spawn(function()
			for _, other in Players:GetPlayers() do
				if other ~= player and friends[other] and Feature.areFriends(player, other) then
					if not friends[player] then
						return -- left while Roblox was answering
					end
					local first = countOf(player) == 0
					friends[player][other] = true
					friends[other][player] = true
					tell(other)
					if first then
						local percent = math.floor(Gifts.FRIEND_COINS * 100 + 0.5)
						Game.notify(player, `Friend bonus! +{percent}% coins for every friend playing with you`, "good")
					end
					Game.notify(other, `{player.DisplayName} joined: your friend bonus went up!`, "good")
				end
			end
			tell(player)
		end)
	end)
	Game.on("leave", function(player: Player)
		local mine = friends[player]
		friends[player] = nil
		for other in mine or {} do
			if friends[other] then
				friends[other][player] = nil
				tell(other)
			end
		end
	end)
end

return Feature
