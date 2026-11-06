import records.Short as Wire
import ClosureRequest
import Fail
import Fx
import Registry
import RegistryCache
import Roots

## The short names of a command from the registry (slice 211; Registry 4.3 R-SN1, R-SN4, R-SN5, R-SN6, R-AP33; CLI 2 R-AD3 to R-AD5, R-AD7, R-AD34; Design 4.3 R-I8).
## One `GET /v1/packages?short=a&short=b` holds all short names of one command (R-SN6): entry i of `matches` is for the value i. The wire types and the codecs are the package `records` (`records.Short`, R-PK7).
## `origin` in each function is the base URL form of R-RG7 (`Registry.base`). No guard: `?short=` and `?q=` carry only the text that the user typed (R-RG4).
## The reads go through `RegistryCache.get!` (R-AP24: `max-age=60` for `short`, `max-age=300` for `q`, a copy for `--offline`). No command calls this module yet: slice 206 and the flows of `add`, `install`, `tool install` and `x` do.
ShortNames :: [].{

	## `state` of an item (R-AP32): `Active`, `Missing`, `Moved`.
	State : [Active, Missing, Moved]

	## An item of `matches` (R-SN6, `records.Short.Item`): `moved_from` is `Ok(old name)` only for a replaced name (R-AP33).
	Item : { name : Str, first_log_index : U64, state : State, moved_from : Try(Str, [None]) }

	## An item of `packages` (the ranked `?q=` answer, R-SN6, R-SN10: display only, R-SN5).
	Hit : { name : Str, first_log_index : U64, state : State }

	## The result for one short name (R-AD3 to R-AD5): `One(item)` (use it), `Many(items)` (2 or more: stop and list, in the order of the answer, which is sorted by name), `NoMatch`.
	Outcome : [One(Item), Many(List(Item)), NoMatch]

	## The result of `lookup!` for one value of the request: the value as given (not changed), its outcome, and the suggestions (the visible hits of `?q=`) only for `NoMatch`, else `[]`.
	Found : { short : Str, outcome : Outcome, suggest : List(Hit) }

	## R-SN6, R-AP69: the path and the query of the read of all short names of one command: `/v1/packages?short=<v1>&short=<v2>`, in the order of the list, each value with `Registry.encode` (a repeated value is repeated: entry i is for value i). No value gives `/v1/packages`.
	short_path : List(Str) -> Str
	short_path = |shorts| if shorts.is_empty() {
		"/v1/packages"
	} else {
		"/v1/packages?${Str.join_with(shorts.map(|text| "short=${Registry.encode(text)}"), "&")}"
	}

	## R-SN5, R-AP69: the path and the query of the ranked search: `/v1/packages?q=<text>` with `Registry.encode`.
	search_path : Str -> Str
	search_path = |text| "/v1/packages?q=${Registry.encode(text)}"

	## R-SN6, R-AP51: the reader of the 200 body of `short_path` (`Wire.decode_matches`). The result has one list of items for each value of `shorts`: entry i for value i, whatever the `short` text of the entry says.
	## A body that does not decode, or that has a number of entries other than `shorts.len()`, is a failure of kind `Network` (exit 15, R-E6 last row): `the answer of the registry <origin> is not a short-name answer: <reason>` (a proposal, TW24; for a wrong count the reason is `<n> entries for <m> names`).
	entries : { origin : Str, body : Str, shorts : List(Str) } -> Try(List(List(Item)), Fail)
	entries = |facts| match Wire.decode_matches(facts.body) {
		Err(BadJson(why)) => Err(not_short_answer(facts.origin, why))
		Ok(got) => if got.matches.len() == facts.shorts.len() {
			Ok(got.matches.map(|entry| entry.matches))
		} else {
			Err(not_short_answer(facts.origin, "${got.matches.len().to_str()} entries for ${facts.shorts.len().to_str()} names"))
		}
	}

	## R-SN5, R-AP51: the reader of the 200 body of `search_path` (`Wire.decode_packages`). A body that does not decode: kind `Network`, `the answer of the registry <origin> is not a package search answer: <reason>`.
	hits : { origin : Str, body : Str } -> Try(List(Hit), Fail)
	hits = |facts| match Wire.decode_packages(facts.body) {
		Ok(got) => Ok(got.found)
		Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${facts.origin} is not a package search answer: ${why}"))
	}

	## R-SN4, R-AD34: `--snapshot log:N` hides each item with `first_log_index` greater than N (`Ok(N)`: equal stays). `Err(None)`: all items. The order stays.
	visible_items : { items : List(Item), snapshot : Try(U64, [None]) } -> List(Item)
	visible_items = |facts| match facts.snapshot {
		Ok(n) => facts.items.keep_if(|item| item.first_log_index <= n)
		Err(None) => facts.items
	}

	## R-SN4 for the hits of `?q=` (R-SN6: their `first_log_index` is as R-SN4 says): the same hide (Q4 of slice 211).
	visible_hits : { hits : List(Hit), snapshot : Try(U64, [None]) } -> List(Hit)
	visible_hits = |facts| match facts.snapshot {
		Ok(n) => facts.hits.keep_if(|hit| hit.first_log_index <= n)
		Err(None) => facts.hits
	}

	## R-AD3, R-AD4, R-AD5: `[]` is `NoMatch`, one item is `One`, 2 or more are `Many`. A `Missing` or `Moved` item counts as any other (R-SN2: a match that is too wide only makes Talon ask for the full name).
	outcome : List(Item) -> Outcome
	outcome = |items| match items {
		[] => NoMatch
		[one] => One(one)
		_ => Many(items)
	}

	## R-AD3, R-AP33, R-I8: the line of one use, a proposal for the text (TW24, R-OUT2). `short` is the name as typed.
	##
	## | Item | Line (no line end) |
	## | --- | --- |
	## | no `moved_from` | `matched "<short>": <name>` |
	## | `moved_from` is `Ok(old)` | `matched "<short>": <name> (moved from <old>)` |
	matched_line : { short : Str, item : Item } -> Str
	matched_line = |facts| "matched \"${facts.short}\": ${facts.item.name}${moved_text(facts.item)}"

	## R-AD4, R-AD7: the lines of a list of full names (a proposal, TW24): for each item `  <name>` and, with `moved_from`, ` (moved from <old>)`, then a line end. The order stays.
	list_lines : List(Item) -> Str
	list_lines = |items| Str.join_with(items.map(|item| "  ${item.name}${moved_text(item)}\n"), "")

	## The short names of one command, with the read cache (R-SN6, R-AD34, R-IX6). `shorts` are the values in the order of the command, repeats included. `now` is the real clock, `snapshot` is `--snapshot log:N`. The calls, in order
	## (the L2 case `registry/sn6-short-names` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | `ClosureRequest.check_shorts(shorts.len())`: more than 50 values is its failure (kind `Usage`, exit 2) with no other call. No value: `Ok([])` with no call |
	## | 2 | One `RegistryCache.get!` of `short_path(shorts)` (not `newest`, no bookmark). `NoCopy` (`--offline` and no copy): kind `Network`, exit 15, `the registry <origin> is not asked (--offline) and Talon has no kept answer for <v1>, <v2>. Run the command with no --offline.` (R-IX6, a proposal for the text). A status other than 200: `Registry.refuse` with method `Get`. A failure of `get!` is the failure |
	## | 3 | `entries`, `visible_items` and `outcome` for each value. The result is in the order of `shorts` |
	## | 4 | For each value with `NoMatch`, in order: one `RegistryCache.get!` of `search_path(<value>)` (R-SN5), then `hits` and `visible_hits`. A read that fails, a `NoCopy` and a status other than 200 give no suggestion (Q5 of slice 211: no test, the reference gives `[]`) |
	lookup! : Fx, { roots : Roots, origin : Str, version : Str, now : U64, offline : Bool, snapshot : Try(U64, [None]), shorts : List(Str) } => Try(List(Found), Fail)
	lookup! = |fx, facts| {
		ClosureRequest.check_shorts(facts.shorts.len())?
		if facts.shorts.is_empty() {
			Ok([])
		} else {
			body = read_body!(fx, facts, ShortNames.short_path(facts.shorts), facts.shorts)?
			lists = ShortNames.entries({ origin: facts.origin, body, shorts: facts.shorts })?
			var $found = []
			for pair in facts.shorts.map2(lists, |short, items| (short, items)) {
				short = pair.0
				result = ShortNames.outcome(ShortNames.visible_items({ items: pair.1, snapshot: facts.snapshot }))
				suggest = match result {
					NoMatch => suggestions!(fx, facts, short)
					_ => []
				}
				$found = $found.append({ short, outcome: result, suggest })
			}
			Ok($found)
		}
	}
}

not_short_answer : Str, Str -> Fail
not_short_answer = |origin, why| Fail.new(Network, "the answer of the registry ${origin} is not a short-name answer: ${why}")

moved_text : ShortNames.Item -> Str
moved_text = |item| match item.moved_from {
	Ok(old) => " (moved from ${old})"
	Err(None) => ""
}

Ask : { roots : Roots, origin : Str, version : Str, now : U64, offline : Bool, snapshot : Try(U64, [None]), shorts : List(Str) }

# One read through the cache. `Ok(Err(NoCopy))` is `--offline` with no kept answer. A status other than 200 is a refusal.
read_answer! : Fx, Ask, Str => Try([Body(Str), NoCopy], Fail)
read_answer! = |fx, facts, route| {
	got = RegistryCache.get!(fx, { roots: facts.roots, origin: facts.origin, version: facts.version, path: route, now: facts.now, offline: facts.offline, newest: Bool.False, bookmark: Err(None) })?
	match got {
		NoCopy => Ok(NoCopy)
		Answer(answer) => if answer.status == 200 {
			Ok(Body(answer.body))
		} else {
			Err(Registry.refuse({ origin: facts.origin, version: facts.version, method: Get, reply: { status: answer.status, body: answer.body }, retry_after: Registry.retry_after_of(answer.headers) }))
		}
	}
}

# Step 2 of `lookup!`.
read_body! : Fx, Ask, Str, List(Str) => Try(Str, Fail)
read_body! = |fx, facts, route, shorts| match read_answer!(fx, facts, route)? {
	Body(text) => Ok(text)
	NoCopy => Err(Fail.new(Network, "the registry ${facts.origin} is not asked (--offline) and Talon has no kept answer for ${Str.join_with(shorts, ", ")}. Run the command with no --offline."))
}

# Step 4 of `lookup!`: the ranked hits of a name with no match. Any failure gives no suggestion (Q5 of slice 211).
suggestions! : Fx, Ask, Str => List(ShortNames.Hit)
suggestions! = |fx, facts, short| match read_answer!(fx, facts, ShortNames.search_path(short)) {
	Ok(Body(text)) => match ShortNames.hits({ origin: facts.origin, body: text }) {
		Ok(found) => ShortNames.visible_hits({ hits: found, snapshot: facts.snapshot })
		Err(_) => []
	}
	_ => []
}
