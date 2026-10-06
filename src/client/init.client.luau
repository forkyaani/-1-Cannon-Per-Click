-- Client entry point: wires the HUD, the windows, the marketplace, the battlefield and the world effects
-- together, then starts every feature module in Features (docs/ARCHITECTURE.md).
-- The player walks everywhere with Roblox's own camera and controls: nothing here listens for taps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Roblox's own health bar and backpack have no use here: nobody takes damage and there are no tools.
-- The call fails while the core scripts are still loading, so it is tried until it goes through.
task.spawn(function()
	for _ = 1, 20 do
		local done = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if done then
			return
		end
		task.wait(0.5)
	end
end)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))
local Items = require(ReplicatedStorage.Shared:WaitForChild("Items"))
ReplicatedStorage.Shared:WaitForChild("Layout")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("Action")
local notifyRemote = remotes:WaitForChild("Notify")
local hatchRemote = remotes:WaitForChild("Hatch")
local featureRemote = remotes:WaitForChild("Feature")

local State = require(script.State)
local UI = require(script.UI)
local Hud = require(script.Hud)
local Windows = require(script.Windows)
local Field = require(script.Field)
local Effects = require(script.Effects)
local Market = require(script.Market)
local Loot = require(script.Loot)

local TICK_SECONDS = 0.25

local function act(name: string, argument: any?)
	actionRemote:FireServer(name, argument)
end

for action, button in Hud.actions do
	button.Activated:Connect(function()
		act(action)
	end)
end
-- Both places are walking views, so the HUD wears its marketplace layout everywhere, and that layout's one
-- travel button goes both ways. (The cannon-view pieces of the HUD stay hidden until its owner folds the two
-- layouts into one; the level's own HUD is src/client/Features/Defense.luau.)
Hud.setMode(true)
Hud.backButton.Activated:Connect(function()
	act(if State.get("InMarket", false) == true then "goHome" else "goMarket")
end)
-- What is pinned beside the MORE button: on the plot the windows a defender reaches for, in the marketplace
-- what the HUD pins there. (Hud.PINNED.market is the list the marketplace layout reads.)
local MARKET_PINS = table.clone(Hud.PINNED.market)
table.insert(MARKET_PINS, 1, "BASE")
local PLOT_PINS = { "STORE", "MARKET", "WORLDS" }

-- The core menu. Features add their own buttons after these (orders 10 and up are free).
local rgb = Color3.fromRGB
-- On the plot the way to the marketplace is one of the pinned menu buttons; the big travel button only shows
-- in the marketplace and on islands, as the way back.
Hud.addMenuButton("MARKET", rgb(255, 150, 60), 1, function()
	act("goMarket")
end)
Hud.addMenuButton("BASE", rgb(255, 150, 60), 1, function()
	act("goHome")
end)
for order, entry in {
	{ "STORE", rgb(60, 170, 230) },
	{ "MINI CANNONS", rgb(120, 120, 220) },
	{ "WORLDS", rgb(60, 170, 120) },
	{ "MISSIONS", rgb(200, 90, 200) },
	{ "DAILY", rgb(230, 90, 90) },
	{ "TOP PLAYERS", rgb(200, 160, 40) },
} do
	local name = entry[1]
	Hud.addMenuButton(name, entry[2], order + 1, function()
		Windows.byName[name].toggle()
	end)
end

-- The world tab on the wave cluster is a shortcut to the WORLDS window.
Hud.worldTab.Activated:Connect(function()
	Windows.byName.WORLDS.toggle()
end)

----------------------------------------------------------------------------------------------------
-- What a feature module gets: ctx. A feature returns { start = function(ctx) end }.
----------------------------------------------------------------------------------------------------
local channels = {} -- server -> client feature messages: [channel] = { handlers }
local flagProviders = {} -- [menu button name] = function() -> boolean: whether to show "!" on it

featureRemote.OnClientEvent:Connect(function(channel: string, ...)
	for _, handler in channels[channel] or {} do
		task.spawn(handler, ...)
	end
end)

local ctx = {
	Config = Config,
	Format = Format,
	Items = Items,
	State = State,
	UI = UI,
	Hud = Hud,
	Windows = Windows,
	Effects = Effects,
	Field = Field,
	Loot = Loot,
	act = act,
}

-- Listens for Game.send(player, channel, ...) from the server.
function ctx.on(channel: string, handler: (...any) -> ())
	channels[channel] = channels[channel] or {}
	table.insert(channels[channel], handler)
end

-- The server opens a window: a base's WORLDS teleporter does, for the base's owner only (Game.start).
ctx.on("window", function(name: unknown)
	local window = if typeof(name) == "string" then Windows.byName[name] else nil
	if window then
		window.open()
	end
end)

-- Kept so features written for the tap clicker still start: there is no tap to fire any more, so a hook
-- registered here is never called.
function ctx.onTap(_hook: (position: Vector3) -> boolean?) end

-- Shows "!" on a menu button while provider() is true.
function ctx.flag(buttonName: string, provider: () -> boolean)
	flagProviders[buttonName] = provider
end

local featureFolder = script:WaitForChild("Features", 5)
local features = if featureFolder then featureFolder:GetChildren() else {}
table.sort(features, function(a, b)
	return a.Name < b.Name
end)
for _, module in features do
	if module:IsA("ModuleScript") then
		-- One broken feature must not take the whole HUD down with it.
		local ok, err = pcall(function()
			require(module).start(ctx)
		end)
		if not ok then
			warn(`[Client] feature {module.Name} failed to start and was skipped: {err}`)
		end
	end
end

----------------------------------------------------------------------------------------------------
local inMarket: boolean? = nil
local function refresh()
	local market = State.get("InMarket", false) == true
	if market ~= inMarket then
		inMarket = market
		UI.closeWindows()
		Hud.backButton.Text = if market then "BACK TO\nBASE" else "GO TO\nMARKET"
		Hud.PINNED.market = if market then MARKET_PINS else PLOT_PINS
		Hud.setMode(true)
	end
	local travel = Hud.backButton.Parent
	if travel and travel:IsA("GuiObject") then
		travel.Visible = false
	end
	Hud.refresh()
	Windows.refresh()
	local flags = Windows.flags()
	for name, provider in flagProviders do
		local ok, flagged = pcall(provider)
		flags[name] = ok and flagged == true
	end
	Hud.setFlags(flags)
	Market.refresh()
end
State.onChange(refresh)
refresh()

notifyRemote.OnClientEvent:Connect(Hud.toast)
hatchRemote.OnClientEvent:Connect(Effects.hatch)
Field.start()
Effects.start()
Market.start(function(name: string)
	local window = Windows.byName[name]
	if window then
		window.open()
	end
end)

task.spawn(function()
	while true do
		Hud.tick()
		Windows.tick()
		task.wait(TICK_SECONDS)
	end
end)
