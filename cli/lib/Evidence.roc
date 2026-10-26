import Db
import JsonDoc
import Locked
import Pin
import Probe

## The evidence of a package version and the unit-fail note (Resolution 3 R-EF1, R-EF3; CLI R-CM7; Design 7 R-PH12; Resolution 4 R-UM1; slice 032b). Part A (pure). The command code is `EvidenceFlow`.
## The evidence of a pair (hash, compiler) is the set of facts `works(hash, nightly)` from the sources of R-EF1. P1 with `direct` has three of them (the others need the registry, P2, or the index, R-DI1):
##
## | Rank | `Source` | Where it comes from | Result |
## | --- | --- | --- | --- |
## | 1 | `Local` | the row of `compat.db` for (hash, compiler, target `any`) (slice 030, 031) | `pass`, `fail` (with the failing modules), `hang`, `crash` |
## | 3 | `Pin` | the `roc:` entry of the header of the release (`packages/<hash>/main.roc`), when it is the compiler (`Pin.same_id`) | `pass` (a hint: the author says it passed) |
## | 4 | `Hint` | the `.roc-version` of the release tag, from the cache file of an earlier `Github.hint!` call (R-DI8), when it is the compiler | `pass` (a hint) |
##
## R-EF3: the lines are in rank order, and the first line is the fact that Talon uses (the winner, marked `*` in the text). A source with no value for the pair has no line. A rank 3 pin for another compiler is no value for this pair.
## Rank 4 (slice 068, R-DI8): the cache file of `Github.hint!` (`talon/index/github/<owner>/<repo>/<tag>.roc-version`), read by `EvidenceFlow.blocks!` (step 5). A tag with no file, or an empty file, has no rank 4 line.
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
	of_pair = |pair| {
		local = pair.facts
			.keep_if(|f| f.hash == pair.hash and f.nightly == pair.compiler and f.target == "any")
			.take_first(1)
			.map(|f| { rank: 1, source: Local, result: f.outcome, modules: f.modules })
		hint = |rank, source, found| if is_compiler(found, pair.compiler) [{ rank, source, result: Pass, modules: [] }] else []
		local.concat(hint(3, Pin, pair.pin)).concat(hint(4, Hint, pair.hint))
	}

	## R-EF1 rank 3: the `roc:` pin of the header text of a release (`Locked.read`, which reads a package header as an app header, R-H8). A header with no pin, a text with no header and a pin that is not a full
	## compiler id (R-SC12) are `Err(NoPin)`: a bad pin is no evidence, and `why` is not the place to refuse it. `path` is for the failure of `Locked.read`, which this function drops.
	pin_of : { path : Str, text : Str } -> Try(Str, [NoPin])
	pin_of = |header| match Locked.read(header) {
		Ok(locked) => locked.roc
		Err(_) => Err(NoPin)
	}

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
	text = |block| match block.compiler {
		Err(None) => ""
		Ok(compiler) => if block.lines.is_empty() {
			""
		} else {
			first = block.lines.take_first(1).map(|l| line_text("*", l))
			rest = block.lines.drop_first(1).map(|l| line_text(" ", l))
			notes = block.notes.map(|n| "    note: ${n}\n")
			"    evidence on ${compiler}:\n${Str.join_with(first.concat(rest).concat(notes), "")}"
		}
	}

	## The members of `data.members[]` of `tln why --json` that the evidence adds (R-OUT4: each fact that the text prints), in this order:
	##
	## | Key | Value |
	## | --- | --- |
	## | `compiler` | The compiler id, or null |
	## | `evidence` | A list in rank order (`[]` when there is no compiler or no value): `{ "rank", "source", "result", "modules", "winner" }`. `rank` is a number, `source` is `local`, `pin` or `roc-version`, `result` is `pass`, `fail`, `hang` or `crash`, `modules` is a list of texts, `winner` is true for the first line only |
	## | `notes` | The texts of `notes` |
	fields : Evidence.Block -> List((Str, JsonDoc))
	fields = |block| {
		lines = match block.compiler {
			Ok(_) => block.lines.take_first(1).map(|l| line_doc(l, Bool.True)).concat(block.lines.drop_first(1).map(|l| line_doc(l, Bool.False)))
			Err(None) => []
		}
		[
			(
				"compiler",
				match block.compiler {
					Ok(compiler) => Text(compiler)
					Err(None) => Null
				},
			),
			("evidence", Arr(lines)),
			("notes", Arr(block.notes.map(|n| Text(n)))),
		]
	}

	## R-UM1, R-P6: the unit fails that the scan ignored. For each hash of `hashes`, in order, with its row for `nightly` and the target `any` in `facts`: a row with the outcome `Fail` gives one `Ignored` for each of its
	## modules (in the order of the row) that is not explained by the baseline (no error of `baseline` in `Package({ hash, path })` with that module), is not `main.roc` (roc reads it for every package) and is not in `used`.
	## A row with another outcome, no row, a row of another compiler or a build row gives none. A fail with no module gives none (it is a hard fail, `Units.judge`).
	ignored : { hashes : List(Str), facts : List(Db.Fact), nightly : Str, baseline : List(Probe.Err), used : List({ hash : Str, path : Str }) } -> List(Evidence.Ignored)
	ignored = |run| run.hashes.join_map(
		|hash| run.facts
			.keep_if(|f| f.hash == hash and f.nightly == run.nightly and f.target == "any" and f.outcome == Fail)
			.take_first(1)
			.join_map(
				|f| f.modules
					.keep_if(|path| path != "main.roc" and !run.baseline.any(|err| err.file == Package({ hash, path })) and !run.used.contains({ hash, path }))
					.map(|path| { hash, path }),
			),
	)

	## The name of a module in a message: the path in the package without the suffix `.roc` (`Yaml.roc` is `Yaml`, `sub/Yaml.roc` is `sub/Yaml`). A path with no suffix stays as it is.
	module_name : Str -> Str
	module_name = |path| if path.ends_with(".roc") path.drop_suffix(".roc") else path

	## E4: the unit-fail note, with no `note: ` prefix (the caller adds it): `module <Evidence.module_name> fails on <compiler>. Your app does not import it.` It has no error title and no package (the fact stores the failing modules only, R-P4).
	note : { path : Str, compiler : Str } -> Str
	note = |run| "module ${Evidence.module_name(run.path)} fails on ${run.compiler}. Your app does not import it."
}

# A pin or a hint is a line only when it is the compiler of the block (R-CV1: `Pin.same_id`).
is_compiler : Try(Str, e), Str -> Bool
is_compiler = |found, compiler| match found {
	Ok(id) => Pin.same_id(id, compiler)
	Err(_) => Bool.False
}

source_word : Evidence.Source -> Str
source_word = |source| match source {
	Local => "local"
	Pin => "pin"
	Hint => "roc-version"
}

# `fail (<module>, <module>)` for a fail with modules, else the word of the outcome.
result_text : Evidence.Line -> Str
result_text = |line| if line.result == Fail and !line.modules.is_empty() {
	"fail (${Str.join_with(line.modules, ", ")})"
} else {
	Db.outcome_word(line.result)
}

line_text : Str, Evidence.Line -> Str
line_text = |mark, line| "      ${mark} ${line.rank.to_str()} ${source_word(line.source)}: ${result_text(line)}\n"

line_doc : Evidence.Line, Bool -> JsonDoc
line_doc = |line, winner| JsonDoc.Obj([
	("rank", Num(line.rank.to_i64_wrap())),
	("source", Text(source_word(line.source))),
	("result", Text(Db.outcome_word(line.result))),
	("modules", Arr(line.modules.map(|m| Text(m)))),
	("winner", Flag(winner)),
])
