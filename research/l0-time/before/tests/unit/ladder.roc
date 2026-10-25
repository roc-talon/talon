app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Fail
import lib.Ladder
import lib.Probe

import "../fixtures/check/out/pass.stdout" as pass_out : Str
import "../fixtures/check/out/dup.stderr" as dup_err : Str
import "../fixtures/check/out/app-errors.stderr" as app_errors_err : Str
import "../fixtures/check/out/pkg-base.stderr" as pkg_base_err : Str
import "../fixtures/check/out/pkg-same.stderr" as pkg_same_err : Str
import "../fixtures/check/out/pkg-new.stderr" as pkg_new_err : Str
import "../fixtures/check/out/build-pass.stdout" as build_pass_out : Str
import "../fixtures/check/out/build-errors.stdout" as build_errors_out : Str
import "../fixtures/check/out/build-errors.stderr" as build_errors_err : Str
import "../fixtures/check/out/build-target.stderr" as build_target_err : Str

main! = |_args| Ok({})

root = "/tmp/talon-check-fixtures"

project = |name| "${root}/project/${name}"

copy_dir = "${root}/home/.cache/roc/talon/tmp/0123456789abcdef"

pkgs = "${root}/home/.cache/roc/packages"

id = "nightly-2026-10-14-38a3029"

h_pf = "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw"

h_parser = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc"

h_json_bad = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"

pf = { hash: h_pf, name: "acme/pf", version: "0.1.0", is_platform: Bool.True }

parser = { hash: h_parser, name: "acme/parser", version: "1.0.0", is_platform: Bool.False }

json = { hash: h_json_bad, name: "acme/json", version: "2.1.0", is_platform: Bool.False }

owners = [pf, parser, json]

out = |ended, stdout, stderr| { ended, stdout, stderr }

errs = |text, dir| Probe.errors({ text, dir, pkgs })

fail_view = |r| match r {
	Ok(report) => Ok(report.lines)
	Err(f) => Err((f.kind.code(), f.message))
}

# R-LD1 R-LD4 R-LD5 R-LD6 R-LD7 R-BL1 R-BL2 R-PP3 R-BS1 R-BS2 R-PH9 R-SE4 R-P1 R-CC2: the probes of one member. One round: the baseline in the project dir (the current
# header, R-BL1) and the check in the temp copy (the candidate header, R-BL2), in this order (the results are read in the order of the list). Then one build in the
# copy (R-LD6). The build is always in the plan of an app: P0 has no `compat.db`, so it never skips the build (R-BS1, R-BS2, R-PH9). A package or a platform has no app, so it has no build (R-LD7).
# Each probe is `check` or `build` (R-SE4, R-P1).
# R-PX2 R-PX6 R-CC9 (slice 023c): each probe of the plan has the `program` and the `env` of the facts, the same for each probe (the selected compiler by its path, the cache variables).
# R-PP6 (slice 031): a check has the weight 1 and the build has the weight 4 (the slots that it takes from the pool).
expect {
	copy = "/c/talon/tmp/0123456789abcdef"
	program = "/h/.cache/roc/toolchains/${id}/roc"
	env = [("XDG_CACHE_HOME", "/h/.cache"), ("ROC_CACHE_DIR", "/h/.cache/roc"), ("TALON_IN_PROXY", "1")]
	spec = |dir, args| { compiler: id, program, args, dir, env, timeout: 30, weight: if args.first() == Ok("build") 4 else 1 }
	first = [spec("/p/app", ["check", "main.roc"]), spec(copy, ["check", "main.roc"])]
	for_app = Ladder.plan({ compiler: id, program, env, kind: App, dir: "/p/app", file: "main.roc", copy, timeout: 30 })
	for_package = Ladder.plan({ compiler: id, program, env, kind: Package, dir: "/p/lib", file: "main.roc", copy, timeout: 30 })
	for_platform = Ladder.plan({ compiler: id, program, env, kind: Platform, dir: "/p/pf", file: "main.roc", copy, timeout: 30 })
	slow = Ladder.plan({ compiler: "0.1.0", program: "/usr/bin/roc", env: [], kind: App, dir: "/p/app", file: "app.roc", copy, timeout: 7 })
	first_rows = [
		("app: first round", for_app.first, first),
		("package: first round with its own dir", for_package.first, [spec("/p/lib", ["check", "main.roc"]), spec(copy, ["check", "main.roc"])]),
		("compiler, program, env, file and timeout are the ones of the facts", slow.first, [{ compiler: "0.1.0", program: "/usr/bin/roc", args: ["check", "app.roc"], dir: "/p/app", env: [], timeout: 7, weight: 1 }, { compiler: "0.1.0", program: "/usr/bin/roc", args: ["check", "app.roc"], dir: copy, env: [], timeout: 7, weight: 1 }]),
	]
	build_rows = [
		("app: the build, in the copy, once", for_app.build, Ok(spec(copy, ["build", "main.roc", "--output=${copy}/tln-probe.out"]))),
		("package: no build", for_package.build, Err(None)),
		("platform: no build", for_platform.build, Err(None)),
		("the build has the program and the env of the facts", slow.build, Ok({ compiler: "0.1.0", program: "/usr/bin/roc", args: ["build", "app.roc", "--output=${copy}/tln-probe.out"], dir: copy, env: [], timeout: 7, weight: 4 })),
	]
	bad = first_rows.keep_if(|(_, got, want)| got != want).map(|(name, _, _)| name).concat(build_rows.keep_if(|(_, got, want)| got != want).map(|(name, _, _)| name))
	dbg bad
	only_check_and_build = for_app.first.concat(
		match for_app.build {
			Ok(s) => [s]
			Err(None) => []
		},
	).all(|s| s.args.first() == Ok("check") or s.args.first() == Ok("build"))
	bad == [] and only_check_and_build
}

# R-BL1 R-BL3 R-P7 R-EC1 R-PH10 C6 (slice 007, Q7 of the scope): the baseline. A pass is an empty set, a fail is its errors. A baseline that is not a set of errors (a hang, a crash, no result) stops the command with
# exit code 1 and says to fix the compiler fault or to pass `--no-check`: with no baseline each error would be new, and the blame would be wrong.
expect {
	base = |o| Ladder.baseline({ output: o, dir: project("pkg-base"), pkgs, compiler: id, timeout: 30 })
	view = |r| match r {
		Ok(list) => Ok(list.len())
		Err(f) => Err((f.kind.code(), f.message))
	}
	rows = [
		("pass", view(base(out(Exited(0), pass_out, ""))), Ok(0)),
		("warnings only", view(base(out(Exited(2), "", "── 0 errors and 1 warning ───── main.roc\n"))), Ok(0)),
		("a fail is a set", view(base(out(Exited(1), "", pkg_base_err))), Ok(1)),
		(
			"hang",
			view(base(out(TimedOut, "", ""))),
			Err((1, "the baseline check hangs on ${id} (no result in 30 s). That is a compiler fault. Fix it, or pass --no-check.")),
		),
		(
			"crash",
			view(base(out(Signaled(11), "", ""))),
			Err((1, "the baseline check crashes on ${id} (signal 11). That is a compiler fault. Fix it, or pass --no-check.")),
		),
		(
			"killed from outside",
			view(base(out(Signaled(9), "", ""))),
			Err((1, "the baseline check on ${id} gave no result: signal 9. Run the command again.")),
		),
		(
			"C6: a fail with no error that tln can read (2 errors in the summary, no error report)",
			view(base(out(Exited(1), "", "── 2 errors and 0 warnings ───────── main.roc\n"))),
			Err((1, "the baseline check on ${id} gave no result: 2 errors that tln cannot read. Run the command again.")),
		),
		(
			"C6: one error",
			view(base(out(Exited(1), "", "── 1 error and 0 warnings ───────── main.roc\n"))),
			Err((1, "the baseline check on ${id} gave no result: 1 error that tln cannot read. Run the command again.")),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad
	errors_equal = base(out(Exited(1), "", pkg_base_err)) == Ok(errs(pkg_base_err, project("pkg-base")))
	bad == [] and errors_equal
}

# R-LD4 R-BL5 R-P6 R-P8 R-PH10 R-PH13 C6 R-RC2 R-RC3 R-RC4 R-P3 R-EC10 R-EC11 R-EC1: ladder step 2. The candidate passes when it has no new error, also when the app has errors (R-P6), and the
# unchanged and removed errors are notes. A new error in a file of a hash blames that hash (exit 10, one tuple: R-PH10), and a new error in an app file stops with exit 11 (R-LD4).
# A hang or a crash of the candidate is exit 10 with the changed entries. A signal from outside is no fact (exit 1).
expect {
	check = |o, baseline, dir, own, moved| Ladder.check({ output: o, dir, pkgs, baseline, owners: own, moved, compiler: id, timeout: 30 })
	base = errs(pkg_base_err, project("pkg-base"))
	note = "note: unchanged error: acme/parser 1.0.0 Parser.roc: type mismatch"
	removed = "note: removed error: acme/parser 1.0.0 Parser.roc: type mismatch"
	mixed = out(Exited(1), "", "${dup_err}${pkg_new_err}")
	rows = [
		("no error at all", fail_view(check(out(Exited(0), pass_out, ""), [], copy_dir, owners, [json])), Ok(["check: passed"])),
		("the same error as the baseline", fail_view(check(out(Exited(1), "", pkg_same_err), base, copy_dir, owners, [json])), Ok(["check: passed", note])),
		("the baseline error is gone", fail_view(check(out(Exited(0), pass_out, ""), base, copy_dir, owners, [json])), Ok(["check: passed", removed])),
		(
			"a new error in the files of a hash",
			fail_view(check(out(Exited(1), "", pkg_new_err), base, copy_dir, owners, [json])),
			Err((10, "no tuple works: the whole-app check found new errors in acme/json 2.1.0 (Wire.roc: type mismatch)")),
		),
		(
			"the owner of the hash is not known: the hash",
			fail_view(check(out(Exited(1), "", pkg_new_err), base, copy_dir, [pf, parser], [json])),
			Err((10, "no tuple works: the whole-app check found new errors in ${h_json_bad} (Wire.roc: type mismatch)")),
		),
		(
			"a new error in an app file",
			fail_view(check(out(Exited(1), "", dup_err), [], copy_dir, owners, [json])),
			Err((11, "a new error in an app file: main.roc (type redeclared). The app is not a free variable: fix it, or pass --no-check.")),
		),
		(
			"an app error wins over the blame of a hash",
			fail_view(check(mixed, [], copy_dir, owners, [json])),
			Err((11, "a new error in an app file: main.roc (type redeclared). The app is not a free variable: fix it, or pass --no-check.")),
		),
		(
			"R-P8: an error that the baseline hid in the same module is new (a conservative result)",
			fail_view(check(out(Exited(1), "", pkg_same_err.replace_each("type mismatch", "missing method")), base, copy_dir, owners, [json])),
			Err((10, "no tuple works: the whole-app check found new errors in acme/parser 1.0.0 (Parser.roc: missing method)")),
		),
		(
			"hang",
			fail_view(check(out(TimedOut, "", ""), [], copy_dir, owners, [json, parser])),
			Err((10, "no tuple works: the whole-app check hangs on ${id} (no result in 30 s) with acme/json 2.1.0, acme/parser 1.0.0")),
		),
		(
			"crash",
			fail_view(check(out(Signaled(11), "", ""), [], copy_dir, owners, [json])),
			Err((10, "no tuple works: the whole-app check crashes on ${id} (signal 11) with acme/json 2.1.0")),
		),
		(
			"no fact: killed from outside",
			fail_view(check(out(Signaled(9), "", ""), [], copy_dir, owners, [json])),
			Err((1, "the whole-app check on ${id} gave no result: signal 9. Run the command again.")),
		),
		(
			"C6: a fail with no error that tln can read is no fact, never a pass",
			fail_view(check(out(Exited(1), "", "── 2 errors and 0 warnings ───────── main.roc\n"), base, copy_dir, owners, [json])),
			Err((1, "the whole-app check on ${id} gave no result: 2 errors that tln cannot read. Run the command again.")),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad
	bad == []
}

# R-LD5 R-LD6 R-BL5 C6 R-RC1 R-RC2 R-RC3 R-RC4 R-PH10 R-EC10 R-EC11: ladder step 3. A build that passes is `build: passed`. A build error that has no file (a target that the platform lacks, a link
# error) blames the platform (exit 10). The errors of a build that the baseline has are not blamed. A new error in an app file is exit 11, in the file of a hash it is exit 10.
expect {
	build = |o, baseline, dir, own| Ladder.build({ output: o, dir, pkgs, baseline, owners: own, compiler: id, timeout: 30 })
	app_base = errs(app_errors_err, project("app-errors"))
	platform_text = "on the platform acme/pf 0.1.0"
	target = out(Exited(1), "", build_target_err)
	broken = out(Exited(1), build_errors_out, build_errors_err)
	rows = [
		("pass", fail_view(build(out(Exited(0), build_pass_out, ""), [], copy_dir, owners)), Ok(["build: passed"])),
		(
			"a target that the platform lacks: the platform",
			fail_view(build(target, [], copy_dir, owners)),
			Err((10, "no tuple works: the build for the host target failed on the platform acme/pf 0.1.0: unsupported target")),
		),
		(
			"no platform in the owners",
			fail_view(build(target, [], copy_dir, [parser])),
			Err((10, "no tuple works: the build for the host target failed on the platform: unsupported target")),
		),
		("the errors of the baseline are not blamed", fail_view(build(broken, app_base, copy_dir, owners)), Ok(["build: passed"])),
		(
			"a new error in a hash file",
			fail_view(build(out(Exited(1), "", pkg_new_err), errs(pkg_base_err, project("pkg-base")), copy_dir, owners)),
			Err((10, "no tuple works: the build found new errors in acme/json 2.1.0 (Wire.roc: type mismatch)")),
		),
		(
			"a new error in an app file",
			fail_view(build(out(Exited(1), "", dup_err), [], copy_dir, owners)),
			Err((11, "a new error in an app file: main.roc (type redeclared). The app is not a free variable: fix it, or pass --no-check.")),
		),
		("hang", fail_view(build(out(TimedOut, "", ""), [], copy_dir, owners)), Err((10, "no tuple works: the build hangs on ${id} (no result in 30 s) ${platform_text}"))),
		("crash", fail_view(build(out(Signaled(6), "", ""), [], copy_dir, owners)), Err((10, "no tuple works: the build crashes on ${id} (signal 6) ${platform_text}"))),
		("no fact", fail_view(build(out(Signaled(15), "", ""), [], copy_dir, owners)), Err((1, "the build on ${id} gave no result: signal 15. Run the command again."))),
		(
			"C6: a fail with no error that tln can read is no fact, never a pass",
			fail_view(build(out(Exited(1), "", "── 1 error and 0 warnings ───────── main.roc\n"), [], copy_dir, owners)),
			Err((1, "the build on ${id} gave no result: 1 error that tln cannot read. Run the command again.")),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad
	# The failure of a new app error in a build lists each app error (the message starts with the first two).
	app_new = fail_view(build(broken, [], copy_dir, owners))
	app_ok = match app_new {
		Err((11, text)) => text.starts_with("a new error in an app file: main.roc (type mismatch); main.roc (type mismatch)")
		_ => Bool.False
	}
	bad == [] and app_ok and Fail.new(NoTuple, "x").kind.code() == 10
}
