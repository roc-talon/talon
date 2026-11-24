#!/usr/bin/env python3
# Slice 261c (test agent): writes the expected files of tests/commands/cases/logproof/* and of the 3 old default-registry cases by hand rules, from the
# output of the code BEFORE 261c (the work dirs of a run of tests/commands/run.sh on these cases, which fails) and the proposal of the check
# (docs/slices/261-log-inclusion-proofs.md section 14.3): each inserted Fx call, text and file is written below. No output of the new code is used.
# Usage (repo root, after a run of the cases): python3 research/slice-261c-tests/mk-expect.py <work root, e.g. .tmp/tmp/talon-l2>
import json, os, shutil, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mkexpectlib import Log, copies_of, post_end, put, read, runs_of  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tests/commands/cases")
WROOT = os.path.abspath(sys.argv[1])
SCRATCH = os.path.join(ROOT, ".tmp/s261c-expect")
UA = "  User-Agent: tln/0.0.1"
FORM = "(the form is <name>+<8 hex digits>+<base64 key>)"


def fresh(log, tiles, sleeps=()):
    """A check with no kept checkpoint and no copy: read, tiles, write (R-LV6, R-LV7, R-IX8)."""
    return log.read_kept() + log.get_checkpoint(sleeps) + log.read_copies(tiles) + log.fetch(tiles) + log.write(tiles)


def json_error(command, kind, code, message, details):
    return json.dumps({"schema": 1, "command": command, "ok": False, "data": None,
                       "error": {"kind": kind, "code": code, "message": message, "details": details}}, separators=(",", ":"), ensure_ascii=False)


def details(log, reason, size, index, release):
    return {"log": f"{log.base}/log", "reason": reason, "size": size, "index": index, "release": release}


def stdout_runs(text):
    """The stdout of each run: (the `== <line>` line, the output lines, the `exit <n>` line)."""
    out = []
    for l in text.split("\n")[:-1]:
        if l.startswith("== "):
            out.append([l, [], None])
        elif l.startswith("exit ") and out and out[-1][2] is None:
            out[-1][2] = l
        else:
            out[-1][1].append(l)
    return out


def again(run1, json):
    """A run of the ad35 world after a run 1 that failed at the check point (so nothing of the header was written), by the rules of the second runs of
    registry/rg2-example-add-short: no `tty` with --json; the project is known (no projects.json write); the roc on PATH is known (no version job);
    the guard reads the kept repo.json (no GitHub request); the R-AP1 answer is a fresh copy (`read_files <meta> <json>`, no request)."""
    out, i = [], 0
    while i < len(run1):
        l = run1[i]
        if (l == "tty" and json) or l == "write_atomic $HOME/.cache/roc/talon/projects.json" or l == "write_atomic $HOME/.cache/roc/talon/path-roc.json":
            i += 1
        elif l == "spawn_all limit=1":
            i += 2
        elif l == "http_get https://api.github.com/repos/acme/known":
            i += 4  # the request, 2 header lines, the write of repo.json
        elif l == "http_get http://127.0.0.1:9/v1/packages/acme/known/releases":
            key = run1[i + 2].split("/get/")[1].split(".json")[0]
            g = "$HOME/.cache/roc/talon/index/registry/http_127.0.0.1_9/get/" + key
            out.append(f"read_files {g}.meta {g}.json")
            i += 3
        else:
            out.append(l)
            i += 1
    return out


def write_case(name, plans, copies=None, keep_project=True, again_runs=False):
    """plans: one item for each run: (calls to insert, 'keep' | 'drop' (the calls after the check point), stdout lines or None (today's), stderr lines, exit).
    copies: {relative path in home: text} that the check writes. keep_project: False when no run writes the header (the work dir gets the project of orig/).
    again_runs: run 2 and later come from `again(run 1)` (today, run 1 wrote the header, so today's run 2 is not the run after a failure)."""
    c = os.path.join(CASES, name)
    w = os.path.join(WROOT, name.replace("/", "_"))
    today_calls = runs_of(read(os.path.join(w, "out/calls.log.n")).split("\n")[:-1])
    today_out = stdout_runs(read(os.path.join(w, "out/stdout.n")))
    if again_runs:
        today_calls = [today_calls[0]] + [again(today_calls[0], "--json" in so[0]) for so in today_out[1:]]
    if not keep_project:
        for dp, _, fs in os.walk(os.path.join(w, "orig/project")):
            for f in fs:
                src = os.path.join(dp, f)
                shutil.copyfile(src, os.path.join(w, "project", os.path.relpath(src, os.path.join(w, "orig/project"))))
    calls, out, err = [], [], []
    for run, so, (insert, after, lines, errs, code) in zip(today_calls, today_out, plans):
        k = post_end(run) if any(l.startswith("http_send POST ") for l in run) else len(run)
        calls += run[:k] + insert + (run[k:] if after == "keep" else [])
        out += [so[0]] + (so[1] if lines is None else lines) + [f"exit {code}"]
        err += errs
    ex = os.path.join(c, "expect")
    os.makedirs(ex, exist_ok=True)
    put(os.path.join(ex, "calls.log"), "\n".join(calls) + "\n")
    put(os.path.join(ex, "stdout"), "\n".join(out) + "\n")
    if err:
        put(os.path.join(ex, "stderr"), "\n".join(err) + "\n")
    elif os.path.exists(os.path.join(ex, "stderr")):
        os.remove(os.path.join(ex, "stderr"))
    put(os.path.join(ex, "exit"), "0\n")
    # The file tree: today's tree (in the work dir), with the copies of the check.
    for rel, text in (copies or {}).items():
        put(os.path.join(w, "home", rel), text)
    diff = subprocess.run(["bash", "-c", f'. "{ROOT}/tests/lib.sh"; tree_diff "{w}"'], check=True, capture_output=True, text=True).stdout
    put(os.path.join(ex, "tree.diff"), diff)


def served_checkpoint(case_dir, host, file="checkpoint"):
    return read(os.path.join(case_dir, "fx/http", host, "log", file))


L9 = Log("http://127.0.0.1:9", "http_127.0.0.1_9")
T3 = ["tile/entries/000.p/3", "tile/0/000.p/3"]
KNOWN = "known: acme/known 1.1.0"
KNOWN_URL = "https://github.com/acme/known/releases/download/1.1.0/24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL.tar.zst"
L1 = "github.com/acme/known/releases/download/{v}/ 1.0.0 5UVYbRk4zTJP7MLG5AAaTwK2TmX3U1bdndvNzddMyTaV 1790848800000"
L2 = "github.com/acme/known/releases/download/{v}/ 1.1.0 24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL 1790848800000"
LP = os.path.join(CASES, "logproof")


def known_copies(case):
    cps = copies_of(os.path.join(LP, case), 3, L9.origin, {"1": L1, "2": L2})
    cps[f".local/share/talon/log/{L9.origin}/checkpoint"] = served_checkpoint(os.path.join(LP, case), "127.0.0.1%3A9", "checkpoint.3" if case == "lp6-behind" else "checkpoint")
    return cps


def fail1(code, kind, message):
    return ([], [f"tln: error[{kind}]: {message}"], code)


# lp1, lp11c, lp11d: the proof passes; the copies and the checkpoint are written; the header is written; no new output.
for case in ["lp1-add-proof", "lp11c-trimmed-env", "lp11d-trimmed-config"]:
    write_case(f"logproof/{case}", [(fresh(L9, T3), "keep", None, [], 0)], copies=known_copies(case))
# lp2: the kept checkpoint and copies: no request, no write.
write_case("logproof/lp2-kept-copies", [(L9.read_kept() + L9.read_copies(T3), "keep", None, [], 0)])
# lp3: T3, then --json.
msg3 = "the checkpoint of the log of http://127.0.0.1:9 has no valid signature of 127.0.0.1:9/log+56ce7b6e (TALON_LOG_KEY). Talon wrote nothing."
ins3 = L9.read_kept() + L9.get_checkpoint()
write_case("logproof/lp3-bad-signature", [
    (ins3, "drop", [], [f"tln: error[integrity]: {msg3}"], 16),
    (ins3, "drop", [json_error("add", "integrity", 16, msg3, details(L9, "bad-signature", None, None, None))], [f"tln: error[integrity]: {msg3}"], 16),
], keep_project=False, again_runs=True)
# lp4, lp12: T1 (lp12 with --dry-run, and --json).
other = "github.com/acme/known/releases/download/{v}/ 1.1.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK"
msg1 = f"{KNOWN}: the log of http://127.0.0.1:9 has another entry at log index 2: {other}. Talon wrote nothing."
ins1 = L9.read_kept() + L9.get_checkpoint() + L9.read_copies(T3) + L9.fetch(T3)
write_case("logproof/lp4-entry-differs", [(ins1, "drop", [], [f"tln: error[integrity]: {msg1}"], 16)], keep_project=False)
write_case("logproof/lp12-dry-run-json", [
    (ins1, "drop", [], [f"tln: error[integrity]: {msg1}"], 16),
    (ins1, "drop", [json_error("add", "integrity", 16, msg1, details(L9, "entry-differs", 3, 2, KNOWN_URL))], [f"tln: error[integrity]: {msg1}"], 16),
], keep_project=False)
# lp5: T2.
msg2 = f"{KNOWN}: the inclusion proof of log index 2 does not match the signed checkpoint of http://127.0.0.1:9 (size 3). Talon wrote nothing."
write_case("logproof/lp5-tile-tampered", [(ins1, "drop", [], [f"tln: error[integrity]: {msg2}"], 16)], keep_project=False)
# lp15: T2b.
evil = "https://github.com/acme/known/releases/download/1.1.0/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst"
msg2b = f"{KNOWN}: the registry http://127.0.0.1:9 gave the URL {evil}, which is not the URL of its log entry. Talon wrote nothing."
write_case("logproof/lp15-url-differs", [(ins1, "drop", [], [f"tln: error[integrity]: {msg2b}"], 16)], keep_project=False)
# lp6: behind on reads 1 and 2, covers on read 3.
write_case("logproof/lp6-behind", [(fresh(L9, T3, sleeps=(2000, 4000)), "keep", None, [], 0)], copies=known_copies("lp6-behind"))
# lp6b: T5 after 4 reads.
msg5 = f"{KNOWN} (log index 2) is not in the log of http://127.0.0.1:9 yet: the checkpoint has size 1 after 4 reads. Try again in a few minutes."
write_case("logproof/lp6b-behind-four-reads", [(L9.read_kept() + L9.get_checkpoint((2000, 4000, 8000)), "drop", [], [f"tln: error[network]: {msg5}"], 15)], keep_project=False)
# lp7: T6 with status 404, then --json with timeout.
msg6a = f"the log of http://127.0.0.1:9 does not answer (status 404): Talon cannot check {KNOWN}. Try again later, or use --registry direct."
msg6b = f"the log of http://127.0.0.1:9 does not answer (timeout): Talon cannot check {KNOWN}. Try again later, or use --registry direct."
write_case("logproof/lp7-no-answer", [
    (L9.read_kept() + L9.get_checkpoint(), "drop", [], [f"tln: error[network]: {msg6a}"], 15),
    (L9.read_kept() + L9.get_checkpoint(), "drop", [json_error("add", "network", 15, msg6b, details(L9, "no-answer", None, 2, KNOWN_URL))], [f"tln: error[network]: {msg6b}"], 15),
], keep_project=False, again_runs=True)
# lp7b: T6b, then --json.
msg6t = "the log of http://127.0.0.1:9 has no tile tile/0/000.p/3 for size 3 (status 404). Try again later."
ins6t = L9.read_kept() + L9.get_checkpoint() + L9.read_copies(T3) + L9.fetch(T3)
write_case("logproof/lp7b-tile-missing", [
    (ins6t, "drop", [], [f"tln: error[network]: {msg6t}"], 15),
    (ins6t, "drop", [json_error("add", "network", 15, msg6t, details(L9, "tile-missing", 3, None, None))], [f"tln: error[network]: {msg6t}"], 15),
], keep_project=False, again_runs=True)
# lp8: T4. The consistency tile first; the date of the kept file from list_dirs (fx/mtimes).
T8 = ["tile/0/000.p/3", "tile/entries/000.p/3"]
msg4 = f"the log of http://127.0.0.1:9 changed its history: the checkpoint of size 3 does not contain the checkpoint of size 1 that Talon kept on 2026-10-14 ({L9.kept}). Talon wrote nothing. Report this to the registry operator."
ins4 = L9.read_kept() + L9.get_checkpoint() + L9.read_copies(T8) + L9.fetch(T8) + [f"list_dirs $HOME/.local/share/talon/log/{L9.origin}"]
write_case("logproof/lp8-fork", [(ins4, "drop", [], [f"tln: error[integrity]: {msg4}"], 16)], keep_project=False)
# lp9: --offline with the kept proof: no request. lp9b: T7.
T36 = ["tile/entries/000.p/36", "tile/0/000.p/36"]
write_case("logproof/lp9-offline", [(L9.read_kept() + L9.read_copies(T36), "keep", None, [], 0)])
msg7 = "json: acme/json 2.1.0 has no kept log proof and --offline is set. Run the command without --offline."
w9 = stdout_runs(read(os.path.join(WROOT, "logproof_lp9b-offline-no-proof/out/stdout.n")))[0][1]
before_check = [l for l in w9 if l.endswith(": fixed: not in the registry index") or l.endswith(": fixed: offline, no cached index")]
write_case("logproof/lp9b-offline-no-proof", [(L9.read_kept(), "keep", before_check, [f"tln: error[network]: {msg7}"], 15)])
# lp10, lp13: no check.
write_case("logproof/lp10-no-key", [([], "keep", None, [], 0)])
write_case("logproof/lp13-kept-values", [([], "keep", None, [], 0), ([], "keep", None, [], 0)])
# lp11, lp11b, lp11e: a bad setting at the check point.
m8b = f"TALON_LOG_KEY: 'xyz' is not a log verifier key {FORM}"
write_case("logproof/lp11-bad-env", [
    ([], "drop", [], [f"tln: error[usage]: {m8b}"], 2),
    ([], "drop", [json_error("add", "usage", 2, m8b, details(L9, "bad-key", None, None, None))], [f"tln: error[usage]: {m8b}"], 2),
], keep_project=False, again_runs=True)
m8 = f"$HOME/.config/talon/config.toml: line 2: log-key: 'xyz' is not a log verifier key {FORM}"
write_case("logproof/lp11b-bad-config", [
    ([], "drop", [], [f"tln: error[input]: {m8}"], 19),
    ([], "drop", [json_error("add", "input", 19, m8, details(L9, "bad-key", None, None, None))], [f"tln: error[input]: {m8}"], 19),
], keep_project=False, again_runs=True)
inner = read(os.path.join(LP, "lp11e-space-inside/given/home/.config/talon/config.toml")).split('log-key = "')[1].split('"')[0]
m8e = f"$HOME/.config/talon/config.toml: line 2: log-key: '{inner}' is not a log verifier key {FORM}"
write_case("logproof/lp11e-space-inside", [([], "drop", [], [f"tln: error[input]: {m8e}"], 19)], keep_project=False)
print("ok")
