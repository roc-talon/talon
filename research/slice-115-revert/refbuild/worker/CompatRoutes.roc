## The handler of `POST /v1/compat`, the bot path (Registry R-AP10, R-AP41, R-AP46, R-AP48, R-MX4, R-MX5, R-MX8 to R-MX10; slice 115a). The decisions are in `lib/Compat.roc` (pure, W0).
## The tests are W2: `worker/tests/cases/compat/`. The SQL of the bot set is `sql/compat/*.sql` in this dir (W1: `sql/tests/cases/compat/`).
## STUB (test agent): `post!` is `crash "todo"`. The flow (the slice file section 3.3):
## 1. `req.bytes_with!({ max_bytes: Compat.body_limit })`. `Err(TooLarge)`: the 413 answer of `Compat.too_large("body", Compat.body_limit)`. Another `Err`: the bytes `[]` (then 400).
## 2. `Compat.request_kind` of the headers `authorization` and `talon-contributor`. `Refuse(problem)` is the answer (400, R-CT1). `Hint` is the user path of slice 116: `Err(Fault(..))` here.
##    `Bot` goes on. (The bot path reads the body before the token check: R-AP48 rows 4 to 6 come before the route, R-AP66 checks 1 to 7, Design Q144. The media type of a body is a header: a body that is too large and not JSON is 415, `Route.decide` gives it before this handler.)
## 3. `Compat.parse_post(bytes)`. `Err(Bad(problem))`: `Err(Refuse(problem))`. `Err(TooLarge(problem, extra))`: `Ok` of the 413 answer
##    `Response.from_bytes(413, "application/problem+json", Problem.to_json_with(problem, extra).to_utf8())`. No D1 call before this step.
## 4. `Auth.bot!(req)` (slice 108). `Err(problem)` is the answer (401, 403, 500, 502), no D1 call.
## 5. D1 call 1: one `batch!` of 3 statements on the primary: `artifacts`, `targets` and `artifact_targets` for the lists of `Compat.read_params(post)`. `Compat.plan`: `Err(problem)` is the
##    answer (404, 400). A body with no row skips this call and step 6 writes only the sweep.
## 6. D1 call 2: one `batch!` of the row statement (`Compat.rows_sql()`, if there are rows) and the sweep statement (`Compat.sweep_sql()`, if the body has a sweep), with `Time.now_ms!()` once.
##    `written` is the `changes` of the row statement (no trigger fires on `compat`). On a `Constraint` error `Compat.failure_of`: `Bad(problem)` is the answer; `Fault(text)` is `Err(Fault)`;
##    `SweepIncomplete` goes to step 7.
## 7. D1 call 3 on the primary (only after `SweepIncomplete`, R-AP41 "error detail", R-AP66 check 10): the statement `missing` of `sql/compat/` with the sweep as parameters, the state after the
##    rollback; `Compat.sweep_incomplete` is the 422 answer, also for an empty list.
## 8. 201 or 200 by `Compat.written_status`, `content-type: application/json`, `cache-control: no-store`, the body `Compat.written_body(written)`.
import pf.Request
import pf.Response
import ReadRoutes

CompatRoutes :: [].{

	post! : Request => Try(Response, ReadRoutes.Error)
	post! = |_req| crash "todo"
}
