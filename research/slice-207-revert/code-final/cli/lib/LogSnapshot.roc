import records.Closure as Wire
import ClosureRequest
import Fail
import Fx
import ClosureIndex
import Registry

## The log snapshot of a registry run (slice 207; Registry 4.1 R-AP16, R-AP19; CLI R-FL9; Resolution 11 R-DT3, R-DT5; Resolution 9 R-SP24).
## `--snapshot log:N` hides each release above N in the closure answer. The printed log size is N, or the `log_size` of the first answer. The second query of a held move gets the first `log_size` as `log:N`.
## The pure functions are L0 (`tests/unit/LogsnapshotTest.roc`). `second!` is command code (L2: `tests/commands/cases/registry/`, the word `closure` with `then-group=`).
LogSnapshot :: [].{

	## R-AP19, Design Q403, Q405: `--snapshot log:N` applied to one closure answer. `keep` are the `hashes` of the request of the command (the header values).
	##
	## | # | Rule |
	## | --- | --- |
	## | 1 | A release row with `log_index` greater than N is removed, unless its `hash` is in `keep` (R-C9, R-AP63: a snapshot never hides the value that the header has now, Q403). A row with `log_index` = N stays. The order of the rows stays. |
	## | 2 | `epochs`, `runs`, `nearest` and `hints` are evidence (R-AP19). `artifacts`, `unknown`, `checked`, `repos` and `log_size` are not changed either (Q405). Only the release rows are hidden. |
	##
	## The toolchain row of the held `roc:` pin (Q403) is kept by the compiler list (`RegistryToolchains.visible`, `ClosureRequest.allowed`): not this function (slice 206b).
	hide_above : Wire.Answer, { n : U64, keep : List(Str) } -> Wire.Answer
	hide_above = |answer, facts| {
		kept = answer.releases.keep_if(|row| row.log_index <= facts.n or facts.keep.contains(row.hash))
		{ ..answer, releases: kept }
	}

	## R-AP16, R-AP19, Design Q404: the N that hides the second answer: the first `log_size`, or the smaller of it and the N of the user's `--snapshot log:N`.
	second_cut : { user : Try(U64, [None]), first : Wire.Answer } -> U64
	second_cut = |facts| match facts.user {
		Ok(n) => if n < facts.first.log_size n else facts.first.log_size
		Err(None) => facts.first.log_size
	}

	## R-DT5: the log size that the command prints (`resolved at log:<n>`) and puts in `snapshot` of `--json`. `snapshot: Ok(N)` (`--snapshot log:N`) gives N, also when N is above `log_size`. `Err(None)` gives the `log_size` of `first`, the first answer of the command (not the second).
	printed : { snapshot : Try(U64, [None]), first : Wire.Answer } -> U64
	printed = |facts| match facts.snapshot {
		Ok(n) => n
		Err(None) => facts.first.log_size
	}

	## R-DT5 (proposal, TW24): the text of a log snapshot, `log:<n>`, as in `resolved at log:184467, 4 probes` (`Report.resolved_line` with this text as `at`) and `"snapshot": "log:184467"` (`Report.data`).
	at_text : U64 -> Str
	at_text = |n| "log:${n.to_str()}"

	## R-AP16 (second query), R-SP24: the body of the second query. `groups` as given (the caller chooses them: only the groups of the movable variables, each with the ranges of a moved variable, R-SP23). `hashes` is empty (the first answer has their records). `compilers` is the one of the first query.
	second_request : { groups : List(ClosureRequest.Group), compilers : Try(Wire.Window, [None]) } -> Wire.Request
	second_request = |facts| { groups: facts.groups, hashes: [], compilers: facts.compilers }

	## R-AP16, R-AP19, R-AP18, R-SP24, R-AP3, R-AP34, R-IX3: the second closure query of a held move. The calls, in order (the L2 case `registry/ap16-second-query` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | The body is `second_request`. The checks, the one `http_send!` (`Post`, `Registry.closure_url`, the same headers, `timeout_s` `ClosureIndex.query_timeout_s`), the errors and the decode are those of `ClosureIndex.query!` (steps 2 to 4 there). No second try. Nothing is written. |
	## | 2 | R-AP18: `ClosureIndex.one_state` on the second answer (against its own `log_size`). |
	## | 3 | R-AP16, Q404: `hide_above` with `n` = `second_cut({ user, first })` and `keep` (the `hashes` of the first request: the second request has none). The second answer shows the state of the first one. |
	##
	## The result is the second answer after step 3. `user` is the N of `--snapshot log:N`, `Err(None)` for none.
	second! : Fx, { origin : Str, version : Str, first : Wire.Answer, compilers : Try(Wire.Window, [None]), groups : List(ClosureRequest.Group), keep : List(Str), user : Try(U64, [None]) } => Try(Wire.Answer, Fail)
	second! = |fx, facts| {
		request = LogSnapshot.second_request({ groups: facts.groups, compilers: facts.compilers })
		body = Wire.encode_request(request)
		ClosureRequest.check({ groups: request.groups.len(), hashes: request.hashes.len(), bytes: body.count_utf8_bytes() })?
		sent = fx.http_send!({ method: Post, url: Registry.closure_url(facts.origin), headers: Registry.headers({ version: facts.version, body: Json }), body, timeout_s: ClosureIndex.query_timeout_s })
		reply = match sent {
			Ok(r) => r
			Err(Timeout) => return Err(Registry.no_answer({ origin: facts.origin, why: "no answer in ${ClosureIndex.query_timeout_s.to_str()} s" }))
			Err(Failed(text)) => return Err(Registry.no_answer({ origin: facts.origin, why: text }))
		}
		if reply.status != 200 {
			return Err(Registry.refuse({ origin: facts.origin, version: facts.version, method: Query, reply: { status: reply.status, body: reply.body } }))
		}
		answer = Registry.closure_answer({ origin: facts.origin, body: reply.body })?
		checked = ClosureIndex.one_state(facts.origin, answer)?
		Ok(LogSnapshot.hide_above(checked, { n: LogSnapshot.second_cut({ user: facts.user, first: facts.first }), keep: facts.keep }))
	}
}
