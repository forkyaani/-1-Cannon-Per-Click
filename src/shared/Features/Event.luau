-- Events: a stretch of time with a currency of its own, a global leaderboard of who EARNED the most of it, and
-- prizes for the best few when it ends. An event is one entry in Event.List: a new one (Christmas) is that
-- entry plus the Huge its winners get, and nothing else in this feature changes.
-- The server half (src/server/Features/Event.luau) counts what is earned, runs the board, freezes the ranking
-- at the end and pays the winners; the client half shows the time left, the prizes and the player's own place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Event = {}

local rgb = Color3.fromRGB

-- How long after an event's end its ranking is frozen. Until SUBMIT_GRACE the board still takes the scores of
-- players who were online at the end (their next autosave sends them); nothing is earned after the end itself.
Event.SUBMIT_GRACE = 240
Event.FREEZE_DELAY = 300
-- How long after its end an event's board stays up, in the marketplace and in TOP PLAYERS.
Event.SHOW_SECONDS = 14 * 86_400
-- The board reads this many entries, so a player this high up can be told their rank.
Event.RANKED = 100

-- id            names the save's counters, the board's store and the winners' record. Never reuse one: next
--               year's Halloween is a new id, or last year's winners would be this year's
-- name, icon    what players read
-- currency      the save field that is earned ("candy"); currencyName is what players call it
-- startsAt, endsAt   unix seconds (UTC). Earning counts from the start up to the end
-- rewards       who wins what, by final rank: { from, to, kind = "pet", pet = id } or { from, to, kind = "gems",
--               amount }. Ranks nobody lists win nothing
Event.List = {
	{
		id = "halloween2026",
		name = "Halloween",
		icon = "🎃",
		color = rgb(255, 130, 30),
		currency = "candy",
		currencyName = "candy",
		startsAt = Config.Halloween.startsAt or 0, -- it was live before this board was built
		endsAt = Config.Halloween.endsAt,
		rewards = {
			{ from = 1, to = 3, kind = "pet", pet = "hugespectre" },
			{ from = 4, to = 4, kind = "gems", amount = 2_500 },
			{ from = 5, to = 5, kind = "gems", amount = 1_500 },
		},
	},
	-- Christmas, when it is built: this entry, a `christmasCandy = 0` in the save (src/server/Data.luau), its
	-- name in Config.CurrencyNames, and the Huge its winners get (defineHuge in Config.luau, a feature in
	-- Features/Huge.luau). Whatever pays Christmas candy only has to add to data.christmasCandy.
	-- {
	-- 	id = "christmas2026",
	-- 	name = "Christmas",
	-- 	icon = "🎄",
	-- 	color = rgb(220, 50, 60),
	-- 	currency = "christmasCandy",
	-- 	currencyName = "Christmas candy",
	-- 	startsAt = 1796083200, -- 2026-12-01 00:00 UTC
	-- 	endsAt = 1798761600, -- 2027-01-01 00:00 UTC
	-- 	rewards = {
	-- 		{ from = 1, to = 3, kind = "pet", pet = "hugesnowman" },
	-- 		{ from = 4, to = 4, kind = "gems", amount = 2_500 },
	-- 		{ from = 5, to = 5, kind = "gems", amount = 1_500 },
	-- 	},
	-- },
}

Event.ById = {}

-- Checks an entry and fills in what is worked out from it. The list above goes through it; a test adds an
-- event of its own the same way.
function Event.define(event)
	assert(typeof(event.id) == "string" and not Event.ById[event.id], `event id {tostring(event.id)} is missing or used twice`)
	assert(typeof(event.currency) == "string", `event {event.id} has no currency`)
	assert(typeof(event.startsAt) == "number" and typeof(event.endsAt) == "number" and event.startsAt < event.endsAt, `event {event.id} has no dates`)
	event.winners = 0 -- how many ranks win something
	for _, reward in event.rewards do
		assert(reward.from >= 1 and reward.to >= reward.from, `event {event.id} has a reward without ranks`)
		if reward.kind == "pet" then
			assert(Config.Pets[reward.pet], `event {event.id} gives an unknown mini cannon {tostring(reward.pet)}`)
		else
			assert(reward.kind == "gems" and reward.amount > 0, `event {event.id} has an unknown reward`)
		end
		event.winners = math.max(event.winners, reward.to)
	end
	event.board = "Event_" .. event.id -- the board's id (Leaderboard.luau, ReplicatedStorage.Leaderboards)
	event.currencyName = event.currencyName or event.currency
	event.color = event.color or rgb(255, 205, 60)
	event.icon = event.icon or "🏆"
	Event.ById[event.id] = event
	if not table.find(Event.List, event) then
		table.insert(Event.List, event)
	end
	return event
end
for _, event in table.clone(Event.List) do
	Event.define(event)
end

-- Earning counts: from the start up to the end.
function Event.live(event, now: number): boolean
	return now >= event.startsAt and now < event.endsAt
end

-- The board is up: from the start until SHOW_SECONDS after the end.
function Event.shown(event, now: number): boolean
	return now >= event.startsAt and now < event.endsAt + Event.SHOW_SECONDS
end

-- The ranking can be frozen: nobody's score changes any more.
function Event.over(event, now: number): boolean
	return now >= event.endsAt + Event.FREEZE_DELAY
end

-- What a final rank wins, or nil.
function Event.reward(event, rank: number)
	for _, reward in event.rewards do
		if rank >= reward.from and rank <= reward.to then
			return reward
		end
	end
	return nil
end

-- "a Huge Spectre Cannon", "2,500 gems": a prize in words.
function Event.rewardText(reward): string
	if reward.kind == "pet" then
		return `a {Config.Pets[reward.pet].name}`
	end
	return `{Event.commas(reward.amount)} gems`
end

-- 2500 -> "2,500": a prize is a number people repeat, so it is written out.
function Event.commas(amount: number): string
	local text = tostring(math.floor(amount))
	while true do
		local changed, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = changed
		if count == 0 then
			return text
		end
	end
end

local function ordinal(rank: number): string
	local last, lastTwo = rank % 10, rank % 100
	if last == 1 and lastTwo ~= 11 then
		return `{rank}st`
	elseif last == 2 and lastTwo ~= 12 then
		return `{rank}nd`
	elseif last == 3 and lastTwo ~= 13 then
		return `{rank}rd`
	end
	return `{rank}th`
end
Event.ordinal = ordinal

-- The prizes, one line each: "Top 3: Huge Spectre Cannon", "4th: 2,500 gems".
function Event.prizeLines(event): { string }
	local lines = {}
	for _, reward in event.rewards do
		local who = if reward.from == reward.to then ordinal(reward.from) elseif reward.from == 1 then `Top {reward.to}` else `{ordinal(reward.from)} to {ordinal(reward.to)}`
		local what = if reward.kind == "pet" then Config.Pets[reward.pet].name else `{Event.commas(reward.amount)} gems`
		table.insert(lines, `{who}: {what}`)
	end
	return lines
end

-- A score on the board: "12.4K candy earned".
function Event.scoreText(event, score: number): string
	return `{Format.abbreviate(score)} {event.currencyName}`
end

return Event
