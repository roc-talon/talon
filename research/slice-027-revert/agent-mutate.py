#!/usr/bin/env python3
"""Revert check of the code agent for slice 027 (TW12). One small change of the code at a time, then only the layers that should catch it.
Before each mutation, all code files are restored from code-final/ (a kill is safe), and again after it. At the end the files are compared with code-final/.
Usage: python3 -I research/slice-027-revert/agent-mutate.py [id ...]   Output: one line per mutation, and agent-results.md (agent-results-partial.md with ids).
No full sweep: l0 is the file tests/unit/setup.roc, l2 the cases setup/, l3 the cases setup/st1 and fx/st1. Each run has a timeout."""
import os, shutil, subprocess, sys, filecmp

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-027-revert/code-final")
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=ROOT + "/.work/cache", ROC_CACHE_DIR=ROOT + "/.work/cache/roc", ROC=ROC)
SE = "cli/lib/Setup.roc"
ST = "cli/lib/SetupText.roc"
CO = "cli/lib/Consent.roc"
RF = "cli/RealFiles.roc"
FILES = [SE, ST, "cli/lib/SetupIo.roc", CO, RF, "cli/lib/main.roc"]

# id, file, old text, new text, layers that must catch it (l0, l2, l3). An empty layer text: no test is expected (a rule that the slice leaves untested).
M = [
    ("A01", SE, 'tln setup takes no operand, got ${many.len().to_str()}', 'tln setup takes no operand, got ${(many.len() + 1).to_str()}', "l0 l2"),
    ("A02", SE, 'if ["talon", "tln", "roc"].contains(tool)', 'if ["tln", "roc"].contains(tool)', "l0"),
    ("A03", SE, 'source: "${if name == "roc" "tln" else name}${ext}"', 'source: "${name}${ext}"', "l0 l2 l3"),
    ("A04", SE, 'Ok(home) => Ok(Text.join(home, ".local/bin"))', 'Ok(home) => Ok(Text.join(home, "bin"))', "l0 l2 l3"),
    ("A05", SE, '(Sha(want), Sha(have)) => if want == have Keep else Foreign', '(Sha(want), Sha(have)) => if want == have Keep else Keep', "l0 l2 l3"),
    ("A06", SE, '(Sha(_), _) => Foreign', '(Sha(_), _) => Keep', "l0"),
    ("A07", SE, '(Sha(_), Absent) => Make', '(Sha(_), Absent) => Keep', "l0 l2 l3"),
    ("A08", SE, 'before = parts.sublist({ start: 0, len: at })', 'before = parts.sublist({ start: 0, len: at + 1 })', "l0 l2 l3"),
    ("A09", SE, '"bash" => Ok(Bash)', '"bash" => Ok(Zsh)', "l0 l2 l3"),
    ("A10", SE, '_ => "export PATH=\\"${facts.dir}:\\$PATH\\" ${marker}"', '_ => "export PATH=\\"${facts.dir}:\\$PATH\\""', "l0 l2 l3"),
    ("A11", SE, 'Ok(text) => if text.contains(marker) Keep', 'Ok(text) => if text.contains(marker) and text.is_empty() Keep', "l0 l2 l3"),
    ("A12", ST, '"complete -F _tln tln",', '"complete -F _tln",', "l0 l2 l3"),
    ("A13", SE, 'newest: 1, can_recreate', 'newest: 2, can_recreate', "l0"),
    ("A14", SE, 'if row.entry.entry != exe_name(facts.os, "roc") {', 'if row.entry.entry != "zzz" {', "l2 l3"),
    ("A15", SE, 'if run.listed.data.contains(entry.source) and !$shas.any(|(name, _)| name == entry.source) {', 'if run.listed.data.contains(entry.source) {', "l2"),
    ("A16", SE, 'flag = if plan.replace_roc Ok(Yes) else Err(NoFlag)', 'flag = Err(NoFlag)', "l2 l3"),
    ("A17", SE, 'flag = if plan.no_modify_path Ok(No) else Err(NoFlag)', 'flag = Err(NoFlag)', "l2 l3"),
    ("A18", SE, 'Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag })?', 'Prompt.ask!(fx, prompt, { mode, yes: Bool.False, quiet: args.quiet, flag })?', "l3"),
    ("A19", SE, 'if !todo.is_empty() {', 'if !todo.is_empty() or !facts.bin.is_empty() {', "l2"),
    ("A20", SE, 'match fx.rename!({ from: roc_path(facts), to: old_path(facts) }) {', 'match fx.rename!({ from: old_path(facts), to: roc_path(facts) }) {', "l2 l3"),
    ("A21", SE, 'kind: Link, path: old_path(facts), now: run.now', 'kind: Link, path: roc_path(facts), now: run.now', "l2 l3"),
    ("A22", SE, 'Launch.toolchains!(fx, facts.roots).contains("link-system")', 'Launch.toolchains!(fx, facts.roots).contains("zzz")', "l3"),
    ("A23", SE, 'Ok(_) => HardLink', 'Ok(_) => Copy', "l2 l3"),
    ("A24", SE, 'Err(_) => match fx.copy_file!({ from, to: temp }) {', 'Err(_) => match fx.copy_file!({ from, to: target }) {', "l2"),
    ("A25", SE, 'temp = Temp.name({ target, hex: Temp.hex(fx.random!()) })', 'temp = Temp.name({ target, hex: Temp.hex(0) })', "l2"),
    ("A26", SE, 'if Setup.on_path({ path: SetupText.var_of(facts.env, "PATH"), dir: facts.bin }) return Ok(OnPath)', 'if Setup.on_path({ path: SetupText.var_of(facts.env, "PATH"), dir: facts.bin }) and facts.home.is_empty() return Ok(OnPath)', "l2 l3"),
    ("A27", SE, 'if !github.is_empty() {', 'if !github.is_empty() and facts.bin.is_empty() {', "l2 l3"),
    ("A28", SE, 'if answers.modify {\n\t\tmatch path {', 'if !answers.modify {\n\t\tmatch path {', "l2 l3"),
    ("A29", SE, 'Ok(text) if text == want => Ok(Present)', 'Ok(text) if text.is_empty() => Ok(Present)', "l2 l3"),
    ("A30", ST, 'moved = if done.moved [', 'moved = if !done.moved [', "l2 l3"),
    ("A31", SE, 'fx.out!(Out.json_ok({ command: args.typed, data: SetupText.data(done) }))', 'fx.err!(Out.json_ok({ command: args.typed, data: SetupText.data(done) }))', "l2"),
    ("A32", ST, '("roc_old", JsonDoc.Flag(done.moved))', '("roc_old", JsonDoc.Flag(Bool.False))', "l2"),
    ("A33", CO, '\t\tdefault: No,\n\t\tquestion: "${facts.path} is a roc', '\t\tdefault: Yes,\n\t\tquestion: "${facts.path} is a roc', "l2 l3"),
    ("A34", CO, '"moving ${facts.path} to ${facts.old}" else "keeping ${facts.path}"', '"moved ${facts.path} to ${facts.old}" else "keeping ${facts.path}"', "l2 l3"),
    ("A35", CO, '\t\tdefault: Yes,\n\t\tquestion: "Add ${facts.dir}', '\t\tdefault: No,\n\t\tquestion: "Add ${facts.dir}', "l2 l3"),
    ("A36", RF, '} else if exists!(to) {\n\t\t\tErr(Exists)\n\t\t} else if is_directory!(from) {\n\t\t\tErr(Other("is a directory"))\n\t\t} else {\n\t\t\tmatch Path.hard_link!', '} else if is_directory!(from) {\n\t\t\tErr(Other("is a directory"))\n\t\t} else {\n\t\t\tmatch Path.hard_link!', "l3"),
    ("A37", SE, 'if replace and facts.bin_names.contains(Setup.old_roc(facts.os)) {', 'if replace and facts.bin_names.contains("zzz") {', ""),
    ("A38", SE, 'Ok(first) => if first.verdict == NoSource {', 'Ok(first) => if first.verdict == Foreign {', ""),
    ("A39", SE, 'Prompt.ask!(fx, prompt, { mode: roc_answer.mode, yes', 'Prompt.ask!(fx, prompt, { mode, yes', ""),
]


def sh(cmd, timeout):
    try:
        return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(cmd, 124, "", "timeout")


def restore():
    for f in FILES:
        shutil.copy(os.path.join(FINAL, f), os.path.join(ROOT, f))


def run_layers(layers):
    """Returns the layers that failed."""
    failed = []
    if "l0" in layers:
        if sh(f"{ROC} test tests/unit/setup.roc --no-cache", 300).returncode != 0:
            failed.append("l0")
    if "l2" in layers:
        if sh("tests/commands/run.sh setup/", 300).returncode != 0:
            failed.append("l2")
    if "l3" in layers:
        b = sh(f"{ROC} build cli/main.roc --opt=dev --output=.work/mut/tln && {ROC} build cli/fxprobe.roc --opt=dev --output=.work/mut/fxprobe", 300)
        if b.returncode != 0:
            failed.append("l3(build)")
        elif sh("TLN=$PWD/.work/mut/tln tests/run.sh setup/st1 fx/st1", 300).returncode != 0:
            failed.append("l3")
    return failed


def main():
    want = sys.argv[1:]
    os.makedirs(os.path.join(ROOT, ".work/mut"), exist_ok=True)
    results = []
    for mid, path, old, new, layers in M:
        if want and mid not in want:
            continue
        restore()
        full = os.path.join(ROOT, path)
        original = open(full).read()
        if original.count(old) != 1:
            results.append((mid, "NOT APPLIED (%d matches)" % original.count(old), layers, ""))
            print(mid, "NOT APPLIED", flush=True)
            continue
        open(full, "w").write(original.replace(old, new, 1))
        try:
            check = sh(f"{ROC} check cli/main.roc", 300)
            if check.returncode != 0:
                results.append((mid, "DOES NOT COMPILE", layers, check.stdout[-200:].replace("\n", " ")))
                print(mid, "DOES NOT COMPILE", flush=True)
            else:
                # An untested rule (no layers): run all 3 layers and show which fail.
                failed = run_layers((layers or "l0 l2 l3").split())
                missing = [l for l in layers.split() if l not in failed]
                if not layers:
                    state = "caught (not expected)" if failed else "NOT CAUGHT (untested rule)"
                else:
                    state = "caught" if not missing else "NOT CAUGHT by " + " ".join(missing)
                results.append((mid, state, layers, " ".join(failed)))
                print(mid, state, "(failed:", " ".join(failed) + ")", flush=True)
        finally:
            restore()
    differ = [f for f in FILES if not filecmp.cmp(os.path.join(ROOT, f), os.path.join(FINAL, f), shallow=False)]
    print("files that differ from code-final:", differ or "none")
    out = "agent-results.md" if not want else "agent-results-partial.md"
    with open(os.path.join(ROOT, "research/slice-027-revert", out), "w") as f:
        f.write("| Id | Result | Layers that must catch it | Layers that failed |\n| --- | --- | --- | --- |\n")
        for mid, state, layers, failed in results:
            f.write(f"| {mid} | {state} | {layers} | {failed} |\n")


main()
