# Writes worker/tests/unit/ReadsTest.roc = a generated data section + reads_tests.roc.in (hand written tests).
# Every expected value comes from fixtures.py (python, no Roc code).
from fixtures import *
import os
def rs(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
def lst(b): return '['+', '.join(str(x) for x in b)+']'
def tn(v): return 'Err(None)' if v is None else f'Ok({rs(v)})'
def tm(v): return 'Err(Missing)' if v is None else f'Ok({rs(v)})'
BT=lambda b: 'Bool.True' if b else 'Bool.False'
SAT = stored(0xFFFFFFFFFFFFFFFF)
out=[]
def const(name,typ,val): out.append(f'{name} : {typ}\n{name} = {val}\n')
# releases: (input row dict, expected wire dict)
def rel(log,h,form,stor,vt,tag,rocv,repo,pub,yanked,wd,series,vtxt):
    inp=dict(log_index=log,hash=h,form=form,version=str(stor),version_text=vt,url=url(form,vtxt,h),tag=tag,roc_version=rocv,repo=repo,published_at=pub,yanked=yanked,withdrawn=wd)
    exp=dict(log_index=log,hash=b58(h),group=form,series=series,version=vtxt,url=url(form,vtxt,h),tag=tag,roc_version=rocv,repo=repo,published_at=pub,yanked=yanked,yank_reason=None,withdrawn=wd)
    return inp,exp
REL=[
 rel(2,H1,G1,stored(key(4,2,0)),'','4.2.0','0.1.0',R1,1700000000000,False,None,'4','4.2.0'),
 rel(5,H2,GX,stored(key(0,25,1)),'',None,None,None,1700000100000,True,'edited','0.25','0.25.1'),
 rel(9,H3,G1,SAT,'70000.1.2','70000.1.2',None,R1,1700000200000,False,None,'70000','70000.1.2'),
]
def inexpr(i): return (f'{{ log_index: {i["log_index"]}, hash: {lst(i["hash"])}, form: {rs(i["form"])}, version: {rs(i["version"])}, version_text: {rs(i["version_text"])}, url: {rs(i["url"])}, '
  f'tag: {tm(i["tag"])}, roc_version: {tm(i["roc_version"])}, repo: {tm(i["repo"])}, published_at: {i["published_at"]}, yanked: {BT(i["yanked"])}, withdrawn: {tm(i["withdrawn"])} }}')
def exexpr(e): return (f'{{ log_index: {e["log_index"]}, hash: {rs(e["hash"])}, group: {rs(e["group"])}, series: {rs(e["series"])}, version: {rs(e["version"])}, url: {rs(e["url"])}, '
  f'tag: {tn(e["tag"])}, roc_version: {tn(e["roc_version"])}, repo: {tn(e["repo"])}, published_at: {e["published_at"]}, yanked: {BT(e["yanked"])}, yank_reason: Err(None), withdrawn: {tn(e["withdrawn"])} }}')
for n,h in (('h1',H1),('h2',H2),('h3',H3),('h4',H4),('h5',H5)):
    const(n,'List(U8)',lst(h)); const('b'+n[1],'Str',rs(b58(h)))
for i,(inp,exp) in enumerate(REL,1):
    const(f'rr{i}','Reads.ReleaseRow',inexpr(inp)); const(f'er{i}','Release.Row',exexpr(exp)); const(f'ej{i}','Str',rs(js(exp)))
const('g1','Str',rs(G1)); const('g1b','Str',rs(G1B)); const('gx','Str',rs(GX))
# repos, checked
CH={'name':R1,'checked_at':1700000000000,'stale':False}
RP1={'name':R1,'state':'active','successor':None,'state_at':1699999000000}
RP2={'name':R3,'state':'moved','successor':R1,'state_at':1699999500000}
def chjs(c): return js(c)
def rpjs(r): return js(r)
def rpexpr(r):
    st={'active':'Active','missing':'Missing','moved':'Moved'}[r['state']]
    return f'{{ name: {rs(r["name"])}, state: {st}, successor: {tn(r["successor"])}, state_at: {r["state_at"]} }}'
const('chk1','Reads.CheckedItem',f'{{ name: {rs(R1)}, checked_at: Ok(1700000000000), stale: Bool.False }}')
const('rp1','Reads.RepoItem',rpexpr(RP1)); const('rp2','Reads.RepoItem',rpexpr(RP2))
# artifacts
def dep(alias,h,form,ver):
    return dict(alias=alias,hash=b58(h),group=form,series=('4' if ver=='4.1.0' else '0.25'),version=ver,url=url(form,ver,h))
D_B=dep('b',H2,G1B,'4.1.0'); D_A=dep('a',H3,G1,'0.25.1')
AR1=dict(hash=b58(H1),kind='package',exposed=['Unicode','Utf'],platform_hash=None,roc_pin=None,size=12345,deps=[D_B,D_A],target_names=[])
AR2=dict(hash=b58(H4),kind='platform',exposed=[],platform_hash=None,roc_pin='nightly-2026-10-31-f7bef6b',size=99,deps=[],target_names=['x64linux','wasm32'])
AR3=dict(hash=b58(H5),kind='app',exposed=[],platform_hash=b58(H4),roc_pin=None,size=7,deps=[],target_names=[])
def arexpr(a):
    kind={'package':'Package','platform':'Platform','app':'App'}[a['kind']]
    ds=', '.join(f'{{ alias: {rs(d["alias"])}, hash: {rs(d["hash"])}, group: {rs(d["group"])}, series: {tn(d["series"])}, version: {tn(d["version"])}, url: {rs(d["url"])} }}' for d in a['deps'])
    ts=', '.join(rs(t) for t in a['target_names'])
    return (f'{{ hash: {rs(a["hash"])}, kind: {kind}, exposed: [{", ".join(rs(x) for x in a["exposed"])}], platform_hash: {tn(a["platform_hash"])}, roc_pin: {tn(a["roc_pin"])}, size: {a["size"]}, deps: [{ds}], target_names: [{ts}] }}')
def depin(d,h,form,ver):
    return f'{{ alias: {rs(d["alias"])}, hash: {lst(h)}, form: Ok({rs(form)}), version: Ok({rs(str(stored(key(*map(int,ver.split(".")))) ))}), version_text: Ok(""), url: {rs(d["url"])} }}'
const('art1_rows','{ artifact : Reads.ArtifactRow, deps : List(Reads.DepRow), target_names : List(Str) }',
  f'{{ artifact: {{ hash: {lst(H1)}, kind: 1, exposed_json: {rs(json.dumps(["Unicode","Utf"],separators=(",",":")))}, platform_hash: Err(Missing), roc_pin: Err(Missing), size: 12345 }}, deps: [{depin(D_B,H2,G1B,"4.1.0")}, {depin(D_A,H3,G1,"0.25.1")}], target_names: [] }}')
const('art1','Artifact.Row',arexpr(AR1))
const('art2_rows','{ artifact : Reads.ArtifactRow, deps : List(Reads.DepRow), target_names : List(Str) }',
  f'{{ artifact: {{ hash: {lst(H4)}, kind: 2, exposed_json: "[]", platform_hash: Err(Missing), roc_pin: Ok("nightly-2026-10-31-f7bef6b"), size: 99 }}, deps: [], target_names: ["x64linux", "wasm32"] }}')
const('art2','Artifact.Row',arexpr(AR2))
const('art3_rows','{ artifact : Reads.ArtifactRow, deps : List(Reads.DepRow), target_names : List(Str) }',
  f'{{ artifact: {{ hash: {lst(H5)}, kind: 0, exposed_json: "[]", platform_hash: Ok({lst(H4)}), roc_pin: Err(Missing), size: 7 }}, deps: [], target_names: [] }}')
const('art3','Artifact.Row',arexpr(AR3))
# bodies
RJ=lambda rows: '['+','.join(js(r) for r in rows)+']'
E=[r[1] for r in REL]
B_REL='{"releases":%s,"checked":%s,"repos":[%s,%s]}'%(RJ([E[0],E[1]]),chjs(CH),rpjs(RP2),rpjs(RP1))
B_NULL='{"releases":[],"checked":null,"repos":[]}'
B_PAGE='{"releases":%s,"repos":[%s]}'%(RJ([E[2]]),rpjs(RP1))
B_PAGE0='{"releases":[],"repos":[]}'
AR1_SORTED=AR1|{'deps':sorted(AR1['deps'],key=lambda d:d['alias'])}
B_ART='{"artifact":%s,"releases":[%s],"repos":[%s]}'%(js(AR1_SORTED),js(E[0]),rpjs(RP1))
for n,v in (('body_rel',B_REL),('body_null',B_NULL),('body_page',B_PAGE),('body_page0',B_PAGE0),('body_art',B_ART)): const(n,'Str',rs(v))
const('etag_page0','Str',rs(etag(B_PAGE0.encode())))
here=os.path.dirname(os.path.abspath(__file__))
root=os.path.join(here,'..','..','..')
head='''import lib.Reads
import lib.Route
import lib.Problem
import records.Release
import records.Artifact

ReadsTest :: [].{}

# W0 tests of worker/lib/Reads.roc (slice 106). The constants up to the line "# ---- tests ----" are generated by
# research/slice-106-revert/gen/gen_w0.py with python (hashlib, json): no expected value comes from the Roc code.

'''
body=open(os.path.join(here,'reads_tests.roc.in')).read()
open(os.path.join(root,'worker/tests/unit/ReadsTest.roc'),'w').write(head+'\n'.join(out)+'\n# ---- tests ----\n\n'+body)
print('ok',len(out))
