-- Runs before the server starts: a fake logger in AnalyticsService's place (the emulator has no such service,
-- and the feature sends nothing in Studio), and the save of a player from before the funnel existed (user 3).
local Analytics = require(game:GetService("ServerScriptService").Server.Features.Analytics)

local fake = { calls = {}, fail = false }

function fake:LogOnboardingFunnelStepEvent(player: Player, step: number, name: string)
	if self.fail then
		error("AnalyticsService is not answering")
	end
	table.insert(self.calls, { kind = "funnel", user = player.UserId, step = step, name = name })
end

function fake:LogCustomEvent(player: Player, name: string, value: number, fields)
	local field = nil
	for _, text in fields or {} do
		field = text
	end
	table.insert(self.calls, { kind = "custom", user = player.UserId, name = name, value = value, field = field })
end

Analytics.logger = fake

local store = game:GetService("DataStoreService"):GetDataStore("PlayerData_v4")
store:SetAsync("u_3", { lastSeen = os.time() - 3600, bestCleared = 12, cleared = 12, wave = 13, totalKills = 300, totalHatches = 2 })
