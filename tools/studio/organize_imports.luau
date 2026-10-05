-- Turns freshly imported Blender meshes into the four folders the game looks for in ReplicatedStorage:
-- MiniCannons, EggModels, IslandModels and Creatures (src/shared/Models.luau, src/server/Islands.luau,
-- src/server/Marketplace.luau). Paste the whole file into Studio's command bar (View > Command Bar) and press
-- Enter, in edit mode, after importing these with File > Import (defaults, plus "Insert Using Scene Position"
-- ticked, so each file's origin is the world's; Blender's front, -Y, arrives as the world's -Z):
--     assets/models/minis/marketplace_minis.fbx
--     assets/models/islands/earth_island.fbx
--     assets/models/creatures_all.fbx
-- It copies; the imports stay in the Workspace until you delete them. Running it again replaces the folders.
--
-- The importer keeps where each mesh's origin is (the Blender scripts put it where the game wants the pivot)
-- but not which way it looks, so every pivot is turned here to look along the model's front. It also drops the
-- creatures' colours, which are materials and not vertex colours: COLOURS holds them, read from the FBX
-- with tools/studio/fbx_colours.py.
local FRONT = -Vector3.zAxis
local COLOURS = "boss_Arm=4A1FA8;boss_Arm.001=4A1FA8;boss_Belly=C9A6FF;boss_Blush=FF7AC8;boss_Blush.001=FF7AC8;boss_Body=8E4DFF;boss_Brow=4A1FA8;boss_Brow.001=4A1FA8;boss_CrownBall=FFC61A;boss_CrownBall.001=FFC61A;boss_CrownBall.002=FFC61A;boss_CrownBall.003=FFC61A;boss_CrownBall.004=FFC61A;boss_CrownBand=FFC61A;boss_CrownGem=FF3355;boss_CrownGem.001=FF3355;boss_CrownGem.002=FF3355;boss_CrownGem.003=FF3355;boss_CrownGem.004=FF3355;boss_CrownPoint=FFC61A;boss_CrownPoint.001=FFC61A;boss_CrownPoint.002=FFC61A;boss_CrownPoint.003=FFC61A;boss_CrownPoint.004=FFC61A;boss_Eye=1B1140;boss_Eye.001=1B1140;boss_EyeWhite=FFFFFF;boss_EyeWhite.001=FFFFFF;boss_Fang=FFFFFF;boss_Fang.001=FFFFFF;boss_Foot=4A1FA8;boss_Foot.001=4A1FA8;boss_FuseBit=3A1F55;boss_FuseBit.001=3A1F55;boss_FuseBit.002=3A1F55;boss_FuseBit.003=3A1F55;boss_FuseBit.004=3A1F55;boss_Horn=FFD98A;boss_Horn.001=FFD98A;boss_Iris=FF5AF0;boss_Iris.001=FF5AF0;boss_Mouth=1B1140;boss_Shine=FFFFFF;boss_Shine.001=FFFFFF;boss_ShineSmall=FFFFFF;boss_ShineSmall.001=FFFFFF;boss_Spark=FFB01F;boss_SparkRay=FFB01F;boss_SparkRay.001=FFB01F;boss_SparkRay.002=FFB01F;boss_SparkRay.003=FFB01F;boss_SparkRay.004=FFB01F;boss_SparkRay.005=FFB01F;goblin_Cone=8FBF3F;goblin_Cone.001=FFB3C7;goblin_Cone.002=8FBF3F;goblin_Cone.003=FFB3C7;goblin_Cone.004=FFFFFF;goblin_Cube=8FBF3F;goblin_Cube.001=5E8A22;goblin_Cube.002=5E8A22;goblin_Cube.003=5E8A22;goblin_Cube.004=5E8A22;goblin_Cube.005=5E8A22;goblin_Cube.006=5E8A22;goblin_Cube.007=1B1140;goblin_Sphere=FFFFFF;goblin_Sphere.001=1B1140;goblin_Sphere.002=FFC61A;goblin_Sphere.003=FFFFFF;goblin_Sphere.004=FFFFFF;goblin_Sphere.005=FF8FB8;goblin_Sphere.006=FFFFFF;goblin_Sphere.007=1B1140;goblin_Sphere.008=FFC61A;goblin_Sphere.009=FFFFFF;goblin_Sphere.010=FFFFFF;goblin_Sphere.011=FF8FB8;goblin_Sphere.012=B9783F;rock_crab_Cone=FF8A5C;rock_crab_Cone.001=FF8A5C;rock_crab_Cone.002=FF8A5C;rock_crab_Cone.003=FF8A5C;rock_crab_Cube=FF6A3D;rock_crab_Cube.001=9A93B5;rock_crab_Cube.002=9A93B5;rock_crab_Cube.003=9A93B5;rock_crab_Cube.004=D9431F;rock_crab_Cube.005=D9431F;rock_crab_Cube.006=D9431F;rock_crab_Cube.007=D9431F;rock_crab_Cube.008=D9431F;rock_crab_Cube.009=D9431F;rock_crab_Cube.010=D9431F;rock_crab_Cube.011=D9431F;rock_crab_Cube.012=D9431F;rock_crab_Cube.013=D9431F;rock_crab_Cube.014=1B1140;rock_crab_Cube.015=1B1140;rock_crab_Cube.016=1B1140;rock_crab_Sphere=FF8A5C;rock_crab_Sphere.001=FF8A5C;rock_crab_Sphere.002=FFFFFF;rock_crab_Sphere.003=1B1140;rock_crab_Sphere.004=FFE23A;rock_crab_Sphere.005=FFFFFF;rock_crab_Sphere.006=FFFFFF;rock_crab_Sphere.007=FF8FB8;rock_crab_Sphere.008=FFFFFF;rock_crab_Sphere.009=1B1140;rock_crab_Sphere.010=FFE23A;rock_crab_Sphere.011=FFFFFF;rock_crab_Sphere.012=FFFFFF;rock_crab_Sphere.013=FF8FB8;slime_Cube=5FE03A;slime_Cube.001=1B1140;slime_Cube.002=1B1140;slime_Cube.003=1B1140;slime_Sphere=3CB526;slime_Sphere.001=5FE03A;slime_Sphere.002=5FE03A;slime_Sphere.003=B6F59A;slime_Sphere.004=FFFFFF;slime_Sphere.005=1B1140;slime_Sphere.006=9CFF3A;slime_Sphere.007=FFFFFF;slime_Sphere.008=FFFFFF;slime_Sphere.009=FF8FB8;slime_Sphere.010=FFFFFF;slime_Sphere.011=1B1140;slime_Sphere.012=9CFF3A;slime_Sphere.013=FFFFFF;slime_Sphere.014=FFFFFF;slime_Sphere.015=FF8FB8;troll_Cone=FFF3D6;troll_Cone.001=FFF3D6;troll_Cube=7F93B5;troll_Cube.001=55678A;troll_Cube.002=55678A;troll_Cube.003=55678A;troll_Cube.004=55678A;troll_Cube.005=55678A;troll_Cube.006=55678A;troll_Cube.007=1B1140;troll_Sphere=B4C2DA;troll_Sphere.001=7F93B5;troll_Sphere.002=7F93B5;troll_Sphere.003=7F93B5;troll_Sphere.004=7F93B5;troll_Sphere.005=FFFFFF;troll_Sphere.006=1B1140;troll_Sphere.007=FF8A1F;troll_Sphere.008=FFFFFF;troll_Sphere.009=FFFFFF;troll_Sphere.010=FF8FB8;troll_Sphere.011=FFFFFF;troll_Sphere.012=1B1140;troll_Sphere.013=FF8A1F;troll_Sphere.014=FFFFFF;troll_Sphere.015=FFFFFF;troll_Sphere.016=FF8FB8;troll_Sphere.017=FF8A1F;troll_Sphere.018=FF8A1F;troll_Sphere.019=FF8A1F;troll_Sphere.020=FF8A1F;wisp_Sphere=9FDCFF;wisp_Sphere.001=9FDCFF;wisp_Sphere.002=DDF4FF;wisp_Sphere.003=9FDCFF;wisp_Sphere.004=DDF4FF;wisp_Sphere.005=DDF4FF;wisp_Sphere.006=DDF4FF;wisp_Sphere.007=DDF4FF;wisp_Sphere.008=DDF4FF;wisp_Sphere.009=DDF4FF;wisp_Sphere.010=6FB7E8;wisp_Sphere.011=FFFFFF;wisp_Sphere.012=1B1140;wisp_Sphere.013=3FE0FF;wisp_Sphere.014=FFFFFF;wisp_Sphere.015=FFFFFF;wisp_Sphere.016=FF8FB8;wisp_Sphere.017=FFFFFF;wisp_Sphere.018=1B1140;wisp_Sphere.019=3FE0FF;wisp_Sphere.020=FFFFFF;wisp_Sphere.021=FFFFFF;wisp_Sphere.022=FF8FB8;wisp_Sphere.023=1B1140"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local CREATURES = { slime = "Slime", goblin = "Goblin", rock_crab = "Rock Crab", wisp = "Wisp", troll = "Troll", boss = "Boss" }
local SHELLS = { EggPedestal = true, Stall = true, Portal = true, PortalSheet = true, BossPlinth = true }
local MATERIALS = { Glow = Enum.Material.Neon, Water = Enum.Material.Glass }
-- A pivot at that position, which stands upright and looks along the model's front.
local function facing(position: Vector3): CFrame
	return CFrame.lookAt(position, position + FRONT)
end

local colours: { [string]: Color3 } = {}
for name, hex in string.gmatch(COLOURS, "([^=;]+)=(%x+)") do
	colours[name] = Color3.fromHex(hex)
end

local function folder(name: string, class: string?): Instance
	local old = ReplicatedStorage:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local new = Instance.new(class or "Folder")
	new.Name = name
	new.Parent = ReplicatedStorage
	return new
end

local function still(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- The lowest and highest corners of the parts, in world space.
local function bounds(parts: { BasePart }): (Vector3, Vector3)
	local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, part in parts do
		local half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
					low, high = low:Min(corner), high:Max(corner)
				end
			end
		end
	end
	return low, high
end

local minis, eggs = folder("MiniCannons"), folder("EggModels")
local islands, creatures = folder("IslandModels"), folder("Creatures")
local scenery: { [string]: Model } = {}
local herds: { [string]: { BasePart } } = {}
local counts = { minis = 0, eggs = 0, island = 0, creatures = 0 }

for _, found in workspace:GetDescendants() do
	if not found:IsA("MeshPart") then
		continue
	end
	local name = found.Name
	local mini, egg = string.match(name, "^mini_(.+)$"), string.match(name, "^egg_(.+)$")
	local world, piece = string.match(name, "^(%u%l+)_(%u%w+)$")
	local kind = string.match(string.lower(name), "^(%l+_crab)_") or string.match(string.lower(name), "^(%l+)_")
	if mini then
		-- Pivot at its middle, looking along the barrel with its X axis (Models.mini).
		local part = found:Clone()
		part.PivotOffset = part.CFrame:ToObjectSpace(CFrame.fromMatrix(part.Position, FRONT, Vector3.yAxis))
		part.Name = mini
		still(part)
		part.Parent = minis
		counts.minis += 1
	elseif egg then
		-- Pivot under its foot (Marketplace.buildEggStand).
		local part = found:Clone()
		part.PivotOffset = part.CFrame:ToObjectSpace(facing(found:GetPivot().Position))
		part.Name = egg
		still(part)
		part.Parent = eggs
		counts.eggs += 1
	elseif world and piece then
		local part = found:Clone()
		still(part)
		part.Material = MATERIALS[piece] or part.Material
		if SHELLS[piece] then
			local shells = islands:FindFirstChild(world .. "Shells") or Instance.new("Folder")
			shells.Name = world .. "Shells"
			shells.Parent = islands
			-- Pivot in the middle of its base, its front towards the pivot's -Z (Islands.wear).
			part.PivotOffset = part.CFrame:ToObjectSpace(facing(found:GetPivot().Position))
			part.Name = piece
			part.Parent = shells
		else
			local model = scenery[world] or Instance.new("Model")
			model.Name = world
			-- Every scenery mesh has the middle of the island, on the ground, as its origin. The game's north
			-- is -Z and Blender's (+Y) arrives opposite to FRONT, so the pivot looks that way.
			local middle = found:GetPivot().Position
			model.WorldPivot = CFrame.lookAt(middle, middle - FRONT)
			model.Parent = islands
			scenery[world] = model
			part.Name = piece
			part.Parent = model
		end
		counts.island += 1
	elseif kind and CREATURES[kind] then
		herds[kind] = herds[kind] or {}
		table.insert(herds[kind], found)
	end
end

for kind, parts in herds do
	local model = Instance.new("Model")
	model.Name = CREATURES[kind]
	local low, high = bounds(parts)
	local body: BasePart? = nil
	for _, original in parts do
		local part = original:Clone()
		part.Name = string.gsub(string.sub(original.Name, #kind + 2), "%.%d+$", "")
		part.Color = colours[original.Name] or part.Color
		still(part)
		part.Parent = model
		if part.Name == "Body" or not body or (body.Name ~= "Body" and part.Size.Magnitude > body.Size.Magnitude) then
			body = part
		end
	end
	-- The model's pivot is on the ground under its middle, facing -Z (Models.monster).
	local foot = facing(Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2))
	if body then
		body.PivotOffset = body.CFrame:ToObjectSpace(foot)
		model.PrimaryPart = body
	end
	model.Parent = creatures
	counts.creatures += 1
end

ChangeHistoryService:SetWaypoint("Organize imported models")
print(`[organize_imports] mini cannons {counts.minis}/25, eggs {counts.eggs}/5, island pieces {counts.island}/13, creatures {counts.creatures}/6`)
