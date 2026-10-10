-- Playtime gifts, client side: the GIFTS window. One row a gift: how long to play today, what it pays, and a
-- button that counts down, then says CLAIM. The server counts the time and pays
-- (src/server/Features/Gifts.luau); this window counts on from what it was last told, so nothing is sent
-- every second. Under the gifts: the friend bonus, as the server says it stands.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gifts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Gifts"))

local ROW_HEIGHT = 70

local function start(ctx)
	local State, UI, Format, Items = ctx.State, ctx.UI, ctx.Format, ctx.Items
	local Colors = UI.Colors

	local window = UI.window(Gifts.WINDOW, 560, 150 + (#Gifts.List + 1) * (ROW_HEIGHT + 8))
	local list = UI.scroll(window.body, { Size = UDim2.fromScale(1, 1) })

	-- Seconds played today, counted on from the server's last word.
	local function played(): number
		local meta = State.feature("gifts")
		if typeof(meta.seconds) ~= "number" or typeof(meta.at) ~= "number" then
			return 0
		end
		return meta.seconds + math.max(0, State.now() - meta.at)
	end
	local function claimed(index: number): boolean
		local meta = State.feature("gifts")
		return typeof(meta.claimed) == "table" and meta.claimed[tostring(index)] == true
	end
	local function itemName(id: string): string
		local def = Items.get(id)
		return if def then def.name else id
	end

	local rows = {}
	for index, gift in Gifts.List do
		local row = UI.row(list, ROW_HEIGHT, index)
		row.icon.BackgroundColor3 = Colors.green
		row.setIcon("gift")
		row.title.Text = `Play {gift.minutes} minutes`
		row.sub.Text = Gifts.rewardText(gift, itemName)
		row.button.Activated:Connect(function()
			ctx.act("giftClaim", index)
		end)
		rows[index] = row
	end
	local friendRow = UI.row(list, ROW_HEIGHT, #Gifts.List + 1)
	friendRow.icon.BackgroundColor3 = Colors.gold
	friendRow.setIcon("heart")
	friendRow.title.Text = "Friend bonus"
	friendRow.button.Visible = false
	friendRow.title.Size = UDim2.new(1, -70, 0, 26)
	friendRow.sub.Size = UDim2.new(1, -70, 0, ROW_HEIGHT - 40)

	local function refresh()
		local seconds = played()
		for index, gift in Gifts.List do
			local row = rows[index]
			local left = gift.minutes * 60 - seconds
			local text, color
			if claimed(index) then
				text, color = "CLAIMED", Colors.grey
			elseif left <= 0 then
				text, color = "CLAIM", Colors.green
			else
				text, color = Format.duration(math.ceil(left)), Colors.grey
			end
			if row.button.Text ~= text then
				row.button.Text = text
			end
			row.button.BackgroundColor3 = color
		end
		local friends = State.feature("friends")
		local count = if typeof(friends.count) == "number" then friends.count else 0
		local percent = math.floor(Gifts.FRIEND_COINS * 100 + 0.5)
		friendRow.sub.Text = if count > 0
			then `{count} friend{if count == 1 then "" else "s"} here: +{count * percent}% coins right now`
			else `+{percent}% coins for every friend playing on your server (up to {Gifts.FRIEND_MAX})`
	end

	ctx.Windows.register(Gifts.WINDOW, window, refresh)
	ctx.Hud.addMenuButton(Gifts.WINDOW, Color3.fromRGB(95, 224, 58), 9, window.toggle)
	-- "!" on the button while a gift waits.
	ctx.flag(Gifts.WINDOW, function(): boolean
		local seconds = played()
		for index, gift in Gifts.List do
			if seconds >= gift.minutes * 60 and not claimed(index) then
				return true
			end
		end
		return false
	end)
	State.onChange(refresh)
	refresh()
end

return { start = start }
