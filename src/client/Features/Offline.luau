-- Offline earnings, client half: the welcome-back card. A full-screen card that says how long the player was
-- away, which level their towers farmed, the coins that earned and when earnings stop, with one CLAIM button.
-- Everything on it is the server's (State.feature("offline"), worked out when the player joined); CLAIM asks
-- the server to pay (`offlineClaim`) and the card goes when the server says nothing is waiting any more.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Offline = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Offline"))

local CARD = Vector2.new(600, 430) -- design px; the card is scaled to fit the screen
local RETRY_SECONDS = 1.5 -- CLAIM can be pressed again after this long without an answer

local Feature = {}

function Feature.start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local camera = workspace.CurrentCamera

	local gui = UI.make("ScreenGui", {
		Name = "WelcomeBack",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30, -- over the HUD and its windows
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
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
		Parent = gui,
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
	local banner = UI.make("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -30),
		Size = UDim2.fromOffset(440, 68),
		BackgroundTransparency = 1,
		Rotation = -2,
		ZIndex = 3,
		Parent = card,
	})
	local bannerSticker = UI.sticker(banner, UI.Variants.title, { radius = 34, lip = 6, outline = 4 })
	UI.label({
		Size = UDim2.new(1, 0, 1, -2),
		Font = UI.TITLE_FONT,
		Text = "WELCOME BACK!",
		TextSize = 40,
		Stroke = 3,
		ZIndex = 2,
		Parent = bannerSticker.face,
	})
	UI.label({
		Position = UDim2.fromOffset(30, 52),
		Size = UDim2.new(1, -60, 0, 28),
		Text = "Your towers kept fighting while you were away",
		TextSize = 22,
		ZIndex = 2,
		Parent = card,
	})

	-- Two facts side by side: the time away and the level that was farmed.
	local function fact(x: number, title: string): TextLabel
		local value = UI.label({
			Position = UDim2.fromOffset(8, 26),
			Size = UDim2.new(1, -16, 0, 34),
			TextSize = 26,
			TextColor3 = Colors.ink,
			Stroke = 0,
			TextScaled = true,
		})
		UI.make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10, Parent = value })
		UI.chip({ Position = UDim2.fromOffset(x, 92), Size = UDim2.fromOffset(262, 68), ZIndex = 2, Parent = card }, {
			UI.label({
				Position = UDim2.fromOffset(8, 4),
				Size = UDim2.new(1, -16, 0, 22),
				Text = title,
				TextSize = 16,
				TextColor3 = Colors.row,
				Stroke = 0,
			}),
			value,
		})
		return value
	end
	local awayLabel = fact(30, "TIME AWAY")
	local levelLabel = fact(308, "LEVEL FARMED")

	local coinsLabel = UI.label({
		Position = UDim2.fromOffset(30, 172),
		Size = UDim2.new(1, -60, 0, 70),
		Font = UI.TITLE_FONT,
		TextSize = 60,
		TextColor3 = Colors.power,
		Stroke = 4,
		TextScaled = true,
		ZIndex = 2,
		Parent = card,
	})
	UI.make("UITextSizeConstraint", { MaxTextSize = 60, MinTextSize = 16, Parent = coinsLabel })
	local capLabel = UI.label({
		Position = UDim2.fromOffset(30, 246),
		Size = UDim2.new(1, -60, 0, 44),
		TextSize = 18,
		TextColor3 = Colors.cream,
		TextWrapped = true,
		ZIndex = 2,
		Parent = card,
	})
	local claimButton = UI.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 304),
		Size = UDim2.fromOffset(300, 84),
		Text = "CLAIM",
		BackgroundColor3 = Colors.green,
		ZIndex = 2,
		Parent = card,
	})

	local shown = false
	local asked = 0 -- os.clock() of the CLAIM press the server has not answered yet

	local function refresh()
		local pending = State.feature("offline")
		local coins = if typeof(pending.coins) == "number" then pending.coins else 0
		if coins <= 0 then
			shown = false
			asked = 0
			gui.Enabled = false
			return
		end
		local away = if typeof(pending.away) == "number" then pending.away else 0
		local level = if typeof(pending.level) == "number" then pending.level else 1
		local capHours = if typeof(pending.capHours) == "number" then pending.capHours else Config.Offline.capHours
		local share = if typeof(pending.share) == "number" then pending.share else Config.Offline.share
		awayLabel.Text = Format.duration(away)
		levelLabel.Text = Config.waveLabel(math.max(1, level))
		coinsLabel.Text = `+★ {Format.abbreviate(coins)} COINS`
		capLabel.Text = `Away earns {math.floor(share * 100 + 0.5)}% of what your towers make.\nEarnings stop after {Offline.hoursText(capHours)} away.`
		local waiting = asked > 0 and os.clock() - asked < RETRY_SECONDS
		claimButton.Text = if waiting then "..." else "CLAIM"
		claimButton.BackgroundColor3 = if waiting then Colors.grey else Colors.green
		if not shown then
			shown = true
			gui.Enabled = true
			cardScale.Scale = fit * 0.8
			TweenService:Create(cardScale, UI.Motion.pop, { Scale = fit }):Play()
		end
	end

	claimButton.Activated:Connect(function()
		if asked > 0 and os.clock() - asked < RETRY_SECONDS then
			return
		end
		asked = os.clock()
		ctx.act("offlineClaim")
		refresh()
		-- No answer (the request was dropped): the button comes back.
		task.delay(RETRY_SECONDS + 0.1, refresh)
	end)

	State.onChange(refresh)
	refresh()

	Feature.gui, Feature.claimButton = gui, claimButton -- for tests
end

return Feature
