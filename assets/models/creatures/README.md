# Creatures

Made by `tools/blender/creatures.py`: `blender --background --python tools/blender/creatures.py -- <World> assets/models/creatures [draft]`.
One file per world, `<world>_creatures.fbx` (+ `.blend`, `.png`). Every creature is one mesh with its colours on
the vertices (`Col`), origin under its feet, front towards -Y, about 2 units tall (bosses 2.6). A mesh's name
is the game's monster name (`Config.Worlds` in `src/shared/Config.luau`) with underscores for spaces;
`tools/studio/setup_models.luau` files each one as `ReplicatedStorage.Creatures.<monster name>`.

- **Earth** (`earth_creatures.fbx`): `Ogre_Chief` = Ogre Chief (mid boss), `Earth_Titan` = Earth Titan (world boss). Earth's five monsters are in `../creatures_all.fbx`.
- **Moon** (`moon_creatures.fbx`): `Moon_Rockling` = Moon Rockling, `Crater_Crawler` = Crater Crawler, `Lunar_Bat` = Lunar Bat, `Astro_Ghost` = Astro Ghost, `Moon_Golem` = Moon Golem, `Dark_Side_Stalker` = Dark Side Stalker (mid boss), `Moon_Colossus` = Moon Colossus (world boss).
- **Mars** (`mars_creatures.fbx`): `Martian_Grunt` = Martian Grunt, `Sand_Worm` = Sand Worm, `Red_Scorpion` = Red Scorpion, `Dust_Devil` = Dust Devil, `Rover_Bot` = Rover Bot, `Martian_Warlord` = Martian Warlord (mid boss), `Olympus_Guardian` = Olympus Guardian (world boss).
- **Neptune** (`neptune_creatures.fbx`): `Frost_Imp` = Frost Imp, `Snow_Blob` = Snow Blob, `Ice_Wraith` = Ice Wraith, `Glacier_Crab` = Glacier Crab, `Yeti` = Yeti, `Blizzard_Wraith` = Blizzard Wraith (mid boss), `Frost_Giant` = Frost Giant (world boss).
- **The Sun** (`the_sun_creatures.fbx`): `Magma_Blob` = Magma Blob, `Fire_Imp` = Fire Imp, `Lava_Crab` = Lava Crab, `Flare_Spirit` = Flare Spirit, `Cinder_Golem` = Cinder Golem, `Inferno_Hound` = Inferno Hound (mid boss), `Solar_Titan` = Solar Titan (world boss).

Floaters (Lunar Bat, Astro Ghost, Dust Devil, Ice Wraith, Blizzard Wraith, Flare Spirit) hover 0.6 over a thin
puddle of light that is part of the mesh: the setup script puts the pivot at the mesh's lowest point, so the
puddle is what keeps the hover.
