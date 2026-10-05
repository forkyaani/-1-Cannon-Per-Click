"""Builds the Earth wave in the cute-cube style: Slime, Goblin, Rock Crab, Wisp, Troll.
Renders them as a line-up and exports each one for Roblox.

Run: blender --background --python tools/blender/wave.py -- <output folder>
Each creature is the same recipe (rounded body, big eyes, feet) with its own colours and extras.
"""
import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}


def srgb(hex_code):
    hex_code = hex_code.lstrip("#")
    return tuple(((int(hex_code[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4))


def mat(hex_code, roughness=0.5, emission=0.0, metallic=0.0):
    key = (hex_code, roughness, emission, metallic)
    if key not in materials:
        m = bpy.data.materials.new(hex_code)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        colour = srgb(hex_code)
        bsdf.inputs["Base Color"].default_value = (*colour, 1)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission:
            bsdf.inputs["Emission Color"].default_value = (*colour, 1)
            bsdf.inputs["Emission Strength"].default_value = emission
        m.diffuse_color = (*colour, 1)
        materials[key] = m
    return materials[key]


WHITE, EYE, BLUSH = "FFFFFF", "1B1140", "FF8FB8"
parts = []  # the creature being built
origin = Vector((0, 0, 0))


def finish(obj, material):
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.location += origin
    parts.append(obj)
    return obj


def box(size, location, colour, bevel=0.3, rotation=(0, 0, 0), **look):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = bevel
    modifier.segments = 4
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return finish(obj, mat(colour, **look))


def ball(radius, location, colour, scale=(1, 1, 1), rotation=(0, 0, 0), **look):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=16, ring_count=8, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, mat(colour, **look))


def cone(radius, depth, location, colour, rotation=(0, 0, 0), tip=0.0, **look):
    bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=tip, depth=depth, location=location, rotation=rotation, vertices=14)
    return finish(bpy.context.object, mat(colour, **look))


def face(front, height, spread, iris, size=1.0, brow=None, brow_tilt=-20):
    """Two big glossy eyes on the body's front face (y = front), with blush under them."""
    for side in (-1, 1):
        x = side * spread
        ball(0.5 * size, (x, front - 0.02, height), WHITE, scale=(1, 0.3, 1.08), roughness=0.2)
        ball(0.42 * size, (x, front - 0.09, height - 0.02), EYE, scale=(1, 0.3, 1.1), roughness=0.08)
        ball(0.25 * size, (x, front - 0.17, height - 0.1), iris, scale=(1, 0.25, 1), roughness=0.3, emission=1.5)
        ball(0.14 * size, (x - 0.13 * size, front - 0.23, height + 0.17 * size), WHITE, scale=(1, 0.3, 1), roughness=0.2)
        ball(0.07 * size, (x + 0.16 * size, front - 0.23, height - 0.16 * size), WHITE, scale=(1, 0.3, 1), roughness=0.2)
        ball(0.2 * size, (side * (spread + 0.42 * size), front + 0.02, height - 0.5 * size), BLUSH, scale=(1.15, 0.2, 0.6), roughness=0.6)
        if brow:
            box((0.68 * size, 0.18, 0.18), (x, front - 0.14, height + 0.6 * size), brow, bevel=0.08, rotation=(0, side * math.radians(brow_tilt), 0))


def mouth(front, height, width=0.5, smile=True):
    box((width, 0.14, 0.14), (0, front - 0.06, height), EYE, bevel=0.06, roughness=0.3)
    if smile:
        for side in (-1, 1):
            box((0.2, 0.14, 0.14), (side * (width / 2 + 0.03), front - 0.06, height + 0.06), EYE, bevel=0.06, rotation=(0, side * math.radians(-40), 0), roughness=0.3)


def feet(colour, spread, y=-0.2, size=(0.75, 0.95, 0.45)):
    for side in (-1, 1):
        box(size, (side * spread, y, size[2] / 2), colour, bevel=0.2)


# ---- The five creatures of the wave ----
def slime():
    body, dark = "5FE03A", "3CB526"
    # A soft blob: a rounded box squashed wide, with a drip on top and a puddle under it.
    ball(1.25, (0, 0, 0.12), dark, scale=(1.25, 1.15, 0.12))
    box((2.2, 2.0, 1.75), (0, 0, 0.98), body, bevel=0.75, roughness=0.25)
    ball(0.32, (0.15, 0, 1.95), body, scale=(1, 1, 1.25), roughness=0.25)
    ball(0.16, (0.32, 0, 2.38), body, roughness=0.25)
    ball(0.45, (-0.55, -0.55, 1.45), "B6F59A", scale=(1, 0.5, 0.55), roughness=0.15)  # a wet highlight
    face(-1.0, 1.05, 0.5, "9CFF3A", size=0.9)
    mouth(-1.0, 0.52, 0.42)


def goblin():
    body, dark = "8FBF3F", "5E8A22"
    box((2.0, 1.8, 1.9), (0, 0, 1.35), body, bevel=0.5)
    feet(dark, 0.55)
    for side in (-1, 1):
        # Big pointed ears, with a pink inside.
        cone(0.42, 1.25, (side * 1.5, 0.05, 1.8), body, rotation=(0, side * math.radians(70), 0))
        cone(0.24, 0.8, (side * 1.4, -0.12, 1.78), "FFB3C7", rotation=(0, side * math.radians(70), 0))
        box((0.45, 0.6, 0.75), (side * 1.18, -0.2, 1.0), dark, bevel=0.2, rotation=(0, side * math.radians(-15), 0))
    face(-0.9, 1.5, 0.48, "FFC61A", size=0.85, brow=dark)
    mouth(-0.9, 0.88, 0.5, smile=False)
    cone(0.11, 0.3, (0.18, -1.0, 1.02), WHITE, roughness=0.3)  # one snaggle tooth
    # A leather cap.
    ball(0.85, (0, 0.05, 2.25), "B9783F", scale=(1.1, 1.0, 0.45))


def rock_crab():
    shell, dark, claw = "FF6A3D", "D9431F", "FF8A5C"
    box((2.6, 1.9, 1.3), (0, 0, 0.95), shell, bevel=0.55)
    # Rocks on the shell.
    for x, y, r in ((-0.6, 0.2, 0.5), (0.5, 0.35, 0.42), (0.05, -0.15, 0.36)):
        box((r * 1.6, r * 1.5, r * 1.2), (x, y, 1.65), "9A93B5", bevel=r * 0.35, rotation=(0.2, 0.3, x))
    for side in (-1, 1):
        for index in range(3):  # little legs
            box((0.5, 0.3, 0.5), (side * 1.25, -0.5 + index * 0.55, 0.22), dark, bevel=0.12, rotation=(0, side * math.radians(25), 0))
        # Claws: an arm and two pincers.
        box((0.5, 0.5, 0.5), (side * 1.55, -0.7, 0.95), dark, bevel=0.2)
        ball(0.5, (side * 1.95, -1.05, 1.2), claw, scale=(1, 0.8, 0.85))
        cone(0.2, 0.6, (side * 1.8, -1.45, 1.42), claw, rotation=(math.radians(100), 0, side * math.radians(-15)))
        cone(0.18, 0.5, (side * 2.12, -1.45, 1.05), claw, rotation=(math.radians(80), 0, side * math.radians(15)))
        # Eyes on stalks.
        box((0.22, 0.22, 0.6), (side * 0.48, -0.75, 1.75), dark, bevel=0.1)
    face(-0.86, 2.15, 0.48, "FFE23A", size=0.72)
    mouth(-0.95, 0.75, 0.4)


def wisp():
    body, pale = "9FDCFF", "DDF4FF"
    lift = 0.7  # it floats
    ball(1.0, (0, 0, lift + 1.0), body, scale=(1, 0.95, 1), roughness=0.2, emission=0.5)
    # A flame tuft curling up and back, and a wispy tail under it.
    for index, (y, z, r) in enumerate(((0.1, 1.95, 0.5), (0.3, 2.4, 0.36), (0.42, 2.75, 0.24), (0.42, 3.02, 0.14))):
        ball(r, (0, y, lift + z), body if index % 2 == 0 else pale, roughness=0.2, emission=0.6)
    for y, z, r in ((0.2, 0.15, 0.42), (0.42, -0.2, 0.28), (0.55, -0.45, 0.16)):
        ball(r, (0, y, lift + z), pale, roughness=0.2, emission=0.6)
    for side in (-1, 1):
        ball(0.26, (side * 1.12, -0.1, lift + 0.85), pale, scale=(1, 0.8, 1.2), roughness=0.2, emission=0.6)
    ball(1.15, (0, 0.1, 0.02), "6FB7E8", scale=(0.8, 0.8, 0.02))  # its shadow puddle of light
    face(-0.9, lift + 1.1, 0.42, "3FE0FF", size=0.8)
    ball(0.13, (0, -0.98, lift + 0.6), EYE, scale=(1, 0.4, 1.2), roughness=0.3)  # a little "o" mouth


def troll():
    body, dark, hair = "7F93B5", "55678A", "FF8A1F"
    box((2.3, 2.0, 2.7), (0, 0, 1.75), body, bevel=0.55)
    ball(0.85, (0, -0.95, 1.05), "B4C2DA", scale=(1.05, 0.22, 0.85))
    feet(dark, 0.62, size=(0.9, 1.1, 0.5))
    for side in (-1, 1):
        # Long heavy arms and a club-like fist.
        box((0.6, 0.75, 1.5), (side * 1.45, -0.15, 1.35), dark, bevel=0.26, rotation=(0, side * math.radians(-12), 0))
        ball(0.45, (side * 1.62, -0.2, 0.62), body, scale=(1, 1, 0.9))
        cone(0.15, 0.5, (side * 0.42, -1.12, 1.42), "FFF3D6", roughness=0.3)  # tusks, pointing up
        ball(0.3, (side * 1.2, 0.0, 2.5), body, scale=(0.6, 1, 1))  # ears
    face(-1.0, 2.1, 0.5, "FF8A1F", size=0.8, brow=dark, brow_tilt=-14)
    mouth(-1.0, 1.25, 0.6, smile=False)
    # A tuft of orange hair.
    for x, z, r in ((0, 3.25, 0.42), (-0.3, 3.15, 0.3), (0.32, 3.15, 0.3), (0.05, 3.62, 0.24)):
        ball(r, (x, 0.05, z), hair, scale=(1, 0.9, 1.25))


WAVE = [("slime", slime), ("goblin", goblin), ("rock_crab", rock_crab), ("wisp", wisp), ("troll", troll)]
SPACING = 3.9
everything = []
for index, (name, build) in enumerate(WAVE):
    parts = []
    origin = Vector(((index - (len(WAVE) - 1) / 2) * SPACING, 0, 0))
    build()
    triangles = 0
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.name = f"{name}_{obj.name}"
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        obj.select_set(True)
    print(f"CREATURE {name} parts {len(parts)} triangles {triangles}")
    # Exported standing on the origin, not where it stands in the line-up.
    for obj in parts:
        obj.location -= origin
    bpy.ops.export_scene.fbx(filepath=f"{OUT}/{name}.fbx", use_selection=True, apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE")
    for obj in parts:
        obj.location += origin
    everything += parts

# ---- The line-up photo: grass, sky, soft sun ----
bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, 0))
bpy.context.object.data.materials.append(mat("7BD957", roughness=0.9))
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*srgb("9FDCFF"), 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.85
scene.world = world


def light(location, energy, size, colour=(1, 1, 1)):
    data = bpy.data.lights.new("Light", "AREA")
    data.energy, data.size, data.color = energy, size, colour
    obj = bpy.data.objects.new("Light", data)
    obj.location = location
    scene.collection.objects.link(obj)
    obj.rotation_euler = (Vector((0, 0, 1.5)) - Vector(location)).to_track_quat("-Z", "Y").to_euler()


light((-8, -10, 12), 5500, 10, (1, 0.97, 0.9))
light((10, -8, 4), 1600, 12, (0.85, 0.92, 1))
light((2, 9, 8), 2600, 8, (1, 0.95, 0.85))

camera_data = bpy.data.cameras.new("Camera")
camera_data.lens = 50
camera = bpy.data.objects.new("Camera", camera_data)
camera.location = (-2.5, -33, 7.0)
scene.collection.objects.link(camera)
camera.rotation_euler = (Vector((0, 0, 1.45)) - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = camera

scene.render.engine = "CYCLES"
scene.cycles.samples = 80
scene.cycles.use_denoising = True
scene.render.resolution_x = 2000
scene.render.resolution_y = 1000
scene.view_settings.view_transform = "Standard"
scene.render.filepath = f"{OUT}/wave_earth.png"
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/wave_earth.blend")
