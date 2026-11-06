#!/usr/bin/env python3
"""Slice 206d2: the given and fx files of 2 new L2 cases (entry `commands`), not the expect files.
  tests/commands/cases/registry/sp24-update-held-move   R-SP16, R-SP23, R-SP24, R-AP16 (second query), Q404, Q460 in `tln update`
  tests/commands/cases/registry/dt3-update-range-log    R-DT3, R-AP19, R-CV1 in the compiler range step of `tln update`
  tests/commands/cases/registry/sp24-held-move-drop      R-AP3, R-SP24 (Design Q466): one second query in a command with a ladder drop
  tests/commands/cases/registry/ix6-offline-range       R-IX6, R-AP74 row 4 (Design Q467): --offline with a range and no toolchains.json
Run from the repo root: python3 -I research/slice-206d2-revert/mkcases.py [<cases dir> [<case name> ...]]
With case names, only those cases are made. It DELETES each case dir that it makes (expect/ and rules too): keep a copy before a run."""
import hashlib, json, os, shutil, sys, datetime

ROOT = os.getcwd()
CASES = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tests/commands/cases/registry")
ONLY = sys.argv[2:]


def want(name): return not ONLY or name in ONLY
AL2 = os.path.join(ROOT, "tests/commands/cases/registry/al2-update-query")
WIN = os.path.join(ROOT, "tests/commands/cases/registry/al2-update-window")
HOST = "127.0.0.1%3A9"
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n:
        n, r = divmod(n, 58); s = ALPHA[r] + s
    return s


def H(name): return b58(hashlib.sha256(b"slice206d2-" + name.encode()).digest())


def ms(day, hour=12):
    d = datetime.datetime.strptime(f"{day}T{hour:02d}:00:00", "%Y-%m-%dT%H:%M:%S").replace(tzinfo=datetime.timezone.utc)
    return int(d.timestamp()) * 1000


def form(repo): return f"github.com/acme/{repo}/releases/download/{{v}}/"
def gh(repo, v, h): return f"https://github.com/acme/{repo}/releases/download/{v}/{h}.tar.zst"


PF0 = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"   # pfx 0.1.0 (platform), as al2-update-query
JS0 = "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21"   # json 2.0.0
JS1 = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"   # json 2.1.0
PF1, PF2 = H("pfx-0.1.1"), H("pfx-0.1.2")
Y0, Y1, Y2 = H("yaml-1.0.0"), H("yaml-1.1.0"), H("yaml-1.2.0")
PFU = H("pfx-0.1.0-unknown")  # a pfx 0.1.0 that the registry does not know (u2: the anchor)
PLATFORM = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
PACKAGE = "package [Lib] {}\n"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def j(v): return json.dumps(v, separators=(",", ":"))


def series(v): return ".".join(v.split(".")[:2]) if v.startswith("0.") else v.split(".")[0]


def rel(repo, v, h, log, day):
    return {"log_index": log, "hash": h, "group": form(repo), "series": series(v), "version": v, "url": gh(repo, v, h), "tag": v,
            "roc_version": None, "repo": f"acme/{repo}", "published_at": ms(day), "yanked": False, "yank_reason": None,
            "withdrawn": None, "provenance": ["webhook"]}


def art(h, kind="package", pf=None):
    deps = []
    if pf:
        v, ph = pf
        deps = [{"alias": "pf", "hash": ph, "group": form("pfx"), "series": series(v), "version": v, "url": gh("pfx", v, ph), "is_platform": True}]
    return {"hash": h, "kind": kind, "exposed": [], "platform_hash": pf[1] if pf else None, "roc_pin": None, "size": 1000, "deps": deps,
            "target_names": ["x64musl"] if kind == "platform" else []}


def answer(rels, arts, log_size, unknown, checked):
    return {"artifacts": sorted(arts, key=lambda a: a["hash"]), "releases": rels, "epochs": [], "runs": [], "nearest": [], "hints": [],
            "log_size": log_size, "unknown": unknown,
            "checked": [{"name": f"acme/{r}", "checked_at": ms("2026-10-15"), "stale": False} for r in checked],
            "repos": [{"name": f"acme/{r}", "state": "active", "successor": None, "state_at": 1700000000000} for r in checked]}


CLOSURE_META = "status 200\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire-none authorization\n"


def common(d, src, pin=True):
    shutil.rmtree(d, ignore_errors=True)
    write(os.path.join(d, "entry"), "commands\n")
    write(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n")
    for f in os.listdir(os.path.join(src, "fx")):
        if f in ("gitdirs", "jobs", "path-roc", "programs"):
            shutil.copy(os.path.join(src, "fx", f), os.path.join(d, "fx", f))
    write(os.path.join(d, "given/home/.config/talon/config.toml"), 'registry = "http://127.0.0.1:9"\n')


def header(entries, pin=True):
    lines = "".join(f"\t{k}: {v},\n" for k, v in entries)
    roc = '\troc: "nightly-2026-10-14-38a3029",\n' if pin else ""
    return "app [main!] {\n" + lines + roc + "}\n\nmain! = |_args| Ok({})\n"


# ---------------------------------------------------------------- case 1: sp24-update-held-move
if want("sp24-update-held-move"):
    d = os.path.join(CASES, "sp24-update-held-move")
    common(d, AL2)
    write(os.path.join(d, "given/project/u1/main.roc"), header([
        ("pf", f'platform "{gh("pfx", "0.1.0", PF0)}"'),
        ("json", f'"{gh("json", "2.0.0", JS0)}"'),
        ("yaml", f'"{gh("yaml", "1.0.0", Y0)}"'),
    ]))
    write(os.path.join(d, "given/project/u2/main.roc"), header([
        ("pf", f'platform "{gh("pfx", "0.1.0", PFU)}"'),
        ("yaml", f'"{gh("yaml", "1.0.0", Y0)}"'),
    ]))
    # The archives of the header values. The facts of u1 come from the records of the answers; PFU (u2) is not in the registry, so its facts come from its archive (R-DI7).
    for h, text in ((PF0, PLATFORM), (JS0, PACKAGE), (Y0, PACKAGE), (PFU, PLATFORM)):
        write(os.path.join(d, f"given/home/.cache/roc/packages/{h}/main.roc"), text)
    # The privacy guard (R-RG4, R-RG5): each repository has a kept public answer, so the guard sends no request.
    for repo in ("json", "pfx", "yaml"):
        write(os.path.join(d, f"given/home/.cache/roc/talon/index/github/acme/{repo}/repo.json"), j({"id": 1, "full_name": f"acme/{repo}", "private": False}))
    yaml_rels = [rel("yaml", "1.0.0", Y0, 10, "2026-08-01"), rel("yaml", "1.1.0", Y1, 20, "2026-09-01"), rel("yaml", "1.2.0", Y2, 30, "2026-09-10")]
    yaml_arts = [art(Y0), art(Y1, pf=("0.1.1", PF1)), art(Y2, pf=("0.1.2", PF2))]
    # The first answer of u1: only the group of the free variable (yaml); the records of the 3 header hashes. log_size 40.
    first = answer(yaml_rels, yaml_arts + [art(PF0, "platform"), art(JS0)], 40, [], ["yaml"])
    # The second answer: the groups of the movable variables (pfx, json). pfx 0.1.2 has log 43: above the first log_size 40. log_size 45 (the log grew).
    second = answer([rel("pfx", "0.1.0", PF0, 2, "2026-07-01"), rel("pfx", "0.1.1", PF1, 38, "2026-09-20"), rel("pfx", "0.1.2", PF2, 43, "2026-09-25"),
                     rel("json", "2.0.0", JS0, 5, "2026-08-16"), rel("json", "2.1.0", JS1, 25, "2026-09-25")],
                    [art(PF0, "platform"), art(PF1, "platform"), art(PF2, "platform"), art(JS0), art(JS1)], 45, [], ["json", "pfx"])
    # The first answer of u2: PFU is unknown and no release of its group is in the answer: an anchor (R-AP28, R-DI11). log_size 50.
    first_u2 = answer(yaml_rels, yaml_arts, 50, [PFU], ["yaml"])
    v1 = os.path.join(d, "fx/http", HOST, "v1")
    # Run 1: POST 1, 2. Run 2: POST 3, 4. Run 3: POST 5, 6. Run 4 (u2): POST 7 only; POST 8 is there for a wrong second query (revert M8).
    for name, body in (("closure.POST", first), ("closure.POST.2", second), ("closure.POST.3", first), ("closure.POST.4", second),
                       ("closure.POST.5", first), ("closure.POST.6", second), ("closure.POST.7", first_u2), ("closure.POST.8", second)):
        write(os.path.join(v1, name), j(body))
        write(os.path.join(v1, name + ".meta"), CLOSURE_META)
    write(os.path.join(d, "fx/commands"),
          "update yaml@1.1.0 --no-check --dry-run --file u1/main.roc\n"
          "update yaml@1.1.0 --no-check --dry-run --snapshot log:30 --file u1/main.roc\n"
          "update yaml@1.2.0 --no-check --dry-run --file u1/main.roc\n"
          "update yaml@1.1.0 --no-check --dry-run --snapshot log:50 --file u2/main.roc\n")

# ---------------------------------------------------------------- case 2: dt3-update-range-log
if want("dt3-update-range-log"):
    d = os.path.join(CASES, "dt3-update-range-log")
    common(d, WIN)
    shutil.copytree(os.path.join(WIN, "given"), os.path.join(d, "given"), dirs_exist_ok=True)
    shutil.copytree(os.path.join(WIN, "fx/http"), os.path.join(d, "fx/http"), dirs_exist_ok=True)
    write(os.path.join(d, "given/project/u1/talon.toml"), '[toolchain]\nroc = ">=nightly-2026-10-10-0000000"\n')


    def tc(tag, day, log):
        date = tag.split("-", 1)[1].rsplit("-", 1)[0]
        sha = tag.rsplit("-", 1)[1]
        return {"tag": tag, "target": "linux_x86_64", "asset_name": f"roc_nightly-linux_x86_64-{date}-{sha}.tar.gz",
                "sha256": hashlib.sha256(tag.encode()).hexdigest(), "size": 1000 + log, "published_at": ms(day, 0), "log_index": log}


    rows = [tc("nightly-2026-10-11-1a2b3c4", "2026-10-11", 10), tc("nightly-2026-10-12-2664a27", "2026-10-12", 20), tc("nightly-2026-10-13-5e6f7a8", "2026-10-13", 40)]
    tv1 = os.path.join(d, "fx/http", HOST, "v1")
    write(os.path.join(tv1, "toolchains%3Fafter=0"), j({"toolchains": rows, "more": False}))
    write(os.path.join(tv1, "toolchains%3Fafter=0.meta"), "status 200\nheader content-type: application/json\nheader cache-control: max-age=300\n")
    write(os.path.join(tv1, "toolchains%3Fafter=40"), j({"toolchains": [], "more": False}))
    write(os.path.join(tv1, "toolchains%3Fafter=40.meta"), "status 200\nheader content-type: application/json\nheader cache-control: max-age=300\n")
    write(os.path.join(d, "fx/commands"),
          "update --no-check --dry-run --file u1/main.roc\n"
          "update --no-check --dry-run --snapshot log:30 --file u1/main.roc\n")

# ---------------------------------------------------------------- case 3: sp24-held-move-drop (Design Q466)
NEW_JSON0 = """── ✗ type mismatch ─ ../../../packages/%s/Wire.roc:3:15

This expression is used in an unexpected way.

encode = |s| s.count_utf8_bytes()
             ^^^^^^^^^^^^^^^^^^^^

It has the type:

    U64

But the annotation says it should be:

    Str

── 1 error and 0 warnings ───────────────────────────────────────────── main.roc
""" % JS0
if want("sp24-held-move-drop"):
    d = os.path.join(CASES, "sp24-held-move-drop")
    common(d, AL2)
    write(os.path.join(d, "given/project/u1/main.roc"), header([
        ("pf", f'platform "{gh("pfx", "0.1.0", PF0)}"'),
        ("json", f'"{gh("json", "2.0.0", JS0)}"'),
        ("yaml", f'"{gh("yaml", "1.0.0", Y0)}"'),
    ]))
    # The archives of every release that a tuple can have: the ladder checks the tuple with them.
    for h, text in ((PF0, PLATFORM), (PF1, PLATFORM), (JS0, PACKAGE), (JS1, PACKAGE), (Y0, PACKAGE), (Y1, PACKAGE)):
        write(os.path.join(d, f"given/home/.cache/roc/packages/{h}/main.roc"), text)
    for repo in ("json", "pfx", "yaml"):
        write(os.path.join(d, f"given/home/.cache/roc/talon/index/github/acme/{repo}/repo.json"), j({"id": 1, "full_name": f"acme/{repo}", "private": False}))
    first3 = answer([rel("yaml", "1.0.0", Y0, 10, "2026-08-01"), rel("yaml", "1.1.0", Y1, 20, "2026-09-01")],
                    [art(Y0), art(Y1, pf=("0.1.1", PF1)), art(PF0, "platform"), art(JS0)], 40, [], ["yaml"])
    second3 = answer([rel("pfx", "0.1.0", PF0, 2, "2026-07-01"), rel("pfx", "0.1.1", PF1, 38, "2026-09-20"),
                      rel("json", "2.0.0", JS0, 5, "2026-08-16"), rel("json", "2.1.0", JS1, 25, "2026-09-25")],
                     [art(PF0, "platform"), art(PF1, "platform"), art(JS0), art(JS1)], 45, [], ["json", "pfx"])
    v1 = os.path.join(d, "fx/http", HOST, "v1")
    # POST 1: the first query. POST 2: the second query. POST 3 answers a second query that the command must not send (Q466): the same second answer.
    for name, body in (("closure.POST", first3), ("closure.POST.2", second3), ("closure.POST.3", second3)):
        write(os.path.join(v1, name), j(body))
        write(os.path.join(v1, name + ".meta"), CLOSURE_META)
    # The ladder of the first tuple (yaml 1.1.0, pf 0.1.1, json 2.0.0): the baseline passes, the check of the candidate has a new error in acme/json 2.0.0. Then each probe passes.
    write(os.path.join(d, "fx/out/new-json0.stderr"), NEW_JSON0)
    write(os.path.join(d, "fx/out/empty"), "")
    write(os.path.join(d, "fx/probes"),
          "# the baseline of tuple 1 passes\n0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr\n"
          "# the check of tuple 1: a new error in acme/json 2.0.0 (the ladder drops the tuple)\n1\tout/empty\tout/new-json0.stderr\n")
    write(os.path.join(d, "fx/commands"), "update yaml@1.1.0 --no-probe --dry-run --file u1/main.roc\n")

# ---------------------------------------------------------------- case 4: ix6-offline-range (Design Q467)
if want("ix6-offline-range"):
    d = os.path.join(CASES, "ix6-offline-range")
    common(d, WIN)
    shutil.copytree(os.path.join(WIN, "given"), os.path.join(d, "given"), dirs_exist_ok=True)
    write(os.path.join(d, "given/project/u1/talon.toml"), '[toolchain]\nroc = ">=nightly-2026-10-10-0000000"\n')
    write(os.path.join(d, "fx/commands"), "update --no-check --dry-run --offline --file u1/main.roc\n")

# ---------------------------------------------------------------- case 5: so13-range-none (Design Q468)
if want("so13-range-none"):
    d = os.path.join(CASES, "so13-range-none")
    common(d, WIN)
    shutil.copytree(os.path.join(WIN, "given"), os.path.join(d, "given"), dirs_exist_ok=True)
    shutil.copytree(os.path.join(WIN, "fx/http"), os.path.join(d, "fx/http"), dirs_exist_ok=True)
    # The registry list is not empty (3 rows up to 2026-10-13), and the range starts after it.
    write(os.path.join(d, "given/project/u1/talon.toml"), '[toolchain]\nroc = ">=nightly-2026-10-20-0000000"\n')
    rows5 = [tc5 for tc5 in (
        {"tag": "nightly-2026-10-11-1a2b3c4", "log": 10, "day": "2026-10-11"},
        {"tag": "nightly-2026-10-12-2664a27", "log": 20, "day": "2026-10-12"},
        {"tag": "nightly-2026-10-13-5e6f7a8", "log": 40, "day": "2026-10-13"})]
    rows5 = [{"tag": r["tag"], "target": "linux_x86_64", "asset_name": f"roc_nightly-linux_x86_64-{r['tag'][8:18]}-{r['tag'][19:]}.tar.gz",
              "sha256": hashlib.sha256(r["tag"].encode()).hexdigest(), "size": 1000 + r["log"], "published_at": ms(r["day"], 0), "log_index": r["log"]} for r in rows5]
    tv1 = os.path.join(d, "fx/http", HOST, "v1")
    write(os.path.join(tv1, "toolchains%3Fafter=0"), j({"toolchains": rows5, "more": False}))
    write(os.path.join(tv1, "toolchains%3Fafter=0.meta"), "status 200\nheader content-type: application/json\nheader cache-control: max-age=300\n")
    write(os.path.join(d, "fx/commands"), "update --no-check --dry-run --file u1/main.roc\n")
