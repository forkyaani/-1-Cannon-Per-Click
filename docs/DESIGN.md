# +1 Cannon Power Per Click — design

Hybrid simulator/clicker in the "+1 X Per Click" wave (reference: +1 Slash / Shield / Bite Per Click).
Grindy by design; paying should speed it up a lot. Every number lives in `src/shared/Config.luau`.

## Core loop

1. Tap anywhere → your cannon fires at the current monster.
2. Every shot gives **+Cannon Power**; damage per shot = your total Cannon Power.
3. Monsters come in **waves** of 5. Every 5th wave is one giant monster.
4. **Monsters heal** (3–7% of max HP per second) and every wave is **timed** (30–45 s).
   Run out of time → **wave failed**: you drop back a wave into farming mode and have to grind before retrying.
5. Defeated monsters pay **coins** (and candy during Halloween). Clearing a wave unlocks the next.
6. **Auto next wave** on = push forward. Off = **farm** the current wave. `<` `>` pick any unlocked wave.
7. Coins buy the next **cannon** and **eggs** that hatch **mini cannons** (pets).
8. Mini cannons **fire on their own**, so the game keeps playing while you are away from the keyboard.

## Two views

- **At your cannon** (default): fixed camera on your own lane, tap to fire, nobody walks. Clean and readable on a phone.
- **Marketplace**: the MARKETPLACE button teleports you to a walkable town square shared with everyone on the server.
  Free camera, normal movement, your mini cannons follow you, and they keep firing at your lane while you are away.
  BACK TO CANNON (button or the portal) returns you.

What lives in the marketplace:

| Thing | What it does |
|---|---|
| Egg hatchery | One stand per egg with its price and odds. Walk up and press E (or tap) to hatch. Eggs can only be hatched here |
| Weekly shop stall | Diamond shop |
| Halloween shop stall | Candy shop (only while the event is live) |
| Game passes stall | Robux store |
| Leaderboard boards | Top 10 rebirths and total power |
| Daily chest, missions board | Open the daily reward and missions windows |
| Trading plaza | Placeholder sign until trading is built |
| Giant golden cannon | Centrepiece |

## Worlds

Six worlds, 50 waves each (300 total). A new monster type every 10 waves; wave 25 is the mid boss, wave 50 the world boss.

| # | World | Monsters | Mid boss | World boss |
|---|---|---|---|---|
| 1 | Earth | Slime, Goblin, Rock Crab, Wisp, Troll | Ogre Chief | Earth Titan |
| 2 | Moon | Moon Rockling, Crater Crawler, Lunar Bat, Astro Ghost, Moon Golem | Dark Side Stalker | Moon Colossus |
| 3 | Mars | Martian Grunt, Sand Worm, Red Scorpion, Dust Devil, Rover Bot | Martian Warlord | Olympus Guardian |
| 4 | Neptune | Frost Imp, Snow Blob, Ice Wraith, Glacier Crab, Yeti | Blizzard Wraith | Frost Giant |
| 5 | The Sun | Magma Blob, Fire Imp, Lava Crab, Flare Spirit, Cinder Golem | Inferno Hound | Solar Titan |
| 6 | The Void | Shadow Wisp, Null Blob, Rift Stalker, Void Eye, Abyss Knight | Rift Warden | Void King |

- Beating a world boss unlocks the next world. The first time, auto-advance stops there: travel on, or rebirth.
  On later runs it carries straight on through worlds you have already been past.
- Each world has 5 cannons and 2 eggs of its own.

## Rebirth

- Rebirth N needs global wave 25 × N cleared: Earth 25, Earth 50, Moon 25, Moon 50, …
- Resets power, coins, cannon and wave progress. Keeps mini cannons, diamonds, mastery, slots.
- Gives +100% power and +10% coins forever, plus 20 diamonds.

Keeping the loop quick after a rebirth:

- **Overkill chaining:** damage left over from a kill carries into the next monster and on into the next waves,
  up to 50 kills per shot. It only chains while auto-advance is moving forward; when farming, one shot clears at
  most the rest of the current wave.
- **Cannon buy-max:** one press buys every tier you can afford.
- **Auto Rebirth pass:** rebirths the moment it is ready (HUD toggle).

## Fusing

3 mini cannons of the same kind and tier fuse into the next tier, at the Fusion Machine on The Sun's island (the
FUSE window; `docs/ARCHITECTURE.md`, "Fusing").
Each tier keeps the perks below it. Numbers live in `Config.FuseTiers`; the perks are placeholders until decided.

| Tier | Power | Perk |
|---|---|---|
| Silver | x3.5 | Overcharge: +25% of its own DPS |
| Gold | x12 | Coin Magnet: +25% coins per equipped Gold or better |
| Diamond | x40 | Heal Block: monsters heal 20% slower per equipped Diamond (never below 20% of normal) |

## Game passes

Defined in `Config.Passes`. Ids are 0 until the passes are created on Roblox; in Studio play tests every pass is owned.

| Pass | What it does |
|---|---|
| x3 Egg Opener | A second prompt on every egg stand hatches 3 at once |
| x3 Luck | Rare, Epic and Legendary mini cannons hatch 3x as often; stands show each player their real odds |
| +3 / +5 Mini Cannon Slots | Stack with each other and the weekly shop slot, up to 14 equipped |
| +500 Mini Cannon Storage | 50 -> 550 |
| Auto Rebirth | See Rebirth |

## Systems

| System | Status | Notes |
|---|---|---|
| Worlds, monsters, bosses | Built | Monsters are plain shapes for now |
| Healing + wave timer + fail | Built | |
| Cannons (30, five per world) | Built | x5 power per tier |
| Eggs (15) and mini cannons (83) | Built | 2 coin eggs per world, Gem Egg (diamonds), 2 Halloween eggs |
| Auto-fire (AFK) | Built | 1 shot per second per equipped mini cannon |
| Set bonus (hidden buff) | Built | "Mini Gold Cannon" + "Gold Cannon" → that mini gets x1.5 |
| Cannon Mastery | Built | Every kill counts, +10% power per level, never resets |
| Diamonds | Built | Daily rewards, missions, rebirths, first clears of every 25th wave |
| Daily rewards | Built | 7-day streak, exclusive mini cannon on day 7 |
| Daily missions | Built | 5 per day, reset 00:00 UTC |
| Weekly diamond shop | Built | Featured exclusive rotates every Thursday 00:00 UTC |
| Halloween event | Built | Candy drops, 2 eggs, candy shop, pumpkins. Ends 1 Nov 00:00 UTC automatically |
| Leaderboards | Built | Global top 10 for rebirths and total power, plus the in-server player list |
| Marketplace | Built | Walkable town square; see "Two views" |
| Saving | Built (basic) | Plain DataStore; needs session locking before trading |
| Game passes (6) | Built | See "Game passes". Cannot be sold until created on Roblox and their ids filled in |
| Fusing | Built | See "Fusing" |
| Overkill chaining, buy-max, auto rebirth | Built | See "Rebirth" |
| More Robux items | Next | 2x Power, 2x Coins, Auto-Fire, diamond packs |
| Trading | Next | Needs session-locked saves first, or mini cannons can be duplicated |
| Cannon skills / special cannon types | Later | Needs an equip screen |
| Offline earnings | Later | Roblox kicks idle players after 20 minutes, so true AFK needs this |
| Sound, hit effects, real monster models | Later | |

## Monetisation shape

- **Speed-ups** (the main sink): permanent 2x Power, 2x Coins, Auto-Fire, Auto-Rebirth, extra mini cannon slots.
- **Diamonds**: sold in packs; spent on the Gem Egg, the weekly shop and boosts.
- **Collection**: exclusive mini cannons from limited shops and events.
- Robux-priced random eggs must show their odds and respect `PolicyService` paid-random-item restrictions.

## Not tuned yet

With every pass, fused mini cannons and chaining together, a strong save clears all six worlds in about a minute.
The pieces work; the numbers do not hold yet.

Balance was set by formula, not by playing. Expect to adjust after real sessions:
HP growth (x1.35 per wave), coins (x1.2 per wave), cannon steps (x5), egg steps (x16), healing and timers.
