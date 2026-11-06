#!/usr/bin/env python3
# Slice 206: writes the given and fx files of the 4 L2 cases of tests/commands/cases/registry/ (not the expect files).
# Run from the repo root: python3 -I research/slice-206-revert/mkcases.py
import hashlib, json, os, shutil

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "127.0.0.1%3A9"

h1 = "2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp"   # json 1.0.0
h2 = "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN"   # json 1.1.0
h3 = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"   # json 2.0.0, withdrawn
hc = "4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN"   # basic-cli 0.25.0, a platform
ha = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"   # roc-a 1.0.0
hd = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"   # roc-dep 1.0.0, not in the answer
hb = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"   # roc-b
hb2 = "6k78AbasGMFFrhG95Pj6jQbqkVt7FQMhVgemxJovWKR6"  # roc-b, other form
hx = "6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS"   # roc-d

def gh(owner, repo, tag, h):
    return f"https://github.com/{owner}/{repo}/releases/download/{tag}/{h}.tar.zst"

def form(owner, repo, pre=""):
    return f"github.com/{owner}/{repo}/releases/download/{pre}{{v}}/"

json1, json2, json3 = gh("someone", "roc-json", "1.0.0", h1), gh("someone", "roc-json", "1.1.0", h2), gh("someone", "roc-json", "2.0.0", h3)
cli = gh("roc-lang", "basic-cli", "0.25.0", hc)
a_url = gh("someone", "roc-a", "1.0.0", ha)
dep = gh("someone", "roc-dep", "1.0.0", hd)
G_JSON, G_CLI = form("someone", "roc-json"), form("roc-lang", "basic-cli")

def rel(log, h, group, version, url, repo, ms, tag=None, roc_version=None, withdrawn=None, series=None):
    return {"log_index": log, "hash": h, "group": group, "series": series or version.split(".")[0] if not version.startswith("0.") else series or "0." + version.split(".")[1],
            "version": version, "url": url, "tag": tag, "roc_version": roc_version, "repo": repo, "published_at": ms,
            "yanked": False, "yank_reason": None, "withdrawn": withdrawn, "provenance": ["webhook"]}

def dep_item(alias, h, owner, repo, version, url):
    return {"alias": alias, "hash": h, "is_platform": False, "group": form(owner, repo), "series": version.split(".")[0], "version": version, "url": url}

def art(h, kind, size, deps=(), targets=()):
    return {"hash": h, "kind": kind, "exposed": [], "platform_hash": None, "roc_pin": None, "size": size, "deps": list(deps), "target_names": list(targets)}

answer = {
    "artifacts": [
        art(h1, "package", 1200, [dep_item("extra", hd, "someone", "roc-dep", "1.0.0", dep)]),
        art(h2, "package", 3400),
        art(hc, "platform", 9000000, targets=["linux_x86_64", "macos_apple_silicon"]),
        art(ha, "package", 500, [dep_item("json", h1, "someone", "roc-json", "1.0.0", json1)]),
    ],
    "releases": [
        rel(3, h1, G_JSON, "1.0.0", json1, "someone/roc-json", 1790848800000, tag="1.0.0", roc_version="nightly-2026-10-05-2222222\n"),
        rel(7, h2, G_JSON, "1.1.0", json2, "someone/roc-json", 1791194400000),
        rel(9, h3, G_JSON, "2.0.0", json3, "someone/roc-json", 1791540000000, tag="2.0.0", withdrawn="deleted"),
        rel(12, hc, G_CLI, "0.25.0", cli, "roc-lang/basic-cli", 1791540000000, tag="0.25.0", series="0.25"),
    ],
    "epochs": [], "runs": [], "nearest": [], "hints": [],
    "log_size": 40,
    "unknown": ["notahash"],
    "checked": [{"name": "someone/roc-json", "checked_at": 1791540000000, "stale": False}],
    "repos": [{"name": "roc-lang/basic-cli", "state": "active", "successor": None, "state_at": 1700000000000},
              {"name": "someone/roc-json", "state": "active", "successor": None, "state_at": 1700000000000}],
}

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)

def fresh(name):
    d = os.path.join(CASES, name)
    for sub in ("fx", "given"):
        shutil.rmtree(os.path.join(d, sub), ignore_errors=True)
    write(os.path.join(d, "entry"), "registry\n")
    return d

def route(d, path, body, meta):
    write(os.path.join(d, "fx/http", HOST, path), body)
    write(os.path.join(d, "fx/http", HOST, path + ".meta"), meta)

OK_META = "status 200\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire-none authorization\n"

# Case 1: candidates, log_size, unknown, checked.
d = fresh("ap17-closure-index")
route(d, "v1/closure.POST", json.dumps(answer, separators=(",", ":")), OK_META)
write(os.path.join(d, "fx/runs"),
      f"closure group={G_JSON}@1 group={G_CLI} entry=json={json1} held=nightly-2026-10-05-2222222 name=Someone/Roc-Json name=roc-lang/basic-cli name=someone/nothing checked=Someone/roc-json checked=roc-lang/basic-cli\n")

# Case 2: facts from the records, the walk (winners only), the rank 4 hints.
d = fresh("al8-closure-facts")
route(d, "v1/closure.POST", json.dumps(answer, separators=(",", ":")), OK_META)
write(os.path.join(d, f"given/home/.cache/roc/packages/{hd}/main.roc"), "package [Dep] {}\n")
write(os.path.join(d, "fx/runs"),
      f"closure entry=json={json2} read={json2} read={cli} read={a_url} read={dep} gather={json2} gather={dep} gather={cli} hint={json1} hint={json2} hint={json1}\n"
      f"closure entry=json={json2} entry=a={a_url} walk\n")

# Case 3: the query fails, once each (no second try), and no file is written.
d = fresh("ap20-closure-errors")
route(d, "v1/closure.POST", "", "error timeout\n")
route(d, "v1/closure.POST.2", '{"type":"/errors/bad-request","title":"Bad request","status":400,"detail":"groups is not a list"}', "status 400\nheader Content-Type: application/problem+json\n")
route(d, "v1/closure.POST.3", '{"type":"/errors/upstream","title":"Bad gateway","status":502,"detail":"D1 is down"}', "status 502\nheader Content-Type: application/problem+json\n")
route(d, "v1/closure.POST.4", '{}', OK_META)
route(d, "v1/closure.POST.5", 'slow down', "status 429\n")
write(os.path.join(d, "fx/runs"),
      "closure free-empty group=" + G_JSON + "\n" + ("closure group=" + G_JSON + "\n") * 5)

# Case 4: --offline with a registry (R-IX6).
d = fresh("ix6-offline-registry")
def enc(text):
    out = ""
    for b in text.encode():
        c = chr(b)
        out += c if (c.isalnum() and b < 128) or c in "-._~" else "%%%02X" % b
    return out
def key(path):
    return hashlib.sha256(path.encode()).hexdigest()[:32]
B_FORM, B_FORM2 = form("someone", "roc-b", "v"), form("someone", "roc-b")
p1 = "/v1/releases?group=" + enc(G_JSON)
p2 = "/v1/packages/someone/roc-b/releases"
p3 = "/v1/packages/someone/roc-d/releases"
copy_meta = 'status 200\nheader Content-Type: application/json\nheader Cache-Control: max-age=60\nheader ETag: "e1"\n'
def listing(rows):
    return json.dumps({"releases": rows, "checked": None, "repos": []}, separators=(",", ":"))
r_json = [rel(3, h1, G_JSON, "1.0.0", json1, "someone/roc-json", 1790848800000, tag="1.0.0", roc_version="nightly-2026-10-05-2222222"),
          rel(7, h2, G_JSON, "1.1.0", json2, "someone/roc-json", 1791194400000, tag="1.1.0")]
r_b = [rel(4, hb, B_FORM, "1.0.0", gh("someone", "roc-b", "v1.0.0", hb), "someone/roc-b", 1790000000000, tag="v1.0.0"),
       rel(5, hb2, B_FORM2, "2.0.0", gh("someone", "roc-b", "2.0.0", hb2), "someone/roc-b", 1790100000000, tag="2.0.0")]
r_d = [rel(6, hx, form("someone", "roc-d"), "0.3.0", gh("someone", "roc-d", "0.3.0", hx), "someone/roc-d", 1790200000000, tag="0.3.0", series="0.3")]
def route_path(p):
    return p.lstrip("/").replace("%", "%25").replace("?", "%3F")
route(d, route_path(p1), listing(r_json), copy_meta)
route(d, route_path(p2), listing(r_b), copy_meta)
route(d, route_path(p3), listing(r_d), copy_meta)
write(os.path.join(d, "fx/mtimes"), f"{key(p1)}.meta 1792000000\n{key(p2)}.meta 1791990000\n{key(p3)}.meta 1792050000\n")
c_url = gh("someone", "roc-c", "1.0.0", hd)
write(os.path.join(d, "fx/runs"),
      f"get {p1}\nget {p2}\nget {p3}\n"
      f"offline name=someone/roc-json name=Someone/Roc-B name=someone/roc-c name=someone/roc-d known={json1} known={gh('someone', 'roc-b', '2.0.0', hb2)} known={c_url} hint={json1}\n")
print("ok")

# Manager answers Q390 to Q392 (2026-11-03). Only given and fx files here; the expect files are written by hand (research/slice-206-revert/mkexpect.py).
# Q390 (R-AP18): run 1 has a release with log_index = log_size (used), run 2 one with log_index = log_size + 1 (refused, exit 15).
d = fresh("ap18-closure-log-size")
one = dict(answer, artifacts=[answer["artifacts"][1]], releases=[rel(40, h2, G_JSON, "1.1.0", json2, "someone/roc-json", 1791194400000, tag="1.1.0")], unknown=[], checked=[])
two = dict(one, releases=[rel(41, h2, G_JSON, "1.1.0", json2, "someone/roc-json", 1791194400000, tag="1.1.0")])
route(d, "v1/closure.POST", json.dumps(one, separators=(",", ":")), OK_META)
route(d, "v1/closure.POST.2", json.dumps(two, separators=(",", ":")), OK_META)
write(os.path.join(d, "fx/runs"), ("closure group=" + G_JSON + " name=someone/roc-json\n") * 2)

# Q391 (R-IX6 per group): someone/roc-b has 2 known forms. v{v} has a group copy, {v} has none, and there is no repository copy.
d = fresh("ix6-offline-groups")
p4 = "/v1/releases?group=" + enc(B_FORM)
route(d, route_path(p4), listing([r_b[0]]), copy_meta)
write(os.path.join(d, "fx/mtimes"), f"{key(p4)}.meta 1791990000\n")
write(os.path.join(d, "fx/runs"),
      f"get {p4}\n"
      f"offline name=someone/roc-b known={gh('someone', 'roc-b', 'v1.0.0', hb)} known={gh('someone', 'roc-b', '2.0.0', hb2)}\n")
print("keys", key(p4), key("/v1/releases?group=" + enc(form("acme", "json"))))
