import lib.Fail
import lib.Lookup
import lib.Ref
import lib.ShortNames

ShortnamesTest :: [].{}

# Slice 211 (docs/slices/211-short-names.md). Pure: the request of the short names of one command, the reader of the answer, the hide of `log:N`, the outcome (use, list, stop), and the Lookup seam (R-AD3 to R-AD5, R-AD7, R-I8).
# The flow `ShortNames.lookup!` is the L2 case `registry/sn6-short-names`. The bodies are copies of the real Worker answers (worker/tests/cases/shorts/*/expect/responses.jsonl).

origin = "http://127.0.0.1:9"

parser_item = { name: "lukewilliamboswell/roc-parser", first_log_index: 1, state: Active, moved_from: Err(None) }

other_item = { name: "someone/parser", first_log_index: 6, state: Active, moved_from: Err(None) }

json_item = { name: "acme/roc-json", first_log_index: 5, state: Active, moved_from: Ok("olduser/roc-json") }

# R-SN6, R-AP69, R-SN5: the path of the one request of a command: the repeated parameter `short=a&short=b` in the order of the list, each value percent-encoded, a repeated value repeated. The ranked search has `q`.
expect {
	short_ok = ShortNames.short_path(["parser"]) == "/v1/packages?short=parser" and ShortNames.short_path(["parser", "json"]) == "/v1/packages?short=parser&short=json" and ShortNames.short_path(["a", "b", "a"]) == "/v1/packages?short=a&short=b&short=a"
	enc_ok = ShortNames.short_path(["a b", "\u(E9)", "x+y"]) == "/v1/packages?short=a%20b&short=%C3%A9&short=x%2By"
	none_ok = ShortNames.short_path([]) == "/v1/packages"
	search_ok = ShortNames.search_path("pars") == "/v1/packages?q=pars" and ShortNames.search_path("a b+c") == "/v1/packages?q=a%20b%2Bc"
	short_ok and enc_ok and none_ok and search_ok
}

# R-SN6, R-AP33, R-SN9, R-AP51, R-AP44: the reader of the answer. Entry i is for value i, also when 2 values are equal and whatever the `short` text of the entry says. `moved_from` is optional. An unknown member is ignored. The items keep the order of the answer.
expect {
	one = "{\"matches\":[{\"matches\":[{\"first_log_index\":1,\"name\":\"lukewilliamboswell/roc-parser\",\"state\":\"active\"}],\"short\":\"parser\"}]}"
	two = "{\"matches\":[{\"matches\":[{\"first_log_index\":1,\"name\":\"lukewilliamboswell/roc-parser\",\"state\":\"active\"},{\"first_log_index\":6,\"name\":\"someone/parser\",\"state\":\"active\"}],\"short\":\"Parser\"},{\"matches\":[],\"short\":\"pars\"}]}"
	moved = "{\"matches\":[{\"matches\":[{\"first_log_index\":5,\"moved_from\":\"olduser/roc-json\",\"name\":\"acme/roc-json\",\"state\":\"active\"}],\"short\":\"json\"}]}"
	states = "{\"matches\":[{\"matches\":[{\"first_log_index\":2,\"name\":\"a/x\",\"state\":\"missing\",\"extra\":1},{\"first_log_index\":3,\"name\":\"b/x\",\"state\":\"moved\"}],\"short\":\"x\"}]}"
	one_ok = ShortNames.entries({ origin, body: one, shorts: ["parser"] }) == Ok([[parser_item]])
	two_ok = ShortNames.entries({ origin, body: two, shorts: ["Parser", "pars"] }) == Ok([[parser_item, other_item], []])
	moved_ok = ShortNames.entries({ origin, body: moved, shorts: ["json"] }) == Ok([[json_item]])
	position_ok = ShortNames.entries({ origin, body: two, shorts: ["first", "second"] }) == Ok([[parser_item, other_item], []])
	states_ok = ShortNames.entries({ origin, body: states, shorts: ["x"] }) == Ok([[{ name: "a/x", first_log_index: 2, state: Missing, moved_from: Err(None) }, { name: "b/x", first_log_index: 3, state: Moved, moved_from: Err(None) }]])
	empty_ok = ShortNames.entries({ origin, body: "{\"matches\":[]}", shorts: [] }) == Ok([])
	one_ok and two_ok and moved_ok and position_ok and states_ok and empty_ok
}

# R-SN6, R-AP51, R-E6 (last row): a body that does not decode, and a number of entries that is not the number of values, are exit 15 and the message names the registry.
expect {
	one = "{\"matches\":[{\"matches\":[],\"short\":\"parser\"}]}"
	bad : List(Str)
	bad = [
		"",
		"<html>",
		"{}",
		"{\"matches\":null}",
		"{\"matches\":{}}",
		"{\"matches\":[{\"short\":\"parser\"}]}",
		"{\"matches\":[{\"matches\":[{\"name\":\"a/b\",\"state\":\"active\"}],\"short\":\"parser\"}]}",
		"{\"matches\":[{\"matches\":[{\"first_log_index\":1,\"name\":\"a/b\",\"state\":\"gone\"}],\"short\":\"parser\"}]}",
	]
	bad_ok = bad.all(
		|body| match ShortNames.entries({ origin, body, shorts: ["parser"] }) {
			Ok(_) => Bool.False
			Err(f) => f.kind.code() == 15 and f.message.contains(origin) and f.message.contains("is not a short-name answer")
		},
	)
	count_ok = [ShortNames.entries({ origin, body: one, shorts: ["parser", "json"] }), ShortNames.entries({ origin, body: one, shorts: [] })].all(
		|got| match got {
			Ok(_) => Bool.False
			Err(f) => f.kind.code() == 15 and f.message.contains(origin) and f.message.contains("is not a short-name answer")
		},
	)
	bad_ok and count_ok
}

# R-SN5, R-SN6, R-AP51: the reader of the ranked answer (`packages`), in the order of the answer. A bad body is exit 15.
expect {
	body = "{\"packages\":[{\"first_log_index\":1,\"name\":\"lukewilliamboswell/roc-parser\",\"state\":\"active\"},{\"first_log_index\":31,\"name\":\"m/roc-ranked\",\"state\":\"moved\"}]}"
	got_ok = ShortNames.hits({ origin, body }) == Ok([{ name: "lukewilliamboswell/roc-parser", first_log_index: 1, state: Active }, { name: "m/roc-ranked", first_log_index: 31, state: Moved }])
	empty_ok = ShortNames.hits({ origin, body: "{\"packages\":[]}" }) == Ok([])
	bad_ok = ["", "[]", "{}", "{\"packages\":null}", "{\"packages\":[{\"name\":\"a/b\"}]}"].all(
		|b| match ShortNames.hits({ origin, body: b }) {
			Ok(_) => Bool.False
			Err(f) => f.kind.code() == 15 and f.message.contains(origin) and f.message.contains("is not a package search answer")
		},
	)
	got_ok and empty_ok and bad_ok
}

# R-SN4, R-AD34: `log:N` hides each item with `first_log_index` greater than N and keeps the one at N. No snapshot: all. The order stays. The same hide for the hits of `?q=` (Q4 of the slice file).
expect {
	items = [parser_item, other_item, json_item]
	all_ok = ShortNames.visible_items({ items, snapshot: Err(None) }) == items and ShortNames.visible_items({ items, snapshot: Ok(6) }) == items
	cut_ok = ShortNames.visible_items({ items, snapshot: Ok(5) }) == [parser_item, json_item] and ShortNames.visible_items({ items, snapshot: Ok(1) }) == [parser_item] and ShortNames.visible_items({ items, snapshot: Ok(0) }) == []
	hits = [{ name: "a/x", first_log_index: 4, state: Active }, { name: "b/x", first_log_index: 9, state: Missing }]
	hits_ok = ShortNames.visible_hits({ hits, snapshot: Ok(4) }) == [{ name: "a/x", first_log_index: 4, state: Active }] and ShortNames.visible_hits({ hits, snapshot: Err(None) }) == hits and ShortNames.visible_hits({ hits, snapshot: Ok(3) }) == []
	all_ok and cut_ok and hits_ok
}

# R-AD3, R-AD4, R-AD5, R-SN2: no item is `NoMatch`, one is `One`, 2 or more are `Many` in the order given. A `Missing` or a `Moved` item counts as any other.
expect {
	missing = { ..parser_item, state: Missing }
	moved = { ..other_item, state: Moved }
	ShortNames.outcome([]) == NoMatch and ShortNames.outcome([parser_item]) == One(parser_item) and ShortNames.outcome([missing]) == One(missing) and ShortNames.outcome([parser_item, other_item]) == Many([parser_item, other_item]) and ShortNames.outcome([moved, missing]) == Many([moved, missing])
}

# R-AD3, R-AP33, R-I8, R-AD4, R-AD7: the matched line (the short name as typed, also in upper case) with and without `moved from`, and the lines of a list.
expect {
	line_ok = ShortNames.matched_line({ short: "parser", item: parser_item }) == "matched \"parser\": lukewilliamboswell/roc-parser" and ShortNames.matched_line({ short: "Json", item: json_item }) == "matched \"Json\": acme/roc-json (moved from olduser/roc-json)"
	list_ok = ShortNames.list_lines([parser_item, json_item, other_item]) == "  lukewilliamboswell/roc-parser\n  acme/roc-json (moved from olduser/roc-json)\n  someone/parser\n" and ShortNames.list_lines([]) == ""
	line_ok and list_ok
}

ref_of = |text, scope| match Ref.parse(text, scope, Bool.False) {
	Ok(r) => r
	Err(_) => crash "bad ref in a test"
}

entity = |alias, name| { alias, name, series: "1", version: Ok("1.0.0"), note: "direct (${alias})" }

# R-AD3, R-I8, R-AD1, R-AD2, R-AD7, R-SN3, R-SC6 to R-SC8: which names go in the one `?short=` request. `Install`: a short name that is no header alias. A full name and a `host/path` name never (no search). `Tool` and `X`: a short name that matches no local entity by alias or by short name; a tie of local matches is a match.
# `Project` and `Roc` never.
expect {
	local = [entity("parser", "acme/roc-parser"), entity("", "own/json"), entity("", "x/json")]
	need = |scope, text| Lookup.needs_registry(scope, ref_of(text, scope), local)
	install_ok = need(Install, "other") and !need(Install, "parser") and need(Install, "json") and need(Install, "roc-parser") and !need(Install, "acme/roc-parser") and !need(Install, "new/lib") and !need(Install, "example.com/pkg/x")
	tool_ok = need(Tool, "other") and !need(Tool, "parser") and !need(Tool, "roc-parser") and !need(Tool, "json") and !need(Tool, "acme/zzz")
	x_ok = need(X, "other") and !need(X, "roc-parser") and !need(X, "json") and !need(X, "acme/zzz")
	never_ok = !need(Project, "other") and !need(Project, "parser") and Lookup.needs_registry(Roc, ref_of("other", Install), []) == Bool.False
	empty_ok = Lookup.needs_registry(Install, ref_of("parser", Install), []) and Lookup.needs_registry(Tool, ref_of("parser", Tool), [])
	install_ok and tool_ok and x_ok and never_ok and empty_ok
}

registry_of = |scope, text, outcome, suggest| Lookup.registry(scope, ref_of(text, scope), { short: text, outcome, suggest })

usage = |text| Fail.new(Usage, text)

# R-AD3, R-AP33: `tln add parser` with one match uses the full name (`New`), and the matched line (with `moved from` for a replaced name). No block, no failure.
expect {
	one = registry_of(Install, "parser", One(parser_item), [])
	moved = registry_of(Install, "json", One(json_item), [])
	one == Ok({ lookup: New("lukewilliamboswell/roc-parser"), matched: Ok("matched \"parser\": lukewilliamboswell/roc-parser") }) and moved == Ok({ lookup: New("acme/roc-json"), matched: Ok("matched \"json\": acme/roc-json (moved from olduser/roc-json)") })
}

# R-AD4, R-AD5, R-SN5, R-EC2: 2 or more matches stop with the list of full names (the form of the tie list of R-SC14, exit 2). No match stops with the error: no search of GitHub, and no pick from the ranked results (R-SN5), which are only listed as suggestions.
expect {
	many = registry_of(Install, "Parser", Many([parser_item, other_item]), [])
	many_ok = many == Err({ fail: usage("\"Parser\" matches 2 packages. Use a name from the list."), block: "\"Parser\" matches 2 packages:\n  lukewilliamboswell/roc-parser\n  someone/parser\n" })
	none = registry_of(Install, "pars", NoMatch, [])
	none_ok = none == Err({ fail: usage("\"pars\" matches no indexed package. Use the full name (owner/repo)."), block: "" })
	hits = [{ name: "lukewilliamboswell/roc-parser", first_log_index: 1, state: Active }, { name: "someone/parser", first_log_index: 6, state: Moved }]
	hint = registry_of(Install, "pars", NoMatch, hits)
	hint_ok = hint == Err({ fail: usage("\"pars\" matches no indexed package. Use the full name (owner/repo)."), block: "Similar names:\n  lukewilliamboswell/roc-parser\n  someone/parser\n" })
	many_ok and none_ok and hint_ok
}

# R-AD7: `tln tool install` and `tln x` with no local match never pick a registry match, also not a single one. They stop with exit 2 and list the registry matches as full names. No match: the message with no list.
expect {
	msg = "'parser' matches no installed tool or cached app. Use the full name (owner/repo)."
	tool_one = registry_of(Tool, "parser", One(parser_item), [])
	x_many = registry_of(X, "parser", Many([json_item, other_item]), [])
	tool_none = registry_of(Tool, "parser", NoMatch, [{ name: "a/b", first_log_index: 1, state: Active }])
	tool_one == Err({ fail: usage(msg), block: "Registry matches for \"parser\":\n  lukewilliamboswell/roc-parser\n" }) and x_many == Err({ fail: usage(msg), block: "Registry matches for \"parser\":\n  acme/roc-json (moved from olduser/roc-json)\n  someone/parser\n" }) and tool_none == Err({ fail: usage(msg), block: "" })
}

# R-I8, R-AD34, R-AD4, R-AD5, R-EC2 (Design Q223, slice 204b): all short names of one command give one stop. With no failing name, the result has one entry for each name in order, and the ref to go on with is the full name with the selector of the typed ref
# (`parser@^2` goes on as `lukewilliamboswell/roc-parser@^2`; a name with no selector has none). One failing name gives the `Err` of `registry` unchanged, also when another name matches. Two or more failing names give ONE `Err` (exit 2, kind Usage): the blocks of the failing names
# in the order of the command, and a line that lists each failing name as typed. A name with no block (no match, no suggestion) is in the line only. A name that matches is not in the stop.
expect {
	asked = |scope, text, outcome, suggest| { ref: ref_of(text, scope), found: { short: ref_of(text, scope).name, outcome, suggest } }
	ok = Lookup.registry_all(Install, [asked(Install, "parser@^2", One(parser_item), []), asked(Install, "json", One(json_item), [])])
	ok_ok = ok == Ok([
		{ ref: ref_of("lukewilliamboswell/roc-parser@^2", Install), lookup: New("lukewilliamboswell/roc-parser"), matched: Ok("matched \"parser\": lukewilliamboswell/roc-parser") },
		{ ref: ref_of("acme/roc-json", Install), lookup: New("acme/roc-json"), matched: Ok("matched \"json\": acme/roc-json (moved from olduser/roc-json)") },
	])
	one_fail = Lookup.registry_all(Install, [asked(Install, "parser", One(parser_item), []), asked(Install, "Parser", Many([parser_item, other_item]), [])])
	one_ok = one_fail.map_ok(|_| 0) == registry_of(Install, "Parser", Many([parser_item, other_item]), []).map_ok(|_| 0)
	hits = [{ name: "lukewilliamboswell/roc-parser", first_log_index: 1, state: Active }]
	two_fail = Lookup.registry_all(
		Install,
		[
			asked(Install, "Parser", Many([parser_item, other_item]), []),
			asked(Install, "json", One(json_item), []),
			asked(Install, "pars", NoMatch, hits),
			asked(Install, "zzz@2", NoMatch, []),
		],
	)
	two_ok = two_fail == Err({
		fail: usage("3 short names are not identified: \"Parser\", \"pars\", \"zzz\". Use the full name (owner/repo) of each."),
		block: "\"Parser\" matches 2 packages:\n  lukewilliamboswell/roc-parser\n  someone/parser\nSimilar names:\n  lukewilliamboswell/roc-parser\n",
	})
	tool_fail = Lookup.registry_all(Tool, [asked(Tool, "parser", One(parser_item), []), asked(Tool, "Parser", Many([json_item, other_item]), [])])
	tool_ok = tool_fail == Err({
		fail: usage("2 short names are not identified: \"parser\", \"Parser\". Use the full name (owner/repo) of each."),
		block: "Registry matches for \"parser\":\n  lukewilliamboswell/roc-parser\nRegistry matches for \"Parser\":\n  acme/roc-json (moved from olduser/roc-json)\n  someone/parser\n",
	})
	none_ok = Lookup.registry_all(Install, []) == Ok([])
	ok_ok and one_ok and two_ok and tool_ok and none_ok
}
