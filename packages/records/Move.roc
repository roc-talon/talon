## The wire bodies and the problem detail of the move routes (Registry R-AP31, R-TP14, R-TP15, R-AP32, R-AP51, R-AP44, R-AP21; slice 247, `docs/slices/247-move.md`). Pure. The CLI uses them later (`tln move`, R-CM22, R-MV1 to R-MV5).
## Every body here is a stub until the code agent writes it (TW18). The tests are `packages/records/tests/MoveTest.roc`.
## The request of `PUT /v1/packages/{owner}/{repo}/successor` is `{"name": "<owner>/<repo>"}`: the new name, as `owner/repo` (the member of R-AP32). `DELETE` has no body.
## The answer of both routes, and the answer 202 of an offer, is one item of `repos` (R-AP32, R-AP31): `Closure.encode_repo` and `Closure.decode_repo` write and read it (no new type). It is the item itself, not `{"repos": [...]}` (TW24 proposal, the slice file section 5).
## The problem `/errors/successor-mismatch` (R-AP21, R-AP31) has a `detail` that names the check, and for `exposes` lists the missing modules. `detail` and `check_of` are the writer and the reader of that text (TW24 proposal).
Move :: [].{

	## The request body of a `PUT`: the name of the new successor, as sent (the Worker folds the case of ASCII letters, R-IK2).
	Request : { name : Str }

	## The 4 checks of R-AP31, in the order of its table. `Exposes` has the modules of the newest release of the old name that the newest candidate of the successor does not expose, in the order of the old list (R-RE1: the order of the header).
	Check : [Index, Kind, Exposes(List(Str)), Chain]

	## The text of a request: `{"name":"<text>"}`, no white space, with the JSON escapes of the other codecs of this package.
	encode_request : Move.Request -> Str
	encode_request = |request| Json.to_str({ name: request.name })

	## R-AP51: `name` is required and is a text. A missing `name`, `null`, a name that is not a text, and a text that is not a JSON object are `BadJson`. A member that the reader does not know is ignored (R-AP44).
	## The decode does not check the form of the name (`owner/repo`): the Worker does, and a bad form fails the check `Index` (slice file, reading 2).
	decode_request : Str -> Try(Move.Request, [BadJson(Str)])
	decode_request = |text| {
		parsed : Try({ name : Str }, _)
		parsed = Json.parse(text)
		match parsed {
			Ok(r) => Ok({ name: r.name })
			Err(e) => Err(BadJson(Str.inspect(e)))
		}
	}

	## The `detail` of the problem `successor-mismatch` (R-AP31). `name` is the name of the successor as the Worker has it (lower case). The 4 texts, exactly (TW24 proposal):
	## | Check | Text |
	## | --- | --- |
	## | `Index` | `the successor <name> fails the Index check: it needs a github.com name with a repos row in the state active and at least one release that is a candidate` |
	## | `Kind` | `the successor <name> fails the Kind check: the newest candidate of the successor is not the same kind as the newest release of the old name` |
	## | `Exposes(missing)` | `the successor <name> fails the exposes check: the newest candidate of the successor does not expose the modules <m1>, <m2>` (the modules joined with `, `) |
	## | `Chain` | `the successor <name> fails the Chain check: the successor chain from the successor comes back to the old name` |
	detail : Str, Move.Check -> Str
	detail = |name, check| {
		head = "the successor ${name} fails the"
		match check {
			Index => "${head} Index check: it needs a github.com name with a repos row in the state active and at least one release that is a candidate"
			Kind => "${head} Kind check: the newest candidate of the successor is not the same kind as the newest release of the old name"
			Exposes(missing) => "${head} exposes check: ${exposes_tail}${Str.join_with(missing, ", ")}"
			Chain => "${head} Chain check: the successor chain from the successor comes back to the old name"
		}
	}

	exposes_tail : Str
	exposes_tail = "the newest candidate of the successor does not expose the modules "

	## The reader of `detail`: the name and the check of a `detail` text that `detail` wrote. `Exposes` has the missing modules. A text that is not one of the 4 forms is `NotACheck` (a client prints it as it is).
	check_of : Str -> Try({ name : Str, check : Move.Check }, [NotACheck])
	check_of = |text| {
		if !text.starts_with("the successor ") {
			Err(NotACheck)
		} else {
			parts = text.drop_prefix("the successor ").split_on(" fails the ")
			match parts {
				[name, _, ..] => {
					found = [Index, Kind, Chain].find_first(|c| Move.detail(name, c) == text)
					match found {
						Ok(check) => Ok({ name, check })
						Err(_) => exposes_of_text(name, text)
					}
				}
				_ => Err(NotACheck)
			}
		}
	}

	exposes_of_text : Str, Str -> Try({ name : Str, check : Move.Check }, [NotACheck])
	exposes_of_text = |name, text| {
		prefix = Move.detail(name, Exposes([]))
		if text.starts_with(prefix) {
			tail = text.drop_prefix(prefix)
			if (tail.is_empty()) Err(NotACheck) else Ok({ name, check: Exposes(tail.split_on(", ")) })
		} else {
			Err(NotACheck)
		}
	}
}
