# ---------------------------------------------------------------------------------------------------
# Infinity (world 15). Run by ../creatures.py with all its pieces, faces, bodies and features to hand.
# The end of everything, and it is bright: white and gold light, loops, infinity signs, a soft rainbow at
# the edges. What would be grey on a white thing is lilac here.
# ---------------------------------------------------------------------------------------------------
INFINITY_GOLD, INFINITY_LILAC, INFINITY_SKY = "FFC42E", "A894F0", "4FB4FF"
INFINITY_RAINBOW = ("FF6F91", "FFA24A", "FFE14F", "63DC86", "55C4FF", "A27CFF")


def infinity_sweep(path, thick, colour, at=(0, 0, 0), closed=False, **look):
    """A square rod along a path of (x, z) points in an upright plane that faces the front."""
    points = [Vector((x, 0, z)) for x, z in path]
    count = len(points)
    vertices = []
    for index, point in enumerate(points):
        before = points[(index - 1) % count] if closed or index > 0 else point
        after = points[(index + 1) % count] if closed or index < count - 1 else point
        along = (after - before).normalized()
        out = Vector((-along.z, 0, along.x))
        for corner in (out * thick, Vector((0, -thick, 0)), -out * thick, Vector((0, thick, 0))):
            vertices.append(tuple(point + corner))
    faces = []
    for index in range(count if closed else count - 1):
        a, b = index * 4, ((index + 1) % count) * 4
        faces += [(a + corner, a + (corner + 1) % 4, b + (corner + 1) % 4, b + corner) for corner in range(4)]
    if not closed:
        faces += [(0, 1, 2, 3), (4 * count - 4, 4 * count - 3, 4 * count - 2, 4 * count - 1)]
    return mesh(vertices, faces, colour, at, tidy=True, **look)


def infinity_rainbow(path, thick, at=(0, 0, 0), colours=INFINITY_RAINBOW, **look):
    """`infinity_sweep` along a path, cut into as many lengths as there are colours."""
    each = (len(path) - 1) / len(colours)
    for index, colour in enumerate(colours):
        infinity_sweep(path[round(index * each):round((index + 1) * each) + 1], thick, colour, at, **look)


def infinity_circle(radius, steps=18, tall=1.0, start=0, sweep=360):
    """The (x, z) points of a circle (an oval when `tall` is not 1) from `start` degrees (0 is the top) over `sweep`
    degrees; the last point is the first again when it goes all the way round."""
    return [(math.sin(math.radians(start + index * sweep / steps)) * radius, math.cos(math.radians(start + index * sweep / steps)) * radius * tall) for index in range(steps + 1)]


def infinity_eight(size, steps=24):
    """The (x, z) points of an infinity sign lying on its side, `size` from its middle to each end."""
    path = []
    for index in range(steps + 1):
        t = index * 2 * math.pi / steps
        path.append((size * math.cos(t) / (1 + math.sin(t) ** 2), size * 1.25 * math.sin(t) * math.cos(t) / (1 + math.sin(t) ** 2)))
    return path


def loop_blob(c, a):
    # A blob of light whose top is pulled up into a loop, like the handle of a kettle: a rainbow ring with a star
    # caught in it.
    front = blob(c, w=2.4, d=2.1, h=1.6, puddle=a, bevel=0.78, roughness=0.4)
    tuft(c, ((-1.05, -0.4, 0.3, 0.42), (1.1, -0.3, 0.28, 0.4)), roughness=0.4)
    box((0.9, 0.7, 0.5), (0, 0.1, 1.62), c, bevel=0.22, segments=2, roughness=0.4)
    infinity_rainbow(infinity_circle(0.85, steps=18, start=180), 0.21, (0, 0.1, 2.6), emission=0.5)
    star(0.36, (0, 0.1, 2.6), a, depth=0.16, emission=1.5)
    eyes(front, 0.98, 0.5, INFINITY_SKY, size=0.9)
    mouth(front, 0.42, 0.42)


def zero_bat(c, a):
    # A bat that sits inside a big gold nought: zero, the other end of everything.
    ball(1.0, (0, 0, 1.75), c, scale=(1, 0.95, 1), segments=12, roughness=0.4)
    front = -0.93
    infinity_sweep(infinity_circle(1.18, steps=18, tall=1.24)[:-1], 0.19, a, (0, 0.12, 1.75), closed=True, roughness=0.3, emission=0.4)
    wings(INFINITY_LILAC, 1.25, 1.5, size=0.82, y=0.12, sweep=14)
    ears(c, "FF9EC8", 0.42, 2.5, size=0.55, lean=20)
    disc(0.56, (0, front + 0.06, 1.3), "FFFFFF", height=0.08, sides=10)
    for side in (-1, 1):
        ball(0.2, (side * 0.4, -0.25, 0.78), INFINITY_LILAC, scale=(1, 1.3, 0.8), segments=6)
    eyes(front, 1.88, 0.42, a, size=0.84)
    mouth(front, 1.32, 0.36, "fangs")


def endless_worm(c, a):
    # A worm with no end: it goes round in a ring, every segment another colour of the rainbow, and its tail comes
    # back to its own cheek.
    for index in range(8):
        size = 0.66 - index * 0.045
        x, y = ring(222 + index * 41, 1.5)
        ball(size, (x, y, size * 0.92), INFINITY_RAINBOW[index % 6], scale=(1, 1, 0.92), segments=8, roughness=0.4)
    x, y = ring(222 + 8 * 41, 1.45)
    cone(0.26, 0.6, (x, y, 0.3), (-0.3, -1, 0.1), a, sides=6, emission=0.8)
    cube(1.6, 1.45, 1.4, 0.1, c, bevel=0.5, seg=2, y=-1.55, roughness=0.4)
    front = -2.275
    antennae(INFINITY_LILAC, a, 0.42, 1.45, height=0.6, lean=24, y=-1.5, bulb=0.2)
    eyes(front, 0.95, 0.38, a, size=0.74)
    mouth(front, 0.4, 0.3, "o")


def echo_ghost(c, a):
    # A ghost and its echoes: the same ghost again behind it, smaller and fainter each time, pink then blue.
    hem = lambda angle: 0.12 * math.cos(math.radians(angle * 5))

    def sheet(x, y, size, colour, segments, **look):
        ghost = lathe([(0, 2.3), (0.75, 2.15), (1.25, 1.7), (1.35, 1.0), (lambda angle: 1.5, hem), (0, 0.35)], colour, segments=segments, location=(x, y, (1 - size) * 0.5), **look)
        ghost.scale = (size, size, size)

    sheet(0, 0, 1.0, c, 20, roughness=0.3)
    front = -1.28
    for (x, y, size, colour) in ((1.0, 1.0, 0.84, "FF9EC8"), (1.85, 1.95, 0.68, "8FD4FF")):
        sheet(x, y, size, colour, 12, roughness=0.4, emission=0.4)
        for side in (-1, 1):
            disc(0.3 * size, (x + side * 0.42 * size, y - 1.3 * size, (1 - size) * 0.5 + 1.55 * size), INK, height=0.06, stretch=1.15, sides=8)
    for side in (-1, 1):
        ball(0.28, (side * 1.5, -0.6, 0.9), c, segments=8)  # mitten hands
    eyes(front, 1.55, 0.46, a, size=0.88)
    mouth(front, 0.98, 0.3, "o")


def omega_golem(c, a):
    # The last letter, on legs: a white stone golem that wears a great gold omega on its head.
    front = biped(c, INFINITY_LILAC, w=2.0, d=1.8, h=2.0, legs=0.4, arm=False, bevel=0.45, foot=(0.8, 1.0, 0.48), roughness=0.5)
    arms(INFINITY_LILAC, 1.25, 1.35, size=(0.5, 0.62, 1.05), tilt=-14, fist=a, fist_size=0.42)
    box((2.08, 1.88, 0.3), (0, 0, 0.82), a, bevel=0.1, segments=1, roughness=0.3)
    omega = [(-1.2, 0.12), (-0.45, 0.12)] + [(x, z + 0.95) for x, z in infinity_circle(0.82, steps=12, start=-150, sweep=300)] + [(0.45, 0.12), (1.2, 0.12)]
    infinity_sweep(omega, 0.22, a, (0, 0.05, 2.4), roughness=0.3, emission=0.5)
    spot((0.7, front, 1.0), 0.16, INFINITY_LILAC)
    spot((-0.72, front, 2.15), 0.13, INFINITY_LILAC)
    eyes(front, 1.75, 0.46, a, size=0.88, brow=INFINITY_LILAC, tilt=-14)
    mouth(front, 1.18, 0.42, "flat")


def infinity_guardian(c, a):
    # The keeper of the last gate: a knight in white and gold with a great infinity sign for wings, a round
    # shield with the same sign on it, and a spear of light.
    front = biped(c, INFINITY_LILAC, w=2.7, d=2.3, h=2.5, legs=0.5, arm=False, bevel=0.6, foot=(1.0, 1.2, 0.55), roughness=0.45)
    infinity_sweep(infinity_eight(3.0, steps=24)[:-1], 0.27, a, (0, 1.2, 2.55), closed=True, roughness=0.3, emission=0.5)
    box((2.2, 0.4, 0.9), (0, front + 0.05, 1.2), a, bevel=0.2, segments=2, roughness=0.3)  # a gold breastplate
    box((2.78, 2.38, 0.28), (0, 0, 0.78), INFINITY_LILAC, bevel=0.1, segments=1)
    for side in (-1, 1):
        ball(0.75, (side * 1.55, 0, 2.55), a, scale=(1, 1, 0.75), segments=10, roughness=0.3)
        box((0.6, 0.72, 1.05), (side * 1.68, -0.1, 1.65), INFINITY_LILAC, bevel=0.24, segments=2)
        ball(0.46, (side * 1.78, -0.2, 0.95), a, segments=8, roughness=0.3)
    helmet(a, 2.85, 1.32, trim=WHITE, squash=0.6)
    box((0.26, 0.22, 0.6), (0, front - 0.05, 2.7), a, bevel=0.08, segments=1)
    plate([(-0.9, 0.0), (-1.05, 0.55), (-0.6, 1.0), (0.3, 1.05), (0.95, 0.6), (1.0, 0.0)], WHITE, (0, 0.1, 3.5), thick=0.3, rotation=(0, 0, math.pi / 2))  # a white crest
    # The shield.
    tube(1.0, 0.2, (-2.05, -1.0, 1.4), (0, -1, 0), a, vertices=12, roughness=0.3)
    tube(0.8, 0.08, (-2.05, -1.2, 1.4), (0, -1, 0), WHITE, vertices=12)
    infinity_sweep(infinity_eight(0.6, steps=14)[:-1], 0.09, INFINITY_SKY, (-2.05, -1.32, 1.4), closed=True, emission=1)
    # The spear.
    tube(0.1, 3.5, (1.85, -0.5, 0.2), UP, a, vertices=6, roughness=0.3)
    crystal((1.85, -0.5, 3.7), 0.3, 1.0, "FFFDE8", sides=4, emission=2)
    eyes(front, 2.05, 0.62, INFINITY_SKY, size=1.05, brow=a, tilt=-22)
    mouth(front, 1.78, 0.5, "flat")


def the_last_titan(c, a):
    # The last thing there will ever be: a titan of gold with the rainbow for a halo, wings of pale light, the
    # sign of forever shining on its chest and a crown of white fire.
    dark = shade(c, -0.32)
    front = biped(c, dark, w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.6, foot=(1.1, 1.3, 0.6), roughness=0.35)
    infinity_rainbow(infinity_circle(2.2, steps=24, start=-150, sweep=300), 0.26, (0, 1.1, 3.3), emission=0.8)
    infinity_sweep(infinity_circle(1.75, steps=16, start=-140, sweep=280), 0.1, a, (0, 1.1, 3.3), emission=2)
    for side in (-1, 1):
        for index in range(3):  # wings of light
            crystal((side * (1.75 + index * 0.5), 1.0, 2.0 - index * 0.5), 0.32 - index * 0.04, 1.9 - index * 0.35, INFINITY_RAINBOW[4 - index] if side < 0 else INFINITY_RAINBOW[index], lean=(side * (38 + index * 22), 0), sides=4, emission=0.8)
        ball(0.82, (side * 1.72, 0, 2.85), a, scale=(1, 1, 0.78), segments=10, roughness=0.3)
        cone(0.28, 0.75, (side * 1.9, 0, 3.3), (side * 0.5, 0, 1), a, sides=6, emission=1)
        box((0.65, 0.8, 1.2), (side * 1.88, -0.1, 1.72), dark, bevel=0.25, segments=2)
        ball(0.54, (side * 1.98, -0.15, 0.95), a, segments=8, roughness=0.3)
    box((3.1, 2.6, 0.34), (0, 0, 0.82), a, bevel=0.12, segments=1, roughness=0.3)
    infinity_sweep(infinity_eight(0.95, steps=16)[:-1], 0.14, a, (0, front - 0.1, 1.5), closed=True, emission=0.3)
    tube(1.0, 0.3, (0, 0, 3.28), UP, a, vertices=12, roughness=0.3)
    crystal((0, 0, 3.5), 0.4, 1.5, a, sides=6, emission=1.5)
    for side in (-1, 1):
        crystal((side * 0.62, 0, 3.5), 0.28, 0.95, a, lean=(side * 22, 0), emission=1.5)
    eyes(front, 2.45, 0.7, INFINITY_SKY, size=1.1, brow=a, tilt=-22)
    mouth(front, 2.08, 0.7, "fangs")


WORLDS["Infinity"] = [
    ("Loop Blob", loop_blob, "FFF4DC", "FFC42E", "walker"),
    ("Zero Bat", zero_bat, "ECE2FF", "FFC42E", "floater"),
    ("Endless Worm", endless_worm, "FBF6FF", "FFC42E", "walker"),
    ("Echo Ghost", echo_ghost, "F8F4FF", "FFC42E", "floater"),
    ("Omega Golem", omega_golem, "F4EEFF", "FFC42E", "walker"),
    ("Infinity Guardian", infinity_guardian, "F6F2FF", "FFC02E", "boss"),
    ("The Last Titan", the_last_titan, "FFC02E", "FFFFFF", "boss"),
]
BACKDROPS["Infinity"] = "5F58B8"
