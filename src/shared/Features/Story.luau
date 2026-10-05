-- The story: Captain Kaboom, the Void King, and one chapter of quests per world.
-- Both sides read this file: the server follows and pays the quests (src/server/Features/Story), the client
-- shows them and speaks the lines (src/client/Features/Story).
-- Chapters are generated from Config.Worlds, so a world added later gets a chapter without touching this file.
-- WRITTEN holds the hand-written lines for the worlds it knows by name; any other world gets generic ones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)
local Tutorial = require(ReplicatedStorage.Shared.Features.Tutorial)

local Story = {}

local rgb = Color3.fromRGB

-- The guide: a talking cannonball in a captain's hat. He speaks every line that has no speaker of its own,
-- and his statue stands in the marketplace.
Story.Guide = {
	name = "Captain Kaboom",
	body = rgb(44, 46, 58),
	hat = rgb(38, 66, 150),
	trim = rgb(255, 200, 40),
	spark = rgb(255, 150, 40),
}

----------------------------------------------------------------------------------------------------
-- Rewards. Every number a quest pays is in this section.
--   gems    the premium currency (saved as diamonds)
--   coins   a fixed amount: only the tutorial uses it, to pay for the thing its next step asks for (those
--           numbers are the walkthrough's: Tutorial.Steps in src/shared/Features/Tutorial.luau)
--   clears  coins worth that many clears of an ordinary level at the player's own level (Config.levelPlan), so
--           it matters at every stage. For scale: a pad costs half a clear, an egg two and a half.
--           Never worked out past the chapter's last level: an old chapter cannot be saved up for a late payout.
--   items   backpack items other features define, looked up when the reward is given. An entry names an id, a
--           category, or both (the category is then the fallback): a category gives one of its most common
--           items, a different one each time. event = true only pays while the Halloween event is live.
--           An entry nothing matches is skipped.
--   pet     true adds the chapter's mini cannon (see Story.ChapterPets)
-- A quest's reward is paid the moment it is done. A chapter's reward is claimed in the STORY window.
-- The game is meant to be ground through: a whole chapter's quests pay about ten clears, its reward five more.
----------------------------------------------------------------------------------------------------
local function powerup(id: string, amount: number)
	return { id = id, category = "powerup", amount = amount }
end
local ANY_POWERUP = { category = "powerup", amount = 1 }
local CRATE = { category = "crate", amount = 1, event = true } -- crates are part of the Halloween event

Story.Rewards = {
	step = { clears = 0.5 }, -- travel to the world, clear level N, the small steps of the tutorial
	task = { clears = 1, items = { ANY_POWERUP } }, -- defeat, hatch, own, fuse (after the first), the tower goals
	mid = { gems = 10, clears = 2, items = { powerup("megadamage", 1), CRATE } },
	final = { gems = 15, clears = 3, items = { powerup("healfreeze", 1) } },
	chapter = {
		gems = 35,
		clears = 5,
		items = { powerup("luck2x", 2), { category = "crate", amount = 2, event = true } },
		pet = true,
	},
	firstBoss = { gems = 5, clears = 1 },
	firstHatch = { gems = 5 },
	firstFuse = { gems = 5, items = { ANY_POWERUP } },
}

-- One more item on top of a chapter's reward, by chapter number: the two ammo types the Ammo Forge sells for
-- coins, so the first chapters also show a new player what ammo is.
Story.ChapterGifts = {
	[1] = { id = "ammo_double", category = "ammo", amount = 1 },
	[2] = { id = "ammo_golden", category = "ammo", amount = 1 },
}

-- A chapter's mini cannon: the Exclusive named here if Config has it, otherwise the Legendary from that
-- world's own eggs. That one is worth having at any stage: it is as strong as a Common from the next world.
Story.ChapterPets = { [1] = "neon" }

-- The two side quests of every chapter after the first, taken in turn from these lists: one after the early
-- levels and one after the mid boss. Each time a task comes round again its n grows by `more`, up to `max`.
Story.EarlyTasks = {
	{ kind = "kills", n = 150, more = 150, max = 600 },
	{ kind = "hatches", n = 5, more = 5, max = 15 },
	{ kind = "bosses", n = 10, more = 5, max = 25 },
}
-- The tower goals have no n here: they are worked out from the level the chapter's mid boss stands on.
Story.LateTasks = {
	{ kind = "tower" }, -- one tower at TowerGoal.one of that level
	{ kind = "pads" }, -- every pad one clear of that level pays for; once all are owned, a tower on each (TowerGoal.all)
	{ kind = "own", n = 20, more = 10, max = 40 },
}
-- Fusing is done at the Fusion Machine on the island of world Config.FuseIsland (The Sun), so the story asks
-- for none before that world is reached. From its chapter on, every `every`th chapter's late side quest is
-- a fusing quest instead of one from the list above: the first asks for tier `n` (Silver) and each one after
-- it for one tier more (Gold, Diamond, then more than one Diamond).
Story.FuseTask = { from = Config.FuseIsland, every = 2, n = 1, more = 1 }
-- A tower's level ends up close to the level being fought (docs/BALANCE.md). The goals sit under that, so they
-- are met by playing on and never by pouring every coin into one tower. Rounded down to a multiple of `round`.
Story.TowerGoal = { one = 0.8, all = 0.6, round = 5 }

----------------------------------------------------------------------------------------------------
-- The words. Keep every line short enough to read on a phone in a few seconds.
-- A line is a string (the guide says it) or { boss = "mid" | "final", text = ... } (that boss says it).
-- The bosses' names are never typed out: <mid> and <final> stand for "the Ogre Chief" and "the Earth Titan"
-- (<Mid> and <Final> at the start of a sentence) and are filled in from Config, so a renamed boss stays right.
--   title, blurb         shown in the STORY window
--   place                the world's name as it reads inside a sentence
--   midName, finalName   the same for a boss whose name does not take "the"
--   intro                when the chapter starts
--   mid, final           when the quest to beat that boss starts
--   outro                when the chapter is finished; ending replaces it on the last world there is
----------------------------------------------------------------------------------------------------
local WRITTEN = {
	Earth = {
		title = "The First Spark",
		place = "Earth",
		blurb = "You are the newest Cannoneer. The Void King stole the Spark that lights each world, and <final> has Earth's.",
		intro = {
			"Ahoy, Cannoneer! I am Captain Kaboom. Monsters are marching on your base!",
			"Your cannon towers shoot all by themselves. Your job is to build them.",
		},
		mid = {
			"<Mid> guards the road ahead. Don't let him scare you!",
			{ boss = "mid", text = "ME SMASH TINY CANNON!" },
		},
		final = { "<Final> holds Earth's Spark. Go and get it, Cannoneer!" },
		outro = {
			"KABOOM! Earth's Spark is free and the sky is bright again!",
			"One world saved. But look up... the Moon has gone dark.",
		},
	},
	Moon = {
		title = "The Dark Moon",
		place = "the Moon",
		blurb = "Without its Spark the Moon went dark. <Final> is carrying it around.",
		intro = {
			"The Moon went dark when its Spark was taken. Spooky!",
			"Good thing cannons work in space. Probably.",
		},
		mid = {
			"Something is creeping on the dark side... <mid>!",
			{ boss = "mid", text = "You cannot hit what you cannot see..." },
		},
		final = { "<Final> is carrying the Moon's Spark. Knock it loose!" },
		outro = {
			"The Moon shines again! Night lights for everyone.",
			"Next stop: Mars. I hear the Void King left a Warlord in charge.",
		},
	},
	Mars = {
		title = "The Red Warlord",
		place = "Mars",
		blurb = "A Warlord rules Mars for the Void King. The Spark sits on top of Mount Olympus.",
		intro = {
			"Mars! Red sand, red rocks and very grumpy Martians.",
			"Their Spark is up on Mount Olympus. Long way up. Let's roll!",
		},
		mid = {
			"<Mid> works for the Void King. Send him packing!",
			{ boss = "mid", text = "Mars belongs to the Void King now!" },
		},
		final = { "<Final> sits on the Spark and will not share. Rude!" },
		outro = {
			"Mars is free! The Martians say thank you. I think. I don't speak Martian.",
			"Pack a coat. Neptune is next, and it is frozen solid.",
		},
	},
	Neptune = {
		title = "The Big Freeze",
		place = "Neptune",
		blurb = "Neptune froze over when its Spark was taken. <Final> keeps it locked in ice.",
		intro = {
			"Brrr! Neptune froze solid without its Spark.",
			"Even my fuse is shivering. Let's warm this place up!",
		},
		mid = {
			"This storm comes from <mid>. Blow it away!",
			{ boss = "mid", text = "Coooold... forever cooold..." },
		},
		final = { "<Final> froze the Spark in ice. Time to break the ice!" },
		outro = {
			"Neptune is thawing! Somebody get the Yetis a towel.",
			"Only one place is hotter than my cannon: the Sun!",
		},
	},
	["The Sun"] = {
		title = "Too Hot to Handle",
		place = "the Sun",
		blurb = "The Sun has the biggest Spark of all, and <final> guards it for the Void King.",
		intro = {
			"The Sun! Its Spark is the biggest one of all.",
			"The monsters heal in this heat. Don't worry, I packed sunscreen!",
		},
		mid = {
			"Bad dog! <Mid> is guarding the road.",
			{ boss = "mid", text = "GRRRRR! WOOF!" },
		},
		final = { "<Final> holds the biggest Spark. Don't look straight at it!" },
		outro = {
			"The Sun's Spark is safe! Every world is bright again... except one.",
			"The Void. That is where HE lives. Ready, Cannoneer?",
		},
	},
	["The Void"] = {
		title = "<Final>",
		place = "the Void",
		blurb = "The Void is the Void King's home. Beat him and the worlds keep their Sparks for good.",
		intro = {
			"This is it, Cannoneer. The Void. Home of the Void King.",
			{ boss = "final", text = "A cannonball and a rookie? This will be quick." },
		},
		mid = {
			"<Mid> guards the King's door. Knock, knock!",
			{ boss = "mid", text = "Nobody sees the King!" },
		},
		final = {
			"<Final> himself! Every Spark you saved is cheering for you.",
			{ boss = "final", text = "Your little cannons cannot hurt me!" },
		},
		outro = {
			"YOU DID IT! The Void King is beaten!",
			"But he sent Sparks from far-off worlds deep into space. After them!",
		},
		ending = {
			"YOU DID IT! The Void King is beaten and every world shines again!",
			"You are a legend, Cannoneer. Your towers have never looked better!",
		},
	},
	Nebula = {
		title = "Follow the Sparks",
		place = "the Nebula",
		blurb = "The Void King sent stolen Sparks deep into space. The trail starts in the Nebula, at the Queen's court.",
		intro = {
			"The Void King sent Sparks from far-off worlds out here. Let's follow them!",
			"It is one big space cloud. The monsters are quick, and they heal as they walk!",
		},
		mid = {
			"Something huge is hiding in the fog. <Mid>!",
			{ boss = "mid", text = "Bloooooop..." },
		},
		final = { "<Final> wears a crown of stolen Sparks. Knock it off!" },
		outro = {
			"The Nebula sparkles again! And the Queen dropped a map.",
			"It points to the Crystal Belt. Ooh, shiny!",
		},
	},
	["Crystal Belt"] = {
		title = "Crystal Fever",
		place = "the Crystal Belt",
		blurb = "Everything in the Crystal Belt is hard as a gem and worth a fortune. <Final> locked a Spark inside one.",
		intro = {
			"Whoa! The whole Crystal Belt is made of gems.",
			"The monsters are tough here, but they drop piles of coins. Ka-ching!",
		},
		mid = {
			"<Mid> is all spikes. Do NOT hug it.",
			{ boss = "mid", text = "HALT. NO TOUCHING THE CRYSTALS." },
		},
		final = { "<Final> locked a Spark inside a giant gem. Crack it open!" },
		outro = {
			"The Crystal Belt is free, and my hat has never been shinier.",
			"Hear that clanking? Somebody is BUILDING monsters. To the Robot Factory!",
		},
	},
	["Robot Factory"] = {
		title = "The Monster Factory",
		place = "the Robot Factory",
		blurb = "This factory builds monsters for the whole army, and a stolen Spark powers it. <Final> runs the line.",
		intro = {
			"So THIS is where the monster army comes from. A stolen Spark runs it all!",
			"Giants roll off the line much faster here. Stay sharp!",
		},
		mid = {
			"<Mid> flattens everything. Flatten it first!",
			{ boss = "mid", text = "CRUSH. CRUSH. CRUSH." },
		},
		final = { "<Final> runs the whole line. Time to switch it off!" },
		outro = {
			"Factory closed! No more new monsters. Look, the little robots are dancing.",
			"The trail leads into a jungle. A big, hungry, alien jungle.",
		},
	},
	["Alien Jungle"] = {
		title = "It's a Jungle Out There",
		place = "the Alien Jungle",
		blurb = "A stolen Spark made this jungle grow wild and hungry. <Final> swallowed it whole.",
		intro = {
			"Everything in this jungle wants to eat us. Even the flowers!",
			"Bosses heal as they walk here. Bring your hardest hitters!",
		},
		mid = {
			"<Mid> has far too many heads. Aim for... all of them!",
			{ boss = "mid", text = "Hisss! Hisss! Hisssss!" },
		},
		final = { "<Final> swallowed the Spark whole. Make it burp!" },
		outro = {
			"BURP! One Spark, a little slimy. The jungle is calm again.",
			"Uh oh. The stars ahead are being pulled into a Black Hole.",
		},
	},
	["Black Hole"] = {
		title = "<Final>",
		place = "the Black Hole",
		midName = "Graviton",
		blurb = "The Void King was feeding stolen Sparks to <final>. It lives in the Black Hole, where time runs short.",
		intro = {
			"Now I see who the Void King worked for. <Final> eats Sparks!",
			"Time runs fast near a Black Hole, and so do the monsters. Slow them down!",
		},
		mid = {
			"<Mid> pulls everything in. Hold on to your hat! And to mine!",
			{ boss = "mid", text = "EVERYTHING FALLS." },
		},
		final = {
			"<Final> ate a whole sky of Sparks. Make it give them back!",
			{ boss = "final", text = "MORE. I NEED MORE." },
		},
		outro = {
			"It is letting go! Thousands of Sparks are flying home.",
			"One Spark is still missing. The very first one. It is at the Big Bang.",
		},
	},
	["The Big Bang"] = {
		title = "Where It All Began",
		place = "the Big Bang",
		blurb = "The Big Bang is where the very first Spark was born. <Final> guards it, and it is the final test.",
		intro = {
			"The Big Bang. This is where the very first Spark was born.",
			"Everything here is as strong as it gets. Luckily, so are you!",
		},
		mid = {
			"<Mid> says everything must end. Rude! Stop it!",
			{ boss = "mid", text = "ALL THINGS END!" },
		},
		final = {
			"<Final> guards the first Spark. This is the final test!",
			{ boss = "final", text = "SHOW ME YOUR POWER, CANNONEER." },
		},
		outro = {
			"YOU DID IT! The first Spark is safe, and <final> bows to you.",
			"But I can see new lights out there. New worlds! Onward!",
		},
		ending = {
			"YOU DID IT! The first Spark is safe and every world shines again!",
			"You are the greatest Cannoneer ever. Nothing gets past your towers!",
		},
	},
}

local WAVES = Config.WavesPerWorld
local MID_WAVE = WAVES / 2 -- the level of a world where Config.waveKind puts the mid boss
local EARLY_WAVE = math.floor(WAVES / 5)
local LATE_WAVE = WAVES - EARLY_WAVE

local function tierName(tier: number): string
	local def = Config.FuseTiers[tier]
	return if def then def.name else "fused"
end

-- A boss's name as it reads inside a sentence: "Frost Giant" -> "the Frost Giant", "The Devourer" -> "the Devourer".
local function withThe(name: string): string
	return "the " .. (string.gsub(name, "^The ", ""))
end

local function capital(text: string): string
	return (string.gsub(text, "^%l", string.upper))
end

-- kind -> the quest's title and what the guide says about it, for the amount n in that world.
local TASK_TEXT = {
	kills = function(n: number)
		return `Defeat {n} monsters`, `Monsters everywhere! Your towers must defeat {n} of them. Any level counts.`
	end,
	hatches = function(n: number)
		return `Hatch {n} eggs`, `New eggs are waiting on this world's island. Hatch {n} of them!`
	end,
	bosses = function(n: number, world)
		local every = (world.rules or {}).bossEvery or Config.BossEvery
		local pay = Config.WaveKinds.boss.coins
		return `Defeat {n} giant monsters`, `A giant pays as much as {pay} monsters. Defeat {n}! One comes every {every} levels.`
	end,
	own = function(n: number)
		return `Own {n} mini cannons`, `Own {n} mini cannons. More eggs, more boom!`
	end,
	pads = function(n: number)
		return `Own {n} pads`, `More pads, more towers! Buy pads beside the path until you own {n}.`
	end,
}

-- The same for the tower goals: n towers at this level or higher.
local function towerText(n: number, level: number): (string, string)
	if n > 1 then
		return `Get {n} towers to level {level}`, `Every pad counts! Upgrade until {n} of your towers are level {level}.`
	end
	return `Get a tower to level {level}`, `Walk up to a tower and press UPGRADE until it is level {level}. It changes its look every 10 levels!`
end

-- The same for a fusing quest: own n mini cannons fused to this tier or better.
local function fuseText(tier: number, n: number): (string, string)
	local name = tierName(tier)
	if n > 1 then
		return `Own {n} {name} mini cannons`, `{name} mini cannons are the best there are. Fuse until you own {n}!`
	end
	local from = if tier > 1 then `{tierName(tier - 1)} ones` else "mini cannons"
	return `Fuse a {name} mini cannon`, `Fuse a {name} mini cannon. It takes {Config.FuseCount} {from} of the same kind!`
end

----------------------------------------------------------------------------------------------------
-- Quests. Every quest is { kind, n, title, say, reward } plus what its kind needs; the server's GOALS table
-- says how each kind is measured. n is what the progress bar counts up to.
----------------------------------------------------------------------------------------------------
-- Written text with the bosses' names filled in. names is { mid, final, Mid, Final }.
local function named(text: string, names): string
	return (string.gsub(text, "<(%a+)>", names))
end

-- Written lines as the client shows them: a string for the guide, { who, color, text } for a boss.
local function spoken(lines, world, names)
	local result = {}
	for _, line in lines do
		if typeof(line) == "table" then
			local boss = (if line.boss == "mid" then world.midBoss else world.finalBoss) or {}
			table.insert(result, {
				who = boss.name or "???",
				color = boss.color or rgb(200, 60, 80),
				text = named(line.text, names),
			})
		else
			table.insert(result, named(line, names))
		end
	end
	return result
end

-- "Clear this world's level n". from is the last level before the world, so progress counts inside the world.
local function clearWave(from: number, n: number, title: string, say, reward)
	return { kind = "wave", from = from, n = n, title = title, say = say, reward = reward }
end

-- Pads a player can be asked to own by this level: every pad that one clear of it pays for. The second
-- number is how many pads there are in all (Config.padPrice is infinite past the last).
local function padsBy(level: number): (number, number)
	local budget = Config.levelCoins(level)
	local affordable, all = 1, 1
	while Config.padPrice(all + 1) < math.huge do
		all += 1
		if Config.padPrice(all) <= budget then
			affordable = all
		end
	end
	return affordable, all
end

-- The tower level a goal asks for at this level of the game.
local function towerGoal(level: number, share: number): number
	local goal = Story.TowerGoal
	local target = math.floor(level * share / goal.round) * goal.round
	return math.clamp(target, 2, Config.TowerMaxLevel)
end

-- "n towers at this level or higher".
local function towerQuest(n: number, level: number)
	local title, line = towerText(n, level)
	return { kind = "towers", level = level, n = n, title = title, say = { line }, reward = Story.Rewards.task }
end

-- The fusing quest of a chapter, or nil for a chapter that has none (see Story.FuseTask).
local function fuseQuest(index: number)
	local task = Story.FuseTask
	local turn = index - task.from
	if turn < 0 or turn % task.every ~= 0 then
		return nil
	end
	local lap = turn // task.every
	-- Past the top tier there is nothing higher to ask for, so later ones ask for more of that tier.
	local top = math.max(1, #Config.FuseTiers)
	local tier = task.n + lap * task.more
	local n = 1 + math.max(0, tier - top)
	tier = math.min(tier, top)
	local title, line = fuseText(tier, n)
	local say = { line }
	local reward = Story.Rewards.task
	if lap == 0 then
		-- The first one explains what fusing is and where it is done.
		local island = (Config.Worlds[task.from] or {}).name or "this world"
		say = {
			`Here is a secret: {Config.FuseCount} of the same mini cannon can FUSE into a stronger one.`,
			`The Fusion Machine stands on the {island} island. Open WORLDS, press ISLAND, pick three and press FUSE!`,
		}
		reward = Story.Rewards.firstFuse
	end
	return { kind = "fused", tier = tier, n = n, title = title, say = say, reward = reward }
end

-- A chapter's side quest: the list is walked one chapter at a time, and every lap raises the amount.
-- level is where the chapter's mid boss stands: the tower goals are sized for it.
local function sideQuest(tasks, index: number, world, level: number)
	local turn = index - 2 -- the first chapter is the tutorial and has none
	local def = tasks[turn % #tasks + 1]
	local lap = turn // #tasks
	if def.kind == "tower" then
		return towerQuest(1, towerGoal(level, Story.TowerGoal.one))
	end
	local n
	if def.kind == "pads" then
		local affordable, all = padsBy(level)
		if affordable >= all then
			-- Every pad is owned by now: ask for a tower on each of them instead.
			return towerQuest(all, towerGoal(level, Story.TowerGoal.all))
		end
		n = affordable
	else
		n = math.min(def.n + lap * def.more, def.max)
		if def.kind == "own" then
			n = math.min(n, Config.MaxPets)
		end
	end
	local title, line = TASK_TEXT[def.kind](n, world)
	return { kind = def.kind, n = n, title = title, say = { line }, reward = Story.Rewards.task }
end

-- The first chapter doubles as the tutorial, and stands behind the walkthrough a new player is led through
-- (src/shared/Features/Tutorial.luau): the same things in the same order, as a quest list. Walk to the cannon,
-- upgrade it, clear a level, buy a pad, build on it, hatch an egg on the island, beat a giant, visit the
-- marketplace, build another kind of tower, and the two bosses. (Fusing is not in it: the Fusion Machine
-- stands on a later world's island. Story.FuseTask says where the story first asks for it.)
-- A quest with `tutorial = <step id>` asks for what that walkthrough step asks for. Its reward is that step's,
-- and it is paid once: by the walkthrough or by the quest, whichever sees it done first (Tutorial.take).
-- The upgrade comes first, before anything has to be cleared: a player who never upgrades is stopped by the
-- first giant, and the play test showed new players waiting in front of it.
-- A new player starts with a Cannon already standing on their free first pad (Data.luau), so "build a cannon"
-- comes after "buy a second pad": that is the first pad there is anything to build on.
-- Its early rewards pay for the very thing the next step asks for, so nobody waits on coins while learning.
local function tutorial(from: number, midQuest, finalQuest)
	local rewards = Story.Rewards
	local egg = Config.Eggs[1] or {}
	local eggName = egg.name or "first egg"
	-- The first egg stands on its world's island (src/server/Islands.luau), not in the marketplace.
	local islandName = (Config.Worlds[egg.world or 1] or {}).name or "the first world"
	local cannon = Config.Towers.cannon
	-- The second kind of tower a new player can build.
	local second = Config.Towers[Config.TowerOrder[2]] or cannon
	local boss = Config.BossEvery
	local clearOne = clearWave(
		from,
		1,
		"Clear level 1",
		{
			"These monsters work for the Void King. He stole the Spark of every world!",
			"Each one that reaches your gate costs lives. Defeat them all to clear the level.",
		},
		Tutorial.reward("clear")
	)
	clearOne.tutorial = "clear"
	return {
		{
			kind = "pad",
			n = 1,
			title = "Walk to your cannon",
			say = { "See the cannon on the pad beside the path? Walk up to it!" },
			reward = Tutorial.reward("pad"),
			tutorial = "pad",
		},
		{
			kind = "upgrade",
			n = 1,
			title = "Upgrade your cannon",
			say = {
				"It shoots every monster in its range, all by itself. But it needs more boom!",
				"Press UPGRADE at your cannon. The first one is on me!",
			},
			reward = Tutorial.reward("upgrade"),
			tutorial = "upgrade",
		},
		clearOne,
		{
			kind = "pads",
			n = 2,
			title = "Buy a second pad",
			say = { "One cannon is not enough. Walk to a pad with a FOR SALE sign and buy it. My treat!" },
			reward = Tutorial.reward("pad2"),
			tutorial = "pad2",
		},
		{
			kind = "towers",
			level = 1,
			n = 2,
			title = `Build a {cannon.name} on your new pad`,
			say = { `An empty pad! Walk up to it and build a {cannon.name}. I am paying!` },
			reward = Tutorial.reward("build"),
			tutorial = "build",
		},
		{
			kind = "hatched",
			n = 1,
			title = "Hatch an egg",
			say = { `Eggs hatch mini cannons! Open WORLDS, press ISLAND on {islandName} and hatch the {eggName} there.` },
			reward = Tutorial.reward("hatch"),
			tutorial = "hatch",
		},
		clearWave(
			from,
			boss,
			`Beat the first giant (level {boss})`,
			{
				"A mini cannon! It follows you and adds its own DPS to your base, wherever you are.",
				`Every {boss} levels a GIANT comes. If it reaches your gate, the level is lost!`,
			},
			rewards.firstBoss
		),
		{
			kind = "market",
			n = 1,
			title = "Visit the marketplace",
			say = { "Great job! Your towers keep shooting without you. Come and see me in town: press MARKET." },
			reward = rewards.step,
		},
		{
			kind = "kinds",
			n = 2,
			title = "Build a second kind of tower",
			say = { `Now go home and build a {second.name} on a free pad. Different towers are good at different things!` },
			reward = rewards.task,
		},
		midQuest,
		finalQuest,
	}
end

-- What finishing the chapter pays: the same for every chapter, plus the gift Story.ChapterGifts lists for it.
local function chapterReward(index: number)
	local reward = table.clone(Story.Rewards.chapter)
	local gift = Story.ChapterGifts[index]
	if gift then
		reward.items = table.clone(reward.items)
		table.insert(reward.items, gift)
	end
	return reward
end

local function buildChapter(index: number, world)
	local written = WRITTEN[world.name] or {}
	local from = (index - 1) * WAVES
	local place = written.place or (string.gsub(world.name, "^The ", "the "))
	local mid = written.midName or withThe((world.midBoss or {}).name or "mid boss")
	local final = written.finalName or withThe((world.finalBoss or {}).name or "world boss")
	local monster = ((world.monsters or {})[1] or {}).name or "A new monster"
	local isLast = index == #Config.Worlds
	local names = { mid = mid, final = final, Mid = capital(mid), Final = capital(final) }

	local midQuest = clearWave(
		from,
		MID_WAVE,
		`Beat {mid} (level {MID_WAVE})`,
		spoken(written.mid or { "<Mid> guards the road ahead. Blast through!" }, world, names),
		Story.Rewards.mid
	)
	local finalQuest = clearWave(
		from,
		WAVES,
		`Beat {final} (level {WAVES})`,
		spoken(written.final or { "<Final> holds this world's Spark. One more big boom!" }, world, names),
		Story.Rewards.final
	)

	local quests
	if index == 1 then
		quests = tutorial(from, midQuest, finalQuest)
	else
		quests = {
			{
				kind = "travel",
				from = from,
				n = 1,
				title = `Travel to {place}`,
				say = { `Open WORLDS and press TRAVEL to fly to {place}.` },
				reward = Story.Rewards.step,
			},
			clearWave(
				from,
				EARLY_WAVE,
				`Clear level {EARLY_WAVE}`,
				{ `First up: {monster}. Clear level {EARLY_WAVE}!` },
				Story.Rewards.step
			),
			sideQuest(Story.EarlyTasks, index, world, from + MID_WAVE),
			midQuest,
			fuseQuest(index) or sideQuest(Story.LateTasks, index, world, from + MID_WAVE),
			clearWave(
				from,
				LATE_WAVE,
				`Clear level {LATE_WAVE}`,
				{ `The big boss is close. Clear level {LATE_WAVE}!` },
				Story.Rewards.step
			),
			finalQuest,
		}
	end

	-- A world this file has no words for: the same story with its own names, and its twist as a warning.
	local intro = written.intro
	if not intro then
		intro = {
			`More monsters! The Void King's army reached {place} too.`,
			`{monster} and friends are everywhere. Time to clean up!`,
		}
		if world.twist then
			table.insert(intro, `Heads up! {world.twist}.`)
		end
	end
	local ending = written.ending or { `{world.name} is free, and so is every world! You are a legend, Cannoneer.` }
	local outro = written.outro or { `KABOOM! {world.name} has its Spark back. Another world saved!` }
	local blurb = written.blurb or `The Void King's monsters took the Spark of {place}. <Final> is holding it.`
	return {
		index = index,
		world = world.name,
		title = named(written.title or `The Spark of {world.name}`, names),
		blurb = named(blurb, names),
		from = from,
		last = from + WAVES, -- beating this level finishes the chapter, whatever quest it was on
		intro = spoken(intro, world, names),
		outro = spoken(if isLast then ending else outro, world, names),
		quests = quests,
		reward = chapterReward(index),
	}
end

Story.Chapters = {}
do
	local turn = 0
	for index, world in Config.Worlds do
		local chapter = buildChapter(index, world)
		-- turn numbers every quest in the story: it decides which item of a category a quest gives.
		for _, quest in chapter.quests do
			turn += 1
			quest.turn = turn
		end
		Story.Chapters[index] = chapter
	end
end

----------------------------------------------------------------------------------------------------
-- Working out a reward. The server pays what Story.resolve returns and the client shows the same thing.
----------------------------------------------------------------------------------------------------
-- Coins one clear of an ordinary level pays around this level (Config.levelPlan: the world's own rules
-- count, the player's coin multiplier does not). A boss level pays by rules of its own, so the nearest
-- ordinary level below it is the measure. A swarm or a pack of tanks pays the same in all as a plain level.
local function clearCoins(level: number): number
	while level > 1 and Config.waveKind(level) ~= "normal" do
		level -= 1
	end
	local plan = Config.levelPlan(level)
	return plan.count * plan.coins
end

-- The level a "clears" reward is worked out for: the furthest the player has got, but never past the
-- chapter's own last level.
function Story.payWave(chapter, wave: number, cleared: number): number
	return math.clamp(math.max(wave, cleared), 1, chapter.last)
end

local RARITY_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

-- The item a reward entry gives right now, or nil when nothing fits (see "items" at the top of the file).
local function pickItem(entry, turn: number, eventLive: boolean)
	if entry.event and not eventLive then
		return nil
	end
	local named = if entry.id then Items.get(entry.id) else nil
	if named or not entry.category then
		return named
	end
	-- Only the most common items of the category, and nothing that is of no use outside the event.
	local pool, lowest = {}, math.huge
	for _, def in Items.all() do
		if def.category == entry.category and (eventLive or not def.event) then
			local rank = if def.rarity then RARITY_RANK[def.rarity] or 6 else 0
			if rank < lowest then
				pool, lowest = {}, rank
			end
			if rank == lowest then
				table.insert(pool, def)
			end
		end
	end
	table.sort(pool, function(a, b)
		local orderA, orderB = a.order or 0, b.order or 0
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a.id < b.id
	end)
	return pool[(turn - 1) % math.max(1, #pool) + 1]
end

-- The mini cannon a chapter's reward includes, or nil when Config has nothing for it.
local function chapterPet(index: number): string?
	local named = Story.ChapterPets[index]
	local exclusive = if named then Config.Pets[named] else nil
	if exclusive and exclusive.rarity == "Exclusive" then
		return named
	end
	local best: string? = nil
	for _, egg in Config.Eggs do
		if egg.world == index and egg.currency == "coins" and not egg.event then
			for _, entry in egg.pets do
				local pet = Config.Pets[entry.id]
				if pet and pet.rarity == "Legendary" and (not best or pet.bonus > Config.Pets[best].bonus) then
					best = entry.id
				end
			end
		end
	end
	return best
end

-- What a reward pays right now: { gems, coins, items = { { id, name, amount } }, pets = { id } }.
-- wave comes from Story.payWave. turn is the quest's turn, or the chapter's number for a chapter reward, and
-- chapter is that same number: only a chapter reward can hold a mini cannon.
function Story.resolve(spec, wave: number, turn: number, chapter: number?)
	local reward = { gems = spec.gems or 0, coins = spec.coins or 0, items = {}, pets = {} }
	if spec.clears then
		reward.coins += math.floor(spec.clears * clearCoins(wave))
	end
	-- The server's clock on both sides, so the client never shows an event item the server would not give.
	local eventLive = Config.halloweenActive(workspace:GetServerTimeNow())
	for _, entry in spec.items or {} do
		local def = pickItem(entry, turn, eventLive)
		if def then
			table.insert(reward.items, { id = def.id, name = def.name, amount = entry.amount })
		end
	end
	local pet = if spec.pet and chapter then chapterPet(chapter) else nil
	if pet then
		table.insert(reward.pets, pet)
	end
	return reward
end

-- Adds one resolved reward onto another, so several quests finished at once read as one total.
function Story.add(total, reward)
	total.gems += reward.gems
	total.coins += reward.coins
	for _, item in reward.items do
		local held = nil
		for _, other in total.items do
			if other.id == item.id then
				held = other
			end
		end
		if held then
			held.amount += item.amount
		else
			table.insert(total.items, { id = item.id, name = item.name, amount = item.amount })
		end
	end
	for _, pet in reward.pets do
		table.insert(total.pets, pet)
	end
end

-- "+10 💎  +1.20K 💰  +1 2x Power  Mini Neon Cannon", or "" for a reward that pays nothing.
-- short keeps it to one narrow line for the HUD: the items and mini cannons become "+3 more".
function Story.rewardText(reward, short: boolean?): string
	local parts = {}
	if reward.gems > 0 then
		table.insert(parts, `+{reward.gems} 💎`)
	end
	if reward.coins > 0 then
		table.insert(parts, `+{Format.abbreviate(reward.coins)} 💰`)
	end
	if short then
		local more = #reward.pets
		for _, item in reward.items do
			more += item.amount
		end
		if more > 0 then
			table.insert(parts, `+{more} more`)
		end
		return table.concat(parts, "  ")
	end
	for _, item in reward.items do
		table.insert(parts, `+{item.amount} {item.name}`)
	end
	for _, pet in reward.pets do
		table.insert(parts, Config.Pets[pet].name)
	end
	return table.concat(parts, "  ")
end

return Story
