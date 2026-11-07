# 229 Compat stats

Phase: P2 (CLI client). Status: tests (red, questions answered 2026-11-08, waiting for human review of the tests). Depends on slice 223 (`bot/lib/Bot.roc`, `bot/lib/BotFlow.roc`, `compat-bot.yml`).

Decision: Design Q606 (G-C236, decided by the user, 2026-11-08). The compat bot keeps the time and the resources of each probe, so that a person can see the trend and predict when the compat builds get too large (Registry R-MX18).

The workflow file and the merge script are never run by a test. No test calls GitHub or the registry.

## Rules

Q606 (items 1 to 4), R-MX18 (the flow of the bot), R-MX15, R-MX17, R-OUT2 (output text is a proposal). Named also: R-MX1, R-MX13, R-MX10, TW24, TW28.

## What the design gives (Q606) and what is proposed

| Item | Source |
| --- | --- |
| Each probe job runs under GNU `time`: wall ms, user plus system CPU ms, peak RSS KB. No change to `spawn_all!`. | Q606 item 1 |
| Files `stats/compat/<YYYY-MM>.csv` (one row per probe), `stats/compat/runs.csv` (one row per run), `stats/compat/README.md` (mermaid chart of run totals) | Q606 item 3 |
| The files are on the branch `compat-stats`. The bot job stays read-only (OIDC token) and gives the files as an Actions artifact. A second job with `contents: write` and no OIDC token commits them. | Q606 item 4 |
| Everything else in "Output (proposed)" below | TW24, R-OUT2 |

## Flow with stats (proposal, for the review)

Stats are on only when the variable `COMPAT_STATS_DIR` is set (see Q-D). The workflow sets it. With no variable the bot behaves as in slice 223 (the cases b1 to b27 are not changed and still pass).

| # | Step | Where tested |
| --- | --- | --- |
| 1 | After `env_all!`: one `clock!` call. The run time is this time for each row. | L2 b28 |
| 2 | Each probe job is `Bot.timed_job` of `Bot.probe_job`, with the time file `Bot.time_file` (`<RUNNER_TEMP>/<hash>.time`). The curl jobs are not timed. | L0 expect 16, L2 b28 |
| 3 | After one probe batch: one `read_files!` of the time files of that batch (TW3: one coarse call). Each file goes through `Bot.time_stats`. | L2 b28, b29, b30 |
| 4 | A file that is missing or bad gives `Err`: one stderr warning, the row has empty numbers, the run goes on. | L2 b29 |
| 5 | The probe rows and the registry posts do not change (stats never change a post). | L2 b28 |
| 6 | At the end of every run in which at least one probe ran, also a stop with exit 2, 15 or 20 (Q-C): one `write_atomic!` of `<COMPAT_STATS_DIR>/<YYYY-MM>.csv` and `<COMPAT_STATS_DIR>/runs.csv`. Each file has its header line and the rows of the probes that ran in this run. `tags` of the run row is the number of nightlies started. A run with no probe writes nothing (so b1 to b27, the stop cases b4, b9 to b12 and b17 to b27 are not changed; b2 and b6 have no probe and are not changed either). | L2 b28 to b32 |
| 6a | A probe with no fact (its `tln probe` gave no row) has a stats row with the result `no-fact` and the numbers of its time file (Q-B). | L2 b31 |
| 7 | The merge into `stats/compat/` on the branch `compat-stats` is the job `stats` (script, manual verify, Q-A). | Manual |

## Public signatures (stubs `crash "todo: slice 229"` in `bot/lib/Bot.roc`)

`Stats` below is `{ wall_ms : U64, cpu_ms : U64, rss_kb : U64 }`.

| Name | Type | Rule |
| --- | --- | --- |
| `Bot.time_stats` | `Str -> Try(Stats, Str)` | Q606 item 1 |
| `Bot.timed_job` | `{ time_file : Str, argv : List(Str) } -> List(Str)` | Q606 item 1 |
| `Bot.time_file` | `{ dir : Str, hash : Str } -> Str` | Q606 item 1 |
| `Bot.release_repo` | `Str -> Str` (artifact answer, the `repo` of the release that `release_url` picks, empty when none) | Q606 item 3 |
| `Bot.header` | `[Probes, Runs] -> Str` | Q606 item 3 |
| `Bot.month_file` | `U64 -> Str` | Q606 item 3 |
| `Bot.probe_line` | `{ run, time : U64, nightly, hash, repo, target, result, stats : Try(Stats, Str) } -> Str` | Q606 item 3 |
| `Bot.run_line` | `{ run : Str, time : U64, tags : U64, probes : List(Try(Stats, Str)) } -> Str` | Q606 item 3 |

The time text of a `Clock.format_utc` (`lib.Clock`, exists) is used inside `probe_line` and `run_line`. No other new type.

Flow changes for the code agent: `bot/lib/BotFlow.roc` (the steps above, `release!` keeps the repo of the release), `.github/workflows/compat-bot.yml` (env `COMPAT_STATS_DIR`, upload step, job `stats`), `scripts/compat-stats-merge.sh` (name is a proposal, Q-A).

## Tests

| Layer | Where | Checks |
| --- | --- | --- |
| L0 | `tests/unit/BotTest.roc` (driver `l0-9`), expect 14: `time_stats` good text (2 decimals to ms, CPU is user plus system, a first line `Command exited ...` or `Command terminated by signal ...` is ignored) | Q606 item 1 |
| L0 | expect 15: `time_stats` bad text (empty, no number, 3 numbers, 5 numbers, not a number, a negative number) is `Err`, no crash | Q606 item 1 |
| L0 | expect 16: `timed_job`, `time_file`, `probe_job` is not changed | Q606 item 1, R-MX15 |
| L0 | expect 17: `release_repo` (withdrawn skipped, no release, no `repo`, `repo` null, not JSON) | Q606 item 3 |
| L0 | expect 18: `header`, `month_file` (month change at the second, epoch 0) | Q606 item 3 |
| L0 | expect 19: `probe_line` (all fields, `Err` gives 3 empty numbers, empty repo, quoting of a comma and a quote) | Q606 item 3 |
| L0 | expect 20: `run_line` (sums over `Ok`, `no_stats` count, largest RSS, empty list, only `Err`) | Q606 item 3 |
| L2 | `bot/b28-stats`: timed probe jobs, one `clock`, one `read_files` after the batch, same post as b1, one `write_atomic`, the 2 files in the tree | Q606 items 1 and 3, R-MX18 |
| L2 | `bot/b29-stats-bad-time`: no time file for one hash, a text that is not GNU time for the other: exit 0, same posts, empty numbers, 2 warnings, run row `no_stats` 2 | Q606 (a bad time output does not stop the run) |
| L2 | `bot/b30-stats-audit`: stats of an audit probe (the nightly of the audit group, run row `tags` 1, `probes` 1) | Q606, R-MX13 |
| L2 | `bot/b31-stats-no-fact`: as b5 (exit 1 probe) with stats: the row of that probe has the result `no-fact` and the numbers (the first line `Command exited with non-zero status 1` of its time file is ignored); exit 1; posts as b5 | Q606, answer Q-B, R-MX4 |
| L2 | `bot/b32-stats-stop`: the post answers 401 twice after 2 probes (as b12): exit 20, and the 2 stats files are still written with the rows of the 2 probes and the run row | Q606, answer Q-C, R-AP34 |
| L2 | `bot/b1-sweep` to `b27-list-no-nightly` (existing, not changed) | stats off: no `clock`, no wrap, no write |
| Text | `tests/tools/ciscan.py compatbot` (changed): two jobs `bot` and `stats`; `bot` keeps `contents: read` and `id-token: write`, sets `COMPAT_STATS_DIR`, uploads an artifact after the `bot` step; `stats` has exactly `contents: write`, no `id-token`, `needs: bot`, downloads the artifact, names the branch `compat-stats`, does not run `bot`; the upload step and the job `stats` have `if: ${{ !cancelled() }}` (they run when `bot` fails, not when cancelled) | Q606 item 4, answer Q-C, TW28 |
| Manual | The job `stats` and the merge script (append, header once, dedupe by run id, README chart): see "Manual verify" | Q606 items 3, 4 |

The L2 expected files of b28 to b32 were written by hand (no code exists). They reuse the fx routes of b1 and b3 (the committed files, not the output of `tests/tools/mk-bot.sh`, which is behind them). The stats dir of the cases is `{w}/home/stats`, not under `RUNNER_TEMP`: the file tree compare leaves out dirs named `tmp`. The time files are in `RUNNER_TEMP`, which is the production place, and the fake job writes them with `copy:` from `fx/times/<hash>`.

`tests/tools/mk-bot.sh` makes b28 to b30. b31 and b32 were made by hand from b5, b28 and b12 (a comment in the script says so; a re-run removes them). Do not run it to regenerate b1 to b27: the committed files of those differ from its output (hand edits of later slices).

### Manual verify (Q-A, not run by a test)

| Step | Check |
| --- | --- |
| 1 | Merge run on an empty `compat-stats` branch: the monthly file and `runs.csv` get one header line and the rows |
| 2 | A second merge with the same artifact: no duplicate row (the run id is the key) |
| 3 | A merge in the next month: a new monthly file, `runs.csv` keeps one file |
| 4 | `stats/compat/README.md` has a mermaid chart that GitHub draws, from `runs.csv` |
| 5 | The job `stats` after a bot run that exits 1 (Q-C) |

## Output (accepted by the user, 2026-11-08, TW24: file text and names)

All texts below were proposed and are accepted as written. The result `no-fact` (Q-B) is added by the answer.

| Item | Proposal |
| --- | --- |
| GNU time call | `/usr/bin/time -f "%e %U %S %M" -o <RUNNER_TEMP>/<hash>.time env ROC_TOOLCHAIN=<tag> tln probe --json --yes <RUNNER_TEMP>/<hash>.tar.zst`. `-o` keeps the stats out of the stdout that the bot parses. `env` and `tln` run in the timed process (`env` execs `tln`), so the numbers are of `tln probe` and its children. |
| Time file text | `<wall s> <user s> <sys s> <rss KB>`, last line. `wall_ms` is `%e` in ms (10 ms steps), `cpu_ms` is `%U + %S` in ms. |
| Probe file header | `run,time,nightly,hash,repo,target,result,wall_ms,cpu_ms,rss_kb` |
| Probe file name | `<YYYY-MM>.csv`, the UTC month of the run start (one run is one file, also over midnight) |
| Runs file header | `run,time,tags,probes,no_stats,wall_ms,cpu_ms,rss_kb` |
| Run id | `GITHUB_RUN_ID` (the text, `9001` in the cases). Unset: empty field (no stop). A re-run attempt has the same id: Q-A merge dedupe must use the run id and the hash. |
| Time | `Clock.format_utc` of the `clock!` at the start of the run, for each row of the run (`2026-10-15T12:00:00Z`) |
| `repo` | The `repo` of the release that gives the archive (`acme/json`), not the group |
| `target` | `any` (the unit probe, R-MX17) |
| `result` | `pass`, `fail`, `hang`, `crash` (the row result) |
| Numbers on a bad time output | 3 empty fields |
| Run row | `tags` nightlies swept (not the audit), `probes` all rows, `no_stats` rows with no numbers, `wall_ms` and `cpu_ms` are sums over rows that have numbers, `rss_kb` is the largest |
| CSV quoting | RFC 4180: a field with a comma, quote or new line is in double quotes, a quote is doubled |
| Compiler download | The probe time includes the download of its compiler when `tln` has to fetch it. No extra column: a person sees it as a high `wall_ms` and a low `cpu_ms`. |
| Warning (stderr) | `warning: no time stats for <hash> on <tag>` |
| Stdout | No new line (stats files are not announced) |
| Env names | `COMPAT_STATS_DIR` (the dir for the files of the artifact), `GITHUB_RUN_ID` |
| Job names | `bot`, `stats`; artifact name `compat-stats` |

## Out of scope

| Item | Why |
| --- | --- |
| A change of `Fx.spawn_all!` | Q606 item 1 |
| A column or a Worker rule for the stats | Q606 item 2 |
| Stats for the curl download | Not asked |
| Alerts or a forecast | The person reads the chart |

## Questions (answered by the user, 2026-11-08)

| Id | Question | Answer |
| --- | --- | --- |
| Q-A | How do the merge and the README chart run on a runner with no Roc binary? | Accepted: `scripts/compat-stats-merge.sh` (shell or awk), checked by hand under "Manual verify". No Roc chart function, no L0 test for it. |
| Q-B | Does a probe with no fact get a stats row? | Changed: yes, with the result `no-fact` and the numbers from GNU time (empty numbers when the time file is missing or bad). Test: b31. A hash whose probe did not run (curl failed, no artifact) has no time file and no probe: no row (my reading, not tested). |
| Q-C | Are the stats written when the run stops (exit 2, 15, 20) after probes? Do the upload step and `stats` run when `bot` fails? | Changed: stats are written on every exit after probes ran, with the rows of the probes that ran, and `runs.csv` gets the run row. The upload step and the job `stats` run when `bot` fails and not when cancelled (`if: ${{ !cancelled() }}`). Tests: b32, ciscan. My reading, not tested: a stop before any probe (exit 2, or 15 and 20 in the reads) writes nothing, because the answer says "after probes ran". |
| Q-D | Gate the stats on `COMPAT_STATS_DIR`? | Accepted. b1 to b27 are the "stats off" tests. |

## Disputes (from the code agent)

None.

## Red result (2026-11-08, `scripts/get-roc.sh`, ROC_TAG `nightly-2026-10-14-38a3029`; updated after the answers)

| Run | Result | Reason |
| --- | --- | --- |
| `roc test tests/unit/l0-9.roc` | 13 passed (old), 7 failed (`BotTest.roc` lines 178, 183, 189, 195, 202, 207, 213) | `Roc application crashed with this message: todo: slice 229`. No L0 test is added by the answers: `no-fact` is a plain `result` text of `probe_line`. |
| `tests/commands/run.sh bot/` | 27 passed (b1 to b27), 5 failed (b28 to b32) | The calls differ (no `clock`, no `/usr/bin/time` in the job, no `read_files`, no `write_atomic`) and the file tree has no `home/stats/*.csv`. b29 also differs in stderr (no warnings). |
| `python3 tests/tools/ciscan.py compatbot .` | FAIL | `two jobs, bot and stats (Q606), found ['bot']` |
| ciscan on a sample workflow with both jobs | `if: ${{ !cancelled() }}` passes; `if: always()` fails with 2 lines (upload step, job `stats`) | The check can turn green and it catches a missing `!cancelled()` |

## Code agent (2026-11-08)

Files changed: `bot/lib/Bot.roc` (8 functions, helpers `dec_ms`, `csv_field`), `bot/lib/BotFlow.roc` (stats flow), `.github/workflows/compat-bot.yml` (env, upload, job `stats`, header comments), `scripts/compat-stats-merge.sh` (new). No test file was edited.

Flow notes: the stats lines ride in an `Acc` record through `sweeps!`, `sweep_tag!`, `round!`, `audit!`. A stop returns `Halt { fail, acc }`, so `flow!` writes the files on every end after a probe ran (Q-C). A failed `write_atomic!` is a stderr warning (`warning: no stats written: <path>`) and does not change the exit code: the design gives no rule for it (proposal for the review). `tags` counts each tag at the start of `sweep_tag!`.

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` | 20 passed |
| `tests/commands/run.sh bot/` | 32 passed (b1 to b32) |
| `python3 tests/tools/ciscan.py compatbot .` | pass |
| `JOBS=3 TEST_TIMEOUT=400 scripts/test.sh check fmt selftest l0 l2` | all pass (budget warnings only) |
| `JOBS=1 scripts/test.sh l3` | pass |

### Manual verify (merge script, sample data, no GitHub run)

| Step | Result |
| --- | --- |
| 1 Empty branch dir | `2026-10.csv` (1 header + 2 rows, one quoted `"a,b"`), `runs.csv` (1 header + 1 row), `README.md` written |
| 2 Same artifact again | no change: still 3 and 2 lines |
| 3 Next month artifact | new `2026-11.csv`, `runs.csv` has 1 header + 2 rows, `2026-10.csv` unchanged |
| 4 README | mermaid `xychart-beta` with run ids on x, wall and CPU lines; with 70 runs only the last 60 are drawn. Not yet seen drawn by GitHub. |
| 5 Job `stats` after a failed bot run | not run (needs a real workflow run); the job has `if: ${{ !cancelled() }}` and exits 0 when the artifact has no csv |
