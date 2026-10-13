-- Visiting anybody's base (docs/RELEASE_TASKS.md, AD1): VISIT takes a player to another player's base at once,
-- the owner's Visitors switch (SETTINGS) closes the base to everyone they did not invite, SEND HOME keeps a
-- guest away for a while, and a guest, invited or not, changes nothing but their own save.
-- Run with: python3 run.py --all-features tests/visit.luau
local T = harness.load("_prelude.luau")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Game, Layout, Plots = T.Game, T.Layout, T.Plots
local check, eq = T.check, T.eq
local Rules = require(ReplicatedStorage.Shared.Features.Visit)
local Settings = require(ReplicatedStorage.Shared.Features.Settings)

local host, hostData, hostState = T.player, T.data, T.state
local guest = harness.addPlayer("Guest", 2)
local third = harness.addPlayer("Third", 3)
harness.flush()
local guestData, guestState = Game.data(guest), Game.state(guest)
local thirdState = Game.state(third)
assert(guestData and guestState and thirdState, "the other players did not load")
T.release(guest)
T.release(third)

-- A client request from `who`.
local function as(who: Player, name: string, argument: any?)
	harness.actAs(who)
	T.act(name, argument)
end
local function view(who: Player)
	return HttpService:JSONDecode(who:GetAttribute("Meta_visit"))
end
local function toasted(text: string, since: number): number
	local count = 0
	for index = since + 1, #T.toasts do
		if string.find(T.toasts[index].text, text, 1, true) then
			count += 1
		end
	end
	return count
end
-- Past the gap between two visits.
local function rested()
	harness.advance(Rules.VisitGapSeconds + 1)
end
local function home(who: Player)
	as(who, "goHome")
	eq(Game.state(who).place, "plot", `{who.Name} is at home`)
end

T.section("the rules and the switch")
check(Rules.VisitGapSeconds > 0 and Rules.KickedSeconds > Rules.VisitGapSeconds and Rules.NoticeSeconds > 0, "visits have a gap, a wait after SEND HOME and a limit on telling the owner")
eq(Settings.SAVED[Rules.SETTING], true, "Visitors is a saved setting, on by default")
local listed = false
for _, switch in Settings.Switches do
	listed = listed or (switch.key == Rules.SETTING and switch.title == "Visitors")
end
check(listed, "and a switch of the SETTINGS window")
eq(HttpService:JSONDecode(host:GetAttribute("Meta_settings")).visitors, true, "the client is told it is on")
for _, who in { host, guest, third } do
	eq(who:GetAttribute(Rules.PRIVATE), false, `{who.Name} is not private`)
end
check(hostState.slot ~= guestState.slot and guestState.slot ~= thirdState.slot and hostState.slot ~= thirdState.slot, "three players, three bases")

T.section("who can be visited")
local since = #T.toasts
for name, bad in { self = 2, absent = 999, text = "1", fraction = 1.5, nan = 0 / 0, infinity = math.huge, huge = 2 ^ 60, negative = -1, zero = 0, table = { 1 }, boolean = true } do
	as(guest, "visitGo", bad)
	if guestState.place ~= "plot" or guestState.visit ~= 0 then
		error(`CHECK FAILED: a bad id ({name}) started a visit`)
	end
end
as(guest, "visitGo", nil)
eq(guestState.place, "plot", "yourself, an absent player, text, a fraction, NaN, infinity, a huge number and nothing are refused")
eq(toasted("is visiting your base", since), 0, "and nobody is told of a visit")
check(view(guest).nextVisit <= harness.now(), "a refused visit does not use up the gap")

T.section("VISIT takes the player there at once")
since = #T.toasts
as(guest, "visitGo", 1)
eq(guestState.place, "visit", "the visitor is a guest")
eq(guestState.visit, hostState.slot, "on the host's base")
eq(guest:GetAttribute("Visiting"), hostState.slot, "the Visiting attribute")
eq(hostState.place, "plot", "the host stays where they are")
eq(#view(guest).invites, 0, "no invitation was needed")
eq(toasted("Guest is visiting your base", since), 1, "the host is told who came, as a notification")
eq(toasted("Welcome to Tester's base", since), 1, "and the visitor is welcomed")
T.run(1)
eq(view(host).guests[1].id, 2, "the host's window lists the guest")
eq(view(guest).host.id, 1, "and the guest's says whose base it is")
as(guest, "visitGo", 1)
eq(toasted("is visiting your base", since), 1, "visiting the base you are on does nothing")

T.section("a guest who came uninvited has no rights")
do
	as(host, "setPaused", true)
	guestData.coins = 1e9
	local function hostSave(): string
		return HttpService:JSONEncode({ hostData.pads, hostData.towers, hostData.coins, hostData.diamonds, hostData.features.settings })
	end
	local save = hostSave()
	local towers = HttpService:JSONEncode(Plots.towers[hostState.slot])
	local pads = HttpService:JSONEncode(Plots.pads[hostState.slot])
	local free = nil
	for pad = 2, Layout.PAD_COUNT do
		if not table.find(hostData.pads, pad) and not table.find(guestData.pads, pad) then
			free = pad
			break
		end
	end
	assert(free, "no pad to buy")
	as(guest, "buyPad", free)
	as(guest, "buildTower", { pad = free, kind = "cannon" })
	as(guest, "upgradeTower", { pad = free, levels = 10 })
	as(guest, "upgradeTower", { pad = 1, levels = 10 })
	as(guest, "sellTower", 1)
	as(guest, "setPaused", true)
	as(guest, "setPaused", false)
	as(guest, "settingToggle", "music")
	eq(hostSave(), save, "a guest's pad, tower and settings actions leave the host's save alone")
	eq(HttpService:JSONEncode(Plots.towers[hostState.slot]), towers, "and the host's towers")
	eq(HttpService:JSONEncode(Plots.pads[hostState.slot]), pads, "and the host's pads")
	eq(hostState.paused, true, "a guest cannot pause or resume the host's plot")
	check(table.find(guestData.pads, free) ~= nil and Plots.towers[guestState.slot][free] ~= nil, "they land on the guest's own base")
	eq(guestData.features.settings.music, false, "as does their own setting")
	eq(host:GetAttribute(Rules.PRIVATE), false, "a guest's press on a switch is not the host's")
	as(host, "setPaused", false)
	-- The base's teleporters are the owner's.
	since = #T.toasts
	local opened = 0
	local connection = T.Remotes.Feature.OnClientEvent:Connect(function(channel: string)
		if channel == "window" then
			opened += 1
		end
	end)
	harness.advance(0.1)
	harness.fire(Plots.marketPrompts[hostState.slot], "Triggered", guest)
	harness.advance(0.1)
	harness.fire(Plots.worldsPrompts[hostState.slot], "Triggered", guest)
	connection:Disconnect()
	check(guestState.place == "visit" and guestState.visit == hostState.slot and opened == 0, "a guest cannot use the host's teleporters")
	eq(toasted("Only the owner of this base", since), 2, "and is told so")
	-- Nor can a guest send anybody anywhere.
	as(guest, "visitKick", 1)
	eq(hostState.place, "plot", "a guest cannot send the host away")
	-- Their own base keeps fighting.
	local clock = guestState.clock
	T.run(10)
	check(guestState.clock > clock + 8, "the guest's own base keeps fighting meanwhile")
end

T.section("the gap between two visits, and what the host is told")
since = #T.toasts
home(guest)
rested()
as(guest, "visitGo", 1)
eq(guestState.place, "visit", "a second visit")
home(guest)
as(guest, "visitGo", 1)
eq(guestState.place, "plot", "straight back in is refused")
eq(toasted("Slow down", since), 1, "and the visitor is told to slow down")
check(view(guest).nextVisit > harness.now(), "the window knows when they may go again")
rested()
as(guest, "visitGo", 1)
eq(guestState.place, "visit", "after the gap they can")
for _ = 1, 3 do
	home(guest)
	rested()
	as(guest, "visitGo", 1)
end
eq(guestState.place, "visit", "hopping in and out works")
eq(toasted("is visiting your base", since), 0, "but the host is not told again and again")
home(guest)
harness.advance(Rules.NoticeSeconds + 1)
as(guest, "visitGo", 1)
eq(toasted("Guest is visiting your base", since), 1, "after a while the host is told once more")
since = #T.toasts
as(third, "visitGo", 1)
eq(thirdState.visit, hostState.slot, "a second visitor comes too")
eq(toasted("Third is visiting your base", since), 1, "and the host is told about them")
T.run(1)
eq(#view(host).guests, 2, "the host sees both guests")
home(third)

T.section("SEND HOME, and no way straight back")
since = #T.toasts
as(third, "visitKick", 2)
eq(guestState.place, "visit", "only the owner sends a guest home")
as(host, "visitKick", 2)
eq(guestState.place, "plot", "SEND HOME takes the guest to their own base")
eq(toasted("sent you home", since), 1, "and tells them")
check((view(guest).barred["1"] or 0) > harness.now() + Rules.KickedSeconds - 5, "the guest's window knows how long they are kept away")
rested()
since = #T.toasts
as(guest, "visitGo", 1)
eq(guestState.place, "plot", "the guest cannot come straight back uninvited")
eq(toasted("Try again later", since), 1, "and is told to try later")
as(guest, "visitGo", 3)
eq(guestState.visit, thirdState.slot, "somebody else's base is still open to them")
home(guest)
-- The owner's invitation overrules it.
harness.advance(Rules.InviteGapSeconds + 1)
as(host, "visitInvite", 2)
eq(#view(guest).invites, 1, "the owner can invite the guest they sent home")
as(guest, "visitJoin", 1)
eq(guestState.visit, hostState.slot, "and the invitation brings them back")
home(guest)
rested()
as(guest, "visitGo", 1)
eq(guestState.place, "plot", "uninvited they are still kept away")
T.run(Rules.KickedSeconds + 2)
as(guest, "visitGo", 1)
eq(guestState.visit, hostState.slot, "until the wait is over")
check(view(guest).barred["1"] == nil, "and the window forgets it")

T.section("Visitors off: a private base")
-- The guest is on the base uninvited; the third player comes by invitation.
harness.advance(Rules.InviteGapSeconds + 1)
as(host, "visitInvite", 3)
as(third, "visitJoin", 1)
eq(thirdState.visit, hostState.slot, "an invited guest is on the base too")
since = #T.toasts
as(host, "settingToggle", Rules.SETTING)
eq(hostData.features.settings.visitors, false, "the switch is in the host's save")
eq(HttpService:JSONDecode(host:GetAttribute("Meta_settings")).visitors, false, "the SETTINGS window shows it off")
eq(host:GetAttribute(Rules.PRIVATE), true, "every client can see the base is private")
eq(guestState.place, "plot", "the guest who came uninvited is sent home at once")
eq(thirdState.visit, hostState.slot, "the invited guest stays")
eq(toasted("base is private now", since), 1, "and the one sent home is told why")
T.run(1)
eq(#view(host).guests, 1, "the host's list has the invited guest only")
rested()
since = #T.toasts
as(guest, "visitGo", 1)
eq(guestState.place, "plot", "nobody comes uninvited to a private base")
eq(toasted("Tester's base is private", since), 1, "and is told it is private")
eq(toasted("is visiting your base", since), 0, "the owner hears nothing of it")
home(third)
rested()
as(third, "visitGo", 1)
eq(thirdState.place, "plot", "an invited guest who left needs a new invitation")
harness.advance(Rules.InviteGapSeconds + 1)
as(host, "visitInvite", 2)
as(guest, "visitJoin", 1)
eq(guestState.visit, hostState.slot, "an invitation still works while the base is private")
as(host, "visitKick", 2)
eq(guestState.place, "plot", "and the owner can still send that guest home")
-- A private player may visit others.
as(host, "visitGo", 3)
eq(hostState.visit, thirdState.slot, "a private player can still visit an open base")
home(host)
-- On again.
as(host, "settingToggle", Rules.SETTING)
eq(host:GetAttribute(Rules.PRIVATE), false, "switched on again, the base is open")
eq(hostData.features.settings.visitors, true, "and the save says so")
rested()
as(third, "visitGo", 1)
eq(thirdState.visit, hostState.slot, "and visitors come in again")
home(third)

T.section("the window")
do
	as(guest, "settingToggle", Rules.SETTING)
	eq(guest:GetAttribute(Rules.PRIVATE), true, "the second player goes private")
	harness.actAs(host)
	harness.runClient()
	local Windows = require(host.PlayerScripts.Client.Windows)
	local window = Windows.byName[Rules.WINDOW]
	check(window ~= nil, "the VISIT window exists")
	local function buttons(text: string): { TextButton }
		local found = {}
		for _, item in host.PlayerGui:GetDescendants() do
			if item:IsA("TextButton") and item.Visible and item.Text == text then
				table.insert(found, item)
			end
		end
		return found
	end
	window.open()
	T.run(1)
	eq(#buttons("INVITE"), 2, "everybody else on the server is listed")
	eq(#buttons("VISIT"), 1, "an open player has a VISIT button")
	eq(#buttons("Private"), 1, "a private one has it greyed: Private")
	-- Private is pressed first: the server refuses, whatever the client shows.
	rested()
	harness.click(buttons("Private")[1])
	harness.flush()
	eq(hostState.place, "plot", "pressing Private goes nowhere")
	harness.advance(0.2)
	harness.click(buttons("VISIT")[1])
	harness.flush()
	eq(hostState.visit, thirdState.slot, "pressing VISIT goes to that player's base")
	T.run(1)
	window.open() -- travelling closes the windows
	T.run(1)
	eq(#buttons("HERE"), 1, "the row says the player is there")
	eq(#buttons("GO HOME"), 1, "and the window offers the way home")
	as(guest, "settingToggle", Rules.SETTING)
	T.run(1)
	eq(#buttons("Private"), 0, "a player who opens their base is no longer shown as private")
	window.close()
	for _, item in host.PlayerGui:GetDescendants() do
		if item.Name == "VisitInvite" then
			eq(item.Visible, false, "nothing opened by itself: no card without an invitation")
		end
	end
end

T.section("the host leaves the game")
eq(hostState.visit, thirdState.slot, "the first player is on the third player's base, uninvited")
since = #T.toasts
harness.removePlayer(third)
T.run(1)
eq(hostState.place, "plot", "when the owner leaves, the guest is sent home")
eq(host:GetAttribute("Visiting"), 0, "the Visiting attribute is cleared")
eq(toasted("left the game", since), 1, "and told why")
check(view(host).host == nil, "nothing of the visit is left")
rested()
as(host, "visitGo", 3)
eq(hostState.place, "plot", "a player who left cannot be visited")
as(host, "visitGo", 2)
eq(hostState.visit, guestState.slot, "the others still can")
home(host)

check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
