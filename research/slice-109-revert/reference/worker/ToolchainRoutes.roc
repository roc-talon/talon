import pf.Request
import pf.Response
import pf.Http
import pf.D1
import pf.Sql
import pf.Time
import pf.Cache
import lib.Problem
import lib.Toolchains
import records.Id

ToolchainRoutes :: [].{

	Error : [Refuse(Problem), Fault(Str)]

	db = D1.binding("DB")

	rows_sql : Str
	rows_sql = "SELECT tag, target, asset_name, sha256, published_at, log_index FROM toolchains WHERE nightly = ? ORDER BY log_index"

	json_answer : U16, Str -> Response
	json_answer = |status, body| Response.from_bytes(status, "application/json", body.to_utf8()).with_header("cache-control", "no-store")

	put! : Request, Str => Try(Response, ToolchainRoutes.Error)
	put! = |_req, tag| {
		nightly = match Toolchains.start(tag, Id.nightly_id(tag)) {
			Refuse(p) => return Err(Refuse(p))
			ReadRows(id) => id
		}
		known : List(Toolchains.Row)
		known = D1.all!(db, rows_sql, [nightly]) ? |e| Fault(Str.inspect(e))
		match Toolchains.after_rows(tag, known) {
			Refuse(p) => Err(Refuse(p))
			Answer(rows) => Ok(json_answer(200, Toolchains.put_body(rows)))
			ReadGithub => {
				res = Http.send!(Request.get(Toolchains.release_url(tag)).with_header("user-agent", "talon-registry").with_header("accept", "application/vnd.github+json")) ? |_| Refuse(Toolchains.github_no_answer)
				if res.status() == 404 {
					Err(Refuse(Toolchains.no_release(tag)))
				} else if res.status() != 200 {
					Err(Refuse(Toolchains.github_status(res.status())))
				} else {
					text = res.text!() ? |_| Refuse(Toolchains.github_bad)
					release = Toolchains.parse_release(text) ? |_| Refuse(Toolchains.github_bad)
					picked = Toolchains.candidates(tag, release) ? |p| Refuse(p)
					now = Time.now_ms!()
					writes = Toolchains.writes_of({ tag, nightly, published_at: release.published_at, now_ms: now, picked })
					stmts = writes.join_map(|w| [
						Sql.stmt("INSERT INTO log (idx, grp, version, hash, time) SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ? AND target = ?)", (w.leaf.grp, w.leaf.version, w.leaf.hash, w.leaf.time, w.nightly, w.target)),
						Sql.stmt("INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) SELECT ?, ?, ?, ?, ?, ?, (SELECT MAX(idx) FROM log) WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ? AND target = ?)", (w.nightly, w.target, w.tag, w.asset_name, w.sha256, w.published_at, w.nightly, w.target)),
					]).append(Sql.stmt(rows_sql, [nightly]))
					results = D1.batch!(db, stmts) ? |e| Fault(Str.inspect(e))
					last = match results.last() {
						Ok(r) => r
						Err(_) => return Err(Fault("the batch gave no result"))
					}
					changes = results.map_with_index(|r, i| (i, r.info().changes)).keep_if(|(i, _)| i % 2 == 1 and i < results.len() - 1).map(|(_, c)| c)
					rows : List(Toolchains.Row)
					rows = last.all() ? |e| Fault(Str.inspect(e))
					Ok(json_answer(Toolchains.put_status(changes), Toolchains.put_body(rows)))
				}
			}
		}
	}

	etag_of : Str -> Str
	etag_of = |body| "\"${Str.from_utf8(Crypto.SHA256.hash(body.to_utf8()).to_hex().to_utf8().take_first(32)).ok_or("")}\""

	no_cache : Try(Str, [NotFound]) -> Bool
	no_cache = |h| match h {
		Ok(v) => v.split_on(",").any(|dir| dir.trim().caseless_ascii_equals("no-cache"))
		Err(_) => Bool.False
	}

	matches : Str, Str -> Bool
	matches = |inm, etag| if (inm.trim() == "*") Bool.True else inm.split_on(",").any(|piece| {
		t = piece.trim()
		(if (t.starts_with("W/")) t.drop_prefix("W/") else t) == etag
	})

	list! : Request => Try(Response, ToolchainRoutes.Error)
	list! = |req| {
		q = Toolchains.parse_query({ after: req.query("after"), target: req.query("target") }) ? |p| Refuse(p)
		key = req.url()
		bypass = no_cache(req.header("cache-control")) or no_cache(req.header("pragma"))
		cached = if (bypass) Err(NotFound) else Cache.default.get!(key)
		answer = match cached {
			Ok(res) => res
			Err(NotFound) => {
				sql = match q.target {
					Ok(_) => "SELECT tag, target, asset_name, sha256, published_at, log_index FROM toolchains WHERE log_index > ? AND target = ? ORDER BY log_index LIMIT 1001"
					Err(None) => "SELECT tag, target, asset_name, sha256, published_at, log_index FROM toolchains WHERE log_index > ? ORDER BY log_index LIMIT 1001"
				}
				rows : List(Toolchains.Row)
				rows = match q.target {
					Ok(t) => D1.all!(db, sql, (q.after, t)) ? |e| Fault(Str.inspect(e))
					Err(None) => D1.all!(db, sql, [q.after]) ? |e| Fault(Str.inspect(e))
				}
				body = Toolchains.page_body(Toolchains.page_of(rows))
				fresh = Response.from_bytes(200, "application/json", body.to_utf8()).with_header("cache-control", Toolchains.cache_control).with_header("etag", etag_of(body))
				Cache.default.put!(key, fresh) ? |e| Fault(Str.inspect(e))
			}
			Err(e) => return Err(Fault(Str.inspect(e)))
		}
		etag = answer.header("etag") ?? ""
		match req.header("if-none-match") {
			Ok(inm) if matches(inm, etag) => Ok(Response.from_status(304).with_header("etag", etag).with_header("cache-control", Toolchains.cache_control))
			_ => Ok(answer)
		}
	}
}
