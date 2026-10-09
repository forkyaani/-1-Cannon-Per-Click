# +1 Cannon Per Click

A Roblox third-person idle defence game. Each player owns a private base: monsters walk a path across it, and
cannon towers you buy and upgrade shoot them on their own. Mini cannons (pets hatched from eggs) follow you
and add damage. Beat a world's boss to open the next of 12 worlds.

The goal of the project: 100,000 Robux of revenue by 31 December 2026, on a $150 budget.

This file is the starting point for anyone joining the project.

## 1. Get it running (about 15 minutes)

You need a Mac or Windows PC with Roblox Studio installed.

1. Clone the repo.
   ```bash
   git clone https://github.com/forkyaani/-1-Cannon-Per-Click.git
   ```
2. Install Rokit (the tool manager), then let it install Rojo (the tool that syncs these files into Studio).
   See https://github.com/rojo-rbx/rokit for the installer, then inside the project folder:
   ```bash
   rokit install
   ```
3. Start the sync server and leave it running.
   ```bash
   rojo serve
   ```
4. In Roblox Studio: install the Rojo plugin (Plugins tab, or `rojo plugin install`), open the place
   **+1 Cannon Per Click** of the group **Astral Crafts** from Studio's Experiences list (ask Yaani or Victor
   for a group role with edit access; see `docs/RELEASE_PLAN.md`, section 1, "One place"), open the Rojo panel
   and press **Connect**.
5. Press Play in Studio. You should spawn on your own base with a level bar at the bottom of the screen.

The code lives in this repo, not in the Studio place. Edit files here and Rojo pushes them into Studio.
The 3D models are made by the Blender scripts in `tools/blender/`, exported to `assets/models/`, and imported
into the Studio place by hand (steps in `place/README.md`). `place/ProjectEgg.rbxl` is a kept copy of that place.

## 2. How the project is laid out

| Path | What it is |
|---|---|
| `src/shared/` | Data and maths both sides use. `Config.luau` holds every number; `Layout.luau` the base's geometry |
| `src/server/` | Server logic. `Game.luau` is the core loop; `Plots.luau`, `Islands.luau`, `Marketplace.luau` build the world |
| `src/client/` | UI and effects. `UI.luau` is the UI kit; `Hud.luau` the HUD; `Field.luau` draws monsters and tower shots |
| `src/first/` | The loading screen. Runs from `ReplicatedFirst` before anything else has arrived, so it requires nothing |
| `src/*/Features/` | One feature per file, loaded automatically: Towers, Mastery, Enchant, Fuse, Crates, Trading, Story, Tutorial ... |
| `docs/` | Design and technical docs (see section 5) |
| `tools/` | Checks you can run without Studio (see section 3) |
| `assets/` | UI icon atlases and 3D source files |
| `place/` | `ProjectEgg.rbxl`, a full copy of the Studio place (imported model templates, Lighting), and how to import a model |

A feature plugs into the core through hooks instead of editing it. Read `docs/ARCHITECTURE.md` before writing one.

## 3. Check your work before you push

Nothing outside Studio runs real Luau, so these are the checks. Run them from the project folder.

```bash
python3 tools/luau_check.py $(find src -name '*.luau')
```
Syntax and unknown-name check. Must print `ok` for every file.

```bash
rojo build -o out.rbxl
```
Checks the project builds.

```bash
cd tools/emu && python3 run.py --all-features tests/smoke.luau
```
An offline emulator boots the server and client with every feature and plays a session. It takes about
three minutes and must end in `PASSED`. If it stops on "X is not a valid member" for something that really
exists in Roblox, the emulator needs teaching (`tools/emu/roblox_emu.py`), not the game.

Then play it in Studio. The offline checks cannot judge how anything looks or feels.

## 4. Working rules

- **Pull before you start, push small commits.** Say in the commit message what changed for a player.
- **Do not close Studio without saving** (File, Save to Roblox). The imported model templates live in the
  place, and `place/ProjectEgg.rbxl` is only as new as the last copy someone downloaded.
- **Publishing is Yaani's call.** "Save to Roblox" is fine; "Publish to Roblox" changes the live game.
- **The server decides everything.** The client asks; never trust a number the client sends.
- **Numbers go in `Config.luau`** or a feature's shared file, not scattered through the code.
- **UI is built from the kit in `src/client/UI.luau`** (the "Candy Arcade" look, `docs/UI_VISION.md`).
- **Player-facing text says "gems"**; the code and the save call them `diamonds`.
- **Test saves:** in a Studio play test, run this in the command bar to wipe your own save:
  `game.ReplicatedStorage.Remotes.Debug:FireServer("reset", 1)`. Other debug commands are listed at the end
  of `docs/ARCHITECTURE.md`.

## 5. Docs worth reading, in order

1. `docs/RELEASE_TASKS.md`: the live job list. Read its "Who is on what" rules: pull, claim a job on its line
   and push BEFORE starting. `docs/RELEASE_PLAN.md` is the 5 Oct plan with what is done.
2. `docs/IDLE_DEFENSE.md`: the game's design on one page.
3. `docs/BUILD_QUEUE.md`: every decision Yaani has made, with dates. If it is written there, it is decided.
4. `docs/ARCHITECTURE.md`: how to add a feature; the server and client APIs; debug commands.
5. `docs/DEFENSE_SPEC.md`: the contract between the server core, the base and the client.
6. `docs/BALANCE.md`: the pacing model and its simulator (`tools/balance`).
7. `docs/UI_VISION.md` and `docs/VISUAL_AUDIT.md`: the art direction and the list of placeholder visuals.

## 6. What is built

Private bases with visits by invitation; 8 tower kinds on 16 pads; 12 worlds of 50 levels with bosses; lives,
pause and a 1x to 3x speed pass; eggs, mini cannons, Secrets and Huge cannons; 12 world islands with eggs and
shops; Mastery (island 3); Enchanting and the Fuse menu (island 5); crates with an opening animation; the loot
viewer; trading; ammo and powerups; the STATS window; prestige rebirth; three leaderboards plus the Halloween
candy leaderboard; offline earnings; the story and the first-join tutorial.

## 7. What is left before launch

Roughly in order. The live list is `docs/RELEASE_TASKS.md`: claim a job there and push before starting, and
tick it there when it is done.

1. **Balance.** Retuned on 6 Oct in the simulator (`docs/RELEASE_PLAN.md`, A1; `Config.PetDps = 525`) after
   mini cannons became flat DPS and the game stalled from world 2 on. Not yet played through. The pacing
   model and the simulator (`tools/balance`) are in `docs/BALANCE.md`.
2. **Play every feature in Studio and fix what is wrong.** Islands, Mastery, Enchanting, Fuse, STATS, visits,
   the tutorial and offline earnings have passed offline checks but have barely been looked at.
3. **Phones.** Check every window and the HUD on a phone-sized screen (Studio's device emulator).
4. **Two players.** Trading, visits and leaderboards need a real two-player test (Test, Server and Clients).
5. **Loose ends in code:** dead clicker pieces still hidden in `Hud.luau`. (Mastery was reworked on 7 Oct:
   18 tracks, every one measured in `tools/emu/tests/mastery.luau`. "Rapid" is Mini Crit and the Silver fuse
   tier's "Rapid Fire" is Overcharge, +25% DPS. The pace has to be fitted again after it: `docs/BALANCE.md`, 5c.)
6. **Visuals.** Blender models for all twelve worlds are in `assets/models`. `docs/VISUAL_AUDIT.md` and
   `docs/RELEASE_TASKS.md` say what is imported and what is still placeholder.
7. **Robux.** The six game passes, the six gem packs and the group id (`Config.Fan.groupId`) are set. Still
   at id 0: the Royal Crate, the powerup packs and `Enchant.ShinyProduct` (`docs/RELEASE_TASKS.md`, O2 and S3).
   Buying each once on the live place is still open (`docs/RELEASE_PLAN.md`, C13).
8. **Launch.** Game icon and thumbnail, publish, then the ad plan in `docs/PLAN.md`.

## 8. Open questions for Yaani

- Should fusing stay locked until island 5? It slows worlds 1 to 4 a lot.
- Should the "Lucky" enchant be rollable from the Shiny key, which is sold for gems (1,000 in the island
  shop)?
- Should candy won from candy-bought crates count toward the Halloween leaderboard?
