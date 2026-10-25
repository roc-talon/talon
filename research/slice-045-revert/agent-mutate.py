#!/usr/bin/env python3
"""Revert check of slice 045 (code agent). One small break at a time, only the test that must see it.
Run from the repo root: python3 research/slice-045-revert/agent-mutate.py [id ...]
Each file is put back from research/slice-045-revert/code-final/ after each run, and the sha256 file is checked at the end."""
import os, shutil, subprocess, sys

FINAL = "research/slice-045-revert/code-final"
WORK = os.path.join(os.getcwd(), ".work")
os.environ["XDG_CACHE_HOME"] = WORK + "/cache"
os.environ["ROC_CACHE_DIR"] = WORK + "/cache/roc"
ROC = "/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
os.environ["ROC"] = ROC
L0 = [ROC, "test", "tests/unit/l0-3.roc", "--no-cache", "--jobs=2"]
L2 = lambda case: ["tests/commands/run.sh", case]
REF = "cli/lib/GitRef.roc"
BUILD = "cli/lib/GitBuild.roc"
INST = "cli/lib/GitInstall.roc"

# (id, file, old text, new text, test command, what the break is)
M = [
    ("G1", REF, "sha.to_utf8().take_first(8)", "sha.to_utf8().take_first(7)", L0, "the id has 7 characters, not 8 (R-R1)"),
    ("G2", INST, "headers = GitRef.commit_headers({ token: Net.token({ plan: net.token, gh }) })", "headers = GitRef.commit_headers({ token: Err(None) })", L2("roc/gi1-install"), "the commit request sends no token (review Q1)"),
    ("G3", INST, "gh = match net.token {\n\t\tAskGh => Github.ask_gh!(fx)\n\t\t_ => Err(None)\n\t}", "gh = Github.ask_gh!(fx)", L2("roc/gi1-install"), "gh is asked also when a variable or the test API gives the token"),
    ("G4", REF, "Ok(parts) => sha.starts_with(parts.sha)", "Ok(parts) => sha.contains(parts.sha)", L0, "the nightly note accepts the tag sha anywhere in the commit (R-R2)"),
    ("G5", BUILD, "if !best.any or at >= best.at {", "if Bool.True {", L0, "newest ignores the time: the last row wins (R-R5, R-R6)"),
    ("G6", BUILD, " or (is_sha_text(source.ref) and sha_starts(sha, source.ref))", "", L0, "a typed sha does not match the full sha of a build (review Q6)"),
    ("G7", INST, "Wget => Err(GitRef.needs_curl({}))", "Wget => Ok({})", L2("roc/gi1-install"), "wget is allowed for a source archive (R-DA3, R-SE12)"),
    ("G8", INST, "_ = fx.delete!([p.temp, p.scratch])", "_ = fx.delete!([p.temp])", L2("roc/gi2-zig"), "the scratch dir stays after a failed build (R-CC2)"),
    ("G9", INST, "Installed => RocInstall.first_default!(fx, run.roots, run.id)?", "Installed => Kept", L2("roc/gi2-zig"), "the first git build is not made the default (R-SO15)"),
    ("G10", INST, "if args.offline return Err(GitRef.offline_failure(source))\n\tsha = commit!(fx, net, source, real)?", "sha = commit!(fx, net, source, real)?\n\tif args.offline return Err(GitRef.offline_failure(source))", L2("roc/gi1-install"), "--offline stops after the commit request, not before (R-DI12)"),
    ("G11", REF, "404 | 422 =>", "404 =>", L0, "a 422 is not a usage failure"),
    ("G12", INST, "if has_dir(entries, run.id) return Ok({ how: Present, compat: Err(Unknown) })", "if Bool.False and has_dir(entries, run.id) return Ok({ how: Present, compat: Err(Unknown) })", L2("roc/gi2-zig"), "no check for the dir under the lock (R-CC4 step 4)"),
]

def run(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    return p.returncode, (p.stdout + p.stderr)

rows = []
only = sys.argv[1:]
for mid, path, old, new, cmd, what in M:
    if only and mid not in only:
        continue
    src = open(os.path.join(FINAL, path)).read()
    if src.count(old) != 1:
        rows.append((mid, what, "BAD MUTATION: old text found %d times" % src.count(old)))
        continue
    open(path, "w").write(src.replace(old, new))
    try:
        rc, out = run(cmd)
    finally:
        shutil.copyfile(os.path.join(FINAL, path), path)
    if rc == 0:
        verdict = "NOT CAUGHT"
    elif "── ✗" in out and "FAIL" not in out and "failed" not in out.lower() and "passed" not in out:
        verdict = "DID NOT COMPILE (check)"
    else:
        verdict = "caught (exit %d)" % rc
    rows.append((mid, what, verdict + " by " + " ".join(cmd[-2:] if cmd[0] != ROC else ["test", cmd[2]])))
    print(mid, verdict, flush=True)

sha = subprocess.run(["sha256sum", "-c", "research/slice-045-revert/code-final.sha256"], capture_output=True, text=True)
print(sha.stdout, sha.stderr)
with open("research/slice-045-revert/agent-results.md", "w") as f:
    f.write("# Revert check of slice 045 (code agent)\n\n| Id | Mutation | Result |\n| --- | --- | --- |\n")
    for r in rows:
        f.write("| %s | %s | %s |\n" % r)
    f.write("\nCode after the runs: %s\n" % ("same as code-final (sha256sum -c: all OK)" if sha.returncode == 0 else "DIFFERENT: " + sha.stdout))
sys.exit(0 if sha.returncode == 0 else 1)
