-- Huge cannons: what makes each one different. The cannons themselves (name, colours, power, which egg hides
-- which) are mini cannon entries in Config.luau, and so is what every Huge does: x Config.HugePower (3) to the
-- damage of every tower, a modest damage per second of its own (Config.petDpsList) and a Huge Shot
-- (Config.HugeShot). This file holds each one's
-- special feature, and the game pass that sells the one Huge that cannot be hatched.
-- The server half (src/server/Features/Huge.luau) applies the numbers below while a Huge is equipped; the
-- INDEX window (src/client/Features/Huge.luau) lists them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Huge = {}

-- [mini cannon id] = its feature. name is what it is called; the other keys are what it does:
--   coins, heal, luck      multiplies that number (the Game.modify kinds)
--   monsterSpeed           multiplies how fast monsters walk (the Game.modify kind: 0.8 = 20% slower). It
--                          stacks with a Frost tower's slow, and STATS lists it
--   slow                   every monster on the plot walks this much slower (0.2 = 20%). The strongest slow on
--                          a monster counts: it does not add to a Frost tower's. (No Huge has it at present.)
--   bossDamage             multiplies the damage of tower and mini cannon shots on a boss level
--   fireRate               shots a second from the Huge itself (a mini cannon fires 1). Unlike a fused mini
--                          cannon's Rapid Fire these are whole shots: the Huge's own damage per second is
--                          that many times a Huge's (Config.petDpsList)
--   multiHit               { chance, hits }: that share of tower and mini cannon shots hits `hits` times
--   execute                a shot that leaves a monster at or under this share of its health finishes it
--   freeEgg                1 egg in this many costs the player nothing
--   bossGems, gemsPerDay   gems a defeated boss drops, and the most it drops in one UTC day
--   candy, crateDrops      multiplies the Halloween candy monsters drop, and how often bosses drop crates
--   autoUpgrade            upgrades the player's cheapest tower whenever the coins reach, by itself (the
--                          player can switch it off in the INDEX window)
-- Each one is meant to change how the game is played, not to nudge a number. heal is never 0: a level must
-- still be failable.
-- The numbers are the idle defence's (docs/BUILD_QUEUE.md, section 1): the clicker's were ten times these,
-- and no balance survives a x50 on bosses.
Huge.Features = {
	hugestorm = { name = "Chain Lightning", multiHit = { chance = 0.25, hits = 2 } },
	hugegatling = { name = "Gatling", fireRate = 5 },
	hugehex = { name = "Hex", heal = 0.5 },
	hugeslayer = { name = "Boss Slayer", bossDamage = 3 },
	hugeclover = { name = "Lucky", luck = 2 },
	hugegoldengoose = { name = "Golden Eggs", freeEgg = 4 },
	hugeexecutioner = { name = "Execute", execute = 0.15 },
	hugegemstone = { name = "Gem Finder", bossGems = 1, gemsPerDay = 50 },
	hugepumpkin = { name = "Trick or Treat", candy = 2, crateDrops = 2 },
	hugetycoon = { name = "Tycoon", coins = 2, autoUpgrade = true },
	-- The Halloween leaderboard's prize (Features/Event.luau): in no egg.
	hugespectre = { name = "Haunt", monsterSpeed = 0.8 },
}

local function percent(share: number): string
	return `{math.floor(share * 100 + 0.5)}%`
end

-- What a feature does, in a few words. Written from its numbers, so the text can never disagree with them.
local function describe(feature): string
	local parts = {}
	if feature.coins then
		table.insert(parts, `x{feature.coins} coins`)
	end
	if feature.slow then
		table.insert(parts, `monsters walk {percent(feature.slow)} slower`)
	end
	if feature.monsterSpeed then
		table.insert(parts, `monsters walk {percent(1 - feature.monsterSpeed)} slower`)
	end
	if feature.heal then
		table.insert(parts, `{if feature.slow then "" else "monsters "}heal {percent(1 - feature.heal)} slower`)
	end
	if feature.luck then
		table.insert(parts, `x{feature.luck} luck on every egg`)
	end
	if feature.bossDamage then
		table.insert(parts, `x{feature.bossDamage} damage on boss levels`)
	end
	if feature.fireRate then
		table.insert(parts, `fires {feature.fireRate * Config.AutoShotsPerPet} shots a second: x{feature.fireRate} its own DPS`)
	end
	if feature.multiHit then
		local hits = feature.multiHit.hits
		table.insert(parts, `{percent(feature.multiHit.chance)} of shots hit {if hits == 2 then "twice" else `{hits} times`}`)
	end
	if feature.execute then
		table.insert(parts, `finishes monsters under {percent(feature.execute)} health`)
	end
	if feature.freeEgg then
		table.insert(parts, if feature.freeEgg == 2 then "every second egg is free" else `1 egg in {feature.freeEgg} is free`)
	end
	if feature.bossGems then
		table.insert(parts, `bosses drop {feature.bossGems} {if feature.bossGems == 1 then "gem" else "gems"}, up to {feature.gemsPerDay} a day`)
	end
	if feature.candy then
		table.insert(parts, `x{feature.candy} candy`)
	end
	if feature.crateDrops then
		table.insert(parts, `x{feature.crateDrops} crate drops`)
	end
	if feature.autoUpgrade then
		table.insert(parts, "upgrades your cheapest tower for you")
	end
	return table.concat(parts, ", ")
end

-- Each feature gets its text, and its Huge carries the same line as `feature`, which the hatch reveal shows
-- for any mini cannon that has one.
for id, feature in Huge.Features do
	local pet = Config.Pets[id]
	assert(pet and pet.huge, `feature for unknown Huge {id}`)
	feature.id = id
	feature.text = describe(feature)
	pet.feature = feature.text
	-- Fire rate is the one feature the core already knows: the server's mini cannon shots, a Huge's own damage
	-- per second (Config.petDpsList) and the client's volleys all read it from the mini cannon.
	pet.fireRate = feature.fireRate or pet.fireRate
end
for _, id in Config.Huges do
	assert(Huge.Features[id], `Huge {id} has no feature`)
end

-- The one Huge that is bought: owning the pass gives it once (the server remembers that in the save).
Huge.PassKey = "hugeStarter"
Huge.PassPet = "hugetycoon"
do
	local pet = Config.Pets[Huge.PassPet]
	Config.Passes[Huge.PassKey] = {
		id = 0,
		order = 0, -- first in the store
		name = `HUGE {pet.short} Cannon`,
		-- Short: the store's row has two small lines for it.
		desc = `{Format.petPower(pet)} ALL tower damage, Huge Shots, {pet.feature}. Cannot be traded`,
		price = 1499,
	}
end

return Huge
