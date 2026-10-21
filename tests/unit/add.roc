app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Add
import lib.Fail
import lib.Selector

main! = |_args| Ok({})

# A release URL of a GitHub repo at a version. The hash text is not checked here.
url = |repo, ver| "https://github.com/${repo}/releases/download/${ver}/Hhash.tar.zst"

pf_old = { alias: "pf", url: url("roc-lang/basic-cli", "0.25.0"), is_platform: Bool.True }

json_old = { alias: "json", url: url("someone/roc-json", "2.1.0"), is_platform: Bool.False }

util_path = { alias: "util", url: "../util/main.roc", is_platform: Bool.False }

header = [pf_old, json_old, util_path]

none = Err(None)

no_as = Err(Unset)

nothing = Err(Nothing)

# The plan as data. The failure is one text (the stderr line).
view = |res| match res {
	Ok(p) => Ok((p.alias, p.header, p.url, p.toml, p.note))
	Err(f) => Err(Fail.line(f))
}

new = |name, ver, sel, no_pin, as_alias| view(
	Add.decide({
		selector: sel,
		chosen: { name, url: url(name, ver), kind: Package },
		platform_flag: Bool.False,
		no_pin,
		as_alias,
		header,
	}),
)

plat = |name, ver, kind, sel, as_alias, h| view(
	Add.decide({
		selector: sel,
		chosen: { name, url: url(name, ver), kind },
		platform_flag: Bool.True,
		no_pin: Bool.False,
		as_alias,
		header: h,
	}),
)

# R-AD23 R-AD24 R-AD25 R-AD26 R-AD27 R-AD28 R-SL5 R-AD8 R-AD11 R-AD19: a new entry. The header always gets it.
# `talon.toml` gets the alias as key: nothing for no selector and for `latest`, an anchor `=1.2.3` for an exact version
# (hard pin by default), a range `^1.2` or `^1` for a range or a series. `--no-pin` gives an exact start version with no key.
# An alias error of `Alias.choose` stops the plan.
expect {
	uni = url("roc-lang/unicode", "4.2.0")
	set = |key, value| Ok({ key, value })
	rows = [
		(new("roc-lang/unicode", "4.2.0", none, Bool.False, no_as), Ok(("unicode", Insert, uni, nothing, none))),
		(new("roc-lang/unicode", "4.2.0", Ok(Selector.Latest), Bool.False, no_as), Ok(("unicode", Insert, uni, nothing, none))),
		(new("roc-lang/unicode", "4.2.0", Ok(Selector.Exact("4.2.0")), Bool.False, no_as), Ok(("unicode", Insert, uni, set("unicode", "=4.2.0"), none))),
		(new("roc-lang/unicode", "4.2.0", Ok(Selector.Exact("4.2.0")), Bool.True, no_as), Ok(("unicode", Insert, uni, nothing, none))),
		(new("roc-lang/unicode", "4.2.0", Ok(Selector.Range("^1.2")), Bool.False, no_as), Ok(("unicode", Insert, uni, set("unicode", "^1.2"), none))),
		(new("roc-lang/unicode", "4.2.0", Ok(Selector.Range("^4")), Bool.False, no_as), Ok(("unicode", Insert, uni, set("unicode", "^4"), none))),
		(
			new("lukewilliamboswell/roc-parser", "2.0.0", Ok(Selector.Exact("2.0.0")), Bool.False, no_as),
			Ok(("parser", Insert, url("lukewilliamboswell/roc-parser", "2.0.0"), set("parser", "=2.0.0"), none)),
		),
		(
			new("someone/roc-yaml", "1.0.0", Ok(Selector.Exact("1.0.0")), Bool.False, Ok("yml")),
			Ok(("yml", Insert, url("someone/roc-yaml", "1.0.0"), set("yml", "=1.0.0"), none)),
		),
		(
			new("owner/9lives", "1.0.0", none, Bool.False, no_as),
			Err("tln: error[usage]: the default alias '9lives' for 'owner/9lives' is not a valid name. Use --as <alias>."),
		),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-AD20 R-AD21 R-AD22 R-AD28 R-I9 R-SL5 Q11: an entry that is in the header (X is a header alias, or its group is in the header
# under any alias). No selector: no change, a note, `talon.toml` untouched. A selector: the same as `tln update X@sel`, and
# the `talon.toml` value follows the table of `tln add`.
expect {
	json_url = url("someone/roc-json", "2.1.0")
	keep_note = Ok("json: someone/roc-json 2.1.0 is in the header\nRun tln update json to move it.")
	alias = |sel, no_pin| view(Add.decide_alias({ alias: "json", selector: sel, no_pin, header }))
	set = |value| Ok({ key: "json", value })
	by_name = |ver, sel, h| view(
		Add.decide({
			selector: sel,
			chosen: { name: "someone/roc-json", url: url("someone/roc-json", ver), kind: Package },
			platform_flag: Bool.False,
			no_pin: Bool.False,
			as_alias: no_as,
			header: h,
		}),
	)
	js_old = { alias: "js", url: url("someone/roc-json", "2.1.0"), is_platform: Bool.False }
	http_old = { alias: "http", url: url("roc-lang/http", "1.9.0"), is_platform: Bool.False }
	http_2 = |as_alias| view(
		Add.decide({
			selector: Ok(Selector.Range("^2")),
			chosen: { name: "roc-lang/http", url: url("roc-lang/http", "2.0.0"), kind: Package },
			platform_flag: Bool.False,
			no_pin: Bool.False,
			as_alias,
			header: [pf_old, http_old],
		}),
	)
	rows = [
		(alias(none, Bool.False), Ok(("json", Keep, json_url, nothing, keep_note))),
		(alias(Ok(Selector.Range("^3")), Bool.False), Ok(("json", Update, json_url, set("^3"), none))),
		(alias(Ok(Selector.Exact("2.2.0")), Bool.False), Ok(("json", Update, json_url, set("=2.2.0"), none))),
		(alias(Ok(Selector.Exact("2.2.0")), Bool.True), Ok(("json", Update, json_url, nothing, none))),
		(by_name("2.2.0", none, header), Ok(("json", Keep, json_url, nothing, keep_note))),
		(by_name("2.2.0", Ok(Selector.Range("^2")), header), Ok(("json", Update, json_url, set("^2"), none))),
		(
			by_name("2.2.0", none, [pf_old, js_old]),
			Ok(("js", Keep, json_url, nothing, Ok("js: someone/roc-json 2.1.0 is in the header\nRun tln update js to move it."))),
		),
		# Q11 R-AD22: the header has the repo once (series 1). `add roc-lang/http@2` moves that entry to series 2.
		(http_2(no_as), Ok(("http", Update, url("roc-lang/http", "1.9.0"), Ok({ key: "http", value: "^2" }), none))),
		# Q11: `--as` keeps both series, so the new series is a new entry.
		(http_2(Ok("http2")), Ok(("http2", Insert, url("roc-lang/http", "2.0.0"), Ok({ key: "http2", value: "^2" }), none))),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-AD29 R-AD30 R-AD31 R-AD32 R-AD33 R-AD25 R-AD26 R-SE7: `tln add --platform`. A header has one platform.
# With none: a new entry `pf` (or `--as`). With one: it is replaced under the same alias, also for another repo, and the
# `talon.toml` key of the old platform gets the value of the table. A release that is no platform is a usage failure.
# `tln add X` where X is a platform is a usage failure that names `--platform`. A replaced platform gets a notice.
expect {
	web = url("roc-lang/basic-webserver", "0.13.0")
	cli_new = url("roc-lang/basic-cli", "0.26.1")
	set = |value| Ok({ key: "pf", value })
	no_plat = [json_old, util_path]
	rows = [
		(
			plat("roc-lang/basic-webserver", "0.13.0", Platform, Ok(Selector.Exact("0.13.0")), no_as, header),
			Ok(("pf", Replace, web, set("=0.13.0"), Ok("platform changes: roc-lang/basic-cli 0.25.0 -> roc-lang/basic-webserver 0.13.0"))),
		),
		(
			plat("roc-lang/basic-cli", "0.26.1", Platform, Ok(Selector.Range("^0.26")), no_as, header),
			Ok(("pf", Replace, cli_new, set("^0.26"), Ok("platform changes: roc-lang/basic-cli 0.25.0 -> roc-lang/basic-cli 0.26.1"))),
		),
		(
			plat("roc-lang/basic-cli", "0.26.1", Platform, none, no_as, no_plat),
			Ok(("pf", Insert, cli_new, nothing, none)),
		),
		(
			plat("roc-lang/basic-cli", "0.26.1", Platform, Ok(Selector.Exact("0.26.1")), Ok("cli"), no_plat),
			Ok(("cli", Insert, cli_new, Ok({ key: "cli", value: "=0.26.1" }), none)),
		),
		(
			# R-AD31: the platform is the entry with `is_platform`, not the entry that has the alias `pf` (a package can have it).
			plat(
				"roc-lang/basic-webserver",
				"0.13.0",
				Platform,
				none,
				no_as,
				[
					{ alias: "pf", url: url("someone/pf-tools", "1.0.0"), is_platform: Bool.False },
					{ alias: "shell", url: url("roc-lang/basic-cli", "0.25.0"), is_platform: Bool.True },
					json_old,
				],
			),
			Ok(("shell", Replace, web, nothing, Ok("platform changes: roc-lang/basic-cli 0.25.0 -> roc-lang/basic-webserver 0.13.0"))),
		),
		(
			plat("roc-lang/unicode", "4.2.0", Package, none, no_as, header),
			Err("tln: error[usage]: 'roc-lang/unicode' is not a platform"),
		),
		(
			view(
				Add.decide({
					selector: none,
					chosen: { name: "roc-lang/basic-cli", url: cli_new, kind: Platform },
					platform_flag: Bool.False,
					no_pin: Bool.False,
					as_alias: no_as,
					header: no_plat,
				}),
			),
			Err("tln: error[usage]: 'roc-lang/basic-cli' is a platform. Use tln add --platform roc-lang/basic-cli."),
		),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-AD28 R-FL12: `--as` names one entry, so `tln add a b --as x` is a usage failure. Without `--as`, any count is fine.
expect {
	check = |names, as_alias| match Add.check_names({ names, as_alias }) {
		Ok(_) => Ok({})
		Err(f) => Err(Fail.line(f))
	}
	rows = [
		(check(1, Ok("x")), Ok({})),
		(check(2, no_as), Ok({})),
		(check(5, no_as), Ok({})),
		(check(2, Ok("x")), Err("tln: error[usage]: flag '--as' names one entry: got 2 names")),
		(check(3, Ok("x")), Err("tln: error[usage]: flag '--as' names one entry: got 3 names")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-SL12 R-SL3 R-SL4 R-EC2 (slice 007, question Q2): `tln add` of a new name with a selector that no release matches is a usage failure (exit 2) that lists the close versions:
# at most 3, newest first. An exact version: the 3 nearest in the version order (below first, then above, and so on). Another selector: the 3 newest. No version: no list.
expect {
	all = ["1.0.0", "1.1.0", "1.2.0", "1.3.0", "2.0.0"]
	line = |sel, text, versions| Fail.line(Add.no_release({ name: "acme/lex", selector: sel, text, versions }))
	head = "tln: error[usage]: no release of acme/lex matches"
	rows = [
		(line(Ok(Selector.Exact("9.9.9")), "9.9.9", ["1.2.0", "1.0.0", "1.1.0"]), "${head} '9.9.9'. Close versions: 1.2.0, 1.1.0, 1.0.0."),
		(line(Ok(Selector.Exact("1.1.5")), "1.1.5", all), "${head} '1.1.5'. Close versions: 1.2.0, 1.1.0, 1.0.0."),
		(line(Ok(Selector.Exact("0.1.0")), "0.1.0", all), "${head} '0.1.0'. Close versions: 1.2.0, 1.1.0, 1.0.0."),
		(line(Ok(Selector.Range("^3")), "^3", all), "${head} '^3'. Close versions: 2.0.0, 1.3.0, 1.2.0."),
		(line(Ok(Selector.Range("^3")), "3", ["1.0.0"]), "${head} '3'. Close versions: 1.0.0."),
		(line(Ok(Selector.Range("^3")), "^3", []), "${head} '^3'."),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-WS12 Q9 R-SP16 R-SP17 R-EC10 (slice 007): a new entry for a group that other members hold. When the range of the selector admits each held version, the entry gets the held version.
# When it excludes one, the move needs R-NI3, which P0 cannot ask: exit 10 (no_tuple), nothing is written. The failure names the first excluded version and the members that hold it.
expect {
	check = |range, held| match Add.check_held({ name: "acme/json", range, held }) {
		Ok(_) => Ok({})
		Err(f) => Err(Fail.line(f))
	}
	a = { file: "/w/apps/a/main.roc", version: "2.0.0" }
	b = { file: "/w/apps/b/main.roc", version: "2.1.0" }
	c = { file: "/w/apps/c/main.roc", version: "2.0.0" }
	tail = "Moving a held version needs consent (R-NI3), which this version of tln cannot ask. Nothing was written."
	rows = [
		(check("*", [a]), Ok({})),
		(check("=2.0.0", [a, c]), Ok({})),
		(check("^2", [a, b]), Ok({})),
		(check("*", []), Ok({})),
		(
			check("=2.1.0", [a]),
			Err("tln: error[no_tuple]: no tuple works: '=2.1.0' for acme/json excludes the version 2.0.0 held by /w/apps/a/main.roc. ${tail}"),
		),
		(
			check("=2.1.0", [a, b, c]),
			Err("tln: error[no_tuple]: no tuple works: '=2.1.0' for acme/json excludes the version 2.0.0 held by /w/apps/a/main.roc, /w/apps/c/main.roc. ${tail}"),
		),
		(
			check("^3", [b, a]),
			Err("tln: error[no_tuple]: no tuple works: '^3' for acme/json excludes the version 2.1.0 held by /w/apps/b/main.roc. ${tail}"),
		),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-SE7 R-AD31 (slice 009): the text of the notice for a platform release that changes. A new name, and a new version of the same name. `Add.decide` gives the same text for `Replace`.
expect {
	note = |from, to| Add.platform_note({ from, to })
	rows = [
		(note({ name: "roc-lang/basic-cli", version: "0.25.0" }, { name: "roc-lang/basic-webserver", version: "0.13.0" }), "platform changes: roc-lang/basic-cli 0.25.0 -> roc-lang/basic-webserver 0.13.0"),
		(note({ name: "acme/pf", version: "0.1.0" }, { name: "acme/pf", version: "0.1.1" }), "platform changes: acme/pf 0.1.0 -> acme/pf 0.1.1"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-SL12 R-SL3 R-SL4 R-EC10 (slice 009, question Q5): the text that `tln update X@sel` adds to the failure `no tuple works: ... has no release that satisfies ...` (exit 10, the answer of the manager to Q2 of slice 007). It is a space, then `Close versions: ` and at most 3 versions, newest first, and a full stop.
# The versions are chosen as `no_release` chooses them: the 3 nearest to an exact version, else the 3 newest. No version that parses gives no text.
expect {
	close = |selector, versions| Add.close_note({ selector, versions })
	all = ["2.0.0", "2.2.0", "2.0.5", "2.1.0", "1.9.0"]
	rows = [
		(close(Ok(Selector.Range("^3")), all), " Close versions: 2.2.0, 2.1.0, 2.0.5."),
		(close(Ok(Selector.Exact("2.0.4")), all), " Close versions: 2.0.5, 2.0.0, 1.9.0."),
		(close(Ok(Selector.Range("^3")), ["1.0.0", "1.1.0"]), " Close versions: 1.1.0, 1.0.0."),
		(close(Ok(Selector.Latest), all), " Close versions: 2.2.0, 2.1.0, 2.0.5."),
		(close(Ok(Selector.Range("^3")), []), ""),
		(close(Ok(Selector.Range("^3")), ["x", "1.2"]), ""),
		(close(Err(None), ["1.0.0"]), " Close versions: 1.0.0."),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-AD38 R-AD31 R-H9 R-H4 R-AD18 R-AD32 R-AD33 R-C4 R-AD25 R-AD26 R-AD27 R-SL5 R-SE7 (slice 015): `--as <alias>` where the alias is an unmanaged entry (a path entry or a foreign URL) replaces the whole entry under the same
# alias (`Replace`). `talon.toml` follows the table of `tln add` (no selector and `latest`: nothing, an exact version: an anchor, a range: the range, `--no-pin` drops the anchor). The note names the old value as written.
# The platform entry that is a path entry is replaced by `--platform` under its alias (R-AD31), and `--as` over it needs a platform release (R-AD32, R-C4). A platform release over a package entry is the failure of R-AD33.
# The default alias never replaces: it is the failure of R-AD18, with the text that names `--as`.
expect {
	odd_url = "https://example.com/pkg/latest.tar.gz"
	odd_row = { alias: "odd", url: odd_url, is_platform: Bool.False }
	pf_path = { alias: "pf", url: "../platform/main.roc", is_platform: Bool.True }
	with_path_pf = [pf_path, json_old, util_path, odd_row]
	with_pf = [pf_old, json_old, util_path, odd_row]
	as_ = |name, ver, sel, no_pin, alias, kind, h| view(
		Add.decide({
			selector: sel,
			chosen: { name, url: url(name, ver), kind },
			platform_flag: Bool.False,
			no_pin,
			as_alias: Ok(alias),
			header: h,
		}),
	)
	util_url = url("acme/util", "1.1.0")
	note_util = Ok("entry changes: ../util/main.roc -> acme/util 1.1.0")
	set = |key, value| Ok({ key, value })
	rows = [
		("a path entry, no selector", as_("acme/util", "1.1.0", none, Bool.False, "util", Package, with_pf), Ok(("util", Replace, util_url, nothing, note_util))),
		("a path entry, latest is no selector", as_("acme/util", "1.1.0", Ok(Selector.Latest), Bool.False, "util", Package, with_pf), Ok(("util", Replace, util_url, nothing, note_util))),
		("a path entry, an exact version", as_("acme/util", "1.1.0", Ok(Selector.Exact("1.1.0")), Bool.False, "util", Package, with_pf), Ok(("util", Replace, util_url, set("util", "=1.1.0"), note_util))),
		("a path entry, an exact version, --no-pin", as_("acme/util", "1.1.0", Ok(Selector.Exact("1.1.0")), Bool.True, "util", Package, with_pf), Ok(("util", Replace, util_url, nothing, note_util))),
		("a path entry, a range", as_("acme/util", "1.1.0", Ok(Selector.Range("^1")), Bool.False, "util", Package, with_pf), Ok(("util", Replace, util_url, set("util", "^1"), note_util))),
		(
			"a foreign URL",
			as_("acme/odd", "1.0.0", none, Bool.False, "odd", Package, with_pf),
			Ok(("odd", Replace, url("acme/odd", "1.0.0"), nothing, Ok("entry changes: ${odd_url} -> acme/odd 1.0.0"))),
		),
		("the platform entry is a path entry: a package is no platform (R-AD32)", as_("acme/util", "1.1.0", none, Bool.False, "pf", Package, with_path_pf), Err("tln: error[usage]: 'acme/util' is not a platform")),
		("a package entry: a platform release needs --platform (R-AD33)", as_("acme/pf", "0.1.0", none, Bool.False, "util", Platform, with_pf), Err("tln: error[usage]: 'acme/pf' is a platform. Use tln add --platform acme/pf.")),
		(
			"the default alias is the path entry: it stops and names --as",
			new("owner/util", "1.0.0", none, Bool.False, no_as),
			Err("tln: error[usage]: the default alias 'util' for 'owner/util' is used by a path entry in the header. Use --as <alias>, or --as util to replace that entry."),
		),
		("--platform replaces a path platform under its alias", plat("acme/pf", "0.1.0", Platform, none, no_as, with_path_pf), Ok(("pf", Replace, url("acme/pf", "0.1.0"), nothing, Ok("platform changes: ../platform/main.roc -> acme/pf 0.1.0")))),
		(
			"--platform replaces a path platform, an exact version",
			plat("acme/pf", "0.1.0", Platform, Ok(Selector.Exact("0.1.0")), no_as, with_path_pf),
			Ok(("pf", Replace, url("acme/pf", "0.1.0"), set("pf", "=0.1.0"), Ok("platform changes: ../platform/main.roc -> acme/pf 0.1.0"))),
		),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-AD21 R-AD22 R-AD20 R-H9 R-H4 R-SL5 R-EC2 (slice 015): `tln add X` where X is the alias of an unmanaged entry. No selector (and `latest`, R-SL5) changes nothing: exit 0, and the note prints the value as written and names
# no command (the entry has no version, and `tln update` refuses it). A selector is the failure `never_changes`: exit 2, as `tln update X` (R-H9). The text names `tln add <name> --as X`, the one way to change the entry (R-AD38).
# A path entry is "a path entry" and a URL is "a foreign URL" (a value with `://`).
expect {
	odd_url = "https://example.com/pkg/latest.tar.gz"
	h = [pf_old, json_old, util_path, { alias: "odd", url: odd_url, is_platform: Bool.False }]
	alias = |name, sel| view(Add.decide_alias({ alias: name, selector: sel, no_pin: Bool.False, header: h }))
	path_text = "tln: error[usage]: util is a path entry: Talon never changes it. To replace it, run tln add <name> --as util."
	odd_text = "tln: error[usage]: odd is a foreign URL: Talon never changes it. To replace it, run tln add <name> --as odd."
	rows = [
		("a path entry, no selector", alias("util", none), Ok(("util", Keep, "../util/main.roc", nothing, Ok("util: ../util/main.roc is in the header")))),
		("a foreign URL, no selector", alias("odd", none), Ok(("odd", Keep, odd_url, nothing, Ok("odd: ${odd_url} is in the header")))),
		("a path entry, latest", alias("util", Ok(Selector.Latest)), Ok(("util", Keep, "../util/main.roc", nothing, Ok("util: ../util/main.roc is in the header")))),
		("a path entry, a range", alias("util", Ok(Selector.Range("^3"))), Err(path_text)),
		("a path entry, an exact version", alias("util", Ok(Selector.Exact("1.0.0"))), Err(path_text)),
		("a foreign URL, a range", alias("odd", Ok(Selector.Range("^1"))), Err(odd_text)),
		("a release stays as before", alias("json", Ok(Selector.Range("^3"))), Ok(("json", Update, url("someone/roc-json", "2.1.0"), Ok({ key: "json", value: "^3" }), none))),
	]
	failures = [
		("never_changes, a path entry", Fail.line(Add.never_changes({ alias: "util", value: "../util/main.roc" })), path_text),
		("never_changes, a foreign URL", Fail.line(Add.never_changes({ alias: "odd", value: odd_url })), odd_text),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	bad_failures = failures.keep_if(|(_, got, want)| got != want)
	dbg (bad, bad_failures)
	bad == [] and bad_failures == []
}
