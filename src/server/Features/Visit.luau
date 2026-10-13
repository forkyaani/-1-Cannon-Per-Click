-- Visits. Every base stands alone (Layout.plotCFrame): a player gets onto somebody else's with VISIT, or by
-- being invited by its owner.
--   visitGo(user id)       the player goes to that owner's base at once, as a guest. Refused while the owner's
--                          Visitors switch (SETTINGS) is off, and for a while after the owner sent them home
--   visitInvite(user id)   the owner asks that player to come to their base. It lasts Rules.InviteSeconds and
--                          is declined by ignoring it. It works whatever the owner's Visitors switch says
--   visitJoin(user id)     the invited player accepts: they are moved onto that owner's base as a guest
--   visitKick(user id)     the owner sends one of their guests home
-- An owner who switches Visitors off has the guests who came uninvited sent home; the invited ones stay.
-- A guest goes home with their own BASE button (the core's goHome), and is sent home by the core when the
-- owner leaves the game. Where everybody is, is the core's place state (state.place == "visit", state.visit =
-- the host's slot): nothing is kept twice here, the guest list is read off it.
-- The client only asks: every user id it names is checked here, as in Trading.luau, and invitations are
-- rate-limited the same way (a gap between two, a wait before the same player is asked again, a cap on how
-- many one player can have waiting); so are visits (a gap between two, and the owner is told about the same
-- visitor only once in a while). A guest gets no rights on the base, invited or not: the pad actions only ever
-- touch the asking player's own save, and the core lets only the owner use a base's teleporters.
-- No player is asked for text and nothing here opens a way to talk: a visit shows a base, no more.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Features.Visit)

local Visit = {}

local WATCH_SECONDS = 0.4 -- how often, at most, waiting invitations and the guest lists are looked over
local MAX_USER_ID = 2 ^ 53 -- above this a number is no longer a whole user id

local Game -- the core's plug-in API, handed to start

local invites = {} -- waiting invitations, oldest first: { from = Player (the owner), to = Player, expires = time }
local lastAsked = {} -- [player] = when they last sent an invitation
local askAgain = {} -- ["owner id:guest id"] = when the owner may invite that player again
local shown = {} -- [player] = who was on their base, and whose base they were on, when they were last told
local lastVisit = {} -- [player] = when they last went to a base uninvited
local uninvited = {} -- [guest] = the slot of the base they went to without an invitation, while they are on it
local barred = {} -- ["owner id:guest id"] = when that guest, sent home, may come back uninvited
local told = {} -- ["owner id:guest id"] = when the owner may be told again that this player is visiting
local private = {} -- [player] = whether their Visitors switch was off when last looked at (the Private attribute)

-- Every time in here is the server clock the client reads too (State.now), so both show the same countdowns.
local function now(): number
	return workspace:GetServerTimeNow()
end

-- In the game with their base and save set up.
local function ready(player: Player): boolean
	return player.Parent ~= nil and Game.state(player) ~= nil and Game.data(player) ~= nil
end

-- The other player a client named by user id, if that is somebody else on this server.
local function named(player: Player, userId: unknown): Player?
	if typeof(userId) ~= "number" or userId ~= userId or userId % 1 ~= 0 or math.abs(userId) > MAX_USER_ID then
		return nil
	end
	local other = Players:GetPlayerByUserId(userId)
	return if other ~= player then other else nil
end

local function findInvite(from: Player, to: Player): number?
	for index, invite in invites do
		if invite.from == from and invite.to == to then
			return index
		end
	end
	return nil
end

-- The base this player owns, or nil (a server over capacity shares a base: its second owner cannot host).
local function ownSlot(player: Player): number?
	local state = Game.state(player)
	return if state and Game.owner(state.slot) == player then state.slot else nil
end

-- Whether this owner switched Visitors off (the Settings feature keeps it in their save; on by default).
local function isPrivate(player: Player): boolean
	local data = Game.data(player)
	local saved = if data and typeof(data.features) == "table" then data.features.settings else nil
	return typeof(saved) == "table" and saved[Rules.SETTING] == false
end

-- Whose base this player is a guest on right now, or nil.
local function hostOf(player: Player): Player?
	local state = Game.state(player)
	if not state or state.place ~= "visit" then
		return nil
	end
	return Game.owner(state.visit)
end

-- The world this owner's base is fighting in right now: the sky their guests are shown (client Effects).
local function worldOf(host: Player): number
	local data = Game.data(host)
	return (Config.worldOf(if data then data.wave else 1))
end

-- This player's guests, by name.
local function guestsOf(player: Player): { Player }
	local slot = ownSlot(player)
	local guests = if slot then Game.guests(slot) else {}
	table.sort(guests, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId
	end)
	return guests
end

----------------------------------------------------------------------------------------------------
-- What the client is shown: State.feature("visit")
----------------------------------------------------------------------------------------------------
-- Who is where, as far as this player's window shows it: a short text that changes when it does.
local function standing(player: Player): string
	local ids = {}
	for _, guest in guestsOf(player) do
		table.insert(ids, tostring(guest.UserId))
	end
	local host = hostOf(player)
	-- The host's world is part of it: a guest's sky follows the host into the next world.
	return `{if host then host.UserId else 0}|{if host then worldOf(host) else 0}|{table.concat(ids, ",")}`
end

local function publish(player: Player)
	if not ready(player) then
		return
	end
	local view = {
		nextAsk = (lastAsked[player] or 0) + Rules.InviteGapSeconds, -- when they may send an invitation again
		nextVisit = (lastVisit[player] or 0) + Rules.VisitGapSeconds, -- when they may go to a base again
		barred = {}, -- [user id] = when this player may visit that owner again (they were sent home)
		invites = {}, -- waiting for this player's answer: { id, name, expires }
		sent = {}, -- [user id] = when this player's own invitation to them runs out
		later = {}, -- [user id] = when this player may invite them again
		guests = {}, -- who is on this player's base: { id, name }
		-- host = { id, name, world }: whose base this player is on, while they are a guest, and its world
	}
	for _, invite in invites do
		if invite.to == player then
			table.insert(view.invites, { id = invite.from.UserId, name = invite.from.DisplayName, expires = invite.expires })
		elseif invite.from == player then
			view.sent[tostring(invite.to.UserId)] = invite.expires
		end
	end
	local asker = `{player.UserId}:`
	for pair, free in askAgain do
		if string.sub(pair, 1, #asker) == asker then
			view.later[string.sub(pair, #asker + 1)] = free
		end
	end
	local me = `:{player.UserId}`
	for pair, free in barred do
		if string.sub(pair, -#me) == me then
			view.barred[string.sub(pair, 1, #pair - #me)] = free
		end
	end
	for _, guest in guestsOf(player) do
		table.insert(view.guests, { id = guest.UserId, name = guest.DisplayName })
	end
	local host = hostOf(player)
	if host then
		(view :: any).host = { id = host.UserId, name = host.DisplayName, world = worldOf(host) }
	end
	shown[player] = standing(player)
	Game.setMeta(player, "visit", view)
end

-- Forgets every invitation to or from this player, and tells the players at the other end.
local function dropInvites(player: Player)
	for index = #invites, 1, -1 do
		local invite = invites[index]
		if invite.from == player or invite.to == player then
			table.remove(invites, index)
			publish(if invite.from == player then invite.to else invite.from)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------------------------------------
-- INVITE: asks that player to come to this player's base.
local function invite(player: Player, _data, _state, userId: unknown)
	local target = named(player, userId)
	if not target then
		return
	end
	local name = target.DisplayName
	local time = now()
	local pair = `{player.UserId}:{target.UserId}`
	local slot = ownSlot(player)
	local incoming, outgoing = 0, 0
	for _, other in invites do
		if other.to == target then
			incoming += 1
		end
		if other.from == player then
			outgoing += 1
		end
	end

	local trouble: string? = nil
	local targetState = Game.state(target)
	if not slot then
		trouble = "Your base cannot take visitors right now"
	elseif not ready(target) or not targetState then
		trouble = `{name} is still joining`
	elseif targetState.place == "visit" and targetState.visit == slot then
		trouble = `{name} is at your base already`
	elseif findInvite(player, target) then
		trouble = `{name} has not answered yet`
	elseif time < (askAgain[pair] or 0) then
		trouble = `You invited {name} a moment ago. Ask again later.`
	elseif time < (lastAsked[player] or 0) + Rules.InviteGapSeconds then
		trouble = "Slow down a little"
	elseif incoming >= Rules.MaxIncoming then
		trouble = `{name} has too many invitations right now`
	elseif outgoing >= Rules.MaxOutgoing then
		trouble = "Wait for your other invitations to be answered first"
	end
	if trouble then
		Game.notify(player, trouble, "bad")
		return
	end

	lastAsked[player] = time
	-- Whatever becomes of this invitation (ignored, run out), the same player is not asked again for a while
	-- after it: nobody can keep prompting someone who does not want to come.
	askAgain[pair] = time + Rules.InviteSeconds + Rules.AgainSeconds
	table.insert(invites, { from = player, to = target, expires = time + Rules.InviteSeconds })
	Game.notify(player, `Invitation sent to {name}`, "info")
	Game.notify(target, `{player.DisplayName} invited you to their base! Open VISIT to join.`, "good")
	publish(player)
	publish(target)
end

-- VISIT: goes to that owner's base at once, without an invitation.
local function go(player: Player, _data, state, userId: unknown)
	local host = named(player, userId)
	if not host then
		return
	end
	local name = host.DisplayName
	local time = now()
	local pair = `{host.UserId}:{player.UserId}`
	local slot = if ready(host) then ownSlot(host) else nil

	local trouble: string? = nil
	if not slot then
		trouble = `{name}'s base cannot take visitors right now`
	elseif state.place == "visit" and state.visit == slot then
		trouble = `You are at {name}'s base already`
	elseif isPrivate(host) then
		trouble = `{name}'s base is private`
	elseif time < (barred[pair] or 0) then
		trouble = `{name} sent you home. Try again later.`
	elseif time < (lastVisit[player] or 0) + Rules.VisitGapSeconds then
		trouble = "Slow down a little"
	end
	if trouble or not slot then
		Game.notify(player, trouble or "", "bad")
		return
	end

	lastVisit[player] = time
	-- Marked before the move: the core changes where they are at once, and may then wait for the base to stream in.
	uninvited[player] = slot
	if Game.setPlace(player, "visit", slot) then
		Game.notify(player, `Welcome to {name}'s base! Press BASE to go home.`, "good")
		-- A player hopping in and out does not fill the owner's corner with toasts.
		if host.Parent and time >= (told[pair] or 0) then
			told[pair] = time + Rules.NoticeSeconds
			Game.notify(host, `{player.DisplayName} is visiting your base`, "good")
		end
	else
		uninvited[player] = nil
		Game.notify(player, `Could not get to {name}'s base`, "bad")
	end
	publish(player)
	publish(host)
end

-- JOIN: accepts that owner's invitation and moves this player onto their base.
local function join(player: Player, _data, _state, userId: unknown)
	local host = named(player, userId)
	if not host then
		return
	end
	local index = findInvite(host, player)
	if not index then
		Game.notify(player, `{host.DisplayName}'s invitation has run out`, "bad")
		return
	end
	local invitation = table.remove(invites, index)
	local slot = ownSlot(host)
	if now() >= invitation.expires or not ready(host) or not slot then
		Game.notify(player, `{host.DisplayName}'s invitation has run out`, "bad")
		publish(player)
		publish(host)
		return
	end
	-- The owner may ask them again as soon as this visit is over.
	askAgain[`{host.UserId}:{player.UserId}`] = nil
	uninvited[player] = nil -- an invited guest stays when the owner switches Visitors off
	-- The core moves them, and refuses when the base has no owner any more. It may wait for the base to stream in.
	if Game.setPlace(player, "visit", slot) then
		Game.notify(player, `Welcome to {host.DisplayName}'s base! Press BASE to go home.`, "good")
		if host.Parent then
			Game.notify(host, `{player.DisplayName} is visiting your base`, "good")
		end
	else
		Game.notify(player, `Could not get to {host.DisplayName}'s base`, "bad")
	end
	publish(player)
	publish(host)
end

-- SEND HOME: the owner sends one of their guests back to the guest's own base.
local function kick(player: Player, _data, _state, userId: unknown)
	local guest = named(player, userId)
	local slot = ownSlot(player)
	local guestState = if guest then Game.state(guest) else nil
	if not guest or not slot or not guestState or guestState.place ~= "visit" or guestState.visit ~= slot then
		return
	end
	if Game.setPlace(guest, "plot") then
		-- Sent home means stay away for a while: only the owner's invitation brings them back sooner.
		barred[`{player.UserId}:{guest.UserId}`] = now() + Rules.KickedSeconds
		uninvited[guest] = nil
		Game.notify(guest, `{player.DisplayName} sent you home`, "info")
		Game.notify(player, `{guest.DisplayName} went home`, "info")
	end
	publish(guest)
	publish(player)
end

----------------------------------------------------------------------------------------------------
-- The Visitors switch
----------------------------------------------------------------------------------------------------
-- Every client reads who is private off the Player attribute (the VISIT button is greyed); the server's own
-- answer is always the save's (isPrivate). Switched off, the guests who walked in are sent home.
local function privacy(player: Player)
	if not ready(player) then
		return
	end
	local off = isPrivate(player)
	if private[player] == off then
		return
	end
	private[player] = off
	player:SetAttribute(Rules.PRIVATE, off)
	local slot = ownSlot(player)
	if not off or not slot then
		return
	end
	for _, guest in Game.guests(slot) do
		if uninvited[guest] == slot then
			uninvited[guest] = nil
			-- The move may wait for the guest's own base to stream in: the watch is not held up for it.
			task.spawn(function()
				if Game.setPlace(guest, "plot") then
					Game.notify(guest, `{player.DisplayName}'s base is private now, so you are back at your own`, "info")
				end
				publish(guest)
				publish(player)
			end)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Keeping watch
----------------------------------------------------------------------------------------------------
local function watch()
	local time = now()
	for index = #invites, 1, -1 do
		local waiting = invites[index]
		local expired = time >= waiting.expires
		if expired or not ready(waiting.from) or not ready(waiting.to) then
			table.remove(invites, index)
			if expired and ready(waiting.from) then
				Game.notify(waiting.from, `{waiting.to.DisplayName} did not answer your invitation`, "info")
			end
			publish(waiting.from)
			publish(waiting.to)
		end
	end
	for _, list in { askAgain, barred, told } do
		for pair, free in list do
			if time >= free then
				list[pair] = nil
			end
		end
	end
	-- A guest who went home (BASE, a respawn, the owner leaving) is nobody's uninvited guest any more.
	for guest, slot in uninvited do
		local state = if guest.Parent then Game.state(guest) else nil
		if not state or state.place ~= "visit" or state.visit ~= slot then
			uninvited[guest] = nil
		end
	end
	-- Guests come and go without an action of this feature (BASE, a respawn, the owner leaving): whoever's
	-- window would show something else now is told.
	for _, player in Players:GetPlayers() do
		privacy(player)
		if ready(player) and shown[player] ~= standing(player) then
			publish(player)
		end
	end
end

local function depart(player: Player)
	dropInvites(player)
	lastAsked[player], shown[player] = nil, nil
	lastVisit[player], uninvited[player], private[player] = nil, nil, nil
	-- `barred` and `told` are left to run out: leaving and joining again is no way back onto a base, nor a way
	-- to have the owner told again.
	local mine = `{player.UserId}:`
	for pair in askAgain do
		if string.sub(pair, 1, #mine) == mine then
			askAgain[pair] = nil
		end
	end
end

function Visit.start(api)
	Game = api
	Game.actions.visitInvite = invite
	Game.actions.visitJoin = join
	Game.actions.visitKick = kick
	Game.actions.visitGo = go

	Game.on("ready", function(player: Player)
		privacy(player)
		publish(player)
	end)
	-- A press on the Visitors switch counts at once, not at the next look of the watch.
	Game.on("acted", function(player: Player, _data, _state, name: string)
		if name == "settingToggle" then
			privacy(player)
		end
	end)
	Game.on("leave", depart)

	-- The watch rides on the core's `tick` hook (twice a second for every player): once per WATCH_SECONDS,
	-- whoever's tick comes first. With nobody in the game there is nothing to watch.
	local watched = 0
	Game.on("tick", function()
		local time = os.clock()
		if time - watched >= WATCH_SECONDS then
			watched = time
			watch()
		end
	end)
end

return Visit
