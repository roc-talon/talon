import lib.Shorts
import lib.Route
import lib.Problem

ShortsTest :: [].{}

# W0 tests of worker/lib/Shorts.roc (slice 107) and of the route row. The expected texts are written by hand from the design and from
# research/slice-107-revert/gen/gen.py (python, no Roc code). The answers of Q107-1 to Q107-7 are the rules R-SN6 to R-SN10.

# ---- the route (R-AP7, R-AP48 rows 1 and 2) ----

input = |method, segments| { method, segments, content_type: Err(NotFound), has_body: Bool.False }

# R-AP7, R-AP48: `GET /v1/packages` is a route. Another method gives 405 with `Allow: GET`. A path under it that is no route gives 404.
expect Route.decide(input("GET", ["v1", "packages"])) == Handle(GetPackages)
expect Route.decide(input("POST", ["v1", "packages"])) == NotAllowed(Problem.new(MethodNotAllowed, "POST is not allowed on /v1/packages"), ["GET"])
expect Route.decide(input("DELETE", ["v1", "packages"])) == NotAllowed(Problem.new(MethodNotAllowed, "DELETE is not allowed on /v1/packages"), ["GET"])
expect Route.decide(input("GET", ["v1", "packages", "x"])) == Refuse(Problem.new(NotFound, "no route for GET /v1/packages/x"))

# ---- the query (R-AP7, R-AP46, R-AP48 rows 4 and 6) ----
# Slice 123: the route gives `parse_query` the values of `req.query_all("short")` and `req.query_all("q")` (platform 0.0.3: URLSearchParams rules). The percent-decoding,
# the `+`, the empty parts and the end of the query at `#` are the platform's: W2 `shorts/ap7-query-forms` checks them through the route.

shorts_of = |n| List.repeat("s", n)

no_param = Err(Bad(Problem.new(BadRequest, "GET /v1/packages needs the query parameter short or q")))

# R-AP7, R-SN1: `short` values in the order of the request, not changed (the case fold is in `is_match`). `q` is the one `q`.
expect Shorts.parse_query(["parser"], []) == Ok(Short(["parser"]))
expect Shorts.parse_query(["Parser", "json"], []) == Ok(Short(["Parser", "json"]))
expect Shorts.parse_query(["Roc-x y", "%52"], []) == Ok(Short(["Roc-x y", "%52"]))
expect Shorts.parse_query([], ["pars"]) == Ok(Search("pars"))
expect Shorts.parse_query([], ["a b"]) == Ok(Search("a b"))

# R-AP46: 50 `short` values are good, 51 are 413 with the count, also when one value is empty (row 4 before row 6). R-AP7: no `short` and no `q` is 400.
expect Shorts.parse_query(shorts_of(50), []) == Ok(Short(shorts_of(50)))
expect Shorts.parse_query(shorts_of(51), []) == Err(TooMany(51))
expect Shorts.parse_query(shorts_of(51).append(""), []) == Err(TooMany(52))
expect Shorts.parse_query(shorts_of(51), ["a", "b"]) == Err(TooMany(51))
expect Shorts.parse_query([], []) == no_param

# R-SN7: 400 for `short` with `q`, an empty `short` value, `q` more than once, an empty `q`. The 413 comes first (row 4 before row 6).
bad = |detail| Err(Bad(Problem.new(BadRequest, detail)))
expect Shorts.parse_query(["a"], ["b"]) == bad("the query parameters short and q must not be used together")
expect Shorts.parse_query([""], []) == bad("the query parameter short must not be empty")
expect Shorts.parse_query(["a", ""], []) == bad("the query parameter short must not be empty")
expect Shorts.parse_query([], [""]) == bad("the query parameter q must not be empty")
expect Shorts.parse_query([], ["a", "b"]) == bad("the query parameter q must not be given more than once")
# The order of the 400 checks: `short` with `q` first, then an empty `short`, then `q` twice, then an empty `q`.
expect Shorts.parse_query([""], [""]) == bad("the query parameters short and q must not be used together")
expect Shorts.parse_query([""], []) == bad("the query parameter short must not be empty")
expect Shorts.parse_query([], ["", "b"]) == bad("the query parameter q must not be given more than once")

# R-AP46, R-AP21: the 413 body has the members `type`, `status`, `field` and `limit` (the order is free).
expect [
	"\"type\":\"/errors/too-large\"",
	"\"title\":\"Too large\"",
	"\"status\":413",
	"\"detail\":\"the query has 51 short values, the limit is 50\"",
	"\"field\":\"short\"",
	"\"limit\":50",
].all(|part| Shorts.too_large_json(51).contains(part))

# ---- the match rule (R-SN1, R-SN3) ----

# R-SN1: the keys of a name: the repo name in lower case, and the repo name minus ONE leading `roc-`.
expect [
	"lukewilliamboswell/roc-parser",
	"o/Parser",
	"o/roc-roc-x",
	"o/rocx",
	"o/roc-",
	"o/ROC-Json",
	"nothing",
].map(Shorts.short_keys) == [
	["roc-parser", "parser"],
	["parser"],
	["roc-roc-x", "roc-x"],
	["rocx"],
	["roc-"],
	["roc-json", "json"],
	[],
]

# R-SN1 table: `parser` and `roc-parser` match `lukewilliamboswell/roc-parser`, `Parser` matches it and `someone/parser`, `pars` matches none.
# ASCII case-insensitive. A letter that is not ASCII is not folded. A full name matches nothing (the text after the first `/` is the repo name).
expect [
	("parser", "lukewilliamboswell/roc-parser"),
	("roc-parser", "lukewilliamboswell/roc-parser"),
	("Parser", "lukewilliamboswell/roc-parser"),
	("Parser", "someone/parser"),
	("ROC-PARSER", "lukewilliamboswell/roc-parser"),
	("x", "o/roc-roc-x"),
	("roc-x", "o/roc-roc-x"),
	("roc-roc-x", "o/roc-roc-x"),
	("Ünï", "o/Ünï"),
].map(|(short, name)| Shorts.is_match(short, name)) == [
	Bool.True,
	Bool.True,
	Bool.True,
	Bool.True,
	Bool.True,
	Bool.False,
	Bool.True,
	Bool.True,
	Bool.True,
]

expect [
	("pars", "lukewilliamboswell/roc-parser"),
	("arser", "lukewilliamboswell/roc-parser"),
	("parsers", "lukewilliamboswell/roc-parser"),
	("lukewilliamboswell/roc-parser", "lukewilliamboswell/roc-parser"),
	("roc-lang/parser", "roc-lang/parser"),
	("x", "o/rocx"),
	("ünï", "o/Ünï"),
	("", "o/x"),
].map(|(short, name)| Shorts.is_match(short, name)) == List.repeat(Bool.False, 8)

# ---- the chain (R-TP14, R-AP33) ----

row = |name, state, successor, first| { name, state, successor, first_log_index: first }

moved = |name, to| row(name, 2, Ok(to), Ok(1))

active = |name| row(name, 0, Err(Missing), Ok(1))

# R-TP14: the end of a chain of 0, 1 and 4 links (and of the names in between). A name that is not moved is its own end, also when it has a successor.
expect {
	rows = [moved("n0", "n1"), moved("n1", "n2"), moved("n2", "n3"), moved("n3", "n4"), active("n4"), row("keep", 0, Ok("n0"), Ok(1)), row("stuck", 2, Err(Missing), Ok(1)), moved("m0", "m1"), active("m1")]
	["n0", "n1", "n2", "n3", "n4", "keep", "stuck", "m0", "m1"].map(|name| Shorts.chain_end(name, rows)) == ["n4", "n4", "n4", "n4", "n4", "keep", "stuck", "m1", "m1"]
}

# R-SN8: 5 links give the name after 4 links. A to B to A from A gives B. A to B to C to A from A gives C. A name whose successor is itself is its own end.
# A `missing` name ends the walk, also when it has a successor.
expect {
	rows = [moved("f0", "f1"), moved("f1", "f2"), moved("f2", "f3"), moved("f3", "f4"), moved("f4", "f5"), active("f5"), moved("a", "b"), moved("b", "a"), moved("c", "d"), moved("d", "e"), moved("e", "c"), moved("self", "self"), moved("g", "h"), row("h", 1, Ok("i"), Ok(1)), active("i")]
	["f0", "a", "b", "c", "self", "g"].map(|name| Shorts.chain_end(name, rows)) == ["f4", "b", "a", "e", "self", "h"]
}

# ---- the match set (R-SN1, R-SN2, R-SN4, R-AP33) ----

item = |name, first, state, from| { name, first_log_index: first, state, moved_from: from }

entry = |short, matches| { short, matches }

# R-SN1 table, R-SN4: the rows `roc-parser` (log 1 and up) and `someone/parser`. `parser`, `roc-parser`, `Parser` and `pars`, in this order, the value as sent.
expect {
	rows = [row("lukewilliamboswell/roc-json", 0, Err(Missing), Ok(4)), row("someone/parser", 0, Err(Missing), Ok(3)), row("lukewilliamboswell/roc-parser", 0, Err(Missing), Ok(1))]
	one = item("lukewilliamboswell/roc-parser", 1, Active, Err(None))
	two = item("someone/parser", 3, Active, Err(None))
	Shorts.entries_of(["parser", "roc-parser", "Parser", "pars"], rows) == Ok([
		entry("parser", [one, two]),
		entry("roc-parser", [one]),
		entry("Parser", [one, two]),
		entry("pars", []),
	])
}

# R-SN2: a name in the state `missing` counts and keeps the state. A name with no release does not count. A yanked or withdrawn release is a release (the row has its log index).
expect {
	rows = [row("lukewilliamboswell/roc-parser", 1, Err(Missing), Ok(1)), row("someone/parser", 0, Err(Missing), Ok(9)), row("ghost/parser", 0, Err(Missing), Err(Missing))]
	Shorts.entries_of(["parser"], rows) == Ok([entry("parser", [item("lukewilliamboswell/roc-parser", 1, Missing, Err(None)), item("someone/parser", 9, Active, Err(None))])])
}

# R-AP33: a moved name is replaced by the end of its chain, with `moved_from`. The chain goes through names that the value does not match.
# Sorted by the name of the item, not by `moved_from`. A moved name with no release is not in the set.
expect {
	rows = [
		row("y/roc-sort", 2, Ok("c/other-end"), Ok(30)),
		row("m/sort", 0, Err(Missing), Ok(40)),
		row("c/other-end", 0, Err(Missing), Ok(20)),
		row("a/chain1", 2, Ok("b/mid1"), Ok(50)),
		row("b/mid1", 2, Ok("c/mid2"), Err(Missing)),
		row("c/mid2", 2, Ok("d/final"), Err(Missing)),
		row("d/final", 0, Err(Missing), Ok(10)),
		row("o/ghostmove", 2, Ok("d/final"), Err(Missing)),
		row("q/old-lost", 2, Ok("r/lost"), Ok(60)),
		row("r/lost", 1, Err(Missing), Ok(15)),
	]
	Shorts.entries_of(["sort", "chain1", "ghostmove", "old-lost"], rows) == Ok([
		entry("sort", [item("c/other-end", 20, Active, Ok("y/roc-sort")), item("m/sort", 40, Active, Err(None))]),
		entry("chain1", [item("d/final", 10, Active, Ok("a/chain1"))]),
		entry("ghostmove", []),
		entry("old-lost", [item("r/lost", 15, Missing, Ok("q/old-lost"))]),
	])
}

# R-AP33: when the end is already in the set, the set has it once, with `moved_from`.
expect {
	rows = [row("olduser/roc-json", 2, Ok("acme/roc-json"), Ok(7)), row("acme/roc-json", 0, Err(Missing), Ok(5))]
	Shorts.entries_of(["json"], rows) == Ok([entry("json", [item("acme/roc-json", 5, Active, Ok("olduser/roc-json"))])])
}

# R-SN9: `first_log_index` of a replaced item is the minimum over the end and the old names of the entry. The old name has the smaller index: the item gets it.
# The end has no release: the item is there, with the old index. Names on the chain that are not in the set do not count (`mid` has index 1).
expect {
	rows = [row("o/old", 2, Ok("n/new"), Ok(3)), row("n/new", 0, Err(Missing), Ok(9)), row("p/oldnr", 2, Ok("mid/m"), Ok(51)), row("mid/m", 2, Ok("u/noreln"), Ok(1)), row("u/noreln", 0, Err(Missing), Err(Missing))]
	Shorts.entries_of(["old", "oldnr"], rows) == Ok([entry("old", [item("n/new", 3, Active, Ok("o/old"))]), entry("oldnr", [item("u/noreln", 51, Active, Ok("p/oldnr"))])])
}

# R-SN9, R-AP33: 2 old names for 1 end: one item, `moved_from` is the smaller name by bytes, `first_log_index` is the minimum.
expect {
	rows = [row("b/roc-two", 2, Ok("e/end"), Ok(5)), row("a/two", 2, Ok("e/end"), Ok(7)), row("e/end", 0, Err(Missing), Ok(9))]
	Shorts.entries_of(["two"], rows) == Ok([entry("two", [item("e/end", 5, Active, Ok("a/two"))])])
}

# R-SN9: the end is in the set and 2 old names are replaced: one item, `moved_from` stays, the minimum of the three.
expect {
	rows = [row("y/w", 2, Ok("z/w"), Ok(7)), row("x/roc-w", 2, Ok("z/w"), Ok(5)), row("z/w", 0, Err(Missing), Ok(9))]
	Shorts.entries_of(["w"], rows) == Ok([entry("w", [item("z/w", 5, Active, Ok("x/roc-w"))])])
}

# R-SN8: a name whose successor is itself is not a replace. A chain that is cut gives an end in the state `moved`.
expect {
	rows = [row("s/loop", 2, Ok("s/loop"), Ok(4)), row("c/roc-cyc", 2, Ok("d/cyc2"), Ok(6)), row("d/cyc2", 2, Ok("c/roc-cyc"), Ok(8))]
	Shorts.entries_of(["loop", "cyc"], rows) == Ok([entry("loop", [item("s/loop", 4, Moved, Err(None))]), entry("cyc", [item("d/cyc2", 6, Moved, Ok("c/roc-cyc"))])])
}

# R-SN6: equal `short` values give 2 entries in the order of the URL, the value is not made lower case.
expect {
	rows = [row("lukewilliamboswell/roc-parser", 0, Err(Missing), Ok(1))]
	one = item("lukewilliamboswell/roc-parser", 1, Active, Err(None))
	Shorts.entries_of(["Parser", "Parser", "parser"], rows) == Ok([entry("Parser", [one]), entry("Parser", [one]), entry("parser", [one])])
}

# A state code that is no state in a matched row is `Err(BadRow)`.
expect match Shorts.entries_of(["x"], [row("o/x", 7, Err(Missing), Ok(1))]) {
	Err(BadRow(_)) => Bool.True
	_ => Bool.False
}

# ---- the body of `?short=` (R-AP7, R-AP51, R-AP53) ----

# Members in alphabetical order, `moved_from` only when the item has it, the short value escaped as JSON text.
expect Shorts.matches_body([
	entry("parser", [item("lukewilliamboswell/roc-parser", 1, Active, Err(None))]),
	entry("json", [item("acme/roc-json", 5, Moved, Ok("olduser/roc-json"))]),
	entry("q\"x\\", []),
]) == "{\"matches\":[{\"matches\":[{\"first_log_index\":1,\"name\":\"lukewilliamboswell/roc-parser\",\"state\":\"active\"}],\"short\":\"parser\"},{\"matches\":[{\"first_log_index\":5,\"moved_from\":\"olduser/roc-json\",\"name\":\"acme/roc-json\",\"state\":\"moved\"}],\"short\":\"json\"},{\"matches\":[],\"short\":\"q\\\"x\\\\\"}]}"

expect Shorts.matches_body([]) == "{\"matches\":[]}"

expect [Active, Missing, Moved].map(Shorts.state_text) == ["active", "missing", "moved"]

expect [0, 1, 2].map(Shorts.state_of_code) == [Ok(Active), Ok(Missing), Ok(Moved)]

expect match Shorts.state_of_code(3) {
	Err(BadRow(_)) => Bool.True
	_ => Bool.False
}

# ---- the search (R-AP7, R-SN5) ----

ranked = (1.U64).to(25).map(|n| "own/ranked-${n.to_str()}").collect()

# R-SN10: rank 1 exact (the name, the repo part or the short part equals the text), rank 2 prefix (the same three parts), rank 3 substring of the name, else out.
# Order: rank, then name by bytes. ASCII case-insensitive. No fuzzy match.
expect Shorts.rank("parser", ["a/roc-parser-x", "lukewilliamboswell/roc-parser", "someone/parser", "zz/parserx", "b/xparser", "c/other", "d/pars"]) == [
	"lukewilliamboswell/roc-parser",
	"someone/parser",
	"a/roc-parser-x",
	"zz/parserx",
	"b/xparser",
]
expect Shorts.rank("PaRsEr", ["a/parser"]) == ["a/parser"]
expect Shorts.rank("o/p", ["o/pq", "p/o", "o/p"]) == ["o/p", "o/pq"]
expect Shorts.rank("roc-p", ["a/roc-parser", "b/parser", "c/xroc-p"]) == ["a/roc-parser", "c/xroc-p"]
expect Shorts.rank("ranked", ["own/rnkd", "own/other", "x/rankd"]) == []
expect Shorts.rank("ranked", []) == []

# R-SN5, R-SN10: at most 20 after the order (by bytes: 1, 10 to 19, 2, 20 to 25, 3, 4), one list for one input.
expect Shorts.rank("ranked", ranked) == [
	"own/ranked-1",
	"own/ranked-10",
	"own/ranked-11",
	"own/ranked-12",
	"own/ranked-13",
	"own/ranked-14",
	"own/ranked-15",
	"own/ranked-16",
	"own/ranked-17",
	"own/ranked-18",
	"own/ranked-19",
	"own/ranked-2",
	"own/ranked-20",
	"own/ranked-21",
	"own/ranked-22",
	"own/ranked-23",
	"own/ranked-24",
	"own/ranked-25",
	"own/ranked-3",
	"own/ranked-4",
]
expect Shorts.rank("ranked", ranked) == Shorts.rank("ranked", ranked.rev())

# R-AP7, R-SN6: `{"packages":[...]}` in the order of `rank`. An item has `first_log_index`, `name`, `state` (the state of the name itself, also `moved`), and no `moved_from`.
expect Shorts.search_body("zzzq", [{ name: "own/ranked-1", state: 0, first_log_index: 4 }]) == Ok("{\"packages\":[]}")
expect Shorts.search_body("ranked", [{ name: "own/ranked-1", state: 0, first_log_index: 4 }]) == Ok("{\"packages\":[{\"first_log_index\":4,\"name\":\"own/ranked-1\",\"state\":\"active\"}]}")
expect Shorts.search_body("ranked", [{ name: "a/xranked", state: 2, first_log_index: 9 }, { name: "b/ranked", state: 1, first_log_index: 3 }, { name: "c/ranked-x", state: 0, first_log_index: 1 }]) == Ok("{\"packages\":[{\"first_log_index\":3,\"name\":\"b/ranked\",\"state\":\"missing\"},{\"first_log_index\":1,\"name\":\"c/ranked-x\",\"state\":\"active\"},{\"first_log_index\":9,\"name\":\"a/xranked\",\"state\":\"moved\"}]}")
expect match Shorts.search_body("ranked", [{ name: "own/ranked-1", state: 9, first_log_index: 4 }]) {
	Err(BadRow(_)) => Bool.True
	_ => Bool.False
}
