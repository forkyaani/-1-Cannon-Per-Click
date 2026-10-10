-- The FIRE button, client side: a round button of its own on the base's HUD, between the level panel and the
-- jump button (the corners belong to the thumbs), and F on a keyboard. A press is shown at once (the button
-- squashes, the damage floats up); the presses themselves go to the server together, a few times a second,
-- and the server decides how many count (src/server/Features/Blast.luau). Over the button: its level and how
-- far the next one is. Numbers and balance: src/shared/Features/Blast.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Blast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Blast"))

local SIZE = 116 -- the button, design px
local BAR = 26 -- the level bar over it
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
	local bar = UI.bar({
		parent = slot,
		position = UDim2.fromOffset(0, 0),
		size = UDim2.fromOffset(SIZE, BAR),
		color = Colors.gold,
		textSize = 15,
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
	local sent = 0 -- shots sent since the server last said where the bar stands

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
			sent += pending
			ctx.act("blast", pending)
			pending = 0
		end
	end)

	local shownXp: number? = nil
	local function refresh()
		slot.Visible = State.get("InMarket", false) ~= true
		local now = meta()
		local lv = level()
		local xp = if typeof(now.xp) == "number" then now.xp else 0
		if xp ~= shownXp then
			-- The server has spoken: what was sent is in its number now.
			shownXp, sent = xp, 0
		end
		if lv >= Blast.MAX_LEVEL then
			bar.set(1, `Lv {lv} MAX`)
		else
			bar.set(math.clamp((xp + sent + pending) / Blast.need(lv), 0, 1), `Lv {lv}`)
		end
	end
	State.onChange(refresh)
	Hud.onLayout(refresh)
	refresh()
end

return { start = start }
