-- Runs before the server starts: the save of a player who was far into the game before the first-join
-- experience existed (user 3). The story is in chapter 2, so every tutorial quest was paid long ago.
local store = game:GetService("DataStoreService"):GetDataStore("PlayerData_v4")
store:SetAsync("u_3", {
	lastSeen = os.time() - 30,
	bestCleared = 60,
	cleared = 60,
	wave = 61,
	totalKills = 5000,
	totalHatches = 4,
	coins = 1000,
	pads = { 1, 2 },
	towers = { ["1"] = { kind = "cannon", level = 20 }, ["2"] = { kind = "cannon", level = 20 } },
	features = { story = { chapter = 2, quest = 1, count = 0, claimed = {} } },
})

-- The test starts from "no group yet" and sets its own id later, whatever the real Config.Fan.groupId is.
require(game:GetService("ReplicatedStorage").Shared.Config).Fan.groupId = 0

-- This test watches the plot wait behind the welcome cards: the prelude must not let it go.
harness.keepWelcomeHold = true
