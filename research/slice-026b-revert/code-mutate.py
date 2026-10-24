#!/usr/bin/env python3
"""Revert check of the code of slice 026b (TW12, filtered runs only, no full sweep).

For each mutation: one small change in one file of cli/, a `roc check`, then only the tests that should catch it. The first test that fails ends the run of that
mutation (CAUGHT). A test that runs longer than the timeout counts as CAUGHT (a loop). cli/ is restored from research/slice-026b-revert/reference/cli before and
after each mutation, so a kill is safe.

Usage: [ONLY=l0|l2|l3] python3 -I research/slice-026b-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-026b-revert/reference/cli")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}
MA, PI, CO, LA, RU = "lib/Manage.roc", "lib/Pin.roc", "lib/Consent.roc", "lib/Ladder.roc", "lib/RocUse.roc"
L2 = "l2:roc/us1-use roc/us2-workspace roc/us3-step"
L3 = "l3:compilers/us1-use"

# (id, file under cli/, [(old, new)], [tests], what the change breaks)
M = [
    ("M01", MA, [("					Ok(id) => id\n					Err(NoCompiler) => return", "					Ok(_) => facts.id\n					Err(NoCompiler) => return")], ["l0:manage", L2], "R-BL1: a member with no pin has the new compiler as baseline"),
    ("M02", MA, [("				Ok(pin) => pin\n				Err(NoPin) => match facts.fallback", "				Ok(_) => facts.id\n				Err(NoPin) => match facts.fallback")], ["l0:manage", L2], "R-U3: the baseline is the new compiler, not the old pin"),
    ("M03", MA, [("Ok(pin) if Pin.same_id(pin, facts.id) => Err(Same)", "Ok(pin) if pin == facts.id => Err(Same)")], ["l0:manage", L2], "R-H1: the other tag form of the pin is a change"),
    ("M04", MA, [("			Git | Link | Copy => Err(use_refused(one))\n			Nightly | Release => Ok(one)", "			Git | Link => Err(use_refused(one))\n			Copy | Nightly | Release => Ok(one)")], ["l0:manage"], "R-U1: copy-* is taken"),
    ("M05", MA, [('"tln roc use takes one compiler, got ${many', '"tln roc use takes one compiler: ${many')], ["l0:manage"], "R-CS1: text for 2 operands"),
    ("M06", MA, [("use_pinnable = |id| if Pin.is_id(id) Ok({}) else Err(use_refused(id))", "use_pinnable = |_id| Ok({})")], ["l0:manage", L2], "R-U1: a local build id is a pin"),
    ("M07", MA, [('so it still selects the compiler. The pin is used when ROC_TOOLCHAIN is not set."\n', 'so it selects the compiler. The pin is used when ROC_TOOLCHAIN is not set."\n')], ["l0:manage", L2], "R-U6: the text of the note"),
    ("M08", MA, [('		lines.append("the roc pin is now ${facts.id}\\n")', "		lines")], ["l0:manage", L2], "R-OUT2: no final line"),
    ("M09", MA, [('"  ~ roc: ${old} -> ${facts.id}\\n"', '"  + roc: ${old} -> ${facts.id}\\n"')], ["l0:manage", L2], "R-OUT2: the line of a changed pin"),
    ("M10", MA, [('("previous", text_or_null(f.previous.map_err(|NoPin| None))),', '("previous", JsonDoc.Null),')], ["l0:manage", L3], "R-J3: data.previous is null"),
    ("M11", MA, [('("build", if facts.built JsonDoc.Text("passed") else JsonDoc.Null),', '("build", JsonDoc.Text("passed")),')], ["l0:manage", L2], "R-J3: data.build for a package only"),
    ("M12", PI, [("if Pin.is_nightly(facts.id) and !facts.nightly {", "if Bool.False and Pin.is_nightly(facts.id) and !facts.nightly {")], ["l0:pin", L2], "R-U5: the nightly switch is ignored"),
    ("M13", PI, [("Ok(req) if !Pin.admits({ req, id: facts.id, times: facts.times }) => {\n					shown", "Ok(req) if Bool.False and !Pin.admits({ req, id: facts.id, times: facts.times }) => {\n					shown")], ["l0:pin", L2], "R-U5: the range is ignored"),
    ("M14", PI, [('Use a release, or change the nightly switch. ${keep}"', 'Use a release, or change the nightly switch."')], ["l0:pin", L2], "R-U5: the switch text has no hint on talon.toml"),
    ("M15", CO, [("			shape: YesNo,\n			default: Yes,\n			question: \"Download ${what}, ${size}:", "			shape: YesNo,\n			default: No,\n			question: \"Download ${what}, ${size}:")], ["l0:consent", L2], "R-DL3: the default of the prompt is No (review: Yes)"),
    ("M16", CO, [('kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"]),\n			shape: YesNo,\n			default: Yes,\n			question: "Download ${what}', 'kind: Required(["--yes"]),\n			shape: YesNo,\n			default: Yes,\n			question: "Download ${what}')], ["l0:consent", L2], "R-DL3: the ways of the stop"),
    ("M17", CO, [('question: "Download ${what}, ${size}: ${Str.join_with(facts.ids, ", ")}?"', 'question: "Download ${what}: ${Str.join_with(facts.ids, ", ")}?"')], ["l0:consent", L2], "R-DL1: the prompt has no size"),
    ("M18", RU, [("	free = first.members.keep_if(|m| m.locked.roc.is_err())", "	free = first.members")], [L2, L3], "R-BL1: select! stops for a member with a pin"),
    ("M19", RU, [("if found.contains(b) or Pin.same_id(b, id) found else", "if found.contains(b) found else")], [L2, L3], "R-DL1: the new compiler is also a baseline"),
    ("M20", RU, [("	changing = plan.keep_if(|row| row.op.is_ok())", "	changing = plan")], [L2, L3], "R-H1: a member with the pin already is probed and written"),
    ("M21", RU, [("probes: members.fold(0, |total, m| total + if m.kind == App 3 else 2),", "probes: members.fold(0, |total, _m| total + 2),")], [L2, L3], "R-J3: the count of probes"),
    ("M22", RU, [("downloads: downloads + ran.downloads,", "downloads: 0 * downloads + ran.downloads,")], [L2, L3], "R-J3: the count of downloads"),
    ("M23", RU, [("		Ok(t) => [Manage.use_note({ toolchain: t, id })]", "		Ok(_) => []")], [L2, L3], "R-U6: no note for ROC_TOOLCHAIN"),
    ("M24", RU, [("			Ok(id) => Ok(Present({ id: id }))", "			Ok(_) => RocInstall.offer!(fx, { id: facts.text, env: facts.env, offline: args.offline })")], [L2, L3], "R-U2: an installed prefix is not expanded"),
    ("M25", RU, [("		([only], []) => {\n			RocInstall.ask_download!(fx, args, facts.env, { id: only, size })?\n		}", "		([_], []) => {}")], [L2, L3], "R-NI6: no prompt for the named download"),
    ("M26", RU, [("		AutoNo => Err(Consent.download_refused(facts.first_base))", "		AutoNo => Err(Consent.download_stop({ count: facts.ids.len(), size: facts.size }))")], [L2, L3], "R-DL5: TALON_AUTO_INSTALL=no gives the stop of consent"),
    ("M27", RU, [("			if asked.answer == Yes Ok({}) else Err(Consent.command_declined(facts.first_base))", "			if asked.answer == Yes Ok({}) else Ok({})")], [L2, L3], "R-NI5: the answer No downloads"),
    ("M28", RU, [("	all = facts.new.concat(facts.base)", "	all = facts.base.concat(facts.new)")], [L2, L3], "R-CC4: the new compiler is not installed first"),
    ("M29", RU, [("		Ok(t) => Ok(t)\n		Err(Unset) => loaded.selected.id", "		Ok(_) => loaded.selected.id\n		Err(Unset) => loaded.selected.id")], [L2, L3], "R-SO14: ROC_TOOLCHAIN is not the baseline of a member with no pin (select! does not give an id that is not installed)"),
    ("M30", RU, [("allow: allow_flag(args), probe: Err(NoFlag)", "allow: Err(NoFlag), probe: Err(NoFlag)")], [L2, L3], "EQUIVALENT: consent! reads the flag itself, the request flag is for the ladder downloads, which find the compilers installed"),
    ("M31", RU, [("downloads: { auto: Consent.auto_install(start.env),", "downloads: { auto: Ask,")], [L2, L3], "EQUIVALENT: same reason as M30"),
    ("M32", RU, [("	Manage.use_pinnable(id)?\n", "")], [L2, L3], "R-U1: the id from a prefix is not checked (not reachable by a prefix)"),
    ("M33", RU, [("nightly: settings.nightly, source", "nightly: Bool.True, source")], [L2, L3], "R-U5: the switch of the run is not passed to the gate"),
    ("M34", RU, [("req: loaded.intent.toolchain.roc, req_text", "req: Err(Unset), req_text")], [L2, L3], "R-U5: the range is not passed to the gate"),
    ("M35", RU, [('		shown.out!("note: ${note}\\n")', '		shown.out!("${note}\\n")')], [L2, L3], "R-U6: the note has no prefix"),
    ("M36", RU, [("built: members.any(|m| m.kind == App),", "built: Bool.True,")], [L2, L3], "R-J3: data.build"),
    ("M37", RU, [("	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?", "	_ = Bool.True")], [L2, L3], "R-PD9: the project is not recorded"),
    ("M38", RU, [("		$edited = $edited.append({ path, new: Locked.edit({ path, text: now, ops })? })", "		$edited = $edited.append({ path, new: now })")], [L2, L3], "R-RP1: the files are written without the edit"),
    ("M39", RU, [("times: installed_times.concat(new_times) })?", "times: installed_times.concat(new_times).keep_if(|_| Bool.False) })?")], [L2], "R-NS1: the gate orders two nightlies of one day by the tag text"),
    ("M40", PI, [('Err(Fail.new(NoTuple, "tln roc use ${facts.id}: it is a nightly', 'Err(Fail.new(Usage, "tln roc use ${facts.id}: it is a nightly')], ["l0:pin", L2], "R-U5: the switch refusal is exit 2 (review: exit 10)"),
    ("M41", PI, [('Err(Fail.new(NoTuple, "tln roc use ${facts.id}: it is outside', 'Err(Fail.new(Usage, "tln roc use ${facts.id}: it is outside')], ["l0:pin", L2], "R-U5: the range refusal is exit 2 (review: exit 10)"),
    ("M42", RU, [("	if changing.is_empty() {", "	if Bool.False and changing.is_empty() {")], [L2], "Q7: a run with no change probes and downloads"),
    ("M43", MA, [("use_report = |facts| if facts.files.is_empty() [", "use_report = |facts| if Bool.False and facts.files.is_empty() [")], ["l0:manage"], "Q7: the line for no member"),
    ("M44", RU, [("		Download(found) => [{ id: found.id, published_at: found.ctx.published_at }]", "		Download(_) => no_times")], [L2], "R-NS1: the time of a new compiler from the list is not read"),
    ("L01", LA, [("compiler: if other base.id else compiler, timeout })?", "compiler, timeout })?")], [L2, L3], "R-BL1: the baseline is parsed with the compiler of the candidate"),
    ("L02", LA, [("	other = base.id != started.id\n", '	other = base.id == ""\n')], [L2, L3], "R-U3: the baseline check runs on the new compiler"),
    ("L03", LA, [("	if run.base.id != run.started.id and run.base.installed.contains(run.base.id) {", "	if Bool.False and run.base.installed.contains(run.base.id) {")], [L2, L3], "R-CC9: the baseline compiler has no .last-use"),
    ("L04", LA, [("match $bases.find_first(|b| b.id == member.baseline) {", 'match $bases.find_first(|b| b.id == "") {')], [L2], "one start for each distinct baseline"),
    ("L05", LA, [("						$downloads = $downloads + one.downloads\n", "")], [L2, L3], "EQUIVALENT: the compilers are installed before the ladder, so Start.run! downloads 0"),
    ("L06", LA, [("			base = if member.baseline == request.held {\n				started", '			base = if member.baseline == "" {\n				started')], [L2], "a baseline that is the new compiler starts twice"),
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
