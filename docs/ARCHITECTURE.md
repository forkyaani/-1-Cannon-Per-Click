# Architecture: how to add a feature without editing the core

The core game lives in a few big files. A **feature** (ammo, trading, a quest line ...) lives in its own files and
plugs into the core through the hooks below, so several people can build features at the same time.

## Where files go (Rojo maps them into the game)

| Path | Becomes | Purpose |
|---|---|---|
| `src/shared/Features/<Name>.luau` | `ReplicatedStorage.Shared.Features.<Name>` | Data both sides need: item and content tables, formulas |
| `src/server/Features/<Name>.luau` | `ServerScriptService.Server.Features.<Name>` | Server logic. Returns `{ start = function(Game) end }` |
| `src/client/Features/<Name>.luau` | `...Client.Features.<Name>` | UI and effects. Returns `{ start = function(ctx) end }` |

Every module in the two `Features` folders is required and started automatically, in name order
(`init.server.luau`, `init.client.luau`). Server features start after the map is built and before any player joins.
Before either, the client runs `src/first/Loading.client.luau` from `ReplicatedFirst`: the loading screen (see "Private bases, visits and pause").
Require a shared feature module with `require(ReplicatedStorage.Shared.Features.<Name>)`
(on the client use `WaitForChild` on the way down).

The game is called **+1 Cannon Per Click** (`Config.GameName`: use it wherever the game names itself). It is an
idle defence: monsters walk a path on each player's plot and cannon towers on pads shoot them
(`docs/IDLE_DEFENSE.md`; the contract between the pieces is `docs/DEFENSE_SPEC.md`, the numbers are explained
in `docs/BALANCE.md`, what is built next in `docs/BUILD_QUEUE.md`).

Core files: `Config.luau` (numbers and content), `Game.luau` (all game logic: the simulation of every plot,
towers, levels, rewards), `Plots.luau` (the twelve private bases with their pads and teleporters, tower and mini cannon models), `Marketplace.luau`
(the town square), `Islands.luau` (the twelve world islands), `Data.luau` (saving), `Passes.luau`
(game pass ownership), and on the client `Hud.luau`, `Windows.luau`, `Field.luau`, `Effects.luau`, `Market.luau`, `Loot.luau`, `UI.luau`, `State.luau`.

## Rules

- The server decides everything. The client displays and asks.
- Each player has saved `data` (`Data.luau` DEFAULTS) and session `state` (not saved). Never trust client arguments:
  check types and ownership in every action.
- Keep hooks cheap: `kill` can run 50 times in one shot.
- Luau, tabs, typed signatures, short comments that say why.

## Server API (`Game`, passed to `start`)

### Actions: what the client can ask for

```lua
Game.actions.equipAmmo = function(player, data, state, argument) ... end
```

The client calls `ctx.act("equipAmmo", argument)`. Calls are rate-limited, and the player's state is synced afterwards.

### Modifiers: adjust a derived number

```lua
Game.modify("coins", function(player, data, state, value) return value * 1.5 end, "Lucky hat")
```

The third argument is the modifier's **label**: what the STATS window calls this source. A string, or a
`function(player, data, state)` that returns a string or `nil` (nil = not active right now; a timed source can
put its countdown in it: `"2x Luck (12:40 left)"`). It may be left out: the source is then listed as "Other".
A label function may also return a list of parts, `{ { label = "Mini Storm Cannon: Sharp III", weight = 0.15 },
... }`, when the one modifier stands for several sources (the same enchantment on three mini cannons): what
the modifier changed is shared out by weight and every part is listed as a source of its own.

| Kind | Value (what it starts as) |
|---|---|
| `perClick` or `power` | The multiplier on all the player's **tower** damage (every different Huge's x3 x Veteran level x rebirths x the 2x Power boost). The two names are one list; `perClick` is what the clicker called it. It does not touch the mini cannons' own damage |
| `petDps` | The mini cannons' damage per second, all together: each equipped one's own (`Config.petDpsList`) added up. A source of "more mini cannon damage" multiplies it (Bond, Long Shot). Counted in Cannon Power |
| `damage` | Damage of one shot, from a tower (its base damage x the power multiplier) or a mini cannon (its DPS / its shots per second), x `bossDamage` on a boss level |
| `bossDamage` | Multiplier on every tower and mini cannon shot on a boss level: a giant, a mid boss, a world boss (1) |
| `towerRate` | Multiplier on every tower's shots per second (1; kept between 0.1 and 10). Counted in Cannon Power |
| `towerRange` | Multiplier on every tower's range (1; kept between 0.25 and 4) |
| `coins` | Coin multiplier on every kill |
| `upgradeCost` | Multiplier on the price of tower upgrades (1; under 1 is a discount). Selling refunds at the discount too |
| `heal` | Share of max HP every monster of the level heals per second (0 in most worlds) |
| `monsterSpeed` | Multiplier on how fast monsters walk (1; kept between 0.2 and 3). It stacks with a Frost tower's slow |
| `lives` | The lives a level starts with (`Config.Defense.lives`). Read when a level starts; add to it |
| `autoShots` | Shots per second from the mini cannons, all together. It only cuts their damage up: more shots are smaller shots, the damage per second is `petDps` |
| `petShots` | Multiplier on that (1). Like `autoShots` it changes how the damage looks, never how much: nothing in the game uses it since 7 Oct (the Mastery track that did is Mini Crit now) |
| `towerCrit` | Chance that a tower's shot is a crit: double damage, `Config.CritDamage` (0; kept between 0 and 1). The core rolls it in `shoot` and sets `shot.crit` for the `shot` hook |
| `petCrit` | Chance that a mini cannon's shot is a crit (0; kept between 0 and 1) |
| `petCritDamage` | What a mini cannon's crit multiplies its damage by (`Config.CritDamage`, 2; kept between 1 and 10). Crits are counted in Cannon Power, STATS and offline earnings as what they add on average, x (1 + chance x (multiplier - 1)): `Game.critMean(player)` gives the towers' and the mini cannons' |
| `petRange` | Multiplier on how far from the player their mini cannons are drawn shooting and a Huge fires its Huge Shot (1; kept between 0.25 and 4; the distance is `Config.Defense.petRange`). The client reads it as the `PetRange` attribute. The mini cannons' damage needs no range, and nothing in the game changes this number today |
| `luck` | Luck multiplier when hatching (1 = normal) |
| `crateDrops` | Multiplier on crate drop chances (1). The core does not use it: the Crates feature reads `Game.value(player, "crateDrops")` |
| `gems` | Gems a defeated boss drops (0). The core pays whole gems and carries the fraction over. A source must cap itself |
| `equipSlots` | How many mini cannons can be equipped (`Config.MaxEquipped`, the weekly shop's slots, the slot passes; rounded, kept between 1 and 20). A feature whose slots just changed calls `Game.refreshPets(player)` |
| `offlineCap` | Hours away that offline earnings pay for (`Config.Offline.capHours`, 8; kept between 0 and 72). Read once, when the player joins |
| `offlineShare` | Share of what the towers would have earned away that is paid (`Config.Offline.share`, 0.5; kept between 0 and 1). Read once, when the player joins |

`Game.value(player, kind)` is the number the game applies right now (every kind but `damage`, which is per
shot). `Game.breakdown(player, kind)` says where it comes from, for the STATS window:

```lua
{ base = 1, total = 6.3, sources = {
	{ label = "Huge Storm Cannon", value = 3, mult = 3, add = 2 },    -- value: the number after this source
	{ label = "Veteran level 2", value = 3.6, mult = 1.2, add = 0.6 },
	{ label = "1 rebirth", value = 3.78, mult = 1.05, add = 0.18 },
	{ label = "2x Power (12:40 left)", value = 7.56, mult = 2, add = 3.78 },
	{ label = "Mastery: Attack IV", ... },                            -- then every modifier, one at a time
} }
```

Only sources that change the number right now are listed. The core's own sources (each equipped Huge, the
Veteran level, rebirths, boosts, the luck pass) are labelled too. `total` is exactly what the game applies.
`Game.breakdown(player, "petDps")` starts from 0 and lists every equipped mini cannon by name with the DPS it
adds (`"Mini Gold Cannon (set bonus x1.5)"`), then the modifiers.

### Hooks: be told when something happens

```lua
Game.on("kill", function(player, data, state, info) ... end)
```

| Event | Extra arguments | When |
|---|---|---|
| `ready` | | Player's data is loaded and their plot is set up |
| `leave` | | Player is leaving (data may be nil if it never loaded) |
| `shot` | `shot = { manual = false, damage, source, kind, pad, target }` | Before a shot lands. `source` is `"tower"` (then `kind` and `pad` say which) or `"pet"`. Change `shot.damage` to alter it. `shot.target` is the monster it is about to hit (the core's own table, as in `state.monsters`); `state.hp` and `state.maxHp` hold its health |
| `kill` | `info = { wave, kind, reward }` | A monster died. `kind` is the level's: normal, boss, mid or final |
| `waveCleared` | `wave, firstClear` | A level was cleared. `firstClear` is first ever: after a rebirth the levels are cleared again, and it is false |
| `levelStart` | `wave` | A level begins (also when the player picks another one) |
| `levelFailed` | `wave` | The lives ran out. The player is about to drop back one level. (A boss that got through has just paid `Config.Defense.failShare` of its coins, times the share of its health shot off) |
| `leak` | `monster` | A monster reached the gate (`state.lives` is already lower) |
| `hatch` | `egg, results` | Eggs hatched. `results` is a list of `{ pet, kept, chance }` (chance is the % it had) |
| `rebirth` | | The player rebirthed (`data.rebirths` is already one higher; levels, coins, pads and towers are a new save's) |
| `tick` | `dt` | Twice a second per player |
| `action` | `name` | Just before a client's action is handled, or a prompt of the core's (`name` is then `"prompt"`): the moment before anything is bought |
| `acted` | `name` | Just after it was handled: what it bought is paid for. The event feature looks at the balance at both, so candy earned right after a purchase is counted |

### Players, messages, state

| Call | Does |
|---|---|
| `Game.data(player)`, `Game.state(player)` | The player's saved data and session state (nil until ready) |
| `Game.feature(data, "name", defaults)` | This feature's own saved table (`data.features.name`) |
| `Game.notify(player, text, kind)` | Toast. kind: good, bad, info |
| `Game.announce(text, kind)` | Toast for everyone on the server |
| `Game.sync(player)` | Push the player's state to their client now |
| `Game.setMeta(player, key, table)` | Publish feature state to the client (`State.feature(key)` there) |
| `Game.send(player, channel, ...)` / `Game.sendAll` | One-off message to the client (`ctx.on(channel, fn)` there) |
| `Game.damage(player, amount)` | Extra damage (abilities, burns) to the lead monster, the one furthest along the path. What is left after a kill carries into the next, for at most `Config.MaxChainKills` kills. A number that is not finite is dropped. Like `damageAll`, `hurt` and `shoot` it does nothing while the player's plot is paused, and `leadNear` is nil then |
| `Game.damageAll(player, amount)` | The same amount to every living monster of the level, each on its own. Returns how many it hit |
| `Game.leadNear(player, range?)` | The living monster furthest along within `range` studs of the player's character (`Config.Defense.petRange` times the `petRange` modifiers when left out), or nil: what a Huge Shot is fired at and what the client draws the mini cannons shooting at. Nil while the player is away from their plot. (The mini cannons' own damage goes to the lead monster of the base, near or not) |
| `Game.hurt(player, monster, amount)` | Damage to that one monster (from `state.monsters` or `Game.leadNear`). Nothing carries over. Returns whether it was dealt |
| `Game.value(player, kind)`, `Game.breakdown(player, kind)` | A derived number as the game applies it, and where it comes from (see Modifiers) |
| `Game.setPlace(player, place, index?)` | Moves a player: `"plot"`, `"market"`, `"island"` (index = the island) or `"visit"` (index = the slot of the base to be a guest on). False, and nobody moves, when the place cannot be reached (no such island, nobody owns that base, it is the player's own). It may wait for the place to stream in. It checks no permission: the Visit feature asks for an invitation first |
| `Game.owner(slot)`, `Game.guests(slot)` | The player who owns that base right now (or nil), and the players who are guests on it |
| `Game.places.island = function(index) return CFrame end` | Registers where a player arrives on a world's island (`Islands.luau` does). Without one, `goIsland` answers "not open yet" |
| `Game.homePrompts` | A list of `ProximityPrompt`s that send whoever triggers them back to their plot. Add a portal's prompt before `Game.start` (the islands' portals are in it) |
| `Game.shoot(player)` | One extra mini cannon shot at the lead monster (as hard as `Game.shotDamage` before the modifiers), through the `damage` modifiers and the `shot` hook |
| `Game.perClick(player)` (also `Game.power`) | The multiplier on all the player's tower damage right now, with every `perClick` modifier (0 until ready). The client reads it as `PowerMult` |
| `Game.shotDamage(player)` | The damage of one mini cannon shot right now: what the player's average mini cannon deals in a second (`petDps` over how many are equipped; fire rate bonuses left out), through the `bossDamage` and `damage` modifiers. The `shot` hooks are not run (0 until ready, and with none equipped). A Huge Shot is worth five |
| `Game.speed(player)` | The game speed the player's plot runs at: what they picked, 2 at most without the 3x Speed pass |
| `Game.luck(player, data, state)` | The player's luck when hatching (pass times the `luck` modifiers). The client reads it as the `Luck` attribute |
| `Game.random` | A shared `Random` |

### Items (the backpack)

Stackable things a player owns: powerups, ammo, crates. Define them once, in a shared feature module:

```lua
local Items = require(ReplicatedStorage.Shared.Items)
Items.define("power2x", { name = "2x Power", desc = "...", category = "powerup", color = ..., usable = true, tradable = true })
```

| Call | Does |
|---|---|
| `Game.items.give(player, id, amount)` | Adds items |
| `Game.items.take(player, id, amount)` | Removes them if the player has enough; returns whether it did |
| `Game.items.count(data, id)` | How many |
| `Game.onUse(idOrCategory, function(player, data, state, def) return true end)` | What USE does. Return true to consume one |

The client reads counts from `State.feature("items")` (`{ [id] = count }`) and uses one with `ctx.act("useItem", id)`.

### Mini cannons and boosts

| Call | Does |
|---|---|
| `Game.pets.add(player, id, force)` | Adds a mini cannon (`force` keeps it even when storage is full) |
| `Game.pets.remove(player, id, amount)` | Removes them if owned; returns whether it did |
| `Game.pets.count(data, id)` | How many |
| `Game.pets.swap(player, give, get)` | Trades the mini cannons in the list `give` (the same id may be in it more than once) for the one mini cannon `get`, which takes the first one's place: a fusion, an enchantment. Nothing happens unless the player owns them all. The list never grows, so storage is never an issue. Returns whether it was done |
| `Game.refreshPets(player)` | Picks the equipped mini cannons again and rebuilds their models (after an `equipSlots` modifier changed what it gives) |
| `Game.boosts.add(player, id, seconds)` | Starts or extends a timed boost |
| `Game.boosts.active(data, id)`, `Game.boosts.remaining(data, id)` | Is it running, seconds left |

`state.equipped` is the list of equipped mini cannon ids. `Config.Pets[id]` describes each one.

**Enchanted ids.** The save keeps mini cannons as id strings, and an enchanted one is its id plus a suffix:
`wooden_gold~greed1.sharp3` (`~`, then up to three `<enchantment id><level 1 to 3>` joined by `.`, in
alphabetical order). `Config.Pets` resolves such an id on demand (a metatable): the entry reads through to the
plain mini cannon's (`tier`, `base`, `next`, `bonus`, `tradable`, `huge` ...) and adds `plain` (the id without
the suffix; every entry has it), `enchants = { { id, level } }`, `enchanted = true` and a `name` that starts
with "Enchanted". `base` is still the id it was fused from. Enchanted entries are not stored in the table, so
`for id, pet in Config.Pets` walks the plain ones only. So an id is still all there is to a mini cannon:
counts, storage, trading, the index (it goes by `base`) and the loot viewer work as before. What to know when
writing code that handles mini cannon ids:

- Two ids are the same mini cannon and tier when their `plain` is equal; never compare the ids for that.
  Anything keyed by a Huge's id (`Huge.Features`) is keyed by its `plain`.
- `Config.enchantedId(plainId, enchants)` writes an id; `Config.splitPetId(id)` and `Config.parseEnchants(suffix)`
  read one; `Config.petEnchants(id)` is its list; `Config.enchantText(id)` is "Greed I, Sharp III" (use it
  wherever a mini cannon is named: MINI CANNONS and the trade window do).
- Of two equally strong mini cannons `Config.equippedPets` equips the better enchanted one. One of each Huge
  counts, whatever its enchantments.
Other session state a feature may read: `state.slot` (the plot), `state.place` (`"plot"`, `"market"`,
`"island"` or `"visit"`), `state.island` (which island, 0 on none), `state.visit` (the slot of the base the
player is a guest on, 0 on none), `state.inMarket` (true in the marketplace only), `state.paused` (the pause
button: the plot does not step; never saved), `state.away`
(seconds since the save was last written before this session: how long the player was gone),
`state.plan` (the level:
`Config.levelPlan`), `state.lives`, `state.livesMax`, `state.phase` ("fight" or "break"), `state.monsters`
(`{ id, d, hp, max, speed, slowUntil, slow, burnUntil, burn, boss, x, z }`, read only: hurt one with
`Game.damage`), `state.towers[pad]` (`{ kind, level, def, base, cd }`). The saved towers are `data.towers`
(`["3"] = { kind, level }`) and `data.pads`.
Write a mini cannon's strength with `Format.petPower(pet)` ("+129 DPS", or "x3" for a Huge: add "tower
damage" after that one), never by hand: a Huge's `bonus` is infinite. `Format.dps(n)` writes a sum of them.

**What a mini cannon is worth (since 5 Oct).** Its `bonus` is no longer a multiplier on tower damage. It is
that mini cannon's own damage per second: `bonus x Config.PetDps` (100), kept on every entry as `dps`, so
bonus 1.29 reads and deals "+129 DPS". Eggs, rarities, fuse tiers, Secrets and the set bonus scale it exactly
as they scaled the bonus.

- **Flat.** Nothing that multiplies tower damage touches it: not the Veteran level, rebirths, 2x Power,
  Mastery Attack, Sharp, or a Huge's x3. Sources of "more mini cannon damage" are the `petDps` modifiers:
  Mastery Bond (+10% a level), the Bond enchantment (that one mini cannon's own DPS) and Long Shot (+3 / 6 /
  10% for all of them).
- **Everywhere.** The server deals it to the lead monster of the owner's base all the time: with the player
  on the base, in the marketplace, on an island, on a visit, and (as a number) while they are offline. Only a
  paused plot stops it. No range is asked for.
- **In shots.** Each mini cannon's shot is its DPS / its shots per second, so the `autoShots` / `petShots`
  modifiers (a Huge Gatling aside) change how it looks, never what it adds up to. Every shot rolls for a crit
  (`petCrit`, worth `petCritDamage`: Mastery Mini Crit and Crit Power), then goes through
  `bossDamage`, the `damage` modifiers and the `shot` hook (`source = "pet"`) like a tower's.
  A fused mini cannon's Silver perk, Overcharge, is +25% of its own DPS (`Config.FuseTiers`, `dpsBonus`;
  Gold and Diamond keep it). It was Rapid Fire until 7 Oct: twice the shots of half the size. The perk is in
  `dps` and in `strength` (what auto-equip, a full storage and the inventory lists rank by), not in `bonus`.
  What features
  did to `petDps` is shared out evenly over the mini cannons' shots. One mini cannon's damage comes in at most
  10 shots a second.
- **A Huge** still multiplies all tower damage by `Config.HugePower` (x3; `Config.hugeMult`), keeps its
  feature and its Huge Shot (five `Game.shotDamage`s every 2 s, still only at a monster within `petRange` of
  the player on their base). Its own DPS line is modest: as much as the strongest ordinary mini cannon
  equipped beside it, never under `Config.HugeDps` (50), times the shots a second its feature gives it (the
  Huge Gatling: x5). A second copy of the same Huge deals nothing.
- `Config.petDps(id, towerNames)` is one ordinary mini cannon's, `Config.petDpsList(equipped, towerNames)`
  every equipped one's and their sum. `state.petOwn` and `state.petBase` hold them.

### Rebirth, Veteran, Cannon Power

- **Rebirth** is a rare prestige (`Config.Rebirth`, action `rebirth` with the argument `true`): allowed once
  the final boss of world `rebirths + 1` is beaten in this run (`data.cleared >= Config.rebirthWave(data.rebirths)`).
  It puts `wave`, `cleared`, `coins`, `pads` and `towers` back to a new save's and keeps everything else: mini
  cannons, gems, candy, items, boosts, `data.features` (so mastery, enchants and the story), the Veteran kills
  and `bestCleared`, which every unlock reads. It pays `Config.Rebirth.gems` and adds `Config.Rebirth.damage`
  (+5%) to the power multiplier for good. The WORLDS window has the REBIRTH row; its button needs two presses.
- **Veteran** is the kill-based bonus that was called Cannon Mastery (`Config.veteranLevel`, +10% tower damage
  a level; the save key is still `masteryKills`). "Mastery" now means the gem-bought tracks of the Mars island.
- **Cannon Power** is the player's total damage per second: the towers' (every tower's damage x rate, x the
  power multiplier x `towerRate`) plus the mini cannons' (`petDps`). The client reads it as the `CannonPower`
  attribute, and its two halves as `TowerDps` and `PetDps`; it is the HUD's headline number.
- **Leaderboards**: Gems, Rebirths, Cannon Power (`Leaderboard.luau`; ids `Gems`, `Rebirths`, `Power`), on
  three boards in the marketplace, in the TOP PLAYERS window and as the player list's `leaderstats`.

- **Game speed**: 2x is free, 3x is a game pass (`Config.Passes.gameSpeed`, "3x Speed", 99 Robux). `data.speed`
  (1 to 3) is what the player picked, the action `setSpeed` (no argument steps 1x, 2x, 3x, 1x; a number picks
  one) changes it, and `Game.speed(player)` / the `GameSpeed` attribute is what the plot really runs at: the
  picked speed with the pass, 2 at most without it (a saved 3x is kept and comes back with the pass). Without
  the pass, asking for 3x opens the purchase prompt, or says "not on sale yet" while the pass's id is 0: a
  number then changes nothing, and the button (level HUD, `Features/Defense.luau`) steps back to 1x. The player's plot takes that many
  simulation steps per tick: monsters, towers, burns and the break between levels all run faster. It is not
  part of Cannon Power and does not count towards offline earnings.

### Mastery (`Features/Mastery.luau` x3)

Eighteen tracks bought level by level with gems at the shrine on the Mars island (`Mastery.ISLAND` = 3): a Model
`MasteryShrine` in the island's `mastery` spot, whose altar prompt opens the MASTERY window. Every number is in
`src/shared/Features/Mastery.luau` (`Mastery.Tracks`, `cost`, `apply`, `describe`; the table is in
`docs/BALANCE.md`, section 5c). The action is `masteryBuy(trackId)`: the player must have reached Mars
(`bestCleared`, so it stays open after a rebirth) and be standing on that island; the server works out the level
and the price. Saved as `data.features.mastery = { levels = { [trackId] = level }, spent, gemDay, gems }` and
published as `Meta_mastery` (`levels`, `spent`, `off`: tracks the core cannot apply, none today). Each track is
one labelled modifier ("Mastery: Attack IV"; a level past 39 is a plain number, "Mastery: Attack 45"), so it
shows in STATS.

- **What a level does** is the track's `how`: `more` (x (1 + per x level)), `less` (x (1 - per x level), with
  per x cap well under 1), `add` (+ per x level, a count), `points` (+ per x level, read as a percentage: a
  crit chance, the offline share) or `slots`.
- **Crits.** Tower Crit (`towerCrit`), Mini Crit (`petCrit`) and Crit Power (`petCritDamage`) use the core's
  crit kinds: the core rolls every shot and counts the average in Cannon Power. Mini Crit is the track that
  was Rapid: its id is still `rapid`, so the levels a player bought count. Crit Power has `needs = "rapid"`:
  it is not sold before Mini Crit has a level (`Mastery.missing`; the card reads NEEDS MINI CRIT).
- **Slots** adds to `equipSlots` (+1 at levels 3, 6, 9, 14 and 20, `Mastery.slots`) and calls
  `Game.refreshPets`, so a mini cannon is equipped into the new slot at once.
- **Gem Hunter** adds to `gems` (the gems a boss drops) and caps itself: `perDay` (3) gems a level per UTC day,
  counted in the save by a `kill` hook, the way the Gem Finder enchantment does. Past the limit the modifier
  gives nothing and STATS stops listing it.
- **Crate Finder** multiplies `crateDrops` (read by `Features/Crates.luau`; every pool keeps its own limit a day).
- **Lives** count from the next level started. **Offline** (hours, `offlineCap`) and **Night Shift** (the
  share that is paid, `offlineShare`) count from the next time the player is away.
- **Saves.** A track's `id` is the key of its saved level: never change or reuse one, and only raise a cap.
  `Mastery.level` reads any save as a whole level from 0 to the cap. The `ready` hook throws nothing away: a
  level of a track this build does not know, or above this build's cap, stays in the save untouched.
- **The window** draws one level bar per card ("Lv 12/50"), not a pip per level, in a list that scrolls.
- `off` only fills in on a core without a modifier of a track's kind; the window then reads COMING SOON.

### Offline earnings (`Features/Offline.luau` x3)

A player who comes back after more than a minute away is paid for what their towers would have earned,
on a full-screen welcome-back card with one CLAIM button. A calculation, not a simulation
(`src/shared/Features/Offline.luau`, `Offline.estimate`):

- **Time away**: `data.lastSeen` is stamped by `Data.save` and `Data.release` (every save, and on leave); the
  core reads it when the save loads and keeps the seconds since as `state.away` (0 for a new save or one that
  did not load). Under `Config.Offline.minSeconds` (60) pays nothing; the time paid for stops at the
  `offlineCap` modifier (hours; `Config.Offline.capHours` = 8).
- **The level farmed**: `bestCleared` (at least 1) when the towers can clear it, else the highest level below
  it they can (`Offline.farmLevel`). "Can clear" means every monster dies before it has walked the path:
  `hp / dps <= cross` and `count x hp / dps <= (count - 1) x gap + cross`, with `cross = Layout.PATH_LENGTH /
  (plan.speed x the monsterSpeed modifiers)` and `dps` = Cannon Power, the mini cannons' DPS included: they
  hit the base's lead monster wherever the player is, away from the game too (on a boss level x the
  `bossDamage` modifiers and each tower's own boss multiplier), less the level's healing.
- **The coins**: `one clear = max((count - 1) x gap + cross, count x hp / dps) + Config.Defense.breakSeconds`;
  `coins = floor(seconds / one clear x count x floor(plan.coins x the coins multiplier) x share)`, `share`
  being the `offlineShare` modifier (`Config.Offline.share` = 0.5). Coins only: no gems, candy, kills,
  Veteran or mission progress. Game speed is not in it. Per-shot effects (ammo, `shot` hooks, splash) and the
  Huge Shot are not counted, as in Cannon Power.
- **Paying**: the server works the amount out once, in its `ready` hook, with the towers and bonuses the
  player has at that moment, and keeps it in `data.features.offline = { coins, seconds, away, level, earned }`
  (`coins` waits for CLAIM; `earned` is the lifetime total). It is published as `Meta_offline` (those, plus
  `capHours` and `share`); the action `offlineClaim` (no argument) pays `coins` once and clears it. Earnings
  left unclaimed stay in the save and the next absence's are added to them.
- **Raising it**: `Game.modify("offlineCap", ...)` (hours) and `Game.modify("offlineShare", ...)`, labelled
  like any modifier: STATS lists them as OFFLINE HOURS and OFFLINE EARNINGS. The server module's
  `Feature.estimate(player, data, state, away)` is the whole sum, for anything that wants to wrap it.

### The first join (`Features/Tutorial.luau` x3)

What a new player sees before anything else: three welcome cards, then a walkthrough that teaches the game by
doing. The words, the steps and every reward are in `src/shared/Features/Tutorial.luau`; the fan bonus's
numbers are `Config.Fan`.

- **The welcome**, once per save, on a full-screen card (the look of the welcome-back card, drawn over it):
  the game in three lines; the group ("Join our Roblox group for a fan bonus": +250 gems and +10% coins for
  good); a like and a favourite. NEXT turns the page (a page ignores presses for its first 0.6 s). The last
  card has START TUTORIAL and a small "Skip tutorial" link that takes two presses. The action is
  `tutorialWelcome("start" | "skip")`.
- **The plot waits behind the cards.** A save that has not been welcomed is paused when it joins (the server
  feature calls the core's own `setPaused`, see "Pause"), so nothing spawns or walks until START or the skip
  link, which resume it. Only that one pause is the tutorial's: it is made once, when the cards come up, and
  the HUD's PAUSED banner can still resume the plot, so a client that failed to draw the cards is never
  stuck. The pause is session state: a welcomed save always joins running, and somebody who left in the
  middle of the welcome is paused next time only because the cards are up again.
- **The fan bonus is for the group only.** `Config.Fan = { groupId, groupName, gems, coins }`; `groupId = 0`
  means there is no group yet: the card says "coming soon", has no CHECK button and nothing can be claimed.
  With an id, the server asks `player:IsInGroup(groupId)` in a pcall on every join and when the player
  presses CHECK (`tutorialCheck`, at most once every 3 s; a CHECK press also asks `GroupService:GetGroupsAsync`,
  because `IsInGroup` keeps its first answer for the whole session). A member is paid once per save
  (`fanPaid`): the gems, and a labelled `coins` modifier, "Fan bonus", that STATS lists. **Nothing is paid
  for a like or a favourite and the card says so**: a game cannot see one, and Roblox does not allow rewarding
  ratings. Keep it that way: never put a reward, a countdown or the word "bonus" on that card.
- **The walkthrough**, eleven steps (`Tutorial.Steps`): walk to the cannon, open it, upgrade it, watch a level
  clear, buy a second pad, build on it, read what lives are (GOT IT), travel to Earth's island, hatch the first
  egg, come home, and a last card that says where STORY, STORE and STATS are (LET'S GO). The client shows a
  banner at the top middle (in a ScreenGui of its own, so it stays readable over the TOWER window) and a
  marker: a beam and a bouncing arrow over the place to walk to (client-side parts and a BillboardGui), or an
  arrow beside the menu button to press.
- **The server decides every step** from real state, on the `tick` hook (`CHECKS` in the server module): the
  character's distance to an owned pad, `data.towers`, `data.pads`, `data.totalHatches`, `state.place` and
  `state.island`, the `waveCleared` hook. A step that is done already is passed at once, and the saved step
  is where a rejoin carries on. Three things only the client sees are told with `tutorialAck(stepId)` and
  checked: "open" (the TOWER window is open: the player must stand within 20 studs of one of their own pads),
  and the two presses "lives" and "finish". Only the step the player is on can be acknowledged.
- **A level cannot stall it.** No step needs a level the player cannot clear, a failed level drops back one
  as always, and the `levelFailed` hook puts a line on the banner for 14 s that says what to do ("walk to a
  cannon and press UPGRADE", or that the cannons now farm the level before).
- **Rewards.** A step pays `{ coins, gems }` when it is done, sized so that the steps before a purchase have
  paid for it (upgrade 25, pad 75, cannon 50, egg 500 today; `buys` on a step is what it asks the player to
  spend, and `tests/tutorial.luau` checks the sums against `Config`). Chapter 1 of the story asks for six of
  the same things: those quests carry `tutorial = <step id>` and the step's own reward, and
  `Tutorial.take(save, id)` lets it be paid once, by whichever of the two notices first. A save whose story
  was past such a quest before this feature existed has it marked paid the first time it loads.
- **Saved** as `data.features.tutorial = { welcomed, step, fanPaid, paid = { [step id] = true }, seeded }`
  (`step` is a step's id, or `"done"`). **Published** as `Meta_tutorial`: `welcomed`, `step`, `fanPaid`,
  `paid`, `group` (false while `groupId` is 0), `member` (`"unknown"`, `"member"`, `"no"`, `"failed"`),
  `checking`, `hint`, `hintAt`, `hintSeconds`. The story's guide waits with his opening lines while
  `welcomed` is false.
- **Replaying it** (Studio only; the action does not exist on a live server), from the client command bar:

```lua
local a = game.ReplicatedStorage.Remotes.Action
a:FireServer("tutorialReset")          -- the cards and the walkthrough again; rewards stay paid
a:FireServer("tutorialReset", "all")   -- also forgets the paid rewards and the fan bonus (gems already given stay)
```

  To see the fan bonus paid in Studio, set `Config.Fan.groupId` to a group the test account is in.

### Enchanting (`Features/Enchant.luau` x3)

A table on The Sun's island (`Enchant.ISLAND` = `Config.EnchantIsland` = 5): a Model `EnchantingTable` on the
left half of the island's `enchant` spot, whose prompt opens the ENCHANT window. One use costs gems by the
mini cannon's rarity (`Enchant.Gems`) and one key, and rolls random enchantments onto one mini cannon. Every
number is in `src/shared/Features/Enchant.luau`: the nineteen enchantments (`Enchant.List`: three levels each),
the two keys and their odds (`Enchant.Keys`, `Enchant.roll`, `Enchant.odds`), the prices. The table is in
`docs/BALANCE.md`, section 5d.

- **Keys** are backpack items, tradable, not usable from the backpack: `enchantkey` (1 to 3 enchantments, each
  level I to III) and `shinykey` (always 3, at least two at level III). They come from crates (rows in
  `Features/Crates.luau`), the island shops from The Sun's on (`IslandShop.Key`, for gems) and, the Shiny one,
  the Robux product `Enchant.ShinyProduct` (`product = 0`: not on sale yet; action `enchantBuyKey`).
- **The action** is `enchant { pet = id, key = item id, replace = true? }`: the player must have reached The
  Sun (`bestCleared`), stand on its island, own the mini cannon, a key and the gems, and may buy paid random
  items (`PolicyService`, as for the crates). A mini cannon that is enchanted already is only rolled again with
  `replace = true`, which the window sends after its second press. The result is sent on the `enchant`
  channel (`{ from, pet, key, enchants }`). Saved as `data.features.enchant = { rolls, gemDay, gems }`;
  published as `Meta_enchant` (`rolls`, `restricted`).
- **The odds are shown** in the window (on the roll's own panel and on the ODDS AND LIST tab), from the same
  tables `Enchant.roll` rolls with. Roblox requires that: change the tables, never the texts.
- **What they do.** Only equipped mini cannons count, and the same enchantment on several adds up
  (`Enchant.totals`). The ones that change a number are one labelled modifier each, whose label is a list of
  parts, so STATS shows "Mini Storm Cannon: Sharp III" per mini cannon. Splinter, Frostbite, Ember, Chain and
  Executioner are a `shot` hook; Sweet Tooth and Scholar a `kill` hook; Gem Finder is the `gems` modifier with
  a limit of `Enchant.GemsPerDay` a day.
- **Changed with the flat mini cannon DPS (5 Oct).** Bond grows that mini cannon's own DPS (`petDps`; on a
  Huge the part of its tower multiplier over x1, as before: `power`). Long Shot, which raised the mini
  cannons' range, is "+3 / 6 / 10% DPS of all your mini cannons" (`petDps`). **Quick Draw is gone**: it only
  made mini cannons fire faster, which adds nothing now. It is in `Config.RetiredEnchants`: it cannot be
  rolled, and a saved id that still carries it (`wooden~quickdraw3.sharp1`) resolves as before with that
  enchantment dropped from `enchants` (nothing lists, counts or applies it; an id with nothing else left reads
  as a plain mini cannon). The id itself is not rewritten.

### Fusing (`Features/Fuse.luau` x3)

The Fusion Machine (a Model `FusionMachine`) stands on the right half of the same spot; its prompt opens the
FUSE window. Three mini cannons of the same kind and tier (`plain` equal) make one of the next tier
(`Config.FuseTiers`); Huges and top tier ones cannot be fused. The player picks the three; the result keeps
the enchantments of the first pick and the others' are lost (the window warns and takes a second press). FILL
picks three matching ones without enchantments. The rules are `Fuse.result`, `Fuse.lost` and `Fuse.fill` in
the shared module. The action is `fuse { id, id, id }` (a list of exactly three ids, in the order picked): the
player must have reached The Sun, stand on its island and own every pick. The answer comes on the `fuse`
channel (`{ pet }`). The MINI CANNONS window no longer fuses, and the story asks for no fusing before
chapter 5 (`Story.FuseTask`).

### Events and their leaderboard (`Features/Event.luau` x3)

An event is one entry of `Event.List` in `src/shared/Features/Event.luau`: `{ id, name, icon, color, currency
(the save field: "candy"), currencyName, startsAt, endsAt, rewards = { { from, to, kind = "pet", pet } |
{ from, to, kind = "gems", amount } } }`. Halloween (`halloween2026`, its end from `Config.Halloween.endsAt`)
is the first; Christmas is there as a comment. A new event is that entry, its currency in the save, and the
Huge its winners get (`defineHuge` in `Config.luau`, a feature in `Features/Huge.luau`). Never reuse an id.

- **Earned, not owned.** `data.features.event = { earned = { [event id] = n }, paid = { [event id] = rank } }`.
  Nothing reports candy to the feature: it watches the balance, and whatever it has grown by since the last
  look was earned (while the event is live). It looks twice a second and in the `action` hook, just before
  anything is bought, so spending never lowers the count and never hides what was earned before it. Code that
  takes an event's currency away outside an action or a core prompt calls `Event.settle(player)` first
  (`require(script.Parent.Event)` from a server feature). Candy a crate pays out counts as earned too.
- **The board.** One OrderedDataStore per event (`LB_Event_<id>_v1`), added to `Leaderboard.luau` as the board
  `Event_<id>`: submitted on every autosave and on leaving, like the others. It stands in the marketplace on
  the west wall north of the Gems board (built by the feature) and is the fourth column of TOP PLAYERS, with
  the time left, the prizes and the player's own earnings and rank under its heading; the event shop's heading
  shows the same. The rank comes from the board's own refresh (it reads the best 100 every 90 s), so it costs no
  request of its own; a player further down is "not in the top 100 yet". The board stays up for 14 days after
  the end (`Event.SHOW_SECONDS`).
- **The end.** Nothing is earned from `endsAt` on. For 4 minutes (`SUBMIT_GRACE`) the board still takes the
  scores of players who were online at the end (each server sends them at once, and again with the next
  autosave). After 5 minutes (`FREEZE_DELAY`) the ranking is frozen: every server looks for the record
  `EventWinners_v1[event id]`; the first one that finds none reads the best five from the board once and stores
  `{ frozen = true, at, list = { { userId, score } } }` with `UpdateAsync`, which keeps whatever was stored
  first. A board or a store that cannot be read freezes nothing: the next check (every 20 s) tries again.
- **The prizes** (Halloween: ranks 1 to 3 the Huge Spectre Cannon, rank 4 2,500 gems, rank 5 1,500 gems). A
  winner is paid when their save loads on a server that knows the ranking, or at once if they are online when
  it is frozen, and only if `paid[event id]` is not set: the save is locked to one server, so it happens once.
  The server announces it, and the client plays the Huge reveal (`Effects.hatch` with a gift) or, for gems, a
  full-screen card. A session whose save did not load is not paid; the prize waits.
- **Client state**: `State.feature("event") = { list = { [event id] = { earned, rank?, place?, final } },
  reward? = { n, event, rank, kind, pet?, amount? } }`. `reward` is the prize just paid (never saved).
- **The Huge Spectre Cannon** (`hugespectre`): in no egg and no shop, tradable, x`Config.HugePower` like every
  Huge. Its feature is Haunt: monsters walk 20% slower (a `monsterSpeed` modifier, so it stacks with a Frost
  tower's slow and STATS lists it).

### STATS (`Features/Stats.luau`, server and client)

The STATS menu button opens one window that shows every number and where it comes from. The server builds the
whole breakdown from `Game.breakdown`, `Game.value` and `state.towerList` (`Stats.snapshot`) and publishes it
as `Meta_stats`; the client only draws it. It is published only while the window is open and at most once a
second: the client sends `statsWatch(true)` when the window opens and every 4 s after, anything else when it
closes, and a watch that is not renewed for 12 s ends by itself.

```lua
State.feature("stats") = {
	at = unix time, power = Cannon Power, base = the towers' own damage per second, speed = game speed,
	towerPower = the towers' half of Cannon Power,
	chain = { { label, left?, mult, value } },   -- power's sources, then the fire rate's; value = the towers' DPS so far
	sections = { { id, name, unit = "x" | "count" | "rate" | "share", lowGood?, base, total,
		sources = { { label, left?, mult, add, value, how = "mult" | "add" } } } },
	towers = { { pad, kind, level, damage, rate, range, dps, share } },
	pets = { dps = the mini cannons' half, lines = { { label, dps, huge } },  -- one per mini cannon that deals damage
		bonuses = { { label, left?, mult, add, value } },                     -- the `petDps` modifiers
		damage = one average shot, shots = per second, equipped },
	totals = { kills, bosses, hatches, levels, seconds, best, rebirths },
}
```

- A source is whatever a modifier's label says. A label that ends in `(12:40 left)` is a timed source: the
  countdown is sent apart as `left` and drawn as a chip. So **label every modifier** (`Game.modify(kind, fn,
  label)`): an unlabelled one is listed as "Other".
- The POWER tab writes the towers' chain, then one `+` line per mini cannon with its own DPS and one per
  `petDps` modifier, down to Cannon Power. Mini cannons are never a multiplier in the chain.
- The sections are listed in `Stats.SECTIONS` (server): tower damage (`power` and `damage`), fire rate, range, boss
  damage, coins, luck, lives, monster speed, mini cannon DPS (`petDps`), mini cannon shots (`autoShots` x `petShots`), tower crit chance, mini cannon crit chance and crit damage (only while something changes them; a chance reads as a percentage, unit `chance`), mini cannon range
  (`petRange`, only while something changes it), equip slots, and, only
  while something changes them, upgrade price, gems per boss, crate drops and monster healing, then offline
  hours (`offlineCap`) and offline earnings (`offlineShare`). A new modifier kind needs a line there to be shown.
- "Game limit" is the line for what the core's own limits changed (a fire rate past x10, lives rounded).
- What a `shot` hook does to a shot (an ammo's damage, a Huge's double hit) is not a modifier, so it is in no
  breakdown and not in the window.
- The lifetime totals the core did not count are kept by this feature: `data.features.stats = { bosses, levels,
  seconds, seeded }` (bosses defeated, levels cleared, seconds played). An older save starts them from its
  `bestCleared`.

### Redeem codes (`Features/Codes.luau` x3)

The group's page promises codes; the CODES window (menu button CODES) is where one is typed.

- **The list** is `Codes.List` in `src/shared/Features/Codes.luau`: `CODE = { gems = n, clears = n, item = id,
  amount = n, expires = Codes.day(year, month, day) }`, any mix of the rewards. The key is in capitals, letters
  and digits only. `clears` is coins worth that many clears of an ordinary level at the player's best level
  (`Config.levelCoins`). `expires` is the last UTC day the code works; without it the code never runs out.
  `LAUNCH` (100 gems) is a placeholder for Yaani to change. Adding a code is one line and a publish.
- **The action** `redeemCode` takes the typed text and nothing else. The server trims it, puts it in capitals,
  looks it up and pays. Each code pays a player once: `data.features.codes.used[code]` holds when. It is
  marked used before it is paid. Unknown, used and expired codes are each answered with a toast, and so is a
  try within `Codes.COOLDOWN` (2 s) of the last one, which is not looked up at all.
- A line of the list that cannot be paid (an item that does not exist, no reward) is refused with a warning in
  the server log and is not used up, so fixing the line lets players redeem it.
- **The window** is a text box and a REDEEM button, opened from its menu button only. `tests/codes.luau` covers
  all of the above and a rejoin.

### Analytics (`Features/Analytics.luau`, server only)

What Creator Hub's Analytics pages are fed: the funnel of a new player's first ten minutes, and the Robux
purchases a server sees. It changes nothing in the game and uses hooks only.

- **The funnel** is `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)`, seven steps
  (`Analytics.STEPS`), numbered in the order a new player is expected to reach them. A player may reach them
  in any order; each is logged the moment it happens and once per player ever.

| Step | Name | Read from |
|---|---|---|
| 1 | Joined | the `ready` hook |
| 2 | Welcome done | `data.features.tutorial.welcomed` (START or Skip on the last welcome card) |
| 3 | First tower built or upgraded | the towers before and after an action (`action` / `acted`): one more, or a level higher. The starter cannon is not a step |
| 4 | Level 5 cleared | `waveCleared`, and `data.bestCleared` |
| 5 | First hatch | the `hatch` hook, and `data.totalHatches` |
| 6 | Level 10 cleared | as level 5 |
| 7 | First marketplace visit | `state.place == "market"`, on `tick` |

- **Saved** as `data.features.analytics = { old, done = { [step id] = true } }`. `old` is set on a save that was
  played before the feature existed (`lastSeen` is not 0 when the table is first made): such a player is kept
  out of the funnel for good, instead of pouring seven steps into it on one join.
- **Purchases** are custom events, `LogCustomEvent(player, name, value, { CustomField01 = ... })`:
  `PassBought` (value: the pass's price in `Config.Passes`, field: its key) when `Passes.changed` shows a pass
  the player did not have a moment ago, and `ProductBought` (value 0, field: the product id) when a developer
  product's handler returns true. The core has no purchase hook, so the feature wraps the handlers in
  `Game.products` each time a player becomes ready; a product registered later is wrapped on the next join.
  Not seen: a pass bought on the game's page while the player is not in the game, and a product's price (it
  is in each feature's own table, not in the core). Roblox's own Monetization page counts both anyway.
  `LogEconomyEvent` is for coins and gems, not Robux, and is not used.
- **Never in Studio.** `Analytics.logger` is the service on a live server and nil in Studio and in the
  emulator. With no logger nothing is sent and nothing is saved, so a save made in Studio still starts the
  funnel on its first live join. Every call is in a pcall; one that fails is warned about, not marked as
  logged, and tried again on the next join.
- `tests/analytics.luau` puts a fake logger there before the server starts (`analytics.pre.luau`).

### Robux

- Game passes: add an entry to `Config.Passes` from your shared module
  (`Config.Passes.myPass = { id = 0, order = 20, name = ..., desc = ..., price = ... }`), check with
  `Passes.owns(player, key)` (`require(script.Parent.Parent.Passes)`). The store window lists it automatically.
  `id = 0` means not on sale yet. Nobody owns a pass they have not bought, in Studio either: there the Debug
  remote gives or takes one (`"pass:<key>"`, below). The passes today: x3 Egg Opener, x3 Luck, +3 and +5 Mini
  Cannon Slots, +500 Mini Cannon Storage, 3x Speed (`gameSpeed`; 2x is free).
- Developer products: `Game.products[productId] = function(player) ... return true end`, prompt with
  `Game.promptProduct(player, productId)`.
- Paid random items: anything random that is paid for with Robux or with a currency of `Config.PaidCurrencies`
  (gems), and any pass marked `odds = true` (x3 Luck). Before selling one, ask
  `Policy.maySell(player, "The Gem Egg")` (`require(script.Parent.Parent.Policy)`): it returns true, or false
  with the toast to show (text, kind). `Policy.restricted(player)` is the bare answer (nil until Roblox has
  given one) and `Policy.changed` fires with the player when it arrives. The eggs, the crates and enchanting
  all go through it; show the odds wherever the roll is bought. `tools/emu/tests/policy.luau` checks both
  (`harness.setPolicy(true | false | nil)` sets what Roblox answers the next player who joins).

### The marketplace

`Marketplace.frame(x, y, z)` gives a frame in marketplace space (x east, z south, the statue at 0, 0; the square
spans -75..75) and `Marketplace.container()` the folder to parent props to. Build with the helpers in `Build.luau`.
A `ProximityPrompt` with the attribute `Window = "<NAME>"` opens that window on the client with no server code.
One with the attribute `Loot = "<source id>"` opens the loot viewer on that source (see `ctx.Loot`).

### The MINI CANNONS window

A feature of its own: rules `src/shared/Features/Minis.luau`, server `src/server/Features/Minis.luau`, window
`src/client/Features/Minis.luau` (design at the end of `docs/MINI_CANNON_REVAMP.md`). The core still equips
the strongest mini cannons by itself, but asks `Game.equipPicker(player, data, slots)` first: the feature
answers with the player's own picks once they have equipped or unequipped by hand (`Minis.resolve`), and nil
while they have not. `Game.equipped(player)` and `Game.equipSlots(player)` are for features. Actions:
`minisEquip`, `minisUnequip`, `minisBest`, `minisUnequipAll`, `minisLock`, `minisDelete`, `minisLoadout`.
The client reads `State.feature("minis")`: `manual`, `locked`, `loadouts`.

### The store

The STORE window (`src/client/Windows.luau`) has three tabs: GEMS, ITEMS and PASSES. The catalogue of the
first two is `src/shared/Features/Store.luau`: `Store.GemPacks` (Robux developer products; `product = 0` means
not created yet; the first pack a player buys is doubled) and `Store.Items` (backpack items for gems). The
server half (`src/server/Features/Store.luau`) registers each pack in `Game.products`, and has the actions
`storeBuyPack` (asks `Policy.maySell`, then prompts) and `storeBuyItem`. Gems are the main currency: new things
are priced in gems and go in `Store.Items`.

### Blender bases

A world whose base has a Blender model (`tools/blender/base.py <World>`, imported with
`tools/studio/setup_models.luau` as `ReplicatedStorage.BaseModels.<World>` plus `<World>Shells`) wears it over
the part-built base while the plot has an owner: `dress` / `undress` in `Plots.luau`, called from `dressBase`.
The parts stay, unseen (their look is kept in the attributes `Seen` and `Shadow`), as the floor, the walls and
the carriers of every prompt, sign and attribute; the lamps' bulbs, the teleporters' beams and the FOR SALE
signs stay visible. Shells are placed on the game's own spots: `Pad` + `PadTrim` (tinted with the pad's state
colour), `Gate` + `GateTrim` (the owner's colour), `Portal` + `PortalSheet`, `Teleporter` + `TeleporterTrim`,
`Lamp`. `BASE_SOLIDS` adds unseen colliders for the model's solid pieces. Without the folder in the place, or
on a plot nobody owns, the base looks as before. Not yet run in Studio.

### The world islands

`Islands.luau` (required by `init.server.luau`, built after the marketplace and before the features start)
builds one island per world from one template: the world's two coin eggs, a shop stall, a portal back, an
arrival pad, a statue of the world's boss, props in the world's colours. They stand in two rows of six far
from every base (`Layout.islandCFrame(index)`, `Layout.islandSpawn(index)`, `Layout.ISLAND_RADIUS`). Island
space is like marketplace space: the middle at 0, 0, x east, z south. Players arrive in the middle, looking
north; the eggs, the stall, the portal and the two reserved spots stand in a ring 15 to 16 studs around the
arrival pad, facing it, and the statues and the scenery stand at the rim.

| Call | Does |
|---|---|
| `Islands.container(index)` | The island's folder (`workspace.Islands.Island_<index>`, attribute `World`), to parent things under |
| `Islands.frame(index, x, y, z)` | A frame in that island's space, like `Marketplace.frame` |
| `Islands.spot(index, "mastery")`, `Islands.spot(index, "enchant")` | The two reserved 12 x 12 spots: a frame at floor level in the middle of the spot, its -Z facing the middle of the island. Each is 16 studs from the arrival pad; two things on one spot (the enchanting table and the fusion machine on `enchant`) stand at x = -5 and x = 5 of the frame, which keeps both within 17 studs of the pad and 10 apart. Kept clear by everything else on the island; a faint plate `Spot_<name>` marks each |
| `Islands.returnPrompts[index]`, `Islands.shopPrompts[index]` | The portal home's prompt and the stall's |

Require it with `require(script.Parent.Parent.Islands)` from a server feature. All return nil for an unknown
island or spot.

**A world with a Blender island** (Earth so far; `tools/blender/island.py <World>` makes any of the five, `earth_island.py` is its old name for Earth; imported into the place as
`ReplicatedStorage.IslandModels`) wears it over the island built from parts. `IslandModels.<World>` is a model
of scenery meshes whose pivot is the middle of the island on the ground, in island space;
`IslandModels.<World>Shells` holds the landmark meshes (`EggPedestal`, `Stall`, `Portal`, `PortalSheet`,
`BossPlinth`), each with the middle of its base as pivot and its front towards -Z, placed on the game's own
spots. `Islands.wear` makes the part-built pieces unseen (they stay as the floor, the rim wall, the lamps'
light and the carriers of every prompt and sign, so the calls above do not change) and skips the props; the
eggs stand on the model's pedestal (`Marketplace.buildEggStand(egg, frame, parent, pedestal, top)`), and the
statues are the monsters' Blender models. The meshes do not collide: what stops a player is the unseen
part-built island plus one unseen pillar per trunk, lamp and prop (`SOLIDS`, a list per world in island space). Without the folder in the place file, the island is built from parts as before.

- **Travel**: the action `goIsland(index)`, from the ISLAND button of a world's row in the WORLDS window. The
  green teleporter on the player's own base (`Plots.worldsPrompts[slot]`) opens that window: the core answers its
  prompt, for the base's owner only, by sending the client `("window", "WORLDS")`. An island opens when its world is
  reached (`Config.worldUnlocked`). The island's own portal, the travel button and `goHome` lead back.
- **Eggs**: a world's two coin eggs (`egg.world`) stand on its island; the marketplace keeps the Gem Egg and
  the Halloween eggs. The stands are the marketplace's own (`Marketplace.buildEggStand(egg, frame, parent)`),
  parented under `workspace.Marketplace.Eggs` wherever they stand, because that is where each client looks for
  a stand to write its price, odds and panel on. Their prompts are in `Marketplace.eggPrompts` /
  `tripleEggPrompts`, so the core hatches from them like any other, and "What's inside?" opens the loot viewer.
- **Island shop** (`Features/IslandShop.luau` x3): the stall's prompt opens the ISLAND SHOP window. Three
  rows for coins, all in `src/shared/Features/IslandShop.luau`: the world's ammo (`IslandShop.Ammo`; sold
  to a player who owns none of it, once a day), one powerup that changes every day and differs per island (one
  a day on each island) and a Boss Chest (one a day in all). From The Sun's island on there is a fourth row,
  for gems: the Enchantment Key (`IslandShop.Key`: 50 gems) and the Shiny one (`IslandShop.ShinyKey`: 1,000 gems), no daily limit. The action is
  `islandBuy { island, kind }`; the player must be standing on that island. The day's purchases are
  `State.feature("islandShop")`.
- Mini cannons follow the player on an island and are not drawn shooting from there; their damage still
  lands on the base's lead monster, and the towers keep fighting on the plot. The sky is the island's world's
  (`Effects.luau`).

### Private bases, visits and pause

- **Every base is private.** There is no street: the twelve plots stand alone, `Layout.PLOT_SPACING` (2,000
  studs) apart in two rows at z = 4,000 and z = -4,000 (`Layout.PLOT_ROWS`), all facing the same way, and no
  base is within `Layout.PLOT_APART` (1,500) of another base, the marketplace, an island or the lobby
  (`tools/emu/plots_geometry.py` checks it). A base is closed off: the backdrop behind the portal, lower
  hills (`Surround`) down both sides and behind the yard (`Layout.PLOT_YARD`, the 16 studs of ground behind
  where the owner arrives), and over all four sides an unseen wall (`Barrier`). Nobody walks or jumps off a
  base. Under the map is a safety net: twice a second the core puts any character below `Layout.FALL_HEIGHT`
  back on its own base.
- **Each base has two teleporters** beside the arrival spot (`Layout.TELEPORTERS`, 13 studs from
  `Layout.plotSpawn`, on the plaza behind the gate): `Plots.worldsPrompts[slot]` opens the owner's WORLDS
  window (the way to the islands) and `Plots.marketPrompts[slot]` takes the owner to the marketplace. The core
  wires both and lets only the base's owner use them; the MARKET menu button stays too.
- **The lobby** (`workspace.Plots.Lobby`, at `Layout.LOBBY`) is a small closed room with the `SpawnLocation`:
  where a character stands for the moment its save takes to load, before the game moves it to its base.
  The player never sees it: the loading screen is still up.
- **The loading screen** (`src/first/Loading.client.luau`, mapped to `ReplicatedFirst.First`) is the first
  client script to run. It removes Roblox's default loading screen, shows its own (the game's name,
  "Opening your base..." and three bouncing dots) and fades it out once the game has loaded, the player
  attribute `Slot` is set and the character stands within 30 studs of that base's `ArrivalPad` part. After 20
  seconds it goes away whatever happened. It runs before `ReplicatedStorage` has arrived, so it requires
  nothing: its colours, fonts and text are copies of the kit's and of `Config.GameName`, the one place where
  that is allowed. Renaming `ArrivalPad`, `Plot_<slot>` or the `Slot` attribute means changing it too.
- **Visits by invitation** (`Features/Visit.luau` x3; the rules are in the shared module). The VISIT menu
  button (MORE drawer) opens a window listing the other players on the server. INVITE is the action
  `visitInvite(user id)`: it asks that player to come to the asker's base, lasts `Visit.InviteSeconds` (60) and
  is declined by ignoring it. It is rate-limited like a trade request: `InviteGapSeconds` (3) between two,
  `AgainSeconds` (30) after one ran out before the same player can be asked again, at most `MaxIncoming` (5)
  waiting for one player and `MaxOutgoing` (5) out from one. JOIN is `visitJoin(user id)`: the server checks
  the invitation and calls `Game.setPlace(guest, "visit", slot)`, which lands the guest near the host's
  arrival spot. The guest's `state.place` is `"visit"` and `state.visit` the host's slot; they are sent the
  host's field for as long as the visit lasts, their own base keeps fighting (their mini cannons' damage
  lands there too) and nothing of theirs hurts the host's monsters. A guest has no rights on the base: every pad action only ever touches the asking player's own save,
  the client offers them no pad or teleporter prompt there, and the core refuses the teleporters to anyone
  but the owner. They go home with BASE (`goHome`); the host sends one home with SEND HOME
  (`visitKick(user id)`); the core sends every guest home when the host leaves the game, and a guest who
  respawns or falls lands on their own base. Published as `Meta_visit` (`invites`, `sent`, `later`, `nextAsk`,
  `guests`, `host`). An invitation also shows a card with JOIN, and a "!" on the VISIT button.
- **Pause** is the action `setPaused` (`true`, `false`, or nothing to switch) and the `Paused` attribute:
  while `state.paused` the core takes no simulation step for that player's plot (nothing spawns, walks, fires,
  burns or counts down, the break between levels included) and keeps sending its field, so the monsters stand
  still on screen; `Game.damage`, `damageAll`, `hurt` and `shoot` do nothing and `Game.leadNear` is nil.
  Building, upgrading, selling and picking a level work as always. It is session state: never saved, a player
  always joins unpaused (but for a new save, which the Tutorial feature pauses until its welcome cards close). It pays nothing: offline earnings go by the time since the last save and by the
  towers, not by play time (`Features/Offline.luau` is untouched); boosts run on the real clock, paused or not;
  the STATS window's seconds played keep counting.

## The client after the idle defence pivot

The game is a third-person idle defence (`docs/IDLE_DEFENSE.md`, contract in `docs/DEFENSE_SPEC.md`). On the client:

- The player walks everywhere with Roblox's own camera and controls. Nothing locks the camera or the controls
  and nothing listens for taps. The HUD wears its marketplace layout in both places (`Hud.setMode(true)`); its
  one travel button (`Hud.backButton`) says GO TO MARKET on the plot and BACK TO BASE in the marketplace.
- `Field.luau` draws the fight from the `Field` remote: monsters glide between the five messages a second,
  get an HP bar once hurt, a tint while slowed or burning, pop when they die and vanish quietly at the gate.
  The bar says the health in numbers too: a boss "1.2K / 3.4K" in big figures under its name, an ordinary
  monster only what it has left ("1.2K"), and of those only the six hurt ones furthest along at a time. The
  server still sends a share only: the max is `Config.levelPlan(level).hp`, which nothing changes per monster.
  It also plays the shots of every tower under `workspace.Plots` (turret turns, a projectile per kind from the
  `Muzzle`, at the tower's `rate` and inside its `range`, both times what the plot's owner has: their
  `TowerRate`, `TowerRange` and `GameSpeed` attributes). Models, bars, shots and numbers are pooled and capped (the limits are at
  the top of the file). Without `Shared.Models` a monster is a placeholder ball.
- `Effects.luau` moves the mini cannons (they always follow their owner), draws their shots at monsters near
  the player (for show: the server deals their damage wherever the player is), the Huge Shot, the hatch reveal
  and the lighting.
- `Features/Towers.luau` is the TOWER window, opened by a pad's prompt (`Pad` and `Slot` attributes): BUY PAD,
  the kinds of tower, a tower's numbers now and next, UPGRADE +1 / +10 / MAX, SELL (two presses), a range ring,
  and the signs and prompt texts on the player's own pads.
- `Features/Defense.luau` is the level HUD (world and level, on a boss level with the boss's health in numbers,
  lives, monsters left, previous / next / auto, total damage per second, the pause button, the game speed button), the cleared / failed / boss banners and
  the PAUSED banner, which stays while the plot is paused (a press on it resumes), placed through `Hud.onLayout`.
- Where the player is comes as four attributes: `Place` (`"plot"`, `"market"`, `"island"` or `"visit"`),
  `Island` (which one, 0 on none), `Visiting` (the slot of the base they are a guest on, 0 on none) and
  `InMarket` (true whenever the player is not on their own base: in the marketplace, on an island and on a
  visit; the HUD and the travel button go by it). `Paused` says whether their plot is paused.
- The server can open a window: `Game.send(player, "window", name)` (`init.client.luau` listens; a base's
  WORLDS teleporter does it).

## Client API (`ctx`, passed to `start`)

| Field | Use |
|---|---|
| `ctx.act(name, argument)` | Ask the server to run an action |
| `ctx.on(channel, fn)` | Receive `Game.send` messages |
| `ctx.State` | `State.get(attr, default)`, `State.meta`, `State.feature(key)`, `State.onChange(fn)`, `State.now()` |
| `ctx.UI` | `UI.window(title, w, h)`, `UI.scroll`, `UI.row`, `UI.header`, `UI.text`, `UI.button`, `UI.panel`, `UI.make`, `UI.Colors`. Candy Arcade kit (docs/UI_VISION.md): `UI.Variants`, `UI.shade`, `UI.sticker`, `UI.slot` (a container placed in design px), `UI.label`, `UI.pill`, `UI.bar`, `UI.toggle`, `UI.badge`, `UI.chip`, `UI.disc`, `UI.scale()`, `UI.W()`, `UI.T()`, `UI.onLayout(fn)` |
| `ctx.Hud.onLayout(fn)` | `fn(layout)` runs now and when the screen changes. `layout`: `s` (screen scale), `W`, `T` (top bar), `top` (y of the travel button at the top centre), `stack` (left stack y), `toast` (toast line y), in design px. Use it to place a HUD piece of your own. The level HUD sits under the travel button, from `top + 100` to `top + 240` on the plot and one 40 px line in the marketplace |
| `ctx.Windows.register(name, window, refresh)` | Make your window open by name and refresh with the rest |
| `ctx.Windows.boardNotes[boardId] = function() return text end` | A few lines under that board's heading in TOP PLAYERS (the event board's time left, prizes and own rank) |
| `ctx.Windows.shopNote = function(currency) return text end` | Text added to the heading of the event shop that sells for that currency |
| `ctx.Hud.addMenuButton(name, color, order, onClick, view)` | Menu button. Orders 10+ are free. view: both (default) or market. A `cannon` button is never shown: the HUD is in its marketplace layout everywhere |
| `ctx.flag(buttonName, fn)` | Show "!" on that menu button while `fn()` is true |
| `ctx.Hud.toast(text, kind)`, `ctx.Hud.popup(position, text, color)` | Messages and floating numbers |
| `ctx.onTap(fn)` | Does nothing: there is no tap to fire. Kept so old features still start |
| `ctx.Field` | The battlefield. `Field.lead(slot?)` is the model of the lead monster on a plot (the player's own by default; its `PrimaryPart` is the body), `Field.lead(slot, position, range)` the lead one that close to a point, `Field.count(slot?)` how many are alive, `Field.boss(slot?)` the health of the boss alive there as two numbers (left, max; nil without one). `Field.inspect(slot)` and `Field.stats()` are for tests |
| `ctx.Effects.projectile` | `{ color, size }` overrides for the hero shot (the player's first mini cannon firing) |
| `ctx.Effects.fire()` | Draws one hero shot at the lead monster near the player and runs the `onFire` hooks |
| `ctx.Effects.hugeShot(petId, landed)` | Draws a Huge Shot at the lead monster near the player (the one the mini cannons shoot at); false if it could not be drawn |
| `ctx.Effects.hatch(nil, results, gift)` | The hatch reveal for mini cannons that did not come from an egg: `gift = { name, color }` stands in for the egg, `results` is `{ { pet, kept, note } }` |
| `ctx.Effects.onFire(fn)`, `ctx.Effects.target()` | React to each hero shot; the lead monster's model on the player's plot (nil when none is drawn) |
| `ctx.Loot` | The loot viewer: `Loot.register(source)`, `Loot.open(id)`, `Loot.show(spec)`. See below |
| `ctx.Config`, `ctx.Format`, `ctx.Items` | Shared modules |

UI is laid out for a 720px tall screen and scaled. A window is `UI.window(...)`; build rows once and refresh their
text, so buttons do not vanish mid-click. Lay things out for a phone first: the bottom corners belong to the thumbs
(joystick left, jump right), so HUD pieces go top centre or on the right edge, never there.

### The loot viewer (`ctx.Loot`)

One window (`src/client/Loot.luau`, menu button LOOT) shows what anything that is opened can give: a card per
reward with its chance, and a catalogue of every registered source in groups. The eggs register themselves as
`"egg:" .. egg.id` in the group `Eggs`. Anything else with random rewards registers in its `start`:

```lua
ctx.Loot.register({
	id = "crate:pumpkincrate",   -- unique; registering the same id again replaces it
	group = "Crates",            -- the catalogue section
	name = "Pumpkin Crate",
	color = Color3.fromRGB(255, 130, 30),
	order = 1,                   -- position inside the group
	build = function()           -- called every time it is shown (and while it is open), so read State in it
		return {
			title = "Pumpkin Crate",
			subtitle = "250 candy",          -- optional
			color = Color3.fromRGB(255, 130, 30), -- optional
			rows = {
				{ chance = 0.4, pet = "cauldron" },  -- a mini cannon: the viewer fills in the rest
				{ chance = 5, name = "2x Power", color = Color3.new(1, 1, 0), rarity = "Rare", detail = "x1" },
			},
		}
	end,
})
ctx.Loot.open("crate:pumpkincrate")  -- the viewer on that source; with no id, the catalogue
ctx.Loot.show(spec)                  -- a one-off table, the same shape `build` returns
```

- `chance` is a percentage and the rows of a table add up to 100. Take it from the function the server rolls
  with: Roblox requires the odds shown for random items to be the real ones.
- A `pet` row gets its name, colour, rarity, power, 3D preview and an OWNED mark from `Config.Pets`. A hidden one
  (`Config.Pets[id].hidden`) is a "???" silhouette, chance still shown, until the player has found one.
- Any other row: `name`, and optionally `color`, `rarity` (a key of `Config.RarityColors`; anything else gets a
  neutral colour), `detail` (a short line under it) and `icon` (an emoji on its round icon).
- Rows are shown most common first. `keepOrder = true` in the table keeps the order they were given in.
- Optional extras in the table: `subtitleColor`, `note` (a small line under the subtitle), `luck` (a number:
  shows the luck chip), `shape = "egg"` (the header picture; a rounded box otherwise).
- Optional extras in `register`: `shape`, and `info = function() return { status, statusColor, sub, subColor,
  locked } end` for what the catalogue tile says under the name. Without it the tile shows the table's subtitle.
- A `build` that errors or returns nonsense only shows "could not be loaded"; `register` works at any time.
- Also there for features: `Loot.owned(petId)`, `Loot.found(petId)`, `Loot.luck()`.

## Testing

Outside Studio there is an offline emulator: `cd tools/emu && python3 run.py --all-features tests/smoke.luau`
boots the server and the client and plays the game (`tools/emu/mocks` stands in for the plots, the marketplace
and the leaderboards; the islands are the real ones, with stand-in egg stands). It covers enchanted ids,
enchanting with each key, the Shiny key's guarantee over many rolls, fusing and both windows, the speed pass
and offline earnings (the same player leaving and coming back after a faked 30 seconds, 2 hours and 20 hours),
pause (a level stops and resumes) and a visit with two players (invitation, expiry, JOIN, what a guest
cannot do, BASE, SEND HOME, the host leaving).
`tests/offline.luau` joins a player whose save is two hours old and presses CLAIM on the welcome-back card. `tests/tutorial.luau` plays the first join: the welcome cards, the fan bonus (not in the group, Roblox not answering, a member, a second press, a later join), every walkthrough step from real actions, a rejoin, an old save, a failed level and the Studio replay. `tests/codes.luau` redeems codes: once, twice, junk, too fast, expired, each kind of reward, from the window and after a rejoin. `tests/analytics.luau` checks the funnel and the purchase events against a fake logger (each step once, in any order, nothing after a rejoin, an older save, a logger that fails or is missing). `tests/mastery.luau` is the mastery feature's own test. `tests/event.luau` is the event leaderboard's (earning, the freeze, the prizes, with made-up board contents), and `python3 run.py --all-features --real-leaderboard tests/event_board.luau` runs it on the real `Leaderboard.luau` and emulated OrderedDataStores (`harness.failOrdered(n)` makes their next n requests fail; in this emulator a thread that waits never wakes, so a test calls `Leaderboard.refresh()` and the event feature's `check()` itself). `python3 run.py --all-features --real-plots tests/defense_client.luau` runs the client
against the real server and the real `Plots.luau` and checks the battlefield, the TOWER window, the level HUD
and travel. `cd tools/emu2 && GAME_ROOT=<tree> python3 boot.py` boots the server with the real `Plots` and
`Marketplace`, `play.py` there lets a player join, build, upgrade, sell, travel and leave, then plays a visit between two
players with real positions (who is sent whose field, where the guest lands), a pause and a fall under the
map, and `islands.py`
measures the islands (what stands where, which way it faces, what is kept clear) and plays a visit.
`python3 tools/emu/plots_geometry.py` measures the plots and models, and checks that no two bases are within
1,500 studs and that every base is closed off. `python3 tools/balance/sim.py` plays the
balance. The emulators draw nothing, so aiming and looks still need Studio. In a Studio play test the client command bar accepts:

```lua
local d = game.ReplicatedStorage.Remotes.Debug
d:FireServer("coins", 1e9)            -- any number field of the save
d:FireServer("wave", 50)              -- jump to a level
d:FireServer("towers", 60)            -- put every tower you have at that level
d:FireServer("pet:wooden", 27)        -- give mini cannons
d:FireServer("item:power2x", 5)       -- give backpack items
d:FireServer("pass:tripleHatch", 0)   -- take a pass away (1 gives it back)
```
