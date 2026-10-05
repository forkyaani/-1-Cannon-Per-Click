"""Builds "King Kaboom", a boss monster in the cute-cube style, renders a preview and exports it for Roblox.

Run: blender --background --python tools/blender/boss_king.py -- <output folder>
Everything is made from code, so the same script can be re-run with different colours for other bosses.
"""
import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, colour, roughness=0.45, emission=0.0, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*colour, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*colour, 1)
    return mat


def srgb(hex_code):
    hex_code = hex_code.lstrip("#")
    return tuple(((int(hex_code[i:i + 2], 16) / 255) ** 2.2) for i in (0, 2, 4))


BODY = material("Body", srgb("8E4DFF"), 0.5)
BELLY = material("Belly", srgb("C9A6FF"), 0.55)
DARK = material("Dark", srgb("4A1FA8"), 0.5)
EYE = material("Eye", srgb("1B1140"), 0.08)
WHITE = material("White", (1, 1, 1), 0.2)
GLOW = material("Glow", srgb("FF5AF0"), 0.3, emission=2.5)
GOLD = material("Gold", srgb("FFC61A"), 0.25, metallic=0.6)
GEM = material("Gem", srgb("FF3355"), 0.1, emission=0.6)
BLUSH = material("Blush", srgb("FF7AC8"), 0.6)
HORN = material("Horn", srgb("FFD98A"), 0.45)
FUSE = material("Fuse", srgb("3A1F55"), 0.6)
SPARK = material("Spark", srgb("FFB01F"), 0.3, emission=6)

parts = []


def finish(obj, mat, smooth=True):
    obj.data.materials.append(mat)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    parts.append(obj)
    return obj


def rounded_box(name, size, location, mat, bevel=0.35, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = bevel
    modifier.segments = 4
    bpy.ops.object.modifier_apply(modifier="Bevel")
    return finish(obj, mat)


def ball(name, radius, location, mat, scale=(1, 1, 1), rotation=(0, 0, 0), segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=segments, ring_count=segments // 2, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, mat)


def cone(name, radius, depth, location, mat, rotation=(0, 0, 0), tip=0.0, vertices=20):
    bpy.ops.mesh.primitive_cone_add(radius1=radius, radius2=tip, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat)


def cylinder(name, radius, depth, location, mat, rotation=(0, 0, 0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=vertices)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat)


# ---- Body: a fat rounded cube, slightly wider at the bottom, with a paler belly patch ----
body = rounded_box("Body", (3.0, 2.6, 2.7), (0, 0, 1.75), BODY, bevel=0.62)
ball("Belly", 1.0, (0, -1.22, 1.25), BELLY, scale=(1.05, 0.22, 0.8))

# Feet and arms: stubby rounded blocks.
for side in (-1, 1):
    rounded_box("Foot", (1.0, 1.25, 0.6), (side * 0.85, -0.25, 0.3), DARK, bevel=0.26)
    rounded_box("Arm", (0.62, 0.8, 1.0), (side * 1.72, -0.25, 1.35), DARK, bevel=0.28, rotation=(0, side * math.radians(-18), 0))

# ---- Face ----
FRONT = -1.3
for side in (-1, 1):
    x = side * 0.72
    ball("EyeWhite", 0.6, (x, FRONT - 0.02, 2.05), WHITE, scale=(1, 0.3, 1.08))
    ball("Eye", 0.5, (x, FRONT - 0.1, 2.02), EYE, scale=(1, 0.3, 1.1))
    ball("Iris", 0.3, (x, FRONT - 0.2, 1.93), GLOW, scale=(1, 0.25, 1))
    ball("Shine", 0.17, (x - 0.16, FRONT - 0.27, 2.24), WHITE, scale=(1, 0.3, 1))
    ball("ShineSmall", 0.08, (x + 0.2, FRONT - 0.27, 1.84), WHITE, scale=(1, 0.3, 1))
    ball("Blush", 0.26, (side * 1.12, FRONT - 0.0, 1.48), BLUSH, scale=(1.15, 0.2, 0.6))
    # An angry brow, tilted towards the nose: it is a boss, but a cute one.
    rounded_box("Brow", (0.85, 0.22, 0.24), (x, FRONT - 0.16, 2.74), DARK, bevel=0.09, rotation=(0, side * math.radians(-24), 0))
    # Fangs poking up from the mouth.
    cone("Fang", 0.17, 0.42, (side * 0.33, FRONT - 0.14, 1.06), WHITE, rotation=(math.pi, 0, 0), vertices=14)

rounded_box("Mouth", (1.05, 0.16, 0.22), (0, FRONT - 0.08, 1.26), EYE, bevel=0.07)

# ---- Horns ----
for side in (-1, 1):
    cone("Horn", 0.34, 0.95, (side * 1.2, 0.05, 3.3), HORN, rotation=(0, side * math.radians(28), 0))

# ---- Crown: a gold band, five points, a gem on each ----
cylinder("CrownBand", 0.82, 0.36, (0, 0.0, 3.28), GOLD)
for index in range(5):
    angle = math.radians(index * 72 - 90)
    x, y = math.cos(angle) * 0.7, math.sin(angle) * 0.7
    cone("CrownPoint", 0.24, 0.6, (x, y, 3.72), GOLD, vertices=14)
    ball("CrownBall", 0.11, (x, y, 4.05), GOLD)
    ball("CrownGem", 0.13, (math.cos(angle) * 0.82, math.sin(angle) * 0.82, 3.28), GEM, scale=(1, 1, 1.2))

# ---- A cannon fuse for a tail, with a glowing spark: this is a cannon game ----
tail = Vector((0, 1.35, 1.2))
for index in range(5):
    step = index / 4
    position = tail + Vector((0.25 * math.sin(step * 3), 0.2 + 0.25 * index, 0.3 * index))
    ball("FuseBit", 0.16 - 0.015 * index, position, FUSE)
spark_at = tail + Vector((0.25 * math.sin(3), 1.35, 1.4))
ball("Spark", 0.24, spark_at, SPARK)
for index in range(6):
    angle = index * math.pi / 3
    cone("SparkRay", 0.07, 0.42, spark_at + Vector((math.cos(angle) * 0.34, 0, math.sin(angle) * 0.34)), SPARK, rotation=(0, -angle + math.pi / 2, 0), vertices=8)

# ---- Report size ----
triangles = 0
for obj in parts:
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
print(f"PARTS {len(parts)} TRIANGLES {triangles}")

# ---- Export first (only the model), then build the photo studio around it ----
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=f"{OUT}/boss_king.fbx", use_selection=True, apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE")
bpy.ops.export_scene.gltf(filepath=f"{OUT}/boss_king.glb", use_selection=True)

# Studio: a curved pastel backdrop, soft key light, rim light.
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
floor = bpy.context.object
floor.data.materials.append(material("Floor", srgb("B9A8FF"), 0.9))
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (*srgb("D9CCFF"), 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
scene.world = world


def light(kind, location, energy, size, colour=(1, 1, 1)):
    data = bpy.data.lights.new(kind, "AREA")
    data.energy = energy
    data.size = size
    data.color = colour
    obj = bpy.data.objects.new(kind, data)
    obj.location = location
    scene.collection.objects.link(obj)
    direction = Vector((0, 0, 1.8)) - Vector(location)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


light("Key", (-5, -7, 8), 1500, 6)
light("Fill", (6, -5, 3), 700, 8, (0.85, 0.9, 1))
light("Rim", (3, 7, 7), 1200, 4, (1, 0.8, 1))

camera_data = bpy.data.cameras.new("Camera")
camera_data.lens = 70
camera = bpy.data.objects.new("Camera", camera_data)
camera.location = (-5.6, -11.5, 4.3)
scene.collection.objects.link(camera)
camera.rotation_euler = (Vector((0, 0, 2.05)) - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = camera

scene.render.engine = "CYCLES"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 1400
scene.view_settings.view_transform = "Standard"
scene.render.filepath = f"{OUT}/boss_king.png"
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/boss_king.blend")
