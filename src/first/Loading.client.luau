-- The loading screen: the first thing a joining player sees, in place of Roblox's own, and kept up until
-- their base has opened and their character stands on it. So neither Roblox's screen nor the lobby (the
-- closed room a character waits in while its save loads, Plots.buildLobby) is ever seen.
-- This runs from ReplicatedFirst, before ReplicatedStorage has arrived: it requires nothing. Its colours,
-- fonts and text are written out here instead of read from Config and the UI kit (src/client/UI.luau, whose
-- "Candy Arcade" tokens these are). It is the one script allowed to do that.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GAME_NAME = "+1 CANNON PER CLICK" -- Config.GameName, in capitals as every title is
local WAITING_TEXT = "Opening your base..."
local TITLE_FONT = Enum.Font.LuckiestGuy -- UI.TITLE_FONT
local FONT = Enum.Font.FredokaOne -- UI.FONT

local hex = Color3.fromHex
local INK = hex("#2B1240") -- UI.Colors.ink: every outline
local CREAM = hex("#FFF3D6") -- UI.Colors.cream
local POWER = hex("#FFE23A") -- UI.Colors.power: the lemon of the Cannon Power number
local BACK_TOP = hex("#5A35B0") -- UI.Colors.row
local BACK_BOTTOM = hex("#331A6B") -- UI.Colors.pillBottom
local DOTS = { hex("#FFC61A"), hex("#5FE03A"), hex("#3FE0FF") } -- gold, green and gem

local TIMEOUT_SECONDS = 20 -- after the game has loaded: the screen goes away by then whatever happened
local SHORTEST_SECONDS = 1 -- never just a flash, even when everything is ready at once
local SETTLE_SECONDS = 0.4 -- after the character lands: time for the camera to turn and the base to draw
local FADE_SECONDS = 0.4
local ARRIVED_STUDS = 30 -- this near the base's arrival pad counts as standing on the base
local BOUNCE_HEIGHT = 18 -- design px, like every size below
local BOUNCE_SPEED = 5

-- The kit's scale: sizes are for a screen 720 px high (docs/UI_VISION.md).
local scale = math.clamp(camera.ViewportSize.Y / 720, 0.5, 1.3)

local function make(className: string, properties: { [string]: any }): any
	local instance = Instance.new(className)
	for name, value in properties do
		if name ~= "Parent" then
			instance[name] = value
		end
	end
	instance.Parent = properties.Parent
	return instance
end

----------------------------------------------------------------------------------------------------
-- The screen
----------------------------------------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "Loading",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Active, so no tap falls through to the HUD being built underneath.
local back = make("Frame", {
	Name = "Back",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Active = true,
	Parent = gui,
})
make("UIGradient", { Color = ColorSequence.new(BACK_TOP, BACK_BOTTOM), Rotation = 90, Parent = back })

local function label(name: string, text: string, font: Enum.Font, color: Color3, size: number, y: number, height: number): TextLabel
	local made = make("TextLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromScale(0.9, height),
		BackgroundTransparency = 1,
		Font = font,
		Text = text,
		TextColor3 = color,
		TextScaled = true, -- so the name still fits across a phone held upright
		Parent = back,
	})
	make("UITextSizeConstraint", { MaxTextSize = math.floor(size * scale), Parent = made })
	return made
end

-- A title is white or lemon over an ink copy of itself a little lower: its shadow.
local shadow = label("TitleShadow", GAME_NAME, TITLE_FONT, INK, 72, 0.4, 0.18)
shadow.Position += UDim2.fromOffset(0, math.ceil(5 * scale))
make("UIStroke", { Color = INK, Thickness = math.max(1.5, 4 * scale), Parent = shadow })
local title = label("Title", GAME_NAME, TITLE_FONT, POWER, 72, 0.4, 0.18)
make("UIStroke", { Color = INK, Thickness = math.max(1.5, 4 * scale), Parent = title })

local waiting = label("Waiting", WAITING_TEXT, FONT, CREAM, 30, 0.56, 0.06)
make("UIStroke", { Color = INK, Thickness = math.max(1.5, 2 * scale), Parent = waiting })

-- Three dots that bounce one after the other.
local dotSize = math.floor(22 * scale)
local dotGap = math.floor(16 * scale)
local dots: { Frame } = {}
for index, color in DOTS do
	local dot = make("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, (index - 2) * (dotSize + dotGap), 0.67, 0),
		Size = UDim2.fromOffset(dotSize, dotSize),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
	make("UIStroke", { Color = INK, Thickness = math.max(1.5, 3 * scale), Parent = dot })
	dots[index] = dot
end

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local bouncing = RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for index, dot in dots do
		local lift = math.max(0, math.sin(now * BOUNCE_SPEED - index * 0.7)) * BOUNCE_HEIGHT * scale
		dot.Position = UDim2.new(0.5, (index - 2) * (dotSize + dotGap), 0.67, -lift)
	end
end)

----------------------------------------------------------------------------------------------------
-- When the base has opened
-- The server gives the player a base once their save has loaded and says which as the player attribute Slot
-- (Game.luau, syncAll), then moves the character from the lobby onto it (onCharacter, setPlace). Slot alone
-- comes a moment before that move, so this waits for both: Slot is set, and the character stands by that
-- base's arrival pad (workspace.Plots.Plot_<slot>, the part ArrivalPad, which is where Layout.plotSpawn is).
-- Finding the pad also means the base itself has reached this client.
----------------------------------------------------------------------------------------------------
local arrivalPad: BasePart? = nil

local function onBase(): boolean
	local slot = player:GetAttribute("Slot")
	if typeof(slot) ~= "number" then
		return false
	end
	if not arrivalPad or not arrivalPad.Parent then
		local plots = workspace:FindFirstChild("Plots")
		local plot = plots and plots:FindFirstChild(`Plot_{slot}`)
		local pad = plot and plot:FindFirstChild("ArrivalPad", true)
		arrivalPad = if pad and pad:IsA("BasePart") then pad else nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not arrivalPad or not root or not root:IsA("BasePart") then
		return false
	end
	local apart = root.Position - arrivalPad.Position
	return Vector2.new(apart.X, apart.Z).Magnitude <= ARRIVED_STUDS
end

local shownAt = os.clock()
while not game:IsLoaded() do
	task.wait(0.1)
end
-- The safety net: a bug in the lines above, or on the server, must never leave a player behind this screen.
local giveUpAt = os.clock() + TIMEOUT_SECONDS
while not onBase() and os.clock() < giveUpAt do
	task.wait(0.1)
end
task.wait(math.max(SETTLE_SECONDS, SHORTEST_SECONDS - (os.clock() - shownAt)))

----------------------------------------------------------------------------------------------------
-- Fade out, then gone
----------------------------------------------------------------------------------------------------
local fade = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
back.Active = false
for _, instance in gui:GetDescendants() do
	if instance:IsA("TextLabel") then
		TweenService:Create(instance, fade, { TextTransparency = 1 }):Play()
	elseif instance:IsA("Frame") then
		TweenService:Create(instance, fade, { BackgroundTransparency = 1 }):Play()
	elseif instance:IsA("UIStroke") then
		TweenService:Create(instance, fade, { Transparency = 1 }):Play()
	end
end
task.wait(FADE_SECONDS)
bouncing:Disconnect()
gui:Destroy()
