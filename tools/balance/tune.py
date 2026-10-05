#!/usr/bin/env python3
"""Tries knob changes on the draft and prints one line per trial:

    python3 tune.py worlds key=value ... [player options]

A key with dots reaches into a nested table: kinds.boss.hp=8, towers.sniper.damage=40, worldPay.0=12.
A key that starts with "features." changes a number of the systems around the fight for the trial (they are
read out of Config.luau and src/shared/Features, not out of model.py): features.hugePower=2,
features.shop.powerupClears.Common=30, features.mastery.tracks.0.per=0.05.
Player options are the simulator's own, without the dashes: payer=1, hours=4, speed=1, rebirths=0, seed=2,
egg_share=0.4, egg_limit=300, off=mastery,powerups, passes=slots3,slots5."""
import copy
import sys

import model as M
import sim

PLAYER = {"payer", "hours", "speed", "speed_after", "rebirths", "seed", "egg_share", "egg_limit", "presence", "off", "passes", "huges", "enchant"}


def put(table, key, value):
    parts = key.split(".")
    for part in parts[:-1]:
        table = table[int(part) if part.isdigit() else part]
    table[int(parts[-1]) if parts[-1].isdigit() else parts[-1]] = value


def build(overrides):
    """The draft with those knobs, and those feature numbers."""
    knobs = copy.deepcopy(M.KNOBS)
    features = None
    for key, value in overrides.items():
        if key.startswith("features."):
            features = features or copy.deepcopy(M.features())
            put(features, key[len("features."):], value)
        else:
            put(knobs, key, value)
    model = M.draft(knobs)
    if features:
        model.features = features
    return model


def trial(overrides, worlds, label="", **options):
    player = sim.play(build(overrides), worlds, **options)
    sim.one_line(label or " ".join("%s=%s" % kv for kv in overrides.items()) or "as it is", player, worlds)
    return player


def parse(arguments):
    overrides, options = {}, {}
    for arg in arguments:
        key, value = arg.split("=", 1)
        if key in PLAYER:
            if key == "payer":
                options["passes"] = sim.PASSES
            elif key in ("off", "passes", "huges"):
                options[key] = tuple(v for v in value.split(",") if v)
            elif key in ("speed", "speed_after", "rebirths", "seed", "egg_limit"):
                options[key] = int(value)
            else:
                options[key] = float(value)
        else:
            overrides[key] = float(value)
    return overrides, options


if __name__ == "__main__":
    worlds = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    overrides, options = parse(sys.argv[2:])
    trial(overrides, worlds, **options)
