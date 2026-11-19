#!/usr/bin/env python3
# Revert checks (TW12) of slice 257b: the most tricky behaviors only. Each mutant is one change of the private reference
# (reference/LogStep.roc, reference/LogWriter.roc); the W0 tests (worker/tests/unit/w0.roc) or the W2 cases of the step (worker/tests/cases/log/) must fail.
# Run from the repo root, in a capped scope:
#   flock .tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 1800 python3 research/slice-257b-revert/mutate.py [M1 M2 ...]
# Limits: `roc test` 120 s, the wasm build 300 s, the W2 run 180 s. The stub files (stub-*.roc) are put back at the end.
# A W2 mutant builds its own app.wasm into .tmp/257b-mutant/ (the stamp builds of scripts/test.sh are not touched) and runs only the cases `log/`.
import os, re, shutil, subprocess, sys
R = "research/slice-257b-revert/"
STEP, WRITER = "worker/lib/LogStep.roc", "worker/LogWriter.roc"
ref = {STEP: open(R + "reference/LogStep.roc").read(), WRITER: open(R + "reference/LogWriter.roc").read()}
stub = {STEP: open(R + "stub-LogStep.roc").read(), WRITER: open(R + "stub-LogWriter.roc").read()}
# (id, label, file, old, new, layers): layers is "w0", "w2" or "w0 w2".
M = [
    ("M1", "the checkpoint put has no condition (a plain put, the revert of R-SG7)", WRITER, "{ only_if: old.cond, http:", "{ http:", "w2"),
    ("M2", "the checkpoint is written before the tiles (see m2 below)", WRITER, "", "", "w2"),
    ("M3", "the old hashes come from D1 (leaves from idx 1), not from the partial tiles of S in R2", WRITER,
     "(size.to_i64_wrap(), LogStep.cap.to_i64_wrap()))\n\t\tgot = rows.map_err(|e| Fault(Str.inspect(e)))?\n\t\tentries = LogStep.entries(size, got).map_err(|e| Fault(Str.inspect(e)))?\n\t\tif entries.is_empty() {\n\t\t\treturn Ok(Same(size))\n\t\t}\n\t\tgrown = Tlog.grow(size, $edge, entries).map_err(|e| Fault(Str.inspect(e)))?\n\t\tif size > 0 and grown.old_root != old.root {",
     "(0.I64, LogStep.cap.to_i64_wrap()))\n\t\tgot = rows.map_err(|e| Fault(Str.inspect(e)))?\n\t\tall = LogStep.entries(0, got).map_err(|e| Fault(Str.inspect(e)))?\n\t\tentries = all.drop_first(size)\n\t\tif entries.is_empty() {\n\t\t\treturn Ok(Same(size))\n\t\t}\n\t\tfull = Tlog.grow(0, [], all).map_err(|e| Fault(Str.inspect(e)))?\n\t\tgrown = { ..full, tiles: full.tiles.keep_if(|tb| Tlog.growth(size, size + entries.len()).contains(tb.tile)) }\n\t\tif Bool.False {",
     "w2"),
    ("M4", "the D1 read takes the leaves from S (idx >= S), not S + 1", WRITER, "WHERE idx > ? ORDER BY idx", "WHERE idx >= ? ORDER BY idx", "w2"),
    ("M5", "the cap is off by one (a step takes 65,537 leaves)", STEP, "if rows.len() > LogStep.cap {", "if rows.len() > LogStep.cap + 1 {", "w0"),
    ("M6", "the cron stops after a step of exactly the cap", STEP, "Wrote(w) => w.size - w.from >= LogStep.cap", "Wrote(w) => w.size - w.from > LogStep.cap", "w0"),
    ("M7", "the key id of LOG_KEY is not checked against the key", STEP, "if Tlog.key_id(key.name, public) == key.key_id {", "if Bool.True {", "w0 w2"),
    ("M8", "a failed tile put is ignored (the checkpoint is written)", WRITER, "if puts.any(|p| p.is_err()) {", "if Bool.False {", "w2"),
    ("M9", "the root of the tiles of S is not checked against the checkpoint of S", WRITER, "if size > 0 and grown.old_root != old.root {", "if Bool.False {", "w2"),
    ("M10", "after a lost compare and swap, the step writes its checkpoint with no condition", WRITER,
     "\t\t\t\tif LogStep.stop_after_race(again.size, new_size) {\n\t\t\t\t\tOk(Lost({ size: new_size, theirs: again.size }))",
     "\t\t\t\tif LogStep.stop_after_race(again.size, new_size) {\n\t\t\t\t\t_ = R2.put_with!(log, LogStep.checkpoint_key, Body.Text(note), { http: { content_type: LogStep.content_type(LogStep.checkpoint_key) } })\n\t\t\t\t\tOk(Lost({ size: new_size, theirs: again.size }))",
     "w2"),
]
# M2: move the checkpoint put before the tile puts. Written as a function of the reference text (a swap of two blocks).
def m2(text):
    a = "\t\tputs = Io.all!("
    b = "\t\tif puts.any(|p| p.is_err()) {"
    i, j = text.index(a), text.index(b)
    tile_block = text[i:j]
    k = text.index("\t\tmatch R2.put_with!(log, LogStep.checkpoint_key")
    pre = text[:i] + text[j:k]
    ck = ("\t\tck = R2.put_with!(log, LogStep.checkpoint_key, Body.Text(note), { only_if: old.cond, http: { content_type: LogStep.content_type(LogStep.checkpoint_key) } })\n" + tile_block +
          "\t\tmatch ck {\n")
    rest = text[k:]
    rest = rest[rest.index("\n") + 1:]
    # the tile check must not stop the run before the match: keep it after the puts
    out = pre.replace(b, "\t\tif Bool.False {", 1) + ck + rest
    return out
ROOT = os.getcwd()
TMP = os.path.join(ROOT, ".tmp")
env = dict(os.environ, TMPDIR=os.path.join(TMP, "tmp"), W2_TMP=os.path.join(TMP, "tmp"))
tag = os.environ.get("ROC_TAG_WORKER", "nightly-2026-11-06-34f137a")
roc = os.path.join(ROOT, f"cloudflare-workers/.cache/nightlies/{tag}/roc")
build = os.path.join(TMP, "257b-mutant")
def sh(cmd, limit, cwd=ROOT):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=limit, env=env, cwd=cwd)
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return 124, "timeout"
def w0():
    rc, out = sh([roc, "test", "worker/tests/unit/w0.roc", "--no-cache"], 120)
    comp = "Compilation failed" in out or re.search(r"\b[1-9]\d* errors?\b", out)
    return ("TIMEOUT" if rc == 124 else "COMPILE-ERROR" if comp else "CAUGHT" if rc else "not caught") + f" {re.findall(r'(\d+) failed', out)}"
def w2():
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    rc, out = sh([roc, "build", "--target=wasm32", "--no-cache", "--opt=speed", f"--output={build}/app.wasm", "main.roc"], 300, cwd=os.path.join(ROOT, "worker"))
    # A warning (for example "unconditional condition" of a mutant) gives a non-zero exit with a good wasm: only a missing wasm is a compile error.
    if rc == 124 or not os.path.exists(f"{build}/app.wasm") or "successfully building" not in out and rc != 0:
        return "TIMEOUT(build)" if rc == 124 else "COMPILE-ERROR " + out[-300:].replace("\n", " ")
    h = re.search(r"roc-cloudflare-workers/releases/download/[^/]*/([A-Za-z0-9]*)\.tar\.zst", open("worker/main.roc").read()).group(1)
    shutil.copytree(os.path.expanduser(f"~/.cache/roc/packages/{h}/js"), f"{build}/.roc-cfw")
    rc, out = sh(["node", "worker/tests/run.mjs", "log/"], 180)
    fails = [l.split()[1] for l in out.splitlines() if l.startswith("FAIL ")]
    return ("TIMEOUT" if rc == 124 else "CAUGHT" if fails else "not caught") + f" {fails}"
env["W2_DIR"] = build
want = set(sys.argv[1:])
try:
    for mid, label, f, old, new, layers in M:
        if want and mid not in want:
            continue
        for k, v in ref.items():
            open(k, "w").write(v)
        if mid == "M2":
            open(f, "w").write(m2(ref[f]))
        else:
            if ref[f].count(old) != 1:
                print(f"{mid} {label} | SKIP (no unique match)", flush=True)
                continue
            open(f, "w").write(ref[f].replace(old, new))
        res = []
        if "w0" in layers:
            res.append("w0: " + w0())
        if "w2" in layers:
            res.append("w2: " + w2())
        print(f"{mid} {label} | " + " | ".join(res), flush=True)
finally:
    for k, v in stub.items():
        open(k, "w").write(v)
    shutil.rmtree(build, ignore_errors=True)
