"""Worlds 13 to 15 (Update 1, 12 Oct: Multiverse, Time Warp, Infinity): everything island.py and base.py
build for them that the twelve older worlds do not have. One file for both, so an island and its base wear
the same things: the tall props that stand where Earth has trees, the fence, what is on the liquid, the
two set pieces of each world, and the big pieces that hang in its sky.

    import worlds_13_to_15 as w13
    w13.theme(THEME)                 # the world's row of themes.py, before anything is built
    w13.TREES["twin_ring"](leaf, "round")

Nothing here runs for worlds 1 to 12, and nothing here changes kit.py: every piece is made with the kit's
own primitives. A prop is built around its own origin, standing on z = 0, its front towards -Y, as the kit
has it; colours not in the theme are the same in every world (WHITE, GOLD) or named where they are used.

    Multiverse   overlapping realities: every landmark has a double from another world. Pink, teal, violet.
    Time Warp    clockwork: gears, clock faces, pendulums, an hourglass. Brass and amber on deep blue.
    Infinity     the end of everything: white marble and gold, loops like an 8 on its side, stairs that go
                 on up, a soft rainbow at the edges.
"""
import math

from mathutils import Matrix, Vector

from kit import *

T = {}  # the world's theme: set by theme()
WHITE, GOLD, GOLD_DARK = "FFFFFF", "FFC61A", "E09A12"
RAINBOW = ("FF9CB4", "FFC88C", "FFF0A0", "B4F0C0", "9CD8FF", "C8B4FF")  # Infinity's soft rainbow: pink, peach, lemon, mint, sky, lilac
CREAM, HAND = "FFF4D8", "1E2C7C"  # Time Warp: a clock's face and its hands
SAND, GLASS = "FFB428", "CFEAFF"  # Time Warp: what runs through the hourglass, and its glass
OTHER_WORLD = "FF8AD8"  # Multiverse: the world that shows in a mirror pool


def theme(table):
    """The theme the props are built in: a world's row of themes.py (base.py hands over its own stone)."""
    T.clear()
    T.update(table)


# ---------------------------------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------------------------------
def moved(first, frame):
    """Moves every piece made since `first` (len(made) before them) by a matrix."""
    for obj in made[first:]:
        obj.matrix_basis = frame @ obj.matrix_basis


def gem(radius, height, at, colour, lean=UP, sides=4, **look):
    """A shard with two points, base to base: its waist is at `at`, its long point along `lean`."""
    lean = Vector(lean).normalized()
    tube(radius, height * 0.62, at, lean, colour, tip=0.0, vertices=sides, **look)
    tube(radius, height * 0.38, at, -lean, colour, tip=0.0, vertices=sides, **look)


def sag(a, b, height, drop, radius, colour, **look):
    """A chain hanging between two posts' feet, `height` up at its ends and `drop` lower in the middle."""
    start, end = Vector(a) + Vector((0, 0, height)), Vector(b) + Vector((0, 0, height))
    middle = (start + end) / 2 - Vector((0, 0, drop))
    for p, q in ((start, middle), (middle, end)):
        tube(radius, (q - p).length, p, q - p, colour, vertices=4, **look)


def pipe(points, radius, colour, around=8, closed=False, **look):
    """A round bar along a line of points that lie in a plane, or nearly: a loop when `closed`."""
    points = [Vector(point) for point in points]
    count = len(points)
    spread = [max(point[axis] for point in points) - min(point[axis] for point in points) for axis in range(3)]
    across = Vector([1.0 if axis == spread.index(min(spread)) else 0.0 for axis in range(3)])  # out of the line's plane: no twist, and a loop closes on itself
    vertices = []
    for index, point in enumerate(points):
        before = points[index - 1] if (closed or index) else point
        after = points[(index + 1) % count] if (closed or index < count - 1) else point
        along = (after - before).normalized()
        normal = along.cross(across).normalized()
        other = along.cross(normal)
        for turn in range(around):
            a = turn * 2 * math.pi / around
            vertices.append(point + (normal * math.cos(a) + other * math.sin(a)) * radius)
    faces = []
    for index in range(count if closed else count - 1):
        a, b = index * around, ((index + 1) % count) * around
        faces += [(a + turn, a + (turn + 1) % around, b + (turn + 1) % around, b + turn) for turn in range(around)]
    if not closed:
        faces += [tuple(range(around)), tuple(range((count - 1) * around, count * around))]
    return mesh(vertices, faces, colour, tidy=True, **look)


def eight(wide, weave=0.0, steps=28, flat=False):
    """The points of a loop like an 8 on its side, `wide` to each side and half as high as it is wide in
    all: upright, facing the front, or lying `flat`. `weave` lifts one strand over the other where they cross."""
    points = []
    for step in range(steps):
        t = step * 2 * math.pi / steps
        x, y, z = wide * math.cos(t), weave * math.sin(t), wide * math.sin(t) * math.cos(t)
        points.append((x, z, y) if flat else (x, y, z))
    return points


def cog(radius, depth, at, colour, teeth=8, turn=0.0, spin=0.0, hub=None, flat=False, **look):
    """A gear standing upright, its face to the front (-Y), turned `turn` round; or lying `flat`."""
    count = teeth * 3  # a tooth is two corners out and one in: chunky, and cheap
    outline = []
    for index in range(count):
        a = spin + (index // 3 + (0.18, 0.5, 0.82)[index % 3]) * 2 * math.pi / teeth
        reach = radius * 0.72 if index % 3 == 0 else radius
        outline.append((reach * math.sin(a), reach * math.cos(a)))
    vertices = [(x, -depth / 2, z) for x, z in outline] + [(x, depth / 2, z) for x, z in outline] + [(0, -depth / 2, 0), (0, depth / 2, 0)]
    faces = [(2 * count, index, (index + 1) % count) for index in range(count)] + [(2 * count + 1, count + (index + 1) % count, count + index) for index in range(count)]
    faces += [(index, count + index, count + (index + 1) % count, (index + 1) % count) for index in range(count)]
    first = len(made)
    mesh(vertices, faces, colour, smooth=False, tidy=True, **look)
    if hub:
        tube(radius * 0.34, depth + 0.5, (0, depth / 2 + 0.25, 0), (0, -1, 0), hub, vertices=8, roughness=0.3)
    moved(first, Matrix.Translation(at) @ Matrix.Rotation(turn, 4, "Z") @ (Matrix.Rotation(math.pi / 2, 4, "X") if flat else Matrix.Identity(4)))


def dial(radius, y, hour=10.0, minute=2.0, face=CREAM, rim=True):
    """A clock's face round the origin, looking to the front, its surface at `y`: a gold rim, twelve marks,
    two hands. `hour` and `minute` are where the hands point, on the clock's own twelve."""
    size = radius / 3.6
    tube(radius, 0.3, (0, y + 0.15, 0), (0, -1, 0), face, vertices=16)
    if rim:
        hoop(radius * 1.03, radius * 0.09, (0, y, 0), GOLD, rotation=(math.pi / 2, 0, 0), segments=16, roughness=0.3)
    for index in range(12):
        x, z = ring(index * 30, radius * 0.8)
        big = index % 3 == 0
        slab(((0.44 if big else 0.26) * size, 0.2, radius * (0.2 if big else 0.12)), (x, y - 0.2, z), T["wood_dark"], rotation=(0, math.radians(index * 30), 0))
    for angle, length, wide in ((minute * 30, radius * 0.74, 0.36), (hour * 30, radius * 0.5, 0.5)):
        a = math.radians(angle)
        box((wide * size, 0.24, length), (math.sin(a) * length * 0.42, y - 0.3, math.cos(a) * length * 0.42), HAND, bevel=0.08, rotation=(0, a, 0), segments=1)
    ball(radius * 0.11, (0, y - 0.34, 0), GOLD, scale=(1, 0.6, 1), segments=8, roughness=0.3)


def rainbow(radius, band=1.0, steps=20, colours=RAINBOW):
    """An arc of Infinity's six soft colours standing on the ground round the origin, facing the front:
    `radius` to its outside, each colour `band` thick."""
    for index, colour in enumerate(colours):
        reach = radius - (index + 0.5) * band
        points = [(-reach * math.cos(math.pi * step / steps), 0, reach * math.sin(math.pi * step / steps)) for step in range(steps + 1)]
        pipe(points, band * 0.56, colour, around=4, roughness=0.8)


# ---------------------------------------------------------------------------------------------------
# The tall props: tree(leaf, kind), kind "round" (wide) or "tall" (thin), about 16 tall like Earth's trees
# ---------------------------------------------------------------------------------------------------
def twin_ring(leaf, kind):
    """Multiverse: a portal ring on a stone foot with a second ring, from another world, overlapping it;
    or an obelisk with its glowing double standing half inside it. Shards of glass hang round both."""
    others = [colour for colour in T["leaves"] if colour != leaf]

    def portal_ring(at, radius, colour, turn):
        first = len(made)
        hoop(radius, radius * 0.17, (0, 0, 0), colour, rotation=(math.pi / 2, 0, 0), segments=12, roughness=0.3)
        tube(radius * 0.9, 0.24, (0, 0.12, 0), (0, -1, 0), shade(colour, 0.38), vertices=12, emission=0.9)
        moved(first, Matrix.Translation(at) @ Matrix.Rotation(turn, 4, "Z"))

    def obelisk(colour, **look):
        tube(1.6, 10.0, (0, 0, 0), UP, colour, tip=1.05, vertices=4, **look)
        tube(1.05, 3.0, (0, 0, 10.0), UP, colour, tip=0.0, vertices=4, **look)

    tube(2.6, 0.7, (0, 0, -0.3), UP, T["stone_dark"], vertices=8)
    if kind == "round":
        tube(1.9, 1.3, (0, 0, 0.4), UP, T["stone"], tip=1.5, vertices=8)
        portal_ring((-1.0, 0, 6.3), 4.0, leaf, 0.0)
        portal_ring((2.0, 1.3, 8.0), 3.1, others[0], 0.3)  # the other world's, a step behind and out of true
        for x, y, z, size, colour in ((-5.2, -0.3, 11.6, 0.75, others[1]), (4.9, -0.6, 3.4, 0.6, others[1]), (-0.6, -1.0, 12.6, 0.55, others[0]), (5.9, 0.9, 12.2, 0.5, leaf)):
            gem(size, size * 3.0, (x, y, z), colour, (0.15 * (1 if x > 0 else -1), 0, 1), roughness=0.1)
    else:
        first = len(made)
        obelisk(leaf, roughness=0.2)
        moved(first, Matrix.Translation((-0.5, 0, 0.3)) @ Matrix.Rotation(math.pi / 4, 4, "Z"))
        first = len(made)
        obelisk(others[0], roughness=0.2, emission=0.45)  # its double: smaller, turned, and not quite here
        moved(first, Matrix.Translation((1.1, 0.7, 2.1)) @ Matrix.Rotation(math.pi / 4 + 0.5, 4, "Z") @ Matrix.Scale(0.86, 4))
        hoop(3.0, 0.2, (0.2, 0.3, 6.6), others[1], rotation=(0.25, 0.15, 0), segments=14, emission=1.0)
        gem(0.8, 2.8, (-0.5, 0, 15.8), others[1], emission=0.8)
        for x, y, z, size, colour in ((-3.4, 0.4, 10.4, 0.55, others[1]), (3.6, -0.5, 12.4, 0.5, leaf), (-2.9, -0.8, 4.0, 0.45, others[0])):
            gem(size, size * 3.0, (x, y, z), colour, roughness=0.1)


def cog_tree(leaf, kind):
    """Time Warp: a brass post with three gears turning in one another; or a metronome, its arm mid-swing."""
    others = [colour for colour in T["leaves"] if colour != leaf]
    brass, light, dark = T["wood"], T["wood_light"], T["wood_dark"]
    tube(2.5, 0.7, (0, 0, -0.3), UP, T["stone_dark"], vertices=8)
    if kind == "round":
        tube(0.95, 6.4, (0, 0, 0.4), UP, brass, tip=0.7, vertices=8, roughness=0.35)
        cog(4.1, 1.2, (0, 0, 8.4), leaf, teeth=8, hub=dark, roughness=0.35)
        cog(2.5, 1.1, (4.6, 0.25, 12.7), others[0], teeth=7, spin=0.3, hub=dark, roughness=0.35)
        cog(2.1, 1.0, (-4.9, -0.25, 11.2), others[1], teeth=6, spin=0.1, hub=dark, roughness=0.35)
    else:
        first = len(made)
        tube(3.3, 13.6, (0, 0, 0.3), UP, leaf, tip=1.0, vertices=4, roughness=0.4)  # the case: a steep pyramid
        for z in (2.2, 6.8):
            wide = 3.3 - 2.3 * (z - 0.3) / 13.6
            tube(wide * 1.05, 0.55, (0, 0, z), UP, brass, tip=(wide - 0.093) * 1.05, vertices=4, roughness=0.35)
        tube(1.25, 0.6, (0, 0, 13.8), UP, brass, vertices=4, roughness=0.35)
        moved(first, Matrix.Rotation(math.pi / 4, 4, "Z"))
        ball(0.7, (0, 0, 14.8), GOLD, segments=8, roughness=0.3)
        foot, swing = Vector((0, -2.2, 2.6)), Vector((0.3, 0.12, 1)).normalized()  # the arm, up the front of the case
        tube(0.2, 11.6, foot, swing, light, vertices=5, roughness=0.3)
        ball(0.5, foot, dark, segments=6)
        box((1.7, 0.8, 1.3), foot + swing * 7.4 + Vector((0, -0.2, 0)), GOLD, bevel=0.2, rotation=(0, 0.29, 0), segments=1, roughness=0.3)  # its weight
        ball(0.42, foot + swing * 11.8, others[0], segments=6, roughness=0.3)


def infinity_loop(leaf, kind):
    """Infinity: a loop like an 8 on its side, standing on a white column under a halo; or a stair that
    winds up round a beam of light to a star, and never gets there."""
    pale = shade(leaf, 0.45)
    tube(2.5, 0.7, (0, 0, -0.3), UP, T["stone_dark"], vertices=8)
    if kind == "round":
        tube(1.35, 4.6, (0, 0, 0.4), UP, WHITE, tip=1.0, vertices=8, roughness=0.4)
        tube(1.5, 0.5, (0, 0, 4.9), UP, GOLD, vertices=8, roughness=0.3)
        first = len(made)
        pipe(eight(5.0, weave=0.5, steps=20), 0.68, leaf, closed=True, roughness=0.3)
        moved(first, Matrix.Translation((0, 0, 8.5)))
        ball(0.95, (0, 0, 8.5), WHITE, segments=6, emission=0.9)  # the knot where it crosses
        tube(1.7, 0.14, (0, 0, 12.2), UP, T["accent_pale"], vertices=8, emission=1.0)  # a halo
    else:
        tube(0.75, 15.2, (0, 0, 0.3), UP, pale, tip=0.4, vertices=6, emission=0.8)  # the beam
        for index in range(14):  # the stair: a step every 45 degrees, each a little higher
            a = math.radians(index * 45)
            slab((1.6, 2.8, 0.55), (math.sin(a) * 1.8, math.cos(a) * 1.8, 1.3 + index * 1.0), WHITE if index % 2 else T["stone_dark"], rotation=(0, 0, -a))
        for turn in (0, math.pi / 2):  # a star that reads from every side
            star(1.5, (0, 0, 16.6), GOLD, depth=0.55, rotation=(0, 0, turn), emission=0.6)
        tube(2.3, 0.14, (0, 0, 15.0), UP, leaf, vertices=8, emission=0.7)


TREES = {"twin_ring": twin_ring, "cog_tree": cog_tree, "infinity_loop": infinity_loop}
# How wide and how high the unseen pillar in each is, at size 1 (island.py's TREE_SOLID)
TREE_SOLID = {"twin_ring": {"round": ("twin ring", 2.4, 10.0), "tall": ("twin obelisk", 2.2, 13.0)},
              "cog_tree": {"round": ("cog tree", 1.6, 12.0), "tall": ("metronome", 2.4, 13.0)},
              "infinity_loop": {"round": ("infinity loop", 1.8, 10.0), "tall": ("endless stair", 2.6, 14.0)}}


# ---------------------------------------------------------------------------------------------------
# The fence: a post at `foot` (its ring, its clock or its halo looks along `spin`, a turn round Z) and what
# runs from one post's foot to the next. `size` is 1 on an island; a base's is a size up.
# ---------------------------------------------------------------------------------------------------
def fence_post(kind, foot, spin, index, size=1.0):
    foot = Vector(foot)
    up = lambda height: foot + Vector((0, 0, height * size))
    if kind == "ring_post":  # Multiverse: a post with a glowing ring on it
        out, colour = Vector((-math.sin(spin), math.cos(spin), 0)), T["leaves"][index % 3]
        tube(0.45 * size, 3.1 * size, foot + Vector((0, 0, -0.3)), UP, T["wood_light"], vertices=6)
        hoop(0.78 * size, 0.2 * size, up(3.55), colour, rotation=(math.pi / 2, 0, spin), segments=8, roughness=0.3)
        tube(0.66 * size, 0.14 * size, up(3.55) - out * 0.07 * size, out, shade(colour, 0.55), vertices=8, emission=1.0)
    elif kind == "cog_post":  # Time Warp: a brass post with a little clock on it
        out = Vector((-math.sin(spin), math.cos(spin), 0))
        tube(0.55 * size, 3.0 * size, foot + Vector((0, 0, -0.3)), UP, T["wood"], vertices=4, roughness=0.35)
        tube(1.0 * size, 0.3 * size, up(3.5) - out * 0.15 * size, out, T["wood_light"], vertices=8, roughness=0.3)
        tube(0.74 * size, 0.44 * size, up(3.5) - out * 0.22 * size, out, CREAM, vertices=8)
    else:  # halo_post, Infinity: a white post with a gold ball, a halo over it
        tube(0.45 * size, 3.0 * size, foot + Vector((0, 0, -0.3)), UP, WHITE, vertices=6, roughness=0.4)
        ball(0.56 * size, up(3.1), GOLD, segments=6, roughness=0.3)
        tube(0.85 * size, 0.1 * size, up(4.05), UP, T["accent_pale"], vertices=8, emission=1.0)


def fence_rail(kind, a, b, index, low=None, high=None, size=1.0):
    """`low` and `high` are where a base's two solid rails are; an island's fence is free."""
    a, b = Vector(a), Vector(b)
    lift = lambda height: a + Vector((0, 0, height))
    if kind == "ring_post":  # two beams of light, one from each world
        tube(0.22 * size, (b - a).length, lift(high or 2.3), b - a, T["leaves"][0], vertices=4, emission=1.0)
        tube(0.2 * size, (b - a).length, lift(low or 1.4), b - a, T["leaves"][1], vertices=4, emission=1.0)
    elif kind == "cog_post":  # a chain with a pendulum's bob hanging in the middle of it
        top = (high + 0.4) if high else 2.7
        sag(a, b, top, 0.9 * size, 0.2 * size, T["wood_dark"])
        tube(0.46 * size, 1.0 * size, (a + b) / 2 + Vector((0, 0, top - 0.9 * size)), (0, 0, -1), GOLD, tip=0.0, vertices=4, roughness=0.3)  # a plumb bob
        if low:
            tube(0.26 * size, (b - a).length, lift(low), b - a, T["rock_light"], vertices=4, roughness=0.3)
    else:  # a rail that runs through the rainbow, post by post, over one of gold
        tube(0.3 * size, (b - a).length, lift(high or 2.3), b - a, RAINBOW[index % 6], vertices=4, roughness=0.5)
        tube(0.2 * size, (b - a).length, lift(low or 1.3), b - a, T["wood_light"], vertices=4, roughness=0.3)


FENCES = ("ring_post", "cog_post", "halo_post")
LIQUIDS = {"mirror": 0.8, "timepool": 0.7, "stillwater": 0.0}  # how much each glows (stillwater does not: it is the island's _Water mesh)


# ---------------------------------------------------------------------------------------------------
# What is on the liquid. On an island: in the pond's own space (its middle the origin, the stream leaving
# towards -Y, the liquid's top 0.3 up). On a base: at the waterfall, in the waterfall's own space.
# ---------------------------------------------------------------------------------------------------
def pond_dressing(liquid):
    leaves = T["leaves"]
    if liquid == "mirror":  # another world shows in the middle of it, shards of glass hang over it
        tube(3.0, 0.62, (1.0, 0.8, -0.2), UP, OTHER_WORLD, vertices=20, emission=0.8)
        hoop(3.2, 0.26, (1.0, 0.8, 0.36), WHITE, segments=20, emission=1.4)
        for x, y, z, size, colour in ((-4.0, 2.5, 2.8, 0.85, leaves[0]), (3.2, 4.2, 3.6, 0.7, leaves[2]), (4.6, -1.5, 2.4, 0.75, leaves[0]), (-1.4, -3.4, 3.2, 0.6, leaves[2])):
            gem(size, size * 3.2, (x, y, z), colour, (0.12 * (1 if x > 0 else -1), 0.05, 1), roughness=0.1, emission=0.4)
    elif liquid == "timepool":  # it is a clock: twelve marks round it, two brass hands lying on it
        for hour in range(12):
            x, y = ring(hour * 30, 7.2)
            slab((1.0, 2.2, 0.24) if hour % 3 == 0 else (0.7, 1.6, 0.24), (x, y, 0.36), T["wood_light"], rotation=(0, 0, -math.radians(hour * 30)), roughness=0.3)
        for angle, length, wide in ((50, 6.2, 0.75), (-70, 4.2, 1.0)):
            x, y = ring(angle, length / 2)
            box((wide, length, 0.3), (x, y, 0.5), GOLD, bevel=0.1, rotation=(0, 0, -math.radians(angle)), segments=1, roughness=0.3)
        tube(1.1, 0.5, (0, 0, 0.2), UP, GOLD, vertices=10, roughness=0.3)
        ball(0.6, (0, 0, 0.75), T["wood_dark"], scale=(1, 1, 0.6), segments=8)
    else:  # stillwater: one ripple, and a gold loop hanging over it with a light in each half
        hoop(6.5, 0.12, (0, 0, 0.3), WHITE, segments=20)
        first = len(made)
        pipe(eight(4.4, weave=0.35, flat=True), 0.5, GOLD, closed=True, roughness=0.3)
        moved(first, Matrix.Translation((0, 0.6, 2.2)))
        for side in (-1, 1):
            ball(0.75, (side * 3.1, 0.6, 2.2), T["accent_pale"], segments=8, emission=1.2)


def fall_dressing(liquid, fall, pool, reach):
    """A base's waterfall: `fall` is its path as (forward of the butte's middle, height) points, `pool` the
    radius of the pool at its foot, `reach` how far forward of the butte's middle that pool lies."""
    leaves = T["leaves"]
    out, top = fall[0]
    foot = Vector((0, -reach, 0))
    if liquid == "mirror":  # another world in the pool, shards beside the fall and over the pool
        tube(pool * 0.5, 0.1, foot + Vector((0.25, 0.2, 0.3)), UP, OTHER_WORLD, vertices=12, emission=0.8)
        hoop(pool * 1.7, 0.14, foot + Vector((0, 0, 2.0)), WHITE, rotation=(0.3, 0.15, 0), segments=18, emission=1.4)
        for x, y, z, size, colour in ((-2.6, 0.6, 3.4, 0.8, leaves[0]), (2.6, 0.2, 4.6, 0.7, leaves[2]), (0.3, -2.5, 2.6, 0.55, leaves[0])):
            gem(size, size * 3.2, foot + Vector((x, y, z)), colour, roughness=0.1, emission=0.4)
        for x, z, colour in ((-2.9, top - 6.5, leaves[2]), (2.8, top - 11.0, leaves[0]), (-2.6, top - 16.0, leaves[2])):
            gem(0.7, 2.4, (x, -fall[3][0] - 1.4, z), colour, roughness=0.1, emission=0.4)
    elif liquid == "timepool":  # a gear half out of the rock where it starts, a clock's hands on the pool
        cog(2.7, 1.0, (0.4, -out + 0.4, top + 0.5), T["wood_light"], teeth=8, hub=T["wood_dark"], roughness=0.35)
        cog(1.6, 0.8, (-2.7, -out - 0.3, top - 1.6), leaves[1], teeth=6, spin=0.2, hub=GOLD, roughness=0.35)
        for angle, length, wide in ((50, pool * 1.5, 0.34), (-70, pool * 1.0, 0.44)):
            x, y = ring(angle, length / 2)
            box((wide, length, 0.2), foot + Vector((x, y, 0.42)), GOLD, bevel=0.06, rotation=(0, 0, -math.radians(angle)), segments=1, roughness=0.3)
        ball(0.4, foot + Vector((0, 0, 0.5)), T["wood_dark"], scale=(1, 1, 0.6), segments=6)
    else:  # stillwater: it falls as a rainbow, and a gold loop hangs over the pool
        with into("Water"):
            for index, colour in enumerate(RAINBOW):
                ribbon(fall[1:], 0.56, colour, thickness=0.3, shift=(index - 2.5) * 0.58, lift=0.9, roughness=0.3)
        first = len(made)
        pipe(eight(pool * 1.5, weave=0.2, flat=True), 0.26, GOLD, closed=True, roughness=0.3)
        moved(first, Matrix.Translation(foot + Vector((0, 0, 2.2))))
        for side in (-1, 1):
            ball(0.42, foot + Vector((side * pool * 1.05, 0, 2.2)), T["accent_pale"], segments=6, emission=1.2)


# ---------------------------------------------------------------------------------------------------
# The set pieces: two a world, on the spots where Earth has its cannon and its campfire. Each stays within
# 6.2 of its middle and has its front towards -Y.
# ---------------------------------------------------------------------------------------------------
def twin_gate():
    """Multiverse: two portal rings from two worlds, a pink one and a teal one, standing through one
    another; where they overlap a violet shard hangs, and glass round them."""
    pink, teal, violet = T["leaves"]
    tube(4.8, 0.7, (0, 0, 0), UP, T["stone_dark"], vertices=12)
    tube(3.9, 0.7, (0, 0, 0.7), UP, T["stone"], vertices=12)
    hoop(3.93, 0.2, (0, 0, 1.05), GOLD, segments=12, roughness=0.3)
    for side, colour in ((-1, pink), (1, teal)):
        first = len(made)
        hoop(3.7, 0.78, (0, 0, 0), colour, rotation=(math.pi / 2, 0, 0), segments=18, roughness=0.3)
        tube(3.2, 0.3, (0, 0.15, 0), (0, -1, 0), shade(colour, 0.55), vertices=18, emission=0.9)
        for radius, depth, shift in ((2.2, 0.44, 0.2), (1.2, 0.58, -0.15)):  # rings of light in the sheet, the same from both sides
            tube(radius, depth, (shift, depth / 2, 0.1), (0, -1, 0), shade(colour, 0.75 if radius > 2 else 0.9), vertices=14, emission=0.9)
        moved(first, Matrix.Translation((side * 1.35, 0, 6.0)) @ Matrix.Rotation(-side * 0.42, 4, "Z"))
        box((2.0, 2.2, 1.5), (side * 3.1, 0, 1.9), T["stone_pale"], bevel=0.35, segments=1)  # the block it stands in
    gem(1.15, 5.2, (0, 0, 6.2), violet, emission=1.2)
    hoop(1.9, 0.16, (0, 0, 6.2), WHITE, rotation=(0.2, 0.1, 0), segments=14, emission=1.4)
    for x, y, z, size, colour in ((-4.6, 0.6, 11.0, 0.8, teal), (4.7, -0.4, 11.6, 0.7, pink), (0.2, 0.3, 12.4, 0.9, violet), (-5.6, -0.5, 3.6, 0.5, violet), (5.7, 0.4, 3.2, 0.5, violet)):
        gem(size, size * 3.0, (x, y, z), colour, (0.12 * (1 if x > 0 else -1), 0, 1), roughness=0.1, emission=0.5)


def mirror_tower():
    """Multiverse: a little pink tower, and the same tower from the world above it, teal and upside down,
    their roofs tip to tip with a mirror's ring between them."""
    pink, teal, violet = T["leaves"]

    def tower(wall, roof):
        tube(2.5, 4.2, (0, 0, 0.6), UP, wall, tip=2.1, vertices=10, roughness=0.5)
        hoop(2.34, 0.2, (0, 0, 2.6), GOLD, segments=10, roughness=0.3)
        tube(2.6, 0.7, (0, 0, 4.7), UP, T["stone_pale"], vertices=10)
        tube(2.9, 3.0, (0, 0, 5.3), UP, roof, tip=0.0, vertices=10, roughness=0.4)
        for turn in range(4):
            a = turn * math.pi / 2
            box((1.0, 0.5, 1.5), (math.sin(a) * 2.25, -math.cos(a) * 2.25, 3.6), T["accent"], bevel=0.12, rotation=(0, 0, a), segments=1, emission=1.0)

    tube(4.3, 0.6, (0, 0, 0), UP, T["stone_dark"], vertices=12)
    tower(shade(pink, 0.55), pink)
    first = len(made)
    tube(3.2, 0.5, (0, 0, 0.1), UP, T["rock"], tip=2.4, vertices=10)  # the ground it stands on, a piece of its own world
    tower(shade(teal, 0.55), teal)
    moved(first, Matrix.Translation((0, 0, 17.0)) @ Matrix.Rotation(math.pi, 4, "X"))
    hoop(3.3, 0.22, (0, 0, 8.5), WHITE, segments=18, emission=1.4)  # the mirror between the two
    gem(0.7, 1.9, (0, 0, 8.5), violet, emission=1.2)
    for x, y, z, size, colour in ((-3.9, 0.4, 10.6, 0.6, violet), (3.8, -0.5, 6.6, 0.6, violet), (3.4, 0.9, 11.8, 0.45, pink), (-3.6, -0.8, 5.6, 0.45, teal)):
        gem(size, size * 3.0, (x, y, z), colour, roughness=0.1, emission=0.5)


def hourglass():
    """Time Warp: an hourglass as big as a house in a brass frame, half its sand run through, a gear or two
    at its foot."""
    brass, light, dark = T["wood"], T["wood_light"], T["wood_dark"]
    tube(4.6, 0.7, (0, 0, 0), UP, T["stone_dark"], vertices=12)
    tube(3.9, 0.8, (0, 0, 0.7), UP, brass, vertices=12, roughness=0.35)
    # the glass, in four bands: the sand that has run through, the empty glass over it, the sand still to run, the empty glass on top
    lathe([(0, 4.6), (2.75, 4.6), (3.2, 3.0), (2.9, 1.5), (0, 1.5)], SAND, segments=12, roughness=0.6)
    lathe([(0, 7.0), (0.6, 7.0), (2.1, 5.5), (2.75, 4.6), (0, 4.6)], GLASS, segments=12, roughness=0.1)
    lathe([(0, 9.6), (2.5, 9.6), (2.1, 8.6), (0.6, 7.0), (0, 7.0)], SAND, segments=12, roughness=0.6)
    lathe([(0, 12.5), (2.9, 12.5), (3.2, 11.2), (2.5, 9.6), (0, 9.6)], GLASS, segments=12, roughness=0.1)
    hoop(0.8, 0.26, (0, 0, 7.0), GOLD, segments=10, roughness=0.3)
    tube(3.9, 0.8, (0, 0, 12.5), UP, brass, vertices=12, roughness=0.35)
    tube(2.6, 0.5, (0, 0, 13.3), UP, light, vertices=12, roughness=0.35)
    ball(0.8, (0, 0, 14.3), GOLD, segments=8, roughness=0.3)
    for index in range(4):
        x, y = ring(index * 90 + 45, 3.4)
        tube(0.3, 11.2, (x, y, 1.4), UP, light, vertices=6, roughness=0.3)
        ball(0.48, (x, y, 12.4), GOLD, segments=6, roughness=0.3)
    cog(1.9, 0.8, (4.1, -2.5, 1.7), T["leaves"][1], teeth=8, turn=0.5, hub=GOLD, roughness=0.35)
    cog(1.3, 0.7, (-4.3, -2.3, 1.2), light, teeth=6, turn=-0.5, spin=0.3, hub=dark, roughness=0.35)


def grand_clock():
    """Time Warp: a great alarm clock on a brass stand, two bells and a hammer on top, a pendulum swinging
    under it; a face on both sides."""
    brass, light, dark = T["wood"], T["wood_light"], T["wood_dark"]
    middle = Vector((0, 0, 11.2))
    tube(4.5, 0.7, (0, 0, 0), UP, T["stone_dark"], vertices=12)
    box((6.6, 3.4, 1.3), (0, 0, 1.35), T["stone"], bevel=0.35)
    for side in (-1, 1):
        box((1.0, 1.8, 5.6), (side * 2.8, 0, 4.7), brass, bevel=0.3, segments=1, roughness=0.35)
        ball(0.46, (side * 2.8, -0.95, 3.0), GOLD, segments=6, roughness=0.3)
    pivot, swing = Vector((0, 0, 7.6)), Vector((0.38, 0, -1)).normalized()  # the pendulum, at the end of a swing
    tube(0.2, 4.4, pivot, swing, light, vertices=5, roughness=0.3)
    bob = pivot + swing * 4.6
    tube(1.2, 0.7, bob + Vector((0, 0.35, 0)), (0, -1, 0), GOLD, vertices=12, roughness=0.3)
    tube(0.62, 0.9, bob + Vector((0, 0.45, 0)), (0, -1, 0), T["leaves"][1], vertices=8, roughness=0.3)
    tube(4.25, 2.0, middle + Vector((0, 1.0, 0)), (0, -1, 0), brass, vertices=16, roughness=0.35)
    for front in (0, 1):
        first = len(made)
        dial(3.7, -1.0, hour=10.0 + front * 4, minute=2.0 + front * 8)
        moved(first, Matrix.Translation(middle) @ Matrix.Rotation(front * math.pi, 4, "Z"))
    for side in (-1, 1):  # the bells, on their arms
        lean = Vector((side * 0.62, 0, 1)).normalized()
        tube(0.24, 1.3, middle + lean * 4.1, lean, dark, vertices=5)
        first = len(made)
        lathe([(0, 1.5), (0.9, 1.3), (1.5, 0.5), (1.65, 0.0), (0, 0.0)], GOLD, segments=10, roughness=0.3)
        ball(0.3, (0, 0, 1.7), dark, segments=6)
        moved(first, Matrix.Translation(middle + lean * 5.2) @ Matrix.Rotation(-side * 0.55, 4, "Y"))
    tube(0.18, 1.9, middle + Vector((0, 0, 4.1)), UP, dark, vertices=5)  # the hammer between them
    box((1.7, 0.7, 0.7), middle + Vector((0, 0, 6.1)), dark, bevel=0.2, segments=1)
    cog(1.8, 0.8, (3.9, -1.9, 1.7), T["leaves"][1], teeth=8, turn=0.45, hub=GOLD, roughness=0.35)
    cog(1.2, 0.7, (-4.1, -1.9, 1.2), light, teeth=6, turn=-0.45, spin=0.3, hub=dark, roughness=0.35)


def infinity_arch():
    """Infinity: the sign itself, in gold, as big as a house: a loop like an 8 on its side on two white
    columns, a light in each half, on steps in the six soft colours."""
    for index, colour in enumerate((RAINBOW[5], RAINBOW[4], RAINBOW[3], RAINBOW[2])):
        tube(5.0 - index * 0.5, 0.4, (0, 0, index * 0.35), UP, colour, vertices=14, roughness=0.6)
    tube(3.0, 0.5, (0, 0, 1.4), UP, WHITE, vertices=14, roughness=0.4)
    middle = Vector((0, 0, 7.2))
    for side in (-1, 1):
        tube(0.85, 2.4, (side * 3.7, 0, 1.2), UP, WHITE, tip=0.7, vertices=10, roughness=0.4)
        hoop(0.8, 0.18, (side * 3.7, 0, 3.3), GOLD, segments=10, roughness=0.3)
        ball(1.15, middle + Vector((side * 3.15, 0, 0)), T["accent_pale"], segments=10, emission=1.2)
    first = len(made)
    pipe(eight(5.3, weave=0.7, steps=32), 0.95, GOLD, closed=True, roughness=0.3)
    moved(first, Matrix.Translation(middle))
    tube(2.2, 0.16, middle + Vector((0, 0, 4.9)), UP, T["accent_pale"], vertices=14, emission=1.0)  # a halo over it
    for turn in (0, math.pi / 2):
        star(0.9, middle + Vector((0, 0, 6.3)), WHITE, depth=0.35, rotation=(0, 0, turn), emission=1.0)


def endless_stairs():
    """Infinity: a white tower with a stair winding up round its four sides to a ring of light on top:
    the stair that never ends."""
    tube(5.2, 0.6, (0, 0, 0), UP, T["stone_dark"], vertices=14)
    box((4.2, 4.2, 11.4), (0, 0, 6.2), WHITE, bevel=0.45)
    for z, colour in ((3.3, RAINBOW[0]), (6.2, RAINBOW[2]), (9.1, RAINBOW[4])):  # three soft bands round the tower
        box((4.36, 4.36, 0.5), (0, 0, z), colour, bevel=0.1, segments=1)
    for index in range(20):  # four flights of five steps, each step a little higher than the last
        side, step = divmod(index, 5)
        along = -2.6 + step * 1.3
        first = len(made)
        box((1.45, 1.7, 0.55), (along, -2.9, 0), WHITE if index % 2 else T["sand"], bevel=0.14, segments=1)
        moved(first, Matrix.Translation((0, 0, 1.1 + index * 0.52)) @ Matrix.Rotation(side * math.pi / 2, 4, "Z"))
    tube(2.4, 0.5, (0, 0, 11.9), UP, GOLD, vertices=12, roughness=0.3)
    hoop(1.9, 0.36, (0, 0, 14.5), GOLD, rotation=(math.pi / 2, 0, 0), segments=14, roughness=0.3)  # the ring of light it leads to
    tube(1.65, 0.3, (0, 0.15, 14.5), (0, -1, 0), T["accent_pale"], vertices=14, emission=1.2)
    for turn in (0, math.pi / 2):
        star(0.85, (0, 0, 17.4), GOLD, depth=0.32, rotation=(0, 0, turn), emission=0.6)


# A world's two set pieces and what is solid in them, as island.py's SET_PIECES has them:
# (builder, ((what, x, y, radius, height), ...)).
SET_PIECES = {
    "Multiverse": ((twin_gate, (("twin portal", 0, 0, 4.4, 10.0),)), (mirror_tower, (("mirror tower", 0, 0, 3.6, 16.0),))),
    "Time Warp": ((hourglass, (("hourglass", 0, 0, 4.2, 14.0), ("gear", 4.1, -2.5, 1.5, 3.4))), (grand_clock, (("grand clock", 0, 0, 3.8, 16.0), ("gear", 3.9, -1.9, 1.4, 3.4)))),
    "Infinity": ((infinity_arch, (("infinity arch", -3.7, 0, 1.6, 9.0), ("infinity arch", 3.7, 0, 1.6, 9.0), ("infinity arch", 0, 0, 2.6, 2.0))), (endless_stairs, (("endless stairs", 0, 0, 4.4, 12.0),))),
}


# ---------------------------------------------------------------------------------------------------
# What hangs in the sky. Built round the origin, front towards -Y; the caller puts it where it belongs.
# ---------------------------------------------------------------------------------------------------
def sky_clock(radius, hour=10.0, minute=2.0):
    """Time Warp: a clock's face as big as a hill, a brass case behind it, with a gear behind each shoulder."""
    tube(radius * 1.1, radius * 0.2, (0, radius * 0.22, 0), (0, -1, 0), T["wood_light"], vertices=20, roughness=0.35)  # its case is its rim
    dial(radius, 0.0, hour=hour, minute=minute, rim=False)
    cog(radius * 0.5, radius * 0.12, (radius * 0.95, radius * 0.3, radius * 0.6), T["leaves"][1], teeth=8, hub=GOLD, roughness=0.35)
    cog(radius * 0.36, radius * 0.1, (-radius * 1.0, radius * 0.3, -radius * 0.5), T["wood_light"], teeth=6, spin=0.3, hub=T["wood_dark"], roughness=0.35)


def sky_shards(spots, size=1.0):
    """Multiverse: shards of glass at (x, y, z) points, in the three worlds' colours."""
    for index, (x, y, z) in enumerate(spots):
        wide = size * (1.4 + 0.5 * (index % 3))
        gem(wide, wide * 4.2, (x, y, z), T["leaves"][index % 3], (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 1), roughness=0.1)


def sky_stair(steps=12, wide=4.0):
    """Infinity: a length of stair hanging in the sky, winding up round nothing."""
    for index in range(steps):
        a = math.radians(index * 30)
        box((wide * 0.5, wide, wide * 0.16), (math.sin(a) * wide * 0.6, math.cos(a) * wide * 0.6, index * wide * 0.24), WHITE if index % 2 else T["sand_dark"], bevel=0.12, rotation=(0, 0, -a), segments=1)
