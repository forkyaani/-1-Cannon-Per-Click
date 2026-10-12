-- The admin grant tool (run with --all-features): an admin grants gems, coins, candy, an item and a mini
-- cannon to a player who is online; anyone else is refused; bad ids, amounts and names are refused; a full
-- storage queues a mini cannon instead of pushing one out; a grant for a player who is not here is stored,
-- paid once at their next join and not again at the join after; every grant is logged; the ADMIN window.
local T = harness.load("_prelude.luau")
local Game = T.Game
local player = T.player
local check, eq = T.check, T.eq
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Admin = require(game:GetService("ReplicatedStorage").Shared.Features.Admin)

local grants = DataStoreService:GetDataStore("AdminGrants_v1")
local log = DataStoreService:GetDataStore("AdminLog_v1")
local saves = DataStoreService:GetDataStore("PlayerData_v5")

-- A second player who is no admin. The emulated client stays the first player's.
local bob = harness.addPlayer("Bob", 2)
Players.LocalPlayer = player
harness.flush()
local bobData = Game.data(bob)
assert(bobData and Game.state(bob), "the second player did not load")
T.release(bob)

-- GRANT, sent by `as` (the admin when left out), spaced past the action cooldown.
local function grant(argument: any, as: Player?)
	harness.advance(0.2)
	Players.LocalPlayer = as or player
	T.Remotes.Action:FireServer("adminGrant", argument)
	harness.flush()
	Players.LocalPlayer = player
end
local function view(who: Player)
	local raw = who:GetAttribute("Meta_admin")
	return if raw then HttpService:JSONDecode(raw) else nil
end
local function result()
	return view(player).result or {}
end
local function toasted(text: string, from: number): boolean
	for index = from, #T.toasts do
		if string.find(T.toasts[index].text, text, 1, true) then
			return true
		end
	end
	return false
end
local function pending(userId: number)
	local stored = grants:GetAsync("u_" .. userId)
	return if stored then stored.grants else {}
end
-- What the event feature has counted as earned candy for a player.
local function earned(data): number
	local saved = data.features.event
	local total = 0
	if typeof(saved) == "table" and typeof(saved.earned) == "table" then
		for _, amount in saved.earned do
			total += amount
		end
	end
	return total
end

T.section("who is an admin")
check(Admin.IDS[7421324429] == "D1v991", "D1v991 is in the list")
check(view(player) ~= nil and view(player).admin == true, "the server tells an admin's client that it is one")
eq(view(bob), nil, "and tells anyone else nothing")
eq(Admin.amount("gems", 500), 500, "a whole amount within the cap is good")
eq(Admin.amount("gems", 0), nil, "zero is not")
eq(Admin.amount("gems", 1.5), nil, "nor a fraction")
eq(Admin.amount("gems", Admin.Kind.gems.cap + 1), nil, "nor one over the cap")
eq(Admin.amount("pet", Admin.Kind.pet.cap + 1), nil, "a mini cannon's cap is its own")
eq(select(2, Admin.target("  Bob ")), "Bob", "a typed name is trimmed")
eq((Admin.target("12345")), 12345, "digits are a user id")
check(Admin.target("a b") == nil and select(2, Admin.target("a b")) == nil, "a name with a space is nobody")

T.section("an admin grants to a player who is online")
do
	local gems, coins, candy = bobData.diamonds, bobData.coins, bobData.candy
	local from = #T.toasts + 1
	grant({ target = "bob", kind = "gems", amount = 500 })
	eq(bobData.diamonds, gems + 500, "500 gems arrive, whatever the case of the name")
	check(toasted("A gift from the team: +500 gems", from), "the target is told with a toast")
	eq(result().ok, true, "the admin is told it worked")
	check(string.find(result().text, "Granted 500 gems to Bob", 1, true) ~= nil, `and what was granted ("{result().text}")`)

	grant({ target = 2, kind = "coins", amount = 1000 })
	check(bobData.coins >= coins + 1000, "coins arrive, by user id")
	local counted = earned(bobData)
	grant({ target = "2", kind = "candy", amount = 40 })
	check(bobData.candy >= candy + 40, "candy arrives, by a typed user id")
	eq(bob:GetAttribute("Candy"), bobData.candy, "the target's state is synced at once")
	eq(earned(bobData), counted, "granted candy is not counted as earned for the event board")
	T.run(1)
	check(earned(bobData) - counted < 40, "nor a moment later")

	local had = Game.items.count(bobData, "power2x")
	from = #T.toasts + 1
	grant({ target = "Bob", kind = "item", id = "power2x", amount = 3 })
	eq(Game.items.count(bobData, "power2x"), had + 3, "three of an item arrive")
	check(toasted("A gift from the team: +3 " .. T.Items.get("power2x").name, from), "named in the toast")
	local crate = Game.items.count(bobData, "pumpkincrate")
	grant({ target = "Bob", kind = "item", id = "pumpkincrate", amount = 1 })
	eq(Game.items.count(bobData, "pumpkincrate"), crate + 1, "a crate is an item")

	local wooden = Game.pets.count(bobData, "wooden")
	from = #T.toasts + 1
	grant({ target = "Bob", kind = "pet", id = "wooden", amount = 2 })
	eq(Game.pets.count(bobData, "wooden"), wooden + 2, "two mini cannons arrive")
	check(toasted("A gift from the team: +2 " .. T.Config.Pets.wooden.name, from), "named in the toast")
	check(#view(player).log > 0, "the admin's window has log lines")
end

T.section("anyone else is refused")
do
	local gems, mine = bobData.diamonds, T.data.diamonds
	local before = result().n
	grant({ target = "Bob", kind = "gems", amount = 500 }, bob)
	eq(bobData.diamonds, gems, "a player who is no admin cannot grant to themselves")
	grant({ target = "Tester", kind = "gems", amount = 500 }, bob)
	eq(T.data.diamonds, mine, "nor to anyone else")
	grant({ target = "Carol", kind = "gems", amount = 500 }, bob)
	eq(view(bob), nil, "they are still told nothing")
	eq(result().n, before, "and nothing was answered or logged")
	eq(#pending(2) + #pending(1) + #pending(3), 0, "nothing was stored either")
end

T.section("bad ids, amounts and names")
do
	local function snapshot(): string
		return `{bobData.diamonds}/{bobData.candy}/{#bobData.pets}/{Game.items.count(bobData, "power2x")}`
	end
	local same, coins = snapshot(), bobData.coins
	local logged = #log:GetAsync("log").list
	local function refused(argument: any, what: string)
		local before = result().n
		grant(argument)
		check(result().n == before + 1 and result().ok == false, `{what} is refused ("{result().text}")`)
	end
	refused({ target = "Bob", kind = "gems", amount = 0 }, "an amount of zero")
	refused({ target = "Bob", kind = "gems", amount = -50 }, "a negative amount")
	refused({ target = "Bob", kind = "gems", amount = 1.5 }, "a fraction")
	refused({ target = "Bob", kind = "gems", amount = Admin.Kind.gems.cap + 1 }, "an amount over the cap")
	refused({ target = "Bob", kind = "gems", amount = "500" }, "an amount that is text")
	refused({ target = "Bob", kind = "gems" }, "no amount")
	refused({ target = "Bob", kind = "pet", id = "wooden", amount = Admin.Kind.pet.cap + 1 }, "too many mini cannons")
	refused({ target = "Bob", kind = "item", id = "no such item", amount = 1 }, "an item that does not exist")
	refused({ target = "Bob", kind = "pet", id = "no such cannon", amount = 1 }, "a mini cannon that does not exist")
	refused({ target = "Bob", kind = "item", amount = 1 }, "an item without an id")
	refused({ target = "Bob", kind = "pet", id = 7, amount = 1 }, "an id that is a number")
	refused({ target = "Bob", kind = "rebirths", amount = 1 }, "a thing that cannot be granted")
	refused({ target = "Bob", kind = "pass", id = "tripleHatch", amount = 1 }, "a game pass")
	refused({ target = "Nobody_Here", kind = "gems", amount = 5 }, "a name Roblox does not know")
	refused({ target = "", kind = "gems", amount = 5 }, "no name")
	refused({ target = "Bob; drop", kind = "gems", amount = 5 }, "a name with punctuation")
	refused({ target = { "Bob" }, kind = "gems", amount = 5 }, "a name that is a table")
	refused("Bob", "an argument that is not a table")
	eq(snapshot(), same, "none of it changed what the player has")
	check(bobData.coins >= coins, "nor took a coin")
	eq(#log:GetAsync("log").list, logged, "and a refusal is not a grant in the log")
end

T.section("a full storage queues a mini cannon")
do
	while Game.pets.add(bob, "wooden") and #bobData.pets < 1000 do
	end
	local full = #bobData.pets
	local from = #T.toasts + 1
	grant({ target = "Bob", kind = "pet", id = "wooden", amount = 2 })
	eq(#bobData.pets, full, "nothing is pushed out of a full storage")
	eq(#bobData.features.admin.queue, 2, "the two wait in the queue")
	check(string.find(result().text, "2 waiting", 1, true) ~= nil, `the admin is told ("{result().text}")`)
	check(toasted("will arrive when your mini cannon storage has room", from), "and so is the player")
	check(Game.pets.remove(bob, "wooden", 1), "the player makes room for one")
	T.run(1)
	eq(#bobData.pets, full, "one arrives")
	eq(#bobData.features.admin.queue, 1, "and one still waits")
end

T.section("a player who is not here: stored, paid once at the next join")
do
	-- What a brand new save starts with, from a player nobody granted anything.
	local dave = harness.addPlayer("Dave", 4)
	Players.LocalPlayer = player
	harness.flush()
	local fresh = Game.data(dave).diamonds
	harness.removePlayer(dave)
	T.run(1)

	harness.setUser("Carol", 3)
	grant({ target = "carol", kind = "gems", amount = 250 })
	eq(result().ok, true, "a grant for an account that is not online is accepted")
	check(string.find(result().text, "Stored 250 gems for carol", 1, true) ~= nil, `and said to be stored ("{result().text}")`)
	grant({ target = "Carol", kind = "item", id = "power2x", amount = 2 })
	grant({ target = "Carol", kind = "pet", id = "wooden", amount = 1 })
	eq(#pending(3), 3, "three grants wait in the grant store")
	check(pending(3)[1].id ~= pending(3)[2].id and pending(3)[2].id ~= pending(3)[3].id, "each with an id of its own")
	eq(saves:GetAsync("u_3"), nil, "the player's save was not touched")

	local from = #T.toasts + 1
	local carol = harness.addPlayer("Carol", 3)
	Players.LocalPlayer = player
	harness.flush()
	local data = Game.data(carol)
	assert(data and Game.state(carol), "the third player did not load")
	eq(data.diamonds, fresh + 250, "at the next join the gems are paid")
	eq(Game.items.count(data, "power2x"), 2, "and the items")
	eq(Game.pets.count(data, "wooden"), 1, "and the mini cannon")
	check(toasted("A gift from the team: +250 gems", from), "with the usual toast")
	eq(#pending(3), 0, "nothing waits any more")
	eq(next(data.features.admin.paid), nil, "and the save's marks are cleared with it")
	eq(saves:GetAsync("u_3").diamonds, fresh + 250, "the save was written before the grants were removed")

	harness.removePlayer(carol)
	T.run(1)
	from = #T.toasts + 1
	carol = harness.addPlayer("Carol", 3)
	Players.LocalPlayer = player
	harness.flush()
	data = Game.data(carol)
	eq(data.diamonds, fresh + 250, "the join after pays nothing more")
	eq(Game.items.count(data, "power2x"), 2, "no item")
	eq(Game.pets.count(data, "wooden"), 1, "no mini cannon")
	check(not toasted("A gift from the team", from), "and says nothing")

	-- Online now: the same account is paid at once, nothing is stored.
	grant({ target = "Carol", kind = "gems", amount = 5 })
	eq(data.diamonds, fresh + 255, "online again, the player is paid at once")
	eq(#pending(3), 0, "and nothing is stored")
	harness.removePlayer(carol)
	T.run(1)
end

T.section("a crash between the save and the removal cannot pay twice")
do
	-- The save has the mark of a grant that is still in the store: the server died after writing the save.
	saves:SetAsync("u_5", { diamonds = 10, lastSeen = os.time() - 60, features = { admin = { paid = { ["grant-x"] = 1 }, queue = {} } } })
	grants:SetAsync("u_5", { grants = {
		{ id = "grant-x", kind = "gems", amount = 99, by = 1, byName = "Tester", at = 1 },
		{ id = "grant-y", kind = "gems", amount = 7, by = 1, byName = "Tester", at = 1 },
		{ id = "grant-z", kind = "item", item = "an item that left the game", amount = 1, by = 1, byName = "Tester", at = 1 },
	} })
	local eve = harness.addPlayer("Eve", 5)
	Players.LocalPlayer = player
	harness.flush()
	local data = Game.data(eve)
	eq(data.diamonds, 17, "the marked grant is skipped, the other one is paid")
	eq(#pending(5), 0, "all three are out of the store: paid before, paid now, and one that cannot be paid")
	eq(next(data.features.admin.paid), nil, "and the marks are cleared")
	harness.removePlayer(eve)
	T.run(1)
end

T.section("every grant is logged")
do
	local list = log:GetAsync("log").list
	check(#list >= 10 and #list <= Admin.LOG_KEPT, `the log store holds the grants ({#list})`)
	local first = list[1]
	check(first.by == 1 and first.byName == "Tester" and first.to == 2 and first.toName == "Bob", "who granted, and to whom")
	check(first.kind == "gems" and first.amount == 500 and first.how == "online" and typeof(first.at) == "number", "what, how and when")
	local seen = {}
	for _, entry in list do
		seen[entry.how] = true
	end
	check(seen.online and seen.pending and seen.paid and seen.dropped, "online, pending, paid and dropped grants are all there")
	check(#view(player).log <= Admin.LOG_SHOWN and #view(player).log > 0, "the admin's window gets the last few")
end

T.section("the window")
harness.runClient()
do
	local window = require(player.PlayerScripts.Client.Features.Admin)
	local frame = player.PlayerGui:FindFirstChild("ADMIN", true)
	check(frame ~= nil and frame.Visible == false, "the ADMIN window exists for an admin and is closed")
	check(window.button ~= nil and window.grant ~= nil, "with its menu button and a GRANT button")
	local gems = bobData.diamonds
	window.nameBox.Text = "Bob"
	window.amountBox.Text = ""
	harness.advance(0.2)
	harness.click(window.grant)
	harness.flush()
	eq(bobData.diamonds, gems, "GRANT without an amount asks nothing")
	check(window.result.Text ~= "", `and says what is missing ("{window.result.Text}")`)
	window.amountBox.Text = "1,000"
	harness.advance(0.2)
	harness.click(window.grant)
	harness.flush()
	eq(bobData.diamonds, gems + 1000, "GRANT sends what was typed")
	check(string.find(window.result.Text, "Granted", 1, true) ~= nil, `the result line has the server's answer ("{window.result.Text}")`)
	check(string.find(window.lines[1].Text, "Bob", 1, true) ~= nil, `and the newest log line is on top ("{window.lines[1].Text}")`)
	harness.click(window.kindButton)
	harness.click(window.kindButton)
	harness.click(window.kindButton)
	check(window.idBox.Visible, "picking an item shows the id box")
	window.idBox.Text = "power2"
	check(string.find(window.hint.Text, "power2x", 1, true) ~= nil, `typing part of an id offers the ids ("{window.hint.Text}")`)
	window.idBox.Text = "power2x"
	window.amountBox.Text = "2"
	local had = Game.items.count(bobData, "power2x")
	harness.advance(0.2)
	harness.click(window.grant)
	harness.flush()
	eq(Game.items.count(bobData, "power2x"), had + 2, "an item is granted from the window")
	check(frame.Visible == false, "nothing opened by itself")
end

check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
