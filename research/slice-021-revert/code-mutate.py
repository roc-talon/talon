#!/usr/bin/env python3
"""Revert check of the code of slice 021 (TW12, filtered runs only, no full sweep).

For each mutation: all files are first put back from code-final/ (so a kill is safe), then one small change in one file, a `roc check`,
then only the tests that should catch it. The first test that fails ends the run of that mutation (CAUGHT). A test that runs longer than the
timeout counts as CAUGHT (a loop). At the end all files are put back and compared with code-final/.

Usage: python3 -I research/slice-021-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed. Last line: SAME or DIFFERENT.
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-021-revert/code-final")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300, "sh": 300}
FILES = ["cli/lib/Toolchain.roc", "cli/lib/RocInstall.roc", "cli/lib/Consent.roc", "cli/RealFx.roc", "scripts/test.sh"]
T, R, C, X, S = FILES
L0 = ["l0:toolchain"]
L2 = ["l2:roc/ri1"]
L3 = ["l3:compilers/ri1 compilers/ri2"]

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("T1", T, [("(Macos, Arm64) => Ok(MacosApple)", "(Macos, Arm64) => Ok(MacosX64)")], L0, "R-CV8: macOS arm64 is the x64 asset"),
    ("T2", T, [("got ${many.len().to_str()}", "got ${(many.len() - 1).to_str()}")], L0, "R-CM15: the count of operands is wrong"),
    ("T3", T, [("min_age: facts.min_age, snapshot", "min_age: 0, snapshot")], L0, "R-C7: auto has no age limit"),
    ("T4", T, [("named: found.map(|r| r.id)", "named: shown.map(|r| r.id)")], L0, "R-NS4: a name is limited by the age"),
    ("T5", T, [("if has_no_asset(facts.releases, text) {", 'if has_no_asset(facts.releases, "") {')], L0, "R-SC10: the text never names the host"),
    ("T6", T, [("WindowsX64 | WindowsArm64 => \"roc.exe\"", "WindowsX64 => \"roc.exe\"")], L0, "R-HF2: windows arm64 has no roc.exe"),
    ("T7", T, [(', "-C", facts.dir, "--strip-components=1"]', ', "-C", facts.dir]')], L0, "R-HF5: tar keeps the top dir"),
    ("T8", T, [("WindowsX64 | WindowsArm64 => Err(NotNeeded)", "WindowsX64 => Err(NotNeeded)")], L0, "R-HF2: chmod on windows arm64"),
    ("T9", T, [('Fail.new(Integrity, "the asset of', 'Fail.new(Network, "the asset of')], L0, "R-CV4: a missing digest has the kind network"),
    ("T10", T, [("check_download = |facts| if facts.want == facts.got {", "check_download = |facts| if facts.want == facts.want {")], L0, "R-SE11: a wrong hash is ok"),
    ("T11", T, [('Fail.new(Network, "download of ${facts.id} failed: ${status.to_str()}', 'Fail.new(Integrity, "download of ${facts.id} failed: ${status.to_str()}')], L0, "R-DA7: a 404 has the kind integrity"),
    ("T12", T, [('Fail.new(Integrity, "tar rejected', 'Fail.new(Network, "tar rejected')], L0, "R-SE9: tar refusal has the kind network"),
    ("T13", T, [("Ok(old) => old.mtime < entry.mtime", "Ok(_) => Bool.False")], L0, "R-GC10: a dir with a later time is not touched"),
    ("T14", T, [("match Text.sorted(touched.map(|e| e.name.drop_prefix(\"compat-\"))) {", "match touched.map(|e| e.name.drop_prefix(\"compat-\")) {")], L0, "R-GC10: several ids are not sorted"),
    ("T15", T, [("Err(_) => JsonDoc.Null", 'Err(_) => JsonDoc.Text("")')], L0, "R-CV5: an unknown compat is an empty text"),
    ("T16", T, [("Ok(_) => Ok(Keep)", "Ok(_) => Ok(Set(facts.text))")], L0, "R-SO15: a set default is written again"),
    ("T17", T, [("((bytes + 50) // 100)", "(bytes // 100)")], L0, "R-NI6: the size is cut, not rounded"),
    ("T17b", T, [("((bytes + 50_000) // 100_000)", "(bytes // 100_000)")], L0, "R-NI6: the MB size is cut, not rounded"),
    ("T18", T, [("(Installed, Err(Unknown)) =>", "(_, Err(Unknown)) =>")], L0, "R-GC10: a present compiler has the compat warning"),
    ("T19", T, [('("installed", JsonDoc.Flag(facts.how == Installed))', '("installed", JsonDoc.Flag(Bool.True))')], L0, "R-J3: installed is always true"),
    ("C1", C, [("kind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: Yes,", "kind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: No,")], L0 + L2, "R-DL3: the default answer is No"),
    ("C2", C, [("\t\t\tkind: Default,\n\t\t\tshape: YesNo,\n\t\t\tdefault: Yes,\n\t\t\tquestion: \"Download", "\t\t\tkind: Consent,\n\t\t\tshape: YesNo,\n\t\t\tdefault: Yes,\n\t\t\tquestion: \"Download")], L0, "R-NM4: the prompt is a Consent prompt"),
    ("R1", R, [("	if has_dir(entries, typed) return Ok(present(roots, typed))\n", "")], L2, "R-CC4 step 1: no early exit for an installed id"),
    ("R2", R, [("	if has_dir(entries, ctx.id) return Ok({ how: Present, compat: Err(Unknown) })\n", "")], L2, "R-CC4 step 4: no check under the lock"),
    ("R3", R, [("fx.with_lock!(item, Wait, || install!", "fx.with_lock!(item, NoWait, || install!")], L2, "R-CC5: no wait for a busy lock"),
    ("R4", R, [("_ = fx.delete!(stale)", "_ = stale")], L2, "R-CC4 step 5: stale temps stay"),
    ("R5", R, [("Ok(argv) => match spawn_one!(fx, { argv, cwd", 'Ok(argv) => match spawn_one!(fx, { argv: argv.map(|a| if a == "0755" "0644" else a), cwd')], L2, "R-HF2: a wrong mode"),
    ("R6", R, [("	extract!(fx, ctx, p)?\n	set_executable!(fx, ctx, p)?\n", "	set_executable!(fx, ctx, p)?\n	extract!(fx, ctx, p)?\n")], L2, "R-HF2: chmod before the extract"),
    ("R7", R, [("		Present => Kept\n	}\n	Ok({ id, item, how: locked.how", "		Present => set_default!(fx, roots, id)?\n	}\n	Ok({ id, item, how: locked.how")], L2, "D11: the default is set for a present compiler"),
    ("R8", R, [("	Toolchain.check_download({ id: ctx.id, want: ctx.sha, got })?", "	_ = Toolchain.check_download({ id: ctx.id, want: ctx.sha, got })")], L2, "R-CV4: the hash is not checked"),
    ("R9", R, [("Installed => set_default!(fx, roots, id)?", "Installed => Kept")], L2, "R-SO15: the default is never set"),
    ("R10", R, [("if asked.answer == Yes Ok({}) else Err(", "if asked.answer == Yes or asked.answer == No Ok({}) else Err(")], L2, "R-NI6: a No is ignored"),
    ("R11", R, [("_ = fx.delete!([p.temp, p.probe_dir])\n			Err(fail)", "_ = fx.delete!([p.probe_dir])\n			Err(fail)")], L2 + L3, "R-CC2: the temp dir stays after a failure"),
    ("R12", R, [("	compat = learn_compat!(fx, ctx, p)?", "	compat = Err(Unknown)")], L2, "R-GC10: no compat check"),
    ("R13", R, [("	if args.offline return Err(Toolchain.offline_missing(id))\n", "")], L2, "R-DI12: --offline downloads"),
    ("R14", R, [("	if args.json {\n		fx.out!(Out.json_ok", "	if args.json or !args.json {\n		fx.out!(Out.json_ok")], L2, "R-J1: the envelope is always printed"),
    ("R15", R, [("	_ = fx.delete!([p.probe_dir])\n	Ok(Toolchain.learn_compat", "	Ok(Toolchain.learn_compat")], L2, "R-CC2: the probe dir stays"),
    ("R16", R, [("			_ = fx.delete!([p.archive])\n", "")], L2, "R-DA4: the archive stays"),
    ("R17", R, [("Ok(read.config.min_release_age ?? 172800)", "Ok(172800)")], L3, "R-C7: min-release-age is fixed"),
    ("R18", R, [("			second = read_text!(fx, path)?", "			second = first")], L2, "R-CC7: no second read before the write"),
    ("R19", R, [("	ask_download!(fx, args, env, { id, size: asset.size })?\n", "")], L2, "R-NI6: no prompt"),
    ("X1", X, [("AARCH64 => Arm64", "AARCH64 => X64")], ["l3:fx/ri-real"], "R-CV8: arm64 is x64"),
    ("X2", X, [("LINUX => Linux", "LINUX => Macos")], ["l3:fx/ri-real"], "R-CV8: linux is macos"),
    ("X3", X, [("Crypto.SHA256.hash(bytes).to_hex()", "Crypto.SHA256.hash(bytes.take_first(1)).to_hex()")], ["l3:fx/ri-real"], "R-CV4: the hash of other bytes"),
    ("S1", S, [('if [ "$OPT" = dev ]; then', "if true; then")], ["sh:scripts/test.sh selftest"], "TW26: WARN lines for OPT=speed"),
]


def restore():
    for f in FILES:
        with open(os.path.join(FINAL, f)) as src:
            text = src.read()
        with open(os.path.join(ROOT, f), "w") as dst:
            dst.write(text)


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + arg.split()
    elif kind == "l3":
        cmd = ["tests/run.sh"] + arg.split()
    else:
        cmd = arg.split()
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
        restore()
        path = os.path.join(ROOT, fname)
        text = open(path).read()
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            check = "cli/fxprobe.roc" if fname == X else "cli/lib/main.roc"
            built = subprocess.run([ROC, "check", check], cwd=ROOT, env=ENV, capture_output=True, text=True)
            if fname != S and built.returncode != 0:
                print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                continue
            caught_by = None
            for t in tests:
                failed, _ = run(t)
                if failed:
                    caught_by = t
                    break
            print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
    restore()
    same = all(open(os.path.join(ROOT, f)).read() == open(os.path.join(FINAL, f)).read() for f in FILES)
    print("SAME as code-final" if same else "DIFFERENT from code-final")


main()
