app [main!] { resolve: "../main.roc" }

import resolve.Domain
import resolve.Solver

main! = |_args| Ok({})

# Slice 035: PubGrub conflicts. The solver step with conflict resolution, the learned incompatibilities of the probe facts (R-EP7, R-AL5), the rules of `Need`, `Done` and `Fail` for real and inferred facts (R-EP8, R-EP9) and the explanation of a `Fail` (Resolution 5).
# The expected value of each row is the design text (Resolution 4 and 5), not the code. A row prints its label with `dbg` when it is wrong.
# A slot `a` has the releases `a-<version>`. The slot `roc` (the kind `Compiler`) has the compilers `n1` to `n6`, and the list D (`compat.domain`) is `n1` (oldest) to `n6`. The step has `Highest` unless the row says `low`.
# A check is a unit result of a release on a compiler: `fr` a real fail, `fi` an inferred fail (the modules of the fail are the last argument), `pr` and `pi` a real and an inferred pass, `hang` a real hang. `Yaml` is the module that the app uses.

cand : Str, Str -> Domain.Candidate
cand = |name, v| { id: "${name}-${v}", version: v, published_at: 0, yanked: Bool.False }

pkg : Str, List(Str) -> Solver.Slot
pkg = |name, versions| { name, group: name, kind: Package, candidates: versions.map(|v| cand(name, v)), ranges: [], current: Err(None), named: Err(None) }

pf : Str, List(Str) -> Solver.Slot
pf = |name, versions| { ..pkg(name, versions), kind: Platform }

# The compiler slot. Only the ids of the candidates are read. The order of the compilers is the order of D.
roc : List(Str) -> Solver.Slot
roc = |ids| { name: "roc", group: "roc", kind: Compiler, candidates: ids.map(|id| { id, version: id, published_at: 0, yanked: Bool.False }), ranges: [], current: Err(None), named: Err(None) }

d6 : List(Str)
d6 = ["n1", "n2", "n3", "n4", "n5", "n6"]

# The header facts of all releases of the slots (no compiler): the kind of the slot, no platform, no dep.
known : List(Solver.Slot) -> List(Solver.Fact)
known = |slots| slots.keep_if(|s| s.kind != Compiler).join_map(|s| s.candidates.map(|c| { id: c.id, kind: if s.kind == Platform Platform else Package, pf: Err(None), deps: [] }))

needs : List(Solver.Fact), Str, List((Str, Str)) -> List(Solver.Fact)
needs = |facts, id, deps| facts.map(|f| if f.id == id { ..f, deps: deps.map(|(group, version)| { group, version }) } else f)

on_pf : List(Solver.Fact), Str, Str -> List(Solver.Fact)
on_pf = |facts, id, url| facts.map(|f| if f.id == id { ..f, pf: Ok(url) } else f)

chk : Str, Str, [Pass, Fail, Hang, Crash], List(Str), [Real, Inferred] -> Solver.Check
chk = |id, nightly, outcome, modules, source| { id, nightly, outcome, modules, source }

fr : Str, Str, List(Str) -> Solver.Check
fr = |id, n, modules| chk(id, n, Fail, modules, Real)

fi : Str, Str, List(Str) -> Solver.Check
fi = |id, n, modules| chk(id, n, Fail, modules, Inferred)

pr : Str, Str -> Solver.Check
pr = |id, n| chk(id, n, Pass, [], Real)

pi : Str, Str -> Solver.Check
pi = |id, n| chk(id, n, Pass, [], Inferred)

hang : Str, Str -> Solver.Check
hang = |id, n| chk(id, n, Hang, [], Real)

# The same check for each compiler of the list.
each : Str, List(Str), List(Str) -> List(Solver.Check)
each = |id, ns, modules| ns.map(|n| fr(id, n, modules))

# A request with the slots, the checks and the used modules. The facts are the headers of all releases.
world : List(Solver.Slot), List(Solver.Check), List(Solver.Use), [Allowed, Off] -> Solver.Request
world = |slots, checks, used, mode| { slots, rules: { now: 1000, min_age: 100, snapshot: Err(None), strategy: Highest }, facts: known(slots), conflicts: [], compat: { domain: d6, checks, used, probes: mode } }

yaml : List(Solver.Use)
yaml = [{ id: "x-2.0.0", modules: ["Yaml"] }, { id: "x-1.0.0", modules: ["Yaml"] }]

x : Solver.Slot
x = pkg("x", ["1.0.0", "2.0.0"])

low : Solver.Request -> Solver.Request
low = |r| { ..r, rules: { ..r.rules, strategy: Lowest } }

conflicting : Solver.Request, List(List(Solver.Term)) -> Solver.Request
conflicting = |r, conflicts| { ..r, conflicts }

inn : Str, List(Str) -> Solver.Term
inn = |name, ids| { name, ids, sign: In }

ask_text : Solver.Ask -> Str
ask_text = |a| match a {
	Header(id) => id
	Probe(p) => "${p.id}@${p.nightly}"
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

# A step as text: `done a=1.0.0 b=2.0.0`, `need a-1.0.0 b-2.0.0@n6` (a header fact is an id, a probe is `id@nightly`), or `fail` with the lines of the explanation.
full : Solver.Request -> Str
full = |r| match Solver.step(r) {
	Need(asks) => "need ${Str.join_with(asks.map(ask_text), " ")}"
	Done(chosen) => "done ${Str.join_with(chosen.map(|c| "${c.name}=${c.version}"), " ")}"
	Fail(why) => "fail\n${Str.join_with(why.steps.map(step_text), "\n")}"
}

# The result without the explanation.
short : Solver.Request -> Str
short = |r| match Solver.step(r) {
	Fail(_) => "fail"
	_ => full(r)
}

# The same request with the lists of the candidates, the facts, the conflicts and their terms, the checks and the used modules reversed (R-DT2). The order of the slots is `priority`, and D is the order of the compilers: they stay.
flipped : Solver.Request -> Solver.Request
flipped = |r| { ..r, slots: r.slots.map(|s| { ..s, candidates: s.candidates.rev() }), facts: r.facts.rev(), conflicts: r.conflicts.rev().map(|c| c.rev()), compat: { ..r.compat, checks: r.compat.checks.rev(), used: r.compat.used.rev() } }

# A row is wrong when the step differs, or when the step of the flipped request differs from it (R-DT2).
wrong : List((Solver.Request, Str, Str)) -> List(Str)
wrong = |rows| rows.keep_if(|(r, want, _)| short(r) != want or short(flipped(r)) != want).map(|(_, _, label)| label)

# R-EP7, R-AL5, R-UM1, R-VA6: a probe fact makes an incompatibility `not (release and roc in interval)`. Here the solver may not ask for probes (`Off`), so the result shows which pairs (release, compiler) the facts exclude.
# A fail excludes its pair when it has no module, or a module that the app uses (R-UM1). A hang or a crash excludes its pair (a fault, R-EP5). A pass excludes nothing. A real or an inferred fail excludes (R-EP9: with no probes the inferred facts decide).
# A check of a compiler that is not in D, or of a release that is no value, is not read. The best tuple is still by `priority`: with `roc` first, it keeps its best value.
expect {
	w = |checks| world([x, roc(d6)], checks, yaml, Off)
	x2 = "x-2.0.0"
	x1 = "x-1.0.0"
	all_x2 = each(x2, d6, ["Yaml"])
	all_x1 = each(x1, d6, ["Yaml"])
	pfs = pf("pf", ["1.0.0"])
	rows = [
		(w([]), "done x=2.0.0 roc=n6", "no check: the best tuple"),
		(w([fr(x2, "n6", ["Yaml"])]), "done x=2.0.0 roc=n5", "a fail in a used module excludes its pair"),
		(w([fr(x2, "n6", ["Yaml"]), fr(x2, "n5", ["Yaml"])]), "done x=2.0.0 roc=n4", "2 adjacent fails"),
		(w([fr(x2, "n6", ["Yaml"]), pr(x2, "n5"), fr(x2, "n4", ["Yaml"])]), "done x=2.0.0 roc=n5", "a pass between 2 fails stays a value"),
		(w([fr(x2, "n6", ["Other"])]), "done x=2.0.0 roc=n6", "R-UM1: a fail with no used module is ignored"),
		(w([fr(x2, "n6", [])]), "done x=2.0.0 roc=n5", "R-UM1: a fail with no module is a hard fail"),
		(w([fr(x2, "n6", ["Other", "Yaml"])]), "done x=2.0.0 roc=n5", "one used module in 2 is enough"),
		(w([hang(x2, "n6")]), "done x=2.0.0 roc=n5", "a hang excludes its pair"),
		(w([chk(x2, "n6", Crash, [], Real)]), "done x=2.0.0 roc=n5", "a crash excludes its pair"),
		(w([pr(x2, "n6")]), "done x=2.0.0 roc=n6", "a pass excludes nothing"),
		(w([fi(x2, "n6", ["Yaml"])]), "done x=2.0.0 roc=n5", "R-EP9: an inferred fail decides when no probe may run"),
		(w([fr(x2, "n6", ["Yaml"]), fi(x2, "n5", ["Yaml"]), fi(x2, "n4", ["Yaml"])]), "done x=2.0.0 roc=n3", "the inferred fails next to a real fail"),
		(w(all_x2), "done x=1.0.0 roc=n6", "no compiler for x-2.0.0: x-1.0.0"),
		(w(all_x2.concat(all_x1)), "fail", "no compiler for any release of x"),
		(w([fr(x2, "n6", ["Yaml"]), fr(x2, "n5", ["Yaml"]), fr(x1, "n6", ["Yaml"])]), "done x=2.0.0 roc=n4", "x first: the checks of x-1.0.0 do not change x-2.0.0"),
		(low(w([])), "done x=1.0.0 roc=n1", "lowest: the oldest compiler"),
		(low(w([fr(x1, "n1", ["Yaml"]), fr(x1, "n2", ["Yaml"])])), "done x=1.0.0 roc=n3", "lowest: the oldest compiler that has no fail"),
		(world([x, roc(["n3", "n4", "n5"])], [fr(x2, "n5", ["Yaml"]), fr(x2, "n4", ["Yaml"])], yaml, Off), "done x=2.0.0 roc=n3", "the candidates of roc are some of D: the fails still count by D"),
		(world([x, roc(d6)], [fr(x2, "n6", ["Yaml"])], [], Off), "done x=2.0.0 roc=n6", "no used module for the release: a fail with modules is ignored"),
		(world([x, roc(d6)], [fr(x2, "n6", [])], [], Off), "done x=2.0.0 roc=n5", "no used module for the release: a fail with no module is hard"),
		(w([fr(x2, "zz", ["Yaml"])]), "done x=2.0.0 roc=n6", "a compiler that is not in D: not read"),
		(w([fr("q-1.0.0", "n6", ["Yaml"])]), "done x=2.0.0 roc=n6", "a release that is no value: not read"),
		(world([x, pfs, roc(d6)], [fr("pf-1.0.0", "n6", ["Stdout"])], [{ id: "pf-1.0.0", modules: ["Stdout"] }], Off), "done x=2.0.0 pf=1.0.0 roc=n5", "the platform slot has probe facts too (R-LD3)"),
		(world([roc(d6), x], [fr(x2, "n6", ["Yaml"])], yaml, Off), "done roc=n6 x=1.0.0", "R-VA6: roc first in priority keeps n6, x gives way"),
		(conflicting(w([]), [[inn("x", [x2]), inn("roc", ["n6"])]]), "done x=2.0.0 roc=n5", "a conflict of the caller can name the slot roc"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# R-AL3: conflict resolution. These problems have a search that is wrong, or very long, when a conflict teaches only the decisions that gave it. The result is the best tuple by `priority`, as in slice 034.
# A coloring of 3 slots that all differ (2 values each) has no solution. 4 slots in a ring have one. A chain of conflicts is solved by unit propagation alone (no decision). Slots that nothing constrains come first and are not part of the reason.
expect {
	two = |name| pkg(name, ["1.0.0", "2.0.0"])
	req = |slots, conflicts| { slots, rules: { now: 1000, min_age: 100, snapshot: Err(None), strategy: Highest }, facts: known(slots), conflicts, compat: { domain: [], checks: [], used: [], probes: Allowed } }
	differ = |p, q| ["1.0.0", "2.0.0"].map(|v| [inn(p, ["${p}-${v}"]), inn(q, ["${q}-${v}"])])
	abc = [two("a"), two("b"), two("c")]
	abcd = [two("a"), two("b"), two("c"), two("d")]
	abcde = [two("a"), two("b"), two("c"), two("d"), two("e")]
	free = [two("s0"), two("s1"), two("s2"), two("x"), two("y")]
	pair_x_y = [[inn("x", ["x-1.0.0"]), inn("y", ["y-1.0.0"])], [inn("x", ["x-1.0.0"]), inn("y", ["y-2.0.0"])], [inn("x", ["x-2.0.0"]), inn("y", ["y-1.0.0"])], [inn("x", ["x-2.0.0"]), inn("y", ["y-2.0.0"])]]
	chain = [[inn("a", ["a-2.0.0"]), inn("b", ["b-1.0.0"])], [inn("b", ["b-2.0.0"]), inn("c", ["c-1.0.0"])], [inn("c", ["c-2.0.0"]), inn("d", ["d-1.0.0"])], [inn("d", ["d-2.0.0"]), inn("e", ["e-1.0.0"])], [inn("e", ["e-2.0.0"])]]
	# A back-jump over 2 levels. a, b, c, d are decided (levels 1 to 4). Then d=2 gives u=1, u=1 gives x=1 and y=1, and the conflict `x=1 y=1 a=2` has 3 lits at the latest level. The resolution goes to the row `a=2 u=1`:
	# its latest satisfier is the derived u (not a decision) and its other lit is at level 1. The solver learns it and goes back to level 1 (b and c are decided again). A back-jump to the level of u (4) keeps the conflict, so the search does not end.
	wide = { slots: abcd.concat([two("u"), two("x"), two("y")]), conflicts: [[inn("d", ["d-2.0.0"]), inn("a", ["a-2.0.0"]), inn("u", ["u-2.0.0"])], [inn("u", ["u-1.0.0"]), inn("x", ["x-2.0.0"])], [inn("u", ["u-1.0.0"]), inn("y", ["y-2.0.0"])], [inn("x", ["x-1.0.0"]), inn("y", ["y-1.0.0"]), inn("a", ["a-2.0.0"])]] }
	rows = [
		(req(wide.slots, wide.conflicts), "done a=2.0.0 b=2.0.0 c=2.0.0 d=1.0.0 u=2.0.0 x=2.0.0 y=2.0.0", "R-AL3: a conflict whose reason is a derived value at the latest level: learn it, go back over 2 levels (a search that stays at that level does not end)"),
		(req(abc, differ("a", "b").concat(differ("a", "c")).concat(differ("b", "c"))), "fail", "3 slots that all differ, 2 values: no tuple"),
		(req(abcd, differ("a", "b").concat(differ("b", "c")).concat(differ("c", "d")).concat(differ("d", "a"))), "done a=2.0.0 b=1.0.0 c=2.0.0 d=1.0.0", "4 slots in a ring: the best tuple"),
		(req(abcde, chain), "done a=1.0.0 b=1.0.0 c=1.0.0 d=1.0.0 e=1.0.0", "a chain of conflicts: unit propagation gives the tuple"),
		(req(free, pair_x_y), "fail", "x and y have no pair left, 3 free slots before them"),
		(req(free, [[inn("x", ["x-2.0.0"]), inn("y", ["y-1.0.0"])], [inn("x", ["x-2.0.0"]), inn("y", ["y-2.0.0"])]]), "done s0=2.0.0 s1=2.0.0 s2=2.0.0 x=1.0.0 y=2.0.0", "x=2 leaves no value for y: x=1, the free slots keep their best"),
		(req(free, [[inn("s0", ["s0-2.0.0"]), inn("x", ["x-2.0.0"])], [inn("s0", ["s0-2.0.0"]), inn("x", ["x-1.0.0"])]]), "done s0=1.0.0 s1=2.0.0 s2=2.0.0 x=2.0.0 y=2.0.0", "the reason is the first slot: only s0 changes"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}

# The conflict resolution must not repeat work for slots that are no part of the reason. 9 slots with 2 values each come first, then x and y that have no tuple. A search that learns only the decisions that gave the conflict tries all
# 2^9 = 512 tuples of the first slots (the step of slice 034 needs about 13 s for this row, the step of this slice a few ms). The check is the `Fail`.
expect {
	two = |name| pkg(name, ["1.0.0", "2.0.0"])
	slots = List.repeat(0, 9).map_with_index(|_, i| two("s${i.to_str()}")).concat([two("x"), two("y")])
	pair_x_y = [[inn("x", ["x-1.0.0"]), inn("y", ["y-1.0.0"])], [inn("x", ["x-1.0.0"]), inn("y", ["y-2.0.0"])], [inn("x", ["x-2.0.0"]), inn("y", ["y-1.0.0"])], [inn("x", ["x-2.0.0"]), inn("y", ["y-2.0.0"])]]
	r = { slots, rules: { now: 1000, min_age: 100, snapshot: Err(None), strategy: Highest }, facts: known(slots), conflicts: pair_x_y, compat: { domain: [], checks: [], used: [], probes: Allowed } }
	short(r) == "fail"
}

# The tuples of the values of the slots (an id for each slot, in the order of the slots).
tuples : List(List(Str)) -> List(List(Str))
tuples = |doms| match doms {
	[] => [[]]
	[first, .. as rest] => first.join_map(|id| tuples(rest).map(|t| [id].concat(t)))
}

holds : List(Str), List(Str), Solver.Term -> Bool
holds = |names, tuple, t| match names.find_first_index(|n| n == t.name) {
	Ok(i) => match tuple.get(i) {
		Ok(id) => t.ids.contains(id) == (t.sign == In)
		Err(_) => Bool.False
	}
	Err(_) => Bool.False
}

all_true : List(Str), List(Str), List(Solver.Term) -> Bool
all_true = |names, tuple, terms| terms.all(|t| holds(names, tuple, t))

# The steps of the explanation that are not `Derived` and that the step `i` comes from.
leaves_of : List(Solver.Step), U64 -> List(U64)
leaves_of = |steps, i| match steps.get(i) {
	Ok(s) => match s.cause {
		Derived(a, b) => if a < i and b < i leaves_of(steps, a).concat(leaves_of(steps, b)) else []
		_ => [i]
	}
	Err(_) => []
}

# The explanation is a proof: the last step has no term, a `Derived` names 2 earlier steps, and for each step and each tuple of the values: when all terms of the step are true, all terms of one of its leaves are true (so the step is a consequence of its leaves).
well_formed : List(Solver.Step) -> Bool
well_formed = |steps| match steps.last() {
	Ok(last) => last.terms.is_empty() and steps.map_with_index(|s, i| (s, i)).all(
		|(s, i)| match s.cause {
			Derived(a, b) => a < i and b < i
			_ => Bool.True
		},
	)
	Err(_) => Bool.False
}

sound : List(Solver.Step), List(Str), List(List(Str)) -> Bool
sound = |steps, names, doms| tuples(doms).all(
	|t| steps.map_with_index(|s, i| (s, i)).all(
		|(s, i)| !all_true(names, t, s.terms) or leaves_of(steps, i).any(|j| steps.get(j).map_ok(|l| all_true(names, t, l.terms)) ?? Bool.False),
	),
)

leaves : Solver.Why -> List(Str)
leaves = |why| why.steps.keep_if(
	|s| match s.cause {
		Derived(_, _) => Bool.False
		_ => Bool.True
	},
).map(step_text)

# A row: the request, the leaves that every explanation has (`must`: the reasons of the caller, the facts and the probes that no tuple can do without, as `terms <- cause`, the ids of a term in the order of the values of its slot: the best first,
# so with `Highest` the newest compiler first), the leaves that an explanation may have (`may`: all that exist), the names of the slots, the ids of the values of each slot, a label.
# A row is wrong when the step is not a `Fail`, when the leaves are not between `must` and `may` (an explanation names real reasons only, and each reason that is needed), when the explanation is no proof, or when the flipped request gives another text (R-DT2: also the order of the steps).
wrong_why : List((Solver.Request, List(Str), List(Str), List(Str), List(List(Str)), Str)) -> List(Str)
wrong_why = |rows| rows.keep_if(
	|(r, must, may, names, doms, _)| match Solver.step(r) {
		Fail(why) => !(must.all(|l| leaves(why).contains(l)) and leaves(why).all(|l| may.contains(l)) and well_formed(why.steps) and sound(why.steps, names, doms) and full(r) == full(flipped(r)))
		_ => Bool.True
	},
).map(|(_, _, _, _, _, label)| label)

# A row in which the explanation has exactly these leaves: the leaves are needed and no other reason exists.
exact : (Solver.Request, List(Str), List(Str), List(List(Str)), Str) -> (Solver.Request, List(Str), List(Str), List(Str), List(List(Str)), Str)
exact = |(r, ls, names, doms, label)| (r, ls, ls, names, doms, label)

# The explanation of a failure (Resolution 5, the example): the app needs `parser` and `pf`, and no compiler of D checks both. The reasons are the probe facts. A probe reason has its release, the first and last compiler of the interval (R-EP7: the maximal run of D with a fail), the used modules, and the compilers whose fail is inferred.
# R-EP7: a run ends at a compiler that has a pass, no fact, a fail that touches no used module, or a fault. A fault is the interval of its compiler alone. A term with all values of its slot is left out of a reason.
# R-EP9: with no probe allowed, the explanation may use inferred facts, and each interval names them. R-EP8: with probes allowed, a `Fail` has real facts only.
expect {
	parser = pkg("parser", ["1.0.0", "2.0.0"])
	basic = pf("pf", ["0.24.0", "0.25.0"])
	names = ["parser", "pf", "roc"]
	doms = [["parser-1.0.0", "parser-2.0.0"], ["pf-0.24.0", "pf-0.25.0"], d6]
	used = [{ id: "parser-1.0.0", modules: ["Yaml"] }, { id: "parser-2.0.0", modules: ["Yaml"] }, { id: "pf-0.24.0", modules: ["Stdout"] }, { id: "pf-0.25.0", modules: ["Stdout"] }]
	# parser-2.0.0 checks on n3 and n4, pf-0.25.0 on n5 and n6. The older releases check on no compiler.
	base_checks = each("parser-1.0.0", d6, ["Yaml"]).concat(each("pf-0.24.0", d6, ["Stdout"])).concat([fr("parser-2.0.0", "n1", ["Yaml"]), fr("parser-2.0.0", "n2", ["Yaml"]), pr("parser-2.0.0", "n3"), pr("parser-2.0.0", "n4")]).concat(each("pf-0.25.0", ["n1", "n2", "n3", "n4"], ["Stdout"])).concat([pr("pf-0.25.0", "n5"), pr("pf-0.25.0", "n6")])
	example = base_checks.concat([fr("parser-2.0.0", "n5", ["Yaml"]), fr("parser-2.0.0", "n6", ["Yaml"])])
	inferred = base_checks.concat([fr("parser-2.0.0", "n5", ["Yaml"]), fi("parser-2.0.0", "n6", ["Yaml"])])
	slots = [parser, basic, roc(d6)]
	pair = |a, b| "parser:{parser-2.0.0} & roc:{${a}} <- probe parser-2.0.0 fail ${b}"
	# The reasons that no explanation can do without: pf-0.24.0 and parser-1.0.0 check on no compiler, pf-0.25.0 fails on n1 to n4, so only n5 and n6 stay, and parser-2.0.0 fails on both. The first fail of parser-2.0.0 (n1 and n2) is a reason that exists, but a proof does not need it.
	first_fail = pair("n2,n1", "n1..n2 [Yaml] inferred []")
	example_must = [
		"parser:{parser-1.0.0} <- probe parser-1.0.0 fail n1..n6 [Yaml] inferred []",
		pair("n6,n5", "n5..n6 [Yaml] inferred []"),
		"pf:{pf-0.24.0} <- probe pf-0.24.0 fail n1..n6 [Stdout] inferred []",
		"pf:{pf-0.25.0} & roc:{n4,n3,n2,n1} <- probe pf-0.25.0 fail n1..n4 [Stdout] inferred []",
	]
	inferred_must = [
		"parser:{parser-1.0.0} <- probe parser-1.0.0 fail n1..n6 [Yaml] inferred []",
		pair("n6,n5", "n5..n6 [Yaml] inferred [n6]"),
		"pf:{pf-0.24.0} <- probe pf-0.24.0 fail n1..n6 [Stdout] inferred []",
		"pf:{pf-0.25.0} & roc:{n4,n3,n2,n1} <- probe pf-0.25.0 fail n1..n4 [Stdout] inferred []",
	]
	# the runs of one release: a fault, a fail with no used module and an inferred fail cut or mark a run
	x_slot = pkg("x", ["1.0.0", "2.0.0"])
	runs = each("x-1.0.0", d6, ["Yaml"]).concat([fr("x-2.0.0", "n1", ["Yaml"]), fr("x-2.0.0", "n2", ["Yaml"]), hang("x-2.0.0", "n3"), fr("x-2.0.0", "n4", ["Yaml"]), fi("x-2.0.0", "n5", ["Yaml"]), fr("x-2.0.0", "n6", ["Other", "Yaml"])])
	cut = each("x-1.0.0", d6, ["Yaml"]).concat([fr("x-2.0.0", "n1", ["Yaml"]), fr("x-2.0.0", "n2", ["Other"]), fr("x-2.0.0", "n3", ["Yaml"]), fr("x-2.0.0", "n4", ["Yaml"]), fr("x-2.0.0", "n5", ["Yaml"]), fr("x-2.0.0", "n6", ["Yaml"])])
	xnames = ["x", "roc"]
	xdoms = [["x-1.0.0", "x-2.0.0"], d6]
	rows = [
		(world(slots, example, used, Allowed), example_must, example_must.append(first_fail), names, doms, "the example of Resolution 5: real facts only"),
		(world(slots, inferred, used, Off), inferred_must, inferred_must.append(first_fail), names, doms, "R-EP9: no probe may run: the interval of parser-2.0.0 names its inferred compiler n6"),
		exact((
			world([x_slot, roc(d6)], runs, yaml, Off),
			[
				"x:{x-1.0.0} <- probe x-1.0.0 fail n1..n6 [Yaml] inferred []",
				"x:{x-2.0.0} & roc:{n2,n1} <- probe x-2.0.0 fail n1..n2 [Yaml] inferred []",
				"x:{x-2.0.0} & roc:{n3} <- probe x-2.0.0 fault n3..n3 [] inferred []",
				"x:{x-2.0.0} & roc:{n6,n5,n4} <- probe x-2.0.0 fail n4..n6 [Yaml] inferred [n5]",
			],
			xnames,
			xdoms,
			"R-EP7: a fault is an interval of its own and cuts the runs, an inferred fail is part of a run and is named",
		)),
		exact((
			conflicting(world([x_slot, roc(d6)], cut, yaml, Off), [[inn("roc", ["n2"])]]),
			[
				"x:{x-1.0.0} <- probe x-1.0.0 fail n1..n6 [Yaml] inferred []",
				"x:{x-2.0.0} & roc:{n1} <- probe x-2.0.0 fail n1..n1 [Yaml] inferred []",
				"x:{x-2.0.0} & roc:{n6,n5,n4,n3} <- probe x-2.0.0 fail n3..n6 [Yaml] inferred []",
				"roc:{n2} <- given",
			],
			xnames,
			xdoms,
			"R-EP7, R-UM1: a fail with no used module ends a run (n2 is no member)",
		)),
	]
	bad = wrong_why(rows)
	dbg bad
	bad == []
}

# The other reasons. Each reason has the terms of its incompatibility (the value of a slot is in these ids), in the order of the slots. A conflict of the caller (`Given`), a dep (R-C2), a platform (R-C3), a slot with no value (`NoValue`, no term: the incompatibility is always true).
# The terms of a reason are the terms of the incompatibility, joined for one slot, with the terms that hold for all values of their slot left out.
expect {
	a = pkg("a", ["1.0.0", "2.0.0"])
	b = pkg("b", ["1.0.0", "2.0.0"])
	p = pf("pf", ["1.0.0", "2.0.0"])
	r = |slots, facts, conflicts| { slots, rules: { now: 1000, min_age: 100, snapshot: Err(None), strategy: Highest }, facts, conflicts, compat: { domain: [], checks: [], used: [], probes: Allowed } }
	both = [[inn("a", ["a-1.0.0"]), inn("b", ["b-1.0.0"])], [inn("a", ["a-1.0.0"]), inn("b", ["b-2.0.0"])], [inn("a", ["a-2.0.0"]), inn("b", ["b-1.0.0"])], [inn("a", ["a-2.0.0"]), inn("b", ["b-2.0.0"])]]
	ab = ["a", "b"]
	ab_doms = [["a-1.0.0", "a-2.0.0"], ["b-1.0.0", "b-2.0.0"]]
	dep_facts = known([a, b]) |> needs("a-1.0.0", [("b", "2.0.0")]) |> needs("a-2.0.0", [("b", "2.0.0")])
	pf_facts = known([a, p]) |> on_pf("a-1.0.0", "pf-2.0.0") |> on_pf("a-2.0.0", "pf-2.0.0")
	none_a = { ..pkg("a", ["1.0.0"]), ranges: [">=2.0.0"] }
	rows = [
		exact((r([a, b], known([a, b]), both), ["a:{a-1.0.0} & b:{b-1.0.0} <- given", "a:{a-1.0.0} & b:{b-2.0.0} <- given", "a:{a-2.0.0} & b:{b-1.0.0} <- given", "a:{a-2.0.0} & b:{b-2.0.0} <- given"], ab, ab_doms, "4 conflicts of the caller: no pair")),
		exact((r([a, b], known([a, b]), [[inn("a", ["a-1.0.0", "a-2.0.0"]), inn("b", ["b-1.0.0"])], [inn("b", ["b-2.0.0"])]]), ["b:{b-1.0.0} <- given", "b:{b-2.0.0} <- given"], ab, ab_doms, "a term with all values of its slot is left out")),
		exact((r([a, b], dep_facts, [[inn("b", ["b-2.0.0"])]]), ["a:{a-1.0.0} & b:{b-1.0.0} <- dep a-1.0.0 b>=2.0.0", "a:{a-2.0.0} & b:{b-1.0.0} <- dep a-2.0.0 b>=2.0.0", "b:{b-2.0.0} <- given"], ab, ab_doms, "R-C2: each release of a needs b-2.0.0, and the caller forbids it")),
		exact((r([a, p], pf_facts, [[inn("pf", ["pf-2.0.0"])]]), ["a:{a-1.0.0} & pf:{pf-1.0.0} <- pf a-1.0.0 pf-2.0.0", "a:{a-2.0.0} & pf:{pf-1.0.0} <- pf a-2.0.0 pf-2.0.0", "pf:{pf-2.0.0} <- given"], ["a", "pf"], [["a-1.0.0", "a-2.0.0"], ["pf-1.0.0", "pf-2.0.0"]], "R-C3: each release of a names pf-2.0.0, and the caller forbids it")),
		exact((r([none_a, b], known([none_a, b]), []), ["true <- none a"], ab, [[], ["b-1.0.0", "b-2.0.0"]], "a slot with no value")),
	]
	bad = wrong_why(rows)
	dbg bad
	bad == []
}

# R-EP8, R-EP9, R-AL4, R-AL8: `Need`, `Done` and `Fail` with real and inferred facts. `A` is the best tuple with all facts (real and inferred), `B` the best tuple with the real facts only.
# Allowed: no `B`: `Fail`. `A` lacks a header fact: `Need` for the headers only (a probe needs the release). `A` lacks a real fact of a pair: `Need` with a probe for each such pair (an inferred fact is no real fact, also a pass).
# An inferred fail with no real fail in its run is an incompatibility (G3: the rows `pr(n5)` with `fi(n6)` and `two`, with `Off`: done on n5, fail), but with `Allowed` it never decides alone: B has the pair, so the step asks for a probe (the same rows with `Allowed`: a need for n6, and for n2).
# `A` has all facts and `B` is `A`: `Done`. `B` is better than `A` (an inferred fail blocked it) or `A` does not exist: `Need` for `B`, as for `A` (the second pass). Off (`--no-probe`, or the budget is spent): `A` only, with no probe: `Done` or `Fail`, an unknown pair is taken as fit.
expect {
	w = |checks, mode| world([x, roc(d6)], checks, yaml, mode)
	x2 = "x-2.0.0"
	x1 = "x-1.0.0"
	two = world([x, roc(["n1", "n2"])], [fr(x2, "n1", ["Yaml"]), fi(x2, "n2", ["Yaml"]), fr(x1, "n1", ["Yaml"]), fr(x1, "n2", ["Yaml"])], yaml, Allowed)
	y = pkg("y", ["1.0.0", "2.0.0"])
	shared = { ..world([pkg("a", ["1.0.0"]), { ..pkg("b", []), candidates: [cand("a", "1.0.0")] }, roc(d6)], [], [], Allowed), facts: known([pkg("a", ["1.0.0"])]) }
	rows = [
		(w([], Allowed), "need x-2.0.0@n6", "no real fact: a probe for the pair of the best tuple"),
		({ ..w([], Allowed), facts: [] }, "need x-2.0.0", "no header fact: the header first, no probe"),
		(w([pr(x2, "n6")], Allowed), "done x=2.0.0 roc=n6", "a real pass for each pair: done"),
		(w([fr(x2, "n6", ["Yaml"])], Allowed), "need x-2.0.0@n5", "a real fail: the next pair"),
		(w([fr(x2, "n6", ["Yaml"]), pr(x2, "n5")], Allowed), "done x=2.0.0 roc=n5", "a real fail, then a real pass: done"),
		(w([fr(x2, "n6", ["Other"])], Allowed), "done x=2.0.0 roc=n6", "a real fail with no used module is a real fact (R-UM1): done"),
		(w([hang(x2, "n6")], Allowed), "need x-2.0.0@n5", "a real hang: the next pair"),
		(w([pi(x2, "n6")], Allowed), "need x-2.0.0@n6", "R-EP8: an inferred pass is no real fact: a probe"),
		(w([pr(x2, "n5"), fi(x2, "n6", ["Yaml"])], Allowed), "need x-2.0.0@n6", "R-EP8 second pass: an inferred fail blocked the better pair: a probe for it"),
		(w([pr(x2, "n5"), fi(x2, "n6", ["Yaml"])], Off), "done x=2.0.0 roc=n5", "R-EP9: no probe: done on the inferred fail"),
		(w([fi(x2, "n6", ["Yaml"])], Allowed), "need x-2.0.0@n5", "R-EP8: A has the pair n5 with no fact: the first need is for A (the first pass), not for B"),
		(two, "need x-2.0.0@n2", "R-EP8: no tuple with all facts, but one with the real facts: no fail, a probe for the inferred pair"),
		({ ..two, compat: { ..two.compat, probes: Off } }, "fail", "R-EP9: no probe: fail on the inferred fact"),
		({ ..two, compat: { ..two.compat, checks: [fr(x2, "n1", ["Yaml"]), fr(x2, "n2", ["Yaml"]), fr(x1, "n1", ["Yaml"]), fr(x1, "n2", ["Yaml"])] } }, "fail", "R-EP8: real facts only: fail"),
		(world([x, y, roc(d6)], [], [], Allowed), "need x-2.0.0@n6 y-2.0.0@n6", "2 slots: a probe for each pair, in the order of the slots"),
		(world([x, pf("pf", ["1.0.0", "2.0.0"]), roc(d6)], [], [], Allowed), "need x-2.0.0@n6 pf-2.0.0@n6", "the platform is probed too"),
		(shared, "need a-1.0.0@n6", "2 slots with one release: one probe"),
		(w([], Off), "done x=2.0.0 roc=n6", "R-EP9: no probe: a pair with no fact is taken as fit"),
		({ ..w([], Off), facts: [] }, "need x-2.0.0", "R-EP9: no probe, but a header fact is not a probe: a need"),
	]
	bad = wrong(rows)
	dbg bad
	bad == []
}
