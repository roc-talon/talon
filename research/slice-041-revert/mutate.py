#!/usr/bin/env python3
"""Revert check of the reference code of slice 041 (TW12, filtered runs only, no full sweep).

The tree must hold the reference (research/slice-041-revert/reference/). For each mutation: one small change in one file of cli/lib, a `roc check`,
then only the tests that must see it. CAUGHT = a test fails or times out. The file is put back after each mutation.
Usage: python3 -I research/slice-041-revert/mutate.py [id ...]   (from the repo root)
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
TIMEOUT = {"l0": 180, "l2": 600}
IT1 = "l2:init/it1-app"

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("I1", "Init.roc", [("		[Ok(_)] => return Err(Fail.new(Usage, \"main.roc is in", "		[Ok(_)] => {}\n		[Err(Denied)] => return Err(Fail.new(Usage, \"main.roc is in")], [IT1], "R-IN7: an existing main.roc is overwritten"),
    ("I2", "Init.roc", [("	match fx.read_files!([main_path]) {\n		[Err(NotFound)] => {}", "	match fx.read_files!([main_path, Text.join(Text.dir_of(cwd), \"main.roc\")]) {\n		[Err(NotFound), Err(NotFound)] => {}"), ("		[Ok(_)] => return Err(Fail.new(Usage, \"main.roc is in", "		[Ok(_), _] | [_, Ok(_)] => return Err(Fail.new(Usage, \"main.roc is in")], [IT1], "R-PD15: init looks for a main.roc above the current directory"),
    ("I3", "Init.roc", [("allowed = facts.list.keep_if(|c| c.published_at + facts.min_age <= facts.now)", "allowed = facts.list")], ["l0:init", IT1], "R-C7: the start release ignores min-release-age"),
    ("I4", "Init.roc", [("	ci_path = Text.join(cwd, \".github/workflows/ci.yml\")\n", "	ci_path = Text.join(cwd, \".github/workflows/ci.yml\")\n	_ = fx.write_atomic!([{ path: Text.join(cwd, \".roc-version\"), content: outcome.pinned ?? \"\" }])\n")], [IT1], "R-IN4, R-SO16: init writes .roc-version"),
    ("I6", "Init.roc", [("		Ok(\"none\") => NoCi\n", "		Ok(\"none\") => Ci\n")], ["l0:init", IT1], "R-IN6: --ci none still writes the CI file"),
    ("I7", "Init.roc", [("		Package => InitText.package_file\n", "		Package => app_text!(fx, args, plan, { roots, net, now })?\n")], [IT1], "R-IN1: init package writes an app"),
    ("I8", "Init.roc", [("	name = plan.named ?? InitText.default_platform", "	name = if plan.named.is_ok() InitText.default_platform else InitText.default_platform")], [IT1], "R-IN1: --platform is ignored"),
    ("I9", "InitText.roc", [("sh -s -- --yes --version ${version}", "sh")], ["l0:init", IT1], "R-IN6: the install line of the CI file has no version and no --yes"),
    ("I10", "Init.roc", [("	begun = Update.begin!(shown, given)?\n", "	begun = Update.begin!(shown, { ..given, file: Err(Unset) })?\n")], [IT1], "R-PD15: the flow searches for the project (no --file)"),
    ("I11", "Init.roc", [("	opts = Opts.read(given)?\n", "	opts = { ..Opts.read(given)?, no_check: Bool.True }\n")], [IT1], "R-IN2: the ladder is skipped (the pin moves with no check)"),
    ("I12", "Init.roc", [("			_ = fx.delete!([main_path])\n", "			_ = fx.delete!([])\n")], [IT1], "Q1: a failed run leaves the main.roc that it made"),
    ("I13", "Init.roc", [("			[Ok(_)] => Exists\n", "			[Ok(_)] => match fx.write_atomic!([{ path: ci_path, content: InitText.ci_file(Help.version) }]) {\n				Ok({}) => Made\n				Err(_) => Exists\n			}\n")], [IT1], "R-IN7: an existing CI file is overwritten"),
    ("I14", "Init.roc", [("options: consent, file", "options: consent.drop_first(9), file")], [IT1], "Q3: the consent flags do not reach the flow"),
    ("I15", "Init.roc", [("			(Package, Ok(_)) => return Err(", "			(Package, Ok(_)) if args.operands.len() > 5 => return Err(")], ["l0:init"], "Q4: --platform is accepted with package"),
    ("I16", "Init.roc", [("[o, r] if o != \"\" and r != \"\" and !r.contains(\"@\") => {}", "[o, r] if o != \"\" and r != \"\" => {}")], ["l0:init"], "Q6: a platform name with a selector is accepted"),
]


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    else:
        cmd = ["tests/commands/run.sh"] + arg.split()
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
        orig = open(path).read()
        text = orig
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
                open(path, "w").write(orig)


main()
