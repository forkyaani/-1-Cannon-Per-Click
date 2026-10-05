"""Mocked Roblox for luau_vm: datatypes with real maths (so built models can be measured), instances,
signals, the services the game's server uses, and require() over the Rojo source tree."""
import json
import math
import os

from luau_vm import LuaError, LuaTable, ThreadStop, VM, is_number, tostring, type_name


# -- datatypes --------------------------------------------------------------------------------------
class Value:
    """Base for datatypes: fields are read with lua_index, methods are looked up as m_<name>."""
    lua_type = "userdata"

    def lua_index(self, vm, key):
        if isinstance(key, str):
            method = getattr(self, "m_" + key, None)
            if method is not None:
                return lambda _self, *args: method(*args)
            if hasattr(self, "f_" + key):
                return getattr(self, "f_" + key)()
        vm.error(f"{key} is not a valid member of {self.lua_type}")


class Color3(Value):
    lua_type = "Color3"

    def __init__(self, r, g, b):
        self.r, self.g, self.b = r, g, b

    def f_R(self):
        return self.r

    def f_G(self):
        return self.g

    def f_B(self):
        return self.b

    def m_Lerp(self, other, t):
        return Color3(self.r + (other.r - self.r) * t, self.g + (other.g - self.g) * t, self.b + (other.b - self.b) * t)

    def m_ToHex(self):
        return "".join("%02x" % max(0, min(255, round(x * 255))) for x in (self.r, self.g, self.b))

    def lua_eq(self, other):
        return isinstance(other, Color3) and (self.r, self.g, self.b) == (other.r, other.g, other.b)

    def __repr__(self):
        return "rgb(%d,%d,%d)" % (round(self.r * 255), round(self.g * 255), round(self.b * 255))


class Vector3(Value):
    lua_type = "Vector3"

    def __init__(self, x=0.0, y=0.0, z=0.0):
        self.x, self.y, self.z = float(x), float(y), float(z)

    def f_X(self):
        return self.x

    def f_Y(self):
        return self.y

    def f_Z(self):
        return self.z

    def f_Magnitude(self):
        return math.sqrt(self.x ** 2 + self.y ** 2 + self.z ** 2)

    def f_Unit(self):
        m = self.f_Magnitude()
        return Vector3(self.x / m, self.y / m, self.z / m)

    def m_Dot(self, o):
        return self.x * o.x + self.y * o.y + self.z * o.z

    def m_Cross(self, o):
        return Vector3(self.y * o.z - self.z * o.y, self.z * o.x - self.x * o.z, self.x * o.y - self.y * o.x)

    def m_Lerp(self, o, t):
        return Vector3(self.x + (o.x - self.x) * t, self.y + (o.y - self.y) * t, self.z + (o.z - self.z) * t)

    def lua_arith(self, op, a, b):
        if op == "unm":
            return Vector3(-self.x, -self.y, -self.z)
        if isinstance(a, Vector3) and isinstance(b, Vector3):
            if op == "add":
                return Vector3(a.x + b.x, a.y + b.y, a.z + b.z)
            if op == "sub":
                return Vector3(a.x - b.x, a.y - b.y, a.z - b.z)
            if op == "mul":
                return Vector3(a.x * b.x, a.y * b.y, a.z * b.z)
            if op == "div":
                return Vector3(a.x / b.x, a.y / b.y, a.z / b.z)
        if isinstance(a, Vector3) and is_number(b):
            if op == "mul":
                return Vector3(a.x * b, a.y * b, a.z * b)
            if op == "div":
                return Vector3(a.x / b, a.y / b, a.z / b)
        if is_number(a) and isinstance(b, Vector3) and op == "mul":
            return Vector3(a * b.x, a * b.y, a * b.z)
        if isinstance(b, CFrame):
            return b.lua_arith(op, a, b)
        raise LuaError(f"bad Vector3 arithmetic ({op}) on {type_name(a)} and {type_name(b)}")

    def lua_eq(self, other):
        return isinstance(other, Vector3) and (self.x, self.y, self.z) == (other.x, other.y, other.z)

    def __repr__(self):
        return "(%.2f, %.2f, %.2f)" % (self.x, self.y, self.z)


class Vector2(Value):
    lua_type = "Vector2"

    def __init__(self, x=0.0, y=0.0):
        self.x, self.y = float(x), float(y)

    def f_X(self):
        return self.x

    def f_Y(self):
        return self.y

    def f_Magnitude(self):
        return math.hypot(self.x, self.y)

    def f_Unit(self):
        m = self.f_Magnitude()
        return Vector2(self.x / m, self.y / m)

    def m_Dot(self, o):
        return self.x * o.x + self.y * o.y

    def m_Lerp(self, o, t):
        return Vector2(self.x + (o.x - self.x) * t, self.y + (o.y - self.y) * t)

    def lua_eq(self, other):
        return isinstance(other, Vector2) and (self.x, self.y) == (other.x, other.y)

    def lua_arith(self, op, a, b):
        if op == "unm":
            return Vector2(-self.x, -self.y)
        if is_number(a) and isinstance(b, Vector2) and op == "mul":
            return Vector2(a * b.x, a * b.y)
        if isinstance(a, Vector2) and isinstance(b, Vector2):
            if op == "mul":
                return Vector2(a.x * b.x, a.y * b.y)
            if op == "add":
                return Vector2(a.x + b.x, a.y + b.y)
            if op == "sub":
                return Vector2(a.x - b.x, a.y - b.y)
        if isinstance(a, Vector2) and is_number(b):
            if op == "mul":
                return Vector2(a.x * b, a.y * b)
            if op == "div":
                return Vector2(a.x / b, a.y / b)
        raise LuaError(f"bad Vector2 arithmetic ({op})")

    def __repr__(self):
        return "(%g, %g)" % (self.x, self.y)


class UDim(Value):
    lua_type = "UDim"

    def __init__(self, scale=0.0, offset=0.0):
        self.scale, self.offset = float(scale), float(offset)

    def f_Scale(self):
        return self.scale

    def f_Offset(self):
        return self.offset

    def __repr__(self):
        return "{%g, %g}" % (self.scale, self.offset)


class UDim2(Value):
    lua_type = "UDim2"

    def __init__(self, xs=0.0, xo=0.0, ys=0.0, yo=0.0):
        for value in (xs, xo, ys, yo):
            if not is_number(value):
                raise LuaError(f"UDim2.new: number expected, got {type_name(value)}")
        self.x, self.y = UDim(xs, xo), UDim(ys, yo)

    def f_X(self):
        return self.x

    def f_Y(self):
        return self.y

    def f_Width(self):
        return self.x

    def f_Height(self):
        return self.y

    def lua_arith(self, op, a, b):
        if isinstance(a, UDim2) and isinstance(b, UDim2) and op in ("add", "sub"):
            sign = 1 if op == "add" else -1
            return UDim2(a.x.scale + sign * b.x.scale, a.x.offset + sign * b.x.offset, a.y.scale + sign * b.y.scale, a.y.offset + sign * b.y.offset)
        raise LuaError(f"bad UDim2 arithmetic ({op})")

    def __repr__(self):
        return "{%g,%g},{%g,%g}" % (self.x.scale, self.x.offset, self.y.scale, self.y.offset)


IDENTITY = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


def mat_mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mat_vec(m, v):
    return Vector3(*(m[i][0] * v.x + m[i][1] * v.y + m[i][2] * v.z for i in range(3)))


class CFrame(Value):
    lua_type = "CFrame"

    def __init__(self, position=None, rotation=IDENTITY):
        self.p = position or Vector3()
        self.r = rotation

    @staticmethod
    def look_at(eye, target, up=None):
        look = Vector3(target.x - eye.x, target.y - eye.y, target.z - eye.z).f_Unit()
        up = up or Vector3(0, 1, 0)
        right = look.m_Cross(up).f_Unit()
        true_up = right.m_Cross(look)
        return CFrame(eye, ((right.x, true_up.x, -look.x), (right.y, true_up.y, -look.y), (right.z, true_up.z, -look.z)))

    @staticmethod
    def angles(rx, ry, rz):
        cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
        mx = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
        my = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
        mz = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))
        return CFrame(Vector3(), mat_mul(mat_mul(mx, my), mz))

    def f_Position(self):
        return self.p

    def f_X(self):
        return self.p.x

    def f_Y(self):
        return self.p.y

    def f_Z(self):
        return self.p.z

    def f_LookVector(self):
        return Vector3(-self.r[0][2], -self.r[1][2], -self.r[2][2])

    def f_RightVector(self):
        return Vector3(self.r[0][0], self.r[1][0], self.r[2][0])

    def f_UpVector(self):
        return Vector3(self.r[0][1], self.r[1][1], self.r[2][1])

    def m_VectorToWorldSpace(self, v):
        return mat_vec(self.r, v)

    def m_PointToWorldSpace(self, v):
        return self.lua_arith("mul", self, v)

    def m_ToObjectSpace(self, other):
        return self.lua_arith("mul", self.m_Inverse(), other)

    def m_ToWorldSpace(self, other):
        return self.lua_arith("mul", self, other)

    def m_PointToObjectSpace(self, v):
        return self.lua_arith("mul", self.m_Inverse(), v)

    def m_VectorToObjectSpace(self, v):
        return mat_vec(self.m_Inverse().r, v)

    def f_Rotation(self):
        return CFrame(Vector3(), self.r)

    def m_Inverse(self):
        rt = tuple(tuple(self.r[j][i] for j in range(3)) for i in range(3))
        p = mat_vec(rt, self.p)
        return CFrame(Vector3(-p.x, -p.y, -p.z), rt)

    def m_Lerp(self, other, t):
        return CFrame(self.p.m_Lerp(other.p, t), other.r if t >= 0.5 else self.r)

    def lua_arith(self, op, a, b):
        if isinstance(a, CFrame) and isinstance(b, CFrame) and op == "mul":
            rotated = mat_vec(a.r, b.p)
            return CFrame(Vector3(rotated.x + a.p.x, rotated.y + a.p.y, rotated.z + a.p.z), mat_mul(a.r, b.r))
        if isinstance(a, CFrame) and isinstance(b, Vector3):
            if op == "mul":
                rotated = mat_vec(a.r, b)
                return Vector3(rotated.x + a.p.x, rotated.y + a.p.y, rotated.z + a.p.z)
            if op == "add":
                return CFrame(Vector3(a.p.x + b.x, a.p.y + b.y, a.p.z + b.z), a.r)
            if op == "sub":
                return CFrame(Vector3(a.p.x - b.x, a.p.y - b.y, a.p.z - b.z), a.r)
        raise LuaError(f"bad CFrame arithmetic ({op}) on {type_name(a)} and {type_name(b)}")

    def lua_eq(self, other):
        return isinstance(other, CFrame) and self.p.lua_eq(other.p) and self.r == other.r

    def __repr__(self):
        return f"CFrame{self.p}"


class EnumNode:
    lua_type = "EnumItem"

    def __init__(self, path):
        self.path = path

    def lua_index(self, vm, key):
        if key == "Name":
            return self.path.rsplit(".", 1)[-1]
        return EnumNode(f"{self.path}.{key}")

    def lua_eq(self, other):
        return isinstance(other, EnumNode) and other.path == self.path

    def __hash__(self):
        return hash(self.path)

    def __eq__(self, other):
        return isinstance(other, EnumNode) and other.path == self.path

    def __repr__(self):
        return self.path


class Namespace:
    """A library table whose members are Python callables or constants: Color3, Vector3, CFrame ..."""
    lua_type = "table"

    def __init__(self, name, members):
        self.name = name
        self.members = members

    def lua_index(self, vm, key):
        if key not in self.members:
            vm.error(f"{key} is not a valid member of {self.name}")
        return self.members[key]


# -- instances --------------------------------------------------------------------------------------
class Connection:
    lua_type = "RBXScriptConnection"

    def __init__(self, signal, fn):
        self.signal, self.fn = signal, fn

    def lua_index(self, vm, key):
        if key == "Disconnect":
            return lambda _self: self.signal.handlers.remove(self.fn) if self.fn in self.signal.handlers else None
        if key == "Connected":
            return self.fn in self.signal.handlers
        vm.error(f"{key} is not a valid member of RBXScriptConnection")


class Signal:
    lua_type = "RBXScriptSignal"

    def __init__(self, world, name):
        self.world, self.name, self.handlers = world, name, []

    def lua_index(self, vm, key):
        if key in ("Connect", "Once", "ConnectParallel"):
            def connect(_self, fn):
                if type_name(fn) != "function":
                    vm.error(f"{self.name}:Connect needs a function, got {type_name(fn)}")
                self.handlers.append(fn)
                return Connection(self, fn)
            return connect
        if key == "Wait":
            def wait(_self):
                raise ThreadStop()
            return wait
        vm.error(f"{key} is not a valid member of RBXScriptSignal")

    def fire(self, *args):
        for handler in list(self.handlers):
            self.world.vm.spawn(handler, list(args))


SIGNALS = {
    "Activated", "Triggered", "Changed", "Heartbeat", "RenderStepped", "Stepped", "PlayerAdded", "PlayerRemoving",
    "CharacterAdded", "CharacterRemoving", "AttributeChanged", "OnServerEvent", "OnClientEvent",
    "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "PromptShown", "PromptHidden",
    "PromptTriggered", "InputBegan", "InputEnded", "Completed", "Event", "MouseButton1Click", "Touched",
    "ChildAdded", "ChildRemoved", "Died", "Idled", "Chatted", "MouseEnter", "MouseLeave", "Destroying",
}
GUI_CLASSES = {"Frame", "TextLabel", "TextButton", "TextBox", "ScrollingFrame", "ImageLabel", "ImageButton", "CanvasGroup"}
BASE_CLASSES = {
    "Part": ("BasePart", "PVInstance"), "SpawnLocation": ("BasePart", "Part", "PVInstance"), "Model": ("PVInstance",),
    "TextButton": ("GuiButton", "GuiObject"), "TextLabel": ("GuiObject",), "Frame": ("GuiObject",),
    "ScrollingFrame": ("GuiObject",), "ImageLabel": ("GuiObject",), "ImageButton": ("GuiButton", "GuiObject"),
    "IntValue": ("ValueBase",), "StringValue": ("ValueBase",), "NumberValue": ("ValueBase",),
}


class Inst:
    lua_type = "Instance"

    def __init__(self, world, cls, name=None):
        self.world = world
        self.cls = cls
        self.props = {"Name": name or cls, "ClassName": cls}
        self.attrs = {}
        self.children = []
        self.parent = None
        self.signals = {}
        self.methods = {}
        self.extras = {}  # things reachable by name that are not instances (the Rojo tree)
        self.destroyed = False
        if cls in GUI_CLASSES:
            self.props.update({"Visible": True, "ZIndex": 1.0, "LayoutOrder": 0.0, "AbsolutePosition": Vector2(), "AbsoluteSize": Vector2(100, 30), "Rotation": 0.0})
        if cls in ("TextLabel", "TextButton", "TextBox"):
            self.props.update({"Text": "", "TextTransparency": 0.0})
        if cls == "ScrollingFrame":
            self.props["CanvasPosition"] = Vector2()
        if cls in ("Part", "SpawnLocation"):
            self.props.update({"Size": Vector3(4, 1, 2), "CFrame": CFrame(), "Transparency": 0.0})

    def __repr__(self):
        return f"<{self.cls} {self.props['Name']}>"

    def signal(self, name):
        if name not in self.signals:
            self.signals[name] = Signal(self.world, f"{self.props['Name']}.{name}")
        return self.signals[name]

    def find(self, name):
        for child in self.children:
            if child.props.get("Name") == name:
                return child
        return self.extras.get(name)

    def set_parent(self, parent):
        if self.parent is not None and self in self.parent.children:
            self.parent.children.remove(self)
        self.parent = parent
        if parent is not None:
            if not isinstance(parent, Inst):
                raise LuaError(f"Parent must be an Instance, got {type_name(parent)}")
            parent.children.append(self)

    def lua_index(self, vm, key):
        if key == "Parent":
            return self.parent
        if key == "Position" and isinstance(self.props.get("CFrame"), CFrame):
            return self.props["CFrame"].p
        if key in self.props:
            return self.props[key]
        if key in self.methods:
            return self.methods[key]
        # "Event" is a signal of a BindableEvent only: anywhere else it is a child's name (Features.Event).
        if key in SIGNALS and (key != "Event" or self.cls == "BindableEvent"):
            return self.signal(key)
        method = METHODS.get(key)
        if method is not None:
            return method
        return self.find(key)

    def lua_newindex(self, vm, key, value):
        if self.destroyed and key == "Parent" and value is not None:
            vm.error(f"The Parent property of {self.props['Name']} is locked (it was destroyed)")
        self.world.prop_writes.add((self.cls, key))
        if key == "Parent":
            self.set_parent(value)
            return
        if key == "Position" and isinstance(self.props.get("CFrame"), CFrame) and isinstance(value, Vector3):
            self.props["CFrame"] = CFrame(value, self.props["CFrame"].r)
            return
        self.props[key] = value
        changed = self.signals.get("prop:" + key)
        if changed:
            changed.fire()

    def descendants(self):
        for child in self.children:
            yield child
            yield from child.descendants()


def _find_first_child(inst, name, recursive=None):
    child = inst.find(name)
    if child is None and recursive:
        for each in inst.descendants():
            if each.props.get("Name") == name:
                return each
    return child


def _is_a(inst, cls):
    return cls == inst.cls or cls == "Instance" or cls in BASE_CLASSES.get(inst.cls, ())


def _destroy(inst):
    inst.set_parent(None)
    inst.destroyed = True
    for child in list(inst.children):
        _destroy(child)


def _get_pivot(inst):
    """A part's pivot is its CFrame times its PivotOffset; a model's is its PrimaryPart's (or the last PivotTo)."""
    if isinstance(inst.props.get("CFrame"), CFrame):
        offset = inst.props.get("PivotOffset")
        return inst.props["CFrame"].lua_arith("mul", inst.props["CFrame"], offset) if isinstance(offset, CFrame) else inst.props["CFrame"]
    primary = inst.props.get("PrimaryPart")
    if isinstance(primary, Inst):
        return _get_pivot(primary)
    return inst.props.get("_pivot") or CFrame()


def _pivot_to(inst, cframe):
    """Moves the part, or every part of the model, rigidly so that the pivot lands on cframe."""
    old = _get_pivot(inst)
    move = cframe.lua_arith("mul", cframe, old.m_Inverse())
    parts = [inst] if isinstance(inst.props.get("CFrame"), CFrame) else [d for d in inst.descendants() if isinstance(d.props.get("CFrame"), CFrame)]
    for part in parts:
        part.props["CFrame"] = move.lua_arith("mul", move, part.props["CFrame"])
    inst.props["_pivot"] = cframe


def _set_attribute(inst, key, value):
    if isinstance(value, LuaTable) or type_name(value) == "function":
        raise LuaError(f"SetAttribute: {type_name(value)} is not a supported attribute type")
    inst.attrs[key] = value
    inst.world.attr_writes[key] = inst.world.attr_writes.get(key, 0) + 1
    if "AttributeChanged" in inst.signals:
        inst.signals["AttributeChanged"].fire(key)


def _fire_remote(kind):
    def fire(inst, *args):
        inst.world.remote_log.append((kind, inst.props["Name"], list(args)))
    return fire


METHODS = {
    "SetAttribute": _set_attribute,
    "GetAttribute": lambda inst, key: inst.attrs.get(key),
    "GetAttributes": lambda inst: LuaTable(dict(inst.attrs)),
    "FindFirstChild": _find_first_child,
    "WaitForChild": lambda inst, name, timeout=None: inst.find(name),
    "FindFirstChildOfClass": lambda inst, cls: next((c for c in inst.children if c.cls == cls), None),
    "FindFirstChildWhichIsA": lambda inst, cls: next((c for c in inst.children if _is_a(c, cls)), None),
    "GetChildren": lambda inst: LuaTable(list(inst.children)),
    "GetDescendants": lambda inst: LuaTable(list(inst.descendants())),
    "IsA": _is_a,
    "Destroy": _destroy,
    "ClearAllChildren": lambda inst: [_destroy(child) for child in list(inst.children)] and None,
    "PivotTo": lambda inst, cframe: _pivot_to(inst, cframe),
    "GetPivot": lambda inst: _get_pivot(inst),
    "GetPropertyChangedSignal": lambda inst, name: inst.signal("prop:" + name),
    "GetAttributeChangedSignal": lambda inst, name: inst.signal("attr:" + name),
    "Fire": lambda inst, *args: inst.signal("Event").fire(*args),
    "FireClient": _fire_remote("client"),
    "FireAllClients": _fire_remote("all"),
    "FireServer": _fire_remote("server"),
}


class ScriptRef:
    """A script, module or folder of the Rojo tree, addressed by its path on disk."""
    lua_type = "Instance"

    def __init__(self, world, path, parent=None, name=None):
        self.world, self.path, self.parent = world, path, parent
        self.name = name or os.path.basename(path).split(".")[0]
        self.is_dir = os.path.isdir(path)

    def __repr__(self):
        return f"<script {self.path}>"

    def child(self, name):
        if not self.is_dir:
            return None
        if self.world.child_filter and not self.world.child_filter(self, name):
            return None
        folder = os.path.join(self.path, name)
        if os.path.isdir(folder):
            return ScriptRef(self.world, folder, self)
        module = os.path.join(self.path, name + ".luau")
        if os.path.isfile(module):
            return ScriptRef(self.world, module, self)
        return None

    def children(self):
        names = set()
        for entry in sorted(os.listdir(self.path)) if self.is_dir else []:
            if entry.startswith("init.") or entry.startswith("."):
                continue
            names.add(entry.split(".")[0])
        found = [self.child(name) for name in sorted(names)]
        return [each for each in found if each is not None]

    def lua_index(self, vm, key):
        if key == "Parent":
            return self.parent
        if key == "Name":
            return self.name
        if key in ("FindFirstChild", "WaitForChild"):
            return lambda _self, name, _timeout=None: self.child(name)
        if key == "GetChildren":
            return lambda _self: LuaTable(self.children())
        if key == "IsA":
            return lambda _self, cls: (cls == "ModuleScript" and not self.is_dir) or (cls == "Folder" and self.is_dir)
        found = self.child(key)
        if found is None:
            vm.error(f"{key} is not a valid member of {self.name} ({self.path})")
        return found

    def lua_eq(self, other):
        return isinstance(other, ScriptRef) and other.path == self.path


# -- JSON and data stores ---------------------------------------------------------------------------
def to_json(value, what="value"):
    if isinstance(value, LuaTable):
        keys = list(value.d.keys())
        n = value.length()
        if len(keys) == n:
            return [to_json(value.d[i], what) for i in range(1, n + 1)]
        out = {}
        for key in keys:
            if not isinstance(key, str):
                raise LuaError(f"{what}: a table with both list entries and other keys ({tostring(key)!r}) cannot be stored")
            out[key] = to_json(value.d[key], what)
        return out
    if is_number(value):
        if value != value or value in (math.inf, -math.inf):
            raise LuaError(f"{what}: {value} cannot be stored")
        return int(value) if value == int(value) and abs(value) < 2 ** 53 else value
    if value is None or isinstance(value, (bool, str)):
        return value
    raise LuaError(f"{what}: a {type_name(value)} cannot be stored")


def from_json(value):
    if isinstance(value, list):
        return LuaTable([from_json(item) for item in value])
    if isinstance(value, dict):
        return LuaTable({key: from_json(item) for key, item in value.items()})
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return value
    return float(value)


class DataStore:
    lua_type = "Instance"

    def __init__(self, world, name):
        self.world, self.name, self.rows = world, name, {}

    def lua_index(self, vm, key):
        if key == "GetAsync":
            return lambda _self, k: from_json(json.loads(self.rows[k])) if k in self.rows else None
        if key == "SetAsync":
            def set_async(_self, k, value):
                self.rows[k] = json.dumps(to_json(value, f"DataStore {self.name}"))
            return set_async
        if key == "UpdateAsync":
            def update_async(_self, k, fn):
                current = from_json(json.loads(self.rows[k])) if k in self.rows else None
                values = vm.call(fn, [current, None])
                new = values[0] if values else None
                if new is not None:
                    self.rows[k] = json.dumps(to_json(new, f"DataStore {self.name}"))
                return [new]
            return update_async
        if key == "GetSortedAsync":
            def get_sorted(_self, ascending, size):
                pages = Inst(self.world, "DataStorePages")
                pages.methods["GetCurrentPage"] = lambda _p: LuaTable()
                return pages
            return get_sorted
        vm.error(f"{key} is not a valid member of DataStore")


class LuaRandom(Value):
    lua_type = "Random"

    def __init__(self, world, seed=None):
        import random
        self.rng = random.Random(seed if seed is not None else 12345)

    def m_NextNumber(self, low=0.0, high=1.0):
        return low + (high - low) * self.rng.random()

    def m_NextInteger(self, low, high):
        return float(self.rng.randint(int(low), int(high)))


# -- the world --------------------------------------------------------------------------------------
class World:
    def __init__(self, root, side="server"):
        self.vm = VM()
        self.root = root
        self.prop_writes = set()
        self.attr_writes = {}
        self.remote_log = []
        self.modules = {}
        self.child_filter = None
        self.close_handlers = []
        self.stores = {}
        self.studio = True
        vm = self.vm
        g = vm.globals

        self.game = Inst(self, "DataModel", "game")
        self.workspace = Inst(self, "Workspace", "Workspace")
        self.workspace.methods["GetServerTimeNow"] = lambda _self: vm.now
        self.workspace.set_parent(self.game)
        self.services = {}
        for name in ("ReplicatedStorage", "Players", "RunService", "HttpService", "MarketplaceService",
                     "DataStoreService", "TweenService", "UserInputService", "ProximityPromptService", "Lighting",
                     "ServerScriptService", "StarterPlayer", "PolicyService", "TextService", "Debris", "SoundService"):
            self.services[name] = Inst(self, name, name)
            self.services[name].set_parent(self.game)
        def get_service(_self, name):
            if name not in self.services:
                self.services[name] = Inst(self, name, name)
                self.services[name].set_parent(self.game)
            return self.services[name]

        self.game.methods["GetService"] = get_service

        def create_tween(_self, target, info, goals):
            tween = Inst(self, "Tween")
            def play(_tween):
                for key, value in goals.d.items():
                    target.lua_newindex(self.vm, key, value)
                tween.signal("Completed").fire()
            tween.methods["Play"] = play
            tween.methods["Cancel"] = lambda _tween: None
            return tween

        self.services["TweenService"].methods["Create"] = create_tween
        self.services["PolicyService"].methods["GetPolicyInfoForPlayerAsync"] = lambda _self, player: LuaTable()
        self.game.methods["BindToClose"] = lambda _self, fn: self.close_handlers.append(fn)
        self.game.props["JobId"] = ""
        self.game.props["PlaceId"] = 0.0
        self.game.extras["Workspace"] = self.workspace

        shared = ScriptRef(self, os.path.join(root, "src", "shared"), None, "Shared")
        self.services["ReplicatedStorage"].extras["Shared"] = shared
        self.server_script = ScriptRef(self, os.path.join(root, "src", "server"), None, "Server")
        self.client_script = ScriptRef(self, os.path.join(root, "src", "client"), None, "Client")

        http = self.services["HttpService"]
        http.methods["JSONEncode"] = lambda _self, value: json.dumps(to_json(value, "JSONEncode"), ensure_ascii=False)
        http.methods["JSONDecode"] = lambda _self, text: from_json(json.loads(text))
        http.methods["GenerateGUID"] = lambda _self, braces=None: "guid"

        run = self.services["RunService"]
        run.methods["IsStudio"] = lambda _self: self.studio
        run.methods["IsServer"] = lambda _self: side == "server"
        run.methods["IsClient"] = lambda _self: side == "client"

        players = self.services["Players"]
        players.methods["GetPlayers"] = lambda _self: LuaTable([c for c in players.children if c.cls == "Player"])
        players.methods["GetPlayerByUserId"] = lambda _self, user_id: next(
            (c for c in players.children if c.props.get("UserId") == user_id), None)
        players.methods["GetNameFromUserIdAsync"] = lambda _self, user_id: f"Player{int(user_id)}"

        stores = self.services["DataStoreService"]

        def get_store(_self, name, scope=None):
            if name not in self.stores:
                self.stores[name] = DataStore(self, name)
            return self.stores[name]

        stores.methods["GetDataStore"] = get_store
        stores.methods["GetOrderedDataStore"] = get_store

        market = self.services["MarketplaceService"]
        market.methods["UserOwnsGamePassAsync"] = lambda _self, user_id, pass_id: False
        market.methods["PromptGamePassPurchase"] = lambda _self, player, pass_id: None
        market.methods["PromptProductPurchase"] = lambda _self, player, product_id: None

        def new_instance(cls, parent=None):
            inst = Inst(self, cls)
            if cls == "ProximityPrompt":
                inst.props.update({"Enabled": True})
            if parent is not None:
                inst.set_parent(parent)
            return inst

        def number_args(name, count):
            def check(*args):
                for arg in args[:count]:
                    if not is_number(arg):
                        raise LuaError(f"{name}: number expected, got {type_name(arg)}")
            return check

        def cframe_new(*args):
            if not args:
                return CFrame()
            if isinstance(args[0], Vector3):
                if len(args) > 1 and isinstance(args[1], Vector3):
                    return CFrame.look_at(args[0], args[1])
                return CFrame(args[0])
            number_args("CFrame.new", 3)(*args)
            return CFrame(Vector3(*args[:3]))

        def vector3_new(x=0.0, y=0.0, z=0.0):
            number_args("Vector3.new", 3)(x, y, z)
            return Vector3(x, y, z)

        g.update({
            "game": self.game,
            "workspace": self.workspace,
            "Instance": Namespace("Instance", {"new": new_instance}),
            "Enum": EnumNode("Enum"),
            "Color3": Namespace("Color3", {
                "fromRGB": lambda r, gr, b: Color3(r / 255, gr / 255, b / 255),
                "new": lambda r=0.0, gr=0.0, b=0.0: Color3(r, gr, b),
                "fromHSV": lambda h, s, v: Color3(v, v, v),
            }),
            "Vector3": Namespace("Vector3", {
                "new": vector3_new, "zero": Vector3(), "one": Vector3(1, 1, 1),
                "xAxis": Vector3(1, 0, 0), "yAxis": Vector3(0, 1, 0), "zAxis": Vector3(0, 0, 1),
            }),
            "Vector2": Namespace("Vector2", {"new": lambda x=0.0, y=0.0: Vector2(x, y), "zero": Vector2(), "one": Vector2(1, 1)}),
            "UDim": Namespace("UDim", {"new": lambda s=0.0, o=0.0: UDim(s, o)}),
            "UDim2": Namespace("UDim2", {
                "new": lambda xs=0.0, xo=0.0, ys=0.0, yo=0.0: UDim2(xs, xo, ys, yo),
                "fromOffset": lambda x, y: UDim2(0, x, 0, y),
                "fromScale": lambda x, y: UDim2(x, 0, y, 0),
            }),
            "CFrame": Namespace("CFrame", {
                "new": cframe_new,
                "lookAt": lambda eye, target, up=None: CFrame.look_at(eye, target, up),
                "Angles": lambda rx, ry, rz: CFrame.angles(rx, ry, rz),
                "identity": CFrame(),
            }),
            "Random": Namespace("Random", {"new": lambda seed=None: LuaRandom(self, seed)}),
            "ColorSequence": Namespace("ColorSequence", {"new": lambda *args: Inst(self, "ColorSequence")}),
            "NumberSequence": Namespace("NumberSequence", {"new": lambda *args: Inst(self, "NumberSequence")}),
            "NumberSequenceKeypoint": Namespace("NumberSequenceKeypoint", {"new": lambda *args: Inst(self, "NumberSequenceKeypoint")}),
            "ColorSequenceKeypoint": Namespace("ColorSequenceKeypoint", {"new": lambda *args: Inst(self, "ColorSequenceKeypoint")}),
            "NumberRange": Namespace("NumberRange", {"new": lambda *args: Inst(self, "NumberRange")}),
            "TweenInfo": Namespace("TweenInfo", {"new": lambda *args: Inst(self, "TweenInfo")}),
            "require": self.require,
            "coroutine": LuaTable({
                "running": lambda: "thread",
                "yield": lambda *args: (_ for _ in ()).throw(LuaError("coroutine.yield is not simulated")),
            }),
        })

    def require(self, ref=None):
        if not isinstance(ref, ScriptRef):
            self.vm.error(f"require needs a ModuleScript, got {type_name(ref)}")
        path = ref.path
        if ref.is_dir:
            path = next((os.path.join(ref.path, init) for init in ("init.luau", "init.server.luau", "init.client.luau")
                         if os.path.isfile(os.path.join(ref.path, init))), None)
            if path is None:
                self.vm.error(f"{ref.path} is a folder, not a module")
        if path not in self.modules:
            self.modules[path] = None  # a module required while it is still loading sees nil, like a cycle would fail
            values = self.run_file(path, ref)
            if not values:
                self.vm.error(f"module {path} did not return a value")
            self.modules[path] = values[0]
        return self.modules[path]

    def run_file(self, path, ref):
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        return self.vm.load(text, os.path.relpath(path, self.root), {"script": ref})

    def add_player(self, user_id, name):
        player = Inst(self, "Player", name)
        player.props.update({"UserId": float(user_id), "DisplayName": name, "Character": None})
        player.methods["RequestStreamAroundAsync"] = lambda _self, position, timeout=None: None
        player.methods["Kick"] = lambda _self, message=None: self.vm.output.append(f"KICK {name}: {message}")
        player.set_parent(self.services["Players"])
        self.services["Players"].signal("PlayerAdded").fire(player)
        return player

    def remove_player(self, player):
        self.services["Players"].signal("PlayerRemoving").fire(player)
        player.set_parent(None)

    def heartbeat(self, dt):
        self.vm.advance_time(dt)
        self.services["RunService"].signal("Heartbeat").fire(dt)
        self.services["RunService"].signal("RenderStepped").fire(dt)

    def advance(self, seconds, step=0.05):
        """Runs the server loop for a while."""
        for _ in range(int(round(seconds / step))):
            self.heartbeat(step)
