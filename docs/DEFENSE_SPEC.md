# Idle defence: technical spec (the contract between the pieces)

The game, **+1 Cannon Per Click** (`Config.GameName`), changed from a tap clicker in a fixed lane to a
third-person idle defence. `docs/IDLE_DEFENSE.md` is
the one-page design. This file is what the server core, the plot builder and the client must agree on. If you
need to deviate, say so in your report: other people are coding against this text at the same time.

## 1. The game

- Each player owns a **plot**. Monsters walk the plot's **path** from the **portal** to the **gate** of the base.
- Beside the path are 16 **pads**. A player buys pads with coins and builds a **tower** (a cannon) on each one.
  Towers fire by themselves. There is no tapping to fire and no big cannon.
- A **level** (the code and the save still call it `wave`) spawns a group of monsters. All dead: level cleared.
  Every monster that reaches the gate costs **lives**; at zero the level is failed, the player drops back one
  level and auto-advance switches off (as a failed wave does today).
- 50 levels per world, 12 worlds, bosses as today (every 5th level a giant, level 25 the mid boss, level 50 the
  world boss). Nothing resets when a new world opens. Rebirth exists as a rare prestige the player chooses
  after a world's final boss (section 8, "Build queue 0c").
- The player walks freely in third person, on the plot and in the marketplace. Mini cannons (pets) follow
  them; each deals its own flat damage per second to the lead monster of the base, wherever the player is
  (since 5 Oct: section 8, "Mini cannon DPS"; until then their bonus multiplied all tower damage).
- Everything else stays: eggs, fusing, Secrets, Huges, crates, loot viewer, trading, ammo, powerups, backpack,
  story, passes, marketplace.

## 2. Geometry: `src/shared/Layout.luau` (already written, do not change without saying so)

- `Layout.PLOT_COUNT = 12`, `PLOT_WIDTH = 110`, `PLOT_DEPTH = 150`, `PATH_WIDTH = 8`, `PAD_SIZE = 7`.
- Plot space: origin 14 studs behind the gate, +Z up the plot towards the portal, ground top at y = 0. The
  plots are private bases since 5 Oct: twelve of them standing alone, 2,000 studs apart, none turned (section
  8, "Private bases"). `Layout.plotCFrame(slot)`, `Layout.plotPoint(slot, Vector2(x, z), height?) -> Vector3`.
- `Layout.PATH` (10 points), `Layout.PATH_LENGTH` (359), `Layout.pathAt(distance) -> (Vector2 point, Vector2
  direction)` in plot space.
- `Layout.PADS` (16 `Vector2`s, the first is the free starter pad), `Layout.padPosition(slot, pad) -> Vector3`.
- `Layout.plotSpawn(slot) -> CFrame`: where the owner arrives.
- The marketplace stays where it is (`Layout.MARKET_CENTER`), reached by the existing `goMarket` / `goHome`
  actions (a teleport). The old lane functions in `Layout` (slotX, cameraCFrame, monsterPosition ...) are
  deleted, and so is `Arena.luau`.

## 3. Data: `src/shared/Config.luau` (owner: server core)

```lua
Config.Defense = {
	lives = 10,          -- per level
	bossLives = 10,      -- lives a boss costs when it reaches the gate
	tick = 0.1,          -- seconds per simulation step
	syncHz = 5,          -- field messages per second, per plot
	breakSeconds = 2,    -- pause between two levels
	petRange = 40,       -- studs around the player in which their mini cannons are drawn shooting and a Huge Shot is fired
	sellRefund = 0.5,    -- share of the coins put into a tower that selling gives back
	watchDistance = 260, -- a client is sent the field of plots whose origin is within this of their character
}

-- Towers. `Config.TowerOrder` lists the kinds in shop order.
Config.Towers[kind] = {
	name = "Cannon", desc = "...", color = Color3,
	cost = number,        -- to build at level 1
	damage = number,      -- per shot at level 1, before multipliers
	rate = number,        -- shots per second
	range = number,       -- studs, from the pad's centre
	unlock = number,      -- best-ever level cleared needed to build it
	-- optional specials
	splash = number?,     -- studs: the shot also hits everything this close to the target
	slow = number?, slowSeconds = number?,   -- 0.4 = the target walks 40% slower for that long
	burn = number?, burnSeconds = number?,   -- share of the shot's damage dealt again every second for that long
	chain = number?,      -- the shot jumps to this many more monsters
	boss = number?,       -- damage multiplier against single-monster (boss) levels
}
Config.towerDamage(kind, level) -> number
Config.towerUpgradeCost(kind, level) -> number   -- coins to go from `level` to `level + 1`
Config.towerInvested(kind, level) -> number      -- build cost plus every upgrade so far
Config.towerTier(level) -> number                -- 1 + (level - 1) // 10, capped at #Config.Cannons: its look and name
Config.padPrice(count) -> number                 -- coins for the player's `count`-th pad (the first is free)

-- A level. `monster` is Config.monsterFor(level) as today (name, shape, colours, kind, scale, key).
Config.levelPlan(level) -> {
	kind = "normal" | "boss" | "mid" | "final",
	count = number,      -- monsters in the level
	hp = number,         -- each
	coins = number,      -- each, before the player's coin multiplier
	speed = number,      -- studs per second
	gap = number,        -- seconds between two spawns
	regen = number,      -- share of max HP healed per second (0 in most worlds)
	monster = { ... },
}
```

`Config.Cannons` stays as the list of 60 tier styles (name and colour) that `Config.towerTier` indexes; its
`mult` and `cost` fields die with the big cannon. A mini cannon whose short name matches the tier name of one
of the player's towers gets `Config.SetBonus`, as it did for the big cannon.

## 4. Saved data: `src/server/Data.luau` (owner: server core)

New store name `PlayerData_v3` (old test saves are dropped). Changes to DEFAULTS:

- new: `pads = { 1 }` (indices of owned pads), `towers = { ["1"] = { kind = "cannon", level = 1 } }` (keyed by
  the pad index as a string; JSON has no number keys).
- kept: `coins, diamonds, candy, wave, cleared, bestCleared, autoAdvance, masteryKills, pets, items, features,
  receipts, extraSlots, boosts, daily, missions, weekly, event, totalKills, totalHatches`.
- kept for now as dead constants so feature modules written for the clicker do not hit nil, to be removed when
  the features are adapted: `power = 0, totalPower = 0, cannon = 1, autoRebirth = false, totalClicks = 0`.
- `rebirths` is live again (section 8). `cleared` is the highest level cleared in this run, `bestCleared` the
  highest ever: every unlock reads `bestCleared`. `masteryKills` counts kills for the Veteran level.
- `Data.fresh(key)` returns what a new save holds under that key (a rebirth uses it).

## 5. Server core: `src/server/Game.luau` (owner: server core)

Per player `state` gains: `lives`, `livesMax`, `phase` ("fight" or "break"), `monsters` (array, see below),
`spawned`, `plan` (the level plan), and `towers` (runtime: cooldown per pad). `state.slot` is the plot.

A monster: `{ id = number (unique per player session), d = distance along the path, hp, max, speed,
slowUntil, slow, burnUntil, burn, boss = boolean }`.

Each simulation step, per player: spawn what is due; move monsters (`d += speed * dt`, slowed ones slower);
burn; towers whose cooldown is up fire at the monster furthest along the path within `range` of their pad;
mini cannons fire at the monster furthest along, wherever the player is; monsters at the end of the path cost lives and are removed; dead ones pay out.

**Damage of one shot**

- Power multiplier (tower damage only): `Config.hugeMult(equipped) * Veteran * rebirths * boosts`, then the
  `perClick` modifiers. (`perClick` keeps its name so today's features keep working; `power` is accepted as
  an alias.) Published as `PowerMult`. Ordinary mini cannons are not in it.
- Tower shot: `Config.towerDamage(kind, level) * power multiplier` (x the tower's `boss` and the `bossDamage`
  modifiers on a boss level), then the `damage` modifiers, then the
  `shot` hook, which may change `shot.damage`: `shot = { manual = false, damage, source = "tower", kind, pad }`.
- Mini cannon shot: that mini cannon's own damage per second (`bonus * Config.PetDps`, the set bonus, the
  `petDps` modifiers) `/ its shots per second`, not times the power multiplier; same `bossDamage`, `damage`
  modifiers and hook, `source = "pet"`. `Game.shotDamage(player)` is the average mini cannon's damage of one
  second; `Game.shoot(player)` fires one such shot at the lead monster.
- `Game.damage(player, amount)` hits the lead monster (the one furthest along); what is left over after a kill
  carries into the next one, for at most `Config.MaxChainKills` kills.

**Plug-in API**: everything in `docs/ARCHITECTURE.md` keeps working with these meanings: hooks `ready, leave,
shot, kill (info = { wave, kind, reward }), waveCleared (wave, firstClear), hatch, tick (dt, twice a second)`;
`rebirth` fires after a rebirth. Modifiers `perClick`/`power`, `damage`, `coins`, `heal` (the level's regen
share), `autoShots` (mini cannon shots per second), `luck`, and since the build queue `towerRate`, `towerRange`,
`bossDamage`, `lives`, `monsterSpeed`, `upgradeCost`, `petShots`, `crateDrops`, `gems`: the table in
`docs/ARCHITECTURE.md` says what each is. `Game.perClick(player)` returns the power multiplier.
New hooks: `levelStart (wave)`, `levelFailed (wave)`, `leak (monster)`.

**Actions** (client `ctx.act(name, argument)`), all validated on the server:

| Action | Argument | Does |
|---|---|---|
| `buyPad` | pad index | Buys that pad for `Config.padPrice(#data.pads + 1)` |
| `buildTower` | `{ pad, kind }` | Builds on an owned, empty pad; needs `bestCleared >= unlock` and the coins |
| `upgradeTower` | `{ pad, levels }` | Buys up to `levels` upgrades (1, 10, or 1000 for "max"), as many as the coins allow |
| `sellTower` | pad index | Removes the tower and refunds `sellRefund` of what was put in. The last tower cannot be sold |
| `nextWave`, `prevWave`, `travel`, `toggleAuto`, `goMarket`, `goHome` | as today | Level selection and travel |
| `goIsland` | world index | To that world's island. Needs `Config.worldUnlocked(index, bestCleared)` and a registered `Game.places.island` (`Islands.luau`) |
| `rebirth` | `true` | The prestige (section 8). Anything but `true` is ignored: the window sends it on the confirming press |
| `setSpeed` | nothing, or 1 to 3 | The game speed: no argument steps 1x, 2x, 3x and back; a number picks one. The plot takes that many simulation steps per tick. 1x and 2x are free; 3x needs the `gameSpeed` pass: without it the pass is offered (a number changes nothing, the button steps back to 1x) |
| `offlineClaim` | nothing | Pays the offline earnings worked out at join, once (`Features/Offline.luau`) |
| `setPaused` | `true`, `false`, or nothing | Pauses or resumes the player's own plot (nothing switches). While paused the plot takes no simulation step; its field keeps being sent. Never saved |
| `visitInvite`, `visitJoin`, `visitKick` | the other player's user id | Invite a player to the asker's base; accept that owner's invitation and be moved there; send one of the asker's guests home (`Features/Visit.luau`) |

`buyCannon` and `toggleAutoRebirth` are removed. The `Click` remote is removed.

**Replication**

Player attributes (the owner's HUD reads them with `State.get`): `Slot, Place` ("plot", "market", "island" or
"visit"), `Island` (which island, 0 on none), `Visiting` (the slot of the base the player is a guest on, 0 on
none), `InMarket` (true whenever the player is not on their own base), `Paused`, `Coins, Diamonds,
Candy, Wave, Cleared, BestCleared, AutoAdvance, GameSpeed, Lives, LivesMax, Phase, MonstersLeft` (alive plus not yet
spawned), `LevelMonsters` (the level's count), `PowerMult`, `CannonPower` (sum over towers of damage x rate, x
the power multiplier x the `towerRate` modifiers, plus the mini cannons' damage per second; also sent as
`Dps`; its two halves are `TowerDps` and `PetDps`), `EquippedPets, VeteranLevel, VeteranInto,
VeteranNeed, Rebirths, HealRate, TowerRate, TowerRange, UpgradeCost` (the three multipliers the features put
on every tower and on upgrade prices), `WaveEndsAt = 0`. For `Hud.luau` as it stands, until it is replaced:
`PerClick = PowerMult`, `Power = CannonPower`, `Cannon = 1`, `MasteryLevel / MasteryInto / MasteryNeed` (the
Veteran numbers under their old names).

`Meta` (JSON) gains `pads = { 1, 4 }`, `towers = { ["1"] = { kind, level } }`, `padPrice` (the next pad's price).

The field: a remote named `Field` in `ReplicatedStorage.Remotes` (an `UnreliableRemoteEvent` when the class
exists, else a `RemoteEvent`; the client uses `OnClientEvent` either way). Fired `syncHz` times a second per
occupied plot, always to its owner, to every guest on it (`state.place == "visit"` with that slot) and to
anyone else whose character is within `watchDistance` of it (nobody, now that bases are 2,000 studs apart):

```lua
Field:FireClient(watcher, slot, level, lives, livesMax, flat)
-- flat = { id, d, hpShare, flags,  id, d, hpShare, flags,  ... }   one group of four per living monster
--   d        studs along the path (Layout.pathAt)
--   hpShare  0..1 of its max HP
--   flags    1 = slowed, 2 = burning, 4 = boss (added together)
-- A plot whose owner left: Field:FireClient(watcher, slot, 0, 0, 0, {}).
```

What a level's monsters look like is not sent: the client gets it from `Config.levelPlan(level).monster`.
Nor is a monster's max health: every monster of a level has `Config.levelPlan(level).hp` and nothing changes
one monster's max, so the client writes `hpShare x hp` on its bar. Whatever one day gives a monster a max of
its own must send it.
Tower shots are not sent either: the client plays them from the towers it sees (section 6) and the monsters in
range. A monster that vanishes from the list with `d` near `Layout.PATH_LENGTH` leaked; otherwise it died.

One-off messages on the existing `Feature` remote (`Game.send`): `("defense", "cleared", level, coins)`,
`("defense", "failed", level, coins)` (coins: what a boss that got through paid, else 0), `("defense", "leak",
lives)`, `("defense", "rebirth", rebirths)`.

## 6. The plots: `src/server/Plots.luau` (owner: plot builder)

```lua
Plots.build()                          -- all 12 bases and the lobby, once, at start
Plots.claim(slot, player)              -- name sign on the base
Plots.release(slot)                    -- owner left: towers gone, pads back to "for sale", sign cleared
Plots.setWorld(slot, worldIndex)       -- recolours ground, path and backdrop from Config.Worlds[worldIndex]
Plots.setPads(slot, owned)             -- owned: array of pad indices
Plots.setTower(slot, pad, kind, level) -- builds or replaces the tower model; kind = nil removes it
Plots.buildPets(slot, equipped, userId) -> Model   -- the mini cannon models, in `workspace.Cannons`
```

Instances, so the client can find things (all under `workspace.Plots`):

- `Plot_<slot>` (Folder, attribute `Slot`, attribute `Owner` = user id or 0)
  - `Pads/Pad_<i>` (Part; attributes `Pad`, `Slot`, `Owned`). Its `ProximityPrompt` carries `Pad` and `Slot`
    attributes too. The server ignores triggers by anyone but the owner; the client opens the TOWER window.
  - `Towers/Tower_<i>` (Model; attributes `Pad`, `Kind`, `Level`; `PrimaryPart` set; a part named `Muzzle`
    where shots leave; a model or part named `Turret` that the client may turn towards its target).
  - `Gate` (Part) at the end of the path, `Portal` (Part) at its start.
  - `Teleporters/WorldsPortal` and `Teleporters/MarketPortal` (Parts): the base's two teleporters. Each
    carries a `ProximityPrompt` with the attributes `Slot` and `Teleporter` ("worlds" or "market"); the
    server answers it for the base's owner only (`Plots.worldsPrompts[slot]`, `Plots.marketPrompts[slot]`).
- `Lobby` (Folder): a small closed room with the `SpawnLocation`, far from every base.
- The monster and tower builders live in `src/shared/Models.luau` so the client can build monsters too:
  `Models.monster(def, parent) -> Model` (built at the origin, `PrimaryPart` set, pivot on the ground under its
  centre, so the client moves it with `PivotTo`) and `Models.tower(kind, level, parent) -> Model`.
- Mini cannon models keep the attributes the client reads today (`Home`, `PetId`, `Perch`, `Follow` ...): on a
  plot they always follow their owner, as they do in the marketplace now.

## 7. The client (owner: client)

- Third-person camera and normal movement everywhere. No fixed camera, no control lock, no tap to fire.
- `src/client/Field.luau` (new, required from `init.client.luau`): listens to `Field`, keeps a pool of monster
  models per visible plot, moves them between messages, shows HP bars, slow and burn tints, death pops, coin
  and damage numbers, and plays each tower's shots (turn the `Turret`, fly a projectile from `Muzzle`) at its
  `rate` whenever a monster is within its `range`. `Field.lead(slot)` returns the lead monster's model.
- `src/client/Features/Towers.luau` (new): a pad's prompt opens the TOWER window for it. Not owned: BUY PAD
  with the price. Empty: the list of tower kinds (stats, cost, locked ones with what unlocks them). Built: its
  stats now and next level, UPGRADE x1 / x10 / MAX, SELL, and a range ring on the ground while it is open.
- `src/client/Features/Defense.luau` (new): the level HUD through `Hud.onLayout` and `ctx.UI`: world and level,
  lives, monsters left, previous / next / auto buttons, total DPS, and the cleared and failed banners.
- Make prompts with `Build.prompt` (server): they are `ProximityPromptStyle.Custom` and `src/client/Market.luau`
  draws them in the game's own style; a prompt made with `Instance.new` keeps Roblox's default look.
- `src/client/UI.luau` and `src/client/Hud.luau` belong to another session that is restyling them ("Candy
  Arcade", `docs/UI_VISION.md`), together with `src/client/Market.luau` and `src/server/Build.luau`. Do not edit them. Build new UI from the kit in `UI.luau`.

## 8. As built (where the merged code differs from the text above)

- **Config**: `levelPlan` also returns `leak` (lives one monster costs) and `variant` (`"swarm"`, `"tanks"` or
  nil). `Config.petDpsList(equipped, towerNames)` takes the set from `Config.towerNames(towers)` (it was
  `Config.petBonus` until 5 Oct). Extra helpers:
  `towerUpgrades`, `powerMult`, `levelCoins`, `TowerMaxLevel` (750), `Defense.chainRange`, an eighth tower
  kind `rocket`. `Config.Cannons` keeps `mult = 1` and `cost` until the old HUD and the Story tutorial stop
  reading them. Legacy shims (`monsterHP`, `monsterCoins`, `waveTime`, `rebirthWave`, `affordableCannon`,
  `MonstersPerWave`) stay until the clicker features are adapted.
- **Core**: the `Click` remote is gone. Each base's teleporters (`Plots.marketPrompts`, `Plots.worldsPrompts`)
  are wired in `Game.start`.
  Auto-advance carries on into the next world. Infinite or NaN damage is dropped. The leaderboards are Gems,
  Rebirths and Cannon Power (below).
  The owner is sent their plot's field always, also during breaks and in the marketplace: the client clears a
  plot it has heard nothing of for 1.5 s.
- **Plots and models**: `Turret` is a Model nested in the tower, `Muzzle` a part inside it. Towers carry a
  `Tier` attribute too; an upgrade inside a tier only changes `Level`, the model is not rebuilt.
  `Models.towerTier(level)` is `Config.towerTier`. Models are built facing -Z (the way `CFrame.lookAt` looks).
  Each plot also has `Scenery` and `Decor` folders and a `ForSale` model under each pad that is not owned;
  `workspace.Plots.Lobby` holds the `SpawnLocation` (the street is gone). `Plots.build` removes the default
  `Baseplate` and `SpawnLocation`.
- **Client**: `Field.lead(slot?, near?, range?)`; also `Field.count`, `Field.inspect`, `Field.stats` for tests.
  Coin numbers are matched to rises of the `Coins` attribute (kills' pay is not sent). SELL needs two presses.
  On the plot the pinned menu is STORE / MINI CANNONS / WORLDS (`init.client.luau` swaps `Hud.PINNED.market`).
  The Combat feature (Mega Blast, the Power Orb) was removed; `Game.damageAll` stays.

**Build queue 0c and 1 (docs/BUILD_QUEUE.md), as built in the core:**

- **Huge nerf.** `Config.HugePower = 3`; `Config.HugeShot = { seconds = 2, shots = 5 }`, fired only at the
  monster `Game.leadNear` returns (the lead one within `petRange` of the player, on their plot); the features'
  numbers are the queue's table. Hex lost its 20% slow: the table gives it the slower healing only.
- **Rebirth.** `Config.Rebirth = { damage = 0.05, gems = 100 }`, `Config.rebirthWave(rebirths)` (the final
  boss of world `rebirths + 1`; none after the twelfth), `Config.rebirthMult`. The `rebirth` action (argument
  `true`) needs `data.cleared >= Config.rebirthWave(data.rebirths)`, then resets `wave, cleared, coins, pads,
  towers` (and auto-advance) to a new save's and keeps everything else, `bestCleared` included: tower kinds,
  eggs and islands stay unlocked, and the gems of a first clear, a feature's first-clear gift and a "new tower"
  toast are given once ever (`waveCleared`'s `firstClear` is first ever). The WORLDS window has the REBIRTH row.
- **Leaderboards.** Gems (`data.diamonds`), Rebirths, Cannon Power (stored as `log10 x 1,000,000`, because an
  ordered store holds whole numbers up to 9e18). Ids `Gems`, `Rebirths`, `Power`; `Leaderboard.submit(player,
  data, { power })`. Three boards in the marketplace, three columns in TOP PLAYERS (each StringValue carries
  `Order` and `Title` attributes), and `leaderstats` Gems / Rebirths / Cannon Power (a StringValue, abbreviated).
- **Veteran.** The kill-based bonus, renamed from Cannon Mastery: `Config.veteranLevel`,
  `Config.VeteranBonusPerLevel`, attributes `VeteranLevel / VeteranInto / VeteranNeed`. The save key stays
  `masteryKills`.
- **Modifiers and the breakdown.** `Game.modify(kind, fn, label)`, `Game.value(player, kind)`,
  `Game.breakdown(player, kind)` (`docs/ARCHITECTURE.md`). In the simulation step: `towerRate` divides every
  tower's interval, `towerRange` multiplies its range, `monsterSpeed` multiplies every monster's step, `lives`
  sets the level's lives when it starts, `petShots` multiplies the mini cannons' rate.
- **Places.** `state.place`, `state.island`, `goIsland`, `Game.places.island` (section 5). `state.inMarket`
  is true in the marketplace only; the `InMarket` attribute is true on an island too.

**Build queue 2 (the islands), as built:**

- **Geometry.** `Layout.ISLAND_COUNT` (12), `ISLAND_RADIUS` (58), `ISLAND_SPACING` (420), `ISLAND_ORIGIN`
  (0, 0, 1200): two rows of six, more than 600 studs from the marketplace and more than 1,500 from every base.
  `Layout.islandCFrame(index)`, `Layout.islandSpawn(index)`.
- **`src/server/Islands.luau`** builds them (`Islands.build()`, called from `init.server.luau` after
  `Marketplace.build()`), registers `Game.places.island` and puts each portal's prompt in `Game.homePrompts`.
  Instances: `workspace.Islands.Island_<index>` (Folder, attribute `World`), about 100 parts, plus the two egg
  stands (12 parts each), which live under `workspace.Marketplace.Eggs` like every stand. `Islands.container`,
  `Islands.frame`, `Islands.spot(index, "mastery" | "enchant")` are in `docs/ARCHITECTURE.md`.
- **Marketplace.** `Marketplace.buildEggStand(egg, frame, parent)` is exposed; the hatchery skips the eggs
  that have a `world` (it keeps the Gem Egg and, during the event, the Halloween eggs; a lone egg stands in
  the middle of the arc).
- **Plots.** The islands teleporter: on the street when this was built, on every base since 5 Oct
  (`Plots.worldsPrompts[slot]`; the core opens WORLDS for the owner).
- **Client.** WORLDS rows have an ISLAND button (locked until `Config.worldUnlocked(index, BestCleared)`).
  `Effects.luau` uses the island's world's sky and turns the camera to the island's arrival. The "first egg"
  nudge is the "!" on the WORLDS button, and the tutorial's hatch step sends the player to Earth's island.
  The TRADE window lists and prompts by `Place == "market"`, not `InMarket`.
- **Island shop.** `Features/IslandShop.luau` x3; action `islandBuy { island, kind = "ammo" | "powerup" |
  "chest" }`, validated on the server (the player stands on that island, the world is unlocked, the row is in
  stock, the coins are there). Saved under `Game.feature(data, "islandShop")`; published as `Meta_islandShop`.
- **Play-test fixes.** `Config.Level.easeIn` (HP multipliers of levels 1 to 4): the starter cannon, never
  upgraded, clears up to level 4. A boss that gets through pays `Defense.failShare` (0.5) of its coins times the
  share of its health shot off. The tutorial asks for the first upgrade as its second step, before any level
  has to be cleared, and a failed level's toast says to upgrade when the coins are there. A tower kind that
  unlocks with no empty pad says "Buy a pad to build it on". A new player's first toast names the game.

**Build queue 3 and 6, and the loose ends (5 Oct), as built:**

- **Mastery** (`Features/Mastery.luau` x3): thirteen tracks, the `MasteryShrine` on the Mars island, the action
  `masteryBuy(trackId)`, `Meta_mastery`, `data.features.mastery`. Every track is one labelled modifier. The
  Offline track (added 5 Oct with offline earnings) raises the `offlineCap` modifier. Described in `docs/ARCHITECTURE.md`, numbers in `docs/BALANCE.md`.
- **Equip slots are a derived number**: the modifier kind `equipSlots` (the base, the weekly shop's slots and
  the slot passes are its core sources) and `Game.refreshPets(player)`. The Slots mastery track is on sale.
- **Game speed**: `data.speed`, `setSpeed`, `GameSpeed`; `Game.start`'s loop steps a plot `speed` times per
  tick. Brought over from the live tree. Since 6 Oct 2x is free and 3x is the `gameSpeed` pass: `GameSpeed` is 2 at most without it.
- **Offline earnings** (`Features/Offline.luau` x3, 5 Oct): `data.lastSeen`, `state.away`, the `offlineCap` and
  `offlineShare` modifiers, `Meta_offline`, the action `offlineClaim`. Described in `docs/ARCHITECTURE.md`.
- **The client follows the per-player tower multipliers**: `Field.luau` draws every tower's shots at
  `rate x TowerRate x GameSpeed` of the plot's owner and inside `range x TowerRange`; the TOWER window's rate,
  range, DPS and range ring use the player's own `TowerRate` and `TowerRange`, and its SELL price the upgrade
  discount, as the server does.
- **STATS** (`Features/Stats.luau`, server and client): the STATS menu button, `statsWatch`, `Meta_stats`
  (only while the window is open, at most once a second), `data.features.stats` (bosses, levels, seconds).
  The headline's chain is the towers' own damage per second, then every source of `power`, then every source
  of `towerRate`: exactly `CannonPower`. Described in `docs/ARCHITECTURE.md`.
- **The Huge badge on the HUD is hidden** (it sat on the level panel); Ammo's two modifiers are labelled.

**Build queue 4 and 5 (5 Oct), as built:**

- **Enchanted ids**: a mini cannon id may carry enchantments (`wooden_gold~greed1.sharp3`); `Config.Pets`
  resolves it. `plain` on every entry; `Config.equippedPets` and `Config.hugeMult` go by it for Huges.
- **Enchanting** (`Features/Enchant.luau` x3): the `EnchantingTable` on The Sun's island, the actions
  `enchant { pet, key, replace }` and `enchantBuyKey`, `Meta_enchant`, `data.features.enchant`, the items
  `enchantkey` and `shinykey`. Twenty enchantments (nineteen since Quick Draw went, below): labelled modifiers (one line per mini cannon in STATS), a
  `shot` hook and a `kill` hook.
- **Fusing** (`Features/Fuse.luau` x3): the `FusionMachine` on The Sun's island (gone from the marketplace),
  the action `fuse { id, id, id }`. `fusePet` and `fuseAll` are gone, and so are the FUSE buttons of the MINI
  CANNONS window, which lists each mini cannon's enchantments instead.
- **Core**: the modifier kind `petRange` (and the `PetRange` attribute, which `Effects.luau` follows),
  `shot.target`, `Game.pets.swap`, labels that are a list of parts, `Game.leadNear` without a range uses the
  mini cannons' own.
- **Island shop**: a fourth row, the Enchantment Key for gems, from The Sun's island on (`kind = "key"`).
- **Story**: the tutorial has eleven quests (no fusing); `Story.FuseTask` puts the fusing quests in chapters
  5, 7, 9 and 11.
- Described in `docs/ARCHITECTURE.md`; numbers in `docs/BALANCE.md`, section 5d.

**Private bases, visits and pause (5 Oct), as built:**

- **Geometry.** `Layout.plotCFrame(slot)` is `((column - 2.5) x PLOT_SPACING, 0, PLOT_ROWS[row])` with
  `PLOT_SPACING = 2000` and `PLOT_ROWS = { 4000, -4000 }`: six bases in each row, none turned. The nearest two
  bases are 1,884 studs apart edge to edge, the nearest other thing (the lobby) 1,704; `Layout.PLOT_APART`
  (1,500) is the floor the tools check. `STREET_HALF` is gone. New: `PLOT_YARD` (16: the ground behind the
  origin), `TELEPORTERS` (`worlds` at (-13, 3), `market` at (13, 3) in plot space), `LOBBY`, `FALL_HEIGHT`.
  `plotPoint`, `plotSpawn`, `padPosition` and `pathAt` are unchanged.
- **Plots.** No `Street`. Per base, new: `Yard`, 17 `Surround` hills (11 to 17 studs high, in the world's
  colours), 4 `Barrier`s (unseen, 140 high, `CanQuery` off), two lamps in the yard's corners, the
  `Teleporters` folder. The fence runs the whole length. 164 parts per empty base (it was 126), 20 in the lobby (the street had 130).
- **Core.** `state.place == "visit"` with `state.visit`; `Game.setPlace`, `Game.owner`, `Game.guests`; guests
  are sent home when the owner leaves; `setPaused`, `state.paused`, the `Paused` attribute; the safety net
  (`Layout.FALL_HEIGHT`); the field also goes to guests; the `window` channel.
- **Visit** (`Features/Visit.luau` x3) and the pause button are described in `docs/ARCHITECTURE.md`,
  "Private bases, visits and pause".

**Mini cannon DPS and health in numbers (5 Oct), as built:**

- **A mini cannon deals flat damage per second, not a percentage.** `bonus x Config.PetDps` (100) is its own
  DPS (`pet.dps`; bonus 1.29 = "+129 DPS"), with `Config.SetBonus` as before. It is dealt to the lead monster
  of the owner's base on every simulation step, wherever the player is (base, marketplace, island, visit; not
  while paused), with no range check, in shots of DPS / shots per second: fire rate changes the look, not the
  total. A shot still goes through `bossDamage`, the `damage` modifiers and the `shot` hook. The power
  multiplier no longer contains mini cannons and does not multiply their damage. Described in
  `docs/ARCHITECTURE.md`, "What a mini cannon is worth".
- **Config.** `Config.PetDps`, `Config.HugeDps`, `pet.dps`, `Config.petDps`, `Config.petDpsList`,
  `Config.hugeMult`; `Config.powerMult(equipped, veteranLevel, rebirths)` lost its `towerNames`;
  `Config.petBonus` and `Defense.petShotShare` are gone. `Config.RetiredEnchants`.
- **Core.** The modifier kind `petDps` and its breakdown (a line per mini cannon); `state.petOwn`,
  `state.petBase`, `state.petShots`, `state.petOwed` (a table now); `state.heroBase` is gone. Cannon Power =
  towers + mini cannons; attributes `TowerDps` and `PetDps`. `Game.shotDamage` is the average mini cannon's
  damage of one second.
- **A Huge** keeps x`Config.HugePower` on tower damage, its feature and its Huge Shot (unchanged: still fired
  only at a monster within `petRange` of the player on their base). Its own DPS: the strongest ordinary
  mini cannon's beside it, at least `Config.HugeDps`, x5 for the Huge Gatling's five shots.
- **Features.** Mastery Bond and the Bond enchantment are `petDps` modifiers (a Huge's Bond stays on `power`);
  Long Shot is +3 / 6 / 10% mini cannon DPS; Quick Draw is removed (nineteen enchantments; a saved id that
  carries it resolves without it). Offline earnings count the mini cannons' DPS. STATS lists every mini
  cannon as a line of its own under the towers' chain. `Format.petPower` writes "+129 DPS" everywhere.
  Mastery Rapid (+mini cannon shots) is still sold and is now cosmetic: a decision for the owner.
- **Health in numbers.** Monster bars carry their health as text (`Field.luau`), the level panel's boss line
  too (`Field.boss`). Nothing new is sent.
- **Balance.** Not retuned: `docs/BALANCE.md`, section 3b.

## 9. Order of work

1. In parallel, each in its own copy: the server core (sections 3 to 5), the plot builder (6), the client (7).
2. Merge, boot in the emulator, then in Studio.
3. Adapt the features written for the clicker: Huge, Ammo, Powerups, Combat, Story, Crates.
4. Balance pass with a simulator, offline earnings, text and pass names, phone check.
