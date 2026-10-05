-- Huge cannons on the server: the Huge Shot every equipped Huge fires, what each one's special feature does
-- while it is equipped, the Huge that comes with the hugeStarter game pass, and the moment a Secret or a Huge
-- is hatched (the server-wide announcement and the player's index of everything they have found). It also
-- tells each client its player's luck, so the egg stands can show the odds that player really has.
-- The features' numbers are in src/shared/Features/Huge.luau; a Huge's power and the Huge Shot's numbers are
-- in Config.luau (Config.HugePower, Config.HugeShot).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Shared = require(ReplicatedStorage.Shared.Features.Huge)
local Build = require(script.Parent.Parent.Build)
local Data = require(script.Parent.Parent.Data)
local Marketplace = require(script.Parent.Parent.Marketplace)
local Passes = require(script.Parent.Parent.Passes)

local Huge = {}

local rgb = Color3.fromRGB
local SHOWCASE_SCALE = 2.4 -- the Huge on the pedestal against an ordinary mini cannon (3 would pass the pedestal)
local SLOW_HOLD = 1 -- seconds a Huge's slow lasts on a monster: renewed twice a second while it is equipped

-- This feature's part of the save.
local DEFAULTS = {
	found = {}, -- [mini cannon id] = true: every one the player has hatched, won, or owned when they joined
	granted = false, -- whether the game pass's Huge has been given
	eggs = 0, -- eggs hatched since the last free one (Golden Eggs)
	gemDay = 0, -- the UTC day `gems` counts
	gems = 0, -- gems found that day (Gem Finder)
	autoUpgrade = true, -- whether the Tycoon upgrades towers by itself (the switch is in the INDEX window)
}

local Game -- the plug-in API, set by start

----------------------------------------------------------------------------------------------------
-- Which features a player has: one per different Huge they have equipped
----------------------------------------------------------------------------------------------------
local equippedFeatures = setmetatable({}, { __mode = "k" }) -- [state] = { equipped, features }

-- state.equipped is replaced whenever the equipped mini cannons change, so the answer is remembered until
-- then: the hooks below run on every shot and every kill.
local function featuresOf(state)
	local known = equippedFeatures[state]
	if not known or known.equipped ~= state.equipped then
		local features, seen = {}, {}
		for _, id in state.equipped do
			-- The first copy only: a second one of the same Huge adds nothing. An enchanted Huge is the
			-- same Huge: its feature goes by its plain id.
			local pet = Config.Pets[id]
			local plain = if pet then pet.plain else id
			if Shared.Features[plain] and not seen[plain] then
				seen[plain] = true
				table.insert(features, Shared.Features[plain])
			end
		end
		known = { equipped = state.equipped, features = features }
		equippedFeatures[state] = known
	end
	return known.features
end

-- What the player's equipped Huges multiply `key` by: 1 when none of them has it.
function Huge.multiplier(state, key: string): number
	local value = 1
	for _, feature in featuresOf(state) do
		value *= feature[key] or 1
	end
	return value
end

----------------------------------------------------------------------------------------------------
-- The index: what the player has found. The client shows it in the INDEX window.
----------------------------------------------------------------------------------------------------
local function saved(data)
	return Game.feature(data, "huge", DEFAULTS)
end

-- [player] = { id, n }: the Huge the game pass gave them in this session. The client plays its reveal once
-- for each new n. It is never saved, so the reveal is for the moment the Huge is given, not for every join.
local arrivals = {}
local arrivalCount = 0

local function publish(player: Player, data)
	local save = saved(data)
	Game.setMeta(player, "huge", { found = save.found, arrived = arrivals[player], autoUpgrade = save.autoUpgrade })
end

-- Ticks a mini cannon in the player's index. Fused ones count as the one they were fused from.
function Huge.discover(player: Player, petId: string)
	local data = Game.data(player)
	local pet = Config.Pets[petId]
	if data and pet and not saved(data).found[pet.base] then
		saved(data).found[pet.base] = true
		publish(player, data)
	end
end

-- The game pass's Huge: owning the pass gives it once, however often the pass is seen again.
-- reveal: whether the client plays the reveal for it.
local function grant(player: Player, data, reveal: boolean)
	if saved(data).granted or not Passes.owns(player, Shared.PassKey) then
		return
	end
	saved(data).granted = true
	Game.pets.add(player, Shared.PassPet, true)
	if reveal then
		arrivalCount += 1
		arrivals[player] = { id = Shared.PassPet, n = arrivalCount }
	end
	Huge.discover(player, Shared.PassPet)
	publish(player, data)
	Game.notify(player, `Your {Config.Pets[Shared.PassPet].name} has arrived!`, "good")
end

----------------------------------------------------------------------------------------------------
-- Luck: the client cannot work out the luck modifiers, so the server tells it the result.
----------------------------------------------------------------------------------------------------
local shownLuck = {} -- [player] = the luck their client was last told

local function publishLuck(player: Player, data, state)
	local luck = Game.luck(player, data, state)
	if shownLuck[player] ~= luck then
		shownLuck[player] = luck
		player:SetAttribute("Luck", luck)
	end
end

----------------------------------------------------------------------------------------------------
-- The showcase: the game pass's Huge on a pedestal in the marketplace. Its prompt opens the store.
----------------------------------------------------------------------------------------------------
local function buildShowcase()
	local folder = Marketplace.container()
	local pet = Config.Pets[Shared.PassPet]
	local pass = Config.Passes[Shared.PassKey]
	local spot = Marketplace.frame(24, 0, -32).Position
	local middle = Marketplace.frame(0, 0, 0).Position
	-- Floor level, with -Z facing the statue in the middle of the square: where the customers come from.
	local frame = CFrame.lookAt(spot, Vector3.new(middle.X, spot.Y, middle.Z))
	local neon = Enum.Material.Neon

	Build.pillar(frame, 3.4, 1, { Name = "HugePedestal", Color = rgb(44, 46, 54), Material = Enum.Material.Marble, Parent = folder })
	Build.pillar(frame * CFrame.new(0, 1, 0), 2.6, 0.6, {
		Name = "HugePedestalTop",
		Color = pet.accent,
		Material = Enum.Material.Metal,
		Parent = folder,
	})

	-- The same shape Plots.buildPets gives a Huge: seen from the front it shows its eyes, and the
	-- barrel points up and away.
	local scale = SHOWCASE_SCALE
	local center = Vector3.new(0, 1.6 + 1.1 * scale, 0)
	local direction = Vector3.new(0, 0.2, 1).Unit
	local function piece(name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
		return Build.part({
			Name = name,
			Shape = shape,
			Size = size * scale,
			CFrame = frame * cframe,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = folder,
		})
	end
	local cylinder, ball = Enum.PartType.Cylinder, Enum.PartType.Ball
	local barrel = piece("HugeBarrel", cylinder, Vector3.new(2.2, 1, 1), Build.along(center, direction), pet.color, neon)
	for _, offset in { 0.85, 0.2, -0.75 } do
		piece("HugeBand", cylinder, Vector3.new(0.16, 1.2, 1.2), Build.along(center + direction * offset * scale, direction), pet.accent, neon)
	end
	local halo = CFrame.new(center + Vector3.new(0, 1.05, -0.1) * scale) * CFrame.Angles(0, 0, math.rad(90))
	piece("HugeHalo", cylinder, Vector3.new(0.07, 1.3, 1.3), halo, pet.accent, neon).Transparency = 0.3
	for _, side in { -1, 1 } do
		local function at(x: number, y: number, z: number): CFrame
			return CFrame.new(center + Vector3.new(side * x, y, z) * scale)
		end
		piece("HugeWheel", cylinder, Vector3.new(0.25, 0.9, 0.9), at(0.62, -0.35, -0.2), rgb(40, 40, 40))
		piece("HugeEye", ball, Vector3.one * 0.36, at(0.24, 0.42, -0.6), Color3.new(1, 1, 1))
		piece("HugePupil", ball, Vector3.one * 0.18, at(0.24, 0.5, -0.74), Color3.new(0, 0, 0))
	end
	local glow = Instance.new("PointLight")
	glow.Range = 20
	glow.Brightness = 1.5
	glow.Color = pet.accent
	glow.Parent = barrel

	-- The sign hangs on an orb that is not turned, so its offset is straight up whichever way the pedestal faces.
	local orb = Build.part({
		Name = "HugeOrb",
		Shape = ball,
		Size = Vector3.one * 0.9,
		Position = frame * (center + Vector3.new(0, 1.6 * scale, 0)),
		Color = pet.accent,
		Material = neon,
		CanCollide = false,
		Parent = folder,
	})
	local gui = Build.billboard(orb, Vector2.new(13, 4.6), Vector3.new(0, 3.2, 0), 150)
	local title = Build.label(gui, string.upper(pet.name))
	title.Size = UDim2.fromScale(1, 0.4)
	title.TextColor3 = Config.RarityColors[pet.rarity]
	local feature = Build.label(gui, `{Format.petPower(pet)} tower damage  •  {pet.feature}`)
	feature.Position = UDim2.fromScale(0, 0.42)
	feature.Size = UDim2.fromScale(1, 0.3)
	local price = Build.label(gui, `{pass.price} R$  •  the only Huge you can buy`)
	price.Position = UDim2.fromScale(0, 0.74)
	price.Size = UDim2.fromScale(1, 0.26)
	price.TextColor3 = pet.accent

	local plate = Build.part({
		Name = "HugePlate",
		Size = Vector3.new(4.4, 1.3, 0.4),
		CFrame = frame * CFrame.new(0, 1.65, -3),
		Color = rgb(44, 46, 54),
		Parent = folder,
	})
	Build.label(Build.surface(plate, Enum.NormalId.Front), `{pass.price} R$`).TextColor3 = pet.accent
	Build.prompt(plate, "View", pet.name):SetAttribute("Window", "STORE")
end

----------------------------------------------------------------------------------------------------
local shotTimers = {} -- [player] = { [Huge id] = seconds since its last Huge Shot }
local toldUpgrade = {} -- [player] = true once this session's first upgrade by the Tycoon has been announced

function Huge.start(api)
	Game = api
	local rng = Game.random

	-- What the STATS window calls a number's Huge source: the equipped Huges that have that feature, by name.
	-- nil (not active) when none has it.
	local function sourceLabel(key: string)
		return function(_player: Player, _data, state): string?
			local names = {}
			for _, feature in featuresOf(state) do
				if feature[key] then
					table.insert(names, `{Config.Pets[feature.id].name}: {feature.name}`)
				end
			end
			return if #names > 0 then table.concat(names, ", ") else nil
		end
	end

	-- bossDamage is every tower and mini cannon shot on a boss level (a giant, a mid boss, a world boss);
	-- crateDrops is read by the Crates feature (Game.value); monsterSpeed is how fast monsters walk (under 1 is
	-- slower).
	for _, kind in { "coins", "heal", "luck", "bossDamage", "crateDrops", "monsterSpeed" } do
		Game.modify(kind, function(_player: Player, _data, state, value: number): number
			return value * Huge.multiplier(state, kind)
		end, sourceLabel(kind))
	end

	-- What the Huges do to one shot: a tower's, a mini cannon's, or a Huge Shot. hp and maxHp are the health of
	-- the monster it is about to hit.
	local function strike(state, shot, hp: number, maxHp: number)
		local execute = 0
		for _, feature in featuresOf(state) do
			local multi = feature.multiHit
			if multi and rng:NextNumber() < multi.chance then
				shot.damage *= multi.hits
			end
			execute = math.max(execute, feature.execute or 0)
		end
		-- Execute: a shot that would leave the monster that low kills it instead.
		if execute > 0 and hp - shot.damage <= maxHp * execute then
			shot.damage = math.max(shot.damage, hp)
		end
	end

	-- The core puts the health of the monster a shot is about to hit in state.hp and state.maxHp.
	Game.on("shot", function(_player: Player, _data, state, shot)
		strike(state, shot, state.hp, state.maxHp)
	end)

	-- The Huge Shot: one giant shot worth Config.HugeShot.shots mini cannon shots at once (Game.shotDamage: what
	-- the player's average mini cannon deals in a second), at the monster furthest along the path within
	-- Config.Defense.petRange of the player, and only while the player is on their plot. Unlike the mini
	-- cannons' own damage, which lands wherever the player is, it still needs the player at the fight. It hits
	-- that monster only: what is left over after a kill is
	-- lost, so a Huge cannot clear an easy level on its own, and it does nothing for a player who is away.
	-- Returns false when there is nothing to shoot at.
	local function hugeShot(player: Player, state, feature): boolean
		local lead = Game.leadNear(player) -- within Config.Defense.petRange (times the `petRange` modifiers) of the player
		if not lead then
			return false
		end
		local shot = { manual = false, damage = Game.shotDamage(player) * Config.HugeShot.shots, source = "huge" }
		strike(state, shot, lead.hp, lead.max)
		local damage = shot.damage
		if typeof(damage) ~= "number" or damage ~= damage or damage <= 0 or damage == math.huge then
			return false
		end
		if not Game.hurt(player, lead, math.min(damage, lead.hp)) then
			return false
		end
		-- The client draws it: a giant ball from that Huge, a flash on the monster and the number.
		Game.send(player, "hugeShot", feature.id, damage)
		return true
	end

	-- The Tycoon upgrades the tower whose next level is the cheapest, one level every tick, whenever the coins
	-- reach: the same press as UPGRADE +1 in the TOWER window. It never builds a tower or buys a pad, and the
	-- player can switch it off (to save up for one) in the INDEX window.
	local function autoUpgrade(player: Player, data, state)
		if not saved(data).autoUpgrade then
			return
		end
		local pad, price = nil, math.huge
		local discount = Game.value(player, "upgradeCost")
		for key, tower in data.towers do
			local index = tonumber(key)
			if index and tower.level < Config.TowerMaxLevel then
				local cost = Config.towerUpgradeCost(tower.kind, tower.level, discount)
				if cost < price or (cost == price and index < pad) then
					pad, price = index, cost
				end
			end
		end
		-- Only when the coins are there: the action would otherwise answer "need more coins" twice a second.
		if not pad or price > data.coins then
			return
		end
		Game.actions.upgradeTower(player, data, state, { pad = pad, levels = 1 })
		state.dirty = true
		if not toldUpgrade[player] then
			toldUpgrade[player] = true
			Game.notify(player, "Tycoon is upgrading your cheapest tower for you. Switch it off in INDEX to save up coins", "info")
		end
	end

	-- Hex and the like: every monster on the plot walks slower while the Huge is equipped. The core's own slow
	-- (a Frost tower's) is one number per monster and the stronger one wins, so this never adds to it.
	local function slowAll(state, slow: number)
		local now = state.clock
		for _, monster in state.monsters do
			if not monster.dead and (now >= monster.slowUntil or monster.slow <= slow) then
				monster.slow = slow
				monster.slowUntil = now + SLOW_HOLD
			end
		end
	end

	function Game.actions.toggleTycoon(player: Player, data)
		local save = saved(data)
		save.autoUpgrade = not save.autoUpgrade
		publish(player, data)
		Game.notify(player, if save.autoUpgrade then "Tycoon upgrades your towers again" else "Tycoon leaves your coins alone", "info")
	end

	Game.on("kill", function(player: Player, data, state, info)
		local boss = info.kind ~= "normal"
		for _, feature in featuresOf(state) do
			if feature.candy and Config.halloweenActive(os.time()) then
				-- The core has already paid the candy once.
				local base = if boss then Config.Halloween.candyPerBoss else Config.Halloween.candyPerKill
				data.candy += base * (feature.candy - 1)
			end
			if feature.bossGems and boss then
				local save = saved(data)
				local day = Config.dayNumber(os.time())
				if save.gemDay ~= day then
					save.gemDay, save.gems = day, 0
				end
				if save.gems < feature.gemsPerDay then
					-- Never past the day's limit, whatever a boss drops.
					local gems = math.min(feature.bossGems, feature.gemsPerDay - save.gems)
					save.gems += gems
					data.diamonds += gems
					if save.gems >= feature.gemsPerDay then
						Game.notify(player, `{feature.name}: all {feature.gemsPerDay} gems found today. More tomorrow!`, "info")
					end
				end
			end
		end
	end)

	Game.on("hatch", function(player: Player, data, state, egg, results)
		for _, result in results do
			local pet = Config.Pets[result.pet]
			Huge.discover(player, result.pet)
			if pet.hidden then
				local what = if pet.huge then string.upper(pet.name) else `SECRET {pet.name}`
				local odds = if result.chance then ` ({Config.oneIn(result.chance)})` else ""
				Game.announce(`{player.DisplayName} hatched a {what}!{odds}`, "good")
			end
		end
		for _, feature in featuresOf(state) do
			if feature.freeEgg then
				-- Golden Eggs: a count, not a chance, so every egg's real price is known before it is bought.
				local save = saved(data)
				local count = save.eggs + #results
				-- Never more free eggs than were hatched: a save from when it took more eggs to earn one can
				-- hold a higher count than this cycle is long.
				local free = math.min(count // feature.freeEgg, #results)
				save.eggs = count % feature.freeEgg
				if free > 0 then
					data[egg.currency] += egg.cost * free
					Game.notify(player, `{feature.name}: {free} of those eggs {if free == 1 then "was" else "were"} free!`, "good")
				end
			end
		end
	end)

	Game.on("ready", function(player: Player, data, state)
		-- What the player owns counts as found: saves from before the index, and mini cannons that came from
		-- a shop, a reward or a trade.
		local found = saved(data).found
		for _, id in data.pets do
			local pet = Config.Pets[id]
			if pet then
				found[pet.base] = true
			end
		end
		-- Given on joining, it is only revealed when the save loaded: a session that cannot save (the store
		-- is down, or Studio without API access) gives it again on every join, and that is not an arrival.
		grant(player, data, (Data.loaded(player)))
		publish(player, data)
		publishLuck(player, data, state)
	end)

	Game.on("tick", function(player: Player, data, state, dt: number)
		publishLuck(player, data, state)
		local features = featuresOf(state)
		if #features == 0 then
			return
		end
		local timers = shotTimers[player]
		if not timers then
			timers = {}
			shotTimers[player] = timers
		end
		local every = Config.HugeShot.seconds
		for index, feature in features do
			-- Each Huge keeps its own time. Several take turns: a new one starts part of the way through its wait.
			local waited = (timers[feature.id] or (index - 1) / #features * every) + dt
			if waited >= every then
				-- One shot a tick at most, however late the tick is. With nothing to shoot at it stays loaded.
				waited = if hugeShot(player, state, feature) then math.min(waited - every, every) else every
			end
			timers[feature.id] = waited
			if feature.autoUpgrade then
				autoUpgrade(player, data, state)
			end
		end
		local slow = 0
		for _, feature in features do
			slow = math.max(slow, feature.slow or 0)
		end
		if slow > 0 and state.phase == "fight" then
			slowAll(state, slow)
		end
	end)

	Game.on("leave", function(player: Player)
		shownLuck[player] = nil
		shotTimers[player] = nil
		toldUpgrade[player] = nil
		arrivals[player] = nil
	end)

	-- A pass bought mid-session. In Studio, where the Debug remote can also take a pass away again, the Huge
	-- goes with it, so a test save can be tried with and without it.
	Passes.changed:Connect(function(player: Player)
		local data = Game.data(player)
		if not data or not Game.state(player) then
			return
		end
		if RunService:IsStudio() and saved(data).granted and not Passes.owns(player, Shared.PassKey) then
			saved(data).granted = false
			Game.pets.remove(player, Shared.PassPet, 1)
			arrivals[player] = nil
			publish(player, data)
		else
			grant(player, data, true)
		end
	end)

	buildShowcase()
end

return Huge
