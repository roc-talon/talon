# The private reference of slice 113: puts the identity into worker/IngestRoutes.roc of the copy (anchored replacements, so the edits of other slices stay).
import sys
p = sys.argv[1] + '/IngestRoutes.roc'
s = open(p).read()

def rep(old, new, count=1):
    global s
    assert s.count(old) == count, (s.count(old), old[:80])
    s = s.replace(old, new)

rep('import records.Release\n', 'import pf.Env\nimport records.Release\nimport records.Id\nimport lib.Identity\n')

# D1 call 1 is a batch: the label row and the repos row of the name.
rep('''owner_stmt(target, now_ms)]).map_err(fault)?
''', '''owner_stmt(target, now_ms), Sql.stmt(repo_row_sql, [name_id(target)])]).map_err(fault)?
''')
rep('''		rows = label_rows(first.first().map_err(|_| Fault("the pre-read gave no result"))?.all())?
''', '''		rows = label_rows(first.first().map_err(|_| Fault("the pre-read gave no result"))?.all())?
		row = repo_row_of(first.get(2).map_err(|_| Fault("no repos result"))?.all())?
''')

rep('''				_ = read_repo!(target)?
				stmts = [
					Sql.stmt("INSERT INTO provenance (release, via, claims, time) SELECT ?1, 3, NULL, ?2 WHERE NOT EXISTS (SELECT 1 FROM provenance WHERE release = ?1 AND via = 3)", (log_index, Time.now_ms!())),
					Sql.stmt(label_sql, label_params(target)),
				]
''', '''				repo = read_repo!(target)?
				now = Time.now_ms!()
				change = match Identity.decide({ repo: name_id(target), row, seen: { repository_id: repo.id, owner_id: repo.owner_id }, now }) {
					Ok(c) => c
					Err(Changed) => return changed_response!(row, target.name)
				}
				stmts = [
					Sql.stmt("INSERT INTO provenance (release, via, claims, time) SELECT ?1, 3, NULL, ?2 WHERE NOT EXISTS (SELECT 1 FROM provenance WHERE release = ?1 AND via = 3)", (log_index, now)),
				]
					.concat(
						match row {
							Ok(_) => identity_writes(row, change, now).0
							Err(None) => []
						},
					)
					.append(Sql.stmt(label_sql, label_params(target)))
''')

rep('dropping(index!(session, target), req, target, 201)', 'dropping(index!(session, target, row), req, target, 201)')

rep('''	index! : D1.Session, Ingest.Target => Try(Response, IngestRoutes.Error)
	index! = |session, target| {
		repo = read_repo!(target)?
''', '''	index! : D1.Session, Ingest.Target, Try(Identity.Row, [None]) => Try(Response, IngestRoutes.Error)
	index! = |session, target, row| {
		repo = read_repo!(target)?
		now = Time.now_ms!()
		change = match Identity.decide({ repo: name_id(target), row, seen: { repository_id: repo.id, owner_id: repo.owner_id }, now }) {
			Ok(c) => c
			Err(Changed) => return changed_response!(row, target.name)
		}
''')
rep('''		plan = Ingest.plan({ target, repo, artifact, published_at, roc_version, now_ms: Time.now_ms!() })
		writes = writes_of(plan)
''', '''		plan = Ingest.plan({ target, repo, artifact, published_at, roc_version, now_ms: now })
		ids = identity_writes(row, change, plan.provenance_time)
		writes = writes_of(plan, ids.0, ids.1)
''')
rep('''	writes_of : Ingest.Plan -> List(Sql.Stmt)
	writes_of = |plan| {''', '''	writes_of : Ingest.Plan, List(Sql.Stmt), List(Sql.Stmt) -> List(Sql.Stmt)
	writes_of = |plan, id_before, id_after| {''')
rep('''		names.concat(new_targets).append(artifact).concat(deps).concat(artifact_targets).concat([leaf, release, provenance, repos, checks])''',
    '''		names.concat(new_targets).append(artifact).concat(deps).concat(artifact_targets).concat([leaf, release, provenance]).concat(id_before).append(repos).concat(id_after).append(checks)''')

rep('''	db = D1.binding("DB")
''', '''	db = D1.binding("DB")

	# ---- slice 113: the identity (R-TP9 to R-TP13) ----

	name_id : Ingest.Target -> I64
	name_id = |t| Id.name_id(3, t.name.to_utf8())

	repo_row_sql : Str
	repo_row_sql = "SELECT CAST(repo AS TEXT) AS repo, repository_id, repository_owner_id, state, CAST(successor AS TEXT) AS successor, state_at, time FROM repos WHERE repo = ?1"

	RepoSqlRow : { repo : Str, repository_id : U64, repository_owner_id : U64, state : U8, successor : Try(Str, [Missing]), state_at : U64, time : U64 }

	repo_row_of : Try(List(IngestRoutes.RepoSqlRow), _) -> Try(Try(Identity.Row, [None]), IngestRoutes.Error)
	repo_row_of = |read| {
		rows = read.map_err(fault)?
		match rows {
			[] => Ok(Err(None))
			[r, ..] => {
				id = I64.from_str(r.repo).map_err(|_| Fault("bad repo id"))?
				successor = match r.successor {
					Ok(text) => Ok(I64.from_str(text).map_err(|_| Fault("bad successor id"))?)
					Err(Missing) => Err(None)
				}
				state : Identity.State
				state = match r.state {
					0 => Active
					1 => Missing
					_ => Moved
				}
				Ok(Ok({ repo: id, repository_id: r.repository_id, owner_id: r.repository_owner_id, state, successor, state_at: r.state_at, time: r.time }))
			}
		}
	}

	changed_response! : Try(Identity.Row, [None]), Str => Try(Response, IngestRoutes.Error)
	changed_response! = |row, name| {
		issues = Env.var!("ISSUES_URL").map_err(|_| Fault("the setting ISSUES_URL is missing"))?
		bound = match row {
			Ok(r) => r.repository_id
			Err(None) => 0
		}
		Ok(Response.from_bytes(403, "application/problem+json", Identity.changed_json(Identity.changed(name, bound), issues).to_utf8()))
	}

	event_cols : Str
	event_cols = "INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time)"

	## The statements before the insert of the `repos` row, and after it (a rename and a bind need the order).
	identity_writes : Try(Identity.Row, [None]), Identity.Change, U64, Bool -> (List(Sql.Stmt), List(Sql.Stmt))
	identity_writes = |row, change, now, same| match row {
		Err(None) if !same => ([], [bind_stmt(change, now)])
		Err(None) => {
			new = change.row.repo
			ids = change.row
			update_old = Sql.stmt("UPDATE repos SET state = 2, successor = ?1, state_at = ?2 WHERE repository_id = ?3 AND repo <> ?1 AND state <> 2 AND NOT EXISTS (SELECT 1 FROM repos WHERE repo = ?1)", (new, now, ids.repository_id))
			event_old = Sql.stmt(
				"${event_cols} SELECT r.repo, (SELECT COALESCE(MAX(e.seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 2, r.repository_id, r.repository_id, r.repository_owner_id, r.repository_owner_id, ?1, NULL, ?2 FROM repos r WHERE changes() > 0 AND r.successor = ?1 AND r.state = 2 AND r.state_at = ?2 AND r.repository_id = ?3",
				(new, now, ids.repository_id),
			)
			event_new = Sql.stmt(
				"${event_cols} SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), CASE WHEN EXISTS (SELECT 1 FROM repo_events o WHERE o.action = 2 AND o.successor = ?1 AND o.time = ?2) THEN 2 ELSE 0 END, NULL, ?3, NULL, ?4, NULL, NULL, ?2 WHERE EXISTS (SELECT 1 FROM repos WHERE repo = ?1 AND time = ?2) AND NOT EXISTS (SELECT 1 FROM repo_events WHERE repo = ?1)",
				(new, now, ids.repository_id, ids.owner_id),
			)
			([update_old, event_old], [event_new])
		}
		Ok(old) => {
			a = change.row
			update = Sql.stmt(
				"UPDATE repos SET repository_id = ?2, repository_owner_id = ?3, state = ?4, successor = ?5, state_at = ?6 WHERE repo = ?1 AND repository_id = ?7 AND repository_owner_id = ?8",
				(a.repo, a.repository_id, a.owner_id, Identity.state_code(a.state), Sql.or_null(a.successor), a.state_at, old.repository_id, old.owner_id),
			)
			events = change.events.map(
				|e| Sql.stmt(
					"${event_cols} SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), ?2, ?3, ?4, ?5, ?6, ?7, NULL, ?8 WHERE changes() > 0",
					(e.repo, Identity.action_code(e.action), Sql.or_null(e.repository_id_before), Sql.or_null(e.repository_id_after), Sql.or_null(e.owner_id_before), Sql.or_null(e.owner_id_after), Sql.or_null(e.successor), now),
				),
			)
			found = change.events.any(|e| e.action == Found)
			recheck = if found [Sql.stmt("UPDATE repo_checks SET next_check_at = MIN(next_check_at, ?2) WHERE repo = ?1 AND changes() > 0", (a.repo, now))] else []
			base = if change.events.is_empty() [] else [update].concat(events).concat(recheck)
			(base.concat(revive(old, change, now, same)), [])
		}
	}

	## R-TP18 row 3: the row of U is `moved` and has the repository id: it is the current name again.
	revive : Identity.Row, Identity.Change, U64, Bool -> List(Sql.Stmt)
	revive = |old, change, now, same| {
		if same and old.state == Moved {
			u = old.repo
			rid = change.row.repository_id
			mark = Sql.stmt("UPDATE repos SET state = 2, successor = ?1, state_at = ?2 WHERE repository_id = ?3 AND repo <> ?1 AND state <> 2 AND EXISTS (SELECT 1 FROM repos WHERE repo = ?1 AND state = 2 AND repository_id = ?3)", (u, now, rid))
			event_marked = Sql.stmt(
				"${event_cols} SELECT r.repo, (SELECT COALESCE(MAX(e.seq), 0) + 1 FROM repo_events e WHERE e.repo = r.repo), 2, r.repository_id, r.repository_id, r.repository_owner_id, r.repository_owner_id, ?1, NULL, ?2 FROM repos r WHERE changes() > 0 AND r.successor = ?1 AND r.state = 2 AND r.state_at = ?2 AND r.repository_id = ?3",
				(u, now, rid),
			)
			back = Sql.stmt("UPDATE repos SET state = 0, successor = NULL, state_at = ?2 WHERE repo = ?1 AND state = 2 AND repository_id = ?3", (u, now, rid))
			event_back = Sql.stmt(
				"${event_cols} SELECT ?1, (SELECT COALESCE(MAX(seq), 0) + 1 FROM repo_events WHERE repo = ?1), 2, ?3, ?3, ?4, ?4, NULL, NULL, ?2 WHERE changes() > 0",
				(u, now, rid, change.row.owner_id),
			)
			[mark, event_marked, back, event_back]
		} else {
			[]
		}
	}

	## R-TP18 row 6: `U` has no row and `F` is another name: the bind only (the `repos` insert is in `writes_of`).
	bind_stmt : Identity.Change, U64 -> Sql.Stmt
	bind_stmt = |change, now| Sql.stmt(
		"${event_cols} SELECT ?1, 1, 0, NULL, ?3, NULL, ?4, NULL, NULL, ?2 WHERE EXISTS (SELECT 1 FROM repos WHERE repo = ?1 AND time = ?2) AND NOT EXISTS (SELECT 1 FROM repo_events WHERE repo = ?1)",
		(change.row.repo, now, change.row.repository_id, change.row.owner_id),
	)
''')
# C1 (R-TP18): the full_name of the answer; same = F is U.
rep('''	read_repo! : Ingest.Target => Try(Ingest.Repo, IngestRoutes.Error)
	read_repo! = |target| match github!(Ingest.repo_url(target), "repository", Bool.True)? {
		Missing => Err(Refuse(Ingest.not_public))
		Found(text) => match Ingest.parse_repo(text) {
			Ok(repo) if repo.public => Ok(repo)
''', '''	read_repo! : Ingest.Target => Try((Ingest.Repo, Bool), IngestRoutes.Error)
	read_repo! = |target| match github!(Ingest.repo_url(target), "repository", Bool.True)? {
		Missing => Err(Refuse(Ingest.not_public))
		Found(text) => match Ingest.parse_repo(text) {
			Ok(repo) if repo.public => {
				full = Identity.full_name_of(text).map_err(|_| Refuse(Ingest.github_bad(what_repo)))?
				Ok((repo, Identity.renamed(target.name, full) == Err(Same)))
			}
''')
rep('''				repo = read_repo!(target)?
				now = Time.now_ms!()''', '''				(repo, same) = read_repo!(target)?
				now = Time.now_ms!()''')
rep('''		repo = read_repo!(target)?
		now = Time.now_ms!()''', '''		(repo, same) = read_repo!(target)?
		now = Time.now_ms!()''')
rep('identity_writes(row, change, now).0', 'identity_writes(row, change, now, same).0')
rep('identity_writes(row, change, plan.provenance_time)', 'identity_writes(row, change, plan.provenance_time, same)')

open(p, 'w').write(s)
