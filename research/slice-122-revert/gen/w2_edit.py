#!/usr/bin/env python3
# Slice 122: adds `provenance` to the W2 cases that show a release (test agent, TW21: each changed file is read after).
# - seeds: the rows of `provenance` for the releases (reads, closure). The ingest and publish cases have rows already.
# - expect/responses.jsonl: `provenance` in each release, the body and the ETag of the exact-body answers (reads),
#   and the same ETag in requests.jsonl (If-None-Match) and in the other expected lines.
# The values are written here from the design (R-AP49: strongest first; R-PU15; R-PU16), not read from the code.
# Usage: w2_edit.py <worker/tests/cases dir> [--check]   (the second form only prints what it would do)
import json, re, sys, hashlib, os
CASES = sys.argv[1]
CHECK = '--check' in sys.argv
OIDC, WEBHOOK, POLL, INGEST = 0, 1, 2, 3
NAMES = {0: "oidc", 1: "webhook", 2: "poll", 3: "ingest"}
def names(codes): return [NAMES[c] for c in sorted(codes)]  # the code order is the strength order

# the six releases of the reads fixture and the release 7 of ap43-cache-refresh: the rows in the order they are inserted
READS = {1: [3], 2: [3, 0], 3: [1], 4: [3, 1, 2], 5: [3, 2, 1, 0], 6: [2], 7: [0]}
# the closure fixture (the same rows as sql/tests/cases/closure/c2-closure-cte/setup.sql)
CLOSURE = {1: [3, 1], 2: [3], 3: [0], 4: [3], 5: [3, 2], 6: [3, 2, 1, 0], 7: [1], 8: [3]}
def pages(i): return [3, 0] if i % 2 == 0 else [3]   # ap14-pages: 1002 releases

def seed_block(table, upto=None):
    rows = [(r, v) for r, vs in table.items() if r != 7 or upto == 7 for v in vs]
    return ("-- Slice 122, R-AP49 `provenance`, R-RE9: the rows of the releases, inserted out of the order of strength.\n"
            "INSERT INTO provenance (release, via, claims, time) VALUES " + ", ".join("(%d, %d, NULL, %d)" % (r, v, 1767139200000 + v) for r, v in rows) + ";\n")
PAGES_SEED = ("-- Slice 122, R-AP49 `provenance`, R-RE9: every release has an ingest row, the even ones also an oidc row (inserted after it).\n"
              "INSERT INTO provenance (release, via, claims, time) SELECT log_index, 3, NULL, 0 FROM releases;\n"
              "INSERT INTO provenance (release, via, claims, time) SELECT log_index, 0, NULL, 0 FROM releases WHERE log_index % 2 = 0;\n")

def is_release(o): return isinstance(o, dict) and 'log_index' in o and 'group' in o and 'series' in o and 'hash' in o
def add_json(o, prov_of):
    n = 0
    if isinstance(o, dict):
        out = {}
        for k, v in o.items():
            v2, m = add_json(v, prov_of); n += m
            out[k] = v2
            if k == 'log_index' and is_release(o) and 'provenance' not in o:
                out['provenance'] = prov_of(v); n += 1
        return out, n
    if isinstance(o, list):
        res = [add_json(x, prov_of) for x in o]
        return [r[0] for r in res], n + sum(r[1] for r in res)
    return o, n
def add_body(body, prov_of):
    n = 0
    def sub(m):
        nonlocal n; n += 1
        return '"log_index":%s,"provenance":%s,"published_at"' % (m.group(1), json.dumps(prov_of(int(m.group(1))), separators=(',', ':')))
    return re.sub(r'"log_index":(\d+),"published_at"', sub, body), n
def etag_of(body): return hashlib.sha256(body.encode()).hexdigest()[:32]

def edit_case(area, case, prov_of, seed_add=None):
    d = os.path.join(CASES, area, case)
    sep = None
    f = os.path.join(d, 'expect', 'responses.jsonl')
    text = open(f).read()
    sep = (', ', ': ') if text.startswith('{"status": ') else (',', ':')
    out, etags, total = [], {}, 0
    for line in text.split('\n'):
        if not line.strip(): out.append(line); continue
        o = json.loads(line)
        if json.dumps(o, separators=sep, ensure_ascii=False) != line: sys.exit("no roundtrip: " + f)
        if 'json' in o:
            o['json'], n = add_json(o['json'], prov_of); total += n
        if isinstance(o.get('body'), str) and '"log_index"' in o['body']:
            old = o['body']; o['body'], n = add_body(old, prov_of); total += n
            if n: etags[etag_of(old)] = etag_of(o['body'])
        out.append(json.dumps(o, separators=sep, ensure_ascii=False))
    new = '\n'.join(out)
    for a, b in etags.items(): new = new.replace(a, b)
    reqs = os.path.join(d, 'requests.jsonl')
    rtext = open(reqs).read()
    for a, b in etags.items(): rtext = rtext.replace(a, b)
    print("%-45s releases %4d, etags %d%s" % (area + '/' + case, total, len(etags), ", seed +rows" if seed_add else ""))
    if CHECK: return
    open(f, 'w').write(new)
    open(reqs, 'w').write(rtext)
    if seed_add:
        sp = os.path.join(d, 'seed.sql'); s = open(sp).read()
        if 'INTO provenance' in s: sys.exit("seed has provenance rows already: " + sp)
        open(sp, 'w').write(s.rstrip('\n') + '\n' + seed_add)

def table(t): return lambda i: names(t[i])
for c in ['ap1-body-etag-cache', 'ap13-group-series-after', 'ap2-artifact', 'ap24-conditional-first', 'ap43-not-found-uncached', 'ap56-case-fold', 'bookmark-session']:
    edit_case('reads', c, table(READS), seed_block(READS))
edit_case('reads', 'ap43-cache-refresh', table(READS), seed_block(READS))
edit_case('reads', 'ap29-checked-stale', table(READS), seed_block(READS))
edit_case('reads', 'ap14-pages', lambda i: names(pages(i)), PAGES_SEED)
edit_case('closure', 'ap17-answer', table(CLOSURE), seed_block(CLOSURE, upto=7))

# ingest and publish: the lists by hand (the seeds have their rows; the new releases come in by the path of the case)
def fixed(**by_index): return lambda i: by_index['r%d' % i]
edit_case('ingest', 'pu14-pu19-labels', fixed(r1=["webhook", "ingest"], r2=["ingest"], r5=["ingest"]))
edit_case('ingest', 'pu4-index-kinds', fixed(r1=["ingest"], r2=["ingest"], r3=["ingest"]))
edit_case('ingest-limits', 'ap69-cache-drop', fixed(r1=["webhook"], r2=["ingest"]))
edit_case('ingest-limits', 'pu34-ip', lambda i: ["ingest"])
edit_case('ingest-limits', 'pu34-owner', lambda i: ["ingest"])
edit_case('publish', 'pu1-publish-package', lambda i: ["oidc"])
edit_case('publish', 'tp9-claim-ids', lambda i: ["oidc"])
edit_case('publish', 'pu16-after-ingest', fixed(r1=["oidc", "ingest"]))
