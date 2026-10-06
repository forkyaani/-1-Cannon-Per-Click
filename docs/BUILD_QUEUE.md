# Build queue (decided with Yaani, 4 Oct 2026)

Everything below is decided. Build it in this order without asking again.

## 0. Land the idle defence rebuild (in progress)

Workflow finishes feature adaptation and verification in the staging tree. Then: merge staging into `src`
(`tools/merge_work.py base2 stage live`), delete `src/server/Arena.luau`, smoke test, start Studio, look at it.

## 0b. Remove the Combat feature (decided 4 Oct: "excess noise")

Delete the three `Features/Combat.luau` files: no Mega Blast, no critical hits, no weak points, no Power Orb,
no combo. Remove Combat's mentions from the story, the docs and Huge (Storm's multi-hit and Executioner stay:
they are Huge features, not Combat).

## 0c. Pace and leaderboards (decided 4 Oct)

- Yaani's "island 1 to 12 in 10 minutes" was the old clicker. The new core is tuned for about 9 minutes for the
  first 10 levels, 75 to 90 minutes for Earth and about 44 hours for all 12 worlds free-to-play, with roughly
  one level in six failing first try (`docs/BALANCE.md`). Keep that as the floor; the balance pass must hold
  it with Huge, mastery, enchants and powerups switched on, and may only make it longer.
- **Leaderboards (decided):** Gems, Rebirths, Cannon Power. Cannon Power is the player's total DPS (all towers
  with every bonus) and is the headline number on the HUD under that name.
- **Rebirth returns as a rare prestige (decided):** allowed only after beating a world's final boss. It resets
  levels, coins, pads and towers; it keeps mini cannons, gems, items, mastery, enchants and story progress;
  it gives a permanent +5% tower damage per rebirth (decided) and a gem reward. Each rebirth needs one world further than
  the last (first after Earth, second after the Moon ...), so a whole playthrough holds a handful.
  No auto-rebirth pass.
- Incentives to grind: world islands with new eggs, mastery (island 3), enchanting and fusing (island 5),
  the story chapter rewards, first-clear Boss Chests, daily missions and the daily crate.

## 1. Huge nerf (decided: x3)

| | Value |
|---|---|
| `Config.HugePower` | 3 |
| Huge Shot | 5 mini cannon shots (`Game.shotDamage`) every 2 s, only at monsters within `petRange` of the player |
| Tycoon | x2 coins, auto-upgrades the cheapest tower |
| Slayer | x3 boss damage |
| Storm | 25% of shots hit twice |
| Gatling | 5 shots a second |
| Hex | monsters heal 50% slower |
| Clover | x2 luck |
| Golden Goose | 1 egg in 4 free |
| Executioner | finishes monsters under 15% health |
| Gemstone | 1 gem per boss, 50 a day |
| Pumpkin | x2 candy, x2 crate drops |

Files: `src/shared/Config.luau` (HugePower, HugeShot), the three `Features/Huge.luau`. One agent or by hand.

## 2. Islands (decided: portals + WORLDS menu, all 12 from one template)

- One island per world: its two coin eggs, a themed shop stall, a portal back. Recoloured and re-propped from
  `Config.Worlds[index]`. Unlocked when the player reaches that world (`bestCleared >= (index - 1) * 50`).
- Travel: a portal on the plot street and an ISLAND button per row in the WORLDS window. Server action
  `goIsland(index)`; `state.place` becomes "plot", "market" or "island" (today `inMarket`).
- The marketplace hub keeps: Gem Egg, Halloween eggs, crates, trading, store, daily, missions, leaderboards,
  fusion machine. Its coin egg stands are removed.
- Island shop: that world's ammo for coins, one rotating powerup, the world's Boss Chest once a day.
- Files: new `src/server/Islands.luau` (+ `Layout` island positions), egg stand builder shared with the
  marketplace (`Marketplace.buildEggStand` is owned by the UI session: ask it to expose it, do not copy it),
  `Game.luau` (`goIsland`, place handling), `src/client/Windows.luau` (WORLDS rows), a client feature for the
  island shop window. Coordinate with the UI session before touching `Marketplace.luau`.

## 3. Mastery (decided: all four groups; unlocked at island 3, Mars)

A shrine on the Mars island opens the MASTERY window. Tracks are bought level by level with gems; cost rises
with each level. Saved under `Game.feature(data, "mastery")`.

| Group | Track | Effect per level |
|---|---|---|
| Tower | Attack | +tower damage |
| Tower | Fire rate | towers shoot faster |
| Tower | Range | +range |
| Tower | Boss damage | +damage to bosses |
| Mini cannon | Bond | +mini cannon bonus |
| Mini cannon | Rapid | faster mini cannon shots |
| Mini cannon | Slots | +1 equip slot at set levels |
| Economy | Coins | +coins per kill |
| Economy | Luck | +egg luck |
| Economy | Discount | cheaper tower upgrades |
| Survival | Lives | +lives per level |
| Survival | Slow | monsters walk slower |
| Survival | Offline | offline earnings (needs the offline system) |

The kill-based "Cannon Mastery" in the core is renamed "Veteran" so there is one thing called Mastery.
Needs from the core: modifier kinds for tower rate, range, lives, monster speed and upgrade cost
(`Game.modify`), added when this is built. Numbers are tuned with `tools/balance`.

## 4. Enchanting (Yaani's spec; unlocked at island 5, The Sun): BUILT (5 Oct, staging tree)

As built: `Features/Enchant.luau` x3, "Enchanting" in `docs/ARCHITECTURE.md`, numbers in `docs/BALANCE.md`
section 5d. Differences from the draft below: Scholar speeds up Veteran progress only (mastery is bought with
gems, there is no progress to speed up); the shot enchantments (Frostbite, Ember, Chain) are a chance per shot,
so stacking makes them trigger more often; Gem Finder has a limit of 30 gems a day; missions do not pay keys
yet (a mission pays gems only); the plain key is sold on the island shops from The Sun's on.

An enchanting table on The Sun's island opens the ENCHANT window.

- **Cost:** gems plus one key per use. Gems scale with the mini cannon's rarity (Common cheapest, Secret and
  Huge dearest).
- **Enchantment Key:** rolls 1 to 3 enchantments, each at a random level I to III.
- **Shiny Enchantment Key:** always 3 enchantments, at least two of them level III.
- A mini cannon holds at most 3 enchantments. Enchanting again replaces what it had (the window says so first).
- **20 enchantments, each with levels I to III**, giving perks and bonuses (19 since 5 Oct: Quick Draw was
  removed and Long Shot became mini cannon DPS, see "Mini cannons deal flat DPS" below). Draft list:
  Sharp (tower damage), Rapid (tower fire rate), Reach (tower range), Giant Slayer (boss damage),
  Splinter (shots splash), Frostbite (shots slow), Ember (shots burn), Chain (shots jump),
  Executioner (finish low-health monsters), Greed (coins), Treasure (crate drops), Gem Finder (boss gems),
  Lucky (egg luck), Sweet Tooth (candy), Bond (this mini cannon's own bonus), Quick Draw (mini cannon fire
  rate), Long Shot (mini cannon range), Guardian (extra lives), Tar (monsters walk slower), Scholar (mastery
  and veteran progress). Only equipped mini cannons count; the same enchantment on several mini cannons stacks, with no cap.
- **Keys** are backpack items (tradable): from Boss Chests, the Daily Crate, island shops for gems, missions.
  Shiny keys: rare crate rows, the Royal Crate, a Robux product (id 0 until created).
- **How an enchanted mini cannon is stored:** the save keeps mini cannons as id strings, so an enchanted one is
  its id plus a suffix, `wooden_gold~sharp3.greed1`, and `Config.Pets` resolves such ids on demand (a
  metatable that parses the suffix and returns the base entry with `enchants` filled in). Any mini cannon can be
  fused, enchanted or not (see Fusing below). Trading,
  storage and the loot viewer then work unchanged. Enchanted ones show their enchantments in MINI CANNONS and
  in the trade window.
- Needs the same extra modifier kinds as Mastery (tower rate, range, lives, monster speed), so build it after
  Mastery. Enchant odds are shown in the window (random paid items need their odds disclosed).

## 5. Fusing revamp (Yaani's spec; unlocked at island 5, with the enchanting table): BUILT (5 Oct, staging tree)

As built: `Features/Fuse.luau` x3, "Fusing" in `docs/ARCHITECTURE.md`. The story's fuse quests: none in the
tutorial any more; chapters 5, 7, 9 and 11 ask for Silver, Gold, Diamond and two Diamonds (`Story.FuseTask`).

- Fusing leaves the MINI CANNONS window (no more FUSE and FUSE ALL buttons there) and becomes its own FUSE
  window, opened at the Fusion Machine, which moves from the marketplace to The Sun's island.
- The player picks the three mini cannons to fuse from their inventory: three of the same kind and tier, as
  today (Silver, Gold, Diamond). Enchanted ones can be picked. The result keeps the enchantments of the
  first one picked (the window shows which); the other two's are lost, with a warning.
- A "fill" button picks three matching ones without enchantments, for speed.
- The story's fuse quests move to after island 5 is reached.

## 6. STATS window (Yaani's idea: strategy and YouTube material)

A STATS menu button opens one window that shows every number and exactly where it comes from.

- **Headline:** Cannon Power (total DPS), with the multiplier chain written out: tower base damage x mini
  cannon bonus x rebirths x mastery x enchants x Huge x powerups x ammo = result.
- **One section per stat** (damage, fire rate, range, boss damage, coins, luck, lives, monster speed, mini
  cannon shots): the total, then one line per source with its own number ("Mastery: Attack IV  +40%",
  "Mini Storm Cannon~Sharp III  +15%", "2x Power  x2  12:40 left"). Timed buffs show their countdown.
- **Per tower:** each pad's tower with its damage, rate, range and DPS, and its share of the total.
- **Totals:** monsters defeated, bosses, eggs hatched, levels cleared, time played, best level.
- The numbers come from the server: every modifier registers with a label (`Game.modify(kind, fn, label)`),
  and the core publishes the breakdown as `Meta_stats` when the window is open, so the window can never
  disagree with what is really applied. Build it after Mastery and Enchanting so their sources show up.

## 7. After that

Balance pass with the simulator including Huge, mastery and powerups; offline earnings; a new name (no more
"Per Click"); passes and products on Roblox; phone check; publish.

Decided 4 Oct: the game's name is "+1 Cannon Per Click". Island shops: as drafted above.
Status 4 Oct evening: step 0 done (rebuilt game merged into src and running in Studio), step 0b done (Combat removed).

Decided 5 Oct: the enchanting table stands on the player's own plot (the open ground in front of the base wall, to the right of the gate as seen from the plot: see Yaani's screenshot), not on The Sun's island. It appears on a plot once its owner has reached The Sun (world 5) and stays after a rebirth. Its prompt opens ENCHANT for the owner only. The Fusion Machine stays on The Sun's island unless Yaani says otherwise. Do this after the queue workflow, before the merge into src.

Decided 5 Oct (later, replaces the note above about the plot): walks on islands are too long. Every island gets a compact centre: the player arrives in the middle, and the two egg stands, the shop stall, the return portal and (where the island has them) the Mastery shrine, the Enchanting table and the Fusion Machine stand in a tight ring around the arrival pad, each a few steps away (about 15 studs). The statues and scenery go to the rim. The enchanting table stays on The Sun's island in that ring, not on the plot. Do this after the queue workflow, before the merge into src.

Status 4 Oct night, in the staging tree: 0c (rebirth, the three leaderboards, Veteran) and 1 (Huge nerf) are built
in the core, with the groundwork for 2, 3, 4 and 6: `goIsland` / `state.place` / `Game.places.island`, the
modifier kinds mastery and enchanting need, and `Game.modify(kind, fn, label)` / `Game.breakdown`. As built:
`docs/DEFENSE_SPEC.md`, section 8.
Status 4 Oct late night, in the staging tree: 2 (islands) is built: `src/server/Islands.luau`, the WORLDS
window's ISLAND buttons, the street's islands portal, the island shop (`Features/IslandShop.luau` x3). The coin
eggs left the marketplace. As built: `docs/DEFENSE_SPEC.md`, section 8, and "The world islands" in
`docs/ARCHITECTURE.md`. Island shop numbers: `docs/BALANCE.md`.
Status 5 Oct, in the staging tree: 3 (mastery, all twelve tracks on sale: the core has the `equipSlots`
modifier) and 6 (the STATS window, `Features/Stats.luau`) are built, with the game speed button and the hidden
Huge badge brought over from the live tree, and the client following `TowerRate` / `TowerRange`. 4 (enchanting)
and 5 (fusing) are not built yet; STATS lists their sources by itself once their modifiers are labelled. As
built: `docs/DEFENSE_SPEC.md`, section 8; mastery's numbers: `docs/BALANCE.md`, section 5c.
Status 5 Oct, later, in the staging tree: the islands have a compact centre. Players arrive in the middle
(`Layout.islandSpawn`); the two eggs, the stall, the portal home and the two reserved spots stand in a ring 15
to 16 studs around the arrival pad, facing it; the boss and the two monster statues, the lamps and the props
stand at the rim. For 4 and 5: the enchanting table and the fusion machine share the `enchant` spot, at x = -5
and x = 5 of `Islands.spot(5, "enchant")` (`tools/emu2/islands.py` checks those two places).
Status 5 Oct, later still, in the staging tree: 4 (enchanting) and 5 (the fusing revamp) are built:
`Features/Enchant.luau` and `Features/Fuse.luau` (shared, server, client each), enchanted mini cannon ids
(`Config.Pets` resolves `wooden_gold~greed1.sharp3`), the table and the Fusion Machine on The Sun's island, the
keys in the crates and the island shops, the story's fuse quests from chapter 5 on. New in the core: the
`petRange` modifier, `shot.target`, `Game.pets.swap`, and labels that list several sources. The Shiny key's
Robux product has id 0. Not done: keys from missions; the balance pass with enchantments (`tools/balance` does
not model them, and its player now fuses only from The Sun on).

## Event leaderboard (decided 5 Oct)

- A Halloween candy leaderboard, global (OrderedDataStore), ranking candy EARNED during the event (not the
  balance, so spending candy never costs rank). Shown on a board in the marketplace and in TOP PLAYERS.
- Rewards when the event ends, for the top 5: ranks 1 to 3 get a special Halloween Huge cannon (a new,
  event-only Huge that cannot be hatched; default: tradable), ranks 4 and 5 get gems (default: 2,500 and 1,500).
  The final ranking is frozen at the event's end; a winner is paid the next time they join, once.
- Built as a reusable "event" module, not Halloween-only: an event has a currency, start and end times, a
  leaderboard and a reward table, so Christmas (Christmas candy) is a data entry plus its own Huge.
- Build after the current queue is merged.


## Game speed pass and offline earnings (built 5 Oct 2026)

- **3x game speed is a game pass, 2x is free** (decided 6 Oct; until then 2x was in the pass too):
  `Config.Passes.gameSpeed`, "3x Speed", 99 Robux, id 0 until it is created on Roblox. Without it a plot runs
  at 2x at most (a saved 3x is kept for when the pass is bought), and a press at 2x offers the pass and steps
  back to 1x.
- **Offline earnings** (`Features/Offline.luau` x3): on joining after more than a minute away, the towers are
  paid for farming the highest level cleared (or the highest they can still clear) for the time away, capped
  at 8 hours, at 50% (`Config.Offline`). Coins only; paid by CLAIM on a welcome-back card; game speed does not
  count. The cap and the share are the modifiers `offlineCap` (hours) and `offlineShare`, for a later pass.
- **Mastery: Offline** (section 3's missing track) is in: Survival group, +1 hour of offline earnings per
  level, 4 levels (8 hours to 12), 300 gems rising x1.6 (2,780 in all). The share stays 50%.
- Not done: the numbers are not in `tools/balance` (offline coins are not simulated against the pace floor of
  0c), and the STATS window has no "offline coins" tile (its two modifiers are listed as sections).


## The first join: welcome cards and the walkthrough (built 5 Oct 2026)

Yaani: "we also need to think of a tutorial when people first join the game, we need to first plug our group
and tell them to thumbs up the game for a fan bonus or something and then the tutorial walks them through
the game before letting them start".

- **Built** as `Features/Tutorial.luau` x3 (described in `docs/ARCHITECTURE.md`, "The first join"): three
  welcome cards once per save (the game, the group's fan bonus, a like), then an eleven-step walkthrough with
  a banner at the top middle and a marker in the world, driven by the server from real state.
- **The fan bonus is for joining the group, not for the like.** +250 gems once and +10% coins for good
  ("Fan bonus" in STATS), numbers in `Config.Fan`. The like card asks plainly and says there is no reward: a
  game cannot check a like and Roblox does not allow rewarding ratings.
- **To do when the group exists:** put its id and name in `Config.Fan` (`groupId = 0` today: the card says
  the group is coming soon and nothing can be claimed).
- **The story's chapter 1** now runs in the walkthrough's order (the hatch comes before the first giant, the
  marketplace visit after it and it now needs a real visit); a tutorial quest and its walkthrough step share
  one payment.
- **The plot waits behind the welcome cards** (6 Oct 2026): a save that has not been welcomed joins paused and
  starts on START TUTORIAL or the skip link. Emulator tests paused the plot of every new save too, so
  `tests/_prelude.luau` lets its player's go (`T.release`); only `tests/tutorial.luau` keeps the wait.
- Not done: looks, sizes on a real phone and the marker's height need a Studio play test.


## Mini cannons deal flat DPS; monster health in numbers (built 5 Oct 2026)

Yaani: "make it so mini cannons are not +129% power for example and make it +129 DPS (this is a huge nerf to
mini cannons yes i know)", then "applies anywhere on your base, even while offline, even while you're in the
market", then: remove Quick Draw.

- A mini cannon's bonus x 100 is its own damage per second (`Config.PetDps`): "+129 DPS" on every screen
  (`Format.petPower`). It no longer multiplies tower damage, and nothing that multiplies tower damage
  multiplies it. Equipped mini cannons deal it to the lead monster of the base all the time, wherever the
  player is, and offline earnings count it. Cannon Power = towers' DPS + mini cannons' DPS.
- Huges keep x3 tower damage, their feature and the Huge Shot (which still needs the player near the fight).
  A Huge's own DPS is its strongest ordinary neighbour's (at least 50; Huge Gatling x5).
- Bond (mastery and enchantment) grows mini cannon DPS. Long Shot is +3 / 6 / 10% mini cannon DPS. Quick Draw
  is removed: 19 enchantments, and old ids that carry it still load and ignore it.
- Every monster's HP bar shows its health in numbers; so does the level panel's boss line.
- **Open, for Yaani:** Mastery Rapid (+5% mini cannon shots a level, bought with gems) is cosmetic now, like
  Quick Draw was: remove and refund, or give it a new meaning. The fused Silver tier's Rapid Fire perk is
  cosmetic too. The balance was not retuned and the pacing has to be measured again (`docs/BALANCE.md`, 3b).
  `src/client/Market.luau` (another session's file) was not touched and needed nothing: the egg stands only
  write hatch odds, never a mini cannon's strength.
- Files: `Config.luau`, `Format.luau`, `Game.luau`, `Field.luau`, the Enchant, Mastery, Stats, Offline, Huge,
  Defense, Fuse, Trading and Crates features, `Windows.luau`, `Loot.luau`, `Effects.luau`, `tools/balance`.

## Private bases, visits by invitation, and pause (built 5 Oct 2026)

Yaani: "instead of it being a flat map with everyones bases, make it so everyones bases are private, and each
base has an island teleporter, and make an invite system so if someone else wants to come to your base to see
your guns layout etc they can invite using a menu for it ... its quite confusing to see where the thing is in
the middle of the map and its a long walk".

- **Private bases.** The street and its lamps are gone. The twelve bases stand alone, 2,000 studs apart in
  two rows (z = 4,000 and z = -4,000), more than 1,500 studs from each other, the marketplace and the islands.
  Each is closed off by its backdrop, hills down the sides and behind a new yard, and an unseen wall; a
  character that still gets under the map is put back on its base. Beside the arrival spot stand the base's
  own islands teleporter (opens WORLDS) and marketplace teleporter, 13 studs away.
- **Visits** (`Features/Visit.luau` x3): VISIT in the MORE drawer lists the other players with INVITE and,
  when they invited you, JOIN (also on a card that pops up). An invitation lasts 60 seconds and is declined
  by ignoring it. A guest sees the host's towers and monsters, can use nothing of the host's, and goes home
  with BASE; the host has SEND HOME per guest; guests go home when the host leaves.
- **Pause**: a button on the level panel beside the speed button, and a PAUSED banner. The plot does not
  step at all while paused; building, upgrading and selling still work. Never saved.
- Described in `docs/ARCHITECTURE.md` ("Private bases, visits and pause") and `docs/DEFENSE_SPEC.md`
  (section 8).
- Not done: nothing here was seen in Studio. To look at there: the surround's looks and the camera against
  the unseen walls, the teleporters' size beside the arrival, the lobby during a slow load, the level panel's
  tighter bottom row on a phone, and streaming when a guest lands on a base 2,000 or more studs away. A guest
  on a base sees the marketplace's sky, not the host's world's. A server over twelve players still shares
  bases (as before): the second owner of a shared base cannot invite.

## Mini cannons that keep up, more towers, AMMO in the TOWER window (built 7 Oct 2026)

- **Why:** Yaani on The Sun: a full team of 11 mini cannons dealt 5.28M a second beside towers dealing 2.84T.
  Every egg was 2.5x the one before while monsters are about 22x tougher from egg to egg.
- **Mini cannons:** from the third coin egg on, each egg's are 22x the last egg's (`Config.EggCurve.step`; the
  first two eggs are as they were). At 15x (the first try) Yaani's team still dealt under 1% of his towers'
  damage (64T beside 7.29Qa); at 22x it is about a sixth. More than that (`EggCurve.jump`) lets mini cannons
  alone clear worlds in five minutes, so the pace of 30 minutes a world cannot be kept.
- **Towers:** "sniper is the only good one": it was the only kind worth its coins on a boss. Cannon 36 to 64,
  Gatling 16 to 40, Mortar 168 to 340, Frost 40 to 120, Flame 44 to 110, Tesla 160 to 400, Rocket 680 to 1,400;
  the Sniper stays. Six new kinds from the specials the core already has: Laser (level 35), Venom (80),
  Blizzard (130), Railgun (200), Storm (260), Meteor (320). They wear the turret of the kind nearest to them
  with an accent of their own (`Models.luau`, `SHAPES`); none has a model.
- **AMMO:** a button on a cannon's page of the TOWER window opens the AMMO window.
- **Pace:** `worldPay` and `headStart` fitted again; see the note at the top of `docs/BALANCE.md`.
- Not done: nothing here was seen in Studio. The new kinds' numbers are a first guess, sized on paper against
  the Sniper and then only through the simulator's pace, not kind by kind.
