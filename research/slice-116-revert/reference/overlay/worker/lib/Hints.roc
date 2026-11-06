## REFERENCE (private) of worker/lib/Hints.roc, slice 116a.
import records.Code
import records.Id
import semver.Semver
import Compat
import Problem
import Reads
import Nullable

Hints :: [].{

	unknown_version : I64
	unknown_version = 0

	tags_url : Str
	tags_url = "https://api.github.com/repos/roc-talon/talon/tags?per_page=100"

	Row : { hash : Str, artifact : I64, nightly : I64, target : Str, result : Code.Result }

	Post : { talon_version : Str, rows : List(Hints.Row) }

	machine_id : Str -> Try(Str, Problem)
	machine_id = |id| {
		bytes = id.to_utf8()
		ok = bytes.len() == 32 and bytes.all(|b| (b >= '0' and b <= '9') or (b >= 'a' and b <= 'f'))
		if ok Ok(id) else Err(Problem.new(BadRequest, "the header Talon-Contributor must be 32 characters, each one of 0 to 9 and a to f"))
	}

	RowWire : { hash : Str, nightly : Str, target : Str, result : Str, error_digest : Try(Nullable(Str), [Missing]), source : Try(Nullable(Str), [Missing]) }
	PostWire : { talon_version : Str, rows : List(Hints.RowWire), source : Try(Nullable(Str), [Missing]), sweep : Try(Nullable(Str), [Missing]) }

	bad : Str -> Compat.Reject
	bad = |detail| Bad(Problem.new(BadRequest, detail))

	parse : List(U8) -> Try(Hints.Post, Compat.Reject)
	parse = |body| {
		if body.len() > Compat.body_limit {
			return Err(Compat.too_large("body", Compat.body_limit))
		}
		text = Str.from_utf8(body).map_err(|_| bad("the hint request body is not valid: it is not UTF-8"))?
		parsed : Try(Hints.PostWire, _)
		parsed = Json.parse(text)
		wire = parsed.map_err(|e| bad("the hint request body is not valid: ${Str.inspect(e)}"))?
		if wire.source.is_ok() {
			return Err(bad("the hint request body is not valid: member source is not allowed"))
		}
		if wire.sweep.is_ok() {
			return Err(bad("the hint request body is not valid: member sweep is for the compat bot"))
		}
		if wire.rows.any(|r| r.source.is_ok()) {
			return Err(bad("the hint request body is not valid: member source is not allowed in a row"))
		}
		if wire.rows.any(|r| r.error_digest.is_ok()) {
			return Err(bad("the hint request body is not valid: member error_digest is not allowed in a row"))
		}
		if wire.rows.len() > Compat.row_limit {
			return Err(Compat.too_large("rows", Compat.row_limit))
		}
		rows = wire.rows.map_try(row_of)?
		Ok({ talon_version: wire.talon_version, rows })
	}

	row_of : Hints.RowWire -> Try(Hints.Row, Compat.Reject)
	row_of = |r| {
		artifact = Reads.artifact_id(r.hash).map_err(|_| bad("the hash ${r.hash} of a row is not a base58 hash of 32 bytes"))?
		nightly = Id.nightly_id(r.nightly).map_err(|_| bad("the nightly ${r.nightly} of a row is not a nightly tag"))?
		result = match Code.result_from_str(r.result) {
			Ok(Hang) => Err(bad("the result hang of a row is not a hint"))
			Ok(found) => Ok(found)
			Err(_) => Err(bad("the result ${r.result} of a row is not pass, fail or crash"))
		}?
		Ok({ hash: r.hash, artifact, nightly, target: r.target, result })
	}

	read_params : Hints.Post -> { artifacts_json : Str, targets_json : Str }
	read_params = |post| {
		ids = post.rows.fold([], |acc, r| if (acc.contains(r.artifact)) acc else acc.append(r.artifact))
		names = post.rows.fold([], |acc, r| if (r.target == "any" or acc.contains(r.target)) acc else acc.append(r.target))
		{
			artifacts_json: "[${Str.join_with(ids.map(I64.to_str), ",")}]",
			targets_json: "[${Str.join_with(names.map(|n| Json.to_str(n)), ",")}]",
		}
	}

	Sent : { index : U64, artifact : I64, nightly : I64, target : Try(I64, [NoCode]), result : U8 }

	check : Hints.Post, Compat.Facts -> Try(List(Hints.Sent), Problem)
	check = |post, facts| {
		post.rows.map_with_index(|r, index| check_row(r, index, facts)).map_try(|x| x)
	}

	check_row : Hints.Row, U64, Compat.Facts -> Try(Hints.Sent, Problem)
	check_row = |r, index, facts| {
		target = target_code(r, facts)?
		Ok({ index, artifact: r.artifact, nightly: r.nightly, target, result: Code.result_code(r.result) })
	}

	target_code : Hints.Row, Compat.Facts -> Try(Try(I64, [NoCode]), Problem)
	target_code = |r, facts| {
		if r.target == "any" {
			return Ok(Ok(0))
		}
		kind = match facts.artifacts.find_first(|a| a.artifact == r.artifact) {
			Ok(a) => a.kind
			Err(_) => -1
		}
		code = match facts.target_rows.find_first(|t| t.name == r.target) {
			Ok(t) => Ok(t.target)
			Err(_) => Err(NoCode)
		}
		if kind == -1 {
			Ok(code)
		} else if kind == 1 {
			Err(Problem.new(BadRequest, "the target ${r.target} is not valid for a hint: the artifact ${r.hash} is a package"))
		} else if kind == 2 {
			match code {
				Ok(c) => if (facts.platform_targets.any(|p| p.artifact == r.artifact and p.target == c)) Ok(Ok(c)) else Err(Problem.new(BadRequest, "the platform ${r.hash} does not build the target ${r.target}"))
				Err(NoCode) => Ok(Err(NoCode))
			}
		} else {
			Ok(code)
		}
	}

	rows_json : List(Hints.Sent) -> Str
	rows_json = |rows| {
		items = rows.map(
			|r| {
				target = match r.target {
					Ok(c) => c.to_str()
					Err(NoCode) => "null"
				}
				"{\"i\":${r.index.to_str()},\"artifact\":${r.artifact.to_str()},\"nightly\":${r.nightly.to_str()},\"target\":${target},\"result\":${r.result.to_str()}}"
			},
		)
		"[${Str.join_with(items, ",")}]"
	}

	classified : Str
	classified = "WITH r AS (SELECT CAST(json_extract(j.value, '$.i') AS INTEGER) AS i, json_extract(j.value, '$.artifact') AS artifact, json_extract(j.value, '$.nightly') AS nightly, json_extract(j.value, '$.target') AS target, json_extract(j.value, '$.result') AS result FROM json_each(?1) j), c AS (SELECT r.*, CASE WHEN NOT EXISTS (SELECT 1 FROM artifacts a WHERE a.artifact = r.artifact) THEN 'unknown-hash' WHEN NOT EXISTS (SELECT 1 FROM toolchains t WHERE t.nightly = r.nightly) THEN 'unknown-nightly' WHEN r.target IS NULL THEN 'unknown-target' WHEN EXISTS (SELECT 1 FROM compat k WHERE k.artifact = r.artifact AND k.nightly = r.nightly AND k.target = r.target AND k.source = 0) THEN 'bot-row' WHEN (SELECT MIN(t.published_at) FROM toolchains t WHERE t.nightly = r.nightly) < ?2 - 31536000000 THEN 'old-nightly' END AS reason FROM r) "

	first_sql : () -> Str
	first_sql = || "${classified}SELECT COUNT(*) AS first FROM (SELECT DISTINCT c.artifact, c.nightly, c.target FROM c WHERE c.reason IS NULL AND NOT EXISTS (SELECT 1 FROM compat k WHERE k.artifact = c.artifact AND k.nightly = c.nightly AND k.target = c.target) AND NOT EXISTS (SELECT 1 FROM compat_hints h WHERE h.artifact = c.artifact AND h.nightly = c.nightly AND h.target = c.target))"

	skipped_sql : () -> Str
	skipped_sql = || "${classified}SELECT c.i AS row, c.reason AS reason FROM c WHERE c.reason IS NOT NULL ORDER BY c.i"

	insert_sql : () -> Str
	insert_sql = || "${classified}INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) SELECT COALESCE((SELECT l.contributor FROM links l WHERE l.machine = ?3), ?3), c.artifact, c.nightly, c.target, c.result, ?4, ?2 FROM c WHERE c.reason IS NULL ORDER BY c.i ON CONFLICT (contributor, artifact, nightly, target) DO NOTHING RETURNING CAST(artifact AS TEXT) AS artifact"

	hmac_message : Str -> List(U8)
	hmac_message = |machine| machine.to_utf8()

	contributor_id : List(U8) -> I64
	contributor_id = |mac| {
		n = mac.take_first(8).fold(0.U64, |acc, b| acc.shl_wrap(8).bitwise_or(b.to_u64()))
		missing = 8 - U64.min(mac.len(), 8)
		padded = n.shl_wrap((missing * 8).to_u8_wrap())
		padded.bitwise_or(0x8000000000000000).to_i64_wrap()
	}

	talon_key : { version : Str, tags : List(Str) } -> I64
	talon_key = |x| {
		if x.tags.contains("v${x.version}") {
			match Semver.parse(x.version) {
				Ok(v) => v.to_key().key.to_i64_wrap()
				Err(_) => 0
			}
		} else {
			0
		}
	}

	tag_names : Str -> Try(List(Str), [BadTags])
	tag_names = |text| {
		parsed : Try(List({ name : Str }), _)
		parsed = Json.parse(text)
		parsed.map_ok(|items| items.map(|i| i.name)).map_err(|_| BadTags)
	}

	Skipped : { row : U64, reason : Str }

	answer_body : { written : U64, first : U64, skipped : List(Hints.Skipped) } -> Str
	answer_body = |x| {
		items = x.skipped.map(|s| "{\"row\":${s.row.to_str()},\"reason\":${Json.to_str(s.reason)}}")
		"{\"written\":${x.written.to_str()},\"first\":${x.first.to_str()},\"skipped\":[${Str.join_with(items, ",")}]}"
	}

	failure_of : Compat.Constraint -> [Quota, Fault(Str)]
	failure_of = |c| match (c.kind, c.message) {
		(Trigger, "hint-quota") => Quota
		_ => Fault(c.message)
	}

	retry_after : U64 -> U64
	retry_after = |now_ms| {
		left = 86_400_000 - now_ms % 86_400_000
		(left + 999) // 1000
	}

	quota_problem : () -> Problem
	quota_problem = || Problem.new(RateLimited, "the daily limit of user hints is used up: send the rows again after the next UTC day starts")
}
