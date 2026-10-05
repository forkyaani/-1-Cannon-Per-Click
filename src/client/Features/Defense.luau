-- The level HUD of the idle defence game: world and level, lives, monsters left, previous / next / auto, the
-- towers' total damage per second, the pause button, the game speed button (a game pass), short banners
-- (level cleared, level failed, a boss arriving) and the PAUSED banner, which stays while the plot is paused.
-- Everything is read from the player's attributes (docs/DEFENSE_SPEC.md 5) and placed through Hud.onLayout,
-- top centre under the travel button: the corners belong to the thumbs (joystick left, jump right).
-- In the marketplace the cluster shrinks to one line, since the towers keep fighting while the player shops.
local TweenService = game:GetService("TweenService")

local WIDTH = 404 -- the cluster: narrow enough to sit between the thumbs on a phone
local HEIGHT = 140
local LINE = Vector2.new(330, 40) -- the one line shown in the marketplace
local BANNER_SECONDS = 1.8
-- The HUD's slim stat row (src/client/Hud.luau) starts at the left margin: its pills are this far apart, and it
-- ends below the top bar. The cluster keeps out of its way.

local Feature = {}

function Feature.start(ctx)
	local Config, Format, State, UI, Hud = ctx.Config, ctx.Format, ctx.State, ctx.UI, ctx.Hud
	local Colors = UI.Colors
	local defense = Config.Defense or {}

	------------------------------------------------------------------------------------------------
	-- The cluster
	------------------------------------------------------------------------------------------------
	local cluster = UI.slot({ Name = "Defense", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(WIDTH, HEIGHT) })
	local prevButton = UI.button({ Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(60, 72), Text = "<", BackgroundColor3 = Colors.blue, Parent = cluster })
	local nextButton = UI.button({ Position = UDim2.fromOffset(WIDTH - 60, 10), Size = UDim2.fromOffset(60, 72), Text = ">", BackgroundColor3 = Colors.blue, Parent = cluster })
	local panel = UI.make("Frame", {
		Position = UDim2.fromOffset(66, 0),
		Size = UDim2.fromOffset(WIDTH - 132, 92),
		BackgroundTransparency = 1,
		Parent = cluster,
	})
	UI.sticker(panel, UI.Variants.panel, { radius = 24, lip = 6, outline = 4, gloss = false })

	-- The world's name is a button: it opens the WORLDS window.
	local worldTab = UI.make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(190, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
		Parent = panel,
	})
	local worldSticker = UI.sticker(worldTab, UI.shade(Colors.green), { radius = 28, lip = 3, gloss = false })
	local worldLabel = UI.label({ Size = UDim2.new(1, 0, 1, -2), Font = UI.TITLE_FONT, TextSize = 18, Parent = worldSticker.face })
	local levelLabel = UI.label({
		Position = UDim2.fromOffset(8, 34),
		Size = UDim2.new(1, -16, 0, 28),
		Font = UI.TITLE_FONT,
		TextSize = 26,
		Stroke = 3,
		ZIndex = 2,
		Parent = panel,
	})
	local livesBar = UI.bar({
		parent = panel,
		position = UDim2.fromOffset(16, 62),
		size = UDim2.new(1, -32, 0, 20),
		color = Colors.red,
		textSize = 15,
	})
	livesBar.frame.ZIndex = 2

	-- The bottom row, 4 px apart: AUTO, monsters left, damage per second, pause, speed. Every button is 44 high
	-- and at least 48 wide.
	local autoToggle = UI.toggle({ parent = cluster, position = UDim2.fromOffset(0, 96), size = Vector2.new(92, 44), textSize = 18 })
	local function fact(x: number, width: number): TextLabel
		local label = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 18, TextColor3 = Colors.ink, Stroke = 0 })
		UI.chip({ Position = UDim2.fromOffset(x, 98), Size = UDim2.fromOffset(width, 40), Parent = cluster }, { label })
		return label
	end
	local leftLabel = fact(96, 88)
	local dpsLabel = fact(188, 96)
	-- Pause: the plot stands still until it is pressed again. Building and upgrading go on meanwhile.
	local pauseButton = UI.button({ Position = UDim2.fromOffset(288, 96), Size = UDim2.fromOffset(48, 44), Text = "⏸", TextSize = 22, BackgroundColor3 = Colors.blue, Parent = cluster })
	pauseButton.Activated:Connect(function()
		ctx.act("setPaused", State.get("Paused", false) ~= true)
	end)
	-- Game speed: one press steps 1x, 2x, 3x and back. It is the 2x and 3x Speed pass: without it the button
	-- shows a lock, and the server answers a press with the pass's purchase prompt.
	local speedButton = UI.button({ Position = UDim2.fromOffset(340, 96), Size = UDim2.fromOffset(64, 44), Text = "1x", TextSize = 20, Parent = cluster })
	speedButton.Activated:Connect(function()
		ctx.act("setSpeed")
	end)

	-- The marketplace's one line.
	local lineLabel = UI.label({ Size = UDim2.fromScale(1, 1), TextSize = 20, TextColor3 = Colors.ink, Stroke = 0 })
	local line = UI.slot({ Name = "DefenseLine", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(LINE.X, LINE.Y), Visible = false }, {
		UI.chip({ Size = UDim2.fromScale(1, 1) }, { lineLabel }),
	})

	prevButton.Activated:Connect(function()
		ctx.act("prevWave")
	end)
	nextButton.Activated:Connect(function()
		ctx.act("nextWave")
	end)
	autoToggle.button.Activated:Connect(function()
		ctx.act("toggleAuto")
	end)
	worldTab.Activated:Connect(function()
		local worlds = ctx.Windows.byName.WORLDS
		if worlds then
			worlds.toggle()
		end
	end)

	------------------------------------------------------------------------------------------------
	-- Banners: one line that pops in under the toasts and fades. It is not Active, so it never eats a touch.
	------------------------------------------------------------------------------------------------
	local banner = UI.slot({ Name = "DefenseBanner", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(620, 66), Visible = false, ZIndex = 6 })
	local bannerPop = UI.make("UIScale", { Parent = banner })
	local bannerSticker = UI.sticker(banner, UI.Variants.primary, { radius = 33, lip = 6, outline = 4 })
	local bannerLabel = UI.label({
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -32, 1, -2),
		Font = UI.TITLE_FONT,
		TextSize = 30,
		Stroke = 3,
		Parent = bannerSticker.face,
	})
	local bannerToken = 0

	-- Level news goes to the notification stack in the corner, not over the fight.
	local function announce(text: string, look)
		ctx.Hud.toast(text, if look == UI.Variants.danger then "bad" else "good")
	end

	-- PAUSED: stays for as long as the plot is paused, over the level panel (or over the one line away from
	-- the base). It is a button: a press resumes.
	local pausedBanner = UI.slot({ Name = "DefensePaused", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(330, 50), Visible = false, ZIndex = 5 })
	local pausedButton = UI.make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = pausedBanner })
	local pausedSticker = UI.sticker(pausedButton, UI.Variants.gold, { radius = 25, lip = 5, outline = 4 })
	UI.label({
		Size = UDim2.new(1, 0, 1, -2),
		Font = UI.TITLE_FONT,
		Text = "⏸ PAUSED  •  TAP TO RESUME",
		TextSize = 20,
		Stroke = 3,
		Parent = pausedSticker.face,
	})
	pausedButton.Activated:Connect(function()
		ctx.act("setPaused", false)
	end)

	------------------------------------------------------------------------------------------------
	-- Layout
	------------------------------------------------------------------------------------------------
	local lastLayout = nil
	local eventOn = false

	-- Top centre under the travel button. Where that would cover the HUD's stat row, the piece moves right of
	-- the row, or below it when there is no room before the menu column.
	-- Bottom middle: the level panel sits between the thumbs (joystick left, jump right), out of the view's centre.
	local function place(frame: Frame, _width: number, _layout)
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.new(0.5, 0, 1, -14)
	end

	-- The travel button goes to the top right corner (the HUD puts it top centre).
	local function placeTravel(layout)
		local travel = Hud.backButton.Parent
		if travel and travel:IsA("GuiObject") then
			travel.AnchorPoint = Vector2.new(1, 0)
			-- Left of the menu column, which stands against the right edge.
			travel.Position = UDim2.new(1, -170, 0, layout.T + 8)
		end
	end

	local function relayout()
		local layout = lastLayout
		if layout then
			place(cluster, WIDTH, layout)
			place(line, LINE.X, layout)
			placeTravel(layout)
			banner.Position = UDim2.new(0.5, 0, 0, layout.toast + 62)
			-- Just over whichever of the two pieces is showing.
			pausedBanner.Position = UDim2.new(0.5, 0, 1, -14 - (if line.Visible then LINE.Y else HEIGHT) - 8)
		end
	end
	Hud.onLayout(function(layout)
		lastLayout = layout
		relayout()
	end)

	------------------------------------------------------------------------------------------------
	local shownWorld = 0
	local seen: string? = nil -- the level and phase the boss banner was last decided for

	local function refresh()
		local wave = State.get("Wave", 1)
		local worldIndex, level = Config.worldOf(wave)
		local world = Config.Worlds[worldIndex]
		local kind = Config.waveKind(wave)
		local market = State.get("InMarket", false) == true
		local phase = State.get("Phase", "fight")

		local paused = State.get("Paused", false) == true
		local moved = line.Visible ~= market
		cluster.Visible = not market
		line.Visible = market
		pausedBanner.Visible = paused
		pauseButton.Text = if paused then "▶" else "⏸"
		pauseButton.BackgroundColor3 = if paused then Colors.gold else Colors.blue
		local event = State.meta.event ~= nil and State.meta.event.active == true
		if event ~= eventOn or moved then
			eventOn = event
			relayout()
		end

		if worldIndex ~= shownWorld then
			shownWorld = worldIndex
			worldSticker.set(UI.shade(world.floor:Lerp(Colors.white, 0.2)))
		end
		worldLabel.Text = string.upper(world.name)
		local title = if kind == "final"
			then "WORLD BOSS"
			elseif kind == "normal" then `LEVEL {level}/{Config.WavesPerWorld}`
			else `BOSS {level}/{Config.WavesPerWorld}`
		-- The boss line also says the boss's health in numbers, as its bar does: "BOSS 5/50  •  1.2K / 3.4K".
		-- The longer line is shrunk to fit the panel (TextScaled, never past the line's own size).
		local left, max = nil, nil
		if kind ~= "normal" and phase ~= "break" and ctx.Field and ctx.Field.boss then
			left, max = ctx.Field.boss()
		end
		if left and max then
			title ..= `  •  {Format.abbreviate(left)} / {Format.abbreviate(max)}`
		end
		levelLabel.TextScaled = left ~= nil and max ~= nil
		levelLabel.Text = title
		levelLabel.TextColor3 = if kind == "normal" then Colors.white else Color3.fromHex("#FFD0D6")

		local livesMax = State.get("LivesMax", defense.lives or 10)
		local lives = State.get("Lives", livesMax)
		livesBar.set(lives / math.max(1, livesMax), `❤ {lives}/{livesMax}`)

		local monstersLeft = State.get("MonstersLeft", 0)
		leftLabel.Text = if phase == "break" then "⏳ NEXT" else `👾 {monstersLeft} LEFT`
		-- Cannon Power: the towers' total damage per second, the game's headline number.
		dpsLabel.Text = `⚔ {Format.abbreviate(State.get("CannonPower", State.get("Dps", 0)))}/s`
		lineLabel.Text = `{world.name} {level}/{Config.WavesPerWorld}  •  ❤ {lives}/{livesMax}  •  👾 {monstersLeft}{if paused then "  •  ⏸" else ""}`

		prevButton.BackgroundColor3 = if wave > 1 then Colors.blue else Colors.grey
		nextButton.BackgroundColor3 = if wave <= State.get("Cleared", 0) and wave < Config.TotalWaves then Colors.blue else Colors.grey
		local auto = State.get("AutoAdvance", true)
		autoToggle.set(auto, if auto then "AUTO" else "FARM", if auto then UI.Variants.primary else UI.Variants.gold)
		local speed = State.get("GameSpeed", 1)
		if (State.meta.passes or {}).gameSpeed == true then
			speedButton.Text = `⏩ {speed}x`
			speedButton.BackgroundColor3 = if speed > 1 then Colors.gold else Colors.blue
		else
			speedButton.Text = "🔒 2x"
			speedButton.BackgroundColor3 = Colors.premium
		end

		-- A boss level starting gets a warning. Not the one the player joins in the middle of.
		local key = `{wave}:{phase}`
		if key ~= seen then
			if seen and kind ~= "normal" and phase ~= "break" then
				announce(`⚠ {string.upper(Config.monsterFor(wave).name)} IS COMING!`, UI.Variants.danger)
			end
			seen = key
		end
	end
	State.onChange(refresh)
	refresh()
	-- A boss's health comes with the field, five times a second, not with the attributes: on a boss level the
	-- line is written again that often.
	task.spawn(function()
		while true do
			task.wait(0.25)
			if Config.waveKind(State.get("Wave", 1)) ~= "normal" then
				refresh()
			end
		end
	end)

	------------------------------------------------------------------------------------------------
	-- One-off news from the server: Game.send(player, "defense", ...).
	------------------------------------------------------------------------------------------------
	ctx.on("defense", function(what: unknown, a: unknown, b: unknown)
		if what == "cleared" and typeof(a) == "number" then
			local _, level = Config.worldOf(a)
			local coins = if typeof(b) == "number" and b > 0 then `   +★ {Format.abbreviate(b)}` else ""
			announce(`LEVEL {level} CLEARED!{coins}`, UI.Variants.primary)
		elseif what == "failed" and typeof(a) == "number" then
			local _, level = Config.worldOf(a)
			-- A boss that got through still pays for the damage it took.
			local coins = if typeof(b) == "number" and b > 0 then `   +★ {Format.abbreviate(b)}` else ""
			announce(`LEVEL {level} FAILED{coins}`, UI.Variants.danger)
		elseif what == "rebirth" and typeof(a) == "number" then
			announce(`REBIRTH {a}!`, UI.Variants.gold)
		elseif what == "leak" then
			-- A monster got through: the lives bar flashes, and the loss floats off it.
			local frame = livesBar.frame
			livesBar.setColor(Colors.white)
			task.delay(0.15, livesBar.setColor, Colors.red)
			Hud.popup(frame.AbsolutePosition + frame.AbsoluteSize / 2, "-❤", Colors.red)
		end
	end)
end

return Feature
