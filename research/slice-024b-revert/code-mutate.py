#!/usr/bin/env python3
"""Revert check of the code of slice 024b (TW12, filtered runs only, no full sweep).

For each mutation: one small change in one file of cli/, a `roc check`, then only the tests that should catch it. The first test that fails ends the run of that
mutation (CAUGHT). A test that runs longer than the timeout counts as CAUGHT (a loop). cli/ is restored from research/slice-024b-revert/code-final/ before and
after each mutation, so a kill is safe.

Usage: python3 -I research/slice-024b-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-024b-revert/code-final")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}
LINK, LAUNCH, RL = "lib/Link.roc", "lib/Launch.roc", "lib/RocLink.roc"
L2LINK, L2PROXY, L2PROBE = "l2:link/", "l2:proxy/lk2", "l2:probe/pb1"
L3LINK, L3FX = "l3:compilers/lk1-link-real", "l3:fx/lk1-real-fx-copy-file"

# (id, file under cli/, [(old, new)], [tests], what the change breaks)
M = [
    ("M01", LINK, [("				if force and !copy return Err(Fail.new(Usage, \"flag '--force' is not for 'roc link' without --copy\"))\n", "")], ["l0:link"], "R-FL12: --force with no --copy is accepted"),
    ("M02", LINK, [('id: if copy "copy-${name}" else "link-${name}"', 'id: if copy "link-${name}" else "copy-${name}"')], ["l0:link"], "R-R12, R-R13: the prefixes are swapped"),
    ("M03", LINK, [('	and !name.ends_with(".lock")\n', "")], ["l0:link"], "R-LY1: a name that ends in .lock"),
    ("M04", LINK, [("b != 92 and ", "")], ["l0:link"], "R-LY1: a name with a backslash"),
    ("M05", LINK, [('got ${many.len().to_str()} operands', 'got ${many.len().to_str()} operand')], ["l0:link"], "R-CM15: the text of the count"),
    ("M06", LINK, [("		Ok(_) => Ok(facts.full)", "		Ok(real) => Ok(real)")], ["l0:link", L3LINK], "R-LK4, Q5: the canonical path is used, not the absolute path"),
    ("M07", LINK, [('Err(NotFound) => Err(Fail.new(Usage, "no such file', 'Err(NotFound) => Err(Fail.new(Environment, "no such file')], ["l0:link"], "R-R12: no such file is exit 18"),
    ("M08", LINK, [("} else if facts.force {", "} else if !facts.force {")], ["l0:link"], "R-LK2: --force replaces only without the flag"),
    ("M09", LINK, [('Run: tln roc remove ${facts.id}"', 'Run: tln roc rm ${facts.id}"')], ["l0:link"], "R-LK2: the text of a link that exists"),
    ("M10", LINK, [('Link => "path"', 'Link => "source"')], ["l0:link"], "R-LK4: the key of a link"),
    ("M11", LINK, [("Clock.format_utc(facts.now)", "Clock.format_utc(0)")], ["l0:link"], "R-TF1: the time of .talon.json"),
    ("M12", LINK, [('if target.starts_with("/")', "if !target.is_empty()")], ["l0:link"], "R-LK4: a relative target path is accepted"),
    ("M13", LINK, [('Err(NotFound) => Err(Fail.new(Environment, "${facts.path}: the link', 'Err(NotFound) => Err(Fail.new(Input, "${facts.path}: the link')], ["l0:link"], "R-LK4: a link with no .talon.json is exit 19"),
    ("M14", LINK, [("newest: 1,", "newest: 9,")], ["l0:link"], "R-TF3: a newer format is read"),
    ("M15", LINK, [('"copied ${facts.path} to ${facts.id}\\n"', '"copied ${facts.path} to ${facts.id}"')], ["l0:link"], "R-OUT2: no line end"),
    ("M16", LINK, [('("replaced", JsonDoc.Flag(facts.replaced))', '("replaced", JsonDoc.Flag(Bool.False))')], ["l0:link"], "R-J3: replaced is never true"),
    ("M17", RL, [("fx.with_lock!(item, Wait,", "fx.with_lock!(item, NoWait,")], [L2LINK], "R-CC3, R-CC5: no wait for a busy lock"),
    ("M18", RL, [("	_ = fx.delete!([temp])\n	fail", "	_ = fx.delete!([\"${temp}.x\"])\n	fail")], [L2LINK], "R-CC1: a failed copy leaves the temp dir"),
    ("M19", RL, [("_ = fx.delete!([trash])", "_ = [trash]")], [L2LINK], "R-LK2: the trash dir stays after a replace"),
    ("M20", RL, [("	lexical = Text.resolve(fx.cwd!(), plan.path)", "	_ = fx.cwd!()\n	lexical = plan.path")], [L2LINK], "R-LK4: the path is not made absolute"),
    ("M21", RL, [("full: lexical, result: canonical", "full: canonical ?? lexical, result: canonical")], [L3LINK], "R-LK4, Q5: the recorded path is the canonical path"),
    ("M22", RL, [("now = Clock.now!(fx, env)?", "now = 0")], [L2LINK], "R-EV22: no clock call"),
    ("M23", RL, [("	if args.json {\n		fx.out!", "	if !args.json {\n		fx.out!")], [L2LINK], "R-J3: the envelope is written without --json"),
    ("M24", RL, [("shown = Install.shown_fx(fx, args)", "shown = fx")], [L2LINK], "R-FL4: --quiet does not hide the line"),
    ("M25", RL, [("kind_of = |plan| if plan.copy Copy else Link", "kind_of = |plan| if plan.copy Link else Copy")], [L2LINK], "R-LK4, R-LK2: the kinds are swapped"),
    ("M26", RL, [("Ok(mode == Replace)", "Ok(Bool.False)")], [L2LINK], "R-J3: replaced is never true"),
    ("M27", RL, [("fx.rename!({ from: work.item, to: trash })", 'fx.rename!({ from: work.item, to: "${trash}x" })')], [L2LINK], "R-CC10: the old dir goes to another trash name"),
    ("M28", LAUNCH, [('if run.id.starts_with("link-") and run.installed', "if run.installed")], [L2PROXY, L2PROBE], "R-LK4: a read of .talon.json for any id"),
    ("M29", LAUNCH, [('if run.id.starts_with("link-") and run.installed', 'if run.id.starts_with("lonk-") and run.installed')], [L2PROXY], "R-LK4, R-R5: the proxy never reads the link"),
    ("M30", LAUNCH, [('if run.id.starts_with("link-") and run.installed.contains(run.id) {', 'if run.id.starts_with("link-") {')], [L2PROXY, L2PROBE], "D13: a read for a link that is not installed"),
    ("M39", "lib/Clock.roc", [("			Ok((_, text)) => Ok(text)\n			Err(_) => Err(NotSet)\n		}\n		match Clock.now", "			Ok((_, _)) => Err(NotSet)\n			Err(_) => Err(NotSet)\n		}\n		match Clock.now")], [L2LINK], "R-EV22: Clock.now! ignores TALON_NOW"),
    ("M40", "lib/Clock.roc", [('Err(BadTime(text)) => Err(Fail.new(Usage, "TALON_NOW is not', 'Err(BadTime(text)) => Err(Fail.new(Environment, "TALON_NOW is not')], [L2PROXY, "l2:proxy/px"], "R-EV22: a bad TALON_NOW is not exit 2"),
    ("M41", "lib/Fx.roc", [("fx.with_lock!(item, Wait, body!)", "fx.with_lock!(item, NoWait, body!)")], [L2LINK, "l2:roc/"], "R-CC5: Fx.locked! does not wait"),
    ("M42", "lib/Fx.roc", [("		Err(Failed(fail)) => Err(fail)\n		Err(Busy) => Err(Fail.new(Internal, \"the lock of ${item} was not taken\"))", "		Err(Failed(fail)) => Err(Fail.new(Internal, fail.message))\n		Err(Busy) => Err(Fail.new(Internal, \"the lock of ${item} was not taken\"))")], [L2LINK], "Fx.locked! changes the kind of a failure of the body"),
    ("M31", "lib/Pin.roc", [("Ok(id) if can_write and is_compiler_id(id) =>", "Ok(id) if can_write =>")], ["l0:pin", L2PROBE], "R-R4, R-LK3: a local build is written as the pin"),
    ("M32", "lib/Args.roc", [('"--copy" => cmd == "roc link"', '"--copy" => Bool.True')], ["l0:args"], "R-FL12: --copy for every command"),
    ("M33", "lib/Args.roc", [('		"--copy" => cmd == "roc link"\n', "")], ["l0:args", L2LINK], "R-FL12: --copy is not a flag of roc link"),
    ("M34", "RealFiles.roc", [("		} else if exists!(to) {\n			Err(Exists)\n		} else if is_directory!(from) {", "		} else if is_directory!(from) {")], [L3FX], "R-LK2: a target that exists is replaced"),
    ("M35", "RealFiles.roc", [("			_ = Path.create_all!(Path.utf8(Text.dir_of(move.to)))\n			match Path.copy!(from, to) {", "			match Path.copy!(from, to) {")], [L3FX, L3LINK], "R-R13: no parent dirs of the target"),
    ("M36", "RealFiles.roc", [("} else if is_directory!(from) {\n			Err(Other", "} else if is_directory!(to) {\n			Err(Other")], [L3FX], "R-R13: a directory as source is not found"),
    ("M37", "RealFiles.roc", [("Err(Other(\"is a directory\"))", "Err(Other(\"is a dir\"))")], [L3FX], "the text of the error of a directory"),
    ("M38", "RealFiles.roc", [("	Ok(real) => match Path.is_dir!(real) {", "	Ok(_) => match Path.is_dir!(path) {")], [L3FX], "R-LK2: a link to a directory is not seen as a directory"),
]


def restore():
    shutil.copytree(FINAL, os.path.join(ROOT, "cli"), dirs_exist_ok=True)


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + arg.split()
    else:
        cmd = ["tests/run.sh"] + arg.split()
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
        path = os.path.join(ROOT, "cli", fname)
        orig = open(path).read()
        text = orig
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
            try:
                built = subprocess.run([ROC, "check", "cli/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
                if built.returncode != 0:
                    print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                    continue
                caught_by = None
                for t in tests:
                    failed, _ = run(t)
                    if failed:
                        caught_by = t
                        break
                print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
            finally:
                restore()
    restore()


main()
