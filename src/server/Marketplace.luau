-- The marketplace: a walkable town square players teleport to from their cannon.
-- Egg hatchery, shop stalls, leaderboards, daily chest, missions board and a portal back.
-- All built from code.
-- Prompts tagged with a "Window" attribute are handled on the client (they just open a window);
-- egg prompts and the return portal are handled by the server (see Game).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Build = require(script.Parent.Build)

local Marketplace = {}

Marketplace.eggPrompts = {} :: { [ProximityPrompt]: string } -- prompt -> egg id
Marketplace.tripleEggPrompts = {} :: { [ProximityPrompt]: string } -- "Hatch x3" prompt -> egg id
Marketplace.returnPrompt = nil :: ProximityPrompt?

local rgb = Color3.fromRGB
-- A bright toy town in daylight (docs/ui-vision/marketplace-hud.png): pale stone, pastel walls, coloured roofs.
local STONE = rgb(206, 200, 190)
local WOOD = rgb(150, 104, 66)
local DARK = rgb(44, 46, 54)
local GOLD = rgb(255, 200, 40)
local WARM = rgb(255, 214, 140)
local CREAM = rgb(255, 246, 225)
local GRASS = rgb(104, 196, 88)
local PLASTIC = Enum.Material.SmoothPlastic
local BUILDING_COLORS = {
	rgb(255, 214, 170), rgb(255, 236, 170), rgb(176, 212, 245), rgb(190, 232, 180), rgb(240, 196, 226), rgb(250, 244, 230),
}
local ROOF_COLORS = { rgb(222, 84, 70), rgb(70, 128, 220), rgb(240, 160, 50), rgb(60, 170, 150) }
local CURRENCY_ICONS = { coins = "💰", diamonds = "💎", candy = "🍬" }

local origin = Layout.marketCFrame()
local half = Layout.MARKET_SIZE / 2
local rng = Random.new(2026) -- fixed seed: the town looks the same on every server
local folder: Folder
local halloween = false
local boardLabels = {}
local marketShells: Instance? = nil -- the Blender town's landmark meshes, when the place has them (see `wear`)
local cover: (() -> ())? = nil -- hides every part the Blender town covers; set by `wear`

-- A frame in the marketplace's own space: x east, z south, the statue at (0, 0).
local function at(x: number, y: number, z: number): CFrame
	return origin * CFrame.new(x, y, z)
end

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return Build.part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = folder,
	})
end

local function sign(part: BasePart, size: Vector2, offset: Vector3, text: string, color: Color3?): TextLabel
	local label = Build.label(Build.billboard(part, size, offset, 220), text)
	label.TextColor3 = color or Color3.new(1, 1, 1)
	return label
end

----------------------------------------------------------------------------------------------------
-- Town: ground, houses around the square, lamps, trees
----------------------------------------------------------------------------------------------------
local function buildGround()
	-- Cobbles for the square, with a lawn under the houses and beyond them.
	block("Lawn", Vector3.new(half * 2 + 130, 2, half * 2 + 130), at(0, -1.08, 0), GRASS, Enum.Material.Grass)
	block("Ground", Vector3.new(half * 2 + 10, 2, half * 2 + 10), at(0, -1, 0), rgb(200, 190, 176), Enum.Material.Cobblestone)
	Build.pillar(at(0, 0, 0), 26, 0.12, { Name = "Plaza", Color = rgb(226, 212, 186), Material = Enum.Material.Slate, Parent = folder })
	Build.pillar(at(0, 0, 56), 5, 0.14, {
		Name = "ArrivalPad",
		Color = rgb(90, 220, 255),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
end

-- frame: floor-level centre of the house; its -Z faces the square.
local function buildHouse(frame: CFrame, width: number, height: number, color: Color3)
	local depth = 16
	local front = -depth / 2 - 0.15
	block("House", Vector3.new(width - 1, height, depth), frame * CFrame.new(0, height / 2, 0), color, PLASTIC)
	-- Three slabs, each smaller than the one under it, read as a pitched roof from the square.
	local roof = ROOF_COLORS[rng:NextInteger(1, #ROOF_COLORS)]
	for step = 0, 2 do
		block("Roof", Vector3.new(width - step * 7, 1.8, depth + 1.5 - step * 5), frame * CFrame.new(0, height + 0.9 + step * 1.8, 0), roof, PLASTIC)
	end
	block("Door", Vector3.new(4.5, 8, 0.6), frame * CFrame.new(0, 4, front), rgb(90, 60, 40), Enum.Material.Wood)
	local y = 6
	while y + 3 < height do
		for _, x in { -9, -3, 3, 9 } do
			local ground = y == 6 and math.abs(x) < 6 -- leave room for the door
			if not ground then
				block("WindowFrame", Vector3.new(3.9, 4.7, 0.3), frame * CFrame.new(x, y, front + 0.1), CREAM, PLASTIC)
				block("Window", Vector3.new(3.2, 4, 0.4), frame * CFrame.new(x, y, front), rgb(150, 208, 250), PLASTIC)
			end
		end
		y += 7
	end
end

local function buildTown()
	for side = 0, 3 do
		local sideFrame = origin * CFrame.Angles(0, side * math.pi / 2, 0)
		for index = 1, 5 do
			local along = -60 + (index - 1) * 30
			local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
			buildHouse(sideFrame * CFrame.new(along, 0, half + 9), 30, rng:NextInteger(22, 36), color)
		end
		local corner = sideFrame * CFrame.new(half + 9, 0, half + 9)
		Build.pillar(corner, 11, 40, { Name = "Tower", Color = STONE, Material = PLASTIC, Parent = folder })
		Build.part({
			Name = "TowerRoof",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 24,
			CFrame = corner * CFrame.new(0, 40, 0),
			Color = ROOF_COLORS[side % #ROOF_COLORS + 1],
			Material = PLASTIC,
			Parent = folder,
		})
	end
end

local function buildLamp(frame: CFrame, color: Color3)
	block("LampPost", Vector3.new(0.6, 11, 0.6), frame * CFrame.new(0, 5.5, 0), DARK, Enum.Material.Metal)
	local bulb = Build.part({
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8,
		CFrame = frame * CFrame.new(0, 11.6, 0),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})
	local light = Instance.new("PointLight")
	light.Range = 32
	light.Brightness = 1.6
	light.Color = color
	light.Parent = bulb
end

local function buildTree(frame: CFrame)
	Build.pillar(frame, 1, 7, { Name = "Trunk", Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
	-- Green in the sun; autumn colours while the Halloween event is on.
	local leaves = if halloween then { rgb(240, 130, 40), rgb(220, 80, 45), rgb(250, 190, 60) } else { rgb(86, 184, 72), rgb(116, 204, 92), rgb(70, 162, 70) }
	for index, offset in { Vector3.new(0, 10, 0), Vector3.new(2.2, 8.4, 1), Vector3.new(-2, 8.8, -1.4) } do
		Build.part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (if index == 1 then 8 else 6),
			CFrame = frame * CFrame.new(offset),
			Color = leaves[index],
			Material = PLASTIC,
			CanCollide = false,
			Parent = folder,
		})
	end
end

local function buildDecor()
	for index = 1, 8 do
		local angle = math.rad(22.5 + (index - 1) * 45)
		local frame = at(math.sin(angle) * 36, 0, math.cos(angle) * 36)
		local color = if not halloween then WARM elseif index % 2 == 0 then rgb(255, 140, 40) else rgb(170, 90, 255)
		buildLamp(frame, color)
		if halloween then
			-- Pumpkins face outwards from the statue.
			local outward = CFrame.lookAt(frame.Position, origin.Position) * CFrame.Angles(0, math.pi, 0)
			Build.pumpkin(outward * CFrame.new(1.8, 0.8, 0), 1.8, folder)
		end
	end
	for _, spot in { { 66, 66 }, { -66, 66 }, { 66, -66 }, { -66, -66 }, { 66, -22 }, { -66, -22 } } do
		buildTree(at(spot[1], 0, spot[2]))
	end
end

----------------------------------------------------------------------------------------------------
-- Centrepiece: a giant golden cannon on a fountain
----------------------------------------------------------------------------------------------------
local function buildStatue()
	Build.pillar(at(0, 0, 0), 14, 1.6, { Name = "Fountain", Color = STONE, Material = Enum.Material.Marble, Parent = folder })
	Build.pillar(at(0, 1.3, 0), 12.6, 0.5, {
		Name = "Water",
		Color = rgb(96, 190, 255),
		Material = PLASTIC,
		Transparency = 0.2,
		CanCollide = false,
		Parent = folder,
	})
	Build.pillar(at(0, 1.6, 0), 5, 4.4, { Name = "Pedestal", Color = STONE, Material = Enum.Material.Marble, Parent = folder })

	local top = 6
	block("StatueBase", Vector3.new(7, 2, 9), at(0, top + 1, 0), WOOD, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		Build.part({
			Name = "StatueWheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 7.4, 7.4),
			CFrame = at(side * 4.2, top + 3.7, 0),
			Color = rgb(110, 76, 48),
			Material = Enum.Material.Wood,
			Parent = folder,
		})
	end
	-- Aimed up and north, over the egg hatchery.
	local direction = Vector3.new(0, math.sin(math.rad(25)), -math.cos(math.rad(25)))
	local center = Vector3.new(0, top + 6.4, -1.5)
	local barrel = Build.part({
		Name = "StatueBarrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(17, 4.6, 4.6),
		CFrame = origin * Build.along(center, direction),
		Color = GOLD,
		Material = PLASTIC,
		Reflectance = 0.18,
		Parent = folder,
	})
	for ring = 0, 2 do
		Build.part({
			Name = "StatueRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 5.3, 5.3),
			CFrame = origin * Build.along(center + direction * (7.4 - ring * 2), direction),
			Color = rgb(255, 232, 140),
			Material = PLASTIC,
			Parent = folder,
		})
	end
	sign(barrel, Vector2.new(34, 5.5), Vector3.new(0, 14, 0), "MARKETPLACE", GOLD)
end

----------------------------------------------------------------------------------------------------
-- Egg hatchery: one stand per egg, in an arc across the north side
----------------------------------------------------------------------------------------------------
-- The stands are only a few studs apart, so each egg has two signs. The small Sign (name and price) always
-- shows and is narrow enough to clear its neighbours. The Panel is the same in bigger letters, with a line of
-- the player's own under it (how many of the egg's mini cannons they have found, and their luck).
-- A player's own client switches it on in place of the Sign at the egg they stand at (where a prompt carrying
-- its EggId shows): src/client/Market.luau. What the egg can hatch, with every chance, is in the loot viewer
-- (src/client/Loot.luau), which the stand's third prompt opens on this egg.
local EGG_FIT = 1.25 -- a modelled egg is made this much bigger than it was modelled
local PEDESTAL_TOP = 3 -- how high an egg stands on the Blender town's pedestal (market_manifest.json, heights)

-- Where the spots sit on an egg: directions from its centre.
local EGG_SPOTS = {
	Vector3.new(0.75, 0.35, 0.56), Vector3.new(-0.6, 0.55, 0.58), Vector3.new(0.1, -0.2, 0.98),
	Vector3.new(-0.85, -0.25, 0.46), Vector3.new(0.62, -0.5, -0.6), Vector3.new(-0.3, 0.6, -0.74),
	Vector3.new(0.9, 0.2, -0.4), Vector3.new(-0.75, -0.1, -0.65), Vector3.new(0.05, 0.95, 0.1),
}

-- `pedestal` is a mesh to stand the egg on instead of the pedestal built here (a world's Blender island
-- brings its own, src/server/Islands.luau): its pivot is the middle of its base, its top is `top` studs up.
local function buildEggStand(egg, frame: CFrame, parent: Instance, pedestal: MeshPart?, top: number?)
	local model = Instance.new("Model")
	model.Name = "Egg_" .. egg.id
	local seat = 1.7 -- how high the egg stands: the top of the cushion
	if pedestal then
		local stand = pedestal:Clone()
		stand.Name = "Pedestal"
		stand.Anchored = true
		stand.CanCollide = true
		stand:PivotTo(frame)
		stand.Parent = model
		seat = top or seat
	else
		-- A stone pedestal with a gold cushion, and on it a cream egg with spots in the egg's own colour.
		Build.pillar(frame, 2.4, 1.2, { Name = "Pedestal", Color = STONE, Material = PLASTIC, Parent = model })
		Build.pillar(frame * CFrame.new(0, 1.2, 0), 1.9, 0.5, { Name = "Cushion", Color = GOLD, Material = PLASTIC, Parent = model })
	end
	-- An egg with a Blender model (tools/blender/minis.py, imported as ReplicatedStorage.EggModels, one MeshPart
	-- per egg id with its pivot under its foot) stands on the cushion. The others are still made from parts.
	local templates = ReplicatedStorage:FindFirstChild("EggModels")
	local template = templates and templates:FindFirstChild(egg.id)
	local shell: BasePart
	if template and template:IsA("MeshPart") then
		shell = template:Clone()
		shell.Size *= EGG_FIT
		shell.PivotOffset = CFrame.new(shell.PivotOffset.Position * EGG_FIT) * shell.PivotOffset.Rotation
		shell.Name = "Egg"
		shell.Anchored = true
		shell.CanCollide = false
		shell:PivotTo(frame * CFrame.new(0, seat, 0))
		shell.Parent = model
	else
		local radii = Vector3.new(1.7, 2.2, 1.7)
		local centre = frame * CFrame.new(0, seat + 2.05, 0)
		shell = Build.ellipsoid(Build.part({
			Name = "Egg",
			Size = radii * 2,
			CFrame = centre,
			Color = egg.color:Lerp(CREAM, 0.72),
			Material = PLASTIC,
			Parent = model,
		}))
		for index, direction in EGG_SPOTS do
			local unit = direction.Unit
			Build.part({
				Name = "Spot",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (0.8 + (index % 3) * 0.22),
				CFrame = centre * CFrame.new(unit * radii * 0.88),
				Color = egg.color,
				Material = PLASTIC,
				CanCollide = false,
				Parent = model,
			})
		end
	end

	-- Title and Status at the top of a sign: titleHeight and statusHeight are shares of its height.
	-- The client rewrites Status for each player: locked, affordable or not.
	local function heading(gui: BillboardGui, titleHeight: number, statusHeight: number)
		local name = Build.label(gui, egg.name)
		name.Name = "Title"
		name.Size = UDim2.fromScale(1, titleHeight)
		name.TextColor3 = GOLD
		local status = Build.label(gui, `{Format.abbreviate(egg.cost)} {CURRENCY_ICONS[egg.currency]}`)
		status.Name = "Status"
		status.Position = UDim2.fromScale(0, titleHeight + 0.01)
		status.Size = UDim2.fromScale(1, statusHeight)
	end
	local sign = Build.billboard(shell, Vector2.new(4.8, 2.1), Vector3.new(0, 3.65, 0), 80)
	sign.Name = "Sign"
	-- A dark plate behind the two lines, so they read against any background.
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = rgb(43, 18, 64)
	plate.BackgroundTransparency = 0.15
	plate.BorderSizePixel = 0
	plate.ZIndex = 0
	local plateCorner = Instance.new("UICorner")
	plateCorner.CornerRadius = UDim.new(0.25, 0)
	plateCorner.Parent = plate
	plate.Parent = sign
	heading(sign, 0.54, 0.44)

	local prompt = Build.prompt(shell, "Hatch", egg.name)
	prompt:SetAttribute("EggId", egg.id)
	Marketplace.eggPrompts[prompt] = egg.id
	-- Roblox shows one prompt per key, so "Hatch x3" gets keys of its own. Its UI is moved down by a
	-- prompt's height (72 px) and a gap, so it sits under "Hatch" instead of on top of it.
	local triple = Build.prompt(shell, "Hatch x3", egg.name)
	triple.KeyboardKeyCode = Enum.KeyCode.R
	triple.GamepadKeyCode = Enum.KeyCode.ButtonY
	triple.UIOffset = Vector2.new(0, -80)
	triple:SetAttribute("EggId", egg.id)
	Marketplace.tripleEggPrompts[triple] = egg.id
	-- "What's inside?" opens the loot viewer on this egg. The client handles it (its Loot attribute names
	-- what to show), so it is in neither list above. It sits to the left of the two Hatch prompts, level with
	-- the gap between them: on a phone there is no room for a third prompt above or below, and the right of
	-- the screen is the menu's.
	local inside = Build.prompt(shell, "What's inside?", egg.name)
	inside.KeyboardKeyCode = Enum.KeyCode.F
	inside.GamepadKeyCode = Enum.KeyCode.ButtonB
	inside.UIOffset = Vector2.new(-300, -40)
	inside:SetAttribute("EggId", egg.id)
	inside:SetAttribute("Loot", "egg:" .. egg.id)

	model.PrimaryPart = shell
	model.Parent = parent
end

-- For the world islands: the same stand, with its prompts in the lists Game wires at start. The client finds
-- a stand's signs under Marketplace.Eggs (src/client/Market.luau), so that folder is the parent to pass.
Marketplace.buildEggStand = buildEggStand

local function buildHatchery()
	local eggFolder = Instance.new("Folder")
	eggFolder.Name = "Eggs"
	eggFolder.Parent = folder

	local eggs = {}
	for _, egg in Config.Eggs do
		-- A world's two coin eggs stand on that world's island (src/server/Islands.luau), not here.
		if not egg.world and (not egg.event or halloween) then
			table.insert(eggs, egg)
		end
	end
	-- The arc widens with the number of eggs so the stands (5.2 studs across) never touch.
	local radius = math.max(52, 5.8 * (#eggs - 1) / math.rad(156))
	for index, egg in eggs do
		-- A lone egg (the Gem Egg, outside the event) stands in the middle of the arc.
		local angle = if #eggs == 1 then 0 else math.rad(-78 + 156 * (index - 1) / (#eggs - 1))
		local position = Vector3.new(math.sin(angle) * radius, 0, -math.cos(angle) * radius)
		local pedestal = marketShells and marketShells:FindFirstChild("EggPedestal")
		if pedestal and pedestal:IsA("MeshPart") then
			buildEggStand(egg, origin * CFrame.lookAt(position, Vector3.zero), eggFolder, pedestal, PEDESTAL_TOP)
		else
			buildEggStand(egg, origin * CFrame.lookAt(position, Vector3.zero), eggFolder)
		end
	end

	local board = block("HatcherySign", Vector3.new(44, 7, 1), at(0, 18, -70) * CFrame.Angles(0, math.pi, 0), DARK)
	Build.label(Build.surface(board, Enum.NormalId.Front), "🥚 EGG HATCHERY 🥚").TextColor3 = GOLD
	for _, side in { -1, 1 } do
		block("SignPost", Vector3.new(1.2, 15, 1.2), at(side * 20, 7.5, -70), DARK)
	end
end

----------------------------------------------------------------------------------------------------
-- Stalls, boards and the rest. Each frame is floor level with -Z facing the customer.
----------------------------------------------------------------------------------------------------
local function buildStall(frame: CFrame, title: string, stripes: { Color3 }, window: string): Part
	local counter = block("Counter", Vector3.new(10, 3.2, 3), frame * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		block("StallPost", Vector3.new(0.6, 10, 0.6), frame * CFrame.new(side * 4.7, 5, 1.2), WOOD, Enum.Material.Wood)
	end
	for stripe = 1, 7 do
		-- Sloping down towards the customer.
		local cframe = frame * CFrame.new(-6 + stripe * 1.5, 9.6, -0.6) * CFrame.Angles(math.rad(-14), 0, 0)
		block("Awning", Vector3.new(1.5, 0.3, 6), cframe, stripes[stripe % 2 + 1]).CanCollide = false
	end
	local board = block("StallSign", Vector3.new(10, 2.4, 0.4), frame * CFrame.new(0, 11.8, -2.2), rgb(96, 64, 42), Enum.Material.Wood)
	Build.label(Build.surface(board, Enum.NormalId.Front), title)
	Build.prompt(counter, "Open", title):SetAttribute("Window", window)
	return counter
end

local function buildStalls()
	local east = CFrame.Angles(0, math.rad(90), 0) -- stalls on the east side face west, into the square

	local weekly = at(58, 0, 8) * east
	buildStall(weekly, "💎 WEEKLY SHOP", { rgb(70, 150, 255), rgb(240, 245, 255) }, "SHOP")
	block("Gem", Vector3.one * 1.6, weekly * CFrame.new(0, 4.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), rgb(90, 225, 255), Enum.Material.Neon)

	if halloween then
		local spooky = at(58, 0, 28) * east
		buildStall(spooky, "🎃 HALLOWEEN SHOP", { rgb(255, 130, 30), rgb(110, 60, 160) }, "SHOP")
		Build.pumpkin(spooky * CFrame.new(-2.6, 4.1, 0), 1.8, folder)
		Build.pumpkin(spooky * CFrame.new(2.4, 3.9, 0.2), 1.4, folder)
	end

	local passes = at(58, 0, 48) * east
	buildStall(passes, "⭐ GAME PASSES", { GOLD, rgb(240, 245, 255) }, "STORE")
	Build.part({
		Name = "Star",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8,
		CFrame = passes * CFrame.new(0, 4.3, 0),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
end

local function buildLeaderboard(frame: CFrame, id: string, title: string)
	for _, side in { -1, 1 } do
		block("BoardPost", Vector3.new(0.8, 5, 0.8), frame * CFrame.new(side * 6, 2.5, 0), DARK)
	end
	local board = block("Leaderboard", Vector3.new(15, 13, 0.8), frame * CFrame.new(0, 10.5, 0), DARK)
	local gui = Build.surface(board, Enum.NormalId.Front)
	local heading = Build.label(gui, title)
	heading.Size = UDim2.fromScale(1, 0.13)
	heading.TextColor3 = GOLD
	local body = Build.label(gui, "Loading...")
	body.Position = UDim2.fromScale(0.04, 0.15)
	body.Size = UDim2.fromScale(0.92, 0.82)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 26
	cap.Parent = body
	boardLabels[id] = body
end

local function buildChest(frame: CFrame)
	local metal = Enum.Material.Metal
	local chest = block("DailyChest", Vector3.new(5, 2.6, 3.4), frame * CFrame.new(0, 1.3, 0), WOOD, Enum.Material.Wood)
	block("ChestLid", Vector3.new(5.2, 1.2, 3.6), frame * CFrame.new(0, 3.2, 0), rgb(150, 100, 60), Enum.Material.Wood)
	for _, side in { -1, 1 } do
		block("ChestBand", Vector3.new(0.6, 3.9, 3.7), frame * CFrame.new(side * 1.6, 1.95, 0), GOLD, metal)
	end
	block("ChestLock", Vector3.new(0.9, 1, 0.3), frame * CFrame.new(0, 2.5, -1.8), GOLD, metal)
	sign(chest, Vector2.new(9, 1.8), Vector3.new(0, 4.4, 0), "🎁 DAILY REWARD", GOLD)
	Build.prompt(chest, "Open", "Daily Reward"):SetAttribute("Window", "DAILY")
end

local function buildNoticeBoard(frame: CFrame, text: string, window: string?)
	for _, side in { -1, 1 } do
		block("NoticePost", Vector3.new(0.6, 8, 0.6), frame * CFrame.new(side * 3.6, 4, 0), WOOD, Enum.Material.Wood)
	end
	local board = block("NoticeBoard", Vector3.new(8.4, 5, 0.5), frame * CFrame.new(0, 6, 0), rgb(214, 190, 140), Enum.Material.Wood)
	Build.label(Build.surface(board, Enum.NormalId.Front), text)
	if window then
		Build.prompt(board, "Open", "Missions"):SetAttribute("Window", window)
	end
end

local function buildPortal(frame: CFrame)
	for _, side in { -1, 1 } do
		block("PortalPillar", Vector3.new(2, 13, 2), frame * CFrame.new(side * 5.5, 6.5, 0), STONE, Enum.Material.Marble)
	end
	block("PortalBeam", Vector3.new(13, 2, 2), frame * CFrame.new(0, 14, 0), STONE, Enum.Material.Marble)
	local gate = block("Portal", Vector3.new(9, 12, 0.5), frame * CFrame.new(0, 6.5, 0), rgb(130, 100, 255), Enum.Material.Neon)
	gate.Transparency = 0.35
	gate.CanCollide = false
	sign(gate, Vector2.new(16, 2.4), Vector3.new(0, 10.4, 0), "BACK TO YOUR CANNON")
	Marketplace.returnPrompt = Build.prompt(gate, "Return", "Your Cannon")
end

-- The trading plaza: a rug with a trading table in the middle, where players meet to swap mini cannons and items.
-- Its prompt only opens the TRADE window (src/client/Features/Trading), where the trading is done.
local function buildTradingPlaza(frame: CFrame)
	local teal = rgb(90, 225, 255)
	local fabric, neon = Enum.Material.Fabric, Enum.Material.Neon
	-- Three discs, each a little taller than the one around it, make a rug with a gold ring.
	Build.pillar(frame, 9, 0.15, { Name = "TradingRug", Color = rgb(170, 50, 60), Material = fabric, Parent = folder })
	Build.pillar(frame, 6.4, 0.2, { Name = "TradingRugRing", Color = GOLD, Material = fabric, Parent = folder })
	Build.pillar(frame, 5.8, 0.25, { Name = "TradingRugCentre", Color = rgb(140, 40, 52), Material = fabric, Parent = folder })
	-- A spot for each trader, either side of the table.
	for _, side in { -1, 1 } do
		Build.pillar(frame * CFrame.new(side * 4.2, 0, 0), 1.5, 0.32, {
			Name = "TradingSpot",
			Color = if side < 0 then teal else GOLD,
			Material = neon,
			Parent = folder,
		})
	end

	-- The table, with what is being swapped on it: a mini cannon for a gem.
	Build.pillar(frame, 0.5, 2.4, { Name = "TradingTableLeg", Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
	local top = Build.pillar(frame * CFrame.new(0, 2.4, 0), 2.3, 0.4, {
		Name = "TradingTable",
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	Build.part({
		Name = "TradingCannon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, 0.6, 0.6),
		CFrame = frame * CFrame.new(-1, 3.1, 0),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	block("TradingGem", Vector3.one * 0.8, frame * CFrame.new(1, 3.5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), teal, neon)
	Build.prompt(top, "Trade", "Trading Plaza"):SetAttribute("Window", "TRADE")

	-- A lantern on each corner of the rug.
	for index = 1, 4 do
		local angle = math.rad(index * 90 - 45)
		local post = frame * CFrame.new(math.sin(angle) * 7.8, 0, math.cos(angle) * 7.8)
		block("TradingPost", Vector3.new(0.5, 4.6, 0.5), post * CFrame.new(0, 2.3, 0), DARK, Enum.Material.Metal)
		Build.part({
			Name = "TradingLantern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.3,
			CFrame = post * CFrame.new(0, 5.1, 0),
			Color = if index % 2 == 0 then GOLD else teal,
			Material = neon,
			CanCollide = false,
			Parent = folder,
		})
	end

	-- The sign hangs over an orb rather than the table: a billboard's offset follows its part's own axes, and
	-- the table top is a cylinder turned on its side.
	local orb = Build.part({
		Name = "TradingOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		CFrame = frame * CFrame.new(0, 6.2, 0),
		Color = teal,
		Material = neon,
		CanCollide = false,
		Parent = folder,
	})
	local title = sign(orb, Vector2.new(15, 3.4), Vector3.new(0, 2.6, 0), "🤝 TRADING PLAZA", GOLD)
	title.Size = UDim2.fromScale(1, 0.58)
	local how = Build.label(title.Parent, "Swap mini cannons and items with other players")
	how.Position = UDim2.fromScale(0, 0.6)
	how.Size = UDim2.fromScale(1, 0.4)

	buildNoticeBoard(frame * CFrame.new(0, 0, 10), "HOW TO TRADE\n1. Ask a player here\n2. Both add what to swap\n3. Both press READY")
	if halloween then
		Build.pumpkin(frame * CFrame.new(3.4, 0.85, 8.4), 1.6, folder)
	end
end

-- (The Fusion Machine stood here, west of the statue. It is on The Sun's island now:
-- src/server/Features/Fuse.luau.)

----------------------------------------------------------------------------------------------------
-- The Blender town (tools/blender/marketplace.py, imported with tools/studio/setup_models.luau as
-- ReplicatedStorage.MarketModels): a model "Market" whose pivot is the middle of the square on the ground,
-- and a folder "MarketShells" of landmark meshes, each with the middle of its own base as pivot and its front
-- towards -Z. Every number below is from assets/models/marketplace/market_manifest.json.
--
-- What is built from parts stays, unseen, as the floor, the walls, the lamps' light and the carrier of every
-- prompt, sign and board face, so nothing that looks for those parts has to know. Still the game's own, and
-- seen: the lamp bulbs, the trading lanterns and orb, the eggs, the Huge, the crates, the forge's shells, the
-- guide, and every BillboardGui and SurfaceGui.
----------------------------------------------------------------------------------------------------
-- Parts of the square itself (children of its folder) that the town covers.
local UNSEEN = {
	Lawn = true, Ground = true, Plaza = true, ArrivalPad = true,
	House = true, Roof = true, Door = true, WindowFrame = true, Window = true, Tower = true, TowerRoof = true,
	LampPost = true, Trunk = true, Leaves = true,
	Fountain = true, Water = true, Pedestal = true, -- the fountain's: an egg stand's is inside its own model
	StatueBase = true, StatueWheel = true, StatueBarrel = true, StatueRing = true,
	HatcherySign = true, SignPost = true,
	Counter = true, StallPost = true, Awning = true, StallSign = true, Gem = true, Star = true,
	BoardPost = true, Leaderboard = true,
	DailyChest = true, ChestLid = true, ChestBand = true, ChestLock = true, NoticePost = true, NoticeBoard = true,
	PortalPillar = true, PortalBeam = true, Portal = true,
	TradingRug = true, TradingRugRing = true, TradingRugCentre = true, TradingSpot = true, TradingTableLeg = true,
	TradingTable = true, TradingCannon = true, TradingGem = true, TradingPost = true,
	-- What features stand on the square (Huge, Crates, Event):
	HugePedestal = true, HugePedestalTop = true, HugePlate = true,
	CrateRug = true, CrateSignPost = true, CrateSign = true, CratePrices = true,
	EventBoardPost = true, EventBoardRim = true,
	-- Build.pumpkin's pieces: the town's Halloween dress brings a few big pumpkins instead.
	Pumpkin = true, Stem = true, Glow = true,
}
-- And inside the models two features parent here (Ammo, Story).
local UNSEEN_INSIDE = {
	AmmoForge = { ForgeFloor = true, Furnace = true, ForgeFire = true, ForgeChimney = true, AnvilFoot = true, Anvil = true, ForgeRack = true },
	StoryGuide = { Plinth = true },
}
-- The seasonal meshes of the model, by the end of their names: true is worn while the Halloween event is on.
local SEASONAL = { Leaves = false, Bunting = false, LeavesAutumn = true, Halloween = true }
local BOARD_HEIGHT = 10.5 -- a board's middle above its foot (buildLeaderboard, Features/Event.luau)
local EVENT_TRIM = rgb(255, 130, 30)
-- Where each landmark stands: { shell, x, z, yaw, tints }. `tints` colours the white meshes named in it.
local function landmarks()
	local white = rgb(240, 245, 255)
	local list = {
		{ "Stall", 58, 8, 90, { StallStripesA = rgb(70, 150, 255), StallStripesB = white } },
		{ "Stall", 58, 48, 90, { StallStripesA = GOLD, StallStripesB = white } },
		{ "Leaderboard", -58, -10, -90, { LeaderboardTrim = rgb(90, 225, 255) } },
		{ "Leaderboard", -58, 10, -90, { LeaderboardTrim = rgb(170, 90, 255) } },
		{ "Leaderboard", -58, 30, -90, { LeaderboardTrim = GOLD } },
		{ "NoticeBoard", -14, 42, 180 },
		{ "NoticeBoard", -44, 62, 0 },
		{ "Chest", 14, 42, 180 },
		{ "Portal", 0, 70, 0, { PortalSheet = false } },
		{ "HatcherySign", 0, -70, 180 },
		{ "TradePlaza", -44, 52, 0 },
		{ "HugePedestal", 24, -32, 143.13 },
		{ "CrateStand", -24, -32, -143.13 },
		{ "AmmoForge", 34, 26, 52.59 },
		{ "GuidePlinth", -30, 26, -49.09 },
	}
	if halloween then
		table.insert(list, { "Stall", 58, 28, 90, { StallStripesA = rgb(255, 130, 30), StallStripesB = rgb(110, 60, 160) } })
	end
	return list
end
-- Unseen boxes for the new solid things of the Halloween dress: { x, y, z, size x, y, z } (colliders).
local HALLOWEEN_SOLIDS = {
	{ 24.2, 1.84, -70.4, 4.6, 3.68, 4.6 }, { -24.2, 1.6, -70.4, 4.0, 3.2, 4.0 }, { 9.6, 1.52, 70.2, 3.8, 3.04, 3.8 },
	{ -9.4, 1.2, 70.4, 3.0, 2.4, 3.0 }, { 58.4, 1.44, 35.3, 3.6, 2.88, 3.6 }, { 19.4, 1.04, 42.2, 2.6, 2.08, 2.6 },
}

local function dressFor(): (Model?, Instance?)
	local models = ReplicatedStorage:FindFirstChild("MarketModels")
	local scenery = models and models:FindFirstChild("Market")
	local shells = models and models:FindFirstChild("MarketShells")
	if scenery and scenery:IsA("Model") and shells then
		return scenery, shells
	end
	return nil, nil
end

local function covered(item: Instance): boolean
	if not item:IsA("BasePart") then
		return false
	end
	local parent = item.Parent
	if parent == folder then
		return UNSEEN[item.Name] == true or string.sub(item.Name, 1, 11) == "EventBoard_"
	end
	local inside = parent and parent.Parent == folder and UNSEEN_INSIDE[parent.Name]
	return inside ~= nil and inside ~= false and inside[item.Name] == true
end

-- Stands a copy of a shell, and of the tinted meshes that go with it, on a frame. Copies are named
-- "Shell_<name>", so nothing takes them for the game's own part of that name.
local function standShell(shells: Instance, name: string, frame: CFrame, tints: { [string]: Color3 | boolean }?)
	local names = { [name] = true }
	for extra in tints or {} do
		names[extra] = true
	end
	for piece in names do
		local shell = shells:FindFirstChild(piece)
		if shell and (shell:IsA("BasePart") or shell:IsA("Model")) then
			local copy = shell:Clone()
			copy.Name = "Shell_" .. piece
			local tint = tints and tints[piece]
			if typeof(tint) == "Color3" and copy:IsA("BasePart") then
				copy.Color = tint
			end
			copy:PivotTo(frame)
			copy.Parent = folder
		end
	end
end

local function wear(scenery: Model, shells: Instance)
	local function hide(item: Instance)
		if not covered(item) or item:GetAttribute("Unseen") then
			return
		end
		local part = item :: BasePart
		part:SetAttribute("Unseen", true)
		part.Transparency = 1
		part.CastShadow = false
		-- A feature's event board gets the town's board behind its face, like the three built here.
		if string.sub(part.Name, 1, 11) == "EventBoard_" then
			standShell(shells, "Leaderboard", part.CFrame * CFrame.new(0, -BOARD_HEIGHT, 0), { LeaderboardTrim = EVENT_TRIM })
		end
	end
	-- Features build on the square after this (src/server/init.server.luau calls Marketplace.cover when they
	-- have started). Anything added later still is covered as it comes: a part is named and parented in no
	-- fixed order (Build.part), so it is looked at a moment after it arrives.
	cover = function()
		for _, item in folder:GetDescendants() do
			hide(item)
		end
	end
	cover()
	folder.DescendantAdded:Connect(function(item: Instance)
		task.defer(hide, item)
	end)

	local dress = scenery:Clone()
	dress.Name = "Scenery"
	for _, mesh in dress:GetChildren() do
		local season = SEASONAL[string.match(mesh.Name, "([^_]+)$") or ""]
		if season ~= nil and season ~= halloween then
			mesh:Destroy()
		end
	end
	dress:PivotTo(origin)
	dress.Parent = folder

	for _, landmark in landmarks() do
		standShell(shells, landmark[1], at(landmark[2], 0, landmark[3]) * CFrame.Angles(0, math.rad(landmark[4]), 0), landmark[5])
	end
	if halloween then
		for _, solid in HALLOWEEN_SOLIDS do
			local box = block("Solid", Vector3.new(solid[4], solid[5], solid[6]), at(solid[1], solid[2], solid[3]), STONE)
			box.Transparency = 1
			box.CastShadow = false
		end
	end
end

----------------------------------------------------------------------------------------------------
function Marketplace.build()
	halloween = Config.halloweenActive(os.time())
	folder = Instance.new("Folder")
	folder.Name = "Marketplace"
	local scenery, shells = dressFor()
	marketShells = shells

	buildGround()
	buildTown()
	buildDecor()
	buildStatue()
	buildHatchery()
	buildStalls()

	local west = CFrame.Angles(0, math.rad(-90), 0) -- boards on the west side face east, into the square
	-- Gems, Rebirths, Cannon Power: the ids and the order of Leaderboard.luau's boards.
	buildLeaderboard(at(-58, 0, -10) * west, "Gems", "MOST GEMS")
	buildLeaderboard(at(-58, 0, 10) * west, "Rebirths", "MOST REBIRTHS")
	buildLeaderboard(at(-58, 0, 30) * west, "Power", "MOST CANNON POWER")
	local south = CFrame.Angles(0, math.pi, 0) -- things by the arrival pad face the players walking in
	buildChest(at(14, 0, 42) * south)
	buildNoticeBoard(at(-14, 0, 42) * south, "📜 MISSIONS\nEarn gems every day", "MISSIONS")
	buildPortal(at(0, 0, 70))
	buildTradingPlaza(at(-44, 0, 52))
	if scenery and shells then
		wear(scenery, shells)
	end

	folder.Parent = workspace
end

-- Called once every feature has built its part of the square: on a square dressed in the Blender town, what
-- they built is covered like the rest. Does nothing on a part-built square.
function Marketplace.cover()
	if cover then
		cover()
	end
end

-- For features that add something to the square: a frame in marketplace space (x east, z south, the statue
-- at 0, 0) and the folder to parent it under. Only valid after Marketplace.build.
function Marketplace.frame(x: number, y: number, z: number): CFrame
	return at(x, y, z)
end

function Marketplace.container(): Folder
	return folder
end

-- rows: { { name = string, text = string } }, best first.
function Marketplace.setBoard(id: string, rows)
	local label = boardLabels[id]
	if not label then
		return
	end
	if #rows == 0 then
		label.Text = "No scores yet.\nBe the first!"
		return
	end
	local lines = {}
	for rank, row in rows do
		table.insert(lines, `{rank}. {row.name}  -  {row.text}`)
	end
	label.Text = table.concat(lines, "\n")
end

return Marketplace
