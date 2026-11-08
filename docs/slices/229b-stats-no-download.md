# 229b Stats with no download time

Phase: P2 (CLI client). Status: tests (red, waiting for human review of the tests). Depends on slice 229 (`bot/lib/Bot.roc`, `bot/lib/BotFlow.roc`, the cases b28 to b32).

Decision: Design Q608 (G-C238, decided by the user, 2026-11-08). When the stats are on, the bot installs the compiler of a nightly before the first probe batch of that nightly, so the probe rows have no download time.

No test calls GitHub, the registry or a real `tln`.

## Rules

Q608, Q606 (the stats), R-MX18 (the flow of the bot), R-NI6 and R-DL4 (the install command is the consent). Named also: R-MX13 (audit groups), R-OUT2 (output text is a proposal), TW24.

## What the design gives (Q608) and what is proposed

| Item | Source |
| --- | --- |
| Stats on (`COMPAT_STATS_DIR` set): `tln roc install <tag>` once before the first probe batch of each nightly: each sweep tag and each nightly group of the audit | Q608 |
| The install job has no GNU `time`. The probe jobs keep it (Q606 item 1). | Q608 |
| A failed install (any non-zero exit, a signal, not started): one warning on stderr, the probes go on | Q608 |
| Stats off: the bot does not change. b1 to b27 pass as before (no install job, no extra call). | Q608 |
| The argv has no flag and no env. `tln roc install <tag>` names the download, so it is the consent in non-interactive mode (the runner has no TTY, and `CI` is set): no `--yes`, no `TALON_AUTO_INSTALL`. | R-NI6 (answer flags: none needed), R-DL4, R-DL3 |
| Position of the call in one nightly, wait for the review: one `spawn_all!` with one job (`batch!`), after the curl batch and before the probe batch, only when at least one probe job follows | Proposal (Q608 says "before the first probe batch") |
| A second round of a tag (422 `sweep-incomplete`) does not install again: once for each nightly | Q608 ("once"). Not tested here, see Out of scope. |
| The warning text | Output (accepted by the user) |

## Public signatures (stub `crash "todo: slice 229b"` in `bot/lib/Bot.roc`)

| Name | Type | Rule |
| --- | --- | --- |
| `Bot.install_job` | `{ tag : Str } -> List(Str)` (gives `["tln", "roc", "install", tag]`) | Q608, R-NI6 |

Flow change for the code agent: `bot/lib/BotFlow.roc`, in `probe!` (stats on, `$ready` not empty): one `batch!` of `[Bot.install_job(...)]` before the probe batch, and one warning when `result.ended` is not `Exited(0)`. The word text of the ended state is `ended_text` (exists).

## Tests

| Layer | Where | Checks |
| --- | --- | --- |
| L0 | `tests/unit/BotTest.roc` (driver `l0-9`), the last `expect`: `install_job` is `["tln", "roc", "install", tag]`, no flag, no GNU time | Q608, R-NI6 |
| L2 | `bot/b28-stats` (changed): the calls have one `spawn_all` with the job `tln roc install <tag>` between the curl batch and the probe batch. Output and files as before. | Q608 |
| L2 | `bot/b29-stats-bad-time` (changed): same install call | Q608 |
| L2 | `bot/b30-stats-audit` (changed): the install call names the audit nightly (`nightly-2026-10-20-bbbbbbb`), not the sweep tag. The sweep tag has nothing missing, so it has no install call. | Q608, R-MX13 |
| L2 | `bot/b31-stats-no-fact` (changed): same install call | Q608 |
| L2 | `bot/b32-stats-stop` (changed): same install call, then the stop with exit 20 as before | Q608 |
| L2 | `bot/b33-stats-install-fails` (new): the install exits with 1. One warning, the probes, the posts and the stats files as in b28, exit 0. | Q608 |
| L2 | `bot/b34-stats-install-signal` (new): as b30, the install of the audit nightly ends with signal 9. One warning that names the audit nightly. | Q608, R-MX13 |
| L2 | `bot/b35-stats-install-no-start` (new): the install does not start (`notstarted`). One warning. | Q608 |
| L2 | `bot/b1-sweep` to `b27-list-no-nightly` (not changed) | Stats off: no install job (a stray install would make an `exit 99` job and a calls diff) |

The fake `fx/jobs` of each stats case has a rule with the needle `roc install` (exit 0 in b28 to b32). Without a rule a job exits with 99 and would give a warning. The cases b33 to b35 are copies of b28 and b30 with the exit of that rule changed, and the stderr and `rules` changed.

Check that the new tests catch the bad behavior: the red result below is that check. The code is not yet there, so each stats case fails on the missing install call. The old cases b1 to b27 pass, which shows that the stats-off path is untouched.

## Output (warning accepted by the user, 2026-11-08, TW24)

| Item | Proposal |
| --- | --- |
| Warning (stderr), one for each failed install. Accepted by the user as written. | `warning: the compat bot could not install the compiler <tag> before its probes (tln roc install <ended>). Each probe downloads the compiler, so the probe times of <tag> include the download.` where `<ended>` is `exited with <n>`, `ended with signal <n>` or `did not start (<why>)` (`ended_text`) |
| Success | No line on stdout or stderr |
| Stdout | No new line |
| Stats files | No change. The install has no row. |

## Out of scope

| Item | Why |
| --- | --- |
| A stats case for the second round of a tag (once for each nightly) | The round state is in `round!`. A case needs a 422 `sweep-incomplete` with stats on. Ask for it at the review if wanted. |
| An install when every curl download failed | No probe batch follows, so no install (proposal above) |
| A change of `compat-bot.yml` or the merge script | Not asked |
| A time or a row for the install | Q608: no GNU time on the install |

## Questions (stop until answered)

None. The argv is settled by R-NI6 and R-DL4. The position of the install call is a proposal for the review (see the table above).

## Disputes (from the code agent)

None.

## Red result (2026-11-08, `scripts/get-roc.sh`, ROC_TAG `nightly-2026-10-14-38a3029`)

| Run | Result | Reason |
| --- | --- | --- |
| `roc test tests/unit/l0-9.roc` | 27 passed, 1 failed (`BotTest.roc:219`) | `Roc application crashed with this message: todo: slice 229b` |
| `tests/commands/run.sh bot/` | 27 passed (b1 to b27), 8 failed (b28 to b35) | Fx calls differ: the lines `spawn_all limit=4` and `job - tln roc install <tag>` are missing. b33 to b35 also differ in stderr (no warning). |

## Code agent result (2026-11-08)

Changed: `bot/lib/Bot.roc` (`install_job`), `bot/lib/BotFlow.roc` (`probe!` takes `first : Bool`; `round!` passes `state.n == 1`, `audit!` passes true; the install batch and the warning run when `first`, stats are on and `$ready` is not empty).

| Run | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` | 28 passed |
| `tests/commands/run.sh bot/` | 35 passed (b1 to b35) |
| `scripts/test.sh check fmt selftest l0 l2` | check, fmt, selftest pass. l0: 1 fail (`ToolsplanTest.roc:62`). l2: 10 fail (gc1-select, pa5-unsafe-patch, cv1-proxy-range-bad-registry, rg7-remove-bad-config, rg7-share-bad-config, rs-exclude-bad, rs-exclude-bad-config, rn1-scripts, tg1-ladder, ti7-exclude-bad-config). None is a bot case. They are config and cache cases in the area of slice 231 (`cli/lib/` changes of other sessions). Not fixed. |

Limit: if an audit nightly equals a sweep tag of the same run, it installs twice (the state is per round, not per run).

Warning text changed by the user (TW24): the install warning in `bot/lib/BotFlow.roc` has the new text. bot/ 35 passed, l0-9 passed, fmt check valid.
