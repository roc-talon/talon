app [main!] { resolve: "../main.roc" }

import resolve.Domain

main! = |_args| Ok({})

# The expected value of each row is the design text (Resolution 1 and 2, R-VA6, R-C1, R-C6, R-C7, R-C9), not the code.
# The time is in seconds. Now is 1000 and `min-release-age` is 100, so a release published at 900 or before is old enough, and one published at 901 or after is too young (R-C7: "at least" that old).
# The id of a candidate is `x<version>`. A row prints its label with `dbg` when it is wrong.

rules : [Highest, Lowest] -> Domain.Rules
rules = |strategy| { now: 1000, min_age: 100, snapshot: Err(None), strategy }

# A candidate that is old and listed, a young one (published at 950), a yanked one, and one with a published time.
cand : Str -> Domain.Candidate
cand = |v| { id: "x${v}", version: v, published_at: 0, yanked: Bool.False }

young : Str -> Domain.Candidate
young = |v| { id: "x${v}", version: v, published_at: 950, yanked: Bool.False }

yank : Str -> Domain.Candidate
yank = |v| { id: "x${v}", version: v, published_at: 0, yanked: Bool.True }

at : Str, U64 -> Domain.Candidate
at = |v, time| { id: "x${v}", version: v, published_at: time, yanked: Bool.False }

query : List(Domain.Candidate) -> Domain.Query
query = |candidates| { candidates, ranges: [], current: Err(None), named: Err(None), rules: rules(Highest) }

ids : Domain.Query -> List(Str)
ids = |q| Domain.values(q).map(|c| c.id)

mix = ["1.0.0", "1.10.0", "1.2.0", "1.9.0"].map(cand)

# R-VA6 R-C1: the order of the values (best first) and the ranges. A version is compared as a semver, so 1.10.0 is above 1.9.0. A range list is an intersection, and the empty list admits each version.
# One version with 2 ids (a release that was made again): the byte order of the ids, for both strategies. The order of the input never changes the result (R-DT2).
expect {
	lowest = { ..query(mix), rules: rules(Lowest) }
	three = ["2.0.0", "10.0.0", "0.9.0"].map(cand)
	tie = [{ id: "b", version: "1.0.0", published_at: 0, yanked: Bool.False }, { id: "a", version: "1.0.0", published_at: 0, yanked: Bool.False }]
	rows = [
		(ids(query(mix)), ["x1.10.0", "x1.9.0", "x1.2.0", "x1.0.0"], "highest: by version, not by text"),
		(ids(lowest), ["x1.0.0", "x1.2.0", "x1.9.0", "x1.10.0"], "lowest"),
		(ids(query(mix.rev())), ["x1.10.0", "x1.9.0", "x1.2.0", "x1.0.0"], "the order of the input does not matter"),
		(ids({ ..lowest, candidates: mix.rev() }), ["x1.0.0", "x1.2.0", "x1.9.0", "x1.10.0"], "the order of the input does not matter, lowest"),
		(ids(query(three)), ["x10.0.0", "x2.0.0", "x0.9.0"], "the major version counts first"),
		(ids({ ..query(mix), ranges: [">=1.2.0", "<1.10.0"] }), ["x1.9.0", "x1.2.0"], "2 ranges are an intersection"),
		(ids({ ..query(mix), ranges: ["^1.2"] }), ["x1.10.0", "x1.9.0", "x1.2.0"], "a caret range"),
		(ids({ ..query(mix), ranges: ["=1.9.0"] }), ["x1.9.0"], "an exact range"),
		(ids({ ..query(mix), ranges: ["*"] }), ["x1.10.0", "x1.9.0", "x1.2.0", "x1.0.0"], "the star range admits all"),
		(ids({ ..query(mix), ranges: [">=2.0.0"] }), [], "no value in the range"),
		(ids(query([])), [], "no candidate"),
		(ids(query(tie)), ["a", "b"], "one version, 2 ids: byte order"),
		(ids({ ..query(tie), rules: rules(Lowest) }), ["a", "b"], "one version, 2 ids: byte order, lowest"),
	]
	bad = rows.keep_if(|(got, want, _)| got != want).map(|(_, _, label)| label)
	dbg bad
	bad == []
}

# R-C6 R-C7 R-C9: a yanked release, a release that is too young and a release after the snapshot are not values. The header value (`current`) and, for the age, the version that the user named, are.
# The header value is added when the candidates do not list it. A range still excludes it (R-C1). A named version is hidden by neither the age nor the snapshot (Q1 of slice 034).
expect {
	cur = |v| Ok({ id: "x${v}", version: v })
	snap = |time| { ..query([at("1.0.0", 0), at("1.1.0", 500), at("1.2.0", 501)]), rules: { now: 1000, min_age: 0, snapshot: Ok(time), strategy: Highest } }
	rows = [
		(ids(query([cand("1.0.0"), yank("1.1.0")])), ["x1.0.0"], "R-C6: yanked is no value"),
		(ids({ ..query([cand("1.0.0"), yank("1.1.0")]), current: cur("1.1.0") }), ["x1.1.0", "x1.0.0"], "R-C9: a yanked header value stays"),
		(ids(query([cand("1.0.0"), young("1.1.0")])), ["x1.0.0"], "R-C7: too young"),
		(ids(query([cand("1.0.0"), at("1.1.0", 900)])), ["x1.1.0", "x1.0.0"], "R-C7: exactly as old as min-release-age is allowed"),
		(ids(query([cand("1.0.0"), at("1.1.0", 901)])), ["x1.0.0"], "R-C7: one second too young"),
		(ids({ ..query([cand("1.0.0"), young("1.1.0")]), current: cur("1.1.0") }), ["x1.1.0", "x1.0.0"], "R-C9: a young header value stays"),
		(ids({ ..query([cand("1.0.0"), young("1.1.0")]), named: Ok("1.1.0") }), ["x1.1.0", "x1.0.0"], "R-C7: a version that the user names is not too young"),
		(ids({ ..query([cand("1.0.0"), yank("1.1.0")]), named: Ok("1.1.0") }), ["x1.0.0"], "R-C6: a named version that is yanked is no value"),
		(ids({ ..query([cand("1.0.0"), young("1.1.0")]), named: Ok("1.0.0") }), ["x1.0.0"], "the name of another version exempts nothing"),
		(ids({ ..snap(500), candidates: [at("1.0.0", 0), at("1.1.0", 600)], named: Ok("1.1.0") }), ["x1.1.0", "x1.0.0"], "Q1: a named version after the snapshot time is still a value"),
		(ids({ ..snap(500), candidates: [at("1.0.0", 0), at("1.1.0", 600)] }), ["x1.0.0"], "the same release with no name is after the snapshot: no value"),
		(ids({ ..snap(500), candidates: [at("1.0.0", 0), at("1.1.0", 600)], named: Ok("1.1.0"), ranges: ["=1.0.0"] }), ["x1.0.0"], "Q1: a range still hides a named version that it does not admit"),
		(ids(snap(500)), ["x1.1.0", "x1.0.0"], "R-C7: a release after the snapshot time is no value, one at that time is"),
		(ids({ ..snap(499), current: cur("1.2.0") }), ["x1.2.0", "x1.0.0"], "R-C9: a header value after the snapshot stays"),
		(ids({ ..query([cand("1.0.0")]), current: cur("1.5.0") }), ["x1.5.0", "x1.0.0"], "R-C9: a header value that the list does not have is added"),
		(ids({ ..query([cand("1.0.0"), cand("1.6.0")]), current: cur("1.0.0"), ranges: [">=1.5.0"] }), ["x1.6.0"], "R-C1: a range still excludes the header value"),
		(ids({ ..query([]), current: cur("1.5.0") }), ["x1.5.0"], "no candidate: the header value is the one value"),
		(ids({ ..query([young("1.0.0"), yank("1.1.0")]), current: Err(None) }), [], "all hidden, no header value: no value"),
	]
	bad = rows.keep_if(|(got, want, _)| got != want).map(|(_, _, label)| label)
	dbg bad
	bad == []
}
