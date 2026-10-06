-- Redeem codes, both sides: the list of codes and how a typed one is read.
-- The server half is src/server/Features/Codes.luau (it checks and pays), the window src/client/Features/Codes.luau.
--
-- To add a code, add a line to Codes.List. The key is the code as players type it, in CAPITALS, letters and
-- digits only (typing is not case-sensitive, and spaces around it are dropped). A reward can hold:
--   gems     that many gems
--   clears   coins worth that many clears of an ordinary level at the player's best level (Config.levelCoins),
--            so the same code is worth having in world 1 and in world 12
--   item     a backpack item's id (Items.define), with `amount` of them (1 when left out)
--   expires  optional: Codes.day(year, month, day), the last UTC day the code works. Without it, for ever.
-- Each player redeems a code once. Removing a line retires the code; players who used it keep what it paid.
local Codes = {}

Codes.WINDOW = "CODES" -- the window, and its menu button
Codes.MAX_LENGTH = 24 -- a longer text is not a code
Codes.COOLDOWN = 2 -- seconds a player waits between two tries, so codes cannot be guessed in bulk

-- The save's defaults. used[code] is the time (os.time) the player redeemed it.
Codes.SAVED = { used = {} }

-- The unix time at which that UTC day ends: what `expires` holds. Worked out by hand, because the tools that
-- check the game outside Studio have no os.time for a date.
function Codes.day(year: number, month: number, day: number): number
	-- Days since 1 January 1970 (the usual civil-calendar sum, with the year starting in March).
	local y = if month <= 2 then year - 1 else year
	local era = math.floor(y / 400)
	local yearOfEra = y - era * 400
	local dayOfYear = math.floor((153 * (month + (if month > 2 then -3 else 9)) + 2) / 5) + day - 1
	local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
	return (era * 146_097 + dayOfEra - 719_468 + 1) * 86_400
end

Codes.List = {
	-- PLACEHOLDER (Yaani): the one launch code. Change the word and the reward before the group page names it.
	LAUNCH = { gems = 100 },
	-- Examples of the other kinds:
	-- WEEKEND = { clears = 3, expires = Codes.day(2026, 12, 31) },
	-- BOOM = { item = "power2x", amount = 2 },
}

-- What the player typed as a key of Codes.List: trimmed and in capitals. Nil for anything that cannot be a
-- code (not text, empty, too long, or with a character that is not a letter or a digit).
function Codes.normalise(text: any): string?
	if typeof(text) ~= "string" or #text > 4 * Codes.MAX_LENGTH then
		return nil
	end
	local code = string.upper(string.match(text, "^%s*(.-)%s*$") or "")
	if #code == 0 or #code > Codes.MAX_LENGTH or string.find(code, "[^%u%d]") then
		return nil
	end
	return code
end

-- Whether a code's last day is over at `now` (os.time).
function Codes.expired(def, now: number): boolean
	return typeof(def.expires) == "number" and now >= def.expires
end

return Codes
