-- The story's first chapter (the tutorial of the idle defence) played step by step, and the crates' coin
-- maths on the new curve. Run with: python3 run.py --all-features tests/story_crates.luau
local T = harness.load("_prelude.luau")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config, Layout, Game = T.Config, T.Layout, T.Game
local player, data, state = T.player, T.data, T.state
local check, eq, act, debug, run = T.check, T.eq, T.act, T.debug, T.run
local Story = require(ReplicatedStorage.Shared.Features.Story)
local Crates = require(ReplicatedStorage.Shared.Features.Crates)

-- The Huge every pass owner gets in Studio would clear levels by itself.
for _, id in Config.Huges do
	Game.pets.remove(player, id, Game.pets.count(data, id))
end
state.autoAdvance, data.autoAdvance = false, false

local function story()
	return HttpService:JSONDecode(player:GetAttribute("Meta_story"))
end
local function quest()
	local now = story()
	local chapter = Story.Chapters[now.chapter]
	return chapter and chapter.quests[now.quest], now
end
local function expect(kind: string, what: string)
	run(1.5)
	local active, now = quest()
	check(active ~= nil and active.kind == kind, `{what}: quest {now.chapter}.{now.quest} is "{active and active.kind}" ({active and active.title})`)
end

T.section("no quest names what is gone")
local GONE = { "rebirth", "tap", "click", "big cannon", "fire", "per click" }
local quests = 0
for _, chapter in Story.Chapters do
	for _, entry in chapter.quests do
		local text = entry.title
		for _, line in entry.say do
			text ..= " " .. (if typeof(line) == "table" then line.text else line)
		end
		local lower = " " .. string.lower(text) .. " "
		for _, word in GONE do
			if string.find(lower, "%A" .. word .. "%A") then
				error(`CHECK FAILED: chapter {chapter.index} "{entry.title}" says "{word}": {text}`)
			end
		end
		quests += 1
	end
end
check(quests > 80, `{quests} quests, none mentions tapping, firing or rebirth`)

T.section("chapter 1: the tutorial")
eq(#Story.Chapters[1].quests, 11, "quests in chapter 1")
expect("pad", "a new player is asked to walk to their cannon")
local character = Instance.new("Model")
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Position = Layout.plotSpawn(state.slot).Position
root.Parent = character
character.PrimaryPart = root
player.Character = character
character.Parent = workspace
expect("pad", "standing at the spawn is not at the pad")
local coins = data.coins
root.Position = Layout.padPosition(state.slot, 1) + Vector3.new(4, 3, 4)
run(1)
local _, now = quest()
check(now.quest >= 2, "walking up to the pad finishes it")
check(data.coins >= coins + Config.towerUpgradeCost("cannon", 1), "and pays for the first upgrade")
for _ = 1, 120 do
	if data.bestCleared >= 1 then
		break
	end
	run(1)
end
check(data.bestCleared >= 1, "level 1 is cleared by the starter cannon")
expect("upgrade", "then: upgrade a tower")
act("upgradeTower", { pad = 1, levels = 1 })
check(data.towers["1"].level >= 2, "the upgrade was affordable")
expect("pads", "then: buy a second pad")
check(data.coins >= Config.padPrice(2), "the pad is paid for")
act("buyPad", 2)
eq(#data.pads, 2, "pads")
expect("towers", "then: build on it")
check(data.coins >= Config.Towers.cannon.cost, "the cannon is paid for")
act("buildTower", { pad = 2, kind = "cannon" })
expect("hatched", "then: hatch an egg, on the island (the walkthrough's order: Features/Tutorial.luau)")
-- The story alone does not pay for the egg: the walkthrough's trip to the island does.
debug("coins", 1e9)
act("goIsland", 1)
harness.advance(0.1)
harness.fire(T.Marketplace.promptFor[Config.Eggs[1].id], "Triggered", player)
run(1)
check(data.totalHatches >= 1, "hatched")
expect("wave", "then: the first giant")
act("goHome")
debug("wave", Config.BossEvery + 1)
expect("market", "then: the marketplace")
expect("market", "having hatched on an island is not a visit to town")
act("goMarket")
expect("kinds", "then: a second kind of tower")
act("goHome")
debug("wave", math.max(data.wave, Config.Towers[Config.TowerOrder[2]].unlock + 1))
act("buyPad", 3)
act("buildTower", { pad = 3, kind = Config.TowerOrder[2] })
expect("wave", "then: the mid boss (no fusing in the tutorial: the Fusion Machine is on a later island)")
debug("wave", Config.WavesPerWorld / 2 + 1)
expect("wave", "then: the world boss")
eq(story().quest, 11, "the last quest of the chapter")
debug("wave", Config.WavesPerWorld + 1)
run(1.5)
eq(story().chapter, 2, "chapter")
act("storyClaim", 1)
check(story().claimed["1"] == true, "chapter 1's reward is claimed")

T.section("chapter 2: tower goals")
local seen = {}
for _ = 1, 40 do
	local active = quest()
	if not active or story().chapter > 2 then
		break
	end
	seen[active.kind] = true
	if active.kind == "wave" then
		debug("wave", active.from + active.n + 1)
	elseif active.kind == "towers" then
		debug("towers", active.level)
	elseif active.kind == "pads" then
		for pad = 1, active.n do
			act("buyPad", pad)
		end
	elseif active.kind == "kills" or active.kind == "bosses" or active.kind == "hatches" then
		Game.feature(data, "story", {}).count = active.n
	elseif active.kind == "fused" then
		error("a fusing quest before the Fusion Machine's world")
	elseif active.kind == "own" then
		debug("pet:wooden", active.n)
	end
	run(1.5)
end
check(story().chapter > 2, "chapter 2 can be finished")
local kinds = {}
for _, chapter in Story.Chapters do
	for _, entry in chapter.quests do
		kinds[entry.kind] = true
	end
end
check(kinds.towers and kinds.pads and kinds.wave, "later chapters ask for pads, tower levels and levels cleared")
do
	-- The fusing quests: none before the Fusion Machine's world, then Silver, Gold, Diamond.
	local tiers = {}
	for index, chapter in Story.Chapters do
		for _, entry in chapter.quests do
			if entry.kind == "fused" then
				check(index >= Config.FuseIsland, `chapter {index} asks for fusing, and the machine's world is reached by then`)
				table.insert(tiers, `{entry.tier}x{entry.n}`)
			end
		end
	end
	eq(table.concat(tiers, " "), "1x1 2x1 3x1 3x2", "fusing quests after The Sun: Silver, Gold, Diamond, two Diamonds")
	eq(Config.FuseIsland, 5, "the Fusion Machine is on The Sun's island")
end
debug("wave", Config.TotalWaves)
run(2)
check(harness.errors() == 0, "no errors after jumping to the end of the game")

T.section("story rewards follow Config.levelPlan")
for _, level in { 1, 30, 120, 599 } do
	local reward = Story.resolve({ clears = 1 }, level, 1)
	local plan = Config.levelPlan(level)
	local ordinary = level
	while ordinary > 1 and Config.waveKind(ordinary) ~= "normal" do
		ordinary -= 1
	end
	plan = Config.levelPlan(ordinary)
	eq(reward.coins, math.floor(plan.count * plan.coins), `one clear at level {level}`)
end

T.section("crates on the new coin curve")
local wood = Crates.ById.woodcrate
for _, best in { 0, 1, 49, 50, 300, 600 } do
	local price = Crates.price(wood, best)
	eq(price, math.max(1, math.floor(Config.levelCoins(math.max(1, best)))), `Wooden Crate price at level {best}`)
	-- What a crate pays back in coins on average, as a share of its price: never a money machine.
	local back = 0
	for _, entry in Crates.odds(wood) do
		if entry.row.coins then
			back += entry.chance / 100 * Crates.coins(entry.row, best)
		end
	end
	check(back < price * 0.7 and back > price * 0.4, `it pays back {math.floor(back / price * 100)}% in coins at level {best}`)
end
for _, crate in Crates.List do
	local total = 0
	for _, entry in Crates.odds(crate) do
		total += entry.chance
		local text = string.lower(Crates.rewardText(entry.row, 100))
		assert(not string.find(text, "rebirth") and not string.find(text, "click"), text)
	end
	check(math.abs(total - 100) < 1e-6, `{crate.name}: the chances add up to 100`)
	local words = string.lower(crate.name .. " " .. crate.desc .. " " .. (crate.source or ""))
	check(not string.find(words, "rebirth") and not string.find(words, "big cannon") and not string.find(words, "click"), `{crate.name}: its text names nothing that is gone`)
end
data.coins = 0
act("buyCrates", { id = "woodcrate", count = 1 })
local price = Crates.price(wood, data.cleared)
data.coins = price
act("buyCrates", { id = "woodcrate", count = 1 })
check(data.coins < price * 40, "a Wooden Crate was bought and opened")
check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
