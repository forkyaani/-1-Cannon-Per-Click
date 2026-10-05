#!/usr/bin/env python3
"""Fits the coin anchor of each world (KNOBS["worldPay"], Config.Level.worldPay) so that every world takes the
simulated free player its target time:

    python3 fit.py [first world to fit] [last] [key=value ...]

The targets are real minutes at the speed and the hours a day the simulator's player plays (sim.Player):
Earth takes EARTH, every world after it RATIO times the one before. Worlds are fitted in order, each on the
average of a few seeds; the players are carried over from world to world, so a world is only ever played
from its own first level. key=value changes a knob or a feature number for the whole fit, as in tune.py.

The result is printed as a list to paste into model.py and Config.luau. The player is a set of plain rules,
so the fit is only as good as that player: see docs/BALANCE.md.
"""
import copy
import pickle
import sys
from concurrent.futures import ProcessPoolExecutor

import model as M
import sim
import tune

EARTH = 82.0  # real minutes
FIRST_TEN = 10.0  # real minutes for the first ten levels, which a new player plays at 1x
RATIO = 1.175  # every world should take this many times as long as the one before
SEEDS = (1, 2, 3, 4)
TOLERANCE = 0.04
ROUNDS = 8


def target(world):
    return EARTH * RATIO ** (world - 1)


def one(args):
    """One seed plays one world. Returns (real minutes it took or None, the player afterwards, minutes for the first ten levels)."""
    overrides, world, seed, start, options = args
    player = pickle.loads(start) if start else None
    before = player.real if player else 0.0
    model = tune.build(overrides)
    limit = (before / 60 + target(world) * 4) / 60
    player = sim.play(model, world, start=player, limit=limit, **({} if player else dict(options, seed=seed)))
    done = world * M.WAVES_PER_WORLD in player.first_clear
    ten = player.snapshots.get(10, {}).get("minutes")
    return ((player.real - before) / 60 if done else None, pickle.dumps(player), ten)


def measure(pool, overrides, world, starts, options):
    runs = list(pool.map(one, [(overrides, world, seed, starts[index], options) for index, seed in enumerate(SEEDS)]))
    times = [run[0] for run in runs]
    tens = [run[2] for run in runs if run[2] is not None]
    return (None if None in times else sum(times) / len(times)), [run[1] for run in runs], times, (sum(tens) / len(tens) if tens else None)


def head_start(top):
    """Config.Level.headStart: the first levels pay `top` times the curve, and less each level, so that what a
    monster pays stays about level while it lasts. It ends where the curve has caught up."""
    table, level = [], 1
    while top / M.KNOBS["coinGrowth"] ** (level - 1) > 1.05:
        table.append(float("%.3g" % (top / M.KNOBS["coinGrowth"] ** (level - 1))))
        level += 1
    return table


def fit_earth(pool, overrides, pay, options):
    """Earth has two targets: the whole world, and its first ten levels. The anchor moves the first, the head
    start the second. Returns the head start's first number."""
    top = (M.KNOBS.get("headStart") or [1])[0]
    best = None
    for _ in range(ROUNDS * 2):
        trial = dict(overrides, headStart=head_start(top), **{"worldPay.0": pay[0]})
        took, _, times, ten = measure(pool, trial, 1, [None] * len(SEEDS), options)
        off = 3.0 if took is None else took / target(1)
        early = 3.0 if ten is None else ten / FIRST_TEN
        print("  Earth: anchor %.4g, head start %.3g -> %s min (target %.0f), first ten %s min (target %.0f)" % (
            pay[0], top, "%.0f" % took if took else "never", target(1), "%.1f" % ten if ten else "-", FIRST_TEN), flush=True)
        score = abs(off - 1) + abs(early - 1)
        if best is None or score < best[0]:
            best = (score, pay[0], top)
        if abs(off - 1) <= TOLERANCE and abs(early - 1) <= 0.12:
            break
        # Fewer coins overall make both longer; a bigger head start then gives the first levels theirs back.
        change = min(3.0, max(0.33, off)) ** 0.8
        pay[0] *= change
        top *= (min(3.0, max(0.33, early)) ** 0.8) / change
        top = max(1.0, top)
    pay[0] = float("%.3g" % best[1])
    return float("%.3g" % best[2])


def main():
    numbers = [arg for arg in sys.argv[1:] if "=" not in arg]
    first = int(numbers[0]) if len(numbers) > 0 else 1
    last = int(numbers[1]) if len(numbers) > 1 else M.WORLDS
    overrides, options = tune.parse([arg for arg in sys.argv[1:] if "=" in arg])
    pay = list(M.KNOBS["worldPay"])
    for key in list(overrides):
        if key.startswith("worldPay."):
            pay[int(key.split(".")[1])] = overrides.pop(key)
    starts = [None] * len(SEEDS)
    with ProcessPoolExecutor(len(SEEDS)) as pool:
        if first == 1:
            top = fit_earth(pool, overrides, pay, options)
            overrides["headStart"] = head_start(top)
            print('"headStart": %s,' % overrides["headStart"], flush=True)
            first = 2
        for world in range(1, last + 1):
            best = None
            for _ in range(ROUNDS if world >= first else 1):
                trial = dict(overrides, **{"worldPay.%d" % index: value for index, value in enumerate(pay)})
                took, after, times, ten = measure(pool, trial, world, starts, options)
                # A world the player never finished counts as far too slow.
                off = 3.0 if took is None else took / target(world)
                if best is None or abs(off - 1) < abs(best[0] - 1):
                    best = (off, pay[world - 1], took, after, ten)
                print("  world %2d: anchor %.4g -> %s min (target %.0f)  %s%s" % (
                    world, pay[world - 1], "%.0f" % took if took else "never", target(world),
                    " ".join("%.0f" % t if t else "-" for t in times),
                    "  first ten levels %.1f min" % ten if world == 1 and ten else ""), flush=True)
                if world < first or abs(off - 1) <= TOLERANCE:
                    break
                # More coins, less time: the time goes about as one over the coins.
                pay[world - 1] *= min(3.0, max(0.33, off)) ** 0.9
            pay[world - 1] = float("%.3g" % best[1])
            starts = best[3]
            print("world %2d: anchor %.3g, %.0f min (target %.0f)" % (world, pay[world - 1], best[2] or 0, target(world)), flush=True)
    print('"worldPay": [%s],' % ", ".join("%.3g" % c for c in pay))


if __name__ == "__main__":
    main()
