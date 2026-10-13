-- The player's own settings, both sides: what is saved and what each switch is called.
-- The server half is src/server/Features/Settings.luau (it saves them), the window src/client/Features/Settings.luau.
local Settings = {}

Settings.WINDOW = "SETTINGS" -- the window, and its menu button

-- The save's defaults: a new player hears everything, and their base can be visited.
Settings.SAVED = { sound = true, music = true, visitors = true }

-- The switches in the order the window shows them. `key` is the saved field and, for the two sound switches,
-- the mixer of UI.SoundGroups. `visitors` is read by the Visit feature (src/server/Features/Visit.luau).
Settings.Switches = {
	{ key = "music", title = "Music", sub = "The tune of your base, the marketplace and the islands" },
	{ key = "sound", title = "Sounds", sub = "Buttons, monsters, bosses, eggs and crates" },
	{ key = "visitors", title = "Visitors", sub = "Other players can visit your base. Off: only players you invite" },
}

return Settings
