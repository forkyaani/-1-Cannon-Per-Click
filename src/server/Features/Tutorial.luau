-- The first-join experience, server half: decides when the welcome is over, checks the group and pays the fan
-- bonus once, and follows each player through the walkthrough (src/shared/Features/Tutorial.luau has the steps,
-- their words and their rewards). The client only draws: Meta_tutorial says where the player is.
--
-- Every step is read from the player's real state on the tick hook, twice a second, so a step ends when the
-- thing is actually done, a step that is done already is passed at once, and a player who rejoins carries on
-- at the saved step. Three things the server cannot see are told by the client and checked here
-- (`tutorialAck`): the TOWER window was opened (the player must be standing at one of their own pads), and
-- the two presses that end a reading step (GOT IT, LET'S GO).
--
-- A step's reward is paid once ever (Tutorial.take). Chapter 1 of the story asks for some of the same things:
-- those quests carry `tutorial = <step id>` and share the payment, so whichever notices first pays, the other
-- pays nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Story = require(ReplicatedStorage.Shared.Features.Story)
local Tutorial = require(ReplicatedStorage.Shared.Features.Tutorial)

local PAD_REACH = 12 -- studs from a pad's centre that count as "walked up to it": about its prompt's reach
local OPEN_REACH = 20 -- the TOWER window can only have been opened from this close to an owned pad
local CHECK_SECONDS = 3 -- the shortest time between two presses of CHECK that ask Roblox
local HINT_SECONDS = 14 -- how long the "your level failed, do this" line stays on the banner
-- A player this far in has seen levels clear and lives lost: the two watching steps are passed for them.
local VETERAN_LEVEL = Config.BossEvery * 2

local FIRST = Tutorial.Steps[1].id
local DONE = Tutorial.DONE

local Feature = {}

local Game -- the plug-in API, handed to start
local sessions = {} -- [player] = { save, acks, sawClear, group, checking, checkedAt, hint, hintAt, dirty }

-- A whole, finite, non-negative number out of Config, or 0: a typo there must not corrupt a save.
local function amount(value: any): number
	return if typeof(value) == "number" and value == value and value >= 0 and value < math.huge then math.floor(value) else 0
end

----------------------------------------------------------------------------------------------------
-- The group and the fan bonus
----------------------------------------------------------------------------------------------------
local function groupId(): number
	local id = Config.Fan.groupId
	return if typeof(id) == "number" and id == id and id > 0 and id % 1 == 0 then id else 0
end

-- Whether the player is in the group: (Roblox answered, is a member). It yields.
-- Player:IsInGroup remembers its first answer for the whole session, so somebody who joins the group while
-- playing would be told "no" until they rejoin. `fresh` (the CHECK button) therefore also asks GroupService
-- for the player's groups as they are now. A field of the module, so a test can stand in for Roblox.
function Feature.inGroup(player: Player, id: number, fresh: boolean?): (boolean, boolean)
	local ok, member = pcall(player.IsInGroup, player, id)
	if ok and member == true then
		return true, true
	end
	if fresh then
		local listed, groups = pcall(function()
			return game:GetService("GroupService"):GetGroupsAsync(player.UserId)
		end)
		if listed and typeof(groups) == "table" then
			for _, group in groups do
				if typeof(group) == "table" and group.Id == id then
					return true, true
				end
			end
			return true, false
		end
	end
	return ok, false
end

-- The gems, once per save. The coin bonus is the `coins` modifier below: it reads the same flag.
local function payFan(player: Player, data, save)
	if save.fanPaid then
		return
	end
	save.fanPaid = true -- before the gems: a payment that failed half way must not be paid again
	local gems = amount(Config.Fan.gems)
	data.diamonds += gems
	local percent = math.floor((tonumber(Config.Fan.coins) or 0) * 100 + 0.5)
	Game.notify(player, `Fan bonus! +{Format.abbreviate(gems)} gems and +{percent}% coins forever. Thank you for joining!`, "good")
end

local publish

-- Asks Roblox and pays if the player is a member. Runs in its own thread: the question yields.
local function checkGroup(player: Player, fresh: boolean)
	local session = sessions[player]
	local id = groupId()
	if not session or session.checking or id == 0 or session.save.fanPaid then
		return
	end
	session.checking = true
	-- In pcall: a question that throws must not leave the check "running" for the rest of the session.
	local called, ok, member = pcall(Feature.inGroup, player, id, fresh)
	ok = called and ok == true
	-- The player may have left while Roblox was thinking.
	session = sessions[player]
	local data = Game.data(player)
	if not session or not data then
		return
	end
	session.checking = false
	session.group = if not ok then "failed" elseif member then "member" else "no"
	if ok and member then
		payFan(player, data, session.save)
		Game.sync(player)
	end
	publish(player, session)
end

----------------------------------------------------------------------------------------------------
-- The walkthrough: when each step is done. fn(player, data, state, session) -> boolean
----------------------------------------------------------------------------------------------------
-- The highest level among the player's towers, and how many are standing.
local function towerStats(data): (number, number)
	local highest, count = 0, 0
	for _, tower in data.towers do
		highest = math.max(highest, tower.level)
		count += 1
	end
	return highest, count
end

-- Whether the player's character stands within `reach` studs of one of their own pads, on their plot.
local function atOwnPad(player: Player, data, state, reach: number): boolean
	local character = player.Character
	local root = character and character.PrimaryPart
	if not root or state.place ~= "plot" or not state.slot then
		return false
	end
	for _, pad in data.pads do
		if Layout.PADS[pad] then
			local offset = root.Position - Layout.padPosition(state.slot, pad)
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach then
				return true
			end
		end
	end
	return false
end

-- Anyone who has upgraded a tower or bought a pad has stood at one and had its window open.
local function usedAPad(data): boolean
	return #data.pads > 1 or towerStats(data) > 1
end

local function veteran(data): boolean
	return data.bestCleared >= VETERAN_LEVEL or data.rebirths > 0
end

local CHECKS = {}

function CHECKS.pad(player: Player, data, state): boolean
	return usedAPad(data) or atOwnPad(player, data, state, PAD_REACH)
end

-- The TOWER window was opened: the client says so (`tutorialAck`), from one of the player's own pads.
function CHECKS.open(_player: Player, data, _state, session): boolean
	return session.acks.open == true or usedAPad(data)
end

-- A new save's only tower is level 1, and a tower's level never drops.
function CHECKS.upgrade(_player: Player, data): boolean
	return towerStats(data) > 1
end

-- A level was cleared while this was the step (the waveCleared hook), so the player saw it happen.
function CHECKS.clear(_player: Player, data, _state, session): boolean
	return session.sawClear == true or veteran(data)
end

function CHECKS.pad2(_player: Player, data): boolean
	return #data.pads >= 2
end

function CHECKS.build(_player: Player, data): boolean
	local _, count = towerStats(data)
	return count >= 2
end

-- A line to read, ended with GOT IT. Nobody is made to lose a level for it.
function CHECKS.lives(_player: Player, data, _state, session): boolean
	return session.acks.lives == true or veteran(data)
end

-- Standing on the island of the first egg. Having hatched says the way there is known.
function CHECKS.island(_player: Player, data, state): boolean
	return data.totalHatches > 0 or (state.place == "island" and state.island == Tutorial.Island)
end

function CHECKS.hatch(_player: Player, data): boolean
	return data.totalHatches > 0
end

function CHECKS.home(_player: Player, _data, state): boolean
	return state.place == "plot"
end

function CHECKS.finish(_player: Player, _data, _state, session): boolean
	return session.acks.finish == true
end

----------------------------------------------------------------------------------------------------
-- Publishing and moving on
----------------------------------------------------------------------------------------------------
-- The client draws the cards, the banner and the marker from this.
function publish(player: Player, session)
	local save = session.save
	session.dirty = false
	Game.setMeta(player, "tutorial", {
		welcomed = save.welcomed,
		step = save.step, -- a step's id, or "done"
		fanPaid = save.fanPaid,
		paid = save.paid, -- [step id] = true: that reward is given, so the banner offers it no more
		group = groupId() ~= 0, -- false = the group is coming soon
		member = session.group, -- what the last check said: "unknown", "member", "no" or "failed"
		checking = session.checking,
		hint = session.hint, -- what to do about a failed level; the client shows it for hintSeconds from hintAt
		hintAt = session.hintAt,
		hintSeconds = HINT_SECONDS,
		studio = RunService:IsStudio(),
	})
end

-- Pays a step's reward unless it was paid before (by an earlier run, or by the story's quest for the same
-- thing). Adds what it paid to `total`.
local function pay(data, save, step, total)
	local reward = step.reward
	if not reward or not Tutorial.take(save, step.id) then
		return
	end
	local coins, gems = amount(reward.coins), amount(reward.gems)
	data.coins += coins
	data.diamonds += gems
	total.coins += coins
	total.gems += gems
end

-- Passes the step the player is on if it is done, and every step after it that is done already.
local function advance(player: Player, data, state)
	local session = sessions[player]
	if not session then
		return
	end
	local save = session.save
	if not save.welcomed or save.step == DONE then
		return
	end
	local index = Tutorial.Index[save.step] or 1
	local moved = false
	local total = { coins = 0, gems = 0 }
	while true do
		local step = Tutorial.Steps[index]
		if not step then
			save.step = DONE
			break
		end
		save.step = step.id
		local check = CHECKS[step.id]
		-- A step this file cannot check must not stop the walkthrough: it counts as done.
		local ok, done = true, true
		if check then
			ok, done = pcall(check, player, data, state, session)
		end
		if ok and not done then
			break
		end
		-- Moved on before it is paid: if paying ever failed, the next tick must not pay it again.
		index += 1
		save.step = if Tutorial.Steps[index] then Tutorial.Steps[index].id else DONE
		session.sawClear = false
		moved = true
		pay(data, save, step, total)
	end
	if moved then
		session.hint = nil
		-- One toast however many steps it was.
		local text = Tutorial.rewardText(total)
		if save.step == DONE then
			Game.notify(player, `Tutorial complete! {if text ~= "" then text .. ". " else ""}Your quests are in STORY.`, "good")
		elseif text ~= "" then
			Game.notify(player, `Tutorial step done!  {text}`, "good")
		end
		Game.sync(player)
		publish(player, session)
	end
end

local function running(session): boolean
	return session.save.welcomed == true and session.save.step ~= DONE
end

----------------------------------------------------------------------------------------------------
-- What the client asks for. Every argument is whatever a client chose to send.
----------------------------------------------------------------------------------------------------
-- The last welcome card: "start" begins the walkthrough, "skip" ends it before it begins.
local function welcome(player: Player, data, state, choice: unknown)
	local session = sessions[player]
	if not session or session.save.welcomed or (choice ~= "start" and choice ~= "skip") then
		return
	end
	local save = session.save
	save.welcomed = true
	if choice == "skip" then
		save.step = DONE
	elseif not Tutorial.Index[save.step] then
		save.step = FIRST
	end
	advance(player, data, state)
	publish(player, session)
end

-- CHECK on the group card.
local function check(player: Player)
	local session = sessions[player]
	if not session or session.save.fanPaid or session.checking or groupId() == 0 then
		return
	end
	local now = os.clock()
	if now - session.checkedAt < CHECK_SECONDS then
		return
	end
	session.checkedAt = now
	task.spawn(checkGroup, player, true)
end

-- The three things only the client sees: the TOWER window opening, GOT IT and LET'S GO. Only the step the
-- player is on can be acknowledged, and only if it is one of those.
local function ack(player: Player, data, state, id: unknown)
	local session = sessions[player]
	if not session or not running(session) or typeof(id) ~= "string" or id ~= session.save.step then
		return
	end
	local step = Tutorial.ById[id]
	if id == "open" then
		if not atOwnPad(player, data, state, OPEN_REACH) then
			return
		end
	elseif not step or not step.ack then
		return
	end
	session.acks[id] = true
	advance(player, data, state)
end

local function onReady(player: Player, data, state)
	local save = Game.feature(data, "tutorial", Tutorial.SAVED)
	-- A save is whatever was stored: make it the shape this file counts on.
	save.welcomed = save.welcomed == true
	save.fanPaid = save.fanPaid == true
	if typeof(save.paid) ~= "table" then
		save.paid = {}
	end
	if save.step ~= DONE and not Tutorial.Index[save.step] then
		save.step = FIRST
	end
	-- Once per save: a story quest that was finished before the walkthrough existed has paid for its step.
	if save.seeded ~= true then
		save.seeded = true
		local story = data.features.story
		local chapter = Story.Chapters[1]
		if typeof(story) == "table" and chapter then
			local at = if (tonumber(story.chapter) or 1) > 1 then math.huge else tonumber(story.quest) or 1
			for index, quest in chapter.quests do
				if quest.tutorial and index < at then
					save.paid[quest.tutorial] = true
				end
			end
		end
	end
	local session = {
		save = save,
		acks = {},
		sawClear = false,
		group = if save.fanPaid then "member" else "unknown",
		checking = false,
		checkedAt = -math.huge,
		hint = nil,
		hintAt = 0,
		dirty = false,
	}
	sessions[player] = session
	-- A rejoin carries on where the save says, past whatever got done in the meantime.
	advance(player, data, state)
	publish(player, session)
	-- Every join asks again, quietly: somebody who joined the group since last time is paid now.
	if not save.fanPaid and groupId() ~= 0 then
		task.spawn(checkGroup, player, false)
	end
end

-- The walkthrough must never leave a player stuck in front of a level they cannot clear: the core drops
-- them back one level and stops auto-advance, and the banner says what to do about it.
local function onLevelFailed(player: Player, data)
	local session = sessions[player]
	if not session or not running(session) then
		return
	end
	local affordable = false
	local mult = Game.value(player, "upgradeCost")
	for _, tower in data.towers do
		if tower.level < Config.TowerMaxLevel and Config.towerUpgradeCost(tower.kind, tower.level, mult) <= data.coins then
			affordable = true
			break
		end
	end
	session.hint = if affordable
		then "Level failed! Walk to a cannon and press UPGRADE, then press > to try again."
		else "Level failed. No problem: your cannons now farm the level before. Upgrade when you have the coins, then press >."
	session.hintAt = workspace:GetServerTimeNow()
	publish(player, session)
end

function Feature.start(core)
	Game = core

	-- +10% coins for good, once the fan bonus is paid. Labelled, so STATS lists it.
	Game.modify("coins", function(_player: Player, data, _state, value: number): number
		local save = data.features.tutorial
		if typeof(save) == "table" and save.fanPaid == true then
			local bonus = tonumber(Config.Fan.coins) or 0
			if bonus == bonus and bonus > 0 and bonus < math.huge then
				return value * (1 + bonus)
			end
		end
		return value
	end, "Fan bonus")

	Game.actions.tutorialWelcome = welcome
	Game.actions.tutorialCheck = check
	Game.actions.tutorialAck = ack

	-- Studio only: play the first join again (docs/ARCHITECTURE.md).
	--   Remotes.Action:FireServer("tutorialReset")          the cards and the walkthrough; rewards stay paid
	--   Remotes.Action:FireServer("tutorialReset", "all")   also forgets the paid rewards and the fan bonus
	if RunService:IsStudio() then
		Game.actions.tutorialReset = function(player: Player, _data, _state, what: unknown)
			local session = sessions[player]
			if not session then
				return
			end
			local save = session.save
			save.welcomed = false
			save.step = FIRST
			if what == "all" then
				save.paid = {}
				save.fanPaid = false
				session.group = "unknown"
			end
			session.acks = {}
			session.sawClear = false
			session.hint = nil
			publish(player, session)
		end
	end

	Game.on("ready", onReady)
	Game.on("tick", advance)
	Game.on("levelFailed", onLevelFailed)
	Game.on("waveCleared", function(player: Player)
		local session = sessions[player]
		if session and running(session) and session.save.step == "clear" then
			session.sawClear = true
		end
	end)
	Game.on("leave", function(player: Player)
		sessions[player] = nil
	end)
end

return Feature
