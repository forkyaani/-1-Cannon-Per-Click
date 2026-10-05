-- Cannon ammo, server side: which ammo each slot fires, what it does to that slot's shots, the Ammo Forge and
-- boss drops. The ammo types and all their numbers live in the shared Ammo module.
-- The towers' slot (key "big") covers every tower shot, the mini cannons' slot every mini cannon shot: the
-- core's `shot` hook says which it is in shot.source. Burns and slows go on the monster the shot hits, in the
-- monster's own burn and slow fields, so the core deals the burn and the client shows both.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ammo = require(ReplicatedStorage.Shared.Features.Ammo)
local Build = require(script.Parent.Parent.Build)
local Marketplace = require(script.Parent.Parent.Marketplace)

local rgb = Color3.fromRGB
local STONE = rgb(150, 150, 158)
local WOOD = rgb(120, 84, 56)
local DARK = rgb(44, 46, 54)
local GOLD = rgb(255, 200, 40)
local EMBER = rgb(255, 120, 30)

local STANDARD = Ammo.byId[Ammo.STANDARD]
local CURRENCY_NAMES = { coins = "coins", diamonds = "gems" }

local SLOT_KEYS = {}
for _, slot in Ammo.Slots do
	SLOT_KEYS[slot.key] = true
end

-- Every ammo a boss can drop.
local drops = {}
for _, def in Ammo.Types do
	if def.dropOneIn then
		table.insert(drops, def)
	end
end

-- [player] = {
--   saved               the saved choice: { big = ammo id, mini = ammo id }
--   big, mini           one table per slot: def (the ammo it fires), and slowCut until slowUntil (how much
--                       slower its last hit made the monsters heal)
--   firing              the slot whose shot landed last, so a kill pays that slot's coin and candy bonus
--   lit, litTarget      the last burning shot and the monster it hit (nil once the burn is lit)
--   burnShare           that shot's ammo's burn
--   candyOwed           fractions of a bonus candy, carried to the next kill
--   lastRoll            when the last boss-drop roll was made
-- }
local sessions = {}

local function newSlot()
	return { def = STANDARD, slowCut = 0, slowUntil = 0 }
end

-- Loads an ammo into a slot and remembers the choice.
local function loadAmmo(session, key: string, def)
	session.saved[key] = def.id
	session[key].def = def
end

-- The monster a shot is about to hit. The `shot` hook does not say, so it is found the way the core picked
-- it: for a tower, the living monster furthest along the path inside its range; for a mini cannon, the one
-- furthest along with exactly the health the core put in state.hp and state.maxHp for this shot.
local function targetOf(state, shot)
	local tower = if shot.pad then state.towers[shot.pad] else nil
	local target, best = nil, -1
	if tower then
		for _, monster in state.monsters do
			if not monster.dead and monster.d > best then
				local dx, dz = monster.x - tower.x, monster.z - tower.z
				if dx * dx + dz * dz <= tower.range2 then
					target, best = monster, monster.d
				end
			end
		end
		if target and target.hp == state.hp then
			return target
		end
		target, best = nil, -1
	end
	for _, monster in state.monsters do
		if not monster.dead and monster.d > best and monster.hp == state.hp and monster.max == state.maxHp then
			target, best = monster, monster.d
		end
	end
	return target
end

-- A burning shot only lights its monster once the shot is over, when its damage is final: other features
-- change shot.damage too, and this way the burn is the same whichever hook ran first. The burn goes into the
-- monster's own burn (damage a second until burnUntil, on the plot's clock), on top of what is left of an
-- earlier one, as a Flame tower's does.
local function foldBurn(session, state)
	local lit, target = session.lit, session.litTarget
	if not lit then
		return
	end
	session.lit, session.litTarget = nil, nil
	local damage = lit.damage
	if not target or target.dead or typeof(damage) ~= "number" or damage ~= damage or damage <= 0 or damage == math.huge then
		return
	end
	local now = state.clock
	local left = target.burn * math.max(0, target.burnUntil - now)
	target.burnUntil = now + Ammo.BURN_SECONDS
	target.burn = (left + damage * session.burnShare) / Ammo.BURN_SECONDS
end

----------------------------------------------------------------------------------------------------
-- The Ammo Forge in the marketplace. Its prompt only opens the AMMO window, where the buying is done.
----------------------------------------------------------------------------------------------------
local function buildForge()
	local spot = Marketplace.frame(34, 0, 26).Position
	local statue = Marketplace.frame(0, 0, 0).Position
	-- Floor level with -Z facing the customer, like the stalls: the forge looks at the statue in the centre.
	local frame = CFrame.lookAt(spot, Vector3.new(statue.X, spot.Y, statue.Z))
	local model = Instance.new("Model")
	model.Name = "AmmoForge"

	local function block(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
		return Build.part({
			Name = name,
			Size = size,
			CFrame = frame * CFrame.new(offset),
			Color = color,
			Material = material,
			Parent = model,
		})
	end
	local function shell(offset: Vector3, size: number, color: Color3)
		Build.part({
			Name = "Shell",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = frame * CFrame.new(offset),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end

	-- Everything stands on a round floor 9.8 studs across, so the forge fits a 10 x 10 plot whichever way it faces.
	local top = 0.4
	Build.pillar(frame, 4.9, top, { Name = "ForgeFloor", Color = DARK, Material = Enum.Material.Slate, Parent = model })

	-- The furnace at the back, its fire facing the customer.
	block("Furnace", Vector3.new(4.2, 5.2, 2.8), Vector3.new(-1.3, top + 2.6, 1.8), STONE, Enum.Material.Brick)
	local fire = block("ForgeFire", Vector3.new(2.4, 2, 0.3), Vector3.new(-1.3, top + 1.8, 0.35), EMBER, Enum.Material.Neon)
	fire.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.5
	light.Color = EMBER
	light.Parent = fire
	local chimney = block("ForgeChimney", Vector3.new(1.5, 3.4, 1.5), Vector3.new(-1.3, top + 6.9, 2.2), DARK, Enum.Material.Brick)

	-- The anvil in front of the fire, with a shell being forged on it.
	block("AnvilFoot", Vector3.new(1.2, 1.1, 1), Vector3.new(-1.3, top + 0.55, -2), DARK, Enum.Material.Metal)
	local anvil = block("Anvil", Vector3.new(2.8, 0.7, 1.3), Vector3.new(-1.3, top + 1.45, -2), DARK, Enum.Material.Metal)
	shell(Vector3.new(-1.3, top + 2.3, -2), 1, EMBER)

	-- A rack showing one shell of every ammo type, two abreast.
	block("ForgeRack", Vector3.new(2.2, 1.8, 5.6), Vector3.new(2.6, top + 0.9, 0), WOOD, Enum.Material.Wood)
	local shown = 0
	for _, def in Ammo.Types do
		if not def.free then
			local side, row = shown % 2, shown // 2
			shell(Vector3.new(2.1 + side, top + 2.25, -2.2 + row * 1.1), 0.9, def.color)
			shown += 1
		end
	end

	-- The sign hangs over the chimney, a block: a billboard's offset follows its part's own axes.
	local gui = Build.billboard(chimney, Vector2.new(15, 3.4), Vector3.new(0, 4.2, 0), 220)
	local title = Build.label(gui, "💥 AMMO FORGE")
	title.Size = UDim2.fromScale(1, 0.58)
	title.TextColor3 = GOLD
	local how = Build.label(gui, "Special ammo for towers and mini cannons")
	how.Position = UDim2.fromScale(0, 0.6)
	how.Size = UDim2.fromScale(1, 0.4)

	Build.prompt(anvil, "Open", "Ammo Forge"):SetAttribute("Window", "AMMO")
	model.Parent = Marketplace.container()
end

----------------------------------------------------------------------------------------------------
local function start(Game)
	local rng = Game.random

	Game.on("ready", function(player: Player, data)
		local big = newSlot()
		local session = {
			saved = Game.feature(data, "ammo", { big = Ammo.STANDARD, mini = Ammo.STANDARD }),
			big = big,
			mini = newSlot(),
			firing = big,
			burnShare = 0,
			candyOwed = 0,
			lastRoll = 0,
		}
		sessions[player] = session
		-- A saved choice that is no longer owned, or no longer exists, starts on Standard.
		for _, slot in Ammo.Slots do
			loadAmmo(session, slot.key, Ammo.loaded(session.saved, data.items, slot.key))
		end
		Game.setMeta(player, "ammo", session.saved)
	end)

	Game.on("leave", function(player: Player)
		sessions[player] = nil
	end)

	-- Every effect on the shot itself multiplies shot.damage, so it stacks the same way with any other
	-- feature's change, whichever hook runs first.
	Game.on("shot", function(player: Player, _data, state, shot)
		local session = sessions[player]
		if not session then
			return
		end
		foldBurn(session, state)
		-- A tower's shot wears the towers' ammo; anything else is a mini cannon's.
		local slot = if shot.source == "tower" then session.big else session.mini
		session.firing = slot
		local def = slot.def
		if def.damage then
			shot.damage *= def.damage
		end
		if def.bossDamage and state.plan.kind ~= "normal" then
			shot.damage *= def.bossDamage
		end
		if def.doubleChance and rng:NextNumber() < def.doubleChance then
			shot.damage *= 2
		end
		if def.critChance and rng:NextNumber() < def.critChance then
			shot.damage *= def.critDamage
		end
		if def.healCut and (def.healChance >= 1 or rng:NextNumber() < def.healChance) then
			slot.slowCut = def.healCut
			slot.slowUntil = os.clock() + def.healSeconds
		end
		local slows = def.slow and (def.slowChance >= 1 or rng:NextNumber() < def.slowChance)
		if not slows and not def.burn then
			return
		end
		local target = targetOf(state, shot)
		if not target then
			return
		end
		-- The stronger slow wins, as between two Frost towers: an ammo's never replaces a stronger one that is
		-- still running.
		if slows and (state.clock >= target.slowUntil or def.slow >= target.slow) then
			target.slow = def.slow
			target.slowUntil = state.clock + def.slowSeconds
		end
		if def.burn then
			session.lit = shot
			session.litTarget = target
			session.burnShare = def.burn
		end
	end)

	-- Poison, void and the like: each slot's last hit may have left the monsters healing slower for a while
	-- (it only matters in the worlds whose monsters heal).
	Game.modify("heal", function(player: Player, _data, _state, value: number): number
		local session = sessions[player]
		if not session then
			return value
		end
		local now = os.clock()
		if session.big.slowUntil > now then
			value *= 1 - session.big.slowCut
		end
		if session.mini.slowUntil > now then
			value *= 1 - session.mini.slowCut
		end
		return value
	end, "Ammo: healing cut")

	Game.modify("coins", function(player: Player, _data, _state, value: number): number
		local session = sessions[player]
		local bonus = session and session.firing.def.coins
		return if bonus then value * (1 + bonus) else value
	end, function(player: Player): string?
		local session = sessions[player]
		return if session then `Ammo: {session.firing.def.name}` else nil
	end)

	-- One roll, at most one drop: each ammo owns a slice of the roll as wide as its chance.
	local function rollDrop(player: Player, wave: number)
		local roll = rng:NextNumber()
		for _, def in drops do
			roll -= 1 / def.dropOneIn
			if roll < 0 then
				if def.event and not Config.halloweenActive(os.time()) then
					return
				end
				Game.items.give(player, def.id, 1)
				if def.announce then
					Game.announce(`{player.DisplayName} found {def.name}! ({Ammo.oddsText(def)})`, "good")
				else
					local monster = Config.monsterFor(wave).name
					Game.notify(player, `{monster} dropped {def.name}! ({def.rarity}) Load it in AMMO`, "good")
				end
				return
			end
		end
	end

	Game.on("kill", function(player: Player, data, _state, info)
		local session = sessions[player]
		if not session then
			return
		end
		-- There is no candy modifier, so the bonus is paid here, on top of what the kill already paid.
		local bonus = session.firing.def.candy
		if bonus and Config.halloweenActive(os.time()) then
			local base = if info.kind == "normal" then Config.Halloween.candyPerKill else Config.Halloween.candyPerBoss
			if typeof(base) == "number" then
				session.candyOwed += base * bonus
				local whole = math.floor(session.candyOwed)
				if whole >= 1 then
					session.candyOwed -= whole
					data.candy += whole
				end
			end
		end
		if info.kind ~= "normal" then
			local now = os.clock()
			if now - session.lastRoll >= Ammo.DROP_COOLDOWN then
				session.lastRoll = now
				rollDrop(player, info.wave)
			end
		end
	end)

	Game.on("tick", function(player: Player, data, state)
		local session = sessions[player]
		if not session then
			return
		end
		-- Nothing tells a feature that an item left the backpack, so look: a traded-away ammo is unloaded.
		for _, slot in Ammo.Slots do
			local def = session[slot.key].def
			if not def.free and Game.items.count(data, def.id) < 1 then
				loadAmmo(session, slot.key, STANDARD)
				Game.setMeta(player, "ammo", session.saved)
				Game.notify(player, `{slot.name}: {def.name} is gone, back to {STANDARD.name}`, "info")
			end
		end
		foldBurn(session, state)
	end)

	-- A new level has new monsters: a shot that was waiting to light one of the old ones is forgotten.
	Game.on("levelStart", function(player: Player)
		local session = sessions[player]
		if session then
			session.lit, session.litTarget = nil, nil
		end
	end)

	-- argument: { slot = a slot key, id = an ammo id }. The window only offers what is possible, so a refusal
	-- (a stale or forged request) needs no message.
	function Game.actions.equipAmmo(player: Player, data, _state, argument: unknown)
		local session = sessions[player]
		if not session or typeof(argument) ~= "table" then
			return
		end
		local request = argument :: { slot: unknown, id: unknown }
		local key, id = request.slot, request.id
		local def = if typeof(id) == "string" then Ammo.byId[id] else nil
		if typeof(key) ~= "string" or not SLOT_KEYS[key] or not def then
			return
		end
		if not def.free and Game.items.count(data, def.id) < 1 then
			return
		end
		loadAmmo(session, key, def)
		Game.setMeta(player, "ammo", session.saved)
	end

	-- The forge sells an ammo only to a player who owns none: one is enough to load it in both slots.
	function Game.actions.buyAmmo(player: Player, data, _state, id: unknown)
		local def = if typeof(id) == "string" then Ammo.byId[id] else nil
		local price = def and def.price
		if not price or Game.items.count(data, def.id) > 0 then
			return
		end
		if data[price.currency] < price.cost then
			Game.notify(player, `Not enough {CURRENCY_NAMES[price.currency]} for {def.name}`, "bad")
			return
		end
		data[price.currency] -= price.cost
		Game.items.give(player, def.id, 1)
		Game.notify(player, `Forged {def.name}! Load it for your towers or your mini cannons`, "good")
	end

	buildForge()
end

return { start = start }
