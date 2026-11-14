## Private reference of slice 247 (test agent). Not for the code agent (TW18).
import records.Code
import records.Move as Wire
import Identity
import Oidc
import Problem

Move :: [].{

	Name : { owner : Str, repo : Str, name : Str }

	Newest : { kind : Code.Kind, modules : List(Str) }

	Old : { name : Str, repository_id : U64, owner_id : U64, state : Identity.State, successor : Try(Str, [None]), offer : Try(Str, [None]) }

	Successor : { state : Identity.State, newest : Try(Move.Newest, [None]) }

	Facts : { old : Move.Old, old_newest : Try(Move.Newest, [None]), name : Str, succ : Try(Move.Successor, [None]), chain : List(Str) }

	ok_byte : U8 -> Bool
	ok_byte = |b| (b >= 97 and b <= 122) or (b >= 65 and b <= 90) or (b >= 48 and b <= 57) or b == 45 or b == 46 or b == 95

	ok_part : Str -> Bool
	ok_part = |part| !part.is_empty() and part != "." and part != ".." and part.to_utf8().all(ok_byte)

	parse_name : Str -> Try(Move.Name, [BadName])
	parse_name = |text| match text.split_on("/") {
		[owner, repo] => if ok_part(owner) and ok_part(repo) Ok({ owner, repo, name: "${owner}/${repo}".with_ascii_lowercased() }) else Err(BadName)
		_ => Err(BadName)
	}

	bad : Str -> Problem
	bad = |why| Problem.new(BadRequest, "the move request body is not valid: ${why}")

	parse_body : List(U8) -> Try(Str, Problem)
	parse_body = |bytes| {
		text = Str.from_utf8(bytes).map_err(|_| bad("it is not UTF-8"))?
		request = Wire.decode_request(text).map_err(|BadJson(why)| bad(why))?
		Ok(request.name)
	}

	exposes_of : Str -> Try(List(Str), [BadExposes])
	exposes_of = |text| {
		parsed : Try(List(Str), _)
		parsed = Json.parse(text)
		parsed.map_err(|_| BadExposes)
	}

	check_token : Oidc.Claims -> Try({}, Problem)
	check_token = |claims| {
		Oidc.claim_is(Forbidden, "repository_visibility", claims.repository_visibility, "public")?
		Oidc.claim_is(Forbidden, "event_name", claims.event_name, "workflow_dispatch")
	}

	state_text : Identity.State -> Str
	state_text = |state| match state {
		Active => "active"
		Missing => "missing"
		Moved => "moved"
	}

	forbidden : Str -> Problem
	forbidden = |detail| Problem.new(Forbidden, detail)

	put_role : { claims : Oidc.Claims, old : Move.Old, name : Str } -> [Move({ clear_offer : Bool }), Offer, Refuse(Problem)]
	put_role = |input| {
		old = input.old
		repository = match input.claims.repository {
			Ok(r) => r
			Err(Missing) => return Refuse(forbidden("token claim repository is missing"))
		}
		is_succ = repository.caseless_ascii_equals(input.name)
		is_old = repository.caseless_ascii_equals(old.name)
		owner = input.claims.repository_owner_id
		if is_succ and owner == Ok(old.owner_id.to_str()) {
			Move({ clear_offer: Bool.True })
		} else if is_old and old.state == Active {
			Offer
		} else if is_succ and old.offer == Ok(input.name) {
			Move({ clear_offer: Bool.True })
		} else if is_old {
			Refuse(forbidden("token claim repository is \"${repository}\": the old repository ${old.name} is in the state ${state_text(old.state)}, an offer needs the state active"))
		} else if is_succ {
			match owner {
				Ok(id) => Refuse(forbidden("token claim repository_owner_id is \"${id}\": it is not the owner of ${old.name}, and ${old.name} has no offer for ${input.name}"))
				Err(Missing) => Refuse(forbidden("token claim repository_owner_id is missing"))
			}
		} else {
			Refuse(forbidden("token claim repository is \"${repository}\": it is not ${old.name} and it is not ${input.name}"))
		}
	}

	delete_role : { claims : Oidc.Claims, old : Move.Old } -> Try({}, Problem)
	delete_role = |input| {
		old = input.old
		repository = input.claims.repository ? |Missing| forbidden("token claim repository is missing")
		is_old = repository.caseless_ascii_equals(old.name)
		match old.successor {
			Ok(successor) => if is_old or repository.caseless_ascii_equals(successor) Ok({}) else Err(forbidden("token claim repository is \"${repository}\": it is not ${old.name} and it is not the successor of ${old.name}"))
			Err(None) => if is_old Ok({}) else Err(forbidden("token claim repository is \"${repository}\": it is not ${old.name}"))
		}
	}

	put_effect : Move.Old, Str -> [Same, Set, Replace]
	put_effect = |old, name| match old.successor {
		Err(None) => Set
		Ok(successor) => if successor == name Same else Replace
	}

	put_status : [Same, Set, Replace] -> U16
	put_status = |effect| match effect {
		Set => 201
		_ => 200
	}

	delete_effect : Move.Old -> [Same, Remove]
	delete_effect = |old| match old.successor {
		Err(None) => Same
		Ok(_) => Remove
	}

	set_change : { row : Identity.Row, successor : I64, now : U64 } -> Identity.Change
	set_change = |input| {
		row = { ..input.row, state: Moved, successor: Ok(input.successor), state_at: input.now }
		ids = { repository_id: row.repository_id, owner_id: row.owner_id }
		{ row, events: [Identity.event_of(row, SuccessorSet, Ok(ids), ids)] }
	}

	check : Move.Facts -> Try({}, Problem)
	check = |facts| {
		fail = |c| Err(Problem.new(SuccessorMismatch, Wire.detail(facts.name, c)))
		succ = match facts.succ {
			Err(None) => return fail(Index)
			Ok(s) => s
		}
		if succ.state != Active {
			return fail(Index)
		}
		candidate = match succ.newest {
			Err(None) => return fail(Index)
			Ok(n) => n
		}
		match facts.old_newest {
			Err(None) => {}
			Ok(o) => {
				if o.kind != candidate.kind {
					return fail(Kind)
				}
				missing = o.modules.fold([], |acc, m| if candidate.modules.contains(m) or acc.contains(m) acc else acc.append(m))
				if !missing.is_empty() {
					return fail(Exposes(missing))
				}
			}
		}
		if facts.chain.contains(facts.old.name) fail(Chain) else Ok({})
	}

	no_repo : Str -> Problem
	no_repo = |name| Problem.new(NotFound, "no package named ${name} has a repos row")
}
