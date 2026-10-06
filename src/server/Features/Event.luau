-- Events on the server (the events themselves are data: src/shared/Features/Event.luau). For each one:
--   * counts what a player EARNS of the event's currency while it is live, in their save
--     (data.features.event.earned[event id]). Spending never lowers it
--   * runs a global board of that number (an OrderedDataStore, through Leaderboard.luau: submitted and
--     refreshed with the other boards) and builds it in the marketplace
--   * freezes the ranking once the event is over: the first server to notice reads the best few once and
--     stores them (a normal DataStore key, UpdateAsync, so every server ends up with the same list)
--   * pays a winner the next time they join, or at once if they are online, exactly once (a flag in their
--     save, which only one server holds at a time)
-- How earning is counted: nothing has to report candy to this file. It watches the balance instead: whatever
-- the balance has grown by since it last looked was earned. It looks twice a second and just before every
-- action and prompt (the core's `action` hook), which is where everything is spent, so a purchase can never
-- hide what was earned before it. Anything that spends outside an action calls Event.settle(player) first.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Shared = require(ReplicatedStorage.Shared.Features.Event)
local Build = require(script.Parent.Parent.Build)
local Data = require(script.Parent.Parent.Data)
local Leaderboard = require(script.Parent.Parent.Leaderboard)
local Marketplace = require(script.Parent.Parent.Marketplace)

local Event = {}

local WINNERS_STORE = "EventWinners_v1" -- [event id] = { frozen = true, at = unix time, list = { { userId, score } } }
local CHECK_SECONDS = 20 -- how often the events' clocks are looked at
local PUBLISH_SECONDS = 1 -- a player's own numbers go to their client at most this often
local MAX_SCORE = 9e15 -- an OrderedDataStore holds whole numbers; this is far inside what a double keeps exact
local BOARD_SPOT = Vector3.new(-58, 0, -30) -- marketplace space: on the west wall, north of the Gems board
local BOARD_STEP = -20 -- a second event running at the same time stands this far along the wall

-- This feature's part of the save.
local DEFAULTS = {
	earned = {}, -- [event id] = what the player earned of its currency while it was live
	paid = {}, -- [event id] = the final rank they were paid for
}

local Game -- the plug-in API, set by start
local winnersStore -- the DataStore, or nil when there is none (Studio without API access)

local sessions = {} -- [player] = { seen = { [event id] = balance last looked at }, sent = what their client was told, at }
local ranks = {} -- [event id] = { [user id] = rank } for the best Shared.RANKED, as of the board's last refresh
local winners = {} -- [event id] = the frozen list, once this server knows it
local freezing = {} -- [event id] = true while this server is working on it
local closed = {} -- [event id] = true once the players online at the end had their last score sent
local boards = {} -- [event id] = { body, status }: the labels of its board in the marketplace
local arrivals = {} -- [player] = { n, event, rank, kind, pet, amount }: the prize they were just paid, for the reveal
local arrivalCount = 0
local warned = {} -- [what] = true: a store that is down is reported once, not every CHECK_SECONDS
local function warnOnce(what: string, text: string)
	if not warned[what] then
		warned[what] = true
		warn(text)
	end
end

local function saved(data)
	local save = Game.feature(data, "event", DEFAULTS)
	if typeof(save.earned) ~= "table" then
		save.earned = {}
	end
	if typeof(save.paid) ~= "table" then
		save.paid = {}
	end
	return save
end

local function earnedIn(save, event): number
	local earned = save.earned[event.id]
	if typeof(earned) ~= "number" or earned ~= earned or earned < 0 then
		return 0
	end
	return math.min(math.floor(earned), MAX_SCORE)
end

-- What the player has earned in an event (0 for an unknown one).
function Event.earned(player: Player, eventId: string): number
	local data, event = Game.data(player), Shared.ById[eventId]
	return if data and event then earnedIn(saved(data), event) else 0
end

----------------------------------------------------------------------------------------------------
-- Counting what is earned
----------------------------------------------------------------------------------------------------
local function settle(player: Player, data, now: number)
	local session = sessions[player]
	if not session then
		return
	end
	local save = nil
	for _, event in Shared.List do
		local balance = data[event.currency]
		if typeof(balance) ~= "number" or balance ~= balance then
			continue -- a currency the save does not have (yet)
		end
		local seen = session.seen[event.id]
		if seen and balance > seen and Shared.live(event, now) then
			save = save or saved(data)
			save.earned[event.id] = math.min(earnedIn(save, event) + math.floor(balance - seen), MAX_SCORE)
		end
		session.seen[event.id] = balance
	end
end

-- Counts what the player has earned up to this moment. Call it before taking an event's currency away
-- anywhere that is not a client action or a prompt (those are covered).
function Event.settle(player: Player)
	local data = Game.data(player)
	if data then
		settle(player, data, os.time())
	end
end

----------------------------------------------------------------------------------------------------
-- What the client is told: State.feature("event") = {
--   list = { [event id] = { earned, rank?, place?, final } },   rank: on the board now (the best 100 only);
--                                                               final: the ranking is frozen; place: their final rank
--   reward = { n, event, rank, kind, pet?, amount? }            the prize just paid, for the reveal (never saved)
-- }
----------------------------------------------------------------------------------------------------
local function snapshot(player: Player, data, now: number)
	local save = saved(data)
	local list = {}
	local key = {}
	for _, event in Shared.List do
		if Shared.shown(event, now) then
			local entry = {
				earned = earnedIn(save, event),
				rank = ranks[event.id] and ranks[event.id][player.UserId],
				final = winners[event.id] ~= nil,
				place = nil :: number?,
			}
			for place, winner in winners[event.id] or {} do
				if winner.userId == player.UserId then
					entry.place = place
				end
			end
			list[event.id] = entry
			table.insert(key, `{event.id}:{entry.earned}:{entry.rank or 0}:{entry.place or 0}:{entry.final}`)
		end
	end
	local arrival = arrivals[player]
	table.insert(key, if arrival then tostring(arrival.n) else "")
	return { list = list, reward = arrival }, table.concat(key, "|")
end

local function publish(player: Player, data, force: boolean?)
	local session = sessions[player]
	if not session then
		return
	end
	local clock = os.clock()
	if not force and clock - session.at < PUBLISH_SECONDS then
		return
	end
	local meta, key = snapshot(player, data, os.time())
	if key ~= session.sent then
		session.sent, session.at = key, clock
		Game.setMeta(player, "event", meta)
	end
end

----------------------------------------------------------------------------------------------------
-- Paying a winner
----------------------------------------------------------------------------------------------------
local function pay(player: Player, data, event)
	local list = winners[event.id]
	if not list then
		return
	end
	local save = saved(data)
	if save.paid[event.id] then
		return
	end
	local rank = nil
	for place, winner in list do
		if winner.userId == player.UserId then
			rank = place
			break
		end
	end
	local reward = rank and Shared.reward(event, rank)
	-- A session whose save did not load cannot remember having been paid: the prize waits for one that can.
	if not rank or not reward or not Data.loaded(player) then
		return
	end
	save.paid[event.id] = rank
	if reward.kind == "pet" then
		-- Kept even in a full storage: it takes the place of the weakest mini cannon, like a hatched Huge.
		Game.pets.add(player, reward.pet, true)
	else
		data.diamonds += reward.amount
	end
	arrivalCount += 1
	arrivals[player] = { n = arrivalCount, event = event.id, rank = rank, kind = reward.kind, pet = reward.pet, amount = reward.amount }
	Game.sync(player)
	publish(player, data, true)
	Game.announce(`{player.DisplayName} finished {Shared.ordinal(rank)} in the {event.name} event and won {Shared.rewardText(reward)}!`, "good")
	-- The prize is in the save from the next autosave on; a save right now makes a crash in between harmless.
	task.spawn(Data.save, player)
end

local function payEveryone(event)
	for _, player in Players:GetPlayers() do
		local data = Game.data(player)
		if data and Game.state(player) then
			pay(player, data, event)
			publish(player, data, true)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- The end of an event
----------------------------------------------------------------------------------------------------
local function validRecord(record): boolean
	return typeof(record) == "table" and record.frozen == true and typeof(record.list) == "table"
end

-- Only { userId, score } rows with whole user ids, at most as many as win something.
local function cleanList(event, list)
	local clean = {}
	for _, entry in list do
		if #clean < event.winners and typeof(entry) == "table" and typeof(entry.userId) == "number" then
			table.insert(clean, { userId = entry.userId, score = if typeof(entry.score) == "number" then entry.score else 0 })
		end
	end
	return clean
end

-- Finds out who won: the stored record if a server has frozen the ranking already, else the board's best few,
-- stored so that whatever is stored first is what every server pays from. Yields. On any failure it leaves
-- everything as it was and the next check tries again.
local function freeze(event)
	if winners[event.id] or freezing[event.id] or not winnersStore then
		return
	end
	freezing[event.id] = true
	local ok, record = pcall(winnersStore.GetAsync, winnersStore, event.id)
	if not ok then
		warnOnce(event.id .. ":read", `[Event] {event.id}: the winners could not be read, trying again every {CHECK_SECONDS}s: {record}`)
	elseif not validRecord(record) and not Shared.shown(event, os.time()) then
		-- Long over, its board is gone and nobody ever froze it: there is nothing left to rank or to ask again.
		record = { frozen = true, list = {} }
	elseif not validRecord(record) then
		record = nil
		-- An empty board is an answer too (nobody played); a board that cannot be read is not.
		local top = Leaderboard.top(event.board, event.winners)
		if top then
			local mine = { frozen = true, at = os.time(), list = cleanList(event, top) }
			local kept = nil
			local stored, err = pcall(winnersStore.UpdateAsync, winnersStore, event.id, function(old)
				if validRecord(old) then
					kept = old -- another server was first: its list is the ranking
					return nil
				end
				kept = mine
				return mine
			end)
			if stored then
				record = kept
			else
				warnOnce(event.id .. ":store", `[Event] {event.id}: the winners could not be stored, trying again every {CHECK_SECONDS}s: {err}`)
			end
		end
	end
	freezing[event.id] = nil
	if validRecord(record) and not winners[event.id] then
		winners[event.id] = cleanList(event, record.list)
		payEveryone(event)
	end
end

-- The players who were online when the event ended have earned things no autosave has sent yet.
local function close(event)
	closed[event.id] = true
	for _, player in Players:GetPlayers() do
		local data = Game.data(player)
		if data then
			task.spawn(Leaderboard.submitOne, event.board, player, data)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- The board: in Leaderboard.luau's list (so TOP PLAYERS shows it) and standing in the marketplace
----------------------------------------------------------------------------------------------------
local function statusText(event, now: number): string
	if winners[event.id] then
		return "FINAL RANKING"
	elseif now >= event.endsAt then
		return "The event is over: final ranking soon"
	end
	return `Ends in {Format.duration(event.endsAt - now)}`
end

local function buildBoard(event, index: number)
	local folder = Marketplace.container()
	local west = CFrame.Angles(0, math.rad(-90), 0) -- on the west side, facing east into the square, like the others
	local frame = Marketplace.frame(BOARD_SPOT.X, BOARD_SPOT.Y, BOARD_SPOT.Z + (index - 1) * BOARD_STEP) * west
	local dark = Color3.fromRGB(44, 46, 54)
	for _, side in { -1, 1 } do
		Build.part({ Name = "EventBoardPost", Size = Vector3.new(0.8, 5, 0.8), CFrame = frame * CFrame.new(side * 6, 2.5, 0), Color = dark, Parent = folder })
	end
	local board = Build.part({
		Name = "EventBoard_" .. event.id,
		Size = Vector3.new(15, 13, 0.8),
		CFrame = frame * CFrame.new(0, 10.5, 0),
		Color = dark,
		Parent = folder,
	})
	-- A rim in the event's colour tells it apart from the three boards that are always there.
	Build.part({
		Name = "EventBoardRim",
		Size = Vector3.new(15.6, 13.6, 0.5),
		CFrame = frame * CFrame.new(0, 10.5, 0.2),
		Color = event.color,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	local gui = Build.surface(board, Enum.NormalId.Front)
	local heading = Build.label(gui, `{event.icon} MOST {string.upper(event.currencyName)} EARNED`)
	heading.Size = UDim2.fromScale(1, 0.11)
	heading.TextColor3 = event.color
	local status = Build.label(gui, "")
	status.Position = UDim2.fromScale(0.04, 0.11)
	status.Size = UDim2.fromScale(0.92, 0.06)
	local body = Build.label(gui, "Loading...")
	body.Position = UDim2.fromScale(0.04, 0.18)
	body.Size = UDim2.fromScale(0.92, 0.62)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 26
	cap.Parent = body
	local prizes = Build.label(gui, "PRIZES WHEN IT ENDS\n" .. table.concat(Shared.prizeLines(event), "\n"))
	prizes.Position = UDim2.fromScale(0.04, 0.81)
	prizes.Size = UDim2.fromScale(0.92, 0.18)
	prizes.TextColor3 = Color3.fromRGB(255, 205, 60)
	boards[event.id] = { body = body, status = status }
	status.Text = statusText(event, os.time())
end

local function register(event, index: number)
	if boards[event.id] then
		return
	end
	boards[event.id] = {}
	local built, err = pcall(buildBoard, event, index)
	if not built then
		warn(`[Event] {event.id}: its board could not be built: {err}`)
	end
	Leaderboard.add({
		id = event.board,
		title = `MOST {string.upper(event.currencyName)} EARNED`,
		storeName = `LB_Event_{event.id}_v1`,
		-- Called with the save alone when a player has just left, so it reads the save and nothing else.
		score = function(data): number
			if os.time() >= event.endsAt + Shared.SUBMIT_GRACE then
				return 0 -- the ranking is about to be frozen: nothing may move any more
			end
			local save = data.features and data.features.event
			return if typeof(save) == "table" and typeof(save.earned) == "table" then earnedIn(save, event) else 0
		end,
		format = function(score: number): string
			return Shared.scoreText(event, score)
		end,
		top = Shared.RANKED,
		attributes = { Event = event.id },
		onEntries = function(entries, rows)
			local places = {}
			for rank, entry in entries do
				local userId = tonumber(entry.key)
				if userId then
					places[userId] = rank
				end
			end
			ranks[event.id] = places
			local body = boards[event.id].body
			if body then
				local lines = {}
				for rank, row in rows do
					table.insert(lines, `{rank}. {row.name}  -  {row.text}`)
				end
				body.Text = if #lines > 0 then table.concat(lines, "\n") else "No scores yet.\nBe the first!"
			end
		end,
	})
end

-- Looks at every event's clock: puts up the board of one that has started, sends the last scores of one that
-- has just ended, and freezes the ranking of one that is over.
local function check()
	local now = os.time()
	local index = 0
	for _, event in Shared.List do
		if Shared.shown(event, now) then
			index += 1
			register(event, index)
			local status = boards[event.id].status
			if status then
				status.Text = statusText(event, now)
			end
		end
		if now >= event.endsAt and not closed[event.id] then
			close(event)
		end
		if Shared.over(event, now) and not winners[event.id] then
			task.spawn(freeze, event)
		end
	end
end
Event.check = check -- for tests: what the loop below does every CHECK_SECONDS

function Event.start(api)
	Game = api
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(WINNERS_STORE)
	end)
	if ok then
		winnersStore = result
	else
		warn(`[Event] DataStore unavailable, event prizes cannot be given: {result}`)
	end

	Game.on("ready", function(player: Player, data)
		local seen = {}
		for _, event in Shared.List do
			local balance = data[event.currency]
			seen[event.id] = if typeof(balance) == "number" then balance else nil
		end
		sessions[player] = { seen = seen, sent = nil, at = 0 }
		for _, event in Shared.List do
			pay(player, data, event)
		end
		publish(player, data, true)
	end)

	-- Just before anything is bought: what was earned up to here is counted first.
	Game.on("action", function(player: Player, data)
		settle(player, data, os.time())
	end)

	-- And just after: the balance is looked at again, so that what is earned next is counted from what the
	-- purchase left, not hidden under what it took (a kill half a second after a purchase was lost).
	Game.on("acted", function(player: Player, data)
		settle(player, data, os.time())
	end)

	Game.on("tick", function(player: Player, data)
		settle(player, data, os.time())
		publish(player, data)
	end)

	Game.on("leave", function(player: Player, data)
		if data then
			settle(player, data, os.time())
		end
		sessions[player] = nil
		arrivals[player] = nil
	end)

	check()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local fine, err = pcall(check)
			if not fine then
				warn(`[Event] check failed: {err}`)
			end
		end
	end)
end

Event.winners = winners -- for tests: [event id] = the frozen list

return Event
