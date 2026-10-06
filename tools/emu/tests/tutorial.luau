-- The first-join experience (Features/Tutorial.luau x3). Run with:
--   python3 run.py --all-features tests/tutorial.luau
-- A new save sees the welcome once; the fan bonus is paid once and only for the group; every walkthrough step
-- ends when the thing is really done, in order, and pays once (the story's quest for the same thing pays
-- nothing more); steps that are done already are passed; a rejoin carries on; a failed level says what to do.
-- The plot stands still behind the welcome cards and starts when they close; nobody stays paused after them.
-- tutorial.pre.luau stores the save of an old player (user 3) the walkthrough has nothing to teach.
local T = harness.load("_prelude.luau")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local Config, Layout, Game = T.Config, T.Layout, T.Game
local player, data, state = T.player, T.data, T.state
local check, eq, act, run = T.check, T.eq, T.act, T.run
local Tutorial = require(ReplicatedStorage.Shared.Features.Tutorial)
local Story = require(ReplicatedStorage.Shared.Features.Story)
local ServerTutorial = require(Server.Features.Tutorial)

-- The Huge every pass owner gets in Studio would change how fast levels clear.
for _, id in Config.Huges do
	Game.pets.remove(player, id, Game.pets.count(data, id))
end

local function meta(who: Player?)
	return HttpService:JSONDecode((who or player):GetAttribute("Meta_tutorial"))
end
local function story(who: Player?)
	return HttpService:JSONDecode((who or player):GetAttribute("Meta_story"))
end
local function step(who: Player?): string
	return meta(who).step
end
-- Where every living monster of a plot is and what it has left, and how many were sent: for "nothing moved".
local function field(session): string
	local parts = { `spawned {session.spawned}`, `phase {session.phase}` }
	for _, monster in session.monsters do
		table.insert(parts, `{monster.id}@{monster.d}:{monster.hp}`)
	end
	return table.concat(parts, " ")
end
local function toasted(text: string, from: number?): boolean
	for index = from or 1, #T.toasts do
		if string.find(T.toasts[index].text, text, 1, true) then
			return true
		end
	end
	return false
end
-- A character that stands where the test puts it.
local function body(who: Player, at: Vector3): Part
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = at
	root.Parent = character
	character.PrimaryPart = root
	who.Character = character
	character.Parent = workspace
	return root
end
-- Every text that is on screen under an instance (nothing inside a hidden page), joined.
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

----------------------------------------------------------------------------------------------------
T.section("the steps and what they pay")
local ids = {}
for _, entry in Tutorial.Steps do
	table.insert(ids, entry.id)
end
eq(table.concat(ids, " "), "pad open upgrade clear pad2 build lives island hatch home finish", "the walkthrough's order")
do
	-- Every purchase the walkthrough asks for is paid for by the steps before it, with nothing from the fight.
	local purse = 0
	for _, entry in Tutorial.Steps do
		if entry.buys then
			check(purse >= entry.buys, `"{entry.title}" costs {entry.buys} and the steps before it have paid {purse}`)
			purse -= entry.buys
		end
		purse += (entry.reward and entry.reward.coins) or 0
	end
	eq(Tutorial.ById.upgrade.buys, Config.towerUpgradeCost("cannon", 1), "the upgrade's real price")
	eq(Tutorial.ById.pad2.buys, Config.padPrice(2), "the second pad's real price")
	eq(Tutorial.ById.build.buys, Config.Towers.cannon.cost, "a Cannon's real price")
	eq(Tutorial.ById.hatch.buys, Config.Eggs[1].cost, "the first egg's real price")
	print(`  PRICES upgrade {Tutorial.ById.upgrade.buys}, pad {Tutorial.ById.pad2.buys}, cannon {Tutorial.ById.build.buys}, egg {Tutorial.ById.hatch.buys}`)
	for _, entry in Tutorial.Steps do
		print(`  STEP {entry.id}: "{entry.title}" / "{entry.detail}" pays "{Tutorial.rewardText(entry.reward)}"`)
	end
end
do
	-- Chapter 1 stands behind the walkthrough: the same things in the same order, the same reward, paid once.
	local order = {}
	for _, quest in Story.Chapters[1].quests do
		if quest.tutorial then
			table.insert(order, quest.tutorial)
			check(quest.reward == Tutorial.ById[quest.tutorial].reward, `the "{quest.title}" quest pays the step's own reward`)
			check(Tutorial.ById[quest.tutorial].story == true, `and the step "{quest.tutorial}" knows it has a quest`)
		end
	end
	eq(table.concat(order, " "), "pad upgrade clear pad2 build hatch", "the story's tutorial quests, in the walkthrough's order")
	local last = 0
	for _, id in order do
		check(Tutorial.Index[id] > last, `"{id}" comes later in the walkthrough than the quest before it`)
		last = Tutorial.Index[id]
	end
end
do
	-- The like card promises nothing. The bonus is on the group's card only.
	local like, group
	for _, card in Tutorial.Cards do
		if card.id == "like" then
			like = card
		elseif card.id == "group" then
			group = card
		end
	end
	local words = string.lower(table.concat(like.lines, " ") .. " " .. like.title .. " " .. like.next)
	for _, word in { "gem", "coin", "bonus", "free", "claim", "get " } do
		check(not string.find(words, word, 1, true), `the like card does not say "{word}"`)
	end
	check(string.find(words, "no reward", 1, true) ~= nil, "it says there is no reward")
	local groupWords = string.lower(table.concat(group.lines, " ") .. " " .. group.no .. " " .. group.ask)
	check(not string.find(groupWords, "like", 1, true) and not string.find(groupWords, "favo", 1, true) and not string.find(groupWords, "thumb", 1, true), "the group card does not mention liking")
	for name in Game.actions do
		local lower = string.lower(name)
		check(not string.find(lower, "like") and not string.find(lower, "favo") and not string.find(lower, "thumb"), `no action pays for a rating ({name})`)
	end
end

----------------------------------------------------------------------------------------------------
T.section("a new save: the welcome, once")
eq(meta().welcomed, false, "a new save has not been welcomed")
eq(step(), "pad", "and its walkthrough waits at the first step")
eq(meta().group, false, "no group yet (Config.Fan.groupId is 0)")
check(T.held == true, "the join paused the new player's plot")
eq(state.paused, true, "and it is still paused")
eq(player:GetAttribute("Paused"), true, "the client is told")
local stood = { field = field(state), coins = data.coins, kills = data.totalKills, wave = data.wave }
local root = body(player, Layout.padPosition(state.slot, 1) + Vector3.new(3, 3, 3))
run(2)
eq(step(), "pad", "nothing of the walkthrough runs before the welcome is over, even at the pad")
eq(state.spawned, 0, "no monster is sent while the cards are up")
eq(#state.monsters, 0, "so none is on the path")
root.Position = Layout.plotSpawn(state.slot).Position

harness.runClient()
local Client = player.PlayerScripts.Client
local view = require(Client.Features.Tutorial)
local Hud = require(Client.Hud)
local Windows = require(Client.Windows)
check(view.cardGui.Enabled == true, "the card is up when the client starts")
check(view.banner.Visible == false, "and no banner under it")
local shown = textOf(view.cardGui)
print("  CARD 1: " .. shown)
check(string.find(shown, "WELCOME", 1, true) ~= nil and string.find(shown, Config.GameName, 1, true) ~= nil, "card one welcomes to the game by name")
check(string.find(shown, "1/3", 1, true) ~= nil, "it is card 1 of 3")
harness.click(view.mainButton)
check(string.find(textOf(view.cardGui), "1/3", 1, true) ~= nil, "a press in the first moment does not turn the page")
harness.advance(1)
harness.click(view.mainButton)
shown = textOf(view.cardGui)
print("  CARD 2 (no group yet): " .. shown)
check(string.find(shown, "2/3", 1, true) ~= nil and string.find(shown, "FAN BONUS", 1, true) ~= nil, "NEXT turns to the group's card")
check(string.find(shown, `+{Config.Fan.gems} gems`, 1, true) ~= nil and string.find(shown, "+10% coins", 1, true) ~= nil, "which says what the bonus is")
check(string.find(shown, "coming soon", 1, true) ~= nil, "and that the group is coming soon")
check(view.checkButton.Visible == false, "with no CHECK button while there is no group")

T.section("the fan bonus: for the group only, once")
local gems = data.diamonds
local baseCoins = Game.value(player, "coins")
act("tutorialCheck")
run(1)
eq(data.diamonds, gems, "CHECK without a group pays nothing")
eq(meta().fanPaid, false, "and nothing is marked paid")
-- The owner fills the id in.
Config.Fan.groupId = 4242
act("tutorialCheck")
run(1)
eq(meta().group, true, "with an id the card offers the check")
eq(meta().member, "no", "the emulated Roblox says this player is not in the group")
eq(data.diamonds, gems, "so nothing is paid")
harness.advance(0.5)
shown = textOf(view.cardGui)
print("  CARD 2 (not a member): " .. shown)
check(view.checkButton.Visible == true and string.find(shown, "Not a member yet", 1, true) ~= nil, "the card says so and keeps its CHECK button")
-- Roblox down.
local asks, answer, answered = 0, false, true
local members = {} -- [user id] = true: who is in the group, for the players that join later
local joinAsks = 0
ServerTutorial.inGroup = function(who: Player, id: number, fresh: boolean?): (boolean, boolean)
	assert(id == 4242, "the check asks about the configured group")
	if who.UserId ~= 1 then
		joinAsks += 1
		return true, members[who.UserId] == true
	end
	asks += 1
	return answered, answer
end
answered = false
harness.advance(4)
act("tutorialCheck")
run(1)
eq(meta().member, "failed", "a check Roblox did not answer is not a no")
eq(data.diamonds, gems, "and pays nothing")
answered, answer = true, true
local before = asks
act("tutorialCheck")
eq(asks, before, "CHECK cannot be hammered: a second press within seconds asks nobody")
harness.advance(4)
harness.click(view.checkButton)
run(1)
eq(asks, before + 1, "the card's CHECK button asks the server, which asks Roblox")
eq(data.diamonds, gems + Config.Fan.gems, "a member is paid the gems")
eq(meta().fanPaid, true, "the bonus is marked paid")
check(math.abs(Game.value(player, "coins") - baseCoins * (1 + Config.Fan.coins)) < 1e-9, `and coins are x{1 + Config.Fan.coins} from now on`)
do
	local named = false
	for _, source in Game.breakdown(player, "coins").sources do
		named = named or source.label == "Fan bonus"
	end
	check(named, 'STATS lists it as "Fan bonus"')
end
check(toasted("Fan bonus!"), "a toast says thank you")
harness.advance(4)
act("tutorialCheck")
run(1)
harness.advance(4)
act("tutorialCheck")
run(1)
eq(data.diamonds, gems + Config.Fan.gems, "checking again pays nothing more")
eq(asks, before + 1, "and does not even ask")
harness.advance(2)
shown = textOf(view.cardGui)
print("  CARD 2 (paid): " .. shown)
check(string.find(shown, "Fan bonus claimed", 1, true) ~= nil and view.checkButton.Visible == false, "the card says it is claimed and CHECK is gone")

T.section("the like card and the way in")
harness.click(view.mainButton)
shown = textOf(view.cardGui)
print("  CARD 3: " .. shown)
check(string.find(shown, "3/3", 1, true) ~= nil and string.find(shown, "START TUTORIAL", 1, true) ~= nil, "the last card has the START button")
check(string.find(shown, "Skip tutorial", 1, true) ~= nil, "and the skip link")
gems = data.diamonds
harness.advance(1)
harness.click(view.skipLink)
run(1)
eq(meta().welcomed, false, "one press on the link skips nothing")
check(string.find(textOf(view.cardGui), "Tap again", 1, true) ~= nil, "it asks first")
harness.advance(5)
for _, junk in { 1, true, "yes", { "start" }, "START" } do
	act("tutorialWelcome", junk)
end
eq(meta().welcomed, false, "a junk answer does not end the welcome")
-- All of the above took a good half minute of game time.
eq(state.paused, true, "the plot is still waiting on the last card")
eq(field(state), stood.field, "nothing spawned and nothing moved in all that time")
eq(data.totalKills, stood.kills, "nothing was shot")
eq(data.wave, stood.wave, "and the level is the one the player joined on")
act("tutorialAck", "lives")
act("tutorialAck", "finish")
eq(step(), "pad", "and no step can be acknowledged before the walkthrough runs")
harness.advance(0.5)
harness.click(view.mainButton)
run(1)
eq(meta().welcomed, true, "START TUTORIAL ends the welcome")
eq(data.diamonds, gems, "the like card paid nothing")
check(view.cardGui.Enabled == false, "the card is gone")
check(view.banner.Visible == true, "and the banner is up")
eq(state.paused, false, "the plot starts when the cards close")
eq(player:GetAttribute("Paused"), false, "and the client is told")
run(2)
check(state.spawned > 0 or data.totalKills > stood.kills, "the first monsters are on their way")
act("tutorialWelcome", "skip")
eq(step(), "pad", "the welcome cannot be answered twice")

----------------------------------------------------------------------------------------------------
T.section("the walkthrough, step by step")
-- Lets the client look around: half a second of frames.
local function frames()
	for _ = 1, 15 do
		harness.advance(1 / 30)
		harness.fire(game:GetService("RunService"), "RenderStepped", 1 / 30)
	end
end
local function banner(): string
	frames()
	return textOf(view.banner)
end
-- How many toasts since `from` say that this thing was done and paid.
local function paidToasts(title: string, from: number): number
	local count = 0
	for index = from, #T.toasts do
		local text = T.toasts[index].text
		-- The story pays several quests that finish together in one toast ("2 quests done!  +125").
		if (string.find(text, title, 1, true) or string.find(text, "quests done!", 1, true)) and string.find(text, "+", 1, true) then
			count += 1
		end
	end
	return count
end
local mark = 1 -- the story's quest saw the player at the pad while the welcome was still up

shown = banner()
print("  BANNER: " .. shown)
check(string.find(shown, "Walk to your cannon", 1, true) ~= nil and string.find(shown, "1/11", 1, true) ~= nil, "step 1 of 11: walk to the cannon")
do
	local target = view.pointing()
	check(target ~= nil and (target - Layout.padPosition(state.slot, 1)).Magnitude < 0.01, "the marker stands on the starter pad")
	check(view.arrow.Enabled == true and view.beam.Transparency < 1, "with its arrow and its beam")
end
eq(step(), "pad", "standing at the spawn is not at the pad")
root.Position = Layout.padPosition(state.slot, 1) + Vector3.new(3, 3, 3)
run(1)
eq(step(), "open", "walking up to the pad is step one done")
eq(paidToasts("Walk to your cannon", mark), 1, "paid once, by the walkthrough or by the story's quest, not both")
check(data.coins >= Config.towerUpgradeCost("cannon", 1), "the first upgrade is paid for")
eq(meta().paid.pad, true, "and the reward is marked given")

root.Position = Layout.plotSpawn(state.slot).Position + Vector3.new(0, 0, -40)
act("tutorialAck", "open")
eq(step(), "open", "the tower window cannot have been opened from across the plot")
act("tutorialAck", "upgrade")
act("tutorialAck", "lives")
eq(step(), "open", "and a step that is not the player's is not theirs to acknowledge")
root.Position = Layout.padPosition(state.slot, 1) + Vector3.new(3, 3, 3)
local towerWindow = Windows.byName.TOWER
check(towerWindow ~= nil, "the TOWER window is registered")
towerWindow.open()
harness.advance(2)
frames()
run(1)
eq(step(), "upgrade", "opening the tower window at the pad is step two done")
shown = banner()
print("  BANNER: " .. shown)
check(string.find(shown, "Press UPGRADE", 1, true) ~= nil, "the banner stays readable over the open window")
towerWindow.close()

mark = #T.toasts + 1
act("upgradeTower", { pad = 1, levels = 1 })
run(1)
check(data.towers["1"].level >= 2, "the upgrade was affordable")
eq(step(), "clear", "upgrading is step three done")
eq(paidToasts("pgrade", mark), 1, "paid once")
check(data.coins >= Config.padPrice(2), "the second pad is paid for")

local cleared = data.bestCleared
for _ = 1, 120 do
	if step() ~= "clear" then
		break
	end
	run(1)
end
check(data.bestCleared > cleared, "a level was cleared while the player watched")
eq(step(), "pad2", "which is step four done")

do
	local target = view.pointing()
	local nearest, distance = nil, math.huge
	for pad = 2, #Layout.PADS do
		local away = (Layout.PADS[pad] - Layout.PADS[1]).Magnitude
		if away < distance then
			nearest, distance = pad, away
		end
	end
	frames()
	target = view.pointing()
	check(target ~= nil and (target - Layout.padPosition(state.slot, nearest)).Magnitude < 0.01, `the marker stands on the pad for sale nearest the cannon (pad {nearest})`)
end
mark = #T.toasts + 1
act("buyPad", 2)
run(1)
eq(#data.pads, 2, "the pad was affordable")
eq(step(), "build", "buying a pad is step five done")
eq(paidToasts("second pad", mark), 1, "paid once")
check(data.coins >= Config.Towers.cannon.cost, "the cannon is paid for")
act("buildTower", { pad = 2, kind = "cannon" })
run(1)
check(data.towers["2"] ~= nil, "the cannon was affordable")
eq(step(), "lives", "building on it is step six done")
shown = banner()
print("  BANNER: " .. shown)
check(string.find(shown, "cost lives", 1, true) ~= nil and view.ackButton.Visible == true, "the lives step is a line to read with a GOT IT button")
local wave = data.wave
run(3)
eq(step(), "lives", "it waits for the player")
check(data.wave >= wave, "and nobody is made to lose a level for it")

T.section("a rejoin carries on")
do
	-- The client of this test belongs to the first Player object, so the rejoin is looked at on the server.
	harness.removePlayer(player)
	run(1)
	local again = harness.addPlayer("Tester", 1)
	harness.flush()
	local saved = Game.data(again)
	assert(saved and Game.state(again), "the player did not load again")
	eq(meta(again).welcomed, true, "the welcome is not shown a second time")
	eq(step(again), "lives", "the walkthrough is where it was left")
	eq(Game.state(again).paused, false, "and a rejoin after the welcome is not paused")
	eq(again:GetAttribute("Paused"), false, "nor told it is")
	eq(meta(again).fanPaid, true, "the fan bonus is still theirs")
	local had = saved.diamonds
	run(2)
	eq(saved.diamonds, had, "and is not paid again on a later join")
	eq(asks, before + 1, "nor even asked about")
	harness.removePlayer(again)
	run(1)
	player = harness.addPlayer("Tester", 1)
	harness.flush()
	data, state = Game.data(player), Game.state(player)
	root = body(player, Layout.plotSpawn(state.slot).Position)
	eq(step(), "lives", "and again")
end

T.section("the second half")
gems = data.diamonds
act("tutorialAck", "finish")
eq(step(), "lives", "LET'S GO is not this step's button")
act("tutorialAck", "lives")
eq(step(), "island", "GOT IT is step seven done")
run(2)
eq(step(), "island", "which waits for the trip")
act("goMarket")
run(1)
eq(step(), "island", "the marketplace is not the island")
act("goIsland", Tutorial.Island)
run(1)
eq(state.place, "island", "the island is open to a new player")
eq(step(), "hatch", "arriving is step eight done")
check(data.coins >= Config.Eggs[1].cost, "and the egg is paid for")
mark = #T.toasts + 1
harness.advance(0.2)
harness.fire(T.Marketplace.promptFor[Config.Eggs[1].id], "Triggered", player)
run(1)
eq(data.totalHatches, 1, "the egg hatched")
eq(step(), "home", "hatching is step nine done")
eq(data.diamonds, gems + Tutorial.ById.hatch.reward.gems, "the hatch's gems were paid once, not by the story as well")
eq(paidToasts("atch", mark), 1, "with one toast")
run(2)
eq(step(), "home", "it waits for the way back")
act("goHome")
run(1)
eq(step(), "finish", "coming home is step ten done")
act("tutorialAck", "lives")
eq(step(), "finish", "GOT IT is not the last step's button")
act("tutorialAck", "finish")
eq(step(), Tutorial.DONE, "LET'S GO ends the walkthrough")
eq(data.diamonds, gems + Tutorial.ById.hatch.reward.gems + Tutorial.ById.finish.reward.gems, "and pays its gems once")
check(toasted("Tutorial complete"), "with a toast that names STORY")
act("tutorialAck", "finish")
run(2)
eq(data.diamonds, gems + Tutorial.ById.hatch.reward.gems + Tutorial.ById.finish.reward.gems, "nothing more after that")
do
	local now = story()
	local quest = Story.Chapters[now.chapter].quests[now.quest]
	check(now.chapter == 1 and quest.tutorial == nil, `the story carries on behind it, at "{quest.title}"`)
	for id, entry in Tutorial.ById do
		if entry.reward then
			eq(meta().paid[id], true, `"{id}" is marked paid`)
		end
	end
end

T.section("replaying it in Studio")
check(Game.actions.tutorialReset ~= nil, "Studio has the tutorialReset action")
gems = data.diamonds
-- With a monster on the path, so that standing still shows. In short frames: two cannons make short work
-- of these levels.
for _ = 1, 1200 do
	local first = state.monsters[1]
	if state.phase == "fight" and first and not first.dead and first.d > 0 then
		break
	end
	harness.step(0.05)
end
check(#state.monsters >= 1 and state.monsters[1].d > 0, "a monster is walking the path")
act("tutorialReset")
eq(meta().welcomed, false, "it brings the welcome back")
eq(step(), "pad", "and the first step")
eq(state.paused, true, "and the plot waits behind the cards again")
do
	local frozen, kills, coins = field(state), data.totalKills, data.coins
	run(3)
	eq(field(state), frozen, "the monsters on the path stand where they were, unhurt, and no more come")
	eq(data.totalKills, kills, "nothing is shot")
	eq(data.coins, coins, "and nothing is earned")
end
act("tutorialWelcome", "start")
eq(state.paused, false, "START lets it go")
do
	local frozen = field(state)
	run(1)
	check(field(state) ~= frozen, "and the fight carries on from where it stood")
end
eq(step(), "clear", "a replay passes what is done already, up to the first thing to watch")
eq(data.diamonds, gems, "and a replay pays nothing again")
act("tutorialReset")
eq(state.paused, true, "the welcome is back and the plot waits")
act("tutorialWelcome", "skip")
eq(step(), Tutorial.DONE, "SKIP TUTORIAL ends it before it begins")
eq(meta().welcomed, true, "and counts as welcomed")
eq(state.paused, false, "a player who skips is not left paused")
eq(player:GetAttribute("Paused"), false, "nor told so")
-- A pause of the player's own, after the welcome, is theirs: nothing of the tutorial takes it back.
act("setPaused", true)
run(2)
eq(state.paused, true, "the pause button still pauses after the welcome")
act("setPaused", false)
harness.removePlayer(player)
run(1)

----------------------------------------------------------------------------------------------------
T.section("a failed level says what to do")
do
	local rookie = harness.addPlayer("Rookie", 2)
	harness.flush()
	Players.LocalPlayer = rookie
	local saved, session = Game.data(rookie), Game.state(rookie)
	assert(saved and session, "the second player did not load")
	for _, id in Config.Huges do
		Game.pets.remove(rookie, id, Game.pets.count(saved, id))
	end
	eq(meta(rookie).welcomed, false, "another new save is welcomed too")
	eq(meta(rookie).fanPaid, false, "and has no fan bonus of the first player's")
	-- Somebody who played a little before pressing START: the pad, the upgrade and the second pad are done.
	saved.coins = 10_000
	act("upgradeTower", { pad = 1, levels = 1 })
	act("buyPad", 2)
	eq(step(rookie), "pad", "playing behind the welcome moves nothing")
	eq(session.paused, true, "their plot waited all the while: building and upgrading go on, the fight does not")
	eq(session.spawned, 0, "no monster was sent")
	act("tutorialWelcome", "start")
	eq(session.paused, false, "START lets it go")
	eq(step(rookie), "clear", "START passes the steps that are done already and stops at the first that is not")
	-- Thrown far ahead: the level cannot be cleared. With coins for an upgrade the line says to upgrade.
	local function failHint(): string
		local at = meta(rookie).hintAt
		for _ = 1, 200 do
			if meta(rookie).hintAt ~= at then
				break
			end
			run(1)
		end
		check(meta(rookie).hintAt ~= at, "a failed level puts a line on the banner")
		return meta(rookie).hint
	end
	saved.coins = 10_000
	T.debug("wave", 45)
	local failedAt = #T.toasts + 1
	local hint = failHint()
	print("  HINT: " .. tostring(hint))
	check(string.find(hint, "Level failed", 1, true) ~= nil and string.find(hint, "UPGRADE", 1, true) ~= nil, "with coins in hand it says to upgrade")
	check(saved.wave < 45 and saved.autoAdvance == false, "the core dropped back a level and stopped auto-advance")
	check(toasted("got through", failedAt) or toasted("broke through", failedAt), "next to the core's own toast")
	check(meta(rookie).hintSeconds > 5, "and says how long the line stays")
	saved.coins = 0
	T.debug("wave", 43)
	hint = failHint()
	print("  HINT: " .. tostring(hint))
	check(string.find(hint, "Level failed", 1, true) ~= nil and string.find(hint, "farm", 1, true) ~= nil, "without coins it says the cannons farm the level before")
	-- The jump made them somebody who has cleared forty levels: nothing is left to watch, and the pad that was
	-- bought before START is passed too.
	run(1)
	eq(step(rookie), "build", "the walkthrough moves on to the first thing that is not done")

	T.section("a rejoin half way, after joining the group")
	check(joinAsks >= 1, "the group was asked about when they joined")
	eq(meta(rookie).fanPaid, false, "they were not in it")
	local rookieGems = saved.diamonds
	harness.removePlayer(rookie)
	run(1)
	members[2] = true
	rookie = harness.addPlayer("Rookie", 2)
	harness.flush()
	Players.LocalPlayer = rookie
	saved = Game.data(rookie)
	eq(meta(rookie).welcomed, true, "welcomed stays")
	eq(step(rookie), "build", "and the step is the saved one")
	eq(meta(rookie).fanPaid, true, "the join after joining the group pays the fan bonus without a press")
	eq(saved.diamonds, rookieGems + Config.Fan.gems, "the gems")
	-- Roblox throwing in the middle of a check must not jam the next one.
	ServerTutorial.inGroup = function()
		error("Roblox is down")
	end
	harness.removePlayer(rookie)
	run(1)
end

----------------------------------------------------------------------------------------------------
T.section("leaving in the middle of the welcome")
do
	local quitter = harness.addPlayer("Quitter", 4)
	harness.flush()
	Players.LocalPlayer = quitter
	local saved, session = Game.data(quitter), Game.state(quitter)
	assert(saved and session, "the fourth player did not load")
	eq(session.paused, true, "a new save waits behind the cards")
	harness.removePlayer(quitter)
	run(1)
	quitter = harness.addPlayer("Quitter", 4)
	harness.flush()
	Players.LocalPlayer = quitter
	saved, session = Game.data(quitter), Game.state(quitter)
	eq(meta(quitter).welcomed, false, "they come back to the cards they left")
	eq(session.paused, true, "so the plot waits again")
	run(2)
	eq(session.spawned, 0, "and nothing is sent")
	-- The pause is the core's own, so its PAUSED banner can always let the plot go: nobody can be stuck
	-- behind a card that failed to draw. The tutorial does not pause it a second time.
	act("setPaused", false)
	run(2)
	eq(session.paused, false, "the player's own resume holds")
	check(session.spawned > 0, "and the level runs")
	act("tutorialWelcome", "skip")
	eq(session.paused, false, "the cards closing changes nothing then")
	harness.removePlayer(quitter)
	run(1)
	quitter = harness.addPlayer("Quitter", 4)
	harness.flush()
	Players.LocalPlayer = quitter
	saved, session = Game.data(quitter), Game.state(quitter)
	eq(meta(quitter).welcomed, true, "the next join has no cards")
	eq(session.paused, false, "and is not paused")
	local sent = session.spawned
	run(2)
	check(session.spawned > sent or saved.totalKills > 0, "its level runs from the start")
	harness.removePlayer(quitter)
	run(1)
end

----------------------------------------------------------------------------------------------------
T.section("an old save: nothing is paid twice, nothing is taught twice")
do
	local veteran = harness.addPlayer("Veteran", 3)
	harness.flush()
	Players.LocalPlayer = veteran
	local saved = Game.data(veteran)
	assert(saved and Game.state(veteran), "the old save did not load")
	eq(saved.bestCleared, 60, "the stored save loaded")
	eq(meta(veteran).welcomed, false, "an old save sees the welcome once too")
	eq(Game.state(veteran).paused, true, "and its plot waits behind it like anyone's")
	for _, id in { "pad", "upgrade", "clear", "pad2", "build", "hatch" } do
		eq(meta(veteran).paid[id], true, `the story paid for "{id}" long ago: it is marked paid`)
	end
	local coins, diamonds = saved.coins, saved.diamonds
	act("tutorialWelcome", "start")
	eq(step(veteran), "finish", "START takes them straight to the last card")
	eq(Game.state(veteran).paused, false, "and lets the plot go")
	local paidNow = (saved.coins - coins) - 0
	eq(paidNow, Tutorial.ById.island.reward.coins, "only the one step the story never had pays: no step is paid twice")
	eq(meta(veteran).member, "failed", "a check that threw is a check that failed")
	eq(meta(veteran).checking, false, "and the next one is not jammed behind it")
	eq(saved.diamonds, diamonds, "no gems before the last press")
	act("tutorialAck", "finish")
	eq(step(veteran), Tutorial.DONE, "done")
	harness.removePlayer(veteran)
	run(1)
	veteran = harness.addPlayer("Veteran", 3)
	harness.flush()
	eq(meta(veteran).welcomed, true, "and never again")
	eq(step(veteran), Tutorial.DONE, "the walkthrough stays finished")
end

check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
