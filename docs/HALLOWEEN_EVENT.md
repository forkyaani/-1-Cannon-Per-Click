# Halloween 2026: event plan

Proposal for the owner. Nothing here is built unless it says "exists". The premium currency is covered in `docs/GEMS.md`.

- **Labels:** **C** = read from `Config.luau` or the code on 2 Oct · **E** = computed from C · **S** = sourced, links at the end · **G** = guess, tune it.
- **Sizes:** **S** under a day · **M** 1–2 days · **L** 3–4 days. One developer plus AI, one phone test included.
- Every new price, rate and multiplier here is my pick: treat it as **G** even where it is not marked. Nothing was play-tested.

## TL;DR

1. Three rules make it work for every player: candy is paid for time, not kills; Halloween mini cannons grow with you; the Halloween world is tuned to your own best wave.
2. Fix first: candy per kill is broken. Farming one easy wave pays 54,000 candy an hour AFK (E). The whole candy shop costs 12,800 (C).
3. Halloween world: yes, as a re-skin of your own lane. "Pumpkin Hollow": 30 waves a night. 29 you have already beaten, then the Pumpkin King (your best wave as a 12x boss), then endless Overtime.
4. Calendar: Sat 10 Oct launch (candy, 2 eggs, shop, trick-or-treating) → Fri 16 Oct Pumpkin Hollow → Fri 23 Oct Witching Week → Fri 30 Oct to Sun 1 Nov Pumpkin King raids.
5. Move the end. 1 Nov 00:00 UTC is 8 pm in New York on Halloween night. Use Mon 2 Nov 08:00 UTC, then a spend-only week.
6. Candy: a free active player earns about 3,500 a day at any stage. One of everything costs 31,300. Diamond-fusing the three shop exclusives costs 210,600.
7. Content: 6 eggs (30 mini cannons), 5 exclusives, a 4-chapter quest, daily missions, 20 doors to knock on, 2 leaderboards.
8. Robux: 2x Event Loot pass (249), Golden Pumpkin mini cannon (299), and gems that convert to candy. No egg is sold for Robux.
9. Three weeks cannot hold all of it: about 16 build-days of ideas against roughly 12 (G). The cut line is in section 12.
10. Biggest unknown: my simulation of today's formulas reaches world 6 in about an hour, so most returning players may be "end game" by week 2.

Decisions I need from you: section 13.

---

## 1. Fix these three things first

| # | Today | Arithmetic | Fix |
|---|---|---|---|
| 1 | Candy is 1 per kill, 10 per boss (C) | With auto-advance off, one shot kills a whole 5-monster wave (overkill, C). 3 mini cannons = 3 shots/s = 15 candy/s = **54,000 an hour, AFK**. A boss wave pays 10 per shot = 108,000 an hour. Shop total: 300 + 1,500 + 6,000 + 10 × 500 = 12,800 (C). That is **14 minutes** | Rule 1 |
| 2 | Event mini cannons have fixed bonuses (C) | Pumpkin King = 3,000. A Common from the Mars Egg (wave 100) = 16,384. So it is worthless from world 3. And the Pumpkin Egg (3 to 80) is 12–20x a Basic Egg (0.25 to 4) for 3x the price | Rule 2 |
| 3 | Event ends 1 Nov 00:00 UTC (C) | = Sat 31 Oct, 8 pm New York, 5 pm Los Angeles. Halloween evening is cut off | Section 4 |

## 2. The three rules

**Rule 1: candy is paid for time, not kills**
- A candy meter fills 1 candy every 3 seconds and holds 20. Any kill pays out what is in it.
- Result: 20 a minute, 1,200 an hour. Same on wave 1 and wave 300, tapping or AFK.
- Daily cap from the meter: 1,800 (90 minutes). Doors, the Hollow and quests come on top.
- Extends: `Config.Halloween` (replaces `candyPerKill`, `candyPerBoss`), the candy lines in `onMonsterDefeated`, `data.event`.

**Rule 2: Halloween mini cannons grow with you**
- Strength = a multiplier × **R**. R is the Common of the newest coin egg you have unlocked: `R = 0.25 × 16 ^ floor(best wave / 25)`, capped at the Omega Egg (C: the same steps the coin eggs use).
- Players read it as: "Pumpkin King: always stronger than the Legendary of your newest egg."
- **Halloween Spirit:** x2 while the event is live. Every table below shows the October number. From 2 Nov they run at half and keep growing. Each October they are back at full.
- Why half after October: coin eggs must stay worth hatching the rest of the year.

| Player | Best wave | Newest egg (C) | R | Pumpkin King in October (20 × R) | That egg's Legendary (16 × R) |
|---|---|---|---|---|---|
| New | 10 | Basic | 0.25 | 5 (+500%) | 4 |
| Mid | 120 | Mars | 16,384 | 327,680 | 262,144 |
| End | 290 | Omega | 4.40T | 88T | 70.4T |

- Extends: `definePet` (a `scale` instead of a `bonus`), `Config.petBonus`, `Config.equippedPets`, `Config.powerPerClick`, `addPet`, `refreshPets`, the fuse loop (`base.bonus * tier.bonus`), the pet list in `Windows.luau`, the stand text in `Market.luau`.
- Borrowed from Pet Simulator 99: every Huge pet deals 150% of your strongest pet (S).

**Rule 3: the Halloween world is tuned to you.** See section 5.

**A handy unit.** Monster HP grows x1.35 a wave (C). Multiplying power by M is worth `ln M ÷ ln 1.35` waves: 2x = 2.3 waves, 16x (a whole egg tier) = 9 waves. Use it to judge any reward.

## 3. Who plays and what they chase

| Player | What pulls them in | What they chase |
|---|---|---|
| New (Earth, first session) | Candy pops from the first kill. A spooky town with doors to knock on. A free Candy Corn mini cannon from Chapter 1 in about 10 minutes (G) | First Haunted Egg (150 candy = 8 doors) |
| Mid game (Moon to Neptune) | Growing mini cannons do not need re-hatching at every new egg. The Hollow pays a burst of candy each night | Silver and Gold exclusives. Crypt Egg set |
| End game (Void, wave 300) | Overtime in the Hollow climbs past wave 300 with no ceiling: the only new content they have | Deepest Hollow rank. Diamond Pumpkin King. Top 10 candy |
| Active tapper | Taps decide the Pumpkin King, Overtime, raid damage, Candy Rain, doors | A full Hollow clear every night. Raid podium |
| AFK | The candy meter pays while mini cannons fire (1,800 a day). Auto-fire clears the 29 Hollow waves below the King | Haunted Eggs. The cheap exclusives |
| Free | Everything is earnable. Three exclusives in about 5 casual days | One of everything (31,300 candy, about 10 good days) |
| Paying | 2x Event Loot. Golden Pumpkin. Gems to candy. Summoning a raid for the server | Diamond tiers. Finishing early. Cosmetics |
| Collector | 6 eggs, 30 mini cannons, 5 exclusives, 3 fuse tiers each. Year-stamped titles | "Halloween Collector 2026" |
| Competitor | Two global boards. Raid podium every 30 minutes | Top 10 candy. Deepest Hollow |

## 4. Calendar

Today is Fri 2 Oct. Launch is planned for Sat 10 Oct (latest Tue 13 Oct). Real players see about three weeks.

| Date | Beat | What goes live |
|---|---|---|
| Sat 10 Oct | **Candy Season** (launch) | Candy by time · Pumpkin Egg and Haunted Egg (exist) · candy shop with three growing exclusives · trick-or-treating · daily Halloween missions · Chapter 1 · 2x Event Loot pass · pumpkins and night lighting (exist) |
| Fri 16 Oct | **Pumpkin Hollow opens** | The Halloween world · Sweet Tooth Egg and Crypt Egg in a new Pumpkin Patch · Candy Kings and Deepest Hollow boards · Chapter 2 |
| Fri 23 Oct | **Witching Week** | Candy Rain twice an hour · Witch's Egg (gems) · titles, Pumpkin Cannon skin, lane trophy · achievements · Chapter 3 |
| Fri 30 Oct to Sun 1 Nov | **Halloween Night** (finale) | Pumpkin King raid in the square every 30 minutes · Full Moon: 2x candy all weekend · Blood Moon Egg · Chapter 4 · Golden Pumpkin mini cannon |
| Mon 2 Nov, 08:00 UTC | Event ends | See the table below |
| Mon 9 Nov, 08:00 UTC | Shop closes | See the table below |

- Fridays, because they sit before the weekend and match the release dates in `PLAN.md` (16 and 23 Oct).
- The finale sits on PLAN's Halloween ad money (28 Oct to 1 Nov).
- If launch slips to 13 Oct, nothing else moves.

**What happens when it ends**

| | Mon 2 Nov, 08:00 UTC (midnight Sunday in Los Angeles) | Mon 9 Nov, 08:00 UTC |
|---|---|---|
| Candy from monsters, doors, the Hollow, raids, missions, quests | Stop | |
| Candy shop and candy eggs | Stay open, spend only | Close |
| Leftover candy | Kept | Converted: 100 candy → 1 gem, at most 250 gems |
| Halloween mini cannons | Kept forever. Halloween Spirit ends, so half strength. They keep growing | |
| Titles, cannon skin, lane trophy | Kept forever | |
| Leaderboards | Frozen. Top-10 titles are given at next login | Boards removed |
| Pumpkins, night lighting | Go when each server restarts (the flags are read once at start, C) | |
| Comes back | October 2027: the same eggs and shop return, plus new ones. Spirit x2 returns. Titles and trophy stamped "2026" never return | |

- Extends: `Config.Halloween.endsAt` (1793606400), a new `shopEndsAt` (1794211200), `Config.halloweenActive`, `actions.buyEvent`, `hatchEgg`.
- If you keep 1 Nov 00:00 UTC, the same table applies 32 hours earlier, and the finale loses Halloween evening in the Americas and all of Sunday.
- **Sun 1 Nov itself:** nothing closes. It is the last full day of the finale.
- In Adopt Me, candy can no longer be spent once the event is over (S). The spend-only week avoids that complaint.

## 5. Pumpkin Hollow, the Halloween world

**Decision: build it as a re-skin of your lane. Do not build a walkable world.**
- Walkable means a new map, monsters that move and a second camera mode: L or more. The marketplace already is the walkable Halloween place.
- A lane already changes floor, backdrop, sky and monsters per world (C: `Arena.showWave`, `Config.Worlds`). The Hollow is a seventh look with its own wave counter. **M to L, plan 3 days.**
- It is the only thing here that gives a wave-300 player something to push.

**Getting in**
- WORLDS window: a new row, "Pumpkin Hollow · tonight 12/30" (extends the rows built from `Config.Worlds`, and `actions.travel`).
- A glowing gate in the marketplace's Pumpkin Patch (reuses `buildPortal`).
- Unlocks at Earth wave 10. Leave by travelling to any world.
- A rebirth sends you out, and power resets, so climb back before returning.
- Neighbours see your lane turn into a graveyard, which advertises the event for free.

**How it scales**
- 30 waves a night. Resets at 00:00 UTC, with the daily missions.
- `A` = your best wave ever (`bestCleared`), fixed when you first enter that night.
- Hollow wave `w` is as strong as main wave `A − 30 + w` (never below 1). Same HP formula as the main game.
- So waves 1–29 are waves you have already beaten, and wave 30 is your best wave turned into a boss.
- Softer bosses than the main game: x4, x8 and x12, against x8, x20 and x50 (C).

| Hollow wave | As strong as | Boss HP |
|---|---|---|
| 1–29 | 29 to 1 waves below your best | x4 on waves 5, 10, 20, 25 · x8 on 15 |
| 30, the Pumpkin King | your best wave | x12 |
| 31 and up, Overtime | 1, 2, 3… waves above your best, no end | x4 on every 5th |

- The Pumpkin King has 1.5x the HP of the regular boss your best wave would have (x12 against x8, C). In waves, x12 is about 8 waves beyond your best (ln 12 ÷ ln 1.35, E).
- Overtime wave 40 is 10 waves above your best with a x4 boss: about 15 waves beyond. A world boss is 13 (x50, C).

| Player | Best wave | Hollow wave 1 | Pumpkin King (wave 30) | Overtime wave 40 |
|---|---|---|---|---|
| New | Earth 10 | level 1 | level 10 · 1,790 HP | level 20 · 12.0K HP |
| Mid | Mars 20 (120) | level 91 | level 120 · 388Qa HP | level 130 · 2.60Qi HP |
| End | Void 50 (300) | level 271 | level 300 · 112Dd HP | level 310 · 750Dd HP |

- A wave-300 player has already beaten the Void King (466Dd HP, C), so their Pumpkin King falls fast. Their push is Overtime, which passes the Void King near wave 40.
- Expected (G): waves 1–29 fall in seconds. The King takes a push. Overtime is where the strongest stop.
- Getting stronger in the main game during the day lets you go deeper the same night. Tomorrow it re-tunes.

**Monsters** (the four shapes in `Arena.luau`, colours only)

| Waves | Monster | Shape | Colours | 5th wave |
|---|---|---|---|---|
| 1–5 | Pumpkin Slime | blob | orange, green | Giant Pumpkin Slime |
| 6–10 | Skeleton | biped | bone white, dark arms | Giant Skeleton |
| 11–15 | Ghost | floater | white, pale blue | **Headless Horseman**: biped, black and orange, holds a pumpkin |
| 16–20 | Grave Spider | crawler | black, red claws | Giant Grave Spider |
| 21–25 | Zombie | biped | green, brown arms | Giant Zombie |
| 26–30 | Vampire Bat | floater | purple-black, red | **The Pumpkin King**: biped, pumpkin head from `Build.pumpkin`, horn crown |
| 31+ | Nightmare versions of the six | | neon purple | Giant on every 5th |

- Look: dark purple floor, near-black backdrop, clock 0, low brightness, three block tombstones, one dead tree, the two lane pumpkins that already exist.

**What it pays** (first clear each night)

| Wave | Candy |
|---|---|
| Normal (24 of them) | 20 |
| Boss (5, 10, 20, 25) | 60 |
| Headless Horseman (15) | 150 |
| Pumpkin King (30) | 400 |
| Overtime 31–40 | 30 each. Past 40 only the leaderboard moves |
| **Full clear** | **1,270**, plus 300 from Overtime |

- A typical night (E): the 29 easy waves = 870 · with the King = 1,270 · with all paying Overtime = 1,570.
- Coins: the same as the main wave of that level. Kills count for mastery and daily missions. The candy meter runs here too.
- Extends: a new `Config.Hollow` table; `Config.monsterFor`, `monsterHP`, `monsterCoins`, `waveKind`; `spawnWave`, `onWaveCleared`, `failWave`, `actions.nextWave`, `prevWave`, `travel`, `rebirth`; the lane label in `Arena.showWave`. New save fields go in `DEFAULTS` in `Data.luau` or `reconcile` drops them (C).

## 6. Candy economy

**Sources**

| Source | Rate | Cap a day | Free, active 60 min | AFK, 90 min online |
|---|---|---|---|---|
| Candy meter (any world, the Hollow too) | 20 a minute | 1,800 | 1,200 | 1,800 |
| Pumpkin Hollow first clears (from 16 Oct) | 20 / 60 / 150 / 400 | 1,570 | 870 to 1,570 | 870 |
| Trick-or-treating | 20 a door, the lucky house 120 | 500 | 500 | 0 |
| Daily Halloween missions | 3 × 150, plus 50 for all three | 500 | 500 | about 150 |
| Candy Rain (from 23 Oct) | 150 a rain, first 2 a day | 300 | 300 | 0 |
| Raids (30 Oct to 2 Nov) | 150 a raid, first 3 a day | 450 | 450 | 0 |
| Quest chain | once | 4,150 in total | | |
| Gems to candy | 100 gems → 500 candy | 10,000 | | |
| 2x Event Loot boost, 30 min | 80 gems, 2 a day | | about +2,000 if it covers the Hollow and the doors | |

**Per day, by stage** (from 16 Oct; G targets, E sums)

| Stage | Hollow night | Free active | AFK | Paying active (2x Event Loot) |
|---|---|---|---|---|
| Early (Earth) | about 1,400: power grows fast, the King falls | 3,600 | 2,800 | 6,700 |
| Mid (Moon to Neptune) | about 1,100: the King on most nights | 3,300 | 2,800 | 6,100 |
| End (Void, wave 300) | about 1,500: the King and most of Overtime | 3,700 | 2,800 | 6,900 |

- Free active = meter 1,200 + Hollow + doors 500 + missions 500.
- AFK = meter 1,800 + Hollow 870 + missions 150. AFK means mini cannons firing, no taps. Roblox kicks idle players after 20 minutes (`DESIGN.md`), so 90 minutes is several sessions.
- The pass doubles the meter (rate and cap), the Hollow, doors, rain and raids. Not missions or quests.
- Before 16 Oct a free active day is 2,200. A casual 15-minute day is about 1,400.
- The three stages land within 15% of each other. That is the point.

**Whole event, free**

| Player | Candy | How |
|---|---|---|
| Casual | about 8,000 | 5 short days |
| Engaged | about 44,000 | 10 active days, two of them in the finale |
| Never misses a day | about 88,000 | 6 × 2,200 + 7 × 3,300 + 7 × 3,600 + 3 × 7,600 + 4,150 |

**Sinks** (the candy shop, extends `Config.EventShop`)

| Item | Candy | Limit | Status |
|---|---|---|---|
| Mini Candy Corn Cannon | 300 | 27 | exists; limit 1 → 27 so it can be fused |
| Mini Cauldron Cannon | 1,500 | 27 | exists |
| Mini Pumpkin King Cannon | 6,000 | 27 | exists |
| 2x Power, 15 min | 200 | none | exists |
| 2x Coins, 15 min | 200 | none | new row |
| 25 gems | 500 | 10 per event | exists |
| Title "Trick-or-Treater" | 1,000 | 1 | new |
| Lane trophy: pumpkin stack, stays all year | 2,500 | 1 | new |
| Pumpkin Cannon skin | 5,000 | 1 | new |
| Ghostly aura | 10,000 | 1 | new |
| Eggs: Haunted 150 · Sweet Tooth 400 · Crypt 1,000 · Blood Moon 2,500 | | none | section 7 |

**The grind, on purpose**

| Goal | Candy | Who gets there |
|---|---|---|
| First Haunted Egg | 150 | Minute 2: knock on 8 doors |
| All three exclusives, once | 7,800 | Casual |
| One of everything | 31,300 (7,800 + 18,500 cosmetics + 5,000 gem trades) | Engaged |
| The above, exclusives fused to Silver (3 each) | 46,900 | Daily player |
| Exclusives fused to Gold (9 each) | 70,200 for the mini cannons alone | A perfect free player (88,000), skipping most cosmetics |
| Exclusives fused to Diamond (27 each) | 210,600 | Payers: 2x pass plus gems |

## 7. Eggs and mini cannons

Reference (C): your newest coin egg is 1 · 1.6 · 3 · 6 · 16 × R at 50 / 30 / 15 / 4.5 / 0.5%.

| Egg | Live | Cost | Unlock | Mini cannons, Common → Legendary | × R in October |
|---|---|---|---|---|---|
| Pumpkin (exists) | launch | Coins: 3x your newest coin egg (1,500 for a new player, C) | Earth wave 5 (C) | Pumpkin · Bat · Ghost · Witch · Jack-O-Lantern | 0.6 · 1 · 1.8 · 3.5 · 9 |
| Haunted (exists) | launch | 150 candy (C) | none | Skeleton · Zombie · Vampire · Reaper · Headless Horseman | 1.2 · 2 · 3.6 · 7 · 18 |
| Sweet Tooth | 16 Oct | 400 candy | Knock on 20 doors | Lollipop · Gumdrop · Toffee Apple · Licorice · Jawbreaker | 2 · 3.2 · 6 · 12 · 30 |
| Crypt | 16 Oct | 1,000 candy | Beat the Headless Horseman once | Tombstone · Spider · Mummy · Gargoyle · Lich | 4 · 6.5 · 12 · 24 · 60 |
| Witch's | 23 Oct | 120 gems | none | Potion · Black Cat · Broomstick · Crystal Ball · Warlock | 4 · 6.5 · 12 · 24 · 60 |
| Blood Moon | 30 Oct | 2,500 candy | Join one raid | Crow · Scarecrow · Werewolf · Banshee · Blood Moon | 8 · 13 · 24 · 48 · 120 |

- Odds: 50 / 30 / 15 / 4.5 / 0.5% for all (C: `SLOT_WEIGHT`), except Blood Moon at 45 / 30 / 17 / 6 / 2% (needs an optional weights argument on `defineEgg`).
- All 20 new names are free: none clashes with the 83 existing ids.

**Exclusives** (not from eggs)

| Mini cannon | How | × R in October | Copies |
|---|---|---|---|
| Candy Corn (exists) | Candy shop 300. First one free from Chapter 1 | 3 | 27 |
| Cauldron (exists) | Candy shop 1,500 | 8 | 27 |
| Pumpkin King (exists) | Candy shop 6,000 | 20 | 27 |
| Lantern | Finish Chapter 4 | 12 | 1 |
| Golden Pumpkin | 299 Robux game pass, fixed item | 30 | 1 |

**How they stay relevant from wave 10 to wave 300**
- Everything grows with R, so every player gets the same relative jump (Rule 2).
- The Pumpkin Egg's coin price follows your newest coin egg, so it means something at every stage instead of being pocket change after world 1.
- Cheap eggs plus fusing beat expensive eggs on value: 3 Haunted Commons (450 candy) fuse into a Silver worth 4.2 × R (1.2 × 3.5, C), the same as one Crypt Common (1,000 candy). Expensive eggs are the fast lane.
- Fuse tiers are the long tail: Diamond takes 27 copies and multiplies by 40 (C).
- x3 Egg Opener and x3 Luck work on all six (C).
- Stands go in a "Pumpkin Patch" in the south-east corner. The main arc already holds 15 stands about 10 studs apart (E, from `buildHatchery`).
- Extends: `defineEgg` (`event = true`), a new `requires` field, a per-player cost for the Pumpkin Egg, `buildHatchery`, `Market.refresh`.

## 8. Side quests

**Daily Halloween missions.** Three a day from this pool, 150 candy each, plus 50 candy and 10 gems for all three. Extends the `Config.Missions` pattern, `track()` and `actions.claimMission`.

| Mission | Works AFK |
|---|---|
| Collect 300 candy from monsters | yes |
| Clear 15 waves in Pumpkin Hollow | yes |
| Defeat 3 Hollow bosses | yes |
| Knock on 10 doors | no |
| Hatch 5 Halloween eggs | no |
| Fire 600 shots yourself | no |
| Fuse a Halloween mini cannon | no |
| Catch 20 falling candies (from 23 Oct) | no |
| Join a raid (from 30 Oct) | no |

**Quest chain: "The Stolen Candy".** One chapter a week. Steps are counters that never reset.

| Chapter | Story | Steps | Reward |
|---|---|---|---|
| 1. The Candy Thief (launch) | The Pumpkin King stole the town's candy. Win the town's trust | Collect 100 candy · knock on 5 doors · hatch a Halloween egg · defeat 5 bosses | 400 candy · **Mini Candy Corn Cannon** · title "Candy Rookie" |
| 2. Into the Hollow (16 Oct) | The trail leads into Pumpkin Hollow. The Headless Horseman guards it | Clear Hollow wave 5 · beat the Headless Horseman · hatch 10 Halloween eggs · fuse one to Silver | 950 candy · unlocks the Crypt Egg · title "Ghost Hunter" |
| 3. The Witch's Bargain (23 Oct) | The town witch can break the King's spell, for a price | Knock on 60 doors in total · earn 5,000 candy in total · clear Hollow wave 25 · catch 50 falling candies | 1,400 candy · 50 gems · title "Witch's Apprentice" |
| 4. Halloween Night (30 Oct) | The King attacks the town | Join 3 raids · beat the Pumpkin King (raid or Hollow wave 30) · hatch a Blood Moon Egg | 1,400 candy · **Mini Lantern Cannon** · title "Pumpkin Slayer" |

- No character model needed: the chain shows in the Missions window and on a board at the Halloween stall.

**Achievements** (once each, pay gems and titles)

| Goal | Tiers | Gems | Title |
|---|---|---|---|
| Candy earned | 1,000 / 10,000 / 40,000 / 80,000 | 10 / 25 / 50 / 100 | Sweet Tooth · Candy Hoarder · Candy Tycoon |
| Doors knocked | 20 / 100 / 300 | 10 / 20 / 40 | Neighbourhood Legend |
| Halloween eggs hatched | 10 / 100 / 500 | 10 / 25 / 50 | Egg Witch |
| Hollow waves cleared | 100 / 250 / 450 | 10 / 25 / 50 | |
| Raids joined | 1 / 10 | 10 / 40 | |
| Beat the Pumpkin King in the Hollow | once | 50 | Kingslayer |
| Own all five from one Halloween egg | 6 eggs | 15 each | |
| Own all 34 earnable Halloween mini cannons | once | 100 | Halloween Collector 2026 |

- Up to 715 gems. A typical player gets about 200 (G).

## 9. Marketplace events

| Event | When | What happens | Pays | Size |
|---|---|---|---|---|
| **Trick-or-treating** | All event. Resets 00:00 UTC | Knock on the 20 house doors around the square (C: 4 sides × 5 houses). One "lucky house" a night, different for each player | 20 a door, lucky house 120. 500 a night. A full round takes 2–3 minutes | S |
| **Candy Rain** | From 23 Oct. At :15 and :45, for 60 seconds | Candy falls on the square. Walk into it | 6 a piece, 25 pieces at most = 150. First 2 rains a day pay | S–M |
| **Pumpkin King raid** | 30 Oct to 2 Nov. At :00 and :30, for 3 minutes | The King appears over the hatchery, where the giant golden cannon already aims (C). Everyone taps. One tap = one hit, not your power, so a new player hits as hard as a veteran | 150 candy for 50 or more hits, first 3 a day. Top three hitters +50 / 30 / 20, names on a board | M |
| **Full Moon** | 30 Oct to 2 Nov | 2x candy from every source | | S |
| Ghost hunt (optional) | Week 3 | Five ghosts hide around the square each night | 20 each, 100 for all five | S |

- Raid HP: 700 hits per player in the square when it starts (G). About 90 seconds if everyone taps. It works with one player.
- Servers hold 12 players (C: `Layout.SLOT_COUNT`), so every event must work solo.
- Same clock on every server (`os.time()`), so "next raid in 12:40" can sit on a sign.
- A player at their cannon gets a toast with a button that uses the existing `goMarket` action.
- Extends: `buildHouse` (a prompt on each `Door`), prompt wiring in `Game.start`, `clickRemote` while `state.inMarket`, a new raid module, `Arena`'s monster builder.

## 10. Competition and status

| Thing | How it works | Prize |
|---|---|---|
| Candy Kings board | Most candy earned in the event. Bought candy does not count. Global top 10 | Top 1: "Pumpkin Monarch 2026" and a gold lane trophy. Top 10: "Candy Royalty 2026" |
| Deepest Hollow board | Highest Hollow level beaten (best wave − 30 + Hollow wave) | Top 10: "Hollow Legend 2026" |
| Raid podium | Top three hitters each raid | Bonus candy, names shown |
| Titles | On your lane's sign and over your head in the square | 15 in this plan |
| Pumpkin Cannon skin | Orange barrel, green rings, a pumpkin on the base | Candy shop 5,000. Hidden buff: Mini Pumpkin Cannons get the x1.5 set bonus (`Config.SetBonus`) |
| Lane trophy | Three stacked pumpkins that stay on your lane all year | Candy shop 2,500 |
| Ghostly aura | Pale particles around your cannon | Candy shop 10,000 |

- The candy board is fair to new players: candy income is the same at every stage.
- The Hollow board is for the end game: only strong players reach high levels, and Overtime has no ceiling.
- Extends: `BOARDS` in `Leaderboard.luau`, `buildLeaderboard`, the lane label in `Arena.showWave`, `Arena.buildCannon`.

## 11. Monetisation

Prices are guesses inside the ranges in `PLAN.md` section 4. PLAN forecasts 0 from the Halloween pet; treat all of this as upside.

| Item | Type | Price | Notes |
|---|---|---|---|
| 2x Event Loot | Game pass | 249 Robux | Doubles candy from monsters, doors, the Hollow, rain and raids. Works in every future event, so it sells after October too |
| Mini Golden Pumpkin Cannon | Game pass | 299 Robux | Fixed item, not random. One copy, given on purchase. A pass, because pass plumbing exists and developer products do not yet (C). Take it off sale by hand when the shop closes |
| Gems to candy | Gem packs, see `GEMS.md` | 100 gems → 500 candy | At most 2,000 gems a day. No separate candy packs |
| 2x Event Loot boost, 30 min | Gems | 80 | Twice a day at most. Rents what the pass owns |
| Run the Hollow again tonight | Gems | 100 | Twice a day at most |
| Summon the Pumpkin King | Gems | 150 | Starts a raid for the whole server. Shows who paid |

- Passes that already exist gain from the event: x3 Egg Opener and x3 Luck on six new eggs, extra slots for growing mini cannons, +500 storage for Diamond fuses (27 copies).
- No Robux prompt before the first rebirth (PLAN rule).

**Roblox's rules for paid random items** (S)
- A random item bought with Robux, or with a currency Robux can buy, is a "paid random item". Once gems are sold, the Witch's Egg and (through gems to candy) the candy eggs count.
- Every outcome and its % must be shown before buying, sum to 100, and update live when luck changes. The stands already do this for each player (C: `Config.eggOdds`, `Market.refresh`).
- Where `PolicyService` reports `ArePaidRandomItemsRestricted`, the player must not reach a paid random item. Allowed instead: an earn-only path, a fixed sequence, or a direct purchase at a fair price.
- Regions in `RESEARCH.md`: Australia, Belgium, Netherlands, UK under-18s, Brazil. Re-check before shipping.
- In this plan: restricted players cannot convert gems to candy, so their candy eggs stay earn-only. Their Witch's Egg becomes "pick the one you want at a fixed price".
- The x3 Luck pass is a "probability modifier" and needs the same check. There is no `PolicyService` call in the code yet (C).
- Fusing is not random (3 → 1, guaranteed, C). Keep it that way: no "chance to fail".
- Free random rewards (doors, rain) need no odds.

## 12. Build order

| # | Item | Size | Extends | Roblox item |
|---|---|---|---|---|
| | **Must ship at launch, Sat 10 Oct** | | | |
| 1 | Candy by time, with the daily cap | S | `Config.Halloween`, `onMonsterDefeated` | |
| 2 | New end date, spend-only week, leftover conversion | S | `Config.halloweenActive`, `buyEvent`, `hatchEgg` | |
| 3 | Shop retune: limits 27, 2x Coins row | S | `Config.EventShop` | |
| 4 | Trick-or-treating | S | `buildHouse`, `Game.start` | |
| 5 | Mini cannons that grow with you | M | Rule 2 list | |
| 6 | Daily Halloween missions and Chapter 1 | M | `Config.Missions`, `track`, Missions window | |
| 7 | 2x Event Loot pass | S | `Config.Passes` | 1 game pass |
| | **Week 2, Fri 16 Oct** | | | |
| 8 | Pumpkin Hollow | M–L | Section 5 list | |
| 9 | Two leaderboards | S | `Leaderboard.luau` | |
| 10 | Pumpkin Patch, Sweet Tooth Egg, Crypt Egg, Chapter 2 | S | `defineEgg`, `buildHatchery` | |
| | **Week 3, Fri 23 Oct** | | | |
| 11 | Titles | S | lane label | |
| 12 | Candy Rain | S–M | new | |
| 13 | Witch's Egg, gems to candy, policy check | S | needs the gem store in `GEMS.md` | |
| 14 | Achievements and a collection page | M | Missions window | |
| 15 | Pumpkin Cannon skin, lane trophy, aura | M | `Arena.buildCannon` | |
| | **Finale, Fri 30 Oct** | | | |
| 16 | Pumpkin King raid | M | new module | |
| 17 | Blood Moon Egg, Full Moon, Chapter 4, Golden Pumpkin | S | config, `Config.Passes` | 1 game pass |
| 18 | Wrap-up: freeze boards, grant titles | S | `Leaderboard.luau` | |

**Be honest about the time**
- Launch 5.5 days · week 2 4 days · week 3 4.5 days · finale 2.5 days = 16.5 build-days (S = half a day, M = 1.5, the Hollow = 3).
- Available: roughly 12 (G: 3 event days a week for 4 weeks; the rest goes to launch, tuning, the store, bugs and phone tests).
- So about a quarter has to go.

**Cut line**
- **Launch:** items 1–3 are not optional (1.5 days). Then 4, then 5. Items 6–7 move to 16 Oct if needed. If item 5 slips, launch with today's fixed bonuses and switch on 16 Oct: the ids stay the same.
- **Cut in this order:** ghost hunt (not scheduled) → Candy Rain → skin, trophy and aura (keep titles) → achievements page → Chapters 2 and 3 (keep 1 and 4) → the raid.
- **If Candy Rain is cut:** swap its mission and its Chapter 3 step for door steps.
- **If the raid is cut:** the Pumpkin King lives only as Hollow wave 30, the Blood Moon Egg unlocks at Hollow wave 25, and the finale is Full Moon plus that egg. That is config only.
- **Never cut:** items 1–3, mini cannons that grow, the Hollow.
- Build it as a generic "event" (currency, world, doors, raid in one table). December then swaps candy for snowflakes.

## 13. Risks and open questions

**Risks**

| # | Risk | What to do |
|---|---|---|
| 1 | **Pace.** My simulation of the Config formulas reaches wave 250 in 40–90 minutes and wave 300 in 1.5–3 hours with rebirths (E). Without eggs, wave 125 takes about 10 hours. A script, not a play-test: a free 2–6 taps/s player who hatches every 4–10 minutes. `DESIGN.md` now says the same from the other side: a strong save clears all six worlds in about a minute | Play-test before trusting any stage label. If it holds, the Hollow and Overtime are the main content from week 2 |
| 2 | The Hollow touches the core loop while three agents edit it. Its numbers (the 30-wave offset, bosses x4 / x8 / x12) are untested | Build it after fusing, passes and overkill have landed. Keep the numbers in `Config.Hollow` and tune on day one |
| 3 | Few players at first (16+ audience gate, 12 per server) | Every event works solo. Boards will be thin, which makes top 10 reachable |
| 4 | Paid random rules start to apply the day gems are sold | Ship the policy check with the gem store, not after |
| 5 | Countdown wording. The shop header already shows "ends in…" (C), and PLAN says no countdowns until the younger-audiences page is read | Read the page, or remove the timer from anything with a Robux price |
| 6 | Saves have no session lock (C: `Data.luau`), and the event adds state | A failed save near the end loses candy. The spend-only week softens it |
| 7 | Names | Keep bosses generic folklore. No film characters or their looks |
| 8 | Evergreen mini cannons could replace coin eggs | Half strength outside October. Watch hatch counts in November |

**Open questions for you**

1. Move the end to Mon 2 Nov 08:00 UTC, with the shop open until 9 Nov?
2. Candy by time (20 a minute, 1,800 a day) instead of per kill? Is a hard daily cap fine, or should it slow to a trickle instead?
3. Mini cannons that grow with you, at x2 in October and half after? This also fixes the Gem Egg (see `GEMS.md`).
4. Pumpkin Hollow as a lane re-skin with 30 relative waves a night, as the 16 Oct centrepiece?
5. May candy be bought at all (through gems), or is it earn-only?
6. Does Halloween return next October with the same eggs, so only "2026" titles are truly limited?

## Borrowed from

- **Pet Simulator 99:** Huge pets that always deal 150% of your best pet (Rule 2). A Halloween World whose areas open through quests, with the chase pet in the last egg.
- **Pet Simulator X, Halloween 2021:** candy drops in every world, not only the event area.
- **Adopt Me:** trick-or-treating and a candy shop. Its candy cannot be spent after the event, which is why this plan adds a spend-only week.

## Sources

- https://create.roblox.com/docs/production/monetization/paid-random-items
- https://www.u7buy.com/blog/ps99-titanic-vs-huge-pet/
- https://thefilibusterblog.com/ultimate-guide-to-pet-simulator-99-halloween-world/
- https://www.gfinityesports.com/article/pet-simulator-x-halloween
- https://progameguides.com/?p=61482
- `docs/RESEARCH.md` (restricted regions, Home ranking signals), `docs/PLAN.md` (dates, prices, rules)
