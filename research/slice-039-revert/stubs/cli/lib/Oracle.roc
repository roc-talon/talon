import Closure
import Db
import Epochs
import Explain
import Fail
import Ident
import Pick
import OracleDomain
import Release
import Text
import resolve.Solver

## The pure step of the oracle loop (slice 036 and 036b, Resolution 5 steps 3 and 5, R-AL3, R-AL4, R-SP24, R-PH10, R-PH13, R-EP8, R-EP9, R-LF2; TESTING.md 2.2 part B for the command). It is `Pick.step` over the solver step of the package `resolve` (`Solver.step_moves`),
## and it knows the probe facts of one compiler. `PickLoop.run!` calls `Oracle.step_probed` in place of `Pick.step`. Pure: the same input gives the same output (R-DT2).
##
## The input is the one of `Pick.step` (its doc has the fields). The output is `Need` (the ids of the nodes that have no fact: a release URL or the file of a path node), `Pairs` (the pairs of a release and a compiler that the command must probe, or look up in the db with `Off`),
## `Scan` (slice 036b2: the tuple is good, but a chosen release has a unit fail with modules and no used-module result: the command scans the files and calls again with `compat.used`), `Done` (one `Pick.Chosen` for each slot, in the order of the slots) or `Fail` (kind `NoTuple`).
##
## | Part | What the step does | Rule |
## | --- | --- | --- |
## | Slots | A slot is a solver slot with the name `s<index>` (the alias `id` of a slot is no key: one alias can name 2 groups in 2 members, R-WS8). Its group is the group of the releases (`Ident.group` of the header value, else of the first candidate). A `Free` slot, and a `Movable` slot with `second`, has its candidates and ranges. A `Held` slot, and a `Movable` slot with no `second`, has no candidate and no range: its one value is `current` (R-SP1, R-C9). `current` is `Err(None)` for a want (and for a value that is no release URL). | R-SP1, R-C1, R-C9 |
## | Facts | A fact is a `Solver.Fact` of a release URL: its kind, its platform, and its deps as (group, version) (a dep that is no release URL is dropped, R-H4). | R-C2, R-C3, R-C4, R-AL8 |
## | Rules | `now`, `min_age`, `snapshot` and `strategy` are the rules of the request (R-C7, R-DT4, R-VA6). | R-C7 |
## | Compiler | With `compat.compiler` the request has a compiler slot (the last one) with the one value of D, the checks of the db rows of that compiler (target `any`), the used modules (`compat.used`, and `main.roc` for each release: roc reads it for each package of the closure, `Units.judge`), and `compat.probes`. The value that a header has now is a pass unless a real row says other (D2). Without a compiler the request has no compiler slot and `probes` is `Off`: the answer of the step of slice 036. | R-EP7, R-EP8, R-SO22 |
## | Same group | Two slots of one group have one value (R-WS2, R-WS3): for each pair of slots with one group, a conflict of the caller says that the value of the second is the value of the first. | R-WS2, R-WS3 |
## | Conflicts | A conflict of `compat.conflicts` is a list of (place of a slot, release URL): the releases cannot all be chosen. The command gives the tuples that the ladder dropped (R-AL5, R-AL6). | R-AL5 |
## | Search | `second: false`: `Solver.step`. `second: true`: `Solver.step_moves` with the names of the `Movable` slots: they are first in the search, in the order of the slots, and try `current` first, then the nearest values (R-SP24). `Done`, `Need` and `Fail` are in the order of the slots. | R-SP24, R-PH10 |
## | `Pairs` | `Allowed`: the pairs of the best tuple that have no real check, in the order of the slots, before the closure walk of that tuple (R-AL4, R-EP8). The header of a pair release that is not in `facts` is a `Need` first: the package is fetched before its probe (slice 036b F1). `Off` (`--no-probe`): after the closure walk, the chosen releases that change, have no row and are not in `compat.looked`: the command looks them up, it does not probe (R-LF2). A pair with no fact is fit (R-EP9). | R-AL4, R-EP8, R-EP9, R-LF2 |
## | `Scan` | Slice 036b2 (R-UM1, R-AL5, 036 Q3). After the closure walk and the lookups of `Off`, and before `Done`: the chosen releases (no repeat, in the order of the slots) with a real `Fail` row of the compiler that has modules, none of them `main.roc`, and no row for the release in `compat.used`. The verdict is `Scan({ ids, chosen })`: `chosen` is the tuple. The command scans the used modules of the tuple and calls again with a `compat.used` row for each id, also with no module (`modules: []`): a row means that the scan ran, so a release is scanned once. A fail whose module is used (or is `main.roc`) touches the release: the solver drops it with a probe cause, so the conflict names that release only (R-AL5). A fail that touches no used module is no blame (R-UM1: the whole-app check decides). A hard fail, a hang, a crash and a pass need no scan. | R-UM1, R-AL5 |
## | `Need` | The header facts that the best tuple lacks (`Solver.Need`, the releases of the slots), in the order of the slots, no repeat. After `Done` the closure of the tuple (below) can ask for more nodes, and then the step gives `Need` of those. | R-AL8, R-AL9 |
## | Closure | After `Done` of the solver, the step walks the closure of the tuple as `Pick.step` does (R-AL9: `Closure.step` for each member, the rules 1 to 4 of the table of `Pick.step`). A problem of the closure is a conflict of the caller: the releases of that tuple cannot all be chosen. The step asks the solver again, so the next tuple is the best one that has no problem. A tuple with nodes that have no fact gives `Need` of those nodes (an unknown node is taken as fit). | R-AL9, 034 Q3 |
## | Domain D | Slice 036c (R-EP10, R-EP11, Q1 (b) of slice 036). `compat.domain` is D: the ids of the compiler list, oldest first (`Nightlies.order`), or `Err(NotRead)` when the command did not read the list. The compiler slot keeps its one value (the held compiler H: the nightly is held outside `tln upgrade`, R-RP2, R-SP23), but the solver gets D and the checks of D, so a fail interval can go past H (R-EP7). D is used only when H is in it: with H not in D (a compiler that is not in the list: a path compiler, an id of the other tag form) the step uses `[H]` and no inferred fact, as with `Err(NotRead)`. | R-EP10, R-EP11, R-EP7 |
## | Checks of D | For each release of the slots (the candidates and the header value) and each compiler of D, one check: the real row of the db (target `any`) first; else, for the header value on H only, the assumed pass (D2 of slice 036b); else the inferred fact of `compat.inferred` for that hash and compiler (`Epochs.infer`, the command calls `Epochs.epochs` over the list and the rows). The assumed pass is for H and for nothing else: a header value on another compiler has no assumed pass, so it needs a real row or a probe (the revisit of D2 in slice 036c). An inferred fact never replaces the assumed pass or a real row. An inferred fact is a check with `source: Inferred`, so by R-EP8 it never decides with `Allowed` (the step asks for the real fact) and decides with `Off` (R-EP9). | R-EP6, R-EP8, R-EP9, R-EP12, R-EP14 |
## | `Wide` | The step asks the command for D. It gives `Wide` instead of the verdict when `compat.domain` is `Err(NotRead)` and (a) the verdict would be `Fail` and its proof has a probe cause (a unit fail, a hang or a crash of a release on H: the explanation needs D, and the hint needs the facts of the other compilers), or (b) `probes` is `Off` and the verdict would be `Pairs` (a lookup round: with `--no-probe` the db and the inferred facts are the only evidence, so D is read before the lookup). Never else: `Done`, a `Need`, a `Pairs` with `Allowed`, a `Fail` with no probe cause, and a run with no compiler (`--no-check`, `verify`) never read D. The command reads D once, loads the rows of the releases of the slots on each compiler of D, calls `Epochs.epochs`, and calls the step again with `compat.domain` `Ok(D)` (`Ok([H])` when D cannot be read: any failure of the read, no list, H not in D). The step never gives `Wide` for `Ok(_)`. | Q1 (b) of slice 036, R-EP9, R-RP2 |
## | `fix:` lines | A `Fail` with a probe cause has the lines of `Explain.lines` after the first line (the text of `Units.judge`), joined with a line end: one line for each cause whose fail goes past H or is inferred, then the `fix:` block, which names `tln upgrade roc` and `tln roc use <id>` (R-RP2) and the oldest nightly that works when `Oracle.hint` knows one. `details` of the failure is `Explain.details` (R-J5). A `Fail` with no probe cause has the text of `Pick.step` and no line more. | R-RP2, R-EP9, R-EP14, 035 Q1 |
## | `hint` | `Oracle.hint` (a pure function, below). | R-RP2 |
## | `Fail` | The solver found no tuple. A proof with a unit fail (a hard fail, a hang, a crash of a release on the compiler) has the text `no tuple works: the unit check on <compiler> fails for <blame>; <blame>` (the text of `Units.judge`, R-PH13). Else the text of `Pick.step`: a slot with no value gives the first message of its table, else `no tuple works: the releases of <id>, <id> do not fit together (R-C2, R-C3)`. | R-PH10, R-PH13 |
##
## Equal to `Pick.step`: the rows of `tests/unit/pick.roc`, `pickclosure.roc` and `pickmoves.roc` run on `Oracle.step` and give the values that they gave before: the result, the failure texts and the `Need` lists.
Oracle :: [].{

	## The input of `step` (the one of `Pick.step`).
	Input : {
		slots : List(Pick.Slot),
		strategy : [Highest, Lowest],
		now : U64,
		min_age : U64,
		snapshot : Try(U64, [None]),
		facts : List({ url : Str, release : Release }),
		unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
		paths : List(Closure.Node),
		second : Bool,
	}

	## Slice 036b (R-AL4, R-EP8, R-EP9, R-LF2): what the step knows about probes. `compiler` is the one compiler of D (the held compiler), `Err(None)` for no probe and no lookup (`--no-check`, `verify`). `checks` are the rows of the db that the command has, `looked` are the keys that it looked up,
	## `probes` is `Off` for `--no-probe`, and `conflicts` are the tuples that the ladder dropped (a list of (place of a slot, release URL) for each).
	## Slice 036b2: `used` are the scan results: for a release URL (`id`), the modules of that release that the app uses (`path` relative to the package dir, `Yaml.roc`). A row with `modules: []` is a scan that found no module.
	## Slice 036c: `domain` is D (the table above), `inferred` are the inferred facts of `Epochs.epochs` over D and the rows (`[]` when D is not read). `checks` can have the rows of any compiler of D (the command loaded them with D).
	Compat : { compiler : Try(Str, [None]), checks : List(Db.Fact), looked : List(Db.Key), probes : [Allowed, Off], conflicts : List(List({ at : U64, id : Str })), used : List({ id : Str, modules : List(Str) }), domain : Try(List(Str), [NotRead]), inferred : List(Epochs.Inferred) }

	## A pair that the step wants facts for: a release URL on a compiler. `is_platform` marks the platform (R-LD3: it has a text of its own).
	Pair : { id : Str, nightly : Str, is_platform : Bool }

	## What `step_probed` gives.
	## Slice 036c: `Wide` asks for D (the table above).
	Verdict : [Need(List(Str)), Pairs(List(Oracle.Pair)), Scan({ ids : List(Str), chosen : List(Pick.Chosen) }), Wide, Done(List(Pick.Chosen)), Fail(Fail)]

	## Slice 039 (R-SP8, R-SP9, R-SP12, R-SP13, R-UP6): what `step_free` gives. As `Verdict`, and `Done` has the compiler that the tuple uses (`nightly`, `Err(None)` for a run with no compiler).
	Free : [Need(List(Str)), Pairs(List(Oracle.Pair)), Scan({ ids : List(Str), chosen : List(Pick.Chosen) }), Wide, Done({ chosen : List(Pick.Chosen), nightly : Try(Str, [None]) }), Fail(Fail)]

	## Slice 039: the step with a free compiler slot. `askable` are the values that the compiler slot may take (`NightlyPlan.pick`), `Err(Held)` is the one value H (`compat.compiler`). H is always a value.
	## `step_probed` is `step_free` with `Err(Held)`, and it drops the `nightly` of `Done` (the old tests keep their answers).
	## The compiler slot is the last slot of the solver (the packages are first, in the order of `priority`), so R-SP13 holds: for `upgrade X roc` the best release of X is chosen before the best compiler.
	## The best compiler is the newest value of `askable` that no fact excludes (R-SP12: "the newest nightly that all held hashes pass on"). A pair (release, compiler) with no real fact is a `Pairs` row on that compiler (R-AL4),
	## so the facts of the newest compilers are asked first. H has the assumed pass (R-BL3) and is the last value that is tried. A compiler that is not in `compat.domain` is not a value.
	## `Done.nightly` is the value of the compiler slot, `Err(None)` when `compat.compiler` is `Err(None)`. Everything else is the table of `step_probed`. The L0 file `tests/unit/oraclefree.roc` has the rows.
	step_free : Oracle.Input, Oracle.Compat, Try(List(Str), [Held]) -> Oracle.Free
	step_free = |_input, _compat, _askable| crash "todo: slice 039"

	## The step of slice 036: `step_probed` with no compiler.
	step : Oracle.Input -> [Need(List(Str)), Done(List(Pick.Chosen)), Fail(Fail)]
	step = |input| match Oracle.step_probed(input, { compiler: Err(None), checks: [], looked: [], probes: Off, conflicts: [], used: [], domain: Err(NotRead), inferred: [] }) {
		Need(ids) => Need(ids)
		Done(chosen) => Done(chosen)
		Fail(fail) => Fail(fail)
		Pairs(_) => Fail(Fail.new(Internal, "the step asked for a probe, and it has no compiler"))
		Scan(_) => Fail(Fail.new(Internal, "the step asked for a scan, and it has no compiler"))
		Wide => Fail(Fail.new(Internal, "the step asked for the compiler list, and it has no compiler"))
	}

	## The step with the probe facts (the table above).
	step_probed : Oracle.Input, Oracle.Compat -> Oracle.Verdict
	step_probed = |input, compat| step_with(input, compat, Bool.True)

	## Slice 036c (R-RP2): the oldest nightly that works. `compat.domain` is `Ok(D)` and `compat.compiler` is H. The answer is the id of the first compiler of D (oldest first) other than H on which the same step, with that compiler held,
	## is `Done` with real facts only (rule 1), and `Err(None)` when no compiler is. It is the nightly that `tln roc use <id>` can name: on it the command would end with a tuple, by the facts that the command has.
	##
	## | # | Rule | Source |
	## | --- | --- | --- |
	## | 1 | The step on a compiler `n` is `step_probed` with `compiler: Ok(n)`, `probes: Allowed`, `inferred: []`, `conflicts: []` and the same `checks`, `used` and `domain`. Only `Done` counts: `Pairs`, `Scan`, `Fail` and `Wide` do not, and a `Need` does not (but see the header rule below). So a tuple that has a pair with no real fact on `n` does not make `n` the answer (R-EP8: an inferred fact never decides). A `Need` for a header that the command has not read is no fact about `n`: the header is taken as fit (an empty fact, D3) and the step runs again | R-EP8, R-RP2 |
	## | 2 | The header value has no assumed pass on `n` (D2 of slice 036b holds for H only): its pair on `n` needs a real row | D2 revisit |
	## | 3 | `n` is any compiler of D other than H, older or newer than H. The first in the order of D is the answer | R-RP2 "the oldest nightly" |
	## | 4 | `Err(None)` when `compat.compiler` is `Err(None)`, when `compat.domain` is `Err(NotRead)`, and when H is not in D | R-EP11 |
	hint : Oracle.Input, Oracle.Compat -> Try(Str, [None])
	hint = |input, compat| match (compat.compiler, compat.domain) {
		(Ok(held), Ok(d)) if d.contains(held) => d.keep_if(|n| n != held).find_first(|n| works_on(input, compat, n)).map_err(|_| None)
		_ => Err(None)
	}
}

# `assume` is on for the step of a command: the header value has the assumed pass on H, and a failure is explained. The step of `hint` runs on another compiler with `assume` off (D2, no explanation: `failure` calls `hint`).
step_with : Step, Oracle.Compat, Bool -> Oracle.Verdict
step_with = |input, compat, assume| match Pick.empty_domain(input) {
	Ok(fail) => Fail(fail)
	Err(NoFailure) => search(input, compat, assume, request_of(input, compat, assume), movable_of(input), [])
}

# R-RP2 rule 1: the same step on the compiler `n`, with real facts only.
works_on : Step, Oracle.Compat, Str -> Bool
works_on = |input, compat, n| settled(input, { ..compat, compiler: Ok(n), probes: Allowed, inferred: [], conflicts: [] }, 3)

# A `Need` is no fact about the compiler: the release is taken as fit (an empty fact, D3) and the step runs again, `rounds` times at most.
settled : Step, Oracle.Compat, U64 -> Bool
settled = |input, compat, rounds| match step_with(input, compat, Bool.False) {
	Done(_) => Bool.True
	Need(ids) => rounds > 0 and settled(with_empty(input, ids), compat, rounds - 1)
	_ => Bool.False
}

with_empty : Step, List(Str) -> Step
with_empty = |input, ids| {
	urls = ids.keep_if(|id| Ident.of_url(id).is_ok())
	facts = urls.map(|url| { url, release: { kind: if platform_of(input, url) Platform else Package, pf: Err(None), deps: [] } })
	paths = ids.keep_if(|id| Ident.of_url(id).is_err()).map(|id| { id, entries: [] })
	{ ..input, facts: input.facts.concat(facts), paths: input.paths.concat(paths) }
}

Step : {
	slots : List(Pick.Slot),
	strategy : [Highest, Lowest],
	now : U64,
	min_age : U64,
	snapshot : Try(U64, [None]),
	facts : List({ url : Str, release : Release }),
	unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
	paths : List(Closure.Node),
	second : Bool,
}

# D6: the solver names a slot by its place.
slot_name : U64 -> Str
slot_name = |i| "s${i.to_str()}"

# R-SP24: only the second search moves the `Movable` slots.
movable_of : Step -> List(Str)
movable_of = |input| if input.second input.slots.map_with_index(|slot, i| (slot, i)).keep_if(|(slot, _)| slot.hold == Movable).map(|(_, i)| slot_name(i)) else []

group_key : { form : Str, series : Str } -> Str
group_key = |g| "${g.form} ${g.series}"

# The group of the header value, else of the first candidate in the byte order of the URLs (R-DT2).
slot_group : Pick.Slot -> Str
slot_group = |slot| {
	of_first = match slot.candidates.sort_with(|a, b| Text.compare(a.url, b.url)).first() {
		Ok(c) => group_key(c.ident.group)
		Err(_) => ""
	}
	match slot.current {
		Ok(url) => Ident.of_url(url).map_ok(|ident| group_key(ident.group)) ?? of_first
		Err(None) => of_first
	}
}

# R-SP1, R-C9: a closed slot has the one value `current`, with no candidate and no range.
solver_slot : Pick.Slot, U64, Bool -> Solver.Slot
solver_slot = |slot, i, second| {
	open = slot.hold == Free or (slot.hold == Movable and second)
	{
		name: slot_name(i),
		group: slot_group(slot),
		kind: if slot.is_platform Platform else Package,
		candidates: if open slot.candidates.map(|c| { id: c.url, version: c.ident.version, published_at: c.published_at, yanked: Bool.False }) else [],
		ranges: if open slot.ranges else [],
		current: match slot.current {
			Ok(url) => Ident.of_url(url).map_ok(|ident| { id: url, version: ident.version }).map_err(|_| None)
			Err(None) => Err(None)
		},
		named: if open slot.named else Err(None),
	}
}

# R-H4: a dep that is no release URL is dropped.
solver_fact : { url : Str, release : Release } -> Solver.Fact
solver_fact = |f| { id: f.url, kind: f.release.kind, pf: f.release.pf, deps: f.release.deps.keep_oks(|dep| Ident.of_url(dep).map_ok(|ident| { group: group_key(ident.group), version: ident.version })) }

# The values of a solver slot with the group of each (the candidates and `current`).
releases : Solver.Slot -> List((Str, Str))
releases = |slot| {
	listed = slot.candidates.map(|c| c.id)
	ids = match slot.current {
		Ok(c) => if listed.contains(c.id) listed else listed.append(c.id)
		Err(_) => listed
	}
	ids.keep_oks(|id| Ident.of_url(id).map_ok(|ident| (id, group_key(ident.group))))
}

# D7, R-WS2: 2 slots have one value for a group. For each release of the first slot, the releases of the second slot in that group (other than it) cannot go with it.
same_group : List(Solver.Slot) -> List(List(Solver.Term))
same_group = |slots| {
	rows = slots.map(|slot| (slot.name, releases(slot)))
	rows.map_with_index(|(name, mine), i| (name, mine, rows.drop_first(i + 1))).join_map(
		|(name, mine, later)| later.join_map(
			|(other, theirs)| mine.join_map(
				|(a, g)| {
					clash = theirs.keep_if(|(b, h)| h == g and b != a).map(|(b, _)| b)
					if clash.is_empty() [] else [[{ name, ids: [a], sign: In }, { name: other, ids: clash, sign: In }]]
				},
			),
		),
	)
}

# R-AL3, R-EP7: the request. The compiler slot is the last one, so the decision order of the other slots does not change.
request_of : Step, Oracle.Compat, Bool -> Solver.Request
request_of = |input, compat, assume| {
	slots = input.slots.map_with_index(|slot, i| solver_slot(slot, i, input.second))
	base = {
		slots,
		rules: { now: input.now, min_age: input.min_age, snapshot: input.snapshot, strategy: input.strategy },
		facts: input.facts.map(solver_fact),
		conflicts: same_group(slots).concat(given(compat.conflicts)),
		compat: { domain: [], checks: [], used: [], probes: Off },
	}
	match compat.compiler {
		Ok(nightly) => {
			domain = OracleDomain.space(compat.domain, nightly)
			{ ..base, slots: slots.append(roc_slot(nightly)), compat: { domain, checks: checks_of(input, compat, { domain, assumed: if assume Ok(nightly) else Err(None) }), used: used_of(input, compat), probes: compat.probes } }
		}
		Err(None) => base
	}
}

roc_name : Str
roc_name = "roc"

# The compiler variable: one value, the compiler of D (the solver reads the `id` of a candidate only).
roc_slot : Str -> Solver.Slot
roc_slot = |nightly| { name: roc_name, group: roc_name, kind: Compiler, candidates: [{ id: nightly, version: nightly, published_at: 0, yanked: Bool.False }], ranges: [], current: Err(None), named: Err(None) }

# R-AL5: a tuple that the ladder dropped is a conflict of the caller. A place that is no slot never applies.
given : List(List({ at : U64, id : Str })) -> List(List(Solver.Term))
given = |conflicts| conflicts.map(|terms| terms.map(|t| { name: slot_name(t.at), ids: [t.id], sign: In }))

current_of : Pick.Slot -> List(Str)
current_of = |slot| match slot.current {
	Ok(url) => [url]
	Err(None) => []
}

is_current : Pick.Slot, Str -> Bool
is_current = |slot, url| match slot.current {
	Ok(cur) => cur == url
	Err(None) => Bool.False
}

# R-UM1: the used modules of each release: the scan result, and `main.roc` (roc reads it for each package of the closure, `Units.judge`).
used_of : Step, Oracle.Compat -> List(Solver.Use)
used_of = |input, compat| {
	urls = input.slots.join_map(|slot| slot.candidates.map(|c| c.url).concat(current_of(slot)))
	urls.map(|url| { id: url, modules: (compat.used.find_first(|u| u.id == url).map_ok(|u| u.modules) ?? []).append("main.roc") })
}

# R-EP7, R-EP8, R-EP14, D2: the checks of each release of the slots on each compiler of D (`OracleDomain.checks`).
checks_of : Step, Oracle.Compat, { domain : List(Str), assumed : Try(Str, [None]) } -> List(Solver.Check)
checks_of = |input, compat, on| OracleDomain.checks({
	urls: input.slots.join_map(|slot| slot.candidates.map(|c| c.url).concat(current_of(slot))),
	current: input.slots.join_map(current_of),
	rows: compat.checks,
	inferred: compat.inferred,
	domain: on.domain,
	assumed: on.assumed,
})

# D3: a release with no fact has an empty fact of the kind of its slot, so the tuple is the optimistic one and the closure walk can ask for the nodes below it.
optimistic : Solver.Request, Solver.Ask -> Try(Solver.Fact, [NoHeader])
optimistic = |req, ask| match ask {
	Header(id) => {
		holds = |slot| slot.candidates.any(|c| c.id == id) or (
			match slot.current {
				Ok(c) => c.id == id
				Err(_) => Bool.False
			}
		)
		kind = match req.slots.find_first(holds) {
			Ok(slot) => if slot.kind == Platform Platform else Package
			Err(_) => Package
		}
		Ok({ id, kind, pf: Err(None), deps: [] })
	}
	Probe(_) => Err(NoHeader)
}

is_header : Solver.Ask -> Bool
is_header = |ask| match ask {
	Header(_) => Bool.True
	Probe(_) => Bool.False
}

platform_of : Step, Str -> Bool
platform_of = |input, id| input.slots.any(|slot| slot.is_platform and (slot.candidates.any(|c| c.url == id) or is_current(slot, id)))

# R-AL4: the pairs that the solver asks for, in its order.
pairs_of : Step, List(Solver.Ask) -> List(Oracle.Pair)
pairs_of = |input, asks| asks.keep_oks(
	|ask| match ask {
		Probe(p) => Ok({ id: p.id, nightly: p.nightly, is_platform: platform_of(input, p.id) })
		Header(_) => Err(NoPair)
	},
)

# R-AL9, R-EP8: a problem of the closure is a conflict of the whole tuple (034 Q3), and the solver gives the next tuple. `tried` are those conflicts. The facts of the releases that the solver asked for stay in `req`: they are optimistic (D3).
search : Step, Oracle.Compat, Bool, Solver.Request, List(Str), List(List(Solver.Term)) -> Oracle.Verdict
search = |input, compat, assume, req, movable, tried| match Solver.step_moves({ ..req, conflicts: req.conflicts.concat(tried) }, movable) {
	Fail(why) => if wants_domain(compat) and has_probe(why) Wide else Fail(failure(input, compat, assume, why))
	Need(asks) => if asks.any(is_header) {
		search(input, compat, assume, { ..req, facts: req.facts.concat(asks.keep_oks(|ask| optimistic(req, ask))) }, movable, tried)
	} else {
		fetch_first(input, pairs_of(input, asks))
	}
	Done(chosen) => walked(input, compat, assume, { req, movable, tried }, chosen.keep_if(|c| c.name != roc_name))
}

# R-AL8, R-AL4: the release of a pair needs its package in the cache before its probe runs (a unit probe runs in the package dir), and the header of the package is a fact of the pick. So the header of each pair release that the command has not read is a `Need`. Then the pairs.
fetch_first : Step, List(Oracle.Pair) -> Oracle.Verdict
fetch_first = |input, pairs| match pairs.keep_if(|pair| !input.facts.any(|f| f.url == pair.id)).map(|pair| pair.id) {
	[] => Pairs(pairs)
	ids => Need(ids)
}

# The closure walk of a tuple (R-AL9), then the lookups of `Off` (R-LF2).
walked : Step, Oracle.Compat, Bool, { req : Solver.Request, movable : List(Str), tried : List(List(Solver.Term)) }, List(Solver.Chosen) -> Oracle.Verdict
walked = |input, compat, assume, run, chosen| {
	verdict = Pick.closure_verdict({
		members: if input.unmanaged.is_empty() [{ file: "", entries: [] }] else input.unmanaged,
		nodes: input.facts.map(|f| Pick.node_of(f)).concat(input.paths),
		picked: input.slots.map2(chosen, |slot, c| { files: slot.files, is_platform: slot.is_platform, url: c.id }),
	})
	match verdict {
		Problem => search(input, compat, assume, run.req, run.movable, run.tried.append(chosen.map(|c| { name: c.name, ids: [c.id], sign: In })))
		Fine([]) => match lookups(input, compat, chosen) {
			[] => scanned(input, compat, chosen)
			pairs => if wants_domain(compat) Wide else Pairs(pairs)
		}
		Fine(ids) => Need(ids)
	}
}

# R-UM1, R-AL5 (036 Q3): a chosen release with a fail in a module (not `main.roc`, the solver drops that one) and no scan result needs a scan. Else the tuple is done.
scanned : Step, Oracle.Compat, List(Solver.Chosen) -> Oracle.Verdict
scanned = |input, compat, chosen| {
	picked = input.slots.map2(chosen, |slot, c| chosen_of(input, slot, c))
	ids = match compat.compiler {
		Ok(nightly) => chosen
			.map(|c| c.id)
			.fold([], |found, id| if found.contains(id) found else found.append(id))
			.keep_if(|id| needs_scan(compat, nightly, id))
		Err(None) => []
	}
	if ids.is_empty() Done(picked) else Scan({ ids, chosen: picked })
}

needs_scan : Oracle.Compat, Str, Str -> Bool
needs_scan = |compat, nightly, id| match OracleDomain.row_of(compat.checks, nightly, id) {
	Ok(f) => f.outcome == Fail and !f.modules.is_empty() and !f.modules.contains("main.roc") and !compat.used.any(|u| u.id == id)
	Err(_) => Bool.False
}

# R-LF2, R-EP9: with `Off` the step cannot ask for a probe. A chosen release that changes, has no row and was not looked up is a pair for the command to look up in the db. No compiler, no lookup (R-SO22).
lookups : Step, Oracle.Compat, List(Solver.Chosen) -> List(Oracle.Pair)
lookups = |input, compat, chosen| match (compat.compiler, compat.probes) {
	(Ok(nightly), Off) => {
		wanted = input.slots.map2(chosen, |slot, c| (slot, c.id)).keep_if(
			|(slot, url)| !is_current(slot, url) and OracleDomain.row_of(compat.checks, nightly, url).is_err() and !compat.looked.any(|k| k.hash == OracleDomain.hash_of(url) and k.nightly == nightly and k.target == "any"),
		)
		wanted
			.fold([], |found, (_, url)| if found.contains(url) found else found.append(url))
			.map(|url| { id: url, nightly, is_platform: platform_of(input, url) })
	}
	_ => []
}

# Slice 036c: the step asks for D (`Wide`) once, when it has a compiler and the command has not read the list.
wants_domain : Oracle.Compat -> Bool
wants_domain = |compat| compat.compiler.is_ok() and (
	match compat.domain {
		Err(NotRead) => Bool.True
		Ok(_) => Bool.False
	}
)

has_probe : Solver.Why -> Bool
has_probe = |why| why.steps.any(
	|step| match step.cause {
		Probe(_) => Bool.True
		_ => Bool.False
	},
)

# R-EP7: the releases that the proof blames, with their interval on D. A fault is a hang or a crash by the row of H. No repeat.
causes_of : Step, Oracle.Compat, Solver.Why -> List(Explain.Cause)
causes_of = |input, compat, why| why.steps
	.keep_oks(
		|step| match step.cause {
			Probe(p) => Ok({
				label: label_of(input, p.id),
				alias: alias_of(input, p.id),
				kind: match p.kind {
					Fail => Fail
					Fault => match OracleDomain.row_of(compat.checks, compat.compiler ?? "", p.id) {
						Ok(f) => if f.outcome == Hang Hang else Crash
						Err(_) => Crash
					}
				},
				modules: p.modules,
				from: p.from,
				to: p.to,
				inferred: p.inferred,
			})
			_ => Err(NoProbe)
		},
	)
	.fold([], |found, c| if found.contains(c) found else found.append(c))

# R-PH13: the text of a failure. A unit fail in the proof is the blame of `Units.judge` (the same text, so a run with one tuple gives the text of slice 031). Else the text of `Pick.step`.
# R-RP2: with `assume` the lines of `Explain.lines` follow, and the details are `Explain.details`.
failure : Step, Oracle.Compat, Bool, Solver.Why -> Fail
failure = |input, compat, assume, why| {
	nightly = compat.compiler ?? ""
	causes = causes_of(input, compat, why)
	blames = causes.map(blame_text).fold([], |found, text| if found.contains(text) found else found.append(text))
	first = "no tuple works: the unit check on ${nightly} fails for ${Str.join_with(blames, "; ")}"
	if causes.is_empty() {
		Fail.new(NoTuple, "no tuple works: the releases of ${Str.join_with(input.slots.map(|slot| slot.id), ", ")} do not fit together (R-C2, R-C3)")
	} else if assume {
		hint = Oracle.hint(input, compat)
		{ ..Fail.new(NoTuple, "${first}\n${Str.join_with(Explain.lines({ causes, hint }), "\n")}"), details: Ok(Explain.details({ held: nightly, causes, hint })) }
	} else {
		Fail.new(NoTuple, first)
	}
}

# R-LD3, R-EP7: `<name> <version> (<what>)`, or `the platform <name> <version> (<what>)`. A fault is `hangs` or `crashes`, a fail with no module is `no module is named`.
blame_text : Explain.Cause -> Str
blame_text = |c| {
	what = match c.kind {
		Hang => "hangs"
		Crash => "crashes"
		Fail => if c.modules.is_empty() "no module is named" else Str.join_with(c.modules, ", ")
	}
	"${c.label} (${what})"
}

# R-LD3: `<name> <version>`, or `the platform <name> <version>`.
label_of : Step, Str -> Str
label_of = |input, id| {
	name = match Ident.of_url(id) {
		Ok(ident) => "${ident.name ?? id} ${ident.version}"
		Err(_) => id
	}
	if platform_of(input, id) "the platform ${name}" else name
}

# The alias of the slot of a release (`""` for the platform: the app cannot stop using it).
alias_of : Step, Str -> Str
alias_of = |input, id| match input.slots.find_first(|slot| !slot.is_platform and (slot.candidates.any(|c| c.url == id) or is_current(slot, id))) {
	Ok(slot) => slot.id
	Err(_) => ""
}

chosen_of : Step, Pick.Slot, Solver.Chosen -> Pick.Chosen
chosen_of = |input, slot, c| Pick.chosen_for({ slot, url: c.id, version: c.version, published_at: slot.candidates.find_first(|x| x.url == c.id).map_ok(|x| x.published_at) ?? 0, now: input.now, min_age: input.min_age })
