-- Stand-in for src/server/Marketplace.luau: no town square, just one hatch prompt per egg.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Marketplace = { eggPrompts = {}, tripleEggPrompts = {}, returnPrompt = nil, promptFor = {} }

-- stands: [egg id] = { frame, parent }, what a stand was built with.
Marketplace.stands = {}

function Marketplace.buildEggStand(egg, frame: CFrame, parent: Instance)
	local prompt = Instance.new("ProximityPrompt")
	prompt:SetAttribute("EggId", egg.id)
	Marketplace.eggPrompts[prompt] = egg.id
	Marketplace.promptFor[egg.id] = prompt
	local triple = Instance.new("ProximityPrompt")
	Marketplace.tripleEggPrompts[triple] = egg.id
	Marketplace.stands[egg.id] = { frame = frame, parent = parent }
end

-- As the real one: a world's coin eggs stand on its island (src/server/Islands.luau builds those stands).
function Marketplace.cover() end

function Marketplace.build()
	for _, egg in Config.Eggs do
		if not egg.world then
			Marketplace.buildEggStand(egg, CFrame.new(), workspace)
		end
	end
end

function Marketplace.setBoard() end

function Marketplace.frame(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

function Marketplace.container()
	return workspace
end

return Marketplace
