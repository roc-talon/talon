## Private reference of ShortRoutes (slice 107).
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Cache
import lib.Shorts
import lib.Reads
import ReadRoutes

ShortRoutes :: [].{

	list! : Request => Try(Response, ReadRoutes.Error)
	list! = |req| match Shorts.parse_url(req.url()) {
		Err(Bad(problem)) => Err(Refuse(problem))
		Err(TooMany(count)) => Ok(Response.from_bytes(413, "application/problem+json", Shorts.too_large_json(count).to_utf8()))
		Ok(Short(values)) => {
			json = Json.to_str(values.map(|v| v.with_ascii_lowercased()))
			serve!(req, Shorts.short_cache_control, Sql.stmt(short_sql, [json]), |result| short_answer(values, result))
		}
		Ok(Search(text)) => serve!(req, Shorts.search_cache_control, Sql.stmt(search_sql, Sql.none), |result| search_answer(result, text))
	}

	short_answer : List(Str), D1.Result -> Try(Str, ReadRoutes.Error)
	short_answer = |values, result| {
		rows : List(Shorts.Row)
		rows = result.all().map_err(|e| Fault(Str.inspect(e)))?
		entries = Shorts.entries_of(values, rows).map_err(bad_row)?
		Ok(Shorts.matches_body(entries))
	}

	search_answer : D1.Result, Str -> Try(Str, ReadRoutes.Error)
	search_answer = |result, text| {
		rows : List(Shorts.SearchRow)
		rows = result.all().map_err(|e| Fault(Str.inspect(e)))?
		Shorts.search_body(text, rows).map_err(bad_row)
	}

	bad_row : [BadRow(Str)] -> ReadRoutes.Error
	bad_row = |e| match e {
		BadRow(text) => Fault(text)
	}

	serve! : Request, Str, Sql.Stmt, (D1.Result -> Try(Str, ReadRoutes.Error)) => Try(Response, ReadRoutes.Error)
	serve! = |req, cache_control, stmt, build| {
		key = req.url()
		bypass = Reads.bypass_cache({ cache_control: req.header("cache-control"), pragma: req.header("pragma") })
		if_none_match = req.header("if-none-match")
		match (if (bypass) Err(Miss) else Cache.default.get!(key).map_err(|_| Miss)) {
			Ok(hit) => Ok(answer_hit(hit, if_none_match, cache_control))
			Err(_) => {
				session = db.with_session!(Reads.session_of(req.header("talon-bookmark"))).map_err(|e| Fault(Str.inspect(e)))?
				results = session.batch!([stmt]).map_err(|e| Fault(Str.inspect(e)))?
				result = match results {
					[one] => Ok(one)
					_ => Err(Fault("the batch gave ${U64.to_str(results.len())} results, not 1"))
				}?
				body = build(result)?
				bytes = body.to_utf8()
				etag = Reads.etag_of(bytes)
				res = Response.from_bytes(200, "application/json", bytes).with_header("cache-control", cache_control).with_header("etag", etag)
				sent = Cache.default.put!(key, res) ?? res
				Ok(if (matches(if_none_match, etag)) not_modified(etag, cache_control) else sent)
			}
		}
	}

	answer_hit : Response, Try(Str, [NotFound]), Str -> Response
	answer_hit = |hit, if_none_match, cache_control| match hit.header("etag") {
		Ok(etag) => if (matches(if_none_match, etag)) not_modified(etag, cache_control) else hit
		Err(NotFound) => hit
	}

	matches : Try(Str, [NotFound]), Str -> Bool
	matches = |if_none_match, etag| match if_none_match {
		Ok(text) => Reads.etag_matches(text, etag)
		Err(NotFound) => Bool.False
	}

	not_modified : Str, Str -> Response
	not_modified = |etag, cache_control| Response.from_status(304).with_header("etag", etag).with_header("cache-control", cache_control)

	db = D1.binding("DB")

	## R-AP41 row 2: the shorts go as one JSON parameter. The candidates are the indexed names whose repo part, or the repo part minus `roc-`, is a value; then the successor chains (R-AP41 row 1).
	short_sql : Str
	short_sql = "WITH RECURSIVE want(v) AS (SELECT lower(value) FROM json_each(?1)), hit(repo) AS (SELECT n.id FROM names n JOIN repos p ON p.repo = n.id WHERE n.kind = 3 AND EXISTS (SELECT 1 FROM releases r WHERE r.repo = n.id) AND EXISTS (SELECT 1 FROM want w WHERE w.v = substr(n.value, instr(n.value, '/') + 1) OR (substr(substr(n.value, instr(n.value, '/') + 1), 1, 4) = 'roc-' AND length(substr(n.value, instr(n.value, '/') + 1)) > 4 AND w.v = substr(substr(n.value, instr(n.value, '/') + 1), 5)))), chain(repo, depth) AS (SELECT repo, 0 FROM hit UNION SELECT p.successor, c.depth + 1 FROM chain c JOIN repos p ON p.repo = c.repo WHERE p.state = 2 AND p.successor IS NOT NULL AND c.depth < 5) SELECT rn.value AS name, p.state AS state, sn.value AS successor, (SELECT min(r.log_index) FROM releases r WHERE r.repo = p.repo) AS first_log_index FROM (SELECT DISTINCT repo FROM chain) c JOIN repos p ON p.repo = c.repo JOIN names rn ON rn.id = p.repo LEFT JOIN names sn ON sn.id = p.successor ORDER BY rn.value"

	search_sql : Str
	search_sql = "SELECT n.value AS name, p.state AS state, (SELECT min(r.log_index) FROM releases r WHERE r.repo = n.id) AS first_log_index FROM names n JOIN repos p ON p.repo = n.id WHERE n.kind = 3 AND EXISTS (SELECT 1 FROM releases r WHERE r.repo = n.id) ORDER BY n.value"
}
