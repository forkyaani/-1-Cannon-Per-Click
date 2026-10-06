"""Mini cannons ("cannon critters") and eggs of the five launch worlds: Earth, Moon, Mars, Neptune, The Sun.

Run: blender --background --python tools/blender/world_minis.py -- <output folder> <World> [draft]
     (<World> is Config.Worlds' name: Earth, Moon, Mars, Neptune, "The Sun")

The same family as tools/blender/minis.py (the marketplace's): a rounded creature with big eyes that is still a
cannon, with wheels, a barrel on its head aimed along -Y and a fuse for a tail. The kit here is that script's,
made of fewer triangles (500 to 1,500 a model). Every model is joined into one mesh with its colours on the
vertices ("Col"), so in Roblox it is a single part.

A world has two coin eggs, and an egg has eight mini cannons: its five (Common to Legendary), its two Secrets
(Glitched, Forbidden) and its Huge. A Huge that an earlier egg already hides is not made again.
Writes <world>_minis.fbx, .blend and <world>_minis_sheet.png (one row per egg, the egg at the end of its row).
Meshes are named by the game's ids: a mini cannon by its pet id, an egg "Egg_<egg id>" (tools/studio/setup_models.luau
files them into ReplicatedStorage.MiniCannons and ReplicatedStorage.EggModels).
"""
import math
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "."
WORLD = ARGS[1] if len(ARGS) > 1 else "Earth"
DRAFT = "draft" in ARGS

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}

WHITE, INK, BLUSH, GOLD, WOOD, SPARK = "FFFFFF", "1B1140", "FF8FB8", "FFC61A", "8A5A2B", "FFB01F"
MAGENTA, CYAN = "FF3CDC", "3CFFF0"
RAD = math.radians


def linear(hex_code):
    hex_code = hex_code.lstrip("#")
    return tuple(((int(hex_code[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4))


def shade(hex_code, amount):
    """Darker (amount < 0) or lighter (amount > 0) version of a colour."""
    hex_code = hex_code.lstrip("#")
    target = 255 if amount > 0 else 0
    return "".join("%02X" % round(int(hex_code[i:i + 2], 16) + (target - int(hex_code[i:i + 2], 16)) * abs(amount)) for i in (0, 2, 4))


def blend(a, b, share):
    """`share` of b in a: Color3:Lerp."""
    return "".join("%02X" % round(int(a[i:i + 2], 16) + (int(b[i:i + 2], 16) - int(a[i:i + 2], 16)) * share) for i in (0, 2, 4))


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


def finish(obj, colour, flat_caps=False, smooth=True, **look):
    obj.data.materials.append(mat(colour, **look))
    for polygon in obj.data.polygons:
        # The ends of a tube stay flat, or its mouth shades like a cone.
        polygon.use_smooth = smooth and not (flat_caps and abs(polygon.normal.z) > 0.99)
    obj.location += origin
    parts.append(obj)
    return obj


def box(size, location, colour, bevel=0.0, rotation=(0, 0, 0), **look):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = min(bevel, min(size) * 0.49)
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
    return finish(obj, colour, smooth=bool(bevel), **look)


def ball(radius, location, colour, scale=(1, 1, 1), rotation=(0, 0, 0), seg=10, rings=5, floor=None, **look):
    """floor: nothing of the ball hangs lower than this far under its middle (a dome, a cap)."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=seg, ring_count=rings, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if floor is not None:
        for vertex in obj.data.vertices:
            vertex.co.z = max(vertex.co.z, -floor)
    return finish(obj, colour, **look)


def dot(radius, location, colour, **look):
    """A small ball of few triangles."""
    return ball(radius, location, colour, seg=6, rings=3, **look)


def gem(radius, location, colour, scale=(1, 1, 1), rotation=(0, 0, 0), sub=1, **look):
    """A faceted lump: 20 triangles (sub 1) or 80 (sub 2)."""
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, location=location, subdivisions=sub, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, colour, smooth=False, **look)


def tube(radius, depth, start, direction, colour, tip=None, vertices=10, **look):
    """A cylinder (or a cone when tip is given) from `start` along `direction`."""
    direction = Vector(direction).normalized()
    location = Vector(start) + direction * depth / 2
    rotation = direction.to_track_quat("Z", "Y").to_euler()
    if tip is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=tip, depth=depth, location=location, rotation=rotation, vertices=vertices)
    return finish(bpy.context.object, colour, flat_caps=True, **look)


def disc(radius, location, colour, facing=(0, -1, 0), vertices=10, scale=(1, 1, 1), **look):
    """A flat round patch that looks along `facing`: an iris, a blush, a spot."""
    rotation = Vector(facing).normalized().to_track_quat("Z", "Y").to_euler()
    bpy.ops.mesh.primitive_circle_add(radius=radius, location=location, rotation=rotation, vertices=vertices, fill_type="TRIFAN")
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, colour, smooth=False, **look)


def ring(major, minor, location, colour, rotation=(0, 0, 0), scale=(1, 1, 1), seg=14, minor_seg=4, **look):
    """A hoop lying flat (its axis is z) until `rotation` turns it."""
    bpy.ops.mesh.primitive_torus_add(location=location, rotation=rotation, major_radius=major, minor_radius=minor, major_segments=seg, minor_segments=minor_seg)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, colour, **look)


def plate(points, thickness, location, colour, rotation=(0, 0, 0), **look):
    """A shape cut from a sheet: `points` are (x, z) round its outline; it stands upright, `thickness` deep."""
    mesh = bpy.data.meshes.new("Plate")
    bm = bmesh.new()
    front = [bm.verts.new((x, -thickness / 2, z)) for x, z in points]
    back = [bm.verts.new((x, thickness / 2, z)) for x, z in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    count = len(points)
    for index in range(count):
        bm.faces.new((front[index], back[index], back[(index + 1) % count], front[(index + 1) % count]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Plate", mesh)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    return finish(obj, colour, smooth=False, **look)


def star_points(outer, inner, points=5, turn=90.0):
    return [((outer if index % 2 == 0 else inner) * math.cos(RAD(turn + index * 180 / points)),
             (outer if index % 2 == 0 else inner) * math.sin(RAD(turn + index * 180 / points))) for index in range(points * 2)]


def crescent_points(radius, horn=45.0, dip=0.25, steps=8):
    """A crescent with its horns up."""
    tip = (radius * math.cos(RAD(horn)), radius * math.sin(RAD(horn)))
    middle = radius * dip
    inner = math.hypot(tip[0], tip[1] - middle)
    alpha = math.degrees(math.atan2(tip[1] - middle, tip[0]))
    outline = []
    for index in range(steps + 1):  # the outer edge, from the right horn down and round to the left one
        angle = RAD(horn - (180 + 2 * horn) * index / steps)
        outline.append((radius * math.cos(angle), radius * math.sin(angle)))
    for index in range(1, steps):  # the inner edge, back again
        angle = RAD(-180 - alpha + (180 + 2 * alpha) * index / steps)
        outline.append((inner * math.cos(angle), middle + inner * math.sin(angle)))
    return outline


def round_points(radius, count=10):
    return [(radius * math.cos(RAD(index * 360 / count)), radius * math.sin(RAD(index * 360 / count))) for index in range(count)]


BOLT = [(0.3, 1.0), (-0.38, 0.08), (-0.02, 0.08), (-0.3, -1.0), (0.42, 0.2), (0.06, 0.2)]
FLAME = [(0.0, -0.9), (0.55, -0.55), (0.62, 0.0), (0.3, 0.45), (0.38, 0.05), (0.05, 1.0), (-0.35, 0.3), (-0.5, 0.5), (-0.62, -0.1), (-0.5, -0.6)]


def scaled(points, size):
    return [(x * size, z * size) for x, z in points]


# ---------------------------------------------------------------------------------------------------
# The kit
# ---------------------------------------------------------------------------------------------------
FRONT = -0.86  # y of a cube body's face
TOPS = {"cube": 2.05, "round": 2.0, "tall": 2.45, "facet": 2.0}
FACES = {"cube": 1.45, "round": 1.45, "tall": 1.6, "facet": 1.45}
FRONTS = {"cube": FRONT, "round": -0.93, "tall": -0.81, "facet": -0.95}


def body(colour, shape="cube", lift=0.0, **look):
    if shape == "round":
        ball(1.05, (0, 0, 1.3 + lift), colour, scale=(1, 0.92, 0.9), seg=12, rings=6, **look)
    elif shape == "facet":
        gem(1.12, (0, 0, 1.3 + lift), colour, scale=(1, 0.9, 0.88), sub=2, **look)
    elif shape == "tall":
        box((1.7, 1.6, 2.0), (0, 0, 1.45 + lift), colour, bevel=0.5, **look)
    else:
        box((1.9, 1.7, 1.6), (0, 0, 1.25 + lift), colour, bevel=0.5, **look)


def wheels(colour="5A3A6E", hub=GOLD, radius=0.5, y=0.05, spread=0.9):
    for side in (-1, 1):
        tube(radius, 0.3, (side * spread, y, radius), (side, 0, 0), colour)
        disc(radius * 0.36, (side * (spread + 0.31), y, radius), hub, facing=(side, 0, 0), vertices=8)


def barrel(colour, top=2.05, band=GOLD, length=1.45, radius=0.4):
    """The cannon on its head, aimed forward (-Y) and a little up."""
    direction = Vector((0, -math.cos(RAD(16)), math.sin(RAD(16))))
    start = Vector((0, 0.72, top + 0.3))
    tube(radius, length, start, direction, colour, vertices=12)
    tube(radius + 0.08, 0.2, start + direction * (length - 0.16), direction, band)
    tube(radius + 0.06, 0.16, start + direction * 0.12, direction, band)
    disc(radius - 0.12, start + direction * (length + 0.045), INK, facing=direction)
    ball(radius, start, colour, seg=8, rings=4)
    # A cradle so the barrel sits on the head instead of floating over it.
    box((0.6, 0.8, 0.3), (0, 0.15, top + 0.06), shade(colour, -0.25))


def fuse(height=1.3, colour="3A1F55", spark=SPARK):
    for index in range(3):
        dot(0.12 - index * 0.012, (0, 0.92 + index * 0.17, height + index * 0.2), colour)
    dot(0.19, (0, 1.48, height + 0.66), spark, emission=5)


def eye(x, height, iris, size=0.85, front=FRONT):
    # The balls lie on their side (their axis looks forward), so the eye's outline is the ball's 14 segments.
    ball(0.5 * size, (x, front - 0.02, height), WHITE, scale=(1, 1.08, 0.3), rotation=(RAD(90), 0, 0), seg=14, rings=3, roughness=0.2)
    ball(0.42 * size, (x, front - 0.09, height - 0.02), INK, scale=(1, 1.1, 0.3), rotation=(RAD(90), 0, 0), seg=14, rings=3, roughness=0.08)
    y = front - 0.1 - 0.13 * size
    disc(0.25 * size, (x, y, height - 0.1), iris, vertices=10, roughness=0.3, emission=1.2)
    disc(0.13 * size, (x - 0.13 * size, y - 0.012, height + 0.17 * size), WHITE, vertices=6, roughness=0.2)
    disc(0.07 * size, (x + 0.16 * size, y - 0.012, height - 0.16 * size), WHITE, vertices=5, roughness=0.2)


def eyes(height=1.45, spread=0.46, iris="3FE0FF", size=0.85, front=FRONT, other=None):
    eye(-spread, height, iris, size, front)
    eye(spread, height, other or iris, size, front)


def blush(height=1.02, spread=0.82, front=FRONT):
    for side in (-1, 1):
        disc(0.2, (side * spread, front - 0.015, height), BLUSH, vertices=8, scale=(1.15, 0.6, 1), roughness=0.6)


def smile(height=0.86, width=0.34, front=FRONT):
    box((width, 0.12, 0.12), (0, front - 0.05, height), INK)
    for side in (-1, 1):
        box((0.16, 0.12, 0.12), (side * (width / 2 + 0.02), front - 0.05, height + 0.05), INK, rotation=(0, side * RAD(-40), 0))


def fangs(height=0.8, spread=0.2, front=FRONT):
    for side in (-1, 1):
        tube(0.09, 0.26, (side * spread, front - 0.08, height + 0.06), (0, 0, -1), WHITE, tip=0.0, vertices=6)


def brows(colour, height=2.0, spread=0.46, tilt=-22, front=FRONT):
    for side in (-1, 1):
        box((0.56, 0.16, 0.15), (side * spread, front - 0.12, height), colour, rotation=(0, side * RAD(tilt), 0))


def face(iris, height=1.45, mood="happy", brow=None, front=FRONT, other=None):
    eyes(height, iris=iris, front=front, other=other)
    blush(height - 0.43, front=front)
    smile(height - 0.59, front=front)
    if mood == "fierce":
        brows(brow or INK, height + 0.52, front=front)
        fangs(height - 0.66, front=front)


def critter(colour, iris="3FE0FF", mood="happy", shape="cube", barrel_colour=None, band=GOLD, wheel="5A3A6E", hub=GOLD,
            lift=0.0, rolls=True, faced=True, brow=None, **look):
    """What nearly every mini cannon has: body, wheels, barrel, fuse, face. Returns the height of its head."""
    body(colour, shape, lift, **look)
    if rolls:
        wheels(wheel, hub)
    top = TOPS[shape] + lift
    barrel(barrel_colour or shade(colour, -0.35), top=top, band=band)
    fuse(height=1.3 + lift)
    if faced:
        face(iris, height=FACES[shape] + lift, mood=mood, brow=brow or shade(colour, -0.5), front=FRONTS[shape])
    return top


def ears(colour, kind="cat", inner="FFB3C7", top=2.0):
    for side in (-1, 1):
        if kind == "cat":
            tube(0.36, 0.6, (side * 0.6, 0.1, top - 0.08), (side * 0.25, 0, 1), colour, tip=0.0, vertices=8)
            tube(0.2, 0.36, (side * 0.6, -0.05, top - 0.04), (side * 0.25, 0, 1), inner, tip=0.0, vertices=6)
        elif kind == "round":
            ball(0.36, (side * 0.78, 0.1, top + 0.05), colour, scale=(1, 0.6, 1), seg=8, rings=4)
            disc(0.2, (side * 0.78, -0.13, top + 0.05), inner, vertices=8)
        elif kind == "bunny":
            ball(0.3, (side * 0.5, 0.1, top + 0.55), colour, scale=(0.8, 0.5, 2.3), rotation=(0, side * RAD(12), 0), seg=8, rings=4)
            disc(0.16, (side * 0.53, -0.06, top + 0.6), inner, vertices=8, scale=(1, 2.6, 1))


def horns(colour="FFF3D6", top=2.0, spread=0.72, size=1.0):
    for side in (-1, 1):
        tube(0.2 * size, 0.6 * size, (side * spread, 0.1, top - 0.08), (side * 0.5, 0, 1), colour, tip=0.0, vertices=8)


def wings(colour, kind="bat", height=1.5, tips=None, **look):
    for side in (-1, 1):
        if kind == "bat":
            for index, (reach, up) in enumerate(((1.0, 0.75), (1.25, 0.3), (1.05, -0.15))):
                tube(0.2, 0.9 + index * 0.05, (side * 0.85, 0.55, height), (side * reach, 0.25, up), colour, tip=0.0, vertices=6, **look)
            dot(0.42, (side * 1.25, 0.72, height + 0.15), colour, scale=(1.3, 0.2, 0.9), **look)
        elif kind == "crystal":
            for reach, up, length in ((0.9, 1.0, 1.25), (1.2, 0.45, 1.05), (1.1, -0.05, 0.8)):
                tube(0.2, length, (side * 0.85, 0.55, height), (side * reach, 0.2, up), colour, tip=0.0, vertices=5, roughness=0.15, emission=0.6)
        elif kind == "feather":
            for index, up in enumerate((42, 14, -16)):
                shade_of = (tips or (colour, colour, colour))[index]
                dot(0.5, (side * (1.3 + 0.12 * (1 - abs(index - 1))), 0.6, height + 0.42 - index * 0.36), shade_of,
                    scale=(1.25 - index * 0.12, 0.2, 0.44), rotation=(0, -side * RAD(up), 0), **look)
        elif kind == "flame":
            for index, (reach, up, length) in enumerate(((0.8, 1.0, 1.2), (1.2, 0.5, 1.05), (1.15, 0.0, 0.8))):
                tube(0.24, length, (side * 0.85, 0.55, height), (side * reach, 0.2, up), colour if index != 1 else (tips or colour), tip=0.0, vertices=6, emission=2)


def crystals(colour, spots, **look):
    """Shards: (x, y, z, radius, length, lean)."""
    for x, y, z, radius, length, lean in spots:
        tube(radius, length, (x, y, z), (lean, 0, 1), colour, tip=0.0, vertices=5, roughness=0.15, **look)


def crown(top=3.02, colour=GOLD, gems="FF3355", y=0.1, radius=0.34):
    tube(radius, 0.2, (0, y, top - 0.04), (0, 0, 1), colour)
    for index in range(5):
        angle = RAD(index * 72 - 90)
        x, yy = math.cos(angle) * radius * 0.86, math.sin(angle) * radius * 0.86
        tube(0.15, 0.36, (x, y + yy, top + 0.12), (0, 0, 1), colour, tip=0.0, vertices=6)
    for index in (0, 1, 4):  # the gems that can be seen from the front
        angle = RAD(index * 72 - 90)
        gem(0.09, (math.cos(angle) * radius, y + math.sin(angle) * radius, top + 0.06), gems, emission=0.5)


def halo(top=3.55, colour="FFE97A", radius=0.5, y=0.1):
    ring(radius, 0.07, (0, y, top), colour, emission=3)


def flame(x, y, z, size=1.0, lean=(0, 0, 1), outer="FF6A1F", inner="FFE56A"):
    tube(0.3 * size, 0.95 * size, (x, y, z), lean, outer, tip=0.0, vertices=7, emission=2)
    tube(0.17 * size, 0.55 * size, (x, y - 0.16 * size, z), lean, inner, tip=0.0, vertices=5, emission=4)


def sparkle(x, y, z, size=0.2, colour=WHITE):
    gem(size, (x, y, z), colour, scale=(0.35, 0.35, 1.6), emission=4)
    gem(size, (x, y, z), colour, scale=(1.6, 0.35, 0.35), emission=4)


def bands(colour, heights, depth=1.76, width=1.96, thickness=0.14, **look):
    for z, tilt in heights:
        box((width, depth, thickness), (0, 0, z), colour, rotation=(0, RAD(tilt), 0), **look)


def hoop(z, colour, minor=0.08, lift=0.0, out=0.0, **look):
    """A band round a round body at height z."""
    fit = math.sqrt(max(0.05, 1 - ((z - 1.3) / 0.945) ** 2))
    ring(1.0, minor, (0, 0, z + lift), colour, scale=((1.05 * fit + out), (0.966 * fit + out), 1), **look)  # look may hold minor_seg


def beak(colour="FF9A2E", height=1.1, front=-0.95, size=1.0):
    tube(0.26 * size, 0.5 * size, (0, front + 0.05, height), (0, -1, -0.12), colour, tip=0.0, vertices=8)


# ---------------------------------------------------------------------------------------------------
# Earth. Basic Egg: the tiers of Earth's towers.
# ---------------------------------------------------------------------------------------------------
def wooden():
    critter("855E42", "7BE07B", barrel_colour="5E3F2A", band="787C82", wheel="6B4A2B", hub="E3B06B")
    bands("5E3F2A", ((0.82, 0), (1.72, 0)), thickness=0.05)  # the gaps between its planks
    for x in (-0.8, 0.8):
        for z in (0.62, 1.0, 1.9):
            disc(0.06, (x, FRONT - 0.01, z), "3A2A1A", vertices=6)  # nails
    box((0.5, 0.06, 0.34), (0.55, FRONT - 0.01, 0.66), "A87B52")  # a mended board
    tube(0.05, 0.3, (-0.55, -0.3, 2.02), (-0.2, 0, 1), "5E3F2A", vertices=5)  # a twig still growing from it
    dot(0.2, (-0.7, -0.3, 2.36), "6FD046", scale=(1.2, 0.7, 0.4))


def iron():
    critter("787C82", "FFB01F", barrel_colour="4A4E55", band="2E3138", wheel="3A3D44", hub="B9BEC6", roughness=0.35)
    bands("4A4E55", ((0.62, 0), (1.93, 0)), thickness=0.2)
    for z in (0.62, 1.93):
        for x in (-0.75, -0.25, 0.25, 0.75):
            dot(0.07, (x, FRONT - 0.03, z), "C9CED6")  # rivets
    for side in (-1, 1):  # a bolt through its neck
        tube(0.16, 0.3, (side * 0.9, -0.1, 1.5), (side, 0, 0), "B9BEC6", vertices=6)
        tube(0.24, 0.12, (side * 1.18, -0.1, 1.5), (side, 0, 0), "4A4E55", vertices=6)


def steel():
    top = critter("B0BECC", "4FA8FF", shape="tall", barrel_colour="7E8FA3", band="E8F0F8", wheel="5C6B80", hub="E8F0F8", roughness=0.2)
    box((1.84, 0.3, 0.16), (0, -0.82, 2.32), "E8F0F8", roughness=0.2)  # the brim of a helmet
    box((0.14, 0.1, 0.5), (0, -0.84, 2.1), "E8F0F8", roughness=0.2)  # nose guard
    for side in (-1, 1):
        ball(0.42, (side * 0.86, 0.0, top - 0.2), "7E8FA3", scale=(0.7, 1.0, 0.6), seg=8, rings=4, roughness=0.2)  # shoulder plates
        dot(0.07, (side * 0.7, -0.84, 0.7), "5C6B80")
    tube(0.3, 1.0, (0, 0.95, top - 0.1), (0, 0.45, 1), "E5402D", tip=0.04, vertices=7)  # a red plume


def gold():
    critter("FFC828", "FF6A1F", shape="round", barrel_colour="E09A0A", band="FFF3B0", wheel="D9940A", hub="FFF3B0", roughness=0.2)
    wings("FFFFFF", "feather", height=1.45, tips=("FFFFFF", "FFF3B0", "FFE27A"))
    disc(0.3, (0, -0.72, 2.02), "FFF3B0", facing=(0, -0.75, 0.66), vertices=8, emission=0.5)  # a coin on its brow
    plate(star_points(0.2, 0.09), 0.04, (0, -0.74, 2.04), "E09A0A", rotation=(RAD(-40), 0, 0))
    for x, z in ((-1.25, 2.55), (1.3, 0.75), (0.95, 2.75)):
        sparkle(x, -0.5, z, 0.14)
    for index in range(3):  # a stack of coins it guards
        tube(0.3, 0.1, (-1.45, -0.55, index * 0.12), (0, 0, 1), "FFD83A" if index % 2 else "E09A0A", vertices=8)


def diamond():
    critter("50DCFF", "FF96FF", shape="facet", barrel_colour="2FA0D9", band="FFFFFF", wheel="2F6FC0", hub="E8FBFF", roughness=0.1)
    wings("C9F9FF", "crystal")
    crown(gems="FF96FF", colour="FFFFFF")
    halo(colour="FFFFFF")
    crystals("E8FBFF", ((-0.7, -0.2, 1.95, 0.2, 0.6, -0.5), (0.7, -0.2, 1.95, 0.2, 0.6, 0.5), (-1.25, -0.5, 0.0, 0.2, 0.7, -0.3), (1.25, -0.5, 0.0, 0.22, 0.85, 0.3)), emission=0.8)
    sparkle(-1.1, -0.7, 2.6, 0.16)


# Earth. Forest Egg.
def leaf():
    critter("6EBE5A", "FFE23A", shape="round", barrel_colour="8A5A2B", band="C9E86A", wheel="6B4A2B", hub="C9E86A")
    for side in (-1, 1):  # leaves for ears
        ball(0.5, (side * 0.92, 0.1, 2.25), "8FD93E", scale=(0.62, 0.2, 1.15), rotation=(0, side * RAD(28), 0), seg=8, rings=4)
        box((0.05, 0.06, 0.8), (side * 0.92, -0.02, 2.25), "4FA83A", rotation=(0, side * RAD(28), 0))
    tube(0.05, 0.35, (0.0, -0.62, 2.0), (0, -0.3, 1), "4FA83A", vertices=5)  # a sprout on its brow
    for side in (-1, 1):
        dot(0.2, (side * 0.2, -0.7, 2.38), "8FD93E", scale=(1.3, 0.6, 0.4), rotation=(0, -side * RAD(25), 0))
    dot(0.3, (0, 1.05, 0.95), "4FA83A", scale=(0.5, 1.2, 0.25))  # a leaf for a tail under the fuse


def vine():
    critter("3C8C46", "FF9BE0", barrel_colour="6B4A2B", band="8FD93E", wheel="6B4A2B", hub="8FD93E")
    bands("8FD93E", ((0.58, 0), (1.98, 7)), thickness=0.12)
    for x, y, z in ((-0.98, -0.4, 0.62), (0.98, 0.3, 0.62), (0.98, -0.5, 2.1), (-0.98, 0.2, 1.9)):
        dot(0.2, (x, y, z), "B6F07A", scale=(0.5, 1.2, 0.8))  # leaves on the vine
    for index in range(5):  # a flower
        angle = RAD(index * 72)
        dot(0.13, (0.68 + math.cos(angle) * 0.17, -0.62 + math.sin(angle) * 0.17, 2.12), "FF7AB8", scale=(1, 1, 0.5))
    dot(0.1, (0.68, -0.62, 2.17), "FFD83A")
    for side in (-1, 1):  # tendrils that curl
        for index in range(5):
            angle = RAD(index * 62)
            dot(0.09 - index * 0.008, (side * (0.72 + 0.25 * math.sin(angle) + index * 0.03), 0.3, 2.1 + 0.28 * (1 - math.cos(angle)) + index * 0.03), "8FD93E")


def mushroom():
    body("F5E9D0", "round")
    wheels("C9B48A", "FFFFFF")
    ball(1.32, (0, 0, 1.95), "D2463C", scale=(1, 1, 0.75), seg=12, rings=6, floor=0.02)  # the cap
    for turn, up in ((0, 25), (55, 40), (-60, 35), (120, 30), (-125, 30), (25, 62), (-30, 66), (180, 45)):
        a, e = RAD(turn), RAD(up)
        dot(0.2, (1.3 * math.cos(e) * math.sin(a), -1.3 * math.cos(e) * math.cos(a), 1.95 + 0.97 * math.sin(e)), WHITE)
    barrel("8A2A24", top=2.74, band="FFFFFF")
    fuse()
    face("7A4A2B", height=1.36, front=-0.93)


def honey():
    critter("F5BE3C", "7A4A1E", shape="round", barrel_colour="3A2A1A", band="FFE23A", wheel="3A2A1A", hub="FFE23A")
    for y in (-0.08, 0.3, 0.62):  # a bee's stripes
        fit = math.sqrt(1 - (y / 0.966) ** 2)
        ring(1.0, 0.1, (0, y, 1.3), "3A2A1A", rotation=(RAD(90), 0, 0), scale=(1.05 * fit, 1, 0.945 * fit), seg=12)
    for side in (-1, 1):
        tube(0.045, 0.6, (side * 0.3, -0.55, 2.02), (side * 0.35, -0.45, 1), "3A2A1A", vertices=5)  # feelers
        dot(0.11, (side * 0.47, -0.77, 2.5), "3A2A1A")
        dot(0.6, (side * 1.2, 0.35, 2.3), "DFF3FF", scale=(1.25, 0.6, 0.12), rotation=(0, -side * RAD(34), 0), roughness=0.15)  # wings
    tube(0.17, 0.42, (0, 0.88, 0.85), (0, 1, -0.25), "3A2A1A", tip=0.0, vertices=6)  # sting
    ball(0.62, (0, -0.25, 2.02), "E8930C", scale=(1.15, 0.9, 0.3), seg=8, rings=4, roughness=0.15)  # honey running down its head
    for x, z, length in ((-0.82, 1.95, 0.4), (0.86, 1.98, 0.28), (0.0, 2.0, 0.2)):
        dot(0.12, (x, -0.5 if x else -0.88, z - length / 2), "E8930C", scale=(1, 1, length / 0.24), roughness=0.15)


def jade():
    critter("3CC896", "FFE23A", barrel_colour="1F8A66", band=GOLD, wheel="1F6E55", hub=GOLD, roughness=0.15)
    box((1.98, 1.78, 0.16), (0, 0, 0.62), GOLD, roughness=0.25)
    horns(GOLD, size=1.35)
    for side in (-1, 1):  # antlers: a branch on each horn
        tube(0.09, 0.4, (side * 0.9, 0.1, 2.3), (side * 1, 0, 0.5), GOLD, tip=0.0, vertices=5)
    wings("A8FFE0", "crystal", height=1.45)
    crown(gems="FF3355")
    gem(0.16, (0, FRONT - 0.04, 2.0), "FF3355", emission=1.5)  # a ruby on its brow
    for x in (-0.55, 0.55):
        gem(0.1, (x, FRONT - 0.03, 0.62), "A8FFE0", emission=1)
    halo(colour="A8FFE0")


# ---------------------------------------------------------------------------------------------------
# Moon. Moon Egg: the tiers of the Moon's towers.
# ---------------------------------------------------------------------------------------------------
def moonrock():
    critter("AAAAB9", "7FB4FF", shape="facet", barrel_colour="7D7D8F", band="D9D7EC", wheel="6C60A8", hub="D9D7EC", roughness=0.8)
    for x, y, z, r in ((-0.8, 0.25, 1.95, 0.42), (0.85, 0.35, 1.85, 0.36), (0.9, -0.2, 0.95, 0.3), (-0.6, 0.75, 1.0, 0.4)):
        gem(r, (x, y, z), "9A9AAB", roughness=0.8)  # lumps of rock
    for x, z, r in ((-0.72, 0.85, 0.13), (0.2, 2.02, 0.12), (0.78, 1.95, 0.1)):
        disc(r, (x, -0.99 + abs(x) * 0.32 + (0.5 if z > 1.9 else 0.14), z), "7D7D8F", vertices=7)  # pock marks


def crater():
    critter("6E6E82", "FFE27A", barrel_colour="4A4A5E", band="B9B5DA", wheel="3F3F55", hub="B9B5DA", roughness=0.8)
    for side in (-1, 1):  # craters raised like ears, and one on each cheek
        tube(0.36, 0.26, (side * 0.62, -0.25, 2.0), (0, 0, 1), "8A8AA0", tip=0.25, vertices=10)
        disc(0.2, (side * 0.62, -0.25, 2.265), "3A3A4C", facing=(0, 0, 1), vertices=8)
        ring(0.33, 0.07, (side * 0.97, 0.15, 1.45), "8A8AA0", rotation=(0, RAD(90), 0), seg=10)
        disc(0.3, (side * 0.965, 0.15, 1.45), "3A3A4C", facing=(side, 0, 0), vertices=8)
    ring(0.2, 0.05, (0.62, FRONT - 0.0, 0.66), "8A8AA0", rotation=(RAD(90), 0, 0), seg=8)
    disc(0.18, (0.62, FRONT - 0.012, 0.66), "3A3A4C", vertices=8)


def lunar():
    critter("D7DCF0", "B58CFF", shape="round", barrel_colour="8FA0DA", band="FFE27A", wheel="6272B6", hub="FFE27A", roughness=0.3)
    plate(crescent_points(1.75, horn=52, dip=0.3), 0.3, (0, 0.72, 1.95), "FFE9A0", emission=0.6)  # a crescent moon at its back
    for x, z in ((-1.5, 3.2), (1.55, 3.3)):
        sparkle(x, 0.6, z, 0.12, "FFE9A0")
    disc(0.16, (0, -0.75, 2.02), "FFE9A0", facing=(0, -0.75, 0.66), vertices=8, emission=1)


def astro():
    body("5A78DC", "cube")
    box((2.14, 1.72, 1.84), (0, 0.22, 1.42), "F2F4FA", bevel=0.55, roughness=0.25)  # the helmet, open at the front
    wheels("8A93A8", "FF4D4D")
    barrel("B9BEC6", top=2.34, band="FF4D4D")
    fuse()
    face("7FD8FF", front=FRONT)
    tube(0.04, 0.7, (0.8, 0.1, 2.3), (0.2, 0, 1), "B9BEC6", vertices=5)  # aerial
    dot(0.12, (0.94, 0.1, 3.02), "FF4D4D", emission=3)
    disc(0.16, (-1.08, -0.2, 1.75), "FF4D4D", facing=(-1, 0, 0), vertices=8)
    for side in (-1, 1):  # a jet pack
        tube(0.28, 1.1, (side * 0.6, 1.15, 0.75), (0, 0, 1), "C9CED6", vertices=8)
        dot(0.28, (side * 0.6, 1.15, 1.85), "C9CED6")
        tube(0.24, 0.55, (side * 0.6, 1.15, 0.75), (0, 0.15, -1), "FF8A1F", tip=0.0, vertices=6, emission=3)


def stellar():
    critter("FAF0AA", "FF9BE0", shape="round", barrel_colour="E8C24A", band="FFFFFF", wheel="8B78D0", hub="FFE27A", roughness=0.25)
    plate(star_points(2.15, 1.05), 0.26, (0, 0.62, 1.55), "FFD83A", emission=0.7)  # a great star behind it
    crown(top=2.97, gems="7FD8FF")
    halo(top=3.5, colour="FFFFFF")
    for x, z, s in ((-1.75, 2.6, 0.16), (1.8, 2.5, 0.13), (1.3, 3.3, 0.1)):
        sparkle(x, -0.2, z, s)
    plate(star_points(0.22, 0.1), 0.05, (0, -0.76, 2.03), "FF9BE0", rotation=(RAD(-40), 0, 0), emission=1)


# Moon. Comet Egg.
def dust():
    critter("BEB9AF", "8B78D0", shape="round", barrel_colour="8E897F", band="ECE8FB", wheel="8E897F", hub="ECE8FB", roughness=0.9)
    ears("BEB9AF", "bunny", inner="E6D3D8")  # a dust bunny
    for x, y, z, r in ((-0.9, 1.0, 0.3, 0.42), (0.75, 1.15, 0.26, 0.36), (0.1, 1.5, 0.2, 0.28), (-1.5, 0.3, 0.2, 0.26), (1.5, 0.5, 0.22, 0.3)):
        dot(r, (x, y, z), "D8D4CC", roughness=0.9)  # the cloud it kicks up
    for x, z in ((-0.55, 2.02), (0.5, 2.05)):
        dot(0.2, (x, -0.42, z), "D8D4CC", roughness=0.9)
    dot(0.24, (0, 0.95, 1.0), "E8E5DE", roughness=0.9)  # a bob tail


def comet():
    critter("96D2FF", "FFFFFF", shape="round", barrel_colour="5CA0E0", band="E8F8FF", wheel="3F6FC0", hub="E8F8FF", roughness=0.2)
    for x, z, r, length, tint in ((-0.62, 1.55, 0.42, 1.5, "BFE8FF"), (0.62, 1.55, 0.42, 1.5, "BFE8FF"), (0, 0.85, 0.36, 1.2, "E8F8FF"), (-0.3, 2.0, 0.2, 0.9, "FFFFFF"), (0.3, 2.0, 0.2, 0.9, "FFFFFF")):
        tube(r, length, (x, 0.45, z), (x * 0.25, 1, 0.22), tint, tip=0.0, vertices=7, emission=0.6)  # its tail streams out behind
    for x, z in ((-1.2, 2.3), (1.25, 1.0)):
        sparkle(x, -0.3, z, 0.13)
    crystals("E8F8FF", ((-0.5, -0.35, 2.0, 0.14, 0.4, -0.4), (0.5, -0.35, 2.0, 0.14, 0.4, 0.4)), emission=0.6)


def meteor():
    critter("826459", "FFB01F", mood="fierce", shape="round", barrel_colour="4A352E", band="FF8A1F", wheel="3A2A26", hub="FF8A1F", roughness=0.85)
    for x, y, z, r in ((-0.85, 0.2, 1.9, 0.36), (0.9, -0.1, 1.0, 0.28), (0.8, 0.5, 1.9, 0.3)):
        gem(r, (x, y, z), "6A5048", roughness=0.85)
    for x, z, r in ((-0.74, 0.86, 0.15), (0.74, 0.8, 0.11), (0.0, 2.08, 0.1)):
        disc(r, (x, -0.95 + abs(x) * 0.3 + (0.55 if z > 2 else 0.1), z), "FF6A1F", vertices=7, emission=3)  # glowing pits
    for x, z, s in ((-0.7, 1.5, 1.0), (0.7, 1.5, 1.0), (0, 0.9, 0.9)):
        flame(x, 0.7, z, s, lean=(x * 0.3, 1, 0.45))  # it is still burning up


def star():
    # Its body is the star: two points for ears, one each side over the wheels, one for a chin.
    plate(star_points(1.62, 1.0, turn=-90), 1.5, (0, 0, 1.6), "FFEB82", roughness=0.3)
    ball(0.95, (0, 0, 1.55), "FFEB82", scale=(1, 0.86, 1), roughness=0.3)
    wheels("C89A2A", "FFFFFF", spread=0.95)
    barrel("E0A82A", top=2.4, band="FFFFFF")
    fuse(spark="FFFFFF")
    face("FF7AB8", height=1.6, front=-0.82)
    for x, z in ((-1.6, 2.9), (1.65, 2.2)):
        sparkle(x, -0.4, z, 0.13)


def galaxy():
    critter("6E50D2", "FFE27A", shape="round", barrel_colour="3A2A8A", band="FF9BE0", wheel="2A1F66", hub="7FD8FF", roughness=0.3)
    ring(1.55, 0.08, (0, 0, 1.3), "FF9BE0", rotation=(RAD(24), RAD(14), 0), seg=16, minor_seg=3, emission=1.5)  # the arms of a galaxy
    ring(1.9, 0.06, (0, 0, 1.3), "7FD8FF", rotation=(RAD(20), RAD(-20), 0), seg=16, minor_seg=3, emission=1.5)
    for angle, r, tint in ((20, 1.55, "FFE27A"), (150, 1.55, WHITE), (250, 1.9, "FF9BE0"), (330, 1.9, "FFE27A")):
        dot(0.15, (r * math.cos(RAD(angle)), r * math.sin(RAD(angle)), 1.3 + r * (0.42 * math.sin(RAD(angle)) + (-0.24 if r < 1.6 else 0.34) * math.cos(RAD(angle)))), tint, emission=3)
    crown(top=2.97, colour="FFE27A", gems="7FD8FF")
    for x, z, r in ((-0.6, 0.9, 0.05), (0.75, 1.0, 0.04), (0.1, 2.05, 0.05), (-0.85, 1.85, 0.04)):
        disc(r, (x, -0.99 + abs(x) * 0.3 + (0.5 if z > 2 else 0.12), z), WHITE, vertices=5, emission=3)  # stars in it
    halo(top=3.5, colour="FF9BE0")


# ---------------------------------------------------------------------------------------------------
# Mars. Mars Egg: the tiers of Mars's towers.
# ---------------------------------------------------------------------------------------------------
def rust():
    critter("B45A32", "35D6C4", barrel_colour="7A3A22", band="5E2A1A", wheel="4A2A20", hub="D98A4A", roughness=0.9)
    box((0.62, 0.06, 0.46), (-0.58, FRONT - 0.01, 0.7), "8A4A2C")  # plates patched over the holes
    box((0.5, 0.5, 0.06), (0.6, -0.5, 2.06), "D98A4A")
    for x, z in ((-0.82, 0.86), (-0.34, 0.86), (-0.82, 0.54), (-0.34, 0.54)):
        dot(0.05, (x, FRONT - 0.04, z), "E8C0A0")
    tube(0.15, 1.2, (1.08, 0.45, 1.1), (0, 0, 1), "7A3A22", vertices=7)  # an exhaust pipe
    tube(0.2, 0.14, (1.08, 0.45, 2.24), (0, 0, 1), "4A2A20", vertices=7)
    dot(0.2, (1.1, 0.5, 2.62), "9A8F8A", roughness=0.9)
    for x, y, z in ((-0.97, 0.3, 1.5), (0.4, FRONT - 0.0, 1.98), (-0.97, -0.3, 0.9)):
        dot(0.16, (x, y, z), "7A3A22", scale=(0.4, 1, 1) if abs(x) > 0.9 else (1, 0.3, 1.4))  # rust runs


def dune():
    critter("E1B978", "8A5A2B", shape="round", barrel_colour="B8894A", band="FFE9C4", wheel="9E6B3A", hub="FFE9C4", roughness=0.9)
    ball(1.7, (0, 0.1, 0.0), "F0D9A0", scale=(1, 0.95, 0.24), seg=12, rings=4, floor=0.0, roughness=0.9)  # the dune it sits in
    hoop(0.66, "CFA05E", minor=0.06)
    hoop(1.9, "CFA05E", minor=0.05)
    for side in (-1, 1):  # crests the wind has curled
        tube(0.36, 0.55, (side * 0.55, -0.2, 2.0), (side * 0.7, 0, 1), "F0D9A0", tip=0.0, vertices=7)
    ring(1.9, 0.04, (0, 0.1, 0.1), "CFA05E", scale=(1, 0.95, 1), seg=14)


def martian():
    critter("5ABE6E", "FF5AF0", shape="round", barrel_colour="9AA6C0", band="FF5AF0", wheel="3A7A4A", hub="FF9BE0")
    ball(1.55, (0, 0, 0.72), "C8CDD2", scale=(1, 0.95, 0.13), seg=14, rings=4, roughness=0.25)  # the rim of its saucer
    for turn in range(-60, 61, 30):
        dot(0.09, (1.5 * math.sin(RAD(turn)), -1.43 * math.cos(RAD(turn)), 0.74), "FFE27A", emission=4)
    for side in (-1, 1):
        tube(0.05, 0.6, (side * 0.45, -0.35, 2.05), (side * 0.4, -0.1, 1), "3A7A4A", vertices=5)  # feelers
        dot(0.14, (side * 0.68, -0.41, 2.62), "FF5AF0", emission=3)
    eye(0, 2.02, "FF5AF0", size=0.42, front=-0.74)  # a third eye


def rover():
    box((1.9, 1.9, 1.15), (0, 0, 1.3), "C8CDD2", bevel=0.25, roughness=0.3)
    for side in (-1, 1):
        for y in (-0.7, 0.0, 0.7):  # six wheels
            tube(0.42, 0.28, (side * 0.95, y, 0.42), (side, 0, 0), "3A3D44", vertices=8)
            disc(0.16, (side * 1.235, y, 0.42), "FF8A1F", facing=(side, 0, 0), vertices=6)
        # solar panels for wings
        box((1.3, 1.0, 0.07), (side * 1.55, 0.2, 2.0), "2F5FD0", rotation=(0, -side * RAD(18), 0), roughness=0.2)
        box((0.04, 1.02, 0.09), (side * 1.55, 0.2, 2.0), "BFD4FF", rotation=(0, -side * RAD(18), 0))
        box((1.32, 0.04, 0.09), (side * 1.55, 0.2, 2.0), "BFD4FF", rotation=(0, -side * RAD(18), 0))
    box((1.94, 0.3, 0.2), (0, -0.82, 0.86), "FFC61A")  # gold foil
    barrel("8A93A8", top=1.88, band="FF8A1F")
    fuse(height=1.2)
    face("35D6C4", height=1.38, front=-0.96)
    tube(0.05, 0.9, (0.7, 0.6, 1.85), (0, 0, 1), "8A93A8", vertices=5)  # a dish on a mast
    tube(0.34, 0.22, (0.7, 0.6, 2.95), (0.3, -0.6, -1), "F2F4FA", tip=0.04, vertices=8)
    tube(0.06, 0.55, (-0.7, -0.6, 1.85), (0, 0, 1), "8A93A8", vertices=5)  # a camera on a mast
    box((0.34, 0.3, 0.24), (-0.7, -0.62, 2.5), "3A3D44")
    disc(0.09, (-0.7, -0.775, 2.5), "35D6C4", vertices=6, emission=3)


def warlord():
    critter("BE2828", "FFE23A", mood="fierce", barrel_colour="3A2A2A", band=GOLD, wheel="2A1A1A", hub=GOLD, brow="2A0A0A")
    box((2.02, 1.82, 0.36), (0, 0, 1.99), "3A2A2A", bevel=0.1, roughness=0.3)  # a helmet
    box((0.16, 0.12, 0.62), (0, FRONT - 0.07, 1.72), "3A2A2A")
    horns("FFF3D6", top=2.15, spread=0.85, size=1.6)
    for side in (-1, 1):
        tube(0.26, 0.5, (side * 0.9, 0.0, 1.35), (side, 0, 0.35), "3A2A2A", tip=0.0, vertices=6)  # shoulder spikes
        flame(side * 0.75, 0.75, 1.9, 0.75, lean=(side * 0.3, 0.3, 1))
    box((2.1, 0.12, 1.3), (0, 0.9, 1.25), "7A1010")  # cape
    tube(0.06, 3.3, (1.3, 0.75, 0.3), (0, 0, 1), WOOD, vertices=5)  # war banner
    box((0.95, 0.06, 0.8), (1.82, 0.75, 3.1), "E5402D")
    plate(star_points(0.26, 0.11), 0.09, (1.82, 0.75, 3.1), GOLD)
    crown(top=3.02, gems="FF3355")
    box((0.5, 0.05, 0.08), (0.5, FRONT - 0.02, 1.02), "5E0A0A", rotation=(0, RAD(35), 0))  # a scar


# Mars. Dune Egg.
def sand():
    critter("DCBE8C", "35D6C4", barrel_colour="B8946A", band="FFF3D6", wheel="B8946A", hub="FFF3D6", roughness=0.9)
    for x in (-0.74, 0.74):  # a sandcastle's battlements
        for y in (-0.64, 0.0, 0.64):
            box((0.42, 0.42, 0.4), (x, y, 2.2), "E8D0A4", roughness=0.9)
    box((0.42, 0.06, 0.6), (0.0, FRONT - 0.01, 0.42 + 0.18), "9E7B4E")  # the gate
    ball(0.21, (0.0, FRONT - 0.01, 0.9), "9E7B4E", scale=(1, 0.14, 1), seg=8, rings=4)
    tube(0.035, 0.75, (-0.74, -0.64, 2.4), (0, 0, 1), WOOD, vertices=5)
    plate([(0, 0.16), (0, -0.16), (0.46, 0)], 0.04, (-0.72, -0.64, 2.98), "FF4D4D")  # a flag
    dot(0.17, (0.72, FRONT - 0.03, 0.62), "FF9BC0", scale=(1, 0.4, 0.9))  # a shell pressed into it
    ball(1.5, (0, 0.1, 0.0), "F0D9A0", scale=(1, 0.95, 0.14), seg=12, rings=4, floor=0.0, roughness=0.9)


def cactus():
    critter("46A050", "FFE23A", shape="tall", barrel_colour="2F7A3A", band="FF7AB8", wheel="B8643A", hub="F2C9A0")
    for side, low, high in ((-1, 1.25, 0.95), (1, 1.65, 0.7)):  # arms
        tube(0.27, 0.55, (side * 0.8, 0.1, low), (side, 0, 0), "46A050", vertices=8)
        ball(0.27, (side * 1.35, 0.1, low), "46A050", seg=8, rings=4)
        tube(0.27, high, (side * 1.35, 0.1, low), (0, 0, 1), "46A050", vertices=8)
        ball(0.27, (side * 1.35, 0.1, low + high), "46A050", seg=8, rings=4)
        for z in (0.25, 0.6):
            tube(0.03, 0.2, (side * 1.6, 0.1, low + high * z + 0.1), (side, 0, 0.2), "FFF3D6", tip=0.0, vertices=4)
    for x in (-0.6, 0.6):
        box((0.06, 1.62, 1.6), (x, 0, 1.5), "2F7A3A")  # ribs
    for x, z in ((-0.86, 0.9), (0.86, 2.2), (-0.86, 2.1), (0.86, 1.1)):
        tube(0.03, 0.22, (x, -0.2, z), (x, 0, 0.2), "FFF3D6", tip=0.0, vertices=4)  # spines
    for index in range(5):  # a flower
        angle = RAD(index * 72)
        dot(0.15, (-0.55 + math.cos(angle) * 0.2, -0.5 + math.sin(angle) * 0.2, 2.52), "FF7AB8", scale=(1, 1, 0.5))
    dot(0.12, (-0.55, -0.5, 2.58), "FFD83A")


def scorpion():
    body("8C3C1E", "round")
    wheels("3A1A10", "FFB45A")
    barrel("5E2412", top=2.0, band="FFB45A")
    face("FFE23A", mood="fierce", brow="3A1A10", front=-0.93)
    # Its tail curls over its back; the sting is where a fuse's spark would be.
    tail = ((0, 0.95, 1.1, 0.34), (0, 1.38, 1.55, 0.31), (0, 1.62, 2.15, 0.28), (0, 1.55, 2.78, 0.25), (0, 1.2, 3.25, 0.22))
    for x, y, z, r in tail:
        ball(r, (x, y, z), "A84A26", seg=8, rings=4)
    tube(0.2, 0.55, (0, 1.1, 3.35), (0, -1, -0.25), "3A1A10", tip=0.0, vertices=6)
    dot(0.13, (0, 0.52, 3.2), SPARK, emission=5)
    for side in (-1, 1):  # claws
        tube(0.16, 0.75, (side * 0.85, -0.45, 0.95), (side * 0.55, -1, 0.1), "A84A26", vertices=6)
        ball(0.34, (side * 1.28, -1.2, 1.03), "A84A26", scale=(0.9, 1.1, 0.8), seg=8, rings=4)
        tube(0.2, 0.55, (side * 1.4, -1.35, 1.1), (side * 0.25, -1, 0.1), "8C3C1E", tip=0.0, vertices=6)
        tube(0.15, 0.45, (side * 1.12, -1.38, 0.98), (-side * 0.1, -1, 0), "8C3C1E", tip=0.0, vertices=6)


def pharaoh():
    critter("FAD250", "35D6C4", barrel_colour="2F5FD0", band=GOLD, wheel="2F5FD0", hub=GOLD, roughness=0.25)
    box((2.04, 1.84, 0.32), (0, 0, 2.0), "2F5FD0", bevel=0.08)  # the striped head cloth
    box((2.06, 1.86, 0.08), (0, 0, 2.0), GOLD)
    for side in (-1, 1):
        box((0.36, 1.5, 1.3), (side * 1.08, 0.12, 1.5), "2F5FD0", bevel=0.1)
        for z in (1.1, 1.5, 1.9):
            box((0.4, 1.54, 0.1), (side * 1.08, 0.12, z), GOLD)
        box((0.42, 0.06, 0.07), (side * 0.98, FRONT - 0.03, 1.5), INK)  # painted eyes
    tube(0.1, 0.42, (0, FRONT - 0.02, 2.0), (0, -0.3, 1), GOLD, vertices=6)  # the cobra on its brow
    gem(0.15, (0, FRONT - 0.2, 2.45), GOLD, scale=(1.2, 0.6, 1.2))
    dot(0.05, (0, FRONT - 0.3, 2.47), "FF3355", emission=2)
    box((0.22, 0.2, 0.5), (0, FRONT - 0.06, 0.42), "2F5FD0", bevel=0.06)  # its beard
    box((0.24, 0.22, 0.08), (0, FRONT - 0.06, 0.42), GOLD)


def sandstorm():
    lift = 0.95
    critter("C8965A", "FFE23A", mood="fierce", shape="round", barrel_colour="7A5A36", band=GOLD, lift=lift, rolls=False, brow="5E4426")
    # No wheels: it rides a whirlwind.
    tube(0.16, 1.45, (0, 0, 0.02), (0, 0, 1), "E8C99A", tip=1.0, vertices=10, roughness=0.9)
    for z, r, tilt in ((0.35, 0.5, 12), (0.8, 0.78, -10), (1.25, 1.05, 8)):
        ring(r, 0.07, (0, 0, z), "FFF0D0", rotation=(RAD(tilt), RAD(-tilt), 0), seg=10, minor_seg=3)
    ring(1.7, 0.07, (0, 0, 1.3 + lift), "F0D9A0", rotation=(RAD(10), RAD(-14), 0), seg=14, minor_seg=3)  # sand flying round it
    for angle, tint in ((30, "9E6B3A"), (120, "7A5A36"), (215, "9E6B3A"), (300, "E8C99A")):
        gem(0.2, (1.7 * math.cos(RAD(angle)), 1.7 * math.sin(RAD(angle)), 1.3 + lift + 0.35 * math.cos(RAD(angle))), tint)
    crown(top=2.97 + lift, gems="35D6C4")
    for side in (-1, 1):
        plate(scaled(BOLT, 0.55), 0.08, (side * 1.25, -0.5, 0.75), "FFE23A", rotation=(0, side * RAD(20), 0), emission=4)  # lightning in the storm


# ---------------------------------------------------------------------------------------------------
# Neptune. Frost Egg: the tiers of Neptune's towers.
# ---------------------------------------------------------------------------------------------------
def frost():
    critter("AADCFF", "4FA8E8", barrel_colour="6FA8E0", band=WHITE, wheel="4A7FD0", hub="E8FAFF", roughness=0.25)
    box((2.02, 1.82, 0.36), (0, 0, 1.98), WHITE, bevel=0.16)  # a cap of rime
    for x, length in ((-0.82, 0.42), (-0.25, 0.2), (0.2, 0.3), (0.84, 0.5)):
        dot(0.13, (x, FRONT - 0.03, 1.84 - length / 2), WHITE, scale=(1, 0.6, length / 0.2))
    for side in (-1, 1):
        dot(0.13, (side * 0.97, 0.3, 1.7), WHITE, scale=(0.6, 1, 2.2))
    for x, z in ((-1.2, 2.4), (1.25, 1.2)):
        sparkle(x, -0.4, z, 0.11)
    for x, z in ((-0.75, 0.62), (0.72, 0.58)):
        plate(star_points(0.16, 0.05, points=6), 0.03, (x, FRONT - 0.02, z), WHITE)  # frost flowers


def glacier():
    box((1.75, 1.6, 2.0), (0, 0, 1.45), "5AA0EB", bevel=0.12, roughness=0.2)  # a block of old ice, hard edged
    box((1.4, 1.3, 0.34), (0.12, 0.05, 2.6), "BFE3FF", bevel=0.08, roughness=0.2)
    box((0.8, 0.9, 0.3), (-0.3, 0.1, 2.9), "E8F7FF", bevel=0.08, roughness=0.2)
    wheels("2F5FA8", "BFE3FF")
    barrel("2F6FC0", top=3.02, band="BFE3FF")
    fuse()
    face("E8FAFF", height=1.6, front=-0.82)
    gem(0.5, (-0.95, 0.2, 2.2), "8FC4F5", scale=(0.7, 1, 1.3), roughness=0.2)  # a slab calving off its shoulder
    for x, z, lean in ((0.55, 0.85, 30), (0.68, 0.62, -25), (0.5, 0.45, 35)):
        box((0.05, 0.05, 0.34), (x, -0.81, z), "E8F7FF", rotation=(0, RAD(lean), 0))  # a crack


def crystal():
    critter("78F0F5", "B58CFF", barrel_colour="3FB8C8", band="E8FFFF", wheel="2F8FA8", hub="E8FFFF", roughness=0.15)
    crystals("C8FBFF", ((-0.8, -0.45, 1.9, 0.22, 0.75, -0.5), (-0.85, 0.1, 1.9, 0.26, 1.0, -0.3), (-0.8, 0.6, 1.9, 0.2, 0.7, -0.6),
                        (0.8, -0.45, 1.9, 0.22, 0.75, 0.5), (0.85, 0.1, 1.9, 0.26, 1.0, 0.3), (0.8, 0.6, 1.9, 0.2, 0.7, 0.6)), emission=0.5)
    crystals("B58CFF", ((-1.0, 0.75, 0.9, 0.22, 0.9, -1.4), (1.0, 0.75, 0.9, 0.22, 0.9, 1.4), (-0.95, -0.2, 1.3, 0.16, 0.55, -2.5), (0.95, -0.2, 1.3, 0.16, 0.55, 2.5)), emission=0.8)
    gem(0.2, (0, FRONT - 0.02, 2.0), "B58CFF", scale=(0.8, 0.5, 1.2), emission=1)


def blizzard():
    critter("EBF5FF", "4FA8E8", shape="round", barrel_colour="8FB8E8", band=WHITE, wheel="5C90E0", hub=WHITE)
    for turn in (0, 60, 120):  # a great snowflake behind it
        box((0.16, 0.12, 3.5), (0, 0.85, 1.75), "BFE9FF", rotation=(0, RAD(turn), 0), emission=0.5)
        for end in (-1, 1):
            for fork in (-1, 1):
                at = Vector((math.sin(RAD(turn)), 0, math.cos(RAD(turn)))) * end * 1.3
                box((0.1, 0.1, 0.5), (at.x, 0.85, 1.75 + at.z), "BFE9FF", rotation=(0, RAD(turn + fork * 50 + (0 if end > 0 else 180)), 0), emission=0.5)
    hoop(0.8, "3264C8", minor=0.14, out=0.04)  # scarf
    box((0.3, 0.1, 0.7), (0.85, -0.62, 0.5), "3264C8", rotation=(0, RAD(-18), RAD(30)))
    for x, y, z in ((-1.35, -0.4, 2.3), (1.4, -0.2, 2.0), (-1.3, -0.5, 0.9), (0.4, -0.9, 2.6)):
        dot(0.1, (x, y, z), WHITE)  # snow in the air


def aurora():
    critter("78FFC8", "FF9BE0", shape="round", barrel_colour="2A3F8A", band="B58CFF", wheel="2A3F8A", hub="78FFC8", roughness=0.2)
    for side in (-1, 1):  # curtains of the northern lights for wings
        for index, tint in enumerate(("78FFC8", "6EE6FF", "B58CFF", "FF9BE0")):
            lean = side * RAD(12 + index * 13)
            box((0.36, 0.07, 1.9 - index * 0.25), (side * (0.9 + index * 0.3), 0.6 + index * 0.06, 2.15 - index * 0.1), tint, rotation=(0, lean, 0), emission=1.2)
    crown(top=2.97, colour="E8FAFF", gems="FF9BE0")
    halo(top=3.5, colour="78FFC8")
    for x, z in ((-0.7, 0.85), (0.72, 0.95), (0.0, 2.05)):
        disc(0.05, (x, -0.99 + abs(x) * 0.3 + (0.5 if z > 2 else 0.12), z), WHITE, vertices=5, emission=3)
    sparkle(-1.6, -0.5, 3.1, 0.13)
    sparkle(1.7, -0.5, 2.9, 0.1)


# Neptune. Blizzard Egg.
def snow():
    critter("F0F8FF", "5C90E0", shape="round", barrel_colour="3A3F55", band="FF4D4D", wheel="5C90E0", hub=WHITE, faced=False)
    eyes(1.5, iris="5C90E0", front=-0.93)
    blush(1.07, front=-0.93)
    tube(0.15, 0.6, (0, -0.9, 1.12), (0, -1, -0.08), "FF8A1F", tip=0.0, vertices=7)  # a carrot nose
    for index in range(5):  # a mouth of coal
        x = -0.3 + index * 0.15
        dot(0.055, (x, -0.99 + abs(x) * 0.1, 0.84 - 0.1 * math.cos(x * 5)), INK)
    for side in (-1, 1):  # twig arms
        tube(0.05, 0.9, (side * 0.95, 0.0, 1.35), (side, 0, 0.7), WOOD, vertices=5)
        tube(0.04, 0.3, (side * 1.5, 0.0, 1.74), (side * 0.2, 0, 1), WOOD, vertices=5)
        tube(0.04, 0.28, (side * 1.42, 0.0, 1.68), (side, 0, -0.1), WOOD, vertices=5)
    dot(0.3, (-0.6, -0.3, 2.1), WHITE)  # a snowball someone left on its head
    ball(1.5, (0, 0.1, 0.0), WHITE, scale=(1, 0.95, 0.12), seg=12, rings=4, floor=0.0)


def icicle():
    critter("96D7FF", "3264C8", barrel_colour="5CA8E8", band="E8FAFF", wheel="4A7FD0", hub="E8FAFF", roughness=0.2)
    box((2.6, 1.95, 0.22), (0, 0, 2.02), "C4ECFF", bevel=0.08, roughness=0.2)  # eaves of ice, with icicles hanging
    for side in (-1, 1):
        for y, length in ((-0.7, 0.75), (-0.2, 1.05), (0.3, 0.6), (0.75, 0.9)):
            tube(0.13, length, (side * 1.14, y, 1.92), (0, 0, -1), "D0F4FF", tip=0.0, vertices=6, roughness=0.15, emission=0.3)
    for x, length in ((-0.95, 0.3), (0.0, 0.22), (0.95, 0.34)):
        tube(0.09, length, (x, -0.9, 1.92), (0, 0, -1), "D0F4FF", tip=0.0, vertices=5, roughness=0.15)
    for side in (-1, 1):  # and two that grew upwards
        tube(0.3, 1.25, (side * 0.85, 0.1, 2.1), (side * 0.18, 0, 1), "D0F4FF", tip=0.0, vertices=6, roughness=0.15, emission=0.3)
        tube(0.18, 0.6, (side * 0.75, -0.5, 2.1), (side * 0.3, -0.1, 1), "E8FAFF", tip=0.0, vertices=5, roughness=0.15)


def penguin():
    critter("282D3C", "3FBDF5", shape="round", barrel_colour="3A4055", band="FF9A2E", wheel="1A1E2A", hub="FF9A2E", faced=False)
    ball(0.86, (0, -0.42, 1.22), WHITE, scale=(0.95, 0.66, 1.0), seg=10, rings=5)  # its white front
    eyes(1.5, spread=0.4, iris="3FBDF5", size=0.72, front=-0.9)
    blush(1.1, spread=0.72, front=-0.93)
    beak(height=1.1, front=-0.98, size=0.85)
    for side in (-1, 1):
        ball(0.5, (side * 1.08, 0.0, 1.25), "282D3C", scale=(0.22, 0.6, 1.0), rotation=(0, side * RAD(-22), 0), seg=8, rings=4)  # flippers
        dot(0.3, (side * 0.42, -0.9, 0.1), "FF9A2E", scale=(0.9, 1.3, 0.3))  # feet
    for x in (-0.14, 0.14):
        tube(0.1, 0.34, (x, -0.3, 1.98), (x * 2, -0.2, 1), "282D3C", tip=0.0, vertices=5)  # a tuft
    for side in (-1, 1):  # a bow tie
        tube(0.16, 0.22, (0, -1.0, 0.72), (side, 0, 0), "FF4D4D", tip=0.02, vertices=6)


def yeti():
    top = critter("E1EBF5", "6EE6FF", mood="fierce", shape="tall", barrel_colour="8FA8C8", band="6EE6FF", wheel="5C7FB0", hub="D0F8FF", brow="5C7FB0")
    box((1.36, 0.1, 1.5), (0, -0.78, 1.5), "A8C8E8", bevel=0.04)  # its bare blue face
    horns("5C7FB0", top=top + 0.05, spread=0.7, size=1.5)
    for x, y, z, lean in ((-0.35, -0.45, top, -0.3), (0.35, -0.45, top, 0.3), (0.0, -0.6, top, 0.0),
                          (-0.86, -0.3, 1.9, -1.5), (0.86, -0.3, 1.9, 1.5), (-0.86, -0.2, 1.2, -2.0), (0.86, -0.2, 1.2, 2.0)):
        tube(0.2, 0.42, (x, y, z - 0.08), (lean, -0.2, 1), WHITE, tip=0.0, vertices=5)  # tufts of fur
    for side in (-1, 1):  # big fists
        ball(0.42, (side * 1.28, -0.35, 0.95), "E1EBF5", seg=8, rings=4)
        disc(0.22, (side * 1.28, -0.78, 0.95), "A8C8E8", vertices=8)


def polar():
    critter("78BEFA", "FFFFFF", shape="round", barrel_colour="3F7FD0", band="E8FAFF", wheel="2F5FA8", hub="E8FAFF", faced=False)
    ears("78BEFA", "round", inner=WHITE, top=2.05)  # a polar bear, in the colours of the pole's sky
    eyes(1.52, iris="FFFFFF", front=-0.93)
    blush(1.09, front=-0.93)
    ball(0.42, (0, -0.86, 1.0), WHITE, scale=(1.1, 0.6, 0.78), seg=8, rings=4)  # muzzle
    dot(0.12, (0, -1.12, 1.1), INK, scale=(1.2, 0.6, 0.8))
    box((0.2, 0.06, 0.05), (0, -1.1, 0.88), INK)
    wings("C8F0FF", "crystal", height=1.45)
    crown(top=2.97, colour="E8FAFF", gems="3264C8")
    plate(star_points(0.34, 0.12, points=4), 0.06, (0, 0.1, 3.75), "FFF7C0", emission=4)  # the pole star over its crown
    halo(top=3.75, colour="C8F0FF", radius=0.55)
    crystals("E8FAFF", ((-1.2, -0.6, 0.0, 0.2, 0.7, -0.3), (1.25, -0.5, 0.0, 0.22, 0.9, 0.3)), emission=0.6)


# ---------------------------------------------------------------------------------------------------
# The Sun. Ember Egg: the tiers of the Sun's towers.
# ---------------------------------------------------------------------------------------------------
def ember():
    critter("FF8C3C", "FFE56A", shape="round", barrel_colour="5E2A2C", band="FFC83C", wheel="3F2632", hub="FF8A1F", emission=0.3)
    for x, y, z, r in ((-0.85, 0.2, 1.8, 0.4), (0.9, 0.0, 1.0, 0.36), (0.65, 0.5, 1.9, 0.36), (-0.8, -0.3, 0.8, 0.3), (0.7, -0.55, 1.95, 0.24)):
        gem(r, (x, y, z), "3F2632", scale=(1, 1, 0.8), roughness=0.9)  # the coal it is burning out of
    flame(-0.5, -0.4, 1.95, 1.0)
    flame(-0.85, -0.1, 1.7, 0.6, lean=(-0.5, 0, 1))
    for x, y, z in ((-1.2, -0.3, 2.5), (1.2, -0.4, 2.1), (0.5, -0.6, 2.6)):
        dot(0.06, (x, y, z), "FFE56A", emission=5)  # sparks


def magma():
    critter("E6501E", "FFE56A", barrel_colour="33202E", band="FF8A1F", wheel="33202E", hub="FF5A1A", emission=0.4)
    box((2.04, 1.84, 0.42), (0, 0, 1.95), "3F2632", bevel=0.12, roughness=0.9)  # a crust of cooled rock
    box((2.02, 1.82, 0.26), (0, 0, 0.56), "3F2632", bevel=0.1, roughness=0.9)
    for x, length in ((-0.8, 0.5), (-0.3, 0.24), (0.3, 0.3), (0.82, 0.42)):
        dot(0.12, (x, FRONT - 0.04, 1.8 - length / 2), "FFD23A", scale=(1, 0.6, length / 0.2), emission=3)  # it runs out underneath
    for side in (-1, 1):
        gem(0.3, (side * 0.8, 0.3, 2.2), "5A3542", roughness=0.9)
        dot(0.12, (side * 0.98, -0.3, 1.6), "FFD23A", scale=(0.6, 1, 2.6), emission=3)
    for x, y in ((-0.5, -0.4), (0.55, -0.55)):
        disc(0.12, (x, y, 2.165), "FFD23A", facing=(0, 0, 1), vertices=6, emission=3)


def obsidian():
    critter("2D2337", "B58CFF", shape="facet", barrel_colour="16101E", band="8E6BFF", wheel="16101E", hub="8E6BFF", roughness=0.08)
    for x, y, z, r, length, lean in ((-0.7, 0.0, 1.9, 0.26, 1.0, -0.5), (0.7, 0.0, 1.9, 0.26, 1.0, 0.5), (-0.95, 0.4, 1.4, 0.22, 0.8, -1.6),
                                     (0.95, 0.4, 1.4, 0.22, 0.8, 1.6), (-0.45, -0.5, 1.95, 0.16, 0.5, -0.3), (0.45, -0.5, 1.95, 0.16, 0.5, 0.3)):
        tube(r, length, (x, y, z), (lean, 0, 1), "3D3050", tip=0.0, vertices=4, roughness=0.08)  # shards of black glass
    for x, z in ((-0.95, 2.75), (0.95, 2.75), (-1.45, 1.95)):
        sparkle(x, -0.1, z, 0.1, "B58CFF")
    box((0.06, 0.05, 0.5), (0.72, -0.84, 0.9), "8E6BFF", rotation=(0, RAD(30), 0), emission=3)  # a glowing edge where it chipped


def inferno():
    critter("FF3C14", "FFE56A", mood="fierce", barrel_colour="33202E", band="FFC83C", wheel="33202E", hub="FFC83C", brow="5E0A0A", emission=0.3)
    horns("33202E", size=1.3)
    wings("FF6A1F", "flame", tips="FFD23A")
    for x, y, s in ((-0.45, -0.35, 0.7), (0.45, -0.35, 0.7), (-0.75, 0.55, 0.9), (0.75, 0.55, 0.9)):
        flame(x, y, 2.0, s)  # it is on fire
    flame(0, 1.0, 0.9, 1.0, lean=(0, 0.8, 1))
    for side in (-1, 1):
        dot(0.1, (side * 0.98, -0.3, 0.9), "FFD23A", scale=(0.5, 1, 2.4), emission=3)


def solar():
    critter("FFD750", "FF6A1F", shape="round", barrel_colour="E89A1A", band=WHITE, wheel="D9461A", hub="FFE56A", roughness=0.25, emission=0.3)
    for index in range(11):  # the sun's rays, all round it
        angle = RAD(-25 + index * 23)
        long = index % 2 == 0
        tube(0.26, 0.95 if long else 0.6, (0.9 * math.cos(angle), 0.4, 1.3 + 0.82 * math.sin(angle)), (math.cos(angle), 0, math.sin(angle)),
             "FFB52E" if long else "FFE56A", tip=0.0, vertices=6, emission=2)
    crown(top=2.97, gems="FF4D4D")
    halo(top=3.5, colour="FFF0A8", radius=0.56)


# The Sun. Solar Egg.
def spark():
    critter("FFE678", "4FA8FF", barrel_colour="C89A2A", band=WHITE, wheel="5C3848", hub="FFE56A", emission=0.2)
    for side in (-1, 1):  # bolts for ears
        plate(scaled(BOLT, 0.62), 0.14, (side * 0.72, 0.05, 2.55), "FFF7A0", rotation=(0, side * RAD(22), 0), emission=4)
    for x, y, z, s in ((-1.3, -0.5, 1.9, 0.14), (1.35, -0.4, 1.2, 0.12), (1.1, -0.6, 2.5, 0.1), (0, 1.5, 2.3, 0.2)):
        sparkle(x, y, z, s, "FFF7A0")
    plate(scaled(BOLT, 0.26), 0.04, (0.6, FRONT - 0.02, 0.68), "FF8A1F", rotation=(0, RAD(15), 0))  # its mark


def flame_mini():
    body("FF7828", "round", emission=0.3)
    ball(0.8, (0, -0.32, 1.12), "FFD23A", scale=(0.95, 0.68, 0.95), seg=10, rings=5, emission=0.6)  # its bright heart
    wheels("8A3A2C", "FFE56A")
    barrel("C8401A", top=2.0, band="FFE56A")
    fuse()
    face("FF3C14", height=1.5, front=-0.93)
    # A mane of fire swept back, tallest in the middle.
    for x, y, z, r, length, lean in ((-0.55, 0.0, 1.9, 0.42, 1.3, -0.25), (0.55, 0.0, 1.9, 0.42, 1.3, 0.25), (-0.95, 0.2, 1.4, 0.34, 0.95, -0.9), (0.95, 0.2, 1.4, 0.34, 0.95, 0.9)):
        tube(r, length, (x, y, z), (lean, 0.35, 1), "FF6A1F", tip=0.0, vertices=7, emission=2)
        tube(r * 0.55, length * 0.6, (x, y - 0.3, z + 0.05), (lean, 0.35, 1), "FFE56A", tip=0.0, vertices=5, emission=4)
    tube(0.4, 1.1, (0, 0.85, 1.0), (0, 1, 0.8), "FF6A1F", tip=0.0, vertices=7, emission=2)


def lava():
    lift = -0.28
    critter("D23C14", "FFE56A", shape="round", barrel_colour="33202E", band="FF8A1F", lift=lift, rolls=False, emission=0.4)
    ball(1.75, (0, 0, 0.0), "FF5A1A", scale=(1, 0.95, 0.12), seg=12, rings=4, floor=0.0, emission=2)  # the pool it rises from
    ball(1.2, (0, 0, 0.1), "D23C14", scale=(1, 0.95, 0.4), seg=10, rings=4, floor=0.0, emission=0.4)
    for x, y, r in ((-1.3, -0.5, 0.2), (1.2, -0.7, 0.26), (1.4, 0.5, 0.16), (-0.9, 1.0, 0.2), (0.3, -1.4, 0.14)):
        dot(r, (x, y, 0.16), "FFD23A", emission=4)  # bubbles
    for x, y, z, r in ((-0.55, 0.1, 1.95 + lift, 0.4), (0.6, -0.2, 1.9 + lift, 0.34), (0.75, 0.6, 1.6 + lift, 0.3)):
        ball(r, (x, y, z), "3F2632", scale=(1, 1, 0.45), seg=8, rings=4, roughness=0.9)  # skin cooling on it
    for x, y, z, length in ((-0.95, -0.3, 1.2, 0.6), (0.98, -0.2, 1.0, 0.45), (-0.3, -0.92, 0.5, 0.3)):
        dot(0.12, (x, y, z + lift), "FFD23A", scale=(1, 1, length / 0.2), emission=3)


def phoenix():
    critter("FFAA32", "FF3C14", shape="round", barrel_colour="C8401A", band="FFE56A", wheel="8A3A2C", hub="FFE56A", faced=False)
    eyes(1.5, iris="FF3C14", front=-0.93)
    blush(1.07, front=-0.93)
    brows("C8401A", 2.0, tilt=-18, front=-0.9)
    beak("FFE56A", height=1.08, front=-0.98)
    wings("E5402D", "feather", height=1.75, tips=("E5402D", "FF8A1F", "FFE56A"))
    for x, lean, length, tint in ((-0.45, -0.45, 1.5, "E5402D"), (0.0, 0.0, 1.9, "FF8A1F"), (0.45, 0.45, 1.5, "E5402D")):
        tube(0.24, length, (x, 0.75, 0.9), (lean, 1.0, 0.75), tint, tip=0.03, vertices=6, emission=1)  # tail plumes
        end = Vector((x, 0.75, 0.9)) + Vector((lean, 1.0, 0.75)).normalized() * length
        dot(0.17, end, "FFE56A", emission=4)
    for x, lean in ((-0.25, -0.5), (0.0, 0.0), (0.25, 0.5)):
        tube(0.12, 0.5, (x, -0.5, 1.95), (lean, -0.3, 1), "E5402D", tip=0.0, vertices=5)  # crest


def supernova():
    lift = 0.6
    critter("FFFADC", "FF6A1F", shape="round", barrel_colour="FF9BE0", band="7FD8FF", lift=lift, rolls=False, emission=0.8, roughness=0.3)
    centre = Vector((0, 0.15, 1.3 + lift))
    tints = ("FFE56A", "FF8A1F", "FF9BE0", "7FD8FF")
    index = 0
    for turn in range(0, 360, 45):  # the blast, in every direction but its face
        for up in (-35, 10, 55):
            way = Vector((math.cos(RAD(up)) * math.sin(RAD(turn + up)), math.cos(RAD(up)) * math.cos(RAD(turn + up)), math.sin(RAD(up))))
            if way.y < -0.3 or (up > 30 and abs(way.x) < 0.5):
                continue
            tube(0.26, 1.0 + 0.5 * (index % 3 == 0), centre + way * 0.75, way, tints[index % 4], tip=0.0, vertices=5, emission=3)
            index += 1
    ring(1.75, 0.07, centre, "7FD8FF", rotation=(RAD(72), RAD(20), 0), seg=16, emission=3)  # shock waves
    ring(2.05, 0.05, centre, "FF9BE0", rotation=(RAD(80), RAD(-28), 0), seg=16, emission=3)
    crown(top=2.97 + lift, gems="FF9BE0", colour="FFE56A")
    ball(1.1, (0, 0.1, 0.03), "FFE56A", scale=(0.9, 0.9, 0.03), seg=10, rings=3, emission=3)  # its light on the ground


# ---------------------------------------------------------------------------------------------------
# The Secrets. Every egg hides a Glitched and a Forbidden one. They are two families: what tells one egg's
# from another's is its colour (the game's: the Secret's own colour with a share of the egg's) and the egg's
# sign, standing at its back.
# ---------------------------------------------------------------------------------------------------
def sign(kind, colour, x=0.0, y=0.98, z=2.85, **look):
    at = (x, y, z)
    if kind == "basic":  # a wooden signboard
        plate([(-0.85, -0.5), (0.85, -0.5), (0.85, 0.5), (-0.85, 0.5)], 0.12, at, colour, **look)
        box((0.14, 0.1, 1.2), (x, y + 0.02, z - 1.0), colour, **look)
        box((1.5, 0.14, 0.06), (x, y, z), shade(colour, -0.4), **look)
    elif kind == "forest":  # a fir tree
        plate([(0, 1.0), (-0.5, 0.35), (-0.25, 0.35), (-0.7, -0.25), (-0.35, -0.25), (-0.85, -0.85), (0.85, -0.85), (0.35, -0.25), (0.7, -0.25), (0.25, 0.35), (0.5, 0.35)], 0.12, at, colour, **look)
    elif kind == "moon":
        plate(crescent_points(0.95, horn=60, dip=0.35), 0.12, at, colour, rotation=(0, RAD(40), 0), **look)
    elif kind == "comet":
        plate(star_points(0.6, 0.25, points=4), 0.12, (x + 0.35, y, z + 0.3), colour, **look)
        plate([(0.2, 0.45), (-1.0, -0.75), (0.5, 0.1)], 0.1, (x, y + 0.01, z), colour, **look)
    elif kind == "mars":  # a ringed red planet
        plate(round_points(0.7), 0.12, at, colour, **look)
        box((2.1, 0.1, 0.1), at, shade(colour, 0.4), rotation=(0, RAD(22), 0), **look)
    elif kind == "dune":  # a pyramid under the sun
        plate([(-1.0, -0.7), (1.0, -0.7), (0, 0.5)], 0.12, at, colour, **look)
        plate(round_points(0.24, 8), 0.1, (x + 0.7, y, z + 0.65), shade(colour, 0.4), **look)
    elif kind == "frost":  # a snowflake
        for turn in (0, 60, 120):
            box((0.16, 0.12, 1.9), at, colour, rotation=(0, RAD(turn), 0), **look)
        plate(round_points(0.3, 6), 0.14, at, colour, **look)
    elif kind == "blizzard":  # a fan of ice shards
        for lean, length in ((-40, 0.95), (0, 1.3), (40, 0.95)):
            plate([(0, 0), (-0.22, length * 0.45), (0, length), (0.22, length * 0.45)], 0.12, (x, y, z - 0.8), colour, rotation=(0, RAD(lean), 0), **look)
    elif kind == "ember":
        plate(FLAME, 0.12, at, colour, **look)
    elif kind == "solar":  # the sun
        plate(star_points(1.0, 0.6, points=8), 0.12, at, colour, **look)


def glitched(colour, kind):
    def build():
        # Its body is three strips that have slid apart, like a picture that tore while loading.
        for z, slide, tint in ((0.72, 0.1, -0.14), (1.25, -0.14, 0.0), (1.78, 0.16, 0.14)):
            box((1.9, 1.7, 0.55), (slide, 0, z), shade(colour, tint), bevel=0.14)
        wheels(INK, MAGENTA)
        barrel(INK, top=2.05, band=MAGENTA)
        direction = Vector((0, -math.cos(RAD(16)), math.sin(RAD(16))))
        tube(0.48, 0.1, Vector((0.14, 0.72, 2.35)) + direction * 0.75, direction, CYAN, vertices=8, emission=2)  # a band that has come loose
        fuse(spark=CYAN)
        eyes(1.45, iris=MAGENTA, other=CYAN)  # eyes that do not match
        smile(0.86)
        for x, z, tint in ((-0.78, 0.62, MAGENTA), (-0.58, 0.62, INK), (-0.78, 0.82, INK), (-0.58, 0.82, MAGENTA)):
            box((0.2, 0.06, 0.2), (x, FRONT - 0.01, z), tint)  # the missing-picture checks
        for x, y, z, size, tint in ((-1.35, -0.3, 1.9, 0.26, CYAN), (-1.55, 0.1, 1.45, 0.16, MAGENTA), (1.4, -0.2, 1.2, 0.24, MAGENTA), (1.55, 0.2, 1.75, 0.15, WHITE),
                                    (1.25, -0.5, 2.3, 0.14, CYAN), (-1.2, 0.4, 2.45, 0.12, INK), (0.6, -0.4, 2.3, 0.18, colour)):
            box((size, size, size), (x, y, z), tint, emission=2 if tint in (CYAN, MAGENTA, WHITE) else 0)  # blocks of it floating off
        # The egg's sign, drawn twice and out of line: the colours have split.
        sign(kind, MAGENTA, x=0.12, y=1.04, emission=1.5)
        sign(kind, CYAN, x=-0.1, emission=1.5)
    return build


def forbidden(colour, kind, shape="cube"):
    def build():
        top = critter(colour, "FF2A2A", mood="fierce", shape=shape, barrel_colour="16101E", band="FF2A2A", wheel="16101E", hub="FF2A2A", brow="16101E")
        low = {"cube": FRONT, "tall": -0.81, "round": -0.66}[shape]
        # Chained shut, and locked.
        if shape == "round":
            hoop(0.7, "16101E", minor=0.08, minor_seg=3, seg=12)
            hoop(1.9, "16101E", minor=0.08, minor_seg=3, seg=10)
        else:
            wide, deep = (1.98, 1.78) if shape == "cube" else (1.78, 1.68)
            bands("16101E", ((0.6, 0), (top - 0.06, 0)), thickness=0.13, depth=deep, width=wide)
        for x in (-0.55, 0.55) if shape != "round" else ():
            ring(0.1, 0.035, (x, low - 0.03, 0.62), "8A8494", rotation=(RAD(90), 0, 0), seg=6, minor_seg=3)
        box((0.34, 0.14, 0.3), (0.0, low - 0.08, 0.4), GOLD, bevel=0.04)
        horns("16101E", top=top, size=1.55)
        wings(shade(colour, -0.55), "bat", height=1.5 if shape != "tall" else 1.8)
        # The sign that says no, over its barrel.
        ring(0.5, 0.08, (0, 0.1, top + 1.45), "FF2A2A", rotation=(RAD(90), 0, 0), seg=12, minor_seg=3, emission=4)
        box((0.92, 0.1, 0.13), (0, 0.1, top + 1.45), "FF2A2A", rotation=(0, RAD(45), 0), emission=4)
        for side in (-1, 1):
            flame(side * 0.55, 0.75, top - 0.1, 0.7, outer="7A1FB0", inner="FF2A2A")
        sign(kind, "C81E2E", y=1.0, z=top + 0.8, emission=1.0)
    return build


# ---------------------------------------------------------------------------------------------------
# The Huges (Mythical). Coin eggs take them in turn, so some are hidden by two of these ten eggs.
# ---------------------------------------------------------------------------------------------------
def huge_storm():
    critter("4696FF", "FFF078", mood="fierce", barrel_colour="2A5FC0", band="FFF078", wheel="1F3F8A", hub="FFF078", brow="1F3F8A")
    for x, y, z, r in ((-0.75, 0.3, 2.3, 0.5), (0.75, 0.3, 2.3, 0.5), (-0.4, 0.75, 2.75, 0.45), (0.45, 0.8, 2.7, 0.45), (-1.15, 0.5, 2.0, 0.36), (1.15, 0.5, 2.0, 0.36)):
        ball(r, (x, y, z), "DDE6F5", seg=8, rings=4)  # a thunder cloud on its back
    for side in (-1, 1):
        plate(scaled(BOLT, 0.85), 0.12, (side * 1.4, 0.3, 1.15), "FFF078", rotation=(0, side * RAD(12), 0), emission=5)
    bands("FFF078", ((0.6, 0),), thickness=0.12, emission=2)
    halo(top=3.75, colour="FFF078", radius=0.6)
    for x, z in ((-0.3, 3.3), (0.35, 3.35)):
        dot(0.08, (x, -0.2, z), "7FD8FF", scale=(1, 1, 1.8))


def huge_gatling():
    body("96A0AF", "cube", roughness=0.3)
    wheels("3A3D44", "FF463C")
    # Six barrels round one axle instead of one.
    direction = Vector((0, -math.cos(RAD(14)), math.sin(RAD(14))))
    start = Vector((0, 0.8, 2.6))
    side_way = Vector((1, 0, 0))
    up_way = direction.cross(side_way).normalized()
    for index in range(6):
        angle = RAD(index * 60 + 30)
        offset = (side_way * math.cos(angle) + up_way * math.sin(angle)) * 0.3
        tube(0.13, 1.75, start + offset, direction, "4A4E55", vertices=6, roughness=0.3)
        disc(0.08, start + offset + direction * 1.755, INK, facing=direction, vertices=6)
    for along, tint in ((0.2, "FF463C"), (1.0, "3A3D44"), (1.55, "FF463C")):
        tube(0.5, 0.14, start + direction * along, direction, tint, vertices=12, emission=2 if tint == "FF463C" else 0)
    ball(0.42, start, "4A4E55", seg=8, rings=4)
    box((0.9, 0.9, 0.5), (0, 0.25, 2.2), "5C6470", bevel=0.1)
    fuse()
    face("FF463C", mood="fierce", brow="3A3D44")
    box((0.5, 0.6, 0.7), (1.15, 0.3, 1.9), "5E6B3A", bevel=0.06)  # its box of shells, and the belt up to the gun
    for index in range(6):
        t = index / 5
        tube(0.06, 0.26, (0.95 - 0.5 * t - 0.13, 0.3, 2.3 + 0.35 * math.sin(t * math.pi) + 0.1 * t), (1, 0, 0), GOLD, vertices=5)
    bands("FF463C", ((0.6, 0),), thickness=0.12, emission=2)
    halo(top=3.9, colour="FF463C", radius=0.6, y=0.0)


def huge_hex():
    top = critter("8C3CC8", "78FF8C", mood="fierce", barrel_colour="3A1A66", band="78FF8C", wheel="3A1A66", hub="78FF8C", brow="3A1A66")
    horns("3A1A66", size=1.5)
    for side in (-1, 1):
        gem(0.1, (side * 1.17, 0.1, 2.72), "78FF8C", emission=3)
    # Six-sided runes turn slowly round it, and its halo has six sides too.
    for x, y, z, r, turn in ((-1.6, -0.2, 1.9, 0.42, 20), (1.6, -0.1, 1.5, 0.48, -15), (-1.45, 0.3, 0.75, 0.3, 0), (1.3, 0.4, 2.7, 0.3, 10)):
        ring(r, 0.07, (x, y, z), "78FF8C", rotation=(RAD(90), 0, RAD(turn)), seg=6, minor_seg=3, emission=3)
        gem(r * 0.32, (x, y, z), "C8FFD0", emission=3)
    ring(0.62, 0.08, (0, 0.1, top + 1.7), "78FF8C", seg=6, emission=4)
    eye(0, 2.03, "78FF8C", size=0.4)  # the eye that casts it
    bands("78FF8C", ((0.6, 0),), thickness=0.1, emission=2)
    for x in (-0.6, 0.6):
        plate(round_points(0.15, 6), 0.03, (x, FRONT - 0.03, 0.6), "3A1A66")
    box((2.0, 0.14, 1.4), (0, 0.9, 1.3), "3A1A66")  # a cloak


def huge_slayer():
    critter("C8281E", "F0EBDC", mood="fierce", barrel_colour="3A1A1A", band="F0EBDC", wheel="2A1010", hub="F0EBDC", brow="2A0A0A")
    ball(1.02, (0, 0.0, 1.98), "F0EBDC", scale=(1, 0.9, 0.42), seg=10, rings=4, floor=0.0)  # a helmet made of a skull
    for x in (-0.3, 0.0, 0.3):
        tube(0.08, 0.22, (x, FRONT - 0.04, 1.98), (0, 0, -1), "F0EBDC", tip=0.0, vertices=4)
    horns("F0EBDC", top=2.2, spread=0.8, size=1.7)
    # Its great sword, point up.
    plate([(-0.2, -1.2), (0.2, -1.2), (0.2, 1.0), (0, 1.45), (-0.2, 1.0)], 0.08, (1.5, -0.2, 2.2), "DDE6F5", roughness=0.15)
    box((0.06, 0.1, 2.0), (1.5, -0.2, 2.1), "9AA6B8")
    box((0.8, 0.16, 0.14), (1.5, -0.2, 0.98), GOLD)
    tube(0.07, 0.5, (1.5, -0.2, 0.45), (0, 0, 1), "3A1A1A", vertices=6)
    gem(0.12, (1.5, -0.2, 0.4), "FF3355", emission=2)
    for side in (-1, 1):
        tube(0.24, 0.45, (side * 0.9, 0.2, 1.4), (side, 0, 0.4), "F0EBDC", tip=0.0, vertices=6)
    box((0.55, 0.05, 0.08), (-0.5, FRONT - 0.02, 1.0), "5E0A0A", rotation=(0, RAD(-35), 0))
    bands("F0EBDC", ((0.6, 0),), thickness=0.1, emission=1)
    box((2.1, 0.12, 1.3), (0, 0.9, 1.25), "5E0A0A")
    halo(top=3.75, colour="F0EBDC", radius=0.6)


def huge_clover():
    critter("28C85A", "FFD750", shape="round", barrel_colour="1A7A3A", band="FFD750", wheel="1A7A3A", hub="FFD750")
    # A four-leaf clover stands behind it, and a small one grows on its brow.
    for turn in (45, 135, 225, 315):
        for half in (-1, 1):
            a = RAD(turn + half * 16)
            ball(0.62, (1.05 * math.cos(a), 0.85, 2.0 + 1.05 * math.sin(a)), "3FE070", scale=(1, 1, 0.22), rotation=(RAD(90), 0, 0), seg=8, rings=3)
    tube(0.08, 1.2, (0, 0.85, 0.9), (0, 0, 1), "1A7A3A", vertices=5)
    for turn in (45, 135, 225, 315):
        dot(0.15, (0.17 * math.cos(RAD(turn)), -0.72, 2.2 + 0.17 * math.sin(RAD(turn))), "3FE070", scale=(1, 0.4, 1))
    ring(0.4, 0.1, (1.5, -0.4, 0.45), "FFD750", rotation=(RAD(75), 0, RAD(20)), seg=10, roughness=0.2, emission=0.5)  # a lucky horseshoe
    for index in range(1):
        tube(0.3, 0.12, (-1.45, -0.5, index * 0.14), (0, 0, 1), "FFD750" if index % 2 else "E0A82A", vertices=8, roughness=0.2)  # and its pot's gold
    hoop(0.72, "FFD750", minor=0.07, minor_seg=3, emission=1.5)
    halo(top=3.55, colour="FFD750", radius=0.58)


def huge_golden_goose():
    critter("FFCD3C", "3FBDF5", shape="round", barrel_colour="E09A0A", band="FFFAEB", wheel="E0760A", hub="FFFAEB", roughness=0.2, faced=False)
    eyes(1.52, iris="3FBDF5", front=-0.93)
    blush(1.09, front=-0.93)
    ball(0.42, (0, -1.02, 1.05), "FF8A1F", scale=(1.0, 0.95, 0.42), seg=8, rings=4)  # a broad bill
    box((0.5, 0.3, 0.03), (0, -1.15, 1.03), "C85A0A")
    wings("FFFAEB", "feather", height=1.5, tips=("FFFAEB", "FFF0B8", "FFE27A"))
    for x, lean in ((-0.3, -0.4), (0.0, 0.0), (0.3, 0.4)):
        dot(0.32, (x, 1.0, 1.05), "FFFAEB", scale=(0.6, 1.5, 0.35), rotation=(RAD(25), 0, RAD(-lean * 40)))  # tail feathers
    for x, y, r in ((-1.35, -0.75, 0.36), (1.4, -0.6, 0.3)):
        ball(r, (x, y, r * 1.2), "FFD83A", scale=(1, 1, 1.25), seg=8, rings=4, roughness=0.12, emission=0.5)  # the golden eggs
    for x in (-0.14, 0.0, 0.14):
        tube(0.07, 0.36, (x, -0.55, 1.98), (x * 2.5, -0.5, 1), "FFFAEB", tip=0.0, vertices=4)
    hoop(0.72, "FFFAEB", minor=0.07, minor_seg=3, emission=1.5)
    halo(top=3.55, colour="FFFAEB", radius=0.58)


def huge_executioner():
    body("231E28", "cube")
    box((2.14, 1.72, 1.84), (0, 0.22, 1.42), "16101E", bevel=0.55)  # the hood
    tube(0.55, 0.9, (0, 0.5, 2.1), (0, 0.5, 1), "16101E", tip=0.0, vertices=8)
    wheels("16101E", "FF323C")
    barrel("0E0A14", top=2.34, band="FF323C")
    fuse()
    eyes(1.45, iris="FF323C")
    brows("0E0A14", 1.97)
    # Its axe, as tall as it is.
    tube(0.08, 3.3, (1.5, -0.2, 0.2), (0, 0, 1), WOOD, vertices=6)
    for side in (-1, 1):
        plate([(0.05, 0.3), (0.75, 0.75), (0.95, 0.0), (0.75, -0.75), (0.05, -0.3)], 0.1, (1.5, -0.2, 2.75), "C9D3E0", rotation=(0, 0, 0) if side > 0 else (0, RAD(180), 0), roughness=0.15)
        plate([(0.78, 0.74), (0.99, 0.0), (0.78, -0.74), (0.88, 0.0)], 0.12, (1.5, -0.2, 2.75), "FF323C", rotation=(0, 0, 0) if side > 0 else (0, RAD(180), 0), emission=3)
    tube(0.1, 0.3, (1.5, -0.2, 3.5), (0, 0, 1), "C9D3E0", tip=0.0, vertices=5)
    bands("FF323C", ((0.6, 0),), thickness=0.1, emission=2)
    box((0.9, 0.08, 0.5), (0, 0.98, 1.5), "FF323C", rotation=(0, RAD(45), 0), emission=2)
    halo(top=4.0, colour="FF323C", radius=0.6, y=0.3)


# ---------------------------------------------------------------------------------------------------
# Eggs: one design per egg, about 3.6 tall, standing on the ground, front towards -Y.
# ---------------------------------------------------------------------------------------------------
TAPER = 0.3  # how much narrower an egg is at its top than at its middle


def narrow(z):
    """An egg's width at height z, as a share of its widest."""
    return 1 - TAPER * max(0.0, (z - 1.8) / 1.78) ** 1.4


def egg_r(z):
    """How far the shell is from the egg's axis at height z."""
    return 1.35 * narrow(z) * math.sqrt(max(0.0, 1 - ((z - 1.8) / 1.782) ** 2))


def on_egg(turn, z, out=0.0):
    """A point on the shell: turn 0 is the front, 90 its side at +X."""
    r = egg_r(z) + out
    return (r * math.sin(RAD(turn)), -r * math.cos(RAD(turn)), z)


def shell(colour, **look):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.35, location=(0, 0, 1.8), segments=20, ring_count=12)
    obj = bpy.context.object
    obj.scale = (1, 1, 1.32)
    bpy.ops.object.transform_apply(scale=True)
    for vertex in obj.data.vertices:
        factor = narrow(vertex.co.z)  # applying the scale applied the location too: z is already the height
        vertex.co.x *= factor
        vertex.co.y *= factor
    finish(obj, colour, **look)


def patch(turn, z, radius, colour, tall=1.1, flat=0.3, **look):
    """A spot lying on the shell."""
    ball(radius, on_egg(turn, z, -0.02), colour, scale=(1, flat, tall), rotation=(0, 0, RAD(turn)), seg=8, rings=4, **look)


def egg_band(z, height, colour, out=0.05, **look):
    tube(egg_r(z - height / 2) + out, height, (0, 0, z - height / 2), (0, 0, 1), colour, tip=egg_r(z + height / 2) + out, vertices=20, **look)


def egg_cap(z, colour, out=0.06, **look):
    """Everything of the egg above z, a little bigger: snow, a cloth, an acorn's cup."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.35, location=(0, 0, 1.8), segments=20, ring_count=12)
    obj = bpy.context.object
    obj.scale = (1, 1, 1.32)
    bpy.ops.object.transform_apply(scale=True)
    for vertex in obj.data.vertices:
        height = max(vertex.co.z, z)
        factor = (egg_r(height) + out) / max(0.001, math.hypot(vertex.co.x, vertex.co.y)) if math.hypot(vertex.co.x, vertex.co.y) > 0.001 else 1
        vertex.co.x *= factor
        vertex.co.y *= factor
        vertex.co.z = height + (out if height > z else 0)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0005)
    bm.to_mesh(obj.data)
    bm.free()
    finish(obj, colour, **look)


def crater_on(turn, z, radius, rim, floor):
    patch(turn, z, radius, floor, tall=1.0, flat=0.16)
    ring(radius, radius * 0.22, on_egg(turn, z, 0.0), rim, rotation=(RAD(90), 0, RAD(turn)), seg=10, minor_seg=3)


def egg_basic():
    shell("FFF3D6")
    for turn, z, r in ((-28, 2.35, 0.32), (30, 1.5, 0.38), (-10, 1.0, 0.24), (22, 2.85, 0.2), (95, 2.2, 0.34), (-100, 1.6, 0.36), (170, 2.0, 0.36), (-60, 0.95, 0.2)):
        patch(turn, z, r, "6FD046" if r > 0.3 else "92E35A")
    for index in range(9):  # a tuft of grass round its foot
        turn = index * 40 + 10
        x, y, _ = on_egg(turn, 0.35, 0.12)
        tube(0.16, 0.5 + 0.2 * (index % 2), (x, y, 0.0), (x * 0.25, y * 0.25, 1), "58BE3E" if index % 2 else "6FD046", tip=0.0, vertices=5)
    tube(0.06, 0.45, (0, 0, 3.5), (0.1, 0, 1), "4FA83A", vertices=5)  # a sprout
    for side in (-1, 1):
        dot(0.3, (side * 0.3, 0, 4.0), "6FD046", scale=(1.25, 0.7, 0.3), rotation=(0, -side * RAD(28), 0))


def egg_forest():
    shell("3E9A4A")
    egg_cap(2.75, "8A5A2B", roughness=0.9)  # an acorn's cup
    ring(egg_r(2.75) + 0.08, 0.1, (0, 0, 2.75), "6B4A2B", seg=20)
    for turn in range(0, 360, 60):
        gem(0.11, on_egg(turn, 3.0, 0.06), "6B4A2B")
        gem(0.11, on_egg(turn + 30, 3.3, 0.06), "6B4A2B")
    tube(0.09, 0.4, (0, 0, 3.6), (0.2, 0, 1), "6B4A2B", vertices=6)
    for turn, z, r in ((-30, 2.2, 0.3), (35, 1.3, 0.34), (100, 1.9, 0.3), (-110, 1.2, 0.34), (175, 2.0, 0.3)):
        patch(turn, z, r, "2F7A3A", tall=1.5)  # leaf shapes, darker
    egg_band(0.82, 0.14, "8FD93E")
    for turn in (-50, 10, 70, 150, 230):
        dot(0.16, on_egg(turn, 0.9, 0.1), "B6F07A", scale=(1, 1, 0.5))
    for x, y, tall in ((-1.2, -0.75, 0.42), (1.3, -0.5, 0.56)):  # toadstools at its foot
        tube(0.1, tall, (x, y, 0), (0, 0, 1), "F5E9D0", vertices=6)
        ball(0.32, (x, y, tall), "D2463C", scale=(1, 1, 0.7), seg=8, rings=4, floor=0.0)
        dot(0.07, (x - 0.12, y - 0.2, tall + 0.12), WHITE)
        dot(0.06, (x + 0.16, y - 0.12, tall + 0.14), WHITE)


def egg_moon():
    shell("B9B5DA", roughness=0.8)
    for turn, z, r in ((-22, 2.3, 0.36), (32, 1.35, 0.3), (-48, 1.05, 0.2), (40, 2.75, 0.18), (105, 2.0, 0.34), (-115, 1.8, 0.32), (180, 1.5, 0.36)):
        crater_on(turn, z, r, "DAD7EE", "8B78D0")
    tube(0.035, 0.9, (0.1, 0, 3.5), (0, 0, 1), "F2F4FA", vertices=5)  # someone has planted a flag on it
    plate([(0, 0.2), (0.6, 0.2), (0.6, -0.2), (0, -0.2)], 0.04, (0.12, 0, 4.2), "FF4D4D")
    for x, y, r, length, lean in ((-1.2, -0.6, 0.22, 0.8, -0.3), (1.25, -0.4, 0.26, 1.0, 0.35), (0.2, 1.3, 0.24, 0.8, 0.1)):
        tube(r, length, (x, y, 0), (lean, 0, 1), "7FD8FF", tip=0.0, vertices=5, roughness=0.15, emission=0.8)  # moon crystals
    for x, y, r in ((-0.9, -1.0, 0.22), (0.6, -1.25, 0.16)):
        gem(r, (x, y, r * 0.6), "938EC0", roughness=0.8)


def egg_comet():
    shell("1C1C40", roughness=0.25)
    egg_band(1.45, 0.2, "5CB6F2", emission=1)  # the comet's path
    egg_band(1.45, 0.07, "E8F8FF", out=0.08, emission=2)
    for turn, z in ((-35, 2.5), (20, 2.2), (55, 2.9), (-15, 0.85), (40, 0.9), (-70, 1.9), (110, 2.4), (160, 0.9), (-130, 2.6), (-160, 1.0)):
        x, y, _ = on_egg(turn, z, 0.0)
        disc(0.07 if (turn + 360) % 3 else 0.11, on_egg(turn, z, 0.02), "FFF7C0", facing=(x, y, (z - 1.8) * 0.5), vertices=5, emission=4)  # stars
    # The comet itself goes round it.
    head = Vector((1.75, -0.75, 2.5))
    ball(0.3, head, "E8F8FF", seg=8, rings=4, emission=3)
    for spread, length, tint in ((0.0, 1.5, "BFE8FF"), (0.3, 1.0, "7FD8FF"), (-0.3, 1.0, "7FD8FF")):
        tube(0.26, length, head, (0.35, 1.0, 0.45 + spread), tint, tip=0.0, vertices=6, emission=1.5)
    for x, y, r, length, lean in ((-0.3, 0.1, 0.26, 0.9, -0.3), (0.2, -0.1, 0.3, 1.1, 0.15), (0.05, 0.3, 0.2, 0.7, 0.5)):
        tube(r, length, (x, y, 3.25), (lean, 0, 1), "BFE8FF", tip=0.0, vertices=5, roughness=0.15, emission=0.6)  # ice at its top


def egg_mars():
    shell("D9663A", roughness=0.8)
    for z, height, tint in ((0.85, 0.28, "9E3B24"), (1.55, 0.16, "F2905A"), (2.05, 0.3, "B04A2C"), (2.75, 0.18, "F2905A")):
        egg_band(z, height, tint, roughness=0.8)  # layers of rock, like a mesa
    crater_on(-25, 1.3, 0.26, "F2905A", "8E3A3C")
    crater_on(40, 2.42, 0.2, "F2905A", "8E3A3C")
    crater_on(140, 1.3, 0.28, "F2905A", "8E3A3C")
    for x, y, r, tint in ((-1.2, -0.7, 0.36, "B04A2C"), (1.3, -0.55, 0.28, "8E3A3C"), (0.8, -1.2, 0.2, "F2905A"), (-0.5, 1.3, 0.32, "B04A2C")):
        gem(r, (x, y, r * 0.6), tint, scale=(1, 1, 0.8), roughness=0.9)  # boulders
    gem(0.4, (0.05, 0, 3.55), "9E3B24", scale=(1.1, 1.1, 0.5), roughness=0.9)  # a flat stone on top, like a spire's


def egg_dune():
    shell("F0C878", roughness=0.8)
    egg_cap(2.7, "2F5FD0")  # a pharaoh's striped cloth
    for z in (2.85, 3.12, 3.38):
        egg_band(z, 0.1, "FFD25A", out=0.17)
    gem(0.16, on_egg(0, 2.8, 0.14), "FF3355", emission=1.5)
    for z, tint in ((0.75, "D6A25A"), (1.1, "E0B468")):
        egg_band(z, 0.1, tint)  # ripples in the sand
    x, y, z = on_egg(0, 1.75, 0.0)
    plate([(-0.55, -0.4), (0.55, -0.4), (0, 0.45)], 0.1, (x, y, z), "C98B4D")  # a pyramid, and the sun over it
    plate([(0, -0.4), (0.55, -0.4), (0, 0.45)], 0.12, (x, y, z), "A86B34")
    disc(0.17, on_egg(26, 2.3, 0.03), "FF8A1F", facing=(0.3, -1, 0.2), vertices=8, emission=2)
    ball(1.9, (0, 0, 0), "FFE9C4", scale=(1, 1, 0.12), seg=12, rings=4, floor=0.0, roughness=0.9)
    tube(0.17, 0.75, (1.45, -0.5, 0.05), (0, 0, 1), "46A050", vertices=7)  # a cactus beside it
    ball(0.17, (1.45, -0.5, 0.8), "46A050", seg=7, rings=3)
    tube(0.1, 0.26, (1.45, -0.5, 0.42), (1, 0, 0), "46A050", vertices=6)
    tube(0.1, 0.3, (1.71, -0.5, 0.42), (0, 0, 1), "46A050", vertices=6)
    dot(0.09, (1.45, -0.5, 0.98), "FF7AB8")


def egg_frost():
    shell("9EDCFF", roughness=0.15)
    egg_cap(2.55, WHITE)  # snow lying on it, and running down
    for turn, length in ((-55, 0.5), (-20, 0.3), (15, 0.6), (50, 0.34), (95, 0.5), (140, 0.3), (185, 0.55), (235, 0.36), (275, 0.5)):
        patch(turn, 2.55 - length / 2 + 0.05, 0.19, WHITE, tall=length / 0.19, flat=0.35)
    x, y, z = on_egg(0, 1.5, 0.0)
    for turn in (0, 60, 120):  # a snowflake on its front
        box((0.09, 0.1, 1.0), (x, y, z), WHITE, rotation=(0, RAD(turn), 0), emission=1)
    plate(round_points(0.16, 6), 0.14, (x, y, z), "D0F4FF", emission=1)
    for turn, r, length in ((-40, 0.24, 0.9), (30, 0.2, 0.7), (100, 0.26, 1.0), (160, 0.2, 0.7), (215, 0.24, 0.85), (290, 0.2, 0.65)):
        px, py, _ = on_egg(turn, 0.3, 0.2)
        tube(r, length, (px, py, 0), (px * 0.3, py * 0.3, 1), "D0F4FF", tip=0.0, vertices=5, roughness=0.15, emission=0.4)  # ice round its foot


def egg_blizzard():
    shell("3264C8", roughness=0.25)
    for turn, z, r in ((-30, 2.6, 0.12), (10, 2.25, 0.16), (45, 1.75, 0.1), (-50, 1.6, 0.15), (-5, 1.2, 0.11), (35, 0.95, 0.15), (80, 2.4, 0.13), (-95, 2.2, 0.13), (120, 1.3, 0.16), (-140, 1.4, 0.13), (175, 2.3, 0.15)):
        patch(turn, z, r, WHITE, tall=1.0, flat=0.5)  # snow driving past
    egg_band(1.95, 0.08, "9BF0FF", emission=1)
    # Blades of ice have grown out of it: a crown on top and wings at its sides.
    for x, y, r, length, lean in ((0, 0, 0.34, 1.3, 0.0), (-0.38, 0.05, 0.26, 0.95, -0.55), (0.38, 0.05, 0.26, 0.95, 0.55), (0.0, 0.35, 0.22, 0.8, 0.0)):
        tube(r, length, (x, y, 3.2), (lean, 0, 1), "9BF0FF", tip=0.0, vertices=5, roughness=0.15, emission=0.7)
    for side in (-1, 1):
        for z, length, up in ((2.3, 1.1, 0.7), (1.8, 1.3, 0.25), (1.35, 0.95, -0.1)):
            tube(0.24, length, (side * (egg_r(z) - 0.2), 0.1, z), (side, 0, up), "9BF0FF", tip=0.0, vertices=5, roughness=0.15, emission=0.7)
    for x, y, r in ((-1.0, -0.9, 0.5), (1.1, -0.7, 0.42), (0.1, -1.3, 0.36), (-0.2, 1.2, 0.5), (1.0, 0.9, 0.4), (-1.2, 0.5, 0.4)):
        ball(r, (x, y, 0.0), WHITE, scale=(1.2, 1.2, 0.6), seg=8, rings=4, floor=0.0)  # a drift at its foot


def egg_ember():
    shell("3F2632", roughness=0.85)
    # Cracks that glow: the fire inside is showing.
    for turn, high, count in ((-22, 2.75, 5), (24, 2.3, 4), (2, 1.55, 2), (-50, 1.9, 2), (105, 2.6, 5), (-110, 2.4, 4), (180, 2.7, 5)):
        for index in range(count):  # each a zigzag running down the shell
            box((0.11, 0.1, 0.5), on_egg(turn, high - index * 0.37, -0.01), "FF8A1F", rotation=(0, RAD(35 if index % 2 else -35), RAD(turn)), emission=5)
    egg_band(0.5, 0.2, "FF5A1A", emission=3)
    for x, y, r in ((-1.1, -0.8, 0.3), (1.2, -0.6, 0.24), (0.4, -1.3, 0.2), (-0.6, 1.2, 0.3), (1.0, 1.0, 0.22)):
        gem(r, (x, y, r * 0.6), "4A2C3A", roughness=0.9)  # cinders
        dot(r * 0.4, (x, y - r * 0.5, r * 1.0), "FF8A1F", emission=5)
    flame(0, 0, 3.4, 1.1)
    flame(-0.3, 0.1, 3.3, 0.6, lean=(-0.4, 0, 1))
    flame(0.3, 0.1, 3.3, 0.6, lean=(0.4, 0, 1))


def egg_solar():
    shell("FFB52E", roughness=0.25, emission=0.3)
    x, y, z = on_egg(0, 1.8, 0.0)
    plate(star_points(0.9, 0.55, points=8), 0.08, (x, y + 0.06, z), "FF6A1F", emission=1)  # the sun on its front
    ball(0.5, (x, y + 0.02, z), "FFE56A", scale=(1, 1, 0.34), rotation=(RAD(90), 0, 0), seg=12, rings=3, emission=3)
    for index in range(10):  # a corona round its top
        turn = index * 36
        px, py, _ = on_egg(turn, 2.85, -0.1)
        tube(0.24, 0.9 if index % 2 else 0.6, (px, py, 2.85), (px, py, 0.55), "FFE56A" if index % 2 else "FF8A1F", tip=0.0, vertices=5, emission=2.5)
    egg_band(2.8, 0.14, "FFE56A", emission=2)
    egg_band(0.8, 0.16, "FF6A1F", emission=1)
    for turn in (40, 120, 200, 280, 340):
        px, py, _ = on_egg(turn, 0.3, 0.3)
        flame(px, py, 0.0, 0.8)
    for turn, z in ((-40, 2.4), (45, 1.2), (110, 1.9), (-120, 1.5), (180, 2.2)):
        patch(turn, z, 0.2, "FFE56A", tall=1.0, emission=2)


# ---------------------------------------------------------------------------------------------------
# Which world has what. An egg: (egg id, its model, the egg's colour in the game, its mini cannons by pet id).
# The ids are Config.Pets' and Config.Eggs' (src/shared/Config.luau: WORLD_EGGS, CANNON_STYLES, SECRETS, COIN_HUGES).
# ---------------------------------------------------------------------------------------------------
FORBIDDEN_SHAPES = {"basic": "cube", "forest": "round", "moon": "round", "comet": "cube", "mars": "cube", "dune": "tall", "frost": "cube", "blizzard": "tall", "ember": "cube", "solar": "round"}


def secrets(egg_id, egg_colour):
    return [("glitched" + egg_id, glitched(blend("3CFFBE", egg_colour, 0.3), egg_id)), ("forbidden" + egg_id, forbidden(blend("961428", egg_colour, 0.3), egg_id, FORBIDDEN_SHAPES[egg_id]))]


def egg(egg_id, build, colour, minis, huge=None):
    return (egg_id, build, minis + secrets(egg_id, colour) + ([huge] if huge else []))


WORLDS = {
    "Earth": [
        egg("basic", egg_basic, "467A48", [("wooden", wooden), ("iron", iron), ("steel", steel), ("gold", gold), ("diamond", diamond)], ("hugestorm", huge_storm)),
        egg("forest", egg_forest, "78AFE1", [("leaf", leaf), ("vine", vine), ("mushroom", mushroom), ("honey", honey), ("jade", jade)], ("hugegatling", huge_gatling)),
    ],
    "Moon": [
        egg("moon", egg_moon, "9696A0", [("moonrock", moonrock), ("crater", crater), ("lunar", lunar), ("astro", astro), ("stellar", stellar)], ("hugehex", huge_hex)),
        egg("comet", egg_comet, "1C1C32", [("dust", dust), ("comet", comet), ("meteor", meteor), ("star", star), ("galaxy", galaxy)], ("hugeslayer", huge_slayer)),
    ],
    "Mars": [
        egg("mars", egg_mars, "BE5A32", [("rust", rust), ("dune", dune), ("martian", martian), ("rover", rover), ("warlord", warlord)], ("hugeclover", huge_clover)),
        egg("dune", egg_dune, "EB965A", [("sand", sand), ("cactus", cactus), ("scorpion", scorpion), ("pharaoh", pharaoh), ("sandstorm", sandstorm)], ("hugegoldengoose", huge_golden_goose)),
    ],
    "Neptune": [
        egg("frost", egg_frost, "C8E6FF", [("frost", frost), ("glacier", glacier), ("crystal", crystal), ("blizzard", blizzard), ("aurora", aurora)], ("hugeexecutioner", huge_executioner)),
        # Its Huge is the Storm again: modelled with Earth's.
        egg("blizzard", egg_blizzard, "3264C8", [("snow", snow), ("icicle", icicle), ("penguin", penguin), ("yeti", yeti), ("polar", polar)]),
    ],
    "The Sun": [
        # Their Huges are the Gatling and the Hex again: modelled with Earth's and the Moon's.
        egg("ember", egg_ember, "782814", [("ember", ember), ("magma", magma), ("obsidian", obsidian), ("inferno", inferno), ("solar", solar)]),
        egg("solar", egg_solar, "FF8C28", [("spark", spark), ("flame", flame_mini), ("lava", lava), ("phoenix", phoenix), ("supernova", supernova)]),
    ],
}
# What the photo's floor is: a colour the world's mini cannons stand out against.
FLOORS = {"Earth": "CFC6F0", "Moon": "4A4390", "Mars": "9FD8E8", "Neptune": "3F5FA8", "The Sun": "5A3848"}

if WORLD not in WORLDS:
    raise SystemExit(f"Unknown world {WORLD!r}: one of {', '.join(WORLDS)}")
FILE = WORLD.lower().replace(" ", "_") + "_minis"

GAP, ROW_GAP = 4.4, 18.0
models = {}  # mesh name -> (parts, where it stands)
rows = WORLDS[WORLD]
widest = max(len(minis) for _, _, minis in rows) + 1
for row, (egg_id, egg_build, minis) in enumerate(rows):
    line = list(minis) + [("Egg_" + egg_id, egg_build)]
    for index, (name, build) in enumerate(line):
        column = index if index < len(minis) else widest - 1  # the egg at the end of its row
        parts = []
        origin = Vector(((column - (widest - 1) / 2) * GAP, (len(rows) - 1 - row) * ROW_GAP, 0))
        build()
        models[name] = (parts, origin.copy())

# ---- One mesh per model, colours on the vertices ----
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
    low = min(vertex.co.z for vertex in joined.data.vertices)
    size = joined.dimensions
    is_egg = name.startswith("Egg_")
    remark = "" if is_egg or 500 <= triangles <= 1500 else "   <-- OUTSIDE 500 to 1,500"
    print(f"MODEL {name} triangles {triangles} size {size.x:.2f} x {size.y:.2f} x {size.z:.2f} lowest {low:.2f}{remark}")

# ---- The photo: every model turned a little to one side, so the barrel and the fuse show ----
bpy.ops.mesh.primitive_plane_add(size=1200, location=(0, 0, 0))
ground = bpy.context.object
ground.data.materials.append(mat(FLOORS[WORLD], roughness=0.9))
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*linear("DCEBFF"), 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
scene.world = world
sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 3.2
sun_data.angle = RAD(12)
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (RAD(52), 0, RAD(-32))

camera_data = bpy.data.cameras.new("Camera")
camera_data.type = "ORTHO"
camera_data.ortho_scale = widest * GAP + 1.5
camera = bpy.data.objects.new("Camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.samples = 12 if DRAFT else 64
scene.cycles.use_denoising = True
TILT = RAD(20)  # how far down the camera looks
tall = (len(rows) - 1) * ROW_GAP * math.sin(TILT) + 7.2
scene.render.resolution_x = 2600
scene.render.resolution_y = round(2600 * tall / camera_data.ortho_scale)
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "Standard"
centre = Vector((0, (len(rows) - 1) * ROW_GAP / 2, 1.9))
camera.location = centre + Vector((0, -math.cos(TILT), math.sin(TILT))) * 80
camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()

POSE = RAD(-34)
for name in models:
    bpy.data.objects[name].rotation_euler.z = POSE if not name.startswith("Egg_") else RAD(-20)
scene.render.filepath = f"{OUT}/{FILE}_sheet{'_draft' if DRAFT else ''}.png"
bpy.ops.render.render(write_still=True)
for name in models:
    bpy.data.objects[name].rotation_euler.z = 0

if DRAFT:
    raise SystemExit

# ---- For Roblox ----
bpy.ops.object.select_all(action="DESELECT")
for name in models:
    bpy.data.objects[name].select_set(True)
bpy.ops.export_scene.fbx(filepath=f"{OUT}/{FILE}.fbx", use_selection=True, apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", colors_type="SRGB")
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/{FILE}.blend")
