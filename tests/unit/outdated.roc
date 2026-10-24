app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Args
import lib.Fail
import lib.Ident
import lib.Outdated

main! = |_args| Ok({})

now = 1792065600

day = 86400

# A release URL of the fixture host (as in `upgrade.roc`). `v` in the tag gives another URL form (R-DI5: the tag text around the version is part of the group).
u = |repo, ver| "https://github.com/acme/${repo}/releases/download/${ver}/${repo}x${ver.replace_each(".", "x")}.tar.zst"

cand = |url, days| match Ident.of_url(url) {
	Ok(ident) => { url, ident, tag: ident.version, published_at: now - days * day, size: 1 }
	Err(_) => crash "bad test URL"
}

# The input of `Outdated.versions` for the header value `current` of `json`: `ranges`, and the candidates `(version, age in days)` in any order. min-release-age is 2 days.
ask = |current, ranges, specs| {
	current: u("json", current),
	ranges,
	list: specs.map(|(ver, days)| cand(u("json", ver), days)),
	now,
	min_age: 2 * day,
	snapshot: Err(None),
}

view = |r| (r.wanted, r.latest, r.new_series)

# The options of `outdated` as a tuple or the failure text (an `Err` record with a `Bool` crashes `roc test`).
read_view = |words| match Args.parse(words) {
	Err(stop) => Err(Fail.line(stop.fail))
	Ok(args) => match Outdated.read(args) {
		Ok(_) => Ok("ok")
		Err(f) => Err(Fail.line(f))
	}
}

# R-CM6 R-FL5 R-FL7 R-EC2 R-E4 (slice 040): the options of `outdated`. R-CM6 has no operand, so a name (also with a selector) is a usage failure. The checks of `Opts.read` come first (the registry). `Args.parse` rejects the resolve flags (R-FL7:
# `--snapshot`, `--strategy`, `--dry-run`), which `Outdated.read` never sees. `--json`, `--quiet`, `--yes`, `--offline` and `--file` work.
expect {
	no_name = "tln: error[usage]: tln outdated takes no name"
	registry = "tln: error[usage]: --registry 'https://r.example': no registry exists in this version of tln. Use --registry direct."
	rows = [
		(["outdated"], Ok("ok")),
		(["outdated", "--json", "--quiet", "--yes", "--offline"], Ok("ok")),
		(["outdated", "--file", "apps/a/main.roc", "--registry", "direct"], Ok("ok")),
		(["outdated", "json"], Err(no_name)),
		(["outdated", "json@^2"], Err(no_name)),
		(["outdated", "--json", "json", "parser"], Err(no_name)),
		(["outdated", "--registry", "https://r.example"], Err(registry)),
		(["outdated", "--registry", "https://r.example", "json"], Err(registry)),
		(["outdated", "--snapshot", "2026-10-01T00:00:00Z"], Err("tln: error[usage]: flag '--snapshot' is not for 'outdated'")),
		(["outdated", "--strategy", "lowest"], Err("tln: error[usage]: flag '--strategy' is not for 'outdated'")),
		(["outdated", "--dry-run"], Err("tln: error[usage]: flag '--dry-run' is not for 'outdated'")),
	]
	bad = rows.keep_if(|(words, want)| read_view(words) != want).map(|(words, want)| (words, want, read_view(words)))
	dbg bad
	bad == []
}

# R-C1 R-C7 R-C9 R-UP1 R-UP3 R-UP10 R-UP12 R-DI5 R-DI10 (slice 040): `Outdated.versions`, the `wanted` and the `latest` version of one group. `wanted` is the newest release of the group of the header value that the ranges admit.
# `latest` is the newest release of the URL form in any series, with no range. A release that min-release-age or the snapshot hides is no candidate, but the header value always is (R-C9). The order is by version number, not by time.
# The tuple is (wanted, latest, new series).
expect {
	d30 = |vs| vs.map(|v| (v, 30))
	json = ["2.0.0", "2.1.0", "2.2.0", "3.0.2"]
	other_form = cand("https://github.com/acme/json/releases/download/v2.3.0/jsonxv2x3x0.tar.zst", 30)
	snap = |input| { ..input, snapshot: Ok(now - 10 * day) }
	rows = [
		("a range inside the series: the newest in range, and the newest of all series", view(Outdated.versions(ask("2.1.0", ["^2.1"], d30(json)))), ("2.2.0", "3.0.2", Bool.True)),
		("no range (the implied range is the caller's job): the newest of the series", view(Outdated.versions(ask("2.1.0", [], d30(json)))), ("2.2.0", "3.0.2", Bool.True)),
		("an anchor: wanted stays, latest does not", view(Outdated.versions(ask("2.1.0", ["=2.1.0"], d30(json)))), ("2.1.0", "3.0.2", Bool.True)),
		("a tilde range stops below the next minor", view(Outdated.versions(ask("2.1.0", ["~2.1"], d30(["2.1.0", "2.1.5", "2.2.0", "3.0.2"])))), ("2.1.5", "3.0.2", Bool.True)),
		("two ranges are an intersection (R-C1)", view(Outdated.versions(ask("2.1.0", ["^2.1", "<2.2.0"], d30(json)))), ("2.1.0", "3.0.2", Bool.True)),
		("the newest of the series is the newest of all: no new series", view(Outdated.versions(ask("2.1.0", ["^2.1"], d30(["2.1.0", "2.2.0"])))), ("2.2.0", "2.2.0", Bool.False)),
		("a young release is hidden (R-C7): 2.2.0 is 1 day old", view(Outdated.versions(ask("2.1.0", ["^2.1"], [("2.1.0", 30), ("2.2.0", 1), ("3.0.2", 30)]))), ("2.1.0", "3.0.2", Bool.True)),
		("each newer release is young: nothing is newer", view(Outdated.versions(ask("2.1.0", ["^2.1"], [("2.1.0", 30), ("2.2.0", 1), ("3.0.2", 0)]))), ("2.1.0", "2.1.0", Bool.False)),
		("the header value is no candidate to hide (R-C9): it is 1 day old", view(Outdated.versions(ask("2.1.0", ["^2.1"], [("2.1.0", 1)]))), ("2.1.0", "2.1.0", Bool.False)),
		("a release exactly at min-release-age is visible", view(Outdated.versions(ask("2.1.0", ["^2.1"], [("2.1.0", 30), ("2.2.0", 2)]))), ("2.2.0", "2.2.0", Bool.False)),
		("the snapshot hides what is published after it (R-C7): 2.2.0 is 5 days old, the snapshot is 10 days ago", view(Outdated.versions(snap(ask("2.1.0", ["^2.1"], [("2.1.0", 30), ("2.2.0", 5), ("3.0.2", 20)])))), ("2.1.0", "3.0.2", Bool.True)),
		("a release in another URL form is no candidate (R-DI5)", view(Outdated.versions({ ..ask("2.1.0", ["^2.1"], d30(["2.1.0"])), list: [cand(u("json", "2.1.0"), 30), other_form] })), ("2.1.0", "2.1.0", Bool.False)),
		("the current group is the newest: wanted and latest are it (a lower series is no new series)", view(Outdated.versions(ask("3.0.2", [], d30(json)))), ("3.0.2", "3.0.2", Bool.False)),
		("a header value that the list does not have (R-C9) is the base: the list gives the newer release", view(Outdated.versions(ask("2.1.0", ["^2.1"], d30(["2.2.0"])))), ("2.2.0", "2.2.0", Bool.False)),
		("an empty list: the header value", view(Outdated.versions(ask("2.1.0", ["^2.1"], []))), ("2.1.0", "2.1.0", Bool.False)),
		("the order is the version number: 2.10.0 is above 2.9.0 although it is older", view(Outdated.versions(ask("2.0.0", [], [("2.0.0", 90), ("2.9.0", 5), ("2.10.0", 40)]))), ("2.10.0", "2.10.0", Bool.False)),
		("below 1.0 the series is 0.minor: 0.1.1 is wanted and 0.2.0 is a new series", view(Outdated.versions(ask("0.1.0", ["^0.1.0"], d30(["0.1.0", "0.1.1", "0.2.0"])))), ("0.1.1", "0.2.0", Bool.True)),
		("a header value that is no release URL has no versions", view(Outdated.versions({ ..ask("2.1.0", [], d30(json)), current: "./local/main.roc" })), ("", "", Bool.False)),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, want)| (name, got, want))
	dbg bad
	bad == []
}

# R-PB3 R-PB4 R-EP5 R-EP6 R-EP11 R-EF1 (slice 040): `Outdated.range_of` and `Outdated.range_text`, the nightly range from facts that are known. The compiler list D is `n1` to `n6`, oldest first. `ProbeRange.found` gives the range (the rules are in
# `proberange.roc`): an end that is not a real fact has a `?`. No real pass: `none known`. An empty D (the list was not read): `-`, also when facts exist.
expect {
	d = ["n1", "n2", "n3", "n4", "n5", "n6"]
	fact = |hash, id, outcome| { hash, nightly: id, target: "any", outcome, modules: [], closure: "" }
	text = |domain, facts| Outdated.range_text(Outdated.range_of({ hash: "H", domain, facts }))
	rows = [
		("no fact", text(d, []), "none known"),
		("a pass with fails on both sides: both ends are real", text(d, [fact("H", "n2", Fail), fact("H", "n3", Pass), fact("H", "n4", Pass), fact("H", "n5", Fail)]), "n3 .. n4"),
		("one pass, no fail: both ends are unknown", text(d, [fact("H", "n3", Pass)]), "n3? .. n3?"),
		("a pass on each release: the ends of D are real", text(d, [fact("H", "n1", Pass), fact("H", "n2", Pass), fact("H", "n3", Pass), fact("H", "n4", Pass), fact("H", "n5", Pass), fact("H", "n6", Pass)]), "n1 .. n6"),
		("a fail below and no fact above: one end is real", text(d, [fact("H", "n2", Fail), fact("H", "n3", Pass)]), "n3 .. n3?"),
		("only fails: no real pass", text(d, [fact("H", "n3", Fail), fact("H", "n4", Fail)]), "none known"),
		("the facts of another hash are not read", text(d, [fact("G", "n3", Pass), fact("G", "n4", Pass)]), "none known"),
		("a fact of a release that D does not have is not read", text(d, [fact("H", "n9", Pass)]), "none known"),
		("a check fact has the target any: a build fact is not read", text(d, [{ hash: "H", nightly: "n3", target: "x86_64-linux", outcome: Pass, modules: [], closure: "c" }]), "none known"),
		("D is not read: `-` also with facts", text([], [fact("H", "n3", Pass)]), "-"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, want)| (name, got, want))
	dbg bad
	bad == []
}

row = |alias, cur, want, latest, series, range| { alias, name: "acme/${alias}", current: cur, wanted: want, latest, new_series: series, range }

# R-CM6 R-DI11 R-OUT4 R-J3 (slice 040, a proposal, TW24): `Outdated.behind`, `Outdated.text` (the table: a header row, the columns padded to the longest cell and 2 spaces, the last column not padded, ` (new series)` after `latest`, `all packages are
# up to date` for no row, one fixed line for each host) and `Outdated.data` (`--json`).
expect {
	known = Known(Range({ from: { id: "n3", real: Bool.True }, to: { id: "n4", real: Bool.False } }))
	rows = [
		row("json", "2.1.0", "2.2.0", "3.0.2", Bool.True, known),
		row("parser", "1.0.0", "1.0.0", "2.0.0", Bool.True, Unread),
		row("pf", "0.1.0", "0.1.0", "0.1.0", Bool.False, Known(NoPass)),
		row("util", "1.0.0", "1.1.0", "1.1.0", Bool.False, Unread),
	]
	behind = rows.map(|r| Outdated.behind(r))
	table = Outdated.text({ file: "/p/main.roc", rows: rows.keep_if(|r| Outdated.behind(r)), fixed: ["example.org", "x.test"] })
	clean = Outdated.text({ file: "/p/main.roc", rows: [], fixed: ["example.org"] })
	empty = Outdated.text({ file: "/q/main.roc", rows: [], fixed: [] })
	json = Outdated.data([{ file: "/p/main.roc", rows: [row("json", "2.1.0", "2.2.0", "3.0.2", Bool.True, known), row("util", "1.0.0", "1.1.0", "1.1.0", Bool.False, Unread), row("pf", "0.1.0", "0.1.1", "0.1.1", Bool.False, Known(NoPass))], fixed: ["example.org"] }, { file: "/q/main.roc", rows: [], fixed: [] }]).render()
	table_want = "/p/main.roc\n  package  current  wanted  latest              nightly range\n  json     2.1.0    2.2.0   3.0.2 (new series)  n3 .. n4?\n  parser   1.0.0    1.0.0   2.0.0 (new series)  -\n  util     1.0.0    1.1.0   1.1.0               -\n  fixed: example.org has no index without a registry\n  fixed: x.test has no index without a registry\n"
	json_want = "{\"members\":[{\"file\":\"/p/main.roc\",\"packages\":[{\"alias\":\"json\",\"name\":\"acme/json\",\"current\":\"2.1.0\",\"wanted\":\"2.2.0\",\"latest\":\"3.0.2\",\"new_series\":true,\"nightly_range\":{\"state\":\"range\",\"from\":{\"id\":\"n3\",\"real\":true},\"to\":{\"id\":\"n4\",\"real\":false}}},{\"alias\":\"util\",\"name\":\"acme/util\",\"current\":\"1.0.0\",\"wanted\":\"1.1.0\",\"latest\":\"1.1.0\",\"new_series\":false,\"nightly_range\":{\"state\":\"unread\"}},{\"alias\":\"pf\",\"name\":\"acme/pf\",\"current\":\"0.1.0\",\"wanted\":\"0.1.1\",\"latest\":\"0.1.1\",\"new_series\":false,\"nightly_range\":{\"state\":\"no-pass\"}}],\"fixed\":[\"example.org\"]},{\"file\":\"/q/main.roc\",\"packages\":[],\"fixed\":[]}]}"
	dbg [table == table_want, json == json_want]
	behind == [Bool.True, Bool.True, Bool.False, Bool.True] and table == table_want and clean == "/p/main.roc\n  all packages are up to date\n  fixed: example.org has no index without a registry\n" and empty == "/q/main.roc\n  all packages are up to date\n" and json == json_want
}
