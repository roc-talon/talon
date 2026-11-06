## The pure part of `POST /v1/closure` (Registry 4.1: R-AP3, R-AP16, R-AP17, R-AP18, R-AP28, R-AP41 rows 2 and 4, R-AP46, R-AP48, R-AP51; slice 110).
## No effect, no platform import. The effects (the body read, the one D1 batch, the clock) are in `worker/ClosureRoute.roc`.
## The SQL is in `worker/sql/closure/*.sql` (the code agent writes it). The W1 cases `sql/tests/cases/closure/` run the same files.
## The tests are `worker/tests/unit/ClosureQueryTest.roc` (W0) and `worker/tests/cases/closure/` (W2). The slice file is `docs/slices/110-closure.md`.
## The `detail` texts are proposals for the human review (TW24): the slice file section 6.
import records.Closure
import records.Code
import records.Id
import semver.VersionReq
import semver.Semver
import Version
import records.Release
import Problem
import Reads

ClosureQuery :: [].{

	body_limit : U64
	body_limit = 262_144

	group_limit : U64
	group_limit = 300

	hash_limit : U64
	hash_limit = 1_000

	cache_control : Str
	cache_control = "no-store"

	Filter : { group : Str, series : Try(Str, [None]), range : Try(Str, [None]) }

	Query : {
		groups_json : Str,
		hashes_json : Str,
		from : Try(I64, [None]),
		to : Try(I64, [None]),
		hash_texts : List(Str),
		filters : List(ClosureQuery.Filter),
	}

	Reject : [Bad(Problem), TooLarge(Problem, { field : Str, limit : U64 })]

	too_large : Str, U64 -> ClosureQuery.Reject
	too_large = |field, limit| TooLarge(Problem.new(TooLarge, "the ${field} of the closure request is larger than its limit of ${U64.to_str(limit)}"), { field, limit })

	bad : Str -> ClosureQuery.Reject
	bad = |detail| Bad(Problem.new(BadRequest, detail))

	parse : List(U8) -> Try(ClosureQuery.Query, ClosureQuery.Reject)
	parse = |body| {
		if body.len() > body_limit {
			return Err(too_large("body", body_limit))
		}
		text = Str.from_utf8(body).map_err(|_| bad("the closure request body is not UTF-8"))?
		req = Closure.decode_request(text).map_err(
			|e| match e {
				BadJson(t) => bad("the closure request body is not valid: ${t}")
			},
		)?
		if req.groups.len() > group_limit {
			return Err(too_large("groups", group_limit))
		}
		if req.hashes.len() > hash_limit {
			return Err(too_large("hashes", hash_limit))
		}
		items = req.groups.map_try(group_item)?
		ids = req.hashes.keep_oks(|h| Reads.artifact_id(h))
		window = match req.compilers {
			Ok(w) => { from: tag_id(w.from)?, to: tag_id(w.to)? }
			Err(None) => { from: Err(None), to: Err(None) }
		}
		Ok({
			groups_json: "[${Str.join_with(items, ",")}]",
			hashes_json: "[${Str.join_with(ids.map(I64.to_str), ",")}]",
			from: window.from,
			to: window.to,
			hash_texts: req.hashes,
			filters: req.groups.map(|g| { group: g.group, series: g.series, range: g.range }),
		})
	}

	tag_id : Try(Str, [None]) -> Try(Try(I64, [None]), ClosureQuery.Reject)
	tag_id = |end| match end {
		Err(None) => Ok(Err(None))
		Ok(tag) => match Id.nightly_id(tag) {
			Ok(id) => Ok(Ok(id))
			Err(_) => Ok(Err(None))
		}
	}

	group_item : Closure.GroupQuery -> Try(Str, ClosureQuery.Reject)
	group_item = |g| {
		s = match g.series {
			Ok(series) => Ok(Version.series_bounds(series).map_err(|_| bad("the series ${series} of the group ${g.group} is not a series (M or 0.m)"))?)
			Err(None) => Err(None)
		}
		r = match g.range {
			Ok(range) => Ok(Version.range_bounds(VersionReq.parse(range).map_err(|_| bad("the range ${range} of the group ${g.group} is not a version range"))?))
			Err(None) => Err(None)
		}
		lo = I64.max(end_of(s, |b| b.lo, I64.lowest), end_of(r, |b| b.lo, I64.lowest))
		hi = I64.min(end_of(s, |b| b.hi, I64.highest), end_of(r, |b| b.hi, I64.highest))
		Ok("{\"form\":${I64.to_str(Reads.form_id(g.group))},\"lo\":${I64.to_str(lo)},\"hi\":${I64.to_str(hi)}}")
	}

	end_of : Try(Version.Bounds, [None]), (Version.Bounds -> Str), I64 -> I64
	end_of = |bounds, pick, default| match bounds {
		Ok(b) => I64.from_str(pick(b)) ?? default
		Err(None) => default
	}

	keep_release : ClosureQuery.Query, Release.Row -> Bool
	keep_release = |query, release| query.hash_texts.contains(release.hash) or query.filters.all(
		|f| if f.group != release.group {
			Bool.True
		} else {
			series_ok = match f.series {
				Ok(s) => s == release.series
				Err(None) => Bool.True
			}
			range_ok = match f.range {
				Ok(text) => match (VersionReq.parse(text), Semver.parse(release.version)) {
					(Ok(req), Ok(v)) => req.matches(v)
					_ => Bool.False
				}
				Err(None) => Bool.True
			}
			series_ok and range_ok
		},
	)

	unknown_of : ClosureQuery.Query, List(U64) -> List(Str)
	unknown_of = |query, idx| {
		var $k = 0
		var $out = []
		for text in query.hash_texts {
			is_unknown = match Reads.artifact_id(text) {
				Err(_) => Bool.True
				Ok(_) => {
					hit = idx.contains($k)
					$k = $k + 1
					hit
				}
			}
			if is_unknown and !$out.contains(text) {
				$out = $out.append(text)
			}
		}
		$out
	}

	DepRow : { owner : List(U8), alias : Str, hash : List(U8), form : Try(Str, [Missing]), version : Try(Str, [Missing]), version_text : Try(Str, [Missing]), url : Str }

	TargetRow : { owner : List(U8), name : Str }

	UnknownRow : { idx : U64 }

	RunRow : { hash : List(U8), target : Str, source : I64, result : I64, error_digest : Try(Str, [Missing]), from : Str, to : Str }

	NearestRow : { hash : List(U8), target : Str, source : I64, result : I64, error_digest : Try(Str, [Missing]), nightly : Str, side : Str }

	HintRow : { hash : List(U8), nightly : Str, target : Str, pass_count : U64, fail_count : U64, crash_count : U64 }

	Rows : {
		artifacts : List(Reads.ArtifactRow),
		deps : List(ClosureQuery.DepRow),
		target_rows : List(ClosureQuery.TargetRow),
		releases : List(Reads.ReleaseRow),
		unknown : List(ClosureQuery.UnknownRow),
		epochs : List(Closure.Epoch),
		runs : List(ClosureQuery.RunRow),
		nearest : List(ClosureQuery.NearestRow),
		hints : List(ClosureQuery.HintRow),
		checked : List(Reads.CheckRow),
		repos : List(Reads.RepoRow),
		log_size : U64,
	}

	source_of : I64 -> Try(Code.Source, [BadRow(Str)])
	source_of = |c| match c {
		0 => Ok(Bot)
		1 => Ok(Author)
		_ => Err(BadRow("the source code ${I64.to_str(c)} is not known"))
	}

	result_of : I64 -> Try(Code.Result, [BadRow(Str)])
	result_of = |c| match c {
		0 => Ok(Pass)
		1 => Ok(Fail)
		2 => Ok(Hang)
		3 => Ok(Crash)
		_ => Err(BadRow("the result code ${I64.to_str(c)} is not known"))
	}

	answer : ClosureQuery.Query, ClosureQuery.Rows, U64 -> Try(Str, [BadRow(Str)])
	answer = |query, rows, now_ms| {
		artifacts = rows.artifacts.map_try(
			|a| Reads.artifact_of_rows({
				artifact: a,
				deps: rows.deps.keep_if(|d| d.owner == a.hash).map(|d| { alias: d.alias, hash: d.hash, form: d.form, version: d.version, version_text: d.version_text, url: d.url }),
				target_names: rows.target_rows.keep_if(|t| t.owner == a.hash).map(|t| t.name),
			}),
		)?
		releases = rows.releases.map_try(Reads.release_of_row)?.keep_if(|r| keep_release(query, r))
		runs = rows.runs.map_try(
			|r| Ok({ hash: Reads.base58_of_bytes(r.hash)?, target: r.target, source: source_of(r.source)?, result: result_of(r.result)?, error_digest: r.error_digest.map_err(|_| None), from: r.from, to: r.to }),
		)?
		nearest = rows.nearest.map_try(
			|n| {
				side = match n.side {
					"before" => Ok(Before)
					"after" => Ok(After)
					other => Err(BadRow("the side ${other} is not known"))
				}?
				Ok({ hash: Reads.base58_of_bytes(n.hash)?, target: n.target, source: source_of(n.source)?, result: result_of(n.result)?, error_digest: n.error_digest.map_err(|_| None), nightly: n.nightly, side })
			},
		)?
		hints = rows.hints.map_try(|h| Ok({ hash: Reads.base58_of_bytes(h.hash)?, nightly: h.nightly, target: h.target, pass_count: h.pass_count, fail_count: h.fail_count, crash_count: h.crash_count }))?
		repos = rows.repos.map_try(Reads.repo_item_of_row)?
		ans : Closure.Answer
		ans = {
			artifacts,
			releases,
			epochs: rows.epochs,
			runs,
			nearest,
			hints,
			log_size: rows.log_size,
			unknown: unknown_of(query, rows.unknown.map(|u| u.idx)),
			checked: rows.checked.map(|c| Reads.checked_of_row(c, now_ms)),
			repos,
		}
		Ok(Closure.encode_answer(ans))
	}
}
