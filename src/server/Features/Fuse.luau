-- Fusing, server half: the Fusion Machine on The Sun's island and the `fuse` action. The rules of a fusion
-- are in the shared module (src/shared/Features/Fuse.luau); this file checks that the player may fuse, owns
-- what they picked, and makes the trade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Parent.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Fuse = require(ReplicatedStorage.Shared.Features.Fuse)
local Islands = require(script.Parent.Parent.Islands)

local rgb = Color3.fromRGB
local DARK = rgb(44, 46, 54)
local STONE = rgb(206, 200, 190)
local CORE = rgb(190, 120, 255)
local GOLD = rgb(255, 200, 40)
local FUSE_ALL_LIMIT = 60 -- fusions in one FUSE ALL: every fusion rebuilds the equipped models, so one press is bounded (a storage without the pass needs 24 at most; press again if sets remain)
local SPOT_SIDE = 5 -- the machine stands on the right half of the island's `enchant` spot (the enchanting table on the left)

local Feature = {}

-- The machine: a glowing core under a cap, one column per fused tier in an arc behind it (the first tier on
-- the customer's left) and a console in front. Few parts: an island has a budget of about 120. `frame` is at floor level, its -Z towards the middle of the
-- island. Everything stays within 3 studs of the middle: the spot is shared.
local function buildMachine(frame: CFrame, parent: Instance): ProximityPrompt
	local model = Instance.new("Model")
	model.Name = "FusionMachine"
	local metal = Enum.Material.Metal
	local neon = Enum.Material.Neon
	local function pillar(name: string, base: CFrame, radius: number, height: number, color: Color3, material: Enum.Material, collide: boolean): Part
		return Build.pillar(base, radius, height, {
			Name = name,
			Color = color,
			Material = material,
			CanCollide = collide,
			CanQuery = collide,
			CanTouch = false,
			Parent = model,
		})
	end
	pillar("FusionBase", frame, 3, 0.4, DARK, metal, true)
	local core = pillar("FusionCore", frame * CFrame.new(0, 0.4, 0), 0.9, 4.6, CORE, neon, true)
	local glow = Instance.new("PointLight")
	glow.Range = 16
	glow.Brightness = 1.2
	glow.Color = CORE
	glow.Parent = core
	pillar("FusionCap", frame * CFrame.new(0, 5, 0), 1.6, 0.5, DARK, metal, false)
	-- One glowing column per tier, taller with each.
	for index, tier in Config.FuseTiers do
		local angle = math.rad(((#Config.FuseTiers + 1) / 2 - index) * 55)
		local pod = frame * CFrame.new(math.sin(angle) * 2.2, 0.4, math.cos(angle) * 2.2)
		pillar("FusionPod", pod, 0.45, 1.2 + index * 0.8, tier.color, neon, false)
	end
	local console = Build.part({
		Name = "FusionConsole",
		Size = Vector3.new(2.6, 1.9, 0.9),
		CFrame = frame * CFrame.new(0, 1.35, -2.2),
		Color = STONE,
		Material = metal,
		CanTouch = false,
		Parent = model,
	})
	-- The sign hangs over this orb rather than a pillar: a billboard's offset follows its part's own axes, and
	-- a pillar is a cylinder turned on its side.
	local top = Build.part({
		Name = "FusionTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.3,
		CFrame = frame * CFrame.new(0, 6.3, 0),
		Color = CORE,
		Material = neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local gui = Build.billboard(top, Vector2.new(13, 3.4), Vector3.new(0, 2.6, 0), 180)
	local title = Build.label(gui, "✨ FUSION MACHINE")
	title.Size = UDim2.fromScale(1, 0.6)
	title.TextColor3 = GOLD
	local how = Build.label(gui, `Fuse {Fuse.COUNT} of the same mini cannon into a stronger one`)
	how.Position = UDim2.fromScale(0, 0.62)
	how.Size = UDim2.fromScale(1, 0.38)
	local prompt = Build.prompt(console, "Open", "Fusion Machine")
	prompt:SetAttribute("Window", Fuse.WINDOW)
	prompt:SetAttribute("Island", Fuse.ISLAND)
	model.PrimaryPart = console
	model.Parent = parent
	return prompt
end

function Feature.start(Game)
	local world = Config.Worlds[Fuse.ISLAND]
	local spot = Islands.spot(Fuse.ISLAND, "enchant")
	local folder = Islands.container(Fuse.ISLAND)
	if spot and folder then
		Feature.prompt = buildMachine(spot * CFrame.new(SPOT_SIDE, 0, 0), folder)
	end

	-- argument: the three picks, a list of exactly Fuse.COUNT mini cannon ids in the order they were picked
	-- (the same id may be in it more than once). The player must have reached the machine's world, be
	-- standing on its island and own every pick; what the fusion makes is worked out here.
	Game.actions.fuse = function(player: Player, data, state, argument: unknown)
		if typeof(argument) ~= "table" then
			return
		end
		local picks = {}
		local keys = 0
		for key, value in argument :: any do
			keys += 1
			if typeof(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > Fuse.COUNT or typeof(value) ~= "string" then
				return
			end
			picks[key] = value
		end
		if keys ~= Fuse.COUNT or #picks ~= Fuse.COUNT then
			return
		end
		if not Fuse.unlocked(data.bestCleared) then
			Game.notify(player, `Reach {world.name} to unlock fusing`, "bad")
			return
		end
		if state.place ~= "island" or state.island ~= Fuse.ISLAND then
			Game.notify(player, `Visit the Fusion Machine on the {world.name} island`, "bad")
			return
		end
		local result, why = Fuse.result(picks)
		if not result then
			Game.notify(player, why or "That cannot be fused", "bad")
			return
		end
		-- Game.pets.swap checks that the player owns every pick (each copy counted once) and does nothing
		-- otherwise. The result takes the first pick's place, so storage is never an issue.
		if not Game.pets.swap(player, picks, result) then
			Game.notify(player, "You do not own those mini cannons any more", "bad")
			return
		end
		local made = Config.Pets[result]
		local tier = Config.FuseTiers[made.tier]
		local kept = if made.enchanted then ". It kept its enchantments" else ""
		Game.send(player, "fuse", { pet = result })
		Game.notify(player, `Fused a {made.name}! {Format.petPower(made)}, new perk: {tier.perk}{kept}`, "good")
	end

	-- FUSE ALL: every set of Fuse.COUNT of the same mini cannon and tier is fused, and the results with them,
	-- until no set is left. Only mini cannons without enchantments are used, as FILL does, so one press can
	-- never lose an enchantment. Same rules of place as `fuse`.
	Game.actions.fuseAll = function(player: Player, data, state)
		if not Fuse.unlocked(data.bestCleared) then
			Game.notify(player, `Reach {world.name} to unlock fusing`, "bad")
			return
		end
		if state.place ~= "island" or state.island ~= Fuse.ISLAND then
			Game.notify(player, `Visit the Fusion Machine on the {world.name} island`, "bad")
			return
		end
		local fusions, best = 0, nil
		for _ = 1, FUSE_ALL_LIMIT do
			local counts = {}
			for _, id in data.pets do
				counts[id] = (counts[id] or 0) + 1
			end
			local picks = Fuse.fill(counts, {})
			local result = picks and Fuse.result(picks)
			if not picks or not result or not Game.pets.swap(player, picks, result) then
				break
			end
			fusions += 1
			local made = Config.Pets[result]
			if not best or made.bonus > Config.Pets[best].bonus then
				best = result
			end
		end
		if not best then
			Game.notify(player, `Nothing to fuse: it takes {Fuse.COUNT} of the same mini cannon without enchantments`, "info")
			return
		end
		Game.send(player, "fuse", { pet = best })
		local more = if fusions == FUSE_ALL_LIMIT then " Press FUSE ALL again for the rest." else ""
		Game.notify(player, `Fused {fusions} time{if fusions == 1 then "" else "s"}! Best: {Config.Pets[best].name}, {Format.petPower(Config.Pets[best])}{more}`, "good")
	end
end

return Feature
