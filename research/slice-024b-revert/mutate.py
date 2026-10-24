#!/usr/bin/env python3
"""Revert check of the private reference (TW12): each mutation changes one small thing in the reference code (which is in cli/ while this runs),
then runs the layers that should catch it. The file is put back after each one. Filtered runs only (no full sweep).
Usage: python3 -I research/slice-024b-revert/mutate.py [id ...]   Output: one line per mutation, and results.md.
The reference must be in cli/ (research/slice-024b-revert/reference/): it is deleted after the review, so this script then cannot run again."""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=ROOT + "/.work/cache", ROC_CACHE_DIR=ROOT + "/.work/cache/roc", ROC=ROC)
LINK = "cli/lib/Link.roc"
RL = "cli/lib/RocLink.roc"
LA = "cli/lib/Launch.roc"
PX = "cli/lib/Proxy.roc"
LD = "cli/lib/Ladder.roc"
PIN = "cli/lib/Pin.roc"
ARGS = "cli/lib/Args.roc"
RF = "cli/RealFiles.roc"

BYTES = """match Path.read_bytes!(from) {
						Ok(bytes) => match Path.write_bytes!(to, bytes) {
							Ok(_) => Ok({})
							Err(PathErr(failed, _)) => Err(RealBase.file_err(failed))
						}
						Err(PathErr(failed, _)) => Err(RealBase.file_err(failed))
					}"""

# id, file, old text, new text, layers that must catch it (l0, l2, l3)
M = [
    ("M01", LINK, 'id: if copy "copy-${name}" else "link-${name}"', 'id: if copy "link-${name}" else "link-${name}"', "l0 l2 l3"),
    ("M02", LINK, "if force and !copy {", "if force and !copy and name.is_empty() {", "l0"),
    ("M03", LINK, '!name.ends_with(".lock") and ', "", "l0"),
    ("M04", LINK, '!name.contains("\\\\") and ', "", "l0"),
    ("M05", LINK, "got ${many.len().to_str()} operands", "got ${(many.len() + 1).to_str()} operands", "l0"),
    ("M06", LINK, 'Err(NotFound) => Err(Fail.new(Usage, "no such file: ${facts.typed}"))', 'Err(NotFound) => Err(Fail.new(Environment, "no such file: ${facts.typed}"))', "l0"),
    ("M07", LINK, "} else if facts.copy and facts.force {", "} else if facts.copy {", "l0"),
    ("M08", LINK, 'Err(Fail.new(Usage, "${facts.id} exists. Run: tln roc remove ${facts.id}"))', 'Err(Fail.new(Usage, "${facts.id} exists. Use --force to replace it."))', "l0"),
    ("M09", LINK, "Copy => \"source\"", "Copy => \"path\"", "l0 l2 l3"),
    ("M10", LINK, "JsonDoc.Text(Clock.format_utc(facts.now))", "JsonDoc.Text(Clock.format_utc(0))", "l0 l2 l3"),
    ("M11", LINK, 'Ok((_, Text(path))) if path.starts_with("/") => Ok(path)', 'Ok((_, Text(path))) if !path.is_empty() => Ok(path)', "l0"),
    ("M12", LINK, "newest: 1, can_recreate", "newest: 2, can_recreate", "l0 l2"),
    ("M13", LINK, 'Err(NotFound) => Err(Fail.new(Environment, "${facts.path}: the link', 'Err(NotFound) => Err(Fail.new(Input, "${facts.path}: the link', "l0 l2"),
    ("M14", LINK, 'Copy => ["copied ${facts.path} to ${facts.id}\\n"]', 'Copy => ["copied ${facts.id} to ${facts.path}\\n"]', "l0 l2 l3"),
    ("M15", LINK, '("replaced", JsonDoc.Flag(facts.replaced))', '("replaced", JsonDoc.Flag(Bool.False))', "l0 l2"),
    ("M16", RL, "fx.with_lock!(item, Wait, ||", "fx.with_lock!(item, NoWait, ||", "l2"),
    ("M17", RL, "Err(fail) => {\n\t\t\t_ = fx.delete!([temp])\n\t\t\treturn Err(fail)", "Err(fail) => {\n\t\t\treturn Err(fail)", "l2"),
    ("M18", RL, "\tif replace {\n\t\tmatch fx.rename!({ from: run.item, to: trash })", "\tif replace and run.item.is_empty() {\n\t\tmatch fx.rename!({ from: run.item, to: trash })", "l2"),
    ("M19", RL, "\tif replace {\n\t\t_ = fx.delete!([trash])", "\tif replace and run.item.is_empty() {\n\t\t_ = fx.delete!([trash])", "l2"),
    ("M20", LINK, "Ok(_) => Ok(facts.full)", "Ok(path) => Ok(path)", "l0 l3"),
    ("M21", RL, "now = clock_now!(fx, env)?", "now = 0", "l2 l3"),
    ("M22", RL, "if args.json {", "if args.json and args.typed.is_empty() {", "l2 l3"),
    ("M23", RL, "shown = Install.shown_fx(fx, args)", "shown = fx", "l2"),
    ("M24", RL, "answer = match fx.canonical!([full]) {", "answer = match [Ok(full)] {", "l2 l3"),
    ("M25", RL, "kind = if plan.copy Copy else Link", "kind = Link", "l2 l3"),
    ("M26", LA, 'program! = |fx, run| if run.id.starts_with("link-") and', 'program! = |fx, run| if run.id.starts_with("linx-") and', "l2 l3"),
    ("M27", LA, 'if run.id.starts_with("link-") and run.installed.contains(run.id) {', 'if (run.id.starts_with("link-") or run.id.starts_with("copy-")) and run.installed.contains(run.id) {', "l2"),
    ("M28", PX, "\tprogram = Launch.program!(fx, { roots, id, installed: have, path: on_path })?\n\tif !off and have.contains(id) {\n\t\tLaunch.touch!(fx, roots, { id, now })\n\t}", "\tif !off and have.contains(id) {\n\t\tLaunch.touch!(fx, roots, { id, now })\n\t}\n\tprogram = Launch.program!(fx, { roots, id, installed: have, path: on_path })?", "l2"),
    ("M29", PX, "program = Launch.program!(fx, { roots, id, installed: have, path: on_path })?", "program = Launch.program({ roots, id, installed: have, path: on_path })", "l2 l3"),
    ("M30", LD, "program = Launch.program!(fx, { roots: run.roots, id, installed, path: run.path_roc })?", "program = Launch.program({ roots: run.roots, id, installed, path: run.path_roc })", "l2"),
    ("M31", PIN, "Ok(id) if can_write and is_compiler_id(id) => facts.members", "Ok(id) if can_write => facts.members", "l0 l2"),
    ("M32", ARGS, '"--copy" => cmd == "roc link"', '"--copy" => cmd != ""', "l0"),
    ("M33", ARGS, '"--copy" => cmd == "roc link"', '"--copy" => cmd == "roc linx"', "l0 l2 l3"),
    ("M34", RF, "} else if exists!(to) {\n\t\t\tErr(Exists)\n\t\t} else {\n\t\t\tmatch Path.is_dir!(from)", "} else if exists!(to) and exists!(Path.utf8(\"/no/such\")) {\n\t\t\tErr(Exists)\n\t\t} else {\n\t\t\tmatch Path.is_dir!(from)", "l3"),
    ("M35", RF, "match Path.copy!(from, to) {\n\t\t\t\t\t\tOk(_) => Ok({})\n\t\t\t\t\t\tErr(CopyErr(failed)) => Err(RealBase.file_err(failed.error))\n\t\t\t\t\t}", BYTES, "l3"),
    ("M36", RF, "_ = Path.create_all!(Path.utf8(Text.dir_of(move.to)))\n\t\t\t\t\tmatch Path.copy!", "match Path.copy!", "l3"),
    ("M37", RF, "Ok(Bool.True) => Err(Other(\"is a directory\"))\n\t\t\t\t_ => {\n\t\t\t\t\t_ = Path.create_all", "Ok(Bool.True) => Err(Other(\"is a dir\"))\n\t\t\t\t_ => {\n\t\t\t\t\t_ = Path.create_all", "l3"),
    ("M38", RL, "Ok({}) => {}\n\t\tErr(fail) => {\n\t\t\t_ = fx.delete!([temp])", "Ok({}) => {}\n\t\tErr(fail) => {\n\t\t\t_ = fx.delete!([Text.join(temp, \"x\")])", "l2"),
    ("M39", RL, "answer = match fx.canonical!([full]) {", "answer = match fx.canonical!([plan.path]) {", "l2"),
    ("M40", RL, "full = Text.resolve(cwd, plan.path)", "full = \"${cwd}/${plan.path}\"", "l3"),
    ("M41", LINK, "Ok(_) => Ok(facts.full)", "Ok(_) => Ok(facts.typed)", "l0 l2 l3"),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, **kw)


def run_layers(layers):
    """Returns the layers that failed."""
    failed = []
    if "l0" in layers:
        r = sh(f"{ROC} test tests/unit/link.roc; a=$?; {ROC} test tests/unit/pin.roc; b=$?; {ROC} test tests/unit/args.roc; c=$?; [ $a = 0 ] && [ $b = 0 ] && [ $c = 0 ]")
        if r.returncode != 0:
            failed.append("l0")
    if "l2" in layers:
        r = sh("tests/commands/run.sh link/lk1-link proxy/lk2-run-link probe/pb1-ladder")
        if r.returncode != 0:
            failed.append("l2")
    if "l3" in layers:
        b = sh(f"{ROC} build cli/main.roc --opt=dev --output=.work/mut/tln && {ROC} build cli/fxprobe.roc --opt=dev --output=.work/mut/fxprobe")
        if b.returncode != 0:
            failed.append("l3(build)")
        else:
            r = sh("TLN=$PWD/.work/mut/tln tests/run.sh compilers/lk1-link-real fx/lk1-real-fx-copy-file")
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
    with open(os.path.join(ROOT, "research/slice-024b-revert", out), "w") as f:
        f.write("| Id | Result | Layers that must catch it | Layers that failed |\n| --- | --- | --- | --- |\n")
        for mid, state, layers, failed in results:
            f.write(f"| {mid} | {state} | {layers} | {failed} |\n")


main()
