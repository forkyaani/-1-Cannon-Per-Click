-- The FIRE button, server half (src/shared/Features/Blast.luau has the numbers and why they are what they are).
-- The client sends its presses in small batches; this file decides how many of them count, deals their damage
-- to the lead monster of the player's own base, and sells the button's levels for coins or gems (`blastBuy`).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blast = require(ReplicatedStorage.Shared.Features.Blast)
local Format = require(ReplicatedStorage.Shared.Format)

local MAX_BATCH = 16 -- more presses than this in one message is not a thumb

local Feature = {}

function Feature.start(Game)
	local sessions = {} -- [player] = { allow = shots that may count now, at = os.clock() of that number }

	local function saved(data)
		local save = Game.feature(data, "blast", Blast.SAVED)
		save.level = math.clamp(math.floor(tonumber(save.level) or 0), 0, Blast.MAX_LEVEL)
		save.xp = nil -- levels were earned by pressing until 11 Oct 2026; they are bought now
		save.shots = math.max(0, math.floor(tonumber(save.shots) or 0))
		return save
	end

	local function publish(player: Player, data)
		local save = saved(data)
		Game.setMeta(player, "blast", { level = save.level, shots = save.shots })
	end

	-- Whether there is something to shoot at: the player's own base, a level being fought, a monster alive.
	local function hasTarget(state): boolean
		if state.place ~= "plot" or state.paused or state.phase ~= "fight" then
			return false
		end
		for _, monster in state.monsters do
			if not monster.dead then
				return true
			end
		end
		return false
	end

	Game.actions.blast = function(player: Player, data, state, count)
		local session = sessions[player]
		if not session or typeof(count) ~= "number" or count ~= math.floor(count) or count < 1 or count > MAX_BATCH then
			return
		end
		-- The allowance fills at RATE a second, up to BURST: presses beyond it are simply not counted.
		local now = os.clock()
		session.allow = math.min(Blast.BURST, session.allow + (now - session.at) * Blast.RATE)
		session.at = now
		local shots = math.min(count, math.floor(session.allow))
		if shots < 1 or not hasTarget(state) then
			return
		end
		session.allow -= shots
		local save = saved(data)
		-- The headline number the player sees: towers and mini cannons, with every boost (Game's sync).
		local dps = tonumber(player:GetAttribute("CannonPower")) or 0
		local damage = dps * Blast.share(save.level) * shots
		if damage == damage and damage > 0 and damage < math.huge then
			Game.damage(player, damage)
		end
		save.shots += shots
		publish(player, data)
	end

	-- argument: "coins" or "gems". The level and its price are worked out here, never taken from the client.
	Game.actions.blastBuy = function(player: Player, data, _state, argument: unknown)
		if argument ~= "coins" and argument ~= "gems" then
			return
		end
		local save = saved(data)
		if save.level >= Blast.MAX_LEVEL then
			Game.notify(player, "FIRE is at its last level", "info")
			return
		end
		local cost = Blast.cost(save.level + 1, argument)
		if typeof(cost) ~= "number" or cost ~= cost or cost < 1 or cost == math.huge then
			return
		end
		if argument == "coins" then
			if data.coins < cost then
				Game.notify(player, `Need {Format.abbreviate(cost - data.coins)} more coins for FIRE level {save.level + 1}`, "bad")
				return
			end
			data.coins -= cost
		else
			if data.diamonds < cost then
				Game.notify(player, `Not enough gems for FIRE level {save.level + 1} ({cost} 💎)`, "bad")
				return
			end
			data.diamonds -= cost
		end
		save.level += 1
		publish(player, data)
		Game.sync(player)
		Game.notify(player, `FIRE level {save.level}! Each shot now hits for {Blast.shareText(save.level)} of your damage per second`, "good")
	end

	Game.on("ready", function(player: Player, data)
		sessions[player] = { allow = Blast.BURST, at = os.clock() }
		publish(player, data)
	end)
	Game.on("leave", function(player: Player)
		sessions[player] = nil
	end)
end

return Feature
