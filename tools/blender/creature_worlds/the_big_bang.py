# ---------------------------------------------------------------------------------------------------
# The Big Bang (world 12). Run by ../creatures.py with all its pieces, faces, bodies and features to hand.
# The first things there ever were: a quark, an atom, a photon, antimatter, a titan that is not finished yet,
# the herald of chaos and the titan the universe came out of.
# ---------------------------------------------------------------------------------------------------
from mathutils import Euler

THE_BIG_BANG_STAR = "FFF2A8"  # the white-gold of new light


def the_big_bang_eye(x, front, z, iris, size=1.0):
    """One eye of `eyes`, for a face whose two eyes are not the same."""
    disc(0.5 * size, (x, front, z), WHITE, height=0.1 * size, stretch=1.08, sides=12, sink=0.04 * size, roughness=0.2)
    disc(0.41 * size, (x, front - 0.075 * size, z - 0.02 * size), INK, height=0.08 * size, stretch=1.1, sides=12, sink=0.05 * size, roughness=0.08)
    disc(0.25 * size, (x, front - 0.17 * size, z - 0.1 * size), iris, height=0.05 * size, sink=0.02 * size, sides=8, roughness=0.3, emission=1.5)
    disc(0.14 * size, (x - 0.13 * size, front - 0.21 * size, z + 0.17 * size), WHITE, height=0.04 * size, sink=0.02 * size, sides=6, roughness=0.2)
    disc(0.07 * size, (x + 0.16 * size, front - 0.2 * size, z - 0.16 * size), WHITE, height=0.03 * size, sink=0.02 * size, sides=5, roughness=0.2)


def the_big_bang_orbit(radius, thickness, centre, turn, colour, moons=(), segments=16, **look):
    """A ring round `centre`, turned by `turn` (x, y, z in degrees), with a ball on it for every moon:
    (where on the ring in degrees, its radius, its colour)."""
    spin = Euler([math.radians(angle) for angle in turn])
    hoop(radius, thickness, centre, colour, rotation=spin, segments=segments, **look)
    for degrees, size, moon in moons:
        point = Vector((math.cos(math.radians(degrees)) * radius, math.sin(math.radians(degrees)) * radius, 0))
        point.rotate(spin)
        ball(size, Vector(centre) + point, moon, segments=8, emission=1.5)


def the_big_bang_sparkle(long, short, waist=0.2):
    """The outline of a four-pointed twinkle: tall, with shorter side points."""
    return [(0, long), (waist, waist), (short, 0), (waist, -waist), (0, -long), (-waist, -waist), (-short, 0), (-waist, waist)]


def quark(c, a):
    # Never alone: a round red quark with its two partners (a green and a blue) on springy gluons, an "up" arrow
    # on its head.
    ball(1.15, (0, 0, 1.25), c, scale=(1, 0.95, 0.95), segments=14, roughness=0.3)
    front = -1.0
    feet(shade(c, -0.25), 0.5, size=(0.6, 0.8, 0.36), y=-0.15)
    disc(0.5, (-0.45, -0.3, 2.2), shade(c, 0.4), height=0.06, sides=8, towards=(-0.35, -0.3, 1))  # a shine
    arrow = [(-0.16, 0), (-0.16, 0.42), (-0.42, 0.42), (0, 0.95), (0.42, 0.42), (0.16, 0.42), (0.16, 0)]
    plate(arrow, a, (0, 0, 2.25), thick=0.22, emission=1.2)
    for side, colour, at in ((-1, "4FD86A", (-1.75, -0.25, 2.25)), (1, "4F9BFF", (1.8, -0.2, 0.75))):
        start = Vector((side * 0.95, -0.15, 1.75 if side < 0 else 1.0))
        end = Vector(at)
        for index in range(1, 4):  # the gluon: a zigzag of beads
            point = start.lerp(end, index / 4.2)
            ball(0.17, (point.x, point.y, point.z + (0.14 if index % 2 else -0.14)), a, segments=6, emission=1.2)
        ball(0.46, at, colour, segments=10, roughness=0.3)
        for eye in (-1, 1):
            disc(0.11, (at[0] + eye * 0.17, at[1] - 0.4, at[2] + 0.06), INK, height=0.04, sides=6)
    eyes(front, 1.45, 0.47, a, size=0.9)
    mouth(front - 0.04, 0.82, 0.4)


def atom_spinner(c, a):
    # The atom everyone draws: a knobbly nucleus with a face, three orbits round it and an electron on each.
    # It spins on a point, like a top.
    centre = (0, 0, 1.9)
    cone(0.5, 0.75, (0, 0, 0.95), (0, 0, -1), a, sides=8)
    ball(1.2, centre, c, scale=(1, 0.95, 0.95), segments=14, roughness=0.3)
    front = -1.07
    for x, y, z, r, colour in ((-0.8, 0.3, 2.7, 0.6, "FF5A7A"), (0.78, 0.35, 2.74, 0.56, shade(c, 0.45)), (0, 0.6, 3.0, 0.5, c), (-0.95, 0.35, 1.3, 0.5, shade(c, 0.45)), (0.98, 0.35, 1.32, 0.52, "FF5A7A")):
        ball(r, (x, y, z), colour, segments=8, roughness=0.3)
    for index, (turn, where) in enumerate(((0, 200), (60, 20), (120, 160))):
        the_big_bang_orbit(1.8, 0.13, centre, (14, turn, 0), a, moons=((where, 0.3, "8CF4FF"),), segments=18, emission=0.4)
    eyes(front, 2.05, 0.5, "8CF4FF", size=0.95)
    mouth(front - 0.06, 1.4, 0.36)


def photon_sprite(c, a):
    # A twinkle of light with a face, fairy wings, and the wave it travels as trailing under it.
    plate(the_big_bang_sparkle(1.75, 1.75, 0.5), THE_BIG_BANG_STAR, (0, 0.4, 1.9), thick=0.2, emission=2)
    plate(the_big_bang_sparkle(1.3, 1.3, 0.4), a, (0, 0.55, 1.9), thick=0.2, rotation=(0, math.radians(45), 0), emission=0.6)
    ball(1.1, (0, 0, 1.9), c, scale=(1, 0.85, 1), segments=14, roughness=0.3, emission=0.5)
    front = -0.88
    wings(THE_BIG_BANG_STAR, 0.8, 1.9, size=0.8, y=0.15, sweep=24, kind="round")
    for index in range(4):  # the wave: beads swinging from side to side, smaller as they go
        z = 0.72 - index * 0.26
        ball(0.3 - index * 0.04, (0.3 * math.sin(index * 1.6 + 0.8), 0.1 + index * 0.08, z), THE_BIG_BANG_STAR if index % 2 else a, segments=8, emission=1.5)
    for side in (-1, 1):
        ball(0.22, (side * 0.95, -0.5, 1.4), a, segments=6)  # little hands
    eyes(front, 2.05, 0.45, THE_BIG_BANG_STAR, size=0.9)
    mouth(front - 0.03, 1.42, 0.3, "o")


def antimatter_jelly(c, a):
    # A jellyfish of the wrong stuff: a deep violet bell that glows teal from inside, long beaded tentacles,
    # and a minus sign on its brow where a plus should be.
    hem = lambda angle: 1.2 + 0.1 * math.cos(math.radians(angle * 6))
    lathe([(0, 2.85), (0.75, 2.72), (1.25, 2.3), (1.42, 1.7), (lambda angle: 1.5, hem), (0, 1.5)], c, segments=18, roughness=0.25)
    front = -1.36
    tube(1.3, 0.14, (0, 0, 1.2), UP, a, vertices=12, emission=1.5)  # the glow under the bell
    for index in range(6):
        x, y = ring(index * 60 + 30, 0.9)
        length = 4 if index % 2 else 3
        for bead in range(length):
            sway = 0.12 * math.sin(bead * 1.7 + index)
            last = bead == length - 1
            ball(0.3 if last else 0.25 - bead * 0.02, (x + sway, y, 1.0 - bead * 0.3), a if last or bead % 2 else shade(c, 0.3), segments=6, emission=1.5 if last else 0.3)
    spot((-0.7, -0.3, 2.62), 0.2, a, towards=(-0.5, -0.3, 1), ring_colour=shade(c, 0.3))
    spot((0.75, 0.1, 2.58), 0.16, a, towards=(0.5, 0, 1), ring_colour=shade(c, 0.3))
    slab((0.5, 0.12, 0.15), (0, -0.98, 2.62), a, rotation=(math.radians(-38), 0, 0), emission=2)  # the minus
    eyes(front, 1.95, 0.48, a, size=0.88)
    mouth(front - 0.03, 1.42, 0.3, "o")


def proto_titan(c, a):
    # A titan that is still being made: a chubby giant-to-be with a newborn star for a heart, stone mittens and
    # boots too big for it, and the ring of dust and rubble it is growing out of still turning round its head.
    dark = shade(c, -0.3)
    front = biped(c, dark, w=2.0, d=1.8, h=1.9, legs=0.4, arm=False, bevel=0.6, foot=(0.85, 1.05, 0.5))
    for side in (-1, 1):
        box((0.42, 0.55, 0.7), (side * 1.22, -0.1, 1.3), dark, bevel=0.18, segments=1, rotation=(0, side * math.radians(-18), 0))
        chunk((0.5, 0.5, 0.46), (side * 1.42, -0.15, 0.8), shade(c, 0.3), detail=1)
        cone(0.26, 0.5, (side * 0.6, 0, 2.25), (side * 0.3, 0, 1), a, sides=6, emission=0.6)  # horn buds
    star(0.36, (0, front - 0.1, 0.78), a, depth=0.14, emission=2)
    the_big_bang_orbit(1.6, 0.12, (0, 0, 2.5), (14, -12, 0), a, segments=16, emission=1.2)
    spin = Euler((math.radians(14), math.radians(-12), 0))
    for degrees, size in ((250, 0.36), (320, 0.26), (30, 0.3), (130, 0.34), (190, 0.22)):
        point = Vector((math.cos(math.radians(degrees)) * 1.6, math.sin(math.radians(degrees)) * 1.6, 0))
        point.rotate(spin)
        chunk((size, size, size * 0.85), (point.x, point.y, point.z + 2.5), shade(c, 0.3) if size > 0.3 else dark, detail=1)
    eyes(front, 1.75, 0.46, a, size=0.9)
    mouth(front, 1.2, 0.34)


def chaos_herald(c, a):
    # The one who announces the end: a great jelly bell with odd eyes and odd horns, the eight arrows of chaos
    # standing behind its head, a herald's trumpet with a banner in one of its ragged arms.
    hem = lambda angle: 1.25 + 0.22 * math.cos(math.radians(angle * 5)) + 0.1 * math.sin(math.radians(angle * 2))
    lathe([(0, 3.6), (1.0, 3.45), (1.65, 2.9), (1.85, 2.1), (lambda angle: 1.9, hem), (0, 1.7)], c, segments=20, roughness=0.3)
    front = -1.8
    lathe([(0, 3.62), (0.7, 3.56), (1.15, 3.3), (0, 3.3)], shade(c, 0.3), segments=12)  # a paler cap
    for index, length in enumerate((4, 2, 4, 3, 4, 2, 3)):  # ragged tentacles, no two alike
        x, y = ring(index * 360 / 7 + 20, 1.15)
        for bead in range(length):
            last = bead == length - 1
            sway = 0.16 * math.sin(bead * 1.9 + index * 2.1)
            ball(0.32 - bead * 0.03, (x + sway, y, 1.3 - bead * 0.32), a if bead % 2 else shade(c, -0.2), segments=6)
        cone(0.2, 0.45, (x + sway, y, 1.3 - (length - 1) * 0.32), (sway, 0, -1), "FFD93A", sides=5, emission=1)
    # The star of chaos: eight arrows out of a hub, behind its head.
    hub = Vector((0, 1.1, 2.75))
    tube(0.55, 0.3, hub, (0, 1, 0), a, vertices=8)
    for index in range(8):
        angle = math.radians(index * 45)
        way = Vector((math.sin(angle), 0, math.cos(angle)))
        reach = 1.95 if index % 2 == 0 else 1.5
        tube(0.16, reach, hub + Vector((0, 0.15, 0)), way, a, vertices=5)
        cone(0.42, 0.65, hub + Vector((0, 0.15, 0)) + way * reach, way, "FFD93A" if index % 2 == 0 else a, sides=5, emission=0.8 if index % 2 == 0 else 0)
    # Odd horns: a big hooked one, a small stub.
    cone(0.42, 1.0, (-1.05, 0, 3.2), (-0.7, 0, 1), "FFF3D6")
    cone(0.26, 0.8, (-1.6, 0, 3.95), (0.5, 0, 1), "FFF3D6", sides=6)
    cone(0.32, 0.6, (1.1, 0, 3.25), (0.5, 0, 1), "FFF3D6", sides=6)
    # Odd eyes, a crooked brow over each, a grin full of teeth.
    the_big_bang_eye(-0.72, front, 2.55, "FFD93A", size=1.35)
    the_big_bang_eye(0.8, front, 2.7, "8CF4FF", size=0.85)
    box((0.95, 0.22, 0.24), (-0.72, front - 0.16, 3.38), a, bevel=0.08, segments=1, rotation=(0, math.radians(22), 0))
    box((0.62, 0.22, 0.2), (0.8, front - 0.12, 3.25), a, bevel=0.07, segments=1, rotation=(0, math.radians(14), 0))
    for side in (-1, 1):
        disc(0.22, (side * 1.4, front + 0.04, 1.95), BLUSH, height=0.05, stretch=0.6, sides=8)
    mouth(front - 0.02, 1.72, 0.95, "grin")
    # The trumpet: a long gold horn held out to its right, a banner hanging from it.
    ball(0.42, (1.95, -0.9, 2.0), shade(c, -0.2), segments=8)
    tube(0.16, 1.5, (1.95, -0.6, 2.05), (0.25, -1, 0.3), GOLD, vertices=6, roughness=0.3)
    tube(0.18, 0.8, (2.3, -1.98, 2.46), (0.25, -1, 0.3), GOLD, tip=0.85, vertices=8, roughness=0.3)
    plate([(0, 0), (1.0, 0), (1.0, -1.2), (0.5, -0.85), (0, -1.2)], a, (1.9, -1.2, 2.15), thick=0.1, rotation=(0, 0, math.radians(76)))
    ball(0.16, (1.95, -0.6, 2.05), GOLD, segments=6)


def genesis_titan(c, a):
    # The titan everything came out of: night-coloured and sprinkled with stars, the Big Bang itself bursting
    # from its chest, ringed planets for shoulders, a whole little solar system turning round its head, and
    # the first star held up in its fist.
    dark = shade(c, -0.3)
    front = biped(c, dark, w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.6, foot=(1.1, 1.3, 0.6), roughness=0.4)
    # The bang: a white-hot heart in a ring of long and short gold rays.
    tube(0.62, 0.12, (0, front + 0.02, 1.3), (0, -1, 0), a, vertices=10, emission=1.5)
    ball(0.42, (0, front - 0.12, 1.3), THE_BIG_BANG_STAR, scale=(1, 0.6, 1), segments=8, emission=3)
    rays((0, front - 0.02, 1.3), 0.5, a, count=8, size=0.8, sides=4, emission=1.5)
    rays((0, front - 0.02, 1.3), 0.5, THE_BIG_BANG_STAR, count=8, size=0.5, start=22.5, sides=4, emission=2)
    # Shoulders: a planet each, with its ring. Arms of night, fists of gold.
    for side, planet in ((-1, "FF5A9A"), (1, "3FD0E0")):
        ball(0.82, (side * 1.75, 0, 2.95), planet, scale=(1, 1, 0.85), segments=10, roughness=0.35)
        the_big_bang_orbit(1.15, 0.09, (side * 1.75, 0, 2.95), (20, side * 22, 0), THE_BIG_BANG_STAR, segments=12, emission=1)
        box((0.65, 0.8, 1.15), (side * 1.88, -0.1, 1.75), dark, bevel=0.25, segments=1)
        ball(0.52, (side * 1.98, -0.15, 0.98), a, segments=8, roughness=0.3)
    # Stars on its skin.
    for x, z, size in ((-1.05, 0.75, 0.2), (1.1, 1.0, 0.16), (-1.15, 1.75, 0.14), (1.2, 2.0, 0.2), (0.95, 3.02, 0.14), (-0.3, 3.08, 0.12)):
        star(size, (x, front - 0.03, z), THE_BIG_BANG_STAR, depth=0.06, emission=2)
    # Its crown: a tall gold spike with a shorter one each side, a solar system turning round the lot.
    tube(1.0, 0.3, (0, 0, 3.28), UP, a, vertices=12, roughness=0.3)
    crystal((0, 0, 3.5), 0.4, 1.7, a, sides=6, emission=0.8)
    for side in (-1, 1):
        crystal((side * 0.62, 0, 3.5), 0.28, 1.0, THE_BIG_BANG_STAR, lean=(side * 22, 0), emission=1.5)
    the_big_bang_orbit(2.25, 0.1, (0, 0, 4.1), (16, 10, 0), THE_BIG_BANG_STAR, moons=((255, 0.36, "FF5A9A"), (20, 0.3, "5AE0FF"), (150, 0.26, "7CF07C")), segments=18, emission=1)
    eyes(front, 2.4, 0.7, a, size=1.1, brow=a, tilt=-22)
    mouth(front, 2.05, 0.7, "fangs")
    # The first star, held high in its left fist.
    box((0.6, 0.7, 0.8), (-2.2, -0.35, 1.5), dark, bevel=0.2, segments=1, rotation=(0, math.radians(30), 0))
    star(0.7, (-2.55, -0.5, 2.55), THE_BIG_BANG_STAR, depth=0.3, emission=2.5)


WORLDS["The Big Bang"] = [
    ("Quark", quark, "F0424E", "FFE27A", "walker"),
    ("Atom Spinner", atom_spinner, "3A94F5", "2A46C8", "floater"),
    ("Photon Sprite", photon_sprite, "FF9A1E", "E8482A", "floater"),
    ("Antimatter Jelly", antimatter_jelly, "5A2CA6", "2CE0C8", "floater"),
    ("Proto Titan", proto_titan, "A84CE6", "FF9028", "walker"),
    ("Chaos Herald", chaos_herald, "E23CA4", "6A30C0", "boss floater"),
    ("Genesis Titan", genesis_titan, "3A30B0", "FFB01E", "boss"),
]
BACKDROPS["The Big Bang"] = "86D2B4"
