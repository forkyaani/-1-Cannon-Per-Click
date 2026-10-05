#!/usr/bin/env python3
"""A strict-enough Luau syntax checker with scope analysis, for a machine with no Luau toolchain.

It parses the Luau used in this project (Lua 5.1 plus: type annotations, if-expressions, interpolated
strings, compound assignment, continue, generalized for, // and number separators) and reports:
  * syntax errors (the first one per file, with line number)
  * names that are read but are neither a local in scope nor a known Roblox/Luau global
  * locals that are never read (possible dead code); names starting with _ are ignored
Usage: luau_check.py file.luau [file.luau ...]
"""
import re
import sys

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
    "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}

GLOBALS = set("""
game workspace script Instance Enum Color3 Vector2 Vector3 CFrame UDim UDim2 TweenInfo Random Rect
NumberSequence ColorSequence NumberRange BrickColor Ray Region3 task math table string os coroutine debug
utf8 bit32 buffer typeof type require pcall xpcall print warn error assert tostring tonumber pairs ipairs
next select unpack rawget rawset rawequal rawlen setmetatable getmetatable tick time wait spawn delay newproxy
_G shared DateTime PhysicalProperties Font Faces Axes NumberSequenceKeypoint ColorSequenceKeypoint
OverlapParams RaycastParams PathWaypoint vector elapsedTime gcinfo settings UserSettings version
Vector3int16 Vector2int16 Region3int16 SharedTable
""".split())

SYMBOLS = [
    "...", "..=", "//=", "..", "==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "^=", "//", "::", "->",
    "+", "-", "*", "/", "%", "^", "#", "<", ">", "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "?",
    "|", "&",
]

NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
NUMBER_RE = re.compile(
    r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:[0-9][0-9_]*\.?[0-9_]*|\.[0-9][0-9_]*)(?:[eE][+-]?[0-9_]+)?"
)


class LuauError(Exception):
    def __init__(self, message, line):
        super().__init__(message)
        self.line = line


class Token:
    __slots__ = ("kind", "value", "line", "parts")

    def __init__(self, kind, value, line, parts=None):
        self.kind = kind  # name, keyword, number, string, interp, symbol, eof
        self.value = value
        self.line = line
        self.parts = parts  # interp: list of token lists, one per embedded expression

    def __repr__(self):
        return f"{self.kind}:{self.value!r}@{self.line}"


class Lexer:
    def __init__(self, text):
        self.text = text
        self.pos = 0
        self.line = 1

    def error(self, message):
        raise LuauError(message, self.line)

    def long_bracket(self):
        """At '[' : returns the level of a long bracket opener, or -1."""
        text, pos = self.text, self.pos + 1
        level = 0
        while pos < len(text) and text[pos] == "=":
            level += 1
            pos += 1
        if pos < len(text) and text[pos] == "[":
            return level
        return -1

    def read_long(self, level):
        closer = "]" + "=" * level + "]"
        start = self.pos + level + 2
        end = self.text.find(closer, start)
        if end < 0:
            self.error("unfinished long string or comment")
        body = self.text[start:end]
        self.line += body.count("\n")
        self.pos = end + len(closer)
        return body

    def read_quoted(self, quote):
        text = self.text
        self.pos += 1
        start = self.pos
        while True:
            if self.pos >= len(text):
                self.error("unfinished string")
            ch = text[self.pos]
            if ch == "\n":
                self.error("unfinished string (newline inside quotes)")
            if ch == "\\":
                nxt = text[self.pos + 1 : self.pos + 2]
                if nxt == "z":
                    self.pos += 2
                    while self.pos < len(text) and text[self.pos] in " \t\r\n":
                        if text[self.pos] == "\n":
                            self.line += 1
                        self.pos += 1
                    continue
                if nxt == "\n":
                    self.line += 1
                self.pos += 2
                continue
            if ch == quote:
                value = text[start : self.pos]
                self.pos += 1
                return value
            self.pos += 1

    def read_interp(self):
        """At a backtick. Returns a Token of kind interp whose parts are token lists."""
        text = self.text
        line = self.line
        self.pos += 1
        parts = []
        while True:
            if self.pos >= len(text):
                self.error("unfinished interpolated string")
            ch = text[self.pos]
            if ch == "\\":
                if text[self.pos + 1 : self.pos + 2] == "\n":
                    self.line += 1
                self.pos += 2
            elif ch == "`":
                self.pos += 1
                return Token("interp", "`", line, parts)
            elif ch == "\n":
                self.error("unfinished interpolated string (newline)")
            elif ch == "{":
                if text[self.pos + 1 : self.pos + 2] == "{":
                    self.error("'{{' is not allowed in an interpolated string")
                self.pos += 1
                tokens = self.tokens(stop_at_brace=True)
                if not tokens:
                    self.error("empty {} in interpolated string")
                tokens.append(Token("eof", None, self.line))
                parts.append(tokens)
            else:
                self.pos += 1

    def tokens(self, stop_at_brace=False):
        text = self.text
        out = []
        depth = 0
        while True:
            # whitespace and comments
            while self.pos < len(text):
                ch = text[self.pos]
                if ch == "\n":
                    self.line += 1
                    self.pos += 1
                elif ch in " \t\r":
                    self.pos += 1
                elif text.startswith("--", self.pos):
                    self.pos += 2
                    if self.pos < len(text) and text[self.pos] == "[" and self.long_bracket() >= 0:
                        self.read_long(self.long_bracket())
                    else:
                        end = text.find("\n", self.pos)
                        self.pos = len(text) if end < 0 else end
                else:
                    break
            if self.pos >= len(text):
                if stop_at_brace:
                    self.error("unfinished {} in interpolated string")
                return out
            ch = text[self.pos]
            line = self.line
            match = NAME_RE.match(text, self.pos)
            if match:
                word = match.group()
                self.pos = match.end()
                out.append(Token("keyword" if word in KEYWORDS else "name", word, line))
                continue
            if ch.isdigit() or (ch == "." and text[self.pos + 1 : self.pos + 2].isdigit()):
                match = NUMBER_RE.match(text, self.pos)
                self.pos = match.end()
                if self.pos < len(text) and (text[self.pos].isalnum() or text[self.pos] == "_"):
                    self.error("malformed number")
                out.append(Token("number", match.group(), line))
                continue
            if ch in "\"'":
                out.append(Token("string", self.read_quoted(ch), line))
                continue
            if ch == "`":
                out.append(self.read_interp())
                continue
            if ch == "[" and self.long_bracket() >= 0:
                out.append(Token("string", self.read_long(self.long_bracket()), line))
                continue
            if stop_at_brace:
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    if depth == 0:
                        self.pos += 1
                        return out
                    depth -= 1
            for symbol in SYMBOLS:
                if text.startswith(symbol, self.pos):
                    self.pos += len(symbol)
                    out.append(Token("symbol", symbol, line))
                    break
            else:
                self.error(f"unexpected character {ch!r}")


BINARY_PRIORITY = {
    "or": (1, 1), "and": (2, 2),
    "<": (3, 3), ">": (3, 3), "<=": (3, 3), ">=": (3, 3), "~=": (3, 3), "==": (3, 3),
    "..": (5, 4),
    "+": (6, 6), "-": (6, 6),
    "*": (7, 7), "/": (7, 7), "//": (7, 7), "%": (7, 7),
    "^": (10, 9),
}
UNARY_PRIORITY = 8
COMPOUND = {"+=", "-=", "*=", "/=", "//=", "%=", "^=", "..="}
BLOCK_END = {"end", "else", "elseif", "until"}


class Local:
    __slots__ = ("name", "line", "reads", "kind")

    def __init__(self, name, line, kind):
        self.name = name
        self.line = line
        self.reads = 0
        self.kind = kind  # local, param, loop, function, self


class Parser:
    def __init__(self, tokens, report, scopes=None):
        self.tokens = tokens
        self.index = 0
        self.report = report  # list of (line, message)
        self.scopes = scopes if scopes is not None else [dict()]
        self.loop_depth = 0

    # -- token helpers ---------------------------------------------------------------------------
    @property
    def tok(self):
        return self.tokens[self.index]

    def peek(self, offset=1):
        index = min(self.index + offset, len(self.tokens) - 1)
        return self.tokens[index]

    def error(self, message, token=None):
        token = token or self.tok
        found = "end of file" if token.kind == "eof" else repr(token.value)
        raise LuauError(f"{message} (found {found})", token.line)

    def at(self, value, kind=None):
        token = self.tok
        if token.value != value:
            return False
        if kind:
            return token.kind == kind
        return token.kind in ("symbol", "keyword")

    def accept(self, value):
        if self.at(value):
            self.index += 1
            return True
        return False

    def expect(self, value, what=None):
        if not self.accept(value):
            self.error(f"expected {what or repr(value)}")

    def name(self, what="a name"):
        token = self.tok
        if token.kind != "name":
            self.error(f"expected {what}")
        self.index += 1
        return token

    # -- scopes ----------------------------------------------------------------------------------
    def push(self):
        self.scopes.append(dict())

    def pop(self):
        scope = self.scopes.pop()
        for local in scope.values():
            if local.reads == 0 and local.kind in ("local", "function") and not local.name.startswith("_"):
                self.report.append((local.line, f"local '{local.name}' is never read"))

    def declare(self, token, kind="local"):
        scope = self.scopes[-1]
        old = scope.get(token.value)
        if old and old.reads == 0 and old.kind in ("local", "function") and not old.name.startswith("_"):
            self.report.append((old.line, f"local '{old.name}' is never read (redeclared on line {token.line})"))
        scope[token.value] = Local(token.value, token.line, kind)

    def lookup(self, name):
        for scope in reversed(self.scopes):
            if name in scope:
                return scope[name]
        return None

    def read(self, token):
        local = self.lookup(token.value)
        if local:
            local.reads += 1
        elif token.value not in GLOBALS:
            self.report.append((token.line, f"undefined name '{token.value}'"))

    def write(self, token):
        """An assignment target that is a bare name."""
        local = self.lookup(token.value)
        if not local and token.value not in GLOBALS:
            self.report.append((token.line, f"assignment to undeclared global '{token.value}'"))

    # -- types -----------------------------------------------------------------------------------
    def type_annotation(self):
        """After a ':' in a declaration."""
        self.type_expr()

    def type_expr(self):
        self.accept("|")
        self.accept("&")
        self.simple_type()
        while self.at("|") or self.at("&"):
            self.index += 1
            self.simple_type()

    def simple_type(self):
        token = self.tok
        if token.kind == "string":
            self.index += 1
        elif token.kind == "keyword" and token.value in ("nil", "true", "false"):
            self.index += 1
        elif token.kind == "name":
            self.index += 1
            if token.value == "typeof" and self.at("("):
                self.index += 1
                self.expr()
                self.expect(")")
            else:
                while self.accept("."):
                    self.name("a type name")
                if self.at("<"):
                    self.index += 1
                    if not self.at(">"):
                        self.type_list_item()
                        while self.accept(","):
                            self.type_list_item()
                    self.expect(">")
        elif self.at("{"):
            self.index += 1
            self.table_type()
        elif self.at("("):
            self.function_or_paren_type()
        elif self.at("function", "keyword"):
            self.error("'function' is not a type")
        else:
            self.error("expected a type")
        while self.accept("?"):
            pass

    def type_list_item(self):
        if self.accept("..."):
            self.type_expr()
        else:
            self.type_expr()
            self.accept("...")  # a generic pack: T...

    def table_type(self):
        while not self.at("}"):
            if self.at("["):
                self.index += 1
                self.type_expr()
                self.expect("]")
                self.expect(":")
                self.type_expr()
            elif self.tok.kind == "name" and self.peek().value == ":" and self.peek().kind == "symbol":
                self.index += 2
                self.type_expr()
            else:
                self.type_expr()
            if not (self.accept(",") or self.accept(";")):
                break
        self.expect("}", "'}' to close the table type")

    def function_or_paren_type(self):
        self.expect("(")
        count = 0
        named = False
        if not self.at(")"):
            while True:
                if self.accept("..."):
                    self.type_expr()
                else:
                    if self.tok.kind == "name" and self.peek().value == ":" and self.peek().kind == "symbol":
                        self.index += 2
                        named = True
                    self.type_expr()
                count += 1
                if not self.accept(","):
                    break
        self.expect(")")
        if self.accept("->"):
            self.return_type()
        elif count != 1 or named:
            self.error("expected '->' after a parameter list in a type")

    def return_type(self):
        if self.at("("):
            # either a type pack (A, B) or a parenthesised/function type
            self.function_or_pack()
        elif self.accept("..."):
            self.type_expr()
        else:
            self.type_expr()

    def function_or_pack(self):
        self.expect("(")
        if not self.at(")"):
            while True:
                if self.accept("..."):
                    self.type_expr()
                else:
                    if self.tok.kind == "name" and self.peek().value == ":" and self.peek().kind == "symbol":
                        self.index += 2
                    self.type_expr()
                if not self.accept(","):
                    break
        self.expect(")")
        if self.accept("->"):
            self.return_type()
        while self.accept("?"):
            pass
        while self.at("|") or self.at("&"):
            self.index += 1
            self.simple_type()

    # -- expressions -----------------------------------------------------------------------------
    def expr_list(self):
        count = 1
        self.expr()
        while self.accept(","):
            self.expr()
            count += 1
        return count

    def expr(self, limit=0):
        token = self.tok
        if (token.kind == "keyword" and token.value == "not") or (
            token.kind == "symbol" and token.value in ("-", "#")
        ):
            self.index += 1
            self.expr(UNARY_PRIORITY)
        else:
            self.simple_expr()
        while True:
            token = self.tok
            if token.kind not in ("symbol", "keyword") or token.value not in BINARY_PRIORITY:
                break
            left, right = BINARY_PRIORITY[token.value]
            if left <= limit:
                break
            self.index += 1
            self.expr(right)

    def simple_expr(self):
        token = self.tok
        kind, value = token.kind, token.value
        if kind in ("number", "string"):
            self.index += 1
        elif kind == "interp":
            self.index += 1
            self.interp(token)
        elif kind == "keyword" and value in ("nil", "true", "false"):
            self.index += 1
        elif kind == "symbol" and value == "...":
            self.index += 1
        elif kind == "symbol" and value == "{":
            self.table()
        elif kind == "keyword" and value == "function":
            self.index += 1
            self.function_body(is_method=False)
        elif kind == "keyword" and value == "if":
            self.if_expr()
        else:
            self.suffixed_expr()
            self.cast()
            return
        self.cast()

    def cast(self):
        while self.accept("::"):
            self.type_expr()

    def interp(self, token):
        for part in token.parts:
            sub = Parser(part, self.report, self.scopes)
            sub.expr()
            if sub.tok.kind != "eof":
                sub.error("unexpected token inside {} of an interpolated string")

    def if_expr(self):
        self.expect("if")
        self.expr()
        self.expect("then", "'then' in an if-expression")
        self.expr()
        while self.accept("elseif"):
            self.expr()
            self.expect("then", "'then' in an if-expression")
            self.expr()
        self.expect("else", "'else' (an if-expression always needs one)")
        self.expr()

    def table(self):
        self.expect("{")
        while not self.at("}"):
            if self.at("["):
                self.index += 1
                self.expr()
                self.expect("]")
                self.expect("=")
                self.expr()
            elif self.tok.kind == "name" and self.peek().kind == "symbol" and self.peek().value == "=":
                self.index += 2
                self.expr()
            else:
                self.expr()
            if not (self.accept(",") or self.accept(";")):
                break
        self.expect("}", "'}' to close the table (missing a comma?)")

    def primary_expr(self):
        """Returns ('name', token) or ('paren', None)."""
        token = self.tok
        if token.kind == "name":
            self.index += 1
            return ("name", token)
        if self.accept("("):
            self.expr()
            self.expect(")")
            return ("paren", None)
        self.error("unexpected token in an expression")

    def call_args(self):
        token = self.tok
        if token.kind in ("string", "interp"):
            self.index += 1
            if token.kind == "interp":
                self.interp(token)
        elif self.at("{"):
            self.table()
        elif self.at("("):
            self.index += 1
            if not self.at(")"):
                self.expr_list()
            self.expect(")", "')' to close the call (missing a comma?)")
        else:
            self.error("expected call arguments")

    def suffixed_expr(self, as_statement=False):
        """Parses a prefix expression with its suffixes.
        Returns (kind, name_token): kind is 'call', 'name', 'index' or 'paren'."""
        kind, token = self.primary_expr()
        first = token
        pending_read = kind == "name"
        while True:
            current = self.tok
            if current.kind == "symbol" and current.value == ".":
                if pending_read:
                    self.read(first)
                    pending_read = False
                self.index += 1
                if self.tok.kind not in ("name", "keyword"):
                    self.error("expected a field name after '.'")
                self.index += 1
                kind = "index"
            elif current.kind == "symbol" and current.value == "[":
                if pending_read:
                    self.read(first)
                    pending_read = False
                self.index += 1
                self.expr()
                self.expect("]")
                kind = "index"
            elif current.kind == "symbol" and current.value == ":" and self.peek().kind == "name" and (
                self.peek(2).kind in ("string", "interp") or self.peek(2).value in ("(", "{")
            ):
                if pending_read:
                    self.read(first)
                    pending_read = False
                self.index += 2
                self.call_args()
                kind = "call"
            elif (current.kind == "symbol" and current.value in ("(", "{")) or current.kind in ("string", "interp"):
                # A call. In statement position a '(' on a new line is ambiguous in Lua; Luau treats it as a call.
                if pending_read:
                    self.read(first)
                    pending_read = False
                self.call_args()
                kind = "call"
            else:
                break
        if pending_read and not as_statement:
            self.read(first)
        return kind, first

    def function_body(self, is_method, self_line=0):
        if self.at("<"):
            self.index += 1
            self.name()
            self.accept("...")
            while self.accept(","):
                self.name()
                self.accept("...")
            self.expect(">")
        self.expect("(", "'(' to start the parameter list")
        self.push()
        if is_method:
            self.scopes[-1]["self"] = Local("self", self_line, "self")
        if not self.at(")"):
            while True:
                if self.accept("..."):
                    if self.accept(":"):
                        self.type_list_item()
                    break
                param = self.name("a parameter name")
                self.declare(param, "param")
                if self.accept(":"):
                    self.type_annotation()
                if not self.accept(","):
                    break
        self.expect(")", "')' to close the parameter list")
        if self.accept(":"):
            self.return_type()
        saved_loops = self.loop_depth
        self.loop_depth = 0
        self.block()
        self.loop_depth = saved_loops
        self.expect("end", "'end' to close the function")
        self.pop()

    # -- statements ------------------------------------------------------------------------------
    def block(self):
        self.push()
        self.block_body()
        self.pop()

    def block_body(self):
        while True:
            token = self.tok
            if token.kind == "eof" or (token.kind == "keyword" and token.value in BLOCK_END):
                return
            if self.statement():
                self.accept(";")
                token = self.tok
                if not (token.kind == "eof" or (token.kind == "keyword" and token.value in BLOCK_END)):
                    self.error("a block must end after 'return', 'break' or 'continue'")
                return
            self.accept(";")

    def statement(self):
        """Returns True when the statement ends its block (return, break, continue)."""
        token = self.tok
        kind, value = token.kind, token.value
        if kind == "keyword":
            if value == "local":
                self.local()
            elif value == "function":
                self.function_statement()
            elif value == "if":
                self.if_statement()
            elif value == "while":
                self.index += 1
                self.expr()
                self.expect("do")
                self.loop_depth += 1
                self.block()
                self.loop_depth -= 1
                self.expect("end", "'end' to close the while loop")
            elif value == "for":
                self.for_statement()
            elif value == "repeat":
                self.index += 1
                self.loop_depth += 1
                self.push()
                self.block_body()
                self.expect("until")
                self.expr()
                self.pop()
                self.loop_depth -= 1
            elif value == "do":
                self.index += 1
                self.block()
                self.expect("end", "'end' to close the do block")
            elif value == "return":
                self.index += 1
                nxt = self.tok
                if not (nxt.kind == "eof" or (nxt.kind == "keyword" and nxt.value in BLOCK_END) or self.at(";")):
                    self.expr_list()
                return True
            elif value == "break":
                self.index += 1
                if self.loop_depth == 0:
                    self.error("'break' outside a loop", token)
                return True
            else:
                self.error("unexpected keyword")
            return False
        if kind == "name" and value == "continue":
            nxt = self.peek()
            ends = nxt.kind == "eof" or (nxt.kind == "keyword" and nxt.value in BLOCK_END) or (
                nxt.kind == "symbol" and nxt.value == ";"
            )
            if ends:
                self.index += 1
                if self.loop_depth == 0:
                    self.error("'continue' outside a loop", token)
                return True
        if kind == "name" and value in ("type", "export") and self.peek().kind == "name":
            if value == "export":
                self.index += 1
                if not (self.tok.value == "type" and self.peek().kind == "name"):
                    self.error("expected 'type' after 'export'")
            self.index += 1
            self.name("a type name")
            if self.at("<"):
                self.index += 1
                self.name()
                while self.accept(","):
                    self.name()
                self.expect(">")
            self.expect("=", "'=' in a type alias")
            self.type_expr()
            return False
        self.expression_statement()
        return False

    def local(self):
        self.expect("local")
        if self.accept("function"):
            name = self.name("a function name")
            self.declare(name, "function")
            self.function_body(is_method=False)
            return
        names = [self.name("a variable name")]
        if self.accept(":"):
            self.type_annotation()
        while self.accept(","):
            names.append(self.name("a variable name"))
            if self.accept(":"):
                self.type_annotation()
        if self.accept("="):
            self.expr_list()
        elif self.tok.kind == "symbol" and self.tok.value in COMPOUND:
            self.error("a compound assignment cannot follow 'local'")
        for name in names:
            self.declare(name, "local")

    def function_statement(self):
        self.expect("function")
        first = self.name("a function name")
        is_method = False
        if self.at(".") or self.at(":"):
            self.read(first)
            while self.accept("."):
                self.index += 1 if self.tok.kind in ("name", "keyword") else 0
            if self.accept(":"):
                self.name("a method name")
                is_method = True
        else:
            self.write(first)
        self.function_body(is_method=is_method, self_line=first.line)

    def if_statement(self):
        self.expect("if")
        self.expr()
        self.expect("then", "'then'")
        self.block()
        while self.at("elseif"):
            self.index += 1
            self.expr()
            self.expect("then", "'then'")
            self.block()
        if self.accept("else"):
            self.block()
        self.expect("end", "'end' to close the if")

    def for_statement(self):
        self.expect("for")
        names = [self.name("a loop variable")]
        if self.accept(":"):
            self.type_annotation()
        if self.at("="):
            self.index += 1
            self.expr()
            self.expect(",", "',' in a numeric for")
            self.expr()
            if self.accept(","):
                self.expr()
        else:
            while self.accept(","):
                names.append(self.name("a loop variable"))
                if self.accept(":"):
                    self.type_annotation()
            self.expect("in", "'in' or '=' in a for loop")
            self.expr_list()
        self.expect("do", "'do'")
        self.push()
        for name in names:
            self.declare(name, "loop")
        self.loop_depth += 1
        self.block_body()
        self.loop_depth -= 1
        self.pop()
        self.expect("end", "'end' to close the for loop")

    def expression_statement(self):
        start = self.tok
        kind, first = self.suffixed_expr(as_statement=True)
        token = self.tok
        if token.kind == "symbol" and (token.value == "=" or token.value == ","):
            targets = [(kind, first)]
            while self.accept(","):
                targets.append(self.suffixed_expr(as_statement=True))
            self.expect("=", "'=' in an assignment")
            self.expr_list()
            for target_kind, target in targets:
                if target_kind == "name":
                    self.write(target)
                elif target_kind in ("call", "paren"):
                    self.error("cannot assign to this expression", start)
        elif token.kind == "symbol" and token.value in COMPOUND:
            if kind == "name":
                self.read(first)
                self.write(first)
            elif kind in ("call", "paren"):
                self.error("cannot assign to this expression", start)
            self.index += 1
            self.expr()
        elif kind != "call":
            if kind == "name":
                self.error("this name is not a statement on its own (missing '=' or a call?)", start)
            self.error("this expression is not a statement (missing '=' or a call?)", start)

    def chunk(self):
        self.block_body()
        if self.tok.kind != "eof":
            self.error("unexpected token at the top level (an extra 'end'?)")
        # report unused top-level locals too
        scope = self.scopes[0]
        for local in scope.values():
            if local.reads == 0 and local.kind in ("local", "function") and not local.name.startswith("_"):
                self.report.append((local.line, f"local '{local.name}' is never read"))


def check(path):
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    report = []
    try:
        tokens = Lexer(text).tokens()
        tokens.append(Token("eof", None, text.count("\n") + 1))
        Parser(tokens, report).chunk()
    except LuauError as problem:
        report.append((problem.line, f"SYNTAX ERROR: {problem}"))
    return sorted(set(report))


def main():
    failed = False
    for path in sys.argv[1:]:
        report = check(path)
        status = "ok" if not report else f"{len(report)} finding(s)"
        print(f"{path}: {status}")
        for line, message in report:
            print(f"    line {line}: {message}")
            if message.startswith("SYNTAX"):
                failed = True
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
