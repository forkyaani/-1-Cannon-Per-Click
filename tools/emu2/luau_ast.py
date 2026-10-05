"""Builds a syntax tree from Luau source, for luau_vm.py to run. Types are parsed and thrown away."""
import re

from luau_check import BINARY_PRIORITY, BLOCK_END, COMPOUND, UNARY_PRIORITY, Lexer, LuauError, Parser, Token

ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", '"': '"', "'": "'", "`": "`", "{": "{", "\n": "\n"}


def unescape(raw):
    out = []
    i = 0
    while i < len(raw):
        ch = raw[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        nxt = raw[i + 1]
        if nxt in ESCAPES:
            out.append(ESCAPES[nxt])
            i += 2
        elif nxt == "x":
            out.append(chr(int(raw[i + 2 : i + 4], 16)))
            i += 4
        elif nxt == "u":
            end = raw.index("}", i)
            out.append(chr(int(raw[i + 3 : end], 16)))
            i = end + 1
        elif nxt == "z":
            i += 2
            while i < len(raw) and raw[i] in " \t\r\n":
                i += 1
        elif nxt.isdigit():
            match = re.match(r"\d{1,3}", raw[i + 1 :])
            out.append(chr(int(match.group())))
            i += 1 + len(match.group())
        else:
            raise LuauError(f"bad escape \\{nxt}", 0)
    return "".join(out)


class AstLexer(Lexer):
    """Like Lexer, but an interpolated string keeps its literal text too."""

    def read_interp(self):
        text = self.text
        line = self.line
        self.pos += 1
        parts = []
        literal = []
        while True:
            if self.pos >= len(text):
                self.error("unfinished interpolated string")
            ch = text[self.pos]
            if ch == "\\":
                literal.append(text[self.pos : self.pos + 2])
                self.pos += 2
            elif ch == "`":
                self.pos += 1
                parts.append(("text", unescape("".join(literal))))
                return Token("interp", "`", line, parts)
            elif ch == "\n":
                self.error("unfinished interpolated string (newline)")
            elif ch == "{":
                parts.append(("text", unescape("".join(literal))))
                literal = []
                self.pos += 1
                tokens = self.tokens(stop_at_brace=True)
                tokens.append(Token("eof", None, self.line))
                parts.append(("expr", tokens))
            else:
                literal.append(ch)
                self.pos += 1


class AstParser(Parser):
    """Reuses the checker's token helpers and type parsing; everything else builds nodes.
    A node is a tuple: (kind, line, ...)."""

    def __init__(self, tokens):
        super().__init__(tokens, report=[])

    # scopes are the checker's business
    def push(self):
        pass

    def pop(self):
        pass

    # -- expressions -----------------------------------------------------------------------------
    def expr_list(self):
        items = [self.expr()]
        while self.accept(","):
            items.append(self.expr())
        return items

    def expr(self, limit=0):
        token = self.tok
        if (token.kind == "keyword" and token.value == "not") or (token.kind == "symbol" and token.value in ("-", "#")):
            self.index += 1
            left = ("unop", token.line, token.value, self.expr(UNARY_PRIORITY))
        else:
            left = self.simple_expr()
        while True:
            token = self.tok
            if token.kind not in ("symbol", "keyword") or token.value not in BINARY_PRIORITY:
                break
            lprio, rprio = BINARY_PRIORITY[token.value]
            if lprio <= limit:
                break
            self.index += 1
            right = self.expr(rprio)
            if token.value in ("and", "or"):
                left = (token.value, token.line, left, right)
            else:
                left = ("binop", token.line, token.value, left, right)
        return left

    def simple_expr(self):
        token = self.tok
        kind, value, line = token.kind, token.value, token.line
        if kind == "number":
            self.index += 1
            text = value.replace("_", "")
            if text[:2].lower() == "0x":
                node = ("const", line, float(int(text, 16)))
            elif text[:2].lower() == "0b":
                node = ("const", line, float(int(text[2:], 2)))
            else:
                node = ("const", line, float(text))
        elif kind == "string":
            self.index += 1
            node = ("const", line, unescape(value) if "\\" in value else value)
        elif kind == "interp":
            self.index += 1
            node = self.interp(token)
        elif kind == "keyword" and value in ("nil", "true", "false"):
            self.index += 1
            node = ("const", line, {"nil": None, "true": True, "false": False}[value])
        elif kind == "symbol" and value == "...":
            self.index += 1
            node = ("vararg", line)
        elif kind == "symbol" and value == "{":
            node = self.table()
        elif kind == "keyword" and value == "function":
            self.index += 1
            node = self.function_body(False, name="anonymous")
        elif kind == "keyword" and value == "if":
            node = self.if_expr()
        else:
            node = self.suffixed_expr()
        while self.accept("::"):
            self.type_expr()
            node = ("paren", line, node)  # a cast keeps one value, like parentheses
        return node

    def interp(self, token):
        parts = []
        for kind, payload in token.parts:
            if kind == "text":
                if payload:
                    parts.append(("const", token.line, payload))
            else:
                sub = AstParser(payload)
                parts.append(sub.expr())
                if sub.tok.kind != "eof":
                    sub.error("unexpected token inside {} of an interpolated string")
        return ("interp", token.line, parts)

    def if_expr(self):
        line = self.tok.line
        self.expect("if")
        arms = []
        cond = self.expr()
        self.expect("then")
        arms.append((cond, self.expr()))
        while self.accept("elseif"):
            cond = self.expr()
            self.expect("then")
            arms.append((cond, self.expr()))
        self.expect("else")
        return ("ifexpr", line, arms, self.expr())

    def table(self):
        line = self.tok.line
        self.expect("{")
        items = []
        while not self.at("}"):
            if self.at("["):
                self.index += 1
                key = self.expr()
                self.expect("]")
                self.expect("=")
                items.append(("keyed", key, self.expr()))
            elif self.tok.kind == "name" and self.peek().kind == "symbol" and self.peek().value == "=":
                key = self.tok.value
                self.index += 2
                items.append(("keyed", ("const", line, key), self.expr()))
            else:
                items.append(("pos", None, self.expr()))
            if not (self.accept(",") or self.accept(";")):
                break
        self.expect("}")
        return ("table", line, items)

    def call_args(self):
        token = self.tok
        if token.kind == "string":
            self.index += 1
            return [("const", token.line, unescape(token.value) if "\\" in token.value else token.value)]
        if token.kind == "interp":
            self.index += 1
            return [self.interp(token)]
        if self.at("{"):
            return [self.table()]
        self.expect("(")
        args = []
        if not self.at(")"):
            args = self.expr_list()
        self.expect(")")
        return args

    def suffixed_expr(self, as_statement=False):
        token = self.tok
        if token.kind == "name":
            self.index += 1
            node = ("name", token.line, token.value)
        elif self.accept("("):
            node = ("paren", token.line, self.expr())
            self.expect(")")
        else:
            self.error("unexpected token in an expression")
        while True:
            current = self.tok
            line = current.line
            if current.kind == "symbol" and current.value == ".":
                self.index += 1
                field = self.tok
                self.index += 1
                node = ("index", line, node, ("const", line, field.value))
            elif current.kind == "symbol" and current.value == "[":
                self.index += 1
                key = self.expr()
                self.expect("]")
                node = ("index", line, node, key)
            elif current.kind == "symbol" and current.value == ":" and self.peek().kind == "name" and (
                self.peek(2).kind in ("string", "interp") or self.peek(2).value in ("(", "{")
            ):
                method = self.peek().value
                self.index += 2
                node = ("method", line, node, method, self.call_args())
            elif (current.kind == "symbol" and current.value in ("(", "{")) or current.kind in ("string", "interp"):
                node = ("call", line, node, self.call_args())
            else:
                return node

    def function_body(self, is_method, self_line=0, name="?"):
        line = self.tok.line
        if self.at("<"):
            while not self.accept(">"):
                self.index += 1
        self.expect("(")
        params = ["self"] if is_method else []
        vararg = False
        if not self.at(")"):
            while True:
                if self.accept("..."):
                    vararg = True
                    if self.accept(":"):
                        self.type_list_item()
                    break
                params.append(self.name().value)
                if self.accept(":"):
                    self.type_annotation()
                if not self.accept(","):
                    break
        self.expect(")")
        if self.accept(":"):
            self.return_type()
        body = self.block()
        self.expect("end")
        return ("function", line, params, vararg, body, name)

    # -- statements ------------------------------------------------------------------------------
    def block(self):
        statements = []
        while True:
            token = self.tok
            if token.kind == "eof" or (token.kind == "keyword" and token.value in BLOCK_END):
                return statements
            statement = self.statement()
            statements.append(statement)
            self.accept(";")
            if statement[0] in ("return", "break", "continue"):
                return statements

    def statement(self):
        token = self.tok
        kind, value, line = token.kind, token.value, token.line
        if kind == "keyword":
            if value == "local":
                self.index += 1
                if self.accept("function"):
                    name = self.name().value
                    return ("localfunction", line, name, self.function_body(False, name=name))
                names = [self.name().value]
                if self.accept(":"):
                    self.type_annotation()
                while self.accept(","):
                    names.append(self.name().value)
                    if self.accept(":"):
                        self.type_annotation()
                exprs = self.expr_list() if self.accept("=") else []
                return ("local", line, names, exprs)
            if value == "function":
                self.index += 1
                target = ("name", line, self.name().value)
                label = target[2]
                is_method = False
                while self.accept("."):
                    field = self.tok.value
                    self.index += 1
                    target = ("index", line, target, ("const", line, field))
                    label += "." + field
                if self.accept(":"):
                    field = self.name().value
                    target = ("index", line, target, ("const", line, field))
                    label += ":" + field
                    is_method = True
                return ("assign", line, [target], [self.function_body(is_method, name=label)])
            if value == "if":
                self.index += 1
                arms = []
                cond = self.expr()
                self.expect("then")
                arms.append((cond, self.block()))
                orelse = None
                while self.at("elseif"):
                    self.index += 1
                    cond = self.expr()
                    self.expect("then")
                    arms.append((cond, self.block()))
                if self.accept("else"):
                    orelse = self.block()
                self.expect("end")
                return ("if", line, arms, orelse)
            if value == "while":
                self.index += 1
                cond = self.expr()
                self.expect("do")
                body = self.block()
                self.expect("end")
                return ("while", line, cond, body)
            if value == "for":
                self.index += 1
                names = [self.name().value]
                if self.accept(":"):
                    self.type_annotation()
                if self.accept("="):
                    start = self.expr()
                    self.expect(",")
                    stop = self.expr()
                    step = self.expr() if self.accept(",") else None
                    self.expect("do")
                    body = self.block()
                    self.expect("end")
                    return ("fornum", line, names[0], start, stop, step, body)
                while self.accept(","):
                    names.append(self.name().value)
                    if self.accept(":"):
                        self.type_annotation()
                self.expect("in")
                exprs = self.expr_list()
                self.expect("do")
                body = self.block()
                self.expect("end")
                return ("forin", line, names, exprs, body)
            if value == "repeat":
                self.index += 1
                body = self.block()
                self.expect("until")
                return ("repeat", line, body, self.expr())
            if value == "do":
                self.index += 1
                body = self.block()
                self.expect("end")
                return ("do", line, body)
            if value == "return":
                self.index += 1
                nxt = self.tok
                exprs = []
                if not (nxt.kind == "eof" or (nxt.kind == "keyword" and nxt.value in BLOCK_END) or self.at(";")):
                    exprs = self.expr_list()
                return ("return", line, exprs)
            if value == "break":
                self.index += 1
                return ("break", line)
            self.error("unexpected keyword")
        if kind == "name" and value == "continue":
            nxt = self.peek()
            if nxt.kind == "eof" or (nxt.kind == "keyword" and nxt.value in BLOCK_END) or (nxt.kind == "symbol" and nxt.value == ";"):
                self.index += 1
                return ("continue", line)
        if kind == "name" and value in ("type", "export") and self.peek().kind == "name":
            if value == "export":
                self.index += 1
            self.index += 1
            self.name()
            if self.at("<"):
                while not self.accept(">"):
                    self.index += 1
            self.expect("=")
            self.type_expr()
            return ("do", line, [])
        node = self.suffixed_expr()
        token = self.tok
        if token.kind == "symbol" and token.value in ("=", ","):
            targets = [node]
            while self.accept(","):
                targets.append(self.suffixed_expr())
            self.expect("=")
            return ("assign", line, targets, self.expr_list())
        if token.kind == "symbol" and token.value in COMPOUND:
            self.index += 1
            return ("compound", line, node, token.value[:-1], self.expr())
        if node[0] not in ("call", "method"):
            self.error("this expression is not a statement")
        return ("callstat", line, node)


def parse(text):
    tokens = AstLexer(text).tokens()
    tokens.append(Token("eof", None, text.count("\n") + 1))
    parser = AstParser(tokens)
    body = parser.block()
    if parser.tok.kind != "eof":
        parser.error("unexpected token at the top level")
    return body
