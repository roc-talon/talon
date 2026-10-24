#!/usr/bin/env python3
"""Revert check of the tests of slice 030b (TW12) against the private reference. Filtered runs only, one after another (no full sweep, no parallel roc builds).

For each mutation: put the reference (research/slice-030b-revert/reference) into cli/, change one small thing, `roc check cli/main.roc` (0 errors and no warning), then run the layers of the mutation in order.
The first layer that fails ends the run of that mutation (caught). A layer over its timeout counts as caught (a loop). At the end the stubs are put back.
Layers: l0 = tests/unit/pins.roc, l2 = tests/commands/run.sh roc/cv1-pins plus the old cases that the mutation can change (named in the row), l3 = tests/run.sh compilers/cv1-first-seen.

Usage (from the repo root): [ONLY=l0|l2|l3] python3 -I research/slice-030b-revert/mutate.py [id ...]   (no id: all)
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
WORKD = ROOT + "/.work"
# The roc cache of the repo (.work/cache) holds the platform: a new cache dir would need the network. Run scripts/test.sh check before, it prunes the object cache (TESTING.md 3.2).
ENV = dict(os.environ, XDG_CACHE_HOME=WORKD + "/cache", ROC_CACHE_DIR=WORKD + "/cache/roc", ROC=ROC, WORK=WORKD, CASE_TIMEOUT="60", JOBS="4")
REF = os.path.join(ROOT, "research/slice-030b-revert/reference")
STUBS = os.path.join(ROOT, "research/slice-030b-revert/stubs")
FA, NI, TO, RI = "cli/lib/Facts.roc", "cli/lib/Nightlies.roc", "cli/lib/Toolchain.roc", "cli/lib/RocInstall.roc"
TIMEOUT = {"l0": 120, "l2": 300, "l3": 600}
L2 = "tests/commands/run.sh roc/cv1-pins"
L2_OLD = "tests/commands/run.sh roc/cv1-pins roc/ri1-flow consent/dl3-rank4"

# id, rule, file, old text, new text, layers in order
M = [
    ("F01", "R-CV6", FA, "New => if !seen.any(|p| p.tag == listed.tag and p.target == listed.target) {\n\t\t\t\t\t$fresh = seen.append(listed)\n\t\t\t\t}", "New => {\n\t\t\t\t\t$fresh = seen.append(listed)\n\t\t\t\t}", "l0"),
    ("F02", "R-CV6", FA, "Changed(change) => {\n\t\t\t\t\t$changed = $changed.append(change)\n\t\t\t\t}", "Changed(_) => {}", "l0 l2"),
    ("F03", "R-CV6", FA, "Same => {}", "Same => {\n\t\t\t\t\t$fresh = seen.append(listed)\n\t\t\t\t}", "l0"),
    ("F04", "R-CV6", FA, "if run.listed.is_empty() {\n\t\t\tOk([])", "if run.listed.len() > 1000000 {\n\t\t\tOk([])", "l2_old"),
    ("F05", "R-CV6", FA, "if round.new.is_empty() {\n\t\t\t\t\t\tOk(round.changed)", "if round.new.is_empty() and round.changed.is_empty() {\n\t\t\t\t\t\tOk(round.changed)", "l2"),
    ("F06", "R-CV6", FA, "fx.db_write!(open, Pinned(round.new))", "fx.db_write!(open, Pinned(run.listed))", "l2"),
    ("F07", "R-CC8", FA, "Ok(_) => Ok(None)\n\t\t\t\t\tErr(fail) => Err(fail)\n\t\t\t\t}\n\t\t\t}\n\t\t\tmatch recorded", "Ok(_) => Ok(Some([]))\n\t\t\t\t\tErr(fail) => Err(fail)\n\t\t\t\t}\n\t\t\t}\n\t\t\tmatch recorded", "l2 l3"),
    ("F08", "R-CC8", FA, "Ok(_) => Ok(None)\n\t\t\t\t\tErr(fail) => Err(fail)\n\t\t\t\t}\n\t\t\t}\n\t\t\tmatch recorded", "Ok(_) => Err(Fail.new(Internal, \"x\"))\n\t\t\t\t\tErr(fail) => Err(fail)\n\t\t\t\t}\n\t\t\t}\n\t\t\tmatch recorded", "l2 l3"),
    ("F09", "R-TF3", FA, "Ok(_) => Ok(None)\n\t\t\t\t\tErr(fail) => Err(fail)\n\t\t\t\t}\n\t\t\t}\n\t\t\tmatch recorded", "Ok(_) => Ok(None)\n\t\t\t\t\tErr(_) => Ok(None)\n\t\t\t\t}\n\t\t\t}\n\t\t\tmatch recorded", "l2 l3"),
    ("F10", "R-CC8", FA, "Ok(_) => Ok(round.changed)\n\t\t\t\t\t\t\t\tErr(fail) => Err(fail)", "Ok(_) => Ok([])\n\t\t\t\t\t\t\t\tErr(fail) => Err(fail)", "l2"),
    ("F11", "R-CV6", FA, "keys = run.listed.map(|p| { tag: p.tag, target: p.target })", "keys = run.listed.map(|p| { tag: p.tag, target: \"any\" })", "l2"),
    ("F12", "R-CC8", FA, "match fx.db_write!(open, Pinned(round.new)) {\n\t\t\t\t\t\t\tOk(_) => Ok(round.changed)", "match fx.db_write!(open, Pinned(round.new)) {\n\t\t\t\t\t\t\tOk(_) => Ok(round.changed.keep_if(|c| c.now.tag != \"nightly-2026-10-13-91fa0c2\"))", "l2"),
    ("N01", "R-CV3", NI, "source: GithubDigest })\n\t\t\t\tErr(None) => Err(NoPin)", "source: Registry })\n\t\t\t\tErr(None) => Err(NoPin)", "l0"),
    ("N02", "R-CV4", NI, "Err(None) => Err(NoPin)\n\t\t\t}\n\t\t\tErr(_) => Err(NoPin)", "Err(None) => Ok({ tag: r.id, target: Nightlies.target(facts.host), sha256: \"\", source: GithubDigest })\n\t\t\t}\n\t\t\tErr(_) => Err(NoPin)", "l0"),
    ("N03", "R-CV8", NI, "Ok(hex) => Ok({ tag: r.id, target: Nightlies.target(facts.host)", "Ok(hex) => Ok({ tag: r.id, target: \"linux_x86_64\"", "l0"),
    ("N04", "R-CV6", NI, "facts.releases.keep_if(|r| !facts.changed.any(|c| c.now.tag == r.id))", "facts.releases", "l0 l2"),
    ("N05", "R-CV6", NI, "Ok({ releases: Nightlies.without_changed({ releases: list, changed }), source: found.source, changed })", "Ok({ releases: list, source: found.source, changed })", "l2 l3"),
    ("N06", "R-CV6", NI, "source: found.source, changed })\n\t\t\t}", "source: found.source, changed: [] })\n\t\t\t}", "l2 l3"),
    ("N07", "R-CV3", NI, "listed: Nightlies.pins({ host: facts.host, releases: list })", "listed: if found.source == Live Nightlies.pins({ host: facts.host, releases: list }) else []", "l2 l2_old"),
    ("T01", "R-CV6", TO, 'text = facts.text.drop_prefix("@")', "text = facts.text", "l0"),
    ("T02", "R-SC10", TO, "[one] => Ok(Facts.changed_fail(one))", "[_] => Err(NotNamed)", "l0 l2"),
    ("T03", "R-CV1", TO, "c.now.tag == text or same_tag(c.now.tag, text)", "c.now.tag == text or c.now.tag == \"x\"", "l0"),
    ("T04", "R-SC10", TO, "[one] => Ok(Facts.changed_fail(one))\n\t\t\t\t\t_ => Err(NotNamed)", "[one, ..] => Ok(Facts.changed_fail(one))\n\t\t\t\t\t_ => Err(NotNamed)", "l0"),
    ("T05", "R-CV6", TO, "if text.is_empty() {\n\t\t\tErr(NotNamed)", "if text == \"x-never\" {\n\t\t\tErr(NotNamed)", "l0"),
    ("T06", "R-CV6", TO, "(${Db.source_word(change.now.source)}). Talon does not offer this compiler.\"", "(${Db.source_word(change.now.source)}). Talon does not use this compiler.\"", "l0 l2"),
    ("T07", "R-CV6", TO, "first seen ${change.first.sha256} (${Db.source_word(change.first.source)}), now ${change.now.sha256} (${Db.source_word(change.now.source)}). Talon does not offer", "first seen ${change.first.sha256} (${Db.source_word(change.now.source)}), now ${change.now.sha256} (${Db.source_word(change.first.source)}). Talon does not offer", "l0"),
    ("R01", "R-CV6", RI, "Ok(fail) => return Err(fail)", "Ok(_) => return Err(Toolchain.pick_failed({ error, releases: found.releases, host: system, switch }))", "l2 l3"),
    ("R02", "R-CV6", RI, "Ok(picked) => {\n\t\t\t\twarn_changed!(fx, found.changed)\n\t\t\t\tpicked\n\t\t\t}", "Ok(picked) => picked", "l2 l3"),
    ("R03", "R-CV6", RI, "Ok(fail) => return Err(fail)", "Ok(fail) => {\n\t\t\t\t\twarn_changed!(fx, found.changed)\n\t\t\t\t\treturn Err(fail)\n\t\t\t\t}", "l2 l3"),
    ("R04", "R-CV6", RI, "Err(NotNamed) => {\n\t\t\t\t\twarn_changed!(fx, found.changed)\n\t\t\t\t\treturn Err(", "Err(NotNamed) => {\n\t\t\t\t\treturn Err(", "l2"),
    ("R05", "R-CV6", RI, "changed: found.changed }) {\n\t\t\t\tOk(fail)", "changed: [] }) {\n\t\t\t\tOk(fail)", "l2 l3"),
    ("A01", "R-CV6", NI, "Ok(b) => match facts.dropped.find_first(|r| r.id == b or same_nightly(r.id, b)) {", "Ok(b) => match facts.dropped.find_first(|r| r.id == \"x\" and b == \"y\") {", "l0 l2"),
    ("A02", "R-CV6", NI, "if r.id == held.id or facts.auto.contains(r.id) Ok(r.id)", "if r.id == held.id or facts.dropped.any(|d| d.id == r.id) or facts.auto.contains(r.id) Ok(r.id)", "l0 l2"),
    ("A03", "R-CV1", NI, "find_first(|r| r.id == b or same_nightly(r.id, b))", "find_first(|r| r.id == b)", "l0"),
    ("A04", "R-NS1", NI, "Nightlies.order(facts.releases.concat(facts.dropped)).keep_oks(", "facts.releases.concat(facts.dropped).keep_oks(", "l0"),
    ("A05", "R-CV6", RI, "steps = Nightlies.auto_with_base({ releases: found.releases, dropped: found.dropped, auto: lists.auto, base })", "steps = lists.auto", "l2"),
    ("A06", "R-CV6", NI, "dropped: list.keep_if(|r| changed.any(|c| c.now.tag == r.id)) })", "dropped: [] })", "l2"),
]


def sh(cmd, timeout):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=timeout)


def put(src):
    for name in ["Facts", "Nightlies", "Toolchain", "RocInstall"]:
        shutil.copy(os.path.join(src, "cli/lib", name + ".roc"), os.path.join(ROOT, "cli/lib", name + ".roc"))


def run_layer(layer):
    """Returns (failed, text)."""
    try:
        if layer == "l0":
            r = sh(f"{ROC} test tests/unit/pins.roc --no-cache", TIMEOUT["l0"])
            return r.returncode != 0, "unit/pins"
        if layer in ("l2", "l2_old"):
            cmd = L2 if layer == "l2" else L2_OLD
            r = sh(cmd, TIMEOUT["l2"])
            return r.returncode != 0, cmd.replace("tests/commands/run.sh ", "l2 ")
        r = sh("tests/run.sh compilers/cv1-first-seen", TIMEOUT["l3"])
        return r.returncode != 0, "l3 compilers/cv1-first-seen"
    except subprocess.TimeoutExpired:
        return True, f"{layer} timeout"


def main():
    want = sys.argv[1:]
    os.makedirs(WORKD, exist_ok=True)
    results = []
    try:
        for mid, rule, name, old, new, layers in M:
            if want and mid not in want:
                continue
            put(REF)
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
            caught = ""
            for layer in layers.split():
                if os.environ.get("ONLY") and layer != os.environ["ONLY"]:
                    continue
                failed, what = run_layer(layer)
                if failed:
                    caught = what
                    break
            state = "caught" if caught else "NOT CAUGHT"
            results.append((mid, rule, name, state, caught))
            print(mid, rule, name, state, caught, flush=True)
    finally:
        put(STUBS)
    out = "results.md" if not want else "results-partial.md"
    with open(os.path.join(ROOT, "research/slice-030b-revert", out), "w") as f:
        f.write("| Id | Rule | File | Result | First failing test |\n| --- | --- | --- | --- | --- |\n")
        for r in results:
            f.write("| " + " | ".join(r) + " |\n")


main()
