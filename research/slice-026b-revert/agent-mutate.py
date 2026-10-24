#!/usr/bin/env python3
"""Revert check of the code agent for slice 026b (TW12, filtered runs only, no full sweep).

For each mutation: restore cli/ from code-final/cli, make one small change in one file of cli/, `roc check`, then only the tests that should catch it.
The first test that fails ends the run of that mutation (CAUGHT). A test that runs longer than its timeout counts as CAUGHT (a loop).
cli/ is restored before and after each mutation, so a kill is safe. At the end `diff -r` compares cli/ with code-final/cli.

Usage: [ONLY=l0|l2|l3] python3 -I research/slice-026b-revert/agent-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed, what the change breaks.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-026b-revert/code-final/cli")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}
MA, PI, CO, LA, RU = "lib/Manage.roc", "lib/Pin.roc", "lib/Consent.roc", "lib/Ladder.roc", "lib/RocUse.roc"
L2 = "l2:roc/us1-use roc/us2-workspace roc/us3-step"
L3 = "l3:compilers/us1-use"

# (id, file under cli/, [(old, new)], [tests], what the change breaks)
M = [
    ("A01", MA, [("[one] => if is_local_build(one)", '[one] => if one.starts_with("git-") or one.starts_with("link-")')], ["l0:manage"], "R-U1: copy-* is taken"),
    ("A02", MA, [('		[] => Err(Fail.new(Usage, "tln roc use needs one compiler', '		[] => Err(Fail.new(Usage, "tln roc use needs a compiler')], ["l0:manage"], "R-CS1: text for no operand"),
    ("A03", MA, [("use_pinnable = |id| if Pin.is_id(id) Ok({}) else Err(use_refused(id))", "use_pinnable = |_id| Ok({})")], ["l0:manage", L2], "R-U1: a local build id from a prefix is a pin"),
    ("A04", MA, [("				Err(NoPin) => facts.fallback.map_err(|NoCompiler| Compiler.failure(NoCompiler))?", "				Err(NoPin) => facts.id")], ["l0:manage", L2], "R-BL1: a member with no pin has the new compiler as baseline"),
    ("A05", MA, [("				Ok(pin) => Pin.same_id(pin, facts.id)\n				Err(NoPin) => Bool.False", "				Ok(pin) => pin == facts.id\n				Err(NoPin) => Bool.False")], ["l0:manage", L2], "R-H1: the other tag form of the pin is a change"),
    ("A06", MA, [("use_report = |facts| if facts.files.is_empty() {", "use_report = |facts| if Bool.False and facts.files.is_empty() {")], ["l0:manage", L2], "Q7: the line for no member"),
    ("A07", MA, [('Ok(old) => ["${f.file}\\n", "  ~ roc: ${old}', 'Ok(old) => ["${f.file}\\n", "  + roc: ${old}')], ["l0:manage", L2], "R-OUT2: the line of a changed pin"),
    ("A08", MA, [('("build", if facts.built JsonDoc.Text("passed") else JsonDoc.Null),', '("build", JsonDoc.Text("passed")),')], ["l0:manage", L2], "R-J3: data.build for a package only"),
    ("A09", MA, [('("downloads", JsonDoc.Num(facts.downloads.to_i64_wrap())),', '("downloads", JsonDoc.Num(facts.probes.to_i64_wrap())),')], ["l0:manage", L2], "R-J3: data.downloads"),
    ("A10", MA, [('than the new pin ${facts.id}, so it still selects', 'than the new pin ${facts.id}, so it selects')], ["l0:manage", L2], "R-U6: the text of the note"),
    ("A11", PI, [("if Pin.is_nightly(facts.id) and !facts.nightly {", "if Bool.False and Pin.is_nightly(facts.id) and !facts.nightly {")], ["l0:pin", L2], "R-U5: the nightly switch is ignored"),
    ("A12", PI, [("if !Pin.admits({ req, id: facts.id, times: facts.times })", "if Bool.False and !Pin.admits({ req, id: facts.id, times: facts.times })")], ["l0:pin", L2], "R-U5: the range is ignored"),
    ("A13", PI, [("(Ok(req), Ok(text)) if !Pin.admits({ req, id: facts.id, times: facts.times })", "(Ok(req), Ok(text)) if !Pin.admits({ req, id: facts.id, times: [] })")], ["l0:pin", L2], "R-NS1: the gate orders nightlies of one day by the tag text"),
    ("A14", PI, [('Err(Fail.new(NoTuple, "tln roc use ${facts.id}: it is a nightly', 'Err(Fail.new(Usage, "tln roc use ${facts.id}: it is a nightly')], ["l0:pin", L2], "R-U5: the switch refusal is exit 2 (review: exit 10)"),
    ("A15", CO, [("			shape: YesNo,\n			default: Yes,\n			question: \"Download ${what}, ${size}:", "			shape: YesNo,\n			default: No,\n			question: \"Download ${what}, ${size}:")], ["l0:consent", L2], "R-DL3: the default of the prompt is No"),
    ("A16", CO, [('question: "Download ${what}, ${size}: ${Str.join_with(facts.ids, ", ")}?"', 'question: "Download ${what}: ${Str.join_with(facts.ids, ", ")}?"')], ["l0:consent", L2], "R-DL1: the prompt has no size"),
    ("A17", CO, [('kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"]),\n			shape: YesNo,\n			default: Yes,\n			question: "Download ${what}', 'kind: Default,\n			shape: YesNo,\n			default: Yes,\n			question: "Download ${what}')], ["l0:consent", L2], "R-NI5: the prompt answers itself with no person"),
    ("A18", LA, [("match $bases.find_first(|b| Pin.same_id(b.id, member.baseline)) {", "match $bases.find_first(|b| b.id == member.baseline) {")], [L2, L3], "R-CV1: a baseline in the other tag form of the new compiler starts again"),
    ("A19", LA, [("					$bases = $bases.append(fresh)\n", "")], [L2], "one start for each distinct baseline"),
    ("A20", LA, [("held: member.baseline, downloads: request.downloads })?", "held: request.held, downloads: request.downloads })?")], [L2, L3], "R-U3: the baseline check runs on the new compiler"),
    ("A21", LA, [("moved: [], downloads: request.downloads }", "moved: request.owners, downloads: request.downloads }")], [L2], "EQUIVALENT: moved owners (owners is [] in RocUse)"),
    ("A22", RU, [("	unpinned = loaded.members.keep_if(|m| m.locked.roc.is_err())", "	unpinned = loaded.members")], [L2, L3], "R-SO6: select! stops for a pinned member (mixed workspace)"),
    ("A23", RU, [("			Ok(id) => Ok(Ok(id))\n			Err(Unset) => Ok(ResolveBase.select!", "			Ok(_) => Ok(ResolveBase.select!(fx, request, { ..loaded, members: unpinned })?.selected.id)\n			Err(Unset) => Ok(ResolveBase.select!")], [L2, L3], "R-BL1: ROC_TOOLCHAIN is not the baseline of a member with no pin"),
    ("A24", RU, [("			Ok(id) => Ok(Present({ id: id }))\n			Err(NoMatch(_)) => RocInstall.offer!(fx, offer)", "			Ok(_) => RocInstall.offer!(fx, offer)\n			Err(NoMatch(_)) => RocInstall.offer!(fx, offer)")], [L2, L3], "R-U2: an installed prefix is not expanded"),
    ("A25", RU, [("	known = if toolchain.roc.is_ok() and !run.installed.is_empty()", "	known = if !run.installed.is_empty()")], [L2], "R-NS1: the times of installed compilers are read with no range"),
    ("A26", RU, [("		Download(offer) => known.append({ id: offer.id, published_at: offer.ctx.published_at })", "		Download(_) => known")], [L2], "R-NS1: the time of a new compiler from the list is not read"),
    ("A27", RU, [("	changes = rows.keep_if(|r| r.op.is_ok())", "	changes = rows")], [L2, L3], "R-H1: a member with the pin already is probed and written"),
    ("A28", RU, [("	Manage.use_pinnable(id)?\n", "")], [L2, L3], "R-U1: the id from a prefix is not checked"),
    ("A29", RU, [("keep_if(|id| !Pin.same_id(id, run.id) and Compiler.find(", "keep_if(|id| Compiler.find(")], [L2], "R-DL1: the new compiler is also a baseline download"),
    ("A30", RU, [("		Ok(id) => Compiler.require({ id, installed: ctx.installed, path: ctx.path_roc }).map_ok(|_| missing)", "		Ok(_) => Ok(missing)")], [L2], "R-NS2: a baseline that is not a nightly and not installed has no refusal"),
    ("A31", RU, [("		AutoNo => Err(Consent.download_refused(run.first))", "		AutoNo => Err(Consent.download_stop({ count: sum.ids.len(), size: sum.size }))")], [L2], "R-DL5: TALON_AUTO_INSTALL=no gives the stop of consent"),
    ("A32", RU, [("			flag = if decided == Install Ok(Yes) else Err(NoFlag)", "			flag = Err(NoFlag)")], [L2, L3], "R-DL5: the answer flag does not answer the prompt"),
    ("A33", RU, [("else Err(Consent.command_declined(sum.ids.first() ?? run.first))", "else Ok({})")], [L2], "R-NI5: the answer No downloads"),
    ("A34", RU, [("	mode = if want(ctx.mode) == NeedTty Mode.with_tty(ctx.mode, fx.tty!()) else ctx.mode", "	mode = ctx.mode")], [L2], "R-HF1: the terminal is not asked before the decision"),
    ("A35", RU, [("	all = new.concat($offers)", "	all = $offers.concat(new)")], [L2, L3], "R-CC4: the new compiler is not installed first"),
    ("A36", RU, [("				done = RocInstall.install_offer!(fx, d)?\n				if done.how == Installed {\n					$installed = $installed + 1\n				}", "				_ = RocInstall.install_offer!(fx, d)?\n				$installed = $installed + 1")], [L2], "EQUIVALENT: a compiler that another process installed counts as a download (not reachable with the fake Fx)"),
    ("A37", RU, [("new: Locked.edit({ path, text: now, ops })? })", "new: now })")], [L2, L3], "R-RP1: the files are written without the edit"),
    ("A38", RU, [("spans_now: Locked.spans({ text: now, ops }) })", "spans_now: Locked.spans({ text: read, ops }) })")], [L2, L3], "R-CC7: a header changed during the run is not detected"),
    ("A39", RU, [("		Ok(toolchain) if !done.written.is_empty() => [Manage.use_note", "		Ok(toolchain) => [Manage.use_note")], [L2], "R-U6: the note is printed for a run that wrote nothing"),
    ("A40", RU, [('		shown.out!("note: ${text}\\n")', '		shown.out!("${text}\\n")')], [L2, L3], "R-U6: the note has no prefix"),
    ("A41", RU, [("notes: done.notes.concat(note) })", "notes: done.notes })")], [L2, L3], "R-J3: the ROC_TOOLCHAIN note is not in data.notes"),
    ("A42", RU, [("probes: members.fold(0, |total, m| total + if m.kind == App 3 else 2),", "probes: members.fold(0, |total, _m| total + 2),")], [L2, L3], "R-J3: the count of probes"),
    ("A43", RU, [("	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?\n", "")], [L2, L3], "R-PD9: the project is not recorded"),
    ("A44", RU, [("		shown.out!(line)\n	}\n	note =", "		fx.out!(line)\n	}\n	note =")], [L2, L3], "R-J3: with --json the report goes to stdout"),
    ("A45", RU, [("	ran = Ladder.use!(fx, { roots: start.roots, now: start.now, path_roc: compiler, held: id,", "	ran = Ladder.use!(fx, { roots: start.roots, now: start.now, path_roc: compiler, held: text,")], [L2, L3], "R-U2: the ladder runs on the text of the operand, not the id"),
    ("B01", "lib/ResolveBase.roc", [("keep_if(|e| e.new != e.now)\n		if changed.is_empty() return Ok([])", "keep_if(|_e| Bool.True)\n		if changed.is_empty() return Ok([])")], ["l2:install/ remove/ roc/us1-use roc/us2-workspace", "l2:"], "R-H1: write_checked! writes a file whose text did not change"),
    ("B02", "lib/ResolveBase.roc", [("		if changed.is_empty() return Ok([])\n		match fx.write_atomic!", "		match fx.write_atomic!")], ["l2:install/ remove/ roc/us1-use roc/us2-workspace", "l2:"], "R-CC1: write_checked! calls write_atomic! with no file"),
    ("B03", "lib/ResolveBase.roc", [("ordered = Guard.check_all(run.files)?", "ordered = Guard.check_all(run.files.map(|f| { ..f, now: f.read, spans_now: f.spans_read }))?")], ["l2:install/ remove/ roc/us1-use roc/us2-workspace", "l2:", L3], "R-CC7: write_checked! does not see a change of a file during the run"),
    ("X01", "lib/Run.roc", [('RocUse.use!(fx, args)', '2')], [L2], "R-CS1: the command is not wired"),
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
                    print(f"{mid}: DID NOT COMPILE ({what}) " + (built.stdout + built.stderr)[:400].replace("\n", " "), flush=True)
                    continue
                caught_by = None
                only = os.environ.get("ONLY")
                for t in [x for x in tests if not only or x.startswith(only)]:
                    failed, _ = run(t)
                    if failed:
                        caught_by = t
                        break
                print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
            finally:
                restore()
    restore()


main()
