import lib.Client
import lib.Oidc
import lib.Problem
import lib.Route
import lib.Yank

YankTest :: [].{}

# W0 tests of worker/lib/Yank.roc, and of the route lines of yank in Route.roc and Client.roc (slice 246, docs/slices/246-yank.md section 4.1). The design: Registry 7.2 (R-YK1 to R-YK7), 7.1 (R-TP3, R-TP8), 4 (R-AP45, R-AP48, R-AP51).

# ---- the route (R-AP48 rows 1, 2, 5; R-AP45; R-YK1) ----

input = |method, segments, content_type, has_body| { method, segments, content_type, has_body }

yank_path = |index| ["v1", "releases", index, "yank"]

json = Ok("application/json")

# R-YK1, R-AP48 rows 1 and 2: `PUT` and `DELETE` are served on `/v1/releases/{log_index}/yank`. Another method is 405 with `Allow: DELETE, PUT`. The index is any one segment (the code agent maps a bad index: question Q246-7).
# A path with another shape is 404 (the path of a publish, `/v1/releases`, is not changed).
expect {
	not_allowed = |method| NotAllowed(Problem.new(MethodNotAllowed, "${method} is not allowed on /v1/releases/5/yank"), ["DELETE", "PUT"])
	Route.decide(input("PUT", yank_path("5"), json, Bool.True)) == Handle(PutYank("5"))
		and Route.decide(input("PUT", yank_path("5"), Err(NotFound), Bool.False)) == Handle(PutYank("5"))
		and Route.decide(input("DELETE", yank_path("5"), Err(NotFound), Bool.False)) == Handle(DeleteYank("5"))
		and Route.decide(input("PUT", yank_path("123456789"), json, Bool.True)) == Handle(PutYank("123456789"))
		and Route.decide(input("GET", yank_path("5"), Err(NotFound), Bool.False)) == not_allowed("GET")
		and Route.decide(input("POST", yank_path("5"), json, Bool.True)) == not_allowed("POST")
		and Route.decide(input("PATCH", yank_path("5"), json, Bool.True)) == not_allowed("PATCH")
		and Route.decide(input("PUT", ["v1", "releases", "5", "yank", "x"], json, Bool.True)) == Refuse(Problem.new(NotFound, "no route for PUT /v1/releases/5/yank/x"))
		and Route.decide(input("PUT", ["v1", "releases", "5"], json, Bool.True)) == Refuse(Problem.new(NotFound, "no route for PUT /v1/releases/5"))
		and Route.decide(input("GET", ["v1", "releases"], Err(NotFound), Bool.False)) == Handle(GetReleases)
}

# R-AP48 row 5, R-AP23: a `PUT` with a body that is not `application/json` is 415. A `PUT` with no body is not checked. A `DELETE` has no body check (as the other `DELETE` routes, R-AP38).
expect {
	Route.decide(input("PUT", yank_path("5"), Ok("text/plain"), Bool.True)) == Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, got text/plain"))
		and Route.decide(input("PUT", yank_path("5"), Err(NotFound), Bool.True)) == Refuse(Problem.new(UnsupportedMediaType, "the request body must be application/json, but the request has no Content-Type"))
		and Route.decide(input("PUT", yank_path("5"), Ok("Application/JSON; charset=UTF-8"), Bool.True)) == Handle(PutYank("5"))
		and Route.decide(input("DELETE", yank_path("5"), Ok("text/plain"), Bool.True)) == Handle(DeleteYank("5"))
		and Route.decide(input("DELETE", yank_path("5"), Err(NotFound), Bool.True)) == Handle(DeleteYank("5"))
}

# R-AP45, R-AP41: `MIN_TLN_WRITE` covers the two yank routes. The reads stay reads.
expect {
	Client.is_write(PutYank("5")) and Client.is_write(DeleteYank("5")) and !Client.is_write(GetReleases) and !Client.is_write(GetArtifact("x"))
}

# ---- the decision (R-YK1, R-YK2, R-YK4) ----

verdict = |action, caller, state| match Yank.decide(action, caller, state) {
	NoChange => "no-change"
	Change => "change"
	Refuse(problem) => "refuse ${problem.http_status().to_str()}"
}

# R-YK1: both routes are idempotent. A `PUT` on a yanked release and a `DELETE` on a release that is not yanked change nothing, for each caller and each earlier `by`.
expect {
	verdict(Yank, Author, Yanked(Author)) == "no-change"
		and verdict(Yank, Author, Yanked(Operator)) == "no-change"
		and verdict(Yank, Operator, Yanked(Author)) == "no-change"
		and verdict(Yank, Operator, Yanked(Operator)) == "no-change"
		and verdict(Unyank, Author, Live) == "no-change"
		and verdict(Unyank, Operator, Live) == "no-change"
}

# R-YK1, R-YK4: a `PUT` on a release that is not yanked, a `DELETE` on a yanked release, change it.
# R-YK2: an author cannot remove a yank of the operator (403 `forbidden`). The operator removes both kinds, and an author removes a yank of an author.
expect {
	verdict(Yank, Author, Live) == "change"
		and verdict(Yank, Operator, Live) == "change"
		and verdict(Unyank, Author, Yanked(Author)) == "change"
		and verdict(Unyank, Operator, Yanked(Author)) == "change"
		and verdict(Unyank, Operator, Yanked(Operator)) == "change"
		and verdict(Unyank, Author, Yanked(Operator)) == "refuse 403"
}

# R-YK2: the text of the refusal (a TW24 proposal, the slice file section 5).
expect {
	Yank.decide(Unyank, Author, Yanked(Operator)) == Refuse(Problem.new(Forbidden, "the release is yanked by the operator: only the operator can remove this yank"))
}

# R-RE10, R-IK7: the codes. `yank` 0, `unyank` 1. `author` 0, `operator` 1.
expect {
	Yank.action_code(Yank) == 0 and Yank.action_code(Unyank) == 1 and Yank.by_code(Author) == 0 and Yank.by_code(Operator) == 1
}

# ---- the body of a PUT (R-YK6, R-AP51, R-AP48 row 6) ----

body = |text| Yank.parse_body(text.to_utf8())

reason_of = |text| match body(text) {
	Ok(put) => Ok(put.reason)
	Err(problem) => Err(problem.http_status())
}

# R-YK6: a yank with no reason is valid. R-AP51: a missing `reason` and `null` are no reason, an unknown member is ignored (R-AP44), the empty text is a reason.
expect {
	reason_of("{}") == Ok(Err(None))
		and reason_of("{\"reason\":null}") == Ok(Err(None))
		and reason_of("{\"reason\":\"broken build\"}") == Ok(Ok("broken build"))
		and reason_of("{\"reason\":\"\"}") == Ok(Ok(""))
		and reason_of("{\"reason\":\"x\",\"later\":{\"a\":1}}") == Ok(Ok("x"))
		and reason_of("{\"later\":1}") == Ok(Err(None))
		and reason_of("{\"reason\":\"${"a".repeat(500)}\"}") == Ok(Ok("a".repeat(500)))
		and reason_of("{\"reason\":\"${"é".repeat(250)}\"}") == Ok(Ok("é".repeat(250)))
}

# R-YK6, R-AP48 row 6, R-AP51: 400 `bad-request` for a reason of more than 500 bytes, a reason with a control character (written as a JSON escape), a reason that is not a text, a body that is not JSON,
# a body that is not an object, and bytes that are not UTF-8. The `detail` of a fault of the length or of a control character names the member `reason`.
expect {
	bad = |text| reason_of(text) == Err(400)
	bad("{\"reason\":\"${"a".repeat(501)}\"}")
		and bad("{\"reason\":\"${"é".repeat(251)}\"}")
		and bad("{\"reason\":\"a\\nb\"}")
		and bad("{\"reason\":\"a\\tb\"}")
		and bad("{\"reason\":\"a\\u0000b\"}")
		and bad("{\"reason\":\"a\\u007fb\"}")
		and bad("{\"reason\":5}")
		and bad("{\"reason\":true}")
		and bad("{\"reason\":[\"x\"]}")
		and bad("{\"reason\":")
		and bad("[]")
		and bad("\"x\"")
		and bad("not json")
}

expect {
	names_reason = |text| match body(text) {
		Err(problem) => problem.to_json().contains("reason")
		Ok(_) => Bool.False
	}
	names_reason("{\"reason\":\"${"a".repeat(501)}\"}") and names_reason("{\"reason\":\"a\\nb\"}")
}

expect {
	match Yank.parse_body([123, 34, 114, 34, 58, 34, 255, 34, 125]) {
		Err(problem) => problem == Problem.new(BadRequest, "the yank request body is not valid: it is not UTF-8")
		Ok(_) => Bool.False
	}
}

# ---- the token (R-TP8, R-TP3 rows 4 and 6) ----

base : Oidc.Claims
base = {
	iss: Ok("https://token.actions.githubusercontent.com"),
	aud: Ok("https://registry.example"),
	exp: Ok(1767225900),
	nbf: Ok(1767225300),
	repository: Ok("acme/lib"),
	repository_id: Ok("900"),
	repository_owner_id: Ok("9100"),
	repository_visibility: Ok("public"),
	ref: Ok("refs/heads/main"),
	ref_type: Ok("branch"),
	event_name: Ok("workflow_dispatch"),
	workflow_ref: Ok("acme/lib/.github/workflows/yank.yml@refs/heads/main"),
	workflow_sha: Ok("89abcdef0123456789abcdef0123456789abcdef"),
	job_workflow_ref: Ok("acme/lib/.github/workflows/yank.yml@refs/heads/main"),
	run_id: Ok("77"),
	run_attempt: Ok("1"),
	actor_id: Ok("512345"),
	runner_environment: Ok("github-hosted"),
}

check = |claims, repository| match Yank.check_token(claims, repository) {
	Ok({}) => Ok({})
	Err(problem) => Err(problem.to_json())
}

# The problem of a fault as the JSON text of `Problem.to_json`, so that the test names the type and the `detail`.
forbidden = |detail| Err(Problem.new(Forbidden, detail).to_json())

# R-TP8: the token is a token of the repository of the release, `workflow_dispatch`, public. The repository compare has no case (R-TP3 row 4). Rows 7 and 8 do not apply: a branch ref, a missing ref and a missing ref_type pass.
expect {
	check(base, Ok("acme/lib")) == Ok({})
		and check({ ..base, repository: Ok("Acme/LIB") }, Ok("acme/lib")) == Ok({})
		and check({ ..base, ref: Ok("refs/tags/1.0.0"), ref_type: Ok("tag") }, Ok("acme/lib")) == Ok({})
		and check({ ..base, ref: Err(Missing), ref_type: Err(Missing) }, Ok("acme/lib")) == Ok({})
		and check({ ..base, ref: Ok("refs/tags/other-tag") }, Ok("acme/lib")) == Ok({})
}

# R-TP8, R-TP3 row 4: another repository, and a missing claim `repository`, are 403 `forbidden`; the `detail` names the claim.
expect {
	check({ ..base, repository: Ok("acme/other") }, Ok("acme/lib")) == forbidden("token claim repository is \"acme/other\", expected \"acme/lib\"")
		and check({ ..base, repository: Err(Missing) }, Ok("acme/lib")) == forbidden("token claim repository is missing")
}

# R-TP8, R-TP3 row 6: the repository is public.
expect {
	check({ ..base, repository_visibility: Ok("private") }, Ok("acme/lib")) == forbidden("token claim repository_visibility is \"private\", expected \"public\"")
		and check({ ..base, repository_visibility: Ok("internal") }, Ok("acme/lib")) == forbidden("token claim repository_visibility is \"internal\", expected \"public\"")
		and check({ ..base, repository_visibility: Err(Missing) }, Ok("acme/lib")) == forbidden("token claim repository_visibility is missing")
}

# R-TP8: `event_name` is `workflow_dispatch`. Reason: a yank is a manual act. `push`, `release` (the events that a publish accepts), `schedule` and a missing claim are 403.
expect {
	check({ ..base, event_name: Ok("push") }, Ok("acme/lib")) == forbidden("token claim event_name is \"push\", expected \"workflow_dispatch\"")
		and check({ ..base, event_name: Ok("release") }, Ok("acme/lib")) == forbidden("token claim event_name is \"release\", expected \"workflow_dispatch\"")
		and check({ ..base, event_name: Ok("schedule") }, Ok("acme/lib")) == forbidden("token claim event_name is \"schedule\", expected \"workflow_dispatch\"")
		and check({ ..base, event_name: Err(Missing) }, Ok("acme/lib")) == forbidden("token claim event_name is missing")
}

# R-TP8: the order of the faults is the repository, the visibility, the event (R-TP3 rows 4, 6, then the event).
expect {
	all_bad = { ..base, repository: Ok("acme/other"), repository_visibility: Ok("private"), event_name: Ok("push") }
	check(all_bad, Ok("acme/lib")) == forbidden("token claim repository is \"acme/other\", expected \"acme/lib\"")
		and check({ ..all_bad, repository: Ok("acme/lib") }, Ok("acme/lib")) == forbidden("token claim repository_visibility is \"private\", expected \"public\"")
		and check({ ..all_bad, repository: Ok("acme/lib"), repository_visibility: Ok("public") }, Ok("acme/lib")) == forbidden("token claim event_name is \"push\", expected \"workflow_dispatch\"")
}

# R-YK2: a release on another host has no GitHub identity, so a token never yanks it (403 `forbidden`). Only the operator can.
expect {
	match Yank.check_token(base, Err(NoRepo)) {
		Err(problem) => problem == Problem.new(Forbidden, "the release has no GitHub repository: only the operator can yank it")
		Ok({}) => Bool.False
	}
}

# ---- the ids (R-TP3 row 5, R-TP9, R-TP12) ----

ids = |repository_id, owner_id| { repository_id, owner_id }

# R-TP3 row 5: no `repos` row passes. A row: the same repository id, or the same owner id, passes (a transfer and a recreate: R-TP9 rows 2, 3). Both different is `Changed`. A yank records nothing (question Q246-4).
expect {
	Yank.binding(ids(900, 9100), Err(NoRow)) == Ok({})
		and Yank.binding(ids(900, 9100), Ok(ids(900, 9100))) == Ok({})
		and Yank.binding(ids(900, 777), Ok(ids(900, 9100))) == Ok({})
		and Yank.binding(ids(1, 9100), Ok(ids(900, 9100))) == Ok({})
		and Yank.binding(ids(1, 2), Ok(ids(900, 9100))) == Err(Changed)
}
