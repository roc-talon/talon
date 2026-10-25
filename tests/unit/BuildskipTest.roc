import lib.BuildSkip
import lib.Db

BuildskipTest :: [].{}

nt = "nightly-2026-10-14-38a3029"

other = "nightly-2026-10-09-258ab27"

# A hash of the fixture host: letters and digits only.
pf_hash = "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw"

used = |hash, path| { hash, path }

node = |hash, is_pf| { hash, name: "acme/${hash}", version: "1.0.0", is_platform: is_pf }

linux_x64 = { os: Linux, arch: X64 }

# The key of the tests: the platform pf, the compiler nt, the target x64musl.
key = { hash: pf_hash, nightly: nt, target: "x64musl" }

d1 = "911169ddaaf146aff539f58c26c489af3b892dff0fe283c1c264c65ae5aa59a2"

d2 = "df6641991491da94c25ed37de40d75c14588d9f802ea2aa307e0c643834b03aa"

# A row of `facts`: the key of the tests, with one part changed.
row = |k, outcome, closure| { hash: k.hash, nightly: k.nightly, target: k.target, outcome, modules: [], closure }

# R-BS2 R-ID6 (slice 032): the used-closure digest is the SHA-256 (64 lowercase hex digits) of the sorted, unique hashes of the used packages, each followed by a line end. The vectors come from `sha256sum`:
# "a\nb\n" is d1, the empty text is the SHA-256 of no bytes. The order of the modules, the module paths and the number of used modules of one package do not change it. A package that is not in the list is not in the digest.
expect {
	row_of = |label, got, want| (label, got, want)
	rows = [
		row_of("2 packages: sha256 of a, b with line ends", BuildSkip.digest([used("a", "A.roc"), used("b", "B.roc")]), d1),
		row_of("the order of the list does not matter", BuildSkip.digest([used("b", "B.roc"), used("a", "A.roc")]), d1),
		row_of("2 modules of one package are one hash", BuildSkip.digest([used("a", "A.roc"), used("b", "B.roc"), used("a", "Other.roc"), used("b", "B.roc")]), d1),
		row_of("the module path does not matter", BuildSkip.digest([used("a", "x/Deep.roc"), used("b", "main.roc")]), d1),
		row_of("a package that is not used is not in the digest", BuildSkip.digest([used("a", "A.roc")]), "87428fc522803d31065e7bce3cf03fe475096631e5e07bbd7a0fde60c4cf25c7"),
		row_of("the byte order: a capital letter comes first", BuildSkip.digest([used("b", "B.roc"), used("A", "A.roc")]), "7fb70b2c8e53af12ab5a1631e86294849c1b682d9cac55e8ca78b22da8dfb3fb"),
		row_of("a real pair of hashes", BuildSkip.digest([used("9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK", "Stdout.roc"), used("7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21", "Json.roc")]), d2),
		row_of("no used package: the SHA-256 of no bytes", BuildSkip.digest([]), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-ID6 R-P4 R-LD5 R-HF10 (slice 032): the key of a build fact is (platform hash, compiler, host target). The target names are the 5 Roc targets that Talon ships. Any other system has no key. The platform is the node with `is_platform`:
# a closure with no such node (the platform is a path entry or a foreign URL: no hash) has no key, and so has an empty closure (`roc use` passes none).
expect {
	system = |os, arch| { os, arch }
	row_of = |label, got, want| (label, Str.inspect(got), Str.inspect(want))
	nodes = [node("a", Bool.False), node(pf_hash, Bool.True), node("b", Bool.False)]
	rows = [
		row_of("linux x64", BuildSkip.target(system(Linux, X64)), Ok("x64musl")),
		row_of("linux arm64", BuildSkip.target(system(Linux, Arm64)), Ok("arm64musl")),
		row_of("macos x64", BuildSkip.target(system(Macos, X64)), Ok("x64mac")),
		row_of("macos arm64", BuildSkip.target(system(Macos, Arm64)), Ok("arm64mac")),
		row_of("windows x64", BuildSkip.target(system(Windows, X64)), Ok("x64win")),
		row_of("windows arm64 has no target (R-HF10)", BuildSkip.target(system(Windows, Arm64)), Err(Unknown)),
		row_of("another os", BuildSkip.target(system(Other("freebsd"), X64)), Err(Unknown)),
		row_of("another arch", BuildSkip.target(system(Linux, Other("riscv64"))), Err(Unknown)),
		row_of("the platform node gives the hash", BuildSkip.pf_hash(nodes), Ok(pf_hash)),
		row_of("a closure with no platform node has no hash", BuildSkip.pf_hash([node("a", Bool.False), node("b", Bool.False)]), Err(NoPlatform)),
		row_of("an empty closure has no hash", BuildSkip.pf_hash([]), Err(NoPlatform)),
		row_of("the key: platform hash, compiler, target", BuildSkip.key({ pf: pf_hash, nightly: nt, system: linux_x64 }), Ok(key)),
		row_of("the key of another compiler", BuildSkip.key({ pf: pf_hash, nightly: other, system: linux_x64 }), Ok({ ..key, nightly: other })),
		row_of("the key of another target", BuildSkip.key({ pf: pf_hash, nightly: nt, system: system(Macos, Arm64) }), Ok({ ..key, target: "arm64mac" })),
		row_of("an unknown system has no key", BuildSkip.key({ pf: pf_hash, nightly: nt, system: system(Windows, Arm64) }), Err(Unknown)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-BS1 R-BS2 (slice 032): the decision of the build skip. The rows of the key with the same digest decide (a key has one row for each digest). `Skip` only when one of them is a `Pass` with a digest (conditions 1 and 2) and none of them is a `Fail`, a `Hang` or a `Crash`.
# Every other case builds: no row, a row of another hash, compiler or target (the key is part of the build id), a pass with another digest, a pass that has no digest, and each outcome that is not a pass.
# A recorded fail never allows a skip (manager review): a fail, a hang or a crash of this digest blocks the skip also when a pass of the same digest is in the list (a row that was made by hand or by a later Talon). A fail of another digest does not block.
expect {
	decide = |facts| BuildSkip.decide({ facts, key, digest: d1 })
	row_of = |label, got, want| (label, Str.inspect(got), Str.inspect(want))
	rows = [
		row_of("a pass with the same digest", decide([row(key, Pass, d1)]), Skip),
		row_of("a pass with the same digest, among other rows", decide([row({ ..key, nightly: other }, Pass, d2), row(key, Pass, d1), row({ ..key, target: "any" }, Pass, "")]), Skip),
		row_of("a pass of this digest and a pass of another digest", decide([row(key, Pass, d2), row(key, Pass, d1)]), Skip),
		row_of("a pass of this digest and a fail of another digest", decide([row(key, Fail, d2), row(key, Pass, d1)]), Skip),
		row_of("a pass of this digest and a crash of another digest", decide([row(key, Crash, d2), row(key, Pass, d1)]), Skip),
		row_of("no row", decide([]), Build),
		row_of("a pass with another digest (a used package changed)", decide([row(key, Pass, d2)]), Build),
		row_of("a pass with no digest", decide([row(key, Pass, "")]), Build),
		row_of("a pass of another platform", decide([row({ ..key, hash: "other" }, Pass, d1)]), Build),
		row_of("a pass of another compiler", decide([row({ ..key, nightly: other }, Pass, d1)]), Build),
		row_of("a pass of another target", decide([row({ ..key, target: "arm64mac" }, Pass, d1)]), Build),
		row_of("a check pass (target any) is no build pass", decide([row({ ..key, target: "any" }, Pass, d1)]), Build),
		row_of("a pass with no digest, and no digest in the candidate either", BuildSkip.decide({ facts: [row(key, Pass, "")], key, digest: "" }), Build),
		row_of("a recorded fail", decide([row(key, Fail, d1)]), Build),
		row_of("a recorded fail with no digest", decide([row(key, Fail, "")]), Build),
		row_of("a recorded hang", decide([row(key, Hang, d1)]), Build),
		row_of("a recorded crash", decide([row(key, Crash, d1)]), Build),
		row_of("a pass and a fail of this digest (the fail blocks)", decide([row(key, Pass, d1), row(key, Fail, d1)]), Build),
		row_of("a fail and a pass of this digest (the order does not matter)", decide([row(key, Fail, d1), row(key, Pass, d1)]), Build),
		row_of("a pass and a hang of this digest", decide([row(key, Pass, d1), row(key, Hang, d1)]), Build),
		row_of("a pass and a crash of this digest", decide([row(key, Pass, d1), row(key, Crash, d1)]), Build),
		row_of("a pass of this digest and a fail of this digest in another compiler", decide([row(key, Pass, d1), row({ ..key, nightly: other }, Fail, d1)]), Skip),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-P4 R-P3 R-BS2 (slice 032): the fact of the result of a build: the key, the outcome of the class, no modules except for a fail, and the digest in `closure` for every outcome. `NoFact` (a download error, a signal from outside) is no row.
# A fail has the modules of the platform hash that the errors name (R-P4: the paths of the errors with a `Package` file of this hash). The text form is what `compat.db` and `expect/facts.tsv` show: the columns hash, compiler, target, outcome, modules, closure.
# `BuildSkip.skipped_line` is the line of the summary that the design gives (R-BS2).
expect {
	pkg_err = |hash, path| { file: Package({ hash, path }), title: "type mismatch", message: "a" }
	app_err = { file: App("main.roc"), title: "type mismatch", message: "a" }
	made = |class, errors| BuildSkip.row({ key, digest: d1, class, errors })
	want = |outcome, modules| Ok({ hash: pf_hash, nightly: nt, target: "x64musl", outcome, modules, closure: d1 })
	rows = [
		("pass", Str.inspect(made(Pass, [])), Str.inspect(want(Pass, []))),
		("fail with a module of the platform", Str.inspect(made(Fail(2), [pkg_err(pf_hash, "Std.roc"), app_err])), Str.inspect(want(Fail, ["Std.roc"]))),
		("fail with no module of the platform", Str.inspect(made(Fail(1), [app_err, pkg_err("other", "A.roc")])), Str.inspect(want(Fail, []))),
		("hang", Str.inspect(made(Hang, [])), Str.inspect(want(Hang, []))),
		("crash", Str.inspect(made(Crash("exit 139"), [])), Str.inspect(want(Crash, []))),
		("a signal from outside is no fact", Str.inspect(made(NoFact("signal 9"), [])), Str.inspect(Err(NoFact))),
		("not started is no fact", Str.inspect(made(NoFact("not started: x"), [])), Str.inspect(Err(NoFact))),
	]
	bad = rows.keep_if(|(_, got, wanted)| got != wanted).map(|(label, got, wanted)| (label, wanted, got))
	dbg bad
	fact = BuildSkip.row({ key, digest: d1, class: Pass, errors: [] })
	text = match fact {
		Ok(found) => Db.fact_line(found)
		Err(_) => "no row"
	}
	bad == [] and BuildSkip.skipped_line == "build: skipped (recorded pass)" and text == "fact\t${pf_hash}\t${nt}\tx64musl\tpass\t\t${d1}"
}

# R-BS1 R-LD5 (slice 032, gap b18): the `build` state of the outcome of a command from the number of app members (the members that have a build) and the number of members that skipped it.
# No app: `NotRun` (a package or a platform has no build). Every app skipped: `Skipped`. Else `Passed`, also when only some of the apps skipped.
expect {
	state = |apps, skipped| Str.inspect(BuildSkip.state({ apps, skipped }))
	rows = [
		("no member", state(0, 0), "NotRun"),
		("no app, a skip count of 1 (never happens)", state(0, 1), "NotRun"),
		("1 app, built", state(1, 0), "Passed"),
		("1 app, skipped", state(1, 1), "Skipped"),
		("2 apps, none skipped", state(2, 0), "Passed"),
		("2 apps, only one skipped", state(2, 1), "Passed"),
		("2 apps, both skipped", state(2, 2), "Skipped"),
		("3 apps, 2 skipped", state(3, 2), "Passed"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
