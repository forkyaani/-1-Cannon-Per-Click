"""A small tree-walking interpreter for the Luau this project uses. Enough of the language and standard
library to run the game's own modules against mocked Roblox services (see roblox_mock.py)."""
import functools
import math
import random
import re
import string as pystring
import sys
import threading

sys.setrecursionlimit(20000)
threading.stack_size(256 * 1024 * 1024)

from luau_ast import parse


class LuaError(Exception):
    def __init__(self, value, where=""):
        super().__init__(f"{where}: {value}" if where else str(value))
        self.value = value
        self.where = where


class BreakSignal(Exception):
    pass


class ContinueSignal(Exception):
    pass


class ReturnSignal(Exception):
    def __init__(self, values):
        self.values = values


class ThreadStop(Exception):
    """A thread that yields and is never resumed in this simulation."""


class LuaThread:
    def __init__(self):
        self.signal = threading.Event()  # set whenever this thread parks or finishes
        self.resume = threading.Event()  # set to let a parked thread run again
        self.wake = 0.0
        self.finished = False


class LuaTable:
    __slots__ = ("d", "meta")

    def __init__(self, items=None):
        self.d = {}
        self.meta = None
        if items:
            if isinstance(items, dict):
                self.d.update(items)
            else:
                for index, value in enumerate(items, 1):
                    self.d[index] = value

    def length(self):
        n = 0
        d = self.d
        while (n + 1) in d:
            n += 1
        return n

    def array(self):
        return [self.d[i] for i in range(1, self.length() + 1)]

    def keys_in_order(self):
        n = self.length()
        ordered = list(range(1, n + 1))
        for key in self.d:
            if not (isinstance(key, (int, float)) and not isinstance(key, bool) and 1 <= key <= n and key == int(key)):
                ordered.append(key)
        return ordered

    def __repr__(self):
        return f"<table {len(self.d)}>"


class LuaFunction:
    __slots__ = ("params", "vararg", "body", "env", "name", "file")

    def __init__(self, params, vararg, body, env, name, file):
        self.params = params
        self.vararg = vararg
        self.body = body
        self.env = env
        self.name = name
        self.file = file

    def __repr__(self):
        return f"<function {self.name}>"


class Env:
    __slots__ = ("vars", "parent")

    def __init__(self, parent=None):
        self.vars = {}
        self.parent = parent


def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def truthy(value):
    return value is not None and value is not False


def lua_eq(a, b):
    if isinstance(a, bool) or isinstance(b, bool):
        return a is b
    if a is None or b is None:
        return a is b
    if hasattr(a, "lua_eq"):
        return a.lua_eq(b)
    return a == b if type(a) is type(b) or (is_number(a) and is_number(b)) else False


def type_name(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "boolean"
    if is_number(value):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, LuaTable):
        return "table"
    if isinstance(value, LuaFunction) or callable(value):
        return "function"
    return getattr(value, "lua_type", "userdata")


def tostring(value):
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if is_number(value):
        if value != value:
            return "nan"
        if value in (math.inf, -math.inf):
            return "inf" if value > 0 else "-inf"
        if value == int(value) and abs(value) < 1e15:
            return str(int(value))
        return "%.14g" % value
    if isinstance(value, str):
        return value
    if isinstance(value, LuaTable):
        return "table: 0x%08x" % (id(value) & 0xFFFFFFFF)
    if isinstance(value, LuaFunction) or callable(value):
        return "function"
    return str(value)


# -- Lua patterns -> Python regular expressions ----------------------------------------------------
CLASSES = {
    "a": "A-Za-z", "d": "0-9", "l": "a-z", "u": "A-Z", "s": " \\t\\n\\r\\f\\v", "w": "A-Za-z0-9", "x": "A-Fa-f0-9",
    "p": re.escape(pystring.punctuation), "c": "\\x00-\\x1f",
}


@functools.lru_cache(maxsize=None)
def lua_pattern(pattern):
    out = []
    i = 0
    n = len(pattern)
    if pattern.startswith("^"):
        out.append("\\A")
        i = 1
    while i < n:
        ch = pattern[i]
        if ch == "%":
            nxt = pattern[i + 1]
            lower = nxt.lower()
            if lower in CLASSES and nxt.isalpha():
                out.append(("[^%s]" if nxt.isupper() else "[%s]") % CLASSES[lower])
            elif nxt.isdigit():
                out.append("\\" + nxt)
            else:
                out.append(re.escape(nxt))
            i += 2
        elif ch == "[":
            j = i + 1
            body = []
            if pattern[j] == "^":
                body.append("^")
                j += 1
            first = True
            while pattern[j] != "]" or first:
                first = False
                if pattern[j] == "%":
                    nxt = pattern[j + 1]
                    if nxt.lower() in CLASSES and nxt.isalpha():
                        if nxt.isupper():
                            raise NotImplementedError("complement class inside a set")
                        body.append(CLASSES[nxt])
                    else:
                        body.append(re.escape(nxt))
                    j += 2
                else:
                    body.append("\\" + pattern[j] if pattern[j] in "\\[]" else pattern[j])
                    j += 1
            out.append("[" + "".join(body) + "]")
            i = j + 1
        elif ch == ".":
            out.append("(?s:.)")
            i += 1
        elif ch == "-":
            out.append("*?")
            i += 1
        elif ch in "*+?()":
            out.append(ch)
            i += 1
        elif ch == "$" and i == n - 1:
            out.append("\\Z")
            i += 1
        else:
            out.append(re.escape(ch))
            i += 1
    return re.compile("".join(out))


FORMAT_RE = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[a-zA-Z%]")


class VM:
    def __init__(self):
        self.globals = {}
        self.file = "?"
        self.line = 0
        self.stack = []  # (file, function name, line of the call)
        self.now = 1_790_000_000.0  # unix time: 21 Sep 2026, inside the Halloween event
        self.clock = 100.0
        self.deferred = []
        self.sleepers = []
        self.threads = {}  # Python thread id -> LuaThread
        self.rng = random.Random(7)
        self.output = []  # print / warn lines
        self.install_stdlib()

    # -- errors ----------------------------------------------------------------------------------
    def where(self):
        return f"{self.file}:{self.line}"

    def error(self, message):
        trace = " <- ".join(f"{f}:{l} in {n}" for f, n, l in reversed(self.stack[-6:]))
        raise LuaError(message, f"{self.where()}" + (f" [{trace}]" if trace else ""))

    # -- running ---------------------------------------------------------------------------------
    def load(self, text, file, extra=None):
        """Runs a chunk and returns what it returned."""
        body = parse(text)
        env = Env()
        if extra:
            env.vars.update(extra)
        saved = (self.file, self.line)
        self.file = file
        try:
            self.exec_block(body, env)
        except ReturnSignal as signal:
            return signal.values
        finally:
            self.file, self.line = saved
        return []

    def call(self, fn, args):
        if isinstance(fn, LuaFunction):
            env = Env(fn.env)
            params = fn.params
            for index, name in enumerate(params):
                env.vars[name] = args[index] if index < len(args) else None
            if fn.vararg:
                env.vars["..."] = list(args[len(params):])
            self.stack.append((self.file, fn.name, self.line))
            if len(self.stack) > 180:
                self.stack.pop()
                self.error("stack overflow")
            saved = (self.file, self.line)
            self.file = fn.file
            try:
                self.exec_statements(fn.body, env)
            except ReturnSignal as signal:
                return signal.values
            finally:
                self.file, self.line = saved
                self.stack.pop()
            return []
        if hasattr(fn, "lua_call"):
            return self.results(fn.lua_call(self, args))
        if callable(fn):
            return self.results(fn(*args))
        self.error(f"attempt to call a {type_name(fn)} value")

    @staticmethod
    def results(value):
        if value is None:
            return []
        if isinstance(value, (list, tuple)):
            return list(value)
        return [value]

    def exec_block(self, statements, env):
        self.exec_statements(statements, Env(env))

    def exec_statements(self, statements, env):
        for statement in statements:
            self.exec(statement, env)

    def exec(self, node, env):
        kind = node[0]
        self.line = node[1]
        if kind == "local":
            values = self.eval_list(node[3], env)
            for index, name in enumerate(node[2]):
                env.vars[name] = values[index] if index < len(values) else None
        elif kind == "localfunction":
            env.vars[node[2]] = None
            env.vars[node[2]] = self.eval(node[3], env)
        elif kind == "assign":
            values = self.eval_list(node[3], env)
            for index, target in enumerate(node[2]):
                self.assign(target, values[index] if index < len(values) else None, env)
        elif kind == "compound":
            target = node[2]
            if target[0] == "index":
                obj = self.eval(target[2], env)
                key = self.eval(target[3], env)
                self.line = node[1]
                current = self.index(obj, key)
                self.setindex(obj, key, self.binop(node[3], current, self.eval(node[4], env)))
            else:
                self.assign(target, self.binop(node[3], self.eval(target, env), self.eval(node[4], env)), env)
        elif kind == "callstat":
            self.eval_multi(node[2], env)
        elif kind == "if":
            for cond, block in node[2]:
                if truthy(self.eval(cond, env)):
                    self.exec_block(block, env)
                    return
            if node[3] is not None:
                self.exec_block(node[3], env)
        elif kind == "do":
            self.exec_block(node[2], env)
        elif kind == "while":
            while truthy(self.eval(node[2], env)):
                try:
                    self.exec_block(node[3], env)
                except BreakSignal:
                    break
                except ContinueSignal:
                    pass
        elif kind == "repeat":
            while True:
                inner = Env(env)
                try:
                    self.exec_statements(node[2], inner)
                except BreakSignal:
                    break
                except ContinueSignal:
                    pass
                if truthy(self.eval(node[3], inner)):
                    break
        elif kind == "fornum":
            start = self.eval(node[3], env)
            stop = self.eval(node[4], env)
            step = self.eval(node[5], env) if node[5] is not None else 1
            if not (is_number(start) and is_number(stop) and is_number(step)):
                self.error("'for' limits must be numbers")
            value = start
            while (step > 0 and value <= stop) or (step < 0 and value >= stop):
                inner = Env(env)
                inner.vars[node[2]] = value
                try:
                    self.exec_statements(node[6], inner)
                except BreakSignal:
                    break
                except ContinueSignal:
                    pass
                value += step
        elif kind == "forin":
            self.for_in(node, env)
        elif kind == "return":
            raise ReturnSignal(self.eval_list(node[2], env))
        elif kind == "break":
            raise BreakSignal()
        elif kind == "continue":
            raise ContinueSignal()
        else:
            raise RuntimeError(f"unknown statement {kind}")

    def for_in(self, node, env):
        names, body = node[2], node[4]
        values = self.eval_list(node[3], env)
        first = values[0] if values else None
        self.line = node[1]

        def run(items):
            inner = Env(env)
            for index, name in enumerate(names):
                inner.vars[name] = items[index] if index < len(items) else None
            try:
                self.exec_statements(body, inner)
            except ContinueSignal:
                pass

        try:
            if isinstance(first, LuaTable):
                for key in first.keys_in_order():
                    value = first.d.get(key)
                    if value is not None:
                        run([float(key) if isinstance(key, int) and not isinstance(key, bool) else key, value])
            elif hasattr(first, "lua_iter"):
                for items in first.lua_iter():
                    run(items)
            elif isinstance(first, LuaFunction) or callable(first):
                state = values[1] if len(values) > 1 else None
                control = values[2] if len(values) > 2 else None
                while True:
                    items = self.call(first, [state, control])
                    if not items or items[0] is None:
                        break
                    control = items[0]
                    run(items)
            else:
                self.error(f"attempt to iterate over a {type_name(first)} value")
        except BreakSignal:
            pass

    def assign(self, target, value, env):
        kind = target[0]
        if kind == "name":
            name = target[2]
            scope = env
            while scope is not None:
                if name in scope.vars:
                    scope.vars[name] = value
                    return
                scope = scope.parent
            self.globals[name] = value
        elif kind == "index":
            obj = self.eval(target[2], env)
            key = self.eval(target[3], env)
            self.line = target[1]
            self.setindex(obj, key, value)
        else:
            self.error("cannot assign to this expression")

    # -- expressions -----------------------------------------------------------------------------
    def eval_list(self, nodes, env):
        values = []
        last = len(nodes) - 1
        for index, node in enumerate(nodes):
            if index == last:
                values.extend(self.eval_multi(node, env))
            else:
                values.append(self.eval(node, env))
        return values

    def eval_multi(self, node, env):
        kind = node[0]
        if kind == "call":
            fn = self.eval(node[2], env)
            args = self.eval_list(node[3], env)
            self.line = node[1]
            if fn is None:
                self.error(f"attempt to call a nil value ({self.describe(node[2])})")
            return self.call(fn, args)
        if kind == "method":
            obj = self.eval(node[2], env)
            self.line = node[1]
            if obj is None:
                self.error(f"attempt to index nil with '{node[3]}' ({self.describe(node[2])})")
            fn = self.index(obj, node[3])
            args = [obj] + self.eval_list(node[4], env)
            self.line = node[1]
            if fn is None:
                self.error(f"attempt to call missing method '{node[3]}' of {self.describe(node[2])}")
            return self.call(fn, args)
        if kind == "vararg":
            scope = env
            while scope is not None:
                if "..." in scope.vars:
                    return list(scope.vars["..."])
                scope = scope.parent
            return []
        return [self.eval(node, env)]

    def describe(self, node):
        if node[0] == "name":
            return node[2]
        if node[0] == "index" and node[3][0] == "const":
            return f"{self.describe(node[2])}.{node[3][2]}"
        if node[0] == "method":
            return f"{self.describe(node[2])}:{node[3]}()"
        if node[0] == "call":
            return f"{self.describe(node[2])}()"
        return node[0]

    def eval(self, node, env):
        kind = node[0]
        if kind == "const":
            return node[2]
        if kind == "name":
            name = node[2]
            scope = env
            while scope is not None:
                if name in scope.vars:
                    return scope.vars[name]
                scope = scope.parent
            return self.globals.get(name)
        if kind == "index":
            obj = self.eval(node[2], env)
            key = self.eval(node[3], env)
            self.line = node[1]
            if obj is None:
                self.error(f"attempt to index nil with '{tostring(key)}' ({self.describe(node[2])})")
            return self.index(obj, key)
        if kind in ("call", "method", "vararg"):
            values = self.eval_multi(node, env)
            return values[0] if values else None
        if kind == "binop":
            left = self.eval(node[3], env)
            right = self.eval(node[4], env)
            self.line = node[1]
            return self.binop(node[2], left, right)
        if kind == "and":
            left = self.eval(node[2], env)
            return self.eval(node[3], env) if truthy(left) else left
        if kind == "or":
            left = self.eval(node[2], env)
            return left if truthy(left) else self.eval(node[3], env)
        if kind == "unop":
            value = self.eval(node[3], env)
            self.line = node[1]
            op = node[2]
            if op == "not":
                return not truthy(value)
            if op == "-":
                if is_number(value):
                    return -value
                if hasattr(value, "lua_arith"):
                    return value.lua_arith("unm", value, None)
                self.error(f"attempt to perform arithmetic (unm) on {type_name(value)}")
            if isinstance(value, str):
                return float(len(value.encode("utf-8")))
            if isinstance(value, LuaTable):
                return float(value.length())
            self.error(f"attempt to get length of a {type_name(value)} value")
        if kind == "function":
            return LuaFunction(node[2], node[3], node[4], env, node[5], self.file)
        if kind == "table":
            table = LuaTable()
            position = 1
            items = node[2]
            last = len(items) - 1
            for index, (item_kind, key, value) in enumerate(items):
                if item_kind == "pos":
                    if index == last:
                        for each in self.eval_multi(value, env):
                            if each is not None:
                                table.d[position] = each
                            position += 1
                    else:
                        result = self.eval(value, env)
                        if result is not None:
                            table.d[position] = result
                        position += 1
                else:
                    result_key = self.eval(key, env)
                    if result_key is None:
                        self.error("table index is nil")
                    result = self.eval(value, env)
                    if result is not None:
                        table.d[result_key] = result
            return table
        if kind == "interp":
            return "".join(tostring(self.eval(part, env)) for part in node[2])
        if kind == "ifexpr":
            for cond, value in node[2]:
                if truthy(self.eval(cond, env)):
                    return self.eval(value, env)
            return self.eval(node[3], env)
        if kind == "paren":
            return self.eval(node[2], env)
        raise RuntimeError(f"unknown expression {kind}")

    def index(self, obj, key):
        if isinstance(obj, LuaTable):
            value = obj.d.get(key)
            if value is None and obj.meta is not None:
                handler = obj.meta.d.get("__index")
                if isinstance(handler, LuaTable):
                    return self.index(handler, key)
                if handler is not None:
                    values = self.call(handler, [obj, key])
                    return values[0] if values else None
            return value
        if isinstance(obj, str):
            return self.globals["string"].d.get(key)
        if hasattr(obj, "lua_index"):
            return obj.lua_index(self, key)
        self.error(f"attempt to index {type_name(obj)} with '{tostring(key)}'")

    def setindex(self, obj, key, value):
        if isinstance(obj, LuaTable):
            if key is None:
                self.error("table index is nil")
            if isinstance(key, float) and key != key:
                self.error("table index is NaN")
            if value is None:
                obj.d.pop(key, None)
            else:
                obj.d[key] = value
        elif hasattr(obj, "lua_newindex"):
            obj.lua_newindex(self, key, value)
        else:
            self.error(f"attempt to index {type_name(obj)} with '{tostring(key)}' (assignment)")

    ARITH = {"+": "add", "-": "sub", "*": "mul", "/": "div", "//": "idiv", "%": "mod", "^": "pow"}

    def binop(self, op, left, right):
        if op in self.ARITH:
            if is_number(left) and is_number(right):
                try:
                    if op == "+":
                        return left + right
                    if op == "-":
                        return left - right
                    if op == "*":
                        return left * right
                    if op == "/":
                        if right == 0:
                            return math.nan if left == 0 or left != left else math.copysign(math.inf, left)
                        return left / right
                    if op == "//":
                        if right == 0:
                            return math.nan if left == 0 else math.copysign(math.inf, left)
                        return float(math.floor(left / right))
                    if op == "%":
                        if right == 0:
                            return math.nan
                        return left - math.floor(left / right) * right
                    return float(left) ** right
                except OverflowError:
                    return math.inf
            for side in (left, right):
                if hasattr(side, "lua_arith"):
                    return side.lua_arith(self.ARITH[op], left, right)
            self.error(f"attempt to perform arithmetic ({self.ARITH[op]}) on {type_name(left)} and {type_name(right)}")
        if op == "..":
            for side in (left, right):
                if not (isinstance(side, str) or is_number(side)):
                    self.error(f"attempt to concatenate {type_name(left)} with {type_name(right)}")
            return tostring(left) + tostring(right)
        if op == "==":
            return lua_eq(left, right)
        if op == "~=":
            return not lua_eq(left, right)
        if (is_number(left) and is_number(right)) or (isinstance(left, str) and isinstance(right, str)):
            if op == "<":
                return left < right
            if op == "<=":
                return left <= right
            if op == ">":
                return left > right
            return left >= right
        self.error(f"attempt to compare {type_name(left)} {op} {type_name(right)}")

    # -- standard library ------------------------------------------------------------------------
    def install_stdlib(self):
        vm = self
        g = self.globals

        def table_of(functions):
            return LuaTable(dict(functions))

        def check_table(value, name):
            if not isinstance(value, LuaTable):
                vm.error(f"{name}: table expected, got {type_name(value)}")
            return value

        def check_number(value, name):
            if not is_number(value):
                vm.error(f"{name}: number expected, got {type_name(value)}")
            return value

        def check_string(value, name):
            if is_number(value):
                return tostring(value)
            if not isinstance(value, str):
                vm.error(f"{name}: string expected, got {type_name(value)}")
            return value

        # string
        def s_format(fmt, *args):
            fmt = check_string(fmt, "string.format")
            args = list(args)
            position = [0]

            def replace(match):
                spec = match.group()
                kind = spec[-1]
                if kind == "%":
                    return "%"
                if position[0] >= len(args):
                    vm.error("string.format: missing argument")
                value = args[position[0]]
                position[0] += 1
                if kind in "di":
                    return (spec[:-1] + "d") % int(check_number(value, "string.format"))
                if kind in "xX":
                    return spec % int(check_number(value, "string.format"))
                if kind in "fgeE":
                    return spec % check_number(value, "string.format")
                if kind == "s":
                    return spec % tostring(value)
                vm.error(f"string.format: unsupported {spec}")

            return FORMAT_RE.sub(replace, fmt)

        def s_sub(s, i=1, j=-1):
            s = check_string(s, "string.sub")
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

        def expand(match, repl):
            def group(m):
                ch = m.group(1)
                if ch == "%":
                    return "%"
                index = int(ch)
                if index == 0:
                    return match.group(0)
                return match.group(index) or ""

            return re.sub(r"%([%0-9])", group, repl)

        def s_gsub(s, pattern, repl, limit=None):
            s = check_string(s, "string.gsub")
            regex = lua_pattern(check_string(pattern, "string.gsub"))
            count = [0]

            def replace(match):
                count[0] += 1
                whole = match.group(0)
                captures = list(match.groups()) or [whole]
                if isinstance(repl, str):
                    return expand(match, repl)
                if isinstance(repl, LuaTable):
                    value = repl.d.get(captures[0])
                else:
                    values = vm.call(repl, captures)
                    value = values[0] if values else None
                if value is None or value is False:
                    return whole
                return tostring(value)

            result = regex.sub(replace, s, count=int(limit) if limit is not None else 0)
            return [result, float(count[0])]

        def s_find(s, pattern, init=1, plain=None):
            s = check_string(s, "string.find")
            start = int(init) - 1 if init > 0 else max(len(s) + int(init), 0)
            if truthy(plain):
                at = s.find(pattern, start)
                return [float(at + 1), float(at + len(pattern))] if at >= 0 else [None]
            match = lua_pattern(pattern).search(s, start)
            if not match:
                return [None]
            return [float(match.start() + 1), float(match.end())] + list(match.groups())

        def s_match(s, pattern, init=1):
            s = check_string(s, "string.match")
            match = lua_pattern(pattern).search(s, int(init) - 1)
            if not match:
                return [None]
            return list(match.groups()) or [match.group(0)]

        def s_split(s, sep=","):
            return LuaTable(check_string(s, "string.split").split(sep))

        g["string"] = table_of({
            "format": s_format,
            "sub": s_sub,
            "gsub": s_gsub,
            "find": s_find,
            "match": s_match,
            "split": s_split,
            "lower": lambda s: check_string(s, "string.lower").lower(),
            "upper": lambda s: "".join(c.upper() if "a" <= c <= "z" else c for c in check_string(s, "string.upper")),
            "len": lambda s: float(len(check_string(s, "string.len").encode("utf-8"))),
            "rep": lambda s, n: check_string(s, "string.rep") * int(n),
            "reverse": lambda s: check_string(s, "string.reverse")[::-1],
            "byte": lambda s, i=1: float(ord(s[int(i) - 1])) if len(s) >= i else None,
            "char": lambda *codes: "".join(chr(int(code)) for code in codes),
        })

        # table
        def t_insert(t, *args):
            check_table(t, "table.insert")
            if len(args) == 1:
                if args[0] is not None:
                    t.d[t.length() + 1] = args[0]
            elif len(args) == 2:
                position, value = int(args[0]), args[1]
                n = t.length()
                for index in range(n, position - 1, -1):
                    t.d[index + 1] = t.d[index]
                t.d[position] = value
            else:
                vm.error("table.insert: wrong number of arguments")

        def t_remove(t, position=None):
            check_table(t, "table.remove")
            n = t.length()
            if n == 0:
                return None
            position = n if position is None else int(position)
            value = t.d.get(position)
            for index in range(position, n):
                t.d[index] = t.d[index + 1]
            t.d.pop(n, None)
            return [value]

        def t_concat(t, sep="", i=1, j=None):
            check_table(t, "table.concat")
            j = t.length() if j is None else int(j)
            parts = []
            for index in range(int(i), j + 1):
                value = t.d.get(index)
                if not (isinstance(value, str) or is_number(value)):
                    vm.error(f"table.concat: invalid value (a {type_name(value)}) at index {index}")
                parts.append(tostring(value))
            return sep.join(parts)

        def t_sort(t, comp=None):
            check_table(t, "table.sort")
            items = t.array()

            def less(a, b):
                if comp is None:
                    return vm.binop("<", a, b)
                values = vm.call(comp, [a, b])
                return truthy(values[0]) if values else False

            def compare(a, b):
                if less(a, b):
                    return -1
                if less(b, a):
                    return 1
                return 0

            items.sort(key=functools.cmp_to_key(compare))
            for index, value in enumerate(items, 1):
                t.d[index] = value

        def t_clone(t):
            clone = LuaTable()
            clone.d = dict(check_table(t, "table.clone").d)
            return clone

        def t_find(t, value, init=1):
            for index in range(int(init), check_table(t, "table.find").length() + 1):
                if lua_eq(t.d[index], value):
                    return float(index)
            return [None]

        def t_move(a1, f, e, t, a2=None):
            a2 = a2 or a1
            for offset in range(0, int(e) - int(f) + 1):
                value = a1.d.get(int(f) + offset)
                if value is None:
                    a2.d.pop(int(t) + offset, None)
                else:
                    a2.d[int(t) + offset] = value
            return a2

        def unpack(t, i=1, j=None):
            j = check_table(t, "unpack").length() if j is None else int(j)
            return [t.d.get(index) for index in range(int(i), j + 1)]

        g["table"] = table_of({
            "insert": t_insert, "remove": t_remove, "concat": t_concat, "sort": t_sort, "clone": t_clone,
            "find": t_find, "move": t_move, "unpack": unpack,
            "create": lambda n, value=None: LuaTable([value] * int(n)) if value is not None else LuaTable(),
            "clear": lambda t: t.d.clear(),
            "freeze": lambda t: t,
        })
        g["unpack"] = unpack

        # math
        def m_clamp(x, low, high):
            check_number(x, "math.clamp")
            check_number(low, "math.clamp")
            check_number(high, "math.clamp")
            if low > high:
                vm.error("math.clamp: max must be greater than or equal to min")
            return min(max(x, low), high)

        def m_floor(x):
            check_number(x, "math.floor")
            return x if x != x or x in (math.inf, -math.inf) else float(math.floor(x))

        def m_ceil(x):
            check_number(x, "math.ceil")
            return x if x != x or x in (math.inf, -math.inf) else float(math.ceil(x))

        def m_minmax(pick, name):
            def run(*values):
                if not values:
                    vm.error(f"{name}: missing argument")
                for value in values:
                    check_number(value, name)
                return pick(values)
            return run

        def m_log(x, base=None):
            check_number(x, "math.log")
            if x <= 0:
                return -math.inf if x == 0 else math.nan
            return math.log(x) if base is None else math.log(x, base)

        def m_random(low=None, high=None):
            if low is None:
                return vm.rng.random()
            if high is None:
                return float(vm.rng.randint(1, int(low)))
            return float(vm.rng.randint(int(low), int(high)))

        g["math"] = table_of({
            "floor": m_floor, "ceil": m_ceil, "clamp": m_clamp, "max": m_minmax(max, "math.max"),
            "min": m_minmax(min, "math.min"), "abs": lambda x: abs(check_number(x, "math.abs")),
            "sqrt": lambda x: math.sqrt(x) if x >= 0 else math.nan, "log": m_log,
            "log10": lambda x: math.log10(x) if x > 0 else (-math.inf if x == 0 else math.nan),
            "exp": math.exp, "pow": lambda a, b: float(a) ** b, "sin": math.sin, "cos": math.cos, "tan": math.tan,
            "atan2": math.atan2, "rad": math.radians, "deg": math.degrees, "huge": math.inf, "pi": math.pi,
            "random": m_random, "round": lambda x: float(math.floor(x + 0.5)),
            "sign": lambda x: 0.0 if x == 0 else math.copysign(1.0, x),
            "fmod": math.fmod,
        })

        # basics
        def l_tonumber(value, base=None):
            if is_number(value):
                return value
            if isinstance(value, str):
                try:
                    text = value.strip()
                    return float(int(text, int(base))) if base else float(int(text, 16)) if text.lower().startswith("0x") else float(text)
                except ValueError:
                    return [None]
            return [None]

        def l_assert(*args):
            if not args or not truthy(args[0]):
                vm.error(args[1] if len(args) > 1 else "assertion failed!")
            return list(args)

        def l_error(message=None, level=None):
            vm.error(message)

        def l_pcall(fn, *args):
            saved = (vm.file, vm.line, len(vm.stack))
            try:
                return [True] + vm.call(fn, list(args))
            except LuaError as problem:
                vm.file, vm.line = saved[0], saved[1]
                del vm.stack[saved[2]:]
                value = problem.value
                return [False, f"{problem.where}: {value}" if isinstance(value, str) else value]

        def l_xpcall(fn, handler, *args):
            result = l_pcall(fn, *args)
            if result[0]:
                return result
            handled = vm.call(handler, [result[1]])
            return [False] + handled

        def l_select(n, *args):
            if n == "#":
                return float(len(args))
            return list(args[int(n) - 1:])

        def l_next(t, key=None):
            keys = check_table(t, "next").keys_in_order()
            if key is None:
                position = 0
            else:
                position = keys.index(key) + 1
            if position >= len(keys):
                return [None]
            return [keys[position], t.d[keys[position]]]

        def l_ipairs(t):
            check_table(t, "ipairs")

            class Iter:
                def lua_iter(self):
                    index = 1
                    while index in t.d:
                        yield [float(index), t.d[index]]
                        index += 1
            return Iter()

        def l_pairs(t):
            check_table(t, "pairs")
            return t

        def l_setmetatable(t, meta):
            check_table(t, "setmetatable").meta = meta
            return t

        def l_print(*args):
            vm.output.append("print: " + " ".join(tostring(arg) for arg in args))

        def l_warn(*args):
            vm.output.append("WARN: " + " ".join(tostring(arg) for arg in args))

        g.update({
            "tostring": tostring, "tonumber": l_tonumber, "typeof": type_name, "type": type_name,
            "assert": l_assert, "error": l_error, "pcall": l_pcall, "xpcall": l_xpcall, "select": l_select,
            "next": l_next, "pairs": l_pairs, "ipairs": l_ipairs, "setmetatable": l_setmetatable,
            "getmetatable": lambda t: t.meta if isinstance(t, LuaTable) else None,
            "rawget": lambda t, k: t.d.get(k), "rawequal": lambda a, b: a is b,
            "print": l_print, "warn": l_warn,
        })

        def os_time(spec=None):
            return float(math.floor(vm.now))

        g["os"] = table_of({"time": os_time, "clock": lambda: vm.clock})
        g["debug"] = table_of({"traceback": lambda message=None, level=None: tostring(message) + "\n(traceback)"})

        # task: every spawned function is a thread of its own (a Python thread, with only one ever running).
        # A thread that waits is parked until advance_time reaches its wake-up time.
        def task_spawn(fn, *args):
            vm.spawn(fn, list(args))

        def task_wait(seconds=0):
            return vm.park(seconds or 0.03)

        def task_delay(seconds, fn, *args):
            def later():
                vm.park(seconds)
                vm.call(fn, list(args))
            vm.spawn(later, [])

        g["task"] = table_of({
            "spawn": task_spawn,
            "defer": lambda fn, *args: vm.deferred.append((fn, list(args))),
            "delay": task_delay,
            "wait": task_wait,
        })

    # -- threads ---------------------------------------------------------------------------------
    def context(self):
        return (self.file, self.line, list(self.stack))

    def restore(self, saved):
        self.file, self.line = saved[0], saved[1]
        self.stack[:] = saved[2]

    def spawn(self, fn, args):
        """Runs fn in a new thread until it finishes or parks, then carries on here."""
        thread = LuaThread()
        saved = self.context()

        def body():
            self.threads[threading.get_ident()] = thread
            self.stack[:] = []
            try:
                self.call(fn, args)
            except ThreadStop:
                pass
            except LuaError as problem:
                self.output.append(f"THREAD ERROR: {problem}")
            except Exception as problem:  # a bug in the simulator itself
                self.output.append(f"SIMULATOR ERROR: {type(problem).__name__}: {problem}")
            finally:
                thread.finished = True
                thread.signal.set()

        worker = threading.Thread(target=body, daemon=True)
        worker.start()
        thread.signal.wait()
        self.restore(saved)

    def park(self, seconds):
        thread = self.threads.get(threading.get_ident())
        if thread is None:
            # The simulation's own thread cannot be parked: time simply passes.
            self.clock += seconds
            self.now += seconds
            return seconds
        if seconds == math.inf:
            raise ThreadStop()
        saved = self.context()
        thread.wake = self.clock + seconds
        thread.resume.clear()
        self.sleepers.append(thread)
        thread.signal.set()
        thread.resume.wait()
        self.restore(saved)
        return seconds

    def advance_time(self, seconds):
        self.clock += seconds
        self.now += seconds
        self.run_deferred()
        while True:
            due = [thread for thread in self.sleepers if thread.wake <= self.clock + 1e-9]
            if not due:
                break
            thread = min(due, key=lambda each: each.wake)
            self.sleepers.remove(thread)
            saved = self.context()
            thread.signal.clear()
            thread.resume.set()
            thread.signal.wait()
            self.restore(saved)
            self.run_deferred()

    def run_deferred(self):
        while self.deferred:
            fn, args = self.deferred.pop(0)
            self.spawn(fn, args)
