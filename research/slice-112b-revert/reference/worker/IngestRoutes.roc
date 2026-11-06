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
import pf.Cache
import pf.RateLimit
import lib.IngestLimits
import lib.Client
import lib.Version
import records.Release
import lib.ArchiveRead
import lib.Ingest
import lib.Problem
import lib.Reads
import Archive

IngestRoutes :: [].{

	## The error of the handler: the same form as `ReadRoutes.Error`.
	Error : [Refuse(Problem), Fault(Str)]

	post! : Request => Try(Response, IngestRoutes.Error)
	post! = |req| {
		bytes = match req.bytes_with!({ max_bytes: body_limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(too_large)
			Err(BodyErr(_)) => []
		}
		url = Ingest.parse_body(bytes).map_err(|p| Refuse(p))?
		target = Ingest.parse_url(url).map_err(|p| Refuse(p))?
		match rl.limit!(Client.rate_key(req.header("cf-connecting-ip"))) {
			Ok({}) => {}
			Err(RateLimited) => return Ok(limited(IngestLimits.ip_limited, IngestLimits.ip_retry_after))
			Err(Infra(_)) => return Err(Fault("the rate limit failed"))
		}
		session = db.with_session!(Primary).map_err(fault)?
		owner = IngestLimits.owner_of(target.name)
		range = IngestLimits.owner_range(owner)
		now = Time.now_ms!()
		pre = session.batch!([Sql.stmt(label_sql, label_params(target)), Sql.stmt(owner_sql, (range.lo, range.hi, IngestLimits.day_start(now), Reads.repo_id(target.owner, target.repo)))]).map_err(fault)?
		first = pre.first().map_err(|_| Fault("no pre-read result"))?
		rows = label_rows(first.all())?
		second = pre.last().map_err(|_| Fault("no owner result"))?
		counts : Try(List({ count : U64, has_repo : Bool }), _)
		counts = second.all()
		oc = match counts.map_err(fault)? {
			[c, ..] => c
			[] => { count: 0, has_repo: Bool.False }
		}
		drop = |res| res.after(|| drop!(origin_of(req.url()), target))
		match Ingest.after_read(target, rows).map_err(bad_row)? {
			Conflict(problem) => Err(Refuse(problem))
			Answer(release) => answer!(session, 200, release)
			AddProvenance(log_index) => {
				_ = read_repo!(target)?
				stmts = [
					Sql.stmt("INSERT INTO provenance (release, via, claims, time) SELECT ?1, 3, NULL, ?2 WHERE NOT EXISTS (SELECT 1 FROM provenance WHERE release = ?1 AND via = 3)", (log_index, Time.now_ms!())),
					Sql.stmt(label_sql, label_params(target)),
				]
				results = session.batch!(stmts).map_err(fault)?
				answer!(session, 200, last_release(results)?).map_ok(drop)
			}
			Index =>
				match IngestLimits.owner_check({ owner, has_repo: oc.has_repo, count: oc.count, now_ms: now }) {
					Err((p, secs)) => Ok(limited(p, secs))
					Ok({}) => index!(session, target).map_ok(drop)
				}
		}
	}

	rl = RateLimit.binding(IngestLimits.ip_binding)

	owner_sql : Str
	owner_sql = "SELECT (SELECT COUNT(*) FROM repos p JOIN names n ON n.id = p.repo WHERE n.kind = 3 AND n.value >= ?1 AND n.value < ?2 AND p.time >= ?3) AS count, EXISTS (SELECT 1 FROM repos WHERE repo = ?4) AS has_repo"

	limited : Problem, U64 -> Response
	limited = |p, secs| Response.from_bytes(429, "application/problem+json", p.to_json().to_utf8()).with_header("retry-after", secs.to_str())

	origin_of : Str -> Str
	origin_of = |url| Str.join_with(url.split_on("/").take_first(3), "/")

	drop! : Str, Ingest.Target => Try({}, Str)
	drop! = |origin, t| {
		keys = IngestLimits.drop_keys({ origin, group: t.form, series: Version.series_of(t.version), name: t.name, hash: t.hash })
		for k in keys {
			_ = Cache.default.delete!(k)
		}
		Ok({})
	}

	## R-AP46: the most bytes of the body.
	body_limit : U64
	body_limit = 262144

	too_large : Response
	too_large = {
		problem = Problem.new(TooLarge, "the body of the ingest request is larger than its limit of ${body_limit.to_str()}")
		Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, { field: "body", limit: body_limit }).to_utf8())
	}

	## Steps 3, 5, 6: the GitHub reads, the archive read, and the write batch.
	index! : D1.Session, Ingest.Target => Try(Response, IngestRoutes.Error)
	index! = |session, target| {
		repo = read_repo!(target)?
		release_text = match github!(Ingest.release_url(target), "release", Bool.True)? {
			Found(text) => text
			Missing => return Err(Refuse(Ingest.no_release(target.tag)))
		}
		release = Ingest.parse_release(release_text).map_err(|_| Refuse(Ingest.github_bad("release")))?
		published_at = Ingest.candidate(target, release).map_err(|p| Refuse(p))?
		artifact = Archive.read!(target.url, target.hash).map_err(
			|e| match e {
				Refused(r) => Refuse(ArchiveRead.problem(r))
				Upstream(u) => Refuse(ArchiveRead.upstream_problem(u))
				Fault(text) => Fault(text)
			},
		)?
		roc_version = match github!(Ingest.roc_version_url(target), ".roc-version", Bool.False)? {
			Found(text) => Ok(Ingest.roc_version_of(text))
			Missing => Err(None)
		}
		plan = Ingest.plan({ target, repo, artifact, published_at, roc_version, now_ms: Time.now_ms!() })
		writes = writes_of(plan)
		release_at = plan.names.len() + plan.new_targets.len() + 1 + plan.deps.len() + plan.target_names.len() + 1
		match session.batch!(writes.append(Sql.stmt(label_sql, label_params(target)))) {
			Ok(results) => {
				changes = results.get(release_at).map_ok(|r| r.info().changes) ?? 0
				answer!(session, Ingest.status_of(changes), last_release(results)?)
			}
			Err(Constraint(c)) => match Ingest.batch_failure(c) {
				LabelConflict => Err(Refuse(Ingest.label_conflict(target, Err(None))))
				IdCollision => {
					ids = plan.names.map(|n| n.id)
					marks = Str.join_with(ids.map(|_| "?"), ", ")
					found : Try(List(Ingest.NameRow), _)
					found = session.all!("SELECT CAST(id AS TEXT) AS id, kind, CAST(value AS BLOB) AS value FROM names WHERE id IN (${marks})", ids)
					Err(Refuse(Ingest.collision(plan.names, found.map_err(fault)?)))
				}
				Fault => Err(Fault(c.message))
			}
			Err(e) => Err(fault(e))
		}
	}

	## Step 3: the visibility read (R-PU31, R-PU32).
	read_repo! : Ingest.Target => Try(Ingest.Repo, IngestRoutes.Error)
	read_repo! = |target| match github!(Ingest.repo_url(target), "repository", Bool.True)? {
		Missing => Err(Refuse(Ingest.not_public))
		Found(text) => match Ingest.parse_repo(text) {
			Ok(repo) if repo.public => Ok(repo)
			Ok(_) => Err(Refuse(Ingest.not_public))
			Err(BadRepo) => Err(Refuse(Ingest.github_bad(what_repo)))
		}
	}

	what_repo : Str
	what_repo = "repository"

	## One GitHub `GET`: 200 is `Found(text)`, 404 is `Missing`, another status or no answer is 502 `upstream`.
	github! : Str, Str, Bool => Try([Found(Str), Missing], IngestRoutes.Error)
	github! = |url, what, api| {
		base = Request.get(url).with_header("user-agent", "talon-registry")
		request = if (api) base.with_header("accept", "application/vnd.github+json") else base
		res = Http.send!(request).map_err(|_| Refuse(Ingest.github_no_answer(what)))?
		status = res.status()
		if status == 404 {
			Ok(Missing)
		} else if status != 200 {
			Err(Refuse(Ingest.github_status(what, status)))
		} else {
			res.text!().map_ok(|text| Found(text)).map_err(|_| Refuse(Ingest.github_bad(what)))
		}
	}

	## The answer 200 or 201 (step 7), with the bookmark of the session after its last call (R-AP41 row 5).
	answer! : D1.Session, U16, Release.Row => Try(Response, IngestRoutes.Error)
	answer! = |session, status, release| {
		base = Response.from_bytes(status, "application/json", Ingest.answer_body(release).to_utf8()).with_header("cache-control", Ingest.cache_control)
		located = if (status == 201) base.with_header("location", Ingest.location(release.hash)) else base
		Ok(
			match session.bookmark!() {
				Ok(bookmark) => located.with_header("talon-bookmark", bookmark)
				Err(NotFound) => located
			},
		)
	}

	# ---- the label read (step 2, and the last statement of a batch) ----

	## The columns of `Reads.ReleaseRow` and `has_ingest`, in one flat row.
	LabelSqlRow : {
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

	label_params : Ingest.Target -> (I64, Str, Str)
	label_params = |t| (Reads.form_id(t.form), t.column.version, t.column.version_text)

	label_rows : Try(List(IngestRoutes.LabelSqlRow), _) -> Try(List(Ingest.LabelRow), IngestRoutes.Error)
	label_rows = |read| {
		rows = read.map_err(fault)?
		Ok(
			rows.map(
				|r| {
					release: {
						log_index: r.log_index,
						hash: r.hash,
						form: r.form,
						version: r.version,
						version_text: r.version_text,
						url: r.url,
						tag: r.tag,
						roc_version: r.roc_version,
						repo: r.repo,
						published_at: r.published_at,
						yanked: r.yanked,
						withdrawn: r.withdrawn,
					},
					has_ingest: r.has_ingest,
				},
			),
		)
	}

	## The release of the label read, the last statement of a batch.
	last_release : List(D1.Result) -> Try(Release.Row, IngestRoutes.Error)
	last_release = |results| {
		last = results.last().map_err(|_| Fault("the batch gave no result"))?
		rows = label_rows(last.all())?
		match rows {
			[row, ..] => Reads.release_of_row(row.release).map_err(bad_row)
			[] => Err(Fault("the label has no row after the write batch"))
		}
	}

	# ---- the write batch (slice file section 3.2, R-SG8, Design Q86: no OR IGNORE) ----

	writes_of : Ingest.Plan -> List(Sql.Stmt)
	writes_of = |plan| {
		a = plan.artifact
		r = plan.release
		names = plan.names.map(
			|n| {
				sql = "INSERT INTO names (id, kind, value) VALUES (?, ?, ?) ON CONFLICT (kind, value) DO NOTHING"
				if (n.kind == 1) Sql.stmt(sql, (n.id, n.kind, Sql.blob(n.value))) else Sql.stmt(sql, (n.id, n.kind, Str.from_utf8_lossy(n.value)))
			},
		)
		new_targets = plan.new_targets.map(|name| Sql.stmt("INSERT INTO targets (target, name) SELECT (SELECT MAX(target) + 1 FROM targets), ?1 WHERE NOT EXISTS (SELECT 1 FROM targets WHERE name = ?1)", [name]))
		artifact = Sql.stmt(
			"INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) SELECT ?1, ?2, ?3, ?4, ?5, ?6 WHERE NOT EXISTS (SELECT 1 FROM artifacts WHERE artifact = ?1)",
			(a.id, a.kind, a.exposes_json, Sql.or_null(a.platform_id), Sql.or_null(a.roc_pin), a.size),
		)
		deps = plan.deps.map(
			|d| Sql.stmt(
				"INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7 WHERE NOT EXISTS (SELECT 1 FROM deps WHERE artifact = ?1 AND alias = ?2)",
				(a.id, d.alias, d.dep, Sql.or_null(d.form), Sql.or_null(d.version.map_ok(|c| c.version)), Sql.or_null(d.version.map_ok(|c| c.version_text)), d.url),
			),
		)
		artifact_targets = plan.target_names.map(
			|name| Sql.stmt(
				"INSERT INTO artifact_targets (artifact, target) SELECT ?1, t.target FROM targets t WHERE t.name = ?2 AND NOT EXISTS (SELECT 1 FROM artifact_targets x WHERE x.artifact = ?1 AND x.target = t.target)",
				(a.id, name),
			),
		)
		label = "form = ?1 AND version = ?2 AND version_text = ?3"
		leaf = Sql.stmt(
			"INSERT INTO log (idx, grp, version, hash, time) SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?4, ?5, ?6, ?7 WHERE NOT EXISTS (SELECT 1 FROM releases WHERE ${label})",
			(r.form, r.column.version, r.column.version_text, plan.leaf.grp, plan.leaf.version, plan.leaf.hash, plan.leaf.time),
		)
		release = Sql.stmt(
			"INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM releases WHERE ${label} AND artifact = ?4)",
			(r.form, r.column.version, r.column.version_text, r.artifact, r.repo, r.url, r.tag, Sql.or_null(r.roc_version), r.published_at),
		)
		provenance = Sql.stmt(
			"INSERT INTO provenance (release, via, claims, time) SELECT r.log_index, 3, NULL, ?4 FROM releases r WHERE ${label} AND NOT EXISTS (SELECT 1 FROM provenance p WHERE p.release = r.log_index AND p.via = 3)",
			(r.form, r.column.version, r.column.version_text, plan.provenance_time),
		)
		repo = plan.repo_row
		repos = Sql.stmt(
			"INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) SELECT ?1, ?2, ?3, 0, NULL, ?4, ?4 WHERE NOT EXISTS (SELECT 1 FROM repos WHERE repo = ?1)",
			(repo.repo, repo.repository_id, repo.repository_owner_id, repo.time),
		)
		checks = Sql.stmt(
			"INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) SELECT ?1, NULL, NULL, ?2, 0, 0 WHERE NOT EXISTS (SELECT 1 FROM repo_checks WHERE repo = ?1)",
			(plan.check_row.repo, plan.check_row.next_check_at),
		)
		names.concat(new_targets).append(artifact).concat(deps).concat(artifact_targets).concat([leaf, release, provenance, repos, checks])
	}

	db = D1.binding("DB")

	fault = |e| Fault(Str.inspect(e))

	bad_row : [BadRow(Str)] -> IngestRoutes.Error
	bad_row = |e| match e {
		BadRow(text) => Fault(text)
	}
}
