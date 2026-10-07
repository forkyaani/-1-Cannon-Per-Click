"""A player's BASE for one of the launch worlds (themes.py), in the chunky, rounded simulator style of the
islands: the plot the game builds from parts (src/server/Plots.luau), made to be worn over it without moving
any of it. Every world has the same layout; the look comes from the world's theme.

Run: blender --background --python tools/blender/base.py -- <World> <output folder> [draft] [photos=a,b] [nofiles]
     <World> is one of the twelve of themes.py: "Earth", "Moon", "Mars", "Neptune", "The Sun", "The Void",
     "Nebula", "Crystal Belt", "Robot Factory", "Alien Jungle", "Black Hole", "The Big Bang". Capitals,
     spaces and underscores do not matter: the_sun, crystal_belt and TheBigBang work too.
     Worlds 6 to 12 wear their island's own things (island.py): its tall prop on the hills, its fence, its
     liquid down the butte, one of its set pieces as the landmark. Everything made for them is in a branch
     of its own (NEW): the first five worlds come out exactly as they did before there were twelve.

THE MAPPING. Plot space is the game's (Layout.luau): the origin is the middle of the base's edge of the
ground, x runs across the plot, +z up the plot to the portal, y is up, the ground's top is y = 0 and the yard
is behind the origin (-z). 1 unit is 1 stud. In Blender:
    Blender x = -plot x        Blender y = plot z        Blender z = plot y
so Blender's (x, y, z) is plot (-x, z, y): the portal is at Blender y = +147, the gate at y = 14, the yard at
y = -16 ... 0. This is exactly how an FBX lands in Roblox (Blender (x, y, z) -> (-x, z, y)), and it puts the
plot's north (the portal) on Blender +Y, where tools/studio/setup_models.luau wants a scene's north.
`at(x, z, y)` turns plot space into Blender's; every position below is written in plot space.
A shell is made around the middle of its own base, standing on z = 0, its front towards -Y. `face` says
where that front looks in plot space: 0 up the plot (+z), 90 towards +x, 180 back at the yard (-z).
In Roblox a shell's front is its pivot's -Z:  frame * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(face + 180), 0).
Two marker meshes are in every export: Base_Origin (a 2 x 2 x 2 cube, its middle 1 above the plot's origin)
and Base_North (the same cube 10 towards the portal). They are not in the photos.

Everything the game lays out is copied from Layout.luau and Plots.luau (see LAYOUT below): the path and its
width, the sixteen pads, the gate and its towers and walls, the name sign, the plaza and the arrival pad, the
portal, the two teleporters, the two lamps, the fence and the size of the ground.

Writes <world>_base_hero.png, <world>_base_ground.png, <world>_base.blend, <world>_base.fbx and
<world>_base_manifest.json (world in small letters, _ for spaces). Meshes, colours on the vertices:
  scenery, all with the plot's origin (on the ground) as origin:
      Base_Ground  Base_Cliff  Base_Road  Base_Backdrop  Base_Trees  Base_Dressing
      Base_Glow (for Neon)  Base_Water (for Glass; not on a world whose liquid glows)
  shells, each around the middle of its own base, front towards -Y:
      Base_Pad + Base_PadTrim        Base_Gate + Base_GateTrim        Base_Portal + Base_PortalSheet
      Base_Teleporter + Base_TeleporterTrim        Base_Lamp
  A ...Trim mesh is pure white on its vertices: the game's Color tints it (the owner's colour, a
  teleporter's destination, a pad's state). In the photos it wears a stand-in colour.
The floor stays clean: lawn, road and pads are big calm shapes and nothing small lies on them. Trees, rocks
and the landmark stand outside the ground, where the game has its solid skyline.
The towers, the monsters, the bulbs, the beams, the words on the signs and the sky in the photos are
stand-ins and are not exported; neither are the copies of a shell on its other spots.
`draft` makes the photos at half size. `photos=road,gate` makes only those (hero, ground, or one of CHECKS;
`photos=none` makes none). `nofiles` skips the export.
"""
import json
import math
import os
import sys
from contextlib import contextmanager

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import *
from themes import THEMES

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WORLD = next((name for name in THEMES if ARGS and name.lower().replace(" ", "") == ARGS[0].lower().replace(" ", "").replace("_", "")), None)
if WORLD is None:
    sys.exit(f"base.py: the first argument has to be a world ({', '.join(THEMES)}), then the output folder")
OUT = ARGS[1] if len(ARGS) > 1 else "."
DRAFT = "draft" in ARGS
NOFILES = "nofiles" in ARGS
ONLY = [name for arg in ARGS if arg.startswith("photos=") for name in arg[7:].split(",")]
SLUG = WORLD.lower().replace(" ", "_")
T = THEMES[WORLD]
NEW = WORLD not in ("Earth", "Moon", "Mars", "Neptune", "The Sun")  # worlds 6 to 12: every branch made for them asks this, or their theme's kind

SCENERY = ("Ground", "Cliff", "Road", "Backdrop", "Trees", "Dressing", "Water", "Glow", "Origin", "North")
TRIMS = ("PadTrim", "GateTrim", "TeleporterTrim")  # exported white, for the game to tint
RENDER_ONLY = ("Placeholders", "Sky")  # in the photos, not in the export
kit.init(seed=11, prefix="Base_", scenery=SCENERY, render_only=RENDER_ONLY)


def mix(a, b, share):
    """A colour between two."""
    return "".join("%02X" % round(int(a[i:i + 2], 16) + (int(b[i:i + 2], 16) - int(a[i:i + 2], 16)) * share) for i in (0, 2, 4))


# ---------------------------------------------------------------------------------------------------
# The look: the theme's colours, and what a base needs on top of them (LOOKS: a theme key or a colour).
# ---------------------------------------------------------------------------------------------------
GRASS, GRASS_LIGHT, GRASS_DEEP, GRASS_RIM = T["grass"], T["grass_light"], T["grass_deep"], T["grass_rim"]
DIRT, DIRT_DARK = T["dirt"], T["dirt_dark"]
ROCK, ROCK_DARK, ROCK_LIGHT = T["rock"], T["rock_dark"], T["rock_light"]
UNDER, UNDER_DARK, UNDER_LIGHT = T["under"], T["under_dark"], T["under_light"]
SAND, SAND_DARK, COBBLE = T["sand"], T["sand_dark"], T["cobble"]
STONE, STONE_DARK, STONE_PALE = T["stone"], T["stone_dark"], T["stone_pale"]
WOOD, WOOD_LIGHT, WOOD_DARK = T["wood"], T["wood_light"], T["wood_dark"]
WATER, WATER_LIGHT = T["water"], T["water_light"]
LEAVES, PETALS = T["leaves"], T["petals"]
ACCENT, ACCENT_PALE = T["accent"], T["accent_pale"]
WHITE, INK, GOLD, RED, BLUE = "FFFFFF", "1B1140", "FFC61A", "FF4D4D", "3FA9FF"
BONE, BONE_DARK = "FFF3D6", "E3C385"

LOOKS = {
    # road, road_edge, kerb: the road has to read as THE path from far away, so on pale ground it is dark.
    # hot, ember: the monsters' portal glows in a colour that is not the world's accent (the island's portal).
    # lair: the portal's stone. roof: the towers' roofs. knob: what tops a wall's post. window: a tower's.
    "Earth": dict(road="sand", road_edge="sand_dark", kerb="stone_pale", kerb_glow=0.0, band="sand_dark", hot="FF3D7F", ember="FF8A3D", lair="5F5888",
                  roof="cone", knob="ball", window=INK, iron="4A4763", board="3A3560", landmark="windmill", cloud="FFFFFF", ambient=0.85, sun=2.7,
                  monsters=("5FD35A", "8FD93E", "FF8A3D", "E8F4FF")),
    "Moon": dict(road="6A5CC4", road_edge="5548A8", kerb="cobble", kerb_glow=0.0, band="6A5CC4", hot="5CFF7A", ember="C8FF5A", lair="52488C",
                 roof="dome", knob="bulb", window="accent", iron="wood_dark", board="2A2560", landmark="rocket", cloud="3D3684", ambient=1.0, fill=3.2, sun=2.9,
                 sky=((0.0, "2C2670"), (0.15, "262062"), (0.36, "1F1B54"), (0.47, "3A3182"), (0.5, "5246A0"), (0.62, "2E2872"), (0.8, "1F1B54"), (1.0, "17153F")),
                 monsters=("B9B5DA", "FF9BE0", "7FD8FF", "FFE27A")),
    "Mars": dict(road="sand", road_edge="sand_dark", kerb="cobble", kerb_glow=0.0, band="sand_dark", hot="B45CFF", ember="FF5CD0", lair="6E2A34",
                 roof="pagoda", knob="pyramid", window=INK, iron="wood_dark", board="4A1E30", landmark="arch", cloud="FFF1DC", ambient=0.85, sun=2.6,
                 monsters=("FF5A5A", "FFD25A", "5FD08A", "35D6C4")),
    "Neptune": dict(road="3A6FCC", road_edge="2A52A8", kerb="cobble", kerb_glow=0.0, band="3A6FCC", hot="FF4D8F", ember="FFB03D", lair="2A52A8",
                    roof="spire", knob="crystal", window="accent", iron="wood_dark", board="1E3C80", landmark="igloo", cloud="FFFFFF", ambient=0.85, sun=2.6,
                    monsters=("FFFFFF", "B58CFF", "5AE1FF", "FF9BE0")),
    "The Sun": dict(road="rock", road_edge="rock_dark", kerb="water_light", kerb_glow=1.0, band="rock", hot="3DB4FF", ember="B06BFF", lair="3F2632",
                    roof="flame", knob="ember", window="accent", iron="wood_dark", board="26141E", landmark="volcano", cloud="FFF3C4", ambient=0.8, sun=2.5,
                    monsters=("FF4D4D", "FFE56A", "FFFFFF", "FF8A1F")),
    # Worlds 6 to 12. More keys, all optional: stone (stone, dark, pale: what is BUILT here, when the theme's
    # own stone would vanish against this world's ground), hills (four tones, when the ground's rim is another
    # colour than the ground), crags (the five tones of the rock behind the portal, when the theme's rock goes
    # grey in this world's light), stars (the photos' night sky), lamp_glow (the lamp's bands glow).
    "The Void": dict(road="2A1266", road_edge="1E0A50", kerb="water", kerb_glow=1.0, band="sand_dark", hot="FF7A28", ember="FFD23C", lair="30289E",
                     roof="shard", knob="gem", window="accent", iron="wood_dark", board="200C54", landmark="rift", cloud="5A34B8", ambient=1.0, fill=4.5, sun=2.9,
                     stone=("8C94FF", "6468E4", "BCC4FF"), stars=("F6C2FF", "FF7AD0", "78DCFF"), lamp_glow=True,
                     sky=((0.0, "2A1270"), (0.36, "160A3C"), (0.47, "30167A"), (0.5, "3A1A7A"), (0.62, "2A1270"), (0.8, "160A3C"), (1.0, "0C0618")),
                     monsters=("FF3C8C", "78DCFF", "FFE27A", "F6C2FF")),
    "Nebula": dict(road="wood", road_edge="wood_dark", kerb="cobble", kerb_glow=0.0, band="wood", hot="FFD23C", ember="FF8A3D", lair="under_dark",
                   roof="onion", knob="nova", window="accent", iron="wood_dark", board="4A389A", landmark="telescope", cloud="FFC2EE", ambient=0.85, sun=2.6,
                   stars=("FFFFFF", "FFE27A", "C8FFF8"), lamp_glow=True, monsters=("6CE0E8", "FFE27A", "B49CFF", "FFFFFF")),
    "Crystal Belt": dict(road="under", road_edge="under_dark", kerb="cobble", kerb_glow=0.0, band="under", hot="FF4D8F", ember="FFB03D", lair="wood_dark",
                         roof="prism", knob="prism", window="accent", iron="wood_dark", board="1A3480", landmark="geode", cloud="3C78B8", ambient=1.0, fill=3.4, sun=2.9,
                         stars=("FFFFFF", "ECD8FF", "8CF0E6"), lamp_glow=True,
                         sky=((0.0, "1E4A8C"), (0.36, "101E4A"), (0.47, "24589A"), (0.5, "2E6C9C"), (0.62, "1E4A8C"), (0.8, "101E4A"), (1.0, "101E4A")),
                         monsters=("FF7AD0", "FFD24A", "B46CFF", "FFFFFF")),
    "Robot Factory": dict(road="sand", road_edge="sand_dark", kerb="2C3870", kerb_glow=0.0, band="sand_dark", hot="FF3C3C", ember="FFC21A", lair="under_dark",
                          roof="tank", knob="bolt", window="accent", iron="2C3870", board="242E8C", landmark="robot_arm", cloud="FFF6D0", ambient=0.85, sun=2.6,
                          hills=("2E64DA", "3458C8", "2A52C0", "2840A0"), lamp_glow=True, monsters=("FF6A2A", "50FFAA", "FFC21A", "FF7AD0")),
    "Alien Jungle": dict(road="sand", road_edge="sand_dark", kerb="rock", kerb_glow=0.0, band="sand_dark", hot="3CD8FF", ember="B4FF2A", lair="under",
                         roof="cap", knob="pod", window="accent", iron="wood_dark", board="2C1858", landmark="snap_pod", cloud="E8FFB0", ambient=0.85, sun=2.6,
                         lamp_glow=True, monsters=("FF5AB4", "FFB03C", "A85CFF", "FFFFFF")),
    "Black Hole": dict(road="sand", road_edge="sand_dark", kerb="water_light", kerb_glow=1.0, band="sand_dark", hot="5ADCE6", ember="B06BFF", lair="wood_light",
                       roof="claw", knob="orbit", window="accent", iron="wood_dark", board="360A3A", landmark="black_hole", cloud="A02848", ambient=1.0, fill=5.0, sun=3.1,
                       stone=("B84A8A", "8A3070", "E070A8"), crags=("6A1C78", "7C2488", "641E6E", "78267E", "902E8E"), hills=("962C90", "882884", "7A2478", "8A2A6C"), stars=("FFD8A0", "FF8A28", "FF7AA8"), lamp_glow=True,
                       sky=((0.0, "6A1434"), (0.36, "2A0A20"), (0.47, "861A3C"), (0.5, "A01C40"), (0.62, "6A1434"), (0.8, "2A0A20"), (1.0, "1A0616")),
                       monsters=("FF3C8C", "5ADCE6", "B45CFF", "FFFFFF")),
    "The Big Bang": dict(road="sand_dark", road_edge="under_dark", kerb="cobble", kerb_glow=0.0, band="sand_dark", hot="FF3C6E", ember="3C9CFF", lair="under_dark",
                         roof="burst", knob="spark", window="accent", iron="wood_dark", board="8A3CC0", landmark="bang", cloud="FFFFFF", ambient=0.85, sun=2.5,
                         stone=("E4CCFF", "BE96F0", "F8ECFF"), lamp_glow=True, monsters=("FF4A5A", "3C9CFF", "FFD83A", "FFFFFF")),
}
LOOK = {key: T.get(value, value) if isinstance(value, str) else value for key, value in LOOKS[WORLD].items()}
ROAD, ROAD_EDGE, KERB_COLOUR = LOOK["road"], LOOK["road_edge"], LOOK["kerb"]
IRON, BOARD = LOOK["iron"], LOOK["board"]  # metal, and what the game writes on in white
if "stone" in LOOK:
    STONE, STONE_DARK, STONE_PALE = LOOK["stone"]
NAVY, HOLE, NEBULA_GOLD = "2C3870", "160A24", "FFC42E"  # island.py's: the Factory's dark paint, a black hole's heart, Nebula's stars
# The hills round the plot: darker than the ground, four tones from its deep patch to its rim.
HILLS = LOOK.get("hills") or (("55BE48", "4AB246", "3FA548", "369A4A") if WORLD == "Earth" else tuple(mix(GRASS_DEEP, GRASS_RIM, share) for share in (0.1, 0.4, 0.7, 1.0)))
# The monsters' portal: dark stone and a hot glow, nothing like the island's friendly one.
LAIR, LAIR_DARK, LAIR_DEEP = LOOK["lair"], shade(LOOK["lair"], -0.22), shade(LOOK["lair"], -0.4)
HOT, HOT_DARK, HOT_DEEP, HOT_CORE, EMBER = LOOK["hot"], shade(LOOK["hot"], -0.25), shade(LOOK["hot"], -0.55), shade(LOOK["hot"], -0.82), LOOK["ember"]
LIQUID_GLOW = {"rift": 1.4, "gas": 0.8, "coolant": 1.2, "acid": 1.2, "singularity": 1.5, "energy": 1.0}  # island.py's, for the new worlds' liquids
GLOWS = T["liquid"] in ("stardust", "lava") or T["liquid"] in LIQUID_GLOW  # the world's liquid glows


# ---------------------------------------------------------------------------------------------------
# What the kit does not have: flat hand-made pieces
# ---------------------------------------------------------------------------------------------------
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
PADS = ((4, 113), (14, 26), (-8, 53), (8, 53), (-24, 53), (24, 53), (-8, 83), (8, 83), (-24, 83), (24, 83),
        (-20, 113), (-14, 26), (24, 113), (-50, 53), (50, 83), (-50, 113))
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
WORLD_SIGN = (-9.9, 9.9, 24.76, 31.56)  # the world's name on the middle slab of the skyline, at z = 150: x from, x to, y from, y to
OWNER = "FF6161"  # a stand-in for the owner's colour in the photos: the game's colour of slot 1


def at(x, z, y=0.0):
    """A point of plot space (x across, z up the plot, y up) in Blender's."""
    return Vector((-x, z, y))


def place(build, spot, face=0.0, scale=1.0, **options):
    """Builds a prop (made around its own origin, standing on z = 0, its front towards -Y) and stands it at
    (x, z) or (x, z, y) of plot space, its front looking `face` (0 up the plot, 90 towards +x, 180 at the
    yard). Returns the frame it stands at. (The kit's own `place` is the island's: it has another north.)"""
    first = len(made)
    build(**options)
    frame = Matrix.Translation(at(*spot)) @ Matrix.Rotation(math.radians(face + 180), 4, "Z")
    for obj in made[first:]:
        obj.matrix_basis = frame @ Matrix.Scale(scale, 4) @ obj.matrix_basis
    return frame


def moved(first, frame):
    """Moves every piece made since `first` by a frame: a part of a prop built somewhere handier."""
    for obj in made[first:]:
        obj.matrix_basis = frame @ obj.matrix_basis


def stand(name, build, spot, face=0.0, also=(), **options):
    """A shell: a group of its own, on one of its spots. `also` names the meshes that share its origin."""
    with into(name):
        shells[name] = place(build, spot, face, **options)
    for other in also:
        shells[other] = shells[name]


@contextmanager
def part(name):
    """`with part("PadTrim"):` builds into another mesh of the shell being built (its trim, its sheet). In a
    stand-in for the photos the pieces stay with the stand-in."""
    if current() in RENDER_ONLY:
        yield
    else:
        with into(name):
            yield


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
# What stands on the hills: the theme's `tree`. Each is about 16 tall around its own origin; `tone` picks
# one of the three leaf colours, `variant` one of two shapes.
# ---------------------------------------------------------------------------------------------------
def tree_round_tall(tone=0, variant=0):
    """Earth: a fat trunk and balls of leaves, round or stacked like a fir."""
    leaf = LEAVES[tone]
    tube(1.25, 7.5, (0, 0, -0.6), (0.04, 0, 1), WOOD, tip=0.8, vertices=6)
    if not variant:
        ball(5.3, (0, 0, 10.2), leaf, scale=(1, 1, 0.9), segments=12)
        ball(3.5, (-3.3, -1.0, 8.2), shade(leaf, -0.1), segments=8)
        ball(3.3, (3.1, 1.2, 8.7), shade(leaf, -0.1), segments=8)
        ball(3.1, (0.9, -1.6, 13.2), shade(leaf, 0.14), segments=8)
    else:
        ball(4.7, (0, 0, 8.2), shade(leaf, -0.1), scale=(1, 1, 0.8), segments=10)
        ball(3.8, (0, 0, 12.2), leaf, scale=(1, 1, 0.85), segments=8)
        ball(2.7, (0, 0, 15.6), shade(leaf, 0.14), scale=(1, 1, 0.95), segments=8)


def tree_crater_rock(tone=0, variant=0):
    """Moon: a boulder with a crater bowl in it and glowing crystals growing out of it."""
    chunk((4.8, 4.4, 3.9), (0, 0, 2.6), ROCK_LIGHT if variant else ROCK, detail=1)
    chunk((2.5, 2.3, 1.9), (3.7, 1.0, 1.0), ROCK_DARK, detail=1)
    tilt = (math.radians(58), 0, 0)  # the bowl looks to the front and up
    hoop(1.75, 0.5, (0, -3.1, 4.2), ROCK_LIGHT if not variant else ROCK, rotation=tilt, segments=8)
    ball(1.7, (0, -2.95, 4.1), ROCK_DARK, scale=(1, 1, 0.3), rotation=tilt, segments=8)
    for index, (x, y, z, radius, length, lean_x, lean_y) in enumerate(((0.4, 0.6, 4.6, 1.5, 10.5, 0.06, 0.04), (-1.9, 0.9, 4.0, 1.05, 6.8, -0.34, 0.1), (2.2, -0.2, 3.9, 0.95, 5.6, 0.4, -0.08), (-0.6, 2.2, 3.6, 0.8, 4.4, -0.1, 0.42))):
        if variant and index == 3:
            continue
        tube(radius, length, (x, y, z), (lean_x, lean_y, 1), LEAVES[(tone + index) % 3], tip=0.0, vertices=5, smooth=False, roughness=0.2, emission=0.55)


def tree_mesa_spire(tone=0, variant=0):
    """Mars: a flat-topped spire of stacked rock layers."""
    layers = ((3.5, 3.0, 3.6), (2.8, 2.6, 2.8), (3.0, 2.5, 2.4), (2.3, 2.1, 3.4), (3.4, 3.1, 1.5)) if not variant else ((3.2, 2.8, 2.8), (2.6, 2.3, 3.6), (2.8, 2.6, 1.8), (2.0, 1.8, 2.6), (2.9, 2.6, 1.3))
    z = -0.7
    for index, (low, high, height) in enumerate(layers):
        tube(low, height, (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), z), UP, LEAVES[(tone + index) % 3], tip=high, vertices=8, smooth=False, roughness=0.9)
        z += height
    tube(1.9, 2.4, (3.6, 0.8, -0.6), UP, LEAVES[(tone + 1) % 3], tip=1.5, vertices=6, smooth=False, roughness=0.9)  # a stump of a second spire beside it
    tube(2.2, 0.9, (3.6, 0.8, 1.8), UP, LEAVES[(tone + 2) % 3], tip=2.0, vertices=6, smooth=False, roughness=0.9)


def tree_ice_spike(tone=0, variant=0):
    """Neptune: a cluster of leaning ice shards in a drift of snow."""
    ball(4.0, (0, 0, 0.1), GRASS_LIGHT, scale=(1, 1, 0.42), segments=8, roughness=0.9)
    shards = ((0, 0.2, 2.0, 16.0, 0.05, 0.0), (-2.2, 0.6, 1.5, 10.5, -0.3, 0.1), (2.3, -0.4, 1.45, 12.0, 0.32, -0.05), (0.4, -2.0, 1.15, 7.5, 0.1, -0.38), (-0.6, 2.1, 1.2, 8.5, -0.12, 0.34))
    for index, (x, y, radius, length, lean_x, lean_y) in enumerate(shards):
        if variant and index == 4:
            continue
        way = Vector((lean_x, lean_y, 1)).normalized()
        colour = LEAVES[(tone + index) % 3]
        tube(radius, length * 0.58, (x, y, -0.6), way, colour, tip=radius * 0.82, vertices=5, smooth=False, roughness=0.2)
        tube(radius * 0.82, length * 0.42, Vector((x, y, -0.6)) + way * length * 0.58, way, shade(colour, 0.3), tip=0.0, vertices=5, smooth=False, roughness=0.2)


def tree_lava_spire(tone=0, variant=0):
    """The Sun: a basalt spire with glowing cracks and a molten tip."""
    height = 13.0 if variant else 15.0
    lathe([(0, height), (0.9, height * 0.86), (1.7, height * 0.64), (2.5, height * 0.38), (3.4, height * 0.13), (4.0, -0.7)], ROCK_LIGHT if variant else ROCK, segments=7, rough=0.3, smooth=False)
    ball(1.35, (0, 0, height + 0.1), LEAVES[tone], scale=(1, 1, 1.15), segments=8, emission=1.0)
    tube(0.5, 3.2, (0.45, -0.85, height - 0.4), (0.12, -0.16, -1), LEAVES[(tone + 1) % 3], tip=0.18, vertices=5, emission=1.0)  # a drip down its front
    tube(0.42, 2.2, (-0.8, 0.3, height - 0.5), (-0.2, 0.05, -1), LEAVES[(tone + 1) % 3], tip=0.15, vertices=5, emission=1.0)
    for degrees, z, length in ((200, 4.6, 3.6), (150, 7.6, 2.8), (290, 3.4, 3.0), (40, 5.6, 3.2)):  # cracks
        reach = 2.5 + (3.4 - 2.5) * (height * 0.38 - z) / (height * 0.25) if z < height * 0.38 else 1.7 + (2.5 - 1.7) * (height * 0.64 - z) / (height * 0.26)
        x, y = ring(degrees, reach + 0.12)
        slab((0.42, 0.42, length), (x, y, z), LEAVES[(tone + 2) % 3], rotation=(rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), -math.radians(degrees)), emission=1.0)


# ---- Worlds 6 to 12: island.py's tall props and the few pieces they are made of, copied (island.py is a
# script, not a module). None of this runs for worlds 1 to 5. ----
def gem(radius, height, spot, colour, lean=UP, sides=4, **look):
    """A shard with two points, base to base: its waist is at `spot`, its long point along `lean`."""
    lean = Vector(lean).normalized()
    tube(radius, height * 0.62, spot, lean, colour, tip=0.0, vertices=sides, **look)
    tube(radius, height * 0.38, spot, -lean, colour, tip=0.0, vertices=sides, **look)


def prism(radius, length, start, lean, colour, point=0.3, sides=6, **look):
    """A cut crystal: a six-sided column from `start` along `lean`, a little wider towards its pointed end."""
    lean = Vector(lean).normalized()
    body = length * (1 - point)
    tube(radius * 0.82, body, start, lean, colour, tip=radius, vertices=sides, **look)
    tube(radius, length - body, Vector(start) + lean * body, lean, colour, tip=0.0, vertices=sides, **look)


def upright(outline, depth, colour, location=(0, 0, 0), rotation=(0, 0, 0), **look):
    """A flat shape standing upright, its face to the front (-Y): `outline` is its (x, z) corners in order.
    Every corner must be in sight of the middle of them. (island.py's `plate`.)"""
    count = len(outline)
    middle = (sum(x for x, z in outline) / count, sum(z for x, z in outline) / count)
    vertices = [(x, -depth / 2, z) for x, z in outline] + [(x, depth / 2, z) for x, z in outline] + [(middle[0], -depth / 2, middle[1]), (middle[0], depth / 2, middle[1])]
    faces = [(2 * count, index, (index + 1) % count) for index in range(count)] + [(2 * count + 1, count + (index + 1) % count, count + index) for index in range(count)]
    faces += [(index, count + index, count + (index + 1) % count, (index + 1) % count) for index in range(count)]
    return mesh(vertices, faces, colour, location, rotation, smooth=False, tidy=True, **look)


def bent(start, leans, radius, length, colours, taper=0.12, vertices=8, glow=None, **look):
    """A trunk that bends: one piece per lean, each `length` long and thinner than the one before. `glow`
    puts a glowing band on every joint. Returns where it ends."""
    spot = Vector(start)
    for index, lean in enumerate(leans):
        lean = Vector(lean).normalized()
        thick = radius * (1 - taper * index)
        tube(thick, length * 1.08, spot, lean, colours[index % len(colours)], tip=radius * (1 - taper * (index + 1)), vertices=vertices, **look)
        if glow and index:
            tube(thick * 1.06, 0.3, spot - lean * 0.15, lean, glow, vertices=vertices, emission=1.3)
        spot = spot + lean * length
    return spot


def void_gem(radius, height, spot, lean, glow):
    """The Void's hanging shard: rock above, and the point it was torn off at still glowing below."""
    lean = Vector(lean).normalized()
    tube(radius, height * 0.62, spot, lean, ROCK_LIGHT, tip=0.0, vertices=5, roughness=0.3)
    tube(radius, height * 0.38, spot, -lean, glow, tip=0.0, vertices=5, emission=1.2)


def nova(size, spot, colour=NEBULA_GOLD):
    """Nebula: a star that reads from every side: two crossed."""
    for turn in (0, math.pi / 2):
        star(size, spot, colour, depth=size * 0.4, rotation=(0, 0, turn), emission=0.8)


def sag(a, b, height, drop, radius, colour, **look):
    """A rope or a chain hanging between two posts' feet (Blender points), `height` up at its ends and `drop` lower in the middle."""
    start, end = a + Vector((0, 0, height)), b + Vector((0, 0, height))
    middle = (start + end) / 2 - Vector((0, 0, drop))
    for p, q in ((start, middle), (middle, end)):
        tube(radius, (q - p).length, p, q - p, colour, vertices=4, **look)


def tree_void_shard(tone=0, variant=0):
    """The Void: shards of rock torn loose, hanging over the stump they came from round a glowing core; or a
    broken obelisk whose pieces float apart, light in the gaps."""
    leaf = LEAVES[tone]
    pale = shade(leaf, 0.4)
    if not variant:
        chunk((3.3, 3.1, 1.5), (0, 0, 0.6), ROCK_DARK, detail=1)
        tube(1.9, 0.5, (0, 0, 1.6), UP, leaf, tip=1.2, vertices=6, emission=1.3)  # the wound it left, still glowing
        ball(1.7, (0, 0, 5.6), leaf, segments=8, emission=1.5)
        hoop(3.0, 0.26, (0, 0, 5.6), pale, rotation=(0.45, 0.25, 0), segments=10, emission=1.2)
        for x, y, z, radius, height, lean in ((2.9, 1.6, 6.4, 1.5, 6.0, (0.25, 0.1, 1)), (-3.1, 0.9, 5.0, 1.3, 4.6, (-0.3, 0.05, 1)), (0.4, -3.0, 7.6, 1.25, 4.8, (0.05, -0.3, 1)), (-0.5, 0.8, 11.2, 1.35, 5.2, (-0.08, 0.05, 1))):
            void_gem(radius, height, (x, y, z), lean, leaf)
    else:
        tube(2.3, 3.2, (0, 0, -0.4), UP, ROCK_DARK, tip=1.85, vertices=5)
        tube(2.12, 0.3, (0, 0, 1.3), UP, leaf, vertices=5, emission=1.3)  # a band of runes
        ball(1.15, (0, 0, 3.6), leaf, segments=6, emission=1.5)
        tube(1.85, 4.6, (0.15, 0, 4.5), (0.03, 0, 1), ROCK, tip=1.45, vertices=5, roughness=0.3)
        for z, radius in ((5.5, 1.84), (7.0, 1.72), (8.4, 1.6)):
            tube(radius, 0.28, (0.15 + (z - 4.5) * 0.03, 0, z), (0.03, 0, 1), pale if z == 7.0 else leaf, vertices=5, emission=1.3)
        ball(0.95, (0.3, 0, 9.9), leaf, segments=6, emission=1.5)
        hoop(2.6, 0.24, (0.3, 0, 9.9), pale, rotation=(0.3, 0.15, 0), segments=10, emission=1.2)
        void_gem(1.45, 6.4, (0.4, 0, 12.9), (0.04, 0, 1), leaf)


def tree_gas_cloud(tone=0, variant=0):
    """Nebula: a heap of gas puffs with newborn stars in it (the pink ones with a ring of teal light round
    them), or a plume of puffs twisting up to a star."""
    leaf = LEAVES[tone]
    deep, light = shade(leaf, -0.14), shade(leaf, 0.35)
    if not variant:
        for x, y, z, radius, colour, segments in ((0, 0, 3.1, 3.9, leaf, 10), (-3.0, -0.5, 2.1, 2.6, deep, 8), (2.9, 0.7, 2.3, 2.7, deep, 8), (0.6, -0.9, 6.7, 2.9, light, 8), (-1.3, 0.9, 9.3, 1.9, light, 8)):
            ball(radius, (x, y, z), colour, scale=(1, 1, 0.88), segments=segments, roughness=1.0)
        if tone == 0:
            hoop(5.6, 0.42, (0, 0, 4.4), ACCENT, rotation=(0.3, 0.16, 0), segments=16, emission=0.7)
        for x, y, z, size in ((-1.0, -0.5, 12.6, 1.7), (-4.3, -1.6, 6.2, 1.0), (4.2, -1.2, 6.8, 1.15)):
            nova(size, (x, y, z))
    else:
        for index in range(5):
            turn, radius = index * 1.25, 3.0 - index * 0.38
            ball(radius, (math.cos(turn) * 1.1, math.sin(turn) * 1.1, 1.9 + index * 2.55), (deep, leaf, light)[index % 3], scale=(1, 1, 0.92), segments=8, roughness=1.0)
        nova(1.9, (0.3, -0.3, 15.6))
        nova(0.9, (-2.9, -1.4, 9.4))


def tree_crystal_cluster(tone=0, variant=0):
    """The Crystal Belt: cut crystals out of a chunk of asteroid, a spread of five or one tall one with a
    belt of small rocks round it."""
    leaf = LEAVES[tone]
    others, light = [colour for colour in LEAVES if colour != leaf], shade(leaf, 0.3)
    if not variant:
        chunk((3.6, 3.4, 2.0), (0, 0, 1.0), ROCK, detail=1)
        chunk((1.6, 1.5, 1.1), (2.6, -1.4, 0.6), ROCK_DARK, detail=1)
        crystals = ((0.2, 0.2, 2.0, 12.5, (0.08, 0.05, 1), leaf), (-1.7, 0.8, 1.5, 9.0, (-0.5, 0.2, 1), others[0]), (1.9, -0.3, 1.4, 8.0, (0.55, -0.12, 1), light),
                    (0.2, -1.9, 1.1, 6.0, (0.08, -0.6, 1), others[1]), (0.3, 2.0, 1.2, 6.5, (0.0, 0.55, 1), light))
    else:
        chunk((2.6, 2.4, 1.5), (0, 0, 0.7), ROCK, detail=1)
        crystals = ((0, 0, 1.8, 16.5, (0.03, 0.02, 1), leaf), (-1.5, 0.3, 1.1, 7.5, (-0.4, 0.05, 1), others[0]), (1.4, -0.5, 1.0, 6.0, (0.45, -0.15, 1), light))
        for index in range(8):  # its belt: rocks and small gems on a tilted ring
            x, y = ring(index * 45 + 10, 3.3)
            z = 10.2 + 1.2 * math.sin(math.radians(index * 45 + 10))
            if index % 2:
                gem(0.5, 1.5, (x, y, z), others[index // 2 % 2], roughness=0.12)
            else:
                chunk((0.95, 0.9, 0.75), (x, y, z), ROCK_LIGHT, detail=1)
    for x, y, radius, length, lean, colour in crystals:
        prism(radius, length, (x, y, 0.4), lean, colour, roughness=0.12)


def tree_factory_stack(tone=0, variant=0):
    """The Robot Factory: a bolted tank with a gauge and a pipe, or a striped chimney with a puff of steam."""
    leaf = LEAVES[tone]
    if not variant:
        tube(3.5, 0.7, (0, 0, -0.3), UP, NAVY, vertices=10)
        tube(3.0, 5.4, (0, 0, 0.4), UP, leaf, vertices=10, roughness=0.35)
        lathe([(0, 1.5), (1.7, 1.2), (3.0, 0)], leaf, segments=10, location=(0, 0, 5.8), roughness=0.35)
        for z in (1.5, 4.6):
            tube(3.14, 0.5, (0, 0, z - 0.25), UP, NAVY, vertices=10)
            for degrees in (130, 230):  # (island.py has six bolts a band, a rim round the gauge and twelve sides: thirty of these share one mesh of 10,000 triangles)
                x, y = ring(degrees, 3.2)
                slab((0.5, 0.5, 0.34), (x, y, z), GOLD, rotation=(0, 0, -math.radians(degrees)), roughness=0.3)
        tube(1.1, 0.35, (0, -2.95, 3.1), (0, -1, 0), WHITE, vertices=8)  # the gauge
        slab((0.16, 0.12, 0.85), (0.2, -3.36, 3.3), RED, rotation=(0, 0.6, 0))
        tube(0.6, 2.4, (0, 0, 7.0), UP, T["stone"], vertices=6)  # the pipe out of its top, with an elbow
        ball(0.78, (0, 0, 9.4), T["stone_dark"], segments=6)
        tube(0.6, 2.7, (0, 0, 9.4), (1, 0.2, 0), T["stone"], vertices=6)
        ball(0.55, (-1.6, 0.6, 7.4), ACCENT, segments=6, emission=1.3)
    else:
        z = -0.4
        for index, height in enumerate((3.2, 2.4, 2.4, 2.4, 2.4)):
            radius = 2.3 - index * 0.2
            tube(radius, height, (0, 0, z), UP, leaf if index % 2 == 0 else WHITE, tip=radius - 0.2, vertices=8, roughness=0.4)
            z += height
        tube(1.6, 0.6, (0, 0, z - 0.4), UP, NAVY, vertices=8)
        tube(1.1, 0.3, (0, 0, z), UP, ACCENT, vertices=8, emission=1.3)
        for x, y, rise, radius in ((0.2, 0, 1.6, 1.3), (1.5, 0.4, 3.0, 1.05), (3.0, 0.2, 3.9, 0.75)):  # drifting off, not a stack
            ball(radius, (x, y, z + rise), "F4F8FF", segments=6, roughness=1.0)


def tree_glow_shroom(tone=0, variant=0):
    """The Alien Jungle: a giant mushroom with glowing spots, wide and squat with a young one beside it, or
    tall on a bending stalk with a bell cap and lights hanging from its rim."""
    leaf = LEAVES[tone]
    stalk, glow, spots = "D2A2FF", WATER_LIGHT, "5CF0E0"  # a lilac stalk, lime gills and lights, cyan spots: no toadstool has those

    def cap(radius, height, spot, tilt, colour, drops=False):
        first = len(made)
        lathe([(0, height), (radius * 0.5, height * 0.86), (radius * 0.88, height * 0.42), (radius, 0), (radius * 0.86, -0.35), (0, -0.2)], colour, segments=12, roughness=0.4)
        tube(radius * 0.8, 0.3, (0, 0, -0.5), UP, glow, vertices=8, emission=1.2)  # the gills
        for degrees, share in ((10, 0.3), (130, 0.42), (250, 0.36), (70, 0.72), (190, 0.76), (310, 0.7))[:5 if radius > 3 else 3]:
            x, y = ring(degrees, radius * share)
            out = Vector((x / radius, y / radius, 0.9 * height / radius * (1.1 - share))).normalized()  # roughly the cap's own slope there
            wide = radius * (0.2 if share < 0.5 else 0.14)
            tube(wide, 0.34, Vector((x, y, height * (1 - 0.72 * share * share) - 0.16)), out, spots, tip=wide * 0.6, vertices=5, emission=1.4)
        for index in range(4 if drops else 0):
            x, y = ring(index * 90 + 20, radius * 0.82)
            tube(0.08, 1.7, (x, y, -0.3), (0, 0, -1), glow, vertices=3, emission=1.0)
            gem(0.4, 1.0, (x, y, -2.3), glow, emission=1.3)
        moved(first, Matrix.Translation(spot) @ Matrix.Rotation(tilt, 4, "Y"))

    if not variant:
        stalk = "DDF7A0"  # pale lime under the wide cap: lilac goes grey in the gills' lime light
        tube(1.9, 6.6, (0, 0, -0.4), (0.06, 0, 1), stalk, tip=1.2, vertices=8)
        tube(1.35, 0.5, (0.27, 0, 4.1), (0.06, 0, 1), glow, vertices=8, emission=1.2)  # a glowing band under the cap
        cap(5.6, 3.4, (0.4, 0, 5.9), 0.1, leaf)
        tube(0.7, 2.6, (3.9, -2.2, -0.3), (0.1, -0.05, 1), stalk, tip=0.5, vertices=6)
        cap(2.1, 1.4, (4.1, -2.3, 2.1), 0.2, shade(leaf, 0.2))
    else:
        end = bent((0, 0, -0.4), [(0.05, 0, 1), (0.15, 0, 1), (0.3, 0, 1), (0.42, 0, 1)], 1.2, 3.1, (stalk, shade(stalk, -0.12)), taper=0.1, glow=glow)
        cap(3.3, 4.2, end - Vector((0.1, 0, 0.5)), 0.36, leaf, drops=True)


def tree_bent_rock(tone=0, variant=0):
    """The Black Hole: rock pulled out of shape. Two claws closing over a small black hole, or a spire that
    breaks up at the top, its pieces falling in an arc into one."""
    leaf = LEAVES[tone]

    def hole(spot, radius):  # a dark ball in a thin ring of fire, well clear of it and nearly level (close to it or tilted at you, it is an eye)
        ball(radius, spot, HOLE, segments=10, roughness=0.3)
        first = len(made)
        lathe([(radius * 1.42, -radius * 0.08), (radius * 1.42, radius * 0.08), (radius * 1.85, radius * 0.05), (radius * 1.85, -radius * 0.05), (radius * 1.42, -radius * 0.08)], leaf, segments=10, emission=1.5)
        moved(first, Matrix.Translation(spot) @ Matrix.Rotation(0.16, 4, "X") @ Matrix.Rotation(0.08, 4, "Y"))

    if not variant:
        chunk((3.8, 3.1, 1.5), (0, 0, 0.5), ROCK_DARK, detail=1)
        for side in (-1, 1):
            bent((side * 2.9, 0, 0.2), [(side * 0.5, 0, 1), (side * 0.1, 0, 1), (-side * 0.5, 0, 1), (-side * 1.3, 0, 1)], 1.8, 2.9, (ROCK, ROCK_LIGHT), taper=0.2, vertices=5, glow=leaf)
        hole(Vector((0, 0, 6.0)), 1.8)
    else:
        leans = [(0.03, 0, 1), (0.12, 0, 1), (0.26, 0, 1)]
        end = bent((0, 0, -0.4), leans, 2.5, 3.1, (ROCK, ROCK_LIGHT, ROCK), taper=0.17, vertices=5)
        tube(1.3, 0.3, end - Vector(leans[-1]).normalized() * 0.1, leans[-1], leaf, vertices=5, emission=1.4)  # where it broke
        for x, z, size in ((1.7, 10.3, 1.0), (2.1, 11.9, 0.75), (2.3, 13.2, 0.5)):  # the pieces, on their way in
            chunk((size, size * 0.9, size * 1.1), (x, 0, z), ROCK_LIGHT if size > 0.6 else ROCK, detail=1)
        hole(Vector((2.4, 0, 15.3)), 1.4)


def tree_spark_burst(tone=0, variant=0):
    """The Big Bang: a spark with shards flying out of it, stopped mid-burst; or a beam of light with rings
    of shards round it."""
    leaf = LEAVES[tone]
    deep = shade(leaf, -0.18)

    def shards(middle, count, reach, size, rise=0.0, turn=0.0):
        for index in range(count):
            x, y = ring(index * 360 / count + turn, 1.0)
            out = Vector((x, y, rise)).normalized()
            gem(0.62 * size, 2.7 * size, Vector(middle) + out * reach, leaf if index % 2 == 0 else deep, out, roughness=0.25)

    tube(2.2, 0.6, (0, 0, -0.2), UP, WOOD, vertices=8, roughness=0.3)
    if not variant:
        tube(0.9, 5.0, (0, 0, 0.4), UP, WOOD_LIGHT, tip=0.6, vertices=6, roughness=0.3)
        ball(2.3, (0, 0, 7.2), ACCENT, segments=10, emission=0.9)
        shards((0, 0, 7.2), 6, 3.9, 1.35)
        shards((0, 0, 7.2), 4, 3.7, 1.15, rise=0.9, turn=45)
        shards((0, 0, 7.2), 4, 3.5, 1.0, rise=-0.6, turn=20)
        gem(0.8, 4.0, (0, 0, 11.6), leaf, roughness=0.25)
    else:
        tube(1.3, 14.2, (0, 0, 0.2), UP, ACCENT, tip=0.25, vertices=6, emission=0.9)  # a ray of light, standing
        shards((0, 0, 4.4), 5, 3.0, 1.2, rise=0.35)
        shards((0, 0, 8.6), 4, 2.6, 1.0, rise=0.45, turn=36)
        shards((0, 0, 12.2), 3, 2.1, 0.85, rise=0.55, turn=10)
        gem(1.3, 4.4, (0, 0, 15.6), leaf, roughness=0.25)


TREE = {"round_tall": tree_round_tall, "crater_rock": tree_crater_rock, "mesa_spire": tree_mesa_spire, "ice_spike": tree_ice_spike, "lava_spire": tree_lava_spire,
        "void_shard": tree_void_shard, "gas_cloud": tree_gas_cloud, "crystal_cluster": tree_crystal_cluster, "factory_stack": tree_factory_stack,
        "glow_shroom": tree_glow_shroom, "bent_rock": tree_bent_rock, "spark_burst": tree_spark_burst}[T["tree"]]


def rocks(colour=ROCK):
    chunk((2.3, 2.0, 1.7), (0, 0, 0.9), colour)
    chunk((1.3, 1.2, 1.0), (2.4, 0.6, 0.5), shade(colour, -0.14), detail=1)
    chunk((0.95, 0.9, 0.7), (-2.1, -0.9, 0.35), shade(colour, 0.14), detail=1)


# ---------------------------------------------------------------------------------------------------
# The fence: the theme's kind, where the game's solid rails are
# ---------------------------------------------------------------------------------------------------
def fence_new(kind, points, turn, first, last):
    """Worlds 6 to 12: island.py's fences (themed_fence), a size up, on a run's posts. What runs from post to
    post is where the game's two solid rails are (FENCE_RAILS), or sags between them."""
    low, high = FENCE_RAILS
    spin = (0, 0, turn)
    for index, point in enumerate(points):
        if (index == 0 and not first) or (index == len(points) - 1 and not last):
            continue
        foot = at(point.x, point.y)
        if kind == "rift_post":  # The Void: a small obelisk, a gem of light floating over it
            tube(0.95, 3.4, foot + Vector((0, 0, -0.3)), UP, ROCK_LIGHT, tip=0.55, vertices=4)
            gem(0.62, 1.8, foot + Vector((0, 0, 4.4)), LEAVES[index % 3], emission=1.4)
        elif kind == "star_rope":  # Nebula: a post with a star on it
            tube(0.55, 3.7, foot + Vector((0, 0, -0.3)), UP, WOOD_LIGHT, vertices=6)
            ball(0.62, foot + Vector((0, 0, 3.45)), PETALS[0], segments=6)
            star(1.25, foot + Vector((0, 0, 4.6)), NEBULA_GOLD, depth=0.45, rotation=(0, 0, turn + math.pi / 2), emission=0.8)
        elif kind == "crystal_post":  # Crystal Belt: a stone post with a gem on it
            box((1.5, 1.5, 3.0), foot + Vector((0, 0, 1.2)), STONE, bevel=0.3, rotation=spin, segments=1)
            gem(1.0, 2.8, foot + Vector((0, 0, 3.8)), LEAVES[index % 3], roughness=0.12)
        elif kind == "pipe_rail":  # Robot Factory: a bollard in hazard stripes
            tube(0.9, 4.0, foot + Vector((0, 0, -0.3)), UP, "FFC21A", vertices=6, roughness=0.4)
            tube(0.96, 1.1, foot + Vector((0, 0, 1.45)), UP, NAVY, vertices=6)
            tube(1.12, 0.4, foot + Vector((0, 0, 3.7)), UP, WOOD, vertices=6)
        elif kind == "vine_post":  # Alien Jungle: a thorn with a glowing pod
            tube(0.85, 4.0, foot + Vector((0, 0, -0.3)), (rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 1), WOOD, tip=0.4, vertices=6)
            gem(0.85, 2.0, foot + Vector((0, 0, 4.0)), LEAVES[index % 3], sides=5, emission=1.2)
        elif kind == "orbit_post":  # Black Hole: a post with a ringed ball on it
            box((1.4, 1.4, 3.7), foot + Vector((0, 0, 1.55)), ROCK_LIGHT, bevel=0.3, rotation=spin, segments=1)
            ball(0.68, foot + Vector((0, 0, 4.3)), HOLE, segments=6)
            tube(1.35, 0.14, foot + Vector((0, 0, 4.23)), (0.55 * math.sin(turn + 0.9), 0.55 * math.cos(turn + 0.9), 1), LEAVES[0], vertices=8, emission=1.4)
        else:  # spark_post, The Big Bang: a gold post with a spark on it
            tube(0.62, 3.6, foot + Vector((0, 0, -0.3)), UP, WOOD_LIGHT, vertices=6, roughness=0.3)
            gem(0.8, 2.0, foot + Vector((0, 0, 4.2)), ACCENT_PALE, emission=1.4)
    for a, b in zip(points, points[1:]):
        a, b = at(a.x, a.y), at(b.x, b.y)
        if kind == "rift_post":  # beams of light
            tube(0.28, (b - a).length, a + Vector((0, 0, high)), b - a, ACCENT, vertices=4, emission=1.0)
            tube(0.2, (b - a).length, a + Vector((0, 0, low)), b - a, LEAVES[1], vertices=4, emission=1.0)
        elif kind == "star_rope":
            sag(a, b, 3.1, 0.75, 0.28, PETALS[0])
            sag(a, b, 1.75, 0.5, 0.24, LEAVES[2])
        elif kind == "crystal_post":
            for height in (low, high):
                tube(0.32, (b - a).length, a + Vector((0, 0, height)), b - a, WOOD_LIGHT, vertices=4, roughness=0.15)
        elif kind == "pipe_rail":  # two pipes
            for height in (low, high):
                tube(0.36, (b - a).length, a + Vector((0, 0, height)), b - a, T["stone"], vertices=4, roughness=0.3)
        elif kind == "vine_post":
            sag(a, b, 3.1, 0.9, 0.3, GRASS_LIGHT)
            sag(a, b, 1.75, 0.5, 0.24, WOOD_LIGHT)
        elif kind == "orbit_post":  # chains that glow
            sag(a, b, 3.1, 0.75, 0.24, LEAVES[1], emission=1.0)
            sag(a, b, 1.75, 0.5, 0.22, T["stone_pale"])  # (not glowing: every glowing piece of the scenery is in one mesh)
        else:  # a bolt of lightning over a rail of gold
            corners = [a + Vector((0, 0, high))] + [a + (b - a) * share + Vector((0, 0, height)) for share, height in ((0.3, high + 0.8), (0.62, high - 0.9))] + [b + Vector((0, 0, high))]
            for p, q in zip(corners, corners[1:]):
                tube(0.26, (q - p).length, p, q - p, ACCENT, vertices=4, emission=1.2)
            tube(0.26, (b - a).length, a + Vector((0, 0, low)), b - a, WOOD, vertices=4, roughness=0.3)


def fence_run(start, end, count, first=True, last=True):
    """A fence from one point of the plot to another, `count` posts on it."""
    kind = T["fence"]
    start, end = Vector(start), Vector(end)
    way = end - start
    turn = math.atan2(way.x, way.y)
    points = [start + way * index / (count - 1) for index in range(count)]
    if NEW:
        return fence_new(kind, points, turn, first, last)
    for index, point in enumerate(points):
        if (index == 0 and not first) or (index == count - 1 and not last):
            continue
        if kind == "wood_rail":
            box((1.3, 1.3, 4.3), at(point.x, point.y, 1.95), WOOD_LIGHT, bevel=0.3, segments=1, rotation=(0, 0, turn))
        elif kind == "metal_rail":
            tube(0.55, 3.7, at(point.x, point.y, -0.2), UP, WOOD, vertices=6)
            tube(0.8, 0.35, at(point.x, point.y, 3.4), UP, WOOD_DARK, vertices=6)
            ball(0.72, at(point.x, point.y, 4.3), ACCENT, segments=6, emission=0.9)
        elif kind == "rope_post":
            box((1.5, 1.5, 4.0), at(point.x, point.y, 1.8), STONE_DARK, bevel=0.3, segments=1, rotation=(0, 0, turn))
            box((1.9, 1.9, 0.6), at(point.x, point.y, 4.0), STONE_PALE, bevel=0.2, segments=1, rotation=(0, 0, turn))
        elif kind == "ice_post":
            tube(1.0, 5.0, at(point.x, point.y, -0.3), (rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 1), LEAVES[index % 3], tip=0.0, vertices=5, smooth=False, roughness=0.2)
        else:  # basalt_chain
            box((1.5, 1.5, 3.8), at(point.x, point.y, 1.7), ROCK_LIGHT, bevel=0.3, segments=1, rotation=(0, 0, turn))
            ball(0.7, at(point.x, point.y, 4.0), LEAVES[0], segments=6, emission=1.0)
    middle = (start + end) / 2
    if kind in ("wood_rail", "metal_rail", "ice_post"):
        colours = {"wood_rail": (WOOD, WOOD), "metal_rail": (WOOD_DARK, WOOD_LIGHT), "ice_post": (WATER, WATER_LIGHT)}[kind]
        for height, colour in zip(FENCE_RAILS, colours):
            slab((0.5, way.length, 0.5), at(middle.x, middle.y, height), colour, rotation=(0, 0, turn))
    else:  # a rope or a chain that sags from post to post, twice
        colour = SAND_DARK if kind == "rope_post" else shade(ROCK_LIGHT, 0.25)
        for a, b in zip(points, points[1:]):
            for top, sag in ((3.1, 0.75), (1.75, 0.5)):
                heights = (top, top - sag, top - sag, top)
                for step in range(3):
                    low, high = a + (b - a) * step / 3, a + (b - a) * (step + 1) / 3
                    rise, run = heights[step + 1] - heights[step], (high - low).length
                    spot = (low + high) / 2
                    slab((0.34, math.hypot(run, rise) + 0.1, 0.34), at(spot.x, spot.y, (heights[step] + heights[step + 1]) / 2), colour, rotation=(math.atan2(rise, run), 0, turn))


def lamp():
    """The game's lamp, without its bulb: the game's own glowing ball (LAMP_BULB_SIZE across, its middle
    LAMP_BULB up) hangs in the cage, so its light and its Halloween colour stay the game's."""
    tube(1.15, 0.9, (0, 0, 0), UP, STONE, vertices=10)
    tube(0.85, 0.4, (0, 0, 0.9), UP, STONE_DARK, vertices=10)
    tube(0.42, 9.0, (0, 0, 1.3), UP, IRON, tip=0.32, vertices=8)
    if LOOK.get("lamp_glow"):  # worlds 6 to 12: the two bands on the post glow in the world's accent
        hoop(0.52, 0.2, (0, 0, 2.4), ACCENT, segments=10, emission=1.0)
        hoop(0.44, 0.18, (0, 0, 9.5), ACCENT, segments=10, emission=1.0)
    else:
        hoop(0.5, 0.17, (0, 0, 2.4), GOLD, segments=10, roughness=0.3)
        hoop(0.42, 0.15, (0, 0, 9.5), GOLD, segments=10, roughness=0.3)
    tube(0.45, 0.6, (0, 0, 10.3), UP, IRON, tip=1.3, vertices=10)
    for index in range(4):
        x, y = ring(index * 90 + 45, 1.24)
        tube(0.1, 2.3, (x, y, 10.85), UP, IRON, vertices=4)
    tube(1.75, 1.3, (0, 0, 13.1), UP, IRON, tip=0.2, vertices=10)
    ball(0.32, (0, 0, 14.6), GOLD, segments=8, roughness=0.3)


# ---------------------------------------------------------------------------------------------------
# A landmark for the hills beside the plot, one per world. Front -Y.
# ---------------------------------------------------------------------------------------------------
def windmill():
    """Earth: a stone mill with a red cap and four sails."""
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


def rocket():
    """Moon: a fat little rocket on its fins, ready to go."""
    tube(1.7, 1.6, (0, 0, 1.6), UP, IRON, tip=2.3, vertices=10)
    lathe([(0, 14.0), (2.75, 14.0), (3.3, 10.6), (3.3, 6.0), (2.5, 3.2), (0, 3.2)], COBBLE, segments=12)
    lathe([(0, 19.4), (0.9, 18.4), (1.9, 16.6), (2.78, 14.0), (0, 14.0)], RED, segments=12)
    ball(0.5, (0, 0, 19.5), GOLD, segments=8, roughness=0.3)
    hoop(3.36, 0.34, (0, 0, 6.2), GOLD, segments=12, roughness=0.3)
    hoop(2.82, 0.3, (0, 0, 13.9), GOLD, segments=12, roughness=0.3)
    tube(1.45, 0.6, (0, -2.95, 10.2), (0, -1, 0), WOOD_DARK, vertices=10)
    tube(1.05, 0.7, (0, -2.95, 10.2), (0, -1, 0), ACCENT, vertices=10, emission=0.8)
    for index in range(3):
        x, y = ring(index * 120 + 60, 3.4)
        mesh([(0, -0.35, 6.6), (0, -0.35, 0), (3.0, -0.35, -0.6), (3.0, -0.35, 2.2), (0, 0.35, 6.6), (0, 0.35, 0), (3.0, 0.35, -0.6), (3.0, 0.35, 2.2)],
             [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], RED, (x * 0.8, y * 0.8, 0.6), (0, 0, math.radians(90 - (index * 120 + 60))), smooth=False, tidy=True)


def arch():
    """Mars: a natural arch of layered rock."""
    for side in (-1, 1):
        for index, (width, height) in enumerate(((5.2, 3.6), (4.4, 3.2), (4.8, 3.0), (4.2, 3.2))):
            box((width, width * 0.9, height + 0.1), (side * (6.4 - index * 0.25), 0, -0.6 + sum(h for w, h in ((5.2, 3.6), (4.4, 3.2), (4.8, 3.0), (4.2, 3.2))[:index]) + height / 2), LEAVES[(index + (side > 0)) % 3], bevel=0.7, rotation=(0, 0, rng.uniform(-0.15, 0.15)), roughness=0.9)
    box((18.5, 4.6, 3.4), (0, 0, 14.0), LEAVES[1], bevel=0.9, roughness=0.9)
    box((12.0, 4.0, 2.0), (0.6, 0, 16.5), LEAVES[2], bevel=0.7, roughness=0.9)
    box((6.0, 3.4, 1.5), (-1.0, 0, 18.1), LEAVES[0], bevel=0.6, roughness=0.9)


def igloo():
    """Neptune: an igloo with a lit doorway and a flag."""
    ball(6.4, (0, 0, -0.4), COBBLE, scale=(1, 1, 0.92), segments=14, roughness=0.8)
    for z, colour in ((1.5, STONE_DARK), (3.4, STONE_DARK), (4.9, STONE_DARK)):
        hoop(math.sqrt(6.4 ** 2 - ((z + 0.4) / 0.92) ** 2) + 0.02, 0.13, (0, 0, z), colour, segments=14)
    tube(3.0, 4.2, (0, -3.6, 0.2), (0, -1, 0), STONE, vertices=10)
    tube(3.25, 0.7, (0, -7.4, 0.2), (0, -1, 0), STONE_PALE, vertices=10)
    tube(2.2, 0.3, (0, -7.95, 0.2), (0, -1, 0), "FFD86B", vertices=10, emission=0.9)
    tube(0.2, 5.0, (0, 0, 5.2), UP, WOOD_DARK, vertices=5)
    mesh([(0, -0.1, 1.1), (0, -0.1, -1.1), (3.4, -0.1, 0), (0, 0.1, 1.1), (0, 0.1, -1.1), (3.4, 0.1, 0)], [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], RED, (0.15, 0, 9.0), smooth=False, tidy=True)


def volcano():
    """The Sun: a small volcano, lava in its crater and down its sides."""
    lathe([(0, 12.0), (2.6, 12.2), (3.6, 13.6), (4.6, 12.8), (6.4, 8.4), (9.2, 3.6), (12.0, 0.4), (12.6, -1.5)], ROCK, segments=10, rough=0.35, smooth=False)
    lathe([(0, 13.0), (3.5, 13.0), (3.5, 12.0)], WATER_LIGHT, segments=10, emission=1.2)
    ball(1.5, (0.6, -0.4, 15.4), WATER_LIGHT, segments=8, emission=1.2)
    ball(0.8, (-1.2, 0.6, 17.4), WATER, segments=6, emission=1.2)
    for degrees, length in ((180, 9.5), (120, 6.5), (250, 7.5), (40, 8.0), (320, 5.5)):  # lava runs down from the rim
        x, y = ring(degrees, 4.5)
        way = Vector((math.sin(math.radians(degrees)) * 0.55, math.cos(math.radians(degrees)) * 0.55, -1))
        tube(1.0, length, (x, y, 13.0), way, WATER, tip=0.35, vertices=5, emission=1.0)


# ---- Worlds 6 to 12: one of the island's two set pieces (island.py), grown to a landmark's size ----
def rift():
    """The Void: a tear in space standing open between two claws of rock, shards hanging round it."""
    glow, pale = "FF3CC8", "FFC2F4"
    jags = (1.0, 0.55, 0.8, 0.5, 0.95, 0.6, 0.75, 0.5, 1.0, 0.55, 0.85, 0.5, 0.9, 0.6)

    def tear(wide, high, depth, colour, turn=0.0, **look):
        upright([(math.sin(index * math.tau / len(jags)) * reach * wide, 6.8 + math.cos(index * math.tau / len(jags)) * reach * high) for index, reach in enumerate(jags)], depth, colour, rotation=(0, 0, turn), **look)

    chunk((4.8, 2.6, 1.2), (0, 0, 0.4), ROCK_DARK)
    tear(3.1, 6.0, 0.5, glow, emission=1.5)
    tear(2.1, 4.7, 0.8, pale, emission=1.8)
    tear(1.05, 3.3, 1.0, "1A0A4A")  # the dark you see through it
    tear(3.0, 5.6, 0.5, glow, math.pi / 2, emission=1.5)  # the tear runs both ways, so that it is a tear from the side too
    tear(2.0, 4.4, 0.8, pale, math.pi / 2, emission=1.8)
    tear(1.0, 3.1, 1.0, "1A0A4A", math.pi / 2)
    for side in (-1, 1):
        bent((side * 3.5, 0.2, 0.2), [(side * 0.35, 0, 1), (-side * 0.05, 0, 1), (-side * 0.5, 0, 1)], 1.5, 3.9, (ROCK, ROCK_LIGHT), taper=0.28, vertices=5)
    for x, y, z, radius, height, lean in ((-4.9, 0.5, 10.4, 0.9, 2.8, (-0.2, 0, 1)), (4.7, -0.4, 11.6, 0.75, 2.2, (0.25, 0, 1)), (0.3, 0.3, 14.4, 0.8, 2.4, (0.05, 0, 1))):
        void_gem(radius, height, (x, y, z), lean, glow)
    for x, y, z in ((-2.7, -0.6, 12.4), (2.6, 0.4, 12.9), (-4.6, -0.5, 6.4), (4.9, 0.3, 7.4)):
        gem(0.35, 1.1, (x, y, z), pale, emission=1.5)


def telescope():
    """Nebula: a fat telescope on a stone pier, aimed at the sky."""
    body, band, aim_at, pivot = "6A4CF0", NEBULA_GOLD, Vector((0, -0.74, 0.67)).normalized(), Vector((0, 0.6, 5.6))
    tube(3.6, 0.7, (0, 0, 0), UP, STONE_DARK, vertices=12)
    tube(1.7, 4.0, (0, 0, 0.7), UP, STONE, tip=1.2, vertices=10)
    for side in (-1, 1):  # the fork it swings in
        box((0.8, 1.7, 3.2), (side * 2.35, 0.6, 5.1), "38B4B8", bevel=0.25, segments=1)
        tube(0.7, 0.5, (side * 2.5, 0.6, 5.6), (side, 0, 0), band, vertices=8, roughness=0.3)
    box((5.4, 1.9, 0.8), (0, 0.6, 3.9), "38B4B8", bevel=0.3, segments=1)
    tube(1.7, 9.2, pivot - aim_at * 3.6, aim_at, body, tip=2.25, vertices=12, roughness=0.3)
    for along, radius in ((-3.5, 1.85), (0.5, 2.12), (5.1, 2.42)):
        tube(radius, 0.6, pivot + aim_at * along, aim_at, band, vertices=12, roughness=0.3)
    tube(2.0, 0.2, pivot + aim_at * 5.65, aim_at, ACCENT, vertices=12, roughness=0.1, emission=1.0)  # the lens
    tube(0.65, 1.5, pivot - aim_at * 5.0, aim_at, "FF7AD0", vertices=8)  # the eyepiece
    tube(0.5, 4.0, pivot + Vector((1.75, 0, 1.3)) - aim_at * 1.5, aim_at, "FF7AD0", vertices=8, roughness=0.3)  # the finder
    nova(1.5, (0.4, -7.6, 13.6))  # the star it is looking at
    nova(0.8, (-3.2, -6.0, 11.4), WHITE)


def geode():
    """The Crystal Belt: a giant geode split open, its hollow full of glowing crystals, loose ones beside it."""
    chunk((3.6, 2.8, 1.7), (0, 2.2, 0.8), ROCK_DARK)
    first = len(made)
    lathe([(0, -3.2), (2.8, -1.9), (3.8, 0.6), (4.3, 0.9), (4.7, 0.2), (4.0, -2.9), (0, -4.6)], ROCK, segments=10, rough=0.2, smooth=False)
    lathe([(0, -3.0), (2.7, -1.75), (3.9, 0.75)], "ECD8FF", segments=10, roughness=0.3)  # its pale lining
    hoop(4.45, 0.42, (0, 0, 0.72), "FFFFFF", segments=10)  # the cut edge: a white crust all round the hollow
    prism(1.5, 7.8, (0, 0, -3.0), UP, LEAVES[0], roughness=0.12, emission=0.7)
    for index in range(6):
        x, y = ring(index * 60 + 15, 2.2)
        prism(1.0, 4.6 + (index % 2) * 1.1, (x, y, -2.2), (x * 0.2, y * 0.2, 1), LEAVES[(index + 1) % 3], roughness=0.12, emission=0.7)
    for degrees, colour in ((95, LEAVES[1]), (180, LEAVES[2]), (265, LEAVES[0])):  # and three that broke through its back
        x, y = ring(degrees, 4.2)
        prism(0.6, 2.4, (x, y, -1.6), (x, y, -0.6), colour, roughness=0.12)
    moved(first, Matrix.Translation((0, 0.6, 4.25)) @ Matrix.Rotation(math.radians(32), 4, "X"))
    for x, y, radius, length, lean, colour in ((4.5, -2.8, 0.9, 3.6, (0.3, -0.2, 1), LEAVES[1]), (5.2, -1.5, 0.6, 2.3, (-0.2, 0.3, 1), LEAVES[2]), (-4.7, -2.4, 0.75, 2.9, (-0.35, -0.1, 1), LEAVES[0])):
        prism(radius, length, (x, y, -0.2), lean, colour, roughness=0.12)


def robot_arm():
    """The Robot Factory: a robot arm on a base in hazard stripes, a glowing power cell in its claw."""
    yellow, orange, steel = "FFC21A", "FF6A2A", T["stone"]
    tube(3.7, 0.8, (0, 0, 0), UP, NAVY, vertices=12)
    for index in range(0, 12, 2):
        x, y = ring(index * 30, 3.6)
        box((1.7, 0.3, 0.62), (x, y, 0.42), yellow, bevel=0.06, rotation=(0, 0, -math.radians(index * 30)), segments=1)
    tube(2.5, 1.6, (0, 0, 0.8), UP, yellow, tip=2.0, vertices=10, roughness=0.35)
    shoulder, elbow, wrist = Vector((0, 0.8, 3.4)), Vector((0, 0.2, 10.2)), Vector((0, -4.3, 8.4))
    ball(1.7, shoulder, NAVY, segments=10)
    tube(1.25, (elbow - shoulder).length, shoulder, elbow - shoulder, orange, vertices=8, roughness=0.35)
    ball(1.5, elbow, NAVY, segments=10)
    tube(1.0, (wrist - elbow).length, elbow, wrist - elbow, yellow, vertices=8, roughness=0.35)
    ball(1.2, wrist, NAVY, segments=8)
    for joint, reach in ((shoulder, 1.65), (elbow, 1.45)):
        for side in (-1, 1):
            tube(0.6, 0.35, joint + Vector((side * reach, 0, 0)), (side, 0, 0), GOLD, vertices=8, roughness=0.3)
    piston = shoulder + Vector((0, -1.3, 0.2))
    tube(0.3, (elbow - piston).length * 0.6, piston, shoulder + (elbow - shoulder) * 0.62 - piston, steel, vertices=6, roughness=0.3)
    tube(0.6, 1.3, wrist, (0, 0, -1), steel, vertices=8)
    box((3.7, 1.1, 0.7), wrist + Vector((0, 0, -1.5)), orange, bevel=0.2, segments=1)
    for side in (-1, 1):
        box((0.65, 1.1, 2.3), wrist + Vector((side * 1.6, 0, -2.7)), orange, bevel=0.2, rotation=(0, side * 0.12, 0), segments=1)
    cell = wrist + Vector((0, 0, -3.3))
    box((2.5, 2.5, 2.5), cell, ACCENT, bevel=0.4, emission=0.9)
    for z in (-0.8, 0.8):
        box((2.68, 2.68, 0.36), cell + Vector((0, 0, z)), NAVY, bevel=0.08, segments=1)
    tube(0.16, 1.5, (1.5, 1.3, 2.3), UP, steel, vertices=5)  # a warning light
    ball(0.5, (1.5, 1.3, 4.0), RED, segments=6, emission=1.3)


def snap_pod():
    """The Alien Jungle: a giant snapping plant on a thick stalk in a rosette of leaves, its jaws open."""
    green, red, tooth, hinge = "5CE07A", "E13C5A", "FFF3C8", Vector((0, 3.0, 0))
    for index in range(6):
        turn = math.radians(index * 60 + 15)
        ball(3.3, (math.cos(turn) * 2.8, math.sin(turn) * 2.8, 0.55), WOOD_LIGHT if index % 2 else "8A5CD8", scale=(1, 0.42, 0.16), rotation=(0, -0.22, turn), segments=8)
    bent((0, 1.6, -0.3), [(0, 0.1, 1), (0, -0.1, 1), (0, -0.1, 1), (0, -0.3, 1)], 1.5, 2.3, (green, shade(green, -0.15)), taper=0.08, glow=WATER)
    middle = Vector((0, -0.7, 10.0))

    def jaw(frame, upper):
        first = len(made)
        lathe([(0, 1.6), (1.9, 1.3), (2.9, 0.4), (3.05, 0), (0, 0)], red, segments=12, stretch=1.2, roughness=0.4)
        tube(2.6, 0.14, (0, 0, -0.12), UP, "FF8AC0", vertices=12)
        for index in range(-4, 5):
            turn = math.radians(index * 22)
            tube(0.34, 1.0, (math.sin(turn) * 2.7, -math.cos(turn) * 2.7 * 1.2, 0.05), (0, 0, -1), tooth, tip=0.0, vertices=5)
        for degrees, share in ((0, 0.25), (140, 0.5), (220, 0.5), (60, 0.6), (300, 0.6)) if upper else ():
            x, y = ring(degrees, 3.0 * share)
            ball(0.5, (x, y * 1.2, 1.6 * (1 - 0.7 * share * share) + 0.02), "FFE23A", scale=(1, 1, 0.4), segments=6)
        moved(first, frame)

    swing = Matrix.Translation(middle + hinge) @ Matrix.Scale(1.2, 4)
    jaw(swing @ Matrix.Rotation(-0.5, 4, "X") @ Matrix.Translation(-hinge), True)
    jaw(swing @ Matrix.Rotation(0.28, 4, "X") @ Matrix.Translation(-hinge) @ Matrix.Rotation(math.pi, 4, "Y"), False)
    ball(1.0, middle + Vector((0, 0.8, 0.5)), WATER, segments=8, emission=1.3)  # its throat glows
    ball(1.0, middle + Vector((0, -1.9, 0.1)), "FF8AC0", scale=(0.8, 1.9, 0.3), segments=8)  # its tongue
    for side in (-1, 1):  # two feelers with a light on each
        end = bent((side * 2.2, 1.2, 0), [(side * 0.5, 0, 1), (side * 0.9, -0.1, 1), (side * 0.4, -0.3, 1)], 0.6, 2.2, (WOOD_LIGHT,), taper=0.2, vertices=6)
        ball(0.8, end, LEAVES[2], segments=6, emission=1.3)


def black_hole():
    """The Black Hole: one in miniature. A dark ball in a tilted ring of fire, the light behind it bent into
    a halo, held in three claws of rock."""
    orange, hot, pink = "FF7A1E", "FFE08A", "FF3C8C"
    middle = Vector((0, 0, 8.2))
    tube(3.8, 0.7, (0, 0, 0), UP, T["stone_dark"], vertices=9)
    for index in range(3):
        x, y = ring(index * 120 + 60, 2.6)
        out = Vector((x, y, 0)).normalized()
        bent((x, y, 0.4), [out * 0.55 + Vector(UP), out * 0.1 + Vector(UP), -out * 0.5 + Vector(UP)], 1.2, 2.0, (ROCK, ROCK_LIGHT), taper=0.25, vertices=6, glow=orange)
    ball(2.5, middle, HOLE, segments=14, roughness=0.25)
    hoop(2.75, 0.24, middle, pink, rotation=(math.pi / 2, 0, 0), segments=18, emission=1.6)
    first = len(made)
    lathe([(3.0, -0.14), (3.0, 0.14), (5.1, 0.08), (5.1, -0.08), (3.0, -0.14)], orange, segments=24, emission=1.5)
    lathe([(2.72, -0.2), (2.72, 0.2), (3.5, 0.17), (3.5, -0.17), (2.72, -0.2)], hot, segments=24, emission=1.8)
    for degrees, distance in ((30, 4.3), (150, 4.6), (265, 4.1)):  # rock on its way in
        x, y = ring(degrees, distance)
        chunk((0.55, 0.5, 0.45), (x, y, 0.35), ROCK_LIGHT, detail=1)
    moved(first, Matrix.Translation(middle) @ Matrix.Rotation(0.38, 4, "X") @ Matrix.Rotation(0.15, 4, "Y"))


def bang():
    """The Big Bang: the bang itself, stopped an instant after. A white-hot spark on a gold stand, fat rays
    of light bursting out of it in every direction, pieces of what it was flying off between them, and two
    shock rings running out."""
    middle = Vector((0, 0, 8.0))
    tube(3.4, 0.7, (0, 0, 0), UP, T["stone_dark"], vertices=12)
    tube(2.4, 0.6, (0, 0, 0.7), UP, WOOD_LIGHT, vertices=12, roughness=0.3)
    tube(1.0, 4.6, (0, 0, 1.3), UP, WOOD, tip=0.55, vertices=8, roughness=0.3)
    ball(2.5, middle, "FFE680", segments=12, emission=1.0)
    rays = ((0, 0.1), (60, 0.7), (120, 0.0), (180, 0.75), (240, 0.1), (300, 0.7), (30, -0.55), (150, -0.5), (270, -0.55), (90, 3.0))
    for index, (degrees, rise) in enumerate(rays):  # the rays: fat at the spark, a point far out
        x, y = ring(degrees, 1.0)
        out = Vector((x, y, rise)).normalized()
        tube(1.15, 5.4 if rise >= 0 else 3.6, middle + out * 1.6, out, "FFC61A" if index % 2 == 0 else "FF7A1E", tip=0.0, vertices=5, emission=0.35)
    for index, (degrees, rise, far, size) in enumerate(((30, 0.5, 6.4, 1.0), (92, -0.1, 6.9, 0.8), (150, 0.45, 6.6, 1.05), (212, -0.15, 6.8, 0.85), (268, 0.5, 6.4, 1.0), (332, -0.1, 7.0, 0.8), (200, 1.9, 6.2, 0.9), (20, 1.7, 6.4, 0.8))):
        x, y = ring(degrees, 1.0)
        out = Vector((x, y, rise)).normalized()
        gem(0.95 * size, 3.4 * size, middle + out * far, LEAVES[index % 3], out, roughness=0.25)  # what it threw out
    hoop(4.6, 0.36, middle, WHITE, rotation=(0.3, 0.12, 0), segments=24, emission=1.4)
    hoop(6.6, 0.24, middle, "FF7AD0", rotation=(0.3, 0.12, 0), segments=28, emission=1.2)


def grown(build, size):
    """A set piece of the island's, `size` times as big: a landmark has to show from across the plot."""
    def bigger():
        first = len(made)
        build()
        moved(first, Matrix.Scale(size, 4))
    return bigger


LANDMARK = {"windmill": windmill, "rocket": rocket, "arch": arch, "igloo": igloo, "volcano": volcano,
            "rift": grown(rift, 1.35), "telescope": grown(telescope, 1.45), "geode": grown(geode, 1.8), "robot_arm": grown(robot_arm, 1.55),
            "snap_pod": grown(snap_pod, 1.45), "black_hole": grown(black_hole, 1.6), "bang": grown(bang, 1.3)}[LOOK["landmark"]]


# ---------------------------------------------------------------------------------------------------
# The hills round the plot and the rock behind the portal: the plot's horizon. All of it stands outside the
# ground, where the game has its solid skyline.
# ---------------------------------------------------------------------------------------------------
hills = []  # (x, z, across, along, height)
BUN = ((0.0, 1.0), (0.3, 0.97), (0.55, 0.86), (0.76, 0.64), (0.9, 0.36), (1.0, 0.0))  # a hill's cut: (share of its radius, share of its height)


def hill(x, z, across, along, height, colour, segments=16):
    """A round hill, `across` wide (its radius along x) and `along` deep (along z)."""
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
    """A blunt rock with a cap of the world's ground, like the island's floating rocks."""
    lathe([(0, height), (radius * 0.5, height * 0.985), (radius * 0.74, height * 0.84), (radius * 0.9, height * 0.45), (radius, 0), (radius * 1.02, -1.5)],
          colour, segments=segments, rough=radius * 0.05, smooth=False, stretch=stretch)
    if cap:
        ball(radius * 0.66, (0, 0, height - 0.7), cap, scale=(1, stretch, 0.3), segments=12, roughness=0.9)
        ball(radius * 0.4, (radius * 0.2, radius * 0.12, height + 0.1), shade(cap, 0.12), scale=(1, stretch, 0.34), segments=10, roughness=0.9)


def waterfall(fall, pool, reach):
    """The world's liquid coming out from under a butte's cap, down its front and into a small pool at its
    foot. `fall` is its path as (forward of the butte's middle, height) points, `pool` the pool's radius,
    `reach` how far forward of the butte's middle the pool lies."""
    for index in range(7):  # stones round the pool
        x, y = ring(index * 38 + 66, pool + 0.5)
        chunk((rng.uniform(0.7, 1.0), rng.uniform(0.7, 0.95), rng.uniform(0.55, 0.8)), (x, -reach + y, 0.3), rng.choice((ROCK, ROCK_LIGHT, ROCK_DARK)), detail=1)
    if T["liquid"] in ("water", "oasis"):
        for x, z, radius in ((-0.9, 0.5, 0.8), (0.3, 0.7, 0.95), (1.1, 0.4, 0.7)):  # foam where it lands
            ball(radius, (x, -fall[-1][0] - 0.3, z), WHITE, segments=8)
    wet = dict(roughness=0.15, emission=LIQUID_GLOW.get(T["liquid"], 0.9)) if GLOWS else dict(roughness=0.15)
    with into("Water"):
        ribbon(fall, 3.6, WATER, lift=0.7, **wet)
        for shift, width, skip in ((-0.9, 0.7, 1), (0.8, 0.5, 2)):  # lighter streaks down the fall
            ribbon(fall[skip:], width, WATER_LIGHT, thickness=0.3, shift=shift, lift=0.9, **wet)
        tube(pool, 0.4, (0, -reach, -0.1), UP, WATER, vertices=16, **wet)
        tube(pool * 0.58, 0.4, (0.25, -reach + 0.2, -0.06), UP, shade(WATER, 0.25), vertices=12, **wet)
        if T["liquid"] == "prism":  # cut like a gem: the fall splits into colours
            for shift, colour, skip in ((-1.45, PETALS[0], 2), (1.4, PETALS[2], 1), (-0.2, PETALS[3], 3)):
                ribbon(fall[skip:], 0.4, colour, thickness=0.3, shift=shift, lift=0.9, roughness=0.15)
    if NEW:
        liquid_dressing(fall, pool, reach)


def liquid_dressing(fall, pool, reach):
    """Worlds 6 to 12: what island.py's pond has on it, at the waterfall: at its top (where it comes out from
    under the butte's cap), down its sides and round its pool. In the waterfall's own space, front -Y."""
    liquid = T["liquid"]
    out, top = fall[0]
    foot = Vector((0, -reach, 0))
    if liquid == "rift":  # shards of rock hanging over the tear, and the dark in the middle of it
        for x, y, z, radius, height, lean in ((-2.9, 0.6, 3.4, 0.9, 3.2, (0.2, 0, 1)), (2.8, 0.2, 4.4, 0.75, 2.6, (-0.15, 0.1, 1)), (0.3, -2.6, 2.6, 0.6, 2.0, (0, -0.1, 1))):
            void_gem(radius, height, foot + Vector((x, y, z)), lean, WATER_LIGHT)
        for x, z in ((-2.9, top - 6.5), (2.8, top - 11.0), (-2.6, top - 16.0)):  # and beside the fall
            void_gem(0.8, 2.8, (x, -fall[3][0] - 1.4, z), UP, WATER_LIGHT)
        tube(pool * 0.5, 0.1, foot + Vector((0.25, 0.2, 0.3)), UP, "1A0A4A", vertices=7)
    elif liquid == "gas":  # puffs where it lands and drifting off the fall
        for x, y, z, size, colour in ((-1.6, -0.4, 0.9, 1.5, "C8FFF8"), (1.5, -0.6, 0.8, 1.3, WHITE), (0.1, -1.6, 0.6, 1.1, LEAVES[0]), (-2.6, 2.0, top - 8.0, 1.2, LEAVES[2]), (2.7, 2.4, top - 14.0, 1.0, "C8FFF8")):
            ball(size, foot + Vector((x, y, z)), colour, scale=(1, 1, 0.8), segments=10, roughness=1.0)
        nova(1.1, foot + Vector((0.2, 0.6, 3.6)))
    elif liquid == "prism":  # crystals growing out of it
        for x, y, radius, length, lean, colour in ((-2.4, 0.9, 1.0, 6.0, (-0.15, 0.05, 1), LEAVES[0]), (-3.2, -0.3, 0.7, 3.6, (-0.5, -0.1, 1), LEAVES[1]), (2.5, 0.8, 0.9, 5.0, (0.2, 0.1, 1), LEAVES[2]), (3.2, -0.5, 0.6, 3.0, (0.5, -0.15, 1), LEAVES[1])):
            prism(radius, length, foot + Vector((x, y, 0)), lean, colour, roughness=0.12)
        for x, radius, length in ((-1.4, 0.5, 3.0), (0.1, 0.4, 2.2), (1.3, 0.55, 3.4)):  # frozen: icicles where it tips over
            tube(radius, length, (x, -out - 2.1, top - 1.0), (0, 0, -1), WATER_LIGHT, tip=0.0, vertices=5, roughness=0.15)
    elif liquid == "coolant":  # the pipe it runs out of, and bubbles in the pool
        tube(2.3, 4.6, (0, -out + 2.6, top + 0.6), (0, -1, -0.1), WOOD, vertices=10, roughness=0.35)
        hoop(2.4, 0.4, (0, -out - 1.7, top + 0.15), "FFC21A", rotation=(math.pi / 2 - 0.1, 0, 0), segments=10)
        hoop(2.4, 0.4, (0, -out + 1.2, top + 0.45), NAVY, rotation=(math.pi / 2 - 0.1, 0, 0), segments=10)
        for x, y, size in ((-0.8, 0.3, 0.5), (0.7, -0.5, 0.4), (0.2, 0.8, 0.3)):
            ball(size, foot + Vector((x, y, 0.4)), WATER_LIGHT, segments=6, emission=1.4)
    elif liquid == "acid":  # bubbles, in the pool and up the fall
        for x, y, z, size in ((-0.9, 0.2, 0.5, 0.7), (0.8, -0.5, 0.45, 0.5), (0.1, 0.9, 0.4, 0.4), (-2.3, 1.2, 3.0, 0.6), (2.2, 1.4, 5.5, 0.5), (-2.0, 1.8, 8.5, 0.4)):
            ball(size, foot + Vector((x, y, z)), "5CF0E0" if size < 0.5 else WATER_LIGHT, segments=6, emission=1.4)
    elif liquid == "singularity":  # the dark it all falls into, and the last light round it
        tube(pool * 0.62, 0.1, foot + Vector((0, 0, 0.3)), UP, HOLE, vertices=16, roughness=0.3)
        hoop(pool * 0.7, 0.16, foot + Vector((0, 0, 0.42)), WATER_LIGHT, segments=16, emission=1.7)
        hoop(pool * 1.9, 0.14, foot + Vector((0, 0, 2.2)), LEAVES[1], rotation=(0.3, 0.15, 0), segments=18, emission=1.4)
    else:  # energy: rings running out over it, sparks standing over it
        for radius, z in ((pool * 0.5, 0.36), (pool * 1.5, 1.6), (pool * 2.0, 3.0)):
            hoop(radius, 0.14, foot + Vector((0, 0, z)), WHITE, segments=18, emission=1.6)
        for x, y, z, size in ((-2.6, 0.6, 3.0, 0.8), (2.5, 0.3, 4.2, 0.7), (0.2, -2.4, 2.2, 0.6)):
            gem(size, size * 3.2, foot + Vector((x, y, z)), LEAVES[int(z * 10) % 3], roughness=0.25)


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
    foot, plate_colour = ("200C54", "D2C8FF") if WORLD == "The Void" else (STONE_DARK, STONE_PALE)  # The Void: violet stone on violet ground vanished, so the road's dark and a pale plate
    tile(PAD_SIZE, PAD_SIZE, 0.9, 0.0, 0.32, foot, lip=0.1)
    tile(6.3, 6.3, 0.7, 0.28, PAD_HEIGHT - 0.04, plate_colour, lip=0.07)
    for x in (-1, 1):
        for y in (-1, 1):
            tile(1.5, 1.5, 0.45, 0.2, PAD_HEIGHT, GOLD, lip=0.07, location=(x * 2.75, y * 2.75, 0), roughness=0.3)
    with part("PadTrim"):
        inlay(rounded(6.0, 6.0, 0.5), rounded(4.9, 4.9, 0.3), PAD_HEIGHT - 0.03, tint)


def teleporter(tint=WHITE):
    """A walk-on teleporter: a low round dais (the game's ring is TELEPORTER_RING across it) under a slim
    stone arch. The game's beam (TELEPORTER_BEAM wide, 0.4 to 8.4 up) stands in the arch. TeleporterTrim
    is what the game tints: the ring and the disc on the dais, the orb in the arch's crown (where the
    game's own orb floats) and a gem on each leg. Its title floats over it: nothing here is higher than 11.3."""
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
    with part("TeleporterTrim"):
        lathe([(2.25, 0.42), (2.32, 0.47), (2.88, 0.47), (2.95, 0.42)], tint, segments=24, emission=0.9)
        lathe([(0, 0.47), (TELEPORTER_BEAM, 0.47), (TELEPORTER_BEAM + 0.08, 0.42)], tint, segments=20, emission=0.9)
        ball(0.95, (0, 0, crown + reach), tint, segments=12, emission=1.2)
        for side in (-1, 1):
            for front in (-1, 1):
                tube(0.5, 0.45, (side * reach, front * 0.78, 3.6), (0, front, 0), tint, tip=0.0, vertices=4, emission=0.9)


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


# The towers' roofs, one shape a world: a cut for `lathe` from the tip down to the parapet (17.7), how many
# sides it has and whether it is faceted.
ROOFS = {
    "cone": ([(0, 26.2), (0.95, 24.0), (2.1, 21.4), (3.25, 19.2), (3.9, 18.1), (3.7, 17.7), (0, 17.7)], 16, True),
    "dome": ([(0, 24.6), (1.5, 24.2), (2.9, 23.0), (3.8, 21.3), (4.15, 19.6), (3.95, 18.3), (3.7, 17.7), (0, 17.7)], 16, True),
    "pagoda": ([(0, 26.0), (0.9, 24.2), (2.0, 22.6), (3.3, 21.7), (2.4, 21.3), (2.9, 19.8), (4.6, 18.2), (3.7, 17.7), (0, 17.7)], 12, True),
    "spire": ([(0, 29.0), (1.5, 24.0), (3.0, 20.4), (4.1, 18.2), (3.7, 17.7), (0, 17.7)], 6, False),
    "flame": ([(0, 28.0), (0.6, 26.4), (1.7, 24.6), (3.2, 22.4), (4.2, 20.2), (4.1, 18.7), (3.6, 17.7), (0, 17.7)], 12, True),
    # worlds 6 to 12
    "shard": ([(0, 30.0), (1.3, 25.4), (3.3, 20.6), (4.3, 18.6), (3.7, 17.7), (0, 17.7)], 5, False),  # The Void: a five-sided splinter
    "onion": ([(0, 26.6), (0.5, 25.4), (1.3, 24.2), (3.0, 23.0), (4.3, 21.4), (4.6, 19.8), (4.1, 18.4), (3.7, 17.7), (0, 17.7)], 16, True),  # Nebula: a puff drawn to a point
    "prism": ([(0, 29.4), (3.3, 24.6), (4.3, 19.2), (3.7, 17.7), (0, 17.7)], 6, False),  # Crystal Belt: a cut crystal
    "tank": ([(0, 24.4), (1.7, 24.4), (1.7, 22.6), (2.3, 22.6), (2.5, 22.0), (4.1, 20.2), (4.3, 18.4), (3.7, 17.7), (0, 17.7)], 12, False),  # Robot Factory: a boiler's lid and its chimney
    "cap": ([(0, 25.2), (2.3, 24.6), (4.3, 22.9), (5.4, 20.6), (5.1, 19.7), (3.5, 19.2), (3.5, 17.7), (0, 17.7)], 14, True),  # Alien Jungle: a mushroom's cap over the parapet
    "claw": ([(0, 29.0), (0.9, 26.2), (1.5, 23.6), (2.9, 21.2), (4.3, 19.4), (4.2, 18.4), (3.7, 17.7), (0, 17.7)], 5, False),  # Black Hole: rock pulled to a point
    "burst": ([(0, 28.4), (1.0, 24.6), (2.3, 22.2), (4.7, 20.2), (3.1, 18.9), (3.7, 17.7), (0, 17.7)], 8, False),  # The Big Bang: a spark's point over a ring of them
}


def knob(x, y, z):
    """What tops a post of the base's wall, one kind a world."""
    kind = LOOK["knob"]
    if kind == "ball":
        ball(0.7, (x, y, z + 0.4), GOLD, segments=8, roughness=0.3)
    elif kind == "bulb":
        tube(0.5, 0.3, (x, y, z - 0.25), UP, IRON, vertices=6)
        ball(0.75, (x, y, z + 0.5), ACCENT, segments=8, emission=0.9)
    elif kind == "pyramid":
        tube(1.2, 1.5, (x, y, z - 0.3), UP, GOLD, tip=0.0, vertices=4, roughness=0.3)
    elif kind == "crystal":
        tube(0.75, 2.2, (x, y, z - 0.3), UP, LEAVES[2], tip=0.0, vertices=5, smooth=False, roughness=0.2)
    # worlds 6 to 12: what tops their fence's posts
    elif kind == "gem":  # The Void: a gem of light floating over the post
        gem(0.7, 2.0, (x, y, z + 1.2), ACCENT, emission=1.4)
    elif kind == "nova":  # Nebula: a star
        tube(0.3, 0.7, (x, y, z - 0.2), UP, IRON, vertices=5)
        nova(1.0, (x, y, z + 1.2))
    elif kind == "prism":  # Crystal Belt: a cut crystal
        prism(0.8, 2.6, (x, y, z - 0.3), UP, LEAVES[round(abs(x)) % 3], roughness=0.12)
    elif kind == "bolt":  # Robot Factory: a cap in hazard yellow with a green light
        tube(1.0, 0.5, (x, y, z - 0.25), UP, "FFC21A", vertices=6, roughness=0.4)
        ball(0.62, (x, y, z + 0.55), ACCENT, segments=6, emission=1.3)
    elif kind == "pod":  # Alien Jungle: a glowing pod
        gem(0.85, 2.0, (x, y, z + 0.5), ACCENT, sides=5, emission=1.2)
    elif kind == "orbit":  # Black Hole: a dark ball in a ring of fire
        ball(0.75, (x, y, z + 0.6), HOLE, segments=6, roughness=0.3)
        tube(1.4, 0.14, (x, y, z + 0.53), (0.35, 0.3, 1), ACCENT, vertices=8, emission=1.4)
    elif kind == "spark":  # The Big Bang: a spark
        gem(0.8, 2.2, (x, y, z + 0.6), T["accent"], emission=1.2)
    else:  # ember
        ball(0.8, (x, y, z + 0.45), ACCENT, scale=(1, 1, 1.2), segments=8, emission=1.0)


def gate(tint=OWNER):
    """The base's gatehouse, the piece the monsters come for: two round towers with the world's roofs and
    banners, a round arch between them with a portcullis drawn up and its door standing open to the road,
    the owner's name over it on both sides, a crest on top, and a wall with battlements out to each fence.
    Its origin is the middle of the gate on the ground; its front (-Y) is the side the monsters see.
    The game's solid parts are where its own are: the towers (TOWER_RADIUS, TOWER_TOP high) and the walls
    (WALL_THICK thick, WALL_HEIGHT high). The arch is GATE_WIDTH wide and GATE_HEIGHT high in the middle.
    GateTrim is everything in the owner's colour: the roofs, the flags, the banners, the crest and the
    disc of the arrival pad (10 studs behind the gate, like the game's)."""
    spring = GATE_HEIGHT / 2  # the arch: half a circle, GATE_WIDTH across
    roof, sides, smooth = ROOFS[LOOK["roof"]]
    tip = roof[0][1]
    window = LOOK["window"]
    lit = dict(emission=0.9) if window != INK else {}
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
            if LOOK["roof"] == "spire":  # icicles under the parapet
                a, b = ring(index * 45, 4.15)
                tube(0.34, 1.5 + 0.5 * (index % 2), (x + a, b, 16.65), (0, 0, -1), WATER_LIGHT, tip=0.0, vertices=5, roughness=0.2)
        for degrees, z in ((38, 3.6), (-52, 5.4), (128, 4.2), (-140, 6.6), (64, 11.6), (-118, 12.6), (150, 12.0), (-30, 13.2)):  # stones that stand out of the wall
            a, b = ring(degrees, 3.42)
            slab((1.7, 0.5, 0.85), (x + a, b, z), STONE_DARK if z < 9 else STONE, rotation=(0, 0, -math.radians(degrees)))
        for front in (-1, 1):  # a window to the road and one to the yard
            box((2.0, 0.6, 3.2), (x, front * 3.3, 5.6), STONE_DARK, bevel=0.25, segments=1)
            box((1.2, 0.5, 2.0), (x, front * 3.48, 5.35), window, bevel=0.1, segments=1, **lit)
            tube(0.6, 0.5, (x, front * 3.23, 6.35), (0, front, 0), window, vertices=10, **lit)
            tube(0.14, 3.2, (x - 1.6, front * 3.95, 14.2), (1, 0, 0), GOLD, vertices=6, roughness=0.3)  # the banner's rod
            for end in (-1, 1):
                ball(0.3, (x + end * 1.6, front * 3.95, 14.2), GOLD, segments=6, roughness=0.3)
            star(0.72, (x, front * 4.02, 12.5), GOLD, depth=0.16, roughness=0.3)
        tube(0.16, 4.2, (x, 0, tip - 0.2), UP, IRON, vertices=5)
        ball(0.5, (x, 0, tip), GOLD, segments=8, roughness=0.3)
        ball(0.3, (x, 0, tip + 4.1), GOLD, segments=6, roughness=0.3)
        with part("GateTrim"):
            lathe(roof, tint, segments=sides, smooth=smooth, location=(x, 0, 0))
            for front in (-1, 1):
                banner(2.7, 5.0, tint, (x, front * 3.9, 14.2), back=front > 0)
            # The flag: a pennant that flies away from the gate.
            mesh([(0, -0.1, 0.95), (0, -0.1, -0.95), (3.2, -0.1, 0), (0, 0.1, 0.95), (0, 0.1, -0.95), (3.2, 0.1, 0)], [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)],
                 tint, (x + side * 0.16, 0, tip + 2.9), (0, 0, 0 if side > 0 else math.pi), smooth=False, tidy=True, roughness=0.8)
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
    with part("GateTrim"):
        tube(2.0, 0.44, (0, 0.22, 21.8), (0, -1, 0), tint, vertices=18)
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
            knob(side * x, 0, 5.9)
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
    with part("GateTrim"):
        lathe([(0, 0.2), (ARRIVAL_RADIUS, 0.2), (ARRIVAL_RADIUS, 0.14)], tint, segments=28, location=(0, behind, 0), emission=0.5)


def portal():
    """The monsters' portal: an arch of dark stone made into a face, with horns, two angry eyes and fangs in
    its mouth. Its origin is the middle of the sheet on the ground (the game's own spot), its front (-Y) looks
    down the road at the gate. The mouth is 14.5 wide and 16.5 high in the middle: the game's sheet is 14 by 15.
    PortalSheet is everything that glows, for Neon: the sheet with its dark whirl, the eyes, the runes."""
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
        tube(0.66, 1.9, (math.cos(angle) * inner, -1.0, crown + math.sin(angle) * inner), (-math.cos(angle), 0, -math.sin(angle)), BONE, tip=0.0, vertices=8, roughness=0.3)
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
    with part("PortalSheet"):
        slab((14.6, 0.36, crown), (0, 0, crown / 2), HOT, emission=1.0)
        tube(7.3, 0.4, (0, 0.2, crown), (0, -1, 0), HOT, vertices=28, emission=1.0)
        for radius, depth, x, z, colour in ((5.7, 0.5, 0.0, 8.5, HOT_DARK), (4.3, 0.6, 0.45, 8.9, HOT_DEEP), (2.9, 0.7, -0.2, 9.1, HOT_CORE), (1.5, 0.8, 0.2, 8.9, shade(HOT_CORE, -0.5))):  # the whirl: darker towards its middle
            tube(radius, depth, (x, depth / 2, z), (0, -1, 0), colour, vertices=20, emission=0.6)
        for x, z, radius in ((-4.6, 4.0, 0.5), (4.9, 12.0, 0.42), (-3.4, 13.4, 0.36), (4.2, 3.0, 0.3), (-5.3, 9.6, 0.3)):  # sparks
            tube(radius, 0.6, (x, 0.3, z), (0, -1, 0), shade(HOT, 0.6), vertices=8, emission=1.4)
        for side in (-1, 1):
            ball(1.3, (side * 3.95, -2.1, 17.6), "FFE45C", scale=(1, 0.36, 1.08), segments=14, emission=1.2)  # an eye
            for z in (4.2, 6.6):  # runes on the legs
                box((0.6, 0.3, 1.5), (side * reach, -2.0, z), HOT, bevel=0.1, segments=1, emission=1.2)
        tube(0.75, 0.6, (0, -2.25, crown + reach - 0.3), (0, -1, 0), HOT, tip=0.0, vertices=4, emission=1.2)  # a gem on its brow


# ---------------------------------------------------------------------------------------------------
# Stand-ins for the photos: a tower, a monster, the words on the signs
# ---------------------------------------------------------------------------------------------------
def stand_in_tower(colour=RED):
    """The game's rank 1 cannon in rough: a wooden plinth, a carriage with wheels, a fat barrel."""
    tube(2.5, 1.0, (0, 0, 0), UP, "B9783F", vertices=16)
    box((2.2, 3.0, 0.9), (0, 0.3, 1.65), "8A5A2B", bevel=0.2, segments=1)
    for side in (-1, 1):
        tube(1.15, 0.5, (side * 1.15, 0.4, 2.15), (side, 0, 0), "4A4763", vertices=12)
    aim_at, back = Vector((0, -math.cos(math.radians(12)), math.sin(math.radians(12)))), Vector((0, 1.7, 2.55))
    tube(0.8, 4.2, back, aim_at, colour, vertices=12, roughness=0.35)
    ball(0.88, back, shade(colour, -0.3), segments=10, roughness=0.35)
    tube(1.0, 0.5, back + aim_at * 3.8, aim_at, shade(colour, -0.3), vertices=12, roughness=0.35)
    tube(0.55, 0.06, back + aim_at * 4.3, aim_at, INK, vertices=10)
    tube(0.98, 0.3, back + aim_at * 2.6, aim_at, WHITE, vertices=12)


def stand_in_monster(colour="5FD35A", eye="FFE23A"):
    """A monster in rough: a rounded cube with two big glossy eyes. About 2.4 tall."""
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
    obj.matrix_basis = Matrix.Translation(at(*spot)) @ Matrix.Rotation(math.radians(face + 180), 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X")
    bpy.context.scene.collection.objects.link(obj)


# ---------------------------------------------------------------------------------------------------
# The markers: where the plot's origin is and which way the portal lies. In the export, not in the photos.
# ---------------------------------------------------------------------------------------------------
with into("Origin"):
    slab((2, 2, 2), at(0, 0, 1), "FF00FF").hide_render = True
with into("North"):
    slab((2, 2, 2), at(0, 10, 1), "00FFFF").hide_render = True

# ---------------------------------------------------------------------------------------------------
# The ground: a floating island like the world's own, but rounded-square. It is level (y = 0) over the
# whole of the game's ground and well past it; the hills stand on the band outside.
# ---------------------------------------------------------------------------------------------------
HALF_X, HALF_Z, MIDDLE_Z, SQUARE = 91.0, 118.0, 73.0, 6  # the island reaches x +-91 and z -45 ... 191
FLAT = 0.955  # the share of the way to the edge that the ground stays level


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
    return -x, MIDDLE_Z + y * HALF_Z / HALF_X


R = HALF_X
LOBES = 22


def drips(degrees):
    return -9.0 - 5.5 * abs(math.sin(math.radians(degrees) * LOBES / 2)) ** 0.7


def wave(depth, swing, count, phase=0.0):
    return lambda degrees: depth + swing * math.sin(math.radians(degrees) * count + phase)


def spike(radius, depth, colour=UNDER):
    lathe([(0, 2.0), (radius, 0.0), (radius * 0.72, -depth * 0.4), (radius * 0.34, -depth * 0.78), (0, -depth)], colour, segments=7, rough=radius * 0.1, smooth=False)


use("Ground")
# (The ground ends under the darker rim of the Cliff group, and has as many corners round its edge: nothing of it pokes through.)
island([(0, 0.0), (R * FLAT, 0.0), (R * 0.966, top(0.966)), (R * 0.972, top(0.972) - 2.0), (R * 0.972, -6.0), (0, -6.0)], GRASS, LOBES * 4, roughness=0.9)
# A few big lighter and darker patches, lying flat in the ground, so it is not one flat colour. (x, z, radius, colour)
for x, z, radius, colour in ((30, 21, 13, GRASS_LIGHT), (-33, 23, 11, GRASS_DEEP), (46, 50, 9, GRASS_LIGHT), (-16, 83, 12, GRASS_DEEP), (-47, 83, 8, GRASS_LIGHT), (33, 114, 12, GRASS_LIGHT),
                              (-8, 114, 10, GRASS_DEEP), (22, 140, 9, GRASS_LIGHT), (-30, 143, 10, GRASS_LIGHT), (-40, -7, 10, GRASS_DEEP), (38, -6, 11, GRASS_LIGHT), (0, 53, 9, GRASS_LIGHT)):
    dome(radius, 0.03, at(x, z), mix(GRASS, colour, 0.75), rotation=(0, 0, rng.uniform(0, 3)), stretch=rng.uniform(0.72, 0.9), sink=0.02, segments=16, roughness=0.9)

use("Cliff")
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
use("Road")
HALF = PATH_WIDTH / 2
sweep(PATH, [(-HALF + 0.7, ROAD_TOP), (HALF - 0.7, ROAD_TOP)], ROAD, back=PORTAL_DEPTH, roughness=0.9)
for side in (-1, 1):
    sweep(PATH, [(side * (HALF - 0.7), ROAD_TOP), (side * HALF, ROAD_TOP)], ROAD_EDGE, back=PORTAL_DEPTH, roughness=0.9)  # a darker band along each edge
    sweep(PATH, [(side * HALF, ROAD_TOP - 0.1), (side * HALF, 0.33), (side * (HALF + 0.1), 0.42), (side * (HALF + KERB - 0.1), 0.42), (side * (HALF + KERB), 0.33), (side * (HALF + KERB), -0.05)],
          KERB_COLOUR, back=PORTAL_DEPTH, caps=True, roughness=0.8, **(dict(emission=LOOK["kerb_glow"]) if LOOK["kerb_glow"] else {}))
# The plaza behind the gate: the game's 40 x 14 of paving, with round corners to the yard and a pale border.
PLAZA_PATH = ((-PLAZA_WIDTH / 2 + 3, GATE_Z), (-PLAZA_WIDTH / 2 + 3, 3), (PLAZA_WIDTH / 2 - 3, 3), (PLAZA_WIDTH / 2 - 3, GATE_Z))
sweep(PLAZA_PATH, [(-3.0, -0.05), (-3.0, PLAZA_TOP - 0.06), (-2.94, PLAZA_TOP), (-2.2, PLAZA_TOP)], COBBLE if LOOK["kerb_glow"] else KERB_COLOUR, roughness=0.8)
sweep(PLAZA_PATH, [(-2.2, PLAZA_TOP), (-1.5, PLAZA_TOP)], LOOK["band"], roughness=0.9)
plate(offset_line(PLAZA_PATH, -1.5), PLAZA_TOP, SAND, roughness=0.9)

# ---- The shells, on the game's spots ----
stand("Pad", pad, PADS[0], also=("PadTrim",), tint="FFC61A")
stand("Gate", gate, (0, GATE_Z), also=("GateTrim",))
stand("Portal", portal, PORTAL_AT, face=180, also=("PortalSheet",))
stand("Teleporter", teleporter, TELEPORTERS["worlds"], face=180, also=("TeleporterTrim",), tint=TELEPORTER_TINTS["worlds"])
stand("Lamp", lamp, LAMPS[0])

# ---- The fence: down both sides where the game's rails are, and along the back of the yard ----
use("Dressing")
for side in (-1, 1):
    fence_run((side * FENCE_X, -YARD - 0.6), (side * FENCE_X, DEPTH - 0.65), 19)
fence_run((-FENCE_X, -YARD - 0.6), (FENCE_X, -YARD - 0.6), 13, first=False, last=False)

# ---- The hills: two rows down each side (the two sides are not mirror images) and a low row behind the
# yard, all outside the ground ----
use("Backdrop")
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
FAR_DARK, FAR, CRAG_DARK, CRAG, CRAG_LIGHT = LOOK.get("crags") or (UNDER_DARK, UNDER, ROCK_DARK, ROCK, ROCK_LIGHT)
CRAGS = ((-11, 177, 14, 39, FAR_DARK, peak), (13, 178, 13, 42, FAR_DARK, peak), (-33, 172, 13, 30, FAR, peak), (35, 173, 13, 33, FAR, peak),  # (x, z, radius, height, colour, kind)
         (-21, 163, 12.5, 30, CRAG_DARK, butte), (22, 164, 12.5, 27, CRAG_DARK, butte), (-38, 161, 11, 24, CRAG, peak), (39, 162, 11, 20, CRAG, butte),
         (-53, 160, 9.5, 16.5, CRAG_LIGHT, butte), (54, 161, 9.5, 21, CRAG_LIGHT, peak))
SQUASH = 0.8  # a crag is this much less deep than it is wide
for x, z, radius, height, colour, kind in CRAGS:
    place(kind, (x, max(z, BEHIND + radius * SQUASH)), radius=radius, height=height, colour=colour, stretch=SQUASH)
# The world's liquid falls down the butte to the right of the portal, into a pool at its foot (outside the ground).
place(waterfall, (22, 164), face=180, fall=[(5.2, 27.6), (6.5, 26.9), (7.3, 25.0), (8.0, 21.5), (9.3, 12.0), (10.2, 1.2), (10.75, 0.25)], pool=1.8, reach=11.1)
place(monolith, (0, BEHIND + 15 * 0.85), radius=15, height=45, colour=FAR, stretch=0.85)
for x, z, size in ((-15.5, 153.8, 1.5), (14.6, 153.8, 1.1)):  # a boulder at its foot on each side of the portal
    place(rocks, (x, z), face=rng.uniform(0, 360), scale=size, colour=ROCK_LIGHT)
for x, z, radius, length, lean, colour in ((-13.0, 151.6, 0.9, 4.6, -0.3, HOT), (-14.6, 151.2, 0.6, 2.8, -0.6, EMBER), (13.4, 151.5, 0.95, 5.0, 0.3, HOT), (15.0, 151.1, 0.6, 3.0, 0.6, EMBER),
                                           (-11.9, 151.0, 0.5, 2.2, 0.1, HOT), (12.2, 150.9, 0.5, 2.4, -0.1, EMBER)):  # crystals beside the portal: they go to Glow
    tube(radius, length, at(x, z, 0), (-lean, 0, 1), colour, tip=0.0, vertices=5, roughness=0.15, emission=0.8)
# The world's name: a flat, empty board where the game writes it (WORLD_SIGN), hung on two beams.
left, right, low, high = WORLD_SIGN
sign_x, sign_y, sign_wide, sign_tall = (left + right) / 2, (low + high) / 2, right - left + 1.2, high - low + 0.9
slab((sign_wide, 0.6, sign_tall), at(sign_x, DEPTH + 0.4, sign_y), BOARD)
for y in (-1, 1):
    box((sign_wide + 1.5, 1.0, 0.8), at(sign_x, DEPTH + 0.35, sign_y + y * (sign_tall / 2 + 0.4)), GOLD, bevel=0.2, segments=1, roughness=0.3)
for x in (-1, 1):
    box((0.8, 1.0, sign_tall + 1.6), at(sign_x + x * (sign_wide / 2 + 0.4), DEPTH + 0.35, sign_y), GOLD, bevel=0.2, segments=1, roughness=0.3)
    box((1.4, 9.0, 1.4), at(sign_x + x * 7.5, DEPTH + 4.6, sign_y + 1.5), WOOD_DARK, bevel=0.3, segments=1)
    star(1.0, at(sign_x + x * (sign_wide / 2 + 0.4), DEPTH - 0.25, sign_y + sign_tall / 2 + 0.4), GOLD, depth=0.3, roughness=0.3)
# The world's landmark on the hills to the left, looking over the fence.
MILL = (-74, 61)
place(LANDMARK, (*MILL, hill_top(*MILL) - 1.0), face=78, scale=1.15)

# ---- The theme's trees, on the hills: nothing of them stands on the ground the game lays out ----
use("Trees")
HILL_TREES = [(side * (NEAR + 9 + across + rng.uniform(-2, 2)), z + rng.uniform(-3, 3), rng.uniform(1.15, 1.45)) for side in (-1, 1) for z, across, along, height in FAR_HILLS[side]]
HILL_TREES += [(side * (NEAR + across + rng.uniform(1, 4)), z + rng.uniform(-4, 4), rng.uniform(0.85, 1.05)) for side in (-1, 1) for z, across, along, height in SIDE_HILLS[side][1::2]]
HILL_TREES += [(-66, -25, 1.3), (67, -26, 1.35), (-74, -14, 1.0), (76, -13, 1.05), (-67, 150, 1.3), (69, 150, 1.25), (-54, 163, 0.9), (40, 165, 0.8), (-22, 166, 0.85), (-76, 143, 0.95), (78, 141, 1.0),
               (-34, -35, 0.95), (47, -31, 0.9), (10, -36, 0.7)]  # the last three: on the hills behind the yard, where they hide nothing of the base from the hero photo
for index, (x, z, size) in enumerate(HILL_TREES):
    if math.hypot(x - MILL[0], z - MILL[1]) < 15:
        continue  # the landmark's hill stays clear
    ground_here = hill_top(x, z)
    for bx, bz, radius, height, colour, kind in CRAGS:  # the buttes' caps
        if kind is butte and math.hypot(x - bx, z - bz) < radius * 0.5:
            ground_here = max(ground_here, height + 0.6)
    place(TREE, (x, z, ground_here - 0.8), face=rng.uniform(0, 360), scale=size, tone=index % 3, variant=1 if index % 3 == 1 else 0)

# ---- For the photos only: the shells on their other spots, towers, monsters, bulbs, beams, words ----
use("Placeholders")
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
# Monsters on the road, walking down it. (how far along the path, which colour, size)
LENGTHS = [(Vector(b) - Vector(a)).length for a, b in zip(PATH, PATH[1:])]
MONSTERS = LOOK["monsters"]
for far, tone, size in ((9, 0, 1.5), (34, 1, 1.5), (47, 2, 1.5), (70, 0, 1.5), (88, 3, 1.5), (112, 1, 1.5), (131, 3, 3.3), (160, 2, 1.5), (178, 0, 1.5), (205, 3, 1.5), (232, 1, 1.5), (262, 0, 1.5), (283, 2, 1.5)):
    for (a, b), length in zip(zip(PATH, PATH[1:]), LENGTHS):
        if far <= length:
            a, b = Vector(a), Vector(b)
            point, way = a + (b - a) * far / length, (b - a).normalized()
            place(stand_in_monster, (point.x + rng.uniform(-1.6, 1.6), point.y, ROAD_TOP), face=math.degrees(math.atan2(way.x, way.y)), scale=size, colour=MONSTERS[tone], eye="45C8FF" if tone == 3 else "FFE23A")
            break
        far -= length
words("YAANI'S BASE", (0, GATE_Z - NAME_SIGN[2] / 2 - 0.02, NAME_SIGN_Y), 1.5, face=180)
words("YAANI'S BASE", (0, GATE_Z + NAME_SIGN[2] / 2 + 0.02, NAME_SIGN_Y), 1.5, face=0)
words(WORLD.upper(), (sign_x, DEPTH - 0.02, sign_y), 5.4 if len(WORLD) < 6 else 4.4 if len(WORLD) < 9 else 30 / len(WORLD), face=180)

use("Sky")
for x, z, y, size in ((-150, 60, -40, 11), (160, 90, -34, 10), (-140, 200, -55, 8), (150, 220, -60, 9), (-60, -80, -70, 10), (70, -90, -75, 9),  # around and under the island
                      (-140, 330, 85, 15), (120, 350, 100, 16), (-10, 420, 140, 17), (230, 300, 60, 12), (-250, 280, 55, 12), (40, 300, 60, 9)):  # the sky seen from the yard
    place(cloud, (x, z, y), face=180 + rng.uniform(-25, 25), scale=size, colour=LOOK["cloud"])
if WORLD == "Moon":  # stars, all round and above
    for index in range(110):
        turn, lift = rng.uniform(0, 2 * math.pi), rng.uniform(-0.5, 1.1)
        far = 1300
        ball(rng.uniform(2.2, 5.5), (math.cos(turn) * math.cos(lift) * far, 73 + math.sin(turn) * math.cos(lift) * far, math.sin(lift) * far), rng.choice(("FFFFFF", "FFE9A8", "BFD8FF")), segments=6, emission=3.0)
    ball(46, at(-330, 760, 300), "7FB8FF", segments=24, roughness=0.9)  # the Earth, far off
    ball(46.3, at(-330, 760, 300), "6FD046", scale=(0.62, 1, 0.5), rotation=(0.3, 0.2, 0.5), segments=16, roughness=0.9)
# Worlds 6 to 12: the stars of the ones with a night (or a dawn) sky, in that world's colours, as on its island
for index in range(110 if LOOK.get("stars") else 0):
    turn, lift = rng.uniform(0, 2 * math.pi), rng.uniform(-0.5, 1.1)
    far = 1300
    ball(rng.uniform(2.2, 5.5), (math.cos(turn) * math.cos(lift) * far, 73 + math.sin(turn) * math.cos(lift) * far, math.sin(lift) * far), LOOK["stars"][index % 3], segments=6, emission=3.0)
if WORLD == "Nebula":  # teal gas between the pink
    for x, z, y, size in ((-170, 130, -30, 10), (175, 20, -48, 9), (20, -100, -60, 9), (60, 340, 110, 14), (-230, 330, 70, 12)):
        place(cloud, (x, z, y), face=180 + rng.uniform(-25, 25), scale=size, colour="9AF0E4")
if WORLD == "The Big Bang":  # what the bang threw out, still on its way: shards all round the island
    for index in range(40):
        x, y = ring(rng.uniform(0, 360), rng.uniform(150, 260))
        gem(rng.uniform(1.8, 3.4), rng.uniform(8, 15), (x, 73 + y, rng.uniform(-80, 70)), (LEAVES + (GOLD, WHITE))[index % 5], (rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1) or 1), roughness=0.25)

triangles = kit.count()

# ---------------------------------------------------------------------------------------------------
# The photos: the world's sky and light
# ---------------------------------------------------------------------------------------------------
kit.studio(OUT, draft=DRAFT, sky=kit.EARTH_SKY if WORLD == "Earth" else LOOK.get("sky") or kit.sky_ramp(T["sky_top"], T["sky_horizon"]), clip_end=4000, strength=LOOK["ambient"])
if LOOK.get("fill"):  # a night sky: dark to look at, but it lights the base `fill` times as much as it shows
    tree = bpy.context.scene.world.node_tree
    rays, scale = tree.nodes.new("ShaderNodeLightPath"), tree.nodes.new("ShaderNodeMapRange")
    scale.inputs["To Min"].default_value, scale.inputs["To Max"].default_value = LOOK["ambient"] * LOOK["fill"], LOOK["ambient"]
    tree.links.new(rays.outputs["Is Camera Ray"], scale.inputs["Value"])
    tree.links.new(scale.outputs["Result"], tree.nodes["Background"].inputs["Strength"])
bpy.context.scene.cycles.samples = 32 if DRAFT else 64  # other Blender jobs render at the same time
kit.sun.data.energy = LOOK["sun"]


def sky_point(degrees, height, distance):
    """A point `distance` away in a direction of plot space (0 up the plot, 90 towards +x, 180 behind the
    yard) and `height` degrees above the ground, in Blender's space."""
    reach = distance * math.cos(math.radians(height))
    return Vector((-math.sin(math.radians(degrees)) * reach, math.cos(math.radians(degrees)) * reach, distance * math.sin(math.radians(height))))


def shot(name, eye, target, lens, light=(215, 50)):
    """A photo from `eye` at `target`, both points of Blender's space (use at). `light` is where the sun
    stands: its direction in plot space (like sky_point) and its height."""
    photo(f"{SLUG}_base_{name}", eye, target, lens, light=(-light[0], light[1]))


# For checking only, when asked for by name (photos=road,gate ...).
CHECKS = {"portal": (at(12, 106, 7.5), at(2, 150, 14.5), 22, (205, 48)),  # the portal, from the road in front of it
          "road": (at(-12, 133, 9.5), at(0, 14, 6.0), 26, (-30, 48)),  # the base as the monsters see it when they come out of the portal
          "gate": (at(-11, 47, 7.0), at(0, 14, 10.5), 24, (-35, 46)),  # the gate from close by, from the road
          "field": (at(6, 30, 6.0), at(-50, 92, 7.0), 20),  # a player's eyes out in the field: the road, the pads and the horizon
          "pad": (at(-15, 41, 5.5), at(-23, 53, 0.3), 35), "lamp": (at(-38, -4, 7.0), at(-49, -11, 7.5), 28), "back": (at(0, 9, 6.2), at(8, -30, 5.0), 18),
          "right": (at(-10, 96, 6.0), at(50, 130, 9.0), 20), "teleporter": (at(-4, -6, 6.5), at(-13, 3, 4.5), 26), "mill": (at(-30, 61, 8.0), at(-74, 61, 18.0), 28)}
for name in ONLY:
    if name in CHECKS:
        shot(name, *CHECKS[name])
# A player's eyes in the yard behind the gate, looking up the road to the portal.
if not ONLY or "ground" in ONLY:
    shot("ground", at(0, -14.5, 6.2), at(0, 40, 10.5), 17)
# Three-quarters from above, from behind the yard. Last, so the saved file opens on this view.
if not ONLY or "hero" in ONLY:
    HERO_TARGET = at(0, 66, -26)
    shot("hero", HERO_TARGET + sky_point(156, 34, 500), HERO_TARGET, 52)


# ---------------------------------------------------------------------------------------------------
# For Roblox: one mesh per group, colours on the vertices (white on a trim), none with over 10,000
# triangles, and a manifest that says where everything goes.
# ---------------------------------------------------------------------------------------------------
def beside_path(x, z):
    """How far a point of plot space is from the middle of the road (which starts PORTAL_DEPTH behind the path's first point)."""
    line = [Vector(PORTAL_AT)] + [Vector(point) for point in PATH[1:]]
    here = Vector((x, z))
    return min((here - (a + (b - a) * max(0.0, min(1.0, (here - a).dot(b - a) / (b - a).dot(b - a))))).length for a, b in zip(line, line[1:]))


def rounded_list(values, places=2):
    return [round(value, places) + 0.0 for value in values]


def export():
    report = kit.export(f"{OUT}/{SLUG}_base.fbx", white=TRIMS)
    meshes, bounds = [], {}
    for entry in report:
        name, least, most = entry["group"], entry["low"], entry["high"]
        bounds[name] = (least, most)
        is_shell, is_marker = name in shells, name in ("Origin", "North")
        meshes.append({
            "name": entry["name"],
            "kind": "marker" if is_marker else "shell" if is_shell else "scenery",
            "origin": "the middle of its own base on the ground, front towards Blender -Y" if is_shell else "the plot's origin, on the ground",
            "triangles": entry["triangles"],
            "box_blender": {"low": rounded_list(least), "high": rounded_list(most)},
            # the same box in the game's axes: plot space for scenery, the shell's own pivot (front -Z) for a shell
            "box": {"low": rounded_list((-most.x, least.z, least.y)), "high": rounded_list((-least.x, most.z, most.y))},
            "material": "Neon" if name in ("Glow", "PortalSheet") else "Glass" if name == "Water" else "SmoothPlastic",
            "white_for_tinting": name in TRIMS,
        })

    # The layout, measured back off the meshes: what the game's own numbers say they should be.
    road = [vertex.co for vertex in bpy.data.objects["Base_Road"].data.vertices if vertex.co.y > GATE_Z + 0.01 or (vertex.co.y > GATE_Z - 0.01 and abs(vertex.co.x) < PATH_WIDTH)]  # without the plaza
    if LOOK["kerb_glow"]:  # the glowing kerb is in Base_Glow
        road += [vertex.co for vertex in bpy.data.objects["Base_Glow"].data.vertices if vertex.co.z < 0.45 and beside_path(-vertex.co.x, vertex.co.y) < 4.81 and vertex.co.y < 147.01]
    surface = [co for co in road if abs(co.z - ROAD_TOP) < 0.001]
    pad_low, pad_high = bounds["Pad"]
    origin_low, origin_high = bounds["Origin"]
    north_low, north_high = bounds["North"]
    checks = {
        "road_top": [round(min(co.z for co in surface), 3), round(max(co.z for co in surface), 3)],
        "road_half_width": round(max(beside_path(-co.x, co.y) for co in surface), 3),
        "road_with_kerb_half_width": round(max(beside_path(-co.x, co.y) for co in road), 3),
        "road_from_z_to_z": [round(max(co.y for co in road), 3), round(min(co.y for co in road), 3)],
        "kerb_top": round(max(co.z for co in road), 3),
        "pad_size": [round(value, 3) for value in pad_high - pad_low],
        "ground_top": round(max(vertex.co.z for vertex in bpy.data.objects["Base_Ground"].data.vertices if abs(vertex.co.x) < 60 and -20 < vertex.co.y < 160), 3),
        "origin_marker_centre_plot": rounded_list(((-(origin_low.x + origin_high.x) / 2), (origin_low.z + origin_high.z) / 2, (origin_low.y + origin_high.y) / 2)),
        "north_marker_centre_plot": rounded_list(((-(north_low.x + north_high.x) / 2), (north_low.z + north_high.z) / 2, (north_low.y + north_high.y) / 2)),
        "biggest_mesh": max(entry["triangles"] for entry in meshes),
    }
    total = sum(entry["triangles"] for entry in meshes)
    print("CHECKS", checks)
    print(f"EXPORTED {WORLD}: {len(meshes)} meshes, {total} triangles, biggest {checks['biggest_mesh']}")

    def box_of(what, x, z, size, yaw=0.0, optional=False):
        return {"what": what, "shape": "box", "centre": [round(x, 2), round(size[1] / 2, 2), round(z, 2)], "size": [round(value, 2) for value in size], "yaw": yaw, "optional": optional}

    def pillar_of(what, x, z, radius, height):
        return {"what": what, "shape": "pillar", "centre": [round(x, 2), round(height / 2, 2), round(z, 2)], "radius": round(radius, 2), "height": round(height, 2)}

    colliders = [pillar_of("lamp", x, z, 0.6, 11.0) for x, z in LAMPS]
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
    roof_tip = ROOFS[LOOK["roof"]][0][0][1]
    manifest = {
        "what": f"The {WORLD} base: scenery and shells for src/server/Plots.luau to wear over the base it builds from parts, as Islands.wear does for the island. Made by tools/blender/base.py \"{WORLD}\".",
        "world": WORLD,
        "units": "1 Blender unit = 1 stud",
        "mapping": {
            "plot_space": "Layout.luau: the origin is the middle of the base's edge of the ground, x across the plot, +z up the plot to the portal, y up, the ground's top at y = 0, the yard behind the origin (-z)",
            "blender_to_plot": "plot (x, y, z) = Blender (-x, z, y)",
            "plot_to_blender": "Blender (x, y, z) = plot (-x, z, y)",
            "markers": "Base_Origin: a 2 x 2 x 2 cube centred at plot (0, 1, 0). Base_North: the same cube at plot (0, 1, 10), towards the portal (Blender +Y). tools/studio/setup_models.luau reads and deletes them",
            "scenery_in_roblox": "an FBX lands as Roblox (-x, z, y) of Blender's (x, y, z), which is plot space itself. setup_models.luau gives the scenery Model the plot's origin as its pivot with its -Z towards the North marker, the portal; the plot's +Z runs to the portal, so: model:PivotTo(plot.frame * CFrame.Angles(0, math.pi, 0))",
            "shell_in_roblox": "a shell's pivot is the middle of its base on the ground and its front (Blender -Y) is its -Z: shell:PivotTo(plot.frame * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)) with yaw = face + 180",
            "face": "where a shell's front looks, in plot space: 0 = up the plot (+z), 90 = towards +x, 180 = back at the yard (-z)",
            "colliders": "centre is (x, y, z) in plot space; a box's size is (x, y, z) in its own frame, turned by CFrame.Angles(0, math.rad(yaw), 0); a pillar stands upright",
        },
        "theme": {"tree": T["tree"], "fence": T["fence"], "liquid": T["liquid"], "ground": GRASS, "road": ROAD, "kerb": KERB_COLOUR, "kerb_glows": bool(LOOK["kerb_glow"]), "stone": STONE, "wood": WOOD,
                  "portal_glow": HOT, "roofs": LOOK["roof"], "landmark": LOOK["landmark"], "sky": [T["sky_top"], T["sky_horizon"]]},
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
        "meshes": meshes,
        "total_triangles": total,
        "shells": {
            "Pad": {
                "meshes": ["Base_Pad", "Base_PadTrim"], "spots": [list(point) for point in PADS], "y": 0, "face": 0, "yaw": 180, "note": "the same from all four sides: any quarter turn will do",
                "footprint": [PAD_SIZE, PAD_SIZE], "highest": PAD_HEIGHT, "plate_top": PAD_HEIGHT - 0.04,
                "heights": "the gold corners are PAD_HEIGHT (0.5) high, the plate 0.46: the game's pad stays as the solid floor and the carrier of the prompt and the '+', and its top (0.5, where a tower stands) is 0.04 over the plate",
                "trim": "Base_PadTrim is the band round the plate, for the pad's state. In the photos: for sale B0B4C0, the owner's and empty 6EEB8C, built on FFC61A",
                "sign": {"what": "the '+' on an empty pad (the pad's Top)", "written_at_y": PAD_HEIGHT, "flat_empty_face": "the plate, at y = 0.46: x -3.08 ... 3.08, z -3.08 ... 3.08 around the pad's middle, but for the gold corners (1.5 square each)"},
            },
            "Gate": {
                "meshes": ["Base_Gate", "Base_GateTrim"], "spots": [[0, GATE_Z]], "y": 0, "face": 0, "yaw": 180, "note": "its front is the side the monsters see; the yard's side looks the same",
                "heights": {"arch": "round, 14 wide; 14 high in the middle, springing 7 up (the game's see-through Gate part, 14 x 14, fits behind it: its top corners are inside the stone)",
                            "portcullis_tips": 10.1, "name_board": [14.05, 17.15], "gatehouse_top": 19.2, "crest_top": 24.1, "tower_parapet": 17.7, "tower_battlements": 18.9, "roof_tip": roof_tip, "flag_top": roof_tip + 4.4,
                            "wall_top": WALL_HEIGHT, "wall_battlements": 5.37, "wall_posts": 5.9, "wall_post_knobs": 7.9, "arrival_ring": 0.28, "arrival_disc": 0.2},
                "trim": "Base_GateTrim is everything in the owner's colour (plot.colored): the two roofs, the two flags, the four banners, the crest's shield and the disc of the arrival pad (at plot 0, 4; its top is 0.2, under the game's own disc at 0.25). In the photos FF6161, slot 1's colour",
                "signs": [
                    {"what": "the owner's name, yard side (NameSign, Front)", "written_at_z": GATE_Z - apart / 2, "x": [-wide / 2, wide / 2], "y": [NAME_SIGN_Y - tall / 2, NAME_SIGN_Y + tall / 2],
                     "flat_empty_face": "a dark board at plot z = 12.35 (0.05 behind the writing): x -6.55 ... 6.55, y 14.05 ... 17.15"},
                    {"what": "the owner's name, road side (NameSign, Back)", "written_at_z": GATE_Z + apart / 2, "x": [-wide / 2, wide / 2], "y": [NAME_SIGN_Y - tall / 2, NAME_SIGN_Y + tall / 2],
                     "flat_empty_face": "a dark board at plot z = 15.65: x -6.55 ... 6.55, y 14.05 ... 17.15"},
                ],
            },
            "Portal": {
                "meshes": ["Base_Portal", "Base_PortalSheet"], "spots": [list(PORTAL_AT)], "y": 0, "face": 180, "yaw": 0, "note": "its front looks down the road at the gate; its back is plain (the rock is 3 studs behind it)",
                "heights": {"mouth": "14.5 wide between the legs; 16.2 high in the middle, springing 9.3 up", "sheet_top": 16.6, "top_of_the_arch": 20.8, "crest": 22.7, "horn_tips": 25.6},
                "sheet": f"Base_PortalSheet (for Neon; the game may fade or dim it as it does its own Portal part) is the sheet with its dark whirl, the two eyes, the runes on the legs and the gem on the brow. Its glow is {HOT}, on purpose not the world's accent {ACCENT} that the island's friendly portal has",
            },
            "Teleporter": {
                "meshes": ["Base_Teleporter", "Base_TeleporterTrim"], "spots": [list(TELEPORTERS["worlds"]), list(TELEPORTERS["market"])], "y": 0, "face": 180, "yaw": 0, "note": "the same from the front and the back",
                "heights": {"dais_top": 0.42, "trim_on_the_dais": 0.47, "orb": TELEPORTER_ORB, "highest": 11.25, "inside_the_arch": "6.2 wide between the legs, 9.15 high in the middle: the game's beam (1.7 in radius, 0.4 to 8.4 up) stands in it"},
                "trim": "Base_TeleporterTrim is pure white: the ring and the disc on the dais, the orb in the crown (where the game's own orb floats) and a gem on each leg. Tint it by destination: worlds 46DC8C (70, 220, 140), market 8264FF (130, 100, 255)",
                "sign": "the game's titles are billboards (15 x 3.8, their middle 13.3 up): no face to keep. Nothing of the shell is higher than 11.25, the titles' lower edge is 11.4",
            },
            "Lamp": {
                "meshes": ["Base_Lamp"], "spots": [list(spot) for spot in LAMPS], "y": 0, "face": 0, "yaw": 180, "note": "the same from all sides",
                "heights": {"bulb": LAMP_BULB, "cage": [10.85, 13.1], "top": 14.9},
                "bulb": "the shell has no bulb: the game's own Lamp ball (2.2 across, its middle 12 up) hangs in the cage and keeps its light and its Halloween colour",
            },
        },
        "signs_on_scenery": [
            {"what": "the world's name (the middle slab of the skyline, Front)", "written_at_z": DEPTH, "x": [left, right], "y": [low, high],
             "flat_empty_face": "Base_Backdrop: a dark board at plot z = 150.1 (0.1 behind the writing): x -10.5 ... 10.5, y 24.31 ... 32.01"},
        ],
        "game_parts": {
            "stay_seen": ["Lamp (the bulb)", "WorldsPortal and MarketPortal (the teleporters' see-through beams)", "Gate (the see-through sheet in the arch, if wanted)", "the pads' FOR SALE signs, the towers"],
            "unseen_but_kept": "everything else in Scenery and the Decor folder (the ten world props: the base brings its own backdrop): Ground, Yard, Kerb, Road, Backdrop, Surround, FencePost, FenceRail, Plaza, ArrivalPad, GateTower, Battlement, Roof, FlagPole, Flag, Wall, GateBeam, Merlon, NameSign, LampFoot, LampPost, PortalPillar, PortalBeam, PortalHorn, Portal, WorldsRing, MarketRing, WorldsOrb, MarketOrb, Pad_1 ... Pad_16. The signs on NameSign, Backdrop and the pads stay on",
        },
        "colliders": colliders,
        "checks_measured_off_the_meshes": checks,
        "not_as_the_code": [
            "The road runs round the outside of each of its eight bends in an arc (radius 4, with the kerb 4.8): inside the square corner the game's slabs make, never outside it.",
            "The kerb is 0.8 wide as in the code but 0.42 high (the code's is a flat band at 0.1, lower than the road's 0.2).",
            "The gate's arch is round: 14 wide and 14 high in the middle like the code's opening, lower towards its sides. A portcullis hangs in its top (tips 10.1 up) and its door stands open to the road: two leaves beside the way, x = +-7.3 ... +-8.5, z = 15.9 ... 22.8 (see colliders).",
            "The towers are 3.6 in radius (the code's solid 3.5), their feet 4.0. The walls' posts are 2.8 x 3.0 (the solid wall is 2 thick) and stand 1.4 over its top.",
            "The plaza keeps the code's 40 x 14 but has round corners (radius 3) to the yard. Like the code's ring, a teleporter's dais (3.6 in radius) reaches 0.6 past the plaza's edge.",
            "The fence has 19 posts a side (the code 10; every other one of mine stands on one of the code's) and runs on along the back of the yard at z = -16.6, just outside the ground, where the code has only its hills. Its rails follow the theme's kind; the game's two solid rails stay where they are.",
            "The code's ten world props (PROP_SPOTS) are not used and nothing stands in for them: the floor stays clean, and every tree, rock and the landmark is outside the ground (|x| > 55, z < -16 or z > 150).",
            f"The portal's glow is {HOT} instead of the code's glow for this world, so it is not the island's portal.",
            "The big lighter and darker patches of the ground are flat discs that rise 0.03 in their middle.",
        ],
    }
    with open(f"{OUT}/{SLUG}_base_manifest.json", "w") as file:
        json.dump(manifest, file, indent=1)


if not NOFILES:
    export()
