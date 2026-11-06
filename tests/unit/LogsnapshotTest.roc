import lib.LogSnapshot
import lib.Report

LogsnapshotTest :: [].{}

# Slice 207 (docs/slices/207-log-snapshot.md). Pure: `--snapshot log:N` on a closure answer, the printed log size, the body of the second query.

h1 = "2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp"

h2 = "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN"

h3 = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"

h4 = "4DQvwn8UDgjnLQbitjpB7euqpnQKzr4amMFM6oThgRyN"

g = "github.com/someone/roc-json/releases/download/{v}/"

url = |version, hash| "https://github.com/someone/roc-json/releases/download/${version}/${hash}.tar.zst"

# A release row of the answer (R-AP49) with its log index.
rel = |log_index, version, hash| {
	log_index,
	hash,
	group: g,
	series: "1",
	version,
	url: url(version, hash),
	tag: Ok(version),
	roc_version: Err(None),
	repo: Ok("someone/roc-json"),
	published_at: 1790848800000,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Err(None),
	provenance: ["webhook"],
}

art = |hash| { hash, kind: Package, exposed: [], platform_hash: Err(None), roc_pin: Err(None), size: 100, deps: [], target_names: [] }

answer = {
	artifacts: [art(h1), art(h2), art(h3), art(h4)],
	releases: [rel(10, "1.0.0", h1), rel(30, "1.1.0", h2), rel(31, "1.2.0", h3), rel(50, "1.3.0", h4)],
	epochs: [{ target: "linux_x86_64", from: "nightly-2026-10-01-aaaaaaa", to: "nightly-2026-10-09-bbbbbbb" }],
	runs: [],
	nearest: [],
	hints: [{ hash: h4, nightly: "nightly-2026-10-09-bbbbbbb", target: "linux_x86_64", pass_count: 2, fail_count: 0, crash_count: 0 }],
	log_size: 50,
	unknown: ["zzz"],
	checked: [{ name: "someone/roc-json", checked_at: Ok(1791540000000), stale: Bool.False }],
	repos: [],
}

versions = |a| a.releases.map(|r| (r.version, r.log_index))

hide = |n, keep| versions(LogSnapshot.hide_above(answer, { n, keep }))

# R-AP19: `log:N` hides each release with `log_index` above N. A release with `log_index` = N stays. The order of the rows stays.
expect hide(30, []) == [("1.0.0", 10), ("1.1.0", 30)]

# R-AP19: N below every row hides all releases. N at or above the largest `log_index` hides none.
expect hide(9, []) == [] and hide(50, []) == versions(answer) and hide(900, []) == versions(answer)

# R-AP19, Design Q403, R-C9, R-AP63: a release whose hash is in `keep` (the `hashes` of the request, a header value) stays also above N. The other releases above N are hidden. A kept hash that is below N changes nothing.
expect hide(30, [h4]) == [("1.0.0", 10), ("1.1.0", 30), ("1.3.0", 50)] and hide(30, [h3, h4]) == versions(answer) and hide(30, [h1]) == [("1.0.0", 10), ("1.1.0", 30)]

# R-AP19: `epochs` and `hints` are evidence, not releases: they are not hidden.
# Design Q405: `artifacts`, `unknown`, `checked`, `repos` and `log_size` are not changed either, also with a keep list.
expect {
	one = |hidden| hidden.epochs == answer.epochs and hidden.hints == answer.hints and hidden.artifacts == answer.artifacts and hidden.unknown == answer.unknown and hidden.checked == answer.checked and hidden.repos == answer.repos and hidden.log_size == 50
	one(LogSnapshot.hide_above(answer, { n: 30, keep: [] })) and one(LogSnapshot.hide_above(answer, { n: 9, keep: [h4] }))
}

# R-AP16, R-AP19, Design Q404: the second answer is hidden above the first `log_size`, or above the smaller of it and the N of the user.
expect {
	cut = |user| LogSnapshot.second_cut({ user, first: answer })
	cut(Err(None)) == 50 and cut(Ok(30)) == 30 and cut(Ok(50)) == 50 and cut(Ok(900)) == 50
}

# R-DT5: the printed log size is N of `--snapshot log:N`, else the `log_size` of the first answer.
expect LogSnapshot.printed({ snapshot: Ok(30), first: answer }) == 30 and LogSnapshot.printed({ snapshot: Err(None), first: answer }) == 50

# R-DT5: N is printed as given also when it is above the `log_size` of the answer (the design says N of the snapshot).
expect LogSnapshot.printed({ snapshot: Ok(900), first: answer }) == 900

# R-DT5, R-J3: the text `log:<n>` is the `at` of the line `resolved at log:184467, 4 probes` and the `snapshot` of `--json`. Slice 206d2 (Design Q438, a proposal): `log_size` follows `snapshot` when the run has an answer.
expect {
	at = LogSnapshot.at_text(184467)
	line_ok = Report.resolved_line({ at, log: Ok(184467), probes: 4 }) == "resolved at log:184467, 4 probes"
	out = {
		at,
		log: Ok(184467),
		probes: 4,
		downloads: 0,
		dry_run: Bool.False,
		check: NotRun,
		build: NotRun,
		added: [],
		moved: [],
		kept: [],
		pinned: Err(None),
		toml: [],
		renamed: [],
		notes: [],
		written: [],
	}
	json_ok = Report.data(out).render().starts_with("{\"snapshot\":\"log:184467\",\"log_size\":184467,\"probes\":4,")
	at == "log:184467" and line_ok and json_ok
}

# R-AP16, R-SP24: the second query has the groups that the caller gives, in order, with their series and range. `hashes` is empty. `compilers` is the one of the first query (a window, or none).
expect {
	groups = [
		{ group: g, series: Ok("1"), range: Ok(">=1.1.0, <2.0.0") },
		{ group: "github.com/roc-lang/basic-cli/releases/download/{v}/", series: Err(None), range: Err(None) },
	]
	window = Ok({ from: Ok("nightly-2026-10-01-aaaaaaa"), to: Ok("nightly-2026-10-09-bbbbbbb") })
	LogSnapshot.second_request({ groups, compilers: window }) == { groups, hashes: [], compilers: window } and LogSnapshot.second_request({ groups, compilers: Err(None) }) == { groups, hashes: [], compilers: Err(None) }
}

# R-SP24, R-EP15, R-AL4, Design Q522 (slice 206e3b): the answer of the searches after a held move. `epochs` by target: the second answer replaces the epochs of a target that it lists, a target of the first answer only is kept.
# `hints`: the rows of both, and for one (hash, nightly, target) the row of the second answer. `releases` and `runs` have the rows of the second answer first. The other members are those of the first answer.
expect {
	n1 = "nightly-2026-10-01-aaaaaaa"
	epoch = |target, to| { target, from: n1, to }
	hint = |hash, pass_count, fail_count| { hash, nightly: n1, target: "linux_x86_64", pass_count, fail_count, crash_count: 0 }
	run = |hash| { hash, target: "any", source: Bot, result: Pass, error_digest: Err(None), from: n1, to: n1 }
	first = { ..answer, epochs: [epoch("linux_x86_64", "nightly-2026-10-09-bbbbbbb"), epoch("macos_apple_silicon", "nightly-2026-10-05-ccccccc")], hints: [hint(h1, 1, 0), hint(h2, 0, 2)], runs: [run(h1)], log_size: 50 }
	second = { ..answer, releases: [rel(45, "1.2.5", h3)], epochs: [epoch("linux_x86_64", "nightly-2026-10-12-ddddddd"), epoch("windows_x86_64", "nightly-2026-10-06-eeeeeee")], hints: [hint(h1, 5, 0), hint(h3, 0, 1)], runs: [run(h3)], log_size: 55 }
	m = LogSnapshot.merged({ first, second })
	epochs_ok = m.epochs.len() == 3 and m.epochs.contains(epoch("linux_x86_64", "nightly-2026-10-12-ddddddd")) and m.epochs.contains(epoch("macos_apple_silicon", "nightly-2026-10-05-ccccccc")) and m.epochs.contains(epoch("windows_x86_64", "nightly-2026-10-06-eeeeeee"))
	hints_ok = m.hints.len() == 3 and m.hints.contains(hint(h1, 5, 0)) and m.hints.contains(hint(h2, 0, 2)) and m.hints.contains(hint(h3, 0, 1)) and !m.hints.contains(hint(h1, 1, 0))
	rows_ok = m.releases.map(|r| r.version).take_first(1) == ["1.2.5"] and m.runs == [run(h3), run(h1)] and m.log_size == 50
	epochs_ok and hints_ok and rows_ok
}
