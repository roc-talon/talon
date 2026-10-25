#!/usr/bin/env python3
"""Revert check of slice 059 (code agent). Run from the repo root: python3 research/slice-059-revert/agent-mutate.py [name ...]
Each mutation changes one small thing in a file of cli/lib, checks that the code still compiles, runs L0, then L2, then L3 (filtered) until one fails,
and puts the file back from code-final/. At the end `sha256sum -c research/slice-059-revert/code-final.sha256` must pass."""
import os, subprocess, sys, shutil

ROOT = os.getcwd()
FINAL = "research/slice-059-revert/code-final"
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))

# (name, file, old, new)
MUTATIONS = [
    ("m1-key-matches-repo-name", "XProject.roc",
     "find_first(|e| e.key == facts.ref.name)", "find_first(|e| e.key == facts.ref.name or Text.last_segment(ToolsToml.app_of(e.ref)) == facts.ref.name)"),
    ("m2-first-entry-of-app-wins", "XProject.roc",
     "[entry] => Ok({ entry, via: App })\n\t\t\t\t\t_ => Err(Many(same.map(|e| e.key)))", "[entry, ..] => Ok({ entry, via: App })"),
    ("m3-selector-does-not-stop-walk", "XProject.roc",
     "Ok(_) => Ok(Err(Miss))\n\t\tErr(None) => walk!", "Ok(_) => walk!(fx, args, plan)\n\t\tErr(None) => walk!"),
    ("m4-no-record", "XProject.roc",
     "files: RunSteps.record_files!(fx, seen.scan, seen.found)", "files: []"),
    ("m5-table-of-the-file-not-of-the-root", "XProject.roc",
     'path = Text.join(seen.found.tools_dir, "talon.toml")\n\ttext = match seen.scan.walk.find_first(|d| d.dir == seen.found.tools_dir)',
     'path = Text.join(seen.found.dir, "talon.toml")\n\ttext = match seen.scan.walk.find_first(|d| d.dir == seen.found.dir)'),
    ("m6-args-after-dashes-dropped", "XProject.roc",
     "argv: [got.bin].concat(plan.args)", "argv: [got.bin].concat(plan.args.drop_first(1))"),
    ("m7-note-for-key-too", "XProject.roc",
     "(App, Ok(ident)) =>", "(_, Ok(ident)) =>"),
    ("m8-standalone-records-toml-not-main", "RunSteps.roc",
     'if has_main "main.roc" else "talon.toml"', 'if !has_main "main.roc" else "talon.toml"'),
]

def sh(cmd, timeout=900):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout + p.stderr

def main():
    want = sys.argv[1:]
    for name, file, old, new in MUTATIONS:
        if want and name not in want:
            continue
        path = f"cli/lib/{file}"
        with open(path) as f:
            text = f.read()
        if text.count(old) != 1:
            print(name, "BAD PATTERN", text.count(old)); continue
        with open(path, "w") as f:
            f.write(text.replace(old, new))
        try:
            rc, out = sh(f"{ROC} check cli/lib/main.roc")
            if rc != 0:
                print(name, "INVALID (does not compile)", out[-300:]); continue
            result = "NOT CAUGHT"
            for layer, cmd in (("l0", f"{ROC} test tests/unit/l0-7.roc"), ("l2", "tests/commands/run.sh x/x3-project"), ("l3", "tests/run.sh ptools/pt2-x")):
                rc, out = sh(cmd)
                if rc != 0:
                    result = f"killed by {layer}"; break
            print(name, result, flush=True)
        finally:
            shutil.copy(f"{FINAL}/{path}", path)

main()
