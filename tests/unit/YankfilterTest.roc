import records.Index as WireIndex
import lib.ClosureIndex
import lib.FullName
import lib.Pick
import lib.Selector
import lib.XCmd

YankfilterTest :: [].{}

# Slice 250 (docs/slices/250-yank-filter.md, Design Q630). Pure: the release rows of a registry answer that a pick may use (R-C6, R-C9), and the note of a reused build (R-B3).

h_1 = "2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp"

h_2 = "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN"

h_3 = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"

h_other = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"

json_url = |version, hash| "https://github.com/someone/roc-json/releases/download/${version}/${hash}.tar.zst"

g_json = "github.com/someone/roc-json/releases/download/{v}/"

# A release row of the answer (R-AP49). `published_at` is in milliseconds (R-AP50).
rel = |version, hash, yanked| {
	log_index: 1,
	hash,
	group: g_json,
	series: "1",
	version,
	url: json_url(version, hash),
	tag: Ok(version),
	roc_version: Err(None),
	repo: Ok("someone/roc-json"),
	published_at: 1790848800000,
	yanked,
	yank_reason: if yanked Ok("parse bug") else Err(None),
	withdrawn: Err(None),
	provenance: ["webhook"],
}

rows = [rel("1.0.0", h_1, Bool.False), rel("1.1.0", h_2, Bool.True), rel("1.2.0", h_3, Bool.False)]

versions = |list| list.map(|r| r.version)

# R-C6, R-AP1, R-AP17, R-YK7: a row with `yanked` true is not a row for a pick. The other rows stay, in the order of the rows.
expect versions(ClosureIndex.live({ releases: rows, held: [] })) == ["1.0.0", "1.2.0"]

# R-C9: the value of a header entry stays in the domain of its variable, also when it is yanked (so a hold, the implied range and `tln update` still work). Only that row stays.
expect versions(ClosureIndex.live({ releases: rows, held: [json_url("1.1.0", h_2)] })) == ["1.0.0", "1.1.0", "1.2.0"]

# R-C9, Design Q461: a header URL with the same version and another hash is another value. It does not keep the yanked row.
expect versions(ClosureIndex.live({ releases: rows, held: [json_url("1.1.0", h_other)] })) == ["1.0.0", "1.2.0"]

# R-C9, Design Q461 (mutation gap G1): the label of the held URL must be the label of the row. The same hash with another version, and the same hash and version in another URL form (the tag `v1.1.0`, the group form `v{v}`), hold nothing. Only the URL with the same form, version and hash keeps the yanked row.
expect versions(ClosureIndex.live({ releases: rows, held: [json_url("1.2.0", h_2)] })) == ["1.0.0", "1.2.0"]

expect versions(ClosureIndex.live({ releases: rows, held: [json_url("v1.1.0", h_2)] })) == ["1.0.0", "1.2.0"]

expect versions(ClosureIndex.live({ releases: rows, held: [json_url("1.2.0", h_2), json_url("v1.1.0", h_2), json_url("1.1.0", h_2)] })) == ["1.0.0", "1.1.0", "1.2.0"]

# R-C9: a header value that is not yanked keeps nothing more. A header entry that is a path, and a URL that is no release, hold no row.
expect versions(ClosureIndex.live({ releases: rows, held: [json_url("1.0.0", h_1), "/home/me/app/lib/main.roc", "https://example.com/x.tar.zst"] })) == ["1.0.0", "1.2.0"]

# R-C6: each row is yanked and no header value names one: no row is left (the pick has no candidate for the name).
expect ClosureIndex.live({ releases: [rel("1.1.0", h_2, Bool.True), rel("2.0.0", h_3, Bool.True)], held: [] }) == []

# R-C6, R-AP49: the candidates of the rows that a pick may use. A yanked row is no candidate, a held yanked row is one (`candidates` keeps the order of the rows).
expect {
	list = ClosureIndex.candidates({ releases: ClosureIndex.live({ releases: rows, held: [json_url("1.1.0", h_2)] }), artifacts: [], name: "someone/roc-json" })
	list.map(|c| c.ident.version) == ["1.0.0", "1.1.0", "1.2.0"]
}

expect {
	list = ClosureIndex.candidates({ releases: ClosureIndex.live({ releases: rows, held: [] }), artifacts: [], name: "someone/roc-json" })
	list.map(|c| c.ident.version) == ["1.0.0", "1.2.0"]
}

# R-B3, R-C6, CLI R-AU4: the note of a reused build. `direct` has no yank and advisory data: the note. A registry has the yank data (Design Q629, Q630), and the advisories are P3 with no note: no note.
expect XCmd.reuse_note(Direct) == Ok(XCmd.no_data)

expect XCmd.reuse_note(Registry) == Err(None)

# Design Q630-2 (R-C6, R-IN9 (2), R-AD35 step 5): a version that the user names is not chosen when it is yanked. The one item of the closure query is `NoMatch` (exit 2 with the text of `Add.no_release`), not a fall back to the yanked release.
body = |yanked_11| {
	row = |i, version, hash, yanked| "{\"log_index\":${i.to_str()},\"hash\":\"${hash}\",\"group\":\"${g_json}\",\"series\":\"1\",\"version\":\"${version}\",\"url\":\"${json_url(version, hash)}\",\"tag\":\"${version}\",\"roc_version\":null,\"repo\":\"someone/roc-json\",\"published_at\":1790848800000,\"yanked\":${if yanked "true" else "false"},\"yank_reason\":null,\"withdrawn\":null,\"provenance\":[\"webhook\"]}"
	"{\"releases\":[${row(1.U64, "1.0.0", h_1, Bool.False)},${row(2.U64, "1.1.0", h_2, yanked_11)}],\"checked\":null,\"repos\":[]}"
}

item = |text, range, yanked_11| match WireIndex.decode_releases(body(yanked_11)) {
	Ok(releases) => {
		selector = match Selector.parse(text, Bool.False) {
			Ok(parsed) => Ok(parsed)
			Err(_) => Err(None)
		}
		FullName.closure_item({ releases, selector, text, range })
	}
	Err(_) => Err(NoMatch)
}

expect item("1.1.0", "=1.1.0", Bool.True) == Err(NoMatch)

# The same name with no yank is found (the test is about the yank).
expect item("1.1.0", "=1.1.0", Bool.False) == Ok({ group: g_json, series: Err(None), range: Ok("=1.1.0") })

# Design Q630-3 (R-AD35 step 2, R-C6): each release is yanked and no selector: exit code 2 and the text. No closure query.
expect FullName.each_yanked({ name: "acme/known" }).kind.code() == 2

# Slice 255 (Design Q635): one wording with the R-PU29 text (slice 254): `yanked or withdrawn`, and no successor sentence with no successor.
expect FullName.each_yanked({ name: "acme/known" }).message == "acme/known has no release that Talon can use: each release is yanked or withdrawn."

# Slice 255 (Design Q635): the successor form is the same sentence, then the successor sentence (T1 of slice 254).
expect FullName.each_yanked_moved({ name: "acme/known", successor: "neworg/known" }).message == "acme/known has no release that Talon can use: each release is yanked or withdrawn. Its successor is neworg/known. Run: tln add neworg/known"

# Design Q630-4 (R-C6, R-PH13): the failure of an empty domain counts the yanked rows that the filter dropped. With 0 the text is the old text.
no_range = "no tuple works: json has no release that satisfies ^2 (2 releases, 0 outside the ranges, 0 too new)"

expect Pick.with_yanked({ message: no_range, yanked: 0 }) == no_range

# 3 rows were dropped: the total is 2 + 3, and `3 yanked` follows `too new`. The sum of the 3 counts is the total.
expect Pick.with_yanked({ message: no_range, yanked: 3 }) == "no tuple works: json has no release that satisfies ^2 (5 releases, 0 outside the ranges, 0 too new, 3 yanked)"

expect Pick.with_yanked({ message: "no tuple works: json has no release that satisfies ^5 (4 releases, 4 outside the ranges, 0 too new)", yanked: 1 }) == "no tuple works: json has no release that satisfies ^5 (5 releases, 4 outside the ranges, 0 too new, 1 yanked)"

# All rows were yanked: the list of the pick is empty. The text has `0 outside the ranges, 0 too new`.
expect Pick.with_yanked({ message: "no tuple works: json has no release that satisfies any range (0 releases, 0 outside the ranges, 0 too new)", yanked: 2 }) == "no tuple works: json has no release that satisfies any range (2 releases, 0 outside the ranges, 0 too new, 2 yanked)"

# Other failures are not changed: the kind of R-C4 and "do not fit together" say nothing about the age or the ranges.
expect Pick.with_yanked({ message: "no tuple works: json has no release of the kind package in ^2 (R-C4)", yanked: 2 }) == "no tuple works: json has no release of the kind package in ^2 (R-C4)"

expect Pick.with_yanked({ message: "no tuple works: the releases of json, pf do not fit together (R-C2, R-C3)", yanked: 2 }) == "no tuple works: the releases of json, pf do not fit together (R-C2, R-C3)"
