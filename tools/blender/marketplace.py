"""The marketplace: the town square in the chunky, rounded simulator style, made to be worn over the square
the game builds from parts (src/server/Marketplace.luau) without moving any of its spots.

Run: blender --background --python tools/blender/marketplace.py -- <output folder> [draft]

Marketplace space is the game's: the middle of the square (the fountain) on the ground is the origin, 1 unit
is 1 stud, the ground's top is z = 0, x is east and +Y is north (the game's z is -y here). 0 degrees is north,
90 east. Every spot is copied from Marketplace.luau and from the features that build on the square: the
fountain and its cannon in the middle, the plaza (26), the lamp ring (36), 20 houses and 4 towers at 84, the
eggs on an arc of 52 across the north, the hatchery sign at y = 70, stalls at x = 58, boards at x = -58, the
chest and the missions board at y = -42, the arrival pad at y = -56, the portal at y = -70, the trading
plaza at (-44, -52), the Huge at (24, 32), the crates at (-24, 32), the forge at (34, -26), the guide at
(-30, -26).

Writes market_hero.png, market_ground.png and the same two in Halloween dress, marketplace.blend,
market_manifest.json and marketplace.fbx with three kinds of mesh, colours on the vertices as earth_island.py:
  scenery, shown as it is, all with the middle of the square (on the ground) as origin:
      Market_Ground  Market_HousesNorth/East/South/West  Market_Towers  Market_Fountain  Market_Trees
      Market_Dressing  Market_Backdrop  Market_Glow (for Neon)  Market_Water (for Glass)
  seasonal, same origin, for the game to show or hide:
      Market_Leaves / Market_LeavesAutumn (the same shapes)  Market_Bunting (everyday)  Market_Halloween
  landmark shells, each with the middle of its own base as origin and its front towards -Y:
      EggPedestal  Stall + StallStripesA + StallStripesB (white, to tint)  Leaderboard + LeaderboardTrim (white)
      NoticeBoard  Chest  Portal + PortalSheet  HatcherySign  TradePlaza  HugePedestal  CrateStand  AmmoForge
      GuidePlinth
In the photos every shell stands on its spots as a copy, with stand-ins for what stays the game's own (eggs,
lamp bulbs, crates, the Huge, the guide, the words on the boards). None of that is exported, nor the clouds.
`draft` makes the photos at half size, for a quick look.

The floor is kept clean on purpose: a few big calm shapes (plaza, paths, lawn) and nothing scattered on it.
Character comes from the houses, roofs, towers, fountain, stalls, boards, lamps, trees and bunting overhead.
"""
import json
import math
import os
import random
import sys
from contextlib import contextmanager

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
OUT = ARGS[0]
DRAFT = "draft" in ARGS
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}
rng = random.Random(11)  # the same "random" town every run

GRASS, GRASS_LIGHT, GRASS_DEEP, GRASS_RIM = "6FD046", "92E35A", "58BE3E", "389A45"
STONE, STONE_DARK, STONE_PALE = "DCD6CC", "B9B2A8", "F4EFE6"
PAVE, PATH, PLAZA, BAND, WALK = "D9C5A1", "F1DDAE", "F7E2AA", "E3BE7A", "C8B492"
WOOD, WOOD_LIGHT, WOOD_DARK = "B9783F", "E3B06B", "8A5A2B"
WATER, WATER_LIGHT = "3FBDF5", "A8E8FF"
WHITE, INK, GOLD, GOLD_DARK, GOLD_LIGHT = "FFFFFF", "2B1240", "FFC61A", "E09A12", "FFE27A"
IRON, RED, BLUE, TEAL = "4A4763", "FF4D4D", "3FA9FF", "5AE1FF"
TRIM, GLASS = "FFF8EC", "8FD0FF"
BOARD_PLUM, BOARD_BLUE = "3A1F55", "2F6FE0"  # the faces the game writes on: gold and white words read on both
WALLS = ("FFD6AA", "FFECAA", "B0D4F5", "BEE8B4", "F0C4E2", "FAF4E6")  # BUILDING_COLORS
PEACH, BUTTER, SKY, MINT, PINK, CREAM = WALLS
ROOFS = ("DE5446", "4680DC", "F0A032", "3CAA96")  # ROOF_COLORS
ROOF_RED, ROOF_BLUE, ROOF_ORANGE, ROOF_TEAL = ROOFS
LEAVES = ("4FC44A", "2FA85A", "8FD93E")
AUTUMN = ("F0822A", "DC502D", "FABE3C")  # the game's autumn leaves
PETALS = ("FF7AB8", "FFFFFF", "FFD83A", "FF5A5A", "B58CFF")
PARTY = ("FF4D6A", "FFC61A", "3FA9FF", "5FE03A", "B58CFF", "FF8A1F")
PUMPKIN, WITCH, SLIME = "FF7A1A", "6B2BD9", "9CFF3A"
SPOOKY = (PUMPKIN, WITCH, "2B1240", PUMPKIN, "8A4BEA")
UP = (0, 0, 1)


def linear(hex_code):
    hex_code = hex_code.lstrip("#")
    return tuple(((int(hex_code[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4))


def shade(hex_code, amount):
    """Darker (amount < 0) or lighter (amount > 0) version of a colour."""
    hex_code = hex_code.lstrip("#")
    target = 255 if amount > 0 else 0
    return "".join("%02X" % round(int(hex_code[i:i + 2], 16) + (target - int(hex_code[i:i + 2], 16)) * abs(amount)) for i in (0, 2, 4))


def mat(hex_code, roughness=0.6, emission=0.0):
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


# ---------------------------------------------------------------------------------------------------
# The kit (earth_island.py's). Every piece is one flat colour. Pieces are collected per group: a group
# becomes one mesh. In the scenery anything that glows goes to the group "Glow" and the water to "Water",
# so that in Roblox those two meshes can be given Neon and Glass. A shell keeps its own glowing bits.
# ---------------------------------------------------------------------------------------------------
SIDES = ("North", "East", "South", "West")
SCENERY = ("Ground", *("Houses" + side for side in SIDES), *("Roofs" + side for side in SIDES), "Towers", "Fountain", "Trees", "Dressing", "Backdrop", "Water", "Glow")
SEASONAL = ("Leaves", "LeavesAutumn", "Bunting", "Halloween")
RENDER_ONLY = ("Placeholders", "PlaceholdersDay", "PlaceholdersHalloween", "Clouds")  # in the photos, not in the export
groups = {}  # name -> pieces
group = "Ground"  # the group being built
made = []  # every piece, in the order it was made
exporting = False  # a landmark's shell is being built (not its copy for the photos)
SHARP = math.radians(50)  # edges bent more than this stay crisp


@contextmanager
def into(name):
    """Builds what is inside the `with` into another group."""
    global group
    home, group = group, name
    try:
        yield
    finally:
        group = home


row = "North"  # the row of houses being built


def roofing():
    """A row's roofs (with their dormers, chimneys, flags and ornaments) are a mesh of their own: a row of
    houses with its roofs is over the 10,000 triangles one mesh may have."""
    return into("Roofs" + row if group.startswith("Houses") else group)


def part(name):
    """Where a shell's second mesh goes: a group of its own for the export, the copy's group for the photos."""
    return into(name if exporting else group)


def finish(work, colour, location=(0, 0, 0), rotation=(0, 0, 0), smooth=True, tidy=False, **look):
    """Turns the shape being worked on into a piece of the current group."""
    if tidy:  # a hand-made closed shape: make every face look outwards
        bmesh.ops.recalc_face_normals(work, faces=work.faces)
    work.normal_update()
    for edge in work.edges:
        if len(edge.link_faces) == 2 and edge.calc_face_angle() > SHARP:
            edge.smooth = False
    for face in work.faces:
        face.smooth = smooth
    data = bpy.data.meshes.new("Piece")
    work.to_mesh(data)
    work.free()
    data.materials.append(mat(colour, **look))
    obj = bpy.data.objects.new("Piece", data)
    obj.location, obj.rotation_euler = location, rotation
    scene.collection.objects.link(obj)
    groups.setdefault("Glow" if look.get("emission") and group in SCENERY else group, []).append(obj)
    made.append(obj)
    return obj


def box(size, location, colour, bevel=0.3, rotation=(0, 0, 0), segments=2, **look):
    work = bmesh.new()
    bmesh.ops.create_cube(work, size=1.0)
    bmesh.ops.scale(work, vec=size, verts=work.verts)
    bmesh.ops.bevel(work, geom=work.edges[:], offset=min(bevel, min(size) * 0.49), offset_type="OFFSET", segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)
    return finish(work, colour, location, rotation, **look)


def slab(size, location, colour, rotation=(0, 0, 0), **look):
    """A plain box with crisp edges: 12 triangles, for small and far things."""
    work = bmesh.new()
    bmesh.ops.create_cube(work, size=1.0)
    bmesh.ops.scale(work, vec=size, verts=work.verts)
    return finish(work, colour, location, rotation, smooth=False, **look)


def ball(radius, location, colour, scale=(1, 1, 1), rotation=(0, 0, 0), segments=12, **look):
    work = bmesh.new()
    bmesh.ops.create_uvsphere(work, u_segments=segments, v_segments=max(3, segments // 2), radius=radius)
    bmesh.ops.scale(work, vec=scale, verts=work.verts)
    return finish(work, colour, location, rotation, **look)


def tube(radius, depth, start, direction, colour, tip=None, vertices=12, **look):
    """A cylinder (or a cone when tip is given) from `start` along `direction`."""
    direction = Vector(direction).normalized()
    work = bmesh.new()
    bmesh.ops.create_cone(work, cap_ends=True, cap_tris=False, segments=vertices, radius1=radius, radius2=radius if tip is None else tip, depth=depth)
    return finish(work, colour, Vector(start) + direction * depth / 2, direction.to_track_quat("Z", "Y").to_euler(), **look)


def mesh(vertices, faces, colour, location=(0, 0, 0), rotation=(0, 0, 0), bevel=0.0, up=False, **look):
    work = bmesh.new()
    corners = [work.verts.new(vertex) for vertex in vertices]
    for face in faces:
        made_face = work.faces.new([corners[index] for index in face])
        if up:  # ground: seen from above only, and Roblox draws one side of a face
            made_face.normal_update()
            if made_face.normal.z < 0:
                made_face.normal_flip()
    if bevel:
        bmesh.ops.recalc_face_normals(work, faces=work.faces)
        bmesh.ops.bevel(work, geom=work.edges[:], offset=bevel, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    return finish(work, colour, location, rotation, **look)


def prism(outline, depth, colour, location=(0, 0, 0), rotation=(0, 0, 0), axis="y", bevel=0.0, **look):
    """A flat outline of (across, height) points given `depth`: along Y (the outline is then seen from the
    front) or along X (seen from the side: across is y)."""
    def corner(across, height, side):
        return (across, side, height) if axis == "y" else (side, across, height)
    work = bmesh.new()
    near = [work.verts.new(corner(a, b, -depth / 2)) for a, b in outline]
    far = [work.verts.new(corner(a, b, depth / 2)) for a, b in outline]
    work.faces.new(near)
    work.faces.new(far[::-1])
    for index in range(len(outline)):
        after = (index + 1) % len(outline)
        work.faces.new((near[after], near[index], far[index], far[after]))
    if bevel:
        bmesh.ops.recalc_face_normals(work, faces=work.faces)
        bmesh.ops.bevel(work, geom=work.edges[:], offset=bevel, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    return finish(work, colour, location, rotation, tidy=True, **look)


def hoop(radius, thickness, location, colour, rotation=(0, 0, 0), segments=16, around=5, **look):
    """A ring lying flat: a band around a column, a handle, a halo."""
    vertices = []
    for step in range(segments):
        a = step * 2 * math.pi / segments
        for turn in range(around):
            b = turn * 2 * math.pi / around
            reach = radius + thickness * math.cos(b)
            vertices.append((reach * math.cos(a), reach * math.sin(a), thickness * math.sin(b)))
    faces = [(step * around + turn, ((step + 1) % segments) * around + turn, ((step + 1) % segments) * around + (turn + 1) % around, step * around + (turn + 1) % around)
             for step in range(segments) for turn in range(around)]
    return mesh(vertices, faces, colour, location, rotation, tidy=True, **look)


def ring(degrees, radius):
    """A point (x, y) on a circle around the middle, like the game's: 0 degrees is north, 90 is east."""
    angle = math.radians(degrees)
    return math.sin(angle) * radius, math.cos(angle) * radius


def lathe(rings, colour, segments=48, shape=None, rough=0.0, stretch=1.0, **look):
    """A solid of rings stacked around the Z axis. Each ring is (radius, z); a radius of 0 is a single point.
    List the rings the way a cut through the middle is drawn clockwise: outwards along the top, down the
    outside, back in underneath. Then every face looks outwards."""
    vertices, starts = [], []
    for radius, z in rings:
        starts.append(len(vertices))
        if not callable(radius) and radius == 0:
            vertices.append((0, 0, z))
            continue
        for step in range(segments):
            degrees = step * 360 / segments
            r = radius(degrees) if callable(radius) else radius
            height = z(degrees) if callable(z) else z
            if shape:
                r *= shape(degrees)
            if rough:
                r += rng.uniform(-rough, rough)
                height += rng.uniform(-rough, rough) * 0.5
            x, y = ring(degrees, r)
            vertices.append((x, y * stretch, height))
    starts.append(len(vertices))
    faces = []
    for index in range(len(rings) - 1):
        a, b = starts[index], starts[index + 1]
        point_a, point_b = b - a == 1, starts[index + 2] - b == 1
        for step in range(segments):
            after = (step + 1) % segments
            if point_a:
                faces.append((a, b + after, b + step))
            elif point_b:
                faces.append((a + step, a + after, b))
            else:
                faces.append((a + step, a + after, b + after, b + step))
    return mesh(vertices, faces, colour, **look)


def dome(radius, height, location, colour, rotation=(0, 0, 0), stretch=1.0, sink=None, segments=12, **look):
    """A low rounded cap, open underneath, to lie on something."""
    sink = radius * 0.25 if sink is None else sink
    return lathe([(0, height), (radius * 0.62, height * 0.62), (radius, -sink)], colour, segments=segments, stretch=stretch, location=location, rotation=rotation, **look)


def star(radius, location, colour, depth=0.35, rotation=(0, 0, 0), **look):
    """A chunky five-pointed star standing upright, its face to the front (-Y)."""
    rim = [ring(index * 36, radius if index % 2 == 0 else radius * 0.5) for index in range(10)]
    vertices = [(x, 0, z) for x, z in rim] + [(0, -depth, 0), (0, depth, 0)]
    faces = [(10, (index + 1) % 10, index) for index in range(10)] + [(11, index, (index + 1) % 10) for index in range(10)]
    return mesh(vertices, faces, colour, location, rotation, smooth=False, tidy=True, **look)


def flat(points, z, colour, **look):
    """A flat shape lying on the ground, seen from above only: (x, y) points."""
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(points, points[1:] + points[:1]))
    if area < 0:
        points = points[::-1]
    return mesh([(x, y, z) for x, y in points], [tuple(range(len(points)))], colour, up=True, smooth=False, roughness=0.9, **look)


def band(inner, outer, start, end, z, colour, steps=48):
    """A flat piece of a ring on the ground, from `start` to `end` degrees."""
    vertices, faces = [], []
    for step in range(steps + 1):
        degrees = start + (end - start) * step / steps
        vertices += [(*ring(degrees, inner), z), (*ring(degrees, outer), z)]
        if step:
            a = (step - 1) * 2
            faces.append((a, a + 1, a + 3, a + 2))
    return mesh(vertices, faces, colour, up=True, smooth=False, roughness=0.9)


def frame_square(inner, outer, z, colour):
    """A flat square ring on the ground, around the middle."""
    vertices = [(sx * reach, sy * reach, z) for reach in (inner, outer) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    faces = [(index, (index + 1) % 4, 4 + (index + 1) % 4, 4 + index) for index in range(4)]
    return mesh(vertices, faces, colour, up=True, smooth=False, roughness=0.9)


def rect(x0, y0, x1, y1, z, colour):
    return flat([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], z, colour)


def arch(width, height, steps=5):
    """The outline of a shape with a round top, from the middle of its foot."""
    r = width / 2
    return [(r, 0.0)] + [(r * math.cos(index * math.pi / steps), height - r + r * math.sin(index * math.pi / steps)) for index in range(steps + 1)] + [(-r, 0.0)]


def half_disc(radius, steps=8):
    return [(radius * math.cos(index * math.pi / steps), radius * math.sin(index * math.pi / steps)) for index in range(steps + 1)]


def place(build, at, face=None, scale=1.0, **options):
    """Builds a prop (made around its own origin, standing on z = 0, its front towards -Y) and stands it at
    (x, y) on the ground, or at (x, y, z). It looks at the middle of the square unless `face` says where
    (degrees, like ring). Returns the frame it stands at."""
    first = len(made)
    build(**options)
    x, y = at[0], at[1]
    z = at[2] if len(at) > 2 else 0.0
    if face is None:
        face = math.degrees(math.atan2(-x, -y)) if (x or y) else 180
    frame = Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(180 - face), 4, "Z")
    for obj in made[first:]:
        obj.matrix_basis = frame @ Matrix.Scale(scale, 4) @ obj.matrix_basis
    return frame


# ---------------------------------------------------------------------------------------------------
# Landmarks: a shell for the game (built once, around its own origin) and a copy on every spot for the photos
# ---------------------------------------------------------------------------------------------------
shells = {}  # name -> what the manifest says about it
spots = {}  # name -> where the game stands it
colliders = []  # boxes the game should add for new solid things
labels = {"both": [], "day": [], "halloween": []}  # words on the boards, for the photos only
WHEN = {"both": "Placeholders", "day": "PlaceholdersDay", "halloween": "PlaceholdersHalloween"}
FONT = None
for path in ("/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",):
    if os.path.exists(path):
        FONT = bpy.data.fonts.load(path)


def facing(x, y, face=None):
    if face is None:
        face = math.degrees(math.atan2(-x, -y))
    return face % 360


def shell(name, build, also=(), **info):
    """Builds a landmark's shell for the export: a group of its own (and of every mesh in `also`)."""
    global exporting
    exporting = True
    with into(name):
        build()
    exporting = False
    for each in (name, *also):
        shells[each] = dict(info) if each == name else {"with": name}
        spots.setdefault(each, [])


def show(name, build, at, face=None, when="both", note=None, **options):
    """Stands a copy of a landmark on one of the game's spots, for the photos, and notes the spot."""
    with into(WHEN[when]):
        frame = place(build, at, face, **options)
    if name:
        degrees = facing(at[0], at[1], face)
        entry = {"x": round(at[0], 3), "z": round(-at[1], 3), "faces": round(degrees, 2), "yaw": round((-degrees + 180) % 360 - 180, 2),
                 "when": {"both": "always", "day": "everyday", "halloween": "halloween"}[when]}
        if note:
            entry["note"] = note
        for each in [name] + [other for other, about in shells.items() if about.get("with") == name]:
            spots[each].append(entry)
    return frame


def words(text, frame, at, height, colour=WHITE, when="both", align="CENTER"):
    """For the photos only: what the game writes on a board. `at` is a point in the board's own space, on its face."""
    curve = bpy.data.curves.new("Words", "FONT")
    curve.body = text
    curve.size = height
    curve.align_x, curve.align_y = align, "CENTER"
    curve.extrude = 0.02
    if FONT:
        curve.font = FONT
    curve.materials.append(mat(colour, roughness=0.8))
    obj = bpy.data.objects.new("Words", curve)
    obj.matrix_basis = frame @ Matrix.Translation(at) @ Matrix.Rotation(math.pi / 2, 4, "X")
    scene.collection.objects.link(obj)
    labels[when].append(obj)


def collider(name, at, size, face=0.0, when="always"):
    """A box the game should add (invisible, CanCollide) for something solid that is new. `at` is the middle of
    its foot in this file's space, `size` is (across, deep, tall) before it is turned to `face`."""
    colliders.append({"name": name, "centre": {"x": round(at[0], 2), "y": round(size[2] / 2, 2), "z": round(-at[1], 2)},
                      "size": {"x": size[0], "y": size[2], "z": size[1]}, "yaw": round((-face + 180) % 360 - 180, 2), "when": when})


# ---------------------------------------------------------------------------------------------------
# Plants, lamps, bunting
# ---------------------------------------------------------------------------------------------------
def foliage(radius, location, tone, amount=0.0, scale=(1, 1, 1), segments=12):
    """A ball of leaves: green in the mesh Leaves, the same ball in autumn colours in LeavesAutumn."""
    for name, colours in (("Leaves", LEAVES), ("LeavesAutumn", AUTUMN)):
        with into(name):
            ball(radius, location, shade(colours[tone], amount), scale=scale, segments=segments)


def tree(leaf=0, kind="round", fine=True):
    """A fat trunk and a few balls of leaves in three tones of one colour. About 16 tall."""
    big, small = (14, 10) if fine else (12, 8)
    tube(1.25, 7.5, (0, 0, -0.6), (0.04, 0, 1), WOOD, tip=0.8, vertices=8)
    if kind == "round":
        foliage(5.3, (0, 0, 10.2), leaf, scale=(1, 1, 0.9), segments=big)
        foliage(3.5, (-3.3, -1.0, 8.2), leaf, -0.1, segments=small)
        foliage(3.3, (3.1, 1.2, 8.7), leaf, -0.1, segments=small)
        foliage(3.1, (0.9, -1.6, 13.2), leaf, 0.14, segments=small)
    else:  # three balls stacked like a fir
        foliage(4.7, (0, 0, 8.2), leaf, -0.1, scale=(1, 1, 0.8), segments=big - 2)
        foliage(3.8, (0, 0, 12.2), leaf, scale=(1, 1, 0.85), segments=big - 4)
        foliage(2.7, (0, 0, 15.6), leaf, 0.14, scale=(1, 1, 0.95), segments=small)


def bud(radius, location, colour):
    ball(radius, location, colour, segments=6)


def flower_box(x, y, z, width, petal, fine=True):
    """A box of flowers under a window: on the house, never on the floor."""
    if fine:
        box((width, 1.1, 0.9), (x, y, z), WOOD, bevel=0.2, segments=1)
    else:
        slab((width, 1.1, 0.9), (x, y, z), WOOD)
    ball(0.5, (x, y, z + 0.5), LEAVES[1], scale=(width * 0.9, 0.9, 0.9), segments=6)
    other = PETALS[2] if petal != PETALS[2] else PETALS[1]
    for index in range(3) if fine else (0, 2):
        bud(0.46, (x + (index - 1) * width * 0.31, y - 0.12, z + 0.88 + 0.12 * (index % 2)), other if index == 1 else petal)


def lamp():
    """A street lamp: the game's own bulb (a ball 1.8 across, 11.6 up) hangs in its cage, so the game can
    colour it. A basket of flowers hangs from its arm."""
    tube(1.1, 0.9, (0, 0, 0), UP, STONE, vertices=10)
    tube(0.8, 0.5, (0, 0, 0.9), UP, STONE_PALE, vertices=10)
    tube(0.34, 8.7, (0, 0, 1.4), UP, IRON, tip=0.26, vertices=8)
    tube(0.5, 0.3, (0, 0, 4.3), UP, GOLD, vertices=8, roughness=0.3)
    tube(0.75, 0.4, (0, 0, 10.0), UP, IRON, tip=1.15, vertices=8)
    for index in range(4):
        x, y = ring(index * 90 + 45, 1.08)
        tube(0.08, 2.3, (x, y, 10.38), UP, IRON, vertices=3)
    tube(1.5, 1.0, (0, 0, 12.6), UP, IRON, tip=0.2, vertices=8)
    bud(0.24, (0, 0, 13.7), GOLD)
    tube(0.12, 2.3, (0, 0, 8.5), (1, 0, 0.12), IRON, vertices=4)
    tube(0.05, 0.9, (2.2, 0, 7.85), UP, IRON, vertices=3)
    ball(0.8, (2.2, 0, 7.35), WOOD_DARK, scale=(1, 1, 0.62), segments=6)
    ball(0.95, (2.2, 0, 7.75), LEAVES[1], scale=(1, 1, 0.5), segments=6)
    for index, petal in enumerate((PETALS[0], PETALS[2], PETALS[3])):
        x, y = ring(index * 120 + 30, 0.5)
        bud(0.4, (2.2 + x, y, 8.1), petal)


def bulb(colour, radius=0.9, height=11.6):
    """For the photos: the game's own lamp."""
    ball(radius, (0, 0, height), colour, emission=1.6)


def bunting(a, b, sag=2.0):
    """A string of flags between two points, overhead: party colours in the mesh Bunting, orange and purple
    with a lantern now and then in Halloween."""
    a, b = Vector(a), Vector(b)
    count = max(4, round((b - a).length / 2.1))
    points = [a.lerp(b, index / count) - Vector((0, 0, sag * 4 * (index / count) * (1 - index / count))) for index in range(count + 1)]
    turn = math.atan2(b.y - a.y, b.x - a.x)
    for name, colours in (("Bunting", PARTY), ("Halloween", SPOOKY)):
        with into(name):
            for index in range(count):
                p, q = points[index], points[index + 1]
                tube(0.07, (q - p).length, p, q - p, "5B4A7E", vertices=3)
                middle = (p + q) / 2
                if name == "Halloween" and index % 7 == 3:
                    paper_lantern(middle)
                else:
                    prism([(-0.86, 0.05), (0.86, 0.05), (0, -2.0)], 0.1, colours[index % len(colours)], location=middle, rotation=(0, 0, turn))
            for end in (a, b):
                bud(0.3, end, GOLD)


# ---------------------------------------------------------------------------------------------------
# Halloween: cute, not scary
# ---------------------------------------------------------------------------------------------------
def paper_lantern(at):
    at = Vector(at)
    ball(0.7, at - Vector((0, 0, 0.9)), PUMPKIN, scale=(1, 1, 0.9), segments=6, emission=0.5)
    tube(0.32, 0.2, at - Vector((0, 0, 0.36)), UP, INK, vertices=4)


def pumpkin(size=2.0, smile=True):
    """A big friendly jack-o'-lantern, its face to the front."""
    glow = "FFE65A"
    def ribs(degrees):
        return 1 + 0.07 * math.cos(math.radians(degrees) * 6)

    lathe([(0, 1.5 * size)] + [(radius * size, z * size) for radius, z in ((0.55, 1.52), (1.0, 1.15), (1.08, 0.66), (0.8, 0.14))] + [(0, 0.0)],
          PUMPKIN, segments=18, shape=ribs, roughness=0.4)
    tube(size * 0.16, size * 0.5, (0, 0, size * 1.5), (0.25, 0, 1), "5C8A3A", tip=size * 0.1, vertices=6)
    if smile:
        for side in (-1, 1):
            prism([(-0.2 * size, 0), (0.2 * size, 0), (0, 0.32 * size)], 0.3 * size, glow, location=(side * 0.36 * size, -0.98 * size, size * 0.92), emission=1.0)
        prism([(-0.5 * size, 0.16 * size), (-0.25 * size, 0), (0.25 * size, 0), (0.5 * size, 0.16 * size), (0.22 * size, 0.1 * size), (-0.22 * size, 0.1 * size)],
              0.3 * size, glow, location=(0, -0.99 * size, size * 0.5), emission=1.0)


def ghost(size=1.0):
    """A friendly ghost: a rounded sheet with a wavy hem, big eyes, a smile and rosy cheeks."""
    white = "F6F8FF"
    lathe([(0, 3.4), (0.75, 3.25), (1.3, 2.7), (1.55, 1.8), (1.6, 0.5), (1.45, 0.2), (0, 0.5)], white, segments=10)
    for index in range(6):
        x, y = ring(index * 60, 1.15)
        ball(0.52, (x, y, 0.32), white, segments=6)
    for side in (-1, 1):
        ball(0.5, (side * 1.55, -0.35, 1.9), white, scale=(1.25, 0.8, 0.7), rotation=(0, side * -0.5, 0), segments=6)
        ball(0.3, (side * 0.52, -1.3, 2.45), INK, scale=(0.8, 0.4, 1.15), segments=8)
        ball(0.1, (side * 0.52 - 0.08, -1.44, 2.6), WHITE, segments=6)
        ball(0.22, (side * 0.95, -1.22, 2.0), "FFB3CF", scale=(1, 0.3, 0.7), segments=6)
    ball(0.22, (0, -1.5, 1.95), INK, scale=(1.2, 0.4, 0.8), segments=6)


def bat():
    """A small round bat, wings out."""
    ball(0.75, (0, 0, 0), WITCH, scale=(1, 0.85, 1), segments=8)
    for side in (-1, 1):
        prism([(0, 0.35), (1.0, 0.75), (2.1, 0.3), (1.75, -0.1), (1.3, 0.12), (0.85, -0.2), (0.4, 0.05), (0, -0.35)], 0.12, shade(WITCH, -0.25), location=(side * 0.55, 0.05, 0.1),
              rotation=(0, side * -0.2 if side > 0 else math.pi - 0.2, 0))
        tube(0.2, 0.5, (side * 0.38, 0, 0.55), (side * 0.25, 0, 1), WITCH, tip=0.0, vertices=4)
        ball(0.17, (side * 0.27, -0.62, 0.12), WHITE, segments=6)
        ball(0.08, (side * 0.27, -0.76, 0.12), INK, segments=4)


def cobweb(size=4.0):
    """A corner web: it hangs in the corner under (0, 0, 0), spreading towards +X and down."""
    white = "F1EEFA"
    spokes = [math.radians(angle) for angle in (0, 30, 60, 90)]
    for angle in spokes:
        slab((size, 0.07, 0.11), (math.cos(angle) * size / 2, 0, -math.sin(angle) * size / 2), white, rotation=(0, angle, 0))
    for share in (0.45, 0.9):
        for a, b in zip(spokes, spokes[1:]):
            p = Vector((math.cos(a), 0, -math.sin(a))) * size * share
            q = Vector((math.cos(b), 0, -math.sin(b))) * size * share
            step = q - p
            slab((step.length, 0.07, 0.1), (p + q) / 2, white, rotation=(0, math.atan2(-step.z, step.x), 0))


def witch_hat(size=1.0):
    brim, cone = "3B1F6E", WITCH
    lathe([(0, 0.5), (2.6, 0.3), (3.3, 0.0), (2.6, -0.1), (0, -0.1)], brim, segments=14, location=(0, 0, 0))
    lathe([(0, 5.6), (0.5, 4.3), (1.15, 2.6), (1.75, 0.9), (1.9, 0.3), (0, 0.3)], cone, segments=12, location=(0, 0, 0), rotation=(0.12, 0.1, 0))
    tube(1.92, 0.55, (0, 0, 0.42), UP, PUMPKIN, vertices=12)
    box((0.9, 0.3, 0.75), (0, -1.9, 0.7), GOLD, bevel=0.1, segments=1)


# ---------------------------------------------------------------------------------------------------
# Eggs (earth_island.py's), for the photos and for the two that are ornaments
# ---------------------------------------------------------------------------------------------------
EGG_SPOTS = ((0, 5, 0.35), (48, 38, 0.24), (-55, 30, 0.28), (-30, -32, 0.24), (40, -25, 0.31), (100, 5, 0.33), (-110, -5, 0.35), (165, 30, 0.28), (190, -25, 0.32), (10, 64, 0.2), (140, -40, 0.22), (-150, 52, 0.2))
CUSHION_TOP = 3.0  # where the game's egg stands on EggPedestal


def egg(radius, location, colour, spot_colour, spots=EGG_SPOTS, detail=2):
    """A big egg: a ball stretched tall and narrowed towards its top, with round spots all over its shell."""
    tall = 1.36
    around, rows, dots = ((14, 8, 9), (18, 10, 12), (24, 12, 18))[detail]
    work = bmesh.new()
    bmesh.ops.create_uvsphere(work, u_segments=around, v_segments=rows, radius=radius)
    for vertex in work.verts:
        narrow = 1 - 0.16 * vertex.co.z / radius
        vertex.co = (vertex.co.x * narrow, vertex.co.y * narrow, vertex.co.z * tall)
    finish(work, colour, location, roughness=0.3)
    for turn, rise, share in spots:
        a, b, size = math.radians(turn), math.radians(rise), share * radius
        narrow = 1 - 0.16 * math.sin(b)
        point = Vector((math.sin(a) * math.cos(b) * radius * narrow, -math.cos(a) * math.cos(b) * radius * narrow, math.sin(b) * radius * tall))
        normal = Vector((point.x, point.y, point.z / tall ** 2)).normalized()
        dome(size, size * 0.16, Vector(location) + point, spot_colour, rotation=normal.to_track_quat("Z", "Y").to_euler(), segments=dots, roughness=0.3)
    high = Vector((-0.42, -0.62, 0.66)).normalized()
    dome(radius * 0.24, radius * 0.03, Vector(location) + Vector((high.x * radius * 0.88, high.y * radius * 0.88, high.z * radius * tall * 0.94)), WHITE, rotation=high.to_track_quat("Z", "Y").to_euler(), stretch=0.6, segments=10, roughness=0.2)


def stand_in_egg(shell_colour="FFF3D6", spot_colour="FF6A3D"):
    """For the photos only: an egg the size of the game's on the cushion."""
    egg(1.7, (0, 0, CUSHION_TOP - 0.15 + 1.7 * 1.36), shell_colour, spot_colour)


# ---------------------------------------------------------------------------------------------------
# Houses. Each is built on the game's own footprint: 29 wide (x), 16 deep (y), its front wall at y = -8.
# ---------------------------------------------------------------------------------------------------
def walls(width, depth, height, colour, x=0.0, y=0.0):
    box((width, depth, height), (x, y, height / 2), colour, bevel=0.45)
    box((width + 0.5, depth + 0.5, 1.5), (x, y, 0.75), STONE_PALE, bevel=0.2, segments=1)
    slab((width + 0.7, depth + 0.7, 0.8), (x, y, height - 0.4), TRIM)


def window(x, z, w=3.4, h=4.4, y=-8.0, trim=TRIM, shutters=None, flowers=None, round_top=False, bars=2, fine=False):
    """A window on a wall that looks towards -Y: (x, z) is its middle, y the wall. `fine` is for the ground
    floor, which players stand in front of: rounded edges cost triangles."""
    if round_top:
        prism(arch(w + 1.0, h + 1.0, 5 if fine else 4), 0.6, trim, location=(x, y, z - h / 2 - 0.5), bevel=0.12 if fine else 0.0)
        prism(arch(w, h, 5 if fine else 4), 0.3, GLASS, location=(x, y - 0.25, z - h / 2), roughness=0.25)
    elif fine:
        box((w + 1.0, 0.6, h + 1.0), (x, y, z), trim, bevel=0.2, segments=1)
        slab((w, 0.3, h), (x, y - 0.25, z), GLASS, roughness=0.25)
    else:
        slab((w + 1.0, 0.6, h + 1.0), (x, y, z), trim)
        slab((w, 0.3, h), (x, y - 0.25, z), GLASS, roughness=0.25)
    if bars:
        slab((0.24, 0.14, h - 0.06), (x, y - 0.42, z), trim)
    if bars > 1:
        slab((w - 0.06, 0.14, 0.24), (x, y - 0.42, z - h * 0.06), trim)
    if fine:
        box((w + 1.7, 0.9, 0.42), (x, y - 0.35, z - h / 2 - 0.56), trim, bevel=0.12, segments=1)
    else:
        slab((w + 1.7, 0.9, 0.42), (x, y - 0.35, z - h / 2 - 0.56), trim)
    if shutters:
        for side in (-1, 1):
            slab((1.15, 0.28, h + 0.5), (x + side * (w / 2 + 1.2), y - 0.3, z), shutters)
    if flowers:
        flower_box(x, y - 0.95, z - h / 2 - 0.85, w + 1.2, flowers, fine)


def round_window(x, z, radius, y=-8.0, trim=TRIM, emblem=None):
    tube(radius + 0.5, 0.7, (x, y + 0.35, z), (0, -1, 0), trim, vertices=14)
    tube(radius, 0.2, (x, y - 0.3, z), (0, -1, 0), GLASS, vertices=14, roughness=0.25)
    if emblem:
        star(radius * 0.72, (x, y - 0.5, z), emblem, depth=0.22, roughness=0.3)
    else:
        slab((0.22, 0.12, radius * 1.96), (x, y - 0.52, z), trim)
        slab((radius * 1.96, 0.12, 0.22), (x, y - 0.52, z), trim)


def door(x, colour, w=4.4, h=7.6, y=-8.0, trim=TRIM, flat_top=False, double=False):
    """A door in a wall that looks towards -Y, with a low step in front of it."""
    outline = (lambda width, height: [(width / 2, 0), (width / 2, height), (-width / 2, height), (-width / 2, 0)]) if flat_top else arch
    prism(outline(w + 1.3, h + 0.65), 0.7, trim, location=(x, y, 0), bevel=0.12)
    prism(outline(w, h), 0.34, colour, location=(x, y - 0.33, 0))
    if double:
        slab((0.2, 0.14, h - 0.3), (x, y - 0.53, h / 2 - 0.1), shade(colour, -0.3))
        for side in (-1, 1):
            bud(0.3, (x + side * 0.6, y - 0.62, h * 0.42), GOLD)
    else:
        bud(0.32, (x + w * 0.3, y - 0.62, h * 0.42), GOLD)
        tube(w * 0.2, 0.16, (x, y - 0.46, h - w * 0.42), (0, -1, 0), GLASS, vertices=10, roughness=0.25)
    box((w + 2.2, 1.3, 0.36), (x, y - 0.55, 0.16), STONE, bevel=0.14, segments=1)  # low enough to walk over


def canopy(x, z, width, colours, y=-8.0, reach=3.0, drop=1.2):
    """A striped awning over a shop front: overhead, out of everybody's way."""
    count = max(3, round(width / 1.8))
    each = width / count
    angle, length = math.atan2(drop, reach), math.hypot(reach, drop)
    for index in range(count):
        cx = x - width / 2 + each * (index + 0.5)
        colour = colours[index % 2]
        slab((each, length + 0.2, 0.32), (cx, y - reach / 2, z - drop / 2), colour, rotation=(angle, 0, 0))
        slab((each, 0.26, 0.85), (cx, y - reach - 0.02, z - drop - 0.3), colour)


def chimney(x, y, z, height):
    with roofing():
        box((2.4, 2.4, height), (x, y, z + height / 2), "EADFC8", bevel=0.2, segments=1)
        slab((3.0, 3.0, 0.7), (x, y, z + height), STONE_DARK)
        tube(0.7, 0.9, (x, y, z + height + 0.3), UP, "C96A4A", vertices=6)


def hanging_sign(x, z, colour, y=-8.0, icon=GOLD):
    """A round sign on an arm, across the street: overhead."""
    slab((0.3, 3.2, 0.3), (x, y - 1.6, z + 1.9), IRON)
    for dy in (-1.0, -2.4):
        slab((0.1, 0.1, 0.6), (x, y + dy, z + 1.55), IRON)
    tube(1.5, 0.4, (x - 0.2, y - 1.7, z), (1, 0, 0), WOOD_DARK, vertices=12)
    tube(1.2, 0.5, (x - 0.25, y - 1.7, z), (1, 0, 0), colour, vertices=12)
    for side in (-1, 1):
        star(0.75, (x + side * 0.3, y - 1.7, z), icon, depth=0.12, rotation=(0, 0, side * math.pi / 2), roughness=0.3)


def wall_lantern(x, z, y=-8.0):
    slab((0.3, 0.9, 0.2), (x, y - 0.45, z + 0.75), IRON)
    box((0.8, 0.8, 1.1), (x, y - 0.8, z), "FFE9A8", bevel=0.2, segments=1, emission=1.0)
    tube(0.7, 0.45, (x, y - 0.8, z + 0.5), UP, IRON, tip=0.1, vertices=6)


def gable(width, depth, z, rise, colour, x=0.0, y=0.0, ridge="x", over=1.3, ends=0.45, thick=0.9, wall=None):
    """A pitched roof on a block whose walls end at z. ridge "x": the ridge runs along the front and the eaves
    hang over the front and the back. ridge "y": the gable end looks at the square."""
    with roofing():
        return _gable(width, depth, z, rise, colour, x, y, ridge, over, ends, thick, wall)


def _gable(width, depth, z, rise, colour, x, y, ridge, over, ends, thick, wall):
    span, length = (depth, width) if ridge == "x" else (width, depth)
    slope = rise / (span / 2)
    reach, eave, run = span / 2 + over, z - over * slope, length + 2 * ends
    outline = [(-reach, eave), (0, z + rise), (reach, eave), (reach, eave + thick), (0, z + rise + thick), (-reach, eave + thick)]
    prism(outline, run, colour, location=(x, y, 0), axis=ridge, bevel=0.22)
    if wall:  # the wall under it, at both ends
        prism([(-span / 2, z - 0.1), (span / 2, z - 0.1), (0, z + rise - 0.1)], length - 0.5, wall, location=(x, y, 0), axis=ridge)
    along = Vector((1, 0, 0)) if ridge == "x" else Vector((0, 1, 0))
    tube(0.45, run + 0.3, Vector((x, y, z + rise + thick - 0.08)) - along * (run + 0.3) / 2, along, shade(colour, -0.18), vertices=6)
    pitch, long = math.atan(slope), math.hypot(reach, rise + over * slope)
    for share in (0.3, 0.64):  # two lighter rows across each slope, for tiles
        for side in (-1, 1):
            across, height = side * reach * (1 - share), eave + thick + (z + rise - eave) * share + 0.02
            if ridge == "x":
                slab((run + 0.04, long * 0.11, 0.14), (x, y + across, height), shade(colour, 0.14), rotation=(-side * pitch, 0, 0))
            else:
                slab((long * 0.11, run + 0.04, 0.14), (x + across, y, height), shade(colour, 0.14), rotation=(0, side * pitch, 0))


def hip(width, depth, z, rise, colour, x=0.0, y=0.0, over=1.2, thick=0.8):
    """A roof that slopes to all four sides."""
    with roofing():
        _hip(width, depth, z, rise, colour, x, y, over, thick)


def _hip(width, depth, z, rise, colour, x, y, over, thick):
    w, d = width / 2 + over, depth / 2 + over
    r = max(w - d, 0.0)
    if over:
        box((2 * w, 2 * d, thick), (x, y, z + thick / 2 - 0.2), shade(colour, -0.16), bevel=0.25, segments=1)
    base = z + (thick - 0.25 if over else 0.0)
    mesh([(-w + 0.2, -d + 0.2, base), (w - 0.2, -d + 0.2, base), (w - 0.2, d - 0.2, base), (-w + 0.2, d - 0.2, base), (-r, 0, base + rise), (r, 0, base + rise)],
         [(0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4), (3, 2, 1, 0)], colour, location=(x, y, 0), bevel=0.2)
    tube(0.45, 2 * r + 0.8, (x - r - 0.4, y, base + rise - 0.1), (1, 0, 0), shade(colour, -0.18), vertices=6)


def dormer(x, height, wall, roof):
    """A little window house on the front slope of a roof."""
    with roofing():
        box((3.8, 4.4, 4.6), (x, -3.8, height + 2.9), wall, bevel=0.2, segments=1)
        prism([(-2.6, 0), (0, 1.8), (2.6, 0), (2.6, 0.55), (0, 2.4), (-2.6, 0.55)], 5.2, roof, location=(x, -3.9, height + 4.9))
        slab((2.6, 0.5, 2.5), (x, -6.0, height + 3.8), TRIM)
        slab((1.9, 0.2, 1.8), (x, -6.22, height + 3.8), GLASS, roughness=0.25)


def back_windows(height, xs=(-9.2, 0.0, 9.2)):
    """Plain windows on the wall nobody walks past: the south row shows its back in the photo from above."""
    z = 13.6
    while z + 3.6 < height:
        for x in xs:
            slab((4.2, 0.4, 5.2), (x, 8.0, z), TRIM)
            slab((3.3, 0.3, 4.3), (x, 8.12, z), GLASS, roughness=0.25)
        z += 7


def flag(x, y, z, colour, height=5.0):
    with roofing():
        tube(0.14, height, (x, y, z), UP, GOLD_DARK, vertices=4)
        prism([(0, 0), (3.2, -0.9), (0, -1.9)], 0.12, colour, location=(x + 0.1, y, z + height - 0.1))
        bud(0.28, (x, y, z + height + 0.1), GOLD)


def cottage(height, wall, roof, m=1, accent=None, petal=PETALS[0], back=False):
    """A wide cottage: the roof slopes to the square, with two dormers, a porch and a chimney."""
    accent = accent or shade(roof, -0.1)
    walls(29, 16, height, wall)
    gable(29, 16, height, 7.0, roof, ridge="x", wall=wall)
    door(0, accent)
    prism([(-3.5, 0), (3.5, 0), (3.5, 0.5), (0, 2.3), (-3.5, 0.5)], 2.6, roof, location=(0, -9.1, 8.8), bevel=0.15)
    for side in (-1, 1):
        slab((0.3, 2.0, 0.3), (side * 3.0, -9.0, 8.6), WOOD_DARK)
        window(side * 9.2, 5.6, shutters=accent, flowers=petal, fine=True)
        dormer(side * 6.6, height, wall, roof)
    z, row = 13.6, 0
    while z + 3.6 < height:
        for x in (-9.2, 0.0, 9.2):
            window(x, z, shutters=accent, round_top=row % 2 == 1, flowers=petal if row == 0 and x == 0 else None, bars=2 if row == 0 else 1)
        z, row = z + 7, row + 1
    chimney(m * 10.0, 3.6, height + 2.2, 7.8)
    if back:
        back_windows(height)


def shop(height, wall, roof, m=1, awning=(RED, TRIM), accent=None, sign=GOLD, rise=8.5, petal=PETALS[3], back=False):
    """A shop: its gable looks at the square, with a big window under a striped awning and a hanging sign."""
    accent = accent or shade(roof, -0.1)
    walls(29, 16, height, wall)
    gable(29, 16, height, rise, roof, ridge="y", over=0.45, ends=1.1, wall=wall)
    round_window(0, height + rise * 0.36, 1.6, y=-7.75)
    wx = -5.0 * m
    box((12.6, 0.7, 6.9), (wx, -8.0, 5.05), accent, bevel=0.22, segments=1)
    slab((11.4, 0.3, 5.0), (wx, -8.28, 5.7), GLASS, roughness=0.25)
    for dx in (-1.9, 1.9):
        slab((0.26, 0.16, 5.0), (wx + dx, -8.45, 5.7), TRIM)
    box((13.2, 1.1, 0.5), (wx, -8.35, 3.0), TRIM, bevel=0.14, segments=1)
    for index, colour in enumerate((PETALS[0], GOLD, TEAL)):  # wares in the window
        bud(0.8, (wx + (index - 1) * 3.6, -8.5, 4.05), colour)
    door(8.7 * m, accent, w=4.0, h=7.4, flat_top=True)
    canopy(wx, 10.3, 13.4, awning)
    hanging_sign(8.7 * m, 11.0, wall, icon=sign)
    z, row = 15.0, 0
    while z + 3.6 < height:
        for x in (-9.2, 0.0, 9.2):
            window(x, z, round_top=True, flowers=petal if row == 0 and x != 0 else None, bars=2 if row == 0 else 1)
        z, row = z + 7, row + 1
    if back:
        back_windows(height)


def twin(height, wall=(SKY, BUTTER), roof=(ROOF_ORANGE, ROOF_TEAL), m=1, drop=4.0, petal=PETALS[2], awning=(ROOF_BLUE, TRIM), back=False):
    """Two narrow houses on one footprint, each with its own colours, height and gable."""
    for index, cx in enumerate((-7.25 * m, 7.25 * m)):
        tall = height - index * drop
        walls(14.3, 16, tall, wall[index], x=cx)
        gable(14.3, 16, tall, 6.2, roof[index], x=cx, ridge="y", over=0.4, ends=1.0, wall=wall[index])
        round_window(cx, tall + 2.5, 1.15, y=-7.75)
        towards = (1 if index == 0 else -1) * m  # the doors stand by the outer walls
        door(cx - towards * 3.3, shade(roof[index], -0.1), w=3.5, h=7.0)
        window(cx + towards * 3.2, 5.4, w=3.0, h=4.0, flowers=petal if index == 0 else None, fine=True)
        if index == 1:
            canopy(cx - towards * 3.3, 9.6, 5.4, awning, reach=2.0, drop=0.8)
        else:
            wall_lantern(cx - towards * 0.3, 7.4)
        z, row = 13.4, 0
        while z + 3.4 < tall:
            for side in (-1, 1):
                window(cx + side * 3.3, z, w=2.8, h=4.0, round_top=(row + index) % 2 == 1, flowers=PETALS[3] if row == 0 and index == 1 and side == towards else None, bars=2 if row == 0 else 1)
            z, row = z + 6.8, row + 1
        if back:
            back_windows(tall, xs=(cx,))
    chimney(-7.25 * m + 3.5, 4.5, height + 0.5, 8.2)


def turret(height, wall, roof, m=1, cone=None, accent=None, petal=PETALS[0], pennant=RED, back=False):
    """A house with a round tower at one corner, under a pointed hat with a flag."""
    accent, cone = accent or shade(roof, -0.1), cone or roof
    cx = -4.2 * m
    walls(20.6, 16, height, wall, x=cx)
    gable(20.6, 16, height, 6.6, roof, x=cx, ridge="x", wall=wall)
    door(cx, accent)
    for side in (-1, 1):
        window(cx + side * 6.4, 5.6, w=3.0, flowers=petal if side * m < 0 else None, fine=True)
    z = 13.6
    while z + 3.6 < height:
        for x in (cx - 6.4, cx, cx + 6.4):
            window(x, z, w=3.0, shutters=accent if x == cx else None, bars=2 if z < 14 else 1)
        z += 7
    dormer(cx, height, wall, roof)
    chimney(cx - 6.5 * m, 3.6, height + 2.0, 7.4)
    tx, ty, radius, top = 9.7 * m, -3.25, 4.7, height + 6.0
    tube(radius, top, (tx, ty, 0), UP, shade(wall, 0.35), vertices=16)
    tube(radius + 0.35, 1.5, (tx, ty, 0), UP, STONE_PALE, vertices=16)
    tube(radius + 0.3, 0.8, (tx, ty, top - 0.8), UP, TRIM, vertices=16)
    tube(radius + 0.15, 0.6, (tx, ty, 9.8), UP, TRIM, vertices=16)
    with roofing():
        lathe([(0, 11.5), (1.0, 9.0), (3.0, 5.0), (5.6, 1.2), (6.2, 0.0), (5.6, -0.4), (0, -0.4)], cone, segments=16, location=(tx, ty, top))
    flag(tx, ty, top + 11.2, pennant, height=3.4)
    z = 6.4
    while z + 3 < top - 1:
        window(tx, z, w=1.9, h=3.6, y=ty - radius + 0.12, round_top=True, bars=False)
        z += 8.2
    if back:
        back_windows(height, xs=(cx - 6.4, cx + 6.4))


def inn(height, wall, roof, m=1, petal=PETALS[3], sign=ROOF_BLUE, back=False):
    """A half-timbered inn: a stone ground floor, an upper floor that juts out over it, dark beams, a hipped roof."""
    upper, front = height - 9.6, -8.6
    box((29, 16, 10.0), (0, 0, 5.0), "EFE6D2", bevel=0.45)
    box((29.5, 16.5, 1.5), (0, 0, 0.75), STONE, bevel=0.2, segments=1)
    box((29.0, 16.6, upper), (0, -0.3, 9.6 + upper / 2), wall, bevel=0.4)
    for z in (10.05, height - 0.45):
        slab((29.3, 0.4, 0.85), (0, front - 0.1, z), WOOD_DARK)
    for x in (-14.15, -7.1, 0.0, 7.1, 14.15):
        slab((0.8, 0.4, upper), (x, front - 0.1, 9.6 + upper / 2), WOOD_DARK)
    for side in (-1, 1):
        slab((0.6, 0.38, 6.2), (side * 10.65, front - 0.08, 12.6), WOOD_DARK, rotation=(0, side * 0.86, 0))
        window(side * 9.4, 5.4, w=3.8, h=4.2, trim=WOOD_LIGHT, flowers=petal, fine=True)
        wall_lantern(side * 4.4, 7.6)
    door(0, WOOD, w=5.4, h=7.9, trim=WOOD_DARK, double=True)
    z, row = 14.4 if upper < 15 else 15.6, 0
    while z + 3.2 < height - 0.6:
        for x in (-10.65, -3.55, 3.55, 10.65):
            if not (row == 0 and abs(x) > 10):  # the braces fill the end bays of the first row
                window(x, z, w=2.9, h=3.8, y=front, trim=WOOD_LIGHT)
        z, row = z + 6.8, row + 1
    hip(29, 16.6, height, 7.2, roof, y=-0.3)
    chimney(m * 8.5, 2.2, height + 1.4, 8.6)
    hanging_sign(-m * 12.2, 11.6, sign, y=front)
    if back:
        back_windows(height)


def giant_gem(radius, location):
    lathe([(0, radius * 1.62), (radius * 0.62, radius * 1.62), (radius, radius * 1.2), (0, 0)], "3FE0FF", segments=8, smooth=False, location=location, roughness=0.2, emission=0.5)
    lathe([(0, radius * 1.66), (radius * 0.4, radius * 1.66), (0, radius * 1.4)], "C9F9FF", segments=8, smooth=False, location=location, roughness=0.2, emission=0.6)


def hall(height, wall, roof, icon="egg", accent=None, pennant=RED, petal=PETALS[0]):
    """The big house in the middle of a row: pillars, a tall doorway, a pediment, and a giant ornament on its
    roof that says what the row is for (an egg over the hatchery, a gem over the shops, a star over the boards)."""
    accent = accent or shade(roof, -0.08)
    walls(29, 16, height, wall)
    for x in (-13.3, -5.5, 5.5, 13.3):
        box((1.9, 0.9, height - 2.4), (x, -8.15, 1.4 + (height - 2.4) / 2), TRIM, bevel=0.2, segments=1)
        slab((2.5, 1.2, 0.9), (x, -8.2, height - 1.3), TRIM)
    door(0, accent, w=6.2, h=9.6, double=True)
    round_window(0, min(height - 6.0, 15.4), 1.9, emblem=GOLD)
    for side in (-1, 1):
        window(side * 9.4, 6.4, w=3.2, h=6.4, round_top=True, fine=True)
        wall_lantern(side * 4.9, 8.0)
        z = 16.6
        while z + 3.8 < height - 1.5:
            window(side * 9.4, z, w=3.2, h=4.6, round_top=True, flowers=petal if z < 17 else None)
            z += 7.2
        flag(side * 13.6, -7.3, height + 1.3, pennant)
    hip(27, 14, height + 1.2, 5.0, roof, over=0.0)
    top = height + 7.2
    with roofing():
        box((30.0, 17.0, 1.7), (0, 0, height + 0.55), TRIM, bevel=0.3, segments=1)
        prism([(-7.6, 0), (7.6, 0), (7.6, 1.2), (0, 4.8), (-7.6, 1.2)], 1.4, TRIM, location=(0, -7.7, height + 1.3), bevel=0.2)
        prism([(-5.6, 0.55), (5.6, 0.55), (0, 3.7)], 0.4, roof, location=(0, -8.35, height + 1.4))
        tube(4.3, top - height - 4.4, (0, 0.5, height + 4.4), UP, TRIM, vertices=16)
        if icon == "egg":
            hoop(3.3, 0.85, (0, 0.5, top + 0.3), GOLD, segments=16, around=4, roughness=0.3)
            egg(4.0, (0, 0.5, top + 4.0 * 1.36 - 0.5), "FFF3D6", "FF6FB5", detail=1)
        elif icon == "gem":
            hoop(2.2, 0.7, (0, 0.5, top + 0.3), GOLD, segments=12, around=4, roughness=0.3)
            giant_gem(4.2, (0, 0.5, top + 0.2))
        else:
            tube(0.5, 2.4, (0, 0.5, top), UP, GOLD_DARK, vertices=8)
            star(4.6, (0, 0.5, top + 5.6), GOLD, depth=1.3, roughness=0.3)
            star(2.9, (0, -0.6, top + 5.6), GOLD_LIGHT, depth=0.5, roughness=0.3)


def tower(roof, pennant):
    """A corner tower: the game's is a pillar 11 across and 40 high under a ball. Its door looks at the square."""
    sides = 20
    tube(11.6, 3.0, (0, 0, 0), UP, STONE, vertices=sides)
    tube(11.0, 40.0, (0, 0, 0), UP, STONE_PALE, tip=10.4, vertices=sides)
    tube(10.95, 1.2, (0, 0, 19.4), UP, STONE, vertices=sides)
    tube(10.6, 2.8, (0, 0, 37.4), UP, STONE, tip=12.6, vertices=sides)
    lathe([(0, 62.5), (1.5, 58.0), (4.4, 52.0), (8.4, 46.2), (12.4, 41.8), (13.7, 40.2), (12.7, 39.6), (0, 39.6)], roof, segments=sides)
    lathe([(12.6, 41.75), (13.85, 40.2), (12.8, 39.5)], shade(roof, -0.18), segments=sides)
    for upper, lower in (((5.1, 50.9), (6.5, 48.95)), ((9.2, 45.4), (10.5, 43.95))):  # lighter rows round the hat
        lathe([(upper[0] + 0.12, upper[1]), (lower[0] + 0.12, lower[1])], shade(roof, 0.14), segments=sides)
    flag(0, 0, 62.3, pennant, height=4.6)
    prism(arch(5.6, 8.6), 1.4, STONE_DARK, location=(0, -11.2, 0), bevel=0.15)
    prism(arch(4.2, 7.6), 0.4, WOOD, location=(0, -11.85, 0))
    slab((0.2, 0.14, 7.0), (0, -12.07, 3.6), WOOD_DARK)
    bud(0.3, (0.7, -12.15, 3.4), GOLD)
    for z in (14.0, 24.5, 33.0):
        window(0, z, w=2.6, h=4.6, y=-10.95 + z * 0.014, round_top=True)


# ---------------------------------------------------------------------------------------------------
# The middle: the fountain and the giant golden cannon (Marketplace.buildStatue)
# ---------------------------------------------------------------------------------------------------
def fountain():
    """The game's fountain is 14 from the middle and 1.6 high, its pedestal 5 and up to 6. The cannon on it is
    the game's too: a base 7 x 9, wheels 7.4 across at x = +-4.2, a barrel 17 long aimed 25 degrees up and north."""
    lathe([(12.4, 1.1), (12.4, 1.75), (12.8, 2.0), (13.7, 2.0), (14.1, 1.75), (14.1, 0.75), (14.7, 0.5), (14.7, 0.0)], STONE_PALE, segments=40)
    lathe([(14.16, 1.5), (14.16, 1.0)], BLUE, segments=40)  # a band of tiles round the wall
    for index in range(16):
        x, y = ring(index * 22.5, 14.22)
        ball(0.34, (x, y, 1.25), GOLD, scale=(1, 1, 1), segments=6, roughness=0.3)
    lathe([(0, 6.0), (4.6, 6.0), (5.2, 5.7), (5.2, 5.2), (4.4, 4.9), (4.2, 2.6), (5.0, 2.2), (5.7, 1.9), (5.7, 1.2), (0, 1.2)], STONE_PALE, segments=24)
    hoop(5.22, 0.2, (0, 0, 5.45), GOLD, segments=24, roughness=0.3)
    hoop(5.72, 0.16, (0, 0, 1.95), GOLD, segments=24, roughness=0.3)
    with into("Water"):
        tube(12.45, 0.4, (0, 0, 1.15), UP, WATER, vertices=40, roughness=0.15)
        lathe([(0, 1.58), (8.6, 1.58), (9.0, 1.54)], shade(WATER, 0.25), segments=32, roughness=0.15)
    for index in range(4):  # four gold spouts, and the water they throw into the basin
        dx, dy = ring(index * 90 + 45, 1.0)
        tube(0.5, 1.3, (dx * 3.9, dy * 3.9, 4.0), (dx, dy, 0.2), GOLD, tip=0.6, vertices=8, roughness=0.3)
        with into("Water"):
            path = [Vector((dx * reach, dy * reach, 4.25 + 0.9 * step - 0.62 * step * step)) for step, reach in ((0.0, 5.1), (0.7, 6.2), (1.4, 7.3), (2.0, 8.2), (2.6, 9.0))]
            for a, b in zip(path, path[1:]):
                tube(0.3, (b - a).length + 0.1, a, b - a, WATER_LIGHT, vertices=5, roughness=0.15)
            ball(0.7, (dx * 9.1, dy * 9.1, 1.6), WHITE, scale=(1, 1, 0.5), segments=6)
    # The cannon.
    box((7.0, 9.0, 2.0), (0, 0, 7.0), WOOD, bevel=0.5)
    for side in (-1, 1):
        box((1.0, 7.4, 2.6), (side * 2.6, 0.2, 8.9), WOOD_LIGHT, bevel=0.3, segments=1)
        x = side * 4.2
        tube(3.7, 1.2, (x - side * 0.6, 0, 9.7), (side, 0, 0), WOOD_DARK, vertices=20)
        tube(3.78, 0.5, (x - side * 0.25, 0, 9.7), (side, 0, 0), GOLD_DARK, vertices=20, roughness=0.3)
        tube(3.0, 1.36, (x - side * 0.6, 0, 9.7), (side, 0, 0), WOOD_LIGHT, vertices=20)
        for spoke in range(3):
            slab((0.3, 5.8, 0.5), (x + side * 0.72, 0, 9.7), WOOD_DARK, rotation=(spoke * math.pi / 3, 0, 0))
        tube(1.05, 1.9, (x - side * 0.6, 0, 9.7), (side, 0, 0), GOLD, vertices=10, roughness=0.3)
    aim = Vector((0, math.cos(math.radians(25)), math.sin(math.radians(25))))
    centre = Vector((0, 1.5, 12.4))
    start = centre - aim * 8.5
    tube(2.5, 17.0, start, aim, GOLD, tip=2.15, vertices=20, roughness=0.3)
    ball(2.5, start, GOLD, segments=16, roughness=0.3)
    ball(0.95, start - aim * 2.9, GOLD_DARK, segments=8, roughness=0.3)
    tube(0.5, 0.9, start - aim * 2.5, aim, GOLD_DARK, vertices=8, roughness=0.3)
    for along, radius in ((1.6, 2.72), (11.4, 2.5), (13.4, 2.45)):
        tube(radius, 0.7, start + aim * along, aim, GOLD_LIGHT, vertices=20, roughness=0.3)
    tube(2.75, 1.5, start + aim * 15.6, aim, GOLD_LIGHT, tip=2.9, vertices=20, roughness=0.3)
    tube(1.9, 0.12, start + aim * 17.02, aim, INK, vertices=16)
    side_up = Vector((-0.5, -aim.z * 0.82, aim.y * 0.82)).normalized()
    turn = Matrix((aim.cross(side_up), aim, side_up)).transposed().to_euler()
    ball(1.0, centre + side_up * 2.3 + aim * 1.5, WHITE, scale=(0.3, 3.4, 0.12), rotation=turn, segments=8, roughness=0.2)  # a wet highlight along the barrel
    fuse = start + Vector((0, -0.2, 2.35))
    tube(0.16, 1.5, fuse, (0.2, -0.3, 1), "C4AA78", vertices=5)
    ball(0.5, fuse + Vector((0.3, -0.45, 1.7)), "FF8A1F", segments=8, emission=1.6)
    ball(0.28, fuse + Vector((0.3, -0.45, 1.7)), "FFE23A", segments=6, emission=1.8)


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


def cloud():
    for x, y, z, radius in ((0, 0, 0, 1.0), (-1.15, 0.1, -0.2, 0.72), (1.2, -0.1, -0.15, 0.8), (0.45, 0.4, 0.4, 0.66), (-0.5, -0.3, 0.3, 0.6), (2.05, 0, -0.38, 0.5), (-1.95, 0, -0.4, 0.46)):
        ball(radius, (x, y, z * 0.8), WHITE, scale=(1, 1, 0.78), segments=16, roughness=1.0)


# ---------------------------------------------------------------------------------------------------
# The landmark shells. Each is built around its own origin, its front towards -Y. A board the game writes on
# has a flat, empty face 0.05 behind the face of the game's own part: FACES says where (x, z of its middle,
# the y of the game's face, width, height).
# ---------------------------------------------------------------------------------------------------
def framed(width, height, z, face_y, colour, beam, depth=1.0, thick=0.9, back=WOOD_DARK, lift=0.3):
    """A board: a back, a flat face `width` x `height` whose front is at face_y + 0.05, and four beams round it."""
    box((width + 2 * thick - 0.2, depth * 0.7, height + 2 * thick - 0.2), (0, face_y + 0.05 + depth * 0.35 + 0.1, z), back, bevel=0.2, segments=1)
    slab((width, 0.3, height), (0, face_y + 0.05 + 0.15, z), colour, roughness=0.8)
    middle = face_y + 0.05 - lift + depth / 2
    for side in (-1, 1):
        box((width + 2 * thick, depth, thick), (0, middle, z + side * (height + thick) / 2), beam, bevel=0.22, segments=1, roughness=0.4)
        box((thick, depth, height), (side * (width + thick) / 2, middle, z), beam, bevel=0.22, segments=1, roughness=0.4)


def egg_pedestal():
    """What an egg stands on: stone steps, a short column with a gold band and a fat gold cushion, 6.4
    across at its foot. The cushion's top, flat for 3.4 across, is CUSHION_TOP up. (The island's.)"""
    tube(3.2, 0.6, (0, 0, 0), UP, STONE_DARK, vertices=20)
    tube(2.6, 0.5, (0, 0, 0.6), UP, STONE, vertices=20)
    tube(1.9, 0.9, (0, 0, 1.1), UP, STONE_PALE, vertices=16)
    hoop(1.92, 0.24, (0, 0, 1.55), GOLD, roughness=0.3)
    tube(2.5, 0.35, (0, 0, 1.9), UP, STONE, vertices=20)
    box((4.4, 4.4, 0.95), (0, 0, CUSHION_TOP - 0.475), GOLD, bevel=0.47, segments=3, roughness=0.4)
    box((4.52, 4.52, 0.24), (0, 0, CUSHION_TOP - 0.475), GOLD_DARK, bevel=0.1, segments=1)
    for x in (-1, 1):
        for y in (-1, 1):
            ball(0.4, (x * 2.05, y * 2.05, CUSHION_TOP - 0.62), GOLD_DARK, segments=8)


STALL_FACE = {"x": 0, "z": 11.8, "y": -2.4, "width": 10, "height": 2.4}


def stall(stripes=None):
    """A market stall on the game's: a counter 10 wide, a striped awning 9.6 up that slopes to the customer, a
    sign over it. The awning's two sets of stripes are meshes of their own, white, for the game to colour:
    A is the first colour of the game's list (the 2nd, 4th and 6th stripe), B the second (the other four)."""
    box((10.8, 3.5, 0.5), (0, 0, 0.25), WOOD_DARK, bevel=0.15, segments=1)
    box((10.4, 3.2, 2.9), (0, 0, 1.55), WOOD, bevel=0.35)
    box((11.2, 4.0, 0.5), (0, -0.1, 3.05), WOOD_LIGHT, bevel=0.2)
    for x in (-3.45, 0, 3.45):
        slab((0.3, 0.2, 2.1), (x, -1.62, 1.6), WOOD_DARK)
    for side in (-1, 1):
        tube(0.36, 10.5, (side * 4.9, 1.3, 0), UP, WOOD_DARK, vertices=8)
        tube(0.36, 13.3, (side * 4.9, -1.5, 0), UP, WOOD_DARK, vertices=8)
        slab((0.3, 5.4, 0.3), (side * 4.9, -0.75, 9.25), WOOD_DARK, rotation=(math.radians(14), 0, 0))
        bud(0.42, (side * 4.9, -1.5, 13.45), GOLD)
    slope = math.radians(14)
    for index in range(7):  # the game's stripes are 1.5 wide, at x = -4.5 ... 4.5
        x = (index - 3) * 1.5
        name, colour = ("StallStripesA", stripes[0] if stripes else WHITE) if index % 2 else ("StallStripesB", stripes[1] if stripes else WHITE)
        with part(name):
            box((1.5, 6.0, 0.4), (x, -0.6, 9.6), colour, bevel=0.14, rotation=(slope, 0, 0), segments=1)
            slab((1.5, 0.34, 0.75), (x, -3.52, 8.42), colour)
            tube(0.75, 0.34, (x, -3.35, 8.05), (0, -1, 0), colour, vertices=10)
    framed(10, 2.4, 11.8, -2.4, BOARD_PLUM, WOOD_LIGHT, depth=0.8, thick=0.6, lift=0.25)
    for side in (-1, 1):
        star(0.5, (side * 5.3, -2.75, 13.3), GOLD, depth=0.2, roughness=0.3)
    # At the two ends of the counter, clear of what the game stands on it: a pink potion and a pile of coins.
    ball(0.6, (-4.3, 0.1, 3.85), "FF5FA2", segments=8, roughness=0.2)
    tube(0.22, 0.55, (-4.3, 0.1, 4.3), UP, "FFD0E4", vertices=6)
    bud(0.26, (-4.3, 0.1, 4.95), WOOD)
    for index in range(3):
        tube(0.55, 0.22, (4.25 + index * 0.08, -0.2, 3.3 + index * 0.22), UP, GOLD, vertices=10, roughness=0.3)


LEADERBOARD_FACE = {"x": 0, "z": 10.5, "y": -0.4, "width": 15, "height": 13}


def leaderboard(trim=None):
    """A leaderboard: the game's board is 15 x 13, its middle 10.5 up, on two posts 6 either side. The rim
    round it and the jewel in its crown are a mesh of their own, white, for the game to colour per board."""
    for side in (-1, 1):
        box((1.7, 1.7, 0.8), (side * 6, 0.1, 0.4), STONE, bevel=0.2, segments=1)
        box((1.1, 1.1, 2.9), (side * 6, 0.1, 2.0), GOLD_DARK, bevel=0.25, segments=1, roughness=0.4)
    framed(15, 13, 10.5, -0.4, BOARD_PLUM, GOLD, depth=1.0, thick=1.0, back="5A35B0")
    for x in (-8, 8):
        for z in (3.5, 17.5):
            ball(0.78, (x, -0.2, z), GOLD_LIGHT, segments=8, roughness=0.3)
    box((5.0, 0.9, 1.0), (0, -0.1, 18.4), GOLD, bevel=0.25, segments=1, roughness=0.3)
    for x, tall in ((-1.8, 1.5), (0.0, 2.1), (1.8, 1.5)):
        tube(0.62, tall, (x, -0.1, 18.8), UP, GOLD, tip=0.0, vertices=6, roughness=0.3)
        bud(0.3, (x, -0.1, 18.85 + tall), GOLD_LIGHT)
    with part("LeaderboardTrim"):
        colour = trim or WHITE
        for side in (-1, 1):
            slab((17.5, 0.5, 0.3), (0, 0.1, 10.5 + side * 7.65), colour)
            slab((0.3, 0.5, 15.6), (side * 8.65, 0.1, 10.5), colour)
        ball(0.5, (0, -0.55, 18.4), colour, scale=(1, 0.6, 1), segments=8, roughness=0.2)


NOTICE_FACE = {"x": 0, "z": 6.0, "y": -0.25, "width": 8.4, "height": 5.0}


def notice_board():
    """A notice board under a little roof: the game's board is 8.4 x 5, its middle 6 up."""
    for side in (-1, 1):
        tube(0.48, 9.6, (side * 4.75, 0, 0), UP, WOOD, vertices=8)
        tube(0.75, 0.6, (side * 4.75, 0, 0), UP, STONE, vertices=8)
    box((9.2, 0.4, 5.8), (0, 0.15, 6.0), WOOD_DARK, bevel=0.12, segments=1)
    slab((8.4, 0.3, 5.0), (0, -0.05, 6.0), BOARD_BLUE, roughness=0.8)
    for z in (3.15, 8.85):
        box((9.9, 0.75, 0.7), (0, -0.1, z), WOOD_LIGHT, bevel=0.16, segments=1)
    prism([(-5.9, 9.4), (0, 10.9), (5.9, 9.4), (5.9, 10.0), (0, 11.55), (-5.9, 10.0)], 2.2, ROOF_RED, bevel=0.14)
    bud(0.36, (0, -1.0, 11.2), GOLD)


def chest():
    """The daily chest: wood with gold bands, a round lid and a big lock. The game's is 5 x 3.4 and 3.8 high."""
    wood = "C97B3C"
    box((5.4, 3.6, 2.7), (0, 0, 1.35), wood, bevel=0.3)
    prism(half_disc(1.8), 5.4, shade(wood, 0.1), location=(0, 0, 2.7), axis="x", bevel=0.12)
    box((5.7, 3.9, 0.5), (0, 0, 2.7), WOOD_DARK, bevel=0.15, segments=1)
    for x in (-1.75, 1.75):
        box((0.6, 3.76, 2.75), (x, 0, 1.38), GOLD, bevel=0.1, segments=1, roughness=0.3)
        prism(half_disc(1.92), 0.6, GOLD, location=(x, 0, 2.7), axis="x", roughness=0.3)
    for x in (-2.72, 2.72):
        prism(half_disc(1.86), 0.25, GOLD_DARK, location=(x, 0, 2.7), axis="x", roughness=0.3)
        slab((0.25, 3.7, 0.4), (x, 0, 0.3), GOLD_DARK)
    box((1.3, 0.5, 1.5), (0, -1.9, 2.55), GOLD, bevel=0.2, segments=1, roughness=0.3)
    ball(0.26, (0, -2.18, 2.7), INK, scale=(1, 0.5, 1), segments=6)
    slab((0.16, 0.12, 0.5), (0, -2.16, 2.3), INK)
    star(0.55, (0, -1.72, 3.65), GOLD_LIGHT, depth=0.16, rotation=(-0.5, 0, 0), roughness=0.3)


def portal():
    """The way back to the base (the island's): a chunky stone arch on two steps. The glowing sheet in it is a
    mesh of its own (PortalSheet) with the same origin, so the game can make it Neon. Built a size too big
    and stood at 0.88: its pillars then stand where the game's do."""
    glow, pale = "8E6BFF", "C7B5FF"
    box((15.5, 6.4, 0.7), (0, 0, 0.35), STONE_DARK, bevel=0.25)
    box((13.4, 4.6, 0.7), (0, 0, 1.0), STONE, bevel=0.25)
    for side in (-1, 1):
        for index in range(3):
            box((2.9, 2.9, 3.0), (side * 5.2, 0, 2.85 + index * 3.0), STONE if index % 2 == 0 else STONE_DARK, bevel=0.4, rotation=(0, 0, rng.uniform(-0.09, 0.09)))
        box((3.4, 3.4, 0.9), (side * 5.2, 0, 10.75), STONE_DARK, bevel=0.3)
        for y in (-1.5, 1.5):
            box((0.5, 0.3, 1.3), (side * 5.2, y, 5.85), pale, bevel=0.1, segments=1, emission=1.2)
    for index in range(7):
        angle = math.radians(index * 30)
        size = (3.5, 3.5, 3.3) if index == 3 else (2.95, 2.9, 2.7)
        box(size, (-math.cos(angle) * 5.2, 0, 11.15 + math.sin(angle) * 5.2), STONE if index % 2 else STONE_DARK, bevel=0.4, rotation=(0, angle - math.pi / 2, 0))
    for y in (-1.8, 1.8):
        ball(0.75, (0, y, 16.35), pale, segments=10, emission=1.4)
    for x, y, radius, length, lean in ((-7.6, -0.6, 0.7, 3.2, -0.3), (-8.5, 0.6, 0.5, 2.0, -0.6), (7.7, 0.4, 0.75, 3.6, 0.3), (8.6, -0.7, 0.5, 2.2, 0.6)):
        tube(radius, length, (x, y, 0), (lean, 0, 1), pale, tip=0.0, vertices=5, roughness=0.15, emission=0.7)
    with part("PortalSheet"):
        box((7.8, 0.4, 9.8), (0, 0, 6.25), glow, bevel=0.05, segments=1, emission=1.0)
        tube(3.95, 0.4, (0, 0.2, 11.15), (0, -1, 0), glow, vertices=24, emission=1.0)
        for radius, depth, x, z, colour in ((3.3, 0.5, 0.0, 8.2, "A68AFF"), (2.4, 0.6, 0.25, 8.45, "BEA8FF"), (1.5, 0.7, -0.1, 8.6, "D9CCFF"), (0.7, 0.8, 0.1, 8.5, "F4F0FF")):
            tube(radius, depth, (x, depth / 2, z), (0, -1, 0), colour, vertices=20, emission=0.8)


HATCHERY_FACE = {"x": 0, "z": 18.0, "y": -0.5, "width": 44, "height": 7}


def hatchery_sign():
    """The hatchery's sign: the game's board is 44 x 7, its middle 18 up, on two posts 20 either side. A row
    of lights along its top and bottom, a big egg over its middle and a small one on each end."""
    for side in (-1, 1):
        x = side * 20
        tube(1.8, 1.0, (x, 0.2, 0), UP, STONE, vertices=12)
        tube(1.35, 0.6, (x, 0.2, 1.0), UP, STONE_PALE, vertices=12)
        tube(0.9, 12.4, (x, 0.2, 1.6), UP, "FFF3D6", vertices=10)
        for z in (4.2, 8.8, 13.2):
            tube(1.02, 0.5, (x, 0.2, z), UP, GOLD, vertices=10, roughness=0.3)
        egg(1.35, (side * 22.6, -0.1, 22.7 + 1.35 * 1.36 - 0.25), ("45B4FF", "7BE36A")[side > 0], ("FFE23A", "FFFFFF")[side > 0], spots=EGG_SPOTS[:8], detail=0)
    framed(44, 7, 18.0, -0.5, BOARD_PLUM, GOLD, depth=1.3, thick=1.2, back="5A35B0", lift=0.4)
    for index in range(12):  # lights, like a fairground's
        x = (index - 5.5) * 3.9
        for z in (22.1, 13.9):
            ball(0.4, (x, -1.0, z), "FFF6C4", segments=6, emission=1.2)
    hoop(1.9, 0.6, (0, -0.1, 22.9), GOLD_DARK, segments=12, roughness=0.3)
    egg(2.4, (0, -0.1, 22.7 + 2.4 * 1.36 - 0.1), "FFF3D6", "FF6FB5", spots=EGG_SPOTS[:8], detail=0)
    for side in (-1, 1):
        star(1.1, (side * 4.6, -0.3, 23.9), GOLD, depth=0.35, roughness=0.3)
        star(0.7, (side * 7.4, -0.3, 23.4), GOLD_LIGHT, depth=0.25, roughness=0.3)


def trade_plaza():
    """The trading plaza (Marketplace.buildTradingPlaza): the round floor the game lays (9 across, a gold ring
    at 6.4), a spot for each trader 4.2 either side, the table with a mini cannon and a gem on it, and four
    lantern posts at the corners. The lanterns' bulbs and the orb over the table stay the game's."""
    lathe([(0, 0.15), (8.7, 0.15), (9.0, 0.0)], "E5566B", segments=40, roughness=0.9)
    band(5.85, 6.4, 0, 360, 0.2, GOLD, steps=40)
    lathe([(0, 0.25), (5.7, 0.25), (5.85, 0.16)], "C93F58", segments=32, roughness=0.9)
    for x, colour in ((4.2, TEAL), (-4.2, GOLD)):  # the game's teal spot is at its own x = -4.2: a shell's x is the other way
        tube(1.5, 0.32, (x, 0, 0), UP, colour, vertices=16, emission=0.6)
        tube(1.05, 0.36, (x, 0, 0), UP, shade(colour, 0.5), vertices=16, emission=0.6)
    tube(1.25, 0.35, (0, 0, 0.25), UP, WOOD_DARK, vertices=10)
    tube(0.55, 2.0, (0, 0, 0.5), UP, WOOD, tip=0.42, vertices=8)
    tube(2.3, 0.4, (0, 0, 2.4), UP, WOOD_LIGHT, vertices=16)
    hoop(2.3, 0.14, (0, 0, 2.6), GOLD, segments=16, roughness=0.3)
    tube(0.34, 1.3, (0.45, 0, 3.12), (1, 0, 0.12), GOLD, tip=0.28, vertices=8, roughness=0.3)  # the mini cannon
    for y in (-0.42, 0.42):
        tube(0.3, 0.16, (0.9, y - 0.08 * (1 if y > 0 else -1), 3.0), (0, 1 if y > 0 else -1, 0), IRON, vertices=8)
    lathe([(0, 0.62), (0.3, 0.62), (0.5, 0.42), (0, 0)], TEAL, segments=6, smooth=False, location=(-1.0, 0, 2.85), roughness=0.2, emission=0.5)  # the gem
    for index in range(4):
        x, y = ring(index * 90 + 45, 7.8)
        tube(0.5, 0.4, (x, y, 0), UP, STONE, vertices=8)
        tube(0.2, 4.1, (x, y, 0.3), UP, IRON, vertices=6)
        tube(0.42, 0.25, (x, y, 4.25), UP, IRON, tip=0.6, vertices=6)
        for turn in range(3):
            dx, dy = ring(turn * 120, 0.72)
            tube(0.05, 1.5, (x + dx, y + dy, 4.45), UP, IRON, vertices=3)
        tube(0.95, 0.6, (x, y, 5.9), UP, IRON, tip=0.12, vertices=6)


HUGE_TOP = 1.6  # where the game's Huge stands on HugePedestal
HUGE_FACE = {"x": 0, "z": 1.65, "y": -3.2, "width": 4.4, "height": 1.3}


def huge_pedestal():
    """What the game pass's Huge stands on (Features/Huge.luau): the game's is 3.4 from its middle and 1 high
    under a top 2.6 and 0.6 high, with a price plate 4.4 x 1.3 in front."""
    dark = "3A3550"
    tube(3.5, 1.0, (0, 0, 0), UP, dark, vertices=24)
    hoop(3.5, 0.2, (0, 0, 0.5), GOLD, segments=24, roughness=0.3)
    tube(2.8, HUGE_TOP - 1.0, (0, 0, 1.0), UP, GOLD, vertices=24, roughness=0.3)
    tube(2.3, 0.06, (0, 0, HUGE_TOP - 0.04), UP, GOLD_LIGHT, vertices=24, roughness=0.3)
    for index in range(8):
        x, y = ring(index * 45 + 22.5, 3.52)
        if abs(index * 45 + 22.5 - 180) > 40:  # not behind the plate
            bud(0.3, (x, y, 0.5), GOLD_LIGHT)
    framed(4.4, 1.3, 1.65, -3.2, BOARD_PLUM, GOLD, depth=0.6, thick=0.35, back=dark, lift=0.2)


CRATE_SIGN_FACE = {"x": 0, "z": 11.0, "y": 2.4, "width": 8.7, "height": 1.9}
CRATE_LIST_FACE = {"x": 0, "z": 7.6, "y": 2.4, "width": 8.7, "height": 4.6}


def crate_stand():
    """The crate stand (Features/Crates.luau): the round floor the game lays (6 across), and behind the game's
    stack of crates two posts with the sign (8.7 x 1.9, 11 up) and the price list (8.7 x 4.6, 7.6 up)."""
    lathe([(0, 0.2), (5.7, 0.2), (6.0, 0.0)], "7A4BC2", segments=32, roughness=0.9)
    band(4.7, 5.15, 0, 360, 0.25, GOLD, steps=32)
    for side in (-1, 1):
        tube(0.75, 0.7, (side * 4.9, 2.6, 0), UP, STONE, vertices=8)
        tube(0.42, 12.8, (side * 4.9, 2.6, 0), UP, WOOD, vertices=8)
        bud(0.5, (side * 4.9, 2.6, 13.0), GOLD)
    box((9.5, 0.4, 7.4), (0, 2.85, 8.65), WOOD_DARK, bevel=0.12, segments=1)
    slab((8.7, 0.3, 1.9), (0, 2.6, 11.0), BOARD_PLUM, roughness=0.8)
    slab((8.7, 0.3, 4.6), (0, 2.6, 7.6), BOARD_PLUM, roughness=0.8)
    for z in (12.3, 4.95):
        box((10.2, 0.8, 0.7), (0, 2.5, z), WOOD_LIGHT, bevel=0.16, segments=1)


def ammo_forge():
    """The Ammo Forge (Features/Ammo.luau), piece for piece on the game's: a round floor 4.9 from its middle and
    0.4 high, the furnace at the back with its fire to the customer, the anvil in front of it, the rack beside
    it. The shells on the anvil and the rack stay the game's. (A shell's x is the other way from the game's.)"""
    lathe([(0, 0.4), (4.5, 0.4), (4.9, 0.22), (4.9, 0.0)], "6A6682", segments=32, roughness=0.9)
    box((4.2, 2.8, 5.2), (1.3, 1.8, 3.0), "D9CFC0", bevel=0.55)
    box((4.5, 3.1, 0.9), (1.3, 1.8, 0.85), STONE_DARK, bevel=0.2, segments=1)
    box((4.5, 3.1, 0.6), (1.3, 1.8, 5.5), STONE_DARK, bevel=0.2, segments=1)
    prism(arch(3.3, 3.1), 0.5, STONE_DARK, location=(1.3, 0.42, 0.75), bevel=0.1)
    prism(arch(2.5, 2.5), 0.3, INK, location=(1.3, 0.24, 0.85))
    prism(arch(2.1, 1.9), 0.3, "FF8A1F", location=(1.3, 0.14, 0.9), emission=1.5)
    prism(arch(1.2, 1.2), 0.3, "FFE23A", location=(1.3, 0.06, 0.92), emission=1.8)
    box((1.5, 1.5, 3.4), (1.3, 2.2, 7.3), "4A4763", bevel=0.2, segments=1)
    box((2.0, 2.0, 0.5), (1.3, 2.2, 9.0), STONE_DARK, bevel=0.15, segments=1)
    box((1.2, 1.0, 1.1), (1.3, -2.0, 0.95), IRON, bevel=0.15, segments=1)
    box((2.8, 1.3, 0.7), (1.3, -2.0, 1.85), IRON, bevel=0.2, segments=1, roughness=0.35)
    tube(0.34, 1.1, (2.6, -2.0, 1.9), (1, 0, 0), IRON, tip=0.0, vertices=6, roughness=0.35)
    box((2.2, 5.6, 1.5), (-2.6, 0, 1.15), WOOD, bevel=0.25)
    box((2.5, 5.9, 0.3), (-2.6, 0, 2.05), WOOD_LIGHT, bevel=0.1, segments=1)
    tube(0.16, 3.0, (3.3, 0.9, 0.4), (0.25, 0.3, 1), WOOD_DARK, vertices=5)  # a hammer against the furnace
    box((1.2, 0.6, 0.6), (4.05, 1.8, 3.3), IRON, bevel=0.12, segments=1, rotation=(0, 0, 0.9))


GUIDE_TOP = 0.8


def guide_plinth():
    """What Captain Kaboom stands on (Features/Story.luau): 3.4 from its middle, 0.8 high."""
    tube(3.4, GUIDE_TOP, (0, 0, 0), UP, STONE, vertices=20)
    tube(3.0, 0.06, (0, 0, GUIDE_TOP - 0.03), UP, STONE_PALE, vertices=20)
    hoop(3.42, 0.16, (0, 0, 0.4), GOLD, segments=20, roughness=0.3)


# For the photos only: what stays the game's own.
def stand_in_huge():
    """The Huge on its pedestal, as Huge.buildShowcase makes it: a barrel 2.4 times a mini cannon's."""
    body, accent = "EBF0FA", "FFCD3C"
    centre = Vector((0, 0, HUGE_TOP + 2.64))
    aim = Vector((0, 1, 0.2)).normalized()
    tube(1.2, 5.28, centre - aim * 2.64, aim, body, vertices=14, emission=0.3)
    for offset in (2.04, 0.48, -1.8):
        tube(1.44, 0.38, centre + aim * offset - aim * 0.19, aim, accent, vertices=14, emission=0.6)
    for side in (-1, 1):
        tube(1.08, 0.6, centre + Vector((side * 1.5, -0.48, -0.84)) - Vector((side * 0.3, 0, 0)), (side, 0, 0), "282828", vertices=12)
        ball(0.43, centre + Vector((side * 0.58, -1.44, 1.0)), WHITE, segments=10)
        ball(0.22, centre + Vector((side * 0.58, -1.78, 1.2)), INK, segments=8)


def stand_in_crates(colours):
    """The stack on the crate stand, as Crates.buildStand makes it: 2.4 cubes in two rows."""
    below = math.ceil(len(colours) / 2)
    for index, colour in enumerate(colours):
        upper = index >= below
        in_row, spot = (len(colours) - below, index - below) if upper else (below, index)
        x = -(spot + 1 - (in_row + 1) / 2) * 2.7
        z = 0.2 + 1.2 + (2.4 if upper else 0)
        turn = math.radians(-7 if index % 2 else 6)
        box((2.4, 2.4, 2.4), (x, 0.4, z), colour, bevel=0.15, segments=1, rotation=(0, 0, turn))
        for height in (-0.86, 0.86):
            slab((2.55, 2.55, 0.34), (x, 0.4, z + height), shade(colour, -0.6), rotation=(0, 0, turn))


def stand_in_guide():
    """Captain Kaboom, as Story.buildGuide makes him: a cannonball 5 across in a captain's hat."""
    middle = GUIDE_TOP + 3.1
    ball(2.5, (0, 0, middle), "2C2E3A", segments=20, roughness=0.35)
    for side in (-1, 1):
        box((1.3, 1.9, 0.7), (side * 0.95, -0.2, GUIDE_TOP + 0.35), "5C402C", bevel=0.2, segments=1)
        ball(0.5, (side * 0.75, -2.15, middle + 0.55), WHITE, segments=10)
        ball(0.25, (side * 0.75, -2.58, middle + 0.55), INK, segments=8)
        ball(0.6, (side * 2.9, -0.6, middle - 0.3), WHITE, segments=10)
    slab((1.5, 0.3, 0.25), (0, -2.3, middle - 0.75), WHITE)
    hat = middle + 2.15
    tube(2.3, 0.3, (0, 0, hat), UP, "264296", vertices=16)
    tube(1.5, 1.5, (0, 0, hat + 0.3), UP, "264296", vertices=16)
    tube(1.56, 0.4, (0, 0, hat + 0.3), UP, GOLD, vertices=16)
    ball(0.35, (0.5, -0.3, hat + 3.0), "FF9628", segments=8, emission=1.5)


def stand_in_shells(colours=("FF6A3D", "5AE1FF", "9CFF3A", "FF5AC8", "FFE23A", "B58CFF")):
    """The shells the game shows on the forge's anvil and rack."""
    ball(0.5, (1.3, -2.0, 2.7), "FF7A28", segments=10, emission=1.2)
    for index, colour in enumerate(colours):
        ball(0.45, (-2.1 - index % 2, -2.2 + (index // 2) * 1.1, 2.65), colour, segments=8, emission=1.0)


def stand_in_trade_lights():
    for index in range(4):
        x, y = ring(index * 90 + 45, 7.8)
        ball(0.65, (x, y, 5.1), TEAL if (x < 0) == (y > 0) else GOLD, segments=10, emission=1.4)
    ball(0.7, (0, 0, 6.2), TEAL, segments=10, emission=1.4)


def stall_wares(kind):
    """What stands on a stall's counter in place of the game's cube and ball: a cut gem, a gold star, pumpkins."""
    if kind == "gem":
        lathe([(0, 1.3), (0.5, 1.3), (0.85, 0.95), (0, 0)], TEAL, segments=8, smooth=False, location=(0, 0, 3.5), roughness=0.2, emission=0.8)
        hoop(0.5, 0.16, (0, 0, 3.42), GOLD, segments=8, roughness=0.3)
    elif kind == "star":
        star(1.05, (0, 0, 4.5), GOLD, depth=0.4, roughness=0.3, emission=0.5)
        tube(0.5, 0.25, (0, 0, 3.3), UP, GOLD_DARK, vertices=8)
    else:  # the Halloween stall: the game's two pumpkins are at its own x = -2.6 and 2.4
        place(pumpkin, (2.6, 0, 3.3), face=180, size=0.9)
        place(pumpkin, (-2.4, -0.2, 3.3), face=180, size=0.7)


# ---------------------------------------------------------------------------------------------------
# The ground: a few big calm shapes, and nothing scattered on it.
#   lawn (the game's is 280 square, its top at -0.08), cobbles (160 square, top at 0), the plaza (26 from the
#   middle, 0.12 high), and paths where people walk: a ring under the lamps, four ways out of the plaza, the
#   egg walk across the north, a street past the stalls and one past the boards.
# ---------------------------------------------------------------------------------------------------
HALF = 75  # Layout.MARKET_SIZE / 2: the houses' fronts stand 1 past it
EGG_RING, EGG_ANGLES = 52, {"day": (0,), "halloween": (-78, -39, 0, 39, 78)}  # buildHatchery: one egg outside the event, five in it
LAMPS = [157.5 - 45 * index for index in range(8)]  # buildDecor's lamps 1 to 8, as directions here
LAMP_RING = 36

group = "Ground"
frame_square(80.6, 140.0, -0.08, GRASS)
flat([(-80.7, -80.7), (80.7, -80.7), (80.7, 80.7), (-80.7, 80.7)], 0.0, PAVE)
frame_square(80.0, 81.5, 0.04, STONE)  # a kerb between cobbles and lawn
frame_square(70.0, 80.0, 0.03, WALK)  # the pavement the houses stand on
band(46.0, 58.0, -80, 80, 0.05, PATH, steps=32)  # the egg walk
for side in (-1, 1):
    x, y = ring(side * 80, EGG_RING)
    flat([(x + 6 * math.cos(index * math.pi / 8), y + 6 * math.sin(index * math.pi / 8)) for index in range(16)], 0.055, PATH)
band(32.5, 39.5, 0, 360, 0.06, PATH, steps=64)  # the ring under the lamps
rect(-5, 25, 5, 47, 0.07, PATH)  # north, to the eggs
rect(-5, -67.5, 5, -25, 0.07, PATH)  # south, to the arrival pad and the portal
rect(25, -5, 50, 5, 0.07, PATH)  # east
rect(-50, -5, -25, 5, 0.07, PATH)  # west
rect(48.5, -56, 55.5, 6, 0.08, PATH)  # past the stalls
rect(-55.5, -38, -48.5, 38, 0.08, PATH)  # past the boards
lathe([(0, 0.12), (25.6, 0.12), (26.0, 0.0)], PLAZA, segments=64, roughness=0.9)  # as high as the game's
band(23.3, 25.3, 0, 360, 0.17, BAND, steps=64)
band(14.7, 16.4, 0, 360, 0.17, BAND, steps=48)
# Big soft patches on the lawn behind the houses, so it is not one flat green.
for degrees, distance, radius, colour in ((20, 118, 18, GRASS_LIGHT), (70, 120, 15, GRASS_DEEP), (112, 116, 17, GRASS_LIGHT), (160, 119, 16, GRASS_DEEP), (205, 117, 18, GRASS_LIGHT),
                                          (250, 120, 15, GRASS_DEEP), (292, 117, 17, GRASS_LIGHT), (336, 119, 16, GRASS_DEEP)):
    dome(radius, 0.25, (*ring(degrees, distance), -0.08), colour, rotation=(0, 0, rng.uniform(0, 3)), stretch=0.8, sink=0.05, segments=14, roughness=0.9)
place(arrival_pad, (0, -56), face=0)

group = "Fountain"
fountain()

# ---- The houses and towers: buildTown's 20 footprints and 4 corners. The game picks each house's height
# (22 to 36) and colours with its own dice; here they are chosen: low along the south, where the photo from
# above looks in, rising to the north behind the hatchery. ----
ROWS = {"North": (180, lambda along: (along, 84)), "East": (270, lambda along: (84, along)), "South": (0, lambda along: (along, -84)), "West": (90, lambda along: (-84, along))}
TOWN = {
    "North": ((-60, turret, dict(height=33, wall=SKY, roof=ROOF_RED, cone=ROOF_BLUE, m=-1, pennant=GOLD)),
              (-30, shop, dict(height=30, wall=BUTTER, roof=ROOF_TEAL, awning=(RED, TRIM), m=1)),
              (0, hall, dict(height=34, wall=CREAM, roof=ROOF_BLUE, icon="egg", pennant="FF6FB5")),
              (30, inn, dict(height=31, wall=PEACH, roof=ROOF_RED, m=1)),
              (60, twin, dict(height=35, wall=(MINT, PINK), roof=(ROOF_ORANGE, ROOF_TEAL), m=1))),
    "East": ((-60, cottage, dict(height=24, wall=PINK, roof=ROOF_BLUE, m=1)),
             (-30, twin, dict(height=28, wall=(BUTTER, SKY), roof=(ROOF_RED, ROOF_ORANGE), m=1, awning=(ROOF_TEAL, TRIM))),
             (0, hall, dict(height=30, wall=MINT, roof=ROOF_TEAL, icon="gem", pennant=GOLD)),
             (30, shop, dict(height=32, wall=PEACH, roof=ROOF_BLUE, awning=(ROOF_ORANGE, TRIM), m=-1)),
             (60, turret, dict(height=34, wall=CREAM, roof=ROOF_TEAL, cone=ROOF_RED, m=1, pennant=ROOF_BLUE))),
    "South": ((-60, twin, dict(height=24, wall=(BUTTER, SKY), roof=(ROOF_TEAL, ROOF_ORANGE), m=1, drop=2.0, back=True)),
              (-30, cottage, dict(height=22, wall=PEACH, roof=ROOF_RED, m=1, back=True)),
              (0, shop, dict(height=23, wall=MINT, roof=ROOF_BLUE, awning=(RED, TRIM), rise=6.5, m=1, back=True)),
              (30, inn, dict(height=22, wall=CREAM, roof=ROOF_ORANGE, m=-1, back=True)),
              (60, cottage, dict(height=24, wall=PINK, roof=ROOF_TEAL, m=-1, back=True))),
    "West": ((-60, inn, dict(height=25, wall=BUTTER, roof=ROOF_TEAL, m=1)),
             (-30, shop, dict(height=28, wall=PINK, roof=ROOF_BLUE, awning=(ROOF_TEAL, TRIM), m=1)),
             (0, hall, dict(height=30, wall=SKY, roof=ROOF_ORANGE, icon="star", pennant=RED)),
             (30, cottage, dict(height=31, wall=MINT, roof=ROOF_RED, m=1)),
             (60, twin, dict(height=34, wall=(PEACH, CREAM), roof=(ROOF_BLUE, ROOF_TEAL), m=-1))),
}
houses = []  # for the manifest: what stands on each of the game's footprints
for row, (face, where) in ROWS.items():
    group = "Houses" + row
    for along, kind, options in TOWN[row]:
        x, y = where(along)
        place(kind, (x, y), face=face, **options)
        houses.append({"x": x, "z": -y, "faces": face, "kind": kind.__name__, "height": options["height"]})
group = "Towers"
for (sx, sy), roof, pennant in (((1, -1), ROOF_BLUE, GOLD), ((1, 1), ROOF_ORANGE, ROOF_BLUE), ((-1, 1), ROOF_TEAL, RED), ((-1, -1), ROOF_RED, GOLD)):  # buildTown: ROOF_COLORS[side % 4 + 1]
    place(tower, (sx * 84, sy * 84), roof=roof, pennant=pennant)

# ---- Lamps on the game's ring of eight, the six trees on the game's spots, bunting overhead ----
group = "Dressing"
for index, degrees in enumerate(LAMPS):
    at = ring(degrees, LAMP_RING)
    place(lamp, at, face=degrees + 180)  # its basket hangs on the side away from the fountain... see `lamp`: +X of the prop
    with into("PlaceholdersDay"):
        place(bulb, at, colour="FFD68C")
    with into("PlaceholdersHalloween"):
        place(bulb, at, colour="FF8C28" if (index + 1) % 2 == 0 else "AA5AFF")  # buildDecor: even lamps orange, odd purple
group = "Trees"
for index, (x, y) in enumerate(((66, -66), (-66, -66), (66, 66), (-66, 66), (66, 22), (-66, 22))):  # buildDecor's trees
    place(tree, (x, y), face=rng.uniform(0, 360), scale=1.3 if abs(y) > 30 else 1.15, leaf=index % 3, kind="round" if index % 2 == 0 else "tall")
# Bunting: between the lamps either side of each diagonal (never across a path), and across each corner of
# the square from house to house, high over everything.
for degrees in (45, 135, 225, 315):
    bunting((*ring(degrees - 22.5, LAMP_RING), 10.2), (*ring(degrees + 22.5, LAMP_RING), 10.2), sag=1.5)
for sx, sy in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
    bunting((sx * 36, sy * 75.6, 18.5), (sx * 75.6, sy * 36, 18.5), sag=3.2)

# ---- Far away: hills and big trees beyond the houses, where nobody gets. Clouds are for the photos. ----
group = "Backdrop"
HILLS = ((8, 182, 60, 40, GRASS_DEEP), (42, 196, 70, 52, GRASS), (76, 180, 58, 36, GRASS_DEEP), (106, 190, 66, 46, GRASS), (140, 184, 60, 30, GRASS_DEEP), (172, 196, 64, 24, GRASS),
         (206, 186, 60, 28, GRASS_DEEP), (238, 192, 68, 44, GRASS), (270, 180, 58, 38, GRASS_DEEP), (300, 196, 70, 52, GRASS), (332, 184, 62, 42, GRASS_DEEP),
         (25, 330, 120, 120, "8AD79C"), (72, 340, 130, 100, "9BDDAE"), (118, 330, 110, 84, "8AD79C"), (246, 330, 110, 88, "9BDDAE"), (292, 340, 130, 104, "8AD79C"), (338, 330, 120, 124, "9BDDAE"))  # the far ones pale with distance
for degrees, distance, radius, height, colour in HILLS:
    lathe([(0, height), (radius * 0.42, height * 0.9), (radius * 0.78, height * 0.52), (radius, 0)], colour, segments=14, location=(*ring(degrees, distance), -3.0), roughness=0.9)
group = "Trees"
FAR_TREES = ((15, 108, 3.0), (38, 126, 2.7), (64, 118, 2.9), (90, 108, 3.2), (116, 118, 2.6), (144, 128, 1.8), (216, 128, 1.8), (244, 118, 2.6), (270, 108, 3.2), (296, 118, 2.9), (322, 126, 2.7), (345, 108, 3.1))
for index, (degrees, distance, size) in enumerate(FAR_TREES):  # big ones: their heads show over the roofs
    place(tree, ring(degrees, distance), face=rng.uniform(0, 360), scale=size, leaf=index % 3, kind="tall" if index % 3 == 0 else "round", fine=False)
group = "Clouds"
for x, y, z, size in ((-150, 300, 120, 16), (120, 320, 150, 18), (-20, 380, 190, 20), (230, 260, 90, 13), (-250, 250, 85, 13), (-320, 60, 70, 12), (320, 40, 80, 12), (60, 420, 110, 15), (-110, 420, 100, 14)):
    place(cloud, (x, y, z), face=180 + rng.uniform(-25, 25), scale=size)

# ---- The landmark shells, and a copy of each on the game's spots ----
group = "Placeholders"
EAST, WEST, NORTH, SOUTH = 90, 270, 0, 180
shell("EggPedestal", egg_pedestal, top=CUSHION_TOP, note="The egg stands on the cushion: pass this as `top` to Marketplace.buildEggStand. 6.4 across at its foot.")
EGGS = {"gem": ("B9F1FF", "50DCFF"), "pumpkin": ("FFE2C0", "FF821E"), "haunted": ("E2D2F2", "6E3CA0"), "crypt": ("E4E6E8", "5F6973"), "bloodmoon": ("F4CFCF", "AA141E")}
for when, names in (("day", ("gem",)), ("halloween", ("gem", "pumpkin", "haunted", "crypt", "bloodmoon"))):
    for degrees, name in zip(EGG_ANGLES[when], names):
        show("EggPedestal", egg_pedestal, ring(degrees, EGG_RING), when=when, note=f"{name} egg, at {degrees} degrees on the arc of {EGG_RING}")
        with into(WHEN[when]):
            place(stand_in_egg, ring(degrees, EGG_RING), shell_colour=EGGS[name][0], spot_colour=EGGS[name][1])

shell("Stall", stall, also=("StallStripesA", "StallStripesB"), faces={"sign": STALL_FACE},
      note="StallStripesA takes the first colour of buildStall's list (3 stripes), StallStripesB the second (4 stripes). The counter is clear between x = -3.7 and 3.7 for what the game stands on it.")
for (x, y), when, stripes, title, wares in (((58, -8), "both", ("4696FF", "F0F5FF"), "WEEKLY SHOP", "gem"), ((58, -28), "halloween", ("FF821E", "6E3CA0"), "HALLOWEEN SHOP", "pumpkins"),
                                            ((58, -48), "both", ("FFC828", "F0F5FF"), "GAME PASSES", "star")):
    frame = show("Stall", stall, (x, y), face=WEST, when=when, note=title, stripes=stripes)
    words(title, frame, (0, -2.4, 11.8), 1.25, when=when)
    with into("Halloween" if wares == "pumpkins" else "Dressing"):
        place(stall_wares, (x, y), face=WEST, kind=wares)

shell("Leaderboard", leaderboard, also=("LeaderboardTrim",), faces={"board": LEADERBOARD_FACE},
      note="LeaderboardTrim (the rim and the crown's jewel) is white: colour it per board. Also for Features/Event.luau's boards, in the event's colour in place of EventBoardRim.")
BOARDS = (((-58, 10), "both", "MOST GEMS", "3FE0FF", "Gems"), ((-58, -10), "both", "MOST REBIRTHS", "5FE03A", "Rebirths"), ((-58, -30), "both", "MOST CANNON POWER", "FFE23A", "Power"),
          ((-58, 30), "halloween", "MOST CANDY EARNED", "FF821E", "Event board 1 (Features/Event.luau); a second event's stands at x -58, z -50"))
for (x, y), when, title, trim, note in BOARDS:
    frame = show("Leaderboard", leaderboard, (x, y), face=EAST, when=when, note=note, trim=trim)
    words(title, frame, (0, -0.42, 16.15), 0.95, GOLD if when == "both" else "FF9A3C", when=when)
    words("\n".join(f"{rank}. {name}  -  {score}" for rank, (name, score) in enumerate((("ashura", "18.3K"), ("Yaani", "12.1K"), ("CannonKid", "9.40K"), ("PumpkinPie", "7.75K"), ("xXBoomXx", "5.02K")), 1)),
          frame, (-6.9, -0.42, 12.2), 0.8, when=when, align="LEFT")

shell("NoticeBoard", notice_board, faces={"board": NOTICE_FACE})
frame = show("NoticeBoard", notice_board, (-14, -42), face=SOUTH, note="Missions")
words("MISSIONS", frame, (0, -0.27, 6.9), 1.45)
words("Earn gems every day", frame, (0, -0.27, 5.0), 0.7)
frame = show("NoticeBoard", notice_board, (-44, -62), face=NORTH, note="How to trade (the trading plaza's)")
words("HOW TO TRADE\n1. Ask a player here\n2. Both add what to swap\n3. Both press READY", frame, (0, -0.27, 6.0), 0.62)

shell("Chest", chest, note="The daily chest. 5.4 x 3.6 at its foot, 4.5 high.")
show("Chest", chest, (14, -42), face=SOUTH)

shell("Portal", lambda: place(portal, (0, 0), face=SOUTH, scale=0.88), also=("PortalSheet",), note="PortalSheet is the glowing sheet (Neon), same origin. 13.6 x 5.6 at its foot, 15 high.")
show("Portal", portal, (0, -70), face=NORTH, scale=0.88)

shell("HatcherySign", hatchery_sign, faces={"board": HATCHERY_FACE})
frame = show("HatcherySign", hatchery_sign, (0, 70), face=SOUTH)
words("EGG HATCHERY", frame, (0, -0.52, 18.0), 4.7, GOLD)

shell("TradePlaza", trade_plaza, note="The whole plaza but its lantern bulbs and the orb over the table (TradingLantern, TradingOrb stay the game's). Table top 2.8 up; traders' spots 4.2 either side.")
frame = show("TradePlaza", trade_plaza, (-44, -52), face=NORTH)
place(stand_in_trade_lights, (-44, -52), face=NORTH)

shell("HugePedestal", huge_pedestal, top=HUGE_TOP, faces={"plate": HUGE_FACE}, note="Features/Huge.luau's showcase: the Huge stands on its top.")
frame = show("HugePedestal", huge_pedestal, (24, 32))
place(stand_in_huge, (24, 32))
words("799 R$", frame, (0, -3.22, 1.65), 0.8, "FFCD3C")

shell("CrateStand", crate_stand, faces={"sign": CRATE_SIGN_FACE, "list": CRATE_LIST_FACE}, note="Features/Crates.luau's stand: the crates themselves stay the game's (their middles are 0.4 behind its middle).")
frame = show("CrateStand", crate_stand, (-24, 32))
words("CRATES", frame, (0, 2.38, 11.0), 1.25)
words("Wood Crate  -  drops from monsters\nDaily Crate  -  one free a day\nBoss Chest  -  beat a boss\nGem Crate  -  40 gems\nRoyal Crate  -  99 R$", frame, (0, 2.38, 7.6), 0.52)
CRATES = ("B07C4C", "46BE78", "C83C3C", "50DCFF", "FAC332")
with into("PlaceholdersDay"):
    place(stand_in_crates, (-24, 32), colours=CRATES)
with into("PlaceholdersHalloween"):
    place(stand_in_crates, (-24, 32), colours=CRATES + ("FF821E", "7832B4"))

shell("AmmoForge", ammo_forge, note="Features/Ammo.luau's forge, piece for piece on the game's. The shells on the anvil and the rack and the fire's light stay the game's.")
show("AmmoForge", ammo_forge, (34, -26))
place(stand_in_shells, (34, -26))

shell("GuidePlinth", guide_plinth, top=GUIDE_TOP, note="Features/Story.luau's Captain Kaboom stands on it.")
show("GuidePlinth", guide_plinth, (-30, -26))
place(stand_in_guide, (-30, -26))

# ---- Halloween: a few big friendly things by the landmarks, the rest overhead ----
group = "Halloween"
BIG_PUMPKINS = (((24.2, 70.4), 2.3, 180), ((-24.2, 70.4), 2.0, 180),  # either side of the hatchery sign
                ((9.6, -70.2), 1.9, 0), ((-9.4, -70.4), 1.5, 0),  # either side of the portal
                ((58.4, -35.3), 1.8, 270),  # between the Halloween stall and the next
                ((19.4, -42.2), 1.3, 180))  # by the daily chest
for (x, y), size, face in BIG_PUMPKINS:
    place(pumpkin, (x, y), face=face + rng.uniform(-14, 14), size=size)
    collider("Pumpkin", (x, y), (size * 2, size * 2, size * 1.6), when="halloween")
for sx, sy in ((1, 1), (1, -1), (-1, -1), (-1, 1)):  # one at each tower's door
    place(pumpkin, (sx * 72.8, sy * 72.8), size=2.6)
    collider("Pumpkin", (sx * 72.8, sy * 72.8), (5.2, 5.2, 4.2), when="halloween")
place(ghost, (13.5, 71.6, 22.4), face=180, scale=1.5)  # peeking over the hatchery sign
place(ghost, (63.5, -21.0, 14.5), face=250, scale=1.3)  # over the Halloween stall
place(ghost, (-63.0, 34.0, 20.5), face=110, scale=1.3)  # over the event board
for x, y, z, face in ((70, 70, 50, 220), (-66, 74, 47, 150), (-74, -62, 49, 40), (10, 60, 34, 190), (-28, 64, 30, 170), (40, -6, 27, 260)):
    place(bat, (x, y, z), face=face, scale=rng.uniform(1.6, 2.2))
for side in (-1, 1):  # webs in the corners under the hatchery sign, and on the two houses beside the hall
    place(cobweb, (side * 19.0, 69.2, 13.2), face=180 if side < 0 else 0, size=4.2)
    place(cobweb, (side * 44.6, 75.4, 29.0 if side < 0 else 30.0), face=180 if side < 0 else 0, size=5.0)
place(cobweb, (75.4, 14.6, 29.0), face=270, size=5.0)
place(cobweb, (-75.4, -14.6, 29.0), face=90, size=5.0)
place(witch_hat, (0, 84.5, 34 + 7.2 + 4.0 * 1.36 * 2 - 1.6), face=180, scale=1.15)  # on the giant egg over the hatchery

# ---------------------------------------------------------------------------------------------------
# Counting
# ---------------------------------------------------------------------------------------------------
bpy.context.view_layer.update()


def export_name(name):
    if name in RENDER_ONLY:
        return "RenderOnly_" + name
    return name if name in shells else "Market_" + name


triangles = {}
for name, pieces in groups.items():
    triangles[name] = 0
    for obj in pieces:
        obj.data.calc_loop_triangles()
        triangles[name] += len(obj.data.loop_triangles)
    print(f"GROUP {export_name(name)} pieces {len(pieces)} triangles {triangles[name]}")
kinds = {name: "shell" if name in shells else "seasonal" if name in SEASONAL else "scenery" for name in groups if name not in RENDER_ONLY}
for kind in ("scenery", "seasonal", "shell"):
    print(f"TOTAL {kind} {sum(triangles[name] for name, each in kinds.items() if each == kind)}")
print(f"EXPORT triangles {sum(triangles[name] for name in kinds)}")

# ---------------------------------------------------------------------------------------------------
# The photos: a sky that pales towards the horizon, a warm sun from the south, each once in everyday dress
# and once in Halloween dress
# ---------------------------------------------------------------------------------------------------
world = bpy.data.worlds.new("World")
world.use_nodes = True
nodes, links = world.node_tree.nodes, world.node_tree.links
direction, split, remap, ramp = (nodes.new(kind) for kind in ("ShaderNodeTexCoord", "ShaderNodeSeparateXYZ", "ShaderNodeMapRange", "ShaderNodeValToRGB"))
remap.inputs["From Min"].default_value = -1.0
links.new(direction.outputs["Generated"], split.inputs[0])
links.new(split.outputs["Z"], remap.inputs["Value"])
links.new(remap.outputs["Result"], ramp.inputs["Fac"])
links.new(ramp.outputs["Color"], nodes["Background"].inputs["Color"])
SKY_RAMP = ((0.0, "E8F6FF"), (0.15, "CDEBFF"), (0.36, "6DB6F5"), (0.47, "8FCBFA"), (0.5, "C4E8FF"), (0.62, "8CCBFB"), (0.8, "5AA7EE"), (1.0, "3F8FE0"))
stops = ramp.color_ramp.elements
for index, (position, colour) in enumerate(SKY_RAMP):
    stop = stops[index] if index < 2 else stops.new(position)
    stop.position = position
    stop.color = (*linear(colour), 1)
nodes["Background"].inputs["Strength"].default_value = 0.85
scene.world = world


def aim(obj, eye, target):
    obj.location = eye
    obj.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()


def from_sky(degrees, height, distance):
    """A point `distance` away in a direction (degrees, like ring) and `height` degrees above the ground."""
    x, y = ring(degrees, distance * math.cos(math.radians(height)))
    return Vector((x, y, distance * math.sin(math.radians(height))))


def sunlight(name, energy, colour, degrees, height, shadow=True):
    data = bpy.data.lights.new(name, "SUN")
    data.energy, data.color, data.angle = energy, colour, math.radians(6)
    data.use_shadow = shadow
    if not shadow:
        data.specular_factor = 0.0
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    aim(obj, from_sky(degrees, height, 100), (0, 0, 0))


sunlight("Sun", 2.7, (1.0, 0.96, 0.88), 204, 56)
sunlight("Fill", 0.7, (0.9, 0.95, 1.0), 70, 32, shadow=False)  # what the sky throws on the walls that face away from the sun

camera_data = bpy.data.cameras.new("Camera")
camera_data.clip_end = 3000
camera = bpy.data.objects.new("Camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera

scene.render.engine = "CYCLES"
scene.cycles.samples = 32 if DRAFT else 80
scene.cycles.use_denoising = True
scene.render.resolution_x = 2000
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 50 if DRAFT else 100
scene.view_settings.view_transform = "Standard"
try:  # the graphics card when there is one
    devices = bpy.context.preferences.addons["cycles"].preferences
    devices.compute_device_type = "METAL"
    (getattr(devices, "refresh_devices", None) or devices.get_devices)()
    for device in devices.devices:
        device.use = device.type != "CPU"
    scene.cycles.device = "GPU"
except Exception as problem:
    print("Rendering on the processor:", problem)

DRESS = {"": {"LeavesAutumn", "Halloween", "PlaceholdersHalloween"}, "_halloween": {"Leaves", "Bunting", "PlaceholdersDay"}}  # what each dress hides
LABELS = {"": "halloween", "_halloween": "day"}


def dress(suffix):
    for name, pieces in groups.items():
        hidden = name in DRESS[suffix] or name in shells
        for obj in pieces:
            obj.hide_render = hidden
    for when, objects in labels.items():
        for obj in objects:
            obj.hide_render = when == LABELS[suffix]


def photo(name, eye, target, lens):
    camera_data.lens = lens
    aim(camera, eye, target)
    scene.render.filepath = f"{OUT}/{name}.png"
    bpy.ops.render.render(write_still=True)


HERO_TARGET = Vector((0, 2, 2))
ONLY = [word.split("=")[1] for word in ARGS if word.startswith("only=")]
for suffix in ("_halloween", ""):  # everyday last, so the saved file opens in everyday dress
    dress(suffix)
    if not ONLY or "ground" in ONLY:
        photo("market_ground" + suffix, (0, -66.4, 6.3), (0, 30, 11.5), 20)  # what a player sees on arriving: from just behind the arrival pad, looking north
    if not ONLY or "hero" in ONLY:
        photo("market_hero" + suffix, HERO_TARGET + from_sky(190, 46, 330), HERO_TARGET, 35)  # three-quarters from above, from the south
    for word in ARGS:  # extra looks while working: view=name,x,y,z,tx,ty,tz,lens
        if word.startswith("view="):
            bits = word[5:].split(",")
            photo(f"check_{bits[0]}{suffix}", tuple(float(v) for v in bits[1:4]), tuple(float(v) for v in bits[4:7]), float(bits[7]))

# ---------------------------------------------------------------------------------------------------
# For Roblox: one mesh per group, colours on the vertices, none with over 10,000 triangles. Scenery and
# seasonal meshes keep the middle of the square (on the ground) as origin. A shell is exported around its own
# base, front towards -Y; in the saved file the shells stand in a row south of the town.
# ---------------------------------------------------------------------------------------------------
exported, report = [], []
for name, pieces in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.hide_render = False
        colour = obj.data.materials[0].diffuse_color
        attribute = obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        attribute.data.foreach_set("color", [colour[0], colour[1], colour[2], 1.0] * len(obj.data.loops))
        obj.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = joined.data.name = export_name(name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if name in RENDER_ONLY:
        continue
    exported.append(joined)
    low, high = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for vertex in joined.data.vertices:
        for axis in range(3):
            low[axis], high[axis] = min(low[axis], vertex.co[axis]), max(high[axis], vertex.co[axis])
    entry = {"name": joined.name, "kind": kinds[name], "triangles": triangles[name],
             "bounds": {"centre": [round((low[axis] + high[axis]) / 2, 2) for axis in range(3)], "size": [round(high[axis] - low[axis], 2) for axis in range(3)]}}
    if name in shells:
        entry.update({key: value for key, value in shells[name].items() if key != "with"})
        if "with" in shells[name]:
            entry["partOf"] = shells[name]["with"]
        entry["spots"] = spots[name]
    report.append(entry)

bpy.ops.object.select_all(action="DESELECT")
for obj in exported:
    obj.select_set(True)
bpy.context.view_layer.update()
bpy.ops.export_scene.fbx(filepath=f"{OUT}/marketplace.fbx", use_selection=True, apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", colors_type="SRGB")

SHOW = {"Market_LeavesAutumn": False, "Market_Halloween": False, "RenderOnly_PlaceholdersHalloween": False}  # the saved file opens in everyday dress
shelf = 0
for name in groups:
    obj = bpy.data.objects[export_name(name)]
    if name in shells:  # the shells in a row south of the town, the meshes of one shell together
        owner = shells[name].get("with", name)
        position = list(name for name in shells if "with" not in shells[name]).index(owner)
        obj.matrix_basis = Matrix.Translation((-150 + position * 27, -190, 0))
    if obj.name in SHOW:
        obj.hide_render = obj.hide_viewport = True
for obj in labels["halloween"]:
    obj.hide_render = obj.hide_viewport = True

manifest = {
    "about": "The marketplace as Blender meshes (tools/blender/marketplace.py). Marketplace space: the middle of the square on the ground is the origin. "
             "In the file x is east, y is NORTH, z is up (the game's z is -y, the game's y is z). Scenery and seasonal meshes share that origin. "
             "A shell has the middle of its own base as origin and its front towards -Y (in the game: -Z), so a shell's x runs the other way from the game's.",
    "units": "1 unit = 1 stud",
    "meshes": report,
    "totals": {kind: sum(entry["triangles"] for entry in report if entry["kind"] == kind) for kind in ("scenery", "seasonal", "shell")},
    "spots": "A shell's spot is in the game's marketplace space (x east, z SOUTH). `faces` is the compass direction its front looks (0 north, 90 east, 180 south, 270 west); "
             "`yaw` is the same as the angle of Marketplace.frame(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0), whose -Z is the front.",
    "faces": "A board's face is flat and empty: x and z are its middle in the shell's space, width x height its size, y the plane of the GAME's own board face "
             "(where its SurfaceGui draws). The mesh's face lies 0.05 behind that plane, so the words stay in front of it.",
    "seasons": {
        "everyday": {"show": ["Market_Leaves", "Market_Bunting"], "hide": ["Market_LeavesAutumn", "Market_Halloween"]},
        "halloween": {"show": ["Market_LeavesAutumn", "Market_Halloween"], "hide": ["Market_Leaves", "Market_Bunting"]},
    },
    "materials": {"Market_Glow": "Neon", "Market_Water": "Glass or SmoothPlastic at 0.2 transparency", "PortalSheet": "Neon, 0.35 transparency like the game's gate"},
    "gameParts": {
        "keepVisible": ["Lamp (the bulbs: they hang in the mesh lamps' cages, the game colours them)", "TradingLantern", "TradingOrb", "every egg", "the Huge on its pedestal", "the crates on the stand",
                        "the forge's shells", "Captain Kaboom (but his Plinth)", "every BillboardGui and SurfaceGui"],
        "hide": ["Lawn", "Ground", "Plaza", "ArrivalPad", "House", "Roof", "Door", "WindowFrame", "Window", "Tower", "TowerRoof", "LampPost", "Trunk", "Leaves", "Fountain", "Water", "Pedestal (the fountain's)",
                 "StatueBase", "StatueWheel", "StatueBarrel", "StatueRing", "HatcherySign", "SignPost", "Counter", "StallPost", "Awning", "StallSign", "Gem", "Star", "BoardPost", "Leaderboard", "DailyChest",
                 "ChestLid", "ChestBand", "ChestLock", "NoticePost", "NoticeBoard", "PortalPillar", "PortalBeam", "Portal", "TradingRug", "TradingRugRing", "TradingRugCentre", "TradingSpot", "TradingTableLeg",
                 "TradingTable", "TradingCannon", "TradingGem", "TradingPost", "egg stands' Pedestal and Cushion", "HugePedestal", "HugePedestalTop", "HugePlate", "CrateRug", "CrateSignPost", "CrateSign",
                 "CratePrices", "EventBoardPost", "EventBoard_*", "EventBoardRim", "AmmoForge: ForgeFloor, Furnace, ForgeFire, ForgeChimney, AnvilFoot, Anvil, ForgeRack", "StoryGuide: Plinth",
                 "every Build.pumpkin (the lamps', the stall's, the plaza's, the crate stand's): Market_Halloween brings a few big ones instead"],
    },
    "houses": {"note": "What stands on each of buildTown's footprints (29 x 16, front 1 past the square). Heights and colours are this file's, not the game's dice: the game's own houses are hidden.", "list": houses},
    "heights": {"eggPedestalTop": CUSHION_TOP, "hugePedestalTop": HUGE_TOP, "guidePlinthTop": GUIDE_TOP, "fountainRim": 2.0, "fountainPedestalTop": 6.0, "plazaTop": 0.12, "tradeTableTop": 2.8},
    "colliders": {"note": "Boxes for new solid things (centre and size in the game's marketplace space, y up, z south; yaw in degrees). Everything else in the meshes either stands on something of the game's "
                          "that already collides, hangs overhead, or is flat ground.", "list": colliders},
    "photos": ["market_hero.png", "market_ground.png", "market_hero_halloween.png", "market_ground_halloween.png"],
}
with open(f"{OUT}/market_manifest.json", "w") as handle:
    json.dump(manifest, handle, indent=1)

bpy.context.preferences.filepaths.save_version = 0  # no .blend1 beside it
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/marketplace.blend")
print("DONE")
