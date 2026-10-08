# Release task list: Saturday 10 Oct 2026

Visuals, UX and Blender models for launch. Small jobs, ticked off as they land. Each job ends with a push to
git. **[S]** marks a job that needs Roblox Studio (import, test or publish): d1v or Yaani in the group's place.
Written 5 Oct 2026. Background: `docs/VISUAL_AUDIT.md`, `docs/UI_VISION.md`, `docs/MINI_CANNON_REVAMP.md`.

Order of work: A, B, C, D per world (Earth, Moon, Mars, Neptune, The Sun), then E, F, G and I.

## Who is on what (read before starting anything)

Two people and several Claude sessions work from this list. On 6 Oct the same mini cannons were modelled
twice in parallel. So:

1. **Pull first** (`git pull --rebase origin main`) and read the job's line.
2. **Claim it before working:** add `(taken: Yaani, 6 Oct 21:40)` or `(taken: d1v, ...)` at the start of the
   job's text, commit only that line, push. If the push is rejected, pull and look again: somebody may have
   claimed it in the meantime.
3. **A claimed job is the claimer's.** Do not start it, extend it or "help" with it; pick another, or ask.
4. **When done:** tick it, replace the claim with a short note of what was made and where, push.
5. A claim older than a day with no commits behind it may be taken over, with a note saying so.
6. **Plan first, on git first** (Yaani, 7 Oct): a new piece of work is written here as jobs and pushed BEFORE
   anybody starts it. Nothing is built, and no agent is started, from a chat message alone.

### Who has what (split on 7 Oct; d1v has the bigger share because he has more usage)

Every open job carries its owner's name: **[d1v]** or **[Yaani]**. Work only on your own; to swap one, change
the name on its line and push before starting.

| Owner | Jobs | About |
|---|---|---|
| **d1v** | E6 remaining mini cannons · F1 to F5 the marketplace · I2 thumbnails · I5 the phone play-through | 6 h 30 |
| **Yaani** | I6 publish | 5 min |

**6 Oct, 06:50:** all 14 model files (5 bases, 4 new islands, 5 creature batches) are imported into the group's place
with `setup_models.luau` and saved. All five bases were seen in a play test (the base swaps as the world changes); the new monsters
were seen walking on The Sun. The islands and a proper look at each monster batch still need their test.

## Time estimates

Working time per job, including checking the result. Studio jobs assume Studio is free. Rough: a model that
needs a second pass doubles its job.

| Group | Time |
|---|---|
| A. Pipeline | 4 h 00 |
| B. Bases | 4 h 10 |
| C. Islands | 3 h 00 |
| D. Monsters and bosses | 6 h 55 |
| E. Eggs and mini cannons | 5 h 55 |
| F. Marketplace | 1 h 55 |
| G. Sky, light and sound | 2 h 55 |
| I. Launch | 2 h 30 |
| **Must ship (A to G and I, without E6)** | **28 h 20** |
| **Everything** | **31 h 20** |

## A. Pipeline (do once, makes everything after it fast)

- [x] A1. `tools/blender/kit.py`: move the shared kit (box, ball, tube, lathe, mat, export) out of the island script · **30 min**
- [x] A2. Theme table for the 5 worlds: ground, rock, plant, accent and sky colours, prop kinds (craters, spires, ice, lava) · **20 min**
- [x] A3. `earth_island.py` becomes `island.py <world>`: same layout, look from the theme · **45 min**
- [x] A4. `earth_base.py` becomes `base.py <world>`: same path and pads, look from the theme · **45 min**
- [x] A5. `creatures.py <world>`: one run makes a world's 5 monsters and 2 bosses as one .fbx · **1 h 00**
- [x] A6. One Studio setup script (`tools/studio/setup_models.luau`) that turns any imported .fbx into its templates **[S]** · **30 min**
- [x] A7. Short import guide for d1v in `place/README.md` · **10 min**

## B. Bases (the first thing every player sees)

- [x] B1. Finish the Earth base model (road, 16 pads, gate, monster portal, teleporters, backdrop) · **40 min**
- [x] B2. `Plots.wear`: hook that puts a base model over the part-built base (keep pads, prompts, signs, walls) · **40 min**
- [x] B3. Colliders list for the Earth base · **10 min**
- [x] B4. Import and test the Earth base **[S]** · **20 min**
- [x] B5. Moon base: theme, render, check the photo · **20 min**
- [x] B6. Moon base: import and test **[S]** · **15 min**
- [x] B7. Mars base: theme, render, check the photo · **20 min**
- [x] B8. Mars base: import and test **[S]** · **15 min**
- [x] B9. Neptune base: theme, render, check the photo · **20 min**
- [x] B10. Neptune base: import and test **[S]** · **15 min**
- [x] B11. The Sun base: theme, render, check the photo · **20 min**
- [x] B12. The Sun base: import and test **[S]** · **15 min**

- [x] B13. A new player's free cannon stands by the monsters' portal instead of by the gate (pads 1 and 12 swap places in `Layout.PADS`); the old spot is for sale. Check it on a fresh save **[S]** · **20 min**

## C. Islands

- [x] C1. Earth island (live)
- [x] C2. Moon island: theme, render, check the photo · **20 min**
- [x] C3. Moon island: colliders list in `Islands.SOLIDS` · **10 min**
- [x] C4. Moon island: import and test **[S]** · **15 min** Seen 6 Oct (d1v's Studio): dressed, eggs, stall, portal and boss statue in place, no errors.
- [x] C5. Mars island: theme, render, check the photo · **20 min**
- [x] C6. Mars island: colliders list in `Islands.SOLIDS` · **10 min**
- [x] C7. Mars island: import and test **[S]** · **15 min** Seen 6 Oct (d1v's Studio): dressed, eggs, stall, portal and boss statue in place, no errors.
- [x] C8. Neptune island: theme, render, check the photo · **20 min**
- [x] C9. Neptune island: colliders list in `Islands.SOLIDS` · **10 min**
- [x] C10. Neptune island: import and test **[S]** · **15 min** Seen 6 Oct (d1v's Studio): dressed, eggs, stall, portal and boss statue in place, no errors.
- [x] C11. The Sun island: theme, render, check the photo · **20 min**
- [x] C12. The Sun island: colliders list in `Islands.SOLIDS` · **10 min**
- [x] C13. The Sun island: import and test **[S]** · **15 min** Seen 6 Oct (d1v's Studio): dressed, eggs, stall, portal and boss statue in place, no errors.

## D. Monsters and bosses

- [x] D1. Earth's 5 monsters (live)
- [x] D2. `Models.creatureFor`: each boss uses its own model, not the shared one · **15 min**
- [x] D3. Earth boss: Ogre Chief · **10 min**
- [x] D4. Earth boss: Earth Titan · **10 min**
- [x] D5. Earth: import the batch and test a wave **[S]** · **20 min** Seen 6 Oct (d1v's Studio): all 7 are models, coloured, facing forward (line-up through `Models.monster`). No wave of this world was watched in a fight.
- [x] D6. Moon: Moon Rockling · **10 min**
- [x] D7. Moon: Crater Crawler · **10 min**
- [x] D8. Moon: Lunar Bat · **10 min**
- [x] D9. Moon: Astro Ghost · **10 min**
- [x] D10. Moon: Moon Golem · **10 min**
- [x] D11. Moon boss: Dark Side Stalker · **10 min**
- [x] D12. Moon boss: Moon Colossus · **10 min**
- [x] D13. Moon: import the batch and test a wave **[S]** · **20 min** Seen 6 Oct (d1v's Studio): all 7 are models, coloured, facing forward (line-up through `Models.monster`). A Moon wave was also watched on the Moon base.
- [x] D14. Mars: Martian Grunt · **10 min**
- [x] D15. Mars: Sand Worm · **10 min**
- [x] D16. Mars: Red Scorpion · **10 min**
- [x] D17. Mars: Dust Devil · **10 min**
- [x] D18. Mars: Rover Bot · **10 min**
- [x] D19. Mars boss: Martian Warlord · **10 min**
- [x] D20. Mars boss: Olympus Guardian · **10 min**
- [x] D21. Mars: import the batch and test a wave **[S]** · **20 min** Seen 6 Oct (d1v's Studio): all 7 are models, coloured, facing forward (line-up through `Models.monster`). No wave of this world was watched in a fight.
- [x] D22. Neptune: Frost Imp · **10 min**
- [x] D23. Neptune: Snow Blob · **10 min**
- [x] D24. Neptune: Ice Wraith · **10 min**
- [x] D25. Neptune: Glacier Crab · **10 min**
- [x] D26. Neptune: Yeti · **10 min**
- [x] D27. Neptune boss: Blizzard Wraith · **10 min**
- [x] D28. Neptune boss: Frost Giant · **10 min**
- [x] D29. Neptune: import the batch and test a wave **[S]** · **20 min** Seen 6 Oct (d1v's Studio): all 7 are models, coloured, facing forward (line-up through `Models.monster`). No wave of this world was watched in a fight.
- [x] D30. The Sun: Magma Blob · **10 min**
- [x] D31. The Sun: Fire Imp · **10 min**
- [x] D32. The Sun: Lava Crab · **10 min**
- [x] D33. The Sun: Flare Spirit · **10 min**
- [x] D34. The Sun: Cinder Golem · **10 min**
- [x] D35. The Sun boss: Inferno Hound · **10 min**
- [x] D36. The Sun boss: Solar Titan · **10 min**
- [x] D37. The Sun: import the batch and test a wave **[S]** · **20 min** Seen 6 Oct (d1v's Studio): all 7 are models, coloured, facing forward (line-up through `Models.monster`). No wave of this world was watched in a fight.

## E. Eggs and mini cannons

- [x] E1. Test the egg prompts (E / R / F, no popup) **[S]** · **15 min**
- [x] E2. Check the "what's inside" window on an egg; fix what looks poor · **30 min**
- [x] E3. Earth: Basic Egg and Forest Egg models · **20 min** · d1v, 6 Oct: `egg_basic`, `egg_forest` in `assets/models/minis/world_minis.fbx`. Not yet imported (E7)
- [x] E4. Earth: the mini cannons of those two eggs · **1 h 00** · d1v, 6 Oct: ten, `mini_wooden` to `mini_jade`, same file; photos `world_row_basic.jpg`, `world_row_forest.jpg`. Not yet imported (E7)
- [x] E5. Eggs for worlds 2 to 5 (2 each): recolours of one egg design · **30 min** · d1v, 6 Oct: eight eggs, same file; photo `world_row_mars.jpg` (Moon's and Comet's stand in their own rows). Built with `minis.py -- <folder> full worlds`. Not yet imported (E7)
- [x] E6. **[d1v]** (for d1v: Yaani's side will not take this) (DECIDED by Yaani, 6 Oct: d1v's style is the one to use, `minis.py ... worlds`. Still to make in that style: Mars, Neptune and The Sun's mini cannons, and the hidden Secrets and Huges of all five worlds. The set from `world_minis.py` (`<world>_minis.fbx`, commit 7680145) is NOT to be imported over d1v's; it is only a stand-in for ids d1v's set does not have yet.) (Moon's ten done by d1v, 6 Oct: `mini_moonrock` to `mini_galaxy` in `world_minis.fbx`, photos `world_row_moon.jpg`, `world_row_comet.jpg`. Mars, Neptune and The Sun's thirty done by d1v, 6 Oct 22:00: all 50 ordinary mini cannons of worlds 1 to 5 are in `world_minis.fbx`, one photo per egg, `world_row_<egg id>.jpg`. Imported 6 Oct 22:01: the place holds 75 mini cannons (all 50 of these and the marketplace's 25) and 15 eggs. Ten of the new ones were built with `Models.mini` in a play test and came out whole and in colour; none has been seen firing from a base. The 20 Secrets and 7 coin-egg Huges are modelled (d1v, 6 Oct 22:25): `mini_glitched<egg>`, `mini_forbidden<egg>`, `mini_huge<name>` in `world_minis.fbx`, photos `world_row_secrets1..4.jpg`, `world_row_huges1..2.jpg`. Imported 6 Oct 22:28: the place holds 102 mini cannons and 15 eggs, and in a play test all 80 mini cannons the ten coin eggs can hatch (50 ordinary, 20 Secret, 10 Huge slots) got a model from `Models.mini`. None seen firing from a base yet. Left for after launch, no model yet: the Secrets of the Gem and Halloween eggs, and the Gemstone, Pumpkin, Tycoon and Spectre Huges) Mini cannons for worlds 2 to 5: after launch unless time is left · **3 h 00**
- [x] E7. Import eggs and mini cannons **[S]** · **20 min** · d1v, 6 Oct 21:36: `world_minis.fbx` imported under Astral Crafts and filed (the place now holds 45 mini cannons and 15 eggs; nothing else touched). Seen in a play test: the Basic and Forest eggs stand on Earth's island as models, 15 of the world's eggs are models. The 20 new mini cannons are filed by pet id but not yet seen firing. The eggs first went in as `basic`, `forest`...: the game's ids are `basicegg`, `forestegg`..., so they were renamed in the place and in `minis.py`. For a later import use `tools/studio/add_minis.luau` or `setup_models.luau`. `place/ProjectEgg.rbxl` is NOT refreshed yet (I4)

## F. Marketplace

- [x] F1. **[d1v]** Finish the marketplace model (final render was interrupted); check all four photos · **30 min** · d1v, 6 Oct 22:50: `marketplace.py` now runs to the end here (Blender 5.2.2, two minutes): all four photos, `marketplace.fbx` (36 meshes, mesh for mesh the one that was in git), `marketplace.blend` and a fresh `market_manifest.json` (the old one was from an earlier run of the script). Both hero photos looked at: the town is whole
- [x] F2. **[d1v]** `Marketplace.wear`: hook that puts it over the part-built town · **40 min** · d1v, 6 Oct 22:50, in code: `Marketplace.wear` in `src/server/Marketplace.luau`, and `Marketplace.cover()` after the features start. Test `market_wear.luau` (run with `--real-marketplace`, a new switch of the emulator). Not seen in Studio yet (F5)
- [x] F3. **[d1v]** Halloween dress on while the event runs · **15 min** · d1v, 6 Oct 22:50, in code: the season's meshes are kept (`SEASONAL`), the Halloween stall's shell and the event board's shell stand while the event runs. Not seen in Studio yet (F5)
- [x] F4. **[d1v]** Colliders list · **10 min** · d1v, 6 Oct 22:50, in code: the manifest's six Halloween pumpkins are unseen solid boxes (`HALLOWEEN_SOLIDS`); everything else stands on a part of the game's that still collides. Not seen in Studio yet (F5)
- [x] F5. **[d1v]** Import and test **[S]** · **20 min** · d1v, 6 Oct 22:45: `marketplace.fbx` imported under Astral Crafts (Anchored ticked) and filed with `setup_models.luau`: `MarketModels.Market` has 20 meshes, `MarketShells` 16; the other model folders were counted before and after and are as they were. The place's `Server` and `Server.Marketplace` scripts were set to `main`'s (the place had the version before F2). Play test, Halloween on: 724 parts unseen, 18 scenery meshes, 28 shells; looked at from above and from walking height at the hatchery: houses, fountain, stalls, boards, crate stand, Huge pedestal and egg pedestals stand on their spots, the boards' words show. NOT checked: walking into things (colliders), the trading plaza and forge up close, the square outside the event, a phone

## G. Sky, light and sound

- [x] G1. Sky and lighting per place in code (Earth, Moon, Mars, Neptune, The Sun, marketplace) · **1 h 00** Done 6 Oct (d1v): `Effects.updateLighting` gives every place an atmosphere, stars and a tint. The values for Earth, the Moon, Mars, Neptune and The Sun were tried live on their islands in a Studio play test (Mars is peach and hazy, the Moon a starry night, The Sun gold); worlds 6 to 12 take theirs from their backdrop colour. Run in Studio on 6 Oct from a place built from `main`: the atmosphere, sky and tint are made on Earth's base with no error; the marketplace and the other worlds were not looked at through this code. No skybox textures and no clouds: the sky's own colour high up is still Roblox's.
- [x] G2. `UI.sound` helper and button click / window open / error sounds · **30 min** Done 6 Oct (d1v): `UI.sound(name, pitch?)`, `UI.Sounds` and `UI.music` in `src/client/UI.luau`; every kit button clicks, windows whoosh open and shut, a red toast has an error sound.
- [x] G3. Fight sounds: shot, hit, monster pop, boss arrive, level cleared · **30 min** Done 6 Oct (d1v): monster pop, boss arrives, boss defeated, level cleared, level failed. **Shot and hit are hooks with id 0 (silent)**: nothing in Roblox's library was short and quiet enough for twenty a second.
- [x] G4. Hatch sounds: shake, crack, reveal · **20 min** Done 6 Oct (d1v): the egg's rocking (rising in pitch), the crack, the reveal, and bells for a Secret or a Huge. The crate opening's six sounds are set too.
- [x] G5. One music loop for the base, one for the marketplace · **30 min** Done 6 Oct (d1v): Happy Adventure on the base, Happy Shoppers in the marketplace, a calm loop on the islands (APM and Roblox, free for any experience). Run in Studio on 6 Oct from a place built from `main`: every sound and the base's music load (none is blocked or missing), the music plays, no error. **None of G2 to G5 has been heard**: every id was picked by its name and length. Somebody has to play with the sound on and swap what is wrong in `UI.Sounds`. No volume or mute setting yet.
- [x] G6. Switch off Roblox's default health bar and backpack · **5 min**

## I. Launch

- [x] I1. Game icon (512 px) from `docs/ui-vision/game-icon.png` · **20 min** Done 6 Oct (d1v): `assets/page/game-icon-512.png`, the concept art scaled down. **Not uploaded yet** (it goes through moderation: by Friday morning).
- [x] I2. **[d1v]** Three thumbnails · **30 min** · d1v, 7 Oct 10:05: `assets/page/thumbnail-1-marketplace.png`, `thumbnail-2-island.png`, `thumbnail-3-base.png`, each 1920 x 1080, taken in a Studio play test of the group's place with the HUD off (View, Screenshot; cropped to 16:9). No words or logo added. To know: the base one shows the name `D1v991's Base` over the gate and FOR SALE signs on empty pads, and no monsters are on the path (the test save's towers clear a level at once). **Not uploaded** (moderated: by Friday morning)
- [x] I3. Game passes recreated in the group's experience; ids into `Config.luau` **[S]** · **30 min** Done 6 Oct (d1v): six passes on sale in the group's experience at the prices in `Config.Passes`, ids in the config. No icons yet; the six Robux products (Shiny key, Robux crate, four packs) still have id 0.
- [x] I4. **[Yaani]** Refresh `place/ProjectEgg.rbxl` after the last import **[S]** · **5 min** · d1v, 6 Oct 22:31: File, Download a Copy of the group's place, taken right after the import of the 102 mini cannons and 15 eggs (2.8 MB). Refreshed again 6 Oct 22:46, after the marketplace import: it holds every model folder and the code of `main` at bbba446 for the marketplace
- [ ] I5. **[d1v]** Full play-through of worlds 1 to 5 on a phone-sized screen **[S]** · **1 h 00** · **Part done, still d1v's** (7 Oct 10:05). Done on Studio's iPhone XR (896 x 414), with the place's scripts checked equal to `main`: the welcome-back card and CLAIM; the base of each of worlds 1 to 5 (jumped with the debug remote, level 5 of each); the HUD; STORE; the MORE drawer (15 buttons); MINI CANNONS; SETTINGS (the Music switch turned off and on, and the save said so); WORLDS; the Mars island; the marketplace in its Blender town. Nothing was cut off and every button was inside the screen; no error in the output. Found:
  - A Huge mini cannon follows the player and stands between the camera and everything else on a phone: on the base, an island and the marketplace it fills the middle of the screen.
  - Small print too small to read on a phone: the paragraph at the top of MINI CANNONS, a world's rule line in WORLDS (orange on purple), the second line of a STORE row.
  - STORE's gem packs and the rows of MINI CANNONS show a plain coloured disc, not a picture.
  - STATS, VISIT and CODES in the drawer show a letter, not an icon.
  - A tap on a HUD button while a window is open only closes the window; the button needs a second tap.
  - Done 8 Oct 19:15 (d1v), iPhone XR: at the Gem Egg in the marketplace the three prompts (WHAT'S INSIDE?, HATCH, HATCH X3) are tappable and do not overlap; WHAT'S INSIDE? opens LOOT, which fits the screen (the egg's picture there is a plain oval: Q8); HATCH took 60 gems, showed the egg model and the reveal card (Rare, Mini Sapphire Cannon) in the middle of the screen, then gave the prompts back. HATCH X3 not tapped.
  - **Not done:** a new save from level 1 (the tutorial and welcome cards; it needs the test save wiped, which is Victor's to say), buying anything, trading, the frame rate, portrait, a real phone
- [ ] I6. **[Yaani]** Publish **[S]** · **5 min**

## J. Asked for on 7 Oct (Yaani)

- [x] J0. Enchantment keys for gems, no daily limit: 50 gems, Shiny 1,000 gems, in the island shop from The Sun's island on (`Features/IslandShop`). Done 7 Oct (Yaani's side); emulator test passes, not yet seen in Studio.
- [x] J0b. Keys from more places (7 Oct, Yaani's side): Halloween shop sells them for candy (1,000; Shiny 15,000, `Config.EventShop`, new offer kind `item`); Pumpkin and Cursed Crates drop them; Boss Chest drops them twice as often (`Features/Crates`). Emulator test passes, not yet seen in Studio. These are drop rates: balance may want to tune them.
- [x] J1. **[Yaani]** (done 7 Oct: `fuseAll` action and the button in `Features/Fuse`; it uses only mini cannons without enchantments, so none can be lost; emulator test passes, not yet seen in Studio) FUSE window: a **FUSE ALL** button beside FILL / CLEAR / FUSE. One press fuses every set of 3 of the same mini cannon and tier the player has, repeating up the tiers until no set is left; equipped and enchanted ones are kept as the first pick so nothing is lost; a result line says what was made. Server action plus the button (`Features/Fusion`) · **45 min**
- [x] J2. **[Yaani]** STORE window with three tabs: GEMS (six packs for Robux, first one doubled), ITEMS for gems (keys 50 / 1,000, Boss Chest 100, 2x Power and 2x Coins 30) and PASSES. Catalogue `src/shared/Features/Store.luau`, server `src/server/Features/Store.luau`, window in `src/client/Windows.luau`. Done 7 Oct; emulator test passes (1,344 checks); not yet seen in Studio.
- [x] J3. **[Yaani]** (done 7 Oct: six products created, ids in `Store.GemPacks`, Managed Pricing left off; a real purchase has not been tried) Create the six gem pack developer products in the group's experience (Creator Hub > Monetisation > Developer Products; names and Robux prices as in `Store.GemPacks`) and paste each id into its `product = 0`. Until then the GEMS tab shows the packs and answers "not on sale yet" · **20 min**

## K. Islands for worlds 6 to 12 (asked for by Yaani on 7 Oct; stopped once the same day with nothing made; taken again by Yaani on 7 Oct 09:42)

- [x] K1. **[Yaani]** (done 7 Oct: themes, tall props, liquids, fences and set pieces for the seven worlds in `themes.py` and `island.py`; the five finished worlds render the same; not yet imported, see K9) Themes for worlds 6 to 12 in `tools/blender/themes.py`, and their tree, liquid, fence and set pieces in `island.py` · **1 h 00**
- [x] K2. **[Yaani]** (done 7 Oct: `assets/models/islands/the_void_island.*`; colliders in `Islands.SOLIDS`; photos looked at; not yet imported, see K9) The Void island: render, check the photo, colliders into `Islands.SOLIDS` · **25 min**
- [x] K3. **[Yaani]** (done 7 Oct: `nebula_island.*`; colliders in `Islands.SOLIDS`; photos looked at; not yet imported, see K9) Nebula island: render, check the photo, colliders into `Islands.SOLIDS` · **25 min**
- [x] K4. **[Yaani]** (done 7 Oct: `crystal_belt_island.*`; colliders in `Islands.SOLIDS`; photos looked at; not yet imported, see K9) Crystal Belt island: render, check the photo, colliders into `Islands.SOLIDS` · **25 min**
- [x] K5. **[Yaani]** (done 7 Oct: `robot_factory_island.*`; colliders in `Islands.SOLIDS`; photos looked at; not yet imported, see K9) Robot Factory island: render, check the photo, colliders into `Islands.SOLIDS` · **25 min**
- [x] K6. **[Yaani]** (done 7 Oct: `alien_jungle_island.*`; colliders in `Islands.SOLIDS`; photos looked at; not yet imported, see K9) Alien Jungle island: render, check the photo, colliders into `Islands.SOLIDS` · **25 min**
- [x] K7. **[Yaani]** (done 7 Oct: `black_hole_island.*`; colliders in `Islands.SOLIDS`; photos looked at; not yet imported, see K9) Black Hole island: render, check the photo, colliders into `Islands.SOLIDS` · **25 min**
- [x] K8. **[Yaani]** (done 7 Oct: `the_big_bang_island.*`; colliders in `Islands.SOLIDS`; photos looked at; not yet imported, see K9) The Big Bang island: render, check the photo, colliders into `Islands.SOLIDS` · **25 min**
- [x] K9. **[Yaani]** (done. 8 Oct 07:20: all 21 files of worlds 6 to 12 imported, filed with `setup_models.luau` and saved to the group's place: 12 islands, 12 bases, 85 creature templates, nothing left in workspace. Studio crashed once during the base imports; nothing was lost. STILL TO DO: look at each world in a play test. Not published. Then, 8 Oct 15:45, play test in the group's place: the islands of The Void, Nebula, Crystal Belt, Robot Factory, Alien Jungle and Black Hole were visited and each wears its model; The Big Bang's was not caught on screen but its template is in the place. Not published) Import the seven islands and look at each in a play test **[S]** · **45 min**

## L. Bases for worlds 6 to 12 (asked for by Yaani on 7 Oct; taken by Yaani on 7 Oct 19:06)

- [x] L1. **[Yaani]** (done 7 Oct: `base.py` builds all twelve worlds; roofs, knobs, portal glow, backdrop, landmark, props and fence per world, taken from each world's island; the five finished bases build the same; not yet imported, see L9) Base looks for the seven themes in `tools/blender/base.py` (gate, monster portal, backdrop per world; the themes come from K1) · **1 h 00**
- [x] L2. **[Yaani]** (done 7 Oct: `assets/models/bases/the_void_base.*`; photos looked at; not yet imported, see L9) The Void base: render, check the photos · **20 min**
- [x] L3. **[Yaani]** (done 7 Oct: `assets/models/bases/nebula_base.*`; photos looked at; not yet imported, see L9) Nebula base: render, check the photos · **20 min**
- [x] L4. **[Yaani]** (done 7 Oct: `assets/models/bases/crystal_belt_base.*`; photos looked at; not yet imported, see L9) Crystal Belt base: render, check the photos · **20 min**
- [x] L5. **[Yaani]** (done 7 Oct: `assets/models/bases/robot_factory_base.*`; photos looked at; not yet imported, see L9) Robot Factory base: render, check the photos · **20 min**
- [x] L6. **[Yaani]** (done 7 Oct: `assets/models/bases/alien_jungle_base.*`; photos looked at; not yet imported, see L9) Alien Jungle base: render, check the photos · **20 min**
- [x] L7. **[Yaani]** (done 7 Oct: `assets/models/bases/black_hole_base.*`; photos looked at; not yet imported, see L9) Black Hole base: render, check the photos · **20 min**
- [x] L8. **[Yaani]** (done 7 Oct: `assets/models/bases/the_big_bang_base.*`; photos looked at; not yet imported, see L9) The Big Bang base: render, check the photos · **20 min**
- [x] L9. **[Yaani]** (done. 8 Oct 07:20: all 21 files of worlds 6 to 12 imported, filed with `setup_models.luau` and saved to the group's place: 12 islands, 12 bases, 85 creature templates, nothing left in workspace. Studio crashed once during the base imports; nothing was lost. STILL TO DO: look at each world in a play test. Not published. Then, 8 Oct 15:45, play test: all seven bases of worlds 6 to 12 were seen and each wears its model. For about a second after a world changes the part-built base shows before the model is on. Not published) Import the seven bases and see each in a play test **[S]** · **45 min**

## M. Monsters and bosses for worlds 6 to 12 (asked for by Yaani on 7 Oct; taken by Yaani on 7 Oct 19:49)

Each world: its 5 monsters, mid boss and final boss (names in `Config.Worlds`), built with `tools/blender/creatures.py <World>`.

- [x] M1. **[Yaani]** (done 7 Oct: `tools/blender/creature_worlds/the_void.py`, `assets/models/creatures/the_void_creatures.*`; all seven inside the triangle limits, photo looked at; not yet imported, see M8) The Void: 5 monsters and 2 bosses, render, check the photo · **1 h 10**
- [x] M2. **[Yaani]** (done 7 Oct: `tools/blender/creature_worlds/nebula.py`, `assets/models/creatures/nebula_creatures.*`; all seven inside the triangle limits, photo looked at; not yet imported, see M8) Nebula: 5 monsters and 2 bosses, render, check the photo · **1 h 10**
- [x] M3. **[Yaani]** (done 7 Oct: `tools/blender/creature_worlds/crystal_belt.py`, `assets/models/creatures/crystal_belt_creatures.*`; all seven inside the triangle limits, photo looked at; not yet imported, see M8) Crystal Belt: 5 monsters and 2 bosses, render, check the photo · **1 h 10**
- [x] M4. **[Yaani]** (done 7 Oct: `tools/blender/creature_worlds/robot_factory.py`, `assets/models/creatures/robot_factory_creatures.*`; all seven inside the triangle limits, photo looked at; not yet imported, see M8) Robot Factory: 5 monsters and 2 bosses, render, check the photo · **1 h 10**
- [x] M5. **[Yaani]** (done 7 Oct: `tools/blender/creature_worlds/alien_jungle.py`, `assets/models/creatures/alien_jungle_creatures.*`; all seven inside the triangle limits, photo looked at; not yet imported, see M8) Alien Jungle: 5 monsters and 2 bosses, render, check the photo · **1 h 10**
- [x] M6. **[Yaani]** (done 7 Oct: `tools/blender/creature_worlds/black_hole.py`, `assets/models/creatures/black_hole_creatures.*`; all seven inside the triangle limits, photo looked at; not yet imported, see M8) Black Hole: 5 monsters and 2 bosses, render, check the photo · **1 h 10**
- [x] M7. **[Yaani]** (done 7 Oct: `tools/blender/creature_worlds/the_big_bang.py`, `assets/models/creatures/the_big_bang_creatures.*`; all seven inside the triangle limits, photo looked at; not yet imported, see M8) The Big Bang: 5 monsters and 2 bosses, render, check the photo · **1 h 10**
- [x] M8. **[Yaani]** (done. 8 Oct 07:20: all 21 files of worlds 6 to 12 imported, filed with `setup_models.luau` and saved to the group's place: 12 islands, 12 bases, 85 creature templates, nothing left in workspace. Studio crashed once during the base imports; nothing was lost. STILL TO DO: look at each world in a play test. Not published. Then, 8 Oct 15:45, play test: a level ran in each of worlds 6 to 12 with no script error, and a check in the place finds a template for every monster and boss of all twelve worlds. NOT looked at close up, one monster at a time. Not published) Import the seven batches and watch a wave in each world **[S]** · **1 h 00**

## N. Egg opening (asked for by Yaani on 7 Oct; PLAN only, not started, nobody has it yet)

Today the hatch reveal (`Effects.hatch` in `src/client/Effects.luau`) rocks the egg for about 1.4 s and swaps it
for the mini cannon. Where an egg or a mini cannon has no Blender model in the place, a flat coloured circle
shows instead: that is what Yaani saw.

- [x] N1. **[d1v]** Find out which eggs and mini cannons still show as circles: list `ReplicatedStorage.EggModels` and `MiniCannons` in the group's place against `Config.Eggs` and `Config.Pets` **[S]** · **15 min** · d1v, 7 Oct 18:16, counted in the group's place: **14 of 29 eggs** have no model (every coin egg of worlds 6 to 12: `shadowegg` `omegaegg` `nebulaegg` `starlightegg` `shardegg` `geodeegg` `scrapegg` `circuitegg` `jungleegg` `bloomegg` `gravityegg` `warpegg` `cosmicegg` `genesisegg`), and **112 of 214 mini cannons**: the 7 of each of those 14 eggs (5 ordinary and 2 Secrets: 98), the 2 Secrets of each marketplace egg (`gem` `pumpkin` `haunted` `crypt` `bloodmoon`: 10), and 4 Huges (`hugegemstone` `hugepumpkin` `hugetycoon` `hugespectre`). Everything of worlds 1 to 5 has its model
- [x] N2. **[d1v]** (done 8 Oct 16:57: imported under Astral Crafts and filed; the group's place holds 214 mini cannons, 29 eggs and 58 egg halves, every egg has its model and both halves, and ten of the new mini cannons were built with `Models.mini` in a play test and came out whole and in colour. The halves in the place are now the group's own, which settles N5's open point. What was made: `assets/models/minis/late_minis.fbx`, 126 models from `minis.py -- <out> full late`: the 14 eggs and 70 mini cannons of worlds 6 to 12, their 28 Secrets, the 10 Secrets of the marketplace's eggs, and the Gemstone, Pumpkin, Tycoon and Spectre Huges; photos `late_row_<row>.jpg`. Worlds 6 to 12 come from a table in the script (`LATE`), so they are plainer than worlds 1 to 5. `egg_halves.fbx` was made again with `egg_halves.py` for all 29 eggs (58 halves), so it has to be imported again, under Astral Crafts, which also settles N5's open point. `minis.py` now joins each model as it is built: the worlds set builds in 22 s and both old sets still come out mesh for mesh as they were) Model what N1 finds missing, in d1v's style (`minis.py ... worlds`), and import it **[S]** · depends on N1
- [x] N6. **[d1v]** (found 8 Oct while checking N2) 18 mini cannons that no egg hatches still have no model and show the part-built stand-in: `bonedragon` `calendar` `candycorn` `candyskull` `cauldron` `crate` `dragon` `fortune` `jackpot` `mecha` `mimic` `motherlode` `neon` `pumpkinking` `royalguard` `treasure` `vault` `witchinghour` (crates, shops, events and rewards). Model them in `minis.py` and import **[S]** · **1 h 30** · d1v, 8 Oct 17:05: all 18 modelled by hand (`minis.py -- <out> full extras`, `assets/models/minis/extra_minis.fbx`, photos `extra_row_1..4.jpg`), imported under Astral Crafts and filed. The place holds 232 mini cannons and no mini cannon in `Config.Pets` is without a model. `place/ProjectEgg.rbxl` is the place as downloaded at 17:05 with all of this in it. Seen in a play test 8 Oct 19:30 (d1v): all 18 built by `Models.mini` on the client and lined up in front of the camera, each upright, coloured, with its face and barrel; none fell back to the part-built stand-in. Not seen: each one following a player or firing
- [x] N3. **[Yaani]** (done 7 Oct: `tools/blender/egg_halves.py` cuts every finished egg in two, read out of the saved `.blend` files, so `minis.py` is untouched and a new egg gets its halves by running it again; the 15 eggs that exist are in `assets/models/minis/egg_halves.fbx` (look at `egg_halves.png`); `add_minis.luau` files `eggtop_<id>` / `eggbottom_<id>` into `ReplicatedStorage.EggHalves`. NOT imported yet: that is part of N5) Eggs that can open: each egg exported as two meshes, top and bottom, split along a zigzag crack (same pivot), so the game can lift the top off. Needs a change to how eggs are modelled and filed (`minis.py`, `add_minis.luau`) · **1 h 30**
- [x] N4. **[Yaani]** (done 7 Oct in code: `Effects.hatch` hops the egg as it rocks, flashes, throws the top half off, bursts shell pieces, and the mini cannon jumps out with a spin and lands; rays for a Secret or a Huge; an egg without halves throws its whole shell off; a flat stand-in swaps as before. No squash: the egg hops instead. `tests/hatch_open.luau` plays it a frame at a time. NOT seen in Studio: N5) The opening animation in `Effects.hatch`: the egg rocks harder with a squash, cracks (a flash), the top flies off and shell pieces fly out, the mini cannon jumps up out of the bottom half with a spin and lands; rare ones get rays and a longer hold. Works with one-piece eggs too (the whole shell bursts) until N3 lands · **1 h 30**
- [x] N5. **[Yaani]** (done 8 Oct: `egg_halves.fbx` imported into the group's place and filed with `add_minis.luau`, 30 halves for 15 eggs in `ReplicatedStorage.EggHalves`; Yaani hatched in a play test and the opening works. OPEN POINT: the import window offered only "Me" as creator, so the 30 meshes belong to Yaani's account, not the group: d1v re-imports the file under Astral Crafts before launch, or the folder is removed and eggs throw their whole shell off. Not seen on a phone-sized screen) First import `assets/models/minis/egg_halves.fbx` and run `tools/studio/add_minis.luau`, then see it in Studio for one egg of each kind (marketplace, world, a Secret, a Huge) and on a phone-sized screen **[S]** · **20 min**

## O. Things for sale that have no Roblox id yet (7 Oct)

- [x] O1. **[Yaani]** (done 7 Oct: pass 2013380339 created, on sale at 1,499 Robux, Managed Pricing off; a real purchase has not been tried) HUGE Tycoon Cannon game pass, 1,499 Robux: create it in the group's experience and paste its id into `Huge.Pass` (`src/shared/Features/Huge.luau`, `id = 0`). The STORE says "not on sale yet" until then · **15 min**
- [ ] O2. **[open]** Decide and then create or remove the other things still at `product = 0`: the Royal Crate (99 Robux, `Features/Crates`), the three powerup packs (49 / 129 / 399 Robux, `Features/Powerups`) and the old Robux Shiny key (`Enchant.ShinyProduct`, dropped in favour of gems). Not started: needs Yaani's call

## P. MINI CANNONS window, rebuilt from scratch (asked for by Yaani on 7 Oct; PLAN only, not started, nobody has it yet)

Today's window (`petsWindow` in `src/client/Windows.luau`) is a plain list. Yaani wants a full inventory:
equip and unequip, delete, search, "and other features". The mockup is `docs/ui-vision/mini-cannons-window.png`
(a grid of picture cards with a detail pane). Jobs in order; P1 is the only one that needs Yaani.

- [x] P1. **[Yaani]** (done 8 Oct: design at the end of `docs/MINI_CANNON_REVAMP.md`; Yaani said "run p1-9", so the open questions were given defaults there: delete gives nothing back, 3 loadouts, locks without limit) Read today's window and server actions (equip, best, release, storage, slots), then write the design into `docs/MINI_CANNON_REVAMP.md`: layout, every button, what each does, and the open questions for Yaani (below). Yaani says yes before P2 · **30 min**
- [x] P2. **[Yaani]** (done 8 Oct: the card is built in `src/client/Features/Minis.luau` (not yet a shared `UI.card`)) `UI.card`: a picture card with a 3D preview (`UI.preview` + `Models.mini`), rarity frame, count badge, equipped tick, fuse-tier and enchantment marks; reused by this window and later by INDEX and LOOT · **1 h 00**
- [x] P3. **[Yaani]** (done 8 Oct: one card per kind with a count, pooled; the first 30 cards have a 3D picture) The grid: one card per kind of mini cannon the player owns (same kind, tier and enchantments stack with a count), scrolling, built once and reused so 500 stored ones stay smooth · **1 h 30**
- [x] P4. **[Yaani]** (done 8 Oct: EQUIP / UNEQUIP / EQUIP ANOTHER, EQUIP BEST, UNEQUIP ALL; `Game.equipPicker`) Equip and unequip: tap a card, then EQUIP / UNEQUIP in the detail pane; equipped ones first in the grid with a tick; the slots line "5 / 8 equipped"; EQUIP BEST and UNEQUIP ALL buttons. Server actions checked for each (some exist) · **1 h 00**
- [x] P5. **[Yaani]** (done 8 Oct: DELETE 1, DELETE MANY with a count on the button, locks, a second press for precious ones) Delete: DELETE on one, and a delete mode to tick several cards and remove them in one go, with a confirm that names what goes; never an equipped, a Huge, a Secret or an enchanted one without a second confirm; a lock toggle per mini cannon that delete skips · **1 h 15**
- [x] P6. **[Yaani]** (done 8 Oct: search by name, rarity or egg; SORT and SHOW cycle. Not remembered between sessions) Search and sort: a search box (by name), filter chips (rarity, world or egg, enchanted, fused tier), and sort by damage, rarity, newest or name; the choice is remembered · **1 h 00**
- [x] P7. **[Yaani]** (done 8 Oct. FUSE and ENCHANT jump buttons were left out) The detail pane: big 3D preview, name, rarity, damage, enchantments, fuse tier and what the next tier needs, where it hatches, how many owned, and the buttons (equip, delete, lock; FUSE and ENCHANT jump to those machines' islands) · **1 h 00**
- [x] P8. **[Yaani]** (done 8 Oct: three loadouts and the storage bar with the +500 pass button) Other features, DECIDED by Yaani on 7 Oct: (a) **loadouts**: saved sets of equipped mini cannons, save the current set under a slot and switch with one press (how many slots is for P1); (b) **a storage bar**: "183 / 250 stored", turning orange when nearly full, with the +500 Mini Cannon Storage pass offered beside it. NOT wanted for launch: auto-delete while hatching, "new" dots · **1 h 30**
- [x] P9. **[Yaani]** (done 8 Oct: 45 new emulator checks; seen in Studio on a desktop-sized screen: the grid, the detail pane, search, UNEQUIP and EQUIP BEST, pictures in `docs/checks/`. NOT checked: a phone-sized screen, delete and loadouts by hand. Seen while there: the loadout hint is too small to read; the Tycoon and Neon cards show a ball because they have no model) Tests in the emulator for every new action (equip, unequip, delete one and many, lock, search does not change what is owned), then seen in Studio on a desktop and a phone-sized screen **[S]** · **1 h 00**

Open questions for P1: delete gives nothing back, or a few coins or gems? May an equipped one be deleted in one
step? Is there a limit on locks? How many loadout slots?

## Q. Icons for every item in the game (asked for by Yaani on 7 Oct; PLAN only, not started, nobody has it yet)

Yaani's screenshots of the STORE: every row (passes, gem packs, keys, Boss Chest, boosts) shows a plain
coloured oval where its picture should be. The same oval is the stand-in everywhere a row is built with
`UI.row`. Every item needs a real icon. Today 32 icons exist (atlases A and B, `UI.icon`, `assets/ui/`);
sheets C to E in `docs/UI_VISION.md` section 8 were planned and never made.

- [x] Q1. **[Yaani]** (done 7 Oct: `docs/ICONS.md`, about 95 icons on six sheets C to H) The list: every thing that shows an oval or an emoji today, from the code: game passes, gem packs, STORE items, backpack items (`Items.get`: powerups, keys, chests, crates, ammo), currencies, island shop rows, Halloween and weekly shop offers, missions, daily rewards, worlds, towers, boosts, enchantments, mastery tracks, menu buttons. Written into `docs/ICONS.md` with a name per icon and which sheet it goes on · **45 min**
- [x] Q2. **[Yaani]** (Yaani said yes on 7 Oct: six painted sheets, about 120 Kling credits; mini cannons and eggs keep their 3D previews) Decide per kind how the picture is made (in `docs/ICONS.md`): painted icons on atlas sheets (Kling, about 20 credits a sheet, same Candy Arcade style as sheets A and B) for flat things (boosts, currencies, passes, missions); a 3D render from the Blender model for things that have one (mini cannons, eggs, crates, chests, keys, towers). Yaani says yes before Q3 · **20 min**
- [x] Q3. **[Yaani]** (done 7 Oct: `assets/ui/atlas-c.png`) Sheet C: boosts, powerups and passes (2x Power, 2x Coins, 2x Luck, Mega Luck, Auto, Mega Damage, Heal Freeze, Supercharge, x3 Egg Opener, x3 Luck, slots, storage, 3x Speed, Huge) · **40 min**
- [x] Q4. **[Yaani]** (done 7 Oct: `assets/ui/atlas-d.png`; it came back with a dark tile behind each icon, cut off with a higher tolerance, a faint dark fringe is left on a few) Sheet D: gems and shop things (six gem pack sizes from a few gems to a mountain, Enchantment Key, Shiny Enchantment Key, Boss Chest, Daily Crate, Wooden, Gem, Royal, Pumpkin and Cursed Crates, candy) · **40 min**
- [x] Q5. **[Yaani]** (done 7 Oct: `assets/ui/atlas-e.png`) Sheet E: ammo kinds, and the twelve world medallions · **40 min**
- [x] Q5b. **[Yaani]** (done 7 Oct: `atlas-f.png`, `atlas-g.png`, `atlas-h.png`. Weak: H's enchantments came out as glowing icons without the white sticker edge, a different look from the rest; F's fusion icon reads as a gatling gun. Not regenerated: Yaani's call) Sheets F (worlds and places), G (towers) and H (enchantments), as listed in `docs/ICONS.md` · **1 h 30**
- [x] Q6. **[d1v]** Done 8 Oct 19:05 (d1v). The six sheets `assets/ui/atlas-c.png` to `atlas-h.png` are uploaded to Astral Crafts as Images through Studio's Asset Manager (Creator Hub is behind Roblox's "Updated Agreements" dialog, which d1v still has to answer himself), approved by Roblox, and their ids are in `UI.Atlases` in `src/client/UI.luau` and in the place's copy of that script: c 103062879865504, d 78392187816203, e 73148987143993, f 92148934171613, g 89245700421390, h 133537584728505. Seen in a play test: the WORLDS window draws the Earth, Moon and Mars icons from sheet F, and the client holds image labels on all six sheets. Not looked at one by one: every icon of sheets C, D, E, G, H (that is Q10). Was: Cut each sheet into its atlas (`tools/icon_atlas.py`), upload to the group (Astral Crafts) and add the names to `UI.Atlases` / `UI.icon` **[S]** · **30 min**
- [x] Q7. **[Yaani]** (done 8 Oct: `row.setIcon` is used by STORE, ISLAND SHOP, BACKPACK (items, crates, ammo, bundles), SHOP (weekly and Halloween), MISSIONS, WORLDS and the TOWER list; `ICON_ALIASES` in `UI.luau` maps item ids to icon names. Nothing shows until Q6's image ids are in. Left with ovals on purpose: mini cannon rows (FUSE, ENCHANT, TRADE), MASTERY, SETTINGS, VISIT)
- [ ] Q8. **[d1v]** (taken: d1v, 8 Oct 19:40) Go through every window and replace what is left: STORE, ISLAND SHOP, SHOP, BACKPACK, AMMO, CRATES, LOOT, MISSIONS, DAILY, WORLDS, the HUD chips and the notifications' emoji · **1 h 30**
- [ ] Q9. **[open]** Pictures for the Roblox purchase prompts: upload an icon to each of the six gem packs and the seven game passes in Creator Hub (they are blank today) **[S]** · **30 min**
- [ ] Q10. **[open]** Seen in Studio: every window on a desktop and a phone-sized screen, no oval or emoji left **[S]** · **30 min**

## After launch

Fight effects, tower and pad models, emoji to icons, MINI CANNONS and STORE windows (cut from launch on
6 Oct), the remaining feature windows, Auto Hatch and Fast Hatch passes,
Huge models, mini cannons for worlds 2 to 12.
