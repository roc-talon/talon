## REFERENCE (private) of worker/lib/Compat.roc, slice 115a.
import records.Code
import records.Id
import ClosureQuery
import Nullable
import Problem
import Reads

Compat :: [].{

	body_limit : U64
	body_limit = 262_144

	row_limit : U64
	row_limit = 500

	missing_limit : U64
	missing_limit = 100

	Row : { hash : Str, artifact : I64, nightly : I64, target : Str, result : Code.Result, error_digest : Try(Str, [None]) }

	Sweep : { tag : Str, nightly : I64, upto_log_index : U64 }

	Post : { rows : List(Compat.Row), sweep : Try(Compat.Sweep, [None]) }

	Reject : ClosureQuery.Reject

	too_large : Str, U64 -> Compat.Reject
	too_large = |field, limit| TooLarge(Problem.new(TooLarge, "the ${field} of the compat request is larger than its limit of ${limit.to_str()}"), { field, limit })

	RowWire : { hash : Str, nightly : Str, target : Str, result : Str, error_digest : Nullable(Str), source : Try(Nullable(Str), [Missing]) }
	SweepWire : { nightly : Str, target : Str, upto_log_index : U64 }
	PostWire : { rows : List(Compat.RowWire), sweep : Try(Nullable(Compat.SweepWire), [Missing]), source : Try(Nullable(Str), [Missing]) }

	bad : Str -> Compat.Reject
	bad = |detail| Bad(Problem.new(BadRequest, detail))

	parse_post : List(U8) -> Try(Compat.Post, Compat.Reject)
	parse_post = |body| {
		if body.len() > body_limit {
			return Err(too_large("body", body_limit))
		}
		text = Str.from_utf8(body).map_err(|_| bad("the compat request body is not valid: it is not UTF-8"))?
		parsed : Try(Compat.PostWire, _)
		parsed = Json.parse(text)
		wire = parsed.map_err(|e| bad("the compat request body is not valid: ${Str.inspect(e)}"))?
		if wire.source.is_ok() {
			return Err(bad("the compat request body is not valid: it has a member source (the Worker sets the source from the token, R-MX5)"))
		}
		if wire.rows.any(|r| r.source.is_ok()) {
			return Err(bad("the compat request body is not valid: a row has a member source (the Worker sets the source from the token, R-MX5)"))
		}
		if wire.rows.len() > row_limit {
			return Err(too_large("rows", row_limit))
		}
		rows = wire.rows.map_try(row_of)?
		sweep = match Nullable.read_opt(wire.sweep) {
			Ok(s) => Ok(sweep_of(s)?)
			Err(None) => Err(None)
		}
		Ok({ rows, sweep })
	}

	row_of : Compat.RowWire -> Try(Compat.Row, Compat.Reject)
	row_of = |w| {
		artifact = Reads.artifact_id(w.hash).map_err(|_| bad("the compat request body is not valid: the hash ${w.hash} is not a hash (base58 of 32 bytes)"))?
		nightly = Id.nightly_id(w.nightly).map_err(|_| bad("the compat request body is not valid: the nightly ${w.nightly} is not a nightly tag"))?
		result = Code.result_from_str(w.result).map_err(|_| bad("the compat request body is not valid: the result ${w.result} is not pass, fail, hang or crash"))?
		Ok({ hash: w.hash, artifact, nightly, target: w.target, result, error_digest: Nullable.read(w.error_digest) })
	}

	sweep_of : Compat.SweepWire -> Try(Compat.Sweep, Compat.Reject)
	sweep_of = |w| {
		if w.target != "any" {
			return Err(bad("the compat request body is not valid: the target of a sweep must be any, got ${w.target}"))
		}
		nightly = Id.nightly_id(w.nightly).map_err(|_| bad("the compat request body is not valid: the sweep nightly ${w.nightly} is not a nightly tag"))?
		if w.upto_log_index > Reads.max_after {
			return Err(bad("the compat request body is not valid: the sweep upto_log_index is larger than 2^63 - 1"))
		}
		Ok({ tag: w.nightly, nightly, upto_log_index: w.upto_log_index })
	}

	read_params : Compat.Post -> { artifacts_json : Str, targets_json : Str }
	read_params = |post| {
		var $ids = []
		var $names = []
		for r in post.rows {
			if !$ids.contains(r.artifact) {
				$ids = $ids.append(r.artifact)
			}
			if r.target != "any" and !$names.contains(r.target) {
				$names = $names.append(r.target)
			}
		}
		{ artifacts_json: "[${Str.join_with($ids.map(I64.to_str), ",")}]", targets_json: "[${Str.join_with($names.map(|n| Json.to_str(n)), ",")}]" }
	}

	ArtifactFact : { artifact : I64, kind : I64 }

	TargetFact : { name : Str, target : I64 }

	PlatformFact : { artifact : I64, target : I64 }

	Facts : { artifacts : List(Compat.ArtifactFact), target_rows : List(Compat.TargetFact), platform_targets : List(Compat.PlatformFact) }

	PlanRow : { artifact : I64, nightly : I64, target : I64, result : U8, error_digest : Try(Str, [None]) }

	plan : Compat.Post, Compat.Facts -> Try(List(Compat.PlanRow), Problem)
	plan = |post, facts| post.rows.map_try(|r| plan_row(r, facts))

	plan_row : Compat.Row, Compat.Facts -> Try(Compat.PlanRow, Problem)
	plan_row = |r, facts| {
		fact = match facts.artifacts.find_first(|a| a.artifact == r.artifact) {
			Ok(a) => a
			Err(_) => return Err(Reads.no_artifact(r.hash))
		}
		code = target_code(r, fact, facts)?
		Ok({ artifact: r.artifact, nightly: r.nightly, target: code, result: Code.result_code(r.result), error_digest: r.error_digest })
	}

	target_code : Compat.Row, Compat.ArtifactFact, Compat.Facts -> Try(I64, Problem)
	target_code = |r, fact, facts| {
		if r.target == "any" {
			return Ok(0)
		}
		if fact.kind != 2 {
			return Err(Problem.new(BadRequest, "the row for ${r.hash} has the target ${r.target}, but only a platform has a smoke build on a target"))
		}
		named = match facts.target_rows.find_first(|t| t.name == r.target) {
			Ok(t) => t
			Err(_) => return Err(Problem.new(BadRequest, "the target ${r.target} has no code"))
		}
		if facts.platform_targets.any(|p| p.artifact == r.artifact and p.target == named.target) {
			Ok(named.target)
		} else {
			Err(Problem.new(BadRequest, "the target ${r.target} is not a target of the platform ${r.hash}"))
		}
	}

	rows_json : List(Compat.PlanRow) -> Str
	rows_json = |rows| {
		items = rows.map(
			|r| {
				digest = match r.error_digest {
					Ok(d) => Json.to_str(d)
					Err(None) => "null"
				}
				"{\"a\":${r.artifact.to_str()},\"n\":${r.nightly.to_str()},\"t\":${r.target.to_str()},\"r\":${r.result.to_str()},\"d\":${digest}}"
			},
		)
		"[${Str.join_with(items, ",")}]"
	}

	rows_sql : () -> Str
	rows_sql = || "INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) SELECT j.value ->> '$.a', j.value ->> '$.n', j.value ->> '$.t', 0, j.value ->> '$.r', j.value ->> '$.d', ?2, NULL FROM json_each(?1) j WHERE true ON CONFLICT DO NOTHING"

	sweep_sql : () -> Str
	sweep_sql = || "INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, ?4) ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time WHERE excluded.upto_log_index > sweeps.upto_log_index"

	written_status : U64 -> U16
	written_status = |written| if (written > 0) 201 else 200

	written_body : U64 -> Str
	written_body = |written| "{\"written\":${written.to_str()}}"

	Constraint : { kind : [PrimaryKey, Unique, ForeignKey, Check, NotNull, Trigger, Datatype, Other], message : Str }

	failure_of : Compat.Constraint -> [SweepIncomplete, Bad(Problem), Fault(Str)]
	failure_of = |c| match c {
		{ kind: Trigger, message: "sweep-incomplete" } => SweepIncomplete
		{ kind: Trigger, message: "sweep-bound" } => Bad(Problem.new(BadRequest, "the sweep upto_log_index is larger than the log size"))
		_ => Fault("the write batch failed: ${Str.inspect(c)}")
	}

	sweep_incomplete : { tag : Str, upto_log_index : U64, missing : List(Str) } -> Problem
	sweep_incomplete = |x| {
		k = x.missing.len()
		shown = x.missing.take_first(missing_limit)
		list = Str.join_with(shown, ", ")
		tail = if (k > missing_limit) ", and ${(k - missing_limit).to_str()} more" else ""
		if k == 0 {
			Problem.new(SweepIncomplete, "the sweep of ${x.tag} up to the log index ${x.upto_log_index.to_str()} was incomplete, but no member has no bot row now: send the request again")
		} else {
			Problem.new(SweepIncomplete, "the sweep of ${x.tag} up to the log index ${x.upto_log_index.to_str()} is incomplete: ${k.to_str()} members of the bot set have no bot row: ${list}${tail}")
		}
	}

	request_kind : { authorization : Try(Str, [NotFound]), contributor : Try(Str, [NotFound]) } -> [Bot, Hint, Refuse(Problem)]
	request_kind = |h| match (h.authorization, h.contributor) {
		(Ok(_), _) => Bot
		(Err(NotFound), Ok(_)) => Hint
		(Err(NotFound), Err(NotFound)) => Refuse(Problem.new(BadRequest, "POST /v1/compat needs an Authorization header (the compat bot) or a Talon-Contributor header (a user hint)"))
	}
}
