-- Before the server starts: stand-ins for an imported egg, its two halves and its mini cannons, so the hatch
-- reveal's opening has models to play with (tests/hatch_open.luau). Plain parts: only names, sizes and places matter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function folder(name: string): Folder
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = ReplicatedStorage
	return made
end
local function mesh(name: string, size: Vector3, parent: Instance)
	local part = Instance.new("MeshPart")
	part.Name = name
	part.Size = size
	part.PivotOffset = CFrame.new()
	part.Anchored = true
	part.Parent = parent
end
local eggs, halves, minis = folder("EggModels"), folder("EggHalves"), folder("MiniCannons")
mesh("basicegg", Vector3.new(2.7, 4, 2.7), eggs) -- has halves
mesh("basicegg_Top", Vector3.new(2.7, 2, 2.7), halves)
mesh("basicegg_Bottom", Vector3.new(2.7, 2.4, 2.7), halves)
mesh("forestegg", Vector3.new(2.7, 4, 2.7), eggs) -- has none: the whole shell is thrown off
for _, id in { "wooden", "iron", "leaf" } do
	mesh(id, Vector3.new(2.4, 1.6, 1.4), minis)
end
