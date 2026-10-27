import lib.Probe

# The real outputs of the pinned roc (tests/fixtures/check/make.sh). The stdout and the stderr of each run.
import "../fixtures/check/out/pass.stdout" as pass_out : Str
import "../fixtures/check/out/warn.stderr" as warn_err : Str
import "../fixtures/check/out/syntax.stderr" as syntax_err : Str
import "../fixtures/check/out/not-found.stderr" as not_found_err : Str
import "../fixtures/check/out/dup.stderr" as dup_err : Str
import "../fixtures/check/out/dup-shifted.stderr" as dup_shifted_err : Str
import "../fixtures/check/out/app-errors.stderr" as app_errors_err : Str
import "../fixtures/check/out/app-errors-shifted.stderr" as app_shifted_err : Str
import "../fixtures/check/out/pkg-base.stderr" as pkg_base_err : Str
import "../fixtures/check/out/pkg-same.stderr" as pkg_same_err : Str
import "../fixtures/check/out/pkg-new.stderr" as pkg_new_err : Str
import "../fixtures/check/out/build-pass.stdout" as build_pass_out : Str
import "../fixtures/check/out/build-errors.stdout" as build_errors_out : Str
import "../fixtures/check/out/build-errors.stderr" as build_errors_err : Str
import "../fixtures/check/out/build-target.stderr" as build_target_err : Str
import "../fixtures/check/out/build-warn.stdout" as build_warn_out : Str
import "../fixtures/check/out/build-warn.stderr" as build_warn_err : Str

ProbeTest :: [].{}

root = "/tmp/talon-check-fixtures"

project = |name| "${root}/project/${name}"

copy_dir = "${root}/home/.cache/roc/talon/tmp/0123456789abcdef"

pkgs = "${root}/home/.cache/roc/packages"

h_parser = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc"

h_json_bad = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"

out = |ended, stdout, stderr| { ended, stdout, stderr }

errs = |text, dir| Probe.errors({ text, dir, pkgs })

# R-SE4 R-P1: a probe is `check` or `build` and nothing else. The compiler arguments of each (R-LD4, R-LD5).
# R-LD8 (slice 077): each build has `--no-cache` after `--output=<output>`, a check has no flag. `Probe.build_args` is the one function that makes the arguments of a build: the options of the caller (`--opt=speed` of a tool build) come before `--output`.
# R-RC1 to R-RC4 R-P2 R-P3: the class of a result. The outputs are the real outputs of the roc on the pinned nightly:
# a check that passes (exit 0), warnings only (exit 2: the exit code is not the class, R-P2), errors (exit 1), a build that works, a build that has
# type errors (the program is still made, and the summary is on stdout), and a target error that has no summary line. A hang, a fault signal, a signal from
# outside, a child that does not start, and an output that says nothing are the other classes.
expect {
	args = [
		(Probe.args({ command: Check, file: "main.roc" }), ["check", "main.roc"]),
		(Probe.args({ command: Build({ output: "/c/tln-probe.out" }), file: "main.roc" }), ["build", "main.roc", "--output=/c/tln-probe.out", "--no-cache"]),
		(Probe.build_args({ file: "main.roc", options: [], output: "/c/o" }), ["build", "main.roc", "--output=/c/o", "--no-cache"]),
		(Probe.build_args({ file: "app.roc", options: ["--opt=speed"], output: "/c/o" }), ["build", "app.roc", "--opt=speed", "--output=/c/o", "--no-cache"]),
	]
	bad_args = args.keep_if(|(got, want)| got != want)
	dbg bad_args

	rows = [
		("check passes", out(Exited(0), pass_out, ""), Pass),
		("warnings only, exit 2", out(Exited(2), "", warn_err), Pass),
		("5 syntax errors", out(Exited(1), "", syntax_err), Fail(5)),
		("1 error and 1 warning", out(Exited(1), "", dup_err), Fail(1)),
		("1 error, singular", out(Exited(1), "", not_found_err), Fail(1)),
		("5 errors in 3 files", out(Exited(1), "", app_errors_err), Fail(5)),
		("build passes", out(Exited(0), build_pass_out, ""), Pass),
		("build with 5 errors, summary on stdout", out(Exited(1), build_errors_out, build_errors_err), Fail(5)),
		("build target error, no summary", out(Exited(1), "", build_target_err), Fail(1)),
		# R-RC1 R-P2 (slice 087): a build with warnings only. roc exits with 2 and writes the program. The summary has 0 errors: a pass.
		("build warnings only, exit 2", out(Exited(2), build_warn_out, build_warn_err), Pass),
		("hang", out(TimedOut, "", ""), Hang),
		("hang with output", out(TimedOut, pass_out, ""), Hang),
		("SIGSEGV", out(Signaled(11), "", ""), Crash("signal 11")),
		("SIGILL", out(Signaled(4), "", ""), Crash("signal 4")),
		("SIGABRT", out(Signaled(6), "", ""), Crash("signal 6")),
		("SIGBUS", out(Signaled(7), "", ""), Crash("signal 7")),
		("SIGFPE", out(Signaled(8), "", ""), Crash("signal 8")),
		("exit 139", out(Exited(139), "", ""), Crash("exit 139")),
		# Q1 (user): only 139 is a crash. Talon starts roc with no shell, so a real fault is a signal. 128 plus n comes from a program or a wrapper: no result.
		("exit 134 (SIGABRT from a wrapper)", out(Exited(134), "", ""), NoFact("no result (exit 134)")),
		("exit 137 (SIGKILL from a shell)", out(Exited(137), "", ""), NoFact("no result (exit 137)")),
		("SIGKILL (the OOM killer)", out(Signaled(9), "", ""), NoFact("signal 9")),
		("SIGTERM", out(Signaled(15), "", ""), NoFact("signal 15")),
		("SIGINT", out(Signaled(2), "", ""), NoFact("signal 2")),
		("SIGHUP", out(Signaled(1), "", ""), NoFact("signal 1")),
		("not started", out(NotStarted("NotFound"), "", ""), NoFact("not started: NotFound")),
		("exit 1 and no report", out(Exited(1), "", "boom"), NoFact("no result (exit 1)")),
		("exit 0 and no text", out(Exited(0), "", ""), NoFact("no result (exit 0)")),
	]
	bad_rows = rows.keep_if(|(_, o, want)| Probe.classify(o) != want).map(|(name, _, want)| (name, want))
	dbg bad_rows
	bad_args == [] and bad_rows == []
}

# R-BL4 R-P2 R-LD4: the error set of a probe. The place is the path in the app, or the hash and the module path of a package file, never the cache path. The same error
# has the same value in the project dir and in the temp copy, where the relative paths of roc are different. The message has no source excerpt and no line or column number.
expect {
	base = errs(pkg_base_err, project("pkg-base"))
	new = errs(pkg_new_err, copy_dir)
	syntax = errs(syntax_err, project("syntax"))
	target = errs(build_target_err, copy_dir)
	titles = |list| list.map(|e| e.title)
	files = |list| list.map(|e| e.file)

	counts = [
		("pass", errs(pass_out, project("pass")), 0),
		("warnings are no errors", errs(warn_err, project("warn")), 0),
		("a warning and an error", errs(dup_err, project("dup")), 1),
		("syntax", syntax, 5),
		("package, in the project dir", base, 1),
		("package, in the copy", errs(pkg_same_err, copy_dir), 1),
		("2 packages", new, 2),
		("app files and a path package", errs(app_errors_err, project("app-errors")), 5),
		("build errors are on stderr", errs(build_errors_err, copy_dir), 5),
	]
	bad_counts = counts.keep_if(|(_, list, n)| list.len() != n).map(|(name, list, n)| (name, list.len(), n))
	dbg bad_counts

	package_message = "This expression is used in an unexpected way.\n\nIt has the type:\n\n    U64\n\nBut the annotation says it should be:\n\n    Str"
	syntax_message = "I was parsing a list expression, and I expected `,` or `]`.\n\nSeparate list elements with commas and close the list with ].\n\nFor example:\n    [1, 2, 3]\n\nI found Stdout here.\nNames that start with uppercase letters are used for tags, type names, and\nmodule names in Roc."
	redeclared = errs(dup_err, project("dup"))
	pins = [
		("package error", base, [{ file: Package({ hash: h_parser, path: "Parser.roc" }), title: "type mismatch", message: package_message }]),
		("syntax: the first error, the excerpt is gone", syntax.take_first(1), [{ file: App("main.roc"), title: "expected list separator", message: syntax_message }]),
		("a position in the message is gone", redeclared, [{ file: App("main.roc"), title: "type redeclared", message: "The type Foo is being redeclared.\n\nBut Foo was already declared in main.roc." }]),
	]
	bad_pins = pins.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_pins

	title_rows = [
		("syntax titles", titles(syntax), ["expected list separator", "expected list separator", "unexpected expression syntax", "expected list separator", "expected closing brace"]),
		("build target: title", titles(target), ["unsupported target"]),
		("a message that has the app path: title", titles(errs(not_found_err, project("not-found"))), ["file not found"]),
	]
	file_rows = [
		("syntax files", files(syntax), [App("main.roc"), App("main.roc"), App("main.roc"), App("main.roc"), App("main.roc")]),
		("2 packages: the order of the output", files(new), [Package({ hash: h_json_bad, path: "Wire.roc" }), Package({ hash: h_parser, path: "Parser.roc" })]),
		("a file in the app and a path package (outside of the app dir: the absolute path)", files(errs(app_errors_err, project("app-errors"))).drop_first(3), [App("Util.roc"), App("${root}/project/lib-local/Local.roc")]),
		("build target: no file", files(target), [NoFile]),
		("not found: no file", files(errs(not_found_err, project("not-found"))), [NoFile]),
	]
	bad_titles = title_rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	bad_files = file_rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	bad_spots = bad_titles.len() + bad_files.len()
	dbg bad_titles
	dbg bad_files

	# The same errors, found in another dir with other relative paths and other line numbers, are equal (R-BL4: no cache path, no line number).
	same = [
		("package: project dir and copy", base, errs(pkg_same_err, copy_dir)),
		("app files: the lines moved by 3, the dir is another", errs(app_errors_err, project("app-errors")), errs(app_shifted_err, copy_dir)),
		("a position in the message moved", redeclared, errs(dup_shifted_err, copy_dir)),
		("a build and a check", errs(app_errors_err, project("app-errors")), errs(build_errors_err, copy_dir)),
	]
	bad_same = same.keep_if(|(_, a, b)| a != b).map(|(name, _, _)| name)
	dbg bad_same
	bad_counts == [] and bad_pins == [] and bad_spots == 0 and bad_same == []
}

# R-BL5 R-BL4 R-BL3 R-P6: `compare` sorts the errors of the candidate into new and unchanged, and the errors of the baseline into removed. The identity is the file, the title and the
# message: the same error on another line is the same error, a changed message or file is another error.
expect {
	base = errs(pkg_base_err, project("pkg-base"))
	new = errs(pkg_new_err, copy_dir)
	apps = errs(app_errors_err, project("app-errors"))
	# The real output has 5 errors, and 2 of them have the same file, title and message (a value that is not used, in 2 lines of main.roc). By R-BL4 they are one error (question Q2).
	distinct = apps.fold([], |kept, e| if kept.contains(e) kept else kept.append(e))
	redeclared = errs(dup_err, project("dup"))
	first = apps.first() ?? { file: NoFile, title: "", message: "" }
	other_message = { ..first, message: "another text" }
	other_file = { ..first, file: App("Other.roc") }
	rows = [
		(
			"the candidate adds an error",
			Probe.compare({ baseline: base, candidate: new }),
			{ new: new.take_first(1), unchanged: base, removed: [] },
		),
		(
			"the candidate removes an error",
			Probe.compare({ baseline: new, candidate: base }),
			{ new: [], unchanged: base, removed: new.take_first(1) },
		),
		(
			"no baseline errors: each error is new (R-BL3)",
			Probe.compare({ baseline: [], candidate: base }),
			{ new: base, unchanged: [], removed: [] },
		),
		(
			"no candidate errors",
			Probe.compare({ baseline: base, candidate: [] }),
			{ new: [], unchanged: [], removed: base },
		),
		(
			"the lines moved: all unchanged",
			Probe.compare({ baseline: apps, candidate: errs(app_shifted_err, copy_dir) }),
			{ new: [], unchanged: distinct, removed: [] },
		),
		(
			"a line in the message moved",
			Probe.compare({ baseline: redeclared, candidate: errs(dup_shifted_err, copy_dir) }),
			{ new: [], unchanged: redeclared, removed: [] },
		),
		(
			"a message that changed is another error",
			Probe.compare({ baseline: [first], candidate: [other_message] }),
			{ new: [other_message], unchanged: [], removed: [first] },
		),
		(
			"a file that changed is another error",
			Probe.compare({ baseline: [first], candidate: [other_file] }),
			{ new: [other_file], unchanged: [], removed: [first] },
		),
		(
			"order: unchanged in the order of the candidate, removed in the order of the baseline",
			Probe.compare({ baseline: distinct.take_first(3), candidate: [distinct.get(2) ?? first, distinct.get(0) ?? first] }),
			{ new: [], unchanged: [distinct.get(2) ?? first, distinct.get(0) ?? first], removed: [distinct.get(1) ?? first] },
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, _, _)| name)
	dbg bad
	bad == []
}

# R-PP6 R-PP7 (slice 031): the slots that a probe takes from the pool. A check takes 1, a build takes 4: a pool of 12 slots runs 12 checks, or 3 builds, or a mix.
expect {
	rows = [
		(Probe.weight(Check), 1),
		(Probe.weight(Build({ output: "/tmp/talon/tln-probe.out" })), 4),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

no_keys = { max: Err(Unset), timeout: Err(Unset), slots: Err(Unset), max_toolchains: Err(Unset) }

# R-P5 R-PP7 R-LY4 R-FL11 (slice 031): the probe settings. The default is `probe.max` 100, `probe.timeout` 30, `probe.slots` 12, `probe.max-toolchains` 10. A layer sets a key by itself: the flag `--slots`, then the `talon.toml` of
# the project, then `config.toml` (`Setting.pick`). A key that a layer does not set comes from the layer below. A value of 0 is a value (`max-toolchains = 0` is the setting that turns the optional downloads off, R-DL6).
expect {
	settings = |flag_slots, from_toml, user| Probe.settings({ flag_slots, project: from_toml, user })
	user_all = { max: Ok(50), timeout: Ok(10), slots: Ok(6), max_toolchains: Ok(0) }
	rows = [
		("the defaults", settings(Err(Unset), no_keys, no_keys), { max: 100, timeout: 30, slots: 12, max_toolchains: 10 }),
		("config.toml sets each key, also 0", settings(Err(Unset), no_keys, user_all), { max: 50, timeout: 10, slots: 6, max_toolchains: 0 }),
		("talon.toml over config.toml, key by key", settings(Err(Unset), { ..no_keys, slots: Ok(3) }, { ..user_all, slots: Ok(8) }), { max: 50, timeout: 10, slots: 3, max_toolchains: 0 }),
		("talon.toml over config.toml for max, timeout and max-toolchains", settings(Err(Unset), { ..no_keys, max: Ok(7), timeout: Ok(2), max_toolchains: Ok(4) }, user_all), { max: 7, timeout: 2, slots: 6, max_toolchains: 4 }),
		("the flag over talon.toml and config.toml", settings(Ok(2), { ..no_keys, slots: Ok(3) }, user_all), { max: 50, timeout: 10, slots: 2, max_toolchains: 0 }),
		("the flag changes the slots only", settings(Ok(2), no_keys, no_keys), { max: 100, timeout: 30, slots: 2, max_toolchains: 10 }),
		("a key of talon.toml with a default below", settings(Err(Unset), { ..no_keys, max: Ok(5), timeout: Ok(1) }, no_keys), { max: 5, timeout: 1, slots: 12, max_toolchains: 10 }),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
