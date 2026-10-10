-- The FIRE button, both sides: a press is one shot of the player's own at the lead monster of their base.
-- The server half is src/server/Features/Blast.luau (it counts, deals the damage and levels the button up), the
-- button itself src/client/Features/Blast.luau.
--
-- Balance, in one place:
--   * a shot is worth a SHARE of the player's whole damage per second (towers and mini cannons, boosts and
--     all), never a share of a monster's health: it helps a base that is nearly strong enough and cannot carry
--     one that is not;
--   * the server counts at most RATE shots a second, however fast the button is pressed, so an auto-clicker
--     gains nothing over a fast thumb;
--   * pressing flat out therefore adds RATE x share: +20% damage at level 0, +50% at the last level. A 2x Power
--     boost adds +100%.
local Blast = {}

Blast.RATE = 5 -- shots a second the server counts
Blast.BURST = 5 -- shots that can be saved up while the button rests
Blast.BATCH_SECONDS = 0.4 -- the client sends its presses together this often
Blast.MAX_LEVEL = 50
Blast.SHARE = 0.04 -- of the damage per second, a shot, at level 0
Blast.SHARE_PER_LEVEL = 0.0012 -- more for each level: 10% at level 50

-- The save's defaults. xp: shots towards the next level. shots: every shot ever counted.
Blast.SAVED = { level = 0, xp = 0, shots = 0 }

-- The share of the damage per second one shot is worth at that level.
function Blast.share(level: number): number
	return Blast.SHARE + Blast.SHARE_PER_LEVEL * math.clamp(level, 0, Blast.MAX_LEVEL)
end

-- Shots it takes to go from that level to the next: 60, 100, 140 ... 52,000 for all fifty.
function Blast.need(level: number): number
	return 60 + 40 * level
end

return Blast
