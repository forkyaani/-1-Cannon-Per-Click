-- Player save data, session-locked: only one server at a time holds a player's save.
-- Loading claims the save by writing a lock into it (this server's id and the time); every save renews the lock
-- and the last one clears it. A server that finds another server's fresh lock waits for it to let go, and gives
-- up rather than load a save that may still change. Without this two servers can each hold a copy of the same
-- player, and whatever was traded away on one comes back from the other.
local DataStoreService = game:GetService("DataStoreService")

local Data = {}

local STORE_NAME = "PlayerData_v4" -- v2 was the clicker; its saves (test saves only) are dropped
local LOAD_ATTEMPTS = 3 -- tries at a load while the store itself is failing
local RELEASE_ATTEMPTS = 3 -- the last save is worth retrying: it also frees the lock
local LOCK_KEY = "_session" -- the lock inside the stored table: { job = server id, at = unix time }
-- A lock this old was left by a server that died. Keep it well above the autosave interval (Game.luau), which
-- is what renews the lock of a server that is alive.
local LOCK_STALE_SECONDS = 300
local LOCK_WAIT_SECONDS = 30 -- how long a load waits for another server to let go
local LOCK_RETRY_SECONDS = 2
local CLOSE_WAIT_SECONDS = 25 -- of the 30 a closing server is given

-- The name this server signs its locks with. Studio has no JobId; all its play tests share one name, so a
-- test that ended badly never locks the next one out.
local SESSION = if game.JobId ~= "" then game.JobId else "studio"

-- Empty tables are free-form (lists or maps the game fills in); tables with keys are fixed shapes.
local DEFAULTS = {
	coins = 0,
	diamonds = 0,
	candy = 0,
	wave = 1, -- global level being fought (the save still calls a level a wave)
	cleared = 0, -- highest global level cleared in this run: a rebirth takes it back to 0
	bestCleared = 0, -- the highest ever, over every run. Unlocks (tower kinds, eggs, islands, the story) read this one
	rebirths = 0, -- how often the player has rebirthed: +Config.Rebirth.damage tower damage each
	autoAdvance = true,
	speed = 1, -- the game speed the player picked: 1, 2 or 3 (MAX_SPEED in Game.luau)
	masteryKills = 0, -- monsters defeated, for the Veteran level (it was called Cannon Mastery: the key stays)
	pads = { 1 }, -- indices (into Layout.PADS) of the pads the player owns; the first is free
	towers = { ["1"] = { kind = "cannon", level = 1 } }, -- [pad index as a string] = { kind, level }: JSON has no number keys
	pets = {},
	items = {}, -- stackable backpack items: [item id] = count
	features = {}, -- each feature's own saved table: [feature name] = {...}
	receipts = {}, -- recent Robux purchase ids already granted
	extraSlots = 0,
	boosts = {},
	daily = { last = 0, streak = 0 },
	missions = { day = 0, progress = {}, claimed = {} },
	weekly = { week = 0, bought = {} },
	event = { bought = {} },
	totalKills = 0,
	totalHatches = 0,
	lastSeen = 0, -- unix time of the last save: how long the player was away is counted from it (0 = never saved)
	-- Dead constants from the clicker. The core never changes them; they are here so the features written for
	-- it (Huge, Story, Powerups) read a number instead of nil. Remove each when its last reader is adapted.
	power = 0,
	totalPower = 0,
	cannon = 1,
	autoRebirth = false,
	totalClicks = 0,
}

-- Defaults that are lists or maps with content of their own: a save takes them whole, or not at all.
-- (reconcile would otherwise read `pads = { 1 }` as a fixed shape with the one key 1.)
local WHOLE = { pads = true, towers = true }

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

-- What a brand-new save holds under `key`, as a copy the caller may keep: a rebirth puts the levels, the
-- coins, the pads and the towers back to this.
function Data.fresh(key: string): any
	return deepCopy(DEFAULTS[key])
end

local profiles = {} -- [player] = { key, player, data, canSave, why }
local sessions = {} -- [key] = the profile that holds that save's lock on this server
local queues = {} -- [key] = threads waiting for the request that key has in flight
local pending = 0 -- store requests in flight or waiting, on any key

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore unavailable, progress will not save: " .. tostring(result))
	end
end

local function reconcile(saved, defaults)
	local data = {}
	for key, default in defaults do
		local value = if typeof(saved) == "table" then saved[key] else nil
		if WHOLE[key] then
			-- Game.luau checks what is inside (pad indices, tower kinds and levels) when the player joins.
			data[key] = if typeof(value) == "table" then value else deepCopy(default)
		elseif typeof(default) == "table" then
			if next(default) == nil then
				data[key] = if typeof(value) == "table" then value else {}
			else
				data[key] = reconcile(value, default)
			end
		elseif typeof(value) == typeof(default) then
			data[key] = value
		else
			data[key] = default
		end
	end
	return data
end

-- Requests for one key run one at a time, in the order they were made: a save must not land after the release
-- that followed it, and a player who rejoins this server must not load before their last save is written.
local function enter(key: string)
	pending += 1
	local waiting = queues[key]
	if waiting then
		table.insert(waiting, coroutine.running())
		coroutine.yield()
	else
		queues[key] = {}
	end
end

local function leave(key: string)
	pending -= 1
	local nextInLine = table.remove(queues[key], 1)
	if nextInLine then
		task.spawn(nextInLine)
	else
		queues[key] = nil
	end
end

-- Whether a stored lock belongs to another server that is still alive.
local function heldElsewhere(lock): boolean
	return typeof(lock) == "table"
		and lock.job ~= SESSION
		and typeof(lock.at) == "number"
		and os.time() - lock.at < LOCK_STALE_SECONDS
end

-- One try at claiming the save for this server. Returns "claimed" and what is stored, "locked" while someone
-- else holds it, or "failed" when the store did not answer.
local function claim(profile): (string, any)
	local key = profile.key
	enter(key)
	local status, saved = "failed", nil
	if sessions[key] then
		-- Held on this very server: the same player rejoined before their old profile was released.
		status = "locked"
	else
		-- UpdateAsync reads and writes in one step, so two servers can never both find the save free.
		local ok, err = pcall(store.UpdateAsync, store, key, function(current)
			local value = if typeof(current) == "table" then current else {}
			if heldElsewhere(value[LOCK_KEY]) then
				status, saved = "locked", nil
				return nil -- cancels the write: the save stays the other server's
			end
			-- No lock (an old save, or one released properly), a dead server's lock, or our own.
			value[LOCK_KEY] = { job = SESSION, at = os.time() }
			status, saved = "claimed", value
			return value
		end)
		if not ok then
			status, saved = "failed", nil
			warn(`[Data] load failed for {key}: {err}`)
		elseif status == "claimed" then
			sessions[key] = profile
		end
	end
	leave(key)
	return status, saved
end

-- Yields until the save is claimed for this server and returns what is stored. Gives up (nil) when the store
-- keeps failing, when another server holds the lock for too long, or when the player has already left.
local function acquire(profile): any
	local deadline = os.clock() + LOCK_WAIT_SECONDS
	local failures = 0
	while profile.player.Parent do
		local status, saved = claim(profile)
		if status == "claimed" then
			profile.canSave = true
			return saved
		elseif status == "locked" then
			if os.clock() >= deadline then
				profile.why = "locked"
				warn(`[Data] {profile.key} is locked by another server; loading without saving`)
				return nil
			end
			task.wait(LOCK_RETRY_SECONDS)
		else
			failures += 1
			if failures >= LOAD_ATTEMPTS then
				return nil
			end
			task.wait(failures)
		end
	end
	return nil
end

-- Yields. Returns the data table and whether it loaded from the store and is locked to this server.
-- If loading failed (the store is down, or another server still holds the save) the profile is never saved,
-- so a bad load cannot wipe a real save.
function Data.load(player: Player)
	local profile = { key = "u_" .. player.UserId, player = player, canSave = false, why = "offline" }
	local saved = if store then acquire(profile) else nil
	profile.data = reconcile(saved, DEFAULTS)
	profiles[player] = profile
	return profile.data, profile.canSave
end

function Data.get(player: Player)
	local profile = profiles[player]
	return profile and profile.data
end

-- Whether the player's save is loaded and locked to this server. Only then can what they own be trusted with
-- something another player depends on, like a trade. When it is not, the second value says why: "locked"
-- (another server holds the save) or "offline" (the store did not answer).
function Data.loaded(player: Player): (boolean, string?)
	local profile = profiles[player]
	if profile and profile.canSave then
		return true
	end
	return false, profile and profile.why
end

-- Another server has taken the save over (this server's lock went stale while the store was failing).
-- Nothing more may be written from here, and the player is sent off to rejoin: playing on would not save.
local function lose(profile)
	profile.canSave = false
	profile.why = "locked"
	if sessions[profile.key] == profile then
		sessions[profile.key] = nil
	end
	warn(`[Data] lost the lock on {profile.key}`)
	if profile.player.Parent then
		profile.player:Kick("Your save was opened on another server. Please rejoin.")
	end
end

-- Writes the profile and renews its lock, or clears the lock when this is the last save. The store is only
-- written while the lock in it is still this server's. Yields. Returns whether the save went through.
local function write(profile, last: boolean): boolean
	if not store or not profile.canSave then
		return false
	end
	local key = profile.key
	local attempts = if last then RELEASE_ATTEMPTS else 1
	enter(key)
	local saved = false
	for attempt = 1, attempts do
		-- Asked again here: the request this one waited behind may have found the lock gone.
		if not profile.canSave then
			break
		end
		local mine, gone = false, false
		local ok, err = pcall(store.UpdateAsync, store, key, function(current)
			local lock = if typeof(current) == "table" then current[LOCK_KEY] else nil
			mine = typeof(lock) == "table" and lock.job == SESSION
			gone = lock == nil
			if not mine then
				return nil -- cancels the write: it would undo another server's work
			end
			-- A copy, so the lock never shows up in the data the game works on.
			local value = table.clone(profile.data)
			value[LOCK_KEY] = if last then nil else { job = SESSION, at = os.time() }
			return value
		end)
		if not ok then
			warn(`[Data] save failed for {key}: {err}`)
			if attempt < attempts then
				task.wait(attempt)
			end
		elseif mine or (gone and attempt > 1) then
			-- A retry that finds the lock gone means the try before it did land after all.
			saved = true
			break
		else
			lose(profile)
		end
	end
	if last then
		profile.canSave = false
		if sessions[key] == profile then
			sessions[key] = nil
		end
	end
	leave(key)
	return saved
end

-- Testing only: puts the player's save back to a brand new player's, in the same table. Whatever the session
-- worked out from the old save is stale afterwards, so the player has to rejoin.
function Data.reset(player: Player)
	local profile = profiles[player]
	if profile then
		table.clear(profile.data)
		for key, value in reconcile(nil, DEFAULTS) do
			profile.data[key] = value
		end
	end
end

-- Yields. Returns whether the save went through.
function Data.save(player: Player): boolean
	local profile = profiles[player]
	if profile then
		profile.data.lastSeen = os.time() -- every save says when the player was last here (offline earnings)
	end
	return profile ~= nil and write(profile, false)
end

-- Saves one last time, frees the lock and forgets the profile. Returns whether the save went through.
-- The profile is forgotten before the save yields: on shutdown PlayerRemoving and BindToClose both release
-- the same player, and the second one must find nothing to write.
function Data.release(player: Player): boolean
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		profile.data.lastSeen = os.time()
	end
	return profile ~= nil and write(profile, true)
end

-- A release started by PlayerRemoving is in nobody's BindToClose handler, so a closing server could stop with
-- the last save, and the lock, still on its way. Hold the server open until every profile is released and written.
game:BindToClose(function()
	local deadline = os.clock() + CLOSE_WAIT_SECONDS
	while (pending > 0 or next(profiles) ~= nil) and os.clock() < deadline do
		task.wait(0.2)
	end
end)

return Data
