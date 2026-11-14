## The handlers of the yank routes `PUT /v1/releases/{log_index}/yank` and `DELETE /v1/releases/{log_index}/yank` (Registry 7.2: R-YK1, R-YK2, R-YK4, R-YK6, R-YK7; 7.1: R-TP3, R-TP8, R-TP9, R-TP12;
## 4: R-AP41, R-AP45, R-AP48, R-AP69; 5: R-RE10; slice 246, `docs/slices/246-yank.md`). The decisions are in `lib/Yank.roc` (pure, W0). This module only orders the effects. The tests are W2: `worker/tests/cases/yank/`.
## `Err(Refuse(problem))` is a problem answer, `Err(Fault(text))` is 500 `internal` (R-AP48, never a `crash`).
##
## Flow (the order of the slice file section 3.1; the first check that fails gives the answer):
## 1. `PUT` only: `req.bytes_with!({ max_bytes: 262144 })` (R-AP46), `Yank.parse_body`. No D1 call, no JWKS read, no read of a secret before this step is done. `DELETE`: no body is read.
## 2. The caller: `Oidc.bearer` of the `Authorization` header (`NoToken`: 401 `Oidc.missing_token`; `Refuse(problem)`: 401). The setting `OPERATOR_KEY` (a secret; a missing one is 500 `internal`, question Q246-6).
##    A token text equal to `OPERATOR_KEY` (a constant-time compare, question Q246-5) is `Operator`: no JWKS read. Any other token is `Auth.verify!` (R-TP3 rows 1 to 3: 401, 502, 500) and the caller is `Author`.
## 3. `db.with_session!(Primary)`. D1 call 1, one `batch!`: the release by `log_index` (the record of R-AP49 with the `yank_reason`, the repository name, the group, the series, the hash), the `repos` row of its repository,
##    and the `by` of the last `yank` row. No release (a leaf of a compiler, an index that is not in the log): 404 `Yank.no_release`.
## 4. `Author` only: `Yank.check_token` (403), `Publish.claims_ids` (403), `Yank.binding` (403 `repository-changed` with `issues_url`: the setting `ISSUES_URL`). No more D1 call.
## 5. `Yank.decide`. `Refuse(problem)`: the answer. `NoChange`: 200 with the record of the pre-read, no write, no cache drop.
## 6. `Change`: D1 call 2, one `batch!`: `UPDATE releases SET yanked`, the row of `yanks` (R-YK4: `seq` = the largest `seq` of the release plus 1, `action`, `by`, `claims` (the text of `Publish.claims_json` for `Author`, NULL for `Operator`),
##    `reason` (`Yank` only, NULL for none), `time`), and last the read of the release. Each statement has the condition on the state that the pre-read saw (R-AP41 row 3): a request that lost a race changes nothing and gives the answer of the state it finds.
## 7. The answer: 200, `content-type: application/json`, `cache-control: no-store`, `Wire.encode_answer`, `talon-bookmark`. After a `Change`: the cache drop of R-YK7 and R-AP69 (`Response.after`).
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Time
import pf.Cache
import pf.Env
import pf.Log
import records.Release
import records.Yank as Wire
import lib.Identity
import lib.IngestLimits
import lib.Problem
import lib.Publish
import lib.Reads
import lib.Yank
import Auth
import IngestRoutes
import ReadRoutes

YankRoutes :: [].{

	## `PUT /v1/releases/{log_index}/yank`. `index` is the path segment.
	put! : Request, Str => Try(Response, IngestRoutes.Error)
	put! = |req, index| {
		bytes = match req.bytes_with!({ max_bytes: IngestRoutes.body_limit }) {
			Ok(b) => b
			Err(TooLarge) => return Ok(IngestRoutes.too_large)
			# Q246-2: a `PUT` with no body is a yank with no reason.
			Err(BodyErr(_)) => []
		}
		put = if bytes.is_empty() {
			{ reason: Err(None) }
		} else {
			Yank.parse_body(bytes).map_err(|p| Refuse(p))?
		}
		run!(req, index, Yank, put.reason)
	}

	## `DELETE /v1/releases/{log_index}/yank`. The body of a `DELETE` is not read (Q246-2).
	delete! : Request, Str => Try(Response, IngestRoutes.Error)
	delete! = |req, index| run!(req, index, Unyank, Err(None))

	## The caller of steps 2 and 3 of the flow, then steps 3 to 7.
	run! : Request, Str, Yank.Action, Try(Str, [None]) => Try(Response, IngestRoutes.Error)
	run! = |req, index, action, reason| {
		caller = Auth.yank!(req).map_err(|p| Refuse(p))?
		# Q246-7: a text that is not a log index is no release: 404 with no D1 call.
		log_index = match Reads.after_value(index) {
			Ok(n) => n
			Err(_) => return Err(Refuse(Yank.no_release(index)))
		}
		session = IngestRoutes.db.with_session!(Primary).map_err(IngestRoutes.fault)?
		page = "WITH page AS (SELECT * FROM releases WHERE log_index = ?1)"
		id = log_index.to_i64_wrap()
		first = session.batch!([
			Sql.stmt(ReadRoutes.releases_sql(page), [id]),
			Sql.stmt(ReadRoutes.reasons_sql(page), [id]),
			Sql.stmt(by_sql, [id]),
			Sql.stmt(repo_sql, [id]),
		]).map_err(IngestRoutes.fault)?
		pre = pre_read(first, index)?
		role = match caller {
			Operator => Operator
			Author(claims) => {
				Yank.check_token(claims, pre.repository).map_err(|p| Refuse(p))?
				seen = Publish.claims_ids(claims).map_err(|p| Refuse(p))?
				match Yank.binding(seen, pre.ids) {
					Ok({}) => Author
					Err(Changed) => return Ok(changed!(pre, seen))
				}
			}
		}
		state = if (pre.release.yanked) Yanked(pre.by) else Live
		match Yank.decide(action, role, state) {
			Refuse(problem) => Err(Refuse(problem))
			NoChange => answer!(session, pre.release)
			Change => {
				claims_text = match caller {
					Operator => Err(None)
					Author(claims) => Ok(Publish.claims_json(claims))
				}
				write!(session, req, { id, action, role, reason, claims_text, old: pre.release.yanked, release: pre.release })
			}
		}
	}

	## What the first batch gives: the release record (with its reason), the `by` of its last yank, the name and ids of its repository.
	PreRead : { release : Release.Row, by : Yank.Caller, repository : Try(Str, [NoRepo]), ids : Try(Identity.Ids, [NoRow]) }

	pre_read : List(D1.Result), Str -> Try(YankRoutes.PreRead, IngestRoutes.Error)
	pre_read = |results, index| match results {
		[rel, why, by, repo] => {
			found = ReadRoutes.releases_of(rel, why)?
			release = match found {
				[one, ..] => one
				[] => return Err(Refuse(Yank.no_release(index)))
			}
			bys : List({ by_code : U64 })
			bys = by.all().map_err(IngestRoutes.fault)?
			by_who = match bys {
				[last, ..] => if (last.by_code == 1) Operator else Author
				[] => if (release.yanked) return Err(Fault("release ${index} is yanked and has no row in yanks")) else Author
			}
			repos : List({ repository_id : U64, repository_owner_id : U64 })
			repos = repo.all().map_err(IngestRoutes.fault)?
			ids = match repos {
				[row, ..] => Ok({ repository_id: row.repository_id, owner_id: row.repository_owner_id })
				[] => Err(NoRow)
			}
			Ok({ release, by: by_who, repository: release.repo.map_err(|_| NoRepo), ids })
		}
		_ => Err(Fault("yank: the first batch gave ${results.len().to_str()} results, not 4"))
	}

	by_sql : Str
	by_sql = "SELECT y.\"by\" AS by_code FROM yanks y WHERE y.release = ?1 ORDER BY y.seq DESC LIMIT 1"

	repo_sql : Str
	repo_sql = "SELECT p.repository_id AS repository_id, p.repository_owner_id AS repository_owner_id FROM repos p WHERE p.repo = (SELECT repo FROM releases WHERE log_index = ?1)"

	## R-TP3 row 5, R-TP12: both ids are not the ids of the `repos` row. 403 `repository-changed` with `issues_url`. The bound id is the one of the row.
	changed! : YankRoutes.PreRead, Identity.Ids => Response
	changed! = |pre, seen| {
		bound = match pre.ids {
			Ok(row) => row.repository_id
			Err(NoRow) => seen.repository_id
		}
		name = pre.release.repo ?? ""
		issues_url = Env.var!("ISSUES_URL") ?? ""
		body = Identity.changed_json(Identity.changed(name, bound), issues_url)
		Response.from_bytes(403, "application/problem+json", body.to_utf8())
	}

	## Step 6: D1 call 2, one batch. Statement 1 changes `yanked` when it is still the old value. Statement 2 adds the row of `yanks` only when statement 1 changed a row (`changes()`),
	## so a request that lost a race changes nothing (R-AP41 row 3). Then the read of the answer (the release, then its reason). The answer is the state that the batch finds.
	Write : { id : I64, action : Yank.Action, role : Yank.Caller, reason : Try(Str, [None]), claims_text : Try(Str, [None]), old : Bool, release : Release.Row }

	write! : D1.Session, Request, YankRoutes.Write => Try(Response, IngestRoutes.Error)
	write! = |session, req, w| {
		now = Time.now_ms!()
		new_yanked = match w.action {
			Yank => 1.I64
			Unyank => 0.I64
		}
		old_yanked = if (w.old) 1.I64 else 0.I64
		page = "WITH page AS (SELECT * FROM releases WHERE log_index = ?1)"
		update = Sql.stmt("UPDATE releases SET yanked = ?2 WHERE log_index = ?1 AND yanked = ?3", (w.id, new_yanked, old_yanked))
		insert = Sql.stmt(
			"INSERT INTO yanks (release, seq, action, \"by\", claims, reason, time) SELECT ?1, COALESCE((SELECT MAX(seq) FROM yanks WHERE release = ?1), 0) + 1, ?2, ?3, ?4, ?5, ?6 WHERE changes() > 0",
			(w.id, Yank.action_code(w.action), Yank.by_code(w.role), Sql.or_null(w.claims_text), Sql.or_null(w.reason), now),
		)
		results = session.batch!(
			[update, insert, Sql.stmt(ReadRoutes.releases_sql(page), [w.id]), Sql.stmt(ReadRoutes.reasons_sql(page), [w.id])],
		).map_err(IngestRoutes.fault)?
		found = match results {
			[_, _, rel, why] => ReadRoutes.releases_of(rel, why)?
			_ => return Err(Fault("yank: the write batch gave ${results.len().to_str()} results, not 4"))
		}
		release = match found {
			[one, ..] => one
			[] => return Err(Fault("the release is not found after the yank"))
		}
		dropping(answer!(session, release), req, release)
	}

	## The answer 200 (step 7): the release record in `{"release": ...}`, `no-store`, the bookmark of the session after its last call (R-AP41 row 5), also for a 200 that changed nothing.
	answer! : D1.Session, Release.Row => Try(Response, IngestRoutes.Error)
	answer! = |session, release| {
		base = Response.from_bytes(200, "application/json", Wire.encode_answer(release).to_utf8()).with_header("cache-control", "no-store")
		Ok(
			match session.bookmark!() {
				Ok(bookmark) => base.with_header("talon-bookmark", bookmark)
				Err(NotFound) => base
			},
		)
	}

	## R-YK7, R-AP69: after a change, the 4 keys of the release are dropped after the answer (`Response.after`). A release on another host has no repository key.
	dropping : Try(Response, IngestRoutes.Error), Request, Release.Row -> Try(Response, IngestRoutes.Error)
	dropping = |result, req, release| result.map_ok(
		|res| {
			name = release.repo ?? ""
			all = IngestLimits.drop_keys({ origin: IngestRoutes.origin_of(req.url()), group: release.group, series: release.series, name, hash: release.hash })
			keys = if (name == "") all.keep_if(|key| !key.contains("/v1/packages//releases")) else all
			work! = || {
				for key in keys {
					match Cache.default.delete!(key) {
						Ok({}) | Err(NotFound) => {}
						Err(e) => Log.warn!("cache drop failed", { key, error: Str.inspect(e) })
					}
				}
				Ok({})
			}
			res.after(work!)
		},
	)
}
