"""Slice 262b (B9, R-AD28, R-UP11): add the anchor note to expected files by hand-checked rule.
After the block of `<path>/talon.toml: <k> = ...` lines of an install/add/update run (not upgrade, not --quiet),
one line `note: <k> is pinned to =<v>: ...` for each value `=<v>` of the block, in the order of the block.
In a JSON envelope of such a run, the text (no `note: `) is appended to data.notes.
Usage: python3 anchor_note.py <file> [upgrade-marker]. Prints what it changed."""
import re, sys, json
TOML = re.compile(r'^\S*talon\.toml: ([A-Za-z0-9_.-]+) = "=([^"]+)"( \(was .*\))?$')
ANY_TOML = re.compile(r'^\S*talon\.toml: ')
def text(k, v):
    return f"{k} is pinned to ={v}: tln update keeps it there, and tln upgrade {k} moves it. To start at {v} with no pin, add --no-pin."
def skip(cmd):
    w = cmd.split()
    return "upgrade" in w[:3] or "--quiet" in w
def fix(path):
    lines = open(path).read().split("\n")
    out, cmd, i, changed = [], "", 0, 0
    while i < len(lines):
        l = lines[i]
        if l.startswith("== "):
            cmd = l[3:]
        if ANY_TOML.match(l):
            block = []
            while i < len(lines) and ANY_TOML.match(lines[i]):
                block.append(lines[i]); i += 1
            out += block
            if not skip(cmd):
                for b in block:
                    m = TOML.match(b)
                    if m and not m.group(3):
                        out.append("note: " + text(m.group(1), m.group(2))); changed += 1
            continue
        if l.startswith('{"schema":1') and '"toml":[' in l and not skip(cmd):
            doc = json.loads(l)
            d = doc.get("data") or {}
            adds = [text(t["key"], t["value"][1:]) for t in d.get("toml", []) if t["value"].startswith("=")]
            if adds:
                # keep the key order and the compact form of the file
                old = json.dumps(d["notes"], separators=(",", ":"), ensure_ascii=False)
                new = json.dumps(d["notes"] + adds, separators=(",", ":"), ensure_ascii=False)
                key = '"notes":' + old
                assert l.count(key) == 1, (path, key)
                l = l.replace(key, '"notes":' + new); changed += 1
        out.append(l); i += 1
    open(path, "w").write("\n".join(out))
    print(path, changed)
for p in sys.argv[1:]:
    fix(p)
