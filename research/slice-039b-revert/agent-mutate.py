#!/usr/bin/env python3
"""Revert check of the code of slice 039b by the code agent (TW12, filtered runs only, no full sweep).

Before each mutation the file is restored from research/slice-039b-revert/code-final/ (repo-relative paths). After the run, the same copy is put back and
`code-final.sha256` is checked from the repo root. CAUGHT = a test fails or times out.
Usage: python3 -I research/slice-039b-revert/agent-mutate.py [id ...]   (from the repo root)
"""
import hashlib, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
FINAL = os.path.join(ROOT, "research/slice-039b-revert/code-final")
LIB = "cli/lib/"
TIMEOUT = {"l0": 180, "l2": 600}
UR5 = "l2:upgrade/ur5-optional"

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("A1", "PickOptional.roc", [("fx.err!(\"${Consent.optional_skipped({ count: every.fetch.len(), size: every.size })}\\n\")\n				Ok(left_out(round, state, { gone: state.open,", "fx.err!(\"${Consent.optional_skipped({ count: every.fetch.len(), size: every.size })}\\n\")\n				Ok(left_out(round, state, { gone: wanted,")], [UR5], "R-DL4: a skip removes only the wanted compilers, so the line shows again"),
    ("A2", "PickOptional.roc", [("else request.downloads.probe })", "else request.downloads.probe.on_err(|_| request.downloads.allow) })")], [UR5], "R-DL5: --allow-downloads is an opt-in"),
    ("A3", "PickOptional.roc", [("yes: !request.dry_run and request.prompt.yes, flag: if request.dry_run Err(NoFlag) else request.downloads.probe", "yes: request.prompt.yes, flag: request.downloads.probe")], [UR5], "R-LF4: --dry-run does not answer No"),
    ("A4", "PickOptional.roc", [("$failed = $failed.append(item.id)\n				$tried = $tried + 1", "$failed = $failed.append(item.id)")], [UR5], "R-DL6: a failed try does not count for the cap"),
    ("A5", "PickLoop.roc", [("	budget = match Units.budget({ max, started: probed.count, fixed: 0, wanted: pairs.len() }) {", "	early = PickOptional.step!(fx, request, { settings: setup.settings, sizes: setup.optional.sizes, pairs: pairs }, probed.optional)?\n	budget = match Units.budget({ max, started: probed.count, fixed: 0, wanted: pairs.len() }) {"), ("stepped = PickOptional.step!(fx, request, { settings: setup.settings, sizes: setup.optional.sizes, pairs: pairs.take_first(budget.run) }, probed.optional)?", "stepped = { state: early.state, pairs: early.pairs.take_first(budget.run) }")], [UR5], "R-P5: the download is made before the budget check"),
    ("A6", "PickOptional.roc", [("left = if cap > state.tried cap - state.tried else 0", "left = cap")], [UR5], "R-DL6: the cap does not count the tries of earlier rounds"),
    ("A7", "InstallFlow.roc", [(" + probed.optional.downloads }", " }")], [UR5], "R-J3: data.downloads does not count the optional downloads"),
    ("A8", "PickLoop.roc", [(".concat(probed.optional.got)", "")], [UR5], "a compiler that the search installed is no value of the compiler slot"),
    ("A9", "InstallFlow.roc", [("if cap > 0 and probed.optional.dropped > 0 {", "if probed.optional.dropped > 0 {")], [UR5], "R-DL6: the cap note shows also when the cap is 0"),
    ("A10", "NightlyPlan.roc", [("!have(id) and newest != Ok(id)", "(!have(id) or Bool.True) and newest != Ok(id)")], ["l0:nightlyplan"], "R-UP6: an installed compiler is optional"),
]


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def restore(fname):
    shutil.copyfile(os.path.join(FINAL, LIB, fname), os.path.join(ROOT, LIB, fname))


def run(test):
    kind, _, arg = test.partition(":")
    cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"] if kind == "l0" else ["tests/commands/run.sh"] + arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr)


def main():
    want = set(sys.argv[1:])
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        path = os.path.join(ROOT, LIB, fname)
        restore(fname)
        text = open(path).read()
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            try:
                built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
                if built.returncode != 0:
                    print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                    continue
                caught_by = None
                for t in tests:
                    failed, _ = run(t)
                    if failed:
                        caught_by = t
                        break
                print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
            finally:
                restore(fname)
    bad = subprocess.run("sha256sum -c research/slice-039b-revert/code-final.sha256 | grep -v ': OK$'", shell=True, cwd=ROOT, capture_output=True, text=True).stdout
    print("final compare:", "SAME" if not bad else "DIFFERENT\n" + bad, flush=True)


main()
