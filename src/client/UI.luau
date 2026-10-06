-- Small UI kit: everything on screen is built from code with these helpers.
-- The look is "Candy Arcade" (docs/UI_VISION.md): ink outlines, a darker lip under a glossy gradient face.
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local UI = {}

UI.FONT = Enum.Font.FredokaOne
UI.TITLE_FONT = Enum.Font.LuckiestGuy

-- Icon atlases: assets/ui/atlas-*.png, uploaded to Roblox as images. Each is 1024 px, a 4 x 4 grid of 256 px
-- cells. tools/icon_atlas.py builds them from a generated sheet; UI.icon cuts one icon out.
UI.Atlases = {
	a = "rbxassetid://75982409729652",
	b = "rbxassetid://89091306681120",
}

local hex = Color3.fromHex
UI.Colors = {
	white = Color3.new(1, 1, 1),
	text = hex("#FFF3D6"),
	green = hex("#5FE03A"),
	grey = hex("#9A93B5"),
	gold = hex("#FFC61A"),
	red = hex("#FF4257"),
	blue = hex("#2FA8FF"),
	orange = hex("#FF8A1F"),
	panel = hex("#2F7BFF"),
	row = hex("#5A35B0"),
	dark = hex("#3A1F55"),
	-- Nothing is outlined in pure black: every outline and text stroke is this plum.
	ink = hex("#2B1240"),
	cream = hex("#FFF3D6"),
	creamShade = hex("#E9D8AE"),
	panelTop = hex("#4DB5FF"),
	panelLip = hex("#1A3FA8"),
	wellStroke = hex("#1F5FE0"),
	pillBottom = hex("#331A6B"),
	premium = hex("#A64BFF"),
	power = hex("#FFE23A"),
	gem = hex("#3FE0FF"),
	pumpkin = hex("#FF7A1A"),
	witch = hex("#6B2BD9"),
	slime = hex("#9CFF3A"),
	neon = hex("#FF3DF0"),
}

-- A sticker's colours: the face is a gradient from top to bottom, the lip shows under it.
export type Look = { top: Color3, bottom: Color3, lip: Color3 }

UI.Variants = {
	primary = { top = hex("#8CF05A"), bottom = hex("#3CC926"), lip = hex("#1C7A14") },
	secondary = { top = hex("#6CC6FF"), bottom = hex("#1E90F0"), lip = hex("#1668C7") },
	danger = { top = hex("#FF7483"), bottom = hex("#F02B45"), lip = hex("#B81E3A") },
	gold = { top = hex("#FFE97A"), bottom = hex("#FFC61A"), lip = hex("#E08A00") },
	travel = { top = hex("#FFB01F"), bottom = hex("#FF7A1A"), lip = hex("#B8500A") },
	premium = { top = hex("#C07BFF"), bottom = hex("#8F35EE"), lip = hex("#5E1FB0") },
	disabled = { top = hex("#B4AECB"), bottom = hex("#8A83A8"), lip = hex("#6A6388") },
	panel = { top = UI.Colors.panelTop, bottom = UI.Colors.panel, lip = UI.Colors.panelLip },
	title = { top = UI.Colors.power, bottom = hex("#FFB01F"), lip = hex("#B8500A") },
}

UI.Motion = {
	press = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	release = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	pop = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	glide = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

-- Shades any colour into a sticker look, so rarity and world colours need no table of their own.
function UI.shade(color: Color3): Look
	return { top = color:Lerp(UI.Colors.white, 0.35), bottom = color, lip = color:Lerp(UI.Colors.ink, 0.45) }
end

-- Old code colours buttons with UI.Colors; those map onto the variants.
local variantByColor: { { any } } = {
	{ UI.Colors.green, UI.Variants.primary },
	{ UI.Colors.grey, UI.Variants.disabled },
	{ UI.Colors.blue, UI.Variants.secondary },
	{ UI.Colors.gold, UI.Variants.gold },
	{ UI.Colors.red, UI.Variants.danger },
	{ UI.Colors.orange, UI.Variants.travel },
	{ UI.Colors.premium, UI.Variants.premium },
}

local function lookFor(color: Color3): Look
	for _, entry in variantByColor do
		if entry[1] == color then
			return entry[2]
		end
	end
	return UI.shade(color)
end

function UI.make(className: string, props, children: { Instance }?)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

----------------------------------------------------------------------------------------------------
-- Sound. UI.sound(name) plays one of UI.Sounds for this player only; an id of 0 is silent, so a hook can be
-- in the code before its sound is chosen. Every id is from Roblox's own library (the creator "Roblox") or,
-- for the music, its licensed catalogue (APMOfficial): both may be used in any experience. They were picked
-- by name and length, not by ear: change an id here and nothing else.
----------------------------------------------------------------------------------------------------
UI.Sounds = {
	press = 15675059323, -- Roblox_UI_Bright_Click: any kit button
	open = 15675024286, -- Roblox_UI_Whoosh_01: a window opens
	close = 15675012262, -- Roblox_UI_Whoosh_04: a window closes
	error = 15675075163, -- Roblox_UI_Delete: a toast that says no
	shot = 0, -- a mini cannon fires: twenty a second, so nothing until one is found that is quiet enough
	hit = 0, -- that shot lands
	pop = 17208204604, -- Roblox GUI - Bubble: a monster of your own base is defeated
	boss = 9120031442, -- Thunder With Lion Roar: a boss level starts
	boss_down = 3149249837, -- Cannon_Explode: a boss is defeated
	clear = 15675043410, -- Roblox_UI_Tonal_Stinger: level cleared
	fail = 15675062723, -- Roblox_UI_Whistle_Low: level failed
	wobble = 15675028888, -- Roblox_UI_Whoosh_02: an egg rocks
	crack = 15675055424, -- Roblox_UI_Cute_Pop: the egg opens
	reveal = 15675032796, -- Roblox_UI_Small_Click: an ordinary mini cannon is shown
	reveal_rare = 16480570986, -- Roblox_Pinball_Bumper_Low_Bells_02: a Secret or a Huge is shown
}
UI.Music = {
	base = 9047876673, -- Happy Adventure (APM), 71 s
	market = 1840383905, -- Happy Shoppers (APM), 165 s
	island = 15675069601, -- Roblox_UI_Loop_Calm_Music, 95 s
}
local SOUND_VOLUME = 0.5
local MUSIC_VOLUME = 0.22
local QUIET = { pop = 0.25, press = 0.4, wobble = 0.35, reveal = 0.4 } -- sounds heard many times a minute
local SOUND_GAP = 0.06 -- seconds: the same sound is not started twice within this, however often it is asked for

-- Two mixers, so a switch of the SETTINGS window silences everything of its kind at once. A sound made
-- anywhere else (the crate opening) joins one with `SoundGroup = UI.SoundGroups.sound`.
UI.SoundGroups = {
	sound = UI.make("SoundGroup", { Name = "Effects", Parent = SoundService }),
	music = UI.make("SoundGroup", { Name = "Music", Parent = SoundService }),
}
-- kind is "sound" or "music".
function UI.setAudio(kind: string, on: boolean)
	local group = UI.SoundGroups[kind]
	if group then
		group.Volume = if on then 1 else 0
	end
end

local playing: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
-- pitch is a multiplier (default 1); every play is also 4% off either way, so a run of them is not a machine.
function UI.sound(name: string, pitch: number?)
	local id = UI.Sounds[name]
	local now = os.clock()
	if not id or id == 0 or now - (lastPlayed[name] or 0) < SOUND_GAP then
		return
	end
	lastPlayed[name] = now
	local sound = playing[name]
	if not sound then
		sound = UI.make("Sound", {
			Name = "Sound_" .. name,
			SoundId = `rbxassetid://{id}`,
			Volume = QUIET[name] or SOUND_VOLUME,
			SoundGroup = UI.SoundGroups.sound,
			Parent = SoundService,
		})
		playing[name] = sound
	end
	sound.PlaybackSpeed = (pitch or 1) * (0.96 + math.random() * 0.08)
	sound:Play()
end

-- The loop for where the player is: one of UI.Music, or nil for silence. Asking for the one that is playing
-- does nothing, so it can be called every frame.
local music: Sound? = nil
local musicName: string? = nil
function UI.music(name: string?)
	if name == musicName then
		return
	end
	musicName = name
	local id = if name then UI.Music[name] else nil
	if not id or id == 0 then
		if music then
			music:Stop()
		end
		return
	end
	if not music then
		music = UI.make("Sound", { Name = "Music", Looped = true, Volume = MUSIC_VOLUME, SoundGroup = UI.SoundGroups.music, Parent = SoundService })
	end
	local track = music :: Sound
	track:Stop()
	track.SoundId = `rbxassetid://{id}`
	track:Play()
end

-- Everything is laid out for a 720px tall screen and scaled to fit phones.
local scales = {}
local function currentScale(): number
	return math.clamp(camera.ViewportSize.Y / 720, 0.5, 1.3)
end

-- UIScale does not thin a UIStroke, so outlines follow the screen scale by hand.
local STROKE_TAG = "ScaledStroke"
local function strokeSize(thickness: number): number
	return math.max(math.min(thickness, 1.5), thickness * currentScale())
end

function UI.stroke(thickness: number, color: Color3?): UIStroke
	local stroke = UI.make("UIStroke", { Thickness = strokeSize(thickness), Color = color or UI.Colors.ink })
	stroke:SetAttribute("Base", thickness)
	stroke:AddTag(STROKE_TAG) -- tags go away with the instance, so rebuilt rows leak nothing
	return stroke
end

function UI.corner(radius: number): UICorner
	return UI.make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

-- Scaled text label. props.MaxSize caps the text size (for small multi-line text).
function UI.text(props): TextLabel
	local maxSize = props.MaxSize
	props.MaxSize = nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or UI.FONT
	props.TextColor3 = props.TextColor3 or UI.Colors.white
	props.TextScaled = true
	local label = UI.make("TextLabel", props, { UI.stroke(if maxSize and maxSize < 18 then 1.5 else 2) })
	if maxSize then
		UI.make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 6, Parent = label })
	end
	return label
end

-- The piece every button, panel and pill is made from: an ink-outlined lip with a gradient face on top.
-- options: radius, lip (height), gloss (default true), outside (the lip hangs below the parent, for windows).
-- Returns { lip, face, set(look) }. Put content inside `face` so it moves with a press.
function UI.sticker(parent: Instance, look: Look, options)
	local radius: number = options.radius
	local lipHeight: number = options.lip
	local outline = UI.stroke(options.outline or 3)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local lip = UI.make("Frame", {
		Name = "Lip",
		Size = if options.outside then UDim2.new(1, 0, 1, lipHeight) else UDim2.fromScale(1, 1),
		BackgroundColor3 = look.lip,
		BorderSizePixel = 0,
		Parent = parent,
	}, { UI.corner(radius), outline })
	-- A UIGradient multiplies the frame's colour, so the face itself stays white.
	local gradient = UI.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(look.top, look.bottom) })
	local face = UI.make("Frame", {
		Name = "Face",
		Size = if options.outside then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 1, -lipHeight),
		BackgroundColor3 = UI.Colors.white,
		BorderSizePixel = 0,
		Parent = parent,
	}, { UI.corner(radius), gradient })
	if options.gloss ~= false then
		local inset = math.min(8, radius * 0.5)
		UI.make("Frame", {
			Name = "Gloss",
			Position = UDim2.fromOffset(inset, 3),
			Size = UDim2.new(1, -inset * 2, 0.38, 0),
			BackgroundColor3 = UI.Colors.white,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Parent = face,
		}, { UI.corner(math.max(2, radius - inset)) }) -- its own corner: UICorner does not clip children
	end
	local sticker = { lip = lip, face = face }
	function sticker.set(newLook: Look)
		lip.BackgroundColor3 = newLook.lip
		gradient.Color = ColorSequence.new(newLook.top, newLook.bottom)
	end
	return sticker
end

-- Still a TextButton, so old code keeps writing .Text and .BackgroundColor3; both are mirrored onto the sticker.
function UI.button(props): TextButton
	props.Text = props.Text or ""
	props.BackgroundColor3 = props.BackgroundColor3 or UI.Colors.grey
	props.Font = UI.FONT
	props.TextTransparency = 1
	props.BackgroundTransparency = 1
	props.AutoButtonColor = false
	local button: TextButton = UI.make("TextButton", props)

	local height = if props.Size and props.Size.Y.Scale == 0 then props.Size.Y.Offset else 44
	local lipHeight = if height < 36 then 3 else 5
	-- The squash is on a child, so a press never shifts neighbours in a list or grid.
	local body = UI.make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = button,
	})
	local squash = UI.make("UIScale", { Parent = body })
	local sticker = UI.sticker(body, lookFor(button.BackgroundColor3), {
		radius = math.clamp(math.floor(height * 0.36), 8, 22),
		lip = lipHeight,
	})
	local label = UI.text({
		Name = "Label",
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -16, 1, -6),
		Text = button.Text,
		Parent = sticker.face,
	})

	button:GetPropertyChangedSignal("Text"):Connect(function()
		label.Text = button.Text
	end)
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		sticker.set(lookFor(button.BackgroundColor3))
	end)

	local pressed = false
	local function press(down: boolean)
		if pressed == down then
			return
		end
		pressed = down
		local info = if down then UI.Motion.press else UI.Motion.release
		TweenService:Create(squash, info, { Scale = if down then 0.95 else 1 }):Play()
		TweenService:Create(sticker.face, info, { Position = UDim2.fromOffset(0, if down then lipHeight - 1 else 0) }):Play()
	end
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) then
			press(true)
			UI.sound("press")
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			press(false)
		end
	end)
	button.MouseLeave:Connect(function()
		press(false)
	end)
	return button
end

UI.gui = UI.make("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

function UI.scaled(frame: GuiObject)
	table.insert(scales, UI.make("UIScale", { Scale = currentScale(), Parent = frame }))
	return frame
end

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	for _, uiScale in scales do
		uiScale.Scale = currentScale()
	end
	for _, stroke in CollectionService:GetTagged(STROKE_TAG) do
		stroke.Thickness = strokeSize(stroke:GetAttribute("Base"))
	end
end)

-- Both fonts and the icon atlases load early, so nothing flashes in a fallback face.
task.spawn(function()
	local probes = {}
	for _, font in { UI.FONT, UI.TITLE_FONT } do
		table.insert(probes, UI.make("TextLabel", { Font = font, Text = "0", TextTransparency = 1, BackgroundTransparency = 1, Parent = UI.gui }))
	end
	for _, atlas in UI.Atlases do
		table.insert(probes, UI.make("ImageLabel", { Image = atlas, ImageTransparency = 1, BackgroundTransparency = 1, Parent = UI.gui }))
	end
	pcall(function()
		ContentProvider:PreloadAsync(probes)
	end)
	for _, probe in probes do
		probe:Destroy()
	end
end)

-- A transparent, scaled container pinned somewhere on the HUD.
function UI.panel(props, children: { Instance }?): Frame
	props.BackgroundTransparency = 1
	props.Parent = UI.gui
	return UI.scaled(UI.make("Frame", props, children)) :: Frame
end

-- The HUD canvas: one frame over the whole screen whose children are placed in design px (720 tall), so
-- margins and gaps scale with the screen the same way sizes do.
local canvas = UI.make("Frame", {
	Name = "Canvas",
	Size = UDim2.fromScale(1 / currentScale(), 1 / currentScale()),
	BackgroundTransparency = 1,
	Parent = UI.gui,
})
local canvasScale = UI.make("UIScale", { Scale = currentScale(), Parent = canvas })

-- A transparent container on the canvas. Unlike UI.panel its Position is in design px too.
function UI.slot(props, children: { Instance }?): Frame
	props.BackgroundTransparency = 1
	props.Parent = canvas
	return UI.make("Frame", props, children)
end

-- The numbers a layout needs: the screen scale, the canvas width and the Roblox top bar's height in design px.
function UI.scale(): number
	return currentScale()
end
function UI.W(): number
	return UI.gui.AbsoluteSize.X / currentScale()
end
function UI.T(): number
	return GuiService.TopbarInset.Height / currentScale()
end

-- fn runs now and again whenever the screen or the top bar changes.
local layouts: { () -> () } = {}
function UI.onLayout(fn: () -> ())
	table.insert(layouts, fn)
	fn()
end
local function relayout()
	canvas.Size = UDim2.fromScale(1 / currentScale(), 1 / currentScale())
	canvasScale.Scale = currentScale()
	for _, fn in layouts do
		fn()
	end
end
UI.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(relayout)

local windows = {}

-- Darkens the game behind an open window. It is a button, so a tap outside closes the window and never fires the cannon.
local dimmer = UI.make("TextButton", {
	Name = "Dimmer",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = UI.Colors.ink,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 9,
	Parent = UI.gui,
})

local function refreshDimmer()
	for _, window in windows do
		if window.frame.Visible then
			dimmer.Visible = true
			return
		end
	end
	dimmer.Visible = false
end

-- A centred pop-up window. Only one is open at a time. Returns { frame, body, open, close, toggle, onOpen }.
function UI.window(title: string, width: number, height: number)
	-- `frame` is only the layout box; other files read and watch its Visible to know the window is open.
	local frame = UI.make("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		Visible = false,
		Active = true,
		ZIndex = 10,
		Parent = UI.gui,
	})
	UI.scaled(frame)
	local pop = UI.make("Frame", {
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local popScale = UI.make("UIScale", { Parent = pop })
	UI.sticker(pop, UI.Variants.panel, { radius = 28, lip = 8, outline = 4, gloss = false, outside = true })

	-- The title is a tilted tab hanging over the top-left edge.
	local tabOutline = UI.stroke(4)
	tabOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local tab = UI.make("Frame", {
		Name = "Title",
		Position = UDim2.fromOffset(18, -20),
		Size = UDim2.fromOffset(0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UI.Colors.white,
		BorderSizePixel = 0,
		Rotation = -2,
		ZIndex = 3,
		Parent = pop,
	}, {
		UI.corner(26),
		tabOutline,
		UI.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(UI.Variants.title.top, UI.Variants.title.bottom) }),
		UI.make("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }),
	})
	UI.make("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = UI.TITLE_FONT,
		Text = title,
		TextSize = 32,
		TextColor3 = UI.Colors.white,
		Parent = tab,
	}, { UI.stroke(3) })

	local closeButton = UI.button({
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(1, -40, 0, -16),
		Text = "X",
		BackgroundColor3 = UI.Colors.red,
		ZIndex = 3,
		Parent = pop,
	})
	local body = UI.make("Frame", {
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 1, -62),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = pop,
	})

	local window = { frame = frame, body = body, onOpen = nil :: (() -> ())? }
	function window.close()
		if frame.Visible then
			UI.sound("close")
		end
		frame.Visible = false
	end
	function window.open()
		UI.sound("open")
		for _, other in windows do
			other.frame.Visible = false
		end
		popScale.Scale = 0.8
		frame.Visible = true
		TweenService:Create(popScale, UI.Motion.pop, { Scale = 1 }):Play()
		if window.onOpen then
			window.onOpen()
		end
	end
	function window.toggle()
		if frame.Visible then
			window.close()
		else
			window.open()
		end
	end
	closeButton.Activated:Connect(window.close)
	frame:GetPropertyChangedSignal("Visible"):Connect(refreshDimmer)
	table.insert(windows, window)
	return window
end

function UI.closeWindows()
	for _, window in windows do
		window.frame.Visible = false
	end
end
dimmer.Activated:Connect(UI.closeWindows)

-- A vertical scrolling list that fills its parent.
function UI.scroll(parent: Instance, props): ScrollingFrame
	props = props or {}
	props.Size = props.Size or UDim2.fromScale(1, 1)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = 8
	props.ScrollBarImageColor3 = UI.Colors.ink
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	props.Parent = parent
	return UI.make("ScrollingFrame", props, {
		UI.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		-- Room for the rows' outlines, which the scrolling frame would otherwise clip.
		UI.make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
end

-- A list row: coloured icon, title, small description, and one button on the right.
function UI.row(parent: Instance, height: number, order: number)
	local outline = UI.stroke(3)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local frame = UI.make("Frame", {
		Size = UDim2.new(1, -10, 0, height),
		BackgroundColor3 = UI.Colors.row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, {
		UI.corner(14),
		outline,
		-- Callers recolour rows, so the shading multiplies whatever colour the row has.
		UI.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(UI.Colors.white, Color3.fromRGB(196, 190, 214)) }),
	})
	local icon = UI.make("Frame", {
		Size = UDim2.fromOffset(36, math.min(46, height - 16)),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		BackgroundColor3 = UI.Colors.white,
		Parent = frame,
	}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(2) })
	local title = UI.text({
		Size = UDim2.new(1, -212, 0, 26),
		Position = UDim2.fromOffset(58, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local sub = UI.text({
		Size = UDim2.new(1, -212, 0, height - 40),
		Position = UDim2.fromOffset(58, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = UI.Colors.text,
		MaxSize = 16,
		Parent = frame,
	})
	local button = UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(132, height - 18),
		Parent = frame,
	})
	return { frame = frame, icon = icon, title = title, sub = sub, button = button }
end

-- A section heading inside a list.
function UI.header(parent: Instance, order: number): TextLabel
	return UI.text({
		Size = UDim2.new(1, -10, 0, 26),
		LayoutOrder = order,
		Text = "",
		Font = UI.TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

----------------------------------------------------------------------------------------------------
-- Kit pieces for rebuilt screens. Text here has a fixed size (under the screen scale), so sibling labels match.
----------------------------------------------------------------------------------------------------

-- Where each icon sits in the atlases: name = { atlas, column, row }
local ICONS = {
	coin = { "a", 0, 0 }, gem = { "a", 1, 0 }, candy = { "a", 2, 0 }, power = { "a", 3, 0 },
	rebirth = { "a", 0, 1 }, mastery = { "a", 1, 1 }, luck = { "a", 2, 1 }, egg = { "a", 3, 1 },
	minicannon = { "a", 0, 2 }, cannon = { "a", 1, 2 }, store = { "a", 2, 2 }, missions = { "a", 3, 2 },
	chest = { "a", 0, 3 }, trophy = { "a", 1, 3 }, backpack = { "a", 2, 3 }, gear = { "a", 3, 3 },
	market = { "b", 0, 0 }, worlds = { "b", 1, 0 }, trade = { "b", 2, 0 }, ammo = { "b", 3, 0 },
	story = { "b", 0, 1 }, index = { "b", 1, 1 }, loot = { "b", 2, 1 }, gift = { "b", 3, 1 },
	lock = { "b", 0, 2 }, clock = { "b", 1, 2 }, skull = { "b", 2, 2 }, crown = { "b", 3, 2 },
	heart = { "b", 0, 3 }, tap = { "b", 1, 3 }, check = { "b", 2, 3 }, flame = { "b", 3, 3 },
}

-- A picture from the atlas. `fallback` is what stands in for it (a glyph, a code-drawn shape): it stays
-- until the picture has loaded, so a slow, pending or rejected upload never leaves a hole.
-- Returns nil for a name that is not in the atlas.
function UI.icon(name: string?, props, fallback: GuiObject?): ImageLabel?
	local cell = name and ICONS[name]
	local atlas = cell and UI.Atlases[cell[1]]
	if not atlas or atlas == "" then
		return nil
	end
	props.BackgroundTransparency = 1
	props.Image = atlas
	props.ImageRectOffset = Vector2.new(cell[2] * 256, cell[3] * 256)
	props.ImageRectSize = Vector2.new(256, 256)
	props.ScaleType = Enum.ScaleType.Fit
	local image: ImageLabel = UI.make("ImageLabel", props)
	if fallback then
		local function sync()
			fallback.Visible = not image.IsLoaded
		end
		image:GetPropertyChangedSignal("IsLoaded"):Connect(sync)
		sync()
	end
	return image
end

-- A label with a fixed text size. props.Stroke is the outline thickness (default 2; 0 for ink text on cream).
function UI.label(props): TextLabel
	local thickness = props.Stroke or 2
	props.Stroke = nil
	props.BackgroundTransparency = 1
	props.Font = props.Font or UI.FONT
	props.TextColor3 = props.TextColor3 or UI.Colors.white
	props.TextSize = props.TextSize or 24
	return UI.make("TextLabel", props, if thickness > 0 then { UI.stroke(thickness) } else nil)
end

-- A round icon: an ink ring, a cream ring, then a coloured disc with a glyph on it.
function UI.disc(props, color: Color3, glyph: string, glyphColor: Color3?): Frame
	props.BackgroundColor3 = UI.Colors.cream
	props.BorderSizePixel = 0
	local outline = UI.stroke(3)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local round = UDim.new(0.5, 0)
	return UI.make("Frame", props, {
		UI.make("UICorner", { CornerRadius = round }),
		outline,
		UI.make("Frame", {
			Name = "Disc",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, {
			UI.make("UICorner", { CornerRadius = round }),
			UI.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(UI.Colors.white, Color3.fromRGB(205, 205, 215)) }),
			UI.text({ Name = "Glyph", Position = UDim2.fromScale(0.16, 0.16), Size = UDim2.fromScale(0.68, 0.68), Text = glyph, TextColor3 = glyphColor }),
		}),
	})
end

-- A stat pill: a capsule with an icon over its left end and a number. Returns { frame, label, face }.
-- options: parent, position, size (Vector2), look, textSize, iconName (atlas picture), and the disc that
-- stands in until that has loaded: icon (glyph), iconColor, glyphColor.
function UI.pill(options)
	local size: Vector2 = options.size
	local frame = UI.make("Frame", {
		Position = options.position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = options.parent,
	})
	local sticker = UI.sticker(frame, options.look, { radius = size.Y, lip = 5, outline = 4 })
	local iconSize = size.Y + 6
	local disc = UI.disc({
		Name = "Icon",
		Position = UDim2.fromOffset(-10, -4),
		Size = UDim2.fromOffset(iconSize, iconSize),
		Rotation = -8,
		ZIndex = 2,
		Parent = frame,
	}, options.iconColor, options.icon, options.glyphColor)
	UI.icon(options.iconName, {
		Name = "Picture",
		Position = UDim2.fromOffset(-16, -10),
		Size = UDim2.fromOffset(iconSize + 12, iconSize + 12),
		Rotation = -8,
		ZIndex = 3,
		Parent = frame,
	}, disc)
	local label = UI.text({
		Name = "Number",
		Position = UDim2.fromOffset(iconSize, 4),
		Size = UDim2.new(1, -iconSize - 16, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxSize = options.textSize,
		Parent = sticker.face,
	})
	return { frame = frame, label = label, face = sticker.face }
end

-- A progress bar. The fill is always full width and a hard step in its gradient is slid along it, so the
-- fill keeps the track's round ends at any value and can glide.
-- options: parent, position, size (UDim2), color, textSize. Returns { frame, set(value, text?), setColor(color) }.
function UI.bar(options)
	local outline = UI.stroke(3)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local round = UDim.new(0.5, 0)
	local frame = UI.make("Frame", {
		Position = options.position,
		Size = options.size,
		AnchorPoint = options.anchor or Vector2.zero,
		BackgroundColor3 = UI.Colors.dark,
		BorderSizePixel = 0,
		Parent = options.parent,
	}, { UI.make("UICorner", { CornerRadius = round }), outline })
	local step = UI.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(0.5, 0),
	})
	local fill = UI.make("Frame", {
		Name = "Fill",
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundColor3 = options.color,
		BorderSizePixel = 0,
		Parent = frame,
	}, { UI.make("UICorner", { CornerRadius = round }), step })
	local label = UI.text({
		Name = "Label",
		Position = UDim2.fromOffset(6, 1),
		Size = UDim2.new(1, -12, 1, -2),
		Text = "",
		MaxSize = options.textSize,
		ZIndex = 2,
		Parent = frame,
	})
	local bar = { frame = frame, label = label }
	local shown = -1
	function bar.set(value: number, text: string?)
		value = math.clamp(value, 0, 1)
		if text then
			label.Text = text
		end
		if math.abs(value - shown) < 0.002 then
			return
		end
		shown = value
		TweenService:Create(step, UI.Motion.glide, { Offset = Vector2.new(value - 0.5, 0) }):Play()
	end
	function bar.setColor(color: Color3)
		fill.BackgroundColor3 = color
	end
	return bar
end

-- A two-state switch. `button` is what a press lands on. set(on, text, look) moves the knob and recolours it.
function UI.toggle(options)
	local size: Vector2 = options.size
	local button = UI.make("TextButton", {
		Position = options.position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = options.parent,
	})
	local sticker = UI.sticker(button, UI.Variants.disabled, { radius = size.Y, lip = 4, outline = 4, gloss = false })
	local knobSize = size.Y - 16
	local knobOutline = UI.stroke(3)
	knobOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local knob = UI.make("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 6 + knobSize / 2, 0.5, 0),
		Size = UDim2.fromOffset(knobSize, knobSize),
		BackgroundColor3 = UI.Colors.white,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = sticker.face,
	}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), knobOutline })
	local label = UI.text({ Size = UDim2.new(1, -knobSize - 22, 1, -10), Text = "", MaxSize = options.textSize, Parent = sticker.face })

	local toggle = { button = button }
	local shownOn: boolean? = nil
	function toggle.set(on: boolean, text: string, look: Look)
		if on == shownOn and label.Text == text then
			return
		end
		shownOn = on
		sticker.set(look)
		label.Text = text
		-- The word sits on the side the knob is not.
		label.Position = UDim2.fromOffset(if on then 12 else knobSize + 12, 5)
		local x = if on then size.X - 6 - knobSize / 2 else 6 + knobSize / 2
		TweenService:Create(knob, UI.Motion.release, { Position = UDim2.new(0, x, 0.5, 0) }):Play()
	end
	return toggle
end

-- A red "!" that sits on the top-right corner of whatever it is parented to. Hidden until told otherwise.
function UI.badge(parent: Instance): Frame
	local outline = UI.stroke(3)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return UI.make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = UI.Colors.red,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	}, {
		UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		outline,
		UI.text({ Position = UDim2.fromScale(0.15, 0.1), Size = UDim2.fromScale(0.7, 0.8), Text = "!" }),
	})
end

-- A 3D picture of a part or model: a ViewportFrame with a camera of its own.
-- Returns { frame, show(subject, direction?) }: show puts the subject in the picture in place of the last one
-- and frames it. `direction` points from the subject to the camera; the default looks at its front (-Z)
-- from a little to one side and above.
function UI.preview(props)
	props.BackgroundTransparency = 1
	props.Ambient = Color3.fromRGB(200, 200, 210)
	props.LightColor = Color3.new(1, 1, 1)
	props.LightDirection = Vector3.new(0.4, -1, 0.7)
	local viewport: ViewportFrame = UI.make("ViewportFrame", props)
	local view = UI.make("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = view
	local shown: Instance? = nil
	local preview = { frame = viewport }
	function preview.show(subject: PVInstance?, direction: Vector3?)
		if shown then
			shown:Destroy()
		end
		shown = subject
		if not subject then
			return
		end
		subject.Parent = viewport
		local cframe: CFrame, size: Vector3
		if subject:IsA("Model") then
			cframe, size = subject:GetBoundingBox()
		else
			cframe, size = (subject :: BasePart).CFrame, (subject :: BasePart).Size
		end
		local from = (direction or Vector3.new(-0.5, 0.35, -1)).Unit
		-- Framed on its longest side: tight enough that it fills the picture, loose enough that a turn fits.
		local distance = math.max(size.X, size.Y, size.Z) * 0.66 / math.tan(math.rad(15))
		view.CFrame = CFrame.lookAt(cframe.Position + from * distance, cframe.Position)
	end
	return preview
end

-- A cream note with an ink outline, for small facts (per click, heal rate, hints).
function UI.chip(props, children: { Instance }?): Frame
	props.BackgroundColor3 = UI.Colors.cream
	props.BorderSizePixel = 0
	local outline = UI.stroke(3)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local chip = UI.make("Frame", props, children)
	UI.corner(14).Parent = chip
	outline.Parent = chip
	return chip
end

return UI
