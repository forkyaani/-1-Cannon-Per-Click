-- Enchanting, server half: the table on The Sun's island, the `enchant` action (one key and some gems for a
-- roll), and what the enchantments of the equipped mini cannons do. The enchantments, the prices and the
-- odds are in the shared module (src/shared/Features/Enchant.luau); this file checks, rolls and applies.
--
-- Those that change a number of the game are labelled modifiers, one per enchantment, whose label lists
-- every mini cannon that has it ("Mini Storm Cannon: Sharp III"), so each shows as its own source in the
-- STATS window. Those that act on a shot or a kill are hooks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Parent.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Enchant = require(ReplicatedStorage.Shared.Features.Enchant)
local Islands = require(script.Parent.Parent.Islands)
local Items = require(ReplicatedStorage.Shared.Items)
local Policy = require(script.Parent.Parent.Policy)

local rgb = Color3.fromRGB
local OBSIDIAN = rgb(38, 30, 60)
local CLOTH = rgb(150, 40, 60)
local PAGE = rgb(255, 246, 225)
local GLOW = rgb(190, 110, 255)
local FLAME = rgb(255, 198, 26)
local SPOT_SIDE = -5 -- the table stands on the left half of the island's `enchant` spot (the Fusion Machine on the right)

local Feature = {}

-- The table: a cloth-covered block, an open book floating over it and an orb over that, on a round base
-- with two candles. Few parts: an island has a budget of about 120. `frame` is at floor level, its -Z towards the middle of the island. Everything
-- stays within 3 studs of the middle: the spot is shared.
local function buildTable(frame: CFrame, parent: Instance): ProximityPrompt
	local model = Instance.new("Model")
	model.Name = "EnchantingTable"
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
	Build.pillar(frame, 3, 0.4, { Name = "EnchantBase", Color = OBSIDIAN, Material = Enum.Material.Slate, CanTouch = false, Parent = model })
	local block = part("EnchantTable", Vector3.new(3, 2.4, 2.6), CFrame.new(0, 1.6, 0), CLOTH, Enum.Material.Fabric, true)
	-- The book lies open, tilted towards whoever walks up.
	part("EnchantBook", Vector3.new(1.8, 0.25, 1.3), CFrame.new(0, 3.6, 0) * CFrame.Angles(math.rad(-25), 0, 0), PAGE, Enum.Material.SmoothPlastic, false)
	local orb = part("EnchantOrb", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 5.4, 0), GLOW, Enum.Material.Neon, false)
	orb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 22
	light.Brightness = 2
	light.Parent = orb
	for _, side in { -1, 1 } do
		Build.pillar(frame * CFrame.new(side * 2.2, 0.4, 1.4), 0.22, 2, {
			Name = "EnchantCandle",
			Color = FLAME,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = model,
		})
	end
	local gui = Build.billboard(orb, Vector2.new(13, 3.4), Vector3.new(0, 3.2, 0), 180)
	local title = Build.label(gui, "✨ ENCHANTING")
	title.Size = UDim2.fromScale(1, 0.6)
	title.TextColor3 = FLAME
	local how = Build.label(gui, "A key and some gems for random perks")
	how.Position = UDim2.fromScale(0, 0.62)
	how.Size = UDim2.fromScale(1, 0.38)
	local prompt = Build.prompt(block, "Open", "Enchanting Table")
	prompt:SetAttribute("Window", Enchant.WINDOW)
	prompt:SetAttribute("Island", Enchant.ISLAND)
	model.PrimaryPart = block
	model.Parent = parent
	return prompt
end

function Feature.start(Game)
	local world = Config.Worlds[Enchant.ISLAND]
	local spot = Islands.spot(Enchant.ISLAND, "enchant")
	local folder = Islands.container(Enchant.ISLAND)
	if spot and folder then
		Feature.prompt = buildTable(spot * CFrame.new(SPOT_SIDE, 0, 0), folder)
	end
	local rng = Game.random

	------------------------------------------------------------------------------------------------
	-- What a player's equipped mini cannons add up to. state.equipped is replaced whenever the equipped mini
	-- cannons change, so the answer is remembered until then: modifiers run on every shot.
	------------------------------------------------------------------------------------------------
	local SHOT_ENCHANTS = { "splinter", "frostbite", "ember", "chain", "executioner" }
	local KILL_ENCHANTS = { "sweettooth", "scholar", "gemfinder" }
	local known = setmetatable({}, { __mode = "k" }) -- [state] = { equipped, totals, shots, kills }

	local function equippedOf(state)
		local entry = known[state]
		if not entry or entry.equipped ~= state.equipped then
			local totals = Enchant.totals(state.equipped)
			entry = { equipped = state.equipped, totals = totals, shots = false, kills = false }
			for _, id in SHOT_ENCHANTS do
				entry.shots = entry.shots or totals[id] ~= nil
			end
			for _, id in KILL_ENCHANTS do
				entry.kills = entry.kills or totals[id] ~= nil
			end
			known[state] = entry
		end
		return entry
	end
	Feature.totals = function(state)
		return equippedOf(state).totals
	end

	-- The saved table with today's Gem Finder count: emptied when the UTC day has rolled over.
	local function today(data)
		local saved = Game.feature(data, "enchant", Enchant.SAVED)
		local day = Config.dayNumber(os.time())
		if saved.gemDay ~= day or typeof(saved.gems) ~= "number" or saved.gems ~= saved.gems then
			saved.gemDay, saved.gems = day, 0
		end
		return saved
	end

	-- Whether Gem Finder still drops gems today. It reads the save without touching it: a modifier runs often.
	local function gemsLeft(data): boolean
		local saved = data.features.enchant
		if typeof(saved) ~= "table" or saved.gemDay ~= Config.dayNumber(os.time()) then
			return true
		end
		return typeof(saved.gems) ~= "number" or saved.gems < Enchant.GemsPerDay
	end

	-- One modifier per enchantment that changes a number. Its label is the list of mini cannons behind it.
	local off = {} -- [enchantment id] = true: the core has no number of that kind (an older core)
	for _, def in Enchant.List do
		-- Bond changes two numbers: an ordinary mini cannon's own damage per second, a Huge's tower multiplier.
		for _, kind in def.kinds or { def.kind } do
			local id = def.id
			local ok = pcall(Game.modify, kind, function(_player: Player, data, state, value: number): number
				local total = equippedOf(state).totals[id]
				if not total or (id == "gemfinder" and not gemsLeft(data)) then
					return value
				end
				return Enchant.apply(id, total, value, state, kind)
			end, function(_player: Player, _data, state)
				local total = equippedOf(state).totals[id]
				if not total or not def.kinds then
					return if total then total.parts else nil
				end
				-- Only the mini cannons that changed this number: the Huges for `power`, the others for the rest.
				local parts = {}
				for _, part in total.parts do
					if part.huge == (kind == "power") then
						table.insert(parts, part)
					end
				end
				return parts
			end)
			if not ok then
				off[id] = true
			end
		end
	end
	Feature.off = off

	------------------------------------------------------------------------------------------------
	-- The enchantments that act on a shot. shot.target is the monster it is about to hit.
	------------------------------------------------------------------------------------------------
	local function usable(amount: any): boolean
		return typeof(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
	end

	Game.on("shot", function(player: Player, _data, state, shot)
		local entry = equippedOf(state)
		if not entry.shots then
			return
		end
		local target, damage = shot.target, shot.damage
		if typeof(target) ~= "table" or target.dead or not usable(damage) then
			return
		end
		local totals = entry.totals
		local now = state.clock
		-- Frostbite: the monster walks slower for a moment. The stronger slow on a monster counts (a Frost
		-- tower's is never weakened).
		local frost = totals.frostbite
		if frost and rng:NextNumber() < frost.sum and (now >= target.slowUntil or Enchant.Chill.slow >= target.slow) then
			target.slow = Enchant.Chill.slow
			target.slowUntil = now + Enchant.Chill.seconds
		end
		-- Ember: a burn, added to what is left of the one it already has (as a Flame tower's is).
		local ember = totals.ember
		if ember and rng:NextNumber() < ember.sum then
			local seconds = Enchant.Burn.seconds
			local left = target.burn * math.max(0, target.burnUntil - now)
			target.burnUntil = now + seconds
			target.burn = (left + Enchant.Burn.share * damage) / seconds
		end
		-- Chain: the shot jumps to the monster nearest along the path.
		local chain = totals.chain
		if chain and rng:NextNumber() < chain.sum then
			local nearest, gap = nil, math.huge
			for _, monster in state.monsters do
				if monster ~= target and not monster.dead and math.abs(monster.d - target.d) < gap then
					nearest, gap = monster, math.abs(monster.d - target.d)
				end
			end
			if nearest then
				Game.hurt(player, nearest, damage * Enchant.Jump.share)
			end
		end
		-- Splinter: a share of the shot on every other monster.
		local splinter = totals.splinter
		if splinter then
			local splash = damage * splinter.sum
			for _, monster in state.monsters do
				if monster ~= target and not monster.dead then
					Game.hurt(player, monster, splash)
				end
			end
		end
		-- Executioner: a shot that would leave the monster that low finishes it.
		local execute = totals.executioner
		if execute and not target.dead and target.hp - damage <= target.max * execute.sum then
			shot.damage = math.max(damage, target.hp)
		end
	end)

	------------------------------------------------------------------------------------------------
	-- The enchantments that act on a kill. Fractions are carried to the next kill.
	------------------------------------------------------------------------------------------------
	local owed = {} -- [player] = { candy, kills }

	Game.on("kill", function(player: Player, data, state, info)
		local entry = equippedOf(state)
		if not entry.kills then
			return
		end
		local totals = entry.totals
		local carry = owed[player]
		if not carry then
			carry = { candy = 0, kills = 0 }
			owed[player] = carry
		end
		-- Sweet Tooth: the core has paid the kill's candy once; this adds the enchantments' share.
		local sweet = totals.sweettooth
		if sweet and Config.halloweenActive(os.time()) then
			local base = if info.kind == "normal" then Config.Halloween.candyPerKill else Config.Halloween.candyPerBoss
			carry.candy += base * sweet.sum
			local whole = math.floor(carry.candy)
			if whole > 0 then
				carry.candy -= whole
				data.candy += whole
			end
		end
		-- Scholar: the kill counts for more towards the next Veteran level.
		local scholar = totals.scholar
		if scholar then
			carry.kills += scholar.sum
			local whole = math.floor(carry.kills)
			if whole > 0 then
				carry.kills -= whole
				data.masteryKills += whole
			end
		end
		-- Gem Finder: the `gems` modifier above made this boss drop more; count it against the day's limit.
		local gems = totals.gemfinder
		if gems and info.kind ~= "normal" and not off.gemfinder then
			local saved = today(data)
			if saved.gems < Enchant.GemsPerDay then
				saved.gems += gems.sum
				if saved.gems >= Enchant.GemsPerDay then
					Game.notify(player, `Gem Finder: all {Enchant.GemsPerDay} gems found today. More tomorrow!`, "info")
				end
			end
		end
	end)

	------------------------------------------------------------------------------------------------
	-- Paid random items: a roll costs gems, which are meant to be sold for Robux (docs/GEMS.md), and a
	-- Shiny key is. Roblox does not allow those to be sold to players in some regions and says which
	-- through PolicyService, as for the crates (Policy.luau asks and remembers).
	------------------------------------------------------------------------------------------------
	local function publish(player: Player, data)
		local saved = today(data)
		Game.setMeta(player, "enchant", { rolls = saved.rolls, restricted = Policy.restricted(player) == true })
	end

	Policy.changed:Connect(function(player: Player)
		local data = Game.data(player)
		if data then
			publish(player, data)
		end
	end)

	local function mayRoll(player: Player): boolean
		local ok, why, kind = Policy.maySell(player, "Enchanting", "offered")
		if not ok then
			Game.notify(player, why, kind)
		end
		return ok
	end

	------------------------------------------------------------------------------------------------
	-- The roll
	------------------------------------------------------------------------------------------------
	-- argument: { pet = a mini cannon id the player owns, key = a key's item id, replace = true when the
	-- player has confirmed losing the enchantments it has }. The player must have reached the table's world
	-- and be standing on its island. The price and the roll are worked out here.
	Game.actions.enchant = function(player: Player, data, state, argument: unknown)
		if typeof(argument) ~= "table" then
			return
		end
		local petId, keyId, replace = (argument :: any).pet, (argument :: any).key, (argument :: any).replace
		if typeof(petId) ~= "string" or typeof(keyId) ~= "string" then
			return
		end
		local pet, key = Config.Pets[petId], Enchant.KeyById[keyId]
		if not pet or not key or not Items.get(keyId) then
			return
		end
		if not Enchant.unlocked(data.bestCleared) then
			Game.notify(player, `Reach {world.name} to unlock enchanting`, "bad")
			return
		end
		if state.place ~= "island" or state.island ~= Enchant.ISLAND then
			Game.notify(player, `Visit the Enchanting Table on the {world.name} island`, "bad")
			return
		end
		if Game.pets.count(data, petId) < 1 then
			Game.notify(player, "You do not own that mini cannon any more", "bad")
			return
		end
		if pet.enchanted and replace ~= true then
			-- The window asks first; a request without the confirmation never replaces anything.
			Game.notify(player, `{pet.name} is enchanted already. Confirm in the ENCHANT window to replace its enchantments`, "info")
			return
		end
		if Game.items.count(data, keyId) < 1 then
			Game.notify(player, `You need {if keyId == "enchantkey" then "an" else "a"} {key.name}`, "bad")
			return
		end
		local cost = Enchant.cost(petId)
		if typeof(cost) ~= "number" or cost ~= cost or cost < 0 then
			return
		end
		if data.diamonds < cost then
			Game.notify(player, `Not enough gems to enchant {pet.name} ({cost} 💎)`, "bad")
			return
		end
		if not mayRoll(player) then
			return
		end
		local enchants = Enchant.roll(keyId, rng)
		local newId = enchants and Config.enchantedId(pet.plain, enchants)
		if not enchants or not newId or not Config.Pets[newId] then
			return
		end
		-- One of this mini cannon becomes the enchanted one, in its place: storage is never an issue.
		if not Game.pets.swap(player, { petId }, newId) then
			return
		end
		Game.items.take(player, keyId, 1)
		data.diamonds -= cost
		local saved = today(data)
		saved.rolls = (if typeof(saved.rolls) == "number" then saved.rolls else 0) + 1
		publish(player, data)
		Game.sync(player)
		-- The window shows the result; the toast says it too.
		Game.send(player, "enchant", { from = petId, pet = newId, key = keyId, enchants = enchants })
		Game.notify(player, `{Config.Pets[pet.plain].name} enchanted: {Enchant.summary(newId)}`, "good")
	end

	-- The Shiny key for Robux.
	local product = Enchant.ShinyProduct
	if product.product ~= 0 then
		Game.products[product.product] = function(player: Player): boolean
			-- A purchase that was made is always granted. Where it may not be sold the prompt is never shown
			-- (enchantBuyKey below).
			Game.items.give(player, product.key, product.amount)
			Game.notify(player, `{Enchant.KeyById[product.key].name} bought! It is in your BACKPACK`, "good")
			return true
		end
	end

	Game.actions.enchantBuyKey = function(player: Player)
		if product.product == 0 then
			Game.notify(player, `{Enchant.KeyById[product.key].name}s are not on sale yet`, "info")
		elseif mayRoll(player) then
			Game.promptProduct(player, product.product)
		end
	end

	Game.on("ready", function(player: Player, data)
		local saved = today(data)
		if typeof(saved.rolls) ~= "number" or saved.rolls ~= saved.rolls then
			saved.rolls = 0
		end
		Policy.ask(player)
		publish(player, data)
	end)

	Game.on("leave", function(player: Player)
		owed[player] = nil
	end)
end

return Feature
