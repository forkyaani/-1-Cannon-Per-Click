-- Runs before the server starts: a new player who has done every step of the walkthrough but the last card,
-- and is not in the group. The group has an id, so its card has something to ask.
local store = game:GetService("DataStoreService"):GetDataStore("PlayerData_v4")
store:SetAsync("u_1", {
	lastSeen = os.time() - 30,
	bestCleared = 6,
	cleared = 6,
	wave = 7,
	totalKills = 80,
	totalHatches = 1,
	features = { tutorial = { welcomed = true, step = "finish", fanPaid = false, paid = {}, seeded = true } },
})
require(game:GetService("ReplicatedStorage").Shared.Config).Fan.groupId = 4242
