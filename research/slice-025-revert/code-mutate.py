#!/usr/bin/env python3
"""Revert check of the code of slice 025a (TW12, filtered runs only, no full sweep).

For each mutation: one small change in one file of cli/, a `roc check`, then only the tests that should catch it. The first test that fails ends the run of that
mutation (CAUGHT). A test that runs longer than the timeout counts as CAUGHT (a loop). cli/ is restored from research/slice-025-revert/code-final/cli before and
after each mutation, so a kill is safe.

Usage: python3 -I research/slice-025-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(ROOT, "research/slice-025-revert/code-final/cli")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}
CON, COM, ST = "lib/Consent.roc", "lib/Compiler.roc", "lib/Start.roc"
L0C, L2C, L3C, L3T = "l0:consent", "l2:consent/", "l3:dl1-resolve-consent", "l3:dl2-consent-tty"

# (id, file under cli/, [(old, new)], [tests], what the change breaks)
M = [
    ("C01", CON, [("		} else if run.auto == No and !answered {\n			AutoNo\n		} else if", "		} else if")], [L0C, L2C], "R-DL5: TALON_AUTO_INSTALL=no does not refuse"),
    ("C02", CON, [("NonInteractive => NeedsConsent", "NonInteractive => Install")], [L0C, L2C, L3C], "R-DL4: a run with no person downloads with no consent"),
    ("C03", CON, [("answered = run.yes or flag_is_yes(run.flag)", "answered = run.yes")], [L0C, L2C, L3C], "R-DL5: --allow-downloads is ignored"),
    ("C04", CON, [("answered = run.yes or flag_is_yes(run.flag)", "answered = flag_is_yes(run.flag)")], [L0C, L2C, L3C], "R-DL5: --yes is ignored"),
    ("C05", CON, [("} else if run.auto == Yes or answered {", "} else if answered {")], [L0C, L2C, L3C], "R-DL9: TALON_AUTO_INSTALL=yes is ignored"),
    ("C06", CON, [("			default: No,\n			question: \"${facts.id} is not installed.", "			default: Yes,\n			question: \"${facts.id} is not installed.")], [L0C, L2C], "R-DL3: the default of the prompt is Yes"),
    ("C07", CON, [("needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.\")\n	}", "needs consent. Pass --allow-downloads.\")\n	}")], [L0C, L2C, L3C], "R-DL4: the stop does not name TALON_AUTO_INSTALL"),
    ("C08", CON, [('		Ok((_, "no")) => No', '		Ok((_, "no")) => Ask')], [L0C, L2C], "R-DL10: no is not read"),
    ("C09", CON, [("if !Pin.is_nightly(run.id) {\n			Refuse", 'if run.id == "" {\n			Refuse')], [L0C, L2C], "R-NS2: a release version is downloaded"),
    ("C10", CON, [("				Interactive => Ask\n				NeedsTty => NeedTty", "				Interactive => Ask\n				NeedsTty => Ask")], [L0C, L2C], "R-HF1: a prompt with no tty call"),
    ("C11", CON, [("Download ${facts.count.to_str()} ${plural(facts.count, \"compiler\", \"compilers\")}, ${size}?", "Download ${facts.count.to_str()} ${plural(facts.count, \"compiler\", \"compilers\")}?")], [L0C, L2C], "R-DL1: the prompt has no size"),
    ("C12", CON, [('plural(facts.count, "download", "downloads")', '"download"')], [L0C], "R-DL1: the stop of 2 downloads says download"),
    ("C14", CON, [("} else if run.auto == No and !answered {", "} else if run.auto == No {")], [L0C, L2C], "Q1: the variable wins over a flag"),
    ("C15", CON, [('what = if facts.count == 1 facts.id else "${facts.count.to_str()} compilers"', "what = facts.id")], [L0C], "R-DL1: the answer line of 2 downloads names one"),
    ("C16", CON, [('Nothing was downloaded. ${ways(id)}")', 'Nothing was downloaded.")')], [L0C, L2C], "Q4: the interactive No does not name the way"),
    ("C17", CON, [('refuses the download. ${ways(id)}")', 'refuses the download.")')], [L0C, L2C], "Q4: the refusal of `no` does not name the way"),
    ("C18", CON, [('		Ok((_, "yes")) => Yes\n		Ok((_, "no")) => No', '		Ok((_, "yes")) => Ask\n		Ok((_, "no")) => No')], [L0C, L2C], "R-DL9: yes is not read"),
    ("K01", COM, [("Ok(found) if Pin.same_id(facts.id, found.id) => Ok(found.id)\n			_ => Err(Missing)", "Ok(_) => Ok(facts.id)\n			_ => Err(Missing)")], ["l0:compiler", "l2:probe/ ladder/"], "R-SO10: the roc on PATH counts for any id"),
    ("K02", COM, [("find = |facts| match facts.installed.find_first(|id| Pin.same_id(facts.id, id))", "find = |facts| match facts.installed.find_first(|id| id == facts.id)")], ["l0:compiler", "l2:probe/ ladder/"], "R-CV1: the other tag form is not one nightly"),
    ("O01", "lib/Opts.roc", [('allow_downloads: if given("--allow-downloads") Ok(Yes) else Err(NoFlag)', "allow_downloads: Err(NoFlag)")], ["l0:opts", L2C], "R-FL12: --allow-downloads is not read"),
    ("O02", "lib/Opts.roc", [('probe_downloads: if given("--probe-downloads") Ok(Yes) else Err(NoFlag)', "probe_downloads: Err(NoFlag)")], ["l0:opts"], "R-FL12: --probe-downloads is not read"),
    ("O03", "lib/Removal.roc", [('allow_downloads: if has_flag(args, "--allow-downloads") Ok(Yes) else Err(NoFlag)', "allow_downloads: Err(NoFlag)")], ["l0:removal", L2C], "R-NI5: remove ignores --allow-downloads"),
    ("S01", ST, [("Present(found) => Ok({ id: found.id, installed: listed.append(found.id), downloads: 0 })", "Present(found) => Ok({ id: found.id, installed: listed, downloads: 0 })")], [L2C, L3C], "R-CC9: the id that came meanwhile has no .last-use"),
    ("S02", ST, [("Ok({ id: done.id, installed: listed.append(done.id), downloads: 1 })", "Ok({ id: done.id, installed: listed, downloads: 1 })")], [L2C, L3C], "R-CC9: the new compiler is not in the installed list"),
    ("S03", ST, [("Consent.download_stop({ count: 1, size: offer.size })", "Consent.download_stop({ count: 1, size: 0 })")], [L2C, L3C], "R-DL1: the stop has no size"),
    ("S04", ST, [("if asked.answer != Yes return", "if asked.answer == Option(9) return")], [L2C, L3T], "R-DL3: the answer No downloads"),
    ("S05", ST, [("flag = if how.decided == Install Ok(Yes) else Err(NoFlag)", "flag = Ok(Yes)")], [L2C, L3T], "R-DL1: no prompt for a person"),
    ("S06", ST, [("		Refuse => {\n			id = Compiler.require(", "		Refuse => offered!(fx, run, listed, { decided: Install, mode })\n		Install => {\n			id = Compiler.require(")], [L2C, L3C], "R-NS2: a refused compiler is downloaded"),
    ("S07", ST, [("AutoNo => Err(Consent.download_refused(run.held))", "AutoNo => Err(Consent.command_declined(run.held))")], [L2C, L3C], "Q4: the refusal of `no` has the text of the interactive No"),
    ("S08", ST, [("Ok({ id: done.id, installed: listed.append(done.id), downloads: 1 })", "Ok({ id: done.id, installed: listed.append(done.id), downloads: 0 })")], [L2C, L3C], "Q7: the count of downloads is 0"),
    ("S09", ST, [("mode = if first == NeedTty Mode", "mode = if first == Refuse Mode")], [L2C, L3T], "R-HF1: the terminal is asked after the list"),
    ("S10", ST, [("offline: facts.offline })?", "offline: Bool.False })?")], [L2C], "R-NM8: --offline is not passed to the offer"),
    ("S11", ST, [("Consent.command_download({ id: offer.id, count: 1, size: offer.size })", "Consent.command_download({ id: offer.id, count: 2, size: offer.size })")], [L2C, L3T], "R-DL1: the count of the prompt"),
    ("S12", ST, [("listed = Launch.toolchains!(fx, run.roots)\n", "listed = []\n")], [L2C, "l2:ladder/ probe/"], "R-SO22: the installed list is not read"),
    ("B01", "lib/ResolveBase.roc", [("mode: request.prompt.mode,", "mode: NonInteractive,")], [L2C, L3T], "R-NI5: the mode of the run is not read"),
    ("B02", "lib/ResolveBase.roc", [("yes: request.prompt.yes,", "yes: Bool.False,")], [L2C, L3C], "R-DL5: --yes is not passed to the ladder"),
    ("B03", "lib/ResolveBase.roc", [("		offline: request.offline,\n		env: request.downloads.env,", "		offline: Bool.False,\n		env: request.downloads.env,")], [L2C], "R-NM8: --offline is not passed to the ladder"),
    ("B04", "lib/ResolveBase.roc", [("allow: request.downloads.allow,", "allow: Err(NoFlag),")], [L2C, L3C], "R-FL12: the flag is not passed to the ladder"),
    ("B05", "lib/ResolveBase.roc", [("auto: request.downloads.auto,", "auto: Ask,")], [L2C, L3C], "R-EV6: the variable is not passed to the ladder"),
    ("R01", "lib/Report.roc", [("Num(o.downloads.to_i64_wrap())", "Num(0)")], ["l0:report", L3C], "Q7: data.downloads is 0"),
    ("R02", "lib/InstallFlow.roc", [("			downloads: done.downloads,\n			check: Passed,\n			build: if members.any", "			downloads: 0,\n			check: Passed,\n			build: if members.any")], [L2C], "Q7: update and install do not pass the count"),
    ("R03", "lib/VerifyFlow.roc", [("			downloads: done.downloads,", "			downloads: 0,")], [L3C], "Q7: verify does not pass the count"),
    ("R04", "lib/RemoveFlow.roc", [("			downloads: done.downloads,", "			downloads: 0,")], [L2C], "Q7: remove does not pass the count"),
    ("T01", "lib/Verify.roc", [('shown.out!("verified: the tuple passes. No project file was written.\\n")', 'shown.out!("verified: the tuple passes. Nothing was written.\\n")')], ["l2:verify/ workspace/", "l3:verify/vf1-verify"], "Q5: the old verify line"),
    ("V01", "lib/Verify.roc", [("auto: Consent.auto_install(start.env), allow: opts.allow_downloads", "auto: Ask, allow: opts.allow_downloads")], [L2C, L3C], "R-EV6: verify ignores TALON_AUTO_INSTALL"),
    ("V02", "lib/Verify.roc", [("allow: opts.allow_downloads, probe", "allow: Err(NoFlag), probe")], [L3C], "R-FL12: verify ignores --allow-downloads"),
    ("U01", "lib/Update.roc", [("allow: opts.allow_downloads, probe: opts.probe_downloads", "allow: Err(NoFlag), probe: opts.probe_downloads")], [L2C], "R-FL12: update ignores --allow-downloads"),
    ("U02", "lib/Update.roc", [("auto: Consent.auto_install(start.env)", "auto: Ask")], [L2C], "R-EV6: update ignores TALON_AUTO_INSTALL"),
    ("I01", "lib/Install.roc", [("allow: opts.allow_downloads, probe", "allow: Err(NoFlag), probe")], [L2C], "R-FL12: add ignores --allow-downloads"),
    ("I02", "lib/Install.roc", [("auto: Consent.auto_install(env), allow", "auto: Ask, allow")], [L2C], "R-EV6: install ignores TALON_AUTO_INSTALL"),
    ("D01", "lib/Remove.roc", [("allow: opts.allow_downloads, probe: Err(NoFlag)", "allow: Err(NoFlag), probe: Err(NoFlag)")], [L2C], "R-FL12: remove ignores --allow-downloads"),
    ("D02", "lib/Remove.roc", [("auto: Consent.auto_install(start.env)", "auto: Ask")], [L2C], "R-EV6: remove ignores TALON_AUTO_INSTALL"),
    ("P01", "lib/Proxy.roc", [("auto = Consent.auto_install(run.env)", "auto = Ask")], ["l2:proxy/", "l3:px"], "R-EV6: the proxy ignores TALON_AUTO_INSTALL"),
    ("N01", "lib/Common.roc", [('Ok((_, "1")) | Ok((_, "true")) => Ok(Bool.True)', 'Ok((_, "1")) => Ok(Bool.True)')], ["l2:install/ update/ resolve/ roc/ proxy/", "l3:"], "R-EV4: TALON_NIGHTLY=true (moved to Common)"),
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
