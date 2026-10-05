-- Global top-10 boards (OrderedDataStores) published to clients as JSON in ReplicatedStorage.Leaderboards.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Leaderboard = {}

-- Optional hook: called with (board id, rows) after each refresh, for boards built in the world.
Leaderboard.onRefresh = nil :: ((id: string, rows: { { name: string, text: string } }) -> ())?

local REFRESH_SECONDS = 90
local TOP = 10
local PAGE_MAX = 100 -- the most entries one page of an OrderedDataStore holds

-- An OrderedDataStore holds whole numbers up to about 9e18, and Cannon Power passes that in the second world.
-- It is stored as its logarithm: POWER_SCALE steps per power of ten keeps six digits, more than a board shows.
local POWER_SCALE = 1_000_000

-- The three boards, in the order they are shown: Gems, Rebirths, Cannon Power. `id` names the StringValue in
-- ReplicatedStorage.Leaderboards and the board in the marketplace (Marketplace.setBoard); `title` is its
-- heading in the TOP PLAYERS window (the Title attribute).
-- score(data, stats) -> a whole number, 0 for "nothing to show". stats is what the save does not hold:
-- { power = the player's Cannon Power (their towers' total damage per second) }.
-- A feature adds a board of its own with Leaderboard.add (the event boards: Features/Event.luau).
local BOARDS = {
	{
		id = "Gems",
		title = "MOST GEMS",
		storeName = "LB_Gems_v1",
		score = function(data): number
			return math.max(0, math.floor(data.diamonds))
		end,
		format = function(score: number): string
			return Format.abbreviate(score) .. " gems"
		end,
	},
	{
		id = "Rebirths",
		title = "MOST REBIRTHS",
		storeName = "LB_Rebirths_v2", -- v1 was the clicker's
		score = function(data): number
			return math.clamp(math.floor(data.rebirths), 0, #Config.Worlds)
		end,
		format = function(score: number): string
			return if score == 1 then "1 rebirth" else `{score} rebirths`
		end,
	},
	{
		id = "Power",
		title = "MOST CANNON POWER",
		storeName = "LB_CannonPower_v1",
		score = function(_data, stats): number
			local power = if stats then stats.power else nil
			if typeof(power) ~= "number" or power ~= power or power < 1 or power == math.huge then
				return 0
			end
			return math.floor(math.log10(power) * POWER_SCALE)
		end,
		format = function(score: number): string
			return Format.abbreviate(10 ^ (score / POWER_SCALE)) .. " Cannon Power"
		end,
	},
}

local names = {}

local function nameFor(userId: number): string
	if not names[userId] then
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if ok then result else "Player"
	end
	return names[userId]
end

local folder: Folder? = nil -- ReplicatedStorage.Leaderboards, once started

local function boardById(id: string)
	for _, board in BOARDS do
		if board.id == id then
			return board
		end
	end
	return nil
end

local function submitTo(board, player: Player, data, stats: { power: number }?)
	local score = board.score(data, stats)
	if board.store and typeof(score) == "number" and score > 0 then
		local ok, err = pcall(board.store.SetAsync, board.store, tostring(player.UserId), score)
		if not ok then
			warn(`[Leaderboard] {board.id} submit failed: {err}`)
		end
	end
end

-- stats: { power = the player's Cannon Power right now }, from Game.luau. Without it that board is skipped.
function Leaderboard.submit(player: Player, data, stats: { power: number }?)
	for _, board in BOARDS do
		submitTo(board, player, data, stats)
	end
end

-- One board only, right now: for a feature whose board is about to close.
function Leaderboard.submitOne(id: string, player: Player, data)
	local board = boardById(id)
	if board then
		submitTo(board, player, data, nil)
	end
end

-- The best `count` (at most 100) of a board, straight from the store: { { userId = number, score = number } },
-- best first. nil when the store could not be read, which is not the same as an empty board: the caller
-- tries again later. Yields.
function Leaderboard.top(id: string, count: number): { { userId: number, score: number } }?
	local board = boardById(id)
	if not board or not board.store then
		return nil
	end
	local ok, pages = pcall(board.store.GetSortedAsync, board.store, false, math.clamp(count, 1, PAGE_MAX))
	if not ok then
		warn(`[Leaderboard] {id} read failed: {pages}`)
		return nil
	end
	local list = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId and #list < count then
			table.insert(list, { userId = userId, score = entry.value })
		end
	end
	return list
end

local function refreshBoard(board)
	if not board.store or not board.value then
		return
	end
	-- board.top: how many entries a feature wants to see in onEntries (the shown rows stay the best ten).
	local size = math.clamp(board.top or TOP, TOP, PAGE_MAX)
	local ok, pages = pcall(board.store.GetSortedAsync, board.store, false, size)
	if not ok then
		warn(`[Leaderboard] {board.id} refresh failed: {pages}`)
		return
	end
	local entries = pages:GetCurrentPage()
	local rows = {}
	for rank, entry in entries do
		if rank > TOP then
			break
		end
		rows[rank] = { name = nameFor(tonumber(entry.key) :: number), text = board.format(entry.value) }
	end
	board.value.Value = HttpService:JSONEncode(rows)
	if board.onEntries then
		-- (entries, rows): the store's own { key = user id as a string, value = score } list, and what is shown.
		local fine, err = pcall(board.onEntries, entries, rows)
		if not fine then
			warn(`[Leaderboard] {board.id} onEntries failed: {err}`)
		end
	end
	if Leaderboard.onRefresh then
		Leaderboard.onRefresh(board.id, rows)
	end
end

-- Reads every board again and publishes it. Runs by itself every REFRESH_SECONDS. Yields.
local function refresh()
	for _, board in BOARDS do
		refreshBoard(board)
	end
end
Leaderboard.refresh = refresh

-- Opens a board's store and makes the StringValue the clients read it from.
local function open(board, order: number)
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(board.storeName)
	end)
	if ok then
		board.store = result
	else
		warn(`[Leaderboard] {board.id} unavailable: {result}`)
	end
	local value = Instance.new("StringValue")
	value.Name = board.id
	value.Value = "[]"
	-- The TOP PLAYERS window shows the boards in this order, under these headings.
	value:SetAttribute("Order", order)
	value:SetAttribute("Title", board.title)
	-- Anything else the window should know about the board (an event board says which event it is).
	for name, attribute in board.attributes or {} do
		value:SetAttribute(name, attribute)
	end
	value.Parent = folder
	board.value = value
end

-- A board of a feature's own, shown after the three above and submitted and refreshed with them:
--   { id, title, storeName, score = function(data) -> whole number (0 = do not submit), format = function(score) -> text,
--     top = entries to read (10 to 100), onEntries = function(entries, rows) after each refresh, attributes = { name = value } }
-- An id that is already there is left alone. May be called before or after Leaderboard.start.
function Leaderboard.add(board)
	if boardById(board.id) then
		return
	end
	table.insert(BOARDS, board)
	if folder then
		open(board, #BOARDS)
		task.spawn(refreshBoard, board)
	end
end

function Leaderboard.start()
	local made = Instance.new("Folder")
	made.Name = "Leaderboards"
	folder = made
	for order, board in BOARDS do
		open(board, order)
	end
	made.Parent = ReplicatedStorage

	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return Leaderboard
