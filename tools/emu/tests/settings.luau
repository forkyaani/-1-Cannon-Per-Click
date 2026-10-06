-- The SETTINGS window (run with --all-features): the music and sound switches start on, a press turns the
-- mixer down at once and is kept in the save, and a key the game does not know changes nothing.
local T = harness.load("_prelude.luau")
local Game = T.Game
local player, data = T.player, T.data
local check, eq = T.check, T.eq
local Http = game:GetService("HttpService")

local function shown()
	return Http:JSONDecode(player:GetAttribute("Meta_settings"))
end

T.section("a new player hears everything")
eq(shown().music, true, "music is on")
eq(shown().sound, true, "sounds are on")

T.section("the server keeps a switch")
Game.actions.settingToggle(player, data, nil, "music")
eq(data.features.settings.music, false, "music off is in the save")
eq(shown().music, false, "and the client is told")
eq(shown().sound, true, "sounds are untouched")
Game.actions.settingToggle(player, data, nil, "volume")
Game.actions.settingToggle(player, data, nil, 7)
eq(data.features.settings.volume, nil, "an unknown switch is not saved")

T.section("the window")
harness.runClient()
local UI = require(player.PlayerScripts.Client.UI)
eq(UI.SoundGroups.music.Volume, 0, "the music mixer is down when the client starts")
eq(UI.SoundGroups.sound.Volume, 1, "the sound mixer is up")
check(player.PlayerGui:FindFirstChild("SETTINGS", true) ~= nil, "the SETTINGS window exists")
Game.actions.settingToggle(player, data, nil, "music")
Game.actions.settingToggle(player, data, nil, "sound")
harness.flush()
eq(UI.SoundGroups.music.Volume, 1, "music back on")
eq(UI.SoundGroups.sound.Volume, 0, "sounds off")

check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
