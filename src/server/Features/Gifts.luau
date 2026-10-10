-- Playtime gifts, server half: counts the seconds a player is in the game today and pays a gift for each step
-- of Gifts.List when the player claims it (src/shared/Features/Gifts.luau, window src/client/Features/Gifts.luau).
-- The count is in the save, so leaving and coming back the same day carries on; a new UTC day starts it again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Gifts = require(Shared.Features.Gifts)

local SAVE_SECONDS = 20 -- how often the running count is written into the save

local Feature = {}

function Feature.start(Game)
	-- [player] = { since = os.clock() the count was last written, told = how many gifts they were told are ready }
	local sessions = {}

	local function saved(data)
		local save = Game.feature(data, "gifts", Gifts.SAVED)
		if typeof(save.claimed) ~= "table" then
			save.claimed = {}
		end
		save.seconds = math.max(0, tonumber(save.seconds) or 0)
		local today = Config.dayNumber(os.time())
		if save.day ~= today then
			save.day, save.seconds, save.claimed = today, 0, {}
		end
		return save
	end

	-- Brings the save's count up to now.
	local function count(player: Player, data)
		local save = saved(data)
		local session = sessions[player]
		if session then
			local now = os.clock()
			save.seconds += math.max(0, now - session.since)
			session.since = now
		end
		return save
	end

	local function ready(save): number
		local n = 0
		for index, gift in Gifts.List do
			if save.seconds >= gift.minutes * 60 and not save.claimed[tostring(index)] then
				n += 1
			end
		end
		return n
	end

	local function publish(player: Player, data)
		local save = count(player, data)
		-- The client counts on from `at`: nothing is sent every second.
		Game.setMeta(player, "gifts", { seconds = math.floor(save.seconds), at = workspace:GetServerTimeNow(), claimed = save.claimed })
	end

	Game.actions.giftClaim = function(player: Player, data, _state, index)
		if typeof(index) ~= "number" or index ~= math.floor(index) then
			return
		end
		local gift = Gifts.List[index]
		local save = count(player, data)
		if not gift or save.claimed[tostring(index)] then
			return
		end
		if save.seconds < gift.minutes * 60 then
			Game.notify(player, `Play {gift.minutes} minutes today for this gift`, "bad")
			return
		end
		save.claimed[tostring(index)] = true -- before the reward: a payment that failed half way is not paid twice
		data.diamonds += math.max(0, math.floor(tonumber(gift.gems) or 0))
		if gift.item and Items.get(gift.item) then
			Game.items.give(player, gift.item, 1)
		end
		local text = Gifts.rewardText(gift, function(id: string): string
			local def = Items.get(id)
			return if def then def.name else id
		end)
		Game.notify(player, `Playtime gift! {text}`, "good")
		local session = sessions[player]
		if session then
			session.told = ready(save)
		end
		publish(player, data)
	end

	Game.on("ready", function(player: Player, data)
		sessions[player] = { since = os.clock(), told = ready(saved(data)), written = os.clock() }
		publish(player, data)
	end)
	Game.on("tick", function(player: Player, data)
		local session = sessions[player]
		if not session then
			return
		end
		local day = Game.feature(data, "gifts", Gifts.SAVED).day
		local now = os.clock()
		if now - session.written < SAVE_SECONDS and day == Config.dayNumber(os.time()) then
			-- Between two writes, only look whether a gift has come due.
			local save = Game.feature(data, "gifts", Gifts.SAVED)
			local seconds = save.seconds + math.max(0, now - session.since)
			local due = 0
			for index, gift in Gifts.List do
				if seconds >= gift.minutes * 60 and not save.claimed[tostring(index)] then
					due += 1
				end
			end
			if due <= session.told then
				return
			end
		end
		session.written = now
		local save = count(player, data)
		local due = ready(save)
		if due > session.told then
			Game.notify(player, "A playtime gift is ready! Open GIFTS to claim it.", "good")
		end
		local changed = due ~= session.told or day ~= save.day
		session.told = due
		if changed then
			publish(player, data)
		end
	end)
	Game.on("leave", function(player: Player, data)
		if data and sessions[player] then
			count(player, data)
		end
		sessions[player] = nil
	end)
end

return Feature
