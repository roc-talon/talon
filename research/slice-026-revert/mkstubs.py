#!/usr/bin/env python3
"""Makes research/slice-026-revert/stubs/ from reference/ and before/ (the state that the test agent hands over: bodies `crash "todo"`, the old text of Pin.toolchain_note).
Usage: python3 research/slice-026-revert/mkstubs.py   (run from the repo root, after swap.sh save-reference)"""
import os, re, shutil
R = "research/slice-026-revert"
ref = lambda f: open(f"{R}/reference/{f}").read()
bef = lambda f: open(f"{R}/before/{f}").read()
out = {}

def stub_body(text, name, sig_prefix):
    """Replace the body of `name = ...` (a lambda that starts after `name = |params|`) by crash "todo", keeping the params as _x."""
    m = re.search(r"^(\t%s = )\|([a-z_]+)\|" % re.escape(name), text, re.M)
    assert m, name
    start = m.start()
    # the body ends at the blank line that follows it (a module member is followed by an empty line, or by the end of the module)
    rest = text[m.end():]
    cut = rest.find("\n\n")
    cut2 = rest.find("\n}\n")
    ends = [c for c in (cut, cut2) if c >= 0]
    body_end = m.end() + min(ends)
    return text[:start] + f'\t{name} = |_{m.group(2)}| crash "todo"' + text[body_end:]

# Manage
t = ref("cli/lib/Manage.roc").replace("import Toolchain\n", "", 1)
for n in ["read_update", "update_move", "update_report", "update_data"]:
    t = stub_body(t, n, "")
out["cli/lib/Manage.roc"] = t
# Toolchain
t = ref("cli/lib/Toolchain.roc").replace("import Selector\n", "", 1)
t = stub_body(t, "needs_base", "")
out["cli/lib/Toolchain.roc"] = t
# Pin: the old body
out["cli/lib/Pin.roc"] = None  # filled below
p = ref("cli/lib/Pin.roc")
i = p.index("\ttoolchain_note = |facts| {")
j = p.index("\n\t}\n", i) + 4
p = p[:i] + '\ttoolchain_note = |facts| "ROC_TOOLCHAIN is ${facts.toolchain}, but the header pin is ${facts.pin}. This command keeps the pin. To change the pin, run tln roc use ${facts.toolchain}."\n' + p[j:]
out["cli/lib/Pin.roc"] = p
# RocManage: the reference with the code of `update!` and its helpers replaced by the stub (the doc stays)
t = ref("cli/lib/RocManage.roc")
i = t.index("\tupdate! = |fx, args| match Manage.read_update(args) {")
j = t.index("# What the edit of `config.toml` gives")
t = t[:i] + '\tupdate! = |_fx, _args| crash "todo"\n}\n\n' + t[j:]
out["cli/lib/RocManage.roc"] = t
t = ref("cli/lib/RocInstall.roc")
# the stub of RocInstall: the reference with the 2 code changes undone (the doc keeps the new text)
t = t.replace("import Base\n", "", 1).replace("import Compiler\n", "", 1)
t = t.replace("		base = if Toolchain.needs_base(run.id) Base.selected!(fx, { env: run.env, roots, installed: Compiler.installed(entries), config })? else Err(None)\n", "", 1)
t = t.replace("auto: lists.auto, base })", "auto: lists.auto, base: Err(None) })", 1)
out["cli/lib/RocInstall.roc"] = t
out["cli/lib/Install.roc"] = bef("cli/lib/Install.roc")
out["cli/lib/Run.roc"] = ref("cli/lib/Run.roc")
out["cli/lib/main.roc"] = ref("cli/lib/main.roc").replace("\t\tOnPath,\n", "", 1)
# Base: the head of the reference up to the signature, then the stub
r = ref("cli/lib/Base.roc")
k = r.index("\tselected! = |fx, facts| {")
head = r[:k]
head = re.sub(r"^import .*\n", "", head, flags=re.M)
head = "import Fail\nimport Fx\nimport Intent\nimport Roots\n\n" + head.lstrip("\n")
out["cli/lib/Base.roc"] = head + '\tselected! = |_fx, _facts| crash "todo"\n}\n'
for f, text in out.items():
    path = f"{R}/stubs/{f}"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)
# OnPath is only in the reference: no stub
print("stubs written:", len(out))
