# World 11, "Black Hole": run by ../creatures.py with all its pieces, faces, bodies and features to hand.
# The world's own things are accretion rings (glowing orange and gold round something deep indigo), orbits with
# captured motes, clocks (time runs wrong here) and portals.
from mathutils import Euler

BLACK_HOLE_DEEP = "2A1466"  # what is "black" here: a deep saturated indigo
BLACK_HOLE_GOLD = "FFE45A"
BLACK_HOLE_PINK = "FF5AA8"


def black_hole_orbit(at, radius, tilt, colour, thick=0.08, motes=(), segments=14, emission=1.5):
    """A thin ring round `at`, tilted (about x, about y) in radians, with motes on it: (degrees, radius, colour);
    180 degrees is the front."""
    turn = Euler((tilt[0], tilt[1], 0))
    hoop(radius, thick, at, colour, rotation=turn, segments=segments, emission=emission)
    for degrees, size, mote in motes:
        x, y = ring(degrees, radius)
        point = Vector((x, y, 0))
        point.rotate(turn)
        ball(size, Vector(at) + point, mote, segments=6, emission=0.8)


def black_hole_disc(at, inner, outer, colour, tilt=(0, 0), thick=0.1, segments=16, emission=1.5):
    """A flat wide ring lying round `at`: an accretion disc."""
    lathe([(inner, thick), (outer, thick * 0.4), (outer, -thick * 0.4), (inner, -thick), (inner, thick)], colour, segments=segments, location=at, rotation=Euler((tilt[0], tilt[1], 0)), emission=emission)


def dark_matter_blob(c, a):
    # A heap of something unseen: lumpy violet, a tiny black hole sunk in its head, a ring of motes circling it.
    front = blob(c, w=2.3, d=2.1, h=1.7, puddle=shade(c, -0.4), bevel=0.8)
    tuft(shade(c, -0.22), ((-1.0, 0.35, 0.45, 0.5), (1.05, 0.25, 0.4, 0.46), (-0.75, 0.5, 1.55, 0.4)))
    hoop(0.5, 0.14, (0.25, 0.0, 1.74), a, rotation=(0.2, 0.15, 0), segments=12, emission=2)
    ball(0.42, (0.25, 0.0, 1.76), BLACK_HOLE_DEEP, scale=(1, 1, 0.6), segments=10)
    black_hole_orbit((0, 0, 0.85), 1.75, (0.3, 0.12), a, thick=0.07, motes=((150, 0.2, BLACK_HOLE_DEEP), (75, 0.24, BLACK_HOLE_DEEP), (255, 0.17, BLACK_HOLE_GOLD), (330, 0.22, BLACK_HOLE_DEEP), (20, 0.14, BLACK_HOLE_GOLD)))
    spot((0.92, front + 0.03, 1.42), 0.14, shade(c, 0.4))
    spot((-0.95, front + 0.03, 0.4), 0.11, shade(c, 0.4))
    eyes(front, 1.05, 0.5, a, size=0.9)
    mouth(front, 0.5, 0.42)


def gravity_mite(c, a):
    # A little bug that carries its own gravity: a beam from its back holds up a ringed moon, pebbles rise with it.
    dark = shade(c, -0.38)
    front = crawler(c, dark, w=2.3, d=1.9, h=1.15, lift=0.3, legs=3)
    for y in (0.15, 0.7):  # the plates of its shell
        box((2.42, 0.26, 1.22), (0, y, 0.9), dark, bevel=0.1, segments=1)
    for side in (-1, 1):
        cone(0.2, 0.6, (side * 0.75, front + 0.05, 0.5), (-side * 0.45, -1, -0.1), a, sides=6)  # mandibles
    antennae(dark, a, 0.55, 1.4, height=0.7, lean=34, y=-0.65, bulb=0.17)
    tube(0.55, 0.85, (0, 0.25, 1.42), UP, "FFF6C8", tip=0.3, vertices=8, emission=1.5)
    ball(0.56, (0, 0.25, 2.6), "8E5CF0", segments=10)
    hoop(0.9, 0.09, (0, 0.25, 2.6), a, rotation=(0.4, 0.25, 0), segments=12, emission=1)
    rocks(dark, ((-0.8, 0.1, 1.85, 0.2), (0.85, 0.45, 2.05, 0.16)))
    eyes(front, 1.0, 0.5, "FF7A3C", size=0.85)
    mouth(front, 0.48, 0.36)


def time_eater(c, a):
    # A jellyfish with an alarm clock for a crown and a mouth full of teeth: it eats the hours.
    lathe([(0, 2.3), (0.8, 2.15), (1.3, 1.7), (1.45, 1.15), (1.35, 0.8), (0, 0.95)], c, segments=16, roughness=0.3, emission=0.15)
    front = -1.38
    hoop(1.36, 0.15, (0, 0, 0.86), a, segments=14)
    for degrees, reach in ((40, 0.85), (115, 0.7), (180, 0.8), (245, 0.7), (320, 0.85)):
        x, y = ring(degrees, 0.85)
        tube(0.2, reach, (x, y, 0.85), (x * 0.25, y * 0.25, -1), shade(c, -0.14), tip=0.09, vertices=6)
        ball(0.15, (x * (1 + 0.25 * reach), y * (1 + 0.25 * reach), 0.85 - reach), a, segments=6, emission=1.5)
    # The clock: an orange case, a cream face, two hands, two bells and a knob.
    tube(0.68, 0.3, (0, 0.2, 2.75), (0, -1, 0), a, vertices=12, roughness=0.3)
    tube(0.54, 0.06, (0, -0.1, 2.75), (0, -1, 0), "FFF6DC", vertices=12)
    slab((0.1, 0.06, 0.42), (0, -0.19, 2.93), INK)
    slab((0.3, 0.06, 0.1), (0.12, -0.19, 2.75), INK)
    for x, z in ((0, 0.43), (0.43, 0), (0, -0.43), (-0.43, 0)):
        slab((0.09, 0.05, 0.09), (x, -0.17, 2.75 + z), a)
    for side in (-1, 1):
        ball(0.26, (side * 0.52, 0.05, 3.32), BLACK_HOLE_GOLD, scale=(1, 1, 0.8), segments=8, roughness=0.3)
    tube(0.09, 0.3, (0, 0.05, 3.4), UP, a, vertices=6)
    eyes(front, 1.52, 0.5, a, size=0.9)
    mouth(front - 0.02, 0.98, 0.72, "grin")


def warp_wraith(c, a):
    # A ghost half way out of a portal: the ring stands behind it, its tail still twists back through.
    tube(1.3, 0.1, (0, 0.75, 1.95), (0, 1, 0), "1C3CA8", vertices=14)
    hoop(1.4, 0.2, (0, 0.72, 1.95), a, rotation=(math.pi / 2, 0, 0), segments=14, emission=0.6)
    hoop(1.0, 0.07, (0, 0.66, 1.95), "B6F6FF", rotation=(math.pi / 2, 0, 0), segments=12, emission=2)
    ball(1.0, (0, -0.1, 2.0), c, scale=(1, 0.95, 1.05), segments=12, roughness=0.3, emission=0.25)
    front = -1.03
    for index in range(6):  # the tail: a corkscrew that thins away
        angle = index * 1.25
        reach = 0.42 * (1 - index / 9)
        ball(0.62 - index * 0.09, (math.sin(angle) * reach, 0.05 + math.cos(angle) * reach * 0.6, 1.3 - index * 0.24), c if index % 2 == 0 else shade(c, -0.18), segments=8, emission=0.25)
    cone(0.5, 0.9, (0.1, 0.0, 2.8), (0.35, 0.3, 1), c, sides=7, emission=0.25)  # a wisp flicking off its head
    for side in (-1, 1):
        cone(0.38, 1.0, (side * 0.8, -0.35, 1.85), (side, -0.45, -0.2), c, sides=6, emission=0.25)  # reaching sleeves
        ball(0.2, (side * 1.85, -0.82, 1.65), "B6F6FF", segments=6, emission=1.5)
    eyes(front, 2.08, 0.42, "FFFFFF", size=0.84, blush=False, brow=a, tilt=-16)
    mouth(front, 1.5, 0.3, "o")


def horizon_knight(c, a):
    # A knight in orange plate with a deep indigo helm: his shield is an event horizon, his sword a beam of light.
    front = biped(c, a, w=1.9, d=1.7, h=1.9, legs=0.4, arm=False, bevel=0.5, foot=(0.7, 0.9, 0.42))
    box((1.98, 1.78, 0.28), (0, 0, 0.85), a, bevel=0.1, segments=1)  # belt
    disc(0.2, (0, front - 0.02, 0.85), BLACK_HOLE_GOLD, height=0.1, sides=6, emission=1.5)
    helmet(a, 2.05, 1.08, trim=BLACK_HOLE_GOLD, squash=0.7)
    box((0.22, 0.2, 0.6), (0, front - 0.06, 1.85), a, bevel=0.07, segments=1)  # nose guard
    flame((0, 0.15, 2.7), 0.36, 1.0, BLACK_HOLE_PINK, rotation=(0.35, 0, 0))  # plume
    for side in (-1, 1):
        ball(0.5, (side * 1.08, 0, 1.75), a, scale=(1, 1, 0.75), segments=8)
        box((0.42, 0.52, 0.8), (side * 1.2, -0.15, 1.2), shade(c, -0.2), bevel=0.16, segments=1)
        ball(0.3, (side * 1.25, -0.3, 0.8), a, segments=6)
    # The shield: indigo, a ring of light round a dark heart.
    tube(0.85, 0.18, (-1.4, -0.75, 1.15), (0, -1, 0), a, vertices=12)
    hoop(0.5, 0.13, (-1.4, -0.96, 1.15), BLACK_HOLE_GOLD, rotation=(math.pi / 2, 0, 0), segments=12, emission=2)
    tube(0.36, 0.05, (-1.4, -0.93, 1.15), (0, -1, 0), BLACK_HOLE_DEEP, vertices=10)
    # The sword.
    tube(0.09, 0.5, (1.3, -0.45, 0.7), UP, a, vertices=6)
    slab((0.6, 0.16, 0.14), (1.3, -0.45, 1.25), BLACK_HOLE_GOLD)
    box((0.26, 0.12, 1.5), (1.3, -0.45, 2.05), "FFF3A0", bevel=0.05, segments=1, emission=2)
    cone(0.15, 0.3, (1.3, -0.45, 2.78), UP, "FFF3A0", sides=4, emission=2)
    eyes(front, 1.5, 0.44, a, size=0.8, blush=False)
    mouth(front, 0.98, 0.34, "flat")


def graviton(c, a):
    # Gravity itself: a pale spiked ball that everything falls round. Two orbits of captured rocks circle it.
    ball(1.5, (0, 0, 1.9), c, scale=(1, 0.95, 0.95), segments=14, roughness=0.3)
    front = -1.37
    spikes = [(90, 0, 1.35)] + [(50, az, 1.0) for az in (0, 60, 120, 180, 240, 300)] + [(5, az, 1.1) for az in (0, 50, 100, 260, 310)] + [(-45, az, 0.9) for az in (0, 90, 180, 270)] + [(-90, 0, 1.0)]
    for elevation, azimuth, size in spikes:
        x, y = ring(azimuth, math.cos(math.radians(elevation)))
        way = Vector((x, y, math.sin(math.radians(elevation))))
        cone(0.45 * size, 1.05 * size, Vector((0, 0, 1.9)) + Vector((way.x * 1.32, way.y * 1.25, way.z * 1.25)), way, a, sides=6, emission=0.4)
    violet = "7A5CE0"
    black_hole_orbit((0, 0, 1.9), 2.55, (0.42, 0.3), BLACK_HOLE_PINK, thick=0.08, segments=16, motes=((140, 0.26, violet), (215, 0.2, BLACK_HOLE_GOLD), (20, 0.3, violet), (290, 0.22, violet)))
    black_hole_orbit((0, 0, 1.9), 2.2, (0.35, -0.5), BLACK_HOLE_GOLD, thick=0.07, segments=16, motes=((200, 0.22, violet), (80, 0.26, violet), (320, 0.18, BLACK_HOLE_PINK)))
    disc(0.26, (0, front + 0.12, 2.9), a, height=0.12, sides=6, emission=2)
    eyes(front, 2.1, 0.62, a, size=1.1, brow=violet, tilt=-24)
    mouth(front + 0.06, 1.32, 0.7, "fangs")


def star_devourer(c, a):
    # The black hole with a face: a deep indigo heap sitting in its own accretion disc, a star between its teeth,
    # the stars it has already swallowed shining through its skin, and three more circling its horns.
    front = blob(c, w=3.4, d=3.0, h=3.1, bevel=1.1)
    black_hole_disc((0, 0, 0.3), 1.9, 2.75, a, tilt=(0.05, 0.1), thick=0.14, emission=1.2)
    black_hole_disc((0, 0, 0.36), 1.5, 2.05, BLACK_HOLE_GOLD, tilt=(0.05, 0.1), thick=0.12, emission=2)
    # The mouth, wide open, and the star in it.
    box((2.0, 0.3, 1.0), (0, front + 0.06, 1.05), INK, bevel=0.14, segments=1)
    for index in range(5):
        cone(0.17, 0.4, ((index - 2) * 0.4, front - 0.08, 1.5), (0, 0, -1), WHITE, sides=5)
    for index in range(4):
        cone(0.17, 0.36, ((index - 1.5) * 0.44, front - 0.08, 0.6), UP, WHITE, sides=5)
    star(0.42, (0.1, front - 0.2, 1.05), BLACK_HOLE_GOLD, depth=0.2, rotation=(0, 0.3, 0), emission=2)
    for x, z, r in ((-1.2, 1.5, 0.1), (1.25, 1.2, 0.13), (-0.9, 2.85, 0.09), (1.3, 2.75, 0.08), (-1.4, 0.8, 0.08)):
        disc(r, (x, front + 0.12, z), BLACK_HOLE_GOLD, height=0.05, sides=5, emission=2)
    for side in (-1, 1):
        # Horns that hook inwards.
        cone(0.5, 1.1, (side * 1.15, 0, 2.85), (side * 0.8, 0, 1), a, emission=0.5)
        cone(0.3, 0.9, (side * 1.85, 0, 3.6), (-side * 0.4, 0, 1), a, sides=6, emission=0.5)
        # Stubby arms.
        box((0.7, 0.85, 1.1), (side * 1.9, -0.2, 1.55), shade(c, 0.18), bevel=0.28, segments=2, rotation=(0, side * math.radians(-20), 0))
        ball(0.5, (side * 2.15, -0.3, 0.95), a, segments=8)
    black_hole_orbit((0, 0, 3.75), 1.25, (0.3, 0.0), BLACK_HOLE_PINK, thick=0.07, segments=14)
    for degrees in (180, 300, 60):
        x, y = ring(degrees, 1.25)
        star(0.3, (x, y * math.cos(0.3), 3.75 + y * math.sin(0.3)), BLACK_HOLE_GOLD, depth=0.14, emission=2)
    eyes(front, 2.25, 0.8, a, size=1.15, brow=shade(c, 0.35), tilt=-26)


WORLDS["Black Hole"] = [
    ("Dark Matter Blob", dark_matter_blob, "7B4FE8", "FF963C", "walker"),
    ("Gravity Mite", gravity_mite, "FFC466", "FFF6DC", "walker"),
    ("Time Eater", time_eater, "EDE4FF", "FF963C", "floater"),
    ("Warp Wraith", warp_wraith, "55DDE8", "2A72C8", "floater"),
    ("Horizon Knight", horizon_knight, "FFA02E", "3A2C8A", "walker"),
    ("Graviton", graviton, "E6E0FF", "FFA83C", "boss floater"),
    ("Star Devourer", star_devourer, "35207A", "FF8C28", "boss"),
]
BACKDROPS["Black Hole"] = "A8527F"
