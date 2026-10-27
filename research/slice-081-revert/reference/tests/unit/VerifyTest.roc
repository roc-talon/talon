import lib.Ladder
import lib.Probe

VerifyTest :: [].{}

id = "nightly-2026-10-14-38a3029"

old_json = "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst"

new_json = "https://github.com/acme/json/releases/download/2.1.0/4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq.tar.zst"

old_pf = "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst"

new_pf = "https://github.com/acme/pf/releases/download/0.1.1/GqCT1gibKhSDVNtziTGJcyq93kHA8SmamjrYH6si2ZQG.tar.zst"

# R-LD8 (slice 077): a build of `tln verify` has `--no-cache` before the `--replace-dep` pairs.
# R-CM11 R-LB2 R-P1 R-SE4: the command line of a probe of `tln verify`. `--replace-dep <old> <new>` for each replacement, in order, after the file. No replacement gives the arguments of `Probe.args`.
expect {
	json = { old: old_json, new: new_json }
	pf = { old: old_pf, new: new_pf }
	rows = [
		(Probe.replace_args({ command: Check, file: "main.roc", replace: [] }), ["check", "main.roc"]),
		(Probe.replace_args({ command: Check, file: "main.roc", replace: [json] }), ["check", "main.roc", "--replace-dep", old_json, new_json]),
		(Probe.replace_args({ command: Check, file: "app.roc", replace: [json, pf] }), ["check", "app.roc", "--replace-dep", old_json, new_json, "--replace-dep", old_pf, new_pf]),
		(Probe.replace_args({ command: Build({ output: "/t/o" }), file: "main.roc", replace: [pf] }), ["build", "main.roc", "--output=/t/o", "--no-cache", "--replace-dep", old_pf, new_pf]),
		(Probe.replace_args({ command: Build({ output: "/t/o" }), file: "main.roc", replace: [] }), Probe.args({ command: Build({ output: "/t/o" }), file: "main.roc" })),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, _)| got)
	dbg bad
	bad == []
}

# R-CM11 R-LB2 R-LD1 R-LD6 R-LD7 R-BL1 R-PP3 R-SE4 R-P1 R-BS1: the probes of one member for `tln verify`. No copy: the baseline and the candidate check run in the project dir (one round, in this order), and the candidate has the
# replacements. The build (an app only) is one probe in the project dir with the replacements, and its output goes to the temp dir. A package or a platform has no build.
expect {
	tmp = "/c/talon/tmp/0123456789abcdef"
	program = "/h/.cache/roc/toolchains/${id}/roc"
	env = [("XDG_CACHE_HOME", "/h/.cache"), ("ROC_CACHE_DIR", "/h/.cache/roc"), ("TALON_IN_PROXY", "1")]
	spec = |dir, args| { compiler: id, program, args, dir, env, timeout: 30, weight: if args.first() == Ok("build") 4 else 1 }
	json = { old: old_json, new: new_json }
	pf = { old: old_pf, new: new_pf }
	plan = |kind, replace| Ladder.plan_replace({ compiler: id, program, env, kind, dir: "/p/app", file: "main.roc", tmp, replace, timeout: 30 })
	for_app = plan(App, [json, pf])
	app_first = [
		spec("/p/app", ["check", "main.roc"]),
		spec("/p/app", ["check", "main.roc", "--replace-dep", old_json, new_json, "--replace-dep", old_pf, new_pf]),
	]
	app_build = Ok(spec("/p/app", ["build", "main.roc", "--output=${tmp}/tln-probe.out", "--no-cache", "--replace-dep", old_json, new_json, "--replace-dep", old_pf, new_pf]))
	nothing = plan(App, [])
	first_rows = [
		("app: first round", for_app.first, app_first),
		("package: first round", plan(Package, [json]).first, [spec("/p/app", ["check", "main.roc"]), spec("/p/app", ["check", "main.roc", "--replace-dep", old_json, new_json])]),
		("no replacement (Q4): the candidate has no flag", nothing.first, [spec("/p/app", ["check", "main.roc"]), spec("/p/app", ["check", "main.roc"])]),
	]
	build_rows = [
		("app: the build in the project dir", for_app.build, app_build),
		("package: no build", plan(Package, [json]).build, Err(None)),
		("platform: no build", plan(Platform, [json]).build, Err(None)),
		("no replacement: the build", nothing.build, Ok(spec("/p/app", ["build", "main.roc", "--output=${tmp}/tln-probe.out", "--no-cache"]))),
	]
	bad = first_rows.keep_if(|(_, got, want)| got != want).map(|(name, _, _)| name).concat(build_rows.keep_if(|(_, got, want)| got != want).map(|(name, _, _)| name))
	dbg bad
	slow = Ladder.plan_replace({ compiler: "0.1.0", program: "/usr/bin/roc", env: [], kind: App, dir: "/q", file: "x.roc", tmp, replace: [json], timeout: 7 })
	only_check_and_build = for_app.first.concat([for_app.build.ok_or(spec("/", []))]).all(|s| s.args.first() == Ok("check") or s.args.first() == Ok("build"))
	slow_spec = |args| { compiler: "0.1.0", program: "/usr/bin/roc", args, dir: "/q", env: [], timeout: 7, weight: if args.first() == Ok("build") 4 else 1 }
	slow.first == [slow_spec(["check", "x.roc"]), slow_spec(["check", "x.roc", "--replace-dep", old_json, new_json])] and slow.build == Ok(slow_spec(["build", "x.roc", "--output=${tmp}/tln-probe.out", "--no-cache", "--replace-dep", old_json, new_json])) and bad == [] and only_check_and_build
}
