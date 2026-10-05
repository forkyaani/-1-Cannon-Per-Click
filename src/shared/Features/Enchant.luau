-- Enchanting: random perks rolled onto a mini cannon at the enchanting table on The Sun's island
-- (docs/BUILD_QUEUE.md, section 4). Every number of it is in this file: the twenty enchantments and what each
-- level gives, what a roll costs, and the odds of every roll. The server half
-- (src/server/Features/Enchant.luau) rolls and applies from these functions and the ENCHANT window
-- (src/client/Features/Enchant.luau) lists from them, so the window can never show a price, an effect or a
-- chance the server would not give. Roblox requires the odds of a paid random item to be shown: Enchant.odds
-- is what the window prints and Enchant.roll is what the server rolls, and both read the same tables.
--
-- How an enchanted mini cannon is kept: its id carries its enchantments ("wooden_gold~greed1.sharp3"), and
-- Config.Pets resolves such an id (see "Enchanted mini cannons" in Config.luau). Only equipped mini cannons
-- count, and the same enchantment on several of them adds up, with no cap of its own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

local Enchant = {}

Enchant.WINDOW = "ENCHANT"
Enchant.ISLAND = Config.EnchantIsland -- the world whose island has the table; enchanting opens when it is reached
Enchant.MAX = Config.MaxEnchants -- enchantments on one mini cannon
Enchant.LEVELS = Config.MaxEnchantLevel
Enchant.SAVED = { rolls = 0, gemDay = 0, gems = 0 } -- data.features.enchant: rolls made; Gem Finder's day and its gems

local rgb = Color3.fromRGB

----------------------------------------------------------------------------------------------------
-- The keys: backpack items. One use of the table takes one key and the gems below.
--   count    how many enchantments a roll gives, as weights: { [count] = weight }
--   levels   the level of each enchantment, as weights: { I, II, III }
--   top      this many of the enchantments are always level III; `levels` is rolled for the others only
----------------------------------------------------------------------------------------------------
Enchant.Keys = {
	{
		id = "enchantkey",
		name = "Enchantment Key",
		desc = "Enchants a mini cannon at the table on The Sun's island: 1 to 3 enchantments, each level I to III",
		color = rgb(190, 110, 255),
		rarity = "Rare",
		count = { 50, 35, 15 },
		levels = { 60, 30, 10 },
		top = 0,
	},
	{
		id = "shinykey",
		name = "Shiny Enchantment Key",
		desc = "Enchants a mini cannon with 3 enchantments, at least two of them level III",
		color = rgb(255, 225, 120),
		rarity = "Legendary",
		count = { 0, 0, 100 },
		levels = { 40, 35, 25 },
		top = 2,
	},
}
Enchant.KeyById = {}
for order, key in Enchant.Keys do
	Enchant.KeyById[key.id] = key
	if not Items.get(key.id) then
		Items.define(key.id, {
			name = key.name,
			desc = key.desc,
			category = "keys", -- the backpack heads a category it does not know with its own name
			color = key.color,
			rarity = key.rarity,
			usable = false, -- used at the table, not from the backpack
			tradable = true,
			order = order,
		})
	end
end

-- The Shiny Enchantment Key for Robux. product is the developer product id from the Creator Hub: 0 means not
-- on sale yet (as in Config.Passes). price is only what the button shows.
Enchant.ShinyProduct = { key = "shinykey", amount = 1, product = 0, price = 149 }

-- What one use costs in gems, by the mini cannon's rarity. A fused one costs what the one it was fused from
-- costs.
Enchant.Gems = {
	Common = 10,
	Uncommon = 15,
	Rare = 25,
	Epic = 40,
	Legendary = 60,
	Exclusive = 80,
	Secret = 120,
	Mythical = 150, -- a Huge
}
Enchant.RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Exclusive", "Secret", "Mythical" }

----------------------------------------------------------------------------------------------------
-- The enchantments, in the window's order. Every one is as likely as any other.
--   amounts   what levels I, II and III give (0.05 = 5%; a count for `add`)
--   how       what the server does with the amounts of all equipped mini cannons added up:
--               "more"  multiplies the number of `kind` (a Game.modify kind) by 1 + the sum
--               "less"  multiplies it by (1 - amount) once per enchantment: it can never reach nothing
--               "add"   adds the sum to it
--               "bond"  that mini cannon's own damage per second grows by the amount (a Huge's multiplier on
--                       tower damage instead: the part over x1)
--               "hook"  no number of the game to change: the server applies it to shots and kills by name
--                       (see the hooks in src/server/Features/Enchant.luau)
--   kind      the number it changes, so the STATS window lists it as a source
--   kinds     for one that changes two numbers (Bond: `petDps` for an ordinary mini cannon, `power` for a Huge)
--   text      how the effect reads; %s is the amount
--   unit      "count" writes the amount as it is; everything else is a percentage
-- The sizes are small on purpose: nine enchantment slots (three mini cannons) of one kind at level III are
-- +135% tower damage: about six levels' worth of monster health (docs/BALANCE.md, section 5d).
----------------------------------------------------------------------------------------------------
-- A number as text: a whole one without decimals, anything else with up to two.
local function number(amount: number): string
	local rounded = math.floor(amount * 100 + 0.5) / 100
	if rounded % 1 == 0 then
		return string.format("%d", rounded)
	end
	return (string.gsub(string.format("%.2f", rounded), "0+$", ""))
end

local function percent(share: number): string
	return number(share * 100)
end

-- What the shot enchantments do once they trigger: fixed, so stacking only makes them trigger more often.
Enchant.Chill = { slow = 0.3, seconds = 2 } -- Frostbite: the monster walks 30% slower for 2 s
Enchant.Burn = { share = 0.5, seconds = 3 } -- Ember: half the shot's damage again, spread over 3 s
Enchant.Jump = { share = 0.5 } -- Chain: half the shot's damage to one more monster
Enchant.GemsPerDay = 30 -- Gem Finder: the most gems all Gem Finder enchantments drop in one UTC day

Enchant.List = {
	{ id = "sharp", name = "Sharp", how = "more", kind = "power", amounts = { 0.05, 0.10, 0.15 }, text = "+%s%% tower damage" },
	{ id = "rapid", name = "Rapid", how = "more", kind = "towerRate", amounts = { 0.03, 0.06, 0.10 }, text = "+%s%% tower fire rate" },
	{ id = "reach", name = "Reach", how = "more", kind = "towerRange", amounts = { 0.03, 0.06, 0.10 }, text = "+%s%% tower range" },
	{ id = "slayer", name = "Giant Slayer", how = "more", kind = "bossDamage", amounts = { 0.10, 0.20, 0.30 }, text = "+%s%% damage on boss levels" },
	{ id = "splinter", name = "Splinter", how = "hook", amounts = { 0.03, 0.06, 0.10 }, text = "every shot splashes %s%% of its damage on all other monsters" },
	{ id = "frostbite", name = "Frostbite", how = "hook", amounts = { 0.05, 0.10, 0.15 }, text = `%s%% of shots chill their monster ({percent(Enchant.Chill.slow)}%% slower for {Enchant.Chill.seconds}s)` },
	{ id = "ember", name = "Ember", how = "hook", amounts = { 0.05, 0.10, 0.15 }, text = `%s%% of shots set their monster alight (+{percent(Enchant.Burn.share)}%% damage over {Enchant.Burn.seconds}s)` },
	{ id = "chain", name = "Chain", how = "hook", amounts = { 0.05, 0.10, 0.15 }, text = `%s%% of shots jump to a second monster for {percent(Enchant.Jump.share)}%% damage` },
	{ id = "executioner", name = "Executioner", how = "hook", amounts = { 0.01, 0.02, 0.03 }, text = "finishes monsters under %s%% health" },
	{ id = "greed", name = "Greed", how = "more", kind = "coins", amounts = { 0.05, 0.10, 0.15 }, text = "+%s%% coins" },
	{ id = "treasure", name = "Treasure", how = "more", kind = "crateDrops", amounts = { 0.10, 0.20, 0.30 }, text = "+%s%% crate drops from bosses" },
	{ id = "gemfinder", name = "Gem Finder", how = "add", kind = "gems", unit = "count", amounts = { 0.05, 0.10, 0.15 }, text = `bosses drop +%s gems (up to {Enchant.GemsPerDay} a day)` },
	{ id = "lucky", name = "Lucky", how = "more", kind = "luck", amounts = { 0.05, 0.10, 0.15 }, text = "+%s%% egg luck" },
	{ id = "sweettooth", name = "Sweet Tooth", how = "hook", amounts = { 0.10, 0.20, 0.30 }, text = "+%s%% candy from monsters" },
	{ id = "bond", name = "Bond", how = "bond", kind = "petDps", kinds = { "petDps", "power" }, amounts = { 0.10, 0.20, 0.30 }, text = "+%s%% of this mini cannon's own DPS (on a Huge: of its tower damage bonus)" },
	-- Quick Draw (+mini cannon shots) stood here until 5 Oct. Mini cannons deal flat damage per second, so
	-- firing faster added nothing: it is gone (Config.RetiredEnchants), and an id that still carries it
	-- resolves without it.
	-- Long Shot raised the mini cannons' range. Their damage needs no range any more, so it is a small "more
	-- mini cannon damage" instead, for all of them.
	{ id = "longshot", name = "Long Shot", how = "more", kind = "petDps", amounts = { 0.03, 0.06, 0.10 }, text = "+%s%% DPS of all your mini cannons" },
	{ id = "guardian", name = "Guardian", how = "add", kind = "lives", unit = "count", amounts = { 1, 2, 3 }, text = "+%s lives per level" },
	{ id = "tar", name = "Tar", how = "less", kind = "monsterSpeed", amounts = { 0.02, 0.04, 0.06 }, text = "monsters walk %s%% slower" },
	{ id = "scholar", name = "Scholar", how = "hook", amounts = { 0.10, 0.20, 0.30 }, text = "+%s%% Veteran progress from every kill" },
}

Enchant.byId = {}
for _, def in Enchant.List do
	assert(string.match(def.id, "^%l+$"), `enchantment id {def.id}: lower case letters only (it is part of a saved id)`)
	assert(#def.amounts == Enchant.LEVELS, `enchantment {def.id} needs {Enchant.LEVELS} levels`)
	assert(not Config.RetiredEnchants[def.id], `enchantment {def.id} is retired: saved ids that carry it resolve without it`)
	Enchant.byId[def.id] = def
	Config.EnchantNames[def.id] = def.name -- so every list that names a mini cannon can write its enchantments
end

local ROMAN = { "I", "II", "III" }

function Enchant.roman(level: number): string
	return ROMAN[level] or tostring(level)
end

-- Whether the player has reached the table's world. It reads the highest level ever, so it stays open after
-- a rebirth.
function Enchant.unlocked(bestCleared: number): boolean
	return Config.worldUnlocked(Enchant.ISLAND, bestCleared)
end

-- What a level of an enchantment gives (0 for one this build does not know).
function Enchant.amount(id: string, level: number): number
	local def = Enchant.byId[id]
	return if def then def.amounts[level] or 0 else 0
end

-- "+15% tower damage": what an amount of an enchantment does, in words. The amount may be several levels
-- added up.
function Enchant.describe(id: string, amount: number): string
	local def = Enchant.byId[id]
	if not def then
		return "Unknown enchantment"
	end
	local text = string.format(def.text, number(if def.unit == "count" then amount else amount * 100))
	if def.unit == "count" and amount == 1 then
		text = string.gsub(text, "lives", "life")
	end
	return text
end

-- "Sharp III".
function Enchant.title(id: string, level: number): string
	local def = Enchant.byId[id]
	return `{if def then def.name else id} {Enchant.roman(level)}`
end

-- A mini cannon's enchantments as one line: "Greed I, Sharp III". "" for a plain one.
function Enchant.summary(petId: string): string
	local parts = {}
	for _, enchant in Config.petEnchants(petId) do
		table.insert(parts, Enchant.title(enchant.id, enchant.level))
	end
	return table.concat(parts, ", ")
end

-- The same with what each one does: { "Sharp III: +15% tower damage", ... }.
function Enchant.lines(petId: string): { string }
	local lines = {}
	for _, enchant in Config.petEnchants(petId) do
		table.insert(lines, `{Enchant.title(enchant.id, enchant.level)}: {Enchant.describe(enchant.id, Enchant.amount(enchant.id, enchant.level))}`)
	end
	return lines
end

-- What enchanting this mini cannon costs in gems, or nil for an id nobody knows.
function Enchant.cost(petId: string): number?
	local pet = Config.Pets[petId]
	if not pet then
		return nil
	end
	return Enchant.Gems[pet.rarity] or Enchant.Gems.Mythical
end

----------------------------------------------------------------------------------------------------
-- Rolling. `random` is a Random (NextNumber): the server's own.
----------------------------------------------------------------------------------------------------
-- One pick from a list of weights: the index it lands on.
local function pick(weights: { number }, roll: number): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local left = roll * total
	local last = 1
	for index, weight in weights do
		if weight > 0 then
			last = index
			left -= weight
			if left < 0 then
				return index
			end
		end
	end
	return last -- rounding left a hair over: the last one that can be picked
end

-- What one use of a key gives: { { id, level } }, no enchantment twice, or nil for a key nobody knows.
function Enchant.roll(keyId: string, random): { { id: string, level: number } }?
	local key = Enchant.KeyById[keyId]
	if not key then
		return nil
	end
	local count = math.min(pick(key.count, random:NextNumber()), Enchant.MAX, #Enchant.List)
	-- Which ones: drawn without putting back, every enchantment as likely as any other.
	local pool = table.clone(Enchant.List)
	local enchants = {}
	for _ = 1, count do
		local index = math.min(#pool, math.floor(random:NextNumber() * #pool) + 1)
		table.insert(enchants, { id = pool[index].id, level = 1 })
		table.remove(pool, index)
	end
	-- Their levels. A key with `top` gives that many of them level III for certain (which ones is random,
	-- because they were drawn at random); the rest roll like any other.
	for index, enchant in enchants do
		enchant.level = if index <= key.top then Enchant.LEVELS else pick(key.levels, random:NextNumber())
	end
	return enchants
end

-- The odds of a key, as the window prints them and exactly as Enchant.roll rolls them:
--   count   { { n = 1, chance = 50 }, ... }           how many enchantments (per cent; only what can happen)
--   levels  { { level = 1, chance = 60 }, ... }       the level of each enchantment that is not guaranteed
--   top     how many are level III for certain
--   each    the chance, per cent, that one given enchantment is among those of a roll that gives n:
--           { [n] = chance }
function Enchant.odds(keyId: string)
	local key = Enchant.KeyById[keyId]
	if not key then
		return nil
	end
	local function shares(weights: { number }, name: string)
		local total = 0
		for _, weight in weights do
			total += weight
		end
		local list = {}
		for index, weight in weights do
			if weight > 0 then
				table.insert(list, { [name] = index, chance = weight / total * 100 })
			end
		end
		return list
	end
	local each = {}
	for n = 1, Enchant.MAX do
		each[n] = n / #Enchant.List * 100
	end
	return { count = shares(key.count, "n"), levels = shares(key.levels, "level"), top = key.top, each = each }
end

local function percentText(chance: number): string
	return number(chance) .. "%"
end

-- The odds of a key in words, for the window: a few short lines.
function Enchant.oddsLines(keyId: string): { string }
	local odds = Enchant.odds(keyId)
	local key = Enchant.KeyById[keyId]
	if not odds or not key then
		return {}
	end
	local lines = {}
	local counts = {}
	for _, entry in odds.count do
		table.insert(counts, `{entry.n}: {percentText(entry.chance)}`)
	end
	table.insert(lines, `Enchantments  •  {table.concat(counts, "   ")}`)
	local levels = {}
	for _, entry in odds.levels do
		table.insert(levels, `{Enchant.roman(entry.level)}: {percentText(entry.chance)}`)
	end
	if odds.top > 0 then
		table.insert(lines, `Levels  •  {odds.top} are always III; the other one  •  {table.concat(levels, "   ")}`)
	else
		table.insert(lines, `Level of each  •  {table.concat(levels, "   ")}`)
	end
	table.insert(lines, `Which ones  •  all {#Enchant.List} are equally likely ({percentText(100 / #Enchant.List)} each), none twice`)
	return lines
end

-- The same on one line, for the place where the roll is bought:
-- "Enchantment Key: 1 / 2 / 3 enchantments 50% / 35% / 15%, each level I / II / III 60% / 30% / 10%".
function Enchant.oddsShort(keyId: string): string
	local odds = Enchant.odds(keyId)
	local key = Enchant.KeyById[keyId]
	if not odds or not key then
		return ""
	end
	local function row(list, name: string, write: (any) -> string): (string, string)
		local what, chances = {}, {}
		for _, entry in list do
			table.insert(what, write(entry[name]))
			table.insert(chances, percentText(entry.chance))
		end
		return table.concat(what, " / "), table.concat(chances, " / ")
	end
	local counts, countChances = row(odds.count, "n", tostring)
	local levels, levelChances = row(odds.levels, "level", Enchant.roman)
	local count = if #odds.count == 1 then `always {counts} enchantments` else `{counts} enchantments {countChances}`
	local level = if odds.top > 0
		then `{odds.top} of them level III, the other {levels} {levelChances}`
		else `each level {levels} {levelChances}`
	return `{key.name}: {count}, {level}`
end

-- An enchantment's three levels in one line: "+5 / 10 / 15% tower damage".
function Enchant.describeLevels(id: string): string
	local def = Enchant.byId[id]
	if not def then
		return ""
	end
	local amounts = {}
	for _, amount in def.amounts do
		table.insert(amounts, number(if def.unit == "count" then amount else amount * 100))
	end
	return string.format(def.text, table.concat(amounts, " / "))
end

-- The gem prices in one line: "Common 10  •  Uncommon 15 ...".
function Enchant.costLine(): string
	local parts = {}
	for _, rarity in Enchant.RARITIES do
		table.insert(parts, `{if rarity == "Mythical" then "Huge" else rarity} {Enchant.Gems[rarity]}`)
	end
	return table.concat(parts, "  •  ")
end

----------------------------------------------------------------------------------------------------
-- What the equipped mini cannons' enchantments add up to.
----------------------------------------------------------------------------------------------------
-- { [enchantment id] = { sum, keep, parts } } for a list of equipped mini cannon ids:
--   sum     the amounts added up                    keep    (1 - amount) of each multiplied together
--   parts   { { label = "Mini Storm Cannon: Sharp III", weight = amount } }: one per mini cannon that has
--           it, for the STATS window (two of the same mini cannon share a line: "... x2")
-- A second copy of the same Huge counts like any other mini cannon: it is equipped, so its enchantments are.
function Enchant.totals(equipped: { string })
	local totals = {}
	for _, petId in equipped do
		local pet = Config.Pets[petId]
		local plain = pet and Config.Pets[pet.plain]
		for _, enchant in if pet and pet.enchants then pet.enchants else {} do
			local amount = Enchant.amount(enchant.id, enchant.level)
			if amount > 0 then
				local total = totals[enchant.id]
				if not total then
					total = { sum = 0, keep = 1, parts = {}, byKey = {} }
					totals[enchant.id] = total
				end
				total.sum += amount
				total.keep *= math.max(0, 1 - amount)
				local key = `{pet.plain}:{enchant.level}`
				local part = total.byKey[key]
				if part then
					part.count += 1
					part.weight += amount
					part.label = `{part.name} x{part.count}: {part.title}`
				else
					local name = if plain then plain.name else petId
					local title = Enchant.title(enchant.id, enchant.level)
					part = { name = name, title = title, count = 1, weight = amount, label = `{name}: {title}`, huge = pet.huge == true }
					total.byKey[key] = part
					table.insert(total.parts, part)
				end
			end
		end
	end
	return totals
end

-- What the Bond enchantments multiply a number by. Each mini cannon that has Bond counts its own strength that
-- much more:
--   kind "petDps"   an ordinary mini cannon's own damage per second grows by its Bond; the answer is what that
--                   does to all the mini cannons' damage per second together (Config.petDpsList)
--   kind "power"    a Huge has no damage of its own to speak of: the part of its multiplier on tower damage
--                   over x1 grows instead (x3 with Bond III is x3.6)
-- equipped and towerNames are the state's.
function Enchant.bondFactor(equipped: { string }, towerNames: { [string]: boolean }?, kind: string?): number
	local list = Config.petDpsList(equipped, towerNames)
	local base, grown = 0, 0 -- the mini cannons' damage per second, without and with Bond
	local power, powerGrown = 1, 1
	local counted = {}
	for index, petId in equipped do
		local pet = Config.Pets[petId]
		if not pet then
			continue
		end
		local share = 0
		for _, enchant in pet.enchants or {} do
			if enchant.id == "bond" then
				share += Enchant.amount("bond", enchant.level)
			end
		end
		local own = list[index] or 0
		base += own
		grown += if pet.huge then own else own * (1 + share)
		if pet.huge and not counted[pet.plain] then
			counted[pet.plain] = true
			power *= pet.power
			powerGrown *= 1 + (pet.power - 1) * (1 + share)
		end
	end
	if kind == "power" then
		return powerGrown / power
	end
	return if base > 0 then grown / base else 1
end

-- A number of `kind` after the enchantment `id`, whose equipped amounts are `total` (an entry of
-- Enchant.totals). state is the player's session state (Bond reads the equipped mini cannons from it). kind
-- is the number being changed: the enchantment's own when left out (Bond has two).
function Enchant.apply(id: string, total, value: number, state, kind: string?): number
	local def = Enchant.byId[id]
	if not def or not total then
		return value
	end
	if def.how == "more" then
		return value * (1 + total.sum)
	elseif def.how == "less" then
		return value * total.keep
	elseif def.how == "add" then
		return value + total.sum
	elseif def.how == "bond" then
		return value * Enchant.bondFactor(state.equipped, state.towerNames, kind or def.kind)
	end
	return value
end

return Enchant
