"""The Earth base: a player's plot (world 1) in the chunky, rounded simulator style of the Earth island,
made to be worn over the base the game builds from parts (src/server/Plots.luau) without moving any of it.

Run: blender --background --python tools/blender/earth_base.py -- <output folder> [draft] [photos=a,b] [nofiles]

THE MAPPING. Plot space is the game's (Layout.luau): the middle of the base's edge of the ground is the
origin, x runs across the plot, +z up the plot to the portal, the ground's top is y = 0 and the yard is
behind the origin (-z). 1 unit is 1 stud. In Blender:
    Blender x = plot x        Blender y = -plot z        Blender z = plot y
so a point (x, y, z) of this file is (x, z, -y) in plot space. The portal is at Blender y = -147, the gate at
y = -14, the yard at y = 0 ... 16. `at(x, z, y)` turns plot space into Blender's, and every position below is
written in plot space.
A shell is made around the middle of its own base, standing on z = 0, its front towards -Y. `face` says
where that front looks in plot space: 0 up the plot (+z), 90 towards +x, 180 back at the yard (-z).
In Roblox (an FBX lands as (-x, z, y), so a shell's front is its -Z, as on the island): put a shell on its
spot with  frame * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(face + 180), 0).

Everything the game lays out is copied from Layout.luau and Plots.luau (see LAYOUT below): the path and its
width, the sixteen pads, the gate and its towers and walls, the name sign, the plaza and the arrival pad, the
portal, the two teleporters, the two lamps, the fence and the size of the ground.

Writes earth_base_hero.png, earth_base_ground.png (and five more photos: top, field, road, gate, portal),
earth_base.blend, earth_base.fbx and earth_base_manifest.json. Two kinds of mesh, colours on the vertices:
  scenery, all with the plot's origin (on the ground) as origin:
      Base_Ground  Base_Cliff  Base_Road  Base_Backdrop  Base_BackdropTrees  Base_Trees  Base_Dressing
      Base_Glow (for Neon)  Base_Water (for Glass)
  shells, each around the middle of its own base, front towards -Y:
      Base_Pad + Base_PadTrim        Base_Gate + Base_GateTrim        Base_Portal + Base_PortalSheet
      Base_Teleporter + Base_TeleporterTrim        Base_Lamp
  A ...Trim mesh is pure white on its vertices: the game's Color tints it (the owner's colour, a
  teleporter's destination, a pad's state). In the photos it wears a stand-in colour.
The towers, the monsters, the bulbs, the beams, the words on the signs and the clouds in the photos are
stand-ins and are not exported; neither are the copies of a shell on its other spots.
`draft` makes the photos at half size. `photos=hero,ground` makes only those. `nofiles` skips the export.

The kit is the one of earth_island.py (box, ball, tube, lathe ..., one flat colour a piece, built with bmesh).
"""
import json
import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
OUT = ARGS[0]
DRAFT = "draft" in ARGS
NOFILES = "nofiles" in ARGS
ONLY = [name for arg in ARGS if arg.startswith("photos=") for name in arg[7:].split(",")]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}
rng = random.Random(11)  # the same "random" base every run

# The island's palette.
GRASS, GRASS_LIGHT, GRASS_DEEP, GRASS_RIM = "6FD046", "92E35A", "58BE3E", "389A45"
DIRT, DIRT_DARK = "C98B4D", "9C6436"
ROCK, ROCK_DARK, ROCK_LIGHT = "9A93B5", "756E98", "B9B3CF"
UNDER, UNDER_DARK, UNDER_LIGHT = "7C75A3", "5F5888", "958EB6"
SAND, SAND_DARK, COBBLE = "F6DFA6", "E3C385", "FFF1CC"
STONE, STONE_DARK, STONE_PALE = "DCD6CC", "B9B2A8", "F4EFE6"
WOOD, WOOD_LIGHT, WOOD_DARK = "B9783F", "E3B06B", "8A5A2B"
WATER, WATER_LIGHT = "3FBDF5", "A8E8FF"
WHITE, INK, GOLD, GOLD_DARK = "FFFFFF", "1B1140", "FFC61A", "E09A12"
IRON, RED, BLUE = "4A4763", "FF4D4D", "3FA9FF"
LEAVES = ("4FC44A", "2FA85A", "8FD93E")
HILLS = ("55BE48", "4AB246", "3FA548", "369A4A")  # the hills round the plot: darker than the lawn
BOARD = "3A3560"  # what the game writes on in white
# The monsters' portal: dark stone and a hot pink glow, nothing like the island's cream and purple one.
LAIR, LAIR_DARK, LAIR_DEEP = "5F5888", "4A4763", "39365A"
HOT, HOT_DARK, HOT_DEEP, HOT_CORE, EMBER = "FF3D7F", "D81E63", "8E1250", "3A0A30", "FF8A3D"
BONE, BONE_DARK = "FFF3D6", "E3C385"
UP = (0, 0, 1)


def linear(hex_code):
    hex_code = hex_code.lstrip("#")
    return tuple(((int(hex_code[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4))


def shade(hex_code, amount):
    """Darker (amount < 0) or lighter (amount > 0) version of a colour."""
    hex_code = hex_code.lstrip("#")
    target = 255 if amount > 0 else 0
    return "".join("%02X" % round(int(hex_code[i:i + 2], 16) + (target - int(hex_code[i:i + 2], 16)) * abs(amount)) for i in (0, 2, 4))


def mat(hex_code, roughness=0.6, emission=0.0, alpha=1.0):
    key = (hex_code, roughness, emission, alpha)
    if key not in materials:
        m = bpy.data.materials.new(hex_code)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        colour = linear(hex_code)
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Alpha"].default_value = alpha
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*colour, 1)
            bsdf.inputs["Emission Strength"].default_value = emission
        m.diffuse_color = (*colour, 1)
        materials[key] = m
    return materials[key]


# ---------------------------------------------------------------------------------------------------
# The kit (earth_island.py's). Every piece is one flat colour. Pieces are collected per group: a group
# becomes one mesh. In the scenery anything that glows goes to "Glow" and the water to "Water".
# ---------------------------------------------------------------------------------------------------
SCENERY = ("Ground", "Cliff", "Road", "Backdrop", "BackdropTrees", "Trees", "Dressing", "Water", "Glow")
TRIMS = ("PadTrim", "GateTrim", "TeleporterTrim")  # exported white, for the game to tint
RENDER_ONLY = ("Placeholders", "Sky")  # in the photos, not in the export
groups = {}  # name -> pieces
group = "Ground"  # the group being built
shells = {}  # a shell's group -> the frame it stands at on the plot
made = []  # every piece, in the order it was made
SHARP = math.radians(50)  # edges bent more than this stay crisp


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
    """A plain block with crisp edges: twelve triangles, for rails, bricks and bars."""
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


def mesh(vertices, faces, colour, location=(0, 0, 0), rotation=(0, 0, 0), **look):
    work = bmesh.new()
    corners = [work.verts.new(vertex) for vertex in vertices]
    for face in faces:
        work.faces.new([corners[index] for index in face])
    return finish(work, colour, location, rotation, **look)


def patch(vertices, faces, colour, **look):
    """A hand-made sheet whose corners may fall together (the inside of a bend): those are welded, what is
    left of a face without area is dropped, and it is turned to face up."""
    work = bmesh.new()
    corners = [work.verts.new(vertex) for vertex in vertices]
    for face in faces:
        work.faces.new([corners[index] for index in face])
    bmesh.ops.remove_doubles(work, verts=work.verts[:], dist=0.0005)
    bmesh.ops.dissolve_degenerate(work, edges=work.edges[:], dist=0.0005)
    bmesh.ops.recalc_face_normals(work, faces=work.faces[:])
    work.normal_update()
    if sum(face.normal.z * face.calc_area() for face in work.faces) < 0:
        bmesh.ops.reverse_faces(work, faces=work.faces[:])
    return finish(work, colour, **look)


def hoop(radius, thickness, location, colour, rotation=(0, 0, 0), segments=16, **look):
    """A ring lying flat: a band around a column, a handle, a halo."""
    around = 5
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


def chunk(size, location, colour, detail=2, **look):
    """A low-poly rock: a faceted ball with its corners pushed in and out."""
    work = bmesh.new()
    bmesh.ops.create_icosphere(work, subdivisions=detail, radius=1.0)
    for vertex in work.verts:
        push = 1 + rng.uniform(-0.16, 0.16)
        vertex.co = (vertex.co.x * size[0] * push, vertex.co.y * size[1] * push, vertex.co.z * size[2] * push)
    return finish(work, colour, location, (0, 0, rng.uniform(0, 6.28)), smooth=False, **look)


def ring(degrees, radius):
    """A point (x, y) on a circle: 0 degrees is +Y, 90 is +X."""
    angle = math.radians(degrees)
    return math.sin(angle) * radius, math.cos(angle) * radius


def lathe(rings, colour, segments=48, shape=None, rough=0.0, stretch=1.0, **look):
    """A solid of rings stacked around the Z axis. Each ring is (radius, z), and either may be a function of
    the angle in degrees; a radius of 0 is a single point. `shape` multiplies every radius by a function of
    the angle, `rough` shakes every corner by up to that much, `stretch` squeezes it along Y.
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


def ribbon(profile, width, colour, thickness=0.6, shift=0.0, lift=0.0, **look):
    """A band that runs out of a prop's front along a path of (forward, height) points: a waterfall."""
    vertices, faces = [], []
    for index, (forward, height) in enumerate(profile):
        before, after = profile[max(index - 1, 0)], profile[min(index + 1, len(profile) - 1)]
        along = Vector((after[0] - before[0], after[1] - before[1])).normalized()
        out = Vector((-along.y, along.x))
        for side, sink in ((-0.5, thickness), (-0.3, 0), (0.3, 0), (0.5, thickness)):
            vertices.append((shift + side * width, -(forward + out.x * (lift - sink)), height + out.y * (lift - sink)))
        if index:
            a, b = (index - 1) * 4, index * 4
            faces += [(a + corner, a + (corner + 1) % 4, b + (corner + 1) % 4, b + corner) for corner in range(4)]
    last = len(vertices) - 4
    faces += [(0, 1, 2, 3), (last, last + 1, last + 2, last + 3)]
    return mesh(vertices, faces, colour, tidy=True, **look)


def rounded(width, depth, radius, steps=4):
    """The outline of a rectangle with round corners around the origin: (x, y) points, anticlockwise."""
    points = []
    for corner, (sx, sy) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
        cx, cy = sx * (width / 2 - radius), sy * (depth / 2 - radius)
        for step in range(steps + 1):
            a = math.pi / 2 * (corner + step / steps)
            points.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    return points


def tile(width, depth, radius, bottom, top, colour, lip=0.08, location=(0, 0, 0), rotation=(0, 0, 0), **look):
    """A flat slab with round corners and a chamfered top edge, open underneath."""
    loops = [(rounded(width, depth, radius), bottom), (rounded(width, depth, radius), top - lip), (rounded(width - 2 * lip, depth - 2 * lip, max(radius - lip, 0.02)), top)]
    count = len(loops[0][0])
    vertices = [(x, y, z) for outline, z in loops for x, y in outline]
    faces = [(level * count + index, level * count + (index + 1) % count, (level + 1) * count + (index + 1) % count, (level + 1) * count + index) for level in range(2) for index in range(count)]
    faces.append(tuple(range(2 * count, 3 * count)))
    return mesh(vertices, faces, colour, location, rotation, **look)


def inlay(outer, inner, z, colour, location=(0, 0, 0), **look):
    """A flat band between two outlines with as many points each, face up."""
    count = len(outer)
    vertices = [(x, y, z) for x, y in outer] + [(x, y, z) for x, y in inner]
    faces = [(index, (index + 1) % count, count + (index + 1) % count, count + index) for index in range(count)]
    return mesh(vertices, faces, colour, location, **look)


# ---------------------------------------------------------------------------------------------------
# LAYOUT: the game's own numbers, in plot space (x, z). Copied, not measured:
# Layout.luau "Plots" and Plots.luau buildGround, buildStrip, buildBase, buildPortal, buildPads,
# buildTeleporter and lamp.
# ---------------------------------------------------------------------------------------------------
WIDTH, DEPTH, YARD = 110, 150, 16  # PLOT_WIDTH, PLOT_DEPTH, PLOT_YARD: the ground is x -55 ... 55, z -16 ... 150
PATH_WIDTH = 8
PATH = ((0, 145), (0, 128), (-38, 128), (-38, 98), (38, 98), (38, 68), (-38, 68), (-38, 38), (0, 38), (0, 14))
PADS = ((-14, 26), (14, 26), (-8, 53), (8, 53), (-24, 53), (24, 53), (-8, 83), (8, 83), (-24, 83), (24, 83),
        (-20, 113), (4, 113), (24, 113), (-50, 53), (50, 83), (-50, 113))
PAD_SIZE, PAD_HEIGHT = 7, 0.5
ROAD_TOP, KERB = 0.2, 0.8  # the road's top, and how much kerb shows on each side of it (the code's kerb top is 0.1)
PORTAL_DEPTH = 2  # the portal stands this far behind the first point of the path, and the road starts under it
PORTAL_AT = (PATH[0][0], PATH[0][1] + PORTAL_DEPTH)
GATE_Z = PATH[-1][1]  # 14: the wall of the base stands across the end of the path
GATE_WIDTH, GATE_HEIGHT = 14, 14  # the opening of the gate; the portal's sheet is as wide and 15 high
TOWER_X, TOWER_RADIUS, TOWER_TOP = GATE_WIDTH / 2 + 3.5, 3.5, GATE_HEIGHT + 4  # the two towers of the gate (solid)
WALL_FROM, WALL_HEIGHT, WALL_THICK = TOWER_X + 3.5, 4.5, 2  # the wall from each tower to the fence (solid)
NAME_SIGN = (GATE_WIDTH - 1.6, 2.4, 3.4)  # the owner's name: 12.4 x 2.4 on both faces, 3.4 apart ...
NAME_SIGN_Y = GATE_HEIGHT + 1.6  # ... its middle this high
PLAZA_WIDTH, PLAZA_TOP = 40, 0.15  # the paving behind the gate: x -20 ... 20, z 0 ... 14
ARRIVAL, ARRIVAL_RADIUS, ARRIVAL_TOP = (0, 4), 3.5, 0.25  # the owner's disc, in the owner's colour
TELEPORTERS = {"worlds": (-13, 3), "market": (13, 3)}
TELEPORTER_RING, TELEPORTER_BEAM, TELEPORTER_ORB = 3.2, 1.7, 9.9  # the ring's and the beam's radius, the orb's height
TELEPORTER_TINTS = {"worlds": "46DC8C", "market": "8264FF"}  # rgb(70, 220, 140) and rgb(130, 100, 255)
LAMPS = ((-49, -11), (49, -11))  # x = +-(WIDTH / 2 - 6), z = -YARD + 5
LAMP_BULB, LAMP_BULB_SIZE = 12.0, 2.2  # the game's bulb: a ball this high and this wide
FENCE_X, FENCE_RAILS = WIDTH / 2 - 0.7, (1.3, 2.7)  # the rails are solid
RIM = 3  # how thick the game's solid skyline is: it stands just outside the ground
WORLD_SIGN = (-9.9, 9.9, 24.76, 31.56)  # the world's name on the middle slab of the skyline, at z = 150: x from, x to, y from, y to
OWNER = "FF6161"  # a stand-in for the owner's colour in the photos: the game's colour of slot 1


def at(x, z, y=0.0):
    """A point of plot space (x across, z up the plot, y up) in Blender's."""
    return Vector((x, -z, y))


def place(build, spot, face=0.0, scale=1.0, **options):
    """Builds a prop (made around its own origin, standing on z = 0, its front towards -Y) and stands it at
    (x, z) or (x, z, y) of plot space, its front looking `face` (0 up the plot, 90 towards +x, 180 at the
    yard). Returns the frame it stands at."""
    first = len(made)
    build(**options)
    frame = Matrix.Translation(at(*spot)) @ Matrix.Rotation(math.radians(face), 4, "Z")
    for obj in made[first:]:
        obj.matrix_basis = frame @ Matrix.Scale(scale, 4) @ obj.matrix_basis
    return frame


def moved(first, frame):
    """Moves every piece made since `first` by a frame: a part of a prop built somewhere handier."""
    for obj in made[first:]:
        obj.matrix_basis = frame @ obj.matrix_basis


def stand(name, build, spot, face=0.0, also=(), **options):
    """A shell: a group of its own, on one of its spots. `also` names the meshes that share its origin."""
    global group
    home, group = group, name
    shells[name] = place(build, spot, face, **options)
    for other in also:
        shells[other] = shells[name]
    group = home


def into(name):
    """From here on the pieces go to another mesh of the shell being built (its trim, its sheet). In a
    stand-in for the photos they stay with the stand-in. Returns the group to go back to."""
    global group
    home = group
    if home not in RENDER_ONLY:
        group = name
    return home


def turned(way):
    """A quarter turn of a direction (x, z)."""
    return Vector((-way.y, way.x))


def offset_line(points, offset, steps=6, back=0.0):
    """The line `offset` beside a path of (x, z) points that turns in right angles. Round the outside of a
    bend it runs in an arc, on the inside it has one sharp corner. Whatever the offset, the line has as many
    points, so two of them make a strip. `back` starts it that far before the first point."""
    points = [Vector(point) for point in points]
    ways = [(b - a).normalized() for a, b in zip(points, points[1:])]
    line = [points[0] - ways[0] * back + turned(ways[0]) * offset]
    for corner, a, b in zip(points[1:-1], ways, ways[1:]):
        inside = turned(a).dot(b) * offset >= 0
        for step in range(steps + 1):
            if inside:
                line.append(corner + (turned(a) + turned(b)) * offset)
            else:
                turn = step / steps * math.pi / 2
                line.append(corner + (turned(a) * math.cos(turn) + turned(b) * math.sin(turn)) * offset)
    line.append(points[-1] + turned(ways[-1]) * offset)
    return line


def sweep(points, profile, colour, steps=6, back=0.0, caps=False, **look):
    """Pulls a cut of (offset, height) points along a path of (x, z) points: a road, a kerb."""
    lines = [offset_line(points, offset, steps, back) for offset, height in profile]
    count = len(lines[0])
    vertices = [at(point.x, point.y, height) for line, (offset, height) in zip(lines, profile) for point in line]
    faces = [(level * count + row, level * count + row + 1, (level + 1) * count + row + 1, (level + 1) * count + row) for level in range(len(profile) - 1) for row in range(count - 1)]
    if caps:
        faces += [tuple(level * count for level in range(len(profile))), tuple(level * count + count - 1 for level in range(len(profile)))]
    return patch(vertices, faces, colour, **look)


def plate(outline, top, colour, **look):
    """A flat piece with an outline of (x, z) points."""
    return patch([at(point[0], point[1], top) for point in outline], [tuple(range(len(outline)))], colour, **look)


# ---------------------------------------------------------------------------------------------------
# Plants and dressing
# ---------------------------------------------------------------------------------------------------
def tree(leaf=LEAVES[0], kind="round", fruit=None, fine=True):
    """The island's tree: a fat trunk and a few balls of leaves in three tones of one green. About 16 tall.
    `fine` is for the ones a player walks under; the ones on the hills get by with fewer corners."""
    big, small = (16, 10) if fine else (12, 8)
    tube(1.25, 7.5, (0, 0, -0.6), (0.04, 0, 1), WOOD, tip=0.8, vertices=8 if fine else 6)
    if kind == "round":
        ball(5.3, (0, 0, 10.2), leaf, scale=(1, 1, 0.9), segments=big)
        ball(3.5, (-3.3, -1.0, 8.2), shade(leaf, -0.1), segments=small)
        ball(3.3, (3.1, 1.2, 8.7), shade(leaf, -0.1), segments=small)
        ball(3.1, (0.9, -1.6, 13.2), shade(leaf, 0.14), segments=small)
        for x, y, z in fruit and ((-3.6, -3.4, 9.4), (2.2, -4.6, 10.6), (4.9, -1.2, 11.4), (-0.6, -4.2, 13.6), (-5.2, 0.6, 10.8)) or ():
            ball(0.75, (x, y, z), fruit, segments=6, roughness=0.3)
    else:  # three balls stacked like a fir
        ball(4.7, (0, 0, 8.2), shade(leaf, -0.1), scale=(1, 1, 0.8), segments=big - 2)
        ball(3.8, (0, 0, 12.2), leaf, scale=(1, 1, 0.85), segments=big - 4)
        ball(2.7, (0, 0, 15.6), shade(leaf, 0.14), scale=(1, 1, 0.95), segments=small)


def rocks(colour=ROCK):
    chunk((2.3, 2.0, 1.7), (0, 0, 0.9), colour)
    chunk((1.3, 1.2, 1.0), (2.4, 0.6, 0.5), shade(colour, -0.14), detail=1)
    chunk((0.95, 0.9, 0.7), (-2.1, -0.9, 0.35), shade(colour, 0.14), detail=1)


def fence_run(start, end, count, first=True, last=True):
    """A wooden fence from one point of the plot to another, `count` posts on it: chunky posts and the two
    rails the game has (they are solid in the game, and stand exactly here)."""
    start, end = Vector(start), Vector(end)
    way = end - start
    turn = -math.atan2(way.x, -way.y) if way.length else 0
    for index in range(count):
        if (index == 0 and not first) or (index == count - 1 and not last):
            continue
        point = start + way * index / (count - 1)
        box((1.3, 1.3, 4.3), at(point.x, point.y, 1.95), WOOD_LIGHT, bevel=0.3, segments=1, rotation=(0, 0, turn))
    middle = (start + end) / 2
    for height in FENCE_RAILS:
        slab((0.5, way.length, 0.5), at(middle.x, middle.y, height), WOOD, rotation=(0, 0, turn))


def lamp():
    """The game's lamp, without its bulb: the game's own glowing ball (LAMP_BULB_SIZE across, its middle
    LAMP_BULB up) hangs in the cage, so its light and its Halloween colour stay the game's."""
    tube(1.15, 0.9, (0, 0, 0), UP, STONE, vertices=10)
    tube(0.85, 0.4, (0, 0, 0.9), UP, STONE_DARK, vertices=10)
    tube(0.42, 9.0, (0, 0, 1.3), UP, IRON, tip=0.32, vertices=8)
    hoop(0.5, 0.17, (0, 0, 2.4), GOLD, segments=10, roughness=0.3)
    hoop(0.42, 0.15, (0, 0, 9.5), GOLD, segments=10, roughness=0.3)
    tube(0.45, 0.6, (0, 0, 10.3), UP, IRON, tip=1.3, vertices=10)
    for index in range(4):
        x, y = ring(index * 90 + 45, 1.24)
        tube(0.1, 2.3, (x, y, 10.85), UP, IRON, vertices=4)
    tube(1.75, 1.3, (0, 0, 13.1), UP, IRON, tip=0.2, vertices=10)
    ball(0.32, (0, 0, 14.6), GOLD, segments=8, roughness=0.3)


def windmill():
    """A landmark for the hills beside the plot: a stone mill with a red cap and four sails. Front -Y."""
    tube(4.7, 1.2, (0, 0, 0), UP, STONE_DARK, vertices=12)
    tube(4.2, 12.6, (0, 0, 1.0), UP, STONE_PALE, tip=3.0, vertices=12)
    hoop(3.72, 0.3, (0, 0, 5.4), WOOD, segments=12)
    box((2.0, 0.6, 3.2), (0, -4.0, 2.5), WOOD_DARK, bevel=0.2, segments=1)
    box((1.3, 0.5, 1.7), (0, -3.25, 9.2), INK, bevel=0.2, segments=1)
    lathe([(0, 19.2), (1.7, 16.9), (3.4, 14.6), (4.1, 13.5), (3.8, 13.2), (0, 13.2)], RED, segments=12)
    ball(0.45, (0, 0, 19.3), GOLD, segments=8, roughness=0.3)
    hub = Vector((0, -3.6, 11.6))
    tube(0.6, 2.2, hub + Vector((0, 1.4, 0)), (0, -1, 0), WOOD_DARK, vertices=8)
    ball(0.85, hub + Vector((0, -0.8, 0)), GOLD, segments=8, roughness=0.3)
    for index in range(4):
        first = len(made)
        slab((0.5, 0.4, 9.4), (0, 0, 4.9), WOOD_DARK)
        box((2.5, 0.22, 6.6), (1.35, 0, 5.9), COBBLE, bevel=0.1, segments=1)
        for z in (3.4, 5.9, 8.4):
            slab((2.7, 0.3, 0.3), (1.35, 0, z), WOOD)
        moved(first, Matrix.Translation(hub + Vector((0, -0.4, 0))) @ Matrix.Rotation(math.radians(index * 90 + 24), 4, "Y"))


def cloud():
    for x, y, z, radius in ((0, 0, 0, 1.0), (-1.15, 0.1, -0.2, 0.72), (1.2, -0.1, -0.15, 0.8), (0.45, 0.4, 0.4, 0.66), (-0.5, -0.3, 0.3, 0.6), (2.05, 0, -0.38, 0.5), (-1.95, 0, -0.4, 0.46)):
        ball(radius, (x, y, z * 0.8), WHITE, scale=(1, 1, 0.78), segments=16, roughness=1.0)


# ---------------------------------------------------------------------------------------------------
# The hills round the plot and the rock behind the portal: the plot's horizon. All of it stands outside the
# ground, where the game has its solid skyline.
# ---------------------------------------------------------------------------------------------------
hills = []  # (x, z, across, along, height)
BUN = ((0.0, 1.0), (0.3, 0.97), (0.55, 0.86), (0.76, 0.64), (0.9, 0.36), (1.0, 0.0))  # a hill's cut: (share of its radius, share of its height)


def hill(x, z, across, along, height, colour, segments=16):
    """A round green hill, `across` wide (its radius along x) and `along` deep (along z)."""
    rings = [(across * share, height * rise) for share, rise in BUN[:-1]] + [(across, -0.6)]
    lathe(rings, colour, segments=segments, stretch=along / across, location=at(x, z), roughness=0.9)
    hills.append((x, z, across, along, height))


def hill_top(x, z):
    """How high the hills are at a point."""
    best = 0.0
    for cx, cz, across, along, height in hills:
        share = math.hypot((x - cx) / across, (z - cz) / along)
        for (a, low), (b, high) in zip(BUN, BUN[1:]):
            if a <= share < b:
                best = max(best, height * (low + (high - low) * (share - a) / (b - a)))
    return best


def peak(radius, height, colour, stretch=1.0, segments=9):
    """A pointed crag, faceted like the rock under the island."""
    lathe([(0, height), (radius * 0.2, height * 0.9), (radius * 0.46, height * 0.64), (radius * 0.72, height * 0.34), (radius * 0.94, height * 0.08), (radius, -1.5)],
          colour, segments=segments, rough=radius * 0.06, smooth=False, stretch=stretch)


def butte(radius, height, colour, stretch=1.0, cap=GRASS_DEEP, segments=9):
    """A blunt rock with a cap of grass, like the island's floating rocks."""
    lathe([(0, height), (radius * 0.5, height * 0.985), (radius * 0.74, height * 0.84), (radius * 0.9, height * 0.45), (radius, 0), (radius * 1.02, -1.5)],
          colour, segments=segments, rough=radius * 0.05, smooth=False, stretch=stretch)
    if cap:
        ball(radius * 0.66, (0, 0, height - 0.7), cap, scale=(1, stretch, 0.3), segments=12, roughness=0.9)
        ball(radius * 0.4, (radius * 0.2, radius * 0.12, height + 0.1), shade(cap, 0.12), scale=(1, stretch, 0.34), segments=10, roughness=0.9)


def waterfall(fall, pool, reach):
    """Water that comes out from under a butte's cap, runs down its front and ends in a small pool at its
    foot. `fall` is its path as (forward of the butte's middle, height) points, `pool` the pool's radius,
    `reach` how far forward of the butte's middle the pool lies."""
    global group
    for index in range(7):  # stones round the pool
        x, y = ring(index * 38 + 66, pool + 0.5)
        chunk((rng.uniform(0.7, 1.0), rng.uniform(0.7, 0.95), rng.uniform(0.55, 0.8)), (x, -reach + y, 0.3), rng.choice((ROCK, ROCK_LIGHT, ROCK_DARK)), detail=1)
    for x, z, radius in ((-0.9, 0.5, 0.8), (0.3, 0.7, 0.95), (1.1, 0.4, 0.7)):  # foam where it lands
        ball(radius, (x, -fall[-1][0] - 0.3, z), WHITE, segments=8)
    home, group = group, "Water"
    ribbon(fall, 3.6, WATER, lift=0.7, roughness=0.15)
    for shift, width, skip in ((-0.9, 0.7, 1), (0.8, 0.5, 2)):  # lighter streaks down the fall
        ribbon(fall[skip:], width, WATER_LIGHT, thickness=0.3, shift=shift, lift=0.9, roughness=0.15)
    tube(pool, 0.4, (0, -reach, -0.1), UP, WATER, vertices=16, roughness=0.15)
    tube(pool * 0.58, 0.4, (0.25, -reach + 0.2, -0.06), UP, shade(WATER, 0.25), vertices=12, roughness=0.15)
    group = home


def monolith(radius, height, colour, stretch=1.0, segments=11):
    """The big rock behind the portal: steep, so the world's sign can hang on its face."""
    lathe([(0, height), (radius * 0.3, height * 0.95), (radius * 0.58, height * 0.82), (radius * 0.8, height * 0.6), (radius * 0.9, height * 0.32), (radius, 0), (radius * 1.02, -1.5)],
          colour, segments=segments, rough=radius * 0.045, smooth=False, stretch=stretch)


# ---------------------------------------------------------------------------------------------------
# The shells. Each is built around its own origin, standing on z = 0, its front towards -Y.
# ---------------------------------------------------------------------------------------------------
def pad(tint=WHITE):
    """One cannon pad: PAD_SIZE square, a stone plate on a darker foot with gold corners. Nothing of it is
    higher than PAD_HEIGHT (its corners); the plate, flat and empty, is 0.04 lower, so the game's "+" on
    the pad's top and the tower's foot lie just over it. PadTrim is the band round the plate."""
    global group
    tile(PAD_SIZE, PAD_SIZE, 0.9, 0.0, 0.32, STONE_DARK, lip=0.1)
    tile(6.3, 6.3, 0.7, 0.28, PAD_HEIGHT - 0.04, STONE_PALE, lip=0.07)
    for x in (-1, 1):
        for y in (-1, 1):
            tile(1.5, 1.5, 0.45, 0.2, PAD_HEIGHT, GOLD, lip=0.07, location=(x * 2.75, y * 2.75, 0), roughness=0.3)
    home = into("PadTrim")
    inlay(rounded(6.0, 6.0, 0.5), rounded(4.9, 4.9, 0.3), PAD_HEIGHT - 0.03, tint)
    group = home


def teleporter(tint=WHITE):
    """A walk-on teleporter: a low round dais (the game's ring is TELEPORTER_RING across it) under a slim
    stone arch. The game's beam (TELEPORTER_BEAM wide, 0.4 to 8.4 up) stands in the arch. TeleporterTrim
    is what the game tints: the ring and the disc on the dais, the orb in the arch's crown (where the
    game's own orb floats) and a gem on each leg. Its title floats over it: nothing here is higher than 11."""
    global group
    tube(3.6, 0.3, (0, 0, 0), UP, STONE_DARK, vertices=24)
    tube(TELEPORTER_RING, 0.42, (0, 0, 0), UP, STONE, vertices=24)
    for index in range(8):
        x, y = ring(index * 45 + 22.5, 3.4)
        ball(0.3, (x, y, 0.3), GOLD, segments=6, roughness=0.3)
    reach = 3.9  # how far the legs stand from the middle; the arch springs where its crown comes TELEPORTER_ORB high
    crown = TELEPORTER_ORB - reach
    for side in (-1, 1):
        box((2.1, 2.1, 1.0), (side * reach, 0, 0.5), STONE_DARK, bevel=0.3, segments=1)
        for index in range(3):
            box((1.6, 1.6, (crown - 1.0) / 3 + 0.04), (side * reach, 0, 1.0 + (index + 0.5) * (crown - 1.0) / 3), STONE if index % 2 == 0 else STONE_PALE, bevel=0.3, segments=1, rotation=(0, 0, rng.uniform(-0.08, 0.08)))
        hoop(0.92, 0.2, (side * reach, 0, 1.15), GOLD, segments=10, roughness=0.3)
    for index, degrees in enumerate((18, 42, 66, 114, 138, 162)):
        angle = math.radians(degrees)
        box((1.72, 1.55, 1.5), (-math.cos(angle) * reach, 0, crown + math.sin(angle) * reach), STONE_PALE if index % 2 == 0 else STONE, bevel=0.3, segments=1, rotation=(0, angle - math.pi / 2, 0))
    hoop(1.12, 0.22, (0, 0, crown + reach), GOLD, rotation=(math.pi / 2, 0, 0), segments=14, roughness=0.3)
    home = into("TeleporterTrim")
    lathe([(2.25, 0.42), (2.32, 0.47), (2.88, 0.47), (2.95, 0.42)], tint, segments=24, emission=0.9)
    lathe([(0, 0.47), (TELEPORTER_BEAM, 0.47), (TELEPORTER_BEAM + 0.08, 0.42)], tint, segments=20, emission=0.9)
    ball(0.95, (0, 0, crown + reach), tint, segments=12, emission=1.2)
    for side in (-1, 1):
        for front in (-1, 1):
            tube(0.5, 0.45, (side * reach, front * 0.78, 3.6), (0, front, 0), tint, tip=0.0, vertices=4, emission=0.9)
    group = home


def arch_wall(half, spring, top, depth, colour, steps=12):
    """The wall over a round arch that is `half` wide to each side and springs `spring` up: as high as
    `top`, `depth` thick, around y = 0."""
    vertices, faces = [], []
    for index in range(steps + 1):
        angle = math.pi * index / steps
        x, z = half * math.cos(angle), spring + half * math.sin(angle)
        for y in (-depth / 2, depth / 2):
            vertices += [(x, y, z), (x, y, top)]
    for index in range(steps):
        a, b = index * 4, index * 4 + 4
        faces += [(a, b, b + 1, a + 1), (a + 2, a + 3, b + 3, b + 2), (a, a + 2, b + 2, b), (a + 1, b + 1, b + 3, a + 3)]
    faces += [(0, 1, 3, 2), (steps * 4, steps * 4 + 2, steps * 4 + 3, steps * 4 + 1)]
    return mesh(vertices, faces, colour, tidy=True)


def banner(width, length, colour, location, back=False):
    """A cloth hanging down from `location`, its end cut in a swallowtail. It looks to the front, or to the back."""
    half, notch, thick = width / 2, width * 0.36, 0.14
    outline = ((-half, 0), (half, 0), (half, -length), (0, -length + notch), (-half, -length))
    vertices = [(x, -thick, z) for x, z in outline] + [(x, thick, z) for x, z in outline]
    faces = [(0, 1, 2, 3, 4), (9, 8, 7, 6, 5)] + [(index, 5 + index, 5 + (index + 1) % 5, (index + 1) % 5) for index in range(5)]
    return mesh(vertices, faces, colour, location, (0, 0, math.pi if back else 0), smooth=False, tidy=True, roughness=0.8)


def door_leaf():
    """One leaf of the gate's door, from its hinge along +X: five planks that follow the arch, two iron
    bands with gold studs and a ring to pull."""
    for index in range(5):
        along = 0.7 + index * 1.4
        height = GATE_HEIGHT / 2 + math.sqrt(49 - (7 - along) ** 2) - 0.25
        box((1.36, 0.56, height - 0.3), (along, 0, 0.3 + (height - 0.3) / 2), WOOD if index % 2 == 0 else shade(WOOD, 0.12), bevel=0.16, segments=1)
    for z in (3.2, 8.4):
        slab((6.9, 0.8, 0.75), (3.5, 0, z), IRON)
        for along in (1.0, 3.5, 6.0):
            for front in (-1, 1):
                ball(0.3, (along, front * 0.42, z), GOLD, segments=6, roughness=0.3)
    for front in (-1, 1):
        hoop(0.62, 0.15, (5.9, front * 0.42, 5.8), GOLD, rotation=(math.pi / 2, 0, 0), segments=10, roughness=0.3)


def gate(tint=OWNER):
    """The base's gatehouse, the piece the monsters come for: two round towers with pointed roofs and
    banners, a round arch between them with a portcullis drawn up and its door standing open to the road,
    the owner's name over it on both sides, a crest on top, and a wall with battlements out to each fence.
    Its origin is the middle of the gate on the ground; its front (-Y) is the side the monsters see.
    The game's solid parts are where its own are: the towers (TOWER_RADIUS, TOWER_TOP high) and the walls
    (WALL_THICK thick, WALL_HEIGHT high). The arch is GATE_WIDTH wide and GATE_HEIGHT high in the middle.
    GateTrim is everything in the owner's colour: the roofs, the flags, the banners, the crest and the
    disc of the arrival pad (10 studs behind the gate, like the game's)."""
    global group
    spring = GATE_HEIGHT / 2  # the arch: half a circle, GATE_WIDTH across
    for side in (-1, 1):
        x = side * TOWER_X
        tube(4.0, 1.1, (x, 0, 0), UP, STONE_DARK, vertices=16)
        tube(3.8, 0.6, (x, 0, 1.1), UP, STONE, tip=3.62, vertices=16)
        tube(3.6, 13.6, (x, 0, 1.7), UP, STONE_PALE, tip=3.4, vertices=16)
        hoop(3.5, 0.3, (x, 0, 8.5), GOLD, segments=16, roughness=0.3)
        tube(3.4, 1.3, (x, 0, 15.3), UP, STONE_DARK, tip=4.4, vertices=16)
        tube(4.4, 1.1, (x, 0, 16.6), UP, STONE, vertices=16)
        for index in range(8):
            a, b = ring(index * 45 + 22.5, 3.72)
            box((1.55, 1.2, 1.25), (x + a, b, 18.3), STONE_PALE, bevel=0.22, segments=1, rotation=(0, 0, -math.radians(index * 45 + 22.5)))
        for degrees, z in ((38, 3.6), (-52, 5.4), (128, 4.2), (-140, 6.6), (64, 11.6), (-118, 12.6), (150, 12.0), (-30, 13.2)):  # stones that stand out of the wall
            a, b = ring(degrees, 3.42)
            slab((1.7, 0.5, 0.85), (x + a, b, z), STONE_DARK if z < 9 else STONE, rotation=(0, 0, -math.radians(degrees)))
        for front in (-1, 1):  # a window to the road and one to the yard
            box((2.0, 0.6, 3.2), (x, front * 3.3, 5.6), STONE_DARK, bevel=0.25, segments=1)
            box((1.2, 0.5, 2.0), (x, front * 3.48, 5.35), INK, bevel=0.1, segments=1)
            tube(0.6, 0.5, (x, front * 3.23, 6.35), (0, front, 0), INK, vertices=10)
            tube(0.14, 3.2, (x - 1.6, front * 3.95, 14.2), (1, 0, 0), GOLD, vertices=6, roughness=0.3)  # the banner's rod
            for end in (-1, 1):
                ball(0.3, (x + end * 1.6, front * 3.95, 14.2), GOLD, segments=6, roughness=0.3)
            star(0.72, (x, front * 4.02, 12.5), GOLD, depth=0.16, roughness=0.3)
        tube(0.16, 4.2, (x, 0, 26.0), UP, IRON, vertices=5)
        ball(0.5, (x, 0, 26.2), GOLD, segments=8, roughness=0.3)
        ball(0.3, (x, 0, 30.3), GOLD, segments=6, roughness=0.3)
        home = into("GateTrim")
        lathe([(0, 26.2), (0.95, 24.0), (2.1, 21.4), (3.25, 19.2), (3.9, 18.1), (3.7, 17.7), (0, 17.7)], tint, segments=16, location=(x, 0, 0))
        for front in (-1, 1):
            banner(2.7, 5.0, tint, (x, front * 3.9, 14.2), back=front > 0)
        # The flag: a pennant that flies away from the gate.
        mesh([(0, -0.1, 0.95), (0, -0.1, -0.95), (3.2, -0.1, 0), (0, 0.1, 0.95), (0, 0.1, -0.95), (3.2, 0.1, 0)], [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)],
             tint, (x + side * 0.16, 0, 29.1), (0, 0, 0 if side > 0 else math.pi), smooth=False, tidy=True, roughness=0.8)
        group = home
        # The piers of the arch, up to the top of the gatehouse.
        box((1.75, 3.6, 17.4), (side * (GATE_WIDTH / 2 + 0.875), 0, 8.7), STONE_DARK, bevel=0.3, segments=1)
        for index, degrees in enumerate((13, 31, 48)):  # the arch's stones; over them the name board takes the wall
            angle = math.radians(degrees if side < 0 else 180 - degrees)
            box((2.6, 3.5, 1.5), (-math.cos(angle) * 7.75, 0, spring + math.sin(angle) * 7.75), STONE_PALE if index % 2 else STONE, bevel=0.3, segments=1, rotation=(0, angle - math.pi / 2, 0))

    arch_wall(GATE_WIDTH / 2, spring, 17.4, 3.1, STONE)
    box((16.0, 3.9, 0.6), (0, 0, 17.65), STONE_DARK, bevel=0.2, segments=1)
    for x in (-6, -3, 0, 3, 6):
        box((1.9, 3.9, 1.3), (x, 0, 18.55), STONE_PALE, bevel=0.25, segments=1)
    # The owner's name: a flat, empty board on each side, a hair behind where the game writes.
    wide, tall, apart = NAME_SIGN
    for front in (-1, 1):
        slab((wide + 0.7, 0.3, tall + 0.7), (0, front * (apart / 2 - 0.2), NAME_SIGN_Y), BOARD)
        for z in (-1, 1):
            box((wide + 1.3, 0.5, 0.34), (0, front * (apart / 2 - 0.1), NAME_SIGN_Y + z * (tall / 2 + 0.3)), GOLD, bevel=0.1, segments=1, roughness=0.3)
        for x in (-1, 1):
            box((0.34, 0.5, tall + 0.94), (x * (wide / 2 + 0.48), front * (apart / 2 - 0.1), NAME_SIGN_Y), GOLD, bevel=0.1, segments=1, roughness=0.3)
    # The crest on top: a shield in the owner's colour with a gold star, the same from both sides.
    tube(0.3, 1.0, (0, 0, 19.1), UP, GOLD, vertices=6, roughness=0.3)
    hoop(2.0, 0.26, (0, 0, 21.8), GOLD, rotation=(math.pi / 2, 0, 0), segments=18, roughness=0.3)
    for front in (-1, 1):
        star(1.2, (0, front * 0.3, 21.8), GOLD, depth=0.2, roughness=0.3)
    home = into("GateTrim")
    tube(2.0, 0.44, (0, 0.22, 21.8), (0, -1, 0), tint, vertices=18)
    group = home
    # The portcullis, drawn up into the arch on the road's side: gold tips over the monsters' heads.
    grille = -0.95
    for x in (-5, -3, -1, 1, 3, 5):
        top = spring + math.sqrt(49 - x * x) + 0.2
        slab((0.5, 0.5, top - 11.0), (x, grille, (top + 11.0) / 2), IRON)
        tube(0.42, 0.9, (x, grille, 11.0), (0, 0, -1), GOLD, tip=0.0, vertices=4, roughness=0.3)
    for z in (11.5, 12.9):
        slab((2 * math.sqrt(49 - (z - spring) ** 2) + 0.3, 0.4, 0.5), (0, grille, z), IRON)
    # The door: two leaves swung open to the road, a little wider than the way.
    for side in (-1, 1):
        first = len(made)
        door_leaf()
        moved(first, Matrix.Translation((side * (GATE_WIDTH / 2 + 0.3), -1.9, 0)) @ Matrix.Rotation(math.radians(-90 + side * 10), 4, "Z"))
    # The walls out to the fences, with a post every nine studs and battlements between them.
    reach = WIDTH / 2 - WALL_FROM
    for side in (-1, 1):
        middle = side * (WALL_FROM + reach / 2)
        slab((reach + 0.6, 2.6, 0.9), (middle, 0, 0.45), STONE_DARK)
        slab((reach + 0.6, WALL_THICK, 3.2), (middle, 0, 2.5), STONE)
        box((reach + 0.6, 2.5, 0.5), (middle, 0, WALL_HEIGHT - 0.25), STONE_PALE, bevel=0.12, segments=1)
        posts = (18.6, 27.6, 36.6, 45.6, 53.9)
        for x in posts:
            box((2.8, 3.0, 5.4), (side * x, 0, 2.7), STONE_DARK, bevel=0.3, segments=1)
            box((3.2, 3.4, 0.6), (side * x, 0, 5.6), STONE_PALE, bevel=0.2, segments=1)
            ball(0.7, (side * x, 0, 6.3), GOLD, segments=8, roughness=0.3)
        for before, after in zip((WALL_FROM - 0.4,) + posts, posts):
            count = 1 if after - before < 6 else 3
            for index in range(count):
                x = before + (after - before) * (index + 1) / (count + 1)
                box((1.5, 2.3, 0.9), (side * x, 0, WALL_HEIGHT + 0.42), STONE, bevel=0.2, segments=1)
            for index in range(2):  # a few stones that stand out, on both faces
                x = before + (after - before) * (0.3 + 0.4 * index)
                for front in (-1, 1):
                    slab((1.8, 0.24, 0.8), (side * (x + front * 0.5), front * WALL_THICK / 2, 1.7 + 1.1 * ((index + (front > 0)) % 2)), STONE_DARK if index % 2 else STONE_PALE)
    # The arrival pad, behind the gate: a stone ring with gold studs; the disc in it is the owner's.
    behind = GATE_Z - ARRIVAL[1]
    lathe([(ARRIVAL_RADIUS - 0.05, 0.14), (ARRIVAL_RADIUS, 0.28), (4.0, 0.28), (4.08, 0.14)], STONE, segments=28, location=(0, behind, 0))
    for index in range(8):
        x, y = ring(index * 45 + 22.5, 3.76)
        ball(0.3, (x, behind + y, 0.26), GOLD, scale=(1, 1, 0.6), segments=6, roughness=0.3)
    star(2.3, (0, behind, 0.205), WHITE, depth=0.045, rotation=(math.pi / 2, 0, 0))
    home = into("GateTrim")
    lathe([(0, 0.2), (ARRIVAL_RADIUS, 0.2), (ARRIVAL_RADIUS, 0.14)], tint, segments=28, location=(0, behind, 0), emission=0.5)
    group = home


def portal():
    """The monsters' portal: an arch of dark stone made into a face, with horns, two angry eyes and fangs in
    its mouth. Its origin is the middle of the sheet on the ground (the game's own spot), its front (-Y) looks
    down the road at the gate. The mouth is 14.5 wide and 16.5 high in the middle: the game's sheet is 14 by 15.
    PortalSheet is everything that glows, for Neon: the sheet with its dark whirl, the eyes, the runes."""
    global group
    crown, reach = 9.3, 9.2  # where the arch springs, and its radius through the middle of its stones
    for side in (-1, 1):
        box((4.8, 5.0, 1.5), (side * 9.45, 0, 0.75), LAIR_DEEP, bevel=0.45)
        for index in range(3):
            box((3.9, 3.9, 2.6), (side * reach, 0, 2.8 + index * 2.6), LAIR if index % 2 == 0 else LAIR_DARK, bevel=0.5, rotation=(0, 0, rng.uniform(-0.07, 0.07)))
    for index, degrees in enumerate((15, 40, 65, 90, 115, 140, 165)):
        angle = math.radians(degrees)
        size = (4.9, 4.6, 4.6) if degrees == 90 else (4.15, 3.9, 3.9)
        box(size, (-math.cos(angle) * reach, 0, crown + math.sin(angle) * reach), LAIR_DARK if index % 2 == 0 else LAIR, bevel=0.55, rotation=(0, angle - math.pi / 2, 0))
    # Fangs in the mouth, on the road's side of the sheet.
    for degrees in (30, 52, 75, 105, 128, 150):
        angle = math.radians(degrees)
        inner = 6.95 if 70 < degrees < 110 else 7.3
        tube(0.66, 1.9, (math.cos(angle) * inner, -1.0, crown + math.sin(angle) * inner), (-math.cos(angle), 0, -math.sin(angle)), COBBLE, tip=0.0, vertices=8, roughness=0.3)
    # Horns: fat cones that bend up and in.
    for side in (-1, 1):
        bends = ((8.2, 16.0, 1.55), (10.9, 18.1, 1.3), (12.8, 20.6, 1.0), (13.7, 23.2, 0.66), (13.3, 25.6, 0.0))  # (x, z, radius)
        for (x, z, radius), (next_x, next_z, next_radius) in zip(bends, bends[1:]):
            start, end = Vector((side * x, 0.2, z)), Vector((side * next_x, 0.2, next_z))
            tube(radius, (end - start).length, start, end - start, BONE if next_radius > 0.6 else BONE_DARK, tip=next_radius, vertices=10, roughness=0.4)
            ball(radius, start, BONE, segments=10, roughness=0.4)
        hoop(1.62, 0.32, (side * 8.5, 0.2, 16.3), GOLD, rotation=(0, side * math.radians(46), 0), segments=12, roughness=0.3)
    # The face: brows and pupils. (The eyes themselves glow: they are with the sheet.)
    for side in (-1, 1):
        x = side * 3.95
        ball(0.66, (x - side * 0.25, -2.5, 17.5), INK, scale=(0.6, 0.3, 1.25), segments=10, roughness=0.3)
        ball(0.2, (x - side * 0.25 - 0.3, -2.62, 18.1), WHITE, scale=(1, 0.3, 1), segments=6, roughness=0.2)
        box((3.3, 1.0, 0.95), (x + side * 0.1, -2.25, 19.1), LAIR_DEEP, bevel=0.3, rotation=(0, -side * 0.4, 0))
    for x in (-1.5, 0, 1.5):  # a crest of spikes on its brow
        tube(0.7, 2.2 if x == 0 else 1.6, (x, 0, crown + reach + 2.0), (x * 0.12, 0, 1), LAIR_DEEP, tip=0.0, vertices=6)
    home = into("PortalSheet")
    slab((14.6, 0.36, crown), (0, 0, crown / 2), HOT, emission=1.0)
    tube(7.3, 0.4, (0, 0.2, crown), (0, -1, 0), HOT, vertices=28, emission=1.0)
    for radius, depth, x, z, colour in ((5.7, 0.5, 0.0, 8.5, HOT_DARK), (4.3, 0.6, 0.45, 8.9, HOT_DEEP), (2.9, 0.7, -0.2, 9.1, HOT_CORE), (1.5, 0.8, 0.2, 8.9, "1A0518")):  # the whirl: darker towards its middle
        tube(radius, depth, (x, depth / 2, z), (0, -1, 0), colour, vertices=20, emission=0.6)
    for x, z, radius in ((-4.6, 4.0, 0.5), (4.9, 12.0, 0.42), (-3.4, 13.4, 0.36), (4.2, 3.0, 0.3), (-5.3, 9.6, 0.3)):  # sparks
        tube(radius, 0.6, (x, 0.3, z), (0, -1, 0), "FFB3CF", vertices=8, emission=1.4)
    for side in (-1, 1):
        ball(1.3, (side * 3.95, -2.1, 17.6), "FFE45C", scale=(1, 0.36, 1.08), segments=14, emission=1.2)  # an eye
        for z in (4.2, 6.6):  # runes on the legs
            box((0.6, 0.3, 1.5), (side * reach, -2.0, z), HOT, bevel=0.1, segments=1, emission=1.2)
    tube(0.75, 0.6, (0, -2.25, crown + reach - 0.3), (0, -1, 0), HOT, tip=0.0, vertices=4, emission=1.2)  # a gem on its brow
    group = home


# ---------------------------------------------------------------------------------------------------
# Stand-ins for the photos: a tower, a monster
# ---------------------------------------------------------------------------------------------------
def stand_in_tower(colour=RED):
    """The game's rank 1 cannon in rough: a wooden plinth, a carriage with wheels, a fat barrel."""
    tube(2.5, 1.0, (0, 0, 0), UP, WOOD, vertices=16)
    box((2.2, 3.0, 0.9), (0, 0.3, 1.65), WOOD_DARK, bevel=0.2, segments=1)
    for side in (-1, 1):
        tube(1.15, 0.5, (side * 1.15, 0.4, 2.15), (side, 0, 0), IRON, vertices=12)
    aim, back = Vector((0, -math.cos(math.radians(12)), math.sin(math.radians(12)))), Vector((0, 1.7, 2.55))
    tube(0.8, 4.2, back, aim, colour, vertices=12, roughness=0.35)
    ball(0.88, back, shade(colour, -0.3), segments=10, roughness=0.35)
    tube(1.0, 0.5, back + aim * 3.8, aim, shade(colour, -0.3), vertices=12, roughness=0.35)
    tube(0.55, 0.06, back + aim * 4.3, aim, INK, vertices=10)
    tube(0.98, 0.3, back + aim * 2.6, aim, WHITE, vertices=12)


def stand_in_monster(colour="5FD35A", eye="FFE23A"):
    """One of Earth's monsters in rough: a rounded cube with two big glossy eyes. About 2.4 tall."""
    box((2.5, 2.3, 2.1), (0, 0, 1.35), colour, bevel=0.7, segments=3, roughness=0.4)
    for side in (-1, 1):
        box((0.9, 1.1, 0.55), (side * 0.7, -0.1, 0.28), shade(colour, -0.25), bevel=0.24)
        x = side * 0.62
        ball(0.55, (x, -1.15, 1.6), WHITE, scale=(1, 0.3, 1.08), segments=12)
        ball(0.45, (x, -1.22, 1.58), INK, scale=(1, 0.3, 1.1), segments=12, roughness=0.3)
        ball(0.26, (x, -1.3, 1.5), eye, scale=(1, 0.25, 1), segments=10, roughness=0.3)
        ball(0.13, (x - 0.15, -1.36, 1.78), WHITE, scale=(1, 0.3, 1), segments=6, roughness=0.2)


def words(text, spot, size, face=180.0, colour=WHITE):
    """For the photos only: what the game writes on a sign, standing upright at a point of plot space."""
    curve = bpy.data.curves.new("Words", "FONT")
    curve.body, curve.size, curve.align_x, curve.align_y = text, size, "CENTER", "CENTER"
    curve.materials.append(mat(colour, emission=0.3))
    obj = bpy.data.objects.new("RenderOnly_Words", curve)
    obj.matrix_basis = Matrix.Translation(at(*spot)) @ Matrix.Rotation(math.radians(face), 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X")
    scene.collection.objects.link(obj)


# ---------------------------------------------------------------------------------------------------
# The ground: a floating island like Earth's, but rounded-square. The lawn is level over the whole of the
# game's ground and well past it; the hills stand on the band outside.
# ---------------------------------------------------------------------------------------------------
HALF_X, HALF_Z, MIDDLE_Z, SQUARE = 91.0, 118.0, 73.0, 6  # the island reaches x +-91 and z -45 ... 191
FLAT = 0.955  # the share of the way to the edge that the grass stays level


def outline(degrees):
    """How far the island's edge is from its middle in a direction, as a share of HALF_X: a square with
    round corners, a hair uneven."""
    a = math.radians(degrees)
    return (abs(math.sin(a)) ** SQUARE + abs(math.cos(a)) ** SQUARE) ** (-1 / SQUARE) * (1 + 0.006 * math.sin(5 * a + 0.4) + 0.005 * math.sin(9 * a + 2.1))


def top(share):
    return 0.0 if share < FLAT else -2.6 * ((share - FLAT) / (1 - FLAT)) ** 2


def island(rings, colour, segments, **look):
    lathe(rings, colour, segments=segments, shape=outline, stretch=HALF_Z / HALF_X, location=at(0, MIDDLE_Z), **look)


def edge(degrees, share):
    """The point (x, z) of plot space in a direction from the island's middle, a share of the way to its edge."""
    x, y = ring(degrees, HALF_X * outline(degrees) * share)
    return x, MIDDLE_Z - y * HALF_Z / HALF_X


R = HALF_X
LOBES = 22


def drips(degrees):
    return -9.0 - 5.5 * abs(math.sin(math.radians(degrees) * LOBES / 2)) ** 0.7


def wave(depth, swing, count, phase=0.0):
    return lambda degrees: depth + swing * math.sin(math.radians(degrees) * count + phase)


def spike(radius, depth, colour=UNDER):
    lathe([(0, 2.0), (radius, 0.0), (radius * 0.72, -depth * 0.4), (radius * 0.34, -depth * 0.78), (0, -depth)], colour, segments=7, rough=radius * 0.1, smooth=False)


group = "Ground"
island([(0, 0.0), (R * FLAT, 0.0)] + [(R * share, top(share)) for share in (0.968, 0.98, 0.992, 1.0)] + [(R, -6.0), (0, -6.0)], GRASS, 72, roughness=0.9)
# A few big lighter and darker patches, so the lawn is not one flat green. (x, z, radius, colour)
for x, z, radius, colour in ((30, 21, 13, GRASS_LIGHT), (-33, 23, 11, GRASS_DEEP), (46, 50, 9, GRASS_LIGHT), (-16, 83, 12, GRASS_DEEP), (-47, 83, 8, GRASS_LIGHT), (33, 114, 12, GRASS_LIGHT),
                              (-8, 114, 10, GRASS_DEEP), (22, 140, 9, GRASS_LIGHT), (-30, 143, 10, GRASS_LIGHT), (-40, -7, 10, GRASS_DEEP), (38, -6, 11, GRASS_LIGHT), (0, 53, 9, GRASS_LIGHT)):
    dome(radius, 0.07, at(x, z), colour, rotation=(0, 0, rng.uniform(0, 3)), stretch=rng.uniform(0.72, 0.9), sink=0.02, segments=16, roughness=0.9)

group = "Cliff"
island([(R * 0.958, top(0.958) - 0.3), (R * 0.965, top(0.965) + 0.15), (R * 0.99, top(0.99) + 0.28), (R * 1.016, -3.4), (R * 1.026, -7.0), (R * 1.008, drips), (R * 0.93, -9.5), (0, -9.5)], GRASS_RIM, LOBES * 4, roughness=0.9)
island([(R * 0.9, -6.0), (R * 0.975, -7.0), (R * 0.955, -20.0), (R * 0.925, wave(-33.0, 2.2, 7)), (R * 0.6, -31.0), (0, -31.0)], DIRT, 48, rough=0.4, roughness=0.9)
island([(R * 0.6, -28.0), (R * 0.905, -29.0), (R * 0.86, -44.0), (R * 0.79, wave(-57.0, 2.8, 5, 1.0)), (R * 0.5, -53.0), (0, -53.0)], DIRT_DARK, 40, rough=0.5, roughness=0.9)
island([(R * 0.5, -50.0), (R * 0.77, -53.0), (R * 0.69, -66.0), (R * 0.55, -83.0), (R * 0.39, -100.0), (R * 0.23, -115.0), (R * 0.09, -127.0), (0, -134.0)], UNDER, 18, rough=2.4, smooth=False)
for degrees, share, z, radius, depth, colour in ((20, 0.58, -53, 19, 36, UNDER_DARK), (95, 0.62, -53, 17, 31, UNDER), (160, 0.57, -53, 20, 39, UNDER_DARK), (215, 0.64, -53, 16, 28, UNDER),
                                                 (275, 0.59, -53, 18, 35, UNDER_DARK), (330, 0.64, -53, 16, 29, UNDER), (60, 0.78, -44, 10, 21, UNDER_LIGHT), (130, 0.79, -44, 9, 19, UNDER_LIGHT),
                                                 (190, 0.8, -44, 10, 22, UNDER_LIGHT), (245, 0.8, -44, 9, 19, UNDER_LIGHT), (305, 0.79, -44, 10, 21, UNDER_LIGHT), (0, 0.8, -44, 9, 19, UNDER_LIGHT)):
    place(spike, (*edge(degrees, share), z), radius=radius, depth=depth, colour=colour)
for index in range(12):  # stones stuck in the dirt wall
    size = rng.uniform(2.6, 4.6)
    x, z = edge(index * 30 + rng.uniform(-8, 8), rng.uniform(0.945, 0.96))
    chunk((size, size, size * 0.8), at(x, z, rng.uniform(-27.0, -13.0)), rng.choice((ROCK, ROCK_LIGHT)), detail=1)

# ---- The road: exactly on the path, PATH_WIDTH wide, flat, its top at ROAD_TOP, with a kerb of KERB on
# each side. It starts under the portal and ends in the gate. Round the outside of a bend it runs in an arc
# (inside the square corner the game's own slabs make). ----
group = "Road"
HALF = PATH_WIDTH / 2
sweep(PATH, [(-HALF + 0.7, ROAD_TOP), (HALF - 0.7, ROAD_TOP)], SAND, back=PORTAL_DEPTH, roughness=0.9)
for side in (-1, 1):
    sweep(PATH, [(side * (HALF - 0.7), ROAD_TOP), (side * HALF, ROAD_TOP)], SAND_DARK, back=PORTAL_DEPTH, roughness=0.9)  # a darker band along each edge
    sweep(PATH, [(side * HALF, ROAD_TOP - 0.1), (side * HALF, 0.33), (side * (HALF + 0.1), 0.42), (side * (HALF + KERB - 0.1), 0.42), (side * (HALF + KERB), 0.33), (side * (HALF + KERB), -0.05)],
          STONE_PALE, back=PORTAL_DEPTH, caps=True, roughness=0.8)
# The plaza behind the gate: the game's 40 x 14 of paving, with round corners to the yard and a pale border.
PLAZA_PATH = ((-PLAZA_WIDTH / 2 + 3, GATE_Z), (-PLAZA_WIDTH / 2 + 3, 3), (PLAZA_WIDTH / 2 - 3, 3), (PLAZA_WIDTH / 2 - 3, GATE_Z))
sweep(PLAZA_PATH, [(-3.0, -0.05), (-3.0, PLAZA_TOP - 0.06), (-2.94, PLAZA_TOP), (-2.2, PLAZA_TOP)], STONE_PALE, roughness=0.8)
sweep(PLAZA_PATH, [(-2.2, PLAZA_TOP), (-1.5, PLAZA_TOP)], SAND_DARK, roughness=0.9)
plate(offset_line(PLAZA_PATH, -1.5), PLAZA_TOP, SAND, roughness=0.9)

# ---- The shells, on the game's spots ----
stand("Pad", pad, PADS[0], also=("PadTrim",), tint="FFC61A")
stand("Gate", gate, (0, GATE_Z), also=("GateTrim",))
stand("Portal", portal, PORTAL_AT, face=180, also=("PortalSheet",))
stand("Teleporter", teleporter, TELEPORTERS["worlds"], face=180, also=("TeleporterTrim",), tint=TELEPORTER_TINTS["worlds"])
stand("Lamp", lamp, LAMPS[0])

# ---- The fence: down both sides where the game's rails are, and along the back of the yard ----
group = "Dressing"
for side in (-1, 1):
    fence_run((side * FENCE_X, -YARD - 0.6), (side * FENCE_X, DEPTH - 0.65), 19)
fence_run((-FENCE_X, -YARD - 0.6), (FENCE_X, -YARD - 0.6), 13, first=False, last=False)

# ---- The hills: two rows down each side (the two sides are not mirror images) and a low row behind the
# yard, all outside the ground ----
group = "Backdrop"
NEAR = WIDTH / 2 + 0.6
SIDE_HILLS = {-1: ((-8, 11, 17, 9.5), (19, 13, 18, 12.5), (48, 12, 17, 10.5), (77, 14, 19, 13.5), (107, 12, 18, 11.5), (134, 13, 17, 14.0)),  # (z, across, along, height)
              1: ((-6, 12, 18, 10.5), (23, 12, 17, 11.5), (52, 14, 19, 13.0), (82, 12, 17, 10.5), (110, 13, 19, 13.5), (137, 12, 16, 12.5))}
FAR_HILLS = {-1: ((4, 12, 21, 16.0), (37, 13, 20, 14.5), (66, 12, 19, 18.5), (97, 13, 21, 15.5), (126, 12, 20, 19.0)),
             1: ((8, 13, 20, 15.0), (38, 12, 21, 18.0), (69, 13, 20, 15.0), (99, 12, 20, 19.0), (126, 13, 19, 16.5))}
for side in (-1, 1):
    for index, (z, across, along, height) in enumerate(FAR_HILLS[side]):
        hill(side * (NEAR + 9 + across), z, across, along, height, HILLS[2 + index % 2])
    for index, (z, across, along, height) in enumerate(SIDE_HILLS[side]):
        hill(side * (NEAR + across), z, across, along, height, HILLS[index % 2])
for index, (x, across, along, height) in enumerate(((-30, 18, 9, 11.0), (2, 18, 9, 9.5), (33, 18, 9, 11.5))):  # behind the yard, the far row
    hill(x, -YARD - 8.5 - along, across, along, height, HILLS[2 + index % 2])
for index, (x, across, along, height) in enumerate(((-46, 16, 9, 8.5), (-15, 17, 10, 9.5), (16, 16, 9, 8.5), (46, 17, 10, 10.0))):
    hill(x, -YARD - 1.4 - along, across, along, height, HILLS[index % 2])
for x, z, across, along, height, colour in ((-66, -25, 14, 12, 13.5, HILLS[2]), (67, -26, 14, 12, 14.5, HILLS[3]), (-67, 152, 14, 15, 15.0, HILLS[3]), (68, 151, 14, 16, 14.0, HILLS[2])):  # the corners
    hill(x, z, across, along, height, colour)

# ---- Behind the portal: the monsters' rock. A steep monolith with the world's sign on it, crags and
# buttes to both sides, everything from z = 150 on (where the game's skyline is solid). ----
BEHIND = DEPTH + 0.3
CRAGS = ((-11, 177, 14, 39, UNDER_DARK, peak), (13, 178, 13, 42, UNDER_DARK, peak), (-33, 172, 13, 30, UNDER, peak), (35, 173, 13, 33, UNDER, peak),  # (x, z, radius, height, colour, kind)
         (-21, 163, 12.5, 30, ROCK_DARK, butte), (22, 164, 12.5, 27, ROCK_DARK, butte), (-38, 161, 11, 24, ROCK, peak), (39, 162, 11, 20, ROCK, butte),
         (-53, 160, 9.5, 16.5, ROCK_LIGHT, butte), (54, 161, 9.5, 21, ROCK_LIGHT, peak))
SQUASH = 0.8  # a crag is this much less deep than it is wide
for x, z, radius, height, colour, kind in CRAGS:
    place(kind, (x, max(z, BEHIND + radius * SQUASH)), radius=radius, height=height, colour=colour, stretch=SQUASH)
# A waterfall down the butte to the right of the portal, into a pool at its foot (outside the ground).
place(waterfall, (22, 164), face=180, fall=[(5.2, 27.6), (6.5, 26.9), (7.3, 25.0), (8.0, 21.5), (9.3, 12.0), (10.2, 1.2), (10.75, 0.25)], pool=1.8, reach=11.1)
place(monolith, (0, BEHIND + 15 * 0.85), radius=15, height=45, colour=UNDER, stretch=0.85)
for x, z, size in ((-15.5, 153.8, 1.5), (14.6, 153.8, 1.1)):  # a boulder at its foot on each side of the portal
    place(rocks, (x, z), face=rng.uniform(0, 360), scale=size, colour=ROCK_LIGHT)
for x, z, radius, length, lean, colour in ((-13.0, 151.6, 0.9, 4.6, -0.3, HOT), (-14.6, 151.2, 0.6, 2.8, -0.6, EMBER), (13.4, 151.5, 0.95, 5.0, 0.3, HOT), (15.0, 151.1, 0.6, 3.0, 0.6, EMBER),
                                           (-11.9, 151.0, 0.5, 2.2, 0.1, HOT), (12.2, 150.9, 0.5, 2.4, -0.1, EMBER)):  # crystals beside the portal: they go to Glow
    tube(radius, length, at(x, z, 0), (lean, 0, 1), colour, tip=0.0, vertices=5, roughness=0.15, emission=0.8)
# The world's name: a flat, empty board where the game writes it (WORLD_SIGN), hung on two beams.
left, right, low, high = WORLD_SIGN
sign_x, sign_y, sign_wide, sign_tall = (left + right) / 2, (low + high) / 2, right - left + 1.2, high - low + 0.9
slab((sign_wide, 0.6, sign_tall), at(sign_x, DEPTH + 0.4, sign_y), BOARD)
for y in (-1, 1):
    box((sign_wide + 1.5, 1.0, 0.8), at(sign_x, DEPTH + 0.35, sign_y + y * (sign_tall / 2 + 0.4)), GOLD, bevel=0.2, segments=1, roughness=0.3)
for x in (-1, 1):
    box((0.8, 1.0, sign_tall + 1.6), at(sign_x + x * (sign_wide / 2 + 0.4), DEPTH + 0.35, sign_y), GOLD, bevel=0.2, segments=1, roughness=0.3)
    box((1.4, 9.0, 1.4), at(sign_x + x * 7.5, DEPTH + 4.6, sign_y + 1.5), WOOD_DARK, bevel=0.3, segments=1)
    star(1.0, at(sign_x + x * (sign_wide / 2 + 0.4), DEPTH - 0.25, sign_y + sign_tall / 2 + 0.4), GOLD, depth=0.3, rotation=(0, 0, math.pi), roughness=0.3)
# A windmill on the hills to the left, looking over the fence.
MILL = (-74, 61)
place(windmill, (*MILL, hill_top(*MILL) - 1.0), face=78, scale=1.15)

# ---- Trees on the hills ----
group = "BackdropTrees"
HILL_TREES = [(side * (NEAR + 9 + across + rng.uniform(-2, 2)), z + rng.uniform(-3, 3), rng.uniform(1.15, 1.45)) for side in (-1, 1) for z, across, along, height in FAR_HILLS[side]]
HILL_TREES += [(side * (NEAR + across + rng.uniform(1, 4)), z + rng.uniform(-4, 4), rng.uniform(0.85, 1.05)) for side in (-1, 1) for z, across, along, height in SIDE_HILLS[side][1::2]]
HILL_TREES += [(-66, -25, 1.3), (67, -26, 1.35), (-74, -14, 1.0), (76, -13, 1.05), (-67, 150, 1.3), (69, 150, 1.25), (-54, 163, 0.9), (40, 165, 0.8), (-22, 166, 0.85), (-76, 143, 0.95), (78, 141, 1.0),
               (-34, -35, 0.95), (47, -31, 0.9), (10, -36, 0.7)]  # the last three: on the hills behind the yard, where they hide nothing of the base from the hero photo
for index, (x, z, size) in enumerate(HILL_TREES):
    if math.hypot(x - MILL[0], z - MILL[1]) < 13:
        continue  # the mill's hill stays clear
    ground_here = hill_top(x, z)
    for bx, bz, radius, height, colour, kind in CRAGS:  # the buttes' caps
        if kind is butte and math.hypot(x - bx, z - bz) < radius * 0.5:
            ground_here = max(ground_here, height + 0.6)
    place(tree, (x, z, ground_here - 0.8), face=rng.uniform(0, 360), scale=size, leaf=LEAVES[index % 3], kind="tall" if index % 3 == 1 else "round", fine=False)

# ---- A few big trees inside, right against the side fences, clear of the road and of every pad ----
group = "Trees"
TREES = ((-49.5, 26, "round", 1.05, 0), (49.5, 27, "tall", 1.0, 1), (49.5, 55, "round", 1.1, 2), (-49.5, 82, "tall", 1.05, 1), (49.5, 110, "round", 1.0, 0), (-48.5, 141, "round", 1.1, 2), (48.5, 141, "tall", 1.0, 1))
for index, (x, z, kind, size, leaf) in enumerate(TREES):
    place(tree, (x, z), face=rng.uniform(0, 360), scale=size, leaf=LEAVES[leaf], kind=kind, fruit=RED if index in (2, 5) else None)

# ---- For the photos only: the shells on their other spots, towers, monsters, bulbs, beams, words ----
group = "Placeholders"
BUILT = {1: RED, 2: BLUE, 3: "FFC61A", 4: "B58CFF", 6: RED, 7: BLUE, 9: "FF8A1F", 11: "FFC61A", 12: "B58CFF"}  # pad -> its tower's colour
OWNED = (5, 8, 10)  # bought and still empty
for index, spot in enumerate(PADS, start=1):
    if index > 1:
        place(pad, spot, tint="FFC61A" if index in BUILT else "6EEB8C" if index in OWNED else "B0B4C0")
    if index in BUILT:
        # A tower looks at the nearest stretch of the path, as Plots.padFacing has it.
        best, nearest = (0, 1), 1e9
        for a, b in zip(PATH, PATH[1:]):
            a, b, here = Vector(a), Vector(b), Vector(spot)
            reach = a + (b - a) * max(0, min(1, (here - a).dot(b - a) / (b - a).dot(b - a))) - here
            if 0.01 < reach.length < nearest:
                best, nearest = reach, reach.length
        place(stand_in_tower, (*spot, PAD_HEIGHT), face=math.degrees(math.atan2(best[0], best[1])), colour=BUILT[index])
place(teleporter, TELEPORTERS["market"], face=180, tint=TELEPORTER_TINTS["market"])
for kind, spot in TELEPORTERS.items():
    tube(TELEPORTER_BEAM, 8.0, at(*spot, 0.4), UP, TELEPORTER_TINTS[kind], vertices=20, emission=1.0, alpha=0.3)
place(lamp, LAMPS[1])
for spot in LAMPS:
    ball(LAMP_BULB_SIZE / 2, at(*spot, LAMP_BULB), "FFD68C", emission=1.2)
# Monsters on the road, walking down it. (how far along the path, colour, eyes, size)
LENGTHS = [(Vector(b) - Vector(a)).length for a, b in zip(PATH, PATH[1:])]
for far, colour, eye, size in ((9, "5FD35A", "FFE23A", 1.5), (34, "8FD93E", "FFE23A", 1.5), (47, "FF8A3D", "FFE23A", 1.5), (70, "5FD35A", "FFE23A", 1.5), (88, "E8F4FF", "45C8FF", 1.5), (112, "8FD93E", "FFE23A", 1.5),
                               (131, "6FB2E8", "FFE23A", 3.3), (160, "FF8A3D", "FFE23A", 1.5), (178, "5FD35A", "FFE23A", 1.5), (205, "E8F4FF", "45C8FF", 1.5), (232, "8FD93E", "FFE23A", 1.5), (262, "5FD35A", "FFE23A", 1.5),
                               (283, "FF8A3D", "FFE23A", 1.5)):
    for (a, b), length in zip(zip(PATH, PATH[1:]), LENGTHS):
        if far <= length:
            a, b = Vector(a), Vector(b)
            point, way = a + (b - a) * far / length, (b - a).normalized()
            place(stand_in_monster, (point.x + rng.uniform(-1.6, 1.6), point.y, ROAD_TOP), face=math.degrees(math.atan2(way.x, way.y)), scale=size, colour=colour, eye=eye)
            break
        far -= length
words("YAANI'S BASE", (0, GATE_Z - NAME_SIGN[2] / 2 - 0.02, NAME_SIGN_Y), 1.5, face=180)
words("YAANI'S BASE", (0, GATE_Z + NAME_SIGN[2] / 2 + 0.02, NAME_SIGN_Y), 1.5, face=0)
words("EARTH", (sign_x, DEPTH - 0.02, sign_y), 5.4, face=180)

group = "Sky"
for x, z, y, size in ((-150, 60, -40, 11), (160, 90, -34, 10), (-140, 200, -55, 8), (150, 220, -60, 9), (-60, -80, -70, 10), (70, -90, -75, 9),  # around and under the island
                      (-140, 330, 85, 15), (120, 350, 100, 16), (-10, 420, 140, 17), (230, 300, 60, 12), (-250, 280, 55, 12), (40, 300, 60, 9)):  # the sky seen from the yard
    place(cloud, (x, z, y), face=180 + rng.uniform(-25, 25), scale=size)

bpy.context.view_layer.update()
triangles = {}
for name, pieces in groups.items():
    triangles[name] = 0
    for obj in pieces:
        obj.data.calc_loop_triangles()
        triangles[name] += len(obj.data.loop_triangles)
    print(f"GROUP {'RenderOnly_' if name in RENDER_ONLY else 'Base_'}{name} pieces {len(pieces)} triangles {triangles[name]}")
print(f"EXPORT triangles {sum(count for name, count in triangles.items() if name not in RENDER_ONLY)}")

# ---------------------------------------------------------------------------------------------------
# The photos: the island's sky and light
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
SKY = ((0.0, "E8F6FF"), (0.15, "CDEBFF"), (0.36, "6DB6F5"), (0.47, "8FCBFA"), (0.5, "C4E8FF"), (0.62, "8CCBFB"), (0.8, "5AA7EE"), (1.0, "3F8FE0"))  # straight down ... the horizon at 0.5 ... straight up
stops = ramp.color_ramp.elements
for index, (position, colour) in enumerate(SKY):
    stop = stops[index] if index < 2 else stops.new(position)
    stop.position = position
    stop.color = (*linear(colour), 1)
nodes["Background"].inputs["Strength"].default_value = 0.85
scene.world = world


def aim(obj, eye, target):
    obj.location = eye
    obj.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()


def from_sky(degrees, height, distance):
    """A point `distance` away in a direction of plot space (0 up the plot, 90 towards +x, 180 behind the
    yard) and `height` degrees above the ground."""
    reach = distance * math.cos(math.radians(height))
    return Vector((math.sin(math.radians(degrees)) * reach, -math.cos(math.radians(degrees)) * reach, distance * math.sin(math.radians(height))))


sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 2.7
sun_data.angle = math.radians(6)
sun_data.color = (1.0, 0.96, 0.88)
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
# A weak second light from below and in front, without shadows: what sky and clouds throw back up.
bounce_data = bpy.data.lights.new("Bounce", "SUN")
bounce_data.energy = 0.8
bounce_data.color = (1.0, 0.93, 0.85)
bounce_data.use_shadow = False
bounce_data.specular_factor = 0.0
bounce = bpy.data.objects.new("Bounce", bounce_data)
scene.collection.objects.link(bounce)

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


def photo(name, eye, target, lens, light=(215, 50)):
    """A photo from `eye` at `target`, both points of Blender's space (use at). `light` is where the sun
    stands: its direction (like from_sky) and its height."""
    if ONLY and name not in ONLY:
        return
    camera_data.type, camera_data.lens = "PERSP", lens
    aim(camera, eye, target)
    aim(sun, from_sky(light[0], light[1], 100), (0, 0, 0))
    aim(bounce, from_sky(light[0] - 40, -60, 100), (0, 0, 0))
    scene.render.filepath = f"{OUT}/earth_base_{name}.png"
    bpy.ops.render.render(write_still=True)


# Straight down on the plot, the portal to the left and the yard to the right: the layout, to lay over the code's.
if not ONLY or "top" in ONLY:
    camera_data.type, camera_data.ortho_scale = "ORTHO", 300
    camera.location, camera.rotation_euler = at(0, MIDDLE_Z, 400), (0, 0, math.pi / 2)
    aim(sun, from_sky(215, 55, 100), (0, 0, 0))
    aim(bounce, from_sky(175, -60, 100), (0, 0, 0))
    scene.render.filepath = f"{OUT}/earth_base_top.png"
    bpy.ops.render.render(write_still=True)
# The portal, from the road in front of it.
photo("portal", at(12, 106, 7.5), at(2, 150, 14.5), 22, light=(205, 48))
# The base as the monsters see it when they come out of the portal.
photo("road", at(0, 132, 9.0), at(0, 14, 6.0), 26, light=(-30, 48))
# The gate from close by, from the road.
photo("gate", at(-11, 47, 7.0), at(0, 14, 10.5), 24, light=(-35, 46))
# A player's eyes in the yard behind the gate, looking up the road to the portal.
photo("ground", at(0, -14.5, 6.2), at(0, 40, 10.5), 17)
# The same eyes out in the field: the road, the pads and the horizon the hills make.
photo("field", at(6, 30, 6.0), at(-50, 92, 7.0), 20)
# For checking only, when asked for by name (photos=pad,passage ...): close looks at the small things.
CHECKS = {"pad": (at(-15, 41, 5.5), at(-23, 53, 0.3), 35), "passage": (at(5, 3, 13.0), at(0, 15, 0.0), 22), "lamp": (at(-38, -4, 7.0), at(-49, -11, 7.5), 28),
          "back": (at(0, 9, 6.2), at(8, -30, 5.0), 18), "right": (at(-10, 96, 6.0), at(50, 130, 9.0), 20), "teleporter": (at(-4, -6, 6.5), at(-13, 3, 4.5), 26)}
for name in ONLY:
    if name in CHECKS:
        photo(name, *CHECKS[name])
# Three-quarters from above, from behind the yard. Last, so the saved file opens on this view.
HERO_TARGET = at(0, 68, -34)
photo("hero", HERO_TARGET + from_sky(156, 32, 520), HERO_TARGET, 48)

# ---------------------------------------------------------------------------------------------------
# For Roblox: one mesh per group, colours on the vertices (white on a trim), none with over 10,000
# triangles. The scenery keeps the plot's origin, so dropped at the same spot it all lines up. A shell is
# exported around its own base, front towards -Y; in the saved file it stands on its spot of the plot.
# ---------------------------------------------------------------------------------------------------
def beside_path(x, z):
    """How far a point of plot space is from the middle of the road (which starts PORTAL_DEPTH behind the path's first point)."""
    line = [Vector(PORTAL_AT)] + [Vector(point) for point in PATH[1:]]
    here = Vector((x, z))
    return min((here - (a + (b - a) * max(0.0, min(1.0, (here - a).dot(b - a) / (b - a).dot(b - a))))).length for a, b in zip(line, line[1:]))


def export():
    exported, report, bounds = [], [], {}
    for name, pieces in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in pieces:
            colour = (1.0, 1.0, 1.0) if name in TRIMS else obj.data.materials[0].diffuse_color
            attribute = obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
            attribute.data.foreach_set("color", [colour[0], colour[1], colour[2], 1.0] * len(obj.data.loops))
            obj.select_set(True)
        bpy.context.view_layer.objects.active = pieces[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = joined.data.name = ("RenderOnly_" if name in RENDER_ONLY else "Base_") + name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if name in shells:
            joined.data.transform(shells[name].inverted())
            joined.matrix_basis = shells[name]
        if name in RENDER_ONLY:
            continue
        exported.append(joined)
        low = Vector([min(vertex.co[axis] for vertex in joined.data.vertices) for axis in range(3)])
        high = Vector([max(vertex.co[axis] for vertex in joined.data.vertices) for axis in range(3)])
        bounds[name] = (low, high)
        report.append({
            "name": joined.name,
            "kind": "shell" if name in shells else "scenery",
            "origin": "the middle of its own base on the ground, front towards Blender -Y" if name in shells else "the plot's origin, on the ground",
            "triangles": triangles[name],
            "centre": [round(value, 2) for value in (low + high) / 2],
            "size": [round(value, 2) for value in high - low],
            "material": "Neon" if name in ("Glow", "PortalSheet") else "Glass" if name == "Water" else "SmoothPlastic",
            "white_for_tinting": name in TRIMS,
        })

    bpy.ops.object.select_all(action="DESELECT")
    for obj in exported:
        obj.select_set(True)
    for name in shells:
        bpy.data.objects["Base_" + name].matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.fbx(filepath=f"{OUT}/earth_base.fbx", use_selection=True, apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", colors_type="SRGB")
    for name, frame in shells.items():
        bpy.data.objects["Base_" + name].matrix_basis = frame
    bpy.context.preferences.filepaths.save_version = 0  # no .blend1 beside it
    bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/earth_base.blend")

    # The layout, measured back off the meshes: what the game's own numbers say they should be.
    road = [vertex.co for vertex in bpy.data.objects["Base_Road"].data.vertices if -vertex.co.y > GATE_Z + 0.01 or (-vertex.co.y > GATE_Z - 0.01 and abs(vertex.co.x) < PATH_WIDTH)]  # without the plaza
    surface = [co for co in road if abs(co.z - ROAD_TOP) < 0.001]
    pad_low, pad_high = bounds["Pad"]
    checks = {
        "road_top": [round(min(co.z for co in surface), 3), round(max(co.z for co in surface), 3)],
        "road_half_width": round(max(beside_path(co.x, -co.y) for co in surface), 3),
        "road_with_kerb_half_width": round(max(beside_path(co.x, -co.y) for co in road), 3),
        "road_from_z_to_z": [round(max(-co.y for co in road), 3), round(min(-co.y for co in road), 3)],
        "kerb_top": round(max(co.z for co in road), 3),
        "pad_size": [round(value, 3) for value in pad_high - pad_low],
        "ground_top": round(max(vertex.co.z for vertex in bpy.data.objects["Base_Ground"].data.vertices if abs(vertex.co.x) < 60 and -160 < vertex.co.y < 20), 3),
        "biggest_mesh": max(entry["triangles"] for entry in report),
    }
    total = sum(entry["triangles"] for entry in report)
    print("CHECKS", checks)
    print(f"EXPORTED {len(report)} meshes, {total} triangles")

    def box_of(what, x, z, size, yaw=0.0, optional=False):
        return {"what": what, "shape": "box", "centre": [round(x, 2), round(size[1] / 2, 2), round(z, 2)], "size": [round(value, 2) for value in size], "yaw": yaw, "optional": optional}

    def pillar_of(what, x, z, radius, height):
        return {"what": what, "shape": "pillar", "centre": [round(x, 2), round(height / 2, 2), round(z, 2)], "radius": round(radius, 2), "height": round(height, 2)}

    colliders = [pillar_of("tree", x, z, 1.1 * size, 7.0 * size) for x, z, kind, size, leaf in TREES]
    colliders += [pillar_of("lamp", x, z, 0.6, 11.0) for x, z in LAMPS]
    colliders += [box_of("teleporter leg", x + side * 3.9, z, (2.1, 7.6, 2.1)) for x, z in TELEPORTERS.values() for side in (-1, 1)]
    colliders += [box_of("portal leg", PORTAL_AT[0] + side * 9.45, PORTAL_AT[1], (4.8, 10.0, 5.0)) for side in (-1, 1)]
    colliders += [box_of("gate pier (the edge of the arch; the tower behind it is the game's own)", side * (GATE_WIDTH / 2 + 0.875), GATE_Z, (1.75, 14.0, 3.6)) for side in (-1, 1)]
    for side in (-1, 1):  # the door's leaves, 7 long, swung 10 degrees past straight
        way = Vector((side * math.sin(math.radians(10)), math.cos(math.radians(10))))  # along the leaf, in plot space (x, z)
        hinge = Vector((side * (GATE_WIDTH / 2 + 0.3), GATE_Z + 1.9))
        middle = hinge + way * 3.5
        colliders.append(box_of("gate door leaf", middle.x, middle.y, (0.6, 12.0, 7.0), yaw=side * 10.0))
    colliders += [box_of("wall post (the wall under it is the game's own, solid to 4.5)", side * x, GATE_Z, (2.8, 5.9, 3.0), optional=True) for side in (-1, 1) for x in (18.6, 27.6, 36.6, 45.6, 53.9)]

    wide, tall, apart = NAME_SIGN
    left, right, low, high = WORLD_SIGN
    manifest = {
        "what": "The Earth base (world 1): scenery and shells for src/server/Plots.luau to wear over the base it builds from parts, as Islands.wear does for the island. Made by tools/blender/earth_base.py.",
        "units": "1 Blender unit = 1 stud",
        "mapping": {
            "plot_space": "Layout.luau: the origin is the middle of the base's edge of the ground, x across the plot, +z up the plot to the portal, y up, the ground's top at y = 0, the yard behind the origin (-z)",
            "blender_to_plot": "plot (x, y, z) = Blender (x, z, -y)",
            "plot_to_blender": "Blender (x, y, z) = plot (x, -z, y)",
            "scenery_in_roblox": "an FBX lands as Roblox (-x, z, y) of Blender's (x, y, z), half a circle off, exactly as the Earth island's did: give the scenery model the plot's origin as its pivot, turned half a circle about Y, and Model:PivotTo(plot.frame) puts every scenery mesh in place",
            "shell_in_roblox": "a shell's pivot is the middle of its base on the ground and its front (Blender -Y) is its -Z, like the island's shells: shell:PivotTo(plot.frame * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)) with yaw = face + 180",
            "face": "where a shell's front looks, in plot space: 0 = up the plot (+z), 90 = towards +x, 180 = back at the yard (-z)",
            "colliders": "centre is (x, y, z) in plot space; a box's size is (x, y, z) in its own frame, turned by CFrame.Angles(0, math.rad(yaw), 0); a pillar stands upright",
        },
        "layout_copied_from_the_code": {
            "ground": {"x": [-WIDTH / 2, WIDTH / 2], "z": [-YARD, DEPTH], "top": 0},
            "path": [list(point) for point in PATH], "path_width": PATH_WIDTH, "kerb": KERB, "road_top": ROAD_TOP, "road_starts_at_z": PORTAL_AT[1],
            "pads": [list(point) for point in PADS], "pad_size": PAD_SIZE, "pad_height": PAD_HEIGHT,
            "gate": {"at": [0, GATE_Z], "opening": [GATE_WIDTH, GATE_HEIGHT], "towers_x": [-TOWER_X, TOWER_X], "tower_radius": TOWER_RADIUS, "tower_top": TOWER_TOP,
                     "walls_x": [WALL_FROM, WIDTH / 2], "wall_height": WALL_HEIGHT, "wall_thickness": WALL_THICK},
            "plaza": {"x": [-PLAZA_WIDTH / 2, PLAZA_WIDTH / 2], "z": [0, GATE_Z], "top": PLAZA_TOP}, "arrival_pad": {"at": list(ARRIVAL), "radius": ARRIVAL_RADIUS, "top": ARRIVAL_TOP},
            "portal": {"at": list(PORTAL_AT), "sheet": [GATE_WIDTH, GATE_HEIGHT + 1]},
            "teleporters": {kind: list(spot) for kind, spot in TELEPORTERS.items()}, "lamps": [list(spot) for spot in LAMPS],
            "fence_x": [-FENCE_X, FENCE_X], "fence_rails_y": list(FENCE_RAILS), "skyline_from": {"x": WIDTH / 2, "z_behind_the_yard": -YARD, "z_behind_the_portal": DEPTH},
        },
        "meshes": report,
        "total_triangles": total,
        "shells": {
            "Pad": {
                "meshes": ["Base_Pad", "Base_PadTrim"], "spots": [list(point) for point in PADS], "y": 0, "face": 0, "yaw": 180, "note": "the same from all four sides: any quarter turn will do",
                "footprint": [PAD_SIZE, PAD_SIZE], "highest": PAD_HEIGHT, "plate_top": PAD_HEIGHT - 0.04,
                "heights": "the gold corners are PAD_HEIGHT (0.5) high, the plate 0.46: the game's pad stays as the solid floor and the carrier of the prompt and the '+', and its top (0.5, where a tower stands) is 0.04 over the plate",
                "trim": "Base_PadTrim is the band round the plate, for the pad's state. In the photos: for sale B0B4C0, the owner's and empty 6EEB8C, built on FFC61A",
            },
            "Gate": {
                "meshes": ["Base_Gate", "Base_GateTrim"], "spots": [[0, GATE_Z]], "y": 0, "face": 0, "yaw": 180, "note": "its front is the side the monsters see; the yard's side looks the same",
                "heights": {"arch": "round, 14 wide; 14 high in the middle, springing 7 up (the game's see-through Gate part, 14 x 14, fits behind it: its top corners are inside the stone)",
                            "portcullis_tips": 10.1, "name_board": [14.05, 17.15], "gatehouse_top": 19.2, "crest_top": 24.1, "tower_parapet": 17.7, "tower_battlements": 18.9, "roof_tip": 26.2, "flag_top": 30.6,
                            "wall_top": WALL_HEIGHT, "wall_battlements": 5.37, "wall_posts": 5.9, "wall_post_knobs": 7.0, "arrival_ring": 0.28, "arrival_disc": 0.2},
                "trim": "Base_GateTrim is everything in the owner's colour (plot.colored): the two roofs, the two flags, the four banners, the crest's shield and the disc of the arrival pad (at plot 0, 4; its top is 0.2, under the game's own disc at 0.25). In the photos FF6161, slot 1's colour",
            },
            "Portal": {
                "meshes": ["Base_Portal", "Base_PortalSheet"], "spots": [list(PORTAL_AT)], "y": 0, "face": 180, "yaw": 0, "note": "its front looks down the road at the gate; its back is plain (the rock is 3 studs behind it)",
                "heights": {"mouth": "14.5 wide between the legs; 16.2 high in the middle, springing 9.3 up", "sheet_top": 16.6, "top_of_the_arch": 20.8, "crest": 22.7, "horn_tips": 25.6},
                "sheet": "Base_PortalSheet (for Neon; the game may fade or dim it as it does its own Portal part) is the sheet with its dark whirl, the two eyes, the runes on the legs and the gem on the brow. Hot pink (FF3D7F), not the island's purple",
            },
            "Teleporter": {
                "meshes": ["Base_Teleporter", "Base_TeleporterTrim"], "spots": [list(TELEPORTERS["worlds"]), list(TELEPORTERS["market"])], "y": 0, "face": 180, "yaw": 0, "note": "the same from the front and the back",
                "heights": {"dais_top": 0.42, "trim_on_the_dais": 0.47, "orb": TELEPORTER_ORB, "highest": 11.25, "inside_the_arch": "6.2 wide between the legs, 9.15 high in the middle: the game's beam (1.7 in radius, 0.4 to 8.4 up) stands in it"},
                "trim": "Base_TeleporterTrim is the ring and the disc on the dais, the orb in the crown (where the game's own orb floats) and a gem on each leg. Tint it by destination: worlds 46DC8C (70, 220, 140), market 8264FF (130, 100, 255)",
                "titles": "the game's titles are billboards (15 x 3.8, their middle 13.3 up): no face to keep. Nothing of the shell is higher than 11.25, the titles' lower edge is 11.4",
            },
            "Lamp": {
                "meshes": ["Base_Lamp"], "spots": [list(spot) for spot in LAMPS], "y": 0, "face": 0, "yaw": 180, "note": "the same from all sides",
                "heights": {"bulb": LAMP_BULB, "cage": [10.85, 13.1], "top": 14.9},
                "bulb": "the shell has no bulb: the game's own Lamp ball (2.2 across, its middle 12 up) hangs in the cage and keeps its light and its Halloween colour",
            },
        },
        "signs": [
            {"what": "the owner's name, yard side (NameSign, Front)", "written_at_z": GATE_Z - apart / 2, "x": [-wide / 2, wide / 2], "y": [NAME_SIGN_Y - tall / 2, NAME_SIGN_Y + tall / 2],
             "board": "Base_Gate: flat and empty, dark (3A3560), at z = 12.35, x -6.55 ... 6.55, y 14.05 ... 17.15; in the shell's own space y = 1.65"},
            {"what": "the owner's name, road side (NameSign, Back)", "written_at_z": GATE_Z + apart / 2, "x": [-wide / 2, wide / 2], "y": [NAME_SIGN_Y - tall / 2, NAME_SIGN_Y + tall / 2],
             "board": "Base_Gate: flat and empty, dark, at z = 15.65, x -6.55 ... 6.55, y 14.05 ... 17.15; in the shell's own space y = -1.65"},
            {"what": "the world's name (the middle slab of the skyline, Front)", "written_at_z": DEPTH, "x": [left, right], "y": [low, high],
             "board": "Base_Backdrop: flat and empty, dark, at z = 150.1, x -10.5 ... 10.5, y 24.31 ... 32.01"},
            {"what": "the '+' on an empty pad (the pad's Top)", "written_at_y": PAD_HEIGHT, "board": "Base_Pad: the plate, flat and empty at y = 0.46, 6.16 square but for the gold corners (1.5 square each)"},
        ],
        "game_parts": {
            "stay_seen": ["Lamp (the bulb)", "WorldsPortal and MarketPortal (the teleporters' see-through beams)", "Gate (the see-through sheet in the arch, if wanted)", "the pads' FOR SALE signs, the towers"],
            "unseen_but_kept": "everything else in Scenery and the Decor folder (the ten world props: the base brings its own trees): Ground, Yard, Kerb, Road, Backdrop, Surround, FencePost, FenceRail, Plaza, ArrivalPad, GateTower, Battlement, Roof, FlagPole, Flag, Wall, GateBeam, Merlon, NameSign, LampFoot, LampPost, PortalPillar, PortalBeam, PortalHorn, Portal, WorldsRing, MarketRing, WorldsOrb, MarketOrb, Pad_1 ... Pad_16. The signs on NameSign, Backdrop and the pads stay on",
        },
        "colliders": colliders,
        "checks_measured_off_the_meshes": checks,
        "not_as_the_code": [
            "The road runs round the outside of each of its eight bends in an arc (radius 4, with the kerb 4.8): inside the square corner the game's slabs make, never outside it.",
            "The kerb is 0.8 wide as in the code but 0.42 high (the code's is a flat band at 0.1, lower than the road's 0.2).",
            "The gate's arch is round: 14 wide and 14 high in the middle like the code's opening, lower towards its sides. A portcullis hangs in its top (tips 10.1 up) and its door stands open to the road: two leaves beside the way, x = +-7.3 ... +-8.5, z = 15.9 ... 22.8 (see colliders).",
            "The towers are 3.6 in radius (the code's solid 3.5), their feet 4.0. The walls' posts are 2.8 x 3.0 (the solid wall is 2 thick) and stand 1.4 over its top.",
            "The plaza keeps the code's 40 x 14 but has round corners (radius 3) to the yard. Like the code's ring, a teleporter's dais (3.6 in radius) reaches 0.6 past the plaza's edge.",
            "The fence has 19 posts a side (the code 10; every other one of mine stands on one of the code's) and runs on along the back of the yard at z = -16.6, just outside the ground, where the code has only its hills.",
            "The code's ten world props (PROP_SPOTS) are not used: seven trees stand inside, against the side fences (see colliders); the rest of the trees are outside the ground.",
            "The portal's glow is hot pink instead of the code's Earth glow (130, 100, 255), so it is not the island's purple portal.",
        ],
    }
    with open(f"{OUT}/earth_base_manifest.json", "w") as file:
        json.dump(manifest, file, indent=1)


if not NOFILES:
    export()
