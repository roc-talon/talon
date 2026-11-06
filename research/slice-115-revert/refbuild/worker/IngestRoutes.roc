## The handler of the ingest `POST /v1/releases` with no `Authorization` (Registry 4: R-AP9, R-AP26, R-AP41; 7: R-PU4, R-PU6, R-PU14, R-PU15, R-PU19, R-PU26,
## R-PU31, R-PU32; 5.1: R-IK3; 7.1: R-TP5; slice 112). The decisions are in `lib/Ingest.roc` (pure, W0). This module only orders the effects.
## The tests are W2: `worker/tests/cases/ingest/`. `Err(Refuse(problem))` is a problem answer, `Err(Fault(text))` is 500 `internal` (R-AP48, never a `crash`).
## `main.roc` calls `post!` only for a request with no `Authorization` header (R-AP26: a token is a publish, slice 114).
##
## Flow (docs/slices/112-ingest.md section 3.1):
## 1. `req.bytes_with!({ max_bytes: 262144 })` (R-AP46). `Err(TooLarge)`: 413 `too-large` with `field` `body` and `limit` 262144 (as `ClosureRoute`). Another `Err`: the bytes `[]`.
##    `Ingest.parse_body`, then `Ingest.parse_url`. A refusal makes no D1 call and no GitHub call.
## 2. One session `db.with_session!(Primary)` for all the D1 calls of the request (a write reads the newest state, R-AP41 row 5).
##    D1 call 1, the pre-read: the `Ingest.LabelRow` of the label (`releases.form` = the form id, `version`, `version_text` of `target.column`; the columns of
##    `Reads.ReleaseRow` as `ReadRoutes` reads them, and `EXISTS (SELECT 1 FROM provenance WHERE release = log_index AND via = 3)` as `has_ingest`).
##    `Ingest.after_read`: `Conflict` is `Refuse`. `Answer(release)` is the answer 200 (step 7). `AddProvenance` and `Index` go on.
## 3. GitHub `GET Ingest.repo_url(target)` (headers `user-agent: talon-registry`, `accept: application/vnd.github+json`). 404: `Ingest.not_public`.
##    Another status than 200: `Ingest.github_status("repository", s)`. No answer: `github_no_answer("repository")`. `Ingest.parse_repo` refuses: `github_bad("repository")`.
##    `public` is false: `Ingest.not_public` (R-PU32: nothing is written, and the log line has the problem type only).
## 4. `AddProvenance(log_index)`: D1 call 2, one batch: the provenance statement of section 3.2 row 8 and the read of step 2. Status 200 (step 7).
## 5. `Index`: GitHub `GET Ingest.release_url(target)` (the same headers). 404: `Ingest.no_release(tag)`. Another status: `github_status("release", s)`. No answer, or
##    `Ingest.parse_release` refuses: `github_no_answer("release")`, `github_bad("release")`. Then `Ingest.candidate`.
##    `Archive.read!(target.url, target.hash)`: `Refused(r)` is `ArchiveRead.problem(r)`, `Upstream(u)` is `ArchiveRead.upstream_problem(u)` (502), `Fault` is `Fault`.
##    GitHub `GET Ingest.roc_version_url(target)` with the header `user-agent: talon-registry`: 200 is `Ok(Ingest.roc_version_of(text))`, 404 is `Err(None)`,
##    another status `github_status(".roc-version", s)`, no answer `github_no_answer(".roc-version")`.
## 6. `Ingest.plan` with `Time.now_ms!()` (once for the request). D1 call 2: one batch with the statements of the slice file section 3.2, in that order, and last the read of step 2.
##    `Err(Constraint(c))`: `Ingest.batch_failure(c)`. `LabelConflict`: `Refuse(Ingest.label_conflict(target, Err(None)))`. `IdCollision`: D1 call 3, the read of
##    `Ingest.NameRow` for the ids of `plan.names`, then `Refuse(Ingest.collision(plan.names, rows))`. `Fault`: `Fault`.
## 7. The answer: the status `Ingest.status_of(<changes of the releases statement>)` (200 for steps 2 and 4), `content-type: application/json`,
##    `cache-control: Ingest.cache_control`, the body `Ingest.answer_body(release)` (`Reads.release_of_row` of the row of the last statement),
##    `talon-bookmark: <session.bookmark!()>` after the last D1 call (R-AP41 row 5), and for a 201 `location: Ingest.location(hash)`.
import pf.Request
import pf.Response
import lib.Problem

IngestRoutes :: [].{

	## The error of the handler: the same form as `ReadRoutes.Error`.
	Error : [Refuse(Problem), Fault(Str)]

	post! : Request => Try(Response, IngestRoutes.Error)
	post! = |_req| crash "todo"
}
