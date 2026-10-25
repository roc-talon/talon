#!/usr/bin/env python3
"""Code agent mutations of slice 057b: python3 agent-mutate-b.py <part> [id ...].
Each mutation is one exact replace in a live file. The script runs the filtered test, then puts the original text back and checks the sha256.
Layers: l0 = `roc test` of tests/unit/l0-7.roc, l2 = tests/commands/run.sh <filter>, l3 = tests/run.sh <filter>.
A mutation is INVALID when the output has a compiler error or a warning (not a test failure)."""
import hashlib, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
ROC = os.environ.get("ROC") or os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
L0 = [ROC, "test", "tests/unit/l0-7.roc"]

L2 = ["tests/commands/run.sh", "run/rn1", "run/rn2"]
# id: (part, file, old, new, command)
M = {
    "b1-walk-no-stop": ("b", "cli/lib/RunFind.roc",
        "\t\t\t\t\t\t\t_ => Err(Stop(not_found(facts, checked)))",
        "\t\t\t\t\t\t\t_ => search(facts, stop, above, checked)", L0),
    "b2-nc4-no-probe": ("b", "cli/lib/RunFind.roc",
        "\tif !asked.is_empty() {\n\t\tErr(Need(asked))",
        "\tif asked.len() > 100 {\n\t\tErr(Need(asked))", L0),
    "b3-record-not-made": ("b", "cli/lib/RunFlow.roc",
        "\tKnown.record!(fx, { roots, files: record_files!(fx, scan, found), now })?\n",
        "\t_ = Known.record_recent!\n", L2),
    "b4-standalone-record-talon": ("b", "cli/lib/RunFlow.roc",
        "[Text.join(found.dir, if has_main \"main.roc\" else \"talon.toml\")]",
        "[Text.join(found.dir, if has_main and found.dir.is_empty() \"main.roc\" else \"talon.toml\")]", L2),
    "b5-list-first-file": ("b", "cli/lib/RunFind.roc",
        "Err(None) => !file.names.is_empty()",
        "Err(None) => file.names.len() >= 0", L0),
    "b6-roc-args-lost": ("b", "cli/lib/RunFlow.roc",
        "Ok(Roc(rest)) => Ok(Proxy.run!({ ..inner, args!: || rest, program_name!: || \"roc\" }))",
        "Ok(Roc(_)) => Ok(Proxy.run!({ ..inner, args!: || [], program_name!: || \"roc\" }))", L2),
    "b7-no-stop-at-first-failure": ("b", "cli/lib/RunFlow.roc",
        "if done != 0 return Ok(done)", "if done > 200 return Ok(done)", L2),
    "b8-member-tools-own": ("b", "cli/lib/RunFind.roc",
        "Member(node) => { dir, kind: Member, tools_dir: stop, members: node, stop }",
        "Member(node) => { dir, kind: Member, tools_dir: dir, members: node, stop }", L0),
    "b9-dashdash-no-name-ok": ("b", "cli/lib/RunCmd.roc",
        "[] => if args.passthrough.is_empty() {",
        "[] => if args.passthrough.is_empty() or args.operands.is_empty() {", L2),
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
