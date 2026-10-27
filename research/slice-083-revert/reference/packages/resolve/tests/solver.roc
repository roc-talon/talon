app [main!] { resolve: "../main.roc" }

import resolve.Domain
import resolve.Solver

main! = |_args| Ok({})

# R-PK6 R-GP6: the solver step of the package `packages/resolve` (TESTING.md 2.2, part B): `step : Request -> [Need, Done, Fail]`. The package stays in the Talon repository.
# The expected value of each row is the design text (Resolution 1, 2 and 5: R-VA6, R-C1 to R-C4, R-C6, R-C7, R-C9, R-AL3, R-AL8, R-AL9), not the code. A row prints its label with `dbg` when it is wrong.
# A slot `a` has the releases `a-<version>` (the id of a release). The slots are in the order of `priority`. A step has `Highest` unless the row says `low`.

cand : Str, Str -> Domain.Candidate
cand = |name, v| { id: "${name}-${v}", version: v, published_at: 0, yanked: Bool.False }

slot : Str, [Package, Platform, Compiler], List(Str) -> Solver.Slot
slot = |name, kind, versions| { name, group: name, kind, candidates: versions.map(|v| cand(name, v)), ranges: [], current: Err(None), named: Err(None) }

pkg : Str, List(Str) -> Solver.Slot
pkg = |name, versions| slot(name, Package, versions)

pf : Str, List(Str) -> Solver.Slot
pf = |name, versions| slot(name, Platform, versions)

# The facts of all releases of the slots: the kind of the slot, no platform, no dep.
known : List(Solver.Slot) -> List(Solver.Fact)
known = |slots| slots.join_map(|s| s.candidates.map(|c| { id: c.id, kind: if s.kind == Package Package else Platform, pf: Err(None), deps: [] }))

# The fact of release `id` gets these deps (a dep is `group` and the lowest version), or this platform.
needs : List(Solver.Fact), Str, List((Str, Str)) -> List(Solver.Fact)
needs = |facts, id, deps| facts.map(|f| if f.id == id { ..f, deps: deps.map(|(group, version)| { group, version }) } else f)

on_pf : List(Solver.Fact), Str, Str -> List(Solver.Fact)
on_pf = |facts, id, url| facts.map(|f| if f.id == id { ..f, pf: Ok(url) } else f)

kind_of : List(Solver.Fact), Str, [Package, Platform, App] -> List(Solver.Fact)
kind_of = |facts, id, kind| facts.map(|f| if f.id == id { ..f, kind } else f)

req : List(Solver.Slot), List(Solver.Fact) -> Solver.Request
req = |slots, facts| { slots, rules: { now: 1000, min_age: 100, snapshot: Err(None), strategy: Highest }, facts, conflicts: [], compat: { domain: [], checks: [], used: [], probes: Allowed } }

low : Solver.Request -> Solver.Request
low = |r| { ..r, rules: { ..r.rules, strategy: Lowest } }

conflicting : Solver.Request, List(List(Solver.Term)) -> Solver.Request
conflicting = |r, conflicts| { ..r, conflicts: conflicts }

ask_id : Solver.Ask -> Str
ask_id = |a| match a {
	Header(id) => id
	Probe(p) => "${p.id}@${p.nightly}"
}

# A step as text: `done a=1.0.0 b=2.0.0` (in the order of the slots), `need a-1.0.0 b-2.0.0` (the ids, in the order of the slots), or `fail`. The reason of a `Fail` is a placeholder of slice 034 (slice 035 explains), so a row does not read it.
show : [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)] -> Str
show = |r| match r {
	Need(asks) => "need ${Str.join_with(asks.map(ask_id), " ")}"
	Done(chosen) => "done ${Str.join_with(chosen.map(|c| "${c.name}=${c.version}"), " ")}"
	Fail(_) => "fail"
}

step : Solver.Request -> Str
step = |r| show(Solver.step(r))

# The rows of an `expect`: a request, the step as text, a label. A row is wrong when the step differs, or when the step of the flipped request differs from it (R-DT2).
wrong : List((Solver.Request, Str, Str)) -> List(Str)
wrong = |rows| rows.keep_if(|(r, want, _)| step(r) != want or step(flipped(r)) != want).map(|(_, _, label)| label)

# The same request with the lists of the candidates, the facts and the conflicts reversed, and the terms of each conflict (R-DT2: the order of these lists does not change the result). The order of the slots does: it is `priority`.
flipped : Solver.Request -> Solver.Request
flipped = |r| { ..r, slots: r.slots.map(|s| { ..s, candidates: s.candidates.rev() }), facts: r.facts.rev(), conflicts: r.conflicts.rev().map(|c| c.rev()) }

# R-VA6 R-AL3: the best tuple by `priority`: the first slot gets its best value, then the second, and so on. `Highest` the highest version, `Lowest` the lowest. A later slot never changes an earlier one when a tuple exists.
# R-C3 makes the choice real: the package `x-2.0.0` needs the platform `pf-1.0.0`, and `x-1.0.0` needs `pf-2.0.0`, so the order of the slots decides which of the two is the newest. The cases of R-C1, R-C6, R-C7 and R-C9 go through the request.
expect {
	x = pkg("x", ["1.0.0", "2.0.0"])
	p = pf("pf", ["1.0.0", "2.0.0"])
	facts = known([x, p]) |> on_pf("x-2.0.0", "pf-1.0.0") |> on_pf("x-1.0.0", "pf-2.0.0")
	ab = [pkg("a", ["1.0.0", "2.0.0", "3.0.0"]), pkg("b", ["1.0.0", "2.0.0"])]
	ranged = { ..pkg("a", ["1.0.0", "2.0.0", "3.0.0"]), ranges: ["<3.0.0"] }
	yanked_top = { ..pkg("a", []), candidates: [cand("a", "1.0.0"), { ..cand("a", "2.0.0"), yanked: Bool.True }] }
	young_top = { ..pkg("a", []), candidates: [cand("a", "1.0.0"), { ..cand("a", "2.0.0"), published_at: 950 }] }
	held = { ..yanked_top, current: Ok({ id: "a-2.0.0", version: "2.0.0" }) }
	named_young = { ..young_top, named: Ok("2.0.0") }
	both_pf1 = known([x, p]) |> on_pf("x-2.0.0", "pf-1.0.0") |> on_pf("x-1.0.0", "pf-1.0.0")
	rows = [
		(req(ab, known(ab)), "done a=3.0.0 b=2.0.0", "highest: the best of each slot"),
		(low(req(ab, known(ab))), "done a=1.0.0 b=1.0.0", "lowest"),
		(req([x, p], facts), "done x=2.0.0 pf=1.0.0", "x first: x gets its best, the platform follows (R-C3)"),
		(req([p, x], facts), "done pf=2.0.0 x=1.0.0", "the platform first: it gets its best, x follows (R-C3)"),
		(low(req([x, p], facts)), "done x=1.0.0 pf=2.0.0", "lowest, x first"),
		(low(req([p, x], facts)), "done pf=1.0.0 x=2.0.0", "lowest, the platform first"),
		(req([ranged], known([ranged])), "done a=2.0.0", "R-C1: a range through the request"),
		(req([yanked_top], known([yanked_top])), "done a=1.0.0", "R-C6: a yanked release through the request"),
		(req([young_top], known([young_top])), "done a=1.0.0", "R-C7: too young, through the request and its rules"),
		(req([held], known([held])), "done a=2.0.0", "R-C9: the header value stays, through the request"),
		(req([named_young], known([named_young])), "done a=2.0.0", "R-C7: a named version is not too young, through the request"),
		(req([p, x], both_pf1), "done pf=1.0.0 x=2.0.0", "R-C3: the facts of the releases that lose count too: both x need pf-1.0.0, so the platform gives way"),
		(req([pkg("a", [])], []), "fail", "a slot with no release"),
		(req([ranged, pkg("b", [])], []), "fail", "the first slot is fine, the second has no release"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# R-AL8 R-AL9: the protocol. The step finds the best tuple with the facts that it has (a release with no fact is taken as fit). `Need` asks for the facts of the releases of that tuple that have none, in the order of the slots.
# A release that is not in the tuple is never asked for. `Done` only when each release of the tuple has a fact. A fact can change the best tuple (the next step asks for the new releases). `Fail` needs no fact: no tuple with the facts that exist is no tuple at all.
expect {
	ab = [pkg("a", ["1.0.0", "2.0.0"]), pkg("b", ["1.0.0", "2.0.0"])]
	all = known(ab)
	only = |ids| all.keep_if(|f| ids.contains(f.id))
	without = |ids| all.keep_if(|f| !ids.contains(f.id))
	a2_needs_b3 = only(["a-2.0.0"]) |> needs("a-2.0.0", [("b", "3.0.0")])
	rows = [
		(req(ab, []), "need a-2.0.0 b-2.0.0", "no fact: the best tuple"),
		(req(ab, only(["a-2.0.0"])), "need b-2.0.0", "only what is missing"),
		(req(ab, only(["b-2.0.0"])), "need a-2.0.0", "only what is missing, the first slot"),
		(req(ab, only(["a-2.0.0", "b-2.0.0"])), "done a=2.0.0 b=2.0.0", "the facts of the tuple: done"),
		(req(ab, without(["a-1.0.0", "b-1.0.0"])), "done a=2.0.0 b=2.0.0", "a release outside the tuple needs no fact"),
		(req([pkg("a", ["1.0.0"]), { ..pkg("b", []), candidates: [cand("a", "1.0.0")] }], []), "need a-1.0.0", "2 slots choose one release with no fact: the need names it once"),
		(req(ab, a2_needs_b3), "need a-1.0.0 b-2.0.0", "a fact changes the tuple: the new release is asked for, the next one stays"),
		(req(ab, a2_needs_b3.concat(only(["a-1.0.0", "b-2.0.0"]))), "done a=1.0.0 b=2.0.0", "the facts of the new tuple: done"),
		(req([pkg("a", ["1.0.0"]), pkg("b", ["1.0.0"])], only(["a-1.0.0"]) |> needs("a-1.0.0", [("b", "2.0.0")])), "fail", "a fact shows that no tuple exists: fail, no ask for b"),
		(req([{ ..pkg("a", ["1.0.0"]), ranges: [">=2.0.0"] }], []), "fail", "no value: fail, not a need"),
		(req([], []), "done ", "no slot: the empty tuple"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# R-C2: a dep of the chosen release on the group of another slot sets a lower limit for that slot: the slot has a value at or above the version (roc MVS: a direct pin is at least the highest version in the closure).
# Many deps on one group: the highest limit wins. A version is compared as a semver. The group is the key (`group`), not the name of the slot. The limit is checked against the domain (the ranges of the slot). A dep on a group that has no slot (a transitive group) is
# not read: the closure walk of the caller finds its problems (R-AL9). The same holds for a dep on the group of the slot of the release itself (a cycle).
expect {
	a2 = pkg("a", ["1.0.0", "2.0.0"])
	b3 = pkg("b", ["1.0.0", "2.0.0", "3.0.0"])
	c3 = pkg("c", ["1.0.0", "2.0.0", "3.0.0"])
	b19 = pkg("b", ["1.9.0", "1.10.0"])
	json = { ..pkg("json", ["1.0.0", "2.0.0"]), group: "acme/json" }
	b_low = { ..b3, ranges: ["<2.0.0"] }
	rows = [
		(req([a2, b3], known([a2, b3]) |> needs("a-2.0.0", [("b", "4.0.0")])), "done a=1.0.0 b=3.0.0", "a limit above all values excludes the release"),
		(low(req([a2, b3], known([a2, b3]) |> needs("a-1.0.0", [("b", "2.0.0")]))), "done a=1.0.0 b=2.0.0", "lowest: the slot gets the limit, the lowest value at or above it"),
		(low(req([a2, b3], known([a2, b3]) |> needs("a-1.0.0", [("b", "3.0.0")]))), "done a=1.0.0 b=3.0.0", "the limit is a value: allowed"),
		(low(req([a2, pkg("b", ["1.0.0"]), c3], known([a2, pkg("b", ["1.0.0"]), c3]) |> needs("a-1.0.0", [("c", "2.0.0")]) |> needs("b-1.0.0", [("c", "3.0.0")]))), "done a=1.0.0 b=1.0.0 c=3.0.0", "2 limits: the highest wins"),
		(low(req([a2, b19], known([a2, b19]) |> needs("a-1.0.0", [("b", "1.10.0")]))), "done a=1.0.0 b=1.10.0", "a semver: 1.10.0 is above 1.9.0"),
		(low(req([a2, b19], known([a2, b19]) |> needs("a-1.0.0", [("b", "1.9.0")]))), "done a=1.0.0 b=1.9.0", "a semver: 1.9.0 is the lowest value at or above 1.9.0"),
		(req([a2], known([a2]) |> needs("a-2.0.0", [("t", "5.0.0")])), "done a=2.0.0", "a dep on a group with no slot is not read"),
		(req([a2], known([a2]) |> needs("a-2.0.0", [("a", "3.0.0")])), "done a=2.0.0", "a dep on the own group is not read (a cycle: the closure walk of the caller finds it)"),
		(req([a2, json], known([a2, json]) |> needs("a-2.0.0", [("acme/json", "3.0.0")])), "done a=1.0.0 json=2.0.0", "the dep names the group: the slot json has the group acme/json"),
		(req([a2, json], known([a2, json]) |> needs("a-2.0.0", [("json", "3.0.0")])), "done a=2.0.0 json=2.0.0", "the name of a slot is not a group"),
		(low(req([a2, b_low], known([a2, b_low]) |> needs("a-1.0.0", [("b", "2.0.0")]))), "done a=2.0.0 b=1.0.0", "the limit is checked against the domain: the range <2.0.0 leaves no value at or above 2.0.0"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# R-C3 R-C4: one platform: a package release that names a platform needs that platform (the URL, byte for byte). With no platform slot, nothing is checked. A release that names no platform fits each platform.
# R-C4: the kind is a header fact. A `Package` slot takes only a release of the kind `Package`, a `Platform` slot only `Platform`. An `App` release is never a value. A release with no fact is taken as fit, so the step asks for it.
expect {
	x = pkg("x", ["1.0.0", "2.0.0"])
	p1 = pf("pf", ["1.0.0"])
	p2 = pf("pf", ["1.0.0", "2.0.0"])
	rows = [
		(req([x, p1], known([x, p1]) |> on_pf("x-2.0.0", "pf-9.0.0")), "done x=1.0.0 pf=1.0.0", "R-C3: a platform that is no value of the platform slot excludes the release"),
		(req([x], known([x]) |> on_pf("x-2.0.0", "pf-9.0.0")), "done x=2.0.0", "R-C3: no platform slot, no check"),
		(req([x, pf("p1", ["1.0.0"]), pf("p2", ["1.0.0"])], known([x, pf("p1", ["1.0.0"]), pf("p2", ["1.0.0"])]) |> on_pf("x-2.0.0", "p2-1.0.0")), "done x=2.0.0 p1=1.0.0 p2=1.0.0", "R-C3 (Q2): with 2 platform slots nothing is checked, so a platform that is the second one is no conflict"),
		(req([{ ..x, candidates: [cand("x", "1.0.0")] }, p2], known([x, p2])), "done x=1.0.0 pf=2.0.0", "R-C3: a release with no platform fits each platform"),
		(req([p2], known([p2]) |> kind_of("pf-2.0.0", Package)), "done pf=1.0.0", "R-C4: a platform slot refuses a package release"),
		(req([x], known([x]) |> kind_of("x-2.0.0", Platform)), "done x=1.0.0", "R-C4: a package slot refuses a platform release"),
		(req([x], known([x]) |> kind_of("x-2.0.0", App)), "done x=1.0.0", "R-C4: an app release is never a value of a package slot"),
		(req([p2], known([p2]) |> kind_of("pf-2.0.0", App)), "done pf=1.0.0", "R-C4: an app release is never a value of a platform slot"),
		(req([x], known([x]) |> kind_of("x-1.0.0", App) |> kind_of("x-2.0.0", Platform)), "fail", "R-C4: no release of the right kind: fail"),
		(req([p2], []), "need pf-2.0.0", "R-C4: no fact, the kind is taken as right: the step asks"),
		(req([p2], only_fact(known([p2]), "pf-2.0.0") |> kind_of("pf-2.0.0", Package)), "need pf-1.0.0", "R-C4: the fact shows the wrong kind: the next release is asked for"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

only_fact : List(Solver.Fact), Str -> List(Solver.Fact)
only_fact = |facts, id| facts.keep_if(|f| f.id == id)

inn : Str, List(Str) -> Solver.Term
inn = |name, ids| { name, ids, sign: In }

not_in : Str, List(Str) -> Solver.Term
not_in = |name, ids| { name, ids, sign: NotIn }

# Terms and incompatibilities of the caller (`conflicts`): the terms of one conflict cannot all be true. The solver finds the best tuple that breaks none. These rows need the work of PubGrub: a conflict that shows only after a decision (the solver learns
# the decisions and goes back), a chain of unit propagation, and a conflict that leaves no tuple. `In` is a set of values, `NotIn` the other values. An id that is no value, and a name that is no slot, make a term that is never true, so the conflict never applies.
expect {
	abc = [pkg("a", ["1.0.0", "2.0.0"]), pkg("b", ["1.0.0", "2.0.0"]), pkg("c", ["1.0.0", "2.0.0"])]
	r = |conflicts| conflicting(req(abc, known(abc)), conflicts)
	abcd = [pkg("a", ["1.0.0", "2.0.0"]), pkg("b", ["1.0.0", "2.0.0"]), pkg("c", ["1.0.0", "2.0.0"]), pkg("d", ["1.0.0", "2.0.0"])]
	cd = |c, d| [inn("a", ["a-2.0.0"]), inn("c", [c]), inn("d", [d])]
	deep = [cd("c-2.0.0", "d-2.0.0"), cd("c-2.0.0", "d-1.0.0"), cd("c-1.0.0", "d-1.0.0"), cd("c-1.0.0", "d-2.0.0")]
	rows = [
		(r([]), "done a=2.0.0 b=2.0.0 c=2.0.0", "no conflict"),
		(r([[inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"])]]), "done a=2.0.0 b=1.0.0 c=2.0.0", "2 terms: a takes its best, b gives way"),
		(r([[inn("a", ["a-2.0.0"])]]), "done a=1.0.0 b=2.0.0 c=2.0.0", "one term: the value is out"),
		(r([[not_in("a", ["a-1.0.0"]), not_in("b", ["b-2.0.0"])]]), "done a=2.0.0 b=2.0.0 c=2.0.0", "NotIn: a=2 is not in {a-1}, b=2 is in {b-2}: the conflict does not hold"),
		(r([[inn("a", ["a-2.0.0"]), not_in("b", ["b-1.0.0"])]]), "done a=2.0.0 b=1.0.0 c=2.0.0", "NotIn: a=2 and b other than b-1 cannot hold together, so b is b-1"),
		(r([[inn("b", ["b-2.0.0"]), inn("c", ["c-1.0.0"])], [inn("b", ["b-2.0.0"]), inn("c", ["c-2.0.0"])]]), "done a=2.0.0 b=1.0.0 c=2.0.0", "a conflict after a decision: b=2 leaves no value for c, so b=1"),
		(r([[inn("a", ["a-2.0.0"]), inn("b", ["b-1.0.0"])], [inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"])]]), "done a=1.0.0 b=2.0.0 c=2.0.0", "a=2 leaves no value for b: a goes back to its second best"),
		(r([[inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"])], [inn("b", ["b-2.0.0"]), inn("c", ["c-2.0.0"])]]), "done a=2.0.0 b=1.0.0 c=2.0.0", "a chain: b gives way, then the second conflict does not hold"),
		(r([[inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"]), inn("c", ["c-2.0.0"])]]), "done a=2.0.0 b=2.0.0 c=1.0.0", "3 terms: the last slot gives way"),
		(r([[inn("a", ["a-9.0.0"])]]), "done a=2.0.0 b=2.0.0 c=2.0.0", "an id that is no value: never true"),
		(r([[inn("z", ["z-1.0.0"]), inn("a", ["a-2.0.0"])]]), "done a=2.0.0 b=2.0.0 c=2.0.0", "a name that is no slot: never applies"),
		(r([[inn("a", ["a-1.0.0", "a-2.0.0"])]]), "fail", "all values of a are out"),
		(r([[not_in("a", [])]]), "fail", "NotIn of no id is all values"),
		(r([[]]), "fail", "a conflict with no term is always true: no tuple"),
		(r([[inn("a", ["a-1.0.0"]), inn("b", ["b-1.0.0"])], [inn("a", ["a-1.0.0"]), inn("b", ["b-2.0.0"])], [inn("a", ["a-2.0.0"]), inn("b", ["b-1.0.0"])], [inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"])]]), "fail", "no pair of a and b is left"),
		(conflicting(req(abc, []), [[inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"])]]), "need a-2.0.0 b-1.0.0 c-2.0.0", "the conflict and the need together: the facts of the new tuple"),
		(r([[inn("a", ["a-1.0.0"]), inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"])]]), "done a=2.0.0 b=2.0.0 c=2.0.0", "2 terms of one slot with no common value: never true"),
		(r([[inn("a", ["a-1.0.0", "a-2.0.0"]), inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"])]]), "done a=2.0.0 b=1.0.0 c=2.0.0", "2 terms of one slot: the values that both hold"),
		(conflicting(req(abcd, known(abcd)), deep), "done a=1.0.0 b=2.0.0 c=2.0.0 d=2.0.0", "a conflict 3 decisions deep: a=2 has no tuple, but c=2 and b=2 stay valid for a=1"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}
