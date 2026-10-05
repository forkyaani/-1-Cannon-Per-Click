-- Crates on the server: selling them (coins, gems, candy, Robux), the free daily one, boss drops, opening
-- them, and the crate stand in the marketplace. The prices, drop rates and loot tables are in
-- src/shared/Features/Crates.luau.
-- An opening is answered with one message on the "crates" channel, which the client turns into the opening
-- animation (src/client/Features/CrateOpening.luau):
--   { crate = id, rewards = { { kind, amount, id, rarity, chance, kept } } }    one reward per crate opened
--   kind     candy, gems, coins (amount is how many), pet (id is the mini cannon) or item (id, amount)
--   rarity   the mini cannon's or the item's, when it has one
--   chance   the per cent chance that reward had
--   kept     mini cannons only: false when storage was full and it was released
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Shared = require(ReplicatedStorage.Shared.Features.Crates)
local Build = require(script.Parent.Parent.Build)
local Marketplace = require(script.Parent.Parent.Marketplace)
local Huge = require(script.Parent.Huge)

local Crates = {}

local rgb = Color3.fromRGB
local Drops = Shared.Drops
-- This feature's part of the save.
local DEFAULTS = {
	dropDay = 0, -- the UTC day the two drop counts are for
	drops = 0, -- Halloween crates bosses have dropped that day
	chests = 0, -- Boss Chests bosses have dropped that day
	chestWorld = 0, -- the last world whose boss has given its first-clear crate
	claimDay = 0, -- the UTC day the free daily crate was last claimed
	buyDay = 0, -- the UTC day `bought` counts
	bought = {}, -- [crate id] = how many of a crate with a daily limit were bought that day
}
local HOW_TO_OPEN = "Open it in your BACKPACK"
local STAND_CRATE = 2.4 -- the side of a crate on the stand, in studs
local STAND_GAP = 0.3

local function plural(count: number, name: string): string
	return if count == 1 then name else `{count} {name}s`
end

-- What a buy or open request names: the crate and how many (1 to MaxPerPress). The crate is nil if the
-- client sent anything else.
local function request(argument: any)
	if typeof(argument) ~= "table" or typeof(argument.id) ~= "string" then
		return nil, 0
	end
	local count = argument.count
	if typeof(count) ~= "number" or count ~= count then
		return nil, 0
	end
	return Shared.ById[argument.id], math.clamp(math.floor(count), 1, Shared.MaxPerPress)
end

----------------------------------------------------------------------------------------------------
-- The stand: every crate a player can get right now, stacked on a rug under a board that says how each one
-- is got. Its prompt opens the CRATES window. It stays small: the Huge showcase is its neighbour.
----------------------------------------------------------------------------------------------------
local function buildStand()
	local folder = Marketplace.container()
	local spot = Marketplace.frame(-24, 0, -32).Position
	local middle = Marketplace.frame(0, 0, 0).Position
	-- Floor level, with -Z facing the statue in the middle of the square: where the customers come from.
	local frame = CFrame.lookAt(spot, Vector3.new(middle.X, spot.Y, middle.Z))
	local wood, dark = rgb(120, 84, 56), rgb(44, 46, 54)
	local eventLive = Config.halloweenActive(os.time())

	local shown = {}
	for _, crate in Shared.List do
		if eventLive or not (crate.price and crate.price.event) then
			table.insert(shown, crate)
		end
	end

	Build.pillar(frame, 6, 0.2, { Name = "CrateRug", Color = rgb(70, 40, 90), Material = Enum.Material.Fabric, Parent = folder })
	-- Two rows: the first half on the rug, the rest on top of them.
	local below = math.ceil(#shown / 2)
	local lines = {}
	for index, crate in shown do
		local top = index > below
		local inRow = if top then #shown - below else below
		local place = if top then index - below else index
		local x = (place - (inRow + 1) / 2) * (STAND_CRATE + STAND_GAP)
		local y = 0.2 + STAND_CRATE / 2 + (if top then STAND_CRATE else 0)
		-- Each turned a little so they do not look stacked by a machine.
		local turn = math.rad(if index % 2 == 0 then 7 else -6)
		local cframe = frame * CFrame.new(x, y, 0.4) * CFrame.Angles(0, turn, 0)
		local box = Build.part({
			Name = "Crate_" .. crate.id,
			Size = Vector3.one * STAND_CRATE,
			CFrame = cframe,
			Color = crate.color,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		for _, height in { -0.36, 0.36 } do
			Build.part({
				Name = "CrateBand",
				Size = Vector3.new(STAND_CRATE + 0.15, STAND_CRATE * 0.14, STAND_CRATE + 0.15),
				CFrame = cframe * CFrame.new(0, height * STAND_CRATE, 0),
				Color = crate.color:Lerp(Color3.new(0, 0, 0), 0.6),
				Material = Enum.Material.Metal,
				Parent = folder,
			})
		end
		Build.label(Build.surface(box, Enum.NormalId.Front), "?")
		if index == 1 then
			local glow = Instance.new("PointLight")
			glow.Range = 16
			glow.Brightness = 1.2
			glow.Color = Color3.fromRGB(255, 220, 150)
			glow.Parent = box
		end
		table.insert(lines, `<font color="#{crate.color:ToHex()}">{crate.name}</font>  •  {Shared.sourceText(crate)}`)
	end

	for _, side in { -1, 1 } do
		Build.part({
			Name = "CrateSignPost",
			Size = Vector3.new(0.5, 12, 0.5),
			CFrame = frame * CFrame.new(side * 4.6, 6, 2.6),
			Color = wood,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
	end
	local board = Build.part({
		Name = "CrateSign",
		Size = Vector3.new(8.7, 1.9, 0.4),
		CFrame = frame * CFrame.new(0, 11, 2.6),
		Color = dark,
		Parent = folder,
	})
	Build.label(Build.surface(board, Enum.NormalId.Front), "📦 CRATES")
	local list = Build.part({
		Name = "CratePrices",
		Size = Vector3.new(8.7, 4.6, 0.4),
		CFrame = frame * CFrame.new(0, 7.6, 2.6),
		Color = dark,
		Parent = folder,
	})
	local listGui = Build.surface(list, Enum.NormalId.Front)
	listGui.PixelsPerStud = 50 -- seven lines of small text need a finer canvas than a one-word sign
	Build.label(listGui, table.concat(lines, "\n")).RichText = true
	if eventLive then
		Build.pumpkin(frame * CFrame.new(-4.4, 0.85, -3), 1.5, folder)
	end

	-- The prompt hangs in front of the stack at hand height, on a part nobody can see or bump into.
	local handle = Build.part({
		Name = "CratePrompt",
		Size = Vector3.one,
		CFrame = frame * CFrame.new(0, 2.6, -1.2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	Build.prompt(handle, "Open", "Crates"):SetAttribute("Window", "CRATES")
end

----------------------------------------------------------------------------------------------------
function Crates.start(Game)
	local rng = Game.random

	-- The saved table, with the day's counters back at 0 once the UTC day has rolled over. Also returns the day.
	local function today(data)
		local save = Game.feature(data, "crates", DEFAULTS)
		local day = Config.dayNumber(os.time())
		if save.dropDay ~= day then
			save.dropDay = day
			for _, pool in Drops.pools do
				save[pool.key] = 0
			end
		end
		if save.buyDay ~= day then
			save.buyDay, save.bought = day, {}
		end
		return save, day
	end

	------------------------------------------------------------------------------------------------
	-- Paid random items. Roblox does not allow them to be sold to players in some regions, and says which
	-- through PolicyService. The answer is asked for when a player joins and remembered while they stay.
	------------------------------------------------------------------------------------------------
	local restricted = {} -- [player] = whether they may not buy paid random items; nil until Roblox has answered
	local asking = {} -- [player] = true while the question is on its way

	-- What the CRATES window needs to know about its player.
	local function publish(player: Player, data)
		local save = today(data)
		Game.setMeta(player, "crates", {
			claimDay = save.claimDay,
			buyDay = save.buyDay,
			bought = save.bought,
			restricted = restricted[player] == true,
		})
	end

	local function askPolicy(player: Player)
		if asking[player] then
			return
		end
		asking[player] = true
		task.spawn(function()
			local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
			asking[player] = nil
			if not player.Parent then
				return
			end
			if ok and typeof(info) == "table" then
				restricted[player] = info.ArePaidRandomItemsRestricted == true
			elseif RunService:IsStudio() then
				-- Only a play test may go on without an answer. In a live game no answer means no sale.
				restricted[player] = false
			else
				warn(`[Crates] policy lookup failed for {player.Name}: {info}`)
				return
			end
			local data = Game.data(player)
			if data then
				publish(player, data)
			end
		end)
	end

	-- Whether the crate may be sold to the player. Says why when it may not.
	local function maySell(player: Player, crate): boolean
		if not Shared.Paid[crate.price.currency] or restricted[player] == false then
			return true
		end
		if restricted[player] then
			Game.notify(player, `The {crate.name} cannot be sold in your region`, "bad")
		else
			-- No answer yet, or the lookup failed: ask again rather than guess.
			askPolicy(player)
			Game.notify(player, `Still checking whether the {crate.name} can be sold in your region. Try again in a moment`, "info")
		end
		return false
	end

	------------------------------------------------------------------------------------------------
	-- Opening
	------------------------------------------------------------------------------------------------
	-- Two draws make one roll, fine enough for a 1 in 10,000,000 jackpot (as hatchOne does in Game.luau).
	local function bigRoll(): number
		return (rng:NextInteger(0, 9_999) + rng:NextNumber()) / 10_000
	end

	-- Opens `count` crates the player has already paid for or handed over, and sends their client what came
	-- out. There is no toast: the opening animation shows the same thing.
	local function open(player: Player, data, crate, count: number)
		local totals = { candy = 0, coins = 0, gems = 0 }
		local rewards = {} -- in the order they came out
		for _ = 1, count do
			local row, chance = Shared.roll(crate, bigRoll())
			local reward: any = Shared.reward(row, data.cleared)
			reward.chance = chance
			if totals[reward.kind] then
				totals[reward.kind] += reward.amount
			elseif reward.kind == "item" then
				local item = Items.get(reward.id)
				reward.rarity = item and item.rarity
				Game.items.give(player, reward.id, reward.amount)
			else
				if reward.kind == "egg" then
					-- A free hatch, at the egg's own odds and without luck. The chance of what hatched is the
					-- row's chance times the egg's.
					local petId, petChance = Config.rollEgg(Config.EggById[reward.id], bigRoll())
					reward.kind, reward.id, reward.chance = "pet", petId, chance * petChance / 100
				end
				local pet = Config.Pets[reward.id]
				reward.rarity = pet.rarity
				-- A crate's own mini cannon is always kept: in a full storage it takes the place of the weakest
				-- one. What hatches from an egg row is kept the way an egg's is: only a Secret or a Huge is forced in.
				reward.kept = Game.pets.add(player, reward.id, row.pet ~= nil or pet.hidden == true)
				Huge.discover(player, reward.id)
				if pet.hidden then
					local what = if pet.huge then string.upper(pet.name) else `SECRET {pet.name}`
					local found = `{player.DisplayName} found a {what} in a {crate.name}!`
					Game.announce(`{found} ({Config.oneIn(reward.chance)})`, "good")
				end
			end
			table.insert(rewards, reward)
		end
		data.candy += totals.candy
		data.coins += totals.coins
		data.diamonds += totals.gems
		Game.send(player, "crates", { crate = crate.id, rewards = rewards })
	end

	-- USE in the backpack opens one. The core takes the crate when this returns true.
	Game.onUse("crate", function(player: Player, data, _state, def): boolean
		local crate = Shared.ById[def.id]
		if not crate then
			return false
		end
		open(player, data, crate, 1)
		return true
	end)

	-- The CRATES window: argument is { id, count }.
	Game.actions.openCrates = function(player: Player, data, _state, argument: unknown)
		local crate, count = request(argument)
		if not crate or crate.instant then
			return
		end
		count = math.min(count, Game.items.count(data, crate.id))
		if count < 1 then
			Game.notify(player, `You have no {crate.name}`, "bad")
		elseif Game.items.take(player, crate.id, count) then
			open(player, data, crate, count)
		end
	end

	------------------------------------------------------------------------------------------------
	-- Buying: argument is { id, count }. The free daily crate is claimed through here too.
	------------------------------------------------------------------------------------------------
	Game.actions.buyCrates = function(player: Player, data, _state, argument: unknown)
		local crate, count = request(argument)
		if not crate then
			return
		end
		local save, day = today(data)
		if crate.daily then
			if save.claimDay == day then
				Game.notify(player, `You have had today's {crate.name}. The next one is ready at midnight UTC`, "bad")
				return
			end
			save.claimDay = day
			publish(player, data)
			open(player, data, crate, 1)
			return
		end
		local price = crate.price
		if not price then
			Game.notify(player, `The {crate.name} is not for sale: {string.lower(crate.source)}`, "info")
			return
		end
		if price.event and not Config.halloweenActive(os.time()) then
			Game.notify(player, "The Halloween event has ended", "bad")
			return
		end
		if not maySell(player, crate) then
			return
		end
		if price.currency == "robux" then
			-- Roblox takes the payment; the crate arrives through Game.products below.
			if price.product == 0 then
				Game.notify(player, `The {crate.name} is not on sale yet`, "info")
			else
				Game.promptProduct(player, price.product)
			end
			return
		end
		if price.perDay then
			local left = price.perDay - (save.bought[crate.id] or 0)
			if left < 1 then
				Game.notify(player, `No {crate.name}s left today. New stock at midnight UTC`, "bad")
				return
			end
			count = math.min(count, left)
		end
		local cost = (Shared.price(crate, data.cleared) :: number) * count
		if data[price.currency] < cost then
			Game.notify(player, `Not enough {Shared.Currency[price.currency].name} for {plural(count, crate.name)}`, "bad")
			return
		end
		data[price.currency] -= cost
		if price.perDay then
			save.bought[crate.id] = (save.bought[crate.id] or 0) + count
			publish(player, data)
		end
		if crate.instant then
			open(player, data, crate, count)
		else
			Game.items.give(player, crate.id, count)
			Game.notify(player, `Bought {plural(count, crate.name)}!`, "good")
		end
	end

	-- Robux crates: one developer product gives one crate.
	for _, crate in Shared.List do
		local price = crate.price
		if price and price.currency == "robux" and price.product ~= 0 then
			Game.products[price.product] = function(player: Player): boolean
				-- buyCrates only prompts a player who may buy, but a client can open the prompt by itself:
				-- nothing is handed over unless Roblox has said this player may buy paid random items. The
				-- receipt stays unprocessed, so Roblox asks again later and refunds what is never granted.
				if restricted[player] ~= false then
					askPolicy(player)
					return false
				end
				if not Game.items.give(player, crate.id, 1) then
					return false
				end
				Game.notify(player, `{crate.name} bought! Open it at the crate stand or in your BACKPACK`, "good")
				return true
			end
		end
	end

	------------------------------------------------------------------------------------------------
	-- Boss drops. Runs for every kill, up to 50 times in one shot, so the common case does next to nothing.
	------------------------------------------------------------------------------------------------
	local nextRoll = {} -- [player] = the os.clock() from which they get their next drop roll
	Game.on("kill", function(player: Player, data, state, info)
		if info.kind == "normal" then
			return
		end
		local now = os.clock()
		if now < (nextRoll[player] or 0) then
			return
		end
		nextRoll[player] = now + Drops.rollSeconds
		local save = today(data)
		local eventLive = Config.halloweenActive(os.time())
		local boost = Game.value(player, "crateDrops") -- the `crateDrops` modifiers: a Huge, an enchant
		local dropped = {} -- [pool] = true once it has dropped its one crate of this roll
		-- The rarest crate rolls first.
		for index = #Shared.List, 1, -1 do
			local crate = Shared.List[index]
			local drop = crate.drop
			local chance = drop and drop[info.kind]
			local pool = drop and Drops.pools[drop.pool]
			if chance and not dropped[drop.pool] and (eventLive or not pool.event) and save[pool.key] < pool.perDay then
				if rng:NextNumber() < chance * boost then
					dropped[drop.pool] = true
					save[pool.key] += 1
					Game.items.give(player, crate.id, 1)
					Game.notify(player, `{Config.monsterFor(info.wave).name} dropped a {crate.name}! {HOW_TO_OPEN}`, "good")
				end
			end
		end
	end)

	-- The first time a player beats a world's boss, it always leaves a crate: once per world, ever.
	Game.on("waveCleared", function(player: Player, data, _state, wave: number)
		if Config.waveKind(wave) ~= "final" then
			return
		end
		local world = Config.worldOf(wave)
		local save = today(data)
		if world <= save.chestWorld then
			return
		end
		save.chestWorld = world
		for _, crate in Shared.List do
			if crate.drop and crate.drop.firstClear then
				Game.items.give(player, crate.id, 1)
				Game.notify(player, `{Config.Worlds[world].name} is beaten, and its boss left a {crate.name}! {HOW_TO_OPEN}`, "good")
			end
		end
	end)

	Game.on("ready", function(player: Player, data)
		publish(player, data)
		askPolicy(player)
	end)

	Game.on("leave", function(player: Player)
		nextRoll[player] = nil
		restricted[player] = nil
	end)

	buildStand()
end

return Crates
