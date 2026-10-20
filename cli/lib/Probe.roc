import Text

## A probe is one run of `roc check` or `roc build` (Resolution 4, R-LD1, R-P1). This module has the pure part (TESTING.md 2.2, part A): the
## command line of a probe, the class of its result (R-RC1 to R-RC4, R-P2, R-P3), the error set of a failed probe, and the comparison of two
## error sets (R-BL4, R-BL5). `Fx.probes!` runs the probes (the real `Fx` starts the child with a timeout, TW3).
##
## Talon runs `check` and `build` only and never runs the output (R-P1, R-SE4: the type of `Command` has no other case).
##
## What the pinned roc prints (the real outputs are in `tests/fixtures/check/out/`, made by `tests/fixtures/check/make.sh`):
##
## | Case | Exit | stdout | stderr |
## | --- | --- | --- | --- |
## | check, no error | 0 | `No errors found in <n>ms for <file>` | empty |
## | check, warnings only | 2 | empty | the reports, then `── 0 errors and 1 warning ──...── <file>` |
## | check, errors | 1 | empty | the reports, then `── <n> errors and <m> warnings ──...── <file>` |
## | build, no error | 0 | `0 errors and 0 warnings found in <n>ms while successfully building:` and the output path | empty |
## | build, errors (the output is still made) | 1 | `<n> errors and <m> warnings found in <t>ms while successfully building:` and the output path | the reports |
## | build, target or link failure | 1 | empty | one report with no file and no summary line |
##
## A report starts with a header line. `── ✗ <title> ──...── <path>:<line>:<column>` is an error. `── ● <title> ──...` is a warning. The path is
## relative to the working directory of the probe. A header of a report that has no place in a file ends with the dashes (no path).
## The line `── <digit>...` (no `✗`, no `●`) is the summary. Exit code 2 with `0 errors` is a pass: the exit code is not the class.
Probe :: [].{

	## One probe for `Fx.probes!` (TESTING.md 2.3 row 3). `compiler` is the compiler id (a nightly tag or a release): the real `Fx` of P0 runs the
	## `roc` on `PATH` (R-PH6), and `Compiler.require` has checked that this is the id. `args` are the arguments of `roc` (`Probe.args`). `dir` is the
	## working directory. `timeout` is in seconds (R-RC3, R-P5: 30).
	Spec : { compiler : Str, args : List(Str), dir : Str, timeout : U64 }

	## What `Fx.probes!` gives for one probe. `TimedOut`: the child did not end in `timeout` seconds and the real `Fx` killed it. `NotStarted`:
	## the program could not start.
	Output : { ended : [Exited(I32), Signaled(I32), TimedOut, NotStarted(Str)], stdout : Str, stderr : Str }

	## The compiler command of a probe (R-LD1, R-LD4, R-LD5, R-P1). `Build` writes the program to `output` and never runs it.
	Command : [Check, Build({ output : Str })]

	## The arguments of `roc`. `Check` is `["check", file]`. `Build({ output })` is `["build", file, "--output=<output>"]` (R-LD5: the host target is the
	## default, so there is no `--target`). `file` is the file name of the project file, as the working directory sees it.
	args : { command : Command, file : Str } -> List(Str)
	args = |facts| match facts.command {
		Check => ["check", facts.file]
		Build({ output }) => ["build", facts.file, "--output=${output}"]
	}

	## The class of a result (R-RC1 to R-RC4, R-P2, R-P3). `Fail(n)` has the number of errors. `Crash(text)` and `NoFact(text)` have a short text for the
	## message (`signal 11`, `exit 139`, `signal 9`, `not started: <text>`, `no result (exit <n>)`). The rules, first match wins:
	##
	## | # | `ended` and text | Class | Rule |
	## | --- | --- | --- | --- |
	## | 1 | `TimedOut` | `Hang` | R-RC3 |
	## | 2 | `Signaled` 4, 6, 7, 8 or 11 (SIGILL, SIGABRT, SIGBUS, SIGFPE, SIGSEGV) | `Crash("signal <n>")` | R-RC4 |
	## | 3 | `Signaled` with another number (9 SIGKILL, 15 SIGTERM, 2 SIGINT, 1 SIGHUP, ...) | `NoFact("signal <n>")` | R-P3 |
	## | 4 | `NotStarted(text)` | `NoFact("not started: <text>")` | R-P3 |
	## | 5 | `Exited(139)` | `Crash("exit 139")` | R-RC4 (a shell reports a segmentation fault as 139) |
	## | 6 | A summary line in stdout or stderr: `No errors found` (check) | `Pass` | R-RC1 |
	## | 7 | A summary line `<n> error(s) and <m> warning(s)` (check: after `── `, build: `... found in`), `n` is 0 | `Pass`, also with exit code 2 | R-RC1, R-P2 |
	## | 8 | The same with `n` above 0 | `Fail(n)` | R-RC2 |
	## | 9 | No summary line, exit code is not 0, and at least one error header (`── ✗`) | `Fail(<number of error headers>)` | R-RC2 (the target error of a build) |
	## | 10 | Anything else | `NoFact("no result (exit <n>)")` | R-P3 |
	##
	## The exit code of rows 6 to 8 is not used. Only exit 139 is a crash (row 5). Any other exit code with no summary (134 too) is row 10.
	Class : [Pass, Fail(U64), Hang, Crash(Str), NoFact(Str)]

	classify : Output -> Class
	classify = |output| match output.ended {
		TimedOut => Hang
		Signaled(n) => if is_fault(n) Crash("signal ${n.to_str()}") else NoFact("signal ${n.to_str()}")
		NotStarted(text) => NoFact("not started: ${text}")
		Exited(code) => if is_fault_exit(code) Crash("exit ${code.to_str()}") else classify_text(output, code)
	}

	## The place of an error (R-BL4: the path in the app, or the hash and the module path for a package file, never the cache path).
	## The path of the header is resolved against `dir` and the `..` and `.` parts are removed. A path under `pkgs` is `Package`: `hash` is the first
	## segment after `pkgs`, `path` is the rest of the path (`Greet.roc`, `sub/Foo.roc`). A path under `dir` is `App(<path relative to dir>)`. Another
	## absolute path (a path entry that points outside of the app dir) is `App(<absolute path>)`. No path is `NoFile`.
	File : [App(Str), Package({ hash : Str, path : Str }), NoFile]

	## One error of a failed probe (R-BL4). `title` is the title of the header line (`type mismatch`). `message` is the text of the report with the source
	## excerpts, the line numbers and the column numbers removed, in this form:
	##
	## | Step | Rule |
	## | --- | --- |
	## | 1 | The lines between the header and the next header |
	## | 2 | Each source excerpt is removed: a line that has only `^` and spaces (and at least one `^`), and the line before it (the source line, also when it is empty) |
	## | 3 | Each `:<digits>:<digits>` is removed (`main.roc:7:1` is `main.roc`) |
	## | 4 | Each line loses its trailing spaces. A run of empty lines is one empty line. The empty lines at the start and at the end are removed. The lines are joined with `\n`. |
	Err : { file : File, title : Str, message : Str }

	## The errors of the stderr of a probe, in the order of the output (R-BL4). Only the headers with `✗` are errors (R-P2: a warning is not an error).
	## `dir` is the working directory of the probe, `pkgs` is the packages dir (`Roots.pkgs`). The text of a build or a check that passed gives `[]`.
	errors : { text : Str, dir : Str, pkgs : Str } -> List(Err)
	errors = |facts| {
		dir = Text.resolve(facts.dir, facts.dir)
		pkgs = Text.resolve(facts.dir, facts.pkgs)
		sections_of(facts.text.split_on("\n"))
			.keep_if(|s| s.is_error)
			.map(|s| { file: file_of({ path: s.path, dir, pkgs }), title: s.title, message: message_of(s.body) })
	}

	## R-BL5: two errors are the same error when `file`, `title` and `message` are equal (R-BL4). The sets are lists with no repeat (an error that is in a list
	## twice counts once: question Q2). `new` are the errors of `candidate` that `baseline` lacks, `unchanged` are the errors of `candidate` that
	## `baseline` has (both in the order of `candidate`). `removed` are the errors of `baseline` that `candidate` lacks (in the order of `baseline`).
	Compared : { new : List(Err), unchanged : List(Err), removed : List(Err) }

	compare : { baseline : List(Err), candidate : List(Err) } -> Compared
	compare = |facts| {
		candidate = without_repeats(facts.candidate)
		baseline = without_repeats(facts.baseline)
		{
			new: candidate.keep_if(|e| !facts.baseline.contains(e)),
			unchanged: candidate.keep_if(|e| facts.baseline.contains(e)),
			removed: baseline.keep_if(|e| !facts.candidate.contains(e)),
		}
	}
}

# R-RC4: the signals that mean a fault of the compiler: SIGILL, SIGABRT, SIGBUS, SIGFPE, SIGSEGV.
is_fault : I32 -> Bool
is_fault = |n| [4, 6, 7, 8, 11].contains(n)

# R-RC4: a shell reports a segmentation fault as exit 139. No other exit code is a crash.
is_fault_exit : I32 -> Bool
is_fault_exit = |code| code == 139

# Rows 6 to 10 of the table of `classify`.
classify_text : Probe.Output, I32 -> Probe.Class
classify_text = |output, code| {
	lines = output.stdout.split_on("\n").concat(output.stderr.split_on("\n"))
	match lines.keep_oks(summary_of) {
		[n, ..] => if n == 0 Pass else Fail(n)
		[] => {
			headers = lines.keep_if(|l| l.starts_with("── ✗ ")).len()
			if code != 0 and headers > 0 Fail(headers) else NoFact("no result (exit ${code.to_str()})")
		}
	}
}

# The number of errors in a summary line of a check (`No errors found ...`, `── <n> errors and <m> warnings ──`) or of a build (`<n> errors and <m> warnings found in ...`).
summary_of : Str -> Try(U64, [NoSummary])
summary_of = |line| {
	if line.starts_with("No errors found") {
		Ok(0)
	} else if line.starts_with("── ") or line.contains(" found in ") {
		match line.drop_prefix("── ").split_on(" ") {
			[n, e, "and", _, w, ..] if e.starts_with("error") and w.starts_with("warning") => U64.from_str(n).map_err(|_| NoSummary)
			_ => Err(NoSummary)
		}
	} else {
		Err(NoSummary)
	}
}

# One report of the stderr: the header (`── ✗ title ──── path:line:col`) and the lines up to the next header.
Section : { is_error : Bool, title : Str, path : Str, body : List(Str) }

Walk : { done : List(Section), open : Try(Section, [None]) }

no_walk : Walk
no_walk = { done: [], open: Err(None) }

sections_of : List(Str) -> List(Section)
sections_of = |lines| closed(lines.fold(no_walk, walk_step))

closed : Walk -> List(Section)
closed = |walk| match walk.open {
	Ok(section) => walk.done.append(section)
	Err(None) => walk.done
}

walk_step : Walk, Str -> Walk
walk_step = |walk, line| {
	if line.starts_with("── ✗ ") or line.starts_with("── ● ") {
		{ done: closed(walk), open: Ok(header_of(line)) }
	} else if line.starts_with("── ") and summary_of(line) != Err(NoSummary) {
		{ done: closed(walk), open: Err(None) }
	} else {
		match walk.open {
			Ok(section) => { ..walk, open: Ok({ ..section, body: section.body.append(line) }) }
			Err(None) => walk
		}
	}
}

# A header ends with its dashes, and then the path of the place (a report with no place has no path).
header_of : Str -> Section
header_of = |line| {
	rest = line.drop_prefix("── ✗ ").drop_prefix("── ● ")
	{ title, path } = match rest.split_first(" ─") {
		Ok({ before, after }) => { title: before, path: strip_positions(after.split_on("─").last() ?? "").trim() }
		Err(NotFound) => { title: rest.trim(), path: "" }
	}
	{ is_error: line.starts_with("── ✗ "), title, path, body: [] }
}

# R-BL4: the place of an error. `dir` and `pkgs` are absolute and have no `..`.
file_of : { path : Str, dir : Str, pkgs : Str } -> Probe.File
file_of = |facts| {
	if facts.path.is_empty() {
		NoFile
	} else {
		full = Text.resolve(facts.dir, facts.path)
		under_pkgs = "${facts.pkgs}/"
		under_dir = "${facts.dir}/"
		if full.starts_with(under_pkgs) {
			match full.drop_prefix(under_pkgs).split_first("/") {
				Ok({ before, after }) => Package({ hash: before, path: after })
				Err(NotFound) => App(full)
			}
		} else if full.starts_with(under_dir) {
			App(full.drop_prefix(under_dir))
		} else {
			App(full)
		}
	}
}

# R-BL4: the text of a report with no source excerpt (a `^` line and the line before it), no `:<line>:<column>`, no trailing spaces, one empty line at most.
message_of : List(Str) -> Str
message_of = |body| {
	kept = body.map_with_index(|line, i| (line, i)).keep_if(|(line, i)| !is_caret(line) and !is_caret(body.get(i + 1) ?? "")).map(|(line, _)| line)
	lines = kept.map(|line| strip_positions(line).trim_end())
	spaced = lines.fold([], |acc, line| if line.is_empty() and acc.last() == Ok("") acc else acc.append(line))
	no_start = if spaced.first() == Ok("") spaced.drop_first(1) else spaced
	Str.join_with(if no_start.last() == Ok("") no_start.drop_last(1) else no_start, "\n")
}

is_caret : Str -> Bool
is_caret = |line| {
	bytes = line.to_utf8()
	bytes.any(|b| b == 94) and bytes.all(|b| b == 94 or b == 32)
}

# Removes each `:<digits>:<digits>`.
strip_positions : Str -> Str
strip_positions = |text| {
	bytes = text.to_utf8()
	Str.from_utf8_lossy(strip_from(bytes, 0, []))
}

strip_from : List(U8), U64, List(U8) -> List(U8)
strip_from = |bytes, i, kept| match bytes.get(i) {
	Err(_) => kept
	Ok(58) => {
		first = digits_at(bytes, i + 1)
		second = if first > 0 and bytes.get(i + 1 + first) == Ok(58) digits_at(bytes, i + 2 + first) else 0
		if second > 0 {
			strip_from(bytes, i + 2 + first + second, kept)
		} else {
			strip_from(bytes, i + 1, kept.append(58))
		}
	}
	Ok(b) => strip_from(bytes, i + 1, kept.append(b))
}

digits_at : List(U8), U64 -> U64
digits_at = |bytes, start| match bytes.get(start) {
	Ok(b) if b >= 48 and b <= 57 => 1 + digits_at(bytes, start + 1)
	_ => 0
}

without_repeats : List(Probe.Err) -> List(Probe.Err)
without_repeats = |errors| errors.fold([], |kept, e| if kept.contains(e) kept else kept.append(e))
