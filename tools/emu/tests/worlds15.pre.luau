-- Runs before the server starts (tests/worlds15.luau).
-- A save from before worlds 13 to 15 existed: its player stands on the last level of The Big Bang, level 600,
-- which they have not cleared yet. Nothing in it knows about a thirteenth world.
local store = game:GetService("DataStoreService"):GetDataStore("PlayerData_v5")
store:SetAsync("u_1", {
	lastSeen = os.time(),
	bestCleared = 599,
	cleared = 599,
	wave = 600,
	coins = 1e36,
	totalKills = 60_000,
	totalHatches = 900,
	pets = { "genesis", "genesis_gold", "bigbang" },
})

-- Stand-ins for imported Blender models of ONE of the new worlds, named the way tools/studio/setup_models.luau
-- files them (time_warp_island -> IslandModels["Time Warp"] + "Time WarpShells", infinity_base -> BaseModels.Infinity
-- + InfinityShells, <world>_creatures -> Creatures[<the monster's name>]). The other new worlds have none, so
-- the test sees both a worn model and the island and base built from parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function folder(name: string, parent: Instance): Folder
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end
local function model(name: string, parent: Instance): Model
	local made = Instance.new("Model")
	made.Name = name
	local part = Instance.new("MeshPart")
	part.Name = "Body"
	part.Size = Vector3.new(4, 4, 4)
	part.Position = Vector3.new(0, 2, 0)
	part.Color = Color3.new(1, 1, 1)
	part.Anchored = true
	part.Parent = made
	made.PrimaryPart = part
	made.Parent = parent
	return made
end
local islands = folder("IslandModels", ReplicatedStorage)
model("Time Warp", islands)
folder("Time WarpShells", islands)
local bases = folder("BaseModels", ReplicatedStorage)
model("Infinity", bases)
folder("InfinityShells", bases)
local creatures = folder("Creatures", ReplicatedStorage)
model("Father Time", creatures)
