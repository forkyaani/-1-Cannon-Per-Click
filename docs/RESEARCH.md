# Research reports (reference)

These are the four research reports the plan in `PLAN.md` is built on, copied verbatim. They were produced on 2026-10-02. The critiques that changed the plan are summarised in `PLAN.md` section 9, not here.

Contents:
1. Meta: market and trend report
2. Money: monetization math
3. Growth: user-acquisition plan
4. Build: systems, schedule and risks

---

## RESEARCH: meta

# Market/meta report: "+1 stat / verb for Eggs" (snapshot 2026-10-02)

Labels: **S** = sourced, **B** = benchmark-estimate, **G** = guess. Ratings are computed as up/(up+down) from the Roblox search API. Nothing was play-tested; minute timings are inferred from written guides.

## 1. Shared core loop

Train stat → stat gates a trip → grab egg → carry home → hatch → pet pays cash/sec (also offline) → buy gear → rebirth for a permanent multiplier → next zone.

| Minute | Player does | Earns / sees | Label |
|---|---|---|---|
| 0:00–0:30 | Spawns on own plot; stands in auto-train zone | +1 stat per tick; 2x Money / VIP buttons on HUD | S (auto-train), G (HUD timing) |
| 0:30–2:00 | Walks/flies to zone 1, takes a Common egg, carries it home | First pet pays $10–95/s | S |
| 2:00–3:00 | Waits on hatch timer | Robux "skip incubation" prompt | S (exists), G (timing) |
| 3:00–5:00 | Takes first upgrades (free, then $15–$263) | Upgrade panel shows cash or Robux (3 R$) side by side: the first soft paywall | S |
| 5:00–8:00 | 2–4 more eggs; first gear ($1K–$30K, or 19 R$); farm expansion $18K | Zone 2 visible but stat-gated | S |
| 8:00–15:00 | First rebirth (speed 40, or 1,000 strength, or $50K) | x1.5–x2 permanent multiplier | S (thresholds), B (time) |

Monetisation actually listed (S):

| Game | Passes (R$) |
|---|---|
| Steal An Egg | 2x Money 399, 2x Growth 467 |
| +1 Wings For Eggs | VIP 149, 2x Money 199, 2x Growth 349; wings 19–799; +1 Carry 99 |
| +1 Strength for Eggs | VIP 149, 2x Money 160, 2x Strength 199, 2x Growth 280 |

Other shared features (S): 7-day login calendar, offline earnings, 7-player servers (Steal An Egg).

## 2. Verbs taken vs open

**Taken (S):** Steal, +1 Wings/Fly, +1 Strength, Race, Run, Drill, Dig, Mine, Swim, Sail, Boat, Build A Boat, Swing, Climb, Jump, Pull, Carry, Rope, Shoot, Laser, Punch, Throw, Kick, Drive, Fish, Shuffle, Crack, Break, Clone, Hoverboard, Open Sea, Backflip, Ride, Survive Waves, Dive.

| Candidate | Exists? (S) | Verdict |
|---|---|---|
| **Dive for Eggs** (+1 oxygen) | Yes, twice, both tiny: "Dive for Eggs!" (4 CCU, 189K visits, 97.8%) and "Dive for Eggs" by Deepwave (113 CCU, created 09-16, 88%). Adjacent: Swim For Eggs (6.5K CCU, 93.5%). "Dive For Brainrots!" had 26M visits at 97.9% and is now at 14 CCU. | Mechanic proven; title not free; two prior egg attempts failed to get traffic |
| Launch / +1 Cannon for Eggs | No match. "Launch Plane for Brainrots" had 100K upvotes at 97% | Open |
| +1 Jetpack for Eggs | No "for Eggs". "+1 Jetpack for Animals" 53 CCU; "for Brainrots" 1K CCU, 89% | Open but a Wings clone |
| +1 Magnet for Eggs | No match | Open, unproven |
| Sled / +1 Sleigh for Presents | No match | Open; December only |
| Trick-or-Treat / +1 Broom for Eggs | No match | Open; too late for a late-October launch |
| Grapple, Bounce, Skydive for Eggs | No match | Open, but physics-skill risk (see section 3) |

## 3. Why 95%+ vs 70–85%

| Game | Rating | CCU | Mechanic |
|---|---|---|---|
| Race for Eggs | 98.1% | 14.5K | Stat vs fixed-pace bots, auto-race |
| Break and Steal an Egg | 98.0% | 53K | Not researched |
| +1 Wings For Eggs | 97.9% | 26K | Stamina-gated flight |
| +1 Strength for Eggs | 97.5% | 24K | Auto-train |
| Steal An Egg | 92.4% | 1.77M | PvP theft |
| Dig For Eggs | 88.1% | 9K | Not researched |
| Pull An Egg | 87.8% | 9K | Drag on rope while a guard takes it back |
| Swing For Eggs | 84.7% | 8.7K | Web-swing over guardians |
| Shuffle an Egg | 82.1% | 7.4K | Not researched |

My reading (B, inferred from the table, not from player reviews):
- **High raters** are deterministic: your stat decides the outcome, training is automatic, and nobody can take your stuff.
- **Low raters** add loss or dexterity: guards reclaiming eggs, swing physics, and probably luck in Shuffle (G).
- **PvP theft** costs rating points. Steal a Brainrot (85%) is criticised for griefing and for the best items being cash-only (S, Wikipedia/Polygon).
- **Design rule:** never let the player lose an egg they already hold. For Dive, running out of air should mean "teleported to the surface, egg kept".

## 4. Rotation speed and risk

| Meta | Launch | Peak | Later | Hot for |
|---|---|---|---|---|
| Grow a Garden | 2025-03-26 | 22.3M (2025-08-23) | 22K now | ~5 months (S) |
| Steal a Brainrot | 2025-05-16 | 25.4–25.8M (Oct 2025) | 215K early 2026; 81K now | ~5–6 months (S) |
| Escape Tsunami / "for Brainrots" clones | Jan 2026 | ~5M | 164K about two months later | ~2–3 months (S/B) |
| Steal An Egg | 2026-07-25 | 14.3M (Sep 2026) | 1.77M now (-88%) | ~2 months so far (S) |
| "for Eggs" clones | mostly 09-02 to 09-16 | Swing: 38K | Swing: 8.7K five days later (-77%) | Weeks (S) |

Pet sims were not researched; I have no sourced lifespan for them.

- **The wave is about 4 weeks old.** A late-October launch lands at week 7–8, and each meta has been shorter than the last.
- **Odds the "for Eggs" title still pulls discovery traffic:** 45–60% in late October, 15–30% by December (G).
- **Most clones fail.** About 16 of 36 egg-wave titles on one search page sit under 1K CCU (S), and search under-counts the dead ones.
- **Winners are factories.** The Crazay groups shipped Pull (08-07), Wings (09-02), Strength (09-12) and Drill (09-16), one verb every 1–2 weeks. xFrozen x Dudes has two.
- **Mitigations:** ship by mid-October rather than late October. Make the noun (Eggs) and theme a config table, so a re-title to Presents or whatever is hot in December takes a day.

## 5. Top 3 concepts

| # | Title | Hook | Why |
|---|---|---|---|
| 1 | **+1 Cannon for Eggs** | "Upgrade your cannon, blast yourself further, land on rarer eggs." | Verb untaken. Launch was proven in the brainrot wave. A scripted arc is deterministic. The map is a flat strip of distance bands built from parts. Thumbnail: a character fired from a cannon at a giant egg. |
| 2 | **Dive for Eggs (+1 Oxygen)** | "Every breath = +1 oxygen; dive deeper for rarer eggs." | Mechanic proven at 97.9%. The map is stacked colour bands, and water can be generated in code with `Terrain:FillBlock`. Downsides: the exact title exists twice, and Swim For Eggs owns the underwater thumbnail. Use the soft fail from section 3. |
| 3 | **+1 Jetpack for Eggs** | "+1 fuel per second; fly higher to sky nests." | Same structure as the 97.9% Wings game. Vertical part islands are the easiest map to generate. Weakest differentiation. |

Wildcard: +1 Magnet for Eggs is the cheapest to build but unproven.

## Sources
- Roblox search API (live CCU and votes): https://apis.roblox.com/search-api/omni-search?searchQuery=for%20eggs&sessionId=2&pageType=all
- Roblox games API (created dates, visits): https://games.roblox.com/v1/games?universeIds=10563114921,10764897725,10766138478,10371406677,10766721625,10763764817,10649255304,10472449476,10766723413,9557124946
- Game passes: https://apis.roblox.com/game-passes/v1/universes/10764897725/game-passes?passView=Full&pageSize=100 (also universes 10766138478 and 10563114921)
- Guides: https://allthings.how/?p=217553 (Wings), https://allthings.how/?p=207552 (Race), https://allthings.how/?p=169154 (Pull), https://allthings.how/?p=226724 (Wings incubation skip), https://roonby.com/2026/08/19/how-to-steal-eggs-in-steal-an-egg-roblox-guide-tips-tricks/, https://bloxodes.com/articles/steal-an-egg-speed-guide
- Stats: https://rowatcher.com/games/10563114921/steal-an-egg, https://earnaldo.com/blog/steal-an-egg, https://www.rolimons.com/game/109203247742910
- History: https://en.wikipedia.org/wiki/Grow_a_Garden, https://en.wikipedia.org/wiki/Steal_a_Brainrot, https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals

---

## RESEARCH: money

# Monetization math: 100,000 Robux in 90 days

**Bottom line:** target 100,000 Robux *cleared* in the account by Dec 31, which means about 142,900 Robux of player spend by about Dec 24. At base-case benchmarks that is roughly 1,060 average DAU over 60 live days, or about 95,000 visits. The benchmark inputs are weak (old forum anecdotes and survivor-biased reports), so treat the funnel as a range, not a forecast.

Labels: **S** = sourced, **B** = benchmark-estimate, **G** = guess.

## 1. What Roblox pays

| Stream | Developer receives | Hold before it lands | Label |
|---|---|---|---|
| Game passes | 70% of price paid | 3-7 days | S [1][2] |
| Developer products | 70% | 3-7 days | S [1][2] |
| Private servers | 70% | 3-7 days assumed | S [1] / G on hold |
| Creator Rewards: Daily Engagement (replaced Premium payouts, July 2025) | 5 Robux per Active Spender per day (10+ min, one of their first 3 games that day) | 60 days | S [3][4] |
| Creator Rewards: Audience Expansion | 35% of a new/returning user's first $100 of Robux purchases; needs 100 average DAU | 60 days | S [3] |

- **Target definition:** net Robux cleared (not pending) by 2026-12-31. Gross needed = 100,000 / 0.70 = **142,857 Robux**.
- **Creator Rewards count as zero.** With a 60-day hold, only rewards earned before Nov 1 would clear in time.
- **Sales cutoff is about Dec 24.** Christmas Day spending will not clear by Dec 31, so the Christmas event must be live by about Dec 12.
- **Hold risk:** one unconfirmed forum post (April 2026) claims the hold on earned Robux is now 30 days [5]. If true, the cutoff is Dec 1 and DAU needs rise about 1.6x. Make a small test purchase on launch day to measure the real hold.
- **Regional pricing** is on by default for passes (discounts up to 70% of list price), so realized price is below list. It is opt-in for developer products [6]. (S)
- **DevEx:** $0.0038 per Robux, so 100,000 Robux = **$380**; minimum cash-out is 30,000 earned Robux [7][8]. (S)

## 2. Benchmarks

| Metric | Low | Base | High | Basis |
|---|---|---|---|---|
| Daily payer conversion | 0.5% | 1.5% | 3.0% | B. Median is 3.8% for games with 1M+ MAU (survivor-biased) [9] |
| Gross Robux per payer per day | 80 | 150 | 200 | B. Median ARPPU $0.70, top 10% $2.33 [9]; Robux conversion is unclear |
| Net Robux per DAU | 0.28 | 1.58 | 4.20 | Computed: conversion x ARPPU x 0.7 |
| Net Robux per visit | 0.19 | 1.05 | 2.80 | Computed at 1.5 visits per DAU (median 1.56 sessions/day [9]) |

Cross-checks:
- DevForum anecdotes put typical games at 1-2 Robux per visit and simulators at 1-3, but the threads are old (search-result summary) [10]. (B)
- A third-party blog gives $0.003-0.006 per DAU for conservative games and $0.015-0.025 for well-monetized ones, roughly 0.9-7 Robux [11]. (B)
- Downside case: a DevForum thread title reports a game averaging 60-78 CCU earning only 25,000 Robux a year [12]. I did not open the thread.

## 3. Funnel to 100,000 net

| | Low | Base | High |
|---|---|---|---|
| Net Robux per DAU | 0.28 | 1.575 | 4.20 |
| DAU-days needed (100,000 / net) | 357,143 | 63,492 | 23,810 |
| **Average DAU over 60 days** | **5,952** | **1,058** | **397** |
| **Total visits (x1.5)** | **535,714** | **95,238** | **35,714** |
| Payer-days (DAU-days x conversion) | 1,786 | 952 | 714 |
| Average CCU (DAU / 96, assuming 15 min/day) (G) | 62 | 11 | 4 |

- The base case in plain terms: about 950 purchase-days averaging 150 Robux each.
- If launch slips, required DAU scales by 60 / live days.
- I did not research ad costs. At a guessed $0.03-0.10 per play, $150 buys 1,500-5,000 visits, about 2-5% of base-case visits. Nearly all traffic must be organic. (G)

## 4. Store design

Revenue shares are all guesses. The roughly 35/65 split between passes and products follows a DevForum anecdote that about two-thirds of one game's revenue came from developer products [10].

| Game pass (permanent) | Robux | Share |
|---|---|---|
| 2x stat gain (the "+1" becomes "+2") | 199 | 10% |
| Auto-collect / auto-train (AFK) | 249 | 8% |
| 2x coins | 149 | 6% |
| VIP (tag, +20%, daily chest with fixed contents) | 99 | 4% |
| Lucky eggs (2x luck) — a paid random item | 299 | 4% |
| +3 pet equips / storage | 149 | 3% |

| Developer product (repeatable) | Robux | Share |
|---|---|---|
| Starter pack, once per player: named guaranteed pet, coins, 15 min 2x | 49 | 10% |
| Coin packs S / M / L, sized as minutes of the player's own income | 49 / 199 / 799 | 20% |
| 2x boost, 15 min / 60 min | 29 / 79 | 10% |
| Skip stage / instant rebirth | 39-99 | 8% |
| Event-exclusive pet, guaranteed (Halloween, Christmas) | 299-399 | 10% |
| 2x offline earnings claim | 25 | 4% |
| Server-wide 2x for 15 min | 99 | 3% |

- **Expected best sellers:** permanent multipliers and auto-collect remove the core grind in an idle game. Coin packs and boosts are the repeat-spend engine.
- **Starter pack:** show it once after the first rebirth (about minute 5-10) with a real 24-hour timer. It must contain no random item.
- **Limited-time offers:** Halloween pet from launch to Nov 2; Christmas pet Dec 12-24. Both are direct, guaranteed purchases.
- **Private servers:** make them free. Revenue is negligible and friends playing together helps retention. (G)

## 5. Policy limits

- **Paid random items** cover anything random bought with Robux or with currency bought with Robux: egg hatching, spins, luck boosts, pity systems. A bundle containing one random item is restricted as a whole [13]. (S)
- **Odds disclosure:** show numeric odds for every outcome before purchase, summing to 100%, updating live when luck modifiers are active [13][14]. (S)
- **Region and age gate:** check `PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted`. It is currently true for Australia, Belgium, Netherlands, UK under-18s, and Brazil (under-18s from March 17, 2026; unverified adults from March 31) [13][15]. For those users, hide the feature or offer an earnable or fixed-order path [14]. (S)
- **Enforcement:** moderation notice, then game removal and account suspension [13]. (S)
- **Simplest safe design:** eggs cost earned-only currency, and Robux buys only deterministic items. Gate the luck pass and any coin-to-egg path behind the policy check.
- **No trading at launch.** It adds a second gate (`IsPaidItemTradingAllowed`) [14]. (S)
- **Cross-game sales** of passes and products were disabled May 29, 2026 (search-result summary), so sell only in your own experience [16]. (S)
- **Not verified:** Roblox's "Promoting Items to Younger Audiences" article returned a 403 [17]. Read it before building purchase prompts. Until then, use real timers, no fake scarcity, and no prompts fired by accidental touch. (G)

## Sources

1. https://devforum.roblox.com/t/unified-marketplace-fee-for-private-servers-paid-access-and-plugin-marketplace-sales/902229
2. https://devforum.roblox.com/t/incoming-adjustment-to-pending-sales-waiting-period/832724
3. https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628
4. https://devforum.roblox.com/t/how-does-daily-engagement-work-in-creator-rewards/3950669
5. https://devforum.roblox.com/t/robux-pending-for-over-4-weeks/4587819
6. https://devforum.roblox.com/t/enabling-regional-prices-for-all-passes-to-grow-your-global-audience/4471199
7. https://create.roblox.com/docs/production/monetization/developer-exchange
8. https://devforum.roblox.com/t/not-receiving-85-increase-on-devex/4172372
9. https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox
10. https://devforum.roblox.com/t/how-could-i-increase-robux-per-visit/1831270
11. https://rowatcher.com/news/devex-math-in-2026-what-you-actually-take-home-per-1-000-players
12. https://devforum.roblox.com/t/my-game-with-a-60-78-ccu-yearly-average-generates-25k-robux-a-year/3560194
13. https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622
14. https://create.roblox.com/docs/en-us/production/monetization/paid-random-items.md
15. https://devforum.roblox.com/t/will-arepaidrandomitemsrestricted-apply-to-brazil-too/4401452
16. https://devforum.roblox.com/t/disabling-cross-game-sales-of-passes-and-dev-products-and-introducing-the-transfers-api/4618396
17. https://en.help.roblox.com/hc/en-us/articles/47965190783892-Promoting-Items-to-Younger-Audiences

---

## RESEARCH: growth

# User-acquisition plan: $150, zero Robux, 2026-10-02 to 12-31

**Bottom line:** $150 buys roughly 1K–13K plays on its own, which will not reach 100K Robux. Its real job is to buy measurement data and get the game considered by the Home algorithm. Labels: **S** = sourced, **B** = benchmark-estimate, **G** = guess.

## 1. How paid promotion works

| Item | Fact | Label |
|---|---|---|
| Account | 13+ with verified email; personal or business ad account | S [1] |
| ID verification | Not required (2023 FAQ); 2FA and account age not mentioned in docs | S [2] |
| Paying in USD | Card only, 18+; $1 hold, and first campaign pre-charges $5 | S [1] |
| Under 18 | Must buy Robux and convert at 263–285 R$ per credit; $150 becomes about 42–57 credits | S [2] / G |
| Formats | One "sponsored" campaign serves both Home and Search; up to 10 thumbnails (16:9) | S [1][3] |
| Objectives | Plays, Engagement, Earnings (limited) | S [1] |
| Bidding | Auto-bid, second-price auction, charged per play | S [1][2] |
| Minimum spend | 10 credits (5/day for 2 days) as of 2023; current docs state none | S [2] |
| Targeting | Location, age, gender, genre, device; new/recent/lapsed players | S [3] |
| Timing | Moderation up to 24h; reports lag up to 48h; 3–5 days for meaningful results | S [3] |

**The under-18 fork matters most:** if Yaani cannot use a card, the budget is worth about a third as much.

Cost-per-play evidence is thin and inconsistent:
- **Developer reports (2024):** $0.0027–$0.0135 [5], $0.02 [4], and 5 credits for 1,600 visits (about $0.003) [6].
- **Agency figure (2026):** $0.45 average [7], which contradicts the same agency's guide quoting $0.01–$0.05 per visit.
- **Q4:** holiday competition probably pushes prices up (G).

| Plays bought (G, built from the points above) | Low ($0.15) | Base ($0.04) | High ($0.01) |
|---|---|---|---|
| $100 | 670 | 2,500 | 10,000 |
| $150 | 1,000 | 3,750 | 15,000 |

## 2. How the Home algorithm picks up a new game

- **Two stages:** retrieval picks candidates, then ranking personalises them (S [8]).
- **Top signals:** play-through rate from Home, first-play bounce (under 60s and 61–180s), play days per user (D1, D2–7, D8–28), and playtime per user capped at 60 min/day (S [8]).
- **Secondary signals:** co-play days, qualified plays, spend days and Robux spent per user (S [8]).
- **Ads do not feed ranking:** engagement of users first acquired from ads, search or social is not counted in ranking, though those signals "can accelerate your consideration" (S [8]).
- **So the paid burst does two things:** it gets the game considered, and it gives a clean retention read before the algorithm tests it organically. A content update then triggers "explore"; a good cohort triggers "expand" (S [8]).
- **No official thresholds exist.** Roblox says dashboard benchmarks are comparison only (S [8]).

| Metric | Median | Strong (90th pct) | Our go gate | Label |
|---|---|---|---|---|
| D1 retention | 4–11% | 18% | 10% or above | S [9] / gate G |
| D7 retention | 0.4–1.8% | 5–6% | 3% or above | S [9] / gate G |
| Avg playtime | — | 10–12 min "good", 7–8 min minimum | 8 min or above | S (forum anecdote) [6] |
| Under-60s bounce | — | — | 30% or below | G |
| Payer conversion | about 1.25% | — | 1% or above | B [10] |

Retention can be viewed by acquisition source in the dashboard, so the ad cohort is measurable separately (S [11]).

## 3. Free channels, ranked by plays per hour (all G)

| # | Channel | What to do | Effort | Expected plays |
|---|---|---|---|---|
| 1 | Title and keywords | Name in the live pattern ("+1 <Stat> for Eggs"); add an original twist, since Roblox penalises repetitive titles and images [8] | 1h once | Lifts every impression |
| 2 | Icon and thumbnails | Upload 5–10 thumbnails to thumbnail personalization, which auto-allocates to the winner [12]; swap the icon every 2 weeks and compare play-through rate | 3h, then 30 min per fortnight | +10–50% play-through |
| 3 | TikTok and Shorts | One 15–25s clip per day, same file on both: big-number moment, rare egg hatch, code in caption | 20 min/day | Median 0–50 per clip; about 1 in 20 reaches 1K–10K+ |
| 4 | In-game codes | New code with each update, posted in the game description and clips | Claude codes it; 5 min each | Helps D1/D7, not acquisition |
| 5 | Creator outreach | DM 10 small Roblox YouTubers (1K–50K subs) per week with an exclusive code | 1h/week | 0–2 videos total; 500–5K each if they land |
| 6 | Roblox group | Join-for-reward chest; shout on each update | 30 min once | Retention only |
| 7 | Discord | Skip until 100+ CCU | — | About 0 |

One developer reports about 90% of players from the algorithm and 10% from YouTube/TikTok (S [13]).

## 4. Dated spend plan

| Date | Spend | Purpose | Continue if | Otherwise |
|---|---|---|---|---|
| Oct 2 | $0 | Verify email, create ad account, confirm 18+ card path | — | Under 18: use the Robux route and scale everything below by about a third |
| Oct 20–22 | $15 | Soft-launch test, Plays objective, $5/day | Cost per play $0.05 or less, playtime 8 min+, D1 8%+, bounce 30% or less | Cost over $0.10: redo icon. Bounce over 40%: fix first 60 seconds. No more spend until fixed |
| Oct 23–29 | $0 | Fix week | — | — |
| Oct 30–Nov 1 | $25 | Halloween update retest | D1 10%+, payer conversion 0.5%+, cost per play flat or down | Repeat fix cycle; move the $50 to December |
| Nov 13–19 | $50 | Main push with a content update | Organic Home impressions rising week on week | Stop ads; put effort into retention and clips |
| Dec 18–24 | $35 | Christmas update | D7 3%+ and Robux per visit rising | Spend only $15 |
| Any time | $25 | Reserve: double the best-performing campaign, or commission an icon | — | Do not spend it before Nov 20 |

The first test should give roughly 375 plays at base cost, enough to read D1 to about ±3 points (B).

**Manual steps for Yaani:** create the ad account, add the card, submit four campaigns, upload thumbnails.

## 5. Honest play estimate (about $125 deployed plus reserve)

| Scenario | Paid only | With organic | Rough odds (G) |
|---|---|---|---|
| Low: algorithm never expands | 800 | 1.5K–3K | 60% |
| Base: modest Home and search trickle, one clip lands | 3,200 | 10K–40K | 30% |
| High: Home "expand" fires | 13,000 | 150K–1M+ | 5–10% |

At 1–2 Robux per visit (G), 100K Robux needs about 50K–100K visits. That is reachable only in the upper base case or the high case, and it depends on retention, not on ad spend.

## Sources
1. https://create.roblox.com/docs/production/promotion/ads-manager
2. https://devforum.roblox.com/t/sponsored-experiences-moving-to-ads-manager/2661756
3. https://create.roblox.com/docs/production/promotion/sponsoring-experiences
4. https://devforum.roblox.com/t/optimizing-my-games-cost-per-play-from-ads/3047197
5. https://devforum.roblox.com/t/sponsors-in-ad-manager-cost-more-if-you-make-them-cheaper/3086156
6. https://devforum.roblox.com/t/sponsorship-costs-and-long-term-ccu-stability/3121727
7. https://bloxg.com/statistics/roblox-advertising-benchmarks
8. https://create.roblox.com/docs/en-us/discovery
9. https://www.gameanalytics.com/cn/reports/2025-roblox-report
10. https://rolearn.dev/trend-reports/creator-economy-2025-report (figure seen in a search summary only; page not opened)
11. https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157
12. https://create.roblox.com/docs/production/publishing/thumbnails (search summary only; page not opened)
13. https://devforum.roblox.com/t/game-launch-advertising-cost/3667546

---

## RESEARCH: build

**Bottom line:** a soft launch on **Fri 2026-10-16** (range Oct 16–23, GUESS) is realistic. The largest risk is not code: new games are shown only to age-checked 16+ users until they pass a Roblox evaluation, so shipping early matters more than polish.

Labels: SOURCED = from a cited page; GUESS = my estimate. Sizes are elapsed time including one human playtest: S under 1 day, M 1–2 days, L 3–4 days (all GUESS).

## 1. Systems

| # | System | Size | Depends on | Phase |
|---|---|---|---|---|
| 1 | Data persistence (ProfileStore, schema versioning) | M | – | v1 |
| 2 | Net layer (remotes, type validation, rate limits; this is the anti-exploit layer) | S | – | v1 |
| 3 | Balance config (all curves in one module) | M | – | v1 |
| 4 | Stat training loop (+1 per tap, auto-train) | S | 1, 2, 3 | v1 |
| 5 | Zones and world generated from code | M | 3 | v1 |
| 6 | Eggs, hatching, rarity (server-side RNG) | M | 1, 3 | v1 |
| 7 | Pets (inventory, equip, multipliers, client-side visuals) | L | 6 | v1 |
| 8 | Rebirths | S | 4 | v1 |
| 9 | Offline earnings (capped, e.g. 8 h) | S | 1, 7 | v1 |
| 10 | Shop: passes, developer products, idempotent ProcessReceipt | M | 1, 2 | v1 |
| 11 | Odds popup and PolicyService fallback | S | 6, 10 | v1 (compliance) |
| 12 | Daily rewards | S | 1 | v1 |
| 13 | Codes | S | 1 | v1 |
| 14 | Tutorial (arrow and 5 steps) | M | 4–6 | v1 |
| 15 | Analytics (funnel and economy events) | S | all | v1 |
| 16 | Mobile UI kit (HUD, modals, number pops) | L | 2 | v1 |
| 17 | CLI publish (rojo build plus Open Cloud) | S | – | v1 |
| 18 | Leaderboards (OrderedDataStore) | S | 1 | week 3 |
| 19 | Seasonal egg and zone (config flag) | S each | 5, 6 | Oct 24, Dec 1 |
| 20 | Pet fusion / golden pets | M | 7 | post-launch |
| 21 | Trading | L | 7 | cut |

## 2. Architecture

- **Layout:** `src/server/Services/*`, `src/client/Controllers/*` and `src/client/UI/*`, `src/shared/{Config,Net,Types,Util}`, `vendor/ProfileStore.luau`, `default.project.json`. The project is fully managed by Rojo; nothing is authored in Studio.
- **Data:** ProfileStore, vendored as one file from GitHub. It gives session locking and a 300 s auto-save (SOURCED).
- **Packages:** skip Wally. The only Wally listing found for ProfileStore is a third-party re-upload (`2jammers/profilestore`).
- **Networking:** one hand-written `Net` module. The server owns all state and sends deltas; the client sends intents only (`Train`, `Hatch`, `Equip`). No Knit, no React.
- **Rokit tools to add (names from memory, verify):** `luau-lsp`, `selene`, `StyLua`, `lune` (offline economy simulation), optionally `rbxcloud`.
- **Studio's built-in MCP server:** Claude Code can run playtests, read the console and take screenshots (SOURCED). This removes most manual Studio work, but Studio must be open.
- **Open Cloud:** place publishing via API key is documented (SOURCED). Pass and product creation endpoints were reported only by a third-party listing; verify before relying on them.

## 3. Art at about $0

| Need | Approach | Risk |
|---|---|---|
| World | Code-generated parts, 5-colour palette per zone, Neon accents, Atmosphere/Bloom/ColorCorrection presets | Low |
| Pets and eggs | Primitive-built blocky pets, or Studio MCP mesh generation (SOURCED as a capability) | Quality varies |
| Free Creator Store assets | Meshes and images only; delete every script | Backdoors are a documented risk and moderation "is not guaranteed" to catch them (SOURCED) |
| IP | No brainrot, anime or branded characters | Takedown |
| UI | All in code: UICorner, UIStroke, UIGradient, one font | Low |
| Icon 512×512, thumbnail 1920×1080 (SOURCED) | Studio screenshot plus bold text; AI image optional at $0–10 (GUESS) | Must pass moderation |

**Minimum look (GUESS, I did not inspect the charted games):** ratings in this genre likely follow feel more than art. That means saturated colours, a tween and sound on every tap, large number pops, no data loss, smooth play on a phone, and no paywall in the first 5 minutes.

## 4. Human-only tasks (about 4–5 h total, GUESS)

| # | Task | Minutes | When |
|---|---|---|---|
| 1 | Install Studio and log in | 15 | Oct 2 |
| 2 | Age check, ID verification, 2-Step Verification (account must be at least 2 days old) | 20 | Oct 2 |
| 3 | Click Connect in the Rojo plugin (Claude runs `rojo plugin install`) | 5 | Oct 2 |
| 4 | Assistant → … → Manage MCP Servers → enable Studio as MCP server | 2 | Oct 2 |
| 5 | First publish; send Claude the universe and place IDs | 5 | Oct 3 |
| 6 | Game Settings → Security → enable Studio Access to API Services | 1 | Oct 3 |
| 7 | Create an Open Cloud key (`universe-places` write) and save it in a git-ignored `.env` | 10 | Oct 3 |
| 8 | Create passes and products in Creator Hub; paste IDs into `Config/Products.luau` | 30 | Oct 12 |
| 9 | Maturity questionnaire (declare paid random items) | 10 | Oct 14 |
| 10 | Buy 1,000 R$ and pay the Kids/Select publishing fee | 5 | Oct 14 |
| 11 | Upload icon and thumbnails | 10 | Oct 15 |
| 12 | Phone playtest, 20 min per milestone | 6 × 20 | each milestone |
| 13 | Set audience to public; watch the Audience Reach dashboard | 5 | Oct 16 |

## 5. Schedule

| Week | Dates | Deliverable |
|---|---|---|
| 1 | Oct 2–8 | Setup; systems 1–5 and HUD. Tap, number goes up, saves, runs on phone |
| 2 | Oct 9–15 | Systems 6–15; playtesters-only build Oct 13; store assets Oct 15 |
| 3 | Oct 16–22 | **Soft launch Oct 16**; leaderboards; fixes from funnel data |
| 4 | Oct 23–29 | Halloween egg and zone live Oct 24 |
| 5–6 | Oct 30–Nov 12 | Zones 3–4, fusion, balance; target is passing the evaluation |
| 7–9 | Nov 13–Dec 3 | Weekly content; Christmas event built by Nov 28 |
| 10–13 | Dec 4–31 | Christmas live Dec 1–26; limited products |

**Mobile constraints (all GUESS targets):**
- Touch targets at least 44 px, landscape, respect the notch safe area.
- Keep the thumbstick and jump zones clear.
- StreamingEnabled on, and under about 3k parts per zone.
- Pets rendered client-side, at most about 6 visible per player.
- No per-frame remotes; at most 10 per second per player.
- Numbers stored as doubles with suffix formatting.

## Top 8 risks

| # | Risk | Mitigation |
|---|---|---|
| 1 | **Audience gate.** New games reach only age-checked 16+ users until 250 unique plays by "highly engaged" users in 60 days (SOURCED). Kids/Select also needs a 1,000 R$ refundable fee or a subscription held 2 consecutive months (SOURCED). | Launch Oct 16; pay the fee (about $10–13, GUESS), since a subscription started now qualifies around Dec 2. Expedited review at 50k–100k R$ (sources conflict) is unaffordable. |
| 2 | Data loss or duplicated purchases | ProfileStore session lock; purchase IDs stored in the profile; grant before returning `PurchaseGranted` |
| 3 | Claude cannot see the game | Studio MCP playtest and screenshots; `luau-lsp` and `selene` on every change |
| 4 | Low-end phone lag | The budgets above; phone test at each milestone |
| 5 | Broken economy | Single config module; Lune simulation of the first 2 h and of day 7 |
| 6 | Exploits | Server authority; rate limits; never trust client-sent amounts |
| 7 | Paid random items violation | Odds shown as percentages summing to 100%; honour `ArePaidRandomItemsRestricted` (SOURCED) |
| 8 | Scope creep | Trading cut; one milestone per day; nothing added before Oct 16 |

**Unknowns:**
- Yaani's age: it decides facial estimation versus government ID.
- The exact "highly engaged" criteria: Roblox does not publish them.
- The reachable 16+ share: one secondary source says age-checked 18+ users are 27% of daily users.

## Sources
- https://create.roblox.com/docs/production/publishing/kids-and-select
- https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164
- https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717
- https://create.roblox.com/docs/studio/mcp
- https://github.com/Roblox/studio-rust-mcp-server
- https://devforum.roblox.com/t/profilestore/3190543
- https://create.roblox.com/docs/production/monetization/paid-random-items
- https://create.roblox.com/docs/cloud/guides/usage-place-publishing
- https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities
- https://create.roblox.com/docs/production/promotion/game-icons
- https://interspacemusic.com/blog/roblox-daily-active-users-fall-to-123-million-in-q2-2026/
