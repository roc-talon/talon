#!/usr/bin/env python3
"""Revert check of the code of slice 025 (TW12, filtered runs only, no full sweep).

For each mutation: one small change in one file of cli/lib, a `roc check`, then only the tests that should catch it. The first test that fails ends the run of that mutation
(CAUGHT). A test that runs longer than the timeout counts as CAUGHT (a loop). The file is put back after each mutation.

Usage: [SKIP=l0] python3 -I research/slice-025-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("C1", "Consent.roc", [("} else if run.auto == No and run.flag == Err(NoFlag) and !run.yes {\n			AutoNo\n		} else if", "} else if")], ["l0:consent", "l2:consent/"], "R-DL5: TALON_AUTO_INSTALL=no does not refuse"),
    ("C2", "Consent.roc", [("NonInteractive => NeedsConsent", "NonInteractive => Install")], ["l0:consent", "l2:consent/", "l3:dl1-resolve-consent"], "R-DL4: a run with no person downloads with no consent"),
    ("C3", "Consent.roc", [("run.auto == Yes or run.flag == Ok(Yes) or run.yes {", "run.auto == Yes or run.yes {")], ["l0:consent", "l2:consent/", "l3:dl1-resolve-consent"], "R-DL5: --allow-downloads is ignored"),
    ("C4", "Consent.roc", [("run.auto == Yes or run.flag == Ok(Yes) or run.yes {", "run.auto == Yes or run.flag == Ok(Yes) {")], ["l0:consent", "l2:consent/", "l3:dl1-resolve-consent"], "R-DL5: --yes is ignored"),
    ("C5", "Consent.roc", [("run.auto == Yes or run.flag == Ok(Yes) or run.yes {", "run.flag == Ok(Yes) or run.yes {")], ["l0:consent", "l2:consent/", "l3:dl1-resolve-consent"], "R-DL9: TALON_AUTO_INSTALL=yes is ignored"),
    ("C6", "Consent.roc", [('			default: No,\n			question: "${facts.id} is not installed. Download ${count}', '			default: Yes,\n			question: "${facts.id} is not installed. Download ${count}')], ["l0:consent", "l2:consent/"], "R-DL3: the default of the prompt is Yes"),
    ("C7", "Consent.roc", [("(${Toolchain.size_text(facts.size)}) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.", "(${Toolchain.size_text(facts.size)}) needs consent. Pass --allow-downloads.")], ["l0:consent", "l2:consent/", "l3:dl1-resolve-consent"], "R-DL4: the stop does not name TALON_AUTO_INSTALL"),
    ("C8", "Consent.roc", [('Ok((_, "no")) => No', 'Ok((_, "no")) => Ask')], ["l0:consent", "l2:consent/"], "R-DL10: no is not read"),
    ("C9", "Consent.roc", [("if !Pin.is_nightly(run.id) {\n			Refuse", "if run.id == \"\" {\n			Refuse")], ["l0:consent", "l2:consent/"], "R-NS2: a release version is downloaded"),
    ("C10", "Consent.roc", [("				NeedsTty => NeedTty", "				NeedsTty => Ask")], ["l0:consent", "l2:consent/"], "R-HF1: a prompt with no tty call"),
    ("C11", "Consent.roc", [("question: \"${facts.id} is not installed. Download ${count} ${noun}, ${size}?\"", "question: \"${facts.id} is not installed. Download ${count} ${noun}?\"")], ["l0:consent", "l2:consent/"], "R-DL1: the prompt has no size"),
    ("C12", "Consent.roc", [("if facts.count == 1 \"download\" else \"downloads\"", "\"download\"")], ["l0:consent"], "R-DL1: the stop of 2 downloads says download"),
    ("K1", "Compiler.roc", [("Ok(found) if Pin.same_id(facts.id, found.id) => Ok(found.id)\n			_ => Err(Missing)", "Ok(_) => Ok(facts.id)\n			_ => Err(Missing)")], ["l0:compiler", "l2:probe/ ladder/"], "R-SO10: the roc on PATH counts for any id"),
    ("K2", "Compiler.roc", [("find = |facts| match facts.installed.find_first(|id| Pin.same_id(facts.id, id))", "find = |facts| match facts.installed.find_first(|id| id == facts.id)")], ["l0:compiler", "l2:probe/ ladder/"], "R-CV1: the other tag form is not one nightly"),
    ("O1", "Opts.roc", [('allow_downloads: if given("--allow-downloads") Ok(Yes) else Err(NoFlag)', "allow_downloads: Err(NoFlag)")], ["l0:opts", "l2:consent/"], "R-FL12: --allow-downloads is not read"),
    ("O2", "Opts.roc", [('probe_downloads: if given("--probe-downloads") Ok(Yes) else Err(NoFlag)', "probe_downloads: Err(NoFlag)")], ["l0:opts"], "R-FL12: --probe-downloads is not read"),
    ("O3", "Removal.roc", [("allow_downloads: read.allow_downloads })", "allow_downloads: Err(NoFlag) })")], ["l0:removal", "l2:consent/"], "R-NI5: remove ignores --allow-downloads"),
    ("L1", "Ladder.roc", [("(got.id, listed.append(got.id), if got.downloaded 1 else 0)", "(got.id, listed, if got.downloaded 1 else 0)")], ["l2:consent/"], "R-CC4: the new compiler is not in the installed list"),
    ("L2", "Ladder.roc", [("Download(offer) => Err(Consent.download_stop({ count: 1, size: offer.size }))", "Download(_) => Err(Consent.download_stop({ count: 0, size: 0 }))")], ["l2:consent/", "l3:dl1-resolve-consent"], "R-DL1: the stop has no size"),
    ("L3", "Ladder.roc", [("Err(Consent.command_declined(offer.id))", "{\n					done = RocInstall.install_offer!(fx, offer)?\n					Ok({ id: done.id, downloaded: Bool.True })\n				}")], ["l2:consent/", "l3:dl2-consent-tty"], "R-DL3: the answer No downloads"),
    ("L4", "Ladder.roc", [("Ask => offer_and_install!(fx, run, { mode, flag: Err(NoFlag) })", "Ask => offer_and_install!(fx, run, { mode, flag: Ok(Yes) })")], ["l2:consent/", "l3:dl2-consent-tty"], "R-DL1: no prompt for a person"),
    ("L5", "Ladder.roc", [("Refuse | NeedTty => Err(refusal)", "NeedTty => Err(refusal)\n		Refuse => offer_and_install!(fx, run, { mode, flag: Ok(Yes) })")], ["l2:consent/", "l3:dl1-resolve-consent"], "R-DL10: a refused compiler is downloaded"),
    ("C14", "Consent.roc", [("run.auto == No and run.flag == Err(NoFlag) and !run.yes {", "run.auto == No {")], ["l0:consent", "l2:consent/"], "Q1: the variable wins over a flag"),
    ("C15", "Consent.roc", [('what = if facts.count == 1 facts.id else "${count} compilers"', "what = facts.id")], ["l0:consent"], "R-DL1: the answer line of 2 downloads names one"),
    ("C16", "Consent.roc", [("Run: tln roc install ${id}, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.\")\n\n\t## R-NI5, R-NM8", "Run: tln roc install ${id}.\")\n\n\t## R-NI5, R-NM8")], ["l0:consent", "l2:consent/"], "Q4: the interactive No does not name the flag"),
    ("L7", "Ladder.roc", [("AutoNo => Err(Consent.download_refused(run.held))", "AutoNo => Err(refusal)")], ["l2:consent/", "l3:dl1-resolve-consent"], "Q4: the refusal of `no` has the P0 text"),
    ("L8", "Ladder.roc", [("(got.id, listed.append(got.id), if got.downloaded 1 else 0)", "(got.id, listed.append(got.id), 0)")], ["l3:dl1-resolve-consent"], "Q7: the count of downloads is 0"),
    ("R1", "Report.roc", [("Num(o.downloads.to_i64_wrap())", "Num(0)")], ["l0:report", "l3:dl1-resolve-consent"], "Q7: data.downloads is 0"),
    ("R2", "InstallFlow.roc", [("		downloads: done.ran.downloads,\n", "		downloads: 0,\n")], ["l2:consent/"], "Q7: update and install do not pass the count"),
    ("R3", "VerifyFlow.roc", [("downloads: ran.downloads,", "downloads: 0,")], ["l3:dl1-resolve-consent"], "Q7: verify does not pass the count"),
    ("T1", "Verify.roc", [('shown.out!("verified: the tuple passes. No project file was written.\\n")', 'shown.out!("verified: the tuple passes. Nothing was written.\\n")')], ["l2:verify/ workspace/", "l3:verify/vf1-verify"], "Q5: the old verify line"),
    ("B1", "ResolveBase.roc", [("mode: request.prompt.mode,", "mode: NonInteractive,")], ["l2:consent/", "l3:dl2-consent-tty"], "R-NI5: the mode of the run is not read"),
    ("B2", "ResolveBase.roc", [("yes: request.prompt.yes,", "yes: Bool.False,")], ["l2:consent/", "l3:dl1-resolve-consent"], "R-DL5: --yes is not passed to the ladder"),
    ("B3", "ResolveBase.roc", [("		offline: request.offline,\n	}", "		offline: Bool.False,\n	}")], ["l2:consent/"], "R-NM8: --offline is not passed to the offer"),
    ("V1", "Verify.roc", [("auto: Consent.auto_install(start.env), allow: opts.allow_downloads", "auto: Ask, allow: opts.allow_downloads")], ["l2:consent/", "l3:dl1-resolve-consent"], "R-EV6: verify ignores TALON_AUTO_INSTALL"),
    ("U1", "Update.roc", [("allow: opts.allow_downloads, probe: opts.probe_downloads", "allow: Err(NoFlag), probe: opts.probe_downloads")], ["l2:consent/"], "R-FL12: update ignores --allow-downloads"),
    ("P1", "Proxy.roc", [("auto = Consent.auto_install(run.env)", "auto = Ask")], ["l2:proxy/", "l3:px1-proxy"], "R-EV6: the proxy ignores TALON_AUTO_INSTALL"),
]


def run(test):
    kind, _, arg = test.partition(":")
    if kind in os.environ.get("SKIP", "").split(","):
        return False, "skipped"
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
        path = os.path.join(ROOT, LIB, fname)
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
                built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
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
                open(path, "w").write(orig)


main()
