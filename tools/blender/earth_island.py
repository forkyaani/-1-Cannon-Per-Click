"""The Earth island: a floating island in the chunky, rounded simulator style, made to stand in for the
island the game builds from parts (src/server/Islands.luau) without moving any of its spots.

Run: blender --background --python tools/blender/earth_island.py -- <output folder> [draft] [clutter]

Island space is the game's: the arrival pad in the middle, 1 unit is 1 stud, the ground's top is z = 0,
x is east and +Y is north (the game's z is -y here). 0 degrees is north, 90 east. Where things stand is
copied from Islands.luau: eggs at ring(-25, 15) and ring(25, 15), the stall at ring(75, 15), the portal at
ring(140, 15), the enchant and mastery spots at ring(207, 16) and ring(282, 16), lamps at 36, the boss's
statue at ring(0, 44), a monster's statue at ring(270, 47) and ring(90, 47). A player gets 55.6 from the
middle; the grass is level that far and ends a little past the game's 58.

Writes earth_island_hero.png and earth_island_ground.png (the two photos), earth_island.blend, and
earth_island.fbx with two kinds of mesh, colours on the vertices as minis.py does:
  scenery, shown as it is, all with the island's middle (on the ground) as origin:
      Earth_Island  Earth_Paths  Earth_FloatingRocks  Earth_Trees  Earth_Plants  Earth_Dressing
      Earth_Glow (for Neon)  Earth_Water (for Glass)
  landmark shells, each with the middle of its own base as origin and its front towards -Y:
      Earth_EggPedestal (one, no egg: the cushion's top is CUSHION_TOP up)  Earth_Stall
      Earth_Portal  Earth_PortalSheet (same origin as the portal)
      Earth_BossPlinth (no statue: PLINTH_TOP high, 18 across)
The eggs and the statue in the photos are stand-ins and are not exported; neither are the clouds.
`draft` makes the photos at half size, for a quick look. `clutter` puts the small ground dressing back
(see CLUTTER).

The kit is tools/blender/kit.py (box, ball, tube, lathe, colours from hex codes, groups, photos, export).
Its pieces are made with bmesh instead of operators: the island has some 1,300 pieces, and an operator
gets slower with every object already in the scene.
"""
import math
import os
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import kit
from kit import *

OUT, ARGS = kit.args()
DRAFT = "draft" in ARGS
# The small things on the ground: flowers, tufts of grass, mushrooms, tubs, cobbles on the plaza, the pumpkin
# patch, most rocks and the bushes round the plaza. Off since 2026-10-05: Yaani found the floor too crowded.
# The trees, the fence, the lamps, the pond, the cannon and the campfire are not part of it.
CLUTTER = "clutter" in ARGS

# Pieces are collected per group: a group becomes one mesh. In the scenery anything that glows goes to the
# group "Glow" and the water to "Water", so that in Roblox those two meshes can be given Neon and Glass. A
# landmark's shell keeps its own glowing bits.
SCENERY = ("Island", "Paths", "FloatingRocks", "Trees", "Plants", "Dressing", "Water", "Glow")
RENDER_ONLY = ("Placeholders", "Backdrop")  # in the photos, not in the export
kit.init(seed=7, prefix="Earth_", scenery=SCENERY, render_only=RENDER_ONLY)  # the same "random" island every run

GRASS, GRASS_LIGHT, GRASS_DEEP, GRASS_RIM = "6FD046", "92E35A", "58BE3E", "389A45"
DIRT, DIRT_DARK = "C98B4D", "9C6436"
ROCK, ROCK_DARK, ROCK_LIGHT = "9A93B5", "756E98", "B9B3CF"
UNDER, UNDER_DARK, UNDER_LIGHT = "7C75A3", "5F5888", "958EB6"  # the rock under the island
SAND, SAND_DARK, COBBLE = "F6DFA6", "E3C385", "FFF1CC"
STONE, STONE_DARK, STONE_PALE = "DCD6CC", "B9B2A8", "F4EFE6"
WOOD, WOOD_LIGHT, WOOD_DARK = "B9783F", "E3B06B", "8A5A2B"
WATER, WATER_LIGHT = "3FBDF5", "A8E8FF"
WHITE, INK, GOLD, GOLD_DARK = "FFFFFF", "1B1140", "FFC61A", "E09A12"
IRON, RED, BLUE = "4A4763", "FF4D4D", "3FA9FF"
LEAVES = ("4FC44A", "2FA85A", "8FD93E")
PETALS = ("FF7AB8", "FFFFFF", "FFD83A", "FF5A5A", "B58CFF")

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
def tree(leaf=LEAVES[0], kind="round", fruit=None):
    """A fat trunk and a few balls of leaves in three tones of one green. About 16 tall."""
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
    tube(0.36, 8.0, (0, 0, 0.8), UP, IRON, vertices=8)
    tube(0.95, 0.4, (0, 0, 8.8), UP, IRON, vertices=8)
    ball(1.2, (0, 0, 10.2), "FFE9A8", emission=1.0)
    tube(1.4, 1.1, (0, 0, 11.1), UP, IRON, tip=0.15, vertices=8)


def brazier():
    tube(1.3, 0.7, (0, 0, 0), UP, STONE_DARK, vertices=8)
    tube(0.75, 3.4, (0, 0, 0.7), UP, STONE, tip=0.6, vertices=8)
    tube(1.0, 1.1, (0, 0, 4.1), UP, IRON, tip=1.75, vertices=10)
    ball(1.25, (0, 0, 5.5), "FF8A1F", scale=(1, 1, 1.1), segments=10, emission=1.4)
    ball(0.8, (0.15, 0, 6.5), "FFD83A", scale=(1, 1, 1.4), segments=8, emission=1.6)


def fence(step=7.2):
    """A wooden fence all the way round the rim, where the game's wall stands (the stream runs out under it)."""
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
    elif size > 3:
        place(bush, (-size * 0.2, 0, 0.8), face=180, scale=size / 9, leaf=LEAVES[2])



# ---------------------------------------------------------------------------------------------------
# The paving and what the game builds on: the arrival pad, the two empty spots, the statues' bases
# ---------------------------------------------------------------------------------------------------
def arrival_pad():
    """Where players land: a glowing disc in a stone ring, with a star in it. Low, like the game's."""
    tube(5.6, 0.3, (0, 0, 0), UP, STONE_DARK, vertices=32)
    tube(5.1, 0.42, (0, 0, 0), UP, STONE, vertices=32)
    tube(4.5, 0.5, (0, 0, 0), UP, "35CFFF", vertices=32, emission=0.8)
    tube(3.3, 0.56, (0, 0, 0), UP, "8DE8FF", vertices=24, emission=0.8)
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
        colour = RED if index % 2 == 0 else cream
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
    glow, pale = "8E6BFF", "C7B5FF"
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
    for radius, depth, x, z, colour in ((3.3, 0.5, 0.0, 8.2, "A68AFF"), (2.4, 0.6, 0.25, 8.45, "BEA8FF"), (1.5, 0.7, -0.1, 8.6, "D9CCFF"), (0.7, 0.8, 0.1, 8.5, "F4F0FF")):
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
    for x, y in ((-4.0, 2.5), (3.2, 4.2), (4.6, -1.5)):  # lily pads
        tube(1.3, 0.16, (x, y, 0.24), UP, LEAVES[1], vertices=8)
    ball(0.5, (-4.0, 2.5, 0.6), PETALS[0], scale=(1, 1, 0.7), segments=6)
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
    tube(8.8, 0.5, (0, 0, -0.24), UP, WATER, vertices=24, roughness=0.15)
    tube(5.6, 0.5, (1.0, 0.8, -0.2), UP, shade(WATER, 0.25), vertices=20, roughness=0.15)
    drop = reach[-1]
    path = reach + [(drop[0] + 0.5, drop[1] - 4.0), (drop[0] + 0.7, drop[1] - fall)]
    ribbon(path, 4.4, WATER, lift=0.3, roughness=0.15)
    for shift, width, skip in ((-1.1, 0.8, 1), (0.9, 0.6, 2), (0.0, 0.5, 4)):  # lighter streaks down the fall
        ribbon(path[skip:], width, WATER_LIGHT, thickness=0.3, shift=shift, lift=0.5, roughness=0.15)
    for x, z, radius in ((-1.5, 0.3, 1.0), (0.1, 0.5, 1.2), (1.6, 0.2, 0.9)):  # foam where it tips over
        ball(radius, (x, -drop[0] - 0.6, drop[1] + z), WHITE, segments=8)
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
for side in (-1, 1):
    place(brazier, (side * 11.0, BOSS_RING - 6.5), face=180)
    claim(side * 11.0, BOSS_RING - 6.5, 1.6)
place(pond, ring(POND, POND_AT), face=POND, bridge=12.0, fall=23.0,
      reach=[(7.5, 0.0), (edge * FLAT - POND_AT, 0.05)] + [(edge * share - POND_AT, top(share) + rise) for share, rise in ((0.965, 0.2), (0.98, 0.3), (0.992, 0.38), (1.0, 0.4))] + [(edge * 1.035 - POND_AT, -2.9), (edge * 1.055 - POND_AT, -5.0)])
claim(*ring(POND, POND_AT), 11.5)
for distance in (50, 54):
    claim(*ring(POND, distance), 4.5)
place(cannon, CANNON, face=math.degrees(math.atan2(TARGET[0] - CANNON[0], TARGET[1] - CANNON[1])))
claim(*CANNON, 6.5)
place(campfire, CAMP)
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
    place(tree, (x, y), face=rng.uniform(0, 360), scale=size, leaf=LEAVES[leaf], kind=kind, fruit=RED if index in (4, 12, 18) else None)
    claim(x, y, 2.6 * size)

# ---- Rocks and mushrooms ----
kit.use("Dressing")
ROCKS = ((9, 52.5, 1.0), (176, 51, 1.0), (345, 52, 1.0))  # by the fence
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
BUSHES = ((22, 50.5), (-22, 50.5))  # beside the boss
if CLUTTER:
    BUSHES = ((14, 28.5), (-14, 28.5), (36, 28.5), (60, 28.5), (118, 29), (150, 28.5), (192, 28.5), (218, 28.5), (258, 28.5), (300, 28.5), (340, 30)) + BUSHES  # round the plaza
for index, (degrees, distance) in enumerate(BUSHES):
    x, y = ring(degrees, distance)
    if free(x, y, 2.2):
        place(bush, (x, y), face=rng.uniform(0, 360), scale=rng.uniform(0.9, 1.2), leaf=LEAVES[index % 3], berries=RED if index % 4 == 0 else None)
        claim(x, y, 2.6)
for index, (x, y) in enumerate(scatter(5, 30, 52, 2.6)):
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
place(floating_rock, TARGET, face=math.degrees(math.atan2(CANNON[0] - TARGET[0], CANNON[1] - TARGET[1])), size=5.5, extra=target)

# ---- Clouds: only the photos' backdrop ----
kit.use("Backdrop")
for x, y, z, size in ((-112, 130, -34, 9), (114, 120, -26, 8), (-98, -10, -52, 6.5), (98, -30, -50, 6), (-45, 40, -62, 10), (50, 30, -70, 9),  # around and under the island
                      (-120, 240, 78, 13), (105, 250, 95, 14), (-15, 330, 135, 15), (170, 200, 50, 10), (-190, 190, 45, 10)):  # the sky seen from the arrival pad
    place(cloud, (x, y, z), face=180 + rng.uniform(-25, 25), scale=size)
mist = Vector((*ring(POND, edge * 1.07), -31.0))  # where the waterfall ends
for dx, dz, size in ((0, 0, 2.6), (-3.5, 1.5, 1.8), (3.8, 1.0, 2.0)):
    place(cloud, (mist.x + dx, mist.y, mist.z + dz), face=POND, scale=size)


kit.count()

# ---------------------------------------------------------------------------------------------------
# The photos: a sky that pales towards the horizon and below it, a warm sun from the south-west
# ---------------------------------------------------------------------------------------------------
kit.studio(OUT, draft=DRAFT)
HERO_TARGET = Vector((0, 0, -14))
# A player's eyes on the arrival pad, looking north at the eggs and the statue.
photo("earth_island_ground", (0, -5.0, 5.3), (0, 30, 6.4), 20)
# Three-quarters from above, from the south. Last, so the saved file opens on this view.
photo("earth_island_hero", HERO_TARGET + from_sky(178, 34, 254), HERO_TARGET, 45)

# ---------------------------------------------------------------------------------------------------
# For Roblox: one mesh per group, colours on the vertices, none with over 10,000 triangles. The scenery
# keeps the island's middle (on the ground) as origin, so dropped at the same spot it all lines up. A
# landmark's shell is exported around its own base, front towards -Y; in the saved file it stands on its
# spot of the island.
# ---------------------------------------------------------------------------------------------------
kit.export(f"{OUT}/earth_island.fbx")
