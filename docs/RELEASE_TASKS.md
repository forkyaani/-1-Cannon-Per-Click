# Release task list: Saturday 10 Oct 2026

Visuals, UX and Blender models for launch. Small jobs, ticked off as they land. Each job ends with a push to
git. **[S]** marks a job that needs Roblox Studio (import, test or publish): d1v or Yaani in the group's place.
Written 5 Oct 2026. Background: `docs/VISUAL_AUDIT.md`, `docs/UI_VISION.md`, `docs/MINI_CANNON_REVAMP.md`.

Order of work: A, B, C, D per world (Earth, Moon, Mars, Neptune, The Sun), then E, F, G and I.

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

- [ ] A1. `tools/blender/kit.py`: move the shared kit (box, ball, tube, lathe, mat, export) out of the island script · **30 min**
- [ ] A2. Theme table for the 5 worlds: ground, rock, plant, accent and sky colours, prop kinds (craters, spires, ice, lava) · **20 min**
- [ ] A3. `earth_island.py` becomes `island.py <world>`: same layout, look from the theme · **45 min**
- [ ] A4. `earth_base.py` becomes `base.py <world>`: same path and pads, look from the theme · **45 min**
- [ ] A5. `creatures.py <world>`: one run makes a world's 5 monsters and 2 bosses as one .fbx · **1 h 00**
- [x] A6. One Studio setup script (`tools/studio/setup_models.luau`) that turns any imported .fbx into its templates **[S]** · **30 min**
- [x] A7. Short import guide for d1v in `place/README.md` · **10 min**

## B. Bases (the first thing every player sees)

- [ ] B1. Finish the Earth base model (road, 16 pads, gate, monster portal, teleporters, backdrop) · **40 min**
- [ ] B2. `Plots.wear`: hook that puts a base model over the part-built base (keep pads, prompts, signs, walls) · **40 min**
- [ ] B3. Colliders list for the Earth base · **10 min**
- [ ] B4. Import and test the Earth base **[S]** · **20 min**
- [ ] B5. Moon base: theme, render, check the photo · **20 min**
- [ ] B6. Moon base: import and test **[S]** · **15 min**
- [ ] B7. Mars base: theme, render, check the photo · **20 min**
- [ ] B8. Mars base: import and test **[S]** · **15 min**
- [ ] B9. Neptune base: theme, render, check the photo · **20 min**
- [ ] B10. Neptune base: import and test **[S]** · **15 min**
- [ ] B11. The Sun base: theme, render, check the photo · **20 min**
- [ ] B12. The Sun base: import and test **[S]** · **15 min**

## C. Islands

- [x] C1. Earth island (live)
- [ ] C2. Moon island: theme, render, check the photo · **20 min**
- [ ] C3. Moon island: colliders list in `Islands.SOLIDS` · **10 min**
- [ ] C4. Moon island: import and test **[S]** · **15 min**
- [ ] C5. Mars island: theme, render, check the photo · **20 min**
- [ ] C6. Mars island: colliders list in `Islands.SOLIDS` · **10 min**
- [ ] C7. Mars island: import and test **[S]** · **15 min**
- [ ] C8. Neptune island: theme, render, check the photo · **20 min**
- [ ] C9. Neptune island: colliders list in `Islands.SOLIDS` · **10 min**
- [ ] C10. Neptune island: import and test **[S]** · **15 min**
- [ ] C11. The Sun island: theme, render, check the photo · **20 min**
- [ ] C12. The Sun island: colliders list in `Islands.SOLIDS` · **10 min**
- [ ] C13. The Sun island: import and test **[S]** · **15 min**

## D. Monsters and bosses

- [x] D1. Earth's 5 monsters (live)
- [ ] D2. `Models.creatureFor`: each boss uses its own model, not the shared one · **15 min**
- [ ] D3. Earth boss: Ogre Chief · **10 min**
- [ ] D4. Earth boss: Earth Titan · **10 min**
- [ ] D5. Earth: import the batch and test a wave **[S]** · **20 min**
- [ ] D6. Moon: Moon Rockling · **10 min**
- [ ] D7. Moon: Crater Crawler · **10 min**
- [ ] D8. Moon: Lunar Bat · **10 min**
- [ ] D9. Moon: Astro Ghost · **10 min**
- [ ] D10. Moon: Moon Golem · **10 min**
- [ ] D11. Moon boss: Dark Side Stalker · **10 min**
- [ ] D12. Moon boss: Moon Colossus · **10 min**
- [ ] D13. Moon: import the batch and test a wave **[S]** · **20 min**
- [ ] D14. Mars: Martian Grunt · **10 min**
- [ ] D15. Mars: Sand Worm · **10 min**
- [ ] D16. Mars: Red Scorpion · **10 min**
- [ ] D17. Mars: Dust Devil · **10 min**
- [ ] D18. Mars: Rover Bot · **10 min**
- [ ] D19. Mars boss: Martian Warlord · **10 min**
- [ ] D20. Mars boss: Olympus Guardian · **10 min**
- [ ] D21. Mars: import the batch and test a wave **[S]** · **20 min**
- [ ] D22. Neptune: Frost Imp · **10 min**
- [ ] D23. Neptune: Snow Blob · **10 min**
- [ ] D24. Neptune: Ice Wraith · **10 min**
- [ ] D25. Neptune: Glacier Crab · **10 min**
- [ ] D26. Neptune: Yeti · **10 min**
- [ ] D27. Neptune boss: Blizzard Wraith · **10 min**
- [ ] D28. Neptune boss: Frost Giant · **10 min**
- [ ] D29. Neptune: import the batch and test a wave **[S]** · **20 min**
- [ ] D30. The Sun: Magma Blob · **10 min**
- [ ] D31. The Sun: Fire Imp · **10 min**
- [ ] D32. The Sun: Lava Crab · **10 min**
- [ ] D33. The Sun: Flare Spirit · **10 min**
- [ ] D34. The Sun: Cinder Golem · **10 min**
- [ ] D35. The Sun boss: Inferno Hound · **10 min**
- [ ] D36. The Sun boss: Solar Titan · **10 min**
- [ ] D37. The Sun: import the batch and test a wave **[S]** · **20 min**

## E. Eggs and mini cannons

- [ ] E1. Test the egg prompts (E / R / F, no popup) **[S]** · **15 min**
- [ ] E2. Check the "what's inside" window on an egg; fix what looks poor · **30 min**
- [ ] E3. Earth: Basic Egg and Forest Egg models · **20 min**
- [ ] E4. Earth: the mini cannons of those two eggs · **1 h 00**
- [ ] E5. Eggs for worlds 2 to 5 (2 each): recolours of one egg design · **30 min**
- [ ] E6. Mini cannons for worlds 2 to 5: after launch unless time is left · **3 h 00**
- [ ] E7. Import eggs and mini cannons **[S]** · **20 min**

## F. Marketplace

- [ ] F1. Finish the marketplace model (final render was interrupted); check all four photos · **30 min**
- [ ] F2. `Marketplace.wear`: hook that puts it over the part-built town · **40 min**
- [ ] F3. Halloween dress on while the event runs · **15 min**
- [ ] F4. Colliders list · **10 min**
- [ ] F5. Import and test **[S]** · **20 min**

## G. Sky, light and sound

- [ ] G1. Sky and lighting per place in code (Earth, Moon, Mars, Neptune, The Sun, marketplace) · **1 h 00**
- [ ] G2. `UI.sound` helper and button click / window open / error sounds · **30 min**
- [ ] G3. Fight sounds: shot, hit, monster pop, boss arrive, level cleared · **30 min**
- [ ] G4. Hatch sounds: shake, crack, reveal · **20 min**
- [ ] G5. One music loop for the base, one for the marketplace · **30 min**
- [ ] G6. Switch off Roblox's default health bar and backpack · **5 min**

## I. Launch

- [ ] I1. Game icon (512 px) from `docs/ui-vision/game-icon.png` · **20 min**
- [ ] I2. Three thumbnails · **30 min**
- [ ] I3. Game passes recreated in the group's experience; ids into `Config.luau` **[S]** · **30 min**
- [ ] I4. Refresh `place/ProjectEgg.rbxl` after the last import **[S]** · **5 min**
- [ ] I5. Full play-through of worlds 1 to 5 on a phone-sized screen **[S]** · **1 h 00**
- [ ] I6. Publish **[S]** · **5 min**

## After launch

Fight effects, tower and pad models, emoji to icons, MINI CANNONS and STORE windows (cut from launch on
6 Oct), worlds 6 to 12 (monsters, islands, bases), the remaining feature windows, Auto Hatch and Fast Hatch passes,
Huge models, mini cannons for worlds 2 to 12.
