-- Part-building helpers shared by the Arena and the Marketplace. The whole map is made from code with these.
local Build = {}

local WHITE = Color3.new(1, 1, 1)

function Build.part(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

-- A cylinder's long axis is its X axis; this points that axis along `direction`.
function Build.along(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
end

-- An upright cylinder (a disc or a pillar) whose base sits at `base`.
function Build.pillar(base: CFrame, radius: number, height: number, props): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, radius * 2, radius * 2)
	local part = Build.part(props)
	part.CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- Turns a block into an ellipsoid of the same size.
function Build.ellipsoid(part: Part): Part
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

function Build.label(parent: Instance, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = parent
	return label
end

-- Text painted on one face of a part.
function Build.surface(part: BasePart, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = part
	return gui
end

-- A sign floating above a part. size is in studs, so it shrinks with distance like a real sign.
function Build.billboard(part: BasePart, size: Vector2, offset: Vector3, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size.X, size.Y)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

function Build.prompt(part: Instance, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	-- The client draws every prompt itself, in the game's own style (src/client/Market.luau).
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = part
	return prompt
end

-- A jack-o'-lantern whose face looks along the frame's -Z.
function Build.pumpkin(frame: CFrame, size: number, parent: Instance)
	local glow = Color3.fromRGB(255, 230, 90)
	local function piece(name: string, partSize: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
		return Build.part({
			Name = name,
			Size = partSize * size,
			CFrame = frame * CFrame.new(offset * size),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = parent,
		})
	end
	Build.ellipsoid(piece("Pumpkin", Vector3.new(1, 0.85, 1), Vector3.zero, Color3.fromRGB(255, 130, 30)))
	piece("Stem", Vector3.new(0.14, 0.3, 0.14), Vector3.new(0, 0.5, 0), Color3.fromRGB(70, 120, 50))
	for _, side in { -1, 1 } do
		piece("Glow", Vector3.new(0.17, 0.17, 0.08), Vector3.new(side * 0.2, 0.12, -0.46), glow, Enum.Material.Neon)
	end
	piece("Glow", Vector3.new(0.44, 0.1, 0.08), Vector3.new(0, -0.14, -0.47), glow, Enum.Material.Neon)
end

return Build
