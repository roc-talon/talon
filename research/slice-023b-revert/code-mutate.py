#!/usr/bin/env python3
"""Revert check of the code of slice 023b (TW12, filtered runs only, no full sweep).

For each mutation: the 3 files are first restored from research/slice-023b-revert/code-final/ (so a kill is safe), then one small change, a `roc check`,
then only the tests that should catch it. The first test that fails ends the run (CAUGHT). A timeout counts as CAUGHT. The files are restored after each mutation.

Usage: python3 -I research/slice-023b-revert/code-mutate.py [id ...]     (from the repo root)
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = "cli/lib/"
FINAL = os.path.join(ROOT, "research/slice-023b-revert/code-final")
FILES = ["Proxy.roc", "Consent.roc", "RocInstall.roc"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}
PX = ["l0:proxy", "l2:proxy/", "l3:px2-proxy-install"]
RI = ["l2:roc/ri1-flow", "l3:ri1-install-flow"]

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("A1", "Proxy.roc", [('Ok((_, "yes")) => Yes', 'Ok((_, "yes")) => Ask')], PX, "R-EV6: yes counts as ask"),
    ("A2", "Proxy.roc", [('Ok((_, "no")) => No', 'Ok((_, "no")) => Ask')], PX, "R-EV6: no counts as ask"),
    ("A3", "Proxy.roc", [("\t\t_ => Ask\n\t}\n\n\t## R-PX4", "\t\t_ => Yes\n\t}\n\n\t## R-PX4")], PX, "R-EV6: a bad value counts as yes"),
    ("W1", "Proxy.roc", [("if !Pin.is_nightly(run.id) or run.auto == No {", "if run.auto == No {")], PX, "Q2: a text that is not a nightly tag is downloaded"),
    ("W2", "Proxy.roc", [("or run.auto == No {", "or run.auto == Ask and Bool.False {")], PX, "R-DL10: no does not refuse"),
    ("W3", "Proxy.roc", [("} else if run.auto == Yes {", "} else if run.auto == Yes and run.mode != Interactive {")], PX, "R-DL9: yes with a person asks"),
    ("W4", "Proxy.roc", [("NeedsTty => NeedTty", "NeedsTty => Ask")], PX, "R-HF1: no tty call, ask with an unknown mode"),
    ("W5", "Proxy.roc", [("NonInteractive => Refuse", "NonInteractive => Install")], PX, "R-DL8: no person installs"),
    ("W6", "Proxy.roc", [("Interactive => Ask", "Interactive => Refuse")], PX, "R-DL8: a person gets a refusal"),
    ("W7", "Proxy.roc", [("Pin.is_nightly(run.id)", "Pin.is_id(run.id)")], PX, "Q2: the check is any id"),
    ("D1", "Proxy.roc", [("Refuse | NeedTty => Err(Proxy.missing({ id: run.id, rank: run.rank }))", "Refuse | NeedTty => offer_and_install!(fx, run, { mode: known, flag: Ok(Yes) })")], PX, "R-DL8, R-DL10: no refusal"),
    ("D2", "Proxy.roc", [("Install => offer_and_install!(fx, run, { mode: known, flag: Ok(Yes) })", "Install => offer_and_install!(fx, run, { mode: known, flag: Err(NoFlag) })")], PX, "R-DL5: yes has no flag"),
    ("D3", "Proxy.roc", [("if asked.answer == Yes {", "if asked.answer == Yes or asked.answer == No {")], PX, "R-CC4 step 2: the answer No installs"),
    ("D4", "Proxy.roc", [("source: source_text({ id: run.id, rank: run.rank })", 'source: "the roc on PATH"')], PX, "R-NI5: the source of the prompt"),
    ("D5", "Proxy.roc", [("mode: how.mode, yes: Bool.False", "mode: how.mode, yes: Bool.True")], PX, "R-NI5: --yes is always set"),
    ("D6", "Proxy.roc", [("known = if first == NeedTty Mode.with_tty(mode, fx.tty!()) else mode", "known = if first == NeedTty and Bool.False Mode.with_tty(mode, fx.tty!()) else mode")], PX, "R-HF1: no tty call"),
    ("D7", "Proxy.roc", [("offline: Bool.False })? {", "offline: Bool.True })? {")], PX, "the offer is offline"),
    ("D8", "Proxy.roc", [("have = if missing installed.append(id) else installed", "have = installed")], PX, "N3: the new id is not installed for the program"),
    ("D9", "Proxy.roc", [("id = if missing install_missing!", "id = if missing and Bool.False install_missing!")], PX, "R-PX4: no install"),
    ("D10", "Proxy.roc", [("if !off and have.contains(id) {", "if !off and have.contains(id) and !missing {")], PX, "R-CC9: no .last-use after the install"),
    ("I1", "RocInstall.roc", [("fx.with_lock!(ctx.item, Wait,", "fx.with_lock!(ctx.item, NoWait,")], PX + RI, "R-CC5: no wait for the lock"),
    ("I2", "RocInstall.roc", [("Installed => set_default!(fx, ctx.roots, ctx.id)?", "Installed => Kept")], PX + RI, "R-SO15: no default"),
    ("I3", "RocInstall.roc", [("Ok(Download({ id, size: asset.size, ctx }))", "Ok(Download({ id, size: 0, ctx }))")], PX, "R-DL1: the size of the offer"),
    ("I4", "RocInstall.roc", [("\tif has_dir(entries, ctx.id) return Ok({ how: Present, compat: Err(Unknown) })\n", "")], PX + RI, "R-CC4 step 4: no check under the lock"),
    ("I5", "RocInstall.roc", [('Err(Busy) => return Err(Fail.new(Internal, "the lock of ${ctx.item} was not taken"))\n\t\t}\n\t\tdefault', 'Err(Busy) => return Err(Fail.new(Internal, "the lock of ${ctx.item} was not taken"))\n\t\t}\n\t\t_ = fx.out!("installed ${ctx.id}\\n")\n\t\tdefault')], PX, "N5: a line on stdout"),
    ("I6", "RocInstall.roc", [("ask_download!(fx, args, env, { id: offer.id, size: offer.size })?", "ask_download!(fx, args, env, { id: offer.id, size: 0 })?")], RI, "run!: the size of the prompt"),
    ("I7", "RocInstall.roc", [("\t\tif run.offline return Err(Toolchain.offline_missing(id))\n", "")], RI, "R-DI12: --offline downloads"),
    ("I8", "RocInstall.roc", [("\t\tif has_dir(entries, run.id) return Ok(Present({ id: run.id }))\n", "")], PX + RI, "R-CC4 step 1: an installed id makes a request"),
    ("C1", "Consent.roc", [('default: Yes,\n\t\t\tquestion: "${facts.id} (${facts.source})', 'default: No,\n\t\t\tquestion: "${facts.id} (${facts.source})')], ["l0:consent", "l2:proxy/"], "R-DL3: the default is No"),
    ("C2", "Consent.roc", [('kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"])', 'kind: Required(["TALON_AUTO_INSTALL=yes"])')], ["l0:consent"], "R-NI5: the flags"),
    ("C3", "Consent.roc", [('is not installed. Download 1 compiler, ${size}?"', 'is not installed. Download ${size}?"')], ["l0:consent", "l2:proxy/"], "R-DL1: the count"),
    ("C4", "Consent.roc", [('"downloading ${facts.id} (${size})" else "no download of ${facts.id}",\n\t\t}\n\t}\n\n\t## The failure of a picker', '"download of ${facts.id} (${size})" else "no download of ${facts.id}",\n\t\t}\n\t}\n\n\t## The failure of a picker')], ["l0:consent", "l2:proxy/"], "R-NM6: the answer line"),
    ("C5", "Consent.roc", [('id: "proxy-download"', 'id: "roc-install"')], ["l0:consent"], "the id of the prompt"),
    ("C6", "Consent.roc", [('question: "${facts.id} (${facts.source}) is', 'question: "${facts.id} is')], ["l0:consent", "l2:proxy/"], "R-NI5: no source in the question"),
]


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


def restore():
    for name in FILES:
        shutil.copyfile(os.path.join(FINAL, name), os.path.join(ROOT, LIB, name))


def main():
    want = set(sys.argv[1:])
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        restore()
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
                restore()


main()
restore()
