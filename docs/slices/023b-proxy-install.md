# 023b Install in the proxy

Phase: P1. Status: done

Slice 023b makes the `roc` proxy install a compiler that is not installed (CLI 6.2, R-PX4). Slice 023 refuses it (exit 13). Now the proxy follows `TALON_AUTO_INSTALL` and the consent rules (R-DL1 to R-DL5, R-DL8 to R-DL10): it asks the person (prompt R-NI5), or installs with no prompt for `yes`, then it runs the compiler. The install is the code of `tln roc install` (slice 021) called as a function, with the consent in between. Follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-023b-revert/before/` (with `NEW.txt`). The private reference is deleted.

## 0. Where the output goes (slice 023 D10: the stdout and stderr of the proxy belong to roc)

| Output | Where | Text |
| --- | --- | --- |
| Install, stdout | Nothing. Never. The only stdout is the one of the compiler. | No `installed <id>` line, no `... is now the default compiler` line |
| The prompt (R-NI5) | stderr (`Fx.ask!` writes the prompt to stderr and reads one line from stdin, before the compiler starts) | `<id> (<source>) is not installed. Download 1 compiler, <size>? [Y/n] ` |
| The answer with no prompt (`TALON_AUTO_INSTALL=yes`, R-NM6) | stderr, one line | `downloading <id> (<size>)` |
| The wait for another install (R-CC5) | stderr, one line, only when the lock is held | `waiting for another tln: <id>` |
| A warning of `config.toml` (an unknown key, D7 of slice 021) | stderr, before any request (the code of `roc install`) | `warning: ...` |
| A failure (refusal, decline, digest, network) | stderr, one line, `tln: error[<kind>]: ...`, then the exit code of the kind (13, 16, 15, 18, 2) | Section 6 |
| Progress of the download (R-DA6) | Not built (slice 021 out of scope). No progress line. | |
| The compat warning of `roc install` | Not printed in the proxy (question Q3) | |

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-PX4 (a missing compiler follows `TALON_AUTO_INSTALL` and the consent rules), R-DL8 (`ask`: the prompt, then install and run. No person: the error that names `TALON_AUTO_INSTALL=yes` and `tln roc install <id>`, exit 13 before the compiler runs) | `Proxy.want`, `Proxy.run!` (step 9), `Consent.proxy_download` | L0 `want`. L2 `proxy/px2-install` runs 1, 3, 5. L3 `compilers/px2-proxy-install` run 1 |
| R-DL9 (`yes`: install and run, no prompt, in each mode) | `Proxy.auto_install`, `Proxy.want` | L0 `auto_install`, `want`. L2 runs 4, 7, 8, 9. L3 runs 4 to 6 |
| R-DL10 (`no`: the error, no prompt, in each mode) | same | L0 `want`. L2 run 6. L3 run 2 |
| R-EV6 (`TALON_AUTO_INSTALL`: `ask`, `yes`, `no`; another value counts as not set) | `Proxy.auto_install` | L0 `auto_install` (11 rows). L2 run 11. L3 part 3 |
| R-NI5 (the prompt: required download that the command does not name, default Yes for the proxy, flags `--allow-downloads`, `--yes`, `TALON_AUTO_INSTALL=yes`, no person: exit 13) | `Consent.proxy_download` | L0 `consent` (6 decisions, 6 texts, 3 replies). L2 runs 1, 3 |
| R-DL1 (one prompt for the run, count and size), R-DL3 (default Yes for the proxy) | `Consent.proxy_download` | L0 `consent`. L2 run 1 (Enter gives Yes) |
| R-DL5 (`TALON_AUTO_INSTALL=yes` is the answer of the required prompt, the answer line goes to stderr, R-NM6) | `Proxy.run!` step 9d | L2 runs 4, 7. L3 run 5 |
| R-CC4 (the steps of an install: step 2 the consent before the lock, step 3 the lock, step 4 the check under the lock, step 7 the unlock), R-CC3 (point 5: no `ask!` under a lock) | `RocInstall.offer!`, `RocInstall.install_offer!` | L2 run 1 (the order in `calls.log`, no `VIOLATION` line). L3 run 6 (3 proxies, 1 download) |
| R-CC9 (`.last-use` of the compiler that was just installed, before it starts) | `Proxy.run!` step 9f | L2 runs 1, 4, 7, 9 (`tree.diff`). L3 runs 5, 6 |
| R-SO15 (the first compiler that Talon installs is the global default) | `RocInstall.install_offer!` | L2 run 1 (`config.toml` is new), run 4 (stays). L3 run 5, 6 |
| R-CV4 (the digest check: exit 16 through the proxy, the compiler does not run) | `RocInstall.install_offer!` | L2 run 8. L3 run 4 |
| R-NM6 (the answer line) | `Prompt.ask!` with `flag: Ok(Yes)` | L2 runs 4, 7. L3 run 5 |

`MISSING=1 scripts/rules.sh R-PX4 R-DL1 R-DL3 R-DL5 R-DL8 R-DL9 R-DL10 R-EV6 R-NI5 R-CC4` lists none of these ids (each has a test).

## 2. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Proxy.roc` | 483 (+36) | Stubs | 2 new functions in the `Proxy` block (`auto_install`, `want`, bodies `crash "todo"`). The doc of the module has the new steps 9a to 9f and the table "where the output goes". `go!` is not changed: it still refuses (so the old runs pass). `import Mode` is new. |
| `cli/lib/Consent.roc` | 167 (+13) | Stub | `proxy_download`: `crash "todo"` |
| `cli/lib/RocInstall.roc` | 350 (+23) | Stubs | New `Offer` type, `offer!` and `install_offer!` (bodies `crash "todo"`), and a doc table of the 2 parts. `run!` and `flow!` are not changed. |
| `tests/unit/proxy.roc` | 276 (+57) | Test agent | 2 new `expect`s (`auto_install` 11 rows, `want` 18 rows) |
| `tests/unit/consent.roc` | 171 (+34) | Test agent | 1 new `expect` (`proxy_download`) |
| `tests/commands/cases/proxy/px2-install/` | 1 case | Test agent | L2, 11 runs. `fx/http` is a copy of the one of `roc/ri1-flow` (the same fake list). |
| `tests/scenarios/compilers/px2-proxy-install/` | 1 case | Test agent | L3, 6 parts. `given/http` was made by `ARCHIVE=real tests/tools/mk-nightly.sh` (the command is in the `cmd` header). |
| `tests/commands/cases/proxy/px1-flow/expect/calls.log` | +2 lines | Test agent | Old test that changes (section 5) |
| `research/slice-023b-revert/` | | Test agent | `before/` (copies and `NEW.txt`), `stubs/`, `mutate.py`, `results.md`, `run.log` |

No `Fx` field is new, no runner or harness changed, `tests/tools/` is not changed (`mk-nightly.sh` and `fakehttp.py` are enough). `docs/slices/PLAN-P1.md` is not changed.

## 3. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Proxy.auto_install` | `List((Str, Str)) -> [Ask, Yes, No]`. `ask` and no variable: `Ask`. `yes`: `Yes`. `no`: `No`. Any other text (also empty, also `YES`) counts as not set: `Ask`. No failure. | R-EV6 |
| `Proxy.want` | `{ id : Str, auto : [Ask, Yes, No], mode : Mode } -> [Refuse, Install, Ask, NeedTty]` (the table is in the doc) | R-PX4, R-DL8 to R-DL10, R-NI5 |
| `Consent.proxy_download` | `{ id : Str, source : Str, size : U64 } -> Prompt` | R-NI5, R-DL1, R-DL3 |
| `RocInstall.Offer` | `[Present({ id : Str }), Download({ id : Str, size : U64, ctx : Ctx })]` | R-CC4 step 1 |
| `RocInstall.offer!` | `Fx, { id : Str, env : List((Str, Str)), offline : Bool } => Try(RocInstall.Offer, Fail)`: steps 2 to 6 of `tln roc install` | R-CC4, R-CV4 |
| `RocInstall.install_offer!` | `Fx, { id : Str, size : U64, ctx : Ctx } => Try({ id : Str, item : Str, how : [Installed, Present], default : [Set, Kept], compat : Compat }, Fail)`: steps 8 to 12 | R-CC4, R-CC3, R-SO15 |

Unchanged: `RocInstall.run!` has the same calls in the same order as today (the code agent builds it from the 2 parts: `offer!`, `ask_download!`, `install_offer!`). `Proxy.missing` is the text for the refusal (R-DL8, R-DL10).

## 4. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/proxy.roc`: `auto_install` (11 rows) | `ask`, `yes`, `no`, not set, no variable, the other variables are not read. `true`, `1`, `YES`, the empty text and `no thanks` count as not set (`Ask`). | R-EV6, R-DL8 to R-DL10 |
| L0 | same: `want` (11 rows for a nightly tag, 7 for other ids) | `ask`: a person gives `Ask`, not known gives `NeedTty`, no person gives `Refuse`. `yes` gives `Install` in each mode, also not known (no `tty!` call). `no` gives `Refuse` in each mode, also not known. The July form of a tag counts. A prefix, `link-dev`, `git-0123abcd`, `copy-x`, `0.1.0` and the empty text give `Refuse` also for `yes` and also with not known (no `tty!` call). | R-PX4, R-DL3, R-DL4, R-DL8 to R-DL10, R-NI5, R-CV1 |
| L0 | `tests/unit/consent.roc`: `proxy_download` (6 decisions, 6 texts, 3 replies) | Required. No person and no flag: `Stop` with `Pass --allow-downloads or TALON_AUTO_INSTALL=yes or --yes.`. `--yes` and the flag give Yes. A person gives `Ask`. The prompt text with the source and the size (`73.9 MB`, `453 B`). The answer lines. The default is Yes (Enter, `n`, `Y`). | R-NI5, R-DL1, R-DL3, R-DL5, R-NM5, R-NM6, R-NM8, R-NR2 |
| L2 | `proxy/px2-install` (11 runs, `commands` entry, a person is there: `fx/tty`) | See the list below. One case checks stdout (nothing but the `== ` and `exit` lines: the install prints nothing on stdout), the exit codes, stderr, the file tree (4 installed compilers, `.talon.json`, `.last-use`, `config.toml`, `projects.json`) and the 282 lines of `calls.log`. | R-PX4, R-DL1, R-DL3, R-DL5, R-DL8 to R-DL10, R-EV6, R-NI5, R-CC3, R-CC4, R-CC9, R-SO15, R-CV4, R-NM6 |
| L3 | `compilers/px2-proxy-install` (6 parts) | The real binary as `roc`, real `curl` and `tar`, the fake release server, `ARCHIVE=real`. See the list below. | R-PX4, R-DL8 to R-DL10, R-EV6, R-CC3, R-CC4, R-CC9, R-SO15, R-CV4, R-E1 |

L2 runs of `px2-install` (`fx/commands` has the comments). The first run is a person (`fx/tty` true), no `CI`. `fx/answers`: an empty line (Enter), then `n`.

| # | Command | Shows |
| --- | --- | --- |
| 1 | `check p1/main.roc` (the pin is not installed) | `tty`, the list (fetch), the prompt with the source `the roc: entry of the header` and `73.9 MB`, no lock yet (R-CC3 point 5), then the lock, the install, the unlock, `config.toml` is made (R-SO15), `.last-use`, `exec` of the new compiler. stdout is empty. |
| 2 | the same | Installed now: no `tty`, no list, no prompt, no lock |
| 3 | `+nightly-2026-10-12-2664a27 version`, the answer is `n` | Exit 13, `<id> is not installed. Nothing was downloaded.`, no lock, no write, no `exec` |
| 4 | `+nightly-2026-10-14-38a3029 version`, `TALON_AUTO_INSTALL=yes`, `CI=true` | No prompt, no `tty` call. The answer line `downloading <id> (73.4 MB)` on stderr. Install. The default stays. |
| 5 | `+nightly-2026-10-12-2664a27 version`, `CI=true` | R-DL8: no person. Exit 13 with the text of `Proxy.missing`. No `tty`, no list, no request. |
| 6 | the same, `TALON_AUTO_INSTALL=no`, a person is there | R-DL10: exit 13, no `tty` call, no prompt |
| 7 | `version`, `ROC_TOOLCHAIN=nightly-2026-10-13-91fa0c2`, `TALON_AUTO_INSTALL=yes`, a person is there | R-DL9 with a person: no prompt, no `tty` call. Rank 2. |
| 8 | `+nightly-2026-10-17-601b54c version`, `yes`; the digest of the asset is wrong | Exit 16, no `exec`, the temp dir and the probe dir are deleted, the lock is released |
| 9 | `+nightly-2026-10-16-1df370f version`, `yes`; `roc check` makes 2 compat dirs | Exit 0, no compat warning (Q3), `compat: null` in `.talon.json` |
| 10 | `+nightly-2026-10 version`, `yes` | Q2: a text that is not a nightly tag is not downloaded. Exit 13, the text of `Proxy.missing`, no list. |
| 11 | `+nightly-2026-10-12-2664a27 version`, `TALON_AUTO_INSTALL=true`, `CI=true` | Q1: counts as not set (`ask`). No person: the refusal of run 5, exit 13, no `tty` call. |

L3 parts of `px2-proxy-install` (`cmd` has the comments). The runner has `CI=true`, so no part has a prompt. The first part also fills `path-roc.json`, so the 3 runs at the end do not run `roc version` on the fake `roc` of `PATH`.

| # | Part | Shows |
| --- | --- | --- |
| 1 | `roc +<id> version`, no variable | R-DL8: exit 13, nothing in the store, no request. `roc.log` has the one `version` of the walk of `PATH` (slice 023 D5). |
| 2 | `TALON_AUTO_INSTALL=no` | R-DL10: exit 13 |
| 3 | `TALON_AUTO_INSTALL=maybe` | R-EV6: counts as not set (`ask`), no person: the same refusal as part 1, exit 13 |
| 4 | `yes`, a release with a wrong digest | R-CV4: exit 16 through the proxy, `downloading <id> (454 B)` and the error on stderr, nothing in the store, no temp, no lock |
| 5 | `yes`, `build p1/main.roc` (the pin) | R-PX4, R-DL9: the pin is installed and runs (the fake `roc` prints its version, exit 0). `.last-use` has the time of Talon (R-CC9). `config.toml` has the new compiler as `default-roc` (R-SO15). |
| 6 | 3 proxies at once for one compiler that is not installed (the body of its asset is slow: 0.6 s) | R-CC3, R-CC4: 3 exit codes 0, 3 times `Roc compiler version <id>` on stdout and nothing else, 3 answer lines (each run consents before the lock), 1 request for the asset (also in `expect/http.log`), `.last-use`. The store has the 2 compilers and no temp dir and no lock. The default is still the first one. |

Budget: 3 L0 `expect`s (2 files), 2 deep cases (L2 1, L3 1). Times on the stub tree: check 7.0 s in a full run (3.0 s alone), l0 6.0 s, l2 8.8 s, l3 9.2 s, selftest 3.5 s. All within the budget (TW26). The L3 case takes about 6 s alone with the reference (the build of `tln` is 2 s of it) and runs in parallel with the others.

## 5. Old tests that changed

| File | Change | Why |
| --- | --- | --- |
| `tests/commands/cases/proxy/px1-flow/expect/calls.log` | +2 lines: `tty` after the `path_roc` block of run 10 (`check p9/main.roc`, the pin is not installed) and of run 12 (`+nightly-2026-10-21-5349569 check`) | D9 of slice 023: the 2 refusals are now `ask` with a person unknown (no `CI`, `fx/tty` is not set): the proxy asks the terminal once (R-HF1, R-NM1) before it refuses. Run 11 (`TALON_AUTO_INSTALL=no`) and run 13 (rank 4, R-SO13) are the same as before. The expected stdout, stderr and exit codes of the case do not change. |

Both lines are `tty` only, in the same place (checked with `diff` against `research/slice-023b-revert/before/`). On the stub tree this case fails by these 2 lines. No other old test changes: the 5 other L2 cases of `proxy/`, the L3 cases of slice 023 and `roc/ri1-flow` stay as they are (the refactor of `RocInstall.run!` keeps its calls: the code agent checks with these cases).

## 6. Output proposals (TW24, for the review)

| Where | Proposal |
| --- | --- |
| The prompt R-NI5 (stderr, `Fx.ask!`) | `<id> (<source>) is not installed. Download 1 compiler, <size>? [Y/n] `. `<source>` is `roc +<id>`, `ROC_TOOLCHAIN`, `the roc: entry of the header`, `.roc-version` or `the global default` (the words of `Proxy.missing`). `<size>` is as in `roc install` (`73.9 MB`). Prompt id `proxy-download`. |
| The answer line (R-NM6) | `downloading <id> (<size>)`. With `n` in a prompt: no line (the failure follows). |
| Decline | `tln: error[consent]: <id> is not installed. Nothing was downloaded.` Exit 13 (the text of `roc install`, `Consent.roc_install_declined`). |
| `Required` text (not shown by the proxy) | `the download of <id> needs consent. Pass --allow-downloads or TALON_AUTO_INSTALL=yes or --yes.` It is for the commands of slice 025. |
| Refusal (R-DL8, R-DL10) | The text of slice 023 (`Proxy.missing`) is not changed: `the compiler <id> (<source>) is not installed. Run: tln roc install <id>, or set TALON_AUTO_INSTALL=yes.` |
| Bad `TALON_AUTO_INSTALL` | No output of its own: it counts as not set (Q1). |
| Install failures | The text of slices 020 and 021, with the exit code of the kind: 16 (`sha256 of <id> differs ...`), 15 (`download of <id> failed: 404 (<url>)`), 18 (no `curl` and no `wget`, no asset for the system), 2 (`<id> has no asset for <target>`). They go through `Fail.line` as the other failures of the proxy (R-E4). |
| `--json` | The proxy has none (R-PD17). No `data` field. |

## 7. Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `RocInstall` is 2 functions with the consent between them: `offer!` (list, pick, digest: gives the size) and `install_offer!` (lock, download, default). `run!` and the proxy call both. | One function with the consent as a closure (`ask!` in a record): an effectful closure in a record is a risk for the compiler (limits list). The proxy calls `RocInstall.run!`: its prompt has the kind Default (R-NM4: answer Yes with no person), against R-DL8, and it prints on stdout. |
| D2 | `Proxy.want` decides before any request. A refusal (no person with `ask`, `no`, a text that is not a nightly tag) needs no list: it is fast and works with no network. | Fetch the list first (a CI refusal would need the network). |
| D3 | The prompt is the new `Consent.proxy_download` (kind Required, the answer flags of R-NI5, default Yes for the proxy: R-DL3). It comes after the list (it needs the size, R-DL1) and before the lock (R-CC3 point 5, R-CC4 step 2). | `Consent.roc_install` (kind Default: it answers Yes with no person). |
| D4 | `TALON_AUTO_INSTALL=yes` is the flag `Ok(Yes)` of `Prompt.ask!`, so the answer line (R-NM6) is printed on stderr, as `roc install` does. | No line for `yes` (R-NM6 says the line is printed for each answer with no prompt). |
| D5 | The answer `n` of the prompt is the failure `Consent.roc_install_declined` (exit 13, R-CC4 step 2: "with no consent, stop"). | A new text. |
| D6 | The compiler that runs is the id that the offer or the install gives (the id of the list), and `.last-use` is written for it before `exec` (R-CC9). | The id as typed (the other tag form of a pin gives the id of the list). |
| D7 | An install failure is returned and printed as every failure of the proxy: `Fail.line` on stderr, the exit code of its kind. The compiler does not run. | Run the compiler of rank 7 or another one. |
| D8 | The install sets the global default when none is set (R-SO15: "the first compiler that Talon installs"), also in the proxy, silently. | No default change from the proxy (the text of R-SO15 has no exception). |
| D9 | `TALON_AUTO_INSTALL` is read only when the selected compiler is missing. | Read it at the start of each run. |
| D10 | The `tty!` call (R-HF1) is made once, only for `ask` with a mode that is not known. `yes`, `no`, and an id that is never downloaded make no `tty!` call. | Always ask the terminal first. |
| D11 | The walk of `PATH` (slice 023 D5) still runs before the install for a missing compiler (the id on `PATH` can be the missing id, R-SO10). The order of the calls: selection, walk, then step 9. | Walk after the refusal. |
| D12 | `offer!` gets `env` from the caller (so `run!` keeps its `env_all` call and the proxy does not call it again). It calls `clock!`, `platform!` and reads `config.toml` itself (the proxy has read the config already: the `calls.log` shows the repeat). | Pass the clock, the platform and the config in (more fields, a change of `run!`). |

## 8. Out of scope

| Rule or item | Reason |
| --- | --- |
| R-SO13 (rank 4 with no installed compiler in the range: the newest release in the range is a required download), R-NI5 for `add`, `update`, `upgrade`, `install`, `remove`, `probe`, `verify`, `--allow-downloads`, R-DL2 and R-DL4 for the other commands, R-DL6 (the cap), R-NI4 | Slice 025 (the plan row). The proxy keeps the refusal of `NoneInRange` (the `px1-flow` run 13). |
| The text of `Compiler.failure(NoneInRange)`: `This version of tln does not download a compiler for a run.` | Not true any more for the other ranks. Slice 025 changes it with R-SO13 (question Q5). |
| The L3 case with a TTY for the proxy prompt | The prompt is tested in L2 (the order of the calls, the text, Enter and `n`) and in L0. The real `ask!` is tested by `fx/hf1-tty`. Slice 025 has "one TTY case" in the plan (PLAN-P1 3.1). |
| `TALON_PROXY=0` with a missing compiler | Question Q4. No test. The code agent keeps the consent rules (R-DL7). |
| A missing pin in the other tag form (R-CV1) and `Present` after the pick | The pick is the code of slice 021 (L3 `ri1` run 5). The mutation of the second `Present` check in `offer!` is not caught (I6 in `results.md`): no proxy path reaches it, because the selection maps the other tag form to the installed id before. |
| Ctrl-C and SIGKILL of a proxy during the install | The install code is the one of slice 021 (R-CC2). The proxy adds no state. |
| A failed install and the next process that waits (R-CC4 step 7) | Same code as `roc install` (L2 `ri1-flow` run 6). |
| Progress of the download (R-DA6) | Slice 021 out of scope |
| A release version as a missing compiler (`.roc-version` `0.1.0`) | No source of releases (R-NS2). It is `Refuse` (Q2). |

## 9. Questions (TW17) and design gaps

The tests pin the default of each question. A different answer changes the named expected files only.

| # | Text | Default of the tests and of the reference |
| --- | --- | --- |
| Q1 | R-EV6 lists `ask`, `yes`, `no`. What does another value give (`true`, `1`, `YES`, the empty text)? | Answered by the manager (review): counts as not set, so `ask`, as a bad `TALON_NIGHTLY` (`docs/slices/ANSWERS.md`). Pinned by L0 `auto_install`, L2 run 11, L3 part 3. |
| Q2 | Which missing compilers does the proxy download? A prefix (`+nightly-2026-10`), a build (`link-`, `git-`, `copy-`) and a release version cannot be one asset of the list (R-NS2: no release is known). | Only a nightly tag in either form (`Pin.is_nightly`). All other ids are refused with the text of slice 023, also with `yes`. Pinned by L0 `want` (7 rows) and L2 run 10. The other option: let the pick of `offer!` choose for a prefix. |
| Q3 | The compat warning of `roc install` (a compat dir that is not known) in a proxy install | Not printed (the stderr of the proxy belongs to roc). `.talon.json` gets `compat: null`. Pinned by L2 run 9. |
| Q4 | R-PX7: `TALON_PROXY=0` "runs the selected compiler with no extra work". Does an install count as extra work? | The consent rules apply to each proxy run (R-DL7), so the install runs as with no opt-out, and `.last-use` is not written (slice 023 Q1). Not tested. |
| Q5 | R-SO13: rank 4 with no installed compiler in the range. The proxy keeps the refusal in 023b (plan row 025). The text says that `tln` does not download a compiler for a run: not true for the other ranks now. | Unchanged text. Slice 025 changes the behavior and the text. |
| G1 | R-NM6 says that Talon prints the answer when it answers a prompt with no person. So a CI job with `TALON_AUTO_INSTALL=yes` gets the line `downloading <id> (<size>)` on the stderr of the build before the compiler starts. The design (6.2) does not say that the stderr of the proxy belongs to roc: this is a rule of slice 023 (D10). | The line is printed (D4). If the manager wants a silent proxy, R-NM6 needs an exception for the proxy. |
| G2 | R-DL3 and R-NI5 give the default Yes for the proxy, but R-DL8 says "install and run" for `ask` in an interactive run and does not say what the exit code is for the answer `n`. R-CC4 step 2 says "with no consent, stop (exit code 13)". | Exit 13 (D5). |

## 10. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | `Proxy.go!`: the steps of the table in the doc of the module (9a to 9f). The L2 `calls.log` is exact. The calls of a missing compiler, in order: the walk of `PATH` (step 8, as today), then `tty` (only for `ask` with `NeedsTty`), then the calls of `RocInstall.offer!` (`clock`, `platform`, `read_files` of `config.toml`, `list_dirs` of `toolchains`, the list), then the prompt (`ask`), then the calls of `install_offer!`. `Proxy.want` gives `Refuse` before any of these. |
| N2 | `Install`: the flag of `Prompt.ask!` is `Ok(Yes)` (the answer line). `Ask`: the flag is `Err(NoFlag)` and the mode is the `Interactive` that `Mode.with_tty` gave, so `Prompt.ask!` calls `fx.ask!` once. The mode of the proxy is `Mode.from_env({ env, json: Bool.False })`. |
| N3 | After the install: `.last-use` for the id of the result, then `canonical`, then `exec` of `<cache>/toolchains/<id>/roc`. `Proxy.program` needs the id in `installed` (add it). The compiler on `PATH` has no `.last-use`, as before. |
| N4 | `RocInstall.run!` keeps its calls in the same order: `ri1-flow` and the L3 cases of slice 021 must not change (a check that you did not break the refactor). `offer!` does not call `env_all!` (the caller gives `env`). `ask_download!` stays in `run!`. |
| N5 | The proxy prints nothing on stdout in the install (section 0): do not call `RocInstall.print!`. |
| N6 | `Proxy.want` and `Proxy.auto_install` are pure. The texts are in the doc of the functions and in the L0 rows. |
| N7 | Compiler limits found while the reference was written: `Present({ id })` is a block, write `Present({ id: id })`. `var` cannot be a variable name. An unused variable is a warning, and `roc build` exits 2 on a warning. A tag name equal to a module name (`Prompt`) is a risk: the result of `want` uses `Ask`, not `Prompt`. |
| N8 | Format with `roc fmt` (the `fmt` step). Do not edit a test (TW18). A question goes to the manager. |

## 11. Revert check (TW12)

The private reference made all new tests pass (`scripts/test.sh` exit 0 with it). 33 small mutations of it were run, one at a time, each with the layers that should catch it (`research/slice-023b-revert/mutate.py`, the table is `results.md`, the log is `run.log`). Each mutation first compiles with no warning (`roc check` of `cli/lib/main.roc` and `cli/main.roc`), else it is `INVALID` and is rewritten or dropped (D3 and D5 were rewritten, 2 more with a missing name and an unused variable were dropped). 32 of 33 are caught. The one that is not (I6) is no behavior of the proxy (section 8).

| Group | Mutations | Caught by |
| --- | --- | --- |
| `auto_install`: `yes`, `no`, not set, a bad value counts as `Yes`, the case | A1 to A5 | L0 (A1, A3, A4 also L2 and L3, A2 also L2, A5 only L0) |
| `want`: the nightly check, `no`, `yes` (2 forms), no person, not known, `Ask` for a person, `is_id` for `is_nightly` | W1 to W8 | L0 (W3 and W7 only L0, the others also L2) |
| `download!`: no refusal, the flag of `yes`, no decline check, the source text, the mode of the prompt, no `.last-use`, `offline`, no install | D1 to D8 | L2 (D1, D2, D6, D7, D8 also L3) |
| `RocInstall`: no check under the lock (I1), the default never set (I2), the size 0 (I3), `NoWait` (I4), a line on stdout (I5), the early `Present` after the pick (I6) | I1 to I6 | I1 only L3 (so the 3 proxies do meet at the lock). I2, I4, I5 L2 and L3. I3 L2. I6 not caught (section 8). |
| `Consent.proxy_download`: the default, the kind, the question (2 forms), the answer line, the id | C1 to C6 | L0 (C1, C3, C4, C6 also L2, C4 also L3) |

Caught only by one layer, by design: A2 (`no`) is not caught by L3, because the L3 runner has `CI=true` and `ask` refuses too: L0 and L2 (a person is there) catch it. W3 (`yes` with a person) is only L0, because L2 runs have the mode `NeedsTty` before the first `tty!` call.

## 12. State on the stub tree (red)

`scripts/test.sh` (2026-10-23): check pass (all files compile), fmt pass, selftest pass. l0: `proxy` and `consent` fail (the new `expect`s: `Roc application crashed ... todo`, from `auto_install`, `want` and `proxy_download`). The other 52 of 54 L0 files pass. l2: 41 passed, 2 failed. l3: 36 passed, 1 failed, 1 skipped.

```text
tests/unit/proxy.roc:   FAILED  (6 old expects pass, the 2 new: Roc application crashed with this message: todo)
tests/unit/consent.roc: FAILED  (3 old pass, the new one: todo)
FAIL proxy/px1-flow            Fx calls differs: the 2 lines `tty` (runs 10 and 12) are missing
FAIL proxy/px2-install         stdout differs: -exit 0 / +exit 13 (runs 1, 2, 4, 7, 8, 9), -exit 16 / +exit 13 (the refusal of slice 023, no install)
FAIL compilers/px2-proxy-install  exit code differs, stdout differs (-exit 16 / +exit 13), the store has no compiler, expect/http.log has 4 requests and the run has 0
```

With the reference all steps pass (before the stubs were put back).

## Review (manager, 2026-10-23)

D1 to D12, the output table (section 0), the proposals, Q2 to Q5, G1 (the one R-NM6 stderr line is accepted) and G2 (exit 13) are accepted. Q5: I note the R-SO13 text fix for slice 025. One change:

| Item | Decision | Change in the tests |
| --- | --- | --- |
| Q1 | The user already answered the same case for `TALON_NIGHTLY` (`docs/slices/ANSWERS.md`, row "Bad TALON_NIGHTLY value"): a bad value counts as not set. So a `TALON_AUTO_INSTALL` value other than `ask`, `yes`, `no` counts as not set, and the mode is `ask` (the default). No exit 2. | `Proxy.auto_install` has the type `List((Str, Str)) -> [Ask, Yes, No]` (no `Try`, no failure text). L0 `auto_install`: the 5 bad rows give `Ask`. L2 run 11 has `CI=true` and gives the refusal of run 5 (exit 13, no `tty` call). L3 part 3 gives the refusal of part 1 (exit 13). Expected files made again with the reference. Mutations A4 (a bad value counts as `Yes`) and A5 are caught (A1 to A5 re-run: 5 of 5). |

Test agent: the private reference is deleted. `scripts/test.sh` on the stub tree is red as in section 12.

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | The steps 9a to 9f are 2 private functions in `cli/lib/Proxy.roc` (`install_missing!`, `offer_and_install!`). `Proxy.roc` is 535 lines: no split. | A `ProxyInstall` module (the file is under 600 lines). |
| C2 | `Proxy.want` is called twice for the mode that is not known: the first call decides if `tty!` runs, the second gives the answer. Both calls are pure. | A `match` on the first result with a copy of the table. |
| C3 | `RocInstall.run!` keeps its calls: `flow!` is `env_all!`, `offer!`, `ask_download!`, `install_offer!`. For `Present`, `flow!` calls `Roots.from_env` again (pure) to build the item path. | `Present` with the item path in `Offer` (a change of the public type). |
| C4 | `install_offer!` does not read `offer.size`. The field stays (the signature of the slice). | |

## Code result

| Item | Value |
| --- | --- |
| `scripts/test.sh` | exit 0. check 7.0 s, fmt 0.1 s, l0 6.0 s, l2 43 cases passed 10.1 s, l3 37 passed 1 skipped 9.3 s, selftest 42 passed 3.5 s. `OPT=speed`: exit 0 (l2 85.0 s: LLVM build, no warning). |
| Files | `cli/lib/Proxy.roc` 535 (+52), `cli/lib/RocInstall.roc` 359 (+9), `cli/lib/Consent.roc` 178 (+11) |
| Signatures | No public signature changed. |

## Verify results

Code agent: 34 small mutations (`research/slice-023b-revert/code-mutate.py`, `code-run-1.log`, `code-run-2.log`). Caught 34 of 34. D6 and C2 did not run in the first pass (an unused variable, a text with 2 matches): they were written again and run in the second pass. Each run first restores the 3 files from `code-final/`. After the run the 3 files are the same as `code-final/` (`code-final.sha256`: OK). Only the tests that should catch a mutation were run (no full sweep).

| Id | What the change breaks | First test that failed |
| --- | --- | --- |
| A1 | R-EV6: yes counts as ask | l0:proxy |
| A2 | R-EV6: no counts as ask | l0:proxy |
| A3 | R-EV6: a bad value counts as yes | l0:proxy |
| W1 | Q2: a text that is not a nightly tag is downloaded | l0:proxy |
| W2 | R-DL10: no does not refuse | l0:proxy |
| W3 | R-DL9: yes with a person asks | l0:proxy |
| W4 | R-HF1: no tty call, ask with an unknown mode | l0:proxy |
| W5 | R-DL8: no person installs | l0:proxy |
| W6 | R-DL8: a person gets a refusal | l0:proxy |
| W7 | Q2: the check is any id | l0:proxy |
| D1 | R-DL8, R-DL10: no refusal | l2:proxy/ |
| D2 | R-DL5: yes has no flag | l2:proxy/ |
| D3 | R-CC4 step 2: the answer No installs | l2:proxy/ |
| D4 | R-NI5: the source of the prompt | l2:proxy/ |
| D5 | R-NI5: --yes is always set | l2:proxy/ |
| D7 | the offer is offline | l2:proxy/ |
| D8 | N3: the new id is not installed for the program | l2:proxy/ |
| D9 | R-PX4: no install | l2:proxy/ |
| D10 | R-CC9: no .last-use after the install | l2:proxy/ |
| I1 | R-CC5: no wait for the lock | l3:px2-proxy-install |
| I2 | R-SO15: no default | l2:proxy/ |
| I3 | R-DL1: the size of the offer | l2:proxy/ |
| I4 | R-CC4 step 4: no check under the lock | l3:px2-proxy-install |
| I5 | N5: a line on stdout | l2:proxy/ |
| I6 | run!: the size of the prompt | l2:roc/ri1-flow |
| I7 | R-DI12: --offline downloads | l2:roc/ri1-flow |
| I8 | R-CC4 step 1: an installed id makes a request | l2:roc/ri1-flow |
| C1 | R-DL3: the default is No | l0:consent |
| C3 | R-DL1: the count | l0:consent |
| C4 | R-NM6: the answer line | l0:consent |
| C5 | the id of the prompt | l0:consent |
| C6 | R-NI5: no source in the question | l0:consent |
| D6 | R-HF1: no tty call | l2:proxy/ |
| C2 | R-NI5: the flags | l0:consent |

Note: the mutations of the reference that touched `Present` after the pick (I6 of the test agent) were not repeated: the slice says no proxy path reaches it (section 8). The `Present` check of the early `has_dir` in `offer!` (I8 here) is caught by `roc/ri1-flow`.

## Close (manager, 2026-10-23)

C1 to C4 of the code agent are accepted. `scripts/test.sh` exits 0 with no WARN. Status: done.
