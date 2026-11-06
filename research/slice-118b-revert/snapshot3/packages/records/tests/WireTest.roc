import records.Artifact
import records.Closure
import records.Release

WireTest :: [].{}

# W0 tests of Release.roc, Artifact.roc and Closure.roc (slice 104). The JSON is written with ' in place of ", so the text stays readable. The wire names are the design names (R-AP15 to R-AP17, R-AP29, R-AP32) or the proposal of slice 104 section 5.

js : Str -> Str
js = |text| text.replace_each("'", "\"")

form : Str
form = "github.com/roc-lang/unicode/releases/download/{v}/"

release_json : Str
release_json = js("{'log_index':7,'hash':'H1','group':'${form}','series':'4','version':'4.2.0','url':'https://${form.replace_each("{v}", "4.2.0")}H1.tar.zst','tag':'v4.2.0','roc_version':'nightly-2026-10-09-258ab27','repo':'roc-lang/unicode','published_at':1760000000000,'yanked':false,'yank_reason':null,'withdrawn':'edited','provenance':['oidc','ingest']}")

release_row : Release.Row
release_row = {
	log_index: 7,
	hash: "H1",
	group: form,
	series: "4",
	version: "4.2.0",
	url: "https://${form.replace_each("{v}", "4.2.0")}H1.tar.zst",
	tag: Ok("v4.2.0"),
	roc_version: Ok("nightly-2026-10-09-258ab27"),
	repo: Ok("roc-lang/unicode"),
	published_at: 1760000000000,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Ok("edited"),
	provenance: ["oidc", "ingest"],
}

# R-AP49, R-AP50, R-RE2, R-AP15, R-IK1: a release has the group (URL form) and the series as two text fields, the version as text, and the hash as text. A host other than github.com has `repo` null (R-RE2), a missing `.roc-version` is null or missing (R-AP51), and `published_at` is in milliseconds.
expect (Release.decode(release_json) == Ok(release_row)) and (Release.decode(js("{'log_index':8,'hash':'H2','group':'${form}','series':'0.25','version':'0.25.1','url':'u','tag':null,'roc_version':null,'repo':null,'published_at':1000,'yanked':true,'yank_reason':'broken','withdrawn':null,'provenance':['webhook']}")) == Ok({ ..release_row, log_index: 8, hash: "H2", series: "0.25", version: "0.25.1", url: "u", tag: Err(None), roc_version: Err(None), repo: Err(None), published_at: 1000, yanked: Bool.True, yank_reason: Ok("broken"), withdrawn: Err(None), provenance: ["webhook"] }))

expect {
	text = Release.encode({ ..release_row, repo: Err(None) })
	text.contains(js("'group':'${form}'")) and text.contains("\"series\":\"4\"") and text.contains("\"repo\":null") and text.contains("\"yank_reason\":null") and text.contains("\"published_at\":1760000000000") and Release.decode(text) == Ok({ ..release_row, repo: Err(None) })
}

# R-RE1, R-RE19: an artifact with its deps and targets. A dep with no version in its URL has a null version (R-RE19).
artifact_row : Artifact.Row
artifact_row = {
	hash: "H1",
	kind: Package,
	size: 1234,
	exposed: ["Json", "Parser"],
	platform_hash: Err(None),
	roc_pin: Err(None),
	deps: [
		{ alias: "local", hash: "H8", group: "example.org/x/", series: Err(None), version: Err(None), url: "https://example.org/x/H8.tar.zst" },
		{ alias: "semver", hash: "H9", group: "github.com/a/b/releases/download/{v}/", series: Ok("0.2"), version: Ok("0.2.0"), url: "https://github.com/a/b/releases/download/0.2.0/H9.tar.zst" },
	],
	target_names: [],
}

expect {
	text = Artifact.encode(artifact_row)
	text.contains("\"exposed\":[\"Json\",\"Parser\"]") and text.contains("\"platform_hash\":null") and text.contains("\"version\":null") and text.contains("\"size\":1234") and text.contains("\"kind\":\"package\"") and Artifact.decode(text) == Ok(artifact_row)
}
expect {
	with_platform = { ..artifact_row, kind: App, platform_hash: Ok("HP"), roc_pin: Ok("nightly-2026-10-09-258ab27"), target_names: ["wasm32", "x64linux"] }
	Artifact.decode(Artifact.encode(with_platform)) == Ok(with_platform)
}

# R-AP16: the request. `series`, `range`, `compilers`, `from` and `to` are optional. An absent member is left out of the text (not null). `hashes` can be empty.
request_json : Str
request_json = js("{'groups':[{'group':'${form}','series':'4','range':'^4.1'},{'group':'${form}'}],'hashes':['H1'],'compilers':{'from':'nightly-2026-10-09-258ab27'}}")

request_row : Closure.Request
request_row = {
	groups: [{ group: form, series: Ok("4"), range: Ok("^4.1") }, { group: form, series: Err(None), range: Err(None) }],
	hashes: ["H1"],
	compilers: Ok({ from: Ok("nightly-2026-10-09-258ab27"), to: Err(None) }),
}

expect (Closure.decode_request(request_json) == Ok(request_row)) and (Closure.decode_request(js("{'groups':[],'hashes':[]}")) == Ok({ groups: [], hashes: [], compilers: Err(None) }))

expect {
	text = Closure.encode_request({ ..request_row, groups: [{ group: form, series: Err(None), range: Err(None) }], compilers: Err(None) })
	!text.contains("series") and !text.contains("range") and !text.contains("compilers") and !text.contains("null") and Closure.decode_request(Closure.encode_request(request_row)) == Ok(request_row)
}

# R-AP44: a member that the type does not know is ignored.
expect Closure.decode_request(js("{'groups':[],'hashes':[],'future':{'a':1}}")) == Ok({ groups: [], hashes: [], compilers: Err(None) })

# R-AP16, R-AP17: text that is not JSON is an error.
expect match Closure.decode_request("not json") {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}
expect match Closure.decode_answer("[]") {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

# R-AP17, R-AP29, R-AP32, R-IK7: the answer, with the 9 members of R-AP17 and `repos`. `source`, `result`, `side` and `state` are lower-case text. `checked_at` and `successor` are null when none. `log_size` keeps all its digits above 2^53 (R-IK2 text rule for big integers).
answer_json : Str
answer_json = js("{'artifacts':[],'releases':[${release_json}],'epochs':[{'target':'x64linux','from':'nightly-2026-10-09-258ab27','to':'nightly-2026-10-14-38a3029'}],'runs':[{'hash':'H1','target':'any','source':'bot','result':'fail','error_digest':'e1','from':'nightly-2026-10-09-258ab27','to':'nightly-2026-10-14-38a3029'}],'nearest':[{'hash':'H1','target':'any','source':'author','result':'pass','error_digest':null,'nightly':'nightly-2026-10-01-1111111','side':'before'}],'hints':[{'hash':'H1','nightly':'nightly-2026-10-09-258ab27','target':'x64linux','pass_count':3,'fail_count':0,'crash_count':1}],'log_size':9007199254740993,'unknown':['H7'],'checked':[{'name':'roc-lang/unicode','checked_at':null,'stale':true}],'repos':[{'name':'roc-lang/unicode','state':'moved','successor':'acme/unicode','state_at':1760000001000},{'name':'a/b','state':'active','successor':null,'state_at':5}]}")

answer_row : Closure.Answer
answer_row = {
	artifacts: [],
	releases: [release_row],
	epochs: [{ target: "x64linux", from: "nightly-2026-10-09-258ab27", to: "nightly-2026-10-14-38a3029" }],
	runs: [{ hash: "H1", target: "any", source: Bot, result: Fail, error_digest: Ok("e1"), from: "nightly-2026-10-09-258ab27", to: "nightly-2026-10-14-38a3029" }],
	nearest: [{ hash: "H1", target: "any", source: Author, result: Pass, error_digest: Err(None), nightly: "nightly-2026-10-01-1111111", side: Before }],
	hints: [{ hash: "H1", nightly: "nightly-2026-10-09-258ab27", target: "x64linux", pass_count: 3, fail_count: 0, crash_count: 1 }],
	log_size: 9007199254740993,
	unknown: ["H7"],
	checked: [{ name: "roc-lang/unicode", checked_at: Err(None), stale: Bool.True }],
	repos: [
		{ name: "roc-lang/unicode", state: Moved, successor: Ok("acme/unicode"), state_at: 1760000001000 },
		{ name: "a/b", state: Active, successor: Err(None), state_at: 5 },
	],
}

expect Closure.decode_answer(answer_json) == Ok(answer_row)

expect {
	text = Closure.encode_answer(answer_row)
	names = ["'log_size':9007199254740993", "'source':'bot'", "'result':'fail'", "'side':'before'", "'state':'moved'", "'checked_at':null", "'successor':null", "'error_digest':'e1'", "'pass_count':3"]
	names.all(|n| text.contains(js(n))) and Closure.decode_answer(text) == Ok(answer_row)
}

# R-AP17: the closed sets have the wire values of the design only (R-AP17 `runs`). An unknown `result` or `state` is an error.
expect match Closure.decode_answer(answer_json.replace_first(js("'result':'fail'"), js("'result':'maybe'"))) {
	Err(_) => Bool.True
	Ok(_) => Bool.False
}

# R-AP49: on encode the deps are sorted by alias and the target names are sorted (same bytes for the same state, R-AP24).
expect {
	unsorted = { ..artifact_row, kind: Platform, deps: artifact_row.deps.rev(), target_names: ["x64linux", "arm64mac", "wasm32"] }
	text = Artifact.encode(unsorted)
	Artifact.decode(text) == Ok({ ..unsorted, deps: artifact_row.deps, target_names: ["arm64mac", "wasm32", "x64linux"] }) and text.contains("\"target_names\":[\"arm64mac\",\"wasm32\",\"x64linux\"]") and Artifact.encode(artifact_row) == Artifact.encode({ ..artifact_row, deps: artifact_row.deps.rev() })
}

# R-AP49, R-AP51: `kind` is a closed set. An unknown kind, a missing required member and a null required member are BadJson. A missing or null optional member is accepted.
expect {
	good = Artifact.encode(artifact_row)
	is_bad = |t| match Artifact.decode(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	is_bad(good.replace_first("\"kind\":\"package\"", "\"kind\":\"library\"")) and is_bad(good.replace_first("\"size\":1234,", "")) and is_bad(good.replace_first("\"hash\":\"H1\"", "\"hash\":null")) and is_bad(good.replace_first("\"roc_pin\":null,", "")) and is_bad(good.replace_first("\"platform_hash\":null,", "")) and is_bad(good.replace_first("\"series\":null,", "")) and is_bad(good.replace_first(",\"version\":null", "")) and good.replace_first(",\"version\":null", "") != good and Artifact.decode(good.replace_first("\"roc_pin\":null", "\"roc_pin\":null")) == Ok(artifact_row)
}

# R-AP51: a missing required member of a release is BadJson. A missing nullable member of a release is accepted.
expect match Release.decode(release_json.replace_first(js("'hash':'H1',"), "")) {
	Err(BadJson(_)) => Bool.True
	_ => Bool.False
}

# R-AP51: a missing required member is BadJson in a request (`groups`, `hashes`) and in an answer (`log_size`, `artifacts`). `null` for a required member is BadJson. A null optional member (`series`, `compilers`) is accepted.
expect {
	req_bad = |t| match Closure.decode_request(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	ans_bad = |t| match Closure.decode_answer(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	req_bad(js("{'hashes':[]}")) and req_bad(js("{'groups':[]}")) and req_bad(js("{'groups':null,'hashes':[]}")) and ans_bad(answer_json.replace_first(js("'log_size':9007199254740993,"), "")) and ans_bad(answer_json.replace_first(js("'artifacts':[],"), "")) and ans_bad(answer_json.replace_first(js("'log_size':9007199254740993"), js("'log_size':null"))) and Closure.decode_request(js("{'groups':[{'group':'g','series':null,'range':null}],'hashes':[],'compilers':null}")) == Ok({ groups: [{ group: "g", series: Err(None), range: Err(None) }], hashes: [], compilers: Err(None) })
}

# Slice 104b. R-AP29, R-AP32, R-AP50, R-AP51: the items of `checked` and `repos` have their own encoders. The text has the members in alphabetical order, `null` for none, and times in milliseconds.
expect {
	c1 = { name: "roc-lang/unicode", checked_at: Ok(1760000000000), stale: Bool.False }
	c2 = { name: "a/b", checked_at: Err(None), stale: Bool.True }
	Closure.encode_checked(c1) == js("{'checked_at':1760000000000,'name':'roc-lang/unicode','stale':false}") and Closure.encode_checked(c2) == js("{'checked_at':null,'name':'a/b','stale':true}") and Closure.decode_checked(Closure.encode_checked(c1)) == Ok(c1) and Closure.decode_checked(Closure.encode_checked(c2)) == Ok(c2) and Closure.decode_checked(js("{'checked_at':null,'name':'a/b','stale':true,'extra':1}")) == Ok(c2)
}

expect {
	r1 = { name: "roc-lang/unicode", state: Moved, successor: Ok("acme/unicode"), state_at: 1760000001000 }
	r2 = { name: "a/b", state: Active, successor: Err(None), state_at: 5 }
	r3 = { name: "c/d", state: Missing, successor: Err(None), state_at: 0 }
	Closure.encode_repo(r1) == js("{'name':'roc-lang/unicode','state':'moved','state_at':1760000001000,'successor':'acme/unicode'}") and Closure.encode_repo(r2) == js("{'name':'a/b','state':'active','state_at':5,'successor':null}") and [r1, r2, r3].all(|r| Closure.decode_repo(Closure.encode_repo(r)) == Ok(r)) and Closure.decode_repo(js("{'name':'a/b','state':'active','state_at':5,'successor':null}")) == Ok(r2)
}

# Slice 104b, R-AP51: a missing required member, a null required member, a wrong type and an unknown `state` are BadJson in both items.
expect {
	bad_c = |t| match Closure.decode_checked(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	bad_r = |t| match Closure.decode_repo(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	bad_c(js("{'checked_at':null,'name':'a'}")) and bad_c(js("{'name':'a/b','stale':true}")) and bad_c(js("{'checked_at':null,'name':null,'stale':true}")) and bad_c(js("{'checked_at':'x','name':'a','stale':true}")) and bad_c("[]") and bad_r(js("{'name':'a','state':'gone','state_at':1,'successor':null}")) and bad_r(js("{'name':'a','state':'active','successor':null}")) and bad_r(js("{'name':'a','state':'active','state_at':1}")) and bad_r(js("{'name':'a','state':null,'state_at':1,'successor':null}"))
}

# R-AP49, R-AP51: each nullable member is written as `null`, not left out. Release: `tag`, `roc_version`, `repo`, `yank_reason`, `withdrawn`. Artifact: `platform_hash`, `roc_pin`. Dep: `series`, `version`.
expect {
	r = Release.encode({ ..release_row, tag: Err(None), roc_version: Err(None), repo: Err(None), yank_reason: Err(None), withdrawn: Err(None) })
	a = Artifact.encode(artifact_row)
	["\"tag\":null", "\"roc_version\":null", "\"repo\":null", "\"yank_reason\":null", "\"withdrawn\":null"].all(|m| r.contains(m)) and ["\"platform_hash\":null", "\"roc_pin\":null", "\"series\":null", "\"version\":null"].all(|m| a.contains(m)) and Release.decode(r) == Ok({ ..release_row, tag: Err(None), roc_version: Err(None), repo: Err(None), yank_reason: Err(None), withdrawn: Err(None) })
}

# Slice 104c, R-AP58, R-AP51: `error_digest` of a run and of a nearest row is text or `null`. It is a required member: the writer writes `null`, an empty text is a digest, and a missing member is BadJson.
expect {
	run = |d| { hash: "H1", target: "any", source: Bot, result: Pass, error_digest: d, from: "nightly-2026-10-09-258ab27", to: "nightly-2026-10-09-258ab27" }
	near = |d| { hash: "H1", target: "any", source: Author, result: Fail, error_digest: d, nightly: "nightly-2026-10-01-1111111", side: After }
	ans_with = |d| { ..answer_row, runs: [run(d)], nearest: [near(d)] }
	text_null = Closure.encode_answer(ans_with(Err(None)))
	text_set = Closure.encode_answer(ans_with(Ok("d9")))
	text_empty = Closure.encode_answer(ans_with(Ok("")))
	(text_null.split_on("\"error_digest\":null").len() == 3) and (text_set.split_on("\"error_digest\":\"d9\"").len() == 3) and (text_empty.split_on("\"error_digest\":\"\"").len() == 3) and Closure.decode_answer(text_null) == Ok(ans_with(Err(None))) and Closure.decode_answer(text_set) == Ok(ans_with(Ok("d9"))) and Closure.decode_answer(text_empty) == Ok(ans_with(Ok("")))
}

expect {
	text = Closure.encode_answer(answer_row)
	no_run = text.replace_first("\"error_digest\":\"e1\",", "")
	no_nearest = text.replace_first("\"error_digest\":null,", "")
	bad = |t| match Closure.decode_answer(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	no_run != text and no_nearest != text and bad(no_run) and bad(no_nearest)
}

# Slice 104c, Q8, R-AP51: a member that is required but can be null must be present. A missing release member (`tag`, `roc_version`, `repo`, `yank_reason`, `withdrawn`) is BadJson, and a null one is accepted.
expect {
	bad = |t| match Release.decode(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	nulls = Release.encode({ ..release_row, tag: Err(None), roc_version: Err(None), repo: Err(None), yank_reason: Err(None), withdrawn: Err(None) })
	members = ["tag", "roc_version", "repo", "yank_reason", "withdrawn"]
	members.all(|m| bad(nulls.replace_first("\"${m}\":null,", "").replace_first(",\"${m}\":null", ""))) and Release.decode(nulls) == Ok({ ..release_row, tag: Err(None), roc_version: Err(None), repo: Err(None), yank_reason: Err(None), withdrawn: Err(None) })
}

# Slice 122, R-AP49 `provenance`, R-AP51, Design Q158: the member is a list of text, always written, between `log_index` and `published_at` (the members are in the order of the names). The list is kept as it is sent.
expect {
	text = Release.encode(release_row)
	four = Release.encode({ ..release_row, provenance: ["oidc", "webhook", "poll", "ingest"] })
	none = Release.encode({ ..release_row, provenance: [] })
	text.contains("\"log_index\":7,\"provenance\":[\"oidc\",\"ingest\"],\"published_at\":1760000000000") and four.contains("\"provenance\":[\"oidc\",\"webhook\",\"poll\",\"ingest\"]") and none.contains("\"provenance\":[]") and Release.decode(text) == Ok(release_row) and Release.decode(four) == Ok({ ..release_row, provenance: ["oidc", "webhook", "poll", "ingest"] }) and Release.decode(none) == Ok({ ..release_row, provenance: [] })
}

# Slice 122, R-AP51, R-AP44: `provenance` is required. A missing member, `null`, a text and a list of numbers are BadJson. A text that the reader does not know is kept (it is not a closed set). An unknown member of the release is ignored.
expect {
	bad = |t| match Release.decode(t) {
		Err(BadJson(_)) => Bool.True
		_ => Bool.False
	}
	good = Release.encode(release_row)
	no_member = good.replace_first(",\"provenance\":[\"oidc\",\"ingest\"]", "").replace_first("\"provenance\":[\"oidc\",\"ingest\"],", "")
	no_member != good and bad(no_member) and bad(good.replace_first("[\"oidc\",\"ingest\"]", "null")) and bad(good.replace_first("[\"oidc\",\"ingest\"]", "\"oidc\"")) and bad(good.replace_first("[\"oidc\",\"ingest\"]", "[1,2]")) and Release.decode(good.replace_first("[\"oidc\",\"ingest\"]", "[\"oidc\",\"future\"]")) == Ok({ ..release_row, provenance: ["oidc", "future"] }) and Release.decode(good.replace_first("\"published_at\"", "\"future\":1,\"published_at\"")) == Ok(release_row)
}

# Slice 122, R-AP17, R-AP49: the releases of the closure answer have the member too, one list for each release.
expect {
	text = Closure.encode_answer({ ..answer_row, releases: [release_row, { ..release_row, log_index: 8, provenance: ["poll"] }] })
	text.contains("\"log_index\":7,\"provenance\":[\"oidc\",\"ingest\"]") and text.contains("\"log_index\":8,\"provenance\":[\"poll\"]") and Closure.decode_answer(text) == Ok({ ..answer_row, releases: [release_row, { ..release_row, log_index: 8, provenance: ["poll"] }] })
}
