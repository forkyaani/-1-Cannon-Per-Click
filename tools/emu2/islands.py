"""Boots the real server (real Plots, Marketplace and Islands) and measures the world islands, which the
position-only emulator in tools/emu cannot:  GAME_ROOT=<tree> python3 islands.py

  * twelve islands, each about 120 parts with its two egg stands, every part on its own island
  * the world's two coin eggs stand on the island (on the marketplace's stands, under Marketplace.Eggs) and
    the marketplace keeps the rest
  * the stall, the portal, the eggs, the reserved spots and the boss statue face the way the code says
  * the arrival, the portal, the eggs, the stall and the two reserved spots are clear of everything else
  * the compact centre: players arrive in the middle, and every interactable (the two eggs, the stall, the
    portal, the mastery spot, and the two halves of the enchant spot, for the table and the fusion machine)
    is within 20 studs of the arrival pad and at least 9 studs from the others; statues and scenery are out
    at the rim
  * the enchanting table and the Fusion Machine stand on The Sun's island, each on its half of the enchant
    spot, and open ENCHANT and FUSE; the marketplace has no Fusion Machine any more
  * a player travels there, hatches at an island egg stand, and takes the portal home
"""
import math
import sys

from boot import boot, data_of, module, remote
from roblox_mock import Inst, Vector3
from luau_vm import LuaTable

failures = []


def check(ok, what):
    if not ok:
        print("  FAILED: " + what)
        failures.append(what)


def flat(a, b):
    return math.hypot(a.x - b.x, a.z - b.z)


def parts(inst):
    return [d for d in inst.descendants() if d.cls == "Part"]


def reach(part):
    """The radius of a part's footprint on the ground: half the diagonal of its box seen from above, so a tall
    post counts as thin and a pillar lying on its side (Build.pillar) as its disc."""
    size, frame = part.props["Size"], part.props["CFrame"]
    total = 0.0
    for length, axis in ((size.x, frame.f_RightVector()), (size.y, frame.f_UpVector()), (size.z, frame.f_LookVector())):
        total += length * length * max(0.0, 1 - axis.y * axis.y)
    return math.sqrt(total) / 2


MAX_WALK = 20.0  # no interactable is further than this from the arrival pad
MIN_APART = 9.0  # and none is closer than this to another
HALF_SPOT = 5.0  # two things on one spot stand this far left and right of its middle (Islands.luau, SPOTS)
SCENERY = {"Plinth", "Fountain", "LampPost", "Lamp", "SignOrb", "Trunk", "Leaves", "Rock", "Spire", "SpireShard",
           "OrbBase", "Orb", "Machine", "MachineLight"}
RIM_FROM = 30.0  # scenery and statues stand at least this far from the arrival pad


world = boot(studio=True)
vm = world.vm
Layout = module(world, "src/shared/Layout.luau")
Islands = module(world, "src/server/Islands.luau")
Config = module(world, "src/shared/Config.luau")
RADIUS = Layout.d["ISLAND_RADIUS"]
worlds = Config.d["Worlds"]
count = worlds.length()

root = world.workspace.find("Islands")
check(root is not None and len(root.children) == count, "workspace.Islands holds one folder per world")
eggs_folder = world.workspace.find("Marketplace").find("Eggs")
egg_by_id = Config.d["EggById"]
market = Layout.d["MARKET_CENTER"]

totals = []
for index in range(1, count + 1):
    middle = vm.call(Layout.d["islandCFrame"], [float(index)])[0].p
    folder = root.find("Island_%d" % index)
    check(folder is not None, "island %d exists" % index)
    own = parts(folder)
    stands = []
    for stand in eggs_folder.children:
        egg = egg_by_id.d[stand.props["Name"][len("Egg_"):]]
        if egg.d.get("world") == index and not egg.d.get("event"):
            stands.append(stand)
    check(len(stands) == 2, "island %d has two egg stands (%d)" % (index, len(stands)))
    total = len(own) + sum(len(parts(stand)) for stand in stands)
    totals.append(total)

    for part in own:
        check(flat(part.props["CFrame"].p, middle) <= RADIUS + 1.5, "island %d: %s is on the island" % (index, part.props["Name"]))

    # What must stay clear, as circles on the ground: (name, centre, radius).
    spawn = vm.call(Layout.d["islandSpawn"], [float(index)])[0]
    check(spawn.f_LookVector().z < -0.99, "island %d: arrivals look north" % index)
    check(flat(spawn.p, middle) < 0.01, "island %d: players arrive in the middle" % index)
    pad = folder.find("ArrivalPad")
    check(pad is not None and flat(pad.props["CFrame"].p, spawn.p) < 0.01, "island %d: the arrival pad is where players arrive" % index)
    keep = [("arrival", spawn.p, 7.0)]
    usable = []  # (name, where its prompt is)
    for name in ("mastery", "enchant"):
        frame = vm.call(Islands.d["spot"], [float(index), name])[0]
        to_middle = Vector3(middle.x - frame.p.x, 0, middle.z - frame.p.z).f_Unit()
        check(frame.f_LookVector().m_Dot(to_middle) > 0.99, "island %d: the %s spot faces the middle" % (index, name))
        check(abs(frame.p.y - middle.y) < 0.01, "island %d: the %s spot is at floor level" % (index, name))
        keep.append((name + " spot", frame.p, 6 * math.sqrt(2)))
        plate = folder.find("Spot_" + name)
        check(plate is not None and flat(plate.props["CFrame"].p, frame.p) < 0.01 and plate.attrs.get("Spot") == name, "island %d: the %s spot is marked" % (index, name))
        if name == "enchant":
            # Two things stand on it: the enchanting table and the fusion machine, left and right of its middle.
            side = frame.f_RightVector()
            for label, sign in (("enchanting table", -1), ("fusion machine", 1)):
                usable.append((label, Vector3(frame.p.x + side.x * HALF_SPOT * sign, frame.p.y, frame.p.z + side.z * HALF_SPOT * sign)))
        else:
            usable.append((name + " spot", frame.p))
    for stand in stands:
        shell = stand.find("Egg")
        check(flat(shell.props["CFrame"].p, middle) < RADIUS - 10, "island %d: %s stands on the island" % (index, stand.props["Name"]))
        prompts = [c for c in shell.children if c.cls == "ProximityPrompt"]
        check(len(prompts) == 3 and all(p.attrs.get("EggId") for p in prompts), "island %d: %s has its three prompts" % (index, stand.props["Name"]))
        check(sum(1 for p in prompts if str(p.attrs.get("Loot", "")).startswith("egg:")) == 1, "island %d: %s has its What's inside? prompt" % (index, stand.props["Name"]))
        keep.append((stand.props["Name"], shell.props["CFrame"].p, 3.5))
        usable.append((stand.props["Name"], shell.props["CFrame"].p))
        pedestal = stand.find("Pedestal").props["CFrame"]
        to_middle = Vector3(middle.x - pedestal.p.x, 0, middle.z - pedestal.p.z).f_Unit()
        # A pillar lies on its side: the stand's own -Z is the pedestal's.
        check(pedestal.f_LookVector().m_Dot(to_middle) > 0.99, "island %d: %s faces the middle" % (index, stand.props["Name"]))
    counter = folder.find("Counter")
    look = counter.props["CFrame"].f_LookVector()
    to_middle = Vector3(middle.x - counter.props["CFrame"].p.x, 0, middle.z - counter.props["CFrame"].p.z).f_Unit()
    check(look.m_Dot(to_middle) > 0.99, "island %d: the stall faces the middle" % index)
    shop = next((c for c in counter.children if c.cls == "ProximityPrompt"), None)
    check(shop is not None and shop.attrs.get("Window") == "ISLAND SHOP", "island %d: the stall opens ISLAND SHOP" % index)
    keep.append(("stall", counter.props["CFrame"].p, 6.5))
    usable.append(("stall", counter.props["CFrame"].p))
    gate = folder.find("Portal")
    check(any(c.cls == "ProximityPrompt" for c in gate.children), "island %d: the portal has its prompt" % index)
    keep.append(("portal", gate.props["CFrame"].p, 5.0))
    usable.append(("portal", gate.props["CFrame"].p))
    to_middle = Vector3(middle.x - gate.props["CFrame"].p.x, 0, middle.z - gate.props["CFrame"].p.z).f_Unit()
    check(gate.props["CFrame"].f_LookVector().m_Dot(to_middle) > 0.99, "island %d: the portal faces the middle" % index)

    # The compact centre: everything to use is a few steps from the arrival pad, and no two share a place.
    if index == 1:
        print("  from the arrival pad: " + ", ".join("%s %.1f" % (name, flat(point, spawn.p)) for name, point in usable))
        print("  nearest neighbour:    " + ", ".join("%s %.1f" % (name, min(flat(point, other) for label, other in usable if label != name)) for name, point in usable))
    check(len(usable) == 7, "island %d: seven interactables (%d)" % (index, len(usable)))
    for i, (name, point) in enumerate(usable):
        walk = flat(point, spawn.p)
        check(walk <= MAX_WALK, "island %d: the %s is within %d studs of the arrival pad (%.1f)" % (index, name, MAX_WALK, walk))
        check(walk >= 12, "island %d: the %s leaves the arrival pad room (%.1f)" % (index, name, walk))
        for other, point_b in usable[i + 1:]:
            apart = flat(point, point_b)
            check(apart >= MIN_APART, "island %d: the %s and the %s are %d studs apart (%.1f)" % (index, name, other, MIN_APART, apart))
    # Statues and scenery stand out at the rim, away from the ring.
    for part in parts(folder):
        if part.props["Name"] in SCENERY or (part.parent is not None and part.parent.props.get("Name") == "Statue"):
            check(flat(part.props["CFrame"].p, spawn.p) >= RIM_FROM, "island %d: %s stands at the rim (%.1f)" % (index, part.props["Name"], flat(part.props["CFrame"].p, spawn.p)))

    # The big things that belong to each of those circles, and flat things that are walked over.
    belongs = {
        "arrival": {"ArrivalPad"},
        "mastery spot": {"Spot_mastery", "ShrineBase", "ShrineStep", "ShrinePillar", "ShrineFlame", "ShrineAltar",
                         "ShrineCrystal"},
        "enchant spot": {"Spot_enchant", "EnchantBase", "EnchantTable", "EnchantBook", "EnchantOrb", "EnchantCandle",
                         "FusionBase", "FusionCore", "FusionCap", "FusionPod", "FusionConsole", "FusionTop"},
        "stall": {"Counter", "StallPost", "Awning", "StallSign", "StallShell", "StallChest"},
        "portal": {"Portal", "PortalPillar", "PortalBeam"},
    }
    floor = {"Ground", "Plaza", "Rim"}
    for name, centre, radius in keep:
        for part in own:
            part_name = part.props["Name"]
            if part_name in floor or part_name in belongs.get(name, ()):
                continue
            gap = flat(part.props["CFrame"].p, centre) - reach(part) - radius
            check(gap >= 0, "island %d: %s is clear of the %s (%.1f)" % (index, part_name, name, gap))
    # And those circles are clear of each other.
    for i, (a, centre_a, radius_a) in enumerate(keep):
        for b, centre_b, radius_b in keep[i + 1:]:
            check(flat(centre_a, centre_b) >= radius_a + radius_b, "island %d: the %s and the %s are apart" % (index, a, b))

    # The boss stands at the north rim, behind the eggs, and looks south, at the players arriving.
    north = Vector3(middle.x, middle.y, middle.z - 44)
    statue = next((c for c in folder.children if c.cls == "Model" and c.props["Name"] == "Statue" and flat(c.find("Body").props["CFrame"].p, north) < 2), None)
    check(statue is not None, "island %d: the boss stands at the north rim" % index)
    if statue is not None:
        check(statue.find("Body").props["CFrame"].f_LookVector().z > 0.99, "island %d: the boss looks south" % index)
        low = min(p.props["CFrame"].p.y - p.props["Size"].y / 2 for p in parts(statue))
        check(low >= middle.y + 1.9, "island %d: the boss stands on its plinth (%.2f)" % (index, low - middle.y))

# The Sun's island: the enchanting table and the Fusion Machine share the enchant spot, each on its own half,
# and the marketplace no longer has the machine.
sun = root.find("Island_%d" % int(Config.d["EnchantIsland"]))
sun_spot = vm.call(Islands.d["spot"], [float(Config.d["EnchantIsland"]), "enchant"])[0]
sun_side = sun_spot.f_RightVector()
check(Config.d["EnchantIsland"] == 5 and Config.d["FuseIsland"] == 5, "enchanting and fusing are on The Sun's island")
for model_name, sign, window_name in (("EnchantingTable", -1, "ENCHANT"), ("FusionMachine", 1, "FUSE")):
    model = sun.find(model_name)
    check(model is not None, "The Sun's island has the %s" % model_name)
    if model is None:
        continue
    centre = Vector3(sun_spot.p.x + sun_side.x * HALF_SPOT * sign, sun_spot.p.y, sun_spot.p.z + sun_side.z * HALF_SPOT * sign)
    prompts = [d for d in model.descendants() if d.cls == "ProximityPrompt"]
    check(len(prompts) == 1 and prompts[0].attrs.get("Window") == window_name, "the %s opens %s" % (model_name, window_name))
    if prompts:
        check(flat(prompts[0].parent.props["CFrame"].p, centre) <= 3, "the %s's prompt is on its half of the spot" % model_name)
    for part in parts(model):
        far = flat(part.props["CFrame"].p, centre) + reach(part)
        check(far <= 4.6, "%s: %s stays on its half of the spot (%.1f)" % (model_name, part.props["Name"], far))
    check(len(parts(model)) <= 10, "the %s is a few parts (%d)" % (model_name, len(parts(model))))
for index in range(1, count + 1):
    if index != int(Config.d["EnchantIsland"]):
        folder = root.find("Island_%d" % index)
        check(folder.find("EnchantingTable") is None and folder.find("FusionMachine") is None, "island %d has no table and no machine" % index)
check(not any(d.props.get("Name", "").startswith("Fusion") for d in world.workspace.find("Marketplace").descendants()), "the marketplace no longer has the Fusion Machine")

print("  parts per island, egg stands included: %d to %d" % (min(totals), max(totals)))
check(100 <= min(totals) and max(totals) <= 140, "about 120 parts per island")

# The marketplace keeps the eggs that belong to no world.
for stand in eggs_folder.children:
    egg = egg_by_id.d[stand.props["Name"][len("Egg_"):]]
    if not egg.d.get("world"):
        position = stand.find("Egg").props["CFrame"].p
        check(flat(position, market) < 80 and not math.isnan(position.x), "%s stays in the marketplace" % stand.props["Name"])
check(any(not egg_by_id.d[s.props["Name"][4:]].d.get("world") for s in eggs_folder.children), "the marketplace still has eggs")
check(len(eggs_folder.children) == sum(1 for s in eggs_folder.children if egg_by_id.d.get(s.props["Name"][4:]) is not None), "every stand is an egg's")

# Bases are private: there is no street, every base has its own islands teleporter (the core opens WORLDS for
# the base's owner), and no base is anywhere near an island.
plots_root = world.workspace.find("Plots")
check(plots_root.find("Street") is None, "there is no street any more")
APART = float(Layout.d["PLOT_APART"])
check(APART >= 1500, "Layout.PLOT_APART is at least 1,500")
plot_count = int(Layout.d["PLOT_COUNT"])
plot_origins = [vm.call(Layout.d["plotCFrame"], [float(slot)])[0].p for slot in range(1, plot_count + 1)]
for slot in range(1, plot_count + 1):
    base = plots_root.find("Plot_%d" % slot)
    teleporters = base.find("Teleporters")
    beam = teleporters.find("WorldsPortal") if teleporters is not None else None
    check(beam is not None and any(c.cls == "ProximityPrompt" and c.attrs.get("Teleporter") == "worlds" and c.attrs.get("Slot") == slot for c in beam.children),
          "base %d has its islands teleporter" % slot)
    if beam is not None:
        check(flat(beam.props["CFrame"].p, teleporters.find("MarketPortal").props["CFrame"].p) > 16, "base %d: clear of the marketplace teleporter" % slot)
    for index in range(1, count + 1):
        middle = vm.call(Layout.d["islandCFrame"], [float(index)])[0].p
        # Edge to edge, generously: the base's far corner is under 200 studs from its origin.
        check(flat(plot_origins[slot - 1], middle) - 200 - RADIUS >= APART, "base %d is far from island %d" % (slot, index))
    check(flat(plot_origins[slot - 1], market) - 200 - 110 >= APART, "base %d is far from the marketplace" % slot)
for a in range(plot_count):
    for b in range(a + 1, plot_count):
        check(flat(plot_origins[a], plot_origins[b]) - 400 >= APART, "bases %d and %d are more than %d studs apart" % (a + 1, b + 1, APART))

# A player goes there, hatches, and comes home.
player = world.add_player(101, "Rookie")
character = Inst(world, "Model", "Rookie")
body = Inst(world, "Part", "HumanoidRootPart")
body.set_parent(character)
Inst(world, "Humanoid", "Humanoid").set_parent(character)
character.props["PrimaryPart"] = body
character.set_parent(world.workspace)
player.props["Character"] = character
player.signal("CharacterAdded").fire(character)
world.advance(1)
data = data_of(world, player)


def act(name, argument=None):
    world.advance(0.3)
    remote(world, "Action").signal("OnServerEvent").fire(player, name, argument)
    world.advance(0.2)


act("goIsland", 2.0)
check(player.attrs.get("Place") == "plot", "the Moon's island is locked for a new player")
act("goIsland", 1.0)
check(player.attrs.get("Place") == "island" and player.attrs.get("Island") == 1, "goIsland(1)")
check(player.attrs.get("InMarket") is True, "InMarket is true on the island, for the HUD and the egg signs")
remote(world, "Debug").signal("OnServerEvent").fire(player, "coins", 1e9)
first = Config.d["Eggs"].d[1.0] if 1.0 in Config.d["Eggs"].d else Config.d["Eggs"].array[0]
stand = eggs_folder.find("Egg_" + first.d["id"])
hatch = next(c for c in stand.find("Egg").children if c.cls == "ProximityPrompt" and c.props.get("ActionText") == "Hatch")
before = data.d["totalHatches"]
world.advance(0.3)
hatch.signal("Triggered").fire(player)
world.advance(0.3)
check(data.d["totalHatches"] == before + 1, "an island egg stand hatches (the core wired its prompt)")
act("islandBuy", LuaTable({"island": 1.0, "kind": "chest"}))
check("bosschest" in player.attrs.get("Meta_items", ""), "the island shop sells its Boss Chest")
home = next(c for c in root.find("Island_1").find("Portal").children if c.cls == "ProximityPrompt")
world.advance(0.3)
home.signal("Triggered").fire(player)
world.advance(0.3)
check(player.attrs.get("Place") == "plot" and player.attrs.get("InMarket") is False, "the island's portal leads home")

bad = [line for line in vm.output if line.startswith(("WARN", "THREAD ERROR", "SIMULATOR ERROR"))]
for line in bad:
    print("  ", line)
check(not bad, "no warnings or errors")
print("FAILED" if failures else "PASSED", "islands.py")
sys.exit(1 if failures else 0)
