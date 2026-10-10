-- Runs before the server starts.
-- This test was written with rebirth in the game: switch it back on (Config.Rebirth.enabled is false for launch).
require(game:GetService("ReplicatedStorage").Shared.Config).Rebirth.enabled = true
