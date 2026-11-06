import records.Closure as Wire
import records.Compat
import Compiler
import PinOrder
import ProbeShow
import Registry
import Db
import Fail
import JsonDoc
import Nightlies
import QueueSend
import ShareQueue

## `tln probe --share`, part A (slice 217; Resolution 4 R-PB6; CLI 1 R-SH2, R-SH3, R-RG4; CLI 3 R-E6). Pure decisions. The command code is `ProbeShareFlow`.
## Reuse: the filters are `ShareQueue.admit` (no second copy of the 6 filters), the request is `QueueSend.request`, the totals are `QueueSend.totals`, the failures are `Registry.refuse` and `Registry.no_answer`.
##
## `rows` calls `ShareQueue.admit` for each stored fact of the hash with `sharing` = `{ share: Ok(true), registry: Url(origin), offline: false, env: [] }` (the flag is the consent: R-SH2 conditions 1, 4 and 5 do not stop it),
## `origin: Probed` (filter 1 is the one filter that `--share` does not apply: the facts of `compat.db` are not a probe of this command), and `probe`:
##
## | Stored fact | `Fact.probe` | Reason |
## | --- | --- | --- |
## | `closure` is empty (a unit check: R-P4) | `Unit` | R-SH3 filter 2 |
## | `closure` is not empty (the build of an app or of a platform) | `AppBuild` | filter 2 stops it (the smoke table is slice 218, not read here) |
##
## `compiler.recorded` is true when the nightly id is in `recorded` (the caller reads it: question Q2). `machine_error` is false (a stored fact has no error text).
ProbeShare :: [].{

	## What `rows` reads. `facts`: all stored rows of `hash` (`Db.Query` `FactsOf`). `recorded`: the compiler ids that have a recorded sha256 (R-CV6). `answers`, `headers`, `domain`: as the input of `ShareQueue.admit`. `queued_at` is the time text of the rows.
	Input : { hash : Str, facts : List(Db.Fact), recorded : List(Str), answers : List(Wire.Answer), headers : List({ hash : Str, kind : [Package, Platform, App], names : List(Str) }), domain : List(Nightlies.Release), talon_version : Str, queued_at : Str }

	## A stored fact that is not sent, and the first false filter (the `Why` of `ShareQueue.admit`).
	KeptBack : { nightly : Str, target : Str, why : ShareQueue.Why }

	## The facts of `hash` that go out, as the rows of the hint request (`talon_version` and `queued_at` as given), and the facts that stay back. Both lists are sorted by `nightly` (text order, so the oldest tag first), then `target`, then `closure`
	## (a proposal, TW24: the order of the request body and of the output lines).
	Plan : { rows : List(Db.Queued), kept_back : List(ProbeShare.KeptBack) }

	## R-PB6, R-SH3 (filters 2 to 7): which stored facts are sent. See the table above. The only fact that is dropped for a reason that is not a filter is a fact of another hash (a caller fault): it is ignored.
	## `Hang` stops at filter 6 (`Result`). A `fail` is sent (`machine_error` is false).
	rows : ProbeShare.Input -> ProbeShare.Plan
	rows = |input| {
		mine = input.facts.keep_if(|f| f.hash == input.hash).sort_with(order)
		sharing = { share: Ok(Bool.True), registry: Url("probe-share"), offline: Bool.False, env: [] }
		decided = mine.map(
			|f| {
				recorded = input.recorded.any(|id| PinOrder.same_id(id, f.nightly))
				fact = { origin: Probed, probe: if f.closure.is_empty() Unit else AppBuild, compiler: { id: f.nightly, recorded }, hash: f.hash, target: f.target, outcome: f.outcome, machine_error: Bool.False }
				# Q503: the local filters (2, 3, 6) decide first; the answer filters (4, 5, 7) apply only to the facts that pass them.
				decision = match local_why(f, recorded) {
					Err(why) => Skip(why)
					Ok(_) => ShareQueue.admit({ sharing, fact, answers: input.answers, headers: input.headers, domain: input.domain, talon_version: input.talon_version, queued_at: input.queued_at })
				}
				(f, decision)
			},
		)
		{
			rows: decided.keep_oks(
				|(_, d)| match d {
					Queue(row) => Ok(row)
					Skip(_) => Err(Gone)
				},
			),
			kept_back: decided.keep_oks(
				|(f, d)| match d {
					Skip(why) => Ok({ nightly: f.nightly, target: f.target, why })
					Queue(_) => Err(Gone)
				},
			),
		}
	}

	## R-PB6 (4), Design Q498: the most requests of one `--share` (20 of 500 rows: 10,000 rows, the cap of the queue).
	max_requests : U64
	max_requests = 20

	## R-PB6 (4), R-AP10: the rows in batches of at most `QueueSend.batch_rows` (500), in order, at most `max_requests` batches in `send`. The rows past them are `unsent` (listed as not shared). No row: no batch, nothing unsent.
	batches : List(Db.Queued) -> { send : List(List(Db.Queued)), unsent : List(Db.Queued) }
	batches = |list| {
		cut = ProbeShare.max_requests * QueueSend.batch_rows
		{ send: list.chunks_of(QueueSend.batch_rows).take_first(ProbeShare.max_requests), unsent: list.drop_first(cut) }
	}

	## R-PB6 (3), Design Q491: the body of the one `POST /v1/closure` of `--share`: `groups` empty, `hashes` the one hash, `compilers` from the oldest to the newest nightly (text order of the tag) of the facts that can be sent without the answer:
	## a unit check (empty `closure`), not a `Hang`, the compiler a nightly (`Compiler.kind`) that is in `recorded`. No such fact: `compilers` is `Err(None)` (no member). The facts of other hashes are ignored.
	closure_request : { hash : Str, facts : List(Db.Fact), recorded : List(Str) } -> { groups : List({ group : Str, series : Try(Str, [None]), range : Try(Str, [None]) }), hashes : List(Str), compilers : Try({ from : Try(Str, [None]), to : Try(Str, [None]) }, [None]) }
	closure_request = |input| {
		ids = input.facts
			.keep_if(|f| f.hash == input.hash and f.closure.is_empty() and f.outcome != Hang and Compiler.kind(f.nightly) == Nightly and input.recorded.any(|id| PinOrder.same_id(id, f.nightly)))
			.map(|f| f.nightly)
			.sort_with(|a, b| text_order(a, b))
		compilers = match (ids.first(), ids.last()) {
			(Ok(from), Ok(to)) => Ok({ from: Ok(from), to: Ok(to) })
			_ => Err(None)
		}
		{ groups: [], hashes: [input.hash], compilers }
	}

	## R-PB6 (4), Q498: kind `Network` (exit 15) for the cap: rows are `unsent` and no request failed. `tln probe --share sent <requests> requests and stopped: <count> facts are not shared. Run it again to send the rest.` (a proposal, TW24)
	unfinished : { requests : U64, count : U64 } -> Fail
	unfinished = |facts| Fail.new(Network, "tln probe --share sent ${facts.requests.to_str()} requests and stopped: ${facts.count.to_str()} facts are not shared. Run it again to send the rest.")

	## R-PB6 (1), Design Q494: kind `Network` (exit 15) for `--offline`: `tln probe --share needs the network: --offline sends no request`
	offline : {} -> Fail
	offline = |_none| Fail.new(Network, "tln probe --share needs the network: --offline sends no request")

	## What the answers of the requests added: the sum over the requests. `requests` is the number of requests that got a 200 or 201 answer, `skipped` is the number of rows in the `skipped` members.
	Shared : { requests : U64, sent : U64, counted : U64, first : U64, skipped : U64 }

	## R-E6, R-AP51, R-AP10: what one answer of one request is. `count` is the number of rows of the request.
	##
	## | Answer | Result |
	## | --- | --- |
	## | 200 or 201, body decodes as `Compat.HintAnswer` | `Ok({ sent: count, counted: written, first, skipped: <number of skipped items> })` |
	## | 200 or 201, body does not decode (R-AP51) | `Err`, kind `Network` (15) |
	## | any other status | `Err(Registry.refuse(...))` with the method `Post`: 400 and 413 are `Internal` (1), 401 403 404 409 422 are `Rejected` (20), 429 and 5xx are `Network` (15), a body that is not problem details is `Network` |
	## | a 2xx other than 200 and 201, a 3xx | `Err`, kind `Network` (15) (R-E6 "each other case") |
	## | `Timeout`, `Failed(_)` | `Err(Registry.no_answer(...))`, kind `Network` (15): `why` is `no answer in 20 s` for `Timeout`, the text for `Failed` |
	answer : { origin : Str, version : Str, count : U64, reply : QueueSend.Reply } -> Try({ sent : U64, counted : U64, first : U64, skipped : U64 }, Fail)
	answer = |facts| match facts.reply {
		Err(Timeout) => Err(Registry.no_answer({ origin: facts.origin, why: "no answer in 20 s" }))
		Err(Failed(why)) => Err(Registry.no_answer({ origin: facts.origin, why }))
		Ok(reply) => if reply.status == 200 or reply.status == 201 {
			match Compat.decode_hint_answer(reply.body) {
				Ok(done) => Ok({ sent: facts.count, counted: done.written, first: done.first, skipped: done.skipped.len() })
				Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${facts.origin} to the facts is not a hint answer (${why})"))
			}
		} else {
			Err(Registry.refuse({ origin: facts.origin, version: facts.version, method: Post, reply: { status: reply.status, body: reply.body }, retry_after: Registry.retry_after_of(reply.headers) }))
		}
	}

	## R-PB6, R-SH10 (the same text as `ShareAccount.direct_text`): kind `Usage` (exit 2): `tln probe --share needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.`
	direct : {} -> Fail
	direct = |_none| Fail.new(Usage, "tln probe --share needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.")

	## R-PB6: kind `Usage` (exit 2) for `--share` with no operand: `tln probe --share needs a header alias: the project file has no hash`
	no_hash : {} -> Fail
	no_hash = |_none| Fail.new(Usage, "tln probe --share needs a header alias: the project file has no hash")

	## R-PB6: kind `Usage` (exit 2) for `--share` with a bundle file: `tln probe --share needs a header alias: a bundle file can be a hash before its release`
	bundle : {} -> Fail
	bundle = |_none| Fail.new(Usage, "tln probe --share needs a header alias: a bundle file can be a hash before its release")

	## R-PB6, R-OUT2 (proposal, TW24): the lines on stdout, each with a line end. `label` is `<name> <version>` (the label of `ProbeCmd.text`). With 1 fact `fact`, else `facts`:
	## 0. `nothing to share\n` instead of line 1 when `shared.requests` is 0 and `unsent` is empty (R-PB6 (5), Design Q495).
	## 1. `shared <sent> fact(s) of <label>: <counted> counted, <skipped> skipped by the registry`
	## 2. for each of `kept_back`, in order, then for each of `unsent` (after the kept back, in order: `  not shared: <nightly> <target>: not sent`, R-PB6 (4)): `  not shared: <nightly> <target>: <reason>`. The reasons: `Off(_)` and `NotProbed` do not occur; `Kind` `not a unit check`, `Compiler` `the compiler has no recorded sha256 or is not a nightly`,
	##    `NotInAnswer` `the hash is not in an answer of the registry`, `BotRow` `the registry has a bot result for it`, `Result` `a hang, or a machine error`, `Target` `the registry does not take this target for the kind of the hash`.
	lines : { label : Str, shared : ProbeShare.Shared, kept_back : List(ProbeShare.KeptBack), unsent : List(Db.Queued) } -> List(Str)
	lines = |facts| {
		head = if facts.shared.requests == 0 and facts.unsent.is_empty() {
			"nothing to share\n"
		} else {
			"shared ${ProbeShow.plural(facts.shared.sent, "fact")} of ${facts.label}: ${facts.shared.counted.to_str()} counted, ${facts.shared.skipped.to_str()} skipped by the registry\n"
		}
		back = facts.kept_back.map(|k| "  not shared: ${k.nightly} ${k.target}: ${why_text(k.why)}\n")
		left = facts.unsent.map(|r| "  not shared: ${r.nightly} ${r.target}: not sent\n")
		[head].concat(back).concat(left)
	}

	## R-PB6, R-OUT2, R-OUT4 (proposal, TW24): the `data` of the share step: `{"share":{"requests":<n>,"sent":<n>,"counted":<n>,"first":<n>,"skipped":<n>,"not_shared":[{"nightly":"<id>","target":"<t>","reason":"<word>"}]}}`.
	## The words: `kind`, `compiler`, `not-in-answer`, `bot-row`, `result`, `target`, and `not-sent` for each of `unsent`, after the kept back.
	data : { shared : ProbeShare.Shared, kept_back : List(ProbeShare.KeptBack), unsent : List(Db.Queued) } -> JsonDoc
	data = |facts| {
		back = facts.kept_back.map(|k| Obj([("nightly", Text(k.nightly)), ("target", Text(k.target)), ("reason", Text(why_word(k.why)))]))
		left = facts.unsent.map(|r| Obj([("nightly", Text(r.nightly)), ("target", Text(r.target)), ("reason", Text("not-sent"))]))
		sums = facts.shared
		JsonDoc.Obj([
			(
				"share",
				Obj([
					("requests", Num(sums.requests.to_i64_wrap())),
					("sent", Num(sums.sent.to_i64_wrap())),
					("counted", Num(sums.counted.to_i64_wrap())),
					("first", Num(sums.first.to_i64_wrap())),
					("skipped", Num(sums.skipped.to_i64_wrap())),
					("not_shared", Arr(back.concat(left))),
				]),
			),
		])
	}
}

# The order of the rows: nightly, target, closure, in text order (a proposal, TW24).
order : Db.Fact, Db.Fact -> [Before, Same, After]
order = |a, b| match text_order(a.nightly, b.nightly) {
	Same => match text_order(a.target, b.target) {
		Same => text_order(a.closure, b.closure)
		other => other
	}
	other => other
}

text_order : Str, Str -> [Before, Same, After]
text_order = |a, b| {
	x = a.to_utf8()
	y = b.to_utf8()
	var $result = x.len().order_relative_to(y.len())
	var $index = x.len().min(y.len())
	# The first byte that differs decides; a prefix is before the longer text.
	while $index > 0 {
		$index = $index - 1
		first = x.get($index) ?? 0
		second = y.get($index) ?? 0
		match first.order_relative_to(second) {
			Same => {}
			other => {
				$result = other
			}
		}
	}
	$result
}

why_text : ShareQueue.Why -> Str
why_text = |why| match why {
	Off(_) => "sharing is off"
	NotProbed => "not a probe of this command"
	Kind => "not a unit check"
	Compiler => "the compiler has no recorded sha256 or is not a nightly"
	NotInAnswer => "the hash is not in an answer of the registry"
	BotRow => "the registry has a bot result for it"
	Result => "a hang, or a machine error"
	Target => "the registry does not take this target for the kind of the hash"
}

why_word : ShareQueue.Why -> Str
why_word = |why| match why {
	Off(_) => "off"
	NotProbed => "not-probed"
	Kind => "kind"
	Compiler => "compiler"
	NotInAnswer => "not-in-answer"
	BotRow => "bot-row"
	Result => "result"
	Target => "target"
}

# The filters that need no answer, in the order of R-SH3: 2 (a unit check), 3 (a recorded nightly), 6 (not a hang).
local_why : Db.Fact, Bool -> Try({}, ShareQueue.Why)
local_why = |f, recorded| if !f.closure.is_empty() {
	Err(Kind)
} else if !(Compiler.kind(f.nightly) == Nightly and recorded) {
	Err(Compiler)
} else if f.outcome == Hang {
	Err(Result)
} else {
	Ok({})
}
