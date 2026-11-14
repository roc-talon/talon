## The pure part of the move routes `PUT` and `DELETE /v1/packages/{owner}/{repo}/successor` (Registry 7.3: R-AP31, R-TP14, R-TP15, R-TP11, R-TP13; 4: R-AP32, R-AP41, R-AP51; slice 247, `docs/slices/247-move.md`). No effect, no platform import.
## The effects (the body read, the token check, the D1 session and its calls, the clock) are in `worker/MoveRoutes.roc` and `worker/Auth.roc`. The wire bodies and the text of the `detail` of `successor-mismatch` are in `packages/records/Move.roc`.
## The tests are `worker/tests/unit/MoveTest.roc` (W0) and `worker/tests/cases/move/` (W2).
## Every body here is a stub until the code agent writes it (TW18). The texts of the `detail` of a problem are proposals (TW24): the slice file section 5.
import records.Code
import records.Move as Wire
import Identity
import Oidc
import Problem

Move :: [].{

	## A name of the request as the Worker uses it: `name` is the lower-case `owner/repo` (R-IK2, the key of the `repos` row), `owner` and `repo` its parts as sent (not lower case).
	Name : { owner : Str, repo : Str, name : Str }

	## The release that a check compares: its kind (`artifacts.kind`) and its `exposes` list (R-RE1) as `modules` (`exposes` is a reserved word of Roc), in the order of the header.
	Newest : { kind : Code.Kind, modules : List(Str) }

	## The old row (R-RE11), with the names in place of the ids: `name` is the lower-case `owner/repo` of the path, `successor` and `offer` are names. `Err(None)` is no successor, no offer.
	Old : { name : Str, repository_id : U64, owner_id : U64, state : Identity.State, successor : Try(Str, [None]), offer : Try(Str, [None]) }

	## The `repos` row of the successor with its newest candidate (the live release with the largest version, R-IK5; live is not yanked and not withdrawn). `newest` is `Err(None)` for no candidate.
	Successor : { state : Identity.State, newest : Try(Move.Newest, [None]) }

	## What the read batch of D1 call 1 gives for the checks of R-AP31. `name` is the lower-case name of the successor as sent. `succ` is `Err(None)` when the successor has no `repos` row, and also
	## when `name` is not an `owner/repo` name. `old_newest` is the newest release of the old name: the live or not live release with the largest version (R-IK5); `Err(None)` when the old name has no release.
	## `chain` is the walk from the successor with the steps of R-SN8 (the start is on the walk, then each successor while the name is in the state `moved`, fewer than 4 links, no name twice).
	Facts : { old : Move.Old, old_newest : Try(Move.Newest, [None]), name : Str, succ : Try(Move.Successor, [None]), chain : List(Str) }

	## `parse_name`'s name for a text that is not `owner/repo`: not exactly one `/`, an empty part, a character other than `A-Z a-z 0-9 - . _` (the letters of a GitHub name), or a `.` or `..` part.
	## `Err(BadName)` is not a 400: the route treats the successor as a name with no `repos` row, so the check `Index` fails (slice file, reading 2).
	parse_name : Str -> Try(Move.Name, [BadName])
	parse_name = |text| {
		match text.split_on("/") {
			[owner, repo] => {
				if good_part(owner) and good_part(repo) {
					Ok({ owner, repo, name: text.with_ascii_lowercased() })
				} else {
					Err(BadName)
				}
			}
			_ => Err(BadName)
		}
	}

	## One part of a GitHub name: not empty, not `.` or `..`, only `A-Z a-z 0-9 - . _`.
	good_part : Str -> Bool
	good_part = |part| {
		bytes = part.to_utf8()
		!bytes.is_empty() and part != "." and part != ".." and bytes.all(|b| (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or b == 45 or b == 46 or b == 95)
	}

	## R-AP31: the body of a `PUT`: the bytes decode with `records.Move.decode_request`. A fault is 400 `bad-request`, `detail` `the move request body is not valid: <why>` (the `why` is the `BadJson` text; not UTF-8 is `it is not UTF-8`).
	## The result is the name as sent (not checked: `parse_name` does that).
	parse_body : List(U8) -> Try(Str, Problem)
	parse_body = |bytes| {
		text = Str.from_utf8(bytes).map_err(|_| bad_body("it is not UTF-8"))?
		request = Wire.decode_request(text).map_err(|BadJson(why)| bad_body(why))?
		Ok(request.name)
	}

	bad_body : Str -> Problem
	bad_body = |why| Problem.new(BadRequest, "the move request body is not valid: ${why}")

	## R-RE1: the column `artifacts.exposes` is a JSON array of module names, in the order of the header (Design Q93). `Err(BadExposes)` for a text that is not that.
	exposes_of : Str -> Try(List(Str), [BadExposes])
	exposes_of = |text| {
		parsed : Try(List(Str), _)
		parsed = Json.parse(text)
		parsed.map_err(|_| BadExposes)
	}

	## R-TP15: the token of a move after R-TP3 rows 1 to 3 (`Auth.verify!`): row 6 `repository_visibility` is `public`, then `event_name` is `workflow_dispatch`. Each fault is 403 `forbidden`
	## (`Oidc.claim_is`: `token claim repository_visibility is "private", expected "public"`; a missing claim `token claim event_name is missing`). Rows 4, 5, 7 and 8 do not apply.
	check_token : Oidc.Claims -> Try({}, Problem)
	check_token = |claims| {
		Oidc.claim_is(Forbidden, "repository_visibility", claims.repository_visibility, "public")?
		Oidc.claim_is(Forbidden, "event_name", claims.event_name, "workflow_dispatch")
	}

	## R-TP15, the table, for a `PUT`. `name` is the lower-case successor name of the body. The repository of the token is the claim `repository` (no case); a missing claim is 403 (`token claim repository is missing`).
	## The first row that fits:
	## 1. The token is of the successor (`repository` is `name`) and the claim `repository_owner_id` is the owner id of the old row: `Move({ clear_offer })`. `clear_offer` is not fixed by the tests (Q247-5).
	## 2. The token is of the old repository (`repository` is `old.name`) and the old row is `Active`: `Offer`.
	## 3. The token is of the successor and the old row has an offer that names `name`: `Move({ clear_offer: Bool.True })`.
	## 4. Else `Refuse(403 forbidden)`. The `detail` (TW24, slice file section 5): the token is of the old repository and the old row is not `Active`: `token claim repository is "<repository>": the old repository <old> is in the state <state>, an offer needs the state active`;
	##    the token is of the successor and the owner id is not the owner of the old row, and no offer: `token claim repository_owner_id is "<id>": it is not the owner of <old>, and <old> has no offer for <name>`;
	##    any other repository: `token claim repository is "<repository>": it is not <old> and it is not <name>`. `<state>` is `missing` or `moved`.
	put_role : { claims : Oidc.Claims, old : Move.Old, name : Str } -> [Move({ clear_offer : Bool }), Offer, Refuse(Problem)]
	put_role = |input| {
		claims = input.claims
		old = input.old
		name = input.name
		repository = match claims.repository {
			Ok(text) => text
			Err(Missing) => return Refuse(Oidc.missing(Forbidden, "repository"))
		}
		if repository.caseless_ascii_equals(name) {
			offered = old.offer == Ok(name)
			match claims.repository_owner_id {
				Ok(owner) if owner == old.owner_id.to_str() => Move({ clear_offer: Bool.True })
				_ if offered => Move({ clear_offer: Bool.True })
				Err(Missing) => Refuse(Oidc.missing(Forbidden, "repository_owner_id"))
				Ok(owner) => Refuse(Problem.new(Forbidden, "token claim repository_owner_id is \"${owner}\": it is not the owner of ${old.name}, and ${old.name} has no offer for ${name}"))
			}
		} else if repository.caseless_ascii_equals(old.name) {
			match old.state {
				Active => Offer
				Missing => Refuse(Problem.new(Forbidden, "token claim repository is \"${repository}\": the old repository ${old.name} is in the state missing, an offer needs the state active"))
				Moved => Refuse(Problem.new(Forbidden, "token claim repository is \"${repository}\": the old repository ${old.name} is in the state moved, an offer needs the state active"))
			}
		} else {
			Refuse(Problem.new(Forbidden, "token claim repository is \"${repository}\": it is not ${old.name} and it is not ${name}"))
		}
	}

	## R-TP15, the sentence "`DELETE` takes a token of the old repository, a token of the successor, or the operator key", for a `DELETE`. The token of the old repository (`repository` is `old.name`, any state), or the token of the
	## successor of the old row (`repository` is `old.successor`): `Ok`. Else 403 `forbidden`, `detail` `token claim repository is "<repository>": it is not <old> and it is not the successor of <old>` (no successor: `token claim repository is "<repository>": it is not <old>`).
	delete_role : { claims : Oidc.Claims, old : Move.Old } -> Try({}, Problem)
	delete_role = |input| {
		old = input.old
		repository = input.claims.repository ? |Missing| Oidc.missing(Forbidden, "repository")
		is_old = repository.caseless_ascii_equals(old.name)
		match old.successor {
			Ok(successor) => {
				if is_old or repository.caseless_ascii_equals(successor) {
					Ok({})
				} else {
					Err(Problem.new(Forbidden, "token claim repository is \"${repository}\": it is not ${old.name} and it is not the successor of ${old.name}"))
				}
			}
			Err(None) => {
				if (is_old) Ok({}) else Err(Problem.new(Forbidden, "token claim repository is \"${repository}\": it is not ${old.name}"))
			}
		}
	}

	## R-AP31: what a `PUT` of `name` does to the old row. `Same`: the successor is `name` already (200, nothing written). `Set`: the old row has no successor (201). `Replace`: it has another successor (200).
	put_effect : Move.Old, Str -> [Same, Set, Replace]
	put_effect = |old, name| match old.successor {
		Ok(current) => if (current == name) Same else Replace
		Err(None) => Set
	}

	## R-AP31: the status of the answer of a `PUT` that does not offer: 201 for `Set`, else 200.
	put_status : [Same, Set, Replace] -> U16
	put_status = |effect| match effect {
		Set => 201
		_ => 200
	}

	## R-AP31: what a `DELETE` does. `Same`: the old row has no successor (200, nothing written). `Remove`: it has one (200, written).
	delete_effect : Move.Old -> [Same, Remove]
	delete_effect = |old| match old.successor {
		Ok(_) => Remove
		Err(None) => Same
	}

	## R-AP31, R-TP11, R-TP13: the new row and the event of a `PUT` that sets or replaces the successor. `successor` is the repo id of the new successor (R-IK2). The row gets the state `Moved`, the successor and `state_at` = `now`.
	## Ids, `time` and the rest stay. One event `SuccessorSet`: the ids before and after are the ids of the row, and its `successor` is the new successor (`Identity.event_of` form). A row that is `Moved` gets the new successor and `state_at` = `now`.
	## (A row in the state `Missing` is not fixed by the tests: Q247-3.)
	set_change : { row : Identity.Row, successor : I64, now : U64 } -> Identity.Change
	set_change = |input| {
		row = { ..input.row, state: Moved, successor: Ok(input.successor), state_at: input.now }
		ids = { repository_id: row.repository_id, owner_id: row.owner_id }
		{ row, events: [Identity.event_of(row, SuccessorSet, Ok(ids), ids)] }
	}

	## R-AP31: the checks of the successor, in the order of its table. The first that fails gives 422 `successor-mismatch` with `Wire.detail(facts.name, check)`:
	## 1. `Index`: `succ` is `Err(None)`, or its state is not `Active`, or it has no candidate.
	## 2. `Kind`: `old_newest` is a release, and its kind is not the kind of the newest candidate. An old name with no release has nothing to compare (Q247-6, not fixed by a W2 case).
	## 3. `Exposes(missing)`: a module of the `exposes` of `old_newest` that is not in the `exposes` of the newest candidate (an exact compare). `missing` is in the order of the old list, each module once.
	## 4. `Chain`: `facts.old.name` is in `facts.chain`.
	check : Move.Facts -> Try({}, Problem)
	check = |facts| {
		fail = |check_failed| Err(Problem.new(SuccessorMismatch, Wire.detail(facts.name, check_failed)))
		succ = match facts.succ {
			Ok(found) => found
			Err(None) => return fail(Index)
		}
		if succ.state != Active {
			return fail(Index)
		}
		candidate = match succ.newest {
			Ok(newest) => newest
			Err(None) => return fail(Index)
		}
		match facts.old_newest {
			Ok(old_newest) => {
				if old_newest.kind != candidate.kind {
					return fail(Kind)
				}
				missing = old_newest.modules.fold(
					[],
					|acc, mod| if (candidate.modules.contains(mod) or acc.contains(mod)) acc else acc.append(mod),
				)
				if !missing.is_empty() {
					return fail(Exposes(missing))
				}
			}
			Err(None) => {}
		}
		if (facts.chain.contains(facts.old.name)) fail(Chain) else Ok({})
	}

	## R-AP31 error 404: the old name has no `repos` row. `detail` `no package named <name> has a repos row` (TW24).
	no_repo : Str -> Problem
	no_repo = |name| Problem.new(NotFound, "no package named ${name} has a repos row")
}
