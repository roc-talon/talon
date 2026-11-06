#!/usr/bin/env python3
# Slice 207: writes the 2 L2 cases of tests/commands/cases/registry/ (fx, entry, rules, and the expect files BY HAND from the rules, not from a run).
# Run from the repo root: python3 -I research/slice-207-revert/mkcases.py
import json, os, shutil

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "127.0.0.1%3A9"
h1 = "2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp"
h2 = "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN"
h3 = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"
h4 = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"
hc1 = "4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN"
hc2 = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"
hc3 = "6k78AbasGMFFrhG95Pj6jQbqkVt7FQMhVgemxJovWKR6"

def form(owner, repo): return f"github.com/{owner}/{repo}/releases/download/{{v}}/"
def gh(owner, repo, tag, h): return f"https://github.com/{owner}/{repo}/releases/download/{tag}/{h}.tar.zst"
G_JSON, G_CLI = form("someone", "roc-json"), form("roc-lang", "basic-cli")

def rel(log, h, group, version, url, repo, ms, series):
    return {"log_index": log, "hash": h, "group": group, "series": series, "version": version, "url": url, "tag": version, "roc_version": None,
            "repo": repo, "published_at": ms, "yanked": False, "yank_reason": None, "withdrawn": None, "provenance": ["webhook"]}

def art(h, size):
    return {"hash": h, "kind": "package", "exposed": [], "platform_hash": None, "roc_pin": None, "size": size, "deps": [], "target_names": []}

def answer(rels, arts, log_size):
    return {"artifacts": arts, "releases": rels, "epochs": [], "runs": [], "nearest": [], "hints": [], "log_size": log_size, "unknown": [], "checked": [], "repos": []}

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)

def fresh(name):
    d = os.path.join(CASES, name)
    shutil.rmtree(d, ignore_errors=True)
    write(os.path.join(d, "entry"), "registry\n")
    return d

def route(d, path, body):
    write(os.path.join(d, "fx/http", HOST, path), json.dumps(body, separators=(",", ":")))
    write(os.path.join(d, "fx/http", HOST, path + ".meta"),
          "status 200\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire-none authorization\n")

def post(body):
    return ("http_send POST http://127.0.0.1:9/v1/closure timeout=20\n  User-Agent: tln/0.0.1\n  Content-Type: application/json\n  <body> " + body + "\n")

J = [("1.0.0", h1, 10, 1790848800000, 100), ("1.1.0", h2, 30, 1791194400000, 200), ("1.2.0", h3, 31, 1791540000000, 300), ("1.3.0", h4, 50, 1791886400000, 400)]
def jurl(v, h): return gh("someone", "roc-json", v, h)
json_rels = [rel(l, h, G_JSON, v, jurl(v, h), "someone/roc-json", ms, "1") for v, h, l, ms, _ in J]
json_arts = [art(h, size) for _, h, _, _, size in J]
def cand(prefix, name, v, h, ms, size): return f"{prefix}candidate {name} {v} {v} {ms // 1000} {size} {jurl(v, h)}\n"

# Case 1: --snapshot log:N on the answer (R-AP19) and the printed log size (R-DT5).
d = fresh("ap19-log-snapshot")
for p in ("v1/closure.POST", "v1/closure.POST.2", "v1/closure.POST.3", "v1/closure.POST.4"):
    route(d, p, answer(json_rels, json_arts, 50))
base = f"closure group={G_JSON} name=someone/roc-json"
e3 = f"entry=json={jurl('1.2.0', h3)}"
write(os.path.join(d, "fx/runs"), f"{base} snapshot=30 resolved\n{base} resolved\n{base} snapshot=900 resolved\n{base} {e3} snapshot=30 resolved\n")
write(os.path.join(d, "rules"),
"""R-AP19 R-DT3 R-DT5 R-AP16 R-DI14 R-IX3 (slice 207, tests/commands/L2Registry.roc, entry registry, the word closure with snapshot= and resolved): `--snapshot log:N` with a registry.
The answer has 4 releases of someone/roc-json with log_index 10, 30, 31, 50 and log_size 50. The body of the request is the same in the 3 runs (no snapshot member: the client applies the snapshot to the answer, R-AP19).
Run 1, snapshot 30: the releases above 30 are hidden (31 and 50), the release with log_index 30 stays, so 2 releases and 2 candidates; log_size 50 and 4 artifacts stay (Design Q405); the line `resolved at log:30, 0 probes` has N, not log_size (R-DT5). Run 2, no snapshot: 4 releases, `log:50` (the log_size of the answer). Run 3, snapshot 900 (above log_size): 4 releases, `log:900` (N as given). Run 4 (Design Q403, R-C9): the entry names the release 1.2.0 (log_index 31, hash in the `hashes` of the request), snapshot 30: that release is kept although it is above 30, the release 50 is hidden: 3 releases and 3 candidates, `log:30`. Design Q405: the lines log_size 50 and artifacts 4 are the same after the hide.
The text `resolved at log:<n>, <probes> probes` is the proposal of R-DT5 (the form of `Report.resolved_line`).
""")
out = ""
for run, snap, keep, shown in ((f"snapshot=30 resolved", 30, 2, 30), ("resolved", None, 4, 50), ("snapshot=900 resolved", 900, 4, 900), (f"{e3} snapshot=30 resolved", 30, 3, 30)):
    out += f"== {base} {run}\nlog_size 50\nreleases {keep}\nartifacts 4\nresolved at log:{shown}, 0 probes\n"
    for v, h, l, ms, size in J[:keep]:
        out += cand("", "someone/roc-json", v, h, ms, size)
write(os.path.join(d, "expect/stdout"), out)
body1 = json.dumps({"groups": [{"group": G_JSON}], "hashes": []}, separators=(",", ":"))
body3 = json.dumps({"groups": [{"group": G_JSON}], "hashes": [h3]}, separators=(",", ":"))
write(os.path.join(d, "expect/calls.log"), "env_all\n" + post(body1) * 3 + post(body3))
write(os.path.join(d, "expect/exit"), "0\n")

# Case 2: the second query of a held move (R-AP16, R-SP24, R-AP19).
d = fresh("ap16-second-query")
entry = gh("someone", "roc-json", "1.0.0", h1)
held = "nightly-2026-10-05-2222222"
first = answer([rel(5, h1, G_JSON, "1.0.0", entry, "someone/roc-json", 1790848800000, "1"), rel(38, h2, G_JSON, "1.1.0", jurl("1.1.0", h2), "someone/roc-json", 1791194400000, "1")],
               [art(h1, 100), art(h2, 200)], 40)
C = [("0.25.0", hc1, 12, 1791540000000, 9000), ("0.26.0", hc2, 38, 1791626400000, 9100), ("0.27.0", hc3, 43, 1791712800000, 9200)]
def curl(v, h): return gh("roc-lang", "basic-cli", v, h)
second = answer([rel(l, h, G_CLI, v, curl(v, h), "roc-lang/basic-cli", ms, "0." + v.split(".")[1]) for v, h, l, ms, _ in C], [art(h, size) for _, h, _, _, size in C], 45)
route(d, "v1/closure.POST", first)
route(d, "v1/closure.POST.2", second)
# run 2: the second answer has a release above its own log_size (R-AP18): exit 15
bad = answer([rel(46, hc1, G_CLI, "0.25.0", curl("0.25.0", hc1), "roc-lang/basic-cli", 1791540000000, "0.25")], [art(hc1, 9000)], 45)
route(d, "v1/closure.POST.3", first)
route(d, "v1/closure.POST.4", bad)
route(d, "v1/closure.POST.5", first)
route(d, "v1/closure.POST.6", second)
line = f"closure group={G_JSON} entry=json={entry} held={held} name=someone/roc-json resolved then-group={G_CLI}@0.25 name2=roc-lang/basic-cli"
line3 = f"closure group={G_JSON} entry=json={entry} entry=cli={curl('0.27.0', hc3)} held={held} name=someone/roc-json snapshot=20 resolved then-group={G_CLI}@0.25 name2=roc-lang/basic-cli"
write(os.path.join(d, "fx/runs"), line + "\n" + line + "\n" + line3 + "\n")
write(os.path.join(d, "rules"),
"""R-AP16 R-SP24 R-AP19 R-AP18 R-DT5 R-DI1 R-DT3 R-IX3 R-E6 (slice 207, tests/commands/L2Registry.roc, entry registry, the word closure with then-group=): the second query of a held move.
Run 1: the first query has the group of someone/roc-json, the hash of the entry and the held window. The first answer has log_size 40. The second query (closure.POST.2) has ONLY the group of the movable variable (basic-cli, series 0.25), `hashes` empty, and the same `compilers` as the first. Its answer has log_size 45 and 3 releases with log_index 12, 38 and 43. The client applies the first log_size as `log:40` (R-AP16, R-AP19): the release 43 is hidden, so 2 releases. The line `resolved at log:40, 0 probes` has the log_size of the FIRST answer (R-DT5), not the 45 of the second.
Run 2: the first answer is as in run 1 (closure.POST.3). The second answer (closure.POST.4) has a release with log_index 46 above its own log_size 45 (R-AP18): the answer is refused, exit 15 (R-E6 last row), and no `second` line. Each query is one request, no second try.
Run 3 (Design Q404, Q403): the user gave `--snapshot log:20`, below the first log_size 40; the entries name the json 1.0.0 (log 5) and the basic-cli 0.27.0 (log 43), so `hashes` has both and the first answer hides the release 38 (1 release). The second answer is hidden above the SMALLER of 20 and 40: the release 38 is hidden (a cut by the first log_size alone would keep it), the release 12 stays, and the release 43 stays because its hash is in the keep list (Q403, the first request's `hashes`; the second request has none): 2 releases. The line is `log:20` (N of the flag, R-DT5); log_size 40 and 45 are not changed (Q405).\nNo file is written (R-IX3: no-store). The text of the failure is the proposal of slice 206 (Q390).
""")
def cc(v, h, ms, size): return f"second candidate roc-lang/basic-cli {v} {v} {ms // 1000} {size} {curl(v, h)}\n"
out = f"== {line}\nlog_size 40\nreleases 2\nartifacts 2\nresolved at log:40, 0 probes\n" + cand("", "someone/roc-json", "1.0.0", h1, 1790848800000, 100) + cand("", "someone/roc-json", "1.1.0", h2, 1791194400000, 200)
out += "second log_size 45\nsecond releases 2\n" + cc("0.25.0", hc1, 1791540000000, 9000) + cc("0.26.0", hc2, 1791626400000, 9100)
out += f"== {line}\nlog_size 40\nreleases 2\nartifacts 2\nresolved at log:40, 0 probes\n" + cand("", "someone/roc-json", "1.0.0", h1, 1790848800000, 100) + cand("", "someone/roc-json", "1.1.0", h2, 1791194400000, 200) + "exit 15\n"
out += f"== {line3}\nlog_size 40\nreleases 1\nartifacts 2\nresolved at log:20, 0 probes\n" + cand("", "someone/roc-json", "1.0.0", h1, 1790848800000, 100)
out += "second log_size 45\nsecond releases 2\n" + cc("0.25.0", hc1, 1791540000000, 9000) + cc("0.27.0", hc3, 1791712800000, 9200)
write(os.path.join(d, "expect/stdout"), out)
b1 = json.dumps({"compilers": {"from": held, "to": held}, "groups": [{"group": G_JSON}], "hashes": [h1]}, separators=(",", ":"))
b3 = json.dumps({"compilers": {"from": held, "to": held}, "groups": [{"group": G_JSON}], "hashes": [h1, hc3]}, separators=(",", ":"))
b2 = json.dumps({"compilers": {"from": held, "to": held}, "groups": [{"group": G_CLI, "series": "0.25"}], "hashes": []}, separators=(",", ":"))
write(os.path.join(d, "expect/calls.log"), "env_all\n" + post(b1) + post(b2) + post(b1) + post(b2) + post(b3) + post(b2))
write(os.path.join(d, "expect/exit"), "0\n")
write(os.path.join(d, "expect/stderr"),
      f"tln: error[network]: the answer of the registry http://127.0.0.1:9 is not a closure answer: the release {curl('0.25.0', hc1)} has the log index 46, above the log size 45\n")
print("ok")
