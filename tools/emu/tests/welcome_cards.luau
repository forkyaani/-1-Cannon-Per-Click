-- The cards after the walkthrough (run with --all-features): one card stands before the game (tutorial.luau);
-- the group's card and the like card come up once the last step is answered, in that order, pay nothing by
-- themselves, and are never seen again.
local T = harness.load("_prelude.luau")
local Game = T.Game
local player, data = T.player, T.data
local check, eq = T.check, T.eq
local Http = game:GetService("HttpService")
local Tutorial = require(game:GetService("ReplicatedStorage").Shared.Features.Tutorial)

local function meta()
	return Http:JSONDecode(player:GetAttribute("Meta_tutorial"))
end
local function textOf(root: Instance): string
	local parts = {}
	for _, item in root:GetDescendants() do
		if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text ~= "" then
			local at, visible = item, true
			while at and at ~= root do
				if at:IsA("GuiObject") and not at.Visible then
					visible = false
				end
				at = at.Parent
			end
			if visible then
				table.insert(parts, item.Text)
			end
		end
	end
	return table.concat(parts, " | ")
end
local function frames()
	for _ = 1, 15 do
		harness.advance(1 / 30)
		harness.fire(game:GetService("RunService"), "RenderStepped", 1 / 30)
	end
end
local function settle()
	harness.fire(game:GetService("RunService"), "Heartbeat", 1)
	harness.flush()
	frames()
end

T.section("what the lists say")
eq(table.concat(Tutorial.Welcome, " "), "welcome", "one card before the game")
eq(table.concat(Tutorial.Outro, " "), "group like", "the group and the like after the walkthrough")

T.section("the last step's card")
eq(meta().step, "finish", "the save is at the last card")
harness.runClient()
local view = require(player.PlayerScripts.Client.Features.Tutorial)
settle()
local shown = textOf(view.cardGui)
print("  LAST CARD: " .. shown)
check(view.cardGui.Enabled == true and string.find(shown, "YOU ARE ON YOUR OWN", 1, true) ~= nil, "the last step's card is up")
check(string.find(shown, "FAN BONUS", 1, true) == nil and string.find(shown, "favourite", 1, true) == nil, "it asks for nothing")

T.section("the group's card comes next")
local gems = data.diamonds
harness.advance(1)
harness.click(view.mainButton)
settle()
eq(meta().step, Tutorial.DONE, "LET'S GO ends the walkthrough")
local afterFinish = data.diamonds
eq(afterFinish, gems + Tutorial.ById.finish.reward.gems, "which pays its own gems")
shown = textOf(view.cardGui)
print("  GROUP CARD: " .. shown)
check(view.cardGui.Enabled == true and string.find(shown, "FAN BONUS", 1, true) ~= nil, "the group's card is up")
check(view.checkButton.Visible == true, "with its CHECK button, for somebody who has not got the bonus")
check(view.skipLink.Visible == false, "and no skip link")
check(string.find(shown, "favourite", 1, true) == nil, "it does not ask for a rating")

T.section("then the like card")
harness.advance(1)
harness.click(view.mainButton)
settle()
shown = textOf(view.cardGui)
print("  LIKE CARD: " .. shown)
check(view.cardGui.Enabled == true and string.find(shown, "ENJOYING THE GAME?", 1, true) ~= nil, "the like card is up")
check(string.find(shown, "no reward", 1, true) ~= nil, "it says there is no reward")
check(view.checkButton.Visible == false and view.skipLink.Visible == false, "one button and nothing else")
harness.advance(1)
harness.click(view.mainButton)
settle()
check(view.cardGui.Enabled == false, "one press closes it")
eq(data.diamonds, afterFinish, "and neither card paid anything")
harness.advance(3)
settle()
check(view.cardGui.Enabled == false, "they do not come back")

print(`welcome_cards.luau: {T.checks} checks passed`)
