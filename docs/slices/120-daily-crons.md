# 120 Daily crons: hint cleanup, hint_days and the trim

Phase: P2. Status: review (scope and test agent, 2026-11-02). Model for the code: Sonnet medium. The code is about 120 lines (TW19), one code step.

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-120-revert/` (the private reference).

One cron job, `Daily.cron`, does 3 steps in order: the hint cleanup (R-CT5), the delete of old `hint_days` rows (R-RE6), and the trim (R-CT15). It is a `Worker.cron` handler of `main.roc` (the platform runs the handler of the cron before `scheduled!`, `cloudflare-workers/MODULES.md` 3). Slice 119 adds its own cron beside it.

## 1. Scope

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/Daily.roc`: `cron`, `old_ms` (constants), `hints_sql`, `days_sql`, `due_sql`, `trim_sqls` (stubs, `crash "todo"`; the doc comment of each is the rule) | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/DailyCrons.roc`: `run! : Worker.Scheduled => Try({}, [Fault(Str)])` (stub, the flow is in the doc comment) | Test agent (signature), code agent (body) | Stub |
| `worker/lib/main.roc` (exposes `Daily`), `worker/tests/unit/w0.roc` (imports `DailyTest`) | Test agent | Done |
| `worker/main.roc`: `import lib.Daily`, `import DailyCrons`, `crons: [Worker.cron(Daily.cron, DailyCrons.run!)]` in `Worker.new` | Test agent | Done. The line has a comment: slice 119 adds its cron here |
| `worker/wrangler.toml`: `[triggers] crons = ["0 3 * * *"]` | Test agent | Done. `roc-cfw sync --check` compares it with the manifest |
| `worker/tests/run.mjs`: a cron line sets the clock to `now` first (the scheduled event does not pass the entry `fetch`, so `x-test-now` set no clock). Copy before: `research/slice-120-revert/before/` | Test agent | Done |
| Tests: section 5 | Test agent | Red |

No SQL file and no W1 case: the statements are strings of `Daily` (as `Hints` and `Login`). W0 pins their key words, W2 pins what they do on local D1. The schema and the triggers do not change. The code agent writes no new route and no new Route.Id.

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-CT5 | A daily step deletes each `compat_hints` row whose pair (artifact, nightly, target) has a `bot` row (`compat.source` 0). All `talon_version` rows of the pair go. `contributions` stay | W0 `hints_sql`. W2 `pu35-hint-cleanup`, `ct15-trim` |
| R-RE6, R-RE24 | The daily cron deletes the `hint_days` rows older than 2 days. The rows of today and yesterday stay (the counter of R-CT13) | W0 `days_sql`. W2 `pu35-hint-cleanup`. The edge: Q343 answered (strict, the row of `today - 2` stays) |
| R-CT15 | The trim: each compiler (a `nightly` of `toolchains`) with `published_at` (the smallest over its targets) below now minus 365 days, the oldest first. One D1 batch for each compiler with 3 steps: upsert `contributor_totals` (the classes of R-CT10, the smaller `first_time`, the larger `last_time`), delete the `contributions`, delete the `compat_hints` of that compiler. `compat` is not trimmed. A compiler at exactly 365 days is not old. The tracker of a contributor is the same before and after | W0 `due_sql`, `trim_sqls`. W2 `ct15-trim`, `ct15-trim-failure` |
| R-CT15, R-PU35 (trim row) | A batch that fails writes a log line, and the step goes on with the next compiler. The compiler stays due | W2 `ct15-trim-failure` |
| R-PU35 | Each job selects its work from the state of D1, not from the time of the last run | W2 `pu35-hint-cleanup` (a `bot` row that comes between 2 runs), `ct15-trim-failure` (the cause goes between 2 runs) |
| R-PU36 | Each job is safe when 1 planned time runs 2 times: the second run finds no rows | W2 all 3 cases run the cron 2 or more times. Overlap of 2 runs: out of scope (section 8) |
| R-RE25 | The columns of `contributor_totals` | W2 `ct15-trim` |

## 3. What the code agent writes

| File | What |
| --- | --- |
| `worker/lib/Daily.roc` | The 4 bodies. The doc comment of each stub is the rule. Reuse the class logic of `Login.tracker_sql` (R-CT10) in `trim_sqls` step 1 (the same `first`, `agreed`, `disagreed`, `unconfirmed`) |
| `worker/DailyCrons.roc` | The body of `run!` |

Hints:

- A 64-bit id travels as text: `due_sql` gives `CAST(nightly AS TEXT) AS nightly`, and each trim statement binds it with `CAST(?1 AS INTEGER)`. A D1 statement takes as many values as its highest `?n`.
- `D1` `batch!` is one transaction. A trigger `RAISE(ABORT)` in step 3 rolls back steps 1 and 2 of that compiler. The test `ct15-trim-failure` depends on this.
- Step 1 reads `contributions` and `compat`, so it runs before step 2. Check `INSERT ... SELECT ... ON CONFLICT` for the SQLite parse rule (a `SELECT` with a join and no `WHERE` needs `WHERE true`).
- The clock is `Time.now_ms!()` once (Q345). The case sets `time` and `now` to the same value.
- The result of `run!` is `Ok({})` when the steps ran. One compiler that fails is a log line, not an `Err` (the W2 cases expect `outcome` `ok`, status 200).
- `Log.warn!("trim failed", { nightly, error })`. `nightly` is the id as text. No contributor id and no name (R-PU32). See section 7.

## 4. The signatures

See `worker/lib/Daily.roc` and `worker/DailyCrons.roc`.

| Function | Signature |
| --- | --- |
| `Daily.cron`, `Daily.old_ms` | `Str` (`"0 3 * * *"`), `U64` (31536000000). Constants, done |
| `Daily.hints_sql`, `days_sql`, `due_sql` | `() -> Str`. Values: none, ?1 now, ?1 now |
| `Daily.trim_sqls` | `() -> List(Str)`, 3 statements, ?1 the nightly as text |
| `DailyCrons.run!` | `Worker.Scheduled => Try({}, [Fault(Str)])` |

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `worker/tests/unit/DailyTest.roc`, 4 `expect`s: `hints_sql` (one DELETE, the pair key, `source = 0` only, no `contributions`), `days_sql` (one DELETE, strict day compare of `?1 / 86400000`), `due_sql` (smallest `published_at`, strict, 365 days, rows exist, one `ORDER BY`, id as text) and the constants, `trim_sqls` (3 statements in order, ON CONFLICT with MIN and MAX, never `OR REPLACE`, no `compat` write) | R-CT5, R-CT15, R-RE6, R-RE24, R-PU35, R-PU36 |
| W2 | `cron/pu35-hint-cleanup`: 5 pairs. The pair with a `bot` row and 2 `talon_version` rows loses both hints. A pair with only a smoke row, a pair with a `bot` row for another target and one for another nightly keep their hints. Run 1; then a `bot` row for a fifth pair; run 2 deletes its hint (by state); run 3 changes nothing. `hint_days`: the days 20451, 20424, 20400 go, 20453 and 20454 stay (now is day 20454). `contributions` and `compat` count unchanged | R-CT5, R-RE6, R-RE24, R-PU35, R-PU36 |
| W2 | `cron/ct15-trim`: 5 compilers (the ids are not in the order of age; one has 2 targets; one is at exactly 365 days; one is new). 4 contributors (an account with an old totals row, one without totals, a bystander with totals and no rows, a machine). Request 1 and 4 are `GET /v1/contributors/me`: the same tracker before and after. Requests 2 and 3 are the cron 2 times. The totals are exact (`counted`, `first`, `agreed`, `disagreed`, `unconfirmed`, `first_time`, `last_time`), the rows of the old compilers are gone, the rows of the 365-day and the new compiler stay, `compat` is 4 rows, the order of the trim is the order of age (a probe trigger on `DELETE` of `contributions`) | R-CT15, R-CT10, R-CT5, R-RE25, R-RE6, R-RE24, R-PU35, R-PU36 |
| W2 | `cron/pu35-cleanup-failure` (added after the Q344 answer): a `BEFORE DELETE` trigger on `compat_hints` makes the hint cleanup DELETE fail for a pair with a `bot` row. The run is `ok`, one log line `{"level":"warn","msg":"hint cleanup failed"}` is written (text as the code has it, TW24), the old `hint_days` row still goes and the old compiler is still trimmed (Q344). The hint of the failed pair stays | R-CT5, R-CT15, R-PU35, R-PU36, R-RE6, R-RE24 |
| W2 | `cron/ct15-trim-failure`: a trigger makes the batch of the oldest compiler fail. Runs 1 and 2: outcome `ok`, one log line `trim failed` with `nightly` `"9100"` for each run, the next compiler is trimmed once (no double count), the failed compiler keeps its rows, hints and totals (snap tables). Then `DROP TRIGGER`: run 3 trims it. Run 4 changes nothing | R-CT15, R-PU35, R-PU36 |

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 (`roc test` of `DailyTest`) | 4 `expect`s, 0 pass (`todo`). 0 compiler errors. `roc fmt --check` passes |
| W2 `cron` (`scripts/test.sh wbuild w2`) | 0 of 3 pass. Each cron request: status 500, outcome `exception`, Worker log `scheduled: trap: todo`. The databases are unchanged. `wbuild` (with `sync --check`) passes |
| Old W2 with the stubs | The only other failures are `webhook/*` (slice 118b, in work) |

### 5.2 Private reference and revert check

`research/slice-120-revert/reference/` and `ref.sh [w0|w2]`. With the reference: W0 `DailyTest` 4 of 4, W2 `cron` 3 of 3 (the first run). Mutations (`mutate.py`, 4 of the tricky ones):

| Mutation | Caught by |
| --- | --- |
| `order-by-id` (the trim order is the nightly id, not the age) | W2 `ct15-trim` (probe) |
| `edge-le` (a compiler at exactly 365 days is trimmed) | W2 `ct15-trim` |
| `stop-on-failure` (a failed batch stops the loop) | W2 `ct15-trim-failure` |
| `pair-with-version-and-smoke` (a smoke row counts as a `bot` row) | W2 `pu35-hint-cleanup` |

## 6. Questions (TW17)

| Id | Question | Effect |
| --- | --- | --- |
| Q343 (answered) | "A `hint_days` row older than 2 days" (R-PU35, R-RE6): is the row of `today - 2` deleted? Proposal: a day is old when `day < today - 2`, where `today = now / 86400000` (strict, as the 365 days of R-CT14: "exactly at the edge is not old"). The rows of today, yesterday and `today - 2` stay | Stops one test row: the row of `today - 2`. `Daily.days_sql` and its W0 test do not pin the edge, and no W2 case has a row at `today - 2`. The code agent must not choose: wait for the answer |
| Q344 (answered) | The hint cleanup (R-CT5) and the `hint_days` delete are "One DELETE, the next run" (R-PU35). When the DELETE fails, or the read of the due compilers fails: is the run `Err` (a failed run in Past Events), or is it a log line and `Ok`? Does the failure stop the next steps? Proposal: each of the 4 reads and writes is independent. A failure writes a `Log.warn!` and the run goes on, as R-PU37 row 2. The run is `Ok` | No test. The reference does the proposal |
| Q345 (answered) | The clock of the job: `Time.now_ms!()` or `time_ms` of the `Scheduled` (the planned time)? The design says "Each job is safe when 1 planned time runs 2 times" (R-PU36). Proposal: `Time.now_ms!()`, as every other handler | The W2 cases set both to the same value, so both pass. Not a stop |

### 6.1 Answers (design agent, 2026-11-02; Design Q343 to Q345)

| Id | Answer | Test change |
| --- | --- | --- |
| Q343 | Strict: a day is old when `day < today - 2`. The row of `today - 2` stays. A read (the trigger `contributions_count`, R-CT13) uses only the day of the request time, which is today | Yes, 2 edits. W2 `pu35-hint-cleanup`: add the row of day 20452 to `seed.sql` and to `expect/db.tsv` (it stays; the days 20451, 20424, 20400 go). W0 `days_sql`: pin the offset (`holds` also `"- 2"`) |
| Q344 | A failed DELETE or a failed read of the due compilers writes a `Log.warn!` and the run goes on with the next step. The run is `Ok({})`. A failed due read skips the trim of that run only | No test change |
| Q345 | `Time.now_ms!()` once at the start of the run. `time_ms` of the event is not used for a cutoff | No test change (the cases set `time` and `now` to the same value) |

## 7. Output (TW24, proposals for the human review)

| Item | Proposal |
| --- | --- |
| The cron expression | `0 3 * * *` (03:00 UTC), in `Daily.cron` and `wrangler.toml` |
| The log line of a failed batch | `Log.warn!("trim failed", { nightly, error })`: JSON `{"level":"warn","msg":"trim failed","nightly":"9100","error":"..."}`. `nightly` is the id as text. `error` is the text of the D1 error (no test pins it) |
| The log lines of Q344 (as the code has them) | `Log.warn!("hint cleanup failed", { error })`, pinned by `pu35-cleanup-failure`, `"hint days cleanup failed"`, `"trim read failed"` |
| The answer of the run | `Ok({})`: Miniflare gives `{"outcome":"ok","noRetry":false}` with status 200 |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| Two runs that overlap in time (R-PU36) | D1 runs one write at a time and Miniflare runs the cases one request at a time. The cases run the same planned time 2 or more times. The design gives the way: each statement or batch selects by state |
| The time of one batch for a compiler with many rows (R-CT15 "Not measured") | W3 |
| The cron wiring of `wrangler.toml` | `wbuild` runs `roc-cfw sync --check` |
| A compiler with rows and no `toolchains` row | Not a compiler of R-CT15 (the age comes from `toolchains`). No test |
| The reconcile cron and the tile catch-up | Slice 119 and P3 |

## 9. Requests to other slices

| # | To | Request |
| --- | --- | --- |
| RQ1 | Slice 119 | Add the reconcile cron beside `Worker.cron(Daily.cron, ...)` in `main.roc`, and its expression in `[triggers] crons`. `worker/tests/run.mjs` already sets the clock for a cron line |

## 10. Code (code agent, 2026-11-02)

| Part | Lines | What |
| --- | --- | --- |
| `worker/lib/Daily.roc` | 66 file; 4 bodies and 2 helpers (`totals_sql`, `sql_text`) | `hints_sql`, `days_sql` (`day < ?1 / 86400000 - 2`), `due_sql` (grouped MIN of `published_at`), `trim_sqls` |
| `worker/DailyCrons.roc` | 59 file; `run!`, `step!`, `trim!` | One `Time.now_ms!()`, 2 DELETE steps, then the trim loop |

Green results:

| Step | Result |
| --- | --- |
| `scripts/test.sh w0` | DailyTest 4 of 4 pass. The only reds are 4 `WebhookTest` (slice 118b, not mine) |
| `node sql/tests/run.mjs` | pass |
| `scripts/test.sh wbuild w2` | wbuild pass. `cron/*` 3 of 3 pass. The only reds are 9 `webhook/*` (slice 118b) |
| `scripts/test.sh check fmt w1` | pass |

Choices:

| Choice | Reason |
| --- | --- |
| Step 1 of the trim is `tracker_sql` logic over a subquery of the `contributions` of the nightly, grouped by contributor, with `WHERE true` before `GROUP BY` | Same classes as R-CT10; parse rule of `INSERT ... SELECT ... ON CONFLICT` |
| Failures: `Log.warn!` with `hint cleanup failed`, `hint days cleanup failed`, `trim read failed`, `trim failed` `{ nightly, error }` | Q344, section 7 |
| `step!` and `trim!` are private helpers with the effects inline | Direct style; no new route |
| No test changed | |

## 10. Revert check on the real code (TW12)

Build copy only (`ref.sh` with `NOREF=1`, `mutate2.py`, `--opt=speed`). `worker/` and the tests were not changed. Logs: `research/slice-120-revert/real-*.log`.

| Mutant | Result | Caught by |
| --- | --- | --- |
| `order-by-id` (trim order is the nightly id) | caught | W2 `ct15-trim` (probe) |
| `edge-le` (365 days is old) | caught | W2 `ct15-trim` |
| `stop-on-failure` (`break` after the first failed batch) | caught | W2 `ct15-trim-failure` |
| `smoke-as-bot` (`source IN (0, 1)` in `hints_sql`) | caught | W2 `pu35-hint-cleanup` |
| `days-edge-le` (`day <= today - 2`) | caught | W2 `pu35-hint-cleanup` (day 20452) |
| `last-time-min` (smaller `last_time` in the totals upsert) | caught | W2 `ct15-trim`, `ct15-trim-failure` |
| `delete-fail-silent` (a failed hint DELETE writes no `Log.warn!`) | caught after the new case | W2 `pu35-cleanup-failure` (first run: survived) |
