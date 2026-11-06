## The handler of the ingest `POST /v1/releases` with no `Authorization` (Registry 4: R-AP9, R-AP26, R-AP41; 7: R-PU4, R-PU6, R-PU14, R-PU15, R-PU19, R-PU26,
## R-PU31, R-PU32; 5.1: R-IK3; 7.1: R-TP5; slice 112). The decisions are in `lib/Ingest.roc` (pure, W0). This module only orders the effects.
## The tests are W2: `worker/tests/cases/ingest/`. `Err(Refuse(problem))` is a problem answer, `Err(Fault(text))` is 500 `internal` (R-AP48, never a `crash`).
## `main.roc` calls `post!` only for a request with no `Authorization` header (R-AP26: a token is a publish, slice 114).
##
## Flow (Registry R-AP68 rows 1, 2, 4, 6 to 11; Design Q155 to Q165; rows 3, 5 and 12 are slice 112b):
## 1. `req.bytes_with!({ max_bytes: 262144 })` (R-AP46). `Err(TooLarge)`: 413 `too-large` with `field` `body` and `limit` 262144 (as `ClosureRoute`). Another `Err`: the bytes `[]`.
##    `Ingest.parse_body`, then `Ingest.parse_url`. A refusal makes no D1 call and no GitHub call.
## 2. One session `db.with_session!(Primary)` for all the D1 calls of the request (a write reads the newest state, R-AP41 row 5).
##    D1 call 1, the pre-read: the `Ingest.LabelRow` of the label (`releases.form` = the form id, `version`, `version_text` of `target.column`; the columns of
##    `Reads.ReleaseRow` as `ReadRoutes` reads them, and `EXISTS (SELECT 1 FROM provenance WHERE release = log_index AND via = 3)` as `has_ingest`).
##    `Ingest.after_read`: `Conflict` is `Refuse`. `Answer(release)` is the answer 200 (step 7). `AddProvenance` and `Index` go on.
## 3. GitHub `GET Ingest.repo_url(target)` (headers `user-agent: talon-registry`, `accept: application/vnd.github+json`). 404: `Ingest.not_public`.
##    Another status than 200: `Ingest.github_status("repository", s)`. No answer: `github_no_answer("repository")`. `Ingest.parse_repo` refuses: `github_bad("repository")`.
##    `public` is false: `Ingest.not_public` (R-PU32: nothing is written, and the log line has the problem type only).
## 4. `AddProvenance(log_index)`: D1 call 2, one batch: the provenance statement of section 3.2 row 8 and the read of step 2. Status 200 (step 7).
## 5. `Index`: GitHub `GET Ingest.release_url(target)` (the same headers). 404: `Ingest.no_release(tag)`. Another status: `github_status("release", s)`. No answer, or
##    `Ingest.parse_release` refuses: `github_no_answer("release")`, `github_bad("release")`. Then `Ingest.candidate`.
##    `Archive.read!(target.url, target.hash)`: `Refused(r)` is `ArchiveRead.problem(r)`, `Upstream(u)` is `ArchiveRead.upstream_problem(u)` (502), `Fault` is `Fault`.
##    GitHub `GET Ingest.roc_version_url(target)` with the header `user-agent: talon-registry`: 200 is `Ok(Ingest.roc_version_of(text))`, 404 is `Err(None)`,
##    another status `github_status(".roc-version", s)`, no answer `github_no_answer(".roc-version")`.
## 6. `Ingest.plan` with `Time.now_ms!()` (once for the request). D1 call 2: one batch with the statements of the slice file section 3.2, in that order, and last the read of step 2.
##    `Err(Constraint(c))`: `Ingest.batch_failure(c)`. `LabelConflict`: `Refuse(Ingest.label_conflict(target, Err(None)))`. `IdCollision`: D1 call 3, the read of
##    `Ingest.NameRow` for the ids of `plan.names`, then `Refuse(Ingest.collision(plan.names, rows))`. `Fault`: `Fault`.
## 7. The answer: the status `Ingest.status_of(<changes of the releases statement>)` (200 for steps 2 and 4), `content-type: application/json`,
##    `cache-control: Ingest.cache_control`, the body `Ingest.answer_body(release)` (`Reads.release_of_row` of the row of the last statement),
##    `talon-bookmark: <session.bookmark!()>` after the last D1 call (R-AP41 row 5), and for a 201 `location: Ingest.location(hash)`. A problem answer has no `talon-bookmark` (Q165).
import pf.Request
import pf.Response
import pf.Http
import pf.D1
import pf.Sql
import pf.Time
import lib.Problem
import lib.Ingest
import lib.Reads
import lib.ArchiveRead
import records.Release
import Archive

IngestRoutes :: [].{

	Error : [Refuse(Problem), Fault(Str)]

	db = D1.binding("DB")

	limit : U64
	limit = 262144

	Row : {
		log_index : U64,
		hash : List(U8),
		form : Str,
		version : Str,
		version_text : Str,
		url : Str,
		tag : Try(Str, [Missing]),
		roc_version : Try(Str, [Missing]),
		repo : Try(Str, [Missing]),
		published_at : U64,
		yanked : Bool,
		withdrawn : Try(Str, [Missing]),
		has_ingest : Bool,
	}

	label_sql : Str
	label_sql = "SELECT r.log_index AS log_index, an.value AS hash, fn.value AS form, CAST(r.version AS TEXT) AS version, r.version_text AS version_text, r.url AS url, r.tag AS tag, r.roc_version AS roc_version, rn.value AS repo, r.published_at AS published_at, r.yanked AS yanked, r.withdrawn AS withdrawn, EXISTS (SELECT 1 FROM provenance p WHERE p.release = r.log_index AND p.via = 3) AS has_ingest FROM releases r JOIN names an ON an.id = r.artifact JOIN names fn ON fn.id = r.form LEFT JOIN names rn ON rn.id = r.repo WHERE r.form = ?1 AND r.version = ?2 AND r.version_text = ?3"

	label_of : IngestRoutes.Row -> Ingest.LabelRow
	label_of = |r| {
		release: { log_index: r.log_index, hash: r.hash, form: r.form, version: r.version, version_text: r.version_text, url: r.url, tag: r.tag, roc_version: r.roc_version, repo: r.repo, published_at: r.published_at, yanked: r.yanked, withdrawn: r.withdrawn },
		has_ingest: r.has_ingest,
	}

	fault = |e| Fault(Str.inspect(e))

	post! : Request => Try(Response, IngestRoutes.Error)
	post! = |req| {
		bytes = match req.bytes_with!({ max_bytes: limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(Response.from_bytes(413, "application/problem+json", Problem.to_json_with(Problem.new(TooLarge, "the request body is larger than ${limit.to_str()} bytes"), { field: "body", limit }).to_utf8()))
			Err(_) => []
		}
		url = Ingest.parse_body(bytes).map_err(|p| Refuse(p))?
		target = Ingest.parse_url(url).map_err(|p| Refuse(p))?
		label_params : (I64, Str, Str)
		label_params = (Reads.form_id(target.form), target.column.version, target.column.version_text)
		session = db.with_session!(Primary).map_err(fault)?
		rows : List(IngestRoutes.Row)
		rows = session.all!(label_sql, label_params).map_err(fault)?
		next = Ingest.after_read(target, rows.map(label_of)).map_err(|BadRow(t)| Fault(t))?
		match next {
			Conflict(p) => Err(Refuse(p))
			Answer(release) => answer!(session, 200, release)
			AddProvenance(log_index) => {
				_ = read_repo!(target)?
				now = Time.now_ms!()
				results = session.batch!([provenance_stmt(log_index, now), Sql.stmt(label_sql, label_params)]).map_err(fault)?
				release = last_release(results)?
				answer!(session, 200, release)
			}
			Index => index!(session, target, label_params)
		}
	}

	index! : D1.Session, Ingest.Target, (I64, Str, Str) => Try(Response, IngestRoutes.Error)
	index! = |session, target, label_params| {
		repo = read_repo!(target)?
		gh = read_github!(Ingest.release_url(target), "release")?
		gh_release = match gh {
			Found(text) => Ingest.parse_release(text).map_err(|_| Refuse(Ingest.github_bad("release")))?
			Missing => return Err(Refuse(Ingest.no_release(target.tag)))
		}
		published_at = Ingest.candidate(target, gh_release).map_err(|p| Refuse(p))?
		artifact = match Archive.read!(target.url, target.hash) {
			Ok(a) => a
			Err(Refused(r)) => return Err(Refuse(ArchiveRead.problem(r)))
			Err(Upstream(u)) => return Err(Refuse(ArchiveRead.upstream_problem(u)))
			Err(Fault(t)) => return Err(Fault(t))
		}
		roc_version = match read_github!(Ingest.roc_version_url(target), ".roc-version")? {
			Found(text) => Ok(Ingest.roc_version_of(text))
			Missing => Err(None)
		}
		now = Time.now_ms!()
		plan = Ingest.plan({ target, repo, artifact, published_at, roc_version, now_ms: now })
		stmts = statements(plan, {}).append(Sql.stmt(label_sql, label_params))
		results = match session.batch!(stmts) {
			Ok(r) => r
			Err(Constraint(c)) =>
				match Ingest.batch_failure(c) {
					LabelConflict => return Err(Refuse(Ingest.label_conflict(target, Err(None))))
					IdCollision => {
						ids = Str.join_with(plan.names.map(|n| n.id.to_str()), ",")
						name_rows : List(Ingest.NameRow)
						name_rows = session.all!("SELECT CAST(id AS TEXT) AS id, kind, CAST(value AS BLOB) AS value FROM names WHERE id IN (SELECT value FROM json_each(?1))", ["[${ids}]"]).map_err(fault)?
						return Err(Refuse(Ingest.collision(plan.names, name_rows)))
					}
					Fault => return Err(Fault(c.message))
				}
			Err(e) => return Err(fault(e))
		}
		release_index = plan.names.len() + plan.new_targets.len() + 1 + plan.deps.len() + plan.target_names.len() + 1
		changes = match results.get(release_index) {
			Ok(r) => r.info().changes
			Err(_) => 0
		}
		release = last_release(results)?
		answer!(session, Ingest.status_of(changes), release)
	}

	last_release : List(D1.Result) -> Try(Release.Row, IngestRoutes.Error)
	last_release = |results| {
		last = results.last().map_err(|_| Fault("the batch gave no result"))?
		rows : List(IngestRoutes.Row)
		rows = last.all().map_err(fault)?
		match rows {
			[r, ..] => Reads.release_of_row(label_of(r).release).map_err(|BadRow(t)| Fault(t))
			[] => Err(Fault("the label has no row after the batch"))
		}
	}

	answer! : D1.Session, U16, Release.Row => Try(Response, IngestRoutes.Error)
	answer! = |session, status, release| {
		res = Response.from_bytes(status, "application/json", Ingest.answer_body(release).to_utf8()).with_header("cache-control", Ingest.cache_control)
		with_loc = if (status == 201) res.with_header("location", Ingest.location(release.hash)) else res
		Ok(
			match session.bookmark!() {
				Ok(b) => with_loc.with_header("talon-bookmark", b)
				Err(_) => with_loc
			},
		)
	}

	read_repo! : Ingest.Target => Try(Ingest.Repo, IngestRoutes.Error)
	read_repo! = |target| {
		repo = match read_github!(Ingest.repo_url(target), "repository")? {
			Found(text) => Ingest.parse_repo(text).map_err(|_| Refuse(Ingest.github_bad("repository")))?
			Missing => return Err(Refuse(Ingest.not_public))
		}
		if (repo.public) Ok(repo) else Err(Refuse(Ingest.not_public))
	}

	read_github! : Str, Str => Try([Found(Str), Missing], IngestRoutes.Error)
	read_github! = |url, what| {
		res = Http.send!(Request.get(url).with_header("user-agent", "talon-registry").with_header("accept", "application/vnd.github+json")).map_err(|_| Refuse(Ingest.github_no_answer(what)))?
		status = res.status()
		if status == 404 {
			Ok(Missing)
		} else if status != 200 {
			Err(Refuse(Ingest.github_status(what, status)))
		} else {
			Ok(Found(res.text!().map_err(|_| Refuse(Ingest.github_bad(what)))?))
		}
	}

	provenance_stmt : U64, U64 -> Sql.Stmt
	provenance_stmt = |log_index, now| Sql.stmt("INSERT INTO provenance (release, via, claims, time) SELECT ?1, 3, NULL, ?2 WHERE NOT EXISTS (SELECT 1 FROM provenance WHERE release = ?1 AND via = 3)", (log_index, now))

	statements : Ingest.Plan, {} -> List(Sql.Stmt)
	statements = |p, {}| {
		names = p.names.map(
			|n| {
				value = if (n.kind == 1) Sql.Blob(n.value) else Sql.Text(Str.from_utf8(n.value) ?? "")
				Sql.stmt("INSERT INTO names (id, kind, value) VALUES (?1, ?2, ?3) ON CONFLICT (kind, value) DO NOTHING", (n.id, n.kind.to_i64(), value))
			},
		)
		new_tgts = p.new_targets.map(|t| Sql.stmt("INSERT INTO targets (target, name) SELECT (SELECT MAX(target) + 1 FROM targets), ?1 WHERE NOT EXISTS (SELECT 1 FROM targets WHERE name = ?1)", [t]))
		a = p.artifact
		artifact = Sql.stmt(
			"INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) SELECT ?1, ?2, ?3, ?4, ?5, ?6 WHERE NOT EXISTS (SELECT 1 FROM artifacts WHERE artifact = ?1)",
			(a.id, a.kind.to_i64(), a.exposes_json, opt_int(a.platform_id), opt_text(a.roc_pin), a.size),
		)
		deps = p.deps.map(
			|d| {
				(version, version_text) = match d.version {
					Ok(c) => (Sql.Text(c.version), Sql.Text(c.version_text))
					Err(None) => (Sql.Null, Sql.Null)
				}
				Sql.stmt(
					"INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7 WHERE NOT EXISTS (SELECT 1 FROM deps WHERE artifact = ?1 AND alias = ?2)",
					(a.id, d.alias, d.dep, opt_int(d.form), version, version_text, d.url),
				)
			},
		)
		tgts = p.target_names.map(|t| Sql.stmt("INSERT INTO artifact_targets (artifact, target) SELECT ?1, (SELECT target FROM targets WHERE name = ?2) WHERE NOT EXISTS (SELECT 1 FROM artifact_targets WHERE artifact = ?1 AND target = (SELECT target FROM targets WHERE name = ?2))", (a.id, t)))
		r = p.release
		leaf = Sql.stmt(
			"INSERT INTO log (idx, grp, version, hash, time) SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4 WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7)",
			(p.leaf.grp, p.leaf.version, p.leaf.hash, p.leaf.time, r.form, r.column.version, r.column.version_text),
		)
		release = Sql.stmt(
			"INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4)",
			(r.form, r.column.version, r.column.version_text, r.artifact, r.repo, r.url, r.tag, opt_text(r.roc_version), r.published_at),
		)
		prov = Sql.stmt(
			"INSERT INTO provenance (release, via, claims, time) SELECT r.log_index, 3, NULL, ?4 FROM releases r WHERE r.form = ?1 AND r.version = ?2 AND r.version_text = ?3 AND NOT EXISTS (SELECT 1 FROM provenance p WHERE p.release = r.log_index AND p.via = 3)",
			(r.form, r.column.version, r.column.version_text, p.provenance_time),
		)
		rr = p.repo_row
		repo = Sql.stmt(
			"INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) SELECT ?1, ?2, ?3, 0, NULL, ?4, ?4 WHERE NOT EXISTS (SELECT 1 FROM repos WHERE repo = ?1)",
			(rr.repo, rr.repository_id, rr.repository_owner_id, rr.time),
		)
		check = Sql.stmt(
			"INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) SELECT ?1, NULL, NULL, ?2, 0, 0 WHERE NOT EXISTS (SELECT 1 FROM repo_checks WHERE repo = ?1)",
			(p.check_row.repo, p.check_row.next_check_at),
		)
		names.concat(new_tgts).append(artifact).concat(deps).concat(tgts).concat([leaf, release, prov, repo, check])
	}

	opt_int = |t| match t {
		Ok(v) => Sql.Int(v)
		Err(None) => Sql.Null
	}

	opt_text = |t| match t {
		Ok(v) => Sql.Text(v)
		Err(None) => Sql.Null
	}
}
