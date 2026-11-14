import resolve.Domain
import resolve.Solver
import lib.Explain
import lib.Ident
import lib.Oracle
import lib.OracleRequest

SolverifaceTest :: [].{}

# Slice 248: the solver interface (Resolution 5, "The solver step": R-AL13 to R-AL17) and the `no_tuple` text (R-AL10, R-AL11). The expected value of each row is the design text, not the code.
# Part 1 calls `Solver.step` and `Solver.step_moves` of the package `packages/resolve` (the solver step, TESTING.md 2.2 part B). Part 2 calls `Oracle.step_probed` and `Oracle.step_free` (the oracle step of the CLI: the solver with the probe facts, and the text of a `Fail`).
# A row prints its label with `dbg` when it is wrong.

# ---- Part 1: the solver step ----

# A slot `a` has the releases `a-<version>` (the id of a release). The slots are in the order of `priority`. A step has `Highest` unless the row says `low`.
cand : Str, Str -> Domain.Candidate
cand = |name, v| { id: "${name}-${v}", version: v, published_at: 0, yanked: Bool.False }

pkg : Str, List(Str) -> Solver.Slot
pkg = |name, versions| { name, group: name, kind: Package, candidates: versions.map(|v| cand(name, v)), ranges: [], current: Err(None), named: Err(None) }

pf : Str, List(Str) -> Solver.Slot
pf = |name, versions| { ..pkg(name, versions), kind: Platform }

# The compiler slot: only the ids of the candidates are read.
roc : List(Str) -> Solver.Slot
roc = |ids| { name: "roc", group: "roc", kind: Compiler, candidates: ids.map(|id| { id, version: id, published_at: 0, yanked: Bool.False }), ranges: [], current: Err(None), named: Err(None) }

# D, oldest first (R-EP11).
d4 : List(Str)
d4 = ["n1", "n2", "n3", "n4"]

# The header facts of all releases of the slots (no compiler): the kind of the slot, no platform, no dep.
known : List(Solver.Slot) -> List(Solver.Fact)
known = |slots| slots.keep_if(|s| s.kind != Compiler).join_map(|s| s.candidates.map(|c| { id: c.id, kind: if s.kind == Platform Platform else Package, pf: Err(None), deps: [] }))

needs : List(Solver.Fact), Str, List((Str, Str)) -> List(Solver.Fact)
needs = |facts, id, deps| facts.map(|f| if f.id == id { ..f, deps: deps.map(|(group, version)| { group, version }) } else f)

on_pf : List(Solver.Fact), Str, Str -> List(Solver.Fact)
on_pf = |facts, id, url| facts.map(|f| if f.id == id { ..f, pf: Ok(url) } else f)

req : List(Solver.Slot), List(Solver.Fact) -> Solver.Request
req = |slots, facts| { slots, rules: { now: 1000, min_age: 100, snapshot: Err(None), strategy: Highest }, facts, conflicts: [], compat: { domain: d4, checks: [], used: [], probes: Allowed } }

low : Solver.Request -> Solver.Request
low = |r| { ..r, rules: { ..r.rules, strategy: Lowest } }

off : Solver.Request -> Solver.Request
off = |r| { ..r, compat: { ..r.compat, probes: Off } }

checked : Solver.Request, List(Solver.Check) -> Solver.Request
checked = |r, checks| { ..r, compat: { ..r.compat, checks } }

conflicting : Solver.Request, List(List(Solver.Term)) -> Solver.Request
conflicting = |r, conflicts| { ..r, conflicts }

inn : Str, List(Str) -> Solver.Term
inn = |name, ids| { name, ids, sign: In }

chk : Str, Str, [Pass, Fail, Hang, Crash] -> Solver.Check
chk = |id, nightly, outcome| { id, nightly, outcome, modules: [], source: Real }

ask_text : Solver.Ask -> Str
ask_text = |a| match a {
	Header(id) => "header ${id}"
	Probe(p) => "probe ${p.id}@${p.nightly}"
}

term_text : Solver.Term -> Str
term_text = |t| "${t.name}:${if t.sign == In "" else "!"}{${Str.join_with(t.ids, ",")}}"

cause_text : Solver.Cause -> Str
cause_text = |c| match c {
	Probe(p) => {
		kind = if p.kind == Fail "fail" else "fault"
		"probe ${p.id} ${kind} ${p.from}..${p.to} [${Str.join_with(p.modules, ",")}] inferred [${Str.join_with(p.inferred, ",")}]"
	}
	Dep(d) => "dep ${d.id} ${d.group}>=${d.version}"
	Pf(f) => "pf ${f.id} ${f.pf}"
	Given => "given"
	NoValue(name) => "none ${name}"
	Derived(a, b) => "derived ${a.to_str()} ${b.to_str()}"
}

step_text : Solver.Step -> Str
step_text = |s| {
	terms = if s.terms.is_empty() "true" else Str.join_with(s.terms.map(term_text), " & ")
	"${terms} <- ${cause_text(s.cause)}"
}

show : [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)] -> Str
show = |r| match r {
	Need(asks) => "need ${Str.join_with(asks.map(ask_text), ", ")}"
	Done(chosen) => "done ${Str.join_with(chosen.map(|c| "${c.name}=${c.id}"), " ")}"
	Fail(_) => "fail"
}

step : Solver.Request -> Str
step = |r| show(Solver.step(r))

# The steps of the explanation of a `Fail`, as text (`[]` for no `Fail`).
why : [Need(List(Solver.Ask)), Done(List(Solver.Chosen)), Fail(Solver.Why)] -> List(Solver.Step)
why = |r| match r {
	Fail(w) => w.steps
	_ => []
}

# The leaves of an explanation (the steps that are no `Derived`), as text.
leaves : List(Solver.Step) -> List(Str)
leaves = |steps| steps.keep_if(
	|s| match s.cause {
		Derived(_, _) => Bool.False
		_ => Bool.True
	},
).map(step_text)

report : List((Str, Str, Str)) -> Bool
report = |rows| {
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-AL13 R-VA6 R-C1 R-C7 R-C9: a variable is a slot, and its values are the candidates that section 2 allows, best first. A package or a platform: by semver, the highest first with `highest`, the lowest first with `lowest` (1.10.0 is above 1.9.0).
# Two ids of one version are in the byte order of the ids (for both strategies). A version that does not parse is not a value: a slot with only such a candidate has no value (`NoValue`). A range still excludes the header value (R-C9).
# The values are seen through the best tuple: a conflict of the caller that excludes the best value gives the next value.
expect {
	a = pkg("a", ["1.0.0", "1.9.0", "1.10.0"])
	twin = { ..pkg("a", []), candidates: [{ id: "a-1.0.0-z", version: "1.0.0", published_at: 0, yanked: Bool.False }, { id: "a-1.0.0-b", version: "1.0.0", published_at: 0, yanked: Bool.False }] }
	bad = { ..pkg("a", ["1.0.0"]), candidates: [cand("a", "1.0.0"), { id: "a-junk", version: "1.x", published_at: 0, yanked: Bool.False }] }
	only_bad = { ..pkg("a", []), candidates: [{ id: "a-junk", version: "1.x", published_at: 0, yanked: Bool.False }] }
	held = { ..pkg("a", ["1.0.0", "2.0.0"]), current: Ok({ id: "a-1.0.0", version: "1.0.0" }) }
	report([
		("highest: 1.10.0 is the best value (semver, not text)", step(req([a], known([a]))), "done a=a-1.10.0"),
		("highest: without 1.10.0 the next value is 1.9.0", step(conflicting(req([a], known([a])), [[inn("a", ["a-1.10.0"])]])), "done a=a-1.9.0"),
		("lowest: 1.0.0 is the best value", step(low(req([a], known([a])))), "done a=a-1.0.0"),
		("lowest: without 1.0.0 the next value is 1.9.0", step(conflicting(low(req([a], known([a]))), [[inn("a", ["a-1.0.0"])]])), "done a=a-1.9.0"),
		("one version, 2 ids, highest: the byte order of the ids", step(req([twin], known([twin]))), "done a=a-1.0.0-b"),
		("one version, 2 ids, lowest: the byte order of the ids", step(low(req([twin], known([twin])))), "done a=a-1.0.0-b"),
		("a version that does not parse is not a value", step(low(req([bad], known([bad])))), "done a=a-1.0.0"),
		("a version that does not parse is not a value, also as the best text", step(conflicting(req([bad], known([bad])), [[inn("a", ["a-1.0.0"])]])), "fail"),
		("a slot with only a version that does not parse has no value", Str.join_with(leaves(why(Solver.step(req([only_bad], known([only_bad]))))), "\n"), "true <- none a"),
		("lowest keeps the header value when no range excludes it (R-C9)", step(low(req([held], known([held])))), "done a=a-1.0.0"),
		("a range excludes the header value (R-C9, R-C1)", step(low(req([{ ..held, ranges: ["^2"] }], known([held])))), "done a=a-2.0.0"),
	])
}

# R-AL13 R-EP11 R-VA6: the values of the compiler slot are the releases of D, in the order of D: the newest first with `highest`, the oldest first with `lowest`. A candidate that is not in D is not a value. A compiler slot with no candidate in D has no value.
# A transitive group is no variable (R-AL9): a dep on a group that no slot has is not read here (the closure walk of the caller checks it).
expect {
	a = pkg("a", ["1.0.0"])
	facts = known([a])
	report([
		("highest: the newest compiler of D", step(checked(req([a, roc(["n1", "n2", "n3"])], facts), [chk("a-1.0.0", "n3", Pass)])), "done a=a-1.0.0 roc=n3"),
		("lowest: the oldest compiler of D", step(checked(low(req([a, roc(["n1", "n2", "n3"])], facts)), [chk("a-1.0.0", "n1", Pass)])), "done a=a-1.0.0 roc=n1"),
		("a compiler that is not in D is not a value (n9)", step(checked(req([a, roc(["n2", "n9"])], facts), [chk("a-1.0.0", "n2", Pass)])), "done a=a-1.0.0 roc=n2"),
		("no compiler of the slot is in D: no value", Str.join_with(leaves(why(Solver.step(req([a, roc(["n9"])], facts)))), "\n"), "true <- none roc"),
		("a dep on a transitive group (no slot) is no variable and is not read", step(req([a], needs(facts, "a-1.0.0", [("t", "9.0.0")]))), "done a=a-1.0.0"),
	])
}

# R-AL14 R-C7 R-WS2 R-EP9: the request has the slots, the rules (`now`, `min-release-age`, `snapshot`, `strategy`), the header facts, the conflicts of the caller and the compatibility record (D, the checks, the used modules, the probe mode).
# The rules hide a release that is too young (R-C7: `now` 1000, `min-release-age` 100) or after the snapshot. The conflicts of the caller for 2 slots of one group (`OracleRequest.same_group`, R-WS2) make the 2 slots take one value.
# The probe mode: with `Allowed` a pair with no real fact is a probe ask; with `Off` the pair is fit and the step is `Done` (R-EP9).
expect {
	young = { ..pkg("a", ["1.0.0"]), candidates: [cand("a", "1.0.0"), { id: "a-2.0.0", version: "2.0.0", published_at: 950, yanked: Bool.False }] }
	late = { ..pkg("a", ["1.0.0"]), candidates: [cand("a", "1.0.0"), { id: "a-2.0.0", version: "2.0.0", published_at: 500, yanked: Bool.False }] }
	snap = |r| { ..r, rules: { ..r.rules, snapshot: Ok(400) } }
	# Two slots of one group (acme/json series 1, release URLs: `same_group` reads the group from the URL): s0 has 1.0.0 and 1.1.0, s1 has 1.0.0 only (an older member). Without the conflict, s0 takes 1.1.0 and s1 1.0.0.
	g1 = u("json", "1.0.0")
	g2 = u("json", "1.1.0")
	url_cand = |id, v| { id, version: v, published_at: 0, yanked: Bool.False }
	s0 = { ..pkg("s0", []), group: "json", candidates: [url_cand(g1, "1.0.0"), url_cand(g2, "1.1.0")] }
	s1 = { ..pkg("s1", []), group: "json", candidates: [url_cand(g1, "1.0.0")] }
	both = [s0, s1]
	a = pkg("a", ["1.0.0"])
	with_roc = req([a, roc(["n3"])], known([a]))
	report([
		("a release younger than min-release-age is not a value (R-C7)", step(req([young], known([young]))), "done a=a-1.0.0"),
		("a release after the snapshot is not a value", step(snap(req([late], known([late])))), "done a=a-1.0.0"),
		("the same release before the snapshot is a value", step(req([late], known([late]))), "done a=a-2.0.0"),
		("2 slots of one group, no conflict: each takes its own best value", step(req(both, known(both))), "done s0=${g2} s1=${g1}"),
		("2 slots of one group with the conflicts of R-WS2: one value", step(conflicting(req(both, known(both)), OracleRequest.same_group(both))), "done s0=${g1} s1=${g1}"),
		("probe mode Allowed: the pair with no real fact is asked", step(with_roc), "need probe a-1.0.0@n3"),
		("probe mode Off: the pair with no fact is fit", step(off(with_roc)), "done a=a-1.0.0 roc=n3"),
	])
}

# R-AL15 R-AL8 R-AL4 R-EP8: the answer. `Need`: the asks are for the best tuple only, headers before probes (a header first: the release may be of a wrong kind, R-C4), in the order of the slots. `Done`: the best tuple when each release has its facts.
# A release with no fact is taken as fit until its fact comes. `Fail`: no tuple, with the explanation.
expect {
	a = pkg("a", ["1.0.0", "2.0.0"])
	b = pkg("b", ["1.0.0", "2.0.0"])
	slots = [a, b, roc(["n3"])]
	all = known([a, b])
	pass_all = ["a-1.0.0", "a-2.0.0", "b-1.0.0", "b-2.0.0"].map(|id| chk(id, "n3", Pass))
	report([
		("no header fact: headers of the best tuple only, no probe yet", step(req(slots, [])), "need header a-2.0.0, header b-2.0.0"),
		("one header missing: only that header, no probe yet", step(req(slots, all.keep_if(|f| f.id != "b-2.0.0"))), "need header b-2.0.0"),
		("all headers, no check: the probes of the best tuple, in the order of the slots", step(req(slots, all)), "need probe a-2.0.0@n3, probe b-2.0.0@n3"),
		("all facts: done", step(checked(req(slots, all), pass_all)), "done a=a-2.0.0 b=b-2.0.0 roc=n3"),
		("a release with no header is fit: a-2.0.0 is asked, not passed over", step(req([a], all.keep_if(|f| f.id != "a-2.0.0"))), "need header a-2.0.0"),
		("the header shows a wrong kind: the next value", step(req([a], all.map(|f| if f.id == "a-2.0.0" { ..f, kind: Platform } else f))), "done a=a-1.0.0"),
		("no tuple: fail", step(conflicting(req([a], all), [[inn("a", ["a-1.0.0", "a-2.0.0"])]])), "fail"),
	])
}

# R-AL15 R-C2 R-C3: R-C3 is checked when the request has exactly one platform slot. R-C2 and R-C3 are checked only between the slots.
expect {
	x = pkg("x", ["1.0.0"])
	p = pf("p", ["1.0.0", "2.0.0"])
	q = pf("q", ["1.0.0"])
	c = pkg("c", ["1.0.0", "2.0.0"])
	one = [x, p]
	two = [x, p, q]
	report([
		("one platform slot: the release names p-1.0.0, so p is p-1.0.0", step(req(one, on_pf(known(one), "x-1.0.0", "p-1.0.0"))), "done x=x-1.0.0 p=p-1.0.0"),
		("2 platform slots: R-C3 is not checked", step(req(two, on_pf(known(two), "x-1.0.0", "p-1.0.0"))), "done x=x-1.0.0 p=p-2.0.0 q=q-1.0.0"),
		("R-C2 between slots: x needs c >= 2.0.0, so c is 2.0.0 also with lowest", step(low(req([x, c], needs(known([x, c]), "x-1.0.0", [("c", "2.0.0")])))), "done x=x-1.0.0 c=c-2.0.0"),
		("R-C2 not between slots: a dep on a group with no slot is not read", step(low(req([x], needs(known([x]), "x-1.0.0", [("c", "2.0.0")])))), "done x=x-1.0.0"),
	])
}

# R-AL16 R-AL3 R-EP7 R-AL5: PubGrub with unit propagation and conflict learning. A learned incompatibility of a probe (R-EP7) and a conflict of the caller have one form: a set of terms that cannot all be true.
# The same set of terms from a probe fail or from the caller gives the same answer, and the leaves of the 2 explanations have the same terms (only the cause differs).
# A coloring of 3 slots that must all differ, with 2 values each, has no tuple. 9 free slots before 2 slots with no tuple: the search learns the conflict and does not try the 2^9 tuples of the first slots (the step is fast; a search with no learning takes about 13 s).
expect {
	a = pkg("a", ["1.0.0", "2.0.0"])
	base = req([a, roc(["n3"])], known([a]))
	by_probe = checked(base, [chk("a-2.0.0", "n3", Fail), chk("a-1.0.0", "n3", Fail)])
	by_caller = conflicting(base, [[inn("a", ["a-2.0.0"])], [inn("a", ["a-1.0.0"])]])
	terms_of = |r| leaves(why(Solver.step(r))).map(|s| s.split_on(" <- ").first() ?? "")
	half_probe = checked(base, [chk("a-2.0.0", "n3", Fail), chk("a-1.0.0", "n3", Pass)])
	half_caller = checked(conflicting(base, [[inn("a", ["a-2.0.0"]), inn("roc", ["n3"])]]), [chk("a-1.0.0", "n3", Pass)])
	ring = [pkg("x", ["1.0.0", "2.0.0"]), pkg("y", ["1.0.0", "2.0.0"]), pkg("z", ["1.0.0", "2.0.0"])]
	differ = |p, q| ["1.0.0", "2.0.0"].map(|v| [inn(p, ["${p}-${v}"]), inn(q, ["${q}-${v}"])])
	coloring = conflicting(req(ring, known(ring)), differ("x", "y").concat(differ("y", "z")).concat(differ("x", "z")))
	free = ["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9"].map(|name| pkg(name, ["1.0.0", "2.0.0"]))
	xy = [pkg("x", ["1.0.0", "2.0.0"]), pkg("y", ["1.0.0", "2.0.0"])]
	tail = conflicting(req(free.concat(xy), known(free.concat(xy))), differ("x", "y").concat([[inn("x", ["x-1.0.0"]), inn("y", ["y-2.0.0"])], [inn("x", ["x-2.0.0"]), inn("y", ["y-1.0.0"])]]))
	report([
		("a probe fail and a caller conflict give the same answer", step(half_probe), step(half_caller)),
		("the probe fail answer is the other value", step(half_probe), "done a=a-1.0.0 roc=n3"),
		("the leaves of a probe proof and a caller proof have the same terms", Str.join_with(terms_of(by_probe), "\n"), Str.join_with(terms_of(by_caller), "\n")),
		("the leaves of the probe proof: one term for each fail (the compiler term holds all values: left out)", Str.join_with(terms_of(by_probe), "\n"), "a:{a-2.0.0}\na:{a-1.0.0}"),
		("3 slots that must all differ, 2 values each: no tuple", step(coloring), "fail"),
		("9 free slots, then 2 slots with no tuple: fail, fast", step(tail), "fail"),
	])
}

# R-AL17: the explanation of a `Fail` is a graph of steps. Each step has terms and a cause: `Probe`, `Dep`, `Pf`, `Given`, `NoValue` or `Derived` (the join of 2 earlier steps). The last step has no term.
# The terms are the slots in the order of the slots, with their ids best first (with `highest` the newest compiler and the highest version first). A term with all values of its slot is left out. A `NoValue` step has no term.
# A `Probe` cause has the release, the first and the last compiler of the fail run, the failing modules that the app uses, and the compilers whose fail is inferred.
expect {
	x = pkg("x", ["1.0.0", "2.0.0"])
	c = pkg("c", ["1.0.0", "2.0.0"])
	p = pf("p", ["1.0.0", "2.0.0"])
	# x 2.0.0 needs c >= 3.0.0 (no such value), x 1.0.0 is excluded by the caller.
	dep_req = conflicting(req([x, c], needs(known([x, c]), "x-2.0.0", [("c", "3.0.0")])), [[inn("x", ["x-1.0.0"])]])
	# x needs p 9.0.0 (no such URL): R-C3 excludes each value of p for x 2.0.0.
	pf_req = conflicting(req([x, p], on_pf(known([x, p]), "x-2.0.0", "p-9.0.0")), [[inn("x", ["x-1.0.0"])]])
	# x fails on n1, n2 and n3 (hard fails), passes on n4. roc has n2, n3 (n4 not a value). D is n1 to n4.
	x2 = pkg("x", ["1.0.0"])
	probe_req = checked(req([x2, roc(["n2", "n3"])], known([x2])), [chk("x-1.0.0", "n1", Fail), chk("x-1.0.0", "n2", Fail), chk("x-1.0.0", "n3", Fail), chk("x-1.0.0", "n4", Pass)])
	last_empty = |r| match why(Solver.step(r)).last() {
		Ok(s) => s.terms.is_empty()
		Err(_) => Bool.False
	}
	derived_back = |r| why(Solver.step(r)).map_with_index(|s, i| (s, i)).all(
		|(s, i)| match s.cause {
			Derived(a, b) => a < i and b < i
			_ => Bool.True
		},
	)
	report([
		("Dep: the release, the group and the version; the term of c holds all values: left out", Str.join_with(leaves(why(Solver.step(dep_req))), "\n"), "x:{x-2.0.0} <- dep x-2.0.0 c>=3.0.0\nx:{x-1.0.0} <- given"),
		("Pf: the release and the URL that it names", Str.join_with(leaves(why(Solver.step(pf_req))), "\n"), "x:{x-2.0.0} <- pf x-2.0.0 p-9.0.0\nx:{x-1.0.0} <- given"),
		("Probe: the run n1 .. n3 (the maximal fail run of D)", Str.join_with(leaves(why(Solver.step(probe_req))), "\n"), "true <- probe x-1.0.0 fail n1..n3 [] inferred []"),
		("the last step has no term (dep)", if last_empty(dep_req) "yes" else "no", "yes"),
		("the last step has no term (probe)", if last_empty(probe_req) "yes" else "no", "yes"),
		("a Derived step names 2 earlier steps", if derived_back(dep_req) and derived_back(pf_req) "yes" else "no", "yes"),
	])
}

# R-AL17 R-SP24: in the second search of a held move (`Solver.step_moves`), the movable slot `b` is first in the search, but the terms of each step are still in the order of the slots: `a` before `b`.
# a and b have 2 values each, and each of the 4 tuples is a conflict of the caller. Slice 248: red (the terms are in the order of the search now).
expect {
	a = pkg("a", ["1.0.0", "2.0.0"])
	b = { ..pkg("b", ["1.0.0", "2.0.0"]), current: Ok({ id: "b-1.0.0", version: "1.0.0" }) }
	all4 = ["1.0.0", "2.0.0"].join_map(|va| ["1.0.0", "2.0.0"].map(|vb| [inn("a", ["a-${va}"]), inn("b", ["b-${vb}"])]))
	r = conflicting(req([a, b], known([a, b])), all4)
	order = |steps| steps.all(
		|s| match s.terms {
			[first, second] => first.name == "a" and second.name == "b"
			_ => Bool.True
		},
	)
	steps = why(Solver.step_moves(r, ["b"]))
	report([
		("the plain step: a fail", step(r), "fail"),
		("the second search: a fail", show(Solver.step_moves(r, ["b"])), "fail"),
		("the second search: some step has terms of a and b", if steps.any(|s| s.terms.len() == 2) "yes" else "no", "yes"),
		("the second search: the terms are in the order of the slots", if order(steps) "yes" else Str.join_with(steps.map(step_text), "\n"), "yes"),
	])
}

# ---- Part 2: the text of a `Fail` (R-AL10, R-AL11), through the oracle step of the CLI ----

now = 1792065600

day = 86400

# D (oldest first): 5 nightlies. n3 is the held compiler H.
n1 = "nightly-2026-10-01-1111111"

n2 = "nightly-2026-10-02-2222222"

n3 = "nightly-2026-10-03-3333333"

n4 = "nightly-2026-10-04-4444444"

n5 = "nightly-2026-10-05-5555555"

d5 = [n1, n2, n3, n4, n5]

u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

hash = |url| match Ident.of_url(url) {
	Ok(ident) => ident.hash
	Err(_) => crash "bad test URL"
}

ocand = |url| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - 30 * day, size: 1 }
	Err(_) => crash "bad test URL"
}

# A held slot with its header value (one value).
held_slot = |id, url| { id, is_platform: Bool.False, ranges: [], current: Ok(url), hold: Held, named: Err(None), candidates: [ocand(url)], files: [] }

pkg_fact = |url| { url, release: { kind: Package, pf: Err(None), deps: [] } }

pf_fact = |url| { url, release: { kind: Platform, pf: Err(None), deps: [] } }

input = |slots, facts| { slots, strategy: Highest, now, min_age: 2 * day, exclude: [], snapshot: Err(None), facts, unmanaged: [], paths: [], second: Bool.False }

row = |url, id, outcome, modules| { hash: hash(url), nightly: id, target: "any", outcome, modules, closure: "" }

compat = |checks, used| { compiler: Ok(n3), checks, looked: [], probes: Allowed, conflicts: [], used, domain: Ok(d5), inferred: [], failed: Other }

json = u("json", "1.0.0")

lib = u("lib", "1.0.0")

pfu = u("pf", "0.1.0")

json_slot = held_slot("json", json)

lib_slot = held_slot("lib", lib)

pf_slot = { ..held_slot("pf", pfu), is_platform: Bool.True }

facts = [pkg_fact(json), pkg_fact(lib), pf_fact(pfu)]

# The message of a `Fail`, else the kind of the verdict.
message = |verdict| match verdict {
	Fail(fail) => fail.message
	Done(_) => "done"
	Need(_) => "need"
	Pairs(_) => "pairs"
	Scan(_) => "scan"
	Wide => "wide"
}

first_line = |text| text.split_on("\n").first() ?? ""

# The lines between the first line and the fix block (the cause lines of R-AL11).
cause_lines = |text| text.split_on("\n").drop_first(1).keep_if(|l| !l.starts_with("  fix:") and !l.starts_with("       or "))

probed = |slots, checks, used| message(Oracle.step_probed(input(slots, facts), compat(checks, used)))

# `tln upgrade roc`: the packages are held, the compiler is free over the askable compilers H, n4 and n5.
upgraded = |slots, checks| match Oracle.step_free(input(slots, facts), compat(checks, []), Ok([n3, n4, n5])) {
	Fail(fail) => fail.message
	Done(_) => "done"
	Need(_) => "need"
	Pairs(_) => "pairs"
	Scan(_) => "scan"
	Wide => "wide"
}

head = "no tuple works: the unit check on ${n3} fails for "

# R-AL10 R-UM1 R-LD3: the first line. `no tuple works: ` and the reason of the solver: the unit check on the held nightly fails for each release that the proof blames, with the failing modules that the app uses (`(Yaml.roc)`),
# or `(no module is named)` when the fail has no module (a platform fail). More than one blamed release: joined with `; `. (`tln: error[no_tuple]: ` is `Fail.line`, R-E4: the L2 cases check it.)
# A fault (a hang or a crash) on the first line: question Q-248-1 of the slice file, no row here.
expect {
	yaml = [{ id: json, modules: ["Yaml.roc"] }]
	# 2 blamed releases: the `tln upgrade roc` world of the last expect (json fails on H and n4, lib fails on n5): the proof needs both.
	two = upgraded([json_slot, lib_slot], [row(json, n2, Pass, []), row(json, n3, Fail, []), row(json, n4, Fail, []), row(json, n5, Pass, []), row(lib, n4, Pass, []), row(lib, n5, Fail, [])])
	blames = first_line(two).drop_prefix(head).split_on("; ")
	report([
		("a hard fail (no module)", first_line(probed([json_slot], [row(json, n3, Fail, [])], [])), "${head}acme/json 1.0.0 (no module is named)"),
		("a fail in a used module", first_line(probed([json_slot], [row(json, n3, Fail, ["Yaml.roc"])], yaml)), "${head}acme/json 1.0.0 (Yaml.roc)"),
		("a platform fail", first_line(probed([pf_slot], [row(pfu, n3, Fail, [])], [])), "${head}the platform acme/pf 0.1.0 (no module is named)"),
		("2 blamed releases: the head", if first_line(two).starts_with(head) "yes" else first_line(two), "yes"),
		("2 blamed releases, joined with '; '", Str.join_with(blames.sort_with(|p, q| if p == q Same else if p.starts_with("acme/json") Before else After), " | "), "acme/json 1.0.0 (no module is named) | acme/lib 1.0.0 (no module is named)"),
	])
}

# R-AL11 R-EP7 R-EP9: the cause lines. One line for each blamed release: `  <label> fails on <from> .. <to>`, the fail run of R-EP7. `hangs` and `crashes` replace `fails` for a hang and a crash.
# A run of one compiler has `on <id>` and no range, and no line when it is the held nightly alone (the first line has it). An inferred compiler in the run gives the mark `(inferred on <id>, ...)`.
expect {
	run3 = [row(json, n1, Pass, []), row(json, n2, Fail, []), row(json, n3, Fail, []), row(json, n4, Fail, []), row(json, n5, Pass, [])]
	alone = [row(json, n2, Pass, []), row(json, n3, Fail, []), row(json, n4, Pass, [])]
	hang_h = [row(json, n2, Pass, []), row(json, n3, Hang, []), row(json, n4, Pass, [])]
	inferred = Explain.lines({ causes: [{ label: "acme/json 1.0.0", alias: "json", kind: Fail, modules: [], from: n2, to: n4, inferred: [n3, n4] }], hint: Err(None), failed: Other })
	report([
		("a fail run around H", Str.join_with(cause_lines(probed([json_slot], run3, [])), "\n"), "  acme/json 1.0.0 fails on ${n2} .. ${n4}"),
		("a fail on H alone: no cause line", Str.join_with(cause_lines(probed([json_slot], alone, [])), "\n"), ""),
		("a hang on H alone: no cause line (a fault is the interval of H)", Str.join_with(cause_lines(probed([json_slot], hang_h, [])), "\n"), ""),
		("the inferred mark", Str.join_with(inferred.keep_if(|l| !l.starts_with("  fix:") and !l.starts_with("       or ")), "\n"), "  acme/json 1.0.0 fails on ${n2} .. ${n4} (inferred on ${n3}, ${n4})"),
	])
}

# R-AL11 R-SP12 (slice 248, red): `tln upgrade roc` with no tuple. json fails on H and n4 (passes on n2 and n5), lib passes on n4 and fails on n5 alone (the last of D). No compiler of H, n4 and n5 works.
# json has the line of its run n3 .. n4. lib has a run of one compiler that is not H: the line `  acme/lib 1.0.0 fails on <n5>` (R-AL11: "a run of one compiler has `on <id>` and no range"; only a run of H alone has no line).
# The same world with a hang of lib on n5: the line `  acme/lib 1.0.0 hangs on <n5>`, and no word `crashes` (the fault is a hang on n5; lib has no row on H).
expect {
	world = |lib_n5| [row(json, n2, Pass, []), row(json, n3, Fail, []), row(json, n4, Fail, []), row(json, n5, Pass, []), row(lib, n4, Pass, []), row(lib, n5, lib_n5, [])]
	failed = upgraded([json_slot, lib_slot], world(Fail))
	hung = upgraded([json_slot, lib_slot], world(Hang))
	report([
		("upgrade roc, no tuple: a Fail", if failed.starts_with("no tuple works") "yes" else failed, "yes"),
		("the run of json around H", if cause_lines(failed).contains("  acme/json 1.0.0 fails on ${n3} .. ${n4}") "yes" else failed, "yes"),
		("a run of one compiler that is not H has a line", if cause_lines(failed).contains("  acme/lib 1.0.0 fails on ${n5}") "yes" else failed, "yes"),
		("a hang on one compiler that is not H: the word hangs", if cause_lines(hung).contains("  acme/lib 1.0.0 hangs on ${n5}") "yes" else hung, "yes"),
		("a hang is not a crash", if hung.contains("crashes") hung else "no crash", "no crash"),
	])
}

# R-AL17 R-SP24 (slice 248, answer of Q-248-2, approved 2026-11-14): in a `Fail` of the second search (`Solver.step_moves`), the ids of a term of a movable slot are in the order of R-SP24 rule 2: the current value first, then the nearest.
# `highest`: the higher versions from low to high, then the lower ones from high to low. `lowest`: the lower ones from high to low, then the higher ones from low to high. b has 1.0.0 to 4.0.0, the current value is 2.0.0.
# The caller excludes 1.0.0, 2.0.0 and 3.0.0 in one conflict, and 4.0.0 in another: no tuple. The leaf of the first conflict has the term of b with 3 ids.
expect {
	b = { ..pkg("b", ["1.0.0", "2.0.0", "3.0.0", "4.0.0"]), current: Ok({ id: "b-2.0.0", version: "2.0.0" }) }
	conflicts = [[inn("b", ["b-1.0.0", "b-2.0.0", "b-3.0.0"])], [inn("b", ["b-4.0.0"])]]
	r = conflicting(req([b], known([b])), conflicts)
	leaves_of = |q| Str.join_with(leaves(why(Solver.step_moves(q, ["b"]))), "\n")
	report([
		("highest: current, then higher from low to high, then lower from high to low", leaves_of(r), "b:{b-2.0.0,b-3.0.0,b-1.0.0} <- given\nb:{b-4.0.0} <- given"),
		("lowest: current, then lower from high to low, then higher from low to high", leaves_of(low(r)), "b:{b-2.0.0,b-1.0.0,b-3.0.0} <- given\nb:{b-4.0.0} <- given"),
	])
}

# R-AL10 R-PH13 (slice 248, answer of Q-248-1, approved 2026-11-14): a fault on the held nightly. The first line has `(hangs)` for a hang and `(crashes)` for a crash, not `(no module is named)`. The cause line is left out (the run is H alone, R-AL11).
expect {
	fault = |outcome| [row(json, n2, Pass, []), row(json, n3, outcome, []), row(json, n4, Pass, [])]
	report([
		("a hang on H", first_line(probed([json_slot], fault(Hang), [])), "${head}acme/json 1.0.0 (hangs)"),
		("a hang on H: no cause line", Str.join_with(cause_lines(probed([json_slot], fault(Hang), [])), "\n"), ""),
		("a crash on H", first_line(probed([json_slot], fault(Crash), [])), "${head}acme/json 1.0.0 (crashes)"),
		("a platform hang on H", first_line(probed([pf_slot], [row(pfu, n3, Hang, [])], [])), "${head}the platform acme/pf 0.1.0 (hangs)"),
	])
}
