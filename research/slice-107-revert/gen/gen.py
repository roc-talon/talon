# Writes worker/tests/cases/shorts/*: seed, requests and expected answers. Every expected value is made with python, not with Roc code.
import os, shutil, json, hashlib
from urllib.parse import quote
from fixtures import b58, nid, stored, key, etag, js
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.normpath(os.path.join(here, '..', '..', '..'))
cases = os.path.join(root, 'worker/tests/cases/shorts')
NOW = 1767225600000
STATE = {0: 'active', 1: 'missing', 2: 'moved'}
def sqlq(s): return "'" + s.replace("'", "''") + "'"
def blob(b): return "X'" + b.hex() + "'"
def vkey(v):
    M, m, p = map(int, v.split('.')); return stored(key(M, m, p))
def hash_of(tag): return hashlib.sha256(tag.encode()).digest()
def gh(name): return 'github.com/%s/releases/download/{v}/' % name
def url(form, ver, h): return 'https://' + form.replace('{v}', ver) + b58(h) + '.tar.zst'

class World:
    """packages: name -> dict(state, successor, releases=[(log, group, repo or None, yanked, withdrawn)])"""
    def __init__(self): self.pk = {}; self.extra = []
    def add(self, name, state=0, successor=None, rels=()):
        self.pk[name] = dict(state=state, successor=successor, rels=list(rels))
    def rel(self, log, name, yanked=0, withdrawn=None, group=None):
        return (log, group or gh(name), name, yanked, withdrawn)
    def stmts(self, only=None):
        s = []
        names = {}
        for name, p in self.pk.items():
            if only and name not in only: continue
            names[(3, name.encode())] = sqlq(name)
            if p['successor']: names[(3, p['successor'].encode())] = sqlq(p['successor'])
            for (log, group, repo, y, w) in p['rels']:
                h = hash_of('%s/%d' % (name, log))
                names[(1, h)] = blob(h); names[(2, group.encode())] = sqlq(group)
                if repo: names[(3, repo.encode())] = sqlq(repo)
        s.append('INSERT OR IGNORE INTO names (id, kind, value) VALUES\n' + ',\n'.join('  (%d, %d, %s)' % (nid(k, d), k, v) for (k, d), v in names.items()) + ';')
        for name, p in self.pk.items():
            if only and name not in only: continue
            for (log, group, repo, y, w) in p['rels']:
                h = hash_of('%s/%d' % (name, log)); ver = '1.%d.0' % log
                s.append('INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (%d, 1, %s, NULL, NULL, 100);' % (nid(1, h), sqlq('["M"]')))
                s.append('INSERT INTO log (idx, grp, version, hash, time) VALUES (%d, %s, %s, %s, %d);' % (log, sqlq(group), sqlq(ver), sqlq(b58(h)), NOW - 86400000))
                s.append('INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (%d, %d, %d, %s, %d, %s, %s, %s, NULL, %d, %d, %s, %s);' % (
                    log, nid(2, group.encode()), vkey(ver), sqlq(''), nid(1, h), 'NULL' if repo is None else nid(3, repo.encode()), sqlq(url(group, ver, h)), sqlq(ver), 1700000000000 + log, y, 'NULL' if w is None else sqlq(w), 'NULL' if w is None else NOW - 1000))
            s.append('INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (%d, %d, %d, %d, %s, %d, %d);' % (
                nid(3, name.encode()), 1000 + len(self.pk) + sum(name.encode()), 2000, p['state'], 'NULL' if p['successor'] is None else nid(3, p['successor'].encode()), 1699999000000, 1699999000000))
        return s
    def seed(self): return '\n'.join(self.stmts()) + '\n'

# ---- the answer ----
def first(w, name):
    ls = [r[0] for r in w.pk[name]['rels'] if r[2] == name]
    return min(ls) if ls else None
def indexed(w, name): return first(w, name) is not None
def key_of(name):
    repo = name.split('/', 1)[1].lower() if '/' in name else None
    if repo is None: return []
    ks = [repo]
    if repo.startswith('roc-') and len(repo) > 4: ks.append(repo[4:])
    return ks
def asc_lower(s): return ''.join(c.lower() if c.isascii() else c for c in s)
def match(w, short):
    return [n for n in w.pk if indexed(w, n) and asc_lower(short) in key_of(n)]
def chain_end(w, n):
    seen = {n}; cur = n; links = 0
    while w.pk[cur]['state'] == 2 and w.pk[cur]['successor'] and w.pk[cur]['successor'] in w.pk and links < 4 and w.pk[cur]['successor'] not in seen:
        cur = w.pk[cur]['successor']; seen.add(cur); links += 1
    return cur
def entry(w, short):
    items = {}
    for n in match(w, short):
        if w.pk[n]['state'] == 2:
            e = chain_end(w, n)
            if e == n:
                it = dict(first_log_index=first(w, n), name=n, state=STATE[2]); old = None
            else:
                f = first(w, n)
                if first(w, e) is not None: f = min(f, first(w, e))
                it = dict(first_log_index=f, name=e, state=STATE[w.pk[e]['state']], moved_from=n); old = n
        else:
            it = dict(first_log_index=first(w, n), name=n, state=STATE[w.pk[n]['state']])
        if it['name'] in items:
            o = items[it['name']]
            o['first_log_index'] = min(o['first_log_index'], it['first_log_index'])
            if 'moved_from' in it: o['moved_from'] = min(o.get('moved_from', it['moved_from']).encode(), it['moved_from'].encode()).decode()
        else: items[it['name']] = it
    return dict(short=short, matches=[items[k] for k in sorted(items, key=lambda s: s.encode())])
def body(w, shorts): return js(dict(matches=[entry(w, s) for s in shorts]))

def GET(path, headers=None):
    d = {'method': 'GET', 'path': path}
    if headers: d['headers'] = headers
    return d
def ok(b, cc='max-age=60', d1=1):
    return {'status': 200, 'headers': {'content-type': 'application/json', 'cache-control': cc, 'etag': etag(b.encode())}, 'body': b}, d1
def notmod(b, cc='max-age=60', d1=0):
    return {'status': 304, 'headers': {'etag': etag(b.encode()), 'cache-control': cc}, 'body': ''}, d1
def q(s): return quote(s, safe='')
def write(name, rules, reqs, seed=None):
    d = os.path.join(cases, name)
    shutil.rmtree(d, ignore_errors=True); os.makedirs(os.path.join(d, 'expect'))
    open(os.path.join(d, 'rules'), 'w').write('\n'.join(rules) + '\n')
    if seed is not None: open(os.path.join(d, 'seed.sql'), 'w').write(seed)
    with open(os.path.join(d, 'requests.jsonl'), 'w') as rq, open(os.path.join(d, 'expect/responses.jsonl'), 'w') as rp, open(os.path.join(d, 'expect/d1-calls'), 'w') as dc:
        for r in reqs:
            if isinstance(r, dict): rq.write(json.dumps(r) + '\n'); continue
            req, (exp, n) = r
            rq.write(json.dumps(req) + '\n'); rp.write(json.dumps(exp) + '\n'); dc.write(f'{n}\n')

def P(short, *more): return '/v1/packages?' + '&'.join('short=' + q(s) for s in (short,) + more)

def main():
    shutil.rmtree(cases, ignore_errors=True); os.makedirs(cases)
    # ---- case 1: the table of R-SN1, the example of R-SN2, R-SN3, R-SN4 ----
    w = World()
    RP = 'lukewilliamboswell/roc-parser'; RJ = 'lukewilliamboswell/roc-json'
    w.add(RP, rels=[w.rel(1, RP), w.rel(2, RP)])
    w.add(RJ, rels=[w.rel(3, RJ)])
    # a group on another host and a gitlab group: no name (R-SN3). Their repo is NULL, so they have no `repos` row.
    other = [(4, 'example.com/parser/{v}/', None, 0, None), (5, 'gitlab.com/x/parser/{v}/', None, 0, None)]
    base = w.seed()
    ext = World(); ext.add('_x'); ext.pk['_x']['rels'] = other
    # statements for the releases of other hosts only (no repos row, no repo name)
    ext_stmts = [s for s in ext.stmts() if not s.startswith('INSERT INTO repos')]
    base += '\n'.join(ext_stmts) + '\n'
    sp = World(); sp.add('someone/parser', rels=[sp.rel(6, 'someone/parser')])
    sp_sql = sp.stmts()
    w2 = World(); w2.pk = dict(w.pk); w2.pk['someone/parser'] = sp.pk['someone/parser']
    b_parser1 = body(w, ['parser'])
    b_roc = body(w, ['roc-parser']); b_pars = body(w, ['pars'])
    b_both = body(w2, ['Parser'])
    w3 = World(); w3.pk = {k: dict(v) for k, v in w2.pk.items()}; w3.pk[RP]['state'] = 1
    b_missing = body(w3, ['parser'])
    multi = ['parser', 'json', 'pars', 'Parser']
    b_multi = body(w3, multi)
    miss_sql = ["UPDATE repos SET state = 1 WHERE repo = %d" % nid(3, RP.encode()),
                "UPDATE releases SET withdrawn = 'repo-missing', withdrawn_at = %d WHERE repo = %d" % (NOW - 500, nid(3, RP.encode()))]
    write('sn1-table', ['R-AP7', 'R-SN1', 'R-SN2', 'R-SN3', 'R-SN4', 'R-AP33', 'R-AP41', 'R-AP43', 'R-AP44', 'R-AP46', 'R-AP53', 'R-AP54'], [
        (GET(P('parser')), ok(b_parser1)),
        (GET(P('parser')), ok(b_parser1, d1=0)),
        (GET(P('roc-parser')), ok(b_roc)),
        (GET(P('pars')), ok(b_pars)),
        {'sql': sp_sql},
        (GET(P('Parser')), ok(b_both)),
        {'sql': miss_sql},
        (GET(P('parser') + '&n=1'), ok(b_missing)),
        (GET(P(*multi)), ok(b_multi)),
        (GET(P(*multi), {'if-none-match': etag(b_multi.encode())}), notmod(b_multi)),
    ], base)
    # ---- case 2: members of the set ----
    w = World()
    w.add('a/roc-yank', rels=[w.rel(5, 'a/roc-yank', yanked=1)])
    w.add('b/wd', rels=[w.rel(6, 'b/wd', withdrawn='edited')])
    w.add('c/ghost')
    w.add('d/roc-roc-x', rels=[w.rel(7, 'd/roc-roc-x')])
    w.add('e/rocx', rels=[w.rel(8, 'e/rocx')])
    w.add('f/multi', rels=[w.rel(9, 'f/multi'), w.rel(3, 'f/multi', group='github.com/f/multi/releases/download/v{v}/')])
    w.add('g/roc-', rels=[w.rel(10, 'g/roc-')])
    big = ['yank', 'wd', 'ghost', 'roc-x', 'roc-roc-x', 'rocx', 'multi', 'a/roc-yank', 'ROC-YANK']
    write('sn2-members', ['R-AP7', 'R-SN1', 'R-SN2', 'R-SN4', 'R-AP46', 'R-AP53', 'R-AP41'], [
        (GET(P(*big)), ok(body(w, big))),
        (GET(P('x')), ok(body(w, ['x']))),
        (GET(P('ROC-ROC-X')), ok(body(w, ['ROC-ROC-X']))),
        (GET(P('roc-')), ok(body(w, ['roc-']))),
        (GET('/v1/packages?short=x&short=rocx&short=%72oc-yank'), ok(body(w, ['x', 'rocx', 'roc-yank']))),
    ], w.seed())
    # ---- case 3: moved names (R-AP33) ----
    w = World()
    w.add('olduser/roc-json', state=2, successor='acme/roc-json', rels=[w.rel(7, 'olduser/roc-json')])
    w.add('acme/roc-json', rels=[w.rel(5, 'acme/roc-json')])
    w.add('a/chain1', state=2, successor='b/mid1', rels=[w.rel(20, 'a/chain1')])
    w.add('b/mid1', state=2, successor='c/mid2', rels=[w.rel(21, 'b/mid1')])
    w.add('c/mid2', state=2, successor='d/final')
    w.add('d/final', rels=[w.rel(10, 'd/final')])
    w.add('x/lone', state=2, successor='n/one', rels=[w.rel(30, 'x/lone')])
    w.add('n/one', state=2, successor='n/two')
    w.add('n/two', state=2, successor='n/three')
    w.add('n/three', state=2, successor='n/four')
    w.add('n/four', rels=[w.rel(11, 'n/four')])
    w.add('q/old-lost', state=2, successor='r/lost', rels=[w.rel(12, 'q/old-lost')])
    w.add('r/lost', state=1, rels=[w.rel(13, 'r/lost', withdrawn='repo-missing')])
    w.add('y/roc-sort', state=2, successor='c/other-end', rels=[w.rel(14, 'y/roc-sort')])
    w.add('m/sort', rels=[w.rel(15, 'm/sort')])
    w.add('c/other-end', rels=[w.rel(16, 'c/other-end')])
    w.add('o/ghostmove', state=2, successor='d/final')
    w.add('p/older', state=2, successor='s/newer', rels=[w.rel(3, 'p/older')])
    w.add('s/newer', rels=[w.rel(50, 's/newer')])
    w.add('t/oldnr', state=2, successor='u/noreln', rels=[w.rel(51, 't/oldnr')])
    w.add('u/noreln')
    w.add('b/roc-two', state=2, successor='e/end', rels=[w.rel(60, 'b/roc-two')])
    w.add('a/two', state=2, successor='e/end', rels=[w.rel(61, 'a/two')])
    w.add('e/end', rels=[w.rel(62, 'e/end')])
    w.add('f0/five', state=2, successor='f1/x', rels=[w.rel(70, 'f0/five')])
    for i in range(1, 5): w.add('f%d/x' % i, state=2, successor='f%d/x' % (i + 1))
    w.add('f5/x', rels=[w.rel(71, 'f5/x')])
    w.add('c/roc-cyc', state=2, successor='d/cyc2', rels=[w.rel(72, 'c/roc-cyc')])
    w.add('d/cyc2', state=2, successor='c/roc-cyc', rels=[w.rel(73, 'd/cyc2')])
    w.add('s/loop', state=2, successor='s/loop', rels=[w.rel(74, 's/loop')])
    seq = ['json', 'chain1', 'lone', 'old-lost', 'sort', 'ghostmove', 'older', 'oldnr', 'two', 'five', 'cyc', 'loop']
    allq = seq
    write('ap33-moved', ['R-AP7', 'R-AP33', 'R-SN1', 'R-SN2', 'R-SN4', 'R-TP11', 'R-TP14', 'R-AP32', 'R-AP41'], [
        (GET(P(s)), ok(body(w, [s]))) for s in seq] + [(GET(P(*allq)), ok(body(w, allq)))], w.seed())
    # ---- case 4: limits and refusals ----
    w = World(); w.add('o/s1', rels=[w.rel(1, 'o/s1')])
    n50 = ['s%d' % i for i in range(1, 51)]
    n51 = n50 + ['s51']
    path = lambda l: '/v1/packages?' + '&'.join('short=' + x for x in l)
    big_body = body(w, n50)
    too = {'status': 413, 'problem': {'type': '/errors/too-large', 'status': 413, 'field': 'short', 'limit': 50}}
    bad = {'status': 400, 'problem': {'type': '/errors/bad-request', 'status': 400}}
    na = lambda m: {'status': 405, 'headers': {'allow': 'GET'}, 'problem': {'type': '/errors/method-not-allowed', 'status': 405}}
    write('ap46-limits', ['R-AP46', 'R-AP7', 'R-AP48', 'R-AP21', 'R-AP43', 'R-SN1'], [
        (GET(path(n50)), ({'status': 200, 'headers': {'content-type': 'application/json', 'cache-control': 'max-age=60', 'etag': etag(big_body.encode())}, 'json_len': {'matches': 50}, 'json_at': {'matches.0.short': 's1', 'matches.49.short': 's50', 'matches.0.matches.0.name': 'o/s1', 'matches.1.matches': []}}, 1)),
        (GET(path(n51)), (too, 0)),
        (GET(path(n51)), (too, 0)),
        (GET(path(n51) + '&short='), (too, 0)),
        (GET('/v1/packages'), (bad, 0)),
        (GET('/v1/packages?foo=1'), (bad, 0)),
        (GET('/v1/packages?short=a&q=b'), (bad, 0)),
        (GET('/v1/packages?short='), (bad, 0)),
        (GET('/v1/packages?q='), (bad, 0)),
        (GET('/v1/packages?q=a&q=b'), (bad, 0)),
        ({'method': 'POST', 'path': '/v1/packages?short=x'}, (na('POST'), 0)),
        ({'method': 'PUT', 'path': '/v1/packages?short=x'}, (na('PUT'), 0)),
        ({'method': 'DELETE', 'path': '/v1/packages'}, (na('DELETE'), 0)),
        (GET('/v1/packages/x?short=x'), ({'status': 404, 'problem': {'type': '/errors/not-found', 'status': 404}}, 0)),
    ], w.seed())
    # ---- case 5: q (R-SN10) ----
    w = World()
    for i in range(1, 26): w.add('own/ranked-%02d' % i, rels=[w.rel(i, 'own/ranked-%02d' % i)])
    w.add('own/other', rels=[w.rel(26, 'own/other')]); w.add('x/yyy', rels=[w.rel(27, 'x/yyy')])
    w.add('z/ranked', rels=[w.rel(28, 'z/ranked')]); w.add('y/xranked', rels=[w.rel(29, 'y/xranked')]); w.add('own/rnkd', rels=[w.rel(30, 'own/rnkd')])
    w.add('m/roc-ranked', state=2, successor='z/ranked', rels=[w.rel(31, 'm/roc-ranked')])
    def rank(t):
        t = asc_lower(t); out = []
        for n in w.pk:
            if not indexed(w, n): continue
            l = asc_lower(n); repo = l.split('/', 1)[1]; sh = repo[4:] if repo.startswith('roc-') and len(repo) > 4 else repo
            r = 1 if t in (l, repo, sh) else 2 if any(x.startswith(t) for x in (l, repo, sh)) else 3 if t in l else 0
            if r: out.append((r, n.encode(), n))
        out.sort()
        return [n for _, _, n in out][:20]
    def qbody(t):
        return js(dict(packages=[dict(first_log_index=first(w, n), name=n, state=STATE[w.pk[n]['state']]) for n in rank(t)]))
    bq = qbody('ranked'); Eq = etag(bq.encode())
    empty = '{"packages":[]}'
    E = etag(empty.encode())
    qh = {'content-type': 'application/json', 'cache-control': 'max-age=300'}
    write('sn5-search', ['R-AP7', 'R-SN5', 'R-SN6', 'R-SN10', 'R-AP41', 'R-AP43', 'R-AP54', 'R-AP48'], [
        (GET('/v1/packages?q=ranked'), ({'status': 200, 'headers': dict(qh, etag=Eq), 'body': bq}, 1)),
        (GET('/v1/packages?q=ranked'), ({'status': 200, 'headers': dict(qh, etag=Eq), 'body': bq}, 0)),
        (GET('/v1/packages?q=RANKED&x=1'), ({'status': 200, 'headers': dict(qh, etag=Eq), 'body': bq}, 1)),
        (GET('/v1/packages?q=roc-ranked'), ({'status': 200, 'headers': dict(qh, etag=etag(qbody('roc-ranked').encode())), 'body': qbody('roc-ranked')}, 1)),
        (GET('/v1/packages?q=zzzq'), ({'status': 200, 'headers': dict(qh, etag=E), 'body': empty}, 1)),
        (GET('/v1/packages?q=zzzq', {'if-none-match': E}), ({'status': 304, 'headers': {'etag': E, 'cache-control': 'max-age=300'}, 'body': ''}, 0)),
        (GET('/v1/packages?q=zzzq', {'if-none-match': E, 'cache-control': 'no-cache'}), ({'status': 304, 'headers': {'etag': E, 'cache-control': 'max-age=300'}, 'body': ''}, 1)),
        (GET('/v1/packages?q=zzzq&unknown=1'), ({'status': 200, 'headers': dict(qh, etag=E), 'body': empty}, 1)),
    ], w.seed())
main()
