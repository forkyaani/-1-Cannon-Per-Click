"""Boots the real server (real Plots and Marketplace), lets one player join, build, upgrade, sell, travel and
leave, and checks what the client is promised in docs/DEFENSE_SPEC.md section 6. Then a second player joins:
their bases are far apart, one invites the other, the visit is played with real positions (who is sent whose
field, where the guest lands, what a guest cannot do), the plot is paused and resumed, and a character that
falls under the map is put back on its base:  GAME_ROOT=<tree> python3 play.py"""
import json
import math
import sys

from boot import boot, data_of, module, remote
from roblox_mock import CFrame, Inst, Vector3
from luau_vm import tostring

failures = []


def check(ok, what):
    print(("  ok: " if ok else "  FAILED: ") + what)
    if not ok:
        failures.append(what)


def problems(world):
    return [line for line in world.vm.output if line.startswith(("WARN", "THREAD ERROR", "SIMULATOR ERROR"))]


def join(user_id, name):
    """A player with a character, as the game finds them a moment after they joined."""
    who = world.add_player(user_id, name)
    model = Inst(world, "Model", name)
    body = Inst(world, "Part", "HumanoidRootPart")
    body.set_parent(model)
    Inst(world, "Humanoid", "Humanoid").set_parent(model)
    model.props["PrimaryPart"] = body
    model.set_parent(world.workspace)
    who.props["Character"] = model
    who.signal("CharacterAdded").fire(model)
    world.advance(1)
    return who, body


world = boot(studio=True)
player, root = join(101, "Rookie")

data = data_of(world, player)
slot = player.attrs.get("Slot")
plots = world.workspace.find("Plots")
check(plots is not None, "workspace.Plots exists")
plot = plots.find("Plot_%d" % slot)
check(plot is not None and plot.attrs.get("Owner") == 101, "the player's plot is claimed (Owner attribute)")
pads, towers = plot.find("Pads"), plot.find("Towers")
check(len(pads.children) == 16, "16 pads")
pad1 = pads.find("Pad_1")
check(pad1.attrs.get("Owned") is True and pads.find("Pad_2").attrs.get("Owned") is False, "only the starter pad is owned")
prompt = next((c for c in pad1.descendants() if c.cls == "ProximityPrompt"), None)
check(prompt is not None and prompt.attrs.get("Pad") == 1 and prompt.attrs.get("Slot") == slot, "a pad's prompt carries Pad and Slot")
tower = towers.find("Tower_1")
check(tower is not None and tower.attrs.get("Kind") == "cannon" and tower.attrs.get("Level") == 1, "the starter cannon stands on pad 1")
check(tower.props.get("PrimaryPart") is not None, "a tower has a PrimaryPart")
names = {d.props["Name"] for d in tower.descendants()}
check("Turret" in names and "Muzzle" in names, "a tower has a Turret and a Muzzle")
check(plot.find("Gate") is not None and plot.find("Portal") is not None, "Gate and Portal")


def act(name, argument=None, who=None):
    world.advance(0.3)
    remote(world, "Action").signal("OnServerEvent").fire(who or player, name, argument)
    world.advance(0.2)


def table(**fields):
    from luau_vm import LuaTable
    return LuaTable({key: float(value) if isinstance(value, int) else value for key, value in fields.items()})


# In Studio every pass is owned, and one gives the Huge Tycoon, which upgrades towers by itself: switched off
# here so the tower levels below are the ones this script buys.
act("toggleTycoon")
remote(world, "Debug").signal("OnServerEvent").fire(player, "coins", 1e12)
act("buyPad", 2.0)
check(pads.find("Pad_2").attrs.get("Owned") is True, "buyPad: the pad shows as owned")
act("buildTower", table(pad=2, kind="cannon"))
built = towers.find("Tower_2")
check(built is not None and built.attrs.get("Kind") == "cannon", "buildTower: the model appears")
act("upgradeTower", table(pad=2, levels=10))
built = towers.find("Tower_2")
check(built is not None and built.attrs.get("Level") == 11, "upgradeTower: the model's Level follows (%s)" % (built and built.attrs.get("Level")))
meta = json.loads(player.attrs["Meta"])
check(sorted(meta["pads"]) == [1, 2] and meta["towers"]["2"]["level"] == 11 and meta["padPrice"] > 0, "Meta has pads, towers and padPrice")
act("sellTower", 2.0)
check(towers.find("Tower_2") is None, "sellTower: the model is gone")

world.advance(60)
fields = [entry for entry in world.remote_log if entry[1] == "Field"]
check(len(fields) > 100, "the Field remote is fired (%d messages in a minute)" % len(fields))
check(any(len(entry[2]) >= 6 and entry[2][5].length() >= 4 for entry in fields), "with monsters in them")
check(data.d["totalKills"] > 0, "towers kill monsters (%s kills, level %s)" % (tostring(data.d["totalKills"]), tostring(data.d["wave"])))

act("goMarket")
check(player.attrs.get("InMarket") is True, "goMarket")
world.advance(5)
act("goHome")
check(player.attrs.get("InMarket") is False, "goHome")
remote(world, "Debug").signal("OnServerEvent").fire(player, "wave", 51.0)
world.advance(5)
check(player.attrs.get("Wave") == 51, "jumping to world 2 (Plots.setWorld)")

# ---------------------------------------------------------------------------------------------------
# Private bases, a visit by invitation, pause, and the safety net under the map
# ---------------------------------------------------------------------------------------------------
Layout = module(world, "src/shared/Layout.luau")
vm = world.vm


def flat(a, b):
    return math.hypot(a.x - b.x, a.z - b.z)


def spawn_of(a_slot):
    return vm.call(Layout.d["plotSpawn"], [float(a_slot)])[0].p


def trigger(prompt, who):
    world.advance(0.3)
    prompt.signal("Triggered").fire(who)
    world.advance(0.2)


def fields_to(who, a_slot, seconds):
    """The Field messages sent to `who` about the plot `a_slot` over the next `seconds`."""
    world.remote_log[:] = [entry for entry in world.remote_log if entry[1] != "Field"]
    world.advance(seconds)
    return [entry[2] for entry in world.remote_log
            if entry[1] == "Field" and len(entry[2]) >= 6 and entry[2][0] is who and entry[2][1] == a_slot and entry[2][2] > 0]


def visit_view(who):
    return json.loads(who.attrs["Meta_visit"])


friend, friend_root = join(202, "Friend")
friend_slot = friend.attrs.get("Slot")
friend_plot = plots.find("Plot_%d" % friend_slot)
check(friend_slot != slot and friend_plot.attrs.get("Owner") == 202, "a second player gets a base of their own")
check(plots.find("Street") is None and plots.find("Lobby") is not None, "no street: the bases and a lobby")
origins = [vm.call(Layout.d["plotCFrame"], [float(index)])[0].p for index in range(1, int(Layout.d["PLOT_COUNT"]) + 1)]
closest = min(flat(a, b) for i, a in enumerate(origins) for b in origins[i + 1:])
check(closest - 400 >= 1500, "no two bases are within 1,500 studs (the nearest two are %d apart)" % closest)
check(flat(root.props["CFrame"].p, spawn_of(slot)) < 1 and flat(friend_root.props["CFrame"].p, spawn_of(friend_slot)) < 1, "each arrives on their own base")
check(flat(root.props["CFrame"].p, friend_root.props["CFrame"].p) >= 1500, "and they are out of each other's sight")
check(not fields_to(friend, slot, 3) and len(fields_to(friend, friend_slot, 3)) > 5 and len(fields_to(player, slot, 3)) > 5,
      "each is sent their own field and not the other's")

# The base's own teleporters.
teleporters = plot.find("Teleporters")
worlds_prompt = next(c for c in teleporters.find("WorldsPortal").children if c.cls == "ProximityPrompt")
market_prompt = next(c for c in teleporters.find("MarketPortal").children if c.cls == "ProximityPrompt")
here = spawn_of(slot)
for name in ("WorldsPortal", "MarketPortal"):
    check(flat(teleporters.find(name).props["CFrame"].p, here) <= 15, "%s is within 15 studs of the arrival" % name)
world.remote_log[:] = []
trigger(worlds_prompt, player)
check(any(entry[1] == "Feature" and entry[2][0] is player and entry[2][1:3] == ["window", "WORLDS"] for entry in world.remote_log),
      "the islands teleporter opens the owner's WORLDS window")
trigger(market_prompt, player)
check(player.attrs.get("Place") == "market", "the marketplace teleporter takes the owner to the marketplace")
act("goHome")

# Nobody walks in; an invitation, and the visit.
act("visitJoin", 101.0, friend)
check(friend.attrs.get("Place") == "plot", "no visit without an invitation")
act("visitInvite", 202.0)
check(len(visit_view(friend)["invites"]) == 1 and visit_view(friend)["invites"][0]["id"] == 101, "the invitation arrives")
act("visitJoin", 101.0, friend)
check(friend.attrs.get("Place") == "visit" and friend.attrs.get("Visiting") == slot and friend.attrs.get("InMarket") is True,
      "JOIN: Place = visit, Visiting = the host's slot, InMarket true")
landed = friend_root.props["CFrame"].p
check(flat(landed, here) <= 8 and abs(landed.y - here.y) < 1, "the guest lands near the host's arrival spot (%.1f studs from it)" % flat(landed, here))
check(-55 < landed.x - origins[int(slot) - 1].x < 55 and 0 < landed.z - origins[int(slot) - 1].z < 14, "on the plaza behind the gate")
world.advance(1)
check([g["id"] for g in visit_view(player)["guests"]] == [202] and visit_view(friend)["host"]["id"] == 101, "both windows know of the visit")
seen = fields_to(friend, slot, 5)
check(len(seen) > 10, "the guest is sent the host's field (%d messages in 5 s)" % len(seen))
check(len(fields_to(friend, friend_slot, 3)) > 5, "and still their own")
friend_kills = data_of(world, friend).d["totalKills"]
world.advance(40)
check(data_of(world, friend).d["totalKills"] > friend_kills, "the guest's own base keeps fighting")
# Standing at the far end of the host's plot they are still sent its field: the whole plot is in reach.
friend_root.props["CFrame"] = CFrame(Vector3(origins[int(slot) - 1].x + 50, 3, origins[int(slot) - 1].z + 148))
check(len(fields_to(friend, slot, 3)) > 5, "the field reaches a guest anywhere on the base")

# A guest has no rights there.
remote(world, "Debug").signal("OnServerEvent").fire(friend, "coins", 1e12)
host_tower = towers.find("Tower_1").attrs.get("Level")
host_pads = [pad.attrs.get("Owned") for pad in pads.children]
host_meta = {key: json.loads(player.attrs["Meta"])[key] for key in ("pads", "towers")}
act("upgradeTower", table(pad=1, levels=10), friend)
act("buyPad", 3.0, friend)
act("buildTower", table(pad=3, kind="cannon"), friend)
check(towers.find("Tower_1").attrs.get("Level") == host_tower and towers.find("Tower_3") is None
      and [pad.attrs.get("Owned") for pad in pads.children] == host_pads, "a guest's pad actions do nothing to the host's base")
check({key: json.loads(player.attrs["Meta"])[key] for key in ("pads", "towers")} == host_meta, "nor to the host's save")
check(friend_plot.find("Towers").find("Tower_3") is not None, "they land on the guest's own base")
trigger(market_prompt, friend)
world.remote_log[:] = []
trigger(worlds_prompt, friend)
check(friend.attrs.get("Place") == "visit" and not any(entry[1] == "Feature" and entry[2][1] == "window" for entry in world.remote_log),
      "a guest cannot use the host's teleporters")
pad_prompt = next(c for c in pad1.descendants() if c.cls == "ProximityPrompt")
trigger(pad_prompt, friend)
check(towers.find("Tower_1").attrs.get("Level") == host_tower, "nor the host's pad prompts")
act("visitKick", 101.0, friend)
check(player.attrs.get("Place") == "plot", "a guest cannot send the host anywhere")

# Home: the guest's own BASE button, then the host's SEND HOME.
act("goHome", None, friend)
check(friend.attrs.get("Place") == "plot" and friend.attrs.get("Visiting") == 0 and friend.attrs.get("InMarket") is False, "BASE takes the guest home")
check(flat(friend_root.props["CFrame"].p, spawn_of(friend_slot)) < 1, "to their own arrival spot")
check(not fields_to(friend, slot, 3), "and the host's field stops coming")
world.advance(4)
act("visitInvite", 202.0)
act("visitJoin", 101.0, friend)
check(friend.attrs.get("Place") == "visit", "a second visit")
act("visitKick", 202.0)
check(friend.attrs.get("Place") == "plot" and flat(friend_root.props["CFrame"].p, spawn_of(friend_slot)) < 1, "the host's SEND HOME takes the guest home")

# Pause: the plot stands still and its field keeps coming.
check(player.attrs.get("Paused") is False, "nobody is paused until they ask")
act("prevWave")
world.advance(6)
act("setPaused", True)
check(player.attrs.get("Paused") is True, "setPaused(true): the Paused attribute")
kills_before, coins_before = data.d["totalKills"], player.attrs.get("Coins")
paused_fields = fields_to(player, slot, 20)
shapes = {tuple(message[5].array()) for message in paused_fields}
check(len(paused_fields) > 50, "the field keeps being sent while paused (%d messages in 20 s)" % len(paused_fields))
check(len(shapes) == 1 and len(next(iter(shapes))) >= 4, "and every message is the same: the monsters stand still")
check(data.d["totalKills"] == kills_before and player.attrs.get("Coins") == coins_before, "no kills and no coins while paused")
level_before = towers.find("Tower_1").attrs.get("Level")
act("upgradeTower", table(pad=1, levels=1))
check(towers.find("Tower_1").attrs.get("Level") == level_before + 1, "upgrading works while paused")
act("setPaused", False)
check(player.attrs.get("Paused") is False, "setPaused(false) resumes")
moving = {tuple(message[5].array()) for message in fields_to(player, slot, 5)}
check(len(moving) > 5, "and the monsters walk again")

# The safety net: a character under the map is put back on its own base.
fall = float(Layout.d["FALL_HEIGHT"])
root.props["CFrame"] = CFrame(Vector3(here.x + 300, fall - 20, here.z))
world.advance(1.5)
check(flat(root.props["CFrame"].p, here) < 1 and root.props["CFrame"].p.y > 0, "a fallen character is back on its base")
act("visitInvite", 202.0)  # too soon after the last one for the same player: refused, and harmless
act("visitInvite", 101.0, friend)
act("visitJoin", 202.0)
check(player.attrs.get("Place") == "visit", "the first player visits the second")
root.props["CFrame"] = CFrame(Vector3(root.props["CFrame"].p.x, fall - 20, root.props["CFrame"].p.z))
world.advance(1.5)
check(player.attrs.get("Place") == "plot" and flat(root.props["CFrame"].p, here) < 1, "a guest who falls lands on their own base, not the host's")

# The host leaves: their guest is sent home.
act("visitInvite", 101.0, friend)
world.advance(4)
act("visitJoin", 202.0)
if player.attrs.get("Place") != "visit":
    # The first invitation was used; the second waits behind the "ask again later" time.
    world.advance(100)
    act("visitInvite", 101.0, friend)
    act("visitJoin", 202.0)
check(player.attrs.get("Place") == "visit", "visiting again")
world.remove_player(friend)
world.advance(1)
check(player.attrs.get("Place") == "plot" and player.attrs.get("Visiting") == 0 and flat(root.props["CFrame"].p, here) < 1,
      "when the host leaves the game, the guest is sent home")
check(friend_plot.attrs.get("Owner") == 0, "and the host's base is released")

world.remove_player(player)
world.advance(1)
check(plot.attrs.get("Owner") == 0 and len(towers.children) == 0, "leaving releases the plot")
check(pad1.attrs.get("Owned") is False, "and its pads are for sale again")

bad = problems(world)
for line in bad:
    print("  ", line)
check(not bad, "no warnings or errors")
print("FAILED" if failures else "PASSED", "play.py")
sys.exit(1 if failures else 0)
