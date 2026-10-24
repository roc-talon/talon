import Db
import JsonDoc
import Probe

## The evidence of a package version and the unit-fail note (Resolution 3 R-EF1, R-EF3; CLI R-CM7; Design 7 R-PH12; Resolution 4 R-UM1; slice 032b). Part A (pure). The command code is `EvidenceFlow`.
## The evidence of a pair (hash, compiler) is the set of facts `works(hash, nightly)` from the sources of R-EF1. P1 with `direct` has three of them (the others need the registry, P2, or the index, R-DI1):
##
## | Rank | `Source` | Where it comes from | Result |
## | --- | --- | --- | --- |
## | 1 | `Local` | the row of `compat.db` for (hash, compiler, target `any`) (slice 030, 031) | `pass`, `fail` (with the failing modules), `hang`, `crash` |
## | 3 | `Pin` | the `roc:` entry of the header of the release (`packages/<hash>/main.roc`), when it is the compiler (`Pin.same_id`) | `pass` (a hint: the author says it passed) |
## | 4 | `Hint` | the `.roc-version` of the release tag, from the cache of an earlier `Github.hint!` call, when it is the compiler | `pass` (a hint) |
##
## R-EF3: the lines are in rank order, and the first line is the fact that Talon uses (the winner, marked `*` in the text). A source with no value for the pair has no line. A rank 3 pin for another compiler is no value for this pair.
## Rank 4 has no cache today (`Github.hint!` keeps none): the command passes `Err(None)` until a slice writes the cache (question Q1 of slice 032b). The pure code is ready for it.
##
## The text of `tln why` for one package (a proposal, TW24, R-OUT2). `Why.show` puts it after the path lines. Nothing is printed when there is no compiler, or no source has a value:
##
## ```text
##     evidence on nightly-2026-10-14-38a3029:
##       * 1 local: fail (Yaml.roc)
##         3 pin: pass
##     note: module Yaml fails on nightly-2026-10-14-38a3029. Your app does not import it.
## ```
Evidence :: [].{

	## The source words of a line, for the text and for `--json` (`source`): `local`, `pin`, `roc-version`.
	Source : [Local, Pin, Hint]

	## One source that has a value. `rank` is 1, 3 or 4. `result` is `Pass` for `Pin` and `Hint`. `modules` are the failing modules of a `Local` fail (as the fact has them, sorted), else `[]`.
	Line : { rank : U64, source : Evidence.Source, result : Db.Outcome, modules : List(Str) }

	## The evidence of one package for `tln why`. `compiler` is the compiler of the member (Resolution 13, no download): `Err(None)` when none is selected. `lines` are in rank order. `notes` are the unit-fail notes
	## (`Evidence.note`, no prefix) for the modules of the `Local` fail that the app does not import (`Evidence.ignored`).
	Block : { compiler : Try(Str, [None]), lines : List(Evidence.Line), notes : List(Str) }

	## A unit fail that the scan of the used modules ignored (R-UM1): the package `hash` and the path of the failing module in the package (`Yaml.roc`).
	Ignored : { hash : Str, path : Str }

	## R-EF1, R-EF3: the lines of one pair, in rank order (1, 3, 4). `facts` are the rows that a query gave (rows of other keys are ignored).
	##
	## | Rank | Line when |
	## | --- | --- |
	## | 1 | a row has `hash`, `nightly` equal to `compiler` (the same text) and the target `any`. A build row (a host target) is no evidence of a check. `result` and `modules` are the ones of the row |
	## | 3 | `pin` is `Ok(id)` and `Pin.same_id(id, compiler)` (R-CV1: the two tag forms of a nightly are one compiler). `Pass`, no modules |
	## | 4 | `hint` is `Ok(id)` and `Pin.same_id(id, compiler)`. `Pass`, no modules |
	of_pair : { hash : Str, compiler : Str, facts : List(Db.Fact), pin : Try(Str, [NoPin]), hint : Try(Str, [None]) } -> List(Evidence.Line)
	of_pair = |_facts| crash "todo"

	## R-EF1 rank 3: the `roc:` pin of the header text of a release (`Locked.read`, which reads a package header as an app header, R-H8). A header with no pin, a text with no header and a pin that is not a full
	## compiler id (R-SC12) are `Err(NoPin)`: a bad pin is no evidence, and `why` is not the place to refuse it. `path` is for the failure of `Locked.read`, which this function drops.
	pin_of : { path : Str, text : Str } -> Try(Str, [NoPin])
	pin_of = |_facts| crash "todo"

	## The text of the block (the example above). Empty when `compiler` is `Err(None)` or `lines` is empty. Else:
	##
	## | Line | Text |
	## | --- | --- |
	## | 1 | 4 spaces, `evidence on <compiler>:` |
	## | each line of `lines` | 6 spaces, `*` for the first line and a space for the others, a space, the rank, a space, the source word, `: `, the result |
	## | each of `notes` | 4 spaces, `note: `, the note |
	##
	## The result is `pass`, `hang`, `crash`, `fail`, or `fail (<module>, <module>)` for a fail with modules (in the order of the line). Each line ends with a line end.
	text : Evidence.Block -> Str
	text = |_block| crash "todo"

	## The members of `data.members[]` of `tln why --json` that the evidence adds (R-OUT4: each fact that the text prints), in this order:
	##
	## | Key | Value |
	## | --- | --- |
	## | `compiler` | The compiler id, or null |
	## | `evidence` | A list in rank order (`[]` when there is no compiler or no value): `{ "rank", "source", "result", "modules", "winner" }`. `rank` is a number, `source` is `local`, `pin` or `roc-version`, `result` is `pass`, `fail`, `hang` or `crash`, `modules` is a list of texts, `winner` is true for the first line only |
	## | `notes` | The texts of `notes` |
	fields : Evidence.Block -> List((Str, JsonDoc))
	fields = |_block| crash "todo"

	## R-UM1, R-P6: the unit fails that the scan ignored. For each hash of `hashes`, in order, with its row for `nightly` and the target `any` in `facts`: a row with the outcome `Fail` gives one `Ignored` for each of its
	## modules (in the order of the row) that is not explained by the baseline (no error of `baseline` in `Package({ hash, path })` with that module), is not `main.roc` (roc reads it for every package) and is not in `used`.
	## A row with another outcome, no row, a row of another compiler or a build row gives none. A fail with no module gives none (it is a hard fail, `Units.judge`).
	ignored : { hashes : List(Str), facts : List(Db.Fact), nightly : Str, baseline : List(Probe.Err), used : List({ hash : Str, path : Str }) } -> List(Evidence.Ignored)
	ignored = |_facts| crash "todo"

	## The name of a module in a message: the path in the package without the suffix `.roc` (`Yaml.roc` is `Yaml`, `sub/Yaml.roc` is `sub/Yaml`). A path with no suffix stays as it is.
	module_name : Str -> Str
	module_name = |_path| crash "todo"

	## E4: the unit-fail note, with no `note: ` prefix (the caller adds it): `module <Evidence.module_name> fails on <compiler>. Your app does not import it.` It has no error title and no package (the fact stores the failing modules only, R-P4).
	note : { path : Str, compiler : Str } -> Str
	note = |_facts| crash "todo"
}
