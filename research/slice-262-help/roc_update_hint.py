"""Slice 262b (B12, R-RU5, Q262-5, Q262-6): add the project hint of `tln roc update` to expected files.
Usage: python3 roc_update_hint.py <case dir> <pin id or -> [walk|nowalk per run...]
Each run of fx/commands that ends with exit 0 gets, at the end of its calls, the walk of R-PD1 to R-PD6 (a guess of the order,
the code agent may dispute it): cwd, list_dirs $PROJECT, list_dirs $WORK, and with a project read_files $PROJECT/talon.toml,
read_files $PROJECT/main.roc. With a pin that is not the new id: line A after the run's lines (stdout; stderr with --json;
none with --quiet). --json: data gets "project" after "changed"."""
import sys, re, json
case, pin = sys.argv[1], sys.argv[2]
proj = pin != "-"
cmds = [l for l in open(f"{case}/fx/commands").read().split("\n") if l.strip() and not l.startswith("#")]
line_a = lambda p: f"note: the project $PROJECT/main.roc pins {p}, so it stays on that compiler. To move it with a check, run: tln upgrade roc"
walk = ["cwd", "list_dirs $PROJECT", "list_dirs $WORK"] + (["read_files $PROJECT/talon.toml", "read_files $PROJECT/main.roc"] if proj else [])
# stdout: runs
out = open(f"{case}/expect/stdout").read().split("\n")
runs, cur = [], None
for l in out:
    if l.startswith("== "):
        cur = [l]; runs.append(cur)
    elif cur is not None:
        cur.append(l)
assert len(runs) == len(cmds), (len(runs), len(cmds))
ok, newid, js, quiet = [], [], [], []
for r, c in zip(runs, cmds):
    ok.append(any(x == "exit 0" for x in r))
    js.append("--json" in c.split()); quiet.append("--quiet" in c.split())
    nid = None
    for x in r:
        m = re.match(r"^(?:installed (\S+)|(\S+) is the newest)$", x)
        if m: nid = m.group(1) or m.group(2)
        if x.startswith('{"schema"'):
            nid = json.loads(x)["data"]["id"]
    newid.append(nid)
stderr_adds = []
new_out = []
for i, r in enumerate(runs):
    r = list(r)
    if ok[i]:
        a = proj and newid[i] != pin
        for k, x in enumerate(r):
            if x.startswith('{"schema"'):
                project = json.dumps({"file": "$PROJECT/main.roc", "pin": pin, "uses": "pin"}, separators=(",", ":")) if proj else "null"
                assert '"changed":' in x
                r[k] = re.sub(r'("changed":(?:true|false))', r'\1,"project":' + project.replace("\\", "\\\\"), x, count=1)
        if a and not quiet[i]:
            if js[i]:
                stderr_adds.append((i, line_a(pin)))
            else:
                e = r.index("exit 0"); r.insert(e, line_a(pin))
    new_out += r
open(f"{case}/expect/stdout", "w").write("\n".join(new_out))
# calls: split on args
calls = open(f"{case}/expect/calls.log").read().split("\n")
segs, cur = [], None
tail = calls[-1] == ""
for l in (calls[:-1] if tail else calls):
    if l == "args":
        cur = [l]; segs.append(cur)
    else:
        cur.append(l)
assert len(segs) == len(cmds), (len(segs), len(cmds))
res = []
for i, s in enumerate(segs):
    res += s + (walk if ok[i] else [])
open(f"{case}/expect/calls.log", "w").write("\n".join(res) + ("\n" if tail else ""))
print(case, "ok runs:", [i + 1 for i in range(len(ok)) if ok[i]], "new ids:", newid, "stderr adds (run index):", [i + 1 for i, _ in stderr_adds])
