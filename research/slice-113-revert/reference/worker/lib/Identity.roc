## Repository identity: the `repos` row of a name against the GitHub ids that a write or a read shows (Registry 7.1 R-TP5; 7.3 R-TP9 to R-TP13; R-RE11, R-RE15;
## R-PU24 state part; slice 113). Pure: no effect, no platform import. The effects (the D1 reads and writes, the GitHub reads) are in `worker/IngestRoutes.roc` today, and
## in the publish (114), the webhook (118) and the reconcile (119) later. They all call these decisions, so the 4 rows of R-TP9 are written once.
## The tests are in `worker/tests/unit/IdentityTest.roc` (W0) and `worker/tests/cases/identity/` (W2). The slice file is `docs/slices/113-repo-identity.md`.
## The texts of the 403 answer are proposals (TW24): the slice file section 5.
import Problem

Identity :: [].{

	# ---- the rows ----

	## The GitHub ids of a repository: `id` and `owner.id` of the answer of `GET /repos/{owner}/{repo}` or `GET /repositories/{id}`, or the claims
	## `repository_id` and `repository_owner_id` of a token (R-TP3 row 5).
	Ids : { repository_id : U64, owner_id : U64 }

	## R-TP11, R-RE11: the codes of the column `repos.state` are `Active` 0, `Missing` 1, `Moved` 2.
	State : [Active, Missing, Moved]

	## A `repos` row (R-RE11). `repo` is the id of the lower-case `owner/repo` (R-IK2: `Id.name_id(3, ...)`). `successor` is a repo id (R-TP14).
	## `time` is the time of the first write of the name and never changes (R-TP5; the owner count of R-PU34 row 2 reads it). `state_at` is the time of the last change of
	## `state` or `successor` (a proposal, TW24: the R-AP32 member `state_at`).
	Row : { repo : I64, repository_id : U64, owner_id : U64, state : Identity.State, successor : Try(I64, [None]), state_at : U64, time : U64 }

	## R-RE15, R-TP13: the codes of the column `repo_events.action` are `Bind` 0, `Transfer` 1, `Rename` 2, `Recreate` 3, `Missing` 4, `Found` 5, `SuccessorSet` 6,
	## `SuccessorRemoved` 7, `Offer` 8, `Operator` 9. Slice 113 writes the first six. The others are the slices 114 (none), the move route (P3) and the operator.
	Action : [Bind, Transfer, Rename, Recreate, Missing, Found, SuccessorSet, SuccessorRemoved, Offer, Operator]

	## One row of `repo_events` without its `seq` and its time. The writer adds `seq` (the next number of `repo` in the table) and the clock of the request, and `claims` is NULL
	## (the claims of a token are the publish, slice 114). `repository_id_*` and `owner_id_*` are the ids before and after the event (`Err(None)` before a `Bind`).
	## `successor` is the successor of the row after the event.
	Event : {
		repo : I64,
		action : Identity.Action,
		repository_id_before : Try(U64, [None]),
		repository_id_after : Try(U64, [None]),
		owner_id_before : Try(U64, [None]),
		owner_id_after : Try(U64, [None]),
		successor : Try(I64, [None]),
	}

	## The new state of a row and the events of the change (none: the row is not changed and nothing is written for the identity).
	Change : { row : Identity.Row, events : List(Identity.Event) }

	state_code : Identity.State -> U8
	state_code = |state| match state {
		Active => 0
		Missing => 1
		Moved => 2
	}

	action_code : Identity.Action -> U8
	action_code = |action| match action {
		Bind => 0
		Transfer => 1
		Rename => 2
		Recreate => 3
		Missing => 4
		Found => 5
		SuccessorSet => 6
		SuccessorRemoved => 7
		Offer => 8
		Operator => 9
	}

	# ---- R-TP9: the ids against the row ----

	## R-TP9 (with R-TP5, R-TP11). `row` is the `repos` row of the name `repo`, or `Err(None)`. `seen` is what the write or the read shows. The first case that fits gives the result:
	## 1. No row (R-TP5, Design Q163): `Ok` with the new row (`Active`, no successor, `state_at` and `time` = `now`) and one event `Bind` (before `Err(None)`, after the ids).
	## 2. Both ids are different (R-TP9 row 4), in any state: `Err(Changed)`. Nothing is written.
	## 3. The same `repository_id` and the same `owner_id` (row 1): the row is the same. A row in the state `Missing` becomes `Active`, `state_at` = `now`, event `Found`
	##    (R-TP11: a read of the same `repository_id` succeeds). A row in the state `Moved` stays as it is, with no event (Registry R-TP18 rows 3 and 5: the rename back is SQL of the ingest, not `decide`).
	## 4. The same `repository_id`, another `owner_id` (row 2, a transfer): the row gets the new `owner_id`, event `Transfer` (R-TP9). A row in the state `Missing` is also `Active`
	##    with an event `Found` after the `Transfer` (R-TP11).
	## 5. The same `owner_id`, another `repository_id` (row 3, the owner made the repository again): the row gets the new `repository_id`, the state `Active` and no successor,
	##    one event `Recreate` and no `Found`. `state_at` = `now` when the state or the successor changed, else it stays.
	## `time` never changes. In each event the successor is the successor of the row after the change. Without a change, `events` is `[]` and `row` is the given row.
	decide : { repo : I64, row : Try(Identity.Row, [None]), seen : Identity.Ids, now : U64 } -> Try(Identity.Change, [Changed])
	decide = |input| {
		seen = input.seen
		match input.row {
			Err(None) => {
				row = { repo: input.repo, repository_id: seen.repository_id, owner_id: seen.owner_id, state: Active, successor: Err(None), state_at: input.now, time: input.now }
				Ok({ row, events: [event(input.repo, Bind, Err(None), seen, Err(None))] })
			}
			Ok(row) => {
				same_repo = row.repository_id == seen.repository_id
				same_owner = row.owner_id == seen.owner_id
				if !same_repo and !same_owner {
					Err(Changed)
				} else {
					before = { repository_id: row.repository_id, owner_id: row.owner_id }
					# row 3 of R-TP9: a new repository of the same owner
					recreated = !same_repo
					# the state and the successor after the change
					back = if (recreated) { state: Active, successor: Err(None) } else if (row.state == Missing) { state: Active, successor: row.successor } else { state: row.state, successor: row.successor }
					moved_state = back.state != row.state or back.successor != row.successor
					after = { repo: row.repo, repository_id: seen.repository_id, owner_id: seen.owner_id, state: back.state, successor: back.successor, state_at: if (moved_state) input.now else row.state_at, time: row.time }
					transfer = same_repo and !same_owner
					found = !recreated and row.state == Missing
					mid = { repository_id: seen.repository_id, owner_id: seen.owner_id }
					events = []
						.concat(if (recreated) [event(row.repo, Recreate, Ok(before), mid, back.successor)] else [])
						.concat(if (transfer) [event(row.repo, Transfer, Ok(before), mid, back.successor)] else [])
						.concat(if (found) [event(row.repo, Found, Ok(mid), mid, back.successor)] else [])
					Ok({ row: after, events })
				}
			}
		}
	}

	event : I64, Identity.Action, Try(Identity.Ids, [None]), Identity.Ids, Try(I64, [None]) -> Identity.Event
	event = |repo, action, before, after, successor| {
		repo,
		action,
		repository_id_before: before.map_ok(|b| b.repository_id),
		repository_id_after: Ok(after.repository_id),
		owner_id_before: before.map_ok(|b| b.owner_id),
		owner_id_after: Ok(after.owner_id),
		successor,
	}

	## R-TP11 and R-PU24 (state part), for the webhook and the reconcile (slices 118, 119): the repository is not found or not public now. An `Active` row becomes `Missing`
	## (`state_at` = `now`, event `Missing` with the same ids before and after). The ids and the binding stay (R-TP9 row 4). A `Missing` row is the same, with no event.
	## A `Moved` row: the same row, no event (R-TP19, Design Q265): the state `missing` is for the row of the current name. This function does not change `releases.withdrawn`.
	went_missing : { row : Identity.Row, now : U64 } -> Identity.Change
	went_missing = |input| {
		row = input.row
		if row.state == Active {
			ids = { repository_id: row.repository_id, owner_id: row.owner_id }
			{ row: { ..row, state: Missing, state_at: input.now }, events: [event(row.repo, Missing, Ok(ids), ids, row.successor)] }
		} else {
			{ row, events: [] }
		}
	}

	# ---- R-TP10: a rename ----

	## `GET /repositories/{repository_id}`: the read by id (R-TP10, R-PU31). The Worker `fetch` follows the 301 of the old name to this URL (MODULES.md 4).
	repo_by_id_url : U64 -> Str
	repo_by_id_url = |id| "https://api.github.com/repositories/${id.to_str()}"

	## R-TP10: the `full_name` of the GitHub answer (`GET /repos/{owner}/{repo}` or `GET /repositories/{id}`). A text that is not JSON, or with no text member `full_name`,
	## is `Err(BadRepo)` (502). Unknown members are ignored.
	full_name_of : Str -> Try(Str, [BadRepo])
	full_name_of = |text| {
		parsed : Try({ full_name : Str }, _)
		parsed = Json.parse(text)
		match parsed {
			Ok(r) => Ok(r.full_name)
			Err(_) => Err(BadRepo)
		}
	}

	## R-TP10: is the answer for the name a rename? `name` is the lower-case name of the request. `Ok(current)` when `full_name` is another name, ignoring the case of ASCII letters,
	## and `current` is `full_name` in lower case. `Err(Same)` for the same name.
	renamed : Str, Str -> Try(Str, [Same])
	renamed = |name, full_name| {
		current = full_name.with_ascii_lowercased()
		if (current == name.with_ascii_lowercased()) Err(Same) else Ok(current)
	}

	# ---- R-TP12: the answer 403 ----

	## R-TP9 row 4, R-TP12: 403 `repository-changed`. `name` is the lower-case name of the request, `repository_id` the id of the row (the bound repository).
	## The text is a proposal (TW24), after the `tln` message of R-TP12.
	changed : Str, U64 -> Problem
	changed = |name, repository_id| Problem.new(RepositoryChanged, "the name ${name} is bound to another GitHub account (repository id ${repository_id.to_str()})")

	## R-TP12: the problem body with one more member, `issues_url`, the value of the Worker setting `ISSUES_URL`. The members of `Problem.to_json` are the same
	## (`type`, `title`, `status`, `detail`). The caller sets the media type `application/problem+json`.
	changed_json : Problem, Str -> Str
	changed_json = |problem, issues_url| Problem.to_json(problem).drop_suffix("}").concat(",\"issues_url\":${Json.to_str(issues_url)}}")
}
