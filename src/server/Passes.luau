-- Game passes: who owns what. The one place for ownership checks, purchase prompts and the Studio test override.
-- Pass definitions (ids, names, prices) live in Config.Passes; a pass with id 0 is not on sale yet.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Passes = {}

local owned = {} -- [player] = { [pass key] = true }
local changed = Instance.new("BindableEvent")

-- Fires with the player whenever their passes change (a purchase, or the Studio override).
Passes.changed = changed.Event

function Passes.owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

-- The player's passes as { [key] = true }, for sending to their client.
function Passes.list(player: Player): { [string]: boolean }
	return owned[player] or {}
end

-- Yields: asks Roblox which passes the player owns. Call once when they join.
-- Nobody starts with a pass they have not bought, in Studio either; setForTesting gives one for a test.
function Passes.load(player: Player)
	local set = {}
	for key, pass in Config.Passes do
		if pass.id ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and result then
				set[key] = true
			elseif not ok then
				warn(`[Passes] ownership check failed for {key}: {result}`)
			end
		end
	end
	owned[player] = set
end

function Passes.unload(player: Player)
	owned[player] = nil
end

-- Opens the Roblox purchase prompt. Returns false when the pass is not on sale yet (id 0).
function Passes.prompt(player: Player, key: string): boolean
	local pass = Config.Passes[key]
	if not pass or pass.id == 0 then
		return false
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
	return true
end

-- Studio only: give or remove a pass without buying it, to test what it does.
function Passes.setForTesting(player: Player, key: string, value: boolean)
	if not RunService:IsStudio() or not Config.Passes[key] or not owned[player] then
		return
	end
	owned[player][key] = if value then true else nil
	changed:Fire(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	if not purchased or not owned[player] then
		return
	end
	for key, pass in Config.Passes do
		if pass.id == passId then
			owned[player][key] = true
			changed:Fire(player)
		end
	end
end)

return Passes
