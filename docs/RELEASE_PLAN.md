# Release plan: public on Saturday 10 October 2026

Written Monday 5 October 2026. Five days. This is the one list for the release: everything that has to
happen, in code, in Blender, in Studio and on Roblox. `README.md` is how to set up and the working rules,
`docs/BUILD_QUEUE.md` the record of what Yaani decided and what was built, `docs/VISUAL_AUDIT.md` the full
inventory of what looks placeholder (the M, D, U and E numbers below are its), and `docs/PLAN.md` the money,
the ad budget and the human checklist.

## 0. The three things that decide the date

1. **Fixed in the simulator on 6 October (A1), not yet played.** What it was:
   the balance is broken from the second world on, and that blocks the release more than any model.
   `python3 tools/balance/sim.py` on 5 October, the ordinary player, every system on: Earth 1:12, the Moon
   **12:48**, Mars **92 hours**, Neptune **367 hours**, stuck in the fifth world after 600 hours. The target is
   about 44 hours for the whole game (`docs/BALANCE.md`, section 1). Since mini cannons became flat DPS their
   share of the growth is gone after Earth. Nothing was retuned. Task A1.
2. **Not everything can be modelled by Saturday, and it does not need to be.** 147 mini cannons, 24 eggs,
   79 monsters and bosses, 11 islands, the marketplace and the whole base are still parts. Whatever has no
   model falls back to the part-built one by itself (`Models.mini`, `Models.monster`, `Islands.dressFor`), so
   no missing model can break the game. The plan models what a player sees on the first day and ships the
   rest in order, world by world, after the release.
3. **Settled 6 October: the group's experience is the release.** Yaani imported every model into the group's
   place (`2504544`) and works there. What follows is the record of why it was a question.
   There were two experiences, and only one can be the release. Yaani's "Project Egg WIP" holds the
   models as first imported (meshes owned by the account `OhYaani`; `place/ProjectEgg.rbxl` is its copy). On
   5 October Victor published a second one, `+1 Cannon Per Click`, under the group Astral Crafts, built from
   `src` and with Earth's models imported again from the FBX files (meshes owned by the group). Passes,
   products, saves, leaderboards and the page all belong to one experience. Decision 1 in section 4, on
   Tuesday morning, before anything is created on Roblox. The plan below assumes the group's.

## 1. How the two of us work on this

- **This file is the list.** To take a task, put your name in its Owner cell and push that one-line change to
  `main` before starting, so the other sees it. When it is done, set Status to `done` with the date. A task
  with no owner on Wednesday morning is nobody's: say so in the chat.
- **Git.** `main` is what is published. Work on a branch named `<who>/<task id>` (`victor/C3`), open a pull
  request, the other one reads it, merge. Small fixes to docs and this file go straight to `main`. Pull before
  you start, every time. Never force-push `main`.
- **Before every push:** `for t in tools/emu/tests/*.luau; do case $t in *.pre.luau|*_prelude*) ;; *) python3
  tools/emu/run.py --all-features $t || break;; esac; done` and `python3 tools/luau_check.py` on what changed.
- **One place.** Assuming decision 1: the Roblox place `80923792816716` (experience `10769534537`, owned by
  the group Astral Crafts, `230235107`). Open it from Studio's Experiences list. Code reaches it with
  `rojo serve` and the Rojo plugin, which syncs `src` and leaves the models alone. The models and the lighting
  live only in the place: a place made with `rojo build` has neither, and publishing one over the live place
  deletes them. `place/ProjectEgg.rbxl` is the copy kept in git (File, Download a Copy, after every import).
- **Publishing.** `README.md` says publishing is Yaani's call and "Save to Roblox" is always fine. Victor
  published the group's place twice on 5 October before reading that. From now: save freely, say "publishing"
  in the chat before a publish, and give every publish a note with the task ids (File, Publish to Roblox with
  Notes). After Saturday a publish changes the live game for players.
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
| A1 | P0 | Retune so the game is playable past Earth: `Config.PetDps`, the egg curve, `Config.TowerCurve` (`tools/balance/tune.py`, `fit.py`) | `sim.py`: the Moon under 2 hours, Mars under 2:30, all twelve worlds between 40 and 60 hours | Yaani | done 6 Oct in `sim.py`, not played: towers 4x, mini cannons 5.25x, `hpGrowth` 1.131, `worldPay` fitted. Yaani's pace replaces the 40 to 60 hours of this row and of the gate: about 30 minutes a world, the last four 40 to 70 on average, none over 1:30. Six seeds: worlds 1 to 8 are 20 to 40 minutes, the last four swing from 5 minutes to 1:52; 6 to 8 hours in all |
| A2 | P0 | `docs/BALANCE.md` rewritten from the new run; its sections 1, 3 and 4 are out of date since the flat DPS change | the document's numbers are the simulator's | | open |
| A3 | P0 | Decide what Mastery Rapid and the Silver tier's Rapid Fire do. Both are cosmetic since Quick Draw went and Rapid is still sold for gems (Yaani's call: remove and refund, or a new meaning) | no track or perk that does nothing is on sale | | open |
| A4 | P0 | Things the simulator does not know and nobody has sized for the new core: ammo, powerups and the 2x boosts are still the clicker's numbers (`docs/BALANCE.md`, section 5) | each is in `sim.py` or checked by hand against a level's worth of damage | | open |
| A5 | P0 | `docs/GEMS.md`, "before launch": gems named the same on every screen; rebirth's gem reward capped; slot prices 250 / 750 / 2,000; the Gem Egg and the weekly Exclusives scale with the player. Written for the clicker: check each against today's code first | each line marked built or not needed in `docs/GEMS.md` | | open |
| A6 | P1 | Offline earnings in the simulator (they are not measured against the pace floor) and an "offline coins" tile in STATS | `sim.py --offline`; the tile shows | | open |
| A7 | P0 | Decide: are gems sold for Robux at launch? Nothing sells them today, and `docs/GEMS.md` puts the gem packs after launch. The plan assumes **no**: launch revenue is the 6 passes and 6 products of section C | written here | | open |

### B. Code

| # | P | Task | Done when | Owner | Status |
|---|---|---|---|---|---|
| B1 | P0 | The six `.conflict` files (`Game`, `Config`, `Data`, `Effects`, `ARCHITECTURE.md`, `BUILD_QUEUE.md`): fold in what is missing from the live file, or delete | none left in the repository | Yaani | done 6 Oct |
| B2 | P0 | Server size. The place allows 50 players and there are 12 bases; over twelve, bases are shared and the second owner cannot invite | the experience's maximum is 12 | Victor | done 6 Oct (Creator Hub, the place's Access page: 50 to 12) |
| B3 | P0 | Never seen in Studio (built 5 Oct): the base's surround and the camera against its unseen walls, the two teleporters beside the arrival, the lobby during a slow load, the level panel's bottom row on a phone, a guest landing on a base 2,000 studs away | each looked at; what is wrong is a line in H3 | | open |
| B4 | P1 | A guest on somebody's base sees the marketplace's sky, not the host's world's | the host's sky | | open |
| B5 | P0 | First join: the level keeps running behind the welcome cards; the cards' and the marker's size on a real phone | checked on a phone with a new save | | open |
| B19 | P0 | A new player's free cannon stands by the monsters' portal, not by the gate: the starter pad (`Layout.PADS[1]`) and the old twelfth pad swapped places, so the pad by the gate is for sale | a fresh save in a play test has one cannon, at the portal end | Yaani | done 6 Oct in code and tests; not yet seen in Studio |
| B6 | P0 | Loading screen in `ReplicatedFirst` (not mapped in `default.project.json` today), held until the base has opened, which also hides the "Opening your base..." room (D11, D12, M24) | no grey room and no Roblox default screen on joining | | open |
| B7 | P0 | Sound hooks: `UI.sound` does not exist and the only sounds in the game are six crate sounds with id 0 (D13). The hooks are listed in `docs/UI_VISION.md`, "Sound hooks" | every hook plays what F1 uploads | | open |
| B8 | P1 | Particles with their own texture (D15). The health bar and backpack were switched off on 6 Oct (Yaani) | not Roblox's default sparkle | | open |
| B9 | P0 | Paid random items: the odds are shown for every egg, crate and enchant roll, and `PolicyService` is asked before each paid roll (it is in Crates and Enchant; check the x3 Luck pass and the eggs) | a restricted test account cannot buy a random item | | open |
| B10 | P0 | Halloween event end to end: candy drops, the four eggs, the candy shop, the event leaderboard, the top five's rewards paid once on the next join, everything gone after `Config.Halloween.endsAt` (1 November 2026, 00:00 UTC) | played with a test end time five minutes away | | open |
| B11 | P0 | The first save of the real game. The live experience already holds test saves from 5 October in `PlayerData_v4`. Decide: wipe them or rename the store | no tester starts the release at level 28 | | open |
| B12 | P0 | Marketplace wear code for D5: the model over the part-built square, the way `Islands.wear` does it; the Halloween dress shown and hidden with the event | every prompt and sign of `Marketplace.luau` stands where the model shows it | | open |
| B13 | P0 | Base wear code for D7 in `Plots.luau` (shells placed as `earth_base.py`'s header says, the `...Trim` meshes tinted by the game), and `Models.tower` using D6's models; the part-built ones stay as the fall back | `tools/emu/tests/defense_client.luau` passes; aiming and the muzzle unchanged | | open |
| B14 | P1 | Loot viewer and the Huge showcase using `Models.mini` (M7, M8) | one mini cannon builder, not three | | open |
| B15 | P0 | The group promises codes ("Exclusive codes" in its description) and the game has no way to redeem one. Build a small code box, or take the line out of the group | the promise and the game agree | | open |
| B16 | P1 | Analytics: the funnel of the first ten minutes (joined, welcome done, first tower, level 5, first hatch, level 10, marketplace) and every purchase | visible in Creator Hub | | open |
| B17 | P0 | The Mastery "Slots" track is shown but not sold (`README.md`, section 7) | sold, or not shown | | open |
| B18 | P0 | Two stale emulator tests: `mastery.luau` and `defense_client.luau` | both pass, or are rewritten for today's game | | open |
| B19 | P1 | Dead clicker pieces still hidden in `Hud.luau` | removed | | open |
| B20 | P2 | STATS: the missing sources. Badges. Own run and idle animations (D6). Chat colours (D7) | | | open |

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
| C6 | P0 | Pass: 3x Speed (2x is free for everyone since 6 Oct; the code and `tests/smoke.luau` are done, the pass still has to be created) | 99 | `Config.Passes.gameSpeed` | | open |
| C7 | P0 | Product: Shiny Enchantment Key | 149 | `Enchant.ShinyProduct` (`src/shared/Features/Enchant.luau`) | | open |
| C8 | P0 | Product: the Robux crate | 99 | `src/shared/Features/Crates.luau`, the `robux` price | | open |
| C9 | P0 | Product: Boost Pack | 49 | `src/shared/Features/Powerups.luau` | | open |
| C10 | P0 | Product: Boss Buster Pack | 129 | same | | open |
| C11 | P0 | Product: Mega Pack | 399 | same | | open |
| C12 | P0 | Product: Candy Pack (event) | 79 | same | | open |
| C13 | P0 | Buy each once on the live place with a real account: the pass works at once and after rejoining; a product is granted once, and once only when the receipt is retried (`Game.processReceipt`) | 12 ticks | | open |
| C14 | P0 | Group revenue: who gets what share of Astral Crafts' Robux (Victor and Yaani decide; set in the group's payouts) | set | | open |

### D. Models, islands, bases, sky and sound: see `docs/RELEASE_TASKS.md`

**The jobs for Blender models, the Studio imports, sky, light and sound are in `docs/RELEASE_TASKS.md`**
(Yaani's list, groups A to G and I, with time estimates). They are ticked there and not repeated here, so a
job has one home. On 6 October it stood at 61 done, 32 open: bases, islands and monsters for worlds 1 to 5
are built; the open jobs are the Studio import-and-test of the four new islands and of each world's monsters,
Earth's two coin eggs and their 10 mini cannons, the marketplace model and its hook, sky and light, all of
sound, and the launch jobs. Worlds 6 to 12 and the mini cannons of worlds 2 to 5 are after the release.

Where this file and that one name the same job, that one is where it is ticked: sound (F here, G2 to G5
there), sky (E6 here, G1 there), icon and thumbnails (G3 here, I1 and I2 there), the passes (C1 to C6 here,
I3 there), the kept place file (R2 here, I4 there), the phone play-through (H2 here, I5 there), the
marketplace and base hooks (B12 and B13 here, F2 and B2 there).

Not in that list: towers have no models (after the release, by that list), and the loot viewer and the Huge
showcase still build mini cannons from parts (B14).

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
| G1 | P0 | **Tuesday, not Saturday:** confirm in Creator Hub that the experience can be made public. The maturity and compliance questionnaire, and whatever account verification Roblox asks of the publisher, can take days | Creator Hub shows nothing missing | Victor | doing. 6 Oct: the maturity questionnaire is submitted (label Mild; Violence, repeated and mild; paid random items and paid item trading declared, both policy APIs followed). The Audience reach page then shows: group publishing reach **All ages** (nothing wrong with the account or the group); a **refundable publishing fee, not submitted** ("reach more players by paying a refundable publishing fee to level up your current publishing reach"); an optional expedited review for a refundable 50,000 Robux; and "highly engaged players" 0 of 250. Until the fee is paid or that count is reached, a public game is limited to 16+ users and trusted friends. **Open:** the fee's amount and terms (View details), and the decision to pay it (Victor and Yaani; `docs/PLAN.md` has a $150 budget) |
| G2 | P0 | The page: name `+1 Cannon Per Click`, description, genre, devices (phone, tablet, computer; console only if E1 was done on one) | filled | | open |
| G3 | P0 | Icon and three thumbnails uploaded (D15). They are moderated: upload on Friday morning at the latest | approved | | open |
| G4 | P0 | Settings: maximum players 12 (B2); "Studio Access to API Services" as needed; HTTP requests off; private servers on and free, or off (decide) | set | | open |
| G5 | P0 | The group: the description matches the game (B15); the icon is up; social links; who has which role. Yaani's Admin role can play, edit and publish since 5 October; nobody else can | checked | | open |
| G6 | P0 | Asset ownership. The UI atlases (`75982409729652`, `89091306681120`) were uploaded by a personal account: check they load in the group's experience for an account that is not the uploader, or upload them again under the group | the HUD's icons show for a stranger | | open |
| G7 | P1 | A second place or a copy of the experience for testing, so nothing is tried on the live one after Saturday | exists, and is where Rojo points by default | | open |
| G8 | P1 | The launch post in the group and wherever else (Victor and Yaani decide where); a trailer or a 20-second clip | posted on Saturday | | open |
| G9 | P1 | Ads: `docs/PLAN.md`'s human checklist (the Ads Manager account, the card, campaign 1 drafted and not submitted until the first day's numbers are in) | campaign 1 is a draft | | open |
| G10 | P0 | Mesh and image ownership for the release experience. If it is the group's: every model is imported again from its FBX under Astral Crafts (Earth's were, 5 Oct), and `place/ProjectEgg.rbxl` is replaced by a copy of the group's place. If it is Yaani's: nothing to do | no blank model for a stranger | | open |

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
| R2 | P0 | The kept place file is the release experience's: `place/ProjectEgg.rbxl` refreshed from it (File, Download a Copy) after every import, as `place/README.md` says. Better, if there is time: the four folders saved as `.rbxm` and mapped in `default.project.json`, so `rojo build` gives the whole game | the committed file, opened and played, shows every model that is live | | open |
| R3 | P0 | `tools/studio/organize_imports.luau` for every world: monsters and bosses by a name table instead of Earth's six; worlds with two-word names (`The Sun`, `Crystal Belt`, `Robot Factory`, `Alien Jungle`, `Black Hole`, `The Big Bang`) | the Moon's files import with no edit to the script | | open |
| R4 | P0 | Rojo for both: `rokit install` works on both machines (`rokit.toml` pins Rojo 7.7.1), the Rojo plugin is in both Studios | both have synced a change | | open |
| R5 | P1 | `README.md` (Yaani, 5 Oct): add how to import a model (section 7 here) and name the release experience | both in | Yaani | done 5 Oct, two lines to add |
| R6 | P1 | A check on every pull request that runs the tests (GitHub Actions; the tests need only Python 3) | a red cross on a broken pull request | | open |

## 4. Decisions only Victor and Yaani can make

Each blocks a task above. Write the answer here.

| # | Question | Blocks | Answer |
|---|---|---|---|
| 1 | Which experience is released: the group's `+1 Cannon Per Click` (the plan), or Yaani's "Project Egg WIP"? And who presses Publish? | C, G, R2, G10 | The group's (6 Oct: Yaani imported every model into it). Who publishes: still open |
| 1b | Is it acceptable that worlds 4 to 12 are part-built on Saturday? The plan assumes yes | everything | |
| 2 | Mastery Rapid and Silver's Rapid Fire: remove and refund, or a new meaning? | A3 | |
| 3 | Gems for Robux at launch: no (the plan), or yes? | A7 | |
| 4 | Test saves in the live experience: wipe? | B11 | |
| 5 | Codes: build a code box, or drop the promise? | B15 | |
| 6 | Revenue split of the group | C14 | |
| 7 | Private servers: free, paid or off? | G4 | |
| 8 | Who owns which section this week? | every Owner cell | |
| 9 | Should fusing stay locked until island 5? It slows worlds 1 to 4 (`README.md`) | A1 | |
| 10 | Should "Lucky" be rollable from the Shiny key, which is sold for Robux? (`README.md`) | B9, C7 | |
| 11 | Does candy won from candy-bought crates count for the Halloween leaderboard? (`README.md`) | B10 | |

## 5. Day by day

### Tuesday 6 October: the blockers and the pipeline

Decision 1 first: which experience. Then A1, A2, A3 (balance). G1 (can it go public at all). D1, D2, R2,
R3, R4, G10 (the pipeline). B1 (conflict files), B18 (stale tests). D3 (Earth's eggs and mini cannons). The
rest of section 4's decisions.

### Wednesday 7 October: Earth and the base, finished; money in

D4 (Earth's bosses), D6 and D7 with B13 (towers and the base), D5 with B12 (marketplace), D8 and D9 if there
is time. B17. C1 to C12 with E4 (create every pass and product), A4, A5, A7, B2, B9, B11, B15. F1 and F2 chosen.

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
- [x] No `.conflict` file in the repository (B1)
- [ ] One experience, named in section 0, and `place/ProjectEgg.rbxl` is its copy (decision 1, R2)
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
6. File, Download a Copy over `place/ProjectEgg.rbxl` (R2), commit, publish.

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
