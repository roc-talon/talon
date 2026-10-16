# Prototype of the smoke-app generator (Resolution 4, R-SM2). Talon does this in Roc.
# Usage: python3 -I gen.py <platform main.roc> <platform URL>   -> prints the app
# The app gives the platform each value of its `requires` clause:
#   a function type   -> a lambda with one `_` for each argument (`()` is no argument), body `crash`
#   a record type     -> a record with a generated value for each field
#   a `[A : a]` alias -> `A : {}`
#   any other type    -> no app (exit 2): a top-level constant is evaluated when roc compiles it
import re, sys

CRASH = 'crash "talon smoke test"'

def requires_body(src):
    src = re.sub(r"#[^\n]*", "", src)
    i = src.index("requires")
    # Take the last {...} group before `exposes`: `requires {} { main! : ... }` and `requires { ... }` both work.
    j = src.index("exposes", i)
    part = src[i + len("requires"):j].strip()
    groups, depth, start = [], 0, None
    for k, ch in enumerate(part):
        if ch in "{([":
            if depth == 0: start = k
            depth += 1
        elif ch in "})]":
            depth -= 1
            if depth == 0: groups.append(part[start + 1:k])
    return groups[-1].strip()

def split_top(s, sep=","):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch in "{([": depth += 1
        if ch in "})]": depth -= 1
        if ch == sep and depth == 0: out.append(cur); cur = ""
        else: cur += ch
    if cur.strip(): out.append(cur)
    return [x.strip() for x in out if x.strip()]

def top_arrow(t):
    depth = 0
    for k in range(len(t) - 1):
        if t[k] in "{([": depth += 1
        if t[k] in "})]": depth -= 1
        if depth == 0 and t[k:k + 2] in ("=>", "->"): return k
    return -1

def gen(t, indent):
    t = t.strip()
    k = top_arrow(t)
    if k >= 0:
        args = t[:k].strip()
        n = 0 if args == "()" else len(split_top(args))
        return "|" + ", ".join(["_"] * n) + "| " + CRASH
    if t.startswith("{") and t.endswith("}"):
        pad = "\t" * (indent + 1)
        fields = []
        # A comma at depth 0 also separates function arguments, so a piece that does not start with `name :` joins the field before it.
        merged = []
        for piece in split_top(t[1:-1]):
            if re.match(r"[a-z_][A-Za-z0-9_]*!?\s*:", piece) or not merged: merged.append(piece)
            else: merged[-1] += ", " + piece
        for f in merged:
            name, ftype = f.split(":", 1)
            fields.append(f"{pad}{name.strip()}: {gen(ftype, indent + 1)},")
        return "{\n" + "\n".join(fields) + "\n" + "\t" * indent + "}"
    raise SystemExit(2)

def main():
    src = open(sys.argv[1]).read()
    body = requires_body(src)
    aliases, rest = [], body
    m = re.match(r"\[(.*?)\]\s*for\s+(.*)", body, re.S)
    if m:
        aliases = [a.split(":")[0].strip() for a in split_top(m.group(1))]
        rest = m.group(2)
    name, rtype = rest.split(":", 1)
    name = name.strip()
    print(f'app [{", ".join(aliases + [name])}] {{ pf: platform "{sys.argv[2]}" }}\n')
    for a in aliases: print(f"{a} : {{}}\n")
    print(f"{name} = {gen(rtype, 0)}")

main()
