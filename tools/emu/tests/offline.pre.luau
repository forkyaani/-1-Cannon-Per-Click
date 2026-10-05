-- Runs before the server starts: a save that was last written two hours ago, with level 2 cleared.
local store = game:GetService("DataStoreService"):GetDataStore("PlayerData_v4")
store:SetAsync("u_1", { lastSeen = os.time() - 2 * 3600, bestCleared = 2, cleared = 2, wave = 3, totalKills = 20 })
