-- Fusing, client side: the FUSE window, opened by the Fusion Machine on The Sun's island (its prompt carries
-- Window = "FUSE"). The player puts three mini cannons of the same kind and tier into the machine's three
-- slots, from the list under it, and presses FUSE. The result keeps the enchantments of the first one
-- picked: the window shows which, and warns (and takes a second press) when the other two carry enchantments
-- that would be lost. FILL picks three matching ones without enchantments.
-- The rules come from the shared module, which is what the server checks a request with.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fuse = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Fuse"))

local ROW_HEIGHT = 58
local MACHINE_HEIGHT = 196
local MACHINE_TOP = 26
local LIST_TOP = MACHINE_TOP + MACHINE_HEIGHT + 6
local SLOT_WIDTH, SLOT_HEIGHT, SLOT_GAP = 148, 62, 6
local CONFIRM_SECONDS = 5 -- how long the first of the two presses that lose enchantments stays armed
local MAGIC = Color3.fromRGB(226, 170, 255)

local function start(ctx)
	local Config, Format, State, UI = ctx.Config, ctx.Format, ctx.State, ctx.UI
	local Colors = UI.Colors
	local left = Enum.TextXAlignment.Left
	local world = Config.Worlds[Fuse.ISLAND]

	local window = UI.window(Fuse.WINDOW, 700, 540)
	local headline = UI.text({
		Size = UDim2.new(1, -8, 0, 22),
		TextXAlignment = left,
		TextColor3 = Colors.gold,
		MaxSize = 18,
		Parent = window.body,
	})

	local picks: { string } = {} -- what is in the machine, in the order picked
	local armed = -math.huge -- when FUSE was first pressed for a fusion that loses enchantments
	local lastMade = "" -- what the last fusion made, shown until the next pick
	local refresh

	-- A mini cannon's enchantments, marked: "✨ Sharp III", or "" for a plain one.
	local function magic(id: string): string
		local text = Config.enchantText(id)
		return if text ~= "" then "✨ " .. text else ""
	end

	------------------------------------------------------------------------------------------------
	-- The machine: three slots, what they make, the warning, and FILL / CLEAR / FUSE.
	------------------------------------------------------------------------------------------------
	local machine = UI.make("Frame", {
		Name = "Machine",
		Position = UDim2.fromOffset(0, MACHINE_TOP),
		Size = UDim2.new(1, 0, 0, MACHINE_HEIGHT),
		BackgroundColor3 = Colors.dark,
		BorderSizePixel = 0,
		Parent = window.body,
	}, { UI.corner(14), UI.stroke(3) })
	local slots = {}
	for slot = 1, Fuse.COUNT do
		local button = UI.button({
			Position = UDim2.fromOffset(10 + (slot - 1) * (SLOT_WIDTH + SLOT_GAP), 8),
			Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT),
			Parent = machine,
		})
		-- Pressing a filled slot takes that mini cannon out again; the ones after it move up.
		button.Activated:Connect(function()
			if picks[slot] then
				table.remove(picks, slot)
				armed = -math.huge
				refresh()
			end
		end)
		slots[slot] = button
	end
	local resultLabel = UI.text({
		Position = UDim2.fromOffset(10 + Fuse.COUNT * (SLOT_WIDTH + SLOT_GAP) + 4, 8),
		Size = UDim2.new(1, -(24 + Fuse.COUNT * (SLOT_WIDTH + SLOT_GAP)), 0, SLOT_HEIGHT),
		TextXAlignment = left,
		TextWrapped = true,
		MaxSize = 16,
		Parent = machine,
	})
	local keeps = UI.text({
		Position = UDim2.fromOffset(12, 76),
		Size = UDim2.new(1, -24, 0, 34),
		TextXAlignment = left,
		TextWrapped = true,
		TextColor3 = MAGIC,
		MaxSize = 15,
		Parent = machine,
	})
	local warning = UI.text({
		Position = UDim2.fromOffset(12, 112),
		Size = UDim2.new(1, -24, 0, 34),
		TextXAlignment = left,
		TextWrapped = true,
		TextColor3 = Colors.red,
		MaxSize = 15,
		Parent = machine,
	})
	local fillButton = UI.button({
		Position = UDim2.fromOffset(10, 150),
		Size = UDim2.fromOffset(150, 40),
		Text = "FILL",
		BackgroundColor3 = Colors.blue,
		Parent = machine,
	})
	local clearButton = UI.button({
		Position = UDim2.fromOffset(166, 150),
		Size = UDim2.fromOffset(120, 40),
		Text = "CLEAR",
		BackgroundColor3 = Colors.grey,
		Parent = machine,
	})
	local fuseButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 150),
		Size = UDim2.fromOffset(220, 40),
		Text = "FUSE",
		Parent = machine,
	})

	local list = UI.scroll(window.body, { Position = UDim2.fromOffset(0, LIST_TOP), Size = UDim2.new(1, 0, 1, -LIST_TOP) })
	local emptyLabel = UI.text({
		Size = UDim2.new(1, -10, 0, 40),
		LayoutOrder = 0,
		TextColor3 = Colors.text,
		MaxSize = 16,
		Text = `Nothing to fuse yet: it takes {Fuse.COUNT} of the same mini cannon. Hatch more eggs!`,
		Visible = false,
		Parent = list,
	})

	local function atMachine(): boolean
		return State.get("Place", "plot") == "island" and State.get("Island", 0) == Fuse.ISLAND
	end

	local function owned(): { [string]: number }
		local counts = State.meta.pets
		return if typeof(counts) == "table" then counts else {}
	end

	-- How many of a mini cannon are in the machine.
	local function inMachine(id: string): number
		local count = 0
		for _, pick in picks do
			if pick == id then
				count += 1
			end
		end
		return count
	end

	local function setButton(button: TextButton, text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	-- Whether one more of this mini cannon can go into the machine, and what its ADD button says if not.
	local function canAdd(id: string, counts): (boolean, string)
		if #picks >= Fuse.COUNT then
			return false, "FULL"
		elseif not Fuse.fusable(id) then
			return false, "TOP TIER"
		elseif (counts[id] or 0) - inMachine(id) < 1 then
			return false, "ALL IN"
		elseif #picks > 0 and not Fuse.matches(picks[1], id) then
			return false, "NO MATCH"
		end
		return true, "ADD"
	end

	fillButton.Activated:Connect(function()
		local filled, why = Fuse.fill(owned(), picks)
		if filled then
			picks = filled
			lastMade = ""
		elseif why then
			ctx.Hud.toast(why, "bad")
		end
		armed = -math.huge
		refresh()
	end)
	clearButton.Activated:Connect(function()
		table.clear(picks)
		armed = -math.huge
		refresh()
	end)
	fuseButton.Activated:Connect(function()
		if #picks ~= Fuse.COUNT or not Fuse.result(picks) then
			return
		end
		-- Enchantments would be lost: the first press only arms the button.
		if Fuse.lost(picks) > 0 and os.clock() - armed > CONFIRM_SECONDS then
			armed = os.clock()
			refresh()
			return
		end
		armed = -math.huge
		ctx.act("fuse", table.clone(picks))
	end)

	-- One row per different mini cannon that could be fused. Made once and kept, so a button never vanishes
	-- under a finger.
	local rows = {}
	local function rowFor(id: string)
		local row = rows[id]
		if not row then
			row = UI.row(list, ROW_HEIGHT, 0)
			row.title.Position = UDim2.fromOffset(58, 3)
			row.title.Size = UDim2.new(1, -212, 0, 22)
			row.sub.Position = UDim2.fromOffset(58, 26)
			row.sub.Size = UDim2.new(1, -212, 0, ROW_HEIGHT - 30)
			row.button.Activated:Connect(function()
				if canAdd(id, owned()) then
					table.insert(picks, id)
					lastMade = ""
					armed = -math.huge
					refresh()
				end
			end)
			rows[id] = row
		end
		return row
	end

	local shownCounts = nil -- the table of counts the list was last ordered for

	local function refreshList(counts)
		-- A kind is listed when the player owns three of it in all, enchanted or not: only those can be fused.
		local perKind = {}
		for id, count in counts do
			local pet = Config.Pets[id]
			if pet and typeof(count) == "number" and count > 0 and Fuse.fusable(id) then
				perKind[pet.plain] = (perKind[pet.plain] or 0) + count
			end
		end
		local ids = {}
		for id, count in counts do
			local pet = Config.Pets[id]
			if pet and typeof(count) == "number" and count > 0 and (perKind[pet.plain] or 0) >= Fuse.COUNT then
				table.insert(ids, id)
			end
		end
		if counts ~= shownCounts then
			shownCounts = counts
			-- Strongest first; a kind's enchanted ones next to its plain ones.
			table.sort(ids, function(a, b)
				local bonusA, bonusB = Config.Pets[a].bonus, Config.Pets[b].bonus
				return if bonusA == bonusB then a < b else bonusA > bonusB
			end)
			local listed = {}
			for order, id in ids do
				listed[id] = true
				rowFor(id).frame.LayoutOrder = order
			end
			for id, row in rows do
				row.frame.Visible = listed[id] == true
			end
		end
		emptyLabel.Visible = #ids == 0
		for _, id in ids do
			local pet = Config.Pets[id]
			local row = rows[id]
			if not row then
				continue
			end
			local above = Config.Pets[pet.next] -- what three of it make
			local tier = above and Config.FuseTiers[above.tier]
			row.icon.BackgroundColor3 = pet.color
			row.title.Text = `{pet.name}  x{counts[id] - inMachine(id)}`
			row.title.TextColor3 = Config.RarityColors[pet.rarity] or Colors.white
			local carried = magic(id)
			local into = if tier then `{Format.petPower(pet)}  •  3 make a {tier.name} one ({Format.petPower(above)})` else Format.petPower(pet)
			row.sub.Text = `{into}\n{if carried ~= "" then carried else "No enchantments"}`
			row.sub.TextColor3 = if carried ~= "" then MAGIC else Colors.text
			local ok, word = canAdd(id, counts)
			setButton(row.button, word, if ok then Colors.green else Colors.grey)
		end
	end

	function refresh()
		local counts = owned()
		-- What is in the machine must still be owned (a trade, or the fusion that just went through).
		local kept, used = {}, {}
		for _, id in picks do
			used[id] = (used[id] or 0) + 1
			if Config.Pets[id] and used[id] <= (counts[id] or 0) then
				table.insert(kept, id)
			end
		end
		picks = kept

		local unlocked = Fuse.unlocked(State.get("BestCleared", 0))
		local here = atMachine()
		if not unlocked then
			headline.Text = `Reach {world.name} to unlock fusing`
		elseif not here then
			headline.Text = `Fuse at the Fusion Machine on the {world.name} island`
		else
			headline.Text = `Pick {Fuse.COUNT} of the same mini cannon and tier  •  the first pick keeps its enchantments`
		end

		for slot, button in slots do
			local id = picks[slot]
			local pet = id and Config.Pets[id]
			if pet then
				local carried = magic(id)
				local note = if carried ~= "" then (if slot == 1 then "✨ kept" else "✨ LOST") else "tap to remove"
				setButton(button, `{slot}. {Config.Pets[pet.plain].name}\n{note}`, if carried ~= "" and slot > 1 then Colors.red else Colors.gold)
			else
				setButton(button, if slot == 1 then "1. EMPTY\nkeeps its enchantments" else `{slot}. EMPTY`, Colors.grey)
			end
		end

		local result = if #picks == Fuse.COUNT then Fuse.result(picks) else nil
		local made = result and Config.Pets[result]
		if made then
			local tier = Config.FuseTiers[made.tier]
			resultLabel.Text = `= {made.name}\n{Format.petPower(made)}  •  {if tier then tier.perk else ""}`
			resultLabel.TextColor3 = if tier then tier.color else Colors.white
		elseif lastMade ~= "" and #picks == 0 then
			resultLabel.Text = lastMade
			resultLabel.TextColor3 = Colors.gold
		else
			resultLabel.Text = `Put in {Fuse.COUNT - #picks} more`
			resultLabel.TextColor3 = Colors.text
		end

		local first = picks[1]
		local carried = if first then magic(first) else ""
		if not first then
			keeps.Text = "The result keeps the enchantments of the FIRST mini cannon you pick."
		elseif carried ~= "" then
			keeps.Text = `The result keeps the first pick's enchantments: {carried}`
		else
			keeps.Text = "The first pick has no enchantments, so the result has none."
		end
		local lost = Fuse.lost(picks)
		if lost > 0 then
			local names = {}
			for slot = 2, #picks do
				local text = magic(picks[slot])
				if text ~= "" then
					table.insert(names, `pick {slot}: {text}`)
				end
			end
			warning.Text = `WARNING: these enchantments will be LOST for good  •  {table.concat(names, "  •  ")}`
		else
			warning.Text = ""
		end

		local ready = made ~= nil and unlocked and here
		if lost > 0 and os.clock() - armed <= CONFIRM_SECONDS then
			setButton(fuseButton, "LOSE THEM? PRESS AGAIN", Colors.red)
		else
			setButton(fuseButton, "FUSE", if ready then Colors.green else Colors.grey)
		end
		clearButton.BackgroundColor3 = if #picks > 0 then Colors.orange else Colors.grey
		refreshList(counts)
	end

	ctx.Windows.register(Fuse.WINDOW, window, refresh)

	-- The server's answer to a fusion: the machine is empty again, and says what came out.
	ctx.on("fuse", function(result)
		if typeof(result) ~= "table" or typeof(result.pet) ~= "string" then
			return
		end
		local made = Config.Pets[result.pet]
		table.clear(picks)
		armed = -math.huge
		lastMade = if made then `FUSED: {made.name}!` else ""
		if window.frame.Visible then
			refresh()
		end
	end)

	-- An armed button goes back by itself; walking off the island closes the machine's window.
	task.spawn(function()
		while true do
			if window.frame.Visible and armed > 0 and os.clock() - armed > CONFIRM_SECONDS then
				armed = -math.huge
				refresh()
			end
			task.wait(0.5)
		end
	end)
	local wasHere = false
	State.onChange(function()
		local here = atMachine()
		if window.frame.Visible and wasHere and not here then
			window.close()
		end
		wasHere = here
	end)
end

return { start = start }
