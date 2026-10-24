#!/usr/bin/env python3
"""Makes research/slice-025b-revert/stubs/ from reference/ and before/: the 5 new functions get the body `crash "todo"`, the files that the code agent changes (ResolveBase, Proxy) are the files of before/,
Compiler.roc is the file of before/ with the new doc row (the body keeps the old text, so the test is red with a wrong value)."""
import os, re, shutil
R = "research/slice-025b-revert"
def rd(p): return open(p).read()
def wr(p, t):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(t)

def stub(path, name, params, ):
    pass

def replace_body(text, header, new_body_lines):
    """header: the first line of the definition `name = |args| {` or `name = |args| expr`. The body ends at the first line that is `\t}` (a block) or the same line (one expression)."""
    i = text.index(header)
    j = text.index("\n", i)
    first = text[i:j]
    if first.rstrip().endswith("{"):
        k = text.index("\n\t}\n", j) + len("\n\t}")
        return text[:i] + new_body_lines + text[k:]
    return text[:i] + new_body_lines + text[j:]

ref = lambda f: rd(f"{R}/reference/cli/lib/{f}")
bef = lambda f: rd(f"{R}/before/cli/lib/{f}")

t = ref("Toolchain.roc")
t = replace_body(t, "\trange_pick = |facts| {", '\trange_pick = |_facts| crash "todo"')
t = replace_body(t, "\trange_failed = |facts| {", '\trange_failed = |_facts| crash "todo"')
wr(f"{R}/stubs/cli/lib/Toolchain.roc", t)

c = ref("Consent.roc")
c = replace_body(c, "\tauto_refuses = |run| ", '\tauto_refuses = |_run| crash "todo"')
c = replace_body(c, "\trange_refused = |range| ", '\trange_refused = |_range| crash "todo"')
wr(f"{R}/stubs/cli/lib/Consent.roc", c)

r = ref("RocInstall.roc")
r = replace_body(r, "\trange_id! = |fx, run| {", '\trange_id! = |_fx, _run| crash "todo"')
wr(f"{R}/stubs/cli/lib/RocInstall.roc", r)

# Compiler.roc: the file of before/ with the doc row of the reference (the body is the old one)
cb = bef("Compiler.roc")
cr = ref("Compiler.roc")
m_old = re.search(r"\t## \| `NoneInRange\(<req text>\)` \|.*\n", cb).group(0)
m_new = re.search(r"\t## \| `NoneInRange\(<req text>\)` \|.*\n", cr).group(0)
wr(f"{R}/stubs/cli/lib/Compiler.roc", cb.replace(m_old, m_new))

for f in ("ResolveBase.roc", "Proxy.roc"):
    wr(f"{R}/stubs/cli/lib/{f}", bef(f))
