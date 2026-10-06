-- Files freshly imported mini cannons and eggs into ReplicatedStorage.MiniCannons and ReplicatedStorage.EggModels
-- (src/shared/Models.luau, src/server/Marketplace.luau). It only adds: a model with the same name is replaced,
-- every other model in the two folders, and every other folder, is left alone. Safe to run again.
--
-- 1. File > Import assets/models/minis/world_minis.fbx (or marketplace_minis.fbx), defaults, plus
--    "Insert Using Scene Position" ticked. Blender's front, -Y, arrives as the world's -Z.
-- 2. Paste this whole file into the command bar (View > Command Bar) in edit mode and run it.
-- 3. Delete the import from the Workspace, save, and refresh place/ProjectEgg.rbxl (place/README.md).
local FRONT = -Vector3.zAxis

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function folder(name: string): Instance
	local found = ReplicatedStorage:FindFirstChild(name)
	if not found then
		found = Instance.new("Folder")
		found.Name = name
		found.Parent = ReplicatedStorage
	end
	return found
end

local function file(part: MeshPart, name: string, into: Instance)
	local old = into:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = into
end

local minis, eggs = folder("MiniCannons"), folder("EggModels")
local added = { minis = {}, eggs = {} }
for _, found in workspace:GetDescendants() do
	if not found:IsA("MeshPart") then
		continue
	end
	local mini, egg = string.match(found.Name, "^mini_(.+)$"), string.match(found.Name, "^egg_(.+)$")
	if mini then
		-- Pivot at its middle, looking along the barrel with its X axis (Models.mini).
		local part = found:Clone()
		part.PivotOffset = part.CFrame:ToObjectSpace(CFrame.fromMatrix(part.Position, FRONT, Vector3.yAxis))
		file(part, mini, minis)
		table.insert(added.minis, mini)
	elseif egg then
		-- Pivot under its foot, looking along its front (Marketplace.buildEggStand).
		local part = found:Clone()
		local foot = found:GetPivot().Position
		part.PivotOffset = part.CFrame:ToObjectSpace(CFrame.lookAt(foot, foot + FRONT))
		file(part, egg, eggs)
		table.insert(added.eggs, egg)
	end
end
ChangeHistoryService:SetWaypoint("Add mini cannons and eggs")
table.sort(added.minis)
table.sort(added.eggs)
print(`[add_minis] {#added.minis} mini cannons: {table.concat(added.minis, ", ")}`)
print(`[add_minis] {#added.eggs} eggs: {table.concat(added.eggs, ", ")}`)
print(`[add_minis] MiniCannons now holds {#minis:GetChildren()}, EggModels {#eggs:GetChildren()}`)
