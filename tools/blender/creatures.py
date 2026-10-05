"""A world's monsters and bosses in the cute-cube style of wave.py: `creatures.py <World>` makes its five
monsters and two bosses (Earth: the two bosses, its monsters exist) in one run.

    blender --background --python tools/blender/creatures.py -- <World> <output folder> [draft]

Writes <world>_creatures.fbx (world in lower case, spaces as underscores), the .blend beside it and one photo,
<world>_creatures.png: the creatures in a row, turned 34 degrees. `draft` halves the photo.

Every creature is ONE mesh named after the game's monster with underscores for spaces (Moon_Rockling), its
colours on the vertices ("Col"), its origin on the ground under it, its front towards -Y, about 2 units tall
(a boss 2.6). In the .fbx they all stand on the origin; in the .blend they stand in the photo's row.
A floater hovers 0.6 over a thin puddle of light that lies on the ground: tools/studio/setup_models.luau puts
the pivot at the bottom of the mesh, so without the puddle the hover would be lost (Earth's Wisp has one too).

How it is built
  * The pieces: `cube`, `cone`, `disc`, `plate`, `flame`, `crystal`, and the kit's box, ball, tube, lathe ...
  * The face: `eyes`, `mouth`.
  * The bodies: `blob`, `biped`, `crawler`, `floater`. Each returns the y of its front, for the face.
  * The features: feet, arms, horns, ears, wings, claws, tail, wheels, crown, helmet, crater, tuft ...
  * One design function per creature composes them: design(c, a) gets the monster's colour and accent (the
    game's, Config.Worlds, pushed to candy: no greys). A design is drawn in loose units, standing on z = 0
    (a floater too: `stage` lifts it); `stage` sizes it afterwards.
  * WORLDS lists who is in which world. The names are Config.Worlds' monster names, letter for letter.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import kit
from kit import *

WHITE, INK, BLUSH, GOLD, GEM = "FFFFFF", "1B1140", "FF8FB8", "FFC61A", "FF3355"
HEIGHT, BOSS_HEIGHT, HOVER = 2.0, 2.6, 0.6
WIDEST, BOSS_WIDEST = 3.3, 4.3  # a low wide creature is sized by its width instead
POSE = math.radians(-34)  # how far each one is turned in the photo
BACKDROPS = {"Earth": "8FD6A0", "Moon": "8F88CC", "Mars": "86B8D8", "Neptune": "6FA4E0", "The Sun": "8C6A9A"}


# ---------------------------------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------------------------------
def cube(w, d, h, z0, colour, bevel=0.5, seg=3, x=0.0, y=0.0, **look):
    """A rounded block standing on z0."""
    return box((w, d, h), (x, y, z0 + h / 2), colour, bevel=bevel, segments=seg, **look)


def cone(radius, depth, base, direction, colour, sides=8, **look):
    return tube(radius, depth, base, direction, colour, tip=0.0, vertices=sides, **look)


def disc(radius, at, colour, height=None, stretch=1.0, sides=10, sink=None, towards=(0, -1, 0), **look):
    """A low cap lying on a surface, looking `towards`; `stretch` makes it taller than wide."""
    rotation = Vector(towards).to_track_quat("Z", "Y").to_euler()
    return dome(radius, radius * 0.28 if height is None else height, at, colour, rotation=rotation, stretch=stretch, sink=sink, segments=sides, **look)


def plate(outline, colour, at=(0, 0, 0), thick=0.14, rotation=(0, 0, 0), **look):
    """A flat shape standing upright, facing the front: `outline` is its (x, z) corners."""
    n, half = len(outline), thick / 2
    vertices = [(x, -half, z) for x, z in outline] + [(x, half, z) for x, z in outline]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh(vertices, faces, colour, at, rotation, smooth=False, tidy=True, **look)


def flame(at, radius, height, colour, sides=6, rotation=(0, 0, 0), **look):
    """A teardrop standing on `at`."""
    rings = [(0, height), (radius * 0.2, height * 0.82), (radius * 0.6, height * 0.58), (radius * 0.92, height * 0.36), (radius, height * 0.2), (radius * 0.7, height * 0.04), (0, 0)]
    return lathe(rings, colour, segments=sides, location=at, rotation=rotation, **look)


def fire(at, size, outer, inner, lean=0.0):
    """A fire standing on `at`: a tall tongue with a smaller one licking out at each side, a paler heart in front."""
    x, y, z = at
    flame(at, 0.52 * size, 1.5 * size, outer, rotation=(lean, 0.12, 0), emission=0.3)
    flame((x - 0.36 * size, y, z), 0.34 * size, 0.95 * size, outer, sides=5, rotation=(lean, -0.5, 0), emission=0.3)
    flame((x + 0.38 * size, y, z), 0.3 * size, 0.8 * size, outer, sides=5, rotation=(lean, 0.55, 0), emission=0.3)
    flame((x, y - 0.3 * size, z), 0.3 * size, 0.8 * size, inner, sides=5, rotation=(lean, 0, 0), emission=0.8)


def crystal(at, radius, height, colour, lean=(0, 0), sides=5, **look):
    """An ice shard or a gem: a faceted spike standing on `at`, leaning (to the side, to the back) in degrees."""
    way = Vector((math.sin(math.radians(lean[0])), math.sin(math.radians(lean[1])), 1)).normalized()
    tube(radius * 0.8, height * 0.55, at, way, colour, tip=radius, vertices=sides, smooth=False, **look)
    tube(radius, height * 0.45, Vector(at) + way * height * 0.55, way, colour, tip=0.0, vertices=sides, smooth=False, **look)


def crescent(radius, bite=0.55, points=9, sweep=150):
    """The outline of a crescent moon, its horns pointing up."""
    outer = [(math.sin(math.radians(a)) * radius, -math.cos(math.radians(a)) * radius) for a in (-sweep + index * 2 * sweep / (points - 1) for index in range(points))]
    inner = [(x * (1 - bite * 0.45), z * (1 - bite) + radius * bite * 0.75) for x, z in reversed(outer[1:-1])]
    return outer + inner


# ---------------------------------------------------------------------------------------------------
# The face
# ---------------------------------------------------------------------------------------------------
def eyes(front, z, spread, iris, size=1.0, brow=None, tilt=-20, blush=True):
    """Two big glossy eyes on the front (y = front), blush under them, brows when `brow` is a colour."""
    for side in (-1, 1):
        x = side * spread
        disc(0.5 * size, (x, front, z), WHITE, height=0.1 * size, stretch=1.08, sides=12, sink=0.04 * size, roughness=0.2)
        disc(0.41 * size, (x, front - 0.075 * size, z - 0.02 * size), INK, height=0.08 * size, stretch=1.1, sides=12, sink=0.05 * size, roughness=0.08)
        disc(0.25 * size, (x, front - 0.17 * size, z - 0.1 * size), iris, height=0.05 * size, sink=0.02 * size, sides=8, roughness=0.3, emission=1.5)
        disc(0.14 * size, (x - 0.13 * size, front - 0.21 * size, z + 0.17 * size), WHITE, height=0.04 * size, sink=0.02 * size, sides=6, roughness=0.2)
        disc(0.07 * size, (x + 0.16 * size, front - 0.2 * size, z - 0.16 * size), WHITE, height=0.03 * size, sink=0.02 * size, sides=5, roughness=0.2)
        if blush:
            disc(0.2 * size, (side * (spread + 0.44 * size), front + 0.02, z - 0.52 * size), BLUSH, height=0.05, stretch=0.6, sides=8)
        if brow:
            box((0.7 * size, 0.2, 0.19 * size), (x, front - 0.13 * size, z + 0.62 * size), brow, bevel=0.07, segments=1, rotation=(0, side * math.radians(tilt), 0))


def mouth(front, z, width=0.5, kind="smile", teeth=WHITE):
    """smile, flat, o, fangs (two teeth pointing down), tusks (two pointing up), grin (a row of teeth)."""
    y = front - 0.05
    if kind == "o":
        disc(width * 0.3, (0, front - 0.02, z), INK, stretch=1.2, sides=8)
        return
    slab((width, 0.14, 0.13 if kind != "grin" else 0.3), (0, y, z), INK)
    if kind == "smile":
        for side in (-1, 1):
            slab((0.2, 0.14, 0.13), (side * (width / 2 + 0.04), y, z + 0.06), INK, rotation=(0, side * math.radians(-40), 0))
    elif kind == "fangs":
        for side in (-1, 1):
            cone(0.13, 0.36, (side * width * 0.3, y - 0.07, z + 0.02), (0, 0, -1), teeth, sides=6)
    elif kind == "tusks":
        for side in (-1, 1):
            cone(0.16, 0.5, (side * width * 0.42, y - 0.08, z - 0.04), (side * 0.15, 0, 1), teeth, sides=6)
    elif kind == "grin":
        for index in range(4):
            slab((width * 0.19, 0.06, 0.2), ((index - 1.5) * width * 0.23, y - 0.08, z + 0.02), teeth)


# ---------------------------------------------------------------------------------------------------
# Bodies. Each returns the y of its front.
# ---------------------------------------------------------------------------------------------------
def feet(colour, spread, size=(0.75, 0.95, 0.45), y=-0.2):
    for side in (-1, 1):
        box(size, (side * spread, y, size[2] / 2), colour, bevel=0.2, segments=2)


def arms(colour, x, z, size=(0.5, 0.62, 1.1), tilt=-14, fist=None, y=-0.15, fist_size=0.42):
    """Stubby arms hanging at the sides; `fist` is the colour of a ball at each end."""
    for side in (-1, 1):
        box(size, (side * x, y, z), colour, bevel=0.22, segments=2, rotation=(0, side * math.radians(tilt), 0))
        if fist:
            lean = math.sin(math.radians(-tilt)) * size[2] / 2
            ball(fist_size, (side * (x + lean), y - 0.05, z - size[2] / 2 - fist_size * 0.3), fist, scale=(1, 1, 0.9), segments=8)


def blob(colour, w=2.2, d=2.0, h=1.75, puddle=None, bevel=0.75, **look):
    """A soft heap sitting on the ground, on a puddle when `puddle` is a colour."""
    if puddle:
        ball(1.0, (0, 0, 0.1), puddle, scale=(w * 0.62, d * 0.62, 0.11), segments=12, **look)
    cube(w, d, h, 0.08 if puddle else 0.0, colour, bevel=bevel, **look)
    return -d / 2


def biped(colour, dark, w=2.0, d=1.8, h=1.9, legs=0.4, bevel=0.5, arm=True, belly=None, foot=(0.75, 0.95, 0.45), **look):
    """A block of a body on two feet, with arms and a paler belly."""
    cube(w, d, h, legs, colour, bevel=bevel, **look)
    feet(dark, w * 0.28, size=foot)
    if arm:
        arms(dark, w / 2 + 0.2, legs + h * 0.42, size=(0.48, 0.6, h * 0.5))
    if belly:
        disc(w * 0.36, (0, -d / 2 + 0.02, legs + h * 0.3), belly, height=0.06, stretch=0.85, sides=10)
    return -d / 2


def crawler(colour, dark, w=2.6, d=1.9, h=1.3, lift=0.3, legs=3, bevel=0.5, **look):
    """A low wide body on rows of little legs."""
    cube(w, d, h, lift, colour, bevel=bevel, **look)
    for side in (-1, 1):
        for index in range(legs):
            y = (index - (legs - 1) / 2) * (d * 0.8 / max(legs, 2))
            box((0.5, 0.32, lift + 0.3), (side * (w / 2 - 0.02), y, (lift + 0.3) / 2), dark, bevel=0.12, segments=1, rotation=(0, side * math.radians(24), 0))
    return -d / 2


def floater(colour, radius=1.0, squash=1.0, **look):
    """A round body; `stage` lifts every floater off the ground and lays the puddle under it."""
    ball(radius, (0, 0, radius * squash), colour, scale=(1, 0.95, squash), segments=12, **look)
    return -radius * 0.93


# ---------------------------------------------------------------------------------------------------
# Features
# ---------------------------------------------------------------------------------------------------
def horns(colour, x, z, size=1.0, lean=28, y=0.05, sides=8):
    for side in (-1, 1):
        cone(0.32 * size, 0.95 * size, (side * x, y, z), (side * math.sin(math.radians(lean)), 0, math.cos(math.radians(lean))), colour, sides=sides)


def ears(colour, inner, x, z, size=1.0, lean=70, y=0.05):
    """Big pointed ears sticking out sideways."""
    for side in (-1, 1):
        way = (side * math.sin(math.radians(lean)), 0, math.cos(math.radians(lean)))
        cone(0.42 * size, 1.25 * size, (side * x, y, z), way, colour)
        cone(0.24 * size, 0.85 * size, (side * (x + 0.02), y - 0.16 * size, z), way, inner, sides=6)


def wings(colour, x, z, size=1.0, y=0.25, sweep=18, kind="bat"):
    """Flat wings spread to the sides."""
    if kind == "bat":
        outline = [(0, 0.1), (0.25, 0.75), (1.0, 1.25), (1.9, 1.15), (1.55, 0.55), (1.25, 0.8), (1.0, 0.1), (0.7, 0.5), (0.4, -0.25)]
    else:  # a little rounded wing
        outline = [(0, 0), (0.2, 0.5), (0.8, 0.8), (1.25, 0.55), (1.0, 0.25), (1.1, 0), (0.75, -0.1), (0.8, -0.3), (0.35, -0.3)]
    for side in (-1, 1):
        plate([(px * size * side, pz * size) for px, pz in outline], colour, (side * x, y, z), rotation=(0, 0, side * math.radians(-sweep)))


def claws(colour, dark, x, y, z, size=1.0, sides=(-1, 1)):
    """A crab's claws held out in front: an arm, a fist, two pincers."""
    for side in sides:
        box((0.5 * size, 0.5 * size, 0.5 * size), (side * x, y, z), dark, bevel=0.2, segments=1)
        ball(0.5 * size, (side * (x + 0.4 * size), y - 0.35 * size, z + 0.25 * size), colour, scale=(1, 0.8, 0.85), segments=8)
        cone(0.24 * size, 0.7 * size, (side * (x + 0.25 * size), y - 0.6 * size, z + 0.42 * size), (-side * 0.1, -1, 0.25), colour)
        cone(0.2 * size, 0.6 * size, (side * (x + 0.6 * size), y - 0.6 * size, z + 0.08 * size), (side * 0.1, -1, -0.1), colour)


def tail(points, colour, start=0.24, end=0.12, tip=None, tip_size=0.3, **look):
    """A chain of balls along a path of points; `tip` is the colour of a bigger ball on its end."""
    for index, point in enumerate(points):
        ball(start + (end - start) * index / max(1, len(points) - 1), point, colour, segments=8, **look)
    if tip:
        ball(tip_size, points[-1], tip, segments=8, emission=1.5)


def wheels(colour, hub, x, r=0.55, width=0.4, ys=(0.0,)):
    for side in (-1, 1):
        for y in ys:
            tube(r, width, (side * x, y, r), (side, 0, 0), colour, vertices=10)
            tube(r * 0.4, 0.08, (side * (x + width), y, r), (side, 0, 0), hub, vertices=8)


def crown(z, radius=0.75, colour=GOLD, gems=GEM, points=5, y=0.0, size=1.0):
    tube(radius, 0.34 * size, (0, y, z), UP, colour, vertices=12, roughness=0.3)
    for index in range(points):
        px, py = ring(index * 360 / points + 180, radius * 0.86)
        cone(0.24 * size, 0.6 * size, (px, y + py, z + 0.3 * size), UP, colour, sides=6, roughness=0.3)
        gx, gy = ring(index * 360 / points + 180, radius)
        ball(0.12 * size, (gx, y + gy, z + 0.17 * size), gems, segments=6, emission=0.6)


def helmet(colour, z, radius, trim=None, y=0.0, squash=0.75):
    """A cap over the top of the head, with a band round its rim when `trim` is a colour."""
    lathe([(0, radius * squash), (radius * 0.55, radius * squash * 0.86), (radius * 0.9, radius * squash * 0.5), (radius, 0), (radius * 0.9, -0.08), (0, -0.08)], colour, segments=12, location=(0, y, z), roughness=0.35)
    if trim:
        tube(radius + 0.06, 0.2, (0, y, z - 0.08), UP, trim, vertices=12, roughness=0.3)


def crater(at, radius, height, colour, pool, rim=0.62, sides=10, glow=1.5):
    """A cone with a bowl in its top: a moon crater, a volcano. `pool` is what is in the bowl."""
    top = radius * rim
    lathe([(0, height * 0.6), (top * 0.78, height * 0.6), (top, height), (top * 1.12, height * 0.94), (radius, 0)], colour, segments=sides, location=at)
    disc(top * 0.82, (at[0], at[1], at[2] + height * 0.66), pool, height=0.06, sink=0.02, towards=UP, sides=sides, emission=glow)


def spot(at, radius, colour, towards=(0, -1, 0), ring_colour=None):
    """A flat mark on the body: a moon crater seen from afar, a scale, a patch."""
    if ring_colour:
        disc(radius * 1.3, at, ring_colour, height=radius * 0.16, sides=8, towards=towards)
        at = Vector(at) + Vector(towards).normalized() * radius * 0.12
    disc(radius, at, colour, height=radius * 0.16, sides=8, towards=towards)


def tuft(colour, spots, **look):
    """Balls: fur, snow, hair, smoke. Each spot is (x, y, z, radius)."""
    for x, y, z, radius in spots:
        ball(radius, (x, y, z), colour, scale=(1, 0.9, 1.1), segments=8, **look)


def rocks(colour, spots, detail=1):
    for x, y, z, radius in spots:
        chunk((radius, radius, radius * 0.85), (x, y, z), colour, detail=detail)


def antennae(colour, tip, x, z, height=0.9, lean=18, y=0.0, bulb=0.2):
    for side in (-1, 1):
        way = Vector((side * math.sin(math.radians(lean)), 0, math.cos(math.radians(lean))))
        tube(0.07, height, (side * x, y, z), way, colour, vertices=6)
        ball(bulb, Vector((side * x, y, z)) + way * height, tip, segments=8, emission=1.5)


def rays(at, radius, colour, count=8, size=1.0, y=0.0, start=0.0, sides=6, **look):
    """Cones in a ring that faces the front: a sun's rays, a mane."""
    for index in range(count):
        angle = math.radians(start + index * 360 / count)
        way = (math.sin(angle), 0, math.cos(angle))
        cone(0.3 * size, 0.75 * size, (at[0] + way[0] * radius, at[1] + y, at[2] + way[2] * radius), way, colour, sides=sides, **look)


# ---------------------------------------------------------------------------------------------------
# Earth's bosses
# ---------------------------------------------------------------------------------------------------
def ogre_chief(c, a):
    front = biped(c, a, w=3.0, d=2.5, h=2.7, legs=0.45, bevel=0.7, arm=False, belly=shade(c, 0.35), foot=(1.0, 1.25, 0.55))
    arms(a, 1.75, 1.55, size=(0.7, 0.85, 1.4), tilt=-16, fist=c, fist_size=0.55)
    eyes(front, 2.25, 0.68, "FFC61A", size=1.1, brow=a, tilt=-22)
    mouth(front, 1.3, 1.1, "tusks", teeth="FFF3D6")
    for side in (-1, 1):
        ball(0.42, (side * 1.52, 0, 2.6), c, scale=(0.6, 1, 1.1), segments=8)  # ears
        ball(0.16, (side * 1.72, -0.1, 2.3), GOLD, segments=6)  # earrings
    # The chief's headdress: a band and a fan of big feathers.
    tube(1.0, 0.36, (0, 0, 3.08), UP, "D9432F", vertices=12)
    for index, colour in enumerate(("3FA9F5", "FFC61A", "FF5A3C", "FFC61A", "3FA9F5")):
        lean = (index - 2) * 22
        feather = [(-0.3, 0), (-0.42, 0.9), (0, 1.75), (0.42, 0.9), (0.3, 0)]
        plate(feather, colour, (math.sin(math.radians(lean)) * 0.75, 0.05, 3.3 + math.cos(math.radians(lean)) * 0.2), thick=0.2, rotation=(0, math.radians(lean), 0))
    # A bone club in one fist.
    tube(0.2, 1.7, (2.2, -0.5, 0.75), (0.25, -0.1, 1), "FFF3D6", vertices=8)
    for dx in (-0.2, 0.2):
        ball(0.3, (2.63 + dx, -0.67, 2.42), "FFF3D6", segments=8)


def earth_titan(c, a):
    dark = shade(c, -0.3)
    front = biped(c, dark, w=3.0, d=2.5, h=2.8, legs=0.5, bevel=0.55, arm=False, foot=(1.1, 1.3, 0.6))
    # Boulder shoulders and fists: it is made of the ground.
    for side in (-1, 1):
        chunk((0.85, 0.8, 0.75), (side * 1.8, 0, 2.75), dark, detail=2)
        box((0.6, 0.7, 1.0), (side * 1.85, -0.1, 1.75), c, bevel=0.2, segments=1)
        chunk((0.7, 0.7, 0.65), (side * 1.95, -0.2, 1.0), dark, detail=2)
    eyes(front, 2.3, 0.68, "7CFF4A", size=1.1, brow=dark, tilt=-18)
    mouth(front, 1.35, 0.9, "grin")
    # Moss: a lawn on its head that hangs over the edge, patches on its body.
    box((3.2, 2.7, 0.55), (0, 0, 3.3), a, bevel=0.26, segments=2)
    for x, d in ((-1.1, 0.5), (-0.35, 0.8), (0.5, 0.45), (1.2, 0.7)):
        box((0.5, 0.3, d), (x, front - 0.04, 3.1 - d / 2), a, bevel=0.14, segments=1)
    spot((-0.9, front, 1.0), 0.3, a)
    spot((1.0, front, 0.85), 0.22, a)
    # Its signature: a tree grows on its head.
    tube(0.26, 0.95, (0.15, 0.1, 3.5), (0.1, 0, 1), "8A5A2B", vertices=8)
    for x, z, r in ((0.25, 4.85, 0.85), (-0.35, 4.55, 0.55), (0.85, 4.5, 0.5)):
        ball(r, (x, 0.1, z), "3FB53A" if r > 0.6 else "58D04A", segments=10)
    for x, z, colour in ((-1.1, 3.7, "FF6FA8"), (1.2, 3.68, "FFD93A")):
        ball(0.2, (x, -0.6, z), colour, segments=6)


# ---------------------------------------------------------------------------------------------------
# Moon
# ---------------------------------------------------------------------------------------------------
def moon_rockling(c, a):
    # A cut stone: chamfered and faceted, with craters and a crown of moon rocks.
    box((2.4, 2.0, 1.85), (0, 0, 1.15), c, bevel=0.6, segments=1, smooth=False)
    front = -1.0
    for side in (-1, 1):
        chunk((0.5, 0.55, 0.38), (side * 0.62, -0.15, 0.3), a, detail=1)
    rocks(a, ((-0.75, 0.1, 2.15, 0.6), (0.2, 0.3, 2.3, 0.5), (0.85, -0.1, 2.1, 0.36)), detail=2)
    crystal((0.35, -0.2, 2.0), 0.26, 0.8, "FFE45A", lean=(14, 0), emission=1.5)
    rocks(a, ((-1.25, 0, 1.0, 0.3), (1.25, 0.1, 1.3, 0.26)), detail=1)
    spot((0.0, front + 0.02, 1.98), 0.15, a, ring_colour=shade(c, 0.3))
    spot((0.95, front + 0.02, 0.6), 0.14, a, ring_colour=shade(c, 0.3))
    eyes(front, 1.3, 0.52, "FFE45A", size=0.92)
    mouth(front, 0.68, 0.42)


def crater_crawler(c, a):
    front = crawler(c, a, w=2.8, d=2.1, h=1.2, lift=0.35, legs=3)
    # Its back is one big crater with a glowing pool, and two small ones beside it.
    crater((0, 0.15, 1.4), 1.35, 0.7, a, "C08CFF", rim=0.8, sides=12, glow=2.5)
    crater((-1.05, -0.35, 1.4), 0.42, 0.4, a, "C08CFF", sides=8)
    crater((1.05, -0.3, 1.4), 0.36, 0.34, a, "C08CFF", sides=8)
    antennae(a, "C08CFF", 0.45, 1.45, height=1.25, lean=24, y=-0.85, bulb=0.24)
    eyes(front, 1.02, 0.55, "C08CFF", size=0.85)
    mouth(front, 0.52, 0.4)


def lunar_bat(c, a):
    front = floater(c, 1.0, squash=0.95)
    wings(a, 0.7, 0.75, size=1.25, sweep=14)
    ears(c, "FFB3D9", 0.5, 1.6, size=0.95, lean=24)
    disc(0.6, (0, front + 0.06, 0.62), shade(c, 0.4), height=0.08, sides=10)  # a pale tummy
    for side in (-1, 1):
        ball(0.2, (side * 0.4, -0.2, 0.02), a, scale=(1, 1.3, 0.8), segments=6)  # little feet
    eyes(front, 1.1, 0.42, "FFE45A", size=0.82)
    mouth(front, 0.58, 0.36, "fangs")


def astro_ghost(c, a):
    # A sheet ghost: a round head that falls into a wavy hem.
    hem = lambda angle: 0.12 * math.cos(math.radians(angle * 5))
    lathe([(0, 2.3), (0.75, 2.15), (1.25, 1.7), (1.35, 1.0), (lambda angle: 1.5, hem), (0, 0.35)], c, segments=20, roughness=0.3)
    front = -1.28
    # Its space suit: a visor frame round the face, ear caps, an aerial, a pack on its back.
    hoop(1.05, 0.17, (0, front + 0.1, 1.5), a, rotation=(math.pi / 2, 0, 0), segments=14)
    for side in (-1, 1):
        tube(0.4, 0.3, (side * 1.2, 0, 1.5), (side, 0, 0), "FF9A3C", vertices=8)
        ball(0.28, (side * 1.5, -0.6, 0.85), c, segments=8)  # mitten hands
    tube(0.07, 0.45, (0.55, 0, 2.1), (0.2, 0, 1), a, vertices=6)
    ball(0.22, (0.66, 0, 2.62), "FF5A5A", segments=8, emission=2)
    box((1.3, 0.5, 1.1), (0, 1.3, 1.35), a, bevel=0.18, segments=1)
    eyes(front, 1.55, 0.46, "5AC8FF", size=0.86)
    mouth(front, 0.98, 0.3, "o")


def moon_golem(c, a):
    # Tall, with boulders for shoulders and fists and a glowing crystal core.
    front = biped(c, a, w=1.9, d=1.7, h=2.5, legs=0.45, arm=False, bevel=0.4, foot=(0.8, 1.0, 0.5))
    for side in (-1, 1):
        chunk((0.75, 0.7, 0.68), (side * 1.4, 0, 2.55), a, detail=2)
        box((0.5, 0.6, 0.95), (side * 1.5, -0.05, 1.65), c, bevel=0.2, segments=1)
        chunk((0.62, 0.62, 0.58), (side * 1.58, -0.1, 0.95), a, detail=2)
    crystal((0, 0, 2.85), 0.34, 1.0, "5FF0FF", emission=2)
    crystal((-0.45, 0, 2.85), 0.2, 0.55, "5FF0FF", lean=(-20, 0), emission=2)
    crystal((0.45, 0, 2.85), 0.2, 0.55, "5FF0FF", lean=(20, 0), emission=2)
    disc(0.36, (0, front, 1.0), "5FF0FF", height=0.14, sides=6, emission=2)
    eyes(front, 2.15, 0.46, "5FF0FF", size=0.84, brow=a, tilt=-14)
    mouth(front, 1.52, 0.5, "flat")


def dark_side_stalker(c, a):
    # A prowling shadow: low, wide, on four clawed legs, a crest of glowing spikes, a hooked tail with a lamp.
    cube(3.3, 2.6, 2.0, 0.6, c, bevel=0.7)
    front = -1.3
    for side in (-1, 1):
        for y in (-0.8, 0.8):
            box((0.8, 0.9, 1.0), (side * 1.55, y, 0.5), shade(c, -0.25), bevel=0.25, segments=2)
            for toe in (-0.22, 0, 0.22):
                cone(0.13, 0.36, (side * 1.55 + toe, y - 0.4, 0.14), (0, -1, -0.1), a, sides=5, emission=1)
        # Curved horns that hook inwards, like a crescent.
        cone(0.42, 1.0, (side * 1.25, 0, 2.5), (side * 0.75, 0, 1), a, emission=1)
        cone(0.26, 0.8, (side * 1.72, 0, 3.12), (-side * 0.45, 0, 1), a, sides=6, emission=1)
    for index, height in enumerate((0.75, 1.15, 0.9, 0.65)):
        crystal((0, -0.75 + index * 0.6, 2.5), 0.3, height, a, sides=4, emission=1.5)
    tail([(0, 1.4, 1.6), (0, 1.8, 2.1), (0, 2.0, 2.7), (0, 1.85, 3.3), (0, 1.45, 3.75)], shade(c, -0.25), start=0.3, end=0.18, tip=a, tip_size=0.42)
    eyes(front, 1.75, 0.76, a, size=1.2, brow=shade(c, 0.25), tilt=-26)
    mouth(front, 0.95, 1.0, "fangs")
    spot((0, front, 2.42), 0.2, a)


def moon_colossus(c, a):
    front = biped(c, a, w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.6, belly=shade(a, 0.55), foot=(1.1, 1.3, 0.6))
    # Armour: shoulder plates with a gold stud, a belt, heavy arms.
    for side in (-1, 1):
        ball(0.8, (side * 1.7, 0, 2.85), a, scale=(1, 1, 0.75), segments=10)
        ball(0.2, (side * 1.9, -0.55, 2.95), GOLD, segments=6)
        box((0.65, 0.8, 1.2), (side * 1.85, -0.1, 1.7), c, bevel=0.25, segments=2)
        ball(0.5, (side * 1.95, -0.15, 0.95), a, segments=8)
    box((3.1, 2.6, 0.36), (0, 0, 0.95), a, bevel=0.12, segments=1)
    star(0.3, (0, front - 0.12, 0.95), GOLD, depth=0.12)
    spot((-1.0, front, 1.5), 0.22, shade(c, -0.18))
    spot((1.05, front, 2.9), 0.18, shade(c, -0.18))
    eyes(front, 2.3, 0.68, "6FA0FF", size=1.1, brow=a, tilt=-18)
    mouth(front, 1.45, 0.8, "flat")
    # Its signature: a great golden crescent moon standing on its head.
    plate(crescent(1.35), GOLD, (0, 0, 4.75), thick=0.4, roughness=0.3)
    tube(0.8, 0.3, (0, 0, 3.25), UP, a, vertices=12)
    ball(0.22, (0, -0.2, 4.55), "FFF3A0", segments=6, emission=2)


# ---------------------------------------------------------------------------------------------------
# Mars
# ---------------------------------------------------------------------------------------------------
def martian_grunt(c, a):
    # A little green man: a big dome of a head, aerials, a ray gun.
    cube(2.1, 1.8, 1.7, 0.75, c, bevel=0.75)
    front = -0.9
    cube(1.2, 1.0, 0.7, 0.2, a, bevel=0.25, seg=2)  # a small suit under the big head
    feet("E85A2E", 0.42, size=(0.6, 0.8, 0.35))
    hoop(0.72, 0.16, (0, 0, 0.86), "E85A2E", segments=10)  # collar
    antennae(a, "FF5AF0", 0.55, 2.3, height=0.85, lean=20, bulb=0.24)
    for side in (-1, 1):
        box((0.36, 0.42, 0.62), (side * 0.82, -0.15, 0.6), a, bevel=0.14, segments=1, rotation=(0, side * math.radians(-28), 0))
    # The ray gun, held out at its right.
    tube(0.17, 0.75, (1.12, -0.25, 0.55), (0, -1, 0.1), "FF5AF0", vertices=8, emission=0.5)
    ball(0.26, (1.12, -1.05, 0.63), "FFE45A", segments=8, emission=2)
    box((0.22, 0.26, 0.4), (1.12, -0.35, 0.35), "E85A2E", bevel=0.06, segments=1)
    eyes(front, 1.7, 0.5, "FF5AF0", size=0.95)
    mouth(front, 1.05, 0.34)


def sand_worm(c, a):
    # It comes up out of a mound of sand: fat rings, getting smaller, the head on top.
    ball(1.0, (0, 0, 0.12), a, scale=(1.75, 1.6, 0.3), segments=12)
    for index, (z, r) in enumerate(((0.55, 1.15), (1.15, 1.05), (1.72, 0.95))):
        ball(r, (0, 0.08 * index, z), a if index % 2 else c, scale=(1, 0.95, 0.42), segments=12)
    cube(2.0, 1.8, 1.5, 1.85, c, bevel=0.7)
    front = -0.9
    for index in range(4):  # a ridge of spines down its back, seen over its head
        cone(0.26, 0.6, (0, 0.2 + index * 0.25, 3.25 - index * 0.5), (0, 0.5, 1), a, sides=5)
    for side in (-1, 1):  # mandibles
        cone(0.2, 0.55, (side * 0.62, front - 0.02, 2.05), (-side * 0.5, -0.5, -1), "FFF3D6", sides=6)
        rocks(shade(a, -0.15), ((side * 1.5, -0.6, 0.2, 0.26),))
    eyes(front, 2.75, 0.48, "FF9A3C", size=0.9)
    mouth(front, 2.15, 0.5, "o")


def red_scorpion(c, a):
    front = crawler(c, a, w=2.3, d=2.0, h=1.15, lift=0.3, legs=3)
    # Big pincers out in front, open wide.
    for side in (-1, 1):
        box((0.42, 0.9, 0.42), (side * 1.25, -0.9, 0.8), a, bevel=0.16, segments=1, rotation=(0, 0, side * math.radians(-28)))
        ball(0.56, (side * 1.6, -1.55, 0.9), c, scale=(0.9, 1.0, 0.8), segments=10)
        cone(0.3, 0.9, (side * 1.42, -1.85, 0.98), (-side * 0.25, -1, 0.1), c)
        cone(0.24, 0.8, (side * 1.86, -1.85, 0.82), (side * 0.2, -1, -0.05), c)
    # The tail: up over its back, the sting hanging over its head.
    tail([(0, 0.95, 1.35), (0, 1.25, 1.95), (0, 1.25, 2.6), (0, 0.9, 3.15), (0, 0.35, 3.4)], a, start=0.4, end=0.32)
    ball(0.42, (0, -0.2, 3.3), c, segments=8)
    cone(0.26, 0.75, (0, -0.4, 3.2), (0, -0.7, -0.75), "FFD93A", sides=6, emission=1.5)
    eyes(front, 1.08, 0.5, "FFD93A", size=0.82, brow=a, tilt=-18)
    mouth(front, 0.55, 0.36, "fangs")


def dust_devil(c, a):
    # A little whirlwind: wide at the top, a point at the bottom, each band pushed off-centre.
    layers = ((0.0, 0.12, 0.42), (0.42, 0.4, 0.5), (0.92, 0.66, 0.5), (1.42, 0.95, 0.5))
    for index, (z, bottom, depth) in enumerate(layers):
        shift = 0.14 * math.sin(index * 1.9)
        tube(bottom, depth, (shift, 0, z), UP, a if index % 2 else c, tip=bottom + 0.34, vertices=12)
    cube(2.55, 2.3, 1.25, 1.85, c, bevel=0.6)
    front = -1.15
    hoop(1.5, 0.11, (0, 0, 1.75), a, rotation=(0.22, 0.1, 0), segments=12)  # a ring of blown sand
    rocks(shade(a, -0.2), ((1.55, -0.5, 1.2, 0.24), (-1.5, 0.3, 2.3, 0.2), (-1.2, -0.7, 0.7, 0.18)))
    # A devil, after all: two red horns and a pointed tail.
    horns("E8483A", 0.8, 2.95, size=0.95, lean=24)
    tail([(0.5, 0.5, 0.3), (0.95, 0.5, 0.2), (1.35, 0.5, 0.4)], "E8483A", start=0.12, end=0.1)
    cone(0.22, 0.42, (1.4, 0.5, 0.45), (0.6, 0, 1), "E8483A", sides=4)
    eyes(front, 2.5, 0.6, "FF7A3C", size=0.92, brow=a, tilt=-16)
    mouth(front, 2.02, 0.5)


def rover_bot(c, a):
    # A six-wheeled rover: a flat deck, a head on a mast, solar panels for wings, a dish.
    wheels("3F4680", a, 0.95, r=0.52, width=0.42, ys=(-0.85, 0.05, 0.95))
    cube(2.1, 2.6, 0.7, 0.5, c, bevel=0.22, seg=2)
    tube(0.2, 0.75, (0, -0.55, 1.15), UP, "3F4680", vertices=8)
    cube(2.0, 1.2, 1.25, 1.75, c, bevel=0.3, seg=2, y=-0.6)
    front = -1.2
    for side in (-1, 1):  # panels: blue glass in a yellow frame
        box((1.5, 1.2, 0.12), (side * 1.5, 0.75, 1.5), a, bevel=0.04, segments=1, rotation=(0, side * math.radians(-18), 0))
        box((1.3, 1.0, 0.14), (side * 1.5, 0.75, 1.52), "3F7BFF", bevel=0.04, segments=1, rotation=(0, side * math.radians(-18), 0))
    tube(0.06, 0.9, (0.65, -0.4, 2.95), (0.15, 0, 1), "3F4680", vertices=6)  # aerial
    ball(0.17, (0.79, -0.4, 3.85), "FF5A5A", segments=6, emission=2)
    lathe([(0, 0.0), (0.5, 0.3), (0.42, 0.34), (0, 0.1)], a, segments=10, location=(-0.6, -0.3, 3.3), rotation=(-0.5, -0.3, 0))  # dish
    tube(0.06, 0.4, (-0.6, -0.4, 2.95), UP, "3F4680", vertices=6)
    eyes(front, 2.4, 0.5, "5AE0FF", size=0.88, blush=False)
    slab((0.9, 0.1, 0.16), (0, front - 0.03, 1.95), "3F4680")  # a speaker grille for a mouth
    for index in range(3):
        slab((0.1, 0.12, 0.16), ((index - 1) * 0.3, front - 0.05, 1.95), a)


def martian_warlord(c, a):
    front = biped(c, shade(c, -0.3), w=3.0, d=2.5, h=2.6, legs=0.5, arm=False, bevel=0.7, foot=(1.05, 1.3, 0.6))
    # Red armour: breastplate, shoulder plates with a spike, gauntlets.
    box((2.5, 0.4, 1.0), (0, front + 0.02, 1.15), a, bevel=0.2, segments=2)
    star(0.3, (0, front - 0.2, 1.2), GOLD, depth=0.1)
    for side in (-1, 1):
        ball(0.8, (side * 1.7, 0, 2.5), a, scale=(1, 1, 0.75), segments=10)
        cone(0.26, 0.7, (side * 1.9, 0, 2.9), (side * 0.6, 0, 1), GOLD, sides=6)
        box((0.6, 0.75, 1.1), (side * 1.82, -0.1, 1.55), shade(c, -0.3), bevel=0.25, segments=2)
        ball(0.5, (side * 1.92, -0.15, 0.9), a, segments=8)
    # The helmet of the god of war: a red cap with gold trim and a tall crest from front to back.
    helmet(a, 2.95, 1.45, trim=GOLD, squash=0.55)
    crest = [(-1.25, 0.0), (-1.45, 0.75), (-0.9, 1.45), (0, 1.75), (0.9, 1.45), (1.45, 0.75), (1.25, 0.0)]
    plate([(x * 0.8, z) for x, z in crest], "FFD93A", (0, 0, 3.6), thick=0.34, rotation=(0, 0, math.pi / 2))
    box((0.4, 2.1, 0.3), (0, 0, 3.7), GOLD, bevel=0.1, segments=1)
    antennae(shade(c, -0.3), "FF5AF0", 1.2, 3.35, height=0.9, lean=38, bulb=0.26)
    eyes(front, 2.2, 0.68, "FF5AF0", size=1.1, brow=a, tilt=-26)
    mouth(front, 1.78, 0.7, "fangs")
    # A war banner in its fist.
    tube(0.1, 3.6, (2.25, -0.4, 0.4), UP, GOLD, vertices=6)
    plate([(0, 0), (1.1, -0.1), (0.75, -0.5), (1.1, -0.9), (0, -1.0)], a, (2.3, -0.4, 4.0), thick=0.1)


def olympus_guardian(c, a):
    # A walking volcano: Olympus Mons on legs, in gold armour, behind a gold shield.
    front = biped(c, shade(c, -0.3), w=3.0, d=2.5, h=2.2, legs=0.5, arm=False, bevel=0.6, foot=(1.05, 1.3, 0.6))
    crater((0, 0, 2.5), 1.75, 1.75, shade(c, -0.12), "FFB01F", rim=0.5, sides=12, glow=3)
    for x, y, d in ((-0.5, -0.82, 0.9), (0.45, -0.8, 0.6), (0.95, -0.35, 1.1), (-1.0, 0.1, 0.7)):  # lava running down
        tube(0.14, d, (x, y * 0.72, 4.22), (x * 0.85, y * 0.9, -1.75), "FF8A1F", vertices=6, emission=0.5)
    tuft("FFD9A0", ((0, 0, 4.6, 0.36), (0.3, 0.1, 5.05, 0.28), (-0.1, 0, 5.4, 0.2)), emission=0.6)  # a puff of smoke
    for side in (-1, 1):
        ball(0.75, (side * 1.7, 0, 2.3), a, scale=(1, 1, 0.75), segments=10, roughness=0.3)
        box((0.6, 0.75, 1.0), (side * 1.82, -0.1, 1.5), shade(c, -0.3), bevel=0.25, segments=2)
        ball(0.48, (side * 1.92, -0.15, 0.9), a, segments=8, roughness=0.3)
    box((3.1, 2.6, 0.34), (0, 0, 0.85), a, bevel=0.12, segments=1, roughness=0.3)
    eyes(front, 1.9, 0.68, "FFB01F", size=1.1, brow=a, tilt=-22)
    mouth(front, 1.2, 0.8, "grin")
    # The shield, on its left arm.
    tube(1.05, 0.2, (-2.0, -1.1, 1.5), (0, -1, 0), a, vertices=10, roughness=0.3)
    tube(0.78, 0.1, (-2.0, -1.3, 1.5), (0, -1, 0), "E0432E", vertices=10)
    star(0.48, (-2.0, -1.46, 1.5), a, depth=0.14)


# ---------------------------------------------------------------------------------------------------
# Neptune
# ---------------------------------------------------------------------------------------------------
def frost_imp(c, a):
    front = biped(c, a, w=1.9, d=1.7, h=1.7, legs=0.38, arm=True, belly=shade(c, 0.5), foot=(0.65, 0.85, 0.4))
    ears(c, "DFF4FF", 0.92, 1.55, size=1.0, lean=62)
    # Horns of ice and a frozen quiff.
    crystal((-0.5, 0, 2.0), 0.24, 0.95, "DFF8FF", lean=(-24, 0), emission=0.6)
    crystal((0.5, 0, 2.0), 0.24, 0.95, "DFF8FF", lean=(24, 0), emission=0.6)
    crystal((0, -0.1, 2.02), 0.2, 0.55, "FFFFFF", lean=(0, -10))
    # A scarf, its ends flying.
    box((2.05, 1.85, 0.34), (0, 0, 0.62), "FF5A7A", bevel=0.14, segments=1)
    box((0.42, 0.2, 0.75), (0.62, front - 0.08, 0.3), "FF5A7A", bevel=0.08, segments=1, rotation=(0, math.radians(-14), 0))
    tail([(0, 0.9, 0.6), (0.2, 1.25, 0.8), (0.3, 1.5, 1.15)], a, start=0.14, end=0.1)
    crystal((0.3, 1.5, 1.15), 0.18, 0.5, "DFF8FF", lean=(10, 30), sides=4)
    eyes(front, 1.45, 0.46, "3FE0FF", size=0.88)
    mouth(front, 0.92, 0.34, "fangs")


def snow_blob(c, a):
    # A snowman that never got finished: a lumpy heap with a carrot nose, twig arms and a bobble hat.
    front = blob(c, w=2.4, d=2.1, h=1.7, puddle=a, bevel=0.8, roughness=0.8)
    tuft(c, ((-0.95, -0.5, 0.35, 0.5), (1.0, -0.4, 0.32, 0.46), (0.75, 0.2, 1.7, 0.5), (-0.7, 0.3, 1.72, 0.44)), roughness=0.8)
    cone(0.2, 0.8, (0, front + 0.05, 0.8), (0, -1, -0.05), "FF8A1F", sides=6)
    for side in (-1, 1):
        tube(0.07, 1.0, (side * 1.1, 0, 1.0), (side, -0.1, 0.5), "8A5A2B", vertices=5)
        tube(0.05, 0.4, (side * 1.75, -0.06, 1.3), (side * 0.2, 0, 1), "8A5A2B", vertices=5)
    helmet("3FA9F5", 1.72, 0.85, trim="FFFFFF", squash=0.9)
    ball(0.28, (0, 0, 2.6), "FFFFFF", segments=8)
    eyes(front, 1.1, 0.5, "3FA9F5", size=0.9)
    for index in range(5):  # a mouth of coal
        offset = index - 2
        ball(0.07, (offset * 0.14, front - 0.04, 0.5 + abs(offset) * 0.04), INK, segments=6)


def ice_wraith(c, a):
    # A hooded spirit that ends in an icicle. Its sleeves and its shards float beside it.
    tube(0.08, 0.9, (0, 0.05, 0.0), UP, a, tip=0.8, vertices=6, smooth=False)  # the icicle it tapers into
    ball(1.1, (0, 0, 1.65), c, scale=(1, 0.95, 0.95), segments=12, roughness=0.2, emission=0.2)
    front = -1.02
    # The hood: a dark cowl round the face with a point that flops back.
    hoop(1.02, 0.28, (0, front + 0.32, 1.65), a, rotation=(math.pi / 2, 0, 0), segments=12)
    cone(0.85, 0.95, (0, 0.2, 2.25), (0, 0.5, 1), a, sides=8)
    for side in (-1, 1):
        cone(0.42, 1.0, (side * 0.9, -0.3, 1.25), (side * 1, -0.2, -0.45), a, sides=5, smooth=False)  # sleeves
        crystal((side * 1.75, -0.3, 1.5), 0.26, 0.85, "DFF8FF", lean=(side * 14, 0), emission=0.6)
        crystal((side * 1.45, 0.3, 2.2), 0.18, 0.6, "DFF8FF", lean=(side * 10, 0), emission=0.6)
    eyes(front, 1.72, 0.44, "FFFFFF", size=0.86, blush=False)
    mouth(front, 1.14, 0.28, "o")


def glacier_crab(c, a):
    front = crawler(c, shade(c, -0.3), w=2.6, d=1.9, h=1.2, lift=0.3, legs=3)
    # An iceberg on its back.
    for x, y, r, h, lean in ((0.1, 0.25, 0.62, 2.0, (4, 0)), (-0.75, 0.15, 0.45, 1.35, (-16, 0)), (0.85, 0.3, 0.4, 1.15, (18, 0)), (-0.2, -0.3, 0.3, 0.8, (-6, -14))):
        crystal((x, y, 1.35), r, h, a, lean=lean, sides=5, emission=0.4)
    tuft("FFFFFF", ((-0.9, -0.3, 1.5, 0.3), (0.75, -0.25, 1.5, 0.26)))  # snow
    # A fiddler crab: one huge claw, one small.
    claws(a, shade(c, -0.3), 1.6, -0.7, 0.95, size=1.5, sides=(1,))
    claws(a, shade(c, -0.3), 1.5, -0.7, 0.8, size=0.7, sides=(-1,))
    for side in (-1, 1):
        box((0.22, 0.22, 0.55), (side * 0.48, front + 0.12, 1.7), shade(c, -0.3), bevel=0.1, segments=1)
    eyes(front + 0.1, 2.1, 0.48, "DFF8FF", size=0.72)
    mouth(front, 0.8, 0.4)


def yeti(c, a):
    front = biped(c, a, w=2.3, d=2.0, h=2.5, legs=0.45, arm=False, bevel=0.6, foot=(0.95, 1.15, 0.5), roughness=0.8)
    # Shaggy: tufts of fur on its head, shoulders and elbows, long arms that reach its knees.
    arms(c, 1.45, 1.45, size=(0.62, 0.75, 1.6), tilt=-12, fist=a, fist_size=0.48)
    tuft(c, ((0, 0, 3.05, 0.5), (-0.5, 0, 2.95, 0.4), (0.5, 0, 2.95, 0.4), (-1.3, 0, 2.3, 0.46), (1.3, 0, 2.3, 0.46), (-1.15, -0.2, 2.75, 0.3), (1.15, -0.2, 2.75, 0.3)), roughness=0.8)
    # A blue face and a blue tummy, little horns.
    disc(0.95, (0, front + 0.02, 2.0), a, height=0.07, stretch=0.82, sides=12)
    disc(0.6, (0, front + 0.02, 0.95), a, height=0.07, stretch=0.8, sides=10)
    horns("5A8FE0", 0.82, 2.85, size=0.7, lean=36)
    eyes(front - 0.05, 2.1, 0.46, "3FA9F5", size=0.82, blush=False)
    mouth(front - 0.05, 1.52, 0.6, "tusks")


def blizzard_wraith(c, a):
    # A storm with a face: a great round ghost in a cloak, crowned with ice, snow whirling round it.
    hem = lambda angle: 0.2 * math.cos(math.radians(angle * 6))
    lathe([(0, 3.1), (0.9, 2.9), (1.45, 2.3), (1.5, 1.4), (lambda angle: 1.15, 0.6), (lambda angle: 0.7, lambda angle: 0.15 + hem(angle)), (0, 0.5)], c, segments=24, roughness=0.3, emission=0.2)
    front = -1.45
    # The cloak over its shoulders, with a gold clasp.
    lathe([(0, 1.5), (1.62, 1.5), (1.75, 1.2), (lambda angle: 1.7, lambda angle: 0.75 + 0.5 * hem(angle)), (0, 1.0)], a, segments=24)
    ball(0.24, (0, front - 0.2, 1.3), GOLD, segments=8)
    # Its crown: tall shards of ice.
    for index in range(7):
        x, y = ring(index * 360 / 7 + 180, 0.85)
        crystal((x, y, 2.85), 0.3, 1.25 if index % 2 == 0 else 0.85, "E8FBFF", lean=(x * 14, y * 14), emission=1)
    tube(0.95, 0.3, (0, 0, 2.8), UP, a, vertices=12)
    # The blizzard: two tilted rings of snowballs.
    for tilt, radius, z, count in ((0.3, 2.3, 1.55, 9), (-0.35, 2.0, 0.8, 7)):
        for index in range(count):
            angle = index * 2 * math.pi / count + tilt
            point = Vector((math.cos(angle) * radius, math.sin(angle) * radius, 0))
            point.rotate(Matrix.Rotation(tilt, 3, "Y"))
            ball(0.24 if index % 2 else 0.16, (point.x, point.y, point.z + z), "FFFFFF", segments=6, emission=0.5)
    for side in (-1, 1):  # sleeves reaching out
        cone(0.5, 1.2, (side * 1.4, -0.3, 1.9), (side * 1, -0.3, -0.25), c, sides=6)
        ball(0.3, (side * 2.55, -0.65, 1.6), "FFFFFF", segments=8)
    eyes(front, 2.15, 0.62, a, size=1.1, brow=a, tilt=-24)
    mouth(front - 0.02, 1.72, 0.5, "o")


def frost_giant(c, a):
    front = biped(c, shade(c, -0.35), w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.6, foot=(1.1, 1.3, 0.6))
    arms(shade(c, -0.35), 1.85, 1.75, size=(0.7, 0.85, 1.3), tilt=-14, fist=c, fist_size=0.55)
    # Its signature: a great white beard, with a moustache over it.
    for x, z, r in ((0, 1.25, 0.8), (-0.75, 1.5, 0.62), (0.75, 1.5, 0.62), (-0.4, 0.75, 0.55), (0.4, 0.75, 0.55), (0, 0.35, 0.42), (-1.2, 1.85, 0.42), (1.2, 1.85, 0.42)):
        ball(r, (x, front - 0.1, z), a, scale=(1, 0.6, 1), segments=8, roughness=0.8)
    for side in (-1, 1):
        ball(0.36, (side * 0.4, front - 0.42, 1.78), "FFFFFF", scale=(1.5, 0.6, 0.7), segments=8, rotation=(0, side * 0.3, 0))
    # A horned helmet of dark blue iron with a gold rim.
    helmet("3A5FD0", 3.1, 1.6, trim=GOLD, squash=0.55)
    for side in (-1, 1):
        cone(0.42, 1.0, (side * 1.4, 0, 3.3), (side * 1, 0, 0.45), "FFF3D6")
        cone(0.3, 0.9, (side * 2.2, 0, 3.6), (side * 0.2, 0, 1), "FFF3D6", sides=6)
    eyes(front, 2.45, 0.68, "DFF8FF", size=1.05, brow="FFFFFF", tilt=-20)
    # A club of ice in its fist.
    tube(0.16, 1.2, (2.25, -0.5, 0.75), (0.3, -0.1, 1), "8A5A2B", vertices=6)
    crystal((2.58, -0.61, 1.85), 0.55, 1.7, "DFF8FF", lean=(16, -4), sides=6, emission=0.8)


# ---------------------------------------------------------------------------------------------------
# The Sun
# ---------------------------------------------------------------------------------------------------
def magma_blob(c, a):
    # Molten: a glowing heap with a cooled black crust on top that has cracked, in a pool of lava.
    front = blob(c, w=2.3, d=2.1, h=1.7, puddle="FFD23A", bevel=0.75, emission=0.3)
    crust = "5A2A30"
    for x, y, z, sx, sy in ((-0.5, 0.2, 1.72, 0.7, 0.62), (0.55, 0.3, 1.7, 0.6, 0.6), (0.1, -0.5, 1.72, 0.52, 0.4), (-1.08, 0.1, 1.1, 0.3, 0.55), (1.1, 0.2, 1.0, 0.3, 0.5)):
        chunk((sx, sy, 0.3), (x, y, z), crust, detail=1)
    for x, z, r in ((-1.3, 0.3, 0.3), (1.25, 0.45, 0.22), (1.5, 0.15, 0.16)):  # bubbles in the pool
        ball(r, (x, -0.5, z), "FFD23A", segments=8, emission=2)
    fire((0.05, 0.1, 1.8), 0.75, "FF4A1E", "FFD23A")
    eyes(front, 1.05, 0.5, "FFE45A", size=0.9)
    mouth(front, 0.5, 0.42)


def fire_imp(c, a):
    # A little devil: horns, a head of flame, bat wings, an arrow tail and a trident.
    front = biped(c, shade(c, -0.3), w=1.8, d=1.6, h=1.9, legs=0.4, arm=False, foot=(0.6, 0.85, 0.4))
    for side in (-1, 1):
        box((0.45, 0.55, 0.9), (side * 1.1, -0.15, 1.2), shade(c, -0.3), bevel=0.18, segments=1, rotation=(0, side * math.radians(-14), 0))
    for side in (-1, 1):  # horns that curve in
        cone(0.3, 0.7, (side * 0.72, 0, 2.2), (side * 0.7, 0, 1), a)
        cone(0.2, 0.6, (side * 1.08, 0, 2.68), (-side * 0.35, 0, 1), a, sides=6)
    fire((0, 0.05, 2.2), 0.8, "FF7A1E", "FFE45A")
    wings(shade(c, -0.3), 0.6, 1.2, size=0.85, y=0.75, sweep=20)
    tail([(0.35, 1.15, 0.5), (0.8, 1.2, 0.7), (1.15, 1.1, 1.1)], shade(c, -0.3), start=0.13, end=0.1)
    cone(0.26, 0.5, (1.18, 1.08, 1.15), (0.5, -0.1, 1), a, sides=4)
    # The trident, in its left hand.
    tube(0.07, 2.6, (-1.3, -0.4, 0.15), UP, "8A5A2B", vertices=6)
    slab((0.8, 0.12, 0.12), (-1.3, -0.4, 2.7), a)
    for dx in (-0.36, 0, 0.36):
        cone(0.12, 0.6, (-1.3 + dx, -0.4, 2.7), UP, a, sides=5)
    eyes(front, 1.6, 0.44, "FFE45A", size=0.84, brow=shade(c, -0.4), tilt=-24)
    mouth(front, 1.0, 0.5, "grin")


def lava_crab(c, a):
    front = crawler(c, shade(c, -0.3), w=2.9, d=2.0, h=1.15, lift=0.3, legs=3)
    # A volcano for a shell, lava spilling over its rim, spikes round it.
    crater((0, 0.15, 1.3), 1.25, 1.35, shade(c, -0.25), "FFD23A", rim=0.5, glow=3)
    for x, y, d in ((-0.3, -0.6, 0.6), (0.45, -0.45, 0.9)):
        tube(0.1, d, (x, y + 0.15, 2.6), (x, y, -1.5), a, vertices=5, emission=0.5)
    flame((0, 0.15, 2.5), 0.4, 1.0, "FF4A1E", sides=6, emission=0.3)
    for side in (-1, 1):
        cone(0.26, 0.6, (side * 1.15, 0.3, 1.4), (side * 0.5, 0, 1), a, sides=5, emission=1)
        box((0.22, 0.22, 0.55), (side * 0.5, front + 0.12, 1.65), shade(c, -0.3), bevel=0.1, segments=1)
    claws(a, shade(c, -0.3), 1.7, -0.7, 0.85, size=1.15)
    eyes(front + 0.1, 2.02, 0.5, "FFD23A", size=0.72, brow=shade(c, -0.3), tilt=-16)
    mouth(front, 0.78, 0.4, "fangs")


def flare_spirit(c, a):
    # A little sun: a round face in a ring of flames, a wisp of fire under it.
    for z, r in ((0.0, 0.14), (0.3, 0.26), (0.62, 0.38)):
        ball(r, (0.12 * math.sin(z * 6), 0.1, z + 0.1), a, segments=8, emission=1.5)
    ball(1.0, (0, 0, 1.8), c, scale=(1, 0.8, 1), segments=14, roughness=0.3, emission=0.8)
    front = -0.75
    rays((0, 0, 1.8), 0.9, a, count=10, size=1.25, y=0.1, sides=6, emission=1.5)
    rays((0, 0, 1.8), 0.9, "FF5A28", count=10, size=0.8, y=0.3, start=18, sides=5, emission=1.5)
    for side in (-1, 1):
        flame((side * 1.5, -0.5, 0.75), 0.2, 0.5, a, sides=6, emission=1.5)  # sparks that follow it
    eyes(front, 1.9, 0.38, "FF7A1E", size=0.76)
    mouth(front, 1.4, 0.32)


def cinder_golem(c, a):
    # A squat furnace of coal: wide, open at the top, fire roaring out, glowing cracks, fists like braziers.
    front = biped(c, shade(c, -0.25), w=2.7, d=2.0, h=1.8, legs=0.4, arm=False, bevel=0.35, foot=(1.0, 1.15, 0.5))
    box((2.2, 1.6, 0.3), (0, 0, 2.2), a, bevel=0.1, segments=1, emission=2)  # the fire bed
    for x, y in ((-1.1, -0.7), (1.1, -0.7), (-1.1, 0.7), (1.1, 0.7), (-0.45, -0.85), (0.5, -0.85)):  # the rim of coals
        chunk((0.42, 0.36, 0.42), (x, y, 2.3), shade(c, -0.25), detail=1)
    fire((0, 0.1, 2.3), 1.3, a, "FFD23A")
    for side in (-1, 1):
        box((0.55, 0.7, 0.85), (side * 1.62, -0.1, 1.35), shade(c, -0.25), bevel=0.2, segments=1)
        chunk((0.62, 0.62, 0.58), (side * 1.72, -0.15, 0.7), c, detail=1)
        disc(0.26, (side * 1.72, -0.66, 0.7), a, height=0.1, sides=6, emission=2)
    # Cracks: glowing zigzags down its front.
    crack = [(-0.1, 0), (0.12, -0.3), (-0.04, -0.34), (0.16, -0.75), (-0.2, -0.36), (-0.02, -0.32)]
    plate(crack, a, (-0.95, front - 0.02, 0.95), thick=0.1, emission=2)
    plate([(-x, z) for x, z in crack], a, (1.0, front - 0.02, 1.15), thick=0.1, emission=2)
    eyes(front, 1.5, 0.55, a, size=0.95, brow=shade(c, 0.25), tilt=-18)
    slab((0.9, 0.14, 0.28), (0, front - 0.05, 0.72), a, emission=2)  # a furnace grate of a mouth
    for index in range(3):
        slab((0.1, 0.18, 0.3), ((index - 1) * 0.26, front - 0.06, 0.72), shade(c, -0.25))


def inferno_hound(c, a):
    # A dog on four legs: a long body, a big head with ears and a snout, a mane and tail of fire, a spiked collar.
    dark = shade(c, -0.3)
    box((2.2, 3.0, 1.7), (0, 0.6, 1.75), c, bevel=0.6, segments=2)
    for side in (-1, 1):
        for y in (-0.5, 1.7):
            box((0.75, 0.85, 1.2), (side * 0.85, y, 0.6), dark, bevel=0.25, segments=2)
            box((0.82, 0.92, 0.24), (side * 0.85, y, 0.42), GOLD, bevel=0.08, segments=1, roughness=0.3)  # gold cuffs
    box((3.0, 2.2, 2.4), (0, -1.5, 2.6), c, bevel=0.7, segments=3)  # the head
    front = -2.6
    # The collar: gold, with spikes.
    tube(1.45, 0.4, (0, -0.25, 2.0), (0, 1, 0), GOLD, vertices=12, roughness=0.3)
    for index in range(8):
        angle = index * math.pi / 4
        cone(0.2, 0.5, (math.sin(angle) * 1.45, -0.05, 2.0 + math.cos(angle) * 1.45), (math.sin(angle), 0, math.cos(angle)), "FFF3D6", sides=5)
    # Snout, nose, tongue, ears.
    box((1.4, 0.8, 0.95), (0, front - 0.25, 1.95), shade(c, 0.25), bevel=0.3, segments=2)
    ball(0.26, (0, front - 0.68, 2.3), INK, scale=(1.3, 0.8, 0.8), segments=8)
    slab((0.9, 0.1, 0.12), (0, front - 0.66, 1.78), INK)
    box((0.36, 0.14, 0.42), (0.1, front - 0.68, 1.58), "FF6F9A", bevel=0.06, segments=1)
    for side in (-1, 1):
        cone(0.14, 0.34, (side * 0.4, front - 0.66, 1.78), (0, 0, -1), WHITE, sides=6)
        plate([(-0.5, 0), (0.1, 1.3), (0.55, 0)], c, (side * 1.0, -1.5, 3.65), thick=0.5, rotation=(0, side * math.radians(16), 0))
        plate([(-0.26, 0.05), (0.08, 0.85), (0.32, 0.05)], a, (side * 1.0, -1.78, 3.68), thick=0.1, rotation=(0, side * math.radians(16), 0))
    # Fire: a mane between the ears and down its back, a tail of flame.
    fire((0, -1.3, 3.7), 1.25, "FF6A1E", "FFE45A")
    for y, size in ((0.3, 0.95), (1.3, 0.75)):
        flame((0, y, 2.5), 0.5 * size, 1.4 * size, "FF6A1E", emission=0.3)
    tail([(0, 2.2, 2.2), (0, 2.6, 2.7), (0, 2.75, 3.3)], dark, start=0.26, end=0.2)
    fire((0, 2.75, 3.3), 1.2, "FF6A1E", "FFE45A")
    eyes(front, 3.0, 0.72, a, size=1.15, brow=dark, tilt=-26)


def solar_titan(c, a):
    front = biped(c, a, w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.6, foot=(1.1, 1.3, 0.6), roughness=0.35)
    # Its signature: the sun itself stands behind its head, a great disc with long rays.
    tube(2.0, 0.3, (0, 1.0, 3.2), (0, 1, 0), "FFE45A", vertices=16, emission=1.5)
    rays((0, 1.15, 3.2), 1.9, "FF8A1F", count=12, size=2.0, sides=5, emission=1.5)
    # Armour of red gold: shoulder plates, gauntlets, a belt with a sun on it.
    for side in (-1, 1):
        ball(0.8, (side * 1.7, 0, 2.8), a, scale=(1, 1, 0.75), segments=10)
        flame((side * 1.8, 0, 3.25), 0.34, 0.9, "FFE45A", sides=6, emission=2)
        box((0.65, 0.8, 1.2), (side * 1.85, -0.1, 1.7), c, bevel=0.25, segments=2, roughness=0.35)
        ball(0.5, (side * 1.95, -0.15, 0.95), a, segments=8)
    box((3.1, 2.6, 0.36), (0, 0, 0.95), a, bevel=0.12, segments=1)
    tube(0.34, 0.14, (0, front - 0.02, 0.95), (0, -1, 0), "FFE45A", vertices=10, emission=2)
    crown(3.3, radius=0.95, colour="FFE45A", gems=a, points=5, size=1.25)
    eyes(front, 2.3, 0.68, "FF5A28", size=1.1, brow=a, tilt=-20)
    mouth(front, 1.6, 0.8, "grin")


# ---------------------------------------------------------------------------------------------------
# Who lives where: (the game's name, design, colour, accent, kind). The colours are Config.Worlds' color and
# accent with their saturation pushed up; a grey there is a lilac or a steel blue here.
# ---------------------------------------------------------------------------------------------------
WORLDS = {
    "Earth": [
        ("Ogre Chief", ogre_chief, "E2A25B", "8E4F2B", "boss"),
        ("Earth Titan", earth_titan, "C2A47C", "58C546", "boss"),
    ],
    "Moon": [
        ("Moon Rockling", moon_rockling, "A9A7E6", "6C69B8", "walker"),
        ("Crater Crawler", crater_crawler, "D4D3F7", "7B79C9", "walker"),
        ("Lunar Bat", lunar_bat, "7B56D8", "45308F", "floater"),
        ("Astro Ghost", astro_ghost, "F2F5FF", "6F92F0", "floater"),
        ("Moon Golem", moon_golem, "8496DE", "5060A8", "walker"),
        ("Dark Side Stalker", dark_side_stalker, "4A4390", "D24DFF", "boss"),
        ("Moon Colossus", moon_colossus, "D3D8F6", "5870E0", "boss"),
    ],
    "Mars": [
        ("Martian Grunt", martian_grunt, "5ED079", "2F8F50", "walker"),
        ("Sand Worm", sand_worm, "F0BC72", "BF7A40", "walker"),
        ("Red Scorpion", red_scorpion, "E8402F", "8F2018", "walker"),
        ("Dust Devil", dust_devil, "F2CB8F", "BE8A52", "floater"),
        ("Rover Bot", rover_bot, "A8BEE6", "FFC83C", "walker"),
        ("Martian Warlord", martian_warlord, "3FB45C", "E0432E", "boss"),
        ("Olympus Guardian", olympus_guardian, "B8472C", "F6CC55", "boss"),
    ],
    "Neptune": [
        ("Frost Imp", frost_imp, "96D2FF", "4A8CE6", "walker"),
        ("Snow Blob", snow_blob, "F5FAFF", "B5D3F2", "walker"),
        ("Ice Wraith", ice_wraith, "6EE6F0", "3A96D0", "floater"),
        ("Glacier Crab", glacier_crab, "4F8CEB", "C8EBFF", "walker"),
        ("Yeti", yeti, "F0F5FA", "86B6E6", "walker"),
        ("Blizzard Wraith", blizzard_wraith, "BEEBFF", "4670E0", "boss floater"),
        ("Frost Giant", frost_giant, "78BEFA", "F0FAFF", "boss"),
    ],
    "The Sun": [
        ("Magma Blob", magma_blob, "FF7A1E", "C83C14", "walker"),
        ("Fire Imp", fire_imp, "EC3C28", "FFC03C", "walker"),
        ("Lava Crab", lava_crab, "A82E22", "FF8420", "walker"),
        ("Flare Spirit", flare_spirit, "FFDC5A", "FF8C28", "floater"),
        ("Cinder Golem", cinder_golem, "4E3B48", "FF6A1E", "walker"),
        ("Inferno Hound", inferno_hound, "8A2E20", "FFA428", "boss"),
        ("Solar Titan", solar_titan, "FFB432", "FF501E", "boss"),
    ],
}


def stage(name, design, colour, accent, kind, x):
    """Builds one creature as its own group, sizes it (a floater: lifts it over its puddle) and stands it at
    x in the photo's row, turned. In the export it stands on the origin, facing -Y."""
    boss, floats = "boss" in kind, "floater" in kind
    group = name.replace(" ", "_")
    with into(group):
        first = len(made)
        design(colour, accent)
        pieces = made[first:]
        corners = [obj.matrix_basis @ vertex.co for obj in pieces for vertex in obj.data.vertices]
        low = Vector([min(co[axis] for co in corners) for axis in range(3)])
        high = Vector([max(co[axis] for co in corners) for axis in range(3)])
        hover = HOVER if floats else 0.0
        size = min(((BOSS_HEIGHT if boss else HEIGHT) - hover) / (high.z - low.z), (BOSS_WIDEST if boss else WIDEST) / (high.x - low.x))
        # Its middle goes over the origin, its lowest point on the ground (or `hover` over it).
        fit = Matrix.Translation((0, 0, hover)) @ Matrix.Scale(size, 4) @ Matrix.Translation((-(low.x + high.x) / 2, -(low.y + high.y) / 2, -low.z))
        if floats:
            reach = min(high.x - low.x, high.y - low.y) * size * 0.36
            lathe([(0, 0.03), (reach * 0.7, 0.03), (reach, 0.0)], shade(accent, -0.1), segments=12)
        frame = Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(POSE, 4, "Z")
        for obj in made[first:]:
            obj.matrix_basis = frame @ (fit if obj in pieces else Matrix.Identity(4)) @ obj.matrix_basis
        kit.shells[group] = frame
    return group


def main():
    given = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not given or given[0] not in WORLDS:
        raise SystemExit(f"creatures.py -- <World> <output folder> [draft]; the worlds: {', '.join(WORLDS)}")
    world, out, draft = given[0], (given[1] if len(given) > 1 else "."), "draft" in given[2:]
    slug = world.lower().replace(" ", "_")
    os.makedirs(out, exist_ok=True)
    kit.init(seed=11, render_only=("Backdrop",))

    cast = WORLDS[world]
    gap = 3.7
    places = [(index - (len(cast) - 1) / 2) * gap for index in range(len(cast))]
    for (name, design, colour, accent, kind), x in zip(cast, places):
        stage(name, design, colour, accent, kind, x)
    triangles = kit.count()

    # The photo: a plain soft floor that fills the frame, a pale sky for the light.
    with into("Backdrop"):
        slab((600, 600, 1), (0, 0, -0.5), BACKDROPS[world], roughness=0.95)
    kit.studio(out, draft=draft, sky=kit.sky_ramp("DCE8FF", "F4F6FF", "F4F6FF"), sun_from=(215, 48), strength=0.95)
    scene = bpy.context.scene
    scene.cycles.samples = 32 if draft else 64
    scene.render.resolution_x, scene.render.resolution_y = 2800, 840
    width = gap * (len(cast) - 1) + 4.4
    distance = max(width / 0.72, 19)  # a 50 mm lens sees 0.72 of its distance across, 0.3 of that up
    photo(f"{slug}_creatures", (-0.06 * distance, -distance, 0.19 * distance), (0, 0, 1.25), 50)

    report = kit.export(f"{out}/{slug}_creatures.fbx", max_tris=2500)
    for entry in report:
        limit = 2500 if any(entry["group"] == name.replace(" ", "_") and "boss" in kind for name, _, _, _, kind in cast) else 1500
        note = "" if 600 <= entry["triangles"] <= limit else f"  <-- outside 600 to {limit}"
        print(f"CREATURE {entry['name']} triangles {entry['triangles']} height {entry['high'].z - entry['low'].z:.2f} width {entry['high'].x - entry['low'].x:.2f} low z {entry['low'].z:.2f}{note}")
    return triangles


main()
