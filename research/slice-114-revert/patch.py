# Private reference of slice 114 (not for the code agent, TW18): anchored replacements on the live worker/IngestRoutes.roc and worker/Auth.roc of a copy.
# Usage: patch.py <worker dir of the copy>. Each replacement must match exactly once, so a change of the live file shows as an error here, not as a silent wrong build.
import sys, re
d = sys.argv[1]

def edit(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        n = s.count(old)
        assert n >= 1, (path, 'no match', old)
        s = s.replace(old, new)
    open(path, 'w').write(s)

def one(old, new):
    return (old, new)

ingest = d + '/IngestRoutes.roc'
s = open(ingest).read()
def sub(old, new, count=1):
    global s
    assert s.count(old) == count, (s.count(old), old)
    s = s.replace(old, new)

# 1. the label read for a given via
sub('label_sql : Str\n\tlabel_sql = "SELECT', 'label_sql : Str\n\tlabel_sql = label_sql_of(3)\n\n\tlabel_sql_of : U8 -> Str\n\tlabel_sql_of = |via| "SELECT')
sub('p.via = 3) AS has_ingest FROM releases r', 'p.via = ${via.to_str()}) AS has_ingest FROM releases r')
# 2. old_row takes the index of the result
sub('old_row : List(D1.Result), I64 -> Try(', 'old_row : List(D1.Result), I64, U64 -> Try(')
sub('old_row = |results, repo| {', 'old_row = |results, repo, at| {')
sub('results.get(2).map_err(|_| Fault("the pre-read gave no repos result"))', 'results.get(at).map_err(|_| Fault("the pre-read gave no repos result"))')
sub('old = old_row(first, repo_id)?', 'old = old_row(first, repo_id, 2)?')
# 3. the context of index!
sub('\tpost! : Request => Try(Response, IngestRoutes.Error)', '''\tCtx : {
\t\tgithub_repo : { repo : Ingest.Repo, full_name : Str },
\t\tvia : U8,
\t\tclaims : Try(Str, [None]),
\t\textra : U64 -> List(Sql.Stmt),
\t\tcandidate : Ingest.Target, Ingest.GithubRelease -> Try(U64, Problem),
\t\tno_release : Str -> Problem,
\t}

\tingest_ctx : { repo : Ingest.Repo, full_name : Str } -> IngestRoutes.Ctx
\tingest_ctx = |github_repo| { github_repo, via: 3, claims: Err(None), extra: |_now| [], candidate: Ingest.candidate, no_release: Ingest.no_release }

\tpost! : Request => Try(Response, IngestRoutes.Error)''')
sub('identity = match identity!(target, repo_id, github_repo, old, now)? {\n\t\t\t\t\tStop(response) => return Ok(response)\n\t\t\t\t\tGo(stmts) => stmts',
    'identity = match identity!(target, repo_id, github_repo, old, now, Err(None))? {\n\t\t\t\t\tStop(response) => return Ok(response)\n\t\t\t\t\tGo(g) => g.stmts')
sub('dropping(index!(session, target, repo_id, old), req, target, 201)', 'github_repo = read_repo!(target)?\n\t\t\t\tdropping(index!(session, target, repo_id, old, ingest_ctx(github_repo)), req, target, 201)')
sub('index! : D1.Session, Ingest.Target, I64, Try(Identity.Row, [None]) => Try(Response, IngestRoutes.Error)\n\tindex! = |session, target, repo_id, old| {\n\t\tgithub_repo = read_repo!(target)?',
    'index! : D1.Session, Ingest.Target, I64, Try(Identity.Row, [None]), IngestRoutes.Ctx => Try(Response, IngestRoutes.Error)\n\tindex! = |session, target, repo_id, old, ctx| {\n\t\tgithub_repo = ctx.github_repo')
sub('identity = match identity!(target, repo_id, github_repo, old, now)? {\n\t\t\tStop(response) => return Ok(response)\n\t\t\tGo(stmts) => stmts',
    'identity = match identity!(target, repo_id, github_repo, old, now, ctx.claims)? {\n\t\t\tStop(response) => return Ok(response)\n\t\t\tGo(g) => g.stmts')
sub('Missing => return Err(Refuse(Ingest.no_release(target.tag)))', 'Missing => return Err(Refuse((ctx.no_release)(target.tag)))')
sub('published_at = Ingest.candidate(target, release).map_err(|p| Refuse(p))?', 'published_at = (ctx.candidate)(target, release).map_err(|p| Refuse(p))?')
sub('writes = writes_of(plan).concat(identity)', 'writes = writes_of(plan, ctx.via, ctx.claims).concat(identity).concat((ctx.extra)(now))')
# 4. identity! takes the claims and says if the change has events
sub('Try(Identity.Row, [None]), U64 => Try([Go(List(Sql.Stmt)), Stop(Response)], IngestRoutes.Error)\n\tidentity! = |target, repo_id, github_repo, old, now| {',
    'Try(Identity.Row, [None]), U64, Try(Str, [None]) => Try([Go({ stmts : List(Sql.Stmt), events : Bool }), Stop(Response)], IngestRoutes.Error)\n\tidentity! = |target, repo_id, github_repo, old, now, claims| {')
sub('Ok(Go(identity_stmts({ u: repo_id, same, old, change, now })))', 'Ok(Go({ stmts: identity_stmts({ u: repo_id, same, old, change, now, claims }), events: !change.events.is_empty() }))')
sub('IdentityInput : { u : I64, same : Bool, old : Try(Identity.Row, [None]), change : Identity.Change, now : U64 }', 'IdentityInput : { u : I64, same : Bool, old : Try(Identity.Row, [None]), change : Identity.Change, now : U64, claims : Try(Str, [None]) }')
# 5. the claims in the events
sub('event_stmt(e, input.now)', 'event_stmt(e, input.now, input.claims)', 2)
sub('event_stmt : Identity.Event, U64 -> Sql.Stmt\n\tevent_stmt = |e, now| Sql.stmt(', 'event_stmt : Identity.Event, U64, Try(Str, [None]) -> Sql.Stmt\n\tevent_stmt = |e, now, claims| Sql.stmt(')
sub('?4, ?5, ?6, ?7, NULL, ?8 WHERE changes() > 0",', '?4, ?5, ?6, ?7, ?9, ?8 WHERE changes() > 0",')
sub('\t\t\tSql.or_null(e.successor),\n\t\t\tnow,\n\t\t),', '\t\t\tSql.or_null(e.successor),\n\t\t\tnow,\n\t\t\tSql.or_null(claims),\n\t\t),')
sub('named = Sql.stmt(\n\t\t\t\t"${event_cols} SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), CASE WHEN EXISTS (SELECT 1 FROM repos WHERE repository_id = ?2 AND repo <> ?1 AND state = 2 AND successor = ?1 AND state_at = ?4) THEN 2 ELSE 0 END, NULL, ?2, NULL, ?3, NULL, NULL, ?4 WHERE changes() > 0",\n\t\t\t\t(input.u, row.repository_id, row.owner_id, input.now),',
    'named = Sql.stmt(\n\t\t\t\t"${event_cols} SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), CASE WHEN EXISTS (SELECT 1 FROM repos WHERE repository_id = ?2 AND repo <> ?1 AND state = 2 AND successor = ?1 AND state_at = ?4) THEN 2 ELSE 0 END, NULL, ?2, NULL, ?3, NULL, ?5, ?4 WHERE changes() > 0",\n\t\t\t\t(input.u, row.repository_id, row.owner_id, input.now, Sql.or_null(input.claims)),')
sub('marked_events_stmt(input.u, row.repository_id, input.now)', 'marked_events_stmt(input.u, row.repository_id, input.now, input.claims)', 2)
sub('marked_events_stmt : I64, U64, U64 -> Sql.Stmt\n\tmarked_events_stmt = |u, id, now| Sql.stmt(', 'marked_events_stmt : I64, U64, U64, Try(Str, [None]) -> Sql.Stmt\n\tmarked_events_stmt = |u, id, now, claims| Sql.stmt(')
sub('r.repository_owner_id, ?1, NULL, ?2 FROM repos r WHERE', 'r.repository_owner_id, ?1, ?4, ?2 FROM repos r WHERE')
sub('\t\t(u, now, id),\n\t)', '\t\t(u, now, id, Sql.or_null(claims)),\n\t)')
sub('\t\t\t\tsuccessor: Err(None),\n\t\t\t},\n\t\t\tinput.now,\n\t\t)', '\t\t\t\tsuccessor: Err(None),\n\t\t\t},\n\t\t\tinput.now,\n\t\t\tinput.claims,\n\t\t)')
# 6. the provenance statement of the batch: via and claims
sub('writes_of : Ingest.Plan -> List(Sql.Stmt)\n\twrites_of = |plan| {', 'writes_of : Ingest.Plan, U8, Try(Str, [None]) -> List(Sql.Stmt)\n\twrites_of = |plan, via, claims| {')
sub('"INSERT INTO provenance (release, via, claims, time) SELECT r.log_index, 3, NULL, ?4 FROM releases r WHERE ${label} AND NOT EXISTS (SELECT 1 FROM provenance p WHERE p.release = r.log_index AND p.via = 3)",\n\t\t\t(r.form, r.column.version, r.column.version_text, plan.provenance_time),',
    '"INSERT INTO provenance (release, via, claims, time) SELECT r.log_index, ${via.to_str()}, ?5, ?4 FROM releases r WHERE ${label} AND NOT EXISTS (SELECT 1 FROM provenance p WHERE p.release = r.log_index AND p.via = ${via.to_str()})",\n\t\t\t(r.form, r.column.version, r.column.version_text, plan.provenance_time, Sql.or_null(claims)),')
open(ingest, 'w').write(s)

# Auth.roc: the body of publish!
auth = d + '/Auth.roc'
a = open(auth).read()
old = '\tpublish! = |_req, _asset| crash "todo"'
assert a.count(old) == 1, 'Auth stub'
new = '''\tpublish! = |req, asset| {
\t\ttoken = match Oidc.bearer(req.header("authorization")) {
\t\t\tToken(text) => text
\t\t\tNoToken => return Err(Oidc.missing_token)
\t\t\tRefuse(problem) => return Err(problem)
\t\t}
\t\tclaims = verify!(token)?
\t\tOidc.check_publish(claims, { host: "github.com", owner_repo: asset.owner_repo, tag: asset.tag })?
\t\tOk(claims)
\t}'''
open(auth, 'w').write(a.replace(old, new))
