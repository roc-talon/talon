#!/usr/bin/env python3
"""Revert check of slice 023b (TW12): small mutations of the private reference, each run with the tests that should catch it.
Usage: research/slice-023b-revert/mutate.py [id ...]   (no id: all). The reference must be in cli/ (a private copy of the reference, now deleted).
The file is put back after each run. Result: research/slice-023b-revert/results.md.
Layers: l0p = tests/unit/proxy.roc, l0c = tests/unit/consent.roc, l2 = tests/commands/run.sh proxy/ roc/ri1-flow, l3 = tests/run.sh px2-proxy-install
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
os.chdir(ROOT)
ROC = f"{ROOT}/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"
ENV = dict(os.environ, XDG_CACHE_HOME=f"{ROOT}/.work/cache", ROC_CACHE_DIR=f"{ROOT}/.work/cache/roc", ROC=ROC)

P = "cli/lib/Proxy.roc"
C = "cli/lib/Consent.roc"
R = "cli/lib/RocInstall.roc"
M = [
    ("A1", P, 'Ok((_, "yes")) => Yes', 'Ok((_, "yes")) => Ask', "l0p l2 l3"),
    ("A2", P, 'Ok((_, "no")) => No', 'Ok((_, "no")) => Ask', "l0p l2 l3"),
    ("A3", P, 'Err(_) | Ok((_, "ask")) => Ask', 'Err(_) => Yes\n\t\tOk((_, "ask")) => Ask', "l0p l2 l3"),
    ("A4", P, 'Ok(_) => Ask', 'Ok(_) => Yes', "l0p l2 l3"),
    ("A5", P, 'Ok((_, "yes")) => Yes', 'Ok((_, "yes")) | Ok((_, "YES")) => Yes', "l0p"),
    ("W1", P, '(Bool.False, _, _) => Refuse', '(Bool.False, Ask, _) => Refuse\n\t\t(Bool.False, _, _) => Install', "l0p l2"),
    ("W2", P, '(_, No, _) => Refuse', '(_, No, _) => Ask', "l0p l2"),
    ("W3", P, '(_, Yes, _) => Install', '(_, Yes, Interactive) => Ask\n\t\t(_, Yes, _) => Install', "l0p l2"),
    ("W4", P, '(_, Yes, _) => Install', '(_, Yes, NeedsTty) => NeedTty\n\t\t(_, Yes, _) => Install', "l0p l2"),
    ("W5", P, '(_, Ask, NonInteractive) => Refuse', '(_, Ask, NonInteractive) => Install', "l0p l2 l3"),
    ("W6", P, '(_, Ask, NeedsTty) => NeedTty', '(_, Ask, NeedsTty) => Ask', "l0p l2"),
    ("W7", P, 'Pin.is_nightly(run.id)', 'Pin.is_id(run.id)', "l0p"),
    ("W8", P, '(_, Ask, Interactive) => Ask', '(_, Ask, Interactive) => Refuse', "l0p l2"),
    ("D1", P, 'if wanted == Refuse return Err(Proxy.missing({ id: run.id, rank: run.rank }))', '', "l2 l3"),
    ("D2", P, 'flag = if wanted == Install Ok(Yes) else Err(NoFlag)', 'flag = Err(NoFlag)', "l2 l3"),
    ("D3", P, 'if asked.answer != Yes return Err(Consent.roc_install_declined(d.id))', 'if asked.answer != Yes and Bool.False return Err(Consent.roc_install_declined(d.id))', "l2"),
    ("D4", P, 'source: source_text({ id: run.id, rank: run.rank })', 'source: "the roc on PATH"', "l2"),
    ("D5", P, 'Prompt.ask!(fx, prompt, { mode, yes: Bool.False', 'Prompt.ask!(fx, prompt, { mode: if wanted == Ask NonInteractive else mode, yes: Bool.False', "l2"),
    ("D6", P, '(installed.contains(run_id) or chosen.state == Missing)', '(installed.contains(run_id))', "l2 l3"),
    ("D7", P, 'offline: Bool.False })?\n\tmatch offer', 'offline: Bool.True })?\n\tmatch offer', "l2 l3"),
    ("D8", P, 'run_id = if chosen.state == Missing download!(fx, { env, roots, id: chosen.id, rank: chosen.rank })? else chosen.id', 'run_id = chosen.id', "l2 l3"),
    ("I1", R, 'if has_dir(entries, ctx.id) return Ok({ how: Present, compat: Err(Unknown) })', '', "l3"),
    ("I2", R, 'Installed => set_default!(fx, ctx.roots, ctx.id)?', 'Installed => Kept', "l2 l3"),
    ("I3", R, 'Ok(Download({ id, size: asset.size, ctx }))', 'Ok(Download({ id, size: 0, ctx }))', "l2"),
    ("I4", R, 'locked = match fx.with_lock!(ctx.item, Wait, || install!(fx, ctx, dir)) {', 'locked = match fx.with_lock!(ctx.item, NoWait, || install!(fx, ctx, dir)) {', "l2 l3"),
    ("I5", R, 'Err(Busy) => return Err(Fail.new(Internal, "the lock of ${ctx.item} was not taken"))\n\t\t}\n\t\tdefault', 'Err(Busy) => return Err(Fail.new(Internal, "the lock of ${ctx.item} was not taken"))\n\t\t}\n\t\t_ = fx.out!("installed ${ctx.id}\\n")\n\t\tdefault', "l2 l3"),
    ("I6", R, 'if has_dir(entries, id) return Ok(Present({ id: id }))', '', "l2 l3"),
    ("C1", C, 'default: Yes,\n\t\t\tquestion: "${facts.id} (${facts.source})', 'default: No,\n\t\t\tquestion: "${facts.id} (${facts.source})', "l0c l2"),
    ("C2", C, 'kind: Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"])', 'kind: Required(["TALON_AUTO_INSTALL=yes"])', "l0c"),
    ("C3", C, 'is not installed. Download 1 compiler, ${size}?"', 'is not installed. Download ${size}?"', "l0c l2"),
    ("C4", C, 'if answer == Yes "downloading ${facts.id} (${size})" else "no download of ${facts.id}",\n\t\t}\n\t}\n\n\t## The failure of a picker', 'if answer == Yes "download of ${facts.id} (${size})" else "no download of ${facts.id}",\n\t\t}\n\t}\n\n\t## The failure of a picker', "l0c l2 l3"),
    ("C5", C, 'id: "proxy-download"', 'id: "roc-install"', "l0c"),
    ("C6", C, 'shape: YesNo,\n\t\t\tdefault: Yes,\n\t\t\tquestion: "${facts.id} (${facts.source})', 'shape: YesNo,\n\t\t\tdefault: Yes,\n\t\t\tquestion: "${facts.id}', "l0c l2"),
]


def run(cmd):
    r = subprocess.run(cmd, shell=True, env=ENV, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def layers_failed(layers):
    failed = []
    for layer in layers.split():
        if layer == "l0p":
            rc, out = run(f"{ROC} test tests/unit/proxy.roc --no-cache")
        elif layer == "l0c":
            rc, out = run(f"{ROC} test tests/unit/consent.roc --no-cache")
        elif layer == "l2":
            rc, out = run("tests/commands/run.sh proxy/ roc/ri1-flow")
        else:
            rc, out = run("tests/run.sh px2-proxy-install")
        if rc != 0:
            failed.append(layer)
    return failed


def main():
    want = sys.argv[1:]
    rows = []
    for (mid, path, old, new, layers) in M:
        if want and mid not in want:
            continue
        text = open(path).read()
        if old not in text:
            rows.append((mid, path, "NOT APPLIED (text not found)", ""))
            print(mid, "NOT APPLIED")
            continue
        shutil.copy(path, "/tmp/mutate23b.keep")
        open(path, "w").write(text.replace(old, new, 1))
        try:
            # a mutation must compile with no warning (roc build exits 2 on a warning), else a failure shows nothing
            rc, out = run(f"{ROC} check cli/lib/main.roc && {ROC} check cli/main.roc")
            failed = layers_failed(layers) if rc == 0 else None
        finally:
            shutil.copy("/tmp/mutate23b.keep", path)
        status = "INVALID (does not compile cleanly)" if failed is None else ("caught by " + " ".join(failed) if failed else "NOT CAUGHT")
        rows.append((mid, path, status, layers))
        print(mid, status, flush=True)
    out = "research/slice-023b-revert/results.md"
    old = {}
    if os.path.exists(out):
        for line in open(out).read().split("\n")[2:]:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) == 4:
                old[cells[0]] = tuple(cells)
    for r in rows:
        old[r[0]] = r
    order = [m[0] for m in M]
    merged = [old[i] for i in order if i in old]
    with open(out, "w") as f:
        f.write("| Id | File | Result | Layers run |\n| --- | --- | --- | --- |\n")
        for r in merged:
            f.write("| %s | %s | %s | %s |\n" % tuple(r))
    caught = sum(1 for r in merged if r[2].startswith("caught"))
    print(f"caught {caught} of {len(merged)}")


main()
