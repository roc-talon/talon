import lib.BuildSkip
import lib.Db
import lib.Mode
import lib.Probe
import lib.Prompt
import lib.ToolCompiler

ToolCompilerTest :: [].{}

# Slice 047 (docs/slices/047-tool-compiler.md): the compiler choice of `tln tool install`. The expected value of each row is the design text (CLI 6.4 R-T12 to R-T21, prompt R-NI8) or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts that the design does not give are the proposals of the slice file (TW24). The `Fx` calls and the files are in the L2 cases `tests/commands/cases/tool/ti3-compiler`, `ti4-nothing` and `ti2-refusals`.

pin = "nightly-2026-10-09-258ab27"

a = "nightly-2026-10-14-38a3029"

b = "nightly-2026-10-12-2664a27"

c = "nightly-2026-10-05-aaaaaaa"

# Real hashes (base58 of 32 bytes): the platform, a dependency, the app bundle.
pf = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

dep = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"

tool_app = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

other_app = "J3fdXfd44AGuuqZMdge6UxcjrCJBwHzF2uiQxbu2ZCnr"

host = "x64musl"

yn : Bool -> Str
yn = |x| if x "y" else "n"

digest : Str
digest = ToolCompiler.digest({ bundle: tool_app, hashes: [pf, dep] })

# R-T17 R-EP4 (P1: no registry, so each release is an epoch of its own): the releases that option 2 tries, newer before older. A local build (`git-`, `link-`, `copy-`) is not a release and is dropped. A release version has no day, so it is older than each
# nightly. Two nightlies of one day are ordered by the tag text (R-NS1). The same set in another order gives the same list.
expect {
	rows = [
		(ToolCompiler.candidates([c, a, b]), [a, b, c]),
		(ToolCompiler.candidates([a, b, c]), [a, b, c]),
		(ToolCompiler.candidates([b, c, a]), [a, b, c]),
		(ToolCompiler.candidates([]), []),
		(ToolCompiler.candidates([b]), [b]),
		(ToolCompiler.candidates(["git-mine", c, "link-dev", "copy-x", a]), [a, c]),
		(ToolCompiler.candidates(["link-dev", "git-mine"]), []),
		(ToolCompiler.candidates(["0.1.0", c, a]), [a, c, "0.1.0"]),
		(ToolCompiler.candidates(["0.1.0", "0.2.0", b]), [b, "0.2.0", "0.1.0"]),
		(ToolCompiler.candidates(["nightly-2026-10-12-aaaaaaa", b, "nightly-2026-10-12-0000000"]), ["nightly-2026-10-12-aaaaaaa", b, "nightly-2026-10-12-0000000"]),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T13 R-T21 R-BS2 (D-E1: the closure of a tool is the hash of its app bundle and the hashes of its header): the digest does not depend on the order or on a repeat, and it changes with the bundle (another version) and with any hash.
# The keys of the evidence query are the build keys of the releases (platform hash, release, target), in the order of the list. A platform with no hash (a path entry) gives no key, so there is no evidence.
expect {
	keys = |pf_try, ids| ToolCompiler.evidence_keys({ pf: pf_try, target: host, ids })
	rows = [
		(yn(ToolCompiler.digest({ bundle: tool_app, hashes: [pf, dep] }) == ToolCompiler.digest({ bundle: tool_app, hashes: [dep, pf] })), "y"),
		(yn(ToolCompiler.digest({ bundle: tool_app, hashes: [pf, dep] }) == ToolCompiler.digest({ bundle: tool_app, hashes: [dep, pf, dep, tool_app] })), "y"),
		(yn(ToolCompiler.digest({ bundle: tool_app, hashes: [pf, dep] }) == ToolCompiler.digest({ bundle: other_app, hashes: [pf, dep] })), "n"),
		(yn(ToolCompiler.digest({ bundle: tool_app, hashes: [pf, dep] }) == ToolCompiler.digest({ bundle: tool_app, hashes: [pf] })), "n"),
		(yn(ToolCompiler.digest({ bundle: tool_app, hashes: [] }) == BuildSkip.digest([{ hash: tool_app, path: "" }])), "y"),
		(Str.inspect(keys(Ok(pf), [a, b])), "[{ hash: \"${pf}\", nightly: \"${a}\", target: \"${host}\" }, { hash: \"${pf}\", nightly: \"${b}\", target: \"${host}\" }]"),
		(Str.inspect(keys(Ok(pf), [])), "[]"),
		(Str.inspect(keys(Err(None), [a, b])), "[]"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

fact : { nightly : Str, target : Str, outcome : Db.Outcome, closure : Str, hash : Str } -> Db.Fact
fact = |f| { hash: f.hash, nightly: f.nightly, target: f.target, outcome: f.outcome, modules: [], closure: f.closure }

pass_of : Str -> Db.Fact
pass_of = |id| fact({ hash: pf, nightly: id, target: host, outcome: Pass, closure: digest })

ids3 : List(Str)
ids3 = [a, b, c]

found : List(Db.Fact) -> Str
found = |facts| match ToolCompiler.evidence({ ids: ids3, pf: Ok(pf), target: host, digest, facts }) {
	Ok(id) => id
	Err(None) => "none"
}

# R-T13 R-T17 R-BS1: the evidence of the installed releases. A release has evidence when `BuildSkip.decide` says `Skip` for its key (platform hash, release, target) and the digest of the closure: a build pass and no fail, hang or crash of that digest.
# The first release of the list wins (newer before older). A check row, a row of another digest, of another release, of another platform hash or of another target is no evidence. A pass with no digest never counts. No platform hash: no evidence.
expect {
	rows = [
		(found([]), "none"),
		(found([pass_of(b)]), b),
		(found([pass_of(c), pass_of(b)]), b),
		(found([pass_of(a), pass_of(b), pass_of(c)]), a),
		(found([fact({ hash: pf, nightly: a, target: host, outcome: Fail, closure: digest }), pass_of(b)]), b),
		(found([fact({ hash: pf, nightly: a, target: host, outcome: Hang, closure: digest }), pass_of(a), pass_of(c)]), c),
		(found([pass_of(b), fact({ hash: pf, nightly: b, target: host, outcome: Crash, closure: digest })]), "none"),
		(found([fact({ hash: pf, nightly: b, target: host, outcome: Pass, closure: "other" })]), "none"),
		(found([fact({ hash: pf, nightly: b, target: host, outcome: Pass, closure: "" })]), "none"),
		(found([fact({ hash: pf, nightly: b, target: "any", outcome: Pass, closure: "" })]), "none"),
		(found([fact({ hash: tool_app, nightly: b, target: "any", outcome: Pass, closure: "" })]), "none"),
		(found([fact({ hash: pf, nightly: b, target: "arm64musl", outcome: Pass, closure: digest })]), "none"),
		(found([fact({ hash: dep, nightly: b, target: host, outcome: Pass, closure: digest })]), "none"),
		(found([pass_of(pin)]), "none"),
		(
			match ToolCompiler.evidence({ ids: ids3, pf: Err(None), target: host, digest, facts: [pass_of(b)] }) {
				Ok(id) => id
				Err(None) => "none"
			},
			"none",
		),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-T21 (what option 2 records is what the next install finds): the rows of `build_row` and `check_row` are the input of `evidence`. A recorded build pass of a release is its evidence. A recorded build fail blocks it, also with a pass for the same digest.
# A recorded check pass is not evidence (the build was not tried).
expect {
	row = |id, class| ToolCompiler.build_row({ pf: Ok(pf), id, target: host, digest, class, errors: [] })
	passed = match row(b, Pass) {
		Ok(r) => [r]
		Err(_) => []
	}
	failed = match row(b, Fail(2)) {
		Ok(r) => [r]
		Err(_) => []
	}
	checked = match ToolCompiler.check_row({ bundle: tool_app, id: b, target: host, class: Pass, errors: [] }) {
		Ok(r) => [r]
		Err(_) => []
	}
	rows = [
		(found(passed), b),
		(found(passed.concat(failed)), "none"),
		(found(failed), "none"),
		(found(checked), "none"),
		(found(passed.concat(checked)), b),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

want_text : { roc : [Auto, Pinned, Installed], auto : [Ask, Yes, No], yes : Bool, mode : Mode, id : Str } -> Str
want_text = |run| match ToolCompiler.decide(run) {
	Download => "download"
	TryInstalled => "try"
	Ask => "ask"
	NeedTty => "tty"
	Stop(fail) => fail.line()
}

# R-T14 R-T15 R-T16 R-NM5 R-NM9 R-DL4 R-DL5 (CLI 6.4: the flags answer R-NI8): what the command does when the pin is not installed and no release has evidence. `--roc installed` is option 2 whatever the mode, `--yes` and `TALON_AUTO_INSTALL`
# (D-E3: a download is not made by option 2, so `TALON_AUTO_INSTALL=no` does not stop it). `--roc pinned`, `--yes` and `TALON_AUTO_INSTALL=yes` are option 1, the default (R-NM9), also with no person. A person is asked when no flag answers.
# With no person and no flag: exit 13 that names the flags. `TALON_AUTO_INSTALL=no` refuses the download, with no prompt, in both modes, unless a flag on the line answers. A pin that is not a nightly tag cannot be downloaded: exit 13 with `tln roc install`.
expect {
	run = |roc, auto, yes, mode| want_text({ roc, auto, yes, mode, id: pin })
	consent = "tln: error[consent]: the compiler ${pin} is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes. (--roc installed tries the installed compilers.)"
	refused = "tln: error[consent]: the compiler ${pin} is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install ${pin}, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."
	release = "tln: error[consent]: the compiler 0.1.0 is not installed. Run: tln roc install 0.1.0."
	rows = [
		(run(Installed, Ask, Bool.False, Interactive), "try"),
		(run(Installed, Ask, Bool.False, NonInteractive), "try"),
		(run(Installed, Ask, Bool.False, NeedsTty), "try"),
		(run(Installed, No, Bool.False, NonInteractive), "try"),
		(run(Installed, Yes, Bool.True, NonInteractive), "try"),
		(run(Pinned, Ask, Bool.False, NonInteractive), "download"),
		(run(Pinned, Ask, Bool.False, Interactive), "download"),
		(run(Pinned, Ask, Bool.False, NeedsTty), "download"),
		(run(Pinned, No, Bool.False, NonInteractive), "download"),
		(run(Auto, Yes, Bool.False, NonInteractive), "download"),
		(run(Auto, Yes, Bool.False, Interactive), "download"),
		(run(Auto, Ask, Bool.True, NonInteractive), "download"),
		(run(Auto, Ask, Bool.True, Interactive), "download"),
		(run(Auto, No, Bool.True, NonInteractive), "download"),
		(run(Auto, Ask, Bool.False, Interactive), "ask"),
		(run(Auto, Ask, Bool.False, NeedsTty), "tty"),
		(run(Auto, Ask, Bool.False, NonInteractive), consent),
		(run(Auto, No, Bool.False, NonInteractive), refused),
		(run(Auto, No, Bool.False, Interactive), refused),
		(run(Auto, No, Bool.False, NeedsTty), refused),
		(want_text({ roc: Auto, auto: Ask, yes: Bool.False, mode: Interactive, id: "0.1.0" }), release),
		(want_text({ roc: Pinned, auto: Ask, yes: Bool.False, mode: NonInteractive, id: "0.1.0" }), release),
		(want_text({ roc: Installed, auto: Ask, yes: Bool.False, mode: Interactive, id: "0.1.0" }), "try"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

prompt_of : { installed : U64, tried : List(ToolCompiler.Tried) } -> Prompt
prompt_of = |facts| ToolCompiler.prompt({ name: "acme/foo", version: "1.4.0", pin, size: 73_000_000, installed: facts.installed, tried: facts.tried })

head : Str
head = "acme/foo 1.4.0 was tested with compiler release ${pin}. It is not installed."

# R-NI8 R-T14 R-T15 R-T20 R-NR2 R-NR6 R-NM9 (CLI 6.4 and CLI 4: the prompt, the default, the answer flags). The question is the text of the design: why it asks, the cost of the download (R-NR2), the options 1 and 3, and option 2 with the number of releases only
# when there are some. After option 2 failed (`tried`) the prompt has the list and no option 2, and keeps the numbers 1 and 3 (D-E4). It is a Required prompt (R-NM5) with its own answer flags (R-NR6), and its default is option 1. `--yes` answers option 1 (R-NM9).
# With no person and no flag it stops (exit 13).
expect {
	t1 = ToolCompiler.tried_of({ id: a, stage: Check, class: Fail(2), errors: [{ file: NoFile, title: "type mismatch", message: "m" }] })
	t2 = ToolCompiler.tried_of({ id: b, stage: Build, class: Fail(1), errors: [] })
	two = |p| Prompt.text(p)
	rows = [
		(prompt_of({ installed: 4, tried: [] }).question, "${head}\n\n  1) Download ${pin} (73.0 MB)    [default]\n  2) Try the 4 installed compiler releases\n  3) Cancel\n\nSelect an option"),
		(prompt_of({ installed: 1, tried: [] }).question, "${head}\n\n  1) Download ${pin} (73.0 MB)    [default]\n  2) Try the 1 installed compiler release\n  3) Cancel\n\nSelect an option"),
		(prompt_of({ installed: 0, tried: [] }).question, "${head}\n\n  1) Download ${pin} (73.0 MB)    [default]\n  3) Cancel\n\nSelect an option"),
		(prompt_of({ installed: 0, tried: [t1, t2] }).question, "${head}\nNo installed compiler release built it:\n  ${a}: check failed: type mismatch\n  ${b}: build failed\n\n  1) Download ${pin} (73.0 MB)    [default]\n  3) Cancel\n\nSelect an option"),
		(two(prompt_of({ installed: 4, tried: [] })), "${head}\n\n  1) Download ${pin} (73.0 MB)    [default]\n  2) Try the 4 installed compiler releases\n  3) Cancel\n\nSelect an option [1-3, default 1] "),
		(Str.inspect(prompt_of({ installed: 4, tried: [] }).kind), "Required([\"--roc pinned\", \"--roc installed\", \"TALON_AUTO_INSTALL=yes\"])"),
		(Str.inspect(prompt_of({ installed: 4, tried: [] }).shape), "Options(3)"),
		(Str.inspect(prompt_of({ installed: 4, tried: [] }).default), "Option(1)"),
		(prompt_of({ installed: 4, tried: [] }).subject, "the compiler ${pin}"),
		((prompt_of({ installed: 4, tried: [] }).answer_line)(Option(1)), "downloading ${pin} (73.0 MB)"),
		((prompt_of({ installed: 4, tried: [] }).answer_line)(Option(2)), "trying 4 installed compiler releases"),
		((prompt_of({ installed: 4, tried: [] }).answer_line)(Option(3)), "cancelled"),
		(Str.inspect(Prompt.decide(prompt_of({ installed: 4, tried: [] }), { mode: NonInteractive, yes: Bool.True, flag: Err(NoFlag) })), "Use(Option(1))"),
		(Str.inspect(Prompt.decide(prompt_of({ installed: 4, tried: [] }), { mode: Interactive, yes: Bool.False, flag: Err(NoFlag) })), "Ask"),
		(
			match Prompt.decide(prompt_of({ installed: 4, tried: [] }), { mode: NonInteractive, yes: Bool.False, flag: Err(NoFlag) }) {
				Stop(fail) => fail.line()
				_ => "no stop"
			},
			"tln: error[consent]: the compiler ${pin} needs consent. Pass --roc pinned or --roc installed or TALON_AUTO_INSTALL=yes or --yes.",
		),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-NI8 R-T20 R-T13 R-NM6 (the texts of the answers): option 2 is offered only with a release to try (D-E4: option 2 is not allowed with `installed` 0, the command asks again). The line of the failed releases has the first error line. The line of a release that is not the pin
# is the design text. The stop with no person after option 2 names each release and the flags (D-E5). The cancel is exit 13 and tells that nothing was done.
expect {
	tried = |stage, class, errors| ToolCompiler.tried_text(ToolCompiler.tried_of({ id: b, stage, class, errors }))
	err = { file: NoFile, title: "type mismatch", message: "m" }
	t1 = ToolCompiler.tried_of({ id: a, stage: Check, class: Fail(2), errors: [err] })
	t2 = ToolCompiler.tried_of({ id: b, stage: Build, class: Hang, errors: [] })
	flags = "The compiler ${pin} is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes."
	rows = [
		(yn(ToolCompiler.allowed({ answer: Option(1), installed: 0 })), "y"),
		(yn(ToolCompiler.allowed({ answer: Option(3), installed: 0 })), "y"),
		(yn(ToolCompiler.allowed({ answer: Option(2), installed: 0 })), "n"),
		(yn(ToolCompiler.allowed({ answer: Option(2), installed: 3 })), "y"),
		(yn(ToolCompiler.allowed({ answer: Option(4), installed: 3 })), "n"),
		(yn(ToolCompiler.allowed({ answer: Yes, installed: 3 })), "n"),
		(ToolCompiler.trying_line(4), "trying 4 installed compiler releases"),
		(ToolCompiler.trying_line(1), "trying 1 installed compiler release"),
		(ToolCompiler.built_line({ id: b, pin }), "built with ${b} (pin: ${pin})"),
		(tried(Check, Fail(2), [err]), "${b}: check failed: type mismatch"),
		(tried(Build, Fail(1), []), "${b}: build failed"),
		(tried(Check, Hang, []), "${b}: check did not end in time"),
		(tried(Build, Crash("signal 11"), []), "${b}: build gave no result: signal 11"),
		(tried(Check, NoFact("not started: x"), []), "${b}: check gave no result: not started: x"),
		(tried(Build, Pass, []), "${b}: build passed"),
		(ToolCompiler.declined(pin).line(), "tln: error[consent]: the compiler ${pin} is not installed. Nothing was downloaded and nothing was built. Run: tln roc install ${pin}, pass --roc pinned, or set TALON_AUTO_INSTALL=yes."),
		(ToolCompiler.all_failed({ name: "acme/foo", version: "1.4.0", pin, tried: [t1, t2] }).line(), "tln: error[consent]: no installed compiler release built acme/foo 1.4.0 (${a}: check failed: type mismatch; ${b}: build did not end in time). ${flags}"),
		(ToolCompiler.all_failed({ name: "acme/foo", version: "1.4.0", pin, tried: [] }).line(), "tln: error[consent]: no compiler release is installed to try for acme/foo 1.4.0. ${flags}"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

pkg_err : Str, Str -> Probe.Err
pkg_err = |hash, path| { file: Package({ hash, path }), title: "type mismatch", message: "a" }

# R-T18 R-T19 R-T21 R-P3 R-P4 R-BS2 (D-E1): the probe of a check and the facts of the tries. The check is `roc check main.roc` in the app dir with `probe.timeout`, weight 1 (R-PP6). The row of a check is the unit row of the app bundle: target `any`, no closure,
# the failing modules of that hash only. The row of a build has the key (platform hash, release, target) and the digest in `closure` for every outcome (`BuildSkip.row`), and the modules of the platform hash. A platform with no hash gives no row. A result that is no fact
# (a download error, a signal from outside) gives no row.
expect {
	spec = ToolCompiler.check_spec({ id: b, program: "/c/roc/toolchains/${b}/roc", env: [("XDG_CACHE_HOME", "/c")], dir: "/c/roc/packages/${tool_app}", timeout: 20 })
	check = |class, errors| ToolCompiler.check_row({ bundle: tool_app, id: b, target: host, class, errors })
	build = |pf_try, class, errors| ToolCompiler.build_row({ pf: pf_try, id: b, target: host, digest, class, errors })
	row = |hash, target, outcome, modules, closure| Ok({ hash, nightly: b, target, outcome, modules, closure })
	rows = [
		(Str.inspect(spec), "{ args: [\"check\", \"main.roc\"], compiler: \"${b}\", dir: \"/c/roc/packages/${tool_app}\", env: [(\"XDG_CACHE_HOME\", \"/c\")], program: \"/c/roc/toolchains/${b}/roc\", timeout: 20, weight: 1 }"),
		(Str.inspect(check(Pass, [])), Str.inspect(row(tool_app, "any", Pass, [], ""))),
		(Str.inspect(check(Fail(2), [pkg_err(tool_app, "Foo.roc"), pkg_err(tool_app, "A/Bar.roc"), pkg_err(dep, "Dep.roc")])), Str.inspect(row(tool_app, "any", Fail, ["A/Bar.roc", "Foo.roc"], ""))),
		(Str.inspect(check(Fail(1), [{ file: App("main.roc"), title: "t", message: "m" }])), Str.inspect(row(tool_app, "any", Fail, [], ""))),
		(Str.inspect(check(Hang, [])), Str.inspect(row(tool_app, "any", Hang, [], ""))),
		(Str.inspect(check(Crash("signal 11"), [])), Str.inspect(row(tool_app, "any", Crash, [], ""))),
		(Str.inspect(check(NoFact("signal 9"), [])), "Err(NoFact)"),
		(Str.inspect(build(Ok(pf), Pass, [])), Str.inspect(row(pf, host, Pass, [], digest))),
		(Str.inspect(build(Ok(pf), Fail(1), [pkg_err(pf, "Host.roc"), pkg_err(tool_app, "Foo.roc")])), Str.inspect(row(pf, host, Fail, ["Host.roc"], digest))),
		(Str.inspect(build(Ok(pf), Hang, [])), Str.inspect(row(pf, host, Hang, [], digest))),
		(Str.inspect(build(Ok(pf), Crash("exit 139"), [])), Str.inspect(row(pf, host, Crash, [], digest))),
		(Str.inspect(build(Ok(pf), NoFact("not started: x"), [])), "Err(NoFact)"),
		(Str.inspect(build(Err(None), Pass, [])), "Err(NoKey)"),
		(Str.inspect(build(Err(None), NoFact("x"), [])), "Err(NoKey)"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
