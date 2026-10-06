-- The player's own settings, both sides: what is saved and what each switch is called.
-- The server half is src/server/Features/Settings.luau (it saves them), the window src/client/Features/Settings.luau.
local Settings = {}

Settings.WINDOW = "SETTINGS" -- the window, and its menu button

-- The save's defaults: a new player hears everything.
Settings.SAVED = { sound = true, music = true }

-- The switches in the order the window shows them. `key` is the saved field and the mixer of UI.SoundGroups.
Settings.Switches = {
	{ key = "music", title = "Music", sub = "The tune of your base, the marketplace and the islands" },
	{ key = "sound", title = "Sounds", sub = "Buttons, monsters, bosses, eggs and crates" },
}

return Settings
