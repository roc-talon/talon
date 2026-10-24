#!/usr/bin/env python3
"""Revert check of the code of slice 025b (TW12, filtered runs only, no full sweep).

Before each mutation, and at the end, the 6 code files are copied from code-final/ (a kill is safe). Each mutation is one small change in one file of cli/lib, a `roc check`,
then only the tests that should catch it. The first test that fails ends the run of that mutation (CAUGHT). A test that runs longer than the timeout counts as CAUGHT.
Usage: python3 -I research/slice-025b-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FINAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "code-final", "cli", "lib")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}
L2 = "l2:consent/dl3 proxy/px2"
L3 = "l3:dl3-rank4"

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("T1", "Toolchain.roc", [("min_age: facts.min_age, snapshot: facts.snapshot, keep: [] })", "min_age: 0, snapshot: facts.snapshot, keep: [] })")], ["l0:toolchain", L2], "R-C7: min-release-age does not limit the compiler"),
    ("T2", "Toolchain.roc", [("now: facts.now, min_age: facts.min_age, snapshot: facts.snapshot, keep: [] })", "now: facts.now, min_age: facts.min_age, snapshot: Err(None), keep: [] })")], ["l0:toolchain", L2], "R-C7, R-DT4: the snapshot does not limit the compiler"),
    ("T3", "Toolchain.roc", [("(facts.nightly or !Pin.is_nightly(r.id)) and Pin.admits({ req: facts.req, id: r.id, times })", "Pin.admits({ req: facts.req, id: r.id, times })")], ["l0:toolchain", L2], "R-NS2: the switch off still picks a nightly"),
    ("T4", "Toolchain.roc", [("(facts.nightly or !Pin.is_nightly(r.id)) and Pin.admits({ req: facts.req, id: r.id, times })", "(facts.nightly or !Pin.is_nightly(r.id))")], ["l0:toolchain", L2], "R-NS7: the range is not checked"),
    ("T5", "Toolchain.roc", [("== After id else best", "== Before id else best")], ["l0:toolchain", L2], "R-SO13: the oldest release, not the newest"),
    ("T6", "Toolchain.roc", [("Pin.order({ a: id, b: best, times })", "Pin.order({ a: id, b: best, times: [] })")], ["l0:toolchain"], "R-NS1: the order of 2 nightlies of one day ignores published_at"),
    ("T7", "Toolchain.roc", [("list: Nightlies.candidates(facts.releases), now: facts.now", "list: facts.releases, now: facts.now")], ["l0:toolchain"], "R-CV2: a release with no asset for the host is a candidate"),
    ("T8", "Toolchain.roc", [("Fail.new(NoTuple, base)", "Fail.new(Consent, base)")], ["l0:toolchain", L2], "R-EC10: the kind of the failure"),
    ("T9", "Toolchain.roc", [('Fail.new(NoTuple, "${base}, and nightly is false (set by ${Pin.source_text(facts.switch.source)})")', "Fail.new(NoTuple, base)")], ["l0:toolchain", L2], "R-NS2: the failure does not name the switch"),
    ("C1", "Consent.roc", [("run.auto == No and !(run.yes or flag_is_yes(run.flag))", "run.auto == No and !flag_is_yes(run.flag)")], ["l0:consent", L2], "R-DL5: --yes does not answer"),
    ("C2", "Consent.roc", [("run.auto == No and !(run.yes or flag_is_yes(run.flag))", "run.auto == No and !run.yes")], ["l0:consent", L2], "R-DL5: --allow-downloads does not answer"),
    ("C3", "Consent.roc", [("run.auto == No and !(run.yes or flag_is_yes(run.flag))", "run.auto == No")], ["l0:consent", L2], "Q1 of 025: the variable wins over the flags"),
    ("C4", "Consent.roc", [("run.auto == No and !(run.yes or flag_is_yes(run.flag))", "!(run.yes or flag_is_yes(run.flag))")], ["l0:consent", L2], "R-DL5: a run with no variable is refused"),
    ("C5", "Consent.roc", [('for an id in the range, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.")', 'for an id in the range, or set TALON_AUTO_INSTALL=yes.")')], ["l0:consent", L2, L3], "R-DL5: the refusal does not name the flag"),
    ("C6", "Consent.roc", [('range_refused = |range| Fail.new(Consent, "no installed', 'range_refused = |range| Fail.new(Usage, "no installed')], ["l0:consent", L2], "R-EC13: the kind of the refusal"),
    ("K1", "Compiler.roc", [('TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id> for an id in the range, or set TALON_AUTO_INSTALL=yes.")', 'This version of tln does not download a compiler for a run.")')], ["l0:compiler", L2], "023b Q5: the old text"),
    ("R1", "RocInstall.roc", [("		if found.source == Missing return Err(Toolchain.offline_no_list({}))\n		picked", "		picked")], ["l2:consent/dl3"], "R-DI12: --offline with no cached list"),
    ("R2", "RocInstall.roc", [("req_text: run.req_text, switch: run.switch })", 'req_text: "", switch: run.switch })')], [L2], "R-SO13: the failure has no range text"),
    ("R3", "RocInstall.roc", [("snapshot: run.snapshot, nightly: run.switch.nightly })", "snapshot: Err(None), nightly: run.switch.nightly })")], [L2], "R-DT4: the snapshot is not passed to the pick"),
    ("R4", "RocInstall.roc", [("min_age: run.min_age, snapshot", "min_age: 0, snapshot")], [L2, L3], "R-C7: min-release-age is not passed to the pick"),
    ("R5", "RocInstall.roc", [("snapshot: run.snapshot, nightly: run.switch.nightly })", "snapshot: run.snapshot, nightly: Bool.True })")], [L2], "R-NS3: the switch is not passed to the pick"),
    ("R6", "RocInstall.roc", [("now: run.now, offline: run.offline, host: system })?\n		if found.source", "now: run.now, offline: Bool.False, host: system })?\n		if found.source")], ["l2:consent/dl3"], "R-DI12: --offline is not passed to the list"),
    ("B1", "ResolveBase.roc", [("if refused and !request.no_check return", "if refused and Bool.False return")], ["l2:consent/dl3", L3], "R-DL10: no refusal for `no`"),
    ("B2", "ResolveBase.roc", [("flag: request.downloads.allow })\n	if refused", "flag: Err(NoFlag) })\n	if refused")], ["l2:consent/dl3", L3], "Q1 of 025: --allow-downloads does not win over the variable"),
    ("B3", "ResolveBase.roc", [("yes: request.prompt.yes, flag: request.downloads.allow })\n	if refused", "yes: Bool.False, flag: request.downloads.allow })\n	if refused")], ["l2:consent/dl3"], "Q1 of 025: --yes does not win over the variable"),
    ("B4", "ResolveBase.roc", [("req_text: text, min_age: settings.min_age, snapshot, switch })", "req_text: text, min_age: settings.min_age, snapshot: if snapshot.is_ok() Err(None) else snapshot, switch })")], ["l2:consent/dl3"], "R-C7: the snapshot is not passed"),
    ("B5", "ResolveBase.roc", [("min_age: settings.min_age, snapshot, switch", "min_age: 0, snapshot, switch")], ["l2:consent/dl3", L3], "R-C7: min-release-age is not passed"),
    ("B6", "ResolveBase.roc", [("switch = { nightly: settings.nightly, source: settings.nightly_from }", "switch = { nightly: settings.nightly, source: Default }")], ["l2:consent/dl3"], "R-NS2: the source of the switch"),
    ("B7", "ResolveBase.roc", [("selected: { id: Ok(id), from: Range } })\n}", "selected: { id: Ok(id), from: Path } })\n}")], ["l2:consent/dl3", L3], "R-SO19: the rank of the held compiler (equivalent?)"),
    ("B8", "ResolveBase.roc", [("req_text: text, min_age", 'req_text: "", min_age')], ["l2:consent/dl3"], "R-NS7: the failure has no range text"),
    ("B9", "ResolveBase.roc", [("offline: request.offline, req, req_text", "offline: Bool.False, req, req_text")], ["l2:consent/dl3"], "R-DI12: --offline is not passed"),
    ("B10", "ResolveBase.roc", [("Ok({ ..loaded, selected: { id: Ok(id), from: Range } })\n}", 'Ok({ ..loaded, selected: { id: if id == "" Ok(id) else loaded.selected.id, from: Range } })\n}')], ["l2:consent/dl3", L3], "R-SO13: the picked compiler is not held"),
    ("B11", "ResolveBase.roc", [("Consent.range_refused(text))\n	snapshot", 'Consent.range_refused(""))\n	snapshot')], ["l2:consent/dl3"], "R-DL10: the refusal has no range text"),
    ("B12", "ResolveBase.roc", [("switch = { nightly: settings.nightly, source: settings.nightly_from }", "switch = { nightly: Bool.True, source: settings.nightly_from }")], ["l2:consent/dl3"], "R-NS3: the switch is not passed"),
    ("N1", "ResolveBase.roc", [("if refused and !request.no_check return", "if refused return")], ["l2:consent/dl3"], "Q1: --no-check is refused by TALON_AUTO_INSTALL=no"),
    ("N2", "ResolveBase.roc", [("	snapshot = ResolveBase.snapshot_of(request, loaded.intent)?", "	if request.no_check return Err(Consent.range_refused(text))\n	snapshot = ResolveBase.snapshot_of(request, loaded.intent)?")], ["l2:consent/dl3"], "Q1: --no-check keeps exit 13 (022 D5)"),
    ("N3", "ResolveBase.roc", [("	snapshot = ResolveBase.snapshot_of(request, loaded.intent)?", "	if request.no_check return Err(Fail.new(NoTuple, text))\n	snapshot = ResolveBase.snapshot_of(request, loaded.intent)?")], ["l2:consent/dl3"], "Q1: --no-check holds no compiler (exit 10)"),
    ("P1", "Proxy.roc", [("auto: Consent.auto_install(run.env), yes: Bool.False", "auto: Consent.auto_install(run.env), yes: loaded.req_text == loaded.req_text")], ["l2:proxy/px2 proxy/px1", L3], "R-DL10: the proxy downloads with `no`"),
    ("P2", "Proxy.roc", [("	now = if run.off Clock.now!(fx, run.env)? else run.now\n", "	now = run.now\n")], ["l2:proxy/px2"], "R-C7: TALON_PROXY=0 has no time"),
    ("P3", "Proxy.roc", [("min_age: loaded.min_age, snapshot", "min_age: 0, snapshot")], [L3, "l2:proxy/px2"], "R-C7: the proxy ignores min-release-age"),
    ("P4", "Proxy.roc", [("	switch = Pin.switch({ env: Common.nightly_of(run.env), toml: loaded.toml_nightly, config: loaded.config_nightly })", "	switch = { nightly: Bool.True, source: Default }")], ["l2:proxy/px2"], "R-NS3: the proxy ignores the switch"),
    ("P5", "Proxy.roc", [("	Ok({ id, rank: Range, state: Missing })", "	Ok({ id, rank: Path, state: Missing })")], ["l2:proxy/px2"], "R-DL8: the source text of the prompt and the refusal"),
    ("P6", "Proxy.roc", [("req_text: loaded.req_text, min_age", 'req_text: "", min_age')], ["l2:proxy/px2"], "R-NS7: the failure has no range text"),
    ("P7", "Proxy.roc", [("min_age: config.min_release_age ?? 172800, has_toml", "min_age: 172800, has_toml")], ["l2:proxy/px2"], "R-C7: the proxy does not read min-release-age of config.toml"),
    ("P8", "Proxy.roc", [("toml: loaded.toml_nightly, config", "toml: Err(Unset), config")], ["l2:proxy/px2"], "R-NS8: the proxy ignores nightly of talon.toml"),
    ("P9", "Proxy.roc", [("config: loaded.config_nightly })", "config: Err(Unset) })")], ["l2:proxy/px2"], "R-NS10: the proxy ignores nightly of config.toml"),
    ("P10", "Proxy.roc", [("Err(Compiler.failure(NoneInRange(loaded.req_text)))\n	}\n	req", "Err(Compiler.failure(NoCompiler))\n	}\n	req")], ["l2:proxy/px2"], "R-DL10: the refusal of the proxy is another failure"),
    ("P11", "Proxy.roc", [("offline: Bool.False, req, req_text", "offline: Bool.True, req, req_text")], ["l2:proxy/px2"], "R-PX4: the proxy reads the list with --offline"),
]


def restore():
    for name in os.listdir(FINAL):
        shutil.copyfile(os.path.join(FINAL, name), os.path.join(ROOT, LIB, name))


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
        path = os.path.join(ROOT, LIB, fname)
        text = open(path).read()
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            open(path, "w").write(text)
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
    restore()


main()
