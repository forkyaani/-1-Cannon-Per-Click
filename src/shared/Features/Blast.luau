-- The FIRE button, both sides: a press is one shot of the player's own at the lead monster of their base.
-- The server half is src/server/Features/Blast.luau (it counts, deals the damage and sells the levels), the
-- button and its FIRE window src/client/Features/Blast.luau.
--
-- Balance, in one place:
--   * a shot is worth a SHARE of the player's whole damage per second (towers and mini cannons, boosts and
--     all), never a share of a monster's health: it helps a base that is nearly strong enough and cannot carry
--     one that is not;
--   * the server counts at most RATE shots a second, however fast the button is pressed, so an auto-clicker
--     gains nothing over a fast thumb;
--   * pressing flat out therefore adds RATE x share: +20% damage at level 0, +50% at the last level. A 2x Power
--     boost adds +100%;
--   * a level is bought, with coins or with gems, never earned by pressing (Victor, 11 Oct 2026). The coin
--     price is what clearing a level of the game pays, a level twelve further on for each level of the button,
--     so it keeps step with the game; the gem price is small and flat, for a player who would rather keep
--     their coins for towers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Blast = {}

Blast.WINDOW = "FIRE" -- the window the button's UPGRADE chip opens

Blast.RATE = 5 -- shots a second the server counts
Blast.BURST = 5 -- shots that can be saved up while the button rests
Blast.BATCH_SECONDS = 0.4 -- the client sends its presses together this often
Blast.MAX_LEVEL = 50
Blast.SHARE = 0.04 -- of the damage per second, a shot, at level 0
Blast.SHARE_PER_LEVEL = 0.0012 -- more for each level: 10% at level 50

-- What a level costs. Coins: one clear of game level COIN_FIRST + COIN_STEP x (level - 1): level 3 for the
-- first, level 591 for the fiftieth, and never less than COIN_RISE times the level before (Earth's first
-- levels all pay alike, and a world with a coin rule can pay less than the one before it).
-- Gems: GEM_BASE + level: 6 for the first, 55 for the last, 1,525 for all.
Blast.COIN_FIRST = 3
Blast.COIN_STEP = 12
Blast.COIN_RISE = 1.25
Blast.GEM_BASE = 5

-- The save's defaults. shots: every shot ever counted.
Blast.SAVED = { level = 0, shots = 0 }

-- The share of the damage per second one shot is worth at that level.
function Blast.share(level: number): number
	return Blast.SHARE + Blast.SHARE_PER_LEVEL * math.clamp(level, 0, Blast.MAX_LEVEL)
end

-- Two significant digits, so a price looks hand-picked (Config's own prices are rounded the same way).
local function nice(n: number): number
	if n < 100 then
		return math.max(1, math.floor(n))
	end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / magnitude + 0.5) * magnitude
end

local coinCost = {}
for level = 1, Blast.MAX_LEVEL do
	local clear = Config.levelCoins(Blast.COIN_FIRST + Blast.COIN_STEP * (level - 1))
	coinCost[level] = nice(math.max(clear, (coinCost[level - 1] or 0) * Blast.COIN_RISE))
end

-- What `level` (the one being bought, 1 to MAX_LEVEL) costs in "coins" or in "gems". nil for anything else.
function Blast.cost(level: number, currency: string): number?
	if level < 1 or level > Blast.MAX_LEVEL or level ~= math.floor(level) then
		return nil
	end
	if currency == "coins" then
		return coinCost[level]
	elseif currency == "gems" then
		return Blast.GEM_BASE + level
	end
	return nil
end

-- "4.1%": a shot's share at that level, as the window and the toast say it.
function Blast.shareText(level: number): string
	return `{math.floor(Blast.share(level) * 1000 + 0.5) / 10}%`
end

return Blast
