## PRIVATE REFERENCE of slice 246 (not for the code agent, TW18). Bodies for worker/YankRoutes.roc.
import pf.Request
import pf.Response
import pf.Sql
import pf.Time
import pf.Cache
import pf.Env
import pf.Log
import records.Release
import lib.Identity
import lib.IngestLimits
import lib.Oidc
import lib.Problem
import lib.Publish
import lib.Reads
import lib.Yank
import Auth
import IngestRoutes

YankRoutes :: [].{

	put! : Request, Str => Try(Response, IngestRoutes.Error)
	put! = |req, index| run!(req, index, Yank)

	delete! : Request, Str => Try(Response, IngestRoutes.Error)
	delete! = |req, index| run!(req, index, Unyank)

	read_sql : Str
	read_sql = "SELECT r.log_index AS log_index, an.value AS hash, fn.value AS form, CAST(r.version AS TEXT) AS version, r.version_text AS version_text, r.url AS url, r.tag AS tag, r.roc_version AS roc_version, rn.value AS repo, r.published_at AS published_at, r.yanked AS yanked, r.withdrawn AS withdrawn, (SELECT group_concat(via) FROM (SELECT via FROM provenance WHERE release = r.log_index ORDER BY via)) AS vias FROM releases r JOIN names an ON an.id = r.artifact JOIN names fn ON fn.id = r.form LEFT JOIN names rn ON rn.id = r.repo WHERE r.log_index = ?1"

	repo_sql : Str
	repo_sql = "SELECT repository_id, repository_owner_id FROM repos WHERE repo = (SELECT repo FROM releases WHERE log_index = ?1)"

	last_sql : Str
	last_sql = "SELECT by AS yank_by, reason AS yank_reason FROM yanks WHERE release = ?1 ORDER BY seq DESC LIMIT 1"

	RepoRow : { repository_id : U64, repository_owner_id : U64 }
	LastRow : { yank_by : I64, yank_reason : Try(Str, [Missing]) }

	run! : Request, Str, Yank.Action => Try(Response, IngestRoutes.Error)
	run! = |req, index, action| {
		put = match action {
			Yank => {
				bytes = match req.bytes_with!({ max_bytes: IngestRoutes.body_limit }) {
					Ok(b) => b
					Err(TooLarge) => return Ok(IngestRoutes.too_large)
					Err(BodyErr(_)) => []
				}
				Yank.parse_body(bytes).map_err(|p| Refuse(p))?
			}
			Unyank => { reason: Err(None) }
		}
		token = match Oidc.bearer(req.header("authorization")) {
			Token(text) => text
			NoToken => return Err(Refuse(Oidc.missing_token))
			Refuse(problem) => return Err(Refuse(problem))
		}
		key = Env.var!("OPERATOR_KEY") ?? ""
		is_operator = key != "" and token == key
		claims : Try(Oidc.Claims, [None])
		claims = if is_operator Err(None) else Ok(Auth.verify!(token).map_err(|p| Refuse(p))?)
		caller : Yank.Caller
		caller = if is_operator Operator else Author
		log_index = match U64.from_str(index) {
			Ok(n) => n
			Err(_) => return Err(Refuse(Yank.no_release(index)))
		}
		session = IngestRoutes.db.with_session!(Primary).map_err(IngestRoutes.fault)?
		first = session.batch!([Sql.stmt(read_sql, [log_index]), Sql.stmt(repo_sql, [log_index]), Sql.stmt(last_sql, [log_index])]).map_err(IngestRoutes.fault)?
		release_rows : Try(List(Reads.ReleaseRow), _)
		release_rows = first.get(0).map_err(|_| Fault("no release result"))?.all()
		row = match release_rows.map_err(IngestRoutes.fault)? {
			[r, ..] => r
			[] => return Err(Refuse(Yank.no_release(index)))
		}
		repo_rows : Try(List(YankRoutes.RepoRow), _)
		repo_rows = first.get(1).map_err(|_| Fault("no repos result"))?.all()
		repo_ids = match repo_rows.map_err(IngestRoutes.fault)? {
			[r, ..] => Ok({ repository_id: r.repository_id, owner_id: r.repository_owner_id })
			[] => Err(NoRow)
		}
		last_rows : Try(List(YankRoutes.LastRow), _)
		last_rows = first.get(2).map_err(|_| Fault("no yanks result"))?.all()
		last = last_rows.map_err(IngestRoutes.fault)?
		state : Yank.State
		state = if row.yanked {
			match last {
				[l, ..] => if (l.yank_by == 1) Yanked(Operator) else Yanked(Author)
				[] => Yanked(Author)
			}
		} else {
			Live
		}
		release = Reads.release_of_row(row).map_err(IngestRoutes.bad_row)?
		reason_now = match last {
			[l, ..] => if row.yanked l.yank_reason.map_err(|_| None) else Err(None)
			[] => Err(None)
		}
		current = { ..release, yank_reason: reason_now }
		match claims {
			Ok(c) => {
				Yank.check_token(c, row.repo.map_err(|_| NoRepo)).map_err(|p| Refuse(p))?
				seen = Publish.claims_ids(c).map_err(|p| Refuse(p))?
				match Yank.binding(seen, repo_ids) {
					Ok({}) => {}
					Err(Changed) => {
						name = row.repo ?? ""
						bound = match repo_ids {
							Ok(ids) => ids.repository_id
							Err(NoRow) => seen.repository_id
						}
						issues_url = Env.var!("ISSUES_URL").map_err(|_| Fault("the setting ISSUES_URL is missing"))?
						body = Identity.changed_json(Identity.changed(name, bound), issues_url)
						return Ok(Response.from_bytes(403, "application/problem+json", body.to_utf8()))
					}
				}
			}
			Err(None) => {}
		}
		match Yank.decide(action, caller, state) {
			Refuse(problem) => Err(Refuse(problem))
			NoChange => IngestRoutes.answer!(session, 200, current)
			Change => {
				now = Time.now_ms!()
				yanking = action == Yank
				new_yanked : U8
				new_yanked = if yanking 1 else 0
				old_yanked : U8
				old_yanked = if yanking 0 else 1
				claims_text = match claims {
					Ok(c) => Ok(Publish.claims_json(c))
					Err(None) => Err(None)
				}
				reason = if yanking put.reason else Err(None)
				update = Sql.stmt("UPDATE releases SET yanked = ?2 WHERE log_index = ?1 AND yanked = ?3", (log_index, new_yanked, old_yanked))
				insert = Sql.stmt(
					"INSERT INTO yanks (release, seq, action, by, claims, reason, time) SELECT ?1, COALESCE((SELECT MAX(seq) FROM yanks WHERE release = ?1), 0) + 1, ?2, ?3, ?4, ?5, ?6 WHERE changes() > 0",
					(log_index, Yank.action_code(action), Yank.by_code(caller), Sql.or_null(claims_text), Sql.or_null(reason), now),
				)
				results = session.batch!([update, insert, Sql.stmt(read_sql, [log_index])]).map_err(IngestRoutes.fault)?
				last_result = results.last().map_err(|_| Fault("the batch gave no result"))?
				after_rows : Try(List(Reads.ReleaseRow), _)
				after_rows = last_result.all()
				after = match after_rows.map_err(IngestRoutes.fault)? {
					[r, ..] => Reads.release_of_row(r).map_err(IngestRoutes.bad_row)?
					[] => return Err(Fault("the release has no row after the write"))
				}
				answered = { ..after, yank_reason: if yanking reason else Err(None) }
				dropping(IngestRoutes.answer!(session, 200, answered), req, answered)
			}
		}
	}

	## R-YK7, R-AP69: the same 4 keys as a publish.
	dropping : Try(Response, IngestRoutes.Error), Request, Release.Row -> Try(Response, IngestRoutes.Error)
	dropping = |result, req, release| result.map_ok(
		|res| {
			keys = IngestLimits.drop_keys({ origin: IngestRoutes.origin_of(req.url()), group: release.group, series: release.series, name: release.repo ?? "", hash: release.hash })
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
