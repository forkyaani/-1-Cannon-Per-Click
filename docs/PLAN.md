# PLAN: +1 Cannon Power for Eggs

> **CONCEPT SUPERSEDED (2026-10-02, Yaani's decision).** The game is now **"+1 Cannon Power Per Click"**, a wave-based
> simulator/clicker in the "+1 X Per Click" wave, not the "for Eggs" launch game described below.
> The numbers, budget, dates, stop-loss rules and human checklist in this file still apply; the game design sections do not.
> Current design: `docs/DESIGN.md`. Yaani confirmed 18+ with a card.

**Window:** 2026-10-02 to 2026-12-31 · **Budget:** $150 total · **Team:** Yaani + Claude (all code)

**Labels:** **S** = SOURCED (a cited page, via the research reports) · **E** = ESTIMATE (benchmark-based, or computed from S/E inputs) · **G** = GUESS.
Dates and prices we choose are decisions, not forecasts. Sources were opened by the research agents on 2026-10-02; this final pass did not re-open them. Nothing was play-tested. Full research: `docs/RESEARCH.md`.

---

## TL;DR (10 lines)

1. **Game:** "+1 Cannon Power for Eggs". Power ticks +1/s, you fire yourself down a shared strip, land on rarer eggs, pets pay coins.
2. **Honest odds of 100,000 Robux cleared by Dec 31: 2–3% (G).** Most likely result: 1,000–3,000 Robux, about $4–11 (G).
3. **Realistic win:** pass Roblox's audience gate and clear 5,000 Robux. Odds about 20% (G).
4. **The maths:** 100,000 net = 142,857 gross player spend (S, 70% payout). That needs 120,000–270,000 plays at realistic monetisation (E).
5. **Sales cutoff:** plan to Dec 1. The payout hold may be 30 days, not 3–7 (unconfirmed). December is a bonus.
6. **Launch:** v0 on Sat Oct 10 (latest Tue Oct 13), Halloween-skinned, 3 bands. v1a Oct 16. v1b Oct 23.
7. **Biggest blocker:** new games reach only age-checked 16+ users until 250 "highly engaged" players (S). Expect to pass Nov 1–20 (G).
8. **Budget:** $13 gate fee + $50 ads in the first two weeks + $25 Halloween + $30 November + $20 conditional + $12 reserve = $150.
9. **Stop-loss:** on Nov 3, if D1 is under 6% OR bounce is over 40%, freeze all remaining ad money.
10. **Today:** tell Claude whether you are 18+ with a card, install Studio, verify the account.

---

## This week (Oct 2–8): Yaani's checklist

About 3 h of listed tasks, plus 2–4 h of "does this bug happen on your phone" loops (G).

**Fri Oct 2**
- [ ] Tell Claude: are you 18+ with a debit/credit card? (1 min; decides the whole ad budget)
- [ ] Install Roblox Studio and log in (15 min)
- [ ] Verify email, do the age check, turn on 2-Step Verification (20 min)
- [ ] Create the Ads Manager account and add your card yourself (15 min)
- [ ] Click **Connect** in the Rojo plugin; enable "Studio as MCP server" in Assistant → Manage MCP Servers (7 min)
- [ ] Open the "Promoting Items to Younger Audiences" help page and paste the text to Claude (5 min; it blocked the researcher with a 403)

**Sat Oct 3**
- [ ] Publish an empty private place; send Claude the universe ID and place ID; enable "Studio Access to API Services" (6 min)
- [ ] Create an Open Cloud key (`universe-places` write) and save it in the git-ignored `.env` (10 min)

**Sun Oct 4**
- [ ] Phone test: the cannon arc only (20 min). Does it stutter? Does the camera fight your thumb?

**Mon Oct 5**
- [ ] Decide with Claude: Cannon or Jetpack (5 min)

**Tue Oct 6 (admin day)**
- [ ] Create 3 store items and paste the IDs: 2x Power pass, 2x Coins pass, Coin Pack S (15 min)
- [ ] Fill in the maturity questionnaire (10 min; v0 has no paid random items)
- [ ] Buy 1,000 Robux and pay the Kids/Select fee (5 min; about $13, G)
- [ ] Upload a first icon made from a cannon screenshot, to test moderation early (10 min)

**Thu Oct 8**
- [ ] Phone test: the full loop (20 min)
- [ ] Draft ad campaign 1 in Ads Manager, do not submit yet (10 min)
- [ ] Search Roblox for "Cannon for Eggs" (2 min). If one exists, tell Claude

**What Claude builds this week:** project setup, saving, net layer, balance config, cannon spike (by Oct 4), Power tick, landing and egg pick, hatching, pets, coins, cannon tiers, rebirth, shop, HUD, tutorial arrow, funnel events, Halloween palette.

---

## 1. Honest outcome

| Outcome | Odds | Label |
|---|---|---|
| 100,000 Robux cleared by Dec 31 | 2–3% | G |
| Realistic win: gate passed + 5,000 Robux cleared | about 20% | G |
| Most likely: 1,000–3,000 Robux cleared ($4–11) | about 60% | G |

- **Scale check:** 100,000 Robux is $380 at DevEx (S). Cash-out needs 30,000 earned Robux (S), so the most likely result cannot be cashed out.
- **What the $150 buys:** measurement data and the audience gate. It does not buy the traffic.
- **Where 2–3% comes from:**
  - Home "expand" fires in 5–10% of outcomes (G).
  - In about 30% of those (G), the game also earns 0.67+ net Robux per visit, expands by mid-November, and the hold lets it clear.
  - That gives 1.5–3%. The "modest trickle" path adds about 0.3% (E): it tops out near 80,000 Robux even at stretch monetisation.
- **Why it is worth doing anyway:** a shipped, measured game and a passed gate are reusable. Treat the 100K as a stretch, not the plan.

---

## 2. The game

| Item | Decision |
|---|---|
| Title | **+1 Cannon Power for Eggs** |
| Hook | "Every second is +1 Cannon Power: blast yourself further down the strip and land on rarer eggs." |
| Core loop | Power ticks everywhere → FIRE → land in a distance band → choose 1 of 3 eggs → auto-return → hatch → pet pays coins/sec → coins buy cannon tiers → rebirth → further bands |
| Why this one | Verb untaken on Oct 2 (S). Outcome is set by your stat, no PvP, no egg loss: the pattern of the 97–98% rated games (E) |
| Backup | **+1 Jetpack for Eggs**: same code, bands vertical. Switch on Oct 5 if the arc feels bad on a phone, or if a "Cannon for Eggs" appears before launch |
| December re-title | **+1 Cannon Power for Presents** (G). Noun and theme are one config table. Decide Nov 20 from what is charting |

**Hard rules**
- The player never loses an egg they hold.
- No Robux prompt before the first rebirth. HUD has one Shop button plus one contextual offer, nothing more.
- Rebirth resets Power only. Coins, pets and cannon tiers stay.
- Every egg shows its odds as percentages summing to 100%.
- Server owns all state. The server picks the landing band from Power; the client plays a cosmetic arc and then teleports.

**First 10 minutes (all timings G; tuned in an offline simulation)**

| Minute | Player does | Sees |
|---|---|---|
| 0:00 | Spawns at own cannon on the shared firing line with Power 10; arrow on FIRE | Power ticking +1/s |
| 0:05–0:15 | Presses FIRE; lands in band 1 | Distance in metres, "NEW RECORD" pop |
| 0:15–0:30 | Walks to 1 of 3 eggs; auto-return; first egg hatches instantly | First pet, coins/sec starts |
| 0:30–2:00 | 2–3 more launches (tap to skip the arc); buys cannon tier 2 | Cannon shows "+2/s"; band 2 opens at 30 Power |
| 2:00–5:00 | Reaches bands 2–3 | Locked silhouettes of the next bands; day-2 calendar pet teaser (v1a) |
| 5:00–8:00 | Reaches band 4 free (v1a); starts a 4–8 h egg | A reason to come back |
| 8:00–10:00 | First rebirth: x1.5 Power gain | Starter pack shown once, no countdown |

**Economy (all G until simulated)**

| Thing | Rule |
|---|---|
| Power | +1/s everywhere, including mid-flight. Multiplied by cannon tier, rebirths and the 2x pass |
| Cannon tier | It is the Power-per-second multiplier, shown on the cannon as "+3/s". Bought with coins |
| Coins | Paid per second by pets. Buy cannon tiers and incubator slots. Never buy eggs |
| Band gates | 10 / 30 / 100 / 300 / 1,000 Power: about 3x steps (the draft's 10 / 50 / 250 / 1.5K / 10K walled at band 4) |
| Rebirth 1 | Tuned to land at minute 8–10; cost rises about 4x each time; x1.5 Power gain (S: competitors use x1.5–x2) |
| Must hold in simulation | Band 4 reachable free in session one |

**Scope by release**

| Release | Date | In |
|---|---|---|
| **v0** | Sat Oct 10 (latest Oct 13) | Shared firing line; 3 bands; 3 eggs x 3 pets; 3 cannon tiers; auto-equip best pets; rebirth; saving; one tutorial arrow; odds labels; personal-best distance; bands 4–5 as locked silhouettes; 6 funnel events; Halloween palette and pumpkin egg; 3 store items |
| **v1a** | Fri Oct 16 | Bands 4–5 with 4–8 h incubation; offline earnings (8 h cap); daily calendar with the day-2 pet shown early; codes; starter pack; 3 more store items |
| **v1b** | Fri Oct 23 | Pet Index with a bonus per completed band; gold and rainbow variants (15 pets become 45 entries, config only); in-server record board; Auto-Launch and VIP passes |
| **Weekly after** | from Oct 30 | One band plus one code. Nothing else |
| **Only if D1 is 10%+** | — | Global leaderboards, Lucky Eggs pass, pet fusion, World 2, YouTuber DMs, server-wide 2x |
| **Never** | — | Trading, PvP stealing, Discord, Instant Rebirth, Skip Incubation |

- **v0 is tight:** it sizes at 8.5–14.5 build-days against 8 calendar days (G). If it slips, cut in this order: cannon tier 3, band 3, rebirth polish. Do not slip past Oct 13.
- **Build approach (S, build research):** Rojo-managed, ProfileStore vendored as one file, one hand-written Net module, no Knit/React/Wally. Claude tests through Studio's MCP server, so Studio must be open.
- **v0 map:** small enough to turn streaming off, so the landing band is always loaded.

---

## 3. The numbers

**Target:** 100,000 Robux, net of Roblox's 30% cut, showing as cleared (not pending) by 2026-12-31.
- Gross needed: 100,000 / 0.70 = **142,857 Robux** of player spend (S inputs, computed).
- Counted: game passes and developer products only. Creator Rewards count as zero (60-day hold, S).

**3a. When must the Robux be earned?**

| Payout hold | Last sale date that clears | Label |
|---|---|---|
| 3–7 days | Dec 24, with zero margin | S (2020 post) |
| 14 days | Dec 17 | unconfirmed (search summaries) |
| 30 days | **Dec 1 (what we plan to)** | unconfirmed (2026 threads, no staff reply) |

- **Check:** time the first real sale. If it has not cleared 8 days later, assume 30 days.
- **Selling days:** about 49 from an Oct 13 launch to Dec 1; about 72 to Dec 24.
- **Full-audience days:** the gate probably passes Nov 1–20 (G). That leaves 11–30 full-audience days to Dec 1, or 34–53 to Dec 24.

**3b. Plays needed to reach 100,000 net**

| | Median game | Realistic centre | Above median (draft "base") | Top 10% | Label |
|---|---|---|---|---|---|
| D1 / D7 retention | 6% / 1% | between median and 10% / 3% | 10% / 3% | 18% / 6% | S benchmarks |
| Net Robux per new player | 0.36 | 0.8–1.8 | 3.15 | 13.0 | E |
| Net Robux per play | 0.19 | 0.4–0.8 | 1.05 | 2.80 | E |
| New players needed | 274,700 | 57,000–128,000 | 31,700 | 7,700 | E |
| **Plays needed** | **535,700** | **120,000–270,000** | **95,200** | **35,700** | E |
| Plays per day over 49 days | 10,900 | 2,450–5,500 | 1,940 | 730 | E |

- **Plain version:** at the realistic centre you need about 17–38 players online around the clock for 7 weeks (E, assuming 15 min per player per day, G).
- **Downside warning:** one DevForum thread title reports a game averaging 60–78 players online earning only 25,000 Robux in a year (S, title only; thread not opened). Monetisation can be far below this table.
- **Ads cover almost none of it:** $125 of ads buys about 830 / 3,100 / 12,500 plays at $0.15 / $0.04 / $0.01 per play (G). At base cost that is 1–3% of the plays needed.

**3c. What to expect**

| Traffic scenario | Odds (G) | Plays | Net Robux at 0.4–0.9 per play | Reaches 100K? |
|---|---|---|---|---|
| Algorithm never expands | 60% | 1,500–4,000 | 600–3,600 | No |
| Modest Home and search trickle | 30% | 10,000–40,000 | 4,000–36,000 | No. 80,000 at best (40K plays x 2.0) |
| Home "expand" fires | 5–10% | 150,000–1M+ | 60,000–900,000 | Only at 0.67+ per play, and only if it fires by mid-November |

**3d. Metrics the game must hit**

| Metric | Gate | Stretch | Read it when | Label |
|---|---|---|---|---|
| Fired cannon within 60 s | 85%+ of joiners | 95% | after test 1 | G |
| Hatched first pet | 70%+ | 85% | after test 1 | G |
| Reached band 2 | 45%+ | 60% | after test 1 | G |
| Reached first rebirth | 20%+ | 35% | after test 1 | G |
| Opened the shop | 15%+ of players | 25% | after test 1 | G |
| Bounce under 60 s | 30% or less | 20% | after test 1 | G |
| Average playtime | 8 min+ | 10–12 min | after test 1 | S (forum anecdote) |
| Ad cost per play | $0.05 or less | $0.02 | after test 1 | G |
| D1 retention | 10%+ | 15% | 500+ pooled ad plays (Nov 3) | S benchmark, G gate |
| D7 retention | 3%+ | 5% | Nov 10 onward | S benchmark, G gate |
| Net Robux per play | 0.5+ | 1.0 | 2,000+ pooled players | E |
| Daily payer % | 1%+ | 1.5% | 2,000+ pooled players | E |
| "Highly engaged" players | 250 by Nov 20 | 250 by Nov 1 | weekly, Audience Reach dashboard | S threshold, G date |

- **Why funnel steps come first:** test 1 buys only 100–375 plays. That reads D1 to within 3–6 points, too wide to tell 6% from 10% (E). Funnel steps are readable at that size.
- **Pool the cohorts:** judge D1 on all ad plays together, not per campaign.

---

## 4. Store

Prices are G picks inside competitor ranges (S: VIP 149, 2x Money 160–399). Regional pricing discounts passes by default (S), so real income per sale is below list.

| Ships | Type | Item | Robux |
|---|---|---|---|
| v0 | Pass | 2x Power ("+1" becomes "+2") | 199 |
| v0 | Pass | 2x Coins | 149 |
| v0 | Product | Coin Pack S (sized as minutes of your own income) | 49 |
| v1a | Product | Starter pack, once: named pet, coins, 15 min 2x. No random item, no countdown | 49 |
| v1a | Product | Coin Pack M / L | 199 / 799 |
| v1a | Product | 2x boost, 15 min | 29 |
| v1b | Pass | Auto-Launch (AFK fire and collect) | 249 |
| v1b | Pass | VIP (tag, +20% coins, fixed daily chest) | 99 |
| v1b | Product | 2x boost 60 min; 2x offline claim | 79; 25 |
| v1b (optional) | Product | Pumpkin pet, direct purchase, ends Nov 2. Forecast revenue: 0 | 299 |
| Dec 1 (bonus) | Product | Christmas pet, direct purchase, Dec 1–24 | 399 |
| Only if D1 is 10%+ | Pass | Lucky Eggs (policy-gated), +2 incubator slots, +1 Egg Carry | 299 / 149 / 99 |

**Compliance**
- Eggs are earned by launching, never bought. Robux buys only fixed items. So v0 and v1 have no paid random items (S rules).
- If Lucky Eggs ever ships: check `ArePaidRandomItemsRestricted`, show live odds, and redo the maturity questionnaire (S).
- No countdown timers or scarcity wording until the younger-audiences policy page has been read.
- Free Creator Store assets: meshes and images only, delete every script (S: backdoor risk). No brainrot, anime or branded characters.
- Private servers free. No trading.

---

## 5. Budget ($150 total)

Ad dates assume an Oct 10 launch. If launch slips, shift test 1 by the same number of days.

| # | When | $ | For | Continue if | Otherwise |
|---|---|---|---|---|---|
| 1 | Oct 6 | 13 | 1,000 Robux for the Kids/Select fee (price G) | — | Overage comes from the reserve |
| 2 | Oct 11–13 | 15 | Ad test 1, $5/day, Engagement objective (Plays if unavailable) | Funnel gates in 3d pass; cost per play $0.05 or less | Cost over $0.10: redo the icon. Bounce over 40%: fix the first 60 s. Pause spend until fixed |
| 3 | Oct 16–22 | 35 | Gate push with v1a, $5/day | Highly-engaged count rising | Keep fixing the first session; do not add spend |
| 4 | Oct 28–Nov 1 | 25 | Halloween weekend, $5/day | Nov 3 read passes (below) | Stop-loss |
| 5 | Nov 9–14 | 30 | November push with a new band, $5/day | Gate passed or close; organic Home impressions rising | Stop ads; effort goes to retention and clips |
| 6 | Conditional | 20 | If the first sale cleared within 8 days: Christmas push Dec 4–10. If not: spend it Oct 23–27 with v1b | — | — |
| 7 | After Nov 3 | 12 | Reserve: fee overage, an icon, or doubling the best campaign | — | Keep it |
| | **Total** | **150** | | | |

- **Front-loading:** $50 lands in the first 12 days (lines 2–3). Passing the gate is estimated at $20–65 of ads (E, from developer anecdotes).
- **Nov 3 stop-loss:** on pooled ad plays (target 500+), if D1 is under 6% **OR** bounce is over 40%, freeze everything left ($42–62).
- **All hold-sensitive money is spent by Nov 20**, except line 6 when the short hold is confirmed.
- **If you are under 18:** ads must be bought through Robux, and the $137 becomes about 33 ad credits (E). Run lines 2–3 only and drop lines 5–6.
- **The fee:** refundable, but the refund lands 90 days after eligibility (S), after the deadline. Treat it as spent.

---

## 6. Schedule

| Wk | Dates | Ships | Check or decision |
|---|---|---|---|
| 1 | Oct 2–8 | Setup; cannon spike; v0 systems | Oct 4 arc on phone · Oct 5 Cannon vs Jetpack · Oct 6 admin done · Oct 8 full loop on phone |
| 2 | Oct 9–15 | Oct 9 final icon + 3 thumbnails · **v0 public Sat Oct 10** (latest Oct 13) · ad test 1 | Oct 15: read funnel gates |
| 3 | Oct 16–22 | **v1a Oct 16** · gate push ads | 8 days after first sale: has it cleared? |
| 4 | Oct 23–29 | **v1b Oct 23** · Halloween ads from Oct 28 | — |
| 5 | Oct 30–Nov 5 | Halloween weekend · band 6 + code | **Nov 3: pooled D1 and bounce → stop-loss** |
| 6 | Nov 6–12 | Band 7 + code · November ads from Nov 9 | Highly-engaged count |
| 7 | Nov 13–19 | One band + code | All hold-sensitive ad money spent |
| 8 | Nov 20–26 | Christmas skin built in config | **Nov 20: is "for Eggs" still charting? If not, re-title.** Gate passed? |
| 9 | Nov 27–Dec 3 | **Christmas live Dec 1** | **Dec 1: planning sales cutoff** |
| 10 | Dec 4–10 | One band + code · line-6 ads only if the hold is short | — |
| 11 | Dec 11–17 | One band + code | Dec 17: cutoff if the hold is 14 days |
| 12 | Dec 18–24 | No ads | Dec 24: last sale that can clear at a 7-day hold |
| 13 | Dec 25–31 | Nothing new counts | **Dec 31: count cleared Robux** |

**Daily during build:** Claude checks whether a "Cannon for Eggs" has appeared and reports it.

---

## 7. Human-only tasks after this week

Before launch the human total is about 10–13 h (G), three times the draft's figure. After launch it is about 1.5–2 h per week.

| When | Task | Min |
|---|---|---|
| Fri Oct 9 | Make the final icon and 3 thumbnails from in-game screenshots; upload | 180 |
| Fri Oct 9 | Phone test the launch build | 20 |
| Sat Oct 10 | Set the game public; submit ad campaign 1 (review takes up to 24 h, S) | 10 |
| From Oct 11 | Post a 15–25 s clip to TikTok and Shorts, 3 times a week | 20 each |
| Thu Oct 15 | Create 3 v1a store items; paste IDs; submit campaign 2 | 20 |
| About Oct 18–20 | Check whether the first sale moved from pending to cleared | 2 |
| Thu Oct 22 | Create v1b store items; paste IDs | 20 |
| Tue Oct 27 | Submit campaign 3; phone test v1b | 25 |
| Tue Nov 3 | Read the dashboard with Claude: D1, bounce, highly-engaged count | 15 |
| Sun Nov 8 | Submit campaign 4 if the gates passed | 5 |
| Fri Nov 20 | Check the charts for "for Eggs"; decide the re-title with Claude | 10 |
| Mon Nov 30 | Create the Christmas pet product | 10 |
| Each update | Phone test | 20 |

Not doing: daily clips, YouTuber DMs (until D1 is 10%+), Discord.

---

## 8. Biggest risks

| # | Risk | What we do |
|---|---|---|
| 1 | **Audience gate.** Only age-checked 16+ users until 250 highly engaged players (S). Criteria unpublished | Launch Oct 10; pay the fee Oct 6; $50 of ads in the first 12 days; watch the count weekly |
| 2 | **The egg wave fades.** 45–60% it still pulls traffic in late October, 15–30% by December (G) | Launch early; theme and noun in one config table; re-title decision Nov 20 |
| 3 | **Payout hold is 30 days.** Then nothing sold after Dec 1 counts | Plan to Dec 1; measure the hold on the first sale |
| 4 | **v0 does not fit in 8 days**, or the arc feels bad on a phone | Oct 4 spike; Oct 5 decision; fixed cut order; Jetpack backup |
| 5 | **Under 18.** Ad budget shrinks to about a third (S/E) | Answer today |
| 6 | **Monetisation under 0.5 Robux per play** | Starter pack at first rebirth; 2x Power and Auto-Launch; no "scam" triggers |
| 7 | **A factory studio ships a Cannon game first** (they ship a verb every 1–2 weeks, S) | Daily check; Jetpack backup; shared firing line and distance records as the visible difference |
| 8 | **Policy strike** on random items or prompts aimed at kids | No paid random items; odds on every egg; no countdowns until the policy is read |

---

## 9. What changed from the draft

**Numbers critique**

| Critique | Decision |
|---|---|
| Hold length is unresolved | **Fixed.** Plan to a Dec 1 cutoff; December is bonus; day-8 check moves $20 |
| Audience gate underfunded | **Fixed.** Engagement objective from launch; $50 in the first 12 days; pass assumed Nov 1–20; Halloween-pet revenue forecast at 0; fee treated as spent |
| "Base" column is above median | **Fixed.** Columns relabelled; realistic centre is 120K–270K plays; gate set at 0.5 net Robux per play |
| Odds and "most likely" inflated | **Fixed.** 2–3%, most likely 1K–3K Robux, success redefined as gate + 5K |
| $150 cannot power the gates | **Fixed.** Funnel-step gates, pooled cohorts, OR stop-loss, 18+ question is task one |

**Design critique**

| Critique | Decision |
|---|---|
| First 75 s are watch-only | **Fixed.** Spawn with Power 10, arrow on FIRE, instant first hatch, Power ticks everywhere, choose 1 of 3 eggs |
| Nothing unfinished at logout | **Fixed, in phases.** Silhouettes at v0; long incubation and calendar in v1a; Pet Index and variants in v1b. **Rejected for v0:** no capacity |
| Late clone, invisible difference | **Fixed.** New title, shared firing line, distance records at v0, in-server board in v1b, daily verb check, December title chosen. **Rejected:** global leaderboard until D1 is 10%+ |
| Economy unclear, walls early | **Fixed.** Tier = Power per second; gates about 3x; band 4 free in session one |
| Store "scam" triggers | **Fixed.** Rebirth resets Power only; Instant Rebirth and Skip Incubation dropped; odds on every egg; no countdown; one Shop button plus one offer; tap-to-skip arc |

**Schedule critique**

| Critique | Decision |
|---|---|
| v1 is 1.2–2x over capacity | **Fixed.** v0 on Oct 10 (latest Oct 13), then v1a and v1b. **One addition kept:** 6 funnel events in v0, because the gates need them |
| Core mechanic untested on phone | **Fixed.** Oct 4 spike, Oct 5 decision, cosmetic client arc, streaming off, 2 HUD buttons at most |
| Human work understated 3x | **Fixed.** 3 store items and 3 thumbnails at v0; clips 3 times a week; no DMs; human estimate tripled |
| Admin gates have zero slack | **Fixed.** Private place Oct 3; store, questionnaire, fee and first icon Oct 6; ad drafted Oct 8. Final art follows on Oct 9 |
| Weeks 3–4 collide | **Fixed.** v0 ships Halloween-skinned; cut list applied; weekly content is one band plus one code |

---

## 10. Unverified assumptions

- **Age:** Yaani is 18+ with a card.
- **Hold:** unknown between 3–7, 14 and 30 days until the first sale clears.
- **Fee:** 1,000 Robux costs about $13; the refund timing comes from one critique's reading of the docs.
- **Gate:** whether ad-driven plays count toward the 250, and what "highly engaged" means, are unpublished.
- **Ads:** the Engagement objective is available to a new account; cost per play is $0.01–0.15.
- **Title:** "Cannon for Eggs" stays untaken until launch.
- **Monetisation:** 0.4–0.9 net Robux per play rests on old forum anecdotes and survivor-biased reports.
- **Mechanic:** a cosmetic client arc looks fine on a phone and other players can see it. Tested Oct 4.
- **Build sizes:** every size-day figure is a guess; v0 fits only at the low end.
- **Competitors:** timings come from written guides, not play.
- **Tooling:** Rokit tool names were given from memory; creating passes by API is unverified, so it stays manual.
- **Policy:** the younger-audiences promotion page has not been read.

---

## Sources

**Payout, hold, DevEx**
- https://devforum.roblox.com/t/unified-marketplace-fee-for-private-servers-paid-access-and-plugin-marketplace-sales/902229
- https://devforum.roblox.com/t/incoming-adjustment-to-pending-sales-waiting-period/832724
- https://devforum.roblox.com/t/robux-pending-for-over-4-weeks/4587819
- https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628
- https://devforum.roblox.com/t/enabling-regional-prices-for-all-passes-to-grow-your-global-audience/4471199
- https://create.roblox.com/docs/production/monetization/developer-exchange

**Monetisation benchmarks**
- https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox
- https://devforum.roblox.com/t/how-could-i-increase-robux-per-visit/1831270
- https://rowatcher.com/news/devex-math-in-2026-what-you-actually-take-home-per-1-000-players
- https://devforum.roblox.com/t/my-game-with-a-60-78-ccu-yearly-average-generates-25k-robux-a-year/3560194

**Policy**
- https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622
- https://create.roblox.com/docs/production/monetization/paid-random-items
- https://en.help.roblox.com/hc/en-us/articles/47965190783892-Promoting-Items-to-Younger-Audiences (not yet read)
- https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities

**Audience gate**
- https://create.roblox.com/docs/production/publishing/kids-and-select
- https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164
- https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717
- https://devforum.roblox.com/t/what-is-the-best-ad-strategy-to-reach-500-highly-engaged-players-for-an-under-16-multiplayer-focused-game/4806311

**Ads and discovery**
- https://create.roblox.com/docs/production/promotion/ads-manager
- https://create.roblox.com/docs/production/promotion/sponsoring-experiences
- https://devforum.roblox.com/t/sponsored-experiences-moving-to-ads-manager/2661756
- https://devforum.roblox.com/t/optimizing-my-games-cost-per-play-from-ads/3047197
- https://devforum.roblox.com/t/sponsors-in-ad-manager-cost-more-if-you-make-them-cheaper/3086156
- https://devforum.roblox.com/t/sponsorship-costs-and-long-term-ccu-stability/3121727
- https://bloxg.com/statistics/roblox-advertising-benchmarks
- https://create.roblox.com/docs/en-us/discovery
- https://www.gameanalytics.com/cn/reports/2025-roblox-report
- https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157
- https://devforum.roblox.com/t/game-launch-advertising-cost/3667546

**Market and meta**
- https://apis.roblox.com/search-api/omni-search?searchQuery=for%20eggs&sessionId=2&pageType=all
- https://games.roblox.com/v1/games?universeIds=10563114921,10764897725,10766138478,10371406677,10766721625,10763764817,10649255304,10472449476,10766723413,9557124946
- https://apis.roblox.com/game-passes/v1/universes/10764897725/game-passes?passView=Full&pageSize=100
- https://rowatcher.com/games/10563114921/steal-an-egg
- https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals
- https://en.wikipedia.org/wiki/Grow_a_Garden
- https://en.wikipedia.org/wiki/Steal_a_Brainrot
- https://allthings.how/?p=217553

**Build**
- https://create.roblox.com/docs/studio/mcp
- https://github.com/Roblox/studio-rust-mcp-server
- https://devforum.roblox.com/t/profilestore/3190543
- https://create.roblox.com/docs/cloud/guides/usage-place-publishing
- https://create.roblox.com/docs/production/promotion/game-icons
