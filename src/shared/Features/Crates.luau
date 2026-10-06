-- Crates: boxes that roll a loot table when they are opened. Five are always in the game (a coin crate, a free
-- daily one, a chest bosses drop, a gem crate and a Robux crate) and two belong to the Halloween event.
-- Every number is in this file: what a crate costs, how often bosses drop it, and what it can hold with each
-- chance. The server half (src/server/Features/Crates.luau) sells and opens them. The CRATES window
-- (src/client/Features/Crates.luau), opened at the crate stand in the marketplace, lists the same table the
-- server rolls on: both come from Crates.odds, so the odds shown are the real ones. Roblox requires that.
-- The opening itself is drawn by src/client/Features/CrateOpening.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)

local Crates = {}

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

Crates.MaxPerPress = 10 -- crates bought or opened by one press in the CRATES window

-- Bosses drop crates. Drops are paid for time, not kills: a player gets one drop roll every rollSeconds, so
-- parking on an easy boss does not pay. Each pool of crates is capped per UTC day on its own, and one roll
-- drops one crate of a pool at most (the rarest crate of the pool rolls first).
--   perDay   crates of that pool one player can be dropped in a UTC day
--   key      where the server keeps that day's count in the player's save
--   event    the pool only drops while the Halloween event is live
Crates.Drops = {
	rollSeconds = 10,
	pools = {
		event = { perDay = 10, key = "drops", event = true },
		boss = { perDay = 6, key = "chests" },
	},
}

-- What a crate is paid in: the key is the save's own name for it (gems are saved as diamonds), name is the
-- word on screen. Robux is not in the save: it goes through a developer product.
Crates.Currency = {
	coins = { name = "coins", icon = "💰" },
	diamonds = { name = "gems", icon = "💎" },
	candy = { name = "candy", icon = "🍬" },
	robux = { name = "Robux", icon = "R$" },
}
-- A crate bought with one of these is a "paid random item" under Roblox's rules: the server asks PolicyService
-- whether the player may buy one before it sells it. Gems are on the list because they are meant to be sold
-- for Robux (docs/GEMS.md): from that day on a gem crate is paid for with money. The list is the eggs' too.
Crates.Paid = Config.PaidCurrencies

-- The rewards that are a number of something, by the key their loot rows use.
local REWARD_CURRENCY = {
	candy = { name = "Candy", icon = "🍬", color = rgb(255, 130, 200) },
	gems = { name = "Gems", icon = "💎", color = rgb(90, 225, 255) },
	coins = { name = "Coins", icon = "💰", color = rgb(255, 205, 60) },
}

-- The crates, in the order the CRATES window lists them. rarity only colours the crate's name.
-- How a player gets one (a crate can have several):
--   price     { currency, cost }: bought in the CRATES window. currency is a key of Crates.Currency.
--               coins    cost is in clears: what clearing one ordinary level pays at the furthest level
--                        the player has cleared (Config.levelCoins, the measure pads and eggs are priced
--                        in). Coins grow 14.5% a level, so the crate costs the same effort in the first
--                        world and the last (Crates.price)
--               robux    cost is only what the button shows, and product is the developer product id from
--                        the Creator Hub: 0 means not on sale yet (as in Config.Passes)
--             perDay     at most this many can be bought in a UTC day
--             event      only sold while the Halloween event is live
--   daily     one is free every UTC day
--   drop      { pool, boss, mid, final, firstClear }: the chance (0.02 = 2%) that a boss of that wave kind
--             (Config.WaveKinds) drops it on a drop roll. pool is a key of Crates.Drops.pools.
--             firstClear: the first time a player beats each world's boss, it always drops one
--   source    for a crate without a price: how to get it, in a few words
-- instant: the crate is opened the moment it is bought or claimed and is never held, so it is not a backpack
-- item. The coin crate is one because both its price and its coins follow the player's progress: a crate
-- bought early and opened late (or handed to a friend who is further) would pay out more than it cost.
-- tradable = false keeps a crate out of trades: the paid ones, so they cannot be bought for someone who may
-- not buy them.
--
-- loot is what one crate gives, most common first. chance is per cent. The first row has none: it takes
-- whatever the others leave, so a table always adds up to 100. A row is one of:
--   candy, gems    that many
--   coins          that many clears' worth of coins, at the furthest level the player has cleared. For
--                  scale: a pad costs half a clear, an egg two and a half, and everything a player has
--                  earned so far adds up to about eight (docs/BALANCE.md)
--   pet            a mini cannon. A Secret one is listed as "???" until the player has found it
--   egg            a free hatch of the best coin egg within that same level (Crates.bestEgg), at that egg's
--                  own odds and without luck: a prize that grows with the player
--   item, amount   another feature's backpack item (a powerup, an ammo, an enchantment key), or a crate. It is looked up in the
--                  item registry when a crate is opened or its table is shown: while the item does not exist,
--                  its row is left out and the first row takes its chance
-- Everything that grows with the player is measured by the furthest level they have cleared (data.cleared,
-- the Cleared attribute), which the functions below call `best`.
-- No money machines: on average a crate pays back less of the currency it costs than it costs. The comment
-- above each crate has its average: work it out again when a table changes.
Crates.List = {
	-- Coins back: 0.57 clears on average for 1 paid (57%).
	{
		id = "woodcrate",
		name = "Wooden Crate",
		desc = "Coins, powerups and mini cannons from your best egg. Its price grows with you",
		color = rgb(176, 124, 76),
		rarity = "Common",
		instant = true,
		price = { currency = "coins", cost = 1, perDay = 30 },
		loot = {
			{ coins = 0.3 },
			{ coins = 0.75, chance = 20 },
			{ egg = true, chance = 8 },
			{ coins = 2, chance = 6 },
			{ item = "power2x", amount = 1, chance = 3 },
			{ item = "coins2x", amount = 1, chance = 3 },
			{ gems = 5, chance = 2 },
			{ item = "ammo_double", amount = 1, chance = 1.5 },
			{ coins = 6, chance = 1.5 },
			{ item = "luck2x", amount = 1, chance = 1 },
			{ pet = "crate", chance = 0.8 },
			{ item = "autotap", amount = 1, chance = 0.6 },
			{ item = "ammo_golden", amount = 1, chance = 0.5 },
			{ item = "megadamage", amount = 1, chance = 0.3 },
			{ coins = 30, chance = 0.2 },
			{ gems = 100, chance = 0.05 },
			{ pet = "mimic", chance = 0.01 }, -- 1 in 10,000
			{ pet = "fortune", chance = 0.0005 }, -- 1 in 200,000
			{ pet = "motherlode", chance = 0.00001 }, -- 1 in 10,000,000
		},
	},
	-- Free. 4.6 gems a day on average.
	{
		id = "dailycrate",
		name = "Daily Crate",
		desc = "Free every day: gems, coins, powerups, and sometimes a Boss Chest or an Enchantment Key",
		color = rgb(70, 190, 120),
		rarity = "Uncommon",
		instant = true,
		daily = true,
		source = "Free, once a day",
		loot = {
			{ coins = 1 },
			{ gems = 10, chance = 16 },
			{ coins = 3, chance = 15 },
			{ gems = 25, chance = 8 },
			{ item = "power2x", amount = 1, chance = 8 },
			{ item = "coins2x", amount = 1, chance = 8 },
			{ egg = true, chance = 6 },
			{ item = "luck2x", amount = 1, chance = 4 },
			{ item = "autotap", amount = 1, chance = 3 },
			{ item = "bosschest", amount = 1, chance = 3 },
			{ item = "enchantkey", amount = 1, chance = 3 },
			{ item = "megadamage", amount = 1, chance = 2 },
			{ item = "healfreeze", amount = 1, chance = 2 },
			{ pet = "crate", chance = 1.5 },
			{ gems = 100, chance = 0.8 },
			{ item = "supercharge", amount = 1, chance = 0.6 },
			{ pet = "treasure", chance = 0.3 },
			{ item = "ammo_flame", amount = 1, chance = 0.2 },
			{ item = "ammo_poison", amount = 1, chance = 0.2 },
			{ item = "megaluck", amount = 1, chance = 0.1 },
			{ item = "shinykey", amount = 1, chance = 0.1 },
			{ gems = 1_000, chance = 0.02 },
			{ pet = "mimic", chance = 0.01 }, -- 1 in 10,000
			{ pet = "fortune", chance = 0.001 }, -- 1 in 100,000
			{ pet = "motherlode", chance = 0.00001 }, -- 1 in 10,000,000
		},
	},
	-- Free. 1.1 gems a chest on average, 6 chests a day at most.
	{
		id = "bosschest",
		name = "Boss Chest",
		desc = "Coins that grow with you, boss-busting powerups, rare ammo and mini cannons",
		color = rgb(200, 60, 60),
		rarity = "Epic",
		drop = { pool = "boss", mid = 0.1, final = 0.5, firstClear = true },
		source = "World bosses drop it",
		loot = {
			{ coins = 1.5 },
			{ coins = 5, chance = 18 },
			{ egg = true, chance = 12 },
			{ gems = 5, chance = 8 },
			{ item = "megadamage", amount = 1, chance = 5 },
			{ item = "healfreeze", amount = 1, chance = 5 },
			{ item = "power2x", amount = 1, chance = 5 },
			{ item = "coins2x", amount = 1, chance = 5 },
			{ item = "autotap", amount = 1, chance = 4 },
			{ item = "enchantkey", amount = 1, chance = 8 },
			{ gems = 20, chance = 3 },
			{ item = "luck2x", amount = 1, chance = 3 },
			{ item = "ammo_double", amount = 1, chance = 2 },
			{ item = "ammo_golden", amount = 1, chance = 1.5 },
			{ item = "supercharge", amount = 1, chance = 1 },
			{ pet = "treasure", chance = 1 },
			{ item = "ammo_flame", amount = 1, chance = 0.5 },
			{ item = "ammo_poison", amount = 1, chance = 0.5 },
			{ item = "ammo_frost", amount = 1, chance = 0.3 },
			{ item = "ammo_lucky", amount = 1, chance = 0.3 },
			{ item = "ammo_boss", amount = 1, chance = 0.3 },
			{ item = "megaluck", amount = 1, chance = 0.2 },
			{ item = "shinykey", amount = 1, chance = 0.5 },
			{ gems = 250, chance = 0.05 },
			{ pet = "mimic", chance = 0.05 }, -- 1 in 2,000
			{ item = "ammo_void", amount = 1, chance = 0.01 },
			{ item = "ammo_rainbow", amount = 1, chance = 0.01 },
			{ pet = "fortune", chance = 0.002 }, -- 1 in 50,000
			{ pet = "motherlode", chance = 0.00002 }, -- 1 in 5,000,000
		},
	},
	-- Gems back: 25 on average for 100 paid.
	{
		id = "gemcrate",
		name = "Gem Crate",
		desc = "Rare ammo, the strongest powerups, Exclusive mini cannons and four Secret jackpots",
		color = rgb(80, 220, 255),
		rarity = "Legendary",
		tradable = false,
		price = { currency = "diamonds", cost = 100 },
		loot = {
			{ gems = 30 },
			{ gems = 60, chance = 12 },
			{ item = "megadamage", amount = 2, chance = 6 },
			{ item = "healfreeze", amount = 2, chance = 6 },
			{ item = "supercharge", amount = 1, chance = 6 },
			{ item = "autotap", amount = 2, chance = 5 },
			{ item = "luck2x", amount = 2, chance = 5 },
			{ item = "enchantkey", amount = 2, chance = 5 },
			{ gems = 150, chance = 4 },
			{ pet = "neon", chance = 4 },
			{ item = "megaluck", amount = 1, chance = 3 },
			{ pet = "treasure", chance = 3 },
			{ item = "ammo_flame", amount = 1, chance = 2 },
			{ item = "ammo_poison", amount = 1, chance = 2 },
			{ pet = "royalguard", chance = 1.5 },
			{ item = "ammo_frost", amount = 1, chance = 1 },
			{ item = "ammo_lucky", amount = 1, chance = 1 },
			{ item = "ammo_boss", amount = 1, chance = 1 },
			{ item = "shinykey", amount = 1, chance = 1 },
			{ pet = "mecha", chance = 0.6 },
			{ gems = 600, chance = 0.4 },
			{ pet = "vault", chance = 0.4 },
			{ pet = "dragon", chance = 0.25 },
			{ pet = "mimic", chance = 0.2 }, -- 1 in 500
			{ item = "ammo_void", amount = 1, chance = 0.1 },
			{ item = "ammo_rainbow", amount = 1, chance = 0.1 },
			{ pet = "fortune", chance = 0.02 }, -- 1 in 5,000
			{ gems = 5_000, chance = 0.01 },
			{ pet = "jackpot", chance = 0.001 }, -- 1 in 100,000
			{ pet = "motherlode", chance = 0.00001 }, -- 1 in 10,000,000
		},
	},
	-- The best odds in the game. 156 gems on average. Nothing in it changes hatching luck: luck sold for Robux
	-- is a "probability modifier" under Roblox's rules (docs/GEMS.md).
	{
		id = "royalcrate",
		name = "Royal Crate",
		desc = "The best odds in the game: every Secret jackpot, Exclusive mini cannons, Legendary ammo",
		color = rgb(250, 195, 50),
		rarity = "Exclusive",
		tradable = false,
		price = { currency = "robux", cost = 99, product = 0 },
		loot = {
			{ gems = 150 },
			{ gems = 400, chance = 15 },
			{ item = "supercharge", amount = 3, chance = 10 },
			{ item = "shinykey", amount = 1, chance = 8 },
			{ item = "megadamage", amount = 5, chance = 7 },
			{ item = "healfreeze", amount = 5, chance = 7 },
			{ pet = "treasure", chance = 6 },
			{ item = "autotap", amount = 5, chance = 6 },
			{ pet = "mecha", chance = 5 },
			{ pet = "vault", chance = 5 },
			{ gems = 1_200, chance = 4 },
			{ pet = "dragon", chance = 4 },
			{ item = "ammo_frost", amount = 1, chance = 3 },
			{ item = "ammo_lucky", amount = 1, chance = 3 },
			{ item = "ammo_boss", amount = 1, chance = 3 },
			{ pet = "mimic", chance = 2 }, -- 1 in 50
			{ item = "ammo_void", amount = 1, chance = 1 },
			{ item = "ammo_rainbow", amount = 1, chance = 1 },
			{ gems = 6_000, chance = 0.5 },
			{ pet = "fortune", chance = 0.5 }, -- 1 in 200
			{ pet = "jackpot", chance = 0.05 }, -- 1 in 2,000
			{ gems = 50_000, chance = 0.01 },
			{ pet = "motherlode", chance = 0.0001 }, -- 1 in 1,000,000
		},
	},
	-- Candy back: 46 on average for 250 paid.
	{
		id = "pumpkincrate",
		name = "Pumpkin Crate",
		desc = "Candy, coins, powerups, Halloween mini cannons and three Secret jackpots",
		color = rgb(255, 130, 30),
		rarity = "Rare",
		price = { currency = "candy", cost = 250, event = true },
		drop = { pool = "event", boss = 0.02, mid = 0.06, final = 0.15 },
		loot = {
			{ candy = 60 },
			{ coins = 0.75, chance = 25 },
			{ candy = 200, chance = 10 },
			{ item = "power2x", amount = 1, chance = 5 },
			{ item = "coins2x", amount = 1, chance = 5 },
			{ item = "candy2x", amount = 1, chance = 3 },
			{ item = "enchantkey", amount = 1, chance = 3 },
			{ gems = 10, chance = 3 },
			{ item = "luck2x", amount = 1, chance = 1.5 },
			{ pet = "candycorn", chance = 1.5 },
			{ item = "ammo_double", amount = 1, chance = 1 },
			{ item = "autotap", amount = 1, chance = 0.5 },
			{ item = "ammo_candy", amount = 1, chance = 0.5 },
			{ pet = "cauldron", chance = 0.4 },
			{ pet = "pumpkinking", chance = 0.08 },
			{ item = "shinykey", amount = 1, chance = 0.05 },
			{ gems = 250, chance = 0.02 },
			{ pet = "candyskull", chance = 0.01 }, -- 1 in 10,000
			{ pet = "bonedragon", chance = 0.0001 }, -- 1 in 1,000,000
			{ pet = "witchinghour", chance = 0.00001 }, -- 1 in 10,000,000
		},
	},
	-- Candy back: 308 on average for 2,000 paid.
	{
		id = "cursedcrate",
		name = "Cursed Crate",
		desc = "Bigger prizes, and every Secret jackpot is 10 times as likely",
		color = rgb(120, 50, 180),
		rarity = "Epic",
		price = { currency = "candy", cost = 2_000, event = true },
		drop = { pool = "event", mid = 0.01, final = 0.04 },
		loot = {
			{ candy = 500 },
			{ coins = 4, chance = 20 },
			{ candy = 1_500, chance = 8 },
			{ item = "megadamage", amount = 1, chance = 6 },
			{ item = "healfreeze", amount = 1, chance = 6 },
			{ item = "autotap", amount = 1, chance = 5 },
			{ item = "luck2x", amount = 2, chance = 5 },
			{ item = "enchantkey", amount = 2, chance = 5 },
			{ gems = 50, chance = 4 },
			{ pet = "cauldron", chance = 3 },
			{ item = "ammo_candy", amount = 1, chance = 2 },
			{ item = "ammo_flame", amount = 1, chance = 1 },
			{ item = "ammo_poison", amount = 1, chance = 1 },
			{ pet = "pumpkinking", chance = 1 },
			{ item = "megaluck", amount = 1, chance = 0.25 },
			{ item = "shinykey", amount = 1, chance = 0.5 },
			{ pet = "candyskull", chance = 0.1 }, -- 1 in 1,000
			{ item = "ammo_lucky", amount = 1, chance = 0.05 },
			{ gems = 1_000, chance = 0.03 },
			{ item = "ammo_rainbow", amount = 1, chance = 0.01 },
			{ pet = "bonedragon", chance = 0.001 }, -- 1 in 100,000
			{ pet = "witchinghour", chance = 0.0001 }, -- 1 in 1,000,000
		},
	},
}

-- Every crate can be found by its id. The ones a player holds are backpack items, in list order.
-- (The Story feature hands out the most common item of the "crate" category during the event: that is the
-- Pumpkin Crate for as long as no crate that is an item has a rarity below Rare.)
local ROW_KINDS = { "candy", "gems", "coins", "pet", "egg", "item" }
Crates.ById = {}
for order, crate in Crates.List do
	local taken = 0
	for index, row in crate.loot do
		local kinds = 0
		for _, kind in ROW_KINDS do
			kinds += if row[kind] ~= nil then 1 else 0
		end
		assert(kinds == 1, `crate {crate.id}: row {index} must give exactly one thing`)
		assert((index == 1) == (row.chance == nil), `crate {crate.id}: only the first row has no chance`)
		assert(not row.pet or Config.Pets[row.pet], `crate {crate.id} holds unknown mini cannon {row.pet}`)
		assert(not row.item or row.amount, `crate {crate.id}: row {index} needs an amount`)
		taken += row.chance or 0
	end
	assert(taken < 100, `crate {crate.id}: the chances pass 100`)
	local price, drop = crate.price, crate.drop
	assert(not price or Crates.Currency[price.currency], `crate {crate.id}: unknown currency`)
	assert(not drop or Crates.Drops.pools[drop.pool], `crate {crate.id}: unknown drop pool`)
	assert(price or crate.source, `crate {crate.id} needs a price or a source`)
	Crates.ById[crate.id] = crate
	if not crate.instant then
		Items.define(crate.id, {
			name = crate.name,
			desc = crate.desc,
			category = "crate",
			color = crate.color,
			rarity = crate.rarity,
			usable = true,
			tradable = crate.tradable ~= false,
			order = order,
		})
	end
end

-- A crate's loot as it stands right now: { { row, chance } } in table order, the chances adding up to 100.
function Crates.odds(crate): { { row: any, chance: number } }
	local odds, taken = {}, 0
	for _, row in crate.loot do
		if not row.item or Items.get(row.item) then
			table.insert(odds, { row = row, chance = row.chance or 0 })
			taken += row.chance or 0
		end
	end
	odds[1].chance = 100 - taken
	return odds
end

-- roll is a random number in [0, 1). Returns the row it lands on and the chance that row had.
-- Rarest first, like Config.rollEgg: the jackpots sit at the low end of the roll, where a number is at its
-- most exact, and if rounding leaves the chances a hair short of 100 the roll lands on the first row.
function Crates.roll(crate, roll: number): (any, number)
	local odds = Crates.odds(crate)
	local remaining = roll * 100
	local picked = odds[1]
	for index = #odds, 1, -1 do
		local entry = odds[index]
		if entry.chance > 0 then
			picked = entry
			remaining -= entry.chance
			if remaining < 0 then
				break
			end
		end
	end
	return picked.row, picked.chance
end

-- What `clears` clears of an ordinary level pay a player whose furthest cleared level is `best`, before
-- their coin multiplier. Config.levelCoins is the plain curve: a boss level or a world's twist does not move
-- it. Whole coins, and never nothing.
local function clearsWorth(clears: number, best: number): number
	return math.max(1, math.floor(clears * Config.levelCoins(math.max(1, best))))
end

-- What a coins row pays a player whose furthest cleared level is `best`.
function Crates.coins(row, best: number): number
	return clearsWorth(row.coins, best)
end

-- What one crate costs that player, in its price's currency: nil for a crate that is not sold.
function Crates.price(crate, best: number): number?
	local price = crate.price
	if not price then
		return nil
	elseif price.currency == "coins" then
		return clearsWorth(price.cost, best)
	end
	return price.cost
end

-- How a player gets the crate, in a few words: "250 🍬", "Free, once a day". Without `best` a coin price,
-- which is different for every player, is only described.
function Crates.sourceText(crate, best: number?): string
	local price = crate.price
	if not price then
		return crate.source
	end
	local icon = Crates.Currency[price.currency].icon
	if price.currency == "coins" and not best then
		return `{icon} price grows with you`
	end
	return `{Format.abbreviate(Crates.price(crate, best or 0) :: number)} {icon}`
end

-- The egg an egg row hatches for that player: the last coin egg that level unlocks. Never an event egg.
function Crates.bestEgg(best: number)
	local found = nil
	for _, egg in Config.Eggs do
		if egg.currency == "coins" and not egg.event and egg.unlock <= best and (not found or egg.unlock > found.unlock) then
			found = egg
		end
	end
	return found or Config.Eggs[1]
end

-- What a row gives that player, as the server sends it and the client draws it: { kind, amount, id }.
-- kind is candy, gems, coins, pet (id is the mini cannon), item (id is the item) or egg (id is the egg: the
-- server turns it into the pet that hatched).
function Crates.reward(row, best: number): { kind: string, amount: number, id: string? }
	if row.candy then
		return { kind = "candy", amount = row.candy }
	elseif row.gems then
		return { kind = "gems", amount = row.gems }
	elseif row.coins then
		return { kind = "coins", amount = Crates.coins(row, best) }
	elseif row.pet then
		return { kind = "pet", amount = 1, id = row.pet }
	elseif row.egg then
		return { kind = "egg", amount = 1, id = Crates.bestEgg(best).id }
	end
	return { kind = "item", amount = row.amount, id = row.item }
end

-- How a reward looks: { name, detail, color, rarity, icon, secret }. rarity is a key of Config.RarityColors
-- or nil, icon an emoji or nil, and secret is true for a mini cannon that stays "???" until it is found.
-- Nothing in a reward is trusted to exist: an id this build does not know still gets a name.
function Crates.view(reward): { name: string, detail: string, color: Color3, rarity: string?, icon: string?, secret: boolean? }
	local currency = REWARD_CURRENCY[reward.kind]
	if currency then
		return { name = currency.name, detail = `+{Format.abbreviate(reward.amount)}`, color = currency.color, icon = currency.icon }
	elseif reward.kind == "pet" then
		local pet = Config.Pets[reward.id]
		if pet then
			-- "+129 DPS"; a Huge multiplies tower damage instead.
			local power = if pet.huge then `{Format.petPower(pet)} tower damage` else Format.petPower(pet)
			return { name = pet.name, detail = power, color = pet.color, rarity = pet.rarity, secret = pet.hidden == true }
		end
	elseif reward.kind == "egg" then
		local egg = Config.EggById[reward.id]
		if egg then
			return { name = "Mini cannon from your best egg", detail = egg.name, color = egg.color, icon = "🥚" }
		end
	elseif reward.kind == "item" then
		local item = Items.get(reward.id)
		if item then
			return { name = item.name, detail = `x{reward.amount}`, color = item.color or WHITE, rarity = item.rarity }
		end
	end
	return { name = tostring(reward.id or reward.kind), detail = "", color = WHITE }
end

-- What a row gives, in a few words: "+60 Candy", "2x Luck x2", "Mini Cauldron Cannon". best is as in Crates.coins.
function Crates.rewardText(row, best: number): string
	local reward = Crates.reward(row, best)
	local view = Crates.view(reward)
	if REWARD_CURRENCY[reward.kind] then
		return `{view.detail} {view.name}`
	elseif reward.kind == "egg" then
		return `{view.name} ({view.detail})`
	elseif reward.kind == "item" and reward.amount > 1 then
		return `{view.name} {view.detail}`
	end
	return view.name
end

return Crates
