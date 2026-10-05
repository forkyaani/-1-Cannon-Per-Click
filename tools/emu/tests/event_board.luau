-- The event board on the real src/server/Leaderboard.luau and emulated OrderedDataStores: a feature's board is
-- submitted and refreshed with the others, a player learns their rank, and the freeze reads the store itself.
-- Run with: python3 run.py --all-features --real-leaderboard tests/event_board.luau
local T = harness.load("_prelude.luau")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local Game = T.Game
local player, data = T.player, T.data
local check, eq, run = T.check, T.eq, T.run
local Shared = require(ReplicatedStorage.Shared.Features.Event)
local Feature = require(Server.Features.Event)
local Leaderboard = require(Server.Leaderboard)

local event = Shared.ById.halloween2026
local scores = DataStoreService:GetOrderedDataStore(`LB_Event_{event.id}_v1`)
local winners = DataStoreService:GetDataStore("EventWinners_v1")
local function meta()
	return HttpService:JSONDecode(player:GetAttribute("Meta_event"))
end

T.section("the client starts")
harness.runClient()
local Client = player.PlayerScripts.Client
local Windows = require(Client.Windows)
local UI = require(Client.UI)
eq(harness.errors(), 0, "errors starting the client")
local function shows(root: Instance, words: string): boolean
	for _, label in root:GetDescendants() do
		if label:IsA("TextLabel") and label.Visible and string.find(label.Text, words, 1, true) then
			return true
		end
	end
	return false
end

T.section("the board is one of the leaderboards")
local folder = ReplicatedStorage.Leaderboards
local value = folder:FindFirstChild(event.board)
check(value ~= nil, "the clients are sent the event's board")
eq(value:GetAttribute("Order"), 4, "it is the fourth board")
eq(value:GetAttribute("Title"), "MOST CANDY EARNED", "its heading")
eq(value:GetAttribute("Event"), event.id, "it says which event it is")
eq(#folder:GetChildren(), 4, "boards in all")
eq(folder.Gems:GetAttribute("Order"), 1, "the first three are where they were")

T.section("scores")
for index = 1, 12 do
	scores:SetAsync(tostring(100 + index), 1000 * index) -- user 112 leads with 12,000
end
data.candy += 6500
run(1)
eq(Feature.earned(player, event.id) >= 6500, true, "the tester earned candy")
data.candy = 0
run(1)
Leaderboard.submit(player, data, { power = 5 })
local mine = Feature.earned(player, event.id)
eq(scores:GetAsync("1"), mine, "the earned candy is on the board, though the purse is empty")
local best = Leaderboard.top(event.board, 5)
eq(#best, 5, "the best five can be read")
eq(best[1].userId, 112, "best first")
eq(best[1].score, 12000, "with their score")
Leaderboard.refresh() -- what the server does every minute and a half
run(2)
local rows = HttpService:JSONDecode(value.Value)
eq(#rows, 10, "ten rows are shown")
eq(rows[1].name, "User112", "the leader's name")
eq(rows[1].text, "12.0K candy", "and score")
check(mine > 6000 and mine < 7000, "the tester is between 6,000 and 7,000")
eq(meta().list[event.id].rank, 7, "the tester is told their rank")
local label = workspace:FindFirstChild("EventBoard_" .. event.id, true):FindFirstChildWhichIsA("SurfaceGui")
check(label ~= nil, "the marketplace board has its text")

T.section("what the player sees")
local note = Windows.boardNotes[event.board]()
print("    " .. string.gsub(note, "\n", "\n    "))
check(string.find(note, "Ends in ", 1, true) == 1, "the time left comes first")
check(string.find(note, "Top 3: Huge Spectre Cannon", 1, true) ~= nil, "then the prizes")
check(string.find(note, "4th: 2,500 gems  •  5th: 1,500 gems", 1, true) ~= nil, "with the gems, called gems")
check(string.find(note, "earned  •  rank #7", 1, true) ~= nil, "and the player's own earnings and rank")
local shopNote = Windows.shopNote("candy")
check(string.find(shopNote, "earned ", 1, true) == 1 and string.find(shopNote, "rank #7", 1, true) ~= nil, `the event shop's heading says the same ({shopNote})`)
eq(Windows.shopNote("diamonds"), nil, "no event pays gems")
local top = Windows.byName["TOP PLAYERS"]
top.open()
harness.flush()
check(shows(top.frame, "MOST CANDY EARNED"), "TOP PLAYERS has the event's column")
check(shows(top.frame, "MOST CANNON POWER"), "beside the others")
check(shows(top.frame, "User112"), "with its ranking")
check(shows(top.frame, "Top 3: Huge Spectre Cannon"), "and the prizes under its heading")
Windows.byName.SHOP.open()
Windows.tick()
check(shows(Windows.byName.SHOP.frame, "rank #7"), "the event shop shows the player's rank")
UI.closeWindows()

T.section("a store that is down")
harness.failOrdered(1)
eq(Leaderboard.top(event.board, 5), nil, "a failed read is no answer: that is not an empty board")
eq(#Leaderboard.top(event.board, 5), 5, "the next read works again")

T.section("the freeze reads the store")
harness.setTime(event.endsAt + Shared.FREEZE_DELAY + 1)
Leaderboard.submit(player, data, { power = 5 })
scores:SetAsync("1", 11500) -- as another server's last submit would have: second place
harness.failOrdered(1)
Feature.check()
run(10)
check(Feature.winners[event.id] == nil and winners:GetAsync(event.id) == nil, "nothing is frozen while the board cannot be read")
eq(harness.errors(), 0, "and nothing breaks")
-- (The emulator never takes a reveal off the screen again, and the game pass's Huge had one.)
local hatch = UI.gui:FindFirstChild("Hatch")
hatch.Visible = false
Feature.check()
harness.flush()
local frozen = winners:GetAsync(event.id)
check(frozen ~= nil, "the next check freezes the ranking")
eq(frozen.list[1].userId, 112, "first")
eq(frozen.list[2].userId, 1, "the tester is second")
eq(frozen.list[2].score, 11500, "with the stored score")
eq(#frozen.list, 5, "five winners")
eq(Game.pets.count(data, "hugespectre"), 1, "and the tester is paid the Huge")
local final = Windows.boardNotes[event.board]()
check(string.find(final, "FINAL RANKING", 1, true) == 1, "the column says the ranking is final")
check(string.find(final, "You finished 2nd!", 1, true) ~= nil, "and where the player finished")
check(not hatch.Visible, "the reveal waits a moment")
run(5)
check(hatch.Visible, "then the Huge reveal fills the screen")
check(shows(hatch, "HALLOWEEN EVENT: 2ND PLACE!"), "and says what it is for")
run(120)
eq(scores:GetAsync("1"), 11500, "no score moves after the freeze")
eq(Game.pets.count(data, "hugespectre"), 1, "paid once")

check(harness.errors() == 0, "no errors")
print(`event_board: {T.checks} checks passed`)
