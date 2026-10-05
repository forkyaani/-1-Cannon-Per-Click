"""Animates the Earth wave walking, to show how the creatures will move in the game.

Run: blender --background assets/models/wave_earth.blend --python tools/blender/wave_walk.py -- <frames folder>
No skeleton: each creature moves as one piece (hop, squash, waddle, bob), which is how the game will do it
in code too, so what this shows is what Roblox can play.
"""
import math
import sys

import bpy
from mathutils import Matrix

OUT = sys.argv[sys.argv.index("--") + 1]
scene = bpy.context.scene
FRAMES = 40
NAMES = ["slime", "goblin", "rock_crab", "wisp", "troll"]


def slime(t):  # a squashy hop: flat on landing, tall in the air
    hop = abs(math.sin(t * math.pi * 2))
    return dict(z=hop * 0.9, sx=1.18 - hop * 0.3, sz=0.78 + hop * 0.42)


def goblin(t):  # a quick waddle
    return dict(z=abs(math.sin(t * math.pi * 4)) * 0.22, roll=math.sin(t * math.pi * 4) * 0.2)


def rock_crab(t):  # a sideways scuttle
    return dict(x=math.sin(t * math.pi * 2) * 0.7, z=abs(math.sin(t * math.pi * 8)) * 0.1, roll=math.sin(t * math.pi * 8) * 0.07)


def wisp(t):  # floats: a slow bob and sway
    return dict(z=math.sin(t * math.pi * 2) * 0.35, roll=math.sin(t * math.pi * 2 + 1) * 0.12, sz=1 + math.sin(t * math.pi * 4) * 0.04)


def troll(t):  # a heavy stomp
    step = math.sin(t * math.pi * 2)
    return dict(z=abs(step) * 0.3, roll=step * 0.13, sz=1 - (1 - abs(step)) * 0.07, sx=1 + (1 - abs(step)) * 0.05)


MOVES = dict(slime=slime, goblin=goblin, rock_crab=rock_crab, wisp=wisp, troll=troll)

for name in NAMES:
    members = [obj for obj in scene.objects if obj.name.startswith(name + "_")]
    centre = sum((obj.location.x for obj in members)) / len(members)
    # Round to the line-up spacing so the pivot is under the creature's feet, in its middle.
    base = round(centre / 3.9 * 2) / 2 * 3.9
    pivot = bpy.data.objects.new(name + "_pivot", None)
    pivot.location = (base, 0, 0)
    scene.collection.objects.link(pivot)
    for obj in members:
        obj.parent = pivot
        obj.matrix_parent_inverse = Matrix.Translation((base, 0, 0)).inverted()
    for frame in range(FRAMES):
        pose = MOVES[name](frame / FRAMES)
        pivot.location = (base + pose.get("x", 0), 0, pose.get("z", 0))
        pivot.rotation_euler = (0, pose.get("roll", 0), 0)
        sx = pose.get("sx", 1)
        pivot.scale = (sx, sx, pose.get("sz", 1))
        for path in ("location", "rotation_euler", "scale"):
            pivot.keyframe_insert(path, frame=frame + 1)

scene.frame_start, scene.frame_end = 1, FRAMES
scene.cycles.samples = 24
scene.render.resolution_x, scene.render.resolution_y = 1200, 600
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = f"{OUT}/f_"
bpy.ops.render.render(animation=True)
