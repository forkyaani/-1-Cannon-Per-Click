#!/usr/bin/env python3
"""Fits the coin anchors of the LAST worlds on the real Config.luau, leaving every world before them alone:

    python3 fit_new.py [first world to fit] [target minutes] [rebirths]      (default: 13 58 0)

For a world added at the end of the game (worlds 13 to 15 were fitted with this on 12 Oct 2026). Unlike fit.py
it does not use the Python draft in model.py: it plays sim.py on copies of src/shared in a temporary folder,
each with other numbers on the line of Config.Level.worldPay that holds the anchors being fitted. That line
has to hold exactly those anchors, one after the other, and nothing else:

	worldPay = {
		0.2748, 151, ... the anchors that stay ...,
		1.15e+35, 3.16e+37, 1.4e+41,
	},

Six seeds play the worlds before `first` once, then each world to fit is played from those six players until
its average is within 4% of the target; the players are carried on from world to world. The anchors are
printed, to be typed into Config.luau by hand. Nothing in the repository is written.
"""
import os
import pickle
import re
import shutil
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor

import model as M
import sim

SEEDS = (1, 2, 3, 4, 5, 6)
TOLERANCE = 0.04
ROUNDS = 10
FIRST = int(sys.argv[1]) if len(sys.argv) > 1 else 13
TARGET = float(sys.argv[2]) if len(sys.argv) > 2 else 58.0
REBIRTHS = int(sys.argv[3]) if len(sys.argv) > 3 else 0
COUNT = M.WORLDS - FIRST + 1
NUMBER = r"[0-9][0-9.e+]*"
LINE = re.compile(r"(\n\t\t)(" + ", ".join([NUMBER] * COUNT) + r"),(\n\t\},)")
SCRATCH = tempfile.mkdtemp(prefix="fit_new_")


def anchors():
    text = open(os.path.join(M.ROOT, "src", "shared", "Config.luau"), encoding="utf-8").read()
    found = LINE.search(text)
    if not found:
        sys.exit("Config.Level.worldPay has no line of its own with exactly %d anchors (see this file's top)" % COUNT)
    return [float(value) for value in found.group(2).split(", ")]


def write(pay):
    """A copy of src/shared with these anchors: the folder to hand to model.from_config."""
    folder = os.path.join(SCRATCH, "_".join("%.4g" % value for value in pay))
    if not os.path.exists(folder):
        shutil.copytree(os.path.join(M.ROOT, "src", "shared"), os.path.join(folder, "shared"))
        path = os.path.join(folder, "shared", "Config.luau")
        text = open(path, encoding="utf-8").read()
        text = LINE.sub(lambda m: m.group(1) + ", ".join("%.4g" % value for value in pay) + "," + m.group(3), text, count=1)
        open(path, "w", encoding="utf-8").write(text)
    return folder


def one(args):
    """One seed plays up to the end of one world. Returns (real minutes that world took or None, the player)."""
    src, world, seed, start = args
    model = M.from_config(src)
    if start:
        player = pickle.loads(start)
        before = player.real
        player = sim.play(model, world, start=player, limit=(before / 60 + TARGET * 6) / 60)
    else:
        before = 0.0
        player = sim.play(model, world, seed=seed, rebirths=REBIRTHS)
    done = world * M.WAVES_PER_WORLD in player.first_clear
    return (player.real - before) / 60 if done else None, pickle.dumps(player)


def main():
    pay = anchors()
    try:
        with ProcessPoolExecutor(len(SEEDS)) as pool:
            starts = [None] * len(SEEDS)
            if FIRST > 1:
                runs = list(pool.map(one, [(write(pay), FIRST - 1, seed, None) for seed in SEEDS]))
                starts = [run[1] for run in runs]
                print("worlds 1 to %d: %s min" % (FIRST - 1, " ".join("%.0f" % run[0] if run[0] else "-" for run in runs)), flush=True)
            for world in range(FIRST, M.WORLDS + 1):
                index, best = world - FIRST, None
                for _ in range(ROUNDS):
                    runs = list(pool.map(one, [(write(pay), world, seed, starts[i]) for i, seed in enumerate(SEEDS)]))
                    times = [run[0] for run in runs]
                    took = None if None in times else sum(times) / len(times)
                    # A world a player never finished counts as far too slow.
                    off = 3.0 if took is None else took / TARGET
                    print("  world %d: anchor %.4g -> %s  (%s)" % (
                        world, pay[index], "%.0f min" % took if took else "never", " ".join("%.0f" % t if t else "-" for t in times)), flush=True)
                    if best is None or abs(off - 1) < abs(best[0] - 1):
                        best = (off, pay[index])
                    if abs(off - 1) <= TOLERANCE:
                        break
                    # More coins, less time: the time goes about as one over the coins.
                    pay[index] *= min(3.0, max(0.33, off)) ** 0.9
                pay[index] = float("%.3g" % best[1])
                # The rounded anchor is what ships: the players carried on are the ones who played it.
                runs = list(pool.map(one, [(write(pay), world, seed, starts[i]) for i, seed in enumerate(SEEDS)]))
                starts = [run[1] for run in runs]
                print("world %d: anchor %.3g, %s min" % (world, pay[index], " ".join("%.0f" % run[0] if run[0] else "-" for run in runs)), flush=True)
        print("worldPay, worlds %d to %d: %s," % (FIRST, M.WORLDS, ", ".join("%.3g" % value for value in pay)))
    finally:
        shutil.rmtree(SCRATCH, ignore_errors=True)


if __name__ == "__main__":
    main()
