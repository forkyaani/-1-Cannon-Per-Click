-- Powerups, client half. Nothing of a powerup is drawn by this file any more:
--   the boosts' names and time left are on the HUD (Config.Boosts) and in the BACKPACK window
--   Deep Freeze shows as the slowed tint Field gives every slowed monster
--   Overdrive's extra shots are the server's; Field draws each tower at its normal rate
-- It stays as the place for a powerup's own effects on screen, and requires the shared module so its boosts
-- and items are known to this client whatever starts first.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Powerups"))

local Feature = {}

function Feature.start(_ctx) end

return Feature
