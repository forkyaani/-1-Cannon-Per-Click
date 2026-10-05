-- The plots: twelve private bases, built from code, each standing alone far from every other one, from the
-- marketplace and from the islands (Layout.plotCFrame). On each: the ground, the path the monsters walk from
-- the portal to the gate of the base, sixteen cannon pads beside it, a fence, a backdrop and props that change
-- with the world, and beside where the owner arrives two teleporters: one opens the WORLDS window (the way to
-- the islands), one leads to the marketplace. The server only builds and dresses them; the monsters
-- themselves are drawn by each client (docs/DEFENSE_SPEC.md, section 6).
--
-- Everything is laid out in plot space (Layout.plotCFrame): x across the plot, z up it, the ground's top at
-- y = 0. Every base faces the same way.
-- A base is closed off: a skyline all the way around it (the backdrop behind the portal, lower hills down the
-- sides and behind the yard) with an unseen wall over it, so nobody walks or jumps off into nothing. Inside,
-- only the ground, the walls of the base, the fence rails and the pads collide; nothing stands on the path.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Models = require(ReplicatedStorage.Shared.Models)
local Build = require(script.Parent.Build)

local Plots = {}

-- Each base's two teleporters, by slot. The core wires both (Game.start) and lets only the base's owner use
-- them: the first sends them to the marketplace, the second opens their WORLDS window.
Plots.marketPrompts = {} :: { [number]: ProximityPrompt }
Plots.worldsPrompts = {} :: { [number]: ProximityPrompt }

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local STONE = rgb(150, 150, 158)
local WOOD = rgb(120, 84, 56)
local DARK = rgb(44, 46, 54)
local GOLD = rgb(255, 200, 40)
local WARM = rgb(255, 214, 140)
local UNCLAIMED = rgb(128, 132, 144)

local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local BALL = Enum.PartType.Ball

local WIDTH, DEPTH, YARD = Layout.PLOT_WIDTH, Layout.PLOT_DEPTH, Layout.PLOT_YARD
local RIM = 3 -- how thick the skyline around a base is: it stands just outside the ground
local RIM_SIDES = { 13, 17, 11, 15, 12, 16 } -- how high its slabs are, down each side: all higher than a jump
local RIM_BACK = { 12, 15, 11, 14, 12 } -- and behind the yard
local BARRIER_HEIGHT = 140 -- the unseen wall over the skyline: nothing a player can climb gets them over it
local GATE_Z = Layout.PATH[#Layout.PATH].Y -- where the path ends: the wall of the base stands across it
local PORTAL = Layout.PATH[1]
local GATE_WIDTH, GATE_HEIGHT = 14, 14 -- the opening of the gate; the portal's is as wide and a little higher
local PAD_HEIGHT = 0.5 -- low enough to walk over
local ROAD_TOP, KERB_TOP = 0.2, 0.1
local KERB = 0.8 -- how much kerb shows on each side of the road
local PORTAL_DEPTH = 2 -- the portal stands this far behind the first point of the path

local root: Folder
local petFolder: Folder
local halloween = false
local plots = {}

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
	part.Shape = BALL
	return part
end

-- An upright disc or pillar standing on `base`.
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

-- Text on a face of a part, sharp enough to read from close by.
local function paint(part: BasePart, face: Enum.NormalId, text: string, pixelsPerStud: number): TextLabel
	local gui = Build.surface(part, face)
	gui.PixelsPerStud = pixelsPerStud
	return Build.label(gui, text)
end

local function lamp(parent: Instance, base: CFrame, color: Color3)
	block(parent, "LampFoot", Vector3.new(1.6, 1, 1.6), base * CFrame.new(0, 0.5, 0), DARK, Enum.Material.Metal)
	block(parent, "LampPost", Vector3.new(0.7, 10.5, 0.7), base * CFrame.new(0, 6, 0), DARK, Enum.Material.Metal)
	local bulb = ball(parent, "Lamp", 2.2, base * CFrame.new(0, 12, 0), color, NEON)
	local light = Instance.new("PointLight")
	light.Range = 36
	light.Brightness = 1.6
	light.Color = color
	light.Parent = bulb
end

----------------------------------------------------------------------------------------------------
-- Worlds. Config.Worlds gives each world its floor and backdrop colours; this is the rest of its look: the
-- ground's material, the road and its kerb, the glow of the portal and the props standing around.
-- A world added to Config without a line here borrows one, with its own floor and backdrop.
----------------------------------------------------------------------------------------------------
local M = Enum.Material
local THEMES = {
	{ -- Earth: a dirt road between trees
		ground = M.Grass, road = rgb(226, 200, 146), roadMaterial = M.Sand, kerb = rgb(150, 150, 158), kerbMaterial = M.Cobblestone,
		glow = rgb(130, 100, 255), prop = "tree", colors = { rgb(64, 150, 70), rgb(110, 196, 84), WOOD },
	},
	{ -- Moon: craters and boulders
		ground = M.Slate, road = rgb(96, 98, 112), roadMaterial = M.Concrete, kerb = rgb(214, 216, 228), kerbMaterial = M.Slate,
		glow = rgb(150, 190, 255), prop = "rocks", colors = { rgb(150, 150, 162), rgb(192, 192, 204), rgb(112, 112, 126) },
	},
	{ -- Mars: red rock
		ground = M.Sand, road = rgb(108, 56, 42), roadMaterial = M.Slate, kerb = rgb(238, 176, 116), kerbMaterial = M.Sand,
		glow = rgb(255, 120, 60), prop = "rocks", colors = { rgb(160, 70, 44), rgb(208, 124, 72), rgb(150, 64, 40) },
	},
	{ -- Neptune: ice
		ground = M.Ice, road = rgb(90, 140, 215), roadMaterial = PLASTIC, kerb = rgb(240, 250, 255), kerbMaterial = M.Ice,
		glow = rgb(110, 230, 255), prop = "crystals", propMaterial = M.Ice, colors = { rgb(120, 220, 255), rgb(222, 245, 255), WHITE },
	},
	{ -- The Sun: black rock and lava
		ground = M.Slate, road = rgb(48, 28, 26), roadMaterial = M.Slate, kerb = rgb(255, 130, 30), kerbMaterial = NEON,
		glow = rgb(255, 200, 60), prop = "vent", colors = { rgb(255, 140, 30), rgb(255, 222, 90), rgb(58, 34, 30) },
	},
	{ -- The Void
		ground = PLASTIC, road = rgb(70, 48, 120), roadMaterial = PLASTIC, kerb = rgb(200, 90, 255), kerbMaterial = NEON,
		glow = rgb(220, 60, 160), prop = "vent", colors = { rgb(170, 80, 255), rgb(255, 120, 220), rgb(22, 14, 38) },
	},
	{ -- Nebula: clouds
		ground = PLASTIC, road = rgb(156, 126, 220), roadMaterial = PLASTIC, kerb = rgb(255, 170, 225), kerbMaterial = PLASTIC,
		glow = rgb(255, 150, 220), prop = "puff", colors = { rgb(255, 170, 220), rgb(150, 225, 245), rgb(240, 225, 255) },
	},
	{ -- Crystal Belt
		ground = M.Slate, road = rgb(30, 80, 110), roadMaterial = M.Slate, kerb = rgb(245, 245, 255), kerbMaterial = M.Marble,
		glow = rgb(200, 120, 255), prop = "crystals", propMaterial = M.Glass, colors = { rgb(200, 120, 240), rgb(250, 250, 255), rgb(250, 190, 235) },
	},
	{ -- Robot Factory
		ground = M.Concrete, road = rgb(52, 56, 64), roadMaterial = M.DiamondPlate, kerb = rgb(238, 186, 52), kerbMaterial = PLASTIC,
		glow = rgb(255, 170, 50), prop = "machine", colors = { rgb(205, 165, 80), rgb(230, 70, 50), rgb(60, 66, 78) },
	},
	{ -- Alien Jungle: glowing mushroom trees
		ground = M.Grass, road = rgb(126, 100, 62), roadMaterial = M.Sand, kerb = rgb(170, 222, 84), kerbMaterial = M.Grass,
		glow = rgb(150, 255, 90), prop = "tree", propGlow = true, colors = { rgb(230, 90, 170), rgb(120, 255, 170), rgb(92, 62, 132) },
	},
	{ -- Black Hole
		ground = PLASTIC, road = rgb(64, 56, 84), roadMaterial = PLASTIC, kerb = rgb(255, 90, 60), kerbMaterial = NEON,
		glow = rgb(255, 80, 60), prop = "orbit", colors = { rgb(8, 8, 12), rgb(255, 140, 40), rgb(60, 54, 74) },
	},
	{ -- The Big Bang
		ground = M.Sand, road = rgb(255, 248, 225), roadMaterial = M.Marble, kerb = rgb(235, 70, 80), kerbMaterial = PLASTIC,
		glow = rgb(255, 240, 170), prop = "orbit", propGlow = true, colors = { rgb(255, 250, 200), rgb(50, 140, 235), rgb(235, 70, 80) },
	},
}

local function themeOf(worldIndex: number)
	return THEMES[(worldIndex - 1) % #THEMES + 1]
end

-- The props. Each stands on `base` (ground level, y up), `size` times as big, in the theme's three colours.
local PROPS = {}

function PROPS.tree(parent: Instance, base: CFrame, size: number, theme)
	local colors = theme.colors
	disc(parent, "Trunk", base, 0.8 * size, 6 * size, colors[3], M.Wood)
	ball(parent, "Leaves", 7 * size, base * CFrame.new(0, 8.3 * size, 0), colors[1], M.Grass)
	local side = base * CFrame.new(1.9 * size, 6 * size, 0.9 * size)
	ball(parent, "Leaves", 4.4 * size, side, colors[2], if theme.propGlow then NEON else M.Grass)
end

function PROPS.rocks(parent: Instance, base: CFrame, size: number, theme)
	local colors = theme.colors
	disc(parent, "Crater", base * CFrame.new(-1.2 * size, 0, 0.6 * size), 3.6 * size, 0.12, colors[3], M.Slate)
	Build.ellipsoid(block(parent, "Boulder", Vector3.new(4.6, 3.2, 3.8) * size, base * CFrame.new(0, 1.2 * size, 0), colors[1], M.Slate))
	ball(parent, "Boulder", 2.2 * size, base * CFrame.new(2.4 * size, 0.7 * size, 1.3 * size), colors[2], M.Slate)
end

function PROPS.crystals(parent: Instance, base: CFrame, size: number, theme)
	local colors, material = theme.colors, theme.propMaterial
	local shards = {
		{ Vector3.new(1.6, 6, 1.6), Vector3.new(0, 2.7, 0), CFrame.Angles(math.rad(8), 0, math.rad(-6)), colors[1] },
		{ Vector3.new(1.2, 4.2, 1.2), Vector3.new(1.5, 1.8, 0.4), CFrame.Angles(math.rad(-14), 0, math.rad(-24)), colors[2] },
		{ Vector3.new(1, 3.2, 1), Vector3.new(-1.3, 1.4, -0.5), CFrame.Angles(math.rad(10), 0, math.rad(26)), colors[3] },
	}
	for _, shard in shards do
		local part = block(parent, "Crystal", shard[1] * size, base * CFrame.new(shard[2] * size) * shard[3], shard[4], material)
		if material == M.Glass then
			part.Transparency = 0.2
		end
	end
end

-- A dark rock with something glowing in it and an ember floating over it.
function PROPS.vent(parent: Instance, base: CFrame, size: number, theme)
	local colors = theme.colors
	block(parent, "Rock", Vector3.new(4.4, 2.2, 4.4) * size, base * CFrame.new(0, 1.1 * size, 0), colors[3], M.Slate)
	ball(parent, "Glow", 2.8 * size, base * CFrame.new(0, 2.3 * size, 0), colors[1], NEON)
	ball(parent, "Ember", 1 * size, base * CFrame.new(0.4 * size, 4.8 * size, 0.2 * size), colors[2], NEON)
end

function PROPS.puff(parent: Instance, base: CFrame, size: number, theme)
	local colors = theme.colors
	local puffs = { { 5, Vector3.new(0, 3.4, 0) }, { 3.6, Vector3.new(2.4, 2.8, 0.6) }, { 3, Vector3.new(-2.2, 2.6, -0.5) } }
	for index, puff in puffs do
		ball(parent, "Cloud", puff[1] * size, base * CFrame.new(puff[2] * size), colors[index]).Transparency = 0.15
	end
end

function PROPS.machine(parent: Instance, base: CFrame, size: number, theme)
	local colors = theme.colors
	block(parent, "Machine", Vector3.new(4, 3, 4) * size, base * CFrame.new(0, 1.5 * size, 0), colors[3], M.DiamondPlate)
	-- A cylinder lies along its X axis: left like that it is a cog standing on its rim.
	block(parent, "Cog", Vector3.new(0.7, 3.4, 3.4) * size, base * CFrame.new(0, 3.9 * size, 0), colors[1], M.Metal).Shape = Enum.PartType.Cylinder
	disc(parent, "Chimney", base * CFrame.new(1.2 * size, 3 * size, 1.2 * size), 0.5 * size, 3 * size, colors[2], M.Metal)
end

-- A ball floating over a pedestal, with a ring around it.
function PROPS.orbit(parent: Instance, base: CFrame, size: number, theme)
	local colors = theme.colors
	disc(parent, "Pedestal", base, 1.1 * size, 1.6 * size, colors[3], M.Slate)
	local middle = base * CFrame.new(0, 4.2 * size, 0)
	ball(parent, "Core", 3 * size, middle, colors[1], if theme.propGlow then NEON else PLASTIC)
	local ring = block(parent, "Ring", Vector3.new(0.2, 6.6, 6.6) * size, middle * CFrame.Angles(math.rad(20), 0, math.rad(90)), colors[2], NEON)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
end

-- Where the props stand, in plot space: clear of the path, the pads and the base. { x, z, size }
local PROP_SPOTS = {
	{ -46, 26, 1 }, { 46, 27, 0.85 }, { 40, 52, 0.9 }, { -40, 83, 1.05 }, { 40, 113, 0.9 },
	{ -48, 141, 1.1 }, { 48, 141, 0.95 }, { 26, 139, 0.8 }, { 49.5, 101, 0.75 }, { -49.5, 96, 0.8 },
}

----------------------------------------------------------------------------------------------------
-- One plot
----------------------------------------------------------------------------------------------------
-- A colour per plot, for its roofs, flags and gate: neighbours get hues far apart.
local function slotColor(slot: number): Color3
	return Color3.fromHSV(((slot - 1) * 5 % 12) / 12, 0.62, 1)
end

-- The path as slabs `width` wide whose tops are at `top`. Each stretch runs on over its corner and the next
-- one starts past it, so the corners are filled without two slabs lying in each other.
local function buildStrip(plot, name: string, width: number, top: number, parent: Instance): { Part }
	local parts = {}
	local path = Layout.PATH
	local thickness = 0.6
	for index = 1, #path - 1 do
		local from, to = path[index], path[index + 1]
		local direction = (to - from).Unit
		if index > 1 then
			from += direction * (width / 2)
		else
			from -= direction * PORTAL_DEPTH -- the road starts under the portal's arch
		end
		if index < #path - 1 then
			to += direction * (width / 2)
		end
		local middle = (from + to) / 2
		local center = plot.frame * Vector3.new(middle.X, top - thickness / 2, middle.Y)
		local ahead = plot.frame:VectorToWorldSpace(Vector3.new(direction.X, 0, direction.Y))
		local size = Vector3.new(width, thickness, (to - from).Magnitude)
		parts[index] = block(parent, name, size, CFrame.lookAt(center, center + ahead), WHITE)
	end
	return parts
end

local function buildGround(plot, parent: Instance)
	local frame = plot.frame
	plot.ground = block(parent, "Ground", Vector3.new(WIDTH, 4, DEPTH), frame * CFrame.new(0, -2, DEPTH / 2), WHITE, nil, true)
	-- The yard: the same ground, running on behind the base to the back of the surround.
	plot.yard = block(parent, "Yard", Vector3.new(WIDTH, 4, YARD), frame * CFrame.new(0, -2, -YARD / 2), WHITE, nil, true)
	plot.kerb = buildStrip(plot, "Kerb", Layout.PATH_WIDTH + KERB * 2, KERB_TOP, parent)
	plot.road = buildStrip(plot, "Road", Layout.PATH_WIDTH, ROAD_TOP, parent)

	-- The backdrop: a skyline of slabs behind the portal, in the world's colour, with the world's name on it.
	plot.backdrop = {}
	local heights = { 18, 26, 34, 24, 20 }
	local slab = WIDTH / #heights
	for index, height in heights do
		local x = -WIDTH / 2 + slab * (index - 0.5)
		local part = block(parent, "Backdrop", Vector3.new(slab, height, 3), frame * CFrame.new(x, height / 2 - 0.4, DEPTH + 1.5), WHITE, nil, true)
		plot.backdrop[index] = part
	end
	local title = paint(plot.backdrop[3], Enum.NormalId.Front, "", 20)
	title.Position = UDim2.fromScale(0.05, 0.06)
	title.Size = UDim2.fromScale(0.9, 0.2)
	plot.worldLabel = title

	-- The fence down both sides, from the back of the yard to the backdrop.
	local fence = rgb(236, 232, 222)
	local length = DEPTH + YARD
	for _, side in { -1, 1 } do
		local x = side * (WIDTH / 2 - 0.7)
		for post = 0, 9 do
			-- The first and the last stand just inside the corners.
			local z = math.clamp(-YARD + post * length / 9, -YARD + 0.65, DEPTH - 0.65)
			block(parent, "FencePost", Vector3.new(1.3, 3.6, 1.3), frame * CFrame.new(x, 1.8, z), fence, M.Wood)
		end
		for _, height in { 1.3, 2.7 } do
			block(parent, "FenceRail", Vector3.new(0.5, 0.5, length), frame * CFrame.new(x, height, -YARD + length / 2), fence, M.Wood, true)
		end
	end

	-- The surround: hills in the world's colour down both sides and behind the yard, lower than the backdrop.
	-- With the backdrop they close the base off: it is the base's horizon, and nothing is beyond it.
	plot.surround = {}
	local function hill(size: Vector3, x: number, z: number)
		local part = block(parent, "Surround", size, frame * CFrame.new(x, size.Y / 2 - 4, z), WHITE, nil, true)
		table.insert(plot.surround, part)
	end
	local from, to = -YARD - RIM, DEPTH + RIM -- the sides run past both ends, so the corners are closed
	local piece = (to - from) / #RIM_SIDES
	for _, side in { -1, 1 } do
		for index, height in RIM_SIDES do
			-- The two sides are not mirror images: the heights run the other way.
			local z = if side < 0 then from + piece * (index - 0.5) else to - piece * (index - 0.5)
			hill(Vector3.new(RIM, height + 4, piece), side * (WIDTH / 2 + RIM / 2), z)
		end
	end
	piece = WIDTH / #RIM_BACK
	for index, height in RIM_BACK do
		hill(Vector3.new(piece, height + 4, RIM), -WIDTH / 2 + piece * (index - 0.5), -YARD - RIM / 2)
	end

	-- Over all four sides an unseen wall, far higher than anything a player can stand on: nobody leaves a base
	-- on foot. (The core's safety net, Layout.FALL_HEIGHT, catches whoever gets under the map some other way.)
	local function barrier(size: Vector3, x: number, z: number)
		Build.part({
			Name = "Barrier",
			Size = size,
			CFrame = frame * CFrame.new(x, BARRIER_HEIGHT / 2 - 4, z),
			Transparency = 1,
			CanCollide = true,
			CanQuery = false, -- the camera and clicks pass through it
			CanTouch = false,
			CastShadow = false,
			Parent = parent,
		})
	end
	for _, side in { -1, 1 } do
		barrier(Vector3.new(RIM, BARRIER_HEIGHT, to - from), side * (WIDTH / 2 + RIM / 2), (from + to) / 2)
	end
	barrier(Vector3.new(WIDTH, BARRIER_HEIGHT, RIM), 0, -YARD - RIM / 2)
	barrier(Vector3.new(WIDTH, BARRIER_HEIGHT, RIM), 0, DEPTH + RIM / 2)

	-- A lamp in each back corner of the yard.
	for _, side in { -1, 1 } do
		lamp(parent, frame * CFrame.new(side * (WIDTH / 2 - 6), 0, -YARD + 5), if halloween then rgb(255, 140, 40) else WARM)
	end
end

-- One of a base's two teleporters: a beam on a ring, with its name over it. Returns its prompt, which carries
-- the base's slot and which teleporter it is. Only light: nothing of it collides.
local function buildTeleporter(plot, parent: Instance, kind: string, color: Color3, title: string, how: string, action: string, object: string): ProximityPrompt
	local spot = Layout.TELEPORTERS[kind]
	local base = plot.frame * CFrame.new(spot.X, 0.3, spot.Y)
	local name = if kind == "worlds" then "Worlds" else "Market"
	disc(parent, name .. "Ring", base, 3.2, 0.1, color, NEON)
	local beam = disc(parent, name .. "Portal", base * CFrame.new(0, 0.1, 0), 1.7, 8, color, NEON)
	beam.Transparency = 0.35
	local glow = Instance.new("PointLight")
	glow.Range = 18
	glow.Brightness = 1.2
	glow.Color = color
	glow.Parent = beam
	-- The sign hangs over an orb: a billboard's offset follows its part's own axes, and a pillar lies on its side.
	local orb = ball(parent, name .. "Orb", 1.8, base * CFrame.new(0, 9.6, 0), color, NEON)
	local gui = Build.billboard(orb, Vector2.new(15, 3.8), Vector3.new(0, 3.4, 0), 160)
	local heading = Build.label(gui, title)
	heading.Size = UDim2.fromScale(1, 0.62)
	heading.TextColor3 = GOLD
	local line = Build.label(gui, how)
	line.Position = UDim2.fromScale(0, 0.64)
	line.Size = UDim2.fromScale(1, 0.36)
	local prompt = Build.prompt(beam, action, object)
	prompt.MaxActivationDistance = 8
	prompt:SetAttribute("Slot", plot.slot)
	prompt:SetAttribute("Teleporter", kind)
	return prompt
end

-- The base: a gatehouse across the end of the path, with a wall out to each fence. The owner arrives on the
-- plaza behind it (Layout.plotSpawn) and walks out through the gate, which is only light.
local function buildBase(plot, parent: Instance)
	local frame = plot.frame
	local brick = M.Brick
	plot.colored = {}
	plot.nameLabels = {}

	block(parent, "Plaza", Vector3.new(40, 0.3, GATE_Z), frame * CFrame.new(0, 0, GATE_Z / 2), rgb(198, 180, 152), M.Slate)
	table.insert(plot.colored, disc(parent, "ArrivalPad", frame * CFrame.new(0, 0.15, 4), 3.5, 0.1, UNCLAIMED, NEON))

	-- The gate is GATE_WIDTH wide and GATE_HEIGHT high: room for a giant, and a world boss has to duck.
	local towerX = GATE_WIDTH / 2 + 3.5
	for _, side in { -1, 1 } do
		local tower = frame * CFrame.new(side * towerX, 0, GATE_Z)
		local top = GATE_HEIGHT + 4
		disc(parent, "GateTower", tower, 3.5, top, STONE, brick, true)
		disc(parent, "Battlement", tower * CFrame.new(0, top, 0), 4.2, 1.4, rgb(120, 120, 130), brick)
		table.insert(plot.colored, ball(parent, "Roof", 7.4, tower * CFrame.new(0, top + 1.4, 0), UNCLAIMED))
		block(parent, "FlagPole", Vector3.new(0.3, 4.6, 0.3), tower * CFrame.new(0, top + 7.2, 0), DARK, M.Metal)
		table.insert(plot.colored, block(parent, "Flag", Vector3.new(0.2, 1.6, 2.6), tower * CFrame.new(0, top + 8.6, 1.45), UNCLAIMED, M.Fabric))
		-- The wall from the gatehouse to the fence.
		local from = towerX + 3.5
		local reach = WIDTH / 2 - from
		block(parent, "Wall", Vector3.new(reach, 4.5, 2), frame * CFrame.new(side * (from + reach / 2), 2.25, GATE_Z), STONE, brick, true)
	end

	-- Over the gate: a beam with battlements, and the owner's name on both sides of it.
	block(parent, "GateBeam", Vector3.new(GATE_WIDTH, 3.2, 3), frame * CFrame.new(0, GATE_HEIGHT + 1.6, GATE_Z), STONE, brick)
	for _, x in { -5, 0, 5 } do
		block(parent, "Merlon", Vector3.new(2.4, 1.2, 3), frame * CFrame.new(x, GATE_HEIGHT + 3.8, GATE_Z), rgb(120, 120, 130), brick)
	end
	local sign = block(parent, "NameSign", Vector3.new(GATE_WIDTH - 1.6, 2.4, 3.4), frame * CFrame.new(0, GATE_HEIGHT + 1.6, GATE_Z), DARK)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		table.insert(plot.nameLabels, paint(sign, face, "", 40))
	end

	local gate = block(plot.folder, "Gate", Vector3.new(GATE_WIDTH, GATE_HEIGHT, 0.6), frame * CFrame.new(0, GATE_HEIGHT / 2, GATE_Z), UNCLAIMED, NEON)
	gate.Transparency = 1
	plot.gate = gate

	-- The two teleporters, left and right of where the owner arrives (Layout.TELEPORTERS). Their prompts do
	-- nothing by themselves: the core answers them, for the base's owner only.
	local teleporters = Instance.new("Folder")
	teleporters.Name = "Teleporters"
	teleporters.Parent = plot.folder
	Plots.worldsPrompts[plot.slot] = buildTeleporter(plot, teleporters, "worlds", rgb(70, 220, 140), "WORLD ISLANDS", "Each world's eggs and shop", "Open", "Worlds")
	Plots.marketPrompts[plot.slot] = buildTeleporter(plot, teleporters, "market", rgb(130, 100, 255), "MARKETPLACE", "Shops, crates and trading", "Enter", "Marketplace")

	if halloween then
		-- In the corner of the plaza, facing the yard.
		Build.pumpkin(frame * CFrame.new(-17.6, 1.08, 11), 2.2, parent)
		Build.pumpkin(frame * CFrame.new(17.8, 0.75, 11.4), 1.4, parent)
	end
end

-- The portal the monsters come out of: an arch at the start of the path, glowing in the world's colour.
local function buildPortal(plot, parent: Instance)
	local frame = plot.frame * CFrame.new(PORTAL.X, 0, PORTAL.Y + PORTAL_DEPTH)
	local stone = rgb(70, 72, 84)
	plot.portalGlow = {}
	local pillarX = GATE_WIDTH / 2 + 1.2
	for _, side in { -1, 1 } do
		block(parent, "PortalPillar", Vector3.new(2.4, GATE_HEIGHT + 1, 2.4), frame * CFrame.new(side * pillarX, (GATE_HEIGHT + 1) / 2, 0), stone, M.Slate)
		table.insert(plot.portalGlow, ball(parent, "PortalHorn", 2.2, frame * CFrame.new(side * pillarX, GATE_HEIGHT + 4.5, 0), UNCLAIMED))
	end
	block(parent, "PortalBeam", Vector3.new(pillarX * 2 + 2.4, 2.4, 2.4), frame * CFrame.new(0, GATE_HEIGHT + 2.2, 0), stone, M.Slate)
	local portal = block(plot.folder, "Portal", Vector3.new(GATE_WIDTH, GATE_HEIGHT + 1, 0.6), frame * CFrame.new(0, (GATE_HEIGHT + 1) / 2, 0), UNCLAIMED)
	table.insert(plot.portalGlow, portal)
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1.4
	light.Enabled = false
	light.Parent = portal
	plot.portal, plot.portalLight = portal, light
end

local function buildPads(plot)
	local folder = Instance.new("Folder")
	folder.Name = "Pads"
	folder.Parent = plot.folder
	plot.pads = {}
	for index, spot in Layout.PADS do
		local part = Build.part({
			Name = `Pad_{index}`,
			Size = Vector3.new(Layout.PAD_SIZE, PAD_HEIGHT, Layout.PAD_SIZE),
			CFrame = plot.frame * CFrame.new(spot.X, PAD_HEIGHT / 2, spot.Y),
			Color = UNCLAIMED,
			Material = PLASTIC,
			CanTouch = false,
			Parent = folder,
		})
		part:SetAttribute("Pad", index)
		part:SetAttribute("Slot", plot.slot)
		part:SetAttribute("Owned", false)
		local prompt = Build.prompt(part, "Buy", "Cannon Pad")
		prompt.MaxActivationDistance = 10
		prompt.Enabled = false
		prompt:SetAttribute("Pad", index)
		prompt:SetAttribute("Slot", plot.slot)
		-- A plus on an empty pad of the owner's: build here.
		local plus = paint(part, Enum.NormalId.Top, "+", 30)
		plus.Parent.Enabled = false
		plot.pads[index] = { part = part, prompt = prompt, plus = plus.Parent, owned = false, sale = nil }
	end
end

-- The sign standing on a pad the owner has not bought. The price is the client's to show.
local function saleSign(plot, index: number): Model
	local spot = Layout.PADS[index]
	local base = plot.frame * CFrame.new(spot.X, PAD_HEIGHT, spot.Y)
	local model = Instance.new("Model")
	model.Name = "ForSale"
	block(model, "Post", Vector3.new(0.4, 2.6, 0.4), base * CFrame.new(0, 1.3, 0), WOOD, M.Wood)
	local board = block(model, "Board", Vector3.new(3.8, 1.7, 0.35), base * CFrame.new(0, 3.2, 0), rgb(235, 70, 70))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		paint(board, face, "FOR SALE", 50)
	end
	model.Parent = plot.pads[index].part
	return model
end

local function towerName(kind: string): string
	local towers = (Config :: any).Towers
	local info = towers and towers[kind]
	return if info and info.name then info.name else string.upper(string.sub(kind, 1, 1)) .. string.sub(kind, 2)
end

-- Makes a pad look like what it is: not for sale (nobody owns the plot), for sale, the owner's and empty, or
-- carrying a tower.
local function dressPad(plot, index: number)
	local pad = plot.pads[index]
	local tower = plot.towers[index]
	local claimed = plot.owner ~= 0
	local forSale = claimed and not pad.owned and not tower
	local part, prompt = pad.part, pad.prompt
	part:SetAttribute("Owned", pad.owned)
	prompt.Enabled = claimed
	pad.plus.Enabled = pad.owned and not tower
	if tower then
		part.Color, part.Material = rgb(70, 74, 86), M.DiamondPlate
		prompt.ActionText, prompt.ObjectText = "Upgrade", `{towerName(tower:GetAttribute("Kind"))} Lv {tower:GetAttribute("Level")}`
	elseif pad.owned then
		part.Color, part.Material = rgb(110, 235, 140), NEON
		prompt.ActionText, prompt.ObjectText = "Build", "Empty Pad"
	else
		part.Color, part.Material = if claimed then rgb(176, 180, 192) else UNCLAIMED, PLASTIC
		prompt.ActionText, prompt.ObjectText = "Buy", "Cannon Pad"
	end
	if forSale and not pad.sale then
		pad.sale = saleSign(plot, index)
	elseif not forSale and pad.sale then
		pad.sale:Destroy()
		pad.sale = nil
	end
end

-- The base and the portal, dressed for an owner or for nobody.
local function dressBase(plot)
	local claimed = plot.owner ~= 0
	local color = if claimed then plot.color else UNCLAIMED
	for _, part in plot.colored do
		part.Color = color
	end
	plot.gate.Color = color
	plot.gate.Transparency = if claimed then 0.55 else 1
	for _, label in plot.nameLabels do
		label.Text = if claimed then plot.ownerName else "EMPTY PLOT"
	end
	local glow = themeOf(plot.world).glow
	for _, part in plot.portalGlow do
		part.Color = if claimed then glow else rgb(52, 54, 66)
		part.Material = if claimed then NEON else PLASTIC
	end
	plot.portal.Transparency = if claimed then 0.3 else 0.7
	plot.portalLight.Enabled = claimed
	plot.portalLight.Color = glow
end

local function dressWorld(plot, worldIndex: number)
	local world, theme = Config.Worlds[worldIndex], themeOf(worldIndex)
	plot.world = worldIndex
	plot.ground.Color, plot.ground.Material = world.floor, theme.ground
	plot.yard.Color, plot.yard.Material = world.floor, theme.ground
	-- The hills around the base: the backdrop's colour, a little towards the ground's, in two shades.
	for index, part in plot.surround do
		part.Color = world.backdrop:Lerp(world.floor, 0.3):Lerp(BLACK, if index % 2 == 0 then 0.1 else 0.22)
	end
	for _, part in plot.road do
		part.Color, part.Material = theme.road, theme.roadMaterial
	end
	for _, part in plot.kerb do
		part.Color, part.Material = theme.kerb, theme.kerbMaterial
	end
	-- The slabs of the skyline step down in brightness towards the corners.
	local shades = { 0.14, 0.05, 0, 0.08, 0.18 }
	for index, part in plot.backdrop do
		part.Color = world.backdrop:Lerp(BLACK, shades[index])
	end
	plot.worldLabel.Text = string.upper(world.name)

	if plot.decor then
		plot.decor:Destroy()
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	for index, spot in PROP_SPOTS do
		local base = plot.frame * CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, index * 2.4, 0)
		PROPS[theme.prop](decor, base, spot[3], theme)
	end
	decor.Parent = plot.folder
	plot.decor = decor
	dressBase(plot)
end

local function buildPlot(slot: number)
	local folder = Instance.new("Folder")
	folder.Name = `Plot_{slot}`
	folder:SetAttribute("Slot", slot)
	folder:SetAttribute("Owner", 0)
	local plot = {
		slot = slot,
		frame = Layout.plotCFrame(slot),
		folder = folder,
		color = slotColor(slot),
		owner = 0,
		ownerName = "",
		towers = {}, -- pad index -> tower Model
	}
	plots[slot] = plot

	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = folder
	buildGround(plot, scenery)
	buildBase(plot, scenery)
	buildPortal(plot, scenery)
	buildPads(plot)
	local towers = Instance.new("Folder")
	towers.Name = "Towers"
	towers.Parent = folder
	plot.towerFolder = towers

	dressWorld(plot, 1)
	for index in plot.pads do
		dressPad(plot, index)
	end
	folder.Parent = root
end

----------------------------------------------------------------------------------------------------
-- The lobby: where a character appears before the game has moved it to its base (Layout.LOBBY). A small
-- closed room far from everything, for the moment a save takes to load.
----------------------------------------------------------------------------------------------------
local LOBBY_RADIUS = 12

local function buildLobby()
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = root
	local origin = CFrame.new(Layout.LOBBY)
	disc(lobby, "LobbyFloor", origin * CFrame.new(0, -4, 0), LOBBY_RADIUS + 2, 4, rgb(198, 180, 152), M.Slate, true)
	disc(lobby, "LobbyRing", origin, 5, 0.1, rgb(90, 220, 255), NEON)
	-- Eight pieces of wall, higher than a jump, with an unseen one over each.
	local pieces = 8
	local length = 2 * LOBBY_RADIUS * math.tan(math.pi / pieces) + 0.6
	for index = 1, pieces do
		local turn = origin * CFrame.Angles(0, (index - 0.5) * 2 * math.pi / pieces, 0)
		block(lobby, "LobbyWall", Vector3.new(length, 10, 2), turn * CFrame.new(0, 5, -LOBBY_RADIUS - 1), STONE, M.Brick, true)
		Build.part({
			Name = "Barrier",
			Size = Vector3.new(length, BARRIER_HEIGHT, 2),
			CFrame = turn * CFrame.new(0, BARRIER_HEIGHT / 2, -LOBBY_RADIUS - 1),
			Transparency = 1,
			CanCollide = true,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = lobby,
		})
	end
	local orb = ball(lobby, "LobbyOrb", 2.4, origin * CFrame.new(0, 9, 0), GOLD, NEON)
	local gui = Build.billboard(orb, Vector2.new(22, 5), Vector3.new(0, 3.6, 0), 200)
	Build.label(gui, "Opening your base...")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Layout.LOBBY + Vector3.new(0, 0.35, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = lobby
end

----------------------------------------------------------------------------------------------------
-- The API (docs/DEFENSE_SPEC.md, section 6)
----------------------------------------------------------------------------------------------------
-- All twelve bases and the lobby, once, at start.
function Plots.build()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	halloween = Config.halloweenActive(os.time())
	root = Instance.new("Folder")
	root.Name = "Plots"
	-- Mini cannons live here, where the client looks for them (petsOf in src/client/Effects.luau).
	-- Reuses the folder if the old lanes already made one, so the client never finds two.
	local existingPets = workspace:FindFirstChild("Cannons")
	if existingPets and existingPets:IsA("Folder") then
		petFolder = existingPets
	else
		petFolder = Instance.new("Folder")
		petFolder.Name = "Cannons"
		petFolder.Parent = workspace
	end

	buildLobby()
	for slot = 1, Layout.PLOT_COUNT do
		buildPlot(slot)
	end
	root.Parent = workspace
end

-- The plot is `player`'s: their name over the gate, the gate and the portal lit, the pads for sale.
function Plots.claim(slot: number, player: Player)
	local plot = plots[slot]
	if not plot then
		return
	end
	plot.owner = player.UserId
	plot.ownerName = `{player.DisplayName}'s Base`
	plot.folder:SetAttribute("Owner", player.UserId)
	dressBase(plot)
	for index in plot.pads do
		dressPad(plot, index)
	end
end

-- The owner left: towers gone, no pad owned, the sign cleared, back to the first world's look.
function Plots.release(slot: number)
	local plot = plots[slot]
	if not plot then
		return
	end
	plot.owner, plot.ownerName = 0, ""
	plot.folder:SetAttribute("Owner", 0)
	for _, tower in plot.towers do
		tower:Destroy()
	end
	plot.towers = {}
	for index, pad in plot.pads do
		pad.owned = false
		dressPad(plot, index)
	end
	if plot.world == 1 then
		dressBase(plot)
	else
		dressWorld(plot, 1)
	end
end

-- Recolours the ground, the path, the backdrop and the portal for a world, and swaps the props.
function Plots.setWorld(slot: number, worldIndex: number)
	local plot = plots[slot]
	if not plot then
		return
	end
	local index = math.clamp(math.floor(worldIndex), 1, #Config.Worlds)
	if plot.world ~= index then
		dressWorld(plot, index)
	end
end

-- owned: the indices of the pads the owner has bought.
function Plots.setPads(slot: number, owned: { number })
	local plot = plots[slot]
	if not plot then
		return
	end
	local has = {}
	for _, index in owned do
		has[index] = true
	end
	for index, pad in plot.pads do
		local now = has[index] == true
		if pad.owned ~= now then
			pad.owned = now
			dressPad(plot, index)
		end
	end
end

-- Which way a new tower looks: at the nearest stretch of the path, in plot space.
local function padFacing(index: number): Vector3
	local pad = Layout.PADS[index]
	local best, bestDistance = Vector2.new(0, 1), math.huge
	for segment = 1, #Layout.PATH - 1 do
		local from, to = Layout.PATH[segment], Layout.PATH[segment + 1]
		local span = to - from
		local share = math.clamp((pad - from):Dot(span) / span:Dot(span), 0, 1)
		local offset = from + span * share - pad
		if offset.Magnitude > 0.01 and offset.Magnitude < bestDistance then
			best, bestDistance = offset.Unit, offset.Magnitude
		end
	end
	return Vector3.new(best.X, 0, best.Y)
end

-- Builds or replaces the tower on a pad; kind = nil removes it.
-- A level that looks the same as the one standing there (same kind, same tier) only updates its Level
-- attribute, so upgrading does not rebuild the model ten times in a row.
function Plots.setTower(slot: number, pad: number, kind: string?, level: number?)
	local plot = plots[slot]
	if not plot or not plot.pads[pad] then
		return
	end
	local old = plot.towers[pad]
	if not kind then
		if old then
			old:Destroy()
			plot.towers[pad] = nil
		end
		dressPad(plot, pad)
		return
	end
	local newLevel = math.max(1, math.floor(level or 1))
	if old and old:GetAttribute("Kind") == kind and old:GetAttribute("Tier") == Models.towerTier(newLevel) then
		old:SetAttribute("Level", newLevel)
	else
		if old then
			old:Destroy()
		end
		local model = Models.tower(kind, newLevel, nil)
		model.Name = `Tower_{pad}`
		model:SetAttribute("Pad", pad)
		local position = Layout.padPosition(slot, pad) + Vector3.new(0, PAD_HEIGHT, 0)
		model:PivotTo(CFrame.lookAt(position, position + plot.frame:VectorToWorldSpace(padFacing(pad))))
		model.Parent = plot.towerFolder
		plot.towers[pad] = model
	end
	dressPad(plot, pad)
end

----------------------------------------------------------------------------------------------------
-- Mini cannons
----------------------------------------------------------------------------------------------------
local MINI_TIER_GROWTH = 0.08 -- a fused mini cannon is this much bigger for every tier it has
local HUGE_SCALE = 4 -- a Huge cannon at its owner's side against an ordinary mini cannon
local SPARE_HUGE_SCALE = 3 -- and a Huge in a follow spot, when both sides are taken
local NEON_RARITIES = { Legendary = true, Exclusive = true, Secret = true, Mythical = true }
local GLOW_RANGE = { Secret = 9, Mythical = 26 } -- these also light up what is around them, this many studs
local FOLLOW_SPOTS = 14 -- how many spots Layout.miniFollow has
-- The first two Huges fly at their owner's side instead of in a follow spot, the first on the left: a Huge is
-- as big as six spots. These are the client's own offsets for them (HUGE_FOLLOW in src/client/Effects.luau),
-- in the owner's space (+Z is behind); here they only say where a Huge waits before the client moves it.
local HUGE_SIDES = { Vector3.new(-6.6, 1.2, 1.5), Vector3.new(6.6, 1.2, 1.5) }

-- The mini cannons of one player, as a Model named Pets_<userId> in workspace.Cannons. On a plot they always
-- follow their owner; each client moves them (src/client/Effects.luau). Until it does they wait behind the
-- plot's spawn point, where their owner arrives.
-- Each mini cannon is a Model whose PrimaryPart is its barrel, with the attributes the client reads:
--   Home    CFrame of the barrel where it waits
--   PetId   which mini cannon it is (Config.Pets)
--   Perch   1 or 2 on a Huge that flies at its owner's side (the first on the left)
--   Follow  on the others: which of Layout.miniFollow's spots it takes (the ones beside a Huge go last)
-- A fused one wears one glowing band per tier, in its tier's colour. A Huge is HUGE_SCALE times the size, with
-- bands and a halo in its accent colour, sparks coming off it and its name over it.
function Plots.buildPets(slot: number, equipped: { string }, userId: number): Model
	local container = Instance.new("Model")
	container.Name = "Pets_" .. userId
	local owner = Layout.plotSpawn(slot)
	local direction = Vector3.new(0, 0.2, 1).Unit
	-- The sides go to the first Huges in the list (Config.equippedPets puts them first). A second copy of the
	-- same Huge adds nothing, so it gets none.
	local perches, perchOf = 0, {}
	for index, id in equipped do
		if Config.Pets[id].huge and perches < #HUGE_SIDES and table.find(equipped, id) == index then
			perches += 1
			perchOf[index] = perches
		end
	end
	-- The follow spots in the order the others take them: the free ones first, then the ones a Huge at the
	-- owner's side covers. Without such a Huge that is 1, 2, 3 ...
	local followOrder, covered = {}, {}
	for spot = 1, FOLLOW_SPOTS do
		local beside = false
		for perch = 1, perches do
			beside = beside or Layout.miniFollow(spot).X * math.sign(HUGE_SIDES[perch].X) > 4
		end
		table.insert(if beside then covered else followOrder, spot)
	end
	for _, spot in covered do
		table.insert(followOrder, spot)
	end

	local placed = 0 -- mini cannons without a side so far
	for index, id in equipped do
		local pet = Config.Pets[id]
		local perch = perchOf[index]
		local scale = if perch then HUGE_SCALE elseif pet.huge then SPARE_HUGE_SCALE else 1 + MINI_TIER_GROWTH * pet.tier
		local offset, followSpot
		if perch then
			offset = HUGE_SIDES[perch]
		else
			-- Past the last spot the order starts again, as Layout's own list does.
			followSpot = followOrder[placed % FOLLOW_SPOTS + 1]
			placed += 1
			offset = Layout.miniFollow(followSpot)
		end
		-- The mini cannon's own frame: its +Z is the way its owner faces, as the lanes had it.
		local position = owner * offset
		local frame = CFrame.lookAt(position, position - owner.LookVector)
		-- A mini cannon with a Blender model is that one part. Fusing it tints it and makes it shine.
		local modelled = Models.mini(pet, scale)
		if modelled then
			local model = Instance.new("Model")
			model.Name = "Mini" .. index
			if pet.tier > 0 then
				modelled.Color = WHITE:Lerp(Config.FuseTiers[pet.tier].color, 0.45)
				modelled.Reflectance = 0.12 * pet.tier
			end
			modelled:PivotTo(frame * Build.along(Vector3.zero, Vector3.zAxis))
			modelled.Parent = model
			model.PrimaryPart = modelled
			model:SetAttribute("Home", model:GetPivot())
			model:SetAttribute("PetId", id)
			model:SetAttribute("Follow", followSpot)
			model.Parent = container
			continue
		end
		local function place(name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
			return Build.part({
				Name = name,
				Shape = shape,
				Size = size * scale,
				CFrame = frame * cframe,
				Color = color,
				Material = material or PLASTIC,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			})
		end
		local cylinder = Enum.PartType.Cylinder
		local function band(name: string, thickness: number, diameter: number, along: number, color: Color3): Part
			return place(name, cylinder, Vector3.new(thickness, diameter, diameter), Build.along(direction * along * scale, direction), color, NEON)
		end

		local model = Instance.new("Model")
		model.Name = "Mini" .. index
		local barrelMaterial = if NEON_RARITIES[pet.rarity] then NEON else Enum.Material.Metal
		local barrel = place("Barrel", cylinder, Vector3.new(2.2, 1, 1), Build.along(Vector3.zero, direction), pet.color, barrelMaterial)
		barrel.Parent = model
		if GLOW_RANGE[pet.rarity] then
			local glow = Instance.new("PointLight")
			glow.Range = GLOW_RANGE[pet.rarity]
			glow.Brightness = 1.5
			glow.Color = pet.accent or pet.color
			glow.Parent = barrel
		end
		if pet.huge then
			-- Its aura: sparks in its two colours drift off it and trail behind it.
			local sparks = Instance.new("ParticleEmitter")
			sparks.Color = ColorSequence.new(pet.accent, pet.color)
			sparks.LightEmission = 0.8
			sparks.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3 * scale),
				NumberSequenceKeypoint.new(1, 0),
			})
			sparks.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			sparks.Lifetime = NumberRange.new(0.7, 1.3)
			sparks.Rate = 16
			sparks.Speed = NumberRange.new(1.5, 3.5)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Parent = barrel
			-- And its name, for everyone who walks past it. In studs, so it shrinks with distance.
			local sign = Build.billboard(barrel, Vector2.new(1.5, 0.4) * scale, Vector3.new(0, 1.4 * scale, 0), 150)
			local name = Build.label(sign, string.upper(pet.name))
			name.Size = UDim2.fromScale(1, 0.6)
			name.TextColor3 = Config.RarityColors[pet.rarity]
			local power = Build.label(sign, `x{pet.power} TOWER DAMAGE`)
			power.Position = UDim2.fromScale(0, 0.6)
			power.Size = UDim2.fromScale(1, 0.4)
			power.TextColor3 = pet.accent
			for _, along in { 0.85, 0.2, -0.75 } do
				band("Band", 0.16, 1.2, along, pet.accent).Parent = model
			end
			-- A cylinder lies along its X axis: stood on end it is a flat disc, floating over the eyes.
			local halo = place("Halo", cylinder, Vector3.new(0.07, 1.3, 1.3), CFrame.new(Vector3.new(0, 1.05, -0.1) * scale) * CFrame.Angles(0, 0, math.rad(90)), pet.accent, NEON)
			halo.Transparency = 0.3
			halo.Parent = model
		end
		for tier = 1, pet.tier do
			-- The first band sits just behind the muzzle, the rest step back from it.
			band("Trim", 0.18, 1.28, 1.19 - tier * 0.29, Config.FuseTiers[pet.tier].color).Parent = model
		end
		for _, side in { -1, 1 } do
			place("Wheel", cylinder, Vector3.new(0.25, 0.9, 0.9), CFrame.new(Vector3.new(side * 0.62, -0.35, -0.2) * scale), rgb(40, 40, 40)).Parent = model
			-- Eyes sit on top at the back: they look at whoever walks behind the owner.
			place("Eye", BALL, Vector3.one * 0.36, CFrame.new(Vector3.new(side * 0.24, 0.42, -0.6) * scale), WHITE).Parent = model
			place("Pupil", BALL, Vector3.one * 0.18, CFrame.new(Vector3.new(side * 0.24, 0.5, -0.74) * scale), BLACK).Parent = model
		end
		model.PrimaryPart = barrel
		model:SetAttribute("Home", barrel.CFrame)
		model:SetAttribute("PetId", id)
		if perch then
			model:SetAttribute("Perch", perch)
		else
			model:SetAttribute("Follow", followSpot)
		end
		model.Parent = container
	end
	container.Parent = petFolder
	return container
end

return Plots
