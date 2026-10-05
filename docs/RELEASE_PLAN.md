# Release plan: public on Saturday 10 October 2026

Written Monday 5 October 2026. Five days. This is the one list for the release; `docs/BUILD_QUEUE.md` stays
the list for features and `docs/VISUAL_AUDIT.md` the full inventory of what looks placeholder (the M and D
numbers below are its).

## 0. The three things that decide the date

1. **The balance is broken from the second world on, and that blocks the release more than any model.**
   `python3 tools/balance/sim.py` on 5 October, the ordinary player, every system on: Earth 1:12, the Moon
   **12:48**, Mars **92 hours**, Neptune **367 hours**, stuck in the fifth world after 600 hours. The target is
   about 44 hours for the whole game (`docs/BALANCE.md`, section 1). Since mini cannons became flat DPS their
   share of the growth is gone after Earth. Nothing was retuned.
2. **Not everything can be modelled by Saturday, and it does not need to be.** 147 mini cannons, 24 eggs,
   79 monsters and bosses, 11 islands, the marketplace and the whole base are still parts. Whatever has no
   model falls back to the part-built one by itself (`Models.mini`, `Models.monster`, `Islands.dressFor`), so
   no missing model can break the game. The plan models what a player sees on the first day and ships the
   rest in order, world by world, after the release.
3. **The models are not in the repository.** The four folders the game reads (`ReplicatedStorage.MiniCannons`,
   `EggModels`, `IslandModels`, `Creatures`) exist only in the published place. A place built from `src` with
   Rojo has none of them, and publishing one over the live place deletes them.

## 1. Where the art stands

All Blender work is code: one script per set in `tools/blender`, run headless, exporting FBX to
`assets/models`. In the place on 5 October (imported and checked in a play test): Earth's island, Earth's five
monsters and one boss model, the Gem Egg and the four Halloween eggs, and their 25 mini cannons.

| Set | In the game | Left | Script |
|---|---|---|---|
| Mini cannons: coin eggs (12 worlds x 2 eggs x 5) | 0 | **120** | `minis.py` (a recipe each) |
| Mini cannons: Gem Egg and the four Halloween eggs | 25 | 0 | `minis.py` |
| Mini cannons: Exclusive (shops, daily, crates) | 0 | 11 | `minis.py` |
| Mini cannons: Secret (crate jackpots, hidden) | 0 | 7 | `minis.py` |
| Huges | 0 | 9 | `minis.py`, at 4x with its own extras |
| Eggs: coin eggs | 0 | 24 | `minis.py` |
| Eggs: Gem and Halloween | 5 | 0 | `minis.py` |
| Monsters (5 a world) | 5 (Earth) | 55 | `wave.py`, one file per world |
| Bosses (a mid boss and a final boss a world) | 1 shared `Boss` | 24 | `boss_king.py` as the recipe |
| World islands | 1 (Earth) | 11 | `earth_island.py` as the template |
| Island machines: Mastery Shrine, Enchanting Table, Fusion Machine (M32, M33) | 0 | 3 | new |
| Marketplace town (M34 to M47) | 0 | 1 set | `marketplace.py` is written; its FBX was never exported and no code wears it |
| Base: gatehouse, gate, monster portal, pads, FOR SALE sign, path, fence, lamps, teleporters, skyline, world props (M11 to M22) | 0 | 1 kit, tinted for 12 worlds | new |
| Towers: 8 kinds (M1, M2; the rocket has no shape of its own) | 0 | 8 | new |
| Shots, crates, daily chest, Ammo Forge, Captain Kaboom, Huge pedestal (M9, M10, M41, M44 to M47) | 0 | 6 sets | new |
| Game icon and thumbnails from the real models (D20) | concept art only | 1 icon, 3 thumbnails | renders from the scripts above |

## 2. Rules

- **Art freeze: Thursday 8 October, 23:59.** After it only renders for the game page.
- **Code freeze: Friday 9 October, 18:00.** After it only fixes for what Friday's play test finds.
- **A row is done when** its FBX and script are committed, it is imported with the steps of section 5, it was
  looked at in a Studio play test, and the place was published. Not when the render looks good.
- **No new features this week.** Anything not in this file waits for `docs/BUILD_QUEUE.md`.
- **Late is cut, not pushed.** A P0 row that is not done at its freeze ships as parts and moves to section 6.
  The only rows that can move the date are 2.1 and the gates of section 4.
- Every push runs `python3 tools/emu/run.py --all-features` on all of `tools/emu/tests/*.luau` first.

## 3. Day by day

P0 ships on Saturday or the release moves. P1 ships if it is done by its freeze.

### Tuesday 6 October: the blockers and the pipeline

| # | P | Task | Done when |
|---|---|---|---|
| 2.1 | P0 | Retune so the game is playable past Earth (`Config.PetDps`, the egg curve, `Config.TowerCurve`; `tools/balance/tune.py`) | `sim.py`: the Moon under 2 hours, Mars under 2:30, all twelve worlds between 40 and 60 hours; `docs/BALANCE.md` section 1 rewritten from the new run |
| 2.2 | P0 | Blender on the machine that builds, and every script in `tools/blender` re-run from clean | each script writes the FBX that is committed, byte for byte or explained |
| 2.3 | P0 | Models into the repository: the four folders saved as `.rbxm` under `assets/roblox`, mapped in `default.project.json` | `rojo build` gives a place with the models; a play test of that file shows them |
| 2.4 | P0 | Monsters as one mesh each with vertex colours, the way `minis.py` joins a mini cannon. Earth's six are 189 MeshParts today (about 30 a monster, 10 to 20 monsters on screen) and their colours are material colours, which the importer drops | `wave.py` and `boss_king.py` export one mesh a monster; `COLOURS` is gone from `organize_imports.luau`; 60 frames a second on a phone with 20 monsters out |
| 2.5 | P0 | `tools/studio/organize_imports.luau` for every world: monsters and bosses by a name table instead of Earth's six, worlds with two-word names (`The Sun`, `Crystal Belt`, `Robot Factory`, `Alien Jungle`, `Black Hole`, `The Big Bang`) | Moon's files import with no edit to the script |
| 2.6 | P0 | Earth's two coin eggs: Basic Egg and Forest Egg and their 10 mini cannons. They are the first thing every player hatches and they are parts today | in the place; hatch reveal checked |
| 2.7 | P0 | The six `.conflict` files: fold in what is missing or delete them | none left in the repository |

### Wednesday 7 October: Earth and the base, finished

| # | P | Task | Done when |
|---|---|---|---|
| 3.1 | P0 | Earth's own bosses: Ogre Chief and Earth Titan (both are the shared `Boss` today), and giants using their monster's model (M4) | both fought in a play test |
| 3.2 | P0 | Towers: the 8 kinds as models with tint zones, so the 60 tiers stay recolours (M1, M2) | `Models.tower` uses them; aiming and the muzzle unchanged in `tools/emu/tests/defense_client.luau` |
| 3.3 | P0 | Base kit, Earth's look: gatehouse and gate, monster portal, pad in three states, path tiles, fence, lamp, teleporter (M13 to M18, M20, M21) | a new player's first screen has no bare slab in it |
| 3.4 | P1 | Base ground, skyline and Earth's props (M11, M12, M19, M22) | the same, seen from the gate |
| 3.5 | P0 | Marketplace: export `marketplace.fbx`, write the wear code the way `Islands.wear` does it, import | every prompt and sign of `Marketplace.luau` still stands where the model shows it |
| 3.6 | P1 | Marketplace set pieces: crates, daily chest, Ammo Forge, Huge pedestal, Captain Kaboom (M41, M44 to M47) | in the place |
| 3.7 | P0 | The 6 game passes created in the experience, their ids in `Config.Passes` | each bought once in a Studio test with `Passes.setForTesting` off |

### Thursday 8 October: the Moon and Mars, then art freeze

After 2.1 an ordinary player finishes Earth in about 75 minutes and the Moon about 95 minutes later, so both
are reached on the first day.

| # | P | Task | Done when |
|---|---|---|---|
| 4.1 | P0 | The Moon: island, 5 monsters, 2 bosses, Moon Egg and Comet Egg, 10 mini cannons | in the place, island visited, a boss fought |
| 4.2 | P0 | Mars: island, 5 monsters, 2 bosses, Mars Egg and Dune Egg, 10 mini cannons, the Mastery Shrine (M32) | the same |
| 4.3 | P0 | Base kit tints and props for the Moon and Mars (`Plots.THEMES`) | both bases looked at |
| 4.4 | P1 | The 9 Huges and the showcase pedestal using `Models.mini` (M8) | the showcase shows one |
| 4.5 | P1 | The 11 Exclusive mini cannons (seven are sold in the weekly and Halloween shops on day one) | the shop's preview shows the model |
| 4.6 | P1 | Shots: a cannonball with a trail for mini cannons, one mesh per tower look (M9, M10) | in a fight |
| | | **23:59 art freeze** | |

### Friday 9 October: the page, the test, the freeze

| # | P | Task | Done when |
|---|---|---|---|
| 5.1 | P0 | Game icon and three thumbnails rendered from the real models (D20); the group icon is done | uploaded to the experience |
| 5.2 | P0 | The experience page: description, genre, the maturity questionnaire, devices | Creator Hub shows nothing missing to go public |
| 5.3 | P0 | Loading screen and the "Opening your base..." room hidden behind it (D11, D12, M24) | no grey room on joining |
| 5.4 | P0 | Sound: at least hatch, tower shot, boss kill, button, and one music loop a place (D13, D14). The game is silent today | heard on a phone |
| 5.5 | P0 | Full play test, a new account, phone and PC: join, the walkthrough, 10 levels, hatch, marketplace, island, a pass, leave and come back (offline earnings) | no red line in the Output; a list of what was found |
| 5.6 | P0 | Two players at once: trading, a visit by invitation, the leaderboards | done once from two accounts |
| | | **18:00 code freeze** | |
| 5.7 | P0 | Fix what 5.5 and 5.6 found. Nothing else | the list is empty or each line is accepted in writing here |

### Saturday 10 October: release

| # | Task |
|---|---|
| 6.1 | Morning: every gate of section 4, ticked by two people |
| 6.2 | Publish the frozen place. Note the version number here |
| 6.3 | Set the experience to public |
| 6.4 | Join from a phone on mobile data, a new account: the first ten minutes |
| 6.5 | Post in the group. Watch errors and the leaderboards for the first two hours; the last version before 6.2 is the roll back |

## 4. Gates: all must hold on Saturday morning

- [ ] `sim.py`: the Moon under 2 hours, the whole game between 40 and 60 hours (2.1)
- [ ] Every test in `tools/emu/tests` passes
- [ ] `rojo build` from `main` gives the same place that is published, models included (2.3)
- [x] No `.conflict` file in the repository (2.7)
- [ ] A new account plays the first ten minutes on a phone with no error and no bare placeholder on screen
- [ ] The 6 game passes are on sale and each gives what it says (3.7)
- [ ] The group reward pays once: 250 gems and +10% coins (`Config.Fan.groupId = 230235107`)
- [ ] Saves survive leaving and rejoining; the data store name is final (`PlayerData_v4`); "Studio Access to
      API Services" is off in the published settings unless it is needed
- [ ] The Halloween event is live and ends when `Config.Halloween.endsAt` says (1 November 2026, 00:00 UTC)
- [ ] Icon, thumbnails, description and the maturity questionnaire are in (5.1, 5.2)
- [ ] Yaani and Victor can both publish; nobody else can

## 5. One model, from script to game

1. Write or extend the script in `tools/blender`. One mesh per model, colours on the vertices
   (`colors_type="SRGB"`), named `mini_<id>`, `egg_<id>`, `<World>_<Piece>` or `<monster>_...`. Origins where
   the game wants the pivot: under the feet for an egg, the middle of the base for a landmark, the middle of
   the island on the ground for scenery.
2. `blender --background --python tools/blender/<script>.py -- assets/models/<folder>`. Commit the FBX, the
   `.blend` and the render.
3. In Studio, the published place, edit mode: File, Import. Tick **Insert Using Scene Position**. Creator
   **Astral Crafts**.
4. Run `tools/studio/organize_imports.luau` in the command bar. It prints what it found, for example
   `mini cannons 25/25, eggs 5/5, island pieces 13/13, creatures 6/6`.
5. Delete the raw import from the Workspace. Play test: which way it faces, where it stands, its size.
6. Save the changed folder to `assets/roblox` (2.3), commit, publish.

Known traps, all met on 5 October: the importer keeps a mesh's origin but not which way it looks (the script
turns every pivot; Blender's front, -Y, arrives as -Z); it drops material colours (hence 2.4); and
"Set Pivot to Scene Origin" only helps with "Insert Using Scene Position" ticked.

## 6. After the release: the rest, in the order players reach it

One world a week keeps art ahead of an ordinary player; a world is its island, 5 monsters, 2 bosses, 2 eggs,
10 mini cannons and the base's tint and props.

| When | What |
|---|---|
| By Sunday 11 October | Neptune. Whatever of P1 was cut |
| Week of 12 October | The Sun, with the Enchanting Table and Fusion Machine (M33). The 7 Secret mini cannons |
| Week of 19 October | The Void, Nebula. Skybox, atmosphere and clouds per world (D1, D2, D4) |
| Before 1 November | The Halloween event ends: its eggs and stalls leave the marketplace |
| After | Crystal Belt, Robot Factory, Alien Jungle, Black Hole, The Big Bang: one a week. Then the rest of `docs/VISUAL_AUDIT.md` |
