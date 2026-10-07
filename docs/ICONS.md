# Icons: every item in the game

Written 7 Oct 2026 for group Q of `docs/RELEASE_TASKS.md`. Yaani: "all of these need icons, basically all the
items in the game need icons like everything". Today a row built with `UI.row` shows a plain coloured oval
where its picture should be (18 call sites in 11 client files), and about 95 emoji stand in for icons in
text (💎 30 times, 💰 13, 🍬 10, ✨ 10, 🔒 9 ...).

## What exists

32 painted icons on two 1024 px atlases (4 x 4 cells of 256 px), drawn by `UI.icon(name)`:

- **A:** coin, gem, candy, power, rebirth, mastery, luck, egg, minicannon, cannon, store, missions, chest,
  trophy, backpack, gear
- **B:** market, worlds, trade, ammo, story, index, loot, gift, lock, clock, skull, crown, heart, tap, check,
  flame

Files in `assets/ui/`; made with Kling (`gemini-3-pro-image`, 2k, 20 credits a sheet) and cut with
`tools/icon_atlas.py`. Style: Candy Arcade stickers, thick plum outline, glossy, one object per cell on a
plain background.

## How each kind gets its picture (Q2: needs Yaani's yes)

| Kind | Picture | Why |
|---|---|---|
| Mini cannons, eggs | The Blender model in a 3D preview (`UI.preview`), as LOOT and the hatch already do | They have models; a painted icon would not match them |
| Everything else below | A painted icon on an atlas sheet, same style as A and B | No model exists, and they are read at 40 to 60 px |
| Towers | Painted for now; a render of the model once the towers are remodelled (after launch) | The towers are still plain parts |

Six new sheets, 16 cells each: about **120 Kling credits** if every sheet is right first time (2,738 left on
5 Oct). A sheet that comes out wrong is not resubmitted without asking.

## The sheets

**C. Boosts and passes (16):** power2x (2x Power), coins2x (2x Coins), candy2x (2x Candy), luck2x (2x Luck),
megaluck (Mega Luck), autotap (Overdrive), megadamage (Mega Damage), healfreeze (Deep Freeze), supercharge
(Supercharge), pass_triplehatch (x3 Egg Opener), pass_tripleluck (x3 Luck), pass_slots (+3 and +5 Mini
Cannon Slots, one icon with the number written by the game), pass_storage (+500 Storage), pass_speed (3x
Speed), pass_huge (HUGE Tycoon Cannon), slot (the weekly shop's +1 slot)

**D. Gems, keys and crates (16):** gems1 to gems6 (a few gems, a pouch, a bag, a chest, a vault, a mountain),
enchantkey, shinykey, bosschest, crate_daily, crate_wooden, crate_gem, crate_royal, crate_pumpkin,
crate_cursed, robux (the R$ mark's stand-in: a neutral coin stack, never Roblox's own logo)

**E. Ammo (10) and fight (6):** ammo_double, ammo_golden, ammo_flame, ammo_poison, ammo_frost, ammo_lucky,
ammo_boss, ammo_candy, ammo_void, ammo_rainbow; monster, boss, wave, shield (base health), speed, sale
(the FOR SALE pad)

**F. Worlds (12) and places (4):** one medallion per world: Earth, Moon, Mars, Neptune, The Sun, The Void,
Nebula, Crystal Belt, Robot Factory, Alien Jungle, Black Hole, The Big Bang; island, base, portal, fusion

**G. Towers (14) and missions (2):** Cannon, Gatling, Mortar, Sniper, Frost, Flame, Tesla, Rocket, Laser,
Venom, Blizzard, Railgun, Storm, Meteor; upgrade, hatch

**H. Enchantments (19 of 16: two sheets or the 16 most used):** Sharp, Rapid, Reach, Giant Slayer,
Splinter, Frostbite, Ember, Chain, Executioner, Greed, Treasure, Gem Finder, Lucky, Sweet Tooth, Bond, Long
Shot, Guardian, Tar, Scholar. Suggestion: one sheet of 16, and Bond, Tar and Scholar share the nearest
look (heart, clock) from sheet B until a seventh sheet is worth it.

Mastery's four tracks and twelve upgrades reuse these (power, speed, crown, coin, heart ...): no sheet of
their own.

## Where the icons go (Q7, Q8)

- Every item table gets an `icon` name: `Items` (powerups, ammo, keys, crates), `Config.Passes`,
  `Store.GemPacks`, `Store.Items`, `Config.EventShop`, the weekly shop, `Config.Missions`, `Config.Worlds`,
  `Config.Towers`, the enchantments.
- `UI.row` draws that icon in place of the oval; the oval stays only for a thing with no icon.
- Windows to go through: STORE, ISLAND SHOP, SHOP, BACKPACK, AMMO, CRATES, LOOT, MISSIONS, DAILY, WORLDS,
  TOWER, ENCHANT, FUSE, MASTERY, TRADE, the HUD chips and the notifications.
- The Roblox purchase prompts: the six gem packs and seven passes take an uploaded image each (Q9), cut from
  sheets C and D.

## Made on 7 Oct 2026

All six sheets were painted in one go (120 credits) and cut into `assets/ui/atlas-c.png` to `atlas-h.png`
(previews beside them, originals in `assets/ui/sheets/`). Cells run left to right, top to bottom, in the order
each sheet is listed above. Not yet uploaded to Roblox or wired into `UI.icon` (Q6).

Known weak spots, not regenerated: sheet H (enchantments) has glow halos and no white sticker edge, unlike
the others; sheet F's last cell (fusion) reads as a gatling gun; sheet D was cut with tolerance 65 because it
came back with a tile behind each icon, and a faint dark fringe is left on a few.
