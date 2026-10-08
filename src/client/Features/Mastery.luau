-- Mastery, client side: the MASTERY window, opened by the shrine on the Mars island (its prompt carries
-- Window = "MASTERY"). A tab per group, its cards in a list that scrolls; each track is a card with its level
-- ("Lv 12/40") over a progress bar, what it gives now and at the next level, the price in gems and BUY. Tracks, prices and effects come from the shared module, which
-- is what the server sells from; the server checks everything again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mastery = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Mastery"))

local CARD_HEIGHT = 84
local TAB_TOP = 28
local TAB_HEIGHT = 38
local LIST_TOP = TAB_TOP + TAB_HEIGHT + 8
local BAR_HEIGHT = 9 -- the level bar: one bar whatever the cap, so 50 levels fit as well as 5
local MARK_WIDTH = 3 -- a tick on the bar where the Slots track gives a slot
local TEXT_LEFT = 58 -- where a row's text starts (UI.row's own layout)

local function start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local left = Enum.TextXAlignment.Left
	local world = Config.Worlds[Mastery.ISLAND]

	local window = UI.window(Mastery.WINDOW, 680, 500)
	local headline = UI.text({
		Size = UDim2.new(1, -8, 0, 22),
		TextXAlignment = left,
		TextColor3 = Colors.gold,
		MaxSize = 18,
		Parent = window.body,
	})

	-- The tabs: one button per group, side by side.
	local selected = Mastery.Groups[1].id
	local tabs = {}
	local refresh
	for index, group in Mastery.Groups do
		local share = 1 / #Mastery.Groups
		local tab = UI.button({
			Position = UDim2.new((index - 1) * share, 2, 0, TAB_TOP),
			Size = UDim2.new(share, -6, 0, TAB_HEIGHT),
			Text = group.name,
			BackgroundColor3 = Colors.grey,
			Parent = window.body,
		})
		tab.Activated:Connect(function()
			selected = group.id
			refresh()
		end)
		tabs[group.id] = tab
	end

	local list = UI.scroll(window.body, { Position = UDim2.fromOffset(0, LIST_TOP), Size = UDim2.new(1, 0, 1, -LIST_TOP) })

	-- Each track's picture (UI.icon); a track not listed shows the mastery star.
	local TRACK_ICONS = {
		attack = "power", rate = "speed", range = "ench_reach", boss = "boss", crit = "ench_sharp",
		bond = "minicannon", rapid = "ench_rapid", critpower = "ench_executioner", slots = "slot",
		coins = "coin", luck = "luck", discount = "sale", crates = "chest", gems = "gem",
		lives = "heart", slow = "ench_frostbite", offline = "clock", nightshift = "ench_guardian",
	}
	local groupColor = {}
	for _, group in Mastery.Groups do
		groupColor[group.id] = group.color
	end

	-- The cards: built once, one per track; a tab shows its own.
	local cards = {}
	for order, track in Mastery.Tracks do
		local row = UI.row(list, CARD_HEIGHT, order)
		row.icon.BackgroundColor3 = groupColor[track.group] or Colors.white
		row.setIcon(TRACK_ICONS[track.id] or "mastery")
		row.title.Position = UDim2.fromOffset(TEXT_LEFT, 4)
		row.title.Size = UDim2.new(1, -212, 0, 24)
		row.sub.Position = UDim2.fromOffset(TEXT_LEFT, 44)
		row.sub.Size = UDim2.new(1, -212, 0, CARD_HEIGHT - 50)
		-- The level bar: filled up to the level owned. The Slots track's slot levels are ticks on it.
		local bar = UI.make("Frame", {
			Name = "Levels",
			Position = UDim2.fromOffset(TEXT_LEFT, 31),
			Size = UDim2.new(1, -212, 0, BAR_HEIGHT),
			BackgroundColor3 = Colors.dark,
			BorderSizePixel = 0,
			Parent = row.frame,
		}, { UI.corner(4) })
		local fill = UI.make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Colors.gold,
			BorderSizePixel = 0,
			Visible = false,
			Parent = bar,
		}, { UI.corner(4) })
		for _, at in track.at or {} do
			UI.make("Frame", {
				Name = "SlotMark",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(at / track.cap, 0),
				Size = UDim2.new(0, MARK_WIDTH, 1, 0),
				BackgroundColor3 = Colors.white,
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = bar,
			})
		end
		row.button.Activated:Connect(function()
			ctx.act("masteryBuy", track.id)
		end)
		cards[track.id] = { row = row, fill = fill }
	end

	local function atShrine(): boolean
		return State.get("Place", "plot") == "island" and State.get("Island", 0) == Mastery.ISLAND
	end

	local function setButton(button: TextButton, text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	local shownTab: string? = nil
	function refresh()
		if shownTab ~= selected then
			shownTab = selected
			list.CanvasPosition = Vector2.zero -- a new tab starts at its first card
		end
		local saved = State.feature("mastery")
		local gems = State.get("Diamonds", 0)
		local unlocked = Mastery.unlocked(State.get("BestCleared", 0))
		local here = atShrine()
		local off = if typeof(saved.off) == "table" then saved.off else {}
		if not unlocked then
			headline.Text = `Reach {world.name} to unlock Mastery`
		elseif not here then
			headline.Text = `Buy at the Mastery Shrine on the {world.name} island  •  kept through rebirths`
		else
			headline.Text = `💎 {Format.abbreviate(gems)} gems  •  Mastery is kept through rebirths`
		end
		for _, group in Mastery.Groups do
			tabs[group.id].BackgroundColor3 = if group.id == selected then Colors.blue else Colors.grey
		end
		for _, track in Mastery.Tracks do
			local card = cards[track.id]
			local row = card.row
			row.frame.Visible = track.group == selected
			if not row.frame.Visible then
				continue
			end
			local level = Mastery.level(saved, track.id)
			row.title.Text = `{string.upper(track.name)}   Lv {level}/{track.cap}`
			card.fill.Size = UDim2.fromScale(level / track.cap, 1)
			card.fill.Visible = level > 0
			local now = `Now: {Mastery.describe(track.id, level)}`
			if level >= track.cap then
				row.sub.Text = now .. "\nFully mastered"
				setButton(row.button, "MAX", Colors.gold)
				continue
			end
			local nextLine = `Next: {Mastery.describe(track.id, level + 1)}`
			if track.how == "slots" then
				local at = Mastery.nextSlot(level)
				if at then
					nextLine = `Next slot at level {at}`
				end
			end
			row.sub.Text = `{now}\n{nextLine}`
			local cost = Mastery.cost(track.id, level + 1) or 0
			if off[track.id] then
				setButton(row.button, "COMING\nSOON", Colors.grey)
			elseif not unlocked then
				setButton(row.button, "LOCKED", Colors.grey)
			elseif Mastery.missing(saved, track.id) then
				-- Crit Power before Mini Crit: the server would refuse it, so the card says what to buy first.
				setButton(row.button, `NEEDS\n{string.upper(Mastery.missing(saved, track.id).name)}`, Colors.grey)
			else
				setButton(row.button, `BUY\n{Format.abbreviate(cost)} 💎`, if here and gems >= cost then Colors.green else Colors.grey)
			end
		end
	end

	ctx.Windows.register(Mastery.WINDOW, window, refresh)

	-- Walking off the island (the portal home, the travel button) closes the shrine's window.
	local wasHere = false
	State.onChange(function()
		local here = atShrine()
		if window.frame.Visible and wasHere and not here then
			window.close()
		end
		wasHere = here
	end)
end

return { start = start }
