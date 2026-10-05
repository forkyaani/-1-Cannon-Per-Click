-- The battlefield as this client draws it: the monsters walking every plot in view, and the towers' shots.
--
-- The server runs the fight. Five times a second it sends each plot's living monsters as plain numbers on the
-- Field remote: id, distance along the path, share of HP left, flags (docs/DEFENSE_SPEC.md 5). Everything on
-- screen is made here from those numbers:
--   * Monsters. Between two messages a monster keeps walking at its own speed, so it glides instead of
--     stepping; a message only nudges it towards where the server has it. It turns through corners, hops as it
--     walks, shows an HP bar once it is hurt, takes a tint while slowed or burning, pops when it dies and is
--     simply gone when it reaches the gate.
--   * Tower shots. They are not sent at all: every tower the server built (workspace.Plots) turns to the
--     monster furthest along the path inside its range and fires at its own rate, here, for show.
-- Models, bars, shots and effects come from pools, and only so much is drawn: the limits are right below.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Layout = require(Shared:WaitForChild("Layout"))
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Colors = UI.Colors

local Field = {}

----------------------------------------------------------------------------------------------------
-- Limits. A monster past a cap is still tracked (towers aim at it, it still counts), it just has no model.
----------------------------------------------------------------------------------------------------
local OWN_CAP = 40 -- monster models on the player's own plot
local OTHER_CAP = 14 -- and on each other plot that is drawn
local OTHER_PLOTS = 3 -- how many other plots are drawn at all: the nearest ones
local DRAW_DISTANCE = 340 -- studs from the camera to a plot's middle; past it nothing of the plot is drawn
local BAR_CAP = 24 -- HP bars
local HP_NUMBERS = 6 -- of the ordinary monsters' bars, how many wear their health as a number: the hurt ones furthest along
local NUMBER_CAP = 14 -- floating damage and coin numbers
local POOL_KEEP = 24 -- spare models kept per kind of monster
local PART_CAPS = { shot = 36, shard = 10, puff = 22, ring = 5, beam = 16 } -- effect parts, per style
local SPARE_SHOTS = 10 -- of the shots, how many only the player's own towers may use
local MIN_SHOT_GAP = 0.09 -- a tower is never drawn firing faster than this, whatever its rate

local STALE_SECONDS = 1.5 -- a plot the server has stopped sending (the player walked off) is cleared after this
local SLOW_TICK = 0.5 -- how often the draw budget and the towers are looked at again

-- How a monster moves between two messages.
local MAX_AHEAD = 0.6 -- seconds it keeps walking with no news; after that it waits
local CATCH_UP = 5 -- share of the gap to the server's position that is closed per second
local SNAP_STUDS = 16 -- a gap this wide is not walked off: the monster jumps
local TURN_RATE = 9 -- how fast it turns into a corner
local HOP_PER_STUD = 0.8 -- hops are tied to the distance walked, so a monster that waits stands still
local LANE_SPREAD = 0.3 -- share of the path's width monsters spread over, so a crowd is not one line
local CENTER_HEIGHT = 1.4 -- a monster's middle above the ground, per unit of its scale: where shots land
local DEFAULT_SPEED = 6 -- studs per second, when the level's plan does not say

local SLOWED_GUESS = 0.6 -- share of its speed a slowed monster is taken to walk at, until it has been measured
local SPEED_WINDOW = 0.45 -- seconds a speed is measured over: long enough that a late message barely shows
local QUIET_ABOVE = 3 -- more monsters than this vanishing as the level changes is a reset, not a massacre

local SLOWED, BURNING, BOSS = 1, 2, 4 -- the flags of a monster, added together
local ICE = Color3.fromRGB(150, 220, 255)
local FIRE = Color3.fromRGB(255, 120, 40)
local WHITE = Color3.new(1, 1, 1)

local DEFENSE = Config.Defense or {}
local SYNC_SECONDS = 1 / (DEFENSE.syncHz or 5)

-- A number the server publishes about the owner of a plot, as an attribute of that player (every client
-- sees them): what their towers and monsters really do, so the show matches the fight.
local function ownerNumber(slot: number, name: string): number
	for _, owner in Players:GetPlayers() do
		if owner:GetAttribute("Slot") == slot then
			local value = owner:GetAttribute(name)
			return if typeof(value) == "number" and value == value and value > 0 then value else 1
		end
	end
	return 1
end

-- The game speed (1 to 3) the owner of a plot has picked: their monsters walk, and their towers shoot, that
-- many times as fast.
local function gameSpeed(slot: number): number
	return ownerNumber(slot, "GameSpeed")
end

-- Whether the owner of a plot has paused it (the Paused attribute): nothing on it moves, so its towers hold
-- their fire here too.
local function paused(slot: number): boolean
	for _, owner in Players:GetPlayers() do
		if owner:GetAttribute("Slot") == slot then
			return owner:GetAttribute("Paused") == true
		end
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- The path, unrolled once from Layout.PATH: a monster remembers which leg it is on, so placing it is no search.
----------------------------------------------------------------------------------------------------
local legs = {}
do
	local travelled = 0
	for index = 1, #Layout.PATH - 1 do
		local span = Layout.PATH[index + 1] - Layout.PATH[index]
		legs[index] = { from = Layout.PATH[index], direction = span.Unit, start = travelled, finish = travelled + span.Magnitude }
		travelled += span.Magnitude
	end
end
local PATH_LENGTH = legs[#legs].finish

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------
-- A plot the server is sending: [slot] = { slot, origin, level, plan, def, lives, monsters = { [id] = monster },
-- list = { monster } in the server's order, drawn, cap, mine, towers = { [model] = tower }, ... }.
local plots = {}
local folder: Folder -- everything this module puts in the world
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------------------------------------------
-- Effect parts: shots, hit puffs, splash rings and beams. Every one is a pooled part that is only ever moved,
-- resized, recoloured and made see-through again.
----------------------------------------------------------------------------------------------------
local function effectPart(props): Part
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	props.Material = Enum.Material.Neon
	props.Transparency = 1
	props.Parent = folder
	return UI.make("Part", props)
end

local STYLES = {
	shot = function(): Part
		return effectPart({ Name = "Shot", Shape = Enum.PartType.Ball, Size = Vector3.one })
	end,
	shard = function(): Part
		return effectPart({ Name = "Shard", Size = Vector3.new(0.45, 0.45, 2.4) })
	end,
	puff = function(): Part
		return effectPart({ Name = "Puff", Shape = Enum.PartType.Ball, Size = Vector3.one })
	end,
	ring = function(): Part
		return effectPart({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1, 1) })
	end,
	beam = function(): Part
		return effectPart({ Name = "Beam", Size = Vector3.one })
	end,
}
local idle = { shot = {}, shard = {}, puff = {}, ring = {}, beam = {} }
local made = { shot = 0, shard = 0, puff = 0, ring = 0, beam = 0 }

-- A part of that style, or nil when every one of them is in use: the effect is then just not drawn.
local function take(style: string): Part?
	local part = table.remove(idle[style])
	if not part and made[style] < PART_CAPS[style] then
		made[style] += 1
		part = STYLES[style]()
	end
	return part
end

local function give(style: string, part: Part)
	part.Transparency = 1
	table.insert(idle[style], part)
end

-- Effects that grow and fade by themselves: { part, style, age, seconds, small, big, solid }.
local fading = {}

local function fade(style: string, part: Part, seconds: number, small: Vector3, big: Vector3, solid: number)
	part.Size = small
	part.Transparency = solid
	table.insert(fading, { part = part, style = style, age = 0, seconds = seconds, small = small, big = big, solid = solid })
end

local function puff(at: Vector3, color: Color3, from: number, to: number, seconds: number)
	local part = take("puff")
	if part then
		part.Position = at
		part.Color = color
		fade("puff", part, seconds, Vector3.one * from, Vector3.one * to, 0.25)
	end
end

-- A flat ring on the ground that spreads to `radius`: where a splash reaches.
local function ring(at: Vector3, color: Color3, radius: number)
	local part = take("ring")
	if part then
		-- A cylinder lies along its X axis: stood on end it is a disc.
		part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
		part.Color = color
		fade("ring", part, 0.3, Vector3.new(0.3, 2, 2), Vector3.new(0.3, radius * 2, radius * 2), 0.45)
	end
end

local function beam(from: Vector3, to: Vector3, color: Color3, width: number, seconds: number)
	local length = (to - from).Magnitude
	local part = if length > 0.1 then take("beam") else nil
	if part then
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
		part.Color = color
		local size = Vector3.new(width, width, length)
		fade("beam", part, seconds, size, size, 0.1)
	end
end

local function stepFading(dt: number)
	for index = #fading, 1, -1 do
		local effect = fading[index]
		effect.age += dt
		local progress = effect.age / effect.seconds
		if progress >= 1 then
			give(effect.style, effect.part)
			fading[index] = fading[#fading]
			fading[#fading] = nil
		else
			if effect.small ~= effect.big then
				effect.part.Size = effect.small:Lerp(effect.big, progress)
			end
			effect.part.Transparency = effect.solid + (1 - effect.solid) * progress
		end
	end
end

-- Sparks for a monster that pops. Particles stay where they were let go, so one emitter serves every pop.
local sparkAnchor: Part
local sparks: ParticleEmitter

local function spark(at: Vector3, color: Color3, count: number)
	if not sparks then
		sparkAnchor = effectPart({ Name = "Sparks", Size = Vector3.one })
		sparks = UI.make("ParticleEmitter", {
			Rate = 0,
			Lifetime = NumberRange.new(0.25, 0.5),
			Speed = NumberRange.new(8, 16),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 0.6,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
			Parent = sparkAnchor,
		})
	end
	sparkAnchor.Position = at
	sparks.Color = ColorSequence.new(color)
	sparks:Emit(count)
end

----------------------------------------------------------------------------------------------------
-- Floating numbers: damage and coins over the player's own plot. Labels on the HUD, placed once from the
-- monster's spot on screen, so they cost nothing in the world.
----------------------------------------------------------------------------------------------------
local NUMBER_SECONDS = 0.6
local NUMBER_DISTANCE = 150 -- studs from the camera past which a number is not worth showing
local idleNumbers = {}
local numbersMade = 0
local floating = {} -- { label, age, x, y }

local function number(at: Vector3, text: string, color: Color3, lift: number)
	local point, onScreen = camera:WorldToViewportPoint(at)
	if not onScreen or point.Z > NUMBER_DISTANCE then
		return
	end
	local label: TextLabel? = table.remove(idleNumbers)
	if not label and numbersMade < NUMBER_CAP then
		numbersMade += 1
		label = UI.make("TextLabel", {
			Name = "FieldNumber",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = UI.FONT,
			TextScaled = true,
			TextStrokeColor3 = Colors.ink,
			Visible = false,
			ZIndex = 5,
			Parent = UI.gui,
		})
	end
	if not label then
		return
	end
	local s = UI.scale()
	label.Size = UDim2.fromOffset(170 * s, 32 * s)
	label.Text = text
	label.TextColor3 = color
	label.Visible = true
	table.insert(floating, { label = label, age = 0, x = point.X + math.random(-22, 22) * s, y = point.Y - lift * s })
end

local function stepNumbers(dt: number)
	local rise = 54 * UI.scale()
	for index = #floating, 1, -1 do
		local entry = floating[index]
		entry.age += dt
		local progress = entry.age / NUMBER_SECONDS
		local label: TextLabel = entry.label
		if progress >= 1 then
			label.Visible = false
			table.insert(idleNumbers, label)
			floating[index] = floating[#floating]
			floating[#floating] = nil
		else
			label.Position = UDim2.fromOffset(entry.x, entry.y - rise * progress)
			label.TextTransparency = progress * progress
			label.TextStrokeTransparency = progress * progress
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Monster models. Built by src/shared/Models.luau (Models.monster) once that module exists; a ball with eyes
-- stands in until then, and whenever a monster cannot be built. Either way: pivot on the ground, facing -Z.
----------------------------------------------------------------------------------------------------
-- What is remembered about a model: [model] = { key, body, top, paints = { { part, color } } }.
local infoOf = {}
local spare = {} -- [monster key] = { models nobody is using }
local PARKED = CFrame.new(0, 4000, 0) -- where a spare model waits: moving it is cheaper than reparenting it

local function placeholder(def): Model
	local scale = def.scale or 1.5
	local model = Instance.new("Model")
	model.Name = "Monster"
	local body = UI.make("Part", {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.2 * scale,
		Position = Vector3.new(0, 1.1 * scale, 0),
		Color = def.color or Colors.green,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	body.PivotOffset = CFrame.new(0, -1.1 * scale, 0)
	for _, side in { -1, 1 } do
		UI.make("Part", {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.5 * scale,
			Position = Vector3.new(side * 0.42, 1.35, -0.95) * scale,
			Color = WHITE,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	model.PrimaryPart = body
	model.Parent = folder
	return model
end

local function monsterKey(def): string
	return def.key or `{def.name}:{def.kind}:{def.scale}`
end

local function build(def): Model
	local model: Model? = nil
	local module = Shared:FindFirstChild("Models")
	if module then
		local ok, result = pcall(function()
			return require(module).monster(def, folder)
		end)
		if ok and typeof(result) == "Instance" and result:IsA("Model") and result.PrimaryPart then
			model = result
		end
	end
	local built: Model = model or placeholder(def)
	local body = built.PrimaryPart :: BasePart
	local paints = {}
	for _, part in built:GetDescendants() do
		if part:IsA("BasePart") then
			-- Moved by this client only: nothing may push it, stand on it or be hit by a ray through it.
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = part == body
			-- Eyes keep their colours under a tint, so a frozen monster still has a face.
			if part.Name ~= "Eye" and part.Name ~= "Pupil" then
				table.insert(paints, { part = part, color = part.Color })
			end
		end
	end
	infoOf[built] = { key = monsterKey(def), body = body, top = built:GetExtentsSize().Y, paints = paints }
	return built
end

----------------------------------------------------------------------------------------------------
-- HP bars: a billboard over a monster, sized in studs so it shrinks with distance. One is only taken once the
-- monster is hurt. A boss has its name on it and shows it from the start.
-- The bar also says the health in numbers. The server sends a share of the monster's max health and the max
-- is the level's own (Config.levelPlan(level).hp: nothing in the game changes one monster's max), so the
-- number is share x max, abbreviated. A boss reads "1.2K / 3.4K" in big figures. An ordinary monster only
-- has room for what it has left ("1.2K"), and in a crowd only the HP_NUMBERS hurt ones furthest along wear
-- it: twenty numbers over twenty monsters would be a wall of text.
----------------------------------------------------------------------------------------------------
-- The bar itself, in studs, and the billboard around it (the number stands over the bar, a boss's name over that).
local BAR = { width = 3.2, height = 0.42, lift = 0.7 } -- lift: the bar's middle above the monster's head
local BOSS_BAR = { width = 9, height = 0.9, lift = 1.05 }
local BAR_GUI = Vector2.new(4.6, 1.6) -- an ordinary monster's: wide enough for "123.4Qa"
local BOSS_GUI = Vector2.new(13, 4.2) -- a boss's: its name, its health in numbers, its bar
local idleBars = {}
local barsMade = 0

local function round(): UICorner
	return UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) })
end

local function newBar()
	local fill = UI.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.green, BorderSizePixel = 0 }, { round() })
	local track = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.ink,
		BorderSizePixel = 0,
	}, {
		round(),
		UI.make("Frame", { Position = UDim2.fromScale(0.03, 0.16), Size = UDim2.fromScale(0.94, 0.68), BackgroundTransparency = 1 }, { fill }),
	})
	local title = UI.make("TextLabel", {
		Size = UDim2.fromScale(1, 0.56),
		BackgroundTransparency = 1,
		Font = UI.TITLE_FONT,
		TextScaled = true,
		TextColor3 = Colors.white,
		TextStrokeColor3 = Colors.ink,
		TextStrokeTransparency = 0,
		Visible = false,
	})
	-- The health in numbers: white with a dark outline, so it reads over any world's ground.
	local amount = UI.make("TextLabel", {
		Name = "Amount",
		BackgroundTransparency = 1,
		Font = UI.FONT,
		TextScaled = true,
		TextColor3 = Colors.white,
		TextStrokeColor3 = Colors.ink,
		TextStrokeTransparency = 0,
		Text = "",
		Visible = false,
	})
	local gui = UI.make("BillboardGui", {
		Name = "MonsterBar",
		LightInfluence = 0,
		MaxDistance = 170,
		Enabled = false,
		ResetOnSpawn = false,
		Parent = playerGui,
	}, { track, title, amount })
	return { gui = gui, fill = fill, track = track, title = title, amount = amount, text = "" }
end

-- A monster's health in numbers: what it has left out of the level's max, or "" when the max is not known.
local function healthText(plot, monster): string
	local max = plot.plan and plot.plan.hp
	if typeof(max) ~= "number" or max ~= max or max <= 0 then
		return ""
	end
	local left = Format.abbreviate(math.max(1, math.clamp(monster.hp, 0, 1) * max))
	return if monster.boss then `{left} / {Format.abbreviate(max)}` else left
end

local function dropBar(monster)
	local bar = monster.bar
	if bar then
		monster.bar = nil
		bar.gui.Enabled = false
		bar.gui.Adornee = nil
		table.insert(idleBars, bar)
	end
end

local function showHealth(plot, monster)
	if not monster.model or (monster.hp >= 0.999 and not monster.boss) then
		return
	end
	local bar = monster.bar
	if not bar then
		bar = table.remove(idleBars)
		if not bar and barsMade < BAR_CAP then
			barsMade += 1
			bar = newBar()
		end
		if not bar then
			return
		end
		monster.bar = bar
		local boss = monster.boss
		local shape = if boss then BOSS_BAR else BAR
		local size = if boss then BOSS_GUI else BAR_GUI
		bar.gui.Size = UDim2.fromScale(size.X, size.Y)
		-- The bar is the bottom of the billboard: it stays where it always was, the rest stands over it.
		bar.gui.StudsOffsetWorldSpace = Vector3.new(0, monster.info.top + shape.lift - shape.height / 2 + size.Y / 2, 0)
		bar.gui.Adornee = monster.info.body
		local barShare = shape.height / size.Y
		bar.track.Size = UDim2.fromScale(shape.width / size.X, barShare)
		bar.title.Visible = boss
		bar.title.Size = UDim2.fromScale(1, 0.3)
		bar.title.Text = if boss then string.upper(plot.def.name or "BOSS") else ""
		-- A boss's number is 1.5 studs tall under its name; an ordinary monster's about one stud, over its bar.
		bar.amount.Position = UDim2.fromScale(0, if boss then 0.33 else 0)
		bar.amount.Size = UDim2.fromScale(1, if boss then 0.36 else 1 - barShare - 0.06)
		-- A boss always wears its number. An ordinary monster is given one by `numberBars`, a few at a time.
		bar.amount.Visible = boss
		bar.text = ""
		bar.amount.Text = ""
		bar.gui.Enabled = true
	end
	local text = healthText(plot, monster)
	if text ~= bar.text then
		bar.text = text
		bar.amount.Text = text
	end
	local share = math.clamp(monster.hp, 0, 1)
	bar.fill.Size = UDim2.fromScale(share, 1)
	bar.fill.BackgroundColor3 = if share > 0.5 then Colors.green elseif share > 0.25 then Colors.gold else Colors.red
end

-- Which ordinary monsters wear their health as a number: of the ones with a bar, the HP_NUMBERS furthest along
-- (the ones about to reach the gate, which is where the player looks). list is the plot's, in the server's
-- order. Run when a field message has been taken in.
local function numberBars(list)
	local hurt = {}
	for _, monster in list do
		if monster.bar and not monster.boss then
			table.insert(hurt, monster)
		end
	end
	if #hurt > HP_NUMBERS then
		table.sort(hurt, function(a, b)
			return a.d > b.d
		end)
	end
	for index, monster in hurt do
		monster.bar.amount.Visible = index <= HP_NUMBERS
	end
end

-- Slowed is an icy blue, burning an orange; both at once is a mix. Only written when the flags change.
local function paint(monster)
	local tint = monster.flags % (SLOWED + BURNING + 1)
	if tint == monster.tint or not monster.model then
		return
	end
	monster.tint = tint
	for _, entry in monster.info.paints do
		local color: Color3 = entry.color
		if tint % (SLOWED * 2) >= SLOWED then
			color = color:Lerp(ICE, 0.55)
		end
		if tint >= BURNING then
			color = color:Lerp(FIRE, 0.5)
		end
		entry.part.Color = color
	end
end

----------------------------------------------------------------------------------------------------
-- Moving a monster. Every frame it walks on at its own speed (so it glides between messages, and still does
-- when a message is lost), and closes a share of whatever gap there is to where the server last had it.
-- It never walks backwards for a small gap; it waits instead.
----------------------------------------------------------------------------------------------------
local function walk(plot, monster, dt: number, now: number)
	local ahead = now - monster.at
	local shown = monster.shown
	-- On a paused plot nothing walks on between two messages: the monsters stand where the server has them.
	local speed = if plot.paused then 0 else monster.speed
	if ahead < MAX_AHEAD then
		shown += speed * dt
	end
	local gap = monster.d + speed * math.min(ahead, MAX_AHEAD) - shown
	if math.abs(gap) > SNAP_STUDS then
		shown += gap
	else
		shown = math.max(monster.shown, shown + gap * math.min(1, dt * CATCH_UP))
	end
	shown = math.clamp(shown, 0, PATH_LENGTH)
	monster.shown = shown

	local leg = monster.leg
	while leg < #legs and shown > legs[leg].finish do
		leg += 1
	end
	while leg > 1 and shown < legs[leg].start do
		leg -= 1
	end
	monster.leg = leg
	local route = legs[leg]
	local point: Vector2 = route.from + route.direction * (shown - route.start)
	monster.point = point -- on the path's middle line: what a tower's range is measured to, as on the server

	local model: Model? = monster.model
	if not model then
		return
	end
	-- It turns into a corner instead of flipping, and its place across the path swings round with it.
	local direction: Vector2 = monster.direction:Lerp(route.direction, math.min(1, dt * TURN_RATE))
	if direction:Dot(direction) < 0.01 then
		direction = route.direction
	end
	monster.direction = direction
	local hop = math.abs(math.sin(shown * HOP_PER_STUD + monster.id)) * monster.hop
	local ground = plot.origin * Vector3.new(point.X - direction.Y * monster.side, 0, point.Y + direction.X * monster.side)
	monster.ground = ground
	local facing = plot.origin:VectorToWorldSpace(Vector3.new(direction.X, 0, direction.Y))
	local feet = ground + Vector3.new(0, hop, 0)
	model:PivotTo(CFrame.lookAt(feet, feet + facing))
end

-- Where a shot at this monster lands, whether or not it has a model.
local function aimAt(plot, monster): Vector3
	local up = Vector3.new(0, monster.height, 0)
	if monster.model and monster.ground then
		return monster.ground + up
	end
	return plot.origin * Vector3.new(monster.point.X, 0, monster.point.Y) + up
end

local function attach(plot, monster, now: number)
	local def = plot.def
	local pool = spare[monsterKey(def)]
	local model: Model = (pool and table.remove(pool)) or build(def)
	monster.model = model
	monster.info = infoOf[model]
	monster.tint = 0
	plot.drawn += 1
	walk(plot, monster, 0, now)
	paint(monster)
	showHealth(plot, monster)
end

local function detach(plot, monster)
	local model: Model? = monster.model
	if not model then
		return
	end
	dropBar(monster)
	if monster.tint ~= 0 then
		for _, entry in monster.info.paints do
			entry.part.Color = entry.color
		end
	end
	monster.model = nil
	monster.ground = nil
	plot.drawn -= 1
	local key = monster.info.key
	local pool = spare[key]
	if not pool then
		pool = {}
		spare[key] = pool
	end
	if #pool < POOL_KEEP then
		model:PivotTo(PARKED)
		table.insert(pool, model)
	else
		infoOf[model] = nil
		model:Destroy()
	end
end

----------------------------------------------------------------------------------------------------
-- Coins over a kill. The server does not say what a kill paid; the player's coins going up does. Kills on the
-- player's own plot and coin gains are matched up when they arrive close together, whichever comes first.
----------------------------------------------------------------------------------------------------
local MATCH_SECONDS = 0.8
local COIN_NUMBERS = 3 -- at most this many "+coins" for one gain
local fallen = {} -- kills waiting for their coins: { at = Vector3, time }
local banked = { amount = 0, time = -math.huge } -- coins that came before the news of the kill
local lastCoins: number? = nil

local function payOut(amount: number, now: number)
	for index = #fallen, 1, -1 do
		if now - fallen[index].time > MATCH_SECONDS then
			table.remove(fallen, index)
		end
	end
	if #fallen == 0 then
		banked.amount = (if now - banked.time < MATCH_SECONDS then banked.amount else 0) + amount
		banked.time = now
		return
	end
	local shown = math.min(#fallen, COIN_NUMBERS)
	for index = 1, shown do
		number(fallen[index].at, `+{Format.abbreviate(math.max(1, amount / shown))} ★`, Colors.gold, 46)
	end
	table.clear(fallen)
end

local function killed(at: Vector3, now: number)
	if #fallen >= COIN_NUMBERS * 2 then
		table.remove(fallen, 1)
	end
	table.insert(fallen, { at = at, time = now })
	if now - banked.time < MATCH_SECONDS and banked.amount > 0 then
		local amount = banked.amount
		banked.amount = 0
		payOut(amount, now)
	end
end

----------------------------------------------------------------------------------------------------
-- Plots
----------------------------------------------------------------------------------------------------
-- What a level's monsters are: Config.levelPlan is the server core's (its speed seeds a monster's walk and its
-- hp turns a share into a damage number). Config.monsterFor still says what they look like without it.
local function planFor(level: number)
	local plan = nil
	if Config.levelPlan then
		local ok, result = pcall(Config.levelPlan, level)
		plan = if ok and typeof(result) == "table" then result else nil
	end
	return plan, (plan and plan.monster) or Config.monsterFor(level)
end

local function remove(plot, monster, pop: boolean, now: number)
	monster.gone = true
	if monster.model then
		if pop then
			local scale = plot.def.scale or 1.5
			local at = aimAt(plot, monster)
			local color = plot.def.color or Colors.green
			puff(at, color, 1.6 * scale, 3.6 * scale, 0.28)
			spark(at, color, if monster.boss then 30 else 8)
			if plot.mine then
				killed(at, now)
			end
		end
		detach(plot, monster)
	end
end

-- Towers go back to how the server left them, so the next client-side record starts from the same rest.
local function forgetTower(tower)
	if tower.turret and tower.turret.Parent and tower.yaw ~= 0 then
		tower.turret:PivotTo(tower.rest)
	end
end

local function clear(plot)
	for _, monster in plot.list do
		monster.gone = true
		detach(plot, monster)
	end
	plot.list = {}
	plot.monsters = {}
	for model, tower in plot.towers do
		forgetTower(tower)
		plot.towers[model] = nil
	end
end

-- Who gets models: the player's own plot, and the few nearest of the others. Far from the camera (the
-- marketplace) nothing is drawn at all.
local function budget()
	local eye = camera.CFrame.Position
	local mine = State.get("Slot", nil)
	local others = {}
	for slot, plot in plots do
		local distance = (plot.origin * Vector3.new(0, 0, Layout.PLOT_DEPTH / 2) - eye).Magnitude
		plot.mine = slot == mine
		plot.cap = 0
		if distance <= DRAW_DISTANCE then
			if plot.mine then
				plot.cap = OWN_CAP
			else
				table.insert(others, { plot = plot, distance = distance })
			end
		end
	end
	table.sort(others, function(a, b)
		return a.distance < b.distance
	end)
	for index = 1, math.min(#others, OTHER_PLOTS) do
		others[index].plot.cap = OTHER_CAP
	end
end

-- Takes models away from a plot that has more than its budget, and hands them to monsters that have none.
local function dress(plot, now: number)
	local list = plot.list
	if plot.drawn > plot.cap then
		for index = #list, 1, -1 do
			if plot.drawn <= plot.cap then
				break
			end
			detach(plot, list[index])
		end
	elseif plot.drawn < math.min(plot.cap, #list) then
		for _, monster in list do
			if plot.drawn >= plot.cap then
				break
			end
			if not monster.model then
				attach(plot, monster, now)
			end
		end
	end
end

local function onField(slot: unknown, level: unknown, lives: unknown, _livesMax: unknown, flat: unknown)
	if typeof(slot) ~= "number" or typeof(level) ~= "number" or typeof(flat) ~= "table" then
		return
	end
	local plot = plots[slot]
	if level <= 0 or slot < 1 or slot > Layout.PLOT_COUNT then
		-- The plot's owner left.
		if plot then
			clear(plot)
			plots[slot] = nil
		end
		return
	end
	local now = os.clock()
	if not plot then
		plot = {
			slot = slot,
			origin = Layout.plotCFrame(slot),
			level = 0,
			lives = if typeof(lives) == "number" then lives else 0,
			monsters = {},
			list = {},
			drawn = 0,
			cap = 0,
			mine = false,
			stamp = 0,
			owed = 0,
			towers = {},
			towersAt = -math.huge,
		}
		plots[slot] = plot
		budget()
	end
	local switched = plot.level ~= level
	if switched then
		plot.level = level
		plot.plan, plot.def = planFor(level)
	end
	local lifeLost = switched or (typeof(lives) == "number" and lives < plot.lives)
	if typeof(lives) == "number" then
		plot.lives = lives
	end
	plot.heardAt = now
	plot.stamp += 1

	local plan = plot.plan
	local stamp = plot.stamp
	local monsters = plot.monsters
	local list = {}
	-- The hardest hit of this message gets a damage number (on the player's own plot).
	local hurt, hurtBy = nil, 0
	for index = 1, #flat - 3, 4 do
		local id, d, hp, flags = flat[index], flat[index + 1], flat[index + 2], flat[index + 3]
		if typeof(id) ~= "number" or typeof(d) ~= "number" or typeof(hp) ~= "number" or typeof(flags) ~= "number" then
			continue
		end
		local monster = monsters[id]
		if monster then
			-- An unreliable message can arrive late: one that would walk the monster backwards is old news.
			if d >= monster.d then
				local slowed = flags % (SLOWED * 2) >= SLOWED
				local base = monster.base
				if slowed ~= monster.slowed then
					monster.slowed = slowed
					monster.speed = if slowed then base * SLOWED_GUESS else base
					monster.markD, monster.markAt = d, now
				elseif now - monster.markAt >= SPEED_WINDOW then
					-- At full speed it walks the level's speed. How much a slow takes off depends on the tower
					-- that gave it, which is not sent, so a slowed monster's speed is measured instead.
					if slowed or not plan then
						local measured = math.clamp((d - monster.markD) / (now - monster.markAt), base * 0.15, base * 1.5)
						monster.speed += (measured - monster.speed) * 0.5
					end
					monster.markD, monster.markAt = d, now
				end
				monster.d, monster.at = d, now
			end
			if monster.hp - hp > hurtBy then
				hurt, hurtBy = monster, monster.hp - hp
			end
			local changed = hp ~= monster.hp
			monster.hp, monster.flags = hp, flags
			paint(monster)
			if changed then
				showHealth(plot, monster)
			end
		else
			local boss = flags % (BOSS * 2) >= BOSS
			local scale = plot.def.scale or 1.5
			local base = ((plan and plan.speed) or DEFAULT_SPEED) * gameSpeed(slot)
			local slowed = flags % (SLOWED * 2) >= SLOWED
			monster = {
				id = id,
				d = d,
				at = now,
				base = base,
				slowed = slowed,
				speed = if slowed then base * SLOWED_GUESS else base,
				markD = d,
				markAt = now,
				shown = d,
				leg = 1,
				direction = legs[1].direction,
				point = Layout.PATH[1],
				-- A place of its own across the path, the same every time it is seen. A boss walks the middle.
				side = if boss then 0 else ((id * 0.618) % 1 - 0.5) * Layout.PATH_WIDTH * LANE_SPREAD,
				hop = 0.1 + 0.16 * scale,
				height = CENTER_HEIGHT * scale,
				hp = hp,
				flags = flags,
				boss = boss,
				tint = 0,
				gone = false,
			}
			monsters[id] = monster
			walk(plot, monster, 0, now)
			-- Already on a later leg when first seen (the player just walked up): it faces the way it walks.
			monster.direction = legs[monster.leg].direction
		end
		monster.stamp = stamp
		table.insert(list, monster)
	end

	-- Whoever the server no longer lists is gone: through the gate if it was about to get there and a life was
	-- lost, dead otherwise.
	local missing = 0
	for _, monster in monsters do
		if monster.stamp ~= stamp then
			missing += 1
		end
	end
	if missing > 0 then
		local quiet = switched and missing > QUIET_ABOVE
		for id, monster in monsters do
			if monster.stamp ~= stamp then
				monsters[id] = nil
				local reached = monster.d + monster.speed * math.min(now - monster.at, MAX_AHEAD)
				local atGate = reached >= PATH_LENGTH - (monster.speed * SYNC_SECONDS * 1.5 + 2)
				local died = not quiet and not (atGate and lifeLost)
				if died and plot.mine and plan and plan.hp and monster.model then
					number(aimAt(plot, monster), `-{Format.abbreviate(math.max(1, monster.hp * plan.hp))}`, Colors.white, 16)
				end
				remove(plot, monster, died, now)
			end
		end
	end
	plot.list = list
	dress(plot, now)
	numberBars(list)
	if hurt and plot.mine and plan and plan.hp and hurt.model then
		number(aimAt(plot, hurt), `-{Format.abbreviate(math.max(1, hurtBy * plan.hp))}`, Colors.white, 16)
	end
end

----------------------------------------------------------------------------------------------------
-- Towers. The server builds the models (workspace.Plots.Plot_<slot>.Towers.Tower_<pad>, with Pad, Kind and
-- Level attributes, a Muzzle part and a Turret). What they do each frame is played here.
-- A turret is turned about its own pivot. Which way its barrel points is read from where its Muzzle is, so
-- the builder is free to model it along any axis.
----------------------------------------------------------------------------------------------------
local AIM_RATE = 12
local CHAIN_REACH = 16 -- studs a chain shot jumps from one monster to the next

-- What a tower's shot looks like, from what it does.
local function lookOf(def): string
	return if def.chain
		then "bolt"
		elseif def.splash then "shell"
		elseif def.slow then "shard"
		elseif def.burn then "flame"
		elseif def.boss then "tracer"
		else "ball"
end

local function newTower(plot, model: Instance, pad: Vector2)
	local turret = model:FindFirstChild("Turret", true)
	local muzzle = model:FindFirstChild("Muzzle", true)
	local tower = { model = model, pad = pad, cooldown = 0, yaw = 0, restYaw = 0, target = nil }
	if turret and turret:IsA("PVInstance") then
		tower.turret = turret
		tower.rest = turret:GetPivot()
	end
	local origin: Vector3 = if tower.rest then tower.rest.Position else plot.origin * Vector3.new(pad.X, 3, pad.Y)
	local mouth: Vector3 = if muzzle and muzzle:IsA("BasePart") then muzzle.Position else origin + Vector3.new(0, 1, 0)
	tower.complete = tower.turret ~= nil and muzzle ~= nil
	tower.origin = origin
	tower.reach = mouth - origin -- from the turret's pivot to the muzzle, as built
	if math.abs(tower.reach.X) + math.abs(tower.reach.Z) > 0.3 then
		tower.restYaw = math.atan2(tower.reach.X, tower.reach.Z)
	elseif tower.rest then
		local look = tower.rest.LookVector
		tower.restYaw = math.atan2(look.X, look.Z)
	end
	return tower
end

local function scanTowers(plot)
	-- What the owner's bonuses do to every tower of the plot (mastery, enchants, powerups: the server's
	-- `towerRate` and `towerRange`), and the game speed they picked. Read here, twice a second.
	plot.towerRate = ownerNumber(plot.slot, "TowerRate") * gameSpeed(plot.slot)
	plot.towerRange = ownerNumber(plot.slot, "TowerRange")
	local plotFolder = plot.folder
	if not plotFolder or not plotFolder.Parent then
		local all = workspace:FindFirstChild("Plots")
		plotFolder = all and all:FindFirstChild("Plot_" .. plot.slot)
		plot.folder = plotFolder
	end
	local built = plotFolder and plotFolder:FindFirstChild("Towers")
	local kinds = Config.Towers
	local seen = {}
	if built and kinds then
		for _, model in built:GetChildren() do
			local def = kinds[model:GetAttribute("Kind")]
			local pad = Layout.PADS[model:GetAttribute("Pad")]
			if def and pad and def.rate and def.range then
				seen[model] = true
				local tower = plot.towers[model]
				if not tower or not tower.complete then
					-- A model can arrive before its parts: it is looked at again until its turret and muzzle are in.
					local cooldown = if tower then tower.cooldown else 0
					if tower then
						forgetTower(tower)
					end
					tower = newTower(plot, model, pad)
					tower.cooldown = cooldown
					plot.towers[model] = tower
				end
				tower.def = def
				tower.look = lookOf(def)
			end
		end
	end
	for model, tower in plot.towers do
		if not seen[model] then
			forgetTower(tower)
			plot.towers[model] = nil
		end
	end
end

-- The monster furthest along the path inside the tower's range: the one the server shoots too.
local function pick(plot, tower)
	local best, bestShown = nil, -1
	local range = tower.def.range * (plot.towerRange or 1)
	for _, monster in plot.list do
		if monster.shown > bestShown and (monster.point - tower.pad).Magnitude <= range then
			best, bestShown = monster, monster.shown
		end
	end
	return best
end

local function muzzleOf(tower): Vector3
	return tower.origin + CFrame.Angles(0, tower.yaw, 0) * tower.reach
end

local function aim(tower, at: Vector3, dt: number)
	local to = at - tower.origin
	local turn = (math.atan2(to.X, to.Z) - tower.restYaw - tower.yaw + math.pi) % (2 * math.pi) - math.pi
	if math.abs(turn) < 0.01 then
		return
	end
	tower.yaw += turn * math.min(1, dt * AIM_RATE)
	if tower.turret then
		tower.turret:PivotTo(CFrame.new(tower.origin) * CFrame.Angles(0, tower.yaw, 0) * tower.rest.Rotation)
	end
end

-- Shots in the air: { part, style, look, plot, target, from, to, age, seconds, arc, size, color, splash }.
local shots = {}

local function jitter(): number
	return (math.random() - 0.5) * 2.6
end

-- Lightning: two crooked pieces from one point to the next.
local function zap(from: Vector3, to: Vector3, color: Color3)
	local bend = (from + to) / 2 + Vector3.new(jitter(), jitter(), jitter())
	beam(from, bend, color, 0.4, 0.14)
	beam(bend, to, color, 0.4, 0.14)
end

local function fire(plot, tower, target)
	local def, look = tower.def, tower.look
	local color: Color3 = def.color or Colors.gold
	local from = muzzleOf(tower)
	local to = aimAt(plot, target)
	if look == "bolt" then
		-- Chain: lightning to the target, then on to the nearest monsters around it.
		local bright = color:Lerp(WHITE, 0.5)
		local struck = { [target] = true }
		local last, lastAt = target, to
		zap(from, to, bright)
		puff(to, bright, 1.2, 2.8, 0.16)
		for _ = 1, def.chain do
			local nearest, nearestAt = nil, CHAIN_REACH
			for _, other in plot.list do
				if not struck[other] then
					local distance = (other.point - last.point).Magnitude
					if distance < nearestAt then
						nearest, nearestAt = other, distance
					end
				end
			end
			if not nearest then
				break
			end
			struck[nearest] = true
			local at = aimAt(plot, nearest)
			zap(lastAt, at, bright)
			puff(at, bright, 1, 2.4, 0.16)
			last, lastAt = nearest, at
		end
		return
	elseif look == "tracer" then
		-- The boss hunter: no flight time, one thin bright line and a hard hit.
		beam(from, to, color:Lerp(WHITE, 0.7), 0.22, 0.12)
		puff(to, color, 1.4, 4, 0.2)
		return
	end
	-- Other plots leave the last few shots to the player's own towers.
	if not plot.mine and made.shot - #idle.shot >= PART_CAPS.shot - SPARE_SHOTS then
		return
	end
	local style = if look == "shard" then "shard" else "shot"
	local part = take(style)
	if not part then
		return
	end
	local size = if look == "shell" then 1.7 elseif look == "flame" then 1.1 else 0.9
	part.Color = color
	part.Transparency = 0
	if style == "shot" then
		part.Size = Vector3.one * size
		part.Position = from
	else
		part.CFrame = if (to - from).Magnitude > 0.1 then CFrame.lookAt(from, to) else CFrame.new(from)
	end
	table.insert(shots, {
		part = part,
		style = style,
		look = look,
		plot = plot,
		target = target,
		from = from,
		to = to,
		age = 0,
		-- A mortar shell is lobbed and takes its time; everything else is quick.
		seconds = if look == "shell" then 0.45 elseif look == "flame" then 0.2 else 0.13,
		arc = if look == "shell" then 5 + (to - from).Magnitude * 0.12 else 0,
		size = size,
		color = color,
		splash = def.splash,
	})
end

local function land(shot)
	local at: Vector3 = shot.to
	local look = shot.look
	if look == "shell" then
		local floor = shot.plot.origin.Position.Y + 0.25
		ring(Vector3.new(at.X, floor, at.Z), shot.color, shot.splash or 6)
		puff(at, FIRE, 2, 5, 0.22)
	elseif look == "shard" then
		puff(at, ICE, 1.2, 3.4, 0.3)
	elseif look == "flame" then
		puff(at, FIRE, 1.4, 3.6, 0.34)
	else
		puff(at, shot.color, 1, 2.2, 0.12)
	end
end

local function stepShots(dt: number)
	for index = #shots, 1, -1 do
		local shot = shots[index]
		shot.age += dt
		local progress = shot.age / shot.seconds
		local target = shot.target
		-- It homes in: the monster has walked on since the shot left.
		if not target.gone then
			shot.to = aimAt(shot.plot, target)
		end
		local part: Part = shot.part
		if progress >= 1 then
			land(shot)
			give(shot.style, part)
			shots[index] = shots[#shots]
			shots[#shots] = nil
		else
			local position = shot.from:Lerp(shot.to, progress)
			if shot.arc > 0 then
				position += Vector3.new(0, math.sin(progress * math.pi) * shot.arc, 0)
			end
			if shot.style == "shard" then
				-- A shard points the way it flies.
				part.CFrame = if (shot.to - position).Magnitude > 0.1 then CFrame.lookAt(position, shot.to) else CFrame.new(position)
			else
				part.Position = position
				if shot.look == "flame" then
					-- A fireball swells as it goes.
					part.Size = Vector3.one * shot.size * (0.6 + progress)
				end
			end
		end
	end
end

local function stepTowers(plot, dt: number)
	for model, tower in plot.towers do
		if not model.Parent then
			continue
		end
		tower.cooldown = math.max(0, tower.cooldown - dt)
		local target = tower.target
		local ready = tower.cooldown <= 0
		-- Like the server, it picks again for every shot; in between it keeps tracking the one it has.
		if ready or not target or target.gone or (target.point - tower.pad).Magnitude > tower.def.range * (plot.towerRange or 1) then
			target = pick(plot, tower)
			tower.target = target
		end
		if target then
			aim(tower, aimAt(plot, target), dt)
			if ready then
				tower.cooldown = math.max(1 / (tower.def.rate * (plot.towerRate or 1)), MIN_SHOT_GAP)
				fire(plot, tower, target)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Frame loop
----------------------------------------------------------------------------------------------------
local frame = 0
local sinceSlow = 0

-- Twice a second: plots nobody sends any more are cleared, the draw budget and the towers are looked at
-- again, and spare models of monsters that no plot has any more are thrown away.
local function slowTick(now: number)
	for slot, plot in plots do
		if now - plot.heardAt > STALE_SECONDS then
			clear(plot)
			plots[slot] = nil
		end
	end
	budget()
	local wanted = {}
	for _, plot in plots do
		plot.paused = paused(plot.slot)
		dress(plot, now)
		if plot.cap > 0 then
			scanTowers(plot)
		end
		wanted[monsterKey(plot.def)] = true
	end
	for key, pool in spare do
		if not wanted[key] then
			for _, model in pool do
				infoOf[model] = nil
				model:Destroy()
			end
			spare[key] = nil
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	frame += 1
	sinceSlow += dt
	if sinceSlow >= SLOW_TICK then
		sinceSlow = 0
		slowTick(now)
	end
	for _, plot in plots do
		-- Other players' plots move every second frame: half the work, and at their distance it does not show.
		plot.owed += dt
		if plot.mine or (frame + plot.slot) % 2 == 0 then
			local elapsed = plot.owed
			plot.owed = 0
			for _, monster in plot.list do
				walk(plot, monster, elapsed, now)
			end
			if plot.cap > 0 and not plot.paused then
				stepTowers(plot, elapsed)
			end
		end
	end
	stepShots(dt)
	stepFading(dt)
	stepNumbers(dt)
end

----------------------------------------------------------------------------------------------------
-- For the rest of the client
----------------------------------------------------------------------------------------------------
-- The model of the lead monster on a plot (the one furthest along the path that is drawn), or nil. Its
-- PrimaryPart is its body. slot defaults to the player's own plot. With `near` and `range`, only monsters that
-- close to that point count: what a mini cannon at its owner's side can reach.
function Field.lead(slot: number?, near: Vector3?, range: number?): Model?
	local plot = plots[slot or State.get("Slot", 0)]
	if not plot then
		return nil
	end
	local best, bestShown = nil, -1
	for _, monster in plot.list do
		if monster.model and monster.ground and monster.shown > bestShown then
			if not near or (monster.ground - near).Magnitude <= (range or math.huge) then
				best, bestShown = monster, monster.shown
			end
		end
	end
	return best and best.model
end

-- The health of the boss on a plot (the player's own by default), in numbers: what it has left and its max,
-- or nil when no boss is alive there or the level's max is not known. The level panel writes it on its boss line.
function Field.boss(slot: number?): (number?, number?)
	local plot = plots[slot or State.get("Slot", 0)]
	local max = plot and plot.plan and plot.plan.hp
	if not plot or typeof(max) ~= "number" or max ~= max or max <= 0 then
		return nil, nil
	end
	for _, monster in plot.list do
		if monster.boss then
			return math.max(1, math.clamp(monster.hp, 0, 1) * max), max
		end
	end
	return nil, nil
end

-- How many monsters are alive on a plot, drawn or not.
function Field.count(slot: number?): number
	local plot = plots[slot or State.get("Slot", 0)]
	return if plot then #plot.list else 0
end

-- For tests and tuning: every monster of a plot as this client has it, in the server's order.
-- d is where it is drawn along the path, server where the last message had it.
function Field.inspect(slot: number)
	local out = {}
	local plot = plots[slot]
	for _, monster in if plot then plot.list else {} do
		table.insert(out, {
			id = monster.id,
			d = monster.shown,
			server = monster.d,
			speed = monster.speed,
			hp = monster.hp,
			flags = monster.flags,
			model = monster.model,
			bar = monster.bar ~= nil,
			health = if monster.bar then monster.bar.amount.Text else nil, -- the number on its bar
			numbered = monster.bar ~= nil and monster.bar.amount.Visible, -- whether that number is showing
			tint = monster.tint,
			position = monster.ground,
		})
	end
	return out
end

-- For tests and tuning: how much is tracked and how much of it is on screen.
function Field.stats()
	local stats = { plots = 0, monsters = 0, models = 0, towers = 0, shots = #shots, effects = #fading, numbers = #floating, bars = barsMade - #idleBars }
	for _, plot in plots do
		stats.plots += 1
		stats.monsters += #plot.list
		stats.models += plot.drawn
		for _ in plot.towers do
			stats.towers += 1
		end
	end
	local pooled = 0
	for _, pool in spare do
		pooled += #pool
	end
	stats.spare = pooled
	return stats
end

function Field.start()
	folder = UI.make("Folder", { Name = "Field", Parent = workspace })
	-- The remote is made by the server core. The client must not hang on it: the rest of the HUD starts first.
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Field")
		remote.OnClientEvent:Connect(onField)
	end)
	State.onChange(function()
		local coins = State.get("Coins", 0)
		if lastCoins and coins > lastCoins then
			payOut(coins - lastCoins, os.clock())
		end
		lastCoins = coins
	end)
	RunService.RenderStepped:Connect(step)
end

return Field
