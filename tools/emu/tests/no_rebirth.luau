-- Rebirth is switched off for launch (Config.Rebirth.enabled = false; run with --all-features): nobody can
-- rebirth, nothing offers it, and the player list and the marketplace's second board show levels instead.
local T = harness.load("_prelude.luau")
local Game, Config = T.Game, T.Config
local player, data = T.player, T.data
local check, eq, act, run = T.check, T.eq, T.act, T.run

T.section("the switch")
eq(Config.Rebirth.enabled, false, "rebirth is off")

T.section("the player list")
local stats = player:FindFirstChild("leaderstats")
check(stats ~= nil and stats:FindFirstChild("Rebirths") == nil, "has no Rebirths column")
check(stats:FindFirstChild("Level") ~= nil and stats:FindFirstChild("Gems") ~= nil and stats:FindFirstChild("Cannon Power") ~= nil, "it shows Gems, Level and Cannon Power")

T.section("a player who has beaten Earth")
T.debug("wave", Config.WavesPerWorld + 1)
data.cleared = Config.WavesPerWorld
data.bestCleared = Config.WavesPerWorld
run(1)
eq(stats.Level.Value, Config.WavesPerWorld, "the Level column is the best level cleared")
local wave, coins, gems = data.wave, data.coins, data.diamonds
act("rebirth", true)
eq(data.rebirths, 0, "cannot rebirth")
eq(data.wave, wave, "is not sent back to level 1")
check(data.coins == coins and data.diamonds == gems, "and is paid nothing")
for _, toast in T.toasts do
	check(string.find(string.lower(toast.text), "rebirth", 1, true) == nil, "no toast mentions rebirth: " .. toast.text)
end

T.section("the boards")
local boards = game:GetService("ReplicatedStorage"):FindFirstChild("Leaderboards")
if boards then
	check(boards:FindFirstChild("Rebirths") == nil, "there is no Rebirths board")
end

T.section("the windows")
harness.runClient()
check(harness.errors() == 0, "the client starts and nothing errors")
local Windows = require(player.PlayerScripts.Client.Windows)
local worlds = Windows.byName.WORLDS
check(worlds ~= nil, "WORLDS is there")
worlds.open()
run(0.5)
local seen = false
for _, item in worlds.frame:GetDescendants() do
	if (item:IsA("TextLabel") or item:IsA("TextButton")) and string.find(string.upper(item.Text), "REBIRTH", 1, true) then
		local at, visible = item, true
		while at and at ~= worlds.frame do
			if at:IsA("GuiObject") and not at.Visible then
				visible = false
			end
			at = at.Parent
		end
		seen = seen or visible
	end
end
check(not seen, "and shows nothing about rebirth")

print(`no_rebirth.luau: {T.checks} checks passed`)
