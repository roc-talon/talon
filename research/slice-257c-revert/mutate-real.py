#!/usr/bin/env python3
# Slice 257c VERIFY: the revert list on the REAL code. Each mutant is one literal change of a MIRROR copy (.tmp/257c-mut-real/) of the real worker; the repo files are never changed.
# `base` is the real code with no change. W0: worker/tests/unit/w0.roc of the mirror (only LogTriggerTest failures count). W2: the runner of the repo with the wasm of the mirror, the cases
# logafter/ and the groups that the code touched (ingest/ publish/ toolchains/ webhook/ reconcile/ log/).
#   flock .tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 600 python3 research/slice-257c-revert/mutate-real.py [base M1 ...]
# Limits: roc test 150 s, wasm build 300 s, W2 run 300 s.
import os, re, shutil, subprocess, sys
ROOT = os.getcwd()
MIR = os.path.join(ROOT, ".tmp", "257c-mut-real")
TMP = os.path.join(ROOT, ".tmp")
env = dict(os.environ, TMPDIR=os.path.join(TMP, "tmp"), W2_TMP=os.path.join(TMP, "tmp"))
tag = os.environ.get("ROC_TAG_WORKER", "nightly-2026-11-06-34f137a")
roc = os.path.join(ROOT, f"cloudflare-workers/.cache/nightlies/{tag}/roc")
build = os.path.join(TMP, "257c-mut-real-build")
TRIG, WRITER, MAIN, QUEUE, RECON = "worker/lib/LogTrigger.roc", "worker/LogWriter.roc", "worker/main.roc", "worker/IndexQueue.roc", "worker/ReconcileCron.roc"
POST_REAL = """	PostRelease => LogWriter.with_step(
		match req.header("authorization") {
			Ok(_) => PublishRoutes.post!(req)
			Err(NotFound) => IngestRoutes.post!(req)
		},
	)
"""
STEP_BEFORE = """	PostRelease => {
		r = match req.header("authorization") {
			Ok(_) => PublishRoutes.post!(req)
			Err(NotFound) => IngestRoutes.post!(req)
		}
		match r {
			Ok(res) if res.status() == 201 => {
				LogWriter.once!()
				Ok(res)
			}
			_ => r
		}
	}
"""
TC_REAL = "		Ok(_) => LogWriter.with_step(ToolchainRoutes.put!(req, tag))\n"
M = [
    ("M1", "the step runs BEFORE the answer (ingest and publish)", MAIN, POST_REAL, STEP_BEFORE, "w2"),
    ("M2", "a step after each 2xx", TRIG, "status == 201", "status >= 200 and status < 300", "w0 w2"),
    ("M3", "a step after a 4xx too", TRIG, "status == 201", "status == 201 or (status >= 400 and status < 500)", "w0 w2"),
    ("M4", "the work after the answer gives Err (platform line after respond: failed)", WRITER, "\t\t\t\t\t\tonce!()\n\t\t\t\t\t\tOk({})\n", "\t\t\t\t\t\tonce!()\n\t\t\t\t\t\tErr(\"step\")\n", "w2"),
    ("M5", "the index queue job path is forgotten", QUEUE, "\t\t\t\t\t\tif LogTrigger.wrote_leaf(res.status()) {\n\t\t\t\t\t\t\tLogWriter.once!()\n\t\t\t\t\t\t}\n", "\t\t\t\t\t\t_ = LogTrigger.wrote_leaf(res.status())\n", "w2"),
    ("M6", "the PUT /v1/toolchains path is forgotten", MAIN, TC_REAL, "		Ok(_) => ToolchainRoutes.put!(req, tag)\n", "w2"),
    ("M8", "the queue job runs the step for a provenance write (no leaf)", QUEUE, "				_ = session.batch!([stmt]).map_err(fault)?\n", "				_ = session.batch!([stmt]).map_err(fault)?\n				LogWriter.once!()\n", "w2"),
    ("M9", "the reconcile run makes a step at its end", RECON, "\trun! = |_s| {\n", "\trun! = |_s| {\n\t\tLogWriter.once!()\n", "w2"),
    ("M10", "the answer waits for the step; a failed step is a 500", MAIN, TC_REAL, "		Ok(_) => match ToolchainRoutes.put!(req, tag) {\n			Ok(res) if res.status() == 201 => match LogWriter.step!() {\n				Ok(_) => Ok(res)\n				Err(Fault(t)) => Err(Fault(t))\n			}\n			other => other\n		}\n", "w2"),
]
def sh(cmd, limit, cwd=ROOT):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=limit, env=env, cwd=cwd)
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return 124, "timeout"
def mirror():
    shutil.rmtree(MIR, ignore_errors=True)
    shutil.copytree("packages/records", MIR + "/packages/records", ignore=shutil.ignore_patterns(".roc-cfw", "*.wasm"))
    shutil.copytree("worker", MIR + "/worker", ignore=shutil.ignore_patterns("cases", "selftest", ".roc-cfw", "*.wasm", "node_modules", "worker.js"))
def put(path, text):
    open(os.path.join(MIR, path), "w").write(text)
def get(path):
    return open(os.path.join(MIR, path)).read()
def swap(path, old, new):
    t = get(path)
    assert t.count(old) == 1, f"{path}: no unique match for {old[:60]!r}"
    put(path, t.replace(old, new))
def w0():
    rc, out = sh([roc, "test", "worker/tests/unit/w0.roc", "--no-cache"], 150, cwd=MIR)
    comp = "Compilation failed" in out or re.search(r"\b[1-9]\d* errors?\b", out)
    # Only the failures of LogTriggerTest count (the shared driver can have red tests of other slices).
    mine = len(re.findall(r"LogTriggerTest\.roc", out))
    if os.environ.get("SHOW"):
        print(out[-3000:])
    return ("TIMEOUT" if rc == 124 else "COMPILE-ERROR " + out[-400:].replace("\n", " ") if comp else "CAUGHT" if mine else "not caught") + f" (LogTriggerTest lines in the output: {mine})"
def w2():
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    rc, out = sh([roc, "build", "--target=wasm32", "--no-cache", "--opt=speed", f"--output={build}/app.wasm", "main.roc"], 300, cwd=os.path.join(MIR, "worker"))
    # `roc build` exits non-zero on a warning with a good wasm: a mutant can give a warning (memory: 257b run1).
    if rc == 124 or not os.path.exists(f"{build}/app.wasm"):
        return "TIMEOUT(build)" if rc == 124 else "COMPILE-ERROR " + out[-600:].replace("\n", " ")
    h = re.search(r"roc-cloudflare-workers/releases/download/[^/]*/([A-Za-z0-9]*)\.tar\.zst", open("worker/main.roc").read()).group(1)
    shutil.copytree(os.path.expanduser(f"~/.cache/roc/packages/{h}/js"), f"{build}/.roc-cfw")
    rc, out = sh(["node", "worker/tests/run.mjs", "logafter/", "ingest/", "publish/", "toolchains/", "webhook/", "reconcile/", "log/"], 300)
    fails = [l.split()[1] for l in out.splitlines() if l.startswith("FAIL ")]
    if os.environ.get("SHOW"):
        print(out[-6000:])
    warn = " (build warning)" if rc != 0 and "warning" in out.lower() else ""
    return ("TIMEOUT" if rc == 124 else "CAUGHT" if fails else "not caught" if rc == 0 else "RUN-ERROR " + out[-300:].replace("\n", " ")) + f" {fails}"
env["W2_DIR"] = build
want = set(sys.argv[1:])
try:
    todo = [("base", "the real code with no change", None, "", "", "w0 w2")] + M
    for mid, label, f, old, new, layers in todo:
        if want and mid not in want:
            continue
        mirror()
        if f is not None:
            t = get(f)
            if t.count(old) != 1:
                print(f"{mid} {label} | SKIP (no unique match)", flush=True)
                continue
            put(f, t.replace(old, new))
            if mid == "M9":
                swap(RECON, "import IngestRoutes\n", "import IngestRoutes\nimport LogWriter\n")
        res = []
        if "w0" in layers:
            res.append("w0: " + w0())
        if "w2" in layers:
            res.append("w2: " + w2())
        print(f"{mid} {label} | " + " | ".join(res), flush=True)
finally:
    shutil.rmtree(build, ignore_errors=True)
    shutil.rmtree(MIR, ignore_errors=True)
