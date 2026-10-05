-- Smoke test: the server starts, a player joins, the client starts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = harness.addPlayer("Tester", 1)
print("attributes after join: wave", player:GetAttribute("Wave"), "lives", player:GetAttribute("Lives"), "dps", player:GetAttribute("Dps"), "items", player:GetAttribute("Meta_items"))
harness.runClient()
print("client started; menu buttons:")
local Hud = require(player.PlayerScripts.Client.Hud)
for name, button in Hud.menu do
	print("  ", name, button.LayoutOrder, button.Text)
end
assert(harness.errors() == 0, "background errors")
