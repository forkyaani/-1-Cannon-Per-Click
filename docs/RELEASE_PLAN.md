# Release plan: public on Saturday 10 October 2026

Written Monday 5 October 2026. Five days. This is the one list for the release: everything that has to
happen, in code, in Blender, in Studio and on Roblox. `docs/BUILD_QUEUE.md` stays the record of what was
decided and built, and `docs/VISUAL_AUDIT.md` the full inventory of what looks placeholder (the M, D, U and E
numbers below are its).

## 0. The three things that decide the date

1. **The balance is broken from the second world on, and that blocks the release more than any model.**
   `python3 tools/balance/sim.py` on 5 October, the ordinary player, every system on: Earth 1:12, the Moon
   **12:48**, Mars **92 hours**, Neptune **367 hours**, stuck in the fifth world after 600 hours. The target is
   about 44 hours for the whole game (`docs/BALANCE.md`, section 1). Since mini cannons became flat DPS their
   share of the growth is gone after Earth. Nothing was retuned. Task A1.
2. **Not everything can be modelled by Saturday, and it does not need to be.** 147 mini cannons, 24 eggs,
   79 monsters and bosses, 11 islands, the marketplace and the whole base are still parts. Whatever has no
   model falls back to the part-built one by itself (`Models.mini`, `Models.monster`, `Islands.dressFor`), so
   no missing model can break the game. The plan models what a player sees on the first day and ships the
   rest in order, world by world, after the release.
3. **The models are not in the repository.** The four folders the game reads (`ReplicatedStorage.MiniCannons`,
   `EggModels`, `IslandModels`, `Creatures`) exist only in the published place. A place built from `src` with
   Rojo has none of them, and publishing one over the live place deletes them. Task R2.

## 1. How the two of us work on this

- **This file is the list.** To take a task, put your name in its Owner cell and push that one-line change to
  `main` before starting, so the other sees it. When it is done, set Status to `done` with the date. A task
  with no owner on Wednesday morning is nobody's: say so in the chat.
- **Git.** `main` is what is published. Work on a branch named `<who>/<task id>` (`victor/C3`), open a pull
  request, the other one reads it, merge. Small fixes to docs and this file go straight to `main`. Pull before
  you start, every time. Never force-push `main`.
- **Before every push:** `for t in tools/emu/tests/*.luau; do case $t in *.pre.luau|*_prelude*) ;; *) python3
  tools/emu/run.py --all-features $t || break;; esac; done` and `python3 tools/luau_check.py` on what changed.
- **One place file.** The live game is the Roblox place `80923792816716` (experience `10769534537`, owned by
  the group Astral Crafts, `230235107`). Open it from Studio's Experiences list, never from an `.rbxl` on
  disk. Until R2 is done, code reaches it with `rojo serve` and the Rojo plugin, which syncs `src` and
  leaves the models alone; `rojo build` plus publish would delete them.
- **One publisher at a time.** Say "publishing" in the chat first. Every publish gets a note with the task ids
  (File, Publish to Roblox with Notes).
- **Team Create is on**, so both can be in the place at once. Scripts come from the repository only: never
  edit a script in Studio, the next sync overwrites it.
- **Where things are:** code in `src`, Blender scripts in `tools/blender`, their output in `assets/models`,
  Studio helpers in `tools/studio`, tests in `tools/emu/tests`, the balance simulator in `tools/balance`.

## 2. Rules

- **Art freeze: Thursday 8 October, 23:59.** After it only renders for the game page.
- **Code freeze: Friday 9 October, 18:00.** After it only fixes for what Friday's play tests find.
- **Done means** merged to `main`, in the published place, and looked at in a Studio play test. For a model
  also: its FBX and script committed and imported with the steps of section 7.
- **No new features this week.** Anything not in this file waits.
- **Late is cut, not pushed.** A P0 task that is not done at its freeze ships as it is and moves to section
  8. Only A1 and the gates of section 6 can move the date.
- **P0** ships on Saturday or the release moves. **P1** ships if it is done by its freeze. **P2** is after.

## 3. Every task

Status is `open`, `doing`, `done <date>` or `cut`. Owner is empty until somebody takes it.

### A. Balance and economy

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| A1 | P0 | Retune so the game is playable past Earth: `Config.PetDps`, the egg curve, `Config.TowerCurve` (`tools/balance/tune.py`, `fit.py`) | `sim.py`: the Moon under 2 hours, Mars under 2:30, all twelve worlds between 40 and 60 hours | | open |
| A2 | P0 | `docs/BALANCE.md` rewritten from the new run; its sections 1, 3 and 4 are out of date since the flat DPS change | the document's numbers are the simulator's | | open |
| A3 | P0 | Decide what Mastery Rapid and the Silver tier's Rapid Fire do. Both are cosmetic since Quick Draw went and Rapid is still sold for gems (Yaani's call: remove and refund, or a new meaning) | no track or perk that does nothing is on sale | | open |
| A4 | P0 | Things the simulator does not know and nobody has sized for the new core: ammo, powerups and the 2x boosts are still the clicker's numbers (`docs/BALANCE.md`, section 5) | each is in `sim.py` or checked by hand against a level's worth of damage | | open |
| A5 | P0 | `docs/GEMS.md`, "before launch": gems named the same on every screen; rebirth's gem reward capped; slot prices 250 / 750 / 2,000; the Gem Egg and the weekly Exclusives scale with the player. Written for the clicker: check each against today's code first | each line marked built or not needed in `docs/GEMS.md` | | open |
| A6 | P1 | Offline earnings in the simulator (they are not measured against the pace floor) and an "offline coins" tile in STATS | `sim.py --offline`; the tile shows | | open |
| A7 | P0 | Decide: are gems sold for Robux at launch? Nothing sells them today, and `docs/GEMS.md` puts the gem packs after launch. The plan assumes **no**: launch revenue is the 6 passes and 6 products of section C | written here | | open |

### B. Code

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| B1 | P0 | The six `.conflict` files (`Game`, `Config`, `Data`, `Effects`, `ARCHITECTURE.md`, `BUILD_QUEUE.md`): fold in what is missing from the live file, or delete | none left in the repository | | open |
| B2 | P0 | Server size. The place allows 50 players and there are 12 bases; over twelve, bases are shared and the second owner cannot invite | the experience's maximum is 12 | | open |
| B3 | P0 | Never seen in Studio (built 5 Oct): the base's surround and the camera against its unseen walls, the two teleporters beside the arrival, the lobby during a slow load, the level panel's bottom row on a phone, a guest landing on a base 2,000 studs away | each looked at; what is wrong is a line in H3 | | open |
| B4 | P1 | A guest on somebody's base sees the marketplace's sky, not the host's world's | the host's sky | | open |
| B5 | P0 | First join: the level keeps running behind the welcome cards; the cards' and the marker's size on a real phone | checked on a phone with a new save | | open |
| B6 | P0 | Loading screen in `ReplicatedFirst` (not mapped in `default.project.json` today), held until the base has opened, which also hides the "Opening your base..." room (D11, D12, M24) | no grey room and no Roblox default screen on joining | | open |
| B7 | P0 | Sound hooks: `UI.sound` does not exist and the only sounds in the game are six crate sounds with id 0 (D13). The hooks are listed in `docs/UI_VISION.md`, "Sound hooks" | every hook plays what F1 uploads | | open |
| B8 | P1 | Health bar and backpack switched off (D9); particles with their own texture (D15) | not on screen | | open |
| B9 | P0 | Paid random items: the odds are shown for every egg, crate and enchant roll, and `PolicyService` is asked before each paid roll (it is in Crates and Enchant; check the x3 Luck pass and the eggs) | a restricted test account cannot buy a random item | | open |
| B10 | P0 | Halloween event end to end: candy drops, the four eggs, the candy shop, the event leaderboard, the top five's rewards paid once on the next join, everything gone after `Config.Halloween.endsAt` (1 November 2026, 00:00 UTC) | played with a test end time five minutes away | | open |
| B11 | P0 | The first save of the real game. The live experience already holds test saves from 5 October in `PlayerData_v4`. Decide: wipe them or rename the store | no tester starts the release at level 28 | | open |
| B12 | P0 | Marketplace wear code for D5: the model over the part-built square, the way `Islands.wear` does it | every prompt and sign of `Marketplace.luau` stands where the model shows it | | open |
| B13 | P0 | `Models.tower` and the base (`Plots.luau`) using the models of D6 and D7, with the part-built ones as the fall back | `tools/emu/tests/defense_client.luau` passes; aiming and the muzzle unchanged | | open |
| B14 | P1 | Loot viewer and the Huge showcase using `Models.mini` (M7, M8) | one mini cannon builder, not three | | open |
| B15 | P0 | The group promises codes ("Exclusive codes" in its description) and the game has no way to redeem one. Build a small code box, or take the line out of the group | the promise and the game agree | | open |
| B16 | P1 | Analytics: the funnel of the first ten minutes (joined, welcome done, first tower, level 5, first hatch, level 10, marketplace) and every purchase | visible in Creator Hub | | open |
| B17 | P2 | STATS: the missing sources. Badges. Own run and idle animations (D6). Chat colours (D7) | | | open |

### C. Robux: passes and products

Every one has id 0 today, which means not on sale. Each needs to be created in Creator Hub under the
experience, given an icon (E4), and its id pasted into the file named.

| # | P | Task | Robux | Where the id goes | Owner | Status |
|---|---|---|---|---|---|---|
| C1 | P0 | Pass: x3 Egg Opener | 349 | `Config.Passes.tripleHatch` | | open |
| C2 | P0 | Pass: x3 Luck | 449 | `Config.Passes.tripleLuck` | | open |
| C3 | P0 | Pass: +3 Mini Cannon Slots | 299 | `Config.Passes.slots3` | | open |
| C4 | P0 | Pass: +5 Mini Cannon Slots | 549 | `Config.Passes.slots5` | | open |
| C5 | P0 | Pass: +500 Mini Cannon Storage | 249 | `Config.Passes.storage500` | | open |
| C6 | P0 | Pass: 2x and 3x Speed | 99 | `Config.Passes.gameSpeed` | | open |
| C7 | P0 | Product: Shiny Enchantment Key | 149 | `Enchant.ShinyProduct` (`src/shared/Features/Enchant.luau`) | | open |
| C8 | P0 | Product: the Robux crate | 99 | `src/shared/Features/Crates.luau`, the `robux` price | | open |
| C9 | P0 | Product: Boost Pack | 49 | `src/shared/Features/Powerups.luau` | | open |
| C10 | P0 | Product: Boss Buster Pack | 129 | same | | open |
| C11 | P0 | Product: Mega Pack | 399 | same | | open |
| C12 | P0 | Product: Candy Pack (event) | 79 | same | | open |
| C13 | P0 | Buy each once on the live place with a real account: the pass works at once and after rejoining; a product is granted once, and once only when the receipt is retried (`Game.processReceipt`) | 12 ticks | | open |
| C14 | P0 | Group revenue: who gets what share of Astral Crafts' Robux (Victor and Yaani decide; set in the group's payouts) | set | | open |

### D. Blender

All Blender work is code: one script per set in `tools/blender`, run headless, exporting FBX to
`assets/models`. In the place on 5 October: Earth's island, Earth's five monsters and one boss model, the Gem
Egg and the four Halloween eggs, and their 25 mini cannons.

What is left, in all:

| Set | In the game | Left | Script |
|---|---|---|---|
| Mini cannons: coin eggs (12 worlds x 2 eggs x 5) | 0 | **120** | `minis.py` (a recipe each) |
| Mini cannons: Gem Egg and the four Halloween eggs | 25 | 0 | `minis.py` |
| Mini cannons: Exclusive (shops, daily, crates) | 0 | 11 | `minis.py` |
| Mini cannons: Secret (crate jackpots, hidden) | 0 | 7 | `minis.py` |
| Huges | 0 | 9 | `minis.py`, at 4x with its own extras |
| Eggs: coin eggs | 0 | 24 | `minis.py` |
| Monsters (5 a world) | 5 (Earth) | 55 | `wave.py`, one file per world |
| Bosses (a mid boss and a final boss a world) | 1 shared `Boss` | 24 | `boss_king.py` as the recipe |
| World islands | 1 (Earth) | 11 | `earth_island.py` as the template |
| Island machines: Mastery Shrine, Enchanting Table, Fusion Machine (M32, M33) | 0 | 3 | new |
| Marketplace town (M34 to M47) | 0 | 1 set | `marketplace.py` is written; its FBX was never exported |
| Base kit (M11 to M22), tinted for 12 worlds | 0 | 1 kit | new |
| Towers: 8 kinds (M1, M2) | 0 | 8 | new |
| Shots, crates, daily chest, Ammo Forge, Captain Kaboom, Huge pedestal (M9, M10, M41, M44 to M47) | 0 | 6 sets | new |

This week's tasks:

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| D1 | P0 | Blender on the machine that builds; every script in `tools/blender` re-run from clean | each writes the FBX that is committed, or the difference is explained | | open |
| D2 | P0 | Monsters as one mesh each with vertex colours, the way `minis.py` joins a mini cannon. Earth's six are 189 MeshParts (about 30 a monster, 10 to 20 monsters on screen), and their colours are material colours, which the importer drops | `wave.py` and `boss_king.py` export one mesh a monster; `COLOURS` is gone from `organize_imports.luau` | | open |
| D3 | P0 | Earth's coin eggs: Basic Egg and Forest Egg and their 10 mini cannons. The first thing every player hatches, and parts today | in the place; the hatch reveal checked | | open |
| D4 | P0 | Earth's own bosses: Ogre Chief and Earth Titan (both are the shared `Boss` today); giants use their monster's model (M4) | both fought | | open |
| D5 | P0 | Marketplace: export `marketplace.fbx` (with B12) | in the place | | open |
| D6 | P0 | Towers: the 8 kinds as models with tint zones, so the 60 tiers stay recolours (with B13) | in a fight | | open |
| D7 | P0 | Base kit, Earth's look: gatehouse and gate, monster portal, pad in three states, FOR SALE sign, path tiles, fence, lamp, teleporter (M13 to M18, M20, M21; with B13) | a new player's first screen has no bare slab in it | | open |
| D8 | P1 | Base ground, skyline and Earth's props (M11, M12, M19, M22) | the same, seen from the gate | | open |
| D9 | P1 | Marketplace set pieces: crates, daily chest, Ammo Forge, Huge pedestal, Captain Kaboom (M41, M44 to M47) | in the place | | open |
| D10 | P0 | The Moon: island, 5 monsters, 2 bosses, Moon Egg and Comet Egg, 10 mini cannons, the base's tint and props | island visited, a boss fought | | open |
| D11 | P0 | Mars: the same, and the Mastery Shrine (M32) | the same | | open |
| D12 | P1 | The 9 Huges | the showcase shows one | | open |
| D13 | P1 | The 11 Exclusive mini cannons (seven are sold in the weekly and Halloween shops on day one) | the shop's preview shows the model | | open |
| D14 | P1 | Shots: a cannonball with a trail for mini cannons, one mesh per tower look (M9, M10) | in a fight | | open |
| D15 | P0 | Renders for the page from the real models: the game icon and three thumbnails (D20) | four image files in `assets` | | open |

### E. Interface

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| E1 | P0 | Every window and the HUD on a phone, portrait refused or handled, the smallest screen Roblox allows: nothing cut off, every button reachable with a thumb | a screenshot of each window from a phone | | open |
| E2 | P1 | Windows rebuilt to their mockups (`docs/UI_VISION.md`, task 5): MINI CANNONS and STORE first, then SHOP, MISSIONS, DAILY, WORLDS, TOP PLAYERS | each matches its picture in `docs/ui-vision` | | open |
| E3 | P1 | Reward moments: hatch reveal, level clear, coin flight (task 7) | seen | | open |
| E4 | P0 | Icons: 6 pass icons and 6 product icons for Creator Hub (section C); icon sheets C, D and E for boosts, items, crates, world medallions and ammo (task 6) are P1 | uploaded | | open |
| E5 | P1 | World signs through one kit sign instead of raw white labels (U1 to U4) | the base's and marketplace's signs | | open |
| E6 | P1 | Skybox, atmosphere and clouds for Earth, the marketplace and the Halloween look (D1, D2, D4); lighting technology set once in Studio (D3) | not Roblox's default sky | | open |

### F. Sound

The game is silent today.

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| F1 | P0 | Effects, uploaded under Astral Crafts or taken from Roblox's licensed library: button, purchase, tower shot (one per look), mini cannon shot, monster death, boss arrives, boss dies, level cleared, level failed, hatch roll and reveal by rarity, crate opening (six ids in `CrateOpening.SOUNDS`), coin pick-up, error | ids in the code, heard on a phone | | open |
| F2 | P0 | Music: one loop each for the base, the marketplace and an island, and the Halloween one | plays, loops cleanly, lowers in windows | | open |
| F3 | P0 | A music and a sound switch in settings, saved | both work | | open |

### G. Roblox: the experience, the group, the accounts

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| G1 | P0 | **Tuesday, not Saturday:** confirm in Creator Hub that the experience can be made public. The maturity and compliance questionnaire, and whatever account verification Roblox asks of the publisher, can take days | Creator Hub shows nothing missing | | open |
| G2 | P0 | The page: name `+1 Cannon Per Click`, description, genre, devices (phone, tablet, computer; console only if E1 was done on one) | filled | | open |
| G3 | P0 | Icon and three thumbnails uploaded (D15). They are moderated: upload on Friday morning at the latest | approved | | open |
| G4 | P0 | Settings: maximum players 12 (B2); "Studio Access to API Services" as needed; HTTP requests off; private servers on and free, or off (decide) | set | | open |
| G5 | P0 | The group: the description matches the game (B15); the icon is up; social links; who has which role. Yaani's Admin role can play, edit and publish since 5 October; nobody else can | checked | | open |
| G6 | P0 | Asset ownership. The UI atlases (`75982409729652`, `89091306681120`) were uploaded by a personal account: check they load in the group's experience for an account that is not the uploader, or upload them again under the group | the HUD's icons show for a stranger | | open |
| G7 | P1 | A second place or a copy of the experience for testing, so nothing is tried on the live one after Saturday | exists, and is where Rojo points by default | | open |
| G8 | P1 | The launch post in the group and wherever else (Victor and Yaani decide where); a trailer or a 20-second clip | posted on Saturday | | open |

### H. Testing

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| H1 | P0 | Every test in `tools/emu/tests` passes on `main`, every day | green | | open |
| H2 | P0 | Full play test, a new account, phone and computer: join, the welcome cards, the walkthrough, 10 levels, hatch, marketplace, an island, a pass, a product, leave and come back (offline earnings), rebirth after Earth's final boss | no red line in the Output | | open |
| H3 | P0 | The list of what H2, H4 and B3 found, here below, each line fixed or accepted by both | empty or accepted | | open |
| H4 | P0 | Two accounts at once: trading from start to finish, a visit by invitation and SEND HOME, the three leaderboards, the event board | done once | | open |
| H5 | P0 | A full server: 12 players, or as many accounts as can be found, each with 15 towers, on a phone | 30 frames a second or better; server heartbeat steady | | open |
| H6 | P0 | Saving: leave in the middle of a level, rejoin; join on a second device while the first is still in (the session lock should hold); close the server with players in it | nothing lost, nothing doubled | | open |
| H7 | P1 | An hour of real play by somebody who has never seen the game, watched without helping | notes | | open |

Found in play tests (H3):

- (nothing yet)

### R. Repository and pipeline

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| R1 | P0 | This plan on `main`; both of us can push | merged | Victor | done 5 Oct |
| R2 | P0 | Models into the repository: the four folders saved from Studio as `.rbxm` under `assets/roblox` and mapped in `default.project.json` | `rojo build` gives a place with the models; a play test of that file shows them | | open |
| R3 | P0 | `tools/studio/organize_imports.luau` for every world: monsters and bosses by a name table instead of Earth's six; worlds with two-word names (`The Sun`, `Crystal Belt`, `Robot Factory`, `Alien Jungle`, `Black Hole`, `The Big Bang`) | the Moon's files import with no edit to the script | | open |
| R4 | P0 | Rojo for both: `rokit install` works on both machines (`rokit.toml` pins Rojo 7.7.1), the Rojo plugin is in both Studios | both have synced a change | | open |
| R5 | P1 | A `README.md`: what the game is, how to run the tests, how to sync, how to import a model (section 7) | exists | | open |
| R6 | P1 | A check on every pull request that runs the tests (GitHub Actions; the tests need only Python 3) | a red cross on a broken pull request | | open |

## 4. Decisions only Victor and Yaani can make

Each blocks a task above. Write the answer here.

| # | Question | Blocks | Answer |
|---|---|---|---|
| 1 | Is it acceptable that worlds 4 to 12 are part-built on Saturday? The plan assumes yes | everything | |
| 2 | Mastery Rapid and Silver's Rapid Fire: remove and refund, or a new meaning? | A3 | |
| 3 | Gems for Robux at launch: no (the plan), or yes? | A7 | |
| 4 | Test saves in the live experience: wipe? | B11 | |
| 5 | Codes: build a code box, or drop the promise? | B15 | |
| 6 | Revenue split of the group | C14 | |
| 7 | Private servers: free, paid or off? | G4 | |
| 8 | Who owns which section this week? | every Owner cell | |

## 5. Day by day

### Tuesday 6 October: the blockers and the pipeline

A1, A2, A3 (balance). G1 (can it go public at all). D1, D2, R2, R3, R4 (the pipeline). B1 (conflict
files). D3 (Earth's eggs and mini cannons). Section 4's decisions, all eight.

### Wednesday 7 October: Earth and the base, finished; money in

D4 (Earth's bosses), D6 with B13 (towers), D7 (base kit), D5 with B12 (marketplace), D8 and D9 if there is
time. C1 to C12 with E4 (create every pass and product), A4, A5, A7, B2, B9, B11, B15. F1 and F2 chosen.

### Thursday 8 October: the Moon and Mars; sound and loading in; art freeze

D10, D11 (the Moon and Mars). D12 to D14 if there is time. B6 (loading screen), B7 with F1 to F3 (sound),
B10 (Halloween end to end), B5, B3, E1. **23:59 art freeze.**

### Friday 9 October: the page, the tests, code freeze

Morning: D15 and G3 (icon and thumbnails up for moderation), G2, G4, G5, G6. C13 (buy everything once).
H2, H4, H5, H6 (the play tests). **18:00 code freeze.** Evening: H3 only.

### Saturday 10 October: release

| # | Task |
|---|---|
| S1 | Morning: every gate of section 6, ticked by both |
| S2 | Publish the frozen place with the note "release". Write its version number here |
| S3 | Set the experience to public |
| S4 | Join from a phone on mobile data with a new account: the first ten minutes |
| S5 | Post (G8). Watch errors, the purchase log and the leaderboards for the first two hours. The roll back is the version before S2 (Studio, Version History) |

## 6. Gates: all must hold on Saturday morning

- [ ] `sim.py`: the Moon under 2 hours, the whole game between 40 and 60 hours (A1)
- [ ] Every test in `tools/emu/tests` passes on `main` (H1)
- [ ] `rojo build` from `main` gives the place that is published, models included (R2)
- [ ] No `.conflict` file in the repository (B1)
- [ ] A new account plays the first ten minutes on a phone with no error, with sound, and with no bare
      placeholder on screen (H2)
- [ ] All 6 passes and 6 products are on sale and each was bought once (C13)
- [ ] A restricted account cannot buy a random item, and every random item shows its odds (B9)
- [ ] The group reward pays once: 250 gems and +10% coins (`Config.Fan.groupId = 230235107`)
- [ ] Saves survive leaving, a second device and a server closing (H6); no test save is left (B11)
- [ ] The Halloween event is live and ends by itself (B10)
- [ ] Maximum players is 12 (B2)
- [ ] Icon, thumbnails and description are approved, and Creator Hub lets the experience go public (G1 to G3)
- [ ] Victor and Yaani can both publish; nobody else can (G5)
- [ ] H3's list is empty or every line is accepted

## 7. One model, from script to game

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
6. Save the changed folder to `assets/roblox` (R2), commit, publish.

Known traps, all met on 5 October: the importer keeps a mesh's origin but not which way it looks (the script
turns every pivot; Blender's front, -Y, arrives as -Z); it drops material colours (hence D2); and
"Set Pivot to Scene Origin" only helps with "Insert Using Scene Position" ticked.

## 8. After the release: the rest, in the order players reach it

One world a week keeps art ahead of an ordinary player; a world is its island, 5 monsters, 2 bosses, 2 eggs,
10 mini cannons and the base's tint and props.

| When | What |
|---|---|
| By Sunday 11 October | Neptune. Whatever of P1 was cut |
| Week of 12 October | The Sun, with the Enchanting Table and Fusion Machine (M33). The 7 Secret mini cannons. G7, R5, R6 |
| By Friday 23 October | `docs/GEMS.md`, "by Fri 23 Oct": gem packs, the Starter Pack, Second Wind, if decision 3 says so |
| Week of 19 October | The Void, Nebula. Skies for every world (E6) |
| 1 November | The Halloween event ends by itself: check it did, pay the top five, start on the next event with the same module |
| After | Crystal Belt, Robot Factory, Alien Jungle, Black Hole, The Big Bang: one a week. Then the rest of `docs/VISUAL_AUDIT.md`, `docs/GEMS.md` and `docs/UI_VISION.md` |
