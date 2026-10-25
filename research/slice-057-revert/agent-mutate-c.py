#!/usr/bin/env python3
"""Code agent mutations of slice 057c: python3 agent-mutate-c.py <part> [id ...].
Each mutation is one exact replace in a live file. The script runs the filtered test, then puts the original text back and checks the sha256.
Layers: l0 = `roc test` of tests/unit/l0-7.roc, l2 = tests/commands/run.sh <filter>, l3 = tests/run.sh <filter>.
A mutation is INVALID when the output has a compiler error or a warning (not a test failure)."""
import hashlib, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
ROC = os.environ.get("ROC") or os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
L0 = [ROC, "test", "tests/unit/l0-7.roc"]

L2 = ["tests/commands/run.sh", "run/rn3"]
L3 = ["tests/run.sh", "run/rn1"]
# id: (part, file, old, new, command)
M = {
    "c1-roc-file-over-key": ("c", "cli/lib/RunPlan.roc",
        "} else if facts.keys.contains(first) {",
        "} else if facts.keys.contains(first) and !first.ends_with(\".roc\") {", L0),
    "c2-no-url-internal": ("c", "cli/lib/RunTools.roc",
        "Fail.new(Frozen, \"the [tools] of", "Fail.new(Internal, \"the [tools] of", L0),
    "c3-stop-keeps-allow-downloads": ("c", "cli/lib/RunTools.roc",
        "Err(fail) => return Err(RunTools.stop(fail))", "Err(fail) => return Err(fail)", L2),
    "c4-never-reuse-build": ("c", "cli/lib/RunTools.roc",
        "match ToolsPlan.cached({ entries: know.found, bundle: ident.hash, target: know.target }) {\n\t\t\tOk(hit) => Ok({ bin:",
        "match ToolsPlan.cached({ entries: know.found, bundle: \"x${ident.hash}\", target: know.target }) {\n\t\t\tOk(hit) => Ok({ bin:", L2),
    "c5-reuse-misses-new-entry": ("c", "cli/lib/RunTools.roc",
        "found = know.found.concat(ensured.added)", "found = know.found.concat(ensured.added.drop_first(1))", L2),
    "c6-path-note-when-absent": ("c", "cli/lib/RunFlow.roc",
        "if on_path fx.err!(", "if !on_path fx.err!(", L2),
    "c7-tool-args-lost": ("c", "cli/lib/RunFlow.roc",
        "exec!(fx, flat, { program: got.bin, args: t.args, vars })",
        "exec!(fx, flat, { program: got.bin, args: [], vars })", L2),
    "c8-tool-build-reuse-l3": ("c", "cli/lib/RunTools.roc",
        "match ToolsPlan.cached({ entries: know.found, bundle: ident.hash, target: know.target }) {\n\t\t\tOk(hit) => Ok({ bin:",
        "match ToolsPlan.cached({ entries: know.found, bundle: \"x${ident.hash}\", target: know.target }) {\n\t\t\tOk(hit) => Ok({ bin:", L3),
}
LAST = set()


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def run(mid):
    part, f, old, new, cmd = M[mid]
    p = os.path.join(ROOT, f)
    orig = open(p).read()
    before = sha(p)
    n = orig.count(old)
    if mid in LAST:
        i = orig.rfind(old)
        mutated = orig[:i] + new + orig[i + len(old):]
    else:
        assert n == 1, f"{mid}: old text found {n} times"
        mutated = orig.replace(old, new)
    open(p, "w").write(mutated)
    try:
        r = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=900)
        out = r.stdout
        counts = re.findall(r"(\d+) errors? and (\d+) warnings?", out)
        bad = any(e != "0" or w != "0" for e, w in counts) or "build of the L2 app failed" in out or "Compilation failed" in out or "compiler errors" in out and "0 compiler errors" not in out
        verdict = ("INVALID" if bad else "caught") if r.returncode != 0 else "NOT CAUGHT"
        lines = [l for l in out.splitlines() if "── ✗ fail" in l or l.startswith("FAIL") or "differs" in l][:4]
    finally:
        open(p, "w").write(orig)
    assert sha(p) == before, f"{mid}: file not restored"
    return verdict, lines


if __name__ == "__main__":
    part = sys.argv[1]
    ids = sys.argv[2:] or [k for k, v in M.items() if v[0] == part]
    for mid in ids:
        verdict, lines = run(mid)
        print(f"{mid}: {verdict}  {' | '.join(lines)}", flush=True)
