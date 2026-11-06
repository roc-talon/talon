#!/usr/bin/env python3
"""Slice 206d: the given and fx files of 2 L2 cases (entry `commands`), not the expect files.
  tests/commands/cases/registry/ap28-update-unknown   R-AP28, R-AP65, R-DI7, R-DI11, R-C9 in `tln update`
  tests/commands/cases/registry/ix6-update-offline    R-IX6 in `tln update --offline` with a registry
Run from the repo root: python3 -I research/slice-206d-revert/mkcases.py [<cases dir>]
It DELETES each case dir first (expect/ and rules too): keep a copy before a run."""
import hashlib, json, os, shutil, sys

ROOT = os.getcwd()
CASES = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tests/commands/cases/registry")
AL2 = os.path.join(ROOT, "tests/commands/cases/registry/al2-update-query")
HOST = "127.0.0.1%3A9"
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n:
        n, r = divmod(n, 58); s = ALPHA[r] + s
    return s


def H(name): return b58(hashlib.sha256(b"slice206d-" + name.encode()).digest())


def ms(day):
    import datetime
    d = datetime.datetime.strptime(day + "T12:00:00", "%Y-%m-%dT%H:%M:%S").replace(tzinfo=datetime.timezone.utc)
    return int(d.timestamp()) * 1000


def form(repo, tag="{v}"): return f"github.com/acme/{repo}/releases/download/{tag}/"
def gh(repo, v, h, tag=None): return f"https://github.com/acme/{repo}/releases/download/{tag or v}/{h}.tar.zst"


# The hashes of al2-update-query (their archives are in the given home there).
PF0 = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"   # pfx 0.1.0 (platform)
JS0 = "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21"   # json 2.0.0
JS1 = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"   # json 2.1.0
PA0 = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc"   # parser 1.0.0
PA2 = "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt"   # parser 1.2.0
PLATFORM = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
PACKAGE = "package [Lib] {}\n"
# New values of this slice.
PAX = H("parser-other")  # the registry's parser 1.0.0 with another hash (R-AP28 case 1, R-AP65 source 1)
CSV = H("csv-0.5.0")
YML = H("yaml-1.0.0")
EXO = H("example-1.0.0")
URL_CSV = gh("csv", "0.5.0", CSV)
URL_YML = gh("yaml", "1.0.0", YML)
URL_EXO = f"https://example.org/acme/other/releases/download/1.0.0/{EXO}.tar.zst"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def j(v): return json.dumps(v, separators=(",", ":"))


def rel(repo, v, h, log, day, kind="package", series=None):
    return {"log_index": log, "hash": h, "group": form(repo), "series": series or (".".join(v.split(".")[:2]) if v.startswith("0.") else v.split(".")[0]),
            "version": v, "url": gh(repo, v, h), "tag": v, "roc_version": None, "repo": f"acme/{repo}", "published_at": ms(day),
            "yanked": False, "yank_reason": None, "withdrawn": None, "provenance": ["webhook"]}


def art(h, kind="package"):
    return {"hash": h, "kind": kind, "exposed": [], "platform_hash": None, "roc_pin": None, "size": 1000, "deps": [],
            "target_names": ["x64musl"] if kind == "platform" else []}


def answer(rels, arts, log_size, unknown, checked):
    return {"artifacts": sorted(arts, key=lambda a: a["hash"]), "releases": rels, "epochs": [], "runs": [], "nearest": [], "hints": [], "log_size": log_size,
            "unknown": unknown, "checked": [{"name": f"acme/{r}", "checked_at": ms("2026-10-15"), "stale": False} for r in checked],
            "repos": [{"name": f"acme/{r}", "state": "active", "successor": None, "state_at": 1700000000000} for r in checked]}


CLOSURE_META = "status 200\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire-none authorization\n"


def ingest_meta(status, headers=(), problem=False):
    meta = f"status {status}\nheader Content-Type: {'application/problem+json' if problem else 'application/json'}\n"
    for h in headers:
        meta += f"header {h}\n"
    return meta + "require content-type: application/json\nrequire-none authorization\nrequire-none talon-contributor\n"


def common(d, programs):
    shutil.rmtree(d, ignore_errors=True)
    write(os.path.join(d, "entry"), "commands\n")
    write(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n")
    for f in ("gitdirs", "jobs", "path-roc"):
        shutil.copy(os.path.join(AL2, "fx", f), os.path.join(d, "fx", f))
    write(os.path.join(d, "fx/programs"), programs)
    write(os.path.join(d, "given/home/.config/talon/config.toml"), 'registry = "http://127.0.0.1:9"\n')
    for h, text in ((PF0, PLATFORM), (JS0, PACKAGE), (JS1, PACKAGE), (PA0, PACKAGE), (PA2, PACKAGE)):
        write(os.path.join(d, f"given/home/.cache/roc/packages/{h}/main.roc"), text)


def header(entries):
    lines = "".join(f"\t{k}: {v},\n" for k, v in entries)
    return "app [main!] {\n" + lines + '\troc: "nightly-2026-10-14-38a3029",\n}\n\nmain! = |_args| Ok({})\n'


# ---------------------------------------------------------------- case 1: ap28-update-unknown
d = os.path.join(CASES, "ap28-update-unknown")
common(d, "roc\ncurl\n")
write(os.path.join(d, "given/project/u1/main.roc"), header([
    ("pf", f'platform "{gh("pfx", "0.1.0", PF0)}"'),
    ("json", f'"{gh("json", "2.0.0", JS0)}"'),
    ("parser", f'"{gh("parser", "1.0.0", PA0)}"'),
    ("csv", f'"{URL_CSV}"'),
    ("yaml", f'"{URL_YML}"'),
    ("other", f'"{URL_EXO}"'),
]))
for h in (CSV, YML, EXO):
    write(os.path.join(d, f"given/home/.cache/roc/packages/{h}/main.roc"), PACKAGE)
# The privacy guard (R-RG4, R-RG5): each github.com repository has a kept public answer, so the guard sends no request.
for repo in ("csv", "json", "parser", "pfx", "yaml"):
    write(os.path.join(d, f"given/home/.cache/roc/talon/index/github/acme/{repo}/repo.json"), j({"id": 1, "full_name": f"acme/{repo}", "private": False}))
base_rels = [
    rel("pfx", "0.1.0", PF0, 2, "2026-07-01", series="0.1"),
    rel("parser", "1.0.0", PAX, 5, "2026-07-17"),     # the label of the header value with another hash
    rel("parser", "1.2.0", PA2, 35, "2026-10-05"),
]
base_arts = [art(PF0, "platform"), art(PAX), art(PA2)]
UNKNOWN1 = [JS0, PA0, CSV, YML, EXO]  # the order of `hashes` (R-AP59): the header order
first = answer(base_rels, base_arts, 50, UNKNOWN1, ["parser", "pfx"])
# The second query (R-AP28 case 2): the ingest of json indexed json 2.0.0 at log 51.
second = answer(base_rels + [rel("json", "2.0.0", JS0, 51, "2026-08-16")], base_arts + [art(JS0)], 51, [PA0, CSV, YML, EXO], ["json", "parser", "pfx"])
v1 = os.path.join(d, "fx/http", HOST, "v1")
# Run 1: POST 1 (first query), POST 2 (the second query of R-AP28). Run 2 (--snapshot log:40): POST 3 (the first query again, no second query).
# Run 3 (--snapshot log:30, Design Q461): POST 4. The snapshot hides parser 1.2.0 (log 35), so the only parser row is the registry's 1.0.0 with another hash: the pick drops it and keeps the header URL.
for name, body in (("closure.POST", first), ("closure.POST.2", second), ("closure.POST.3", first), ("closure.POST.4", first)):
    write(os.path.join(v1, name), j(body))
    write(os.path.join(v1, name + ".meta"), CLOSURE_META)
# The ingests of run 1, in the order of `unknown`: json 201 with a bookmark, csv 422, yaml 409 label-conflict.
write(os.path.join(v1, "releases.POST"), j({"status": "indexed"}))
write(os.path.join(v1, "releases.POST.meta"), ingest_meta(201, ["Talon-Bookmark: 00000033-00000010-00004c60-8e61"]))
write(os.path.join(v1, "releases.POST.2"), j({"type": "/errors/not-a-candidate", "title": "Unprocessable", "status": 422, "detail": "x"}))
write(os.path.join(v1, "releases.POST.2.meta"), ingest_meta(422, problem=True))
write(os.path.join(v1, "releases.POST.3"), j({"type": "/errors/label-conflict", "title": "Conflict", "status": 409, "detail": "x"}))
write(os.path.join(v1, "releases.POST.3.meta"), ingest_meta(409, problem=True))
write(os.path.join(d, "fx/commands"), "update --no-check --dry-run --file u1/main.roc\nupdate --no-check --dry-run --snapshot log:40 --file u1/main.roc\nupdate --no-check --dry-run --snapshot log:30 --file u1/main.roc\n")

# ---------------------------------------------------------------- case 2: ix6-update-offline
d = os.path.join(CASES, "ix6-update-offline")
common(d, "roc\n")
write(os.path.join(d, "given/project/u1/main.roc"), header([
    ("pf", f'platform "{gh("pfx", "0.1.0", PF0)}"'),
    ("json", f'"{gh("json", "2.0.0", JS0)}"'),
    ("parser", f'"{gh("parser", "1.0.0", PA0)}"'),
    ("other", f'"{URL_EXO}"'),  # Design Q465: another host offline: the line of a registry online
]))
write(os.path.join(d, f"given/home/.cache/roc/packages/{EXO}/main.roc"), PACKAGE)
ORIGIN = "http://127.0.0.1:9"
CACHE = "given/home/.cache/roc/talon/index/registry/http_127.0.0.1_9/get"


def key(path): return hashlib.sha256(path.encode()).hexdigest()[:32]


def copy(path, rels, mtime, mtimes):
    k = key(path)
    write(os.path.join(d, CACHE, k + ".json"), j({"releases": rels, "checked": None, "repos": []}))
    write(os.path.join(d, CACHE, k + ".meta"), f"url {path}\nmax-age 60\n")
    mtimes.append(f"{k}.meta {mtime}")


from urllib.parse import quote
mtimes = []
# json: the copy of GET /v1/releases?group=<form> (R-AP13, no series).
copy("/v1/releases?group=" + quote(form("json"), safe=""), [rel("json", "2.0.0", JS0, 44, "2026-08-16"), rel("json", "2.1.0", JS1, 25, "2026-09-25")], 1792000000, mtimes)
# parser: no group copy, the copy of GET /v1/packages/acme/parser/releases (R-AP1): the rows of the form of the header URL only (a row of the form v{v} is not a candidate).
other_form = dict(rel("parser", "9.0.0", H("parser-v9"), 3, "2026-06-01"), group=form("parser", "v{v}"), url=gh("parser", "9.0.0", H("parser-v9"), tag="v9.0.0"), tag="v9.0.0")
copy("/v1/packages/acme/parser/releases", [rel("parser", "1.0.0", PA0, 42, "2026-07-17"), rel("parser", "1.2.0", PA2, 35, "2026-10-05"), other_form], 1791990000, mtimes)
# pfx: no copy at all: the group acts as in R-DI11 with the note of R-IX6.
write(os.path.join(d, "fx/mtimes"), "\n".join(mtimes) + "\n")
write(os.path.join(d, "fx/commands"), "update --no-check --dry-run --offline --file u1/main.roc\n")
