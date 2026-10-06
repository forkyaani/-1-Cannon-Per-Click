local Game = require(script.Game)
local Islands = require(script.Islands)
local Leaderboard = require(script.Leaderboard)
local Marketplace = require(script.Marketplace)
local Plots = require(script.Plots)

Plots.build()
Marketplace.build()
Islands.build() -- after the marketplace: the islands' egg stands are the marketplace's
Leaderboard.onRefresh = Marketplace.setBoard
Leaderboard.start()

-- Every ModuleScript in Features returns { start = function(Game) end } and plugs itself in (docs/ARCHITECTURE.md).
-- Loaded in name order, before any player is handled.
local featureFolder = script:FindFirstChild("Features")
local features = if featureFolder then featureFolder:GetChildren() else {}
table.sort(features, function(a, b)
	return a.Name < b.Name
end)
for _, module in features do
	if module:IsA("ModuleScript") then
		-- One broken feature must not stop the game from starting.
		local ok, err = pcall(function()
			require(module).start(Game)
		end)
		if not ok then
			warn(`[Server] feature {module.Name} failed to start and was skipped: {err}`)
		end
	end
end

-- What the features built on the marketplace's square is covered by its Blender town, if the place has one.
Marketplace.cover()

Game.start()
print("[Server] started")
