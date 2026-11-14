## PRIVATE REFERENCE of slice 246 (not for the code agent, TW18). Bodies for worker/lib/Yank.roc.
import records.Yank as Wire
import Identity
import Oidc
import Problem

Yank :: [].{

	Put : { reason : Try(Str, [None]) }
	Action : [Yank, Unyank]
	Caller : [Author, Operator]
	State : [Live, Yanked(Yank.Caller)]
	Verdict : [NoChange, Change, Refuse(Problem)]

	decide : Yank.Action, Yank.Caller, Yank.State -> Yank.Verdict
	decide = |action, caller, state| match (action, state) {
		(Yank, Yanked(_)) => NoChange
		(Yank, Live) => Change
		(Unyank, Live) => NoChange
		(Unyank, Yanked(Author)) => Change
		(Unyank, Yanked(Operator)) => match caller {
			Operator => Change
			Author => Refuse(Problem.new(Forbidden, "the release is yanked by the operator: only the operator can remove this yank"))
		}
	}

	parse_body : List(U8) -> Try(Yank.Put, Problem)
	parse_body = |bytes| {
		text = Str.from_utf8(bytes).map_err(|_| bad("it is not UTF-8"))?
		request = Wire.decode_request(text).map_err(|BadJson(why)| bad(why))?
		match request.reason {
			Ok(reason) => match Wire.check_reason(reason) {
				Ok({}) => Ok({ reason: Ok(reason) })
				Err(TooLong) => Err(Problem.new(BadRequest, "the reason of the yank request is more than 500 bytes"))
				Err(ControlChar) => Err(Problem.new(BadRequest, "the reason of the yank request has a control character"))
			}
			Err(None) => Ok({ reason: Err(None) })
		}
	}

	bad : Str -> Problem
	bad = |why| Problem.new(BadRequest, "the yank request body is not valid: ${why}")

	check_token : Oidc.Claims, Try(Str, [NoRepo]) -> Try({}, Problem)
	check_token = |claims, repository| match repository {
		Err(NoRepo) => Err(Problem.new(Forbidden, "the release has no GitHub repository: only the operator can yank it"))
		Ok(want) => {
			got = claims.repository ? |Missing| Oidc.missing(Forbidden, "repository")
			if !got.caseless_ascii_equals(want) {
				Err(Problem.new(Forbidden, "token claim repository is \"${got}\", expected \"${want}\""))
			} else {
				Oidc.claim_is(Forbidden, "repository_visibility", claims.repository_visibility, "public")?
				Oidc.claim_is(Forbidden, "event_name", claims.event_name, "workflow_dispatch")
			}
		}
	}

	binding : Identity.Ids, Try(Identity.Ids, [NoRow]) -> Try({}, [Changed])
	binding = |seen, row| match row {
		Err(NoRow) => Ok({})
		Ok(ids) => if (seen.repository_id == ids.repository_id or seen.owner_id == ids.owner_id) Ok({}) else Err(Changed)
	}

	no_release : Str -> Problem
	no_release = |index| Problem.new(NotFound, "no release has the log index ${index}")

	action_code : Yank.Action -> U8
	action_code = |action| match action {
		Yank => 0
		Unyank => 1
	}

	by_code : Yank.Caller -> U8
	by_code = |caller| match caller {
		Author => 0
		Operator => 1
	}
}
