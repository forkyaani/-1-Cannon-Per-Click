"""The shared modelling kit of the Blender scripts (island.py, base.py, creatures.py ...): flat-coloured
chunky pieces made with bmesh, collected in groups, photographed, and exported as one mesh per group with
its colours on the vertices.

    import os, sys
    sys.path.insert(0, os.path.dirname(__file__))
    import kit
    from kit import *            # the names in __all__: primitives, colours, groups, place/stand, photo, export

    OUT, FLAGS = kit.args()      # blender --background --python x.py -- <output folder> [draft] [...]
    kit.init(seed=7, prefix="Earth_", scenery=("Island", "Glow", "Water"), render_only=("Backdrop",))
    kit.use("Island")            # the group the next pieces go to
    box((2, 2, 2), (0, 0, 1), "FF4D4D")
    kit.count()                  # prints the triangles per group
    kit.studio(OUT, draft="draft" in FLAGS)
    photo("hero", (0, -40, 20), (0, 0, 0), 45)
    kit.export(f"{OUT}/earth_island.fbx")    # and earth_island.blend beside it

Importing this file does nothing to Blender. `init()` empties the scene and every table below; nothing
else may be called before it.

What a caller must know
  * Space: 1 unit is 1 stud, z is up, a prop is built around its own origin, standing on z = 0, its front
    towards -Y. Directions are degrees like the game's: 0 is north (+Y), 90 east (+X). See `ring`.
  * Colours are hex strings ("FF4D4D"). Every piece is one flat colour; `**look` on any primitive is
    `roughness`, `emission`, `alpha` (see `mat`), and for `finish` also `smooth` and `tidy`.
  * Groups: a piece goes to the current group (`use`, `into`, `current`). A piece with `emission` made while
    the current group is one of `scenery` goes to the group "Glow" instead, so Roblox can make that mesh
    Neon; a shell (a group that is not scenery) keeps its glowing bits.
  * `groups` (name -> pieces), `made` (every piece in order), `shells` (group -> frame), `materials` and
    `rng` are the same objects for the whole run: `init` empties and reseeds them, it never replaces them,
    so `from kit import *` before `init()` is safe. The current group is not a name to import: ask
    `current()`, set it with `use()`.
  * `rng` is the one random generator; `chunk` and `lathe(rough=...)` draw from it, so the order pieces are
    made in decides their shape. Use it for a script's own randomness too, never `random` itself.
  * `place` stands a prop on `kit.ground(x, y)` when its spot has no z. Give the kit the script's ground
    with `set_ground(function)`; it is flat (0) until then.
  * `export` names each mesh prefix + group ("Earth_Trees"), or "RenderOnly_" + group for the groups that
    are only in the photos; those are not in the FBX. A shell is exported around its own base and stands
    on its spot in the saved .blend. It warns (it does not stop) about a mesh over `max_tris`.
"""
import math
import os
import random
import sys
from contextlib import contextmanager

import bmesh
import bpy
from mathutils import Matrix, Vector

__all__ = [
    "UP", "linear", "shade", "mat",
    "groups", "made", "shells", "materials", "rng", "use", "into", "current",
    "finish", "box", "slab", "ball", "tube", "mesh", "hoop", "chunk", "ring", "lathe", "dome", "star", "rosette", "ribbon", "cloud",
    "place", "stand", "aim", "from_sky", "photo",
]

UP = (0, 0, 1)
SHARP = math.radians(50)  # edges bent more than this stay crisp (the rim of a disc, the sides of a crystal)
EARTH_SKY = ((0.0, "E8F6FF"), (0.15, "CDEBFF"), (0.36, "6DB6F5"), (0.47, "8FCBFA"), (0.5, "C4E8FF"), (0.62, "8CCBFB"), (0.8, "5AA7EE"), (1.0, "3F8FE0"))  # straight down ... the horizon at 0.5 ... straight up

materials = {}  # (colour, roughness, emission, alpha) -> material
groups = {}  # name -> pieces
shells = {}  # a shell's group -> the frame it stands at
made = []  # every piece, in the order it was made
rng = random.Random(0)  # reseeded by init: the same "random" model every run

_group = "Main"  # the group being built
_scenery = ()  # the groups whose glowing pieces go to "Glow"
_render_only = ()  # the groups that are in the photos and not in the export
_prefix = ""  # before every exported mesh's name
_out = "."  # where photo() writes
ground = lambda x, y: 0.0  # the height a prop is placed at; see set_ground
camera = sun = bounce = None  # the objects studio() makes, for a script that aims them itself


def args():
    """What follows `--` on Blender's command line, as (output folder, the rest): `OUT, FLAGS = kit.args()`.
    The folder is "." when nothing was given."""
    given = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return (given[0] if given else "."), given[1:]


def init(seed=0, prefix="", scenery=(), render_only=()):
    """Starts a model: an empty scene, empty tables, `rng` seeded. `prefix` goes before every exported
    mesh's name, `scenery` lists the groups whose glowing pieces move to "Glow", `render_only` the groups
    that are only for the photos. Returns `rng`."""
    global _group, _scenery, _render_only, _prefix, ground, camera, sun, bounce
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for table in (materials, groups, shells):
        table.clear()
    made.clear()
    rng.seed(seed)
    _group, _scenery, _render_only, _prefix = "Main", tuple(scenery), tuple(render_only), prefix
    ground = lambda x, y: 0.0
    camera = sun = bounce = None
    return rng


def set_ground(height):
    """Tells `place` how high the ground is: a function of (x, y)."""
    global ground
    ground = height


# ---------------------------------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------------------------------
def linear(hex_code):
    """A hex colour as Blender's linear (r, g, b)."""
    hex_code = hex_code.lstrip("#")
    return tuple(((int(hex_code[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4))


def shade(hex_code, amount):
    """Darker (amount < 0) or lighter (amount > 0) version of a colour."""
    hex_code = hex_code.lstrip("#")
    target = 255 if amount > 0 else 0
    return "".join("%02X" % round(int(hex_code[i:i + 2], 16) + (target - int(hex_code[i:i + 2], 16)) * abs(amount)) for i in (0, 2, 4))


def mat(hex_code, roughness=0.6, emission=0.0, alpha=1.0):
    """The material of a colour. `alpha` shows in the photos only: the export carries colours, nothing else."""
    key = (hex_code, roughness, emission, alpha)
    if key not in materials:
        m = bpy.data.materials.new(hex_code)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        colour = linear(hex_code)
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
        bsdf.inputs["Roughness"].default_value = roughness
        if alpha != 1.0:
            bsdf.inputs["Alpha"].default_value = alpha
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*colour, 1)
            bsdf.inputs["Emission Strength"].default_value = emission
        m.diffuse_color = (*colour, 1)
        materials[key] = m
    return materials[key]


# ---------------------------------------------------------------------------------------------------
# Groups. Pieces are collected per group: a group becomes one mesh.
# ---------------------------------------------------------------------------------------------------
def current():
    """The group being built."""
    return _group


def use(name):
    """From here on the pieces go to this group. Returns the group it was, to go back to."""
    global _group
    home, _group = _group, name
    return home


@contextmanager
def into(name):
    """`with into("PortalSheet"):` builds what is inside it into another group, then goes back."""
    home = use(name)
    try:
        yield
    finally:
        use(home)


# ---------------------------------------------------------------------------------------------------
# Primitives. Each returns the piece (an object) it made.
# ---------------------------------------------------------------------------------------------------
def finish(work, colour, location=(0, 0, 0), rotation=(0, 0, 0), smooth=True, tidy=False, **look):
    """Turns the bmesh being worked on into a piece of the current group. `tidy` makes every face of a
    hand-made closed shape look outwards."""
    if tidy:
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
    bpy.context.scene.collection.objects.link(obj)
    groups.setdefault("Glow" if look.get("emission") and _group in _scenery else _group, []).append(obj)
    made.append(obj)
    return obj


def box(size, location, colour, bevel=0.3, rotation=(0, 0, 0), segments=2, **look):
    """A block with rounded edges, `location` its middle."""
    work = bmesh.new()
    bmesh.ops.create_cube(work, size=1.0)
    bmesh.ops.scale(work, vec=size, verts=work.verts)
    bmesh.ops.bevel(work, geom=work.edges[:], offset=min(bevel, min(size) * 0.49), offset_type="OFFSET", segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)
    return finish(work, colour, location, rotation, **look)


def slab(size, location, colour, rotation=(0, 0, 0), **look):
    """A plain block with crisp edges: twelve triangles, for rails, bricks, bars and far things."""
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
    """A hand-made shape: corners, and faces as lists of corner numbers."""
    work = bmesh.new()
    corners = [work.verts.new(vertex) for vertex in vertices]
    for face in faces:
        work.faces.new([corners[index] for index in face])
    return finish(work, colour, location, rotation, **look)


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
    """A low-poly rock: a faceted ball with its corners pushed in and out (by `rng`)."""
    work = bmesh.new()
    bmesh.ops.create_icosphere(work, subdivisions=detail, radius=1.0)
    for vertex in work.verts:
        push = 1 + rng.uniform(-0.16, 0.16)
        vertex.co = (vertex.co.x * size[0] * push, vertex.co.y * size[1] * push, vertex.co.z * size[2] * push)
    return finish(work, colour, location, (0, 0, rng.uniform(0, 6.28)), smooth=False, **look)


def ring(degrees, radius):
    """A point (x, y) on a circle around the middle, like the game's: 0 degrees is north, 90 is east."""
    angle = math.radians(degrees)
    return math.sin(angle) * radius, math.cos(angle) * radius


def lathe(rings, colour, segments=48, shape=None, rough=0.0, stretch=1.0, **look):
    """A solid of rings stacked around the Z axis. Each ring is (radius, z), and either may be a function of
    the angle in degrees; a radius of 0 is a single point (a tip, or the middle of a flat end). `shape`
    multiplies every radius by a function of the angle, `rough` shakes every corner by up to that much,
    `stretch` squeezes it along Y.
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
    """A low rounded cap, open underneath, to lie on something: a patch of lawn, a spot on an egg, moss.
    Its rim goes `sink` under `location` (a quarter of its radius if not given, to hug a round shape)."""
    sink = radius * 0.25 if sink is None else sink
    return lathe([(0, height), (radius * 0.62, height * 0.62), (radius, -sink)], colour, segments=segments, stretch=stretch, location=location, rotation=rotation, **look)


def star(radius, location, colour, depth=0.35, rotation=(0, 0, 0), **look):
    """A chunky five-pointed star standing upright, its face to the front (-Y)."""
    rim = [ring(index * 36, radius if index % 2 == 0 else radius * 0.5) for index in range(10)]
    vertices = [(x, 0, z) for x, z in rim] + [(0, -depth, 0), (0, depth, 0)]
    faces = [(10, (index + 1) % 10, index) for index in range(10)] + [(11, index, (index + 1) % 10) for index in range(10)]
    return mesh(vertices, faces, colour, location, rotation, smooth=False, tidy=True, **look)


def rosette(radius, location, colour):
    """Five round petals in one flat piece, face up: a flower's head."""
    rim = [ring(index * 18, radius * (0.55 + 0.45 * abs(math.cos(math.radians(index * 45))))) for index in range(20)]
    vertices = [(x, y, 0) for x, y in rim] + [(0, 0, radius * 0.22), (0, 0, -radius * 0.14)]
    faces = [(20, (index + 1) % 20, index) for index in range(20)] + [(21, index, (index + 1) % 20) for index in range(20)]
    return mesh(vertices, faces, colour, location, tidy=True)


def ribbon(profile, width, colour, thickness=0.6, shift=0.0, lift=0.0, **look):
    """A band that runs out of a prop's front along a path of (forward, height) points: a stream and its
    waterfall, a flow of lava. Its top is `lift` off the path, its middle `shift` to the side."""
    vertices, faces = [], []
    for index, (forward, height) in enumerate(profile):
        before, after = profile[max(index - 1, 0)], profile[min(index + 1, len(profile) - 1)]
        along = Vector((after[0] - before[0], after[1] - before[1])).normalized()
        out = Vector((-along.y, along.x))  # the side of the band that faces up, or away once it falls
        for side, sink in ((-0.5, thickness), (-0.3, 0), (0.3, 0), (0.5, thickness)):
            vertices.append((shift + side * width, -(forward + out.x * (lift - sink)), height + out.y * (lift - sink)))
        if index:
            a, b = (index - 1) * 4, index * 4
            faces += [(a + corner, a + (corner + 1) % 4, b + (corner + 1) % 4, b + corner) for corner in range(4)]
    last = len(vertices) - 4
    faces += [(0, 1, 2, 3), (last, last + 1, last + 2, last + 3)]
    return mesh(vertices, faces, colour, tidy=True, **look)


def cloud(colour="FFFFFF"):
    """A puffy cloud about 4 wide, for a photo's backdrop: place it with a scale."""
    for x, y, z, radius in ((0, 0, 0, 1.0), (-1.15, 0.1, -0.2, 0.72), (1.2, -0.1, -0.15, 0.8), (0.45, 0.4, 0.4, 0.66), (-0.5, -0.3, 0.3, 0.6), (2.05, 0, -0.38, 0.5), (-1.95, 0, -0.4, 0.46)):
        ball(radius, (x, y, z * 0.8), colour, scale=(1, 1, 0.78), segments=16, roughness=1.0)


# ---------------------------------------------------------------------------------------------------
# Standing things somewhere
# ---------------------------------------------------------------------------------------------------
def place(build, at, face=None, scale=1.0, **options):
    """Calls `build(**options)` (a prop made around its own origin, standing on z = 0, its front towards
    -Y) and stands what it made at (x, y) on the ground, or at (x, y, z). It looks at the middle unless
    `face` says where (degrees, like ring). Returns the frame it stands at."""
    first = len(made)
    build(**options)
    x, y = at[0], at[1]
    z = at[2] if len(at) > 2 else ground(x, y)
    if face is None:
        face = math.degrees(math.atan2(-x, -y)) if (x or y) else 180
    frame = Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(180 - face), 4, "Z")
    for obj in made[first:]:
        obj.matrix_basis = frame @ Matrix.Scale(scale, 4) @ obj.matrix_basis
    return frame


def stand(name, build, at, face=None, scale=1.0, also=(), **options):
    """A shell (a landmark the game moves on its own): a group of its own, placed like `place` does, and
    exported around its own base. `also` names the groups that share its origin (the sheet of a portal)."""
    with into(name):
        shells[name] = place(build, at, face, scale, **options)
    for other in also:
        shells[other] = shells[name]
    return shells[name]


# ---------------------------------------------------------------------------------------------------
# The photos
# ---------------------------------------------------------------------------------------------------
def aim(obj, eye, target):
    """Puts a camera or a light at `eye`, looking at `target`."""
    obj.location = eye
    obj.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()


def from_sky(degrees, height, distance):
    """A point `distance` away in a direction (degrees, like ring) and `height` degrees above the ground."""
    x, y = ring(degrees, distance * math.cos(math.radians(height)))
    return Vector((x, y, distance * math.sin(math.radians(height))))


def sky_ramp(top, horizon, below=None):
    """A sky for `studio` out of two colours: `top` straight up, `horizon`, and `below` under the horizon
    (the top's colour, a little paler, if not given)."""
    below = below or shade(top, 0.25)
    return ((0.0, shade(horizon, 0.3)), (0.15, shade(below, 0.6)), (0.36, below), (0.47, shade(below, 0.3)), (0.5, horizon), (0.62, shade(top, 0.4)), (0.8, shade(top, 0.15)), (1.0, top))


def studio(out=".", draft=False, sky=EARTH_SKY, sun_from=(238, 50), bounce_from=(200, -60), clip_end=2000, strength=0.85):
    """Sets up the photos, once, after the model is built: a sky that pales towards the horizon and below
    it (`sky` is a list of (position, colour) from straight down, 0, over the horizon, 0.5, to straight up,
    1; see `sky_ramp`), a warm sun at (direction, height) and a weak shadowless light from below (what sky
    and clouds throw back up), a camera, and Cycles on the graphics card when there is one. `draft` halves
    the photos' size. `photo` writes into `out`. Sets kit.camera, kit.sun and kit.bounce."""
    global _out, camera, sun, bounce
    _out = out
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    direction, split, remap, ramp = (nodes.new(kind) for kind in ("ShaderNodeTexCoord", "ShaderNodeSeparateXYZ", "ShaderNodeMapRange", "ShaderNodeValToRGB"))
    remap.inputs["From Min"].default_value = -1.0
    links.new(direction.outputs["Generated"], split.inputs[0])
    links.new(split.outputs["Z"], remap.inputs["Value"])
    links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], nodes["Background"].inputs["Color"])
    stops = ramp.color_ramp.elements
    for index, (position, colour) in enumerate(sky):
        stop = stops[index] if index < 2 else stops.new(position)
        stop.position = position
        stop.color = (*linear(colour), 1)
    nodes["Background"].inputs["Strength"].default_value = strength
    scene.world = world

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 2.7
    sun_data.angle = math.radians(6)
    sun_data.color = (1.0, 0.96, 0.88)
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    aim(sun, from_sky(sun_from[0], sun_from[1], 100), (0, 0, 0))
    bounce_data = bpy.data.lights.new("Bounce", "SUN")
    bounce_data.energy = 0.8
    bounce_data.color = (1.0, 0.93, 0.85)
    bounce_data.use_shadow = False
    bounce_data.specular_factor = 0.0
    bounce = bpy.data.objects.new("Bounce", bounce_data)
    scene.collection.objects.link(bounce)
    aim(bounce, from_sky(bounce_from[0], bounce_from[1], 100), (0, 0, 0))

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.clip_end = clip_end
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera

    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32 if draft else 80
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 50 if draft else 100
    scene.view_settings.view_transform = "Standard"
    try:  # the graphics card when there is one: much faster, and it leaves the processor to other renders
        devices = bpy.context.preferences.addons["cycles"].preferences
        devices.compute_device_type = "METAL"
        (getattr(devices, "refresh_devices", None) or devices.get_devices)()
        for device in devices.devices:
            device.use = device.type != "CPU"
        scene.cycles.device = "GPU"
    except Exception as problem:
        print("Rendering on the processor:", problem)


def photo(name, eye, target, lens, light=None):
    """Writes <out>/<name>.png: a photo from `eye` at `target` with a lens of `lens` mm. `light` moves the
    sun for this photo and the ones after it: (direction, height). Call `studio` first."""
    camera.data.type, camera.data.lens = "PERSP", lens
    aim(camera, eye, target)
    if light:
        aim(sun, from_sky(light[0], light[1], 100), (0, 0, 0))
        aim(bounce, from_sky(light[0] - 40, -60, 100), (0, 0, 0))
    bpy.context.scene.render.filepath = f"{_out}/{name}.png"
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------------------------------------------
# For Roblox
# ---------------------------------------------------------------------------------------------------
def _name(group, render_only):
    return ("RenderOnly_" if group in render_only else _prefix) + group


def count(render_only=()):
    """Prints how many pieces and triangles every group has, and their sum for the export. Returns
    {group: triangles}. Call it before `export` (which joins the pieces)."""
    render_only = _render_only + tuple(render_only)
    bpy.context.view_layer.update()
    triangles = {}
    for name, pieces in groups.items():
        triangles[name] = 0
        for obj in pieces:
            obj.data.calc_loop_triangles()
            triangles[name] += len(obj.data.loop_triangles)
        print(f"GROUP {_name(name, render_only)} pieces {len(pieces)} triangles {triangles[name]}")
    print(f"EXPORT triangles {sum(amount for name, amount in triangles.items() if name not in render_only)}")
    return triangles


def export(path, render_only=(), max_tris=10000, white=()):
    """Joins each group into one mesh named prefix + group, its colours on the vertices (the attribute
    "Col"), and writes them to the FBX at `path`, and the whole scene to the .blend beside it. Groups in
    `render_only` (and in init's) are joined and named "RenderOnly_" + group, and left out of the FBX.
    Scenery keeps the scene's origin, so dropped at the same spot it all lines up; a shell is exported
    around its own base, front towards -Y, and stands on its spot in the .blend. Groups in `white` are
    exported white, for the game to tint. Prints a warning for every mesh over `max_tris` triangles (Roblox
    takes 10,000 a mesh at most). Returns a list of {"name", "group", "triangles", "low", "high", "over"}
    for the exported meshes, low and high being the corners of its bounding box as exported.
    Call it last: after it `groups` holds pieces that no longer exist."""
    render_only = _render_only + tuple(render_only)
    exported, report = [], []
    for name, pieces in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in pieces:
            colour = (1.0, 1.0, 1.0) if name in white else obj.data.materials[0].diffuse_color
            attribute = obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
            attribute.data.foreach_set("color", [colour[0], colour[1], colour[2], 1.0] * len(obj.data.loops))
            obj.select_set(True)
        bpy.context.view_layer.objects.active = pieces[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = joined.data.name = _name(name, render_only)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if name in shells:
            joined.data.transform(shells[name].inverted())
            joined.matrix_basis = shells[name]
        if name in render_only:
            continue
        exported.append(joined)
        joined.data.calc_loop_triangles()
        corners = [vertex.co for vertex in joined.data.vertices]
        entry = {"name": joined.name, "group": name, "triangles": len(joined.data.loop_triangles),
                 "low": Vector([min(co[axis] for co in corners) for axis in range(3)]), "high": Vector([max(co[axis] for co in corners) for axis in range(3)])}
        entry["over"] = entry["triangles"] > max_tris
        if entry["over"]:
            print(f"WARNING {joined.name} has {entry['triangles']} triangles, over the {max_tris} a mesh may have: split its group")
        report.append(entry)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in exported:
        obj.select_set(True)
    for name in shells:
        bpy.data.objects[_prefix + name].matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", colors_type="SRGB")
    for name, frame in shells.items():
        bpy.data.objects[_prefix + name].matrix_basis = frame
    bpy.context.preferences.filepaths.save_version = 0  # no .blend1 beside it
    bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(path)[0] + ".blend")
    return report
