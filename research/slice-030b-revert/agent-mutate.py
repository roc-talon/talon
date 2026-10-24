#!/usr/bin/env python3
"""Revert check (TW12) of the code of slice 030b, by the code agent. Small mutations of the real code, one after another (no full sweep, no parallel builds).

Each mutation: put code-final/ into cli/lib/, change one small thing, `roc check cli/main.roc` (0 errors and no warning), then L0 (tests/unit/pins.roc),
then `scripts/test.sh l2 l3` (the first layer that fails ends the run: caught). At the end code-final/ is put back and compared with cli/lib/.
Usage (from the repo root): python3 -I research/slice-030b-revert/agent-mutate.py [id ...]   (no id: all)
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work"
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD)
FINAL = os.path.join(ROOT, "research/slice-030b-revert/code-final")
NAMES = ["Facts", "Nightlies", "Toolchain", "RocInstall"]
FA, NI, TO, RI = "cli/lib/Facts.roc", "cli/lib/Nightlies.roc", "cli/lib/Toolchain.roc", "cli/lib/RocInstall.roc"
T = "\t"

M = [
    ("F01", "R-CV6", FA, "if acc.new.any(|seen| same_key(seen, listed)) acc else", "if acc.new.any(|seen| same_key(seen, listed)) and listed.tag.is_empty() acc else"),
    ("F02", "R-CV6", FA, "Changed(change) => { new: acc.new, changed: acc.changed.append(change) }", "Changed(_) => acc"),
    ("F03", "R-CV6", FA, "Same => acc", "Same => { new: acc.new.append(listed), changed: acc.changed }"),
    ("F04", "R-CV6", FA, "if run.listed.is_empty() {", "if run.listed.len() > 999999 {"),
    ("F05", "R-CV6", FA, "record_new! = |fx, open, new| if new.is_empty() {", "record_new! = |fx, open, new| if new.len() > 999999 {"),
    ("F06", "R-CV6", FA, "record_new!(fx, open, seen.new)", "record_new!(fx, open, run.listed)"),
    ("F07", "R-CC8", FA, "Ok(_) => Ok(None)", "Ok(_) => Ok(Some([]))"),
    ("F08", "R-CC8", FA, "Ok(_) => Ok(None)", 'Ok(_) => Err(Fail.new(Internal, "x"))'),
    ("F09", "R-TF3", FA, "Err(fail) => Err(fail)\n" + T * 4 + "}\n" + T * 3 + "}\n" + T * 3 + "match recorded", "Err(_) => Ok(None)\n" + T * 4 + "}\n" + T * 3 + "}\n" + T * 3 + "match recorded"),
    ("F10", "R-CC8", FA, "Ok(_) => Ok(seen.changed)", "Ok(_) => Ok([])"),
    ("F11", "R-CV6", FA, "keys = run.listed.map(|row| { tag: row.tag, target: row.target })", 'keys = run.listed.map(|row| { tag: row.tag, target: "any" })'),
    ("F12", "R-CC8", FA, "Err(err) => settle!(fx, { err, what: Write, path: open.path })\n" + T + "}\n}\n\nopen_of", 'Err(_) => Err(Fail.new(Internal, "x"))\n' + T + "}\n}\n\nopen_of"),
    ("F13", "R-CC8", FA, "Err(err) => settle!(fx, { err, what: Write, path: open.path })\n" + T + "}\n}\n\nopen_of", "Err(_) => Ok({})\n" + T + "}\n}\n\nopen_of"),
    ("N01", "R-CV3", NI, "sha256, source: GithubDigest })\n" + T * 4 + "Err(None) => Err(NoRow)", "sha256, source: Registry })\n" + T * 4 + "Err(None) => Err(NoRow)"),
    ("N02", "R-CV4", NI, "Err(None) => Err(NoRow)\n" + T * 3 + "}", 'Err(None) => Ok({ tag: release.id, target: Nightlies.target(facts.host), sha256: "", source: GithubDigest })\n' + T * 3 + "}"),
    ("N03", "R-CV8", NI, "target: Nightlies.target(facts.host), sha256, source", 'target: "linux_x86_64", sha256, source'),
    ("N04", "R-CV6", NI, "facts.releases.keep_if(|release| !facts.changed.any(|change| change.now.tag == release.id))", "facts.releases"),
    ("N05", "R-CV6", NI, "Ok({ releases: kept,", "Ok({ releases: list,"),
    ("N06", "R-CV6", NI, "source: found.source, changed, dropped", "source: found.source, changed: [], dropped"),
    ("N07", "R-CV3", NI, "listed: Nightlies.pins({ host: facts.host, releases: list }) })?", "listed: match found.source {\n" + T * 5 + "Live => Nightlies.pins({ host: facts.host, releases: list })\n" + T * 5 + "_ => []\n" + T * 4 + "} })?"),
    ("N08", "R-CV6", NI, "dropped: list.keep_if(|release| !kept.any(|k| k.id == release.id)) })", "dropped: [] })"),
    ("N09", "R-CV6", NI, "if acc.new", "if acc.new"),  # placeholder, removed below
    ("A01", "R-CV6", NI, "facts.dropped.find_first(|release| release.id == base or Nightlies.same_nightly(release.id, base))", 'facts.dropped.find_first(|release| release.id == base and base == "x")'),
    ("A02", "R-CV6", NI, "Nightlies.order(facts.releases.append(back))", "Nightlies.order(facts.releases.concat(facts.dropped))"),
    ("A03", "R-CV1", NI, "release.id == base or Nightlies.same_nightly(release.id, base)", "release.id == base"),
    ("A04", "R-NS1", NI, "Nightlies.order(facts.releases.append(back)).map(", "facts.releases.append(back).map("),
    ("A05", "R-CV6", RI, "auto = Nightlies.auto_with_base({ releases: found.releases, dropped: found.dropped, auto: lists.auto, base })", "auto = lists.auto"),
    ("A06", "R-C9", NI, "id == back.id or facts.auto.contains(id)", "facts.auto.contains(id)"),
    ("T01", "R-CV6", TO, 'text = facts.text.drop_prefix("@")', "text = facts.text"),
    ("T02", "R-SC10", TO, "[one] => Ok(Facts.changed_fail(one))", "[_] => Err(NotNamed)"),
    ("T03", "R-CV1", TO, "change.now.tag == text or Nightlies.same_nightly(change.now.tag, text)", "change.now.tag == text"),
    ("T04", "R-SC10", TO, "[one] => Ok(Facts.changed_fail(one))", "[one, ..] => Ok(Facts.changed_fail(one))"),
    ("T05", "R-CV6", TO, "Err(_) => if text.is_empty() {", 'Err(_) => if text == "x-never" {'),
    ("T06", "R-CV6", TO, "(${Db.source_word(now.source)}). Talon does not offer this compiler.", "(${Db.source_word(now.source)}). Talon does not use this compiler."),
    ("T07", "R-CV6", TO, "first seen ${first.sha256} (${Db.source_word(first.source)}), now ${now.sha256} (${Db.source_word(now.source)}). Talon does not offer", "first seen ${first.sha256} (${Db.source_word(now.source)}), now ${now.sha256} (${Db.source_word(first.source)}). Talon does not offer"),
    ("R01", "R-CV6", RI, "Ok(fail) => return Err(fail)", "Ok(_) => return Err(Toolchain.pick_failed({ error, releases: found.releases, host: system, switch }))"),
    ("R02", "R-CV6", RI, "Ok(picked) => {\n" + T * 4 + "warn_changed!(fx, found.changed)\n" + T * 4 + "picked\n" + T * 3 + "}", "Ok(picked) => picked"),
    ("R03", "R-CV6", RI, "Ok(fail) => return Err(fail)", "Ok(fail) => {\n" + T * 5 + "warn_changed!(fx, found.changed)\n" + T * 5 + "return Err(fail)\n" + T * 4 + "}"),
    ("R04", "R-CV6", RI, "Err(NotNamed) => warn_changed!(fx, found.changed)", "Err(NotNamed) => {}"),
    ("R05", "R-CV6", RI, "changed: found.changed }) {", "changed: [] }) {"),
    ("R06", "R-CV6", RI, 'fx.err!("warning: ${Toolchain.changed_warning(change)}\\n")', 'fx.out!("warning: ${Toolchain.changed_warning(change)}\\n")'),
]
M = [m for m in M if m[0] != "N09"]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def put():
    for n in NAMES:
        shutil.copy(os.path.join(FINAL, n + ".roc"), os.path.join(ROOT, "cli/lib", n + ".roc"))


def same():
    return all(open(os.path.join(FINAL, n + ".roc"), "rb").read() == open(os.path.join(ROOT, "cli/lib", n + ".roc"), "rb").read() for n in NAMES)


def first_layer():
    """Returns the text of the first failing layer, or ''."""
    try:
        r = sh(f"{ROC} test tests/unit/pins.roc --no-cache", 120)
        if r.returncode != 0:
            return "l0 unit/pins"
    except subprocess.TimeoutExpired:
        return "l0 timeout"
    try:
        r = sh("scripts/test.sh l2 l3", 600)
    except subprocess.TimeoutExpired:
        return "l2/l3 timeout"
    if r.returncode == 0:
        return ""
    fails = [l.split()[1] for l in r.stdout.splitlines() if l.startswith("FAIL") and len(l.split()) > 1]
    in_l2 = [f for f in fails if os.path.isdir(os.path.join(ROOT, "tests/commands/cases", f))]
    layer = "l2" if in_l2 else "l3"
    return "%s %s" % (layer, " ".join(fails[:3]) if fails else "(see log)")


def main():
    want = sys.argv[1:]
    results = []
    try:
        for mid, rule, name, old, new in M:
            if want and mid not in want:
                continue
            put()
            path = os.path.join(ROOT, name)
            text = open(path).read()
            if text.count(old) != 1:
                results.append((mid, rule, name, "BAD EDIT (%d matches)" % text.count(old), ""))
                print(mid, "BAD EDIT", text.count(old), flush=True)
                continue
            open(path, "w").write(text.replace(old, new))
            check = sh(f"{ROC} check cli/main.roc", 300)
            if check.returncode != 0 or "warning" in check.stdout.lower():
                results.append((mid, rule, name, "DID NOT COMPILE", check.stdout[:200].replace("\n", " ")))
                print(mid, "DID NOT COMPILE", check.stdout[:300].replace("\n", " "), flush=True)
                continue
            caught = first_layer()
            results.append((mid, rule, name, "caught" if caught else "NOT CAUGHT", caught))
            print(mid, rule, name, "caught" if caught else "NOT CAUGHT", caught, flush=True)
    finally:
        put()
    ok = same()
    print("code equal to code-final:", ok, flush=True)
    out = "agent-results.md" if not want else "agent-results-partial.md"
    with open(os.path.join(ROOT, "research/slice-030b-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")
        f.write("\nCode after the run equals code-final/: %s\n" % ok)


main()
