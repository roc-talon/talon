#!/usr/bin/env python3
"""Slice 206e2: the given and fx files of 4 new L2 cases (entry `commands`), not the expect files.
  tests/commands/cases/registry/cv1-upgrade-free       R-CV1, R-AP16 (`Free` window), R-IX4 in `tln upgrade roc` (NightlyFlow, offer!)
  tests/commands/cases/registry/cv1-held-pick          R-CV1, R-SO14, R-SO23 in `tln update` with no compiler (HeldRoc.picked!, the offer! of the first probe)
  tests/commands/cases/registry/cv1-outdated-query     R-CV1, R-AP16 (`groups` of outdated, `Report` window), R-AP74 row 4 in `tln outdated`
  tests/commands/cases/registry/sp24-ingest-held-move  Design Q460: an R-AP28 case 2 ingest and a held move in one `tln update`
Run from the repo root: python3 -I research/slice-206e2-revert/mkcases.py [<case name> ...]
It DELETES each case dir that it makes (expect/ and rules too): keep a copy before a run."""
import datetime, hashlib, json, os, shutil, sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
AL2 = os.path.join(CASES, "al2-update-query")
WIN = os.path.join(CASES, "al2-update-window")
HOST = "127.0.0.1%3A9"
ONLY = sys.argv[1:]
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
FAKE_SHA = hashlib.sha256(b"fake").hexdigest()  # the bytes that the fake curl writes (FakeBase.create_item!)
CLOSURE_META = "status 200\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire-none authorization\n"
TC_META = "status 200\nheader content-type: application/json\nheader cache-control: max-age=300\n"
DL_JOBS = ("# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod (as upgrade/ur1-roc). The first rule whose needle is in the arguments answers.\n"
           "curl --fail\t0\t-\t-\tfile:{out}\n"
           "tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details\n"
           "chmod 0755\t0\t-\t-\t-\n")


def want(name): return not ONLY or name in ONLY


def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n:
        n, r = divmod(n, 58); s = ALPHA[r] + s
    return s


def H(name): return b58(hashlib.sha256(b"slice206e2-" + name.encode()).digest())


def ms(day, hour=12):
    d = datetime.datetime.strptime(f"{day}T{hour:02d}:00:00", "%Y-%m-%dT%H:%M:%S").replace(tzinfo=datetime.timezone.utc)
    return int(d.timestamp()) * 1000


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def j(v): return json.dumps(v, separators=(",", ":"))


def copy_case(name, src):
    d = os.path.join(CASES, name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    for part in ("entry", "fx", "given"):
        p = os.path.join(src, part)
        if os.path.isdir(p):
            shutil.copytree(p, os.path.join(d, part))
        else:
            shutil.copy(p, os.path.join(d, part))
    shutil.rmtree(os.path.join(d, "fx/http/localhost%3A9"), ignore_errors=True)
    return d


def tc(tag, day, log, hour=0, sha=None):
    date = tag.split("-", 1)[1].rsplit("-", 1)[0]
    short = tag.rsplit("-", 1)[1]
    return {"tag": tag, "target": "linux_x86_64", "asset_name": f"roc_nightly-linux_x86_64-{date}-{short}.tar.gz",
            "sha256": sha or hashlib.sha256(tag.encode()).hexdigest(), "size": 1000 + log, "published_at": ms(day, hour), "log_index": log}


def toolchains(d, after, rows):
    v1 = os.path.join(d, "fx/http", HOST, "v1")
    write(os.path.join(v1, f"toolchains%3Fafter={after}"), j({"toolchains": rows, "more": False}))
    write(os.path.join(v1, f"toolchains%3Fafter={after}.meta"), TC_META)


def commands(d, lines): write(os.path.join(d, "fx/commands"), "\n".join(lines) + "\n")


# ---------------------------------------------------------------- cv1-upgrade-free
if want("cv1-upgrade-free"):
    d = copy_case("cv1-upgrade-free", AL2)
    # H = nightly-2026-10-14-38a3029: the roc: pin and the roc on PATH (fx/path-roc). The clock is 2026-10-20T12:00:00Z.
    write(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-20T12:00:00Z\nCI=true\n")
    write(os.path.join(d, "fx/jobs"), DL_JOBS + "version\t0\tRoc compiler version nightly-2026-10-14-38a3029\t-\t-\n")
    write(os.path.join(d, "fx/programs"), "roc\ncurl\n")
    rows = [tc("nightly-2026-10-12-2664a27", "2026-10-12", 10),
            tc("nightly-2026-10-14-38a3029", "2026-10-14", 20),
            # N: the newest compiler that min-release-age (2 days) allows. Its sha256 is the one of the bytes of the fake download.
            tc("nightly-2026-10-16-5e6f7a8", "2026-10-16", 40, sha=FAKE_SHA),
            # 1.5 days old at the clock: min-release-age hides it.
            tc("nightly-2026-10-19-9a8b7c6", "2026-10-19", 45)]
    toolchains(d, 0, rows)
    toolchains(d, 45, [])
    commands(d, ["upgrade roc --dry-run --file u1/main.roc",
                 "upgrade roc --dry-run --snapshot log:30 --file u1/main.roc"])

# ---------------------------------------------------------------- cv1-held-pick
if want("cv1-held-pick"):
    d = copy_case("cv1-held-pick", WIN)
    shutil.rmtree(os.path.join(d, "given/project/u1/talon.toml"), ignore_errors=True)
    for f in ("jobs", "programs"):
        shutil.copy(os.path.join(AL2, "fx", f), os.path.join(d, "fx", f))
    write(os.path.join(d, "fx/jobs"), DL_JOBS)
    write(os.path.join(d, "fx/programs"), "curl\n")
    for h in os.listdir(os.path.join(AL2, "given/home/.cache/roc/packages")):
        dst = os.path.join(d, "given/home/.cache/roc/packages", h)
        if not os.path.exists(dst):
            shutil.copytree(os.path.join(AL2, "given/home/.cache/roc/packages", h), dst)
    rows = [tc("nightly-2026-10-11-1a2b3c4", "2026-10-11", 10),
            tc("nightly-2026-10-12-2664a27", "2026-10-12", 20),
            tc("nightly-2026-10-13-5e6f7a8", "2026-10-13", 40, sha=FAKE_SHA)]
    toolchains(d, 0, rows)
    commands(d, ["update --no-probe --dry-run --yes --file u1/main.roc"])

# ---------------------------------------------------------------- cv1-outdated-query
if want("cv1-outdated-query"):
    d = copy_case("cv1-outdated-query", AL2)
    rows = [tc("nightly-2026-10-11-1a2b3c4", "2026-10-11", 10),
            tc("nightly-2026-10-12-2664a27", "2026-10-12", 20),
            tc("nightly-2026-10-13-5e6f7a8", "2026-10-13", 40)]
    toolchains(d, 0, rows)
    toolchains(d, 40, [])
    commands(d, ["outdated --file u1/main.roc",
                 "env:TALON_NIGHTLY=0 outdated --json --file u1/main.roc"])

# ---------------------------------------------------------------- sp24-ingest-held-move (Design Q460)
PF0 = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"
JS0 = "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21"
JS1 = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"
PF1, PF2 = H("pfx-0.1.1"), H("pfx-0.1.2")
Y0, Y1 = H("yaml-1.0.0"), H("yaml-1.1.0")
PLATFORM = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
PACKAGE = "package [Lib] {}\n"


def form(repo): return f"github.com/acme/{repo}/releases/download/{{v}}/"
def gh(repo, v, h): return f"https://github.com/acme/{repo}/releases/download/{v}/{h}.tar.zst"
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


if want("sp24-ingest-held-move"):
    d = os.path.join(CASES, "sp24-ingest-held-move")
    shutil.rmtree(d, ignore_errors=True)
    write(os.path.join(d, "entry"), "commands\n")
    write(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n")
    for f in ("gitdirs", "jobs", "path-roc"):
        shutil.copy(os.path.join(AL2, "fx", f), os.path.join(d, "fx", f))
    write(os.path.join(d, "fx/programs"), "roc\ncurl\n")
    write(os.path.join(d, "given/home/.config/talon/config.toml"), 'registry = "http://127.0.0.1:9"\n')
    write(os.path.join(d, "given/project/u1/main.roc"),
          "app [main!] {\n"
          f'\tpf: platform "{gh("pfx", "0.1.0", PF0)}",\n'
          f'\tjson: "{gh("json", "2.0.0", JS0)}",\n'
          f'\tyaml: "{gh("yaml", "1.0.0", Y0)}",\n'
          '\troc: "nightly-2026-10-14-38a3029",\n'
          "}\n\nmain! = |_args| Ok({})\n")
    for h, text in ((PF0, PLATFORM), (JS0, PACKAGE), (Y0, PACKAGE)):
        write(os.path.join(d, f"given/home/.cache/roc/packages/{h}/main.roc"), text)
    for repo in ("json", "pfx", "yaml"):
        write(os.path.join(d, f"given/home/.cache/roc/talon/index/github/acme/{repo}/repo.json"), j({"id": 1, "full_name": f"acme/{repo}", "private": False}))
    yaml_rels = [rel("yaml", "1.0.0", Y0, 10, "2026-08-01"), rel("yaml", "1.1.0", Y1, 20, "2026-09-01")]
    yaml_arts = [art(Y0), art(Y1, pf=("0.1.1", PF1))]
    # POST 1, the first query: json 2.0.0 (JS0) is unknown (R-AP28 case 2: a public github.com URL, no log snapshot). log_size 50.
    first = answer(yaml_rels, yaml_arts + [art(PF0, "platform")], 50, [JS0], ["yaml"])
    # POST 2, the query again after the ingest (settle!): JS0 is indexed at log 52. log_size 52. "The first answer" of the held move is this answer (Q460).
    settled = answer(yaml_rels + [rel("json", "2.0.0", JS0, 52, "2026-08-16")], yaml_arts + [art(PF0, "platform"), art(JS0)], 52, [], ["json", "yaml"])
    # POST 3, the second query of the held move: pfx 0.1.1 has log 51 (kept by log_size 52, hidden by the 50 of POST 1); pfx 0.1.2 has log 53 (hidden). log_size 55.
    second = answer([rel("pfx", "0.1.0", PF0, 2, "2026-07-01"), rel("pfx", "0.1.1", PF1, 51, "2026-09-20"), rel("pfx", "0.1.2", PF2, 53, "2026-09-25"),
                     rel("json", "2.0.0", JS0, 52, "2026-08-16"), rel("json", "2.1.0", JS1, 25, "2026-09-25")],
                    [art(PF0, "platform"), art(PF1, "platform"), art(PF2, "platform"), art(JS0), art(JS1)], 55, [], ["json", "pfx"])
    v1 = os.path.join(d, "fx/http", HOST, "v1")
    for name, body in (("closure.POST", first), ("closure.POST.2", settled), ("closure.POST.3", second)):
        write(os.path.join(v1, name), j(body))
        write(os.path.join(v1, name + ".meta"), CLOSURE_META)
    write(os.path.join(v1, "releases.POST"), j({"status": "indexed"}))
    write(os.path.join(v1, "releases.POST.meta"), "status 201\nheader Content-Type: application/json\nheader Talon-Bookmark: 00000034-00000010-00004c60-8e61\n"
          "require content-type: application/json\nrequire-none authorization\nrequire-none talon-contributor\n")
    commands(d, ["update yaml@1.1.0 --no-check --dry-run --file u1/main.roc"])

# ---------------------------------------------------------------- cv1-upgrade-unread (Design Q489, round 2)
if want("cv1-upgrade-unread"):
    # The project, packages and closure answer of registry/al2-upgrade-query (json 3.0.0 in the answer). No route for /v1/toolchains: the list read gets 404, an error answer.
    d = copy_case("cv1-upgrade-unread", os.path.join(CASES, "al2-upgrade-query"))
    shutil.rmtree(os.path.join(d, "expect"), ignore_errors=True)
    shutil.rmtree(os.path.join(d, "rules"), ignore_errors=True)
    commands(d, ["upgrade --dry-run --file u1/main.roc",
                 "upgrade roc --dry-run --file u1/main.roc"])
