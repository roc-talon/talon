import lib.Ingest
import lib.Problem
import lib.Route
import records.Release
import semver.Semver

IngestTest :: [].{}

# W0 tests of worker/lib/Ingest.roc and of the ingest rows of Route.decide (slice 112, docs/slices/112-ingest.md section 4).
# The ids (R-IK2) and the version columns (R-IK5) were computed with node (crypto SHA-256, BigInt), not with the Roc code: worker/tests/tools/mk-ingest.mjs has the same functions.
# h1, h2, h3 are the base58 of 32 bytes of 1, 2, 3. h31 is the base58 of 31 bytes of 7.

h1 = "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi"

h2 = "8qbHbw2BbbTHBW1sbeqakYXVKRQM8Ne7pLK7m6CVfeR"

h3 = "CktRuQ2mttgRGkXJtyksdKHjUdc2C4TgDzyB98oEzy8"

h31 = "7DUeBUtEcb7nujVZRJmeBju3X1mo6PpnWNtJ9EBhdY"

app_form = "github.com/acme/app/releases/download/{v}/"

lib_form = "github.com/acme/lib/releases/download/{v}/"

nac = |detail| Problem.new(NotACandidate, detail)

# ---- Route.decide: /v1/releases serves GET and POST (R-AP9, R-AP26, R-AP48 rows 1, 2, 5) ----

input = |method, content_type, has_body| { method, segments: ["v1", "releases"], content_type, has_body }

# R-AP9, R-AP48: POST is the ingest, with the media check of a JSON body (row 5); no body is the route's 400. Another method is 405 with Allow GET, POST. GET stays R-AP13.
expect {
	got = [
		Route.decide(input("POST", Ok("application/json"), Bool.True)),
		Route.decide(input("POST", Ok("Application/JSON; charset=UTF-8"), Bool.True)),
		Route.decide(input("POST", Err(NotFound), Bool.False)),
		Route.decide(input("POST", Ok("text/plain"), Bool.True)),
		Route.decide(input("POST", Err(NotFound), Bool.True)),
		Route.decide(input("GET", Err(NotFound), Bool.False)),
		Route.decide(input("PUT", Ok("text/plain"), Bool.True)),
	]
	got
		== [
			Handle(PostRelease),
			Handle(PostRelease),
			Handle(PostRelease),
			Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, got text/plain")),
			Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, but the request has no Content-Type")),
			Handle(GetReleases),
			NotAllowed(Problem.new(MethodNotAllowed, "PUT is not allowed on /v1/releases"), ["GET", "POST"]),
		]
}

# ---- parse_body (R-AP68 row 2, R-AP26, R-AP48 row 6, R-AP51, R-AP44) ----

body = |text| Ingest.parse_body(text.to_utf8())

bad_body = |why| Problem.new(BadRequest, "the body must be a JSON object with the member url (text): ${why}")

# R-AP26: a compat member with a value (also an empty list or an object) needs a token: 401. R-AP51: compat null is no value. R-AP44: other members are ignored.
expect {
	got = [
		body("{\"url\":\"u\"}"),
		body("{\"url\":\"u\",\"compat\":null}"),
		body("{ \"compat\" : null , \"url\" : \"u\" }"),
		body("{\"url\":\"u\",\"compat\":[]}"),
		body("{\"compat\":{\"a\":1},\"url\":\"u\"}"),
		body("{\"url\":\"u\",\"compat\": [{\"result\":\"pass\"}]}"),
	]
	got == [Ok("u"), Ok("u"), Ok("u"), Err(Ingest.compat_needs_token), Err(Ingest.compat_needs_token), Err(Ingest.compat_needs_token)]
}

# R-AP48 row 6, R-AP51: no url, url null, url not text, not an object, not JSON, an empty body: 400 before any D1 call.
expect {
	not_obj = Err(bad_body("the body is not a JSON object with a text member url"))
	got = [body(""), body("{}"), body("{\"url\":null}"), body("{\"url\":5}"), body("[\"u\"]"), body("url=u"), body("\"u\"")]
	got == [Err(bad_body("the body is empty")), not_obj, not_obj, not_obj, not_obj, not_obj, not_obj]
}

# R-AP26 after row 6: a body with compat and no url is a 400 (the parse first)
expect body("{\"compat\":[]}") == Err(bad_body("the body is not a JSON object with a text member url"))

# ---- parse_url (R-PU34 row 4, R-DI5, R-PU6, R-IK2, R-IK5) ----

# R-DI5: the parts as sent, the name in lower case (R-IK2), the group with the tag text around the run (v{v}), the version of the run; 01.2.3 is 1.2.3 (R-IK5).
expect {
	url = "https://github.com/Acme/Roc-Thing/releases/download/v1.2.0/${h1}.tar.zst"
	match Ingest.parse_url(url) {
		Ok(t) =>
			(t.url == url)
				and (t.owner == "Acme")
				and (t.repo == "Roc-Thing")
				and (t.name == "acme/roc-thing")
				and (t.tag == "v1.2.0")
				and (t.hash == h1)
				and (t.form == "github.com/Acme/Roc-Thing/releases/download/v{v}/")
				and (t.version == Semver.new(1, 2, 0))
				and (t.column == { version: "-9223090553288065025", version_text: "" })
		Err(_) => Bool.False
	}
}

expect {
	match Ingest.parse_url("https://github.com/acme/lib/releases/download/01.2.3/${h2}.tar.zst") {
		Ok(t) => t.version == Semver.new(1, 2, 3) and t.form == lib_form and t.tag == "01.2.3"
		Err(_) => Bool.False
	}
}

# R-AP68 row 2, R-PU34 row 4, R-PU40 (Design Q155: another host, also www.github.com and api.github.com), R-DI5, R-PU6: each URL that is not a github.com release asset URL with one version and a hash of 32 bytes is 422 not-a-candidate.
expect {
	urls = [
		"http://github.com/t/r/releases/download/1.0.0/${h1}.tar.zst",
		"https://github.com/t/r/releases/download/1.0.0/${h1}",
		"https://github.com/t/r/releases/download/1.0.0/${h31}.tar.zst",
		"https://github.com/t/r/releases/download/1.0.0/not-base58-0OIl.tar.zst",
		"https://github.com/t/r/releases/tag/1.0.0/${h1}.tar.zst",
		"https://github.com/t/r/x/releases/download/1.0.0/${h1}.tar.zst",
		"https://github.com/t/releases/download/1.0.0/${h1}.tar.zst",
		"https://github.com//r/releases/download/1.0.0/${h1}.tar.zst",
		"https://github.com/t/r/releases/download//${h1}.tar.zst",
		"https://github.com/t/r/releases/download/latest/${h1}.tar.zst",
		"https://github.com/t/r-2.0.0/releases/download/1.0.0/${h1}.tar.zst",
		"https://github.com/t/r/releases/download/0.0.0/${h1}.tar.zst",
		"https://github.com/t/r/releases/download/1.0.0/${h1}.tar.zst?x=1",
		"https://github.com/t/r/releases/download/1.0.0/${h1}.tar.zst#f",
		"https://api.github.com/t/r/releases/download/1.0.0/${h1}.tar.zst",
		"https://gitlab.com/acme/lib/-/releases/1.0.0/downloads/${h1}.tar.zst",
		"https://www.github.com/acme/lib/releases/download/1.0.0/${h1}.tar.zst",
		"",
	]
	urls.all(|u| Ingest.parse_url(u) == Err(Ingest.not_release_url(u)))
}

# ---- the GitHub answers (R-PU31, R-PU32, R-TP5, R-PU6, R-AP44) ----

# R-PU32: only visibility public is public; private and internal are not. Unknown and null members are ignored; a missing member is BadRepo.
expect {
	repo = |vis| "{\"id\":501,\"name\":\"r\",\"description\":null,\"owner\":{\"login\":\"t\",\"id\":9001},\"visibility\":\"${vis}\",\"private\":false}"
	got = [
		Ingest.parse_repo(repo("public")),
		Ingest.parse_repo(repo("private")),
		Ingest.parse_repo(repo("internal")),
		Ingest.parse_repo(repo("Public")),
		Ingest.parse_repo("{\"id\":501,\"owner\":{\"id\":9001}}"),
		Ingest.parse_repo("{\"id\":501,\"visibility\":\"public\"}"),
		Ingest.parse_repo("not json"),
	]
	got
		== [
			Ok({ id: 501, owner_id: 9001, public: Bool.True }),
			Ok({ id: 501, owner_id: 9001, public: Bool.False }),
			Ok({ id: 501, owner_id: 9001, public: Bool.False }),
			Ok({ id: 501, owner_id: 9001, public: Bool.False }),
			Err(BadRepo),
			Err(BadRepo),
			Err(BadRepo),
		]
}

# R-PU6, R-AP50: the release: published_at in ms (2026-10-20T12:00:00Z is 1792497600000, python datetime), null is Err(None), the asset names; a bad time or a missing member is BadRelease.
expect {
	rel = |pub| "{\"tag_name\":\"1.0.0\",\"body\":null,\"draft\":false,\"prerelease\":false,\"published_at\":${pub},\"assets\":[{\"name\":\"a.tar.zst\",\"label\":null,\"size\":3},{\"name\":\"docs.tar.gz\"}]}"
	got = [
		Ingest.parse_release(rel("\"2026-10-20T12:00:00Z\"")),
		Ingest.parse_release(rel("null")),
		Ingest.parse_release(rel("\"2026-10-20T12:00:00+00:00\"")),
		Ingest.parse_release("{\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-20T12:00:00Z\"}"),
		Ingest.parse_release("{\"prerelease\":false,\"published_at\":\"2026-10-20T12:00:00Z\",\"assets\":[]}"),
		Ingest.parse_release("[]"),
	]
	got
		== [
			Ok({ draft: Bool.False, prerelease: Bool.False, published_at: Ok(1792497600000), assets: ["a.tar.zst", "docs.tar.gz"] }),
			Ok({ draft: Bool.False, prerelease: Bool.False, published_at: Err(None), assets: ["a.tar.zst", "docs.tar.gz"] }),
			Err(BadRelease),
			Err(BadRelease),
			Err(BadRelease),
			Err(BadRelease),
		]
}

# ---- candidate (R-PU6, CLI R-DI3, R-DI4) ----

target = |hash| {
	url: "https://github.com/acme/app/releases/download/2.0.0/${hash}.tar.zst",
	owner: "acme",
	repo: "app",
	name: "acme/app",
	tag: "2.0.0",
	hash,
	form: app_form,
	version: Semver.new(2, 0, 0),
	column: { version: "-9222809086901288961", version_text: "" },
}

ghr = |draft, prerelease, published_at, assets| { draft, prerelease, published_at, assets }

# R-DI3: a draft, then a prerelease (a draft first when both). R-DI4: the package assets are <base58 of 32 bytes>.tar.zst only; 0 or 2 or more is not a candidate;
# the one asset must be the asset of the URL. A missing published_at of a published release is 502. Else published_at.
expect {
	t = target(h1)
	pk = "${h1}.tar.zst"
	got = [
		Ingest.candidate(t, ghr(Bool.True, Bool.True, Err(None), [pk])),
		Ingest.candidate(t, ghr(Bool.False, Bool.True, Ok(5000), [pk])),
		Ingest.candidate(t, ghr(Bool.False, Bool.False, Ok(5000), ["docs.tar.gz", "${h1}.tar.zst.intoto.jsonl", "${h31}.tar.zst", "x.tar.zst"])),
		Ingest.candidate(t, ghr(Bool.False, Bool.False, Ok(5000), [pk, "${h2}.tar.zst"])),
		Ingest.candidate(t, ghr(Bool.False, Bool.False, Ok(5000), [pk, pk, "${h2}.tar.zst"])),
		Ingest.candidate(t, ghr(Bool.False, Bool.False, Ok(5000), ["${h2}.tar.zst"])),
		Ingest.candidate(t, ghr(Bool.False, Bool.False, Err(None), [pk])),
		Ingest.candidate(t, ghr(Bool.False, Bool.False, Ok(5000), ["docs.tar.gz", pk, "${h1}.tar.zst.intoto.jsonl", "${h31}.tar.zst"])),
	]
	got
		== [
			Err(Ingest.not_final("2.0.0", "a draft")),
			Err(Ingest.not_final("2.0.0", "a prerelease")),
			Err(Ingest.no_package_asset("2.0.0")),
			Err(Ingest.many_package_assets("2.0.0", 2)),
			Err(Ingest.many_package_assets("2.0.0", 3)),
			Err(Ingest.other_asset("2.0.0", "${h2}.tar.zst")),
			Err(Ingest.github_bad("release")),
			Ok(5000),
		]
}

# R-AP68 row 10 (Design Q161): no white space at the ends; an empty file is the text "".
expect [Ingest.roc_version_of(""), Ingest.roc_version_of(" \n"), Ingest.roc_version_of("\tnightly-2026-10-31-f7bef6b\r\n")] == ["", "", "nightly-2026-10-31-f7bef6b"]

# ---- after_read (R-AP68 rows 4 and 7, R-PU14, R-PU19, R-PU15, Design Q156, Q157) ----

# The bytes of h1 and h2 (32 bytes of 1 and of 2).
row = |bytes, has_ingest| {
	release: {
		log_index: 7,
		hash: bytes,
		form: app_form,
		version: "-9222809086901288961",
		version_text: "",
		url: "https://github.com/acme/app/releases/download/2.0.0/${h1}.tar.zst",
		tag: Ok("2.0.0"),
		roc_version: Err(Missing),
		repo: Ok("acme/app"),
		published_at: 1792497600000,
		yanked: Bool.False,
		withdrawn: Err(Missing),
		vias: if (has_ingest) Ok("3,0") else Ok("1"),
	},
	has_ingest,
}

record7 : Release.Row
record7 = {
	log_index: 7,
	hash: h1,
	group: app_form,
	series: "2",
	version: "2.0.0",
	url: "https://github.com/acme/app/releases/download/2.0.0/${h1}.tar.zst",
	tag: Ok("2.0.0"),
	roc_version: Err(None),
	repo: Ok("acme/app"),
	published_at: 1792497600000,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Err(None),
	provenance: ["oidc", "ingest"],
}

# R-PU14: the same hash with an ingest row is the answer; with no ingest row it adds the provenance (R-PU15); R-PU19: another hash is 409 with that hash; no row is Index.
expect {
	t = target(h1)
	got = [
		Ingest.after_read(t, []),
		Ingest.after_read(t, [row(List.repeat(1, 32), Bool.True)]),
		Ingest.after_read(t, [row(List.repeat(1, 32), Bool.False)]),
		Ingest.after_read(t, [row(List.repeat(2, 32), Bool.True)]),
	]
	got == [Ok(Index), Ok(Answer(record7)), Ok(AddProvenance(7)), Ok(Conflict(Ingest.label_conflict(t, Ok(h2))))]
}

# A hash in the row that is not 32 bytes is a fault (500), not an answer.
expect {
	match Ingest.after_read(target(h1), [row(List.repeat(1, 31), Bool.True)]) {
		Err(BadRow(_)) => Bool.True
		_ => Bool.False
	}
}

# ---- plan (R-SG8 rows 1, 2; R-IK2, R-IK3, R-IK5, R-IK7; R-RE1, R-RE2, R-RE19, R-RE20; R-PU15, R-PU26, R-TP5) ----

app_artifact = {
	hash: h1,
	kind: App,
	exposed: [],
	platform_hash: Ok(h2),
	roc_pin: Ok("nightly-2026-10-31-f7bef6b"),
	size: 1234,
	deps: [
		{ alias: "zlib", hash: h3, group: lib_form, series: Ok("0.4"), version: Ok("0.4.1"), url: "https://github.com/acme/lib/releases/download/0.4.1/${h3}.tar.zst" },
		{ alias: "again", hash: h2, group: "example.com/p/", series: Err(None), version: Err(None), url: "https://example.com/p/${h2}.tar.zst" },
	],
	target_names: [],
}

# A function: a constant that crashes (the stub) fails at compile time.
app_plan = |{}| Ingest.plan({ target: target(h1), repo: { id: 503, owner_id: 9001, public: Bool.True }, artifact: app_artifact, published_at: 1792497600000, roc_version: Ok("nightly-2026-10-14-38a3029"), now_ms: 1767225630000 })

# R-IK2, R-IK3: each name once (h2 is the platform and a dep), sorted by id; kind 1 the 32 bytes, kinds 2 and 3 the UTF-8 text. The dep with no version has no form name.
expect {
	app_plan({}).names
		== [
			{ id: -3601728077696412455, kind: 1, value: List.repeat(1, 32) },
			{ id: -1064978168533308264, kind: 1, value: List.repeat(2, 32) },
			{ id: 1377047433888313964, kind: 1, value: List.repeat(3, 32) },
			{ id: 1867293425818598420, kind: 2, value: lib_form.to_utf8() },
			{ id: 8104212146272099543, kind: 3, value: "acme/app".to_utf8() },
			{ id: 8403020328855985657, kind: 2, value: app_form.to_utf8() },
		]
}

# R-RE1 (kind code 0 for an app, R-IK7; exposes as a JSON array; the platform id), R-RE19 (deps by alias; a dep with no version has no form and no version), R-RE20 (none for an app).
expect {
	(app_plan({}).artifact == { id: -3601728077696412455, kind: 0, exposes_json: "[]", platform_id: Ok(-1064978168533308264), roc_pin: Ok("nightly-2026-10-31-f7bef6b"), size: 1234 })
		and (
			app_plan({}).deps
				== [
					{ alias: "again", dep: -1064978168533308264, form: Err(None), version: Err(None), url: "https://example.com/p/${h2}.tar.zst" },
					{ alias: "zlib", dep: 1377047433888313964, form: Ok(1867293425818598420), version: Ok({ version: "-9223372019674775553", version_text: "" }), url: "https://github.com/acme/lib/releases/download/0.4.1/${h3}.tar.zst" },
				]
		)
		and (app_plan({}).new_targets == [])
		and (app_plan({}).target_names == [])
}

# R-SG8 rows 1, 2: the leaf has the text forms and the time of the write, not published_at. R-RE2: the release row. R-PU15: the provenance time.
# R-TP5: the repos row with the GitHub ids. R-PU26, R-PU22: next_check_at is the clock + 1 h.
expect {
	(app_plan({}).leaf == { grp: app_form, version: "2.0.0", hash: h1, time: 1767225630000 })
		and (
			app_plan({}).release
				== {
					form: 8403020328855985657,
					column: { version: "-9222809086901288961", version_text: "" },
					artifact: -3601728077696412455,
					repo: 8104212146272099543,
					url: "https://github.com/acme/app/releases/download/2.0.0/${h1}.tar.zst",
					tag: "2.0.0",
					roc_version: Ok("nightly-2026-10-14-38a3029"),
					published_at: 1792497600000,
				}
		)
		and (app_plan({}).provenance_time == 1767225630000)
		and (app_plan({}).repo_row == { repo: 8104212146272099543, repository_id: 503, repository_owner_id: 9001, time: 1767225630000 })
		and (app_plan({}).check_row == { repo: 8104212146272099543, next_check_at: 1767229230000 })
}

# R-IK7, R-RE20: a platform: kind code 2, the targets sorted, only a name with no fixed code is new (wasm32 and x64mac have codes 34 and 1). No platform id.
expect {
	p = Ingest.plan({
		target: target(h1),
		repo: { id: 1, owner_id: 2, public: Bool.True },
		artifact: { hash: h1, kind: Platform, exposed: ["Stdout", "Arg"], platform_hash: Err(None), roc_pin: Err(None), size: 9, deps: [], target_names: ["wasm32", "x64mac", "zz9new"] },
		published_at: 1,
		roc_version: Err(None),
		now_ms: 2,
	})
	(p.artifact.kind == 2)
		and (p.artifact.exposes_json == "[\"Stdout\",\"Arg\"]")
		and (p.artifact.platform_id == Err(None))
		and (p.new_targets == ["zz9new"])
		and (p.target_names == ["wasm32", "x64mac", "zz9new"])
		and (p.release.roc_version == Err(None))
		and (p.names.len() == 3)
}

# ---- the batch result (R-SG8 rows 4, 7; R-IK3; R-AP8) ----

# R-IK3: the kind and the whole message are compared. A PrimaryKey of another table, leaf-missing, and a Unique of names are faults.
expect {
	c = |kind, message| Ingest.batch_failure({ kind, message })
	got = [
		c(Trigger, "label-conflict"),
		c(PrimaryKey, "UNIQUE constraint failed: names.id"),
		c(Trigger, "leaf-missing"),
		c(PrimaryKey, "UNIQUE constraint failed: releases.log_index"),
		c(Unique, "UNIQUE constraint failed: names.id"),
		c(Unique, "UNIQUE constraint failed: names.kind, names.value"),
		c(Check, "label-conflict"),
	]
	got == [LabelConflict, IdCollision, Fault, Fault, Fault, Fault, Fault]
}

# R-IK3: the detail names the new name and the other name with that id, as text (kind 1 base58, kinds 2 and 3 UTF-8). A row with the same (kind, value) is the name itself, not the other.
expect {
	names = app_plan({}).names
	other_hash = { id: "-1064978168533308264", kind: 1, value: List.repeat(0, 32) }
	itself = { id: "-3601728077696412455", kind: 1, value: List.repeat(1, 32) }
	other_repo = { id: "8104212146272099543", kind: 3, value: "someone/else".to_utf8() }
	cross = { id: "8403020328855985657", kind: 1, value: List.repeat(3, 32) }
	z = "11111111111111111111111111111111"
	got = [
		Ingest.collision(names, [itself, other_hash]),
		Ingest.collision(names, [other_repo]),
		Ingest.collision(names, [cross]),
		Ingest.collision(names, [itself]),
		Ingest.collision(names, []),
	]
	got
		== [
			Problem.new(IdCollision, "the hash ${h2} has the id -1064978168533308264 of the hash ${z} in the index"),
			Problem.new(IdCollision, "the repository acme/app has the id 8104212146272099543 of the repository someone/else in the index"),
			Problem.new(IdCollision, "the group ${app_form} has the id 8403020328855985657 of the hash ${h3} in the index"),
			Ingest.id_collision_unknown,
			Ingest.id_collision_unknown,
		]
}

# R-AP8, Q109-6 form: 201 only when the release statement wrote a row.
expect [Ingest.status_of(0), Ingest.status_of(1), Ingest.status_of(2)] == [200, 201, 201]

# R-AP8 (TW24 proposal): the body is the record in the member release. R-AP9: no-store. The Location of a 201.
expect {
	(Ingest.answer_body(record7) == "{\"release\":${Release.encode(record7)}}")
		and Ingest.answer_body(record7).contains("\"log_index\":7,\"provenance\":[\"oidc\",\"ingest\"],\"published_at\":1792497600000")
		and (Ingest.cache_control == "no-store")
		and (Ingest.location(h1) == "/v1/artifacts/${h1}")
}

# R-PU32: the design gives the detail; R-PU19: the detail says to release a new version (both forms of R-AP68, Design Q164).
expect {
	t = target(h1)
	(Ingest.not_public == nac("repository not found or not public"))
		and (Ingest.label_conflict(t, Ok(h2)) == Problem.new(LabelConflict, "the label ${app_form} 2.0.0 has the hash ${h2} in the index, not ${h1}: release a new version"))
		and (Ingest.label_conflict(t, Err(None)) == Problem.new(LabelConflict, "the label ${app_form} 2.0.0 has another hash in the index, not ${h1}: release a new version"))
}
