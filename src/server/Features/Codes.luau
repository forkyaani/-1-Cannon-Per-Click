-- Redeem codes, server half: the `redeemCode` action. The client sends the text the player typed and nothing
-- else; the code, its reward and whether it is still good are all looked up here
-- (src/shared/Features/Codes.luau has the list). A code pays a player once: the save remembers it.
-- Every try is answered with a toast, and tries are spaced Codes.COOLDOWN apart so codes cannot be guessed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)
local Codes = require(ReplicatedStorage.Shared.Features.Codes)

local Feature = {}

-- A reward's number as something that can be paid: a whole number of at least 1, or nil.
local function whole(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value < 1 or value == math.huge then
		return nil
	end
	return math.floor(value)
end

function Feature.start(Game)
	local lastTry: { [Player]: number } = {} -- os.clock of each player's last try

	-- What a code pays this player right now, or nil when its line in the list is wrong (an item that does
	-- not exist, nothing to pay): such a code is refused rather than used up for nothing.
	local function resolve(data, def)
		local reward = { gems = whole(def.gems) or 0, coins = 0, item = nil :: string?, amount = 0 }
		if typeof(def.clears) == "number" and def.clears > 0 then
			reward.coins = math.floor(def.clears * Config.levelCoins(math.max(1, data.bestCleared)))
		end
		if def.item ~= nil then
			if typeof(def.item) ~= "string" or not Items.get(def.item) then
				return nil
			end
			reward.item, reward.amount = def.item, whole(def.amount) or 1
		end
		local total = data.coins + reward.coins
		if total ~= total or total == math.huge then
			return nil
		end
		if reward.gems == 0 and reward.coins == 0 and not reward.item then
			return nil
		end
		return reward
	end

	local function describe(reward): string
		local parts = {}
		if reward.gems > 0 then
			table.insert(parts, `+{Format.abbreviate(reward.gems)} gems`)
		end
		if reward.coins > 0 then
			table.insert(parts, `+{Format.abbreviate(reward.coins)} coins`)
		end
		if reward.item then
			table.insert(parts, `+{reward.amount} {Items.get(reward.item).name}`)
		end
		return table.concat(parts, ", ")
	end

	-- REDEEM in the CODES window. The argument is what the player typed.
	Game.actions.redeemCode = function(player: Player, data, _state, text)
		local now = os.clock()
		if lastTry[player] and now - lastTry[player] < Codes.COOLDOWN then
			Game.notify(player, "Slow down: wait a moment before trying another code", "bad")
			return
		end
		lastTry[player] = now

		local code = Codes.normalise(text)
		local def = code and Codes.List[code]
		if not code or typeof(def) ~= "table" then
			Game.notify(player, "That code does not exist", "bad")
			return
		end
		local saved = Game.feature(data, "codes", Codes.SAVED)
		if typeof(saved.used) ~= "table" then
			saved.used = {}
		end
		if saved.used[code] then
			Game.notify(player, `You have already used the code {code}`, "bad")
			return
		end
		if Codes.expired(def, os.time()) then
			Game.notify(player, `The code {code} has expired`, "bad")
			return
		end
		local reward = resolve(data, def)
		if not reward then
			warn(`[Codes] the code {code} has no reward that can be paid`)
			Game.notify(player, `The code {code} cannot be redeemed right now`, "bad")
			return
		end

		-- Used first, paid after: whatever goes wrong below, the code cannot pay twice.
		saved.used[code] = os.time()
		data.diamonds += reward.gems
		data.coins += reward.coins
		if reward.item then
			Game.items.give(player, reward.item, reward.amount)
		end
		Game.notify(player, `Code {code} redeemed! {describe(reward)}`, "good")
	end

	Game.on("leave", function(player: Player)
		lastTry[player] = nil
	end)
end

return Feature
