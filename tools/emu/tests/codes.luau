-- Redeem codes (run with --all-features): a good code pays once, a second try is refused, junk is answered
-- and pays nothing, tries are rate-limited, an expired code is refused, every kind of reward is paid, the
-- CODES window sends what was typed, and a rejoin keeps a code used.
local T = harness.load("_prelude.luau")
local Game = T.Game
local player, data = T.player, T.data
local check, eq = T.check, T.eq
local Codes = require(game:GetService("ReplicatedStorage").Shared.Features.Codes)

-- Codes of the test's own, next to the real list: one per kind of reward and two with a last day.
local now = harness.now()
Codes.List.TESTCLEARS = { clears = 2 }
Codes.List.TESTITEM = { item = "power2x", amount = 3 }
Codes.List.TESTOLD = { gems = 5, expires = now - 1 }
Codes.List.TESTSOON = { gems = 5, expires = now + 600 }
Codes.List.TESTLATER = { gems = 7, expires = now + 600 }
Codes.List.TESTBROKEN = { item = "no such item" }
Codes.List.TESTWINDOW = { gems = 3 }

-- One try, spaced past the feature's own cooldown. Returns the toast it was answered with.
local function redeem(text: any): string
	harness.advance(Codes.COOLDOWN + 0.1)
	local before = #T.toasts
	T.Remotes.Action:FireServer("redeemCode", text)
	harness.flush()
	eq(#T.toasts, before + 1, "the try is answered with one toast")
	return T.toasts[#T.toasts].text
end
local function said(text: string, word: string, what: string)
	check(string.find(text, word, 1, true) ~= nil, `{what} ("{text}")`)
end

T.section("the list")
check(typeof(Codes.List.LAUNCH) == "table" and Codes.List.LAUNCH.gems == 100, "the launch code is there: LAUNCH, 100 gems")
eq(Codes.normalise("  launch \n"), "LAUNCH", "a typed code is trimmed and put in capitals")
eq(Codes.normalise("LAUNCH!"), nil, "a code has letters and digits only")
eq(Codes.normalise(""), nil, "nothing typed is not a code")
eq(Codes.normalise(string.rep("A", Codes.MAX_LENGTH + 1)), nil, "nor is a text that is too long")
eq(Codes.day(1970, 1, 1), 86_400, "a last day ends at midnight UTC")
eq(Codes.day(2026, 12, 31), 1_798_761_600, "31 December 2026 ends when 2027 starts")
eq(Codes.day(2028, 2, 29), Codes.day(2028, 3, 1) - 86_400, "leap days count")

T.section("a good code pays once")
local gems, coins = data.diamonds, data.coins
said(redeem("  launch "), "LAUNCH redeemed", "typed in small letters with spaces, it is redeemed")
eq(data.diamonds, gems + 100, "100 gems are paid")
eq(T.toasts[#T.toasts].kind, "good", "the toast is a good one")
check(typeof(data.features.codes.used.LAUNCH) == "number", "the save remembers it")
said(redeem("LAUNCH"), "already used", "a second try is refused")
said(redeem("Launch"), "already used", "however it is typed")
eq(data.diamonds, gems + 100, "and pays nothing more")
eq(T.toasts[#T.toasts].kind, "bad", "the refusal is a bad toast")

T.section("junk")
gems = data.diamonds
said(redeem("NOPE"), "does not exist", "an unknown code")
said(redeem(""), "does not exist", "nothing at all")
said(redeem("   "), "does not exist", "only spaces")
said(redeem("LAUNCH; DROP"), "does not exist", "punctuation")
said(redeem(string.rep("LAUNCH", 500)), "does not exist", "a very long text")
said(redeem(42), "does not exist", "a number")
said(redeem({ "LAUNCH" }), "does not exist", "a table")
said(redeem(nil), "does not exist", "no argument")
-- A client cannot name its own reward: only the text is read.
said(redeem({ code = "TESTLATER", gems = 1e9 }), "does not exist", "a made-up reward")
eq(data.diamonds, gems, "none of it pays a gem")
eq(data.coins >= coins, true, "nor takes a coin")
eq(data.features.codes.used.NOPE, nil, "and an unknown code is not written to the save")

T.section("tries are rate-limited")
do
	harness.advance(Codes.COOLDOWN + 0.1)
	gems = data.diamonds
	local before = #T.toasts
	T.Remotes.Action:FireServer("redeemCode", "WRONG1")
	harness.flush()
	harness.advance(0.2)
	T.Remotes.Action:FireServer("redeemCode", "TESTLATER")
	harness.flush()
	eq(#T.toasts, before + 2, "both tries are answered")
	said(T.toasts[#T.toasts].text, "Slow down", "the second, too soon, is told to wait")
	eq(data.diamonds, gems, "and a good code typed too soon is not paid")
	eq(data.features.codes.used.TESTLATER, nil, "nor used up")
	said(redeem("TESTLATER"), "TESTLATER redeemed", "after the wait it works")
	eq(data.diamonds, gems + 7, "and pays")
end

T.section("expiry")
gems = data.diamonds
said(redeem("TESTOLD"), "expired", "a code past its last day is refused")
eq(data.diamonds, gems, "and pays nothing")
eq(data.features.codes.used.TESTOLD, nil, "nor is it marked used")
harness.setTime(now + 601)
said(redeem("TESTSOON"), "expired", "a code runs out when its day ends")
harness.setTime(now)
said(redeem("TESTSOON"), "TESTSOON redeemed", "before that it is good")
eq(data.diamonds, gems + 5, "and pays")

T.section("the other rewards")
do
	local had, power = data.coins, T.count("power2x")
	local expected = math.floor(2 * T.Config.levelCoins(math.max(1, data.bestCleared)))
	said(redeem("TESTCLEARS"), "coins", "a code for coins says so")
	check(data.coins >= had + expected, `two clears of the player's best level are paid ({expected})`)
	said(redeem("TESTITEM"), "+3 ", "a code for an item says how many")
	eq(T.count("power2x"), power + 3, "three of the item are in the backpack")
	said(redeem("TESTBROKEN"), "cannot be redeemed", "a code whose item does not exist is refused")
	eq(data.features.codes.used.TESTBROKEN, nil, "and not used up")
end

T.section("the window")
harness.runClient()
do
	local view = require(player.PlayerScripts.Client.Features.Codes)
	local frame = player.PlayerGui:FindFirstChild("CODES", true)
	check(frame ~= nil and frame.Visible == false, "the CODES window exists and is closed until its button is pressed")
	check(view.box:IsA("TextBox") and view.button ~= nil, "it has a text box and a REDEEM button")
	gems = data.diamonds
	harness.advance(Codes.COOLDOWN + 0.1)
	local before = #T.toasts
	view.box.Text = ""
	harness.click(view.button)
	eq(#T.toasts, before, "REDEEM on an empty box asks nothing")
	view.box.Text = " testwindow "
	harness.click(view.button)
	harness.flush()
	eq(data.diamonds, gems + 3, "REDEEM sends what was typed")
	eq(view.box.Text, "", "and empties the box")
	view.box.Text = string.rep("A", 100)
	eq(#view.box.Text, Codes.MAX_LENGTH, "a long paste is cut to a code's length")
	check(frame.Visible == false, "nothing opened by itself")
end

T.section("a rejoin keeps it used")
do
	local total = data.diamonds
	harness.removePlayer(player)
	T.run(1)
	local again = harness.addPlayer("Tester", 1)
	harness.flush()
	local saved = Game.data(again)
	assert(saved and Game.state(again), "the player did not load again")
	check(typeof(saved.features.codes.used.LAUNCH) == "number", "the save still has the code")
	eq(saved.diamonds, total, "and the gems it paid")
	harness.advance(0.2)
	local before = #T.toasts
	T.Remotes.Action:FireServer("redeemCode", "LAUNCH")
	harness.flush()
	eq(#T.toasts, before + 1, "a try after the rejoin is answered")
	said(T.toasts[#T.toasts].text, "already used", "and refused")
	eq(saved.diamonds, total, "it pays nothing")
end

check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
