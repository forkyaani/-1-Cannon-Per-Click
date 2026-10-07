# World 9, Robot Factory: run by ../creatures.py with all its pieces, faces, bodies and features to hand.
# Machines, all of them: bolts, saws, cogs, hazard yellow and striped chimneys like the island's.

ROBOT_FACTORY_STEEL, ROBOT_FACTORY_HAZARD, ROBOT_FACTORY_TEAL, ROBOT_FACTORY_BLADE = "B9C6F2", "FFC83C", "45D6C4", "F6F8FF"


def robot_factory_saw(at, radius, colour, hub, axis=(1, 0, 0), teeth=12, thick=0.14):
    """A circular saw blade round `axis`: a disc, hooked teeth on its rim, a hub on both sides."""
    at, normal = Vector(at), Vector(axis).normalized()
    across = normal.orthogonal().normalized()
    along = normal.cross(across)
    tube(radius, thick, at - normal * thick / 2, normal, colour, vertices=teeth, roughness=0.3)
    for index in range(teeth):
        angle = (index + 0.5) * 2 * math.pi / teeth
        out = across * math.cos(angle) + along * math.sin(angle)
        hook = along * math.cos(angle) - across * math.sin(angle)
        cone(radius * 0.15, radius * 0.34, at + out * radius * 0.9, out + hook * 0.8, colour, sides=4, roughness=0.3)
    tube(radius * 0.3, thick + 0.14, at - normal * (thick + 0.14) / 2, normal, hub, vertices=8)


def robot_factory_cog(at, radius, colour, teeth=10, thick=0.3, tooth=0.3, **look):
    """A cog wheel standing upright, facing the front."""
    x, y, z = at
    tube(radius, thick, (x, y - thick / 2, z), (0, 1, 0), colour, vertices=16, **look)
    for index in range(teeth):
        angle = index * 2 * math.pi / teeth
        reach = radius + tooth * 0.35
        slab((tooth * 1.15, thick, tooth * 1.3), (x + math.sin(angle) * reach, y, z + math.cos(angle) * reach), colour, rotation=(0, angle, 0), **look)


def robot_factory_stack(at, radius, height, glow, bands=4, smoke=True):
    """A factory chimney in orange and cream bands, a glowing mouth, puffs of smoke."""
    x, y, z = at
    step = height / bands
    for index in range(bands):
        wide, narrow = radius * (1 - 0.3 * index / bands), radius * (1 - 0.3 * (index + 1) / bands)
        tube(wide, step, (x, y, z + index * step), UP, "FF6A2E" if index % 2 == 0 else "FFF3E0", tip=narrow, vertices=8)
    tube(radius * 0.82, 0.14, (x, y, z + height), UP, glow, vertices=8, emission=1.5)
    if smoke:
        tuft("FFF6E0", ((x + 0.05, y, z + height + radius * 0.9, radius * 0.75), (x + radius * 0.7, y + 0.05, z + height + radius * 1.9, radius * 0.55), (x + radius * 0.5, y, z + height + radius * 2.7, radius * 0.38)))


def scrap_bot(c, a):
    # Bolted together out of what was lying about: a dented box, a lid that no longer shuts, a patch of another
    # colour, a boot on one side and a wheel on the other, a spring for an aerial, a spanner in its hand.
    steel, hazard, teal = ROBOT_FACTORY_STEEL, ROBOT_FACTORY_HAZARD, ROBOT_FACTORY_TEAL
    cube(2.0, 1.7, 1.75, 0.5, c, bevel=0.3, seg=2)
    front = -0.85
    box((0.75, 1.0, 0.6), (-0.55, -0.15, 0.3), a, bevel=0.2, segments=2)  # the boot
    tube(0.45, 0.42, (0.36, -0.1, 0.45), (1, 0, 0), a, vertices=10)  # the wheel
    tube(0.18, 0.5, (0.32, -0.1, 0.45), (1, 0, 0), hazard, vertices=6)
    box((2.15, 1.85, 0.28), (0.08, 0.05, 2.42), shade(c, 0.35), bevel=0.1, segments=1, rotation=(0, math.radians(-9), 0))  # the lid, ajar
    box((0.85, 0.12, 0.62), (0.5, front - 0.02, 0.88), teal, bevel=0.05, segments=1, rotation=(0, math.radians(8), 0))  # a patch
    for dx, dz in ((-0.3, -0.2), (0.3, -0.2), (-0.3, 0.2), (0.3, 0.2)):
        ball(0.07, (0.5 + dx, front - 0.09, 0.88 + dz), steel, segments=6)
    box((0.12, 0.9, 0.6), (-1.0, 0.15, 1.75), hazard, bevel=0.05, segments=1)  # another, on its side
    for side in (-1, 1):  # bolts through its head
        tube(0.2, 0.36, (side * 0.98, 0.1, 1.2), (side, 0, 0), steel, vertices=6)
    # The spring, with a red bulb.
    point = Vector((0.55, 0.1, 2.5))
    for index in range(5):
        after = Vector((0.55 + (0.2 if index % 2 == 0 else -0.2), 0.1, 2.5 + (index + 1) * 0.19))
        tube(0.06, (after - point).length, point, after - point, steel, vertices=5)
        point = after
    ball(0.24, point, "FF5A5A", segments=8, emission=2)
    # Arms: a bare pipe with a claw, and one that holds the spanner up.
    tube(0.15, 0.75, (0.95, -0.2, 1.35), (1, -0.1, -0.7), a, vertices=6)
    for dz in (-0.14, 0.14):
        cone(0.12, 0.4, (1.52, -0.26, 0.9 + dz), (0.6, -0.4, dz * 4 - 0.5), steel, sides=5)
    tube(0.16, 0.8, (-0.95, -0.25, 1.3), (-1, -0.2, 0.25), a, vertices=6)
    ball(0.26, (-1.75, -0.42, 1.5), c, segments=8)
    tube(0.13, 1.3, (-1.78, -0.45, 1.05), (-0.08, 0, 1), steel, vertices=6)
    for dx in (-0.27, 0.27):
        box((0.24, 0.26, 0.5), (-1.88 + dx, -0.45, 2.72), steel, bevel=0.07, segments=1, rotation=(0, dx * 0.9, 0))
    box((0.78, 0.26, 0.34), (-1.88, -0.45, 2.42), steel, bevel=0.1, segments=1)
    eyes(front, 1.62, 0.48, hazard, size=0.9)
    hoop(0.56, 0.08, (0.48, front - 0.04, 1.62), steel, rotation=(math.pi / 2, 0, 0), segments=10)  # a lens screwed over one eye
    slab((0.62, 0.1, 0.12), (-0.25, front - 0.04, 0.88), INK)  # a mouth that was welded shut
    for index in range(3):
        slab((0.07, 0.12, 0.26), (-0.45 + index * 0.2, front - 0.05, 0.88), steel)


def welder_drone(c, a):
    # A flying welder: a rotor on its head, a welding mask pushed up on its forehead, a torch with a blue flame.
    dark = shade(c, -0.45)
    front = floater(c, 1.0, squash=0.92)
    tilt = math.radians(-58)
    box((1.55, 0.3, 0.9), (0, -0.62, 1.74), dark, bevel=0.12, segments=1, rotation=(tilt, 0, 0))
    slab((0.95, 0.08, 0.3), (0, -0.71, 1.875), a, rotation=(tilt, 0, 0), emission=1.5)  # the mask's window
    for side in (-1, 1):
        tube(0.17, 0.16, (side * 0.82, -0.4, 1.42), (side, 0, 0), ROBOT_FACTORY_HAZARD, vertices=6)  # its hinges
    # The rotor.
    tube(0.09, 0.5, (0, 0.2, 1.75), UP, dark, vertices=6)
    for turn in (0.5, 0.5 + math.pi / 2):
        box((2.7, 0.36, 0.08), (0, 0.2, 2.25), a, bevel=0.03, segments=1, rotation=(0, 0, turn))
    ball(0.17, (0, 0.2, 2.3), ROBOT_FACTORY_HAZARD, segments=6)
    # The torch on a short arm, its flame and its sparks.
    way = Vector((-0.35, -1, -0.15)).normalized()
    hand = Vector((-0.8, -0.3, 0.5))
    tube(0.15, 0.75, hand, way, dark, vertices=6)
    tube(0.09, 0.25, hand + way * 0.75, way, ROBOT_FACTORY_STEEL, vertices=6)
    cone(0.27, 0.8, hand + way * 0.98, way, "8FE6FF", sides=6, emission=2.5)
    tip = hand + way * 1.85
    star(0.28, tip, "FFE45A", depth=0.1, emission=2)
    for dx, dz, size in ((-0.3, 0.25, 0.09), (0.25, 0.3, 0.07), (-0.1, -0.3, 0.08), (0.3, -0.15, 0.06)):
        ball(size, tip + Vector((dx, 0, dz)), a, segments=5, emission=2)
    # A gas bottle on its back, a little jet under it.
    tube(0.3, 0.9, (0.45, 0.8, 0.35), (0, 0.15, 1), a, vertices=8)
    ball(0.3, (0.45, 0.94, 1.25), a, segments=8)
    tube(0.36, 0.3, (0, 0, -0.14), UP, dark, tip=0.52, vertices=8)
    disc(0.3, (0, 0, -0.14), a, height=0.12, towards=(0, 0, -1), sides=8, emission=2)
    box((0.3, 0.36, 0.45), (0.95, -0.15, 0.6), dark, bevel=0.12, segments=1, rotation=(0, math.radians(-25), 0))  # the other arm
    eyes(front, 0.98, 0.42, a, size=0.82)
    mouth(front, 0.44, 0.3)


def saw_crawler(c, a):
    # A big circular saw runs through its back from nose to tail; two little ones spin on its arms.
    legs = "6A78D0"
    front = crawler(c, legs, w=2.7, d=2.1, h=1.15, lift=0.3, legs=3)
    robot_factory_saw((0, 0.3, 1.45), 1.35, ROBOT_FACTORY_BLADE, a, teeth=14, thick=0.16)
    box((0.62, 1.7, 0.36), (0, 0.3, 1.5), a, bevel=0.12, segments=1)  # the slot the blade runs in
    box((2.76, 2.16, 0.2), (0, 0, 0.52), a, bevel=0.06, segments=1)  # a red stripe
    for side in (-1, 1):
        box((0.3, 0.95, 0.26), (side * 1.3, -1.3, 0.42), legs, bevel=0.1, segments=1, rotation=(0, 0, side * math.radians(-24)))
        robot_factory_saw((side * 1.55, -1.85, 0.44), 0.5, ROBOT_FACTORY_BLADE, a, axis=UP, teeth=8, thick=0.1)
    eyes(front, 1.02, 0.52, a, size=0.82, brow=a, tilt=-16)
    mouth(front, 0.5, 0.42, "grin")


def spike_mine(c, a):
    # A sea mine on two little feet: a ball of iron, red-hot spikes all round, a warning lamp on top.
    light = shade(c, 0.35)
    ball(1.2, (0, 0, 1.5), c, segments=12, roughness=0.35)
    front = -1.1
    feet(shade(c, -0.25), 0.5, size=(0.6, 0.8, 0.4))
    middle = Vector((0, 0, 1.5))
    for way in ((1, 0, 0.1), (-1, 0, 0.1), (0.72, 0, 0.75), (-0.72, 0, 0.75), (0.8, 0, -0.62), (-0.8, 0, -0.62), (0.6, 0.8, 0.3), (-0.6, 0.8, 0.3),
                (0, 1, -0.2), (0, 0.7, 0.8), (0.62, -0.6, 0.72), (-0.62, -0.6, 0.72), (0.75, -0.62, -0.5), (-0.75, -0.62, -0.5)):
        way = Vector(way).normalized()
        tube(0.32, 0.2, middle + way * 1.08, way, light, vertices=6)
        cone(0.25, 0.62, middle + way * 1.26, way, a, sides=6, emission=1.2)
    tube(0.42, 0.22, (0, 0, 2.62), UP, light, vertices=8)
    ball(0.3, (0, 0, 2.95), a, segments=8, emission=2.5)
    for x, z in ((-0.95, 1.95), (0.98, 1.0), (0.0, 0.42)):  # rivets
        ball(0.09, (x * 0.6, -math.sqrt(max(0.05, 1.44 - (x * 0.6) ** 2 - (z - 1.5) ** 2)) - 0.02, z), light, segments=6)
    eyes(front, 1.58, 0.45, a, size=0.86, brow=light, tilt=-22)
    mouth(front - 0.02, 0.98, 0.4, "fangs")


def guard_mech(c, a):
    # The factory's guard: a tall machine on two legs, in a peaked cap with a badge, behind a riot shield, a
    # stun baton in its other hand and a siren on its head.
    dark = shade(c, -0.4)
    for side in (-1, 1):
        box((0.62, 0.72, 0.9), (side * 0.52, 0, 0.62), a, bevel=0.16, segments=1)
    for side in (-1, 1):
        box((0.85, 1.05, 0.45), (side * 0.55, -0.2, 0.225), dark, bevel=0.2, segments=1)
    cube(2.2, 1.8, 2.0, 0.9, c, bevel=0.4, seg=2)
    front = -0.9
    box((1.25, 0.16, 0.5), (0, front - 0.02, 1.32), a, bevel=0.07, segments=1)  # a panel of lamps
    for index, colour in enumerate(("FF5A5A", ROBOT_FACTORY_HAZARD, "5AF08A")):
        slab((0.2, 0.1, 0.2), ((index - 1) * 0.36, front - 0.1, 1.32), colour, emission=1.5)
    for side in (-1, 1):
        ball(0.56, (side * 1.3, 0, 2.4), a, scale=(1, 1, 0.8), segments=8)
        box((0.45, 0.55, 0.95), (side * 1.45, -0.1, 1.7), dark, bevel=0.18, segments=1)
    # The shield.
    box((1.35, 0.22, 1.8), (-1.75, -0.78, 1.4), a, bevel=0.3, segments=1)
    box((1.0, 0.1, 1.45), (-1.75, -0.9, 1.4), c, bevel=0.2, segments=1)
    star(0.34, (-1.75, -0.98, 1.45), GOLD, depth=0.1)
    # The baton.
    way = Vector((0.2, -0.45, 1)).normalized()
    hand = Vector((1.55, -0.3, 1.2))
    ball(0.3, hand, a, segments=8)
    tube(0.11, 0.9, hand - way * 0.2, way, dark, vertices=6)
    tube(0.16, 0.7, hand + way * 0.7, way, ROBOT_FACTORY_HAZARD, vertices=6, emission=1.5)
    # The cap.
    helmet(dark, 2.86, 1.2, trim=a, squash=0.6)
    box((1.7, 0.75, 0.14), (0, -1.2, 2.84), dark, bevel=0.06, segments=1, rotation=(math.radians(10), 0, 0))
    star(0.26, (0, -1.02, 3.22), GOLD, depth=0.1, rotation=(math.radians(-25), 0, 0))
    tube(0.26, 0.14, (0, 0.1, 3.55), UP, a, vertices=8)
    ball(0.28, (0, 0.1, 3.8), "FF4A4A", segments=8, emission=2.5)
    eyes(front, 2.2, 0.48, "5AE0FF", size=0.9, brow=dark, tilt=-12)
    mouth(front, 1.72, 0.4, "flat")


def crusher_tank(c, a):
    # A bulldozer of a tank: caterpillar tracks, a great spiked roller out in front that flattens what it meets,
    # a cab on its back, two chimneys.
    hazard, steel = ROBOT_FACTORY_HAZARD, ROBOT_FACTORY_STEEL
    for side in (-1, 1):
        box((0.9, 3.6, 1.15), (side * 1.55, 0, 0.575), a, bevel=0.52, segments=2)
        for y in (-1.2, 0, 1.2):
            tube(0.34, 0.1, (side * 2.0, y, 0.575), (side, 0, 0), hazard, vertices=8)
    cube(2.5, 3.0, 2.2, 0.55, c, bevel=0.45, seg=3)
    front = -1.5
    cube(1.9, 1.4, 0.8, 2.6, shade(c, -0.22), bevel=0.25, seg=2, y=0.6)  # the cab
    slab((1.3, 0.1, 0.36), (0, -0.12, 3.05), "7FE0FF", emission=0.8)  # its window
    ball(0.26, (0, 0.6, 3.55), hazard, segments=8, emission=2.5)  # a warning lamp
    for side in (-1, 1):
        robot_factory_stack((side * 0.85, 1.25, 2.7), 0.28, 1.3, hazard, bands=4, smoke=side > 0)
        box((0.34, 1.5, 0.38), (side * 1.05, -2.0, 0.85), hazard, bevel=0.1, segments=1, rotation=(math.radians(-14), 0, 0))  # the roller's arms
        tube(0.36, 0.14, (side * 1.72, -2.45, 0.62), (side, 0, 0), a, vertices=8)
    # The roller.
    tube(0.62, 3.4, (-1.7, -2.45, 0.62), (1, 0, 0), steel, vertices=12, roughness=0.35)
    for row in range(4):
        for index in range(6):
            angle = math.radians(index * 60 + (30 if row % 2 else 0))
            way = (0, math.sin(angle), math.cos(angle))
            cone(0.2, 0.42, (-1.27 + row * 0.85, -2.45 + way[1] * 0.58, 0.62 + way[2] * 0.58), way, hazard, sides=5)
    # Hazard stripes on its nose.
    for index in range(4):
        slab((0.3, 0.08, 0.34), (-0.9 + index * 0.6, front - 0.02, 0.9), hazard, rotation=(0, math.radians(30), 0))
    eyes(front, 2.05, 0.62, hazard, size=1.08, brow=a, tilt=-26)
    mouth(front, 1.3, 0.9, "fangs")


def factory_overlord(c, a):
    # The factory itself, walking: a furnace in its chest, cog wheels for shoulders, chimneys on its back, the
    # horns of the factory gate and a gold crown.
    dark, light = shade(c, -0.3), shade(c, 0.3)
    front = biped(c, dark, w=3.0, d=2.5, h=2.8, legs=0.5, arm=False, bevel=0.45, foot=(1.1, 1.3, 0.6), roughness=0.4)
    for side in (-1, 1):
        robot_factory_stack((side * 0.85, 0.85, 3.2), 0.42, 1.45, a, bands=4, smoke=side > 0)
        robot_factory_cog((side * 1.75, -0.3, 2.75), 0.62, GOLD, teeth=8, thick=0.5, tooth=0.3, roughness=0.3)
        tube(0.26, 0.56, (side * 1.75, -0.6, 2.75), (0, 1, 0), a, vertices=8, emission=1.5)
        box((0.7, 0.85, 1.25), (side * 1.85, -0.1, 1.75), light, bevel=0.25, segments=2)
        box((0.9, 1.0, 0.6), (side * 1.9, -0.15, 0.95), dark, bevel=0.2, segments=1)  # a clamp for a hand
        for dx in (-0.26, 0.26):
            cone(0.2, 0.55, (side * 1.9 + dx, -0.3, 0.7), (dx * 0.6, -0.35, -1), GOLD, sides=5)
        cone(0.42, 1.0, (side * 1.2, 0, 3.15), (side * 1, 0, 0.55), "FFF3D6")  # horns
        cone(0.28, 0.85, (side * 1.98, 0, 3.55), (-side * 0.15, 0, 1), "FFF3D6", sides=6)
    # The furnace door: a gold ring, the glow, two bars.
    tube(0.62, 0.16, (0, front + 0.02, 1.08), (0, -1, 0), GOLD, vertices=12, roughness=0.3)
    tube(0.46, 0.1, (0, front - 0.14, 1.08), (0, -1, 0), a, vertices=10, emission=2.5)
    for dx in (-0.18, 0.18):
        slab((0.1, 0.12, 0.84), (dx, front - 0.26, 1.08), dark)
    box((3.1, 2.6, 0.3), (0, 0, 0.72), light, bevel=0.1, segments=1)
    crown(3.3, radius=0.8, colour=GOLD, gems=a, points=5, size=1.2)
    eyes(front, 2.4, 0.68, a, size=1.1, brow=light, tilt=-26, blush=False)
    mouth(front, 1.9, 0.8, "grin", teeth=a)


WORLDS["Robot Factory"] = [
    ("Scrap Bot", scrap_bot, "E08A4E", "8E4A34", "walker"),
    ("Welder Drone", welder_drone, "4C96F0", "FF7A28", "floater"),
    ("Saw Crawler", saw_crawler, "A9B8F4", "E8463A", "walker"),
    ("Spike Mine", spike_mine, "464EA8", "FF4632", "walker"),
    ("Guard Mech", guard_mech, "3F74DC", "F0F5FF", "walker"),
    ("Crusher Tank", crusher_tank, "E4502A", "3A3F7C", "boss"),
    ("Factory Overlord", factory_overlord, "343C8A", "50FFAA", "boss"),
]
BACKDROPS["Robot Factory"] = "E8CD8C"
