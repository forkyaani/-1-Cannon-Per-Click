# Mini cannon and egg revamp: the map

Written 5 Oct 2026. Exemplar: Pets Universe (cute cube pets, tap-to-hatch eggs, clean white result cards).
Status: plan only. Nothing here is built except the Blender pipeline, proven on six monsters
(`tools/blender/`, `assets/models/`).

## Where we are

| Thing | Today | Problem |
|---|---|---|
| Mini cannons (roughly 150) | Every one is the same grey-wheeled cylinder with two eyes. Only the colour and a glow change | Nothing to want. A Legendary looks like a Common in a different colour |
| Where they are drawn | Three separate copies of the same builder: `Plots.buildPets`, `Loot.buildMini`, `Features/Huge` | Any new look has to be made three times |
| Eggs (29: two per world, Gem, four Halloween) | A cream ellipsoid with spots in the egg's colour | All eggs read as the same egg |
| Hatching | Press E, a text card appears with the name and chance | No moment. The exemplar's whole hook is this moment |
| Inventory | A list of text rows | No pictures, so the collection has no pull |

## The look

**Mini cannons become "cannon critters":** a rounded cube creature with big glossy eyes (the same family as
the new monsters), whose identity is still a cannon: a stubby barrel for a snout or on its back, two little
wheels or feet, a fuse for a tail. One glance says both "pet" and "cannon".

What tells them apart:

| Layer | What changes | Example |
|---|---|---|
| Species (the egg it comes from) | Body shape, ears, tail, barrel style | Earth egg: cat, dog, bunny, bear, fox. Moon egg: alien, astronaut, rock, bat, star |
| Rarity | Extras, not just colour | Common: plain. Rare: hat or scarf. Epic: wings or horns. Legendary: crown, glow, particles |
| Fuse tier (Silver, Gold, Diamond) | Material and trim | Silver bands, gold body shine, diamond sparkle |
| Huge and Secret | Size and an aura | Three times the size, halo, trail |

**Eggs** get one design per family instead of one shape for all: a grass egg with a leaf for Earth, a
cratered egg for Moon, a crystal egg for Gem, a pumpkin for Halloween. Rarer eggs get a ribbon, wings or a glow.

## The pieces, in build order

| # | Piece | What it is | Size |
|---|---|---|---|
| 1 | **Style sample** | Five critters from one egg, plus that egg, modelled in Blender and standing in Studio. Nothing else is built until this looks right | Small |
| 2 | **Parts library** | The Blender script grows a kit: about 12 bodies, 10 ear and horn sets, 6 barrels, 12 hats and extras. A critter is a recipe that picks from the kit, so 150 of them are 150 short recipes, not 150 sculpts | Medium |
| 3 | **One builder in the game** | `Models.mini(pet)` replaces the three copies. Reads a template from `ReplicatedStorage`, tints it, adds fuse trim, falls back to today's cylinder for any pet without a template | Medium |
| 4 | **Roll-out by egg** | Earth's two eggs first (10 critters), then world by world. The game works at every step because of the fallback | Large, but repetitive |
| 5 | **Egg models and stands** | One egg model per family, a nicer stand, the egg bobs and glows when you can afford it | Medium |
| 6 | **The hatch moment** | Egg flies to the middle of the screen, wobbles, tap to crack (or auto), bursts, the critter drops in with its card: picture, name, rarity, "1 in 2,000", EQUIP. x3 hatch shows three eggs. A skip setting for grinders | Medium |
| 7 | **Inventory and index** | A card grid with real pictures of each critter, EQUIP BEST, lock, mass delete, and an index page that shows silhouettes of what you have not found | Medium |
| 8 | **Life** | They hop or waddle behind you, look at what they shoot, bounce when they fire. Whole-body movement in code, no skeletons | Small |

## What is not in this revamp

- The numbers: chances, power, prices and luck stay as they are. Only how odds are shown changes ("1 in 2,000"
  beside the percentage).
- Towers and monsters. Monsters already have their own new models.
- Trading, fusing and enchanting rules. Their windows get the new pictures for free from piece 7.

## Risks worth knowing

| Risk | How the plan deals with it |
|---|---|
| 150 unique models is a lot | The kit (piece 2): variety comes from combining parts. Only Legendary and above get one-off parts |
| Frame rate: six players with 12 critters each is 72 models moving | Each critter is joined into 3 to 5 meshes (body, face, trim), not 30 loose parts like the monster test. A budget of about 1,500 triangles each |
| Every mesh is uploaded to the Roblox account and moderated | Joined meshes keep this to a few hundred uploads in total instead of thousands |
| Scripted shapes look clean but simple | Accept it for Common to Epic; spend hand time on Legendary, Secret and Huge, which are the ones players screenshot |
| The other session owns `Config`, `Plots` and `Game` | Piece 3 is one new function plus three small call-site changes, agreed with it first |

## Decisions (Yaani, 5 Oct 2026)

1. **They stay cannons:** mini cannons, as cannon critters (a creature with wheels, a barrel and a fuse).
2. **Marketplace eggs first:** the Gem Egg and the four Halloween eggs (Pumpkin, Haunted, Crypt, Blood Moon)
   and their 25 mini cannons are the style sample and the first roll-out. World eggs follow.
3. **Hatching is a slow automatic open**, no tapping. Auto Hatch and Fast Hatch come later as game passes.
