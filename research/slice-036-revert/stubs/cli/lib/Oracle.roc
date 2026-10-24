import Closure
import Fail
import Pick
import Release

## The pure step of the oracle loop (slice 036, Resolution 5 steps 3 and 5, R-AL3, R-SP24, R-PH10, R-PH13; TESTING.md 2.2 part B for the command). It is `Pick.step` over the solver step of the package `resolve` (`Solver.step_moves`):
## the same input, the same output, the same texts. `PickLoop.run!` calls it in place of `Pick.step`. Pure: the same input gives the same output (R-DT2).
##
## The input is the one of `Pick.step` (its doc has the fields). The output is `Need` (the ids of the nodes that have no fact: a release URL or the file of a path node), `Done` (one `Pick.Chosen` for each slot, in the order of the slots) or `Fail` (kind `NoTuple`).
##
## | Part | What the step does | Rule |
## | --- | --- | --- |
## | Slots | A slot is a solver slot with the name `s<index>` (the alias `id` of a slot is no key: one alias can name 2 groups in 2 members, R-WS8). Its group is the group of the releases (`Ident.group` of the header value, else of the first candidate). A `Free` slot, and a `Movable` slot with `second`, has its candidates and ranges. A `Held` slot, and a `Movable` slot with no `second`, has no candidate and no range: its one value is `current` (R-SP1, R-C9). `current` is `Err(None)` for a want (and for a value that is no release URL). | R-SP1, R-C1, R-C9 |
## | Facts | A fact is a `Solver.Fact` of a release URL: its kind, its platform, and its deps as (group, version) (a dep that is no release URL is dropped, R-H4). | R-C2, R-C3, R-C4, R-AL8 |
## | Rules | `now`, `min_age`, `snapshot` and `strategy` are the rules of the request (R-C7, R-DT4, R-VA6). The request has no compiler slot, no check and no used module, and `probes` is `Off`: the probe facts are slice 036b. | R-C7 |
## | Same group | Two slots of one group have one value (R-WS2, R-WS3): for each pair of slots with one group, a conflict of the caller says that the value of the second is the value of the first. | R-WS2, R-WS3 |
## | Search | `second: false`: `Solver.step`. `second: true`: `Solver.step_moves` with the names of the `Movable` slots: they are first in the search, in the order of the slots, and try `current` first, then the nearest values (R-SP24). `Done`, `Need` and `Fail` are in the order of the slots. | R-SP24, R-PH10 |
## | `Need` | The header facts that the best tuple lacks (`Solver.Need`, the releases of the slots), in the order of the slots, no repeat. After `Done` the closure of the tuple (below) can ask for more nodes, and then the step gives `Need` of those. | R-AL8, R-AL9 |
## | Closure | After `Done` of the solver, the step walks the closure of the tuple as `Pick.step` does (R-AL9: `Closure.step` for each member, the rules 1 to 4 of the table of `Pick.step`). A problem of the closure is a conflict of the caller: the releases of that tuple cannot all be chosen. The step asks the solver again, so the next tuple is the best one that has no problem. A tuple with nodes that have no fact gives `Need` of those nodes (an unknown node is taken as fit). | R-AL9, 034 Q3 |
## | `Fail` | The solver found no tuple. The text is the text of `Pick.step` for the same case (the doc of `Pick.step`, the table of `Fail`): a slot with no value gives the first message of that table, else `no tuple works: the releases of <id>, <id> do not fit together (R-C2, R-C3)`. | R-PH10, R-PH13 |
##
## Equal to `Pick.step`: the rows of `tests/unit/pick.roc`, `pickclosure.roc` and `pickmoves.roc` run on this step (slice 036: their `step` helper calls `Oracle.step`) and give the values that they gave before: the result, the failure texts and the `Need` lists.
Oracle :: [].{

	step : {
		slots : List(Pick.Slot),
		strategy : [Highest, Lowest],
		now : U64,
		min_age : U64,
		snapshot : Try(U64, [None]),
		facts : List({ url : Str, release : Release }),
		unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
		paths : List(Closure.Node),
		second : Bool,
	} -> [Need(List(Str)), Done(List(Pick.Chosen)), Fail(Fail)]
	step = |_x| crash "todo"
}
