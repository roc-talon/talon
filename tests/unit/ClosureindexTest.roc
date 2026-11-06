import lib.ClosureIndex

ClosureindexTest :: [].{}

# Slice 206 (docs/slices/206-closure-index.md). Pure: the closure answer (records.Closure.Answer) as the index of one command.

h_json1 = "2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp"

h_json2 = "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN"

h_json3 = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"

h_cli = "4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN"

h_other = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"

h_dep = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"

json_url = |version, hash| "https://github.com/Someone/roc-json/releases/download/${version}/${hash}.tar.zst"

cli_url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${h_cli}.tar.zst"

dep_url = "https://github.com/someone/roc-dep/releases/download/1.0.0/${h_dep}.tar.zst"

g_json = "github.com/Someone/roc-json/releases/download/{v}/"

# A release row of the answer (R-AP49). `published_at` is in milliseconds (R-AP50).
rel = |url, hash, version, repo, ms| {
	log_index: 1,
	hash,
	group: g_json,
	series: "1",
	version,
	url,
	tag: Ok(version),
	roc_version: Err(None),
	repo,
	published_at: ms,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Err(None),
	provenance: ["webhook"],
}

art = |hash, kind, size, deps| { hash, kind, exposed: [], platform_hash: Err(None), roc_pin: Err(None), size, deps, target_names: [] }

dep_item = { alias: "dep", hash: h_dep, is_platform: Bool.False, group: "github.com/someone/roc-dep/releases/download/{v}/", series: Ok("1"), version: Ok("1.0.0"), url: dep_url }

releases = [
	rel(json_url("1.0.0", h_json1), h_json1, "1.0.0", Ok("someone/roc-json"), 1790848800000),
	{ ..rel(json_url("1.1.0", h_json2), h_json2, "1.1.0", Ok("someone/roc-json"), 1791194400000), tag: Err(None) },
	{ ..rel(json_url("2.0.0", h_json3), h_json3, "2.0.0", Ok("someone/roc-json"), 1791540000000), withdrawn: Ok("deleted") },
	{ ..rel(cli_url, h_cli, "0.25.0", Ok("roc-lang/basic-cli"), 1791540000000), group: "github.com/roc-lang/basic-cli/releases/download/{v}/", series: "0.25" },
	{ ..rel("https://example.com/x/1.0.0/${h_other}.tar.zst", h_other, "1.0.0", Err(None), 1791540000000), group: "example.com/x/{v}/" },
]

artifacts = [
	art(h_json1, Package, 1200, []),
	art(h_json2, Package, 3400, [dep_item]),
	{ ..art(h_cli, Platform, 9000000, []), target_names: ["linux_x86_64", "macos_apple_silicon"] },
]

answer = { artifacts, releases, epochs: [], runs: [], nearest: [], hints: [], log_size: 40, unknown: [], checked: [{ name: "someone/roc-json", checked_at: Ok(1791540000000), stale: Bool.False }], repos: [] }

view = |list| list.map(|c| (c.url, c.tag, c.published_at, c.size, c.ident.version))

# R-AP17, R-AP49 (reader), R-AP50, R-DI14: the candidates of a name come from the release rows whose `repo` is the name in lower case, in the order of the rows.
# `published_at` milliseconds become seconds, a null `tag` is "", `size` is the size of the artifact record. A withdrawn row is not a candidate. A row of another repo and a row of another host are not.
expect view(ClosureIndex.candidates({ releases, artifacts, name: "Someone/Roc-Json" })) == [
	(json_url("1.0.0", h_json1), "1.0.0", 1790848800, 1200, "1.0.0"),
	(json_url("1.1.0", h_json2), "", 1791194400, 3400, "1.1.0"),
]

# R-AP49: a withdrawn value that Talon does not know is kept as text, and the release is still not a candidate. A row with no artifact record has size 0 (a kept copy of R-AP13 has no artifacts, R-IX6).
expect {
	rows = [{ ..rel(json_url("1.0.0", h_json1), h_json1, "1.0.0", Ok("someone/roc-json"), 1000), withdrawn: Ok("some-new-reason") }, rel(json_url("1.1.0", h_json2), h_json2, "1.1.0", Ok("someone/roc-json"), 2000)]
	view(ClosureIndex.candidates({ releases: rows, artifacts: [], name: "someone/roc-json" })) == [(json_url("1.1.0", h_json2), "1.1.0", 2, 0, "1.1.0")]
}

# R-AP63, R-C9: the rows are not filtered by a range or a series. The release of a header value that is outside the range of the request is still in `releases`, and it stays a candidate (the solver applies the range).
# A row whose URL is not a release URL (no version) is not a candidate.
expect {
	rows = [
		{ ..rel(json_url("3.0.0", h_json3), h_json3, "3.0.0", Ok("someone/roc-json"), 3000), series: "3" },
		rel("https://github.com/Someone/roc-json/releases/download/latest/${h_json1}.tar.zst", h_json1, "1.0.0", Ok("someone/roc-json"), 1000),
	]
	view(ClosureIndex.candidates({ releases: rows, artifacts: [], name: "someone/roc-json" })) == [(json_url("3.0.0", h_json3), "3.0.0", 3, 0, "3.0.0")]
}

# Slice 206d, Design Q461, R-AP28 case 1, R-C9: the header has json 1.0.0 with another hash than the registry's release of that label. The registry's 1.0.0 is dropped, so the pick keeps the header URL.
# json 1.1.0 stays: a header URL with the same hash drops nothing, and another version of the group is not changed.
expect {
	list = ClosureIndex.candidates({ releases, artifacts, name: "Someone/Roc-Json" })
	view(ClosureIndex.drop_labels({ list, known: [json_url("1.0.0", h_other), json_url("1.1.0", h_json2)] })) == [(json_url("1.1.0", h_json2), "", 1791194400, 3400, "1.1.0")]
}

# Slice 206d, Design Q461: a header URL of another group form (`v{v}`) with the version 1.0.0, a URL of another repository, and a path drop nothing.
expect {
	list = ClosureIndex.candidates({ releases, artifacts, name: "Someone/Roc-Json" })
	known = ["https://github.com/Someone/roc-json/releases/download/v1.0.0/${h_other}.tar.zst", cli_url, "/home/me/app/lib/main.roc"]
	view(ClosureIndex.drop_labels({ list, known })) == view(list)
}

# R-AL8 source 2, R-AP17 `artifacts`, R-AP49: the header facts of a release URL from the artifact record of its hash. The deps are the `url` of each item, in the order of the record.
expect {
	got = ClosureIndex.header(answer, json_url("1.1.0", h_json2))
	match got {
		Ok(h) => h.release == { kind: Package, pf: Err(None), deps: [dep_url] } and h.entries == [{ alias: "dep", value: dep_url, is_platform: Bool.False }] and h.target_names == []
		Err(_) => Bool.False
	}
}

# R-AP49 `target_names` (R-RE20): a platform record gives its target names. Kind Platform, no deps.
expect {
	got = ClosureIndex.header(answer, cli_url)
	match got {
		Ok(h) => h.release == { kind: Platform, pf: Err(None), deps: [] } and h.entries == [] and h.target_names == ["linux_x86_64", "macos_apple_silicon"]
		Err(_) => Bool.False
	}
}

# R-AL8: the record is found by the hash of the URL (the hash fixes the facts), also when the URL text differs from the `url` of the release row.
expect {
	other_form = "https://github.com/someone/roc-json/releases/download/v1.0.0/${h_json1}.tar.zst"
	match ClosureIndex.header(answer, other_form) {
		Ok(h) => h.release == { kind: Package, pf: Err(None), deps: [] }
		Err(_) => Bool.False
	}
}

# R-AL8: a hash with no record, and an id that is no release URL (a path file), are not in the answer: the caller reads them from the archive (sources 3 and 4).
expect ClosureIndex.header(answer, json_url("2.0.0", h_json3)).is_err() and ClosureIndex.header(answer, "/home/me/app/lib/main.roc").is_err()

# R-EF1 rank 4, R-AP49 `roc_version`, R-DI14: the hint of a release URL is the `roc_version` of its row, read as a `.roc-version` file (the first line that is not empty, trimmed). Null, no row, or no line: no hint.
expect {
	rows = [
		{ ..rel(json_url("1.0.0", h_json1), h_json1, "1.0.0", Ok("someone/roc-json"), 1000), roc_version: Ok("\n  nightly-2026-10-05-2222222  \nmore") },
		rel(json_url("1.1.0", h_json2), h_json2, "1.1.0", Ok("someone/roc-json"), 2000),
		{ ..rel(cli_url, h_cli, "0.25.0", Ok("roc-lang/basic-cli"), 3000), roc_version: Ok("  \n") },
	]
	a = { ..answer, releases: rows }
	(ClosureIndex.hint(a, json_url("1.0.0", h_json1)), ClosureIndex.hint(a, json_url("1.1.0", h_json2)), ClosureIndex.hint(a, cli_url), ClosureIndex.hint(a, dep_url))
		== (Ok("nightly-2026-10-05-2222222"), Err(None), Err(None), Err(None))
}

# R-AP64, R-AP29: the `checked` item of a repository, by its name in any case. A repository with no item: none.
expect ClosureIndex.checked_of(answer, "Someone/Roc-Json") == Ok({ name: "someone/roc-json", checked_at: Ok(1791540000000), stale: Bool.False }) and ClosureIndex.checked_of(answer, "roc-lang/basic-cli") == Err(None)

# Slice 206c (docs/slices/206c-closure-platform.md). The platform mark of a dep (Design Q251, Q400; Registry R-AP81, R-RE19).
h_pf = "4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN"

h_pf2 = "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN"

h_pkg = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"

pf2_url = "https://github.com/someone/roc-pf2/releases/download/2.0.0/${h_pf2}.tar.zst"

pkg_url = "https://github.com/someone/roc-pkg/releases/download/1.0.0/${h_pkg}.tar.zst"

pf_dep = { alias: "pf", hash: h_pf, is_platform: Bool.True, group: "github.com/roc-lang/basic-cli/releases/download/{v}/", series: Ok("0.25"), version: Ok("0.25.0"), url: cli_url }

pf2_dep = { alias: "pf2", hash: h_pf2, is_platform: Bool.True, group: "github.com/someone/roc-pf2/releases/download/{v}/", series: Ok("2"), version: Ok("2.0.0"), url: pf2_url }

with_deps = |kind, deps| { ..answer, artifacts: [art(h_pkg, kind, 100, deps)] }

# R-AP81, R-RE19, R-C3: a package record with one marked dep. `Release.pf` is the url of the marked dep, and its entry has the mark. The other entry has none. The order of the record stays.
expect {
	match ClosureIndex.header(with_deps(Package, [dep_item, pf_dep]), pkg_url) {
		Ok(h) => h.release == { kind: Package, pf: Ok(cli_url), deps: [dep_url, cli_url] } and h.entries == [{ alias: "dep", value: dep_url, is_platform: Bool.False }, { alias: "pf", value: cli_url, is_platform: Bool.True }]
		Err(_) => Bool.False
	}
}

# R-AP81 (client row): a platform record with a marked dep gives `pf` the same way as a package record.
expect {
	match ClosureIndex.header(with_deps(Platform, [pf_dep]), pkg_url) {
		Ok(h) => h.release.pf == Ok(cli_url) and h.release.kind == Platform and h.entries == [{ alias: "pf", value: cli_url, is_platform: Bool.True }]
		Err(_) => Bool.False
	}
}

# R-AP81 (client row), Design Q400, Q401: the mark in an app record is not read, so an app record gives no `pf` also when a dep has the mark (its platform is `platform_hash`, Design Q128). The deps stay, and every entry flag is false.
expect {
	match ClosureIndex.header(with_deps(App, [dep_item, pf_dep]), pkg_url) {
		Ok(h) => h.release == { kind: App, pf: Err(None), deps: [dep_url, cli_url] } and h.entries.map(|e| e.is_platform) == [Bool.False, Bool.False]
		Err(_) => Bool.False
	}
}

# R-AP81 (client row), Design Q400, Q402: 2 marked deps (a registry that breaks the rule). The first mark in the order of the answer gives `pf`. Only its entry has the flag: the second marked dep and the plain dep have false.
expect {
	match ClosureIndex.header(with_deps(Package, [pf_dep, dep_item, pf2_dep]), pkg_url) {
		Ok(h) => h.release.pf == Ok(cli_url) and h.entries.map(|e| e.is_platform) == [Bool.True, Bool.False, Bool.False]
		Err(_) => Bool.False
	}
}

# R-AP81 (client row), R-AP49 (Dep): no marked dep gives no `pf`, and no entry has the mark.
expect {
	match ClosureIndex.header(with_deps(Package, [dep_item]), pkg_url) {
		Ok(h) => h.release.pf == Err(None) and h.entries.map(|e| e.is_platform) == [Bool.False]
		Err(_) => Bool.False
	}
}
