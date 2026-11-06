import lib.Args
import lib.Fail
import lib.JsonDoc
import lib.ProbeSmoke

ProbesmokeTest :: [].{}

# Slice 218b (Resolution R-PB10, R-PB8; CLI R-CM8, R-FL12; Design Q579): the pure part of `tln probe --smoke`. The flow is the L2 cases `probe/sm1` to `sm5`.
# The texts and the `data` members are proposals for the review (R-OUT2, TW24). A fact that the design does not give is a question in the slice file (Q586 to Q593 are answered): a line with 2 faults is not tested.

hash = "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK"

url = "https://github.com/acme/pfx/releases/download/0.1.1/${hash}.tar.zst"

# A platform header with the given target names (the `targets` section as roc reads it).
header_of = |names| {
	entry = |name| "\t\t${name}: { inputs: [\"libhost.a\", app] },\n"
	"platform \"acme\"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n\ttargets: {\n\t\tinputs_dir: \"targets/\",\n${Str.join_with(names.map(entry), "")}\t}\n"
}

# R-PB10 R-CM8 R-FL12 R-FL11 (slice 218b): the operand and the flags of a `probe --smoke` line, and the failures of `read`: kind `usage`, exit 2, one fault in each row.
# A view of a plan: the operand, then `--target` values, then the slots. A failure is its last line on stderr.
expect {
	view = |words| match Args.parse(words) {
		Err(e) => "args: ${Fail.line(e.fail)}"
		Ok(args) => match ProbeSmoke.read(args) {
			Err(fail) => Fail.line(fail)
			Ok(plan) => {
				operand = match plan.operand {
					Alias(text) => "alias ${text}"
					Url(text) => "url ${text}"
				}
				slots = match plan.opts.slots {
					Ok(n) => " slots ${n.to_str()}"
					Err(Unset) => ""
				}
				"${operand} [${Str.join_with(plan.wanted, ",")}]${slots}"
			}
		}
	}
	usage = |text| "tln: error[usage]: ${text}"
	loopback = "http://127.0.0.1:9/acme/pfx/releases/download/0.1.1/${hash}.tar.zst"
	rows = [
		("a release URL", view(["probe", "--smoke", url]), "url ${url} []"),
		("a loopback URL (a test server)", view(["probe", "--smoke", loopback]), "url ${loopback} []"),
		("a header alias", view(["probe", "--smoke", "pf"]), "alias pf []"),
		("a full name is an alias operand", view(["probe", "--smoke", "acme/pfx@0.1"]), "alias acme/pfx@0.1 []"),
		("1 target", view(["probe", "--smoke", "pf", "--target", "x64musl"]), "alias pf [x64musl]"),
		("targets keep the order of the line", view(["probe", "--smoke", url, "--target", "wasm32", "--target", "x64musl", "--target", "arm64musl"]), "url ${url} [wasm32,x64musl,arm64musl]"),
		("the operand before the flag", view(["probe", "--target", "x64musl", "--smoke", "pf"]), "alias pf [x64musl]"),
		("--slots is read as for probe", view(["probe", "--smoke", "pf", "--slots", "2"]), "alias pf [] slots 2"),
		("no operand", view(["probe", "--smoke"]), usage("tln probe --smoke needs a header alias or a release URL")),
		("--range", view(["probe", "--smoke", "pf", "--range"]), usage("tln probe --smoke cannot run with --range")),
		("--share", view(["probe", "--smoke", "pf", "--share"]), usage("tln probe --smoke cannot run with --share")),
		(
			"a bundle file",
			view(["probe", "--smoke", "out/${hash}.tar.zst"]),
			usage("tln probe --smoke needs a header alias or a release URL, not a bundle file: the smoke app names the URL of the platform"),
		),
		("a URL with --file (no project, Q591)", view(["probe", "--smoke", url, "--file", "p1/main.roc"]), usage("flag '--file' does not work with a release URL: it uses no project")),
		("an alias with --file", view(["probe", "--smoke", "pf", "--file", "p1/main.roc"]), "alias pf []"),
		("2 operands", view(["probe", "--smoke", "pf", "json"]), usage("tln probe --smoke takes one platform: a header alias or a release URL")),
		("--target with no --smoke", view(["probe", "json", "--target", "x64musl"]), usage("flag '--target' works only with --smoke")),
		(
			"a URL with no version (R-DI5)",
			view(["probe", "--smoke", "https://github.com/acme/pfx/releases/download/latest/${hash}.tar.zst"]),
			usage("'https://github.com/acme/pfx/releases/download/latest/${hash}.tar.zst' is not a release URL: it needs one version X.Y.Z (R-DI5)"),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	bad.is_empty()
}

# R-FL12: `--smoke` and `--target` belong to `probe`. Another command stops in `Args.parse` (exit 2) with the usage text of the flag, and a `--target` with no value too.
expect {
	line = |words| match Args.parse(words) {
		Err(e) => Fail.line(e.fail)
		Ok(_) => "ok"
	}
	rows = [
		("--smoke on verify", line(["verify", "--smoke"]), "tln: error[usage]: flag '--smoke' is not for 'verify'"),
		("--target on verify", line(["verify", "--target", "x64musl"]), "tln: error[usage]: flag '--target' is not for 'verify'"),
		("--target with no value", line(["probe", "--smoke", "pf", "--target"]), "tln: error[usage]: flag '--target' needs a value"),
		("--smoke on probe", line(["probe", "--smoke", "pf"]), "ok"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	bad.is_empty()
}

# R-PB10 (Registry R-RE20): the targets to build. No `--target`: the targets of the header in source order. Else the names of the line in the order of the line. A name that the header has not, an app and a package: exit 2.
expect {
	view = |x| match ProbeSmoke.pick(x) {
		Ok(names) => "ok ${Str.join_with(names, ",")}"
		Err(fail) => Fail.line(fail)
	}
	four = header_of(["x64musl", "arm64musl", "x64glibc", "wasm32"])
	app_text = "app [main!] { pf: platform \"${url}\" }\n\nmain! = |_args| Ok({})\n"
	package_text = "package [Lib] {}\n"
	no_section = "platform \"acme\"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n"
	no_target = |what| "tln: error[usage]: '${what}' has no target to build: the header of the platform has no targets"
	not_platform = |what| "tln: error[usage]: '${what}' is not a platform: tln probe --smoke builds the smoke app of a platform"
	rows = [
		("no --target: the header, in source order", view({ text: four, given: [], what: url }), "ok x64musl,arm64musl,x64glibc,wasm32"),
		("the header order is not sorted", view({ text: header_of(["wasm32", "arm64mac", "x64musl"]), given: [], what: url }), "ok wasm32,arm64mac,x64musl"),
		("1 target", view({ text: four, given: ["x64glibc"], what: url }), "ok x64glibc"),
		("the order of the line", view({ text: four, given: ["wasm32", "x64musl"], what: url }), "ok wasm32,x64musl"),
		(
			"a target that the platform has not",
			view({ text: four, given: ["x64musl", "riscv"], what: "pf" }),
			"tln: error[usage]: 'riscv' is not a target of 'pf': it has the targets x64musl, arm64musl, x64glibc, wasm32",
		),
		(
			"the first bad name of the line",
			view({ text: four, given: ["x64win", "riscv"], what: "pf" }),
			"tln: error[usage]: 'x64win' is not a target of 'pf': it has the targets x64musl, arm64musl, x64glibc, wasm32",
		),
		("a name of roc that the platform has not", view({ text: header_of(["x64musl"]), given: ["arm64musl"], what: "pf" }), "tln: error[usage]: 'arm64musl' is not a target of 'pf': it has the targets x64musl"),
		("an app", view({ text: app_text, given: [], what: "pf" }), not_platform("pf")),
		("a package, with a target", view({ text: package_text, given: ["x64musl"], what: url }), not_platform(url)),
		("targets: {} (Q587)", view({ text: header_of([]), given: [], what: "pf" }), no_target("pf")),
		("targets: {} with a target of the line (Q587: no target comes first)", view({ text: header_of([]), given: ["x64musl"], what: "pf" }), no_target("pf")),
		("no targets section (Q587)", view({ text: no_section, given: [], what: url }), no_target(url)),
		("a repeated target is one build, at its first place (Q588)", view({ text: four, given: ["wasm32", "x64musl", "wasm32", "x64musl"], what: url }), "ok wasm32,x64musl"),
		("an app with a bad target: not a platform comes first (Q586)", view({ text: app_text, given: ["riscv"], what: "pf" }), not_platform("pf")),
		("a text that is no header", view({ text: "not a header", given: [], what: "pf" }), not_platform("pf")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	bad.is_empty()
}

# R-PB10 R-SM4 R-SM7: the word of a result: the 4 outcomes of a row, and `machine-error` for a machine error (R-SM7).
expect {
	ProbeSmoke.word(Row(Pass)) == "pass" and ProbeSmoke.word(Row(Fail)) == "fail" and ProbeSmoke.word(Row(Hang)) == "hang" and ProbeSmoke.word(Row(Crash)) == "crash" and ProbeSmoke.word(Machine) == "machine-error" and ProbeSmoke.word(NoFact) == "no-fact" and ProbeSmoke.word(NoSmokeApp) == "no-smoke-app"
}

# R-PB10 R-J6 (Design Q579): `data.smoke` is a list of `{target, result}` in the order of the list. A machine error has the word `machine-error`, a build with no fact `no-fact` (Q590), a platform with no smoke app `no-smoke-app` (Q598). The keys of an item are `target`, `result`.
expect {
	items = [{ target: "x64musl", result: Row(Pass) }, { target: "arm64musl", result: Machine }, { target: "wasm32", result: Row(Crash) }, { target: "x64glibc", result: NoFact }, { target: "x64mac", result: NoSmokeApp }]
	got = JsonDoc.render(ProbeSmoke.data(items))
	want = "{'smoke':[{'target':'x64musl','result':'pass'},{'target':'arm64musl','result':'machine-error'},{'target':'wasm32','result':'crash'},{'target':'x64glibc','result':'no-fact'},{'target':'x64mac','result':'no-smoke-app'}]}"
	got == want.replace_each("'", "\"") and JsonDoc.render(ProbeSmoke.data([{ target: "x64glibc", result: Row(Fail) }])) == "{\"smoke\":[{\"target\":\"x64glibc\",\"result\":\"fail\"}]}"
}

# R-PB10 R-OUT2 (the text is a proposal): a head line with the label and the compiler, then a line for each target in the order of the list, with a line end after each line.
expect {
	got = ProbeSmoke.text({ label: "the platform acme/pfx 0.1.1", compiler: "nightly-2026-10-14-38a3029", items: [{ target: "x64musl", result: Row(Hang) }, { target: "wasm32", result: Machine }] })
	got == "smoke build of the platform acme/pfx 0.1.1 on nightly-2026-10-14-38a3029:\n  x64musl: hang\n  wasm32: machine-error\n"
}
