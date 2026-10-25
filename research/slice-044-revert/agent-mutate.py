#!/usr/bin/env python3
"""Revert check of slice 044 (code agent). One small break at a time, only the test that must see it.
Run from the repo root: python3 research/slice-044-revert/agent-mutate.py [id ...]
Each file is put back from research/slice-044-revert/code-final/ after each run, and the sha256 file is checked at the end."""
import os, shutil, subprocess, sys

FINAL = "research/slice-044-revert/code-final"
WORK = os.path.join(os.getcwd(), ".work")
os.environ["XDG_CACHE_HOME"] = WORK + "/cache"
os.environ["ROC_CACHE_DIR"] = WORK + "/cache/roc"
os.environ["ROC"] = None or "/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
ROC = "/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
L0 = [ROC, "test", "tests/unit/l0-6.roc"]
L2 = lambda case: ["tests/commands/run.sh", case]
L3 = ["tests/run.sh", "zi1-zig-install"]
Z = "cli/lib/Zig.roc"
ZI = "cli/lib/ZigInstall.roc"
C = "cli/lib/Consent.roc"

# (id, file, old text, new text, test command, what the break is)
M = [
    ("Z1", Z, "Ok(v) => Found({ source: Env, path: env.path, version: v })", "Ok(v) => if fits(need, env) Found({ source: Env, path: env.path, version: v }) else Missing(\"zig not found\")", L2("zig/zs1-search"), "ZIG is checked for the series (R-D1, Q1)"),
    ("Z2", Z, "if is_newer(order_key(version_text(c)), order_key(version_text(old))) Ok(c) else Ok(old)", "if is_newer(order_key(version_text(c)), order_key(version_text(old))) Ok(old) else Ok(c)", L2("zig/zs1-search"), "the oldest fitting installed dir wins"),
    ("Z3", Z, "if is_newer(order_key(version_text(c)), order_key(version_text(old))) Ok(c) else Ok(old)", "if Text.compare(version_text(c), version_text(old)) == After Ok(c) else Ok(old)", L2("zig/zs1-search"), "the newest installed dir is chosen in text order (0.18.9 over 0.18.10)"),
    ("Z4", ZI, "Toolchain.check_download({ id, want: run.entry.sha256, got })?", "_ = Toolchain.check_download({ id, want: run.entry.sha256, got })", L2("zig/zi1-install"), "the sha256 check does not stop the install"),
    ("Z5", Z, "MacosX64 => \"x86_64-macos\"\n\t\tMacosApple => \"aarch64-macos\"", "MacosX64 => \"aarch64-macos\"\n\t\tMacosApple => \"x86_64-macos\"", L2("zig/zi2-xz"), "the keys of the 2 macOS hosts are swapped"),
    ("Z6", C, "\t\t\tid: \"zig-install\",\n\t\t\tkind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: Yes,", "\t\t\tid: \"zig-install\",\n\t\t\tkind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: No,", L2("zig/zi1-install"), "the interactive default of the prompt is No"),
    ("Z7", C, "\t\t\tid: \"zig-install\",\n\t\t\tkind: Default,", "\t\t\tid: \"zig-install\",\n\t\t\tkind: Required([\"--yes\"]),", L2("zig/zi1-install"), "non-interactive with no --yes stops (the prompt is Required)"),
    ("Z8", ZI, "if Zig.needs_xz({ host: run.host, archive: run.entry.archive }) and !found.xz {", "if Bool.False and !found.xz {", L2("zig/zi2-xz"), "no xz check under the lock"),
    ("Z9", ZI, "if entries.any(|e| e.is_dir and e.name == Text.last_segment(item)) return Ok(Present)", "if Bool.False and entries.any(|e| e.is_dir and e.name == Text.last_segment(item)) return Ok(Present)", L2("zig/zi1-install"), "no check for the dir under the lock"),
    ("Z10", ZI, "\t\t\tYes => {}\n\t\t\t_ => return Err(Consent.zig_install_declined(entry.version))", "\t\t\tYes => {}\n\t\t\t_ => {}", L2("zig/zi1-install"), "a No answer does not stop the install"),
    ("Z11", Z, "Ok(Text(text)) if is_sha256(text) => text", "Ok(Text(text)) if !text.is_empty() => text", L0, "any non-empty shasum text is accepted"),
    ("Z12", ZI, "\t\t_ = fx.delete!(stale)", "\t\t_ = {}", L2("zig/zi1-install"), "stale temps are not deleted"),
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
    elif "build of the L2 app failed" in out or "── ✗" in out and "FAIL" not in out and "failed" not in out.lower():
        verdict = "DID NOT COMPILE (check)"
    else:
        verdict = "caught (exit %d)" % rc
    rows.append((mid, what, verdict + " by " + " ".join(cmd[-2:])))
    print(mid, verdict, flush=True)

sha = subprocess.run(["sha256sum", "-c", "research/slice-044-revert/code-final.sha256"], capture_output=True, text=True)
print(sha.stdout, sha.stderr)
with open("research/slice-044-revert/agent-results.md", "w") as f:
    f.write("# Revert check of slice 044 (code agent)\n\n| Id | Mutation | Result |\n| --- | --- | --- |\n")
    for r in rows:
        f.write("| %s | %s | %s |\n" % r)
    f.write("\nCode after the runs: %s\n" % ("same as code-final (sha256sum -c: all OK)" if sha.returncode == 0 else "DIFFERENT: " + sha.stdout))
sys.exit(0 if sha.returncode == 0 else 1)
