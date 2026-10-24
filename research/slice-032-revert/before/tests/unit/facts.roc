app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Db
import lib.Facts
import lib.Fail
import lib.Probe

main! = |_args| Ok({})

h1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h2 = "Bz7g9mTqU2oV4tG3a1kKfWm5cD8xNqL6RrPjYsHe2vZu"

nt = "nightly-2026-10-14-38a3029"

host = "linux_x86_64"

sha_a = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

sha_b = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"

pkg_err : Str, Str -> Probe.Err
pkg_err = |hash, path| { file: Package({ hash, path }), title: "type mismatch", message: "a" }

base = { hash: h1, nightly: nt, host, command: Check, class: Pass, errors: [], closure: "" }

# R-P4 R-P3 R-PP4 R-NS12: the row of a probe result. The target of a check is `any`, the target of a build is the host. Only a build pass keeps the closure digest. A hang and a crash are rows of their own outcome.
# `NoFact` (a download error, a signal from outside) is no row. The compiler id of a release is the same column.
expect {
	built = { ..base, command: Build({ output: "/tmp/x" }), closure: "c0ffee" }
	row = |outcome, target, modules, closure| Ok({ hash: h1, nightly: nt, target, outcome, modules, closure })
	rows = [
		(Facts.of_probe(base), row(Pass, "any", [], ""), "check pass"),
		(Facts.of_probe({ ..base, closure: "ignored" }), row(Pass, "any", [], ""), "check pass drops the closure"),
		(Facts.of_probe(built), row(Pass, host, [], "c0ffee"), "build pass"),
		(Facts.of_probe({ ..built, class: Hang }), row(Hang, host, [], ""), "build hang"),
		(Facts.of_probe({ ..base, class: Hang }), row(Hang, "any", [], ""), "check hang"),
		(Facts.of_probe({ ..base, class: Crash("signal 11") }), row(Crash, "any", [], ""), "check crash"),
		(Facts.of_probe({ ..built, class: Crash("exit 139") }), row(Crash, host, [], ""), "build crash"),
		(Facts.of_probe({ ..base, class: NoFact("signal 9") }), Err(NoFact), "signal from outside"),
		(Facts.of_probe({ ..built, class: NoFact("not started: x") }), Err(NoFact), "not started"),
		(Facts.of_probe({ ..base, class: Fail(1), errors: [pkg_err(h1, "Yaml.roc")], nightly: "0.1.0" }), Ok({ hash: h1, nightly: "0.1.0", target: "any", outcome: Fail, modules: ["Yaml.roc"], closure: "" }), "release id"),
		(Facts.of_probe({ ..built, class: Fail(2), errors: [pkg_err(h1, "A.roc")], closure: "c0ffee" }), row(Fail, host, ["A.roc"], ""), "build fail has no closure"),
	]
	bad = rows.keep_if(|(got, want, _)| got != want).map(|(_, _, label)| label)
	dbg bad
	bad == []
}

# R-P4: a fail stores the set of failing modules of this hash. The paths of the errors with a `Package` file of this hash, sorted by byte order, no repeat.
# An error in the app, in another package or with no file is not a module of this hash. A fail with no such error has no module.
expect {
	failing = |errors| Facts.of_probe({ ..base, class: Fail(errors.len()), errors })
	app_err = { file: App("main.roc"), title: "type mismatch", message: "a" }
	no_file = { file: NoFile, title: "link error", message: "a" }
	modules = |errors| match failing(errors) {
		Ok(row) => row.modules
		Err(_) => ["no row"]
	}
	rows = [
		(modules([pkg_err(h1, "Yaml.roc"), pkg_err(h1, "Json.roc")]), ["Json.roc", "Yaml.roc"], "sorted"),
		(modules([pkg_err(h1, "B.roc"), pkg_err(h1, "A.roc"), pkg_err(h1, "B.roc")]), ["A.roc", "B.roc"], "no repeat"),
		(modules([pkg_err(h1, "sub/Foo.roc"), pkg_err(h1, "Sub.roc"), pkg_err(h1, "Zed.roc")]), ["Sub.roc", "Zed.roc", "sub/Foo.roc"], "byte order"),
		(modules([pkg_err(h2, "Other.roc"), pkg_err(h1, "Mine.roc")]), ["Mine.roc"], "another package"),
		(modules([app_err, no_file]), [], "no module of this hash"),
		(modules([app_err, pkg_err(h1, "Mine.roc"), no_file]), ["Mine.roc"], "app and no file"),
		(modules([]), [], "no error"),
	]
	bad = rows.keep_if(|(got, want, _)| got != want).map(|(_, _, label)| label)
	dbg bad
	bad == []
}

# R-EF1 (rank 1): the facts that a query gave, by key. The key has the target, so a check fact and a build fact of one (hash, nightly) are two entries.
expect {
	check = { hash: h1, nightly: nt, target: "any", outcome: Pass, modules: [], closure: "" }
	build = { hash: h1, nightly: nt, target: host, outcome: Pass, modules: [], closure: "c0ffee" }
	other = { hash: h2, nightly: nt, target: "any", outcome: Fail, modules: ["Yaml.roc"], closure: "" }
	release = { hash: h1, nightly: "0.1.0", target: "any", outcome: Hang, modules: [], closure: "" }
	index = Facts.index([check, build, other, release])
	key = |hash, nightly, target| { hash, nightly, target }
	rows = [
		(index.len() == 4, "4 entries"),
		(index.get(key(h1, nt, "any")) == Ok(check), "check"),
		(index.get(key(h1, nt, host)) == Ok(build), "build"),
		(index.get(key(h2, nt, "any")) == Ok(other), "other hash"),
		(index.get(key(h1, "0.1.0", "any")) == Ok(release), "release id (R-NS12)"),
		(index.get(key(h2, nt, host)) == Err(KeyNotFound), "no fact"),
		(Facts.index([]).len() == 0, "empty"),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}

# R-CV6: the first-seen decision for the asset (tag, target). No row of this tag and target: `New`. The same sha256: `Same`, also with another source. Another sha256: `Changed`, with the recorded row first.
# A row of another tag or of another target of the tag is no row of this asset.
expect {
	listed = { tag: nt, target: host, sha256: sha_a, source: GithubDigest }
	same = { tag: nt, target: host, sha256: sha_a, source: GithubDigest }
	other_source = { ..listed, source: Registry }
	changed = { ..listed, sha256: sha_b, source: Registry }
	other_tag = { ..listed, tag: "nightly-2026-10-12-2664a27", sha256: sha_b }
	other_target = { ..listed, target: "linux_arm64", sha256: sha_b }
	rows = [
		(Facts.first_seen({ recorded: [], listed }) == New, "no row"),
		(Facts.first_seen({ recorded: [same], listed }) == Same, "same"),
		(Facts.first_seen({ recorded: [other_source], listed }) == Same, "same sha256, other source"),
		(Facts.first_seen({ recorded: [changed], listed }) == Changed({ first: changed, now: listed }), "changed"),
		(Facts.first_seen({ recorded: [other_tag, other_target], listed }) == New, "rows of other assets"),
		(Facts.first_seen({ recorded: [other_tag, changed, other_target], listed }) == Changed({ first: changed, now: listed }), "changed, among others"),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}

# R-CV6 (TW24, proposal): the failure for a changed sha256 is kind Integrity (exit 16). The message names the tag, the target, both values and both sources. There is no override.
expect {
	first = { tag: nt, target: host, sha256: sha_a, source: GithubDigest }
	now = { tag: nt, target: host, sha256: sha_b, source: Registry }
	got = Facts.changed_fail({ first, now })
	want = Fail.new(Integrity, "the sha256 of ${nt} for ${host} changed: first seen ${sha_a} (github-digest), now ${sha_b} (registry). Talon does not use this compiler. Select another compiler.")
	dbg got
	got == want
}
