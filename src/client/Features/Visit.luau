-- Visits, client side: the VISIT window (menu button VISIT, in the MORE drawer) and a small card when an
-- invitation arrives. Bases are private, so this is the only way onto somebody else's: the window lists the
-- other players on the server, each with INVITE (ask them to come to my base) and, while that player's own
-- invitation to me is waiting, JOIN. A player who is on my base has SEND HOME instead of INVITE; a guest goes home
-- with GO HOME here or with the BASE menu button. The server decides everything
-- (src/server/Features/Visit.luau); this only shows what it published as State.feature("visit") and asks.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Visit"))

local player = Players.LocalPlayer

local ROW_HEIGHT = 64
local HEADER_HEIGHT = 58
local TICK_SECONDS = 0.5 -- the countdowns

local Feature = {}

function Feature.start(ctx)
	local State, UI = ctx.State, ctx.UI
	local Colors = UI.Colors
	local left = Enum.TextXAlignment.Left

	local window = UI.window(Rules.WINDOW, 640, 480)
	-- The line over the list: where the player is, and the way home while they are a guest.
	local statusLabel = UI.text({
		Size = UDim2.new(1, -170, 0, HEADER_HEIGHT - 12),
		Position = UDim2.fromOffset(6, 2),
		TextXAlignment = left,
		TextWrapped = true,
		TextColor3 = Colors.text,
		MaxSize = 18,
		Parent = window.body,
	})
	local homeButton = UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 2),
		Size = UDim2.fromOffset(150, 46),
		Text = "GO HOME",
		BackgroundColor3 = Colors.orange,
		Visible = false,
		Parent = window.body,
	})
	homeButton.Activated:Connect(function()
		ctx.act("goHome")
	end)
	local list = UI.scroll(window.body, { Position = UDim2.fromOffset(0, HEADER_HEIGHT), Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT) })
	local nobodyLabel = UI.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(1, -80, 0, 70),
		TextColor3 = Colors.text,
		TextWrapped = true,
		MaxSize = 20,
		Text = "Nobody else is on this server right now.\nWhen a friend joins, invite them to your base here!",
		Parent = window.body,
	})

	local function setButton(button: TextButton, text: string, color: Color3)
		button.Text = text
		button.BackgroundColor3 = color
	end

	local rows = {} -- [user id] = row
	local function playerRow(other: Player)
		local id = other.UserId
		local row = UI.row(list, ROW_HEIGHT, 0)
		-- Narrower text: a second button sits beside the main one.
		row.title.Size = UDim2.new(1, -338, 0, 26)
		row.sub.Size = UDim2.new(1, -338, 0, 22)
		row.icon.BackgroundColor3 = Color3.fromHSV(id % 360 / 360, 0.55, 0.95)
		-- The main button invites them, or sends them home while they are on my base. The second one is JOIN,
		-- while their own invitation waits.
		row.second = UI.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -150, 0.5, 0),
			Size = UDim2.fromOffset(120, ROW_HEIGHT - 18),
			Text = "JOIN",
			BackgroundColor3 = Colors.green,
			Visible = false,
			Parent = row.frame,
		})
		row.guest = false -- whether they are on my base right now
		row.button.Activated:Connect(function()
			ctx.act(if row.guest then "visitKick" else "visitInvite", id)
		end)
		row.second.Activated:Connect(function()
			ctx.act("visitJoin", id)
		end)
		rows[id] = row
		return row
	end

	local function refresh()
		local info = State.feature("visit")
		local time = State.now()
		local inviting = {} -- [user id] = the invitation that player has waiting here
		for _, invitation in info.invites or {} do
			if typeof(invitation) == "table" and (invitation.expires or 0) > time then
				inviting[invitation.id] = invitation
			end
		end
		local guests = {} -- [user id] = true for whoever is on my base
		for _, guest in info.guests or {} do
			guests[guest.id] = true
		end
		local host = info.host
		homeButton.Visible = host ~= nil
		if host then
			statusLabel.Text = `You are visiting {host.name}'s base. Your own base keeps fighting.`
		elseif next(guests) then
			statusLabel.Text = "Players on your base are listed first. SEND HOME takes one back to their own base."
		else
			statusLabel.Text = `Bases are private. INVITE a player to show them yours: they have {Rules.InviteSeconds}s to join.`
		end

		local others = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				table.insert(others, other)
			end
		end
		-- My guests first, then whoever invited me, then by name.
		local function rank(other: Player): number
			return if guests[other.UserId] then 0 elseif inviting[other.UserId] then 1 else 2
		end
		table.sort(others, function(a: Player, b: Player): boolean
			local rankA, rankB = rank(a), rank(b)
			if rankA ~= rankB then
				return rankA < rankB
			end
			local nameA, nameB = string.lower(a.DisplayName), string.lower(b.DisplayName)
			if nameA ~= nameB then
				return nameA < nameB
			end
			return a.UserId < b.UserId
		end)

		local canAsk = (info.nextAsk or 0) <= time
		local sent, later = info.sent or {}, info.later or {}
		local shown = {}
		for order, other in others do
			local id = other.UserId
			local row = rows[id] or playerRow(other)
			local invitation = inviting[id]
			local sentUntil, askAt = sent[tostring(id)], later[tostring(id)]
			shown[id] = true
			row.frame.LayoutOrder = order
			row.title.Text = other.DisplayName
			row.title.TextColor3 = if invitation then Colors.gold else Colors.white

			local detail = `@{other.Name}`
			if guests[id] then
				detail ..= "  •  on your base"
			elseif invitation then
				detail ..= "  •  invited you to their base!"
			elseif host and host.id == id then
				detail ..= "  •  you are on their base"
			end
			row.sub.Text = detail

			row.second.Visible = invitation ~= nil
			if invitation then
				setButton(row.second, `JOIN\n{math.max(1, math.ceil(invitation.expires - time))}s`, Colors.green)
			end
			row.guest = guests[id] == true
			if row.guest then
				setButton(row.button, "SEND\nHOME", Colors.red)
			elseif sentUntil and sentUntil > time then
				setButton(row.button, `INVITED\n{math.ceil(sentUntil - time)}s`, Colors.grey)
			elseif askAt and askAt > time then
				setButton(row.button, `AGAIN IN\n{math.ceil(askAt - time)}s`, Colors.grey)
			else
				setButton(row.button, "INVITE", if canAsk then Colors.blue else Colors.grey)
			end
		end
		for id, row in rows do
			if not shown[id] then
				row.frame:Destroy()
				rows[id] = nil
			end
		end
		nobodyLabel.Visible = #others == 0
	end

	ctx.Windows.register(Rules.WINDOW, window, refresh)
	-- Order 14: in the MORE drawer, in both views (a guest opens it from the host's base too).
	ctx.Hud.addMenuButton(Rules.WINDOW, Color3.fromRGB(70, 200, 150), 14, window.toggle)

	-- An invitation that is still good: the oldest one first.
	local function waiting()
		local time = State.now()
		for _, invitation in State.feature("visit").invites or {} do
			if typeof(invitation) == "table" and (invitation.expires or 0) > time then
				return invitation, invitation.expires - time
			end
		end
		return nil, 0
	end
	-- "!" while somebody's invitation waits.
	ctx.flag(Rules.WINDOW, function(): boolean
		return waiting() ~= nil
	end)

	------------------------------------------------------------------------------------------------
	-- The invitation card: who is asking, the seconds left, JOIN. There is no "no": it goes away by itself.
	------------------------------------------------------------------------------------------------
	local cardText = UI.label({
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -150, 1, 0),
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = left,
		TextColor3 = Colors.ink,
		Stroke = 0,
	})
	local cardJoin = UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(116, 46),
		Text = "JOIN",
		BackgroundColor3 = Colors.green,
	})
	local card = UI.slot({ Name = "VisitInvite", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(460, 64), Visible = false, ZIndex = 20 }, {
		UI.chip({ Size = UDim2.fromScale(1, 1), Active = true }, { cardText, cardJoin }),
	})
	-- Under the toast line and the level banner.
	ctx.Hud.onLayout(function(layout)
		card.Position = UDim2.new(0.5, 0, 0, layout.toast + 136)
	end)
	local cardFrom: number? = nil
	cardJoin.Activated:Connect(function()
		if cardFrom then
			ctx.act("visitJoin", cardFrom)
		end
	end)

	local function refreshCard()
		local invitation, seconds = waiting()
		-- The window lists the same invitation itself.
		card.Visible = invitation ~= nil and not window.frame.Visible
		if invitation and card.Visible then
			cardFrom = invitation.id
			cardText.Text = `🏰 {invitation.name} invited you to their base  ({math.ceil(seconds)}s)`
		end
	end

	State.onChange(refreshCard)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			refreshCard()
			if window.frame.Visible then
				refresh()
			end
		end
	end)

	------------------------------------------------------------------------------------------------
	-- A base's teleporters are its owner's (the server refuses anybody else): a guest is not offered them.
	------------------------------------------------------------------------------------------------
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local slot = prompt:GetAttribute("Slot")
		local mine = State.get("Slot", nil)
		if prompt:GetAttribute("Teleporter") ~= nil and mine ~= nil and slot ~= mine then
			prompt.Enabled = false
		end
	end)
end

return Feature
