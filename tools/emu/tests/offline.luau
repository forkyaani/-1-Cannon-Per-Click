-- Offline earnings, the welcome-back card (run with --all-features): a player whose save was last written two
-- hours ago (offline.pre.luau) joins, the card shows what the server worked out, and CLAIM pays it once.
-- The sums themselves, the cap and the rejoins are in smoke.luau.
local T = harness.load("_prelude.luau")
local Config, Game = T.Config, T.Game
local player, data = T.player, T.data
local check, eq = T.check, T.eq

T.section("the server worked the earnings out at join")
local pending = game:GetService("HttpService"):JSONDecode(player:GetAttribute("Meta_offline"))
eq(pending.away, 7200, "two hours away")
eq(pending.seconds, 7200, "all of it paid for")
check(pending.level >= 1 and pending.level <= 2, `a level the starter cannon clears was farmed ({pending.level})`)
check(pending.coins > 0, `it earned coins ({pending.coins})`)
do
	-- The worked example of the report: the starter cannon on that level.
	local Offline = require(game:GetService("ReplicatedStorage").Shared.Features.Offline)
	local plan = Config.levelPlan(pending.level)
	local dps = player:GetAttribute("CannonPower")
	local clear = Offline.clearSeconds(plan, dps, 1, 0)
	print(`  EXAMPLE level {pending.level}: {plan.count} monsters, {plan.hp} hp, {plan.coins} coins each, gap {plan.gap}, speed {plan.speed}, path {T.Layout.PATH_LENGTH}; dps {dps}; one clear {clear} s; coin multiplier {Game.value(player, "coins")}; 7200 s -> {pending.coins} coins`)
end
local coins = data.coins

T.section("the welcome-back card")
harness.runClient()
local Client = player.PlayerScripts.Client
local card = require(Client.Features.Offline)
check(card.gui ~= nil and card.gui.Enabled == true, "the card is up when the client starts")
local texts = {}
for _, item in card.gui:GetDescendants() do
	if item:IsA("TextLabel") then
		table.insert(texts, item.Text)
	end
end
local all = table.concat(texts, " | ")
print("  card: " .. all)
for _, word in { "WELCOME BACK", "2h 0m", Config.waveLabel(pending.level), T.Format.abbreviate(pending.coins), "8 hours", "50%" } do
	check(string.find(all, word, 1, true) ~= nil, `the card says "{word}"`)
end
eq(data.coins, coins, "nothing is paid until CLAIM")
harness.advance(0.2)
harness.click(card.claimButton)
harness.flush()
eq(data.coins, coins + pending.coins, "CLAIM pays the coins")
T.run(1)
check(card.gui.Enabled == false, "and the card goes away")
harness.advance(3)
harness.click(card.claimButton)
harness.flush()
T.act("offlineClaim")
eq(data.coins - coins >= pending.coins and data.totalKills >= 20, true, "a second press pays nothing more than the fight does")
check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
