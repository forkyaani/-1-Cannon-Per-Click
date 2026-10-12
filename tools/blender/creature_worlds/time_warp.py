# ---------------------------------------------------------------------------------------------------
# Time Warp (world 14). Run by ../creatures.py with all its pieces, faces, bodies and features to hand.
# Everything here keeps time: clocks, cog wheels, hourglasses, pendulums, sand and brass. Amber, brass, deep blue.
# ---------------------------------------------------------------------------------------------------
TIME_WARP_BRASS, TIME_WARP_AMBER, TIME_WARP_BLUE, TIME_WARP_CREAM, TIME_WARP_SAND = "F0A82E", "FF8A2A", "2C3FA8", "FFF4D6", "F6D07A"


def time_warp_cog(at, radius, colour, teeth=10, thick=0.3, tooth=0.3, **look):
    """A cog wheel standing upright, facing the front; `at` is its middle."""
    x, y, z = at
    tube(radius, thick, (x, y - thick / 2, z), (0, 1, 0), colour, vertices=16, **look)
    for index in range(teeth):
        angle = index * 2 * math.pi / teeth
        reach = radius + tooth * 0.35
        slab((tooth * 1.15, thick, tooth * 1.3), (x + math.sin(angle) * reach, y, z + math.cos(angle) * reach), colour, rotation=(0, angle, 0), **look)


def time_warp_dial(at, radius, hands=(300, 60), marks=4, long=0.7, ink=INK, face=TIME_WARP_CREAM):
    """A clock face on a front that is at y = at[1]: a cream disc, marks round it, two hands (degrees from
    twelve, clockwise as you look at it)."""
    x, y, z = at
    tube(radius, 0.08, (x, y, z), (0, -1, 0), face, vertices=14)
    for index in range(marks):
        angle = index * 2 * math.pi / marks
        slab((0.1 * radius, 0.05, 0.2 * radius), (x + math.sin(angle) * radius * 0.82, y - 0.09, z + math.cos(angle) * radius * 0.82), ink, rotation=(0, angle, 0))
    for index, degrees in enumerate(hands):
        angle = math.radians(-degrees)  # seen from the front, +x is the creature's own left
        reach = radius * (long if index else long * 0.72)
        slab((0.13 * radius, 0.06, reach), (x + math.sin(angle) * reach / 2, y - 0.1 - 0.02 * index, z + math.cos(angle) * reach / 2), ink, rotation=(0, angle, 0))
    ball(0.12 * radius, (x, y - 0.12, z), TIME_WARP_AMBER, segments=6)


def time_warp_hourglass(at, size, frame, sand):
    """An hourglass standing on `at`, 1.4 * size tall: two caps, three posts, pale glass above and sand below."""
    x, y, z = at
    for dz in (0.0, 1.28):
        tube(0.52 * size, 0.12 * size, (x, y, z + dz * size), UP, frame, vertices=8, roughness=0.3)
    lathe([(0, 1.28 * size), (0.4 * size, 1.28 * size), (0.42 * size, 1.02 * size), (0.09 * size, 0.7 * size), (0, 0.7 * size)], "DDF6FF", segments=8, location=at, roughness=0.15)
    lathe([(0, 0.7 * size), (0.09 * size, 0.7 * size), (0.42 * size, 0.38 * size), (0.4 * size, 0.12 * size), (0, 0.12 * size)], sand, segments=8, location=at, emission=0.6)
    for index in range(3):
        px, py = ring(index * 120 + 60, 0.45 * size)
        tube(0.05 * size, 1.2 * size, (x + px, y + py, z + 0.1 * size), UP, frame, vertices=4)


def tick_tock(c, a):
    # An alarm clock that got up and walked: its face is its face, the hands make its moustache, two bells and
    # a hammer on its head, a winding key in its back.
    dark = shade(c, -0.3)
    tube(1.25, 1.2, (0, 0.6, 1.6), (0, -1, 0), c, vertices=16, roughness=0.35)
    front = -0.6
    hoop(1.2, 0.12, (0, front, 1.6), a, rotation=(math.pi / 2, 0, 0), segments=16, roughness=0.3)
    time_warp_dial((0, front, 1.6), 1.08, hands=(235, 125), marks=12, long=0.62)
    front -= 0.08
    feet(dark, 0.6, size=(0.6, 0.85, 0.5))
    for side in (-1, 1):
        ball(0.5, (side * 0.75, 0, 2.95), a, scale=(1, 1, 0.8), segments=8, roughness=0.3)  # bells
        tube(0.07, 0.3, (side * 0.75, 0, 2.6), UP, dark, vertices=5)
        ball(0.26, (side * 1.42, -0.15, 1.35), dark, segments=6)  # little hands
    tube(0.06, 0.5, (0, 0, 2.8), UP, dark, vertices=5)  # the hammer
    slab((0.5, 0.22, 0.2), (0, 0, 3.35), dark)
    tube(0.1, 0.5, (0, 0.6, 1.6), (0, 1, 0), a, vertices=6)  # the key
    for side in (-1, 1):
        tube(0.3, 0.12, (side * 0.3, 1.04, 1.6), (0, 1, 0), a, vertices=8)
    eyes(front, 2.0, 0.45, a, size=0.86, blush=False)
    for side in (-1, 1):
        disc(0.17, (side * 0.86, front + 0.03, 1.5), BLUSH, height=0.05, stretch=0.6, sides=8)


def sand_crawler(c, a):
    # A beetle with a dune for a back: the sand pours off it as it walks and a lost cog sticks out of the heap.
    dark = shade(a, -0.15)
    front = crawler(c, dark, w=2.7, d=2.1, h=1.1, lift=0.3, legs=3)
    lathe([(0, 1.3), (0.3, 1.2), (0.85, 0.7), (1.35, 0.25), (1.45, 0.0), (0, 0.0)], TIME_WARP_SAND, segments=12, stretch=0.8, location=(0.1, 0.2, 1.3), roughness=0.9)
    lathe([(0, 0.6), (0.3, 0.45), (0.65, 0.0), (0, 0.0)], TIME_WARP_SAND, segments=8, location=(-0.85, -0.25, 1.35), roughness=0.9)
    time_warp_cog((0.7, 0.25, 2.05), 0.5, TIME_WARP_BRASS, teeth=8, thick=0.26, tooth=0.26, roughness=0.3)
    tube(0.16, 0.3, (0.7, 0.1, 2.05), (0, -1, 0), TIME_WARP_BLUE, vertices=6)
    for side in (-1, 1):  # sand running off its flanks, a little heap where it lands
        for index in range(3):
            ball(0.16 - index * 0.03, (side * (1.38 + index * 0.06), 0.5, 1.2 - index * 0.36), TIME_WARP_SAND, segments=6)
        lathe([(0, 0.3), (0.42, 0.0), (0, 0.0)], TIME_WARP_SAND, segments=6, location=(side * 1.6, 0.5, 0.0), roughness=0.9)
        cone(0.18, 0.55, (side * 0.85, front + 0.05, 0.5), (-side * 0.5, -1, -0.1), a, sides=6)  # mandibles
    antennae(dark, TIME_WARP_AMBER, 0.6, 1.35, height=0.7, lean=30, y=-0.8, bulb=0.18)
    eyes(front, 1.0, 0.52, TIME_WARP_AMBER, size=0.86)
    mouth(front, 0.48, 0.38)


def clockwork_owl(c, a):
    # A wind-up owl: a big key turns in the top of its head, brass rims round its eyes, a cog on its tummy.
    front = floater(c, 1.05, squash=1.0)
    disc(0.7, (0, front + 0.1, 0.62), TIME_WARP_CREAM, height=0.1, sides=10)  # a pale tummy
    time_warp_cog((0, front + 0.02, 0.5), 0.2, a, teeth=6, thick=0.1, tooth=0.12)
    wings(a, 0.85, 0.9, size=0.95, y=0.15, sweep=20, kind="round")
    for side in (-1, 1):
        cone(0.34, 0.75, (side * 0.62, 0, 1.75), (side * 0.45, 0, 1), c, sides=6)  # ear tufts
        hoop(0.47, 0.085, (side * 0.43, front + 0.02, 1.3), a, rotation=(math.pi / 2, 0, 0), segments=10, roughness=0.3)
        ball(0.2, (side * 0.4, -0.25, 0.04), a, scale=(1, 1.3, 0.8), segments=6)  # feet
    # The key.
    tube(0.11, 0.5, (0, 0.1, 1.95), UP, a, vertices=6, roughness=0.3)
    for side in (-1, 1):
        hoop(0.34, 0.12, (side * 0.42, 0.1, 2.68), a, rotation=(math.pi / 2, 0, 0), segments=10, roughness=0.3)
    slab((0.3, 0.22, 0.28), (0, 0.1, 2.6), a)
    eyes(front + 0.04, 1.3, 0.43, a, size=0.8, blush=False)
    cone(0.2, 0.42, (0, front - 0.02, 0.98), (0, -1, -0.5), TIME_WARP_AMBER, sides=4)  # beak


def hourglass_ghost(c, a):
    # A ghost in the shape of an hourglass: a brass cap, a pinched waist with a brass ring, its own sand running
    # out from under it. Its top half is ghost, its lower half is sand.
    hem = lambda angle: 0.2 + 0.14 * math.cos(math.radians(angle * 5))
    lathe([(0, 3.0), (0.95, 2.95), (1.25, 2.6), (1.15, 2.15), (0.42, 1.62), (0, 1.62)], c, segments=20, roughness=0.25, emission=0.15)
    lathe([(0, 1.62), (0.42, 1.62), (0.42, 1.4), (1.1, 0.95), (lambda angle: 1.45, hem), (0, 0.45)], TIME_WARP_SAND, segments=20, roughness=0.5, emission=0.3)
    front = -1.23
    tube(1.12, 0.26, (0, 0, 2.92), UP, a, vertices=12, roughness=0.3)
    ball(0.26, (0, 0, 3.3), a, segments=6, roughness=0.3)
    hoop(0.5, 0.14, (0, 0, 1.51), a, segments=12, roughness=0.3)
    for index, (x, z) in enumerate(((0.0, 0.0), (0.2, -0.3), (-0.12, -0.55))):
        ball(0.2 - index * 0.04, (x, 0, 0.1 + z), TIME_WARP_SAND, segments=6, emission=0.6)
    tube(1.0, 0.2, (0, 0, 0.42), UP, a, vertices=12, tip=1.3, roughness=0.3)  # the cap under it
    eyes(front, 2.3, 0.45, a, size=0.86)
    mouth(front, 1.75, 0.3, "o")


def gear_golem(c, a):
    # A golem that is one big cog wheel on legs, its face on the hub, a small cog for each fist and one for a hat.
    dark = shade(a, -0.1)
    time_warp_cog((0, 0, 1.85), 1.3, c, teeth=10, thick=1.3, tooth=0.5, roughness=0.35)
    front = -0.65
    tube(1.0, 0.12, (0, front, 1.85), (0, -1, 0), a, vertices=14)  # the hub
    front -= 0.12
    for side in (-1, 1):
        box((0.75, 0.95, 0.5), (side * 0.6, -0.1, 0.25), dark, bevel=0.2, segments=2)
        box((0.4, 0.5, 0.5), (side * 0.6, 0, 0.6), dark, bevel=0.12, segments=1)
        box((0.4, 0.5, 0.85), (side * 1.95, -0.1, 1.55), dark, bevel=0.16, segments=1, rotation=(0, side * math.radians(-24), 0))
        time_warp_cog((side * 2.2, -0.2, 0.95), 0.36, TIME_WARP_AMBER, teeth=6, thick=0.4, tooth=0.24, roughness=0.3)
    time_warp_cog((0.2, 0.1, 3.72), 0.45, TIME_WARP_AMBER, teeth=8, thick=0.3, tooth=0.24, roughness=0.3)
    tube(0.14, 0.4, (0.2, -0.1, 3.72), (0, -1, 0), a, vertices=6)
    eyes(front, 2.05, 0.43, c, size=0.8, brow=c, tilt=-14, blush=False)
    mouth(front, 1.38, 0.5, "grin")


def pendulum_brute(c, a):
    # A grandfather clock of a brute: a dial in its chest, bells for ears, and in its raised fist the pendulum,
    # a great brass weight on a rod that it swings like a wrecking ball.
    dark = shade(c, -0.35)
    front = biped(c, dark, w=3.0, d=2.5, h=2.7, legs=0.5, arm=False, bevel=0.6, foot=(1.1, 1.3, 0.6))
    hoop(0.68, 0.12, (0, front, 1.08), a, rotation=(math.pi / 2, 0, 0), segments=14, roughness=0.3)
    time_warp_dial((0, front, 1.08), 0.62, hands=(330, 90), marks=4)
    box((3.1, 2.6, 0.3), (0, 0, 3.05), a, bevel=0.1, segments=1, roughness=0.3)  # the cornice of the clock case
    plate([(-1.3, 0), (0, 0.75), (1.3, 0)], c, (0, 0, 3.2), thick=2.2)
    ball(0.26, (0, 0, 4.05), a, segments=8, roughness=0.3)
    for side in (-1, 1):
        ball(0.5, (side * 1.55, 0.1, 3.45), a, scale=(1, 1, 0.8), segments=8, roughness=0.3)  # bells
        ball(0.78, (side * 1.72, 0, 2.6), a, scale=(1, 1, 0.75), segments=10, roughness=0.3)
    # The left arm hangs, the right one is raised.
    box((0.65, 0.8, 1.15), (-1.88, -0.1, 1.7), dark, bevel=0.25, segments=2)
    ball(0.52, (-1.98, -0.15, 0.95), a, segments=8, roughness=0.3)
    box((0.65, 0.8, 1.2), (2.2, -0.2, 3.0), dark, bevel=0.25, segments=2, rotation=(0, math.radians(38), 0))
    ball(0.52, (2.6, -0.3, 3.55), a, segments=8, roughness=0.3)
    way = Vector((0.32, -0.1, -1)).normalized()
    grip = Vector((2.6, -0.3, 3.55))
    tube(0.1, 2.3, grip, way, TIME_WARP_CREAM, vertices=6)
    bob = grip + way * 2.6
    ball(0.9, bob, TIME_WARP_BRASS, scale=(1, 0.5, 1), segments=12, roughness=0.3)
    ball(0.45, bob + Vector((0, -0.3, 0)), TIME_WARP_AMBER, scale=(1, 0.5, 1), segments=8, emission=0.8)
    cone(0.3, 0.6, bob + Vector((0, 0, -0.8)), (0, 0, -1), TIME_WARP_BRASS, sides=6, roughness=0.3)
    eyes(front, 2.5, 0.68, a, size=1.1, brow=dark, tilt=-24)
    mouth(front, 1.95, 0.7, "fangs")


def father_time(c, a):
    # The old man himself: a long blue robe sprinkled with stars, a white beard down to his belt, bushy brows,
    # a great clock standing behind his head like a halo, and a staff with an hourglass on top.
    hem = lambda angle: 0.12 * math.cos(math.radians(angle * 6))
    lathe([(0, 3.5), (0.95, 3.38), (1.42, 2.9), (1.5, 2.1), (1.65, 1.1), (lambda angle: 2.0, hem), (0, 0.3)], c, segments=20, roughness=0.5)
    front = -1.46
    tube(2.02, 0.22, (0, 0, 0.12), UP, a, vertices=20, tip=1.95, roughness=0.3)  # the gold hem
    # The clock behind his head.
    time_warp_cog((0, 1.0, 3.6), 1.75, a, teeth=12, thick=0.3, tooth=0.4, roughness=0.3)
    time_warp_dial((0, 0.85, 3.6), 1.52, hands=(335, 60), marks=12, long=0.8, ink=TIME_WARP_BLUE)
    # Beard, moustache, brows.
    tuft(WHITE, ((0, front - 0.02, 2.0, 0.55), (-0.52, front + 0.08, 2.15, 0.42), (0.52, front + 0.08, 2.15, 0.42), (0, front - 0.12, 1.45, 0.45), (0.05, front - 0.2, 0.98, 0.32)), roughness=0.8)
    for side in (-1, 1):
        ball(0.3, (side * 0.3, front - 0.3, 2.42), WHITE, scale=(1.3, 0.8, 0.75), segments=6, roughness=0.8)
        cone(0.5, 1.1, (side * 1.25, -0.35, 2.0), (side, -0.35, -0.5), shade(c, -0.25), sides=6)  # sleeves
    ball(0.36, (2.1, -0.75, 1.5), "FFD9B8", segments=8)  # the hands
    ball(0.36, (-2.1, -0.75, 1.5), "FFD9B8", segments=8)
    for x, z, size in ((-0.95, 1.2, 0.2), (0.9, 0.8, 0.24), (-0.5, 0.6, 0.16), (1.05, 1.75, 0.15)):
        star(size, (x, -math.sqrt(max(0.1, (1.62 + (1.1 - z) * 0.38) ** 2 - x * x)) - 0.03, z), a, depth=0.06, emission=1.5)
    # The staff.
    tube(0.11, 3.2, (2.1, -0.75, 0), UP, TIME_WARP_BRASS, vertices=6, roughness=0.3)
    time_warp_hourglass((2.1, -0.75, 3.2), 0.9, TIME_WARP_BRASS, TIME_WARP_AMBER)
    eyes(front, 2.9, 0.5, a, size=0.95, brow=WHITE, tilt=14)


WORLDS["Time Warp"] = [
    ("Tick Tock", tick_tock, "F2553C", "FFC83C", "walker"),
    ("Sand Crawler", sand_crawler, "F0A84A", "B8642A", "walker"),
    ("Clockwork Owl", clockwork_owl, "3C55D8", "FFB52E", "floater"),
    ("Hourglass Ghost", hourglass_ghost, "BFE6FF", "F0A82E", "floater"),
    ("Gear Golem", gear_golem, "F0A82E", "3448B8", "walker"),
    ("Pendulum Brute", pendulum_brute, "3550C8", "FFC03C", "boss"),
    ("Father Time", father_time, "3046B8", "FFC83C", "boss"),
]
BACKDROPS["Time Warp"] = "459C96"
