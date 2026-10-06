#!/usr/bin/env python3
"""Standard library and Roblox mocks for luau_emu, plus the runner that loads the Rojo tree from disk.

One interpreter plays both server and client: the mock player object is shared, so attributes the server sets
are what the client reads, and a RemoteEvent fired on one side runs the handlers connected on the other.
"""
import functools
import json
import colorsys
import math
import os
import random
import re
import sys

from luau_emu import (
    Host, Interp, LuaError, LuaFunction, LuaSyntaxError, LuaTable, ThreadYield, first, fmt_num, is_num, lua_eq,
    tostr, truthy, typename,
)


def lib(entries):
    t = LuaTable()
    for k, v in entries.items():
        t.hash[k] = v
    return t


def array(values):
    t = LuaTable()
    t.arr = list(values)
    return t


def need_table(t, fn, pos=1):
    if type(t) is not LuaTable:
        raise LuaError(f"invalid argument #{pos} to '{fn}' (table expected, got {typename(t)})")
    return t


def need_num(v, fn, pos=1):
    if not is_num(v):
        raise LuaError(f"invalid argument #{pos} to '{fn}' (number expected, got {typename(v)})")
    return v


def need_str(v, fn, pos=1):
    if is_num(v):
        return fmt_num(v)
    if not isinstance(v, str):
        raise LuaError(f"invalid argument #{pos} to '{fn}' (string expected, got {typename(v)})")
    return v


# ---------------------------------------------------------------------------------------------------
# Lua patterns -> Python regular expressions (the subset this project uses)
# ---------------------------------------------------------------------------------------------------
CLASSES = {"a": "A-Za-z", "d": "0-9", "l": "a-z", "u": "A-Z", "w": "A-Za-z0-9", "s": " \\t\\n\\r\\f\\v", "x": "0-9A-Fa-f", "p": "!-/:-@\\[-`{-~"}


def lua_pattern(p):
    out = []
    i, n, in_set = 0, len(p), False
    while i < n:
        c = p[i]
        if c == "%":
            i += 1
            d = p[i]
            if d.lower() in CLASSES:
                body = CLASSES[d.lower()]
                if in_set:
                    if d.isupper():
                        raise LuaError("pattern class complements inside a set are not emulated")
                    out.append(body)
                else:
                    out.append(("[^" if d.isupper() else "[") + body + "]")
            else:
                out.append(re.escape(d))
        elif c == "[":
            in_set = True
            out.append("[")
            if i + 1 < n and p[i + 1] == "^":
                out.append("^")
                i += 1
        elif c == "]":
            in_set = False
            out.append("]")
        elif in_set:
            out.append(c if c == "-" else re.escape(c))
        elif c == "-":
            out.append("*?")
        elif c in "^$()*+?.":
            out.append(c)
        else:
            out.append(re.escape(c))
        i += 1
    return "".join(out)


# ---------------------------------------------------------------------------------------------------
# Roblox value types
# ---------------------------------------------------------------------------------------------------
class Vec(Host):
    fields = ()

    def __init__(self, *values):
        self.v = tuple(float(x) for x in values) + (0.0,) * (len(self.fields) - len(values))

    def lua_get(self, k):
        if k in self.fields:
            return self.v[self.fields.index(k)]
        if k == "Magnitude":
            return math.sqrt(sum(x * x for x in self.v))
        if k == "Unit":
            m = math.sqrt(sum(x * x for x in self.v)) or 1.0
            return type(self)(*(x / m for x in self.v))
        if k == "Lerp":
            return lambda a, b, t: type(a)(*(x + (y - x) * t for x, y in zip(a.v, b.v)))
        if k == "Dot":
            return lambda a, b: sum(x * y for x, y in zip(a.v, b.v))
        raise LuaError(f"{k} is not a valid member of {self.lua_type}")

    def lua_arith(self, op, a, b):
        if op == "unm":
            return type(self)(*(-x for x in self.v))
        if isinstance(a, CFrame) or isinstance(b, CFrame):
            return (a if isinstance(a, CFrame) else b).lua_arith(op, a, b)
        cls = type(self)
        av = a.v if isinstance(a, cls) else None
        bv = b.v if isinstance(b, cls) else None
        if av is None and is_num(a):
            av = (a,) * len(self.fields)
        if bv is None and is_num(b):
            bv = (b,) * len(self.fields)
        if av is None or bv is None:
            raise LuaError(f"attempt to perform arithmetic ({op}) on {typename(a)} and {typename(b)}")
        if op == "+":
            return cls(*(x + y for x, y in zip(av, bv)))
        if op == "-":
            return cls(*(x - y for x, y in zip(av, bv)))
        if op == "*":
            return cls(*(x * y for x, y in zip(av, bv)))
        if op == "/":
            return cls(*(x / y for x, y in zip(av, bv)))
        raise LuaError(f"attempt to perform arithmetic ({op}) on {self.lua_type}")

    def lua_eq(self, other):
        return type(other) is type(self) and other.v == self.v

    def __str__(self):
        return ", ".join(fmt_num(x) for x in self.v)


class Vector3(Vec):
    lua_type = "Vector3"
    fields = ("X", "Y", "Z")


class Vector2(Vec):
    lua_type = "Vector2"
    fields = ("X", "Y")


class Color3(Vec):
    lua_type = "Color3"
    fields = ("R", "G", "B")

    def lua_get(self, k):
        if k == "ToHex":
            return lambda c: "".join("%02x" % max(0, min(255, round(x * 255))) for x in c.v)
        if k == "ToHSV":
            return lambda c: list(colorsys.rgb_to_hsv(*c.v))
        return super().lua_get(k)


class UDim(Vec):
    lua_type = "UDim"
    fields = ("Scale", "Offset")


class Rect(Host):
    lua_type = "Rect"

    def __init__(self, x0=0, y0=0, x1=0, y1=0):
        self.min, self.max = Vector2(x0, y0), Vector2(x1, y1)

    def lua_get(self, k):
        if k == "Min":
            return self.min
        if k == "Max":
            return self.max
        if k == "Width":
            return self.max.v[0] - self.min.v[0]
        if k == "Height":
            return self.max.v[1] - self.min.v[1]
        raise LuaError(f"{k} is not a valid member of Rect")


class UDim2(Host):
    lua_type = "UDim2"

    def __init__(self, xs=0, xo=0, ys=0, yo=0):
        self.x = UDim(xs, xo)
        self.y = UDim(ys, yo)

    def lua_get(self, k):
        if k in ("X", "Width"):
            return self.x
        if k in ("Y", "Height"):
            return self.y
        if k == "Lerp":
            return lambda a, b, t: b
        raise LuaError(f"{k} is not a valid member of UDim2")

    def lua_arith(self, op, a, b):
        if not (isinstance(a, UDim2) and isinstance(b, UDim2)) or op not in ("+", "-"):
            raise LuaError(f"attempt to perform arithmetic ({op}) on {typename(a)} and {typename(b)}")
        s = 1 if op == "+" else -1
        return UDim2(a.x.v[0] + s * b.x.v[0], a.x.v[1] + s * b.x.v[1], a.y.v[0] + s * b.y.v[0], a.y.v[1] + s * b.y.v[1])

    def lua_eq(self, other):
        return isinstance(other, UDim2) and other.x.v == self.x.v and other.y.v == self.y.v

    def __str__(self):
        return "{%s}, {%s}" % (self.x, self.y)


EXTRA_PROPS = set("""
ScreenInsets ApplyStrokeMode LineJoinMode ClipsDescendants ZIndexBehavior DisplayOrder IgnoreGuiInset ResetOnSpawn
AutomaticSize AutomaticCanvasSize ScrollingDirection ScrollBarThickness ScrollBarImageColor3 CanvasSize CanvasPosition
TextTruncate TextStrokeTransparency TextStrokeColor3 RichText LineHeight MaxVisibleGraphemes TextTransparency
PlaceholderText PlaceholderColor3 ClearTextOnFocus
ImageColor3 ImageTransparency ScaleType SliceCenter ImageRectOffset ImageRectSize ResampleMode
Rotation AnchorPoint SizeConstraint Selectable Active AutoButtonColor Modal Interactable
GroupTransparency GroupColor3 Ambient LightDirection LightColor CurrentCamera FieldOfView Focus CameraType
Enabled Adornee AlwaysOnTop StudsOffset StudsOffsetWorldSpace MaxDistance LightInfluence ExtentsOffset
Thickness Transparency Color Offset PaddingLeft PaddingRight PaddingTop PaddingBottom Padding FillDirection
HorizontalAlignment VerticalAlignment SortOrder CellSize CellPadding FillDirectionMaxCells StartCorner Wraps
AspectRatio AspectType DominantAxis MinSize MaxSize MinTextSize MaxTextSize Scale
HoldDuration KeyboardKeyCode GamepadKeyCode RequiresLineOfSight MaxActivationDistance Exclusivity UIOffset ActionText ObjectText
Range Brightness Shadows Material Reflectance CastShadow CanCollide CanTouch CanQuery Anchored Massless Shape
TopSurface BottomSurface PrimaryPart WorldPivot PivotOffset Volume Looped PlaybackSpeed SoundId TimePosition
""".split())


class CFrame(Host):
    """Position only: rotation is not emulated. Enough for code that just passes CFrames around."""

    lua_type = "CFrame"

    def __init__(self, pos=None):
        self.pos = pos or Vector3(0, 0, 0)

    def lua_get(self, k):
        if k in ("Position", "p"):
            return self.pos
        if k in ("X", "Y", "Z"):
            return self.pos.lua_get(k)
        if k == "LookVector":
            return Vector3(0, 0, -1)
        if k == "RightVector":
            return Vector3(1, 0, 0)
        if k == "UpVector":
            return Vector3(0, 1, 0)
        if k == "Lerp":
            return lambda a, b, t: b
        if k in ("Inverse", "ToWorldSpace", "ToObjectSpace"):
            return lambda a, *rest: a
        if k in ("VectorToWorldSpace", "VectorToObjectSpace"):
            return lambda a, v: v
        if k == "PointToWorldSpace":
            return lambda a, v: a.pos.lua_arith("+", a.pos, v)
        if k == "PointToObjectSpace":
            return lambda a, v: v.lua_arith("-", v, a.pos)
        if k == "Rotation":
            return CFrame()
        raise LuaError(f"{k} is not a valid member of CFrame")

    def lua_arith(self, op, a, b):
        if isinstance(a, CFrame) and isinstance(b, CFrame) and op == "*":
            return CFrame(a.pos.lua_arith("+", a.pos, b.pos))
        if isinstance(a, CFrame) and isinstance(b, Vector3):
            if op == "*":
                return a.pos.lua_arith("+", a.pos, b)
            if op in ("+", "-"):
                return CFrame(a.pos.lua_arith(op, a.pos, b))
        raise LuaError(f"attempt to perform arithmetic ({op}) on {typename(a)} and {typename(b)}")

    def lua_eq(self, other):
        return isinstance(other, CFrame) and other.pos.v == self.pos.v

    def __str__(self):
        return f"CFrame({self.pos})"


class Opaque(Host):
    def __init__(self, lua_type, **fields):
        self.lua_type = lua_type
        self.fields = fields

    def lua_get(self, k):
        if k in self.fields:
            return self.fields[k]
        raise LuaError(f"{k} is not a valid member of {self.lua_type}")

    def __str__(self):
        return self.lua_type


class EnumItem(Host):
    lua_type = "EnumItem"

    def __init__(self, enum, name):
        self.enum, self.name = enum, name

    def lua_get(self, k):
        if k == "Name":
            return self.name
        if k == "Value":
            return 0
        if k == "EnumType":
            return self.enum
        raise LuaError(f"{k} is not a valid member of EnumItem")

    def __str__(self):
        return f"Enum.{self.enum.name}.{self.name}"


class EnumType(Host):
    lua_type = "Enum"

    def __init__(self, name):
        self.name = name
        self.items = {}

    def lua_get(self, k):
        if k not in self.items:
            self.items[k] = EnumItem(self, k)
        return self.items[k]

    def __str__(self):
        return f"Enum.{self.name}"


class Enums(Host):
    lua_type = "Enums"

    def __init__(self):
        self.types = {}

    def lua_get(self, k):
        if k not in self.types:
            self.types[k] = EnumType(k)
        return self.types[k]


# ---------------------------------------------------------------------------------------------------
# Signals and instances
# ---------------------------------------------------------------------------------------------------
class Connection(Host):
    lua_type = "RBXScriptConnection"

    def __init__(self, signal, fn, once=False):
        self.signal, self.fn, self.once, self.connected = signal, fn, once, True

    def lua_get(self, k):
        if k == "Connected":
            return self.connected
        if k == "Disconnect":
            return Connection.disconnect
        raise LuaError(f"{k} is not a valid member of RBXScriptConnection")

    def disconnect(self):
        self.connected = False
        if self in self.signal.handlers:
            self.signal.handlers.remove(self)


class Signal(Host):
    lua_type = "RBXScriptSignal"

    def __init__(self, world, name):
        self.world, self.name, self.handlers = world, name, []

    def lua_get(self, k):
        if k in ("Connect", "ConnectParallel"):
            return Signal.connect
        if k == "Once":
            return lambda s, fn: Signal.connect(s, fn, True)
        if k == "Wait":
            return Signal.wait
        raise LuaError(f"{k} is not a valid member of RBXScriptSignal")

    def connect(self, fn, once=False):
        if not (isinstance(fn, LuaFunction) or callable(fn)):
            raise LuaError(f"Attempt to connect failed: Passed value is not a function (got {typename(fn)})")
        c = Connection(self, fn, once)
        self.handlers.append(c)
        return c

    def wait(self):
        raise ThreadYield()

    def fire(self, *args):
        for c in list(self.handlers):
            if c.connected:
                if c.once:
                    c.disconnect()
                self.world.interp.spawn(c.fn, args, f"a handler of {self.name}")

    def __str__(self):
        return f"Signal {self.name}"


SIGNALS = {
    "Activated", "Changed", "AttributeChanged", "Triggered", "PromptTriggered", "PromptShown", "PromptHidden",
    "OnServerEvent", "OnClientEvent", "Heartbeat", "RenderStepped", "Stepped", "PlayerAdded", "PlayerRemoving",
    "CharacterAdded", "CharacterRemoving", "InputBegan", "InputEnded", "InputChanged", "Completed", "Event",
    "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "MouseButton1Click", "MouseButton1Down",
    "MouseButton1Up", "ChildAdded", "ChildRemoved", "DescendantAdded", "Destroying", "Touched", "Died",
    "MouseEnter", "MouseLeave", "Focused", "FocusLost", "TouchTap", "PlayerChatted", "Idled",
}
GUI_CLASSES = {"Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ScrollingFrame", "TextBox", "CanvasGroup"}
# Properties that exist on one class only, with the value a desktop Studio session starts with. Kept per class
# (unlike World.defaults) so reading one on the wrong kind of instance still stands out.
CLASS_PROPS = {
    "UserInputService": {"TouchEnabled": False, "KeyboardEnabled": True, "MouseEnabled": True, "GamepadEnabled": False},
}


class Instance(Host):
    lua_type = "Instance"

    def __init__(self, world, cls, name=None):
        self.world = world
        self.cls = cls
        self.props = {"Name": name or cls, "ClassName": cls}
        self.props.update(CLASS_PROPS.get(cls, {}))
        self.parent = None
        self.children = []
        self.attrs = {}
        self.tags = []  # CollectionService tags, in the order they were added
        self.signals = {}
        self.prop_signals = {}
        self.destroyed = False
        self.source_path = None

    # -- tree --
    def set_parent(self, parent):
        if parent is not None and not isinstance(parent, Instance):
            raise LuaError(f"invalid value for Parent ({typename(parent)})")
        if self.parent is parent:
            return
        was_in_game = self.in_game()
        if self.parent is not None:
            self.parent.children.remove(self)
        self.parent = parent
        if parent is not None:
            parent.children.append(self)
            if "ChildAdded" in parent.signals:
                parent.signals["ChildAdded"].fire(self)
        if self.world.tag_signals and was_in_game != self.in_game():
            # CollectionService only counts tagged instances that are inside the DataModel.
            self.world.tags_moved(self, not was_in_game)

    def in_game(self):
        node = self
        while node.parent is not None:
            node = node.parent
        return node is self.world.game

    def child(self, name):
        for c in self.children:
            if c.props["Name"] == name:
                return c
        return None

    def full_name(self):
        parts = []
        node = self
        while node is not None and node.cls != "DataModel":
            parts.append(str(node.props["Name"]))
            node = node.parent
        return ".".join(reversed(parts))

    def signal(self, name):
        if name not in self.signals:
            self.signals[name] = Signal(self.world, f"{self.full_name()}.{name}")
        return self.signals[name]

    def is_a(self, cls):
        if cls == self.cls or cls == "Instance":
            return True
        if cls == "GuiObject":
            return self.cls in GUI_CLASSES
        if cls == "GuiBase2d":
            return self.cls in GUI_CLASSES or self.cls in ("ScreenGui", "BillboardGui", "SurfaceGui")
        if cls == "BasePart":
            return self.cls in ("Part", "MeshPart", "WedgePart", "SpawnLocation")
        if cls == "LuaSourceContainer":
            return self.cls in ("ModuleScript", "Script", "LocalScript")
        if cls == "ValueBase":
            return self.cls.endswith("Value")
        return False

    # -- Lua access --
    def lua_get(self, k):
        if k == "Parent":
            return self.parent
        if k in self.props:
            return self.props[k]
        m = self.world.methods.get(self.cls, {}).get(k) or self.world.methods["*"].get(k)
        if m is not None:
            return m
        # "Event" is a signal of a BindableEvent only: anywhere else it is a child's name (Features.Event).
        if k in SIGNALS and (k != "Event" or self.cls == "BindableEvent"):
            return self.signal(k)
        c = self.child(k)
        if c is not None:
            return c
        defaults = self.world.defaults
        if k in defaults:
            d = defaults[k]
            return d() if callable(d) else d
        if k in self.world.known_props:
            return None
        raise LuaError(f"{k} is not a valid member of {self.cls} \"{self.full_name()}\"")

    def lua_set(self, k, v):
        if self.destroyed and k == "Parent" and v is not None:
            raise LuaError(f"The Parent property of {self.props['Name']} is locked")
        if k == "Parent":
            self.set_parent(v)
            return
        if k not in self.world.known_props and k not in self.props and k not in self.world.defaults:
            raise LuaError(f"{k} is not a valid member of {self.cls} \"{self.full_name()}\"")
        if k in self.props:
            old = self.props[k]
        else:
            d = self.world.defaults.get(k)
            old = d() if callable(d) else d
        if v is None and k in ("Text", "Name", "Size", "Position", "BackgroundColor3", "TextColor3", "Visible", "LayoutOrder", "Color"):
            raise LuaError(f"invalid value for {k} (nil)")
        if k in ("Text", "Name") and not isinstance(v, str):
            if is_num(v):
                v = fmt_num(v)
            else:
                raise LuaError(f"invalid value for {k} ({typename(v)}, string expected)")
        # A UIGradient's (or a particle emitter's) Color is a ColorSequence.
        sequenced = self.cls in ("UIGradient", "ParticleEmitter", "Trail", "Beam") and k == "Color"
        if k in ("BackgroundColor3", "TextColor3", "Color", "ImageColor3") and not sequenced and not isinstance(v, Color3):
            raise LuaError(f"invalid value for {k} ({typename(v)}, Color3 expected)")
        if k in ("Size", "Position") and self.cls in GUI_CLASSES and not isinstance(v, UDim2):
            raise LuaError(f"invalid value for {k} ({typename(v)}, UDim2 expected)")
        if k in ("Visible", "Active", "TextScaled", "TextWrapped") and type(v) is not bool:
            raise LuaError(f"invalid value for {k} ({typename(v)}, boolean expected)")
        if k == "LayoutOrder" and not is_num(v):
            raise LuaError(f"invalid value for {k} ({typename(v)}, number expected)")
        self.props[k] = v
        # A part's CFrame and Position are one thing (rotation is not emulated).
        if k == "CFrame" and isinstance(v, CFrame) and self.cls not in ("Camera",):
            self.props["Position"] = v.pos
        elif k == "Position" and isinstance(v, Vector3):
            self.props["CFrame"] = CFrame(v)
        if not lua_eq(old, v):
            if k in self.prop_signals:
                self.prop_signals[k].fire()
            if "Changed" in self.signals:
                self.signals["Changed"].fire(v if self.is_a("ValueBase") else k)

    def __str__(self):
        return str(self.props["Name"])


def json_value(v, what="JSON"):
    """Lua value -> plain Python, with the checks Roblox applies to JSON and DataStore values."""
    if type(v) is LuaTable:
        if v.hash and v.arr:
            raise LuaError(f"{what}: cannot convert a mixed table (array part and keys)")
        if v.hash:
            out = {}
            for k, val in v.hash.items():
                if not isinstance(k, str):
                    raise LuaError(f"{what}: table key {tostr(k)!r} is not a string")
                out[k] = json_value(val, what)
            return out
        return [json_value(x, what) for x in v.arr]
    if v is None or type(v) is bool or isinstance(v, str):
        return v
    if is_num(v):
        if v != v or v in (math.inf, -math.inf):
            raise LuaError(f"{what}: number {fmt_num(v)} cannot be stored")
        return v
    raise LuaError(f"{what}: cannot convert a {typename(v)}")


def lua_value(o):
    if isinstance(o, dict):
        t = LuaTable()
        for k, v in o.items():
            t.hash[k] = lua_value(v)
        return t
    if isinstance(o, list):
        return array([lua_value(x) for x in o])
    if isinstance(o, float) and o.is_integer() and abs(o) < 2**53:
        return int(o)
    return o


# ---------------------------------------------------------------------------------------------------
# The world: interpreter + globals + DataModel
# ---------------------------------------------------------------------------------------------------
class World:
    def __init__(self):
        self.interp = Interp()
        self.clock = 1_791_000_000.0  # unix seconds: early October 2026, while the Halloween event is live
        self.cpu = 100.0
        self.timers = []  # (time, order, fn, args)
        self.timer_order = 0
        self.forced_random = []
        self.rng = random.Random(7)
        self.modules = {}
        self.prompts = []  # purchase prompts shown: (kind, player, id)
        self.output = []
        self.stores = {}
        self.ordered = {}  # OrderedDataStores: name -> {key: whole number}
        self.ordered_failures = 0  # requests to them that will fail next (harness.failOrdered)
        self.is_studio = True
        # What PolicyService says about paid random items for whoever is asked next (harness.setPolicy):
        # True = restricted, False = allowed, None = the lookup fails.
        self.policy_restricted = False
        self.known_props = set()
        self.defaults = {
            "Visible": True, "Text": "", "Enabled": True, "LayoutOrder": 0, "Active": False,
            "AbsolutePosition": lambda: Vector2(0, 0), "AbsoluteSize": lambda: Vector2(100, 30),
            "TopbarInset": lambda: Rect(0, 0, 1280, 58), "IsLoaded": True, "AbsoluteCanvasSize": lambda: Vector2(100, 300), "AbsoluteWindowSize": lambda: Vector2(100, 30),
            "CanvasPosition": lambda: Vector2(0, 0), "TextTransparency": 0, "Transparency": 0,
            "BackgroundTransparency": 0, "Character": None, "PrimaryPart": None, "Adornee": None,
            "CameraSubject": None, "Value": None, "Rotation": 0, "TextBounds": lambda: Vector2(50, 20),
            "CameraType": None, "CFrame": lambda: CFrame(), "JobId": "", "PlaceId": 0, "GameId": 0,
            "ClockTime": 14, "Brightness": 2, "Ambient": None, "OutdoorAmbient": None, "Size": None,
            "Position": None, "BackgroundColor3": None, "TextColor3": None, "AnchorPoint": None,
            "ZIndex": 1, "Scale": 1, "ProcessReceipt": None, "TextStrokeTransparency": 1,
        }
        self.methods = {"*": {}}
        self.tagged = {}  # CollectionService: tag -> instances carrying it, in the order they were tagged
        self.tag_signals = {}  # (tag, "added" | "removed") -> Signal
        self.game = Instance(self, "DataModel", "game")
        self.services = {}
        self.install_globals()
        self.install_methods()

    # -- time --
    def advance(self, seconds):
        self.clock += seconds
        self.cpu += seconds
        while True:
            due = [t for t in self.timers if t[0] <= self.clock]
            if not due:
                break
            due.sort()
            self.timers.remove(due[0])
            self.interp.spawn(due[0][2], due[0][3], "task.delay")
        self.interp.flush()

    # -- CollectionService tags --
    def tag_signal(self, tag, kind):
        key = (tag, kind)
        if key not in self.tag_signals:
            self.tag_signals[key] = Signal(self, f"CollectionService instance {kind} ({tag})")
        return self.tag_signals[key]

    def tag_event(self, inst, tag, kind):
        if (tag, kind) in self.tag_signals:
            self.tag_signals[(tag, kind)].fire(inst)

    def tags_moved(self, inst, entered):
        """inst (and so everything under it) has just entered or left the DataModel."""
        for tag in list(inst.tags):
            self.tag_event(inst, tag, "added" if entered else "removed")
        for child in list(inst.children):
            self.tags_moved(child, entered)

    def add_tag(self, inst, tag):
        if not isinstance(inst, Instance):
            raise LuaError(f"AddTag: Instance expected, got {typename(inst)}")
        if not isinstance(tag, str):
            raise LuaError(f"AddTag: tag must be a string, got {typename(tag)}")
        if tag in inst.tags:
            return
        inst.tags.append(tag)
        self.tagged.setdefault(tag, []).append(inst)
        if inst.in_game():
            self.tag_event(inst, tag, "added")

    def remove_tag(self, inst, tag):
        if not isinstance(inst, Instance):
            raise LuaError(f"RemoveTag: Instance expected, got {typename(inst)}")
        if not isinstance(tag, str):
            raise LuaError(f"RemoveTag: tag must be a string, got {typename(tag)}")
        if tag not in inst.tags:
            return
        inst.tags.remove(tag)
        holders = self.tagged[tag]
        holders.remove(inst)
        if not holders:
            del self.tagged[tag]
        if inst.in_game():
            self.tag_event(inst, tag, "removed")

    # -- services --
    def service(self, name):
        if name not in self.services:
            inst = Instance(self, name, name)
            inst.set_parent(self.game)
            self.services[name] = inst
        return self.services[name]

    def new_instance(self, cls, parent=None):
        if not isinstance(cls, str):
            raise LuaError("Instance.new expects a class name")
        inst = Instance(self, cls)
        if parent is not None:
            inst.set_parent(parent)
        return inst

    # -- require --
    def require(self, module=None):
        if not isinstance(module, Instance) or module.cls != "ModuleScript":
            raise LuaError(f"Attempted to call require with invalid argument(s) ({typename(module)} {tostr(module)})")
        if module in self.modules:
            state = self.modules[module]
            if state[0] == "loading":
                raise LuaError(f"Requested module was required recursively: {module.full_name()}")
            return state[1]
        self.modules[module] = ("loading", None)
        result = self.run_script(module)
        if len(result) != 1:
            raise LuaError(f"Module code did not return exactly one value: {module.full_name()}")
        self.modules[module] = ("done", result[0])
        return result[0]

    def run_script(self, inst):
        src = open(inst.source_path, encoding="utf-8").read()
        interp = self.interp
        saved = interp.stack
        interp.stack = []
        try:
            return interp.run(src, inst.source_path, {"script": inst})
        finally:
            interp.stack = saved

    # -- globals --
    def install_globals(self):
        interp = self.interp
        g = interp.globals.vars
        world = self

        def l_print(*args):
            line = " ".join(tostr(a) for a in args)
            world.output.append(line)
            print("[lua] " + line)

        def l_warn(*args):
            line = " ".join(tostr(a) for a in args)
            world.output.append("WARN " + line)
            print("[lua warn] " + line)

        def l_error(msg=None, level=1):
            raise LuaError(msg if msg is not None else "nil")

        def l_assert(*args):
            if not args or not truthy(args[0]):
                raise LuaError(args[1] if len(args) > 1 else "assertion failed!")
            return list(args)

        def l_pairs(t):
            need_table(t, "pairs")
            gen = t.items()

            def step(_s=None, _c=None):
                for k, v in gen:
                    return [k, v]
                return [None]

            return [step, t, None]

        def l_ipairs(t):
            need_table(t, "ipairs")

            def step(tbl, i):
                v = tbl.get(i + 1)
                if v is None:
                    return [None]
                return [i + 1, v]

            return [step, t, 0]

        def l_next(t, k=None):
            need_table(t, "next")
            found = k is None
            for key, value in t.items():
                if found:
                    return [key, value]
                if lua_eq(key, k):
                    found = True
            return [None]

        def l_select(n, *args):
            if n == "#":
                return len(args)
            return list(args[int(n) - 1 :])

        def l_tonumber(v=None, base=None):
            if is_num(v):
                return v
            if isinstance(v, str):
                try:
                    if base is not None:
                        return int(v.strip(), int(base))
                    text = v.strip()
                    value = float(int(text, 16)) if text[:2].lower() == "0x" else float(text)
                    return int(value) if value.is_integer() and abs(value) < 2**53 else value
                except ValueError:
                    return None
            return None

        def l_setmetatable(t, mt):
            need_table(t, "setmetatable")
            t.meta = mt
            return t

        def l_unpack(t, i=1, j=None):
            need_table(t, "unpack")
            j = len(t.arr) if j is None else int(j)
            return [t.get(n) for n in range(int(i), j + 1)]

        def l_typeof(*args):
            if not args:
                raise LuaError("missing argument #1 to 'typeof'")
            return typename(args[0])

        def l_type(*args):
            if not args:
                raise LuaError("missing argument #1 to 'type'")
            name = typename(args[0])
            return name if name in ("nil", "boolean", "number", "string", "table", "function") else "userdata"

        def l_xpcall(f, handler, *args):
            depth = len(interp.stack)
            try:
                return [True] + interp.call(f, list(args))
            except LuaError as e:
                del interp.stack[depth:]
                return [False] + interp.call(handler, [e.value])

        g["debug"] = lib({"traceback": lambda msg=None, *a: tostr(msg) if msg is not None else "traceback", "info": lambda *a: None})
        g.update({
            "xpcall": l_xpcall,
            "print": l_print, "warn": l_warn, "error": l_error, "assert": l_assert, "pairs": l_pairs,
            "ipairs": l_ipairs, "next": l_next, "select": l_select, "tonumber": l_tonumber,
            "tostring": lambda *a: tostr(a[0]) if a else "nil", "typeof": l_typeof, "type": l_type,
            "pcall": interp.pcall, "setmetatable": l_setmetatable,
            "getmetatable": lambda t: t.meta if type(t) is LuaTable else None,
            "rawget": lambda t, k: t.get(k), "rawset": lambda t, k, v: (t.set(k, v), t)[1],
            "rawequal": lambda a, b: lua_eq(a, b), "rawlen": lambda t: len(t.arr) if type(t) is LuaTable else len(t),
            "unpack": l_unpack, "require": self.require,
            "tick": lambda: world.clock, "time": lambda: world.cpu,
            "wait": lambda *a: (_ for _ in ()).throw(ThreadYield()),
        })

        # string
        def s_format(fmt, *args):
            fmt = need_str(fmt, "format")
            state = {"i": 0}

            def repl(m):
                spec = m.group(0)
                if spec == "%%":
                    return "%"
                if state["i"] >= len(args):
                    raise LuaError(f"missing argument #{state['i'] + 2} to 'format'")
                a = args[state["i"]]
                state["i"] += 1
                conv = spec[-1]
                if conv in "di":
                    return (spec[:-1] + "d") % int(need_num(a, "format", state["i"] + 1))
                if conv in "xX":
                    return spec % int(need_num(a, "format", state["i"] + 1))
                if conv in "fgGeE":
                    return spec % float(need_num(a, "format", state["i"] + 1))
                if conv == "c":
                    return chr(int(a))
                return spec[:-1].replace("q", "") + "s" if False else (spec[:-1] + "s") % tostr(a)

            return re.sub(r"%(?:%|[-+ #0]*\d*(?:\.\d+)?[dixXfgGeEsqc])", repl, fmt)

        def s_sub(s, i=1, j=-1):
            s = need_str(s, "sub")
            n = len(s)
            i, j = int(i), int(j)
            if i < 0:
                i = max(n + i + 1, 1)
            elif i == 0:
                i = 1
            if j < 0:
                j = n + j + 1
            elif j > n:
                j = n
            return s[i - 1 : j] if i <= j else ""

        def s_gsub(s, pattern, repl, limit=None):
            s = need_str(s, "gsub")
            rx = re.compile(lua_pattern(need_str(pattern, "gsub", 2)))

            def sub(m):
                whole = m.group(0)
                capture = m.group(1) if m.groups() else whole
                if isinstance(repl, str):
                    return re.sub(r"%(\d)", lambda d: m.group(int(d.group(1))) if int(d.group(1)) else whole, repl)
                if type(repl) is LuaTable:
                    value = repl.get(capture)
                else:
                    value = first(interp.call(repl, list(m.groups()) or [whole]))
                return whole if not truthy(value) else tostr(value)

            result, count = rx.subn(sub, s, count=int(limit) if limit is not None else 0)
            return [result, count]

        def s_find(s, pattern, init=1, plain=False):
            s = need_str(s, "find")
            start = max(int(init) - 1, 0)
            if truthy(plain):
                at = s.find(pattern, start)
                return [at + 1, at + len(pattern)] if at >= 0 else [None]
            m = re.compile(lua_pattern(pattern)).search(s, start)
            if not m:
                return [None]
            return [m.start() + 1, m.end()] + list(m.groups())

        def s_match(s, pattern, init=1):
            m = re.compile(lua_pattern(pattern)).search(need_str(s, "match"), max(int(init) - 1, 0))
            if not m:
                return [None]
            return list(m.groups()) if m.groups() else [m.group(0)]

        def s_split(s, sep=","):
            return array(need_str(s, "split").split(sep) if sep != "" else list(s))

        interp.string_lib = lib({
            "format": s_format, "sub": s_sub, "gsub": s_gsub, "find": s_find, "match": s_match, "split": s_split,
            "lower": lambda s: need_str(s, "lower").lower(), "upper": lambda s: need_str(s, "upper").upper(),
            "len": lambda s: len(need_str(s, "len").encode("utf-8")),
            "rep": lambda s, n, sep="": sep.join([need_str(s, "rep")] * int(n)),
            "reverse": lambda s: s[::-1], "byte": lambda s, i=1: ord(s[int(i) - 1]) if 0 < int(i) <= len(s) else None,
            "char": lambda *a: "".join(chr(int(x)) for x in a),
        })
        g["string"] = interp.string_lib

        # table
        def t_insert(t, *args):
            need_table(t, "insert")
            if len(args) == 1:
                if args[0] is None:
                    return
                t.set(len(t.arr) + 1, args[0])
            elif len(args) == 2:
                pos = int(need_num(args[0], "insert", 2))
                if pos == len(t.arr) + 1:
                    t.set(pos, args[1])
                else:
                    if not 1 <= pos <= len(t.arr):
                        raise LuaError("invalid argument #2 to 'insert' (position out of bounds)")
                    t.arr.insert(pos - 1, args[1])
            else:
                raise LuaError("wrong number of arguments to 'insert'")

        def t_remove(t, pos=None):
            need_table(t, "remove")
            n = len(t.arr)
            if n == 0:
                return None
            pos = n if pos is None else int(pos)
            if not 1 <= pos <= n:
                return None
            return t.arr.pop(pos - 1)

        def t_sort(t, comp=None):
            need_table(t, "sort")
            if comp is None:
                def less(a, b):
                    return interp.compare("<", a, b, None, None)
            else:
                def less(a, b):
                    return truthy(first(interp.call(comp, [a, b])))

            def cmp(a, b):
                if less(a, b):
                    if less(b, a):
                        raise LuaError("invalid order function for sorting")
                    return -1
                return 1 if less(b, a) else 0

            t.arr.sort(key=functools.cmp_to_key(cmp))

        def t_find(t, value, init=1):
            need_table(t, "find")
            for i in range(int(init) - 1, len(t.arr)):
                if lua_eq(t.arr[i], value):
                    return i + 1
            return None

        def t_clone(t):
            need_table(t, "clone")
            c = LuaTable()
            c.arr = list(t.arr)
            c.hash = dict(t.hash)
            c.meta = t.meta
            return c

        def t_concat(t, sep="", i=1, j=None):
            need_table(t, "concat")
            j = len(t.arr) if j is None else int(j)
            parts = []
            for n in range(int(i), j + 1):
                v = t.get(n)
                if not (isinstance(v, str) or is_num(v)):
                    raise LuaError(f"invalid value (at index {n}) in table for 'concat'")
                parts.append(tostr(v))
            return sep.join(parts)

        def t_clear(t):
            need_table(t, "clear")
            t.arr.clear()
            t.hash.clear()

        def t_move(a, f, e, t, dest=None):
            need_table(a, "move")
            dest = a if dest is None else dest
            values = [a.get(i) for i in range(int(f), int(e) + 1)]
            for offset, value in enumerate(values):
                dest.set(int(t) + offset, value)
            return dest

        g["table"] = lib({
            "move": t_move,
            "insert": t_insert, "remove": t_remove, "sort": t_sort, "find": t_find, "clone": t_clone,
            "concat": t_concat, "clear": t_clear, "unpack": l_unpack, "pack": lambda *a: array(a),
            "create": lambda n, v=None: array([v] * int(n)) if v is not None else LuaTable(),
            "freeze": lambda t: t, "isfrozen": lambda t: False,
        })

        # math
        def whole(fn):
            def wrapped(x):
                need_num(x, fn.__name__)
                if x != x or x in (math.inf, -math.inf) or abs(x) >= 2**53:
                    return float(x)
                return fn(x)

            return wrapped

        def m_clamp(x, lo, hi):
            need_num(x, "clamp")
            need_num(lo, "clamp", 2)
            need_num(hi, "clamp", 3)
            if lo > hi:
                raise LuaError("invalid argument #3 to 'clamp' (max must be greater than or equal to min)")
            return max(lo, min(hi, x))

        def m_max(*a):
            for i, x in enumerate(a):
                need_num(x, "max", i + 1)
            if not a:
                raise LuaError("missing argument #1 to 'max' (number expected)")
            return max(a)

        def m_min(*a):
            for i, x in enumerate(a):
                need_num(x, "min", i + 1)
            if not a:
                raise LuaError("missing argument #1 to 'min' (number expected)")
            return min(a)

        def m_random(a=None, b=None):
            if a is None:
                return world.rng.random()
            if b is None:
                return world.rng.randint(1, int(a))
            return world.rng.randint(int(a), int(b))

        def m_log(x, base=None):
            need_num(x, "log")
            if x <= 0:
                return -math.inf if x == 0 else math.nan
            return math.log(x) if base is None else math.log(x, base)

        g["math"] = lib({
            "floor": whole(math.floor), "ceil": whole(math.ceil), "abs": lambda x: abs(need_num(x, "abs")),
            "max": m_max, "min": m_min, "clamp": m_clamp, "huge": math.inf, "pi": math.pi,
            "sqrt": lambda x: math.sqrt(x) if x >= 0 else math.nan, "sin": math.sin, "cos": math.cos, "tan": math.tan,
            "rad": math.radians, "deg": math.degrees, "exp": math.exp, "log": m_log,
            "log10": lambda x: m_log(x, 10), "pow": lambda a, b: float(a) ** b, "fmod": math.fmod,
            "random": m_random, "randomseed": lambda *a: None,
            "round": lambda x: math.floor(x + 0.5), "sign": lambda x: (x > 0) - (x < 0),
            "atan2": math.atan2, "atan": math.atan, "noise": lambda *a: 0,
        })

        g["os"] = lib({
            "time": lambda *a: int(world.clock), "clock": lambda: world.cpu,
            "date": lambda *a: "date",
        })

        # task
        def t_spawn(f, *args):
            interp.spawn(f, args, "task.spawn")
            return f

        def t_defer(f, *args):
            interp.deferred.append((f, args))
            return f

        def t_delay(seconds, f, *args):
            world.timer_order += 1
            world.timers.append((world.clock + (seconds or 0), world.timer_order, f, args))
            return f

        def t_wait(seconds=0):
            raise ThreadYield()

        g["task"] = lib({"spawn": t_spawn, "defer": t_defer, "delay": t_delay, "wait": t_wait, "cancel": lambda *a: None})
        g["coroutine"] = lib({
            "running": lambda: "thread", "yield": t_wait, "wrap": lambda f: f,
            "isyieldable": lambda: True,
        })

        # Roblox value constructors
        def v3(x=0, y=0, z=0):
            return Vector3(x, y, z)

        g["Vector3"] = lib({"new": v3, "zero": Vector3(0, 0, 0), "one": Vector3(1, 1, 1), "xAxis": Vector3(1, 0, 0), "yAxis": Vector3(0, 1, 0), "zAxis": Vector3(0, 0, 1)})
        g["Vector2"] = lib({"new": lambda x=0, y=0: Vector2(x, y), "zero": Vector2(0, 0), "one": Vector2(1, 1)})
        def c3_from_hex(text=None):
            digits = need_str(text, "fromHex").removeprefix("#")
            if len(digits) == 3:
                digits = "".join(c * 2 for c in digits)
            if len(digits) != 6 or re.fullmatch(r"[0-9A-Fa-f]+", digits) is None:
                raise LuaError("Unable to convert characters to hex value")
            return Color3(*(int(digits[i : i + 2], 16) / 255 for i in (0, 2, 4)))

        def c3_from_hsv(h=0, sat=0, v=0):
            return Color3(*colorsys.hsv_to_rgb(need_num(h, "fromHSV"), need_num(sat, "fromHSV", 2), need_num(v, "fromHSV", 3)))

        g["Color3"] = lib({
            "new": lambda r=0, gr=0, b=0: Color3(r, gr, b),
            "fromRGB": lambda r=0, gr=0, b=0: Color3(need_num(r, "fromRGB") / 255, need_num(gr, "fromRGB", 2) / 255, need_num(b, "fromRGB", 3) / 255),
            "fromHSV": c3_from_hsv, "fromHex": c3_from_hex,
        })
        g["UDim"] = lib({"new": lambda s=0, o=0: UDim(s, o)})
        g["UDim2"] = lib({
            "new": lambda *a: UDim2(*a) if all(is_num(x) for x in a) else UDim2(a[0].v[0], a[0].v[1], a[1].v[0], a[1].v[1]),
            "fromOffset": lambda x=0, y=0: UDim2(0, need_num(x, "fromOffset"), 0, need_num(y, "fromOffset", 2)),
            "fromScale": lambda x=0, y=0: UDim2(need_num(x, "fromScale"), 0, need_num(y, "fromScale", 2), 0),
        })

        def cf_new(*a):
            if not a:
                return CFrame()
            if isinstance(a[0], Vector3):
                return CFrame(a[0])
            return CFrame(Vector3(*a[:3]))

        g["CFrame"] = lib({
            "new": cf_new, "lookAt": lambda at, target, up=None: CFrame(at), "Angles": lambda *a: CFrame(),
            "fromEulerAnglesXYZ": lambda *a: CFrame(), "fromOrientation": lambda *a: CFrame(), "identity": CFrame(),
        })
        g["Enum"] = Enums()
        g["TweenInfo"] = lib({"new": lambda *a: Opaque("TweenInfo")})
        g["NumberRange"] = lib({"new": lambda *a: Opaque("NumberRange")})
        g["Rect"] = lib({"new": lambda *a: Rect(*a)})
        g["NumberSequence"] = lib({"new": lambda *a: Opaque("NumberSequence")})
        g["ColorSequence"] = lib({"new": lambda *a: Opaque("ColorSequence")})
        g["NumberSequenceKeypoint"] = lib({"new": lambda *a: Opaque("NumberSequenceKeypoint")})
        g["ColorSequenceKeypoint"] = lib({"new": lambda *a: Opaque("ColorSequenceKeypoint")})
        g["Instance"] = lib({"new": self.new_instance})

        class LuaRandom(Host):
            lua_type = "Random"

            def lua_get(self, k):
                if k == "NextNumber":
                    return LuaRandom.next_number
                if k == "NextInteger":
                    return lambda s, a, b: world.rng.randint(int(a), int(b))
                raise LuaError(f"{k} is not a valid member of Random")

            def next_number(self, lo=0, hi=1):
                x = world.forced_random.pop(0) if world.forced_random else world.rng.random()
                return lo + (hi - lo) * x

        g["Random"] = lib({"new": lambda seed=None: LuaRandom()})
        g["game"] = self.game
        g["workspace"] = self.service("Workspace")

    # -- instance methods --
    def install_methods(self):
        world = self
        interp = self.interp
        any_methods = self.methods["*"]

        def find_first_child(inst, name, recursive=False):
            c = inst.child(name)
            if c is None and truthy(recursive):
                for child in inst.children:
                    c = find_first_child(child, name, True)
                    if c is not None:
                        break
            return c

        def wait_for_child(inst, name, timeout=None):
            c = inst.child(name)
            if c is None:
                if timeout is not None:
                    return None
                raise ThreadYield()
            return c

        def find_of_class(inst, cls):
            for c in inst.children:
                if c.cls == cls:
                    return c
            return None

        def descendants(inst):
            out = []
            for c in inst.children:
                out.append(c)
                out.extend(descendants(c))
            return out

        def destroy(inst):
            for c in list(inst.children):
                destroy(c)
            inst.set_parent(None)
            inst.destroyed = True
            for tag in list(inst.tags):
                world.remove_tag(inst, tag)
            for s in list(inst.signals.values()) + list(inst.prop_signals.values()):
                s.handlers.clear()

        def set_attribute(inst, name, value):
            if not isinstance(name, str):
                raise LuaError("attribute name must be a string")
            if type(value) is LuaTable or isinstance(value, LuaFunction):
                raise LuaError(f"{typename(value)} is not a supported attribute type")
            if is_num(value) and not isinstance(value, bool) and value != value:
                pass
            old = inst.attrs.get(name)
            if value is None:
                inst.attrs.pop(name, None)
            else:
                inst.attrs[name] = value
            if not lua_eq(old, value):
                if "AttributeChanged" in inst.signals:
                    inst.signals["AttributeChanged"].fire(name)

        def prop_signal(inst, name):
            if name not in world.known_props and name not in inst.props and name not in world.defaults:
                raise LuaError(f"{name} is not a valid property name.")
            if name not in inst.prop_signals:
                inst.prop_signals[name] = Signal(world, f"{inst.full_name()}:{name} changed")
            return inst.prop_signals[name]

        def clone(inst):
            c = Instance(world, inst.cls, inst.props["Name"])
            c.props = dict(inst.props)
            c.attrs = dict(inst.attrs)
            for tag in inst.tags:
                world.add_tag(c, tag)
            c.source_path = inst.source_path
            for child in inst.children:
                clone(child).set_parent(c)
            return c

        def extents_size(inst):
            # The box around a model's parts (no rotation, like the rest of the emulator).
            lo, hi = [math.inf] * 3, [-math.inf] * 3
            for part in descendants(inst):
                pos, size = part.props.get("Position"), part.props.get("Size")
                if isinstance(pos, Vector3) and isinstance(size, Vector3):
                    for axis in range(3):
                        lo[axis] = min(lo[axis], pos.v[axis] - size.v[axis] / 2)
                        hi[axis] = max(hi[axis], pos.v[axis] + size.v[axis] / 2)
            if lo[0] > hi[0]:
                return Vector3(0, 0, 0)
            return Vector3(*(h - l for l, h in zip(lo, hi)))

        any_methods.update({
            "FindFirstChild": find_first_child, "WaitForChild": wait_for_child,
            "FindFirstChildOfClass": find_of_class, "FindFirstChildWhichIsA": lambda i, c, deep=None: next((x for x in (descendants(i) if deep else i.children) if x.is_a(c)), None),
            "GetChildren": lambda i: array(i.children), "GetDescendants": lambda i: array(descendants(i)),
            "IsA": lambda i, c: i.is_a(c), "Destroy": destroy, "Clone": clone,
            "SetAttribute": set_attribute, "GetAttribute": lambda i, n: i.attrs.get(n),
            "GetAttributes": lambda i: lua_value(dict(i.attrs)),
            "GetPropertyChangedSignal": prop_signal, "GetAttributeChangedSignal": lambda i, n: i.signal("Attr_" + n),
            "IsDescendantOf": lambda i, a: any(p is a for p in ancestors(i)),
            "GetFullName": lambda i: i.full_name(), "ClearAllChildren": lambda i: [destroy(c) for c in list(i.children)] and None,
            "PivotTo": lambda i, cf: None, "GetPivot": lambda i: CFrame(), "SetPrimaryPartCFrame": lambda i, cf: None,
            "GetExtentsSize": extents_size,
            "FindFirstAncestor": lambda i, n: next((p for p in ancestors(i) if p.props["Name"] == n), None),
            "AddTag": world.add_tag, "RemoveTag": world.remove_tag,
            "HasTag": lambda i, tag: tag in i.tags, "GetTags": lambda i: array(i.tags),
        })

        def need_instance(inst, fn):
            if not isinstance(inst, Instance):
                raise LuaError(f"{fn}: Instance expected, got {typename(inst)}")
            return inst

        self.methods["CollectionService"] = {
            "AddTag": lambda s, i, tag: world.add_tag(i, tag), "RemoveTag": lambda s, i, tag: world.remove_tag(i, tag),
            "HasTag": lambda s, i, tag: tag in need_instance(i, "HasTag").tags,
            "GetTags": lambda s, i: array(need_instance(i, "GetTags").tags),
            # Like Roblox, only instances inside the DataModel are returned.
            "GetTagged": lambda s, tag: array([i for i in world.tagged.get(tag, []) if i.in_game()]),
            "GetAllTags": lambda s: array(list(world.tagged)),
            "GetInstanceAddedSignal": lambda s, tag: world.tag_signal(tag, "added"),
            "GetInstanceRemovedSignal": lambda s, tag: world.tag_signal(tag, "removed"),
        }

        def ancestors(inst):
            node = inst.parent
            while node is not None:
                yield node
                node = node.parent

        def get_service(game, name):
            return world.service(name)

        self.methods["DataModel"] = {"GetService": get_service, "BindToClose": lambda g, f: None, "IsLoaded": lambda g: True}

        def fire_server(remote, *args):
            player = world.service("Players").props.get("LocalPlayer")
            for a in args:
                check_remote_arg(a)
            remote.signal("OnServerEvent").fire(player, *[copy_remote(a) for a in args])

        def fire_client(remote, player, *args):
            if not isinstance(player, Instance) or player.cls != "Player":
                raise LuaError("FireClient: player argument must be a Player object")
            remote.signal("OnClientEvent").fire(*[copy_remote(a) for a in args])

        def fire_all(remote, *args):
            remote.signal("OnClientEvent").fire(*[copy_remote(a) for a in args])

        def check_remote_arg(a):
            if isinstance(a, LuaFunction):
                raise LuaError("functions cannot be sent through a remote")

        def copy_remote(a):
            if type(a) is LuaTable:
                c = LuaTable()
                c.arr = [copy_remote(x) for x in a.arr]
                for k, v in a.hash.items():
                    c.hash[k] = copy_remote(v)
                return c
            return a

        self.methods["RemoteEvent"] = {"FireServer": fire_server, "FireClient": fire_client, "FireAllClients": fire_all}
        self.methods["UnreliableRemoteEvent"] = self.methods["RemoteEvent"]
        self.methods["BindableEvent"] = {"Fire": lambda b, *a: b.signal("Event").fire(*a)}

        def get_players(players):
            return array([c for c in players.children if c.cls == "Player"])

        def by_user_id(players, user_id):
            for c in players.children:
                if c.cls == "Player" and c.props.get("UserId") == user_id:
                    return c
            return None

        def name_from_user_id(players, user_id):
            # The name of whoever is online with that id; anyone else is "User<id>".
            online = by_user_id(players, user_id)
            return online.props["Name"] if online is not None else f"User{fmt_num(user_id)}"

        self.methods["Players"] = {"GetPlayers": get_players, "GetPlayerByUserId": by_user_id, "GetNameFromUserIdAsync": name_from_user_id}
        self.methods["Player"] = {
            "RequestStreamAroundAsync": lambda p, pos, t=None: None, "Kick": lambda p, msg=None: world.output.append(f"KICK {msg}"),
            "GetRankInGroup": lambda p, g: 0, "IsInGroup": lambda p, g: False, "LoadCharacter": lambda p: None,
        }
        self.methods["RunService"] = {
            "IsStudio": lambda r: world.is_studio, "IsServer": lambda r: True, "IsClient": lambda r: True,
            "IsRunning": lambda r: True, "BindToRenderStep": lambda r, *a: None, "UnbindFromRenderStep": lambda r, *a: None,
        }

        def json_encode(http, value):
            return json.dumps(json_value(value, "JSONEncode"), ensure_ascii=False, separators=(",", ":"))

        def json_decode(http, text):
            if not isinstance(text, str):
                raise LuaError("JSONDecode: string expected")
            try:
                return lua_value(json.loads(text))
            except ValueError as e:
                raise LuaError(f"Can't parse JSON: {e}")

        self.methods["HttpService"] = {"JSONEncode": json_encode, "JSONDecode": json_decode, "GenerateGUID": lambda h, wrap=True: "guid-%d" % world.rng.randrange(10**9)}

        def prompt_product(market, player, product_id):
            if not is_num(product_id):
                raise LuaError("PromptProductPurchase: product id must be a number")
            world.prompts.append(("product", player, product_id))

        def prompt_pass(market, player, pass_id):
            world.prompts.append(("pass", player, pass_id))

        self.methods["MarketplaceService"] = {
            "PromptProductPurchase": prompt_product, "PromptGamePassPurchase": prompt_pass,
            "UserOwnsGamePassAsync": lambda m, uid, pid: False, "PlayerOwnsAsset": lambda m, p, a: False,
            "GetProductInfo": lambda m, pid, kind=None: lua_value({"Name": "product", "PriceInRobux": 0}),
        }

        class DataStore(Host):
            lua_type = "Instance"

            def __init__(self, name):
                self.name = name
                self.values = world.stores.setdefault(name, {})

            def lua_get(self, k):
                if k == "GetAsync":
                    return lambda s, key: lua_value(json.loads(s.values[key])) if key in s.values else None
                if k == "SetAsync":
                    return DataStore.set_async
                if k == "UpdateAsync":
                    return DataStore.update_async
                if k == "RemoveAsync":
                    return lambda s, key: s.values.pop(key, None) and None
                raise LuaError(f"{k} is not a valid member of DataStore")

            def set_async(self, key, value, *rest):
                self.values[key] = json.dumps(json_value(value, f"DataStore value for {key}"))

            def update_async(self, key, fn):
                current = lua_value(json.loads(self.values[key])) if key in self.values else None
                result = first(interp.call(fn, [current, None]))
                if result is not None:
                    self.values[key] = json.dumps(json_value(result, f"DataStore value for {key}"))
                return result

        class OrderedDataStore(Host):
            """Whole numbers by key, read back best first: what the leaderboards are kept in."""
            lua_type = "Instance"

            def __init__(self, name):
                self.name = name
                self.values = world.ordered.setdefault(name, {})

            def lua_get(self, k):
                if k == "GetAsync":
                    return lambda s, key: s.values.get(key)
                if k == "SetAsync":
                    return OrderedDataStore.set_async
                if k == "RemoveAsync":
                    return lambda s, key: s.values.pop(key, None) and None
                if k == "GetSortedAsync":
                    return OrderedDataStore.get_sorted
                raise LuaError(f"{k} is not a valid member of OrderedDataStore")

            def fail(self):
                # harness.failOrdered(n): the next n requests fail, as a store that is down does.
                if world.ordered_failures > 0:
                    world.ordered_failures -= 1
                    raise LuaError(f"502: API Services rejected request (emulated failure of {self.name})")

            def set_async(self, key, value, *rest):
                self.fail()
                if not isinstance(key, str):
                    raise LuaError("OrderedDataStore keys must be strings")
                if not is_num(value) or value != int(value) or abs(value) > 2**63:
                    raise LuaError(f"OrderedDataStore {self.name}: {fmt_num(value) if is_num(value) else typename(value)} is not a whole number it can hold")
                self.values[key] = int(value)

            def get_sorted(self, ascending, size, *rest):
                self.fail()
                if not is_num(size) or size < 1 or size > 100:
                    raise LuaError("GetSortedAsync: the page size must be 1 to 100")
                rows = sorted(self.values.items(), key=lambda row: row[1], reverse=not truthy(ascending))[: int(size)]
                page = array([lua_value({"key": key, "value": value}) for key, value in rows])
                return Opaque("DataStorePages", GetCurrentPage=lambda pages: page, IsFinished=True)

        self.methods["DataStoreService"] = {
            "GetDataStore": lambda s, name, scope=None: DataStore(name),
            "GetOrderedDataStore": lambda s, name, scope=None: OrderedDataStore(name),
        }

        class Tween(Host):
            lua_type = "Instance"

            def __init__(self, inst, goals):
                self.inst, self.goals = inst, goals
                self.completed = Signal(world, "Tween.Completed")

            def lua_get(self, k):
                if k == "Completed":
                    return self.completed
                if k in ("Play", "Cancel", "Pause", "Destroy"):
                    return lambda s: None
                raise LuaError(f"{k} is not a valid member of Tween")

        def tween_create(service, inst, info, goals):
            if not isinstance(inst, Instance):
                raise LuaError("TweenService:Create: Instance expected")
            need_table(goals, "Create", 3)
            return Tween(inst, goals)

        self.methods["TweenService"] = {"Create": tween_create}
        self.methods["Workspace"] = {"GetServerTimeNow": lambda w: world.clock, "Raycast": lambda *a: None}
        def policy_info(service, player):
            if world.policy_restricted is None:
                raise LuaError("GetPolicyInfoForPlayerAsync: the policy service is unavailable")
            return lua_value({"ArePaidRandomItemsRestricted": world.policy_restricted})

        self.methods["PolicyService"] = {"GetPolicyInfoForPlayerAsync": policy_info}
        self.methods["UserInputService"] = {"GetMouseLocation": lambda u: Vector2(0, 0), "IsKeyDown": lambda u, k: False}
        def get_text_size(service, text=None, size=None, font=None, frame=None):
            """An estimate: no font metrics here, so a glyph is taken to be half the font size wide."""
            text = need_str(text, "GetTextSize")
            need_num(size, "GetTextSize", 2)
            if not isinstance(font, EnumItem) or font.enum.name != "Font":
                raise LuaError(f"invalid argument #3 to 'GetTextSize' (Enum.Font expected, got {typename(font)})")
            if not isinstance(frame, Vector2):
                raise LuaError(f"invalid argument #4 to 'GetTextSize' (Vector2 expected, got {typename(frame)})")
            glyph, line_height = size * 0.5, math.ceil(size * 1.2)
            per_line = max(1, int(frame.v[0] // glyph)) if glyph > 0 else 1
            widest, lines = 0, 0
            for line in text.split("\n"):
                lines += max(1, math.ceil(len(line) / per_line))
                widest = max(widest, min(len(line), per_line))
            return Vector2(min(frame.v[0], math.ceil(widest * glyph)), min(frame.v[1], lines * line_height))

        def preload_async(provider, assets=None, callback=None):
            """Everything counts as loaded at once, so (unlike Roblox) this does not yield."""
            need_table(assets, "PreloadAsync")
            for i, asset in enumerate(assets.arr):
                if not isinstance(asset, (Instance, str)):
                    raise LuaError(f"PreloadAsync: item {i + 1} is a {typename(asset)} (Instance or content id expected)")
            if callback is not None:
                for asset in assets.arr:
                    if isinstance(asset, str):
                        interp.call(callback, [asset, world.interp.globals.vars["Enum"].lua_get("AssetFetchStatus").lua_get("Success")])

        self.methods["TextService"] = {"GetTextSize": get_text_size}
        self.methods["ContentProvider"] = {"PreloadAsync": preload_async}
        self.methods["Debris"] = {"AddItem": lambda *a: None}
        self.methods["Humanoid"] = {"MoveTo": lambda *a: None}
        self.methods["Sound"] = {"Play": lambda *a: None, "Stop": lambda *a: None}
        self.methods["SoundService"] = {"PlayLocalSound": lambda *a: None}
        self.methods["ParticleEmitter"] = {"Emit": lambda *a: None}
        # Everything is "on screen", in the middle, as far away as it is from the camera's position.
        self.methods["Camera"] = {"WorldToViewportPoint": lambda cam, at: [
            Vector3(640, 360, (at.lua_arith("-", at, cam.props["CFrame"].pos)).lua_get("Magnitude")), True]}

    # -- the Rojo tree --
    def load_dir(self, path, name, keep=None):
        entries = sorted(os.listdir(path))
        cls, source = "Folder", None
        for init, init_cls in (("init.luau", "ModuleScript"), ("init.server.luau", "Script"), ("init.client.luau", "LocalScript")):
            if init in entries:
                cls, source = init_cls, os.path.join(path, init)
        inst = Instance(self, cls, name)
        inst.source_path = source
        for entry in entries:
            full = os.path.join(path, entry)
            if os.path.isdir(full):
                self.load_dir(full, entry, keep).set_parent(inst)
            elif entry.endswith(".luau") and not entry.startswith("init."):
                stem = entry[: -len(".luau")]
                if name == "Features" and keep is not None and stem not in keep:
                    continue
                child = Instance(self, "ModuleScript", stem)
                child.source_path = full
                child.set_parent(inst)
        return inst

    def harvest_props(self, paths):
        """Property names the existing (trusted) core files assign, so a misspelt one elsewhere stands out."""
        for path in paths:
            src = open(path, encoding="utf-8").read()
            self.known_props.update(re.findall(r"\b([A-Z][A-Za-z0-9]*)\s*=[^=]", src))
        # Real Roblox properties the core files happen not to use: without these a feature that sets one would
        # look like a typo.
        self.known_props.update(EXTRA_PROPS)
