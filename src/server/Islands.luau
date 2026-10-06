-- The world islands: one per world (Config.Worlds), all built from one template and dressed from that
-- world's colours and monsters. On each: the world's two coin eggs, a shop stall (the ISLAND SHOP window,
-- Features/IslandShop), a portal back to the plot, an arrival pad, a statue of the world's boss, and two empty
-- 12 x 12 spots for the modules that come later (the mastery shrine, the enchanting table).
--
-- Everything is laid out in island space (Layout.islandCFrame): the middle of the island is the origin, x
-- east, z south, the ground's top at y = 0. Players arrive in the middle (Layout.islandSpawn) and look north,
-- at the eggs. Everything with a prompt stands in a tight ring around the arrival pad, 15 to 16 studs from
-- it and facing it, so nothing is more than a few steps away; the statues and the scenery stand at the rim.
-- Travel is the core's: the `goIsland` action asks Game.places.island, which this module registers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Models = require(ReplicatedStorage.Shared.Models)
local Build = require(script.Parent.Build)
local Game = require(script.Parent.Game)
local Marketplace = require(script.Parent.Marketplace)

local Islands = {}

Islands.SHOP_WINDOW = "ISLAND SHOP" -- the window a stall's prompt opens (src/client/Features/IslandShop.luau)
Islands.returnPrompts = {} :: { [number]: ProximityPrompt } -- [island] = its portal back to the plot
Islands.shopPrompts = {} :: { [number]: ProximityPrompt } -- [island] = its stall's prompt

local rgb = Color3.fromRGB
local STONE = rgb(206, 200, 190)
local WOOD = rgb(150, 104, 66)
local DARK = rgb(44, 46, 54)
local GOLD = rgb(255, 200, 40)
local CREAM = rgb(255, 246, 225)
local M = Enum.Material
local PLASTIC = M.SmoothPlastic
local NEON = M.Neon

local RADIUS = Layout.ISLAND_RADIUS
local RIM_PIECES = 16
local RIM_HEIGHT = 9 -- higher than a jump, so nobody walks off the edge
local SPOT_SIZE = 12
-- A point of island space (x, z) on a circle around the middle: 0 degrees is north, 90 east.
local function ring(degrees: number, radius: number): Vector2
	local angle = math.rad(degrees)
	return Vector2.new(math.sin(angle), -math.cos(angle)) * radius
end

-- Where things stand, in island space (x, z). The ring around the arrival pad, clockwise from the north:
-- the two eggs, the stall, the portal home, the enchant spot, the mastery spot. Neighbours are 12 studs or
-- more apart. The enchant spot has the widest gap on both sides because it holds two things (the enchanting
-- table and the fusion machine): 5 studs left and right of its middle (x = -5 and x = 5 in the spot's frame)
-- they are 10 apart, 16.8 from the arrival pad and 13 or more from the portal and the shrine.
local ARRIVAL = Vector2.new(0, 0) -- Layout.islandSpawn: keep the two together
local EGGS = { ring(-25, 15), ring(25, 15) }
local STALL = ring(75, 15)
local PORTAL = ring(140, 15)
local SPOTS = { mastery = ring(282, 16), enchant = ring(207, 16) }
local PLAZA_RADIUS = 25 -- the paving under the ring
local LAMPS = { ring(45, 36), ring(135, 36), ring(225, 36), ring(315, 36) }
local BOSS = ring(0, 44) -- the boss's statue, at the north rim behind the eggs
local STATUES = { ring(270, 47), ring(90, 47) } -- two of the world's monsters, at the west and east rim
-- Props stand in a ring near the rim, clear of everything above.
local PROP_ANGLES = { 20, 42, 64, 116, 138, 160, 200, 218, 236, 304, 322, 340 }
local PROP_RADIUS = 49

-- For a world with a Blender island (see `wear`): the parts built here that it covers, by name; how high an
-- egg stands on its pedestal (CUSHION_TOP in tools/blender/earth_island.py); and its boss statue's size.
local UNSEEN = {
	Ground = true, Plaza = true, Rim = true, ArrivalPad = true,
	PortalPillar = true, PortalBeam = true, Portal = true,
	Counter = true, StallPost = true, Awning = true, StallSign = true, StallShell = true, StallChest = true,
	LampPost = true, Lamp = true, Plinth = true, Fountain = true, SignOrb = true,
}
local PEDESTAL_TOP = 3
local DRESSED_BOSS_SCALE = 4.5
-- What is solid on a Blender island, by world: its meshes do not collide, so each trunk, post and prop a
-- player can walk into gets an unseen pillar { x, z, radius, height } in island space. Read off the model
-- (island.py writes each world's list as <world>_island_solids.txt); the fence is left to the rim wall.
local SOLIDS = {
	Earth = {
		{ -11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ 11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ -36.5, 24.6, 2.6, 3.4 }, -- cannon
		{ 25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ 25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ 40.6, 25.5, 1.3, 1.9 }, -- log seat
		{ 32.0, 21.5, 1.2, 1.9 }, -- log seat
		{ 39.0, 16.6, 1.3, 1.9 }, -- log seat
		{ -15.9, -49.0, 1.2, 8.3 }, -- tree
		{ 15.9, -49.0, 1.2, 8.7 }, -- tree
		{ -29.0, -41.4, 1.0, 7.3 }, -- tree
		{ 29.0, -41.4, 1.1, 7.6 }, -- tree
		{ 40.7, -30.7, 1.1, 7.6 }, -- tree
		{ 46.8, -18.9, 0.9, 6.6 }, -- tree
		{ 46.8, 18.9, 1.0, 6.9 }, -- tree
		{ 40.2, 31.4, 0.9, 6.2 }, -- tree
		{ 31.0, 41.1, 0.7, 5.2 }, -- tree
		{ -3.6, 51.4, 0.7, 4.8 }, -- tree
		{ -20.7, 46.6, 0.7, 5.2 }, -- tree
		{ -35.4, 36.7, 0.8, 5.9 }, -- tree
		{ -48.5, 15.8, 1.1, 7.6 }, -- tree
		{ -47.5, -17.3, 1.0, 7.3 }, -- tree
		{ -40.7, -30.7, 1.1, 8.0 }, -- tree
		{ 37.1, -12.1, 0.8, 5.5 }, -- tree
		{ 36.6, 11.9, 0.8, 5.5 }, -- tree
		{ -36.6, 13.3, 0.8, 5.9 }, -- tree
		{ -37.1, -12.1, 0.8, 5.9 }, -- tree
	},
	Moon = {
		{ -11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ 11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ 36.2, 26.4, 1.9, 2.6 }, -- control box
		{ 15.9, -49.0, 4.7, 6.5 }, -- crater rock
		{ -29.0, -41.4, 4.3, 6.0 }, -- crater rock
		{ 40.7, -30.7, 4.6, 6.3 }, -- crater rock
		{ 46.8, 18.9, 4.1, 5.8 }, -- crater rock
		{ 31.0, 41.1, 3.1, 4.3 }, -- crater rock
		{ -3.6, 51.4, 2.9, 4.0 }, -- crater rock
		{ -35.4, 36.7, 3.5, 4.9 }, -- crater rock
		{ -48.5, 15.8, 4.6, 6.3 }, -- crater rock
		{ -40.7, -30.7, 4.7, 6.5 }, -- crater rock
		{ 37.1, -12.1, 3.3, 4.6 }, -- crater rock
		{ -37.1, -12.1, 3.5, 4.9 }, -- crater rock
		{ -15.9, -49.0, 2.1, 16.9 }, -- crystal antenna
		{ 29.0, -41.4, 2.0, 16.4 }, -- crystal antenna
		{ 46.8, -18.9, 1.7, 14.2 }, -- crystal antenna
		{ 40.2, 31.4, 1.7, 13.5 }, -- crystal antenna
		{ -20.7, 46.6, 1.4, 11.2 }, -- crystal antenna
		{ -47.5, -17.3, 1.9, 15.7 }, -- crystal antenna
		{ 36.6, 11.9, 1.5, 12.0 }, -- crystal antenna
		{ -36.6, 13.3, 1.6, 12.7 }, -- crystal antenna
		{ -35.7, 18.2, 0.6, 7.5 }, -- flag
		{ 25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ 25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ -36.5, 24.6, 4.5, 11.2 }, -- lander
		{ 37.2, 21.5, 3.1, 8.8 }, -- radar dish
	},
	Mars = {
		{ 35.7, 27.1, 2.1, 4.0 }, -- air tanks
		{ 32.6, 18.8, 2.3, 4.0 }, -- airlock
		{ -11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ 11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ 37.2, 21.5, 5.7, 6.2 }, -- habitat
		{ 25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ 25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ 15.9, -49.0, 4.9, 13.0 }, -- mesa
		{ -29.0, -41.4, 4.6, 12.1 }, -- mesa
		{ 40.7, -30.7, 4.8, 12.6 }, -- mesa
		{ 46.8, 18.9, 4.4, 11.5 }, -- mesa
		{ 31.0, 41.1, 3.3, 8.6 }, -- mesa
		{ -3.6, 51.4, 3.1, 8.0 }, -- mesa
		{ -35.4, 36.7, 3.7, 9.8 }, -- mesa
		{ -48.5, 15.8, 4.8, 12.6 }, -- mesa
		{ -40.7, -30.7, 4.9, 13.0 }, -- mesa
		{ 37.1, -12.1, 3.5, 9.2 }, -- mesa
		{ -37.1, -12.1, 3.7, 9.8 }, -- mesa
		{ 0.9, 36.9, 0.9, 9.0 }, -- palm
		{ -15.9, -49.0, 3.1, 15.6 }, -- rock spire
		{ 29.0, -41.4, 3.0, 15.2 }, -- rock spire
		{ 46.8, -18.9, 2.6, 13.1 }, -- rock spire
		{ 40.2, 31.4, 2.5, 12.4 }, -- rock spire
		{ -20.7, 46.6, 2.1, 10.3 }, -- rock spire
		{ -47.5, -17.3, 2.9, 14.5 }, -- rock spire
		{ 36.6, 11.9, 2.2, 11.0 }, -- rock spire
		{ -36.6, 13.3, 2.3, 11.7 }, -- rock spire
		{ -36.5, 24.6, 4.8, 5.5 }, -- rover wreck
		{ -29.2, 26.7, 1.8, 1.6 }, -- wheel
	},
	Neptune = {
		{ -11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ 11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ -15.9, -49.0, 2.5, 15.6 }, -- ice spike
		{ 29.0, -41.4, 2.4, 15.2 }, -- ice spike
		{ 46.8, -18.9, 2.1, 13.1 }, -- ice spike
		{ 40.2, 31.4, 2.0, 12.4 }, -- ice spike
		{ -20.7, 46.6, 1.6, 10.3 }, -- ice spike
		{ -47.5, -17.3, 2.3, 14.5 }, -- ice spike
		{ 36.6, 11.9, 1.7, 11.0 }, -- ice spike
		{ -36.6, 13.3, 1.9, 11.7 }, -- ice spike
		{ 15.9, -49.0, 3.4, 11.7 }, -- ice spikes
		{ -29.0, -41.4, 3.1, 10.9 }, -- ice spikes
		{ 40.7, -30.7, 3.3, 11.4 }, -- ice spikes
		{ 46.8, 18.9, 3.0, 10.3 }, -- ice spikes
		{ 31.0, 41.1, 2.2, 7.8 }, -- ice spikes
		{ -3.6, 51.4, 2.1, 7.2 }, -- ice spikes
		{ -35.4, 36.7, 2.5, 8.8 }, -- ice spikes
		{ -48.5, 15.8, 3.3, 11.4 }, -- ice spikes
		{ -40.7, -30.7, 3.4, 11.7 }, -- ice spikes
		{ 37.1, -12.1, 2.4, 8.3 }, -- ice spikes
		{ -37.1, -12.1, 2.5, 8.8 }, -- ice spikes
		{ 37.2, 21.5, 5.5, 5.6 }, -- igloo
		{ 32.6, 18.8, 2.6, 3.6 }, -- igloo door
		{ 25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ 25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ 32.5, 25.3, 1.8, 1.5 }, -- snow blocks
		{ -36.5, 24.6, 3.8, 13.8 }, -- snowman
	},
	["The Sun"] = {
		{ -30.0, 25.2, 1.9, 3.6 }, -- anvil
		{ -11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ 11.0, -37.5, 1.0, 4.1 }, -- brazier
		{ -37.7, 25.4, 5.2, 7.0 }, -- forge
		{ 25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ 25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, 25.5, 0.6, 11.0 }, -- lamp
		{ -25.5, -25.5, 0.6, 11.0 }, -- lamp
		{ -35.1, 18.4, 1.8, 2.1 }, -- lava bucket
		{ 15.9, -49.0, 4.9, 8.5 }, -- lava cone
		{ -29.0, -41.4, 4.6, 7.8 }, -- lava cone
		{ 40.7, -30.7, 4.8, 8.2 }, -- lava cone
		{ 46.8, 18.9, 4.4, 7.5 }, -- lava cone
		{ 31.0, 41.1, 3.3, 5.6 }, -- lava cone
		{ -3.6, 51.4, 3.1, 5.2 }, -- lava cone
		{ -35.4, 36.7, 3.7, 6.4 }, -- lava cone
		{ -48.5, 15.8, 4.8, 8.2 }, -- lava cone
		{ -40.7, -30.7, 4.9, 8.5 }, -- lava cone
		{ 37.1, -12.1, 3.5, 6.0 }, -- lava cone
		{ -37.1, -12.1, 3.7, 6.4 }, -- lava cone
		{ -15.9, -49.0, 3.4, 14.3 }, -- lava spire
		{ 29.0, -41.4, 3.3, 13.9 }, -- lava spire
		{ 46.8, -18.9, 2.8, 12.0 }, -- lava spire
		{ 40.2, 31.4, 2.7, 11.4 }, -- lava spire
		{ -20.7, 46.6, 2.2, 9.5 }, -- lava spire
		{ -47.5, -17.3, 3.1, 13.3 }, -- lava spire
		{ 36.6, 11.9, 2.4, 10.1 }, -- lava spire
		{ -36.6, 13.3, 2.5, 10.8 }, -- lava spire
		{ 37.2, 21.5, 4.8, 6.0 }, -- volcano vent
	},
}

-- The rest of a world's look: what its ground is made of and which prop stands around. A world added to
-- Config without a line here borrows one (the list wraps around).
--   tree    a trunk with a ball of leaves        rock    a boulder
--   spire   a leaning shard                      orb     a ball floating over a small base
--   crate   a machine block with a light on it
local THEMES = {
	{ ground = M.Grass, prop = "tree" }, -- Earth
	{ ground = M.Slate, prop = "rock" }, -- Moon
	{ ground = M.Sand, prop = "rock", second = "spire" }, -- Mars
	{ ground = M.Ice, prop = "spire", material = M.Ice }, -- Neptune
	{ ground = M.Basalt, prop = "spire", material = NEON }, -- The Sun
	{ ground = M.Slate, prop = "orb", material = NEON }, -- The Void
	{ ground = PLASTIC, prop = "orb", material = PLASTIC, second = "rock" }, -- Nebula
	{ ground = M.Slate, prop = "spire", material = M.Glass }, -- Crystal Belt
	{ ground = M.DiamondPlate, prop = "crate" }, -- Robot Factory
	{ ground = M.Grass, prop = "tree", second = "spire" }, -- Alien Jungle
	{ ground = M.Slate, prop = "orb", material = NEON, second = "spire" }, -- Black Hole
	{ ground = M.Marble, prop = "orb", material = NEON, second = "rock" }, -- The Big Bang
}

local root: Folder
local islands = {} -- [index] = { folder, origin }

----------------------------------------------------------------------------------------------------
-- Part helpers. Parts do not collide unless asked to.
----------------------------------------------------------------------------------------------------
local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return Build.part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material or PLASTIC,
		CanCollide = collide == true,
		CanQuery = collide == true,
		CanTouch = false,
		Parent = parent,
	})
end

local function ball(parent: Instance, name: string, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = block(parent, name, Vector3.one * diameter, cframe, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function disc(parent: Instance, name: string, base: CFrame, radius: number, height: number, color: Color3, material: Enum.Material?, collide: boolean?): Part
	return Build.pillar(base, radius, height, {
		Name = name,
		Color = color,
		Material = material or PLASTIC,
		CanCollide = collide == true,
		CanQuery = collide == true,
		CanTouch = false,
		Parent = parent,
	})
end

-- A frame at a point of island space, standing on the ground and looking at the middle of the island: its
-- -Z faces whoever walks up from there, like the marketplace's stalls.
local function facing(origin: CFrame, point: Vector2): CFrame
	return origin * CFrame.lookAt(Vector3.new(point.X, 0, point.Y), Vector3.zero)
end

----------------------------------------------------------------------------------------------------
-- The template's pieces
----------------------------------------------------------------------------------------------------
local function buildGround(folder: Folder, origin: CFrame, world, theme)
	disc(folder, "Ground", origin * CFrame.new(0, -6, 0), RADIUS, 6, world.floor, theme.ground, true)
	disc(folder, "Plaza", origin, PLAZA_RADIUS, 0.12, world.floor:Lerp(CREAM, 0.45), M.Slate)
	-- The rim: a ring of wall pieces in the world's backdrop colour. It is the island's horizon and its fence.
	local length = 2 * RADIUS * math.tan(math.pi / RIM_PIECES) + 0.6
	for index = 1, RIM_PIECES do
		local turn = CFrame.Angles(0, (index - 0.5) * 2 * math.pi / RIM_PIECES, 0)
		local color = if index % 2 == 0 then world.backdrop else world.backdrop:Lerp(world.floor, 0.25)
		block(folder, "Rim", Vector3.new(length, RIM_HEIGHT, 2.4), origin * turn * CFrame.new(0, RIM_HEIGHT / 2 - 1, -RADIUS + 1.2), color, PLASTIC, true)
	end
	disc(folder, "ArrivalPad", origin * CFrame.new(ARRIVAL.X, 0, ARRIVAL.Y), 5, 0.14, rgb(90, 220, 255), NEON)
end

-- The way back: the same gate as the marketplace's, in the ring behind the arriving player's right shoulder.
local function buildPortal(folder: Folder, origin: CFrame, index: number)
	local frame = facing(origin, PORTAL)
	for _, side in { -1, 1 } do
		block(folder, "PortalPillar", Vector3.new(2, 13, 2), frame * CFrame.new(side * 5.5, 6.5, 0), STONE, M.Marble, true)
	end
	block(folder, "PortalBeam", Vector3.new(13, 2, 2), frame * CFrame.new(0, 14, 0), STONE, M.Marble)
	local gate = block(folder, "Portal", Vector3.new(9, 12, 0.5), frame * CFrame.new(0, 6.5, 0), rgb(130, 100, 255), NEON)
	gate.Transparency = 0.35
	Build.label(Build.billboard(gate, Vector2.new(16, 2.4), Vector3.new(0, 10.4, 0), 220), "BACK TO YOUR BASE")
	local prompt = Build.prompt(gate, "Return", "Your Base")
	prompt:SetAttribute("Island", index)
	Islands.returnPrompts[index] = prompt
	table.insert(Game.homePrompts, prompt)
end

-- The shop stall: a counter under a striped awning in the world's two colours. Its prompt only opens the
-- ISLAND SHOP window; the buying is an action (src/server/Features/IslandShop.luau).
local function buildStall(folder: Folder, frame: CFrame, world, index: number)
	local counter = block(folder, "Counter", Vector3.new(10, 3.2, 3), frame * CFrame.new(0, 1.6, 0), WOOD, M.Wood, true)
	for _, side in { -1, 1 } do
		block(folder, "StallPost", Vector3.new(0.6, 10, 0.6), frame * CFrame.new(side * 4.7, 5, 1.2), WOOD, M.Wood)
	end
	local stripes = { world.backdrop, world.floor:Lerp(CREAM, 0.6) }
	for stripe = 1, 5 do
		-- Sloping down towards the customer.
		local cframe = frame * CFrame.new(-6.3 + stripe * 2.1, 9.6, -0.6) * CFrame.Angles(math.rad(-14), 0, 0)
		block(folder, "Awning", Vector3.new(2.1, 0.3, 6), cframe, stripes[stripe % 2 + 1])
	end
	local board = block(folder, "StallSign", Vector3.new(10, 2.4, 0.4), frame * CFrame.new(0, 11.8, -2.2), rgb(96, 64, 42), M.Wood)
	Build.label(Build.surface(board, Enum.NormalId.Front), "🏝️ ISLAND SHOP")
	-- On the counter: a shell and a chest, for the ammo and the Boss Chest it sells.
	ball(folder, "StallShell", 1.5, frame * CFrame.new(-2.4, 3.95, 0), world.backdrop, NEON)
	block(folder, "StallChest", Vector3.new(2.2, 1.5, 1.6), frame * CFrame.new(2.2, 3.95, 0), rgb(200, 60, 60), M.Wood)
	local prompt = Build.prompt(counter, "Open", "Island Shop")
	prompt:SetAttribute("Window", Islands.SHOP_WINDOW)
	prompt:SetAttribute("Island", index)
	Islands.shopPrompts[index] = prompt
end

local function buildLamp(folder: Folder, base: CFrame, color: Color3)
	block(folder, "LampPost", Vector3.new(0.6, 11, 0.6), base * CFrame.new(0, 5.5, 0), DARK, M.Metal)
	local bulb = ball(folder, "Lamp", 1.8, base * CFrame.new(0, 11.6, 0), color, NEON)
	local light = Instance.new("PointLight")
	light.Range = 32
	light.Brightness = 1.6
	light.Color = color
	light.Parent = bulb
end

-- A monster of the world as a statue on a plinth: its own shape, in stone with a hint of its colours.
local function buildStatue(folder: Folder, base: CFrame, def, scale: number, plinth: number): Model
	disc(folder, "Plinth", base, plinth, 1.2, STONE, M.Marble, true)
	-- With a name, a monster that has a Blender model (ReplicatedStorage.Creatures) is a statue of that model.
	local statue = Models.monster({ name = def.name, shape = def.shape, color = def.color, accent = def.accent, scale = scale, kind = def.kind }, nil)
	statue.Name = "Statue"
	for _, part in statue:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.Color = part.Color:Lerp(STONE, 0.45)
			part.Material = M.Marble
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	statue:PivotTo(base * CFrame.new(0, 1.2, 0))
	statue.Parent = folder
	return statue
end

-- The boss at the north rim, behind the eggs, with the island's name over it. (It stood in the middle of the
-- island before the middle became the arrival; the function keeps its name.)
local function buildCentre(folder: Folder, origin: CFrame, world, index: number, dressed: boolean)
	local boss = world.finalBoss
	-- It looks south, at the players arriving.
	local base = facing(origin, BOSS)
	disc(folder, "Fountain", base, 9, 0.8, STONE, M.Marble, true)
	-- On a dressed island (see `wear`) the statue is the boss's Blender model, at the size the plinth was made for.
	local def = { name = if dressed then boss.name else nil, shape = boss.shape, color = boss.color, accent = boss.accent, kind = "final" }
	buildStatue(folder, base * CFrame.new(0, 0.8, 0), def, if dressed then DRESSED_BOSS_SCALE else 3, 4.5)
	-- The sign hangs over an orb: a billboard's offset follows its part's own axes, and a pillar lies on its side.
	local orb = ball(folder, "SignOrb", 2.4, base * CFrame.new(0, 19, 0), world.backdrop, NEON)
	local gui = Build.billboard(orb, Vector2.new(34, 8), Vector3.new(0, 6, 0), 320)
	local title = Build.label(gui, `{string.upper(world.name)} ISLAND`)
	title.Size = UDim2.fromScale(1, 0.62)
	title.TextColor3 = GOLD
	local how = Build.label(gui, `World {index}  •  boss: {boss.name}`)
	how.Position = UDim2.fromScale(0, 0.64)
	how.Size = UDim2.fromScale(1, 0.36)
end

local PROPS = {}

function PROPS.tree(folder: Folder, base: CFrame, color: Color3, _accent: Color3, _material: Enum.Material?, size: number)
	disc(folder, "Trunk", base, 0.9 * size, 6 * size, WOOD, M.Wood, true)
	ball(folder, "Leaves", 7.5 * size, base * CFrame.new(0, 8.4 * size, 0), color, PLASTIC)
end

function PROPS.rock(folder: Folder, base: CFrame, color: Color3, _accent: Color3, _material: Enum.Material?, size: number)
	local rock = block(folder, "Rock", Vector3.new(6, 4, 5) * size, base * CFrame.new(0, 1.4 * size, 0), color:Lerp(DARK, 0.3), M.Slate, true)
	Build.ellipsoid(rock)
end

function PROPS.spire(folder: Folder, base: CFrame, _color: Color3, accent: Color3, material: Enum.Material?, size: number)
	local lean = CFrame.Angles(math.rad(8), 0, math.rad(-10))
	local spire = block(folder, "Spire", Vector3.new(2.2, 11, 2.2) * size, base * lean * CFrame.new(0, 5 * size, 0), accent, material or M.Slate, true)
	spire.Transparency = if material == M.Glass then 0.25 else 0
	block(folder, "SpireShard", Vector3.new(1.4, 6, 1.4) * size, base * CFrame.new(2 * size, 0, 0) * CFrame.Angles(0, 0, math.rad(-22)) * CFrame.new(0, 2.6 * size, 0), accent:Lerp(CREAM, 0.3), material or M.Slate)
end

function PROPS.orb(folder: Folder, base: CFrame, color: Color3, accent: Color3, material: Enum.Material?, size: number)
	disc(folder, "OrbBase", base, 1.6 * size, 0.8, color:Lerp(DARK, 0.5), M.Slate, true)
	ball(folder, "Orb", 4.2 * size, base * CFrame.new(0, 5.5 * size, 0), accent, material or NEON)
end

function PROPS.crate(folder: Folder, base: CFrame, color: Color3, accent: Color3, _material: Enum.Material?, size: number)
	block(folder, "Machine", Vector3.new(5, 5, 5) * size, base * CFrame.new(0, 2.5 * size, 0), color:Lerp(DARK, 0.25), M.Metal, true)
	block(folder, "MachineLight", Vector3.new(3, 0.6, 3) * size, base * CFrame.new(0, 5.3 * size, 0), accent, NEON)
end

local function buildProps(folder: Folder, origin: CFrame, world, theme)
	for order, degrees in PROP_ANGLES do
		local angle = math.rad(degrees)
		local point = Vector2.new(math.sin(angle), math.cos(angle)) * PROP_RADIUS
		-- Every third prop is the theme's second kind, and sizes alternate, so the ring does not look stamped.
		local kind = if theme.second and order % 3 == 0 then theme.second else theme.prop
		local accent = world.monsters[(order - 1) % #world.monsters + 1].color
		PROPS[kind](folder, facing(origin, point), world.backdrop, accent, theme.material, if order % 2 == 0 then 1 else 0.8)
	end
end

-- A faint tile where a later module builds: kept empty by everything else on the island.
local function buildSpot(folder: Folder, origin: CFrame, name: string, point: Vector2, world)
	local plate = block(folder, "Spot_" .. name, Vector3.new(SPOT_SIZE, 0.1, SPOT_SIZE), facing(origin, point) * CFrame.new(0, 0.05, 0), world.floor:Lerp(DARK, 0.25), M.Slate)
	plate:SetAttribute("Spot", name)
end

-- A world's Blender island, if it has one (tools/blender/earth_island.py, imported as
-- ReplicatedStorage.IslandModels): a model named after the world whose pivot is the middle of the island on
-- the ground, and a folder "<World>Shells" of landmark meshes, each with the middle of its base as pivot and
-- its front towards -Z (EggPedestal, Stall, Portal, PortalSheet, BossPlinth).
local function dressFor(world): (Model?, Instance?)
	local models = ReplicatedStorage:FindFirstChild("IslandModels")
	local scenery = models and models:FindFirstChild(world.name)
	local shells = models and models:FindFirstChild(world.name .. "Shells")
	if scenery and scenery:IsA("Model") and shells then
		return scenery, shells
	end
	return nil, nil
end

-- Dresses an island in its Blender model. What was built from parts stays, unseen, as the floor, the rim
-- wall, the lamps' light and the carrier of every prompt and sign, so nothing that looks for those parts
-- has to know. The statues and the eggs are still the game's own.
local function wear(folder: Folder, origin: CFrame, scenery: Model, shells: Instance)
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and (UNSEEN[part.Name] or part:GetAttribute("Spot")) then
			part.Transparency = 1
			part.CastShadow = false
			local face = part:FindFirstChildWhichIsA("SurfaceGui")
			if face then
				face.Enabled = false -- the stall's painted sign: the model has its own board
			end
		end
	end
	local dress = scenery:Clone()
	dress.Name = "Scenery"
	dress:PivotTo(origin)
	dress.Parent = folder
	for _, solid in SOLIDS[scenery.Name] or {} do
		local pillar = disc(folder, "Solid", origin * CFrame.new(solid[1], 0, solid[2]), solid[3], solid[4], STONE, PLASTIC, true)
		pillar.Transparency = 1
		pillar.CastShadow = false
	end
	for name, point in { Stall = STALL, Portal = PORTAL, PortalSheet = PORTAL, BossPlinth = BOSS } do
		local shell = shells:FindFirstChild(name)
		if shell and shell:IsA("PVInstance") then
			local copy = shell:Clone()
			copy:PivotTo(facing(origin, point))
			copy.Parent = folder
		end
	end
end

local function buildIsland(index: number, world)
	local theme = THEMES[(index - 1) % #THEMES + 1]
	local origin = Layout.islandCFrame(index)
	local folder = Instance.new("Folder")
	folder.Name = "Island_" .. index
	folder:SetAttribute("World", index)
	local scenery, shells = dressFor(world)
	islands[index] = { folder = folder, origin = origin, shells = shells }

	buildGround(folder, origin, world, theme)
	buildPortal(folder, origin, index)
	buildStall(folder, facing(origin, STALL), world, index)
	buildCentre(folder, origin, world, index, scenery ~= nil)
	for _, point in LAMPS do
		buildLamp(folder, origin * CFrame.new(point.X, 0, point.Y), world.backdrop:Lerp(CREAM, 0.5))
	end
	for order, point in STATUES do
		-- The world's first and last ordinary monsters.
		local def = world.monsters[if order == 1 then 1 else #world.monsters]
		buildStatue(folder, facing(origin, point), def, 1.6, 2.6)
	end
	if not scenery then
		buildProps(folder, origin, world, theme) -- a Blender island brings its own trees
	end
	for name, point in SPOTS do
		buildSpot(folder, origin, name, point, world)
	end
	if scenery and shells then
		wear(folder, origin, scenery, shells)
	end
	folder.Parent = root
end

-- The world's coin eggs, on the marketplace's own stands. They are parented where the marketplace keeps its
-- stands, because that is where each client looks for a stand to write its own price and odds on.
local function buildEggs(index: number)
	local container = Marketplace.container()
	local parent = container:FindFirstChild("Eggs") or container
	local origin = islands[index].origin
	local shells = islands[index].shells
	local pedestal = shells and shells:FindFirstChild("EggPedestal")
	local place = 0
	for _, egg in Config.Eggs do
		if egg.world == index and not egg.event and EGGS[place + 1] then
			place += 1
			if pedestal and pedestal:IsA("MeshPart") then
				Marketplace.buildEggStand(egg, facing(origin, EGGS[place]), parent, pedestal, PEDESTAL_TOP)
			else
				Marketplace.buildEggStand(egg, facing(origin, EGGS[place]), parent)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Builds every island, once, after the marketplace and before Game.start (which wires the egg prompts and
-- the portals home).
function Islands.build()
	root = Instance.new("Folder")
	root.Name = "Islands"
	for index, world in Config.Worlds do
		buildIsland(index, world)
		buildEggs(index)
	end
	root.Parent = workspace

	Game.places.island = function(index: number): CFrame?
		return if islands[index] then Layout.islandSpawn(index) else nil
	end
end

-- For the modules that add something to an island. Only valid after Islands.build.
-- The folder of a world's island, to parent things under.
function Islands.container(index: number): Folder?
	local island = islands[index]
	return island and island.folder
end

-- A frame in an island's own space (x east, z south, the middle at 0, 0), like Marketplace.frame.
function Islands.frame(index: number, x: number, y: number, z: number): CFrame?
	local island = islands[index]
	return island and island.origin * CFrame.new(x, y, z)
end

-- One of the two reserved 12 x 12 spots: "mastery" or "enchant". The frame is at floor level in the middle of
-- the spot, 16 studs from the arrival pad, its -Z facing the middle of the island (the customer). Two things
-- on one spot stand at x = -5 and x = 5 of this frame (see SPOTS). Nil for an unknown island or name.
function Islands.spot(index: number, name: string): CFrame?
	local island, point = islands[index], SPOTS[name]
	if not island or not point then
		return nil
	end
	return facing(island.origin, point)
end

return Islands
