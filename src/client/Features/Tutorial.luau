-- The first-join experience, client half. Three things are drawn here, all from what the server says
-- (State.feature("tutorial"): welcomed, step, fanPaid, paid, group, member, hint):
--   * the welcome cards: a full-screen card with one page each for the game, the group's fan bonus and a like,
--     and later the "you are on your own" card that ends the walkthrough;
--   * the walkthrough's banner at the top middle: what to do now, one short line more, and what it pays;
--   * the marker: a bouncing arrow and a beam of light over the place to walk to, or an arrow beside the
--     menu button to press.
-- The words, the steps and the rewards are in src/shared/Features/Tutorial.luau. Nothing is decided here:
-- NEXT only turns a page; the last page, CHECK, GOT IT and LET'S GO ask the server.
-- Phone first: the card's buttons are big and in the middle, the banner sits at the very top, and nothing is
-- put in the bottom corners (the thumbs') or on the level panel at the bottom middle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Layout"))
local Tutorial = require(Shared:WaitForChild("Features"):WaitForChild("Tutorial"))

local CARD = Vector2.new(620, 460) -- design px; the card is scaled to fit the screen
local BANNER = Vector2.new(580, 92) -- design px (a 720 px tall screen)
local SIDE = 132 -- the banner's right column: the reward, or the step's button
local PAGE_GUARD = 0.6 -- seconds a new page ignores its buttons: a second tap must not skip a page unread
local RETRY_SECONDS = 1.5 -- a request the server has not answered can be sent again after this long
local SKIP_CONFIRM_SECONDS = 4 -- SKIP has to be pressed twice within this
local LOOK_SECONDS = 0.25 -- how often the things no signal tells of are looked at (a window opening, a part arriving)
local BEAM_HEIGHT = 60 -- studs of light over the place to walk to
local ARROW_HEIGHT = 9 -- studs over the target's top
local BOUNCE = 1.2 -- studs up and down

local Feature = {}

function Feature.start(ctx)
	local Format, State, UI, Hud = ctx.Format, ctx.State, ctx.UI, ctx.Hud
	local Colors = UI.Colors
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local left = Enum.TextXAlignment.Left

	local function coinsText(amount: number): string
		return `★ {Format.abbreviate(amount)}`
	end

	------------------------------------------------------------------------------------------------
	-- What the server says
	------------------------------------------------------------------------------------------------
	local function meta()
		return State.feature("tutorial")
	end

	-- The step the player is on, or nil: before the welcome is over, and after the walkthrough.
	local function currentStep()
		local now = meta()
		if now.welcomed ~= true or typeof(now.step) ~= "string" then
			return nil
		end
		return Tutorial.ById[now.step]
	end

	local function rewardWaiting(step): boolean
		local paid = meta().paid
		return step.reward ~= nil and not (typeof(paid) == "table" and paid[step.id] == true)
	end

	------------------------------------------------------------------------------------------------
	-- The card: one full-screen card whose pages are the three welcome cards and the last step's card
	------------------------------------------------------------------------------------------------
	local cardGui = UI.make("ScreenGui", {
		Name = "TutorialCard",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40, -- over the HUD, its windows and the welcome-back card: the welcome comes first
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = playerGui,
	})
	-- A button, so a tap anywhere is this screen's and never presses what is underneath.
	local backdrop = UI.make("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.ink,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = cardGui,
	})
	local card = UI.make("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		BackgroundTransparency = 1,
		Parent = backdrop,
	})
	local cardScale = UI.make("UIScale", { Parent = card })
	local fit = 1
	local function rescale()
		local view = camera.ViewportSize
		fit = math.clamp(math.min(view.X / (CARD.X + 40), view.Y / (CARD.Y + 80)), 0.3, 1.3)
		cardScale.Scale = fit
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	UI.sticker(card, UI.Variants.panel, { radius = 32, lip = 10, outline = 4, gloss = false })
	local titleTab = UI.make("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -30),
		Size = UDim2.fromOffset(470, 68),
		BackgroundTransparency = 1,
		Rotation = -2,
		ZIndex = 3,
		Parent = card,
	})
	local titleSticker = UI.sticker(titleTab, UI.Variants.title, { radius = 34, lip = 6, outline = 4 })
	local titleLabel = UI.label({
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, -2),
		Font = UI.TITLE_FONT,
		TextSize = 38,
		TextScaled = true,
		Stroke = 3,
		ZIndex = 2,
		Parent = titleSticker.face,
	})
	UI.make("UITextSizeConstraint", { MaxTextSize = 38, MinTextSize = 14, Parent = titleLabel })
	local pageLabel = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 12),
		Size = UDim2.fromOffset(70, 24),
		TextSize = 18,
		TextColor3 = Colors.cream,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = card,
	})

	local BODY_TOP, BODY_HEIGHT = 52, 240 -- the part of the card a page fills
	local function newPage(name: string): Frame
		return UI.make("Frame", {
			Name = name,
			Position = UDim2.fromOffset(34, BODY_TOP),
			Size = UDim2.new(1, -68, 0, BODY_HEIGHT),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 2,
			Parent = card,
		})
	end
	local function line(parent: Instance, y: number, height: number, size: number, text: string, color: Color3?): TextLabel
		return UI.label({
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height),
			Text = text,
			TextSize = size,
			TextColor3 = color or Colors.white,
			TextWrapped = true,
			ZIndex = 2,
			Parent = parent,
		})
	end

	-- A page of plain lines: the first one big, the rest under it, sharing the page's height.
	local function linesPage(def): Frame
		local page = newPage(def.id)
		local each = BODY_HEIGHT / #def.lines
		for index, text in def.lines do
			line(page, (index - 1) * each, each, if index == 1 then 30 else 23, text, if index == 1 then Colors.white else Colors.cream)
		end
		return page
	end

	local cards = {} -- [card id] = its definition (shared)
	for _, def in Tutorial.Cards do
		cards[def.id] = def
	end
	local pages = {}
	pages.welcome = linesPage(cards.welcome)
	pages.like = linesPage(cards.like)

	-- The group: what the bonus is, on a cream note, and under it what the server says about this player.
	pages.group = newPage("group")
	line(pages.group, 4, 40, 25, cards.group.lines[1])
	do
		local rows = {}
		for index, text in cards.group.bonus do
			table.insert(rows, UI.label({
				Position = UDim2.fromOffset(8, 8 + (index - 1) * 42),
				Size = UDim2.new(1, -16, 0, 40),
				Text = text,
				TextSize = 32,
				TextColor3 = Colors.ink,
				Stroke = 0,
				ZIndex = 2,
			}))
		end
		UI.chip({ Position = UDim2.fromOffset(40, 52), Size = UDim2.new(1, -80, 0, 100), ZIndex = 2, Parent = pages.group }, rows)
	end
	local groupStatus = line(pages.group, 160, 80, 20, "", Colors.cream)

	-- The last step: where things are from here on.
	pages.finish = newPage("finish")
	for index, row in Tutorial.Finish.lines do
		local y = 8 + (index - 1) * 64
		UI.label({
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(170, 56),
			Text = `{row.icon} {row.name}`,
			TextSize = 28,
			TextColor3 = Colors.gold,
			TextXAlignment = left,
			ZIndex = 2,
			Parent = pages.finish,
		})
		UI.label({
			Position = UDim2.fromOffset(176, y),
			Size = UDim2.new(1, -176, 0, 56),
			Text = row.text,
			TextSize = 20,
			TextColor3 = Colors.cream,
			TextXAlignment = left,
			TextWrapped = true,
			ZIndex = 2,
			Parent = pages.finish,
		})
	end
	local finishReward = line(pages.finish, 202, 34, 22, "", Colors.power)

	-- The buttons under the page: one big one in the middle, or CHECK beside NEXT on the group's page.
	local BUTTON_Y = BODY_TOP + BODY_HEIGHT + 10
	local mainButton = UI.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BUTTON_Y),
		Size = UDim2.fromOffset(320, 84),
		Text = "NEXT",
		BackgroundColor3 = Colors.green,
		ZIndex = 2,
		Parent = card,
	})
	local checkButton = UI.button({
		Position = UDim2.fromOffset(40, BUTTON_Y),
		Size = UDim2.fromOffset(250, 84),
		Text = "CHECK",
		BackgroundColor3 = Colors.blue,
		Visible = false,
		ZIndex = 2,
		Parent = card,
	})
	-- A link, not a button: small and plain, so nobody presses it for NEXT.
	local skipLink = UI.make("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BUTTON_Y + 94),
		Size = UDim2.fromOffset(380, 40),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = UI.FONT,
		Text = "",
		TextSize = 20,
		TextColor3 = Colors.cream,
		Visible = false,
		ZIndex = 2,
		Parent = card,
	}, { UI.stroke(2) })

	local WELCOME_PAGES = { "welcome", "group", "like" }
	local page = 1 -- which welcome page is up
	local shownPage: string? = nil -- the page on screen
	local pageAt = 0 -- os.clock() when it came up
	local cardUp = false
	local asked = { welcome = 0, check = 0, finish = 0 } -- os.clock() of a request the server has not answered
	local skipArmed = -math.huge -- os.clock() of the first of the two presses that skip

	local function waiting(what: string): boolean
		return asked[what] > 0 and os.clock() - asked[what] < RETRY_SECONDS
	end

	-- The line under the bonus, by what the server knows about this player and the group.
	local function groupText(): string
		local def, now = cards.group, meta()
		if now.fanPaid == true then
			return def.paid
		elseif now.group ~= true then
			return def.soon
		elseif now.checking == true or waiting("check") then
			return "Checking..."
		elseif now.member == "no" then
			return def.no
		elseif now.member == "failed" then
			return def.failed
		end
		return def.ask
	end

	-- Which page should be up right now: a welcome page, the last step's card, or none.
	local function wantedPage(): string?
		local now = meta()
		if now.welcomed == false then
			return WELCOME_PAGES[page]
		end
		local step = currentStep()
		return if step and step.card then "finish" else nil
	end

	local function refreshCard()
		local name = wantedPage()
		if not name then
			cardUp, shownPage = false, nil
			cardGui.Enabled = false
			page = 1
			asked.welcome, asked.finish = 0, 0
			return
		end
		if name ~= shownPage then
			shownPage = name
			pageAt = os.clock()
			skipArmed = -math.huge
			for id, frame in pages do
				frame.Visible = id == name
			end
			-- Each page pops in, so a page turn is seen.
			cardScale.Scale = fit * 0.85
			TweenService:Create(cardScale, UI.Motion.pop, { Scale = fit }):Play()
		end
		if not cardUp then
			cardUp = true
			cardGui.Enabled = true
			UI.closeWindows()
		end

		local now = meta()
		if name == "finish" then
			titleLabel.Text = Tutorial.Finish.title
			pageLabel.Text = ""
			local step = Tutorial.ById.finish
			local text = if rewardWaiting(step) then Tutorial.rewardText(step.reward) else ""
			finishReward.Text = if text ~= "" then `Tutorial complete: {text}` else "Tutorial complete!"
			mainButton.Text = if waiting("finish") then "..." else step.button
			mainButton.BackgroundColor3 = if waiting("finish") then Colors.grey else Colors.green
			mainButton.Position = UDim2.new(0.5, 0, 0, BUTTON_Y)
			mainButton.Size = UDim2.fromOffset(320, 84)
			checkButton.Visible = false
			skipLink.Visible = false
			return
		end

		local def = cards[name]
		titleLabel.Text = def.title
		pageLabel.Text = `{page}/{#WELCOME_PAGES}`
		local last = page == #WELCOME_PAGES
		local busy = last and waiting("welcome")
		mainButton.Text = if busy then "..." else def.next
		mainButton.BackgroundColor3 = if busy then Colors.grey else Colors.green
		-- CHECK only where there is something to check: a group, and a bonus that is not paid yet.
		local checkable = name == "group" and now.group == true and now.fanPaid ~= true
		checkButton.Visible = checkable
		if checkable then
			local checking = now.checking == true or waiting("check")
			checkButton.Text = if checking then "..." else def.check
			checkButton.BackgroundColor3 = if checking then Colors.grey else Colors.blue
			mainButton.Position = UDim2.new(0.5, 135, 0, BUTTON_Y)
			mainButton.Size = UDim2.fromOffset(250, 84)
		else
			mainButton.Position = UDim2.new(0.5, 0, 0, BUTTON_Y)
			mainButton.Size = UDim2.fromOffset(320, 84)
		end
		if name == "group" then
			groupStatus.Text = groupText()
			groupStatus.TextColor3 = if now.fanPaid == true then Colors.power else Colors.cream
		end
		skipLink.Visible = def.skip ~= nil
		if def.skip then
			skipLink.Text = if os.clock() - skipArmed <= SKIP_CONFIRM_SECONDS then def.skipSure else def.skip
		end
	end

	-- Sends a request once, and again only if the server has not answered after a while.
	local function ask(what: string, action: string, argument: any?)
		if waiting(what) then
			return
		end
		asked[what] = os.clock()
		ctx.act(action, argument)
		refreshCard()
		task.delay(RETRY_SECONDS + 0.1, refreshCard)
	end

	mainButton.Activated:Connect(function()
		if not cardUp or os.clock() - pageAt < PAGE_GUARD then
			return
		end
		if shownPage == "finish" then
			ask("finish", "tutorialAck", "finish")
		elseif page < #WELCOME_PAGES then
			page += 1
			refreshCard()
		else
			ask("welcome", "tutorialWelcome", "start")
		end
	end)
	checkButton.Activated:Connect(function()
		if cardUp and shownPage == "group" then
			ask("check", "tutorialCheck")
		end
	end)
	skipLink.Activated:Connect(function()
		if not cardUp or shownPage ~= "like" or os.clock() - pageAt < PAGE_GUARD then
			return
		end
		if os.clock() - skipArmed <= SKIP_CONFIRM_SECONDS then
			ask("welcome", "tutorialWelcome", "skip")
			return
		end
		skipArmed = os.clock()
		refreshCard()
		-- The question goes away by itself.
		task.delay(SKIP_CONFIRM_SECONDS + 0.1, refreshCard)
	end)

	------------------------------------------------------------------------------------------------
	-- The banner: top middle, in a gui of its own so it stays readable over an open window (the TOWER window
	-- is open for two of the steps). It is not Active: a touch on it goes through, unless it lands on GOT IT.
	------------------------------------------------------------------------------------------------
	local guideGui = UI.make("ScreenGui", {
		Name = "TutorialGuide",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5, -- over the HUD and its windows, under the cards
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local banner = UI.make("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(BANNER.X, BANNER.Y),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = guideGui,
	})
	local bannerScale = UI.make("UIScale", { Parent = banner })
	UI.sticker(banner, UI.Variants.panel, { radius = 24, lip = 6, outline = 4, gloss = false })
	local countLabel = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 20, TextColor3 = Colors.ink, Stroke = 0 })
	UI.chip({ Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(64, 36), ZIndex = 2, Parent = banner }, { countLabel })
	local titleLine = UI.text({
		Position = UDim2.fromOffset(86, 6),
		Size = UDim2.new(1, -86 - SIDE - 12, 0, 44),
		TextXAlignment = left,
		TextWrapped = true,
		MaxSize = 26,
		ZIndex = 2,
		Parent = banner,
	})
	local detailLine = UI.text({
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -16 - SIDE - 12, 0, 32),
		TextXAlignment = left,
		TextWrapped = true,
		TextColor3 = Colors.cream,
		MaxSize = 18,
		ZIndex = 2,
		Parent = banner,
	})
	local rewardLabel = UI.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(SIDE, 66),
		TextWrapped = true,
		TextColor3 = Colors.power,
		MaxSize = 20,
		ZIndex = 2,
		Parent = banner,
	})
	local ackButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(SIDE + 4, 72), -- as tall as the banner allows: it is pressed with a thumb
		Text = "GOT IT",
		BackgroundColor3 = Colors.green,
		Visible = false,
		ZIndex = 3,
		Parent = banner,
	})
	local ackAt = 0
	ackButton.Activated:Connect(function()
		local step = currentStep()
		if step and step.ack and not step.card and os.clock() - ackAt >= RETRY_SECONDS then
			ackAt = os.clock()
			ctx.act("tutorialAck", step.id)
		end
	end)

	-- Where the banner goes, in design px. The currency pills run along the top left (STAT_ROW wide, under
	-- Roblox's top bar), so the banner takes the first of these that is free:
	--   the top bar's own height, when it is tall enough (a phone) and Roblox's buttons leave the middle clear;
	--   beside the pills, on a very wide screen;
	--   under the pills.
	-- While a window is open the pills are dimmed behind it, and the banner goes to the very top, above the window.
	local STAT_ROW = Vector2.new(776, 60)
	local lastLayout = nil
	local placedOpen: boolean? = nil
	local function placeBanner(open: boolean)
		local layout = lastLayout
		if not layout then
			return
		end
		placedOpen = open
		local y = layout.T + 8 + STAT_ROW.Y + 6
		if open or (layout.top <= 8 and layout.top + BANNER.Y <= layout.T + 4) then
			y = layout.top
		elseif layout.W / 2 - BANNER.X / 2 >= STAT_ROW.X + 8 then
			y = layout.T + 8
		end
		bannerScale.Scale = layout.s
		banner.Position = UDim2.new(0.5, 0, 0, y * layout.s)
	end
	Hud.onLayout(function(layout)
		lastLayout = layout
		placeBanner(placedOpen == true)
	end)

	-- An arrow beside a menu button: "press this".
	local pointer = UI.make("TextLabel", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Font = UI.TITLE_FONT,
		Text = "➜",
		TextScaled = true,
		TextColor3 = Colors.power,
		Visible = false,
		ZIndex = 5,
		Parent = guideGui,
	}, { UI.stroke(3) })

	------------------------------------------------------------------------------------------------
	-- The marker in the world: a beam of light and a bouncing arrow over the place to walk to. Built from a
	-- part and a BillboardGui, on this client only.
	------------------------------------------------------------------------------------------------
	local beam = UI.make("Part", {
		Name = "TutorialBeam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(BEAM_HEIGHT, 1.4, 1.4),
		Material = Enum.Material.Neon,
		Color = Colors.power,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	})
	-- What the arrow hangs over: a point, so the arrow never depends on another feature's parts staying put.
	local anchor = UI.make("Part", {
		Name = "TutorialTarget",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	})
	local arrowLabel = UI.make("TextLabel", {
		Size = UDim2.fromScale(1, 0.7),
		BackgroundTransparency = 1,
		Font = UI.TITLE_FONT,
		Text = "▼",
		TextScaled = true,
		TextColor3 = Colors.power,
		TextStrokeColor3 = Colors.ink,
		TextStrokeTransparency = 0,
	})
	local distanceLabel = UI.make("TextLabel", {
		Position = UDim2.fromScale(0, 0.7),
		Size = UDim2.fromScale(1, 0.3),
		BackgroundTransparency = 1,
		Font = UI.FONT,
		Text = "",
		TextScaled = true,
		TextColor3 = Colors.white,
		TextStrokeColor3 = Colors.ink,
		TextStrokeTransparency = 0,
	})
	local arrow = UI.make("BillboardGui", {
		Name = "TutorialArrow",
		Size = UDim2.fromOffset(90, 110), -- in pixels: the same size from across the plot as from beside it
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Adornee = anchor,
		Parent = playerGui,
	}, { arrowLabel, distanceLabel })

	------------------------------------------------------------------------------------------------
	-- Where a step points
	------------------------------------------------------------------------------------------------
	local function plotFolder(): Instance?
		local slot = State.get("Slot", nil)
		local plots = workspace:FindFirstChild("Plots")
		return if slot and plots then plots:FindFirstChild("Plot_" .. slot) else nil
	end

	-- A pad's place: the part the server built when it has arrived, else where the layout says it is.
	local function padSpot(pad: number): Vector3?
		local plot = plotFolder()
		local pads = plot and plot:FindFirstChild("Pads")
		local part = pads and pads:FindFirstChild("Pad_" .. pad)
		if part and part:IsA("BasePart") then
			return part.Position
		end
		local slot = State.get("Slot", nil)
		if typeof(slot) == "number" and Layout.PADS[pad] then
			return Layout.padPosition(slot, pad)
		end
		return nil
	end

	local function owned(): { number }
		local pads = State.meta.pads
		return if typeof(pads) == "table" then pads else {}
	end

	local function hasTower(pad: number): boolean
		local towers = State.meta.towers
		return typeof(towers) == "table" and towers[tostring(pad)] ~= nil
	end

	-- The first pad of the player's own with a tower on it (or without one).
	local function ownedPad(withTower: boolean): number?
		local best: number? = nil
		for _, pad in owned() do
			if typeof(pad) == "number" and hasTower(pad) == withTower and (not best or pad < best) then
				best = pad
			end
		end
		return best
	end

	-- The pad for sale that is the shortest walk from the starter cannon.
	local function padForSale(): number?
		local mine = owned()
		local from = Layout.PADS[ownedPad(true) or 1] or Layout.PADS[1]
		local best: number?, bestDistance = nil, math.huge
		for pad, spot in Layout.PADS do
			if not table.find(mine, pad) then
				local distance = (spot - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = pad, distance
				end
			end
		end
		return best
	end

	local function eggSpot(): Vector3?
		local market = workspace:FindFirstChild("Marketplace")
		local eggs = market and market:FindFirstChild("Eggs")
		local stand = eggs and eggs:FindFirstChild("Egg_" .. tostring(Tutorial.Egg.id))
		if not stand then
			return nil
		end
		local shell = stand:FindFirstChild("Egg")
		if shell and shell:IsA("BasePart") then
			return shell.Position
		elseif stand:IsA("Model") then
			return stand:GetPivot().Position
		elseif stand:IsA("BasePart") then
			return stand.Position
		end
		return nil
	end

	local function gateSpot(): Vector3?
		local plot = plotFolder()
		local gate = plot and plot:FindFirstChild("Gate")
		return if gate and gate:IsA("BasePart") then gate.Position else nil
	end

	local function windowOpen(name: string): boolean
		local window = ctx.Windows.byName[name]
		return window ~= nil and window.frame.Visible
	end

	local function anyWindowOpen(): boolean
		for _, window in ctx.Windows.byName do
			if window.frame.Visible then
				return true
			end
		end
		return false
	end

	-- What the step asks for right now: the second line, the place to walk to, the menu button to press.
	-- Every step that happens on the plot sends a player who has wandered off back home first.
	local ON_PLOT = { pad = true, open = true, upgrade = true, pad2 = true, build = true, lives = true }
	local function guide(step): (string, Vector3?, string?)
		local place = State.get("Place", "plot")
		local coins = State.get("Coins", 0)
		local id = step.id
		if ON_PLOT[id] and place ~= "plot" then
			return "Press BASE on the right to go back to your base.", nil, "BASE"
		end
		-- A step that costs coins says so when they are short: they are never far off, the cannon earns them.
		local short = if step.buys and coins < step.buys then `Need {coinsText(step.buys - coins)} more. Your cannon is earning them!` else nil
		if id == "pad" or id == "open" then
			local pad = ownedPad(true)
			return step.detail, if pad then padSpot(pad) else nil, nil
		elseif id == "upgrade" then
			local pad = ownedPad(true)
			if windowOpen("TOWER") then
				return short or step.detail, nil, nil
			end
			return short or "Open your cannon again and press UPGRADE.", if pad then padSpot(pad) else nil, nil
		elseif id == "clear" then
			if State.get("Paused", false) == true then
				return "Your base is paused. Press the pause button again to carry on.", nil, nil
			elseif State.get("Phase", "fight") == "break" then
				return "Here comes the next level...", nil, nil
			end
			return `It shoots all by itself. 👾 {State.get("MonstersLeft", 0)} left.`, nil, nil
		elseif id == "pad2" then
			local pad = padForSale()
			return short or step.detail, if pad then padSpot(pad) else nil, nil
		elseif id == "build" then
			local pad = ownedPad(false)
			return short or step.detail, if pad then padSpot(pad) else nil, nil
		elseif id == "lives" then
			return step.detail, gateSpot(), nil
		elseif id == "island" then
			if windowOpen("WORLDS") then
				return "Now press 🏝️ ISLAND in the first row.", nil, nil
			end
			return step.detail, nil, "WORLDS"
		elseif id == "hatch" then
			if place == "island" and State.get("Island", 0) == Tutorial.Island then
				return short or step.detail, eggSpot(), nil
			elseif windowOpen("WORLDS") then
				return "Press 🏝️ ISLAND in the first row: the egg is there.", nil, nil
			end
			return "The egg is on the island: open WORLDS and press ISLAND.", nil, "WORLDS"
		elseif id == "home" then
			return step.detail, nil, "BASE"
		end
		return step.detail, nil, nil
	end

	------------------------------------------------------------------------------------------------
	local target: Vector3? = nil -- where the marker stands
	local pointAt: string? = nil -- the menu button the arrow stands beside
	local openAskedAt = 0

	local function refreshGuide()
		local step = currentStep()
		if not step or step.card or cardUp then
			banner.Visible = false
			target, pointAt = nil, nil
			return
		end
		local now = meta()
		local detail, spot, button = guide(step)
		local color = Colors.cream
		-- The server's word on a level that just failed comes before the step's own line.
		if typeof(now.hint) == "string" and typeof(now.hintAt) == "number" then
			local seconds = if typeof(now.hintSeconds) == "number" then now.hintSeconds else 14
			if State.now() - now.hintAt < seconds then
				detail, color = now.hint, Color3.fromHex("#FFD0D6")
			end
		end
		local open = anyWindowOpen()
		if open ~= placedOpen then
			placeBanner(open)
		end
		banner.Visible = true
		countLabel.Text = `{Tutorial.Index[step.id]}/{#Tutorial.Steps}`
		titleLine.Text = step.title
		detailLine.Text = detail
		detailLine.TextColor3 = color
		local reward = if rewardWaiting(step) then Tutorial.rewardText(step.reward) else ""
		ackButton.Visible = step.ack == true
		ackButton.Text = step.button or "GOT IT"
		rewardLabel.Visible = not ackButton.Visible and reward ~= ""
		rewardLabel.Text = `🎁 {reward}`
		target, pointAt = spot, button

		-- The one thing only this side sees: the TOWER window is open. The server checks where the player stands.
		if step.id == "open" and windowOpen("TOWER") and os.clock() - openAskedAt >= RETRY_SECONDS then
			openAskedAt = os.clock()
			ctx.act("tutorialAck", "open")
		end
	end

	local function refresh()
		refreshCard()
		refreshGuide()
	end

	-- Whether a HUD button can be seen: it and everything it sits in (a button in the closed MORE drawer cannot).
	local function onScreen(gui: Instance): boolean
		local at: Instance? = gui
		while at and at:IsA("GuiObject") do
			if not at.Visible then
				return false
			end
			at = at.Parent
		end
		return at ~= nil
	end

	-- Puts the marker and the arrow where the step points, and lets them bounce.
	local function animate()
		local bounce = math.sin(os.clock() * 5)
		local spot = target
		if spot and not anyWindowOpen() then
			anchor.Position = spot
			-- A cylinder lies along its X axis: turned, it stands.
			beam.CFrame = CFrame.new(spot + Vector3.new(0, BEAM_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			beam.Transparency = 0.55
			arrow.StudsOffsetWorldSpace = Vector3.new(0, ARROW_HEIGHT + bounce * BOUNCE, 0)
			arrow.Enabled = true
			local character = player.Character
			local root = character and character.PrimaryPart
			distanceLabel.Text = if root then `{math.floor((root.Position - spot).Magnitude + 0.5)} studs` else ""
		else
			beam.Transparency = 1
			arrow.Enabled = false
		end

		local button = if pointAt then Hud.menu[pointAt] else nil
		if button and banner.Visible and onScreen(button) and not anyWindowOpen() then
			local position, size = button.AbsolutePosition, button.AbsoluteSize
			pointer.Size = UDim2.fromOffset(size.Y * 0.7, size.Y * 0.7)
			pointer.Position = UDim2.fromOffset(position.X - 6 + bounce * 8, position.Y + size.Y / 2)
			pointer.Visible = true
		else
			pointer.Visible = false
		end
	end

	State.onChange(function()
		refresh()
		animate()
	end)
	refresh()
	animate()
	-- Every frame for the bounce; a few times a second for what no signal tells of (a window opening, a
	-- request that went unanswered, the level-failed line running out).
	local sinceLook = 0
	RunService.RenderStepped:Connect(function(dt: number)
		sinceLook += dt
		if sinceLook >= LOOK_SECONDS then
			sinceLook = 0
			refresh()
		end
		animate()
	end)

	-- For tests.
	Feature.cardGui, Feature.banner, Feature.pages = cardGui, banner, pages
	Feature.mainButton, Feature.checkButton, Feature.skipLink, Feature.ackButton = mainButton, checkButton, skipLink, ackButton
	Feature.arrow, Feature.beam, Feature.pointer = arrow, beam, pointer
	function Feature.pointing(): (Vector3?, string?)
		return target, pointAt
	end
end

return Feature
