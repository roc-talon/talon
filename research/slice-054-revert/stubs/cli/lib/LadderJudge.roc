import BuildTarget
import Fail
import Probe

## The pure judgment of the probe ladder (Resolution 4 "Probes", "Baseline check"; Design 7 R-PH9, R-PH10, R-PH13, R-BL5, R-LD4, R-LD5). Split from `Ladder` (slice 031b): each function gets the output of a probe and gives the report or the failure.
## `Ladder.baseline`, `Ladder.check` and `Ladder.build` call these functions. The plans of the probes are in `LadderPlan`, the command code is in `Ladder`.
LadderJudge :: [].{

	## The owner of a hash in the candidate header (the `name` is `owner/repo`, as `Vars` gives it, or the URL form when there is none). `is_platform` marks
	## the platform entry (R-LD5: a build error that no file owns blames the platform).
	Owner : { hash : Str, name : Str, version : Str, is_platform : Bool }

	## The lines that the command prints for a step that passed (R-BL5: an error that both runs have is "unchanged", an error that only the baseline has
	## is "removed", both are notes and are never blamed). Texts are a proposal (TW24). `<where>` is the path for an app file, `<name> <version> <module>`
	## for a package file of a known owner, `<hash> <module>` for another package file, and `no file` for an error that has no file.
	##
	## | Step | Lines |
	## | --- | --- |
	## | check | `check: passed`, then `note: unchanged error: <where>: <title>` for each unchanged error, then `note: removed error: <where>: <title>` for each removed error |
	## | build | `build: passed` |
	Report : { lines : List(Str) }

	## The baseline (R-BL1, R-P7): `output` is the result of the check on the current header, run in `dir`. A pass is `Ok([])`, a fail is `Ok(its errors)`. Each other class
	## stops (a baseline that is not a set of errors gives no baseline, so each error would be new and the blame would be wrong, R-BL3):
	##
	## | Class | Failure | Text |
	## | --- | --- | --- |
	## | `Hang` | kind `Internal` (exit 1, R-EC1, R-P7) | `the baseline check hangs on <compiler> (no result in <timeout> s). That is a compiler fault. Fix it, or pass --no-check.` |
	## | `Crash(text)` | `Internal` | `the baseline check crashes on <compiler> (<text>). That is a compiler fault. Fix it, or pass --no-check.` |
	## | `NoFact(text)` | `Internal` | `the baseline check on <compiler> gave no result: <text>. Run the command again.` |
	## | `Fail(n)` with no error that `Probe.errors` can read (C6: the summary says `n` errors, but the output has no error report) | `Internal` | `the baseline check on <compiler> gave no result: <n> errors that tln cannot read. Run the command again.` (`1 error` for 1). An empty set would blame the wrong hash (R-BL3). |
	baseline : { output : Probe.Output, dir : Str, pkgs : Str, compiler : Str, timeout : U64 } -> Try(List(Probe.Err), Fail)
	baseline = |facts| match Probe.classify(facts.output) {
		Pass => Ok([])
		Fail(n) => match Probe.errors({ text: facts.output.stderr, dir: facts.dir, pkgs: facts.pkgs }) {
			[] => Err(unreadable("the baseline check on ${facts.compiler}", n))
			errors => Ok(errors)
		}
		Hang => Err(Fail.new(Internal, "the baseline check hangs on ${facts.compiler} (no result in ${facts.timeout.to_str()} s). That is a compiler fault. Fix it, or pass --no-check."))
		Crash(text) => Err(Fail.new(Internal, "the baseline check crashes on ${facts.compiler} (${text}). That is a compiler fault. Fix it, or pass --no-check."))
		NoFact(text) => Err(Fail.new(Internal, "the baseline check on ${facts.compiler} gave no result: ${text}. Run the command again."))
	}

	## A failure of kind `NoTuple` is `Fail.of_tuple` (slice 036b, R-AL5, R-AL6): the oracle loop can try another tuple. It names the hashes that it blames: a new error names the hashes of its files, a build error that no file owns names the platform, a hang and a crash name none (the whole tuple, D10).
	##
	## Ladder step 2, the whole-app check of the candidate (R-LD4, R-BL5, R-P6, R-PH10). `baseline` is the result of `Ladder.baseline`. `owners` are the owners of the
	## hashes (the candidate header). `moved` are the entries that the command changes (for a fault). A candidate with no new error passes, also when the app has
	## errors (R-P6). The errors that are new (`Probe.compare`) are blamed:
	##
	## | Case | Failure | Text |
	## | --- | --- | --- |
	## | `Pass`, or `Fail` with no new error | `Ok(Report)` | (the lines of `Report`) |
	## | A new error in an app file (`App(...)`: the app is not a free variable) | kind `AppError` (exit 11, R-EC11). This wins over a blame of a hash. | `a new error in an app file: <path> (<title>); <path> (<title>). The app is not a free variable: fix it, or pass --no-check.` (only the app errors, in order) |
	## | New errors in the files of hashes (and none in app files) | kind `NoTuple` (exit 10, R-PH10, R-PH13) | `no tuple works: the whole-app check found new errors in <blame>; <blame>` |
	## | `Hang` | `NoTuple` | `no tuple works: the whole-app check hangs on <compiler> (no result in <timeout> s) with <moved>` (no ` with <moved>` when `moved` is empty) |
	## | `Crash(text)` | `NoTuple` | `no tuple works: the whole-app check crashes on <compiler> (<text>) with <moved>` (no ` with <moved>` when `moved` is empty) |
	## | `NoFact(text)` | `Internal` (exit 1) | `the whole-app check on <compiler> gave no result: <text>. Run the command again.` |
	## | `Fail(n)` with no readable error (C6) | `Internal` (exit 1) | `the whole-app check on <compiler> gave no result: <n> errors that tln cannot read. Run the command again.` (never a pass) |
	##
	## `<blame>` is `<name> <version> (<module>: <title>, <module>: <title>)` for each hash, in the order of its first new error, with its new errors in order.
	## A hash that is not in `owners` is `<hash>` in place of `<name> <version>`. `<moved>` is `<name> <version>` for each moved owner, joined with `, `.
	## A new error with no file in a check goes to the app (it is not a file of a hash).
	check : { output : Probe.Output, dir : Str, pkgs : Str, baseline : List(Probe.Err), owners : List(Owner), moved : List(Owner), compiler : Str, timeout : U64 } -> Try(Report, Fail)
	check = |facts| match Probe.classify(facts.output) {
		Pass => judge_check(facts.baseline, facts.owners, [])
		Fail(n) => match Probe.errors({ text: facts.output.stderr, dir: facts.dir, pkgs: facts.pkgs }) {
			[] => Err(unreadable("the whole-app check on ${facts.compiler}", n))
			errors => judge_check(facts.baseline, facts.owners, errors)
		}
		Hang => Err(Fail.of_tuple("no tuple works: the whole-app check hangs on ${facts.compiler} (no result in ${facts.timeout.to_str()} s)${moved_text(facts.moved)}", []))
		Crash(text) => Err(Fail.of_tuple("no tuple works: the whole-app check crashes on ${facts.compiler} (${text})${moved_text(facts.moved)}", []))
		NoFact(text) => Err(Fail.new(Internal, "the whole-app check on ${facts.compiler} gave no result: ${text}. Run the command again."))
	}

	## Ladder step 3, the build (R-LD5, R-LD6): `output` is the result of the build in the copy. `baseline` is the error set of the baseline check. The rules, in this order:
	##
	## | Case | Failure | Text |
	## | --- | --- | --- |
	## | `Pass` | `Ok({ lines: ["build: passed"] })` | |
	## | `Fail`: a new error (not in `baseline`) in an app file | `AppError` (exit 11) | as in `check` (the same text) |
	## | `Fail`: an error that has no file (a link error, a target that the platform lacks: R-LD5), and no new error in an app file | kind `NoTuple` (exit 10) | `no tuple works: the build for the host target failed on the platform <name> <version>: <title>; <title>` (the titles of the errors with no file, in order) |
	## | `Fail`: a new error in the file of a hash | `NoTuple` | `no tuple works: the build found new errors in <blame>` (`<blame>` as in `check`) |
	## | `Fail` and no new error and no error with no file (the same errors as the baseline) | `Ok({ lines: ["build: passed"] })` | |
	## | `Hang` | `NoTuple` | `no tuple works: the build hangs on <compiler> (no result in <timeout> s) on the platform <name> <version>` |
	## | `Crash(text)` | `NoTuple` | `no tuple works: the build crashes on <compiler> (<text>) on the platform <name> <version>` |
	## | `NoFact(text)` | `Internal` | `the build on <compiler> gave no result: <text>. Run the command again.` |
	## | `Fail(n)` with no readable error (C6) | `Internal` | `the build on <compiler> gave no result: <n> errors that tln cannot read. Run the command again.` (never a pass) |
	##
	## The rows 2 to 4 are in the order of the rules: a new error in an app file first, then an error with no file, then a new error in the file of a hash. `<name> <version>` of the
	## platform is the owner with `is_platform` (`the platform` alone when `owners` has none).
	build : { output : Probe.Output, dir : Str, pkgs : Str, baseline : List(Probe.Err), owners : List(Owner), compiler : Str, timeout : U64 } -> Try(Report, Fail)
	build = |facts| match Probe.classify(facts.output) {
		Pass => Ok({ lines: ["build: passed"] })
		Fail(n) => match Probe.errors({ text: facts.output.stderr, dir: facts.dir, pkgs: facts.pkgs }) {
			[] => Err(unreadable("the build on ${facts.compiler}", n))
			errors => judge_build(facts.baseline, facts.owners, errors)
		}
		Hang => Err(Fail.of_tuple("no tuple works: the build hangs on ${facts.compiler} (no result in ${facts.timeout.to_str()} s) on ${platform_text(facts.owners)}", []))
		Crash(text) => Err(Fail.of_tuple("no tuple works: the build crashes on ${facts.compiler} (${text}) on ${platform_text(facts.owners)}", []))
		NoFact(text) => Err(Fail.new(Internal, "the build on ${facts.compiler} gave no result: ${text}. Run the command again."))
	}

	## Slice 054 (R-TG1, R-TG2, R-LD5): `build` for a build with a build target. `Unlisted` is `build` (the text says `the host target`). `Named(t)` is `build` with one change: the text of the row "an error that has no file" is
	## `no tuple works: the build for the target <t> failed on the platform <name> <version>: <title>; <title>`. Every other row is as in `build`.
	build_at : { output : Probe.Output, dir : Str, pkgs : Str, baseline : List(Probe.Err), owners : List(Owner), compiler : Str, timeout : U64, target : BuildTarget.Chosen } -> Try(Report, Fail)
	build_at = |facts| match facts.target {
		Unlisted => LadderJudge.build({ output: facts.output, dir: facts.dir, pkgs: facts.pkgs, baseline: facts.baseline, owners: facts.owners, compiler: facts.compiler, timeout: facts.timeout })
		Named(_) => crash "todo: slice 054"
	}
}

# C6: a failed probe whose errors Talon cannot read is no fact. An empty set would blame the wrong hash (R-BL3).
unreadable : Str, U64 -> Fail
unreadable = |what, n| {
	count = if n == 1 "1 error" else "${n.to_str()} errors"
	Fail.new(Internal, "${what} gave no result: ${count} that tln cannot read. Run the command again.")
}

moved_text : List(LadderJudge.Owner) -> Str
moved_text = |owners| if owners.is_empty() "" else " with ${Str.join_with(owners.map(|o| "${o.name} ${o.version}"), ", ")}"

# `the platform <name> <version>`, or `the platform` when no owner is the platform.
platform_text : List(LadderJudge.Owner) -> Str
platform_text = |owners| match owners.find_first(|o| o.is_platform) {
	Ok(o) => "the platform ${o.name} ${o.version}"
	Err(_) => "the platform"
}

# Ladder step 2: the new errors of the candidate against the baseline (R-BL5). An error with no file goes to the app (D9).
judge_check : List(Probe.Err), List(LadderJudge.Owner), List(Probe.Err) -> Try(LadderJudge.Report, Fail)
judge_check = |baseline, owners, errors| {
	compared = Probe.compare({ baseline, candidate: errors })
	in_app = compared.new.keep_if(|e| !is_package(e))
	in_hashes = compared.new.keep_if(is_package)
	if !in_app.is_empty() {
		Err(app_error(in_app))
	} else if !in_hashes.is_empty() {
		Err(Fail.of_tuple("no tuple works: the whole-app check found new errors in ${blames(in_hashes, owners)}", hashes_of(in_hashes)))
	} else {
		Ok({ lines: notes("check: passed", compared, owners) })
	}
}

# Ladder step 3. The order of the rules: an app file, an error with no file (the platform), a hash (D8).
judge_build : List(Probe.Err), List(LadderJudge.Owner), List(Probe.Err) -> Try(LadderJudge.Report, Fail)
judge_build = |baseline, owners, errors| {
	new = Probe.compare({ baseline, candidate: errors }).new
	in_app = new.keep_if(|e| e.file != NoFile and !is_package(e))
	no_file = new.keep_if(|e| e.file == NoFile)
	in_hashes = new.keep_if(is_package)
	if !in_app.is_empty() {
		Err(app_error(in_app))
	} else if !no_file.is_empty() {
		Err(Fail.of_tuple("no tuple works: the build for the host target failed on ${platform_text(owners)}: ${Str.join_with(no_file.map(|e| e.title), "; ")}", platform_hashes(owners)))
	} else if !in_hashes.is_empty() {
		Err(Fail.of_tuple("no tuple works: the build found new errors in ${blames(in_hashes, owners)}", hashes_of(in_hashes)))
	} else {
		Ok({ lines: ["build: passed"] })
	}
}

is_package : Probe.Err -> Bool
is_package = |e| match e.file {
	Package(_) => Bool.True
	_ => Bool.False
}

# R-EC11: a new error in an app file.
app_error : List(Probe.Err) -> Fail
app_error = |errors| {
	items = errors.map(
		|e| match e.file {
			App(path) => "${path} (${e.title})"
			_ => "no file (${e.title})"
		},
	)
	Fail.new(AppError, "a new error in an app file: ${Str.join_with(items, "; ")}. The app is not a free variable: fix it, or pass --no-check.")
}

hash_of : Probe.Err -> Str
hash_of = |e| match e.file {
	Package({ hash, .. }) => hash
	_ => ""
}

# R-AL5, D10 of slice 036b: the hashes that a failure blames, in the order of the first error, no repeat. The oracle loop drops the releases of these hashes.
hashes_of : List(Probe.Err) -> List(Str)
hashes_of = |errors| errors.map(hash_of).fold([], |found, hash| if found.contains(hash) found else found.append(hash))

# An error that no file owns (a target that the platform lacks) blames the platform.
platform_hashes : List(LadderJudge.Owner) -> List(Str)
platform_hashes = |owners| match owners.find_first(|o| o.is_platform) {
	Ok(o) => [o.hash]
	Err(_) => []
}

# `<name> <version>` of the owner of a hash, or the hash.
owner_text : List(LadderJudge.Owner), Str -> Str
owner_text = |owners, hash| match owners.find_first(|o| o.hash == hash) {
	Ok(o) => "${o.name} ${o.version}"
	Err(_) => hash
}

# R-PH13: `<name> <version> (<module>: <title>, ...)` for each hash, in the order of its first error.
blames : List(Probe.Err), List(LadderJudge.Owner) -> Str
blames = |errors, owners| {
	hashes = errors.map(hash_of).fold([], |found, hash| if found.contains(hash) found else found.append(hash))
	one = |hash| {
		items = errors.keep_if(|e| hash_of(e) == hash).map(|e| "${module_of(e)}: ${e.title}")
		"${owner_text(owners, hash)} (${Str.join_with(items, ", ")})"
	}
	Str.join_with(hashes.map(one), "; ")
}

module_of : Probe.Err -> Str
module_of = |e| match e.file {
	Package({ path, .. }) => path
	_ => ""
}

# R-BL5: the passed line, then a note for each unchanged error and for each removed error.
notes : Str, Probe.Compared, List(LadderJudge.Owner) -> List(Str)
notes = |first, compared, owners| {
	line = |kind, e| "note: ${kind} error: ${where_text(e, owners)}: ${e.title}"
	[first].concat(compared.unchanged.map(|e| line("unchanged", e))).concat(compared.removed.map(|e| line("removed", e)))
}

where_text : Probe.Err, List(LadderJudge.Owner) -> Str
where_text = |e, owners| match e.file {
	App(path) => path
	NoFile => "no file"
	Package({ hash, path }) => "${owner_text(owners, hash)} ${path}"
}
