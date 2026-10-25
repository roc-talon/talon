#!/usr/bin/env python3
"""Revert check of slice 045: each mutant changes one tricky behavior of the private reference in cli/lib, runs the filtered tests (l0, then l2, then l3) and puts the reference back.
Run from the repo root: python3 research/slice-045-revert/mutants.py [number ...]. The output is `research/slice-045-revert/mutants.log`. Never the full sweep."""
import subprocess, sys, os, shutil
ROC = os.path.abspath("cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.abspath(".work/cache"), ROC_CACHE_DIR=os.path.abspath(".work/cache/roc"), OPT="dev")
M = [
 (1, "Nightlies.by_name: no exact-id branch", "Nightlies.roc", "} else if named.contains(text) {", "} else if Bool.False {"),
 (2, "commit request without the sha media type", "GitRef.roc", '.append(("Accept", "application/vnd.github.sha"))', ""),
 (3, "nightly note: sha anywhere in the commit", "GitRef.roc", "facts.sha.starts_with(parts.sha)", "facts.sha.contains(parts.sha)"),
 (4, "id has 7 characters", "GitRef.roc", "sublist({ start: 0, len: 8 })", "sublist({ start: 0, len: 7 })"),
 (5, "newest: repo not compared", "GitBuild.roc", "if r == GitRef.repo_url(facts.source) and f == facts.source.ref", "if f == facts.source.ref"),
 (6, "newest: time not compared (last row wins)", "GitBuild.roc", "if item.at >= old.at Ok(item) else Ok(old)", "Ok(item)"),
 (7, ".talon.json ref field has the sha", "GitBuild.roc", '("ref", JsonDoc.Text(facts.source.ref))', '("ref", JsonDoc.Text(facts.sha))'),
 (8, "wget allowed", "GitInstall.roc", "Wget => Err(GitRef.needs_curl({}))", "Wget => Ok(Wget)"),
 (9, "scratch dir kept after a failure", "GitInstall.roc", "fx.delete!([p.temp, p.scratch])", "fx.delete!([p.temp])"),
 (10, "no first default", "GitInstall.roc", "Installed => RocInstall.first_default!(fx, ctx.roots, ctx.id)?", "Installed => Kept"),
 (11, "offline does not stop", "GitInstall.roc", "if args.offline return Err(GitRef.offline_failure(source))", ""),
 (12, "422 is not a usage failure", "GitRef.roc", "facts.status == 404 or facts.status == 422", "facts.status == 404"),
 (13, "default --git: no match by full sha", "GitBuild.roc", "(f == facts.source.ref or by_sha(facts.source.ref, sha))", "f == facts.source.ref"),
 (14, "default --git: a 1 digit text matches the sha", "GitBuild.roc", "bytes.len() >= 7 and bytes.len() <= 40", "bytes.len() >= 1 and bytes.len() <= 40"),
 (15, "commit request sends no token", "GitInstall.roc", "GitRef.commit_headers({ token: token })", "GitRef.commit_headers({ token: Err(None) })"),
 (16, "commit request asks gh for a token also when a variable gives one", "GitInstall.roc", "AskGh => ask_gh!(fx)\n\t\t_ => Err(None)\n\t}\n\ttoken = Net.token", "_ => ask_gh!(fx)\n\t}\n\ttoken = Net.token"),
]
def sh(*a, **k): return subprocess.run(a, env=ENV, capture_output=True, text=True, **k)
want = [int(x) for x in sys.argv[1:]]
log = open("research/slice-045-revert/mutants.log", "a")
for n, what, f, old, new in M:
    if want and n not in want: continue
    path = "cli/lib/" + f
    ref = "research/slice-045-revert/reference/lib/" + f
    if not os.path.exists(ref): ref = "research/slice-045-revert/before/cli/lib/" + f  # a file that the slice does not change
    src = open(ref).read()
    if src.count(old) != 1:
        log.write(f"{n}\t{what}\tSKIPPED: old text found {src.count(old)} times\n"); log.flush(); continue
    open(path, "w").write(src.replace(old, new))
    result = "SURVIVED"
    for step, cmd in (("l0", [ROC, "test", "tests/unit/l0-3.roc"]), ("l2", ["tests/commands/run.sh", "roc/gi"]), ("l3", ["tests/run.sh", "compilers/gi1"])):
        r = sh(*cmd)
        out = (r.stdout + r.stderr)
        if "error[" in out and r.returncode != 0 and "COMPILE" in out.upper() and step != "l0" and "failed" not in out:
            result = f"BUILD-ERROR in {step}"; break
        if r.returncode != 0:
            result = f"KILLED by {step}"; break
    shutil.copy(ref, path)
    log.write(f"{n}\t{what}\t{result}\n"); log.flush()
