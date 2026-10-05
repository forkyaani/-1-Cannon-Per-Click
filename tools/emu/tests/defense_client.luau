-- The idle defence client against the real server and the real plots:
--   python3 run.py --all-features --real-plots tests/defense_client.luau
-- The server only simulates on Heartbeat, which this chunk fires when it wants the game to run (T.run); the
-- battlefield checks send their own Field messages in between, so they know exactly what the client was told.
-- It proves data flow and that nothing errors. The emulator has no rotation and no rendering: aiming and looks
-- need Studio.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local T = harness.load("_prelude.luau")
local Config, Game, player = T.Config, T.Game, T.player
local check, eq = T.check, T.eq
local Layout = require(ReplicatedStorage.Shared.Layout)
local Format = require(ReplicatedStorage.Shared.Format)
local data = T.data

local field = ReplicatedStorage.Remotes:FindFirstChild("Field")
check(field ~= nil, "the server made the Field remote")
check(ReplicatedStorage.Remotes:FindFirstChild("Click") == nil, "and no Click remote")

local slot = player:GetAttribute("Slot")
check(typeof(slot) == "number", "the player has a plot")

-- workspace.Plots as the server's Plots.luau builds it (docs/DEFENSE_SPEC.md, section 6).
local plots = workspace:FindFirstChild("Plots")
check(plots ~= nil, "workspace.Plots exists (run with --real-plots)")
local plot = plots:FindFirstChild("Plot_" .. slot)
eq(plot:GetAttribute("Owner"), player.UserId, "the plot is the player's")
local towers = plot.Towers
local prompts = {}
for index = 1, #Layout.PADS do
	local pad = plot.Pads:FindFirstChild("Pad_" .. index)
	prompts[index] = pad and pad:FindFirstChildWhichIsA("ProximityPrompt", true)
	check(prompts[index] ~= nil and prompts[index]:GetAttribute("Pad") == index, `pad {index} has its prompt`)
end
local starter = towers:FindFirstChild("Tower_1")
check(starter ~= nil and starter:GetAttribute("Kind") == "cannon", "the starter cannon stands on pad 1")
check(starter:FindFirstChild("Turret", true) ~= nil and starter:FindFirstChild("Muzzle", true) ~= nil, "with a Turret and a Muzzle")

----------------------------------------------------------------------------------------------------
harness.runClient()
local Client = player.PlayerScripts.Client
local Hud = require(Client.Hud)
local Windows = require(Client.Windows)
local Field = require(Client.Field)
local UI = require(Client.UI)
local camera = workspace.CurrentCamera

local function frames(count: number, dt: number?)
	for _ = 1, count do
		harness.advance(dt or 1 / 30)
		harness.fire(RunService, "RenderStepped", dt or 1 / 30)
	end
end

local function noErrors(what: string)
	check(harness.errors() == 0, "no errors after " .. what)
end

-- Every text on screen under an instance, joined: enough to find a word.
local function textOf(root: Instance): string
	local parts = {}
	for _, item in root:GetDescendants() do
		if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text ~= "" then
			table.insert(parts, item.Text)
		end
	end
	return table.concat(parts, " | ")
end

local function shown(root: Instance): boolean
	local at: Instance? = root
	while at and at:IsA("GuiObject") do
		if not at.Visible then
			return false
		end
		at = at.Parent
	end
	return true
end

local function buttonWith(root: Instance, word: string): TextButton?
	for _, item in root:GetDescendants() do
		if item:IsA("TextButton") and shown(item) and string.find(item.Text, word, 1, true) then
			return item
		end
	end
	return nil
end

T.section("walking view")
frames(3)
check(camera.CameraType ~= Enum.CameraType.Scriptable, "the camera is left to Roblox")
check(shown(Hud.backButton), "the travel button is on screen on the plot")
check(string.find(Hud.backButton.Text, "MARKET") ~= nil, "on the plot it goes to the marketplace: " .. string.gsub(Hud.backButton.Text, "\n", " "))
harness.advance(0.2)
harness.click(Hud.backButton)
frames(3)
eq(player:GetAttribute("InMarket"), true, "pressing it travels to the marketplace")
check(string.find(Hud.backButton.Text, "BASE") ~= nil, "in the marketplace it goes back: " .. string.gsub(Hud.backButton.Text, "\n", " "))
harness.advance(0.2)
harness.click(Hud.backButton)
frames(3)
eq(player:GetAttribute("InMarket"), false, "pressing it again travels home")
noErrors("travelling both ways")

T.section("level HUD")
local cluster = UI.gui:FindFirstChild("Defense", true)
check(cluster ~= nil and shown(cluster), "the level cluster is shown on the plot")
local clusterText = textOf(cluster)
print("    " .. string.gsub(clusterText, "\n", " "))
check(string.find(clusterText, "10/10", 1, true) ~= nil, "it shows the lives")
check(player:GetAttribute("MonstersLeft") > 0, "the server says how many monsters are left")
check(string.find(clusterText, `{player:GetAttribute("MonstersLeft")} LEFT`, 1, true) ~= nil, "it shows the monsters left")
check(player:GetAttribute("Dps") > 0, "the server publishes Dps")
check(string.find(clusterText, Format.abbreviate(player:GetAttribute("Dps")), 1, true) ~= nil, "it shows the towers' damage per second")
local banner = UI.gui:FindFirstChild("DefenseBanner", true)
Game.send(player, "defense", "cleared", 1, 250)
harness.flush()
check(banner.Visible and string.find(textOf(banner), "CLEARED", 1, true) ~= nil, "the cleared banner: " .. textOf(banner))
Game.send(player, "defense", "failed", 3)
harness.flush()
check(string.find(textOf(banner), "FAILED", 1, true) ~= nil, "the failed banner: " .. textOf(banner))
Game.send(player, "defense", "leak", 7)
harness.flush()
harness.advance(3)
harness.flush()
check(not banner.Visible, "a banner goes away by itself")
-- The speed button: 1x, 2x, 3x and round again.
local speedButton = buttonWith(cluster, "1x")
check(speedButton ~= nil, "the level cluster has the speed button")
harness.advance(0.2)
harness.click(speedButton)
frames(2)
eq(data.speed, 2, "a press picks 2x")
check(string.find(speedButton.Text, "2x", 1, true) ~= nil, "and the button says so: " .. speedButton.Text)
T.act("setSpeed", 1)
frames(2)
noErrors("the level HUD")

T.section("monsters")
local level = player:GetAttribute("Wave")
local function send(lives: number, flat)
	field:FireClient(player, slot, level, lives, 10, flat)
	harness.flush()
end
-- Three monsters walking at the level's own speed (Config.levelPlan), five messages a second.
local walk = Config.levelPlan(level).speed
local d = { 10, 20, 330 }
send(10, { 1, d[1], 1, 0, 2, d[2], 1, 0, 3, d[3], 1, 0 })
frames(3)
eq(Field.count(slot), 3, "monsters tracked")
eq(Field.stats().models, 3, "monster models")
check(Field.lead(slot) ~= nil and Field.lead(slot):IsA("Model"), "Field.lead returns the lead monster's model")
local smooth = true
local last = Field.inspect(slot)[1].d
for _ = 1, 5 do
	for _ = 1, 6 do
		frames(1)
		local now = Field.inspect(slot)[1].d
		smooth = smooth and now > last and now - last < 1
		last = now
	end
	for index = 1, 3 do
		d[index] += walk * 0.2
	end
	send(10, { 1, d[1], 1, 0, 2, d[2], 0.6, 1, 3, d[3], 1, 2 })
end
check(smooth, "a monster moves a little every frame between messages")
check(math.abs(last - d[1]) < 2, `and stays where the server has it ({last} against {d[1]})`)
local seen = Field.inspect(slot)
check(not seen[1].bar, "an unhurt monster has no HP bar")
check(seen[2].bar, "a hurt one has")
-- The bar says the health in numbers: an ordinary monster what it has left, from the share the server sent
-- and the level's own max (Config.levelPlan).
eq(seen[2].health, T.Format.abbreviate(0.6 * Config.levelPlan(level).hp), "its bar carries what it has left as a number")
check(seen[2].numbered == true, "and shows it")
eq(seen[2].tint, 1, "a slowed monster is tinted")
eq(seen[3].tint, 2, "a burning monster is tinted")
check(seen[1].position ~= nil and math.abs(seen[1].position.X - Layout.plotCFrame(slot).X) < Layout.PLOT_WIDTH, "it stands on the player's plot")
-- What the server does to every tower of a player (the `towerRange` and `towerRate` modifiers: mastery,
-- enchants, powerups) reaches the show: with the range cut to a quarter the starter cannon no longer reaches
-- monster 3 at the gate, and stops firing.
local reachMult, rateMult = 1, 1
Game.modify("towerRange", function(_player, _data, _state, value: number): number
	return value * reachMult
end, "Test range")
Game.modify("towerRate", function(_player, _data, _state, value: number): number
	return value * rateMult
end, "Test rate")
local function playFor(rounds: number): number
	local most = 0
	for _ = 1, rounds do
		send(10, { 1, d[1], 1, 0, 2, d[2], 0.6, 1, 3, d[3], 1, 2 })
		for _ = 1, 6 do
			frames(1)
			most = math.max(most, Field.stats().shots + Field.stats().effects)
		end
	end
	return most
end
reachMult = 0.25
Game.sync(player)
eq(player:GetAttribute("TowerRange"), 0.25, "the server publishes TowerRange")
playFor(12) -- the client looks twice a second; what was in the air lands and fades
eq(playFor(8), 0, "a tower whose range was cut no longer fires at a monster outside it")
reachMult = 1
Game.sync(player)
-- Monster 3 is at the gate, inside the starter cannon's range. The messages keep coming while it is shot at.
local fired = 0
for _ = 1, 10 do
	send(10, { 1, d[1], 1, 0, 2, d[2], 0.6, 1, 3, d[3], 1, 2 })
	for _ = 1, 6 do
		frames(1)
		fired = math.max(fired, Field.stats().shots + Field.stats().effects)
	end
end
local stats = Field.stats()
print(`    towers {stats.towers}, most shots and effects at once {fired}`)
eq(stats.towers, 1, "the tower the server built is played")
check(fired > 0, "the tower fires at a monster in range")
-- Monster 2 dies, monster 3 walks through the gate (a life is lost).
send(9, { 1, d[1] + 2, 1, 0 })
frames(2)
eq(Field.count(slot), 1, "dead and leaked monsters are gone")
eq(Field.stats().models, 1, "and so are their models")
-- A boss level.
level = 5
send(10, { 50, 5, 1, 4 })
frames(5)
local boss = Field.inspect(slot)[1]
check(boss and boss.bar, "a boss shows its bar from the start")
do
	local max = Config.levelPlan(level).hp
	eq(boss.health, `{T.Format.abbreviate(max)} / {T.Format.abbreviate(max)}`, "with its health in numbers: left / max")
	check(boss.numbered == true, "showing")
	local left, most = Field.boss(slot)
	check(left == max and most == max, "Field.boss gives the level panel the same two numbers")
	send(10, { 50, 6, 0.25, 4 })
	frames(2)
	eq(Field.inspect(slot)[1].health, `{T.Format.abbreviate(0.25 * max)} / {T.Format.abbreviate(max)}`, "and the number follows the bar")
	local panel = ""
	for _, item in player.PlayerGui:GetDescendants() do
		if item:IsA("TextLabel") and string.find(item.Text, "BOSS", 1, true) and string.find(item.Text, " / ", 1, true) then
			panel = item.Text
		end
	end
	print(`    the level panel's boss line: {panel}`)
end
-- Far more monsters than may be drawn, on a normal level.
level = 6
local crowd = {}
for id = 1, 90 do
	table.move({ 100 + id, id * 3, 1, 0 }, 1, 4, #crowd + 1, crowd)
end
send(10, crowd)
frames(20)
stats = Field.stats()
eq(stats.monsters, 90, "a crowd is tracked")
check(stats.models <= 40, `but only so many are drawn ({stats.models})`)
do
	-- All of them hurt: every drawn one may have a bar (up to the cap), but only a few wear a number.
	for index = 3, #crowd, 4 do
		crowd[index] = 0.5
	end
	send(10, crowd)
	frames(2)
	local bars, numbered = 0, 0
	local list = Field.inspect(slot)
	local least, most = math.huge, -math.huge -- the numbered one least far along, the bare bar furthest along
	for _, monster in list do
		if monster.bar then
			bars += 1
			if monster.numbered then
				numbered += 1
				least = math.min(least, monster.server)
			else
				most = math.max(most, monster.server)
			end
		end
	end
	check(bars > 6, `a hurt crowd has its bars ({bars})`)
	check(numbered >= 1 and numbered <= 6, `but only a few of them wear their health as a number ({numbered})`)
	local furthest = least > most
	check(furthest, "the ones furthest along of those with a bar")
end
-- The owner of the plot left.
field:FireClient(player, slot, 0, 0, 0, {})
harness.flush()
frames(5)
eq(Field.stats().monsters, 0, "a plot whose owner left is cleared")
-- Nonsense must not break it.
field:FireClient(player, "x", nil, nil, nil, nil)
field:FireClient(player, 99, 3, 1, 1, { 1, 2 })
field:FireClient(player, slot, 3, 10, 10, { "a", 1, 1, 0, 7, 12, 0.5, 3 })
harness.flush()
frames(10)
noErrors("the battlefield")

T.section("tower window")
local window = Windows.byName.TOWER
check(window ~= nil, "the TOWER window is registered")
T.debug("coins", 1e9)
harness.fire(ProximityPromptService, "PromptTriggered", prompts[1], player)
check(window.frame.Visible, "the prompt of an owned pad opens it")
print("    " .. string.gsub(textOf(window.frame), "\n", " "))
check(buttonWith(window.frame, "UPGRADE") ~= nil, "a built pad offers UPGRADE")
local ring = workspace:FindFirstChild("TowerRange")
check(ring and ring.Transparency < 1, "the range ring is on the ground")
eq(ring.Size.Y, 60, "as wide as the tower's range")
reachMult, rateMult = 1.5, 2
Game.sync(player)
frames(3)
eq(ring.Size.Y, 90, "the ring follows the player's range bonus")
check(string.find(textOf(window.frame), "2 shots/s  •  range 45", 1, true) ~= nil, "and the window shows the real rate and range")
reachMult, rateMult = 1, 1
Game.sync(player)
frames(3)
eq(ring.Size.Y, 60, "and goes back with it")
eq(prompts[1].ActionText, "Upgrade", "the pad's prompt says what a press does")
harness.advance(0.2)
harness.click(buttonWith(window.frame, "UPGRADE"))
frames(2)
eq(data.towers["1"].level, 2, "UPGRADE buys a level")
harness.advance(0.2)
harness.click(buttonWith(window.frame, "LEVELS"))
frames(2)
eq(data.towers["1"].level, 12, "+10 buys ten")
check(string.find(textOf(window.frame), "LEVEL 12", 1, true) ~= nil, "the window follows")
harness.advance(0.2)
harness.click(buttonWith(window.frame, "MAX"))
frames(2)
check(data.towers["1"].level > 12, `MAX buys what the coins reach (level {data.towers["1"].level})`)
check(buttonWith(window.frame, "LAST") ~= nil, "the last tower cannot be sold")

harness.fire(ProximityPromptService, "PromptTriggered", prompts[2], player)
check(buttonWith(window.frame, "BUY PAD") ~= nil, "a pad that is not owned offers BUY PAD")
check(ring.Transparency == 1, "no ring on a pad without a tower")
T.debug("coins", 1e9)
harness.advance(0.2)
harness.click(buttonWith(window.frame, "BUY PAD"))
frames(2)
check(table.find(data.pads, 2) ~= nil, "BUY PAD buys it")
print("    " .. string.gsub(textOf(window.frame), "\n", " "))
check(buttonWith(window.frame, "BUILD") ~= nil, "an empty pad lists the towers")
check(buttonWith(window.frame, "LOCKED") ~= nil, "a kind that is not unlocked yet is locked")
harness.advance(0.2)
harness.click(buttonWith(window.frame, "BUILD"))
frames(2)
check(data.towers["2"] ~= nil, `BUILD builds ({data.towers["2"] and data.towers["2"].kind})`)
check(buttonWith(window.frame, "SELL") ~= nil, "the second tower can be sold")
harness.advance(0.2)
harness.click(buttonWith(window.frame, "SELL"))
frames(2)
check(data.towers["2"] ~= nil, "one press of SELL only asks")
harness.advance(0.2)
harness.click(buttonWith(window.frame, "SURE"))
frames(2)
check(data.towers["2"] == nil, "the second press sells")
window.close()
check(ring.Transparency == 1, "the ring goes with the window")

-- Somebody else's pad.
local other = Instance.new("ProximityPrompt")
other:SetAttribute("Pad", 3)
other:SetAttribute("Slot", slot % Layout.PLOT_COUNT + 1)
other.Parent = workspace
harness.fire(ProximityPromptService, "PromptTriggered", other, player)
check(not window.frame.Visible, "another player's pad opens nothing")
harness.advance(2)
harness.flush()
noErrors("the tower window")

T.section("every window still opens")
for name, entry in Windows.byName do
	entry.open()
	frames(2)
	entry.close()
end
for _, button in Hud.menu do
	harness.click(button)
	frames(1)
end
UI.closeWindows()
noErrors("opening every window")

T.section("a long fight")
level = 7
for tick = 1, 150 do
	local flat = {}
	for id = 1, 30 do
		local at = (tick * 1.2 + id * 9) % 359
		table.move({ 1000 + id + (tick * 1.2 + id * 9) // 359 * 100, at, 1 - (at / 359) * 0.9, id % 4 }, 1, 4, #flat + 1, flat)
	end
	send(10, flat)
	frames(6)
	if tick % 50 == 0 then
		T.debug("coins", data.coins + 1000 * tick)
	end
end
stats = Field.stats()
print(`    monsters {stats.monsters}, models {stats.models}, spare {stats.spare}, shots {stats.shots}, effects {stats.effects}, bars {stats.bars}, numbers {stats.numbers}`)
check(stats.models <= 40 and stats.bars <= 24 and stats.shots <= 36 and stats.numbers <= 14, "everything stays inside its cap")
local parts = 0
for _, item in workspace.Field:GetDescendants() do
	if item:IsA("BasePart") then
		parts += 1
	end
end
print(`    parts in workspace.Field: {parts}`)
noErrors("a long fight")

T.section("the level panel's boss line")
do
	-- The server's own field this time: a real boss level, and the panel reads the boss's health off it.
	T.debug("wave", 5)
	T.run(3)
	local line = nil
	for _, item in player.PlayerGui:GetDescendants() do
		if item:IsA("TextLabel") and string.match(item.Text, "^BOSS %d") then
			line = item.Text
		end
	end
	local max = Format.abbreviate(Config.levelPlan(5).hp)
	check(line ~= nil and string.find(line, "BOSS 5/" .. Config.WavesPerWorld, 1, true) == 1 and string.sub(line, -#(" / " .. max)) == " / " .. max, `the boss line carries the boss's health in numbers: {tostring(line)}`)
	local left, most = Field.boss(slot)
	check(left ~= nil and most == Config.levelPlan(5).hp and left <= most, "from Field.boss")
	noErrors("a boss level on the panel")
end
print(`{T.checks} checks passed`)
