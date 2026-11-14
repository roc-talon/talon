import records.Move

MoveTest :: [].{}

# W0 tests of packages/records/Move.roc (slice 247, docs/slices/247-move.md). The rules are R-AP31 (the request body, the problem detail), R-AP51 (a required member), R-AP44 (an unknown member), R-AP21 (the problem type).
# The detail texts are a proposal (TW24): the slice file section 5. The human accepts them at the review.

# R-AP31: the request is `{"name":"<owner>/<repo>"}`, no white space.
expect Move.encode_request({ name: "acme/roc-json" }) == "{\"name\":\"acme/roc-json\"}"

# R-AP31, R-AP51: the decode of the same text gives the name back. The text of the name is not checked here (the Worker does it).
expect Move.decode_request("{\"name\":\"acme/roc-json\"}") == Ok({ name: "acme/roc-json" })
expect Move.decode_request("{\"name\":\"Acme/Roc-Json\"}") == Ok({ name: "Acme/Roc-Json" })
expect Move.decode_request("{\"name\":\"not a name\"}") == Ok({ name: "not a name" })
expect Move.decode_request("{ \"name\" : \"a/b\" }") == Ok({ name: "a/b" })

# R-AP44: an unknown member is ignored.
expect Move.decode_request("{\"name\":\"a/b\",\"force\":true}") == Ok({ name: "a/b" })

# R-AP51: `name` is required and is a text. A name that is missing, `null` or a number, a body that is not an object, and a text that is not JSON are `BadJson`.
expect {
	is_bad = |text| match Move.decode_request(text) {
		Err(BadJson(_)) => Bool.True
		Ok(_) => Bool.False
	}
	is_bad("{}") and is_bad("{\"name\":null}") and is_bad("{\"name\":7}") and is_bad("{\"name\":[\"a/b\"]}") and is_bad("[]") and is_bad("\"a/b\"") and is_bad("null") and is_bad("") and is_bad("not json")
}

# R-AP31, R-AP21: the `detail` of `successor-mismatch` names the check. The 4 texts, exactly.
expect Move.detail("acme/new", Index) == "the successor acme/new fails the Index check: it needs a github.com name with a repos row in the state active and at least one release that is a candidate"
expect Move.detail("acme/new", Kind) == "the successor acme/new fails the Kind check: the newest candidate of the successor is not the same kind as the newest release of the old name"
expect Move.detail("acme/new", Chain) == "the successor acme/new fails the Chain check: the successor chain from the successor comes back to the old name"

# R-AP31: the `exposes` check lists the missing modules, in the given order, joined with `, `.
expect Move.detail("acme/new", Exposes(["Decode"])) == "the successor acme/new fails the exposes check: the newest candidate of the successor does not expose the modules Decode"
expect Move.detail("acme/new", Exposes(["Encode", "Decode", "Parse"])) == "the successor acme/new fails the exposes check: the newest candidate of the successor does not expose the modules Encode, Decode, Parse"

# R-AP31: `check_of` reads each detail back: the name and the check, with the missing modules.
expect {
	names = ["acme/new", "a/b", "x-y/z.w_1"]
	checks : List(Move.Check)
	checks = [Index, Kind, Chain, Exposes(["Decode"]), Exposes(["Encode", "Decode", "Parse"])]
	names.all(|n| checks.all(|c| Move.check_of(Move.detail(n, c)) == Ok({ name: n, check: c })))
}

# R-AP31: a text that is not one of the 4 forms is `NotACheck`.
expect {
	is_none = |text| match Move.check_of(text) {
		Err(NotACheck) => Bool.True
		Ok(_) => Bool.False
	}
	is_none("") and is_none("no route for PUT /x") and is_none("the successor acme/new fails the Speed check: slow") and is_none("the successor acme/new fails the exposes check: it is bad")
}
