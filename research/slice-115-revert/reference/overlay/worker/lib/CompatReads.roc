## REFERENCE (private) of worker/lib/CompatReads.roc, slice 115b.
import records.Code
import records.Closure
import ClosureQuery
import Problem
import Reads

CompatReads :: [].{

	audit_limit : U64
	audit_limit = 1000

	cache_control : Str
	cache_control = "max-age=300"

	sweep_cache_control : Str
	sweep_cache_control = "no-store"

	parse_sweep_target : Try(Str, [NotFound]) -> Try({}, Problem)
	parse_sweep_target = |target| match target {
		Err(NotFound) => Ok({})
		Ok("any") => Ok({})
		Ok(other) => Err(Problem.new(BadRequest, "the query parameter target must be any, got ${other}"))
	}

	parse_audit : Try(Str, [NotFound]) -> Try(U64, Problem)
	parse_audit = |audit| match audit {
		Err(NotFound) => Err(Problem.new(BadRequest, "GET /v1/compat_hints needs the query parameter audit"))
		Ok(text) => {
			bytes = text.to_utf8()
			digits = !bytes.is_empty() and bytes.all(|b| b >= '0' and b <= '9')
			plain = bytes.len() == 1 or bytes.first() != Ok('0')
			if digits and plain {
				match U64.from_str(text) {
					Ok(n) => Ok(U64.min(n, audit_limit))
					Err(_) => Ok(audit_limit)
				}
			} else {
				Err(Problem.new(BadRequest, "the query parameter audit must be a count (decimal digits), got ${text}"))
			}
		}
	}

	no_tag : Str -> Problem
	no_tag = |tag| Problem.new(NotFound, "no toolchain for the tag ${tag}")

	SweepRow : { upto_log_index : U64, time : U64 }

	sweep_body : { tag : Str, sweep : Try(CompatReads.SweepRow, [None]), log_size : U64, members : U64, missing : List(Str) } -> Str
	sweep_body = |x| {
		sweep = match x.sweep {
			Ok(s) => Json.to_str({ nightly: x.tag, target: "any", time: s.time, upto_log_index: s.upto_log_index })
			Err(None) => "null"
		}
		"{\"log_size\":${x.log_size.to_str()},\"members\":${x.members.to_str()},\"missing\":${Json.to_str(x.missing)},\"sweep\":${sweep}}"
	}

	PairRow : { hash : List(U8), nightly : Str, target : Str, pass_count : U64, fail_count : U64, crash_count : U64 }

	pairs_body : List(CompatReads.PairRow) -> Try(Str, [BadRow(Str)])
	pairs_body = |rows| {
		items = rows.map_try(
			|r| {
				hash = Reads.base58_of_bytes(r.hash)?
				Ok(Json.to_str({ crash_count: r.crash_count, fail_count: r.fail_count, hash, nightly: r.nightly, pass_count: r.pass_count, target: r.target }))
			},
		)?
		Ok("{\"pairs\":[${Str.join_with(items, ",")}]}")
	}

	compat_body : { runs : List(ClosureQuery.RunRow), hints : List(ClosureQuery.HintRow) } -> Try(Str, [BadRow(Str)])
	compat_body = |x| {
		runs = x.runs.map_try(run_item)?
		hints = x.hints.map_try(
			|h| {
				hash = Reads.base58_of_bytes(h.hash)?
				Ok(Json.to_str({ crash_count: h.crash_count, fail_count: h.fail_count, hash, nightly: h.nightly, pass_count: h.pass_count, target: h.target }))
			},
		)?
		Ok("{\"hints\":[${Str.join_with(hints, ",")}],\"runs\":[${Str.join_with(runs, ",")}]}")
	}

	run_item : ClosureQuery.RunRow -> Try(Str, [BadRow(Str)])
	run_item = |r| {
		hash = Reads.base58_of_bytes(r.hash)?
		source = match r.source {
			0 => "bot"
			1 => "author"
			other => return Err(BadRow("the source code ${other.to_str()} is not known"))
		}
		result = match r.result {
			0 => "pass"
			1 => "fail"
			2 => "hang"
			3 => "crash"
			other => return Err(BadRow("the result code ${other.to_str()} is not known"))
		}
		digest = match r.error_digest {
			Ok(d) => Json.to_str(d)
			Err(Missing) => "null"
		}
		Ok("{\"error_digest\":${digest},\"from\":${Json.to_str(r.from)},\"hash\":${Json.to_str(hash)},\"result\":\"${result}\",\"source\":\"${source}\",\"target\":${Json.to_str(r.target)},\"to\":${Json.to_str(r.to)}}")
	}
}
