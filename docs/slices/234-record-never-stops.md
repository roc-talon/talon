# 234 The project record step never stops

Phase: P2. Status: done (TW24 texts wait for the user review)

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-TF9 (Design Q607) | The project record step (R-PD9, R-PD10) of each command and of the `roc` proxy never stops on a `projects.json` failure of kind `input` (a newer `format`, bad content). It prints a warning and writes nothing. GC (6.3) still stops with exit code 19. |
| R-TF3 | A newer `format` of `projects.json` is exit 19 (`input`) for a reader that needs the file. R-TF9 is the exception for the record step. |
| R-TF6 | Content that does not parse is exit 19. R-TF9 is the exception for the record step. |
| R-PD9, R-PD10 | The record step: each command that uses a project records its project files. The proxy records its target file. |
| R-E1 | The exit code of `roc` passes through the proxy. |

Source: research/cli-format-audit/PLAN.md, finding F1. Row 234 of docs/slices/PLAN-P2-CLI.md.

## Scope

| Part | Code today | Wanted |
| --- | --- | --- |
| Failure of kind `input` | `Projects.record` returns `Err(Fail(Input))` (cli/lib/Projects.roc:84 `read_file`, from `TalonFile.open`). `Known.update!` (cli/lib/Known.roc:64 onward) returns it with `?`, `Known.record!` and `Known.record_recent!` return it, and the 12 callers use `?` (for example cli/lib/Install.roc:150, cli/lib/Proxy.roc:219). The command stops with exit 19. | The record step prints one warning, writes nothing, and returns `Ok({})`. The command goes on. |
| Failure of kind `Environment` (read, write, lock) | Stops. | No change. A test is not added: no design change. |
| GC and the other readers (`Known.entries!`) | Exit 19 (cli/lib/Known.roc:38 `entries!`, used by CacheGc.roc:182, RocManage.roc:357, ToolsHeld.roc:32). | No change. |

Out of scope: `config.toml`, `tools.json`, the readers of `Known.entries!` other than GC (see Open, note 2).

## Tests

All 4 new L2 cases are red now. Each runs the same flow as an existing green case, with a `projects.json` that the record step cannot use. The expected files are the flow of the green case (a `projects.json` that Talon can use), with the `write_atomic` of `projects.json` removed and the warning on stderr. So the calls after the read of `projects.json` show that the command goes on, and the tree diff shows that the file bytes stay.

| Layer | Case | Rules | State now |
| --- | --- | --- | --- |
| L2 | tests/commands/cases/proxy/pd1-record-newer: `roc build` and `roc check` through the proxy, `projects.json` is `"format":2`. Fake roc exits with 3. Expected: exit code 3 (R-E1), one warning on stderr for each run, no write of `projects.json` (tree diff has only `.last-use`), `roc` is run (exec in the log). | R-TF9 R-TF3 R-PD9 R-PD10 R-E1 | red: exit 19, roc does not run, an error line |
| L2 | tests/commands/cases/proxy/pd2-record-garbage: the same, `projects.json` is `{"format":1,"projects":` (cut off) | R-TF9 R-TF6 R-PD9 R-PD10 R-E1 | red: the same |
| L2 | tests/commands/cases/install/pd3-record-newer: `tln install --frozen --file n5/main.roc` (project and home of `install/in2-nocompiler` run 5), `projects.json` is `"format":2`. Expected: exit 0, `the header satisfies talon.toml`, one warning, no write. | R-TF9 R-TF3 R-PD9 | red: exit 19, no stdout line |
| L2 | tests/commands/cases/install/pd4-record-garbage: the same, content does not parse | R-TF9 R-TF6 R-PD9 | red: the same |
| L2 | tests/commands/cases/gc/gc8-projects-input: `cache gc` with `"format":2` (run 1), `cache gc` with content that does not parse (run 2, home2), `cache gc --dry-run` with `"format":2` (run 3). Expected: exit 19 and the file named, nothing else. | R-TF9 R-TF3 R-TF6 | green now and after: it guards that the change does not reach GC |
| L2 | tests/commands/cases/gc/gc1-select (exists, run 5, line 21 of its `expect/stderr`): `cache gc` with content that does not parse is exit 19 | R-TF6 R-TF9 | green, no change |
| L0 | none | | See Not tested |

Not tested, and why:

| Item | Reason |
| --- | --- |
| L0 for the decision | There is no pure decision that the design names. The only decision is "kind `input` is a warning, kind `Environment` stops". It is one `match` in command code (`Known.update!` or `record_with!`), so it has L2 tests only (TW1 holds: the failure kind is data of `Fail`). The code agent may add a pure function, but the slice does not ask for it. The texts of the failures have L0 tests today (tests/unit/ProjectsTest.roc:73 to :86), and they stay the same. |
| `tln install --frozen` stands for all the commands | The 12 callers use `Known.record!`. The fix is in `Known`, so one command and the proxy (`record_recent!`) cover both entry points. |
| Kind `Environment` still stops | No design change. The code agent keeps the `match` on the kind. If a mutation (m3) makes `Environment` a warning too, no test fails. This is a gap: I did not add a case, because the fake `Fx` has no table for a read failure of `projects.json` that I found. See Open, note 3. |

### Mutation check (TW12)

I did not edit cli/. Each new case is red now, so it catches the old behavior (the parent commit is the revert). The code agent checks the mutations below after the code is green. Only the revert-sensitive behaviors are listed.

| Id | Mutation (after the code is green) | Caught by |
| --- | --- | --- |
| m1 | The record step returns `Err` for kind `input` again | pd1, pd2, pd3, pd4 |
| m2 | The record step writes the file after the warning (for example it makes a new file) | pd1, pd2, pd3, pd4 (tree diff) |
| m3 | `Known.entries!` (GC) also warns and returns an empty list | gc8, gc1-select |
| m4 | No warning | pd1 to pd4 (stderr) |
| m5 | The warning is printed more than once for a run | pd1, pd2 (2 runs, one line each) |

## Changed expectations

One existing L3 scenario changes (manager request): tests/scenarios/files/tf-bad-projects-json. It ran `flowprobe record` on 3 bad `projects.json` files (garbage, `"format":2`, an entry with no text path) and expected exit 19. Now: the comment names R-TF9 R-TF6 R-TF3 R-CC3 R-CC6, and the 3 runs give exit 0, one warning each on stderr (the texts of the Text proposals), the file bytes unchanged, the lock released. No other L2 or L3 case changes: a grep of tests/commands/cases and tests/scenarios for a bad `projects.json` in `given/` finds only this one for the record step.\n\nNote: the probe line `recorded 1` (cli/flowprobe.roc:62 prints `files.len()`) is misleading when nothing was written. It counts the files asked, not written. I did not change the probe tool. The scenario comment says so. `gc/gc1-select` (GC exit 19 on content that does not parse) stays as it is. The unit tests of `Projects.record` (tests/unit/ProjectsTest.roc:73 to :86) stay: the pure function still returns the failure, and the command code turns it into a warning.

## Code proposal

| Item | Proposal |
| --- | --- |
| Where | `Known.record_with!` (cli/lib/Known.roc:36 onward) or `Known.update!`. One place, so the 12 callers and the proxy do not change. |
| Rule in the code | After `Projects.record(...)`: a `Fail` of kind `Input` gives one `fx` print of the warning to stderr and `Ok({})`. A `Fail` of kind `Environment` is returned as today. The lock is released as today. |
| Warning text | The message of the `Fail` (it names the file), after the prefix `warning: Talon does not record this project. ` (TW24, below). |
| `Known.record!` doc (cli/lib/Known.roc:25) | The sentence "A failure of `Projects.record` is returned as it is (exit 19, R-TF6)" changes to R-TF9. |
| Size | About 10 lines. |

## Text proposals (TW24)

| Item | Text | Where |
| --- | --- | --- |
| Warning, newer format | `warning: Talon does not record this project. <cache>/talon/projects.json: format 2 is newer than this tln (format 1). Run: tln tool update talon` | stderr, once for each run, in the place where the record step runs (before the output of the command) |
| Warning, bad content | `warning: Talon does not record this project. <cache>/talon/projects.json: the content does not parse` | the same |
| Reason for the form | It is the line prefix of the other warnings (`warning: ...`) plus the unchanged message of the failure (ProjectsTest.roc:82, :78). So the file name and the repair hint (R-TF3) stay, and no new text is built. | |
| Other proposal (not tested) | `<path>: <reason>. Talon does not record this project.` (the order that the task gave). I did not use it: the hint `Run: tln tool update talon` of the newer format would then sit in the middle of the line. | |

## Mutation results (research/slice-234-revert/mutate.sh)

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | The record step stops on kind input again | pd1, pd2, pd3, pd4 |
| m2 | No warning | pd1, pd4 |

## Verify

check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only). `tools/ti1-tool-install` (L3) failed once with an extra lock-wait line in the code agent's run and passed in the close run (timing flake, not this slice).

## Open

| Item | Owner |
| --- | --- |
| 1. The texts of the Text proposals table (TW24) | Human review |
| 2. No TW17 question. R-TF9 names the record step and GC. `Known.entries!` has two more readers: `tln roc remove` (RocManage.roc:357, R-RR2) and `ToolsHeld.all!` (ToolsHeld.roc:32, R-B4). They stop with exit 19 as GC does. The design says nothing about them. They are not "the record step", so this slice does not change them, and no test covers them. If the user wants them lenient, it is a new design rule. | Human (information) |
| 3. The kind `Environment` (read, write, lock failure) still stops, but no test guards it. The fake `Fx` of L2 would need an answer table for a failed `read_files` of `projects.json`. I did not find one, and I may not change `tests/commands/` code of the harness for this. If the code agent finds that the table exists, a case is a small follow-up. | Code agent, human |
| 4. The expected `calls.log` files have no line for the warning (stderr is not in `calls.log`, as in `db/cc1-store`). If the code prints through a new `Fx` call that the fake logs, the 4 `calls.log` files change in the same way, and the human must accept it. | Code agent |

## Verify results

Red now: `tests/commands/run.sh pd1 pd2 pd3 pd4 gc8`: 1 pass (gc8), 4 fail (pd1 to pd4: exit 19 instead of the flow, an error line instead of the warning, the calls after the unlock are missing). Not run: L0, L3 (no L0 or L3 change).
