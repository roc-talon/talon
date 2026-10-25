#!/usr/bin/env python3
"""Revert check of slice 055 (code agent). Run from anywhere: python3 research/slice-055-revert/agent-mutate.py [id ...]
Each mutation changes one place of cli/lib, runs the steps that must see it, and puts the file back (sha256 check)."""
import os, subprocess, sys, hashlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
os.chdir(ROOT)

# id, file, old text, new text, test steps, description
M = [
    ("A1", "InitStub", "tok_at(toks, j + 1).kind == Colon", "Bool.True",
     "l0 l2", "any word after a comma starts an entry (the requires split)"),
    ("A2", "InitStub", "args.len() == 2 and is_open", "args.len() == 3 and is_open",
     "l0 l2", "() counts as one argument (the stub text)"),
    ("A3", "Init", "url })?\n\t\t\t\tInitStub.app_text({ name, url, text: header })?", "url })?\n\t\t\t\tInitStub.app_text({ name, url, text: header }) ?? InitText.app_file({ name, url })",
     "l2", "a type with no stub falls back to the hello world: no exit 2 (nothing written)"),
    ("A4", "Init", "!here.moved.any(|m| m.alias == \"pf\")", "Bool.True",
     "l2", "no remake after the resolve moved the platform"),
    ("A5", "Init", "Ok(id) => [Pin(id)]", "Ok(_) => []",
     "l2", "the remake drops the roc: pin"),
    ("A6", "PathCmd", "Text.dir_of(Text.resolve(Text.dir_of(x.file), row.value))", "Text.dir_of(Text.resolve(x.file, row.value))",
     "l0 l2", "a path entry is seen from the project file, not from its directory"),
    ("A7", "PathFlow", "Release(url) => fetch!(fx, { roots: start.roots, net: start.net, offline: args.offline, url })?", "Release(_) => {}",
     "l2", "no fetch of a missing release dir"),
    ("A8", "PathFlow", "offline: args.offline, url })?", "offline: Bool.False, url })?",
     "l2", "--offline does not reach the fetch (exit 15)"),
    ("A9", "PathFlow", "files: Install.canonical_files!(fx, start.project)", "files: []",
     "l2", "the project file is not recorded"),
    ("A10", "Init", "{ net, roots, offline: args.offline, url }", "{ net, roots, offline: Bool.False, url }",
     "l2", "--offline does not reach the fetch of the platform in init"),
]

def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()

def run(steps):
    p = subprocess.run(["scripts/test.sh"] + steps.split(), capture_output=True, text=True)
    out = p.stdout + p.stderr
    bad = [l.strip() for l in out.splitlines() if "FAIL" in l or "fail" in l.lower() and "0 failed" not in l]
    return p.returncode, bad[:6]

want = sys.argv[1:]
for mid, name, old, new, steps, desc in M:
    if want and mid not in want:
        continue
    path = f"cli/lib/{name}.roc"
    before = sha(path)
    text = open(path).read()
    if text.count(old) != 1:
        print(f"{mid}: SKIPPED, the old text occurs {text.count(old)} times", flush=True)
        continue
    open(path, "w").write(text.replace(old, new))
    try:
        rc, bad = run(steps)
    finally:
        open(path, "w").write(text)
    assert sha(path) == before, f"{mid}: file not restored"
    print(f"{mid} {name}: {desc}: {'CAUGHT' if rc != 0 else 'NOT CAUGHT'} (steps {steps}, rc {rc}) {bad}", flush=True)
