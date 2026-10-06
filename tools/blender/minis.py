"""Mini cannons ("cannon critters") and eggs. Two sets:
  marketplace   the Gem Egg and the four Halloween eggs, with their 25 mini cannons (marketplace_minis.fbx)
  worlds        the two coin eggs of each of the first five worlds, and the 20 mini cannons of Earth's
                and the Moon's two (world_minis.fbx). The mini cannons of worlds 3 to 5 have no model
                yet: the game builds those from parts.

Run: blender --background --python tools/blender/minis.py -- <output folder> [full | eggs | nophotos] [marketplace | worlds]

A mini cannon is a rounded creature with big eyes that is still a cannon: wheels, a barrel on its head, a fuse
for a tail. Each one is a short recipe that picks pieces from the kit below. Every model is joined into one
mesh with its colours stored on the vertices, so in Roblox it is a single part.
Writes one render per egg (row_<egg>.png) and marketplace_minis.fbx with every model, named egg_<id> and
mini_<id> (the ids are the game's: Config.Eggs and Config.Pets).
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
MODE = sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else "full"
SET = sys.argv[sys.argv.index("--") + 3] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 3 else "marketplace"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}

WHITE, INK, BLUSH, GOLD, WOOD, SPARK = "FFFFFF", "1B1140", "FF8FB8", "FFC61A", "8A5A2B", "FFB01F"


def linear(hex_code):
    hex_code = hex_code.lstrip("#")
    return tuple(((int(hex_code[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4))


def shade(hex_code, amount):
    """Darker (amount < 0) or lighter (amount > 0) version of a colour."""
    hex_code = hex_code.lstrip("#")
    target = 255 if amount > 0 else 0
    return "".join("%02X" % round(int(hex_code[i:i + 2], 16) + (target - int(hex_code[i:i + 2], 16)) * abs(amount)) for i in (0, 2, 4))


def mat(hex_code, roughness=0.5, emission=0.0):
    key = (hex_code, roughness, emission)
    if key not in materials:
        m = bpy.data.materials.new(hex_code)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        colour = linear(hex_code)
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
        bsdf.inputs["Roughness"].default_value = roughness
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*colour, 1)
            bsdf.inputs["Emission Strength"].default_value = emission
        m.diffuse_color = (*colour, 1)
        materials[key] = m
    return materials[key]


parts = []  # the model being built
origin = Vector((0, 0, 0))


def finish(obj, colour, flat_caps=False, **look):
    obj.data.materials.append(mat(colour, **look))
    for polygon in obj.data.polygons:
        # The ends of a tube stay flat, or its mouth shades like a cone.
        polygon.use_smooth = not (flat_caps and abs(polygon.normal.z) > 0.99)
    obj.location += origin
    parts.append(obj)
    return obj


def box(size, location, colour, bevel=0.3, rotation=(0, 0, 0), **look):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = min(bevel, min(size) * 0.49)
    modifier.segments = 3
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return finish(obj, colour, **look)


def ball(radius, location, colour, scale=(1, 1, 1), rotation=(0, 0, 0), **look):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=12, ring_count=6, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, colour, **look)


def tube(radius, depth, start, direction, colour, tip=None, vertices=12, **look):
    """A cylinder (or a cone when tip is given) from `start` along `direction`."""
    direction = Vector(direction).normalized()
    location = Vector(start) + direction * depth / 2
    rotation = direction.to_track_quat("Z", "Y").to_euler()
    if tip is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=tip, depth=depth, location=location, rotation=rotation, vertices=vertices)
    return finish(bpy.context.object, colour, flat_caps=True, **look)


# ---------------------------------------------------------------------------------------------------
# The kit
# ---------------------------------------------------------------------------------------------------
FRONT = -0.86  # y of the body's face


def body(colour, shape="cube", lift=0.0):
    if shape == "round":
        ball(1.05, (0, 0, 1.3 + lift), colour, scale=(1, 0.92, 0.9))
    elif shape == "tall":
        box((1.7, 1.6, 2.0), (0, 0, 1.45 + lift), colour, bevel=0.5)
    else:
        box((1.9, 1.7, 1.6), (0, 0, 1.25 + lift), colour, bevel=0.5)


def wheels(colour="5A3A6E", hub=GOLD):
    for side in (-1, 1):
        tube(0.5, 0.3, (side * 0.9, 0.05, 0.5), (side, 0, 0), colour)
        ball(0.17, (side * 1.22, 0.05, 0.5), hub, scale=(0.5, 1, 1))


def barrel(colour, top=2.05, band=GOLD, length=1.45, radius=0.4):
    """The cannon on its head, aimed forward and a little up."""
    direction = Vector((0, -math.cos(math.radians(16)), math.sin(math.radians(16))))
    start = Vector((0, 0.72, top + 0.3))
    tube(radius, length, start, direction, colour)
    tube(radius + 0.08, 0.2, start + direction * (length - 0.16), direction, band)
    tube(radius + 0.06, 0.16, start + direction * 0.12, direction, band)
    tube(radius - 0.12, 0.06, start + direction * (length - 0.02), direction, INK)
    ball(radius, start, colour)
    # A cradle so the barrel sits on the head instead of floating over it.
    box((0.6, 0.8, 0.3), (0, 0.15, top + 0.06), shade(colour, -0.25), bevel=0.1)


def fuse(height=1.3, colour="3A1F55"):
    for index in range(3):
        ball(0.12 - index * 0.012, (0, 0.92 + index * 0.17, height + index * 0.2), colour)
    ball(0.19, (0, 1.48, height + 0.66), SPARK, emission=5)


def eyes(height=1.45, spread=0.46, iris="3FE0FF", size=0.85, front=FRONT):
    for side in (-1, 1):
        x = side * spread
        ball(0.5 * size, (x, front - 0.02, height), WHITE, scale=(1, 0.3, 1.08), roughness=0.2)
        ball(0.42 * size, (x, front - 0.09, height - 0.02), INK, scale=(1, 0.3, 1.1), roughness=0.08)
        ball(0.25 * size, (x, front - 0.17, height - 0.1), iris, scale=(1, 0.25, 1), roughness=0.3, emission=1.2)
        ball(0.14 * size, (x - 0.13 * size, front - 0.23, height + 0.17 * size), WHITE, scale=(1, 0.3, 1), roughness=0.2)
        ball(0.07 * size, (x + 0.16 * size, front - 0.23, height - 0.16 * size), WHITE, scale=(1, 0.3, 1), roughness=0.2)


def blush(height=1.02, spread=0.82, front=FRONT):
    for side in (-1, 1):
        ball(0.18, (side * spread, front + 0.02, height), BLUSH, scale=(1.15, 0.2, 0.6), roughness=0.6)


def smile(height=0.86, width=0.34, front=FRONT):
    box((width, 0.12, 0.12), (0, front - 0.05, height), INK, bevel=0.05)
    for side in (-1, 1):
        box((0.16, 0.12, 0.12), (side * (width / 2 + 0.02), front - 0.05, height + 0.05), INK, bevel=0.05, rotation=(0, side * math.radians(-40), 0))


def fangs(height=0.8, spread=0.2, front=FRONT):
    for side in (-1, 1):
        tube(0.09, 0.26, (side * spread, front - 0.08, height + 0.06), (0, 0, -1), WHITE, tip=0.0, vertices=8)


def brows(colour, height=2.0, spread=0.46, tilt=-22, front=FRONT):
    for side in (-1, 1):
        box((0.56, 0.16, 0.15), (side * spread, front - 0.12, height), colour, bevel=0.06, rotation=(0, side * math.radians(tilt), 0))


def face(iris, height=1.45, mood="happy", brow=None, front=FRONT):
    eyes(height, iris=iris, front=front)
    blush(height - 0.43, front=front)
    smile(height - 0.59, front=front)
    if mood == "fierce":
        brows(brow or INK, height + 0.52, front=front)
        fangs(height - 0.66, front=front)


def ears(colour, kind="cat", inner="FFB3C7", top=2.0):
    for side in (-1, 1):
        if kind == "cat":
            tube(0.36, 0.6, (side * 0.6, 0.1, top - 0.08), (side * 0.25, 0, 1), colour, tip=0.0, vertices=10)
            tube(0.2, 0.36, (side * 0.6, -0.05, top - 0.04), (side * 0.25, 0, 1), inner, tip=0.0, vertices=8)
        elif kind == "bat":
            tube(0.3, 0.95, (side * 0.62, 0.15, top - 0.1), (side * 0.45, 0, 1), colour, tip=0.0, vertices=8)
            tube(0.16, 0.6, (side * 0.62, 0.0, top - 0.06), (side * 0.45, 0, 1), inner, tip=0.0, vertices=8)
        elif kind == "round":
            ball(0.36, (side * 0.78, 0.1, top + 0.05), colour, scale=(1, 0.6, 1))
            ball(0.2, (side * 0.78, -0.08, top + 0.05), inner, scale=(1, 0.5, 1))
        elif kind == "floppy":  # a dog's: they hang down the sides of the head
            ball(0.4, (side * 1.02, -0.05, top - 0.5), colour, scale=(0.45, 0.8, 1.45), rotation=(0, side * math.radians(12), 0))
        elif kind == "bunny":
            ball(0.3, (side * 0.6, 0.15, top + 0.62), colour, scale=(0.8, 0.5, 2.4), rotation=(0, side * math.radians(10), 0))
            ball(0.17, (side * 0.6, 0.02, top + 0.62), inner, scale=(0.8, 0.4, 2.2), rotation=(0, side * math.radians(10), 0))
        elif kind == "leaf":
            ball(0.42, (side * 0.95, 0.1, top + 0.12), colour, scale=(1.3, 0.25, 0.7), rotation=(0, side * math.radians(-35), 0))


def horns(colour="FFF3D6", top=2.0, spread=0.72, size=1.0):
    for side in (-1, 1):
        tube(0.2 * size, 0.6 * size, (side * spread, 0.1, top - 0.08), (side * 0.5, 0, 1), colour, tip=0.0, vertices=10)


def wings(colour, kind="bat", height=1.5):
    for side in (-1, 1):
        if kind == "bat":
            for index, (reach, up) in enumerate(((1.0, 0.75), (1.25, 0.3), (1.05, -0.15))):
                tube(0.2, 0.9 + index * 0.05, (side * 0.85, 0.55, height), (side * reach, 0.25, up), colour, tip=0.03, vertices=6)
            ball(0.42, (side * 1.25, 0.72, height + 0.15), colour, scale=(1.3, 0.2, 0.9))
        elif kind == "crystal":
            for index, (reach, up, length) in enumerate(((0.9, 1.0, 1.25), (1.2, 0.45, 1.05), (1.1, -0.05, 0.8))):
                tube(0.2, length, (side * 0.85, 0.55, height), (side * reach, 0.2, up), colour, tip=0.0, vertices=5, roughness=0.15, emission=0.6)
        elif kind == "stone":
            box((0.25, 0.9, 1.25), (side * 1.12, 0.62, height + 0.25), colour, bevel=0.1, rotation=(0, side * math.radians(-28), side * math.radians(20)))
            for index in range(3):
                tube(0.14, 0.4, (side * (1.2 + index * 0.1), 0.62 + index * 0.02, height - 0.3 + index * 0.02), (side * 0.3, 0, -1), colour, tip=0.0, vertices=6)


def crystals(colour, spots, **look):
    """Shards: (x, y, z, radius, length, lean)."""
    for x, y, z, radius, length, lean in spots:
        tube(radius, length, (x, y, z), (lean, 0, 1), colour, tip=0.0, vertices=5, roughness=0.15, **look)


def crown(top=2.05, colour=GOLD, gems="FF3355", y=0.0, radius=0.5):
    tube(radius, 0.2, (0, y, top - 0.04), (0, 0, 1), colour)
    for index in range(5):
        angle = math.radians(index * 72 - 90)
        x, yy = math.cos(angle) * radius * 0.86, math.sin(angle) * radius * 0.86
        tube(0.15, 0.36, (x, y + yy, top + 0.12), (0, 0, 1), colour, tip=0.0, vertices=8)
        ball(0.08, (math.cos(angle) * radius, y + math.sin(angle) * radius, top + 0.06), gems, emission=0.5)


def halo(top=3.1, colour="FFE97A", radius=0.62):
    bpy.ops.mesh.primitive_torus_add(location=(0, 0.1, top), major_radius=radius, minor_radius=0.07, major_segments=16, minor_segments=6)
    finish(bpy.context.object, colour, emission=3)


def witch_hat(colour="6B2BD9", band=SPARK, top=1.98):
    tube(1.05, 0.12, (0, 0.05, top), (0, 0, 1), colour, vertices=16)
    tube(0.62, 1.3, (0, 0.05, top + 0.1), (0.1, 0.25, 1), colour, tip=0.03)
    tube(0.64, 0.2, (0, 0.05, top + 0.1), (0, 0, 1), band)
    box((0.26, 0.1, 0.2), (0, -0.6, top + 0.2), GOLD, bevel=0.04)


def straw_hat(top=1.98):
    tube(1.15, 0.1, (0, 0.05, top), (0, 0, 1), "E8C46A", vertices=16)
    tube(0.6, 0.6, (0, 0.05, top + 0.08), (0, 0, 1), "E8C46A", tip=0.42)
    tube(0.62, 0.16, (0, 0.05, top + 0.1), (0, 0, 1), "C0392B")


def stem(top=2.0, colour="4E9A3A", leaf=True):
    tube(0.16, 0.42, (0, 0.05, top - 0.03), (0.2, 0, 1), "6B4A2B", tip=0.11, vertices=8)
    if leaf:
        ball(0.3, (0.38, 0.05, top + 0.18), colour, scale=(1.2, 0.7, 0.22), rotation=(0, math.radians(-20), 0))


def hood(colour="23202E", top=2.0):
    """A reaper's hood: a dark shell over the head, open at the front."""
    box((2.1, 1.7, 1.8), (0, 0.22, 1.42), colour, bevel=0.55)
    tube(0.5, 0.75, (0, 0.5, top + 0.12), (0, 0.5, 1), colour, tip=0.0, vertices=10)


def scythe(side=1):
    tube(0.07, 2.5, (side * 1.42, -0.15, 0.25), (0, 0, 1), WOOD, vertices=8)
    tube(0.16, 1.05, (side * 1.42, -0.15, 2.6), (-side, 0, -0.35), "C9D3E0", tip=0.0, vertices=4, roughness=0.2)


def bands(colour, heights, depth=1.76, width=1.96, thickness=0.14):
    for z, tilt in heights:
        box((width, depth, thickness), (0, 0, z), colour, bevel=0.05, rotation=(0, math.radians(tilt), 0))


def stitches(colour=INK, at=(0.55, 1.9)):
    x, z = at
    box((0.5, 0.08, 0.07), (x, FRONT - 0.02, z), colour, bevel=0.02, rotation=(0, math.radians(25), 0))
    for index in range(3):
        box((0.07, 0.08, 0.2), (x - 0.15 + index * 0.15, FRONT - 0.03, z - 0.07 + index * 0.07), colour, bevel=0.02, rotation=(0, math.radians(25), 0))


def spider_legs(colour):
    for side in (-1, 1):
        for index in range(4):
            y = -0.5 + index * 0.38
            knee = Vector((side * 1.55, y, 1.55))
            tube(0.09, 0.95, (side * 0.85, y, 1.0), knee - Vector((side * 0.85, y, 1.0)), colour, vertices=6)
            tube(0.08, 1.5, knee, (side * 0.35, 0, -1), colour, tip=0.02, vertices=6)


def tail_wisps(colour, lift, **look):
    for index, (y, z, radius) in enumerate(((0.25, 0.5, 0.5), (0.5, 0.2, 0.34), (0.7, -0.02, 0.2))):
        ball(radius, (0, y, lift + z), colour, **look)


# ---------------------------------------------------------------------------------------------------
# Mini cannons. Five per egg, common first. Each is a recipe.
# ---------------------------------------------------------------------------------------------------
def standard(colour, iris, mood="happy", shape="cube", barrel_colour=None):
    """What nearly every mini cannon has: body, wheels, barrel, fuse, face."""
    body(colour, shape)
    wheels()
    barrel(barrel_colour or shade(colour, -0.35), top=2.45 if shape == "tall" else 2.05)
    fuse()
    face(iris, mood=mood, brow=shade(colour, -0.5), height=1.6 if shape == "tall" else 1.45)


# -- Gem Egg --
def gem():
    standard("78E6FF", "2FA8FF")
    crystals("C9F9FF", ((-0.62, 0.2, 1.95, 0.2, 0.55, -0.3), (0.62, 0.2, 1.95, 0.2, 0.55, 0.3)))


def ruby():
    standard("E62846", "FFD0D6")
    crystals("FF8FA0", ((-0.66, 0.15, 1.95, 0.24, 0.7, -0.35), (0.66, 0.15, 1.95, 0.24, 0.7, 0.35), (-0.9, 0.3, 1.6, 0.16, 0.45, -1.2), (0.9, 0.3, 1.6, 0.16, 0.45, 1.2)))


def sapphire():
    standard("285AE6", "9FDCFF")
    ears("3F74FF", "cat", inner="9FDCFF")
    crystals("9FDCFF", ((0, -0.5, 1.98, 0.14, 0.4, 0),), emission=0.8)


def emerald():
    standard("28C86E", "C8FFD9", mood="fierce")
    horns("C8FFD9", size=1.15)
    crystals("7CF0A8", ((-1.0, 0.35, 1.2, 0.2, 0.75, -0.9), (1.0, 0.35, 1.2, 0.2, 0.75, 0.9)), emission=0.6)


def prismatic():
    standard("FF96FF", "FFE23A", barrel_colour="9B6BFF")
    wings("9FF3FF", "crystal")
    crown(top=3.02, y=0.1, radius=0.34, gems="3FE0FF")
    halo(top=3.55, colour="FFFFFF", radius=0.5)


# -- Pumpkin Egg --
def pumpkin():
    body("FF821E", "round")
    for x in (-0.55, 0, 0.55):  # the ridges of a pumpkin
        ball(1.0, (x, 0, 1.3), shade("FF821E", -0.12), scale=(0.36, 0.95, 0.92))
    wheels()
    barrel("7A4A1E", top=2.0)
    fuse()
    face("FFE23A", front=-0.93)
    stem(top=2.12)


def bat():
    standard("4A3C5C", "FF5AF0", mood="fierce")
    ears("4A3C5C", "bat", inner="B58CE0")
    wings("372B47", "bat")


def ghost():
    lift = 0.55
    body("F2F5FF", "round", lift=lift)
    tail_wisps("F2F5FF", lift)
    for side in (-1, 1):
        ball(0.26, (side * 1.02, -0.2, 1.3 + lift), "F2F5FF", scale=(1, 0.8, 1.2))
    barrel("AEB8D9", top=2.05 + lift)
    fuse(height=1.3 + lift)
    eyes(1.5 + lift, iris="9FDCFF", front=-0.93)
    blush(1.07 + lift, front=-0.93)
    ball(0.13, (0, -1.0, 0.98 + lift), INK, scale=(1, 0.4, 1.25))
    ball(0.95, (0, 0.1, 0.03), "C9D3F5", scale=(0.9, 0.9, 0.03))


def witch():
    standard("6E3CA0", "9CFF3A")
    witch_hat()
    box((0.16, 0.1, 0.16), (0.3, FRONT - 0.04, 1.2), "9CFF3A", bevel=0.05)  # a wart


def jack_o_lantern():
    body("FFAA28", "round")
    for x in (-0.55, 0, 0.55):
        ball(1.0, (x, 0, 1.3), shade("FFAA28", -0.14), scale=(0.36, 0.95, 0.92))
    wheels(hub="FFE23A")
    barrel("3A2A1A", top=2.0, band="FFE23A")
    fuse()
    stem(top=2.12, leaf=False)
    crown(top=2.2, y=0.55, radius=0.3, colour="3A2A1A", gems="FFE23A")
    # A carved, glowing face instead of the usual eyes.
    for side in (-1, 1):
        tube(0.3, 0.14, (side * 0.42, -0.9, 1.5), (0, -1, 0), "FFE23A", vertices=3, emission=5)
    for index in range(5):
        tube(0.15, 0.12, (-0.5 + index * 0.25, -0.93, 0.95 + (0.05 if index % 2 else -0.03)), (0, -1, 0), "FFE23A", vertices=3, emission=5)


# -- Haunted Egg --
def skeleton():
    standard("EDE8D8", "FFFFFF")
    bands("CFC8B2", ((0.78, 0), (1.0, 0)), thickness=0.08)  # ribs
    for side in (-1, 1):  # crossed bones behind
        tube(0.1, 2.5, (side * 1.1, 0.75, 0.5), (-side * 1.0, 0, 1), "EDE8D8", vertices=6)
        for end in (0, 1):
            ball(0.17, (side * 1.1 * (1 - 2 * end) , 0.75, 0.5 + end * 1.77), "EDE8D8")


def zombie():
    standard("7FA35F", "FFE23A")
    stitches()
    box((0.55, 0.1, 0.45), (-0.6, FRONT - 0.01, 0.7), "5E7F45", bevel=0.08)  # a patch
    ball(0.22, (0.75, 0.1, 2.02), "FF8FB8", scale=(1, 1, 0.6))  # a bit of brain showing
    tube(0.07, 0.5, (-0.3, 0.2, 2.0), (-0.3, 0, 1), "5E7F45", vertices=6)


def vampire():
    standard("96142A", "FF3355", mood="fierce")
    box((2.3, 0.5, 1.3), (0, 0.75, 1.5), "23202E", bevel=0.15)  # cape
    for side in (-1, 1):
        tube(0.45, 0.95, (side * 0.85, 0.5, 1.75), (side * 0.6, 0.2, 1), "23202E", tip=0.0, vertices=8)  # collar points
    ball(0.6, (0, 0.05, 2.02), "23202E", scale=(1.25, 1.1, 0.3))  # slick hair
    tube(0.2, 0.3, (0, -0.72, 2.0), (0, -0.5, -1), "23202E", tip=0.0, vertices=6)  # widow's peak


def reaper():
    body("3B3550", "cube")
    hood()
    wheels(colour="23202E", hub="9CFF3A")
    barrel("16131F", top=2.3, band="9CFF3A")
    fuse()
    eyes(1.45, iris="9CFF3A")
    brows("16131F", 1.97)
    scythe()


def headless_horseman():
    body("2B2438", "cube")
    wheels(colour="16131F", hub="FF6E14")
    fuse()
    box((2.0, 1.8, 0.3), (0, 0, 2.02), "5E1FB0", bevel=0.1)  # collar
    # No head: a flaming jack-o'-lantern floats where the barrel would be, and the barrel is the neck.
    tube(0.34, 0.5, (0, 0, 2.05), (0, 0, 1), "16131F")
    ball(0.72, (0, -0.05, 3.1), "FF6E14", scale=(1, 0.95, 0.9))
    for x in (-0.38, 0.38):
        ball(0.68, (x, -0.05, 3.1), shade("FF6E14", -0.14), scale=(0.36, 0.95, 0.9))
        tube(0.18, 0.1, (x * 0.74, -0.7, 3.2), (0, -1, 0), "FFE23A", vertices=3, emission=6)
    for index, (x, z, r) in enumerate(((0, 3.85, 0.3), (-0.28, 3.72, 0.2), (0.3, 3.75, 0.22), (0.05, 4.2, 0.16))):
        ball(r, (x, 0, z), "FFE23A" if index % 2 else SPARK, scale=(1, 1, 1.5), emission=5)
    eyes(1.3, iris="FF6E14", size=0.7)
    brows("16131F", 1.75)


# -- Crypt Egg --
def tombstone():
    standard("8A9098", "C8FFD9", shape="tall")
    ball(0.85, (0, 0, 2.45), "8A9098", scale=(1, 0.94, 0.5))  # the rounded top of the stone
    for x, z in ((-0.7, 0.55), (0.75, 0.75), (-0.5, 2.5)):
        ball(0.28, (x, -0.72, z), "5FA052", scale=(1.2, 0.5, 0.7))  # moss
    box((0.7, 0.08, 0.1), (0, -0.83, 2.3), "5C6168", bevel=0.03)
    box((0.1, 0.08, 0.42), (0, -0.83, 2.3), "5C6168", bevel=0.03)


def spider():
    body("2D2832", "round")
    spider_legs("2D2832")
    barrel("16131F", top=2.0, band="FF3355")
    fuse()
    eyes(1.42, iris="FF3355", front=-0.93)
    for x, z in ((-0.3, 1.98), (0.3, 1.98), (-0.75, 1.85), (0.75, 1.85)):  # the extra eyes
        ball(0.1, (x, -0.9 + abs(x) * 0.18, z), "FF3355", emission=3)
    fangs(0.82, front=-0.93)
    ball(0.5, (0, 0.6, 1.6), "FF3355", scale=(0.5, 0.5, 0.3))  # hourglass mark


def mummy():
    standard("E1D7B9", "FFE23A")
    bands("F6F0DC", ((0.72, 6), (1.05, -8), (1.95, 5)))
    box((2.0, 1.78, 0.5), (0, 0, 1.5), "F6F0DC", bevel=0.06, rotation=(0, math.radians(-9), 0))  # wraps across one eye
    eyes(1.45, spread=0.46, iris="FFE23A", size=0.6)  # the eye that peeks out, drawn over the wrap
    tube(0.1, 0.9, (0.95, 0.2, 0.9), (0.6, 0.3, -1), "F6F0DC", tip=0.05, vertices=6)  # a loose end


def gargoyle():
    standard("5A6E82", "FFB01F", mood="fierce")
    horns("C9D3E0", size=1.25)
    wings("4A5A6C", "stone")
    ears("5A6E82", "bat", inner="4A5A6C")


def lich():
    lift = 0.5
    body("78FFC8", "tall", lift=lift)
    tail_wisps("C8FFE6", lift, emission=1.5)
    barrel("1F5E4A", top=2.45 + lift, band="C8FFE6")
    fuse(height=1.3 + lift)
    face("FFFFFF", height=1.6 + lift, mood="fierce", brow="1F5E4A")
    crown(top=3.42 + lift, y=0.1, radius=0.36, colour="23202E", gems="78FFC8")
    for side in (-1, 1):  # floating bone hands
        ball(0.26, (side * 1.5, -0.3, 1.3 + lift), "EDE8D8")
    box((2.0, 0.5, 1.9), (0, 0.72, 1.5 + lift), "23202E", bevel=0.2)  # a tattered cloak
    ball(1.05, (0, 0.1, 0.03), "78FFC8", scale=(0.9, 0.9, 0.03), emission=2)


# -- Blood Moon Egg --
def crow():
    standard("2A2A36", "FFE23A")
    tube(0.26, 0.55, (0, FRONT + 0.05, 1.08), (0, -1, -0.15), "FFB01F", tip=0.0, vertices=8)  # beak
    for side in (-1, 1):
        ball(0.5, (side * 1.02, 0.25, 1.25), "1E1E28", scale=(0.35, 1.2, 0.85), rotation=(0, 0, side * math.radians(12)))
    for x in (-0.2, 0.05, 0.3):
        tube(0.1, 0.5, (x, 0.2, 1.98), (x, 0.4, 1), "1E1E28", tip=0.0, vertices=6)  # head feathers


def scarecrow():
    standard("D6A85A", "8A5A2B")
    straw_hat()
    stitches(at=(0, 0.9))
    box((0.5, 0.1, 0.45), (0.62, FRONT - 0.01, 0.72), "C0392B", bevel=0.06)  # a patch
    for side in (-1, 1):
        for index in range(3):
            tube(0.06, 0.6, (side * 0.95, -0.2 + index * 0.2, 1.3), (side, 0, -0.2 + index * 0.2), "F2DC8A", tip=0.02, vertices=5)  # straw


def werewolf():
    standard("7A5E4E", "FFE23A", mood="fierce")
    ears("7A5E4E", "cat", inner="D9B8A0")
    ball(0.42, (0, FRONT - 0.12, 1.0), "D9B8A0", scale=(1.1, 0.7, 0.75))  # muzzle
    ball(0.13, (0, FRONT - 0.42, 1.12), INK)
    for side in (-1, 1):
        for index in range(3):
            tube(0.14, 0.42, (side * 0.92, 0.1, 0.95 + index * 0.3), (side, 0, 0.3), "5E4638", tip=0.0, vertices=6)  # cheek fur
    tube(0.3, 1.0, (0, 0.85, 0.9), (0, 1, 0.6), "5E4638", tip=0.05, vertices=8)  # a bushy tail beside the fuse


def banshee():
    lift = 0.55
    body("BEE6EB", "round", lift=lift)
    tail_wisps("E3F7F9", lift, emission=0.8)
    barrel("5E8A92", top=2.05 + lift, band="E3F7F9")
    fuse(height=1.3 + lift)
    eyes(1.5 + lift, iris="FFFFFF", front=-0.93)
    ball(0.2, (0, -1.0, 0.95 + lift), INK, scale=(1, 0.4, 1.5))  # a wailing mouth
    for side in (-1, 1):  # long hair
        for index in range(3):
            tube(0.2, 1.7 - index * 0.25, (side * (0.95 - index * 0.2), 0.3 + index * 0.25, 2.0 + lift), (side * 0.25, 0.15, -1), "7FC4CC", tip=0.03, vertices=6)
    ball(1.0, (0, 0.1, 0.03), "7FC4CC", scale=(0.9, 0.9, 0.03), emission=1)


def blood_moon():
    body("DC1E28", "round")
    for x, z, r in ((-0.55, 1.75, 0.22), (0.6, 0.9, 0.2), (0.75, 1.7, 0.14), (-0.75, 0.95, 0.15)):
        ball(r, (x, -0.72 + abs(x) * 0.25, z), "A0101C", scale=(1, 0.35, 1))  # craters
    wheels(colour="3A0A12", hub="FFE23A")
    barrel("3A0A12", top=2.0, band="FFE23A")
    fuse()
    face("FFE23A", mood="fierce", brow="3A0A12", front=-0.93)
    horns("3A0A12", top=2.05, size=1.2)
    halo(top=3.2, colour="FF5A5A", radius=0.6)
    wings("7A0F18", "bat", height=1.45)


# ---------------------------------------------------------------------------------------------------
# Earth's mini cannons. The Basic Egg's five are the animals of the design note (cat, dog, bunny, bear, fox)
# in the materials of Earth's five towers; the Forest Egg's are things that grow there. The rarer, the more
# it wears: nothing, a little, a scarf or a hat, wings, a crown and a halo.
# ---------------------------------------------------------------------------------------------------
def snout(colour, nose=INK, height=1.0, front=FRONT):
    ball(0.3, (0, front - 0.05, height), colour, scale=(1.2, 0.5, 0.8))
    ball(0.1, (0, front - 0.2, height + 0.1), nose, scale=(1.2, 0.6, 0.8))


def tail(colour, tip=None, bushy=False):
    """Beside the fuse, so both show from behind."""
    if bushy:
        ball(0.36, (0.55, 1.05, 1.0), colour, scale=(0.8, 1.5, 0.8), rotation=(math.radians(-30), 0, 0))
        ball(0.22, (0.55, 1.5, 1.28), tip or colour, scale=(0.8, 1.2, 0.8), rotation=(math.radians(-30), 0, 0))
    else:
        ball(0.26, (0.55, 0.98, 0.95), tip or colour)


def scarf(colour):
    box((2.0, 1.8, 0.24), (0, 0, 0.72), colour, bevel=0.1)
    box((0.3, 0.14, 0.62), (0.55, FRONT - 0.08, 0.45), colour, bevel=0.05, rotation=(0, math.radians(-12), 0))


def rivets(colour, height=1.9):
    for x in (-0.75, -0.25, 0.25, 0.75):
        ball(0.08, (x, FRONT - 0.02, height), colour, scale=(1, 0.5, 1), roughness=0.2)


# -- Basic Egg --
def wooden():  # a cat made of planks
    standard("855E42", "FFC61A")
    bands("6B4A2B", ((0.72, 0), (1.22, 0)), thickness=0.08)
    ears("855E42", "cat", inner="E8C49A")
    tail("855E42", bushy=False)


def iron():  # a dog, riveted
    standard("787C82", "9FDCFF")
    ears("5A5E66", "floppy")
    snout("A9ADB3", height=0.98)
    rivets("C9CDD3")
    tail("5A5E66")


def steel():  # a bunny in a scarf
    standard("B0BECC", "FF8FB8", shape="round")
    ears("B0BECC", "bunny", inner="FFB3C7", top=2.0)
    scarf("E6463C")
    tail(WHITE)


def gold():  # a bear with wings
    standard("FFC828", "8A5A2B", barrel_colour="C98A12")
    ears("FFC828", "round", inner="FFF1B0")
    snout("FFF1B0", nose="8A5A2B", height=0.98)
    wings("FFF1B0", "crystal", height=1.35)
    tail("E0A81C")


def diamond():  # a fox, crowned
    standard("50DCFF", "FF96FF", mood="fierce", barrel_colour="2FA8FF")
    ears("50DCFF", "cat", inner=WHITE)
    tail("50DCFF", tip=WHITE, bushy=True)
    crystals("C9F9FF", ((-1.0, 0.3, 1.25, 0.18, 0.6, -0.9), (1.0, 0.3, 1.25, 0.18, 0.6, 0.9)), emission=0.8)
    crown(top=3.02, y=0.1, radius=0.34, gems="FF96FF")
    halo(top=3.55, colour="FFFFFF", radius=0.5)


# -- Forest Egg --
def leaf():  # a sprout
    standard("6EBE5A", "FFE23A", shape="round")
    stem(top=2.1, colour="4E9A3A")
    ball(0.3, (-0.38, 0.05, 2.3), "8FDB6E", scale=(1.2, 0.7, 0.22), rotation=(0, math.radians(20), 0))


def vine():  # wrapped in creepers
    standard("3C8C46", "C8FFD9")
    bands("2A6B34", ((0.8, 12), (1.6, -10)), thickness=0.12)
    ears("5FB86A", "leaf")
    for x, z in ((-0.6, 0.85), (0.7, 1.72)):
        ball(0.12, (x, FRONT - 0.04, z), "FF8FB8", scale=(1, 0.5, 1))  # two flowers on the vine


def mushroom():  # a toadstool: the cap is its hat
    body("F2E6D0", "tall")
    wheels()
    ball(1.35, (0, 0.05, 2.5), "D2463C", scale=(1, 1, 0.5))
    for x, y, z, radius in ((-0.7, -0.7, 2.75, 0.2), (0.6, -0.85, 2.68, 0.24), (0.0, -0.2, 3.1, 0.22), (0.85, 0.3, 2.85, 0.18), (-0.8, 0.4, 2.85, 0.2)):
        ball(radius, (x, y, z), WHITE, scale=(1, 1, 0.45))
    barrel("8A2E28", top=2.95)
    fuse()
    face("FF5A4D", height=1.5)


def honey():  # a bee of a bear
    standard("F5BE3C", "6B4A2B", barrel_colour="6B4A2B")
    bands("6B4A2B", ((0.7, 0), (1.25, 0)), thickness=0.2)
    ears("F5BE3C", "round", inner="6B4A2B")
    for side in (-1, 1):  # bee wings
        ball(0.6, (side * 1.3, 0.5, 1.9), "EAF7FF", scale=(1.2, 0.15, 0.7), rotation=(0, side * math.radians(-25), side * math.radians(20)), roughness=0.15)
    for side in (-1, 1):  # feelers
        tube(0.05, 0.5, (side * 0.3, -0.5, 2.0), (side * 0.4, -0.3, 1), INK, vertices=6)
        ball(0.1, (side * 0.47, -0.63, 2.44), INK)


def jade():  # a little jade dragon
    standard("3CC896", "FFE23A", mood="fierce", barrel_colour="1E8A62")
    horns("E6FFF4", size=1.2)
    wings("9BF0CE", "crystal")
    tail("3CC896", tip="E6FFF4", bushy=True)
    crown(top=3.02, y=0.1, radius=0.34, gems="3CC896")
    halo(top=3.55, colour="C8FFE6", radius=0.5)


# ---------------------------------------------------------------------------------------------------
# The Moon's mini cannons. The Moon Egg's five are in the materials of the Moon's towers (an alien, a
# rock, a moon bat, an astronaut, a star); the Comet Egg's are things that fly past it.
# ---------------------------------------------------------------------------------------------------
def antennae(colour, tip, top=2.0, spread=0.55):
    for side in (-1, 1):
        tube(0.05, 0.6, (side * spread, -0.35, top - 0.05), (side * 0.35, -0.1, 1), colour, vertices=6)
        ball(0.13, (side * (spread + 0.2), -0.41, top + 0.52), tip, emission=2)


def pits(colour, places):
    """Craters on a body: (x, y, z, radius), each a dark dish."""
    for x, y, z, radius in places:
        ball(radius, (x, y, z), colour, scale=(1, 1, 0.35) if abs(y) < 0.8 else (1, 0.35, 1), roughness=0.8)


def helmet(top=2.0):
    """An astronaut's: a glass bowl round the eyes would hide them, so it is a visor band and a pack."""
    box((2.02, 1.82, 0.2), (0, 0, top - 0.02), "E6EAF2", bevel=0.08)
    box((2.02, 1.82, 0.2), (0, 0, 0.62), "E6EAF2", bevel=0.08)
    box((1.0, 0.5, 1.0), (0, 1.0, 1.2), "E6EAF2", bevel=0.15)  # the pack on its back
    for x in (-0.25, 0.25):
        tube(0.12, 0.3, (x, 1.0, 0.72), (0, 0, -1), "FF7A2E", tip=0.02, vertices=6, emission=2)


def star_points(colour, height=1.25, **look):
    for side in (-1, 1):
        tube(0.42, 0.75, (side * 0.9, 0.1, height), (side, 0, 0.15), colour, tip=0.0, vertices=5, **look)
    tube(0.36, 0.6, (-0.75, 0.1, 0.55), (-0.8, 0, -0.6), colour, tip=0.0, vertices=5, **look)
    tube(0.36, 0.6, (0.75, 0.1, 0.55), (0.8, 0, -0.6), colour, tip=0.0, vertices=5, **look)


def streak(colour, **look):
    """A tail of light behind it."""
    for index, (z, length, radius) in enumerate(((1.6, 1.3, 0.26), (1.2, 1.0, 0.2), (0.85, 0.75, 0.16))):
        tube(radius, length, (0.35 - index * 0.35, 0.8, z), (0, 1, 0.25), colour, tip=0.0, vertices=5, roughness=0.15, **look)


# -- Moon Egg --
def moonrock():  # a lump of the Moon
    standard("AAAABA", "FFE23A", shape="round")
    pits("8E8CA0", ((-0.55, 0.1, 2.02, 0.26), (0.6, -0.2, 1.98, 0.18), (-0.98, 0.2, 1.3, 0.2), (0.98, -0.1, 1.5, 0.24)))


def crater():  # an alien out of one
    standard("6E6E82", "9CFF3A")
    antennae("4E4E60", "9CFF3A")
    pits("4E4E60", ((-0.98, 0.2, 1.2, 0.24), (0.98, -0.1, 1.5, 0.2)))


def lunar():  # a moon bat in a scarf
    standard("D7DCF0", "9B6BFF")
    ears("D7DCF0", "bat", inner="9B6BFF")
    scarf("5A78DC")
    ball(0.34, (0.55, -0.9, 1.98), "FFE97A", scale=(1, 0.25, 1), emission=1.5)  # a crescent on its brow
    ball(0.3, (0.67, -0.95, 2.04), "D7DCF0", scale=(1, 0.3, 1))


def astro():  # an astronaut with a jet pack
    standard("5A78DC", "FFFFFF", barrel_colour="E6EAF2")
    helmet()
    antennae("E6EAF2", "FF3355", spread=0.75)


def stellar():  # a star, crowned
    standard("FAF0AA", "FF96FF", shape="round", barrel_colour="E0A81C")
    star_points("FFE23A", emission=1.0)
    crown(top=3.02, y=0.1, radius=0.34, gems="9B6BFF")
    halo(top=3.55, colour="FFFFFF", radius=0.5)


# -- Comet Egg --
def dust():  # a dust bunny
    standard("BEB9AF", "8A5A2B", shape="round")
    ears("BEB9AF", "bunny", inner="E8E2D6")
    for x, y, z in ((-0.95, 0.4, 0.75), (0.95, 0.3, 0.8), (0.3, 0.95, 0.8)):
        ball(0.26, (x, y, z), "D8D3C8")


def comet():
    standard("96D2FF", "FFFFFF", shape="round", barrel_colour="5FA8F0")
    streak("C9F0FF", emission=1.0)
    ears("96D2FF", "cat", inner="C9F0FF")


def meteor():  # hot rock
    standard("82645A", "FF7A2E", mood="fierce")
    pits("5A4038", ((-0.55, 0.1, 2.02, 0.24), (-0.98, 0.2, 1.3, 0.22), (0.98, -0.1, 1.5, 0.22)))
    horns("FF7A2E", size=1.1)
    streak("FF7A2E", emission=2.0)


def star():
    standard("FFEB82", "FF8FB8", barrel_colour="E0A81C")
    star_points("FFD23A", emission=0.8)
    wings("FFF7C9", "crystal", height=1.5)


def galaxy():  # a whole one, with a ring round it
    standard("6E50D2", "3FE0FF", mood="fierce", shape="round", barrel_colour="3A2A8C")
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, 0.95), rotation=(0, math.radians(12), 0), major_radius=1.55, minor_radius=0.1, major_segments=24, minor_segments=6)
    finish(bpy.context.object, "FF96FF", emission=2)
    for x, y, z in ((-0.6, -0.5, 2.05), (0.7, 0.3, 2.0), (-0.9, 0.5, 1.6), (0.95, -0.3, 0.9)):
        ball(0.09, (x, y, z), "FFFFFF", emission=4)  # stars in it
    crown(top=3.02, y=0.1, radius=0.34, gems="3FE0FF")
    halo(top=3.55, colour="C9B8FF", radius=0.5)


# ---------------------------------------------------------------------------------------------------
# Eggs: one design per egg, about 3.6 tall, standing on the ground.
# ---------------------------------------------------------------------------------------------------
TAPER = 0.3  # how much narrower an egg is at its top than at its middle


def narrow(z):
    """An egg's width at height z, as a share of its widest."""
    return 1 - TAPER * max(0.0, (z - 1.8) / 1.78) ** 1.4


def shell(colour, **look):
    # Finer than the other balls (an egg is looked at up close and stands still), and narrower towards the top.
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.35, location=(0, 0, 1.8), segments=24, ring_count=14)
    obj = bpy.context.object
    obj.scale = (1, 1, 1.32)
    bpy.ops.object.transform_apply(scale=True)
    for vertex in obj.data.vertices:
        factor = narrow(vertex.co.z)  # applying the scale applied the location too: z is already the height
        vertex.co.x *= factor
        vertex.co.y *= factor
    finish(obj, colour, **look)


def spots(colour, places, **look):
    for x, z, radius in places:
        width = 1.35 * narrow(z)
        depth = math.sqrt(max(0.05, 1 - (x / width) ** 2 - ((z - 1.8) / 1.78) ** 2)) * width
        ball(radius, (x, -depth + 0.06, z), colour, scale=(1, 0.3, 1.1), **look)


def egg_gem():
    shell("50DCFF", roughness=0.15)
    spots("C9F9FF", ((-0.5, 2.3, 0.3), (0.55, 1.5, 0.36), (-0.25, 1.1, 0.22), (0.35, 2.75, 0.2)), roughness=0.15)
    crystals("9FF3FF", ((-1.1, 0.2, 0.0, 0.3, 1.2, -0.5), (1.15, 0.1, 0.0, 0.34, 1.45, 0.45), (0.6, -0.9, 0.0, 0.22, 0.8, 0.3), (-0.5, -1.0, 0.0, 0.2, 0.7, -0.3), (0.0, 1.1, 0.0, 0.3, 1.1, 0.1)), emission=0.8)
    crystals("FF96FF", ((0, 0, 3.4, 0.3, 0.8, 0), (-0.3, 0.1, 3.3, 0.18, 0.5, -0.6), (0.3, 0.1, 3.3, 0.18, 0.5, 0.6)), emission=1.0)
    for x, z in ((-0.9, 2.9), (0.95, 2.3), (-1.0, 1.4)):  # sparkles
        ball(0.12, (x, -0.75, z), "FFFFFF", scale=(1, 1, 2.2), emission=4)
        ball(0.12, (x, -0.75, z), "FFFFFF", scale=(2.2, 1, 1), emission=4)


def egg_pumpkin():
    shell("FF821E")
    for index in range(6):  # the ridges of a pumpkin, as lobes around the shell
        angle = math.radians(index * 60 + 30)
        ball(0.62, (math.cos(angle) * 0.72, math.sin(angle) * 0.72, 1.75), shade("FF821E", -0.1 if index % 2 else 0.08), scale=(1, 1, 2.6))
    stem(top=3.5)
    ball(0.5, (0.5, 0.1, 3.6), "4E9A3A", scale=(1.3, 0.8, 0.2), rotation=(0, math.radians(-25), 0))
    for side in (-1, 1):  # a carved grin
        tube(0.26, 0.12, (side * 0.45, -1.22, 2.25), (0, -1, 0.1), "FFE23A", vertices=3, emission=4)
    for index in range(5):
        tube(0.14, 0.1, (-0.56 + index * 0.28, -1.3, 1.5 + (0.05 if index % 2 else -0.04)), (0, -1, 0), "FFE23A", vertices=3, emission=4)


def egg_haunted():
    shell("6E3CA0")
    spots("9B6BE0", ((-0.55, 2.6, 0.3), (0.6, 1.2, 0.3), (0.5, 2.9, 0.18)))
    # A little ghost painted on the front, and bat wings on the sides.
    ball(0.5, (0, -1.3, 1.85), "F2F5FF", scale=(1, 0.3, 1.15))
    for x in (-0.17, 0.17):
        ball(0.1, (x, -1.44, 1.98), INK, scale=(1, 0.4, 1.3))
    ball(0.08, (0, -1.44, 1.7), INK, scale=(1, 0.4, 1.2))
    for side in (-1, 1):
        for reach, up in ((1.0, 0.8), (1.25, 0.3), (1.05, -0.15)):
            tube(0.2, 0.95, (side * 1.15, 0.2, 2.2), (side * reach, 0.1, up), "372B47", tip=0.03, vertices=6)
        ball(0.45, (side * 1.6, 0.25, 2.35), "372B47", scale=(1.3, 0.2, 0.9))


def egg_crypt():
    shell("7F8892", roughness=0.8)
    spots("5C6168", ((-0.5, 2.5, 0.26), (0.6, 1.4, 0.3), (0.2, 3.0, 0.16)), roughness=0.8)
    for x, z, lean in ((-0.25, 2.1, 20), (0.05, 1.85, -35), (-0.1, 1.6, 30)):  # a crack
        box((0.09, 0.1, 0.42), (x, -1.33, z), "33373D", bevel=0.02, rotation=(0, math.radians(lean), 0))
    for x, y, z in ((-0.9, -0.7, 0.35), (1.0, -0.5, 0.3), (0.2, -1.2, 0.25), (-0.3, 1.0, 0.3)):
        ball(0.42, (x, y, z), "5FA052", scale=(1.2, 1, 0.6))  # moss at its foot
    tube(0.1, 1.3, (0.75, -1.1, 0.25), (1, -0.2, 0.25), "EDE8D8", vertices=6)  # a bone leaning on it
    ball(0.17, (0.75, -1.1, 0.25), "EDE8D8")
    ball(0.17, (2.0, -1.36, 0.57), "EDE8D8")


def egg_bloodmoon():
    shell("AA141E", roughness=0.3)
    spots("7A0F18", ((0.6, 2.6, 0.26), (-0.65, 1.3, 0.3), (0.45, 1.05, 0.2)))
    # A glowing crescent moon on the front.
    ball(0.52, (-0.05, -1.3, 2.0), "FFE23A", scale=(1, 0.25, 1), emission=3)
    ball(0.46, (0.16, -1.36, 2.1), "AA141E", scale=(1, 0.3, 1), roughness=0.3)
    horns("3A0A12", top=3.2, spread=0.55, size=1.5)
    halo(top=4.25, colour="FF5A5A", radius=0.7)


# -- The coin eggs: one design, dressed for its world. --
def world_egg(colour, spot, **look):
    shell(colour, **look)
    spots(spot, ((-0.5, 2.5, 0.28), (0.6, 1.4, 0.32), (0.25, 2.95, 0.18), (-0.3, 1.1, 0.2)), **look)


def ring(colour, z, tilt=0.0, thickness=0.09, **look):
    """A band round an egg at height z."""
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, z), rotation=(0, math.radians(tilt), 0), major_radius=1.35 * narrow(z) * math.sqrt(max(0.1, 1 - ((z - 1.8) / 1.78) ** 2)), minor_radius=thickness, major_segments=20, minor_segments=6)
    finish(bpy.context.object, colour, **look)


def tufts(colour, places):
    """Things growing (or lying) round an egg's foot: (x, y, size)."""
    for x, y, size in places:
        for lean in (-0.5, 0, 0.5):
            tube(0.14 * size, 0.7 * size, (x, y, 0), (lean, 0, 1), colour, tip=0.0, vertices=5)


FOOT = ((-1.0, -0.6, 1.0), (1.05, -0.4, 1.2), (0.3, -1.15, 0.8), (-0.4, 1.0, 1.1), (0.9, 0.8, 0.9))


def egg_basic():  # a grass egg with a leaf
    world_egg("A8E07A", "6EBE5A")
    stem(top=3.52)
    tufts("4E9A3A", FOOT)


def egg_forest():
    world_egg("3E9B57", "2A6B34")
    stem(top=3.52)
    ball(0.3, (-0.38, 0.05, 3.72), "8FDB6E", scale=(1.2, 0.7, 0.22), rotation=(0, math.radians(20), 0))
    ring("2A6B34", 1.75, tilt=14)  # a vine round it
    for x, z in ((-0.7, 1.95), (0.5, 1.62)):
        ball(0.13, (x, -1.28, z), "FF8FB8", scale=(1, 0.5, 1))  # and its flowers
    for x, y, size in ((-1.1, -0.5, 1.0), (1.15, -0.3, 0.75), (0.3, -1.2, 0.6)):  # toadstools at its foot
        tube(0.12 * size, 0.45 * size, (x, y, 0), (0, 0, 1), "F2E6D0", vertices=8)
        ball(0.36 * size, (x, y, 0.45 * size), "D2463C", scale=(1, 1, 0.55))


def craters(colour, places):
    for x, z, radius in places:
        width = 1.35 * narrow(z)
        depth = math.sqrt(max(0.05, 1 - (x / width) ** 2 - ((z - 1.8) / 1.78) ** 2)) * width
        bpy.ops.mesh.primitive_torus_add(location=(x, -depth + 0.02, z), rotation=(math.radians(90), 0, 0), major_radius=radius, minor_radius=radius * 0.3, major_segments=12, minor_segments=5)
        finish(bpy.context.object, colour, roughness=0.8)


def egg_moon():  # cratered
    world_egg("C9C7D6", "A7A5B8", roughness=0.8)
    craters("8E8CA0", ((0.1, 2.0, 0.3), (-0.6, 1.3, 0.2), (0.65, 2.7, 0.16)))
    for x, y, size in ((-1.1, -0.5, 0.4), (1.2, -0.3, 0.5), (0.4, -1.2, 0.3)):  # moon rocks
        ball(size, (x, y, size * 0.5), "A7A5B8", scale=(1.2, 1, 0.7), roughness=0.8)


def egg_comet():
    world_egg("8FD0FF", "5FA8F0", roughness=0.2)
    craters("C9F0FF", ((-0.1, 1.9, 0.26), (0.6, 2.7, 0.16)))
    # A comet's tail streaming off its top.
    crystals("C9F0FF", ((0.1, 0.2, 3.3, 0.3, 1.3, 0.5), (0.35, 0.3, 3.2, 0.2, 0.95, 1.0), (-0.1, 0.3, 3.3, 0.18, 0.8, 0.15)), emission=1.2)
    for x, z in ((-0.95, 2.8), (1.0, 1.5)):
        ball(0.12, (x, -0.75, z), WHITE, scale=(1, 1, 2.2), emission=4)
        ball(0.12, (x, -0.75, z), WHITE, scale=(2.2, 1, 1), emission=4)


def egg_mars():  # rust and rock
    world_egg("D9643A", "A8431F", roughness=0.8)
    craters("8A3518", ((0.15, 2.1, 0.26),))
    for x, y, size in ((-1.1, -0.5, 0.5), (1.15, -0.4, 0.4), (0.3, -1.2, 0.3), (-0.5, 1.0, 0.45)):
        ball(size, (x, y, size * 0.5), "A8431F", scale=(1.2, 1, 0.7), roughness=0.8)


def egg_dune():  # sand, with a cactus beside it
    shell("E8C078", roughness=0.8)
    for z, tilt in ((1.2, 8), (1.9, -6), (2.6, 8)):  # wind lines
        ring("CFA35A", z, tilt=tilt, thickness=0.07, roughness=0.8)
    tube(0.26, 1.3, (1.5, -0.4, 0), (0, 0, 1), "46A050", vertices=8)
    ball(0.26, (1.5, -0.4, 1.3), "46A050")
    tube(0.15, 0.5, (1.5, -0.4, 0.6), (1, 0, 0.2), "46A050", vertices=8)
    tube(0.15, 0.45, (1.92, -0.4, 0.66), (0, 0, 1), "46A050", vertices=8)
    ball(0.1, (1.5, -0.4, 1.58), "FF8FB8")
    ball(1.5, (0, 0, 0.02), "E0B468", scale=(1.2, 1.1, 0.1), roughness=0.9)  # the dune it stands on


def snow_cap(colour=WHITE):
    ball(0.98, (0, 0, 3.32), colour, scale=(1, 1, 0.5), roughness=0.3)
    for index in range(7):
        angle = math.radians(index * 51 + 10)
        ball(0.3, (math.cos(angle) * 0.82, math.sin(angle) * 0.82, 3.12 - (index % 2) * 0.14), colour, scale=(1, 1, 1.3), roughness=0.3)


def egg_frost():
    world_egg("BFE8FF", "8FCBF5", roughness=0.2)
    snow_cap()
    for x, y, size in ((-1.1, -0.5, 0.5), (1.15, -0.4, 0.42), (0.3, -1.2, 0.34), (-0.4, 1.0, 0.5)):  # snow at its foot
        ball(size, (x, y, size * 0.35), WHITE, scale=(1.2, 1, 0.6), roughness=0.3)


def egg_blizzard():
    world_egg("7FB4F5", "4E86DC", roughness=0.2)
    snow_cap()
    crystals("DDF4FF", ((-1.1, 0.2, 0.0, 0.28, 1.2, -0.5), (1.15, 0.1, 0.0, 0.32, 1.4, 0.45), (0.6, -0.9, 0.0, 0.2, 0.8, 0.3), (-0.5, -1.0, 0.0, 0.2, 0.7, -0.3)), emission=0.6)
    crystals("DDF4FF", ((0, 0, 3.6, 0.2, 0.7, 0),), emission=0.6)


def egg_ember():  # cooling lava: dark rock, glowing cracks
    shell("5A2A1E", roughness=0.8)
    spots("FF7A2E", ((-0.5, 2.5, 0.26), (0.6, 1.4, 0.3), (0.25, 2.95, 0.16), (-0.3, 1.1, 0.2)), emission=3)
    for x, z, lean in ((-0.05, 2.2, 25), (0.2, 1.95, -35), (0.05, 1.7, 30), (0.3, 1.45, -25)):
        box((0.1, 0.1, 0.42), (x, -1.33 * narrow(z), z), "FFC83A", bevel=0.02, rotation=(0, math.radians(lean), 0), emission=4)
    tufts("FF7A2E", ((-1.0, -0.6, 0.8), (1.05, -0.4, 1.0), (0.3, -1.15, 0.6)))  # flames


def egg_solar():  # a little sun
    world_egg("FFD23A", "FFA51E", emission=0.6)
    for index in range(10):  # rays
        angle = math.radians(index * 36)
        tube(0.2, 0.7, (math.cos(angle) * 1.4, 0.3, 1.9 + math.sin(angle) * 1.75), (math.cos(angle), 0, math.sin(angle) * 1.2), "FFA51E", tip=0.0, vertices=5, emission=2)
    halo(top=4.0, colour="FFF1B0", radius=0.7)


MARKETPLACE = [
    ("gem", egg_gem, [("gem", gem), ("ruby", ruby), ("sapphire", sapphire), ("emerald", emerald), ("prismatic", prismatic)]),
    ("pumpkin", egg_pumpkin, [("pumpkin", pumpkin), ("bat", bat), ("ghost", ghost), ("witch", witch), ("jackolantern", jack_o_lantern)]),
    ("haunted", egg_haunted, [("skeleton", skeleton), ("zombie", zombie), ("vampire", vampire), ("reaper", reaper), ("headlesshorseman", headless_horseman)]),
    ("crypt", egg_crypt, [("tombstone", tombstone), ("spider", spider), ("mummy", mummy), ("gargoyle", gargoyle), ("lich", lich)]),
    ("bloodmoon", egg_bloodmoon, [("crow", crow), ("scarecrow", scarecrow), ("werewolf", werewolf), ("banshee", banshee), ("bloodmoon", blood_moon)]),
]
# A row is photographed together. An entry named egg_... is another egg standing in the row, not a mini cannon.
WORLDS = [
    ("basic", egg_basic, [("wooden", wooden), ("iron", iron), ("steel", steel), ("gold", gold), ("diamond", diamond)]),
    ("forest", egg_forest, [("leaf", leaf), ("vine", vine), ("mushroom", mushroom), ("honey", honey), ("jade", jade)]),
    ("moon", egg_moon, [("moonrock", moonrock), ("crater", crater), ("lunar", lunar), ("astro", astro), ("stellar", stellar)]),
    ("comet", egg_comet, [("dust", dust), ("comet", comet), ("meteor", meteor), ("star", star), ("galaxy", galaxy)]),
    ("mars", egg_mars, [("egg_dune", egg_dune), ("egg_frost", egg_frost), ("egg_blizzard", egg_blizzard), ("egg_ember", egg_ember), ("egg_solar", egg_solar)]),
]
EGGS = {"marketplace": MARKETPLACE, "worlds": WORLDS}[SET]
FILE = {"marketplace": "marketplace_minis", "worlds": "world_minis"}[SET]


def model_name(name):
    return name if name.startswith("egg_") else "mini_" + name


ROW_GAP = 60  # each egg's line-up is far enough from the next to be photographed alone
models = {}  # name -> list of parts
for row, (egg_id, egg_build, minis) in enumerate(EGGS):
    line = [("egg_" + egg_id, egg_build, -9.6)] + [(model_name(name), build, -5.2 + index * 3.9) for index, (name, build) in enumerate(minis)]
    for name, build, x in line:
        parts = []
        origin = Vector((x, row * ROW_GAP, 0))
        build()
        models[name] = (parts, origin.copy())

# ---- The photos: grass, sky, sun ----
bpy.ops.mesh.primitive_plane_add(size=1200, location=(0, 0, 0))
ground = bpy.context.object
ground.data.materials.append(mat("8FDB6E", roughness=0.9))
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*linear("BFE6FF"), 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
scene.world = world
sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 3.2
sun_data.angle = math.radians(12)
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(52), 0, math.radians(-32))

camera_data = bpy.data.cameras.new("Camera")
camera_data.lens = 50
camera = bpy.data.objects.new("Camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x = 2200
scene.render.resolution_y = 760
scene.view_settings.view_transform = "Standard"


def turn(model_parts, at, angle):
    """Turns a model about its own upright axis."""
    spin = Matrix.Translation(at) @ Matrix.Rotation(angle, 4, "Z") @ Matrix.Translation(-at)
    for obj in model_parts:
        obj.matrix_world = spin @ obj.matrix_world


# Photographed turned a little to one side, so the barrel and the fuse show, one egg's line-up at a time.
POSE = math.radians(-34)
if MODE == "eggs":
    egg_names = [name for name in models if name.startswith("egg_")]
    for name, (model_parts, at) in models.items():
        for obj in model_parts:
            obj.hide_render = name not in egg_names
    for index, name in enumerate(egg_names):
        model_parts, at = models[name]
        slide = Matrix.Translation(Vector(((index - 2) * 4.6, 0, 0)) - at)
        for obj in model_parts:
            obj.matrix_world = slide @ obj.matrix_world
        turn(model_parts, Vector(((index - 2) * 4.6, 0, 0)), math.radians(-20))
    centre = Vector((0, 0, 2.2))
    camera.location = centre + Vector((0, -30, 5.5))
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_y = 640
    scene.render.filepath = f"{OUT}/eggs.png"
    bpy.ops.render.render(write_still=True)
    raise SystemExit
for row, (egg_id, _, minis) in enumerate(EGGS if MODE == "full" else []):
    in_row = {"egg_" + egg_id} | {model_name(name) for name, _ in minis}
    for name, (model_parts, at) in models.items():
        for obj in model_parts:
            obj.hide_render = name not in in_row
        if name in in_row:
            turn(model_parts, at, POSE)
    centre = Vector((0.4, row * ROW_GAP, 1.9))
    camera.location = centre + Vector((0, -35, 6.0))
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{OUT}/row_{egg_id}.png"
    bpy.ops.render.render(write_still=True)
    for name in in_row:
        turn(models[name][0], models[name][1], -POSE)
for model_parts, _ in models.values():
    for obj in model_parts:
        obj.hide_render = False

# ---- For Roblox: one mesh per model, colours on the vertices ----
ground.select_set(False)
for name, (model_parts, at) in models.items():
    triangles = 0
    bpy.ops.object.select_all(action="DESELECT")
    for obj in model_parts:
        colour = obj.data.materials[0].diffuse_color
        attribute = obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        attribute.data.foreach_set("color", [colour[0], colour[1], colour[2], 1.0] * len(obj.data.loops))
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = model_parts[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    joined.data.name = name
    # Its origin goes under its feet, in the middle, so it stands on whatever it is placed on.
    scene.cursor.location = (at.x, at.y, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    print(f"MODEL {name} triangles {triangles}")

bpy.ops.object.select_all(action="DESELECT")
for name in models:
    bpy.data.objects[name].select_set(True)
bpy.ops.export_scene.fbx(filepath=f"{OUT}/{FILE}.fbx", use_selection=True, apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", colors_type="SRGB")
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/{FILE}.blend")
