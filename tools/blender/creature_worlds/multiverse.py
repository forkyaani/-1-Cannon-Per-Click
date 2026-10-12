# ---------------------------------------------------------------------------------------------------
# Multiverse (world 13). Run by ../creatures.py with all its pieces, faces, bodies and features to hand.
# Realities that overlap: mirrors, portals, glassy shards, things that are two things at once. Pink, teal, violet.
# ---------------------------------------------------------------------------------------------------
from mathutils import Euler

MULTIVERSE_PINK, MULTIVERSE_TEAL, MULTIVERSE_VIOLET, MULTIVERSE_GLASS = "FF4FA8", "22D8C8", "8A5CF0", "D6FBFF"


def multiverse_oval(at, radius, tall, thick, colour, **look):
    """An oval plate standing upright, facing the front: `tall` times as high as it is wide."""
    return lathe([(0, thick / 2), (radius, thick / 2), (radius, -thick / 2), (0, -thick / 2)], colour, segments=14, stretch=tall, location=at, rotation=(math.pi / 2, 0, 0), **look)


def multiverse_mirror(at, radius, tall, frame, glints=True):
    """A looking glass standing upright, facing the front: a thick frame, pale glass, two streaks of shine."""
    x, y, z = at
    multiverse_oval(at, radius, tall, 0.26, frame, roughness=0.3)
    multiverse_oval((x, y - 0.08, z), radius * 0.8, tall * 1.03, 0.2, "8FDCFF", roughness=0.08)
    if glints:
        for dx, long in ((-0.22, 0.75), (0.08, 0.45)):
            slab((0.13 * radius, 0.06, long * radius * tall), (x + dx * radius, y - 0.2, z + 0.1 * radius), WHITE, rotation=(0, math.radians(32), 0), emission=1.5)


def multiverse_portal(at, radius, rim, deep, swirl, facing=(math.pi / 2, 0, 0), thick=0.2, segments=14):
    """A portal: a glowing ring, a dark sheet in it, a paler ring of swirl. `facing` turns it (it lies flat at
    (0, 0, 0); the default stands it up to face the front)."""
    hoop(radius, thick, at, rim, rotation=facing, segments=segments, emission=1.2)
    if swirl:
        hoop(radius * 0.55, thick * 0.4, at, swirl, rotation=facing, segments=10, emission=2)
    lathe([(0, 0.04), (radius, 0.04), (radius, -0.04), (0, -0.04)], deep, segments=segments, location=at, rotation=facing)


def mirror_slime(c, a):
    # A shiny slime that has swallowed a looking glass: it stands up out of its head, as big as the slime is.
    front = blob(c, w=2.4, d=2.1, h=1.55, puddle=shade(c, -0.22), bevel=0.75, roughness=0.25)
    tuft(c, ((-1.05, -0.45, 0.3, 0.42), (1.1, -0.3, 0.28, 0.4), (0.9, 0.6, 0.3, 0.36)), roughness=0.25)
    multiverse_mirror((0.1, 0.35, 2.2), 0.78, 1.15, a)
    ball(0.24, (0.1, 0.35, 3.2), a, segments=8, roughness=0.3)  # the knob on its frame
    box((1.5, 0.75, 0.5), (0.1, 0.35, 1.55), c, bevel=0.24, segments=2, roughness=0.25)  # slime climbing the frame
    for x, long in ((-0.85, 0.5), (-0.62, 0.3)):  # the slime shines too
        slab((0.12, 0.06, long), (x, front - 0.01, 1.2), WHITE, rotation=(0, math.radians(30), 0))
    eyes(front, 0.95, 0.5, MULTIVERSE_PINK, size=0.9)
    mouth(front, 0.4, 0.42)


def glitch_bat(c, a):
    # A bat that did not load properly: square everywhere, a pink and a teal ghost of itself peeping out at each
    # side, its feet a slice out of line, stair-step wings of two colours and loose pixels drifting off them.
    box((2.0, 1.75, 1.5), (0.22, 0.14, 1.3), MULTIVERSE_PINK, bevel=0.3, segments=1)
    box((2.0, 1.75, 1.5), (-0.22, 0.14, 1.22), MULTIVERSE_TEAL, bevel=0.3, segments=1)
    cube(2.0, 1.75, 1.5, 0.5, c, bevel=0.32, seg=2)
    front = -0.875
    box((1.9, 1.6, 0.36), (0.42, 0, 0.2), c, bevel=0.1, segments=1)  # the slice that slipped
    box((0.5, 0.2, 0.2), (-0.95, -0.3, 0.2), MULTIVERSE_TEAL, bevel=0.05, segments=1)
    step = [(0, -0.1), (0, 0.9), (0.5, 0.9), (0.5, 1.35), (1.2, 1.35), (1.2, 1.0), (1.75, 1.0), (1.75, 0.45), (1.3, 0.45), (1.3, 0.05), (0.85, 0.05), (0.85, 0.4), (0.45, 0.4), (0.45, -0.1)]
    for side, colour in ((-1, MULTIVERSE_TEAL), (1, MULTIVERSE_PINK)):
        plate([(px * side * 1.1, pz * 1.1) for px, pz in step], colour, (side * 0.95, 0.3, 0.75), thick=0.2, rotation=(0, 0, side * math.radians(-14)))
        slab((0.5, 0.5, 0.75), (side * 0.62, 0.1, 2.3), c)  # square ears
        slab((0.26, 0.1, 0.45), (side * 0.62, -0.17, 2.3), colour)
        for dx, dz, size in ((2.75, 2.0, 0.3), (3.0, 1.3, 0.22), (2.6, 0.45, 0.24)):
            slab((size, size, size), (side * dx, 0.1, dz + (0.2 if side > 0 else 0)), colour, emission=1.2)
    eyes(front, 1.4, 0.48, a, size=0.92, blush=False)
    mouth(front, 0.78, 0.44, "fangs")


def portal_crab(c, a):
    # It carries a doorway to somewhere else on its back, and one of its claws already comes out of another.
    dark = shade(c, -0.3)
    front = crawler(c, dark, w=2.6, d=1.9, h=1.15, lift=0.3, legs=3)
    multiverse_portal((0, 0.3, 2.6), 1.2, a, "3A1C8A", MULTIVERSE_GLASS, thick=0.24, segments=12)
    box((1.3, 0.6, 0.4), (0, 0.3, 1.5), dark, bevel=0.14, segments=1)  # what holds it up
    for degrees in (35, 215):  # sparks of the other side
        x, z = ring(degrees, 0.55)
        star(0.17, (x, 0.2, 2.6 + z), WHITE, depth=0.06, emission=2)
    claws(c, dark, 1.55, -0.75, 0.85, size=1.15, sides=(-1,))
    # The other claw: out of a little portal of its own, beside it.
    multiverse_portal((2.3, -0.9, 1.35), 0.62, a, "3A1C8A", None, facing=(math.pi / 2, 0, math.radians(-30)), thick=0.14, segments=8)
    ball(0.5, (2.05, -1.35, 1.4), c, scale=(1, 0.85, 0.85), segments=8)
    cone(0.24, 0.7, (1.9, -1.6, 1.58), (-0.2, -1, 0.25), c)
    cone(0.2, 0.6, (2.2, -1.65, 1.24), (0.0, -1, -0.1), c)
    eyes(front, 1.02, 0.52, a, size=0.86)
    mouth(front, 0.5, 0.4)


def twin_wisp(c, a):
    # The same wisp from two worlds, a pink one and a teal one, chasing each other's tail round and round.
    def wisp(x, z, colour, side):
        ball(0.82, (x, 0, z), colour, scale=(1, 0.95, 1), segments=12, roughness=0.3, emission=0.3)
        # Its tail curls over the top towards its twin.
        for index in range(5):
            angle = math.radians(35 + index * 34)
            reach = 0.86 + index * 0.1
            ball(0.4 - index * 0.065, (x + side * math.cos(angle) * reach * 0.75 - side * 0.05 * index, 0.12, z + math.sin(angle) * reach), colour, segments=6, emission=0.3)
        for eye in (-1, 1):
            ex = x + eye * 0.3
            disc(0.3, (ex, -0.76, z + 0.08), WHITE, height=0.07, stretch=1.08, sides=10, sink=0.06, roughness=0.2)
            disc(0.24, (ex, -0.8, z + 0.07), INK, height=0.06, stretch=1.1, sides=10, sink=0.04, roughness=0.08)
            disc(0.14, (ex, -0.85, z + 0.02), WHITE if colour == c else GOLD, height=0.04, sink=0.02, sides=6, emission=1.5)
            disc(0.08, (ex - 0.08, -0.87, z + 0.17), WHITE, height=0.03, sink=0.02, sides=5)
        disc(0.1, (x, -0.8, z - 0.32), INK, stretch=1.2, sides=6)
        cone(0.3, 0.6, (x - side * 0.2, 0.05, z - 0.6), (side * 0.5, 0, -1), colour, sides=6, emission=0.3)  # the flick under it

    wisp(-0.88, 1.35, c, 1)
    wisp(0.88, 1.0, a, -1)
    hoop(1.95, 0.07, (0, 0, 1.15), WHITE, rotation=(0.3, 0.2, 0), segments=16, emission=2)  # the path they circle on
    for degrees, colour in ((60, c), (245, a)):
        x, y = ring(degrees, 1.95)
        point = Vector((x, y, 0))
        point.rotate(Euler((0.3, 0.2, 0)))
        star(0.24, Vector((0, 0, 1.15)) + point, colour, depth=0.1, emission=2)


def rift_golem(c, a):
    # A golem torn in two by a rift: its top half has slid sideways, the gap between the halves glows, shards of
    # the world it came through stick out of its shoulders.
    dark = shade(c, -0.3)
    cube(2.1, 1.8, 0.9, 0.4, c, bevel=0.35, seg=2, x=-0.45)
    feet(dark, 0.5, size=(0.8, 1.0, 0.45))
    for foot in made[-2:]:
        foot.location.x -= 0.45
    box((1.7, 1.45, 0.5), (-0.1, 0, 1.5), a, bevel=0.08, segments=1, emission=2.5)  # the rift
    for x, z in ((-0.95, 1.5), (0.75, 1.42)):
        star(0.2, (x, -0.8, z), WHITE, depth=0.06, emission=2)
    cube(2.1, 1.8, 1.45, 1.72, c, bevel=0.4, seg=2, x=0.25)
    front = -0.9
    zigzag = [(-0.14, 0.0), (0.2, 0.34), (-0.05, 0.46), (0.28, 0.95), (0.04, 0.5), (0.3, 0.38)]
    plate(zigzag, a, (0.95, front - 0.02, 2.3), thick=0.1, emission=2.5)  # a crack up its face
    for side in (-1, 1):
        crystal((0.25 + side * 0.85, 0.1, 3.07), 0.3, 0.95, MULTIVERSE_GLASS if side < 0 else a, lean=(side * 26, 0), emission=0.8)
        crystal((0.25 + side * 0.5, 0.3, 3.12), 0.2, 0.6, a if side < 0 else MULTIVERSE_GLASS, lean=(side * 10, 12), emission=0.8)
        # Arms that are not joined on: a stone each, floating.
        chunk((0.5, 0.52, 0.62), (side * 1.55 + (0.25 if side > 0 else -0.45), -0.15, 1.9 if side > 0 else 0.95), dark, detail=1)
    first = len(made)
    eyes(front, 2.47, 0.46, a, size=0.86, brow=dark, tilt=-16)
    mouth(front, 1.94, 0.4, "flat")
    for obj in made[first:]:  # the face is on the top half, which slid
        obj.location.x += 0.25


def paradox_knight(c, a):
    # Two knights who are one: pink down one side and teal down the other, each shoulder plate in the other one's
    # colour, a sword of glass in one fist and a looking-glass shield on the other arm.
    dark, deep = shade(c, -0.3), shade(a, -0.35)
    front = biped(c, dark, w=2.7, d=2.3, h=2.5, legs=0.5, arm=False, bevel=0.6, foot=(1.0, 1.2, 0.55))
    box((1.37, 2.34, 2.54), (0.68, 0, 1.75), a, bevel=0.6, segments=3)  # the other half
    box((1.04, 1.24, 0.57), (0.756, -0.2, 0.28), deep, bevel=0.2, segments=2)
    box((2.78, 2.38, 0.3), (0, 0, 0.95), MULTIVERSE_VIOLET, bevel=0.1, segments=1)  # the belt that holds them together
    disc(0.3, (0, front - 0.06, 0.95), GOLD, height=0.14, sides=6, emission=1)
    for side, plate_colour, arm_colour in ((-1, a, dark), (1, c, deep)):
        ball(0.75, (side * 1.55, 0, 2.6), plate_colour, scale=(1, 1, 0.75), segments=10)
        cone(0.24, 0.6, (side * 1.75, 0, 2.95), (side * 0.6, 0, 1), GOLD, sides=6)
        box((0.6, 0.72, 1.05), (side * 1.68, -0.1, 1.7), arm_colour, bevel=0.24, segments=2)
        ball(0.46, (side * 1.78, -0.2, 1.0), plate_colour, segments=8)
    # The helm: violet, a gold rim, a plume of both colours.
    helmet(MULTIVERSE_VIOLET, 2.85, 1.32, trim=GOLD, squash=0.6)
    box((0.26, 0.22, 0.6), (0, front - 0.05, 2.7), MULTIVERSE_VIOLET, bevel=0.08, segments=1)
    flame((-0.2, 0.2, 3.5), 0.42, 1.25, c, rotation=(0.3, -0.25, 0))
    flame((0.2, 0.2, 3.5), 0.42, 1.25, a, rotation=(0.3, 0.25, 0))
    # The shield.
    multiverse_mirror((-2.05, -1.05, 1.45), 0.95, 1.15, GOLD)
    # The sword: a shard of glass.
    tube(0.1, 0.55, (1.85, -0.5, 0.85), UP, MULTIVERSE_VIOLET, vertices=6)
    slab((0.8, 0.2, 0.17), (1.85, -0.5, 1.48), GOLD)
    plate([(-0.24, 0), (-0.3, 1.5), (0.1, 2.3), (0.3, 1.2), (0.24, 0)], MULTIVERSE_GLASS, (1.85, -0.5, 1.56), thick=0.14, emission=1.2, roughness=0.1)
    eyes(front, 2.05, 0.62, GOLD, size=1.05, brow=MULTIVERSE_VIOLET, tilt=-22)
    mouth(front, 1.35, 0.6, "flat")


def multiverse_hydra(c, a):
    # One hydra, three worlds: the middle head is its own, the pink one and the teal one reach in through portals
    # from the worlds next door. A crown on the middle one, a shard of glass on the end of its tail.
    dark = shade(c, -0.3)
    cube(3.2, 2.8, 2.1, 0.0, c, bevel=0.9, seg=2)
    front = -1.4
    for side in (-1, 1):
        box((0.95, 1.15, 0.55), (side * 0.85, -0.85, 0.28), dark, bevel=0.2, segments=2)
    disc(1.0, (0, front + 0.02, 0.95), shade(c, 0.4), height=0.07, stretch=0.8, sides=10)  # a pale belly

    def head(at, size, colour, iris, kind):
        x, y, z = at
        box((1.9 * size, 1.7 * size, 1.6 * size), at, colour, bevel=0.5 * size, segments=2)
        face = y - 0.85 * size
        for eye in (-1, 1):
            ex = x + eye * 0.46 * size
            disc(0.5 * size, (ex, face, z + 0.12 * size), WHITE, height=0.1 * size, stretch=1.08, sides=8, sink=0.04 * size, roughness=0.2)
            disc(0.41 * size, (ex, face - 0.075 * size, z + 0.1 * size), INK, height=0.08 * size, stretch=1.1, sides=8, sink=0.05 * size, roughness=0.08)
            disc(0.25 * size, (ex, face - 0.17 * size, z + 0.02 * size), iris, height=0.05 * size, sink=0.02 * size, sides=6, emission=1.5)
            disc(0.14 * size, (ex - 0.13 * size, face - 0.21 * size, z + 0.29 * size), WHITE, height=0.04 * size, sink=0.02 * size, sides=5)
            box((0.7 * size, 0.2, 0.19 * size), (ex, face - 0.13 * size, z + 0.74 * size), shade(colour, -0.35), bevel=0.06, segments=1, rotation=(0, eye * math.radians(-22), 0))
            cone(0.26 * size, 0.7 * size, (x + eye * 0.6 * size, y, z + 0.7 * size), (eye * 0.4, 0, 1), "FFF3D6", sides=6)  # horns
        slab((0.6 * size, 0.12, 0.13 * size), (x, face - 0.04, z - 0.5 * size), INK)
        for tooth in (-1, 1):
            cone(0.12 * size, 0.32 * size, (x + tooth * 0.2 * size, face - 0.1, z - 0.48 * size), (0, 0, -1), WHITE, sides=5)

    # The middle neck and head.
    for index, (y, z) in enumerate(((0.3, 2.2), (0.2, 2.75), (0.0, 3.25))):
        ball(0.72 - index * 0.06, (0, y, z), c if index % 2 == 0 else shade(c, 0.2), segments=8)
    head((0, -0.3, 4.0), 1.0, c, GOLD, "fangs")
    crown(4.78, radius=0.6, colour=GOLD, gems=a, points=5, y=-0.3, size=0.9)
    # The heads from next door, each through its portal.
    for side, colour in ((-1, MULTIVERSE_PINK), (1, MULTIVERSE_TEAL)):
        multiverse_portal((side * 2.25, 0.25, 2.2), 1.05, GOLD, "3A1C8A", None, facing=(math.pi / 2, 0, side * math.radians(-62)), thick=0.19, segments=10)
        for index, (x, y, z) in enumerate(((2.45, 0.1, 2.3),)):
            ball(0.55 - index * 0.04, (side * x, y, z), colour if index % 2 == 0 else shade(colour, 0.25), segments=8)
        head((side * 2.95, -0.55, 2.9), 0.84, colour, WHITE, "fangs")
    tail([(0.1, 1.6, 0.7), (0.4, 2.15, 0.95), (0.5, 2.5, 1.55)], dark, start=0.42, end=0.28)
    crystal((0.5, 2.5, 1.65), 0.32, 0.95, MULTIVERSE_GLASS, lean=(8, 16), emission=1)


WORLDS["Multiverse"] = [
    ("Mirror Slime", mirror_slime, "34D6C6", "FFC83C", "walker"),
    ("Glitch Bat", glitch_bat, "8A5CF0", "FFE45A", "floater"),
    ("Portal Crab", portal_crab, "FF5AA8", "30E6D2", "walker"),
    ("Twin Wisp", twin_wisp, "FF5CB0", "2EDCD0", "floater"),
    ("Rift Golem", rift_golem, "7C54E0", "3CF0DC", "walker"),
    ("Paradox Knight", paradox_knight, "FF4FA8", "22D0C4", "boss"),
    ("Multiverse Hydra", multiverse_hydra, "7A48E0", "FF5AB4", "boss"),
]
BACKDROPS["Multiverse"] = "F2C48E"
