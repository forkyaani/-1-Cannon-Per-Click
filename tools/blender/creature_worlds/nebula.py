# World 7, Nebula: creatures of cloud, starlight and plasma. Run by ../creatures.py with its helpers to hand.
from mathutils import Euler

NEBULA_PINK, NEBULA_CYAN, NEBULA_STAR = "FF6FD0", "6FF0FF", "FFE45A"


def nebula_strand(points, colour, start=0.2, end=0.1, **look):
    """A tentacle: a chain of small balls along a path."""
    for index, point in enumerate(points):
        ball(start + (end - start) * index / max(1, len(points) - 1), point, colour, segments=6, **look)


def nebula_hang(x, y, z, length, colour, count=5, sway=0.14, phase=0.0, start=0.2, end=0.1, **look):
    """A tentacle hanging down from (x, y, z), swaying."""
    nebula_strand([(x + sway * math.sin(index * 1.7 + phase), y, z - length * index / (count - 1)) for index in range(count)], colour, start, end, **look)


def stardust_mite(c, a):
    # A round little bug with a dark shell sprinkled with stars, a crest of stars on it, stardust behind it.
    front = crawler(c, a, w=2.5, d=2.1, h=1.35, lift=0.3, legs=3, bevel=0.6)
    helmet(a, 1.45, 1.2, y=0.25, squash=0.75)
    star(0.5, (0, 0.25, 2.6), NEBULA_STAR, depth=0.16, emission=1.5)
    star(0.3, (-0.78, 0.1, 2.2), NEBULA_STAR, depth=0.12, emission=1.5)
    star(0.3, (0.8, 0.15, 2.18), NEBULA_STAR, depth=0.12, emission=1.5)
    for x, y, z in ((-0.45, -0.55, 2.02), (0.5, -0.5, 2.0), (-1.0, 0.7, 1.75), (1.0, 0.75, 1.75), (0, 1.25, 1.8)):
        ball(0.11, (x, y, z), WHITE, segments=6, emission=1.5)  # sparkles on the shell
    antennae(a, NEBULA_STAR, 0.5, 1.5, height=0.85, lean=30, y=-0.85, bulb=0.22)
    for side in (-1, 1):  # little mandibles
        cone(0.14, 0.4, (side * 0.42, front - 0.02, 0.6), (-side * 0.4, -0.6, -0.6), a, sides=5)
    for x, y, z, r in ((0.3, 1.35, 0.3, 0.2), (-0.2, 1.6, 0.2, 0.14), (0.15, 1.85, 0.12, 0.1)):
        ball(r, (x, y, z), NEBULA_STAR, segments=6, emission=1.5)  # the dust it leaves
    eyes(front, 1.08, 0.55, a, size=0.88)
    mouth(front, 0.55, 0.3)


def gas_puff(c, a):
    # A puffed-up cloud of gas on a patch of mist, blowing a wisp out of its top.
    front = blob(c, w=2.2, d=2.0, h=1.8, puddle=a, bevel=0.85, roughness=0.8)
    pale = shade(c, 0.5)
    tuft(c, ((-1.05, 0.1, 0.6, 0.62), (1.05, 0.15, 0.62, 0.6), (-0.9, 0.3, 1.45, 0.56), (0.92, 0.3, 1.42, 0.54), (0, 0.8, 0.75, 0.7), (0, 0.65, 1.5, 0.62)), roughness=0.8)
    tuft(a, ((-0.75, -0.62, 0.32, 0.4), (0.8, -0.6, 0.3, 0.38), (-1.35, 0.3, 0.3, 0.34), (1.35, 0.4, 0.3, 0.32)), roughness=0.8)
    tuft(pale, ((0.05, 0.05, 1.92, 0.6), (-0.55, 0.2, 1.85, 0.45), (0.6, 0.05, 1.8, 0.42)), roughness=0.8)
    tuft(pale, ((0.3, 0.1, 2.5, 0.4), (0.55, 0.1, 2.92, 0.3), (0.42, 0.1, 3.25, 0.2)), emission=0.3)  # the wisp
    eyes(front, 1.1, 0.5, "2FB07E", size=0.9)
    mouth(front, 0.52, 0.42, "o")


def nebula_jelly(c, a):
    # A jellyfish: a glassy bell with a pink frill and pink tentacles, a pink glow in its crown.
    hem = lambda angle: 1.25 + 0.1 * math.cos(math.radians(angle * 6))
    lathe([(0, 3.0), (0.75, 2.88), (1.25, 2.45), (1.42, 1.85), (lambda angle: 1.5, hem), (0, 1.55)], c, segments=18, roughness=0.25, emission=0.25)
    front = -1.33
    hoop(1.42, 0.17, (0, 0, 1.3), a, segments=14, emission=0.4)
    ball(0.6, (0, 0, 2.86), a, scale=(1, 1, 0.42), segments=10, emission=1)
    for x, y, z in ((-0.85, -0.5, 2.62), (0.9, -0.4, 2.6), (0.2, 0.9, 2.66)):
        spot((x, y, z), 0.2, a, towards=(x, y, 1.2))
    cone(0.6, 0.9, (0, 0, 1.5), (0, 0, -1), shade(c, 0.4), sides=8)  # the frilly arms in the middle
    for index, (x, y) in enumerate(((-0.95, -0.35), (0.95, -0.35), (-0.6, 0.7), (0.6, 0.7), (0, -0.75))):
        nebula_hang(x, y, 1.2, 1.15 - 0.2 * (index % 2), a, count=5, phase=index * 1.3, emission=0.4)
    eyes(front, 2.05, 0.46, a, size=0.82)
    mouth(front - 0.02, 1.55, 0.3)


def plasma_sprite(c, a):
    # A ball of plasma with a tail, lightning bolts for ears and arms, an electron on a ring round it.
    ball(1.0, (0, 0, 1.5), c, scale=(1, 0.95, 1), segments=12, roughness=0.25, emission=0.6)
    front = -0.9
    cone(0.6, 1.0, (0, 0.1, 0.95), (0.2, 0, -1), c, sides=8, emission=0.6)
    ball(0.16, (0.32, 0.1, -0.2), a, segments=6, emission=1.5)
    bolt = [(-0.14, 0), (0.22, 0.5), (0.0, 0.5), (0.3, 1.1), (-0.34, 0.38), (-0.1, 0.38)]
    for side in (-1, 1):
        shape = [(x * side, z) for x, z in bolt]
        plate(shape, a, (side * 0.5, 0, 2.25), thick=0.2, rotation=(0, side * 0.45, 0), emission=1.5)
        plate(shape, a, (side * 0.85, -0.1, 1.2), thick=0.2, rotation=(0, side * 1.75, 0), emission=1.5)
    turn = Euler((0.4, 0.3, 0))
    hoop(1.4, 0.1, (0, 0, 1.5), a, rotation=turn, segments=14, emission=1)
    for angle, colour in ((-1.2, NEBULA_CYAN), (2.2, WHITE)):
        point = Vector((math.cos(angle) * 1.4, math.sin(angle) * 1.4, 0))
        point.rotate(turn)
        ball(0.2, (point.x, point.y, point.z + 1.5), colour, segments=8, emission=2)
    eyes(front, 1.65, 0.4, "FF7A1E", size=0.8)
    mouth(front, 1.12, 0.32)


def star_hatchling(c, a):
    # A baby star still sitting in its golden eggshell, a bit of shell on its top point.
    zig = lambda angle: 1.15 + (0.2 if round(angle / 22.5) % 2 else -0.2)
    lathe([(0, 0.8), (lambda angle: 1.08, zig), (lambda angle: 1.25, zig), (1.2, 0.75), (0.8, 0.3), (0, 0.22)], a, segments=16, smooth=False, roughness=0.35)
    feet("FF9A3C", 0.5, size=(0.6, 0.8, 0.35))
    cube(1.8, 1.6, 1.75, 0.9, c, bevel=0.8, emission=0.25)
    front = -0.8
    for lean in (0, -72, 72):  # the points of the star that are out of the shell
        way = (math.sin(math.radians(lean)), 0, math.cos(math.radians(lean)))
        cone(0.52, 1.3, (way[0] * 0.6, 0.05, 1.78 + way[2] * 0.6), way, c, sides=6, emission=0.25)
    cap = lambda angle: 0.1 if round(angle / 30) % 2 else -0.06
    lathe([(0, 0.45), (0.4, 0.34), (lambda angle: 0.62, cap), (0, 0.05)], a, segments=12, smooth=False, roughness=0.35, location=(0.05, 0.05, 3.15), rotation=(0, 0.3, 0))
    star(0.2, (0, front - 0.06, 1.52), a, depth=0.08, emission=0.5)
    eyes(front, 2.15, 0.44, "FFB01F", size=0.8)
    mouth(front, 1.75, 0.26)


def cloud_leviathan(c, a):
    # A sky whale of storm cloud: a great head, a body that trails away to a glowing fluke, a mane of cloud,
    # glowing horns and fins, jellyfish whiskers hanging from its jaw.
    dark, pale, puff = shade(c, -0.25), "7A6CF0", "D9D2FF"
    box((3.2, 2.6, 2.3), (0, -0.6, 1.75), c, bevel=0.8, segments=3)
    front = -1.9
    box((2.8, 2.5, 0.8), (0, -0.7, 0.85), pale, bevel=0.35, segments=2)
    for (y, z, r) in ((1.2, 1.7, 1.1), (2.2, 1.75, 0.9), (3.0, 2.0, 0.7), (3.6, 2.4, 0.5)):
        ball(r, (0, y, z), c, segments=10)
    plate([(0, 0), (-1.1, 0.6), (-0.9, 1.0), (0, 0.5), (0.9, 1.0), (1.1, 0.6)], a, (0, 3.85, 2.55), thick=0.25, emission=0.8)
    for side in (-1, 1):
        fin = [(0, 0.3), (1.3, 0.1), (1.6, -0.55), (0.9, -0.35), (0, -0.3)]
        plate([(x * side, z) for x, z in fin], a, (side * 1.5, 0.2, 1.3), thick=0.24, rotation=(0, 0, side * -0.3), emission=0.8)
        cone(0.36, 1.0, (side * 1.1, -0.5, 2.9), (side * 0.6, 0, 1), a, sides=6, emission=1)
        for index in range(3):
            spot((side * 1.61, -1.1 + index * 0.55, 1.75 + 0.12 * index), 0.2 - 0.03 * index, a, towards=(side, 0, 0))
        nebula_hang(side * 1.15, -1.6, 0.6, 0.6, a, count=4, phase=side, start=0.2, end=0.12, emission=1)
        nebula_hang(side * 0.6, -0.4, 0.55, 0.55, a, count=4, phase=2 + side, start=0.18, end=0.1, emission=1)
    tuft(puff, ((-0.9, -0.9, 2.95, 0.5), (0, -1.0, 3.1, 0.6), (0.9, -0.9, 2.95, 0.5), (0, 0, 3.05, 0.6), (-0.7, 0.1, 2.9, 0.45), (0.7, 0.1, 2.9, 0.45),
                (0, 1.2, 2.8, 0.5), (0, 2.2, 2.6, 0.42), (0, 3.0, 2.65, 0.32)), emission=0.2)
    tuft(puff, ((-1.3, 0.3, 0.6, 0.45), (1.3, 0.3, 0.6, 0.45), (0, 1.3, 0.75, 0.5), (0, 2.3, 1.0, 0.4)), emission=0.2)
    eyes(front, 2.15, 0.8, a, size=1.15, brow=pale, tilt=-24)
    mouth(front - 0.04, 1.2, 1.3, "fangs")


def nebula_queen(c, a):
    # A queen in a gown that ends in nebula cloud: a tall crown under a star, hair of pink and cyan cloud,
    # a high pink collar, a star sceptre.
    sleeve = "8A4CE8"
    hem = lambda angle: 0.12 + 0.12 * math.cos(math.radians(angle * 8))
    lathe([(0, 2.2), (1.0, 2.2), (1.15, 1.9), (1.45, 1.0), (lambda angle: 1.85, hem), (0, 0.3)], c, segments=24)
    for index in range(8):
        x, y = ring(index * 45 + 22.5, 1.75)
        ball(0.45, (x, y, 0.42), NEBULA_PINK if index % 2 else NEBULA_CYAN, scale=(1, 1, 0.9), segments=8, emission=0.3)
    tube(1.17, 0.3, (0, 0, 1.85), UP, a, vertices=14, roughness=0.3)
    for x, y, r, turn in ((0, -1.52, 0.32, 0), (-0.75, -1.3, 0.22, -0.52), (0.75, -1.3, 0.22, 0.52)):
        star(r, (x, y, 1.02), NEBULA_STAR, depth=0.1, rotation=(-0.42, 0, turn), emission=1.5)
    cube(2.7, 2.3, 2.1, 2.1, c, bevel=0.7)
    front = -1.15
    for side in (-1, 1):
        collar = [(0.6, 0), (2.4, 0.9), (1.9, 1.1), (2.5, 2.0), (1.8, 1.9), (2.0, 2.9), (0.9, 2.2)]
        plate([(x * side, z) for x, z in collar], NEBULA_PINK, (0, 0.95, 1.9), thick=0.25, emission=0.3)
        tuft(NEBULA_PINK, ((side * 1.45, 0.1, 3.7, 0.6), (side * 1.6, 0.2, 3.0, 0.5), (side * 1.5, 0.3, 2.4, 0.42)), emission=0.3)
        tuft(NEBULA_CYAN, ((side * 0.8, 1.1, 2.9, 0.6),), emission=0.3)
        box((0.6, 0.7, 1.1), (side * 1.5, -0.25, 1.75), sleeve, bevel=0.25, segments=2, rotation=(0, side * math.radians(-16), 0))
        ball(0.36, (side * 1.68, -0.4, 1.15), a, segments=8, roughness=0.3)
    tuft(NEBULA_CYAN, ((0, 1.15, 3.6, 0.8),), emission=0.3)
    crown(4.15, radius=0.8, colour=a, gems=NEBULA_CYAN, points=5, size=1.2)
    star(0.5, (0, 0, 5.3), NEBULA_STAR, depth=0.2, emission=2)
    # The sceptre, in her right hand.
    tube(0.1, 3.3, (1.75, -0.5, 0.3), UP, a, vertices=6, roughness=0.3)
    ball(0.24, (1.75, -0.5, 3.6), NEBULA_CYAN, segments=8, emission=2)
    star(0.55, (1.75, -0.5, 4.15), NEBULA_STAR, depth=0.22, emission=2)
    eyes(front, 3.25, 0.64, NEBULA_PINK, size=1.1, brow=a, tilt=-18)
    mouth(front, 2.52, 0.5, "fangs")


WORLDS["Nebula"] = [
    ("Stardust Mite", stardust_mite, "EBCFFF", "8A55E0", "walker"),
    ("Gas Puff", gas_puff, "8CF5C4", "3FC896", "walker"),
    ("Nebula Jelly", nebula_jelly, "5AD4F5", "FF6FD8", "floater"),
    ("Plasma Sprite", plasma_sprite, "FFEC5A", "FF8C28", "floater"),
    ("Star Hatchling", star_hatchling, "EAF4FF", "FFC83C", "walker"),
    ("Cloud Leviathan", cloud_leviathan, "4A3CC8", "6FE6FF", "boss floater"),
    ("Nebula Queen", nebula_queen, "7A32D0", "FFD23C", "boss"),
]
BACKDROPS["Nebula"] = "C272A6"
