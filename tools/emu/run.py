#!/usr/bin/env python3
"""Boots the game's server script (and, when a test asks, its client script) inside the emulator and runs
Luau test chunks against it:  python3 run.py [--all-features] [--src DIR] test1.luau [test2.luau ...]

Plots, Marketplace and Leaderboard are replaced by the stand-ins in mocks/ (--real-plots keeps the real
src/server/Plots.luau, for tests of the client against what the server really builds; --real-leaderboard keeps
the real src/server/Leaderboard.luau, on emulated OrderedDataStores). By default only this agent's
feature modules are loaded from the Features folders, so other agents' unfinished work cannot fail a run.
"""
import os
import sys
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from luau_emu import LuaError, LuaSyntaxError, first, tostr  # noqa: E402
from roblox_emu import CFrame, Instance, Vector2, World, array, lib, lua_value  # noqa: E402

SRC = os.path.normpath(os.path.join(HERE, "..", "..", "src"))
MINE = {"Powerups", "Backpack"}
TRUSTED = [
    "client/UI.luau", "client/Hud.luau", "client/Windows.luau", "client/Effects.luau", "client/Market.luau",
    "client/State.luau", "client/init.client.luau", "client/Field.luau", "server/Game.luau", "server/Plots.luau",
    "server/Build.luau", "server/Marketplace.luau", "server/Leaderboard.luau",
    "server/Passes.luau", "server/Data.luau", "shared/Models.luau",
]


def make_world(src, features, real=()):
    world = World()
    world.harvest_props([path for path in (os.path.join(src, p) for p in TRUSTED) if os.path.exists(path)])
    world.load_dir(os.path.join(src, "shared"), "Shared", features).set_parent(world.service("ReplicatedStorage"))
    server = world.load_dir(os.path.join(src, "server"), "Server", features)
    server.set_parent(world.service("ServerScriptService"))
    for name in ("Plots", "Marketplace", "Leaderboard"):
        if name in real:
            continue
        module = server.child(name)
        module.source_path = os.path.join(HERE, "mocks", name + ".luau")
    world.client = world.load_dir(os.path.join(src, "client"), "Client", features)
    workspace = world.service("Workspace")
    camera = Instance(world, "Camera")
    camera.props["ViewportSize"] = Vector2(1280, 720)
    camera.props["CFrame"] = CFrame()
    camera.set_parent(workspace)
    workspace.props["CurrentCamera"] = camera
    for name in ("Players", "RunService", "HttpService", "MarketplaceService", "DataStoreService", "TweenService",
                 "UserInputService", "Lighting", "ProximityPromptService", "PolicyService"):
        world.service(name)
    install_harness(world)
    return world


def install_harness(world):
    interp = world.interp
    players = world.service("Players")

    def add_player(name="Tester", user_id=1):
        player = Instance(world, "Player", name)
        player.props.update({"UserId": user_id, "DisplayName": name, "CameraMaxZoomDistance": 128})
        Instance(world, "PlayerGui").set_parent(player)
        Instance(world, "PlayerScripts").set_parent(player)
        player.set_parent(players)
        players.props["LocalPlayer"] = player
        players.signal("PlayerAdded").fire(player)
        interp.flush()
        return player

    def remove_player(player):
        players.signal("PlayerRemoving").fire(player)
        player.set_parent(None)
        interp.flush()

    def run_client():
        player = players.props["LocalPlayer"]
        world.client.set_parent(player.child("PlayerScripts"))
        world.run_script(world.client)
        interp.flush()

    def step(dt=0.5):
        world.advance(dt)
        world.service("RunService").signal("Heartbeat").fire(dt)
        interp.flush()

    def click(inst):
        inst.signal("Activated").fire()
        interp.flush()

    def force_random(*values):
        world.forced_random.extend(values)

    def prompts():
        return array([lua_value({"kind": kind, "id": ident}) for kind, _, ident in world.prompts])

    def receipt(player, product_id, purchase_id):
        handler = world.service("MarketplaceService").props.get("ProcessReceipt")
        receipt = lua_value({"PlayerId": player.props["UserId"], "ProductId": product_id, "PurchaseId": purchase_id})
        decision = first(interp.call(handler, [receipt]))
        interp.flush()
        return tostr(decision)

    def fire(inst, name, *args):
        inst.signal(name).fire(*args)
        interp.flush()

    def load(name):
        path = os.path.join(HERE, "tests", name)
        return interp.run(open(path, encoding="utf-8").read(), path, {})

    def set_studio(value):
        world.is_studio = value is True

    def set_policy(restricted=None):
        # What PolicyService answers from now on: true = paid random items are restricted, false = allowed,
        # nil = the lookup fails. The game asks once per player, so set it before the player joins.
        world.policy_restricted = restricted if isinstance(restricted, bool) else None

    def set_time(unix):
        world.clock = float(unix)

    def fail_ordered(count):
        world.ordered_failures = int(count)

    interp.globals.vars["harness"] = lib({
        "addPlayer": add_player, "removePlayer": remove_player, "runClient": run_client, "step": step,
        "click": click, "forceRandom": force_random, "prompts": prompts, "receipt": receipt,
        "errors": lambda: len(interp.errors), "flush": interp.flush, "advance": world.advance,
        "setStudio": set_studio, "setPolicy": set_policy, "setTime": set_time, "failOrdered": fail_ordered, "now": lambda: world.clock,
        "clearRandom": lambda: world.forced_random.clear(), "fire": fire, "load": load,
        "randomLeft": lambda: len(world.forced_random),
    })


def run(test, src, features, real=()):
    world = make_world(src, features, real)
    interp = world.interp
    failed = False
    try:
        pre = test[: -len(".luau")] + ".pre.luau"
        if os.path.exists(pre):
            # Runs before the server script: for changing shared data the features read when they start.
            interp.run(open(pre, encoding="utf-8").read(), pre, {})
        world.run_script(world.service("ServerScriptService").child("Server"))
        interp.flush()
        interp.run(open(test, encoding="utf-8").read(), test, {})
        interp.flush()
    except LuaSyntaxError as e:
        print(f"SYNTAX ERROR: {e}")
        failed = True
    except LuaError as e:
        print(f"LUA ERROR: {e.value}\n{e.trace or ''}")
        failed = True
    if interp.errors:
        print(f"{len(interp.errors)} error(s) in spawned threads / signal handlers (printed above)")
        failed = True
    benign = {"harness"}
    for name, where in sorted(interp.undefined.items()):
        if name not in benign:
            print(f"undefined global read: {name} (first at {where})")
            failed = True
    for name, where in sorted(interp.global_writes.items()):
        print(f"global written without 'local': {name} (first at {where})")
        failed = True
    print(("FAILED " if failed else "PASSED ") + os.path.basename(test))
    return not failed


def main():
    args = sys.argv[1:]
    features = MINE
    src = SRC
    if "--all-features" in args:
        args.remove("--all-features")
        features = None
    if "--no-features" in args:
        args.remove("--no-features")
        features = set()
    real = set()
    if "--real-plots" in args:
        args.remove("--real-plots")
        real.add("Plots")
    if "--real-leaderboard" in args:
        # The real src/server/Leaderboard.luau, on the emulated OrderedDataStores (tests/event_board.luau).
        args.remove("--real-leaderboard")
        real.add("Leaderboard")
    if "--src" in args:
        i = args.index("--src")
        src = args[i + 1]
        del args[i : i + 2]
    ok = True
    for test in args:
        if test.endswith(".pre.luau"):
            continue
        ok = run(test, src, features, real) and ok
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    threading.stack_size(512 * 1024 * 1024)
    t = threading.Thread(target=main)
    t.start()
    t.join()
