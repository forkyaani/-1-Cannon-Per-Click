-- The FIRE button, client side: a round button of its own on the base's HUD, between the level panel and the
-- jump button (the corners belong to the thumbs), and F on a keyboard. A press is shown at once (the button
-- squashes, the damage floats up); the presses themselves go to the server together, a few times a second,
-- and the server decides how many count (src/server/Features/Blast.luau). Over the button: an UPGRADE chip with
-- its level, green while the next level can be paid for; it opens the FIRE window, where a level is bought with
-- coins or with gems. Numbers and balance: src/shared/Features/Blast.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Blast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Blast"))

local SIZE = 116 -- the button, design px
local BAR = 30 -- the UPGRADE chip over it
local RIGHT = 286 -- its right edge from the screen's: left of the jump button on a phone
local BOTTOM = 14

local function start(ctx)
	local State, UI, Hud, Format = ctx.State, ctx.UI, ctx.Hud, ctx.Format
	local Colors = UI.Colors

	local slot = UI.slot({
		Name = "Fire",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -RIGHT, 1, -BOTTOM),
		Size = UDim2.fromOffset(SIZE, SIZE + BAR + 6),
		ZIndex = 3,
	})
	local chip = UI.button({
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(SIZE, BAR),
		Text = "Lv 0",
		TextSize = 16,
		BackgroundColor3 = Colors.grey,
		Parent = slot,
	})
	local button = UI.button({
		Position = UDim2.fromOffset(0, BAR + 6),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Text = "FIRE!",
		TextSize = 30,
		BackgroundColor3 = Colors.red,
		Parent = slot,
	})

	local function meta()
		return State.feature("blast")
	end
	local function level(): number
		local value = meta().level
		return if typeof(value) == "number" then value else 0
	end
	-- Whether a press has something to hit: the server asks the same.
	local function fighting(): boolean
		return State.get("InMarket", false) ~= true
			and State.get("Paused", false) ~= true
			and State.get("Phase", "") == "fight"
			and State.get("MonstersLeft", 0) > 0
	end

	-- The same allowance the server keeps, so what floats up is what will count.
	local allow, allowAt = Blast.BURST, os.clock()
	local pending = 0 -- presses not sent yet

	local function press()
		if not slot.Visible then
			return
		end
		local now = os.clock()
		allow = math.min(Blast.BURST, allow + (now - allowAt) * Blast.RATE)
		allowAt = now
		if allow < 1 or not fighting() then
			return
		end
		allow -= 1
		pending += 1
		local each = State.get("CannonPower", 0) * Blast.share(level())
		local at = button.AbsolutePosition + Vector2.new(button.AbsoluteSize.X / 2, 0)
		Hud.popup(at, `-{Format.abbreviate(math.max(1, each))}`, Colors.gold)
	end
	button.Activated:Connect(press)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			press()
		end
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		if since >= Blast.BATCH_SECONDS and pending > 0 then
			since = 0
			ctx.act("blast", pending)
			pending = 0
		end
	end)

	-- The FIRE window: what a shot is worth now and at the next level, and the two ways to pay for it.
	local window = UI.window(Blast.WINDOW, 520, 318)
	local left = Enum.TextXAlignment.Left
	local headline = UI.text({ Size = UDim2.new(1, -8, 0, 30), TextXAlignment = left, TextColor3 = Colors.gold, MaxSize = 24, Parent = window.body })
	local now = UI.text({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, -8, 0, 24), TextXAlignment = left, MaxSize = 18, Parent = window.body })
	local after = UI.text({ Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, -8, 0, 24), TextXAlignment = left, TextColor3 = Colors.green, MaxSize = 18, Parent = window.body })
	UI.text({
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, -8, 0, 40),
		TextXAlignment = left,
		TextWrapped = true,
		TextColor3 = Colors.text,
		MaxSize = 15,
		Text = `Up to {Blast.RATE} shots a second count. Pay with coins or with gems: either buys the next level.`,
		Parent = window.body,
	})
	local buy = {}
	for index, currency in { "coins", "gems" } do
		local button = UI.button({
			Position = UDim2.new((index - 1) * 0.5, 2, 0, 144),
			Size = UDim2.new(0.5, -6, 0, 96),
			TextSize = 24,
			BackgroundColor3 = Colors.grey,
			Parent = window.body,
		})
		button.Activated:Connect(function()
			ctx.act("blastBuy", currency)
		end)
		buy[currency] = button
	end
	local ICON = { coins = "💰", gems = "💎" }
	local function have(currency: string): number
		return State.get(if currency == "coins" then "Coins" else "Diamonds", 0)
	end

	-- A level just bought: the button swells, the chip flashes and the new share floats up from it.
	local swell = UI.make("UIScale", { Parent = button })
	local function celebrate(lv: number)
		swell.Scale = 1.35
		TweenService:Create(swell, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		UI.sound("clear", 1 + lv * 0.01)
		if slot.Visible then
			local at = button.AbsolutePosition + Vector2.new(button.AbsoluteSize.X / 2, 0)
			Hud.popup(at, `LEVEL {lv}!`, Colors.green)
		end
	end

	local shownLevel: number? = nil
	local function refresh()
		slot.Visible = State.get("InMarket", false) ~= true
		local lv = level()
		if shownLevel and lv > shownLevel then
			celebrate(lv)
		end
		shownLevel = lv
		local maxed = lv >= Blast.MAX_LEVEL
		local affordable = false
		for currency, button in buy do
			local cost = if maxed then nil else Blast.cost(lv + 1, currency)
			local can = cost ~= nil and have(currency) >= cost
			affordable = affordable or can
			button.Text = if cost then `UPGRADE\n{Format.abbreviate(cost)} {ICON[currency]}` else "MAX"
			button.BackgroundColor3 = if maxed then Colors.gold elseif can then Colors.green else Colors.grey
		end
		chip.Text = if maxed then `Lv {lv} MAX` elseif affordable then `Lv {lv}  UPGRADE!` else `Lv {lv}  UPGRADE`
		chip.BackgroundColor3 = if maxed then Colors.gold elseif affordable then Colors.green else Colors.grey
		headline.Text = `FIRE  Lv {lv}/{Blast.MAX_LEVEL}`
		now.Text = `Now: a shot hits for {Blast.shareText(lv)} of your damage per second`
		after.Text = if maxed then "Fully upgraded" else `Next: {Blast.shareText(lv + 1)}`
	end
	chip.Activated:Connect(window.toggle)
	ctx.Windows.register(Blast.WINDOW, window, refresh)
	State.onChange(refresh)
	Hud.onLayout(refresh)
	refresh()
end

return { start = start }
