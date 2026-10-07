-- Mastery, server half: the shrine on the Mars island, the `masteryBuy` action, and one labelled modifier per
-- track, so every track shows up as a source in the STATS window. What the tracks are, what they cost and
-- what a level does is in the shared module (src/shared/Features/Mastery.luau); this file checks, sells
-- and applies.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Parent.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Islands = require(script.Parent.Parent.Islands)
local Mastery = require(ReplicatedStorage.Shared.Features.Mastery)

local STONE = Color3.fromRGB(226, 220, 235)
local DARK = Color3.fromRGB(70, 52, 110)
local GLOW = Color3.fromRGB(255, 198, 26)
local CRYSTAL = Color3.fromRGB(190, 110, 255)

local Feature = {}

-- The shrine: a round dais with four pillars and a crystal floating over an altar, inside the island's
-- reserved 12 x 12 spot. `frame` is at floor level, its -Z towards the middle of the island.
local function buildShrine(frame: CFrame, parent: Instance): ProximityPrompt
	local model = Instance.new("Model")
	model.Name = "MasteryShrine"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, collide: boolean): Part
		return Build.part({
			Name = name,
			Size = size,
			CFrame = frame * offset,
			Color = color,
			Material = material,
			CanCollide = collide,
			CanQuery = collide,
			CanTouch = false,
			Parent = model,
		})
	end
	local function disc(name: string, y: number, radius: number, height: number, color: Color3)
		Build.pillar(frame * CFrame.new(0, y, 0), radius, height, {
			Name = name,
			Color = color,
			Material = Enum.Material.Marble,
			CanTouch = false,
			Parent = model,
		})
	end
	disc("ShrineBase", 0, 5.6, 0.5, STONE)
	disc("ShrineStep", 0.5, 4.2, 0.5, DARK)
	for _, x in { -3.6, 3.6 } do
		for _, z in { -3.6, 3.6 } do
			Build.pillar(frame * CFrame.new(x, 0.5, z), 0.55, 7.5, {
				Name = "ShrinePillar",
				Color = STONE,
				Material = Enum.Material.Marble,
				CanTouch = false,
				Parent = model,
			})
			Build.ellipsoid(part("ShrineFlame", Vector3.new(1.3, 1.3, 1.3), CFrame.new(x, 8.6, z), GLOW, Enum.Material.Neon, false))
		end
	end
	local altar = part("ShrineAltar", Vector3.new(3, 2.6, 3), CFrame.new(0, 2.3, 0), DARK, Enum.Material.Marble, true)
	-- A block stood on its corner reads as a crystal.
	local tilt = CFrame.Angles(math.rad(45), 0, math.rad(35.26))
	local crystal = part("ShrineCrystal", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 6.2, 0) * tilt, CRYSTAL, Enum.Material.Neon, false)
	local light = Instance.new("PointLight")
	light.Color = CRYSTAL
	light.Range = 26
	light.Brightness = 2
	light.Parent = crystal
	Build.label(Build.billboard(crystal, Vector2.new(13, 2.6), Vector3.new(0, 4.6, 0), 180), "MASTERY")
	local prompt = Build.prompt(altar, "Open", "Mastery Shrine")
	prompt:SetAttribute("Window", Mastery.WINDOW)
	prompt:SetAttribute("Island", Mastery.ISLAND)
	model.PrimaryPart = altar
	model.Parent = parent
	return prompt
end

function Feature.start(Game)
	local world = Config.Worlds[Mastery.ISLAND]
	local spot = Islands.spot(Mastery.ISLAND, "mastery")
	local folder = Islands.container(Mastery.ISLAND)
	if spot and folder then
		Feature.prompt = buildShrine(spot, folder)
	end

	-- Tracks the core cannot apply in this build: [track id] = true. They are shown, and not sold. None today:
	-- every track has its modifier in the core (tests/mastery.luau buys each one and measures what it did).
	local off = {}

	-- Whether a track with a daily limit (Gem Hunter) still gives today. It reads the save without touching
	-- it: a modifier runs often. A count from another UTC day is yesterday's, so nothing was found today.
	local function underLimit(saved, id: string, level: number): boolean
		if typeof(saved) ~= "table" or saved.gemDay ~= Config.dayNumber(os.time()) then
			return true
		end
		return typeof(saved.gems) ~= "number" or saved.gems ~= saved.gems or saved.gems < Mastery.perDay(id, level)
	end

	-- One modifier per track. It reads the saved level directly: a modifier runs for every shot.
	for _, track in Mastery.Tracks do
		local id = track.id
		local limited = track.perDay ~= nil
		local ok = pcall(Game.modify, track.kind, function(_player: Player, data, state, value: number): number
			local saved = data.features.mastery
			local level = Mastery.level(saved, id)
			if level <= 0 or (limited and not underLimit(saved, id, level)) then
				return value
			end
			return Mastery.apply(id, level, value, state)
		end, function(_player: Player, data): string?
			local saved = data.features.mastery
			local level = Mastery.level(saved, id)
			return if level > 0 and (not limited or underLimit(saved, id, level)) then Mastery.label(id, level) else nil
		end)
		if not ok then
			off[id] = true -- a core without a modifier of that kind (an older one had no `equipSlots`)
		end
	end
	Feature.off = off

	local function publish(player: Player, data)
		local saved = Game.feature(data, "mastery", Mastery.SAVED)
		Game.setMeta(player, "mastery", { levels = saved.levels, spent = saved.spent, off = off })
	end

	-- argument: a track id. The player must have reached the shrine's world and be standing on its island;
	-- the level and the price are worked out here, never taken from the client.
	Game.actions.masteryBuy = function(player: Player, data, state, argument: unknown)
		if typeof(argument) ~= "string" then
			return
		end
		local track = Mastery.byId[argument]
		if not track then
			return
		end
		if not Mastery.unlocked(data.bestCleared) then
			Game.notify(player, `Reach {world.name} to unlock Mastery`, "bad")
			return
		end
		if state.place ~= "island" or state.island ~= Mastery.ISLAND then
			Game.notify(player, `Visit the Mastery Shrine on the {world.name} island`, "bad")
			return
		end
		if off[track.id] then
			Game.notify(player, `{track.name} mastery is coming soon`, "info")
			return
		end
		local saved = Game.feature(data, "mastery", Mastery.SAVED)
		local level = Mastery.level(saved, track.id)
		if level >= track.cap then
			Game.notify(player, `{track.name} mastery is maxed`, "info")
			return
		end
		local missing = Mastery.missing(saved, track.id)
		if missing then
			Game.notify(player, `{track.name} does nothing without {missing.name}: buy a level of {missing.name} first`, "bad")
			return
		end
		local cost = Mastery.cost(track.id, level + 1)
		if typeof(cost) ~= "number" or cost ~= cost or cost < 1 then
			return
		end
		if data.diamonds < cost then
			Game.notify(player, `Not enough gems for {track.name} {Mastery.roman(level + 1)} ({cost} 💎)`, "bad")
			return
		end
		data.diamonds -= cost
		saved.levels[track.id] = level + 1
		saved.spent = (if typeof(saved.spent) == "number" then saved.spent else 0) + cost
		if track.how == "slots" and typeof(Game.refreshPets) == "function" then
			Game.refreshPets(player) -- a new slot: equip into it
		end
		publish(player, data)
		Game.sync(player)
		local note = if track.kind == "lives"
			then " (from the next level you start)"
			elseif track.kind == "offlineCap" or track.kind == "offlineShare" then " (from the next time you are away)"
			else ""
		Game.notify(player, `{track.name} {Mastery.roman(level + 1)}: {Mastery.describe(track.id, level + 1)}{note}`, "good")
	end

	-- Gem Hunter: the `gems` modifier above made this boss drop more; count it against today's limit.
	for _, track in Mastery.Tracks do
		if track.perDay and track.kind == "gems" then
			local id = track.id
			Game.on("kill", function(player: Player, data, _state, info)
				if info.kind == "normal" or off[id] then
					return
				end
				local saved = Game.feature(data, "mastery", Mastery.SAVED)
				local level = Mastery.level(saved, id)
				if level <= 0 then
					return
				end
				local day = Config.dayNumber(os.time())
				if saved.gemDay ~= day or typeof(saved.gems) ~= "number" or saved.gems ~= saved.gems then
					saved.gemDay, saved.gems = day, 0
				end
				local limit = Mastery.perDay(id, level)
				if saved.gems < limit then
					saved.gems += track.per * level
					if saved.gems >= limit then
						Game.notify(player, `{track.name}: all {limit} gems found today. More tomorrow!`, "info")
					end
				end
			end)
		end
	end

	Game.on("ready", function(player: Player, data)
		-- A save from another build. Nothing a player bought is thrown away here: a level of a track this build
		-- does not have, or above this build's cap, stays in the save as it is (Mastery.level reads every level
		-- as a whole number from 0 to the cap, so it is harmless, and it is still there for the build that
		-- knows it). Only what is not a level at all goes.
		local saved = Game.feature(data, "mastery", Mastery.SAVED)
		local levels = {}
		if typeof(saved.levels) == "table" then
			for id, level in saved.levels do
				if typeof(id) == "string" and typeof(level) == "number" and level == level and level >= 1 and level < math.huge then
					levels[id] = math.floor(level)
				end
			end
		end
		saved.levels = levels
		if typeof(saved.spent) ~= "number" or saved.spent ~= saved.spent then
			saved.spent = 0
		end
		if typeof(saved.gemDay) ~= "number" or typeof(saved.gems) ~= "number" or saved.gems ~= saved.gems then
			saved.gemDay, saved.gems = 0, 0
		end
		publish(player, data)
	end)
end

return Feature
