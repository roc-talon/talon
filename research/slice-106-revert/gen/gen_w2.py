# Writes worker/tests/cases/reads/*: the seed, the requests and the expected answers. Every expected value is made with python (fixtures.py), not with Roc code.
import os, shutil, json, sys
from fixtures import *
here=os.path.dirname(os.path.abspath(__file__))
root=os.path.normpath(os.path.join(here,'..','..','..'))
cases=os.path.join(root,'worker/tests/cases/reads')
NOW=1767225600000
def sqlq(s): return "'"+s.replace("'","''")+"'"
def blob(b): return "X'"+b.hex()+"'"
def vkey(v):
    M,m,p=map(int,v.split('.')); return stored(key(M,m,p))
def series_of(v):
    M,m,p=v.split('.'); return M if int(M)>=1 else f'0.{m}'
# ---- the world ----
HASHES={'h1':H1,'h2':H2,'h3':H3,'h4':H4,'h5':H5}
# (log_index, form, version, artifact, repo name or None, tag, roc_version, published_at, withdrawn)
REL=[
 (1,G1,'0.25.1',H3,R1,'0.25.1',None,1700000000000,None),
 (2,G1,'4.2.0',H1,R1,'4.2.0','0.1.0',1700000100000,None),
 (3,G1B,'4.1.0',H2,R1,'v4.1.0',None,1700000200000,None),
 (4,G1,'4.3.0',H2,R1,'4.3.0',None,1700000300000,'edited'),
 (5,GX,'1.0.0',H5,None,None,None,1700000400000,None),
 (6,G2,'2.0.0',H4,R2,'2.0.0',None,1700000500000,None),
]
REPOS={R1:dict(state=0,successor=None,state_at=1699999000000,checked_at=NOW-3600000,app=0),
       R2:dict(state=2,successor=R3,state_at=1699999500000,checked_at=None,app=0)}
STATE={0:'active',1:'missing',2:'moved'}
def wire(r):
    log,form,ver,h,repo,tag,rocv,pub,wd=r
    return dict(log_index=log,hash=b58(h),group=form,series=series_of(ver),version=ver,url=url(form,ver,h),tag=tag,roc_version=rocv,repo=repo,published_at=pub,yanked=False,yank_reason=None,withdrawn=wd)
def repo_item(name):
    r=REPOS[name]; return js(dict(name=name,state=STATE[r['state']],successor=r['successor'],state_at=r['state_at']))
def checked_item(name,now=NOW):
    r=REPOS[name]; at=r['checked_at']
    stale = at is None or (now>at and now-at>2*(86400000 if r['app'] else 3600000))
    return js(dict(name=name,checked_at=at,stale=stale))
def rels(rows): return ','.join(js(wire(r)) for r in rows)
def repos_of(rows): return ','.join(repo_item(n) for n in sorted({r[4] for r in rows if r[4]},key=lambda s:s.encode()))
def body_group(rows,checked):
    names={r[4] for r in rows if r[4]}
    c='null' if not names or checked is False else checked_item(sorted(names)[0])
    return '{"releases":[%s],"checked":%s,"repos":[%s]}'%(rels(rows),c,repos_of(rows))
def body_page(rows): return '{"releases":[%s],"repos":[%s]}'%(rels(rows),repos_of(rows))
DEPS={ # artifact -> [(alias, dep hash, form, version)]
 H1:[('b',H2,G1B,'4.1.0'),('a',H3,G1,'0.25.1')],
}
TARGETS={H4:[(9,'x64linux'),(34,'wasm32')]}
ART={ # hash -> (kind code, exposes, platform, roc_pin, size)
 H1:(1,['Unicode','Utf'],None,None,12345),H2:(1,['Two'],None,None,222),H3:(1,['Three'],None,None,333),
 H4:(2,[],None,'nightly-2026-10-31-f7bef6b',99),H5:(0,[],H4,None,7)}
KIND={0:'app',1:'package',2:'platform'}
def art_wire(h):
    k,ex,pl,pin,size=ART[h]
    deps=[dict(alias=a,hash=b58(dh),group=f,series=series_of(v),version=v,url=url(f,v,dh)) for a,dh,f,v in sorted(DEPS.get(h,[]),key=lambda d:d[0])]
    return dict(hash=b58(h),kind=KIND[k],exposed=ex,platform_hash=None if pl is None else b58(pl),roc_pin=pin,size=size,deps=deps,target_names=sorted(n for _,n in TARGETS.get(h,[])))
def body_art(h):
    rows=[r for r in REL if r[3]==h]
    return '{"artifact":%s,"releases":[%s],"repos":[%s]}'%(js(art_wire(h)),rels(rows),repos_of(rows))
def seed_world():
    s=[]
    names=[(nid(1,h),1,blob(h)) for h in (H1,H2,H3,H4,H5)]+[(nid(2,f.encode()),2,sqlq(f)) for f in (G1,G1B,GX,G2)]+[(nid(3,r.encode()),3,sqlq(r)) for r in (R1,R2,R3)]
    s.append('INSERT INTO names (id, kind, value) VALUES\n'+',\n'.join(f'  ({i}, {k}, {v})' for i,k,v in names)+';')
    for h,(k,ex,pl,pin,size) in ART.items():
        s.append('INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (%d, %d, %s, %s, %s, %d);'%(nid(1,h),k,sqlq(json.dumps(ex,separators=(',',':'))),'NULL' if pl is None else nid(1,pl),'NULL' if pin is None else sqlq(pin),size))
    for h,ds in DEPS.items():
        for a,dh,f,v in ds:
            s.append('INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (%d, %s, %d, %d, %d, %s, %s);'%(nid(1,h),sqlq(a),nid(1,dh),nid(2,f.encode()),vkey(v),sqlq(''),sqlq(url(f,v,dh))))
    for h,ts in TARGETS.items():
        for c,_ in ts: s.append('INSERT INTO artifact_targets (artifact, target) VALUES (%d, %d);'%(nid(1,h),c))
    for log,form,ver,h,repo,tag,rocv,pub,wd in REL:
        s.append('INSERT INTO log (idx, grp, version, hash, time) VALUES (%d, %s, %s, %s, %d);'%(log,sqlq(form),sqlq(ver),sqlq(b58(h)),NOW-86400000))
        s.append('INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (%d, %d, %d, %s, %d, %s, %s, %s, %s, %d, 0, %s, %s);'%(
            log,nid(2,form.encode()),vkey(ver),sqlq(''),nid(1,h),'NULL' if repo is None else nid(3,repo.encode()),sqlq(url(form,ver,h)),'NULL' if tag is None else sqlq(tag),'NULL' if rocv is None else sqlq(rocv),pub,'NULL' if wd is None else sqlq(wd),'NULL' if wd is None else NOW-1000))
    for name,r in REPOS.items():
        s.append('INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (%d, %d, %d, %d, %s, %d, %d);'%(nid(3,name.encode()),1000+len(name),2000,r['state'],'NULL' if r['successor'] is None else nid(3,r['successor'].encode()),r['state_at'],r['state_at']))
        s.append('INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (%d, NULL, %s, %d, 0, %d);'%(nid(3,name.encode()),'NULL' if r['checked_at'] is None else r['checked_at'],NOW+3600000,r['app']))
    return '\n'.join(s)+'\n'
# ---- request helpers ----
def GET(path,headers=None):
    d={'method':'GET','path':path}
    if headers: d['headers']=headers
    return d
def ok(body,headers=None,d1=1):
    h={'content-type':'application/json','cache-control':'max-age=60','etag':etag(body.encode())}
    if headers: h.update(headers)
    return {'status':200,'headers':h,'body':body},d1
def notmod(body,d1=0):
    return {'status':304,'headers':{'etag':etag(body.encode()),'cache-control':'max-age=60'},'body':''},d1
def problem(status,typ,detail,d1,headers=None):
    e={'status':status,'problem':{'type':typ,'detail':detail}}
    if headers: e['headers']=headers
    return e,d1
def q(s): 
    from urllib.parse import quote
    return quote(s,safe='')
def write(name,rules,reqs,seed=None,extra=None):
    d=os.path.join(cases,name)
    shutil.rmtree(d,ignore_errors=True); os.makedirs(os.path.join(d,'expect'))
    open(os.path.join(d,'rules'),'w').write('\n'.join(rules)+'\n')
    if seed is not None: open(os.path.join(d,'seed.sql'),'w').write(seed)
    with open(os.path.join(d,'requests.jsonl'),'w') as rq, open(os.path.join(d,'expect/responses.jsonl'),'w') as rp, open(os.path.join(d,'expect/d1-calls'),'w') as dc:
        for r in reqs:
            if isinstance(r,dict):   # a request that is not answered: {"sql": [...]}
                rq.write(json.dumps(r)+'\n'); continue
            req,(exp,n)=r
            rq.write(json.dumps(req)+'\n'); rp.write(json.dumps(exp)+'\n'); dc.write(f'{n}\n')
    if extra:
        for k,v in extra.items(): open(os.path.join(d,k),'w').write(v)
def main():
    shutil.rmtree(cases,ignore_errors=True); os.makedirs(cases)
    W=seed_world()
    R1_ROWS=[r for r in REL if r[4]==R1]
    P1='/v1/packages/roc-lang/unicode/releases'
    b1=body_group(R1_ROWS,True); E1=etag(b1.encode())
    nc={'cache-control':'no-cache'}
    # A
    write('ap1-body-etag-cache',['R-AP1','R-RE2','R-AP18','R-AP29','R-AP32','R-AP49','R-AP50','R-AP51','R-AP23','R-AP24','R-AP41','R-AP43','R-AP53','R-AP54','R-AP55'],[
        (GET(P1),ok(b1,d1=1)),
        (GET(P1),ok(b1,d1=0)),
        (GET(P1,{'if-none-match':E1}),notmod(b1)),
        (GET(P1,{'if-none-match':'"nope"'}),ok(b1,d1=0)),
        (GET(P1,nc),ok(b1,d1=1)),
        (GET(P1,{'pragma':'no-cache'}),ok(b1,d1=1)),
        (GET(P1,{'cache-control':'No-Cache, max-age=0','if-none-match':E1}),notmod(b1,d1=1)),
        (GET(P1,{'cache-control':'max-age=0'}),ok(b1,d1=0)),
        (GET(P1,{'cache-control':'no-store, private'}),ok(b1,d1=0)),
        (GET(P1),ok(b1,d1=0)),
    ],W)
    # B
    write('ap24-conditional-first',['R-AP24','R-AP54','R-AP55','R-AP43','R-AP1','R-AP41'],[
        (GET(P1,{'if-none-match':'W/'+E1}),notmod(b1,d1=1)),
        (GET(P1),ok(b1,d1=0)),
    ],W)
    # case fold (R-AP56)
    write('ap56-case-fold',['R-AP56','R-AP1','R-AP13','R-AP41','R-AP43','R-AP21'],[
        (GET('/v1/packages/Roc-Lang/Unicode/releases'),ok(b1,d1=1)),
        (GET('/v1/packages/Roc-Lang/Unicode/releases'),ok(b1,d1=0)),
        (GET('/v1/packages/ROC-LANG/unicode/releases'),ok(b1,d1=1)),
        (GET('/v1/packages/Roc-Lang/Nope/releases'),problem(404,'/errors/not-found','no indexed release for Roc-Lang/Nope',1)),
        (GET('/v1/releases?group='+q(G1.upper())),ok(body_group([],True),d1=1)),
        (GET('/v1/releases?group='+q('GitHub.com/roc-lang/unicode/releases/download/{v}/')),ok(body_group([],True),d1=1)),
    ],W)
    # C
    nf=lambda o,r:problem(404,'/errors/not-found',f'no indexed release for {o}/{r}',1)
    write('ap43-not-found-uncached',['R-AP1','R-AP43','R-AP21','R-AP41'],[
        (GET('/v1/packages/roc-lang/nope/releases'),nf('roc-lang','nope')),
        (GET('/v1/packages/roc-lang/nope/releases'),nf('roc-lang','nope')),
        (GET('/v1/packages/nobody/unicode/releases'),nf('nobody','unicode')),
        (GET(P1),ok(b1,d1=1)),
    ],W)
    # D
    gq=lambda g,extra='':f'/v1/releases?group={q(g)}{extra}'
    G1_ROWS=[r for r in REL if r[1]==G1]
    write('ap13-group-series-after',['R-AP13','R-AP14','R-AP29','R-AP32','R-AP41','R-AP44','R-AP53','R-IK5','R-RE2'],[
        (GET(gq(G1)),ok(body_group(G1_ROWS,True))),
        (GET(gq(G1,'&series=4')),ok(body_group([r for r in G1_ROWS if series_of(r[2])=='4'],True))),
        (GET(gq(G1,'&series=0.25')),ok(body_group([r for r in G1_ROWS if series_of(r[2])=='0.25'],True))),
        (GET(gq(G1,'&series=7')),ok(body_group([],True))),
        (GET(gq(G1B)),ok(body_group([r for r in REL if r[1]==G1B],True))),
        (GET(gq(GX)),ok(body_group([r for r in REL if r[1]==GX],True))),
        (GET(gq(G2)),ok(body_group([r for r in REL if r[1]==G2],True))),
        (GET(gq('example.com/none/{v}/')),ok(body_group([],True))),
        (GET(gq(G1,'&after=1')),ok(body_group([r for r in G1_ROWS if r[0]>1],True))),
        (GET(gq(G1,'&unknown=1')),ok(body_group(G1_ROWS,True))),
        (GET(gq(G1,'&series=4&after=2')),ok(body_group([r for r in G1_ROWS if r[0]>2 and series_of(r[2])=='4'],True))),
    ],W)
    # E
    bad=lambda d:problem(400,'/errors/bad-request',d,0)
    need='GET /v1/releases needs the query parameter group or after'
    write('ap13-bad-requests',['R-AP13','R-AP14','R-AP21','R-AP48','R-AP41','R-AP44','R-AP56'],[
        (GET('/v1/releases'),bad(need)),
        (GET('/v1/releases?series=4'),bad(need)),
        (GET('/v1/releases?unknown=1'),bad(need)),
        (GET('/v1/releases?group='),bad('the query parameter group must not be empty')),
        (GET(gq(G1,'&after=x')),bad('the query parameter after must be a log index (decimal digits), got x')),
        (GET('/v1/releases?after=-1'),bad('the query parameter after must be a log index (decimal digits), got -1')),
        (GET(gq(G1,'&series=0')),bad('the query parameter series must be a series (M or 0.m), got 0')),
        (GET(gq(G1,'&after=007')),bad('the query parameter after must be a log index (decimal digits), got 007')),
        (GET(gq(G1,'&after=9223372036854775808')),bad('the query parameter after must be a log index (decimal digits), got 9223372036854775808')),
        (GET(gq(G1,'&series=1.2')),bad('the query parameter series must be a series (M or 0.m), got 1.2')),
    ],W)
    # AP14 page
    writeAP14()
    # G
    nfa=lambda h:problem(404,'/errors/not-found',f'no artifact {h}',1)
    unknown=b58(bytes([42]*32))
    nothash=lambda t:problem(404,'/errors/not-found',f'no artifact {t}',0)
    write('ap2-artifact',['R-AP2','R-AP32','R-AP49','R-RE1','R-RE19','R-RE20','R-AP41','R-AP24','R-AP43','R-AP21','R-AP53','R-AP54','R-AP56'],[
        (GET('/v1/artifacts/'+b58(H1)),ok(body_art(H1))),
        (GET('/v1/artifacts/'+b58(H2)),ok(body_art(H2))),
        (GET('/v1/artifacts/'+b58(H4)),ok(body_art(H4))),
        (GET('/v1/artifacts/'+b58(H5)),ok(body_art(H5))),
        (GET('/v1/artifacts/'+b58(H1),{'if-none-match':etag(body_art(H1).encode())}),notmod(body_art(H1))),
        (GET('/v1/artifacts/'+unknown),nfa(unknown)),
        (GET('/v1/artifacts/'+unknown),nfa(unknown)),
        (GET('/v1/artifacts/not-a-hash'),nothash('not-a-hash')),
        (GET('/v1/artifacts/0OIl'),nothash('0OIl')),
        (GET('/v1/artifacts/'+b58(bytes(range(31)))),nothash(b58(bytes(range(31))))),
        (GET('/v1/artifacts/'+b58(bytes(range(33)))),nothash(b58(bytes(range(33))))),
    ],W)
    # J
    na=lambda m,p:problem(405,'/errors/method-not-allowed',f'{m} is not allowed on {p}',0,{'allow':'GET'})
    write('ap48-method-not-allowed',['R-AP48','R-AP21','R-AP1','R-AP2','R-AP13','R-AP14','R-AP41'],[
        ({'method':'POST','path':'/v1/releases','json':{}},na('POST','/v1/releases')),
        ({'method':'PUT','path':'/v1/artifacts/'+b58(H1)},na('PUT','/v1/artifacts/'+b58(H1))),
        ({'method':'DELETE','path':P1},na('DELETE',P1)),
        ({'method':'PATCH','path':'/v1/releases'},na('PATCH','/v1/releases')),
        (GET('/v1/packages/roc-lang/unicode'),problem(404,'/errors/not-found','no route for GET /v1/packages/roc-lang/unicode',0)),
        (GET('/v1/artifacts'),problem(404,'/errors/not-found','no route for GET /v1/artifacts',0)),
    ])
    # H (needs RR1)
    new='roc-lang/new'
    newrow=(7,'github.com/roc-lang/new/releases/download/{v}/','1.0.0',H5,new,'1.0.0',None,1700000600000,None)
    REPOS[new]=dict(state=0,successor=None,state_at=1699999000000,checked_at=NOW-1000,app=0)
    ins=[ 'INSERT INTO names (id, kind, value) VALUES (%d, 3, %s)'%(nid(3,new.encode()),sqlq(new)),
          'INSERT INTO names (id, kind, value) VALUES (%d, 2, %s)'%(nid(2,newrow[1].encode()),sqlq(newrow[1])),
          'INSERT INTO log (idx, grp, version, hash, time) VALUES (7, %s, %s, %s, %d)'%(sqlq(newrow[1]),sqlq('1.0.0'),sqlq(b58(H5)),NOW),
          'INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (7, %d, %d, %s, %d, %d, %s, %s, NULL, %d, 0, NULL, NULL)'%(nid(2,newrow[1].encode()),vkey('1.0.0'),sqlq(''),nid(1,H5),nid(3,new.encode()),sqlq(url(newrow[1],'1.0.0',H5)),sqlq('1.0.0'),newrow[7]),
          'INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (%d, 5000, 2000, 0, NULL, 1699999000000, 1699999000000)'%nid(3,new.encode()),
          'INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (%d, NULL, %d, %d, 0, 0)'%(nid(3,new.encode()),NOW-1000,NOW+3600000)]
    PN='/v1/packages/roc-lang/new/releases'
    bn=body_group([newrow],True)
    # the changed state of R1: release 2 is withdrawn
    rows_after=[(r[:8]+('deleted',) if r[0]==2 else r) for r in R1_ROWS]
    b1b=body_group(rows_after,True)
    upd="UPDATE releases SET withdrawn = 'deleted', withdrawn_at = %d WHERE log_index = 2"%NOW
    write('ap43-cache-refresh',['R-AP43','R-AP1','R-AP41','R-AP24'],[
        (GET(PN),nf('roc-lang','new')),
        {'sql':ins},
        (GET(PN),ok(bn,d1=1)),
        (GET(P1),ok(b1,d1=1)),
        {'sql':[upd]},
        (GET(P1),ok(b1,d1=0)),
        (GET(P1,nc),ok(b1b,d1=1)),
        (GET(P1),ok(b1b,d1=0)),
    ],W)
    # I (needs RR2)
    bm='bookmark-abc-123'
    write('bookmark-session',['R-AP41','R-AP43'],[
        (GET(P1),ok(b1,headers={'x-d1-session':'first-unconstrained'})),
        (GET(P1,{'cache-control':'no-cache','talon-bookmark':bm}),ok(b1,headers={'x-d1-session':bm})),
        (GET(P1,{'cache-control':'no-cache','talon-bookmark':'  '+bm+'  '}),ok(b1,headers={'x-d1-session':bm})),
        (GET(P1,{'cache-control':'no-cache','talon-bookmark':''}),ok(b1,headers={'x-d1-session':'first-unconstrained'})),
        (GET('/v1/artifacts/'+b58(H1),{'cache-control':'no-cache','talon-bookmark':bm}),ok(body_art(H1),headers={'x-d1-session':bm})),
        (GET(gq(G1),{'cache-control':'no-cache','talon-bookmark':bm}),ok(body_group(G1_ROWS,True),headers={'x-d1-session':bm})),
    ],W)
    # checked
    writeChecked()
def writeAP14():
    n=1002; form='example.com/page/{v}/'; h=H1
    fid=nid(2,form.encode()); aid=nid(1,h)
    s=[ "INSERT INTO names (id, kind, value) VALUES (%d, 1, %s), (%d, 2, %s);"%(aid,blob(h),fid,sqlq(form)),
        "WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < %d) INSERT INTO log (idx, grp, version, hash, time) SELECT i, %s, '1.0.' || i, %s, 0 FROM n;"%(n,sqlq(form),sqlq(b58(h))),
        "WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < %d) INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) SELECT i, %d, ((1 << 48) | (i << 16) | 65535) + (-9223372036854775807 - 1), '', %d, NULL, 'https://example.com/page/' || i || '/x.tar.zst', NULL, NULL, 1700000000000 + i * 1000, 0, NULL, NULL FROM n;"%(n,fid,aid)]
    seed='\n'.join(s)+'\n'
    def items(lo,hi): return {'releases':[{'log_index':i,'version':f'1.0.{i}','group':form,'series':'1','hash':b58(h),'repo':None,'published_at':1700000000000+i*1000} for i in range(lo,hi+1)],'repos':[]}
    def jr(lo,hi,**kw):
        e={'status':200,'headers':{'content-type':'application/json','cache-control':'max-age=60'},'json':items(lo,hi)}
        return e,1
    g=f'/v1/releases?group={q(form)}'
    reqs=[(GET('/v1/releases?after=0'),jr(1,1000)),
          (GET('/v1/releases?after=1000'),jr(1001,1002)),
          (GET('/v1/releases?after=1002'),jr(1003,1002)),
          (GET('/v1/releases?after=999'),jr(1000,1002)),
          (GET(g+'&after=998'),jr(999,1002)),
          (GET(g+'&series=1&after=0'),jr(1,1000)),
          (GET('/v1/releases?after=9223372036854775807'),jr(1,0)),
          (GET('/v1/releases?series=zzz&after=1000'),jr(1001,1002))]
    # the group answers have "checked": null
    reqs[4][1][0]['json']['checked']=None
    reqs[5][1][0]['json']['checked']=None
    write('ap14-pages',['R-AP14','R-AP13','R-AP41','R-AP49','R-AP53','R-AP56','R-IK5'],reqs,seed)
def writeChecked():
    # R-AP29: stale when never read or older than 2 intervals (1 h, or 24 h with the App). Four repos.
    reps={}
    seed=[]
    def add(name,form,log,at,app):
        h=bytes([log+50]*32)
        seed.append('INSERT INTO names (id, kind, value) VALUES (%d, 1, %s), (%d, 2, %s), (%d, 3, %s);'%(nid(1,h),blob(h),nid(2,form.encode()),sqlq(form),nid(3,name.encode()),sqlq(name)))
        seed.append('INSERT INTO log (idx, grp, version, hash, time) VALUES (%d, %s, %s, %s, 0);'%(log,sqlq(form),sqlq('1.0.0'),sqlq(b58(h))))
        seed.append("INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (%d, %d, %d, '', %d, %d, %s, NULL, NULL, 1700000000000, 0, NULL, NULL);"%(log,nid(2,form.encode()),vkey('1.0.0'),nid(1,h),nid(3,name.encode()),sqlq(url(form,'1.0.0',h))))
        seed.append('INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (%d, %d, 1, 0, NULL, 1699999000000, 1699999000000);'%(nid(3,name.encode()),3000+log))
        seed.append('INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (%d, NULL, %s, %d, 0, %d);'%(nid(3,name.encode()),'NULL' if at is None else at,NOW,app))
        return form
    H=3600000
    specs=[('o/fresh',1,NOW-H,0,False),('o/never',2,None,0,True),('o/two-hours',3,NOW-2*H,0,False),('o/over-two',4,NOW-2*H-1,0,True),('o/app-day',5,NOW-3*H,1,False),('o/app-old',6,NOW-48*H-1,1,True)]
    reqs=[]
    for name,log,at,app,stale in specs:
        form=f'github.com/{name}/releases/download/{{v}}/'
        add(name,form,log,at,app)
        REPOS[name]=dict(state=0,successor=None,state_at=1699999000000,checked_at=at,app=app)
        reqs.append((GET(f'/v1/releases?group={q(form)}'),(
            {'status':200,'json':{'checked':{'name':name,'checked_at':at,'stale':stale}}},1)))
    write('ap29-checked-stale',['R-AP29','R-AP13','R-AP1','R-PU22','R-AP41'],reqs,'\n'.join(seed)+'\n')
main()
print('ok')
