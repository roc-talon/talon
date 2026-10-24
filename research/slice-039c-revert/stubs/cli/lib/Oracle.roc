import Fail
import OracleBase
import OracleHint
import OracleRequest
import OracleSearch
import Pick

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
## Slice 039s: the module is split by topic (names in `docs/slices/039s-module-split.md`). The types are in `OracleBase`, the request in `OracleRequest`, the search and the probe rounds in `OracleSearch`, the text of a failure in `OracleCause`, the hint in `OracleHint`. This module has the three steps, and `hint` as one line (the unit tests call it).
##
## Equal to `Pick.step`: the rows of `tests/unit/pick.roc`, `pickclosure.roc` and `pickmoves.roc` run on `Oracle.step` and give the values that they gave before: the result, the failure texts and the `Need` lists.
Oracle :: [].{

	## Slice 039: the step with a free compiler slot. `askable` are the values that the compiler slot may take (`NightlyPlan.pick`), `Err(Held)` is the one value H (`compat.compiler`). H is always a value.
	## `step_probed` is `step_free` with `Err(Held)`, and it drops the `nightly` of `Done` (the old tests keep their answers).
	## The compiler slot is the last slot of the solver (the packages are first, in the order of `priority`), so R-SP13 holds: for `upgrade X roc` the best release of X is chosen before the best compiler.
	## The best compiler is the newest value of `askable` that no fact excludes (R-SP12: "the newest nightly that all held hashes pass on"). A pair (release, compiler) with no real fact is a `Pairs` row on that compiler (R-AL4),
	## so the facts of the newest compilers are asked first. H has the assumed pass (R-BL3) and is the last value that is tried. A compiler that is not in `compat.domain` is not a value.
	## `Done.nightly` is the value of the compiler slot, `Err(None)` when `compat.compiler` is `Err(None)`. Everything else is the table of `step_probed`. The L0 file `tests/unit/oraclefree.roc` has the rows.
	step_free : OracleBase.Input, OracleBase.Compat, Try(List(Str), [Held]) -> OracleBase.Free
	step_free = |input, compat, askable| match Pick.empty_domain(input) {
		Ok(fail) => Fail(fail)
		Err(NoFailure) => OracleSearch.search(input, compat, Bool.True, OracleRequest.request_of(input, compat, Bool.True, askable), OracleRequest.movable_of(input), [], OracleHint.hint)
	}

	## Slice 039c (R-RP4, R-SP16, R-SP23, R-SP24): the step of the second search of `tln upgrade X` (the nightly is held, and a held move of `upgrade` can include it). The compiler slot is movable: it has the header value H (`compat.compiler`) as `current`, and `values` are the compilers
	## that it may take (`NightlyPlan.movable`, H is always a value). `Solver.step_moves` gets the names of the movable packages and `roc`, so the movable packages are first in the search, then the compiler (it is the last slot), then the free packages.
	## So the compiler keeps H when a tuple exists with H and the earlier movable packages, and else moves the smallest step: with `Highest` the nearest compiler above H, then the ones above it up to the newest, then the ones below H from new to old (the order of D, `Solver.step_moves` rule 2).
	## Else the table of `step_free` (`Done.nightly` is the compiler of the tuple, a pair on another compiler is a `Pairs` row, `Wide` asks for D). With no compiler (`compat.compiler` is `Err(None)`) it is `step_free` with `Err(Held)`. The L0 file `tests/unit/oraclefree.roc` has the rows.
	step_moved : OracleBase.Input, OracleBase.Compat, List(Str) -> OracleBase.Free
	step_moved = |_input, _compat, _values| crash "todo: slice 039c"

	## The step of slice 036: `step_probed` with no compiler.
	step : OracleBase.Input -> [Need(List(Str)), Done(List(Pick.Chosen)), Fail(Fail)]
	step = |input| match Oracle.step_probed(input, { compiler: Err(None), checks: [], looked: [], probes: Off, conflicts: [], used: [], domain: Err(NotRead), inferred: [] }) {
		Need(ids) => Need(ids)
		Done(chosen) => Done(chosen)
		Fail(fail) => Fail(fail)
		Pairs(_) => Fail(Fail.new(Internal, "the step asked for a probe, and it has no compiler"))
		Scan(_) => Fail(Fail.new(Internal, "the step asked for a scan, and it has no compiler"))
		Wide => Fail(Fail.new(Internal, "the step asked for the compiler list, and it has no compiler"))
	}

	## The step with the probe facts (the table above).
	step_probed : OracleBase.Input, OracleBase.Compat -> OracleBase.Verdict
	step_probed = |input, compat| match Oracle.step_free(input, compat, Err(Held)) {
		Need(ids) => Need(ids)
		Pairs(pairs) => Pairs(pairs)
		Scan(scan) => Scan(scan)
		Wide => Wide
		Done(done) => Done(done.chosen)
		Fail(fail) => Fail(fail)
	}

	## Slice 036c (R-RP2): the oldest nightly that works (the rules are in the doc of `OracleHint.hint`). Slice 039s: the name stays here, because the unit tests call `Oracle.hint`.
	hint : OracleBase.Input, OracleBase.Compat -> Try(Str, [None])
	hint = OracleHint.hint
}
