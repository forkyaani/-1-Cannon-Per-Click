"""A world's island: a floating island in the chunky, rounded simulator style, made to stand in for the
island the game builds from parts (src/server/Islands.luau) without moving any of its spots. Every world
has the same layout; its look comes from tools/blender/themes.py.

Run: blender --background --python tools/blender/island.py -- <World> <output folder> [draft] [clutter]
     <World> is "Earth", "Moon", "Mars", "Neptune" or "The Sun" (the_sun and TheSun are understood too)

Island space is the game's: the arrival pad in the middle, 1 unit is 1 stud, the ground's top is z = 0,
x is east and +Y is north (the game's z is -y here). 0 degrees is north, 90 east. Where things stand is
copied from Islands.luau: eggs at ring(-25, 15) and ring(25, 15), the stall at ring(75, 15), the portal at
ring(140, 15), the enchant and mastery spots at ring(207, 16) and ring(282, 16), lamps at 36, the boss's
statue at ring(0, 44), a monster's statue at ring(270, 47) and ring(90, 47). A player gets 55.6 from the
middle; the ground is level that far and ends a little past the game's 58.

What the theme changes: every colour of ground, rock, paving, stone and timber; the liquid in the pond
(water, a glowing stardust pool, an oasis with a palm, ice, lava); the tall props where Earth has trees
(`tree`); the rim's `fence`; the lamps' and fires' glow; the portal; the photos' sky. And the two set
pieces, on the same two spots with the same footprints:
    Earth    a cannon and a campfire          Moon     a lander and a radar dish
    Mars     a rover wreck and a habitat      Neptune  a snowman and an igloo
    The Sun  a forge and a volcano vent
The floor stays clean: only Earth has bushes, rocks by the fence and stepping stones (as it always had),
and `clutter` (Earth's small ground dressing) is off unless asked for. The other worlds have no scatter.

Writes into the output folder, <world> being the name in small letters with _ for spaces (the_sun):
  <world>_island_hero.png, <world>_island_ground.png   the two photos
  <world>_island_solids.txt   the solid things, as a table for SOLIDS in Islands.luau (also printed)
  <world>_island.blend, <world>_island.fbx   with these meshes, colours on the vertices as minis.py does.
  <Prefix> is the world's name without spaces (Earth, TheSun):
  scenery, shown as it is, all with the island's middle (on the ground) as origin:
      <Prefix>_Island  _Paths  _FloatingRocks  _Trees  _Plants (Earth)  _Dressing
      _Glow (for Neon; a liquid that glows, stardust and lava, is in here)  _Water (for Glass)
  landmark shells, each with the middle of its own base as origin and its front towards -Y:
      _EggPedestal (one, no egg: the cushion's top is CUSHION_TOP up)  _Stall
      _Portal  _PortalSheet (same origin as the portal)
      _BossPlinth (no statue: PLINTH_TOP high, 18 across)
  two markers for tools/studio/setup_models.luau, not in the photos:
      _Origin (a 2 x 2 x 2 cube, its middle 1 above the scene's origin)  _North (the same at (0, 10, 1))
The eggs and the statue in the photos are stand-ins and are not exported; neither are the clouds.
`draft` makes the photos at half size, for a quick look. `clutter` puts Earth's small ground dressing back
(see CLUTTER).

Earth's island is, piece for piece, the one earth_island.py made: every theme branch leaves Earth's pieces
and the order of its random numbers alone. Keep it so, the live island is this model.

The kit is tools/blender/kit.py (box, ball, tube, lathe, colours from hex codes, groups, photos, export).
Its pieces are made with bmesh instead of operators: the island has some 1,300 pieces, and an operator
gets slower with every object already in the scene.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import *
from themes import THEMES

GIVEN = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WORLD = next((name for name in THEMES if GIVEN and name.lower().replace(" ", "") == GIVEN[0].lower().replace(" ", "").replace("_", "")), None)
if WORLD is None or len(GIVEN) < 2:
    raise SystemExit(f"island.py -- <World> <output folder> [draft] [clutter]   worlds: {', '.join(THEMES)}")
OUT, ARGS = GIVEN[1], GIVEN[2:]
THEME = THEMES[WORLD]
EARTH = WORLD == "Earth"
SLUG = WORLD.lower().replace(" ", "_") + "_island"  # the files' name
DRAFT = "draft" in ARGS
# The small things on the ground: flowers, tufts of grass, mushrooms, tubs, cobbles on the plaza, the pumpkin
# patch, most rocks and the bushes round the plaza. Off since 2026-10-05: Yaani found the floor too crowded.
# The trees, the fence, the lamps, the pond, the cannon and the campfire are not part of it.
CLUTTER = "clutter" in ARGS and EARTH  # only Earth has any: the other worlds get no scatter at all

# Pieces are collected per group: a group becomes one mesh. In the scenery anything that glows goes to the
# group "Glow" and the water to "Water", so that in Roblox those two meshes can be given Neon and Glass. A
# landmark's shell keeps its own glowing bits.
SCENERY = ("Island", "Paths", "FloatingRocks", "Trees", "Plants", "Dressing", "Water", "Glow")
RENDER_ONLY = ("Placeholders", "Backdrop")  # in the photos, not in the export
kit.init(seed=7, prefix=WORLD.replace(" ", "") + "_", scenery=SCENERY, render_only=RENDER_ONLY)  # the same "random" island every run

GRASS, GRASS_LIGHT, GRASS_DEEP, GRASS_RIM = (THEME[key] for key in ("grass", "grass_light", "grass_deep", "grass_rim"))
DIRT, DIRT_DARK = THEME["dirt"], THEME["dirt_dark"]
ROCK, ROCK_DARK, ROCK_LIGHT = THEME["rock"], THEME["rock_dark"], THEME["rock_light"]
UNDER, UNDER_DARK, UNDER_LIGHT = THEME["under"], THEME["under_dark"], THEME["under_light"]  # the rock under the island
SAND, SAND_DARK, COBBLE = THEME["sand"], THEME["sand_dark"], THEME["cobble"]
STONE, STONE_DARK, STONE_PALE = THEME["stone"], THEME["stone_dark"], THEME["stone_pale"]
WOOD, WOOD_LIGHT, WOOD_DARK = THEME["wood"], THEME["wood_light"], THEME["wood_dark"]
WATER, WATER_LIGHT = THEME["water"], THEME["water_light"]
LEAVES, PETALS = THEME["leaves"], THEME["petals"]
ACCENT, ACCENT_PALE = THEME["accent"], THEME["accent_pale"]
TREE, LIQUID, FENCING = THEME["tree"], THEME["liquid"], THEME["fence"]
WHITE, INK, GOLD, GOLD_DARK = "FFFFFF", "1B1140", "FFC61A", "E09A12"  # the same in every world
IRON, RED, BLUE = "4A4763", "FF4D4D", "3FA9FF"
# What is not in the theme table, by world. Earth's are what earth_island.py had.
POST = IRON if EARTH else WOOD_DARK  # a lamp's post
LAMP_GLOW = "FFE9A8" if EARTH else ACCENT_PALE
FLAME = {"Moon": ("7FB4FF", "D2E4FF"), "Neptune": ("6EE6FF", "D0F8FF"), "The Sun": ("FF5A1A", "FFD23A")}.get(WORLD, ("FF8A1F", "FFD83A"))  # a fire's body and its tip
AWNING = {"Moon": "FF7AB8", "Mars": "35D6C4", "Neptune": "FF5A7A", "The Sun": "E0407A"}.get(WORLD, RED)  # the stall's stripes
PAD = ("35CFFF", "8DE8FF") if EARTH else (ACCENT, ACCENT_PALE)  # the arrival pad's light
CLOUD = {"Moon": "B7AEF0", "Mars": "FFE9D0", "The Sun": "FFF3B0"}.get(WORLD, WHITE)
WET = {"roughness": 0.15, **({"emission": {"stardust": 1.0, "lava": 1.6}[LIQUID]} if LIQUID in ("stardust", "lava") else {})}  # how the liquid looks; glowing, it lands in "Glow"

# ---------------------------------------------------------------------------------------------------
# The island's shape and the game's layout, and standing things on it
# ---------------------------------------------------------------------------------------------------
RADIUS = 59.2  # of the grass top. The game's ground is 58 (Layout.ISLAND_RADIUS): the grass hangs a stud or two over it
WALK = 55.6  # as far from the middle as a player gets: the game's rim wall starts here
FLAT = 0.953  # the share of the way to the edge that the grass stays level: past WALK in every direction
FENCE = 56.6  # the fence stands where the game's wall does
PLAZA = 25  # the paving under the ring of landmarks (PLAZA_RADIUS)
EGGS, STALL, PORTAL, LANDMARK_RING = (-25, 25), 75, 140, 15
ENCHANT, MASTERY, SPOT_RING = 207, 282, 16  # the two 12 x 12 spots the game builds on itself
LAMPS, LAMP_RING = (45, 135, 225, 315), 36
BOSS_RING = 44  # the boss's statue, due north
STATUES, STATUE_RING = (270, 90), 47  # two of the world's monsters
CUSHION_TOP = 3.0  # where the game's egg stands on Earth_EggPedestal
PLINTH_TOP = 2.0  # where the game's statue stands on Earth_BossPlinth: its own fountain (0.8) and plinth (1.2)
STATUE_TOP = 1.2  # and on the two bases at the sides: the height of the plinth buildStatue makes


def outline(degrees):
    """How far the island's edge is from the middle in a direction, as a share of RADIUS: the game's island
    is a circle, so only a hair off one."""
    a = math.radians(degrees)
    return 1 + 0.008 * math.sin(3 * a + 0.4) + 0.006 * math.sin(5 * a + 2.1)


def top(share):
    """The height of the grass, by the share of the way from the middle (0) to the edge (1): flat, then rolling off."""
    return 0.0 if share < FLAT else -2.6 * ((share - FLAT) / (1 - FLAT)) ** 2


def ground(x, y):
    share = math.hypot(x, y) / (RADIUS * outline(math.degrees(math.atan2(x, y))))
    return top(min(share, 1.0))


def spot(degrees, share):
    """The point (x, y) in a direction, a share of the way to the island's edge."""
    return ring(degrees, RADIUS * outline(degrees) * share)

kit.set_ground(ground)


taken = []  # (x, y, radius): where something already stands


def claim(x, y, radius):
    taken.append((x, y, radius))


def free(x, y, radius):
    """Whether a spot on the lawn is clear of the paving, of the ways to the three statues and of everything
    that has claimed its place."""
    distance = math.hypot(x, y)
    if distance < PLAZA + 0.8 + radius or distance > FENCE - 1.2 - radius:
        return False
    if abs(x) < 2.8 + radius and y > 0:  # the avenue north, to the boss
        return False
    if abs(y) < 2.6 + radius:  # the paths east and west, to the monsters
        return False
    return all(math.hypot(x - a, y - b) > radius + r for a, b, r in taken)


solids = []  # (what, x, y, radius, height): what a player cannot walk through, for the game's unseen pillars


def solid(what, x, y, radius, height, frame=None, scale=1.0):
    """Notes a solid thing at (x, y) of the island, or of the prop that stands at `frame`."""
    if frame is not None:
        point = frame @ Vector((x * scale, y * scale, 0))
        x, y = point.x, point.y
    solids.append((what, x, y, radius * scale, height * scale))


def scatter(count, inner, outer, radius):
    """Random clear spots between two distances from the middle. Each one is claimed."""
    spots, tries = [], 0
    while len(spots) < count and tries < count * 60:
        tries += 1
        x, y = ring(rng.uniform(0, 360), rng.uniform(inner, outer))
        if free(x, y, radius):
            claim(x, y, radius)
            spots.append((x, y))
    return spots


# ---------------------------------------------------------------------------------------------------
# Plants and small dressing
# ---------------------------------------------------------------------------------------------------
def crack(points, colour, profile):
    """A glowing crack up a spire: `points` are (degrees round, height), `profile` gives the spire's radius there."""
    corners = [Vector((*ring(degrees, profile(z) + 0.12), z)) for degrees, z in points]
    for a, b in zip(corners, corners[1:]):
        tube(0.3, (b - a).length, a, b - a, colour, vertices=4, emission=1.4)


def along(rings):
    """The radius of a lathe's outside at a height, from its (radius, z) rings."""
    def radius(z):
        for (r1, z1), (r2, z2) in zip(rings, rings[1:]):
            if z2 <= z <= z1 and z1 != z2:
                return r2 + (r1 - r2) * (z - z2) / (z1 - z2)
        return rings[-1][0]
    return radius


def crater_rock(leaf, kind):
    """The Moon's: a boulder with a crater in it and crystals growing out, or a thin antenna of crystal."""
    deep, light = shade(leaf, -0.14), shade(leaf, 0.3)
    if kind == "round":
        chunk((3.8, 3.6, 3.0), (0, 0, 2.0), ROCK)
        chunk((1.7, 1.6, 1.3), (2.3, -1.3, 0.8), ROCK_DARK, detail=1)
        out = Vector((-0.25, -0.6, 0.76)).normalized()
        rim = Vector((out.x * 3.8, out.y * 3.6, out.z * 3.0)) * 1.04 + Vector((0, 0, 2.0))
        hoop(1.5, 0.45, rim, ROCK_LIGHT, rotation=out.to_track_quat("Z", "Y").to_euler(), segments=10)
        tube(1.5, 0.3, rim - out * 0.3, out, ROCK_DARK, vertices=10)
        for x, y, z, radius, length, lean, colour in ((0.7, 0.9, 2.0, 2.0, 12.5, (0.12, 0.1, 1), leaf), (-1.3, 1.3, 2.0, 1.5, 9.0, (-0.42, 0.15, 1), deep), (2.2, 0.5, 1.8, 1.25, 7.0, (0.55, 0.0, 1), light)):
            tube(radius, length, (x, y, z), lean, colour, tip=0.0, vertices=5, roughness=0.15, emission=0.25)
    else:
        chunk((2.4, 2.2, 1.5), (0, 0, 0.8), ROCK, detail=1)
        tube(1.3, 12.5, (0, 0, 1.0), UP, leaf, tip=0.6, vertices=6, roughness=0.15, emission=0.25)
        for z, radius in ((6.0, 2.1), (9.5, 1.6)):
            hoop(radius, 0.3, (0, 0, z), ACCENT_PALE, segments=10, emission=1.0)
        ball(1.8, (0, 0, 14.6), light, segments=8, roughness=0.15, emission=0.6)


def mesa_spire(leaf, kind):
    """Mars's: rock in stacked layers, a wide flat-topped mesa or a thin spire with a cap balanced on it."""
    deep, light = shade(leaf, -0.16), shade(leaf, 0.2)
    if kind == "round":
        layers = ((4.0, 2.4, deep), (3.5, 0.7, COBBLE), (3.8, 2.2, leaf), (3.2, 0.6, COBBLE), (3.5, 2.0, light), (2.9, 1.6, leaf), (3.3, 0.9, deep))
    else:
        layers = ((2.6, 2.6, deep), (2.1, 0.6, COBBLE), (2.3, 2.6, leaf), (1.8, 0.6, COBBLE), (2.0, 2.6, light), (1.5, 2.2, leaf), (1.2, 1.4, deep), (2.6, 1.5, leaf), (2.1, 0.7, light))
    z = -0.4
    for radius, height, colour in layers:
        tube(radius, height + 0.1, (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), z), UP, colour, tip=radius * 0.9, vertices=9, roughness=0.8)
        z += height


def ice_spike(leaf, kind):
    """Neptune's: leaning shards of ice out of a mound of snow."""
    deep, light = shade(leaf, -0.2), shade(leaf, 0.3)
    if kind == "round":
        dome(3.6, 1.1, (0, 0, 0), GRASS_LIGHT, sink=0.2, segments=10)
        shards = ((0, 0, 2.8, 13.5, (0.05, 0.0), leaf), (-2.0, 0.6, 1.9, 9.0, (-0.35, 0.1), deep), (2.0, -0.4, 1.8, 7.5, (0.4, -0.1), light), (0.3, -1.9, 1.4, 5.5, (0.05, -0.45), deep), (0.2, 2.0, 1.5, 6.5, (0.0, 0.4), light))
    else:
        dome(2.7, 1.0, (0, 0, 0), GRASS_LIGHT, sink=0.2, segments=10)
        shards = ((0, 0, 2.3, 17.0, (0.03, 0.02), leaf), (-1.5, 0.3, 1.5, 9.5, (-0.3, 0.05), deep), (1.4, -0.5, 1.3, 7.0, (0.35, -0.1), light))
    for x, y, radius, length, (lean_x, lean_y), colour in shards:
        tube(radius, length, (x, y, -0.4), (lean_x, lean_y, 1), colour, tip=0.0, vertices=6, roughness=0.15)


def lava_spire(leaf, kind):
    """The Sun's: dark basalt with glowing cracks, a tall spire with a molten tip or a squat cone with a
    pool of lava in its top."""
    light = shade(leaf, 0.3)
    if kind == "round":
        rings = [(0, 6.0), (1.3, 6.2), (2.0, 7.2), (3.0, 4.0), (4.0, 0.5), (4.2, -0.4), (0, -0.4)]
        lathe(rings, ROCK, segments=8, rough=0.2, smooth=False)
        tube(1.6, 0.5, (0, 0, 6.3), UP, leaf, vertices=8, emission=1.4)
        ball(0.9, (0, 0, 7.6), light, scale=(1, 1, 1.3), segments=8, emission=1.6)
        for degrees in (20, 150, 260):
            crack(((degrees, 0.8), (degrees + 15, 3.6), (degrees - 5, 6.4)), leaf, along(rings[2:]))
    else:
        rings = [(0, 13.0), (1.0, 12.6), (1.5, 9.0), (2.2, 4.5), (3.0, 0.6), (3.3, -0.4), (0, -0.4)]
        lathe(rings, ROCK, segments=8, rough=0.2, smooth=False)
        ball(1.3, (0, 0, 13.3), light, scale=(1, 1, 1.25), segments=8, emission=1.6)
        ball(0.6, (0.9, 0.2, 12.0), leaf, segments=6, emission=1.4)
        for degrees in (20, 150, 260):
            crack(((degrees, 1.0), (degrees + 18, 4.5), (degrees - 6, 8.0), (degrees + 10, 11.4)), leaf, along(rings[1:]))


# How wide and how high the unseen pillar in each tall prop is, at size 1: {tree kind: {shape: (name, radius, height)}}
TREE_SOLID = {"round_tall": {"round": ("tree", 1.0, 6.92), "tall": ("tree", 1.0, 6.92)},
              "crater_rock": {"round": ("crater rock", 3.6, 5.0), "tall": ("crystal antenna", 1.6, 13.0)},
              "mesa_spire": {"round": ("mesa", 3.8, 10.0), "tall": ("rock spire", 2.4, 12.0)},
              "ice_spike": {"round": ("ice spikes", 2.6, 9.0), "tall": ("ice spike", 1.9, 12.0)},
              "lava_spire": {"round": ("lava cone", 3.8, 6.5), "tall": ("lava spire", 2.6, 11.0)}}


def tree(leaf=LEAVES[0], kind="round", fruit=None):
    """Earth: a fat trunk and a few balls of leaves in three tones of one green. About 16 tall. Another
    world: its own tall prop of about that size (the theme's `tree`), wide for "round", thin for "tall"."""
    if TREE != "round_tall":
        return {"crater_rock": crater_rock, "mesa_spire": mesa_spire, "ice_spike": ice_spike, "lava_spire": lava_spire}[TREE](leaf, kind)
    tube(1.25, 7.5, (0, 0, -0.6), (0.04, 0, 1), WOOD, tip=0.8, vertices=8)
    if kind == "round":
        ball(5.3, (0, 0, 10.2), leaf, scale=(1, 1, 0.9), segments=16)
        ball(3.5, (-3.3, -1.0, 8.2), shade(leaf, -0.1), segments=10)
        ball(3.3, (3.1, 1.2, 8.7), shade(leaf, -0.1), segments=10)
        ball(3.1, (0.9, -1.6, 13.2), shade(leaf, 0.14), segments=10)
        for x, y, z in fruit and ((-3.6, -3.4, 9.4), (2.2, -4.6, 10.6), (4.9, -1.2, 11.4), (-0.6, -4.2, 13.6), (-5.2, 0.6, 10.8)) or ():
            ball(0.75, (x, y, z), fruit, segments=6, roughness=0.3)
    else:  # three balls stacked like a fir
        ball(4.7, (0, 0, 8.2), shade(leaf, -0.1), scale=(1, 1, 0.8), segments=14)
        ball(3.8, (0, 0, 12.2), leaf, scale=(1, 1, 0.85), segments=12)
        ball(2.7, (0, 0, 15.6), shade(leaf, 0.14), scale=(1, 1, 0.95), segments=10)


def bush(leaf=LEAVES[0], berries=None):
    ball(2.0, (0, 0, 1.1), leaf, segments=10)
    ball(1.5, (1.7, 0.3, 0.9), shade(leaf, -0.1), segments=8)
    ball(1.3, (-1.6, -0.4, 0.8), shade(leaf, 0.12), segments=8)
    for x, y, z in berries and ((0.5, -1.5, 1.9), (-0.9, -1.2, 1.5), (1.9, -0.9, 1.3), (0.1, -0.3, 3.0)) or ():
        ball(0.34, (x, y, z), berries, segments=6, roughness=0.3)


def flower(petal=PETALS[0], kind="daisy"):
    """Oversized on purpose, so a bed of them reads from across the island."""
    tube(0.15, 1.5, (0, 0, -0.1), (rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 1), GRASS_RIM, tip=0.09, vertices=5)
    if kind == "daisy":
        rosette(0.95, (0, 0, 1.4), petal)
        ball(0.36, (0, 0, 1.55), "FFD83A" if petal != "FFD83A" else "FF8A1F", scale=(1, 1, 0.7), segments=6)
    else:  # a tulip: one fat bud
        ball(0.6, (0, 0, 1.6), petal, scale=(1, 1, 1.15), segments=10)


def tuft(colour=GRASS_DEEP):
    for lean, turn in ((0.0, 0.0), (0.4, 2.1), (0.4, 4.2)):
        tube(0.34, 1.5, (0, 0, -0.1), (math.sin(turn) * lean, math.cos(turn) * lean, 1), colour, tip=0.0, vertices=4)


def mushroom(cap=RED):
    tube(0.6, 1.6, (0, 0, -0.1), UP, "FFF3D6", tip=0.42, vertices=8)
    ball(1.5, (0, 0, 1.6), cap, scale=(1, 1, 0.62), segments=10, roughness=0.4)
    for x, y, z in ((0.1, -0.2, 2.42), (-0.85, -0.5, 2.1), (0.8, 0.5, 2.15), (0.5, -1.0, 2.0)):
        ball(0.3, (x, y, z), WHITE, scale=(1, 1, 0.5), segments=6)


def rocks(colour=ROCK, moss=True):
    chunk((2.3, 2.0, 1.7), (0, 0, 0.9), colour)
    chunk((1.3, 1.2, 1.0), (2.4, 0.6, 0.5), shade(colour, -0.14), detail=1)
    chunk((0.95, 0.9, 0.7), (-2.1, -0.9, 0.35), shade(colour, 0.14), detail=1)
    if moss:
        dome(1.5, 0.5, (-0.2, 0.1, 2.3), GRASS_LIGHT, sink=0.6, segments=8)


def lamp():
    tube(1.05, 0.8, (0, 0, 0), UP, STONE, vertices=10)
    tube(0.36, 8.0, (0, 0, 0.8), UP, POST, vertices=8)
    tube(0.95, 0.4, (0, 0, 8.8), UP, POST, vertices=8)
    ball(1.2, (0, 0, 10.2), LAMP_GLOW, emission=1.0)
    tube(1.4, 1.1, (0, 0, 11.1), UP, POST, tip=0.15, vertices=8)


def brazier():
    tube(1.3, 0.7, (0, 0, 0), UP, STONE_DARK, vertices=8)
    tube(0.75, 3.4, (0, 0, 0.7), UP, STONE, tip=0.6, vertices=8)
    tube(1.0, 1.1, (0, 0, 4.1), UP, IRON, tip=1.75, vertices=10)
    ball(1.25, (0, 0, 5.5), FLAME[0], scale=(1, 1, 1.1), segments=10, emission=1.4)
    ball(0.8, (0.15, 0, 6.5), FLAME[1], scale=(1, 1, 1.4), segments=8, emission=1.6)


def sag(a, b, height, drop, radius, colour, **look):
    """A rope or a chain hanging between two posts' feet, `height` up at its ends and `drop` lower in the middle."""
    start, end = a + Vector((0, 0, height)), b + Vector((0, 0, height))
    middle = (start + end) / 2 - Vector((0, 0, drop))
    for p, q in ((start, middle), (middle, end)):
        tube(radius, (q - p).length, p, q - p, colour, vertices=4, **look)


def themed_fence(step):
    """The other worlds' fences, on the same posts' spots as Earth's."""
    posts = []
    for index in range(round(360 / step)):
        x, y = ring(index * step, FENCE)
        z = ground(x, y)
        turn = (0, 0, -math.radians(index * step))
        if FENCING == "metal_rail":  # thin posts with a glowing bulb, one rail
            tube(0.4, 3.3, (x, y, z - 0.3), UP, WOOD_LIGHT, vertices=6, roughness=0.3)
            ball(0.7, (x, y, z + 3.4), ACCENT_PALE, segments=6, emission=1.0)
        elif FENCING == "rope_post":  # stone posts
            box((1.25, 1.25, 3.8), (x, y, z + 1.6), STONE, bevel=0.3, rotation=turn, segments=1)
            slab((1.5, 1.5, 0.5), (x, y, z + 3.5), STONE_DARK, rotation=turn)
        elif FENCING == "ice_post":  # shards
            tube(0.85, 4.6, (x, y, z - 0.3), (rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 1), LEAVES[index % 3], tip=0.0, vertices=5, roughness=0.15)
        else:  # basalt_chain: basalt posts with an ember on top
            box((1.25, 1.25, 3.6), (x, y, z + 1.5), ROCK_LIGHT, bevel=0.3, rotation=turn, segments=1)
            ball(0.65, (x, y, z + 3.6), LEAVES[0], segments=6, emission=1.3)
        posts.append(Vector((x, y, z)))
    for a, b in zip(posts, posts[1:] + posts[:1]):
        if FENCING == "metal_rail":
            tube(0.28, (b - a).length, a + Vector((0, 0, 2.1)), b - a, WOOD, vertices=4, roughness=0.3)
        elif FENCING == "rope_post":
            sag(a, b, 2.9, 0.9, 0.22, WOOD_LIGHT)
            sag(a, b, 1.7, 0.7, 0.22, WOOD_LIGHT)
        elif FENCING == "ice_post":
            tube(0.3, (b - a).length, a + Vector((0, 0, 1.5)), b - a, ROCK_LIGHT, vertices=4, roughness=0.15)
        else:
            sag(a, b, 2.9, 1.1, 0.26, ROCK_DARK)


def fence(step=7.2):
    """A fence all the way round the rim, where the game's wall stands (the stream runs out under it):
    wooden on Earth, the theme's `fence` elsewhere."""
    if FENCING != "wood_rail":
        return themed_fence(step)
    posts = []
    for index in range(round(360 / step)):
        x, y = ring(index * step, FENCE)
        z = ground(x, y)
        box((1.05, 1.05, 4.0), (x, y, z + 1.7), WOOD_LIGHT, bevel=0.28, rotation=(0, 0, -math.radians(index * step)), segments=1)
        posts.append(Vector((x, y, z)))
    for a, b in zip(posts, posts[1:] + posts[:1]):
        for height in (1.2, 2.7):
            tube(0.32, (b - a).length, a + Vector((0, 0, height)), b - a, WOOD, vertices=4)


def stones(points):
    """Stepping stones across the lawn, at (direction, distance from the middle) points."""
    for degrees, distance in points:
        x, y = ring(degrees, distance)
        tube(rng.uniform(1.25, 1.55), 0.3, (x, y, -0.05), UP, rng.choice((COBBLE, SAND_DARK, SAND)), vertices=7, roughness=0.9)
        claim(x, y, 1.7)


def cobbles(spots):
    """Flat paving stones on the plaza or a path, at (x, y) points."""
    for x, y in spots:
        tube(rng.uniform(0.8, 1.2), 0.15, (x, y, 0.1), UP, rng.choice((COBBLE, SAND_DARK, COBBLE)), vertices=7, roughness=0.9)


def cannon():
    """An old cannon on the lawn, aimed over the rim. Its front (-Y) is where it fires."""
    aim = Vector((0, -math.cos(math.radians(22)), math.sin(math.radians(22))))
    box((2.8, 4.6, 1.0), (0, 0.6, 1.4), WOOD, bevel=0.25)
    box((1.4, 1.6, 1.0), (0, 2.4, 0.6), WOOD_DARK, bevel=0.25)
    for side in (-1, 1):
        tube(1.6, 0.7, (side * 1.45, 0.0, 1.6), (side, 0, 0), WOOD_DARK, vertices=12)
        tube(0.5, 0.3, (side * 2.15, 0.0, 1.6), (side, 0, 0), GOLD, vertices=8, roughness=0.3)
    start = Vector((0, 2.4, 2.4))
    tube(1.25, 6.0, start, aim, IRON, tip=1.0, vertices=12, roughness=0.35)
    ball(1.25, start, IRON, segments=10, roughness=0.35)
    tube(1.38, 0.5, start + aim * 1.8, aim, GOLD, vertices=12, roughness=0.3)
    tube(1.2, 0.7, start + aim * 5.5, aim, GOLD, vertices=12, roughness=0.3)
    tube(0.7, 0.1, start + aim * 6.2, aim, INK, vertices=10)
    for x, y, z in ((3.6, 1.2, 0.75), (5.0, 1.4, 0.75), (4.3, 2.5, 0.75), (4.3, 1.7, 1.9)):
        ball(0.8, (x, y, z), IRON, segments=8, roughness=0.35)


def target():
    """A bullseye on an easel, for the cannon to aim at."""
    for side in (-1, 1):
        tube(0.22, 5.2, (side * 1.7, 0.6, -0.2), (-side * 0.22, 0.05, 1), WOOD, vertices=5)
    tube(0.22, 5.0, (0, 2.6, -0.2), (0, -0.4, 1), WOOD, vertices=5)
    for radius, depth, colour in ((2.7, 0.4, WHITE), (2.0, 0.5, RED), (1.3, 0.6, WHITE), (0.6, 0.7, RED)):
        tube(radius, depth, (0, 0.9, 3.6), (0, -1, 0.18), colour, vertices=14)


def campfire():
    for index in range(7):
        x, y = ring(index * 51.4, 1.9)
        chunk((0.7, 0.7, 0.5), (x, y, 0.25), ROCK_LIGHT if index % 2 else ROCK, detail=1)
    for turn in (0.3, 1.9):
        tube(0.35, 3.0, (-1.5 * math.cos(turn), -1.5 * math.sin(turn), 0.5), (math.cos(turn), math.sin(turn), 0.12), WOOD_DARK, vertices=6)
    ball(1.0, (0, 0, 1.2), "FF8A1F", scale=(1, 1, 1.3), segments=8, emission=1.4)
    ball(0.6, (0.1, 0, 2.2), "FFD83A", scale=(1, 1, 1.5), segments=6, emission=1.6)
    for degrees in (20, 150, 260):  # logs to sit on
        x, y = ring(degrees, 5.2)
        across = Vector((math.cos(math.radians(degrees)), -math.sin(math.radians(degrees)), 0))
        tube(1.0, 4.0, Vector((x, y, 0.85)) - across * 2.0, across, WOOD, vertices=8)
        tube(0.7, 4.1, Vector((x, y, 0.85)) - across * 2.05, across, WOOD_LIGHT, vertices=8)


# ---- The other worlds' set pieces: one where Earth has its cannon, one where it has its campfire. Each
# stays inside that spot's footprint (6.5 and 7 from its middle) and has its front towards -Y. ----
def lander():
    """The Moon: a landing craft on four legs, a flag planted beside it."""
    hull, glass = "F4F4FF", "3FA9FF"
    for index in range(4):
        x, y = ring(index * 90 + 45, 1.0)
        knee, foot = Vector((x * 2.2, y * 2.2, 3.9)), Vector((x * 4.9, y * 4.9, 0.4))
        tube(0.36, (foot - knee).length, knee, foot - knee, hull, vertices=6)
        low = Vector((x * 2.4, y * 2.4, 2.3))
        tube(0.22, (foot - low).length, low, foot - low, WOOD, vertices=5)
        tube(1.15, 0.4, (foot.x, foot.y, 0), UP, GOLD, vertices=10, roughness=0.3)
    tube(1.7, 1.5, (0, 0, 1.0), UP, WOOD_DARK, tip=0.9, vertices=10)  # the engine's bell
    tube(3.3, 2.5, (0, 0, 2.4), UP, GOLD, vertices=8, roughness=0.3)  # the gold stage
    hoop(3.2, 0.26, (0, 0, 3.65), "FF5FA2", segments=8)
    ball(2.8, (0, 0, 6.8), hull, scale=(1, 1, 0.92), segments=14, roughness=0.4)  # the cabin
    ball(1.25, (0, -2.25, 7.1), glass, scale=(1, 0.42, 1), segments=10, roughness=0.15)
    hoop(1.3, 0.2, (0, -2.5, 7.1), WOOD, rotation=(math.pi / 2, 0, 0), segments=10)
    tube(0.16, 2.2, (1.3, 0.8, 8.9), UP, hull, vertices=5)
    ball(1.3, (1.3, 0.8, 11.2), hull, scale=(1, 1, 0.3), segments=8)
    ball(0.42, (1.3, 0.8, 11.7), ACCENT, segments=6, emission=1.2)
    ball(0.5, (-1.4, -0.4, 9.5), "FF5FA2", segments=6, emission=1.2)
    tube(0.16, 6.0, (3.9, -3.4, 0), UP, hull, vertices=5)  # the flag
    box((2.2, 0.14, 1.6), (5.1, -3.4, 5.1), "FF5FA2", bevel=0.05, segments=1)
    star(0.5, (5.1, -3.5, 5.1), WHITE, depth=0.1)


def dish():
    """The Moon: a radar dish listening to the sky, and its control box."""
    tube(2.8, 0.8, (0, 0, 0), UP, STONE_DARK, vertices=10)
    tube(1.0, 4.4, (0, 0, 0.8), UP, WOOD, tip=0.65, vertices=8, roughness=0.3)
    ball(1.0, (0, 0, 5.4), WOOD_DARK, segments=8)
    out = Vector((0, -0.72, 0.69)).normalized()
    turn = out.to_track_quat("Z", "Y").to_euler()
    lathe([(0, 0.5), (2.5, 1.0), (4.4, 2.4), (4.6, 2.3), (2.5, 0.4), (0, -0.2)], "F4F4FF", segments=14, location=Vector((0, 0, 5.4)) + out * 0.7, rotation=turn)
    hoop(4.5, 0.2, Vector((0, 0, 5.4)) + out * 3.05, "FF5FA2", rotation=turn, segments=14)
    tube(0.14, 3.4, Vector((0, 0, 5.4)) + out * 1.2, out, WOOD, vertices=5)
    ball(0.6, Vector((0, 0, 5.4)) + out * 4.7, ACCENT_PALE, segments=8, emission=1.4)
    box((2.6, 2.2, 2.4), (4.3, 1.4, 1.2), WOOD_LIGHT, bevel=0.3)
    box((1.7, 0.2, 1.1), (4.3, 0.25, 1.5), ACCENT, bevel=0.05, segments=1, emission=1.0)
    tube(0.12, 2.0, (5.1, 1.9, 2.4), UP, WOOD_DARK, vertices=5)
    ball(0.32, (5.1, 1.9, 4.5), "FF5FA2", segments=6, emission=1.2)


def rover():
    """Mars: a rover stuck askew in a drift of sand, one wheel off, its mast bent."""
    hull, panel = "FFF6E6", "3FA9FF"
    dome(5.6, 1.1, (0.2, 0.6, 0), GRASS_LIGHT, stretch=0.85, sink=0.1, segments=12, roughness=0.9)
    tilt = (0.1, -0.16, 0.3)
    box((4.8, 7.0, 1.8), (0, 0, 2.7), hull, bevel=0.45, rotation=tilt)
    box((4.9, 1.0, 1.9), (-0.1, -1.6, 2.7), ACCENT, bevel=0.3, rotation=tilt, segments=1)
    box((5.6, 4.4, 0.3), (0.5, 1.6, 4.3), panel, bevel=0.1, rotation=(0.1, -0.45, 0.3), segments=1, roughness=0.2)
    for side in (-1, 1):
        for y in (-2.7, 0.2, 3.0):
            if side == -1 and y == -2.7:
                continue  # this one lies on the ground
            z = 1.35 - side * 0.35
            tube(1.35, 1.1, (side * 2.3, y + side * 0.7, z), (side, 0.3 * side, 0), IRON, vertices=10)
            tube(0.55, 0.25, (side * 3.35, y + side * 1.0, z), (side, 0.3 * side, 0), GOLD, vertices=8, roughness=0.3)
    tube(1.35, 1.1, (-4.7, -3.9, 0.0), UP, IRON, vertices=10)
    tube(0.55, 0.25, (-4.7, -3.9, 1.1), UP, GOLD, vertices=8, roughness=0.3)
    foot, lean = Vector((-0.9, -2.5, 3.3)), Vector((-0.28, -0.22, 1)).normalized()
    tube(0.34, 3.6, foot, lean, hull, vertices=6)
    head = foot + lean * 4.0
    box((2.2, 1.3, 1.3), head, hull, bevel=0.3, rotation=(0.25, -0.2, 0.2))
    for side in (-0.5, 0.5):
        tube(0.4, 0.3, head + Vector((side, -0.6, -0.1)), (0.1, -1, -0.25), "35D6C4", vertices=8, emission=1.0)
    tube(0.13, 2.8, (1.5, 2.6, 3.4), (0.5, 0.3, 1), IRON, vertices=5)
    ball(0.36, Vector((1.5, 2.6, 3.4)) + Vector((0.5, 0.3, 1)).normalized() * 2.9, RED, segments=6, emission=1.0)


def habitat():
    """Mars: a white dome to live in, with an airlock at its front."""
    hull, glass = "FFF6E6", "35D6C4"
    tube(5.5, 0.6, (0, 0, 0), UP, STONE_DARK, vertices=16)
    ball(4.9, (0, 0, 1.3), hull, scale=(1, 1, 0.9), segments=16, roughness=0.4)
    hoop(4.78, 0.3, (0, 0, 2.5), ACCENT, segments=16)
    tube(2.1, 2.9, (0, -3.5, 1.5), (0, -1, 0), STONE, vertices=10)
    hoop(2.1, 0.3, (0, -6.4, 1.5), ACCENT, rotation=(math.pi / 2, 0, 0), segments=10)
    tube(1.55, 0.2, (0, -6.4, 1.5), (0, -1, 0), glass, vertices=10, emission=1.0)
    for x in (-1, 1):
        out = Vector((x * 0.62, -0.5, 0.6)).normalized()
        ball(1.0, (out.x * 4.75, out.y * 4.75, 1.3 + out.z * 4.75 * 0.9), glass, segments=8, emission=1.0)
    tube(0.16, 3.0, (0, 0, 5.5), UP, IRON, vertices=5)
    ball(0.42, (0, 0, 8.7), RED, segments=6, emission=1.2)
    for x, y in ((5.3, 0.4), (4.9, 2.3)):  # air tanks beside it
        tube(0.95, 2.8, (x, y, 0), UP, glass, vertices=8, roughness=0.3)
        ball(0.95, (x, y, 2.8), glass, segments=8, roughness=0.3)


def palm(x, y):
    """Mars: the oasis's one palm. Built at (x, y) of the pond."""
    green, at = PETALS[2], Vector((x, y, -0.3))
    for index in range(4):  # the trunk, bending
        lean = Vector((0.1 + 0.11 * index, -0.05, 1)).normalized()
        tube(0.95 - 0.1 * index, 2.9, at, lean, WOOD_LIGHT if index % 2 else WOOD, tip=0.85 - 0.1 * index, vertices=8)
        at = at + lean * 2.6
    for index in range(6):  # six fat leaves
        a = math.radians(index * 60 + 20)
        ball(3.3, at + Vector((math.cos(a) * 2.6, math.sin(a) * 2.6, -0.5)), shade(green, -0.12) if index % 2 else green, scale=(1, 0.36, 0.2), rotation=(0, 0.42, a), segments=8)
    ball(1.1, at, shade(green, 0.2), segments=8)
    for dx, dy in ((0.8, -0.5), (-0.6, -0.7)):
        ball(0.6, at + Vector((dx, dy, -0.9)), WOOD_DARK, segments=6)
    solids.append(("palm", x, y, 0.9, 9.0))  # in the pond's own space: pond() is placed, the caller turns it


def snowman():
    """Neptune: a big snowman in a scarf and a hat."""
    scarf, hat = "FF5FA2", WOOD_DARK
    ball(3.2, (0, 0, 2.5), WHITE, scale=(1, 1, 0.9), segments=14, roughness=0.8)
    ball(2.4, (0, 0, 6.3), "F2FBFF", segments=12, roughness=0.8)
    ball(1.8, (0, 0, 9.4), WHITE, segments=12, roughness=0.8)
    tube(0.45, 1.9, (0, -1.6, 9.4), (0, -1, 0.05), "FF8A1F", tip=0.0, vertices=6)
    for side in (-1, 1):
        ball(0.32, (side * 0.65, -1.55, 10.0), INK, segments=6)
        tube(0.24, 3.6, (side * 2.0, 0, 6.8), (side, -0.1, 0.55), WOOD, vertices=5)
    for z, y in ((7.0, -2.3), (5.8, -2.3)):
        ball(0.36, (0, y, z), INK, segments=6)
    hoop(1.75, 0.5, (0, 0, 8.05), scarf, segments=12)
    box((1.0, 0.45, 2.4), (1.2, -1.95, 6.9), scarf, bevel=0.15, rotation=(0.2, 0, 0.2), segments=1)
    tube(2.1, 0.3, (0, 0, 10.75), UP, hat, vertices=12)
    tube(1.35, 1.9, (0, 0, 11.0), UP, hat, vertices=12)
    hoop(1.37, 0.17, (0, 0, 11.4), GOLD, segments=12, roughness=0.3)


def igloo():
    """Neptune: an igloo of snow blocks, warm light in its door."""
    snow, warm = "F4FCFF", "FFB347"
    ball(5.0, (0, 0, 0.9), snow, scale=(1, 1, 0.85), segments=16, roughness=0.8)
    for z in (1.6, 3.0, 4.2):  # the courses of blocks
        hoop(5.0 * math.sqrt(1 - ((z - 0.9) / 4.25) ** 2) + 0.02, 0.13, (0, 0, z), GRASS_DEEP, segments=16)
    tube(2.4, 3.2, (0, -3.3, 0.9), (0, -1, 0), GRASS_LIGHT, vertices=10, roughness=0.8)
    hoop(2.4, 0.32, (0, -6.5, 0.9), GRASS_DEEP, rotation=(math.pi / 2, 0, 0), segments=10)
    tube(1.7, 0.2, (0, -6.5, 0.9), (0, -1, 0), warm, vertices=10, emission=1.3)
    out = Vector((0.66, -0.45, 0.6)).normalized()
    ball(0.9, (out.x * 4.9, out.y * 4.9, 0.9 + out.z * 4.9 * 0.85), warm, segments=8, emission=1.3)
    for x, y, size in ((5.0, -2.9, 1.7), (5.3, -1.0, 1.3)):  # spare blocks
        box((size, size, size * 0.8), (x, y, size * 0.4), GRASS_LIGHT, bevel=0.3, rotation=(0, 0, 0.4), segments=1)
    tube(0.14, 4.0, (0, 0, 4.9), UP, WOOD_DARK, vertices=5)  # a pennant on top
    box((1.9, 0.12, 1.1), (0.95, 0, 8.3), "FF5FA2", bevel=0.05, segments=1)


def forge():
    """The Sun: a furnace with a glowing mouth and a chimney, an anvil and a bucket of lava before it."""
    lava, bright = "FF5A1A", "FFD23A"
    box((7.0, 5.0, 5.0), (0, 1.2, 2.5), STONE, bevel=0.6)
    box((7.6, 5.6, 0.9), (0, 1.2, 5.2), STONE_DARK, bevel=0.3)
    box((7.6, 5.6, 0.7), (0, 1.2, 0.35), STONE_DARK, bevel=0.2, segments=1)
    tube(1.5, 4.6, (1.7, 1.8, 5.5), UP, STONE_PALE, tip=1.1, vertices=8)
    hoop(1.2, 0.3, (1.7, 1.8, 10.0), GOLD, segments=8, roughness=0.3)
    tube(0.95, 0.3, (1.7, 1.8, 9.9), UP, lava, vertices=8, emission=1.5)
    ball(0.85, (1.7, 1.8, 10.9), bright, scale=(1, 1, 1.3), segments=8, emission=1.6)
    ball(0.5, (2.0, 1.8, 12.3), bright, segments=6, emission=1.6)
    tube(2.0, 0.3, (0, -1.25, 2.5), (0, -1, 0), lava, vertices=12, emission=1.4)  # its mouth
    tube(1.3, 0.4, (0, -1.25, 2.3), (0, -1, 0), bright, vertices=12, emission=1.6)
    hoop(2.05, 0.38, (0, -1.5, 2.5), GOLD, rotation=(math.pi / 2, 0, 0), segments=12, roughness=0.3)
    tube(1.15, 1.3, (-3.3, -4.0, 0), UP, STONE_PALE, vertices=8)  # the anvil on its block
    box((1.3, 1.0, 0.8), (-3.3, -4.0, 1.6), IRON, bevel=0.15, segments=1)
    box((2.7, 1.3, 0.9), (-3.3, -4.0, 2.4), IRON, bevel=0.2)
    tube(0.45, 1.3, (-2.0, -4.0, 2.45), (1, 0, 0), IRON, tip=0.0, vertices=6)
    box((1.5, 0.45, 0.32), (-3.4, -4.0, 3.0), bright, bevel=0.08, segments=1, emission=1.5)
    tube(1.05, 1.7, (3.5, -3.7, 0), UP, IRON, tip=1.4, vertices=10)  # the bucket
    tube(1.25, 0.2, (3.5, -3.7, 1.55), UP, lava, vertices=10, emission=1.4)


def vent():
    """The Sun: a small volcano, lava in its top and running down its sides."""
    lava, bright = "FF5A1A", "FFD23A"
    lathe([(0, 5.2), (1.6, 5.4), (2.5, 6.5), (3.6, 3.6), (4.9, 1.0), (5.4, -0.3), (0, -0.3)], ROCK_LIGHT, segments=9, rough=0.3, smooth=False)
    tube(2.0, 0.5, (0, 0, 5.5), UP, lava, vertices=9, emission=1.4)
    ball(1.1, (0, 0, 7.0), bright, scale=(1, 1, 1.3), segments=8, emission=1.6)
    ball(0.6, (0.4, 0, 8.8), bright, segments=6, emission=1.6)
    for turn, width in ((0.0, 1.5), (2.3, 1.1), (4.2, 1.2)):
        ribbon([(2.2, 6.45), (3.4, 3.9), (4.7, 1.3), (5.7, 0.1)], width, lava, thickness=0.4, lift=0.25, rotation=(0, 0, turn), emission=1.4)


# The two set pieces of a world and what is solid in them: (builder, ((what, x, y, radius, height), ...)), the
# first where Earth has its cannon, the second where it has its campfire.
SET_PIECES = {
    "Moon": ((lander, (("lander", 0, 0, 3.6, 9.0), ("flag", 3.9, -3.4, 0.5, 6.0))), (dish, (("radar dish", 0, 0, 2.8, 8.0), ("control box", 4.3, 1.4, 1.7, 2.4)))),
    "Mars": ((rover, (("rover wreck", 0, 0, 3.8, 4.4), ("wheel", -4.7, -3.9, 1.4, 1.3))), (habitat, (("habitat", 0, 0, 5.2, 5.6), ("airlock", 0, -4.9, 2.1, 3.6), ("air tanks", 5.1, 1.3, 1.9, 3.6)))),
    "Neptune": ((snowman, (("snowman", 0, 0, 3.0, 11.0),)), (igloo, (("igloo", 0, 0, 5.0, 5.1), ("igloo door", 0, -4.9, 2.4, 3.3), ("snow blocks", 5.1, -2.0, 1.6, 1.4)))),
    "The Sun": ((forge, (("forge", 0, 1.2, 4.2, 5.6), ("anvil", -3.3, -4.0, 1.5, 2.9), ("lava bucket", 3.5, -3.7, 1.4, 1.7))), (vent, (("volcano vent", 0, 0, 4.8, 6.0),))),
}


def pumpkins():
    for x, y, size in ((0, 0, 1.6), (3.2, 1.0, 1.2), (-2.6, 1.8, 1.0), (1.2, -2.8, 0.9), (-2.4, -1.8, 1.25)):
        ball(size, (x, y, size * 0.72), "FF8A1F", scale=(1, 1, 0.78), segments=10, roughness=0.4)
        tube(size * 0.2, size * 0.5, (x, y, size * 1.4), (0.2, 0, 1), WOOD_DARK, tip=size * 0.12, vertices=5)
        dome(size * 0.7, 0.2, (x + size * 0.9, y + size * 0.5, 0.2), LEAVES[1], stretch=0.7, sink=0.2, segments=6)


def tub(petal=PETALS[0]):
    """A low stone tub of tulips: it dresses the plaza between the landmarks without standing in a way."""
    tube(2.5, 0.75, (0, 0, 0), UP, STONE, vertices=12)
    tube(2.05, 0.85, (0, 0, 0), UP, WOOD_DARK, vertices=12, roughness=0.9)
    home = kit.use("Plants")
    for index in range(3):
        x, y = ring(index * 120 + 20, 1.05)
        place(flower, (x, y, 0.8), face=rng.uniform(0, 360), petal=petal, kind="tulip")
    dome(0.9, 0.5, (0, 0, 0.85), LEAVES[0], sink=0.1, segments=8)
    kit.use(home)


def floating_rock(size=6.0, leaf=None, extra=None):
    """A chunk of the island that drifted off: a grass cap on a rock, with something growing on it."""
    lathe([(0, 1.0), (size * 0.7, 0.8), (size * 1.06, 0.1), (size * 1.1, -0.7), (size * 0.9, -1.2), (0, -1.2)], GRASS, segments=14)
    lathe([(0, -0.5), (size * 0.96, -0.9), (size * 0.8, -size * 0.55), (size * 0.42, -size * 1.15), (0, -size * 1.7)], ROCK, segments=8, rough=size * 0.09, smooth=False)
    if extra:
        place(extra, (0, 0, 0.8), face=180)
    elif leaf:
        place(tree, (size * 0.15, 0, 0.8), face=180, scale=size / 14, leaf=leaf)
    elif size > 3 and EARTH:
        place(bush, (-size * 0.2, 0, 0.8), face=180, scale=size / 9, leaf=LEAVES[2])
    elif size > 3:
        place(tree, (-size * 0.1, 0, 0.6), face=180, scale=size / 22, leaf=LEAVES[2], kind="tall")



# ---------------------------------------------------------------------------------------------------
# The paving and what the game builds on: the arrival pad, the two empty spots, the statues' bases
# ---------------------------------------------------------------------------------------------------
def arrival_pad():
    """Where players land: a glowing disc in a stone ring, with a star in it. Low, like the game's."""
    tube(5.6, 0.3, (0, 0, 0), UP, STONE_DARK, vertices=32)
    tube(5.1, 0.42, (0, 0, 0), UP, STONE, vertices=32)
    tube(4.5, 0.5, (0, 0, 0), UP, PAD[0], vertices=32, emission=0.8)
    tube(3.3, 0.56, (0, 0, 0), UP, PAD[1], vertices=24, emission=0.8)
    star(2.5, (0, 0, 0.6), WHITE, depth=0.2, rotation=(math.pi / 2, 0, 0), emission=0.8)
    for index in range(8):
        x, y = ring(index * 45 + 22.5, 5.3)
        ball(0.42, (x, y, 0.38), GOLD, segments=8, roughness=0.3)


def spot_pad(kind):
    """One of the two 12 x 12 spots the game fills itself (the enchanting table and the fusion machine, the
    mastery shrine): bare paving, and a low border round the back and the sides, outside the 12 x 12."""
    kerb, tint = ("7A5CFF", "DDD2FF") if kind == "enchant" else (GOLD_DARK, "FFE9B0")
    box((12.0, 12.0, 0.5), (0, 0, 0.01), STONE, bevel=0.1, segments=1, roughness=0.9)
    box((9.4, 9.4, 0.3), (0, 0, 0.18), tint, bevel=0.08, segments=1, roughness=0.9)
    box((13.4, 0.7, 0.6), (0, 6.35, 0.3), kerb, bevel=0.18, segments=1)
    for side in (-1, 1):
        box((0.7, 8.6, 0.6), (side * 6.35, 2.1, 0.3), kerb, bevel=0.18, segments=1)
        box((1.3, 1.3, 1.5), (side * 6.35, 6.35, 0.75), STONE, bevel=0.25, segments=1)
        box((1.0, 1.0, 0.9), (side * 6.3, -2.4, 0.45), STONE, bevel=0.2, segments=1)
        if kind == "enchant":  # crystals on its corner posts
            tube(0.5, 1.5, (side * 6.35, 6.35, 1.4), (side * 0.15, 0, 1), "5CF0FF", tip=0.0, vertices=5, roughness=0.15, emission=0.8)
            tube(0.36, 0.9, (side * 6.3, -2.4, 0.85), UP, "FF8FE0", tip=0.0, vertices=5, roughness=0.15, emission=0.8)
        else:  # gold knobs
            ball(0.55, (side * 6.35, 6.35, 1.85), GOLD, segments=8, roughness=0.3)
            ball(0.4, (side * 6.3, -2.4, 1.15), GOLD, segments=8, roughness=0.3)


def statue_base():
    """Where the game stands one of the world's monsters: a step, and on it a plinth as high as the one
    buildStatue makes (and a little wider than its 2.6), with nothing on it."""
    tube(4.2, 0.5, (0, 0, 0), UP, STONE_DARK, vertices=20)
    tube(3.0, STATUE_TOP - 0.5, (0, 0, 0.5), UP, STONE, vertices=20)
    hoop(3.03, 0.2, (0, 0, 0.85), GOLD, roughness=0.3)


# ---------------------------------------------------------------------------------------------------
# The landmark shells. Each is built around its own origin, its front towards -Y.
# ---------------------------------------------------------------------------------------------------
def egg(radius, location, colour, spot_colour, spots):
    """A big egg: a ball stretched tall and narrowed towards its top, with round spots all over its shell.
    A spot is (degrees around from the front, degrees up from its waist, its radius as a share of the egg's)."""
    tall = 1.36
    work = bmesh.new()
    bmesh.ops.create_uvsphere(work, u_segments=24, v_segments=12, radius=radius)
    for vertex in work.verts:
        narrow = 1 - 0.16 * vertex.co.z / radius
        vertex.co = (vertex.co.x * narrow, vertex.co.y * narrow, vertex.co.z * tall)
    finish(work, colour, location, roughness=0.3)
    for turn, rise, share in spots:
        a, b, size = math.radians(turn), math.radians(rise), share * radius
        narrow = 1 - 0.16 * math.sin(b)
        point = Vector((math.sin(a) * math.cos(b) * radius * narrow, -math.cos(a) * math.cos(b) * radius * narrow, math.sin(b) * radius * tall))
        normal = Vector((point.x, point.y, point.z / tall ** 2)).normalized()
        dome(size, size * 0.16, Vector(location) + point, spot_colour, rotation=normal.to_track_quat("Z", "Y").to_euler(), segments=18, roughness=0.3)
    # A wet highlight, like the creatures' eyes have.
    high = Vector((-0.42, -0.62, 0.66)).normalized()
    dome(radius * 0.24, radius * 0.03, Vector(location) + Vector((high.x * radius * 0.88, high.y * radius * 0.88, high.z * radius * tall * 0.94)), WHITE, rotation=high.to_track_quat("Z", "Y").to_euler(), stretch=0.6, segments=10, roughness=0.2)


EGG_SPOTS = ((0, 5, 0.35), (48, 38, 0.24), (-55, 30, 0.28), (-30, -32, 0.24), (40, -25, 0.31), (100, 5, 0.33), (-110, -5, 0.35), (165, 30, 0.28), (190, -25, 0.32), (10, 64, 0.2), (140, -40, 0.22), (-150, 52, 0.2))


def stand_in_egg(shell="FFF3D6", spots="FF6A3D"):
    """For the photos only: an egg the size of the game's (3.4 across, 4.6 tall) on the cushion."""
    egg(1.7, (0, 0, CUSHION_TOP - 0.15 + 1.7 * 1.36), shell, spots, EGG_SPOTS)


def egg_pedestal():
    """What an egg stands on: stone steps, a short column with a gold band and a fat gold cushion, 6.4
    across at its foot. The cushion's top, flat for 3.4 across, is CUSHION_TOP up."""
    tube(3.2, 0.6, (0, 0, 0), UP, STONE_DARK, vertices=20)
    tube(2.6, 0.5, (0, 0, 0.6), UP, STONE, vertices=20)
    tube(1.9, 0.9, (0, 0, 1.1), UP, STONE_PALE, vertices=16)
    hoop(1.92, 0.24, (0, 0, 1.55), GOLD, roughness=0.3)
    tube(2.5, 0.35, (0, 0, 1.9), UP, STONE, vertices=20)
    box((4.4, 4.4, 0.95), (0, 0, CUSHION_TOP - 0.475), GOLD, bevel=0.47, segments=3, roughness=0.4)
    box((4.52, 4.52, 0.24), (0, 0, CUSHION_TOP - 0.475), GOLD_DARK, bevel=0.1, segments=1)  # its seam
    for x in (-1, 1):
        for y in (-1, 1):
            ball(0.4, (x * 2.05, y * 2.05, CUSHION_TOP - 0.62), GOLD_DARK, segments=8)


def stall():
    """A wooden counter under a striped awning, with its wares on the counter and its stock behind it.
    Built a size too big and scaled down where it is placed."""
    cream = "FFF8EC"
    box((11.6, 3.6, 3.4), (0, 0, 1.7), WOOD, bevel=0.4)
    box((12.6, 4.5, 0.6), (0, 0, 3.6), WOOD_LIGHT, bevel=0.25)
    for x in (-2.9, 0, 2.9):
        box((0.3, 0.3, 2.6), (x, -1.75, 1.75), WOOD_DARK, bevel=0.08, segments=1)
    for side in (-1, 1):
        tube(0.4, 7.0, (side * 5.5, 1.5, 3.6), UP, WOOD_DARK, vertices=8)
        tube(0.4, 5.6, (side * 5.5, -1.7, 3.6), UP, WOOD_DARK, vertices=8)
    slope = math.radians(15)
    for index in range(7):
        x = (index - 3) * 1.95
        colour = AWNING if index % 2 == 0 else cream
        box((1.95, 7.8, 0.5), (x, -1.4, 9.9), colour, bevel=0.18, rotation=(slope, 0, 0))
        box((1.95, 0.45, 1.0), (x, -5.0, 8.45), colour, bevel=0.1, segments=1)  # the edge hangs down, cut in scallops
        tube(0.975, 0.45, (x, -4.775, 7.95), (0, -1, 0), colour, vertices=12)
    # The sign over it: a board with a gold coin, since a mesh carries no words.
    box((8.6, 0.7, 2.7), (0, 1.5, 12.6), WOOD_DARK, bevel=0.3)
    box((7.8, 0.3, 1.9), (0, 1.1, 12.6), WOOD_LIGHT, bevel=0.15)
    tube(1.05, 0.4, (0, 1.0, 12.6), (0, -1, 0), GOLD, vertices=16, roughness=0.3)
    tube(0.7, 0.5, (0, 1.0, 12.6), (0, -1, 0), "FFE27A", vertices=16, roughness=0.3)
    for side in (-1, 1):
        star(0.62, (side * 2.6, 0.9, 12.6), GOLD, depth=0.25)
    # On the counter: a chest, cannonballs, a potion and a pile of coins.
    box((2.5, 1.8, 1.2), (2.7, 0, 4.5), "D9463B", bevel=0.18)
    tube(0.9, 2.5, (1.45, 0, 5.1), (1, 0, 0), "D9463B", vertices=10)
    for x in (1.95, 3.45):
        box((0.36, 1.95, 1.3), (x, 0, 4.5), GOLD, bevel=0.08, segments=1)
        tube(0.98, 0.36, (x - 0.18, 0, 5.1), (1, 0, 0), GOLD, vertices=10)
    box((0.5, 0.3, 0.6), (2.7, -0.95, 4.95), GOLD_DARK, bevel=0.1, segments=1)
    for x, y, z in ((-3.9, 0.2, 4.72), (-2.4, 0.3, 4.72), (-3.15, -0.9, 4.72), (-3.15, -0.1, 5.85)):
        ball(0.82, (x, y, z), IRON, segments=10, roughness=0.35)
    ball(0.62, (-0.5, 0.3, 4.5), "FF5FA2", segments=8, roughness=0.2)
    tube(0.24, 0.6, (-0.5, 0.3, 5.0), UP, "FFD0E4", vertices=6)
    ball(0.26, (-0.5, 0.3, 5.7), WOOD, segments=6)
    for index in range(3):
        tube(0.55, 0.22, (0.55 + index * 0.1, -0.7, 3.9 + index * 0.22), UP, GOLD, vertices=10, roughness=0.3)
    # Behind it, out of everybody's way: a barrel and two crates.
    tube(1.45, 3.0, (4.0, 4.4, 0), UP, WOOD, vertices=10)
    for z in (0.7, 2.3):
        hoop(1.47, 0.16, (4.0, 4.4, z), IRON, segments=10)
    tube(1.25, 0.2, (4.0, 4.4, 2.95), UP, WOOD_LIGHT, vertices=10)
    box((2.8, 2.8, 2.8), (-3.6, 4.5, 1.4), WOOD_LIGHT, bevel=0.2)
    box((1.9, 1.9, 1.9), (-3.4, 4.3, 3.75), WOOD, bevel=0.18, rotation=(0, 0, 0.5))


def portal():
    """A chunky stone arch on two steps: the way back to the base. The glowing sheet in it is a mesh of its
    own (PortalSheet) with the same origin, so the game can make it Neon and hang its prompt on it."""
    glow, pale = ACCENT, ACCENT_PALE
    lights = ("A68AFF", "BEA8FF", "D9CCFF", "F4F0FF") if EARTH else tuple(shade(glow, amount) for amount in (0.2, 0.42, 0.64, 0.88))
    box((15.5, 6.4, 0.7), (0, 0, 0.35), STONE_DARK, bevel=0.25)
    box((13.4, 4.6, 0.7), (0, 0, 1.0), STONE, bevel=0.25)
    for side in (-1, 1):
        for index in range(3):
            box((2.9, 2.9, 3.0), (side * 5.2, 0, 2.85 + index * 3.0), STONE if index % 2 == 0 else STONE_DARK, bevel=0.4, rotation=(0, 0, rng.uniform(-0.09, 0.09)))
        box((3.4, 3.4, 0.9), (side * 5.2, 0, 10.75), STONE_DARK, bevel=0.3)
        for y in (-1.5, 1.5):  # a rune on each face
            box((0.5, 0.3, 1.3), (side * 5.2, y, 5.85), pale, bevel=0.1, segments=1, emission=1.2)
    for index in range(7):  # the arch, block by block, with a fat keystone
        angle = math.radians(index * 30)
        size = (3.5, 3.5, 3.3) if index == 3 else (2.95, 2.9, 2.7)
        box(size, (-math.cos(angle) * 5.2, 0, 11.15 + math.sin(angle) * 5.2), STONE if index % 2 else STONE_DARK, bevel=0.4, rotation=(0, angle - math.pi / 2, 0))
    for y in (-1.8, 1.8):
        ball(0.75, (0, y, 16.35), pale, segments=10, emission=1.4)
    # Crystals and moss at its feet.
    for x, y, radius, length, lean in ((-7.6, -0.6, 0.7, 3.2, -0.3), (-8.5, 0.6, 0.5, 2.0, -0.6), (7.7, 0.4, 0.75, 3.6, 0.3), (8.6, -0.7, 0.5, 2.2, 0.6), (6.9, -1.5, 0.4, 1.5, 0.1)):
        tube(radius, length, (x, y, 0), (lean, 0, 1), pale, tip=0.0, vertices=5, roughness=0.15, emission=0.7)
    for x, y, z, radius in ((-5.6, -0.4, 11.2, 1.0), (3.2, 0.3, 16.75, 1.1), (6.2, 0.9, 1.35, 1.0), (-6.4, 1.0, 1.35, 0.9), (5.5, 0.3, 11.2, 0.8)):
        ball(radius, (x, y, z), GRASS_LIGHT, scale=(1.2, 1, 0.42), segments=8)
    # The sheet, with rings of light in it, the same from both sides.
    home = kit.use("PortalSheet")
    box((7.8, 0.4, 9.8), (0, 0, 6.25), glow, bevel=0.05, segments=1, emission=1.0)
    tube(3.95, 0.4, (0, 0.2, 11.15), (0, -1, 0), glow, vertices=24, emission=1.0)
    for radius, depth, x, z, colour in ((3.3, 0.5, 0.0, 8.2, lights[0]), (2.4, 0.6, 0.25, 8.45, lights[1]), (1.5, 0.7, -0.1, 8.6, lights[2]), (0.7, 0.8, 0.1, 8.5, lights[3])):
        tube(radius, depth, (x, depth / 2, z), (0, -1, 0), colour, vertices=20, emission=0.8)
    kit.use(home)


def boss_plinth():
    """What the boss's statue stands on: three round steps, 18 across at the foot like the game's fountain
    and PLINTH_TOP high like its fountain and plinth together. The top step is 10.4 across."""
    tube(9.0, 0.8, (0, 0, 0), UP, STONE_DARK, vertices=28)
    tube(7.0, 0.6, (0, 0, 0.8), UP, STONE, vertices=24)
    tube(5.2, PLINTH_TOP - 1.4, (0, 0, 1.4), UP, STONE_PALE, vertices=24)
    hoop(7.05, 0.26, (0, 0, 1.1), GOLD, segments=24, roughness=0.3)
    box((4.6, 0.5, 1.1), (0, -7.25, 1.35), GOLD, bevel=0.18, roughness=0.3)
    star(0.42, (0, -7.55, 1.35), GOLD_DARK, depth=0.15)


def boss():
    """For the photos only: King Kaboom's shapes (tools/blender/boss_king.py) carved in stone, with a gold
    crown and eyes that glow. Built his size (about 4 tall) and scaled up when placed."""
    stone, dark, pale, eye = "C9C4D8", "8F8AA8", "E6E2F0", "7CFF6B"
    box((3.0, 2.6, 2.7), (0, 0, 1.75), stone, bevel=0.62, segments=3)
    ball(1.0, (0, -1.22, 1.25), pale, scale=(1.05, 0.22, 0.8))
    front = -1.3
    for side in (-1, 1):
        box((1.0, 1.25, 0.6), (side * 0.85, -0.25, 0.3), dark, bevel=0.26)
        box((0.62, 0.8, 1.0), (side * 1.72, -0.25, 1.35), dark, bevel=0.28, rotation=(0, side * math.radians(-18), 0))
        x = side * 0.72
        ball(0.6, (x, front - 0.02, 2.05), pale, scale=(1, 0.3, 1.08), segments=16)
        ball(0.5, (x, front - 0.1, 2.02), IRON, scale=(1, 0.3, 1.1), segments=16, roughness=0.3)
        ball(0.3, (x, front - 0.2, 1.93), eye, scale=(1, 0.25, 1), segments=16, emission=1.5)
        ball(0.15, (x - 0.16, front - 0.27, 2.24), WHITE, scale=(1, 0.3, 1), segments=8, roughness=0.2)
        box((0.85, 0.22, 0.24), (x, front - 0.16, 2.74), dark, bevel=0.09, rotation=(0, side * math.radians(-24), 0), segments=1)
        tube(0.17, 0.42, (side * 0.33, front - 0.14, 1.27), (0, 0, -1), pale, tip=0.0, vertices=8)
        tube(0.34, 0.95, (side * 1.0, 0.05, 2.88), (side * 0.47, 0, 0.88), pale, tip=0.0, vertices=10)
    box((1.05, 0.16, 0.22), (0, front - 0.08, 1.26), IRON, bevel=0.07, segments=1)
    tube(0.82, 0.36, (0, 0, 3.1), UP, GOLD, vertices=16, roughness=0.3)
    for index in range(5):
        x, y = ring(index * 72 + 180, 0.7)
        tube(0.24, 0.6, (x, y, 3.42), UP, GOLD, tip=0.0, vertices=8, roughness=0.3)
        ball(0.11, (x, y, 4.05), GOLD, segments=6, roughness=0.3)
        ball(0.14, (x * 1.17, y * 1.17, 3.28), eye, segments=6, emission=1.5)
    for index in range(5):  # the fuse he has for a tail
        ball(0.16 - 0.015 * index, (0.25 * math.sin(index * 0.75), 1.55 + 0.25 * index, 1.2 + 0.3 * index), dark, segments=8)
    ball(0.24, (0.04, 2.7, 2.6), GOLD, segments=8, roughness=0.3)
    for x, y, z, radius in ((-0.95, -0.2, 3.1, 0.55), (1.2, 0.6, 3.1, 0.4), (1.78, -0.2, 1.9, 0.36), (-0.8, -0.6, 0.62, 0.4)):  # moss
        ball(radius, (x, y, z - 0.05), GRASS_LIGHT, scale=(1.2, 1, 0.4), segments=8)


def pond(reach, fall, bridge):
    """A round pond with a stream out of its front, over the island's edge. `reach` is the stream's path as
    (distance from the pond's middle, height) points, `fall` how far down the waterfall goes, `bridge` how
    far from the pond's middle the little bridge crosses the stream."""
    tube(10.2, 0.5, (0, 0, -0.34), UP, SAND, vertices=24)
    for index in range(13):
        degrees = index * 27.7 + 20
        if 160 < degrees % 360 < 200:  # the stream leaves here
            continue
        x, y = ring(degrees, 9.6)
        chunk((rng.uniform(1.1, 1.8), rng.uniform(1.0, 1.5), rng.uniform(0.7, 1.1)), (x, y, 0.35), rng.choice((ROCK, ROCK_LIGHT, ROCK_DARK)), detail=1)
    if LIQUID == "water":
        for x, y in ((-4.0, 2.5), (3.2, 4.2), (4.6, -1.5)):  # lily pads
            tube(1.3, 0.16, (x, y, 0.24), UP, LEAVES[1], vertices=8)
        ball(0.5, (-4.0, 2.5, 0.6), PETALS[0], scale=(1, 1, 0.7), segments=6)
    elif LIQUID == "stardust":  # stars drifting on it
        for x, y, size, turn in ((-4.0, 2.5, 1.5, 0.3), (3.2, 4.2, 1.1, 1.2), (4.6, -1.5, 1.3, 2.0)):
            star(size, (x, y, 0.3), WHITE, depth=0.2, rotation=(math.pi / 2, 0, turn), emission=1.4)
    elif LIQUID == "lava":  # plates of crust
        for x, y, size in ((-4.0, 2.5, 1.6), (3.2, 4.2, 1.2), (4.6, -1.5, 1.4)):
            tube(size, 0.3, (x, y, 0.12), UP, ROCK, vertices=6)
    elif LIQUID == "oasis":
        palm(-10.6, 3.6)
    for x, y, height in ((-7.2, 5.2, 3.6), (-6.2, 6.3, 4.4), (-7.9, 4.2, 3.0), (7.3, 5.0, 4.0), (6.4, 6.0, 3.2)) if CLUTTER else ():  # reeds
        tube(0.16, height, (x, y, 0), (rng.uniform(-0.1, 0.1), 0, 1), GRASS_RIM, vertices=5)
        tube(0.36, 1.3, (x, y, height - 0.3), UP, WOOD_DARK, vertices=6)
    for index, rise in enumerate((-0.35, 0.35, 0.6, 0.35, -0.35)):  # the bridge: five planks in an arch
        box((1.9, 3.4, 0.45), ((index - 2) * 1.6, -bridge, 0.75 + rise), WOOD_LIGHT, bevel=0.12, rotation=(0, (index - 2) * 0.28, 0), segments=1)
    for side in (-1, 1):
        for x in (-3.9, 3.9):
            box((0.6, 0.6, 2.6), (x, -bridge + side * 1.5, 1.2), WOOD, bevel=0.15, segments=1)
        for x in (-3.9, 0.0):
            tube(0.2, 4.0, (x, -bridge + side * 1.5, 2.2 if x else 2.9), (3.9, 0, 0.7 if x else -0.7), WOOD, vertices=5)
    home = kit.use("Water")
    tube(8.8, 0.5, (0, 0, -0.24), UP, WATER, vertices=24, **WET)
    tube(5.6, 0.5, (1.0, 0.8, -0.2), UP, WATER_LIGHT if LIQUID == "lava" else shade(WATER, 0.25), vertices=20, **WET)
    drop = reach[-1]
    path = reach + [(drop[0] + 0.5, drop[1] - 4.0), (drop[0] + 0.7, drop[1] - fall)]
    ribbon(path, 4.4, WATER, lift=0.3, **WET)
    for shift, width, skip in ((-1.1, 0.8, 1), (0.9, 0.6, 2), (0.0, 0.5, 4)):  # lighter streaks down the fall
        ribbon(path[skip:], width, WATER_LIGHT, thickness=0.3, shift=shift, lift=0.5, **WET)
    if LIQUID == "ice":  # frozen: icicles where it would tip over, no foam
        for x, radius, length in ((-1.7, 0.6, 3.4), (-0.5, 0.45, 2.4), (0.8, 0.7, 4.2), (1.8, 0.4, 2.0)):
            tube(radius, length, (x, -drop[0] - 0.9, drop[1] - 0.2), (0, 0, -1), WATER_LIGHT, tip=0.0, vertices=5, roughness=0.15)
    else:
        for x, z, radius in ((-1.5, 0.3, 1.0), (0.1, 0.5, 1.2), (1.6, 0.2, 0.9)):  # foam where it tips over
            ball(radius, (x, -drop[0] - 0.6, drop[1] + z), WATER_LIGHT if LIQUID == "lava" else WHITE, segments=8, **({"emission": 1.4} if "emission" in WET else {}))
    kit.use(home)


# ---------------------------------------------------------------------------------------------------
# The island: grass on top, a darker rim that hangs over in drips, two bands of dirt, then rock
# tapering down to a point
# ---------------------------------------------------------------------------------------------------
R = RADIUS
LOBES = 24


def drips(degrees):
    return -7.0 - 3.8 * abs(math.sin(math.radians(degrees) * LOBES / 2)) ** 0.7


def wave(depth, swing, count, phase=0.0):
    return lambda degrees: depth + swing * math.sin(math.radians(degrees) * count + phase)


def spike(radius, depth, colour=UNDER):
    lathe([(0, 2.0), (radius, 0.0), (radius * 0.72, -depth * 0.4), (radius * 0.34, -depth * 0.78), (0, -depth)], colour, segments=7, rough=radius * 0.1, smooth=False)


kit.use("Island")
lathe([(0, 0.0)] + [(R * share, top(share)) for share in (0.3, 0.6, 0.85, FLAT, 0.965, 0.98, 0.992, 1.0)] + [(R, -6.0), (0, -6.0)], GRASS, segments=72, shape=outline, roughness=0.9)
lathe([(R * 0.958, top(0.958) - 0.3), (R * 0.965, top(0.965) + 0.15), (R * 0.99, top(0.99) + 0.28), (R * 1.022, -3.1), (R * 1.034, -5.8), (R * 1.012, drips), (R * 0.93, -7.5), (0, -7.5)],
      GRASS_RIM, segments=LOBES * 6, shape=outline, roughness=0.9)
lathe([(R * 0.9, -5.0), (R * 0.975, -6.0), (R * 0.955, -13.0), (R * 0.925, wave(-21.0, 1.6, 7)), (R * 0.6, -20.0), (0, -20.0)], DIRT, segments=48, shape=outline, rough=0.4, roughness=0.9)
lathe([(R * 0.6, -18.0), (R * 0.905, -19.0), (R * 0.86, -27.0), (R * 0.79, wave(-34.5, 2.0, 5, 1.0)), (R * 0.5, -32.0), (0, -32.0)], DIRT_DARK, segments=40, shape=outline, rough=0.5, roughness=0.9)
lathe([(R * 0.5, -30.0), (R * 0.77, -31.5), (R * 0.69, -38.5), (R * 0.55, -47.0), (R * 0.39, -55.5), (R * 0.23, -63.0), (R * 0.09, -69.0), (0, -73.0)], UNDER, segments=18, shape=outline, rough=1.8, smooth=False)
# Rock hanging under the dirt, around the main taper.
for degrees, share, z, radius, depth, colour in ((20, 0.58, -32, 13, 21, UNDER_DARK), (95, 0.62, -32, 12, 18, UNDER), (160, 0.57, -32, 14, 23, UNDER_DARK), (215, 0.64, -32, 11, 16, UNDER),
                                                 (275, 0.59, -32, 13, 20, UNDER_DARK), (330, 0.64, -32, 11, 17, UNDER), (60, 0.78, -27, 7, 12, UNDER_LIGHT), (130, 0.79, -27, 6, 11, UNDER_LIGHT),
                                                 (190, 0.8, -27, 7, 13, UNDER_LIGHT), (245, 0.8, -27, 6, 11, UNDER_LIGHT), (305, 0.79, -27, 7, 12, UNDER_LIGHT), (0, 0.8, -27, 6, 11, UNDER_LIGHT)):
    place(spike, (*spot(degrees, share), z), face=180, radius=radius, depth=depth, colour=colour)
# Stones stuck in the dirt wall.
for index in range(18):
    size = rng.uniform(1.8, 3.4)
    chunk((size, size, size * 0.8), (*spot(index * 20 + rng.uniform(-6, 6), rng.uniform(0.94, 0.96)), rng.uniform(-18.0, -9.5)), rng.choice((ROCK, ROCK_LIGHT)), detail=1)
# Lighter and darker patches, so the lawn is not one flat green. (direction, distance, radius, colour)
for degrees, distance, radius, colour in ((20, 37, 8, GRASS_LIGHT), (62, 40, 9, GRASS_LIGHT), (112, 36, 8, GRASS_DEEP), (138, 47, 6, GRASS_LIGHT), (196, 38, 9, GRASS_LIGHT), (238, 37, 8, GRASS_DEEP),
                                          (255, 46, 7, GRASS_LIGHT), (292, 38, 9, GRASS_LIGHT), (338, 38, 8, GRASS_DEEP), (318, 47, 6, GRASS_LIGHT), (102, 44, 5, GRASS_DEEP), (188, 47, 6, GRASS_DEEP),
                                          (40, 47, 6, GRASS_DEEP), (218, 47, 6, GRASS_LIGHT)):
    dome(radius, 0.2, (*ring(degrees, distance), 0.0), colour, rotation=(0, 0, rng.uniform(0, 3)), stretch=rng.uniform(0.7, 0.9), sink=0.05, segments=14, roughness=0.9)

# ---- The paving: the plaza under the ring of landmarks, the ways to the three statues, the arrival pad,
# the two spots the game fills, the bases of the two monster statues ----
kit.use("Paths")
lathe([(0, 0.12), (10.0, 0.12), (PLAZA - 0.5, 0.12), (PLAZA, 0.0)], SAND, segments=48, roughness=0.9)  # as high as the game's
lathe([(22.3, 0.08), (22.5, 0.19), (24.7, 0.19), (24.95, 0.03)], SAND_DARK, segments=48, roughness=0.9)  # a darker band round its edge
lathe([(6.6, 0.08), (6.8, 0.19), (8.4, 0.19), (8.6, 0.08)], SAND_DARK, segments=32, roughness=0.9)  # and one round the pad
box((5.0, 13.0, 0.3), (0, 30.0, -0.03), SAND, bevel=0.1, segments=1, roughness=0.9)  # north, to the boss
for side in (-1, 1):
    box((21.0, 4.4, 0.3), (side * 34.0, 0, -0.03), SAND, bevel=0.1, segments=1, roughness=0.9)  # east and west, to the monsters
place(arrival_pad, (0, 0))
place(spot_pad, ring(ENCHANT, SPOT_RING), kind="enchant")
place(spot_pad, ring(MASTERY, SPOT_RING), kind="mastery")
for degrees in STATUES:
    place(statue_base, ring(degrees, STATUE_RING))
    claim(*ring(degrees, STATUE_RING), 6.0)
# Cobbles: a ring of them round the pad, more wherever the plaza is bare, and some on the three ways.
TUBS = ((48, 21.3), (108, 21.3), (174, 21.3), (246, 21.3), (311, 21.3))  # tubs of flowers between the landmarks
footprints = [(EGGS[0], LANDMARK_RING, 4.4, 4.4), (EGGS[1], LANDMARK_RING, 4.4, 4.4), (STALL, LANDMARK_RING + 1.0, 7.0, 5.6), (PORTAL, LANDMARK_RING, 8.6, 3.8),
              (ENCHANT, SPOT_RING, 8.0, 8.0), (MASTERY, SPOT_RING, 8.0, 8.0)] + [(degrees, distance, 3.6, 3.6) for degrees, distance in TUBS]  # (direction, distance, half its width, half its depth)


def bare(x, y):
    """Whether a point of the plaza has nothing standing on it."""
    for degrees, distance, wide, deep in footprints:
        a, b = ring(degrees, 1.0)
        along, across = x * a + y * b - distance, x * b - y * a
        if abs(along) < deep and abs(across) < wide:
            return False
    return True


paving = [ring(index * 30 + 15, 10.0) for index in range(12)]
for attempt in range(1500):
    x, y = ring(rng.uniform(0, 360), rng.uniform(11.8, 20.8))
    if len(paving) < 46 and bare(x, y) and all(math.hypot(x - a, y - b) > 2.5 for a, b in paving):
        paving.append((x, y))
paving = [point for point in paving if bare(*point)]
paving += [((index % 2 - 0.5) * 2.0, 25.5 + index * 1.9) for index in range(5)]
paving += [(side * (26.0 + index * 3.1), (index % 2 - 0.5) * 1.6) for side in (-1, 1) for index in range(5)]
if CLUTTER:
    cobbles(paving)
    for index, (degrees, distance) in enumerate(TUBS):
        place(tub, ring(degrees, distance), petal=PETALS[(index * 2) % len(PETALS)])
if EARTH:  # stepping stones are Earth's alone: the other worlds' floors stay bare
    stones(((165, 26.9),))  # to the pond
    stones(((232, 27.2), (233, 30.6), (234, 34.0), (235, 37.4)))  # to the cannon
    stones(((122, 27.2), (121, 30.6), (120, 34.0), (120, 37.4)))  # to the campfire
if CLUTTER:
    stones(((328, 27.2), (327, 30.6), (326, 34.0), (325.5, 37.4)))  # to the pumpkin patch

# ---- The landmark shells, on the game's spots, each facing the arrival pad ----
stand("EggPedestal", egg_pedestal, ring(EGGS[0], LANDMARK_RING))
stand("Stall", stall, ring(STALL, LANDMARK_RING), scale=0.9)
stand("Portal", portal, ring(PORTAL, LANDMARK_RING), scale=0.88, also=("PortalSheet",))
stand("BossPlinth", boss_plinth, ring(0, BOSS_RING))
claim(*ring(0, BOSS_RING), 12.0)
# For the photos only: the second pedestal, an egg on each, a statue on the plinth.
kit.use("Placeholders")
place(egg_pedestal, ring(EGGS[1], LANDMARK_RING))
place(stand_in_egg, ring(EGGS[0], LANDMARK_RING), shell="FFF3D6", spots="FF6A3D")
place(stand_in_egg, ring(EGGS[1], LANDMARK_RING), shell="45B4FF", spots="FFE23A")
place(boss, (*ring(0, BOSS_RING), PLINTH_TOP), face=180, scale=3.2)

# ---- Lamps on the game's four spots, braziers before the boss, the pond with its stream over the south
# edge, and the corners of the lawn ----
POND, POND_AT = 162, 39
CANNON, CAMP, PATCH = ring(236, 44), ring(120, 43), ring(325, 43)
TARGET = (-72, -34, -6)  # the floating rock the cannon aims at
edge = RADIUS * outline(POND)
kit.use("Dressing")
fence()
for degrees in LAMPS:
    place(lamp, ring(degrees, LAMP_RING))
    claim(*ring(degrees, LAMP_RING), 4.0)
    solid("lamp", *ring(degrees, LAMP_RING), 0.6, 11.0)
for side in (-1, 1):
    place(brazier, (side * 11.0, BOSS_RING - 6.5), face=180)
    claim(side * 11.0, BOSS_RING - 6.5, 1.6)
    solid("brazier", side * 11.0, BOSS_RING - 6.5, 1.0, 4.1)
before = len(solids)
frame = place(pond, ring(POND, POND_AT), face=POND, bridge=12.0, fall=23.0,
      reach=[(7.5, 0.0), (edge * FLAT - POND_AT, 0.05)] + [(edge * share - POND_AT, top(share) + rise) for share, rise in ((0.965, 0.2), (0.98, 0.3), (0.992, 0.38), (1.0, 0.4))] + [(edge * 1.035 - POND_AT, -2.9), (edge * 1.055 - POND_AT, -5.0)])
for index in range(before, len(solids)):  # what pond() noted in its own space
    what, x, y, radius, height = solids.pop(before)
    solid(what, x, y, radius, height, frame)
claim(*ring(POND, POND_AT), 11.5)
for distance in (50, 54):
    claim(*ring(POND, distance), 4.5)
if EARTH:
    place(cannon, CANNON, face=math.degrees(math.atan2(TARGET[0] - CANNON[0], TARGET[1] - CANNON[1])))
    solid("cannon", *CANNON, 2.6, 3.4)
    frame = place(campfire, CAMP)
    for degrees in (20, 150, 260):
        solid("log seat", *ring(degrees, 5.2), 1.3, 1.9, frame)
else:  # the world's own two big pieces, on the same spots, each facing the middle
    for (build, parts), at, scale in zip(SET_PIECES[WORLD], (CANNON, CAMP), (1.25, 1.0 if WORLD == "The Sun" else 1.1)):  # as big as their spots allow
        frame = place(build, at, scale=scale)
        for what, x, y, radius, height in parts:
            solid(what, x, y, radius, height, frame, scale)
claim(*CANNON, 6.5)
claim(*CAMP, 7.0)
if CLUTTER:
    place(pumpkins, PATCH, face=140)
    claim(*PATCH, 5.0)

# ---- Trees: big ones inside the fence, a few smaller ones further in, none on the paving, in the ways to
# the statues or by a lamp. (direction, distance, kind, size, green) ----
kit.use("Trees")
TREES = ((-18, 51.5, "tall", 1.2, 1), (18, 51.5, "round", 1.25, 0), (-35, 50.5, "round", 1.05, 2), (35, 50.5, "tall", 1.1, 1),
         (53, 51, "round", 1.1, 0), (68, 50.5, "tall", 0.95, 2), (112, 50.5, "round", 1.0, 1), (128, 51, "tall", 0.9, 2),
         (143, 51.5, "round", 0.75, 0), (184, 51.5, "round", 0.7, 2), (204, 51, "tall", 0.75, 1), (224, 51, "round", 0.85, 0),
         (252, 51, "round", 1.1, 2), (290, 50.5, "tall", 1.05, 1), (307, 51, "round", 1.15, 0),
         (72, 39, "round", 0.8, 2), (108, 38.5, "tall", 0.8, 1), (250, 39, "tall", 0.85, 0), (288, 39, "round", 0.85, 2))
for index, (degrees, distance, kind, size, leaf) in enumerate(TREES):
    x, y = ring(degrees, distance)
    if not EARTH:  # a spire has no crown to fill the sky with: a little bigger, but never through the fence
        size = min(size * 1.15, 1.3)
    place(tree, (x, y), face=rng.uniform(0, 360), scale=size, leaf=LEAVES[leaf], kind=kind, fruit=RED if index in (4, 12, 18) else None)
    claim(x, y, 2.6 * size)
    what, radius, height = TREE_SOLID[TREE]["round" if kind == "round" else "tall"]
    solid(what, x, y, radius, height, scale=size)

# ---- Rocks and mushrooms ----
kit.use("Dressing")
ROCKS = ((9, 52.5, 1.0), (176, 51, 1.0), (345, 52, 1.0)) if EARTH else ()  # by the fence
if CLUTTER:
    ROCKS += ((60, 44, 0.9), (150, 45, 0.9), (213, 43, 0.8), (262, 42, 0.8), (98, 44, 0.8), (40, 44, 0.7), (322, 34, 0.7), (196, 31, 0.7))
for degrees, distance, size in ROCKS:
    x, y = ring(degrees, distance)
    if free(x, y, 2.5 * size):
        place(rocks, (x, y, ground(x, y) - 0.15), face=rng.uniform(0, 360), scale=size)
        claim(x, y, 3.2 * size)
for index, (x, y) in enumerate(scatter(4, 30, 50, 3.2) if CLUTTER else ()):  # mushrooms in twos
    for dx, dy, size in ((0, 0, 1.0), (2.1, 0.6, 0.65)):
        place(mushroom, (x + dx, y + dy), face=rng.uniform(0, 360), scale=size, cap=(RED, "FF8A1F", "B58CFF")[index % 3])

# ---- Bushes, flowers, tufts of grass ----
kit.use("Plants")
BUSHES = ((22, 50.5), (-22, 50.5)) if EARTH else ()  # beside the boss; only Earth has bushes
if CLUTTER:
    BUSHES = ((14, 28.5), (-14, 28.5), (36, 28.5), (60, 28.5), (118, 29), (150, 28.5), (192, 28.5), (218, 28.5), (258, 28.5), (300, 28.5), (340, 30)) + BUSHES  # round the plaza
for index, (degrees, distance) in enumerate(BUSHES):
    x, y = ring(degrees, distance)
    if free(x, y, 2.2):
        place(bush, (x, y), face=rng.uniform(0, 360), scale=rng.uniform(0.9, 1.2), leaf=LEAVES[index % 3], berries=RED if index % 4 == 0 else None)
        claim(x, y, 2.6)
for index, (x, y) in enumerate(scatter(5, 30, 52, 2.6) if EARTH else ()):
    place(bush, (x, y), face=rng.uniform(0, 360), scale=rng.uniform(0.8, 1.25), leaf=LEAVES[index % 3], berries="FFD83A" if index % 3 == 0 else None)
# Flower beds: along the avenue and the two paths, round the plaza, and wherever there is room.
beds = [(side * 4.6, y, "tulip") for side in (-1, 1) for y in (27.6, 32.0)] + [(side * 33.0, across * 4.4, "tulip") for side in (-1, 1) for across in (-1, 1)]
beds += [(*ring(degrees, 27.6), "daisy") for degrees in (26, 48, 70, 132, 158, 204, 246, 318)]
beds = [bed for bed in beds if CLUTTER and all(math.hypot(bed[0] - a, bed[1] - b) > r + 0.6 for a, b, r in taken)]
for x, y, kind in beds:
    claim(x, y, 2.2)
if CLUTTER:
    beds += [(x, y, "tulip" if index % 3 == 0 else "daisy") for index, (x, y) in enumerate(scatter(4, 30, 53, 2.4))]
for index, (x, y, kind) in enumerate(beds):
    colour = PETALS[index % len(PETALS)]
    for dx, dy in ((0, 0), (1.5, 0.7), (-1.0, 1.4)):
        place(flower, (x + dx + rng.uniform(-0.3, 0.3), y + dy + rng.uniform(-0.3, 0.3)), face=rng.uniform(0, 360), scale=rng.uniform(0.85, 1.1), petal=colour, kind=kind)
for index, (x, y) in enumerate(scatter(42, 26.5, 53.5, 0.9) if CLUTTER else ()):
    place(tuft, (x, y), face=rng.uniform(0, 360), scale=rng.uniform(0.8, 1.3), colour=(GRASS_DEEP, GRASS_RIM, GRASS_LIGHT)[index % 3])

# ---- Chunks of the island floating beside it. One holds the cannon's target. ----
kit.use("FloatingRocks")
for x, y, z, size, leaf in ((-80, 14, 2, 7.0, LEAVES[0]), (86, 8, 0, 6.5, LEAVES[1]), (74, -38, -22, 4.5, None), (-72, 50, 8, 4.5, None), (82, -14, -12, 2.6, None), (-82, -4, -30, 2.8, None), (-62, -52, -36, 3.4, None)):
    place(floating_rock, (x, y, z), face=rng.uniform(0, 360), size=size, leaf=leaf)
place(floating_rock, TARGET, face=math.degrees(math.atan2(CANNON[0] - TARGET[0], CANNON[1] - TARGET[1])), size=5.5, extra=target if EARTH else None, leaf=None if EARTH else LEAVES[2])

# ---- Clouds: only the photos' backdrop ----
kit.use("Backdrop")
for x, y, z, size in ((-112, 130, -34, 9), (114, 120, -26, 8), (-98, -10, -52, 6.5), (98, -30, -50, 6), (-45, 40, -62, 10), (50, 30, -70, 9),  # around and under the island
                      (-120, 240, 78, 13), (105, 250, 95, 14), (-15, 330, 135, 15), (170, 200, 50, 10), (-190, 190, 45, 10)):  # the sky seen from the arrival pad
    place(cloud, (x, y, z), face=180 + rng.uniform(-25, 25), scale=size, colour=CLOUD)
mist = Vector((*ring(POND, edge * 1.07), -31.0))  # where the waterfall ends
for dx, dz, size in ((0, 0, 2.6), (-3.5, 1.5, 1.8), (3.8, 1.0, 2.0)) if LIQUID in ("water", "oasis", "stardust") else ():  # ice and lava throw up no mist
    place(cloud, (mist.x + dx, mist.y, mist.z + dz), face=POND, scale=size, colour=CLOUD if LIQUID == "stardust" else WHITE)
if WORLD == "Moon":  # stars in its night sky
    for index in range(90):
        x, y = ring(rng.uniform(0, 360), 1.0)
        rise = rng.uniform(-0.75, 0.9)
        far = rng.uniform(520, 700)
        ball(rng.uniform(1.4, 3.2), (x * far * math.sqrt(1 - rise * rise), y * far * math.sqrt(1 - rise * rise), rise * far), WHITE, segments=6, emission=3.0)

# ---- The two markers tools/studio/setup_models.luau finds the scene's origin, scale and turn with: each a
# mesh of its own, in the export and the .blend, not in the photos ----
for name, at in (("Origin", (0, 0, 1)), ("North", (0, 10, 1))):
    with into(name):
        slab((2, 2, 2), at, "FF00FF").hide_render = True

# ---- What is solid, for SOLIDS in src/server/Islands.luau: { x, z, radius, height } in island space (the
# game's z is -y here); not the fence, the game's rim wall does that ----
key = WORLD if WORLD.isidentifier() else f'["{WORLD}"]'
lines = [f"\t{key} = {{"] + [f"\t\t{{ {x:.1f}, {-y:.1f}, {radius:.1f}, {height:.1f} }}, -- {what}" for what, x, y, radius, height in sorted(solids, key=lambda entry: entry[0])] + ["\t},"]
lines = [line.replace("-0.0,", "0.0,") for line in lines]
os.makedirs(OUT, exist_ok=True)
with open(f"{OUT}/{SLUG}_solids.txt", "w") as file:
    file.write("\n".join(lines) + "\n")
print("SOLIDS for src/server/Islands.luau:")
print("\n".join(lines))


triangles = kit.count()
total = sum(amount for name, amount in triangles.items() if name not in RENDER_ONLY)
if total > 55000:
    print(f"WARNING {WORLD}: {total} triangles, over the 55,000 an island may have")

# ---------------------------------------------------------------------------------------------------
# The photos: a sky that pales towards the horizon and below it, a warm sun from the south-west
# ---------------------------------------------------------------------------------------------------
if EARTH:
    sky = kit.EARTH_SKY
elif WORLD == "Moon":  # night: dark below the horizon too, where sky_ramp would pale
    sky = ((0.0, "2A2468"), (0.36, "1C1A4A"), (0.47, "3A3180"), (0.5, THEME["sky_horizon"]), (0.62, "2A2468"), (0.8, "1C1A4A"), (1.0, THEME["sky_top"]))
else:
    sky = kit.sky_ramp(THEME["sky_top"], THEME["sky_horizon"])
kit.studio(OUT, draft=DRAFT, sky=sky)
bpy.context.scene.cycles.samples = min(bpy.context.scene.cycles.samples, 64)
HERO_TARGET = Vector((0, 0, -14))
# A player's eyes on the arrival pad, looking north at the eggs and the statue.
photo(f"{SLUG}_ground", (0, -5.0, 5.3), (0, 30, 6.4), 20)
# Three-quarters from above, from the south. Last, so the saved file opens on this view.
photo(f"{SLUG}_hero", HERO_TARGET + from_sky(178, 34, 254), HERO_TARGET, 45)

# ---------------------------------------------------------------------------------------------------
# For Roblox: one mesh per group, colours on the vertices, none with over 10,000 triangles. The scenery
# keeps the island's middle (on the ground) as origin, so dropped at the same spot it all lines up. A
# landmark's shell is exported around its own base, front towards -Y; in the saved file it stands on its
# spot of the island.
# ---------------------------------------------------------------------------------------------------
for entry in kit.export(f"{OUT}/{SLUG}.fbx"):
    print("MESH %s triangles %d low (%.2f, %.2f, %.2f) high (%.2f, %.2f, %.2f)" % (entry["name"], entry["triangles"], *entry["low"], *entry["high"]))
