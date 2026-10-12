-- The admin grant tool, both sides: who is an admin, what can be granted and how much at a time.
-- The server half is src/server/Features/Admin.luau (it checks, pays and logs), the window
-- src/client/Features/Admin.luau. Nothing here is trusted from the client: the server reads this file itself.
local Admin = {}

Admin.WINDOW = "ADMIN" -- the window, and its menu button (made for admins only)

-- Who may grant: [Roblox user id] = who that is. To add an admin, add a line and publish.
-- (The owner of a user-owned place is an admin too; the server checks that, see its isAdmin.)
Admin.IDS = {
	[7421324429] = "D1v991",
	-- TODO Yaani's user id: put it here, as `[1234567890] = "Yaani",`
}

-- What can be granted, in the order the window offers it. `cap` is the most in one grant; `needsId` kinds
-- name a thing of the game: an item (powerups, ammo, crates and keys are all backpack items) or a mini cannon.
Admin.KINDS = {
	{ id = "gems", name = "GEMS", cap = 100_000 },
	{ id = "coins", name = "COINS", cap = 1e15 },
	{ id = "candy", name = "CANDY", cap = 100_000 },
	{ id = "item", name = "ITEM / CRATE / KEY", cap = 100, needsId = true },
	{ id = "pet", name = "MINI CANNON", cap = 10, needsId = true },
}
Admin.Kind = {} -- [kind id] = its entry
for _, kind in Admin.KINDS do
	Admin.Kind[kind.id] = kind
end

Admin.NAME_MAX = 20 -- a Roblox username is 3 to 20 characters
Admin.ID_MAX = 80 -- an item's or a mini cannon's id (an enchanted mini cannon's is long)
Admin.PENDING_MAX = 50 -- grants that may wait for one player who is not here
Admin.QUEUE_MAX = 100 -- mini cannons that may wait for room in one player's storage
Admin.LOG_KEPT = 200 -- entries the log in the DataStore holds; the oldest go first
Admin.LOG_SHOWN = 6 -- entries the window shows

-- An amount as it may be granted: a whole number from 1 to the kind's cap, or nil.
function Admin.amount(kindId: any, value: any): number?
	local kind = Admin.Kind[kindId]
	if not kind or typeof(value) ~= "number" or value ~= value or value % 1 ~= 0 then
		return nil
	end
	if value < 1 or value > kind.cap then
		return nil
	end
	return value
end

-- What the admin typed as a target: a user id (a number, or only digits) or a username. Nil for anything else.
function Admin.target(value: any): (number?, string?)
	if typeof(value) == "number" then
		if value == value and value % 1 == 0 and value >= 1 and value < 2 ^ 53 then
			return value, nil
		end
		return nil, nil
	end
	if typeof(value) ~= "string" or #value > 4 * Admin.NAME_MAX then
		return nil, nil
	end
	local text = string.match(value, "^%s*(.-)%s*$") or ""
	if string.match(text, "^%d+$") and #text <= 16 then
		local id = tonumber(text)
		if id and id >= 1 then
			return id, nil
		end
		return nil, nil
	end
	if #text < 3 or #text > Admin.NAME_MAX or string.find(text, "[^%w_]") then
		return nil, nil
	end
	return nil, text
end

return Admin
