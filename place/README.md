# The place file

`ProjectEgg.rbxl` is a full copy of the Roblox Studio place. The code under `src/` is synced into Studio by
Rojo, but these things live only in the place file, so they are kept here:

- the 3D model templates in `ReplicatedStorage`: `Creatures`, `MiniCannons`, `EggModels`, `IslandModels`
  (made from the Blender files under `assets/models/`). Without them the game falls back to plain blocks.
- the `Lighting` settings (Atmosphere density 0.1, exposure -0.25).

## Setting up your own copy

1. Open `ProjectEgg.rbxl` in Roblox Studio.
2. File > Publish to Roblox As… and create your own experience.
3. Start Rojo (`rojo serve`) and connect from Studio so the scripts match `src/`.

The meshes and the icon images were uploaded from the account `OhYaani`. If models or icons show up blank in
your experience, that account has to grant your experience permission to use them (Creator Hub > the asset >
Permissions), or re-import the `.fbx` files from `assets/models/` yourself.

Game passes and saves belong to an experience: a new experience starts with none, and the pass ids in
`src/shared/Config.luau` have to be replaced with its own.

This copy is refreshed by hand (File > Download a Copy) whenever new models are imported.
