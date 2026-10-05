-- Events on the client (the events are data: src/shared/Features/Event.luau; the server counts, ranks and
-- pays: src/server/Features/Event.luau). This file only shows things:
--   * under an event's column in TOP PLAYERS: the time left, the prizes, and the player's own earnings and rank
--   * in the event shop's heading: the player's own earnings and rank
--   * the full-screen moment when the player is paid a prize: the Huge reveal for a Huge, a card for gems
-- What it reads: State.feature("event") = { list = { [event id] = { earned, rank?, place?, final } }, reward? }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Event"))

local REVEAL_DELAY = 4 -- seconds after the prize arrives: on joining, the screen is still loading
local GEMS_SECONDS = 7 -- how long the gem prize's card stays up
local GEMS_HOLD = 1.5 -- and how long a tap cannot take it off the screen

local function start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors

	local function own(event)
		local list = State.feature("event").list
		local entry = if typeof(list) == "table" then list[event.id] else nil
		return if typeof(entry) == "table" then entry else {}
	end

	local function clock(event, final: boolean): string
		local now = State.now()
		if final then
			return "FINAL RANKING"
		elseif now >= event.endsAt then
			return "Event over: final ranking soon"
		end
		return `Ends in {Format.duration(event.endsAt - now)}`
	end

	-- The player's own line: what they earned and where that puts them.
	local function ownLine(event): string
		local entry = own(event)
		local earned = if typeof(entry.earned) == "number" then entry.earned else 0
		if entry.final then
			if typeof(entry.place) == "number" then
				return `You finished {Shared.ordinal(entry.place)}!`
			end
			return `You earned {Format.abbreviate(earned)} {event.currencyName}`
		elseif earned <= 0 then
			return `Earn {event.currencyName} to get on the board`
		end
		local rank = if typeof(entry.rank) == "number" then `rank #{entry.rank}` else `not in the top {Shared.RANKED} yet`
		return `You: {Format.abbreviate(earned)} earned  •  {rank}`
	end

	-- TOP PLAYERS: the lines under the event board's heading.
	local notes = ctx.Windows.boardNotes
	if typeof(notes) == "table" then
		for _, event in Shared.List do
			local prizes = Shared.prizeLines(event)
			local first = table.remove(prizes, 1) or ""
			local rest = table.concat(prizes, "  •  ")
			notes[event.board] = function(): string
				local lines = { clock(event, own(event).final == true), first }
				if rest ~= "" then
					table.insert(lines, rest)
				end
				table.insert(lines, ownLine(event))
				return table.concat(lines, "\n")
			end
		end
	end

	-- The event shop's heading: the event that pays the shop's currency, while it is live.
	ctx.Windows.shopNote = function(currency: string): string?
		local now = State.now()
		for _, event in Shared.List do
			if event.currency == currency and Shared.live(event, now) then
				local entry = own(event)
				local earned = if typeof(entry.earned) == "number" then entry.earned else 0
				if earned <= 0 then
					return nil
				end
				local rank = if typeof(entry.rank) == "number" then `  •  rank #{entry.rank}` else ""
				return `earned {Format.abbreviate(earned)}{rank}`
			end
		end
		return nil
	end

	------------------------------------------------------------------------------------------------
	-- The prize. A Huge gets the hatch reveal of a Huge; gems get a card of their own, built when first needed.
	------------------------------------------------------------------------------------------------
	local gemsCard = nil
	local gemsToken = 0
	local function showGems(event, rank: number, amount: number)
		if not gemsCard then
			local overlay = UI.make("TextButton", {
				Name = "EventPrize",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.3,
				AutoButtonColor = false,
				Text = "",
				Visible = false,
				ZIndex = 30,
				Parent = UI.gui,
			})
			local box = UI.scaled(UI.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromOffset(640, 300),
				BackgroundTransparency = 1,
				Parent = overlay,
			}))
			gemsCard = {
				overlay = overlay,
				title = UI.text({ Size = UDim2.new(1, 0, 0, 56), Font = UI.TITLE_FONT, Parent = box }),
				place = UI.text({ Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 80), TextColor3 = Colors.gold, Parent = box }),
				prize = UI.text({ Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 70), TextColor3 = Colors.gem, Parent = box }),
				note = UI.text({ Position = UDim2.fromOffset(0, 244), Size = UDim2.new(1, 0, 0, 28), TextColor3 = Colors.text, Text = "Thank you for playing!", Parent = box }),
				shownAt = 0,
			}
			overlay.Activated:Connect(function()
				if os.clock() - gemsCard.shownAt >= GEMS_HOLD then
					gemsToken += 1
					overlay.Visible = false
				end
			end)
		end
		local card = gemsCard
		gemsToken += 1
		local token = gemsToken
		card.title.Text = `{event.icon} {string.upper(event.name)} EVENT`
		card.title.TextColor3 = event.color
		card.place.Text = `{string.upper(Shared.ordinal(rank))} PLACE!`
		card.prize.Text = `+{Shared.commas(amount)} gems`
		card.shownAt = os.clock()
		card.overlay.Visible = true
		task.delay(GEMS_SECONDS, function()
			if token == gemsToken then
				card.overlay.Visible = false
			end
		end)
	end

	local function reveal(reward)
		local event = Shared.ById[reward.event]
		if not event or typeof(reward.rank) ~= "number" then
			return
		end
		local pet = if reward.kind == "pet" then Config.Pets[reward.pet] else nil
		if pet then
			ctx.Effects.hatch(nil, { { pet = reward.pet, kept = true, note = `Your prize for finishing {Shared.ordinal(reward.rank)}` } }, {
				name = `{string.upper(event.name)} EVENT: {string.upper(Shared.ordinal(reward.rank))} PLACE!`,
				color = event.color,
			})
		elseif reward.kind == "gems" and typeof(reward.amount) == "number" then
			showGems(event, reward.rank, reward.amount)
		end
	end

	-- The server marks a prize it has just paid with a new n; it is never saved, so the moment is played once.
	local seen = nil
	local function checkReward()
		local reward = State.feature("event").reward
		if typeof(reward) ~= "table" or reward.n == seen then
			return
		end
		seen = reward.n
		task.delay(REVEAL_DELAY, reveal, reward)
	end
	State.onChange(checkReward)
	checkReward()
end

return { start = start }
