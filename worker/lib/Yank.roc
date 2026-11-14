## The pure part of the yank routes `PUT` and `DELETE /v1/releases/{log_index}/yank` (Registry 7.2: R-YK1, R-YK2, R-YK4, R-YK6, R-YK7; 7.1: R-TP3, R-TP8; 5: R-RE10; slice 246, `docs/slices/246-yank.md`).
## No effect, no platform import. The effects (the body read, the operator key, the token check, the D1 session and its calls, the clock, the cache drop) are in `worker/YankRoutes.roc`.
## The tests are `worker/tests/unit/YankTest.roc` (W0) and `worker/tests/cases/yank/` (W2).
## The texts of the `detail` of a problem are proposals (TW24): the slice file section 5.
import records.Yank as Wire
import Identity
import Oidc
import Problem

Yank :: [].{

	## A body that passed `parse_body`. `reason` is `Err(None)` for no reason.
	Put : { reason : Try(Str, [None]) }

	## The two routes: `PUT` is `Yank`, `DELETE` is `Unyank` (R-RE10 `action`: `yank` 0, `unyank` 1).
	Action : [Yank, Unyank]

	## Who calls: `Author` is a GitHub OIDC token of the repository of the release (R-TP8), `Operator` is the operator key (R-YK2). R-RE10 `by`: `author` 0, `operator` 1.
	Caller : [Author, Operator]

	## The yank state of the release that the pre-read gives: `Live`, or `Yanked(by)` with the `by` of the last `yank` row of the release (R-YK4).
	State : [Live, Yanked(Yank.Caller)]

	## What `decide` gives: `NoChange` (200, no write, no cache drop), `Change` (the write batch, then 200 and the cache drop), `Refuse(problem)`.
	Verdict : [NoChange, Change, Refuse(Problem)]

	## R-YK1 (idempotent), R-YK2 (an author cannot remove a yank of the operator), R-YK4. The table (the first match gives the answer):
	## | Action | State | Caller | Verdict |
	## | --- | --- | --- | --- |
	## | `Yank` | `Yanked(_)` | any | `NoChange`: a `PUT` on a yanked release changes nothing. The reason and the `by` of the yank stay. |
	## | `Yank` | `Live` | any | `Change` |
	## | `Unyank` | `Live` | any | `NoChange`: a `DELETE` on a release that is not yanked changes nothing |
	## | `Unyank` | `Yanked(Author)` | any | `Change` |
	## | `Unyank` | `Yanked(Operator)` | `Operator` | `Change` |
	## | `Unyank` | `Yanked(Operator)` | `Author` | `Refuse(Problem.new(Forbidden, "the release is yanked by the operator: only the operator can remove this yank"))` |
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

	## R-AP48 row 6, R-AP51, R-YK6: the body of a `PUT`, before the token (R-AP48 row 7). The first fault gives the problem, 400 `bad-request`, the `detail` names the member `reason` for a fault of the reason:
	## 1. The bytes are not UTF-8, or `Wire.decode_request` (`records.Yank`) gives `BadJson(why)`: `the yank request body is not valid: <why>`.
	## 2. `Wire.check_reason`: `TooLong`: `the reason of the yank request is more than 500 bytes`. `ControlChar`: `the reason of the yank request has a control character`.
	## A body with no bytes is open (question Q246-2): the tests do not call this function with no bytes.
	parse_body : List(U8) -> Try(Yank.Put, Problem)
	parse_body = |bytes| {
		text = Str.from_utf8(bytes).map_err(|_| bad("the yank request body is not valid: it is not UTF-8"))?
		put = Wire.decode_request(text).map_err(|BadJson(why)| bad("the yank request body is not valid: ${why}"))?
		match put.reason {
			Err(None) => Ok(put)
			Ok(reason) => match Wire.check_reason(reason) {
				Ok({}) => Ok(put)
				Err(TooLong) => Err(bad("the reason of the yank request is more than ${Wire.reason_limit.to_str()} bytes"))
				Err(ControlChar) => Err(bad("the reason of the yank request has a control character"))
			}
		}
	}

	bad : Str -> Problem
	bad = |detail| Problem.new(BadRequest, detail)

	## R-TP8: the claims of a yank token after `Auth.verify!` (R-TP3 rows 1 to 3), against the repository of the release. `repository` is the lower-case `owner/repo` of the release (`releases.repo`),
	## `Err(NoRepo)` for a release on another host (`releases.repo` is NULL). Each fault is 403 `Forbidden`. The order:
	## 1. `NoRepo`: `the release has no GitHub repository: only the operator can yank it` (R-YK2).
	## 2. R-TP3 row 4: the claim `repository` is equal to `repository`, ASCII case-insensitive (the `detail` of `Oidc.check_publish`: `token claim repository is "<value>", expected "<owner/repo>"`; a missing claim: `token claim repository is missing`).
	## 3. R-TP3 row 6: `repository_visibility` is `public` (`Oidc.claim_is`).
	## 4. `event_name` is `workflow_dispatch` (`Oidc.claim_is`: `token claim event_name is "<value>", expected "workflow_dispatch"`).
	## R-TP3 rows 7 and 8 (`ref_type`, `ref`) do not apply (R-TP8): a token of a branch, or of no ref, passes. Row 5 (the ids) is `binding`.
	check_token : Oidc.Claims, Try(Str, [NoRepo]) -> Try({}, Problem)
	check_token = |claims, repository| {
		name = match repository {
			Ok(found) => found
			Err(NoRepo) => return Err(Problem.new(Forbidden, "the release has no GitHub repository: only the operator can yank it"))
		}
		claimed = claims.repository ? |Missing| Oidc.missing(Forbidden, "repository")
		if !claimed.caseless_ascii_equals(name) {
			return Err(Problem.new(Forbidden, "token claim repository is \"${claimed}\", expected \"${name}\""))
		}
		Oidc.claim_is(Forbidden, "repository_visibility", claims.repository_visibility, "public")?
		Oidc.claim_is(Forbidden, "event_name", claims.event_name, "workflow_dispatch")
	}

	## R-TP3 row 5 for a yank, the compare only (question Q246-4: a yank writes no `repos` row and no `repo_events` row). `seen` are the ids of the claims (`Publish.claims_ids`).
	## `row` is the ids of the `repos` row of the repository, `Err(NoRow)` for none. No row: `Ok`. A row: `Ok` when `repository_id` or `owner_id` is equal to the row (a transfer or a recreate passes, nothing is recorded),
	## else `Err(Changed)`: the route gives 403 `repository-changed` with `issues_url` (`Identity.changed`, `Identity.changed_json`, R-TP12), as the publish.
	binding : Identity.Ids, Try(Identity.Ids, [NoRow]) -> Try({}, [Changed])
	binding = |seen, row| match row {
		Err(NoRow) => Ok({})
		Ok(ids) => if (seen.repository_id == ids.repository_id or seen.owner_id == ids.owner_id) Ok({}) else Err(Changed)
	}

	## R-YK1: the 404 of a log index that is no release. `detail`: `no release has the log index <index>`. The text of `index` is the path segment as sent.
	no_release : Str -> Problem
	no_release = |index| Problem.new(NotFound, "no release has the log index ${index}")

	## R-RE10, R-IK7: the code of `action` (`yank` 0, `unyank` 1) and of `by` (`author` 0, `operator` 1).
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
