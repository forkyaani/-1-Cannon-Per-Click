# Gems: premium currency plan

Proposal for the owner. In the code the currency is called "diamonds". The Halloween side is in `docs/HALLOWEEN_EVENT.md`.

- **Labels:** **C** = read from `Config.luau` or the code on 2 Oct · **E** = computed from C · **S** = sourced, links at the end · **G** = guess, tune it.
- **Sizes:** **S** under a day · **M** 1–2 days · **L** 3–4 days. One developer plus AI.
- Every new price, rate and multiplier here is my pick: treat it as **G** even where it is not marked. Nothing was play-tested.

## TL;DR

1. Call it **Gems**. "Diamond" stays a cannon, a mini cannon and a fuse tier. Change the words on screen only; keep the save key `diamonds`.
2. The rule: gems never buy a fixed number. They buy a percentage, time, a slot, a mini cannon that grows with you, or a cosmetic. Every free source is capped per day, per week or once.
3. Free income today: 635 a week (C). Proposed: 785 a week at every stage, plus 420 once from progress.
4. Two leaks to close before launch: rebirths pay 20 gems each with no cap, and the Gem Egg's fixed bonuses are worth 18 waves on day one and nothing after wave 100.
5. Sinks that never run out: six permanent upgrades with rising prices (59,230 gems to max), Second Wind on a failed wave, fuse catalysts, growing exclusives, event conversion, cosmetics.
6. Robux: six packs, 49 Robux (250 gems) to 2,499 Robux (21,000 gems). The first pack is doubled. Starter Pack at 49.
7. Passes own, gems rent. A gem version of a pass effect costs more in Robux terms, or is a timed rental.
8. Selling gems makes gem eggs "paid random items": odds on screen (already there) and a fixed-price path for restricted regions.
9. Build: rename and leak fixes (S) before launch, the store (M) by 23 Oct, then upgrades (M) and Second Wind (S).
10. To create on Roblox: 7 developer products and 1 game pass.

Decisions I need from you: section 10.

---

## 1. The name

| "Diamond" today | Where (C) |
|---|---|
| The currency | `data.diamonds`, "+20 diamonds" toasts, the HUD counter |
| Cannon 5 | "Diamond Cannon" (`CANNON_STYLES`) |
| A mini cannon | "Mini Diamond Cannon", the Basic Egg's Legendary |
| Fuse tier 3 | "Diamond" (`Config.FuseTiers`), which makes a "Diamond Mini Diamond Cannon" |

**Recommendation: Gems.**
- You already say it. The premium egg is already the "Gem Egg" (C). It is the genre's word.
- Change text only: the toasts in `Game.luau`, "25 Diamonds" in `Config.EventShop`, the missions board sign, the shop headers. About 25 lines.
- Add a `Config.CurrencyNames` table so "Not enough {currency}" prints "gems".
- Keep `diamonds` as the save key, the attribute and the `currency =` value. No migration.
- Rejected: Crystals (a Crystal Cannon exists), Stars (a Mini Star Cannon exists), Rubies (a Mini Ruby Cannon exists).
- Side note: fused names still read badly ("Gold Mini Gold Cannon"). Option: show the tiers as Shiny / Radiant / Mythic and keep the ids `silver`, `gold`, `diamond`.

## 2. What gems are for

Gems are the one currency that survives everything. Rebirths wipe coins. Events end and take candy with them. Gems stay. Players earn them slowly for showing up, or buy them with Robux, and spend them on things that are worth the same to a first-hour player and a last-world player.

**The rule that keeps them valuable: no gem price buys a fixed number.**
- **Sinks are relative.** A percentage, a length of time, a slot, a mini cannon that grows with you, or a cosmetic. Never "+500 power" or "1M coins".
- **Sources are capped.** Per day, per week, or once ever. Never per kill, per wave or per rebirth without a cap.
- **One-way valves.** Monsters, eggs and AFK time never drop gems. Candy to gems is capped at 250 an event (C). Gems to candy and back loses 75%.

**A handy unit.** Monster HP grows x1.35 a wave (C). Multiplying power by M is worth `ln M ÷ ln 1.35` waves: 2x = 2.3 waves, 10x = 7.7 waves.

**"Grows with you"** means: strength = a multiplier × **R**, where R is the Common of the newest coin egg the player has unlocked (`0.25 × 16 ^ floor(best wave / 25)`, C steps). Full detail: `HALLOWEEN_EVENT.md`, rule 2. Borrowed from Pet Simulator 99's Huge pets (S).

## 3. Leaks to close before launch

| Leak | Arithmetic | Fix |
|---|---|---|
| Rebirth pays 20 gems, no cap (C) | Past wave 300, every rebirth needs the same wave 300 (C: `rebirthWave`). My simulation: about 25 rebirths an hour between hours 3 and 10 of play, about 230 an hour between hours 10 and 30 (E). That is 500 to 4,600 gems an hour, against 91 a day from dailies | 20 gems for each of the 12 rebirth targets (240 in total). After that 5 each, at most 6 a day |
| Gem Egg bonuses are fixed, 200 to 15,000 (C) | A new player has 60 gems in the first session (missions pay 60 a day, C). A Gem Common (200) is 800x a Basic Common (0.25): worth 18 waves. At wave 100 a Mars Common is 16,384, so even the Gem Legendary is worthless | Gem Egg mini cannons grow with you |
| Weekly exclusives are fixed, 500 to 30,000 (C) | Same. The Dragon (30,000) loses to a Dune Egg Common (262,144) at wave 125 | Same fix |
| Three slots cost 750 gems (C: 250 × 3) | About 125 Robux of gems, against 299 Robux for the +3 slots pass | 250 / 750 / 2,000 |

- The simulation replays the Config formulas for a 6 taps/s player. It is a script, not a play-test.
- Extends: `Config.RebirthDiamonds`, `rebirth()`, the Gem Egg's `defineEgg`, `Config.WeeklyFeatured`, `Config.WeeklyFixed`, `purchase()`.

## 4. Sources

| Source | Amount | Early: Earth | Mid: Moon, Mars | Late: Neptune, Sun | End: Void, wave 300 | Cap | Change |
|---|---|---|---|---|---|---|---|
| Daily reward, 7-day streak | 10 · 15 · 20 · 25 · 30 · 40 · 75 (C) | 215 a week | 215 | 215 | 215 | once a day | keep |
| Daily missions, five | 10 + 10 + 15 + 10 + 15 (C) | 420 a week | 420 | 420 | 420 | daily | keep |
| Weekly missions, three | 50 each | 150 a week | 150 | 150 | 150 | weekly | new |
| First clear of every 25th wave | 15 (C) | 30 once | 60 once | 60 once | 30 once | 180 in total | keep |
| Rebirth | 20 (C) | 40 once | 80 once | 80 once | 40 once, then up to 30 a day | see section 3 | cap |
| Events | Candy trade 250 · achievements up to 715 · quest chain 50 · mission bonus 10 a day | same at every stage | | | | per event | keep and add |
| Codes | 50 a code | same at every stage | | | | one per update | new (PLAN has codes) |

**What a free player earns**

| Stage | Per day | Per week | Once, while passing through |
|---|---|---|---|
| Early | 112 | 785 | 70 |
| Mid | 112 | 785 | 140 |
| Late | 112 | 785 | 140 |
| End | 112, plus up to 30 from the rebirth loop | 785 to 995 | 70 |

- 112 = 215 ÷ 7 + 60 + 150 ÷ 7. Today it is 91 a day and 635 a week (C).
- During Halloween add about 10 a day, 250 from the candy trade and about 200 from achievements (G).
- The daily missions take 5–10 minutes at any stage (G; C goals: 1,000 shots, 400 kills, 15 bosses, 30 waves, 5 hatches). So income does not depend on how far you are.
- Weekly missions (G): play on 5 different days · clear 300 waves · fuse 3 mini cannons. They pay for coming back, which is what Roblox's Home ranking counts (`RESEARCH.md`).

## 5. Sinks, stage by stage

| Stage | Has about | Typical buys | Gems |
|---|---|---|---|
| Early | 785 a week + 70 | First Gem Eggs · first slot · level 1 of each upgrade · a boost when stuck | 60 each · 250 · 100–200 each · 30 |
| Mid | 785 a week + 140 | Second slot · the weekly exclusive · upgrade levels 2–4 · Second Wind at bosses | 750 · 150–800 · 150–510 each · 10–40 |
| Late | 785 a week + 140 | Third slot · upgrade levels 5–7 · catalysts · first cosmetics | 2,000 · 510–1,700 each · 15–540 · 300–1,500 |
| End | 785–995 a week | Upgrade levels 8–10 · Legendary catalysts · event candy and raid summons · status cosmetics | 1,700–5,800 each · 150–1,350 · 100–150 · 500–2,000 |

## 6. The catalogue

**A. Gem Workshop: permanent upgrades, prices rise x1.5 a level** (borrowed from Pet Simulator 99's upgrades, S)

| Upgrade | Each level | Levels | Prices | Total | Why a late-game player still wants it |
|---|---|---|---|---|---|
| Mini cannon slot | +1 equip slot | 3 | 250 · 750 · 2,000 | 3,000 | One more mini cannon's whole bonus and one more auto shot a second (C) |
| Lucky Hatch | +10% luck on Rare and better | 10 | 150 → 5,800 | 16,980 | Legendary 0.5% → 1%. Every new egg and every Diamond fuse (27 copies) needs it again |
| Extra Time | +1 second on every wave timer | 10 | 100 → 3,800 | 11,280 | Every wall is a timer (30–45 s, C) |
| Rapid Minis | +5% mini cannon fire rate (would do nothing now that mini cannon damage is flat: built as Mastery Mini Crit, `docs/BALANCE.md` 5c) | 10 | 120 → 4,600 | 13,690 | AFK damage, at every stage |
| Bounty | +10% coins | 10 | 100 → 3,800 | 11,280 | Each rebirth resets coins and the cannon (C) |
| Deep Pockets | +25 storage | 4 | 200 · 400 · 800 · 1,600 | 3,000 | One Diamond fuse needs 27 copies. Storage is 50 (C) |

- Full ladders: 100 · 150 · 220 · 340 · 510 · 760 · 1,100 · 1,700 · 2,600 · 3,800 (base 100). Base 120 and 150 follow the same shape.
- Everything maxed: **59,230 gems**. About 75 weeks of free income.
- Levels 1–5 of the four long ones, two slots and two storage levels: about 7,800. About 10 weeks.
- Extends: a new `Config.GemUpgrades` table and `data.upgrades`; `equipSlots`, `hatchOne` (luck), `Config.waveTime`, `autoShotsPerSecond`, `coinMult`, `petStorage`. One new window.

**B. Consumables and convenience**

| Item | Gems | Limit | Why it never gets old |
|---|---|---|---|
| 2x Power, 30 min (exists) | 30 | 3 a day | A percentage |
| 2x Coins, 30 min (exists) | 30 | 3 a day | A percentage |
| 2x Event loot, 30 min | 80 | 2 a day | A percentage. Timed over the Hollow and the doors it adds about 2,000 candy |
| Second Wind: on a failed wave, +15 seconds and no healing for 10 seconds | 10, doubling each use on the same wave | none | Offered at the moment it hurts. Walls exist at every stage |
| Time Warp: 60 clears of your current wave's coins, at once | 40 | 3 a day | Sized by your own income. Best right after a rebirth |
| Auto-Fire, 30 min (8 taps a second) | 30 | none | Rents the planned Auto-Fire pass |
| Auto Rebirth, 24 hours | 150 | none | Rents the Auto Rebirth pass |
| Head Start: keep your cannon through the next rebirth | 15 | none | Flat price because the effect is relative |
| Streak Saver: restore a missed daily streak | 50 | once a week | Protects the day-7 reward |
| Fireworks in the marketplace | 25 | none | Everyone in the square sees them |

- Today the two boosts are limited to 5 a week (C). Three a day lets boosts alone absorb a free player's whole income.
- Extends: `Config.WeeklyFixed`, `Config.Boosts`, `addBoost`, `failWave` (Second Wind), `actions.claimDaily`.

**C. Mini cannons that grow**

| Item | Gems | × R | Notes |
|---|---|---|---|
| Gem Egg (exists) | 60 | 1.5 · 2.5 · 5 · 12 · 40 at 50 / 30 / 15 / 4.5 / 0.5% | Your newest coin egg is 1 · 1.6 · 3 · 6 · 16. Never goes stale |
| Weekly exclusive: Neon · Royal Guard · Mecha · Dragon (exist) | 150 · 300 · 500 · 800 (C) | 3 · 6 · 10 · 16 | Up to 3 copies in its week at 1x, 1.5x, 2x the price. Three copies fuse to Silver |
| Calendar (exists, day-7 reward) | free | 2 | One copy per perfect week. Silver in 3 weeks, Gold in 9, Diamond in 27: a long streak goal |

**D. Fusing**

| Catalyst: stands in for one of the three copies | To Silver | To Gold | To Diamond |
|---|---|---|---|
| Common, Uncommon | 15 | 45 | 135 |
| Rare | 30 | 90 | 270 |
| Epic | 60 | 180 | 540 |
| Legendary | 150 | 450 | 1,350 |

- Coin-egg mini cannons only. Anything bought with candy or gems is excluded, or the catalyst would undercut its own egg.
- It is priced by the hatching time it saves (G). It stays relevant because every new egg starts the fusing again.
- Not random: 2 copies plus a catalyst always give the next tier. Keep fusing free of chance (see section 7).
- Extends: `actions.fusePet`, `Config.FuseCount`.

**E. Rebirth**
- Source: capped (section 3).
- Sinks: Auto Rebirth rental and Head Start (table B).

**F. Weekly shop** (exists; rotates Thursday 00:00 UTC, C)
- One growing exclusive (table C), one rotating cosmetic, the fixed rows (slot, boosts).
- Extends: `Config.WeeklyFeatured`, `Config.WeeklyFixed`, `Config.weeklyItems`.

**G. Events**

| Item | Gems | Limit |
|---|---|---|
| Gems to event currency | 100 → 500 candy | 2,000 gems a day |
| Event gem egg (Witch's Egg) | 120 | none |
| Run Pumpkin Hollow again tonight | 100 | 2 a day |
| Summon the Pumpkin King for the whole server | 150 | none |

- Events are the big recurring sink: every event brings a new set to chase, and gems are the way in. No separate currency packs to sell.

**H. Cosmetics and status** (never lose value, never add power)

| Item | Gems |
|---|---|
| Cannon skins (colour, material, trim) | 400 – 1,500 |
| Shot colour and kill effect | 300 |
| Titles and name colour | 250 – 1,000 |
| Lane theme (floor and backdrop) | 800 |
| Gold name on the leaderboards | 2,000 |

- Extends: `Arena.buildCannon`, the lane label in `Arena.showWave`, `Effects.luau`.

## 7. Robux packs

| Pack | Robux | Gems | Gems per Robux | In weeks of free income |
|---|---|---|---|---|
| Pouch | 49 | 250 | 5.1 | 0.3 |
| Sack | 99 | 550 | 5.6 | 0.7 |
| Chest | 249 | 1,500 | 6.0 | 1.9 |
| Crate | 499 | 3,300 | 6.6 | 4.2 |
| Vault | 999 | 7,500 | 7.5 | 9.6 |
| Hoard | 2,499 | 21,000 | 8.4 | 27 |

- All G. A week of free gems (785) is worth about 140 Robux at the Sack rate.
- The developer gets 70% (PLAN). Regional pricing is opt-in for developer products (`RESEARCH.md`).
- **First purchase:** the first pack a player ever buys gives double gems. Once.
- **Starter Pack, 49 Robux, once:** 300 gems, a Mini Rocket Cannon (grows, 6 × R), 2x Power for 60 minutes. Nothing random. Shown once after the first rebirth, no countdown (PLAN rules).
- **VIP pass, 149 Robux:** double gems from the daily reward (+215 a week), a VIP title, a gold name. Pays for itself in about 4 weeks against packs.

**Gems and passes: passes own, gems rent** (Robux value at 6 gems per Robux)

| Pass (C price) | Gem version | Worth in Robux | Verdict |
|---|---|---|---|
| +3 slots, 299 | Three slots, 3,000 gems | 500 | The pass is cheaper. Both stack, up to 14 slots (C: 14 rack positions) |
| +5 slots, 549 | none | | Pass only |
| x3 Luck, 449 | Lucky Hatch at max: x2 for 16,980 gems | 2,830 | The pass is far cheaper. They multiply: Legendary 0.5% → 2.5% with both (C: `eggOdds`) |
| +500 storage, 249 | Deep Pockets: +100 for 3,000 gems | 500 | The pass is five times bigger for half the price |
| Auto Rebirth, 399 | Rental, 150 gems a day | 25 a day | The pass pays for itself in 16 days |
| x3 Egg Opener, 349 | none | | Pass only |
| 2x Power 199, 2x Coins 149 (planned in PLAN) | 30-minute boosts, 30 gems | 5 each | Two hours a day costs 20 Robux, so the pass pays back in 10 days. Pass × boost = 4x |
| Auto-Fire (planned) | Rental, 30 gems per 30 min | 5 | Same pattern |
| 2x Event Loot, 249 (Halloween plan) | 30-minute boost, 80 gems | 13 | An hour a day costs 27 Robux, so the pass pays back in 9 event days. Pass × boost = 4x |

- Rule of thumb: a gem version costs at least 1.5x the pass in Robux terms, or it is a rental that overtakes the pass price within about two weeks.
- So gems never make a pass pointless, and a pass never makes gems pointless: they stack.

**Roblox's rules for paid random items** (S)
- Once gems are sold, anything random bought with gems is a "paid random item": the Gem Egg, the Witch's Egg, and candy eggs through gems to candy.
- Lucky Hatch and the x3 Luck pass are "probability modifiers". Their effect must be shown in numbers and the odds on the stands must update live. The stands already show each player their own odds (C: `Market.refresh`).
- Where `PolicyService` reports `ArePaidRandomItemsRestricted`: hide gems to candy and Lucky Hatch, and turn the Gem Egg into "pick the one you want at a fixed price": the egg price divided by each chance, so 120 · 200 · 400 · 1,300 · 12,000 gems.
- Fusing and catalysts are guaranteed results, so they are outside the rule. A "chance to fail" or a "lucky fuse" would bring them inside it.

## 8. Inflation control

**What stops a hoard with nothing to buy**
- Faucets are fixed in gems and do not grow with progress. Bigger numbers elsewhere never touch them.
- Coming in: 785 a week. Going out every week: boosts up to 180 a day, Gem Eggs without limit, up to three copies of the weekly exclusive (675 to 3,600), the Workshop (59,230 in total).
- A free player who saves everything for four weeks holds 3,140. That buys one level-9 upgrade.
- Watch one number: the median balance of players active for 14 days or more. If it passes two weeks of income (1,600), add a sink. Never raise a faucet.

**What stops payers trivialising the game**
- Nothing sold is a flat amount of power or coins.
- The curve: even 10x power is under 8 waves, in a game of 300.
- The whole Workshop maxed (about 7,000–9,000 Robux) puts a player roughly 8–10 waves ahead (rough E).
- Hard caps: upgrade levels, 3 gem slots, 3 copies a week, Second Wind doubling per use, Time Warp 3 a day, gems to candy 2,000 a day.
- The Halloween candy board counts earned candy only.

## 9. Build order

| # | Item | Size | Extends | Roblox item |
|---|---|---|---|---|
| | **Before launch, Sat 10 Oct** | | | |
| 1 | Show "gems" everywhere | S | text only, `Config.CurrencyNames` | |
| 2 | Cap rebirth gems; slot prices 250 / 750 / 2,000 | S | `rebirth()`, `Config.WeeklyFixed` | |
| 3 | Gem Egg, weekly exclusives and Calendar grow with you | M, shared with Halloween item 5 | `definePet`, `Config.petBonus` | |
| | **By Fri 23 Oct** | | | |
| 4 | Store: developer products, `ProcessReceipt`, a receipt ledger in the save, gem packs, first-purchase double, Starter Pack | M | a new module beside `Passes.luau`, STORE window | 7 developer products |
| 5 | Policy check and the fixed-price Gem Egg | S | `PolicyService`, `hatchEgg` | |
| 6 | Second Wind | S–M | `failWave`, HUD | |
| 7 | Gems to candy, Hollow re-run, raid summon | S | needs the Halloween items | |
| | **By mid-November** | | | |
| 8 | Gem Workshop, six upgrades | M | table A list | |
| 9 | Time Warp, rentals, Head Start, Streak Saver, Fireworks | S each | table B list | |
| 10 | Fuse catalyst | S | `actions.fusePet` | |
| 11 | Weekly missions | S | `Config.Missions` pattern | |
| 12 | VIP pass | S | `Config.Passes`, `actions.claimDaily` | 1 game pass |
| 13 | Cosmetics in the weekly shop | M | section H list | |

- Everything priced in gems needs nothing created on Roblox. Only the packs, the Starter Pack and VIP do.
- Items 1–2 are an hour or two each and stop real damage. Do them first.
- New save fields go in `DEFAULTS` in `Data.luau`, or `reconcile` drops them (C).

## 10. Risks and open questions

**Risks**

| # | Risk | What to do |
|---|---|---|
| 1 | Saves have no session lock (C: `Data.luau`). Selling gems on that can lose or double a purchase | A receipt ledger at the least. ProfileStore is the real fix (`RESEARCH.md`, build notes) |
| 2 | Paid random rules apply from the first gem sold. The x3 Luck pass already needs the check, and no `PolicyService` or `ProcessReceipt` code exists yet (C) | Ship item 5 with item 4, never after |
| 3 | Every price and rate here is a guess. No competitor pack data was collected | Start with low faucets. Giving more later is easy; taking away is not |
| 4 | Pace: if the game is cleared in hours, the 420 one-time gems all land on day one | Fine with the caps. Re-check after tuning |
| 5 | PLAN's cutoff: sales after 1 Dec may not clear by 31 Dec | The store has to be live in October to count |
| 6 | The "Promoting Items to Younger Audiences" page is still unread (PLAN) | It may limit first-purchase and limited-time wording |
| 7 | Too many sinks at once confuse | One Workshop window, one shop, offers in context. No new HUD buttons (there are 7, C) |

**Open questions for you**

1. "Gems" as the name? Rename the fuse tiers on screen too?
2. Sell gems in October at all, or wait until saves are session-locked?
3. Is a 2,499 Robux pack acceptable in a game for younger players, or stop at 999?
4. Keep the Robux-priced boosts from PLAN (29 and 79 Robux), or gems only? I recommend gems only: fewer products to create.
5. VIP pass, yes or no?
6. Lucky Hatch: worth the extra policy work?
7. Rebirth gems after the first 12: 5 each and 6 a day, or nothing?

## Borrowed from

- **Pet Simulator 99:** upgrades as permanent diamond sinks whose price rises each time (section 6A). Huge pets that scale with your best pet ("grows with you").
- **Common practice in free-to-play (from memory, G):** a doubled first purchase, a one-time starter pack, a daily-login pass.

## Sources

- https://create.roblox.com/docs/production/monetization/paid-random-items
- https://bloxodes.com/wiki/pet-simulator-99/upgrades
- https://www.u7buy.com/blog/ps99-titanic-vs-huge-pet/
- `docs/PLAN.md` (store prices, rules, cutoff), `docs/RESEARCH.md` (policy, regional pricing, build notes)
