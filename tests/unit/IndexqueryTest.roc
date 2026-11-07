import lib.Fail
import lib.IndexQuery
import lib.Registry
import "../../worker/wrangler.toml" as wrangler : Str

IndexqueryTest :: [].{}

# Slice 206b (docs/slices/206b-registry-commands.md). Pure: the registry of a run, the groups of the first closure query, the sources of the privacy guard, the snapshot with a registry.
# The failure texts are proposals (R-OUT2, TW24).

forms = "Use direct, an https:// URL, or an http:// URL of 127.0.0.1, [::1] or localhost, with no path."

# The registry of a run as one text: `direct`, the origin, or `<exit code> <the failure line>`.
view = |flag, env, config| match IndexQuery.setting({ flag, env, config }) {
	Ok(Direct) => "direct"
	Ok(Registry(origin)) => origin
	Err(fail) => "${fail.kind.code().to_str()} ${Fail.line(fail)}"
}

# R-RG2 R-RG7 row 7 (Design Q208): the built-in default, in the base URL form.
default_registry = "https://registry.roc-talon.org"

cfg = |text| Ok({ text, at: "/h/.config/talon/config.toml:3" })

# R-RG1 R-RG2: the precedence flag, TALON_REGISTRY, config.toml, then the built-in default, the registry URL (slice 225). The text `direct` is `Direct` at each level.
expect {
	rows = [
		(Err(Unset), Err(Unset), Err(Unset), default_registry),
		(Ok("direct"), Ok("https://env.example"), cfg("https://cfg.example"), "direct"),
		(Ok("https://flag.example"), Ok("https://env.example"), cfg("https://cfg.example"), "https://flag.example"),
		(Err(Unset), Ok("https://env.example"), cfg("https://cfg.example"), "https://env.example"),
		(Err(Unset), Ok("direct"), cfg("https://cfg.example"), "direct"),
		(Err(Unset), Err(Unset), cfg("https://cfg.example"), "https://cfg.example"),
		(Err(Unset), Err(Unset), cfg("direct"), "direct"),
	]
	bad = rows.keep_if(|(f, e, c, want)| view(f, e, c) != want).map(|(f, e, c, _)| view(f, e, c))
	dbg bad
	bad == []
}

# R-RG2 R-RG7 rows 3 and 7 (slice 225): the default is a URL in the base URL form (`Registry.base` keeps it as it is). A user who wants `direct` sets it at any level (the rows above); the default is no `config.toml` text, so it needs no read of the file.
expect {
	view(Err(Unset), Err(Unset), Err(Unset)) == default_registry and Registry.base(default_registry) == Ok(default_registry)
}

# R-RG2 R-CV1 (slice 225): the source of the compiler list of a roc command with no registry setting is the default registry, and `direct` at any level is `Direct`. `kept` and `offline` give the R-IX4 and R-IX6 reads.
expect {
	unset = { flag: Err(Unset), env: Err(Unset), config: Err(Unset), offline: Bool.False, kept: Bool.False }
	got = IndexQuery.list_source(unset)
	direct = IndexQuery.list_source({ ..unset, env: Ok("direct") })
	match (got, direct) {
		(Ok(Registry(r)), Ok(Direct)) => r.origin == default_registry and r.kept == Bool.False
		_ => Bool.False
	}
}

# R-RG8 (slice 225): the base URL form of the default and the Worker setting `AUDIENCE` are one text. The deployed `worker/wrangler.toml` is the source of the setting.
expect {
	wrangler.split_on("\n").contains("AUDIENCE = \"${view(Err(Unset), Err(Unset), Err(Unset))}\"")
}

# R-RG1 R-RG7 row 6 (Design Q439): a valid `--registry` wins, so `TALON_REGISTRY` is not read: a bad value there does not stop the command.
expect {
	rows = [
		(Ok("https://flag.example"), Ok("ftp://127.0.0.1:9"), "https://flag.example"),
		(Ok("direct"), Ok("registry.example.org"), "direct"),
	]
	bad = rows.keep_if(|(f, e, want)| view(f, e, Err(Unset)) != want).map(|(f, e, _)| view(f, e, Err(Unset)))
	dbg bad
	bad == []
}

# R-RG7 rows 1 to 3: the base URL form of the winner (`Registry.base`): lower case, no default port, no trailing `/`; `http` to a loopback host.
expect {
	rows = [
		(Ok("HTTPS://Registry.Example.org:443/"), Err(Unset), "https://registry.example.org"),
		(Err(Unset), Ok("HTTP://LocalHost:9/"), "http://localhost:9"),
		(Ok("http://127.0.0.1:8787"), Err(Unset), "http://127.0.0.1:8787"),
		(Err(Unset), Ok("http://[::1]:80"), "http://[::1]"),
	]
	bad = rows.keep_if(|(f, e, want)| view(f, e, Err(Unset)) != want).map(|(f, e, _)| view(f, e, Err(Unset)))
	dbg bad
	bad == []
}

# R-RG7 row 6, R-EC2: a bad text from `--registry` or `TALON_REGISTRY` is a usage failure (exit 2) that names the source and the text and says the allowed forms (R-RG7 rows 1, 2).
expect {
	rows = [
		(Ok("http://example.org"), Err(Unset), "2 tln: error[usage]: --registry 'http://example.org' is not a registry URL. ${forms}"),
		(Ok("https://r.example/v1"), Err(Unset), "2 tln: error[usage]: --registry 'https://r.example/v1' is not a registry URL. ${forms}"),
		(Err(Unset), Ok("ftp://127.0.0.1:9"), "2 tln: error[usage]: TALON_REGISTRY 'ftp://127.0.0.1:9' is not a registry URL. ${forms}"),
		(Err(Unset), Ok("registry.example.org"), "2 tln: error[usage]: TALON_REGISTRY 'registry.example.org' is not a registry URL. ${forms}"),
	]
	bad = rows.keep_if(|(f, e, want)| view(f, e, Err(Unset)) != want).map(|(f, e, _)| view(f, e, Err(Unset)))
	dbg bad
	bad == []
}

# R-RG7 row 6, R-TF4: a bad text from `config.toml` is an input failure (exit 19) in the form `<path>:<line>: <key>: <why>`. It stops the command as each other key of R-TF4, also when the flag or the variable wins.
expect {
	why = "registry: 'https://user@r.example' is not a registry URL. ${forms}"
	line = "19 tln: error[input]: /h/.config/talon/config.toml:3: ${why}"
	rows = [
		(Err(Unset), Err(Unset), line),
		(Ok("https://flag.example"), Err(Unset), line),
		(Err(Unset), Ok("direct"), line),
	]
	bad = rows.keep_if(|(f, e, want)| view(f, e, cfg("https://user@r.example")) != want).map(|(f, e, _)| view(f, e, cfg("https://user@r.example")))
	dbg bad
	bad == []
}

# A scoped variable for `groups`. `hold` is Free, Held or Movable.
scoped = |form, series, ranges, hold, any_series| {
	variable: { group: { form, series }, name: Ok("acme/x"), is_platform: Bool.False, host: Indexed, patched: Bool.False, uses: [], ranges: ranges.map(|r| { range: r, from: "implied by main.roc" }) },
	free: hold == Free,
	movable: hold == Movable,
	any_series,
	note: Err(None),
}

gj = "github.com/acme/json/releases/download/{v}/"

gp = "github.com/acme/parser/releases/download/{v}/"

gf = "github.com/acme/pfx/releases/download/{v}/"

# R-AP16 R-DI1 R-SP23 R-ID2: one group for each free variable, in the order of the variables, with its series and its range. A held and a movable variable give no group (the first query does not hold the movable groups).
expect {
	got = IndexQuery.groups([
		scoped(gj, "2", [">=2.0.0, <3.0.0"], Free, Bool.False),
		scoped(gp, "1", [">=1.0.0, <2.0.0"], Held, Bool.False),
		scoped(gf, "0.1", [">=0.1.0, <0.2.0"], Movable, Bool.False),
		scoped(gp, "2", [">=2.0.0, <3.0.0"], Free, Bool.False),
	])
	got == [
		{ group: gj, series: Ok("2"), range: Ok(">=2.0.0, <3.0.0") },
		{ group: gp, series: Ok("2"), range: Ok(">=2.0.0, <3.0.0") },
	]
}

# R-AP16 R-AP74 row 3 R-SP5 R-UP3: `any_series` sends no series (all series of the form). 2 ranges are one text (the distinct ranges, joined with `, `); `*` is dropped; no range left gives no `range`.
expect {
	got = IndexQuery.groups([
		scoped(gj, "2", ["^3"], Free, Bool.True),
		scoped(gp, "1", [">=1.0.0, <2.0.0", "^1.2", ">=1.0.0, <2.0.0"], Free, Bool.False),
		scoped(gf, "0.1", ["*"], Free, Bool.False),
		scoped(gf, "0.2", [], Free, Bool.True),
	])
	got == [
		{ group: gj, series: Err(None), range: Ok("^3") },
		{ group: gp, series: Ok("1"), range: Ok(">=1.0.0, <2.0.0, ^1.2") },
		{ group: gf, series: Ok("0.1"), range: Err(None) },
		{ group: gf, series: Err(None), range: Err(None) },
	]
}

# R-AP16: no free variable, no group (`tln update X` with X held by another rule is not this case; an empty list is the empty body member).
expect IndexQuery.groups([scoped(gj, "2", [], Held, Bool.False)]) == []

json_url = "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst"

pf_url = "https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst"

# R-RG4: the guard checks each name that the query carries: the groups in order, then the URL of each entry that gives a hash, in the order of the entries. A path entry and a text with no hash carry no name.
expect {
	got = IndexQuery.sources({
		groups: [{ group: gj, series: Ok("2"), range: Err(None) }, { group: gf, series: Err(None), range: Err(None) }],
		entries: [pf_url, "../lib/main.roc", json_url, "https://example.org/lib.tar.br"],
	})
	got == [Group(gj), Group(gf), Url(pf_url), Url(json_url)]
}

# R-RG4: a query with no group still carries the hashes of the header.
expect IndexQuery.sources({ groups: [], entries: [json_url] }) == [Url(json_url)]

# The snapshot as one text.
snap = |registry, flag, config| match IndexQuery.snapshot({ registry, flag, config }) {
	Ok(None) => "none"
	Ok(Time(t)) => "time ${t.to_str()}"
	Ok(Log(n)) => "log ${n.to_str()}"
	Err(fail) => "${fail.kind.code().to_str()} ${Fail.line(fail)}"
}

# R-DT3 R-FL9 R-EV1 R-AP19: with a registry the log form is valid (flag or `[resolution] snapshot`); the flag wins over the key. No flag and no key: none.
expect {
	rows = [
		(Bool.True, Ok("log:30"), Err(Unset), "log 30"),
		(Bool.True, Err(Unset), Ok(Log(7)), "log 7"),
		(Bool.True, Ok("log:5"), Ok(Log(7)), "log 5"),
		(Bool.True, Ok("log:5"), Ok(Time(1791763200)), "log 5"),
		(Bool.True, Err(Unset), Err(Unset), "none"),
		(Bool.False, Err(Unset), Err(Unset), "none"),
	]
	bad = rows.keep_if(|(r, f, c, want)| snap(r, f, c) != want).map(|(r, f, c, _)| snap(r, f, c))
	dbg bad
	bad == []
}

# R-DT3 R-DT4 R-EC2: the time form works in both modes; the log form with `direct` is the usage failure of `Intent.direct_snapshot`; a text that is neither is the usage failure of `--snapshot`.
expect {
	direct_log = "2 tln: error[usage]: snapshot log:30 needs a registry: direct has no log. Use a UTC time, for example 2026-10-12T00:00:00Z."
	rows = [
		(Bool.True, Ok("2026-10-12T00:00:00Z"), Err(Unset), "time 1791763200"),
		(Bool.False, Ok("2026-10-12T00:00:00Z"), Ok(Log(7)), "time 1791763200"),
		(Bool.True, Err(Unset), Ok(Time(1791763200)), "time 1791763200"),
		(Bool.False, Ok("log:30"), Err(Unset), direct_log),
		(Bool.False, Err(Unset), Ok(Log(30)), direct_log),
		(Bool.True, Ok("log:x"), Err(Unset), "2 tln: error[usage]: --snapshot 'log:x' is not a UTC time or log:<n>. Use a UTC time, for example 2026-10-12T00:00:00Z."),
		(Bool.True, Ok("yesterday"), Err(Unset), "2 tln: error[usage]: --snapshot 'yesterday' is not a UTC time or log:<n>. Use a UTC time, for example 2026-10-12T00:00:00Z."),
	]
	bad = rows.keep_if(|(r, f, c, want)| snap(r, f, c) != want).map(|(r, f, c, _)| snap(r, f, c))
	dbg bad
	bad == []
}

# Slice 206d2 (docs/slices/206d2-update-held-move.md). A scoped variable with one use of `url`.
used = |url, hold| {
	base = scoped(gf, "0.1", [">=0.1.0, <0.2.0"], hold, Bool.False)
	{ ..base, variable: { ..base.variable, uses: [{ file: "/p/main.roc", alias: "pf", url, version: "0.1.0" }] } }
}

other_url = "https://github.com/acme/pfx/releases/download/0.1.0/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst"

# R-SP23 R-DI11 R-AP28: a fixed anchor (a header URL of `anchors`) is never movable. Only `movable` changes; a free anchor stays free. A variable with another URL stays movable. The order stays.
expect {
	got = IndexQuery.held_anchors({ scoped: [used(pf_url, Movable), used(other_url, Movable), used(pf_url, Free), used(pf_url, Held)], anchors: [pf_url] })
	want = [used(pf_url, Held), used(other_url, Movable), used(pf_url, Free), used(pf_url, Held)]
	got == want
}

# R-SP23: no anchor, no change.
expect {
	list = [used(pf_url, Movable), used(other_url, Free)]
	IndexQuery.held_anchors({ scoped: list, anchors: [] }) == list
}

# R-AP16 (second query) R-SP23 R-SP24 R-DI1 R-AP74 row 3: the second query holds one group for each movable variable, in the order of the variables, with its series and its ranges (the function of `groups`). A free and a held variable give none.
expect {
	got = IndexQuery.second_groups([
		scoped(gj, "2", [">=2.0.0, <3.0.0"], Free, Bool.False),
		scoped(gf, "0.1", [">=0.1.0, <0.2.0", "^0.1.0"], Movable, Bool.False),
		scoped(gp, "1", [">=1.0.0, <2.0.0"], Held, Bool.False),
		scoped(gp, "2", ["*"], Movable, Bool.False),
		scoped(gj, "3", [], Movable, Bool.True),
	])
	got == [
		{ group: gf, series: Ok("0.1"), range: Ok(">=0.1.0, <0.2.0, ^0.1.0") },
		{ group: gp, series: Ok("2"), range: Err(None) },
		{ group: gj, series: Err(None), range: Err(None) },
	]
}

# R-AP16 (second query) R-SP23: no movable variable (only free and held ones), no group. A movable variable with no name (a path or another host has no group) gives none.
expect {
	noname = scoped(gf, "0.1", [], Movable, Bool.False)
	nameless = { ..noname, variable: { ..noname.variable, name: Err(NoName) } }
	IndexQuery.second_groups([scoped(gj, "2", [], Free, Bool.False), scoped(gp, "1", [], Held, Bool.False), nameless]) == []
}

# A variable for `report_groups` (slice 206e2).
var_of = |form, series, host, name| { group: { form, series }, name, is_platform: Bool.False, host, patched: Bool.False, uses: [], ranges: [{ range: "^2.0.0", from: "talon.toml:2" }] }

# R-AP16 R-CM6 R-UP1 R-DI1 R-DI11 R-AP74 (slice 206e2): `tln outdated` asks one group for each indexed variable with a name, in the order of the variables, with no series and no range (the `latest` column needs every series and every release).
# A `Fixed` host and a variable with no name give none. Two series of one form give one group.
expect {
	got = IndexQuery.report_groups([
		var_of(gj, "2", Indexed, Ok("acme/json")),
		var_of(gf, "0.1", Indexed, Ok("acme/pfx")),
		var_of("example.org/acme/other/releases/download/{v}/", "1", Fixed("example.org"), Ok("example.org/acme/other")),
		var_of(gj, "3", Indexed, Ok("acme/json")),
		var_of(gp, "1", Indexed, Err(NoName)),
	])
	got == [
		{ group: gj, series: Err(None), range: Err(None) },
		{ group: gf, series: Err(None), range: Err(None) },
	]
}

# R-AP16 R-DI1: no variable, no group.
expect IndexQuery.report_groups([]) == []
