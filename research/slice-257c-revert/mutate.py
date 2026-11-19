#!/usr/bin/env python3
# Revert checks (TW12) of slice 257c: the most tricky behaviors only. The private reference (reference/ and the wiring patches below) is put in a MIRROR copy of the worker
# (.tmp/257c-mirror/), never in the repo files (another agent works in this checkout). Each mutant is one change of the mirror; the W0 tests (worker/tests/unit/w0.roc of the mirror,
# with the real test files) or the W2 cases `logafter/` (the runner of the repo, with the wasm of the mirror) must fail. `base` is the reference with no change: it must pass.
# Run from the repo root, in a capped scope:
#   flock .tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 3000 python3 research/slice-257c-revert/mutate.py [base M1 M2 ...]
# Limits: `roc test` 150 s, the wasm build 300 s, the W2 run 240 s.
import os, re, shutil, subprocess, sys
R = "research/slice-257c-revert/"
ROOT = os.getcwd()
MIR = os.path.join(ROOT, ".tmp", "257c-mirror")
TMP = os.path.join(ROOT, ".tmp")
env = dict(os.environ, TMPDIR=os.path.join(TMP, "tmp"), W2_TMP=os.path.join(TMP, "tmp"))
tag = os.environ.get("ROC_TAG_WORKER", "nightly-2026-11-06-34f137a")
roc = os.path.join(ROOT, f"cloudflare-workers/.cache/nightlies/{tag}/roc")
build = os.path.join(TMP, "257c-mutant")
TRIG, WRITER, MAIN, QUEUE, RECON = "worker/lib/LogTrigger.roc", "worker/LogWriter.roc", "worker/main.roc", "worker/IndexQueue.roc", "worker/ReconcileCron.roc"
POST_STUB = """	PostRelease => match req.header("authorization") {
		Ok(_) => PublishRoutes.post!(req)
		Err(NotFound) => IngestRoutes.post!(req)
	}
"""
POST_REF = """	PostRelease => LogWriter.with_step(
		match req.header("authorization") {
			Ok(_) => PublishRoutes.post!(req)
			Err(NotFound) => IngestRoutes.post!(req)
		},
	)
"""
TC_STUB = "		Ok(_) => ToolchainRoutes.put!(req, tag)\n"
TC_REF = "		Ok(_) => LogWriter.with_step(ToolchainRoutes.put!(req, tag))\n"
Q_IMP_STUB = "import IngestRoutes\n"
Q_IMP_REF = "import IngestRoutes\nimport LogWriter\nimport lib.LogTrigger\n"
Q_STUB = """				match IngestRoutes.index!(session, target, flow) {
					Ok(_) => match old {
						Err(None) => Ok(Added({ repo: repo_id, now }))
						Ok(_) => Ok(Nothing)
					}
"""
Q_REF = """				match IngestRoutes.index!(session, target, flow) {
					Ok(res) => {
						if LogTrigger.wrote_leaf(res.status()) {
							LogWriter.once!()
						}
						match old {
							Err(None) => Ok(Added({ repo: repo_id, now }))
							Ok(_) => Ok(Nothing)
						}
					}
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
ONCE_REF = """	once! = || {
		match step!() {"""
# M7 (run 2): the same step and log line, then MORE steps while LogStep.again (the loop of the cron). Run 1 had a wrong mutant (one step too many each time).
ONCE_LOOP = """	once! = || {
		var $first = step!()
		while match $first {
			Ok(x) => LogStep.again(x)
			Err(_) => Bool.False
		} {
			$first = step!()
		}
		match $first {"""
# (id, label, file, old, new, layers)
M = [
    ("M1", "the step runs BEFORE the answer (in the request, not in Response.after): ingest and publish", MAIN, POST_REF, STEP_BEFORE, "w2"),
    ("M2", "a step also after a 200 (each 2xx answer: an idempotent repeat, a provenance write)", TRIG, "status == 201", "status >= 200 and status < 300", "w0 w2"),
    ("M3", "a step also after a refusal (4xx)", TRIG, "status == 201", "status == 201 or (status >= 400 and status < 500)", "w0 w2"),
    ("M4", "the work after the answer gives Err (the platform writes `after respond: failed`)", WRITER, "				once!()\n				Ok({})\n", "				once!()\n				Err(\"step\")\n", "w2"),
    ("M5", "the index queue job path is forgotten (no step after a job that adds a leaf)", QUEUE, "						if LogTrigger.wrote_leaf(res.status()) {\n							LogWriter.once!()\n						}\n", "", "w2"),
    ("M6", "the PUT /v1/toolchains path is forgotten", MAIN, TC_REF, TC_STUB, "w2"),
    ("M7", "the step after an answer loops (as the cron) while a step took exactly the cap", WRITER, ONCE_REF, ONCE_LOOP, "w2"),
    ("M8", "the queue job runs the step for a provenance write with no leaf (AddProvenance)", QUEUE, "				_ = session.batch!([stmt]).map_err(fault)?\n", "				_ = session.batch!([stmt]).map_err(fault)?\n				LogWriter.once!()\n", "w2"),
    ("M9", "the reconcile run makes a step at its end (Q257-24 option b)", RECON, "	run! = |_s| {\n", "	run! = |_s| {\n		LogWriter.once!()\n", "w2"),
    ("M10", "a failed step after an answer is a 500 (the answer waits for the step)", MAIN, TC_REF, "		Ok(_) => match ToolchainRoutes.put!(req, tag) {\n			Ok(res) if res.status() == 201 => match LogWriter.step!() {\n				Ok(_) => Ok(res)\n				Err(Fault(t)) => Err(Fault(t))\n			}\n			other => other\n		}\n", "w2"),
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
def reference():
    put(TRIG, open(R + "reference/LogTrigger.roc").read())
    put(WRITER, open(R + "reference/LogWriter.roc").read())
    swap(MAIN, POST_STUB, POST_REF)
    swap(MAIN, TC_STUB, TC_REF)
    swap(QUEUE, Q_IMP_STUB, Q_IMP_REF)
    swap(QUEUE, Q_STUB, Q_REF)
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
    rc, out = sh(["node", "worker/tests/run.mjs", "logafter/"], 240)
    fails = [l.split()[1] for l in out.splitlines() if l.startswith("FAIL ")]
    if os.environ.get("SHOW"):
        print(out[-6000:])
    warn = " (build warning)" if rc != 0 and "warning" in out.lower() else ""
    return ("TIMEOUT" if rc == 124 else "CAUGHT" if fails else "not caught" if rc == 0 else "RUN-ERROR " + out[-300:].replace("\n", " ")) + f" {fails}"
env["W2_DIR"] = build
want = set(sys.argv[1:])
try:
    todo = [("base", "the reference with no change (every new test must pass)", None, "", "", "w0 w2")] + M
    for mid, label, f, old, new, layers in todo:
        if want and mid not in want:
            continue
        mirror()
        reference()
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
