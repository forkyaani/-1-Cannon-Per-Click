-- Analytics (docs/RELEASE_PLAN.md, B16): the funnel of a new player's first ten minutes and every Robux
-- purchase this server sees, sent to Roblox's AnalyticsService (Creator Hub, Analytics).
--
-- The funnel is for new players only: a step is logged once per player ever (`data.features.analytics.done`),
-- and a save that was played before this feature existed is kept out of it, so it does not pour seven steps
-- into the funnel on its first join. Nothing here changes the game, and nothing is ever sent from Studio or
-- from the offline emulator: `Feature.logger` is nil there, and with no logger nothing is logged or saved.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Passes = require(script.Parent.Parent.Passes)

local PASS_EVENT = "PassBought" -- custom events: the value is the price in Robux (0 when it is not known)
local PRODUCT_EVENT = "ProductBought"

-- The steps, numbered in the order a new player is expected to reach them. A player may reach them in any
-- other order: each is logged when it happens. `name` is what Creator Hub shows.
local STEPS = {
	joined = { step = 1, name = "Joined" },
	welcome = { step = 2, name = "Welcome done" },
	tower = { step = 3, name = "First tower built or upgraded" },
	level5 = { step = 4, name = "Level 5 cleared" },
	hatch = { step = 5, name = "First hatch" },
	level10 = { step = 6, name = "Level 10 cleared" },
	market = { step = 7, name = "First marketplace visit" },
}

local Feature = {}

Feature.STEPS = STEPS
-- What the events are sent to: AnalyticsService on a live server, nil in Studio (and in the emulator, where
-- Studio is on). A test puts a table with the same three methods here before the server starts.
Feature.logger = nil :: any

-- Every call to the logger goes through here: it must never be able to break the game.
local function send(method: string, ...): boolean
	local logger = Feature.logger
	if not logger then
		return false
	end
	local ok, err = pcall(function(...)
		logger[method](logger, ...)
	end, ...)
	if not ok then
		warn(`[Analytics] {method} failed: {err}`)
	end
	return ok
end

-- The key of a custom field, where this Roblox has them (the emulator's Enum makes one up).
local function fields(value: string): { [string]: string }?
	local ok, key = pcall(function()
		return (Enum :: any).AnalyticsCustomFieldKeys.CustomField01.Name
	end)
	return if ok and typeof(key) == "string" then { [key] = value } else nil
end

function Feature.start(Game)
	if Feature.logger == nil and not RunService:IsStudio() then
		local ok, service = pcall(game.GetService, game, "AnalyticsService")
		Feature.logger = if ok then service else nil
	end

	-- [player] = { tried = { [step id] = true }, towers = number?, passes = { [key] = true } }
	local sessions = {}

	-- This player's saved funnel, or nil when they are not in it (no logger, or an older save).
	local function funnel(player: Player, data)
		if not Feature.logger or not sessions[player] then
			return nil
		end
		local saved = data.features.analytics
		if typeof(saved) ~= "table" then
			-- lastSeen is 0 until a save is first written: anything else was played before the funnel existed.
			saved = Game.feature(data, "analytics", { old = data.lastSeen > 0, done = {} })
		end
		if saved.old or typeof(saved.done) ~= "table" then
			return nil
		end
		return saved
	end

	-- Logs a step unless this player has passed it before. A call that failed is not saved, so the next join
	-- tries again; `tried` keeps it from being sent twice a second until then.
	local function reach(player: Player, data, id: string)
		local saved = funnel(player, data)
		local session = sessions[player]
		if not saved or saved.done[id] or session.tried[id] then
			return
		end
		session.tried[id] = true
		local step = STEPS[id]
		if send("LogOnboardingFunnelStepEvent", player, step.step, step.name) then
			saved.done[id] = true
		end
	end

	-- How much tower the player has: pads built on plus every level. It only grows by building or upgrading.
	local function towerSum(data): number
		local sum = 0
		for _, tower in data.towers do
			sum += 1 + (tonumber(tower.level) or 0)
		end
		return sum
	end

	-- The steps that can be read off the save and the session. Cheap: it runs on every tick.
	local function look(player: Player, data, state)
		if not funnel(player, data) then
			return
		end
		local tutorial = data.features.tutorial
		if typeof(tutorial) == "table" and tutorial.welcomed == true then
			reach(player, data, "welcome")
		end
		if data.bestCleared >= 5 then
			reach(player, data, "level5")
		end
		if data.bestCleared >= 10 then
			reach(player, data, "level10")
		end
		if data.totalHatches > 0 then
			reach(player, data, "hatch")
		end
		if state.place == "market" then
			reach(player, data, "market")
		end
	end

	-- Developer products have no hook: the handlers the features registered are wrapped, so a purchase that
	-- was granted is logged. (A receipt Roblox sends a second time never reaches the handler.)
	local wrapped = {} -- [product id] = the wrapper put in Game.products
	local function wrapProducts()
		for productId, handler in Game.products do
			if wrapped[productId] ~= handler then
				local function logged(player: Player, ...)
					local granted = handler(player, ...)
					if granted then
						send("LogCustomEvent", player, PRODUCT_EVENT, 0, fields(tostring(productId)))
					end
					return granted
				end
				wrapped[productId] = logged
				Game.products[productId] = logged
			end
		end
	end

	Game.on("ready", function(player: Player, data, state)
		sessions[player] = { tried = {}, passes = table.clone(Passes.list(player)) }
		wrapProducts()
		reach(player, data, "joined")
		look(player, data, state)
	end)

	Game.on("leave", function(player: Player)
		sessions[player] = nil
	end)

	Game.on("tick", look)

	Game.on("waveCleared", function(player: Player, data, _state, wave: number)
		if wave >= 5 then
			reach(player, data, "level5")
		end
		if wave >= 10 then
			reach(player, data, "level10")
		end
	end)

	Game.on("hatch", function(player: Player, data)
		reach(player, data, "hatch")
	end)

	-- The towers before and after an action: more of them, or a higher level, is a build or an upgrade.
	Game.on("action", function(player: Player, data)
		local session = sessions[player]
		if session then
			session.towers = towerSum(data)
		end
	end)

	Game.on("acted", function(player: Player, data, state)
		local session = sessions[player]
		if not session then
			return
		end
		if session.towers and towerSum(data) > session.towers then
			reach(player, data, "tower")
		end
		session.towers = nil
		look(player, data, state)
	end)

	-- Game passes: Passes.changed says a player's passes changed. A pass they did not have a moment ago was
	-- just bought in the game (or given by the Studio override, where nothing is logged).
	Passes.changed:Connect(function(player: Player)
		local session = sessions[player]
		if not session then
			return
		end
		local now = Passes.list(player)
		for key in now do
			if not session.passes[key] then
				local pass = Config.Passes[key]
				send("LogCustomEvent", player, PASS_EVENT, if pass then pass.price or 0 else 0, fields(key))
			end
		end
		session.passes = table.clone(now)
	end)
end

return Feature
