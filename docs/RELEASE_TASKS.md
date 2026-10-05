# Release task list: Saturday 10 Oct 2026

Visuals, UX and Blender models for launch. Small jobs, ticked off as they land. Each job ends with a push to
git. **[S]** marks a job that needs Roblox Studio (import, test or publish): d1v or Yaani in the group's place.
Written 5 Oct 2026. Background: `docs/VISUAL_AUDIT.md`, `docs/UI_VISION.md`, `docs/MINI_CANNON_REVAMP.md`.

Order of work: A, B, C, D per world (Earth, Moon, Mars, Neptune, The Sun), then E to I.

## A. Pipeline (do once, makes everything after it fast)

- [ ] A1. `tools/blender/kit.py`: move the shared kit (box, ball, tube, lathe, mat, export) out of the island script
- [ ] A2. Theme table for the 5 worlds: ground, rock, plant, accent and sky colours, prop kinds (craters, spires, ice, lava)
- [ ] A3. `earth_island.py` becomes `island.py <world>`: same layout, look from the theme
- [ ] A4. `earth_base.py` becomes `base.py <world>`: same path and pads, look from the theme
- [ ] A5. `creatures.py <world>`: one run makes a world's 5 monsters and 2 bosses as one .fbx
- [ ] A6. One Studio setup script (`tools/studio/setup_models.luau`) that turns any imported .fbx into its templates **[S]**
- [ ] A7. Short import guide for d1v in `place/README.md`

## B. Bases (the first thing every player sees)

- [ ] B1. Finish the Earth base model (road, 16 pads, gate, monster portal, teleporters, backdrop)
- [ ] B2. `Plots.wear`: hook that puts a base model over the part-built base (keep pads, prompts, signs, walls)
- [ ] B3. Colliders list for the Earth base
- [ ] B4. Import and test the Earth base **[S]**
- [ ] B5. Moon base: theme, render, check the photo
- [ ] B6. Moon base: import and test **[S]**
- [ ] B7. Mars base: theme, render, check the photo
- [ ] B8. Mars base: import and test **[S]**
- [ ] B9. Neptune base: theme, render, check the photo
- [ ] B10. Neptune base: import and test **[S]**
- [ ] B11. The Sun base: theme, render, check the photo
- [ ] B12. The Sun base: import and test **[S]**

## C. Islands

- [x] C1. Earth island (live)
- [ ] C2. Moon island: theme, render, check the photo
- [ ] C3. Moon island: colliders list in `Islands.SOLIDS`
- [ ] C4. Moon island: import and test **[S]**
- [ ] C5. Mars island: theme, render, check the photo
- [ ] C6. Mars island: colliders list in `Islands.SOLIDS`
- [ ] C7. Mars island: import and test **[S]**
- [ ] C8. Neptune island: theme, render, check the photo
- [ ] C9. Neptune island: colliders list in `Islands.SOLIDS`
- [ ] C10. Neptune island: import and test **[S]**
- [ ] C11. The Sun island: theme, render, check the photo
- [ ] C12. The Sun island: colliders list in `Islands.SOLIDS`
- [ ] C13. The Sun island: import and test **[S]**

## D. Monsters and bosses

- [x] D1. Earth's 5 monsters (live)
- [ ] D2. `Models.creatureFor`: each boss uses its own model, not the shared one
- [ ] D3. Earth boss: Ogre Chief
- [ ] D4. Earth boss: Earth Titan
- [ ] D5. Earth: import the batch and test a wave **[S]**
- [ ] D6. Moon: Moon Rockling
- [ ] D7. Moon: Crater Crawler
- [ ] D8. Moon: Lunar Bat
- [ ] D9. Moon: Astro Ghost
- [ ] D10. Moon: Moon Golem
- [ ] D11. Moon boss: Dark Side Stalker
- [ ] D12. Moon boss: Moon Colossus
- [ ] D13. Moon: import the batch and test a wave **[S]**
- [ ] D14. Mars: Martian Grunt
- [ ] D15. Mars: Sand Worm
- [ ] D16. Mars: Red Scorpion
- [ ] D17. Mars: Dust Devil
- [ ] D18. Mars: Rover Bot
- [ ] D19. Mars boss: Martian Warlord
- [ ] D20. Mars boss: Olympus Guardian
- [ ] D21. Mars: import the batch and test a wave **[S]**
- [ ] D22. Neptune: Frost Imp
- [ ] D23. Neptune: Snow Blob
- [ ] D24. Neptune: Ice Wraith
- [ ] D25. Neptune: Glacier Crab
- [ ] D26. Neptune: Yeti
- [ ] D27. Neptune boss: Blizzard Wraith
- [ ] D28. Neptune boss: Frost Giant
- [ ] D29. Neptune: import the batch and test a wave **[S]**
- [ ] D30. The Sun: Magma Blob
- [ ] D31. The Sun: Fire Imp
- [ ] D32. The Sun: Lava Crab
- [ ] D33. The Sun: Flare Spirit
- [ ] D34. The Sun: Cinder Golem
- [ ] D35. The Sun boss: Inferno Hound
- [ ] D36. The Sun boss: Solar Titan
- [ ] D37. The Sun: import the batch and test a wave **[S]**

## E. Eggs and mini cannons

- [ ] E1. Test the egg prompts (E / R / F, no popup) **[S]**
- [ ] E2. Check the "what's inside" window on an egg; fix what looks poor
- [ ] E3. Earth: Basic Egg and Forest Egg models
- [ ] E4. Earth: the mini cannons of those two eggs
- [ ] E5. Eggs for worlds 2 to 5 (2 each): recolours of one egg design
- [ ] E6. Mini cannons for worlds 2 to 5: after launch unless time is left
- [ ] E7. Import eggs and mini cannons **[S]**

## F. Marketplace

- [ ] F1. Finish the marketplace model (final render was interrupted); check all four photos
- [ ] F2. `Marketplace.wear`: hook that puts it over the part-built town
- [ ] F3. Halloween dress on while the event runs
- [ ] F4. Colliders list
- [ ] F5. Import and test **[S]**

## G. Sky, light and sound

- [ ] G1. Sky and lighting per place in code (Earth, Moon, Mars, Neptune, The Sun, marketplace)
- [ ] G2. `UI.sound` helper and button click / window open / error sounds
- [ ] G3. Fight sounds: shot, hit, monster pop, boss arrive, level cleared
- [ ] G4. Hatch sounds: shake, crack, reveal
- [ ] G5. One music loop for the base, one for the marketplace
- [ ] G6. Switch off Roblox's default health bar and backpack

## H. The fight and the HUD (if time is left)

- [ ] H1. Shot trails and muzzle flash
- [ ] H2. Hit burst and monster death pop
- [ ] H3. Coins fly to the coin counter
- [ ] H4. Tower models: the 8 kinds as Blender models
- [ ] H5. Pad model with its three states
- [ ] H6. Emoji swapped for the 32 atlas icons
- [ ] H7. MINI CANNONS window as picture cards
- [ ] H8. STORE window to its mockup

## I. Launch

- [ ] I1. Game icon (512 px) from `docs/ui-vision/game-icon.png`
- [ ] I2. Three thumbnails
- [ ] I3. Game passes recreated in the group's experience; ids into `Config.luau` **[S]**
- [ ] I4. Refresh `place/ProjectEgg.rbxl` after the last import **[S]**
- [ ] I5. Full play-through of worlds 1 to 5 on a phone-sized screen **[S]**
- [ ] I6. Publish **[S]**

## After launch

Worlds 6 to 12 (monsters, islands, bases), the remaining feature windows, Auto Hatch and Fast Hatch passes,
Huge models, mini cannons for worlds 2 to 12.
