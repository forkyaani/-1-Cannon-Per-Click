-- Badges: a Roblox badge for the first hatch, the first boss, the first world and the first rebirth
-- (Gifts.Badges in src/shared/Features/Gifts.luau). A badge whose id is still 0 is not awarded, and a save
-- remembers what it was given, so Roblox is asked once a badge and never in the middle of a fight twice.
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gifts = require(ReplicatedStorage.Shared.Features.Gifts)

local Feature = {}

-- Gives the badge on Roblox. True when Roblox took it. A test puts its own here.
function Feature.award(player: Player, id: number): boolean
	local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
	if not ok then
		warn(`[Badges] could not award {id} to {player.Name}: {err}`)
	end
	return ok
end

function Feature.start(Game)
	local function give(player: Player, data, key: string)
		local badge = Gifts.Badges[key]
		local save = Game.feature(data, "badges", { given = {} })
		if typeof(save.given) ~= "table" then
			save.given = {}
		end
		if not badge or badge.id == 0 or save.given[key] then
			return
		end
		save.given[key] = true
		task.spawn(function()
			if not Feature.award(player, badge.id) then
				save.given[key] = nil -- Roblox did not take it: try again at the next chance
			end
		end)
	end

	-- What a save has already earned: a player from before the badges gets them on the next join.
	local function catchUp(player: Player, data)
		if (data.totalHatches or 0) > 0 then
			give(player, data, "hatch")
		end
		if (data.bestCleared or 0) >= Config.BossEvery then
			give(player, data, "boss")
		end
		if (data.bestCleared or 0) >= Config.WavesPerWorld then
			give(player, data, "world")
		end
		if (data.rebirths or 0) > 0 then
			give(player, data, "rebirth")
		end
	end

	Game.on("ready", catchUp)
	Game.on("hatch", function(player: Player, data)
		give(player, data, "hatch")
	end)
	Game.on("waveCleared", function(player: Player, data)
		catchUp(player, data)
	end)
	Game.on("rebirth", function(player: Player, data)
		give(player, data, "rebirth")
	end)
end

return Feature
