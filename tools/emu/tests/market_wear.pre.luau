-- Before the server starts: a stand-in for the imported Blender town (ReplicatedStorage.MarketModels), so
-- Marketplace.wear runs. Each mesh is a plain part: only names, parents and places matter. (tests/market_wear.luau)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local models = Instance.new("Folder")
models.Name = "MarketModels"
local market = Instance.new("Model")
market.Name = "Market"
for _, name in { "Market_Ground", "Market_HousesNorth", "Market_Glow", "Market_Leaves", "Market_LeavesAutumn", "Market_Bunting", "Market_Halloween" } do
	local mesh = Instance.new("MeshPart")
	mesh.Name = name
	mesh.Anchored = true
	mesh.Parent = market
end
market.Parent = models
local shells = Instance.new("Folder")
shells.Name = "MarketShells"
for _, name in {
	"EggPedestal", "Stall", "StallStripesA", "StallStripesB", "Leaderboard", "LeaderboardTrim", "NoticeBoard", "Chest", "Portal",
	"PortalSheet", "HatcherySign", "TradePlaza", "HugePedestal", "CrateStand", "AmmoForge", "GuidePlinth",
} do
	local mesh = Instance.new("MeshPart")
	mesh.Name = name
	mesh.Anchored = true
	mesh.Parent = shells
end
shells.Parent = models
models.Parent = ReplicatedStorage
