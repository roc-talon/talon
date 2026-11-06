#!/usr/bin/env python3
# Slice 212: writes the L2 cases of tests/commands/cases/registry/ (fx, entry, rules, and the expect files BY HAND from the rules, not from a run).
# Run from the repo root: python3 -I research/slice-212-revert/mkcases.py
import hashlib, json, os, shutil

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "127.0.0.1%3A9"
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
HOME = "$HOME/.cache/roc/talon"
REGDIR = HOME + "/index/registry/http_127.0.0.1_9/get"
UA = "  User-Agent: tln/0.0.1\n"

def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n:
        n, r = divmod(n, 58); s = ALPHA[r] + s
    return s

def H(name): return b58(hashlib.sha256(b"slice212-" + name.encode()).digest())

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)

def fresh(name, programs=True):
    d = os.path.join(CASES, name)
    shutil.rmtree(d, ignore_errors=True)
    write(os.path.join(d, "entry"), "registry\n")
    if programs: write(os.path.join(d, "fx/programs"), "curl\n")
    return d

def meta(status, headers=(), require=()):
    t = f"status {status}\n"
    for h in headers: t += f"header {h}\n"
    for r in require: t += f"{r}\n"
    return t

def route(d, host, path, body, status=200, headers=(), require=()):
    write(os.path.join(d, "fx/http", host, path), body)
    write(os.path.join(d, "fx/http", host, path + ".meta"), meta(status, headers, require))

GH = "api.github.com"
JSON = "Content-Type: application/json"
PROBLEM = "Content-Type: application/problem+json"

def tag_url(repo, tag, h): return f"https://github.com/acme/{repo}/releases/download/{tag}/{h}.tar.zst"

def gh_release(repo, tag, h, published, draft=False, prerelease=False, extra_assets=()):
    assets = [{"name": f"{h}.tar.zst", "size": 1000, "browser_download_url": tag_url(repo, tag, h)}]
    for e in extra_assets: assets.append({"name": f"{e}.tar.zst", "size": 1000, "browser_download_url": tag_url(repo, tag, e)})
    return {"tag_name": tag, "draft": draft, "prerelease": prerelease, "published_at": published, "assets": assets}

def compact(x): return json.dumps(x, separators=(",", ":"))

def guard_route(d, repo, private=False, status=200, with_list=True):
    body = compact({"id": 1, "full_name": f"acme/{repo}", "private": private, "fork": False})
    p = f"repos/acme/{repo}" + ("/@" if with_list else "")
    write(os.path.join(d, "fx/http", GH, p), body)
    write(os.path.join(d, "fx/http", GH, f"repos/acme/{repo}.meta"), meta(status, [JSON]))
    return body

def list_route(d, repo, releases):
    body = compact(releases)
    route(d, GH, f"repos/acme/{repo}/releases%3Fper_page=100", body, 200, [JSON, 'ETag: "g1"'])
    return body

def problem(kind, status, title): return compact({"type": f"/errors/{kind}", "title": title, "status": status, "detail": "x"})

def ingest_route(d, n, status, headers=(), body="{\"status\":\"indexed\"}"):
    p = "v1/releases.POST" + ("" if n == 1 else f".{n}")
    route(d, HOST, p, body, status, headers, ["require content-type: application/json", "require-none authorization", "require-none talon-contributor"])

def row(log, h, repo, version):
    return {"log_index": log, "hash": h, "group": f"github.com/acme/{repo}/releases/download/{{v}}/", "series": version.split(".")[0], "version": version, "url": tag_url(repo, version, h), "tag": version,
            "roc_version": None, "repo": f"acme/{repo}", "published_at": 1790848800000, "yanked": False, "yank_reason": None, "withdrawn": None, "provenance": ["ingest"]}

def releases_body(rows): return compact({"releases": rows, "checked": None, "repos": []})

def reg_first(d, repo, status=404, body=None):
    route(d, HOST, f"v1/packages/acme/{repo}/releases", body or problem("not-found", 404, "Not found"), status, [PROBLEM], ["require-none authorization", "require-none cache-control", "require-none if-none-match"])

def reg_second(d, repo, body, bookmark, n=2):
    route(d, HOST, f"v1/packages/acme/{repo}/releases.{n}", body, 200, [JSON, 'ETag: "r1"', "Cache-Control: max-age=60"],
          ["require cache-control: no-cache", f"require talon-bookmark: {bookmark}", "require-none if-none-match", "require-none authorization"])

def reg_key(repo): return hashlib.sha256(f"/v1/packages/acme/{repo}/releases".encode()).hexdigest()[:32]

# ---- the expected calls
def c_guard(repo, body, tok="tok1"):
    f = f"{HOME}/index/github/acme/{repo}/repo.json"
    return f"read_files {f}\nhttp_get https://api.github.com/repos/acme/{repo}\n{UA}  Authorization: Bearer {tok}\nwrite_atomic {f}\n"
def c_guard_refused(repo, tok="tok1"):
    f = f"{HOME}/index/github/acme/{repo}/repo.json"
    return f"read_files {f}\nhttp_get https://api.github.com/repos/acme/{repo}\n{UA}  Authorization: Bearer {tok}\n"
def c_reg_first(repo):
    return f"list_dirs {REGDIR}\nhttp_get http://127.0.0.1:9/v1/packages/acme/{repo}/releases\n{UA}"
def c_gh_list(repo, tok="tok1"):
    dr = f"{HOME}/index/github/acme/{repo}"
    return f"list_dirs {dr}\nhttp_get https://api.github.com/repos/acme/{repo}/releases?per_page=100\n{UA}  Authorization: Bearer {tok}\nwrite_atomic {dr}/1.json {dr}/1.meta\n"
def c_ingest(urls):
    t = "programs curl\nhttp_all limit=4 tmp=$HOME/.cache/roc/talon/tmp\n"
    for u in urls:
        t += "http_send POST http://127.0.0.1:9/v1/releases timeout=20\n" + UA + "  Content-Type: application/json\n  <body> " + compact({"url": u}) + "\n"
    return t
def c_reg_again(repo, bookmark, wrote=True):
    k = reg_key(repo)
    t = f"http_get http://127.0.0.1:9/v1/packages/acme/{repo}/releases\n{UA}  Cache-Control: no-cache\n  Talon-Bookmark: {bookmark}\n"
    if wrote: t += f"write_atomic {REGDIR}/{k}.json {REGDIR}/{k}.meta\n"
    return t

# ---- the expected tree.diff
def newfile(path, content):
    lines = content.split("\n")
    nonl = not content.endswith("\n")
    if not nonl: lines = lines[:-1]
    n = len(lines)
    t = f"--- {path}\n+++ {path}\n@@ -0,0 +1{',' + str(n) if n != 1 else ''} @@\n"
    for i, l in enumerate(lines):
        t += "+" + l + "\n"
    if nonl: t += "\\ No newline at end of file\n"
    return t
def t_guard(repo, body): return newfile(f"home/.cache/roc/talon/index/github/acme/{repo}/repo.json", body)
def t_gh(repo, body):
    dr = f"home/.cache/roc/talon/index/github/acme/{repo}"
    return newfile(f"{dr}/1.json", body) + newfile(f"{dr}/1.meta", 'etag "g1"\n')
def t_reg(repo, body):
    d = "home/.cache/roc/talon/index/registry/http_127.0.0.1_9/get"
    k = reg_key(repo)
    return newfile(f"{d}/{k}.json", body) + newfile(f"{d}/{k}.meta", f'url /v1/packages/acme/{repo}/releases\netag "r1"\nmax-age 60\n')
def tree(*parts):
    # the order of diff -r with LC_ALL=C: by path
    items = []
    for p in parts:
        for chunk in p.split("--- ")[1:]:
            path = chunk.split("\n", 1)[0]
            items.append((path, "--- " + chunk))
    # a file's `---` and `+++` blocks come together: group them by path (each newfile gives 1 block)
    items.sort(key=lambda x: x[0].encode())
    return "".join(c for _, c in items)

def expect(d, stdout="", stderr="", calls="", exit_="0", treediff=""):
    e = os.path.join(d, "expect")
    write(os.path.join(e, "stdout"), stdout)
    write(os.path.join(e, "stderr"), stderr)
    write(os.path.join(e, "calls.log"), "env_all\n" + calls)
    write(os.path.join(e, "exit"), exit_ + "\n")
    if treediff: write(os.path.join(e, "tree.diff"), treediff)

def runs(d, lines, rules):
    write(os.path.join(d, "fx/runs"), "".join(l + "\n" for l in lines))
    write(os.path.join(d, "rules"), rules)

# the releases of a repository on GitHub, in the order of the page
def page_of(repo):
    return [
        gh_release(repo, "1.0.0", H(repo + "1.0.0"), "2026-06-01T12:00:00Z"),
        gh_release(repo, "2.0.0", H(repo + "2.0.0"), "2026-08-01T12:00:00Z"),
        gh_release(repo, "1.5.0", H(repo + "1.5.0"), "2026-07-01T12:00:00Z"),
    ]
def hh(repo, v): return H(repo + v)
def eline(line): return f"== {line}\n"
def fail_line(kind, msg): return f"tln: error[{kind}]: {msg}\n"
NOCAND = "A release needs one <hash>.tar.zst asset and must not be a draft or a prerelease."

# ======== ad35-ingest
d = fresh("ad35-ingest")
repo = "lib"
page = [
    gh_release(repo, "1.0.0", hh(repo, "1.0.0"), "2026-06-01T12:00:00Z"),
    gh_release(repo, "2.0.0", hh(repo, "2.0.0"), "2026-08-01T12:00:00Z"),
    gh_release(repo, "1.5.0", hh(repo, "1.5.0"), "2026-07-01T12:00:00Z"),
    gh_release(repo, "1.2.0", hh(repo, "1.2.0"), "2026-07-15T12:00:00Z"),
    gh_release(repo, "1.1.0", hh(repo, "1.1.0"), "2026-06-20T12:00:00Z"),
    gh_release(repo, "3.0.0", hh(repo, "3.0.0"), "2026-08-10T12:00:00Z", draft=True),
    gh_release(repo, "3.1.0", hh(repo, "3.1.0"), "2026-08-11T12:00:00Z", prerelease=True),
    gh_release(repo, "0.9.0", hh(repo, "0.9.0a"), "2026-05-01T12:00:00Z", extra_assets=[hh(repo, "0.9.0b")]),
    gh_release(repo, "latest", hh(repo, "latest"), "2026-08-12T12:00:00Z"),
]
gbody = guard_route(d, repo)
lbody = list_route(d, repo, page)
reg_first(d, repo)
bm_a, bm_c, bm_e = "0000000a-00000010-00004c60-8e61", "0000000c-00000030-00004c70-1f22", "0000000b-00000020-00004c68-9a10"
# newest first by published_at: 2.0.0 (08-01), 1.2.0 (07-15), 1.5.0 (07-01), 1.1.0 (06-20), 1.0.0 (06-01)
order = ["2.0.0", "1.2.0", "1.5.0", "1.1.0", "1.0.0"]
ingest_route(d, 1, 201, [JSON, f"Talon-Bookmark: {bm_a}"])
ingest_route(d, 2, 409, [PROBLEM], problem("label-conflict", 409, "Conflict"))
ingest_route(d, 3, 200, [JSON, f"Talon-Bookmark: {bm_c}"])
ingest_route(d, 4, 422, [PROBLEM], problem("not-a-candidate", 422, "Unprocessable"))
ingest_route(d, 5, 201, [JSON, f"Talon-Bookmark: {bm_e}"])
rows = [row(1, hh(repo, "1.0.0"), repo, "1.0.0"), row(2, hh(repo, "1.5.0"), repo, "1.5.0"), row(3, hh(repo, "2.0.0"), repo, "2.0.0")]
abody = releases_body(rows)
reg_second(d, repo, abody, bm_c)
line = "fullname acme/lib env:GITHUB_TOKEN=tok1"
runs(d, [line],
"""R-AD35 R-AD2 R-SC3 R-SC4 R-RG4 R-AP1 R-AP9 R-AP41 R-AP43 R-AP25 R-DI2 R-DI3 R-DI4 R-DI5 R-DA8 R-DA9 R-AP45 R-AP23 R-AP34 R-IX3 (slice 212, entry registry, the word fullname): a full name that the registry did not index.
The order of the calls (R-AD35): the privacy guard first (R-RG4: before the first request that carries the name; repo.json is kept), then GET R-AP1 answers 404, then the release list of GitHub (R-DI2, with the token), then ONE `programs curl` and ONE http_all with limit 4 and 5 POSTs of /v1/releases (no Authorization, no Talon-Contributor), then R-AP1 again.
The GitHub page has 9 releases. Not candidates: 3.0.0 is a draft and 3.1.0 a prerelease (R-DI3), 0.9.0 has 2 package assets (R-DI4: no candidate and a warning that names it), `latest` has no X.Y.Z run in its URL (R-DI5). The 5 candidates are ingested NEWEST FIRST by published_at: 2.0.0, 1.2.0, 1.5.0, 1.1.0, 1.0.0 (not the page order, not the version order).
The answers: 2.0.0 201 with a bookmark, 1.2.0 409 label-conflict, 1.5.0 200 with the LARGEST bookmark, 1.1.0 422 not-a-candidate, 1.0.0 201 with a bookmark between. A 409 and a 422 skip the release with a warning that names it and the error type (R-AD35 step 3); the command goes on, exit 0.
Then R-AP1 is read again with Cache-Control: no-cache and the largest bookmark (the third in time, not the first and not the last), with no If-None-Match (no local copy, R-AP43): the route requires them. The answer is 200: the 3 indexed releases. The copy is kept (R-IX3).
The texts of the warnings are proposals (R-OUT2): FullName.skip_warning and the R-DI4 warning of Index.candidates.
""")
urls = [tag_url(repo, v, hh(repo, v)) for v in order]
calls = c_guard(repo, gbody) + c_reg_first(repo) + c_gh_list(repo) + c_ingest(urls) + c_reg_again(repo, bm_c)
out = eline(line) + "releases 3\n" + "".join(f"release {r['version']} {r['hash']}\n" for r in rows)
err = (f"warning: acme/lib 0.9.0: the release has 2 package assets ({hh(repo,'0.9.0a')}, {hh(repo,'0.9.0b')}). It is not a candidate.\n"
       "warning: acme/lib 1.2.0: skipped, the registry answered 409 (/errors/label-conflict).\n"
       "warning: acme/lib 1.1.0: skipped, the registry answered 422 (/errors/not-a-candidate).\n")
expect(d, out, err, calls, "0", tree(t_guard(repo, gbody), t_gh(repo, lbody), t_reg(repo, abody)))

# ======== ad35-selector (3 runs: a range, an exact version, a selector that keeps nothing)
d = fresh("ad35-selector")
tr = []
posts = 0
ls = []
out = ""; err = ""; calls = ""; tdiff = []
# run 1: ^1 keeps 1.5.0 and 1.0.0, newest first
for i, (repo, sel, keep) in enumerate([("sel1", "^1", ["1.5.0", "1.0.0"]), ("sel2", "1.0.0", ["1.0.0"]), ("sel3", "9.9.9", [])]):
    gbody = guard_route(d, repo)
    lbody = list_route(d, repo, page_of(repo))
    reg_first(d, repo)
    line = f"fullname acme/{repo} sel={sel} env:GITHUB_TOKEN=tok1"
    ls.append(line)
    out += eline(line)
    calls += c_guard(repo, gbody) + c_reg_first(repo) + c_gh_list(repo)
    tdiff += [t_guard(repo, gbody), t_gh(repo, lbody)]
    if keep:
        marks = []
        for k in keep:
            posts += 1
            bm = f"0000000{posts}-00000010-00004c60-8e61"
            marks.append(bm)
            ingest_route(d, posts, 201, [JSON, f"Talon-Bookmark: {bm}"])
        rws = [row(j + 1, hh(repo, k), repo, k) for j, k in enumerate(keep)]
        ab = releases_body(rws)
        reg_second(d, repo, ab, max(marks))
        calls += c_ingest([tag_url(repo, k, hh(repo, k)) for k in keep]) + c_reg_again(repo, max(marks))
        out += f"releases {len(rws)}\n" + "".join(f"release {r['version']} {r['hash']}\n" for r in rws)
        tdiff.append(t_reg(repo, ab))
    else:
        out += "no match\n"
runs(d, ls,
"""R-AD35 R-AD2 R-SC3 R-SC4 R-SL3 R-SL4 R-SL5 R-DI6 R-AP1 R-AP9 R-AP41 R-AP43 R-DA8 (slice 212, entry registry, the word fullname): the selector of the command (R-AD35 step 1) keeps the candidates that are ingested (step 3).
Each run is another repository (acme/sel1, sel2, sel3), each with 3 candidates on GitHub: 1.0.0 (June), 2.0.0 (August), 1.5.0 (July).
Run 1, sel=^1 (a range): 2.0.0 is not ingested. 2 POSTs, newest first: 1.5.0 then 1.0.0. Run 2, sel=1.0.0 (exact): one POST, for 1.0.0 only.
Run 3, sel=9.9.9: the selector keeps no candidate (R-AD35 step 2): the result is `no match` (the command gives its own text, Design Q430, slice 206b), and nothing after the GitHub read: no `programs curl`, no POST, no second read of R-AP1.
In runs 1 and 2 the bookmarks grow with the order of the POSTs of the case (run 1: 1 and 2, run 2: 3): the second read has the largest of the run. """)
expect(d, out, err, calls, "0", tree(*tdiff))

# ======== ad35-still-404
d = fresh("ad35-still-404")
repo = "slow"
gbody = guard_route(d, repo)
lbody = list_route(d, repo, [gh_release(repo, "1.0.0", hh(repo, "1.0.0"), "2026-06-01T12:00:00Z")])
reg_first(d, repo)
bm = "0000000a-00000010-00004c60-8e61"
ingest_route(d, 1, 201, [JSON, f"Talon-Bookmark: {bm}"])
route(d, HOST, f"v1/packages/acme/{repo}/releases.2", problem("not-found", 404, "Not found"), 404, [PROBLEM],
      ["require cache-control: no-cache", f"require talon-bookmark: {bm}", "require-none if-none-match"])
line = "fullname acme/slow env:GITHUB_TOKEN=tok1"
runs(d, [line],
"""R-AD35 R-AD2 R-AP1 R-AP43 R-AP41 R-E6 (slice 212, entry registry, the word fullname): step 4 of R-AD35: R-AP1 is still 404 after the ingests.
One candidate. Its ingest answers 201 (so it is indexed), but the read after it, with no-cache and the bookmark, is still 404 (R-AD35 step 4: a queue of Q30, or a slow colo). Talon stops with exit 15 (kind network), and the message says that the registry indexes the repository and to run the command again. No third read, no second ingest (R-AP34).
Nothing of R-AP1 is kept (a 404 is not a copy, R-IX3). The text is a proposal (R-OUT2): FullName.still_missing.
""")
calls = c_guard(repo, gbody) + c_reg_first(repo) + c_gh_list(repo) + c_ingest([tag_url(repo, "1.0.0", hh(repo, "1.0.0"))]) + c_reg_again(repo, bm, wrote=False)
expect(d, eline(line) + "exit 15\n", fail_line("network", "the registry has no release of acme/slow yet. The registry is indexing the repository: run the command again in a moment."), calls, "0", tree(t_guard(repo, gbody), t_gh(repo, lbody)))

# ======== ad35-rate-limited
d = fresh("ad35-rate-limited")
repo = "limit"
gbody = guard_route(d, repo)
lbody = list_route(d, repo, page_of(repo)[:2])
reg_first(d, repo)
ingest_route(d, 1, 201, [JSON, "Talon-Bookmark: 0000000a-00000010-00004c60-8e61"])
ingest_route(d, 2, 429, [PROBLEM, "Retry-After: 30"], problem("rate-limited", 429, "Too many requests"))
line = "fullname acme/limit env:GITHUB_TOKEN=tok1"
runs(d, [line],
"""R-AD35 R-AD2 R-AP25 R-E6 R-AP34 R-AP28 (slice 212, entry registry, the word fullname): a 429 answer to an ingest of step 3.
2 candidates, newest first: 2.0.0 then 1.0.0. One http_all with both POSTs. The first answers 201 (it stays indexed), the second 429 with Retry-After 30. Talon stops with exit 15 (kind network) at once, with `Try again in 30 s.` (R-AP25, Design Q424): NO second read of R-AP1, although one ingest indexed. An ingest is sent once (R-AP34).
""")
calls = c_guard(repo, gbody) + c_reg_first(repo) + c_gh_list(repo) + c_ingest([tag_url(repo, v, hh(repo, v)) for v in ["2.0.0", "1.0.0"]])
expect(d, eline(line) + "exit 15\n", fail_line("network", "the registry answered 429 (/errors/rate-limited). Try again in 30 s."), calls, "0", tree(t_guard(repo, gbody), t_gh(repo, lbody)))

# ======== ad36-snapshot
d = fresh("ad36-snapshot")
repo = "snap"
gbody = guard_route(d, repo, with_list=False)
reg_first(d, repo)
line = "fullname acme/snap log=40 env:GITHUB_TOKEN=tok1"
runs(d, [line],
"""R-AD36 R-AD35 R-RG4 R-AP19 R-EC2 (slice 212, entry registry, the word fullname): `--snapshot log:N` sends no ingest.
The guard runs and R-AP1 answers 404. With log:40 Talon sends no ingest (a new release has a log index above 40): exit 2, and the message says that the name has no release in the log at size 40. No GitHub release list (nothing to select, the text needs no GitHub data: Question Q1 of the slice file), no `programs curl`, no POST, no second read.
The text is a proposal (R-OUT2): FullName.snapshot_stop.
""")
calls = c_guard(repo, gbody) + c_reg_first(repo)
expect(d, eline(line) + "exit 2\n", fail_line("usage", "acme/snap has no release in the log at size 40. A snapshot sends no ingest."), calls, "0", tree(t_guard(repo, gbody)))

# ======== ad35-stop-cases (the guard stops, no candidate)
d = fresh("ad35-stop-cases")
gp = guard_route(d, "priv", private=True, with_list=False)
write(os.path.join(d, "fx/http", GH, "repos/acme/none.meta"), meta(404, [JSON]))
write(os.path.join(d, "fx/http", GH, "repos/acme/none"), '{"message":"Not Found"}')
repo = "empty"
gbody = guard_route(d, repo)
lbody = list_route(d, repo, [gh_release(repo, "1.0.0", hh(repo, "1.0.0"), "2026-06-01T12:00:00Z", draft=True),
                             gh_release(repo, "2.0.0", hh(repo, "2.0.0"), "2026-07-01T12:00:00Z", prerelease=True),
                             {"tag_name": "3.0.0", "draft": False, "prerelease": False, "published_at": "2026-08-01T12:00:00Z", "assets": [{"name": "docs.tar.gz", "size": 5, "browser_download_url": tag_url(repo, "3.0.0", "docs")}]}])
reg_first(d, repo)
l1, l2, l3 = "fullname acme/priv env:GITHUB_TOKEN=tok1", "fullname acme/none env:GITHUB_TOKEN=tok1", "fullname acme/empty env:GITHUB_TOKEN=tok1"
runs(d, [l1, l2, l3],
"""R-AD35 R-RG4 R-RG6 R-EC2 R-DI3 R-DI4 R-T10 (slice 212, entry registry, the word fullname): the stop cases of R-AD35 step 2.
Run 1, acme/priv: GitHub says `private: true`. The guard stops the command with exit 2 (R-RG6, private packages are not supported) BEFORE the first request that carries the name: NO GET of R-AP1 at all. Run 2, acme/none: GitHub answers 404 for the name: the same stop, with the text for a request with a token.
Run 3, acme/empty: public, R-AP1 answers 404, GitHub has 3 releases and none is a candidate (a draft, a prerelease, a release with no package asset): exit 2 (R-AD35 step 2, as R-T10). No `programs curl`, no POST, no second read.
The text of run 3 is a proposal (R-OUT2): FullName.no_candidate. The texts of runs 1 and 2 are those of slice 203.
""")
calls = (c_guard_refused("priv") + c_guard_refused("none") + c_guard(repo, gbody) + c_reg_first(repo) + c_gh_list(repo))
out = eline(l1) + "exit 2\n" + eline(l2) + "exit 2\n" + eline(l3) + "exit 2\n"
err = (fail_line("usage", "GitHub repository acme/priv is private or does not exist. Private packages are not supported.") +
       fail_line("usage", "GitHub repository acme/none is private or does not exist. Private packages are not supported.") +
       fail_line("usage", f"acme/empty has no release that Talon can use. {NOCAND}"))
expect(d, out, err, calls, "0", tree(t_guard(repo, gbody), t_gh(repo, lbody)))

# ======== ad35-no-curl
d = fresh("ad35-no-curl", programs=False)
repo = "nocurl"
gbody = guard_route(d, repo)
lbody = list_route(d, repo, [gh_release(repo, "1.0.0", hh(repo, "1.0.0"), "2026-06-01T12:00:00Z")])
reg_first(d, repo)
line = "fullname acme/nocurl env:GITHUB_TOKEN=tok1"
runs(d, [line],
"""R-AD35 R-DA8 R-EC18 R-AP28 (slice 212, entry registry, the word fullname): no `curl` for the ingests (Design Q229).
One candidate. The command asks `programs curl` before `http_all!` (the Fx call has no exit code): no `curl` is exit 18 (kind environment) that names curl. No request of an ingest, no second read. The text is the one of slice 208 (UnknownValues.settle!).
""")
calls = c_guard(repo, gbody) + c_reg_first(repo) + c_gh_list(repo) + "programs curl\n"
expect(d, eline(line) + "exit 18\n", fail_line("environment", "curl is not on PATH. Talon needs curl to send the ingests at the same time."), calls, "0", tree(t_guard(repo, gbody), t_gh(repo, lbody)))

# ======== ad35-known (the registry knows the name: no ingest)
d = fresh("ad35-known")
repo = "known"
gbody = guard_route(d, repo, with_list=False)
rows = [row(1, hh(repo, "1.0.0"), repo, "1.0.0"), row(2, hh(repo, "1.1.0"), repo, "1.1.0")]
kbody = releases_body(rows)
route(d, HOST, f"v1/packages/acme/{repo}/releases", kbody, 200, [JSON, 'ETag: "r1"', "Cache-Control: max-age=60"], ["require-none authorization", "require-none cache-control"])
line = "fullname acme/known env:GITHUB_TOKEN=tok1"
runs(d, [line],
"""R-AD35 R-AP1 R-RG4 R-IX3 R-AP24 (slice 212, entry registry, the word fullname): the registry knows the name: no ingest.
The guard runs first (R-RG4: the name is in the request). R-AP1 answers 200: the answer is the result. No GitHub release list, no `programs curl`, no POST, no second read (R-AD35 is for a 404 only). The copy is kept (R-IX3).
""")
calls = c_guard(repo, gbody) + c_reg_first(repo) + f"write_atomic {REGDIR}/{reg_key(repo)}.json {REGDIR}/{reg_key(repo)}.meta\n"
out = eline(line) + "releases 2\n" + "".join(f"release {r['version']} {r['hash']}\n" for r in rows)
expect(d, out, "", calls, "0", tree(t_guard(repo, gbody), t_reg(repo, kbody)))

# ======== ad37-offline
d = fresh("ad37-offline")
line = "fullname acme/off offline env:GITHUB_TOKEN=tok1"
runs(d, [line],
"""R-AD37 R-AD35 R-DI12 R-IX6 R-RG4 (slice 212, entry registry, the word fullname): `--offline` sends no request.
No kept copy of R-AP1 for acme/off. With --offline the guard makes no request (R-RG4), the read of R-AP1 uses the copies only, and with no copy the command stops with exit 15 (R-DI12: a new name with no cached page, as R-IX6). No GitHub read, no ingest. The text is the one of Github.no_page_failure.
""")
calls = f"list_dirs {REGDIR}\n"
expect(d, eline(line) + "exit 15\n", fail_line("network", "the index of acme/off has no cached page and --offline is set. Run the command without --offline."), calls, "0")

# ======== ad35-other-answers (Q398)
d = fresh("ad35-other-answers")
repo = "other"
vers = ["5.0.0", "4.0.0", "3.0.0", "2.0.0", "1.0.0"]   # newest first: 5.0.0 (09-01) ... 1.0.0 (05-01)
times = ["2026-09-01", "2026-08-01", "2026-07-01", "2026-06-01", "2026-05-01"]
gbody = guard_route(d, repo)
lbody = list_route(d, repo, [gh_release(repo, v, hh(repo, v), t + "T12:00:00Z") for v, t in zip(reversed(vers), reversed(times))])
reg_first(d, repo)
bm = "0000000a-00000010-00004c60-8e61"
ingest_route(d, 1, 201, [JSON, f"Talon-Bookmark: {bm}"])                                       # 5.0.0 indexed
ingest_route(d, 2, 502, [PROBLEM], problem("bad-gateway", 502, "Bad gateway"))                  # 4.0.0 warning, status
ingest_route(d, 3, 403, [PROBLEM], problem("forbidden", 403, "Forbidden"))                      # 3.0.0 skip, no warning
write(os.path.join(d, "fx/http", HOST, "v1/releases.POST.4"), "")
write(os.path.join(d, "fx/http", HOST, "v1/releases.POST.4.meta"), "error timeout\nrequire content-type: application/json\nrequire-none authorization\nrequire-none talon-contributor\n")  # 2.0.0 no answer
ingest_route(d, 5, 202, [JSON], "{}")                                                           # 1.0.0 a 202
rows = [row(1, hh(repo, "5.0.0"), repo, "5.0.0")]
abody = releases_body(rows)
reg_second(d, repo, abody, bm)
line = "fullname acme/other env:GITHUB_TOKEN=tok1"
runs(d, [line],
"""R-AD35 R-AD2 R-AP28 R-AP41 R-AP43 R-AP34 (slice 212, Design Q398, Q421, entry registry, the word fullname): the ingest answers that the rule of step 3 does not name.
5 candidates, newest first: 5.0.0 gets 201 (indexed), 4.0.0 a 502 (skip, a warning with the status), 3.0.0 a 403 (another 4xx: skip, NO warning), 2.0.0 no answer (a timeout: skip, a warning with `no answer`), 1.0.0 a 202 (skip, a warning with the status).
One ingest indexed, so R-AP1 is read again (Q399) with the bookmark of the 201. Exit 0. No ingest is sent again (R-AP34). The text of the warning is a proposal (R-OUT2): FullName.unindexed_warning.
""")
urls = [tag_url(repo, v, hh(repo, v)) for v in vers]
calls = c_guard(repo, gbody) + c_reg_first(repo) + c_gh_list(repo) + c_ingest(urls) + c_reg_again(repo, bm)
out = eline(line) + "releases 1\n" + "".join(f"release {r['version']} {r['hash']}\n" for r in rows)
err = ("warning: acme/other 4.0.0: skipped, the registry did not index this release (502).\n"
       "warning: acme/other 2.0.0: skipped, the registry did not index this release (no answer).\n"
       "warning: acme/other 1.0.0: skipped, the registry did not index this release (202).\n")
expect(d, out, err, calls, "0", tree(t_guard(repo, gbody), t_gh(repo, lbody), t_reg(repo, abody)))

# ======== ad35-no-ingested (Q399): all 409/422, and one 5xx, with no 200 or 201
d = fresh("ad35-no-ingested")
two = lambda repo: [gh_release(repo, "1.0.0", hh(repo, "1.0.0"), "2026-06-01T12:00:00Z"), gh_release(repo, "2.0.0", hh(repo, "2.0.0"), "2026-07-01T12:00:00Z")]
ls = []; out = ""; err = ""; calls = ""; tdiff = []
for repo, answers in [("all409", [(409, "label-conflict", "Conflict"), (422, "not-a-candidate", "Unprocessable")]), ("one5xx", [(409, "label-conflict", "Conflict"), (502, "bad-gateway", "Bad gateway")])]:
    gbody = guard_route(d, repo)
    lbody = list_route(d, repo, two(repo))
    reg_first(d, repo)
    line = f"fullname acme/{repo} env:GITHUB_TOKEN=tok1"
    ls.append(line)
    calls += c_guard(repo, gbody) + c_reg_first(repo) + c_gh_list(repo) + c_ingest([tag_url(repo, v, hh(repo, v)) for v in ["2.0.0", "1.0.0"]])
    tdiff += [t_guard(repo, gbody), t_gh(repo, lbody)]
    out += eline(line) + ("exit 2\n" if repo == "all409" else "exit 15\n")
    n = 1 if repo == "all409" else 3
    for k, (st, kind, title) in enumerate(answers):
        pass
    tags = ["2.0.0", "1.0.0"]
    for (st, kind, title), tg in zip(answers, tags):
        if st in (409, 422): err += f"warning: acme/{repo} {tg}: skipped, the registry answered {st} (/errors/{kind}).\n"
        else: err += f"warning: acme/{repo} {tg}: skipped, the registry did not index this release ({st}).\n"
    if repo == "all409": err += fail_line("usage", f"acme/{repo} has no release that Talon can use. {NOCAND}")
    else: err += fail_line("network", f"the registry did not index acme/{repo} now. Run the command again in a moment.")
posts = 0
for repo, answers in [("all409", [(409, "label-conflict", "Conflict"), (422, "not-a-candidate", "Unprocessable")]), ("one5xx", [(409, "label-conflict", "Conflict"), (502, "bad-gateway", "Bad gateway")])]:
    for st, kind, title in answers:
        posts += 1
        ingest_route(d, posts, st, [PROBLEM], problem(kind, st, title))
runs(d, ls,
"""R-AD35 R-AP65 R-AP41 R-AP43 R-AP34 R-E6 (slice 212, Design Q399, entry registry, the word fullname): step 4 asks R-AP1 again only after a 200 or 201.
Run 1, acme/all409: 2 candidates, 2.0.0 gets 409 and 1.0.0 gets 422: each is skipped with its warning (type in it), nothing is indexed, NO second read: exit 2 with the text of no candidate.
Run 2, acme/one5xx: 2.0.0 gets 409 (skip with a warning) and 1.0.0 gets 502 (skip with a warning with the status): no 200 or 201, NO second read: exit 15, and the message says that the registry did not index the name now and to run the command again (a proposal, R-OUT2: FullName.not_indexed).
""")
expect(d, out, err, calls, "0", tree(*tdiff))

# ======== ad35-way (Q397): selectors that stop or that are a source build, before any request
d = fresh("ad35-way", programs=False)
l1, l2, l3 = "fullname acme/way sel=nightly-2026-10-09-258ab27 env:GITHUB_TOKEN=tok1", "fullname acme/way sel=-1 env:GITHUB_TOKEN=tok1", "fullname acme/way sel=dd03c09e env:GITHUB_TOKEN=tok1"
runs(d, [l1, l2, l3],
"""R-AD35 R-SL6 R-SL7 R-SL8 R-SL10 R-SL11 R-SL13 (slice 212, Design Q397, entry registry, the word fullname): the selector forms that have no registry path. There is no fixture and no `programs` file: any call would be seen in calls.log (and the fake answers 404).
Run 1, a nightly tag, and run 2, a relative step: for a compiler only: exit 2 before any request (no guard, no read). Run 3, a sha that is not a version, a range or a series: a source build: no registry path, no request, no ingest (the result is `source build`).
The text of the stop is a proposal (R-OUT2): FullName.compiler_only. The forms that keep the matches are in ad35-selector and in the L0 file.
""")
expect(d, eline(l1) + "exit 2\n" + eline(l2) + "exit 2\n" + eline(l3) + "source build\n",
       fail_line("usage", "acme/way@nightly-2026-10-09-258ab27: a nightly tag and a relative step name a compiler release. acme/way is not a compiler.") +
       fail_line("usage", "acme/way@-1: a nightly tag and a relative step name a compiler release. acme/way is not a compiler."), "", "0")
print("ok")
