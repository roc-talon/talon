app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Db
import lib.Fail
import lib.Ident
import lib.Intent
import lib.Lags
import lib.Locked
import lib.Pick
import lib.Upgrade

main! = |_args| Ok({})

now = 1792065600

day = 86400

nightly = "nightly-2026-10-14-38a3029"

# A release URL of the fixture host (as in `pickmoves.roc`).
u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

hash = |url| match Ident.of_url(url) {
	Ok(ident) => ident.hash
	Err(_) => crash "bad test URL"
}

cand = |url, days| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

# A slot of `tln upgrade`: no range (R-UP1), the header value `ver`, and its candidates (all 30 days old unless the row says so).
slot = |id, is_platform, hold, ver, candidates| { id, is_platform, ranges: [], current: Ok(u(id, ver)), hold, named: Err(None), candidates: candidates.map(|(v, days)| cand(u(id, v), days)), files: [] }

pkg = |id, ver, deps| { url: u(id, ver), release: { kind: Package, pf: Err(None), deps } }

names_pf = |id, ver, pf_ver| { url: u(id, ver), release: { kind: Package, pf: Ok(u("pf", pf_ver)), deps: [] } }

plat = |ver| { url: u("pf", ver), release: { kind: Platform, pf: Err(None), deps: [] } }

chosen = |id, ver| { id, url: u(id, ver), version: ver, change: Keep, note: Err(None) }

row = |id, ver, outcome, modules| { hash: hash(u(id, ver)), nightly, target: "any", outcome, modules, closure: "" }

lag_view = |lags| lags.map(|l| (l.alias, l.newest, l.got, l.why))

# The options of `upgrade` as a tuple (the failure is a text: an `Err` record with a `Bool` crashes `roc test`).
read_view = |words| match Args.parse(words) {
	Err(stop) => Err(Fail.line(stop.fail))
	Ok(args) => match Upgrade.read(args) {
		Ok({ opts }) => Ok((opts.names, [opts.dry_run, opts.no_check, opts.no_probe], opts.strategy))
		Err(f) => Err(Fail.line(f))
	}
}

# R-UP8 R-UP9 R-UP13 R-CM5 R-FL5 R-FL10 R-FL13 R-SP8 R-SP9 R-SL5 (slice 038, Q4 (a); slice 039): the options of `upgrade`. A name with a selector (`json@^3`) is a usage failure: the selector is the word of `update`. The names and the flags are the ones of `update`. `--strategy lowest` is a usage failure (R-UP8: upgrade only moves up).
# `--frozen` is a usage failure (R-FL13). The name `roc` is a name like the others (slice 039). R-UP9: `--no-check` is a usage failure when the nightly is free (no names, or the name `roc`): the pin moves only after the check. With the packages named (`upgrade json --no-check`) the nightly is held and the flag works. The order of the checks: the registry and the strategy of `Opts.read`, then `--frozen`, then `lowest`, then a selector, then `--no-check` with a free nightly.
expect {
	frozen = "tln: error[usage]: flag '--frozen' works only for tln install with no names"
	lowest = "tln: error[usage]: --strategy lowest does not work with tln upgrade: upgrade only moves up"
	selector = |name| "tln: error[usage]: tln upgrade does not take a selector: '${name}'. Use tln update ${name}"
	no_check = "tln: error[usage]: --no-check does not work when tln upgrade moves the nightly: the roc pin moves only after the check. Name the packages to hold the nightly: tln upgrade <name> --no-check"
	rows = [
		(["upgrade"], Ok(([], [Bool.False, Bool.False, Bool.False], Err(Unset)))),
		(["upgrade", "json", "parser"], Ok((["json", "parser"], [Bool.False, Bool.False, Bool.False], Err(Unset)))),
		(["upgrade", "--dry-run", "--no-check", "--json", "json"], Ok((["json"], [Bool.True, Bool.True, Bool.False], Err(Unset)))),
		(["upgrade", "--strategy", "highest", "--no-probe"], Ok(([], [Bool.False, Bool.False, Bool.True], Ok(Highest)))),
		(["upgrade", "--strategy", "lowest"], Err(lowest)),
		(["upgrade", "--strategy=lowest", "json"], Err(lowest)),
		(["upgrade", "--frozen"], Err(frozen)),
		(["upgrade", "--frozen", "--strategy", "lowest"], Err(frozen)),
		(["upgrade", "--strategy", "lowest", "roc"], Err(lowest)),
		(["upgrade", "--strategy", "middle", "--frozen"], Err("tln: error[usage]: --strategy must be highest or lowest, not 'middle'")),
		(["upgrade", "json@^3"], Err(selector("json@^3"))),
		(["upgrade", "json@^3", "roc"], Err(selector("json@^3"))),
		(["upgrade", "--strategy", "lowest", "json@^3"], Err(lowest)),
		(["upgrade", "roc"], Ok((["roc"], [Bool.False, Bool.False, Bool.False], Err(Unset)))),
		(["upgrade", "json", "roc"], Ok((["json", "roc"], [Bool.False, Bool.False, Bool.False], Err(Unset)))),
		(["upgrade", "--no-check"], Err(no_check)),
		(["upgrade", "roc", "--no-check"], Err(no_check)),
		(["upgrade", "json", "roc", "--no-check"], Err(no_check)),
		(["upgrade", "--dry-run", "--no-check", "roc"], Err(no_check)),
		(["upgrade", "json", "--no-check"], Ok((["json"], [Bool.False, Bool.True, Bool.False], Err(Unset)))),
		(["upgrade", "--strategy", "lowest", "--no-check"], Err(lowest)),
		(["upgrade", "json@^3", "--no-check"], Err(selector("json@^3"))),
	]
	bad = rows.keep_if(|(words, want)| read_view(words) != want).map(|(words, want)| (words, want, read_view(words)))
	dbg bad
	bad == []
}

# R-UP2 R-UP1 R-C2 R-C3 R-C6 R-C7 R-EP7 R-UM1 R-SP23 (slice 038): the free variables that did not get their newest release, in the order of the slots, with the first reason (a proposal, TW24). The newest release is the one of the domain with no range
# (young releases are no candidates: R-C7). A held variable, and a movable one, is never a lag. A real db row on the held compiler comes first (a fail with no module, with a module that the app uses, a hang, a crash), then a platform that the
# newest package names (R-C3), then a dep above the chosen version of another slot (R-C2), then a newest platform that a chosen package does not name, then the rest. A fail row of a module that the app does not use is no reason. A newest release with no header fact skips the
# reasons of the header.
expect {
	all_days = |vs| vs.map(|v| (v, 30))
	slots = [
		slot("pf", Bool.True, Free, "0.1.0", all_days(["0.1.0", "0.1.1", "0.2.0"])),
		slot("text", Bool.False, Free, "1.0.0", all_days(["1.0.0", "2.0.0"])),
		slot("json", Bool.False, Free, "2.0.0", all_days(["2.0.0", "2.2.0", "3.0.0"])),
		slot("core", Bool.False, Held, "1.0.0", all_days(["1.0.0", "1.2.0"])),
		slot("parser", Bool.False, Free, "1.0.0", all_days(["1.0.0", "1.1.0"])),
		slot("cli2", Bool.False, Free, "1.0.0", all_days(["1.0.0", "2.0.0"])),
		slot("hangs", Bool.False, Free, "1.0.0", all_days(["1.0.0", "1.1.0"])),
		slot("crashy", Bool.False, Free, "1.0.0", all_days(["1.0.0", "1.1.0"])),
		slot("farfail", Bool.False, Free, "1.0.0", all_days(["1.0.0", "1.1.0"])),
		slot("usedfail", Bool.False, Free, "1.0.0", all_days(["1.0.0", "1.1.0"])),
		slot("both", Bool.False, Free, "1.0.0", all_days(["1.0.0", "1.1.0"])),
		slot("young", Bool.False, Free, "1.0.0", [("1.0.0", 30), ("1.1.0", 1)]),
		slot("moves", Bool.False, Movable, "1.0.0", all_days(["1.0.0", "1.1.0"])),
		slot("nofact", Bool.False, Free, "1.0.0", all_days(["1.0.0", "1.1.0"])),
		slot("plain", Bool.False, Free, "1.0.0", all_days(["1.0.0", "1.1.0"])),
	]
	facts = [
		plat("0.1.0"),
		plat("0.1.1"),
		plat("0.2.0"),
		pkg("text", "1.0.0", []),
		names_pf("text", "2.0.0", "0.1.1"),
		pkg("json", "2.2.0", []),
		pkg("json", "3.0.0", [u("core", "1.2.0")]),
		pkg("core", "1.0.0", []),
		pkg("core", "1.2.0", []),
		pkg("parser", "1.1.0", []),
		names_pf("cli2", "2.0.0", "0.2.0"),
		pkg("hangs", "1.1.0", []),
		pkg("crashy", "1.1.0", []),
		pkg("farfail", "1.1.0", []),
		pkg("usedfail", "1.1.0", []),
		pkg("both", "1.1.0", [u("core", "1.2.0")]),
		pkg("young", "1.1.0", []),
		pkg("moves", "1.1.0", []),
		pkg("plain", "1.1.0", []),
	]
	picked = [
		chosen("pf", "0.1.1"),
		chosen("text", "2.0.0"),
		chosen("json", "2.2.0"),
		chosen("core", "1.0.0"),
		chosen("parser", "1.0.0"),
		chosen("cli2", "1.0.0"),
		chosen("hangs", "1.0.0"),
		chosen("crashy", "1.0.0"),
		chosen("farfail", "1.0.0"),
		chosen("usedfail", "1.0.0"),
		chosen("both", "1.0.0"),
		chosen("young", "1.0.0"),
		chosen("moves", "1.0.0"),
		chosen("nofact", "1.0.0"),
		chosen("plain", "1.0.0"),
	]
	checks = [
		row("parser", "1.1.0", Fail, []),
		row("hangs", "1.1.0", Hang, []),
		row("crashy", "1.1.0", Crash, []),
		row("farfail", "1.1.0", Fail, ["Other.roc"]),
		row("usedfail", "1.1.0", Fail, ["Json.roc"]),
		row("both", "1.1.0", Fail, ["main.roc"]),
		row("plain", "1.1.0", Pass, []),
	]
	used = [{ id: u("usedfail", "1.1.0"), modules: ["Json.roc"] }]
	input = |compiler, rows| { slots, chosen: picked, facts, now, min_age: 2 * day, snapshot: Err(None), compiler, checks: rows, used }
	on = "on ${nightly}"
	got = lag_view(Lags.of(input(Ok(nightly), checks)))
	want = [
		("pf", "0.2.0", "0.1.1", "text 2.0.0 needs pf 0.1.1"),
		("json", "3.0.0", "2.2.0", "needs core >= 1.2.0"),
		("parser", "1.1.0", "1.0.0", "fails the unit check ${on}"),
		("cli2", "2.0.0", "1.0.0", "needs pf 0.2.0"),
		("hangs", "1.1.0", "1.0.0", "hangs the unit check ${on}"),
		("crashy", "1.1.0", "1.0.0", "crashes the unit check ${on}"),
		("farfail", "1.1.0", "1.0.0", "it does not fit the closure of the tuple"),
		("usedfail", "1.1.0", "1.0.0", "fails the unit check ${on}"),
		("both", "1.1.0", "1.0.0", "fails the unit check ${on}"),
		("nofact", "1.1.0", "1.0.0", "it does not fit the closure of the tuple"),
		("plain", "1.1.0", "1.0.0", "it does not fit the closure of the tuple"),
	]
	# With no compiler the rows of the db are not read: the order of the other reasons stays.
	no_compiler = lag_view(Lags.of(input(Err(None), checks))).map(|(a, _, _, why)| (a, why))
	want_no_compiler = [
		("pf", "text 2.0.0 needs pf 0.1.1"),
		("json", "needs core >= 1.2.0"),
		("parser", "it does not fit the closure of the tuple"),
		("cli2", "needs pf 0.2.0"),
		("hangs", "it does not fit the closure of the tuple"),
		("crashy", "it does not fit the closure of the tuple"),
		("farfail", "it does not fit the closure of the tuple"),
		("usedfail", "it does not fit the closure of the tuple"),
		("both", "needs core >= 1.2.0"),
		("nofact", "it does not fit the closure of the tuple"),
		("plain", "it does not fit the closure of the tuple"),
	]
	dbg got
	dbg no_compiler
	got == want and no_compiler == want_no_compiler and Lags.note({ alias: "json", newest: "3.0.0", got: "2.2.0", why: "needs core >= 1.2.0" }) == "json 3.0.0 is not used, 2.2.0 is chosen: needs core >= 1.2.0"
}

h_cli = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

app_header = "app [main!] {\n\tpf: platform \"https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${h_cli}.tar.zst\",\n}\n"

## A member: the file, and its `talon.toml` (path and text), or none.
member = |file, toml| {
	locked = match Locked.read({ path: file, text: app_header }) {
		Ok(l) => l
		Err(e) => crash e.line()
	}
	parsed = match toml {
		Err(NoToml) => Err(NoToml)
		Ok({ path, text }) => match Intent.read({ path, text, role: Standalone }) {
			Ok({ intent, .. }) => Ok({ path, intent })
			Err(e) => crash e.line()
		}
	}
	{ file, locked, toml: parsed }
}

# R-UP5 R-SP25 R-WS1 R-I2 R-OV1 (slice 038): the keys of `talon.toml` that move with a version. One pair for each (file, key), in the order of the moves, with the value that `Ranges.rewrite` gives. The value keeps the `<name>@` of the form `name@range` (R-I2).
# No key means no pair: Talon adds no key and creates no file. A range that admits the new version, a range with no rule (`>=1.2, <1.5`, question Q1) and a member with no `talon.toml` give no pair. Two members under one `talon.toml` with the same alias give one pair.
expect {
	text_a = "[dependencies]\njson = \"^2.1\"\npf = \"0.25.*\"\nparser = \"=2.0.0\"\nfull = \"acme/full@^1\"\nwide = \">=1.2, <1.5\"\nsame = \"^1\"\n"
	a = member("/p/apps/a/main.roc", Ok({ path: "/p/talon.toml", text: text_a }))
	c = member("/p/apps/c/main.roc", Ok({ path: "/p/talon.toml", text: text_a }))
	b = member("/p/apps/b/main.roc", Err(NoToml))
	members = [a, b, c]
	rewrites = |moves| Lags.rewrites({ members, moves })
	mv = |file, alias, version| { file, alias, version }
	f_a = "/p/apps/a/main.roc"
	rows = [
		("a caret key moves to the new series (R-UP5)", rewrites([mv(f_a, "json", "3.0.2")]), [{ path: "/p/talon.toml", key: "json", value: "^3.0" }]),
		(
			"wildcard, anchor and name forms keep their form, in the order of the moves",
			rewrites([mv(f_a, "pf", "0.26.1"), mv(f_a, "parser", "3.0.0"), mv(f_a, "full", "2.0.0")]),
			[{ path: "/p/talon.toml", key: "pf", value: "0.26.*" }, { path: "/p/talon.toml", key: "parser", value: "=3.0.0" }, { path: "/p/talon.toml", key: "full", value: "acme/full@^2" }],
		),
		("a range that admits the version stays: no pair", rewrites([mv(f_a, "json", "2.5.0")]), []),
		("a key that is not there: no pair, no key is added", rewrites([mv(f_a, "nokey", "3.0.0")]), []),
		("a form with no rule: no pair (Q1)", rewrites([mv(f_a, "wide", "3.0.0")]), []),
		("a member with no talon.toml: no pair, no file is created", rewrites([mv("/p/apps/b/main.roc", "json", "3.0.2")]), []),
		("a file that is no member: no pair", rewrites([mv("/p/apps/z/main.roc", "json", "3.0.2")]), []),
		("2 members under one file with one alias: one pair", rewrites([mv(f_a, "same", "2.0.0"), mv("/p/apps/c/main.roc", "same", "2.0.0")]), [{ path: "/p/talon.toml", key: "same", value: "^2" }]),
		("no move: no pair", rewrites([]), []),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-UP5 R-SP25 R-I2 (slice 038, Q1 (b) and Q6 (a) of the review): `Lags.stuck` is the note for a key that stays. The key has a range with no form of R-UP5 (`Ranges.rewrite` is `NoForm`) that does not admit the new version.
# The text is `talon.toml: <key>: the range does not admit <version>, change it by hand`. A range that admits the version (a rewrite that changes nothing), a rewritable range, a key that is not there and a member with no file give no note.
# One note for each key. `Lags.was` is the old value of a key in the form of `Lags.rewrites` (`<name>@<range>` or `<range>`), `Err(None)` for a key that is not there.
expect {
	text = "[dependencies]\nwide = \">=1.2, <1.5\"\nwider = \"acme/wider@>=1, <3\"\nfine = \"^2.1\"\nmoved = \"^2.1\"\nnamed = \"acme/named@^1\"\n"
	a = member("/p/apps/a/main.roc", Ok({ path: "/p/talon.toml", text }))
	b = member("/p/apps/b/main.roc", Err(NoToml))
	members = [a, b]
	stuck = |moves| Lags.stuck({ members, moves })
	mv = |file, alias, version| { file, alias, version }
	f_a = "/p/apps/a/main.roc"
	note = |key, version| "talon.toml: ${key}: the range does not admit ${version}, change it by hand"
	rows = [
		("a range with no form: a note", stuck([mv(f_a, "wide", "3.0.2")]), [note("wide", "3.0.2")]),
		("the name form too", stuck([mv(f_a, "wider", "3.0.2")]), [note("wider", "3.0.2")]),
		("a range that admits the version: no note", stuck([mv(f_a, "wide", "1.3.0")]), []),
		("a rewritable range: no note (the pair is `Lags.rewrites`)", stuck([mv(f_a, "moved", "3.0.2")]), []),
		("a key that is not there, a member with no file, a file that is no member", stuck([mv(f_a, "nokey", "3.0.2"), mv("/p/apps/b/main.roc", "wide", "3.0.2"), mv("/p/apps/z/main.roc", "wide", "3.0.2")]), []),
		("2 moves of one key: one note", stuck([mv(f_a, "wide", "3.0.2"), mv(f_a, "wide", "3.0.2")]), [note("wide", "3.0.2")]),
		("the order of the moves", stuck([mv(f_a, "wider", "3.0.2"), mv(f_a, "wide", "3.0.2")]), [note("wider", "3.0.2"), note("wide", "3.0.2")]),
	]
	was = |path, key| Lags.was({ members, path, key })
	was_rows = [
		("a range", was("/p/talon.toml", "fine"), Ok("^2.1")),
		("the name form", was("/p/talon.toml", "named"), Ok("acme/named@^1")),
		("a key that is not there", was("/p/talon.toml", "nokey"), Err(None)),
		("another file", was("/p/other/talon.toml", "fine"), Err(None)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	bad_was = was_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	dbg bad_was
	bad == [] and bad_was == []
}

# R-RP4 R-UP2 R-UM1 R-EP7 R-EP14 (slice 039c): `Lags.blame`, the reason that a compiler does not work for some releases: the first release (in the order given) with a real check on the compiler that touches the app. A fail with no module, with `main.roc`, or with a module
# that `used` lists for the release touches. A fail in a module that the app does not use, a pass and a row of another compiler do not. A hang and a crash touch. With no real row, the first release with an inferred fail that touches (`(inferred)` ends the text). A real row of any release wins over an inferred row of an earlier release.
expect {
	c4 = "nightly-2026-10-04-4444444"
	c5 = "nightly-2026-10-05-5555555"
	jr = { alias: "json", url: u("json", "1.0.0"), version: "1.0.0" }
	lr = { alias: "lib", url: u("lib", "1.1.0"), version: "1.1.0" }
	real = |id, ver, on, outcome, modules| { hash: hash(u(id, ver)), nightly: on, target: "any", outcome, modules, closure: "" }
	guess = |id, ver, on, outcome, modules| { hash: hash(u(id, ver)), nightly: on, outcome, modules, from: [] }
	blame = |releases, checks, inferred, used| match Lags.blame({ releases, compiler: c5, checks, inferred, used }) {
		Ok(text) => text
		Err(None) => "none"
	}
	rows = [
		("a fail with no module: the first release", blame([jr, lr], [real("json", "1.0.0", c5, Fail, [])], [], []), "json 1.0.0 fails the unit check on ${c5}"),
		("a hang", blame([jr], [real("json", "1.0.0", c5, Hang, [])], [], []), "json 1.0.0 hangs the unit check on ${c5}"),
		("a crash", blame([jr], [real("json", "1.0.0", c5, Crash, [])], [], []), "json 1.0.0 crashes the unit check on ${c5}"),
		("the first release passes, the second fails: the second", blame([jr, lr], [real("json", "1.0.0", c5, Pass, []), real("lib", "1.1.0", c5, Fail, [])], [], []), "lib 1.1.0 fails the unit check on ${c5}"),
		("both fail: the order of the list, not the order of the rows", blame([jr, lr], [real("lib", "1.1.0", c5, Fail, []), real("json", "1.0.0", c5, Fail, [])], [], []), "json 1.0.0 fails the unit check on ${c5}"),
		("a fail in a module that the app does not use: no reason", blame([jr], [real("json", "1.0.0", c5, Fail, ["Far.roc"])], [], []), "none"),
		("the module is used (the scan of the release)", blame([jr], [real("json", "1.0.0", c5, Fail, ["Far.roc"])], [], [{ id: u("json", "1.0.0"), modules: ["Far.roc"] }]), "json 1.0.0 fails the unit check on ${c5}"),
		("a fail in `main.roc` always touches", blame([jr], [real("json", "1.0.0", c5, Fail, ["main.roc"])], [], []), "json 1.0.0 fails the unit check on ${c5}"),
		("a row of another compiler is no reason", blame([jr], [real("json", "1.0.0", c4, Fail, [])], [], []), "none"),
		("a pass is no reason", blame([jr], [real("json", "1.0.0", c5, Pass, [])], [], []), "none"),
		("no row, no inferred fact", blame([jr], [], [], []), "none"),
		("no release", blame([], [real("json", "1.0.0", c5, Fail, [])], [], []), "none"),
		("an inferred fail only: the text ends with `(inferred)`", blame([jr], [], [guess("json", "1.0.0", c5, Fail, [])], []), "json 1.0.0 fails the unit check on ${c5} (inferred)"),
		("an inferred pass is no reason", blame([jr], [], [guess("json", "1.0.0", c5, Pass, [])], []), "none"),
		("an inferred fail of a module that is not used: no reason", blame([jr], [], [guess("json", "1.0.0", c5, Fail, ["Far.roc"])], []), "none"),
		("an inferred fail of another compiler: no reason", blame([jr], [], [guess("json", "1.0.0", c4, Fail, [])], []), "none"),
		("a real row of the second release wins over an inferred fail of the first", blame([jr, lr], [real("lib", "1.1.0", c5, Fail, [])], [guess("json", "1.0.0", c5, Fail, [])], []), "lib 1.1.0 fails the unit check on ${c5}"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-UP2 R-UP6 R-C9 R-CV1 (slice 039c, Q4 of slice 039): `Lags.nightly`, the lag of a free nightly that did not get the newest allowed compiler N. A lag when `got` is older than N: `alias` is `roc`, and `why` is `Lags.blame` of the chosen releases on N, else the text of the last reason of `Lags.of`.
# No lag when `got` is N (also in the other tag form, R-CV1), when `got` is newer than N (H stays in the search outside the range or the age window, R-C9), when no N is known, and for a run with no compiler.
expect {
	c3 = "nightly-2026-10-03-3333333"
	c4 = "nightly-2026-10-04-4444444"
	c5 = "nightly-2026-10-05-5555555"
	jr = { alias: "json", url: u("json", "1.0.0"), version: "1.0.0" }
	lr = { alias: "lib", url: u("lib", "1.1.0"), version: "1.1.0" }
	real = |id, ver, on, outcome, modules| { hash: hash(u(id, ver)), nightly: on, target: "any", outcome, modules, closure: "" }
	base = { newest: Ok(c5), got: Ok(c4), releases: [jr, lr], checks: [real("lib", "1.1.0", c5, Fail, [])], inferred: [], used: [] }
	view = |input| match Lags.nightly(input) {
		Ok(lag) => ("${lag.alias} ${lag.newest} ${lag.got}", lag.why)
		Err(NoLag) => ("none", "")
	}
	rows = [
		("N fails for the second chosen release: the lag names it", view(base), ("roc ${c5} ${c4}", "lib 1.1.0 fails the unit check on ${c5}")),
		("no row on N: the last reason", view({ ..base, checks: [] }), ("roc ${c5} ${c4}", "it does not fit the closure of the tuple")),
		("an inferred fail on N", view({ ..base, checks: [], inferred: [{ hash: hash(u("json", "1.0.0")), nightly: c5, outcome: Fail, modules: [], from: [] }] }), ("roc ${c5} ${c4}", "json 1.0.0 fails the unit check on ${c5} (inferred)")),
		("the row is on another compiler: the last reason", view({ ..base, checks: [real("lib", "1.1.0", c4, Fail, [])] }), ("roc ${c5} ${c4}", "it does not fit the closure of the tuple")),
		("got is H, 2 releases older than N", view({ ..base, got: Ok(c3) }), ("roc ${c5} ${c3}", "lib 1.1.0 fails the unit check on ${c5}")),
		("got is N", view({ ..base, got: Ok(c5) }), ("none", "")),
		("got is N in the other tag form (R-CV1)", view({ ..base, got: Ok("nightly-2026-October-05-5555555") }), ("none", "")),
		("got is newer than N (H outside the age window stays, R-C9)", view({ ..base, newest: Ok(c4), got: Ok(c5) }), ("none", "")),
		("no N is known", view({ ..base, newest: Err(NoneKnown) }), ("none", "")),
		("no compiler in the run", view({ ..base, got: Err(None) }), ("none", "")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	note = match Lags.nightly(base) {
		Ok(lag) => Lags.note(lag)
		Err(NoLag) => "none"
	}
	dbg note
	bad == [] and note == "roc ${c5} is not used, ${c4} is chosen: lib 1.1.0 fails the unit check on ${c5}"
}
