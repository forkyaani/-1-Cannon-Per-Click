-- Playtime gifts, friend bonus and badges: the small things that reward staying and coming back with friends.
-- Both sides read this file. The server halves are src/server/Features/Gifts.luau (playtime gifts),
-- Friends.luau and Badges.luau; the window is src/client/Features/Gifts.luau.
-- Everything here is small on purpose: a full day of playtime gifts is less than the daily missions pay.
local Gifts = {}

Gifts.WINDOW = "GIFTS" -- the window, and its menu button

-- Playtime gifts: one a step, claimed by hand, for minutes played today (UTC day, on any server). `item` is a
-- backpack item's id (Items.define).
Gifts.List = {
	{ minutes = 5, gems = 5 },
	{ minutes = 10, gems = 5, item = "coins2x" },
	{ minutes = 20, gems = 10 },
	{ minutes = 30, gems = 15, item = "luck2x" },
}
-- The save's defaults. day: the UTC day the seconds and claims belong to.
Gifts.SAVED = { day = 0, seconds = 0, claimed = {} }

-- Friend bonus: more coins for every Roblox friend on the same server, up to a cap.
Gifts.FRIEND_COINS = 0.1 -- +10% a friend
Gifts.FRIEND_MAX = 3 -- friends that count

-- Badges. `id` is the badge's id on Roblox (Creator Hub > the experience > Engagement > Badges); a badge with
-- id 0 is simply not awarded. The four were made on 10 Oct 2026; their pictures are assets/page/badges/.
Gifts.Badges = {
	hatch = { id = 2871747086110144, name = "First Hatch", desc = "Hatch your first egg" },
	boss = { id = 68919119244639, name = "Boss Buster", desc = "Defeat your first boss" },
	world = { id = 1918327233301024, name = "World Clear", desc = "Clear every level of Earth" },
	rebirth = { id = 2404591004498051, name = "Reborn", desc = "Rebirth for the first time" },
}

-- What a gift pays, as text: "+5 gems  •  +1 2x Coins".
function Gifts.rewardText(gift, itemName: (id: string) -> string): string
	local parts = {}
	if (gift.gems or 0) > 0 then
		table.insert(parts, `+{gift.gems} gems`)
	end
	if gift.item then
		table.insert(parts, `+1 {itemName(gift.item)}`)
	end
	return table.concat(parts, "  •  ")
end

return Gifts
