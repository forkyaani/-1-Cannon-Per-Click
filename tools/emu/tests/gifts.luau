-- Playtime gifts, the friend bonus, badges and the boss-level gems (run with --all-features).
local T = harness.load("_prelude.luau")
local Game, Config = T.Game, T.Config
local player, data, state = T.player, T.data, T.state
local check, eq, act, run = T.check, T.eq, T.act, T.run
local Http = game:GetService("HttpService")
local Server = game:GetService("ServerScriptService").Server
local Gifts = require(game:GetService("ReplicatedStorage").Shared.Features.Gifts)
local Friends = require(Server.Features.Friends)
local Badges = require(Server.Features.Badges)

local function meta(key: string, who: Player?)
	return Http:JSONDecode((who or player):GetAttribute("Meta_" .. key))
end
local function toasted(text: string): boolean
	for _, toast in T.toasts do
		if string.find(toast.text, text, 1, true) then
			return true
		end
	end
	return false
end

T.section("the window")
harness.runClient()
local window = require(player.PlayerScripts.Client.Windows).byName[Gifts.WINDOW]
check(window ~= nil, "the GIFTS window is registered")
check(harness.errors() == 0, "and nothing errored")

T.section("the numbers stay small")
local total = 0
for _, gift in Gifts.List do
	total += gift.gems
end
local missions = 0
for _, mission in Config.Missions do
	missions += mission.reward
end
check(total < missions, `a day of playtime gifts ({total} gems) pays less than the daily missions ({missions})`)
check(Gifts.FRIEND_COINS * Gifts.FRIEND_MAX <= 0.3 + 1e-9, "friends add 30% coins at most")

T.section("playtime gifts")
local save = data.features.gifts
eq(save.seconds < 5, true, "a new day starts at nothing")
local gems = data.diamonds
act("giftClaim", 1)
eq(data.diamonds, gems, "a gift cannot be claimed before its time")
for _, junk in { 0, 99, 1.5, "1", true, { 1 } } do
	act("giftClaim", junk)
end
eq(data.diamonds, gems, "nor with a junk answer")
harness.advance(5 * 60 + 1)
run(1)
check(toasted("A playtime gift is ready"), "after five minutes a toast says a gift is ready")
check(meta("gifts").seconds >= 300, "and the client is told the time")
act("giftClaim", 1)
eq(data.diamonds, gems + Gifts.List[1].gems, "the first gift pays its gems")
act("giftClaim", 1)
eq(data.diamonds, gems + Gifts.List[1].gems, "once")
eq(meta("gifts").claimed["1"], true, "and the client is told it is claimed")
act("giftClaim", 2)
eq(data.diamonds, gems + Gifts.List[1].gems, "the ten-minute gift is not due yet")
harness.advance(5 * 60)
run(1)
local had = data.items[Gifts.List[2].item] or 0
act("giftClaim", 2)
eq(data.diamonds, gems + Gifts.List[1].gems + Gifts.List[2].gems, "it pays at ten minutes")
eq(data.items[Gifts.List[2].item], had + 1, "with its item")
-- A new day.
data.features.gifts.day -= 1
run(1)
act("giftClaim", 1)
eq(data.diamonds, gems + Gifts.List[1].gems + Gifts.List[2].gems, "a new day starts the count again: nothing is due")
check(data.features.gifts.seconds < 60, "from nothing")
eq(next(data.features.gifts.claimed), nil, "with nothing claimed")

T.section("the friend bonus")
local base = Game.value(player, "coins")
eq(meta("friends").count, 0, "alone, there is no bonus")
Friends.areFriends = function(a: Player, b: Player): boolean
	return a.UserId + b.UserId == 1 + 50 -- the tester and player 50 are friends; nobody else
end
local stranger = harness.addPlayer("Stranger", 60)
harness.flush()
run(1)
check(math.abs(Game.value(player, "coins") - base) < 1e-9, "a stranger joining changes nothing")
local friend = harness.addPlayer("Friend", 50)
harness.flush()
run(1)
eq(meta("friends").count, 1, "a friend joining counts")
check(math.abs(Game.value(player, "coins") - base * (1 + Gifts.FRIEND_COINS)) < 1e-9, "and coins are up by the bonus")
eq(meta("friends", friend).count, 1, "for the friend too")
eq(meta("friends", stranger).count, 0, "and not for the stranger")
do
	local named = false
	for _, source in Game.breakdown(player, "coins").sources do
		named = named or source.label == "Friend bonus"
	end
	check(named, 'STATS lists it as "Friend bonus"')
end
harness.removePlayer(friend)
run(1)
eq(meta("friends").count, 0, "the bonus goes when the friend leaves")
check(math.abs(Game.value(player, "coins") - base) < 1e-9, "and coins are as before")
harness.removePlayer(stranger)

T.section("badges")
local given = {}
Badges.award = function(_who: Player, id: number): boolean
	table.insert(given, id)
	return true
end
local egg = Config.Eggs[1]
data.coins = egg.cost * 10
harness.advance(0.5)
harness.fire(T.Marketplace.promptFor[egg.id], "Triggered", player)
run(1)
check(data.totalHatches > 0, "an egg was hatched")
eq(#given, 0, "a badge without an id on Roblox is not awarded")
Gifts.Badges.hatch.id = 777
harness.advance(0.5)
harness.fire(T.Marketplace.promptFor[egg.id], "Triggered", player)
run(1)
eq(table.concat(given, " "), "777", "with an id, the hatch badge is awarded")
harness.advance(0.5)
harness.fire(T.Marketplace.promptFor[egg.id], "Triggered", player)
run(1)
eq(#given, 1, "once")
eq(data.features.badges.given.hatch, true, "and the save remembers it")
Gifts.Badges.hatch.id = 0

print(`gifts.luau: {T.checks} checks passed`)
