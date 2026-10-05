-- Trading between two players standing in the marketplace.
-- One asks, the other accepts; each puts mini cannons and tradable items on the table and presses READY; after
-- a short countdown everything is checked once more and swapped in one step, and both players are saved.
-- The client only asks: every id, count and player it names is checked here. Limits are in the shared module.
--
-- What keeps a trade honest:
--   * a player is in one trade at a time, and only while both stand in the marketplace
--   * any change to an offer un-readies both sides, stops the countdown and locks READY for a moment, and a
--     READY only counts for the offers that player was looking at when they pressed it: no last-second swap
--   * the swap has no yield in it and only runs after ownership, tradability and storage room were checked
--     again, so either everything moves or nothing does
--   * both saves must be loaded and locked to this server (Data.luau); they are written while the countdown
--     runs and again right after the swap, so one side is never left saved without the other for long
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Features.Trading)
local Data = require(script.Parent.Parent.Data)
local Passes = require(script.Parent.Parent.Passes)

local Trading = {}

local STUDIO = RunService:IsStudio()
local WATCH_SECONDS = 0.25 -- how often open trades and waiting requests are looked over
local POLICY_ATTEMPTS = 3
local SAVE_FRESH_SECONDS = 10 -- a save this recent is not repeated when a countdown starts
local SAVE_WAIT_SECONDS = 8 -- how long a finished countdown waits for those saves before giving up
local SAVE_ATTEMPTS = 3 -- tries at the save that follows a swap
local MAX_CHANGE = 1e6 -- the most one request can add to or take from an offer (the client's "ALL")
local MAX_USER_ID = 2 ^ 53 -- above this a number is no longer a whole user id

local Game -- the core's plug-in API, handed to start

local trades = {} -- [player] = the trade they are in
local requests = {} -- waiting requests, oldest first: { from = Player, to = Player, expires = time }
local policy = {} -- [player] = "checking", "allowed", "denied" or "failed"; nil once they have left
local cooldowns = {} -- [player] = when they may start their next trade
local lastAsked = {} -- [player] = when they last sent a request
local askAgain = {} -- ["asker id:asked id"] = when the asker may ask that player again
local lastSaved = {} -- [player] = os.clock() of the last save made for one of their trades

-- Every time in here is the server clock the client reads too (State.now), so both show the same countdowns.
local function now(): number
	return workspace:GetServerTimeNow()
end

local function partner(trade, player: Player): Player
	return if trade.players[1] == player then trade.players[2] else trade.players[1]
end

-- Standing in the marketplace, with their lane and save set up.
local function present(player: Player): boolean
	local state = Game.state(player)
	return state ~= nil and state.inMarket == true and Game.data(player) ~= nil
end

-- Why this player cannot trade at all for now, in words for their own screen. nil when they can.
local function blocked(player: Player): string?
	-- What they own can only be trusted while their save is loaded and locked to this server. A Studio test
	-- without DataStore access has no saves at all: nothing can be duplicated there, and trading stays testable.
	local loaded, why = Data.loaded(player)
	if not loaded and not (STUDIO and why == "offline") then
		return if why == "locked"
			then "Your save is open on another server. Rejoin in a few minutes to trade."
			else "Your save did not load, so trading is off. Rejoin to fix it."
	end
	local status = policy[player]
	if status == "allowed" then
		return nil
	elseif status == "denied" then
		return "Roblox does not allow trading for your account (region or age rules)."
	elseif status == "failed" then
		return "Could not check your Roblox trading settings. Try again in a moment."
	end
	return "Checking your Roblox trading settings..."
end

-- How many more mini cannons fit in the player's storage. The limit is the same sum as petStorage in
-- Game.luau, which the plug-in API does not offer.
local function room(player: Player, data): number
	local limit = Config.MaxPets
	for key, pass in Config.Passes do
		if pass.storage and Passes.owns(player, key) then
			limit += pass.storage
		end
	end
	return limit - #data.pets
end

----------------------------------------------------------------------------------------------------
-- What the client is shown
----------------------------------------------------------------------------------------------------
-- Sends the player everything their trade window shows (State.feature("trade") on the client).
local function publish(player: Player)
	local data = Game.data(player)
	if not data then
		return
	end
	local view = {
		reason = blocked(player),
		cooldown = cooldowns[player] or 0, -- when they may start a trade again
		nextAsk = (lastAsked[player] or 0) + Rules.RequestGapSeconds, -- when they may send a request again
		requests = {}, -- waiting for this player's answer
		sent = {}, -- [user id] = when this player's own request to them runs out
		later = {}, -- [user id] = when this player may ask them again
	}
	for _, request in requests do
		if request.to == player then
			local from = request.from
			table.insert(view.requests, { id = from.UserId, name = from.DisplayName, expires = request.expires })
		elseif request.from == player then
			view.sent[tostring(request.to.UserId)] = request.expires
		end
	end
	local asker = `{player.UserId}:`
	for pair, free in askAgain do
		if string.sub(pair, 1, #asker) == asker then
			view.later[string.sub(pair, #asker + 1)] = free
		end
	end
	local trade = trades[player]
	if trade then
		local other = partner(trade, player)
		local otherData = Game.data(other)
		view.trade = {
			version = trade.version,
			partner = { id = other.UserId, name = other.DisplayName, user = other.Name },
			give = trade.offers[player],
			get = trade.offers[other],
			ready = trade.ready[player],
			theirReady = trade.ready[other],
			readyAt = trade.readyAt,
			endsAt = trade.endsAt,
			room = room(player, data),
			theirRoom = if otherData then room(other, otherData) else 0,
		}
	end
	Game.setMeta(player, "trade", view)
end

local function publishBoth(trade)
	for _, player in trade.players do
		publish(player)
	end
end

-- Roblox decides per player, by region and age, whether trading paid-for items is allowed. Yields.
local function checkPolicy(player: Player)
	local allowed = nil
	for attempt = 1, POLICY_ATTEMPTS do
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if policy[player] ~= "checking" then
			return -- they left while it was being looked up
		end
		if ok and typeof(info) == "table" then
			allowed = info.IsPaidItemTradingAllowed == true
			break
		end
		warn(`[Trading] policy lookup failed for {player.Name}: {info}`)
		if attempt < POLICY_ATTEMPTS then
			task.wait(attempt * 2)
		end
	end
	if allowed == nil then
		-- A lookup that failed counts as not allowed. Only Studio's test players, who have no policy to look
		-- up, may trade anyway: trading has to stay testable there.
		policy[player] = if STUDIO then "allowed" else "failed"
	else
		policy[player] = if allowed then "allowed" else "denied"
	end
	publish(player)
end

-- The player's saved trading table: their recent trades, newest first, and how many they have made.
local function ledger(data)
	local book = Game.feature(data, "trading", { history = {}, total = 0 })
	-- A save from an older build or one edited by hand must not stop a trade half way through.
	if typeof(book.history) ~= "table" then
		book.history = {}
	end
	if typeof(book.total) ~= "number" then
		book.total = 0
	end
	return book
end

local function publishHistory(player: Player, data)
	local book = ledger(data)
	Game.setMeta(player, "tradeHistory", { total = book.total, list = book.history })
end

-- Writes a finished trade into the player's history and shows them the result.
local function record(player: Player, other: Player, gave, got)
	local data = Game.data(player)
	local book = ledger(data)
	local entry = {
		name = other.DisplayName,
		user = other.Name,
		id = other.UserId,
		at = os.time(),
		gave = { pets = table.clone(gave.pets), items = table.clone(gave.items) },
		got = { pets = table.clone(got.pets), items = table.clone(got.items) },
	}
	table.insert(book.history, 1, entry)
	while #book.history > Rules.HistorySize do
		table.remove(book.history)
	end
	book.total += 1
	publishHistory(player, data)
	Game.send(player, "tradeDone", entry)
end

----------------------------------------------------------------------------------------------------
-- Requests
----------------------------------------------------------------------------------------------------
local function findRequest(from: Player, to: Player): number?
	for index, request in requests do
		if request.from == from and request.to == to then
			return index
		end
	end
	return nil
end

-- Forgets every request to or from this player, and tells the players at the other end.
local function dropRequests(player: Player)
	for index = #requests, 1, -1 do
		local request = requests[index]
		if request.from == player or request.to == player then
			table.remove(requests, index)
			publish(if request.from == player then request.to else request.from)
		end
	end
end

-- The other player a client named by user id, if that is somebody else on this server.
local function named(player: Player, userId: unknown): Player?
	if typeof(userId) ~= "number" or userId % 1 ~= 0 or math.abs(userId) > MAX_USER_ID then
		return nil
	end
	local other = Players:GetPlayerByUserId(userId)
	return if other ~= player then other else nil
end

-- Why this player cannot start a trade right now, in words for their own screen. nil when they can.
local function cannotStart(player: Player): string?
	if not present(player) then
		return "Go to the marketplace to trade"
	elseif trades[player] then
		return "Finish the trade you are in first"
	end
	local left = (cooldowns[player] or 0) - now()
	if left > 0 then
		return `You can trade again in {math.ceil(left)}s`
	end
	return blocked(player)
end

----------------------------------------------------------------------------------------------------
-- A trade: { players, offers, ready, rooms, version, token, readyAt, endsAt }
----------------------------------------------------------------------------------------------------
local function openTrade(a: Player, b: Player)
	dropRequests(a)
	dropRequests(b)
	-- Two players who trade may ask each other again as soon as they are done.
	askAgain[`{a.UserId}:{b.UserId}`], askAgain[`{b.UserId}:{a.UserId}`] = nil, nil
	local trade = {
		players = { a, b },
		offers = { [a] = { pets = {}, items = {} }, [b] = { pets = {}, items = {} } },
		ready = { [a] = false, [b] = false },
		rooms = { [a] = room(a, Game.data(a)), [b] = room(b, Game.data(b)) }, -- as last sent to the clients
		version = 1, -- goes up with every change to an offer
		token = 0, -- goes up whenever a countdown that is running must not finish
		readyAt = now(), -- READY is refused before this
		endsAt = 0, -- when the countdown runs out; 0 while there is none
	}
	trades[a], trades[b] = trade, trade
	for _, player in trade.players do
		player:SetAttribute("InTrade", true) -- every client's player list shows who is busy
	end
	publishBoth(trade)
end

-- Ends the trade. Unless the swap has already run, nothing has moved.
local function closeTrade(trade, message: string?, kind: string?)
	trade.token += 1
	for _, player in trade.players do
		if trades[player] == trade then
			trades[player] = nil
			player:SetAttribute("InTrade", false)
			if message then
				Game.notify(player, message, kind or "info")
			end
			publish(player)
		end
	end
end

-- What is on the table changed: both sides are un-readied, a running countdown is stopped and READY is locked
-- for a moment, so nobody is rushed into agreeing to an offer that was swapped under them.
local function changed(trade)
	trade.version += 1
	trade.token += 1
	trade.endsAt = 0
	trade.readyAt = now() + Rules.ReadyLockSeconds
	for _, player in trade.players do
		trade.ready[player] = false
	end
end

-- The trade cannot go through as it stands: both sides are told why and have to press READY again.
local function refuse(trade, message: string)
	changed(trade)
	for _, player in trade.players do
		Game.notify(player, message, "bad")
	end
	publishBoth(trade)
end

-- Everything that has to hold for the swap: checked when both are ready, and again at the moment it happens.
-- Returns what to tell both players, or nil when the trade can go through.
local function problem(trade): string?
	for index, player in trade.players do
		local data = Game.data(player)
		if not player.Parent or not data or not present(player) then
			return `{player.DisplayName} left the marketplace`
		end
		if blocked(player) then
			return `{player.DisplayName} cannot trade right now`
		end
		local offer = trade.offers[player]
		for kind, counts in offer do
			for id, count in counts do
				local owned = if kind == "pets" then Game.pets.count(data, id) else Game.items.count(data, id)
				if not Rules.canTrade(kind, id) or owned < count then
					return `{player.DisplayName} no longer has everything they offered`
				end
			end
		end
		-- Mini cannons that arrive must fit: past the limit Game.pets.add pushes the weakest ones out.
		local arriving = Rules.total(trade.offers[trade.players[3 - index]].pets)
		local space = room(player, data) + Rules.total(offer.pets)
		if arriving > 0 and arriving > space then
			return `{player.DisplayName} needs room for {arriving - space} more mini cannons (storage is full)`
		end
	end
	return nil
end

-- One step of the swap. Every step was checked beforehand, so none should fail. If one does anyway (an error
-- while a model is rebuilt, say), the rest still run: stopping half way would be worse than a wrong model.
local function step(action, ...)
	local ok, result = pcall(action, ...)
	if not ok or result == false then
		warn(`[Trading] a step of a swap failed: {result}`)
	end
end

-- Moves everything on the table to the other side. Nothing in here yields, so nothing else runs in between.
local function swap(trade)
	for _, player in trade.players do
		local offer = trade.offers[player]
		for id, count in offer.pets do
			step(Game.pets.remove, player, id, count)
		end
		for id, count in offer.items do
			step(Game.items.take, player, id, count)
		end
	end
	for index, player in trade.players do
		local arriving = trade.offers[trade.players[3 - index]]
		for id, count in arriving.pets do
			for _ = 1, count do
				step(Game.pets.add, player, id, true)
			end
		end
		for id, count in arriving.items do
			step(Game.items.give, player, id, count)
		end
	end
end

-- Saves the player before a swap. Yields. A trade only goes through when both saves just worked: the store
-- is reachable, both locks are still this server's, and what each player owned before the trade is on record.
local function secure(player: Player): boolean
	if not Data.loaded(player) then
		-- Only a Studio test without a store gets this far unloaded (see blocked): there is nothing to save.
		return blocked(player) == nil
	end
	local last = lastSaved[player]
	if last and os.clock() - last < SAVE_FRESH_SECONDS then
		return true
	end
	local saved = Data.save(player)
	if saved and policy[player] then
		lastSaved[player] = os.clock()
	end
	return saved
end

-- Saves the player right after a swap, trying again if the store fails: until it is written, a server crash
-- would give this side its old things back.
local function saveAfter(player: Player)
	task.spawn(function()
		for attempt = 1, SAVE_ATTEMPTS do
			if not Data.loaded(player) then
				return -- they left (the release wrote everything), or nothing is being saved at all
			end
			if Data.save(player) then
				if policy[player] then
					lastSaved[player] = os.clock()
				end
				return
			end
			task.wait(attempt * 2)
		end
		warn(`[Trading] could not save {player.Name} after a trade`)
	end)
end

-- The countdown is over: check everything one last time and swap. From the check to closeTrade nothing
-- yields, so no request from either player can land in between.
local function complete(trade)
	local trouble = problem(trade)
	if trouble then
		refuse(trade, trouble)
		return
	end
	swap(trade)
	local a, b = trade.players[1], trade.players[2]
	-- The saves are on their way before anything else is done. Each takes its copy of the data when the store
	-- answers, so the history written below is in it too.
	saveAfter(a)
	saveAfter(b)
	cooldowns[a] = now() + Rules.CooldownSeconds
	cooldowns[b] = cooldowns[a]
	closeTrade(trade)
	record(a, b, trade.offers[a], trade.offers[b])
	record(b, a, trade.offers[b], trade.offers[a])
	for _, player in trade.players do
		Game.notify(player, `Trade with {partner(trade, player).DisplayName} complete!`, "good")
		Game.sync(player)
	end
end

-- Both are ready: the countdown starts, and both players are saved while it runs.
local function countdown(trade)
	trade.token += 1
	local token = trade.token
	trade.endsAt = now() + Rules.CountdownSeconds
	local secured = {}
	for index, player in trade.players do
		task.spawn(function()
			secured[index] = secure(player)
		end)
	end
	task.delay(Rules.CountdownSeconds, function()
		local deadline = os.clock() + SAVE_WAIT_SECONDS
		while trade.token == token and (secured[1] == nil or secured[2] == nil) and os.clock() < deadline do
			task.wait(0.1)
		end
		if trade.token ~= token then
			return -- un-readied, changed or cancelled while it ran
		end
		if not (secured[1] and secured[2]) then
			refuse(trade, "Could not save right now, so nothing was traded. Try again in a moment.")
			return
		end
		complete(trade)
	end)
end

----------------------------------------------------------------------------------------------------
-- What the client can ask for (Game.actions)
----------------------------------------------------------------------------------------------------
-- Starts the trade a waiting request asked for.
local function accept(player: Player, from: Player)
	local index = findRequest(from, player)
	if not index then
		Game.notify(player, "That request is gone", "bad")
		return
	end
	local trouble = cannotStart(player)
	if trouble then
		Game.notify(player, trouble, "bad")
		return
	end
	if cannotStart(from) then
		table.remove(requests, index)
		Game.notify(player, `{from.DisplayName} cannot trade right now`, "bad")
		publish(player)
		publish(from)
		return
	end
	openTrade(from, player)
end

local function request(player: Player, _data, _state, userId: unknown)
	local target = named(player, userId)
	if not target then
		return
	end
	local trouble = cannotStart(player)
	if trouble then
		if policy[player] == "failed" then
			-- Worth another try: the lookup may only have been down for a moment.
			policy[player] = "checking"
			task.spawn(checkPolicy, player)
		end
		Game.notify(player, trouble, "bad")
		return
	end
	if findRequest(target, player) then
		accept(player, target) -- they asked first, so asking back is a yes
		return
	end

	local time = now()
	local name = target.DisplayName
	local pair = `{player.UserId}:{target.UserId}`
	local waiting = 0
	for _, other in requests do
		if other.to == target then
			waiting += 1
		end
	end
	if not present(target) then
		trouble = `{name} is not in the marketplace`
	elseif trades[target] then
		trouble = `{name} is in a trade`
	elseif cannotStart(target) then
		trouble = `{name} cannot trade right now`
	elseif findRequest(player, target) then
		trouble = `{name} has not answered yet`
	elseif time < (askAgain[pair] or 0) then
		trouble = `{name} is not trading with you right now. Ask again later.`
	elseif time < (lastAsked[player] or 0) + Rules.RequestGapSeconds then
		trouble = "Slow down a little"
	elseif waiting >= Rules.MaxIncoming then
		trouble = `{name} has too many requests right now`
	end
	if trouble then
		Game.notify(player, trouble, "bad")
		return
	end

	-- One request at a time: asking someone new takes the last one back.
	for index = #requests, 1, -1 do
		if requests[index].from == player then
			publish(table.remove(requests, index).to)
		end
	end
	lastAsked[player] = time
	-- Whatever becomes of this request (a no, no answer, taken back), the same player is not asked again for
	-- a while after it: nobody can keep prompting someone who does not want to trade.
	askAgain[pair] = time + Rules.RequestSeconds + Rules.DeclinedSeconds
	table.insert(requests, { from = player, to = target, expires = time + Rules.RequestSeconds })
	Game.notify(target, `{player.DisplayName} wants to trade with you`, "info")
	publish(player)
	publish(target)
end

local function answer(player: Player, _data, _state, userId: unknown)
	local from = named(player, userId)
	if from then
		accept(player, from)
	end
end

local function decline(player: Player, _data, _state, userId: unknown)
	local from = named(player, userId)
	local index = from and findRequest(from, player)
	if not from or not index then
		return
	end
	table.remove(requests, index)
	Game.notify(from, `{player.DisplayName} said no to your trade request`, "info")
	publish(player)
	publish(from)
end

-- change: { kind = "pets" or "items", id = string, add = whole number }. add is how many more to offer
-- (negative takes some back); the result is trimmed to what the player owns and to the limits.
local function offer(player: Player, data, _state, change: any)
	local trade = trades[player]
	if not trade or typeof(change) ~= "table" then
		return
	end
	local kind, id, add = change.kind, change.id, change.add
	if (kind ~= "pets" and kind ~= "items") or typeof(id) ~= "string" or typeof(add) ~= "number" then
		return
	end
	-- Whole numbers only, which also turns away NaN and infinity.
	if add % 1 ~= 0 or add == 0 then
		return
	end
	if not Rules.canTrade(kind, id) then
		Game.notify(player, "That cannot be traded", "bad")
		return
	end

	local mine = trade.offers[player]
	local counts = mine[kind]
	local old = counts[id] or 0
	local limit = if kind == "pets" then Game.pets.count(data, id) else Game.items.count(data, id)
	local why = "You have no more of those"
	local cap = if kind == "pets" then Rules.MaxPets - (Rules.total(counts) - old) else Rules.MaxItemCount
	if cap < limit then
		limit = cap
		why = if kind == "pets"
			then `Up to {Rules.MaxPets} mini cannons in one trade`
			else `Up to {Rules.MaxItemCount} of one item in one trade`
	end
	local new = math.clamp(old + math.clamp(add, -MAX_CHANGE, MAX_CHANGE), 0, math.max(limit, 0))
	if new == old then
		if add > 0 then
			Game.notify(player, why, "bad")
		end
		return
	end
	if old == 0 and Rules.stacks(mine) >= Rules.MaxStacks then
		Game.notify(player, `Up to {Rules.MaxStacks} different things in one trade`, "bad")
		return
	end
	counts[id] = if new > 0 then new else nil
	changed(trade)
	publishBoth(trade)
end

-- version: the offers' version the player was looking at when they pressed READY, or false to un-ready.
local function ready(player: Player, _data, _state, version: unknown)
	local trade = trades[player]
	if not trade then
		return
	end
	if version == false then
		if trade.ready[player] then
			trade.ready[player] = false
			trade.token += 1
			trade.endsAt = 0
			publishBoth(trade)
		end
		return
	end
	-- A press that was made for older offers, or while READY is locked after a change, does not count.
	if version ~= trade.version or trade.ready[player] or now() < trade.readyAt then
		return
	end
	local other = partner(trade, player)
	if Rules.stacks(trade.offers[player]) + Rules.stacks(trade.offers[other]) == 0 then
		Game.notify(player, "Add something to the trade first", "bad")
		return
	end
	trade.ready[player] = true
	if trade.ready[other] then
		local trouble = problem(trade)
		if trouble then
			refuse(trade, trouble)
			return
		end
		countdown(trade)
	end
	publishBoth(trade)
end

local function cancel(player: Player)
	local trade = trades[player]
	if trade then
		closeTrade(trade, `{player.DisplayName} cancelled the trade`, "info")
	end
end

----------------------------------------------------------------------------------------------------
-- Keeping watch
----------------------------------------------------------------------------------------------------
-- An open trade: both players must stay in the marketplace and keep owning what they put on the table.
local function check(trade)
	for _, player in trade.players do
		if not present(player) then
			closeTrade(trade, `{player.DisplayName} left the marketplace. Trade cancelled.`, "bad")
			return
		end
	end
	-- Mini cannons can be fused and items used while a trade is open: an offer shrinks to what is left.
	local short = nil
	for _, player in trade.players do
		local data = Game.data(player)
		for kind, counts in trade.offers[player] do
			for id, count in counts do
				local owned = if kind == "pets" then Game.pets.count(data, id) else Game.items.count(data, id)
				if not Rules.canTrade(kind, id) then
					owned = 0
				end
				if owned < count then
					counts[id] = if owned > 0 then owned else nil
					short = player
				end
			end
		end
	end
	if short then
		refuse(trade, `{short.DisplayName} no longer has everything they offered`)
		return
	end
	-- The clients warn about full storage, so they are told when the room changes (a hatch, a fusion).
	local moved = false
	for _, player in trade.players do
		local free = room(player, Game.data(player))
		if trade.rooms[player] ~= free then
			trade.rooms[player] = free
			moved = true
		end
	end
	if moved then
		publishBoth(trade)
	end
end

local function watch()
	local time = now()
	for index = #requests, 1, -1 do
		local waiting = requests[index]
		local expired = time >= waiting.expires
		if expired or not present(waiting.from) or not present(waiting.to) then
			table.remove(requests, index)
			if expired then
				Game.notify(waiting.from, `{waiting.to.DisplayName} did not answer`, "info")
			end
			publish(waiting.from)
			publish(waiting.to)
		end
	end
	for pair, free in askAgain do
		if time >= free then
			askAgain[pair] = nil
		end
	end
	-- Both players of a trade point at it, and a trade may close while it is checked: list them first.
	local open = {}
	for _, trade in trades do
		open[trade] = true
	end
	for trade in open do
		check(trade)
	end
end

-- A player's lane and save are set up: their window gets its first state, and Roblox is asked whether they
-- may trade.
local function arrive(player: Player, data)
	policy[player] = "checking"
	publish(player)
	publishHistory(player, data)
	local loaded, why = Data.loaded(player)
	if not loaded and why == "locked" then
		-- The core only says that the save did not load. This is the one case where waiting fixes it.
		Game.notify(player, "Your save is still open on another server. Rejoin in a few minutes.", "bad")
	end
	-- In a thread of its own: the lookup yields, and the rest of the join must not wait for it.
	task.spawn(checkPolicy, player)
end

local function depart(player: Player)
	local trade = trades[player]
	if trade then
		closeTrade(trade, `{player.DisplayName} left the game. Trade cancelled.`, "bad")
	end
	dropRequests(player)
	policy[player], cooldowns[player], lastAsked[player], lastSaved[player] = nil, nil, nil, nil
end

function Trading.start(api)
	Game = api
	Game.actions.tradeRequest = request
	Game.actions.tradeAccept = answer
	Game.actions.tradeDecline = decline
	Game.actions.tradeOffer = offer
	Game.actions.tradeReady = ready
	Game.actions.tradeCancel = cancel

	Game.on("ready", arrive)
	Game.on("leave", depart)

	task.spawn(function()
		while true do
			task.wait(WATCH_SECONDS)
			-- Each pass in its own thread: an error in one must not stop the watch for good.
			task.spawn(watch)
		end
	end)
end

return Trading
