-- The INDEX window: every mini cannon in the game, ticked once the player has found it. The Huge cannons
-- come first, each with its special feature, then the eggs with what they hatch, then the mini cannons that
-- come from shops, rewards and crates. A Secret or a Huge stays "???" until the player has found one.
-- What has been found comes from the server as State.feature("huge").found.
--
-- And what the player sees of a Huge at work: the sign on the HUD while one is equipped, the giant shot and
-- its number whenever the server fires a Huge Shot, and the reveal when the game pass's Huge is given.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Requiring it is also what gives this client the things the shared module adds to Config: the Huge game
-- pass in the store, and each Huge's feature lines.
local Shared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Huge"))

local NAME = "INDEX" -- the window's title and its menu button
local COLUMNS = 4
local CELL_HEIGHT = 30
local TITLE_HEIGHT = 30
local HUGE_HEIGHT = 46
local TICK = "✅ " -- an emoji: the game's font has no tick of its own
local MYSTERY = "???"
local TOGGLE_WIDTH = 200 -- the Tycoon's AUTO UPGRADE switch
local ARRIVAL_SECONDS = 2 -- the wait before the game pass's Huge is revealed, so a player who just joined sees it

local Huge = {}

function Huge.start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local left = Enum.TextXAlignment.Left

	local window = UI.window(NAME, 660, 470)
	local summary = UI.text({ Size = UDim2.new(1, 0, 0, 22), TextColor3 = Colors.text, MaxSize = 16, Parent = window.body })
	-- The Tycoon's switch: only there while a Huge that upgrades towers by itself is equipped. It takes the
	-- right end of the summary's line.
	local autoButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(TOGGLE_WIDTH, 24),
		Visible = false,
		Parent = window.body,
	})
	autoButton.Activated:Connect(function()
		ctx.act("toggleTycoon")
	end)
	local list = UI.scroll(window.body, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28) })

	local groups = {} -- { title, name, ids }: a box of the list with its heading
	local cells = {} -- { id, pet, icon, label }: one mini cannon in an egg's or the last box's grid
	local hugeRows = {} -- { id, pet, icon, label, detail }: one Huge in the first box
	local listed = {} -- [mini cannon id] = true for every one the index lists

	local function box(name: string, ids: { string }, height: number): Frame
		local frame = UI.make("Frame", {
			Size = UDim2.new(1, -10, 0, TITLE_HEIGHT + height + 6),
			BackgroundColor3 = Colors.row,
			LayoutOrder = #groups + 1,
			Parent = list,
		}, { UI.corner(8) })
		local title = UI.text({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, TITLE_HEIGHT - 8),
			TextXAlignment = left,
			TextColor3 = Colors.gold,
			Parent = frame,
		})
		table.insert(groups, { title = title, name = name, ids = ids })
		for _, id in ids do
			listed[id] = true
		end
		return frame
	end

	local function icon(size: number, position: UDim2, parent: Instance): Frame
		return UI.make("Frame", { Size = UDim2.fromOffset(size, size), Position = position, Parent = parent }, {
			UI.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UI.stroke(1.5),
		})
	end

	local function grid(name: string, ids: { string })
		local frame = box(name, ids, math.ceil(#ids / COLUMNS) * CELL_HEIGHT)
		for index, id in ids do
			local column, row = (index - 1) % COLUMNS, (index - 1) // COLUMNS
			local cell = UI.make("Frame", {
				Position = UDim2.new(column / COLUMNS, 10, 0, TITLE_HEIGHT + row * CELL_HEIGHT),
				Size = UDim2.new(1 / COLUMNS, -12, 0, CELL_HEIGHT - 4),
				BackgroundTransparency = 1,
				Parent = frame,
			})
			table.insert(cells, {
				id = id,
				pet = Config.Pets[id],
				icon = icon(18, UDim2.fromOffset(0, 4), cell),
				label = UI.text({
					Position = UDim2.fromOffset(24, 0),
					Size = UDim2.new(1, -24, 1, 0),
					TextXAlignment = left,
					MaxSize = 15,
					Parent = cell,
				}),
			})
		end
	end

	-- Built the first time the window is opened: it is a few hundred labels nobody needs before then.
	local function build()
		local every = `each one: x{Config.HugePower} ALL tower damage and a Huge Shot`
		local frame = box(`HUGE CANNONS  •  {every}`, Config.Huges, #Config.Huges * HUGE_HEIGHT)
		for index, id in Config.Huges do
			local top = TITLE_HEIGHT + (index - 1) * HUGE_HEIGHT
			table.insert(hugeRows, {
				id = id,
				pet = Config.Pets[id],
				icon = icon(28, UDim2.fromOffset(10, top + 7), frame),
				label = UI.text({
					Position = UDim2.fromOffset(48, top + 2),
					Size = UDim2.new(1, -58, 0, 22),
					TextXAlignment = left,
					Parent = frame,
				}),
				detail = UI.text({
					Position = UDim2.fromOffset(48, top + 24),
					Size = UDim2.new(1, -58, 0, 18),
					TextXAlignment = left,
					TextColor3 = Colors.text,
					MaxSize = 14,
					Parent = frame,
				}),
			})
		end

		local hatched = {}
		for _, egg in Config.Eggs do
			local ids = {}
			for _, entry in egg.pets do
				hatched[entry.id] = true
				table.insert(ids, entry.id)
			end
			grid(string.upper(egg.name), ids)
		end

		-- Whatever no egg hatches, fused versions aside, weakest first.
		local others = {}
		for id, pet in Config.Pets do
			if pet.base == id and not pet.huge and not hatched[id] then
				table.insert(others, id)
			end
		end
		table.sort(others, function(a, b)
			local bonusA, bonusB = Config.Pets[a].bonus, Config.Pets[b].bonus
			return if bonusA == bonusB then a < b else bonusA < bonusB
		end)
		grid("SHOPS, REWARDS AND CRATES", others)
	end

	local shown = nil -- the server's table the window was last written for
	local function refresh()
		if #groups == 0 then
			build()
		end
		local meta = State.feature("huge")
		local upgrades = false
		for _, id in State.meta.equipped or {} do
			local pet = Config.Pets[id]
			local feature = Shared.Features[if pet then pet.plain else id] -- an enchanted Huge is the same Huge
			upgrades = upgrades or (feature ~= nil and feature.autoUpgrade == true)
		end
		local on = meta.autoUpgrade ~= false
		autoButton.Visible = upgrades
		autoButton.Text = if on then "AUTO UPGRADE: ON" else "AUTO UPGRADE: OFF"
		autoButton.BackgroundColor3 = if on then Colors.green else Colors.grey
		summary.Size = UDim2.new(1, if upgrades then -TOGGLE_WIDTH - 8 else 0, 0, 22)
		if meta == shown then
			return
		end
		shown = meta
		local found = meta.found or {}

		for _, row in hugeRows do
			local pet = row.pet
			local known = found[row.id] or not pet.hidden
			row.icon.BackgroundColor3 = if known then pet.color else Colors.dark
			row.label.Text = if known then (if found[row.id] then TICK else "") .. pet.name else MYSTERY
			row.label.TextColor3 = if found[row.id] then Config.RarityColors[pet.rarity] else Colors.grey
			if known then
				local feature = Shared.Features[row.id]
				row.detail.Text = `{Format.petPower(pet)} tower damage  •  {feature.name}: {feature.text}`
			else
				row.detail.Text = `Hidden in an egg  •  {Config.oneIn(Config.HugeChance)}`
			end
		end
		for _, cell in cells do
			local pet = cell.pet
			-- In a grid there is only room for the short name: "Storm" would not say it is the Huge.
			local name = if pet.huge then `Huge {pet.short}` else pet.short
			if found[cell.id] then
				cell.icon.BackgroundColor3 = pet.color
				cell.label.Text = TICK .. name
				cell.label.TextColor3 = Config.RarityColors[pet.rarity]
			else
				cell.icon.BackgroundColor3 = if pet.hidden then Colors.dark else pet.color:Lerp(Colors.row, 0.65)
				cell.label.Text = if pet.hidden then MYSTERY else name
				cell.label.TextColor3 = Colors.grey
			end
		end
		for _, group in groups do
			local count = 0
			for _, id in group.ids do
				if found[id] then
					count += 1
				end
			end
			group.title.Text = `{group.name}  •  {count}/{#group.ids}`
		end

		local count, total = 0, 0
		for id in listed do
			total += 1
			if found[id] then
				count += 1
			end
		end
		summary.Text = `Found {count} of {total}  •  Secret and Huge mini cannons stay {MYSTERY} until you find one`
	end

	ctx.Windows.register(NAME, window, refresh)
	ctx.Hud.addMenuButton(NAME, Color3.fromRGB(70, 170, 190), 14, window.toggle)

	------------------------------------------------------------------------------------------------
	-- The sign on the HUD that a Huge is working, on the plot and in the marketplace alike. It says what the
	-- equipped Huges multiply all tower damage by, its bar fills up to the next Huge Shot, and
	-- it jumps when one is fired.
	------------------------------------------------------------------------------------------------
	local mythical = Config.RarityColors.Mythical
	local badgeText = UI.text({ Position = UDim2.fromOffset(10, 1), Size = UDim2.new(1, -20, 1, -7), TextColor3 = mythical })
	local chargeFill = UI.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = mythical, BorderSizePixel = 0 }, { UI.corner(2) })
	local pop = UI.make("UIScale", {})
	local pill = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.dark,
		BackgroundTransparency = 0.2,
	}, {
		UI.corner(10),
		UI.make("UIStroke", { Thickness = 2, Color = mythical }),
		pop,
		badgeText,
		UI.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, -28, 0, 3),
			BackgroundColor3 = Colors.grey,
			BorderSizePixel = 0,
		}, { UI.corner(2), chargeFill }),
	})
	local badge = UI.panel({
		Name = "HugeBadge",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(460, 28),
		Visible = false,
	}, { pill })
	-- Between the AUTO toggle and the toast line.
	ctx.Hud.onLayout(function(layout)
		badge.Position = UDim2.new(0.5, 0, 0, (layout.top + 210) * layout.s)
	end)

	local badgeShown = "" -- what the badge last said

	local function refreshBadge()
		-- One of each: a second copy of the same Huge adds nothing.
		local huges, power = {}, 1
		for _, id in State.meta.equipped or {} do
			local pet = Config.Pets[id]
			if pet and pet.huge and not table.find(huges, pet.plain) then
				table.insert(huges, pet.plain)
				power *= pet.power
			end
		end
		-- Hidden: it sat on top of the level panel. What a Huge adds is shown in MINI CANNONS (and STATS).
		badge.Visible = false
		if #huges == 0 then
			return
		end
		local name = if #huges == 1 then string.upper(Config.Pets[huges[1]].name) else `{#huges} HUGE CANNONS`
		local text = `{name}  •  x{Format.abbreviate(power)} TOWER DAMAGE  •  HUGE SHOT x{Config.HugeShot.shots}`
		if text ~= badgeShown then
			badgeShown = text
			badgeText.Text = text
		end
	end
	State.onChange(refreshBadge)
	refreshBadge()

	------------------------------------------------------------------------------------------------
	-- The Huge Shot: the server fires it at the lead monster near the player (the one their mini cannons shoot
	-- at) and says which Huge and how hard it hit. Effects draws the shot (on the player's plot only); as it
	-- lands, its number bursts out of the monster.
	------------------------------------------------------------------------------------------------
	local function burst(at: Vector3, damage: number, color: Color3)
		local camera = workspace.CurrentCamera
		local point, onScreen = camera:WorldToViewportPoint(at)
		if not onScreen then
			return
		end
		-- Sized like the rest of the HUD: laid out for a 720px tall screen.
		local scale = math.clamp(camera.ViewportSize.Y / 720, 0.5, 1.3)
		-- A label, so it never takes a press meant for what is under it; under the windows (ZIndex 10).
		local label = UI.make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(point.X, point.Y - 46 * scale),
			Size = UDim2.fromOffset(340 * scale, 88 * scale),
			BackgroundTransparency = 1,
			Font = UI.FONT,
			Text = `HUGE SHOT!\n-{Format.abbreviate(damage)}`,
			TextColor3 = color,
			TextScaled = true,
			TextStrokeTransparency = 0,
			ZIndex = 5,
			Parent = UI.gui,
		})
		local grow = UI.make("UIScale", { Scale = 0.4, Parent = label })
		TweenService:Create(grow, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		-- It holds for a moment, then floats up and fades.
		local fade = TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4), {
			Position = label.Position - UDim2.fromOffset(0, 60 * scale),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		fade.Completed:Connect(function()
			label:Destroy()
		end)
		fade:Play()
	end

	ctx.on("hugeShot", function(petId: unknown, damage: unknown)
		if typeof(petId) ~= "string" or typeof(damage) ~= "number" then
			return
		end
		pop.Scale = 1.2
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local pet = Config.Pets[petId]
		local color = if pet and pet.accent then pet.accent else mythical
		ctx.Effects.hugeShot(petId, function(position: Vector3)
			burst(position, damage, color)
		end)
	end)

	------------------------------------------------------------------------------------------------
	-- The game pass's Huge arriving: the server marks it in State.feature("huge").arrived = { id, n } in the
	-- session it gives it, with a new n each time, and it gets the hatch reveal of a Huge. Not on later joins:
	-- the mark is never saved.
	------------------------------------------------------------------------------------------------
	local arrivalSeen = nil -- the n of the last arrival that was revealed
	local function checkArrival()
		local arrived = State.feature("huge").arrived
		if typeof(arrived) ~= "table" or arrived.n == arrivalSeen then
			return
		end
		arrivalSeen = arrived.n
		local pet = Config.Pets[arrived.id]
		if not pet then
			return
		end
		task.delay(ARRIVAL_SECONDS, function()
			local note = if pet.tradable == false then "Yours forever: it cannot be traded" else "Yours to keep"
			ctx.Effects.hatch(nil, { { pet = arrived.id, kept = true, note = note } }, {
				name = "YOUR HUGE CANNON IS HERE!",
				color = pet.color,
			})
		end)
	end
	State.onChange(checkArrival)
	checkArrival()
end

return Huge
