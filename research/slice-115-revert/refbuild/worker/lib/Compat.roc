## The pure part of `POST /v1/compat`, the bot path (Registry 4.1: R-AP10, R-AP41, R-AP46, R-AP48, R-AP51; 6: R-MX4, R-MX5, R-MX8 to R-MX10; R-RE3, R-RE13; slice 115a).
## No effect, no platform import. The effects (the body read, the token check, the D1 calls, the clock) are in `worker/CompatRoutes.roc`.
## The SQL of the bot set is in `worker/sql/compat/*.sql`. The W1 cases `sql/tests/cases/compat/` run the same files.
## The tests are `worker/tests/unit/CompatTest.roc` (W0) and `worker/tests/cases/compat/` (W2). The slice file is `docs/slices/115a-compat-post.md`.
## The `detail` texts and the SQL texts are proposals for the human review (TW24): the slice file section 6.
## STUB (test agent): every body is `crash "todo"`. The doc comment of each function is the rule.
import records.Code
import ClosureQuery
import Problem

Compat :: [].{

	## R-AP46: the request body, in bytes (256 KB).
	body_limit : U64
	body_limit = 262_144

	## R-AP46: the items of `rows` (first guess).
	row_limit : U64
	row_limit = 500

	## R-MX9: the most hashes that the `detail` of a 422 `sweep-incomplete` lists.
	missing_limit : U64
	missing_limit = 100

	## A row of the body (R-AP10) after the checks of `parse_post`. `hash` is the text as sent, `artifact` its id (`Reads.artifact_id`), `nightly` the id of the tag
	## (`Id.nightly_id`), `target` the name as sent, `result` the code of the text, `error_digest` the text or `Err(None)` for `null` (R-AP66, Design Q140).
	Row : { hash : Str, artifact : I64, nightly : I64, target : Str, result : Code.Result, error_digest : Try(Str, [None]) }

	## The sweep of the body (R-MX4): `tag` as sent, `nightly` its id, `upto_log_index` in 0 to 2^63 - 1. Its target is `any` (checked).
	Sweep : { tag : Str, nightly : I64, upto_log_index : U64 }

	## A body that passed `parse_post`: the rows in the order of the body, the sweep if the body has one (`sweep` absent or `null` is `Err(None)`).
	Post : { rows : List(Compat.Row), sweep : Try(Compat.Sweep, [None]) }

	## A refused body. The same type as the closure route: `Bad(problem)` is a 400, `TooLarge(problem, { field, limit })` is a 413 with the members `field` and `limit`.
	Reject : ClosureQuery.Reject

	## R-AP46: the 413 of a field and its limit, for example `too_large("rows", 500)`. The route also gives it for a body that `Request.bytes_with!` refuses (`field` `body`).
	## `detail`: `the <field> of the compat request is larger than its limit of <n>`.
	too_large : Str, U64 -> Compat.Reject
	too_large = |_field, _limit| crash "todo"

	## The checks 2 and 4 to 6 of R-AP66 (R-AP48 rows 4 and 6), in this order. The first that fails gives the answer, and the route makes no D1 call. Step 2 calls
	## `records.Compat.decode_post` (slice 104d): `BadJson(text)` is a 400 whose `detail` names the member. `decode_post` keeps `result` and `nightly` as text, so the
	## limit of step 3 comes before the value checks of step 4, which stay here:
	## 1. More than `body_limit` bytes: 413, field `body`.
	## 2. The body is not valid (400 `bad-request`, the `detail` names the member for a missing one, R-AP51): not UTF-8, not JSON, not an object, `rows` missing or `null`,
	##    a wrong JSON type, a row that is not an object, a row without `hash`, `nightly`, `target`, `result` or `error_digest` (`null` is allowed for `error_digest`, R-AP66, Design Q140),
	##    `sweep` that is not an object or `null`, a sweep without `nightly`, `target` or `upto_log_index`, an `upto_log_index` that is negative or not an integer.
	##    A member that is not known is ignored (R-AP44) with one exception, `source` (R-MX5): a body that has a member `source` (any value, also `null`) gets 400, in the
	##    body object and in each row (R-AP66 check 4, Design Q139). A text that holds the word (`"error_digest":"source"`, a digest that holds `\"source\":`) is not a member. A key written
	##    with an escape (`"source"`) is the member `source`.
	## 3. More than `row_limit` rows: 413, field `rows`, limit 500. (R-AP66, Design Q143: the limit comes before the checks of the values, as R-AP62 does for the closure.)
	## 4. The values of all rows (Design Q142: before the D1 facts), in the order of the rows, and then the sweep; in a row `hash`, then `nightly`, then `result`: a `hash` that is not base58 of exactly 32 bytes (R-AP66, Design Q141), a `nightly` or sweep tag that has no nightly id
	##    (`Id.nightly_id`, R-IK4), a `result` that is not `pass`, `fail`, `hang` or `crash`, a sweep `target` that is not `any` (R-MX4), a sweep `upto_log_index` above 2^63 - 1.
	## `rows: []` is valid (the sweep may be alone), and a body with no sweep and no rows is valid.
	parse_post : List(U8) -> Try(Compat.Post, Compat.Reject)
	parse_post = |_body| crash "todo"

	## R-AP46 row 2: the two lists of the read batch, as JSON text for `json_each`. `artifacts_json`: the ids of the distinct `artifact` of the rows, in the order of the first
	## row that has it, as JSON integers (`[11,-5]`, R-IK2: 64-bit). `targets_json`: the distinct `target` names of the rows other than `any`, in the same order, as JSON strings.
	read_params : Compat.Post -> { artifacts_json : Str, targets_json : Str }
	read_params = |_post| crash "todo"

	## A row of `artifacts` for the ids in `artifacts_json`: `SELECT CAST(artifact AS TEXT) AS artifact, kind FROM artifacts WHERE artifact IN (...)`. `kind` is the code of R-IK7.
	ArtifactFact : { artifact : I64, kind : I64 }

	## A row of `targets` for the names in `targets_json`: the name and its code (R-IK7, R-RE21).
	TargetFact : { name : Str, target : I64 }

	## A row of `artifact_targets` for the ids in `artifacts_json`: the artifact (`CAST(... AS TEXT)`) and the code of a target of a platform (R-RE20).
	PlatformFact : { artifact : I64, target : I64 }

	## What the read batch (D1 call 1) gives.
	Facts : { artifacts : List(Compat.ArtifactFact), target_rows : List(Compat.TargetFact), platform_targets : List(Compat.PlatformFact) }

	## A row after `plan`: the codes that the write needs (R-IK7): `target` 0 for `any`, `result` 0 to 3.
	PlanRow : { artifact : I64, nightly : I64, target : I64, result : U8, error_digest : Try(Str, [None]) }

	## R-AP10 and R-MX10 against the read batch. The rows are checked in order. The first row that fails gives the problem:
	## 1. The `artifact` of the row has no fact in `artifacts`: 404 `not-found` (`Reads.no_artifact(hash)`: the `detail` names the hash). Nothing is written.
	## 2. The `target` is `any`: code 0, for each kind of artifact.
	## 3. Another target: the kind of the artifact must be platform (2), else 400 `bad-request`. The name must be in `targets` (a name with no code is 400, R-IK7), and the pair
	##    (artifact, code) must be in `platform_targets` (R-MX10: "whose `targets` has that target"), else 400. The `detail` of these 400 names the target.
	## For one row the check 1 comes before the checks of 3. The `rows` of the plan are in the order of the post. R-AP66 check 8 (Design Q142): the first row that fails gives the
	## answer, so a 400 of row 1 comes before a 404 of row 2, and a 404 of row 1 before a 400 of row 2. The static checks of all rows were done by `parse_post`.
	plan : Compat.Post, Compat.Facts -> Try(List(Compat.PlanRow), Problem)
	plan = |_post, _facts| crash "todo"

	## The parameter of the row statement: the JSON text of the rows for `json_each`. The members are the contract between this function and `rows_sql`. `error_digest` is a JSON
	## string or `null`; the ids are JSON integers.
	rows_json : List(Compat.PlanRow) -> Str
	rows_json = |_rows| crash "todo"

	## The text of the row statement (R-RE13 row 1, R-MX8, Q86). It takes `rows_json` as ?1 and the time in ms (R-RE26) as ?2 and writes one `compat` row for each item with `source`
	## 0 (bot, R-MX5), `log_index` NULL. It ends with `ON CONFLICT DO NOTHING`, never `INSERT OR IGNORE` (`OR IGNORE` also drops a row that fails a `CHECK`: R-CT4, Q86).
	rows_sql : () -> Str
	rows_sql = || crash "todo"

	## The text of the sweep statement (R-MX8): `INSERT INTO sweeps ... ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
	## WHERE excluded.upto_log_index > sweeps.upto_log_index`, with ?1 the nightly id, ?2 the target code 0, ?3 the bound, ?4 the time. Never `INSERT OR REPLACE`.
	sweep_sql : () -> Str
	sweep_sql = || crash "todo"

	## The status of the 2xx answer (R-AP10): 201 when `written` is above 0, else 200.
	written_status : U64 -> U16
	written_status = |_written| crash "todo"

	## The body of the 2xx answer: `{"written":<n>}`.
	written_body : U64 -> Str
	written_body = |_written| crash "todo"

	## A `Constraint` of a failed batch (`Sql.Constraint` of the platform, MODULES.md 5.1). The kinds are those of the platform.
	Constraint : { kind : [PrimaryKey, Unique, ForeignKey, Check, NotNull, Trigger, Datatype, Other], message : Str }

	## What a failed write batch is (R-MX9). The whole `message`, not a part, and the kind:
	## `Trigger` and `sweep-incomplete`: `SweepIncomplete` (the route reads the missing hashes in D1 call 3 on the primary, then `sweep_incomplete`). `Trigger` and `sweep-bound`: `Bad(problem)`, 400
	## `bad-request`, `detail` `the sweep upto_log_index is larger than the log size`. Everything else (another text, `sweep-smaller`, `leaf-missing`, another kind with the
	## text `sweep-incomplete`, a text that only has `sweep-bound`): `Fault(text)`, 500 `internal`. A user hint never gets these (R-MX9).
	failure_of : Compat.Constraint -> [SweepIncomplete, Bad(Problem), Fault(Str)]
	failure_of = |_c| crash "todo"

	## R-AP21, R-MX9: the 422 `sweep-incomplete`. `missing` is the base58 of each member of the bot set at the bound that has no `bot` row, in the order of the read (hash bytes).
	## The `detail` lists at most `missing_limit` of them (the first ones, in that order):
	##   up to 100: `the sweep of <tag> up to the log index <n> is incomplete: <k> members of the bot set have no bot row: <h1>, <h2>`
	##   over 100:  `... have no bot row: <h1>, ..., <h100>, and <k - 100> more`
	##   empty (R-AP66 check 10, Design Q145: another request wrote the rows between call 2 and call 3): the answer stays 422, `the sweep of <tag> up to the log index <n> was
	##   incomplete, but no member has no bot row now: send the request again`. The route calls this function with the list of call 3, also when it is empty.
	##   The list is the state after the rollback, so it holds the members whose rows were in the failed request.
	sweep_incomplete : { tag : Str, upto_log_index : U64, missing : List(Str) } -> Problem
	sweep_incomplete = |_x| crash "todo"

	## R-MX5, R-CT1: what the Authorization header and the header `Talon-Contributor` select. A request with an `Authorization` header is `Bot` (the token check follows; the
	## contributor header is ignored). With no `Authorization` and a `Talon-Contributor`: `Hint` (slice 116). With neither: `Refuse(problem)`, 400 `bad-request`.
	request_kind : { authorization : Try(Str, [NotFound]), contributor : Try(Str, [NotFound]) } -> [Bot, Hint, Refuse(Problem)]
	request_kind = |_h| crash "todo"
}
