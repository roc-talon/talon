#!/usr/bin/env python3
"""Code agent mutations of slice 057 (one script for the 3 parts): python3 agent-mutate-a.py <part> [id ...].
Each mutation is one exact replace in a live file. The script runs the filtered test, then puts the original text back and checks the sha256.
Layers: l0 = `roc test` of tests/unit/l0-7.roc, l2 = tests/commands/run.sh <filter>, l3 = tests/run.sh <filter>.
A mutation is INVALID when the output has a compiler error or a warning (not a test failure)."""
import hashlib, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
ROC = os.environ.get("ROC") or os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
L0 = [ROC, "test", "tests/unit/l0-7.roc"]

# id: (part, file, old, new, command)
M = {
    "a1-quote-splits-word": ("a", "cli/lib/ScriptsToml.roc",
        "read_words(rest, { ..st, mode: Dq, begun: Bool.True, quoted: Bool.True })",
        "read_words(rest, { ..flush(st)?, mode: Dq, begun: Bool.True, quoted: Bool.True })", L0),
    "a2-unclosed-ok": ("a", "cli/lib/ScriptsToml.roc",
        "\t\t[] => Err(Unclosed)\n\t\t['\\\\', next",
        "\t\t[] => Ok(st.done.append(Str.from_utf8_lossy(st.cur)))\n\t\t['\\\\', next", L0),
    "a3-args-all-steps": ("a", "cli/lib/RunPlan.roc",
        "one_step(here, if rest.is_empty() args else [])?",
        "one_step(here, if rest.is_empty() or !args.is_empty() args else [])?", L0),
    "a4-cycle-check-off": ("a", "cli/lib/RunPlan.roc",
        "expand = |ctx, dir, name, args, stack| if stack.contains((dir, name)) {",
        "expand = |ctx, dir, name, args, stack| if stack.len() > 40 {", L0),
    "a5-roc-no-dashdash": ("a", "cli/lib/RunPlan.roc",
        "Ok(Roc([first, \"--\"].concat(rest)))", "Ok(Roc([first].concat(rest)))", L0),
    "a6-key-over-roc": ("a", "cli/lib/RunPlan.roc",
        "[first, .. as rest] => if first == \"roc\" {",
        "[first, .. as rest] => if first == \"roc\" and !facts.keys.contains(first) {", L0),
    "a7-signal-code": ("a", "cli/RealFx.roc",
        "\t\t\t\tSignaled(signal) => Ok(128 + signal)\n\t\t\t}\n\t\t\tErr(err) => Err(NotStarted(Str.inspect(err)))\n\t\t}\n\t}\n}\n",
        "\t\t\t\tSignaled(signal) => Ok(signal)\n\t\t\t}\n\t\t\tErr(err) => Err(NotStarted(Str.inspect(err)))\n\t\t}\n\t}\n}\n", ["tests/run.sh", "fx/px2"]),
}
# the exec_in! text is the last one in RealFx.roc: replace the last occurrence only
LAST = {"a7-signal-code"}


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
