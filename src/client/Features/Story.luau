-- Client side of the story: the quest tracker on the HUD, Captain Kaboom's dialogue box and the STORY window.
-- The server owns the progress and publishes it as State.feature("story"): { chapter, quest, have, need,
-- claimed }. Everything here is drawn from that. Dialogue comes from watching the active quest change, so
-- nothing depends on a message that could be missed while the game is still loading.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Story"))

local TRACKER_TOP = 270 / 720 -- a share of the screen height, so it stays clear of the menu on a small phone
local TRACKER_SIZE = Vector2.new(230, 104)
local TRACKER_SMALL = Vector2.new(230, 62) -- in the marketplace, where the left edge is busier: only the quest and its bar
local DIALOGUE_SIZE = Vector2.new(470, 90)
local BAR_BELOW = 90 -- kept free under the dialogue box: the HUD's bottom bar, and the gap above it
local LIST_WIDTH = 206 -- the chapter list in the STORY window
local TAP_GUARD = 0.5 -- seconds a new line ignores taps, so a stray tap does not skip it unread
local MAX_LINES = 6 -- one conversation never runs longer than this

local LEFT = Enum.TextXAlignment.Left

local function start(ctx)
	local State, UI, Format = ctx.State, ctx.UI, ctx.Format
	local Colors = UI.Colors
	local Guide = Story.Guide

	local function round(): UICorner
		return UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) })
	end

	-- A round dot for the speaker's face. front draws it over a dot it overlaps (a pupil over its eye).
	local function dot(size: number, x: number, y: number, color: Color3, front: boolean?): Frame
		return UI.make("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = if front then 2 else 1,
		}, { round() })
	end

	------------------------------------------------------------------------------------------------
	-- Reading the published progress
	------------------------------------------------------------------------------------------------
	-- What the server last published, or nil until it has (the first moments after joining).
	local function progress()
		local story = State.feature("story")
		if typeof(story.chapter) ~= "number" or typeof(story.quest) ~= "number" then
			return nil
		end
		return story
	end

	local function claimed(story, index: number): boolean
		return typeof(story.claimed) == "table" and story.claimed[tostring(index)] == true
	end

	-- The first finished chapter whose reward is still waiting, if there is one.
	local function unclaimed(story): number?
		for index = 1, math.min(story.chapter - 1, #Story.Chapters) do
			if not claimed(story, index) then
				return index
			end
		end
		return nil
	end

	-- The level the server would work a coin reward out for right now.
	local function payWave(chapter): number
		return Story.payWave(chapter, State.get("Wave", 1), State.get("Cleared", 0))
	end

	------------------------------------------------------------------------------------------------
	-- Quest tracker: left edge, under the Roblox chat and above the menu. Plain labels, so a thumb on it
	-- still moves the walking stick.
	------------------------------------------------------------------------------------------------
	local trackerHeader = UI.text({
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 15),
		TextXAlignment = LEFT,
		TextColor3 = Colors.gold,
		MaxSize = 13,
	})
	local trackerTitle = UI.text({
		Size = UDim2.new(1, -16, 0, 34),
		TextXAlignment = LEFT,
		TextWrapped = true,
		MaxSize = 17,
	})
	local trackerFill = UI.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Colors.green,
		BorderSizePixel = 0,
	}, { UI.corner(6) })
	local trackerCount = UI.text({ Size = UDim2.fromScale(1, 1), ZIndex = 2, MaxSize = 13 })
	local trackerBar = UI.make("Frame", {
		Size = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = Colors.dark,
		BorderSizePixel = 0,
	}, { UI.corner(6), UI.stroke(1.5), trackerFill, trackerCount })
	local trackerReward = UI.text({
		Position = UDim2.fromOffset(8, 83),
		Size = UDim2.new(1, -16, 0, 15),
		TextXAlignment = LEFT,
		TextColor3 = Colors.text,
		MaxSize = 13,
	})
	local tracker = UI.panel({
		Name = "StoryTracker",
		Position = UDim2.new(0, 12, TRACKER_TOP, 0),
		Size = UDim2.fromOffset(TRACKER_SIZE.X, TRACKER_SIZE.Y),
		Visible = false,
	}, {
		UI.make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Colors.panel,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
		}, { UI.corner(10), UI.stroke(2), trackerHeader, trackerTitle, trackerBar, trackerReward }),
	})
	-- Under the stat pills on the left, and always clear of the MARKETPLACE button in the corner below.
	ctx.Hud.onLayout(function(layout)
		tracker.Position = UDim2.fromOffset(16 * layout.s, math.min(layout.stack + 402, 508) * layout.s)
	end)
	local trackerShown = "" -- what the tracker last drew, so a state change that does not touch it costs nothing

	local function refreshTracker()
		local story = progress()
		local chapter = story and Story.Chapters[story.chapter]
		local quest = chapter and chapter.quests[story.quest]
		local waiting = story and unclaimed(story)
		-- Nothing to show before the first publish, or once the story is over and every reward is claimed.
		-- The quest tracker is off the HUD (the owner found it in the way); the STORY window shows the quest.
		tracker.Visible = false
		if not tracker.Visible then
			return
		end
		local small = State.get("InMarket", false) == true
		local wave = if chapter then payWave(chapter) else 0
		local signature = `{story.chapter}:{story.quest}:{story.have}:{story.need}:{waiting}:{small}:{wave}`
		if signature == trackerShown then
			return
		end
		trackerShown = signature

		local size = if small then TRACKER_SMALL else TRACKER_SIZE
		tracker.Size = UDim2.fromOffset(size.X, size.Y)
		trackerHeader.Visible = not small
		trackerReward.Visible = not small
		trackerTitle.Position = UDim2.fromOffset(8, if small then 5 else 22)
		trackerBar.Position = UDim2.fromOffset(8, if small then 41 else 62)
		trackerBar.Visible = quest ~= nil
		if quest then
			local have, need = story.have or 0, math.max(1, story.need or 1)
			trackerHeader.Text = string.upper(`Chapter {chapter.index}  •  {chapter.world}`)
			trackerTitle.Text = quest.title
			trackerFill.Size = UDim2.fromScale(math.clamp(have / need, 0, 1), 1)
			trackerCount.Text = `{Format.abbreviate(have)} / {Format.abbreviate(need)}`
			local reward = Story.rewardText(Story.resolve(quest.reward, wave, quest.turn), true)
			trackerReward.Text = if waiting then "🎁 Chapter reward waiting in STORY" else `🎁 {reward}`
		else
			trackerHeader.Text = "STORY COMPLETE"
			trackerTitle.Text = "Claim your chapter reward in STORY"
			trackerReward.Text = ""
		end
	end

	------------------------------------------------------------------------------------------------
	-- The STORY window: chapters on the left, the chosen chapter's quests and its reward on the right.
	-- Rows are built once and only their text changes.
	------------------------------------------------------------------------------------------------
	local window = UI.window("STORY", 640, 460)
	local chapterList = UI.scroll(window.body, { Size = UDim2.new(0, LIST_WIDTH, 1, 0) })
	local pane = UI.make("Frame", {
		Position = UDim2.fromOffset(LIST_WIDTH + 10, 0),
		Size = UDim2.new(1, -(LIST_WIDTH + 10), 1, 0),
		BackgroundTransparency = 1,
		Parent = window.body,
	})
	local paneTitle = UI.text({
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = LEFT,
		TextColor3 = Colors.gold,
		Parent = pane,
	})
	local paneBlurb = UI.text({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = LEFT,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = Colors.text,
		MaxSize = 15,
		Parent = pane,
	})
	local questList = UI.scroll(pane, { Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 1, -132) })
	local rewardLabel = UI.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -150, 0, 50),
		TextXAlignment = LEFT,
		TextWrapped = true,
		MaxSize = 15,
		Parent = pane,
	})
	local claimButton = UI.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(140, 50),
		Parent = pane,
	})

	local chapterButtons = {}
	local questRows = {}
	local mostQuests = 0
	for _, chapter in Story.Chapters do
		mostQuests = math.max(mostQuests, #chapter.quests)
	end
	for index = 1, mostQuests do
		local frame = UI.make("Frame", {
			Size = UDim2.new(1, -10, 0, 44),
			BackgroundColor3 = Colors.row,
			LayoutOrder = index,
			Parent = questList,
		}, { UI.corner(8) })
		questRows[index] = {
			frame = frame,
			mark = UI.text({ Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(28, 28), Parent = frame }),
			title = UI.text({
				Position = UDim2.fromOffset(40, 3),
				Size = UDim2.new(1, -124, 0, 22),
				TextXAlignment = LEFT,
				MaxSize = 17,
				Parent = frame,
			}),
			reward = UI.text({
				Position = UDim2.fromOffset(40, 25),
				Size = UDim2.new(1, -124, 0, 16),
				TextXAlignment = LEFT,
				TextColor3 = Colors.text,
				MaxSize = 13,
				Parent = frame,
			}),
			state = UI.text({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(72, 24),
				TextXAlignment = Enum.TextXAlignment.Right,
				MaxSize = 15,
				Parent = frame,
			}),
		}
	end

	local selected: number? = nil -- the chapter shown on the right; nil lets the window pick when it opens
	local claiming: number? = nil -- the chapter whose CLAIM was last pressed, until the server has paid it
	local windowShown = "" -- what the window last drew

	local function refreshWindow()
		local story = progress()
		if not story then
			return
		end
		-- A reward has just been paid: move on to the next one waiting, so several can be claimed in a row.
		if claiming and claimed(story, claiming) then
			selected = unclaimed(story) or selected
			claiming = nil
		end
		-- Freshly opened: the chapter with a reward to claim, else the one in progress.
		local index = selected or unclaimed(story) or math.min(story.chapter, #Story.Chapters)
		local chapter = Story.Chapters[index]
		if not chapter then
			return
		end
		selected = index
		local wave = payWave(chapter)
		local claims = 0
		for number in Story.Chapters do
			if claimed(story, number) then
				claims += 1
			end
		end
		local signature = `{index}:{story.chapter}:{story.quest}:{story.have}:{story.need}:{claims}:{wave}`
		if signature == windowShown then
			return
		end
		windowShown = signature

		for number, button in chapterButtons do
			local other = Story.Chapters[number]
			local status, color = "🔒 LOCKED", Colors.dark
			if number < story.chapter then
				if claimed(story, number) then
					status, color = "DONE ✓", Colors.grey
				else
					status, color = "🎁 CLAIM REWARD", Colors.gold
				end
			elseif number == story.chapter then
				status, color = `Quest {story.quest} of {#other.quests}`, Colors.blue
			end
			-- The chapter on show is marked with an arrow.
			button.Text = `{if number == index then "▶ " else ""}{number}. {other.world}\n{status}`
			button.BackgroundColor3 = color
		end

		paneTitle.Text = `Chapter {index}: {chapter.title}`
		paneBlurb.Text = chapter.blurb
		for number, row in questRows do
			local quest = chapter.quests[number]
			row.frame.Visible = quest ~= nil
			if quest then
				local done = index < story.chapter or (index == story.chapter and number < story.quest)
				local active = index == story.chapter and number == story.quest
				row.mark.Text = if done then "✓" elseif active then "▶" else "•"
				row.mark.TextColor3 = if done then Colors.green elseif active then Colors.gold else Colors.grey
				row.title.Text = quest.title
				row.title.TextColor3 = if active then Colors.white else Colors.text
				row.state.TextColor3 = if done then Colors.green else Colors.gold
				if done then
					row.reward.Text = "Reward paid"
					row.state.Text = "DONE"
				else
					row.reward.Text = `🎁 {Story.rewardText(Story.resolve(quest.reward, wave, quest.turn))}`
					row.state.Text = if active then `{Format.abbreviate(story.have or 0)}/{Format.abbreviate(quest.n)}` else ""
				end
			end
		end

		local finished = index < story.chapter
		if finished and claimed(story, index) then
			rewardLabel.Text = "Chapter reward claimed. Thank you, Cannoneer!"
			claimButton.Text = "CLAIMED"
			claimButton.BackgroundColor3 = Colors.grey
		else
			rewardLabel.Text = `Chapter reward:\n{Story.rewardText(Story.resolve(chapter.reward, wave, index, index))}`
			claimButton.Text = if finished then "CLAIM" else "🔒 FINISH THE CHAPTER"
			claimButton.BackgroundColor3 = if finished then Colors.green else Colors.grey
		end
	end

	for index in Story.Chapters do
		local button = UI.button({ Size = UDim2.new(1, -10, 0, 48), LayoutOrder = index, Parent = chapterList })
		button.Activated:Connect(function()
			selected = index
			refreshWindow()
		end)
		chapterButtons[index] = button
	end
	-- The server checks that the chapter is finished and not claimed yet.
	claimButton.Activated:Connect(function()
		if selected then
			claiming = selected
			ctx.act("storyClaim", selected)
		end
	end)

	-- Closed: the next time it opens it picks its own chapter again and redraws.
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.frame.Visible then
			selected, claiming, windowShown = nil, nil, ""
		end
	end)

	ctx.Windows.register("STORY", window, refreshWindow)
	ctx.Hud.addMenuButton("STORY", Guide.hat, 13, window.toggle)
	ctx.flag("STORY", function()
		local story = progress()
		return story ~= nil and unclaimed(story) ~= nil
	end)

	------------------------------------------------------------------------------------------------
	-- Dialogue: a small box at the bottom centre with the speaker's face, name and one line.
	-- A tap on the box moves on and so does a few seconds of waiting; nothing else is covered.
	------------------------------------------------------------------------------------------------
	local face = UI.make("Frame", {
		Position = UDim2.fromOffset(16, 28),
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = Guide.body,
		BorderSizePixel = 0,
	}, {
		round(),
		UI.stroke(2),
		dot(15, 10, 14, Colors.white),
		dot(15, 29, 14, Colors.white),
		dot(7, 15, 19, Colors.dark, true),
		dot(7, 34, 19, Colors.dark, true),
	})
	-- The captain's hat and lit fuse, drawn over the top of the face. Hidden when a boss is the one talking.
	local hat = UI.make("Frame", { Size = UDim2.fromOffset(90, 34), BackgroundTransparency = 1, ZIndex = 2 }, {
		UI.make("Frame", {
			Position = UDim2.fromOffset(25, 8),
			Size = UDim2.fromOffset(36, 18),
			BackgroundColor3 = Guide.hat,
			BorderSizePixel = 0,
		}, { UI.corner(4) }),
		UI.make("Frame", {
			Position = UDim2.fromOffset(25, 20),
			Size = UDim2.fromOffset(36, 5),
			BackgroundColor3 = Guide.trim,
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
		UI.make("Frame", {
			Position = UDim2.fromOffset(14, 25),
			Size = UDim2.fromOffset(58, 6),
			BackgroundColor3 = Guide.hat,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, { UI.corner(3) }),
		dot(9, 60, 1, Guide.spark),
	})
	local speakerLabel = UI.text({
		Position = UDim2.fromOffset(88, 7),
		Size = UDim2.new(1, -196, 0, 22),
		TextXAlignment = LEFT,
		TextColor3 = Colors.gold,
	})
	local lineLabel = UI.text({
		Position = UDim2.fromOffset(88, 30),
		Size = UDim2.new(1, -100, 0, 54),
		TextXAlignment = LEFT,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		MaxSize = 19,
	})
	local tapLabel = UI.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 9),
		Size = UDim2.fromOffset(90, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Colors.text,
		MaxSize = 12,
	})
	local box = UI.make("TextButton", {
		Size = UDim2.new(1, 0, 0, DIALOGUE_SIZE.Y),
		BackgroundColor3 = Colors.panel,
		BackgroundTransparency = 0.08,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
	}, {
		UI.corner(12),
		-- On a button a stroke outlines the text unless it is told to take the border.
		UI.make("UIStroke", { Thickness = 3, Color = Guide.trim, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		face,
		hat,
		speakerLabel,
		lineLabel,
		tapLabel,
	})
	-- The panel is anchored to the bottom edge and is taller than the box by BAR_BELOW, so the box sits that
	-- far above the edge at any screen scale. The part below the box is empty and lets taps through.
	-- It heads the notification stack in the top-right corner, which makes room for it (Hud.reserveNotices).
	local dialogue = UI.panel({
		Name = "StoryDialogue",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(DIALOGUE_SIZE.X, DIALOGUE_SIZE.Y),
		ZIndex = 29,
	}, { box })
	ctx.Hud.onLayout(function(layout)
		dialogue.Position = UDim2.new(1, -layout.noteRight * layout.s, 0, layout.noteTop * layout.s)
	end)

	local queue = {} -- the lines still to be said; queue[1] is the one on screen
	local total = 0 -- lines in this conversation, for the "2/3" in the corner
	local shownFor = 0 -- seconds the line on screen has been showing

	local function windowOpen(): boolean
		for _, other in ctx.Windows.byName do
			if other.frame.Visible then
				return true
			end
		end
		return false
	end

	-- Long enough to read, short enough that a box nobody taps clears itself.
	local function holdSeconds(line): number
		local text = if typeof(line) == "table" then line.text else line
		return math.clamp(2.5 + #text * 0.06, 4, 9)
	end

	-- Puts queue[1] in the box. A line is a string (the guide says it) or { who, color, text } (a boss does).
	local function present()
		local line = queue[1]
		box.Visible = line ~= nil and not windowOpen()
		if not line then
			return
		end
		local boss = typeof(line) == "table"
		speakerLabel.Text = string.upper(if boss then line.who else Guide.name)
		speakerLabel.TextColor3 = if boss then Colors.red else Colors.gold
		lineLabel.Text = if boss then line.text else line
		face.BackgroundColor3 = if boss then line.color else Guide.body
		hat.Visible = not boss
		tapLabel.Text = `{total - #queue + 1}/{total}  TAP ▶`
		shownFor = 0
		-- The core's hint line sits where the box is; the guide is the one talking now.
		ctx.Hud.hideHint()
	end

	-- Starts a conversation. Whatever was still waiting from the one before is dropped, so quests that finish
	-- one after another never pile up a backlog of boxes.
	local function say(lines)
		queue = {}
		for index = 1, math.min(#lines, MAX_LINES) do
			queue[index] = lines[index]
		end
		total = #queue
		present()
	end

	local function nextLine()
		table.remove(queue, 1)
		present()
	end

	box.Activated:Connect(function()
		if shownFor >= TAP_GUARD then
			nextLine()
		end
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			local line = queue[1]
			-- Hidden, and its clock stopped, while a window is open: the box must never sit on top of one.
			box.Visible = line ~= nil and not windowOpen()
			ctx.Hud.reserveNotices(if box.Visible then DIALOGUE_SIZE.Y + 10 else 0)
			if box.Visible then
				shownFor += dt
				if shownFor >= holdSeconds(line) then
					nextLine()
				end
			end
		end
	end)

	------------------------------------------------------------------------------------------------
	-- Narration: what the guide says when the active quest changes
	------------------------------------------------------------------------------------------------
	local seen = nil -- the chapter and quest that were last spoken about

	local function narrate(story)
		local chapter = Story.Chapters[story.chapter]
		local quest = chapter and chapter.quests[story.quest]
		local lines = {}
		local function add(more)
			for _, line in more do
				table.insert(lines, line)
			end
		end
		if not seen then
			-- Just joined: a brand-new player gets the opening, anyone else a one-line reminder.
			if quest and story.chapter == 1 and story.quest == 1 then
				add(chapter.intro)
				add(quest.say)
			elseif quest then
				add({ `Welcome back, Cannoneer! Next up: {quest.title}.` })
			end
		else
			local finished = story.chapter - seen.chapter
			if finished == 1 then
				add(Story.Chapters[seen.chapter].outro)
			elseif finished > 1 then
				add({ `You are way ahead of the story! {finished} chapters done at once.` })
			end
			if finished > 0 and chapter then
				add(chapter.intro)
			end
			if quest then
				add(quest.say)
			elseif finished > 0 then
				add({ "That is the whole story so far. New worlds are on the way!" })
			end
		end
		seen = { chapter = story.chapter, quest = story.quest }
		if #lines > 0 then
			say(lines)
		end
	end

	local function onState()
		local story = progress()
		-- The guide waits while the welcome cards are up (Features/Tutorial.luau): his opening lines would
		-- play out unseen behind them.
		local welcoming = State.feature("tutorial").welcomed == false
		if story and not welcoming and (not seen or seen.chapter ~= story.chapter or seen.quest ~= story.quest) then
			narrate(story)
		end
		refreshTracker()
	end
	State.onChange(onState)
	onState()
end

return { start = start }
