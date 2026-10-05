-- The event leaderboard (docs/BUILD_QUEUE.md, "Event leaderboard"): what counts as earned, the board, the
-- freeze at the end and the prizes. Run with: python3 run.py --all-features tests/event.luau
-- (tests/event.pre.luau adds a second event before the server starts.)
local T = harness.load("_prelude.luau")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local Config, Game = T.Config, T.Game
local player, data = T.player, T.data
local check, eq, act, run = T.check, T.eq, T.act, T.run
local Shared = require(ReplicatedStorage.Shared.Features.Event)
local Huges = require(ReplicatedStorage.Shared.Features.Huge)
local Feature = require(Server.Features.Event)
local Leaderboard = require(Server.Leaderboard)

local event = Shared.ById.halloween2026
local HUGE = "hugespectre"
local store = DataStoreService:GetDataStore("EventWinners_v1")

local function meta(who: Player?)
	return HttpService:JSONDecode((who or player):GetAttribute("Meta_event"))
end
local function earned(who: Player?): number
	return Feature.earned(who or player, event.id)
end
local function saved(who: Player)
	return Game.data(who).features.event
end
local function toasted(words: string): boolean
	for _, toast in T.toasts do
		if string.find(toast.text, words, 1, true) then
			return true
		end
	end
	return false
end

harness.runClient() -- the tester's own client, for the prize on screen
local UI = require(player.PlayerScripts.Client.UI)

T.section("the event is data")
check(event ~= nil, "Halloween is an event")
eq(event.currency, "candy", "its currency")
eq(event.endsAt, Config.Halloween.endsAt, "it ends when Config.Halloween says")
eq(event.winners, 5, "ranks that win something")
for rank = 1, 3 do
	local reward = Shared.reward(event, rank)
	check(reward.kind == "pet" and reward.pet == HUGE, `rank {rank} wins the Huge`)
end
eq(Shared.reward(event, 4).amount, 2500, "rank 4 wins gems")
eq(Shared.reward(event, 5).amount, 1500, "rank 5 wins gems")
eq(Shared.reward(event, 6), nil, "rank 6 wins")
eq(Shared.commas(2500), "2,500", "2500 reads")
eq(Shared.commas(1234567), "1,234,567", "1234567 reads")
eq(Shared.ordinal(1) .. Shared.ordinal(2) .. Shared.ordinal(3) .. Shared.ordinal(4) .. Shared.ordinal(11), "1st2nd3rd4th11th", "ordinals")
eq(table.concat(Shared.prizeLines(event), " | "), "Top 3: Huge Spectre Cannon | 4th: 2,500 gems | 5th: 1,500 gems", "the prizes read")
eq(Shared.rewardText(Shared.reward(event, 1)), "a Huge Spectre Cannon", "a prize in words")
check(Shared.ById.christmas2026 == nil, "Christmas is not on yet")
check(Shared.ById.emutest ~= nil and Shared.ById.emutest.board == "Event_emutest", "a second event is one more entry")

T.section("the prize Huge")
local huge = Config.Pets[HUGE]
check(huge and huge.huge == true, "it is a Huge")
eq(huge.power, Config.HugePower, "its power is every Huge's")
check(huge.tradable ~= false, "it can be traded")
check(not huge.hidden, "no egg hides it")
for _, egg in Config.Eggs do
	check(egg.huge ~= HUGE, `the {egg.name} does not hatch it`)
	for _, entry in egg.pets do
		if (entry.id or entry[1]) == HUGE then
			error("CHECK FAILED: an egg lists the prize Huge")
		end
	end
end
eq(Huges.Features[HUGE].name, "Haunt", "its feature")
eq(huge.feature, "monsters walk 20% slower", "what the feature says")

T.section("the board")
local board = Leaderboard.added[event.board]
check(board ~= nil, "the Halloween board is one of the leaderboards")
eq(board.attributes.Event, event.id, "it says which event it is")
check(board.top >= 100, "it reads enough entries to tell a player their rank")
check(workspace:FindFirstChild("EventBoard_" .. event.id, true) ~= nil, "the board stands in the marketplace")
check(Leaderboard.added.Event_emutest ~= nil, "the second event has a board of its own")

T.section("earning counts, spending does not")
eq(earned(), 0, "nothing earned yet")
local start = data.candy
run(30)
check(data.candy > start, `the monsters paid candy ({data.candy - start})`)
eq(earned(), data.candy - start, "all of it counts as earned")
eq(meta().list[event.id].earned, earned(), "the client is told")
-- A lump from anywhere (a crate, a quest): nothing has to report it.
data.candy += 5000
run(1)
local spent = 0
eq(earned(), data.candy - start, "candy from any source counts")
local before = earned()
act("buyEvent", "h_candycorn")
spent += 300
run(1)
check(earned() >= before, "buying in the event shop does not lower what was earned")
eq(earned(), data.candy + spent - start, "and everything earned around the purchase still counts")
-- Earned and spent between two looks: the purchase must not hide what came just before it.
before = earned()
data.candy += 40
act("buyEvent", "h_power")
spent += 200
eq(earned() >= before + 40, true, "candy earned just before a purchase is counted")
run(1)
eq(earned(), data.candy + spent - start, "the sum is exact")
-- A hatch at a stand is a prompt, not an action.
local haunted = Config.EggById.haunted
before = earned()
data.candy += 7
harness.advance(0.2)
harness.fire(T.Marketplace.promptFor.haunted, "Triggered", player)
check(earned() >= before + 7, "candy earned just before a hatch at a stand is counted")
run(1)
local pending = data.candy -- whatever the hatch cost or gave back is in the balance
check(earned() >= before + 7, "hatching for candy does not lower what was earned")
check(haunted.cost > 0 and pending >= 0, "the egg was paid for with candy")
-- Spending it all.
before = earned()
data.candy = 0
run(1)
check(earned() >= before, "an empty purse is still the same score")
local score = earned()

T.section("the score goes on the board")
Leaderboard.submit(player, data, { power = 1 })
eq(Leaderboard.scores[event.board][1], earned(), "the board gets what was earned, not the balance")
Leaderboard.refresh(event.board, { { key = "77", value = 9e9 }, { key = "1", value = earned() } })
run(2)
eq(meta().list[event.id].rank, 2, "the player is told their rank")
check(meta().list[event.id].final == false, "the ranking is not final")

T.section("the second event: its ranking was frozen by another server")
-- It was over when this server started, and its board could not be read: nothing was frozen, nobody paid.
check(Feature.winners.emutest == nil, "a board that cannot be read freezes nothing")
eq(store:GetAsync("emutest"), nil, "and stores nothing")
local gems = data.diamonds
store:SetAsync("emutest", { frozen = true, at = 1, list = { { userId = 1, score = 5 } } })
Leaderboard.fake.Event_emutest = { { userId = 99, score = 1000 } } -- what this server would have frozen
Feature.check()
harness.flush()
eq(#Feature.winners.emutest, 1, "the stored ranking is taken")
eq(Feature.winners.emutest[1].userId, 1, "not this server's own reading of the board")
eq(data.diamonds, gems + 100, "its winner is paid at once, being online")
eq(saved(player).paid.emutest, 1, "and the save remembers")
eq(meta().reward.kind, "gems", "the client is told to show the prize")
eq(meta().reward.amount, 100, "and how much")
check(toasted("finished 1st in the Emulator event and won 100 gems"), "everyone is told")
check(UI.gui:FindFirstChild("EventPrize") == nil, "the prize's card waits a moment")
run(5)
local card = UI.gui:FindFirstChild("EventPrize")
check(card ~= nil and card.Visible, "then the gem prize fills the screen")
local words = {}
for _, label in card:GetDescendants() do
	if label:IsA("TextLabel") then
		table.insert(words, label.Text)
	end
end
local text = table.concat(words, " | ")
check(string.find(text, "EMULATOR EVENT", 1, true) ~= nil, `it names the event ({text})`)
check(string.find(text, "1ST PLACE!", 1, true) ~= nil, "the place")
check(string.find(text, "+100 gems", 1, true) ~= nil, "and the gems")
run(8)
check(not card.Visible, "and goes away by itself")
Feature.check()
run(25)
eq(data.diamonds, gems + 100, "once")

T.section("nothing is paid before the end")
local others = {
	harness.addPlayer("First", 11),
	harness.addPlayer("Second", 12),
	harness.addPlayer("Fourth", 14),
	harness.addPlayer("Sixth", 16),
}
local first, second, fourth, sixth = others[1], others[2], others[3], others[4]
local ranking = {
	{ userId = 11, score = 9000 }, { userId = 12, score = 8000 }, { userId = 1, score = 7000 },
	{ userId = 14, score = 6000 }, { userId = 15, score = 5000 }, { userId = 16, score = 4000 },
}
Leaderboard.fake[event.board] = ranking
local fourthGems, sixthGems = Game.data(fourth).diamonds, Game.data(sixth).diamonds
Feature.check()
run(25)
check(Feature.winners[event.id] == nil, "the ranking is not frozen while the event is live")
eq(store:GetAsync(event.id), nil, "nothing is stored")
eq(Game.pets.count(Game.data(first), HUGE), 0, "the leader has no prize yet")
eq(Game.data(fourth).diamonds, fourthGems, "nor has rank 4")
eq(saved(player).paid[event.id], nil, "nobody is marked as paid")

T.section("the event ends")
Game.data(first).candy += 123
run(1)
eq(Feature.earned(first, event.id) >= 123, true, "earned up to the last second")
local firstScore = Feature.earned(first, event.id)
harness.setTime(event.endsAt + 5)
run(1)
Game.data(first).candy += 500
run(1)
eq(Feature.earned(first, event.id), firstScore, "candy after the end earns nothing")
Feature.check()
harness.flush()
eq(Leaderboard.scores[event.board][11], firstScore, "the players online at the end have their last score sent")
check(Feature.winners[event.id] == nil, "the ranking is not frozen in the first minutes")
eq(board.score(Game.data(first)), firstScore, "late scores are still taken")
harness.setTime(event.endsAt + Shared.SUBMIT_GRACE + 1)
eq(board.score(Game.data(first)), 0, "but not right before the freeze")
eq(Game.pets.count(Game.data(first), HUGE), 0, "still nobody is paid")

T.section("the freeze and the prizes")
harness.setTime(event.endsAt + Shared.FREEZE_DELAY + 1)
-- The board cannot be read: no ranking, no prizes, try again later.
Leaderboard.fake[event.board] = nil
Feature.check()
harness.flush()
check(Feature.winners[event.id] == nil and store:GetAsync(event.id) == nil, "a board that cannot be read freezes nothing")
Leaderboard.fake[event.board] = ranking
T.toasts = {}
Feature.check()
harness.flush()
local frozen = store:GetAsync(event.id)
check(frozen ~= nil and frozen.frozen == true, "the ranking is stored")
eq(#frozen.list, 5, "the best five, no more")
for index = 1, 5 do
	eq(frozen.list[index].userId, ranking[index].userId, `stored rank {index}`)
end
eq(Game.pets.count(Game.data(first), HUGE), 1, "rank 1 gets the Huge")
eq(Game.pets.count(Game.data(second), HUGE), 1, "rank 2 gets the Huge")
eq(Game.pets.count(data, HUGE), 1, "rank 3 gets the Huge")
eq(Game.data(fourth).diamonds, fourthGems + 2500, "rank 4 gets 2,500 gems")
eq(Game.pets.count(Game.data(fourth), HUGE), 0, "and no Huge")
eq(Game.data(sixth).diamonds, sixthGems, "rank 6 gets nothing")
eq(Game.pets.count(Game.data(sixth), HUGE), 0, "no Huge either")
eq(saved(sixth).paid[event.id], nil, "and is not marked")
eq(saved(first).paid[event.id], 1, "rank 1's save remembers")
eq(saved(player).paid[event.id], 3, "rank 3's save remembers")
eq(meta().reward.kind, "pet", "the client is told to play the reveal")
eq(meta().reward.pet, HUGE, "of the Huge")
eq(meta().reward.rank, 3, "for rank 3")
eq(meta(fourth).reward.amount, 2500, "rank 4's client shows the gems")
check(meta(sixth).reward == nil, "rank 6's client shows nothing")
eq(meta().list[event.id].final, true, "the client knows the ranking is final")
eq(meta().list[event.id].place, 3, "and the player's place")
check(toasted("First finished 1st in the Halloween event and won a Huge Spectre Cannon"), "the server announces rank 1")
check(toasted("Fourth finished 4th in the Halloween event and won 2,500 gems"), "and rank 4")
check(not toasted("Sixth finished"), "not rank 6")
check(table.find(Game.state(first).equipped, HUGE) ~= nil, "the Huge is equipped straight away")

T.section("exactly once")
Feature.check()
run(45)
eq(Game.pets.count(Game.data(first), HUGE), 1, "rank 1 still has one Huge")
eq(Game.data(fourth).diamonds, fourthGems + 2500, "rank 4 was paid once")
-- Another server reads the board later and sees a different order: the stored ranking stands.
Feature.winners[event.id] = nil
Leaderboard.fake[event.board] = { { userId = 16, score = 99999 }, { userId = 14, score = 9000 } }
Feature.check()
harness.flush()
eq(Feature.winners[event.id][1].userId, 11, "a second freeze takes the stored ranking")
eq(store:GetAsync(event.id).list[1].userId, 11, "and does not overwrite it")
eq(Game.pets.count(Game.data(sixth), HUGE), 0, "nobody new is paid")
eq(Game.pets.count(Game.data(first), HUGE), 1, "nobody is paid twice")

T.section("a winner who joins later")
local fifth = harness.addPlayer("Fifth", 15)
local fifthData = Game.data(fifth)
eq(fifthData.diamonds, 1500, "rank 5 is paid 1,500 gems on joining")
eq(saved(fifth).paid[event.id], 5, "the save remembers")
eq(meta(fifth).reward.amount, 1500, "their client shows it")
check(toasted("Fifth finished 5th"), "the server announces it")
harness.removePlayer(fifth)
fifth = harness.addPlayer("Fifth", 15)
eq(Game.data(fifth).diamonds, 1500, "joining again pays nothing more")
check(meta(fifth).reward == nil, "and shows no prize again")
-- The Huge winner too.
harness.removePlayer(first)
first = harness.addPlayer("First", 11)
eq(Game.pets.count(Game.data(first), HUGE), 1, "rank 1 has one Huge after joining again")
check(meta(first).reward == nil, "and no second reveal")
-- Someone who was never on the board.
local nobody = harness.addPlayer("Nobody", 40)
eq(Game.data(nobody).diamonds, 0, "a player who was not ranked gets nothing")
eq(Game.pets.count(Game.data(nobody), HUGE), 0, "no Huge")

T.section("the Huge's feature")
local state = T.state
check(table.find(state.equipped, HUGE) ~= nil, "the tester has it equipped")
local speed = Game.breakdown(player, "monsterSpeed")
local found = false
for _, source in speed.sources do
	if source.label == "Huge Spectre Cannon: Haunt" then
		found = true
		check(math.abs(source.mult - 0.8) < 1e-9, "Haunt makes monsters walk 20% slower")
	end
end
check(found, "STATS lists Haunt as a source of monster speed")

check(score >= 0 and harness.errors() == 0, "no errors")
print(`event: {T.checks} checks passed`)
