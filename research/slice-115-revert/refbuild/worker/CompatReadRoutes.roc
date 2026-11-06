## The handlers of `GET /v1/sweeps/{tag}`, `GET /v1/compat_hints` and `GET /v1/artifacts/{hash}/compat` (Registry R-AP4, R-AP39, R-AP40, R-AP41, R-AP43, R-AP54 to R-AP56; slice 115b).
## The decisions are in `lib/CompatReads.roc` (pure, W0). The tests are W2: `worker/tests/cases/compat/`. The SQL is `sql/compat/*.sql` in this dir (W1: `sql/tests/cases/compat/`).
## STUB (test agent): each function is `crash "todo"`. The flow (the slice file section 3):
## `sweep!`: `CompatReads.parse_sweep_target(req.query("target"))` (400, no D1 call); `Id.nightly_id(tag)`, `Err` is 404 `CompatReads.no_tag(tag)` (no D1 call); one batch (one session,
##   `Reads.session_of(talon-bookmark)`): the `toolchains` tag of the nightly, the `sweeps` row, `log_size`, the count of members, the missing hashes; no `toolchains` row is 404; 200,
##   `no-store`, `CompatReads.sweep_body`. No ETag, no Cache API.
## `audit!`: `CompatReads.parse_audit(req.query("audit"))` (400, no D1 call); then the read mechanism of the read routes (`ReadRoutes.serve!` with `CompatReads.cache_control`):
##   the Cache API, the ETag and 304, one session and one statement; `CompatReads.pairs_body`.
## `artifact_compat!`: `Reads.artifact_id(hash)`, `Err(BadHash)` is 404 `Reads.no_artifact(hash)` with no D1 call; `ReadRoutes.serve!` with `CompatReads.cache_control`; one batch: the
##   artifact row (no row: 404 `Reads.no_artifact`, not put in the Cache API), `runs`, `hints`; `CompatReads.compat_body`.
import pf.Request
import pf.Response
import ReadRoutes

CompatReadRoutes :: [].{

	sweep! : Request, Str => Try(Response, ReadRoutes.Error)
	sweep! = |_req, _tag| crash "todo"

	audit! : Request => Try(Response, ReadRoutes.Error)
	audit! = |_req| crash "todo"

	artifact_compat! : Request, Str => Try(Response, ReadRoutes.Error)
	artifact_compat! = |_req, _hash| crash "todo"
}
