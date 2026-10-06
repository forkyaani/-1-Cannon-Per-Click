-- Files freshly imported Blender models where the game looks for them. ONE script for every kind of import.
--
-- How to use: import the .fbx files (File > Import, tick Anchored, Import), then paste this WHOLE file into
-- Studio's command bar (View > Command Bar) and press Enter, in edit mode (not while playing). Then save
-- (File > Save to Roblox). See place/README.md.
--
-- It looks at every Model that sits directly in the Workspace and goes by its name (the .fbx file's name):
--     <world>_island     ->  ReplicatedStorage.IslandModels.<World>  +  <World>Shells    (src/server/Islands.luau)
--     <world>_base       ->  ReplicatedStorage.BaseModels.<World>    +  <World>Shells
--     marketplace        ->  ReplicatedStorage.MarketModels.Market   +  MarketShells
--     <world>_creatures  ->  ReplicatedStorage.Creatures.<monster's name>                (src/shared/Models.luau)
--     <world>_minis      ->  ReplicatedStorage.MiniCannons.<pet id>  +  EggModels.<egg id>   (Models.mini,
--     marketplace_minis      the same                                     src/server/Marketplace.luau)
-- <world> is the world's name in small letters with _ for spaces: earth_island, moon_base, the_sun_island
-- (-> "The Sun"). Anything else in the Workspace is left alone. A filed import is removed from the Workspace.
-- Running it again is safe: a template of the same name is replaced, everything else is kept.
--
-- SCENES (island, base, marketplace). An FBX arrives dropped anywhere and turned half a circle (Blender's
-- (x, y, z) lands at Roblox (-x, z, y)), so the script has to find the scene's origin, its size and where its
-- north is. It uses two marker meshes when the export has them (they are deleted afterwards):
--     <Prefix>_Origin   a 2 x 2 x 2 cube, its middle 1 above the scene's origin
--     <Prefix>_North    a 2 x 2 x 2 cube at Blender +Y 10 (the scene's north; its height does not matter)
-- Without `_Origin` it measures a shell that is known to stand on the origin (FALLBACK.stand, FALLBACK.across
-- studs wide); without `_North` it looks which side a mesh that is known to be off-centre landed on
-- (FALLBACK.side), and if that mesh is missing too it takes the half circle the importer has always made.
-- A scenery mesh keeps its name and goes in the Model, whose pivot is the scene's origin with -Z to the north.
-- A shell loses its prefix (Earth_Stall -> Stall), goes in the Shells folder and gets its pivot in the middle
-- of its own base, front towards -Z. Which meshes are shells: SHELLS below; in the marketplace, every mesh
-- whose name does not start with Market_.
--
-- CREATURES. Every mesh (or model of several meshes) directly inside the import becomes a template: a Model
-- with a PrimaryPart, its pivot under its feet, facing -Z. Its name is the mesh's with spaces for underscores
-- (Moon_Rockling -> "Moon Rockling") and has to be the monster's name in src/shared/Config.luau, letter for
-- letter. The Blender front (-Y) is taken to land on -Z, unless the file has a `_North` marker.
--
-- MINI CANNONS AND EGGS (tools/blender/world_minis.py, minis.py). Every mesh in the import is one template, a
-- single MeshPart. A mesh named Egg_<id> (or egg_<id>) is an egg: it goes to EggModels as <id>, its pivot under
-- its foot, front towards -Z. Every other mesh is a mini cannon: it goes to MiniCannons under its own name (a
-- leading mini_ is dropped), its pivot in its middle with the pivot's X axis along the barrel, which is how
-- Models.mini aims it. The Blender front (-Y: the muzzle, an egg's face) is taken to land on -Z. Nothing is
-- scaled: the game sizes a mini cannon itself, and an egg comes in at 1 Blender unit = 1 stud (about 4 tall).
--
-- Every mesh is set to white, because the colours are on the vertices and a part's Color tints them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local TAG = "[setup_models]"
local FLAT = Vector3.new(1, 0, 1)

local SHELLS = {
	island = { EggPedestal = true, Stall = true, Portal = true, PortalSheet = true, BossPlinth = true },
	base = {
		Pad = true, PadTrim = true, Gate = true, GateTrim = true, Portal = true, PortalSheet = true,
		Teleporter = true, TeleporterTrim = true, Lamp = true, LampTrim = true,
	},
}
-- The shells the game cannot do without: a note in the summary when one is missing.
local NEEDED = {
	island = { "EggPedestal", "Stall", "Portal", "PortalSheet", "BossPlinth" },
	base = { "Pad", "Gate", "Portal", "PortalSheet", "Teleporter", "Lamp" },
	market = { "EggPedestal", "Stall", "Portal", "PortalSheet" },
}
-- For an export without marker meshes. `stand`: a shell whose base is centred on the origin, `across` studs
-- wide. `side`: a mesh whose middle is off-centre, and roughly where in Blender (x east, y north).
local FALLBACK = {
	island = { stand = "BossPlinth", across = 18, side = "Water", x = 1, y = -1 }, -- the pond is south-east
	base = { stand = "Pad", across = 7, side = "Road", x = 0, y = -1 }, -- the road runs south from the origin
	market = { stand = "EggPedestal", across = 6.4, side = "Backdrop", x = 0, y = 1 }, -- the hills are in the north
}
local FOLDERS = { island = "IslandModels", base = "BaseModels", market = "MarketModels" }

local rows: { { string } } = {}
local problems: { string } = {}

local function note(import: string, into: string, count: string, remark: string)
	table.insert(rows, { import, into, count, remark })
end

-- "the_sun" -> "The Sun"
local function title(words: string): string
	local out = {}
	for word in string.gmatch(words, "[^_]+") do
		table.insert(out, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return table.concat(out, " ")
end

-- A mesh's name without the ".001" Blender adds to a second one of the same name.
local function clean(name: string): string
	return (string.gsub(name, "%.%d+$", ""))
end

-- What a mesh is, without its prefix: "Earth_EggPedestal" -> "EggPedestal", "Stall" -> "Stall".
local function pieceOf(name: string): string
	return string.match(clean(name), "([^_]+)$") or clean(name)
end

local function meshesIn(root: Instance): { MeshPart }
	local found = {}
	for _, item in root:GetDescendants() do
		if item:IsA("MeshPart") then
			table.insert(found, item)
		end
	end
	return found
end

local function find(parts: { MeshPart }, piece: string): MeshPart?
	for _, part in parts do
		if pieceOf(part.Name) == piece then
			return part
		end
	end
	return nil
end

-- The lowest and highest corners of the parts, in world space.
local function box(parts: { MeshPart }): (Vector3, Vector3)
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

-- The middle of the parts' box, on its floor.
local function foot(parts: { MeshPart }): Vector3
	local low, high = box(parts)
	return Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
end

local function dress(part: MeshPart)
	local piece = pieceOf(part.Name)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = Color3.new(1, 1, 1) -- the colours are on the vertices
	part.Material = Enum.Material.SmoothPlastic
	if piece == "Glow" then
		part.Material = Enum.Material.Neon
	elseif piece == "PortalSheet" then
		part.Material = Enum.Material.Neon
		part.Transparency = 0.3
		part.CastShadow = false
	elseif piece == "Water" then
		part.Transparency = 0.15
		part.Reflectance = 0.12
		part.CastShadow = false
	end
end

-- Puts `new` in ReplicatedStorage.<folderName>, in place of what had its name.
local function fileInto(folderName: string, new: Instance)
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = ReplicatedStorage
	end
	local old = folder:FindFirstChild(new.Name)
	while old do
		old:Destroy()
		old = folder:FindFirstChild(new.Name)
	end
	new.Parent = folder
end

-- Which way a `_North` marker lies from `origin`, flat; nil when it sits on the origin.
local function towards(origin: Vector3, marker: MeshPart): Vector3?
	local flat = (marker.Position - origin) * FLAT
	if flat.Magnitude < 0.5 then
		return nil
	end
	local north = flat.Unit
	if math.abs(north.Z) > 0.999 then
		north = Vector3.new(0, 0, math.sign(north.Z)) -- no crumbs of a degree in the pivots
	elseif math.abs(north.X) > 0.999 then
		north = Vector3.new(math.sign(north.X), 0, 0)
	end
	return north
end

----------------------------------------------------------------------------------------------------
-- Scenes: island, base, marketplace
----------------------------------------------------------------------------------------------------
local function fileScene(import: Model, kind: string, world: string)
	local parts = meshesIn(import)
	if #parts == 0 then
		error(`{import.Name}: no meshes inside. Import the .fbx again (File > Import).`, 0)
	end
	local fallback = FALLBACK[kind]
	local remarks = {}
	local originMarker, northMarker = find(parts, "Origin"), find(parts, "North")
	local stand = find(parts, fallback.stand)
	if not originMarker and not stand then
		error(`{import.Name}: cannot find the scene's origin. It has neither a marker mesh "..._Origin" nor the shell "{fallback.stand}". Export it again from Blender with the marker meshes.`, 0)
	end

	-- 1. Size: 1 Blender unit has to be 1 stud.
	local factor
	if originMarker then
		factor = 2 / ((originMarker.Size.X + originMarker.Size.Y + originMarker.Size.Z) / 3)
	else
		local low, high = box({ stand :: MeshPart })
		factor = fallback.across / math.max(high.X - low.X, high.Z - low.Z)
	end
	if factor ~= factor or factor < 0.0001 or factor > 10000 then
		error(`{import.Name}: its size makes no sense (it would have to be scaled {factor} times).`, 0)
	end
	if math.abs(factor - 1) > 0.01 then
		import:ScaleTo(import:GetScale() * factor)
		table.insert(remarks, string.format("scaled x%.3f", factor))
	end

	-- 2. The origin: on the ground, in the middle of the scene.
	local origin
	if originMarker then
		origin = originMarker.Position - Vector3.yAxis
	else
		origin = foot({ stand :: MeshPart })
		table.insert(remarks, `no _Origin marker: origin from {fallback.stand}`)
	end

	-- 3. North. The importer turns a scene half a circle, so Blender's +Y lands on +Z.
	local north = northMarker and towards(origin, northMarker)
	if northMarker and not north then
		error(`{import.Name}: the marker "{northMarker.Name}" sits on the origin. It has to be 10 to the north (Blender +Y).`, 0)
	end
	if northMarker and north then
		local far = ((northMarker.Position - origin) * FLAT).Magnitude
		if math.abs(far - 10) > 0.5 then
			table.insert(remarks, string.format("_North marker is %.1f from the origin, not 10", far))
		end
	end
	if not north then
		local side = find(parts, fallback.side)
		local turned = true
		local sure = false
		if side then
			local low, high = box({ side })
			local offset = ((low + high) / 2 - origin) * FLAT
			local landed = offset:Dot(Vector3.new(-fallback.x, 0, fallback.y)) -- above 0: where a turned scene puts it
			if math.abs(landed) > 1 then
				turned = landed > 0
				sure = true
			end
		end
		north = if turned then Vector3.zAxis else -Vector3.zAxis
		table.insert(remarks, if sure then `no _North marker: north from {fallback.side}` else "no _North marker: took the importer's usual half circle")
	end
	local north3 = north :: Vector3
	local sceneryPivot = CFrame.lookAt(origin, origin + north3) -- -Z to the north, as in the game
	local shellPivot = CFrame.lookAt(origin, origin - north3) -- a shell's front (Blender -Y) is its -Z

	-- 4. File the meshes.
	local scenery = Instance.new("Model")
	scenery.Name = world
	local shells = Instance.new("Folder")
	shells.Name = world .. "Shells"
	local sceneryCount, shellCount = 0, 0
	local seen = {}
	for _, part in parts do
		local name, piece = clean(part.Name), pieceOf(part.Name)
		if part == originMarker or part == northMarker or piece == "Origin" or piece == "North" then
			part:Destroy()
			continue
		end
		local isShell
		if kind == "market" then
			isShell = string.sub(name, 1, 7) ~= "Market_"
		else
			isShell = SHELLS[kind][piece] == true
		end
		dress(part)
		if isShell then
			if seen[piece] then
				table.insert(remarks, `two shells named {piece}`)
			end
			seen[piece] = true
			part.PivotOffset = part.CFrame:ToObjectSpace(shellPivot)
			part.Name = piece
			part.Parent = shells
			shellCount += 1
		else
			part.Name = name
			part.Parent = scenery
			sceneryCount += 1
		end
	end
	scenery.WorldPivot = sceneryPivot

	local missing = {}
	for _, piece in NEEDED[kind] do
		if not seen[piece] then
			table.insert(missing, piece)
		end
	end
	if #missing > 0 then
		table.insert(remarks, "MISSING shells: " .. table.concat(missing, ", "))
	end
	if sceneryCount == 0 then
		table.insert(remarks, "NO scenery meshes")
	end

	fileInto(FOLDERS[kind], scenery)
	fileInto(FOLDERS[kind], shells)
	import:Destroy()
	print(`{TAG} {import.Name}: {sceneryCount} scenery meshes, {shellCount} shells`)
	note(import.Name, `{FOLDERS[kind]}.{world} + {world}Shells`, `{sceneryCount} + {shellCount}`, table.concat(remarks, "; "))
end

----------------------------------------------------------------------------------------------------
-- Creatures
----------------------------------------------------------------------------------------------------
local function fileCreatures(import: Model)
	local front = -Vector3.zAxis
	local remarks = {}
	local origin, north = nil, nil
	for _, part in meshesIn(import) do
		local piece = pieceOf(part.Name)
		if piece == "Origin" then
			origin = part
		elseif piece == "North" then
			north = part
		end
	end
	if origin and north then
		local way = towards(origin.Position, north)
		if way then
			front = -way
			table.insert(remarks, "front from the _North marker")
		end
	end
	if origin then
		origin:Destroy()
	end
	if north then
		north:Destroy()
	end

	local names = {}
	local taken = {}
	for _, child in import:GetChildren() do
		local parts: { MeshPart } = if child:IsA("MeshPart") then { child } else meshesIn(child)
		if #parts == 0 then
			continue
		end
		local name = string.gsub(clean(child.Name), "_", " ")
		if taken[name] then
			table.insert(remarks, `"{name}" is in the file twice: the last one counts`)
		end
		taken[name] = true

		-- The pivot: on the ground under its middle, facing the front (Models.monster turns and sizes it).
		local stand = foot(parts)
		local pivot = CFrame.lookAt(stand, stand + front)
		local template = Instance.new("Model")
		template.Name = name
		local body: MeshPart? = nil
		for _, part in parts do
			dress(part)
			part.Name = if #parts == 1 then "Body" else pieceOf(part.Name)
			part.Parent = template
			if not body or (body.Name ~= "Body" and (part.Name == "Body" or part.Size.Magnitude > body.Size.Magnitude)) then
				body = part
			end
		end
		local primary = body :: MeshPart
		primary.PivotOffset = primary.CFrame:ToObjectSpace(pivot)
		template.PrimaryPart = primary
		fileInto("Creatures", template)
		table.insert(names, name)
	end
	if #names == 0 then
		error(`{import.Name}: no meshes inside. Import the .fbx again (File > Import).`, 0)
	end
	table.sort(names)
	import:Destroy()
	print(`{TAG} {import.Name}: {table.concat(names, ", ")}`)
	note(import.Name, "Creatures", tostring(#names), table.concat(names, ", ") .. (if #remarks > 0 then "; " .. table.concat(remarks, "; ") else ""))
end

----------------------------------------------------------------------------------------------------
-- Mini cannons and eggs
----------------------------------------------------------------------------------------------------
local function fileMinis(import: Model)
	local front = -Vector3.zAxis -- where Blender's -Y lands: a mini cannon's muzzle, an egg's face
	local parts = meshesIn(import)
	if #parts == 0 then
		error(`{import.Name}: no meshes inside. Import the .fbx again (File > Import).`, 0)
	end
	local remarks = {}
	local taken = {}
	local minis, eggs = 0, 0
	local tallest = 0
	for _, part in parts do
		local name = clean(part.Name)
		local eggId = string.match(name, "^[Ee]gg_(.+)$")
		local id = eggId or string.match(name, "^mini_(.+)$") or name
		local key = (if eggId then "egg " else "mini ") .. id
		if taken[key] then
			table.insert(remarks, `"{name}" is in the file twice: the last one counts`)
		end
		taken[key] = true
		dress(part)
		if eggId then
			-- Pivot under its foot, looking the way its front does (Marketplace.buildEggStand stands it on that).
			-- The mesh's own origin is its foot; an importer that dropped it leaves the pivot in the middle of
			-- the mesh, and then the foot is measured.
			local stand = part:GetPivot().Position
			if (stand - part.Position).Magnitude < 0.01 then
				stand = foot({ part })
			end
			local low, high = box({ part })
			tallest = math.max(tallest, high.Y - low.Y)
			part.PivotOffset = part.CFrame:ToObjectSpace(CFrame.lookAt(stand, stand + front))
			part.Name = id
			fileInto("EggModels", part)
			eggs += 1
		else
			-- Pivot in its middle, its X axis along the barrel, upright (Models.mini; the game aims that X axis).
			part.PivotOffset = part.CFrame:ToObjectSpace(CFrame.fromMatrix(part.Position, front, Vector3.yAxis))
			part.Name = id
			fileInto("MiniCannons", part)
			minis += 1
		end
	end
	if eggs > 0 then
		table.insert(remarks, string.format("eggs up to %.1f studs tall", tallest))
		if tallest < 2 or tallest > 8 then
			table.insert(remarks, "that is NOT the size they were made at (about 4): import again with the file's own scale")
		end
	end
	import:Destroy()
	print(`{TAG} {import.Name}: {minis} mini cannons, {eggs} eggs`)
	note(import.Name, "MiniCannons + EggModels", `{minis} + {eggs}`, table.concat(remarks, "; "))
end

----------------------------------------------------------------------------------------------------
-- Go through the Workspace
----------------------------------------------------------------------------------------------------
local jobs = {}
for _, child in workspace:GetChildren() do
	if not child:IsA("Model") then
		continue
	end
	local name = string.lower(child.Name)
	local island, base = string.match(name, "^([%l_]+)_island$"), string.match(name, "^([%l_]+)_base$")
	local herd = string.match(name, "^([%l_]+)_creatures$")
	local critters = string.match(name, "^([%l_]+)_minis$")
	if name == "marketplace" then
		table.insert(jobs, { import = child, kind = "market", world = "Market" })
	elseif island then
		table.insert(jobs, { import = child, kind = "island", world = title(island) })
	elseif base then
		table.insert(jobs, { import = child, kind = "base", world = title(base) })
	elseif herd then
		table.insert(jobs, { import = child, kind = "creatures", world = title(herd) })
	elseif critters then
		table.insert(jobs, { import = child, kind = "minis", world = title(critters) })
	end
end

if #jobs == 0 then
	warn(`{TAG} Nothing to do: the Workspace has no imported model. Import an .fbx first (File > Import); its model must be named <world>_island, <world>_base, <world>_creatures, <world>_minis or marketplace, and sit directly in the Workspace.`)
else
	print(`{TAG} {#jobs} imported model(s) found`)
	for _, job in jobs do
		local name = job.import.Name
		local ok, problem = pcall(function()
			if job.kind == "creatures" then
				fileCreatures(job.import)
			elseif job.kind == "minis" then
				fileMinis(job.import)
			else
				fileScene(job.import, job.kind, job.world)
			end
		end)
		if not ok then
			table.insert(problems, tostring(problem))
			note(name, "NOT FILED", "-", "see the warning above; the import is still in the Workspace")
			warn(`{TAG} {problem}`)
		end
	end
	ChangeHistoryService:SetWaypoint("Set up imported models")

	local widths = { 6, 5, 6 }
	for _, row in rows do
		for column = 1, 3 do
			widths[column] = math.max(widths[column], #row[column])
		end
	end
	local function line(row: { string }): string
		local cells = {}
		for column = 1, 3 do
			cells[column] = row[column] .. string.rep(" ", widths[column] - #row[column])
		end
		return "  " .. table.concat(cells, "  ") .. "  " .. row[4]
	end
	print(`{TAG} Summary`)
	print(line({ "Import", "Filed", "Meshes", "Notes" }))
	for _, row in rows do
		print(line(row))
	end
	if #problems > 0 then
		warn(`{TAG} {#problems} import(s) could not be filed. Fix what the warnings say and run this again.`)
	end
	print(`{TAG} Done. Now save: File > Save to Roblox (then File > Publish to Roblox to put it live).`)
end
