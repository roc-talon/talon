## PRIVATE REFERENCE of slice 106 (test agent). The code agent does not read it (TW18).
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Cache
import pf.Time
import lib.Problem
import lib.Reads
import lib.Version

ReadRoutes :: [].{

	Error : [Refuse(Problem), Fault(Str)]

	db = D1.binding("DB")

	fault = |e| Fault(Str.inspect(e))

	release_cols : Str
	release_cols = "r.log_index AS log_index, a.value AS hash, f.value AS form, CAST(r.version AS TEXT) AS version, r.version_text AS version_text, r.url AS url, r.tag AS tag, r.roc_version AS roc_version, rp.value AS repo, r.published_at AS published_at, r.yanked AS yanked, r.withdrawn AS withdrawn"

	release_from : Str
	release_from = "FROM releases r JOIN names a ON a.id = r.artifact JOIN names f ON f.id = r.form LEFT JOIN names rp ON rp.id = r.repo"

	repos_sql : Str -> Str
	repos_sql = |sub| "SELECT n.value AS name, p.state AS state, s.value AS successor, p.state_at AS state_at FROM repos p JOIN names n ON n.id = p.repo LEFT JOIN names s ON s.id = p.successor WHERE p.repo IN (${sub})"

	checked_sql : Str -> Str
	checked_sql = |sub| "SELECT n.value AS name, c.checked_at AS checked_at, c.app_installed AS app_installed FROM repo_checks c JOIN names n ON n.id = c.repo WHERE c.repo IN (${sub})"

	read_rows! : Request, List(Sql.Stmt) => Try(List(D1.Result), ReadRoutes.Error)
	read_rows! = |req, stmts| {
		session = db.with_session!(Reads.session_of(req.header("talon-bookmark"))).map_err(fault)?
		session.batch!(stmts).map_err(fault)
	}

	# The shared flow: cache, one D1 call, the body, the ETag, the 304.
	serve! : Request, (() => Try(Str, ReadRoutes.Error)) => Try(Response, ReadRoutes.Error)
	serve! = |req, load!| {
		key = req.url()
		bypass = Reads.bypass_cache({ cache_control: req.header("cache-control"), pragma: req.header("pragma") })
		cached = if (bypass) Err(NotFound) else Cache.default.get!(key)
		answer = match cached {
			Ok(res) => res
			Err(NotFound) => {
				body = load!()?
				fresh = Response.from_bytes(200, "application/json", body.to_utf8()).with_header("cache-control", Reads.cache_control).with_header("etag", Reads.etag_of(body.to_utf8()))
				Cache.default.put!(key, fresh).map_err(fault)?
			}
			Err(e) => return Err(fault(e))
		}
		etag = answer.header("etag") ?? ""
		match req.header("if-none-match") {
			Ok(inm) if Reads.etag_matches(inm, etag) => Ok(Response.from_status(304).with_header("etag", etag).with_header("cache-control", Reads.cache_control))
			_ => Ok(answer)
		}
	}

	releases_of : List(Reads.ReleaseRow) -> Try(List(_), ReadRoutes.Error)
	releases_of = |rows| rows.map_try(Reads.release_of_row).map_err(fault)

	repo_items : List(Reads.RepoRow) -> Try(List(Reads.RepoItem), ReadRoutes.Error)
	repo_items = |rows| rows.map_try(Reads.repo_item_of_row).map_err(fault)

	repo_releases! : Request, Str, Str => Try(Response, ReadRoutes.Error)
	repo_releases! = |req, owner, repo| {
		id = Reads.repo_id(owner, repo)
		serve!(
			req,
			|| {
				rs = read_rows!(
					req,
					[
						Sql.stmt("SELECT ${release_cols} ${release_from} WHERE r.repo = ? ORDER BY r.log_index", [id]),
						Sql.stmt(repos_sql("SELECT ?"), [id]),
						Sql.stmt(checked_sql("SELECT ?"), [id]),
					],
				)?
				match rs {
					[a, b, c] => {
						rel_rows : List(Reads.ReleaseRow)
						rel_rows = a.all().map_err(fault)?
						repo_rows : List(Reads.RepoRow)
						repo_rows = b.all().map_err(fault)?
						chk_rows : List(Reads.CheckRow)
						chk_rows = c.all().map_err(fault)?
						if rel_rows.is_empty() {
							Err(Refuse(Reads.no_repo_releases(owner, repo)))
						} else {
							now = Time.now_ms!()
							Ok(Reads.releases_body({ releases: releases_of(rel_rows)?, checked: checked_of(chk_rows, now), repos: repo_items(repo_rows)? }))
						}
					}
					_ => Err(Fault("batch shape"))
				}
			},
		)
	}

	checked_of : List(Reads.CheckRow), U64 -> Try(Reads.CheckedItem, [None])
	checked_of = |rows, now| match rows {
		[row, ..] => Ok(Reads.checked_of_row(row, now))
		[] => Err(None)
	}

	artifact! : Request, Str => Try(Response, ReadRoutes.Error)
	artifact! = |req, hash| {
		id = Reads.artifact_id(hash).map_err(|_| Refuse(Reads.no_artifact(hash)))?
		serve!(
			req,
			|| {
				rs = read_rows!(
					req,
					[
						Sql.stmt("SELECT a.value AS hash, x.kind AS kind, x.exposes AS exposed_json, pl.value AS platform_hash, x.roc_pin AS roc_pin, x.size AS size FROM artifacts x JOIN names a ON a.id = x.artifact LEFT JOIN names pl ON pl.id = x.platform WHERE x.artifact = ?", [id]),
						Sql.stmt("SELECT d.alias AS alias, dn.value AS hash, f.value AS form, CAST(d.version AS TEXT) AS version, d.version_text AS version_text, d.url AS url FROM deps d JOIN names dn ON dn.id = d.dep LEFT JOIN names f ON f.id = d.form WHERE d.artifact = ?", [id]),
						Sql.stmt("SELECT t.name AS name FROM artifact_targets at JOIN targets t ON t.target = at.target WHERE at.artifact = ?", [id]),
						Sql.stmt("SELECT ${release_cols} ${release_from} WHERE r.artifact = ? ORDER BY r.log_index", [id]),
						Sql.stmt(repos_sql("SELECT DISTINCT repo FROM releases WHERE artifact = ? AND repo IS NOT NULL"), [id]),
					],
				)?
				match rs {
					[a, d, t, r, p] => {
						art_rows : List(Reads.ArtifactRow)
						art_rows = a.all().map_err(fault)?
						dep_rows : List(Reads.DepRow)
						dep_rows = d.all().map_err(fault)?
						target_rows : List({ name : Str })
						target_rows = t.all().map_err(fault)?
						rel_rows : List(Reads.ReleaseRow)
						rel_rows = r.all().map_err(fault)?
						repo_rows : List(Reads.RepoRow)
						repo_rows = p.all().map_err(fault)?
						match art_rows {
							[art, ..] => {
								artifact = Reads.artifact_of_rows({ artifact: art, deps: dep_rows, target_names: target_rows.map(|x| x.name) }).map_err(fault)?
								Ok(Reads.artifact_body({ artifact, releases: releases_of(rel_rows)?, repos: repo_items(repo_rows)? }))
							}
							[] => Err(Refuse(Reads.no_artifact(hash)))
						}
					}
					_ => Err(Fault("batch shape"))
				}
			},
		)
	}

	releases! : Request => Try(Response, ReadRoutes.Error)
	releases! = |req| {
		query = Reads.parse_query({ group: req.query("group"), series: req.query("series"), after: req.query("after") }).map_err(|p| Refuse(p))?
		serve!(
			req,
			|| match query {
				ByAfter(after) => {
					page = "SELECT log_index FROM releases WHERE log_index > ? ORDER BY log_index LIMIT ${Reads.page_limit.to_str()}"
					rs = read_rows!(
						req,
						[
							Sql.stmt("SELECT ${release_cols} ${release_from} WHERE r.log_index IN (${page}) ORDER BY r.log_index", [after.to_i64_wrap()]),
							Sql.stmt(repos_sql("SELECT DISTINCT repo FROM releases WHERE log_index IN (${page}) AND repo IS NOT NULL"), [after.to_i64_wrap()]),
						],
					)?
					match rs {
						[a, b] => {
							rel_rows : List(Reads.ReleaseRow)
							rel_rows = a.all().map_err(fault)?
							repo_rows : List(Reads.RepoRow)
							repo_rows = b.all().map_err(fault)?
							Ok(Reads.page_body({ releases: releases_of(rel_rows)?, repos: repo_items(repo_rows)? }))
						}
						_ => Err(Fault("batch shape"))
					}
				}
				ByGroup({ group, series, after }) => {
					fid = Reads.form_id(group)
					bounds = match series {
						Ok(s) => Version.series_bounds(s) ?? { lo: "-9223372036854775808", hi: "9223372036854775807" }
						Err(_) => { lo: "-9223372036854775808", hi: "9223372036854775807" }
					}
					filter = "form = ?1 AND version BETWEEN CAST(?2 AS INTEGER) AND CAST(?3 AS INTEGER) AND log_index > ?4"
					limit = match after {
						Ok(_) => Reads.page_limit.to_i64_wrap()
						Err(_) => -1
					}
					params = (fid, bounds.lo, bounds.hi, after.map_ok(|n| n.to_i64_wrap()) ?? 0)
					rs = read_rows!(
						req,
						[
							Sql.stmt("SELECT ${release_cols} ${release_from} WHERE r.form = ?1 AND r.version BETWEEN CAST(?2 AS INTEGER) AND CAST(?3 AS INTEGER) AND r.log_index > ?4 ORDER BY r.log_index LIMIT ${limit.to_str()}", params),
							Sql.stmt(repos_sql("SELECT DISTINCT repo FROM releases WHERE ${filter} AND repo IS NOT NULL"), params),
							Sql.stmt(checked_sql("SELECT DISTINCT repo FROM releases WHERE ${filter} AND repo IS NOT NULL"), params),
						],
					)?
					match rs {
						[a, b, c] => {
							rel_rows : List(Reads.ReleaseRow)
							rel_rows = a.all().map_err(fault)?
							repo_rows : List(Reads.RepoRow)
							repo_rows = b.all().map_err(fault)?
							chk_rows : List(Reads.CheckRow)
							chk_rows = c.all().map_err(fault)?
							now = Time.now_ms!()
							releases = releases_of(rel_rows)?.keep_if(|r| series.map_ok(|s| s == r.series) ?? Bool.True)
							Ok(Reads.releases_body({ releases, checked: checked_of(chk_rows, now), repos: repo_items(repo_rows)? }))
						}
						_ => Err(Fault("batch shape"))
					}
				}
			},
		)
	}
}
