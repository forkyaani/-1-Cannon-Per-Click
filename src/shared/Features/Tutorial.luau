-- The first-join experience: three welcome cards (the game, the group's fan bonus, a like), then a
-- walkthrough that teaches the game by doing, one step at a time.
-- Both sides read this file: the server decides which step is done and pays (src/server/Features/Tutorial),
-- the client draws the cards, the banner and the marker in the world (src/client/Features/Tutorial).
-- The fan bonus's numbers are Config.Fan. Every coin and gem a step pays is in Tutorial.Steps below.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Tutorial = {}

Tutorial.Fan = Config.Fan
Tutorial.DONE = "done" -- what the saved step says once the walkthrough is finished or was skipped

-- What a save holds (data.features.tutorial):
--   welcomed   the welcome cards were seen to the end (once per save)
--   step       the id of the walkthrough step the player is on, or Tutorial.DONE
--   fanPaid    the fan bonus was paid: the gems once, and the coin bonus applies from then on
--   paid       [step id] = true: that step's reward was paid, by the walkthrough or by the story quest that
--              asks for the same thing (Tutorial.take). Whichever sees it first pays; nobody pays twice
--   seeded     the save was looked at once for story quests an older version had paid already
Tutorial.SAVED = { welcomed = false, step = "pad", fanPaid = false, paid = {}, seeded = false }

local cannon = Config.Towers.cannon
local egg = Config.Eggs[1] or {}
local eggWorld = Config.Worlds[egg.world or 1] or {}
local second = Config.Towers[Config.TowerOrder[2]] or cannon

Tutorial.Egg = egg -- the egg the walkthrough hatches: the first one, on its world's island
Tutorial.Island = egg.world or 1

local function coins(amount: number?): string
	return `★ {Format.abbreviate(amount or 0)}`
end

-- The walkthrough, in order. A step:
--   id       saved, and what the client and the server call it
--   title    the banner's line: what to do, in a few words
--   detail   one more short line under it
--   reward   { coins, gems }: paid when the step is done. Each one pays for what a later step asks the player
--            to buy (`buys` says what that costs), so nobody waits on coins while learning
--   story    true when chapter 1 of the story has a quest for the same thing (it carries `tutorial = id` and
--            this reward, src/shared/Features/Story.luau): the two share one payment
--   ack      true for a step that ends with the player's own press (GOT IT, LET'S GO): there is nothing to do
--   card     true for the step that is a full-screen card, not a banner
--   buys     coins the step asks the player to spend
-- How each one is detected is in the server module (DONE there).
Tutorial.Steps = {
	{
		id = "pad",
		title = "Walk to your cannon",
		detail = "Follow the arrow to the pad beside the path.",
		reward = { coins = Config.towerUpgradeCost("cannon", 1) },
		story = true,
	},
	{
		id = "open",
		title = "Open your cannon",
		detail = "Stand at the cannon and press its Upgrade prompt.",
	},
	{
		id = "upgrade",
		title = "Press UPGRADE",
		detail = `It costs {coins(Config.towerUpgradeCost("cannon", 1))}. The coins are on us!`,
		reward = { coins = Config.padPrice(2) },
		buys = Config.towerUpgradeCost("cannon", 1),
		story = true,
	},
	{
		id = "clear",
		title = "Watch your cannon clear the level",
		detail = "It shoots all by itself. Every monster pays coins.",
		reward = { coins = cannon.cost },
		story = true,
	},
	{
		id = "pad2",
		title = "Buy a second pad",
		detail = `Walk to the FOR SALE pad and press BUY PAD ({coins(Config.padPrice(2))}).`,
		reward = { coins = Config.towerUpgradeCost("cannon", 1) },
		buys = Config.padPrice(2),
		story = true,
	},
	{
		id = "build",
		title = `Build a {cannon.name} on your new pad`,
		detail = `Open the empty pad and press BUILD ({coins(cannon.cost)}).`,
		reward = { coins = Config.towerUpgradeCost("cannon", 2) },
		buys = cannon.cost,
		story = true,
	},
	{
		id = "lives",
		title = "Monsters that reach your gate cost lives ❤",
		detail = "No lives left? The level fails and you go back one level.",
		ack = true,
		button = "GOT IT",
	},
	{
		id = "island",
		title = `Open WORLDS, then press ISLAND on {eggWorld.name or "the first world"}`,
		detail = "Eggs wait on the islands. This trip pays for your first egg!",
		reward = { coins = egg.cost or 0 },
	},
	{
		id = "hatch",
		title = `Hatch the {egg.name or "first egg"}`,
		detail = `Walk to the egg and press Hatch ({coins(egg.cost)}).`,
		reward = { gems = 5, coins = second.cost },
		buys = egg.cost or 0,
		story = true,
	},
	{
		id = "home",
		title = "Go back to your base",
		detail = "Press BASE on the right. Your mini cannon comes along.",
	},
	{
		id = "finish",
		title = "You are on your own!",
		detail = "",
		reward = { gems = 10 },
		ack = true,
		card = true,
		button = "LET'S GO!",
	},
}

Tutorial.ById = {}
Tutorial.Index = {}
for index, step in Tutorial.Steps do
	Tutorial.ById[step.id] = step
	Tutorial.Index[step.id] = index
end

-- The reward of a step, for the story quest that asks for the same thing.
function Tutorial.reward(id: string)
	local step = Tutorial.ById[id]
	return (step and step.reward) or {}
end

-- Marks a step's reward as paid. True the first time only: whoever gets true pays.
function Tutorial.take(save, id: string): boolean
	if typeof(save.paid) ~= "table" then
		save.paid = {}
	end
	if save.paid[id] then
		return false
	end
	save.paid[id] = true
	return true
end

-- "+★ 25  +5 gems", or "" for a step that pays nothing.
function Tutorial.rewardText(reward): string
	local parts = {}
	if reward and (reward.coins or 0) > 0 then
		table.insert(parts, `+{coins(reward.coins)}`)
	end
	if reward and (reward.gems or 0) > 0 then
		table.insert(parts, `+{reward.gems} gems`)
	end
	return table.concat(parts, "  ")
end

----------------------------------------------------------------------------------------------------
-- The welcome cards' words. Keep every line short enough to read on a phone at a glance.
-- The fan bonus is for the group only. A game cannot check a like, and Roblox does not allow rewarding one:
-- the like card must never promise, hint at or stand next to a reward.
----------------------------------------------------------------------------------------------------
local fan = Config.Fan
Tutorial.Cards = {
	{
		id = "welcome",
		title = "WELCOME!",
		lines = {
			`This is {Config.GameName}.`,
			"Monsters march on your base. Build cannon towers to stop them!",
			"Your towers shoot by themselves, even while you explore.",
		},
		next = "NEXT",
	},
	{
		id = "group",
		title = "FAN BONUS",
		lines = { `Join {fan.groupName} for a fan bonus:` },
		bonus = { `+{fan.gems} gems`, `+{math.floor(fan.coins * 100 + 0.5)}% coins, forever` },
		-- The line under the bonus, by what the server says (see the client's refresh).
		soon = "Our group is coming soon. Your fan bonus will wait for you!",
		ask = "Joined? Press CHECK to claim it.",
		no = "Not a member yet. Join the group from the game's page, then press CHECK. (Just joined? It can take a rejoin.)",
		failed = "Roblox did not answer. Try CHECK again in a moment.",
		paid = "Fan bonus claimed. Thank you!",
		check = "CHECK",
		next = "NEXT",
	},
	{
		id = "like",
		title = "ENJOYING THE GAME?",
		lines = {
			"A 👍 like and a ⭐ favourite help the game grow.",
			"There is no reward for it. It is simply a big help. Thank you!",
		},
		next = "START TUTORIAL",
		skip = "Played before? Skip tutorial",
		skipSure = "Skip the tutorial? Tap again",
	},
}

-- The last step's card: where things are from here on.
Tutorial.Finish = {
	title = "YOU ARE ON YOUR OWN!",
	lines = {
		{ icon = "📖", name = "STORY", text = "quests and rewards. Press MORE to find it." },
		{ icon = "🛒", name = "STORE", text = "game passes, on the right." },
		{ icon = "📊", name = "STATS", text = "every number and where it comes from. Under MORE." },
	},
}

return Tutorial
