-- The crate opening: a full-screen moment in a ScreenGui of its own, above the HUD.
--   1. the crate drops in and lands with a bounce
--   2. it shakes harder and harder while a glow builds in the colour of the rarest reward, then bursts:
--      a flash, the lid flies off, a spray of particles
--   3. the rewards come out as cards. One crate gives one big card; several deal theirs into a grid, most
--      common first, and the rarest lies face down for a moment before it turns over
--   4. the totals, with OPEN AGAIN and CLOSE. It closes itself after a few seconds
-- A tap anywhere skips to the totals, and a second tap closes them. A Secret (or anything rarer than
-- JACKPOT_BELOW) shakes the screen, tints it, and cannot be tapped away for a moment.
-- The server sends what came out on the "crates" channel, however the crate was opened: the CRATES window, USE
-- in the backpack, or the free daily crate. The message is described at the top of
-- src/server/Features/Crates.luau. The cannon keeps firing underneath: only the player's own taps are taken.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Crates"))

-- Sound asset ids, as numbers. 0 is silent: none has been picked yet, so put an id from the Creator Store
-- (Toolbox > Audio) behind each name to give the opening its sound.
local SOUNDS = {
	-- From Roblox's own library, picked by name and length, not by ear (see UI.Sounds in src/client/UI.luau).
	drop = 15674975792, -- Roblox_UI_Whoosh_03: the crate lands
	shake = 12221976, -- clickfast.wav: it starts to shake
	burst = 15675055424, -- Roblox_UI_Cute_Pop: the lid flies off
	card = 15675032796, -- Roblox_UI_Small_Click: a reward card is dealt
	rare = 15675043410, -- Roblox_UI_Tonal_Stinger: the last, rarest card of a batch turns over
	jackpot = 16480570986, -- Roblox_Pinball_Bumper_Low_Bells_02: that card is a Secret or a jackpot
}
local SOUND_VOLUME = 0.6

-- Everything is laid out on a canvas of this size and scaled to fit the screen, narrow phones included.
local CANVAS = Vector2.new(900, 720)
local STAGE_Y = 318 -- where the crate lands and the cards are centred, from the top of the canvas
local CRATE_SIZE = Vector2.new(190, 180)
local MAX_CARDS = 10 -- more rewards than this (USE pressed many times in a row) show their rarest
local MAX_QUEUE = 5 -- openings of another crate that wait their turn while one is on screen
local COLUMNS = 5
local CARD_GAP = 14
local LONE_CARD = Vector2.new(300, 330)
local ROW_CARD = Vector2.new(164, 200) -- up to COLUMNS cards
local GRID_CARD = Vector2.new(152, 180) -- two rows

-- Timing: about 2.5 seconds to the totals for one crate, under 5 for a full batch.
local DROP_SECONDS = 0.45
local SHAKE_SECONDS = 1
local QUICK_SHAKE_SECONDS = 0.35 -- when more crates arrive while one is still opening
local BURST_SECONDS = 0.15
local POP_SECONDS = 0.25 -- a card flying to its place
local DEAL_GAP = 0.2 -- between two cards
local DEAL_SECONDS = 1.8 -- however many cards there are, all but the last are out within this
local BUILD_UP_SECONDS = 0.6 -- the last card of a batch, face down
local READ_SECONDS = 0.35 -- between the last card and the totals
local PARTICLES = 26
local DIM = 0.35 -- the backdrop's transparency

local STAY_SECONDS = 5 -- how long the totals stay up: one crate, a batch, a jackpot
local BATCH_STAY_SECONDS = 7
local JACKPOT_STAY_SECONDS = 9
local HOLD_SECONDS = 0.4 -- a tap cannot close the totals sooner: the tap that skipped is often a double tap
local JACKPOT_HOLD_SECONDS = 2.5
local QUAKE_SECONDS = 0.9

local ODDS_BELOW = 0.1 -- per cent: a reward rarer than 1 in 1,000 says how rare it was
local JACKPOT_BELOW = 0.02 -- per cent: rarer than 1 in 5,000 is a jackpot, whatever it is
-- The glow and a card's outline take the colour of the reward's rarity. Candy, coins and gems have none:
-- they take one from how likely the row was.
local CHANCE_TIERS = { { 10, "Common" }, { 3, "Uncommon" }, { 1, "Rare" }, { 0.1, "Epic" }, { 0, "Legendary" } }
local BALANCE_ATTRIBUTE = { coins = "Coins", diamonds = "Diamonds", candy = "Candy" }

local Opening = {}

function Opening.start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local camera = workspace.CurrentCamera
	local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
	local CENTER = Vector2.new(0.5, 0.5)
	local HOME = UDim2.new(0.5, 0, 0, STAGE_Y)
	local LID_HOME = UDim2.fromScale(0.5, 0.13)

	------------------------------------------------------------------------------------------------
	-- The screen, built once and reused for every opening
	------------------------------------------------------------------------------------------------
	local gui = UI.make("ScreenGui", {
		Name = "CrateOpening",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20, -- the HUD is at 0
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- A button, so a tap anywhere is this screen's and never presses what is underneath.
	local backdrop = UI.make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = DIM,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = gui,
	})
	local root = UI.make("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y),
		BackgroundTransparency = 1,
		Parent = backdrop,
	})
	local rootScale = UI.make("UIScale", { Parent = root })
	local function rescale()
		local view = camera.ViewportSize
		rootScale.Scale = math.clamp(math.min(view.X / CANVAS.X, view.Y / CANVAS.Y), 0.3, 1.3)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	local flash = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 40,
		Parent = backdrop,
	})

	local title = UI.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(820, 46),
		ZIndex = 12,
		Parent = root,
	})

	-- The glow: a soft disc with a brighter middle, and slowly turning rays behind the rewards.
	local glowCore = UI.make("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55, 0.55),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	local glow = UI.make("Frame", {
		AnchorPoint = CENTER,
		Position = HOME,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = root,
	}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), glowCore })
	local rays = UI.make("Frame", {
		AnchorPoint = CENTER,
		Position = HOME,
		Size = UDim2.fromOffset(780, 780),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = root,
	})
	local rayBars = {}
	for index = 1, 6 do
		rayBars[index] = UI.make("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 18),
			Rotation = (index - 1) * 30,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			Parent = rays,
		})
	end
	-- They never stop turning: a tween that repeats for ever costs nothing while the screen is off.
	TweenService:Create(rays, TweenInfo.new(16, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()

	local function setGlow(color: Color3, position: UDim2, size: number, transparency: number)
		glow.BackgroundColor3 = color
		glow.Position = position
		glow.Size = UDim2.fromOffset(size, size)
		glow.BackgroundTransparency = transparency
		glowCore.BackgroundColor3 = color:Lerp(WHITE, 0.5)
		glowCore.BackgroundTransparency = math.min(1, transparency + 0.1)
	end

	-- The crate, drawn from frames in its own colours: a body with two bands, and a lid that comes off.
	-- Everything inside is sized by scale, so the whole crate can be squashed and shrunk as one.
	local crateFrame = UI.make("Frame", {
		AnchorPoint = CENTER,
		Position = HOME,
		Size = UDim2.fromOffset(CRATE_SIZE.X, CRATE_SIZE.Y),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = root,
	})
	local crateBody = UI.make("Frame", {
		Position = UDim2.fromScale(0, 0.22),
		Size = UDim2.fromScale(1, 0.78),
		BorderSizePixel = 0,
		Parent = crateFrame,
	}, { UI.corner(12), UI.stroke(4) })
	local crateBands = {}
	for index, y in { 0.12, 0.7 } do
		crateBands[index] = UI.make("Frame", {
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, 0.16),
			BorderSizePixel = 0,
			Parent = crateBody,
		})
	end
	UI.text({ Position = UDim2.fromScale(0.25, 0.3), Size = UDim2.fromScale(0.5, 0.4), Text = "?", ZIndex = 2, Parent = crateBody })
	local crateLid = UI.make("Frame", {
		AnchorPoint = CENTER,
		Position = LID_HOME,
		Size = UDim2.fromScale(1.08, 0.26),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = crateFrame,
	}, { UI.corner(12), UI.stroke(4) })

	-- The cards: a coloured disc, the reward's name, how much of it, its rarity and, for a rare one, its odds.
	-- cover is the back of a card that is still face down.
	local cards = {}
	for index = 1, MAX_CARDS do
		local stroke = UI.make("UIStroke", { Thickness = 4 })
		local scale = UI.make("UIScale", {})
		local frame = UI.make("Frame", {
			AnchorPoint = CENTER,
			BackgroundColor3 = Colors.panel,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 10,
			Parent = root,
		}, { UI.corner(14), stroke, scale })
		local icon = UI.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.07),
			Size = UDim2.fromScale(0.34, 0.34),
			SizeConstraint = Enum.SizeConstraint.RelativeYY, -- as wide as it is tall: a disc
			BorderSizePixel = 0,
			Parent = frame,
		}, { UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(3) })
		local coverMark = UI.text({ Position = UDim2.fromScale(0.25, 0.25), Size = UDim2.fromScale(0.5, 0.5), Text = "?" })
		cards[index] = {
			frame = frame,
			stroke = stroke,
			scale = scale,
			icon = icon,
			iconText = UI.text({ Position = UDim2.fromScale(0.16, 0.16), Size = UDim2.fromScale(0.68, 0.68), Parent = icon }),
			name = UI.text({ Position = UDim2.fromScale(0.06, 0.45), Size = UDim2.fromScale(0.88, 0.2), TextWrapped = true, Parent = frame }),
			detail = UI.text({
				Position = UDim2.fromScale(0.06, 0.66),
				Size = UDim2.fromScale(0.88, 0.11),
				TextColor3 = Colors.gold,
				Parent = frame,
			}),
			rarity = UI.text({ Position = UDim2.fromScale(0.06, 0.78), Size = UDim2.fromScale(0.88, 0.09), Parent = frame }),
			odds = UI.text({ Position = UDim2.fromScale(0.06, 0.88), Size = UDim2.fromScale(0.88, 0.09), Parent = frame }),
			cover = UI.make("Frame", {
				Size = UDim2.fromScale(1, 1),
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 5,
				Parent = frame,
			}, { UI.corner(14), coverMark }),
		}
	end

	local summary = UI.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 522),
		Size = UDim2.fromOffset(850, 58),
		TextWrapped = true,
		MaxSize = 24,
		Visible = false,
		ZIndex = 12,
		Parent = root,
	})
	local againButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -8, 0, 592),
		Size = UDim2.fromOffset(236, 58),
		BackgroundColor3 = Colors.green,
		Visible = false,
		ZIndex = 13,
		Parent = root,
	})
	local closeButton = UI.button({
		Size = UDim2.fromOffset(236, 58),
		Text = "CLOSE",
		BackgroundColor3 = Colors.red,
		Visible = false,
		ZIndex = 13,
		Parent = root,
	})
	local hint = UI.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 664),
		Size = UDim2.fromOffset(600, 22),
		TextColor3 = Colors.text,
		MaxSize = 16,
		Text = "Tap anywhere to skip",
		ZIndex = 12,
		Parent = root,
	})

	local sounds = {}
	for name, id in SOUNDS do
		if id ~= 0 then
			sounds[name] = UI.make("Sound", {
				Name = "Crate_" .. name,
				SoundId = `rbxassetid://{id}`,
				Volume = SOUND_VOLUME,
				Parent = SoundService,
			})
		end
	end
	local function sound(name: string)
		if sounds[name] then
			SoundService:PlayLocalSound(sounds[name])
		end
	end

	------------------------------------------------------------------------------------------------
	-- What is being shown
	------------------------------------------------------------------------------------------------
	local playToken = 0 -- goes up with every opening and every close: an opening that was replaced stops
	local stage = "idle" -- idle, intro (the crate), deal (the cards) or summary (the totals)
	local skip = false -- the player tapped: go straight to the totals
	local holdUntil = 0 -- the os.clock() until which a tap cannot close the totals
	local closeAt = 0 -- the os.clock() at which the totals close themselves
	local waiting = false -- OPEN AGAIN was pressed and the server has not answered yet
	-- { crate, rewards, count, cards }: the crate on screen, every reward it shows, how many crates the last
	-- press opened (what OPEN AGAIN repeats) and the cards those rewards were made into.
	local session = nil
	local tweens = {} -- the opening's tweens that may still be running
	-- Messages for a different crate that arrived while one was still opening. Each is played when the totals
	-- before it close, so no crate's rewards go unseen.
	local queue = {}
	local begin -- starts the opening of a message; defined with the message handler below

	local function tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
		local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
		local made = TweenService:Create(instance, info, goal)
		table.insert(tweens, made)
		made:Play()
	end

	local function stopTweens()
		for _, made in tweens do
			made:Cancel()
		end
		table.clear(tweens)
	end

	-- Waits `seconds`, or less when the player skips. False when another opening has taken over meanwhile.
	local function pause(token: number, seconds: number): boolean
		local ends = os.clock() + seconds
		while token == playToken and not skip and os.clock() < ends do
			RunService.RenderStepped:Wait()
		end
		return token == playToken
	end

	local function tierOf(chance: number): string
		for _, tier in CHANCE_TIERS do
			if chance >= tier[1] then
				return tier[2]
			end
		end
		return "Legendary"
	end

	-- The rewards as cards, most common first so the rarest is dealt last.
	local function prepare(rewards)
		local list = {}
		for order, reward in rewards do
			local view = Shared.view(reward)
			table.insert(list, {
				order = order,
				reward = reward,
				view = view,
				color = Config.RarityColors[view.rarity or tierOf(reward.chance)] or WHITE,
				secret = view.secret == true,
				jackpot = view.secret == true or reward.chance < JACKPOT_BELOW,
			})
		end
		table.sort(list, function(a, b): boolean
			if a.reward.chance ~= b.reward.chance then
				return a.reward.chance > b.reward.chance
			end
			return a.order < b.order
		end)
		while #list > MAX_CARDS do
			table.remove(list, 1)
		end
		return list
	end

	-- Where card `index` of `count` goes, and how big it is. The cards in use are centred as a group.
	local function slot(index: number, count: number): (UDim2, Vector2)
		local size = if count == 1 then LONE_CARD elseif count <= COLUMNS then ROW_CARD else GRID_CARD
		local rows = math.ceil(count / COLUMNS)
		local row = (index - 1) // COLUMNS
		local inRow = if row == rows - 1 then count - row * COLUMNS else COLUMNS
		local x = ((index - 1) % COLUMNS - (inRow - 1) / 2) * (size.X + CARD_GAP)
		local y = (row - (rows - 1) / 2) * (size.Y + CARD_GAP)
		return UDim2.new(0.5, x, 0, STAGE_Y + y), size
	end

	local function write(card, entry, size: Vector2)
		local view, reward = entry.view, entry.reward
		card.frame.Size = UDim2.fromOffset(size.X, size.Y)
		card.frame.Rotation = 0
		card.stroke.Color = entry.color
		card.stroke.Thickness = 4
		card.icon.BackgroundColor3 = view.color
		card.iconText.Text = view.icon or ""
		card.name.Text = view.name
		card.name.TextColor3 = if view.rarity then entry.color else WHITE
		card.detail.Text = if reward.kept == false then "storage full: released" else view.detail
		card.rarity.Text = if view.rarity then string.upper(view.rarity) else ""
		card.rarity.TextColor3 = entry.color
		card.odds.Text = if entry.secret or reward.chance < ODDS_BELOW then Config.oneIn(reward.chance) else ""
		card.odds.TextColor3 = entry.color
	end

	-- "+1.20M coins  •  2x Power x2  •  Mini Cauldron Cannon": everything the crates held, added up.
	local function totalsText(rewards): string
		local sums = { coins = 0, gems = 0, candy = 0 }
		local names, counts = {}, {}
		for _, reward in rewards do
			if sums[reward.kind] then
				sums[reward.kind] += reward.amount
			else
				local name = Shared.view(reward).name
				if not counts[name] then
					counts[name] = 0
					table.insert(names, name)
				end
				counts[name] += reward.amount
			end
		end
		local parts = {}
		for _, kind in { "coins", "gems", "candy" } do
			if sums[kind] > 0 then
				table.insert(parts, `+{Format.abbreviate(sums[kind])} {kind}`)
			end
		end
		for _, name in names do
			table.insert(parts, if counts[name] > 1 then `{name} x{counts[name]}` else name)
		end
		return table.concat(parts, "  •  ")
	end

	-- What OPEN AGAIN would do right now: { action, count, text }, or nil when there is nothing to open.
	-- A crate the player holds is opened again; one that is opened as it is bought is bought again.
	local function again(crate, count: number)
		if crate.daily then
			return nil
		end
		if crate.instant then
			local price = crate.price
			local each = Shared.price(crate, State.get("Cleared", 0))
			local attribute = price and BALANCE_ATTRIBUTE[price.currency]
			if not each or not attribute then
				return nil
			end
			local meta = State.feature("crates")
			local today = Config.dayNumber(State.now())
			local bought = if meta.buyDay == today and typeof(meta.bought) == "table" then meta.bought[crate.id] or 0 else 0
			local amount = math.min(count, Shared.MaxPerPress, (price.perDay or math.huge) - bought)
			if amount < 1 or State.get(attribute, 0) < each * amount then
				return nil
			end
			local cost = `{Format.abbreviate(each * amount)} {Shared.Currency[price.currency].icon}`
			return { action = "buyCrates", count = amount, text = `OPEN {amount} MORE\n{cost}` }
		end
		local held = State.feature("items")[crate.id] or 0
		local amount = math.min(count, Shared.MaxPerPress, held)
		if amount < 1 then
			return nil
		end
		return { action = "openCrates", count = amount, text = `OPEN {amount} MORE\n{held} left` }
	end

	local function showButtons()
		local offer = if session and not waiting then again(session.crate, session.count) else nil
		if offer then
			againButton.Text = offer.text
			againButton.BackgroundColor3 = Colors.green
		end
		againButton.Visible = offer ~= nil or waiting
		closeButton.Visible = true
		-- CLOSE sits beside OPEN AGAIN, or in the middle on its own.
		closeButton.AnchorPoint = Vector2.new(if againButton.Visible then 0 else 0.5, 0)
		closeButton.Position = UDim2.new(0.5, if againButton.Visible then 8 else 0, 0, 592)
	end

	local function close()
		playToken += 1
		stopTweens()
		stage = "idle"
		session = nil
		waiting = false
		gui.Enabled = false
		local nextMessage = table.remove(queue, 1)
		if nextMessage then
			task.defer(begin, nextMessage)
		end
	end

	------------------------------------------------------------------------------------------------
	-- The opening itself
	------------------------------------------------------------------------------------------------
	-- The flash, the lid and the particles. They look after themselves, so a skip or a new opening can leave
	-- them to finish.
	local function burst(crate, color: Color3)
		sound("burst")
		flash.BackgroundTransparency = 0.15
		tween(flash, 0.35, { BackgroundTransparency = 1 })

		-- The lid that flies off is a copy on the canvas: the crate it sat on is about to shrink away.
		local lid = crateLid:Clone()
		crateLid.Visible = false
		lid.Position = HOME + UDim2.fromOffset(0, (LID_HOME.Y.Scale - 0.5) * CRATE_SIZE.Y)
		lid.Size = UDim2.fromOffset(crateLid.Size.X.Scale * CRATE_SIZE.X, crateLid.Size.Y.Scale * CRATE_SIZE.Y)
		lid.ZIndex = 7
		lid.Parent = root
		local fly = TweenService:Create(lid, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = lid.Position + UDim2.fromOffset(210, -330),
			Rotation = 75,
			BackgroundTransparency = 1,
		})
		local lidStroke = lid:FindFirstChildOfClass("UIStroke")
		if lidStroke then
			TweenService:Create(lidStroke, TweenInfo.new(0.55), { Transparency = 1 }):Play()
		end
		fly.Completed:Connect(function()
			lid:Destroy()
		end)
		fly:Play()

		local palette = { crate.color, color, WHITE }
		for index = 1, PARTICLES do
			local size = math.random(8, 18)
			local angle = math.random() * math.pi * 2
			local reach = math.random(140, 430)
			local piece = UI.make("Frame", {
				AnchorPoint = CENTER,
				Position = HOME,
				Size = UDim2.fromOffset(size, size),
				Rotation = math.random(0, 90),
				BackgroundColor3 = palette[index % #palette + 1],
				BorderSizePixel = 0,
				ZIndex = 7,
				Parent = root,
			}, { UI.corner(3) })
			local spray = TweenService:Create(piece, TweenInfo.new(0.5 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = HOME + UDim2.fromOffset(math.cos(angle) * reach, math.sin(angle) * reach * 0.8 - 40),
				Rotation = math.random(-260, 260),
				Size = UDim2.fromOffset(size * 0.4, size * 0.4),
				BackgroundTransparency = 1,
			})
			spray.Completed:Connect(function()
				piece:Destroy()
			end)
			spray:Play()
		end

		tween(crateFrame, BURST_SECONDS, { Size = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end

	-- Plays session. quick leaves out the drop and shortens the shake: more of the same crate arrived while
	-- it was still opening (USE pressed again), and the cards are dealt again with the new ones among them.
	local function perform(quick: boolean, token: number)
		local opened = session
		if not opened then
			return
		end
		local crate, shown = opened.crate, opened.cards
		local count = #shown
		local best = shown[count] -- the rarest: its colour is the glow's
		local total = #opened.rewards

		stopTweens()
		skip = false
		waiting = false
		stage = "intro"
		root.Position = UDim2.fromScale(0.5, 0.5)
		backdrop.BackgroundColor3 = BLACK
		flash.BackgroundTransparency = 1
		for _, card in cards do
			card.frame.Visible = false
		end
		summary.Visible = false
		againButton.Visible = false
		closeButton.Visible = false
		hint.Visible = true
		rays.Visible = false
		title.Text = string.upper(if total == 1 then crate.name else `{total} {crate.name}s`)
		title.TextColor3 = crate.color
		crateBody.BackgroundColor3 = crate.color
		crateLid.BackgroundColor3 = crate.color:Lerp(WHITE, 0.2)
		for _, band in crateBands do
			band.BackgroundColor3 = crate.color:Lerp(BLACK, 0.55)
		end
		for _, bar in rayBars do
			bar.BackgroundColor3 = best.color
		end
		crateLid.Visible = true
		crateFrame.Size = UDim2.fromOffset(CRATE_SIZE.X, CRATE_SIZE.Y)
		crateFrame.Rotation = 0
		crateFrame.Visible = true
		setGlow(best.color, HOME, 200, 1)
		gui.Enabled = true

		-- 1. The drop.
		if quick then
			crateFrame.Position = HOME
		else
			crateFrame.Position = UDim2.new(0.5, 0, 0, -CRATE_SIZE.Y)
			tween(crateFrame, DROP_SECONDS, { Position = HOME }, Enum.EasingStyle.Bounce)
			sound("drop")
			if not pause(token, DROP_SECONDS) then
				return
			end
		end

		-- 2. The shake, harder and harder, while the glow builds.
		if not skip then
			sound("shake")
		end
		local shakeSeconds = if quick then QUICK_SHAKE_SECONDS else SHAKE_SECONDS
		local started = os.clock()
		while not skip do
			local clock = os.clock()
			local progress = (clock - started) / shakeSeconds
			if progress >= 1 then
				break
			end
			local power = progress * progress
			crateFrame.Rotation = math.sin(clock * 50) * (2 + 12 * power)
			crateFrame.Position = HOME + UDim2.fromOffset(math.sin(clock * 67) * 9 * power, 0)
			setGlow(best.color, HOME, 200 + 300 * progress, 1 - 0.6 * progress)
			RunService.RenderStepped:Wait()
			if token ~= playToken then
				return
			end
		end

		-- 3. The burst.
		if not skip then
			crateFrame.Rotation = 0
			crateFrame.Position = HOME
			burst(crate, best.color)
			if not pause(token, BURST_SECONDS) then
				return
			end
		end
		crateFrame.Visible = false
		rays.Position = HOME
		rays.Visible = true
		setGlow(best.color, HOME, 520, 0.72)

		-- 4. The cards.
		stage = "deal"
		local gap = if count > 1 then math.min(DEAL_GAP, DEAL_SECONDS / (count - 1)) else POP_SECONDS
		for index, entry in shown do
			if skip then
				break
			end
			local card = cards[index]
			local position, size = slot(index, count)
			write(card, entry, size)
			card.cover.Visible = false
			if index == count and count > 1 then
				-- The rarest of a batch: face down in its place, trembling, with the glow behind it.
				card.cover.BackgroundColor3 = crate.color
				card.cover.Visible = true
				card.frame.Position = position
				card.scale.Scale = 1
				card.frame.Visible = true
				rays.Position = position
				local began = os.clock()
				while not skip do
					local clock = os.clock()
					local progress = (clock - began) / BUILD_UP_SECONDS
					if progress >= 1 then
						break
					end
					card.frame.Rotation = math.sin(clock * 45) * 5 * progress
					card.stroke.Thickness = 4 + 5 * progress
					setGlow(entry.color, position, size.Y * (1.2 + progress), 0.9 - 0.4 * progress)
					RunService.RenderStepped:Wait()
					if token ~= playToken then
						return
					end
				end
				if not skip then
					card.cover.Visible = false
					card.frame.Rotation = 0
					card.scale.Scale = 1.3
					tween(card.scale, POP_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back)
					flash.BackgroundTransparency = 0.6
					tween(flash, 0.3, { BackgroundTransparency = 1 })
					sound(if entry.jackpot then "jackpot" else "rare")
					if not pause(token, POP_SECONDS) then
						return
					end
				end
			else
				-- Out of where the crate burst, to its place.
				card.frame.Position = HOME
				card.scale.Scale = 0.2
				card.frame.Visible = true
				tween(card.frame, POP_SECONDS, { Position = position })
				tween(card.scale, POP_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back)
				sound(if count == 1 and entry.jackpot then "jackpot" else "card")
				if not pause(token, gap) then
					return
				end
			end
		end

		-- A beat to read the last card before the totals join it.
		if not pause(token, READ_SECONDS) then
			return
		end

		-- 5. The totals. Everything is put where it ends up, so a skip lands on the same screen.
		stopTweens()
		local bestPosition, bestSize = slot(count, count)
		for index, entry in shown do
			local card = cards[index]
			local position, size = slot(index, count)
			write(card, entry, size)
			card.frame.Position = position
			card.scale.Scale = 1
			card.cover.Visible = false
			card.frame.Visible = true
		end
		crateFrame.Visible = false
		flash.BackgroundTransparency = 1
		rays.Position = bestPosition
		rays.Visible = true
		setGlow(best.color, bestPosition, bestSize.Y * 2, 0.6)
		hint.Visible = false
		summary.Text = totalsText(opened.rewards)
		summary.Visible = true
		if best.jackpot then
			title.Text = if best.secret then "SECRET!" else "JACKPOT!"
			title.TextColor3 = best.color
		end
		local now = os.clock()
		holdUntil = now + (if best.jackpot then JACKPOT_HOLD_SECONDS else HOLD_SECONDS)
		closeAt = now + (if best.jackpot then JACKPOT_STAY_SECONDS elseif count > 1 then BATCH_STAY_SECONDS else STAY_SECONDS)
		stage = "summary"
		showButtons()

		-- A jackpot shakes the screen, beats in its colour, and a Secret runs through the rainbow.
		local bestCard = cards[count]
		local quakeUntil = now + QUAKE_SECONDS
		while token == playToken and os.clock() < closeAt do
			if best.jackpot then
				local clock = os.clock()
				local beat = (math.sin(clock * 8) + 1) / 2
				backdrop.BackgroundColor3 = best.color:Lerp(BLACK, 0.8 - 0.2 * beat)
				bestCard.stroke.Thickness = 4 + 5 * beat
				if best.secret then
					local hue = Color3.fromHSV(clock * 0.6 % 1, 0.75, 1)
					bestCard.stroke.Color = hue
					bestCard.name.TextColor3 = hue
					title.TextColor3 = hue
				end
				if clock < quakeUntil then
					local power = (quakeUntil - clock) / QUAKE_SECONDS * 18
					root.Position = UDim2.new(0.5, (math.random() - 0.5) * 2 * power, 0.5, (math.random() - 0.5) * 2 * power)
				else
					root.Position = UDim2.fromScale(0.5, 0.5)
				end
			end
			RunService.RenderStepped:Wait()
		end
		if token == playToken then
			close()
		end
	end

	-- The backdrop takes every tap while it is up, so an opening that breaks must never leave it there: the
	-- screen is closed instead, and the player is only out an animation.
	local function play(quick: boolean)
		playToken += 1
		local token = playToken
		local ok, err = pcall(perform, quick, token)
		if not ok then
			warn(`[Crates] the opening animation failed and was closed: {err}`)
			if token == playToken then
				close()
			end
		end
	end

	------------------------------------------------------------------------------------------------
	-- Input and messages
	------------------------------------------------------------------------------------------------
	backdrop.Activated:Connect(function()
		if stage == "summary" then
			if os.clock() >= holdUntil then
				close()
			end
		elseif stage ~= "idle" then
			skip = true
		end
	end)
	closeButton.Activated:Connect(close)
	againButton.Activated:Connect(function()
		if stage ~= "summary" or not session or waiting then
			return
		end
		local offer = again(session.crate, session.count)
		if not offer then
			showButtons()
			return
		end
		-- The answer is a new "crates" message, which starts the next opening. Should the server refuse, the
		-- totals close themselves a little later.
		waiting = true
		againButton.Text = "OPENING..."
		againButton.BackgroundColor3 = Colors.grey
		closeAt = math.max(closeAt, os.clock() + 3)
		ctx.act(offer.action, { id = session.crate.id, count = offer.count })
	end)
	-- What OPEN AGAIN offers follows the player's crates and coins, which arrive a moment after the rewards.
	State.onChange(function()
		if stage == "summary" then
			showButtons()
		end
	end)

	-- Nothing in a message is trusted to be there: a reward this client cannot draw must not break the screen.
	local function valid(result: any): boolean
		if typeof(result) ~= "table" or typeof(result.crate) ~= "string" or typeof(result.rewards) ~= "table" then
			return false
		end
		for _, reward in result.rewards do
			if typeof(reward) ~= "table" or typeof(reward.kind) ~= "string" then
				return false
			elseif typeof(reward.amount) ~= "number" or typeof(reward.chance) ~= "number" or reward.chance <= 0 then
				return false
			end
		end
		return Shared.ById[result.crate] ~= nil and #result.rewards > 0
	end

	begin = function(message)
		local crate = Shared.ById[message.crate]
		local rewards = message.rewards
		local current = session
		local busy = current ~= nil and (stage == "intro" or stage == "deal")
		if busy and current and current.crate ~= crate then
			-- Another crate while this one is still opening: it waits for these totals to close.
			if #queue < MAX_QUEUE then
				table.insert(queue, message)
			end
			return
		end
		if busy and current then
			-- More of the crate that is still opening: its rewards join the ones on their way out.
			rewards = table.clone(current.rewards)
			table.move(message.rewards, 1, #message.rewards, #rewards + 1, rewards)
		end
		session = { crate = crate, rewards = rewards, count = #message.rewards, cards = prepare(rewards) }
		play(busy)
	end

	ctx.on("crates", function(result: unknown)
		if valid(result) then
			begin(result)
		end
	end)
end

return Opening
