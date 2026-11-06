import lib.ClosureRequest

ClosurerequestTest :: [].{}

# Slice 205 (docs/slices/205-closure-request.md). Pure: the body of POST /v1/closure from the resolve request.

h_cli = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"

h_json = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

cli_url = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/${h_cli}.tar.zst"

json_url = "https://github.com/someone/roc-json/releases/download/2.1.0/${h_json}.tar.zst"

# A URL of a package that has no version in it, and a path entry: neither gives a hash (R-ID7).
odd_url = "https://example.com/pkg/latest.tar.gz"

g_cli = "github.com/roc-lang/basic-cli/releases/download/{v}/"

g_json = "github.com/someone/roc-json/releases/download/{v}/"

groups = [
	{ group: g_cli, series: Ok("0.25"), range: Err(None) },
	{ group: g_json, series: Err(None), range: Ok(">=2.1.0, <3.0.0") },
]

# The compiler list (R-AP5 rows) in an order that is not the order of the dates. `now` is 2026-10-14 10:00 UTC, the tags are published at 10:00 UTC of their date.
n1 = "nightly-2026-10-01-1111111"

n2 = "nightly-2026-10-05-2222222"

n3 = "nightly-2026-10-09-3333333"

n4 = "nightly-2026-10-13-4444444"

rows = [
	{ id: n3, published_at: 1791540000, log_index: 3 },
	{ id: n1, published_at: 1790848800, log_index: 1 },
	{ id: n4, published_at: 1791885600, log_index: 4 },
	{ id: n2, published_at: 1791194400, log_index: 2 },
]

two_days = 172800

free = { rows, nightly: Bool.True, req: Err(Unset), now: 1791972000, min_age: two_days, exclude: [], snapshot: None }

# The compilers member of the request for a window.
compilers_of = |window| ClosureRequest.request({ groups: [], entries: [], window }).map_ok(|r| r.compilers)

win = |from, to| Ok(Ok({ from: Ok(from), to: Ok(to) }))

# R-AP16, R-ID7, R-DI1 (registry part), R-AP60: the groups as given, the hash of each entry that is a release URL (in the order of the entries, a repeat kept), no window for `tln probe --range`.
# A path entry and a URL with no version give no hash. The body text has the members in the order of the codec of `records` and leaves out an absent optional member.
expect {
	entries = [cli_url, "../lib/main.roc", odd_url, json_url, cli_url]
	req = ClosureRequest.request({ groups, entries, window: None })
	req_ok = req == Ok({ groups, hashes: [h_cli, h_json, h_cli], compilers: Err(None) })
	text_ok = ClosureRequest.body({ groups, entries: [cli_url], window: None }) == Ok("{\"groups\":[{\"group\":\"${g_cli}\",\"series\":\"0.25\"},{\"group\":\"${g_json}\",\"range\":\">=2.1.0, <3.0.0\"}],\"hashes\":[\"${h_cli}\"]}")
	# A project with no group and no entry is a valid request.
	empty_ok = ClosureRequest.body({ groups: [], entries: [], window: None }) == Ok("{\"groups\":[],\"hashes\":[]}")
	req_ok and text_ok and empty_ok
}

# R-AP16, R-AP60 (the held compiler): from = to = the pin as it is in the header, a nightly of the list, a nightly that the registry does not list, or a release. The list is not read.
expect {
	listed = compilers_of(Held(n2)) == win(n2, n2)
	not_listed = compilers_of(Held("nightly-2026-11-01-abcdef0")) == win("nightly-2026-11-01-abcdef0", "nightly-2026-11-01-abcdef0")
	release = compilers_of(Held("0.1.0")) == win("0.1.0", "0.1.0")
	body = ClosureRequest.body({ groups: [], entries: [], window: Held(n2) }) == Ok("{\"compilers\":{\"from\":\"${n2}\",\"to\":\"${n2}\"},\"groups\":[],\"hashes\":[]}")
	listed and not_listed and release and body
}

# R-AP16 (a free nightly), R-NS1, R-NS3, R-C7: the oldest and the newest compiler of the domain, in the order of the dates, not of the list. The default `min-release-age` (2 days) hides the nightly of 1 day ago.
expect {
	default = compilers_of(Free(free)) == win(n1, n3)
	no_age = compilers_of(Free({ ..free, min_age: 0 })) == win(n1, n4)
	# R-C15 (as used): a pattern of `min-release-age-exclude` keeps the young nightly visible. A pattern for another name does not.
	excluded = compilers_of(Free({ ..free, exclude: ["roc-lang/nightlies"] })) == win(n1, n4)
	other_pattern = compilers_of(Free({ ..free, exclude: ["roc-lang/roc"] })) == win(n1, n3)
	one = compilers_of(Free({ ..free, rows: [{ id: n2, published_at: 1791194400, log_index: 2 }] })) == win(n2, n2)
	default and no_age and excluded and other_pattern and one
}

# R-NS7, R-C7 (snapshot), R-DT3, R-DT4: the `[toolchain] roc` range limits the oldest end. A time snapshot hides a compiler that is published after it, a log snapshot hides a row with a log index above N.
expect {
	at_least = compilers_of(Free({ ..free, req: Ok(">=${n2}") })) == win(n2, n3)
	exactly = compilers_of(Free({ ..free, req: Ok("=${n2}") })) == win(n2, n2)
	time = compilers_of(Free({ ..free, snapshot: Time(1791194400) })) == win(n1, n2)
	log = compilers_of(Free({ ..free, min_age: 0, snapshot: Log(3) })) == win(n1, n3)
	log_and_range = compilers_of(Free({ ..free, min_age: 0, req: Ok(">=${n2}"), snapshot: Log(2) })) == win(n2, n2)
	at_least and exactly and time and log and log_and_range
}

# R-AP61, R-NS2, R-NS7: no compiler stays, so the client has no window to send: `Err(NoCompiler)`, for each reason. What it sends then is question Q3 of the slice file.
# The list has nightlies only (R-AP57 step 1): the switch off (R-NS2) and a semver range (R-NS7: releases only) leave nothing.
expect {
	switch_off = compilers_of(Free({ ..free, nightly: Bool.False })) == Err(NoCompiler)
	semver = compilers_of(Free({ ..free, req: Ok("0.1.*") })) == Err(NoCompiler)
	all_young = compilers_of(Free({ ..free, now: 1790848800 })) == Err(NoCompiler)
	snapshot_before = compilers_of(Free({ ..free, snapshot: Time(1) })) == Err(NoCompiler)
	log_zero = compilers_of(Free({ ..free, snapshot: Log(0) })) == Err(NoCompiler)
	empty_list = compilers_of(Free({ ..free, rows: [] })) == Err(NoCompiler)
	body = ClosureRequest.body({ groups: [], entries: [], window: Free({ ..free, nightly: Bool.False }) }) == Err(NoCompiler)
	switch_off and semver and all_young and snapshot_before and log_zero and empty_list and body
}

# R-AP78, R-AP46, R-EC1: the limits are checked before the send, with no split. A count at the limit is valid. Over a limit: exit 1, the message names the item, the count and the limit. The first check is the body, then groups, then hashes.
expect {
	at = { groups: 300, hashes: 1000, bytes: 262144 }
	text = |item, count, limit| "the closure query has ${count} ${item}, over the limit of ${limit}: the project is past what Talon supports now"
	failed = |counts| match ClosureRequest.check(counts) {
		Err(f) => (f.kind.code(), f.message)
		Ok({}) => (0, "")
	}
	valid = ClosureRequest.check(at) == Ok({}) and ClosureRequest.check({ groups: 0, hashes: 0, bytes: 2 }) == Ok({})
	wire_groups = failed({ ..at, groups: 301 }) == (1, text("groups", "301", "300"))
	hashes = failed({ ..at, hashes: 1001 }) == (1, text("hashes", "1001", "1000"))
	bytes = failed({ ..at, bytes: 262145 }) == (1, text("bytes", "262145", "262144"))
	order = failed({ groups: 400, hashes: 2000, bytes: 300000 }) == (1, text("bytes", "300000", "262144")) and failed({ groups: 400, hashes: 2000, bytes: 10 }) == (1, text("groups", "400", "300"))
	valid and wire_groups and hashes and bytes and order
}

# R-AP78, R-AP46, R-SN1: more than 50 short names in one command is exit 2 (usage), 50 is valid.
expect {
	failed = match ClosureRequest.check_shorts(51) {
		Err(f) => (f.kind.code(), f.message)
		Ok({}) => (0, "")
	}
	ClosureRequest.check_shorts(50) == Ok({}) and ClosureRequest.check_shorts(0) == Ok({}) and failed == (2, "51 short names are over the limit of 50: use full names (owner/repo) or run 2 commands")
}
