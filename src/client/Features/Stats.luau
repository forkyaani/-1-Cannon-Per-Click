-- STATS, client side (docs/BUILD_QUEUE.md, section 6): one window that shows every number and exactly where
-- it comes from. Four tabs under a headline that is always there (Cannon Power):
--   POWER     the towers' multiplier chain written out, line by line, then every mini cannon's own DPS,
--             down to Cannon Power
--   BONUSES   one card per stat: its total, then one line per source, a timed source with its countdown
--   TOWERS    each tower's damage, rate, range and DPS, and its share of the total
--   TOTALS    monsters, bosses, eggs, levels, time played, best level
--
-- Nothing is worked out here. The server publishes the breakdown as Meta_stats while the window is open
-- (src/server/Features/Stats.luau), from the same functions the fight uses, so the window cannot disagree
-- with what is really applied. This file only writes it down, large enough to read on a phone and in a video.
local NAME = "STATS"
local WIDTH, HEIGHT = 760, 590
local HEAD_HEIGHT = 80 -- the Cannon Power banner
local TAB_TOP, TAB_HEIGHT = HEAD_HEIGHT + 8, 40
local LIST_TOP = TAB_TOP + TAB_HEIGHT + 8
local LINE = 32 -- one source
local LINE_TEXT = 20
local CARD_HEAD = 46 -- a card's own heading
local CARD_PAD = 10
local TOWER_ROW = 40
local RENEW_SECONDS = 4 -- how often the server is told the window is still open (it forgets after 12)

local TABS = { "POWER", "BONUSES", "TOWERS", "TOTALS" }

local function start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local left, right = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right
	local GOOD, BAD, FAINT = Colors.green, Colors.red, Colors.grey

	-- What each stat's card wears. An id the server adds later gets the last one.
	local LOOKS = {
		damage = { glyph = "⚔", color = Colors.orange },
		rate = { glyph = "⚡", color = Colors.gold },
		range = { glyph = "🎯", color = Colors.blue },
		boss = { glyph = "💀", color = Colors.red },
		coins = { glyph = "★", color = Colors.gold },
		luck = { glyph = "🍀", color = Colors.green },
		lives = { glyph = "❤", color = Colors.red },
		speed = { glyph = "🐢", color = Colors.gem },
		shots = { glyph = "💣", color = Colors.premium },
		slots = { glyph = "➕", color = Colors.blue },
		price = { glyph = "🏷", color = Colors.green },
		gems = { glyph = "💎", color = Colors.gem },
		crates = { glyph = "🎁", color = Colors.pumpkin },
		heal = { glyph = "✚", color = Colors.slime },
		other = { glyph = "•", color = Colors.grey },
	}

	------------------------------------------------------------------------------------------------
	-- Writing numbers
	------------------------------------------------------------------------------------------------
	-- "1.5", "12", "3.25", "1.25K": short, and never a row of zeros.
	local function num(value: any): string
		if typeof(value) ~= "number" or value ~= value then
			return "0"
		end
		local size = math.abs(value)
		if size >= 1000 then
			return (if value < 0 then "-" else "") .. Format.abbreviate(size)
		end
		local text = string.format(if size >= 100 then "%.0f" elseif size >= 10 then "%.1f" else "%.2f", value)
		if string.find(text, ".", 1, true) then
			text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
		end
		return text
	end

	-- A stat's total: "x6.3", "12", "1.5/s", "1.5%/s".
	local function totalText(unit: string, value: any): string
		if unit == "x" then
			return "x" .. num(value)
		elseif unit == "rate" then
			return num(value) .. "/s"
		elseif unit == "share" then
			return num((if typeof(value) == "number" then value else 0) * 100) .. "%/s"
		end
		return num(value)
	end

	-- What one source did, and whether that is good for the player: "+40%", "x2", "-15%", "+2".
	local function effect(source, lowGood: boolean?): (string, Color3)
		local mult = source.mult
		if source.how == "mult" and typeof(mult) == "number" then
			local good = (mult >= 1) ~= (lowGood == true)
			local color = if mult == 1 then FAINT elseif good then GOOD else BAD
			if mult >= 2 then
				return "x" .. num(mult), color
			elseif mult >= 1 then
				return `+{num((mult - 1) * 100)}%`, color
			end
			return `-{num((1 - mult) * 100)}%`, color
		end
		local add = if typeof(source.add) == "number" then source.add else 0
		local good = (add >= 0) ~= (lowGood == true)
		return (if add >= 0 then "+" else "-") .. num(math.abs(add)), if add == 0 then FAINT elseif good then GOOD else BAD
	end

	local function towerName(kind: string, level: number): string
		local def = Config.Towers[kind]
		local tier = Config.Cannons[Config.towerTier(level)]
		local name = if def then def.name else kind
		return if tier then `{tier.short} {name}` else name
	end

	------------------------------------------------------------------------------------------------
	-- The pieces
	------------------------------------------------------------------------------------------------
	local window = UI.window(NAME, WIDTH, HEIGHT)

	-- A rounded, outlined card in a list.
	local function card(parent: Instance, order: number, color: Color3?): Frame
		local outline = UI.stroke(3)
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		return UI.make("Frame", {
			Size = UDim2.new(1, -12, 0, CARD_HEAD),
			BackgroundColor3 = color or Colors.row,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = parent,
		}, {
			UI.corner(16),
			outline,
			UI.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Colors.white, Color3.fromRGB(196, 190, 214)) }),
		})
	end

	-- A list of lines inside a card, built as they are needed and kept: a refresh only rewrites them.
	-- A line is: name (left) | countdown chip | mid | value (right). `wide` makes room for the mid column.
	local function lineList(parent: Instance, top: number, wide: boolean)
		local lines = {}
		local nameRoom = if wide then 340 else 232
		local function line(index: number)
			local entry = lines[index]
			if entry then
				return entry
			end
			local frame = UI.make("Frame", {
				Position = UDim2.fromOffset(8, top + (index - 1) * LINE),
				Size = UDim2.new(1, -16, 0, LINE),
				BackgroundColor3 = Colors.ink,
				-- Every other line is shaded, so the eye follows a row across a wide card.
				BackgroundTransparency = if index % 2 == 1 then 0.78 else 1,
				BorderSizePixel = 0,
				Parent = parent,
			}, { UI.corner(8) })
			local name = UI.label({
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -nameRoom, 1, 0),
				TextXAlignment = left,
				TextSize = LINE_TEXT,
				TextColor3 = Colors.text,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = frame,
			})
			-- The countdown of a timed source: a cream note, ink text.
			local chip = UI.chip({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(nameRoom - 110), 0.5, 0),
				Size = UDim2.fromOffset(102, LINE - 8),
				Visible = false,
				Parent = frame,
			})
			local chipLabel = UI.label({
				Size = UDim2.fromScale(1, 1),
				TextSize = 16,
				TextColor3 = Colors.ink,
				Stroke = 0,
				Parent = chip,
			})
			local mid = UI.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -118, 0, 0),
				Size = UDim2.new(0, 96, 1, 0),
				TextXAlignment = right,
				TextSize = LINE_TEXT,
				Visible = wide,
				Parent = frame,
			})
			local value = UI.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				Size = UDim2.new(0, 104, 1, 0),
				TextXAlignment = right,
				TextSize = LINE_TEXT,
				Parent = frame,
			})
			entry = { frame = frame, name = name, chip = chip, chipLabel = chipLabel, mid = mid, value = value }
			lines[index] = entry
			return entry
		end
		local list = { count = 0 }
		-- Writes line `index`. left is a countdown ("12:40") or nil.
		function list.write(index: number, nameText: string, leftText: string?, midText: string, midColor: Color3, valueText: string, valueColor: Color3)
			local entry = line(index)
			entry.frame.Visible = true
			entry.name.Text = nameText
			entry.name.TextColor3 = Colors.text
			entry.chip.Visible = leftText ~= nil
			entry.chipLabel.Text = if leftText then `⏱ {leftText}` else ""
			entry.mid.Text = midText
			entry.mid.TextColor3 = midColor
			entry.value.Text = valueText
			entry.value.TextColor3 = valueColor
			return entry
		end
		-- Hides what is past `count`; returns the height the lines take.
		function list.finish(count: number): number
			for index = count + 1, #lines do
				lines[index].frame.Visible = false
			end
			list.count = count
			return count * LINE
		end
		return list
	end

	------------------------------------------------------------------------------------------------
	-- The headline: Cannon Power, always in view
	------------------------------------------------------------------------------------------------
	local head = UI.make("Frame", {
		Size = UDim2.new(1, 0, 0, HEAD_HEIGHT),
		BackgroundTransparency = 1,
		Parent = window.body,
	})
	UI.sticker(head, UI.Variants.premium, { radius = 20, lip = 6, outline = 4 })
	UI.disc({ Position = UDim2.fromOffset(12, 9), Size = UDim2.fromOffset(56, 56) }, Colors.power, "⚔", Colors.ink).Parent = head
	UI.label({
		Position = UDim2.fromOffset(80, 6),
		Size = UDim2.fromOffset(300, 22),
		Text = "CANNON POWER",
		TextXAlignment = left,
		TextSize = 20,
		TextColor3 = Colors.cream,
		ZIndex = 2,
		Parent = head,
	})
	local powerLabel = UI.label({
		Position = UDim2.fromOffset(80, 26),
		Size = UDim2.fromOffset(380, 44),
		Text = "0/s",
		Font = UI.TITLE_FONT,
		TextXAlignment = left,
		TextSize = 42,
		TextColor3 = Colors.power,
		Stroke = 3,
		ZIndex = 2,
		Parent = head,
	})
	-- What Cannon Power is made of, at a glance: the towers' damage per second and the mini cannons'.
	local headFacts = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 8),
		Size = UDim2.fromOffset(270, 58),
		Text = "",
		TextXAlignment = right,
		TextSize = 20,
		LineHeight = 1.15,
		ZIndex = 2,
		Parent = head,
	})

	------------------------------------------------------------------------------------------------
	-- Tabs
	------------------------------------------------------------------------------------------------
	local selected = TABS[1]
	local tabButtons, pages = {}, {}
	local refresh
	for index, name in TABS do
		local share = 1 / #TABS
		local button = UI.button({
			Position = UDim2.new((index - 1) * share, 2, 0, TAB_TOP),
			Size = UDim2.new(share, -6, 0, TAB_HEIGHT),
			Text = name,
			BackgroundColor3 = Colors.grey,
			Parent = window.body,
		})
		button.Activated:Connect(function()
			selected = name
			refresh(true)
		end)
		tabButtons[name] = button
		pages[name] = UI.scroll(window.body, {
			Name = name,
			Position = UDim2.fromOffset(0, LIST_TOP),
			Size = UDim2.new(1, 0, 1, -LIST_TOP),
			Visible = false,
		})
	end

	------------------------------------------------------------------------------------------------
	-- POWER: the chain
	------------------------------------------------------------------------------------------------
	local chainCard = card(pages.POWER, 1)
	UI.label({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 30),
		Text = "HOW YOUR CANNON POWER IS MADE",
		Font = UI.TITLE_FONT,
		TextXAlignment = left,
		TextSize = 24,
		Parent = chainCard,
	})
	local chainLines = lineList(chainCard, CARD_HEAD, true)
	local chainNote = UI.text({
		Size = UDim2.new(1, -12, 0, 44),
		LayoutOrder = 2,
		Text = "",
		TextWrapped = true,
		TextColor3 = Colors.text,
		MaxSize = 18,
		Parent = pages.POWER,
	})

	local function showChain(payload)
		local chain = if typeof(payload.chain) == "table" then payload.chain else {}
		local count = 1
		chainLines.write(1, "Your towers  (damage x shots a second)", nil, "", FAINT, `{num(payload.base)}/s`, Colors.white)
		for _, source in chain do
			count += 1
			local text, color = effect({ how = "mult", mult = source.mult, add = 0 })
			chainLines.write(count, `×  {tostring(source.label)}`, source.left, text, color, `{num(source.value)}/s`, Colors.white)
		end
		-- The mini cannons are not in the chain: each one adds its own damage per second, whatever the towers'
		-- multipliers are. `value` on the right keeps running: Cannon Power so far.
		local pets = if typeof(payload.pets) == "table" then payload.pets else {}
		local petLines = if typeof(pets.lines) == "table" then pets.lines else {}
		local running = if typeof(payload.towerPower) == "number" then payload.towerPower else 0
		for _, pet in petLines do
			local dps = if typeof(pet.dps) == "number" then pet.dps else 0
			running += dps
			count += 1
			chainLines.write(count, `+  {tostring(pet.label)}`, nil, `+{num(dps)} DPS`, GOOD, `{num(running)}/s`, Colors.white)
		end
		for _, source in if typeof(pets.bonuses) == "table" then pets.bonuses else {} do
			local add = if typeof(source.add) == "number" then source.add else 0
			running += add
			count += 1
			chainLines.write(count, `+  {tostring(source.label)}  (mini cannons)`, source.left, `+{num(add)} DPS`, GOOD, `{num(running)}/s`, Colors.white)
		end
		count += 1
		local last = chainLines.write(count, "=  CANNON POWER", nil, "", FAINT, `{num(payload.power)}/s`, Colors.power)
		last.name.TextColor3 = Colors.power
		chainCard.Size = UDim2.new(1, -12, 0, CARD_HEAD + chainLines.finish(count) + CARD_PAD)
		local speed = if typeof(payload.speed) == "number" then payload.speed else 1
		chainNote.Text = "These numbers come from the server: they are exactly what the game applies."
			.. (if speed > 1 then `\nGame speed {speed}x makes the whole fight run faster. It is not counted in Cannon Power.` else "")
	end

	------------------------------------------------------------------------------------------------
	-- BONUSES: one card per stat
	------------------------------------------------------------------------------------------------
	local statCards = {} -- [section id] = { frame, total, lines }
	local function statCard(section, order: number)
		local entry = statCards[section.id]
		if not entry then
			local look = LOOKS[section.id] or LOOKS.other
			local frame = card(pages.BONUSES, order)
			UI.disc({ Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(36, 36) }, look.color, look.glyph, Colors.ink).Parent = frame
			local title = UI.label({
				Position = UDim2.fromOffset(56, 8),
				Size = UDim2.new(1, -240, 0, 30),
				Font = UI.TITLE_FONT,
				TextXAlignment = left,
				TextSize = 24,
				Parent = frame,
			})
			local total = UI.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -18, 0, 6),
				Size = UDim2.fromOffset(170, 34),
				Font = UI.TITLE_FONT,
				TextXAlignment = right,
				TextSize = 30,
				TextColor3 = Colors.power,
				Stroke = 3,
				Parent = frame,
			})
			entry = { frame = frame, title = title, total = total, lines = lineList(frame, CARD_HEAD, false) }
			statCards[section.id] = entry
		end
		entry.frame.LayoutOrder = order
		return entry
	end

	local function showBonuses(payload)
		local sections = if typeof(payload.sections) == "table" then payload.sections else {}
		local seen = {}
		for order, section in sections do
			if typeof(section) ~= "table" or typeof(section.id) ~= "string" then
				continue
			end
			seen[section.id] = true
			local entry = statCard(section, order)
			entry.frame.Visible = true
			entry.title.Text = tostring(section.name or section.id)
			entry.total.Text = totalText(section.unit, section.total)
			local sources = if typeof(section.sources) == "table" then section.sources else {}
			local count = 0
			for _, source in sources do
				count += 1
				local text, color = effect(source, section.lowGood)
				entry.lines.write(count, tostring(source.label), source.left, "", FAINT, text, color)
			end
			if count == 0 then
				count = 1
				entry.lines.write(1, "No bonuses yet", nil, "", FAINT, "—", FAINT).name.TextColor3 = FAINT
			end
			-- The mini cannons' shots card also says what they add up to: more shots are smaller shots.
			local pets = payload.pets
			if section.id == "shots" and typeof(pets) == "table" and (pets.equipped or 0) > 0 then
				count += 1
				entry.lines.write(count, "All their shots together deal", nil, "", FAINT, `{num(pets.dps)}/s`, Colors.white)
			end
			entry.frame.Size = UDim2.new(1, -12, 0, CARD_HEAD + entry.lines.finish(count) + CARD_PAD)
		end
		for id, entry in statCards do
			if not seen[id] then
				entry.frame.Visible = false
			end
		end
	end

	------------------------------------------------------------------------------------------------
	-- TOWERS: one row each
	------------------------------------------------------------------------------------------------
	-- Columns: where each one ends, from the card's right edge, and how wide it is.
	local COLUMNS = {
		{ key = "damage", title = "DAMAGE", right = 348, width = 84 },
		{ key = "rate", title = "RATE", right = 270, width = 74 },
		{ key = "range", title = "RANGE", right = 208, width = 58 },
		{ key = "dps", title = "DPS", right = 124, width = 80 },
	}
	local SHARE_WIDTH = 106
	local towerCard = card(pages.TOWERS, 1)
	local function cell(parent: Instance, column, y: number, height: number, size: number, color: Color3): TextLabel
		return UI.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -column.right, 0, y),
			Size = UDim2.fromOffset(column.width, height),
			TextXAlignment = right,
			TextSize = size,
			TextColor3 = color,
			Parent = parent,
		})
	end
	UI.label({
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.fromOffset(200, 30),
		Text = "TOWER",
		Font = UI.TITLE_FONT,
		TextXAlignment = left,
		TextSize = 22,
		Parent = towerCard,
	})
	for _, column in COLUMNS do
		cell(towerCard, column, 8, 30, 18, Colors.cream).Text = column.title
	end
	UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(SHARE_WIDTH, 30),
		Text = "SHARE",
		TextSize = 18,
		TextColor3 = Colors.cream,
		Parent = towerCard,
	})
	local towerRows = {}
	local function towerRow(index: number)
		local row = towerRows[index]
		if row then
			return row
		end
		local frame = UI.make("Frame", {
			Position = UDim2.fromOffset(8, CARD_HEAD + (index - 1) * TOWER_ROW),
			Size = UDim2.new(1, -16, 0, TOWER_ROW),
			BackgroundColor3 = Colors.ink,
			BackgroundTransparency = if index % 2 == 1 then 0.78 else 1,
			BorderSizePixel = 0,
			Parent = towerCard,
		}, { UI.corner(8) })
		local swatch = UI.make("Frame", {
			Position = UDim2.fromOffset(8, 9),
			Size = UDim2.fromOffset(12, TOWER_ROW - 18),
			BackgroundColor3 = Colors.gold,
			BorderSizePixel = 0,
			Parent = frame,
		}, { UI.corner(4), UI.stroke(2) })
		local name = UI.label({
			Position = UDim2.fromOffset(28, 2),
			Size = UDim2.new(1, -456, 0, 20),
			TextXAlignment = left,
			TextSize = 19,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		local level = UI.label({
			Position = UDim2.fromOffset(28, 21),
			Size = UDim2.new(1, -456, 0, 16),
			TextXAlignment = left,
			TextSize = 15,
			TextColor3 = Colors.cream,
			Stroke = 1.5,
			Parent = frame,
		})
		row = { frame = frame, swatch = swatch, name = name, level = level, cells = {} }
		for _, column in COLUMNS do
			-- The row is 8 px narrower on each side than the card the headings sit on.
			row.cells[column.key] = cell(frame, { right = column.right - 8, width = column.width }, 0, TOWER_ROW, LINE_TEXT, Colors.white)
		end
		row.cells.dps.TextColor3 = Colors.power
		row.share = UI.bar({
			parent = frame,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -6, 0.5, 0),
			size = UDim2.fromOffset(SHARE_WIDTH, 26),
			color = Colors.gold,
			textSize = 16,
		})
		towerRows[index] = row
		return row
	end

	local petsCard = card(pages.TOWERS, 2)
	UI.disc({ Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(36, 36) }, Colors.premium, "💣", Colors.ink).Parent = petsCard
	local petsLabel = UI.label({
		Position = UDim2.fromOffset(56, 0),
		Size = UDim2.new(1, -70, 1, 0),
		TextXAlignment = left,
		TextSize = LINE_TEXT,
		TextWrapped = true,
		Parent = petsCard,
	})
	petsCard.Size = UDim2.new(1, -12, 0, 56)

	local function showTowers(payload)
		local towers = if typeof(payload.towers) == "table" then payload.towers else {}
		-- The hardest hitter first: that is the one a player wants to find.
		local sorted = table.clone(towers)
		table.sort(sorted, function(a, b)
			if (a.dps or 0) ~= (b.dps or 0) then
				return (a.dps or 0) > (b.dps or 0)
			end
			return (a.pad or 0) < (b.pad or 0)
		end)
		for index, tower in sorted do
			local row = towerRow(index)
			local def = Config.Towers[tower.kind]
			row.frame.Visible = true
			row.swatch.BackgroundColor3 = (def and def.color) or Colors.gold
			row.name.Text = towerName(tostring(tower.kind), tower.level or 1)
			row.level.Text = `Level {tower.level or 1}  •  pad {tower.pad or "?"}`
			row.cells.damage.Text = num(tower.damage)
			row.cells.rate.Text = `{num(tower.rate)}/s`
			row.cells.range.Text = num(tower.range)
			row.cells.dps.Text = num(tower.dps)
			local share = if typeof(tower.share) == "number" then tower.share else 0
			row.share.set(share, `{math.floor(share * 100 + 0.5)}%`)
		end
		for index = #sorted + 1, #towerRows do
			towerRows[index].frame.Visible = false
		end
		towerCard.Size = UDim2.new(1, -12, 0, CARD_HEAD + #sorted * TOWER_ROW + CARD_PAD)

		local pets = if typeof(payload.pets) == "table" then payload.pets else {}
		local equipped = pets.equipped or 0
		petsLabel.Text = if equipped > 0
			then `MINI CANNONS  •  {equipped} equipped  •  +{num(pets.dps)} DPS in all  •  they hit your base's lead monster wherever you are`
			else "MINI CANNONS  •  none equipped yet: hatch an egg on a world's island"
	end

	------------------------------------------------------------------------------------------------
	-- TOTALS: six tiles
	------------------------------------------------------------------------------------------------
	local TILES = {
		{ key = "kills", glyph = "👾", color = Colors.green, title = "MONSTERS DEFEATED" },
		{ key = "bosses", glyph = "💀", color = Colors.red, title = "BOSSES DEFEATED" },
		{ key = "hatches", glyph = "🥚", color = Colors.gold, title = "EGGS HATCHED" },
		{ key = "levels", glyph = "🚩", color = Colors.blue, title = "LEVELS CLEARED" },
		{ key = "seconds", glyph = "⏱", color = Colors.premium, title = "TIME PLAYED" },
		{ key = "best", glyph = "🏆", color = Colors.orange, title = "BEST LEVEL" },
	}
	local TILE_HEIGHT = 150
	local tileGrid = UI.make("Frame", {
		Size = UDim2.new(1, -12, 0, TILE_HEIGHT * 2 + 12),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = pages.TOTALS,
	})
	local tileValues = {}
	for index, tile in TILES do
		local column, rowIndex = (index - 1) % 3, (index - 1) // 3
		local outline = UI.stroke(3)
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local frame = UI.make("Frame", {
			Position = UDim2.new(column / 3, 4, 0, rowIndex * (TILE_HEIGHT + 12)),
			Size = UDim2.new(1 / 3, -10, 0, TILE_HEIGHT),
			BackgroundColor3 = Colors.row,
			BorderSizePixel = 0,
			Parent = tileGrid,
		}, {
			UI.corner(18),
			outline,
			UI.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Colors.white, Color3.fromRGB(196, 190, 214)) }),
		})
		UI.disc({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(48, 48) }, tile.color, tile.glyph, Colors.ink).Parent = frame
		tileValues[tile.key] = UI.label({
			Position = UDim2.fromOffset(6, 62),
			Size = UDim2.new(1, -12, 0, 44),
			Font = UI.TITLE_FONT,
			Text = "0",
			TextSize = 36,
			TextColor3 = Colors.power,
			Stroke = 3,
			Parent = frame,
		})
		UI.label({
			Position = UDim2.fromOffset(6, 110),
			Size = UDim2.new(1, -12, 0, 26),
			Text = tile.title,
			TextSize = 18,
			TextColor3 = Colors.cream,
			Parent = frame,
		})
	end

	local function showTotals(payload)
		local totals = if typeof(payload.totals) == "table" then payload.totals else {}
		for _, key in { "kills", "bosses", "hatches", "levels" } do
			tileValues[key].Text = Format.abbreviate(if typeof(totals[key]) == "number" then totals[key] else 0)
		end
		tileValues.seconds.Text = Format.duration(if typeof(totals.seconds) == "number" then totals.seconds else 0)
		local best = if typeof(totals.best) == "number" then totals.best else 0
		if best >= 1 then
			local index, localLevel = Config.worldOf(best)
			tileValues.best.Text = `{string.upper(Config.Worlds[index].name)} {localLevel}`
			tileValues.best.TextSize = 28
		else
			tileValues.best.Text = "—"
		end
	end

	------------------------------------------------------------------------------------------------
	-- Refresh. The window is refreshed on every change of the player's state (ten times a second in a
	-- fight); it only redraws when the server has published a new breakdown or the tab changed.
	------------------------------------------------------------------------------------------------
	local drawn = nil
	function refresh(force: boolean?)
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == selected then Colors.blue else Colors.grey
			pages[name].Visible = name == selected
		end
		local payload = State.feature("stats")
		if payload == drawn and not force then
			return
		end
		drawn = payload
		-- Until the first breakdown arrives, the headline is the number the HUD shows.
		local power = if typeof(payload.power) == "number" then payload.power else State.get("CannonPower", 0)
		powerLabel.Text = `{num(power)}/s`
		-- Its two halves: what the towers deal a second, and what the mini cannons add on their own.
		local pets = if typeof(payload.pets) == "table" then payload.pets else {}
		local towers = if typeof(payload.towerPower) == "number" then payload.towerPower else State.get("TowerDps", 0)
		local minis = if typeof(pets.dps) == "number" then pets.dps else State.get("PetDps", 0)
		headFacts.Text = `towers {num(towers)}/s\nmini cannons +{num(minis)}/s`
		if typeof(payload.at) ~= "number" then
			chainNote.Text = "Loading your numbers..."
			return
		end
		showChain(payload)
		showBonuses(payload)
		showTowers(payload)
		showTotals(payload)
	end

	ctx.Windows.register(NAME, window, function()
		refresh(false)
	end)
	ctx.Hud.addMenuButton(NAME, Color3.fromRGB(255, 198, 26), 16, window.toggle)

	-- The server only works the breakdown out while it is being looked at: say when the window opens and
	-- closes, and keep saying it is open (a lost message must not leave the numbers frozen).
	local function watch()
		ctx.act("statsWatch", window.frame.Visible)
	end
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		watch()
		-- The server drops a request that comes too soon after another one: ask once more.
		task.delay(0.4, watch)
	end)
	task.spawn(function()
		while true do
			task.wait(RENEW_SECONDS)
			if window.frame.Visible then
				watch()
			end
		end
	end)
end

return { start = start }
