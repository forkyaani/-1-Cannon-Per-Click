-- Settings, server half: the music and sound switches are kept in the save, so a player who turned the music
-- off does not hear it again on the next join or on another device. The client applies them
-- (src/client/Features/Settings.luau); nothing here changes the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Features.Settings)

local Feature = {}

function Feature.start(Game)
	local function publish(player: Player, data)
		local saved = Game.feature(data, "settings", Settings.SAVED)
		local shown = {}
		for key in Settings.SAVED do
			shown[key] = saved[key] ~= false
		end
		Game.setMeta(player, "settings", shown)
	end

	-- A press on a switch of the SETTINGS window. The argument is the switch's key; anything else is dropped.
	Game.actions.settingToggle = function(player: Player, data, _state, key)
		if typeof(key) ~= "string" or Settings.SAVED[key] == nil then
			return
		end
		local saved = Game.feature(data, "settings", Settings.SAVED)
		saved[key] = saved[key] == false
		publish(player, data)
	end

	Game.on("ready", function(player: Player, data)
		publish(player, data)
	end)
end

return Feature
