import lib.BuildSkip
import lib.BuildTarget
import lib.Ladder
import lib.LadderPlan

import "../fixtures/check/out/build-pass.stdout" as build_pass_out : Str
import "../fixtures/check/out/build-target.stderr" as build_target_err : Str
import "../fixtures/check/out/dup.stderr" as dup_err : Str

BuildtargetTest :: [].{}

# The pure decisions of the build target (slice 054, Resolution 4 "Build target": R-TG1 to R-TG3, R-TG5, Resolution 2: R-C10).
# `Err(NoSection)` is a platform with no `targets` list that Talon can read: question Q1 of the slice file. Its rows are the status quo (no `--target`), which the old tests of the ladder fix. They are not new decisions.

lines = |parts| Str.join_with(parts, "\n")

view = |r| match r {
	Ok(chosen) => Ok(chosen)
	Err(f) => Err((f.kind.code().to_str(), f.message))
}

# A real header of a platform with 5 targets (basic-cli, nightly format): a doc comment before the keyword, a doc comment inside `requires`, `hosted` with strings, `inputs_dir`, one record for each target.
cli_header = lines([
	"## A native command-line platform.",
	"platform \"\"",
	"\trequires {",
	"\t\t## The entry point.",
	"\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])",
	"\t}",
	"\texposes [Cmd, Env, Stdout]",
	"\tpackages {",
	"\t\t# The shared types.",
	"\t\thttp: \"https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst\",",
	"\t}",
	"\tprovides { \"roc_main\": main_for_host! }",
	"\thosted {",
	"\t\t\"hosted_child_close\": Host.child_close!,",
	"\t}",
	"\ttargets: {",
	"\t\tinputs_dir: \"targets/\",",
	"\t\tx64mac: { inputs: [\"libhost.a\", app] },",
	"\t\tarm64mac: { inputs: [\"libhost.a\", app] },",
	"\t\tx64win: { inputs: [\"host.lib\", \"kernel32.lib\", app] },",
	"\t\tx64musl: { inputs: [\"crt1.o\", \"libhost.a\", \"libunwind.a\", app, \"libc.a\"] },",
	"\t\tarm64musl: { inputs: [\"crt1.o\", \"libhost.a\", \"libunwind.a\", app, \"libc.a\"] },",
	"\t}",
	"",
	"import Cmd",
])

# The head of the platform `cloudflare-workers`: one target, a long `exports` list, a comment with `}` and `targets: {` in it, and strings with `:` and `}`.
worker_header = lines([
	"platform \"\"",
	"\trequires {",
	"\t\tevent! : Worker.Event => Worker.Outcome",
	"\t}",
	"\texposes [Ai, Worker]",
	"\tpackages {",
	"\t\tcbor: \"https://github.com/Karakatiza666/roc-cbor/releases/download/0.2.1/9jD8bxEKhNu6CzBKej1nA1hzymTedJsfhiGgiMPGA1mu.tar.zst\",",
	"\t}",
	"\tprovides { \"roc_event\": event_for_host! }",
	"\thosted { \"roc_await\": Js.host_await!, \"targets: { x64mac\": Js.host_call! }",
	"\ttargets: {",
	"\t\tinputs_dir: \"targets/\",",
	"\t\twasm32: {",
	"\t\t\tinputs: [\"host.wasm\", app],",
	"\t\t\toutput: Shared,",
	"\t\t\t# A comment with a brace } and the words targets: { x64musl: {} } in it.",
	"\t\t\tinitial_stack_size: 1048576,",
	"\t\t\texports: [\"init\", \"handle\", \"a:b\", \"c}d\", \"x64glibc\"],",
	"\t\t},",
	"\t}",
	"",
	"import Worker",
])

# A header with the given text after `provides`.
plain = |tail| lines(["platform \"acme\"", "\trequires {} { main! : () => {} }", "\texposes [Targets]", "\tpackages {}", "\tprovides [main_for_host!]", tail])

# R-TG1 R-C10 (slice 054): `targets_of` gives the names of the keys of `targets: { ... }`, in source order, except `inputs_dir`. A key of a nested record, a word in a comment or in a string, and the module name `Targets` never count.
# `targets: {}` is an empty list and is not the same as no section. A text with no `targets` section (an app, a package, an old platform, a text that is no header) is `Err(NoSection)`.
expect {
	row_of = |label, got, want| (label, Str.inspect(got), Str.inspect(want))
	rows = [
		row_of("5 targets, in source order, with inputs_dir", BuildTarget.targets_of(cli_header), Ok(["x64mac", "arm64mac", "x64win", "x64musl", "arm64musl"])),
		row_of("one target: nested keys, comments and strings do not count", BuildTarget.targets_of(worker_header), Ok(["wasm32"])),
		row_of("targets: {} is an empty list", BuildTarget.targets_of(plain("\ttargets: {}")), Ok([])),
		row_of("only inputs_dir is an empty list", BuildTarget.targets_of(plain("\ttargets: { inputs_dir: \"t/\" }")), Ok([])),
		row_of("a compact record, no trailing comma", BuildTarget.targets_of(plain("\ttargets: {inputs_dir:\"t/\",x64musl:{inputs:[app]},wasm32:{inputs:[app]}}")), Ok(["x64musl", "wasm32"])),
		row_of("inputs_dir in the middle, a trailing comma, many lines", BuildTarget.targets_of(plain("\ttargets: {\n\t\twasm32: { inputs: [app] },\n\t\tinputs_dir: \"t/\",\n\t\tx64glibc: {\n\t\t\tinputs: [app],\n\t\t},\n\t}")), Ok(["wasm32", "x64glibc"])),
		row_of("a comment before the section has the words", BuildTarget.targets_of(plain("\t# targets: { x64mac: {} }\n\ttargets: { arm64linux: { inputs: [app] } }")), Ok(["arm64linux"])),
		row_of("no section (an old platform)", BuildTarget.targets_of(plain("")), Err(NoSection)),
		row_of("an app header", BuildTarget.targets_of("app [main!] { pf: platform \"https://x/y/1.0.0/abc.tar.zst\" }\n\ntargets: { x64mac: {} }\n"), Err(NoSection)),
		row_of("a package header", BuildTarget.targets_of("package [Lib] {}\n"), Err(NoSection)),
		row_of("text that is no header", BuildTarget.targets_of("main! = |_| Ok({})\n"), Err(NoSection)),
		row_of("the empty text", BuildTarget.targets_of(""), Err(NoSection)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-TG3 R-IK7 (slice 054): `[build] target` is one of the 35 Roc targets, byte for byte. The code 0 of Registry R-IK7 (`any`) is no Roc target, and `arm64v1mac` does not exist (every Apple Silicon Mac is above the baseline).
expect {
	valid = ["x64musl", "x64glibc", "x64mac", "x64win", "x64linux", "x64v1elf", "arm64mac", "arm64v1glibc", "arm32musl", "wasm32", "wasm32v1"]
	invalid = ["", "any", "X64MUSL", "x64Musl", " x64musl", "x64musl ", "x64musl\n", "x64 musl", "x64-musl", "arm64v1mac", "wasm64", "x64", "wasm", "native", "host", "x64musl2", "x86musl"]
	invalid_names = valid.concat(BuildTarget.names).keep_if(|name| !BuildTarget.is_name(name))
	accepted = invalid.keep_if(|name| BuildTarget.is_name(name))
	dbg (invalid_names, accepted)
	BuildTarget.names.len() == 35 and invalid_names == [] and accepted == []
}

# R-TG1 rule 2 (slice 054): the host targets of a machine, in the order that `roc build` tries them: musl, then glibc (CLI 6.4, R-T8). The first one is `BuildSkip.target`. A system with no target gives none.
expect {
	system = |os, arch| { os, arch }
	row_of = |label, got, want| (label, got, want)
	rows = [
		row_of("linux x64", BuildTarget.host(system(Linux, X64)), ["x64musl", "x64glibc"]),
		row_of("linux arm64", BuildTarget.host(system(Linux, Arm64)), ["arm64musl", "arm64glibc"]),
		row_of("macos x64", BuildTarget.host(system(Macos, X64)), ["x64mac"]),
		row_of("macos arm64", BuildTarget.host(system(Macos, Arm64)), ["arm64mac"]),
		row_of("windows x64", BuildTarget.host(system(Windows, X64)), ["x64win"]),
		row_of("windows arm64", BuildTarget.host(system(Windows, Arm64)), []),
		row_of("another os", BuildTarget.host(system(Other("freebsd"), X64)), []),
		row_of("another arch", BuildTarget.host(system(Linux, Other("riscv64"))), []),
	]
	first_is_key = [system(Linux, X64), system(Linux, Arm64), system(Macos, X64), system(Macos, Arm64), system(Windows, X64)].all(|s| (BuildTarget.host(s).first() ?? "none") == (BuildSkip.target(s) ?? "unknown"))
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == [] and first_is_key
}

# R-TG1 R-TG3 R-EC2 (slice 054): the build target of an app project file. Rule 1: `[build] target`, also when the platform does not have it (R-C10 checks that). Rule 2: the first host name that the platform has (musl before glibc, whatever the
# order of the list). Rule 3: the one target. No `targets` list that Talon can read: no target (question Q1). Else exit 2 with the targets of the platform and the key `target` of `[build]` in the message.
expect {
	linux = ["x64musl", "x64glibc"]
	pick = |project, host, found| view(BuildTarget.pick({ project, host, found, file: "/p/app/main.roc" }))
	row_of = |label, got, want| (label, Str.inspect(got), Str.inspect(want))
	none_of = "/p/app/main.roc: no build target: the platform has the targets wasm32, x64mac, and none is the host target (x64musl, x64glibc). Set the target in the [build] table of talon.toml, for example: target = \"wasm32\""
	rows = [
		row_of("rule 1: [build] target wins over the host", pick(Ok("wasm32"), linux, Ok(["x64musl", "wasm32"])), Ok(Named("wasm32"))),
		row_of("rule 1: also when the platform does not have it", pick(Ok("wasm32"), linux, Ok(["x64musl"])), Ok(Named("wasm32"))),
		row_of("rule 1: also with 2 targets and no host (no exit 2)", pick(Ok("x64mac"), linux, Ok(["wasm32", "x64mac"])), Ok(Named("x64mac"))),
		row_of("rule 1: also with no list", pick(Ok("x64musl"), linux, Err(NoSection)), Ok(Named("x64musl"))),
		row_of("rule 2: the host target", pick(Err(Unset), linux, Ok(["wasm32", "x64musl"])), Ok(Named("x64musl"))),
		row_of("rule 2: musl before glibc, not the order of the list", pick(Err(Unset), linux, Ok(["x64glibc", "x64musl"])), Ok(Named("x64musl"))),
		row_of("rule 2: glibc when there is no musl", pick(Err(Unset), linux, Ok(["wasm32", "x64glibc"])), Ok(Named("x64glibc"))),
		row_of("rule 2: a host with one name", pick(Err(Unset), ["x64mac"], Ok(["x64win", "x64mac"])), Ok(Named("x64mac"))),
		row_of("rule 3: the one target", pick(Err(Unset), linux, Ok(["wasm32"])), Ok(Named("wasm32"))),
		row_of("rule 3: the one target, host unknown", pick(Err(Unset), [], Ok(["wasm32"])), Ok(Named("wasm32"))),
		row_of("rule 3 is after rule 2: one target that is the host", pick(Err(Unset), linux, Ok(["x64musl"])), Ok(Named("x64musl"))),
		row_of("no list that Talon can read: no target (Q1)", pick(Err(Unset), linux, Err(NoSection)), Ok(Unlisted)),
		row_of("exit 2: 2 targets, none is the host", pick(Err(Unset), linux, Ok(["wasm32", "x64mac"])), Err(("2", none_of))),
		row_of(
			"exit 2: the host is unknown",
			pick(Err(Unset), [], Ok(["wasm32", "x64mac"])),
			Err(("2", "/p/app/main.roc: no build target: the platform has the targets wasm32, x64mac, and none is the host target (unknown host). Set the target in the [build] table of talon.toml, for example: target = \"wasm32\"")),
		),
		row_of(
			"exit 2: a list with no target",
			pick(Err(Unset), linux, Ok([])),
			Err(("2", "/p/app/main.roc: no build target: the platform has no targets. Set the target in the [build] table of talon.toml.")),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-TG2 R-P4 R-ID6 (slice 054): the key of a build fact has the build target. `Named(t)` has the target `t`, also on a system with no host target. `Unlisted` is the key of slice 032 (the host target of `BuildSkip.key`).
expect {
	system = |os, arch| { os, arch }
	key = |chosen, sys| BuildTarget.key({ pf: "pfhash", nightly: "nt", chosen, system: sys })
	row_of = |label, got, want| (label, Str.inspect(got), Str.inspect(want))
	rows = [
		row_of("a named target", key(Named("wasm32"), system(Linux, X64)), Ok({ hash: "pfhash", nightly: "nt", target: "wasm32" })),
		row_of("a named target on another machine: the same key", key(Named("wasm32"), system(Macos, Arm64)), Ok({ hash: "pfhash", nightly: "nt", target: "wasm32" })),
		row_of("a named target on a system with no host target", key(Named("wasm32"), system(Windows, Arm64)), Ok({ hash: "pfhash", nightly: "nt", target: "wasm32" })),
		row_of("a named target that is the host", key(Named("x64glibc"), system(Linux, X64)), Ok({ hash: "pfhash", nightly: "nt", target: "x64glibc" })),
		row_of("unlisted: the host target", key(Unlisted, system(Linux, X64)), Ok({ hash: "pfhash", nightly: "nt", target: "x64musl" })),
		row_of("unlisted, macos", key(Unlisted, system(Macos, Arm64)), Ok({ hash: "pfhash", nightly: "nt", target: "arm64mac" })),
		row_of("unlisted, unknown system: no key", key(Unlisted, system(Windows, Arm64)), Err(Unknown)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-C10 R-TG1 (slice 054): a platform release admits the `[build] target` of the member when its list has the name. No `[build] target`: always (rules 2 and 3 take the target from the release itself). No list that Talon can read: yes (Q1).
expect {
	admits = |wanted, found| BuildTarget.admits({ wanted, found })
	row_of = |label, got, want| (label, got, want)
	rows = [
		row_of("the list has it", admits(Ok("wasm32"), Ok(["x64musl", "wasm32"])), Bool.True),
		row_of("the list has it, the only name", admits(Ok("wasm32"), Ok(["wasm32"])), Bool.True),
		row_of("the list lacks it", admits(Ok("wasm32"), Ok(["x64musl", "x64glibc"])), Bool.False),
		row_of("an empty list", admits(Ok("wasm32"), Ok([])), Bool.False),
		row_of("a name that is a prefix is not it", admits(Ok("wasm32"), Ok(["wasm32v1"])), Bool.False),
		row_of("no [build] target: any list", admits(Err(Unset), Ok(["x64musl"])), Bool.True),
		row_of("no [build] target: an empty list", admits(Err(Unset), Ok([])), Bool.True),
		row_of("no list that Talon can read", admits(Ok("wasm32"), Err(NoSection)), Bool.True),
		row_of("neither", admits(Err(Unset), Err(NoSection)), Bool.True),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == []
}

pf_a = "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst"

pf_b = "https://github.com/acme/pf/releases/download/0.2.0/GqCT1gibKhSDVNtziTGJcyq93kHA8SmamjrYH6si2ZQG.tar.zst"

json_a = "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst"

# R-C10 R-TG5 R-WS5 (slice 054): what each platform release must have. A platform slot gives a `Want` for each URL (its candidates and its current value) and for each member that names it and has a `[build] target`
# (the empty `files` list: every member). A slot that is no platform, and a member with no `[build] target`, give nothing. The order: the slots, then the URLs, then the members.
expect {
	a = { file: "/w/apps/a/main.roc", target: Ok("wasm32") }
	b = { file: "/w/apps/b/main.roc", target: Ok("x64musl") }
	c = { file: "/w/apps/c/main.roc", target: Err(Unset) }
	slot = |is_platform, urls, files| { is_platform, urls, files }
	view_wants = |wants| wants.map(|w| (Str.drop_prefix(w.url, "https://github.com/acme/"), w.target))
	row_of = |label, got, want| (label, Str.inspect(got), Str.inspect(want))
	rows = [
		row_of("one platform, one member", view_wants(BuildTarget.wanted({ slots: [slot(Bool.True, [pf_a, pf_b], ["/w/apps/a/main.roc"])], members: [a, b, c] })), [("pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst", "wasm32"), ("pf/releases/download/0.2.0/GqCT1gibKhSDVNtziTGJcyq93kHA8SmamjrYH6si2ZQG.tar.zst", "wasm32")]),
		row_of("a package slot gives nothing", BuildTarget.wanted({ slots: [slot(Bool.False, [json_a], ["/w/apps/a/main.roc"])], members: [a, b, c] }), []),
		row_of("a member with no target gives nothing", BuildTarget.wanted({ slots: [slot(Bool.True, [pf_a], ["/w/apps/c/main.roc"])], members: [a, b, c] }), []),
		row_of("the empty files list is every member, in the order of the members", view_wants(BuildTarget.wanted({ slots: [slot(Bool.True, [pf_a], [])], members: [a, b, c] })).map(|(_, t)| t), ["wasm32", "x64musl"]),
		row_of("2 slots: the order of the slots", view_wants(BuildTarget.wanted({ slots: [slot(Bool.True, [pf_b], ["/w/apps/b/main.roc"]), slot(Bool.True, [pf_a], ["/w/apps/a/main.roc"])], members: [a, b, c] })).map(|(_, t)| t), ["x64musl", "wasm32"]),
		row_of("a file that is no member gives nothing", BuildTarget.wanted({ slots: [slot(Bool.True, [pf_a], ["/w/apps/z/main.roc"])], members: [a, b, c] }), []),
		row_of("no members, no slots", BuildTarget.wanted({ slots: [], members: [] }), []),
		# Gap rows (slice 054, code decision C5): the order of `members`, not of `files`; a repeated (url, target) pair once.
		row_of("the order of the members, not of the files", view_wants(BuildTarget.wanted({ slots: [slot(Bool.True, [pf_a], ["/w/apps/b/main.roc", "/w/apps/a/main.roc"])], members: [a, b, c] })).map(|(_, t)| t), ["wasm32", "x64musl"]),
		row_of("2 members with the same target: one pair", view_wants(BuildTarget.wanted({ slots: [slot(Bool.True, [pf_a], [])], members: [a, { file: "/w/apps/e/main.roc", target: Ok("wasm32") }, b] })).map(|(_, t)| t), ["wasm32", "x64musl"]),
		row_of("the same url in 2 slots: one pair", view_wants(BuildTarget.wanted({ slots: [slot(Bool.True, [pf_a], ["/w/apps/a/main.roc"]), slot(Bool.True, [pf_a], ["/w/apps/a/main.roc"])], members: [a, b, c] })).map(|(_, t)| t), ["wasm32"]),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-C10 R-C4 (slice 054): `gate` gives the kind `App` to a platform release that lacks a wanted target. The solver never takes an `App` release for a slot, so it is no candidate. A release that Talon did not read, a list that it cannot read (Q1), a package,
# a platform that has the target and a URL that nobody wants are unchanged. With 2 wants, a release that lacks one is out.
expect {
	fact = |url, kind| { url, release: { kind, pf: Err(None), deps: [] } }
	seen = |url, found| { url, found }
	want = |url, target| { url, target }
	kinds = |facts| facts.map(|f| (Str.drop_prefix(f.url, "https://github.com/acme/"), Str.inspect(f.release.kind)))
	short_a = "pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst"
	short_b = "pf/releases/download/0.2.0/GqCT1gibKhSDVNtziTGJcyq93kHA8SmamjrYH6si2ZQG.tar.zst"
	row_of = |label, got, want_rows| (label, got, want_rows)
	rows = [
		row_of(
			"the release that lacks the target is out, the other stays",
			kinds(BuildTarget.gate({ facts: [fact(pf_a, Platform), fact(pf_b, Platform)], seen: [seen(pf_a, Ok(["wasm32", "x64musl"])), seen(pf_b, Ok(["x64musl"]))], wanted: [want(pf_a, "wasm32"), want(pf_b, "wasm32")] })),
			[(short_a, "Platform"), (short_b, "App")],
		),
		row_of(
			"a release that was not read is unchanged",
			kinds(BuildTarget.gate({ facts: [fact(pf_a, Platform)], seen: [], wanted: [want(pf_a, "wasm32")] })),
			[(short_a, "Platform")],
		),
		row_of(
			"no list that Talon can read: unchanged (Q1)",
			kinds(BuildTarget.gate({ facts: [fact(pf_a, Platform)], seen: [seen(pf_a, Err(NoSection))], wanted: [want(pf_a, "wasm32")] })),
			[(short_a, "Platform")],
		),
		row_of(
			"a URL that nobody wants is unchanged",
			kinds(BuildTarget.gate({ facts: [fact(pf_a, Platform)], seen: [seen(pf_a, Ok(["x64musl"]))], wanted: [] })),
			[(short_a, "Platform")],
		),
		row_of(
			"a package is never changed",
			kinds(BuildTarget.gate({ facts: [fact(json_a, Package)], seen: [seen(json_a, Ok(["x64musl"]))], wanted: [want(json_a, "wasm32")] })),
			[("json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst", "Package")],
		),
		row_of(
			"2 wants: out when one is lacking",
			kinds(BuildTarget.gate({ facts: [fact(pf_a, Platform)], seen: [seen(pf_a, Ok(["wasm32"]))], wanted: [want(pf_a, "wasm32"), want(pf_a, "x64musl")] })),
			[(short_a, "App")],
		),
		row_of(
			"2 wants, both there",
			kinds(BuildTarget.gate({ facts: [fact(pf_a, Platform)], seen: [seen(pf_a, Ok(["wasm32", "x64musl"]))], wanted: [want(pf_a, "wasm32"), want(pf_a, "x64musl")] })),
			[(short_a, "Platform")],
		),
		row_of(
			"the order and the other fields of the facts stay",
			kinds(BuildTarget.gate({ facts: [fact(pf_b, Platform), fact(json_a, Package), fact(pf_a, Platform)], seen: [seen(pf_a, Ok(["x64musl"])), seen(pf_b, Ok(["wasm32"]))], wanted: [want(pf_a, "wasm32"), want(pf_b, "wasm32")] })),
			[(short_b, "Platform"), ("json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst", "Package"), (short_a, "App")],
		),
	]
	bad = rows.keep_if(|(_, got, want_rows)| got != want_rows)
	dbg bad
	bad == []
}

# R-C10 OP10 (slice 054): the failure when no platform release has the build target: kind `NoTuple` (exit 10), with no `again` (the solver has no other tuple). The text is a proposal (TW24).
expect {
	fail = BuildTarget.no_release({ alias: "pf", target: "wasm32" })
	fail.kind.code() == 10 and fail.again.is_err() and fail.message == "no tuple works: pf has no platform release with the build target wasm32 (R-C10). Change [build] target in talon.toml, or use a platform that has it."
}

# R-LD8 (slice 077): `--no-cache` stays after `--output`, also with a target.
# R-TG2 R-LD5 (slice 054): the build probe gets `--target=<t>` after `build` and before the file, the form of R-LD5. The `--replace-dep` pairs of the patches stay at the end (R-PA10), the weight and the other fields do not change.
# `Unlisted` (Q1) gives the spec as it is. The check probes have no target (R-LD2, R-LD4: only the build step is for a target).
expect {
	copy = "/c/talon/tmp/0123456789abcdef"
	plan = Ladder.plan({ compiler: "nt", program: "/p/roc", env: [], kind: App, dir: "/p/app", file: "main.roc", copy, timeout: 30 })
	patched = LadderPlan.with_patches({ plan, base: [], candidate: [{ old: "https://x/old", new: "/p/copy/main.roc" }] })
	spec_of = |p| match p.build {
		Ok(s) => s
		Err(_) => { compiler: "", program: "", args: [], dir: "", env: [], timeout: 0, weight: 0 }
	}
	spec = spec_of(plan)
	with_patch = spec_of(patched)
	named = |s, t| LadderPlan.with_target({ spec: s, target: Named(t) })
	out_arg = "--output=${copy}/tln-probe.out"
	no_cache = "--no-cache"
	rows = [
		("a named target", named(spec, "wasm32").args, ["build", "--target=wasm32", "main.roc", out_arg, no_cache]),
		("another name", named(spec, "x64glibc").args, ["build", "--target=x64glibc", "main.roc", out_arg, no_cache]),
		("the pairs of the patches stay at the end", named(with_patch, "wasm32").args, ["build", "--target=wasm32", "main.roc", out_arg, no_cache, "--replace-dep", "https://x/old", "/p/copy/main.roc"]),
		("unlisted: no flag", LadderPlan.with_target({ spec, target: Unlisted }).args, ["build", "main.roc", out_arg, no_cache]),
	]
	same_fields = { ..named(spec, "wasm32"), args: spec.args } == spec
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == [] and same_fields and named(spec, "wasm32").weight == 4 and plan.first.all(|s| !s.args.any(|a| a.starts_with("--target")))
}

# R-TG2 R-LD5 R-PH10 R-EC10 (slice 054): the text of a build that fails for a named target. A build error that no file owns blames the platform: `the build for the target <t> failed on the platform ...` (the text with no target says `the host target`,
# as before). The other rows are the rows of `Ladder.build`: a pass, a new error in an app file (exit 11), a hang.
expect {
	copy = "/c/talon/tmp/0123456789abcdef"
	pkgs = "/h/.cache/roc/packages"
	owners = [{ hash: "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw", name: "acme/pf", version: "0.1.0", is_platform: Bool.True }]
	out = |ended, stdout, stderr| { ended, stdout, stderr }
	build_at = |o, target, own| match Ladder.build_at({ output: o, dir: copy, pkgs, baseline: [], owners: own, compiler: "nt", timeout: 30, target }) {
		Ok(report) => Ok(report.lines)
		Err(f) => Err((f.kind.code(), f.message))
	}
	target_fail = out(Exited(1), "", build_target_err)
	rows = [
		("a named target: the platform is blamed", build_at(target_fail, Named("wasm32"), owners), Err((10, "no tuple works: the build for the target wasm32 failed on the platform acme/pf 0.1.0: unsupported target"))),
		("another target name in the text", build_at(target_fail, Named("x64glibc"), owners), Err((10, "no tuple works: the build for the target x64glibc failed on the platform acme/pf 0.1.0: unsupported target"))),
		("no platform in the owners", build_at(target_fail, Named("wasm32"), []), Err((10, "no tuple works: the build for the target wasm32 failed on the platform: unsupported target"))),
		("unlisted: the host target, as before", build_at(target_fail, Unlisted, owners), Err((10, "no tuple works: the build for the host target failed on the platform acme/pf 0.1.0: unsupported target"))),
		("pass", build_at(out(Exited(0), build_pass_out, ""), Named("wasm32"), owners), Ok(["build: passed"])),
		("a new error in an app file is exit 11", build_at(out(Exited(1), "", dup_err), Named("wasm32"), owners), Err((11, "a new error in an app file: main.roc (type redeclared). The app is not a free variable: fix it, or pass --no-check."))),
		("hang: no target in the text", build_at(out(TimedOut, "", ""), Named("wasm32"), owners), Err((10, "no tuple works: the build hangs on nt (no result in 30 s) on the platform acme/pf 0.1.0"))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == []
}
