# Balance of the idle defence (retuned 6 October)

Every number is in `src/shared/Config.luau`. This file says what they are meant to do, what a simulated player
gets out of them, and how to change them. Nothing here has been played by a person at these numbers: it is a
simulator's result, and section 5 lists what the simulator does not know.

> **7 October, after this file was written.** Mini cannons grow 15x an egg from the third egg on (it was
> 2.5x: `Config.EggCurve.second` and `step`); every tower but the Sniper deals 1.75x to 3x more, and six new
> kinds are on sale (Laser, Venom, Blizzard, Railgun, Storm, Meteor: `Config.Towers`); `worldPay` and
> `headStart` were fitted again. `sim.py`, four seeds: worlds 1 to 8 take 23 to 38 minutes, worlds 9 to 12
> from 9 minutes to 1:26, none over 1:30, 6:35 to 8:03 in all. The sections below still give 6 October's
> numbers: the pace is the same, the shares of towers and mini cannons are not.

The 6 October retune, in one paragraph: towers deal 4x what they did (`Config.Towers`: the starter Cannon is
36 damage a second at level 1, it was 9), mini cannons 5.25x (`Config.PetDps` = 525, it was 100), monster
health grows 13.1% a level instead of 17.2% (`Config.Level.hpGrowth` = 1.131), and every world's coins were
fitted again (`Config.Level.worldPay`, and `headStart` for Earth's first 26 levels).

## 1. Targets and what the simulator measures

The pace is Yaani's (6 Oct) and replaces the first pass's 44 hours and "every world longer than the last":
**about 30 minutes a world, the last three or four worlds longer, no world over 1:30**, for the simulator's
ordinary player at 3x speed. A player without the 3x Speed pass plays at 2x (free since 6 Oct).

Measured on 6 Oct with `python3 tools/balance/sim.py --seed N`, N = 1 to 6, the Config.luau of that day.
Real time played, at 3x from level 10 on, 2 hours a day:

| World | Shortest | Average | Longest | Runs over 1:30 |
|---|---|---|---|---|
| 1 Earth | 30 min | 33 min | 35 min | none |
| 2 | 29 min | 32 min | 35 min | none |
| 3 | 25 min | 29 min | 33 min | none |
| 4 | 21 min | 26 min | 32 min | none |
| 5 | 22 min | 29 min | 35 min | none |
| 6 | 21 min | 31 min | 48 min | none |
| 7 | 25 min | 32 min | 41 min | none |
| 8 | 6 min | 26 min | 37 min | none |
| 9 | 5 min | 40 min | 1:52 | 1 of 6 (seed 3) |
| 10 | 6 min | 27 min | 1:17 | none |
| 11 | 46 min | 1:20 | 1:45 | 2 of 6 (seeds 5 and 6: 1:45, 1:44) |
| 12 | 31 min | 51 min | 1:16 | none |
| All twelve | 6:05 | 7:17 | 8:05 | |

| Target | Simulated |
|---|---|
| About 30 minutes a world | Worlds 1 to 8 average 26 to 33 minutes. Single runs are 21 to 48, but world 8 took 6 and 18 minutes in two of them |
| The last three or four worlds longer | Only on the average, and not in order: 40 min, 27 min, 1:20, 51 min. The 6 Oct fit aimed at 40, 50, 60 and 70; these six runs do not give that. World 10 averages less than Earth, and world 11 is the longest by far |
| No world over 1:30 | **Broken in 3 of 72 worlds**: world 9 once (1:52) and world 11 twice (1:45, 1:44). Three of the six players meet one such world. World 11's average (1:20) leaves ten minutes of room |
| The whole game | 6 to 8 hours of play, 4 or 5 days at 2 hours a day |
| The first ten levels | 2.2 to 2.3 minutes at 1x. The first pass aimed at 8 to 10; the head start and the 4x towers made them four times as quick, and nobody has set a new target |
| Bosses are walls | About one level in seven is failed at the first try over the whole game (2,924 of 20,246 runs), one in ten on Earth (127 of 1,249) |

**From world 8 on, how long a world takes is close to a coin toss.** World 9 took 5 minutes in three runs and
56 minutes to 1:52 in the other three; world 10 took 6 to 12 minutes in four runs and 52 minutes and 1:17 in
the other two. A short world is followed by a long one: seed 2 played worlds 9 and 10 in 5 and 6 minutes and
world 11 in 1:22; seeds 5 and 6 played them in 5 and about 11 minutes and world 11 in 1:45. A player who
arrives with towers ahead of a world's first levels runs through it, and pays in the next one. The averages
in the table hide that, and six seeds are too few to trust an average there to better than ten or twenty
minutes.

**At 2x the rule does not hold.** Two runs at `--speed 2` (seeds 1 and 2) took 14:05 and 14:30, against 8:04
and 6:05 at 3x: 1.7 to 2.4 times as long, not the one and a half that the speeds alone would give (boosts and
daily limits run on real time, so a slower fight gets less out of them). Earth took 1:10 and 1:17, and 5 of the
24 worlds were over 1:30 (1:50, 1:52, 2:16, 2:17, 2:39). The free player's game was not fitted; only the 3x
player's was.

The ordinary player: auto-advance on, spends coins as they come (next pad, a tower on every pad, then the
upgrade that adds the most damage for its price), drops back and farms after a failed level until their
towers are 15% stronger, puts a fifth of their coins into the newest egg until they have hatched 150 of it,
fuses everything once they reach The Sun's island, and uses what the game gives away: the daily reward,
missions, crates, powerups, boosts, the island shops, ammo, mastery with the gems they earn, one rebirth. No
passes and no Huge. 3x speed from level 10 on, 2 hours a day.

## 2. How the numbers are built

- **Monsters.** An ordinary monster of level L has `10 * L^0.5 * 1.131^(L-1)` HP (1.172 until 6 Oct). A level is 10 monsters;
  of every five levels the third is a swarm (20 at half HP, faster), the fourth a pack of tanks (5 at double
  HP, slower), the fifth a giant. Giants have 6x the HP of one monster, the mid boss 9x, the world boss 14x,
  and they walk at 60 to 70% speed. Half of an ordinary level may reach the gate; a boss that does fails it.
- **Coins.** Every world has an anchor: what an ordinary monster of its first level pays
  (`Config.Level.worldPay`). Inside the world a monster pays `anchor * (L / first)^-0.25 * 1.1455^(L - first)`.
  Earth's anchor is 0.453 and `headStart` multiplies its first 26 levels (33x at level 1, 1.11x at level 26),
  so they pay about what level 1 does and the curve takes over after them. A level pays the same in all
  whatever its variant; a giant pays 15 monsters' worth, the mid boss 25, the world boss 40. Bosses are the
  best farm, and a failed boss drops the player to the level before it.
- **Towers.** Damage x1.10 per level and x1.3 more every tenth level (a new tier, a new look); an upgrade
  costs 1.15x the one before. Together that is 12.9% damage for 15% coins, per level, against 13.1% more
  monster health. A tower's level ends up close to the level being fought (level 50: towers 26 to 35; level
  600: towers 565 to 610). The cap is 750.
- **Pads.** The n-th pad costs half a clear of the level it is meant for (levels 1, 4, 7, 11, 16, 23, 32, 43,
  60, 85, 115, 145, 190, 240, 290). All sixteen are owned by the Void, the sixth world.
- **Kinds.** Cannon (start), Gatling (level 3), Mortar (8, splash), Sniper (14, bosses), Frost (22, slow),
  Flame (55, burn), Tesla (105, chain), Rocket (160, splash and burn).
- **World twists.** Each world's twist changes HP, speed, healing or boss rules, and pays for it in coins.
  The healing worlds heal 1 to 1.5% a second: a monster heals all the way between two towers that are far
  apart, so more than that is a wall of its own.

## 3. Mini cannons

- A mini cannon deals damage of its own: its bonus x 525 (`Config.PetDps`) a second, to the lead monster of
  the owner's base, all the time and wherever the player is. It multiplies nothing, and no tower multiplier
  touches it. The first egg's Common is +26 DPS and its Legendary +420, beside 36 for the starter Cannon at
  level 1.
- Every coin egg's mini cannons are **2.5x** as strong as the last egg's (`Config.EggCurve.step`), two eggs a
  world: 6.25x a world. Monster health grows about 470x a world (13.1% a level, fifty levels) and the towers
  follow it, so a mini cannon matters most just after its egg unlocks and less with every level after it.
- An egg costs 2.5 clears of the level that unlocks it (the first: 500 coins). Eggs took 5 to 23% of the
  coins the six players spent.
- **What they are worth** (two runs each, seeds 1 and 2):

  | Player | All twelve worlds | Longest world |
  |---|---|---|
  | Never hatches (`--no-eggs`) | 14:01 and 12:01 | 2:17 and 2:20 |
  | 45 hatches of each egg (`--egg-limit 45`) | 8:22 and 8:09 | 1:34 and 1:32 |
  | 150 hatches (the ordinary player) | 8:04 and 6:05 | 1:23 and 1:22 |
  | 600 hatches (`--egg-limit 600`) | 7:37 and 9:23 | 2:09 and 1:21 |

  A player who never hatches finishes the game, in about twice the time. Hatching more than a few dozen of
  each egg changes nothing that two runs can show: the difference between 45, 150 and 600 hatches is no
  bigger than the difference between two seeds of the same player. In the first pass hatching was the
  strongest thing a player could do; it is not any more.
- Standing near the fight no longer matters for a player without a Huge: `--presence 0` gives the same game
  to the minute (8:04 and 6:05). Only the Huge Shot needs the player near the monsters.
- A Huge multiplies tower damage by 3 and is by far the strongest mini cannon. Its own DPS line is small on
  purpose (the strongest ordinary one's beside it, at least 50). Not run here: the ordinary player owns none.
- The bonuses that were set by hand (gem egg, event eggs, Exclusives, crate prizes) sit on the same curve
  (`onCurve` in Config.luau): as many eggs up the game as they were before.
- Fusing (x3.5, x12, x40), Secrets (x25, x250 of the egg's Legendary) and Huges (x100) are unchanged, and
  fusing needs The Sun's island (section 5d).

## 3b. How mini cannons got here (5 and 6 Oct)

Until 5 Oct a mini cannon's bonus multiplied all tower damage. The owner's decision that day, knowingly "a
huge nerf", made it that mini cannon's own flat damage per second at bonus x 100, with nothing else retuned.
One run of the simulator then gave Earth 1:12, world 2 12:48, world 3 92 hours, and a player still in the
fifth world after 600 hours: the eggs' share of the growth was gone from the second world on. The 6 Oct retune
(the paragraph at the top of this file) is the answer to that, and sections 1, 3 and 4 are measured with it.

What still stands from that change: the Bond track and enchantment, Long Shot, the set bonus and Secrets all
scale flat DPS, so they are worth far less than their prices assumed, and nobody has repriced them. Mastery
Rapid and the Silver tier's Rapid Fire are cosmetic. A mini cannon's fused perks (Coin Magnet, Heal Block) and
enchantments are unchanged.

## 4. The knife's edge

The fight is exponential on both sides, so the pace is the small difference of two large growth rates: towers
buy 12.9% damage for 15% coins a level, monsters gain 13.1% health, and coins grow 14.55%.

| Change | Effect | Where from |
|---|---|---|
| `hpGrowth` 1.131 to 1.130 | About half as long | The 6 Oct fit, four seeds, before the anchors were fitted again (the note in Config.luau). Not run again here |
| `hpGrowth` 1.131 to 1.133 | A world of 3:51 | The same |
| `hpGrowth` 1.131 to 1.1365 | A game of 52 hours | The same |
| 2x speed instead of 3x | 14:05 and 14:30 instead of 8:04 and 6:05; worlds up to 2:39 | Section 1 |
| No eggs at all | 12 to 14 hours; worlds up to 2:20 | Section 3 |
| 45 or 600 hatches of each egg instead of 150 | Within the noise | Section 3 |
| Another seed, nothing else changed | 6:05 to 8:05; a late world 5 minutes or 1:52 | Section 1 |

So: **a thousandth on `hpGrowth` is a different game, and one player's luck is worth two hours of an
eight-hour game.** The anchors of `worldPay` were fitted to averages of six seeds, and from world 8 on the
average says little about any one player (section 1). The 1:30 rule is broken by single runs in worlds 9 and
11, and lowering world 11's anchor would not be enough on its own: what makes a late world long or short is
how far ahead of its first levels the player arrives, and the fit does not control that.

The first pass's rows are gone because they were measured with mini cannons as a multiplier: `coinGrowth`
1.1455 to 1.1445 made the game 40% longer then, and has not been measured since (Config.luau still quotes it).

**`fit.py` and `model.py` are behind.** `python3 tools/balance/sim.py --check` reports 1,238 differences
between the draft in `model.py` and Config.luau, and all the ones it lists are in what levels pay: the draft
still holds the old `worldPay` and a twelve-level `headStart`. `fit.py` and `tune.py` work on that draft, and
`fit.py` still aims at the first pass's pace (Earth 82 minutes, every world 1.175x the last). The 6 Oct fit
was not made with them: the anchors were found by bisection on `sim.py` with the real Config.luau, by a
script of that session that is not in the repository. Until `model.py` is brought up to Config.luau and
`fit.py` is given the new targets, use `sim.py` without `--draft`.

## 5. What the simulator does not know

- **It is one set of rules, not a child.** The simulated player buys the best thing the moment they can afford
  it, opens every crate, uses every powerup and boost, visits the island shops daily and spends gems where
  they save the most time. A 2x Power boost was running 41 to 51% of the time they played. A child will do
  less of all of it; expect every world to run slower than simulated, and nobody knows by how much.
- **Sizes that were never set for this game.** Ammo, powerups and the 2x boosts are in the simulation now, at
  the clicker's sizes (`docs/RELEASE_PLAN.md`, A4). They are part of the pace above, so resizing any of them
  moves it.
- **The free player at 2x.** Run twice (section 1), never fitted.
- **Payers.** Passes and Huges can be given to the simulated player (`--payer`, `--passes`, `--huge`); none
  was run for this file. A Huge is x3 tower damage.
- **Enchantments.** Not modelled: `--enchant` multiplies tower damage by a number of your choosing, 1 by
  default (section 5d).
- **Offline earnings.** Not modelled.
- **Time spent hatching, trading and in windows.** The towers and the mini cannons keep working meanwhile, so
  it is not lost, but the simulated player loses no time to it at all.
- **The first minutes.** 2.3 minutes for ten levels is a player who needs no tutorial. The emulator's idle
  player (section 5b) was measured before the retune.
- **Where the towers stand.** The starter cannon moved to the pad by the monsters' portal on 6 Oct. Whether
  the simulator's first pad is that one was not checked for this file.
- **An oddity in its own report.** In four of the six runs 42 to 54% of the coins spent went to the island
  shops, in the other two none. Not looked into.
- **Six seeds.** Enough for worlds 1 to 7, where runs agree to within half an hour. Not enough for worlds 8
  to 12.

## 5b. Changes after the first play test (4 Oct)

- **The first four levels are eased in** (`Config.Level.easeIn = { 1, 1, 0.75, 0.4 }`, HP multipliers): the free
  starter cannon, never upgraded, clears levels 1 to 4, so a new player who touches nothing is not stopped by
  the first swarm (level 3). The first giant (level 5) is the first wall; by then the tutorial has paid for an
  upgrade, a pad and a second cannon. Measured in the emulator: an idle new player clears 4 levels in 3 minutes
  and then farms level 4.
- **A boss that gets through pays for the damage it took**: `Defense.failShare` (0.5) of its coins, times the
  share of its health that was shot off. An attempt that nearly made it is worth a few ordinary levels; it is
  never worth the kill, and the player still drops back a level. The simulator pays it too.
- **Monsters walk faster** (`Config.Level.speed` 18, `Config.CrossSeconds`): set in the live tree during the
  play test. `tools/balance/model.py` follows it (`crossSeconds`), and section 1 was measured with it.

## 5c. Mastery (queue 3) and the game speed

Bought with gems at the Mars island's shrine; every number is in `src/shared/Features/Mastery.luau`. The gem
price of level n is `base x growth ^ (n - 1)`, rounded to 5.

| Group | Track | Per level | Levels | Gems in all |
|---|---|---|---|---|
| Tower | Attack | +10% damage (`power`) | 20 | 7,475 |
| Tower | Fire Rate | +5% | 10 | 4,190 |
| Tower | Range | +2.5% | 10 | 2,790 |
| Tower | Boss Damage | +5% | 10 | 3,490 |
| Mini cannon | Bond | +3% mini cannon DPS (since 5 Oct; it was their bonus as a tower multiplier) | 10 | 4,190 |
| Mini cannon | Rapid | +5% mini cannon shots | 10 | 2,790 |
| Mini cannon | Slots | +1 equip slot at levels 3, 6, 9 | 9 | 5,965 |
| Economy | Coins | +10% | 10 | 4,190 |
| Economy | Luck | +5% | 10 | 3,490 |
| Economy | Discount | upgrades 3% cheaper | 10 | 2,790 |
| Survival | Lives | +1 life | 5 | 2,375 |
| Survival | Slow | monsters 1.5% slower | 10 | 3,490 |
| Survival | Offline | +1 hour of offline earnings (8 hours to 12) | 4 | 2,780 |

Everything maxed is x3 damage from Attack and up to x1.3 from Bond, x1.5 fire rate, +25% range, x2 coins, three
more mini cannons: 47,225 gems, against roughly 100 a day for a free player. The simulated player buys mastery
with the gems they earn (in the 6 Oct runs about 1,500 gems in a whole game: Attack 6, and one to three levels
of seven other tracks), so section 1 includes it. Nobody has run a player with more gems than that.

**Game speed** (1x, 2x, 3x; `setSpeed`) runs the whole fight of a plot that many times as fast, in real time:
the times in section 1 are real time at 3x (1x for the first ten levels). Since 6 Oct 2x is free and 3x is the
99 Robux pass, so a player who pays nothing plays at 2x, and their game is not one and a half times as long
but about twice (section 1).

## 5d. Enchanting and fusing (queue 4 and 5)

Every number is in `src/shared/Features/Enchant.luau`. Only equipped mini cannons count; the same enchantment
on several adds up, with no cap of its own (the core's limits on fire rate, range and monster speed still hold).

| Enchantment | I | II | III | What |
|---|---|---|---|---|
| Sharp | 5% | 10% | 15% | tower damage |
| Rapid | 3% | 6% | 10% | tower fire rate |
| Reach | 3% | 6% | 10% | tower range |
| Giant Slayer | 10% | 20% | 30% | damage on boss levels |
| Splinter | 3% | 6% | 10% | of every shot, splashed on all other monsters |
| Frostbite | 5% | 10% | 15% | of shots chill their monster (30% slower for 2 s) |
| Ember | 5% | 10% | 15% | of shots set their monster alight (+50% of the shot over 3 s) |
| Chain | 5% | 10% | 15% | of shots jump to a second monster for 50% damage |
| Executioner | 1% | 2% | 3% | finishes monsters under that much health |
| Greed | 5% | 10% | 15% | coins |
| Treasure | 10% | 20% | 30% | crate drops from bosses |
| Gem Finder | 0.05 | 0.10 | 0.15 | gems more per boss, 30 a day at most |
| Lucky | 5% | 10% | 15% | egg luck |
| Sweet Tooth | 10% | 20% | 30% | candy from monsters (Halloween) |
| Bond | 10% | 20% | 30% | of that mini cannon's own DPS (a Huge: of its tower multiplier over x1) |
| Long Shot | 3% | 6% | 10% | DPS of all the player's mini cannons (it was their range until 5 Oct) |
| Guardian | 1 | 2 | 3 | lives per level |
| Tar | 2% | 4% | 6% | monsters walk slower (multiplied, not added) |
| Scholar | 10% | 20% | 30% | Veteran progress from every kill |

**A roll** costs one key and gems by rarity: Common 10, Uncommon 15, Rare 25, Epic 40, Legendary 60, Exclusive
80, Secret 120, Huge 150. **Enchantment Key**: 1 / 2 / 3 enchantments 50% / 35% / 15%, each at level I / II /
III 60% / 30% / 10%. **Shiny Enchantment Key**: always 3, two of them level III, the third I / II / III 40% /
35% / 25%. Every enchantment is as likely as any other (1 in 19 each for one slot, 5.26%), none twice on one
mini cannon. (Quick Draw, +mini cannon shots, was the twentieth until 5 Oct: it is gone, and a mini cannon
that still carries it ignores it.)

**Keys**: Enchantment Key 3% in the Daily Crate, 4% in the Boss Chest, 5% (two keys) in the Gem Crate, and 40
gems on the island shops from The Sun's on (3 a day in all). Shiny key 0.1% in the Daily Crate, 0.2% in the
Boss Chest, 1% in the Gem Crate, 8% in the Royal Crate, and a Robux product (149 R$, id 0: not on sale).
The Gem Crate now pays back 25 gems on average for 100 and the Royal Crate 156.

**Not simulated**: `tools/balance` does not model enchantments. Three equipped mini cannons hold nine
enchantments: nine Sharp III would be +135% tower damage, about six levels' worth of monster health, for
many Shiny keys and a lot of luck; a typical key gives one or two enchantments of level I.

**Fusing needs The Sun's island now, and that changes the pace.** Nobody fuses in the first four worlds any
more, and the simulator's player follows that (`FUSE_ISLAND` in `sim.py`). Its run on 5 Oct, same seed, same
Config: worlds 1 to 4 took 5 h 01 min instead of 50 min (world 2: 69 min instead of 25, world 4: 2 h 25 min
instead of 7 min), and the whole game 6 h 38 min instead of 2 h 41 min; from world 5 on the times are as
before. Fused mini cannons (x3.5, x12, x40) were most of the early power. The 6 Oct retune gave the first four
worlds that power back through tower damage and the coin anchors: they take 21 to 35 minutes each (section 1).

## 6. Changing it

```
python3 tools/balance/sim.py                 # the game in Config.luau, all twelve worlds (1 to 3 minutes)
python3 tools/balance/sim.py --seed 4        # another player: run six and read the "world" lines
python3 tools/balance/sim.py --worlds 1 --trace 40   # the first levels, run by run
python3 tools/balance/sim.py --egg-limit 45  # other players: --egg-share, --presence, --no-eggs, --speed 2
python3 tools/balance/sim.py --check         # Config.luau against the Python copy of its formulas
python3 tools/balance/tune.py 12 coinGrowth=1.145 kinds.boss.hp=7   # try numbers on the Python copy
python3 tools/balance/fit.py                 # the first pass's fit (1.175x a world): out of date, section 4
```

`tools/balance/model.py` is meant to hold the same formulas and numbers as Config.luau (`KNOBS`), so that a
change can be tried there with `tune.py`, copied into Config.luau and confirmed with `--check`. Since 6 Oct
its coins do not agree with Config.luau (section 4): bring it up to date first, or change Config.luau and run
`sim.py` on it directly, six seeds. The fight in `sim.py` is the server's simulation step (`Game.luau`,
`simulate`) copied line for line: change one, change the other.

The levers, from coarse to fine: `Config.Level.hpGrowth` and `coinGrowth` (the length of the whole game),
`worldPay` (one world's average), a world's `rules` (its character), `Config.WaveKinds` (how hard bosses are),
`Config.PetDps` and `Config.EggCurve` (how much mini cannons matter), `headStart`, the first tower's damage
and the unlock levels (the first minutes).
