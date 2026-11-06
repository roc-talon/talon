#!/usr/bin/env python3
# Makes the fixture part of packages/records/tests/AnswerTest.roc from the W2 expected bodies of slices 106, 107 and 109 (worker/tests/cases/*/expect/responses.jsonl).
# Run from the repo root: python3 research/slice-104e-revert/gen.py > /tmp/fixtures.roc
import json
C = "worker/tests/cases/"
def bodies(case, cap):
    seen = []
    for line in open(C + case + "/expect/responses.jsonl"):
        r = json.loads(line)
        b = r.get("body")
        if isinstance(b, str) and r["status"] in (200, 201) and b not in seen: seen.append(b)
    return seen[:cap]
def lit(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
def block(name, doc, items):
    print(f"# {doc}")
    print(f"{name} : List(Str)\n{name} = [")
    for b in items: print("\t" + lit(b) + ",")
    print("]\n")
releases = bodies("reads/ap1-body-etag-cache", 1) + bodies("reads/ap13-group-series-after", 4)
def with_mark(b, first):
    # Slice 104i (R-AP81): the W2 bodies of 106 have no `is_platform` yet (slice 125). Insert it after `hash` in each dep: false, and true for the dep `b` of the first body.
    j = json.loads(b)
    deps = []
    for d in j["artifact"]["deps"]:
        n = {}
        for k, v in d.items():
            n[k] = v
            if k == "hash": n["is_platform"] = bool(first and d["alias"] == "b")
        deps.append(n)
    j["artifact"]["deps"] = deps
    return json.dumps(j, separators=(",", ":"), ensure_ascii=False)
detail_raw = bodies("reads/ap2-artifact", 4)
detail = [with_mark(b, i == 0) for i, b in enumerate(detail_raw)]
page = []
for b in detail_raw:
    j = json.loads(b)
    page.append(json.dumps({"releases": j["releases"], "repos": j["repos"]}, separators=(",", ":"), ensure_ascii=False))
page.append('{"releases":[],"repos":[]}')
def with_size(b):
    # Slice 104h (R-AP80): the W2 bodies of 109 have no `size` yet (slice 109b). Insert it after `sha256`, size = 1000000 + log_index, so the fixture is the R-RE4 form.
    j = json.loads(b)
    rows = []
    for r in j["toolchains"]:
        n = {}
        for k, v in r.items():
            n[k] = v
            if k == "sha256": n["size"] = 1000000 + r["log_index"]
        rows.append(n)
    j["toolchains"] = rows
    return json.dumps(j, separators=(",", ":"), ensure_ascii=False)
tc_page = [with_size(b) for b in bodies("toolchains/get-query", 3)]
tc_put = [with_size(b) for b in bodies("toolchains/pu-new-tag", 1) + bodies("oidc/tp3-jwt-strict", 1)]
matches = bodies("shorts/sn1-table", 3) + bodies("shorts/ap33-moved", 6)
packages = bodies("shorts/sn5-search", 2)
block("releases_bodies", "Index.Releases: reads/ap1-body-etag-cache (slice 106) and reads/ap13-group-series-after.", releases)
block("detail_bodies", "Index.Detail: reads/ap2-artifact.", detail)
block("page_bodies", "Index.Page: the `releases` and `repos` of the ap2 bodies (the W2 cases of R-AP14 compare JSON, not bytes), and the empty page.", page)
block("toolchain_page_bodies", "Toolchain.Page: toolchains/get-query (slice 109) with `size` added after `sha256` (slice 104h).", tc_page)
block("toolchain_put_bodies", "Toolchain.Put: toolchains/pu-new-tag and oidc/tp3-jwt-strict (slice 109) with `size` added (slice 104h).", tc_put)
block("matches_bodies", "Short.Matches: shorts/sn1-table and shorts/ap33-moved (slice 107).", matches)
block("packages_bodies", "Short.Packages: shorts/sn5-search (slice 107).", packages)
