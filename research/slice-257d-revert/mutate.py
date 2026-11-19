#!/usr/bin/env python3
# Revert checks (TW12) of slice 257d: the most tricky behaviors only. The private reference (reference/) is put in a MIRROR copy of the worker (.tmp/257d-mirror/), never in the repo files
# (another agent works in this checkout). Each mutant is one change of the mirror; the W0 tests (worker/tests/unit/w0.roc of the mirror, which has the real test files) or the W2 cases `logread/`
# (the runner of the repo, with the wasm of the mirror) must fail. `base` is the reference with no change: it must pass (each new test can pass).
# Run from the repo root, in a capped scope:
#   flock .tmp/heavy.lock systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 timeout 3000 python3 research/slice-257d-revert/mutate.py [base M1 M2 ...]
# Limits: `roc test` 150 s, the wasm build 300 s, the W2 run 180 s.
import os, re, shutil, subprocess, sys
R = "research/slice-257d-revert/"
ROOT = os.getcwd()
MIR = os.path.join(ROOT, ".tmp", "257d-mirror")
TMP = os.path.join(ROOT, ".tmp")
env = dict(os.environ, TMPDIR=os.path.join(TMP, "tmp"), W2_TMP=os.path.join(TMP, "tmp"))
tag = os.environ.get("ROC_TAG_WORKER", "nightly-2026-11-06-34f137a")
roc = os.path.join(ROOT, f"cloudflare-workers/.cache/nightlies/{tag}/roc")
build = os.path.join(TMP, "257d-mutant")
PATH, ROUTES = "worker/lib/LogPath.roc", "worker/LogRoutes.roc"
ROUTE, CLIENT = "worker/lib/Route.roc", "worker/lib/Client.roc"
ref_path = open(R + "reference/LogPath.roc").read()
ref_routes = open(R + "reference/LogRoutes.roc").read()
DECIDE_STUB = "	decide_log = |_input, _path, _rest| crash \"todo\"\n"
DECIDE_REF = """	decide_log = |input, path, rest| match LogPath.parse(rest) {
		Err(BadPath) => Refuse(Problem.new(NotFound, "no route for ${input.method} ${path}"))
		Ok(target) => match input.method {
			"GET" | "HEAD" => Handle(match target {
				Checkpoint => GetLogCheckpoint
				Tile(_) => GetLogTile(LogPath.key(target))
			})
			_ => NotAllowed(Problem.new(MethodNotAllowed, "${input.method} is not allowed on ${path}"), ["GET", "HEAD"])
		}
	}
"""
CHECKED_STUB = "	is_checked = |_id| Bool.True\n"
CHECKED_REF = "	is_checked = |id| match id {\n		GetLogCheckpoint | GetLogTile(_) => Bool.False\n		_ => Bool.True\n	}\n"
# (id, label, file, old, new, layers)
M = [
    ("M1", "the checkpoint goes in the Cache API (an old checkpoint is served from the colo)", PATH, "		Checkpoint => Bool.False\n		Tile(_) => Bool.True", "		Checkpoint => Bool.True\n		Tile(_) => Bool.True", "w0 w2"),
    ("M2", "MIN_TLN is applied to the log routes (the client check)", CLIENT, "		GetLogCheckpoint | GetLogTile(_) => Bool.False\n", "		GetLogCheckpoint | GetLogTile(_) => Bool.True\n", "w0 w2"),
    ("M3", "HEAD is not served (405)", ROUTE, '"GET" | "HEAD" => Handle(match target {', '"GET" => Handle(match target {', "w0 w2"),
    ("M4", "a partial width of 256 is accepted (off by one at the top)", PATH, "if width >= 1 and width <= 255 {", "if width >= 1 and width <= 256 {", "w0 w2"),
    ("M5", "the x prefix is optional on each group (also accepted on the last group)", PATH, "digits = if has_x { if text.starts_with(\"x\") text.drop_prefix(\"x\") else return Err(BadPath) } else text", "digits = if text.starts_with(\"x\") text.drop_prefix(\"x\") else text", "w0 w2"),
    ("M6", "304 for any If-None-Match (no ETag compare)", ROUTES, "		Ok(text) => Reads.etag_matches(text, etag)", "		Ok(_) => Bool.True", "w2"),
    ("M8", "a tile is not kept in the Cache API", PATH, "		Checkpoint => Bool.False\n		Tile(_) => Bool.True", "		Checkpoint => Bool.False\n		Tile(_) => Bool.False", "w0 w2"),
    ("M9", "a first group x000 (a leading zero group) is accepted", PATH, "if n > 1 and vals.first() == Ok(0) {", "if Bool.False {", "w0 w2"),
    ("M10", "the method is checked before the path (a bad path with POST is 405)", ROUTE, "decide_log = |input, path, rest| match LogPath.parse(rest) {\n		Err(BadPath) => Refuse(Problem.new(NotFound, \"no route for ${input.method} ${path}\"))\n		Ok(target) => match input.method {",
     "decide_log = |input, path, rest| match LogPath.parse(rest) {\n		Err(BadPath) if input.method == \"GET\" or input.method == \"HEAD\" => Refuse(Problem.new(NotFound, \"no route for ${input.method} ${path}\"))\n		Err(BadPath) => NotAllowed(Problem.new(MethodNotAllowed, \"${input.method} is not allowed on ${path}\"), [\"GET\", \"HEAD\"])\n		Ok(target) => match input.method {", "w0 w2"),
    ("M13", "an R2 read error is answered as 404 (not 500)", ROUTES, "Err(Infra(e)) => return Err(Fault(Str.inspect(e)))", "Err(Infra(_)) => return Err(Refuse(Problem.new(NotFound, \"x\")))", "w2"),
    ("M12", "the 304 has no cache-control", ROUTES, "Response.from_status(304).with_header(\"etag\", etag).with_header(\"cache-control\", cc)", "Response.from_status(304).with_header(\"etag\", etag)", "w2"),
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
def reference():
    put(PATH, ref_path)
    put(ROUTES, ref_routes)
    r = get(ROUTE)
    assert DECIDE_STUB in r
    put(ROUTE, r.replace(DECIDE_STUB, DECIDE_REF))
    c = get(CLIENT)
    assert CHECKED_STUB in c
    put(CLIENT, c.replace(CHECKED_STUB, CHECKED_REF))
def w0():
    rc, out = sh([roc, "test", "worker/tests/unit/w0.roc", "--no-cache"], 150, cwd=MIR)
    comp = "Compilation failed" in out or re.search(r"\b[1-9]\d* errors?\b", out)
    failed = re.findall(r"(\d+) failed", out)
    if os.environ.get("SHOW"):
        print(out[-3000:])
    return ("TIMEOUT" if rc == 124 else "COMPILE-ERROR " + out[-400:].replace("\n", " ") if comp else "CAUGHT" if rc else "not caught") + f" {failed}"
def w2():
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    rc, out = sh([roc, "build", "--target=wasm32", "--no-cache", "--opt=speed", f"--output={build}/app.wasm", "main.roc"], 300, cwd=os.path.join(MIR, "worker"))
    if rc == 124 or not os.path.exists(f"{build}/app.wasm") or "successfully building" not in out and rc != 0:
        return "TIMEOUT(build)" if rc == 124 else "COMPILE-ERROR " + out[-400:].replace("\n", " ")
    h = re.search(r"roc-cloudflare-workers/releases/download/[^/]*/([A-Za-z0-9]*)\.tar\.zst", open("worker/main.roc").read()).group(1)
    shutil.copytree(os.path.expanduser(f"~/.cache/roc/packages/{h}/js"), f"{build}/.roc-cfw")
    rc, out = sh(["node", "worker/tests/run.mjs", "logread/"], 180)
    fails = [l.split()[1] for l in out.splitlines() if l.startswith("FAIL ")]
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
        res = []
        if "w0" in layers:
            res.append("w0: " + w0())
        if "w2" in layers:
            res.append("w2: " + w2())
        print(f"{mid} {label} | " + " | ".join(res), flush=True)
finally:
    shutil.rmtree(build, ignore_errors=True)
    shutil.rmtree(MIR, ignore_errors=True)
