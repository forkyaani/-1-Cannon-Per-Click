-- The admin grant tool, server half: the `adminGrant` action. An admin names one player (by username or user
-- id) and one thing: gems, coins, candy, backpack items (crates and keys are items) or a mini cannon.
-- src/shared/Features/Admin.luau has the admins and the caps; the window is src/client/Features/Admin.luau.
--
-- * Who is an admin is decided here, in every call. A call from anyone else pays nothing and is warned about.
-- * A target who is on this server is paid at once, through the calls every other reward uses.
-- * Anyone else gets a pending grant in a store of its own (AdminGrants_v1, one key per user id), paid when
--   their save next loads. Another player's save is never written from here: it is locked to their server.
-- * Every grant is logged: the server log, a capped list in AdminLog_v1, and an analytics event.
--
-- Why a pending grant is paid exactly once. A grant has a unique id. Paying it sets `paid[grant id]` in the
-- player's own save in the same breath as the reward (no yield between the two), so one write of the save
-- carries both or neither. Only after that save has gone through is the grant taken out of AdminGrants_v1,
-- and only then is the mark dropped. A crash:
--   before the save is written    the reward and the mark are both lost, the grant still waits: paid next join;
--   after it, before the removal  the grant still waits but the save has its mark: skipped and removed next join;
--   after the removal             nothing waits.
-- The save is locked to one server (Data.luau), so no second server can pay the same grant into another copy,
-- and a session whose save did not load is not paid at all: the grant goes on waiting.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)
local Admin = require(ReplicatedStorage.Shared.Features.Admin)
local Data = require(script.Parent.Parent.Data)
local Passes = require(script.Parent.Parent.Passes)

local GRANT_STORE = "AdminGrants_v1" -- ["u_" .. user id] = { grants = { grant } }
local LOG_STORE = "AdminLog_v1" -- log = { list = { entry } }, the newest last
local LOG_KEY = "log"
local EVENT = "AdminGrant" -- the analytics custom event: the value is the amount

-- The save's defaults. paid[grant id] is when a pending grant was paid (kept until it is out of the store);
-- queue is the mini cannons that found the storage full and wait for room.
local SAVED = { paid = {}, queue = {} }

local Feature = {}

local function openStore(name: string)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if not ok then
		warn(`[Admin] the store {name} is unavailable: {result}`)
		return nil
	end
	return result
end

-- Whether that account may grant. The list, and the owner of a place that belongs to one user (a place that
-- belongs to a group has only the list: a group's id is not a person).
local function isAdmin(player: Player): boolean
	if Admin.IDS[player.UserId] ~= nil then
		return true
	end
	local ok, owner = pcall(function()
		return game.CreatorType == Enum.CreatorType.User and game.CreatorId ~= 0 and game.CreatorId == player.UserId
	end)
	return ok and owner == true
end
Feature.isAdmin = isAdmin

-- "500 gems", "2 Pumpkin Crate": what a grant is, for the toast, the result line and the log.
local function describe(kind: string, id: string?, amount: number): string
	if kind == "item" then
		local def = id and Items.get(id)
		return `{amount} {if def then def.name else id}`
	elseif kind == "pet" then
		local pet = id and Config.Pets[id]
		return `{amount} {if pet then pet.name else id}`
	end
	return `{Format.abbreviate(amount)} {kind}`
end

-- A log entry as one line of text.
local function line(entry): string
	return `{entry.byName} -> {entry.toName} ({entry.to}): {describe(entry.kind, entry.id, entry.amount)}, {entry.how}`
end

-- A grant as it may be paid: { kind, id?, amount }, or nil and why not. Used on what an admin sends and again
-- on what the store hands back, so a stored grant whose item has left the game is dropped, not paid.
local function validate(kind: any, id: any, amount: any): (any, string?)
	local def = if typeof(kind) == "string" then Admin.Kind[kind] else nil
	if not def then
		return nil, "Pick what to grant"
	end
	local whole = Admin.amount(kind, amount)
	if not whole then
		return nil, `The amount must be a whole number from 1 to {Format.abbreviate(def.cap)}`
	end
	if not def.needsId then
		return { kind = kind, amount = whole }, nil
	end
	if typeof(id) ~= "string" or #id == 0 or #id > Admin.ID_MAX then
		return nil, "Type the id of the thing to grant"
	end
	if kind == "item" and not Items.get(id) then
		return nil, `There is no item with the id "{id}"`
	elseif kind == "pet" and not Config.Pets[id] then
		return nil, `There is no mini cannon with the id "{id}"`
	end
	return { kind = kind, id = id, amount = whole }, nil
end

function Feature.start(Game)
	local grantStore, logStore = openStore(GRANT_STORE), openStore(LOG_STORE)
	local recent = {} -- the last log entries this server knows of, the newest last: { at, text }
	local recentLoaded = false -- whether the stored log has been read into `recent` yet
	local results: { [Player]: any } = {} -- [admin] = { n, ok, text }: the answer to their last GRANT
	local busy: { [Player]: boolean } = {} -- players whose pending grants are being paid right now
	local answers = 0

	-- How many mini cannons the player can store: Game.luau's petStorage, which a feature cannot call.
	local function storage(player: Player): number
		local count = Config.MaxPets
		for key, pass in Config.Passes do
			if pass.storage and Passes.owns(player, key) then
				count += pass.storage
			end
		end
		return count
	end

	-- What an admin's window shows. Nobody else is sent anything: their client makes no button.
	local function publish(player: Player)
		if not isAdmin(player) then
			return
		end
		local log = {}
		for index = math.max(1, #recent - Admin.LOG_SHOWN + 1), #recent do
			table.insert(log, recent[index])
		end
		Game.setMeta(player, "admin", { admin = true, log = log, result = results[player] })
	end

	local function answer(player: Player, text: string, ok: boolean)
		answers += 1
		results[player] = { n = answers, ok = ok, text = text }
		publish(player)
	end

	-- entry: { at, by, byName, to, toName, kind, id?, amount, how, grant? }. how: "online" (paid at once),
	-- "pending" (stored for the next join), "paid" (a stored one was paid), "dropped" (a stored one could not
	-- be paid). sender: the player the analytics event is logged for.
	local function record(entry, sender: Player?)
		local text = line(entry)
		if entry.how == "dropped" then
			warn(`[Admin] {text}`)
		else
			print(`[Admin] {text}`)
		end
		table.insert(recent, { at = entry.at, text = text })
		while #recent > Admin.LOG_SHOWN do
			table.remove(recent, 1)
		end
		for _, player in Players:GetPlayers() do
			publish(player)
		end
		-- The analytics feature's logger: AnalyticsService on a live server, nothing in Studio.
		local analytics = script.Parent:FindFirstChild("Analytics")
		if sender and analytics then
			pcall(function()
				local logger = require(analytics).logger
				if logger then
					local key = (Enum :: any).AnalyticsCustomFieldKeys.CustomField01.Name
					logger:LogCustomEvent(sender, EVENT, entry.amount, { [key] = `{entry.how}:{entry.kind}:{entry.id or ""}` })
				end
			end)
		end
		if logStore then
			task.spawn(function()
				local ok, err = pcall(logStore.UpdateAsync, logStore, LOG_KEY, function(current)
					local list = if typeof(current) == "table" and typeof(current.list) == "table" then current.list else {}
					table.insert(list, entry)
					while #list > Admin.LOG_KEPT do
						table.remove(list, 1)
					end
					return { list = list }
				end)
				if not ok then
					warn(`[Admin] the log could not be written: {err}`)
				end
			end)
		end
	end

	-- Candy from the team is a present, not candy earned: the event feature counts whatever a balance grows
	-- by as earned, so what it has counted is put back to what it was before the grant.
	local function giveCandy(player: Player, data, amount: number)
		local module = script.Parent:FindFirstChild("Event")
		local event = nil
		if module then
			local ok, result = pcall(require, module)
			event = if ok and typeof(result) == "table" and typeof(result.settle) == "function" then result else nil
		end
		if not event then
			data.candy += amount
			return
		end
		event.settle(player) -- what was really earned up to now is counted first
		local saved = data.features.event
		local before = {}
		if typeof(saved) == "table" and typeof(saved.earned) == "table" then
			for id, earned in saved.earned do
				before[id] = earned
			end
		end
		data.candy += amount
		event.settle(player)
		saved = data.features.event
		if typeof(saved) == "table" and typeof(saved.earned) == "table" then
			for id in saved.earned do
				saved.earned[id] = before[id]
			end
		end
	end

	-- Pays a checked grant into a loaded save, with the calls the game's own rewards use. Returns how many
	-- mini cannons had no room and wait in the queue. Never yields: see the note at the top.
	local function pay(player: Player, data, grant): number
		local waiting = 0
		if grant.kind == "gems" then
			data.diamonds += grant.amount
		elseif grant.kind == "coins" then
			data.coins += grant.amount
		elseif grant.kind == "candy" then
			giveCandy(player, data, grant.amount)
		elseif grant.kind == "item" then
			Game.items.give(player, grant.id, grant.amount)
		elseif grant.kind == "pet" then
			local saved = Game.feature(data, "admin", SAVED)
			for _ = 1, grant.amount do
				-- Never forced: a forced mini cannon pushes the player's weakest one out of a full storage.
				-- Behind whatever already waits, so they arrive in the order they were granted.
				local kept = #saved.queue == 0 and #data.pets < storage(player) and Game.pets.add(player, grant.id)
				if not kept then
					table.insert(saved.queue, grant.id)
					waiting += 1
				end
			end
		end
		return waiting
	end

	-- Whether this grant can be paid into this save at all (the save has that currency, the total stays a number).
	local function payable(data, grant): (boolean, string?)
		local field = nil
		if grant.kind == "gems" then
			field = "diamonds"
		elseif grant.kind == "coins" or grant.kind == "candy" then
			field = grant.kind
		end
		if field then
			local total = if typeof(data[field]) == "number" then data[field] + grant.amount else nil
			if not total or total ~= total or total == math.huge then
				return false, `That player's {grant.kind} cannot take this amount`
			end
		elseif grant.kind == "pet" then
			local saved = data.features.admin
			local queued = if typeof(saved) == "table" and typeof(saved.queue) == "table" then #saved.queue else 0
			if queued + grant.amount > Admin.QUEUE_MAX then
				return false, "That player already has too many mini cannons waiting for storage space"
			end
		end
		return true, nil
	end

	-- The target's toast: top right, like every other reward.
	local function gift(player: Player, grant, waiting: number)
		local text = `A gift from the team: +{describe(grant.kind, grant.id, grant.amount)}`
		if waiting > 0 then
			text ..= ` ({waiting} will arrive when your mini cannon storage has room)`
		end
		Game.notify(player, text, "good")
	end

	-- Whether a player on this server can be paid right now: their game is running and their save will be
	-- written (in Studio a save that cannot be written is all there is, and it is paid for the test's sake).
	local function ready(player: Player): boolean
		if not Game.data(player) or not Game.state(player) then
			return false
		end
		return Data.loaded(player) or RunService:IsStudio()
	end

	-- Pays what waits in the store for this player. Yields (the store, then the save).
	local function collect(player: Player)
		if not grantStore or busy[player] or not Game.data(player) or not Game.state(player) then
			return
		end
		-- Only into a save that will be written: an unsaved session would lose the reward.
		if not Data.loaded(player) then
			return
		end
		busy[player] = true
		local key = "u_" .. player.UserId
		local ok, stored = pcall(grantStore.GetAsync, grantStore, key)
		local data = Game.data(player)
		local list = if ok and typeof(stored) == "table" and typeof(stored.grants) == "table" then stored.grants else {}
		if not ok then
			warn(`[Admin] pending grants could not be read for {player.Name}: {stored}`)
		end
		if #list == 0 or not data or not Game.state(player) or not Data.loaded(player) or player.Parent == nil then
			busy[player] = nil
			return
		end

		local saved = Game.feature(data, "admin", SAVED)
		local done = {} -- [grant id] = true: paid now, paid before, or not payable at all
		local count = 0
		for _, entry in list do
			if typeof(entry) ~= "table" or typeof(entry.id) ~= "string" then
				continue
			end
			done[entry.id] = true
			count += 1
			if saved.paid[entry.id] then
				continue -- paid in a session that ended before the grant was taken out of the store
			end
			local grant = validate(entry.kind, entry.item, entry.amount)
			local how = "dropped"
			if grant and payable(data, grant) then
				-- Marked and paid with no yield between: one write of the save carries both.
				saved.paid[entry.id] = os.time()
				gift(player, grant, pay(player, data, grant))
				how = "paid"
			end
			record({
				at = os.time(),
				by = entry.by,
				byName = tostring(entry.byName),
				to = player.UserId,
				toName = player.Name,
				kind = tostring(entry.kind),
				id = if typeof(entry.item) == "string" then entry.item else nil,
				amount = if typeof(entry.amount) == "number" then entry.amount else 0,
				how = how,
				grant = entry.id,
			}, player)
		end
		Game.sync(player)

		-- The save first. If it does not go through, the grants stay in the store and the marks decide later.
		if count > 0 and Data.save(player) then
			local removed, err = pcall(grantStore.UpdateAsync, grantStore, key, function(current)
				local left = {}
				if typeof(current) == "table" and typeof(current.grants) == "table" then
					for _, entry in current.grants do
						-- A grant written while this ran is not in `done` and stays.
						if typeof(entry) == "table" and typeof(entry.id) == "string" and not done[entry.id] then
							table.insert(left, entry)
						end
					end
				end
				return { grants = left }
			end)
			if removed then
				for id in done do
					saved.paid[id] = nil
				end
			else
				warn(`[Admin] paid grants could not be removed for {player.Name}: {err}`)
			end
		end
		busy[player] = nil
	end
	Feature.collect = collect -- for tests

	-- Stores a grant for a player who is not here (or whose save is not loaded). Yields. Returns whether it
	-- was stored and, if not, why.
	local function store(userId: number, entry): (boolean, string?)
		if not grantStore then
			return false, "The grant store is not available"
		end
		local full = false
		local ok, err = pcall(grantStore.UpdateAsync, grantStore, "u_" .. userId, function(current)
			local list = if typeof(current) == "table" and typeof(current.grants) == "table" then current.grants else {}
			full = #list >= Admin.PENDING_MAX
			if full then
				return nil -- cancels the write
			end
			table.insert(list, entry)
			return { grants = list }
		end)
		if not ok then
			warn(`[Admin] a pending grant could not be stored for {userId}: {err}`)
			return false, "The grant could not be stored. Try again"
		elseif full then
			return false, `That player already has {Admin.PENDING_MAX} grants waiting`
		end
		return true, nil
	end

	-- Who the admin means: a player on this server, or an account looked up on Roblox. Yields for a lookup.
	-- Returns the user id, the name and the player if they are here; or nothing and why.
	local function resolve(target: any): (number?, string?, Player?, string?)
		local userId, name = Admin.target(target)
		if not userId and not name then
			return nil, nil, nil, "Type a username or a user id"
		end
		for _, player in Players:GetPlayers() do
			if player.UserId == userId or (name and string.lower(player.Name) == string.lower(name)) then
				return player.UserId, player.Name, player, nil
			end
		end
		if name then
			local ok, result = pcall(Players.GetUserIdFromNameAsync, Players, name)
			if not ok or typeof(result) ~= "number" then
				return nil, nil, nil, `No Roblox player is called "{name}"`
			end
			return result, name, Players:GetPlayerByUserId(result), nil
		end
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if not ok or typeof(result) ~= "string" then
			return nil, nil, nil, `No Roblox player has the id {userId}`
		end
		return userId, result, Players:GetPlayerByUserId(userId :: number), nil
	end

	-- GRANT in the ADMIN window. argument: { target = username or user id, kind, id?, amount }.
	Game.actions.adminGrant = function(player: Player, _data, _state, argument)
		if not isAdmin(player) then
			warn(`[Admin] {player.Name} ({player.UserId}) is not an admin and asked for a grant: refused`)
			return
		end
		if typeof(argument) ~= "table" then
			answer(player, "Nothing to grant", false)
			return
		end
		local grant, why = validate(argument.kind, argument.id, argument.amount)
		if not grant then
			answer(player, why or "That cannot be granted", false)
			return
		end
		local userId, name, target, problem = resolve(argument.target)
		if not userId or not name then
			answer(player, problem or "That player was not found", false)
			return
		end
		local what = describe(grant.kind, grant.id, grant.amount)
		local entry = {
			at = os.time(),
			by = player.UserId,
			byName = player.Name,
			to = userId,
			toName = name,
			kind = grant.kind,
			id = grant.id,
			amount = grant.amount,
			how = "online",
		}

		-- The lookup may have waited: a target who left meanwhile is paid at their next join instead.
		if target and target.Parent ~= nil and ready(target) then
			local data = Game.data(target)
			local fits, whyNot = payable(data, grant)
			if not fits then
				answer(player, whyNot or "That cannot be paid", false)
				return
			end
			local waiting = pay(target, data, grant)
			Game.sync(target)
			gift(target, grant, waiting)
			record(entry, player)
			answer(player, `Granted {what} to {name}` .. (if waiting > 0 then ` ({waiting} waiting for storage space)` else ""), true)
			return
		end

		entry.how = "pending"
		-- Unique for ever: the time, this server's count and a GUID. `item` is the id of the thing granted
		-- (`id` is the grant's own).
		local pending = {
			id = `{os.time()}-{answers}-{HttpService:GenerateGUID(false)}`,
			kind = grant.kind,
			item = grant.id,
			amount = grant.amount,
			by = player.UserId,
			byName = player.Name,
			at = entry.at,
		}
		local stored, whyNot = store(userId, pending)
		if not stored then
			answer(player, whyNot or "The grant could not be stored", false)
			return
		end
		entry.grant = pending.id
		record(entry, player)
		answer(player, `Stored {what} for {name}: paid when they next join`, true)
		-- On this server after all (still loading when asked, or joined during the lookup): pay it now.
		local here = Players:GetPlayerByUserId(userId)
		if here then
			task.defer(collect, here)
		end
	end

	Game.on("ready", function(player: Player)
		publish(player)
		if isAdmin(player) and logStore and not recentLoaded then
			-- The window's last lines, from before this server started. Read once, for the first admin.
			recentLoaded = true
			task.defer(function()
				local ok, stored = pcall(logStore.GetAsync, logStore, LOG_KEY)
				if not ok or typeof(stored) ~= "table" or typeof(stored.list) ~= "table" then
					return
				end
				local lines = {}
				for index = math.max(1, #stored.list - Admin.LOG_SHOWN + 1), #stored.list do
					local entry = stored.list[index]
					if typeof(entry) == "table" and typeof(entry.kind) == "string" and typeof(entry.amount) == "number" then
						table.insert(lines, { at = entry.at, text = line(entry) })
					end
				end
				for _, newer in recent do
					table.insert(lines, newer)
				end
				while #lines > Admin.LOG_SHOWN do
					table.remove(lines, 1)
				end
				recent = lines
				for _, other in Players:GetPlayers() do
					publish(other)
				end
			end)
		end
		-- Deferred: a hook must not hold the join up, and the other features' ready hooks see the save first.
		task.defer(collect, player)
	end)

	-- Mini cannons that found the storage full arrive as soon as there is room.
	Game.on("tick", function(player: Player, data)
		local saved = data.features.admin
		if typeof(saved) ~= "table" or typeof(saved.queue) ~= "table" or #saved.queue == 0 then
			return
		end
		local arrived = 0
		while #saved.queue > 0 and #data.pets < storage(player) do
			local id = table.remove(saved.queue, 1)
			if typeof(id) == "string" and Config.Pets[id] and Game.pets.add(player, id) then
				arrived += 1
			end
		end
		if arrived > 0 then
			Game.notify(player, `A gift from the team arrived: +{arrived} mini cannon{if arrived == 1 then "" else "s"}`, "good")
		end
	end)

	Game.on("leave", function(player: Player)
		results[player] = nil
		busy[player] = nil
	end)
end

return Feature
