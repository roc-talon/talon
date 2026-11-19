#!/usr/bin/env python3
# Slice 257b verify: the revert check on the REAL code (worker/lib/LogStep.roc, worker/LogWriter.roc of the code agent), as literal changes of a MIRROR copy.
# The repo files are never changed (another agent works in this checkout): the mirror is .tmp/slice-257b-mut-real/<name>/ (worker/ without the wasm and the cases, and packages/records).
# W0: `roc test <mirror>/worker/tests/unit/w0.roc`. W2: build <mirror>/worker/main.roc to <mirror>/out/app.wasm, then the repo runner `worker/tests/run.mjs log/` with W2_DIR=<mirror>/out
# (the cases are read from the repo, read only). One mutant at a time. Run each step in the capped scope, under the shared lock:
#   flock .tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 3000 python3 research/slice-257b-revert/mutate-real.py [names]
# Limits: roc test 120 s, build 300 s, W2 run 180 s. Names: base-w0 base-w2 M1 .. M12. No name: all.
import hashlib, os, re, shutil, subprocess, sys
ROOT = "/home/george/dev/Karakatiza666/talon"
MIR = os.path.join(ROOT, ".tmp/slice-257b-mut-real")
TAG = os.environ.get("ROC_TAG_WORKER", "nightly-2026-11-06-34f137a")
ROC = os.path.join(ROOT, f"cloudflare-workers/.cache/nightlies/{TAG}/roc")
env = dict(os.environ, TMPDIR=os.path.join(ROOT, ".tmp/tmp"), W2_TMP=os.path.join(ROOT, ".tmp/tmp"))
S, W = "lib/LogStep.roc", "LogWriter.roc"
REAL = [os.path.join(ROOT, "worker", S), os.path.join(ROOT, "worker", W)]
def sha():
    return [hashlib.sha256(open(p, "rb").read()).hexdigest() for p in REAL]
def mirror(d):
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(os.path.join(d, "packages"))
    shutil.copytree(os.path.join(ROOT, "worker"), os.path.join(d, "worker"), ignore=shutil.ignore_patterns("app.wasm", ".roc-cfw", "cases", "selftest", ".wrangler", "*.wasm"))
    shutil.copytree(os.path.join(ROOT, "packages/records"), os.path.join(d, "packages/records"))
def sh(cmd, limit, cwd=ROOT):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=limit, env=env, cwd=cwd)
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return 124, "timeout"
def w0(d):
    rc, out = sh([ROC, "test", os.path.join(d, "worker/tests/unit/w0.roc"), "--no-cache"], 120)
    if rc == 124:
        return "TIMEOUT"
    if re.search(r"\b[1-9]\d* compiler errors?\b", out) or "Compilation failed" in out:
        return "COMPILE-ERROR"
    m = re.findall(r"(\d+) failed", out)
    # The w0 driver is shared: other slices can have red tests in it (257d). Only the failures in LogStepTest.roc count for a mutant of this slice.
    own = len(re.findall(r"fail \u2500+ [^\n]*LogStepTest\.roc", out))
    return ("CAUGHT" if own else "not caught") + f" (LogStepTest failed {own}; all failed {m[0] if m else 0}; {' '.join(re.findall(r'All \(\d+\) tests passed', out))})"
def w2(d, filt):
    out_dir = os.path.join(d, "out")
    os.makedirs(out_dir, exist_ok=True)
    rc, out = sh([ROC, "build", "--target=wasm32", "--no-cache", "--opt=speed", f"--output={out_dir}/app.wasm", "main.roc"], 300, cwd=os.path.join(d, "worker"))
    if rc == 124 or not os.path.exists(f"{out_dir}/app.wasm"):
        return "TIMEOUT(build)" if rc == 124 else "BUILD FAILED " + out[-300:].replace("\n", " ")
    h = re.search(r"roc-cloudflare-workers/releases/download/[^/]*/([A-Za-z0-9]*)\.tar\.zst", open(os.path.join(ROOT, "worker/main.roc")).read()).group(1)
    shutil.copytree(os.path.expanduser(f"~/.cache/roc/packages/{h}/js"), f"{out_dir}/.roc-cfw")
    rc, out = sh(["node", "worker/tests/run.mjs", *filt.split()], 180)
    fails = [l.split()[1] for l in out.splitlines() if l.startswith("FAIL ")]
    tail = [l for l in out.splitlines() if l.startswith("w2: ")]
    return ("TIMEOUT" if rc == 124 else "CAUGHT" if fails else "not caught") + f" {fails} {tail}"
env_w2 = lambda d: env.update(W2_DIR=os.path.join(d, "out"))
# (name, label, layers, [(file, old, new), ...])
M = [
    ("M1", "the checkpoint put has no condition (a plain put)", "w2", [(W, "{ only_if: cur.cond, http:", "{ http:")]),
    ("M2", "the checkpoint is written before the tiles", "w2", "M2"),
    ("M3", "the old hashes come from D1 (leaves from idx 1), not from the partial tiles of S", "w2", [
        (W, "LIMIT ?2\", (old, LogStep.cap))", "LIMIT ?2\", (0.U64, LogStep.cap))"),
        (W, "\t\tentries = match LogStep.entries(old, rows) {\n\t\t\tOk(list) => list\n", "\t\tentries = match LogStep.entries(0, rows) {\n\t\t\tOk(list) => list.drop_first(old)\n"),
        (W, "\t\tgrown = Tlog.grow(old, edges, entries)", "\t\tfull = Tlog.grow(0, [], LogStep.entries(0, rows) ?? []).map_err(|e| Fault(Str.inspect(e)))?\n\t\tgrown = { ..full, tiles: full.tiles.keep_if(|tb| Tlog.growth(old, size).contains(tb.tile)) }\n\t\t_unused = Tlog.grow(old, edges, entries)"),
        (W, "if old > 0 and grown.old_root != cur.root {", "if Bool.False {")]),
    ("M4", "the D1 read takes the leaves from S (idx >= S)", "w2", [(W, "WHERE idx > ?1", "WHERE idx >= ?1")]),
    ("M5", "the cap is off by one (65,537 rows are one step)", "w0", [(S, "if rows.len() > cap {", "if rows.len() > cap + 1 {")]),
    ("M6", "the cron stops after a step of exactly the cap", "w0", [(S, "Wrote(w) => w.size - w.from >= cap", "Wrote(w) => w.size - w.from > cap")]),
    ("M7", "the key id of LOG_KEY is not checked against the key", "w0 w2", [(S, "if Tlog.key_id(key.name, public) == key.key_id {", "if Bool.True {")]),
    ("M8", "a failed tile put is ignored (the checkpoint is written)", "w2", [(W, "Err(e) => return Err(Fault(\"a tile put failed: ${Str.inspect(e)}\"))", "Err(_) => {}")]),
    ("M9", "the root of the tiles of S is not checked against the checkpoint of S", "w2", [(W, "if old > 0 and grown.old_root != cur.root {", "if Bool.False {")]),
    ("M10", "after a lost compare and swap, the step writes its checkpoint with no condition", "w2", [(W, "\t\t\t\t\tOk(Lost({ size, theirs: again.size }))",
        "\t\t\t\t\t_ = R2.put_with!(log, LogStep.checkpoint_key, Text(note), { http: { content_type: LogStep.content_type(LogStep.checkpoint_key) } })\n\t\t\t\t\tOk(Lost({ size, theirs: again.size }))")]),
    ("M11", "Q257-18: a smaller checkpoint after a lost race stops at once (no one more step)", "w2", [(W, "if LogStep.stop_after_race(again.size, size) or retried {", "if Bool.True {")]),
    ("M12", "Q257-18: the step goes on after the one more step (no stop)", "w2", [(W, "if LogStep.stop_after_race(again.size, size) or retried {", "if LogStep.stop_after_race(again.size, size) {")]),
]
def m2(text):
    a = text.index("\t\tputs = Io.all!(")
    b = text.index("\t\tbody = Tlog.checkpoint_body(")
    c = text.index("\t\tmatch written {")
    return text[:a] + text[b:c] + text[a:b] + text[c:]
want = set(sys.argv[1:])
pick = lambda n: not want or n in want
before = sha()
print(f"sha256 before: LogStep {before[0]} LogWriter {before[1]}", flush=True)
try:
    for base, layer in (("base-w0", "w0"), ("base-w2", "w2")):
        if pick(base):
            d = os.path.join(MIR, base)
            mirror(d)
            env_w2(d)
            print(f"{base}: " + (w0(d) if layer == "w0" else w2(d, "log/ runner/r-sg7 selftest/wrong-r2")), flush=True)
            shutil.rmtree(d, ignore_errors=True)
    for name, label, layers, changes in M:
        if not pick(name):
            continue
        d = os.path.join(MIR, name)
        mirror(d)
        env_w2(d)
        ok = True
        if changes == "M2":
            p = os.path.join(d, "worker", W)
            t = m2(open(p).read())  # read first: open(p, "w") truncates the file
            open(p, "w").write(t)
        else:
            for f, old, new in changes:
                p = os.path.join(d, "worker", f)
                t = open(p).read()
                if t.count(old) != 1:
                    print(f"{name} {label} | DID NOT APPLY: {old[:60]!r}", flush=True)
                    ok = False
                    break
                open(p, "w").write(t.replace(old, new))
        if ok:
            res = []
            if "w0" in layers:
                res.append("w0: " + w0(d))
            if "w2" in layers:
                res.append("w2: " + w2(d, "log/"))
            print(f"{name} {label} | " + " | ".join(res), flush=True)
        shutil.rmtree(d, ignore_errors=True)
finally:
    after = sha()
    print(f"sha256 after:  LogStep {after[0]} LogWriter {after[1]} ({'same' if after == before else 'CHANGED'})", flush=True)
