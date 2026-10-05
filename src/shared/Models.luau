-- Monster and tower models, built from plain parts in code. Shared, so both sides can build them: the server
-- stands the towers on the plots (src/server/Plots.luau), each client builds the monsters it draws.
--
-- Both are built standing at the origin and FACING -Z (the way CFrame.lookAt looks), with the model's pivot on
-- the ground under its middle. So
--     model:PivotTo(CFrame.lookAt(position, position + direction))
-- stands it at `position` looking along `direction` (keep the direction level).
-- Every part is anchored and nothing collides, so a model can never block the path or trap a player.
local Config = require(script.Parent.Config)

local Models = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local rgb = Color3.fromRGB

local CYLINDER = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local PLASTIC = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or PLASTIC
	part.Parent = parent
	return part
end

-- A cylinder's long axis is its X axis; this points that axis along `direction` (straight up included).
local function along(position: Vector3, direction: Vector3): CFrame
	if math.abs(direction.Y) > 0.999 then
		return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	end
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
end

-- Makes `part` the model's PrimaryPart and puts the model's pivot at `pivot`, wherever the part itself is.
local function setPivot(model: Model, part: BasePart, pivot: CFrame)
	part.PivotOffset = part.CFrame:ToObjectSpace(pivot)
	model.PrimaryPart = part
end

----------------------------------------------------------------------------------------------------
-- Monsters: six archetypes. def is what Config.monsterFor(level) returns: shape, color, accent, kind, scale.
-- Offsets are in units of scale, from the body's centre 1.4 units above the ground.
-- The PrimaryPart is the Body. Attributes: Scale, and Height (the top of the model above the ground, for
-- whatever floats over it).
----------------------------------------------------------------------------------------------------
local CENTER_HEIGHT = 1.4

local function piece(model: Model, name: string, size: Vector3, position: Vector3, color: Color3, shape: string?): Part
	local part = newPart(model, name, size, CFrame.new(position), color, PLASTIC, if shape == "ball" then BALL else nil)
	if shape == "ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	return part
end

local function eyes(model: Model, center: Vector3, s: number, spacing: number, height: number, depth: number, size: number)
	for _, side in { -1, 1 } do
		local offset = Vector3.new(side * spacing, height, -depth) * s
		piece(model, "Eye", Vector3.one * size * s, center + offset, WHITE, "ball")
		piece(model, "Pupil", Vector3.one * size * 0.5 * s, center + offset + Vector3.new(0, 0, -size * 0.38 * s), BLACK, "ball")
	end
end

-- Each archetype builds its parts (Body first) and returns how high above the centre a boss's horns stand.
local ARCHETYPES = {}

-- A slime sitting in its own puddle.
function ARCHETYPES.blob(model: Model, center: Vector3, s: number, def)
	piece(model, "Body", Vector3.new(2.6, 2, 2.6) * s, center + Vector3.new(0, -0.4, 0) * s, def.color, "ellipsoid")
	piece(model, "Puddle", Vector3.new(3.2, 0.4, 3.2) * s, center + Vector3.new(0, -1.2, 0) * s, def.accent, "ellipsoid")
	eyes(model, center, s, 0.5, 0, 1.12, 0.5)
	piece(model, "Mouth", Vector3.new(0.7, 0.16, 0.2) * s, center + Vector3.new(0, -0.62, -1.2) * s, BLACK)
	return 0.6
end

function ARCHETYPES.biped(model: Model, center: Vector3, s: number, def)
	piece(model, "Body", Vector3.new(1.7, 1.8, 1.1) * s, center + Vector3.new(0, -0.5, 0) * s, def.color)
	piece(model, "Head", Vector3.one * 1.5 * s, center + Vector3.new(0, 1.1, 0) * s, def.color, "ball")
	for _, side in { -1, 1 } do
		piece(model, "Arm", Vector3.new(0.5, 1.5, 0.5) * s, center + Vector3.new(side * 1.15, -0.35, 0) * s, def.accent)
		piece(model, "Foot", Vector3.new(0.7, 0.35, 1.05) * s, center + Vector3.new(side * 0.45, -1.225, -0.25) * s, def.accent)
	end
	eyes(model, center, s, 0.33, 1.2, 0.66, 0.4)
	return 1.85
end

function ARCHETYPES.floater(model: Model, center: Vector3, s: number, def)
	piece(model, "Body", Vector3.one * 2.3 * s, center + Vector3.new(0, 0.4, 0) * s, def.color, "ball")
	piece(model, "Tail", Vector3.one * 0.6 * s, center + Vector3.new(0, -1.05, 0) * s, def.accent)
	for _, side in { -1, 1 } do
		piece(model, "Fin", Vector3.new(0.25, 0.9, 1) * s, center + Vector3.new(side * 1.22, 0.5, 0.25) * s, def.accent)
	end
	piece(model, "Eye", Vector3.one * 1.1 * s, center + Vector3.new(0, 0.5, -0.8) * s, WHITE, "ball")
	piece(model, "Pupil", Vector3.one * 0.5 * s, center + Vector3.new(0, 0.5, -1.3) * s, BLACK, "ball")
	return 1.55
end

function ARCHETYPES.crawler(model: Model, center: Vector3, s: number, def)
	piece(model, "Body", Vector3.new(2.6, 1, 2) * s, center + Vector3.new(0, -0.9, 0) * s, def.color)
	piece(model, "Stripe", Vector3.new(0.6, 0.24, 2.1) * s, center + Vector3.new(0, -0.36, 0) * s, def.accent)
	for _, side in { -1, 1 } do
		piece(model, "Stalk", Vector3.new(0.2, 0.8, 0.2) * s, center + Vector3.new(side * 0.6, 0, -0.6) * s, def.accent)
		piece(model, "Claw", Vector3.new(0.8, 0.6, 0.8) * s, center + Vector3.new(side * 1.6, -0.9, -0.9) * s, def.accent)
	end
	eyes(model, center, s, 0.6, 0.55, 0.6, 0.5)
	return 0.8
end

-- A dome trailing four tentacles, hovering just off the ground.
function ARCHETYPES.jelly(model: Model, center: Vector3, s: number, def)
	piece(model, "Body", Vector3.new(2.5, 1.7, 2.5) * s, center + Vector3.new(0, 0.55, 0) * s, def.color, "ellipsoid")
	for _, x in { -0.55, 0.55 } do
		for _, z in { -0.45, 0.45 } do
			-- Every tentacle starts inside the dome; the front two are shorter.
			local length = if z < 0 then 1.1 else 1.3
			piece(model, "Tentacle", Vector3.new(0.28, length, 0.28) * s, center + Vector3.new(x, 0.1 - length / 2, z) * s, def.accent)
		end
	end
	eyes(model, center, s, 0.5, 0.6, 1.15, 0.5)
	return 1.4
end

-- A ball bristling with spikes: one straight up, one out of the back, one out of each side and a stub between.
function ARCHETYPES.spiker(model: Model, center: Vector3, s: number, def)
	local middle = center + Vector3.new(0, -0.45, 0) * s
	piece(model, "Body", Vector3.one * 1.9 * s, middle, def.color, "ball")
	piece(model, "Spike", Vector3.new(0.4, 0.8, 0.4) * s, middle + Vector3.new(0, 1.2, 0) * s, def.accent)
	piece(model, "Spike", Vector3.new(0.4, 0.4, 0.55) * s, middle + Vector3.new(0, 0, 0.97) * s, def.accent)
	for _, side in { -1, 1 } do
		piece(model, "Spike", Vector3.new(0.55, 0.4, 0.4) * s, middle + Vector3.new(side * 0.97, 0, 0) * s, def.accent)
		piece(model, "Spike", Vector3.one * 0.45 * s, middle + Vector3.new(side * 0.68, 0.68, 0) * s, def.accent)
	end
	eyes(model, center, s, 0.38, -0.3, 0.85, 0.45)
	-- The top of the ball, not of the spike: a boss's horns stand either side of the spike.
	return 0.5
end

-- Modelled mini cannons (tools/blender/minis.py, imported as ReplicatedStorage.MiniCannons): one MeshPart per
-- mini cannon, named by its id, with its colours on the vertices. Fused and enchanted ones share the model of
-- the plain one they are made from. The part's pivot is at its middle and looks along its barrel with its X
-- axis, the way the old part-built barrel did, so the code that moves and fires them is unchanged.
-- Returns nil for a mini cannon without a model yet: the caller builds the old one from parts.
local MINI_SIZE = 2.4 -- studs across its longest side at scale 1
function Models.mini(pet, scale: number?): MeshPart?
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("MiniCannons")
	if not folder then
		return nil
	end
	local plain = Config.Pets[pet.plain] or pet
	local template = folder:FindFirstChild(plain.base or pet.plain or "")
	if not template or not template:IsA("MeshPart") then
		return nil
	end
	local part = template:Clone()
	local fit = MINI_SIZE * (scale or 1) / math.max(part.Size.X, part.Size.Y, part.Size.Z)
	part.Size *= fit
	part.PivotOffset = CFrame.new(part.PivotOffset.Position * fit) * part.PivotOffset.Rotation
	part.Name = "Barrel"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Modelled creatures (made in Blender, tools/blender, and imported into the place as ReplicatedStorage.Creatures).
-- A monster with a template there by its name uses it; a named boss without one uses "Boss". Anything else
-- is still built from parts below.
local CREATURE_HEIGHT = 2 -- studs tall per unit of the monster's scale, whatever size the template was modelled at
local function creatureFor(def): Model?
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Creatures")
	if not folder or not def.name then
		return nil
	end
	local template = folder:FindFirstChild(def.name)
	if not template and def.kind and def.kind ~= "normal" then
		template = folder:FindFirstChild("Boss")
	end
	return if template and template:IsA("Model") and template.PrimaryPart then template else nil
end

-- A monster of `def`, standing at the origin and facing -Z. Bosses (any kind but "normal") wear horns.
function Models.monster(def, parent: Instance?): Model
	local template = creatureFor(def)
	if template then
		local creature = template:Clone()
		creature.Name = "Monster"
		local scale = def.scale or 1
		creature:ScaleTo(CREATURE_HEIGHT * scale / template:GetExtentsSize().Y)
		creature:PivotTo(CFrame.new())
		creature:SetAttribute("Scale", scale)
		creature:SetAttribute("Height", creature:GetExtentsSize().Y)
		creature.Parent = parent
		return creature
	end
	local model = Instance.new("Model")
	model.Name = "Monster"
	local s = def.scale or 1
	local center = Vector3.new(0, CENTER_HEIGHT * s, 0)
	local accent = def.accent or def.color
	local look = { color = def.color, accent = accent }
	local top = (ARCHETYPES[def.shape] or ARCHETYPES.blob)(model, center, s, look)
	if def.kind and def.kind ~= "normal" then
		for _, side in { -1, 1 } do
			piece(model, "Horn", Vector3.new(0.35, 0.8, 0.35) * s, center + Vector3.new(side * 0.45, top + 0.3, 0) * s, accent)
		end
	end
	local body = model:FindFirstChild("Body") :: Part
	setPivot(model, body, CFrame.new())
	-- No part is turned, so the highest top is the model's.
	local height = 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			height = math.max(height, part.Position.Y + part.Size.Y / 2)
		end
	end
	model:SetAttribute("Scale", s)
	model:SetAttribute("Height", height)
	model.Parent = parent
	return model
end

----------------------------------------------------------------------------------------------------
-- Towers: one silhouette per kind, coloured by tier.
--   tier  = Models.towerTier(level): Config.Cannons[tier] is its name and colour (60 of them, five per world)
--   step  = where the tier is inside its set of five: one more band on the barrel for each
--   rank  = which set of five (1 to 12): a bigger tower on a grander plinth
-- A tower is a Model named "Tower" with attributes Kind, Level and Tier, holding:
--   Base    the plinth, the PrimaryPart. The model's pivot is the middle of its foot.
--   Turret  a Model: everything that turns. Its pivot is on the tower's upright axis and looks along the
--           barrel, so this aims it at a point:
--               local pivot = turret:GetPivot().Position
--               turret:PivotTo(CFrame.lookAt(pivot, Vector3.new(target.X, pivot.Y, target.Z)))
--   Muzzle  a part inside Turret, at the end of the barrel: where shots leave.
-- Sizes below are for a rank 1 tower; a pad is Layout.PAD_SIZE wide and the biggest tower still fits on it,
-- whichever way its turret is turned.
----------------------------------------------------------------------------------------------------
local WOOD = rgb(120, 84, 56)
local STONE = rgb(150, 150, 158)
local DARK = rgb(44, 46, 54)
local STEEL = rgb(70, 74, 86)
local MARBLE = rgb(235, 235, 240)
local GOLD = rgb(255, 200, 40)
local BAND = rgb(245, 245, 245)

local RANK_GROWTH = 0.025 -- a tower is this much bigger for every rank
local FOOT_RADIUS = 2.74 -- the widest thing on a tower, at rank 1

-- What tells the kinds apart besides their shape: one glowing detail each.
local ACCENTS = {
	cannon = rgb(255, 170, 60),
	gatling = rgb(255, 70, 60),
	mortar = rgb(255, 120, 40),
	sniper = rgb(120, 255, 140),
	frost = rgb(130, 225, 255),
	flame = rgb(255, 130, 30),
	tesla = rgb(255, 240, 110),
}

function Models.towerTier(level: number): number
	return Config.towerTier(math.max(1, math.floor(level)))
end

-- The plinth for each rank: colour and material of the plinth itself, and of the step under it from rank 4.
local function plinthStyle(rank: number): (Color3, Enum.Material, Color3)
	if rank <= 1 then
		return WOOD, Enum.Material.WoodPlanks, WOOD
	elseif rank <= 3 then
		return STONE, Enum.Material.Slate, STONE
	elseif rank <= 6 then
		return STEEL, METAL, DARK
	elseif rank <= 9 then
		return MARBLE, Enum.Material.Marble, STEEL
	end
	return DARK, Enum.Material.Marble, GOLD
end

-- Each kind builds its turret with the kit and returns the height of its top and the part its turret turns by.
local KINDS = {}

-- The classic: a fat barrel on a wheeled carriage.
function KINDS.cannon(kit)
	local top = kit.top
	local direction = Vector3.new(0, math.sin(math.rad(12)), -math.cos(math.rad(12)))
	local center = Vector3.new(0, top + 1.95, -0.4)
	local front, back = center + direction * 2.1, center - direction * 2.1
	local barrel = kit.rod(kit.turret, "Barrel", 4.2, 1.6, center, direction, kit.color, kit.metal)
	barrel.CastShadow = true
	kit.rod(kit.turret, "Muzzle", 0.5, 2, front - direction * 0.25, direction, kit.shade, kit.metal)
	kit.rod(kit.turret, "Bore", 0.12, 1.1, front + direction * 0.02, direction, BLACK)
	kit.orb(kit.turret, "Breech", 1.75, back, kit.shade, kit.metal)
	kit.block(kit.turret, "Carriage", Vector3.new(2.2, 0.9, 3), Vector3.new(0, top + 0.65, 0.3), kit.frame, kit.frameMaterial)
	for _, side in { -1, 1 } do
		kit.rod(kit.turret, "Wheel", 0.5, 2.3, Vector3.new(side * 1.4, top + 1.15, 0.4), Vector3.xAxis, DARK)
	end
	kit.bands(kit.turret, front - direction * 0.8, -direction, 1.95, 0.3, { 0, 0.6, 1.2, 1.8, 2.4 })
	return top + 3.3, top + 1.4, barrel
end

-- Three thin barrels in a bundle, an ammo drum on its side and a sight on top, up on a post.
function KINDS.gatling(kit)
	local top = kit.top
	local y = top + 2.25
	kit.rod(kit.tower, "Post", 1.5, 1.1, Vector3.new(0, top + 0.75, 0), Vector3.yAxis, DARK, METAL)
	local body = kit.block(kit.turret, "Body", Vector3.new(1.7, 1.5, 2.2), Vector3.new(0, y, 1.3), kit.shade, kit.metal)
	body.CastShadow = true
	for _, offset in { Vector2.new(0, 0.36), Vector2.new(0.31, -0.18), Vector2.new(-0.31, -0.18) } do
		kit.rod(kit.turret, "Barrel", 2.8, 0.45, Vector3.new(offset.X, y + offset.Y, -1.2), -Vector3.zAxis, kit.color, kit.metal)
	end
	kit.rod(kit.turret, "Muzzle", 0.3, 1.4, Vector3.new(0, y, -2.45), -Vector3.zAxis, DARK, METAL)
	kit.rod(kit.turret, "Drum", 0.8, 1.7, Vector3.new(-1.25, y - 0.15, 1.3), Vector3.xAxis, DARK, METAL)
	kit.block(kit.turret, "Sight", Vector3.new(0.3, 0.5, 0.6), Vector3.new(0, y + 0.95, 1.6), kit.accent, NEON)
	kit.bands(kit.turret, Vector3.new(0, y, -1.9), Vector3.zAxis, 1.25, 0.2, { 0, 0.45, 0.9, 1.35, 1.8 })
	return top + 3.5, y, body
end

-- A short, very fat tube aimed at the sky, between two cheeks.
function KINDS.mortar(kit)
	local top = kit.top
	local direction = Vector3.new(0, math.sin(math.rad(62)), -math.cos(math.rad(62)))
	local center = Vector3.new(0, top + 2.2, -0.05)
	local front, back = center + direction * 1.5, center - direction * 1.5
	local tube = kit.rod(kit.turret, "Barrel", 3, 2.5, center, direction, kit.color, kit.metal)
	tube.CastShadow = true
	kit.rod(kit.turret, "Muzzle", 0.5, 3, front - direction * 0.25, direction, kit.shade, kit.metal)
	kit.rod(kit.turret, "Bore", 0.12, 1.9, front + direction * 0.02, direction, BLACK)
	kit.orb(kit.turret, "Breech", 2.5, back, kit.shade, kit.metal)
	kit.block(kit.turret, "Cradle", Vector3.new(3.4, 0.7, 3.4), Vector3.new(0, top + 0.35, 0), kit.frame, kit.frameMaterial)
	for _, side in { -1, 1 } do
		kit.block(kit.turret, "Cheek", Vector3.new(0.5, 1.7, 1.5), Vector3.new(side * 1.45, top + 1.5, 0.15), DARK, METAL)
	end
	kit.bands(kit.turret, front - direction * 0.8, -direction, 2.85, 0.3, { 0, 0.45, 0.9, 1.35, 1.8 })
	return top + 4.2, top + 1.2, tube
end

-- Tall and thin: a long barrel and a scope on top of a mast.
function KINDS.sniper(kit)
	local top = kit.top
	local y = top + 4.45
	kit.rod(kit.tower, "Mast", 3.4, 1, Vector3.new(0, top + 1.7, 0), Vector3.yAxis, DARK, METAL)
	kit.rod(kit.tower, "Collar", 0.5, 1.8, Vector3.new(0, top + 3.65, 0), Vector3.yAxis, kit.shade, kit.metal)
	local housing = kit.block(kit.turret, "Housing", Vector3.new(1.1, 1.1, 2.4), Vector3.new(0, y, 1.2), kit.color, kit.metal)
	housing.CastShadow = true
	kit.rod(kit.turret, "Barrel", 2.8, 0.5, Vector3.new(0, y, -1.3), -Vector3.zAxis, kit.color, kit.metal)
	kit.rod(kit.turret, "Muzzle", 0.55, 0.9, Vector3.new(0, y, -2.42), -Vector3.zAxis, DARK, METAL)
	kit.rod(kit.turret, "Scope", 1.5, 0.55, Vector3.new(0, y + 0.85, 1), -Vector3.zAxis, DARK, METAL)
	kit.rod(kit.turret, "Lens", 0.1, 0.5, Vector3.new(0, y + 0.85, 0.22), -Vector3.zAxis, kit.accent, NEON)
	kit.bands(kit.turret, Vector3.new(0, y, -1.9), Vector3.zAxis, 0.8, 0.2, { 0, 0.4, 0.8, 1.2, 1.6 })
	return top + 5.7, top + 4, housing
end

-- A glowing ice crystal on a stem, ringed by shards, with a short nozzle.
function KINDS.frost(kit)
	local top = kit.top
	local y = top + 3.4
	local ice = Enum.Material.Ice
	local stem = kit.rod(kit.tower, "Stem", 2.2, 1.6, Vector3.new(0, top + 1.1, 0), Vector3.yAxis, rgb(225, 240, 255), ice)
	stem.CastShadow = true
	local crystal = kit.block(
		kit.turret,
		"Crystal",
		Vector3.one * 1.9,
		Vector3.new(0, y, 0),
		kit.accent,
		NEON,
		CFrame.Angles(math.rad(45), 0, math.rad(45))
	)
	-- Three shards lean out from under the crystal; none stands in front, where the nozzle is.
	for _, degrees in { 60, 180, 300 } do
		local turn = CFrame.Angles(0, math.rad(degrees), 0)
		local position = turn * Vector3.new(0, 0, -1.45)
		kit.block(kit.turret, "Shard", Vector3.new(0.45, 1.5, 0.45), position + Vector3.new(0, y - 0.8, 0), kit.color, ice, turn * CFrame.Angles(math.rad(-28), 0, 0))
	end
	kit.rod(kit.turret, "Nozzle", 1.5, 0.9, Vector3.new(0, y, -1.7), -Vector3.zAxis, kit.color, kit.metal)
	kit.rod(kit.turret, "Muzzle", 0.3, 1.25, Vector3.new(0, y, -2.5), -Vector3.zAxis, WHITE, NEON)
	kit.bands(kit.tower, Vector3.new(0, top + 0.35, 0), Vector3.yAxis, 2, 0.22, { 0, 0.4, 0.8, 1.2, 1.6 })
	return top + 5.1, y, crystal
end

-- Two round fuel tanks feeding one pipe, with a glowing nozzle.
function KINDS.flame(kit)
	local top = kit.top
	local y = top + 1.9
	local pipe = kit.rod(kit.turret, "Pipe", 2.6, 0.8, Vector3.new(0, y, -0.7), -Vector3.zAxis, kit.shade, kit.metal)
	for _, side in { -1, 1 } do
		kit.orb(kit.turret, "Tank", 2.1, Vector3.new(side, y, 1.3), kit.color, kit.metal).CastShadow = true
	end
	kit.block(kit.turret, "Cap", Vector3.new(0.9, 0.5, 0.9), Vector3.new(0, y + 0.75, 1.3), DARK, METAL)
	kit.block(kit.turret, "Stand", Vector3.new(1.8, 1, 2.2), Vector3.new(0, top + 0.5, 0.5), kit.frame, kit.frameMaterial)
	kit.rod(kit.turret, "Muzzle", 0.7, 1.4, Vector3.new(0, y, -2.3), -Vector3.zAxis, DARK, METAL)
	kit.rod(kit.turret, "Flame", 0.2, 1, Vector3.new(0, y, -2.57), -Vector3.zAxis, kit.accent, NEON)
	kit.bands(kit.turret, Vector3.new(0, y, -1.6), Vector3.zAxis, 1.1, 0.22, { 0, 0.4, 0.8, 1.2, 1.6 })
	return top + 3.2, y, pipe
end

-- A coil: three shrinking discs up a pole, and a glowing ball on top between two prongs.
function KINDS.tesla(kit)
	local top = kit.top
	local y = top + 4.7
	kit.rod(kit.tower, "Pole", 4, 0.9, Vector3.new(0, top + 2, 0), Vector3.yAxis, DARK, METAL)
	for index, radius in { 1.9, 1.5, 1.1 } do
		kit.rod(kit.tower, "Coil", 0.45, radius * 2, Vector3.new(0, top + index - 0.1, 0), Vector3.yAxis, kit.color, kit.metal).CastShadow = true
	end
	local orb = kit.orb(kit.turret, "Muzzle", 1.7, Vector3.new(0, y, 0), kit.accent, NEON)
	for _, side in { -1, 1 } do
		kit.block(kit.turret, "Prong", Vector3.new(0.3, 1.5, 0.3), Vector3.new(side * 1.2, y + 0.2, 0), DARK, METAL, CFrame.Angles(0, 0, math.rad(-25 * side)))
	end
	kit.block(kit.turret, "Emitter", Vector3.new(0.3, 0.3, 1.2), Vector3.new(0, y, -1.2), DARK, METAL)
	kit.bands(kit.tower, Vector3.new(0, top + 0.4, 0), Vector3.yAxis, 1.3, 0.2, { 1, 2, 3, 0, 3.4 })
	return top + 5.7, y, orb
end

-- A tower of `kind` at `level`, standing at the origin with its barrel towards -Z.
-- A kind this file does not know is built as a plain cannon.
function Models.tower(kind: string, level: number, parent: Instance?): Model
	local tier = Models.towerTier(level)
	local info = Config.Cannons[tier]
	local rank = math.ceil(tier / Config.CannonsPerWorld)
	local step = (tier - 1) % Config.CannonsPerWorld + 1
	local s = 1 + RANK_GROWTH * (math.min(rank, 12) - 1)

	local tower = Instance.new("Model")
	tower.Name = "Tower"
	local turret = Instance.new("Model")
	turret.Name = "Turret"
	turret.Parent = tower

	-- The kit builds in rank 1 sizes and scales everything by `s`.
	local kit = {}
	function kit.block(into: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, rotation: CFrame?): Part
		local cframe = CFrame.new(position * s)
		return newPart(into, name, size * s, if rotation then cframe * rotation else cframe, color, material)
	end
	function kit.rod(into: Instance, name: string, length: number, diameter: number, position: Vector3, direction: Vector3, color: Color3, material: Enum.Material?): Part
		return newPart(into, name, Vector3.new(length, diameter, diameter) * s, along(position * s, direction), color, material, CYLINDER)
	end
	function kit.orb(into: Instance, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
		return newPart(into, name, Vector3.one * diameter * s, CFrame.new(position * s), color, material, BALL)
	end
	-- One white band per step, at `offsets` along `direction` from `from`.
	function kit.bands(into: Instance, from: Vector3, direction: Vector3, diameter: number, thickness: number, offsets: { number })
		for band = 1, math.min(step, #offsets) do
			kit.rod(into, "Band", thickness, diameter, from + direction * offsets[band], direction, BAND, METAL)
		end
	end

	-- The plinth: taller and richer with rank.
	local plinthColor, plinthMaterial, footColor = plinthStyle(rank)
	local top = 0
	if rank >= 4 then
		kit.rod(tower, "Foot", 0.5, FOOT_RADIUS * 2, Vector3.new(0, 0.25, 0), Vector3.yAxis, footColor, METAL)
		top = 0.5
	end
	local base = kit.rod(tower, "Base", 1, 5, Vector3.new(0, top + 0.5, 0), Vector3.yAxis, plinthColor, plinthMaterial)
	base.CastShadow = true
	top += 1
	if rank >= 7 then
		-- A ring of light around the turntable.
		kit.rod(tower, "Glow", 0.16, 4.7, Vector3.new(0, top + 0.08, 0), Vector3.yAxis, info.color, NEON)
	end
	if rank >= 2 then
		kit.rod(tower, "Turntable", 0.3, 4.2, Vector3.new(0, top + 0.15, 0), Vector3.yAxis, info.color, METAL)
		top += 0.3
	end

	kit.tower, kit.turret, kit.top = tower, turret, top
	kit.color = info.color
	kit.shade = info.color:Lerp(BLACK, 0.3)
	kit.metal = if rank >= 5 then NEON else METAL -- as the big cannon was: from the fifth world on they glow
	kit.accent = ACCENTS[kind] or ACCENTS.cannon
	kit.frame = if rank <= 3 then WOOD else DARK
	kit.frameMaterial = if rank <= 3 then Enum.Material.Wood else METAL

	local crown, pivotHeight, turns = (KINDS[kind] or KINDS.cannon)(kit)
	if rank >= 10 then
		local halo = kit.rod(tower, "Halo", 0.12, 2.4, Vector3.new(0, crown + 0.9, 0), Vector3.yAxis, GOLD, NEON)
		halo.Transparency = 0.3
	end

	setPivot(turret, turns, CFrame.new(0, pivotHeight * s, 0))
	setPivot(tower, base, CFrame.new())
	tower:SetAttribute("Kind", kind)
	tower:SetAttribute("Level", level)
	tower:SetAttribute("Tier", tier)
	tower.Parent = parent
	return tower
end

return Models
