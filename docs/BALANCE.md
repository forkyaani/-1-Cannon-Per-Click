# Balance of the idle defence (first pass)

Every number is in `src/shared/Config.luau`. This file says what they are meant to do, what a simulated player
gets out of them, and how to change them. Nothing here has been played by a person yet: it is a simulator's
result, and section 5 lists what the simulator does not know.

> **6 October retune, not yet written into the sections below.** Towers deal 4x and mini cannons 5.25x what
> they did (`Config.Towers`, `Config.PetDps` = 525), and monster health grows 13.65% a level instead of 17.2%
> (`Config.Level.hpGrowth`). `sim.py`, ordinary player, at 3x: Earth 8 min, the Moon 11 min, Mars 18 min,
> Neptune 58 min, The Sun 31 min, then 1:11, 1:17, 6:04, 3:24, 3:59, 16:10 and 17:53: 52 hours in all. The
> first three worlds are far shorter than section 1's targets and the times are uneven: `fit.py` has not been
> run on the new curve. The edge is sharp: 1.1355 is a 32 hour game, 1.1375 an 80 hour one. A player without
> the 3x Speed pass plays at 2x, so about one and a half times these.

## 1. Targets and what the simulator measures

| Target | Simulated (ordinary player, three seeds) |
|---|---|
| A new player clears 10 levels in 8 to 10 minutes | 9.1 min |
| Earth (50 levels) takes 60 to 90 minutes | 74 to 88 min |
| Every world takes longer than the one before | 1:14, 1:34, 1:51, 1:57, 2:23, 2:52, 3:31, 4:22, 4:38, 5:08, 6:48, 7:27 (seed 1). Target: 1.17x per world. One seed in three has one world shorter than the one before it |
| Boss levels are walls that need a few minutes of farming | About one level in six is failed at the first try (18 of 104 runs on Earth). Level 10 to 15 takes 9 minutes, 20 to 25 takes 10 |
| A long game | About 44 hours of play for all twelve worlds |

The ordinary player: auto-advance on, spends coins as they come (next pad, a tower on every pad, then the
upgrade that adds the most damage for its price), drops back and farms after a failed level until their
towers are 15% stronger, puts a fifth of their coins into the newest egg until they have hatched 150 of it,
fuses everything, and stands in the middle of the plot 70% of the time.

## 2. How the numbers are built

- **Monsters.** An ordinary monster of level L has `10 * L^0.5 * 1.1365^(L-1)` HP (1.172 until 6 Oct). A level is 10 monsters;
  of every five levels the third is a swarm (20 at half HP, faster), the fourth a pack of tanks (5 at double
  HP, slower), the fifth a giant. Giants have 6x the HP of one monster, the mid boss 9x, the world boss 14x,
  and they walk at 60 to 70% speed. Half of an ordinary level may reach the gate; a boss that does fails it.
- **Coins.** An ordinary monster pays `15 * L^-0.25 * 1.1455^(L-1)`, times the world's step
  (`Config.Level.worldCoins`). A level pays the same in all whatever its variant; a giant pays 15 monsters'
  worth, the mid boss 25, the world boss 40. Bosses are the best farm, and a failed boss drops the player to
  the level before it.
- **Towers.** Damage x1.10 per level and x1.3 more every tenth level (a new tier, a new look); an upgrade
  costs 1.15x the one before. Together that is 12.9% damage for 15% coins, per level. A tower's level ends up
  close to the level being fought (level 50: towers 25 to 45; level 600: towers about 605). The cap is 750.
- **Pads.** The n-th pad costs half a clear of the level it is meant for (levels 1, 4, 7, 11, 16, 23, 32, 43,
  60, 85, 115, 145, 190, 240, 290). All sixteen are owned by the Void, the sixth world.
- **Kinds.** Cannon (start), Gatling (level 3), Mortar (8, splash), Sniper (14, bosses), Frost (22, slow),
  Flame (55, burn), Tesla (105, chain), Rocket (160, splash and burn).
- **World twists.** Each world's twist changes HP, speed, healing or boss rules, and pays for it in coins.
  The healing worlds heal 1 to 1.5% a second: a monster heals all the way between two towers that are far
  apart, so more than that is a wall of its own.

## 3. Mini cannons: the decision

- Every coin egg's mini cannons are **2.5x** as strong as the last egg's (it was 16x in the clicker). Two eggs
  a world make 6.25x: about twelve of the fifty levels of monster HP a world adds. Towers carry the rest.
- An egg costs 2.5 clears of the level that unlocks it (the first: 500 coins).
- The bonuses add up and multiply all tower damage. Each equipped mini cannon also fires once a second (twice
  when fused) at the monster furthest along within 40 studs of the player, for half the player's average
  tower shot: with three of them, roughly a quarter of what the towers deal while monsters are near the
  player. It is a reason to stand near the fight, not a second army: a player who is never near the monsters
  needs 52 hours instead of 44.
- The bonuses that were set by hand (gem egg, event eggs, Exclusives, crate prizes) were moved to the same
  place on the new curve (`onCurve` in Config.luau): as many eggs up the game as they were before.
- Fusing (x3.5, x12, x40), Secrets (x25, x250 of the egg's Legendary) and Huges (x100) are unchanged.

## 3b. Mini cannons deal flat DPS (5 Oct): the pacing must be measured again

The owner's decision, knowingly "a huge nerf": a mini cannon's bonus is no longer a multiplier on all tower
damage. It is that mini cannon's own damage per second, bonus x 100 (`Config.PetDps`): the first egg's Common
is +5 DPS, its Legendary +80 DPS, against 9 DPS for the starter tower at level 1. **No number was retuned.**
Everything in sections 1, 3 and 4 that depends on mini cannons was measured with the multiplier and is out
of date:

- The 2.5x per egg (6.25x a world) was sized to carry about twelve of a world's fifty levels of monster
  health, as a multiplier on towers that grow with every upgrade. As flat DPS it is measured against the
  towers' own damage per second instead, which grows far faster than 6.25x a world (10% a tower level and
  x1.3 every tenth, `Config.TowerCurve`): the further the player is, the less a mini cannon adds. The
  targets of section 1 (74 to 88 minutes for Earth, about 44 hours for the game) will be longer, and "a
  player who never hatches is stuck in the second world" is no longer what decides it.
- What a mini cannon does now: it helps early in each world's first levels, it deals its DPS wherever the
  player is (marketplace, islands, offline earnings), and its fused perks (Coin Magnet, Heal Block) and
  enchantments are unchanged. The eggs' prices (2.5 clears) were set for the multiplier.
- A Huge still multiplies tower damage by 3 and is now by far the strongest mini cannon. Its own DPS line is
  small on purpose (the strongest ordinary one's beside it, at least 50).
- The Bond track and enchantment, Long Shot, the set bonus and Secrets (x25, x250) all scale flat DPS now:
  worth far less than their prices assumed. Mastery Rapid and the Silver tier's Rapid Fire are cosmetic.
- **One run of the simulator with the new rule** (`python3 tools/balance/sim.py`, seed 1, the ordinary player,
  every system on, nothing retuned): Earth 1:12 (it was 1:14), world 2 **12:48** (1:34), world 3 **92 hours**
  (1:51), world 4 **367 hours** (1:57), and the player is still in the fifth world after 600 hours, where the
  whole game took about 44. Earth is unchanged because +5 to +80 DPS is a lot beside a 9 DPS tower; from the
  second world on the eggs' share of the growth is simply gone. One seed, a simulated player: a direction, not a
  measurement. But as the numbers stand the game stops being playable in the second world.
- `tools/balance/sim.py` models the new rule (no mini cannon term in `power()`, a flat DPS on the lead
  monster everywhere). Run it for the new times before changing `Config.PetDps`, `EggCurve.step` or the egg
  prices. `python3 sim.py --check` reported 1,238 differences between the draft and `Config.luau` before this
  change and reports the same after it: the draft is behind the level curve, not the mini cannons.

## 4. The knife's edge

The fight is exponential on both sides, so the pace is the small difference of two large growth rates.

| Change | Effect on the whole game |
|---|---|
| `coinGrowth` 1.1455 to 1.1445 | About 40% longer |
| Anything that multiplies damage by 2 (a 2x Power boost that never ends, twice the mini cannons) | Roughly twice as fast: the towers can be 6 levels lower, and those cost half as much |
| 45 hatches of each egg instead of 150 | 115 hours instead of 44 |
| 600 hatches of each egg | 29 hours |
| No eggs at all | Earth in 4 hours, then stuck: the Moon takes 90 |

So: **the game is balanced for a player who hatches**, and hatching more is the strongest thing a player can
do. Eggs cost almost nothing next to towers (under 5% of the coins spent), because an egg's price stands
still while income grows 14.5% a level. The limit on hatching is the player's patience, not coins.

## 5. What the simulator does not know

- **The clicker's features.** Huge cannons, ammo, powerups and the 2x boosts are not in the simulation. The
  Huges were re-sized on 4 Oct (x3 damage, about 7 levels; the Tycoon's coins x2; `docs/BUILD_QUEUE.md`,
  section 1); ammo, powerups and the 2x boosts are still the clicker's sizes.
- **Rebirth.** +5% tower damage each, a handful in a whole game: about a third of a level each. Not simulated.
- **Real spending.** The simulated player buys the best thing the moment they can afford it. A child will
  not; expect the first ten levels and Earth to run slower than simulated.
- **Frost and selling.** The simulated player never builds a Frost tower (it only counts damage) and never
  sells a tower to make room for a better kind.
- **Time spent hatching, trading and in windows.** The towers keep earning meanwhile, so it is not lost, but
  the mini cannons do not fire.
- **Offline earnings, the story's rewards after the rework, gem purchases.**

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
  play test, after the table in section 1 was measured. The numbers in section 1 are from before it.

- **`tools/balance/model.py` follows it** (`crossSeconds`): `sim.py --check` agrees with Config.luau again.
  The pace table of section 1 has still not been measured again.

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
more mini cannons: 47,225 gems, against roughly 100 a day for a free player. **Not simulated**: `tools/balance`
does not model mastery, so the pace floor of queue 0c is unchecked with it switched on. Slow and Lives make
levels easier beyond what the damage numbers say.

**Game speed** (1x, 2x, 3x; `setSpeed`) runs the whole fight of a plot that many times as fast, in real time:
at 3x everything in section 1 takes a third as long. The simulator's times are for 1x. Since 6 Oct 2x is free
and 3x is the 99 Robux pass, so a player who pays nothing plays at 2x.

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
before. Fused mini cannons (x3.5, x12, x40) were most of the early power. The balance pass has to give the
first four worlds that power back another way (the egg curve, or tower damage), or the queue's "may only make
it longer" has just been used up.

## 6. Changing it

```
python3 tools/balance/sim.py                 # the game in Config.luau, all twelve worlds (under a minute)
python3 tools/balance/sim.py --worlds 1 --trace 40   # the first levels, run by run
python3 tools/balance/sim.py --egg-limit 45  # other players: --egg-share, --presence, --no-eggs, --seed
python3 tools/balance/sim.py --check         # Config.luau against the Python copy of its formulas
python3 tools/balance/tune.py 12 coinGrowth=1.145 kinds.boss.hp=7   # try numbers on the Python copy
python3 tools/balance/fit.py                 # set the world steps so each world takes 1.17x the last
```

`tools/balance/model.py` holds the same formulas as Config.luau (`KNOBS`). Try a change there with `tune.py`,
copy it into Config.luau, and run `--check`. The fight in `sim.py` is the server's simulation step
(`Game.luau`, `simulate`) copied line for line: change one, change the other.

The levers, from coarse to fine: `Config.Level.coinGrowth` (the length of the whole game), `worldCoins` (one
world), a world's `rules` (its character), `Config.WaveKinds` (how hard bosses are), `Config.EggCurve` (how
much mini cannons matter), the first tower's damage and the unlock levels (the first ten minutes).
