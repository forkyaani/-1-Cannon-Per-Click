-- Gems in a trade (docs/RELEASE_TASKS.md, AB1): two players offer gems beside their mini cannons, the server
-- checks every amount when it is offered and again at the swap, and no gem is ever made or lost.
-- Run with: python3 run.py --all-features tests/trading.luau
local T = harness.load("_prelude.luau")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Game = T.Game
local check, eq = T.check, T.eq
local Rules = require(ReplicatedStorage.Shared.Features.Trading)

local PET = "wooden"
local a, dataA = T.player, T.data
local b = harness.addPlayer("Buddy", 2)
harness.flush()
local dataB = Game.data(b)
check(dataB ~= nil, "the second player loaded")

-- A client request from `who`.
local function as(who: Player, name: string, argument: any?)
	harness.actAs(who)
	T.act(name, argument)
end
local function view(who: Player)
	return HttpService:JSONDecode(who:GetAttribute("Meta_trade"))
end
local function history(who: Player)
	return HttpService:JSONDecode(who:GetAttribute("Meta_tradeHistory"))
end
local function toasted(text: string, since: number): boolean
	for index = since + 1, #T.toasts do
		if string.find(T.toasts[index].text, text, 1, true) then
			return true
		end
	end
	return false
end
-- Nothing may earn or spend gems behind the test's back: both bases stand still, and the balances are set here.
local function gems(who: Player, amount: number?): number
	local data = Game.data(who)
	if amount then
		data.diamonds = amount
	end
	return data.diamonds
end
for _, who in { a, b } do
	Game.actions.setPaused(who, Game.data(who), Game.state(who), true)
end
-- Opens a trade between the two, past any cooldown, and waits out the lock on READY.
local function open(first: Player, second: Player)
	harness.advance(Rules.CooldownSeconds + 1)
	as(first, "tradeRequest", second.UserId)
	as(second, "tradeAccept", first.UserId)
	check(view(first).trade ~= nil and view(second).trade ~= nil, `{first.Name} and {second.Name} are in a trade`)
	harness.advance(Rules.ReadyLockSeconds + 0.5)
end
local function unlock()
	harness.advance(Rules.ReadyLockSeconds + 0.5)
end
local function ready(who: Player)
	as(who, "tradeReady", view(who).trade.version)
end
local function finish()
	T.run(Rules.CountdownSeconds + 2)
end

T.section("the rules")
eq(Rules.gemAmount(0), 0, "0 gems is an amount")
eq(Rules.gemAmount(Rules.MaxGems), Rules.MaxGems, "so is the most allowed")
for name, bad in { negative = -1, fraction = 0.5, nan = 0 / 0, infinity = math.huge, huge = Rules.MaxGems + 1, text = "100", table = {}, boolean = true } do
	eq(Rules.gemAmount(bad), nil, `not an amount: {name}`)
end
eq(Rules.gemAmount(nil), nil, "not an amount: nothing")
eq(Rules.gemText(1), "1 gem", "one gem")
eq(Rules.gemText(999), "999 gems", "999 gems")
eq(Rules.gemText(1250), "1,250 gems", "thousands are grouped")
eq(Rules.gemText(1000000), "1,000,000 gems", "and millions")
check(Rules.empty({ pets = {}, items = {}, gems = 0 }) and not Rules.empty({ pets = {}, items = {}, gems = 5 }), "gems alone make an offer")
eq(Rules.gems({ pets = {}, items = {} }), 0, "a trade from before gems has none")

T.section("offering gems")
as(a, "goMarket")
as(b, "goMarket")
harness.step(0.5)
eq(view(a).reason, nil, "the tester may trade")
eq(view(b).reason, nil, "so may the second player")
gems(a, 1000)
gems(b, 300)
Game.pets.add(a, PET, true)
local petsA, petsB = Game.pets.count(dataA, PET), Game.pets.count(dataB, PET)
as(a, "tradeGems", 50)
check(view(a).trade == nil, "gems cannot be offered outside a trade")
open(a, b)
eq(view(a).trade.give.gems, 0, "a trade starts with no gems on the table")

local version = view(a).trade.version
for name, bad in { negative = -1, fraction = 10.5, nan = 0 / 0, infinity = math.huge, ["minus infinity"] = -math.huge, huge = 1e18, ["one too many"] = Rules.MaxGems + 1, text = "100", table = { 100 }, boolean = true } do
	as(a, "tradeGems", bad)
	if view(a).trade.give.gems ~= 0 or view(a).trade.version ~= version then
		error(`CHECK FAILED: a bad amount ({name}) got through`)
	end
end
as(a, "tradeGems", nil)
check(view(a).trade.give.gems == 0 and view(a).trade.version == version, "negative, fractional, NaN, infinite, huge and non-number amounts are refused")
local since = #T.toasts
as(a, "tradeGems", 1001)
check(view(a).trade.give.gems == 0 and view(a).trade.version == version, "more than the player holds is refused")
check(toasted("You only have 1,000 gems", since), "and they are told what they have")
gems(a, Rules.MaxGems + 500)
as(a, "tradeGems", Rules.MaxGems + 1)
eq(view(a).trade.give.gems, 0, "the limit holds for a player who has more")
as(a, "tradeGems", Rules.MaxGems)
eq(view(a).trade.give.gems, Rules.MaxGems, "the most allowed can be offered by someone who holds it")
gems(a, 1000)
as(a, "tradeGems", 400)
eq(view(a).trade.give.gems, 400, "400 gems are on the table")
eq(view(b).trade.get.gems, 400, "and the other player sees them")
eq(gems(a), 1000, "nothing has left the balance yet")

T.section("a change un-readies both")
unlock()
ready(b)
eq(view(b).trade.ready, true, "the second player is ready")
version = view(a).trade.version
as(a, "tradeGems", 400)
check(view(b).trade.ready == true and view(a).trade.version == version, "offering the same amount again changes nothing")
as(a, "tradeGems", 500)
eq(view(b).trade.ready, false, "a new amount un-readies them")
eq(view(a).trade.version, version + 1, "the offers have a new version")
check(view(a).trade.readyAt > harness.now(), "and READY is locked for a moment")
as(b, "tradeReady", version)
eq(view(b).trade.ready, false, "a READY pressed for the old amount does not count")
unlock()
ready(a)
ready(b)
check(view(a).trade.endsAt > 0, "both ready: the countdown runs")
as(b, "tradeGems", 120)
eq(view(a).trade.endsAt, 0, "a change of gems stops it")
check(not view(a).trade.ready and not view(b).trade.ready, "and un-readies both")
finish()
check(gems(a) == 1000 and gems(b) == 300, "the stopped countdown moved nothing")
check(view(a).trade ~= nil, "and the trade is still open")

T.section("the same player in two trades")
local c = harness.addPlayer("Third", 3)
harness.flush()
Game.actions.setPaused(c, Game.data(c), Game.state(c), true)
gems(c, 50)
as(c, "goMarket")
harness.step(0.5)
since = #T.toasts
as(c, "tradeRequest", a.UserId)
check(toasted("is in a trade", since), "somebody in a trade cannot be asked")
as(a, "tradeRequest", c.UserId)
check(view(c).trade == nil and #view(c).requests == 0, "nor ask anybody else")
eq(view(a).trade.partner.id, b.UserId, "the first trade goes on")

T.section("the swap")
as(a, "tradeOffer", { kind = "pets", id = PET, add = 1 })
unlock()
ready(a)
ready(b)
local endsAt = view(a).trade.endsAt
check(endsAt > 0, "both ready: 500 gems and a mini cannon for 120 gems")
ready(a)
as(a, "tradeReady", view(a).trade.version)
eq(view(a).trade.endsAt, endsAt, "pressing READY again changes nothing")
check(gems(a) == 1000 and gems(b) == 300, "nothing moves during the countdown")
finish()
check(view(a).trade == nil and view(b).trade == nil, "the trade is over")
eq(gems(a), 1000 - 500 + 120, "the tester paid 500 gems and got 120")
eq(gems(b), 300 + 500 - 120, "the second player got 500 and paid 120")
eq(Game.pets.count(dataA, PET), petsA - 1, "the mini cannon left with the gems")
eq(Game.pets.count(dataB, PET), petsB + 1, "and arrived with them")
eq(a:GetAttribute("Diamonds"), gems(a), "the client is told the new balance")
local entry = history(a).list[1]
check(entry.gave.gems == 500 and entry.got.gems == 120 and entry.gave.pets[PET] == 1, "the history records the gems")
check(history(b).list[1].gave.gems == 120 and history(b).list[1].got.gems == 500, "on both sides")
-- Whatever arrives after the swap finds no trade.
as(a, "tradeReady", 1)
as(a, "tradeGems", 100)
as(b, "tradeReady", 1)
finish()
check(gems(a) == 620 and gems(b) == 680, "late presses move nothing more")

T.section("gems only, one way")
open(b, a)
as(b, "tradeGems", 80)
unlock()
ready(a)
ready(b)
finish()
check(gems(a) == 700 and gems(b) == 600, "a gift of 80 gems goes through, as a gift of mini cannons does")
eq(gems(a) + gems(b), 1300, "the two balances add up to what they started with")

T.section("gems spent after they were offered")
open(a, b)
as(a, "tradeGems", 700)
as(b, "tradeGems", 50)
unlock()
ready(a)
ready(b)
check(view(a).trade.endsAt > 0, "the countdown runs on 700 gems for 50")
since = #T.toasts
gems(a, 100) -- an egg, the store: 600 of the 700 are gone
finish()
eq(gems(a), 100, "the swap did not happen: the tester keeps what they have left")
eq(gems(b), 600, "and the second player was paid nothing and paid nothing")
check(view(a).trade ~= nil, "the trade is still open")
check(not view(a).trade.ready and not view(b).trade.ready, "with both un-readied")
check(toasted("no longer has", since), "both are told why")
-- (The emulator's task.wait ends a thread, so the server's quarter-second watch, which would have taken the
-- missing gems off the table before the countdown ended, never runs here: the refusal above is the check at
-- the swap itself.) The same check when the last READY arrives:
as(a, "tradeGems", 100)
unlock()
ready(b)
since = #T.toasts
version = view(a).trade.version
gems(a, 40)
harness.actAs(a)
ReplicatedStorage.Remotes.Action:FireServer("tradeReady", version)
harness.flush()
check(toasted("no longer has the gems", since), "the last READY finds the gems gone")
check(view(a).trade.endsAt == 0 and not view(b).trade.ready, "no countdown starts")
finish()
check(gems(a) == 40 and gems(b) == 600, "and nothing moved")

T.section("leaving in the middle")
gems(a, 700)
as(a, "tradeGems", 300)
as(b, "tradeGems", 50)
unlock()
ready(a)
ready(b)
check(view(a).trade.endsAt > 0, "the countdown runs")
harness.removePlayer(b)
check(view(a).trade == nil, "the trade closes when the other player leaves")
finish()
eq(gems(a), 700, "and the gems stay where they were")

T.section("Roblox says no")
-- The gate is the one trading had before gems: a player who may not trade paid items is in no trade at all.
harness.setTradePolicy(false)
local d = harness.addPlayer("Denied", 4)
harness.flush()
harness.setTradePolicy(true)
as(d, "goMarket")
harness.step(0.5)
check(view(d).reason ~= nil, "a player Roblox does not let trade is told so")
since = #T.toasts
as(a, "tradeRequest", d.UserId)
check(view(a).trade == nil and toasted("cannot trade right now", since), "and nobody can open a trade with them")
as(d, "tradeGems", 10)
check(view(d).trade == nil, "so they offer no gems")

T.section("the window")
-- The real client for the tester, in a trade with the third player.
harness.actAs(a)
harness.runClient()
open(a, c)
harness.actAs(a)
harness.step(0.5)
local gui = a:FindFirstChildWhichIsA("PlayerGui")
local window = gui:FindFirstChild("TRADE", true)
check(window ~= nil and window.Visible, "a trade opens the TRADE window")
local box = window:FindFirstChild("Gems", true)
check(box ~= nil and box:IsA("TextBox"), "which has a box for gems")
box.Text = "1,250"
harness.advance(0.2)
harness.fire(box, "FocusLost", true)
eq(view(a).trade.give.gems, 700, "typing more than is held offers everything held")
box.Text = "250"
harness.advance(0.2)
harness.fire(box, "FocusLost", true)
eq(view(a).trade.give.gems, 250, "typing an amount offers it")
eq(view(c).trade.get.gems, 250, "and the other player is shown it")
harness.step(0.5)
local shown = false
for _, label in window:GetDescendants() do
	if label:IsA("TextLabel") and string.find(label.Text, "250 gems", 1, true) then
		shown = true
	end
end
check(shown, "the offer panel spells the gems out")
as(a, "tradeCancel")
check(view(a).trade == nil, "the trade can be cancelled")
eq(gems(a), 700, "with every gem still there")

eq(harness.errors(), 0, "nothing errored")
print(`trading: {T.checks} checks`)
