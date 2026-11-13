import lib.Args
import lib.AuditCheck
import lib.Fail

AuditcheckTest :: [].{}

# Slice 244 (docs/slices/244-audit.md), R-CM14 R-AU1 to R-AU5 R-AU8 to R-AU13 R-AU15 R-PT8 R-OUT2. Pure: the decisions of `tln audit` with a registry (part 244a).
# New names for the code agent (a proposal, TW24; until they exist this file does not compile: red on purpose). Module `AuditCheck` (cli/lib/AuditCheck.roc):
#   `AuditCheck.Reason : [Yanked, AssetReplaced, RepoMissing, ReleaseMissing, Prerelease, Moved, Other(Str)]`
#   `AuditCheck.Entry : { url, name, group, version, hash : Str, alias : Try(Str, [None]), edge : Str, via : List(Str), tool : Try(Str, [None]), members : List(Str), why : Str }`
#   `AuditCheck.Finding : { entry : Entry, reason : Reason, ignored : Try(Str, [None]), since : Try(U64, [None]), yank_reason : Try(Str, [None]), new_hash : Try(Str, [None]), successor : Try(Str, [None]) }`
#   `AuditCheck.Report : { index : [Registry, Direct], checked : U64, findings : List(Finding), unused : List(Str), no_yank_data : Bool, unindexed : List({ name : Str, version : Str, hash : Str }) }` (`unindexed`: slice 244 review, Q-244-4)
#   `AuditCheck.entries : { members : List({ file : Str, walked : Closure.Walked }), tools : List({ key : Str, url : Str }) } -> List(Entry)`
#   `AuditCheck.state_of : { answer : records.Closure.Answer, entry : Entry } -> Try({ row : records.Release.Row, repo : Try(records.Closure.Repo, [None]) }, [NotIndexed])`
#   `AuditCheck.reason_of : { row : records.Release.Row, repo : Try(records.Closure.Repo, [None]) } -> Try(Reason, [None])`
#   `AuditCheck.finding : { entry : Entry, row : records.Release.Row, repo : Try(records.Closure.Repo, [None]) } -> Try(Finding, [None])`
#   `AuditCheck.of_answer : { answer : records.Closure.Answer, entries : List(Entry) } -> { checked : U64, findings : List(Finding), unindexed : List(Entry) }`
#   `AuditCheck.reason_text : Reason -> Str`, `AuditCheck.fails : Reason -> Bool`
#   `AuditCheck.parse_item : Str -> Try({ name : Str, version : Str, reason : Str }, [BadItem])`
#   `AuditCheck.read : Args -> Try({ items : List(Str) }, Fail)`   (the operands and the `--ignore` flags, exit 2)
#   `AuditCheck.toml_items : { path : Str, text : Str } -> Try(List(Str), Fail)`   (`[audit] ignore` of the root talon.toml, exit 19)
#   `AuditCheck.ignore : { findings : List(Finding), items : List(Str) } -> { findings : List(Finding), unused : List(Str) }`
#   `AuditCheck.code : List(Finding) -> I32`   (0 or 21)
#   `AuditCheck.fix : Finding -> Str`
#   `AuditCheck.text : Report -> Str`, `AuditCheck.data : Report -> JsonDoc`, `AuditCheck.failure : Report -> Fail`
# Expects marked "Q-244-n" follow the recommended answer of that question of the slice file. If the answer is different, the expect changes.

h_pf = "2r9Lu7UYgi1kKtSUgf4fcvSU2hYjr3h7hGBaYNbpZJFL"

h_json = "532HKEYYDQqzMZhSYLoLRNM98SZvHgQMP3BfwzuyRoMV"

h_parser = "GbwaoZjkLELtS94sHZLdG3xPzyKjWYMhTTWmkEZrYvf1"

h_util = "8vJsgiwWAjcXVatFyZuVru8hP74KeMfBWHiPxGTyFC8U"

h_csv = "cBk3aNj2V9Bkah5N5oWdxXWUPFu7tdMJHbtKwWyM7RU"

h_xml = "7pDrEX5i6rSnPmz39xyi1oQe5Ecz4rhc89537nmcVw23"

h_old = "CWnW9MDhc6peegdvLjPQ9Gp3gMBnwsmdHVcMBbU4CBih"

h_fmt = "9ZhQXvAQ3cvrFKyEzGsNcQw24d2x2rPitgwfEBQqA9ws"

h_web = "9mKnj9JQLeVnum5RynRS4MjBWVi6SRBEuzbFrJ7PpJuW"

h_http1 = "SXwkLwfynSfu5E1xtvdhPKZwLb1tPXG3XcksWCcrxUj"

h_http2 = "Ff6Fu6zwre1eP8rRFRSL3vrGk46qE748ZoJE9M2E3xXv"

form = |name| "github.com/${name}/releases/download/{v}/"

url = |name, version, hash| "https://github.com/${name}/releases/download/${version}/${hash}.tar.zst"

u_pf = url("acme/pfx", "0.1.0", h_pf)

u_json = url("acme/json", "2.1.0", h_json)

u_parser = url("acme/parser", "1.0.2", h_parser)

u_util = url("someone/roc-util", "0.3.0", h_util)

u_csv = url("someone/roc-csv", "1.1.0", h_csv)

u_xml = url("someone/roc-xml", "0.4.0", h_xml)

u_old = url("someone/roc-old", "1.0.0", h_old)

u_fmt = url("acme/fmt", "1.0.0", h_fmt)

u_web = url("acme/web", "1.0.0", h_web)

u_http1 = url("acme/http", "1.4.0", h_http1)

u_http2 = url("acme/http", "2.0.1", h_http2)

# A row of a walk (Closure.Row). `direct` rows have `via` Err(None).
row = |id, alias, name, version, series, via| {
	id,
	kind: Release,
	alias,
	name,
	form: form(name),
	version,
	series,
	direct: via == Err(None),
	via,
	raised: Err(None),
	is_platform: Bool.False,
}

# Member p1: header pf, json, web, csv, xml, old; json needs parser and util; web needs parser too (alias `parse` in the header of web); a path entry and a foreign entry (no hash: not checked).
p1_rows = [
	{ ..row(u_pf, "pf", "acme/pfx", "0.1.0", "0.1", Err(None)), is_platform: Bool.True },
	row(u_json, "json", "acme/json", "2.1.0", "2", Err(None)),
	row(u_web, "web", "acme/web", "1.0.0", "1", Err(None)),
	row(u_csv, "csv", "someone/roc-csv", "1.1.0", "1", Err(None)),
	row(u_xml, "xml", "someone/roc-xml", "0.4.0", "0.4", Err(None)),
	row(u_old, "old", "someone/roc-old", "1.0.0", "1", Err(None)),
	{ id: "/p/lib/main.roc", kind: Path, alias: "lib", name: "./lib/main.roc", form: "", version: "", series: "", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False },
	{ id: "https://example.com/x.tar.zst", kind: Foreign, alias: "x", name: "https://example.com/x.tar.zst", form: "", version: "", series: "", direct: Bool.True, via: Err(None), raised: Err(None), is_platform: Bool.False },
	row(u_parser, "parser", "acme/parser", "1.0.2", "1", Ok("json")),
	row(u_util, "util", "someone/roc-util", "0.3.0", "0.3", Ok("json")),
]

p1_links = [
	{ from: Err(Header), alias: "pf", to: u_pf },
	{ from: Err(Header), alias: "json", to: u_json },
	{ from: Err(Header), alias: "web", to: u_web },
	{ from: Err(Header), alias: "csv", to: u_csv },
	{ from: Err(Header), alias: "xml", to: u_xml },
	{ from: Err(Header), alias: "old", to: u_old },
	{ from: Err(Header), alias: "lib", to: "/p/lib/main.roc" },
	{ from: Err(Header), alias: "x", to: "https://example.com/x.tar.zst" },
	{ from: Ok(u_json), alias: "parser", to: u_parser },
	{ from: Ok(u_json), alias: "util", to: u_util },
	{ from: Ok(u_web), alias: "parse", to: u_parser },
]

p1 = { file: "/p/main.roc", walked: { rows: p1_rows, links: p1_links } }

view = |e| (e.hash, e.alias, e.edge, e.via, e.tool, e.members, e.why)

# R-AU1 R-PT8 R-SC15: the hashes that `tln audit` checks. Each `Release` row of the walk of the member (the header entries and the deps of each package header, to the end), in the order of the walk. A path entry and a foreign entry have no hash:
# no entry. A header entry has its alias and `via` []. A transitive entry has `alias` Err(None), `edge` the alias of the first edge that names it, and `via` every header alias whose paths reach it (the order of the header links).
# The hash of the `url` of each project tool is an entry (only that hash, R-PT8: the closure of a tool is in its own header), after the rows, with `tool` the key of `[tools]`. `why` is the name of R-SC15 for the fix text (R-AU8).
expect {
	got = AuditCheck.entries({ members: [p1], tools: [{ key: "fmt", url: u_fmt }] }).map(view)
	want = [
		(h_pf, Ok("pf"), "pf", [], Err(None), ["/p/main.roc"], "acme/pfx"),
		(h_json, Ok("json"), "json", [], Err(None), ["/p/main.roc"], "acme/json"),
		(h_web, Ok("web"), "web", [], Err(None), ["/p/main.roc"], "acme/web"),
		(h_csv, Ok("csv"), "csv", [], Err(None), ["/p/main.roc"], "someone/roc-csv"),
		(h_xml, Ok("xml"), "xml", [], Err(None), ["/p/main.roc"], "someone/roc-xml"),
		(h_old, Ok("old"), "old", [], Err(None), ["/p/main.roc"], "someone/roc-old"),
		(h_parser, Err(None), "parser", ["json", "web"], Err(None), ["/p/main.roc"], "acme/parser"),
		(h_util, Err(None), "util", ["json"], Err(None), ["/p/main.roc"], "someone/roc-util"),
		(h_fmt, Err(None), "fmt", [], Ok("fmt"), [], "acme/fmt"),
	]
	dbg got
	got == want
}

# R-AU1: the other fields of an entry: `url` (the selected URL), `name` (the full name, R-SC7), `group` (the URL form), `version`.
expect {
	got = AuditCheck.entries({ members: [p1], tools: [{ key: "fmt", url: u_fmt }] }).map(|e| (e.url, e.name, e.group, e.version))
	want = [
		(u_pf, "acme/pfx", form("acme/pfx"), "0.1.0"),
		(u_json, "acme/json", form("acme/json"), "2.1.0"),
		(u_web, "acme/web", form("acme/web"), "1.0.0"),
		(u_csv, "someone/roc-csv", form("someone/roc-csv"), "1.1.0"),
		(u_xml, "someone/roc-xml", form("someone/roc-xml"), "0.4.0"),
		(u_old, "someone/roc-old", form("someone/roc-old"), "1.0.0"),
		(u_parser, "acme/parser", form("acme/parser"), "1.0.2"),
		(u_util, "someone/roc-util", form("someone/roc-util"), "0.3.0"),
		(u_fmt, "acme/fmt", form("acme/fmt"), "1.0.0"),
	]
	dbg got
	got == want
}

# R-AU15 R-AU13 (Q-244-5): in a workspace one hash that 2 members use is one entry. `members` has the member files in the order of the members. A header alias of any member makes `alias`; `via` is the union of the `via` of the members
# (order of first appearance). A tool URL that is also a closure hash is one entry (the closure row first, `tool` set).
expect {
	p2 = {
		file: "/p/b/main.roc",
		walked: {
			rows: [
				row(u_web, "web", "acme/web", "1.0.0", "1", Err(None)),
				row(u_json, "js", "acme/json", "2.1.0", "2", Err(None)),
				row(u_parser, "parse", "acme/parser", "1.0.2", "1", Ok("web")),
			],
			links: [
				{ from: Err(Header), alias: "web", to: u_web },
				{ from: Err(Header), alias: "js", to: u_json },
				{ from: Ok(u_web), alias: "parse", to: u_parser },
			],
		},
	}
	got = AuditCheck.entries({ members: [p1, p2], tools: [{ key: "j", url: u_json }] }).keep_if(|e| e.hash == h_json or e.hash == h_parser or e.hash == h_web).map(view)
	want = [
		(h_json, Ok("json"), "json", [], Ok("j"), ["/p/main.roc", "/p/b/main.roc"], "acme/json"),
		(h_web, Ok("web"), "web", [], Err(None), ["/p/main.roc", "/p/b/main.roc"], "acme/web"),
		(h_parser, Err(None), "parser", ["json", "web"], Err(None), ["/p/main.roc", "/p/b/main.roc"], "acme/parser"),
	]
	dbg got
	got == want
}

# R-SC15 R-AU8: when the checked hashes have 2 or more series of one full name, `why` adds the series in the ref form (`acme/http@1`, `acme/http@2`). Else `why` is the full name. The scope is all entries (the members and the tools).
expect {
	p3 = {
		file: "/p/main.roc",
		walked: {
			rows: [
				row(u_http1, "http", "acme/http", "1.4.0", "1", Err(None)),
				row(u_http2, "http2", "acme/http", "2.0.1", "2", Err(None)),
				row(u_json, "json", "acme/json", "2.1.0", "2", Err(None)),
			],
			links: [
				{ from: Err(Header), alias: "http", to: u_http1 },
				{ from: Err(Header), alias: "http2", to: u_http2 },
				{ from: Err(Header), alias: "json", to: u_json },
			],
		},
	}
	got = AuditCheck.entries({ members: [p3], tools: [] }).map(|e| e.why)
	dbg got
	got == ["acme/http@1", "acme/http@2", "acme/json"]
}

# A release row of the closure answer (R-AP49).
rel = |name, version, hash| {
	log_index: 1,
	hash,
	group: form(name),
	series: "1",
	version,
	url: url(name, version, hash),
	tag: Ok(version),
	roc_version: Err(None),
	repo: Ok(name),
	published_at: 1790000000000,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Err(None),
	provenance: ["webhook"],
}

active = |name| { name, state: Active, successor: Err(None), state_at: 1700000000000 }

missing = |name| { name, state: Missing, successor: Err(None), state_at: 1700000000000 }

moved = |name, to| { name, state: Moved, successor: Ok(to), state_at: 1700000000000 }

# R-AU2 (the registry column), R-AU13, R-AP49: the reason of one release row and the `repos` item of its name. No reason: Err(None).
expect {
	r = rel("acme/json", "2.1.0", h_json)
	reason = |row_value, repo| AuditCheck.reason_of({ row: row_value, repo })
	rows = [
		# 1 to 3: no reason. An unyanked release (yanked false) with a reason text of the last yank is not yanked.
		(r, Err(None), Err(None)),
		(r, Ok(active("acme/json")), Err(None)),
		({ ..r, yank_reason: Ok("old reason") }, Ok(active("acme/json")), Err(None)),
		# 4 to 12: one source each.
		({ ..r, yanked: Bool.True }, Err(None), Ok(Yanked)),
		({ ..r, withdrawn: Ok("deleted") }, Err(None), Ok(ReleaseMissing)),
		({ ..r, withdrawn: Ok("unpublished") }, Err(None), Ok(ReleaseMissing)),
		({ ..r, withdrawn: Ok("prereleased") }, Err(None), Ok(Prerelease)),
		({ ..r, withdrawn: Ok("edited") }, Err(None), Ok(Prerelease)),
		({ ..r, withdrawn: Ok("asset-replaced") }, Err(None), Ok(AssetReplaced)),
		({ ..r, withdrawn: Ok("repo-missing") }, Err(None), Ok(RepoMissing)),
		(r, Ok(missing("acme/json")), Ok(RepoMissing)),
		(r, Ok(moved("acme/json", "acme/roc-json")), Ok(Moved)),
		# 13 to 18: R-AU13, the first reason in the order yanked, asset-replaced, repo-missing, release-missing, prerelease, moved.
		({ ..r, yanked: Bool.True, withdrawn: Ok("asset-replaced") }, Err(None), Ok(Yanked)),
		({ ..r, withdrawn: Ok("asset-replaced") }, Ok(missing("acme/json")), Ok(AssetReplaced)),
		({ ..r, withdrawn: Ok("deleted") }, Ok(missing("acme/json")), Ok(RepoMissing)),
		({ ..r, withdrawn: Ok("prereleased") }, Ok(moved("acme/json", "acme/roc-json")), Ok(Prerelease)),
		({ ..r, withdrawn: Ok("deleted") }, Ok(moved("acme/json", "acme/roc-json")), Ok(ReleaseMissing)),
		({ ..r, yanked: Bool.True }, Ok(moved("acme/json", "acme/roc-json")), Ok(Yanked)),
	]
	bad = rows.keep_if(|(a, b, want)| reason(a, b) != want).map(|(a, b, want)| (a.yanked, a.withdrawn, b, want, reason(a, b)))
	dbg bad
	bad == []
}

# R-AU2 R-AP49 (Q-244-3): a `withdrawn` value that this tln does not know is kept as text: reason `Other(<text>)`. It fails, and it comes after `repo-missing` and before `release-missing` in the order of R-AU13.
expect {
	r = rel("acme/json", "2.1.0", h_json)
	a = AuditCheck.reason_of({ row: { ..r, withdrawn: Ok("frozen") }, repo: Err(None) })
	b = AuditCheck.reason_of({ row: { ..r, withdrawn: Ok("frozen") }, repo: Ok(moved("acme/json", "acme/roc-json")) })
	c = AuditCheck.reason_of({ row: { ..r, yanked: Bool.True, withdrawn: Ok("frozen") }, repo: Err(None) })
	d = AuditCheck.reason_of({ row: { ..r, withdrawn: Ok("frozen") }, repo: Ok(missing("acme/json")) })
	a == Ok(Other("frozen")) and b == Ok(Other("frozen")) and c == Ok(Yanked) and d == Ok(RepoMissing)
}

# R-AU2 R-AU3: the text of a reason and the column "Fails".
expect {
	rows = [
		(Yanked, "yanked", Bool.True),
		(AssetReplaced, "asset-replaced", Bool.True),
		(RepoMissing, "repo-missing", Bool.True),
		(ReleaseMissing, "release-missing", Bool.False),
		(Prerelease, "prerelease", Bool.False),
		(Moved, "moved", Bool.False),
		# Q-244-3: an unknown value fails.
		(Other("frozen"), "frozen", Bool.True),
	]
	bad = rows.keep_if(|(r, t, f)| AuditCheck.reason_text(r) != t or AuditCheck.fails(r) != f)
	dbg bad
	bad == []
}

# The entries of p1 and of the tool `fmt`, written out (the first 2 expects check that `AuditCheck.entries` gives them). The fixtures below do not call `AuditCheck`, so a crash in it fails only its expects.
ent = |u, name, version, hash, alias| { url: u, name, group: form(name), version, hash, alias: Ok(alias), edge: alias, via: [], tool: Err(None), members: ["/p/main.roc"], why: name }

p1_entries = [
	ent(u_pf, "acme/pfx", "0.1.0", h_pf, "pf"),
	ent(u_json, "acme/json", "2.1.0", h_json, "json"),
	ent(u_web, "acme/web", "1.0.0", h_web, "web"),
	ent(u_csv, "someone/roc-csv", "1.1.0", h_csv, "csv"),
	ent(u_xml, "someone/roc-xml", "0.4.0", h_xml, "xml"),
	ent(u_old, "someone/roc-old", "1.0.0", h_old, "old"),
	{ ..ent(u_parser, "acme/parser", "1.0.2", h_parser, "parser"), alias: Err(None), via: ["json", "web"] },
	{ ..ent(u_util, "someone/roc-util", "0.3.0", h_util, "util"), alias: Err(None), via: ["json"] },
	{ ..ent(u_fmt, "acme/fmt", "1.0.0", h_fmt, "fmt"), alias: Err(None), tool: Ok("fmt"), members: [] },
]

entry_of = |hash| match p1_entries.find_first(|e| e.hash == hash) {
	Ok(e) => e
	Err(_) => crash "no entry"
}

r_json = { ..rel("acme/json", "2.1.0", h_json), yanked: Bool.True, yank_reason: Ok("parse bug, use 2.1.1") }

r_parser = { ..rel("acme/parser", "1.0.2", h_parser), withdrawn: Ok("asset-replaced") }

r_csv = { ..rel("someone/roc-csv", "1.1.0", h_csv), withdrawn: Ok("repo-missing") }

r_util = { ..rel("someone/roc-util", "0.3.0", h_util), withdrawn: Ok("deleted") }

r_xml = rel("someone/roc-xml", "0.4.0", h_xml)

r_old = { ..rel("someone/roc-old", "1.0.0", h_old), yanked: Bool.True, yank_reason: Err(None) }

answer = {
	artifacts: [],
	releases: [
		rel("acme/pfx", "0.1.0", h_pf),
		# Slice 244 mutation gap G1: the decoys come BEFORE r_json, so a match by hash only, or by hash and version only, finds a decoy.
		# The same hash in another group (another tag form): not the release of the URL.
		{ ..rel("acme/json", "2.1.0", h_json), group: "github.com/acme/json/releases/download/v{v}/", url: "https://github.com/acme/json/releases/download/v2.1.0/${h_json}.tar.zst", yanked: Bool.False },
		# The same hash and group at another version (one asset released under 2 tags; the label is (group, version), Registry R-RE2 unique index): not the release of the URL.
		{ ..rel("acme/json", "2.1.1", h_json), yanked: Bool.False },
		r_json,
		rel("acme/web", "1.0.0", h_web),
		r_parser,
		r_util,
		r_csv,
		r_xml,
		r_old,
		# An older release of json (another hash): not in the closure.
		{ ..rel("acme/json", "2.0.0", h_pf), yanked: Bool.True },
	],
	epochs: [],
	runs: [],
	nearest: [],
	hints: [],
	log_size: 40,
	unknown: [h_fmt],
	checked: [],
	repos: [active("acme/pfx"), active("acme/json"), active("acme/web"), active("acme/parser"), missing("someone/roc-csv"), active("someone/roc-util"), moved("someone/roc-xml", "acme/roc-xml"), active("someone/roc-old")],
}

# R-AU1 R-AP17 R-AP49 R-AP32: the release of an entry is the row with the hash, the group (URL form) and the version of the entry; its `repos` item is the item whose `name` is the `repo` of the row (lower case). A hash with no such row: Err(NotIndexed).
expect {
	json = AuditCheck.state_of({ answer, entry: entry_of(h_json) })
	xml = AuditCheck.state_of({ answer, entry: entry_of(h_xml) })
	fmt = AuditCheck.state_of({ answer, entry: entry_of(h_fmt) })
	upper = AuditCheck.state_of({ answer: { ..answer, repos: [{ ..active("Acme/JSON"), state: Moved, successor: Ok("acme/roc-json") }] }, entry: entry_of(h_json) })
	json == Ok({ row: r_json, repo: Ok(active("acme/json")) })
		and xml == Ok({ row: r_xml, repo: Ok(moved("someone/roc-xml", "acme/roc-xml")) })
			and fmt == Err(NotIndexed)
				and upper == Ok({ row: r_json, repo: Ok({ ..active("Acme/JSON"), state: Moved, successor: Ok("acme/roc-json") }) })
}

# R-AU2 R-AU13 R-OUT2: the fields of a finding. `since` is the `state_at` of the `repos` item for `repo-missing` and `moved` (the time of that state), else Err(None) (the closure answer has no time of a yank or a withdraw).
# `yank_reason` is the reason of the yank for `yanked`. `successor` is the successor of the `repos` item, for any reason (R-AU13). `new_hash` is Err(None) with a registry (the answer does not give the new asset hash). `ignored` is Err(None).
expect {
	f = |hash, row_value, repo| AuditCheck.finding({ entry: entry_of(hash), row: row_value, repo })
	json = f(h_json, r_json, Ok(active("acme/json")))
	csv = f(h_csv, r_csv, Ok(missing("someone/roc-csv")))
	xml = f(h_xml, r_xml, Ok(moved("someone/roc-xml", "acme/roc-xml")))
	yanked_moved = f(h_json, r_json, Ok(moved("acme/json", "acme/roc-json")))
	none = f(h_pf, rel("acme/pfx", "0.1.0", h_pf), Ok(active("acme/pfx")))
	base = |hash, reason| { entry: entry_of(hash), reason, ignored: Err(None), since: Err(None), yank_reason: Err(None), new_hash: Err(None), successor: Err(None) }
	json == Ok({ ..base(h_json, Yanked), yank_reason: Ok("parse bug, use 2.1.1") })
		and csv == Ok({ ..base(h_csv, RepoMissing), since: Ok(1700000000000) })
			and xml == Ok({ ..base(h_xml, Moved), since: Ok(1700000000000), successor: Ok("acme/roc-xml") })
				and yanked_moved == Ok({ ..base(h_json, Yanked), yank_reason: Ok("parse bug, use 2.1.1"), successor: Ok("acme/roc-json") })
					and none == Err(None)
}

# R-AU1 R-AU2 (Q-244-4): the findings of a closure answer, in the order of the entries. `checked` counts the entries that have a release in the answer. An entry with no release (`unknown`, another host) is in `unindexed`, is not counted, and gives no finding.
expect {
	entries = AuditCheck.entries({ members: [p1], tools: [{ key: "fmt", url: u_fmt }] })
	got = AuditCheck.of_answer({ answer, entries })
	got.checked == 8
		and got.findings.map(|x| (x.entry.hash, x.reason)) == [(h_json, Yanked), (h_csv, RepoMissing), (h_xml, Moved), (h_old, Yanked), (h_parser, AssetReplaced), (h_util, ReleaseMissing)]
			and got.unindexed.map(|e| e.hash) == [h_fmt]
}

# R-AU9 R-AU12 R-SC7 (Q-244-3 for the reason form): an ignore item is `<full name>@<version>:<reason>`. The full name has a `/` (`owner/repo`, or `host/path`), the version is `X.Y.Z`, the reason is not empty and is a-z, 0-9 and `-`, starting with a letter.
# The name is kept as written (the match is case-insensitive, below). A reason that tln does not know is valid (a new `withdrawn` value, R-AU2), so an older item keeps working.
expect {
	rows = [
		("roc-lang/json@2.1.0:yanked", Ok({ name: "roc-lang/json", version: "2.1.0", reason: "yanked" })),
		("Acme/JSON@2.1.0:asset-replaced", Ok({ name: "Acme/JSON", version: "2.1.0", reason: "asset-replaced" })),
		("example.com/x/lib@1.0.0:moved", Ok({ name: "example.com/x/lib", version: "1.0.0", reason: "moved" })),
		("someone/roc-old@1.0.0:frozen", Ok({ name: "someone/roc-old", version: "1.0.0", reason: "frozen" })),
		("roc-lang/json@2.1.0", Err(BadItem)),
		("roc-lang/json:yanked", Err(BadItem)),
		("json@2.1.0:yanked", Err(BadItem)),
		("roc-lang/@2.1.0:yanked", Err(BadItem)),
		("/json@2.1.0:yanked", Err(BadItem)),
		("@2.1.0:yanked", Err(BadItem)),
		("roc-lang/json@2.1:yanked", Err(BadItem)),
		("roc-lang/json@^2.1.0:yanked", Err(BadItem)),
		("roc-lang/json@2.1.0-rc1:yanked", Err(BadItem)),
		("roc-lang/json@2.1.0:", Err(BadItem)),
		("roc-lang/json@2.1.0:Yanked", Err(BadItem)),
		("roc-lang/json@2.1.0:yanked ", Err(BadItem)),
		(" roc-lang/json@2.1.0:yanked", Err(BadItem)),
		("", Err(BadItem)),
	]
	bad = rows.keep_if(|(t, want)| AuditCheck.parse_item(t) != want).map(|(t, want)| (t, want, AuditCheck.parse_item(t)))
	dbg bad
	bad == []
}

# R-CM14 R-AU9 R-AU12 R-FL7 (TW24 texts): the line of `tln audit`. No operand. `--ignore <item>` can occur more than once, in the order of the line. An item that does not parse: exit 2 (kind `Usage`).
expect {
	read = |words| match Args.parse(words) {
		Ok(args) => AuditCheck.read(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	bad_item = |t| Err(Fail.new(Usage, "--ignore: '${t}' is not <full name>@<version>:<reason>, for example roc-lang/json@2.1.0:yanked"))
	rows = [
		(["audit"], Ok({ items: [] })),
		(["audit", "--json", "--quiet", "--file", "p/main.roc"], Ok({ items: [] })),
		(["audit", "--ignore", "acme/json@2.1.0:yanked"], Ok({ items: ["acme/json@2.1.0:yanked"] })),
		(["audit", "--ignore", "acme/json@2.1.0:yanked", "--json", "--ignore", "someone/roc-csv@1.1.0:repo-missing"], Ok({ items: ["acme/json@2.1.0:yanked", "someone/roc-csv@1.1.0:repo-missing"] })),
		(["audit", "--ignore", "acme/json@2.1.0"], bad_item("acme/json@2.1.0")),
		(["audit", "--ignore", "acme/json@2.1.0:yanked", "--ignore", "json@2.1.0:yanked"], bad_item("json@2.1.0:yanked")),
		(["audit", "json"], Err(Fail.new(Usage, "tln audit takes no operand"))),
	]
	bad = rows.keep_if(|(words, want)| read(words) != want).map(|(words, want)| (words, want, read(words)))
	dbg bad
	bad == []
}

# R-AU9 R-AU12 R-TF4 (TW24 texts; Q-244-6: only `tln audit` reads the table): the key `ignore` of `[audit]` in the root talon.toml. No table or no key: no item. A list of strings: the items in the order of the list.
# Not a list of strings, or an item that does not parse: exit 19 (kind `Input`), with the path and the line of the key.
expect {
	items = |text| AuditCheck.toml_items({ path: "/p/talon.toml", text })
	input = |line, why| Err(Fail.new(Input, "/p/talon.toml:${line}: audit.ignore: ${why}"))
	not_item = |t| "'${t}' is not <full name>@<version>:<reason>, for example roc-lang/json@2.1.0:yanked"
	rows = [
		("", Ok([])),
		("[toolchain]\nnightly = true\n", Ok([])),
		("[audit]\n", Ok([])),
		("[audit]\nignore = []\n", Ok([])),
		("[toolchain]\nnightly = true\n\n[audit]\nignore = [\"acme/json@2.1.0:yanked\", \"someone/roc-csv@1.1.0:repo-missing\"]\n", Ok(["acme/json@2.1.0:yanked", "someone/roc-csv@1.1.0:repo-missing"])),
		("[audit]\nignore = [\n  \"acme/json@2.1.0:yanked\",\n]\n", Ok(["acme/json@2.1.0:yanked"])),
		("[audit]\nignore = \"acme/json@2.1.0:yanked\"\n", input("2", "must be a list of strings")),
		("[audit]\nignore = [1]\n", input("2", "must be a list of strings")),
		("# team\n[audit]\n\nignore = [\"acme/json@2.1.0:yanked\", \"json@2.1.0:yanked\"]\n", input("4", not_item("json@2.1.0:yanked"))),
	]
	bad = rows.keep_if(|(text, want)| items(text) != want).map(|(text, want)| (text, want, items(text)))
	dbg bad
	bad == []
}

f_json = { entry: entry_of(h_json), reason: Yanked, ignored: Err(None), since: Err(None), yank_reason: Ok("parse bug, use 2.1.1"), new_hash: Err(None), successor: Err(None) }

f_parser = { entry: entry_of(h_parser), reason: AssetReplaced, ignored: Err(None), since: Err(None), yank_reason: Err(None), new_hash: Err(None), successor: Err(None) }

f_csv = { entry: entry_of(h_csv), reason: RepoMissing, ignored: Err(None), since: Ok(1700000000000), yank_reason: Err(None), new_hash: Err(None), successor: Err(None) }

f_util = { entry: entry_of(h_util), reason: ReleaseMissing, ignored: Err(None), since: Err(None), yank_reason: Err(None), new_hash: Err(None), successor: Err(None) }

f_xml = { entry: entry_of(h_xml), reason: Moved, ignored: Err(None), since: Ok(1700000000000), yank_reason: Err(None), new_hash: Err(None), successor: Ok("acme/roc-xml") }

f_old = { entry: entry_of(h_old), reason: Yanked, ignored: Err(None), since: Err(None), yank_reason: Err(None), new_hash: Err(None), successor: Err(None) }

f_fmt = { entry: entry_of(h_fmt), reason: Yanked, ignored: Err(None), since: Err(None), yank_reason: Ok("bad build"), new_hash: Err(None), successor: Err(None) }

# R-AU9 R-AU10 R-AU11: an item ignores the finding whose full name (case-insensitive, R-AP56), version and reason are those of the item. The finding keeps the item as written in `ignored`. The reason is required: an item of the
# same release with another reason ignores nothing (R-AU9). `unused` has each item that matches no finding, once, in the order of the items. A repeated item is one item.
expect {
	got = AuditCheck.ignore({
		findings: [f_json, f_parser, f_csv],
		items: ["acme/json@2.1.0:yanked", "ACME/Parser@1.0.2:asset-replaced", "acme/json@2.1.0:asset-replaced", "someone/roc-old@1.0.0:yanked", "acme/json@2.1.0:yanked", "someone/roc-csv@1.1.1:repo-missing"],
	})
	got.findings == [{ ..f_json, ignored: Ok("acme/json@2.1.0:yanked") }, { ..f_parser, ignored: Ok("ACME/Parser@1.0.2:asset-replaced") }, f_csv]
		and got.unused == ["acme/json@2.1.0:asset-replaced", "someone/roc-old@1.0.0:yanked", "someone/roc-csv@1.1.1:repo-missing"]
}

# R-AU9 (slice 244 mutation gap G2): an item with the name and the version of a finding but another reason ignores nothing: the finding stays, the item is unused.
expect {
	got = AuditCheck.ignore({ findings: [f_json], items: ["acme/json@2.1.0:asset-replaced"] })
	got.findings == [f_json] and got.unused == ["acme/json@2.1.0:asset-replaced"]
}

# R-AU11 (slice 244 mutation gap G3; TW24: a repeated item prints one unused-ignore note): a repeated item that matches no finding is in `unused` once.
expect {
	got = AuditCheck.ignore({ findings: [], items: ["a/b@1.0.0:yanked", "a/b@1.0.0:yanked"] })
	got.findings == [] and got.unused == ["a/b@1.0.0:yanked"]
}

# R-AU3 R-AU10 R-EC21: exit 21 when a finding that is not ignored fails, else 0. Warnings and ignored findings never fail.
expect {
	ign = |f| { ..f, ignored: Ok("x/y@1.0.0:z") }
	rows = [
		([], 0),
		([f_util, f_xml], 0),
		([f_json], 21),
		([f_util, f_parser], 21),
		([f_csv], 21),
		([ign(f_json), ign(f_parser), ign(f_csv), f_util], 0),
		([ign(f_json), f_csv], 21),
		# Q-244-3
		([{ ..f_util, reason: Other("frozen") }], 21),
	]
	bad = rows.keep_if(|(fs, want)| AuditCheck.code(fs) != want).map(|(fs, want)| (fs.map(|f| f.entry.edge), want))
	dbg bad
	bad == []
}

# R-AU8 R-SC15 R-PU28 (TW24 texts): the fix of a finding (the `fix` field, and the items of the `fix:` line).
# Header entry: `tln update <alias>`; with a successor (any reason) the same command follows it (R-PU28). `asset-replaced` also asks the author. `repo-missing` with no successor: replace the package, or ignore it.
# Transitive entry: update each header entry that needs it (`via`), with `tln why <name of R-SC15>`, or `[overrides]`. A project tool: `tln update --tool <key>` (Q-244-7).
expect {
	rows = [
		(f_json, "tln update json"),
		({ ..f_json, entry: entry_of(h_csv), reason: AssetReplaced }, "ask the author to release a new version, then run tln update csv"),
		(f_csv, "tln remove csv, then tln add another package, or add the item to [audit] ignore"),
		({ ..f_csv, successor: Ok("acme/roc-csv") }, "tln update csv"),
		(f_xml, "tln update xml"),
		(f_util, "tln update json (tln why someone/roc-util), or use [overrides]"),
		(util_header, "tln update util"),
		(f_parser, "tln update json or tln update web (tln why acme/parser), or use [overrides]; ask the author to release a new version"),
		({ ..f_parser, reason: Yanked }, "tln update json or tln update web (tln why acme/parser), or use [overrides]"),
		({ ..f_parser, reason: RepoMissing, successor: Ok("acme/roc-parser") }, "tln update json or tln update web (tln why acme/parser), or use [overrides]"),
		(f_fmt, "tln update --tool fmt"),
	]
	bad = rows.keep_if(|(f, want)| AuditCheck.fix(f) != want).map(|(f, want)| (f.entry.edge, want, AuditCheck.fix(f)))
	dbg bad
	bad == []
}

parser_one = { ..f_parser, entry: { ..entry_of(h_parser), via: ["json"] } }

# util as a header entry (in p1 util is transitive, via json).
util_header = { ..f_util, entry: { ..entry_of(h_util), alias: Ok("util"), via: [] } }

report = {
	index: Registry,
	checked: 14,
	findings: [f_json, parser_one, f_csv, f_util, f_xml, { ..f_old, ignored: Ok("someone/roc-old@1.0.0:yanked") }],
	unused: ["someone/roc-gone@1.0.0:yanked"],
	no_yank_data: Bool.False,
	unindexed: [],
}

# R-AU3 R-AU10 R-AU11 R-OUT2 (TW24: the human text of the design, CLI 3 "Human text of tln audit", with the columns made by a rule). The report on stdout:
# line 1 `audit: <n> packages checked (registry|direct)`; the findings that fail and are not ignored, one row each, in an aligned table (each column is as wide as its longest cell and 2 spaces; the last column is not padded):
# the reason words, `<edge> <version>`, the full name, the detail, `header: <alias>` / `via <aliases>` / `tool: <key>`; then `warning: ` rows for the other findings that are not ignored (2 spaces between the cells, the successor of `moved`);
# then `ignored: <item>` and `unused ignore: <item>`; the count line; the `fix:` line (items for the failing findings and for the findings with a successor that are not ignored); the R-AU4 note last.
expect {
	got = AuditCheck.text(report)
	want = Str.join_with(
		[
			"audit: 14 packages checked (registry)",
			"yanked          json 2.1.0    acme/json        \"parse bug, use 2.1.1\"                header: json",
			"asset replaced  parser 1.0.2  acme/parser      the asset of the header is gone       via json",
			"repo missing    csv 1.1.0     someone/roc-csv  the repository is deleted or private  header: csv",
			"warning: release missing  util 0.3.0  someone/roc-util  via json",
			"warning: moved  xml 0.4.0  someone/roc-xml  successor: acme/roc-xml  header: xml",
			"ignored: someone/roc-old@1.0.0:yanked",
			"unused ignore: someone/roc-gone@1.0.0:yanked",
			"3 findings, 2 warnings, 1 ignored.",
			"fix: json: tln update json. parser: tln update json (tln why acme/parser), or use [overrides]; ask the author to release a new version. csv: tln remove csv, then tln add another package, or add the item to [audit] ignore. xml: tln update xml.",
			"",
		],
		"\n",
	)
	dbg got
	got == want
}

# R-AU2 R-DI15 R-OUT2 (TW24): the detail cell of `asset-replaced` when the index knows the new hash (`direct`, R-DI15): the first 6 characters of each hash. A yank with no reason. A transitive entry with 2 header aliases. A tool. Singular counts.
expect {
	r = {
		index: Direct,
		checked: 2,
		findings: [
			{ ..f_parser, new_hash: Ok(h_web) },
			{ ..f_fmt, yank_reason: Err(None) },
		],
		unused: [],
		no_yank_data: Bool.False,
		unindexed: [],
	}
	got = AuditCheck.text(r)
	want = Str.join_with(
		[
			"audit: 2 packages checked (direct)",
			"asset replaced  parser 1.0.2  acme/parser  GitHub has 9mKnj9..., the header has GbwaoZ...  via json, web",
			"yanked          fmt 1.0.0     acme/fmt     no reason given                                 tool: fmt",
			"2 findings, 0 warnings, 0 ignored.",
			"fix: parser: tln update json or tln update web (tln why acme/parser), or use [overrides]; ask the author to release a new version. fmt: tln update --tool fmt.",
			"",
		],
		"\n",
	)
	one = AuditCheck.text({ ..r, findings: [f_json, f_util] })
	dbg got
	dbg one
	got == want and one.contains("\n1 finding, 1 warning, 0 ignored.\n")
}

# R-AU4 R-C6 (Q-244-1, Q-244-2): the note of no yank data is the last line. `direct`: the text of R-C6. A registry with no yank data (before P3): its own text. No finding: only the first line, the count line and the note.
expect {
	empty = { index: Direct, checked: 3, findings: [], unused: [], no_yank_data: Bool.True, unindexed: [] }
	d = AuditCheck.text(empty)
	g = AuditCheck.text({ ..empty, index: Registry })
	none = AuditCheck.text({ ..empty, index: Registry, no_yank_data: Bool.False })
	d == "audit: 3 packages checked (direct)\n0 findings, 0 warnings, 0 ignored.\nnote: no yank and advisory data without a registry\n"
		and g == "audit: 3 packages checked (registry)\n0 findings, 0 warnings, 0 ignored.\nnote: the registry has no yank and advisory data yet\n"
			and none == "audit: 3 packages checked (registry)\n0 findings, 0 warnings, 0 ignored.\n"
}

# R-OUT2 R-OUT4 R-AU10 R-AU11 R-AU13 (TW24: the catalog row `audit`, with `tool` and `members` added, and `yank` without `by`): the `data` of `--json`. Keys in this order. `notes` are objects with `kind`
# (`no-yank-data`, then one `unused-ignore` for each item). `since` is a UTC time text. `yank` is `{reason}` for `yanked`, else null.
expect {
	r = { ..report, findings: [f_json, parser_one, f_xml], unused: ["someone/roc-old@1.0.0:yanked"], checked: 5, no_yank_data: Bool.True }
	got = AuditCheck.data(r).render()
	want = "{\"index\":\"registry\",\"checked\":5,\"notes\":[{\"kind\":\"no-yank-data\"},{\"kind\":\"unused-ignore\",\"item\":\"someone/roc-old@1.0.0:yanked\"}],\"findings\":[{\"name\":\"acme/json\",\"group\":\"github.com/acme/json/releases/download/{v}/\",\"version\":\"2.1.0\",\"hash\":\"${h_json}\",\"alias\":\"json\",\"via\":[],\"tool\":null,\"members\":[\"/p/main.roc\"],\"reason\":\"yanked\",\"fails\":true,\"ignored\":false,\"since\":null,\"yank\":{\"reason\":\"parse bug, use 2.1.1\"},\"new_hash\":null,\"successor\":null,\"fix\":\"tln update json\"},{\"name\":\"acme/parser\",\"group\":\"github.com/acme/parser/releases/download/{v}/\",\"version\":\"1.0.2\",\"hash\":\"${h_parser}\",\"alias\":null,\"via\":[\"json\"],\"tool\":null,\"members\":[\"/p/main.roc\"],\"reason\":\"asset-replaced\",\"fails\":true,\"ignored\":false,\"since\":null,\"yank\":null,\"new_hash\":null,\"successor\":null,\"fix\":\"tln update json (tln why acme/parser), or use [overrides]; ask the author to release a new version\"},{\"name\":\"someone/roc-xml\",\"group\":\"github.com/someone/roc-xml/releases/download/{v}/\",\"version\":\"0.4.0\",\"hash\":\"${h_xml}\",\"alias\":\"xml\",\"via\":[],\"tool\":null,\"members\":[\"/p/main.roc\"],\"reason\":\"moved\",\"fails\":false,\"ignored\":false,\"since\":\"2023-11-14T22:13:20Z\",\"yank\":null,\"new_hash\":null,\"successor\":\"acme/roc-xml\",\"fix\":\"tln update xml\"}]}"
	ignored = AuditCheck.data({ ..r, findings: [{ ..f_old, ignored: Ok("someone/roc-old@1.0.0:yanked") }], unused: [], no_yank_data: Bool.False }).render()
	dbg got
	got == want and ignored.contains("\"ignored\":true,") and ignored.contains("\"notes\":[],") and ignored.contains("\"yank\":{\"reason\":null}")
}

# R-AU5 R-J4 R-J5 R-EC21 (TW24 message): the failure of a run with exit 21: kind `findings`, the message lists the items of the findings that fail and are not ignored (the form of an ignore item, so a user can copy one),
# and `details` is the `data` of the report (R-AU5: the same form as `data` of exit 0).
expect {
	got = AuditCheck.failure(report)
	want = { ..Fail.new(Findings, "findings that fail: acme/json@2.1.0:yanked, acme/parser@1.0.2:asset-replaced, someone/roc-csv@1.1.0:repo-missing. To accept one, add it to [audit] ignore in talon.toml"), details: Ok(AuditCheck.data(report)) }
	dbg got
	got == want
}

# Q-244-4 (Design Q620) R-AU1 R-OUT2 R-OUT4: a closure hash with no release in the closure answer is not checked. The report has one note for each, in the field `unindexed` of `Report` (NEW: `List({ name : Str, version : Str, hash : Str })`, in the order of the entries).
# Human text (TW24, the text of the code agent, accepted): `note: not checked: <name> <version>: the registry has no release of it`, on stdout, after the `fix:` line and before the R-AU4 note. `--json`: one note `{"kind":"not-indexed","name","version","hash"}` for each, after the `unused-ignore` notes. The exit code does not change.
expect {
	r = { index: Registry, checked: 2, findings: [f_xml], unused: ["someone/roc-old@1.0.0:yanked"], no_yank_data: Bool.True, unindexed: [{ name: "acme/fmt", version: "1.0.0", hash: h_fmt }, { name: "acme/web", version: "1.0.0", hash: h_web }] }
	got = AuditCheck.text(r)
	want = Str.join_with(
		[
			"audit: 2 packages checked (registry)",
			"warning: moved  xml 0.4.0  someone/roc-xml  successor: acme/roc-xml  header: xml",
			"unused ignore: someone/roc-old@1.0.0:yanked",
			"0 findings, 1 warning, 0 ignored.",
			"fix: xml: tln update xml.",
			"note: not checked: acme/fmt 1.0.0: the registry has no release of it",
			"note: not checked: acme/web 1.0.0: the registry has no release of it",
			"note: the registry has no yank and advisory data yet",
			"",
		],
		"\n",
	)
	notes = "\"notes\":[{\"kind\":\"no-yank-data\"},{\"kind\":\"unused-ignore\",\"item\":\"someone/roc-old@1.0.0:yanked\"},{\"kind\":\"not-indexed\",\"name\":\"acme/fmt\",\"version\":\"1.0.0\",\"hash\":\"${h_fmt}\"},{\"kind\":\"not-indexed\",\"name\":\"acme/web\",\"version\":\"1.0.0\",\"hash\":\"${h_web}\"}],"
	data = AuditCheck.data(r).render()
	dbg got
	dbg data
	got == want and data.contains(notes) and AuditCheck.code(r.findings) == 0
}

# ---- Slice 244b (docs/slices/244-audit.md, part 244b): `tln audit` with `direct` (R-AU1, R-AU2 the `direct` column, R-AU4, R-DI2 to R-DI4, R-DI11, R-DI15) and the privacy guard of Design Q620 item 9.
# New names for the code agent (a proposal, TW24; until they exist this file does not compile: red on purpose):
#   `AuditCheck.repos_of : List(Entry) -> List({ owner : Str, repo : Str })`   (the GitHub repositories to list, lower case, each once, in the order of the entries)
#   `AuditCheck.direct_finding : { entry : Entry, list : [NotFound, Pages({ pages : List(Str), redirected : Bool })] } -> Try(Finding, [None, BadPage(U64)])`
#   `AuditCheck.of_lists : { entries : List(Entry), lists : List({ owner : Str, repo : Str, list : [NotFound, Pages({ pages : List(Str), redirected : Bool })] }) } -> Try({ checked : U64, findings : List(Finding), unindexed : List(Entry) }, Fail)`
#   `AuditCheck.of_guarded : { answer : records.Closure.Answer, entries : List(Entry), refused : List(Str) } -> { checked : U64, findings : List(Finding), unindexed : List(Entry) }`   (`of_answer` with the repositories that the guard refused, Q620 item 9)
# Expects marked "Q-244b-n" follow the recommended answer of that question.

# A release object of a GitHub release list page (R-DI3, R-DI4: `tag_name`, `draft`, `prerelease`, `published_at`, `assets`; `html_url` names the repository that answered, Q-244b-1).
gh_release = |name, tag, draft, prerelease, assets| {
	asset_text = Str.join_with(assets.map(|a| "{\"name\":\"${a}\",\"size\":1000,\"browser_download_url\":\"https://github.com/${name}/releases/download/${tag}/${a}\"}"), ",")
	"{\"tag_name\":\"${tag}\",\"draft\":${if draft "true" else "false"},\"prerelease\":${if prerelease "true" else "false"},\"published_at\":\"2026-07-01T12:00:00Z\",\"html_url\":\"https://github.com/${name}/releases/tag/${tag}\",\"assets\":[${asset_text}]}"
}

gh_page = |releases| "[${Str.join_with(releases, ",")}]"

pkg = |hash| "${hash}.tar.zst"

e_json = entry_of(h_json)

pages = |list, redirected| Pages({ pages: list, redirected })

direct = |entry, list| AuditCheck.direct_finding({ entry, list })

d_finding = |entry, reason| { entry, reason, ignored: Err(None), since: Err(None), yank_reason: Err(None), new_hash: Err(None), successor: Err(None) }

# R-AU2 (`direct` column) R-AU13 R-DI3 R-DI4 R-DI15 (Q-244b-1, Q-244b-2): the finding of one entry from the release list of its repository. The release of the entry is the release whose `tag_name` is the tag of the URL (exact).
# `since` is always Err(None) with `direct` (GitHub gives no time of a delete or a replace). No reason: Err(None).
expect {
	other = gh_release("acme/json", "2.0.0", Bool.False, Bool.False, [pkg(h_pf)])
	ok_rel = gh_release("acme/json", "2.1.0", Bool.False, Bool.False, [pkg(h_json)])
	rows = [
		# 1: the list call answers 404: the repository is deleted or private (Design N4).
		(NotFound, Ok(d_finding(e_json, RepoMissing))),
		# 2 to 3: the tag has the header asset: no finding. Other assets do not count (R-DI4).
		(pages([gh_page([other, ok_rel])], Bool.False), Err(None)),
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.False, Bool.False, ["docs.tar.gz", pkg(h_json), "${pkg(h_json)}.intoto.jsonl"])])], Bool.False), Err(None)),
		# 4 to 7: the tag is not in the list (deleted), the list is empty, the tag differs (`v2.1.0` is not `2.1.0`), a draft: `release-missing` (`direct` cannot tell a deleted release from a draft).
		(pages([gh_page([other])], Bool.False), Ok(d_finding(e_json, ReleaseMissing))),
		(pages(["[]"], Bool.False), Ok(d_finding(e_json, ReleaseMissing))),
		(pages([gh_page([gh_release("acme/json", "v2.1.0", Bool.False, Bool.False, [pkg(h_json)])])], Bool.False), Ok(d_finding(e_json, ReleaseMissing))),
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.True, Bool.False, [pkg(h_json)])])], Bool.False), Ok(d_finding(e_json, ReleaseMissing))),
		# 8: `prerelease` true.
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.False, Bool.True, [pkg(h_json)])])], Bool.False), Ok(d_finding(e_json, Prerelease))),
		# 9: a draft that is also a prerelease: `release-missing` comes first (R-AU13).
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.True, Bool.True, [pkg(h_json)])])], Bool.False), Ok(d_finding(e_json, ReleaseMissing))),
		# 10: the tag has one other package asset (R-DI15): `asset-replaced` with the new hash.
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.False, Bool.False, [pkg(h_web)])])], Bool.False), Ok({ ..d_finding(e_json, AssetReplaced), new_hash: Ok(h_web) })),
		# 10b (R-AU13, mutation gap G1): a prerelease with no header asset and one other package asset: `asset-replaced` comes before `prerelease`.
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.False, Bool.True, [pkg(h_web)])])], Bool.False), Ok({ ..d_finding(e_json, AssetReplaced), new_hash: Ok(h_web) })),
		# 11 to 13 (Q-244b-2): no package asset: `asset-replaced`, no new hash. 2 other package assets: `asset-replaced`, no new hash. The header asset and another one (R-DI4: not a candidate): no finding, the bytes of the header are there.
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.False, Bool.False, ["docs.tar.gz"])])], Bool.False), Ok(d_finding(e_json, AssetReplaced))),
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.False, Bool.False, [pkg(h_web), pkg(h_xml)])])], Bool.False), Ok(d_finding(e_json, AssetReplaced))),
		(pages([gh_page([gh_release("acme/json", "2.1.0", Bool.False, Bool.False, [pkg(h_web), pkg(h_json)])])], Bool.False), Err(None)),
		# 14: the tag is on page 2.
		(pages([gh_page([other]), gh_page([ok_rel])], Bool.False), Err(None)),
		# 15 to 17 (Q-244b-1): the list came after a redirect: `moved`. The successor is the `owner/repo` of the `html_url` of the first release of the list; the same name (any case) or no release gives no successor.
		(pages([gh_page([gh_release("acme/roc-json", "2.1.0", Bool.False, Bool.False, [pkg(h_json)])])], Bool.True), Ok({ ..d_finding(e_json, Moved), successor: Ok("acme/roc-json") })),
		(pages([gh_page([gh_release("Acme/JSON", "2.1.0", Bool.False, Bool.False, [pkg(h_json)])])], Bool.True), Ok(d_finding(e_json, Moved))),
		(pages(["[]"], Bool.True), Ok(d_finding(e_json, ReleaseMissing))),
		# 18 to 19: R-AU13 with a redirect: the other reason wins, the finding keeps the successor.
		(pages([gh_page([gh_release("acme/roc-json", "2.1.0", Bool.False, Bool.True, [pkg(h_json)])])], Bool.True), Ok({ ..d_finding(e_json, Prerelease), successor: Ok("acme/roc-json") })),
		(pages([gh_page([gh_release("acme/roc-json", "2.1.0", Bool.False, Bool.False, [pkg(h_web)])])], Bool.True), Ok({ ..d_finding(e_json, AssetReplaced), new_hash: Ok(h_web), successor: Ok("acme/roc-json") })),
		# 20 to 21: a page that is not a JSON array of objects, or a release with no text `tag_name`: `BadPage(n)` (1-based).
		(pages(["{}"], Bool.False), Err(BadPage(1))),
		(pages([gh_page([other]), "[{\"draft\":false}]"], Bool.False), Err(BadPage(2))),
	]
	bad = rows.map_with_index(|(list, want), i| (i + 1, want, direct(e_json, list))).keep_if(|(_, want, got)| got != want)
	dbg bad
	bad == []
}

# R-AU1 R-DI2 R-DI11 (Q-244b-4 for other hosts): the repositories that `direct` lists: the `github.com` repository of each entry (the URL), lower case, each once, in the order of the entries. The header entries and the transitive ones (R-AU1: `audit` also lists transitive groups) and the tools.
# An entry of another host has no list.
expect {
	odd = ent("http://127.0.0.1:9/x/1.0.0/${h_old}.tar.zst", "127.0.0.1:9/x/1.0.0", "1.0.0", h_old, "x")
	upper = ent(url("Acme/JSON", "2.1.0", h_http1), "Acme/JSON", "2.1.0", h_http1, "j2")
	got = AuditCheck.repos_of(p1_entries.concat([odd, upper]))
	want = ["acme/pfx", "acme/json", "acme/web", "someone/roc-csv", "someone/roc-xml", "someone/roc-old", "acme/parser", "someone/roc-util", "acme/fmt"].map(
		|n| match n.split_on("/") {
			[o, r] => { owner: o, repo: r }
			_ => { owner: "", repo: "" }
		},
	)
	dbg got
	got == want
}

# R-AU1 R-AU2 R-DI11 (TW24 proposal for the note of another host): the findings of `direct`, in the order of the entries. `checked` counts the entries with a list (also a 404). An entry of another host, or of a repository with no list, is in `unindexed`.
# A page that is not a list stops the run: kind `Network` (exit 15), the text of `Init` and `FullName` for a bad page.
expect {
	odd = ent("http://127.0.0.1:9/x/1.0.0/${h_old}.tar.zst", "127.0.0.1:9/x/1.0.0", "1.0.0", h_old, "x")
	entries = [entry_of(h_pf), e_json, entry_of(h_csv), odd, entry_of(h_xml)]
	lists = [
		{ owner: "acme", repo: "pfx", list: pages([gh_page([gh_release("acme/pfx", "0.1.0", Bool.False, Bool.False, [pkg(h_pf)])])], Bool.False) },
		{ owner: "acme", repo: "json", list: pages([gh_page([gh_release("acme/json", "2.1.0", Bool.False, Bool.True, [pkg(h_json)])])], Bool.False) },
		{ owner: "someone", repo: "roc-csv", list: NotFound },
	]
	got = AuditCheck.of_lists({ entries, lists })
	bad_page = AuditCheck.of_lists({ entries, lists: [{ owner: "acme", repo: "json", list: pages(["nope"], Bool.False) }] })
	match got {
		Ok(r) =>
			r.checked == 3
				and r.findings.map(|x| (x.entry.hash, x.reason)) == [(h_json, Prerelease), (h_csv, RepoMissing)]
					and r.unindexed.map(|e| e.hash) == [h_old, h_xml]
						and bad_page == Err(Fail.new(Network, "the release list of acme/json (page 1) is not a list of releases"))
		Err(_) => Bool.False
	}
}

# Design Q620 item 9 (Q-244-9): with a registry, a repository that the privacy guard refuses (GitHub 404, no kept public answer) gives a `repo-missing` finding for each entry of it, in the order of the entries, counted in `checked`.
# Its hashes are not in the query, so the answer has no release of them; a refused entry is never `unindexed`. `refused` holds lower-case `owner/repo` names (the form of `PrivacyGuard.repos_to_check`); the entry name matches with any case.
expect {
	no_csv = { ..answer, releases: answer.releases.drop_if(|r| r.hash == h_csv) }
	entries = AuditCheck.entries({ members: [p1], tools: [] })
	got = AuditCheck.of_guarded({ answer: no_csv, entries, refused: ["someone/roc-csv"] })
	plain = AuditCheck.of_answer({ answer: no_csv, entries })
	got.checked == 8
		and got.findings.map(|x| (x.entry.hash, x.reason, x.since)) == [(h_json, Yanked, Err(None)), (h_csv, RepoMissing, Err(None)), (h_xml, Moved, Ok(1700000000000)), (h_old, Yanked, Err(None)), (h_parser, AssetReplaced, Err(None)), (h_util, ReleaseMissing, Err(None))]
			and got.unindexed == []
				and plain.unindexed.map(|e| e.hash) == [h_csv]
}

# R-AU4 R-DI11 R-OUT2 (TW24 proposal): with `direct` the note of an entry with no index has its own text: `note: not checked: <name> <version>: no index without a registry`. The note of no yank data is the text of R-C6.
expect {
	r = { index: Direct, checked: 1, findings: [], unused: [], no_yank_data: Bool.True, unindexed: [{ name: "127.0.0.1:9/x/1.0.0", version: "1.0.0", hash: h_old }] }
	got = AuditCheck.text(r)
	got == "audit: 1 packages checked (direct)\n0 findings, 0 warnings, 0 ignored.\nnote: not checked: 127.0.0.1:9/x/1.0.0 1.0.0: no index without a registry\nnote: no yank and advisory data without a registry\n"
}
