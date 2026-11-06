#!/usr/bin/env python3
"""Slice 206e2b: the given and fx files of the changed and new L2 cases (not the expect files).
  tests/commands/cases/registry/sp24-held-move-drop  (changed) R-CV1, R-IX4 D1: PickLoop.releases! reads the registry list when no pick read it
  tests/commands/cases/registry/cv1-held-offer       (new)     R-CV1, R-IX4 D1: D read first, the offer of the first probe uses the kept rows
  tests/commands/cases/registry/ix6-offline-upgrade  (new)     R-IX6 D2: `upgrade --offline` reads the kept toolchains.json
Run from the repo root: python3 -I research/slice-206e2b-revert/mkcases.py [<case name> ...]
It DELETES the dirs of the NEW cases (expect/ and rules too) and only adds the route to sp24-held-move-drop: keep a copy before a run."""
import datetime, hashlib, json, os, shutil, sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "127.0.0.1%3A9"
ONLY = sys.argv[1:]
FAKE_SHA = hashlib.sha256(b"fake").hexdigest()
TC_META = "status 200\nheader content-type: application/json\nheader cache-control: max-age=300\n"
DL_JOBS = ("# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod (as upgrade/ur1-roc). The first rule whose needle is in the arguments answers.\n"
           "curl --fail\t0\t-\t-\tfile:{out}\n"
           "tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details\n"
           "chmod 0755\t0\t-\t-\t-\n")


def want(name): return not ONLY or name in ONLY


def ms(day, hour=0):
    d = datetime.datetime.strptime(f"{day}T{hour:02d}:00:00", "%Y-%m-%dT%H:%M:%S").replace(tzinfo=datetime.timezone.utc)
    return int(d.timestamp()) * 1000


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def j(v): return json.dumps(v, separators=(",", ":"))


def tc(tag, day, log, sha=None):
    date = tag.split("-", 1)[1].rsplit("-", 1)[0]
    short = tag.rsplit("-", 1)[1]
    return {"tag": tag, "target": "linux_x86_64", "asset_name": f"roc_nightly-linux_x86_64-{date}-{short}.tar.gz",
            "sha256": sha or hashlib.sha256(tag.encode()).hexdigest(), "size": 1000 + log, "published_at": ms(day), "log_index": log}


def route(d, rows):
    v1 = os.path.join(d, "fx/http", HOST, "v1")
    write(os.path.join(v1, "toolchains%3Fafter=0"), j({"toolchains": rows, "more": False}))
    write(os.path.join(v1, "toolchains%3Fafter=0.meta"), TC_META)


def fresh(name, src):
    d = os.path.join(CASES, name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    for part in ("entry", "fx", "given"):
        p = os.path.join(src, part)
        if os.path.isdir(p): shutil.copytree(p, os.path.join(d, part))
        else: shutil.copy(p, os.path.join(d, part))
    return d


# ------------------------------------------------ sp24-held-move-drop: the registry list, not the GitHub list
if want("sp24-held-move-drop"):
    d = os.path.join(CASES, "sp24-held-move-drop")
    # H (38a3029, on PATH) is not in the list: the domain D is [H], as with the old (unreadable) GitHub list, so the probes and the facts do not change.
    route(d, [tc("nightly-2026-10-11-1a2b3c4", "2026-10-11", 10), tc("nightly-2026-10-12-2664a27", "2026-10-12", 20)])

# ------------------------------------------------ cv1-held-offer: the pin H is not installed, nothing read the list before D
if want("cv1-held-offer"):
    d = fresh("cv1-held-offer", os.path.join(CASES, "cv1-held-pick"))
    p = os.path.join(d, "given/project/u1/main.roc")
    text = open(p).read()
    assert "roc:" not in text
    open(p, "w").write(text.replace("\n}\n", '\n\troc: "nightly-2026-10-13-5e6f7a8",\n}\n', 1))
    # the same rows as cv1-held-pick (route already in the copy)

# ------------------------------------------------ ix6-offline-upgrade: --offline, a registry, a kept toolchains.json
if want("ix6-offline-upgrade"):
    d = fresh("ix6-offline-upgrade", os.path.join(CASES, "ix6-update-offline"))
    write(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-20T12:00:00Z\n")
    rows = [tc("nightly-2026-10-12-2664a27", "2026-10-12", 10), tc("nightly-2026-10-14-38a3029", "2026-10-14", 20)]
    write(os.path.join(d, "given/home/.cache/roc/talon/index/registry/http_127.0.0.1_9/toolchains.json"), j({"format": 1, "rows": rows}))
    write(os.path.join(d, "fx/commands"), "upgrade --dry-run --offline --file u1/main.roc\n")
