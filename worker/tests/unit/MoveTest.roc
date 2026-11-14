import lib.Identity
import lib.Move
import lib.Oidc
import lib.Problem
import records.Move as Wire

MoveTest :: [].{}

# W0 tests of worker/lib/Move.roc (slice 247, docs/slices/247-move.md section 4). The rules are R-AP31 (the checks, the effects, the statuses), R-TP15 (the token and the role table), R-TP14, R-TP11, R-TP13, R-AP51, R-IK2.
# The `detail` texts are proposals (TW24): the slice file section 5. The texts of `Move.detail` are in packages/records/tests/MoveTest.roc.

# ---- the claims of a token of a move ----
none : Oidc.Claims
none = {
	iss: Err(Missing),
	aud: Err(Missing),
	exp: Err(Missing),
	nbf: Err(Missing),
	repository: Err(Missing),
	repository_id: Err(Missing),
	repository_owner_id: Err(Missing),
	repository_visibility: Err(Missing),
	ref: Err(Missing),
	ref_type: Err(Missing),
	event_name: Err(Missing),
	workflow_ref: Err(Missing),
	workflow_sha: Err(Missing),
	job_workflow_ref: Err(Missing),
	run_id: Err(Missing),
	run_attempt: Err(Missing),
	actor_id: Err(Missing),
	runner_environment: Err(Missing),
}

# The token of a repository (R-TP15): the claims that the roles read, a public repository, a manual run.
token = |repository, owner| { ..none, repository: Ok(repository), repository_owner_id: Ok(owner), repository_visibility: Ok("public"), event_name: Ok("workflow_dispatch") }

forbidden = |detail| Err(Problem.new(Forbidden, detail))

# ---- parse_name (R-AP31 check Index, R-IK2: the key of a name is the lower-case `owner/repo`) ----
expect Move.parse_name("acme/roc-json") == Ok({ owner: "acme", repo: "roc-json", name: "acme/roc-json" })
expect Move.parse_name("Acme/Roc-Json") == Ok({ owner: "Acme", repo: "Roc-Json", name: "acme/roc-json" })
expect Move.parse_name("x-y/z.w_1") == Ok({ owner: "x-y", repo: "z.w_1", name: "x-y/z.w_1" })
expect {
	is_bad = |text| Move.parse_name(text) == Err(BadName)
	is_bad("") and is_bad("acme") and is_bad("a/b/c") and is_bad("/b") and is_bad("a/") and is_bad("/") and is_bad(" a/b") and is_bad("a /b") and is_bad("a/b ") and is_bad("a/b\n")
		and is_bad("a/..") and is_bad("../b") and is_bad("a/.") and is_bad("a/b?x=1") and is_bad("a/b#c") and is_bad("a%2Fb/c") and is_bad("ü/b") and is_bad("github.com/a/b") and is_bad("https://github.com/a/b")
}

# ---- parse_body (R-AP31, R-AP51): the name as sent; a decode fault is 400 `bad-request` ----
expect Move.parse_body("{\"name\":\"Acme/Roc-Json\"}".to_utf8()) == Ok("Acme/Roc-Json")
expect Move.parse_body("{\"name\":\"not a name\"}".to_utf8()) == Ok("not a name")
expect Move.parse_body("{\"name\":\"a/b\",\"force\":true}".to_utf8()) == Ok("a/b")
expect Move.parse_body([255, 254]) == Err(Problem.new(BadRequest, "the move request body is not valid: it is not UTF-8"))
expect {
	is_bad = |text| match Move.parse_body(text.to_utf8()) {
		Err(p) => p.http_status() == 400 and p.to_json().contains("/errors/bad-request") and p.to_json().contains("the move request body is not valid: ")
		Ok(_) => Bool.False
	}
	is_bad("") and is_bad("{}") and is_bad("{\"name\":null}") and is_bad("{\"name\":7}") and is_bad("[]") and is_bad("not json")
}

# ---- exposes_of (R-RE1: a JSON array of module names, in the order of the header) ----
expect Move.exposes_of("[\"Alpha\",\"Beta\"]") == Ok(["Alpha", "Beta"])
expect Move.exposes_of("[]") == Ok([])
expect Move.exposes_of("[ \"Alpha\" ]") == Ok(["Alpha"])
expect Move.exposes_of("[\"Beta\",\"Alpha\"]") == Ok(["Beta", "Alpha"])
expect {
	is_bad = |text| Move.exposes_of(text) == Err(BadExposes)
	is_bad("") and is_bad("{}") and is_bad("[\"A\",1]") and is_bad("Alpha") and is_bad("null") and is_bad("[\"A\"")
}

# ---- check_token (R-TP15: R-TP3 row 6, and `event_name` is `workflow_dispatch`) ----
good = token("acme/roc-json", "10")
expect Move.check_token(good) == Ok({})
expect Move.check_token({ ..good, repository_visibility: Ok("private") }) == forbidden("token claim repository_visibility is \"private\", expected \"public\"")
expect Move.check_token({ ..good, repository_visibility: Ok("internal") }) == forbidden("token claim repository_visibility is \"internal\", expected \"public\"")
expect Move.check_token({ ..good, repository_visibility: Err(Missing) }) == forbidden("token claim repository_visibility is missing")
expect Move.check_token({ ..good, event_name: Ok("push") }) == forbidden("token claim event_name is \"push\", expected \"workflow_dispatch\"")
expect Move.check_token({ ..good, event_name: Ok("release") }) == forbidden("token claim event_name is \"release\", expected \"workflow_dispatch\"")
expect Move.check_token({ ..good, event_name: Ok("schedule") }) == forbidden("token claim event_name is \"schedule\", expected \"workflow_dispatch\"")
expect Move.check_token({ ..good, event_name: Ok("Workflow_Dispatch") }) == forbidden("token claim event_name is \"Workflow_Dispatch\", expected \"workflow_dispatch\"")
expect Move.check_token({ ..good, event_name: Err(Missing) }) == forbidden("token claim event_name is missing")
# The visibility comes first.
expect Move.check_token({ ..good, repository_visibility: Ok("private"), event_name: Ok("push") }) == forbidden("token claim repository_visibility is \"private\", expected \"public\"")
# Rows 4, 5, 7 and 8 of R-TP3 do not apply: no ref, no ref_type, no repository id is needed.
expect Move.check_token({ ..none, repository_visibility: Ok("public"), event_name: Ok("workflow_dispatch") }) == Ok({})

# ---- put_role (R-TP15 table) ----
old : Move.Old
old = { name: "olduser/roc-json", repository_id: 100, owner_id: 10, state: Active, successor: Err(None), offer: Err(None) }

new_name = "acme/roc-json"

is_move = |got| match got {
	Move(_) => Bool.True
	_ => Bool.False
}

# Row 1: the token of the successor, the owner of the old row: the move is done (the case of the repository name is ignored, as R-TP3 row 4).
expect is_move(Move.put_role({ claims: token("acme/roc-json", "10"), old, name: new_name }))
expect is_move(Move.put_role({ claims: token("Acme/Roc-Json", "10"), old, name: new_name }))
# The row 1 does not depend on the state of the old row, nor on a successor that it has.
expect is_move(Move.put_role({ claims: token("acme/roc-json", "10"), old: { ..old, state: Moved, successor: Ok("acme/first") }, name: new_name }))
expect is_move(Move.put_role({ claims: token("acme/roc-json", "10"), old: { ..old, state: Missing }, name: new_name }))

# Row 2: the token of the old repository, the old row is active: an offer.
expect Move.put_role({ claims: token("olduser/roc-json", "10"), old, name: new_name }) == Offer
expect Move.put_role({ claims: token("OldUser/Roc-Json", "10"), old, name: new_name }) == Offer

# The old repository, an old row that is not active: no offer (the table says state `active`). 403.
expect Move.put_role({ claims: token("olduser/roc-json", "10"), old: { ..old, state: Moved, successor: Ok("acme/first") }, name: new_name }) == Refuse(Problem.new(Forbidden, "token claim repository is \"olduser/roc-json\": the old repository olduser/roc-json is in the state moved, an offer needs the state active"))
expect Move.put_role({ claims: token("olduser/roc-json", "10"), old: { ..old, state: Missing }, name: new_name }) == Refuse(Problem.new(Forbidden, "token claim repository is \"olduser/roc-json\": the old repository olduser/roc-json is in the state missing, an offer needs the state active"))

# Row 3: the token of the successor with another owner id, and an offer of the old row that names it: done, and the offer is cleared.
offered = { ..old, offer: Ok("acme/roc-json") }
expect Move.put_role({ claims: token("acme/roc-json", "20"), old: offered, name: new_name }) == Move({ clear_offer: Bool.True })
expect Move.put_role({ claims: token("Acme/Roc-Json", "20"), old: offered, name: new_name }) == Move({ clear_offer: Bool.True })
# An offer that names another name does not help.
expect Move.put_role({ claims: token("acme/roc-json", "20"), old: { ..old, offer: Ok("third/lib") }, name: new_name }) == Refuse(Problem.new(Forbidden, "token claim repository_owner_id is \"20\": it is not the owner of olduser/roc-json, and olduser/roc-json has no offer for acme/roc-json"))

# No offer, another owner id: 403.
expect Move.put_role({ claims: token("acme/roc-json", "20"), old, name: new_name }) == Refuse(Problem.new(Forbidden, "token claim repository_owner_id is \"20\": it is not the owner of olduser/roc-json, and olduser/roc-json has no offer for acme/roc-json"))
# The owner id claim is missing.
expect Move.put_role({ claims: { ..token("acme/roc-json", "10"), repository_owner_id: Err(Missing) }, old, name: new_name }) == Refuse(Problem.new(Forbidden, "token claim repository_owner_id is missing"))

# Any other repository: 403, also with the owner id of the old row (a repository of the same account is not the successor).
expect Move.put_role({ claims: token("other/lib", "10"), old, name: new_name }) == Refuse(Problem.new(Forbidden, "token claim repository is \"other/lib\": it is not olduser/roc-json and it is not acme/roc-json"))
expect Move.put_role({ claims: token("other/lib", "10"), old: offered, name: new_name }) == Refuse(Problem.new(Forbidden, "token claim repository is \"other/lib\": it is not olduser/roc-json and it is not acme/roc-json"))
expect Move.put_role({ claims: { ..token("a/b", "10"), repository: Err(Missing) }, old, name: new_name }) == Refuse(Problem.new(Forbidden, "token claim repository is missing"))

# ---- delete_role (R-TP15: the old repository, the successor, or the operator key) ----
with_succ = { ..old, state: Moved, successor: Ok("acme/roc-json") }
expect Move.delete_role({ claims: token("olduser/roc-json", "10"), old: with_succ }) == Ok({})
expect Move.delete_role({ claims: token("OldUser/Roc-Json", "10"), old: with_succ }) == Ok({})
# The old repository, any state (a row with a successor is `moved`).
expect Move.delete_role({ claims: token("olduser/roc-json", "10"), old }) == Ok({})
# The successor: any owner id.
expect Move.delete_role({ claims: token("acme/roc-json", "20"), old: with_succ }) == Ok({})
expect Move.delete_role({ claims: token("Acme/Roc-Json", "10"), old: with_succ }) == Ok({})
# Any other repository, also of the same account.
expect Move.delete_role({ claims: token("other/lib", "10"), old: with_succ }) == forbidden("token claim repository is \"other/lib\": it is not olduser/roc-json and it is not the successor of olduser/roc-json")
# A row with no successor has no successor repository.
expect Move.delete_role({ claims: token("acme/roc-json", "10"), old }) == forbidden("token claim repository is \"acme/roc-json\": it is not olduser/roc-json")
expect Move.delete_role({ claims: { ..token("a/b", "10"), repository: Err(Missing) }, old: with_succ }) == forbidden("token claim repository is missing")

# ---- put_effect, put_status, delete_effect (R-AP31: 201 sets, 200 replaces, 200 and no write for the same successor) ----
expect Move.put_effect(old, "acme/roc-json") == Set
expect Move.put_effect(with_succ, "acme/roc-json") == Same
expect Move.put_effect(with_succ, "acme/other") == Replace
expect Move.put_effect({ ..old, offer: Ok("acme/roc-json") }, "acme/roc-json") == Set
expect Move.put_status(Set) == 201
expect Move.put_status(Replace) == 200
expect Move.put_status(Same) == 200
expect Move.delete_effect(old) == Same
expect Move.delete_effect(with_succ) == Remove

# ---- set_change (R-AP31, R-TP11, R-TP13) ----
row : Identity.Row
row = { repo: 11, repository_id: 100, owner_id: 10, state: Active, successor: Err(None), state_at: 1000, time: 500 }

event_of = |r| { repo: 11, action: SuccessorSet, repository_id_before: Ok(100), repository_id_after: Ok(100), owner_id_before: Ok(10), owner_id_after: Ok(10), successor: Ok(r) }

# An active row becomes moved, with the successor and the time of the request. One event, with the successor. The ids and `time` stay.
expect Move.set_change({ row, successor: 22, now: 9000 }) == { row: { ..row, state: Moved, successor: Ok(22), state_at: 9000 }, events: [event_of(22)] }
# A moved row (another successor): the new successor, `state_at` = now, one event.
expect Move.set_change({ row: { ..row, state: Moved, successor: Ok(33) }, successor: 22, now: 9000 }) == { row: { ..row, state: Moved, successor: Ok(22), state_at: 9000 }, events: [event_of(22)] }

# ---- check (R-AP31: Index, Kind, exposes, Chain, in this order) ----
old_app : Move.Newest
old_app = { kind: Package, modules: ["Alpha", "Beta", "Gamma"] }

ok_succ : Move.Successor
ok_succ = { state: Active, newest: Ok({ kind: Package, modules: ["Gamma", "Beta", "Alpha", "Delta"] }) }

facts : Move.Facts
facts = { old, old_newest: Ok(old_app), name: "acme/roc-json", succ: Ok(ok_succ), chain: ["acme/roc-json"] }

mismatch = |c| Err(Problem.new(SuccessorMismatch, Wire.detail("acme/roc-json", c)))

expect Move.check(facts) == Ok({})
# The exposes of the successor may have more modules (Delta), in any order (the first check above).
# Index: no row, a state that is not active, no candidate.
expect Move.check({ ..facts, succ: Err(None) }) == mismatch(Index)
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, state: Missing }) }) == mismatch(Index)
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, state: Moved }) }) == mismatch(Index)
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, newest: Err(None) }) }) == mismatch(Index)
# Kind: another kind of the newest candidate.
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, newest: Ok({ kind: App, modules: ["Alpha", "Beta", "Gamma"] }) }) }) == mismatch(Kind)
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, newest: Ok({ kind: Platform, modules: ["Alpha", "Beta", "Gamma"] }) }) }) == mismatch(Kind)
expect Move.check({ ..facts, old_newest: Ok({ kind: Platform, modules: [] }) }) == mismatch(Kind)
# exposes: the missing modules, in the order of the old list, each once; an exact compare of the names.
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, newest: Ok({ kind: Package, modules: ["Alpha", "Gamma"] }) }) }) == mismatch(Exposes(["Beta"]))
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, newest: Ok({ kind: Package, modules: [] }) }) }) == mismatch(Exposes(["Alpha", "Beta", "Gamma"]))
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, newest: Ok({ kind: Package, modules: ["alpha", "BETA", "Gamma"] }) }) }) == mismatch(Exposes(["Alpha", "Beta"]))
expect Move.check({ ..facts, old_newest: Ok({ kind: Package, modules: ["Alpha", "Alpha", "Beta"] }), succ: Ok({ ..ok_succ, newest: Ok({ kind: Package, modules: ["Beta"] }) }) }) == mismatch(Exposes(["Alpha"]))
# An old release that exposes nothing needs nothing (an app).
expect Move.check({ ..facts, old_newest: Ok({ kind: App, modules: [] }), succ: Ok({ ..ok_succ, newest: Ok({ kind: App, modules: [] }) }) }) == Ok({})
# Chain: the old name is on the walk from the successor.
expect Move.check({ ..facts, name: "olduser/roc-json", chain: ["olduser/roc-json"] }) == Err(Problem.new(SuccessorMismatch, Wire.detail("olduser/roc-json", Chain)))
expect Move.check({ ..facts, chain: ["acme/roc-json", "x/y", "olduser/roc-json"] }) == mismatch(Chain)
expect Move.check({ ..facts, chain: ["acme/roc-json", "x/y"] }) == Ok({})
# The order: Index before Kind before exposes before Chain.
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, state: Missing, newest: Ok({ kind: App, modules: [] }) }), chain: ["olduser/roc-json"] }) == mismatch(Index)
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, newest: Ok({ kind: App, modules: [] }) }), chain: ["olduser/roc-json"] }) == mismatch(Kind)
expect Move.check({ ..facts, succ: Ok({ ..ok_succ, newest: Ok({ kind: Package, modules: [] }) }), chain: ["olduser/roc-json"] }) == mismatch(Exposes(["Alpha", "Beta", "Gamma"]))
# The problem is 422 `successor-mismatch`.
expect {
	match Move.check({ ..facts, succ: Err(None) }) {
		Err(p) => p.http_status() == 422 and p.to_json().contains("/errors/successor-mismatch")
		Ok(_) => Bool.False
	}
}

# ---- no_repo (R-AP31 error 404) ----
expect Move.no_repo("olduser/nothing").http_status() == 404
expect Move.no_repo("olduser/nothing") == Problem.new(NotFound, "no package named olduser/nothing has a repos row")
