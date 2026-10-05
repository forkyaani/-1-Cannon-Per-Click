-- Stand-in for src/server/Plots.luau (docs/DEFENSE_SPEC.md, section 6): the plots and models are not needed
-- to test game logic. It records what the core asked for, so a test can check it.
local Plots = {
	built = false,
	owners = {}, -- [slot] = player
	worlds = {}, -- [slot] = world index
	pads = {}, -- [slot] = { pad indices }
	towers = {}, -- [slot] = { [pad] = { kind, level } }
	released = {}, -- slots, in the order they were released
	marketPrompts = {}, -- [slot] = that base's marketplace teleporter
	worldsPrompts = {}, -- [slot] = that base's islands teleporter (the core opens WORLDS for the owner)
}

function Plots.build()
	Plots.built = true
	for slot = 1, 12 do
		for kind, list in { market = Plots.marketPrompts, worlds = Plots.worldsPrompts } do
			local prompt = Instance.new("ProximityPrompt")
			prompt:SetAttribute("Slot", slot)
			prompt:SetAttribute("Teleporter", kind)
			list[slot] = prompt
		end
	end
end

function Plots.claim(slot: number, player: Player)
	Plots.owners[slot] = player
	Plots.towers[slot] = {}
end

function Plots.release(slot: number)
	Plots.owners[slot] = nil
	Plots.towers[slot] = nil
	Plots.pads[slot] = nil
	table.insert(Plots.released, slot)
end

function Plots.setWorld(slot: number, worldIndex: number)
	Plots.worlds[slot] = worldIndex
end

function Plots.setPads(slot: number, owned: { number })
	Plots.pads[slot] = table.clone(owned)
end

function Plots.setTower(slot: number, pad: number, kind: string?, level: number?)
	Plots.towers[slot][pad] = if kind then { kind = kind, level = level } else nil
end

function Plots.buildPets(slot: number, equipped: { string }, userId: number): Model
	return Instance.new("Model")
end

return Plots
