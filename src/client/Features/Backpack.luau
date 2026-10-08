-- The backpack window: every stackable item the player owns, with USE on the usable ones, and under them
-- the Robux powerup bundles. The items come from State.feature("items") and are described by the shared
-- Items registry and grouped by their category, so other features' items (ammo, crates ...) appear here
-- without this file knowing them. Only powerups get something extra: their running time and the bundles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Powerups = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Powerups"))

local NAME = "BACKPACK" -- the window's title, its menu button, and the name it opens by
local ROW_HEIGHT = 70
local BUNDLE_HEIGHT = 76 -- room for two lines of contents
local BUNDLES_ORDER = 100_000 -- the bundles sit below every item row
local TICK_SECONDS = 0.5 -- how often a running powerup's time left is rewritten while the window is open
-- Headings for the categories known today. Any other category is headed by its own name.
local TITLES = { powerup = "POWERUPS", ammo = "AMMO", crate = "CRATES" }

local Backpack = {}

function Backpack.start(ctx)
	local Config, Format, Items, State, UI = ctx.Config, ctx.Format, ctx.Items, ctx.State, ctx.UI
	local Colors = UI.Colors

	local window = UI.window(NAME, 640, 460)
	local list = UI.scroll(window.body)
	local emptyLabel = UI.text({
		Size = UDim2.new(1, -10, 0, 40),
		LayoutOrder = 0,
		TextColor3 = Colors.text,
		TextWrapped = true,
		MaxSize = 16,
		Text = "Nothing in here yet. Bosses drop powerups. First clears of boss levels, daily rewards and the shop give them too.",
		Parent = list,
	})

	-- [item id] = its row. Built the first time the item is seen and kept, so a USE button never moves or
	-- vanishes under a finger: a used-up item stays listed (x0) until the window is closed.
	local rows = {}
	local headers = {} -- [category] = its heading
	local seen = {} -- [item id] = how many the player had when they last looked in here

	local function addRow(id: string, def)
		local row = UI.row(list, ROW_HEIGHT, 0)
		-- Definitions come from other features too, so no field is trusted to be filled in.
		row.name = def.name or id
		row.desc = def.desc or ""
		row.category = def.category or "other"
		row.order = def.order or math.huge
		row.powerup = if table.find(Powerups.List, def) then def else nil
		row.icon.BackgroundColor3 = def.color or Colors.white
		row.setIcon(id)
		-- White for an item without a rarity, or with one this build has no colour for.
		row.title.TextColor3 = Config.RarityColors[def.rarity] or Colors.white
		row.button.Visible = def.usable == true
		row.button.Activated:Connect(function()
			ctx.act("useItem", id)
		end)
		rows[id] = row
	end

	-- Orders the headings and the rows under them: powerups first, then the other categories by name;
	-- inside a category by the items' own order, then by name.
	local function arrange()
		local groups, categories = {}, {}
		for _, row in rows do
			if row.frame.Visible then
				if not groups[row.category] then
					groups[row.category] = {}
					table.insert(categories, row.category)
				end
				table.insert(groups[row.category], row)
			end
		end
		table.sort(categories, function(a: string, b: string): boolean
			if (a == "powerup") ~= (b == "powerup") then
				return a == "powerup"
			end
			return a < b
		end)
		for category, header in headers do
			header.Visible = groups[category] ~= nil
		end
		local order = 0
		for _, category in categories do
			if not headers[category] then
				headers[category] = UI.header(list, 0)
				headers[category].Text = TITLES[category] or string.upper(category)
			end
			order += 1
			headers[category].LayoutOrder = order
			table.sort(groups[category], function(a, b): boolean
				if a.order ~= b.order then
					return a.order < b.order
				end
				return a.name < b.name
			end)
			for _, row in groups[category] do
				order += 1
				row.frame.LayoutOrder = order
			end
		end
		emptyLabel.Visible = order == 0
	end

	-- GET MORE: one row per Robux bundle, built once.
	UI.header(list, BUNDLES_ORDER).Text = "GET MORE POWERUPS"
	local bundleRows = {}
	for index, bundle in Powerups.Bundles do
		local contents = {}
		for _, entry in bundle.items do
			table.insert(contents, `{Items.get(entry[1]).name} x{entry[2]}`)
		end
		local row = UI.row(list, BUNDLE_HEIGHT, BUNDLES_ORDER + index)
		row.icon.BackgroundColor3 = Colors.gold
		row.setIcon("gift")
		row.title.Text = bundle.name
		row.sub.Text = table.concat(contents, "  •  ")
		if bundle.product == 0 then
			row.button.Text = "NOT ON\nSALE YET"
		else
			row.button.Text = `{bundle.price} R$`
			row.button.BackgroundColor3 = Colors.green
		end
		row.button.Activated:Connect(function()
			ctx.act("buyPowerups", bundle.id)
		end)
		bundleRows[bundle.id] = row
	end

	local function refresh()
		local items = State.feature("items")
		local boosts = State.meta.boosts or {}
		local now = State.now()
		local moved = false
		-- Looked up now rather than when this file loaded: a feature that starts later defines its items later.
		for id in items do
			local def = Items.get(id)
			if def and not rows[id] then
				addRow(id, def)
				moved = true
			end
		end
		for id, row in rows do
			local count = items[id] or 0
			if count > 0 and not row.frame.Visible then
				row.frame.Visible = true
				moved = true
			end
			local status, label, ready = "", "USE", count > 0
			if row.powerup then
				local left = Powerups.timeLeft(row.powerup, boosts, now)
				if left > 0 then
					status = `\nON  •  {Format.duration(left)} left`
				end
				if Powerups.isFull(row.powerup, boosts, now) then
					label, ready = "FULL", false
				end
			end
			row.title.Text = `{row.name}  x{count}`
			row.sub.Text = row.desc .. status
			row.button.Text = label
			row.button.BackgroundColor3 = if ready then Colors.green else Colors.grey
		end
		if moved then
			arrange()
		end
		seen = table.clone(items)

		local eventLive = (State.meta.event or {}).active == true
		for _, bundle in Powerups.Bundles do
			if bundle.event then
				bundleRows[bundle.id].frame.Visible = eventLive
			end
		end
	end

	ctx.Windows.register(NAME, window, refresh)
	local menuButton = ctx.Hud.addMenuButton(NAME, Color3.fromRGB(160, 110, 70), 10, window.toggle)
	-- "!" while the player holds usable items they have not looked at in here: after joining that is all of
	-- them, later only what they have gained since.
	ctx.flag(NAME, function(): boolean
		for id, count in State.feature("items") do
			local def = Items.get(id)
			if def and def.usable and count > (seen[id] or 0) then
				return true
			end
		end
		return false
	end)

	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.frame.Visible then
			-- Everything in here has been seen now: the "!" goes at once, not at the next state change.
			menuButton.Text = NAME
			return
		end
		-- Closing the window is when used-up items leave the list: nothing can be mid-press then.
		local items = State.feature("items")
		for id, row in rows do
			if (items[id] or 0) == 0 then
				row.frame.Visible = false
			end
		end
		arrange()
	end)

	-- A boost's time left changes without any state change, so the open window is refreshed on a timer too.
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			if window.frame.Visible then
				refresh()
			end
		end
	end)
end

return Backpack
