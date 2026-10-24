#!/usr/bin/env python3
"""Revert check of the private reference (TW12): each mutation changes one small thing in the reference code (which is in cli/ while this runs),
then runs the layers that should catch it. The file is put back after each one. Filtered runs only (no full sweep).
Usage: python3 -I research/slice-027-revert/mutate.py [id ...]   Output: one line per mutation, and results.md (results-partial.md with ids).
The reference must be in cli/ (`research/slice-027-revert/swap.sh ref`)."""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=ROOT + "/.work/cache", ROC_CACHE_DIR=ROOT + "/.work/cache/roc", ROC=ROC)
SE = "cli/lib/Setup.roc"
CO = "cli/lib/Consent.roc"
RF = "cli/RealFiles.roc"

# id, file, old text, new text, layers that must catch it (l0, l2, l3)
M = [
    ("M01", SE, 'tln setup takes no operand, got ${many.len().to_str()}', 'tln setup takes no operand, got ${(many.len() + 1).to_str()}', "l0 l2"),
    ("M02", SE, 'replace_roc: has_flag(args, "--replace-roc")', 'replace_roc: has_flag(args, "--no-modify-path")', "l0"),
    ("M03", SE, '["talon", "tln", "roc"].contains(name)', '["tln", "roc"].contains(name)', "l0"),
    ("M04", SE, 'Windows => ".exe"', 'Windows => ""', "l0"),
    ("M05", SE, '{ entry: "roc${ext}", source: tln }', '{ entry: "roc${ext}", source: "roc${ext}" }', "l0 l2 l3"),
    ("M06", SE, 'Windows => "roc.old.exe"', 'Windows => "roc.old"', "l0"),
    ("M07", SE, 'Ok(home) => Ok(Text.join(home, ".local/bin"))', 'Ok(home) => Ok(Text.join(home, "bin"))', "l0 l2 l3"),
    ("M08", SE, '"${home}\\\\.local\\\\bin"', '"${home}/.local/bin"', "l0"),
    ("M09", SE, 'Sha(got) => if got == want Keep else Foreign', 'Sha(got) => if got == want Keep else Keep', "l0 l2 l3"),
    ("M10", SE, 'Dir | Unreadable => Foreign', 'Dir | Unreadable => Keep', "l0"),
    ("M11", SE, 'Absent => Make', 'Absent => Keep', "l0 l2 l3"),
    ("M12", SE, 'path.split_on(":").keep_if(|part| !part.is_empty()).map(trim_slash)', 'path.split_on(":").keep_if(|part| !part.is_empty())', "l0"),
    ("M13", SE, 'Ok(i) => i < at', 'Ok(i) => i > at', "l0 l2 l3"),
    ("M14", SE, 'Err(NotFound) => Err(None)\n            Ok(at)', 'Err(NotFound) => match facts.found.first() {\n                Ok(file) => Ok(file)\n                Err(_) => Err(None)\n            }\n            Ok(at)', "l0 l3"),
    ("M15", SE, '"bash" => Ok(Bash)', '"bash" => Ok(Zsh)', "l0 l2 l3"),
    ("M16", SE, '".config/fish/conf.d/talon.fish"', '".config/fish/config.fish"', "l0 l2"),
    ("M17", SE, '_ => "export PATH=\\"${facts.dir}:\\$PATH\\" # talon: added by tln setup"', '_ => "export PATH=\\"${facts.dir}:\\$PATH\\" # added by tln"', "l0 l2 l3"),
    ("M18", SE, 'one.contains("# talon: added by tln setup")) Keep else', 'one.contains("# talon: added by tln setup") and one.is_empty()) Keep else', "l0 l2 l3"),
    ("M19", SE, 'Write("${text}${gap(text)}${line}\\n")', 'Write("${text}${line}\\n")', "l0 l2"),
    ("M20", SE, 'one.trim() == facts.dir', 'one.contains(facts.dir)', "l0"),
    ("M21", SE, 'Text.join(facts.home, ".local/share/bash-completion/completions/tln")', 'Text.join(facts.home, ".local/share/bash-completion/tln")', "l0 l2 l3"),
    ("M22", SE, '"complete -F _tln tln",', '"complete -F _tln",', "l0 l2 l3"),
    ("M23", SE, '"#compdef tln",', '"#compdef",', "l0 l2"),
    ("M24", SE, '["powershell", "-NoProfile", "-NonInteractive", "-Command", script]', '["powershell", "-NoProfile", "-Command", script]', "l0"),
    ("M25", SE, 'env: [("TALON_BIN_DIR", facts.dir)]', 'env: [("TALON_DIR", facts.dir)]', "l0"),
    ("M26", SE, "\"\\$old = \\$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')\"", "\"\\$old = \\$key.GetValue('Path', '', 'None')\"", "l0"),
    ("M27", SE, 'path: facts.path, text: facts.text, newest: 1, can_recreate', 'path: facts.path, text: facts.text, newest: 2, can_recreate', "l0"),
    ("M28", SE, 'Ok((_, JsonDoc.Obj(pairs))) => Ok(pairs.map(|(name, _)| name))', 'Ok((_, JsonDoc.Obj(pairs))) => Ok(pairs.drop_first(1).map(|(name, _)| name))', "l0 l2 l3"),
    ("M30", SE, 'if v.entry != "roc" {', 'if v.entry != "roc" or v.entry.count_utf8_bytes() > 0 {', "l2 l3"),
    ("M31", SE, 'if kept.contains(e.source) kept else kept.append(e.source)', 'if kept.contains(e.entry) kept else kept.append(e.source)', "l2"),
    ("M32", SE, 'Ok(file) => fx.err!("warning: ${file} comes before', 'Ok(_) => fx.err!("warning: x comes before', "l2 l3"),
    ("M34", SE, 'flag: if plan.replace_roc Ok(Yes) else Err(NoFlag) }', 'flag: Err(NoFlag) }', "l2 l3"),
    ("M35", SE, '{ mode, yes: args.yes, quiet: args.quiet, flag: if plan.replace_roc', '{ mode, yes: Bool.False, quiet: args.quiet, flag: if plan.replace_roc', "l3"),
    ("M36", SE, 'flag: if plan.no_modify_path Ok(No) else Err(NoFlag) }', 'flag: Err(NoFlag) }', "l2 l3"),
    ("M38", SE, 'if facts.verdicts.any(to_make) {', 'if facts.verdicts.any(to_make) and facts.bin.is_empty() {', "l2 l3"),
    ("M39", SE, 'match fx.rename!({ from: roc_path, to: facts.old }) {', 'match fx.rename!({ from: facts.old, to: roc_path }) {', "l2 l3"),
    ("M40", SE, 'path: old, now })', 'path: Text.dir_of(old), now })', "l2 l3"),
    ("M41", SE, 'Launch.toolchains!(fx, roots).contains("link-system")', 'Launch.toolchains!(fx, roots).contains("zzz")', "l3"),
    ("M43", SE, 'Ok(_) => HardLink', 'Ok(_) => Copy', "l2 l3"),
    ("M44", SE, 'Err(_) => match fx.copy_file!({ from: move.from, to: temp }) {', 'Err(_) => match fx.copy_file!({ from: move.from, to: move.to }) {', "l2"),
    ("M45", SE, 'temp = Temp.name({ target: move.to, hex: Temp.hex(fx.random!()) })', 'temp = Temp.name({ target: move.to, hex: Temp.hex(0) })', "l2"),
    ("M46", SE, 'if Setup.on_path({ path: facts.path_var, dir: facts.bin }) {', 'if Setup.on_path({ path: facts.path_var, dir: facts.bin }) and facts.home.is_empty() {', "l2 l3"),
    ("M47", SE, 'if !github.is_empty() {', 'if !github.is_empty() and facts.bin.is_empty() {', "l2 l3"),
    ("M48", SE, 'Needs(need) => if modify {', 'Needs(need) => if !modify {', "l2 l3"),
    ("M49", SE, 'Ok(text) if text == content => Ok(Present)', 'Ok(text) if text.is_empty() => Ok(Present)', "l2 l3"),
    ("M50", SE, 'moved = if done.moved_roc "moved', 'moved = if !done.moved_roc "moved', "l2 l3"),
    ("M51", SE, '        fx.out!(Out.json_ok({ command: args.typed, data: data(done) }))', '        fx.err!(Out.json_ok({ command: args.typed, data: data(done) }))', "l2"),
    ("M52", SE, '("roc_old", JsonDoc.Flag(done.moved_roc))', '("roc_old", JsonDoc.Flag(Bool.False))', "l2"),
    ("M53", SE, 'Ok((_, value)) => if value.is_empty() Err(Unset) else Ok(value)', 'Ok((_, value)) => Ok(value)', "l0"),
    ("M55", CO, 'default: Yes,\n        question: "Add ${facts.dir}', 'default: No,\n        question: "Add ${facts.dir}', "l2 l3"),
    ("M56", CO, 'default: No,\n        question: "${facts.path} is a roc', 'default: Yes,\n        question: "${facts.path} is a roc', "l2 l3"),
    ("M57", CO, '"moving ${facts.path} to ${facts.old}" else "keeping ${facts.path}"', '"moved ${facts.path} to ${facts.old}" else "keeping ${facts.path}"', "l2 l3"),
    ("M58", RF, 'if !exists!(from) {\n            Err(NotFound)\n        } else if exists!(to) {\n            Err(Exists)\n        } else if is_directory!(from) {\n            Err(Other("is a directory"))\n        } else {\n            match Path.hard_link!', 'if !exists!(from) {\n            Err(NotFound)\n        } else if is_directory!(from) {\n            Err(Other("is a directory"))\n        } else {\n            match Path.hard_link!', "l3"),
    ("M62", SE, 'match Text.last_segment(value) {', 'match value {', "l0 l2 l3"),
    ("M64", SE, '[Err(NotFound)] => Ok([])\n        other => Err(Fail.new(Environment, "cannot read ${path}: ${Str.inspect(other)}"))\n    }\n}\n\none_listing', '[Err(NotFound)] => Err(Fail.new(Environment, "no tools.json"))\n        other => Err(Fail.new(Environment, "cannot read ${path}: ${Str.inspect(other)}"))\n    }\n}\n\none_listing', "l2"),
    ("M65", SE, 'Err(NotFound) => Ok([])\n    Err(Denied) => Err(Fail.new(Environment, "cannot read ${dir}: permission denied"))', 'Err(NotFound) => Err(Fail.new(Environment, "no dir"))\n    Err(Denied) => Err(Fail.new(Environment, "cannot read ${dir}: permission denied"))', "l3"),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, **kw)


def run_layers(layers):
    """Returns the layers that failed."""
    failed = []
    if "l0" in layers:
        r = sh(f"{ROC} test tests/unit/setup.roc --no-cache")
        if r.returncode != 0:
            failed.append("l0")
    if "l2" in layers:
        r = sh("tests/commands/run.sh setup/")
        if r.returncode != 0:
            failed.append("l2")
    if "l3" in layers:
        b = sh(f"{ROC} build cli/main.roc --opt=dev --output=.work/mut/tln && {ROC} build cli/fxprobe.roc --opt=dev --output=.work/mut/fxprobe")
        if b.returncode != 0:
            failed.append("l3(build)")
        else:
            r = sh("TLN=$PWD/.work/mut/tln tests/run.sh setup/st1 fx/st1")
            if r.returncode != 0:
                failed.append("l3")
    return failed


def main():
    want = sys.argv[1:]
    os.makedirs(os.path.join(ROOT, ".work/mut"), exist_ok=True)
    results = []
    for mid, path, old, new, layers in M:
        if want and mid not in want:
            continue
        full = os.path.join(ROOT, path)
        original = open(full).read()
        old = old.replace("    ", "\t")
        new = new.replace("    ", "\t")
        if old not in original:
            results.append((mid, "NOT APPLIED", layers, ""))
            print(mid, "NOT APPLIED")
            continue
        shutil.copy(full, full + ".orig")
        open(full, "w").write(original.replace(old, new, 1))
        try:
            check = sh(f"{ROC} check cli/main.roc")
            if check.returncode != 0:
                results.append((mid, "DOES NOT COMPILE", layers, check.stdout[-300:].replace("\n", " ")))
                print(mid, "DOES NOT COMPILE")
            else:
                failed = run_layers(layers.split()) if layers else []
                missing = [l for l in layers.split() if l not in failed]
                state = "caught" if not missing and layers else ("not tested" if not layers else "NOT CAUGHT by " + " ".join(missing))
                results.append((mid, state, layers, " ".join(failed)))
                print(mid, state, "(failed:", " ".join(failed) + ")")
        finally:
            shutil.move(full + ".orig", full)
    out = "results.md" if not want else "results-partial.md"
    with open(os.path.join(ROOT, "research/slice-027-revert", out), "w") as f:
        f.write("| Id | Result | Layers that must catch it | Layers that failed |\n| --- | --- | --- | --- |\n")
        for mid, state, layers, failed in results:
            f.write(f"| {mid} | {state} | {layers} | {failed} |\n")


main()
