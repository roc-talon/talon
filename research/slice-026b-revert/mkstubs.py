#!/usr/bin/env python3
"""Makes research/slice-026b-revert/stubs/ from reference/ (the state that the test agent hands over: the bodies of the new decisions and of `roc use` are `crash "todo"`).
Usage: python3 research/slice-026b-revert/mkstubs.py   (run from the repo root, after swap.sh save-reference)"""
import os, re
R = "research/slice-026b-revert"
ref = lambda f: open(f"{R}/reference/{f}").read()
out = {}

def stub_body(text, name):
    """Replace the body of `name = |params|` by crash "todo", with the params as _x."""
    m = re.search(r"^(\t%s = )\|([a-z_, ]+)\|" % re.escape(name), text, re.M)
    assert m, name
    params = [("_" + p.strip()) for p in m.group(2).split(",")]
    rest = text[m.end():]
    ends = [c for c in (rest.find("\n\n"), rest.find("\n}\n")) if c >= 0]
    end = m.end() + min(ends)
    return text[:m.start()] + f'\t{name} = |{", ".join(params)}| crash "todo"' + text[end:]

# Manage: the 6 decisions are stubs. The private helper `use_refused` and the import of Compiler go.
t = ref("cli/lib/Manage.roc")
for n in ["read_use", "use_pinnable", "use_plan", "use_note", "use_report", "use_data"]:
    t = stub_body(t, n)
i = t.index("# R-U1: the failure for a ref that cannot be a pin.")
j = t.index("\n\n", t.index("use_refused = |ref|", i)) + 2
t = t[:i] + t[j:]
t = t.replace("import Compiler\n", "", 1)
out["cli/lib/Manage.roc"] = t

t = ref("cli/lib/Pin.roc")
out["cli/lib/Pin.roc"] = stub_body(t, "use_gate")

t = ref("cli/lib/Consent.roc")
out["cli/lib/Consent.roc"] = stub_body(t, "use_download")

# Ladder: `use!` is a stub, its helper `no_bases` goes. The change of `probe_member!` (a pair of compilers) stays: it changes no result of `run!`.
t = ref("cli/lib/Ladder.roc")
i = t.index("\tuse! = |fx, request| {")
j = t.index("\n}\n\nno_bases", i)
t = t[:i] + '\tuse! = |_fx, _request| crash "todo"' + t[j:]
k = t.index("\nno_bases : ")
l = t.index("\n\n", k + 1) if False else t.index("no_bases = []", k) + len("no_bases = []\n")
t = t[:k] + "\n" + t[l:].lstrip("\n")
out["cli/lib/Ladder.roc"] = t

out["cli/lib/Run.roc"] = ref("cli/lib/Run.roc")
out["cli/lib/main.roc"] = ref("cli/lib/main.roc")

# RocUse: the head (the doc table) and the stub
r = ref("cli/lib/RocUse.roc")
head = r[:r.index("RocUse :: [].{")]
head = "\n".join(l for l in head.split("\n") if not l.startswith("import "))
head = "import Args\nimport Fx\n\n" + head.lstrip("\n")
out["cli/lib/RocUse.roc"] = head + 'RocUse :: [].{\n\n\t## Steps 1 to 11 of `tln roc use`. The body is the work of the code agent.\n\tuse! : Fx, Args => I32\n\tuse! = |_fx, _args| crash "todo"\n}\n'

for f, text in out.items():
    path = f"{R}/stubs/{f}"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)
print("stubs written:", len(out))
