-- The MINI CANNONS window, server half: equipping by hand, deleting, locks and loadouts. The rules are the
-- shared module's (src/shared/Features/Minis.luau).
-- Saved under the feature "minis": manual (false while the strongest are equipped automatically), picks (what
-- the player equipped by hand, in order), locked ({ [id] = true }) and loadouts ({ [slot as a string] = ids }).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Minis = require(ReplicatedStorage.Shared.Features.Minis)

local SAVED = { manual = false, picks = {}, locked = {}, loadouts = {} }

local Feature = {}

function Feature.start(Game)
	local function saved(data)
		local store = Game.feature(data, "minis", SAVED)
		-- A save from before a field existed, or one that lost its shape.
		for key, default in SAVED do
			if typeof(store[key]) ~= typeof(default) then
				store[key] = if typeof(default) == "table" then {} else default
			end
		end
		return store
	end

	local function publish(player: Player, data)
		local store = saved(data)
		Game.setMeta(player, "minis", { manual = store.manual, locked = store.locked, loadouts = store.loadouts })
	end

	-- The core asks this whenever it works out what is equipped: nil leaves it to pick the strongest.
	Game.equipPicker = function(_player: Player, data, slots: number): { string }?
		local store = saved(data)
		if not store.manual then
			return nil
		end
		return Minis.resolve(data.pets, store.picks, slots)
	end

	-- Picking by hand starts from what is equipped now.
	local function takeOver(player: Player, data)
		local store = saved(data)
		if not store.manual then
			store.manual = true
			store.picks = table.clone(Game.equipped(player))
		end
		return store
	end

	local function apply(player: Player, data)
		Game.refreshPets(player)
		publish(player, data)
	end

	Game.actions.minisEquip = function(player: Player, data, _state, id: unknown)
		if typeof(id) ~= "string" then
			return
		end
		local why = Minis.cannotEquip(data.pets, Game.equipped(player), Game.equipSlots(player), id)
		if why then
			Game.notify(player, why, "bad")
			return
		end
		local store = takeOver(player, data)
		store.picks = table.clone(Game.equipped(player))
		table.insert(store.picks, id)
		apply(player, data)
	end

	Game.actions.minisUnequip = function(player: Player, data, _state, id: unknown)
		if typeof(id) ~= "string" then
			return
		end
		local equipped = table.clone(Game.equipped(player))
		local index = table.find(equipped, id)
		if not index then
			return
		end
		local store = takeOver(player, data)
		table.remove(equipped, index)
		store.picks = equipped
		apply(player, data)
	end

	Game.actions.minisBest = function(player: Player, data)
		local store = saved(data)
		store.manual, store.picks = false, {}
		apply(player, data)
		Game.notify(player, "Your strongest mini cannons are equipped", "good")
	end

	Game.actions.minisUnequipAll = function(player: Player, data)
		local store = saved(data)
		store.manual, store.picks = true, {}
		apply(player, data)
	end

	Game.actions.minisLock = function(player: Player, data, _state, id: unknown)
		if typeof(id) ~= "string" or not Config.Pets[id] then
			return
		end
		local store = saved(data)
		-- Only a mini the player has can be locked; a lock left behind can always be taken off.
		if not store.locked[id] and Game.pets.count(data, id) < 1 then
			return
		end
		store.locked[id] = if store.locked[id] then nil else true
		publish(player, data)
	end

	-- argument: { [id] = how many }. Equipped copies are the last to go (Game.pets.remove takes from the end of
	-- the list, and what is equipped is worked out again afterwards).
	Game.actions.minisDelete = function(player: Player, data, _state, argument: unknown)
		local store = saved(data)
		local wanted, total = Minis.checkDelete(data.pets, store.locked, argument)
		if not wanted then
			Game.notify(player, total :: string, "bad")
			return
		end
		for id, amount in wanted do
			Game.pets.remove(player, id, amount)
		end
		publish(player, data)
		Game.notify(player, `Deleted {total} mini cannon{if total == 1 then "" else "s"}`, "info")
	end

	-- argument: { slot = 1 .. Minis.LOADOUTS, save = boolean }. Saving stores what is equipped now; without
	-- `save` the loadout is equipped (what of it the player still owns).
	Game.actions.minisLoadout = function(player: Player, data, _state, argument: unknown)
		if typeof(argument) ~= "table" then
			return
		end
		local slot, save = (argument :: any).slot, (argument :: any).save == true
		if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > Minis.LOADOUTS then
			return
		end
		local store = saved(data)
		local key = tostring(slot)
		if save then
			store.loadouts[key] = table.clone(Game.equipped(player))
			publish(player, data)
			Game.notify(player, `Loadout {slot} saved`, "good")
			return
		end
		local loadout = store.loadouts[key]
		if typeof(loadout) ~= "table" or #loadout == 0 then
			Game.notify(player, `Loadout {slot} is empty: press SAVE, then {slot}`, "info")
			return
		end
		store.manual, store.picks = true, table.clone(loadout)
		apply(player, data)
		Game.notify(player, `Loadout {slot} equipped`, "good")
	end

	Game.on("ready", function(player: Player, data)
		-- A save that was left in manual mode: the core picked before this feature could answer.
		if saved(data).manual then
			Game.refreshPets(player)
		end
		publish(player, data)
	end)
end

return Feature
