"""Eggs that can open: cuts every finished egg into a top and a bottom half along a toothed crack, so the game
can lift the top off (the hatch reveal, Effects.hatch in src/client/Effects.luau).

    blender --background --python tools/blender/egg_halves.py -- <output folder> <a .blend with eggs> [more .blend files]
    blender --background --python tools/blender/egg_halves.py -- assets/models/minis assets/models/minis/marketplace_minis.blend assets/models/minis/world_minis.blend

It does not model anything: it reads the eggs minis.py has already made (every mesh named egg_<id>, colours on
the vertices, its origin under its foot) out of the .blend files it is given. So an egg's two halves are
always that egg, and a new egg gets its halves by running this again. For every egg it writes two meshes:

    eggbottom_<id>   everything under the crack, with a ring of teeth standing up from the rim
    eggtop_<id>      everything over it, with teeth hanging down, half a tooth round from the bottom's

Both keep the egg's origin (under its foot, front towards -Y), so put on the same spot they are the egg again.
The cut is closed with a dark face in a shade of the shell, which reads as the hollow inside. The whole egg
(egg_<id>) stays what it is: the game shows it until the moment it cracks and only then swaps in the halves,
so the teeth are never seen closed.

Writes egg_halves.fbx and egg_halves.blend (the halves on the origin, as the other exports) and
egg_halves.png: every egg in a row with its top lifted off and tipped, to look at.
tools/studio/add_minis.luau files them into ReplicatedStorage.EggHalves as <id>_Top and <id>_Bottom.
"""
import math
import os
import re
import sys
from collections import Counter

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(ARGS) < 2:
    sys.exit("egg_halves.py -- <output folder> <a .blend with eggs> [more .blend files]")
OUT, SOURCES = ARGS[0], ARGS[1:]

CRACK = 0.54  # how far up the shell the crack runs, as a share of the shell's height
SHELL_HEIGHT = 3.58  # an egg's shell without what stands on it (minis.py); a shorter egg uses its own height
TEETH = 9
TOOTH_HEIGHT = 0.42
TOOTH_THICK = 0.09
INSIDE = 0.42  # the cut face: the shell's colour times this


def read_eggs():
    """{id: mesh} for every egg in the source files. A later file's egg of the same id wins."""
    found = {}
    for path in SOURCES:
        with bpy.data.libraries.load(path) as (source, target):
            target.objects = [name for name in source.objects if re.match(r"egg_", name, re.I)]
        for obj in target.objects:
            if obj is not None and obj.type == "MESH":
                found[re.sub(r"^egg_", "", obj.name.split(".")[0], flags=re.I)] = obj
    return found


def shell_colour(mesh):
    """The colour most of the egg's surface has."""
    layer = mesh.color_attributes["Col"]
    area = Counter()
    for polygon in mesh.polygons:
        colour = layer.data[polygon.loop_start].color
        area[(round(colour[0], 3), round(colour[1], 3), round(colour[2], 3))] += polygon.area
    return area.most_common(1)[0][0]


def half(source, upper, height, colour, name):
    """One side of the egg at `height`: the mesh cut and closed, plus its teeth."""
    bm = bmesh.new()
    bm.from_mesh(source)
    col = bm.loops.layers.color["Col"]
    cut = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, height), plane_no=(0, 0, 1),
                                 clear_outer=not upper, clear_inner=upper)
    edges = [item for item in cut["geom_cut"] if isinstance(item, bmesh.types.BMEdge)]
    rim = [vertex for vertex in bm.verts if abs(vertex.co.z - height) < 1e-4]
    filled = bmesh.ops.holes_fill(bm, edges=edges)
    inside = (colour[0] * INSIDE, colour[1] * INSIDE, colour[2] * INSIDE, 1.0)
    for face in filled["faces"]:
        for loop in face.loops:
            loop[col] = inside

    # The rim's radius: the shell's, not that of something standing beside the egg.
    radii = sorted(math.hypot(vertex.co.x, vertex.co.y) for vertex in rim)
    radius = radii[len(radii) // 2] if radii else 1.0
    tooth = tuple(min(1.0, channel * 1.12 + 0.04) for channel in colour) + (1.0,)
    step = 2 * math.pi / TEETH
    for index in range(TEETH):
        middle = (index + (0.5 if upper else 0.0)) * step
        points = []
        for r in (radius - TOOTH_THICK, radius + 0.01):
            left = Vector((math.cos(middle - step / 2) * r, math.sin(middle - step / 2) * r, height))
            right = Vector((math.cos(middle + step / 2) * r, math.sin(middle + step / 2) * r, height))
            # A top's tooth hangs down, a bottom's stands up; both lean with the shell a little.
            lean = 0.94 if upper else 0.97
            tip = Vector((math.cos(middle) * r * lean, math.sin(middle) * r * lean, height + (-TOOTH_HEIGHT if upper else TOOTH_HEIGHT)))
            points.append([bm.verts.new(left), bm.verts.new(right), bm.verts.new(tip)])
        inner, outer = points
        faces = [bm.faces.new(inner), bm.faces.new(outer[::-1])]
        for a, b in ((0, 1), (1, 2), (2, 0)):
            faces.append(bm.faces.new((inner[b], inner[a], outer[a], outer[b])))
        for face in faces:
            for loop in face.loops:
                loop[col] = tooth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def photo(pairs):
    """Every egg in a row, its top lifted off and tipped back, so the cut, the teeth and the inside show."""
    scene = bpy.context.scene
    material = bpy.data.materials.new("VertexColour")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Col"
    links.new(attribute.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    gap, per_row = 4.4, 8
    rows = (len(pairs) + per_row - 1) // per_row
    for index, (bottom, top) in enumerate(pairs):
        for obj in (bottom, top):
            obj.data.materials.append(material)
        row, column = divmod(index, per_row)
        at = Vector(((column - (min(per_row, len(pairs)) - 1) / 2) * gap, row * 9.0, 0))
        bottom.matrix_world = Matrix.Translation(at) @ Matrix.Rotation(math.radians(-20), 4, "Z")
        top.matrix_world = Matrix.Translation(at + Vector((0.5, 0, 1.5))) @ Matrix.Rotation(math.radians(-20), 4, "Z") @ Matrix.Rotation(math.radians(-28), 4, "X")
    bpy.ops.mesh.primitive_plane_add(size=4000, location=(0, 0, 0))
    ground = bpy.context.object
    floor = bpy.data.materials.new("Floor")
    floor.diffuse_color = (0.55, 0.62, 0.86, 1)
    floor.use_nodes = True
    floor.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.62, 0.86, 1)
    ground.data.materials.append(floor)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.86, 1.0, 1)
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.data.angle = 3.2, math.radians(12)
    sun.rotation_euler = (math.radians(52), 0, math.radians(-32))
    scene.collection.objects.link(sun)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 50
    scene.collection.objects.link(camera)
    scene.camera = camera
    width = gap * min(per_row, len(pairs)) + 2
    centre = Vector((0, (rows - 1) * 4.5, 2.6))
    distance = max(width / 0.72, 16 + rows * 6)
    camera.location = centre + Vector((0, -distance, distance * 0.42))
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 2400, 500 + 520 * rows
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = f"{OUT}/egg_halves.png"
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(ground)
    for bottom, top in pairs:
        bottom.matrix_world = top.matrix_world = Matrix.Identity(4)
        bottom.data.materials.clear()
        top.data.materials.clear()


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    eggs = read_eggs()
    if not eggs:
        sys.exit("egg_halves.py: no mesh named egg_<id> in " + ", ".join(SOURCES))
    pairs = []
    for egg_id in sorted(eggs):
        source = eggs[egg_id].data
        top_z = max(vertex.co.z for vertex in source.vertices)
        height = min(SHELL_HEIGHT, top_z) * CRACK
        colour = shell_colour(source)
        bottom = half(source, False, height, colour, "eggbottom_" + egg_id)
        top = half(source, True, height, colour, "eggtop_" + egg_id)
        pairs.append((bottom, top))
        for obj in (bottom, top):
            obj.data.calc_loop_triangles()
        print(f"EGG {egg_id} crack at {height:.2f} bottom {len(bottom.data.loop_triangles)} triangles top {len(top.data.loop_triangles)} triangles")
    photo(pairs)
    bpy.ops.object.select_all(action="DESELECT")
    for bottom, top in pairs:
        bottom.select_set(True)
        top.select_set(True)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.fbx(filepath=f"{OUT}/egg_halves.fbx", use_selection=True, apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE", colors_type="SRGB")
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and not obj.name.startswith(("eggbottom_", "eggtop_")):
            bpy.data.objects.remove(obj)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(f"{OUT}/egg_halves.blend"))


main()
