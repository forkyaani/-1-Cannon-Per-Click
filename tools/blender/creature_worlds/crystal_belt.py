# World 8, Crystal Belt: run by ../creatures.py with all its pieces, faces, bodies and features to hand.
# Everything here is cut like a gem: flat facets (smooth=False), pointed shards, a little glow in the crystal.


def crystal_belt_shard(at, way, radius, height, colour, sides=5, **look):
    """A crystal pointing any way (the kit's `crystal` only stands up): a faceted shaft and a point."""
    way = Vector(way).normalized()
    tube(radius * 0.75, height * 0.55, at, way, colour, tip=radius, vertices=sides, smooth=False, **look)
    tube(radius, height * 0.45, Vector(at) + way * height * 0.55, way, colour, tip=0.0, vertices=sides, smooth=False, **look)


def crystal_belt_gem(rings, colour, sides=4, **look):
    """A cut gem round the Z axis with a flat facet looking to the front. `rings` are (half width, z): the
    distance from the axis to the middle of a facet, so the front of a ring of half width w is y = -w."""
    grow = 1 / math.cos(math.pi / sides)
    return lathe([(r * grow, z) for r, z in rings], colour, segments=sides, rotation=(0, 0, math.pi / sides), smooth=False, **look)


def crystal_belt_diamond(at, size, colour, **look):
    """A flat diamond on the front of something: a core, a jewel."""
    plate([(0, size * 1.25), (size, 0), (0, -size * 1.25), (-size, 0)], colour, at, thick=0.22, **look)


# ---------------------------------------------------------------------------------------------------
def shardling(c, a):
    # A baby crystal: a cut white stone that bristles with violet shards like a hedgehog.
    box((2.1, 1.8, 1.6), (0, 0, 1.1), c, bevel=0.5, segments=1, smooth=False, roughness=0.25)
    front = -0.9
    feet(shade(a, -0.15), 0.52, size=(0.62, 0.85, 0.36))
    glow = dict(emission=0.5, roughness=0.25)
    crystal_belt_shard((0, 0.1, 1.75), (0, 0.1, 1), 0.4, 1.5, a, **glow)
    for side in (-1, 1):
        crystal_belt_shard((side * 0.6, 0.15, 1.7), (side * 0.55, 0.1, 1), 0.32, 1.15, a, **glow)
        crystal_belt_shard((side * 0.9, 0.1, 1.35), (side * 1, 0.1, 0.45), 0.3, 1.0, shade(a, 0.3), **glow)
        crystal_belt_shard((side * 0.95, 0.2, 0.85), (side * 1, 0.25, -0.05), 0.24, 0.7, a, **glow)
        crystal_belt_shard((side * 0.5, 0.75, 1.3), (side * 0.45, 1, 0.5), 0.28, 0.9, shade(a, 0.3), **glow)
        crystal_belt_shard((side * 0.32, -0.45, 1.8), (side * 0.25, -0.35, 1), 0.2, 0.6, shade(a, 0.55), **glow)
    crystal_belt_shard((0, 0.8, 1.5), (0, 1, 0.75), 0.32, 1.1, a, **glow)
    eyes(front, 1.2, 0.5, a, size=0.92)
    mouth(front, 0.6, 0.4)


def quartz_crab(c, a):
    # A crab cut out of rose quartz: a cluster of white quartz points on its back, crystal pincers, crystal legs.
    dark = shade(c, -0.22)
    box((2.7, 1.9, 1.25), (0, 0, 0.98), c, bevel=0.42, segments=1, smooth=False, roughness=0.3)
    front = -0.95
    for side in (-1, 1):
        for y in (-0.5, 0.15, 0.75):
            crystal_belt_shard((side * 1.2, y, 0.95), (side * 1, 0, -1.05), 0.22, 1.25, dark, sides=4)
        # Pincers: a faceted fist with two quartz points that open like a V.
        box((0.45, 0.8, 0.45), (side * 1.4, -0.9, 0.8), dark, bevel=0.15, segments=1, rotation=(0, 0, side * math.radians(-25)))
        chunk((0.5, 0.5, 0.45), (side * 1.7, -1.45, 0.9), c, detail=1)
        crystal_belt_shard((side * 1.55, -1.6, 1.05), (-side * 0.3, -1, 0.35), 0.3, 1.05, a, emission=0.4)
        crystal_belt_shard((side * 1.9, -1.6, 0.8), (side * 0.3, -1, -0.1), 0.26, 0.9, a, emission=0.4)
    for x, y, r, h, lean, colour in ((0.05, 0.3, 0.5, 1.7, (3, 4), a), (-0.75, 0.25, 0.38, 1.2, (-22, 0), "FFD9EA"), (0.8, 0.35, 0.36, 1.1, (24, 0), a),
                                     (0.3, -0.3, 0.28, 0.75, (10, -16), "FFD9EA"), (-0.35, 0.75, 0.3, 1.0, (-8, 20), a), (-0.35, -0.3, 0.22, 0.55, (-14, -14), a)):
        crystal((x, y, 1.5), r, h, colour, lean=lean, sides=6, emission=0.35, roughness=0.25)
    eyes(front, 1.05, 0.56, "FF5AA8", size=0.86)
    mouth(front, 0.55, 0.4)


def prism_bat(c, a):
    # A glass prism with a face: light goes in and comes out as wings of stained glass, a rainbow in panes.
    plate([(-1.3, 0.5), (-1.08, 0.2), (1.08, 0.2), (1.3, 0.5), (0.2, 2.45), (-0.2, 2.45)], c, thick=1.4, roughness=0.15, emission=0.15)
    front = -0.7
    dark = shade(c, -0.35)
    panes = ((a, (1.25, 1.35), (1.9, 0.65)), ("FFE45A", (1.9, 0.65), (1.5, -0.3)), ("FF8AD8", (1.5, -0.3), (0.5, -0.6)))
    for side in (-1, 1):
        for colour, (x1, z1), (x2, z2) in panes:
            plate([(0, 0), (side * x1, z1), (side * x2, z2)], colour, (side * 0.6, 0.3, 1.0), thick=0.12, emission=0.7, roughness=0.2)
        for x, z in ((1.25, 1.35), (1.9, 0.65), (1.5, -0.3), (0.5, -0.6)):  # the bones of the wing
            tube(0.09, math.hypot(x, z), (side * 0.6, 0.3, 1.0), (side * x, 0, z), dark, vertices=5)
        # Ears: crystal points on the prism's slopes.
        crystal_belt_shard((side * 0.62, 0.0, 1.6), (side * 0.75, 0, 1), 0.3, 1.0, dark, sides=4)
        crystal_belt_shard((side * 0.66, -0.12, 1.68), (side * 0.75, 0, 1), 0.17, 0.62, a, sides=4, emission=0.7)
        ball(0.2, (side * 0.4, -0.2, 0.14), dark, scale=(1, 1.3, 0.8), segments=6)  # little feet
    slab((0.16, 0.06, 1.3), (0, front + 0.01, 1.75), "FFFFFF", emission=1.5)  # the beam of white light inside it
    eyes(front, 1.02, 0.42, a, size=0.78)
    mouth(front, 0.5, 0.34, "fangs")


def geode_roller(c, a):
    # A round stone that rolls on a tread of knobs. It has cracked open: a nest of crystals in a white rim.
    ball(1.25, (0, 0, 1.25), c, scale=(1, 0.92, 1), segments=10, smooth=False, roughness=0.8)
    front = -1.1
    dark = shade(c, -0.25)
    for index in range(12):  # the tread: knobs round it from front to back, none over the face
        angle = math.radians(index * 30)
        if 195 < index * 30 < 345:
            continue
        chunk((0.3, 0.26, 0.3), (0, math.sin(angle) * 1.12, 1.25 + math.cos(angle) * 1.2), dark, detail=1)
    way = Vector((0.5, -0.3, 1)).normalized()
    middle = Vector((0, 0, 1.25)) + way * 1.12
    disc(0.9, middle, "FFF2FF", height=0.2, sink=0.25, towards=way, sides=9)
    disc(0.68, middle + way * 0.12, shade(a, -0.45), height=0.14, sink=0.1, towards=way, sides=9)
    for dx, dy, lean, r, h in ((0, 0, (0, 0, 0), 0.3, 1.15), (0.34, 0.1, (0.5, 0.1, 0), 0.22, 0.8), (-0.34, 0.05, (-0.5, 0, 0), 0.22, 0.75), (0, -0.34, (0, -0.5, 0), 0.2, 0.6), (0.05, 0.36, (0, 0.5, 0), 0.2, 0.7)):
        crystal_belt_shard(middle + Vector((dx, dy, 0.05)), way + Vector(lean) * 0.7, r, h, a if r > 0.2 else shade(a, 0.35), emission=1.2, roughness=0.2)
    for side in (-1, 1):  # the cut ends of the geode, one at each side: an axle cap of crystal
        disc(0.6, (side * 1.16, 0, 1.25), "FFF2FF", height=0.16, sink=0.2, towards=(side, 0, 0), sides=8)
        disc(0.4, (side * 1.3, 0, 1.25), a, height=0.14, sink=0.05, towards=(side, 0, 0), sides=6, emission=1.2)
    rocks(dark, ((-1.5, 0.9, 0.2, 0.24), (1.45, 1.0, 0.16, 0.18)))  # what it kicks up
    eyes(front, 1.3, 0.46, a, size=0.86)
    mouth(front, 0.72, 0.4)


def crystal_golem(c, a):
    # One great cut gem of amber on two feet: no stone in it. Its arms are crystals, its shoulders bristle.
    dark = shade(c, -0.25)
    crystal_belt_gem([(0, 2.95), (0.85, 2.95), (1.08, 2.68), (1.08, 1.7), (0.7, 0.45), (0, 0.45)], c, roughness=0.2, emission=0.12)
    front = -1.08
    for side in (-1, 1):
        box((0.75, 0.95, 0.55), (side * 0.45, -0.1, 0.28), dark, bevel=0.2, segments=1, smooth=False)
        crystal_belt_shard((side * 1.5, -0.05, 2.3), (side * 0.12, -0.12, -1), 0.45, 1.9, dark, sides=6, roughness=0.2)  # an arm
        crystal_belt_shard((side * 1.15, 0, 2.5), (side * 0.7, 0, 1), 0.36, 1.1, a, emission=0.8)
        crystal_belt_shard((side * 1.3, 0.1, 2.35), (side * 1, 0.1, 0.3), 0.26, 0.8, a, emission=0.8)
        crystal((side * 0.55, 0, 2.9), 0.26, 0.8, a, lean=(side * 24, 0), emission=0.8)
    crystal((0, 0, 2.9), 0.36, 1.15, a, emission=0.8)
    crystal_belt_diamond((0, -0.92, 1.12), 0.3, "FFFFFF", emission=2)
    eyes(front, 2.2, 0.5, "FF8A1F", size=0.92, brow=dark, tilt=-14)
    mouth(front, 1.58, 0.5, "flat")


def shard_sentinel(c, a):
    # The belt's guard: a tall obelisk of amethyst with a crystal halberd and a kite shield, shards for a mane.
    dark = shade(c, -0.35)
    crystal_belt_gem([(0, 4.7), (0.85, 3.75), (1.35, 3.35), (1.35, 1.9), (1.0, 0.55), (0, 0.55)], c, roughness=0.2, emission=0.1)
    front = -1.35
    glow = dict(emission=0.6, roughness=0.2)
    for side in (-1, 1):
        box((1.0, 1.25, 0.6), (side * 0.6, -0.1, 0.3), dark, bevel=0.22, segments=1, smooth=False)
        crystal_belt_shard((side * 0.95, 0.5, 3.4), (side * 0.6, 0.3, 1), 0.36, 1.5, a, **glow)
        crystal_belt_shard((side * 1.3, 0.35, 3.0), (side * 1, 0.2, 0.55), 0.34, 1.3, a, **glow)
        crystal_belt_shard((side * 1.3, 0.35, 2.3), (side * 1, 0.2, 0.12), 0.28, 1.0, shade(a, -0.12), **glow)
        box((0.6, 0.75, 1.1), (side * 1.68, -0.35, 1.75), dark, bevel=0.2, segments=1, smooth=False)  # gauntlets
        ball(0.42, (side * 1.8, -0.55, 1.1), a, segments=8)
    crystal_belt_shard((0, 1.2, 3.0), (0, 1, 0.7), 0.36, 1.3, a, **glow)
    box((2.8, 2.8, 0.3), (0, 0, 1.55), GOLD, bevel=0.1, segments=1, roughness=0.3)  # a gold belt, a jewel on it
    crystal_belt_diamond((0, front - 0.1, 1.55), 0.3, a, emission=2)
    # The halberd, in its right fist.
    tube(0.11, 4.3, (1.85, -0.75, 0.1), UP, GOLD, vertices=6, roughness=0.3)
    crystal_belt_shard((1.85, -0.75, 4.2), UP, 0.42, 1.5, a, sides=4, emission=1.2)
    crystal_belt_shard((1.85, -0.75, 4.3), (1, 0, 0.25), 0.3, 0.9, a, sides=4, emission=1.2)
    crystal_belt_shard((1.85, -0.75, 4.3), (-1, 0, 0.25), 0.3, 0.9, a, sides=4, emission=1.2)
    # The shield, on its left arm.
    kite = [(-0.85, 1.0), (0.85, 1.0), (0.95, 0.1), (0, -1.25), (-0.95, 0.1)]
    plate(kite, a, (-1.85, -1.1, 1.75), thick=0.24, roughness=0.2)
    plate([(x * 0.72, z * 0.72 + 0.03) for x, z in kite], c, (-1.85, -1.24, 1.75), thick=0.1, roughness=0.2)
    crystal_belt_diamond((-1.85, -1.3, 1.8), 0.24, GOLD, roughness=0.3)
    eyes(front, 2.72, 0.66, "FF7AE8", size=1.12, brow=a, tilt=-26, blush=False)
    mouth(front, 2.02, 0.7, "fangs")


def crystal_monarch(c, a):
    # The king of the belt: a diamond-white giant under a crown of crystals, a throne of spires at its back,
    # a cape, and a sceptre with a great pink diamond.
    pale = shade("9CC0F5", 0.1)
    front = biped(c, pale, w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.6, foot=(1.1, 1.3, 0.6), roughness=0.25)
    # The throne: a fan of tall spires behind it, in the belt's colours.
    for index, (colour, height) in enumerate((("B58CFF", 2.3), (a, 2.9), ("FFD35A", 3.5), (a, 2.9), ("B58CFF", 2.3))):
        lean = math.radians((index - 2) * 27)
        crystal_belt_shard((math.sin(lean) * 1.1, 1.35, 2.4 + math.cos(lean) * 0.3), (math.sin(lean), 0.1, math.cos(lean)), 0.55, height, colour, sides=6, emission=0.7, roughness=0.2)
    # The cape, with a gold clasp at each shoulder.
    plate([(-1.75, 3.1), (1.75, 3.1), (2.15, 0.25), (1.1, 0.5), (0, 0.2), (-1.1, 0.5), (-2.15, 0.25)], shade(a, -0.3), (0, 1.38, 0), thick=0.26)
    for side in (-1, 1):
        ball(0.8, (side * 1.7, 0, 2.85), GOLD, scale=(1, 1, 0.7), segments=10, roughness=0.3)
        crystal_belt_shard((side * 1.75, 0, 3.1), (side * 0.5, 0, 1), 0.3, 1.0, a, emission=1)
        box((0.65, 0.8, 1.2), (side * 1.85, -0.1, 1.75), pale, bevel=0.25, segments=2)
        ball(0.5, (side * 1.95, -0.15, 1.0), c, segments=8)
    box((3.1, 2.6, 0.36), (0, 0, 0.95), GOLD, bevel=0.12, segments=1, roughness=0.3)
    crystal_belt_diamond((0, front - 0.12, 1.0), 0.36, a, emission=2)
    # The crown: a gold band, a ring of pink points round one tall white spire.
    tube(1.12, 0.42, (0, 0, 3.25), UP, GOLD, vertices=12, roughness=0.3)
    for index in range(6):
        x, y = ring(index * 60 + 30, 0.88)
        crystal((x, y, 3.6), 0.3, 1.15 if index % 2 else 0.85, a, lean=(x * 16, y * 16), emission=1)
        gx, gy = ring(index * 60, 1.14)
        ball(0.14, (gx, gy, 3.46), "6EF0E6", segments=6, emission=1)
    crystal((0, 0, 3.6), 0.42, 1.9, "FFFFFF", sides=6, emission=0.8)
    # The sceptre, in its right fist.
    tube(0.12, 3.2, (2.3, -0.55, 0.3), UP, GOLD, vertices=6, roughness=0.3)
    ball(0.26, (2.3, -0.55, 3.5), GOLD, segments=8, roughness=0.3)
    crystal_belt_shard((2.3, -0.55, 4.05), UP, 0.48, 1.05, a, sides=6, emission=2)
    crystal_belt_shard((2.3, -0.55, 4.05), (0, 0, -1), 0.48, 0.7, a, sides=6, emission=2)
    eyes(front, 2.35, 0.68, a, size=1.1, brow=shade(a, -0.3), tilt=-22)
    mouth(front, 1.6, 0.8, "grin")


WORLDS["Crystal Belt"] = [
    ("Shardling", shardling, "F6F4FF", "9466F2", "walker"),
    ("Quartz Crab", quartz_crab, "FFB0D0", "FFFFFF", "walker"),
    ("Prism Bat", prism_bat, "C873F2", "6EF0E6", "floater"),
    ("Geode Roller", geode_roller, "9C86C6", "D45CF2", "walker"),
    ("Crystal Golem", crystal_golem, "FFC44D", "FFF5D2", "walker"),
    ("Shard Sentinel", shard_sentinel, "9A52EC", "F8F6FF", "boss"),
    ("Crystal Monarch", crystal_monarch, "ECF7FF", "FF72DC", "boss"),
]
BACKDROPS["Crystal Belt"] = "3F9AA2"
