## The pure part of `GET /v1/packages?short=` and `?q=` (Registry 4.3: R-AP7, R-SN1 to R-SN5, R-AP33, R-AP46, R-TP11, R-TP14; slice 107). No effect, no platform import.
## The effects (the D1 session and its one call, the Cache API, the clock, the headers) are in `worker/ShortRoutes.roc`.
## The tests are in `worker/tests/unit/ShortsTest.roc` (W0) and `worker/tests/cases/shorts/` (W2).
## The texts of the `detail` of a problem and the members of the answer that the design does not give are proposals (TW24): `docs/slices/107-short-names.md` section 6.
## Every body is built here as text, so that two answers of one state have the same bytes and the same ETag (R-AP24, R-AP53, R-AP54).
import records.Artifact
import Problem

Shorts :: [].{

	## R-AP46, R-SN1: at most this many `short` values in one request (first guess).
	short_limit : U64
	short_limit = 50

	## R-SN5: at most this many packages in the answer of `?q=` (first guess).
	search_limit : U64
	search_limit = 20

	## R-AP7: the `Cache-Control` of a 200 answer and of a 304 answer of `?short=`.
	short_cache_control : Str
	short_cache_control = "max-age=60"

	## R-AP7: the `Cache-Control` of a 200 answer and of a 304 answer of `?q=`.
	search_cache_control : Str
	search_cache_control = "max-age=300"

	# ---- the query (R-AP7, R-AP46, R-AP48 rows 4 and 6) ----

	## `Short(values)`: one or more `short` parameters, in the order of the URL, each percent-decoded as `Request.query` does (`+` is a space, a bad escape stays),
	## and not changed in any other way (the case fold is in `is_match`). `Search(text)`: the first `q` parameter, decoded.
	Query : [Short(List(Str)), Search(Str)]

	## `Bad(problem)`: 400 `bad-request`. `TooMany(count)`: 413 `too-large`, `count` is the number of `short` parameters (R-AP46).
	Refusal : [Bad(Problem), TooMany(U64)]

	## The checks of R-AP48 rows 4 and 6, in this order. The route makes no D1 call when one fails. The input is the whole URL text (`Request.url`):
	## the platform `Request.query` gives only the first value of a name, and a request has up to 50 `short` values (the form is the repeated parameter, question Q107-1).
	## 1. More than `short_limit` `short` parameters (an empty value counts): `Err(TooMany(count))`. This is before every 400 (R-AP48 row 4 before row 6).
	## 2. No `short` and no `q`: `Err(Bad(..))` with the `detail` `GET /v1/packages needs the query parameter short or q`.
	## An unknown parameter is ignored (R-AP44). A request with `short` and `q`, an empty `short` value and an empty `q` are question Q107-3: no test.
	parse_url : Str -> Try(Shorts.Query, Shorts.Refusal)
	parse_url = |url| {
		query = match url.split_first("?") {
			Ok({ after, .. }) => match after.split_first("#") {
				Ok(p) => p.before
				Err(_) => after
			}
			Err(_) => ""
		}
		pairs = query.split_on("&").map(|pair| match pair.split_first("=") {
			Ok({ before, after }) => (decode(before), decode(after))
			Err(_) => (decode(pair), "")
		})
		shorts = pairs.keep_if(|(k, _)| k == "short").map(|(_, v)| v)
		searches = pairs.keep_if(|(k, _)| k == "q").map(|(_, v)| v)
		bad = |text| Err(Bad(Problem.new(BadRequest, text)))
		if shorts.len() > short_limit {
			Err(TooMany(shorts.len()))
		} else if !shorts.is_empty() and !searches.is_empty() {
			bad("the query parameters short and q must not be used together")
		} else if shorts.any(|v| v == "") {
			bad("the query parameter short must not be empty")
		} else if searches.len() > 1 {
			bad("the query parameter q must not be given more than once")
		} else if shorts.is_empty() {
			match searches {
				[text] => if (text == "") bad("the query parameter q must not be empty") else Ok(Search(text))
				_ => bad("GET /v1/packages needs the query parameter short or q")
			}
		} else {
			Ok(Short(shorts))
		}
	}

	## R-AP46: the body of the 413 answer, `application/problem+json`: the members `type` (`/errors/too-large`), `title`, `status` (413), `detail`,
	## `field` (`short`) and `limit` (50). `detail`: `the query has <count> short values, the limit is 50`. No white space.
	too_large_json : U64 -> Str
	too_large_json = |count| Json.to_str({
		type: "/errors/too-large",
		title: "Too large",
		status: 413.U16,
		detail: "the query has ${U64.to_str(count)} short values, the limit is ${U64.to_str(short_limit)}",
		field: "short",
		limit: short_limit,
	})

	# ---- the match rule (R-SN1, R-SN3) ----

	## R-SN1: the short keys of an `owner/repo` name: the repo name (the text after the first `/`) in lower case, and the repo name minus ONE leading `roc-`
	## when it has that prefix and something after it. Only ASCII letters change case. The repo name comes first. `lukewilliamboswell/roc-parser` gives
	## `["roc-parser", "parser"]`, `o/Parser` gives `["parser"]`, `o/roc-roc-x` gives `["roc-roc-x", "roc-x"]`, `o/rocx` gives `["rocx"]`, `o/roc-` gives `["roc-"]`.
	## A text with no `/` gives `[]`.
	short_keys : Str -> List(Str)
	short_keys = |name| match name.split_first("/") {
		Ok({ after, .. }) => {
			repo = after.with_ascii_lowercased()
			if repo.starts_with("roc-") and repo.count_utf8_bytes() > 4 [repo, repo.drop_prefix("roc-")] else [repo]
		}
		Err(_) => []
	}

	## R-SN1: the `short` value equals one key of the name, ASCII case-insensitive (`Parser` and `PARSER` match `roc-lang/roc-parser`; a letter that is not ASCII is not folded).
	## The value is the whole text: `pars` does not match `roc-parser`, and a value with a `/` (a full name) matches nothing.
	is_match : Str, Str -> Bool
	is_match = |short, name| short_keys(name).contains(short.with_ascii_lowercased())

	# ---- the match set (R-SN1, R-SN2, R-AP33, R-TP11, R-TP14) ----

	## The state of a name (R-AP32, R-TP11).
	State : [Active, Missing, Moved]

	## The wire text of a state: `active`, `missing`, `moved`.
	state_text : Shorts.State -> Str
	state_text = |state| match state {
		Active => "active"
		Missing => "missing"
		Moved => "moved"
	}

	## The state from the column `repos.state`: 0 `Active`, 1 `Missing`, 2 `Moved`. Another code is `Err(BadRow)`.
	state_of_code : I64 -> Try(Shorts.State, [BadRow(Str)])
	state_of_code = |code| match code {
		0 => Ok(Active)
		1 => Ok(Missing)
		2 => Ok(Moved)
		other => Err(BadRow("the state code ${I64.to_str(other)} is not known"))
	}

	## A row that the statement of the route gives: one for each `repos` row that can matter. The statement reads (a) the names that may match (a superset of the match set
	## is good, `is_match` is the rule), and (b) the names on their successor chain (the recursive CTE of R-AP41 row 1). `name`: `names.value` (kind 3).
	## `state`: the code of `repos.state`. `successor`: the name of the successor, or `Missing`. `first_log_index`: the smallest `releases.log_index` of the name,
	## or `Missing` when the name has no release (a name on a chain can have none).
	Row : { name : Str, state : I64, successor : Try(Str, [Missing]), first_log_index : Try(U64, [Missing]) }

	## One package of the match set (R-SN1). `moved_from`: the old name, when the item stands for a name in the state `moved` (R-AP33).
	Item : { name : Str, first_log_index : U64, state : Shorts.State, moved_from : Try(Str, [None]) }

	## The matches of one `short` value, as the request wrote it.
	Entry : { short : Str, matches : List(Shorts.Item) }

	## R-TP14, R-AP33: the end of the successor chain of `name` in `rows`. A name whose `state` is not `Moved`, or that has no successor, is its own end.
	## The walk follows at most 4 links (the limit of R-TP14) and stops before a name that it has seen already (a cycle). Where it stops is question Q107-2:
	## the proposal is the last name reached (after 4 links; or the name before the one that closes the cycle). A successor name that is not in `rows` ends the walk at the last name in `rows`.
	chain_end : Str, List(Shorts.Row) -> Str
	chain_end = |name, rows| chain_step(name, rows, [name], 0)

	## The answer for the `short` values, one entry for each value, in the order of the request (also two equal values: two entries). `rows` as for `Row`.
	## For a value `v`, the matched rows are those with `is_match(v, name)` and with `first_log_index` not `Missing` (R-SN2: an indexed package is a name with at least one release,
	## also yanked or withdrawn; a name in the state `missing` counts; a name with no release does not).
	## Each matched row becomes one item (R-AP33):
	## - state `Active` or `Missing`: `{name, first_log_index, state, moved_from: None}`.
	## - state `Moved`: the item of `chain_end(name, rows)`: its `name`, its `state` (the state of the end row), `moved_from: Ok(old name)`.
	##   Its `first_log_index` is that of the end row, or, when the end has no release, the smallest `first_log_index` of the old names that it replaces (question Q107-4).
	## The set has an end once: when 2 matched rows give one name, the item has `moved_from` of the moved row, the smallest old name when there are several (Q107-5).
	## The items are sorted by `name` (bytes). The compare is not ranked and not cut (R-SN1). A state code that is no state is `Err(BadRow)`.
	entries_of : List(Str), List(Shorts.Row) -> Try(List(Shorts.Entry), [BadRow(Str)])
	entries_of = |shorts, rows| shorts.map_try(|short| entry_of(short, rows))

	## R-AP7, R-SN1, R-AP33: `{"matches":[<entry>,...]}`. An entry: `{"matches":[<item>,...],"short":"<value as sent>"}`. An item: `{"first_log_index":N,"moved_from":"..","name":"..","state":".."}`
	## with `moved_from` only when the item has it (R-AP51: an optional member with no value is left out). The members are in alphabetical order, no white space, text escaped as JSON.
	## No entry: `{"matches":[]}`.
	matches_body : List(Shorts.Entry) -> Str
	matches_body = |entries| "{\"matches\":[${Str.join_with(entries.map(entry_json), ",")}]}"

	# ---- the search (R-AP7, R-SN5) ----

	## A row that the statement of `?q=` gives: an indexed package (R-SN2) with its state and its smallest log index. `state` is the code.
	SearchRow : { name : Str, state : I64, first_log_index : U64 }

	## R-SN5: the names ranked by a text match with `text`, at most `search_limit`. The ranking is question Q107-6. Fixed: the result has at most 20 names, it is a function of
	## `text` and `names` only (two calls give one list), and every name of the result is a name of the input. A name that has no character in common with `text` is not in it.
	rank : Str, List(Str) -> List(Str)
	rank = |text, names| {
		t = text.with_ascii_lowercased()
		scored = names.keep_oks(|n| {
			lower = n.with_ascii_lowercased()
			repo = match lower.split_first("/") {
				Ok({ after, .. }) => after
				Err(_) => lower
			}
			short = if (repo.starts_with("roc-") and repo.count_utf8_bytes() > 4) repo.drop_prefix("roc-") else repo
			rank = if (lower == t or repo == t or short == t) {
				1
			} else if (lower.starts_with(t) or repo.starts_with(t) or short.starts_with(t)) {
				2
			} else if (lower.contains(t)) {
				3
			} else {
				0
			}
			if rank > 0 Ok((rank, n)) else Err(NoMatch)
		})
		sorted = scored.sort_with(|(ra, na), (rb, nb)| if (ra < rb) Before else if (ra > rb) After else Artifact.compare(na, nb))
		sorted.take_first(search_limit).map(|(_, n)| n)
	}

	## R-AP7: `{"packages":[<item>,...]}` with the items of `rank`, an item `{"first_log_index":N,"name":"..","state":".."}` (a proposal, Q107-7). No package: `{"packages":[]}`.
	## A state code that is no state is `Err(BadRow)`.
	search_body : Str, List(Shorts.SearchRow) -> Try(Str, [BadRow(Str)])
	search_body = |text, rows| {
		ranked = rank(text, rows.map(|r| r.name))
		items = ranked.keep_oks(|n| rows.find_first(|r| r.name == n)).map_try(|r| state_of_code(r.state).map_ok(|st| "{\"first_log_index\":${U64.to_str(r.first_log_index)},\"name\":${Json.to_str(r.name)},\"state\":\"${state_text(st)}\"}"))?
		Ok("{\"packages\":[${Str.join_with(items, ",")}]}")
	}

	# ---- helpers of the reference ----

	chain_step : Str, List(Shorts.Row), List(Str), U64 -> Str
	chain_step = |cur, rows, seen, links| match rows.find_first(|r| r.name == cur) {
		Ok(r) if r.state == 2 => match r.successor {
			Ok(next) => if (links < 4 and !seen.contains(next) and rows.any(|x| x.name == next)) chain_step(next, rows, seen.append(next), links + 1) else cur
			Err(Missing) => cur
		}
		_ => cur
	}

	entry_of : Str, List(Shorts.Row) -> Try(Shorts.Entry, [BadRow(Str)])
	entry_of = |short, rows| {
		matched = rows.keep_if(|r| is_match(short, r.name) and r.first_log_index.is_ok())
		items = matched.map_try(|r| item_of(r, rows))?
		sorted = items.sort_with(|a, b| Artifact.compare(a.name, b.name))
		Ok({ short, matches: merge(sorted) })
	}

	item_of : Shorts.Row, List(Shorts.Row) -> Try(Shorts.Item, [BadRow(Str)])
	item_of = |r, rows| {
		state = state_of_code(r.state)?
		first = r.first_log_index ?? 0
		if state == Moved {
			end = chain_end(r.name, rows)
			if end == r.name {
				Ok({ name: r.name, first_log_index: first, state, moved_from: Err(None) })
			} else {
				end_row = rows.find_first(|x| x.name == end)
				end_state = match end_row {
					Ok(x) => state_of_code(x.state)?
					Err(_) => Moved
				}
				end_first = match end_row {
					Ok(x) => x.first_log_index ?? first
					# the minimum with the old name is taken below
					Err(_) => first
				}
				Ok({ name: end, first_log_index: if (end_first < first) end_first else first, state: end_state, moved_from: Ok(r.name) })
			}
		} else {
			Ok({ name: r.name, first_log_index: first, state, moved_from: Err(None) })
		}
	}

	## The items are sorted by name: equal names are next to each other.
	merge : List(Shorts.Item) -> List(Shorts.Item)
	merge = |items| items.fold([], |acc, it| match acc.last() {
		Ok(prev) if prev.name == it.name => acc.drop_last(1).append(join_item(prev, it))
		_ => acc.append(it)
	})

	join_item : Shorts.Item, Shorts.Item -> Shorts.Item
	join_item = |a, b| {
		from = match (a.moved_from, b.moved_from) {
			(Ok(x), Ok(y)) => Ok(if (Artifact.compare(x, y) == After) y else x)
			(Ok(x), Err(_)) => Ok(x)
			(Err(_), Ok(y)) => Ok(y)
			_ => Err(None)
		}
		first = if (a.first_log_index < b.first_log_index) a.first_log_index else b.first_log_index
		{ ..a, moved_from: from, first_log_index: first }
	}

	entry_json : Shorts.Entry -> Str
	entry_json = |e| "{\"matches\":[${Str.join_with(e.matches.map(item_json), ",")}],\"short\":${Json.to_str(e.short)}}"

	item_json : Shorts.Item -> Str
	item_json = |it| {
		from = match it.moved_from {
			Ok(old) => "\"moved_from\":${Json.to_str(old)},"
			Err(_) => ""
		}
		"{\"first_log_index\":${U64.to_str(it.first_log_index)},${from}\"name\":${Json.to_str(it.name)},\"state\":\"${state_text(it.state)}\"}"
	}

	## Percent-decoding of a query part, and "+" as a space (as `Request.query`). A bad escape stays as it is.
	decode : Str -> Str
	decode = |s| {
		bytes = s.to_utf8()
		var $out = List.with_capacity(bytes.len())
		var $i = 0
		while $i < bytes.len() {
			b = bytes.get($i) ?? 0
			if b == '+' {
				$out = $out.append(' ')
				$i = $i + 1
			} else if b == '%' {
				match (hex(bytes.get($i + 1) ?? 0), hex(bytes.get($i + 2) ?? 0)) {
					(Ok(h), Ok(l)) => {
						$out = $out.append(h * 16 + l)
						$i = $i + 3
					}
					_ => {
						$out = $out.append(b)
						$i = $i + 1
					}
				}
			} else {
				$out = $out.append(b)
				$i = $i + 1
			}
		}
		Str.from_utf8($out) ?? s
	}

	hex : U8 -> Try(U8, [NotHex])
	hex = |c| {
		if c >= '0' and c <= '9' {
			Ok(c - '0')
		} else if c >= 'a' and c <= 'f' {
			Ok(c - 'a' + 10)
		} else if c >= 'A' and c <= 'F' {
			Ok(c - 'A' + 10)
		} else {
			Err(NotHex)
		}
	}
}
