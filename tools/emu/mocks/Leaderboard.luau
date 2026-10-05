-- Stand-in for src/server/Leaderboard.luau.
local Leaderboard = { onRefresh = nil, submitted = 0, last = nil :: any }

-- What a test may look at and fill in:
--   added[id]   the boards the features added (Leaderboard.add)
--   scores[id]  [user id] = the score last submitted to an added board
--   fake[id]    what Leaderboard.top answers for that board: { { userId, score } }, best first (nil = the read fails)
Leaderboard.added = {}
Leaderboard.scores = {}
Leaderboard.fake = {}

function Leaderboard.start() end

function Leaderboard.add(board)
	Leaderboard.added[board.id] = Leaderboard.added[board.id] or board
	Leaderboard.scores[board.id] = Leaderboard.scores[board.id] or {}
end

local function submitTo(id: string, player: Player, data)
	local score = Leaderboard.added[id].score(data, nil)
	if score > 0 then
		Leaderboard.scores[id][player.UserId] = score
	end
end

-- stats: { power = the player's Cannon Power }, kept for the test to look at.
function Leaderboard.submit(player: Player, data, stats)
	Leaderboard.submitted += 1
	Leaderboard.last = stats
	for id in Leaderboard.added do
		submitTo(id, player, data)
	end
end

function Leaderboard.submitOne(id: string, player: Player, data)
	if Leaderboard.added[id] then
		submitTo(id, player, data)
	end
end

function Leaderboard.top(id: string, count: number)
	local list = Leaderboard.fake[id]
	if not list then
		return nil
	end
	local best = {}
	for index = 1, math.min(count, #list) do
		best[index] = list[index]
	end
	return best
end

-- Hands an added board the entries a refresh would: { { key = user id as a string, value = score } }.
function Leaderboard.refresh(id: string, entries)
	local board = Leaderboard.added[id]
	if board and board.onEntries then
		board.onEntries(entries, {})
	end
end

return Leaderboard
