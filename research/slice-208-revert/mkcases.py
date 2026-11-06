#!/usr/bin/env python3
# Slice 208: writes the 3 L2 cases of tests/commands/cases/registry/ (fx, entry, rules, and the expect files BY HAND from the rules, not from a run).
# Run from the repo root: python3 -I research/slice-208-revert/mkcases.py
import hashlib, json, os, shutil

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "127.0.0.1%3A9"
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n:
        n, r = divmod(n, 58); s = ALPHA[r] + s
    return s

def H(name): return b58(hashlib.sha256(b"slice208-" + name.encode()).digest())

def gh(repo, version, h): return f"https://github.com/acme/{repo}/releases/download/{version}/{h}.tar.zst"
def form(repo): return f"github.com/acme/{repo}/releases/download/{{v}}/"

def rel(log, h, repo, version):
    return {"log_index": log, "hash": h, "group": form(repo), "series": version.split(".")[0], "version": version, "url": gh(repo, version, h), "tag": version, "roc_version": None,
            "repo": f"acme/{repo}", "published_at": 1790848800000, "yanked": False, "yank_reason": None, "withdrawn": None, "provenance": ["ingest"]}

def answer(rels, log_size, unknown):
    return {"artifacts": [], "releases": rels, "epochs": [], "runs": [], "nearest": [], "hints": [], "log_size": log_size, "unknown": unknown, "checked": [], "repos": []}

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)

def fresh(name, programs):
    d = os.path.join(CASES, name)
    shutil.rmtree(d, ignore_errors=True)
    write(os.path.join(d, "entry"), "registry\n")
    if programs: write(os.path.join(d, "fx/programs"), "curl\n")
    return d

def route(d, path, body, status=200, headers=(), problem=False, require=True):
    write(os.path.join(d, "fx/http", HOST, path), json.dumps(body, separators=(",", ":")))
    ct = "application/problem+json" if problem else "application/json"
    meta = f"status {status}\nheader Content-Type: {ct}\n"
    for h in headers: meta += f"header {h}\n"
    meta += "require content-type: application/json\nrequire-none authorization\nrequire-none talon-contributor\n"
    write(os.path.join(d, "fx/http", HOST, path + ".meta"), meta)

def problem(kind, status, title):
    return {"type": f"/errors/{kind}", "title": title, "status": status, "detail": "x"}

UA = "  User-Agent: tln/0.0.1\n  Content-Type: application/json\n"
def closure_call(body, extra=""):
    return "http_send POST http://127.0.0.1:9/v1/closure timeout=20\n" + UA + extra + "  <body> " + body + "\n"
def ingest_call(url):
    return "http_send POST http://127.0.0.1:9/v1/releases timeout=20\n" + UA + "  <body> " + json.dumps({"url": url}, separators=(",", ":")) + "\n"
def body_of(hashes): return json.dumps({"groups": [], "hashes": hashes}, separators=(",", ":"))
ALL = "http_all limit=4 tmp=$HOME/.cache/roc/talon/tmp\n"
def agent(extra): return extra

# warning texts (proposal, R-OUT2): the text of UnknownValues.label_warning
def warn(name, version, hash, other):
    who = f"the hash {other}" if other else "another hash"
    return f"warning: {name} {version}: the registry has this release with {who}, the header has {hash}. Talon does not use the registry's release for this value. Ask the author to release a new version.\n"

BM_SMALL = "00000005-00000010-00004c60-8e61"
BM_BIG = "0000000b-00000020-00004c70-1f22"
BM_MID = "00000008-00000030-00004c68-9a10"
BM_G = "0000000c-00000040-00004c80-aaaa"

# ---------------------------------------------------------------- case A: R-AP28 cases 1 to 3, R-AP65
d = fresh("ap28-unknown-values", True)
hA, hB, hC, hD, hE, hO = H("a"), H("b"), H("c"), H("d"), H("e"), H("e-other")
uA, uB, uC = gh("lib", "1.0.0", hA), gh("other", "2.0.0", hB), gh("third", "3.0.0", hC)
uD = f"https://example.org/lib/releases/download/1.0.0/{hD}.tar.zst"
uE = gh("lib", "1.1.0", hE)
rowE = rel(9, hO, "lib", "1.1.0")
# run 1: unknown [A, D, B, E, C]
r1 = [hA, hD, hB, hE, hC]
route(d, "v1/closure.POST", answer([rowE], 20, r1))
route(d, "v1/releases.POST", {"status": "indexed"}, 201, [f"Talon-Bookmark: {BM_SMALL}"])
route(d, "v1/releases.POST.2", {"status": "indexed"}, 200, [f"Talon-Bookmark: {BM_BIG}"])
route(d, "v1/releases.POST.3", {"status": "indexed"}, 201, [f"Talon-Bookmark: {BM_MID}"])
route(d, "v1/closure.POST.2", answer([rowE, rel(21, hA, "lib", "1.0.0"), rel(22, hB, "other", "2.0.0"), rel(23, hC, "third", "3.0.0")], 25, [hD, hE]))
# run 2: F (409 label-conflict) and G (201)
hF, hG = H("f"), H("g")
uF, uG = gh("lib", "4.0.0", hF), gh("other", "5.0.0", hG)
route(d, "v1/closure.POST.3", answer([], 30, [hF, hG]))
route(d, "v1/releases.POST.4", problem("label-conflict", 409, "Conflict"), 409, [], True)
route(d, "v1/releases.POST.5", {"status": "indexed"}, 201, [f"Talon-Bookmark: {BM_G}"])
route(d, "v1/closure.POST.4", answer([rel(31, hG, "other", "5.0.0")], 31, [hF]))
# run 3: H (409 id-collision) and I (422): case 3 for both, no second query
hH, hI = H("h"), H("i")
uH, uI = gh("lib", "6.0.0", hH), gh("other", "7.0.0", hI)
route(d, "v1/closure.POST.5", answer([], 40, [hH, hI]))
route(d, "v1/releases.POST.6", problem("id-collision", 409, "Conflict"), 409, [], True)
route(d, "v1/releases.POST.7", problem("not-a-candidate", 422, "Unprocessable"), 422, [], True)
# run 4: --snapshot log:N: L (github) and M (label) get no ingest
hL, hM, hMo = H("l"), H("m"), H("m-other")
uL, uM = gh("lib", "10.0.0", hL), gh("lib", "11.0.0", hM)
rowM = rel(12, hMo, "lib", "11.0.0")
route(d, "v1/closure.POST.6", answer([rowM], 60, [hL, hM]))

def words(urls, extra=""): return " ".join(f"entry={u}" for u in urls) + extra
w1, w2, w3, w4 = words([uA, uD, uB, uE, uC]), words([uF, uG]), words([uH, uI]), words([uL, uM], " snapshot-log")
write(os.path.join(d, "fx/runs"), f"settle {w1}\nsettle {w2}\nsettle {w3}\nsettle {w4}\n")
write(os.path.join(d, "rules"),
"""R-AP28 R-AP65 R-AP9 R-AP41 R-AP43 R-DA8 R-AP34 R-AP18 R-AP17 R-AP59 R-ID7 R-IX3 R-PU40 R-DI7 R-DI11 R-RG4 R-AD35 (slice 208, tests/commands/L2Registry.roc, entry registry, the word settle): the unknown header values of a closure answer.
Run 1 (R-AP28 cases 1, 2, 3 in order): the answer lists 5 unknown hashes, in this order: A (github.com, repo acme/lib), D (example.org), B (github.com), E (github.com, and the answer has the label acme/lib 1.1.0 with ANOTHER hash), C (github.com). E is case 1: the warning that names both hashes, and no ingest (R-AP65 source 1). D is case 3 (R-PU40: no ingest for another host). A, B, C are case 2: ONE `programs curl` (Design Q229), then ONE http_all with limit 4 and tmp dir talon/tmp (R-DA8) with 3 POSTs of /v1/releases in the order of `unknown` (A, B, C), each with the headers User-Agent and Content-Type only (no Authorization, no Talon-Contributor: the route requires none) and the body {"url":...}. The answers: 201 with a bookmark, 200 with the LARGEST bookmark, 201 with a bookmark between: the second closure query is sent ONCE with the same body as the first, the headers User-Agent, Content-Type, Cache-Control: no-cache and Talon-Bookmark: the largest (not the first, not the last). Its answer has log_size 25 and lists D and E as still unknown. The values end: A, B, C indexed, D archive, E label (with the other hash).
Run 2 (R-AP65 source 2): F and G are unknown (github.com). Two ingests. F gets 409 label-conflict: case 1 for F (the warning names the release and the header hash, and says another hash: the 409 does not name it, Q164), no exit code, and the answer has no bookmark. G gets 201: the second query is sent with the bookmark of G. F ends as label (no other hash), G as indexed.
Run 3: H gets 409 id-collision, I gets 422: case 3 for both (R-AP28: another error of an ingest). No exit code, no warning (proposal, R-OUT2), and NO second query (R-AP65: only after a 200 or 201). Both end as archive.
Run 4 (R-AP28 case 3, R-AD36, R-AP65): `--snapshot log:N`: L (github.com) gets no ingest, so no programs call and no http_all. M has the label of the answer with another hash: case 1 still holds (R-AP65: from source 1 only), with the warning. L ends as archive, M as label.
Every ingest and every query is one request, no second try (R-AP34). Nothing is written (R-IX3).
The texts of the warnings are proposals (R-OUT2): the text of UnknownValues.label_warning.
""")
def out(line, values, log_size, rels, unknown):
    s = f"== settle {line}\n"
    for h, e in values: s += f"value {h} {e}\n"
    s += f"log_size {log_size}\nreleases {rels}\n"
    for u in unknown: s += f"unknown {u}\n"
    return s
stdout = out(w1, [(hA, "indexed"), (hD, "archive"), (hB, "indexed"), (hE, f"label other={hO}"), (hC, "indexed")], 25, 4, [hD, hE])
stdout += out(w2, [(hF, "label"), (hG, "indexed")], 31, 1, [hF])
stdout += out(w3, [(hH, "archive"), (hI, "archive")], 40, 0, [hH, hI])
stdout += out(w4, [(hL, "archive"), (hM, f"label other={hMo}")], 60, 1, [hL, hM])
write(os.path.join(d, "expect/stdout"), stdout)
write(os.path.join(d, "expect/stderr"), warn("acme/lib", "1.1.0", hE, hO) + warn("acme/lib", "4.0.0", hF, None) + warn("acme/lib", "11.0.0", hM, hMo))
calls = "env_all\n"
calls += closure_call(body_of(r1)) + "programs curl\n" + ALL + ingest_call(uA) + ingest_call(uB) + ingest_call(uC)
calls += closure_call(body_of(r1), f"  Cache-Control: no-cache\n  Talon-Bookmark: {BM_BIG}\n")
r2 = [hF, hG]
calls += closure_call(body_of(r2)) + "programs curl\n" + ALL + ingest_call(uF) + ingest_call(uG)
calls += closure_call(body_of(r2), f"  Cache-Control: no-cache\n  Talon-Bookmark: {BM_G}\n")
r3 = [hH, hI]
calls += closure_call(body_of(r3)) + "programs curl\n" + ALL + ingest_call(uH) + ingest_call(uI)
r4 = [hL, hM]
calls += closure_call(body_of(r4))
write(os.path.join(d, "expect/calls.log"), calls)
write(os.path.join(d, "expect/exit"), "0\n")

# ---------------------------------------------------------------- case B: no curl (Design Q229, R-DA8, R-EC18)
d = fresh("ap28-no-curl", False)
hA = H("nc")
uA = gh("lib", "1.0.0", hA)
route(d, "v1/closure.POST", answer([], 20, [hA]))
write(os.path.join(d, "fx/runs"), f"settle entry={uA}\n")
write(os.path.join(d, "rules"),
"""R-DA8 R-AP28 R-EC18 R-AP9 (slice 208, entry registry, the word settle): case 2 needs curl for http_all (Design Q229).
The answer lists one github.com hash as unknown. The command asks `programs curl` first (one call), curl is not on PATH (the case has no fx/programs): exit 18 (kind environment, R-EC18), and NO http_all and no ingest and no second query. The text is a proposal (R-OUT2): `curl is not on PATH. Talon needs curl to send the ingests at the same time.`
""")
write(os.path.join(d, "expect/stdout"), f"== settle entry={uA}\nexit 18\n")
write(os.path.join(d, "expect/stderr"), "tln: error[environment]: curl is not on PATH. Talon needs curl to send the ingests at the same time.\n")
write(os.path.join(d, "expect/calls.log"), "env_all\n" + closure_call(body_of([hA])) + "programs curl\n")
write(os.path.join(d, "expect/exit"), "0\n")

# ---------------------------------------------------------------- case C: 429 of an ingest (R-AP25)
d = fresh("ap28-rate-limited", True)
hJ, hK = H("j"), H("k")
uJ, uK = gh("lib", "8.0.0", hJ), gh("other", "9.0.0", hK)
route(d, "v1/closure.POST", answer([], 50, [hJ, hK]))
route(d, "v1/releases.POST", {"status": "indexed"}, 201, [f"Talon-Bookmark: {BM_BIG}"])
route(d, "v1/releases.POST.2", problem("rate-limited", 429, "Too many requests"), 429, ["Retry-After: 30"], True)
write(os.path.join(d, "fx/runs"), f"settle entry={uJ} entry={uK}\n")
write(os.path.join(d, "rules"),
"""R-AP25 R-AD35 R-AP28 R-E6 R-AP34 (slice 208, entry registry, the word settle): a 429 answer to an ingest.
Two github.com hashes are unknown. The 2 ingests run (one http_all). The first gets 201 (it stays indexed), the second gets 429 with Retry-After 30: the command stops with exit 15 (R-AP25, R-E6 kind network) at once: NO second closure query, although one ingest indexed. The ingest is sent once (R-AP34).
Design Q424, R-AP25: the message gives the time of Retry-After in whole seconds: `Try again in 30 s.` (the text is a proposal, R-OUT2).
""")
write(os.path.join(d, "expect/stdout"), f"== settle entry={uJ} entry={uK}\nexit 15\n")
write(os.path.join(d, "expect/stderr"), "tln: error[network]: the registry answered 429 (/errors/rate-limited). Try again in 30 s.\n")
write(os.path.join(d, "expect/calls.log"), "env_all\n" + closure_call(body_of([hJ, hK])) + "programs curl\n" + ALL + ingest_call(uJ) + ingest_call(uK))
write(os.path.join(d, "expect/exit"), "0\n")

# ---------------------------------------------------------------- case D: other answers of an ingest (Q421), no bookmark and a hash still unknown (Q423)
d = fresh("ap28-other-answers", True)
hP, hQ, hX, hY = H("p"), H("q"), H("x"), H("y")
uP, uQ, uX, uY = gh("lib", "1.0.0", hP), gh("other", "2.0.0", hQ), gh("lib", "3.0.0", hX), gh("other", "4.0.0", hY)
route(d, "v1/closure.POST", answer([], 70, [hP, hQ]))
route(d, "v1/releases.POST", problem("upstream", 502, "Bad gateway"), 502, [], True)
write(os.path.join(d, "fx/http", HOST, "v1/releases.POST.2"), "")
write(os.path.join(d, "fx/http", HOST, "v1/releases.POST.2.meta"), "error timeout\n")
route(d, "v1/closure.POST.2", answer([], 80, [hX, hY]))
route(d, "v1/releases.POST.3", {"status": "indexed"}, 200)
route(d, "v1/releases.POST.4", {"status": "indexed"}, 201)
route(d, "v1/closure.POST.3", answer([rel(81, hX, "lib", "3.0.0")], 81, [hY]))
wa, wb = words([uP, uQ]), words([uX, uY])
write(os.path.join(d, "fx/runs"), f"settle {wa}\nsettle {wb}\n")
write(os.path.join(d, "rules"),
"""R-AP28 R-AP34 R-AP17 R-AP59 R-AP41 R-AP43 R-DA8 R-IX3 R-ID7 (slice 208, entry registry, the word settle): Design Q421, Q423.
Run 1 (Q421): P gets a 502 answer, Q gets no answer (the fake route has `error timeout`). Each is case 3 for its URL with ONE warning that names the URL and `502` or `no answer`. The exit code does not change (the app returns 0 and no `exit` line), the ingests are sent once (R-AP34), and there is NO second query (no ingest answered 200 or 201). Both values end as archive.
Run 2 (Q423): X and Y get 200 and 201 with NO `Talon-Bookmark`: the second query is sent once with `Cache-Control: no-cache` and no `Talon-Bookmark` header. Its answer has the release of X and still lists Y as unknown: X ends as indexed, Y ends as archive (case 3), and there is no third query and no more ingest. No warning.
The warning text is a proposal (R-OUT2): the text of UnknownValues.unindexed_warning.
""")
def warn2(url, what): return f"warning: {url}: the registry did not index this release ({what}). Talon reads the archive.\n"
stdout = out(wa, [(hP, "archive"), (hQ, "archive")], 70, 0, [hP, hQ]) + out(wb, [(hX, "indexed"), (hY, "archive")], 81, 1, [hY])
write(os.path.join(d, "expect/stdout"), stdout)
write(os.path.join(d, "expect/stderr"), warn2(uP, "502") + warn2(uQ, "no answer"))
calls = "env_all\n" + closure_call(body_of([hP, hQ])) + "programs curl\n" + ALL + ingest_call(uP) + ingest_call(uQ)
calls += closure_call(body_of([hX, hY])) + "programs curl\n" + ALL + ingest_call(uX) + ingest_call(uY)
calls += closure_call(body_of([hX, hY]), "  Cache-Control: no-cache\n")
write(os.path.join(d, "expect/calls.log"), calls)
write(os.path.join(d, "expect/exit"), "0\n")
print("ok")
