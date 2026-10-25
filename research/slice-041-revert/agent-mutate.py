#!/usr/bin/env python3
"""Revert check of slice 041 (code agent): each mutation breaks the code in one small way,
runs `scripts/test.sh check l0 l2`, records the failing steps, and puts the file back.
Run from the repo root: python3 research/slice-041-revert/agent-mutate.py [id ...]"""
import subprocess, sys, shutil, hashlib, re

INIT = "cli/lib/Init.roc"
ARGS = "cli/lib/Args.roc"
MUTS = [
    ("M1", INIT, "\t\t\t_ = fx.delete!([main_path])\n", "\t\t\t_ = []\n", "a failed run does not remove its main.roc"),
    ("M2", INIT, "[Ok(_)] => Exists\n\t\t\t[Err(NotFound)] => {", "[Ok(_)] | [Err(NotFound)] => {", "an existing CI file is overwritten"),
    ("M3", INIT, "\t\tNoCi => Skipped\n\t\tCi => match", "\t\tNoCi | Ci => match", "--ci none still writes the CI file"),
    ("M4", ARGS, '"--probe-downloads" => resolving or one_of(["probe", "init"])', '"--probe-downloads" => resolving or one_of(["probe"])', "init refuses --probe-downloads"),
    ("M5", ARGS, 'one_of(["probe", "roc use", "init"])', 'one_of(["probe", "roc use"])', "init refuses --allow-downloads"),
    ("M6", INIT, " and !name.contains(\"@\")", "", "a platform name with @ is accepted"),
    ("M7", INIT, "options: consent,", "options: consent.drop_first(consent.len()),", "the consent flags do not reach the flow"),
    ("M8", INIT, '[Ok(_)] => return Err(Fail.new(Usage, "main.roc is in ${cwd} already. tln init never overwrites a file."))', "[Ok(_)] => {}", "an existing main.roc is overwritten"),
    ("M9", INIT, "c.published_at + facts.min_age <= facts.now", "c.published_at + facts.min_age <= facts.now or Bool.True", "the start release ignores min-release-age"),
    ("M10", INIT, '(Ok(_), Package) => Err(Fail.new(Usage, "--platform does not work with the package template: a package has no platform"))', "(Ok(_), Package) => Ok({ template, named, ci })", "--platform is accepted with package"),
]

def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()

def main():
    want = sys.argv[1:]
    for mid, path, old, new, what in MUTS:
        if want and mid not in want:
            continue
        orig = open(path).read()
        if orig.count(old) != 1:
            print(f"{mid}: pattern found {orig.count(old)} times, skipped"); continue
        before = sha(path)
        open(path, "w").write(orig.replace(old, new))
        try:
            r = subprocess.run(["scripts/test.sh", "check", "l0", "l2"], capture_output=True, text=True)
            out = r.stdout + r.stderr
        finally:
            open(path, "w").write(orig)
        assert sha(path) == before
        steps = re.findall(r"^(check|fmt|l0|l2)\s+(pass|FAIL)", out, re.M)
        failed = [s for s, v in steps if v == "FAIL"]
        detail = [l.strip()[:90] for l in out.splitlines() if re.search(r"FAIL|failed|crash|ERROR", l)][:4]
        import glob
        files = [f.split("/")[-1][:-3] for f in glob.glob(".work/logs/l0/*.rc") if open(f).read().strip() != "0"]
        detail = [f"l0 files: {files}"] + detail
        print(f"{mid} | {what} | exit {r.returncode} | failed steps: {failed} | {'; '.join(detail)}", flush=True)

main()
