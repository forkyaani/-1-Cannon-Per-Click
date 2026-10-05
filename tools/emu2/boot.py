"""Boots the real server (init.server.luau and everything it requires) inside the mini interpreter."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(1, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))  # luau_check.py
from roblox_mock import World
from luau_vm import LuaError, LuaTable, tostring

ROOT = os.path.normpath(os.environ.get("GAME_ROOT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

def boot(studio=False, features=None, now=None):
    world = World(ROOT)
    world.studio = studio
    if now is not None:
        world.vm.now = now
    if features is not None:
        world.child_filter = lambda ref, name: not ref.path.endswith(os.path.join("server", "Features")) or name in features
    world.run_file(os.path.join(ROOT, "src", "server", "init.server.luau"), world.server_script)
    return world

def module(world, relative):
    return world.modules[os.path.join(ROOT, relative)]

def remote(world, name):
    return world.services["ReplicatedStorage"].find("Remotes").find(name)

def data_of(world, player):
    Data = module(world, "src/server/Data.luau")
    return world.vm.call(Data.d["get"], [player])[0]

def story_meta(player):
    raw = player.attrs.get("Meta_story")
    return json.loads(raw) if raw else None

def toasts(world, clear=True):
    out = [entry[2][1] for entry in world.remote_log if entry[1] == "Notify"]
    if clear:
        world.remote_log[:] = [entry for entry in world.remote_log if entry[1] != "Notify"]
    return out

if __name__ == "__main__":
    try:
        world = boot()
    except LuaError as problem:
        print("BOOT FAILED:", problem)
        sys.exit(1)
    print("booted. output:")
    for line in world.vm.output:
        print("  ", line)
