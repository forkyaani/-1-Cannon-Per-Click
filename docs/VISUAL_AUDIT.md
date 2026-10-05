# Visual audit: what still looks default or placeholder

Written 5 Oct 2026 from a read of every file under `src/` (the `.conflict` copies were skipped). Functions
and tables are named, never line numbers: the files are being edited today.

- **Seen**: always (on screen while you play) / every session / sometimes / rarely.
- **Size**: S = one sitting, M = about a day, L = several days (split into sittings in the phases).
- **Status**: not started / in progress / done.
- Paths are under `src/`. `Marketplace.x` means `server/Marketplace.luau`, function or table `x` (local ones
  too); the same for `Plots`, `Islands`, `Build`, `Game` (server), `Models`, `Config` (shared), `Field`,
  `Effects`, `Hud`, `Windows`, `Loot`, `Market`, `UI` (client). `F/Name` is `Features/Name.luau` (client or
  server, as said).

## 0. Already replaced or in progress

| Thing | Where | Status |
|---|---|---|
| UI kit: sticker, button, window shell, pill, bar, toggle, badge, chip, disc, icon atlases A and B (32 icons) | `client/UI.luau` | done |
| HUD: stat pills, menu orbs, MORE drawer, toasts | `client/Hud.luau` | done (leftovers: U13 to U16, U20) |
| Prompt pills (all 19 `Build.prompt` call sites use the Custom style), the eggs' three prompts included | `Market.showPrompt` | done. The panel that opened by itself at an egg was removed on 2026-10-05 at Yaani's request: F ("What's inside?") opens the loot viewer instead |
| Level HUD, welcome-back card, tutorial cards and banner, visit invite | client `F/Defense`, `F/Offline`, `F/Tutorial`, `F/Visit` | done (built from kit pieces; emoji icons remain: U13, U43) |
| Earth's five monsters and one boss as Blender models | `Models.monster`, `Models.creatureFor`; `tools/blender/wave.py`, `boss_king.py` | done in code. Needs `ReplicatedStorage.Creatures` in the place file (not verifiable from `src`) |
| Marketplace eggs and their 25 mini cannons | `tools/blender/minis.py`, `assets/models/minis/`; `Models.mini`, `Marketplace.buildEggStand` | done (2026-10-05). Needs `ReplicatedStorage.MiniCannons` and `ReplicatedStorage.EggModels` in the place file |
| Earth island remodel | `tools/blender/earth_island.py`; `Islands.dressFor`, `Islands.wear` | done (2026-10-05): the Blender island is worn over the part-built one, which stays unseen as floor, rim wall and prompt carrier. Needs `ReplicatedStorage.IslandModels` (`Earth`, `EarthShells`) in the place file. Its trees, lamps and props are solid through unseen pillars (`SOLIDS` in `Islands.luau`); the small ground dressing is switched off (`CLUTTER` in the script) at Yaani's request |

## 1. Models built from plain Parts in code

### The fight and the plot (on screen all the time)

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| M1 | Towers: 7 silhouettes (cannon, gatling, mortar, sniper, frost, flame, tesla) from cylinders, blocks and balls. A tier is a recolour plus white bands; rank changes the plinth material, adds a glow ring and a halo | `Models.tower`, `Models.KINDS.*`, `plinthStyle`; placed by `Plots.setTower` | always | Blender model per kind with tint zones (body, trim, accent), found by name like the creatures, parts as fallback | L | not started |
| M2 | Rocket tower has no shape of its own: it is built as a cannon | `Models.tower` (`KINDS[kind] or KINDS.cannon`), `Config.Towers.rocket` | sometimes | Its own model | S | not started |
| M3 | Monsters without a template: 6 part archetypes (blob, biped, floater, crawler, jelly, spiker). All 55 ordinary monsters of worlds 2 to 12 | `Models.monster`, `Models.ARCHETYPES.*`, `piece`, `eyes` | sometimes (always from world 2) | Blender creature per monster, world by world | L | not started |
| M4 | Bosses: every giant, mid boss and world boss of every world falls back to the one `Boss` template. Giants are named "Giant X", so they never use X's own model. 24 named bosses have no model | `Models.creatureFor`, `Config.monsterFor` | every session (every 5th level) | Giant = its own monster scaled up (code); one model per mid and world boss | S + L | in progress (1 boss) |
| M5 | Stand-in ball with eyes, when a monster cannot be built | `Field.placeholder` | rarely | Keep as the safety net | S | done |
| M6 | Mini cannons, builder 1 (the ones that follow players): cylinder barrel, 2 wheel discs, 2 eyes, tier bands; a Huge is the same at 4x with bands and a halo disc | `Plots.buildPets` | always | One `Models.mini(pet)` from templates, parts as fallback | M | in progress (25 modelled, none wired; about 125 world-egg ones not started) |
| M7 | Mini cannons, builder 2: the 3D previews and silhouettes in the loot viewer | `Loot.buildMini` (used by `Loot.showModel`) | sometimes | The same `Models.mini` | S | in progress |
| M8 | Mini cannons, builder 3: the Huge on the showcase pedestal | server `F/Huge.buildShowcase` | sometimes | The same `Models.mini` | S | not started |
| M9 | Tower shots: pooled neon balls, blocks and beams | `Field.STYLES`, `Field.fire`, `Field.zap`, `Field.beam` | always | Mesh projectile per look (see E1) | M | not started |
| M10 | Mini cannon shots: a neon ball | `Effects.shoot` | always | Small cannonball mesh with a trail (see E7) | S | not started |
| M11 | Ground and yard: two slabs, material per world | `Plots.buildGround`, `Plots.dressWorld`, `Plots.THEMES` | always | Ground mesh with a soft edge, texture per world | M | not started |
| M12 | Path: road and kerb slabs | `Plots.buildStrip` | always | Path tile kit (straight, corner), material per world | M | not started |
| M13 | Cannon pads: a flat 7 x 7 part, colour by state, a "+" painted on top | `Plots.buildPads`, `Plots.dressPad` | always | Pad model with three states (for sale, empty, built on) | S | not started |
| M14 | FOR SALE sign: post, red board, text. Up to 15 stand on a new base, and the owner's own billboard (U3) says the same thing over each | `Plots.saleSign` | always | One sticker sign per pad (drop the duplicate) | S | not started |
| M15 | Gatehouse: 2 cylinder towers, battlement discs, ball roofs, flag pole and slab flag, walls, beam, merlons, plaza slab, arrival disc | `Plots.buildBase` | always | Gatehouse model with tint zones for the owner's colour | M | not started |
| M16 | Gate: a see-through neon slab | `Plots.buildBase` (Gate), `Plots.dressBase` | always | Portcullis or energy gate mesh | S | not started |
| M17 | Monster portal: 2 pillars, 2 ball horns, a beam, a see-through slab | `Plots.buildPortal` | always | Portal arch model with a swirl | S | not started |
| M18 | Fence: posts and rails | `Plots.buildGround` (fence) | always | Fence segment mesh | S | not started |
| M19 | Skyline: 5 backdrop slabs with the world's name, 17 hill slabs around the base | `Plots.buildGround` (backdrop, `hill`), `Plots.dressWorld` | always | 3 or 4 hill and skyline meshes, tinted per world | M | not started |
| M20 | Lamps: block post, neon ball (three copies of the same lamp) | `Plots.lamp`, `Marketplace.buildLamp`, `Islands.buildLamp` | always | One lamp model, used in all three | S | not started |
| M21 | Teleporters: neon disc, see-through cylinder, orb | `Plots.buildTeleporter` | every session | Teleporter pad model with particles | S | not started |
| M22 | World props: 7 kinds (tree, rocks, crystals, vent, puff, machine, orbit), 10 per base, recoloured for 12 worlds | `Plots.PROPS.*`, `Plots.PROP_SPOTS`, `Plots.THEMES` | always | Earth's tree first, then one kind at a time | M | not started |
| M23 | Halloween pumpkins | `Build.pumpkin` (called from `Plots.buildBase`, `Marketplace.buildDecor`, `buildStalls`, `buildTradingPlaza`, server `F/Crates.buildStand`) | sometimes (event) | Pumpkin mesh | S | not started |
| M24 | Lobby room: floor disc, ring, 8 walls, orb | `Plots.buildLobby` | every session (seconds) | Hide behind the loading screen (D11) | S | not started |

### Eggs and islands

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| M25 | Egg and stand: pedestal cylinder, cushion disc, ellipsoid egg with 9 ball spots. One shape for every egg, only the colour differs | `Marketplace.buildEggStand` (also called by `Islands.buildEggs`) | every session | Egg model per family, one stand model | M | in progress (marketplace eggs; world eggs not started) |
| M26 | Island ground: disc, plaza disc, 16 rim slabs, arrival disc. 12 islands from one template | `Islands.buildGround` | every session (Earth), sometimes (others) | Island mesh, recoloured per world | M | done for Earth (2026-10-05); worlds 2 to 12 not started |
| M27 | Portal home: 2 pillars, beam, neon slab (the same gate is built twice) | `Islands.buildPortal`, `Marketplace.buildPortal` | every session | One portal model for both | S | not started |
| M28 | Island shop stall: counter, posts, awning slabs, a ball and a box on the counter | `Islands.buildStall` | sometimes | Stall model shared with M34 | S | not started |
| M29 | Statues: the boss and two monsters, always the part archetypes in marble. Earth's too: no name is passed, so the Blender templates are never used | `Islands.buildStatue`, `Islands.buildCentre` | every session | Clone the creature template, stone material | S | done (2026-10-05): the name is passed. The boss statue uses a template only on an island with a Blender model (Earth) |
| M30 | Island props: 5 kinds (tree, rock, spire, orb, crate), 12 per island | `Islands.PROPS.*`, `Islands.buildProps` | every session | Reuse the plot's prop meshes (M22) | S | done for Earth (its Blender island brings its own trees); others not started |
| M31 | Reserved spot plates | `Islands.buildSpot` | sometimes | Remove or a ground decal | S | done for Earth (framed plots in the island model); others not started |
| M32 | Mastery Shrine (Mars): discs, 4 pillars, ball flames, block altar, cube crystal | server `F/Mastery.buildShrine` | sometimes | Shrine model | S | not started |
| M33 | Enchanting Table and Fusion Machine (The Sun) | server `F/Enchant.buildTable`, `F/Fuse.buildMachine` | sometimes | Two models | M | not started |

### Marketplace

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| M34 | Stalls (weekly shop, Halloween shop, game passes) with a cube gem and a ball star | `Marketplace.buildStall`, `buildStalls` | sometimes | Stall model with a sticker sign | S | not started |
| M35 | Ground: lawn slab, cobble slab, plaza disc, arrival disc | `Marketplace.buildGround` | sometimes | Square mesh with real cobbles | M | not started |
| M36 | 20 houses (box, three roof slabs, door, windows) and 4 corner towers with ball roofs | `Marketplace.buildHouse`, `buildTown` | sometimes | 3 or 4 house models, tinted | L | not started |
| M37 | Trees: cylinder trunk, three balls | `Marketplace.buildTree`, `buildDecor` | sometimes | The tree from M22 | S | not started |
| M38 | Fountain and the giant golden cannon: cylinders, a flat water disc | `Marketplace.buildStatue` | sometimes | Hero statue model, moving water | M | not started |
| M39 | Hatchery board and posts | `Marketplace.buildHatchery` | sometimes | Arch or banner model | S | not started |
| M40 | Leaderboard boards (3) and the event board | `Marketplace.buildLeaderboard`; server `F/Event.buildBoard` | sometimes | Board model with kit rows (U6) | M | not started |
| M41 | Daily chest: boxes with gold bands | `Marketplace.buildChest` | sometimes | Chest model that opens | S | not started |
| M42 | Notice boards (missions, how to trade) | `Marketplace.buildNoticeBoard` | sometimes | Board model | S | not started |
| M43 | Trading plaza: rug discs, table, a cylinder "cannon", a cube gem, lanterns | `Marketplace.buildTradingPlaza` | sometimes | Plaza set | M | not started |
| M44 | Ammo Forge: furnace box, chimney, anvil, rack of neon balls | server `F/Ammo.buildForge` | sometimes | Forge model | M | not started |
| M45 | Crate stand: stacked coloured boxes with bands and a "?" | server `F/Crates.buildStand` | sometimes | Crate model per crate | M | not started |
| M46 | Huge showcase pedestal | server `F/Huge.buildShowcase` | sometimes | Pedestal model (with M8) | S | not started |
| M47 | Captain Kaboom, the story NPC: ball body, ball eyes and hands, disc hat, spyglass, on a plinth. He never moves | server `F/Story.buildGuide` | sometimes | Character model with an idle animation | M | not started |

Not in the game at all: pickups (coins and drops go straight to the balance, see E14).

## 2. Roblox defaults left as they are

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| D1 | Skybox. No `Sky` is created anywhere in `src`. A world's "sky" is only a clock time, a brightness and an ambient colour | `Effects.updateLighting`, `Effects.MARKET_SKY`, `HALLOWEEN_SKY`, `Config.Worlds[n].sky` | always | A `Sky` per world, the marketplace and Halloween, set from the same table | M | not started. **Unverified**: the place file may hold a Sky |
| D2 | Atmosphere, bloom, colour correction, sun rays: none in `src` | same | always | One lighting set per world: Atmosphere, Bloom, ColorCorrection | M | not started. **Unverified** in the place file |
| D3 | Lighting technology, shadows, environment light | place file only | always | Set once in Studio | S | not started. **Unverified** |
| D4 | Clouds: none (still open in `docs/UI_VISION.md`, task 4) | none | always | `Clouds` or mesh clouds | S | not started |
| D5 | Baseplate and terrain: the baseplate is removed, no terrain is used. Everything is slabs over the void, closed off by rim walls | `Plots.build` | always | Nothing to do; M19 hides the void | S | done |
| D6 | Avatar: the player's own Roblox avatar with Roblox's own animations. Only the walk speed is set | `Game.setPlace` (`WALK_SPEED`) | always | Optional: own run and idle animations, a cannoneer accessory | M | not started |
| D7 | Chat: default. `TextChatService` is never touched | none | always | Chat window colours and font | S | not started |
| D8 | Player list with `leaderstats` (Gems, Rebirths, Cannon Power). The HUD leaves the top right free for it on purpose | `Game.newLeaderstats`, `Game.sync` | always | Keep, or hide it and build a kit list | S | not started (kept on purpose) |
| D9 | Health bar and backpack: never switched off. Nothing hurts a player and there are no tools, so they rarely show | none (`StarterGui` is never used) | rarely | `SetCoreGuiEnabled` off for both | S | not started |
| D10 | Mouse cursor: default | none | always (PC) | Cursor image | S | not started |
| D11 | Loading screen: Roblox's own. No `ReplicatedFirst` script, and `default.project.json` does not map that folder | none | every session | Own loading screen, held until the base has opened | M | not started |
| D12 | The wait after loading: a closed room with a text billboard "Opening your base..." | `Plots.buildLobby` | every session | Covered by D11 | S | not started |
| D13 | Sound: none in the whole game. The only hooks are six crate-opening sounds, all with id 0 (silent). `UI.sound` from the UI spec does not exist | client `F/CrateOpening` (`SOUNDS`) | always | `UI.sound` and `UI.Sounds`, about 25 Creator Store sounds | M | not started |
| D14 | Music and ambience: none | none | always | One loop per place (base, marketplace, island) | S | not started |
| D15 | Particles use Roblox's default texture: neither emitter sets one | `Field.spark` (death sparks), `Plots.buildPets` (Huge aura) | always | Own spark, star and smoke textures | S | not started |
| D16 | Death and respawn: default. A new character is put back on its base; fallers are caught | `Game.onCharacter`, `Game.catchFallen` | rarely | Keep | S | not started (kept on purpose) |
| D17 | Camera: default third person, zoom capped at 45, turned to face the way after a trip | `Game.onPlayerAdded` (`MAX_CAMERA_ZOOM`), `Effects.faceArrival` | always | Keep; add a shake for boss kills (E4) | S | not started (kept on purpose) |
| D18 | Touch controls and top bar: default | none | always (phone) | Keep | S | not started (kept on purpose) |
| D19 | Scroll bars and button dimming: Roblox's default scroll bar colour in two lists, `AutoButtonColor` on two kinds of tile | `Loot.scroller`, `Loot.tileFor`; client `F/Trading` (backpack `grid`, `cell`) | sometimes | `UI.scroll`, sticker press | S | not started |
| D20 | Game icon and thumbnails: concept art only (`docs/ui-vision/`) | outside `src` | every session (the game page) | Re-render once the real models exist | M | not started. **Unverified** what is uploaded |

Checked and fine: every ProximityPrompt goes through `Build.prompt` (19 call sites, none left with Roblox's look).

## 3. UI that bypasses the kit

### Signs in the world

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| U1 | The sign helpers themselves: every server sign is a white FredokaOne label, scaled text, Roblox's black text stroke, no plate | `Build.label`, `Build.billboard`, `Build.surface` | always | One `Build.sign`: cream sticker plate, ink outline, LuckiestGuy title, atlas icon | S | not started |
| U2 | Base signs: world name on the backdrop, owner's name over the gate, "+" on empty pads, FOR SALE, "WORLD ISLANDS" and "MARKETPLACE" over the teleporters, a Huge's name plate | `Plots.buildGround` (`paint`), `buildBase`, `buildPads`, `saleSign`, `buildTeleporter`, `buildPets` | always | `Build.sign` | S | not started |
| U3 | The owner's pad signs: raw labels on a billboard ("FOR SALE ★ price", "EMPTY PAD", tower name and level) | client `F/Towers` (`signFor`, `refreshPads`) | always | Kit sticker sign with the coin icon | S | not started |
| U4 | Marketplace signs: MARKETPLACE, 🥚 EGG HATCHERY 🥚, 💎 WEEKLY SHOP, 🎃 HALLOWEEN SHOP, ⭐ GAME PASSES, 🎁 DAILY REWARD, 📜 MISSIONS, HOW TO TRADE, 🤝 TRADING PLAZA, and "BACK TO YOUR CANNON" (old wording: it is a base now) | `Marketplace.buildStatue`, `buildHatchery`, `buildStall`, `buildChest`, `buildNoticeBoard`, `buildTradingPlaza`, `buildPortal` | sometimes | `Build.sign`; fix the portal's words | M | not started |
| U5 | Egg stand sign: name and price with an emoji currency on a dark plate. The server's bigger Panel is dead (the client switches it off) | `Marketplace.buildEggStand` (`heading`); `Market.refresh`, `Market.setStatus` | every session | Cream card sign with a price pill (UI_VISION 4.2) | S | not started |
| U6 | Leaderboard boards: one text blob per board | `Marketplace.buildLeaderboard`, `Marketplace.setBoard`; server `F/Event.buildBoard` | sometimes | Ranked rows with medals and headshots (needs the user id in `Leaderboard.refreshBoard` rows) | M | not started |
| U7 | Island signs: "EARTH ISLAND / World 1 • boss", "BACK TO YOUR BASE", "🏝️ ISLAND SHOP" | `Islands.buildCentre`, `buildPortal`, `buildStall` | every session | `Build.sign` | S | not started |
| U8 | Feature signs: 💥 AMMO FORGE, 📦 CRATES with a price list board and "?" on each crate, ✨ ENCHANTING, ✨ FUSION MACHINE, MASTERY, Captain Kaboom's "📖 STORY", the Huge's name and "R$" price plate, the event board | server `F/Ammo.buildForge`, `F/Crates.buildStand`, `F/Enchant.buildTable`, `F/Fuse.buildMachine`, `F/Mastery.buildShrine`, `F/Story.buildGuide`, `F/Huge.buildShowcase`, `F/Event.buildBoard` | sometimes | `Build.sign` | M | not started |
| U9 | Lobby sign "Opening your base..." | `Plots.buildLobby` | every session | Loading screen (D11) | S | not started |

### HUD and fight

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| U10 | Monster HP bar and boss name: hand-built frames on a billboard, not `UI.bar` | `Field.newBar`, `Field.showHealth` | always | Kit bar look (ink outline, gloss); boss bar with the skull icon | S | not started |
| U11 | Damage and coin numbers: raw pooled labels ("-48K", "+120 ★") | `Field.number`, `Field.payOut` | always | Kit number style with the coin icon | S | not started |
| U12 | HUD popups: raw labels ("+N" beside the coin pill, "-❤") | `Hud.popup` | always | Same style as U11 | S | not started |
| U13 | Level HUD icons are glyphs and emoji: ❤ 👾 ⚔ ⏳ ⏸ ▶ ⏩ 🔒 ⚠ ★ | client `F/Defense` (`livesBar`, `fact`, `pauseButton`, `speedButton`, `announce`, `refresh`) | always | Atlas icons (heart, skull, power, clock and lock exist already; pause and speed are new) | S | not started |
| U14 | STATS and VISIT menu orbs show a letter: they are missing from the orb table | `Hud.ORBS`, `Hud.orb` | every session | Two atlas icons | S | not started |
| U15 | Running boosts are not on the HUD: their line sits in the hidden stat stack | `Hud.boostLabel`, `Hud.tick`, `Hud.setMode` | every session | Boost chips with an icon and m:ss (UI_VISION 4.1, row 8) | S | not started |
| U16 | The clicker's HUD is still built and always hidden: wave cluster and fuse, BUY CANNON, REBIRTH, "Tap anywhere to fire your cannon!", per-click chip, mastery bar, the big travel button | `Hud` top level (`stats`, `wave`, `actions`, `hint`, `travel`, `market`); hidden by `Hud.setMode(true)` and by `refresh` in `client/init.client.luau` | never (hidden) | Delete | S | not started |
| U17 | Story tracker and Huge badge: built, then forced invisible | client `F/Story` (`refreshTracker`), `F/Huge` (`refreshBadge`) | never (hidden) | Delete, or rebuild as kit pieces | S | not started |
| U18 | Story dialogue box: see-through raw frame with a stroke, a face made of dots, "TAP ▶" | client `F/Story` (`face`, `hat`, `box`, `present`) | every session | Kit sticker box, Captain Kaboom portrait image | M | not started |
| U19 | Trade request prompt: raw frame with a black stroke | client `F/Trading` (`prompt`, "TradeRequest") | sometimes | Kit card like the visit invite | S | not started |
| U20 | Toast icons are text glyphs: ✓ ✕ i | `Hud.TOAST_KINDS`, `Hud.runToasts` | always | Atlas icons; rarity colour for server-wide news | S | not started |
| U21 | Huge Shot text burst: raw label, black stroke | client `F/Huge` (`burst`) | rarely | Kit number style | S | not started |
| U22 | Tutorial pointers: "➜" and "▼" text glyphs, "N studs" | client `F/Tutorial` (`pointer`, `arrowLabel`, `distanceLabel`) | rarely (first session) | Arrow image | S | not started |

### Windows (all 21 use the kit shell `UI.window`; the contents do not)

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| U23 | TOWER: `UI.row` per kind with a colour dot, a number table on a dark inset, "★ price" as text, 🔒 | client `F/Towers` (`ensureKindRows`, `towerPage`, `statsPanel`, `refresh`) | every session (many times) | Tower cards with a picture, price buttons with the coin icon | M | not started |
| U24 | MINI CANNONS: text rows built by hand and destroyed on every change, a colour dot for a picture, five lines of legend | `Windows.refreshPets`, `Windows.hugeRow` | every session | Card grid and detail pane with real pictures (MINI_CANNON_REVAMP piece 7) | M | not started |
| U25 | WORLDS: `UI.row` x 12 and the REBIRTH row, 🔒 and 🏝️ on buttons, a colour dot per world | `Windows` (`worldRows`, `rebirthRow`, `refreshWorlds`, `refreshRebirth`) | every session | World cards with a planet picture and a progress bar | M | not started |
| U26 | MISSIONS: `UI.row`, progress as text, 💎 | `Windows` (`missionRows`, `refreshMissions`) | every session | Cards with `UI.bar` and a gem chip | S | not started |
| U27 | DAILY REWARDS: seven text boxes | `Windows` (`dayBoxes`, `refreshDaily`) | every session | Day cards | S | not started |
| U28 | GAME PASSES (the STORE): `UI.row`, "99 R$" as text | `Windows.ensurePassRows`, `refreshStore` | sometimes | Premium cards | S | not started |
| U29 | SHOP: `UI.row`, emoji prices, 💎 and 🎃 headings | `Windows.shopRow`, `refreshShop`, `Windows.tick` | sometimes | Hero card and item cards | M | not started |
| U30 | TOP PLAYERS: a text blob per column | `Windows` (`boardColumns`, `refreshTop`) | sometimes | Ranked rows with headshots | M | not started |
| U31 | LOOT: its own card and tile builders, a coloured pill for the picture, 🔒 🍀 | `Loot.cardAt`, `tileFor`, `emblem` | sometimes | `UI.card`; egg and crate pictures | M | not started |
| U32 | INDEX: a text grid with 18 px dots and ✅ | client `F/Huge` (`build`, `grid`, `refresh`) | sometimes | Picture cards and silhouettes | M | not started |
| U33 | BACKPACK: `UI.row` and `UI.header`, "R$" as text | client `F/Backpack` (`addRow`, `bundleRows`) | sometimes | Item cards (icon sheet C) | M | not started |
| U34 | AMMO: hand-built rows, colour dots | client `F/Ammo` (`panels`, `rows`) | sometimes | Ammo cards (icon sheet E) | M | not started |
| U35 | CRATES: hand-built rows, a crate drawn from frames with a "?", a plain text loot list as fallback | client `F/Crates` (`rows`, `lineAt`) | sometimes | Crate cards with crate pictures | M | not started |
| U36 | STORY: buttons as the chapter list, hand-built quest rows, ✓ ▶ • 🎁 🔒, progress as text | client `F/Story` (`chapterButtons`, `questRows`, `refreshWindow`) | sometimes | Chapter cards, `UI.bar` | M | not started |
| U37 | TRADE: players as `UI.row` with a hue dot instead of a headshot; offers and backpack as swatches; raw black strokes | client `F/Trading` (`playerRow`, `offerRow`, `cell`, `swatch`, `historyRow`) | sometimes | Cards and headshots | L | not started |
| U38 | ENCHANT and FUSE: `UI.row` lists, buttons as machine slots, results as a text line | client `F/Enchant` (`rowFor`, `panel`, `block`), `F/Fuse` (`slots`, `rowFor`) | sometimes | Cards with pictures | M | not started |
| U39 | MASTERY, ISLAND SHOP, VISIT: `UI.row` lists (VISIT with a hue dot per player) | client `F/Mastery` (`cards`), `F/IslandShop` (`rows`), `F/Visit` (`playerRow`) | sometimes | Cards | M | not started |
| U40 | STATS: its own cards made from kit pieces; emoji on the discs | client `F/Stats` (`card`, `lineList`, `LOOKS`, `TILES`) | sometimes | Swap the emoji for atlas icons | S | in progress |
| U41 | Event prize card: text on a black overlay | client `F/Event` (`showGems`) | rarely | Kit card | S | not started |

### Across every screen

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| U42 | Kit pieces the spec names that do not exist: `UI.card`, `UI.tabs` (four windows fake tabs with recoloured buttons), `UI.confirm`, `UI.sound`, a price piece (icon plus number) | `client/UI.luau` | always | Build them before the window work | M | not started |
| U43 | Emoji as icons. Currencies are 💰 💎 🍬 in every window, sign and price button, while the HUD pills use the atlas; coins are "★" in some places and "💰" in others. 🔒 ❤ 🍀 💀 🥚 ⏱ 🎁 🏆 ✓ are typed although the atlas has those icons. `UI.icon` is called only from `Hud` and `UI.pill` | `Windows`, `Loot`, `Market` (`ICONS` tables); client `F/Ammo`, `Crates`, `IslandShop`, `Enchant`, `Mastery`, `Story`, `Stats`, `Defense`, `Towers`, `Tutorial`, `Visit`, `Trading`, `Fuse`; `shared/Features/Crates` (`Currency`), `Ammo`, `Story` (`rewardText`), `Tutorial`, `Event`; `Marketplace.CURRENCY_ICONS` | always | Atlas icons through the price piece | M | not started |
| U44 | Colours outside `UI.Colors`: `Loot` (`NEUTRAL`, `MYSTERY_BACK`, `SILHOUETTE`, `LUCK_GREEN`), `F/Trading` (`GIVE_COLOR`, `GET_COLOR`, `BLACK`), `F/Ammo` (`MUTED`), the same lilac three times (`Windows.ENCHANT_COLOR`, `MAGIC` in `F/Enchant` and `F/Fuse`), `Hud.ORBS` and `Hud.WORLD_ACCENTS` (6 of 12 worlds), `Market.PROMPT_LOOK`, `Field` (`ICE`, `FIRE`), pure black overlays (`Effects.OVERLAY_COLOR`, `F/CrateOpening`, `F/Event`). The colours passed to `Hud.addMenuButton` are ignored for every orb in `Hud.ORBS` | as listed | sometimes | Tokens in `UI.Colors`; ink instead of black | S | not started |
| U45 | Text sizing: the old scaled `UI.text` is still called about 145 times; fixed-size `UI.label` is used in 9 files | all client files | always | Goes away as each window moves to cards | L | in progress |
| U46 | World and Halloween theming of the UI is not built (`UI.Theme`, `UI.setWorld`, slime drips, Creepster titles). The level HUD tints its tab from `world.floor` | `client/UI.luau`; client `F/Defense` (`refresh`) | every session | UI_VISION section 6 | M | not started (the event ends 1 Nov 2026) |

## 4. Placeholder effects

| ID | What it is | Where | Seen | Replace with | Size | Status |
|---|---|---|---|---|---|---|
| E1 | Tower shots: a neon ball, a lobbed ball, a block shard, a swelling fire ball, two blocks of lightning, a thin tracer block. No muzzle flash, no recoil, no trail | `Field.fire`, `Field.zap`, `Field.stepShots`, `Field.lookOf` | always | Mesh projectile with a Trail, muzzle flash, turret kick | M | not started |
| E2 | Hits: a neon ball that swells and fades; a flat neon ring for splash | `Field.puff`, `Field.ring`, `Field.land` | always | Particle bursts per look, a ground ring decal | M | not started |
| E3 | Slowed and burning: a colour tint only | `Field.paint` | always | Frost and flame particles on the monster | S | not started. **Unverified** how the tint looks on the Blender creatures |
| E4 | Death: one swelling neon ball and 8 sparks; the model is gone at once. A boss dies the same way with 30 sparks | `Field.remove`, `Field.spark` | always | Squash and pop, textured particles, coin burst; a boss moment (shake, flash) | M | not started |
| E5 | Spawn and leak: monsters just appear at the portal and are simply gone at the gate. A lost life is a bar flash and "-❤" | `Field.onField`, `Field.remove`; client `F/Defense` (`ctx.on("defense")`) | always | Portal puff; gate hit flash, red screen edge | S | not started |
| E6 | Monster movement: the whole model hops on a sine and turns. No animation (the walk in `tools/blender/wave_walk.py` is a preview only) | `Field.walk` | always | Waddle, float or slither per archetype in code, or baked animations | M | not started |
| E7 | Mini cannon shots: a neon ball tweened for 0.12 s; the hit is a size pulse of one part | `Effects.shoot`, `Effects.shootAt`, `Effects.pulse`, `Effects.firePets` | always | Muzzle flash, bounce on firing, a small trail | S | not started. **Unverified**: the pulse resizes only the primary part of a modelled creature |
| E8 | Mini cannons following: a glide and a sine bob; they never look at what they shoot | `Effects.updatePets` | always | Hop or waddle, look at the target (MINI_CANNON_REVAMP piece 8) | S | not started |
| E9 | Huge Shot: a big neon ball with a light, it swells and fades, a Highlight flash, a text burst | `Effects.hugeShot`; client `F/Huge` (`burst`) | rarely | Shockwave particles, screen shake | S | not started |
| E10 | Hatch reveal: a pill-shaped frame in the egg's colour shakes 6 times, turns the mini cannon's colour, three lines of text. No egg, no picture of what hatched, no rays, confetti, flash or sound. The egg on the stand does nothing | `Effects.hatch` (`cards`, `overlay`) | every session | The timeline in UI_VISION section 5 (MINI_CANNON_REVAMP piece 6) | M | not started |
| E11 | Crate opening: the whole sequence exists, but the crate is drawn from frames, a reward is a colour disc with an emoji, confetti is 26 squares, rays are 6 bars, and all six sounds are silent | client `F/CrateOpening` (`crateFrame`, `cards`, `burst`, `perform`, `SOUNDS`) | sometimes | Crate and reward pictures, sounds | M | in progress |
| E12 | Level cleared, level failed, boss arriving, rebirth: one text banner for 1.8 s | client `F/Defense` (`announce`, `ctx.on("defense")`) | always (every level) | Stamp, confetti, coin burst, sound; a boss intro | S | not started |
| E13 | Tower built, upgraded, new tier, sold: the model appears, swaps or vanishes at once, and a toast says so | `Plots.setTower`; `Game.actions.buildTower`, `upgradeTower`, `sellTower` | every session | Build poof and scale-in, upgrade sparkle, tier flash on the tower | S | not started |
| E14 | Coins: nothing to pick up. A kill shows "+N ★" as text and the pill shows "+N" | `Field.payOut`, `Field.killed`; `Hud.refresh` (`lastCoins`) | always | Coin discs fly from the monster to the coin pill; the number ticks up | M | not started. **Unverified**: the "+N" is placed by the hidden big coin pill, so it may float away from the visible one |
| E15 | Pad bought: the FOR SALE sign is deleted and the pad turns green | `Plots.dressPad`; `Game.actions.buyPad` | every session | Sign pop, pad flash | S | not started |
| E16 | Range ring: a see-through neon cylinder | client `F/Towers` (`ring`, `showRange`) | every session | Ring decal or dashed circle | S | not started |
| E17 | Travel: the character is moved at once. Teleporters and portals are still neon parts | `Game.setPlace`; `Plots.buildTeleporter`; `Marketplace.buildPortal`, `Islands.buildPortal` | every session | Fade and whoosh; swirling portal particles | S | not started |
| E18 | News as toasts only: about 45 `notify` calls in `Game.luau` and more in every feature. World unlocked, boss defeated, first-clear gems, Veteran level, daily, mission and story claims, drops | `Game.notify` and its callers (`levelCleared`, `actions.*`); server `F/*` | always | Moments for the big six: world unlocked card, claim stamp with gems flying to the pill, drop reveal | M | not started |
| E19 | Results inside windows are a line of text: "NEW: ..." after enchanting, "FUSED: X!", TRADE COMPLETE, the offline claim just closes | client `F/Enchant` (`ctx.on("enchant")`), `F/Fuse` (`ctx.on("fuse")`), `F/Trading` (`donePane`), `F/Offline` (`claimButton`) | sometimes | Short reveal: stamp, picture, sparkle | M | not started |
| E20 | Tutorial marker: a neon cylinder of light and a "▼" | client `F/Tutorial` (`beam`, `arrow`, `animate`) | rarely (first session) | Arrow mesh and a ground ring | S | not started |
| E21 | No life in the world: fountain water is a still disc, flags do not move, no snow, embers or spores in any world | `Marketplace.buildStatue` (Water); `Plots.THEMES` | always | Ambient emitters per world, moving water | M | not started |
| E22 | UI motion from the spec is missing: no breathing or shine on buttons you can afford, no counter tick, no fail shake, no stamp, no reduced-motion switch | `UI.Motion` (press, release, pop, glide only), `UI.button` | always | UI_VISION section 5 | M | not started |

## Phases

Ordered by how much of the screen time each one fixes per unit of work. Every line is one sitting unless it
says otherwise. IDs point at the tables above.

### Phase 1: sky, light and sound (always on, no modelling)

- D3: open the place in Studio and note what Lighting already holds (S)
- D1, D2, D4: `Sky`, Atmosphere, Bloom and clouds for Earth and the marketplace, read from the `sky` tables `Effects.updateLighting` already uses (S)
- D1, D2: the other 11 worlds and Halloween, four worlds a sitting (M)
- D13, U42: `UI.sound`, then press, error, window open and close, toast (S)
- D13: fight sounds: a shot per look, hit, pop, leak, level cleared, level failed, boss warning (S)
- D14: one music loop per place (S)
- E11: fill the six crate sounds (S)
- D15: particle textures for death sparks and the Huge aura (S)
- D9, D10, D7: switch off health bar and backpack, set a cursor, colour the chat (S)
- D11, D12, U9: loading screen (M)

### Phase 2: the fight (always on, effects only)

- E1, M9: projectiles with trails, muzzle flash, turret kick: ball, shell, shard (S), then flame, lightning, tracer (S)
- E2, E3: hit bursts, frost and fire on monsters (S)
- E4, E14: death pop with a coin burst flying to the pill (M)
- E5: portal puff and gate hit (S)
- U10, U11, U12: HP bar and numbers in kit style (S)
- E12: banners become a stamp with confetti; boss intro (S)
- E6: movement per archetype (M)
- E7, E8, M10: mini cannon shots and bounce (S)
- M4: giants use their own monster's model, scaled (S, code only)

### Phase 3: towers and pads (always on, Blender)

- M1: template lookup in `Models.tower` with the parts as fallback (S)
- M1, M2: models two a sitting: cannon and gatling, mortar and sniper, frost and flame, tesla and rocket (L in all)
- M1: tier look: tint zones, trim per step, plinth per rank (M)
- M13, E15: pad model with three states (S)
- U1, M14, U2, U3: `Build.sign`, then one sign per pad, the gate name and the teleporter signs (S)
- E13, E16: build, upgrade and sell effects, range ring (S)

### Phase 4: mini cannons, eggs and the hatch (in progress today)

- M6, M7, M8: `Models.mini` and its three call sites (M, in progress)
- M25: marketplace egg models and the stand (M, in progress)
- U5: egg stand sign as a sticker card (S)
- E10: hatch reveal (M)
- U42, U24, U32: `UI.card`, then MINI CANNONS and INDEX as picture cards (M)
- M6: world-egg mini cannons, Earth's 10 first, then a world a sitting (L in all)

### Phase 5: your base (always on, Blender kit, Earth first)

- M12, M11: path tiles and ground (M)
- M15, M16: gatehouse and gate (M)
- M17, M18, M20: portal arch, fence, lamp (S)
- M19: skyline and hills (M)
- M21, E17: teleporters and a travel fade (S)
- M22: Earth's tree, then one prop kind a sitting (M in all)
- E21: ambient particles for Earth (S)

### Phase 6: everyday windows and HUD leftovers (every session, kit work)

- U42: `UI.tabs`, price piece, `UI.confirm` (S)
- U43, U13, U20: emoji to the 32 atlas icons that exist (S); icon sheet C for the rest (M)
- U23: TOWER (M)
- U25: WORLDS (M)
- U26, U27, U28: MISSIONS, DAILY, STORE (S each)
- U14, U15, U16, U17: orb icons, boost chips, delete the hidden clicker HUD (S)
- U18: dialogue box with a Captain Kaboom portrait (S)
- E22: breathing buttons, counter tick, fail shake (S)

### Phase 7: Earth island, then the marketplace (every session to sometimes)

- M26, M30, M31: Earth island (M, done 2026-10-05)
- M29: statues cloned from the creature templates (S, code only; done 2026-10-05: `Islands.buildStatue` passes the monster's name)
- M27, M28, M34: one portal model and one stall model for every place (S)
- U4, U7, U8: `Build.sign` on every remaining sign; fix "BACK TO YOUR CANNON" (M)
- M38: fountain and golden cannon (M)
- M36, M35, M37: houses, three sittings; ground and trees (L in all)
- M40, U6, M41, M42, M43: boards with ranked rows, chest, notice boards, trading plaza (M)
- M44, M45, M46, M47: forge, crate stand, showcase, Captain Kaboom (M)
- M32, M33: shrine, enchanting table, fusion machine (S each)

### Phase 8: later worlds, feature windows, polish (sometimes to rarely)

- M3, M4: monsters world by world: 5 monsters and 2 bosses a sitting, 11 worlds (L in all)
- M26, M22: islands and base props for worlds 2 to 12 (M)
- U29 to U39: one window a sitting: SHOP, TOP PLAYERS, LOOT, BACKPACK, AMMO, CRATES, STORY, ENCHANT and FUSE, MASTERY and ISLAND SHOP and VISIT, then TRADE (L in all)
- E11, E18, E19, E9: crate art, the six big moments, window results, Huge Shot (M)
- U46, U44: world and Halloween theming, colour tokens (M)
- U19, U21, U22, U40, U41, E20, M23, M24, M31, M39, D19: small leftovers (S each)
- D6, D20: avatar animations, game icon and thumbnails (M)

In no phase: M5 and D5 (done); D8, D16, D17, D18 (Roblox defaults kept on purpose); U45 (shrinks by itself as
windows move to cards).

## Could not verify from the code

- **Skybox, atmosphere, lighting technology** (D1 to D3): the place file is not in the repository. Nothing in `src` creates a `Sky` or any post effect.
- **`ReplicatedStorage.Creatures`** (M4, section 0): the templates live in the place file. Without that folder every monster is parts again, with no warning.
- **Tint and pulse on the Blender creatures** (E3, E7): written for single-colour parts; look at a slowed, a burning and a shot monster in Studio.
- **The coin "+N" popup** (E14): it is placed from the hidden big coin pill; check where it lands.
- **Game icon and thumbnails** (D20): only concept art is in the repository.
- **Counts of eggs and mini cannons** (29 and about 150) are taken from `docs/MINI_CANNON_REVAMP.md`, not recounted.
