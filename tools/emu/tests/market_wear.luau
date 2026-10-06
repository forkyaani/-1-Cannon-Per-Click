-- The marketplace in its Blender town (run with --all-features --real-marketplace; market_wear.pre.luau puts stand-in models in
-- ReplicatedStorage.MarketModels): the part-built town is unseen but still there, the scenery and every
-- landmark stand on the square, the season's meshes are the right ones, and what a feature builds on the
-- square afterwards is covered too.
local T = harness.load("_prelude.luau")
local Config = T.Config
local check, eq = T.check, T.eq
local square = T.Marketplace.container()
local halloween = Config.halloweenActive(os.time())

local function count(name: string): number
	local n = 0
	for _, child in square:GetChildren() do
		if child.Name == name then
			n += 1
		end
	end
	return n
end

T.section("the part-built town is unseen, and still there")
for _, name in { "Ground", "Lawn", "House", "Tower", "Fountain", "StatueBarrel", "Counter", "Leaderboard", "DailyChest", "Portal", "TradingTable" } do
	local part = square:FindFirstChild(name)
	check(part ~= nil and part.Transparency == 1, `{name} is unseen`)
end
check(square.Ground.CanCollide ~= false, "the ground still holds players up")
eq(square.Lamp.Transparency, 0, "a lamp's bulb is still seen")
eq(square.TradingOrb.Transparency, 0, "so is the trading orb")
check(square.Counter:FindFirstChildWhichIsA("ProximityPrompt") ~= nil, "a stall's prompt is still on its counter")
check(T.Marketplace.returnPrompt ~= nil and T.Marketplace.returnPrompt.Parent == square.Portal, "the way back is still on the gate")

T.section("what features built on the square is covered")
for _, name in { "HugePedestal", "CrateRug", "CrateSign" } do
	local part = square:FindFirstChild(name)
	check(part ~= nil and part.Transparency == 1, `{name} is unseen`)
end
eq(square.AmmoForge.Furnace.Transparency, 1, "the forge's furnace is unseen")
eq(square.StoryGuide.Plinth.Transparency, 1, "the guide's plinth is unseen")

T.section("the town")
local scenery = square:FindFirstChild("Scenery")
check(scenery ~= nil and scenery:FindFirstChild("Market_Ground") ~= nil, "the scenery stands on the square")
eq(scenery:FindFirstChild("Market_Leaves") ~= nil, not halloween, "green leaves outside the event")
eq(scenery:FindFirstChild("Market_Bunting") ~= nil, not halloween, "bunting outside the event")
eq(scenery:FindFirstChild("Market_LeavesAutumn") ~= nil, halloween, "autumn leaves in the event")
eq(scenery:FindFirstChild("Market_Halloween") ~= nil, halloween, "the Halloween dress in the event")
eq(count("Solid") > 0, halloween, "its pumpkins are solid only when they are there")

T.section("the landmarks")
eq(count("Shell_Stall"), if halloween then 3 else 2, "a stall shell per stall")
eq(count("Shell_StallStripesA"), count("Shell_Stall"), "each with its stripes")
check(count("Shell_Leaderboard") >= 3, `a board shell per leaderboard ({count("Shell_Leaderboard")})`)
eq(count("Shell_LeaderboardTrim"), count("Shell_Leaderboard"), "each with its trim")
eq(count("Shell_NoticeBoard"), 2, "two notice boards")
for _, name in { "Chest", "Portal", "PortalSheet", "HatcherySign", "TradePlaza", "HugePedestal", "CrateStand", "AmmoForge", "GuidePlinth" } do
	eq(count("Shell_" .. name), 1, name)
end
local gem = square.Eggs:FindFirstChild("Egg_gem")
check(gem ~= nil and gem.Pedestal:IsA("MeshPart"), "the Gem Egg stands on the town's pedestal")
check(gem:FindFirstChild("Cushion") == nil, "and not on the part-built one")

check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
