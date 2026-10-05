#!/usr/bin/env python3
"""Plays the idle defence game as a typical free player and reports how long everything takes.

    python3 sim.py                    the game in src/shared/Config.luau, all twelve worlds
    python3 sim.py --worlds 1         only Earth (fast)
    python3 sim.py --draft            the Python draft in model.py instead of Config.luau
    python3 sim.py --check            compare the draft with Config.luau, number by number
    python3 sim.py --no-eggs          a player who never hatches an egg
    python3 sim.py --egg-share 0.5    a player who spends half of everything on eggs
    python3 sim.py --egg-limit 600    a player who hatches each egg 600 times (150 is the ordinary player)
    python3 sim.py --presence 0       a player who is never near the monsters: their Huges fire no Huge Shot
                                      (the mini cannons' own damage lands wherever the player is)
    python3 sim.py --table            the balance table for docs/BALANCE.md

The fight is the server's own simulation step (src/server/Game.luau), copied: spawn, move, burn, leaks,
towers at the monster furthest along in range, mini cannons near the player. The player is a set of plain
rules (see Player): they are a stand-in for an ordinary child, not the best possible play.
"""
import argparse
import math
import random
import sys

import model as M

Q = 2  # path samples per stud
DT = 0.1
FUSE_ISLAND = 5  # Config.FuseIsland: the world whose island has the Fusion Machine


# ---------------------------------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------------------------------
class Field:
    def __init__(self, model):
        self.model = model
        path = model.path
        self.length = sum(math.dist(path[i], path[i + 1]) for i in range(len(path) - 1))
        self.n = int(self.length * Q) + 64  # past the end too: a monster is shot at once more before it leaks
        self.px, self.pz = [], []
        for i in range(self.n):
            x, z = self.at(i / Q)
            self.px.append(x)
            self.pz.append(z)
        self.cover = {}

    def at(self, d):
        path = self.model.path
        d = min(max(d, 0), self.length)
        for i in range(len(path) - 1):
            seg = math.dist(path[i], path[i + 1])
            if d <= seg or i == len(path) - 2:
                t = min(1, d / seg)
                return (path[i][0] + (path[i + 1][0] - path[i][0]) * t, path[i][1] + (path[i + 1][1] - path[i][1]) * t)
            d -= seg

    def coverage(self, point, reach):
        """bytearray over the path samples: 1 where the path is within `reach` of `point`."""
        key = (point, reach)
        if key not in self.cover:
            r2 = reach * reach
            self.cover[key] = bytearray(
                1 if (self.px[i] - point[0]) ** 2 + (self.pz[i] - point[1]) ** 2 <= r2 else 0 for i in range(self.n)
            )
        return self.cover[key]

    def covered(self, point, reach):
        """Studs of path within reach."""
        return sum(self.coverage(point, reach)) / Q


# ---------------------------------------------------------------------------------------------------
# One level
# ---------------------------------------------------------------------------------------------------
class Gun:
    __slots__ = ("damage", "interval", "cover", "splash2", "slow", "slow_s", "burn", "burn_s", "chain", "cd")


def fight(field, plan, guns, pet_rate, pet_damage, pet_cover, defense, lives=None, limit=900.0):
    """Returns (cleared, seconds, kills, share). guns' damage already holds every multiplier, and plan the
    player's own speed, healing and health changes. lives is the level's lives when a feature changed them.
    share is how much of the monster that leaked last had been shot off: what a failed boss level pays for."""
    px, pz, last = field.px, field.pz, field.length
    count, max_hp, speed, gap, regen, leak = plan["count"], plan["hp"], plan["speed"], plan["gap"], plan["regen"], plan["leak"]
    chain2 = field.model.chain_range ** 2
    lives = defense["lives"] if lives is None else lives
    monsters = []  # [d, hp, slowUntil, slow, burnUntil, burn]
    spawned, spawn_in, now, kills, pet_owed, share = 0, 0.0, 0.0, 0, 0.0, 0.0
    for gun in guns:
        gun.cd = 0.0

    def hit(m, damage, gun):
        m[1] -= damage
        if gun is not None:
            if gun.slow and (now >= m[2] or gun.slow >= m[3]):
                m[3] = gun.slow
                m[2] = now + gun.slow_s
            if gun.burn:
                left = m[5] * max(0.0, m[4] - now)
                m[4] = now + gun.burn_s
                m[5] = (left + gun.burn * damage * gun.burn_s) / gun.burn_s

    while now < limit:
        now += DT
        spawn_in -= DT
        while spawned < count and spawn_in <= 0:
            monsters.append([0.0, max_hp, 0.0, 0.0, 0.0, 0.0])
            spawned += 1
            spawn_in += gap
        alive = []
        for m in monsters:
            m[0] += (speed * (1 - m[3]) if now < m[2] else speed) * DT
            if regen and m[1] < max_hp:
                m[1] = min(max_hp, m[1] + max_hp * regen * DT)
            if now < m[4]:
                m[1] -= m[5] * DT
            if m[1] <= 0:
                kills += 1
            else:
                alive.append(m)
        monsters = alive

        for gun in guns:
            gun.cd -= DT
            shots = 0
            while gun.cd <= 0 and shots < 5:
                target, best = None, -1.0
                cover = gun.cover
                for m in monsters:
                    if m[1] > 0 and m[0] > best and cover[int(m[0] * Q)]:
                        target, best = m, m[0]
                if target is None:
                    gun.cd = 0.0
                    break
                shots += 1
                gun.cd += gun.interval
                victims = [target]
                if gun.chain:
                    at = target
                    for _ in range(gun.chain):
                        ax, az = px[int(at[0] * Q)], pz[int(at[0] * Q)]
                        nearest, near = None, chain2
                        for m in monsters:
                            if m[1] > 0 and m not in victims:
                                i = int(m[0] * Q)
                                d2 = (px[i] - ax) ** 2 + (pz[i] - az) ** 2
                                if d2 <= near:
                                    nearest, near = m, d2
                        if nearest is None:
                            break
                        victims.append(nearest)
                        at = nearest
                if gun.splash2:
                    i = int(target[0] * Q)
                    tx, tz = px[i], pz[i]
                    for m in monsters:
                        if m[1] > 0 and m not in victims:
                            i = int(m[0] * Q)
                            if (px[i] - tx) ** 2 + (pz[i] - tz) ** 2 <= gun.splash2:
                                victims.append(m)
                for m in victims:
                    hit(m, gun.damage, gun)
            if gun.cd < 0:
                gun.cd = 0.0

        if pet_rate > 0:
            pet_owed += pet_rate * DT
            while pet_owed >= 1:
                pet_owed -= 1
                target, best = None, -1.0
                for m in monsters:
                    if m[1] > 0 and m[0] > best and pet_cover[int(m[0] * Q)]:
                        target, best = m, m[0]
                if target is not None:
                    hit(target, pet_damage, None)
            pet_owed = min(pet_owed, 1.0)

        # Monsters at the end of the path cost lives (after the towers have had this step's shots at them).
        alive = []
        for m in monsters:
            if m[1] <= 0:
                kills += 1
            elif m[0] >= last:
                lives -= leak
                share = min(1.0, max(0.0, 1 - m[1] / max_hp))
            else:
                alive.append(m)
        monsters = alive
        if lives <= 0:
            return False, now, kills, share
        if spawned >= count and not monsters:
            return True, now, kills, share
    return False, now, kills, share


# ---------------------------------------------------------------------------------------------------
# The player
# ---------------------------------------------------------------------------------------------------
# How much more than its single-target damage a kind is taken to be worth, when the player compares towers.
KIND_WORTH = {"splash": 1.8, "chain": 0.7, "slow": 2.0, "boss": 0.15}

# The systems around the fight. A player has all of them; --off switches some away to see what each is worth.
SYSTEMS = ("story", "daily", "gemegg", "slots", "boosts", "mastery", "powerups", "shop", "crates", "ammo", "rebirth")
PASSES = ("tripleHatch", "tripleLuck", "slots3", "slots5", "hugeStarter")
LUCKY = ("Rare", "Epic", "Legendary", "Secret")
RUN_SECONDS = 34.0  # about what one level takes, break included: how the player turns boost time into levels
PACE = 1.15  # a damage multiplier m makes the game m^PACE times as fast (log of the upgrade cost step over the damage step)
MAX_SLOTS, MAX_RATE, MAX_LIVES = 20, 10, 999  # the core's limits (Game.luau)


def egg_odds(pets, luck):
    """Config.eggOdds: luck multiplies the chance of every Rare or better; Common and Uncommon shrink to fit."""
    if luck <= 1:
        return pets
    total = sum(p[0] for p in pets)
    plain = sum(p[0] for p in pets if p[2] not in LUCKY)
    room = total
    shares = [None] * len(pets)
    for index in range(len(pets) - 1, -1, -1):
        if pets[index][2] in LUCKY:
            shares[index] = min(pets[index][0] * luck, room)
            room -= shares[index]
    scale = room / plain if plain > 0 else 0
    return [((shares[i] if shares[i] is not None else p[0] * scale) * 100 / total,) + tuple(p[1:]) for i, p in enumerate(pets)]


class Player:
    """A free player who uses everything the game gives away, the way a sensible child would.

    The fight
    * Auto-advance on. A failed level drops them one back, where they farm until their towers are `retry`
      stronger than when they failed, then try again.
    * After every level they spend: the next pad when it is the best buy, a tower on every empty pad (the kind
      that looks best for its price), otherwise the upgrade that adds the most damage for its coins.
    * `egg_share` of everything they earn goes to the newest egg they have unlocked, up to `egg_limit` hatches
      of each. They fuse whatever can be fused and equip the best.
    * Their mini cannons deal flat damage per second (bonus x Config.PetDps) to the lead monster all the
      time. They stand in the middle of their plot `presence` of the time: only the Huge Shot needs that.

    Around it
    * They play `hours` real hours a day at `speed` (1x until level `speed_after` is cleared: a new player has
      not found the button yet). Boosts, daily limits and the Huge Shot run on real time, the fight on game time.
    * Gems (the daily reward, the missions, milestones, the story, crates, rebirths) go to whatever saves the
      most play time per gem: a Gem Egg early on, the weekly shop's slots and boosts, mastery levels.
    * Powerups are used as they come; Mega Damage and Deep Freeze are kept for a level that was just failed.
    * Every day they buy what the island shops sell (a powerup on each island, the ammo, one Boss Chest) when
      it is worth its coins, open the Daily Crate, and load the best ammo they own: coins while farming,
      damage while pushing.
    * They rebirth `rebirths` times, each as soon as it is allowed.
    """

    def __init__(self, model, seed=1, egg_share=0.2, egg_limit=150, presence=0.7, retry=1.15, stand=(0, 60), patience=4,
                 trace=0, speed=3, speed_after=10, hours=2.0, passes=(), huges=(), rebirths=1, off=(), enchant=1.0,
                 horizon=44.0, missions=0.85):
        self.stand = stand
        self.attach(model)
        self.rng = random.Random(seed)
        self.egg_share, self.egg_limit, self.presence, self.retry = egg_share, egg_limit, presence, retry
        self.stand = stand
        self.speed, self.speed_after, self.hours = speed, speed_after, hours
        self.passes = set(passes)
        self.off = set(off)
        self.rebirth_plan = 0 if "rebirth" in self.off else rebirths
        self.enchant, self.horizon, self.mission_share = enchant, horizon, missions
        self.huges = list(huges)
        if "hugeStarter" in self.passes and self.f.get("passPet") and self.f["passPet"] not in self.huges:
            self.huges.append(self.f["passPet"])

        self.coins = 0.0
        self.egg_wallet = 0.0
        self.gems = 0.0
        self.pads = [1]
        self.towers = {1: ["cannon", 1]}
        self.wave, self.cleared, self.best, self.auto = 1, 0, 0, True
        self.rebirths = 0
        self.kills = 0
        self.pets = []  # (bonus, fuse tier, egg or pet id, the unfused bonus, short name)
        self.hatched = {}
        self.seconds = 0.0  # game time
        self.real = 0.0  # real time played
        self.clock = 0.0  # real time, the hours away included: boosts run out on it
        self.today = 0.0  # real time played today
        self.day = -1
        self.failed_power = None
        self.farm_runs = 0
        self.runs = 0
        self.fails = 0
        self.first_clear = {}  # level -> real seconds played
        self.snapshots = {}  # level -> what the player had when they first cleared it
        self.spent = {"pads": 0.0, "towers": 0.0, "eggs": 0.0, "shop": 0.0}
        self.gems_spent = {"gem egg": 0.0, "slots": 0.0, "boosts": 0.0, "mastery": 0.0}
        self.gems_earned = 0.0
        self.income = 0.0  # coins the last level paid
        self.farm_income = 1.0  # coins the last cleared level paid
        self.trace = trace
        self.patience = patience  # how many levels' income the player will save up for a pad or a tower

        self.extra_slots = 0
        self.mastery_levels = {}
        self.items = {}  # powerups in the backpack; fractions are chances that have not come true yet
        self.boosts = {}  # boost id -> the clock time it runs out
        self.boost_time = {}  # boost id -> real seconds of play it covered (for the report)
        self.ammo = set()
        self.owed = {}  # chances that have not come true yet: ("pet", id), ("ammo", id), "egg", "drop", "chest"
        self.wishlist = []  # what the player means to buy at the island shops today
        self.daily = {}  # today's counters
        self.weekly = {}
        self.chest_world = 0
        self.next_drop = 0.0
        self.next_roll = 0.0
        self.next_ammo_roll = 0.0
        self.story_done = set()
        self.loadout = {"big": None, "mini": None}

        self.new_day()
        if "story" not in self.off:
            # The tutorial pays for the first upgrade, the second pad and the cannon that goes on it.
            self.coins += model.upgrade["cannon"][1] + model.pad_price[2] + model.towers["cannon"]["cost"]

    # A player can be put away and taken out again (fit.py carries one from world to world, across processes):
    # everything but the model and what is worked out from it.
    def __getstate__(self):
        state = dict(self.__dict__)
        for key in ("model", "f", "field", "cache", "pet_cover", "everywhere", "_odds", "powerups", "boost_defs", "ammo_defs", "tracks"):
            state.pop(key, None)
        return state

    def attach(self, model):
        self.model = model
        self.f = model.features
        self.field = Field(model)
        self.cache = {}
        self._odds = {}
        self._equipped = None
        self.pet_cover = self.field.coverage(self.stand, model.defense["petRange"])
        self.everywhere = [True] * len(self.pet_cover)  # the mini cannons' own damage needs no range
        powerups = self.f.get("powerups") or {"list": [], "boosts": {}, "maxUses": 4, "drops": None}
        self.powerups = {p["id"]: p for p in powerups["list"]}
        self.boost_defs = powerups["boosts"]
        self.ammo_defs = {a["id"]: a for a in (self.f.get("ammo") or {"types": []})["types"]}
        self.tracks = {t["id"]: t for t in (self.f.get("mastery") or {"tracks": []})["tracks"]}

    # -- time ------------------------------------------------------------------------------------------
    def speed_now(self):
        return self.speed if self.best >= self.speed_after else 1

    def active(self, boost):
        return self.boosts.get(boost, 0) > self.clock

    def pass_time(self, game_seconds):
        real = game_seconds / self.speed_now()
        for boost, until in self.boosts.items():
            if until > self.clock:
                self.boost_time[boost] = self.boost_time.get(boost, 0) + min(real, until - self.clock)
        self.seconds += game_seconds
        self.real += real
        self.clock += real
        self.today += real
        if self.today >= self.hours * 3600:
            self.clock += (24 - self.hours) * 3600
            self.today = 0.0
            self.new_day()

    def new_day(self):
        f = self.f
        self.day += 1
        if self.day > 0 and "daily" not in self.off:
            # Yesterday's missions.
            self.gain_gems(sum(f["missions"]) * self.mission_share)
        if "daily" not in self.off and f["daily"]:
            reward = f["daily"][self.day % len(f["daily"])]
            self.gain_gems(reward["gems"])
            if reward.get("boost") and reward["boost"] in self.powerups:
                self.give(reward["boost"], reward["minutes"] * 60 / self.powerups[reward["boost"]]["seconds"])
            if reward.get("pet"):
                self.add_pet(reward["pet"])
        self.daily = {"drops": 0, "gifts": 0, "chests": 0, "gemsHuge": 0.0}
        if self.day % 7 == 0:
            self.weekly = {item["id"]: item["limit"] for item in f["weeklyFixed"]}
        if "crates" not in self.off and "dailycrate" in f["crates"]:
            self.open_crate("dailycrate", 1.0)
        self.wishlist = []
        if "shop" not in self.off and f.get("shop"):
            shop = f["shop"]
            islands = [index for index in range(1, M.WORLDS + 1) if self.best >= (index - 1) * M.WAVES_PER_WORLD]
            for index in islands:
                if "ammo" not in self.off:
                    ammo = shop["ammo"][(index - 1) % len(shop["ammo"])]
                    if ammo in self.ammo_defs and ammo not in self.ammo and ("ammo", ammo, index) not in self.wishlist:
                        self.wishlist.append(("ammo", ammo, index))
            if "crates" not in self.off and shop["chest"] in f["crates"]:
                self.wishlist.append(("chest", shop["chest"], 1))
            if "powerups" not in self.off:
                stock = [p for p in shop["powerups"] if p in self.powerups]
                for index in islands:
                    self.wishlist.append(("powerup", stock[(self.day + index) % len(stock)], index))
        self.spend_gems()

    # -- mini cannons -----------------------------------------------------------------------------------
    def veteran(self):
        level, need, kills = 0, 25, self.kills
        while kills >= need:
            kills -= need
            level += 1
            need *= 3
        return level

    def mastery(self, track):
        return self.mastery_levels.get(track, 0)

    def mastered(self, track):
        """What a track multiplies (or adds to) its number by."""
        level = self.mastery(track)
        t = self.tracks.get(track)
        if not t or level <= 0:
            return 0 if t and t["how"] in ("add", "slots", "bond") else 1
        if t["how"] == "more":
            return 1 + t["per"] * level
        if t["how"] == "less":
            return 1 - t["per"] * level
        if t["how"] == "slots":
            return sum(1 for at in t["at"] if level >= at)
        return t["per"] * level  # add, bond

    def slots(self):
        count = self.model.max_equipped + self.extra_slots + self.mastered("slots")
        count += sum(n for key, n in self.f["passSlots"].items() if key in self.passes)
        return max(1, min(MAX_SLOTS, int(count)))

    def equipped(self):
        """The ordinary mini cannons that are equipped (Config.equippedPets: Huges first, one slot kept)."""
        if self._equipped is None:
            slots = self.slots()
            huges = min(len(self.huges), slots - 1 if self.pets else slots)
            self.huge_equipped = self.huges[:huges]
            self._equipped = sorted(self.pets, reverse=True)[: slots - huges]
        return self._equipped

    def huge_features(self):
        self.equipped()
        return [self.f["huges"].get(huge, {}) for huge in self.huge_equipped]

    def huge_mult(self, key):
        value = 1.0
        for feature in self.huge_features():
            if feature.get(key):
                value *= feature[key]
        return value

    def pet_bonus(self):
        tiers = self.model.tiers
        names = set()
        if tiers:
            for kind, level in self.towers.values():
                names.add(tiers[min(len(tiers), 1 + (level - 1) // 10) - 1])
        set_bonus = self.f["setBonus"]
        return sum(pet[0] * (set_bonus if pet[4] and pet[4] in names else 1) for pet in self.equipped())

    def pet_dps(self):
        """The mini cannons' own damage per second (Config.petDpsList and the `petDps` modifiers): bonus x
        Config.PetDps each, a Huge as much as the strongest ordinary one beside it (at least Config.HugeDps,
        times its feature's shots a second), all of it times Mastery Bond. Returns (dps, mini cannons equipped)."""
        self.equipped()  # also settles which Huges are equipped
        per = self.f.get("petDps", 100)
        names = set()
        tiers = self.model.tiers
        if tiers:
            for kind, level in self.towers.values():
                names.add(tiers[min(len(tiers), 1 + (level - 1) // 10) - 1])
        set_bonus = self.f["setBonus"]
        own = [pet[0] * per * (set_bonus if pet[4] and pet[4] in names else 1) for pet in self.equipped()]
        huge = max(max(own, default=0.0), self.f.get("hugeDps", 0))
        total = sum(own) + sum(huge * (feature.get("fireRate") or 1) for feature in self.huge_features())
        return total * self.mastered("bond"), len(own) + len(self.huge_equipped)

    def pet_gain(self, more):
        """What `more` mini cannon bonus is worth, as a share of the player's damage (for the gem offers): flat
        damage per second beside the towers', where it used to be a multiplier on them."""
        base = self.strength() + self.pet_dps()[0]
        return math.log((base + more * self.f.get("petDps", 100)) / base) if base > 0 else 0.0

    def power(self):
        """The multiplier on tower damage. Mini cannons are not in it since 5 Oct: pet_dps()."""
        self.equipped()
        value = self.f["hugePower"] ** len(self.huge_equipped)
        value *= 1 + self.veteran() * self.model.mastery_bonus
        value *= 1 + self.rebirths * self.f["rebirth"]["damage"]
        if self.active("power2x"):
            value *= 2
        value *= self.mastered("attack")
        return value * self.enchant

    def ammo_worth(self, ammo, boss_level, regen):
        """What an ammo multiplies the damage of its slot's shots by, on average."""
        a = self.ammo_defs[ammo]
        value = (a.get("damage") or 1) * ((a.get("bossDamage") or 1) if boss_level else 1)
        value *= 1 + (a.get("doubleChance") or 0)
        value *= 1 + (a.get("critChance") or 0) * ((a.get("critDamage") or 1) - 1)
        value *= 1 + (a.get("burn") or 0)
        value *= 1 + 0.5 * (a.get("slow") or 0) * (a.get("slowChance") or 0)
        if regen:
            value *= 1 + 0.5 * (a.get("healCut") or 0)
        return value

    def load_ammo(self, plan, farming):
        """The ammo in each slot for this level: coins while farming, damage while pushing."""
        if "ammo" in self.off or not self.ammo:
            self.loadout = {"big": None, "mini": None}
            return
        boss_level, regen = plan["kind"] != "normal", plan["regen"] > 0

        def damage(ammo):
            return self.ammo_worth(ammo, boss_level, regen)

        def farm(ammo):
            return (1 + (self.ammo_defs[ammo].get("coins") or 0), damage(ammo))

        self.loadout = {"big": max(self.ammo, key=farm if farming else damage), "mini": max(self.ammo, key=damage)}

    def coin_mult(self):
        fuse = self.model.fuse
        value = 1 + sum(fuse[1][2] for pet in self.equipped() if pet[1] >= 2)
        if self.active("coins2x"):
            value *= 2
        value *= self.mastered("coins") * self.huge_mult("coins")
        if self.loadout["big"]:
            value *= 1 + (self.ammo_defs[self.loadout["big"]].get("coins") or 0)
        return value

    def luck(self):
        value = self.f["luckPass"] if "tripleLuck" in self.passes else 1
        value *= self.mastered("luck") * self.huge_mult("luck")
        for boost, definition in self.boost_defs.items():
            if definition.get("luck") and self.active(boost):
                value *= definition["luck"]
        return max(1, value)

    def boost_mult(self, key):
        value = 1.0
        for boost, definition in self.boost_defs.items():
            if definition.get(key) is not None and self.active(boost):
                value *= definition[key]
        return value

    def upgrade_cost(self, kind, level):
        cost = self.model.upgrade[kind][level]
        mult = self.mastered("discount")
        return cost if mult == 1 else max(1, M.nice(cost * mult))

    def worth(self, kind, level, pad):
        """What the player thinks a tower is worth: damage per second, more for its special and its reach."""
        tower = self.model.towers[kind]
        dps = self.model.damage[kind][level] * tower["rate"]
        if tower.get("splash"):
            dps *= KIND_WORTH["splash"]
        if tower.get("chain"):
            dps *= 1 + KIND_WORTH["chain"] * tower["chain"]
        if tower.get("burn"):
            dps *= 1 + tower["burn"] * tower["burnSeconds"]
        if tower.get("slow"):
            dps *= KIND_WORTH["slow"]
        if tower.get("boss"):
            dps *= 1 + KIND_WORTH["boss"] * tower["boss"]
        reach = self.field.covered(self.model.pads[pad - 1], tower["range"])
        return dps * (reach / 100) ** 0.5

    def strength(self):
        """How strong the player is, by their own reckoning: what they compare with the day a level beat them.
        Boosts are left out: they come and go."""
        saved, self.boosts = self.boosts, {}
        power = self.power() * self.mastered("rate")
        self.boosts = saved
        return sum(self.worth(kind, level, pad) for pad, (kind, level) in self.towers.items()) * power

    def invested(self, kind, level):
        return self.model.towers[kind]["cost"] + sum(self.model.upgrade[kind][1:level])

    # -- what the game hands out ------------------------------------------------------------------------
    def gain_gems(self, amount):
        self.gems += amount
        self.gems_earned += amount

    def give(self, item, amount=1.0):
        """A backpack item: a powerup, an ammo, a crate."""
        if item in self.powerups:
            if "powerups" not in self.off:
                self.items[item] = self.items.get(item, 0) + amount
        elif item in self.ammo_defs:
            if "ammo" not in self.off and item not in self.ammo:
                self.owe(("ammo", item), amount)
        elif item in self.f["crates"]:
            if "crates" not in self.off:
                self.open_crate(item, amount)

    def give_random(self, amount=1.0):
        """Powerups.roll: one random powerup, by weight. The event's only fall during the event."""
        pool = [p for p in self.powerups.values() if not p["event"]]
        total = sum(p["weight"] for p in pool)
        for p in pool:
            self.give(p["id"], amount * p["weight"] / total)

    def owe(self, what, chance):
        """A chance of something. Chances add up, and the thing arrives when they make a whole one: every
        player gets the average, which keeps one lucky drop from deciding how long a whole game takes."""
        self.owed[what] = self.owed.get(what, 0) + chance
        while self.owed[what] >= 1:
            self.owed[what] -= 1
            if what == "egg":
                self.free_hatch()
            elif what[0] == "pet":
                self.add_pet(what[1])
            elif what[0] == "ammo":
                self.ammo.add(what[1])
                self.owed[what] = 0
                break

    def add_pet(self, pet_id):
        pet = self.f["pets"].get(pet_id)
        if pet:
            self.pets.append((pet["bonus"], 0, pet_id, pet["bonus"], pet["short"]))
            self.fuse()

    def clears(self, amount):
        """Coins worth that many clears of an ordinary level, at the furthest level cleared in this run."""
        return amount * self.model.level_coins[max(1, min(M.TOTAL, self.cleared))]

    def open_crate(self, crate, share=1.0):
        """Every row of the crate's table, each by its chance."""
        for row in self.f["crates"][crate]["rows"]:
            chance = row["chance"] / 100 * share
            if row.get("gems"):
                self.gain_gems(row["gems"] * chance)
            elif row.get("coins"):
                self.earn(self.clears(row["coins"]) * chance)
            elif row.get("pet"):
                self.owe(("pet", row["pet"]), chance)
            elif row.get("egg"):
                self.owe("egg", chance)
            elif row.get("item") and row["item"] != crate:
                self.give(row["item"], (row.get("amount") or 1) * chance)

    def pay(self, key, level, chapter=None):
        """A story reward (Story.Rewards)."""
        reward = self.f["story"]["rewards"][key]
        self.gain_gems(reward["gems"])
        if reward["clears"]:
            base = level
            while base > 1 and self.model.plans[base]["kind"] != "normal":
                base -= 1
            plan = self.model.plans[base]
            self.earn(reward["clears"] * plan["coins"] * plan["count"])
        for item in reward["items"]:
            if item["event"]:
                continue
            if item.get("id"):
                self.give(item["id"], item["amount"])
            elif item.get("category") == "powerup":
                # "One of its most common items, a different one each time."
                self.give("power2x", item["amount"] / 2)
                self.give("coins2x", item["amount"] / 2)
        if reward["pet"] and chapter:
            named = self.f["story"]["pets"].get(str(chapter))
            if named and named in self.f["pets"]:
                self.add_pet(named)
            else:
                # The Legendary of the world's own eggs.
                eggs = self.model.eggs[(chapter - 1) * 2:chapter * 2]
                best = max((pet for egg in eggs for pet in egg["pets"] if pet[2] == "Legendary"), key=lambda pet: pet[1], default=None)
                if best:
                    self.pets.append((best[1], 0, "story%d" % chapter, best[1], best[3]))
                    self.fuse()
            gift = self.f["story"]["gifts"].get(str(chapter))
            if gift:
                self.give(gift, 1)

    def story(self, level):
        """What the story pays on the first clear of a level. The quests between the levels (hatch, fuse, build)
        are paid at the level a player has usually done them by."""
        if "story" in self.off or not self.f.get("story"):
            return
        chapter, local = M.world_of(level)
        steps = {25: ["mid"], 50: ["final", "chapter"]}
        if chapter == 1:
            steps.update({1: ["step", "step"], 5: ["firstBoss", "firstHatch", "task"]})
            if local == 5:
                # "My treat": the first egg, and the second kind of tower.
                self.egg_wallet += self.model.eggs[0]["cost"]
                self.coins += self.model.towers[self.model.tower_order[1]]["cost"]
        else:
            steps.update({1: ["step"], 10: ["step"], 15: ["task"], 35: ["task"], 40: ["step"]})
        for key in steps.get(local, []):
            self.pay(key, level, chapter)

    def boss_killed(self, level, kind, first_ever):
        """What a defeated boss can leave behind."""
        f = self.f
        if "powerups" not in self.off and f.get("powerups") and f["powerups"].get("drops"):
            drops = f["powerups"]["drops"]
            if first_ever and self.daily["gifts"] < drops["firstClear"]["perDay"]:
                self.daily["gifts"] += 1
                self.give_random()
            if self.daily["drops"] < drops["boss"]["perDay"] and self.clock >= self.next_drop:
                chance = drops["boss"]["chance"].get(kind, 0)
                self.owed["drop"] = self.owed.get("drop", 0) + chance
                if self.owed["drop"] >= 1:
                    self.owed["drop"] -= 1
                    self.daily["drops"] += 1
                    self.next_drop = self.clock + drops["boss"]["cooldown"]
                    self.give_random()
        if "crates" not in self.off and f.get("crateDrops"):
            pool = f["crateDrops"]["pools"]["boss"]
            if self.clock >= self.next_roll:
                self.next_roll = self.clock + f["crateDrops"]["rollSeconds"]
                for crate_id, crate in f["crates"].items():
                    drop = crate.get("drop")
                    if drop and drop.get("pool") == "boss" and drop.get(kind) and self.daily["chests"] < pool["perDay"]:
                        self.owed["chest"] = self.owed.get("chest", 0) + drop[kind] * self.huge_mult("crateDrops")
                        if self.owed["chest"] >= 1:
                            self.owed["chest"] -= 1
                            self.daily["chests"] += 1
                            self.open_crate(crate_id)
            world = M.world_of(level)[0]
            if kind == "final" and world > self.chest_world:
                self.chest_world = world
                for crate_id, crate in f["crates"].items():
                    if crate.get("drop") and crate["drop"].get("firstClear"):
                        self.open_crate(crate_id)
        if "ammo" not in self.off and f.get("ammo") and self.clock >= self.next_ammo_roll:
            self.next_ammo_roll = self.clock + f["ammo"]["dropCooldown"]
            for ammo in f["ammo"]["types"]:
                if ammo.get("dropOneIn") and not ammo["event"] and ammo["id"] not in self.ammo:
                    self.owe(("ammo", ammo["id"]), 1 / ammo["dropOneIn"])
        for feature in self.huge_features():
            if feature.get("bossGems") and self.daily["gemsHuge"] < feature.get("gemsPerDay", 0):
                self.daily["gemsHuge"] += feature["bossGems"]
                self.gain_gems(feature["bossGems"])

    # -- powerups ---------------------------------------------------------------------------------------
    def use(self, item):
        """USE in the backpack: starts the powerup's boosts, or adds to their time. Refused past MaxUses."""
        powerup = self.powerups[item]
        left = min(max(0.0, self.boosts.get(boost, 0) - self.clock) for boost in powerup["boosts"])
        if self.items.get(item, 0) < 1 or left + powerup["seconds"] > self.f["powerups"]["maxUses"] * powerup["seconds"]:
            return False
        self.items[item] -= 1
        for boost in powerup["boosts"]:
            self.boosts[boost] = max(self.clock, self.boosts.get(boost, 0)) + powerup["seconds"]
        return True

    def use_powerups(self, failed=False):
        """Everything is used as it comes, except the two short ones: those wait for a level that beat the player."""
        used = False
        for item, powerup in self.powerups.items():
            short = any(self.boost_defs.get(boost, {}).get("damage") or self.boost_defs.get(boost, {}).get("slow") for boost in powerup["boosts"])
            if short and not failed:
                continue
            if short and any(self.active(boost) for boost in powerup["boosts"]):
                continue
            while self.items.get(item, 0) >= 1 and self.use(item):
                used = True
                if short:
                    break
        return used

    # -- gems -------------------------------------------------------------------------------------------
    def minutes_left(self):
        """Real minutes of play the player expects to have in front of them: what a permanent bonus works on."""
        return max(600.0, self.horizon * 60 - self.real / 60)

    def gem_offers(self):
        """Everything gems buy, as (minutes of play saved per gem, cost, what)."""
        f, offers = self.f, []
        left = self.minutes_left()
        bonus = self.pet_bonus()
        equipped = self.equipped()
        ordinary = self.slots() - len(self.huge_equipped)
        weakest = equipped[-1][0] if len(equipped) >= ordinary and equipped else 0.0
        spare = sorted(self.pets, reverse=True)[ordinary:ordinary + 1]

        if "gemegg" not in self.off and f.get("gemEgg"):
            egg = f["gemEgg"]
            gain = sum(chance / 100 * max(0.0, b - weakest) for chance, b, rarity, _ in egg["pets"] if rarity != "Secret")
            # It only lasts until the coin eggs outgrow it: two hours of play at the most.
            offers.append((PACE * self.pet_gain(gain) * min(left, 120) / egg["cost"], egg["cost"], ("gemegg",)))
        for item in f["weeklyFixed"]:
            if self.weekly.get(item["id"], 0) <= 0:
                continue
            if item["kind"] == "slot":
                if "slots" in self.off or self.extra_slots >= f["maxExtraSlots"] or self.slots() >= MAX_SLOTS or not spare:
                    continue
                gain = PACE * self.pet_gain(spare[0][0])
                offers.append((gain * left / item["cost"], item["cost"], ("slot", item["id"])))
            elif item["kind"] == "boost" and "boosts" not in self.off and item["boost"] in self.powerups:
                powerup = self.powerups[item["boost"]]
                if self.boosts.get(item["boost"], 0) - self.clock + item["minutes"] * 60 > f["powerups"]["maxUses"] * powerup["seconds"]:
                    continue
                gain = 2 ** PACE - 1 if item["boost"] == "power2x" else 1.0
                offers.append((gain * item["minutes"] / item["cost"], item["cost"], ("boost", item["id"], item["boost"], item["minutes"])))
        mastery = f.get("mastery")
        if "mastery" not in self.off and mastery and self.best >= (mastery["island"] - 1) * M.WAVES_PER_WORLD:
            for track in mastery["tracks"]:
                level = self.mastery(track["id"])
                if level >= track["cap"]:
                    continue
                per, how, cost, levels = track.get("per") or 0, track["how"], track["costs"][level], 1
                if how == "more" and track["kind"] == "petDps":
                    # Bond: that much more of the mini cannons' flat damage per second.
                    gain = PACE * self.pet_gain(bonus * per)
                elif how == "more":
                    gain = math.log((1 + per * (level + 1)) / (1 + per * level))
                    gain *= {"power": PACE, "towerRate": PACE, "towerRange": PACE * 1.2, "bossDamage": PACE * 0.5,
                             "petShots": PACE * 0.2, "coins": 1.0, "luck": PACE * 0.3}.get(track["kind"], 0)
                elif how == "less":
                    gain = math.log((1 - per * level) / (1 - per * (level + 1)))
                    gain *= 1.0 if track["kind"] == "upgradeCost" else PACE
                elif how == "add":
                    gain = PACE * 0.02  # a life: one more monster in ten may get through an ordinary level
                elif how == "slots":
                    target = next((at for at in track["at"] if at > level), None)
                    if target is None or not spare or self.slots() >= MAX_SLOTS:
                        continue
                    cost, levels = sum(track["costs"][level:target]), target - level
                    gain = PACE * self.pet_gain(spare[0][0])
                else:
                    continue
                offers.append((gain * left / cost, cost, ("mastery", track["id"], levels)))
        return offers

    def spend_gems(self):
        while self.gems >= 30:
            offers = [offer for offer in self.gem_offers() if offer[1] <= self.gems and offer[0] > 0]
            if not offers:
                # Saving up: for the best thing on offer, if it is worth waiting for.
                return
            value, cost, what = max(offers)
            dearer = [offer for offer in self.gem_offers() if offer[1] > self.gems]
            if dearer and max(dearer)[0] > value * 1.5:
                return
            self.gems -= cost
            if what[0] == "gemegg":
                self.gems_spent["gem egg"] += cost
                self.roll_egg(self.f["gemEgg"]["pets"], "gem", self.luck())
                self.fuse()
            elif what[0] == "slot":
                self.gems_spent["slots"] += cost
                self.weekly[what[1]] -= 1
                self.extra_slots += 1
                self._equipped = None
            elif what[0] == "boost":
                self.gems_spent["boosts"] += cost
                self.weekly[what[1]] -= 1
                powerup = self.powerups[what[2]]
                self.items[what[2]] = self.items.get(what[2], 0) + what[3] * 60 / powerup["seconds"]
                self.use_powerups()
            elif what[0] == "mastery":
                self.gems_spent["mastery"] += cost
                self.mastery_levels[what[1]] = self.mastery(what[1]) + what[2]
                self._equipped = None

    # -- coins ------------------------------------------------------------------------------------------
    def best_kind(self, pad):
        """The kind to build on a pad: the best worth for the coins of building it and levelling it for a while."""
        best, value = None, 0
        for kind in self.model.tower_order:
            tower = self.model.towers[kind]
            if tower["unlock"] > self.best:
                continue
            # Compared at the spend the player's other towers are at, so a dear kind is not judged at level 1.
            budget = max([self.invested(k, l) for k, l in self.towers.values()] + [tower["cost"]])
            level, spent = 1, tower["cost"]
            while level < self.model.max_tower_level and spent + self.model.upgrade[kind][level] <= budget:
                spent += self.model.upgrade[kind][level]
                level += 1
            v = self.worth(kind, level, pad) / spent
            # A player wants one of each new thing, and not six of the same.
            same = sum(1 for k, _ in self.towers.values() if k == kind)
            v /= 1 + 0.35 * same
            if v > value:
                best, value = kind, v
        return best

    def shop_price(self, kind, item, index):
        """IslandShop.price."""
        shop = self.f["shop"]
        first = (index - 1) * M.WAVES_PER_WORLD + 1
        buyer = max(1, min(M.TOTAL, max(first, self.cleared)))
        if kind == "ammo":
            ammo = self.ammo_defs[item]
            world = shop["ammo"].index(item) + 1
            level = (world - 1) * M.WAVES_PER_WORLD + shop["ammoLevel"]
            cost = M.nice(shop["ammoClears"].get(ammo["rarity"], shop["ammoClears"]["Legendary"]) * self.model.level_coins[level])
            forge = ammo.get("price")
            if forge and forge.get("currency") == "coins":
                cost = min(cost, forge["cost"])
            return cost
        if kind == "powerup":
            clears = shop["powerupClears"].get(self.powerups[item]["rarity"], shop["powerupClears"]["Epic"])
            return M.nice(clears * self.model.level_coins[buyer])
        return M.nice(shop["chestClears"] * self.model.level_coins[buyer])

    def shop_worth(self, kind, item):
        """The most coins a row is worth to the player."""
        income = max(1.0, self.farm_income)
        if kind == "ammo":
            return 150 * income
        if kind == "chest":
            return 8 * income
        runs = self.powerups[item]["seconds"] * self.speed_now() / RUN_SECONDS
        gain = 0.0
        for boost in self.powerups[item]["boosts"]:
            definition = self.boost_defs.get(boost, {})
            if boost == "power2x":
                gain += 2 ** PACE - 1
            elif boost == "coins2x":
                gain += 1.0
            elif definition.get("fireRate"):
                gain += definition["fireRate"] ** PACE - 1
            elif definition.get("damage"):
                gain += 0.5 * (definition["damage"] ** PACE - 1)
            elif definition.get("slow"):
                gain += 0.5 * ((1 / (1 - definition["slow"])) ** PACE - 1)
            elif definition.get("luck"):
                egg = self.newest_egg()
                gain += 0.3 if egg and self.hatched.get(egg["id"], 0) < self.hatch_limit() else 0.0
        return 0.8 * gain * runs * income

    def shop(self):
        """The island shops: what is on today's list, as the coins come. False while saving up for the next."""
        while self.wishlist:
            kind, item, index = self.wishlist[0]
            if kind == "ammo" and item in self.ammo:
                self.wishlist.pop(0)
                continue
            price = self.shop_price(kind, item, index)
            if price > self.shop_worth(kind, item):
                self.wishlist.pop(0)
                continue
            if price > self.coins:
                return price > self.coins + self.patience * max(1.0, self.income)
            self.coins -= price
            self.spent["shop"] += price
            self.wishlist.pop(0)
            if kind == "ammo":
                self.ammo.add(item)
            else:
                self.give(item, 1)
        return True

    def spend(self):
        """The shops first, then pads, a tower on every pad, then upgrades. A purchase a few levels away is saved up for."""
        model = self.model
        if not self.shop():
            return
        income = max(1.0, self.income)
        while True:
            empty = [pad for pad in self.pads if pad not in self.towers]
            if empty:
                pad = empty[0]
                kind = self.best_kind(pad)
                cost = model.towers[kind]["cost"]
                if cost <= self.coins:
                    self.coins -= cost
                    self.towers[pad] = [kind, 1]
                    self.spent["towers"] += cost
                    continue
                if cost <= self.coins + self.patience * income:
                    return
            elif len(self.pads) < len(model.pads):
                price = model.pad_price[len(self.pads) + 1]
                if price <= self.coins:
                    self.coins -= price
                    self.pads.append(len(self.pads) + 1)
                    self.spent["pads"] += price
                    continue
                if price <= self.coins + self.patience * income:
                    return
            best, value = None, 0
            for pad, (kind, level) in self.towers.items():
                if level < model.max_tower_level:
                    cost = self.upgrade_cost(kind, level)
                    if cost <= self.coins:
                        v = (self.worth(kind, level + 1, pad) - self.worth(kind, level, pad)) / cost
                        if v > value:
                            best, value = pad, v
            if best is None:
                return
            kind, level = self.towers[best]
            cost = self.upgrade_cost(kind, level)
            self.coins -= cost
            self.towers[best][1] += 1
            self.spent["towers"] += cost

    # -- eggs -------------------------------------------------------------------------------------------
    def newest_egg(self):
        egg = None
        for candidate in self.model.eggs:
            if candidate["unlock"] <= self.best:
                egg = candidate
        return egg

    def hatch_limit(self):
        # The x3 Egg Opener: as many presses, three eggs each.
        return self.egg_limit * (3 if "tripleHatch" in self.passes else 1)

    def roll_egg(self, pets, key, luck):
        odds = self._odds.get((key, round(luck, 3)))
        if odds is None:
            odds = egg_odds(pets, luck)
            self._odds[(key, round(luck, 3))] = odds
        roll = self.rng.random() * 100
        picked = odds[0]
        for pet in reversed(odds):
            if pet[0] > 0:
                picked = pet
                roll -= pet[0]
                if roll < 0:
                    break
        self.pets.append((picked[1], 0, key, picked[1], picked[3]))
        self._equipped = None

    def free_hatch(self):
        """A crate's egg row: the best coin egg within reach of this run's furthest level, without luck."""
        egg = None
        for candidate in self.model.eggs:
            if candidate["unlock"] <= self.cleared:
                egg = candidate
        egg = egg or self.model.eggs[0]
        self.roll_egg(egg["pets"], egg["id"], 1)
        self.fuse()

    def hatch(self):
        if self.egg_share <= 0:
            return
        egg = self.newest_egg()
        if egg is None:
            return
        limit = self.hatch_limit()
        done = self.hatched.get(egg["id"], 0)
        if done >= limit:
            # Enough of this egg: the egg money goes back to the towers until a new egg unlocks.
            self.coins += self.egg_wallet
            self.egg_wallet = 0
            return
        changed = False
        luck = self.luck()
        free = min((feature["freeEgg"] for feature in self.huge_features() if feature.get("freeEgg")), default=0)
        while self.egg_wallet >= egg["cost"] and done < limit:
            if not (free and done % free == free - 1):
                self.egg_wallet -= egg["cost"]
                self.spent["eggs"] += egg["cost"]
            done += 1
            self.roll_egg(egg["pets"], egg["id"], luck)
            changed = True
        self.hatched[egg["id"]] = done
        if changed:
            self.fuse()

    def fuse(self):
        """Fuses everything that can be: three of the same make one of the next tier. Only once the Fusion
        Machine's world (Config.FuseIsland, The Sun) is reached: fusing is done on its island."""
        if self.best < (FUSE_ISLAND - 1) * M.WAVES_PER_WORLD:
            return
        model = self.model
        self._equipped = None
        for tier in range(len(model.fuse)):
            groups = {}
            for pet in self.pets:
                if pet[1] == tier:
                    groups.setdefault((pet[2], pet[3], pet[4]), []).append(pet)
            for (egg, base, short), same in groups.items():
                for _ in range(len(same) // model.fuse_count):
                    for _ in range(model.fuse_count):
                        self.pets.remove((base * (model.fuse[tier - 1][0] if tier else 1), tier, egg, base, short))
                    self.pets.append((base * model.fuse[tier][0], tier + 1, egg, base, short))

    def earn(self, coins):
        self.egg_wallet += coins * self.egg_share
        self.coins += coins * (1 - self.egg_share)

    # -- playing ----------------------------------------------------------------------------------------
    def play_level(self):
        model, f = self.model, self.f
        level = self.wave
        base = model.plans[level]
        boss_level = base["kind"] != "normal"
        self.load_ammo(base, not self.auto)
        power = self.power()
        towers = self.towers
        features = self.huge_features()
        speed = self.speed_now()

        rate = min(MAX_RATE, max(0.1, self.mastered("rate") * self.boost_mult("fireRate")))
        reach = min(4.0, max(0.25, self.mastered("range")))
        shot = self.boost_mult("damage")  # the `damage` modifiers: Mega Damage
        if boss_level:
            shot *= self.mastered("boss") * self.huge_mult("bossDamage")
        for feature in features:
            if feature.get("multiChance"):
                shot *= 1 + feature["multiChance"] * (feature["multiHits"] - 1)
        ammo_big = self.ammo_worth(self.loadout["big"], boss_level, base["regen"] > 0) if self.loadout["big"] else 1.0
        ammo_mini = self.ammo_worth(self.loadout["mini"], boss_level, base["regen"] > 0) if self.loadout["mini"] else 1.0

        # The level, as this player meets it.
        plan = base
        slow = max((self.boost_defs[boost].get("slow") or 0 for boost in self.boost_defs if self.active(boost)), default=0)
        walk = min(3.0, max(0.2, self.mastered("slow"))) * (1 - slow)
        regen = base["regen"]
        if regen:
            share = 1.0
            for pet in self.equipped():
                if pet[1] >= 3:
                    share *= 1 - 0.2
            regen *= max(f["minHealShare"], share) * self.huge_mult("heal") * self.boost_mult("heal")
            for slot in ("big", "mini"):
                if self.loadout[slot]:
                    regen *= 1 - (self.ammo_defs[self.loadout[slot]].get("healCut") or 0)
        execute = max((feature.get("execute") or 0 for feature in features), default=0)
        if walk != 1 or regen != base["regen"] or execute:
            plan = dict(base, speed=base["speed"] * walk, regen=regen, hp=max(1, base["hp"] * (1 - execute)))
        lives = max(1, min(MAX_LIVES, int(model.defense["lives"] + self.mastered("lives") + 0.5)))

        # Mini cannons: flat damage per second on the lead monster wherever the player is, in shots of DPS / shots
        # per second (the rate only cuts it up). The power multiplier does not touch it; the per-shot modifiers
        # and the mini cannons' ammo do. A Huge Shot is five of the average mini cannon's seconds, every two
        # real seconds, and only while the player stands at the fight: it is folded into the same shots.
        pets, count = self.pet_dps()
        if count:
            pets += len(features) * f["hugeShot"]["shots"] * (pets / count) / (f["hugeShot"]["seconds"] * speed) * self.presence
        fuse = model.fuse
        pet_rate = sum((fuse[0][1] if pet[1] >= 1 else 1) * model.auto_shots for pet in self.equipped())
        pet_rate += sum((feature.get("fireRate") or 1) * model.auto_shots for feature in features)
        pet_rate *= self.mastered("rapid")
        pet_damage = pets * shot * ammo_mini / pet_rate if pet_rate > 0 else 0.0

        key = (level, tuple(sorted((pad, kind, lvl) for pad, (kind, lvl) in towers.items())), round(power * shot, 6),
               round(pet_rate, 3), float("%.6g" % pet_damage), round(rate, 4), round(reach, 4), round(ammo_big, 4), round(ammo_mini, 4), round(walk, 4),
               round(regen, 6), lives, execute)
        result = self.cache.get(key)
        if result is None:
            guns = []
            for pad, (kind, lvl) in sorted(towers.items()):
                tower = model.towers[kind]
                gun = Gun()
                gun.damage = model.damage[kind][lvl] * power * shot * ammo_big * ((tower.get("boss") or 1) if boss_level else 1)
                gun.interval = 1 / (tower["rate"] * rate)
                gun.cover = self.field.coverage(model.pads[pad - 1], tower["range"] * reach)
                gun.splash2 = (tower.get("splash") or 0) ** 2
                gun.slow, gun.slow_s = tower.get("slow") or 0, tower.get("slowSeconds") or 0
                gun.burn, gun.burn_s = tower.get("burn") or 0, tower.get("burnSeconds") or 0
                gun.chain = tower.get("chain") or 0
                guns.append(gun)
            result = fight(self.field, plan, guns, pet_rate, pet_damage, self.everywhere, model.defense, lives)
            if len(self.cache) > 20000:
                self.cache.clear()
            self.cache[key] = result
        cleared, seconds, kills, share = result
        self.runs += 1
        self.kills += kills
        coins = self.coin_mult()
        self.income = kills * math.floor(base["coins"] * coins)
        if not cleared and boss_level:
            # A boss that gets through pays for the damage it took (Game.luau, levelFailed).
            self.income += math.floor(base["coins"] * coins * share * model.defense.get("failShare", 0))
        if cleared:
            self.farm_income = self.income
        self.earn(self.income)
        self.level_seconds = seconds + model.defense["breakSeconds"]
        return cleared

    def snapshot(self, level):
        kinds = {}
        for kind, lvl in self.towers.values():
            kinds.setdefault(kind, []).append(lvl)
        towers = ", ".join(
            "%d %s L%s" % (len(levels), kind, ("%d" % levels[0]) if len(set(levels)) == 1 else "%d-%d" % (min(levels), max(levels)))
            for kind, levels in sorted(kinds.items(), key=lambda kv: self.model.tower_order.index(kv[0]))
        )
        self.snapshots[level] = dict(
            minutes=self.real / 60, game=self.seconds / 60, day=self.day + 1, towers=towers, pads=len(self.pads),
            power=self.power(), plan=self.model.plans[level], runs=self.runs, fails=self.fails, mastery=self.veteran(),
            gems=self.gems_earned, slots=self.slots(), tracks=dict(self.mastery_levels), rebirths=self.rebirths,
        )

    def rebirth(self):
        """Config.Rebirth: levels, coins, pads and towers start again; everything else stays."""
        self.rebirths += 1
        self.gain_gems(self.f["rebirth"]["gems"])
        self.coins, self.egg_wallet = 0.0, 0.0
        self.pads = [1]
        self.towers = {1: ["cannon", 1]}
        self.wave, self.cleared, self.auto = 1, 0, True
        self.failed_power, self.farm_runs = None, 0
        self.income, self.farm_income = 0.0, 1.0

    def step(self):
        """One level, then the shopping."""
        self.use_powerups()
        level = self.wave
        kind = self.model.plans[level]["kind"]
        cleared = self.play_level()
        self.pass_time(self.level_seconds)
        if self.trace > self.runs - 1:
            print("  %6.1f min  level %3d %-6s %-7s %5.1fs  +%-8s coins %-8s %s  x%.2f" % (
                self.real / 60, level, kind, "cleared" if cleared else "FAILED",
                self.level_seconds, short(self.income), short(self.coins),
                " ".join("%d:%s%d" % (pad, k[:2], lvl) for pad, (k, lvl) in sorted(self.towers.items())), self.power()))
        retry = False
        if cleared:
            first_ever = level > self.best
            self.cleared = max(self.cleared, level)
            if first_ever:
                self.best = level
                self.first_clear[level] = self.real
                self.snapshot(level)
                if level % self.f["milestoneEvery"] == 0:
                    self.gain_gems(self.f["milestoneGems"])
                self.story(level)
            if kind != "normal":
                self.boss_killed(level, kind, first_ever)
            if self.auto and level < M.TOTAL:
                self.wave = level + 1
            elif not self.auto:
                self.farm_runs += 1
        else:
            self.fails += 1
            # A level that beat the player: now is the time for Mega Damage or Deep Freeze, and one more try.
            retry = self.use_powerups(failed=True)
            if not retry:
                self.failed_power = self.strength()
                self.farm_runs = 0
                self.auto = False
                if level > 1:
                    self.wave = level - 1
        self.hatch()
        self.spend_gems()
        self.spend()
        if not self.auto and self.failed_power is not None:
            # Farming. Back to the wall once the towers are stronger, or after a long while regardless.
            if self.strength() >= self.failed_power * self.retry or self.farm_runs >= 25:
                self.auto = True
                self.farm_runs = 0
                if self.wave <= self.cleared and self.wave < M.TOTAL:
                    self.wave += 1
        if self.rebirths < self.rebirth_plan and self.cleared >= (self.rebirths + 1) * M.WAVES_PER_WORLD and self.cleared < M.TOTAL:
            self.rebirth()


def play(model, worlds, start=None, limit=600.0, **options):
    """Plays until the last level of world `worlds` is cleared, or for `limit` real hours of play.
    start: a player to carry on with (fit.py carries one from world to world)."""
    player = start or Player(model, **options)
    if start:
        player.attach(model)
    goal = worlds * M.WAVES_PER_WORLD
    while goal not in player.first_clear and player.real < limit * 3600:
        player.step()
    return player


FREE = dict()
PAYER = dict(passes=PASSES)  # every pass, and the Huge the hugeStarter pass gives


# ---------------------------------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------------------------------
def short(n):
    suffixes = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"]
    if n < 1000:
        return ("%.0f" % n) if n >= 100 or n == int(n) else ("%.1f" % n)
    tier = int(math.log10(n) // 3)
    if tier >= len(suffixes):
        return "%.2e" % n
    scaled = n / 10 ** (tier * 3)
    return ("%.0f" if scaled >= 100 else "%.1f" if scaled >= 10 else "%.2f") % scaled + suffixes[tier]


def clock(minutes):
    return "%d:%02d" % (minutes // 60, minutes % 60) if minutes >= 60 else "%.1f min" % minutes


def world_times(player, worlds):
    """Real minutes each world took, None for one that was not finished."""
    out, previous = [], 0.0
    for world in range(1, worlds + 1):
        snap = player.snapshots.get(world * M.WAVES_PER_WORLD)
        out.append(snap["minutes"] - previous if snap else None)
        previous = snap["minutes"] if snap else previous
    return out


def report(player, worlds, rows=None):
    snaps = player.snapshots
    print("Real time, at %dx from level %d on, %g hours a day." % (player.speed, player.speed_after, player.hours))
    print("level  kind    monsters  HP each  coins/level  pads  towers%s  played" % (" " * 38))
    levels = rows or sorted(set(
        [1, 3, 5, 10, 15, 20, 25, 30, 40, 50] + [w * 50 + l for w in range(1, worlds) for l in (10, 25, 50)]
    ))
    for level in levels:
        s = snaps.get(level)
        if not s:
            continue
        plan = s["plan"]
        print("%5d  %-6s  %8d  %7s  %11s  %4d  %-44s  %s" % (
            level, plan["kind"], plan["count"], short(plan["hp"]), short(plan["coins"] * plan["count"]), s["pads"],
            s["towers"][:44], clock(s["minutes"]),
        ))
    print()
    previous, before = 0.0, None
    for world in range(1, worlds + 1):
        s = snaps.get(world * 50)
        if not s:
            print("world %2d: not finished (stuck at level %d after %s)" % (world, max(snaps) + 1 if snaps else 1, clock(player.real / 60)))
            break
        took = s["minutes"] - previous
        runs = s["runs"] - (before["runs"] if before else 0)
        fails = s["fails"] - (before["fails"] if before else 0)
        print("world %2d: %7s  (total %7s, day %2d, power x%s, %4d runs, %3d failed, %d slots, attack %d, %d rebirths)" % (
            world, clock(took), clock(s["minutes"]), s["day"], short(s["power"]), runs, fails, s["slots"],
            s["tracks"].get("attack", 0), s["rebirths"]))
        previous, before = s["minutes"], s
    spent = player.spent
    total = sum(spent.values()) or 1
    print("coins spent: towers %.0f%%, pads %.0f%%, eggs %.0f%%, island shops %.0f%%; hatched %d eggs; veteran level %d" % (
        100 * spent["towers"] / total, 100 * spent["pads"] / total, 100 * spent["eggs"] / total, 100 * spent["shop"] / total,
        sum(player.hatched.values()), player.veteran()))
    print("gems: %d earned; spent %s; mastery %s" % (
        player.gems_earned, ", ".join("%s %d" % (k, v) for k, v in player.gems_spent.items()),
        ", ".join("%s %d" % (k, v) for k, v in sorted(player.mastery_levels.items())) or "none"))
    real = max(1.0, player.real)
    print("boosts running, as a share of the time played: %s" % (", ".join(
        "%s %.0f%%" % (k, 100 * v / real) for k, v in sorted(player.boost_time.items())) or "none"))
    print("ammo owned: %s" % (", ".join(sorted(player.ammo)) or "none"))


def one_line(label, player, worlds):
    times = world_times(player, worlds)
    ten = player.snapshots.get(10, {}).get("minutes", float("nan"))
    done = [t for t in times if t is not None]
    total = sum(done)
    stuck = "" if len(done) == worlds else "  STUCK in world %d" % (len(done) + 1)
    print("%-34s first ten %5.1f min | Earth %s | all %s%s | worlds: %s" % (
        label, ten, clock(done[0]) if done else "-", clock(total), stuck, " ".join(clock(t) for t in done)), flush=True)
    return total


def check(config, draft):
    problems = 0

    def differ(what, a, b):
        nonlocal problems
        if a is None and b is None:
            return
        if a is None or b is None or (isinstance(a, str) and a != b) or (not isinstance(a, str) and abs(a - b) > 1e-9 * max(1, abs(a), abs(b))):
            problems += 1
            if problems <= 25:
                print("  differs: %s: Config %r, draft %r" % (what, a, b))

    for level in range(1, M.TOTAL + 1):
        for key in ("kind", "count", "hp", "coins", "speed", "gap", "regen", "leak"):
            differ("level %d %s" % (level, key), config.plans[level].get(key), draft.plans[level].get(key))
        differ("level %d levelCoins" % level, config.level_coins[level], draft.level_coins[level])
    differ("tower kinds", ",".join(config.tower_order), ",".join(draft.tower_order))
    for kind in draft.tower_order:
        if kind not in config.towers:
            continue
        for key in ("cost", "damage", "rate", "range", "unlock", "splash", "slow", "slowSeconds", "burn", "burnSeconds", "chain", "boss"):
            differ("%s %s" % (kind, key), config.towers[kind].get(key), draft.towers[kind].get(key))
        for level in range(1, M.MAX_TOWER_LEVEL + 1):
            differ("%s damage L%d" % (kind, level), config.damage[kind][level], draft.damage[kind][level])
            differ("%s upgrade L%d" % (kind, level), config.upgrade[kind][level], draft.upgrade[kind][level])
    for count in range(1, len(draft.pads) + 1):
        differ("pad %d price" % count, config.pad_price[count], draft.pad_price[count])
    differ("coin eggs", len(config.eggs), len(draft.eggs))
    for a, b in zip(config.eggs, draft.eggs):
        differ("%s cost" % a["id"], a["cost"], b["cost"])
        differ("%s unlock" % a["id"], a["unlock"], b["unlock"])
        for index, (pa, pb) in enumerate(zip(a["pets"], b["pets"])):
            differ("%s pet %d chance" % (a["id"], index + 1), pa[0], pb[0])
            differ("%s pet %d bonus" % (a["id"], index + 1), pa[1], pb[1])
            differ("%s pet %d rarity" % (a["id"], index + 1), pa[2], pb[2])
            if pb[3]:
                differ("%s pet %d name" % (a["id"], index + 1), pa[3], pb[3])
    for key, value in draft.defense.items():
        differ("Defense.%s" % key, config.defense.get(key), value)
    for key, value in config.defense.items():
        differ("Defense.%s" % key, value, draft.defense.get(key))
    print("draft and Config.luau agree" if problems == 0 else "%d differences" % problems)
    return problems == 0


def options_of(args):
    passes = set(PASSES) if args.payer else set()
    for name in args.passes.split(",") if args.passes else []:
        passes.add(name)
    return dict(
        seed=args.seed, egg_share=0 if args.no_eggs else args.egg_share, egg_limit=args.egg_limit, presence=args.presence,
        speed=args.speed, speed_after=args.speed_after, hours=args.hours, passes=tuple(sorted(passes)),
        huges=tuple(h for h in args.huge.split(",") if h), rebirths=args.rebirths,
        off=tuple(SYSTEMS) if args.bare else tuple(s for s in args.off.split(",") if s), enchant=args.enchant,
    )


def _trial(args):
    draft, worlds, options = args
    model = M.draft() if draft else M.from_config()
    player = play(model, worlds, **options)
    done = [t for t in world_times(player, worlds) if t is not None]
    return dict(times=done, ten=player.snapshots.get(10, {}).get("minutes", float("nan")), finished=len(done) == worlds,
                fails=player.fails, runs=player.runs, gems=player.gems_earned, boosts=dict(player.boost_time), real=player.real)


def trials(draft, worlds, cases, seeds=(1, 2, 3)):
    """Plays every case (a label and the player's options) with a few seeds, all at once. Returns, per case,
    the average real minutes each world took (only the worlds every seed finished)."""
    from concurrent.futures import ProcessPoolExecutor

    jobs = [(draft, worlds, dict(options, seed=seed)) for _, options in cases for seed in seeds]
    with ProcessPoolExecutor() as pool:
        results = list(pool.map(_trial, jobs))
    out = []
    for index, (label, _) in enumerate(cases):
        runs = results[index * len(seeds):(index + 1) * len(seeds)]
        count = min(len(run["times"]) for run in runs)
        times = [sum(run["times"][world] for run in runs) / len(runs) for world in range(count)]
        out.append(dict(label=label, times=times, total=sum(times), finished=count == worlds,
                        ten=sum(run["ten"] for run in runs) / len(runs), spread=[sum(run["times"][:count]) for run in runs],
                        fails=sum(run["fails"] for run in runs) / len(runs), runs=sum(run["runs"] for run in runs) / len(runs)))
    return out


def show(result, base=None, faster=True):
    line = "%-30s first ten %5.1f min | Earth %7s | all %7s%s" % (
        result["label"], result["ten"], clock(result["times"][0]) if result["times"] else "-", clock(result["total"]),
        "" if result["finished"] else " (STUCK in world %d)" % (len(result["times"]) + 1))
    if base and result["finished"]:
        line += " | %.2fx as %s" % ((base["total"] / result["total"]) if faster else (result["total"] / base["total"]), "fast" if faster else "long")
    print(line + " | " + " ".join(clock(t) for t in result["times"]), flush=True)


def contributions(draft, worlds, options):
    """What each system, each habit and each pass is worth: the same player without it, or with it."""
    cases = [("the free player", options)]
    for system in SYSTEMS:
        cases.append(("without %s" % system, dict(options, off=tuple(set(options["off"]) | {system}))))
    cases.append(("the fight and the eggs only", dict(options, off=SYSTEMS)))
    for speed in (1, 2):
        cases.append(("at %dx game speed" % speed, dict(options, speed=speed)))
    for hours in (1, 4):
        cases.append(("%d hours a day" % hours, dict(options, hours=hours)))
    for share in (0.1, 0.35, 0.5):
        cases.append(("%d%% of the coins on eggs" % (share * 100), dict(options, egg_share=share)))
    for limit in (50, 450):
        cases.append(("%d hatches of each egg" % limit, dict(options, egg_limit=limit)))
    cases.append(("never near the monsters", dict(options, presence=0)))
    for count in (0, 2, 3):
        cases.append(("%d rebirths" % count, dict(options, rebirths=count)))
    for name in PASSES:
        cases.append(("with the %s pass" % name, dict(options, passes=tuple(set(options["passes"]) | {name}))))
    cases.append(("every pass and the Huge", dict(options, passes=PASSES)))
    for huge in ("hugestorm", "hugeslayer", "hugeexecutioner"):
        cases.append(("with %s, hatched" % huge, dict(options, huges=(huge,))))
    results = trials(draft, worlds, cases)
    base = results[0]
    for result in results:
        slower = result["label"].startswith(("without", "the fight", "at ", "never"))
        show(result, None if result is base else base, faster=not slower)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--worlds", type=int, default=12)
    parser.add_argument("--draft", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--no-eggs", action="store_true")
    parser.add_argument("--egg-share", type=float, default=0.2)
    parser.add_argument("--egg-limit", type=int, default=150, help="hatches of each egg before the player has had enough")
    parser.add_argument("--presence", type=float, default=0.7)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--speed", type=int, default=3, help="the game speed the player uses (1 to 3)")
    parser.add_argument("--speed-after", type=int, default=10, help="the level from which they use it")
    parser.add_argument("--hours", type=float, default=2.0, help="real hours of play a day")
    parser.add_argument("--payer", action="store_true", help="every pass, and the Huge the hugeStarter pass gives")
    parser.add_argument("--passes", default="", help="passes owned, by key: " + ",".join(PASSES))
    parser.add_argument("--huge", default="", help="Huges owned, by id: hugestorm,hugeslayer ...")
    parser.add_argument("--rebirths", type=int, default=1, help="rebirths the player takes, each as soon as it is allowed")
    parser.add_argument("--off", default="", help="systems the player ignores: " + ",".join(SYSTEMS))
    parser.add_argument("--bare", action="store_true", help="the fight and the eggs only: every system off")
    parser.add_argument("--enchant", type=float, default=1.0, help="what enchantments multiply tower damage by (none are built)")
    parser.add_argument("--contributions", action="store_true", help="what each system and each pass is worth")
    parser.add_argument("--seeds", type=int, default=0, help="one line per seed, 1 to N, instead of the full report")
    parser.add_argument("--trace", type=int, default=0, help="print the first N levels played")
    args = parser.parse_args()

    if args.check:
        sys.exit(0 if check(M.from_config(), M.draft()) else 1)
    model = M.draft() if args.draft else M.from_config()
    options = options_of(args)
    if args.contributions:
        contributions(args.draft, args.worlds, options)
        return
    if args.seeds:
        result = trials(args.draft, args.worlds, [("seeds 1 to %d" % args.seeds, options)], tuple(range(1, args.seeds + 1)))[0]
        show(result)
        print("each seed: %s" % " ".join(clock(t) for t in result["spread"]))
        return
    player = play(model, args.worlds, trace=args.trace, **options)
    report(player, args.worlds)


if __name__ == "__main__":
    main()
