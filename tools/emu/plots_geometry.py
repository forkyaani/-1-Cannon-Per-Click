#!/usr/bin/env python3
"""Geometry check for the plots (src/server/Plots.luau) and the models (src/shared/Models.luau).

The emulator's CFrame keeps no rotation, so run.py cannot tell whether a tower stands on its pad. This script
gives the emulator a real CFrame (position and rotation), builds the plots with the real Luau, and then
measures the parts:

  * nothing stands on the path or on a pad, in any of the twelve world themes
  * every part of a base is inside its own base and surround
  * every base is private: no two bases are within Layout.PLOT_APART (1,500 studs or more) of each other, and
    none is that close to the marketplace, an island or the lobby
  * every base is closed off (ground and yard, a skyline higher than a jump, an unseen wall on all four sides)
    and has its two teleporters within 15 studs of the arrival, clear of the path and of every pad
  * towers stand on their pads, fit them whichever way the turret is turned, and aim where they are told
  * monsters stand on the ground, facing -Z, with the pivot under them
  * the spawn point, the gate, the plaza and the yard are free of anything that collides
  * part counts: per plot, per tower kind, per monster

Usage: python3 tools/emu/plots_geometry.py [--src DIR]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import roblox_emu as R  # noqa: E402
from luau_emu import LuaError, LuaTable  # noqa: E402

Vector3 = R.Vector3
IDENTITY = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


# ---------------------------------------------------------------------------------------------------
# A CFrame with rotation, patched over the emulator's position-only one
# ---------------------------------------------------------------------------------------------------
def mat_mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mat_vec(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


def transpose(m):
    return tuple(tuple(m[j][i] for j in range(3)) for i in range(3))


def column(m, j):
    return (m[0][j], m[1][j], m[2][j])


def from_columns(x, y, z):
    return tuple((x[i], y[i], z[i]) for i in range(3))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(v):
    m = math.sqrt(sum(x * x for x in v))
    if m < 1e-9:
        raise LuaError("CFrame.lookAt: the two points are the same, or the direction is straight up or down")
    return tuple(x / m for x in v)


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def cf(pos=(0, 0, 0), rot=IDENTITY):
    return R.CFrame(Vector3(*pos), rot)


def cf_init(self, pos=None, rot=None):
    self.pos = pos or Vector3(0, 0, 0)
    self.rot = rot or IDENTITY


def cf_inverse(a):
    t = transpose(a.rot)
    return cf(tuple(-x for x in mat_vec(t, a.pos.v)), t)


def cf_mul(a, b):
    moved = mat_vec(a.rot, b.pos.v)
    return cf(tuple(p + q for p, q in zip(a.pos.v, moved)), mat_mul(a.rot, b.rot))


def cf_point(a, v):
    return Vector3(*(p + q for p, q in zip(a.pos.v, mat_vec(a.rot, v.v))))


def cf_get(self, k):
    if k in ("Position", "p"):
        return self.pos
    if k in ("X", "Y", "Z"):
        return self.pos.lua_get(k)
    if k == "LookVector":
        return Vector3(*(-x for x in column(self.rot, 2)))
    if k == "RightVector":
        return Vector3(*column(self.rot, 0))
    if k == "UpVector":
        return Vector3(*column(self.rot, 1))
    if k == "Rotation":
        return cf((0, 0, 0), self.rot)
    if k == "Lerp":
        return lambda a, b, t: b
    if k == "Inverse":
        return cf_inverse
    if k == "ToWorldSpace":
        return cf_mul
    if k == "ToObjectSpace":
        return lambda a, b: cf_mul(cf_inverse(a), b)
    if k == "VectorToWorldSpace":
        return lambda a, v: Vector3(*mat_vec(a.rot, v.v))
    if k == "VectorToObjectSpace":
        return lambda a, v: Vector3(*mat_vec(transpose(a.rot), v.v))
    if k == "PointToWorldSpace":
        return cf_point
    if k == "PointToObjectSpace":
        return lambda a, v: cf_point(cf_inverse(a), v)
    raise LuaError(f"{k} is not a valid member of CFrame")


def cf_arith(self, op, a, b):
    if isinstance(a, R.CFrame) and isinstance(b, R.CFrame) and op == "*":
        return cf_mul(a, b)
    if isinstance(a, R.CFrame) and isinstance(b, Vector3):
        if op == "*":
            return cf_point(a, b)
        if op in ("+", "-"):
            return R.CFrame(a.pos.lua_arith(op, a.pos, b), a.rot)
    raise LuaError(f"attempt to perform arithmetic ({op}) on {R.typename(a)} and {R.typename(b)}")


def cf_eq(self, other):
    if not isinstance(other, R.CFrame):
        return False
    return all(abs(p - q) < 1e-9 for p, q in zip(self.pos.v, other.pos.v)) and all(
        abs(self.rot[i][j] - other.rot[i][j]) < 1e-9 for i in range(3) for j in range(3)
    )


def look_at(at, target, up=None):
    back = unit(tuple(p - q for p, q in zip(at.v, target.v)))
    right = unit(cross(up.v if up else (0, 1, 0), back))
    return R.CFrame(at, from_columns(right, cross(back, right), back))


def cf_new(*a):
    if not a:
        return cf()
    if isinstance(a[0], Vector3):
        return look_at(a[0], a[1]) if len(a) > 1 else R.CFrame(a[0])
    if len(a) == 3:
        return cf(a)
    if len(a) == 12:
        return cf(a[:3], (tuple(a[3:6]), tuple(a[6:9]), tuple(a[9:12])))
    raise LuaError(f"CFrame.new: {len(a)} arguments are not emulated")


def install_cframe(world):
    R.CFrame.__init__ = cf_init
    R.CFrame.lua_get = cf_get
    R.CFrame.lua_arith = cf_arith
    R.CFrame.lua_eq = cf_eq
    R.CFrame.__str__ = lambda self: f"CFrame({self.pos})"
    world.interp.globals.vars["CFrame"] = R.lib({
        "new": cf_new,
        "lookAt": look_at,
        "Angles": lambda x=0, y=0, z=0: cf((0, 0, 0), mat_mul(mat_mul(rot_x(x), rot_y(y)), rot_z(z))),
        "fromEulerAnglesXYZ": lambda x=0, y=0, z=0: cf((0, 0, 0), mat_mul(mat_mul(rot_x(x), rot_y(y)), rot_z(z))),
        "fromOrientation": lambda x=0, y=0, z=0: cf((0, 0, 0), mat_mul(mat_mul(rot_y(y), rot_x(x)), rot_z(z))),
        "identity": cf(),
    })

    # A part's Position and CFrame are one thing.
    plain_set = R.Instance.lua_set

    def lua_set(self, k, v):
        if self.is_a("BasePart"):
            if k == "CFrame":
                if not isinstance(v, R.CFrame):
                    raise LuaError(f"invalid value for CFrame ({R.typename(v)})")
                self.props["Position"] = v.pos
            elif k == "Position":
                if not isinstance(v, Vector3):
                    raise LuaError(f"invalid value for Position ({R.typename(v)})")
                old = self.props.get("CFrame")
                self.props["CFrame"] = R.CFrame(v, old.rot if old else IDENTITY)
            elif k == "PivotOffset" and not isinstance(v, R.CFrame):
                raise LuaError(f"invalid value for PivotOffset ({R.typename(v)})")
        plain_set(self, k, v)

    R.Instance.lua_set = lua_set
    world.known_props.update({"PivotOffset", "CFrame", "Position", "Size"})
    world.methods["*"]["GetPivot"] = get_pivot
    world.methods["*"]["PivotTo"] = pivot_to


def part_cframe(part):
    return part.props.get("CFrame") or cf()


def parts_under(inst, include_self=True):
    out = [inst] if include_self and inst.is_a("BasePart") else []
    for child in inst.children:
        out.extend(parts_under(child))
    return out


def get_pivot(inst):
    if inst.is_a("BasePart"):
        offset = inst.props.get("PivotOffset")
        return cf_mul(part_cframe(inst), offset) if offset else part_cframe(inst)
    primary = inst.props.get("PrimaryPart")
    if primary is not None:
        return get_pivot(primary)
    stored = inst.props.get("WorldPivot")
    if stored is not None:
        return stored
    raise LuaError(f"GetPivot on {inst.full_name()}: a model without a PrimaryPart is not emulated")


def pivot_to(inst, target):
    if not isinstance(target, R.CFrame):
        raise LuaError(f"PivotTo: CFrame expected, got {R.typename(target)}")
    delta = cf_mul(target, cf_inverse(get_pivot(inst)))
    for part in parts_under(inst):
        moved = cf_mul(delta, part_cframe(part))
        part.props["CFrame"] = moved
        part.props["Position"] = moved.pos


# ---------------------------------------------------------------------------------------------------
# Measuring parts
# ---------------------------------------------------------------------------------------------------
def shape_of(part):
    shape = part.props.get("Shape")
    return shape.name if shape is not None else "Block"


def samples(part):
    """Points on the part's surface, in the world: enough to bound it tightly."""
    size = part.props["Size"].v
    frame = part_cframe(part)
    local = []
    shape = shape_of(part)
    if shape == "Ball":
        r = min(size) / 2
        for i in range(-2, 3):
            lat = i * math.pi / 4
            ring = 1 if abs(i) == 2 else 12
            for j in range(ring):
                lon = j * 2 * math.pi / ring
                local.append((r * math.cos(lat) * math.cos(lon), r * math.sin(lat), r * math.cos(lat) * math.sin(lon)))
    elif shape == "Cylinder":
        r = min(size[1], size[2]) / 2
        for end in (-1, 1):
            for j in range(24):
                a = j * 2 * math.pi / 24
                local.append((end * size[0] / 2, r * math.cos(a), r * math.sin(a)))
    else:
        for x in (-1, 1):
            for y in (-1, 1):
                for z in (-1, 1):
                    local.append((x * size[0] / 2, y * size[1] / 2, z * size[2] / 2))
    return [cf_point(frame, Vector3(*p)).v for p in local]


def hull(points):
    """Convex hull of 2D points, counter-clockwise."""
    pts = sorted(set((round(x, 6), round(z, 6)) for x, z in points))
    if len(pts) <= 2:
        return pts

    def turn(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and turn(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and turn(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def point_segment(p, a, b):
    ax, az = b[0] - a[0], b[1] - a[1]
    length = ax * ax + az * az
    t = 0 if length == 0 else max(0, min(1, ((p[0] - a[0]) * ax + (p[1] - a[1]) * az) / length))
    return math.hypot(p[0] - a[0] - t * ax, p[1] - a[1] - t * az)


def inside(p, poly):
    sign = 0
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        c = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        if abs(c) < 1e-9:
            continue
        if sign == 0:
            sign = 1 if c > 0 else -1
        elif (c > 0) != (sign > 0):
            return False
    return True


def segments_cross(a, b, c, d):
    def side(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])

    return side(a, b, c) * side(a, b, d) < 0 and side(c, d, a) * side(c, d, b) < 0


def gap(poly_a, poly_b):
    """Distance between two convex polygons; 0 when they touch or overlap (by more than a hair)."""
    if len(poly_a) >= 3 and any(inside(p, poly_a) for p in poly_b):
        return 0.0
    if len(poly_b) >= 3 and any(inside(p, poly_b) for p in poly_a):
        return 0.0
    best = math.inf
    for i in range(len(poly_a)):
        a, b = poly_a[i], poly_a[(i + 1) % len(poly_a)]
        for j in range(len(poly_b)):
            c, d = poly_b[j], poly_b[(j + 1) % len(poly_b)]
            if segments_cross(a, b, c, d):
                return 0.0
            best = min(best, point_segment(a, c, d), point_segment(b, c, d), point_segment(c, a, b), point_segment(d, a, b))
    return best


def rectangle(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


class Shape:
    """A part measured in some frame: its footprint on the ground and how high it reaches."""

    def __init__(self, part, frame=None):
        pts = samples(part)
        if frame is not None:
            inverse = cf_inverse(frame)
            pts = [cf_point(inverse, Vector3(*p)).v for p in pts]
        self.part = part
        self.points = pts
        self.footprint = hull([(p[0], p[2]) for p in pts])
        self.low = min(p[1] for p in pts)
        self.high = max(p[1] for p in pts)
        self.name = part.props["Name"]
        self.collides = part.props.get("CanCollide", True) is not False

    def where(self):
        xs = [p[0] for p in self.footprint]
        zs = [p[1] for p in self.footprint]
        return f"{self.name} x {min(xs):.1f}..{max(xs):.1f} z {min(zs):.1f}..{max(zs):.1f} y {self.low:.1f}..{self.high:.1f}"


# ---------------------------------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------------------------------
DRIVER = r"""
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Models = require(ReplicatedStorage.Shared.Models)
local Plots = require(Server.Plots)

local T = { Config = Config, Layout = Layout, Models = Models, Plots = Plots }
T.frames, T.spawns, T.path, T.pads, T.padWorld = {}, {}, {}, {}, {}
for slot = 1, Layout.PLOT_COUNT do
	T.frames[slot] = Layout.plotCFrame(slot)
	T.spawns[slot] = Layout.plotSpawn(slot)
	T.padWorld[slot] = {}
	for pad = 1, Layout.PAD_COUNT do
		T.padWorld[slot][pad] = Layout.padPosition(slot, pad)
	end
end
for _, point in Layout.PATH do
	table.insert(T.path, point.X)
	table.insert(T.path, point.Y)
end
for _, point in Layout.PADS do
	table.insert(T.pads, point.X)
	table.insert(T.pads, point.Y)
end
T.pathWidth, T.padSize, T.worlds, T.tiers = Layout.PATH_WIDTH, Layout.PAD_SIZE, #Config.Worlds, #Config.Cannons
T.pathLength = Layout.PATH_LENGTH
-- What a base must be far from: the marketplace, every island, the lobby. { x, z, radius }
T.apart, T.yard, T.fall = Layout.PLOT_APART, Layout.PLOT_YARD, Layout.FALL_HEIGHT
T.others = {}
local function other(name, position, radius)
	table.insert(T.others, name)
	table.insert(T.others, position.X)
	table.insert(T.others, position.Z)
	table.insert(T.others, radius)
end
other("the marketplace", Layout.MARKET_CENTER, Layout.MARKET_SIZE)
for index = 1, Layout.ISLAND_COUNT do
	other("island " .. index, Layout.islandCFrame(index).Position, Layout.ISLAND_RADIUS)
end
other("the lobby", Layout.LOBBY, 16)
T.teleporters = {}
for _, kind in { "worlds", "market" } do
	table.insert(T.teleporters, Layout.TELEPORTERS[kind].X)
	table.insert(T.teleporters, Layout.TELEPORTERS[kind].Y)
end

function T.monsterDef(shape, kind, scale)
	return { name = "Test", shape = shape, color = Color3.new(1, 0, 0), accent = Color3.new(0, 0, 1), kind = kind, scale = scale }
end

-- Turns a tower's turret towards a point, the way the spec tells the client to.
function T.aim(tower, target)
	local turret = tower:FindFirstChild("Turret")
	local pivot = turret:GetPivot().Position
	turret:PivotTo(CFrame.lookAt(pivot, Vector3.new(target.X, pivot.Y, target.Z)))
end

function T.walk(model, slot, distance)
	local point, direction = Layout.pathAt(distance)
	local position = Layout.plotPoint(slot, point)
	local ahead = Layout.plotCFrame(slot):VectorToWorldSpace(Vector3.new(direction.X, 0, direction.Y))
	model:PivotTo(CFrame.lookAt(position, position + ahead))
	return position, ahead
end

return T
"""

KINDS = ["cannon", "gatling", "mortar", "sniper", "frost", "flame", "tesla", "somethingnew"]
LEVELS = [1, 11, 25, 41, 61, 95, 150, 295, 445, 600, 5000]
SHAPES = ["blob", "biped", "floater", "crawler", "jelly", "spiker", "unknownshape"]
FLAT = {"Ground", "Yard", "Road", "Kerb"}
LIGHT = {"Gate", "Portal"}  # only light: monsters and players pass through them

failures = []
notes = []


def check(ok, what):
    if not ok:
        failures.append(what)
        print("  FAIL: " + what)
    return ok


def seq(table):
    if table.arr:
        return list(table.arr)
    return [table.hash[i] for i in range(1, len(table.hash) + 1)]


def make_world(src):
    world = R.World()
    trusted = [
        "client/UI.luau", "client/Hud.luau", "client/Windows.luau", "client/Effects.luau", "client/Market.luau",
        "server/Game.luau", "server/Plots.luau", "server/Build.luau", "server/Marketplace.luau",
    ]
    world.harvest_props([os.path.join(src, p) for p in trusted if os.path.exists(os.path.join(src, p))])
    world.load_dir(os.path.join(src, "shared"), "Shared", set()).set_parent(world.service("ReplicatedStorage"))
    world.load_dir(os.path.join(src, "server"), "Server", set()).set_parent(world.service("ServerScriptService"))
    world.service("Workspace")
    install_cframe(world)
    return world


def main():
    src = os.path.normpath(os.path.join(HERE, "..", "..", "src"))
    if "--src" in sys.argv:
        src = sys.argv[sys.argv.index("--src") + 1]
    world = make_world(src)
    interp = world.interp
    workspace = world.service("Workspace")

    def call(fn, *args):
        result = interp.call(fn, list(args))
        interp.flush()
        return result[0] if result else None

    T = interp.run(DRIVER, "driver", {})[0]
    get = T.hash.get
    Plots, Models = get("Plots").hash, get("Models").hash
    frames, spawns = seq(get("frames")), seq(get("spawns"))
    flat = seq(get("path"))
    path = [(flat[i], flat[i + 1]) for i in range(0, len(flat), 2)]
    flat = seq(get("pads"))
    pads = [(flat[i], flat[i + 1]) for i in range(0, len(flat), 2)]
    half_path, half_pad = get("pathWidth") / 2, get("padSize") / 2
    worlds = get("worlds")
    slots = len(frames)

    # The corridor the monsters walk: every stretch of the path, PATH_WIDTH wide, running on over its corners.
    corridor = []
    for a, b in zip(path, path[1:]):
        x0, x1 = min(a[0], b[0]) - half_path, max(a[0], b[0]) + half_path
        z0, z1 = min(a[1], b[1]) - half_path, max(a[1], b[1]) + half_path
        corridor.append(rectangle(x0, z0, x1, z1))
    pad_squares = [rectangle(x - half_pad, z - half_pad, x + half_pad, z + half_pad) for x, z in pads]

    print("== build")
    call(Plots["build"])
    check(interp.errors == [] or len(interp.errors) == 0, "Plots.build ran without errors")
    root = workspace.child("Plots")
    check(root is not None and root.cls == "Folder", "workspace.Plots exists")
    check(workspace.child("Cannons") is not None, "workspace.Cannons exists (mini cannons)")
    check(root.child("Street") is None, "there is no street any more")
    lobby = root.child("Lobby")
    check(lobby is not None and any(c.cls == "SpawnLocation" for c in lobby.children), "workspace.Plots.Lobby holds the SpawnLocation")
    print(f"  lobby: {len(parts_under(lobby))} parts")
    yard = get("yard")
    # A base with its surround: the ground, the yard behind it and the skyline around both.
    X_OUT, Z_BACK, Z_FRONT = 58.01, -yard - 3.01, 153.01

    def plot_folder(slot):
        return root.child(f"Plot_{slot}")

    def to_path(shape):
        return min(gap(shape.footprint, rect) for rect in corridor)

    def measure(slot, label, strict_inside=True):
        """Every static check on one plot, as it stands now."""
        folder = plot_folder(slot)
        frame = frames[slot - 1]
        shapes = [Shape(part, frame) for part in parts_under(folder)]
        nearest = (math.inf, None)
        for shape in shapes:
            above = ancestors(shape.part)
            under_pad = any(a.props["Name"].startswith("Pad_") for a in above)
            in_tower = any(a.props["Name"] == "Towers" for a in above)
            in_decor = any(a.props["Name"] == "Decor" for a in above)
            # Inside the base and its surround: nothing sticks out of it.
            xs = [p[0] for p in shape.footprint]
            zs = [p[1] for p in shape.footprint]
            if strict_inside:
                check(min(xs) >= -X_OUT and max(xs) <= X_OUT and min(zs) >= Z_BACK and max(zs) <= Z_FRONT,
                      f"{label}: inside the plot: {shape.where()}")
            # The path: only the road itself, light, and what is above the gate's height may be over it.
            if shape.name not in FLAT and shape.name not in LIGHT and shape.low < 13.9 and shape.name != "Plaza":
                distance = to_path(shape)
                check(distance > 0.05, f"{label}: clear of the path: {shape.where()}")
                if in_decor and distance < nearest[0]:
                    nearest = (distance, shape.name)
            # The pads: nothing but the pad, what stands on it by design, and the tower.
            if not (shape.name.startswith("Pad_") or under_pad or in_tower or shape.name in FLAT):
                for index, square in enumerate(pad_squares):
                    if shape.low < 14 and gap(shape.footprint, square) <= 0.0:
                        check(False, f"{label}: on pad {index + 1}: {shape.where()}")
        return shapes, nearest

    def ancestors(inst):
        out = []
        node = inst.parent
        while node is not None:
            out.append(node)
            node = node.parent
        return out

    print("== empty plots (nobody owns them)")
    counts = set()
    for slot in range(1, slots + 1):
        folder = plot_folder(slot)
        check(folder is not None and folder.attrs.get("Slot") == slot and folder.attrs.get("Owner") == 0, f"Plot_{slot} with Slot and Owner")
        shapes, nearest = measure(slot, f"plot {slot}")
        counts.add(len(shapes))
        for name in ("Gate", "Portal", "Pads", "Towers"):
            check(folder.child(name) is not None, f"Plot_{slot}.{name} exists")
        check(len(folder.child("Pads").children) == len(pads), f"Plot_{slot} has {len(pads)} pads")
    print(f"  parts per empty plot: {sorted(counts)}; nearest prop to the path: {nearest[1]} at {nearest[0]:.2f} studs")

    print("== pads, gate and portal are where Layout says, on every base")
    pad_world = seq(get("padWorld"))
    for slot in range(1, slots + 1):
        folder, frame = plot_folder(slot), frames[slot - 1]
        for index in range(len(pads)):
            pad = folder.child("Pads").child(f"Pad_{index + 1}")
            want = seq(pad_world[slot - 1])[index].v
            have = part_cframe(pad).pos.v
            size = pad.props["Size"].v
            check(abs(have[0] - want[0]) < 1e-6 and abs(have[2] - want[2]) < 1e-6 and abs(have[1] - size[1] / 2) < 1e-6,
                  f"plot {slot} pad {index + 1} is at Layout.padPosition")
            check(pad.attrs.get("Pad") == index + 1 and pad.attrs.get("Slot") == slot and pad.attrs.get("Owned") is False,
                  f"plot {slot} pad {index + 1} attributes")
            prompt = next((c for c in pad.children if c.cls == "ProximityPrompt"), None)
            check(prompt is not None and prompt.attrs.get("Pad") == index + 1 and prompt.attrs.get("Slot") == slot,
                  f"plot {slot} pad {index + 1} prompt attributes")
            square = Shape(pad, frame)
            check(min(gap(square.footprint, rect) for rect in corridor) > 1, f"plot {slot} pad {index + 1} is clear of the path")
        gate = cf_point(cf_inverse(frame), part_cframe(folder.child("Gate")).pos).v
        portal = cf_point(cf_inverse(frame), part_cframe(folder.child("Portal")).pos).v
        check(abs(gate[0] - path[-1][0]) < 1e-6 and abs(gate[2] - path[-1][1]) < 1e-6, f"plot {slot} gate at the path's end")
        check(abs(portal[0] - path[0][0]) < 1e-6 and 0 <= portal[2] - path[0][1] <= 3, f"plot {slot} portal at the path's start")
        world_gate = part_cframe(folder.child("Gate")).pos.v
        world_portal = part_cframe(folder.child("Portal")).pos.v
        check(world_gate[2] < world_portal[2] and abs(world_gate[0] - world_portal[0]) < 1e-6, f"plot {slot} runs towards +Z: no base is turned")

    print("== every base is private: far from every other base, the marketplace, the islands and the lobby")
    apart = get("apart")
    check(apart >= 1500, f"Layout.PLOT_APART is at least 1,500 ({apart:.0f})")
    boxes = []
    for slot in range(1, slots + 1):
        pts = [p for part in parts_under(plot_folder(slot)) for p in samples(part)]
        xs, zs = [p[0] for p in pts], [p[2] for p in pts]
        boxes.append((min(xs), max(xs), min(zs), max(zs)))

    def box_gap(a, b):
        dx = max(a[0] - b[1], b[0] - a[1], 0)
        dz = max(a[2] - b[3], b[2] - a[3], 0)
        return math.hypot(dx, dz)

    nearest_base = math.inf
    for i in range(slots):
        for j in range(i + 1, slots):
            distance = box_gap(boxes[i], boxes[j])
            nearest_base = min(nearest_base, distance)
            check(distance >= apart, f"bases {i + 1} and {j + 1} are {distance:.0f} studs apart (edge to edge)")
    flat_others = seq(get("others"))
    nearest_other = (math.inf, None)
    for index in range(0, len(flat_others), 4):
        name, x, z, radius = flat_others[index:index + 4]
        for slot in range(1, slots + 1):
            distance = box_gap(boxes[slot - 1], (x - radius, x + radius, z - radius, z + radius))
            if distance < nearest_other[0]:
                nearest_other = (distance, f"base {slot} and {name}")
            check(distance >= apart, f"base {slot} is {distance:.0f} studs from {name}")
    print(f"  nearest two bases: {nearest_base:.0f} studs apart; nearest anything else: {nearest_other[1]}, {nearest_other[0]:.0f} studs")

    print("== every base is closed off, with a teleporter to the islands and one to the marketplace beside the arrival")
    flat_t = seq(get("teleporters"))
    spots = {"worlds": (flat_t[0], flat_t[1]), "market": (flat_t[2], flat_t[3])}
    prompt_tables = {"worlds": get("Plots").hash.get("worldsPrompts"), "market": get("Plots").hash.get("marketPrompts")}
    for slot in range(1, slots + 1):
        folder, frame = plot_folder(slot), frames[slot - 1]
        shapes = [Shape(part, frame) for part in parts_under(folder)]
        solid = [s for s in shapes if s.collides]
        # The floor: the whole inside of the surround is ground.
        floor = [s for s in solid if s.name in ("Ground", "Yard")]
        fx = [p[0] for s in floor for p in s.footprint]
        fz = [p[1] for s in floor for p in s.footprint]
        check(len(floor) == 2 and min(fx) <= -55 and max(fx) >= 55 and min(fz) <= -yard and max(fz) >= 150
              and all(abs(s.high) < 1e-6 for s in floor), f"base {slot}: ground and yard, from the back of the yard to the backdrop")
        # The walls: on all four sides something solid, higher than any jump, with no gap in it.
        barriers = [s for s in solid if s.name == "Barrier"]
        check(len(barriers) == 4 and all(s.high >= 100 and s.low <= 0 for s in barriers), f"base {slot}: four unseen walls, far higher than a jump")
        check(all(s.part.props.get("Transparency") == 1 and s.part.props.get("CanQuery") is False for s in barriers), f"base {slot}: the unseen walls are unseen, and the camera passes them")
        sides = {
            "left": lambda s: max(p[0] for p in s.footprint) <= -54.9, "right": lambda s: min(p[0] for p in s.footprint) >= 54.9,
            "back": lambda s: max(p[1] for p in s.footprint) <= -yard + 0.1, "front": lambda s: min(p[1] for p in s.footprint) >= 149.9,
        }
        for side, on_side in sides.items():
            wall = [s for s in barriers if on_side(s)]
            if not check(len(wall) >= 1, f"base {slot}: an unseen wall on the {side}"):
                continue
            along = 1 if side in ("left", "right") else 0
            low = min(p[along] for s in wall for p in s.footprint)
            high = max(p[along] for s in wall for p in s.footprint)
            want = (-yard, 150) if along == 1 else (-55, 55)
            check(low <= want[0] + 1e-6 and high >= want[1] - 1e-6, f"base {slot}: the {side} wall runs the whole side ({low:.0f}..{high:.0f})")
        skyline = [s for s in solid if s.name in ("Surround", "Backdrop")]
        check(len(skyline) >= 20 and min(s.high for s in skyline) >= 10, f"base {slot}: the skyline around it is higher than a jump everywhere (lowest {min(s.high for s in skyline):.0f})")
        check(get("fall") < min(s.low for s in solid) - 10, f"base {slot}: the safety net is below everything")
        # The teleporters.
        spawn = cf_point(cf_inverse(frame), spawns[slot - 1].pos).v
        holder = folder.child("Teleporters")
        check(holder is not None, f"base {slot}: Teleporters folder")
        for kind, spot in spots.items():
            table_ = prompt_tables[kind]
            prompt = table_.hash.get(slot) if table_ is not None else None
            if prompt is None and table_ is not None and table_.arr:
                prompt = table_.arr[slot - 1] if slot - 1 < len(table_.arr) else None
            if not check(prompt is not None and prompt.cls == "ProximityPrompt", f"base {slot}: Plots.{kind}Prompts[{slot}]"):
                continue
            check(prompt.attrs.get("Slot") == slot and prompt.attrs.get("Teleporter") == kind and prompt.attrs.get("Window") is None,
                  f"base {slot}: the {kind} teleporter's prompt carries Slot and Teleporter, and opens nothing by itself")
            beam = prompt.parent
            at = cf_point(cf_inverse(frame), part_cframe(beam).pos).v
            check(abs(at[0] - spot[0]) < 1e-6 and abs(at[2] - spot[1]) < 1e-6, f"base {slot}: the {kind} teleporter stands at Layout.TELEPORTERS")
            walk = math.hypot(at[0] - spawn[0], at[2] - spawn[2])
            check(walk <= 15, f"base {slot}: the {kind} teleporter is {walk:.1f} studs from the arrival")
            check(prompt.props.get("MaxActivationDistance", 10) < walk, f"base {slot}: the {kind} prompt is not in the arriving player's face")
            check(beam.parent is holder and beam.props.get("CanCollide") is False, f"base {slot}: the {kind} teleporter is only light")
        for shape in (Shape(part, frame) for part in parts_under(holder)):
            check(to_path(shape) > 3, f"base {slot}: {shape.where()} is clear of the path")
            check(all(gap(shape.footprint, square) > 1 for square in pad_squares), f"base {slot}: {shape.where()} is clear of every pad")
        two = [prompt_tables[k].hash.get(slot) or (prompt_tables[k].arr[slot - 1] if prompt_tables[k].arr else None) for k in spots]
        if all(two):
            a, b = part_cframe(two[0].parent).pos.v, part_cframe(two[1].parent).pos.v
            check(math.hypot(a[0] - b[0], a[2] - b[2]) > 16, f"base {slot}: the two teleporters are apart")
    solid_lobby = [Shape(p) for p in parts_under(lobby) if p.props.get("CanCollide", True) is not False and p.cls != "SpawnLocation"]
    check(sum(1 for s in solid_lobby if s.name == "Barrier") == 8 and any(s.name == "LobbyFloor" for s in solid_lobby), "the lobby is a closed room")

    print("== every world theme")
    for index in range(1, worlds + 1):
        for slot in (2, 9):
            call(Plots["setWorld"], slot, index)
            shapes, nearest = measure(slot, f"world {index} plot {slot}")
            decor = plot_folder(slot).child("Decor")
            if slot == 2:
                print(f"  world {index:2}: {len(shapes)} parts on the plot, {len(parts_under(decor))} of them props; nearest prop to the path: {nearest[1]} at {nearest[0]:.1f}")
    call(Plots["setWorld"], 2, 99)
    check(len(parts_under(plot_folder(2))) > 0, "a world index past the last one is clamped")

    print("== claiming, pads and towers")
    player_a = R.lua_value({"UserId": 101, "DisplayName": "Yaani"})
    player_b = R.lua_value({"UserId": 202, "DisplayName": "Visitor"})
    call(Plots["claim"], 1, player_a)
    call(Plots["claim"], 8, player_b)
    for slot, user in ((1, 101), (8, 202)):
        folder = plot_folder(slot)
        check(folder.attrs.get("Owner") == user, f"plot {slot} Owner attribute after claim")
        signs = [p for p in parts_under(folder) if p.props["Name"] == "Board"]
        check(len(signs) == len(pads), f"plot {slot}: every pad is for sale after claim")
        shapes, _ = measure(slot, f"claimed plot {slot}")
        print(f"  plot {slot} claimed, nothing bought: {len(shapes)} parts")
    call(Plots["setPads"], 1, R.array([1, 4]))
    call(Plots["setPads"], 8, R.array(list(range(1, len(pads) + 1))))
    owned = [p.attrs.get("Owned") for p in plot_folder(1).child("Pads").children]
    check(owned == [i in (0, 3) for i in range(len(pads))], "setPads sets Owned on exactly the pads listed")
    check(len([p for p in parts_under(plot_folder(1)) if p.props["Name"] == "Board"]) == len(pads) - 2, "bought pads lose their sign")

    summary = {}
    for slot in (1, 8):
        frame = frames[slot - 1]
        folder = plot_folder(slot)
        for index in range(len(pads)):
            kind = KINDS[index % len(KINDS)]
            level = LEVELS[(index * 3 + slot) % len(LEVELS)]
            call(Plots["setTower"], slot, index + 1, kind, level)
            tower = folder.child("Towers").child(f"Tower_{index + 1}")
            label = f"plot {slot} pad {index + 1} {kind} L{level}"
            if not check(tower is not None and tower.cls == "Model", f"{label}: Tower_{index + 1} exists"):
                continue
            check(tower.attrs.get("Pad") == index + 1 and tower.attrs.get("Kind") == kind and tower.attrs.get("Level") == level,
                  f"{label}: attributes Pad, Kind, Level")
            check(tower.props.get("PrimaryPart") is not None, f"{label}: PrimaryPart")
            turret = tower.child("Turret")
            muzzles = [p for p in parts_under(tower) if p.props["Name"] == "Muzzle"]
            check(turret is not None and len(muzzles) == 1, f"{label}: one Turret and one Muzzle")
            center = seq(pad_world[slot - 1])[index].v
            pivot = get_pivot(tower)
            check(abs(pivot.pos.v[0] - center[0]) < 1e-6 and abs(pivot.pos.v[2] - center[2]) < 1e-6
                  and abs(pivot.pos.v[1] - 0.5) < 1e-6, f"{label}: stands on the middle of its pad")
            turret_pivot = get_pivot(turret)
            check(abs(turret_pivot.pos.v[0] - center[0]) < 1e-6 and abs(turret_pivot.pos.v[2] - center[2]) < 1e-6,
                  f"{label}: the turret turns about the pad's upright axis")
            check(abs(column(turret_pivot.rot, 1)[1] - 1) < 1e-6, f"{label}: the turret's pivot is upright")
            reach, low, high = 0, math.inf, -math.inf
            for part in parts_under(tower):
                check(part.props.get("CanCollide") is False and part.props.get("Anchored") is True, f"{label}: {part.props['Name']} anchored, no collisions")
                for p in samples(part):
                    reach = max(reach, math.hypot(p[0] - center[0], p[2] - center[2]))
                    low, high = min(low, p[1]), max(high, p[1])
            check(reach <= half_pad + 0.02, f"{label}: fits its pad however the turret turns (reaches {reach:.2f} from the middle)")
            check(abs(low - 0.5) < 1e-6, f"{label}: its foot is on the pad (lowest point {low:.3f})")
            for shape in (Shape(p, frame) for p in parts_under(tower)):
                check(to_path(shape) > 0.5, f"{label}: clear of the path: {shape.where()}")
            # It was built looking at the path; then aim it at three points and see the muzzle follow.
            muzzle = muzzles[0]
            look = column(turret_pivot.rot, 2)
            for target in ((center[0] + 30, 0, center[2] + 5), (center[0] - 12, 3, center[2] - 40), (center[0], 0, center[2] + 9)):
                call(get("aim"), tower, Vector3(*target))
                now = get_pivot(turret)
                want = unit((target[0] - center[0], 0, target[2] - center[2]))
                look = tuple(-x for x in column(now.rot, 2))
                check(sum(a * b for a, b in zip(look, want)) > 0.999999, f"{label}: the turret looks at its target")
                check(abs(now.pos.v[0] - turret_pivot.pos.v[0]) < 1e-6 and abs(now.pos.v[2] - turret_pivot.pos.v[2]) < 1e-6
                      and abs(now.pos.v[1] - turret_pivot.pos.v[1]) < 1e-6, f"{label}: aiming does not move the turret")
                offset = (muzzle.props["Position"].v[0] - center[0], muzzle.props["Position"].v[2] - center[2])
                if math.hypot(*offset) > 0.1:
                    along = (offset[0] * want[0] + offset[1] * want[2]) / math.hypot(*offset)
                    check(along > 0.999, f"{label}: the muzzle points at the target")
            base_count = len([p for p in parts_under(tower) if p.parent is tower])
            summary[(kind, level)] = (len(parts_under(tower)), base_count, reach, high - 0.5, tower.attrs.get("Tier"))
        shapes, _ = measure(slot, f"plot {slot} with 16 towers")
        print(f"  plot {slot} with 16 towers: {len(shapes)} parts")

    print("== upgrading keeps the model until the tier changes; nil removes it")
    towers = plot_folder(1).child("Towers")
    call(Plots["setTower"], 1, 1, "cannon", 1)
    first = towers.child("Tower_1")
    call(Plots["setTower"], 1, 1, "cannon", 7)
    check(towers.child("Tower_1") is first and first.attrs.get("Level") == 7, "levels 1 to 10 are one model")
    call(Plots["setTower"], 1, 1, "cannon", 11)
    check(towers.child("Tower_1") is not first and towers.child("Tower_1").attrs.get("Tier") == 2, "level 11 is a new model")
    call(Plots["setTower"], 1, 1, "frost", 11)
    check(towers.child("Tower_1").attrs.get("Kind") == "frost", "another kind replaces it")
    check(len([t for t in towers.children if t.props["Name"] == "Tower_1"]) == 1, "never two towers on one pad")
    call(Plots["setTower"], 1, 1, None, None)
    check(towers.child("Tower_1") is None, "kind = nil removes the tower")

    print("== releasing")
    call(Plots["release"], 8)
    folder = plot_folder(8)
    check(folder.attrs.get("Owner") == 0 and len(folder.child("Towers").children) == 0, "release: no owner, no towers")
    check(all(p.attrs.get("Owned") is False for p in folder.child("Pads").children), "release: no pad owned")
    check(len(parts_under(folder)) in counts, "release: the plot has as many parts as an empty one")

    print("== towers: every kind at every tier")
    scratch = R.Instance(world, "Folder", "Scratch")
    tiers = get("tiers")
    table = {}
    for kind in KINDS:
        for tier in range(1, tiers + 1):
            level = (tier - 1) * 10 + 1
            model = call(Models["tower"], kind, level, scratch)
            check(model.attrs.get("Tier") == tier, f"{kind} level {level} is tier {tier}")
            reach, low, high = 0, math.inf, -math.inf
            for part in parts_under(model):
                for p in samples(part):
                    reach = max(reach, math.hypot(p[0], p[2]))
                    low, high = min(low, p[1]), max(high, p[1])
            pivot = get_pivot(model)
            check(cf_eq(pivot, cf()), f"{kind} tier {tier}: built at the origin, pivot under its middle")
            check(abs(low) < 1e-6 and reach <= half_pad + 0.02, f"{kind} tier {tier}: on the ground and inside a pad (reach {reach:.2f})")
            muzzle = [p for p in parts_under(model) if p.props["Name"] == "Muzzle"]
            check(len(muzzle) == 1 and muzzle[0].props["Position"].v[2] <= 0.001 and abs(muzzle[0].props["Position"].v[0]) < 1e-6,
                  f"{kind} tier {tier}: the muzzle is towards -Z")
            look = tuple(-x for x in column(get_pivot(model.child("Turret")).rot, 2))
            check(abs(look[2] + 1) < 1e-6, f"{kind} tier {tier}: the turret's pivot looks along -Z")
            table.setdefault(kind, []).append((len(parts_under(model)), reach, high))
            model.set_parent(None)
    for kind in KINDS:
        rows = table[kind]
        counts_k = [r[0] for r in rows]
        print(f"  {kind:13} parts {min(counts_k)}..{max(counts_k)} (mean {sum(counts_k) / len(counts_k):.1f}); tier 1: {rows[0][0]} parts, "
              f"{rows[0][2]:.1f} tall, reach {rows[0][1]:.2f}; tier {tiers}: {rows[-1][0]} parts, {rows[-1][2]:.1f} tall, reach {rows[-1][1]:.2f}")

    print("== monsters")
    for shape_name in SHAPES:
        for kind, scale in (("normal", 1.5), ("boss", 3.3), ("mid", 3.9), ("final", 4.5)):
            model = call(Models["monster"], call(get("monsterDef"), shape_name, kind, scale), scratch)
            label = f"{shape_name} {kind}"
            body = model.props.get("PrimaryPart")
            check(body is not None and body.props["Name"] == "Body", f"{label}: PrimaryPart is the Body")
            check(cf_eq(get_pivot(model), cf()), f"{label}: pivot on the ground under its middle")
            parts = parts_under(model)
            low = min(p[1] for part in parts for p in samples(part))
            high = max(p[1] for part in parts for p in samples(part))
            width = max(abs(p[0]) for part in parts for p in samples(part)) * 2
            check(-0.001 <= low <= 0.25 * scale, f"{label}: stands on the ground (lowest point {low:.2f})")
            check(abs(model.attrs.get("Height") - high) < 0.02 * scale, f"{label}: Height attribute {model.attrs.get('Height'):.2f} against {high:.2f}")
            pupils = [p for p in parts if p.props["Name"] == "Pupil"]
            check(pupils and all(p.props["Position"].v[2] < body.props["Position"].v[2] for p in pupils), f"{label}: faces -Z")
            for part in parts:
                check(part.props.get("Anchored") is True and part.props.get("CanCollide") is False and part.props.get("CastShadow") is False,
                      f"{label}: {part.props['Name']} anchored, no collisions, no shadow")
            # Walked along the path of a far-row plot, it faces the way it walks and stays on the ground.
            for distance in (0, 30, 100, 359):
                position = call(get("walk"), model, 9, distance)
                ahead = interp.call(get("walk"), [model, 9, distance])[1].v
                eyes = [sum(p.props["Position"].v[i] for p in pupils) / len(pupils) for i in range(3)]
                at = body.props["Position"].v
                forward = (eyes[0] - at[0]) * ahead[0] + (eyes[2] - at[2]) * ahead[2]
                check(forward > 0, f"{label}: looks where it walks at {distance}")
                check(abs(get_pivot(model).pos.v[1]) < 1e-6 and abs(get_pivot(model).pos.v[0] - position.v[0]) < 1e-6, f"{label}: pivot follows PivotTo")
            if kind == "normal" or shape_name == "biped":
                print(f"  {shape_name:13} {kind:6} {len(parts):2} parts, {high:.1f} tall, {width:.1f} wide")
            model.set_parent(None)

    print("== nothing that collides is in a player's way")
    for slot in (1, 8, 12):
        frame = frames[slot - 1]
        folder = plot_folder(slot)
        solid = [Shape(p, frame) for p in parts_under(folder) if p.props.get("CanCollide", True) is not False]
        spawn = cf_point(cf_inverse(frame), spawns[slot - 1].pos).v
        look = mat_vec(transpose(frame.rot), tuple(-x for x in column(spawns[slot - 1].rot, 2)))
        check(look[2] > 0.999, f"plot {slot}: the owner arrives facing up the plot")
        zones = {
            "the spawn point": rectangle(spawn[0] - 3, spawn[2] - 3, spawn[0] + 3, spawn[2] + 3),
            "the gate's opening": rectangle(-6.9, 11, 6.9, 17),
            "the plaza behind the gate": rectangle(-20, 0, 20, 10),
            "the yard behind the plaza": rectangle(-50, -yard + 1, 50, 0),
        }
        for what, zone in zones.items():
            for shape in solid:
                if shape.name != "Ground" and shape.high > 0.6 and gap(shape.footprint, zone) <= 0:
                    check(False, f"plot {slot}: {what} is blocked by {shape.where()}")
        for shape in solid:
            # (The backdrop stands behind the portal, and the unseen wall of that side stands in it.)
            behind_portal = shape.name == "Barrier" and min(p[1] for p in shape.footprint) >= 149.9
            if shape.name not in FLAT and shape.name != "Backdrop" and not behind_portal and not shape.name.startswith("Pad_"):
                check(to_path(shape) > 2, f"plot {slot}: {shape.where()} collides near the path")
        if slot == 1:
            names = {}
            for shape in solid:
                names.setdefault(shape.name.split("_")[0], []).append(shape.high)
            print("  what collides on a plot: " + ", ".join(f"{n} x{len(h)} (top {max(h):.1f})" for n, h in sorted(names.items())))
    print("  what collides in the lobby: " + ", ".join(sorted(set(s.name for s in solid_lobby))))

    print("== mini cannons")
    Config = get("Config").hash
    pets_table = Config["Pets"].hash
    huges = [k for k, v in pets_table.items() if v.hash.get("huge")]
    plain = [k for k, v in pets_table.items() if not v.hash.get("huge")]
    fused = [k for k in plain if pets_table[k].hash.get("tier") == 3]
    equipped = [huges[0], huges[1], huges[0], fused[0]] + plain[:14]
    model = call(Plots["buildPets"], 9, R.array(equipped), 202)
    check(model.props["Name"] == "Pets_202" and model.parent is workspace.child("Cannons"), "Pets_<userId> in workspace.Cannons")
    minis = model.children
    check(len(minis) == len(equipped), "one model per equipped mini cannon")
    perches = [m.attrs.get("Perch") for m in minis]
    check(perches[:3] == [1, 2, None], "the first two different Huges get a side; a copy does not")
    spawn = spawns[8]
    for mini, pet in zip(minis, equipped):
        barrel = mini.props.get("PrimaryPart")
        home = mini.attrs.get("Home")
        check(barrel is not None and isinstance(home, R.CFrame) and cf_eq(home, part_cframe(barrel)), f"{pet}: Home is the barrel's CFrame")
        check(mini.attrs.get("PetId") == pet, f"{pet}: PetId")
        check((mini.attrs.get("Perch") is None) != (mini.attrs.get("Follow") is None), f"{pet}: Perch or Follow")
        local = cf_point(cf_inverse(spawn), home.pos).v
        check(local[2] > 0 and home.pos.v[1] > 0.5, f"{pet}: waits behind the spawn point, off the ground")
        # The barrel (its X axis) points the way the owner faces, a little upwards.
        axis = column(home.rot, 0)
        ahead = tuple(-x for x in column(spawn.rot, 2))
        check(sum(a * b for a, b in zip(axis, ahead)) > 0.97 and axis[1] > 0.1, f"{pet}: barrel points the way its owner faces")
        for part in parts_under(mini):
            check(part.props.get("CanCollide") is False and part.props.get("Anchored") is True, f"{pet}: {part.props['Name']} anchored, no collisions")
    follows = [m.attrs.get("Follow") for m in minis if m.attrs.get("Follow") is not None]
    check(len(set(follows[:14])) == 14, "the first fourteen take fourteen different follow spots")
    print(f"  {len(minis)} mini cannons, {len(parts_under(model))} parts; follow spots in order: {follows}")

    print("== tower table (kind, level -> parts, of which static, reach, height, tier)")
    for key in sorted(summary):
        parts, static, reach, height, tier = summary[key]
        print(f"  {key[0]:13} L{key[1]:<5} tier {tier:2}: {parts:2} parts ({static} static), reach {reach:.2f}, {height:.1f} tall")

    total = len(parts_under(workspace))
    print(f"== {total} parts in the workspace now")
    if interp.errors:
        failures.append(f"{len(interp.errors)} Luau error(s) in spawned threads")
    for name, where in sorted(interp.undefined.items()):
        failures.append(f"undefined global read: {name} ({where})")
    print(f"\n{'FAILED: ' + str(len(failures)) + ' check(s)' if failures else 'PASSED'}")
    for failure in failures[:40]:
        print("  " + failure)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    import threading

    threading.stack_size(512 * 1024 * 1024)
    thread = threading.Thread(target=main)
    thread.start()
    thread.join()
