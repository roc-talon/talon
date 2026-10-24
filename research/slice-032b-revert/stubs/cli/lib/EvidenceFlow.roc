import Closure
import Evidence
import Fail
import Fx
import ResolveBase

## Command code (part C) of the evidence of `tln why` (slice 032b, E1 to E3, R-EF1, R-EF3, R-CM7, R-PH12). The pure decisions are in `Evidence`. `Why.run!` calls `blocks!` after the answers (`Why.answers`) and before the output.
## The calls, in order (the L2 cases `evidence/ev1-why` and `ev2-no-compiler` fix them). Nothing is written, nothing is downloaded and no probe runs:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | The compiler of each member, once for each member file: the `roc:` pin of its header (rank 3, the answer of the user for R-SO20: the pin wins), else `ROC_TOOLCHAIN` (rank 2, `Compiler.toolchain_of`), else `ResolveSelect.peek!` (ranks 4 to 7, with the `roc` on `PATH` from `Install.compiler!`, asked at most once for the run). `Err(None)`: no compiler, so no block for that member and no further call for it. A member with a pin or `ROC_TOOLCHAIN` makes no call for this step | E1, R-SO2, R-SO3, R-SO7, R-PH7 |
## | 2 | A member whose package is not a `Release` row (a path file, a foreign URL) has no hash: it has a compiler in the block, no line and no further call | R-H4 |
## | 3 | One `read_files!` of `<pkgs>/<hash>/main.roc` for each package that is shown with a compiler (none when there is none): `Evidence.pin_of`. An unreadable file is no pin | E3, R-EF1 rank 3 |
## | 4 | One `Facts.load!` (one `db_query!` with `Facts(keys)`) for the keys (hash, compiler, `any`) of the packages that are shown with a compiler (none when there is none). A busy or failing db: the warning of R-CC8 on stderr and no local row. `TooNew` is the failure (exit 19) | E2, R-CC8, R-TF3 |
## | 5 | Rank 4: `Err(None)` for every package (`Github.hint!` keeps no cache today: question Q1 of slice 032b). No call | E3 |
## | 6 | A package with a `Local` fail that has modules: the scan of the used modules of its member (`UnitFlow.scan_in!`: one `read_files!` for each level. The text of the member is the one that the load read, so the member file is not read again) and `Evidence.ignored` with the empty baseline. Each entry is a note (`Evidence.note`). No fail row: no call | E5, R-UM1 |
## | 7 | `Evidence.of_pair` for each package, the block | R-EF3 |
##
## Wiring that the code agent writes (not stubs; the files stay as they are before the slice):
##
## | File | Change |
## | --- | --- |
## | `Ls.walk!` | A new public `Ls.walk_full!` that gives `{ closures, request, loaded }` (the `ResolveBase.Request` and the `ResolveBase.Loaded` of the walk). `walk!` calls it and keeps its signature |
## | `ResolveSelect` | A new public `peek!` : `Fx, ResolveBase.Request, ResolveBase.Loaded => Try(Str, [None])`: the steps 2 to 4 of `choose!` (the lists of the installed compilers and `Compiler.select`, one private function that `choose!` calls too) and the id, with no `ranged!` (no download). `NoCompiler` and `NoneInRange` are `Err(None)` |
## | `Why.run!` | `Ls.walk_full!` (with `notes` false), `answers`, `EvidenceFlow.blocks!`, then `Why.show` for the text or `Why.shown_data` for `--json` |
## | `UnitFlow` | A new public `scan_in!` that takes `{ roots, member : { file, kind, text }, walked }`. `scan!` calls it and keeps its signature |
## | `UnitFlow.verdict!` | The result also has `ignored : List(Evidence.Ignored)`: `Evidence.ignored` of the nodes, the facts of the round, the baseline and the scan (`[]` when `used` is `Err(NotScanned)`) |
## | `Ladder` (`probe_in_copy!`, `probe_in_place!`) | After the lines of the check and of the build, one line `note: <Evidence.note>` for each entry of `verdict.ignored` (`compiler` is `ctx.held`). So the summary of `install`, `add`, `update`, `upgrade`, `verify` and `remove` has the notes after the build line, in `data.notes` too (E5) |
EvidenceFlow :: [].{

	## A package that `why` shows: the `file` of its member, the closure of the member and the row of the package.
	Shown : { file : Str, walked : Closure.Walked, target : Closure.Row }

	## The block of each package, in the order of `shown`. See the table above.
	blocks! : Fx, { request : ResolveBase.Request, loaded : ResolveBase.Loaded }, List(EvidenceFlow.Shown) => Try(List(Evidence.Block), Fail)
	blocks! = |_fx, _ctx, _shown| crash "todo"
}
