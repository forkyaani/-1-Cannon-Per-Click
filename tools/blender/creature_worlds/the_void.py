# World 6, The Void: run by ../creatures.py, with all its pieces, faces, bodies and features to hand.
# Deep violets with one glowing accent each: lilac, purple, magenta, hot pink, cyan, pink, red and gold.


def the_void_tear(size=1.0):
    """The outline of a rift: a jagged tear standing upright, pointed at both ends."""
    shape = [(0, -1.0), (0.34, -0.3), (0.14, -0.12), (0.4, 0.45), (0, 1.0), (-0.34, 0.3), (-0.14, 0.12), (-0.4, -0.45)]
    return [(x * size, z * size) for x, z in shape]


def the_void_one_eye(front, z, size, iris):
    """One huge eye bulging out of a round body's front."""
    disc(0.8 * size, (0, front, z), WHITE, height=0.36 * size, sides=14, sink=0.12 * size, roughness=0.2)
    disc(0.5 * size, (0, front - 0.24 * size, z), iris, height=0.17 * size, sides=12, sink=0.03 * size, roughness=0.3, emission=1.2)
    disc(0.29 * size, (0, front - 0.36 * size, z), INK, height=0.09 * size, stretch=1.25, sides=10, sink=0.03 * size, roughness=0.08)
    disc(0.13 * size, (-0.2 * size, front - 0.4 * size, z + 0.22 * size), WHITE, height=0.05 * size, sink=0.02, sides=6, roughness=0.2)
    disc(0.07 * size, (0.2 * size, front - 0.38 * size, z - 0.2 * size), WHITE, height=0.04 * size, sink=0.02, sides=5, roughness=0.2)


def shadow_wisp(c, a):
    # A lick of shadow: a teardrop whose top curls over, a ragged hem of darker tongues, a tail that trails off.
    lathe([(0, 2.25), (0.65, 2.1), (1.12, 1.65), (1.3, 1.15), (1.18, 0.65), (0.75, 0.32), (0, 0.2)], c, segments=14, roughness=0.3)
    front = -1.2
    tail([(0.1, 0.05, 2.05), (0.4, 0.05, 2.4), (0.8, 0.05, 2.55), (1.2, 0.05, 2.45), (1.42, 0.05, 2.15)], c, start=0.55, end=0.2)
    ball(0.24, (1.42, 0.05, 2.15), "E6D2FF", segments=8, emission=2)
    for index in range(7):  # the hem
        x, y = ring(index * 360 / 7 + 26, 0.85)
        cone(0.4, 0.8, (x, y, 0.75), (x * 0.9, y * 0.9, -1), a, sides=5)
    for side in (-1, 1):  # wispy arms
        cone(0.34, 0.85, (side * 1.1, -0.25, 1.0), (side * 1, -0.25, 0.55), a, sides=6)
    eyes(front, 1.4, 0.5, "E6D2FF", size=0.95)
    mouth(front + 0.08, 0.72, 0.34, "o")


def null_blob(c, a):
    # A heap of nothing in a glowing puddle: the "null" sign stands on its head and bits of it are being deleted.
    front = blob(c, w=2.4, d=2.1, h=1.6, puddle=a, bevel=0.75)
    hoop(0.55, 0.15, (0, 0, 2.3), a, rotation=(math.pi / 2, 0, 0), segments=12, emission=1)
    slab((0.16, 0.16, 1.6), (0, 0, 2.3), a, rotation=(0, math.radians(40), 0), emission=1)
    for x, y, z, size, colour in ((1.25, 0.0, 1.35, 0.44, c), (1.6, 0.1, 1.8, 0.32, a), (1.85, 0.0, 2.2, 0.2, c), (-1.3, 0.1, 1.2, 0.34, a), (-1.55, 0.0, 1.6, 0.22, c)):
        box((size, size, size), (x, y, z), colour, bevel=0.05, segments=1, rotation=(0.3, 0.4, 0.2), emission=1.5 if colour == a else 0)
    for x, z, r in ((-1.45, 0.25, 0.26), (1.4, 0.2, 0.2)):  # bubbles in the puddle
        ball(r, (x, -0.55, z), a, segments=8, emission=2)
    eyes(front, 1.02, 0.52, a, size=0.92)
    mouth(front, 0.45, 0.4, "flat")


def rift_stalker(c, a):
    # It stalks on six long pointed legs, and a rift has torn open along its back.
    dark = shade(c, -0.35)
    cube(2.4, 2.0, 1.4, 0.7, c, bevel=0.5)
    front = -1.0
    for side in (-1, 1):
        for y in (-0.62, 0.0, 0.62):
            knee = Vector((side * 1.85, y * 1.25, 1.95))
            tube(0.2, 1.15, (side * 1.0, y, 1.3), knee - Vector((side * 1.0, y, 1.3)), dark, vertices=6)
            ball(0.26, knee, dark, segments=8)
            cone(0.14, 0.4, knee + Vector((side * 0.2, 0, -1.6)), (side * 0.18, 0, -1), a, sides=6, emission=1)
            cone(0.28, 1.95, knee, (side * 0.18, 0, -1), dark, sides=6)
    plate([(-1.0, 0), (-0.62, 0.75), (-0.3, 0.35), (0.1, 1.15), (0.42, 0.5), (0.76, 0.9), (1.0, 0)], a, (0, 0.05, 2.0), thick=0.34, rotation=(0, 0, math.pi / 2), emission=0.8)
    plate([(-0.85, 0), (-0.5, 0.42), (-0.2, 0.15), (0.15, 0.6), (0.45, 0.22), (0.85, 0)], "FFC0FF", (0, 0.05, 2.0), thick=0.42, rotation=(0, 0, math.pi / 2), emission=2)
    eyes(front, 1.52, 0.52, a, size=0.86, brow=dark, tilt=-22)
    mouth(front, 0.98, 0.42, "fangs")


def void_eye(c, a):
    # One great eye that floats, lashes on its lid, tentacles trailing under it.
    ball(1.15, (0, 0, 1.75), c, segments=12, roughness=0.35)
    front = -0.86
    the_void_one_eye(front, 1.75, 1.0, a)
    hoop(0.86, 0.11, (0, front + 0.05, 1.75), a, rotation=(math.pi / 2, 0, 0), segments=14, emission=0.6)
    for lean in (-62, -30, 30, 62):  # lashes
        way = (math.sin(math.radians(lean)), -0.25, math.cos(math.radians(lean)))
        cone(0.24, 0.55, (way[0] * 1.0, -0.4, 1.75 + way[2] * 1.0), way, a, sides=5, emission=0.6)
    for index, (x, y) in enumerate(((-0.55, -0.2), (0.55, -0.2), (-0.25, 0.4), (0.3, 0.4))):
        sway = 0.25 if index % 2 else -0.25
        tail([(x, y, 0.78), (x * 1.3, y, 0.55), (x * 1.45 + sway, y, 0.4)], shade(c, -0.2), start=0.32, end=0.2, tip=a, tip_size=0.24)


def abyss_knight(c, a):
    # A small knight in dark plate: a helm with a plume of cold fire, a glowing sword, a shield.
    dark = shade(c, -0.3)
    front = biped(c, dark, w=1.9, d=1.7, h=2.0, legs=0.4, arm=False, foot=(0.7, 0.9, 0.42))
    helmet(dark, 2.08, 1.22, trim=a, squash=0.7)
    slab((0.2, 0.16, 0.6), (0, front - 0.08, 1.85), dark)  # nose guard
    flame((0, 0.15, 2.8), 0.42, 1.25, a, sides=6, rotation=(0.3, 0, 0), emission=1.5)
    box((2.0, 1.8, 0.28), (0, 0, 0.72), a, bevel=0.1, segments=1, emission=0.5)  # belt
    for side in (-1, 1):
        ball(0.5, (side * 1.12, 0, 1.55), dark, scale=(1, 1, 0.75), segments=8)
        box((0.42, 0.5, 0.75), (side * 1.2, -0.15, 1.05), c, bevel=0.16, segments=1)
        ball(0.3, (side * 1.28, -0.45, 0.75), dark, segments=8)
    # The sword, point up, in its right fist.
    tube(0.08, 0.45, (1.32, -0.6, 0.5), UP, dark, vertices=6)
    slab((0.72, 0.18, 0.15), (1.32, -0.6, 1.0), GOLD)
    plate([(-0.17, 0), (-0.17, 1.45), (0, 1.85), (0.17, 1.45), (0.17, 0)], a, (1.32, -0.6, 1.05), thick=0.12, emission=1.5)
    # The shield, on its left arm.
    tube(0.78, 0.16, (-1.3, -0.72, 1.0), (0, -1, 0), dark, vertices=6)
    tube(0.54, 0.1, (-1.3, -0.88, 1.0), (0, -1, 0), a, vertices=6, emission=0.8)
    star(0.3, (-1.3, -1.0, 1.0), GOLD, depth=0.1)
    eyes(front, 1.5, 0.43, a, size=0.8)
    mouth(front, 0.98, 0.34, "flat")


def rift_warden(c, a):
    # The keeper of the rift: hooded, a ring of keys on its belt, a lantern, a staff with a rift held in its hoop.
    dark = shade(c, -0.35)
    front = biped(c, dark, w=3.0, d=2.5, h=2.7, legs=0.5, arm=False, bevel=0.65, foot=(1.05, 1.3, 0.6))
    # The hood: a pointed cowl whose tip flops over, a glowing band round its rim.
    lathe([(0, 4.45), (0.4, 4.1), (1.1, 3.6), (1.72, 3.05), (1.78, 2.85), (0, 2.85)], dark, segments=12)
    tube(1.82, 0.24, (0, 0, 2.8), UP, a, vertices=12, emission=0.5)
    tail([(0.1, 0, 4.3), (0.45, 0.1, 4.55), (0.85, 0.15, 4.5)], dark, start=0.34, end=0.2, tip=a, tip_size=0.3)
    for side in (-1, 1):
        crystal((side * 1.5, 0, 3.0), 0.3, 1.2, a, lean=(side * 32, 0), emission=1.2)  # shards through the hood
        ball(0.78, (side * 1.7, 0, 2.3), dark, scale=(1, 1, 0.75), segments=10)
        box((0.62, 0.78, 1.0), (side * 1.85, -0.1, 1.5), c, bevel=0.25, segments=2)
        ball(0.5, (side * 1.95, -0.15, 0.95), dark, segments=8)
    box((3.1, 2.6, 0.36), (0, 0, 0.92), dark, bevel=0.12, segments=1)
    tube(0.3, 0.14, (0, front - 0.02, 0.92), (0, -1, 0), GOLD, vertices=8, roughness=0.3)
    # Keys.
    hoop(0.3, 0.07, (-0.95, front - 0.12, 0.6), GOLD, rotation=(math.pi / 2, 0, 0), segments=10)
    for dx, lean in ((-0.12, 0.25), (0.14, -0.2)):
        slab((0.1, 0.08, 0.6), (-0.95 + dx, front - 0.18, 0.1), GOLD, rotation=(0, lean, 0))
        slab((0.24, 0.08, 0.12), (-0.86 + dx * 2.2, front - 0.18, -0.12), GOLD)
    # The lantern in its left fist.
    tube(0.36, 0.12, (-2.0, -0.5, 0.52), UP, GOLD, vertices=8)
    ball(0.34, (-2.0, -0.5, 0.26), a, segments=8, emission=2.5)
    tube(0.36, 0.1, (-2.0, -0.5, -0.1), UP, GOLD, vertices=8)
    # The staff: a rift caught in a golden hoop.
    tube(0.12, 3.5, (2.3, -0.45, 0.1), UP, GOLD, vertices=6, roughness=0.3)
    hoop(0.85, 0.16, (2.3, -0.45, 4.2), GOLD, rotation=(math.pi / 2, 0, 0), segments=12, roughness=0.3)
    plate(the_void_tear(0.74), "FF3CC8", (2.3, -0.45, 4.2), thick=0.2, emission=0.8)
    plate(the_void_tear(0.4), "FFE0FF", (2.3, -0.5, 4.2), thick=0.24, emission=1.5)
    eyes(front, 2.15, 0.68, a, size=1.1, brow=dark, tilt=-22)
    mouth(front, 1.42, 0.8, "fangs")


def void_king(c, a):
    # The king of nothing: a tall crown, a cape with a high collar, a black hole in its belly, another on its sceptre.
    dark = shade(c, -0.3)
    front = biped(c, dark, w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.6, foot=(1.1, 1.3, 0.6))
    cape = [(-1.9, 0.1), (-2.15, 3.0), (-2.6, 4.4), (-1.35, 3.6), (0, 3.25), (1.35, 3.6), (2.6, 4.4), (2.15, 3.0), (1.9, 0.1), (0.95, 0.45), (0, 0.1), (-0.95, 0.45)]
    plate(cape, a, (0, 1.4, 0), thick=0.26)
    crown(3.3, radius=1.05, colour=GOLD, gems=a, points=5, size=1.5)
    for side in (-1, 1):
        ball(0.8, (side * 1.7, 0, 2.8), GOLD, scale=(1, 1, 0.75), segments=10, roughness=0.3)
        cone(0.28, 0.8, (side * 1.9, 0, 3.2), (side * 0.6, 0, 1), a, sides=6, emission=1)
        box((0.65, 0.8, 1.2), (side * 1.85, -0.1, 1.7), c, bevel=0.25, segments=2)
        ball(0.5, (side * 1.95, -0.15, 0.95), a, segments=8)
    # The black hole in its belly, in a ring of light.
    disc(0.66, (0, front, 1.0), a, height=0.1, sides=12, emission=2)
    disc(0.48, (0, front - 0.06, 1.0), "FFD0A0", height=0.08, sides=12, emission=2)
    disc(0.36, (0, front - 0.1, 1.0), INK, height=0.08, sides=10)
    # The sceptre: a little black hole with its ring.
    tube(0.12, 3.3, (2.3, -0.45, 0.2), UP, GOLD, vertices=6, roughness=0.3)
    ball(0.5, (2.3, -0.45, 3.95), dark, segments=10)
    hoop(0.78, 0.12, (2.3, -0.45, 3.95), a, rotation=(0.45, 0.35, 0), segments=12, emission=2)
    eyes(front, 2.45, 0.68, a, size=1.1, brow=GOLD, tilt=-26)
    mouth(front, 1.75, 0.8, "grin")


WORLDS["The Void"] = [
    ("Shadow Wisp", shadow_wisp, "9A6AF0", "5A34C0", "floater"),
    ("Null Blob", null_blob, "3F3796", "B45CFF", "walker"),
    ("Rift Stalker", rift_stalker, "9440E0", "F07AFF", "walker"),
    ("Void Eye", void_eye, "4E2488", "FF4488", "floater"),
    ("Abyss Knight", abyss_knight, "5560B4", "6FE0FF", "walker"),
    ("Rift Warden", rift_warden, "6E32C8", "FF7ADC", "boss"),
    ("Void King", void_king, "3E2280", "FF3C5A", "boss"),
]
BACKDROPS["The Void"] = "9DB2EC"
