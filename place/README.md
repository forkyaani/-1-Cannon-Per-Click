# The place file

`ProjectEgg.rbxl` is a full copy of the Roblox Studio place. The code under `src/` is synced into Studio by
Rojo, but these things live only in the place file, so they are kept here:

- the 3D model templates in `ReplicatedStorage`: `Creatures`, `MiniCannons`, `EggModels`, `IslandModels`,
  `BaseModels`, `MarketModels` (made from the Blender files under `assets/models/`). Without them the game
  falls back to plain blocks.
- the `Lighting` settings (Atmosphere density 0.1, exposure -0.25).

## Setting up your own copy

1. Open `ProjectEgg.rbxl` in Roblox Studio.
2. File > Publish to Roblox As… and create your own experience.
3. Start Rojo (`rojo serve`) and connect from Studio so the scripts match `src/`.

## Importing a new model (d1v)

Do this whenever a new `.fbx` lands in git. It takes about two minutes a file.

1. `git pull`, then open the group's place in Studio. Stay in edit mode (do not press Play).
2. File > Import (in some Studio versions: Home > Import 3D). Pick the `.fbx`.
3. In the import window tick **Anchored**. Leave everything else as it is. Press **Import**.
4. Wait until a model with the file's name (for example `moon_island`) shows up in the Workspace. Do not
   rename or move it. You can import several files before the next step.
5. Open `tools/studio/setup_models.luau` in a text editor, select all, copy.
6. In Studio: View > Command Bar. Click in the bar, paste, press Enter.
7. Read the Output window (View > Output). It ends with a summary table: one line per file, where it went and
   how many meshes. The model is gone from the Workspace: it now lives in `ReplicatedStorage`.
8. File > Save to Roblox.
9. Press Play and look at the thing you imported (walk to the island, start a wave, ...).
10. File > Publish to Roblox.
11. File > Download a Copy, save it over `place/ProjectEgg.rbxl`, commit and push.

Running the script twice does no harm. A newer import replaces the older model of the same name.

### Where the files are and where they end up

| File | Ends up in `ReplicatedStorage` as |
|---|---|
| `assets/models/islands/<world>_island.fbx` | `IslandModels.<World>` and `IslandModels.<World>Shells` |
| `assets/models/bases/<world>_base.fbx` | `BaseModels.<World>` and `BaseModels.<World>Shells` |
| `assets/models/marketplace/marketplace.fbx` | `MarketModels.Market` and `MarketModels.MarketShells` |
| `<world>_creatures.fbx` under `assets/models/` | `Creatures.<monster's name>`, one per monster |

`<world>` is the world in small letters: `earth`, `moon`, `mars`, `neptune`, `the_sun`. The script goes by the
file's name, so do not rename the files.

### If something goes wrong

- **"Nothing to do"**: the import is not in the Workspace, or its name was changed. Import again.
- **A yellow warning with a file's name**: that file was not filed and is still in the Workspace. The warning
  says what is missing (usually a mesh the Blender export should have had). Send it to Yaani.
- **"MISSING shells" in the summary**: the model was filed, but a piece the game needs is not in it. Send it
  to Yaani.
- **The model is white or grey in game**: nothing to fix in Studio, the export has no colours. Send it to Yaani.
- **A monster shows as blocks**: its name in `Creatures` has to match the game's name letter for letter
  (`Moon Rockling`). The summary lists the names it made.
- **Undo**: Ctrl+Z right after the script puts everything back.

Mini cannons and eggs (`assets/models/minis/marketplace_minis.fbx`) are not handled by this script. Do not run
the older `tools/studio/organize_imports.luau` for them without asking: it empties `IslandModels` and
`Creatures` first.

## Permissions

The meshes and the icon images were uploaded from the account `OhYaani`. If models or icons show up blank in
your experience, that account has to grant your experience permission to use them (Creator Hub > the asset >
Permissions), or re-import the `.fbx` files from `assets/models/` yourself (steps above).

## Game passes and saves

Game passes and saves belong to an experience: a new experience starts with none, and the pass ids in
`src/shared/Config.luau` have to be replaced with its own.

## Keeping this copy fresh

This copy is refreshed by hand (File > Download a Copy) whenever new models are imported.
