import lib.Fail
import records.Audit
import records.Compat
import records.Work

## The compat bot, part A (slice 223; Registry R-MX1, R-MX4, R-MX10, R-MX13, R-MX15, R-MX17, R-AP2, R-AP6, R-AP10, R-AP39, R-AP40). Pure decisions. Stubs: the code agent writes the bodies.
## The doc of each function says the rule. The slice file `docs/slices/223-compat-bot.md` has the questions: a function that a question touches says so.
Bot :: [].{

	## Slice 104k (Design Q575): the answers of R-AP39 and R-AP40 are `records.Work.Answer` (`sweep : Try(Work.Sweep, [None])` with `time`, `log_size`, `members`, `missing`: the hashes without a `bot` row, each once) and `records.Audit.Pair`
	## (`hash`, `nightly`, `target`, `pass_count`, `fail_count`, `crash_count`). The flow decodes with `Work.decode` and `Audit.decode`. Slice 223 depends on 104k.

	## The URL of each route that the bot calls. `origin` is the base URL form of the registry (CLI 1, R-RG7), with no `/` at the end.
	##
	## | Route | URL | Rule |
	## | --- | --- | --- |
	## | `Put(tag)` | `<origin>/v1/toolchains/<tag>` | R-AP6 |
	## | `Sweeps(tag)` | `<origin>/v1/sweeps/<tag>` (no `target`: the default `any`, R-AP67) | R-AP39 |
	## | `Audit(n)` | `<origin>/v1/compat_hints?audit=<n>` | R-AP40 |
	## | `Artifact(hash)` | `<origin>/v1/artifacts/<hash>` | R-AP2 (question Q1) |
	## | `Compat` | `<origin>/v1/compat` | R-AP10 |
	url : { origin : Str, route : [Put(Str), Sweeps(Str), Audit(U64), Artifact(Str), Compat] } -> Str
	url = |_x| crash "todo: slice 223"

	## R-AP2, R-MX18 item 1 (Q566): the `url` of the first row of `releases` whose `withdrawn` is `null` (any `yanked`), in `GET /v1/artifacts/{hash}` (`{artifact, releases, repos}`). No such row: `Err(NoRelease)`.
	release_url : Str -> Try(Str, [BadJson(Str), NoRelease])
	release_url = |_text| crash "todo: slice 223"

	## The job that downloads the archive of a hash to `<dir>/<hash>.tar.zst`: `curl -fsSL --output <dir>/<hash>.tar.zst <url>`.
	fetch_job : { dir : Str, hash : Str, url : Str } -> List(Str)
	fetch_job = |_x| crash "todo: slice 223"

	## The job that is one unit probe (R-MX15, R-PB1, R-PB7): `env ROC_TOOLCHAIN=<tag> tln probe --json --yes <dir>/<hash>.tar.zst` (R-MX18 item 1).
	probe_job : { dir : Str, tag : Str, hash : Str } -> List(Str)
	probe_job = |_x| crash "todo: slice 223"

	## R-MX17, R-AP10: the matrix row of one probe from the `stdout` of `tln probe --json` (`data` of CLI 3 R-J3, R-J4; ProbeCmd `Unit`). `target` is `any`, `result` is `data.outcome`
	## (`pass`, `fail`, `hang`, `crash`), `error_digest` is null (Q569). `Err(why)` when the document is not JSON, has `ok` false, is not `kind` `unit`, has another `hash`, or a `compiler` with another nightly id than `tag`
	## (R-IK4: `nightly-2026-July-31-123c5d7` and `nightly-2026-07-31-123c5d7` are equal, Q570): such a probe gives no row.
	row : { tag : Str, hash : Str, stdout : Str } -> Try(Compat.Row, Str)
	row = |_x| crash "todo: slice 223"

	## R-MX4: the sweep of the run. `Ok({ nightly: tag, target: "any", upto_log_index: work.log_size })` when each hash of `work.missing` is in `rowed` (the hashes that have a row of this run), else `Err(None)`.
	## The bound is the log size that the bot read before its probes. An empty `missing` is complete.
	sweep : { tag : Str, work : Work.Answer, rowed : List(Str) } -> Try(Compat.Sweep, [None])
	sweep = |_x| crash "todo: slice 223"

	## R-MX13, R-MX10 (the cost table: the audit is grouped by nightly, so each older nightly downloads once): the unit pairs (`target` `any`) of the audit, as one group for each nightly,
	## in the order of the first pair of the nightly, and the hashes of a group in the order of the pairs. A pair of another target is a smoke build (Q568): it is not in a group.
	audit_groups : List(Audit.Pair) -> List({ nightly : Str, hashes : List(Str) })
	audit_groups = |_pairs| crash "todo: slice 223"

	## R-MX18 item 2 (Q567): the tags of a GitHub release list (`GET https://api.github.com/repos/roc-lang/nightlies/releases?per_page=7`, an array of objects with `tag_name`): the tags that read as a nightly (R-IK4), the others dropped,
	## in the order of R-NS1, oldest first (the list is newest first). Not JSON, or not an array: `BadJson`. An empty result is `Ok([])` (the flow makes the exit 15 `no nightly in the list`).
	tags : Str -> Try(List(Str), [BadJson(Str)])
	tags = |_text| crash "todo: slice 223"

	## R-MX18 item 7 (Q572): a work list with nothing to do: no `missing` and a `sweep` row whose `upto_log_index` is at least `log_size`.
	done : Work.Answer -> Bool
	done = |_work| crash "todo: slice 223"

	## R-MX18 item 7 (Q572, R-AP46): the bodies of one nightly: the rows in chunks of 500, in order, and the sweep only in the last chunk (its check needs each member row in the matrix). No rows: one body with the sweep only
	## (b2). With `sweep` `Err(None)` (the audit) no body has a sweep. No rows and no sweep: no body.
	chunks : { rows : List(Compat.Row), sweep : Try(Compat.Sweep, [None]) } -> List(Compat.Post)
	chunks = |_x| crash "todo: slice 223"

	## R-MX18 item 13, Design Q585 (proposals, R-OUT2): the failure of a registry or GitHub answer. Its own texts, not `Registry.refuse`. `reply` is `Ok` with the status and the body of the answer (the problem details of R-AP21 for a registry answer), or `Err(NoAnswer(why))`.
	## The failure never holds a token: it gets none. `step` is `Put(tag)`, `Post(tag)`, `PostAudit(tag)` (the texts `put <tag>`, `post <tag>`, `post audit <tag>`) or `List` (the GitHub list of Q567).
	##
	## | Case | Kind (exit) | Text |
	## | --- | --- | --- |
	## | 401 or 403 of a write | `rejected` (20) | `the registry <origin> refused the OIDC token of this run (<type>): <detail>. Check that the run is the workflow of BOT_WORKFLOW_REF on the default branch of BOT_REPOSITORY_ID (R-TP7) and that the job has permissions: id-token: write.` |
	## | 400, 404, 409 or 422 of a write | `rejected` (20) | `the registry <origin> refused the <step> (<type>): <detail>. The bot stops. This is a fault of the bot or of the registry data, not of the run.` |
	## | No answer, 429, 5xx or 503 `busy`, after the retries | `network` (15) | `the registry <origin> did not take the <step> after 4 requests (<status or no answer>). The bot stops, and the next run starts again.` |
	## | The GitHub list: no answer, 429, 5xx, a body that does not decode | `network` (15) | `the list of nightlies at api.github.com did not answer (<status or no answer>). The bot stops, and the next run starts again.` |
	failure : { origin : Str, step : [Put(Str), Post(Str), PostAudit(Str), List], reply : Try({ status : U16, body : Str }, [NoAnswer(Str)]) } -> Fail
	failure = |_x| crash "todo: slice 223"
}
