-- Everything visual in the 3D world that only this client needs to see, apart from the battlefield itself
-- (monsters and tower shots: src/client/Field.luau): mini cannons following their owner and firing, the Huge
-- Shot, the hatch reveal and the lighting. The camera and the controls are Roblox's own, everywhere.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Models = require(ReplicatedStorage.Shared.Models)
local Field = require(script.Parent.Field)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Colors = UI.Colors

local Effects = {}

local inMarket = false -- away from the plot: in the marketplace or on a world's island
local island = 0 -- which island the player is on (0 on none)
local visiting = 0 -- the slot of the base the player is a guest on (0 on none)

----------------------------------------------------------------------------------------------------
-- Camera
-- The player walks in third person on their plot and in the marketplace alike, with Roblox's own camera and
-- controls. The one thing done here: after a trip between the two, the camera is turned to look the way the
-- player arrives (up the plot, into the square, or at an island's eggs), because the normal camera keeps the
-- direction it had.
----------------------------------------------------------------------------------------------------
local function faceArrival()
	local slot = State.get("Slot", nil)
	local arrival = if island > 0
		then Layout.islandSpawn(island)
		elseif visiting > 0 then Layout.plotSpawn(visiting)
		elseif inMarket then Layout.marketSpawn()
		elseif slot then Layout.plotSpawn(slot)
		else nil
	if not arrival then
		return
	end
	local at, ahead = arrival.Position, arrival.LookVector
	camera.CFrame = CFrame.lookAt(at - ahead * 16 + Vector3.new(0, 7, 0), at + ahead * 8 + Vector3.new(0, 2, 0))
end

----------------------------------------------------------------------------------------------------
-- Lighting: local to this client. Each world has its own sky, on the plot (the world being fought) and on
-- that world's island; the marketplace has a bright afternoon of its own. A guest on somebody's base gets
-- the sky of the world that base is fighting in: the server says which (State.feature("visit").host.world).
-- A sky is the time of day, brightness and ambient colour (Config.Worlds[world].sky) and a look: the
-- atmosphere's haze and its colour at the horizon and high up, how many stars, and a tint over the picture.
-- The looks of the first five worlds use the sky colours of their Blender themes (tools/blender/themes.py);
-- a world without one gets a look from its backdrop colour. The Atmosphere, the Sky and the tint are made
-- here, in this client's Lighting; what the place file has there (bloom, colour grading) is left alone.
----------------------------------------------------------------------------------------------------
local MARKET_SKY = { clock = 13.5, brightness = 2.6, ambient = Color3.fromRGB(150, 150, 160) }
local HALLOWEEN_SKY = { clock = 15.6, brightness = 2.3, ambient = Color3.fromRGB(165, 140, 125) }

local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)
local LOOKS = {
	Earth = { density = 0.3, offset = 0.25, horizon = hex("C4E8FF"), top = hex("3F8FE0"), glare = 0.2, haze = 1.2 },
	Moon = { density = 0.3, offset = 0, horizon = hex("4D4296"), top = hex("17153F"), glare = 0, haze = 1.5, stars = 6000 },
	Mars = { density = 0.36, offset = 0.3, horizon = hex("FFD9A8"), top = hex("F0884E"), glare = 0.4, haze = 2.2, tint = hex("FFF0E0") },
	Neptune = { density = 0.34, offset = 0.2, horizon = hex("A8DCFF"), top = hex("3264C8"), glare = 0.2, haze = 1.8 },
	["The Sun"] = { density = 0.3, offset = 0.3, horizon = hex("FFE27A"), top = hex("FF7A1E"), glare = 0.8, haze = 2, tint = hex("FFF4E0") },
}
local MARKET_LOOK = { density = 0.28, offset = 0.25, horizon = hex("D6EEFF"), top = hex("4F9BEA"), glare = 0.2, haze = 1 }
local HALLOWEEN_LOOK = { density = 0.36, offset = 0.2, horizon = hex("FFB37A"), top = hex("5A3A8A"), glare = 0.3, haze = 2, tint = hex("FFEEDD") }

-- The look of a world that has none of its own: hazy in its backdrop colour, with stars when it is night there.
local function lookFor(world)
	local night = world.sky.clock < 5 or world.sky.clock > 19.5
	return LOOKS[world.name] or {
		density = 0.32, offset = 0.2, horizon = world.backdrop:Lerp(WHITE, 0.35), top = world.backdrop,
		glare = 0.2, haze = 1.6, stars = if night then 6000 else nil,
	}
end

-- This client's own instance of that class in Lighting, made the first time it is asked for.
local function lit(class: string, name: string): Instance
	local found = Lighting:FindFirstChild(name)
	if not found or not found:IsA(class) then
		found = Instance.new(class)
		found.Name = name
		found.Parent = Lighting
	end
	return found
end

-- The world of the base this player is a guest on, or nil while the server has not said (then: the marketplace's).
local function hostWorld(): number?
	local host = State.feature("visit").host
	local world = if typeof(host) == "table" then host.world else nil
	return if typeof(world) == "number" and Config.Worlds[world] then world else nil
end

local litKey = nil
local function updateLighting()
	local world
	if island > 0 then
		world = island
	elseif visiting > 0 then
		world = hostWorld()
	elseif not inMarket then
		world = Config.worldOf(State.get("Wave", 1))
	end
	local halloween = not world and Config.halloweenActive(State.now())
	local key = world or (if halloween then "halloween" else "market")
	UI.music(if island > 0 then "island" elseif inMarket then "market" else "base")
	if key == litKey then
		return
	end
	litKey = key
	local sky, look
	if world and Config.Worlds[world] then
		sky, look = Config.Worlds[world].sky, lookFor(Config.Worlds[world])
	elseif halloween then
		sky, look = HALLOWEEN_SKY, HALLOWEEN_LOOK
	else
		sky, look = MARKET_SKY, MARKET_LOOK
	end
	Lighting.ClockTime = sky.clock
	Lighting.Brightness = sky.brightness
	Lighting.Ambient = sky.ambient
	Lighting.OutdoorAmbient = sky.ambient
	local atmosphere = lit("Atmosphere", "WorldAtmosphere") :: Atmosphere
	atmosphere.Density = look.density
	atmosphere.Offset = look.offset
	atmosphere.Color = look.horizon
	atmosphere.Decay = look.top
	atmosphere.Glare = look.glare
	atmosphere.Haze = look.haze
	local stars = lit("Sky", "WorldSky") :: Sky
	stars.StarCount = look.stars or 3000
	local tint = lit("ColorCorrectionEffect", "WorldTint") :: ColorCorrectionEffect
	tint.TintColor = look.tint or WHITE
end

----------------------------------------------------------------------------------------------------
-- Targets: the monsters are Field's. Effects made for "the monster" go to the lead one on the player's plot.
----------------------------------------------------------------------------------------------------
local PET_RANGE = if Config.Defense then Config.Defense.petRange else 40 -- times the PetRange attribute (enchantments)

-- The lead monster on the player's own plot, if it is drawn.
local function targetModel(): Model?
	local slot = State.get("Slot", nil)
	return if slot then Field.lead(slot) else nil
end

-- The monster the player's mini cannons shoot: the lead one within their reach of the player.
local function petTarget(): Model?
	local slot = State.get("Slot", nil)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local reach = player:GetAttribute("PetRange")
	return if slot and root then Field.lead(slot, root.Position, PET_RANGE * (if typeof(reach) == "number" then reach else 1)) else nil
end

----------------------------------------------------------------------------------------------------
-- Shots
----------------------------------------------------------------------------------------------------
local function shoot(from: Vector3, to: Vector3, size: number, color: Color3)
	local ball = UI.make("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Position = from,
		Color = color,
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	})
	local tween = TweenService:Create(ball, TweenInfo.new(0.12, Enum.EasingStyle.Linear), { Position = to })
	tween.Completed:Connect(function()
		ball:Destroy()
	end)
	tween:Play()
end

-- Quick squash on the monster being hit, so every shot has a visible impact.
local pulsing = setmetatable({}, { __mode = "k" })
local function pulse(body: BasePart)
	if pulsing[body] then
		return
	end
	pulsing[body] = true
	local size = body.Size
	local tween = TweenService:Create(body, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Size = size * 1.18 })
	tween.Completed:Connect(function()
		body.Size = size
		pulsing[body] = nil
	end)
	tween:Play()
end

local function shootAt(model: Model?, from: Vector3, size: number, color: Color3)
	local body = model and model.PrimaryPart
	if not body then
		return
	end
	shoot(from, body.Position, size, color)
	task.delay(0.12, pulse, body)
end

-- Features can restyle the hero shot (an ammo type): set color and/or size, or nil for the default.
Effects.projectile = { color = nil :: Color3?, size = nil :: number? }

-- Features that react to a hero shot (a muzzle flash, a counter): fn() runs on every one.
local fireHooks = {}
function Effects.onFire(hook: () -> ())
	table.insert(fireHooks, hook)
end

-- The lead monster on the player's plot, if it is drawn. Its PrimaryPart is the body.
function Effects.target(): Model?
	return targetModel()
end

local petsOf -- defined with the mini cannons below

-- A hero shot, for show: the player's first mini cannon fires at the lead monster in its reach, in the look
-- features gave Effects.projectile. (There is no big cannon and no tap to fire any more; this is what the
-- features that drew the big cannon firing now draw.)
function Effects.fire()
	local pets = if inMarket then nil else petsOf(player)
	local first = pets and pets:FindFirstChildWhichIsA("Model")
	local barrel = first and first.PrimaryPart
	if barrel then
		shootAt(petTarget(), barrel.Position, Effects.projectile.size or 1.4, Effects.projectile.color or barrel.Color)
	end
	for _, hook in fireHooks do
		hook()
	end
end

----------------------------------------------------------------------------------------------------
-- Mini cannons
-- The server builds every player's mini cannons (each has a Home CFrame, where it waits while its owner has
-- no character). This client moves them: everyone's follow their owner, on the plots and in the marketplace.
----------------------------------------------------------------------------------------------------
-- A cylinder's long axis is its X axis; this points that axis along `direction` (same as the server's Build.along).
local function along(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
end

function petsOf(owner: Player): Model?
	local folder = workspace:FindFirstChild("Cannons")
	return folder and folder:FindFirstChild("Pets_" .. owner.UserId) :: Model?
end

local following = setmetatable({}, { __mode = "k" }) -- mini cannon model -> where it currently is while following

-- Where a Huge on a perch flies (owner's space, like Layout.miniFollow): at its owner's side, a stud off the
-- ground, the first on the left and the second on the right. It is far too big for a follow spot. The server
-- says which perch it has (the Perch attribute), and moves the other mini cannons out of the follow spots
-- beside it.
local HUGE_FOLLOW = { Vector3.new(-6.6, 1.2, 1.5), Vector3.new(6.6, 1.2, 1.5) }

-- A Huge Shot kicks its Huge back along its barrel, and it glides home.
local KICK_STUDS = 1.6
local KICK_SECONDS = 0.3
local kicked = setmetatable({}, { __mode = "k" }) -- mini cannon model -> the os.clock() of its last Huge Shot

local function updatePets(clock: number, dt: number)
	for _, owner in Players:GetPlayers() do
		local pets = petsOf(owner)
		if not pets then
			continue
		end
		local root = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
		for order, mini in pets:GetChildren() do
			local home = mini:GetAttribute("Home")
			if not mini:IsA("Model") or typeof(home) ~= "CFrame" then
				continue
			end
			local bob = Vector3.new(0, math.sin(clock * 2.2 + order * 1.7) * 0.3, 0)
			if root then
				local spot = HUGE_FOLLOW[mini:GetAttribute("Perch")] or Layout.miniFollow(mini:GetAttribute("Follow") or order)
				local target = along(root.CFrame * spot + bob, root.CFrame.LookVector)
				local current = (following[mini] or target):Lerp(target, math.min(1, dt * 8))
				following[mini] = current
				local kick = kicked[mini]
				if kick and clock - kick < KICK_SECONDS then
					-- The barrel lies along the frame's X axis.
					current -= current.RightVector * (KICK_STUDS * (1 - (clock - kick) / KICK_SECONDS))
				end
				mini:PivotTo(current)
			elseif following[mini] then
				-- Its owner has no character right now: it waits at home.
				following[mini] = nil
				mini:PivotTo(home)
			end
		end
	end
end

-- Mini cannons fire on their own, at the lead monster within their reach of the player. Only the player's own
-- are drawn firing, and only on the plot. This is for show: the server deals their damage per second to the
-- lead monster of the base all the time, wherever the player is, and away from the fight it simply lands
-- (the monster's bar and the damage numbers show it like any other hit).
-- They fire one after another. However many there are, the whole volley is squeezed into the first half of
-- the wait before the next one, so volleys never run into each other.
local SHOT_GAP = 0.14
local VOLLEY_SECONDS = 0.5 / Config.AutoShotsPerPet
local HUGE_AUTO_SIZE = 1.5 -- a Huge's ordinary shot, against 0.7 for a mini cannon's

local function firePets()
	local pets = petsOf(player)
	-- Not away from the base, and not while the plot is paused: the server deals no shots then either.
	if not pets or inMarket or State.get("Paused", false) == true or not petTarget() then
		return
	end
	local minis = pets:GetChildren()
	local gap = math.min(SHOT_GAP, VOLLEY_SECONDS / #minis)
	for order, mini in minis do
		local barrel = mini:IsA("Model") and mini.PrimaryPart
		if barrel then
			-- A mini cannon with a fire rate above 1 shoots more than once per volley, spread evenly across it
			-- (no fused tier has one since Silver's Rapid Fire became Overcharge, +25% DPS).
			local pet = Config.Pets[mini:GetAttribute("PetId")]
			local shots = if pet then pet.fireRate else 1
			-- A Huge's ordinary shots are twice the size, in its accent colour.
			local size = if pet and pet.huge then HUGE_AUTO_SIZE else 0.7
			local color = if pet and pet.huge then pet.accent elseif pet then pet.color else barrel.Color
			for shot = 0, shots - 1 do
				task.delay((order - 1) * gap + shot / (shots * Config.AutoShotsPerPet), function()
					if barrel.Parent then
						shootAt(petTarget(), barrel.Position, size, color)
					end
				end)
			end
		end
	end
end

-- A Huge Shot: the giant shot a Huge cannon fires by itself (the server deals it and tells
-- src/client/Features/Huge.luau, which asks for this). The Huge kicks back, a giant ball flies from its muzzle,
-- the monster it was fired at (the lead one within the mini cannons' reach of the player, as on the server)
-- lights up in the Huge's colour and the ball bursts over it.
-- landed(position) runs as it hits, for the number. Returns whether it was drawn: not away from the plot, and
-- not while no monster near the player is on screen.
local HUGE_SHOT_SIZE = 4.2
local HUGE_SHOT_FLIGHT = 0.2
local HUGE_SHOT_BURST = 12 -- how wide the ball swells as it fades over the monster

function Effects.hugeShot(petId: string, landed: ((position: Vector3) -> ())?): boolean
	local pets = petsOf(player)
	local model = petTarget()
	local body = model and model.PrimaryPart
	if inMarket or not pets or not model or not body then
		return false
	end
	local barrel: BasePart? = nil
	for _, mini in pets:GetChildren() do
		-- The server names the Huge by its plain id; the model carries the id it is owned by (enchanted or not).
		local worn = Config.Pets[mini:GetAttribute("PetId")]
		if mini:IsA("Model") and mini.PrimaryPart and worn and worn.plain == petId then
			barrel = mini.PrimaryPart
			kicked[mini] = os.clock()
			break
		end
	end
	if not barrel then
		return false
	end
	local pet = Config.Pets[petId]
	local color = if pet and pet.accent then pet.accent else barrel.Color
	local to = body.Position
	local ball = UI.make("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * HUGE_SHOT_SIZE,
		-- From the muzzle: the barrel lies along its X axis.
		Position = barrel.Position + barrel.CFrame.RightVector * (barrel.Size.X / 2),
		Color = color,
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	}, { UI.make("PointLight", { Range = 22, Brightness = 3, Color = color }) })
	local flight = TweenService:Create(ball, TweenInfo.new(HUGE_SHOT_FLIGHT, Enum.EasingStyle.Linear), { Position = to })
	flight.Completed:Connect(function()
		local burst = TweenService:Create(ball, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * HUGE_SHOT_BURST,
			Transparency = 1,
		})
		burst.Completed:Connect(function()
			ball:Destroy()
		end)
		burst:Play()
		-- The server dealt the damage before the ball left, so the monster it was fired at is often dead by
		-- now. The flash goes to the one standing there now: the one that took what was left of the shot.
		local hit = targetModel() or model
		local hitBody = hit.PrimaryPart
		if hit.Parent and hitBody then
			pulse(hitBody)
			local flash = UI.make("Highlight", {
				FillColor = color,
				FillTransparency = 0.1,
				OutlineColor = Color3.new(1, 1, 1),
				OutlineTransparency = 0,
				Parent = hit,
			})
			local fade = TweenService:Create(flash, TweenInfo.new(0.45), { FillTransparency = 1, OutlineTransparency = 1 })
			fade.Completed:Connect(function()
				flash:Destroy()
			end)
			fade:Play()
		end
		if landed then
			landed(to)
		end
	end)
	flight:Play()
	return true
end

----------------------------------------------------------------------------------------------------
-- Egg hatch reveal
-- One card per egg hatched: the egg shakes, then shows its mini cannon. Several eggs hatched at once
-- (the x3 Egg Opener pass) sit side by side.
-- A Secret or a Huge gets a reveal of its own: the screen takes its rarity's colour and beats with the egg's
-- outline, the card says how rare it was, and it stays up longer.
-- The same reveal is played for a mini cannon that did not come from an egg (the game pass's Huge): the caller
-- passes a `gift`, the name and colour of what it comes out of in the egg's place.
----------------------------------------------------------------------------------------------------
local MAX_REVEALS = 3
local CARD_SPACING = 300 -- between egg centres: three cards across still fit a 4:3 screen
local CARD_WIDTH = 290
local LONE_CARD_WIDTH = 640 -- an egg on its own gets room for long lines of text
local RELEASED_NOTE = "storage full, so it was released"
-- A slow open: the egg rocks harder and harder for about a second and a half, then bursts.
local SHAKES = 12
local SHAKE_SECONDS = 0.12
local RARE_SECONDS = 5 -- how long a Secret or a Huge stays up
local RARE_HOLD_SECONDS = 2.5 -- and how long neither a tap nor the next hatch can take it off the screen
local OVERLAY_COLOR = Color3.new(0, 0, 0)
local OVERLAY_TRANSPARENCY = 0.2
local EGG_OUTLINE = 4

local overlay = UI.make("TextButton", {
	Name = "Hatch",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = OVERLAY_COLOR,
	BackgroundTransparency = OVERLAY_TRANSPARENCY,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	ZIndex = 30,
	Parent = UI.gui,
})
-- The eggs share one scaled row, so the gaps between them shrink with the screen just like the eggs.
local eggRow = UI.scaled(UI.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(MAX_REVEALS * CARD_SPACING, 190),
	BackgroundTransparency = 1,
	Parent = overlay,
}))

-- A card is as tall as its egg. Its text hangs underneath.
local cards = {}
for _ = 1, MAX_REVEALS do
	local frame = UI.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = eggRow })
	local outline = UI.stroke(EGG_OUTLINE)
	local shell = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 150, 1, 0),
		Parent = frame,
	}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), outline })
	table.insert(cards, {
		frame = frame,
		outline = outline,
		egg = shell,
		-- The egg, and then what came out of it, in 3D. Bigger than the flat shape it stands in for, which only
		-- shows for an egg or a mini cannon that has no model yet.
		view = UI.preview({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(330, 330), Parent = shell }),
		pop = UI.make("UIScale", { Parent = shell }),
		title = UI.text({ Position = UDim2.new(0, 0, 1, 25), Size = UDim2.new(1, 0, 0, 46), Parent = frame }),
		detail = UI.text({
			Position = UDim2.new(0, 0, 1, 77),
			Size = UDim2.new(1, 0, 0, 56),
			TextColor3 = Colors.text,
			Parent = frame,
		}),
		-- A short third line: side by side the detail lines are too narrow for RELEASED_NOTE, and a Secret
		-- or a Huge says here how rare it was.
		note = UI.text({
			Position = UDim2.new(0, 0, 1, 137),
			Size = UDim2.new(1, 0, 0, 24),
			TextColor3 = Colors.text,
			Parent = frame,
		}),
	})
end

-- Whatever takes the reveal off the screen, the HUD hears that it is over (the egg panel waits for this).
overlay:GetPropertyChangedSignal("Visible"):Connect(function()
	if not overlay.Visible then
		UI.gui:SetAttribute("Hatching", false)
	end
end)

local hatchToken = 0
local rareUntil = 0 -- the os.clock() until which a Secret or Huge reveal cannot be taken off the screen
overlay.Activated:Connect(function()
	if os.clock() < rareUntil then
		return
	end
	hatchToken += 1
	overlay.Visible = false
end)

-- results: a list of { pet = id, kept = boolean, chance = number }, one per egg hatched. chance is the
-- percentage that mini cannon had for this player; without one, a result's `note` is its third line.
-- gift: { name, color } to show in place of an egg (eggId is then ignored).
function Effects.hatch(eggId: string?, results: { { pet: string, kept: boolean, chance: number?, note: string? } }, gift: { name: string, color: Color3 }?)
	local egg = gift or Config.EggById[eggId]
	-- Only what can be drawn: known mini cannons, one per card.
	local reveals = {}
	local rarest = nil -- the rarity of the rarest Secret or Huge among them, if there is one
	for _, result in results do
		local pet = Config.Pets[result.pet]
		if pet and #reveals < MAX_REVEALS then
			table.insert(reveals, { pet = pet, kept = result.kept, chance = result.chance, note = result.note })
			-- A Huge always gets the long reveal, the one from the game pass (which no egg hides) included.
			if (pet.hidden or pet.huge) and (pet.huge or not rarest) then
				rarest = pet.rarity
			end
		end
	end
	local now = os.clock()
	-- Mashing the hatch key must not wipe a Secret off the screen the moment it appears.
	if not egg or #reveals == 0 or (now < rareUntil and not rarest) then
		return
	end
	if rarest then
		rareUntil = now + SHAKES * SHAKE_SECONDS + RARE_HOLD_SECONDS
	end
	hatchToken += 1
	local token = hatchToken
	local lone = #reveals == 1
	overlay.BackgroundColor3 = OVERLAY_COLOR
	overlay.BackgroundTransparency = OVERLAY_TRANSPARENCY
	for index, card in cards do
		card.frame.Visible = index <= #reveals
		card.frame.Size = UDim2.new(0, if lone then LONE_CARD_WIDTH else CARD_WIDTH, 1, 0)
		-- The cards in use are centred as a group.
		card.frame.Position = UDim2.new(0.5, (index - (#reveals + 1) / 2) * CARD_SPACING, 0, 0)
		card.egg.BackgroundColor3 = egg.color
		card.egg.Rotation = 0
		card.outline.Thickness = EGG_OUTLINE
		card.outline.Color = OVERLAY_COLOR
		local eggTemplate = eggId and ReplicatedStorage:FindFirstChild("EggModels") and ReplicatedStorage.EggModels:FindFirstChild(eggId)
		local eggModel = if index <= #reveals and eggTemplate and eggTemplate:IsA("BasePart") then eggTemplate:Clone() else nil
		if eggModel then
			eggModel:PivotTo(CFrame.new())
		end
		card.view.show(eggModel)
		card.egg.BackgroundTransparency = if eggModel then 1 else 0
		card.outline.Transparency = if eggModel then 1 else 0
		card.pop.Scale = 1
		card.title.Text = egg.name
		card.title.TextColor3 = Colors.white
		card.detail.Text = ""
		card.note.Text = ""
		card.note.TextColor3 = Colors.text
	end
	overlay.Visible = true
	UI.gui:SetAttribute("Hatching", true)

	for swing = 1, SHAKES do
		if token ~= hatchToken then
			return
		end
		local lean = 5 + swing * 1.3
		local goal = { Rotation = if swing % 2 == 0 then -lean else lean }
		UI.sound("wobble", 1 + swing * 0.05)
		local tweens = {}
		for index in reveals do
			tweens[index] = TweenService:Create(cards[index].egg, TweenInfo.new(SHAKE_SECONDS), goal)
			tweens[index]:Play()
		end
		tweens[1].Completed:Wait()
	end
	if token ~= hatchToken then
		return
	end
	UI.sound("crack")
	UI.sound(if rarest then "reveal_rare" else "reveal")
	for index, reveal in reveals do
		local card, pet = cards[index], reveal.pet
		local color = Config.RarityColors[pet.rarity]
		card.egg.Rotation = 0
		card.egg.BackgroundColor3 = pet.color
		-- The burst: what was inside pops out where the egg was.
		local mini = Models.mini(pet, 1)
		if mini then
			mini:PivotTo(CFrame.Angles(0, math.rad(90), 0)) -- its face and barrel towards the camera
		end
		card.view.show(mini)
		card.egg.BackgroundTransparency = if mini then 1 else 0
		card.outline.Transparency = if mini then 1 else 0
		card.pop.Scale = 0.4
		TweenService:Create(card.pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		card.title.Text = if pet.huge then "HUGE!" else `{string.upper(pet.rarity)}!`
		card.title.TextColor3 = color
		-- An ordinary one adds its own damage per second. A Huge multiplies tower damage instead, fires Huge
		-- Shots, and has a feature of its own.
		local power = Format.petPower(pet)
		if pet.huge then
			power = `{Format.petPower(pet)} ALL tower damage  •  {Config.hugeShotText()}`
		end
		local detail = `{pet.name}\n{power}`
		if pet.feature then
			detail ..= `  •  {pet.feature}`
		end
		if pet.hidden or pet.huge then
			card.outline.Color = color
			if reveal.chance then
				card.note.Text = Config.oneIn(reveal.chance)
				card.note.TextColor3 = color
			elseif reveal.note then
				card.note.Text = reveal.note
				card.note.TextColor3 = color
			end
		elseif not reveal.kept then
			-- A card on its own is wide enough to say so on the same line.
			if lone then
				detail ..= `  •  {RELEASED_NOTE}`
			else
				card.note.Text = RELEASED_NOTE
			end
		end
		card.detail.Text = detail
	end

	if rarest then
		local color = Config.RarityColors[rarest]
		local shownUntil = os.clock() + RARE_SECONDS
		overlay.BackgroundTransparency = 0.25
		while token == hatchToken and os.clock() < shownUntil do
			local beat = (math.sin(os.clock() * 8) + 1) / 2
			overlay.BackgroundColor3 = color:Lerp(OVERLAY_COLOR, 0.8 - 0.25 * beat)
			for index, reveal in reveals do
				if reveal.pet.hidden or reveal.pet.huge then
					cards[index].outline.Thickness = EGG_OUTLINE + 7 * beat
				end
				-- A Huge's title runs through the rainbow.
				if reveal.pet.huge then
					cards[index].title.TextColor3 = Color3.fromHSV(os.clock() * 0.5 % 1, 0.7, 1)
				end
			end
			task.wait()
		end
	else
		-- More mini cannons take longer to read.
		task.wait(1.4 + 0.4 * (#reveals - 1))
	end
	if token == hatchToken then
		overlay.Visible = false
	end
end

----------------------------------------------------------------------------------------------------
-- Frame loop
----------------------------------------------------------------------------------------------------
local petTimer = 0
local arrivedSlot: number? = nil -- the plot the camera was last turned for

function Effects.start()
	RunService.RenderStepped:Connect(function(dt: number)
		local market = State.get("InMarket", false) == true
		local slot = State.get("Slot", nil)
		local onIsland = if State.get("Place", "plot") == "island" then State.get("Island", 0) else 0
		local onVisit = if State.get("Place", "plot") == "visit" then State.get("Visiting", 0) else 0
		if market ~= inMarket or slot ~= arrivedSlot or onIsland ~= island or onVisit ~= visiting then
			inMarket, arrivedSlot, island, visiting = market, slot, onIsland, onVisit
			faceArrival()
		end
		updateLighting()
		updatePets(os.clock(), dt)
		petTimer += dt
		if petTimer >= 1 / Config.AutoShotsPerPet then
			petTimer = 0
			firePets()
		end
	end)
end

return Effects
