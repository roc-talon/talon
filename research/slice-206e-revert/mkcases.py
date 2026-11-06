#!/usr/bin/env python3
"""Slice 206e (sub-slice 1): the given and fx files of 3 new L2 cases (entry `commands`), not the expect files.
  tests/commands/cases/registry/al2-install-query   `tln install` with no names reaches the registry
  tests/commands/cases/registry/al2-verify-query    `tln verify` reaches the registry (settle!, --offline)
  tests/commands/cases/registry/al2-upgrade-query   `tln upgrade <names>` reaches the registry (no range, every series)
Each case starts from a copy of registry/al2-update-query (slice 206b): the same project, packages, kept guard answers, GitHub lists and closure answer.
Run from the repo root: python3 -I research/slice-206e-revert/mkcases.py [<case name> ...]
It DELETES each case dir that it makes (expect/ and rules too): keep a copy before a run."""
import datetime, hashlib, json, os, shutil, sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
AL2 = os.path.join(CASES, "al2-update-query")
AP28 = os.path.join(CASES, "ap28-update-unknown")
ONLY = sys.argv[1:]
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
CLOSURE = "fx/http/127.0.0.1%3A9/v1/closure.POST"
JSON_LIST = "fx/http/api.github.com/repos/acme/json/releases%3Fper_page=100"
OTHER = "4fuYsvs8fLQptnhMHwz9pYv7M1j3knJFyQSmR4o1aaUu"  # the example.org value of ap28-update-unknown (its archive is there)


def want(name): return not ONLY or name in ONLY


def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n:
        n, r = divmod(n, 58); s = ALPHA[r] + s
    return s


def H(name): return b58(hashlib.sha256(b"slice206e-" + name.encode()).digest())


def ms(day): return int(datetime.datetime.strptime(day + "T12:00:00", "%Y-%m-%dT%H:%M:%S").replace(tzinfo=datetime.timezone.utc).timestamp()) * 1000


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def j(v): return json.dumps(v, separators=(",", ":"))


def base(name):
    d = os.path.join(CASES, name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    for part in ("entry", "fx", "given"):
        src = os.path.join(AL2, part)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(d, part))
        else:
            shutil.copy(src, os.path.join(d, part))
    # The case answers only at 127.0.0.1:9 (the config.toml registry).
    shutil.rmtree(os.path.join(d, "fx/http/localhost%3A9"), ignore_errors=True)
    return d


def answer(d): return json.load(open(os.path.join(d, CLOSURE)))


def put_answer(d, a): write(os.path.join(d, CLOSURE), j(a))


def commands(d, lines): write(os.path.join(d, "fx/commands"), "\n".join(lines) + "\n")


DIRECT = "env:TALON_REGISTRY=http://127.0.0.1:9"

# ---------------------------------------------------------------- al2-install-query
if want("al2-install-query"):
    d = base("al2-install-query")
    # R-SP20: json 2.0.0 is outside ^2.1, so json is the one free variable of `install` with no names. parser and pf are held.
    write(os.path.join(d, "given/project/u1/talon.toml"), '[dependencies]\njson = "^2.1"\n')
    commands(d, [
        f"install --no-check --dry-run --registry direct --file u1/main.roc {DIRECT}",
        "install --no-check --dry-run --file u1/main.roc",
        "install --no-check --dry-run --json --snapshot log:30 --file u1/main.roc",
        "install --no-check --registry http://example.org --file u1/main.roc",
    ])

# ---------------------------------------------------------------- di1-install-no-free (Design Q469)
if want("di1-install-no-free"):
    d = base("di1-install-no-free")
    # u1: no talon.toml, one member: nothing is outside (R-SP21). u2: a package header with no entry (no group, no hash).
    write(os.path.join(d, "given/project/u2/main.roc"), "package [Lib] {}\n\nLib := [].{}\n")
    commands(d, [
        "install --no-check --dry-run --json --file u1/main.roc",
        "install --frozen --file u1/main.roc",
        "install --no-check --dry-run --json --file u2/main.roc",
    ])

# ---------------------------------------------------------------- al2-verify-query
if want("al2-verify-query"):
    d = base("al2-verify-query")
    p = os.path.join(d, "given/project/u1/main.roc")
    text = open(p).read().replace('\troc:', f'\tother: "https://example.org/acme/other/releases/download/1.0.0/{OTHER}.tar.zst",\n\troc:')
    write(p, text)
    shutil.copytree(os.path.join(AP28, f"given/home/.cache/roc/packages/{OTHER}"), os.path.join(d, f"given/home/.cache/roc/packages/{OTHER}"))
    a = answer(d)
    a["unknown"] = [OTHER]  # R-AP28 case 3: a value of another host (R-PU40)
    put_answer(d, a)
    commands(d, [
        f"verify --no-check --registry direct --file u1/main.roc {DIRECT}",
        "verify --no-check --file u1/main.roc",
        "verify --no-check --json --snapshot log:30 --file u1/main.roc",
        "verify --no-check --offline --file u1/main.roc",
    ])

# ---------------------------------------------------------------- al2-upgrade-query
if want("al2-upgrade-query"):
    d = base("al2-upgrade-query")
    J3 = H("json-3.0.0")
    url3 = f"https://github.com/acme/json/releases/download/3.0.0/{J3}.tar.zst"
    # json 3.0.0: a new series (R-UP3), published 2026-09-30, log 30. In the GitHub list (direct) and in the answer (registry).
    lst = json.load(open(os.path.join(d, JSON_LIST)))
    lst.append({"tag_name": "3.0.0", "draft": False, "prerelease": False, "published_at": "2026-09-30T12:00:00Z",
                "assets": [{"name": f"{J3}.tar.zst", "size": 1000, "browser_download_url": url3}]})
    write(os.path.join(d, JSON_LIST), j(lst))
    write(os.path.join(d, f"given/home/.cache/roc/packages/{J3}/main.roc"), "package [Lib] {}\n")
    a = answer(d)
    a["artifacts"].append({"hash": J3, "kind": "package", "exposed": [], "platform_hash": None, "roc_pin": None, "size": 1000, "deps": [], "target_names": []})
    a["artifacts"].sort(key=lambda x: x["hash"])
    a["releases"].append({"log_index": 30, "hash": J3, "group": "github.com/acme/json/releases/download/{v}/", "series": "3", "version": "3.0.0", "url": url3,
                          "tag": "3.0.0", "roc_version": None, "repo": "acme/json", "published_at": ms("2026-09-30"), "yanked": False, "yank_reason": None,
                          "withdrawn": None, "provenance": ["webhook"]})
    put_answer(d, a)
    commands(d, [
        f"upgrade json --no-check --dry-run --registry direct --file u1/main.roc {DIRECT}",
        "upgrade json --no-check --dry-run --file u1/main.roc",
        "upgrade json --no-check --dry-run --snapshot 2026-09-26T00:00:00Z --file u1/main.roc",
        "upgrade --dry-run --file u1/main.roc",
    ])
