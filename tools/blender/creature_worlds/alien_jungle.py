# World 10, Alien Jungle: run by ../creatures.py with all its helpers to hand (see the note above `stage`).
# A jungle of giant mushrooms and snapping plants: spores, vines, pods, thorns, a blue hunter, and two bosses,
# a three-headed venom hydra and a behemoth with a great flower growing on its head.
ALIEN_JUNGLE_LEAF, ALIEN_JUNGLE_LIME, ALIEN_JUNGLE_CREAM = "4FCB5E", "C8F25A", "FFEFB0"


def alien_jungle_move(first, matrix):
    """Moves every piece made since `first` (a len(made)) by a matrix: builds a part upright, then tilts it."""
    for obj in made[first:]:
        obj.matrix_basis = matrix @ obj.matrix_basis


def alien_jungle_leaf(at, size, colour, lean=0, turn=0, thick=0.14, wide=1.0, **look):
    """A pointed leaf growing out of `at`: up, leaning `lean` degrees to the side, turned `turn` round."""
    outline = [(0, 0), (-0.3 * wide, 0.36), (-0.24 * wide, 0.78), (0, 1.15), (0.24 * wide, 0.78), (0.3 * wide, 0.36)]
    plate([(x * size, z * size) for x, z in outline], colour, at, thick=thick, rotation=(0, math.radians(lean), math.radians(turn)), **look)


def alien_jungle_vine(points, colour, radius=0.13, tip=None, tip_size=0.2, **look):
    """A vine or a thin tail along a path of points; `tip` is the colour of a glowing ball on its end."""
    for start, end in zip(points, points[1:]):
        way = Vector(end) - Vector(start)
        tube(radius, way.length + radius * 0.6, start, way, colour, vertices=5, **look)
    if tip:
        ball(tip_size, points[-1], tip, segments=6, emission=1.5)


def alien_jungle_shroom(at, size, cap, spots="FFF6C8", stem="FFEFD0"):
    """A little toadstool standing on `at`."""
    x, y, z = at
    tube(0.2 * size, 0.6 * size, at, UP, stem, vertices=6)
    rings = [(0, 1.08), (0.42, 1.0), (0.74, 0.76), (0.82, 0.5), (0.6, 0.44), (0, 0.5)]
    lathe([(r * size, h * size) for r, h in rings], cap, segments=8, location=at)
    for dx, dy, dz in ((0, -0.5, 0.86), (-0.5, -0.2, 0.8), (0.45, -0.1, 0.84)):
        ball(0.13 * size, (x + dx * size, y + dy * size, z + dz * size), spots, segments=6, emission=0.5)


def spore_puff(c, a):
    # A puffball toadstool adrift: a pale round body under a big spotted cap that puffs spores out of its top.
    pale = shade(c, 0.62)
    front = floater(pale, 1.0, squash=0.95)
    tube(1.2, 0.2, (0, 0, 1.38), UP, a, vertices=12)  # gills
    lathe([(0, 2.6), (0.8, 2.47), (1.42, 2.05), (1.62, 1.62), (1.35, 1.45), (0, 1.5)], c, segments=14)
    for x, y, z, r in ((-0.8, -1.02, 2.12, 0.3), (0.5, -1.25, 2.02, 0.24), (1.25, -0.35, 2.12, 0.28), (-1.32, 0.15, 2.05, 0.26), (0.05, -0.62, 2.48, 0.22), (0.3, 1.2, 2.1, 0.3), (-0.3, -1.42, 1.78, 0.17)):
        ball(r * 1.15, (x * 0.96, y * 0.96, z - 0.05), "FFF3D0", segments=8)
    crater((0, 0, 2.5), 0.5, 0.36, a, "FFF07A", sides=8, glow=2)
    tuft("FFF6A8", ((0.05, 0, 3.02, 0.3), (0.34, 0.1, 3.3, 0.2)), emission=0.8)
    for x, y, z, r in ((-1.6, -0.5, 1.1, 0.15), (1.62, -0.4, 0.7, 0.17), (-1.5, -0.6, 0.35, 0.11)):
        ball(r, (x, y, z), "FFF07A", segments=6, emission=2)  # spores that follow it
    for side in (-1, 1):
        ball(0.24, (side * 0.98, -0.3, 0.62), pale, segments=6)  # stubby hands
    eyes(front, 0.92, 0.42, c, size=0.8)
    mouth(front + 0.1, 0.42, 0.34, "o")


def vine_creeper(c, a):
    # A caterpillar of a vine: a big head, three body segments, leaves for a crest, a tail that curls into a bud.
    dark = shade(c, -0.32)
    front = crawler(c, dark, w=2.3, d=1.9, h=1.3, lift=0.3, legs=2)
    for index, (y, z, r) in enumerate(((1.55, 0.95, 0.85), (2.55, 0.8, 0.68))):
        ball(r, (0, y, z), shade(c, 0.22) if index % 2 == 0 else c, segments=8)
        for side in (-1, 1):
            slab((0.36, 0.3, z), (side * r * 0.8, y, z / 2 - 0.08), dark, rotation=(0, side * math.radians(20), 0))
            alien_jungle_leaf((side * r * 0.45, y, z + r * 0.6), 1.1 - index * 0.22, ALIEN_JUNGLE_LEAF, lean=side * 38)
        spot((0, y - r * 0.5, z + r * 0.82), 0.2, a, towards=(0, -0.5, 1))
    alien_jungle_vine([(0, 3.0, 0.8), (0, 3.5, 1.1), (0, 3.6, 1.7), (0, 3.25, 2.15), (0, 2.8, 2.0)], ALIEN_JUNGLE_LEAF, radius=0.16, tip=a, tip_size=0.36)
    # On its head: two curling tendrils, a leaf, a golden flower.
    for side in (-1, 1):
        alien_jungle_vine([(side * 0.55, -0.2, 1.5), (side * 0.72, -0.25, 2.05), (side * 1.05, -0.3, 2.38), (side * 1.4, -0.3, 2.3), (side * 1.48, -0.3, 1.98)], ALIEN_JUNGLE_LEAF, radius=0.1, tip=a, tip_size=0.2)
    alien_jungle_leaf((0.1, 0.3, 1.55), 1.0, ALIEN_JUNGLE_LEAF, lean=16, turn=20)
    for index in range(5):
        px, pz = ring(index * 72, 0.26)
        ball(0.2, (-0.62 + px, front + 0.3, 1.68 + pz), a, scale=(1, 0.6, 1), segments=6)
    ball(0.17, (-0.62, front + 0.2, 1.68), "FFFFFF", segments=6)
    eyes(front, 1.1, 0.5, a, size=0.86)
    mouth(front, 0.55, 0.36)


def snap_pod(c, a):
    # A snapping plant: a great red pod of a mouth on a green stalk, gaping, full of teeth, its tongue hanging out.
    for index in range(6):
        dx, dy = ring(index * 60 + 30, 1)
        cone(0.4, 1.55, (0, 0.4, 0.12), (dx, dy, 0.1), a, sides=5)  # a rosette of leaves on the ground
    tube(0.48, 0.9, (0, 0.5, 0.0), UP, shade(a, -0.15), vertices=8)
    box((2.1, 1.9, 0.8), (0, 0.1, 1.3), "7A1840", bevel=0.1, segments=1)  # the inside of its mouth
    # The upper jaw: the head, with the eyes.
    box((2.5, 2.3, 1.4), (0, 0, 2.2), c, bevel=0.5, segments=3)
    front = -1.15
    box((2.58, 2.38, 0.3), (0, 0, 1.6), ALIEN_JUNGLE_LIME, bevel=0.1, segments=1)
    for x in (-0.9, -0.3, 0.3, 0.9):
        cone(0.19, 0.46, (x, -1.02, 1.47), (0, 0, -1), WHITE, sides=6)
    for side in (-1, 1):
        cone(0.17, 0.4, (side * 1.12, -0.4, 1.47), (0, 0, -1), WHITE, sides=6)
        alien_jungle_leaf((side * 0.7, 0.85, 2.7), 1.15, a, lean=side * 34, thick=0.2)  # sepals behind its head
        spot((side * 1.26, -0.2, 2.35), 0.24, shade(c, 0.5), towards=(side, 0, 0))
    spot((-0.55, -0.3, 2.9), 0.3, shade(c, 0.5), towards=UP)
    spot((0.5, 0.25, 2.9), 0.22, shade(c, 0.5), towards=UP)
    spot((0, front + 0.02, 2.82), 0.14, shade(c, 0.5))
    # The lower jaw, built level and then dropped open at the front.
    first = len(made)
    box((2.4, 2.2, 0.75), (0, 0, 0), c, bevel=0.3, segments=2)
    box((2.5, 2.3, 0.18), (0, 0, 0.34), ALIEN_JUNGLE_LIME, bevel=0.07, segments=1)
    for x in (-0.6, 0, 0.6):
        cone(0.18, 0.42, (x, -1.0, 0.4), UP, WHITE, sides=6)
    for side in (-1, 1):
        cone(0.16, 0.38, (side * 1.05, -0.45, 0.4), UP, WHITE, sides=6)
    box((0.7, 1.5, 0.18), (0.25, -0.75, 0.5), "FF7AA8", bevel=0.08, segments=1)  # tongue
    alien_jungle_move(first, Matrix.Translation((0, 0.05, 0.98)) @ Matrix.Rotation(0.4, 4, "X"))
    eyes(front, 2.32, 0.55, ALIEN_JUNGLE_LIME, size=0.85, brow=shade(c, -0.35), tilt=-16)


def thorn_beast(c, a):
    # A round bristling boar of a thing: four stubby legs, a pale snout with tusks, a back full of long thorns.
    dark = shade(c, -0.3)
    cube(2.6, 2.5, 1.75, 0.4, c, bevel=0.7)
    front = -1.25
    for side in (-1, 1):
        for y in (-0.7, 0.75):
            box((0.72, 0.78, 0.85), (side * 0.85, y, 0.42), dark, bevel=0.22, segments=2)
    for x, y, long in ((-0.8, -0.4, 0.95), (0, -0.5, 1.15), (0.8, -0.4, 0.95), (-0.45, 0.3, 1.3), (0.45, 0.3, 1.3), (-0.8, 0.95, 1.0), (0, 1.0, 1.2), (0.8, 0.95, 1.0)):
        cone(0.3, long, (x, y, 1.95), (x * 0.45, y * 0.4 + 0.12, 1), a, sides=6)
    for side in (-1, 1):
        for y, z in ((0.0, 1.55), (0.85, 1.4), (0.45, 0.95)):
            cone(0.27, 0.9, (side * 1.15, y, z), (side, 0.25, 0.4), a, sides=6)
        cone(0.27, 0.9, (side * 0.5, 1.1, 1.35), (side * 0.3, 1, 0.35), a, sides=6)
        cone(0.28, 0.5, (side * 0.95, -0.85, 2.0), (side * 0.5, -0.2, 1), dark, sides=5)  # ears
        cone(0.18, 0.6, (side * 0.62, front - 0.12, 0.72), (side * 0.3, -0.25, 1), a, sides=6)  # tusks
        slab((0.13, 0.06, 0.2), (side * 0.2, front - 0.42, 1.0), INK)
    box((1.1, 0.55, 0.72), (0, front - 0.15, 0.95), shade(c, 0.42), bevel=0.22, segments=2)  # snout
    ball(0.3, (-0.72, 0.52, 3.2), "FF4F7A", segments=8)  # a berry stuck on a thorn
    alien_jungle_leaf((-0.72, 0.52, 3.4), 0.45, ALIEN_JUNGLE_LEAF, lean=30)
    eyes(front, 1.62, 0.58, "FF9A3C", size=0.84, brow=dark, tilt=-18)
    slab((0.5, 0.1, 0.1), (0, front - 0.06, 0.52), INK)


def jungle_stalker(c, a):
    # A hunting cat that walks upright: pointed ears, tiger stripes that glow, claws, a long tail, leaves for cover.
    dark = shade(c, -0.35)
    front = biped(c, dark, w=1.9, d=1.7, h=2.1, legs=0.45, arm=False, belly=shade(c, 0.5), foot=(0.7, 0.95, 0.42))
    for side in (-1, 1):
        box((0.48, 0.6, 1.0), (side * 1.15, -0.3, 1.2), dark, bevel=0.2, segments=2, rotation=(0.4, side * math.radians(-12), 0))
        for dx in (-0.16, 0, 0.16):
            cone(0.09, 0.34, (side * 1.24 + dx, -0.6, 0.78), (0, -0.7, -1), a, sides=5, emission=1)
        for z in (1.25, 1.7, 2.15):
            slab((0.14, 0.95, 0.2), (side * 0.93, 0.1, z), a, emission=0.5)
        for z in (1.02, 1.32):
            plate([(0, 0.12), (-side * 0.5, 0), (0, -0.12)], a, (side * 0.95, front - 0.02, z), thick=0.1, emission=0.5)
    ears(c, a, 0.58, 2.42, size=0.78, lean=18)
    for x, long in ((-0.5, 0.6), (0, 0.85), (0.5, 0.6)):
        slab((0.2, long, 0.14), (x, -0.85 + long / 2, 2.53), a, emission=0.5)
    alien_jungle_vine([(0, 0.8, 0.8), (0.4, 1.3, 0.85), (0.9, 1.5, 1.25), (1.15, 1.5, 1.85), (1.05, 1.4, 2.45)], dark, radius=0.17, tip=a, tip_size=0.3)
    alien_jungle_leaf((1.05, 1.4, 2.5), 0.6, ALIEN_JUNGLE_LEAF, lean=24)  # it hides its tail's lamp behind a leaf
    eyes(front, 1.78, 0.46, a, size=0.88, brow=dark, tilt=-26, blush=False)
    ball(0.11, (0, front - 0.04, 1.34), "FF8FB8", scale=(1.3, 1, 0.9), segments=6)
    mouth(front, 1.1, 0.5, "fangs")


def alien_jungle_hydra_head(c, a, at, turn, tilt, size, chief):
    """One head of the hydra, built at the origin and then set on its neck."""
    first = len(made)
    cube(1.7, 1.5, 1.4, 0, c, bevel=0.5, seg=2)
    front = -0.75
    box((1.2, 0.4, 0.55), (0, front - 0.05, 0.36), shade(c, 0.35), bevel=0.18, segments=1)  # muzzle
    for side in (-1, 1):
        cone(0.24, 0.7 if chief else 0.55, (side * 0.5, 0.1, 1.25), (side * 0.45, 0.2, 1), a, sides=6, emission=0.4)
        cone(0.13, 0.4, (side * 0.32, front - 0.26, 0.2), (0, 0, -1), WHITE, sides=5)  # fangs
    ball(0.11, (0.32, front - 0.26, -0.36), a, scale=(1, 1, 1.4), segments=6, emission=2)  # a drop of venom
    plate([(-0.55, 0), (-0.3, 0.45), (0.1, 0.55), (0.55, 0)], a, (0, 0.2, 1.36), thick=0.16, rotation=(0, 0, math.pi / 2), emission=0.4)
    if chief:
        cone(0.2, 0.6, (0, -0.35, 1.3), (0, -0.25, 1), a, sides=5, emission=0.4)  # the chief head has a third horn
        ball(0.15, (0, front - 0.02, 1.25), GEM, segments=6, emission=0.6)
    eyes(front, 0.95, 0.42, a, size=0.72, brow=shade(c, -0.4), tilt=-26, blush=chief)
    alien_jungle_move(first, Matrix.Translation(at) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Rotation(tilt, 4, "Y") @ Matrix.Scale(size, 4))


def venom_hydra(c, a):
    # Three heads on three necks out of one fat body, fangs dripping, standing in a pool of its own venom.
    dark = shade(c, -0.3)
    lathe([(0, 0.1), (2.0, 0.1), (2.35, 0.0)], ALIEN_JUNGLE_LIME, segments=12, location=(0, -0.5, 0), emission=0.6)
    cube(3.3, 2.8, 1.7, 0.08, c, bevel=0.6, seg=2)
    front = -1.4
    disc(1.05, (0, front + 0.03, 0.8), shade(c, 0.5), height=0.07, stretch=0.66, sides=12)  # a pale belly
    for x, z in ((-0.35, 1.0), (0.4, 0.85), (-0.1, 0.5)):
        spot((x, front - 0.03, z), 0.13, a)
    for side in (-1, 1):
        box((0.9, 1.0, 0.6), (side * 1.25, -1.1, 0.3), dark, bevel=0.22, segments=1)
        for dx in (-0.2, 0.2):
            cone(0.13, 0.3, (side * 1.25 + dx, -1.55, 0.2), (0, -1, 0), a, sides=5)
        spot((side * 1.66, 0.3, 1.0), 0.26, a, towards=(side, 0, 0))
        # A side neck and its head, leaning out.
        for x, y, z, r in ((1.2, -0.1, 1.6, 0.55), (1.65, -0.3, 2.0, 0.48)):
            ball(r, (side * x, y, z), dark if r < 0.5 else c, segments=6)
        alien_jungle_hydra_head(c, a, (side * 2.0, -0.45, 2.1), side * 0.4, side * 0.3, 0.8, False)
    for y, z, r in ((0.1, 1.9, 0.68), (0.0, 2.45, 0.6), (-0.15, 2.95, 0.55)):
        ball(r, (0, y, z), c if r > 0.62 or r < 0.58 else dark, segments=6)
    alien_jungle_hydra_head(c, a, (0, -0.3, 3.15), 0, 0, 1.0, True)
    for y, z in ((0.75, 2.05), (1.2, 1.7)):
        cone(0.24, 0.6, (0, y, z), (0, 0.5, 1), a, sides=5, emission=0.4)  # spines down its back
    alien_jungle_vine([(0, 1.2, 0.6), (0.5, 2.0, 0.5), (1.0, 2.35, 0.8), (1.3, 2.4, 1.35)], dark, radius=0.28, tip=a, tip_size=0.34)
    for x, y, r in ((-1.9, -1.5, 0.2), (1.7, -1.9, 0.26), (0.3, -2.3, 0.17)):
        ball(r, (x, y, 0.16), a, segments=6, emission=2)  # bubbles in the venom


def jungle_behemoth(c, a):
    # A giant of bark and moss on its knuckles like an ape, tusked, toadstools on its shoulder, and its
    # signature: a huge jungle flower in bloom on its head.
    dark, moss = shade(c, -0.32), ALIEN_JUNGLE_LEAF
    front = biped(c, dark, w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.6, belly=shade(c, 0.42), foot=(1.1, 1.3, 0.6))
    for side in (-1, 1):
        ball(0.9, (side * 1.7, 0, 2.75), moss, scale=(1, 1, 0.8), segments=10)  # mossy shoulders
        box((0.78, 0.95, 1.8), (side * 2.0, -0.2, 1.55), dark, bevel=0.28, segments=1, rotation=(0, side * math.radians(-9), 0))
        ball(0.72, (side * 2.2, -0.35, 0.62), c, segments=8)
        for dx in (-0.25, 0.25):
            cone(0.17, 0.4, (side * 2.2 + dx, -0.9, 0.75), (0, -1, 0.15), ALIEN_JUNGLE_CREAM, sides=5)  # thorn knuckles
        tube(0.09, 1.3, (side * 1.3, front - 0.02, 3.25), (side * 0.15, 0, -1), moss, vertices=5)  # vines off its brow
        alien_jungle_leaf((side * 1.5, front - 0.04, 1.95), 0.5, moss, lean=180 + side * 20)
    alien_jungle_shroom((-1.75, 0.05, 3.3), 1.05, a)
    alien_jungle_shroom((-2.3, -0.35, 3.05), 0.6, "FFB03C")
    alien_jungle_leaf((1.6, 0.1, 3.25), 1.2, "8FE04F", lean=32, thick=0.2)
    alien_jungle_leaf((1.95, 0.0, 3.1), 0.9, moss, lean=62, thick=0.2)
    # A belt of vine with leaves hanging from it.
    box((3.12, 2.62, 0.3), (0, 0, 0.98), moss, bevel=0.12, segments=1)
    for x, size in ((-0.9, 0.55), (-0.3, 0.7), (0.35, 0.6), (0.95, 0.5)):
        alien_jungle_leaf((x, front - 0.1, 0.9), size, "8FE04F", lean=180)
    ball(0.24, (0, front - 0.12, 1.0), a, segments=6, emission=0.6)
    # The flower: a green cup, six great petals, a golden heart.
    tube(0.95, 0.3, (0, 0, 3.25), UP, moss, vertices=10)
    for index in range(6):
        px, py = ring(index * 60 + 30, 1.25)
        ball(0.85, (px, py, 3.95), a, scale=(0.72, 1.0, 0.3), rotation=(0.6, 0, -math.radians(index * 60 + 30)), segments=8)
        qx, qy = ring(index * 60, 0.8)
        ball(0.5, (qx, qy, 3.7), shade(a, 0.4), scale=(0.7, 1.0, 0.3), rotation=(0.8, 0, -math.radians(index * 60)), segments=6)
    ball(0.62, (0, 0, 3.75), "FFD93A", scale=(1, 1, 0.85), segments=8, emission=0.8)
    spot((-1.0, front, 1.55), 0.24, dark, ring_colour=shade(c, 0.3))  # a knot in the bark
    eyes(front, 2.35, 0.68, a, size=1.1, brow=dark, tilt=-24)
    mouth(front, 1.52, 1.2, "tusks", teeth=ALIEN_JUNGLE_CREAM)


WORLDS["Alien Jungle"] = [
    ("Spore Puff", spore_puff, "FF74C6", "A83C98", "floater"),
    ("Vine Creeper", vine_creeper, "AE66EE", "FFC24A", "walker"),
    ("Snap Pod", snap_pod, "F03C62", "3FB552", "walker"),
    ("Thorn Beast", thorn_beast, "B5733F", "FFEFA8", "walker"),
    ("Jungle Stalker", jungle_stalker, "2A62B8", "FF9A32", "walker"),
    ("Venom Hydra", venom_hydra, "7A36BC", "FFF05A", "boss"),
    ("Jungle Behemoth", jungle_behemoth, "9C5232", "FF5A9A", "boss"),
]
BACKDROPS["Alien Jungle"] = "7CCBA6"
