-- Server side of the story: follows each player's active quest, pays the rewards and builds Captain Kaboom's
-- statue in the marketplace. The chapters, quests and reward numbers are in src/shared/Features/Story.
-- One quest is active at a time. Saved (data.features.story): the chapter and quest the player is on, the
-- count of a counting quest, and which chapter rewards were claimed.
-- Counting quests are counted in memory by the kill and hatch hooks. Everything else is read from the
-- player's data (pads, towers, levels, mini cannons) on the tick hook, twice a second, so a goal that is
-- already met completes at once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Story = require(ReplicatedStorage.Shared.Features.Story)
local Tutorial = require(ReplicatedStorage.Shared.Features.Tutorial)
local Build = require(script.Parent.Parent.Build)
local Marketplace = require(script.Parent.Parent.Marketplace)

local PUBLISH_SECONDS = 1 -- a quest's progress reaches the client at most this often
local PAD_REACH = 12 -- studs from a pad's centre that count as "walked up to it": about its prompt's reach
local GUIDE_SPOT = Vector3.new(-30, 0, 26) -- marketplace space: between the arrival pad and the first eggs
local DEFAULTS = { chapter = 1, quest = 1, count = 0, claimed = {} }

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local Game -- the plug-in API, handed to start
local sessions = {} -- [player] = { save, kind, have, need, sent, dirty }

----------------------------------------------------------------------------------------------------
-- Goals: how far a quest of each kind is. The result is capped at quest.n, which is "done".
-- Each one is fn(data, state, save, quest, player) -> number.
----------------------------------------------------------------------------------------------------
local GOALS = {}

-- Best-ever level. quest.from is the last level before the world.
function GOALS.wave(data, _state, _save, quest): number
	return data.bestCleared - quest.from
end

-- The highest level among the player's towers, and how many kinds of tower they have standing.
local function towerStats(data): (number, number)
	local highest, kinds, seen = 0, 0, {}
	for _, tower in data.towers do
		highest = math.max(highest, tower.level)
		if not seen[tower.kind] then
			seen[tower.kind] = true
			kinds += 1
		end
	end
	return highest, kinds
end

-- "Walk to your cannon": the player's character stands by one of their own pads. Anyone who has already
-- upgraded a tower or bought a pad has been at one.
function GOALS.pad(data, state, _save, _quest, player: Player): number
	if #data.pads > 1 or towerStats(data) > 1 then
		return 1
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	if not root or state.inMarket or not state.slot then
		return 0
	end
	for _, pad in data.pads do
		if Layout.PADS[pad] then
			local offset = root.Position - Layout.padPosition(state.slot, pad)
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= PAD_REACH then
				return 1
			end
		end
	end
	return 0
end

-- A tower above level 1. A new player's only tower is level 1 (Data.luau), and a tower's level never drops
-- (a tower that is sold and built again starts over, but the last tower cannot be sold).
function GOALS.upgrade(data): number
	local highest = towerStats(data)
	return if highest > 1 then 1 else 0
end

function GOALS.pads(data): number
	return #data.pads
end

-- How many towers are at quest.level or higher. At level 1 that is simply how many towers are standing.
function GOALS.towers(data, _state, _save, quest): number
	local count = 0
	for _, tower in data.towers do
		if tower.level >= quest.level then
			count += 1
		end
	end
	return count
end

-- How many kinds of tower are standing at once.
function GOALS.kinds(data): number
	local _, kinds = towerStats(data)
	return kinds
end

-- Standing in the marketplace. (The quest comes after the first hatch, on an island: having hatched says
-- nothing about having been to town.)
function GOALS.market(_data, state): number
	return if state.inMarket then 1 else 0
end

function GOALS.hatched(data): number
	return data.totalHatches
end

-- The tier a mini cannon was fused to, 0 for one that never was. A Huge sits at the top tier in Config without
-- ever having been fused, so it does not count.
local function fusedTier(id: string): number
	local pet = Config.Pets[id]
	return if pet and not pet.huge then pet.tier or 0 else 0
end

-- How many mini cannons are fused to the quest's tier or better.
function GOALS.fused(data, _state, _save, quest): number
	local count = 0
	for _, id in data.pets do
		if fusedTier(id) >= quest.tier then
			count += 1
		end
	end
	return count
end

function GOALS.own(data): number
	return #data.pets
end

-- Fighting in the world, or already past its first level.
function GOALS.travel(data, _state, _save, quest): number
	return if data.wave > quest.from or data.bestCleared > quest.from then 1 else 0
end

-- Counted by the kill and hatch hooks while the quest is the active one.
local function counted(_data, _state, save): number
	return save.count
end
GOALS.kills = counted
GOALS.bosses = counted
GOALS.hatches = counted

-- A chapter whose world boss is already beaten is finished whatever its quests ask for, so a player who is
-- far ahead is never held up by an early chapter.
local function progress(player: Player, data, state, save, chapter, quest): number
	if data.bestCleared >= chapter.last then
		return quest.n
	end
	local goal = GOALS[quest.kind]
	-- A quest of a kind this file does not know must not stop the story: it counts as done.
	return if goal then math.clamp(goal(data, state, save, quest, player), 0, quest.n) else quest.n
end

----------------------------------------------------------------------------------------------------
-- Paying and publishing
----------------------------------------------------------------------------------------------------
-- reward is what Story.resolve returned: the items and mini cannon in it exist, or they were left out.
local function pay(player: Player, data, reward)
	data.diamonds += reward.gems
	data.coins += reward.coins
	for _, item in reward.items do
		Game.items.give(player, item.id, item.amount)
	end
	for _, pet in reward.pets do
		Game.pets.add(player, pet, true)
	end
end

-- The client draws the tracker, the dialogue and the STORY window from this.
local function publish(player: Player, session)
	local save = session.save
	session.dirty = false
	session.sent = os.clock()
	Game.setMeta(player, "story", {
		chapter = save.chapter,
		quest = save.quest,
		have = session.have,
		need = session.need,
		claimed = save.claimed,
	})
end

-- Finishes the active quest if its goal is met, then every quest after it that is met already, and pays for
-- them all with one toast. Runs twice a second for each player.
local function step(player: Player, data, state)
	local session = sessions[player]
	if not session then
		return
	end
	local save = session.save
	local total = { gems = 0, coins = 0, items = {}, pets = {} }
	local done, chapters, lastDone = 0, 0, nil

	local chapter = Story.Chapters[save.chapter]
	local quest = chapter and chapter.quests[save.quest]
	local have = 0
	while chapter and quest do
		have = progress(player, data, state, save, chapter, quest)
		if have < quest.n then
			break
		end
		local reward = Story.resolve(quest.reward, Story.payWave(chapter, data.wave, data.cleared), quest.turn)
		-- A quest the walkthrough has a step for shares that step's one payment (src/shared/Features/Tutorial.luau):
		-- when the walkthrough has paid for it already, the quest is ticked off and pays nothing.
		if quest.tutorial and not Tutorial.take(Game.feature(data, "tutorial", Tutorial.SAVED), quest.tutorial) then
			reward = Story.resolve({}, 1, quest.turn)
		end
		-- The quest is ticked off before it is paid: if paying ever failed, the next tick must not pay it again.
		save.count = 0
		if save.quest < #chapter.quests then
			save.quest += 1
		else
			save.chapter += 1
			save.quest = 1
			chapters += 1
		end
		done += 1
		lastDone = quest
		pay(player, data, reward)
		Story.add(total, reward)
		chapter = Story.Chapters[save.chapter]
		quest = chapter and chapter.quests[save.quest]
		have = 0
	end

	-- The kill and hatch hooks read this instead of looking the quest up on every kill.
	session.kind = if quest then quest.kind else nil
	local need = if quest then quest.n else 0
	if have ~= session.have or need ~= session.need then
		session.have, session.need = have, need
		session.dirty = true
	end

	if done > 0 then
		-- One toast however many quests it was: a catch-up reads as a total, not as a wall of messages.
		local what = if done == 1 then `Quest done: {lastDone.title}!` else `{done} quests done!`
		local text = Story.rewardText(total, done > 1)
		Game.notify(player, if text == "" then what else `{what}  {text}`, "good")
		if chapters == 1 then
			Game.notify(player, `Chapter {save.chapter - 1} complete! Claim your reward in STORY.`, "good")
		elseif chapters > 1 then
			Game.notify(player, `{chapters} chapters complete! Claim your rewards in STORY.`, "good")
		end
		Game.sync(player)
		session.dirty = true
	end
	if session.dirty and (done > 0 or os.clock() - session.sent >= PUBLISH_SECONDS) then
		publish(player, session)
	end
end

local function onReady(player: Player, data, state)
	local save = Game.feature(data, "story", DEFAULTS)
	-- A save from an older layout of the story must still point at a quest that exists.
	save.chapter = math.clamp(math.floor(tonumber(save.chapter) or 1), 1, #Story.Chapters + 1)
	local chapter = Story.Chapters[save.chapter]
	save.quest = if chapter then math.clamp(math.floor(tonumber(save.quest) or 1), 1, #chapter.quests) else 1
	save.count = tonumber(save.count) or 0
	if typeof(save.claimed) ~= "table" then
		save.claimed = {}
	end
	sessions[player] = { save = save, have = -1, need = -1, sent = 0, dirty = true }
	-- Catches a returning player up before their first sync.
	step(player, data, state)
end

-- Chapter rewards are claimed in the STORY window. index is the chapter's number.
local function claim(player: Player, data, _state, index: unknown)
	local session = sessions[player]
	local chapter = if typeof(index) == "number" then Story.Chapters[index] else nil
	if not session or not chapter then
		return
	end
	local save = session.save
	local key = tostring(chapter.index) -- a string, so the saved table stays a plain dictionary
	if chapter.index >= save.chapter or save.claimed[key] then
		return
	end
	local wave = Story.payWave(chapter, data.wave, data.cleared)
	local reward = Story.resolve(chapter.reward, wave, chapter.index, chapter.index)
	-- Marked before it is paid, like a quest: a claim that failed half way must not be claimable again.
	save.claimed[key] = true
	-- The mini cannon goes first and unforced: a full storage must not lose a stronger one to it.
	-- Nothing else is paid yet, so the claim can still be given back.
	local pets = reward.pets
	if pets[1] and not Game.pets.add(player, pets[1], false) then
		save.claimed[key] = nil
		Game.notify(player, "Free a mini cannon slot to claim this reward", "bad")
		return
	end
	reward.pets = {}
	pay(player, data, reward)
	reward.pets = pets -- back in, so the message below still names it
	publish(player, session)
	Game.notify(player, `Chapter {chapter.index} reward: {Story.rewardText(reward)}`, "good")
end

----------------------------------------------------------------------------------------------------
-- Captain Kaboom in the marketplace: a cannonball in a captain's hat with a lit fuse, on a plinth.
-- His prompt carries Window = "STORY", which the client opens with no server code.
----------------------------------------------------------------------------------------------------
local function buildGuide()
	local guide = Story.Guide
	local spot = Marketplace.frame(GUIDE_SPOT.X, GUIDE_SPOT.Y, GUIDE_SPOT.Z).Position
	local centre = Marketplace.frame(0, GUIDE_SPOT.Y, 0).Position
	-- Floor level, with -Z (his face) towards the golden cannon in the middle of the square.
	local frame = CFrame.lookAt(spot, centre)
	local model = Instance.new("Model")
	model.Name = "StoryGuide"

	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		return Build.part({
			Name = name,
			Size = size,
			CFrame = frame * offset,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = model,
		})
	end
	local function ball(name: string, size: number, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local part = piece(name, Vector3.one * size, offset, color, material)
		part.Shape = Enum.PartType.Ball
		return part
	end
	local function disc(name: string, base: CFrame, radius: number, height: number, color: Color3, material: Enum.Material?): Part
		return Build.pillar(frame * base, radius, height, {
			Name = name,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = model,
		})
	end

	local plinth = 0.8
	disc("Plinth", CFrame.new(), 3.4, plinth, rgb(150, 150, 158), Enum.Material.Marble).CanCollide = true
	for _, side in { -1, 1 } do
		piece("Boot", Vector3.new(1.3, 0.7, 1.9), CFrame.new(side * 0.95, plinth + 0.35, -0.2), rgb(92, 64, 44))
	end

	local middle = plinth + 3.1 -- the centre of his body, a ball 5 studs across
	local body = ball("Body", 5, CFrame.new(0, middle, 0), guide.body, Enum.Material.Metal)
	body.CanCollide = true
	for _, side in { -1, 1 } do
		ball("Eye", 1, CFrame.new(side * 0.75, middle + 0.55, -2.15), WHITE)
		ball("Pupil", 0.5, CFrame.new(side * 0.75, middle + 0.55, -2.58), BLACK)
		ball("Hand", 1.2, CFrame.new(side * 2.9, middle - 0.3, -0.6), WHITE)
	end
	piece("Smile", Vector3.new(1.5, 0.25, 0.3), CFrame.new(0, middle - 0.75, -2.3), WHITE)

	local hat = middle + 2.15 -- the brim sits just below the top of his head
	disc("HatBrim", CFrame.new(0, hat, 0), 2.3, 0.3, guide.hat)
	disc("Hat", CFrame.new(0, hat + 0.3, 0), 1.5, 1.5, guide.hat)
	disc("HatBand", CFrame.new(0, hat + 0.3, 0), 1.56, 0.4, guide.trim, Enum.Material.Metal)
	ball("HatBadge", 0.6, CFrame.new(0, hat + 1.15, -1.5), guide.trim, Enum.Material.Neon)
	disc("Fuse", CFrame.new(0.5, hat + 1.8, 0.3), 0.15, 1, rgb(196, 170, 120))
	local spark = ball("Spark", 0.7, CFrame.new(0.5, hat + 3, 0.3), guide.spark, Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Range = 12
	glow.Brightness = 1.2
	glow.Color = guide.spark
	glow.Parent = spark

	-- A spyglass in his right hand, trained on the golden cannon.
	local aim = frame:VectorToWorldSpace(Vector3.new(0, 0.35, -1).Unit)
	local hand = (frame * CFrame.new(2.9, middle - 0.3, -0.6)).Position
	Build.part({
		Name = "Spyglass",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 0.6, 0.6),
		CFrame = Build.along(hand + aim * 1.1, aim),
		Color = guide.trim,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = model,
	})

	-- The sign hangs over the body, not the hat: a billboard's offset follows its part's own axes, and the
	-- hat is a cylinder turned on its side.
	local sign = Build.billboard(body, Vector2.new(13, 3.4), Vector3.new(0, 7.4, 0), 140)
	local title = Build.label(sign, string.upper(guide.name))
	title.Size = UDim2.fromScale(1, 0.58)
	title.TextColor3 = guide.trim
	local sub = Build.label(sign, "📖 STORY  •  quests and rewards")
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)

	Build.prompt(body, "Talk", guide.name):SetAttribute("Window", "STORY")
	model.PrimaryPart = body
	model.Parent = Marketplace.container()
end

----------------------------------------------------------------------------------------------------
local function start(core)
	Game = core
	Game.actions.storyClaim = claim
	Game.on("ready", onReady)
	Game.on("tick", step)
	Game.on("leave", function(player: Player)
		sessions[player] = nil
	end)
	Game.on("kill", function(player: Player, _data, _state, info)
		local session = sessions[player]
		if session and (session.kind == "kills" or (session.kind == "bosses" and info.kind ~= "normal")) then
			session.save.count += 1
		end
	end)
	Game.on("hatch", function(player: Player, _data, _state, _egg, results)
		local session = sessions[player]
		if session and session.kind == "hatches" then
			session.save.count += #results
		end
	end)
	-- Last, so a statue that fails to build costs only the statue: the quests are wired up by then.
	buildGuide()
end

return { start = start }
