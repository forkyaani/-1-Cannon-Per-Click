#!/usr/bin/env python3
"""A small Luau parser and tree-walking interpreter with Roblox mocks.

Scratch tooling only: no Luau toolchain is installed on this machine, so this is how the backpack/powerup
code gets parsed and exercised. It covers the syntax and library calls this project uses, not all of Luau.
Threads are not emulated: a function that yields (task.wait, WaitForChild on a missing child ...) is simply
abandoned at that point, which is enough for event-driven code.
"""
import functools
import json
import math
import os
import re
import sys

sys.setrecursionlimit(200000)

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil",
    "not", "or", "repeat", "return", "then", "true", "until", "while",
}
OPS3 = ("...", "..=", "//=")
OPS2 = ("==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "^=", "::", "..", "//", "->")
COMPOUND = {"+=": "+", "-=": "-", "*=": "*", "/=": "/", "//=": "//", "%=": "%", "^=": "^", "..=": ".."}
EOF = ("eof", "<eof>", 0)


class LuaSyntaxError(Exception):
    pass


class LuaError(Exception):
    def __init__(self, value, trace=None):
        super().__init__(value if isinstance(value, str) else repr(value))
        self.value = value
        self.trace = trace


class ThreadYield(BaseException):
    """Raised by anything that would yield; unwinds to the task.spawn / signal handler that started the thread."""


# ---------------------------------------------------------------------------------------------------
# Lexer
# ---------------------------------------------------------------------------------------------------
SIMPLE_ESC = {
    "n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", '"': '"',
    "'": "'", "`": "`", "{": "{", "}": "}", "\n": "\n",
}


def read_escape(src, pos, path, line):
    c = src[pos + 1]
    if c in SIMPLE_ESC:
        return SIMPLE_ESC[c], pos + 2
    if c == "x":
        return chr(int(src[pos + 2 : pos + 4], 16)), pos + 4
    if c == "u":
        m = re.match(r"\{([0-9a-fA-F]+)\}", src[pos + 2 :])
        return chr(int(m.group(1), 16)), pos + 2 + m.end()
    if c == "z":
        j = pos + 2
        while j < len(src) and src[j] in " \t\r\n":
            j += 1
        return "", j
    if c.isdigit():
        m = re.match(r"\d{1,3}", src[pos + 1 :])
        return chr(int(m.group(0))), pos + 1 + m.end()
    raise LuaSyntaxError(f"{path}:{line}: bad escape \\{c}")


def lex(src, path, pos=0, line=1, interp=False):
    """Returns (tokens, pos, line). With interp, stops at the '}' that closes the interpolation (not consumed)."""
    toks = []
    n = len(src)
    depth = 0
    while pos < n:
        c = src[pos]
        if c == "\n":
            line += 1
            pos += 1
        elif c in " \t\r":
            pos += 1
        elif src.startswith("--", pos):
            m = re.match(r"--\[(=*)\[", src[pos : pos + 40])
            if m:
                close = "]" + m.group(1) + "]"
                end = src.find(close, pos)
                if end < 0:
                    raise LuaSyntaxError(f"{path}:{line}: unterminated long comment")
                line += src.count("\n", pos, end)
                pos = end + len(close)
            else:
                end = src.find("\n", pos)
                pos = n if end < 0 else end
        elif c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[pos:])
            word = m.group(0)
            toks.append(("kw" if word in KEYWORDS else "name", word, line))
            pos += len(word)
        elif c.isdigit() or (c == "." and pos + 1 < n and src[pos + 1].isdigit()):
            m = re.match(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:[0-9][0-9_]*\.?[0-9_]*|\.[0-9][0-9_]*)(?:[eE][+-]?[0-9_]+)?", src[pos:])
            text = m.group(0).replace("_", "")
            if text[:2] in ("0x", "0X"):
                value = int(text, 16)
            elif text[:2] in ("0b", "0B"):
                value = int(text[2:], 2)
            else:
                value = float(text)
                if value.is_integer() and abs(value) < 2**53:
                    value = int(value)
            toks.append(("num", value, line))
            pos += len(m.group(0))
        elif c in "\"'":
            start = line
            buf = []
            pos += 1
            while True:
                if pos >= n or src[pos] == "\n":
                    raise LuaSyntaxError(f"{path}:{start}: unterminated string")
                ch = src[pos]
                if ch == c:
                    pos += 1
                    break
                if ch == "\\":
                    text, pos = read_escape(src, pos, path, line)
                    buf.append(text)
                else:
                    buf.append(ch)
                    pos += 1
            toks.append(("str", "".join(buf), start))
        elif c == "`":
            start = line
            parts, buf = [], []
            pos += 1
            while True:
                if pos >= n:
                    raise LuaSyntaxError(f"{path}:{start}: unterminated interpolated string")
                ch = src[pos]
                if ch == "`":
                    pos += 1
                    break
                if ch == "\\":
                    text, pos = read_escape(src, pos, path, line)
                    buf.append(text)
                elif ch == "{":
                    if src.startswith("{{", pos):
                        raise LuaSyntaxError(f"{path}:{line}: '{{{{' in an interpolated string")
                    if buf:
                        parts.append("".join(buf))
                        buf = []
                    inner, pos, line = lex(src, path, pos + 1, line, True)
                    if pos >= n or src[pos] != "}":
                        raise LuaSyntaxError(f"{path}:{start}: unterminated interpolation")
                    if not inner:
                        raise LuaSyntaxError(f"{path}:{line}: empty interpolation")
                    pos += 1
                    inner.append(EOF)
                    parts.append(inner)
                else:
                    if ch == "\n":
                        line += 1
                    buf.append(ch)
                    pos += 1
            if buf:
                parts.append("".join(buf))
            toks.append(("istr", parts, start))
        elif c == "[" and re.match(r"\[=*\[", src[pos : pos + 40]):
            m = re.match(r"\[(=*)\[", src[pos : pos + 40])
            close = "]" + m.group(1) + "]"
            end = src.find(close, pos)
            if end < 0:
                raise LuaSyntaxError(f"{path}:{line}: unterminated long string")
            text = src[pos + len(m.group(0)) : end]
            if text.startswith("\n"):
                text = text[1:]
            toks.append(("str", text, line))
            line += src.count("\n", pos, end)
            pos = end + len(close)
        else:
            op = None
            for cand in OPS3:
                if src.startswith(cand, pos):
                    op = cand
                    break
            if not op:
                for cand in OPS2:
                    if src.startswith(cand, pos):
                        op = cand
                        break
            if not op:
                op = c
                if c not in "+-*/%^#<>=(){}[];:,.|&?":
                    raise LuaSyntaxError(f"{path}:{line}: unexpected character {c!r}")
            if interp:
                if op == "{":
                    depth += 1
                elif op == "}":
                    if depth == 0:
                        return toks, pos, line
                    depth -= 1
            toks.append(("op", op, line))
            pos += len(op)
    return toks, pos, line


# ---------------------------------------------------------------------------------------------------
# Parser. Nodes are tuples; types are parsed and thrown away.
# ---------------------------------------------------------------------------------------------------
BINPRI = {
    "or": (1, 1), "and": (2, 2), "<": (3, 3), ">": (3, 3), "<=": (3, 3), ">=": (3, 3), "~=": (3, 3),
    "==": (3, 3), "..": (9, 8), "+": (10, 10), "-": (10, 10), "*": (11, 11), "/": (11, 11), "//": (11, 11),
    "%": (11, 11), "^": (14, 13),
}
UNARY_PRI = 12
BLOCK_END = {"end", "else", "elseif", "until"}


class Parser:
    def __init__(self, toks, path):
        self.t = toks
        self.i = 0
        self.path = path

    def peek(self, k=0):
        i = self.i + k
        return self.t[i] if i < len(self.t) else EOF

    def next(self):
        tok = self.t[self.i]
        self.i += 1
        return tok

    def check(self, typ, val=None):
        tok = self.t[self.i]
        return tok[0] == typ and (val is None or tok[1] == val)

    def accept(self, typ, val=None):
        if self.check(typ, val):
            self.i += 1
            return True
        return False

    def err(self, msg, tok=None):
        tok = tok or self.peek()
        shown = "<string>" if tok[0] == "istr" else tok[1]
        raise LuaSyntaxError(f"{self.path}:{tok[2] or self.t[max(0, self.i - 1)][2]}: {msg} near {shown!r}")

    def expect(self, typ, val=None):
        if not self.check(typ, val):
            self.err(f"expected {val or typ}")
        return self.next()

    def name(self):
        return self.expect("name")[1]

    # ---- blocks and statements ----
    def chunk(self):
        body = self.block()
        if not self.check("eof"):
            self.err("unexpected token")
        return body

    def block(self):
        stmts = []
        while True:
            tok = self.peek()
            if tok[0] == "eof" or (tok[0] == "kw" and tok[1] in BLOCK_END):
                return stmts
            st = self.statement()
            if st is None:
                continue
            stmts.append(st)
            if st[0] == "Return":
                self.accept("op", ";")
                tok = self.peek()
                if not (tok[0] == "eof" or (tok[0] == "kw" and tok[1] in BLOCK_END)):
                    self.err("'return' must be the last statement of its block")
                return stmts

    def statement(self):
        tok = self.peek()
        typ, val, line = tok
        if typ == "op" and val == ";":
            self.next()
            return None
        if typ == "kw":
            if val == "local":
                self.next()
                if self.accept("kw", "function"):
                    fname = self.name()
                    return ("LocalFunction", fname, self.funcbody(fname, False, line))
                names = [self.name()]
                if self.accept("op", ":"):
                    self.parse_type()
                while self.accept("op", ","):
                    names.append(self.name())
                    if self.accept("op", ":"):
                        self.parse_type()
                exprs = self.exprlist() if self.accept("op", "=") else []
                return ("Local", names, exprs, line)
            if val == "if":
                self.next()
                clauses = []
                cond = self.expr()
                self.expect("kw", "then")
                clauses.append((cond, self.block()))
                orelse = None
                while True:
                    if self.accept("kw", "elseif"):
                        cond = self.expr()
                        self.expect("kw", "then")
                        clauses.append((cond, self.block()))
                    elif self.accept("kw", "else"):
                        orelse = self.block()
                        self.expect("kw", "end")
                        break
                    else:
                        self.expect("kw", "end")
                        break
                return ("If", clauses, orelse)
            if val == "for":
                self.next()
                names = [self.name()]
                if self.accept("op", ":"):
                    self.parse_type()
                if self.accept("op", "="):
                    start = self.expr()
                    self.expect("op", ",")
                    stop = self.expr()
                    step = self.expr() if self.accept("op", ",") else None
                    self.expect("kw", "do")
                    body = self.block()
                    self.expect("kw", "end")
                    return ("NumFor", names[0], start, stop, step, body, line)
                while self.accept("op", ","):
                    names.append(self.name())
                    if self.accept("op", ":"):
                        self.parse_type()
                self.expect("kw", "in")
                exprs = self.exprlist()
                self.expect("kw", "do")
                body = self.block()
                self.expect("kw", "end")
                return ("GenFor", names, exprs, body, line)
            if val == "while":
                self.next()
                cond = self.expr()
                self.expect("kw", "do")
                body = self.block()
                self.expect("kw", "end")
                return ("While", cond, body)
            if val == "repeat":
                self.next()
                body = self.block()
                self.expect("kw", "until")
                return ("Repeat", body, self.expr())
            if val == "do":
                self.next()
                body = self.block()
                self.expect("kw", "end")
                return ("Do", body)
            if val == "function":
                self.next()
                first = self.expect("name")
                target = ("Name", first[1], first[2])
                fname = first[1]
                method = False
                while self.check("op", ".") or self.check("op", ":"):
                    sep = self.next()
                    key = self.name()
                    fname += sep[1] + key
                    target = ("Index", target, ("Const", key), sep[2])
                    if sep[1] == ":":
                        method = True
                        break
                return ("Assign", [target], [self.funcbody(fname, method, line)], line)
            if val == "return":
                self.next()
                tok = self.peek()
                if tok[0] == "eof" or (tok[0] == "kw" and tok[1] in BLOCK_END) or (tok[0] == "op" and tok[1] == ";"):
                    return ("Return", [], line)
                return ("Return", self.exprlist(), line)
            if val == "break":
                self.next()
                return ("Break",)
        if typ == "name":
            nxt = self.peek(1)
            if val == "continue" and not (nxt[0] == "op" and nxt[1] in ("=", ".", "[", "(", ":", ",", "{") or nxt[0] == "op" and nxt[1] in COMPOUND or nxt[0] in ("str", "istr")):
                self.next()
                return ("Continue",)
            if val == "export" and nxt[0] == "name" and nxt[1] == "type":
                self.next()
                tok = self.peek()
                typ, val, line = tok
                nxt = self.peek(1)
            if val == "type" and nxt[0] == "name":
                self.next()
                self.name()
                if self.check("op", "<"):
                    self.skip_generics()
                self.expect("op", "=")
                self.parse_type()
                return None
        e = self.suffixed()
        if self.check("op", "=") or self.check("op", ","):
            targets = [e]
            while self.accept("op", ","):
                targets.append(self.suffixed())
            self.expect("op", "=")
            for target in targets:
                if target[0] not in ("Name", "Index"):
                    self.err("cannot assign to this expression")
            return ("Assign", targets, self.exprlist(), line)
        tok = self.peek()
        if tok[0] == "op" and tok[1] in COMPOUND:
            if e[0] not in ("Name", "Index"):
                self.err("cannot assign to this expression")
            self.next()
            return ("Compound", e, COMPOUND[tok[1]], self.expr(), line)
        if e[0] not in ("Call", "MCall"):
            self.err("incomplete statement: expected assignment or a function call", tok)
        return ("CallStat", e)

    def funcbody(self, fname, method, line):
        if self.check("op", "<"):
            self.skip_generics()
        self.expect("op", "(")
        params = ["self"] if method else []
        vararg = False
        if not self.check("op", ")"):
            while True:
                if self.accept("op", "..."):
                    vararg = True
                    if self.accept("op", ":"):
                        self.parse_type()
                    break
                params.append(self.name())
                if self.accept("op", ":"):
                    self.parse_type()
                if not self.accept("op", ","):
                    break
        self.expect("op", ")")
        if self.accept("op", ":"):
            self.parse_return_type()
        body = self.block()
        self.expect("kw", "end")
        return ("Function", params, vararg, body, fname or "anonymous", line, self.path)

    # ---- types (parsed, discarded) ----
    def skip_generics(self):
        self.expect("op", "<")
        depth = 1
        while depth > 0:
            tok = self.next()
            if tok[0] == "eof":
                self.err("unterminated generics")
            if tok[0] == "op" and tok[1] == "<":
                depth += 1
            elif tok[0] == "op" and tok[1] == ">":
                depth -= 1

    def parse_return_type(self):
        if self.accept("op", "..."):
            self.parse_type()
        else:
            self.parse_type()

    def parse_type(self):
        if self.check("op", "|") or self.check("op", "&"):
            self.next()
        self.type_postfix()
        while self.check("op", "|") or self.check("op", "&"):
            self.next()
            self.type_postfix()

    def type_postfix(self):
        self.type_simple()
        while self.accept("op", "?"):
            pass

    def type_simple(self):
        tok = self.peek()
        typ, val, _ = tok
        if typ == "kw" and val in ("nil", "true", "false"):
            self.next()
        elif typ == "str":
            self.next()
        elif typ == "name":
            self.next()
            if val == "typeof" and self.check("op", "("):
                self.next()
                self.expr()
                self.expect("op", ")")
                return
            while self.accept("op", "."):
                self.name()
            if self.check("op", "<"):
                self.next()
                if not self.check("op", ">"):
                    while True:
                        if self.accept("op", "..."):
                            pass
                        self.parse_type()
                        if not self.accept("op", ","):
                            break
                self.expect("op", ">")
        elif typ == "op" and val == "{":
            self.next()
            while not self.check("op", "}"):
                if self.accept("op", "["):
                    self.parse_type()
                    self.expect("op", "]")
                    self.expect("op", ":")
                    self.parse_type()
                elif self.peek()[0] == "name" and self.peek(1)[:2] == ("op", ":"):
                    self.next()
                    self.next()
                    self.parse_type()
                else:
                    self.parse_type()
                if not (self.accept("op", ",") or self.accept("op", ";")):
                    break
            self.expect("op", "}")
        elif typ == "op" and val in ("(", "<"):
            if val == "<":
                self.skip_generics()
            self.expect("op", "(")
            if not self.check("op", ")"):
                while True:
                    if self.accept("op", "..."):
                        if not (self.check("op", ")") or self.check("op", ",")):
                            self.parse_type()
                    else:
                        if self.peek()[0] == "name" and self.peek(1)[:2] == ("op", ":"):
                            self.next()
                            self.next()
                        self.parse_type()
                    if not self.accept("op", ","):
                        break
            self.expect("op", ")")
            if self.accept("op", "->"):
                self.parse_return_type()
        else:
            self.err("expected a type")

    # ---- expressions ----
    def exprlist(self):
        exprs = [self.expr()]
        while self.accept("op", ","):
            exprs.append(self.expr())
        return exprs

    def expr(self, limit=0):
        tok = self.peek()
        if (tok[0] == "kw" and tok[1] == "not") or (tok[0] == "op" and tok[1] in ("-", "#")):
            self.next()
            left = ("Un", tok[1], self.expr(UNARY_PRI), tok[2])
        else:
            left = self.simple()
        while True:
            tok = self.peek()
            if tok[0] == "op" or (tok[0] == "kw" and tok[1] in ("and", "or")):
                pri = BINPRI.get(tok[1])
            else:
                pri = None
            if not pri or pri[0] <= limit:
                return left
            self.next()
            right = self.expr(pri[1])
            if tok[1] == "and":
                left = ("And", left, right)
            elif tok[1] == "or":
                left = ("Or", left, right)
            else:
                left = ("Bin", tok[1], left, right, tok[2])

    def simple(self):
        tok = self.peek()
        typ, val, line = tok
        if typ == "num":
            self.next()
            node = ("Const", val)
        elif typ == "str":
            self.next()
            node = ("Const", val)
        elif typ == "istr":
            self.next()
            node = self.istr(val)
        elif typ == "kw" and val == "nil":
            self.next()
            node = ("Const", None)
        elif typ == "kw" and val == "true":
            self.next()
            node = ("Const", True)
        elif typ == "kw" and val == "false":
            self.next()
            node = ("Const", False)
        elif typ == "op" and val == "...":
            self.next()
            node = ("Varargs", line)
        elif typ == "op" and val == "{":
            node = self.table()
        elif typ == "kw" and val == "function":
            self.next()
            node = self.funcbody(None, False, line)
        elif typ == "kw" and val == "if":
            self.next()
            clauses = []
            cond = self.expr()
            self.expect("kw", "then")
            clauses.append((cond, self.expr()))
            while self.accept("kw", "elseif"):
                cond = self.expr()
                self.expect("kw", "then")
                clauses.append((cond, self.expr()))
            self.expect("kw", "else")
            node = ("IfExpr", clauses, self.expr())
        else:
            node = self.suffixed()
        while self.accept("op", "::"):
            self.parse_type()
        return node

    def istr(self, parts):
        out = []
        for part in parts:
            if isinstance(part, str):
                out.append(part)
            else:
                sub = Parser(part, self.path)
                out.append(sub.expr())
                if not sub.check("eof"):
                    sub.err("unexpected token in interpolation")
        return ("IStr", out)

    def suffixed(self):
        tok = self.next()
        if tok[0] == "name":
            node = ("Name", tok[1], tok[2])
        elif tok[0] == "op" and tok[1] == "(":
            node = ("Paren", self.expr())
            self.expect("op", ")")
        else:
            self.i -= 1
            self.err("unexpected symbol")
        while True:
            tok = self.peek()
            typ, val, line = tok
            if typ == "op":
                if val == ".":
                    self.next()
                    node = ("Index", node, ("Const", self.name()), line)
                elif val == "[":
                    self.next()
                    key = self.expr()
                    self.expect("op", "]")
                    node = ("Index", node, key, line)
                elif val == ":":
                    self.next()
                    method = self.name()
                    node = ("MCall", node, method, self.callargs(), line)
                elif val == "(" or val == "{":
                    node = ("Call", node, self.callargs(), line)
                else:
                    return node
            elif typ in ("str", "istr"):
                node = ("Call", node, self.callargs(), line)
            else:
                return node

    def callargs(self):
        tok = self.peek()
        if tok[0] == "str":
            self.next()
            return [("Const", tok[1])]
        if tok[0] == "istr":
            self.next()
            return [self.istr(tok[1])]
        if tok[0] == "op" and tok[1] == "{":
            return [self.table()]
        self.expect("op", "(")
        if self.accept("op", ")"):
            return []
        args = self.exprlist()
        self.expect("op", ")")
        return args

    def table(self):
        self.expect("op", "{")
        items = []
        while not self.check("op", "}"):
            if self.check("op", "["):
                self.next()
                key = self.expr()
                self.expect("op", "]")
                self.expect("op", "=")
                items.append(("keyed", key, self.expr()))
            elif self.peek()[0] == "name" and self.peek(1)[:2] == ("op", "="):
                key = self.next()[1]
                self.next()
                items.append(("keyed", ("Const", key), self.expr()))
            else:
                items.append(("pos", self.expr()))
            if not (self.accept("op", ",") or self.accept("op", ";")):
                break
        self.expect("op", "}")
        return ("Table", items)


def parse(src, path):
    toks, _, _ = lex(src, path)
    toks.append(EOF)
    return Parser(toks, path).chunk()


# ---------------------------------------------------------------------------------------------------
# Values
# ---------------------------------------------------------------------------------------------------
BOOLKEY = object()


class LuaTable:
    __slots__ = ("arr", "hash", "meta")

    def __init__(self):
        self.arr = []
        self.hash = {}
        self.meta = None

    def get(self, k):
        t = type(k)
        if t is float and k.is_integer():
            k = int(k)
            t = int
        if t is int:
            if 1 <= k <= len(self.arr):
                return self.arr[k - 1]
        elif t is bool:
            k = (BOOLKEY, k)
        return self.hash.get(k)

    def set(self, k, v):
        t = type(k)
        if k is None:
            raise LuaError("table index is nil")
        if t is float:
            if k != k:
                raise LuaError("table index is NaN")
            if k.is_integer():
                k = int(k)
                t = int
        if t is int:
            n = len(self.arr)
            if 1 <= k <= n:
                self.arr[k - 1] = v
                if v is None and k == n:
                    while self.arr and self.arr[-1] is None:
                        self.arr.pop()
                return
            if k == n + 1:
                if v is None:
                    self.hash.pop(k, None)
                    return
                self.hash.pop(k, None)
                self.arr.append(v)
                nxt = k + 1
                while self.hash and nxt in self.hash:
                    self.arr.append(self.hash.pop(nxt))
                    nxt += 1
                return
        elif t is bool:
            k = (BOOLKEY, k)
        if v is None:
            self.hash.pop(k, None)
        else:
            self.hash[k] = v

    def items(self):
        """Pairs, tolerant of the table changing while it is walked."""
        for i in range(len(self.arr)):
            if i < len(self.arr):
                v = self.arr[i]
                if v is not None:
                    yield i + 1, v
        for k in list(self.hash.keys()):
            v = self.hash.get(k)
            if v is not None:
                yield (k[1] if type(k) is tuple and k[0] is BOOLKEY else k), v


class LuaFunction:
    __slots__ = ("params", "vararg", "body", "scope", "name", "line", "path")

    def __init__(self, node, scope):
        _, self.params, self.vararg, self.body, self.name, self.line, self.path = node
        self.scope = scope


class Scope:
    __slots__ = ("vars", "parent")

    def __init__(self, parent=None):
        self.vars = {}
        self.parent = parent


class Host:
    """Base for mock userdata. Subclasses provide lua_get / lua_set and a lua_type name."""

    lua_type = "userdata"

    def lua_get(self, k):
        raise LuaError(f"{k} is not a valid member of {self.lua_type}")

    def lua_set(self, k, v):
        raise LuaError(f"{k} cannot be assigned to on {self.lua_type}")


def is_num(v):
    t = type(v)
    return t is int or t is float


def fmt_num(n):
    if type(n) is int:
        return str(n)
    if n != n:
        return "nan"
    if n == math.inf:
        return "inf"
    if n == -math.inf:
        return "-inf"
    if n.is_integer() and abs(n) < 1e16:
        return str(int(n))
    return repr(n)


def typename(v):
    if v is None:
        return "nil"
    if type(v) is bool:
        return "boolean"
    if is_num(v):
        return "number"
    if isinstance(v, str):
        return "string"
    if isinstance(v, LuaTable):
        return "table"
    if isinstance(v, LuaFunction) or callable(v):
        return "function"
    if isinstance(v, Host):
        return v.lua_type
    return "userdata"


def tostr(v):
    if v is None:
        return "nil"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if is_num(v):
        return fmt_num(v)
    if isinstance(v, str):
        return v
    if isinstance(v, LuaTable):
        return "table: 0x%08x" % (id(v) & 0xFFFFFFFF)
    if isinstance(v, LuaFunction):
        return f"function: {v.name}"
    if isinstance(v, Host):
        return str(v)
    return "function: builtin"


def lua_eq(a, b):
    ta, tb = type(a), type(b)
    if (ta is int or ta is float) and (tb is int or tb is float):
        return a == b
    if a is b:
        return True
    if ta is bool or tb is bool:
        return False
    if ta is str and tb is str:
        return a == b
    if isinstance(a, Host) and hasattr(a, "lua_eq"):
        return a.lua_eq(b)
    return False


def truthy(v):
    return v is not None and v is not False


# ---------------------------------------------------------------------------------------------------
# Interpreter
# ---------------------------------------------------------------------------------------------------
class Interp:
    def __init__(self):
        self.globals = Scope()
        self.stack = []  # (function name, path, call line) for tracebacks
        self.undefined = {}  # undefined global name -> first place it was read
        self.global_writes = {}  # names assigned without `local`
        self.errors = []  # errors in spawned threads / signal handlers
        self.deferred = []
        self.string_lib = None

    # ---- errors ----
    def error(self, msg, path=None, line=None):
        where = f"{os.path.basename(path)}:{line}: " if path and line else ""
        return LuaError(where + msg, self.traceback(path, line))

    def traceback(self, path=None, line=None):
        lines = []
        cur = (path, line)
        for name, fpath, call_line, call_path in reversed(self.stack):
            lines.append(f"    {os.path.basename(cur[0] or '?')}:{cur[1] or '?'} in {name}")
            cur = (call_path, call_line)
        lines.append(f"    {os.path.basename(cur[0] or '?')}:{cur[1] or '?'} in main chunk")
        return "\n".join(lines)

    # ---- calls ----
    def call(self, f, args, path=None, line=None):
        if type(f) is LuaFunction:
            scope = Scope(f.scope)
            v = scope.vars
            n = len(args)
            i = 0
            for p in f.params:
                v[p] = args[i] if i < n else None
                i += 1
            if f.vararg:
                v["..."] = args[len(f.params) :]
            self.stack.append((f.name, f.path, line, path))
            if len(self.stack) > 190:
                self.stack.pop()
                raise self.error("stack overflow", path, line)
            try:
                r = self.block(f.body, scope, f.path)
            finally:
                self.stack.pop()
            if r is not None and r[0] == "return":
                return r[1]
            return []
        if callable(f):
            try:
                r = f(*args)
            except LuaError as e:
                if e.trace is None:
                    e2 = self.error(e.value if isinstance(e.value, str) else tostr(e.value), path, line)
                    e2.value = e.value if not isinstance(e.value, str) else e2.value
                    raise e2 from None
                raise
            except (TypeError, AttributeError, ValueError, IndexError, KeyError, ZeroDivisionError, OverflowError) as e:
                raise self.error(f"host error in {getattr(f, '__name__', f)}: {type(e).__name__}: {e}", path, line)
            if r is None:
                return []
            if type(r) is list:
                return r
            return [r]
        raise self.error(f"attempt to call a {typename(f)} value", path, line)

    def pcall(self, f, *args):
        depth = len(self.stack)
        try:
            return [True] + self.call(f, list(args))
        except LuaError as e:
            del self.stack[depth:]
            return [False, e.value]

    def spawn(self, f, args, what="task"):
        """Runs f now as its own 'thread': an error or a yield inside it does not reach the caller."""
        depth = len(self.stack)
        try:
            self.call(f, list(args))
        except ThreadYield:
            del self.stack[depth:]
        except LuaError as e:
            del self.stack[depth:]
            self.errors.append((what, e))
            print(f"[emu] error in {what}: {e.value}\n{e.trace or ''}", file=sys.stderr)

    def flush(self):
        guard = 0
        while self.deferred:
            guard += 1
            if guard > 10000:
                raise RuntimeError("deferred tasks never settle")
            f, args = self.deferred.pop(0)
            self.spawn(f, args, "deferred task")

    # ---- variables ----
    def lookup(self, name, scope, path, line):
        s = scope
        while s is not None:
            v = s.vars
            if name in v:
                return v[name]
            s = s.parent
        self.undefined.setdefault(name, f"{os.path.basename(path)}:{line}")
        return None

    def assign_name(self, name, value, scope, path, line):
        s = scope
        while s is not None:
            if name in s.vars:
                s.vars[name] = value
                return
            s = s.parent
        self.global_writes.setdefault(name, f"{os.path.basename(path)}:{line}")
        self.globals.vars[name] = value

    # ---- operations ----
    def index(self, o, k, path, line):
        if type(o) is LuaTable:
            v = o.get(k)
            if v is None and o.meta is not None:
                h = o.meta.get("__index")
                if type(h) is LuaTable:
                    return self.index(h, k, path, line)
                if h is not None:
                    return first(self.call(h, [o, k], path, line))
            return v
        if isinstance(o, str):
            return self.string_lib.get(k)
        if isinstance(o, Host):
            try:
                return o.lua_get(k)
            except LuaError as e:
                raise self.error(e.value, path, line) from None
        shown = f"'{k}'" if isinstance(k, str) else tostr(k)
        raise self.error(f"attempt to index {typename(o)} with {shown}", path, line)

    def setindex(self, o, k, v, path, line):
        if type(o) is LuaTable:
            try:
                o.set(k, v)
            except LuaError as e:
                raise self.error(e.value, path, line) from None
            return
        if isinstance(o, Host):
            try:
                o.lua_set(k, v)
            except LuaError as e:
                raise self.error(e.value, path, line) from None
            return
        shown = f"'{k}'" if isinstance(k, str) else tostr(k)
        raise self.error(f"attempt to index {typename(o)} with {shown}", path, line)

    def arith(self, op, a, b, path, line):
        ta, tb = type(a), type(b)
        if (ta is int or ta is float) and (tb is int or tb is float):
            try:
                if op == "+":
                    r = a + b
                elif op == "-":
                    r = a - b
                elif op == "*":
                    r = a * b
                elif op == "/":
                    return a / b
                elif op == "//":
                    r = a // b
                elif op == "%":
                    r = a % b
                else:
                    return float(a) ** b
                # Lua numbers are doubles: an integer too big for one must not stay exact here either.
                if type(r) is int and (r > 9007199254740992 or r < -9007199254740992):
                    return float(r)
                return r
            except ZeroDivisionError:
                if op == "%" or a == 0 or a != a:
                    return math.nan
                return math.inf if (a > 0) == (not str(b).startswith("-")) else -math.inf
            except OverflowError:
                return math.inf
        for x in (a, b):
            if isinstance(x, Host) and hasattr(x, "lua_arith"):
                return x.lua_arith(op, a, b)
        raise self.error(f"attempt to perform arithmetic ({op}) on {typename(a)} and {typename(b)}", path, line)

    def compare(self, op, a, b, path, line):
        ta, tb = type(a), type(b)
        if ((ta is int or ta is float) and (tb is int or tb is float)) or (ta is str and tb is str):
            if op == "<":
                return a < b
            if op == ">":
                return a > b
            if op == "<=":
                return a <= b
            return a >= b
        raise self.error(f"attempt to compare {typename(a)} {op} {typename(b)}", path, line)

    def concat(self, a, b, path, line):
        for x in (a, b):
            if not (isinstance(x, str) or is_num(x)):
                raise self.error(f"attempt to concatenate {typename(a)} with {typename(b)}", path, line)
        return tostr(a) + tostr(b)

    def length(self, v, path, line):
        if isinstance(v, str):
            return len(v.encode("utf-8"))
        if type(v) is LuaTable:
            return len(v.arr)
        raise self.error(f"attempt to get length of a {typename(v)} value", path, line)

    # ---- expressions ----
    def ev(self, node, scope, path):
        tag = node[0]
        if tag == "Const":
            return node[1]
        if tag == "Name":
            name = node[1]
            s = scope
            while s is not None:
                v = s.vars
                if name in v:
                    return v[name]
                s = s.parent
            self.undefined.setdefault(name, f"{os.path.basename(path)}:{node[2]}")
            return None
        if tag == "Index":
            return self.index(self.ev(node[1], scope, path), self.ev(node[2], scope, path), path, node[3])
        if tag == "Call" or tag == "MCall" or tag == "Varargs":
            r = self.ev_multi(node, scope, path)
            return r[0] if r else None
        if tag == "Bin":
            op = node[1]
            a = self.ev(node[2], scope, path)
            b = self.ev(node[3], scope, path)
            if op == "==":
                return lua_eq(a, b)
            if op == "~=":
                return not lua_eq(a, b)
            if op == "..":
                return self.concat(a, b, path, node[4])
            if op in ("<", ">", "<=", ">="):
                return self.compare(op, a, b, path, node[4])
            return self.arith(op, a, b, path, node[4])
        if tag == "And":
            a = self.ev(node[1], scope, path)
            return self.ev(node[2], scope, path) if truthy(a) else a
        if tag == "Or":
            a = self.ev(node[1], scope, path)
            return a if truthy(a) else self.ev(node[2], scope, path)
        if tag == "Un":
            op = node[1]
            a = self.ev(node[2], scope, path)
            if op == "not":
                return not truthy(a)
            if op == "#":
                return self.length(a, path, node[3])
            if is_num(a):
                return -a
            if isinstance(a, Host) and hasattr(a, "lua_arith"):
                return a.lua_arith("unm", a, None)
            raise self.error(f"attempt to perform arithmetic (unm) on {typename(a)}", path, node[3])
        if tag == "Paren":
            return self.ev(node[1], scope, path)
        if tag == "IStr":
            out = []
            for part in node[1]:
                out.append(part if isinstance(part, str) else tostr(self.ev(part, scope, path)))
            return "".join(out)
        if tag == "Table":
            t = LuaTable()
            items = node[1]
            last = len(items) - 1
            for i, item in enumerate(items):
                if item[0] == "pos":
                    if i == last and item[1][0] in ("Call", "MCall", "Varargs"):
                        for v in self.ev_multi(item[1], scope, path):
                            t.arr.append(v)
                        while t.arr and t.arr[-1] is None:
                            t.arr.pop()
                    else:
                        v = self.ev(item[1], scope, path)
                        t.set(len(t.arr) + 1, v) if v is not None else t.arr.append(None)
                else:
                    k = self.ev(item[1], scope, path)
                    if k is None:
                        raise self.error("table index is nil", path, None)
                    t.set(k, self.ev(item[2], scope, path))
            while t.arr and t.arr[-1] is None:
                t.arr.pop()
            return t
        if tag == "Function":
            return LuaFunction(node, scope)
        if tag == "IfExpr":
            for cond, value in node[1]:
                if truthy(self.ev(cond, scope, path)):
                    return self.ev(value, scope, path)
            return self.ev(node[2], scope, path)
        raise RuntimeError(f"unknown expression node {tag}")

    def ev_multi(self, node, scope, path):
        tag = node[0]
        if tag == "Call":
            f = self.ev(node[1], scope, path)
            if f is None:
                raise self.error(f"attempt to call a nil value ({describe(node[1])})", path, node[3])
            return self.call(f, self.ev_list(node[2], scope, path), path, node[3])
        if tag == "MCall":
            o = self.ev(node[1], scope, path)
            f = self.index(o, node[2], path, node[4])
            if f is None:
                raise self.error(f"attempt to call missing method '{node[2]}' of {typename(o)} ({describe(node[1])})", path, node[4])
            return self.call(f, [o] + self.ev_list(node[3], scope, path), path, node[4])
        if tag == "Varargs":
            s = scope
            while s is not None:
                if "..." in s.vars:
                    return list(s.vars["..."])
                s = s.parent
            raise self.error("cannot use '...' outside a vararg function", path, node[1])
        return [self.ev(node, scope, path)]

    def ev_list(self, exprs, scope, path):
        out = []
        last = len(exprs) - 1
        for i, e in enumerate(exprs):
            if i == last and e[0] in ("Call", "MCall", "Varargs"):
                out.extend(self.ev_multi(e, scope, path))
            else:
                out.append(self.ev(e, scope, path))
        return out

    # ---- statements ----
    def block(self, stmts, scope, path):
        for st in stmts:
            tag = st[0]
            if tag == "Local":
                names = st[1]
                values = self.ev_list(st[2], scope, path) if st[2] else []
                n = len(values)
                v = scope.vars
                for i, name in enumerate(names):
                    v[name] = values[i] if i < n else None
            elif tag == "CallStat":
                self.ev_multi(st[1], scope, path)
            elif tag == "Assign":
                targets = st[1]
                if len(targets) == 1 and len(st[2]) == 1:
                    values = [self.ev(st[2][0], scope, path)]
                else:
                    values = self.ev_list(st[2], scope, path)
                n = len(values)
                for i, target in enumerate(targets):
                    value = values[i] if i < n else None
                    if target[0] == "Name":
                        self.assign_name(target[1], value, scope, path, target[2])
                    else:
                        self.setindex(self.ev(target[1], scope, path), self.ev(target[2], scope, path), value, path, target[3])
            elif tag == "If":
                done = False
                for cond, body in st[1]:
                    if truthy(self.ev(cond, scope, path)):
                        r = self.block(body, Scope(scope), path)
                        if r is not None:
                            return r
                        done = True
                        break
                if not done and st[2] is not None:
                    r = self.block(st[2], Scope(scope), path)
                    if r is not None:
                        return r
            elif tag == "Return":
                return ("return", self.ev_list(st[1], scope, path))
            elif tag == "Compound":
                target, op = st[1], st[2]
                if target[0] == "Name":
                    cur = self.lookup(target[1], scope, path, target[2])
                    rhs = self.ev(st[3], scope, path)
                    new = self.concat(cur, rhs, path, st[4]) if op == ".." else self.arith(op, cur, rhs, path, st[4])
                    self.assign_name(target[1], new, scope, path, target[2])
                else:
                    o = self.ev(target[1], scope, path)
                    k = self.ev(target[2], scope, path)
                    cur = self.index(o, k, path, target[3])
                    rhs = self.ev(st[3], scope, path)
                    new = self.concat(cur, rhs, path, st[4]) if op == ".." else self.arith(op, cur, rhs, path, st[4])
                    self.setindex(o, k, new, path, target[3])
            elif tag == "LocalFunction":
                scope.vars[st[1]] = None
                scope.vars[st[1]] = LuaFunction(st[2], scope)
            elif tag == "GenFor":
                names = st[1]
                values = self.ev_list(st[2], scope, path)
                first_value = values[0] if values else None
                if type(first_value) is LuaTable:
                    pairs = first_value.items()
                elif first_value is None:
                    raise self.error("attempt to iterate over a nil value", path, st[4])
                elif type(first_value) is LuaFunction or callable(first_value):
                    pairs = self.iterate(values, path, st[4])
                else:
                    raise self.error(f"attempt to iterate over a {typename(first_value)} value", path, st[4])
                n = len(names)
                for item in pairs:
                    inner = Scope(scope)
                    v = inner.vars
                    for i in range(n):
                        v[names[i]] = item[i] if i < len(item) else None
                    r = self.block(st[3], inner, path)
                    if r is not None:
                        if r[0] == "break":
                            break
                        if r[0] == "return":
                            return r
            elif tag == "NumFor":
                start = self.ev(st[2], scope, path)
                stop = self.ev(st[3], scope, path)
                step = self.ev(st[4], scope, path) if st[4] is not None else 1
                if not (is_num(start) and is_num(stop) and is_num(step)):
                    raise self.error("'for' limits must be numbers", path, st[6])
                if step == 0:
                    raise self.error("'for' step is zero", path, st[6])
                i = start
                while (i <= stop) if step > 0 else (i >= stop):
                    inner = Scope(scope)
                    inner.vars[st[1]] = i
                    r = self.block(st[5], inner, path)
                    if r is not None:
                        if r[0] == "break":
                            break
                        if r[0] == "return":
                            return r
                    i += step
            elif tag == "While":
                while truthy(self.ev(st[1], scope, path)):
                    r = self.block(st[2], Scope(scope), path)
                    if r is not None:
                        if r[0] == "break":
                            break
                        if r[0] == "return":
                            return r
            elif tag == "Repeat":
                while True:
                    inner = Scope(scope)
                    r = self.block(st[1], inner, path)
                    if r is not None:
                        if r[0] == "break":
                            break
                        if r[0] == "return":
                            return r
                    if truthy(self.ev(st[2], inner, path)):
                        break
            elif tag == "Do":
                r = self.block(st[1], Scope(scope), path)
                if r is not None:
                    return r
            elif tag == "Break":
                return ("break",)
            elif tag == "Continue":
                return ("continue",)
            else:
                raise RuntimeError(f"unknown statement node {tag}")
        return None

    def iterate(self, values, path, line):
        f = values[0]
        state = values[1] if len(values) > 1 else None
        control = values[2] if len(values) > 2 else None
        while True:
            r = self.call(f, [state, control], path, line)
            if not r or r[0] is None:
                return
            control = r[0]
            yield r

    # ---- running source ----
    def run(self, src, path, env=None):
        body = parse(src, path)
        scope = Scope(self.globals)
        for k, v in (env or {}).items():
            scope.vars[k] = v
        scope.vars["..."] = []
        r = self.block(body, scope, path)
        if r is not None and r[0] == "return":
            return r[1]
        return []


def first(values):
    return values[0] if values else None


def describe(node):
    if node[0] == "Name":
        return node[1]
    if node[0] == "Index" and node[2][0] == "Const":
        return f"{describe(node[1])}.{node[2][1]}"
    if node[0] in ("Call", "MCall"):
        return describe(node[1]) + (":" + node[2] if node[0] == "MCall" else "") + "()"
    return "?"
