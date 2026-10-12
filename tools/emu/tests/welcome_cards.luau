-- The cards after the walkthrough (run with --all-features): one card stands before the game (tutorial.luau);
-- the group's card and the like card come up once the last step is answered, in that order, pay nothing by
-- themselves, and are never seen again. Then the LIKE + GROUP button on the HUD: there while the fan bonus is
-- unclaimed, opens its one card on a press only, and is gone for good once the bonus is paid.
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

----------------------------------------------------------------------------------------------------
T.section("the LIKE + GROUP button: shown while the bonus is unclaimed")
local Config = T.Config
local ServerTutorial = require(game:GetService("ServerScriptService").Server.Features.Tutorial)
local member = false
local asks = 0
ServerTutorial.inGroup = function(_who: Player, id: number): (boolean, boolean)
	assert(id == 4242, "the check asks about the configured group")
	asks += 1
	return true, member
end
eq(meta().fanPaid, false, "the bonus is not paid")
check(view.fanSlot.Visible == true, "the button is on the HUD")
local face = textOf(view.fanSlot)
print("  BUTTON: " .. face)
check(string.find(face, "LIKE + GROUP", 1, true) ~= nil, "it is labelled LIKE + GROUP")
check(string.find(face, `+{Config.Fan.gems}`, 1, true) ~= nil, "with the gems on it")
check(string.find(face, "👍", 1, true) ~= nil, "and a thumbs up (the glyph, until the sheet has its picture)")
-- The gem is the atlas picture: here it counts as loaded, so its glyph is hidden behind it.
check(view.fanSlot:FindFirstChildWhichIsA("ImageLabel", true) ~= nil, "and a gem")
check(view.cardGui.Enabled == false, "and nothing has opened by itself")

T.section("a press opens one card")
harness.click(view.fanButton)
settle()
shown = textOf(view.cardGui)
print("  FAN CARD: " .. shown)
check(view.cardGui.Enabled == true and view.pages.fan.Visible == true, "the card is up")
check(string.find(shown, "Thumbs up the game", 1, true) ~= nil, "it asks for a thumbs up")
check(string.find(shown, "Join the group " .. Config.Fan.groupName, 1, true) ~= nil, "and for the group, by its name")
check(string.find(shown, `+{Config.Fan.gems} gems`, 1, true) ~= nil and string.find(shown, "+10% coins", 1, true) ~= nil, "the bonus is on it")
check(string.find(shown, "For joining the group", 1, true) ~= nil, "named as the group's")
check(string.find(shown, "no reward", 1, true) ~= nil, "and the thumbs up is said to pay nothing")
check(view.checkButton.Visible == true and view.skipLink.Visible == false, "CHECK is there, and no skip link")
eq(view.mainButton.Text, "CLOSE", "the other button closes it")

T.section("CHECK from somebody who is not in the group")
local before = data.diamonds
harness.advance(1)
harness.click(view.checkButton)
settle()
harness.advance(2)
settle()
eq(asks, 1, "CHECK asked the server, which asked Roblox")
eq(meta().member, "no", "the answer is no")
eq(data.diamonds, before, "nothing is paid")
check(string.find(textOf(view.cardGui), "Not a member yet", 1, true) ~= nil, "the card says so")
check(view.fanSlot.Visible == true, "the button stays")
harness.click(view.mainButton)
settle()
check(view.cardGui.Enabled == false, "CLOSE closes the card")
harness.advance(5)
settle()
check(view.cardGui.Enabled == false and view.fanSlot.Visible == true, "it stays closed, and the button stays")

T.section("gone once the bonus is paid")
member = true
harness.click(view.fanButton)
settle()
check(view.cardGui.Enabled == true, "a press opens the card again")
harness.advance(1)
harness.click(view.checkButton)
settle()
harness.advance(2)
settle()
eq(meta().fanPaid, true, "a member's CHECK pays the bonus")
eq(data.diamonds, before + Config.Fan.gems, "the gems")
check(view.fanSlot.Visible == false, "the button is gone")
shown = textOf(view.cardGui)
print("  PAID CARD: " .. shown)
check(view.cardGui.Enabled == true and string.find(shown, "Fan bonus claimed", 1, true) ~= nil, "the open card says thank you")
check(view.checkButton.Visible == false, "with nothing left to check")
harness.click(view.mainButton)
settle()
check(view.cardGui.Enabled == false, "CLOSE closes it")
-- The button is hidden; a press that got through anyway must open nothing.
harness.click(view.fanButton)
settle()
check(view.cardGui.Enabled == false, "and nothing opens the card any more")
harness.advance(5)
settle()
check(view.fanSlot.Visible == false and view.cardGui.Enabled == false, "it does not come back")

----------------------------------------------------------------------------------------------------
T.section("where the button stands")
-- The emulator has no real screen, so the button's place is asked for each layout the HUD can hand out and
-- held against the pieces around it (design px, 720 tall; the numbers are the HUD's and the features' own).
local function overlap(a, b): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local screens = {
	{ name = "1280 x 720", W = 1280, T = 58, top = 8, stack = 66 },
	{ name = "the narrow branch (W < 1200)", W = 1100, T = 58, top = 66, stack = 198 },
	{ name = "a tablet, 4:3", W = 960, T = 58, top = 66, stack = 198 },
	{ name = "a phone on its side", W = 1558, T = 107, top = 8, stack = 115 },
	{ name = "a very narrow window", W = 860, T = 58, top = 66, stack = 198 },
}
for _, screen in screens do
	local spot = view.fanSpot(screen)
	local button = { x = spot.X, y = spot.Y, w = view.FAN.X, h = view.FAN.Y }
	local pieces = {
		["the stat pills"] = { x = 16, y = screen.T + 8, w = 760, h = 60 },
		["the story tracker"] = { x = 16, y = math.min(screen.stack + 402, 508), w = 230, h = 104 },
		["the walkthrough's banner"] = { x = screen.W / 2 - 290, y = screen.T + 8 + 60 + 6, w = 580, h = 92 },
		["the level panel"] = { x = screen.W / 2 - 202, y = 720 - 14 - 140, w = 404, h = 140 },
		["the travel button"] = { x = screen.W - 170 - 270, y = screen.T + 8, w = 270, h = 92 },
		["the menu"] = { x = screen.W - 16 - 336, y = 720 - 216 - 208, w = 336, h = 208 },
	}
	for what, piece in pieces do
		check(not overlap(button, piece), `{screen.name}: clear of {what}`)
	end
	check(button.x >= 0 and button.y + button.h <= 720 and button.x + button.w <= screen.W, `{screen.name}: on the screen`)
end

print(`welcome_cards.luau: {T.checks} checks passed`)
