# 025 Download consent

Phase: P1. Status: done

Slice 025 replaces the P0 refusal of a compiler that is not installed by the consent rules of CLI 6.2 (R-DL1 to R-DL7, R-NI5). A command that resolves (`add`, `update`, `install`, `remove`, `verify`) needs one compiler for the first probe (R-SO22, R-BL3: the baseline and the candidate run on the same compiler). When that compiler is a nightly that is not installed, the command now reads the list of releases, then asks once (a person), or stops with exit 13 (no person, no answer), or downloads (an answer: `--allow-downloads`, `--yes`, `TALON_AUTO_INSTALL=yes`). It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-025-revert/before/` (with `NEW.txt`).

Scope of this part (025a): the required download of the first-probe compiler, and its wiring in the 5 commands. The slice is too large for one pass, so it has a split (section 9). Only part 025a is tested. The optional downloads (R-NI4, R-DL6, R-P5) are in part 025b: this part has no function for them (review, Q2 and Q8).

## 1. Rules

| Id | Rule (short) | Where | Tested by |
| --- | --- | --- | --- |
| R-DL1 | One prompt for each command, with the count and the size | `Consent.command_download`, `Consent.download_stop`, `Ladder.start!` | L0 `consent` (`command_download`, `download_stop`). L2 `consent/dl1-resolve` runs 2, 4. `consent/dl2-verify-workspace` run 1 (2 members, 1 prompt). L3 `compilers/dl1-resolve-consent` part 1, `dl2-consent-tty` part 1 |
| R-DL2 | The compiler of the first probe is a required download | `Compiler.find` | L0 `compiler` (`find`, 12 rows, agrees with `require`). L2 `dl1-resolve` |
| R-DL3 | Interactive: prompt, default No for a command that does not name the download | `Consent.command_download` | L0 `consent`. L2 `dl1-resolve` runs 2, 3. L3 `dl2-consent-tty` part 1 |
| R-DL4 | No person: exit 13 and an error that names `--allow-downloads` and `TALON_AUTO_INSTALL=yes` | `Consent.required_want`, `Consent.download_stop` | L0 `consent` (`required_want`, `download_stop`). L2 `dl1-resolve` runs 4, 9. L3 `dl1-resolve-consent` parts 1, 2 |
| R-DL5 | `--yes` and `--allow-downloads` accept, `TALON_AUTO_INSTALL=yes` accepts, `=no` refuses with no prompt, and a flag wins over the variable (review, Q1) | `Consent.required_want`, `Consent.auto_install`, `Consent.download_refused` | L0 `consent` (`required_want` 31 rows, `auto_install` 11 rows, refusals). L2 `dl1-resolve` runs 5, 6, 7, 8, 13, 14, 15. L3 `dl1-resolve-consent` parts 3 to 7 |
| R-DL6 | The cap `probe.max-toolchains` for optional downloads | none in 025a | Part 025b (section 9). The prompt of 025a takes a `count` and a total `size`, so it can show the optional downloads too (R-DL1). |
| R-DL7 | One rule set for each command | the 5 commands share `Ladder.start!` | L2 `dl1-resolve` runs 6 (`remove`), 12 (`add`), 13 (`remove`). `dl2` (`verify`). Other commands: out of scope (section 8) |
| R-NI4 | Optional compiler downloads: the flag `--probe-downloads` is read | `Opts.probe_downloads` | L0 `opts` (7 rows), `args` (the flag is accepted by 5 commands). The prompt and the skipped line are in part 025b (section 9). |
| R-NI5 | Required download that the command does not name: prompt, default No, exit 13, answers `--allow-downloads`, `--yes`, `TALON_AUTO_INSTALL=yes` | `Consent.command_download` (kind `Required`) | L0 `consent`. L2 `dl1-resolve` runs 2 to 8. L3 `dl1-resolve-consent` |
| R-SO12 | A rank selects a nightly that is not installed: a required download | `Ladder.start!` | L2 `dl1-resolve` run 11 (`ROC_TOOLCHAIN`). L3 `dl1-resolve-consent` (all parts use `ROC_TOOLCHAIN`) |
| R-SO22 | Download at the first probe, not before. `--no-check` needs no compiler. | `Ladder.start!` | L2 `dl1-resolve` runs 2, 5 (the probes run the new compiler). L3 `dl1-resolve-consent` part 8 (`--no-check`: no request, no download) |
| R-BL3 | The baseline compiler is a required download | `Ladder.start!` | L2 `dl2-verify-workspace`: one download, both members run on it. L3 `dl1-resolve-consent` part 4 |
| R-PH7 | P1 column: the held pin is a required download | `Ladder.start!` | L2 `dl1-resolve` runs 2 to 9. The P0 text stays for `TALON_AUTO_INSTALL=no` (R-DL5): old cases `gaps/g1-slice009`, `ladder/ld-no-check-refuse`, `probe/pb1-ladder` p3 and p8, `probe/pb2-verify` run 4, L3 `verify/vf1-verify`, `compilers/pb1-probes-by-path` run 3 |
| R-FL12 | `--allow-downloads` and `--probe-downloads` are flags of the commands that resolve | `Opts`, `Removal.opts` | L0 `opts` (7 rows), `removal` (4 rows), `args` (accepted rows, 3 failure rows). L2 `dl1-resolve`. L3 `dl1-resolve-consent` part 4 |
| R-EV6 | `TALON_AUTO_INSTALL`: `yes`, `no`, any other text is not set (moved from `Proxy.auto_install`) | `Consent.download_refused` | `Str -> Fail` (kind `Consent`, exit 13): `TALON_AUTO_INSTALL=no`, no flag | R-DL5, R-DL10 |
| `Consent.command_declined` | `Str -> Fail` (kind `Consent`, exit 13): the answer No to `command_download` | R-NI5, R-NM8 |
| `Consent.auto_install` | L0 `consent` (11 rows). L2 `dl1-resolve` runs 6, 7, 9. `proxy/` cases (unchanged) |
| R-P5 | Budget: the cap `probe.max-toolchains` | none in 025a | Part 025b (section 9) |
| FD | Slice 013 gap: a run where the held nightly is a download writes that nightly as the `roc:` pin | `InstallFlow.finish!` (no code change expected) | L2 `dl1-resolve` run 11 (`+ roc: nightly-2026-10-18-5349569`) |
| R-NM6, R-NM8, R-NM10 | Answer line on stderr, the interactive No, `--yes` gives no prompt | `Consent.command_download` (`answer_line`) | L0 `consent`. L2 `dl1-resolve`. L3 `dl1-resolve-consent` part 4 |
| R-HF1 | Ask the terminal only when the mode is not known, and not when an answer exists | `Ladder.download!` (`NeedTty`) | L0 `consent` (`required_want`). L2 `dl1-resolve` runs 5 to 9 (no `tty` call) |
| R-NS2 | A text that is not a nightly tag is never downloaded (as the proxy) | `Consent.required_want` | L0 `consent`. L2 `dl1-resolve` run 10 |

`MISSING=1 scripts/rules.sh R-DL1 R-DL2 R-DL3 R-DL4 R-DL5 R-DL7 R-NI5 R-SO12 R-SO22 R-BL3 R-PH7 R-FL12` lists none of these ids. R-DL6, R-NI4 (prompt), R-P5 and R-SO13 with its text fix are in part 025b (section 9).

## 2. Flow of a command that needs a download (the calls that the L2 cases fix)

| Step | Call | Rule |
| --- | --- | --- |
| 0a | `Launch.toolchains!`: one `list_dirs` of `<cache>/toolchains` | R-SO22 |
| 0b | `Compiler.find`: `Ok(id)` goes on as before (installed, or the `roc` on `PATH`). `Err(Missing)` is a required download. | R-DL2 |
| 0c | `Consent.required_want`: the table is in its doc (6 rows). `Refuse` (not a nightly tag) is the failure of `Compiler.require` (exit 13, the P0 refusal text of 023c). `AutoNo` (`TALON_AUTO_INSTALL=no`, no flag) is `Consent.download_refused`. `Install` and `Ask` read the list (`RocInstall.offer!`). `NeedTty` makes one `tty!` call, then decides again with `Mode.with_tty`. `NeedsConsent` reads the list (the text needs the size), then fails with `Consent.download_stop`. | R-DL4, R-DL5, R-HF1 |
| 0d | `RocInstall.offer!`: `clock`, `platform`, `config.toml`, `toolchains` again, the list (cache or one request), the pick. `Present` is a compiler that was installed in the meantime: go on. | R-CC4 |
| 0e | `Ask`: `Prompt.ask!` with `Consent.command_download`. A reply `No` is exit 13 with `Consent.command_declined`. `Install`: the answer line, no question (R-NM6). | R-DL1, R-DL3 |
| 0f | `RocInstall.install_offer!`: lock, download, extract, check, `rename`, unlock, the default `config.toml` under its lock, as for `roc install`. The new id joins the installed list. | R-CC3, R-CC4 |
| 0g | `Launch.program!`, `Launch.child_env!`, then the probes (`.last-use` before each round). The run has one prompt and one download for all members. `Ladder.run!` and `Ladder.verify!` return the notes and `downloads` (1 after a download, else 0) for `data.downloads`. | R-BL3, R-CC9, review Q7 |

A run with `--no-check`, `--frozen`, `--dry-run` that needs no probe has none of 0a to 0g (R-SO22).

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Consent.roc` | 201 | Stub | 6 new functions with docs (tables): `command_download`, `required_want`, `download_stop`, `download_refused`, `command_declined`, `auto_install`. Bodies are `crash "todo"`. |
| `cli/lib/Compiler.roc` | 240 | Stub | `find` (type, doc, `crash "todo"`). `require` is unchanged. |
| `cli/lib/Opts.roc` | 101 | Test agent (types) | Fields `allow_downloads` and `probe_downloads` (`Err(NoFlag)` for now, so the old cases run) |
| `cli/lib/Removal.roc` | 102 | Test agent (types) | `Opts.allow_downloads` (`Err(NoFlag)` for now) |
| `cli/lib/ResolveBase.roc` | 529 | Test agent (types) | `Request.downloads : { auto, allow, probe, env }`, `Ran.downloads : U64` |
| `cli/lib/Report.roc` | +2 | Test agent (types, doc) | `Outcome.downloads : U64`. The doc of `data.downloads` has the new meaning. `Report.data` still gives `0` (the code agent). |
| `cli/lib/InstallFlow.roc`, `RemoveFlow.roc`, `VerifyFlow.roc` | +2 to +5 each | Test agent (types) | The records `Ran` and `Outcome` have `downloads: 0` (`outcome_of` and `verified!` copy `ran.downloads`). `Ladder` is not changed in the stubs. |
| `cli/lib/Install.roc`, `Update.roc`, `Remove.roc`, `Verify.roc`, `Ls.roc` | +1 each | Test agent (types) | Fill `downloads` with the neutral value `{ auto: Ask, allow: Err(NoFlag), probe: Err(NoFlag), env }` |
| `cli/lib/Proxy.roc`, `Ladder.roc`, `RocInstall.roc`, `Verify.roc` (the text) | none | None (unchanged) | The code agent changes them (section 7) |
| `tests/unit/consent.roc` | +180 | Test agent | 5 new `expect`s (`command_download`, `required_want`, `download_stop`, the two refusals, `auto_install`) |
| `tests/unit/report.roc` | +4 -2 | Test agent | The `data` rows have `downloads: 1` and `0` |
| `tests/unit/compiler.roc` | +34 | Test agent | 1 new `expect` (`find`) |
| `tests/unit/opts.roc`, `removal.roc` | +24, +20 | Test agent | 1 new `expect` each |
| `tests/unit/args.roc` | +12 -1 | Test agent | Rows in 3 `expect`s |
| `tests/unit/proxy.roc` | +1 -22 | Test agent | The `auto_install` `expect` moved to `consent.roc` (the function moves) |
| `tests/commands/main.roc` | +12 -2 | Test agent | The `resolve` entry fills `downloads` (words `allow-downloads`, `probe-downloads`, `auto-install=<yes or no>`) |
| `tests/commands/cases/consent/dl1-resolve/` | 1 case | Test agent | L2, 16 runs (entry `commands`) |
| `tests/commands/cases/consent/dl2-verify-workspace/` | 1 case | Test agent | L2, 2 runs |
| `tests/scenarios/compilers/dl1-resolve-consent/` | 1 case | Test agent | L3, 8 parts |
| `tests/scenarios/compilers/dl2-consent-tty/` | 1 case (tag `tty`) | Test agent | L3, 3 parts |
| `tests/tools/mk-nightly.sh` | +20 -2 | Test agent (test tool) | `ARCHIVE=probe`: the fake `roc` passes `check` and `build`, prints `version`, and logs one line to `prog.log` |
| `tests/run.sh` | +3 -1 | Test agent (test tool) | A case with tag `tty` and `given/http/` runs with the fake HTTP server (the pty runs `with-http.sh`) |
| 9 old L2 cases, 2 old L3 cases | `fx/runs`, `fx/commands`, `cmd`, expected files | Test agent | Section 6 |
| `research/slice-025-revert/` | | Test agent | `before/` (copies, `NEW.txt`), `stubs/`, `mutate.py`, `mutate.out`, `mutate-l2.out`, `bk.sh`, `swap.sh`, `mkstub-consent.py`, `FILES`. The private reference was deleted after the review. |

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Consent.command_download` | `{ id : Str, count : U64, size : U64 } -> Prompt`. Kind `Required(["--allow-downloads", "TALON_AUTO_INSTALL=yes"])`, yes/no, default No. `count` and `size` are the count and the total of all downloads of the command (R-DL1). | R-NI5, R-DL1, R-DL3 |
| `Consent.required_want` | `{ id : Str, auto : [Ask, Yes, No], mode : Mode, yes : Bool, flag : Try(Answer, [NoFlag]) } -> [Refuse, AutoNo, NeedsConsent, Install, Ask, NeedTty]` | R-DL4, R-DL5, R-NS2, R-HF1 |
| `Consent.download_stop` | `{ count : U64, size : U64 } -> Fail` (kind `Consent`, exit 13) | R-DL1, R-DL4 |
| `Consent.auto_install` | `List((Str, Str)) -> [Ask, Yes, No]` (moved from `Proxy.auto_install`) | R-EV6 |
| `Compiler.find` | `{ id : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } -> Try(Str, [Missing])` | R-DL2, R-SO22 |
| `Opts.allow_downloads`, `Opts.probe_downloads` | `Try(Answer, [NoFlag])` (`Ok(Yes)` when the flag is set) | R-FL12 |
| `Removal.Opts.allow_downloads` | `Try(Answer, [NoFlag])` | R-NI5 |
| `ResolveBase.Ran`, `Report.Outcome` | a new field `downloads : U64` | R-DL1 (Q7) |
| `ResolveBase.Request.downloads` | `{ auto : [Ask, Yes, No], allow : Try(Answer, [NoFlag]), probe : Try(Answer, [NoFlag]), env : List((Str, Str)) }` | R-DL5, R-NI4 |

Types that the code agent adds (the tests do not name them): `Ladder.Downloads`, the `downloads` field of `Ladder.Request` and `Ladder.VerifyRequest`, `ResolveBase.ladder_downloads`, and the result of `Ladder.run!` and `Ladder.verify!`: `{ notes : List(Str), downloads : U64 }` in place of the notes.

## 5. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/consent.roc`: `command_download` | 7 decision rows, 10 texts (ids, question, size text, answer lines, subject, and a count of 2: `Download 2 compilers, 147.4 MB?`), 3 replies (Enter is No) | R-NI5, R-DL1, R-DL3, R-DL5, R-NM5, R-NM6, R-NM8, R-NR2 |
| L0 | `consent.roc`: `required_want` | 23 nightly rows (3 modes, flag, `--yes`, auto yes/no/ask, the July form, and 6 rows for a flag or `--yes` over `TALON_AUTO_INSTALL=no`) and 8 other rows (a prefix, link, git, copy, release, a release with auto no, empty) | R-DL1, R-DL3, R-DL4, R-DL5, R-DL7, R-DL9, R-DL10, R-NI5, R-NS2, R-HF1 |
| L0 | `consent.roc`: `download_stop` | Kind and the text for 1 and 2 downloads, and a size in bytes | R-DL1, R-DL4, R-EC13 |
| L0 | `consent.roc`: `download_refused`, `command_declined` | Kind `Consent`, and the two texts that name `tln roc install <id>`, `--allow-downloads` and `TALON_AUTO_INSTALL=yes`. The text of `roc install` is not changed. | R-DL5, R-DL10, R-NI5, R-NM8, R-EC13 |
| L0 | `consent.roc`: `auto_install` | 11 rows (moved from `proxy.roc`) | R-EV6, R-DL5 |
| L0 | `tests/unit/compiler.roc`: `find` | 12 rows, and `require` agrees on each (same id, a refusal where `find` says `Missing`) | R-SO22, R-SO10, R-CV1, R-DL2, R-BL3 |
| L0 | `tests/unit/report.roc`: `data` | `downloads` is the field of the outcome: 1 and 0 | R-J3, R-J4, R-DL1 |
| L0 | `tests/unit/opts.roc`, `removal.roc`, `args.roc` | The 2 flags (7 rows), `remove` takes `--allow-downloads` (4 rows), the 5 commands accept the flags, 3 commands (`list`, `roc install`, `cache gc`) refuse them with the usage text | R-FL12, R-NI4, R-NI5 |
| L2 | `consent/dl1-resolve` (new, 16 runs, entry `commands`) | See the list below | R-DL1, R-DL3, R-DL4, R-DL5, R-DL7, R-DL10, R-EV6, R-FL12, R-NI5, R-NM8, R-NM10, R-NS2, R-SO15, R-SO19, R-SO22, R-BL3, R-CC4, R-RP3 |
| L2 | `consent/dl2-verify-workspace` (new, 2 runs) | One prompt and one download for 2 members. A second run with the compiler installed: no `tty`, no `ask`. | R-DL1, R-DL3, R-NI5, R-BL3, R-SO21, R-SO22, R-CC4 |
| L3 | `compilers/dl1-resolve-consent` (new, 8 parts) | The real binary, real `curl` and `tar`, the fake release server (4 archives with a fake `roc`). See the list below. | R-DL1, R-DL3 to R-DL5, R-DL9, R-DL10, R-NI5, R-EV6, R-FL12, R-SO22, R-BL3, R-CC4, R-CC9, R-SO15, R-NM6, R-J1, R-NM10 |
| L3 | `compilers/dl2-consent-tty` (new, tag `tty`, 3 parts) | A pseudo terminal with `n` then `y`: the question shows with the size and `[y/N]`, `n` gives exit 13 (the text names the way to download) and no download, `y` downloads and probes, the third run asks nothing | R-DL1, R-DL3, R-NI5, R-NM6, R-NM8, R-FL12, R-HF1, R-CC4 |

L2 runs of `dl1-resolve` (`fx/commands`, `rules` and the comments have the text). The fake `tty` is true, so a run with no `env:CI=true` has a person. The fake list of nightlies has 11 tags.

| # | Run | Shows |
| --- | --- | --- |
| 1 | `remove --offline --allow-downloads` (first, no cached list) | `--offline` reaches the offer: exit 15, no lock |
| 2 | `update json` (u1), a person, `y` | `tty`, the list, one `ask` with the size, lock, install, default compiler, 3 probes on the new compiler |
| 3 | `update json` (u2), a person, Enter | Default No: exit 13, the text names `tln roc install`, the flag and the variable. No lock, no write. |
| 4 | `env:CI=true update json` (u3) | No person, no flag: exit 13, the stop with the count and the size, no `tty`, no `ask` |
| 5 | `env:CI=true update json --allow-downloads` (u4) | No question, one answer line, install, probes |
| 6 | `env:CI=true env:TALON_AUTO_INSTALL=yes remove json` (r5) | The variable answers for `remove` too |
| 7 | `env:TALON_AUTO_INSTALL=no update json` (u6), a person | Refused, no `tty`, no list: the text of `download_refused` |
| 8 | `env:CI=true update json --yes` (u7) | `--yes` accepts the download |
| 9 | `env:CI=true env:TALON_AUTO_INSTALL=maybe update json` (u8) | Any other value is not set: the stop of run 4 |
| 10 | `env:CI=true env:TALON_AUTO_INSTALL=yes update json` (u11, pin `0.2.0`) | A release is never downloaded: the P0 refusal text, no list |
| 11 | no pin, `ROC_TOOLCHAIN=nightly-2026-10-18-5349569`, `--allow-downloads` (f1) | FD: after the download the header gets that nightly as its `roc:` pin |
| 12 | `add acme/json@^2.1 --allow-downloads` (u12) | `install` and `add` are one command |
| 13 | `remove json --allow-downloads` (r14) | `remove` takes the flag |
| 14 | `TALON_AUTO_INSTALL=no update json --allow-downloads` (u15) | Q1: the flag wins over the variable. Install, no refusal. |
| 15 | `TALON_AUTO_INSTALL=no update json --yes` (u16) | Q1: `--yes` wins over the variable |
| 16 | `update json --allow-downloads --json` (u17) | Q7: `data.downloads` is 1 |

L3 parts of `dl1-resolve-consent` (`cmd` has the comments). The runner has `CI=true`, so no part has a person.

| # | Part | Shows |
| --- | --- | --- |
| 1 | `ROC_TOOLCHAIN=A tln verify` | Exit 13, the stop text with `573 B`, empty store, one request for the list |
| 2 | `TALON_AUTO_INSTALL=maybe` | The same stop |
| 3 | `TALON_AUTO_INSTALL=no` | Exit 13, the `download_refused` text, no new request (the list is cached) |
| 4 | `--allow-downloads` | One answer line, one download, the install, 3 probes by the new compiler with the cache variables, `.last-use`, `default-roc` set |
| 5 | A is installed | No list, no download, the same 3 probes |
| 6 | `--yes` (another compiler) | Downloads. The default stays the first compiler. |
| 7 | `TALON_AUTO_INSTALL=yes --json` | stdout is only the envelope, with `"downloads":1`. The answer line is on stderr. |
| 8 | `--no-check` with a missing compiler | No request, no download (R-SO22), no leftover `.tmp` or lock file |

## 6. Old tests that changed

The old cases ran with no person (no `tty`, no `CI`) and expected the P0 refusal. Now a missing compiler is a download, so those runs would ask or stop at the list. To keep what each case tests, the runs that expect the refusal get `TALON_AUTO_INSTALL=no` (R-DL5: exit 13, no prompt, no request). Their stderr has the new text of `download_refused` (review, Q4). The verify line changed too (review, Q5). The expected files were made with the private reference, and each diff was read: only these lines differ.

| File | Change | Why |
| --- | --- | --- |
| `tests/commands/cases/gaps/g1-slice009/fx/commands` (run 1), `rules` | The line starts with `env:TALON_AUTO_INSTALL=no` | R-DL5 |
| `tests/commands/cases/ladder/ld-no-check-refuse/fx/runs` (q1, q6) | The word `auto-install=no` | R-DL5 |
| `tests/commands/cases/probe/pb1-ladder/fx/runs` (p3, p8) | The word `auto-install=no` | R-DL5 |
| `tests/commands/cases/probe/pb2-verify/fx/commands` (run 4) | `env:TALON_AUTO_INSTALL=no` | R-DL5 |
| `expect/stdout` (the `== ...` line) and `expect/stderr` (6 lines) of these 4 cases | The words above, and `the compiler <id> is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` in place of `the compiler <id> is not installed. Run: tln roc install <id>.` | R-DL5, Q4 |
| `expect/stdout` of `closure/cl1-flow`, `closure/cl2-chain`, `verify/vf1-flow`, `workspace/ws1-closure-keys`, `workspace/ws2-verify-members`, `probe/pb2-verify` (13 lines) | `verified: the tuple passes. No project file was written.` in place of `... Nothing was written.` | Q5 |
| `tests/scenarios/verify/vf1-verify/cmd` (2 runs: the pin that is not installed, with and with no `ROC_TOOLCHAIN`) | `env TALON_AUTO_INSTALL=no` | R-DL5 |
| `tests/scenarios/compilers/pb1-probes-by-path/cmd` (run 3) | `env TALON_AUTO_INSTALL=no` | R-DL5 |
| `expect/stdout`, `expect/stderr` of these 2 cases | The `== ...` line, the new refusal text, and the verify line (15 lines) | R-DL5, Q4, Q5 |
| `tests/unit/proxy.roc` | The `auto_install` `expect` moves to `consent.roc` | The function moves (R-EV6) |
| `tests/unit/report.roc` | The `data` rows have `downloads` | Q7 |
| `tests/commands/main.roc` | The `resolve` entry fills `downloads`, new words | `Request.downloads` |

The L3 files of the old cases were made once with a binary built from the pre-slice files in `before/`, then with the reference. Old tests that do not change: the `proxy/` L2 cases and `px1` and `px2` (L3). `Proxy.go!` reads `Consent.auto_install` in place of `Proxy.auto_install`.

## 7. Notes for the code agent

| Item | Note |
| --- | --- |
| Import cycle | `Ladder` cannot import `RocInstall` when `RocInstall` imports `Install` (`Install` imports `Resolve`, `Resolve` imports `InstallFlow`, `InstallFlow` imports `Ladder`). `RocInstall` needs `Install.nightly_of`, `Install.failed!` and `Install.shown_fx`. Move them to a module that both can import. (Accepted in the review.) |
| Order | The list is read before the prompt and before the lock (R-CC3 point 5). The stop of `NeedsConsent` is made after the list is read, because its text has the size (the design example in CLI 3, "Example of a failure"). |
| Config warnings | `RocInstall.offer!` reads `config.toml` again. A warning about a bad `config.toml` key could print twice. No test has a bad key, so no test covers it. |
| One compiler for a run | `start!` runs once for each `Ladder.run!` or `Ladder.verify!`, so a workspace run has one prompt (R-DL1). Do not move the call into the loop of the members. |
| Request types | `Ladder.Request` and `Ladder.VerifyRequest` get a `downloads` field. The 3 flows build it with one function from `ResolveBase.Request` (`mode`, `yes`, `quiet`, `offline` come from `request.prompt` and `request.offline`). |
| Count of downloads | `Ladder.run!` and `Ladder.verify!` return `{ notes, downloads }`. `start!` counts 1 when it installed a compiler. The flows copy it to `Ran.downloads` and `Report.Outcome.downloads`, and `Report.data` writes it. `remove` has no `downloads` field in its `data`. |
| Verify line | `Verify.roc` prints `verified: the tuple passes. No project file was written.` with and with no download. |
| Neutral stubs | The 5 commands and `Opts.parse` have neutral values in the stubs. The code agent replaces them (`Consent.auto_install(env)`, `opts.allow_downloads`, `opts.probe_downloads`). `--probe-downloads` has no reader in 025a. |

## 8. Out of scope

| Id | Reason |
| --- | --- |
| R-SO13 and its text fix (023b Q5), Q3 | Part 025b (section 9). |
| R-NI4 (prompt), R-DL6, R-P5 (cap) | Part 025b. `Consent.optional` was removed in the review: it comes with its first producer, as a part of the one prompt (R-DL1). `--probe-downloads` is parsed and passed in `Request.downloads.probe`, and no code reads it. |
| The baseline compiler of `upgrade` (R-NI5, R-U3) and `probe` | Slices 038, 039 (`upgrade`) and the `probe` command. `roc use` (R-U3): slice 026. |
| `roc install`, `roc default`, `tool install`, `x`, Zig (R-DL7) | These commands name the download (R-NI6). They are other slices. |
| The `roc` proxy | Slice 023b. Only `auto_install` moves. |

## 9. Split (accepted in the review)

| Part | Content | State |
| --- | --- | --- |
| 025a | The required download of the first-probe compiler for `add`, `update`, `install`, `remove`, `verify` (R-DL1 to R-DL5, R-DL7, R-NI5, R-SO12, R-SO22, R-BL3, R-PH7, R-FL12, the FD gap), `Consent.auto_install`, and `data.downloads` | This slice |
| 025b | R-SO13 (rank 4 with a range) with the text fix of `NoneInRange`, Q3 (`--no-check` and rank 4), and the optional downloads (R-NI4, R-DL6, R-P5) as a part of the one prompt of R-DL1 | Added to `PLAN-P1.md` by the manager |

## 10. Decisions that the design does not state, with the rejected options

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The text of `download_stop` is the design example of CLI 3: `1 compiler download (73.9 MB) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.` The stop reads the list first (a request), so its text has the size. (Accepted.) | A stop before any request with the generic text of `Prompt.decide` (no size). |
| D2 | One function `required_want` decides all modes. `Install` and `Ask` read the list too. | A decision inside `Ladder` (not testable at L0). |
| D3 | `Compiler.find` is a new function. `require` is unchanged. (Accepted.) | A new return type of `require`. |
| D4 | `TALON_AUTO_INSTALL=no` and an interactive No have new texts that name the way to download (review, Q4, section 12). | The P0 text, and the text of `roc install`. |
| D6 | Rejected in the review: a separate optional prompt. The prompt of 025a takes `count` and `size`. | `Consent.optional` as a second prompt. |
| D7 | The old cases keep the refusal with `TALON_AUTO_INSTALL=no` (section 6). (Accepted.) | A fixture with a list and a person in each old case. |
| D8 | `Consent.auto_install` replaces `Proxy.auto_install`. | A copy in each module. |
| D9 | `tests/run.sh`: a case with tag `tty` and `given/http/` gets the fake server. (Accepted.) | A fake server started inside the `cmd`. |

## 11. Questions and answers

| # | Question | Answer (manager, 2026-10-23) |
| --- | --- | --- |
| Q1 | `TALON_AUTO_INSTALL=no` with `--allow-downloads` or `--yes` | A flag on the command line wins over the variable. L0 rows and L2 runs 14, 15 (section 5). |
| Q2, Q8 | One prompt or two for required and optional downloads. Land `Consent.optional` now? | One prompt (R-DL1). `Consent.optional` removed. The prompt shape has `count` and `size`. |
| Q3 | `--no-check` and a rank 4 download | Part 025b. |
| Q4 | Should the No texts name the way to download? | Yes. `download_refused` and `command_declined` (section 12). |
| Q5 | `Nothing was written.` after a download | Wrong after a download. `No project file was written.` in `verify` always (section 12). |
| Q6 | The first installed compiler becomes the default | Accepted (as `roc install`). L3 part 4 shows it. |
| Q7 | What `data.downloads` counts | The downloads that this command did: 1 after one, 0 with none. L3 part 7, L2 run 16, L0 `report`. |

## 12. Output proposals (TW24, for the review)

| Where | Proposal |
| --- | --- |
| The question | `<id> is not installed. Download <count> compiler(s), <size>? [y/N] ` (`compiler` for 1, `compilers` for more) |
| Answer line (stderr, R-NM6) | `downloading <id> (<size>)`. With No: `no download of <id>`. With a count other than 1: `downloading <count> compilers (<size>)`, `no download of <count> compilers`. |
| The stop (exit 13, kind `consent`) | `1 compiler download (<size>) needs consent. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.` (`downloads` for 2 or more) |
| An interactive No (exit 13) | `<id> is not installed. Nothing was downloaded. Run: tln roc install <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` |
| `TALON_AUTO_INSTALL=no` (exit 13) | `the compiler <id> is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes.` |
| A tag that is not a nightly (exit 13) | The P0 text, as before: `the compiler <id> is not installed. Run: tln roc install <id>.` |
| `verify`, last line | `verified: the tuple passes. No project file was written.` (with and with no download) |
| `--json`, `data.downloads` | The number of compilers that the command downloaded (1 after one download, 0 with none) |

## 13. Red output (the stub tree)

`scripts/test.sh` on the stub tree. check and fmt pass. The failures are the new tests, and the old tests whose expected text changed (the code agent changes the texts).

| Step | Result | Seconds | Budget | Failures |
| --- | --- | --- | --- | --- |
| check | pass | 3.5 | 10 | |
| fmt | pass | 0.1 | 5 | |
| l0 | FAIL | 6.4 | 10 | `consent.roc` (the new functions crash with `todo`), `compiler.roc` (`find`), `opts.roc` and `removal.roc` (the flags are `Err(NoFlag)`), `report.roc` (`downloads` is 0) |
| l2 | FAIL | 5.5 | 30 | 11 of 52: the 2 new cases, and 9 old cases (new refusal text, new verify line). 41 pass. |
| l3 | FAIL | 9.4 | 60 | 4 of 43: the 2 new cases, `verify/vf1-verify`, `compilers/pb1-probes-by-path` (new texts). 39 pass. |
| selftest | pass | 3.7 | 20 | |

With the reference all steps passed (check 3.2 s, fmt 0.1 s, l0 6.5 s, l2 5.0 s, l3 9.3 s, selftest 5.4 s). The failing old cases differ from their expected files only in the lines of Q4 and Q5.

## 14. Revert check

`research/slice-025-revert/mutate.py` made one change in the reference, ran `roc check`, then only the tests that should catch it (`mutate.out`: all tests, `mutate-l2.out`: L2 and L3 only, to show that the deep cases catch the change without the unit tests). 37 changes, all caught. The L2 and L3 tests alone catch 34. The 3 that only L0 catches are pure rows that no command shows: the plural stop of 2 downloads (C12), the answer line of 2 downloads (C15) and the read of `--probe-downloads` (O2: no reader in 025a). The mutations for the review answers are C14 (the variable wins over a flag), C16 (the interactive No does not name the flag), L7 (the refusal of `no` has the P0 text), L8, R1, R2, R3 (the count of downloads is lost in `start!`, `Report.data`, install or verify), T1 (the old verify line).

| Group | Changes | Caught by |
| --- | --- | --- |
| `Consent.required_want`, `command_download`, `download_stop`, `auto_install` (C1 to C12, C14 to C16) | The rows of the decision table, the default, the texts, the flag over the variable | L0 `consent`, and L2 `consent/` (C12 and C15: L0 only) |
| `Compiler.find` (K1, K2) | The `roc` on `PATH` counts for any id, the other tag form | L0 `compiler`, L2 `probe/`, `ladder/` |
| `Opts`, `Removal` (O1, O2, O3) | A flag is not read | L0 `opts`, `removal`, and L2 `consent/` (O2: L0 only) |
| `Ladder` (L1 to L5, L7, L8) | The new compiler is not in the list, the stop has no size, the answer No downloads, no prompt for a person, a refused compiler is downloaded, the `no` text, the count | L2 `consent/`, L3 `dl1-resolve-consent` |
| `ResolveBase`, `Verify`, `Update`, `Proxy` (B1 to B3, V1, U1, P1) | The mode, `--yes`, `--offline` are not passed, `verify` and `update` ignore a flag or the variable, the proxy ignores the variable | L2 `consent/`, `proxy/`, L3 `dl1-resolve-consent` |
| `Report`, `InstallFlow`, `VerifyFlow`, `Verify` (R1 to R3, T1) | `data.downloads` is lost, the old verify line | L0 `report`, L2 `consent/`, `verify/`, L3 `dl1-resolve-consent` |

The FD gap has no mutation: the pin write is existing code (`InstallFlow.finish!`), and L2 run 11 fails on the stub tree because the download is refused. The `tty` L3 case `dl2-consent-tty` is the only test that sees the real prompt text with the size, and it has no mutation of its own.

## 15. Review (manager, 2026-10-23)

| Item | Decision | Done |
| --- | --- | --- |
| Split | Accepted: this slice is 025a. The manager adds 025b to `PLAN-P1.md` (R-SO13 and its text fix, Q3, the optional download with its one prompt). | Section 9 |
| D1, D3, D4/D5 (with the Q4 change), D7, D9, the old-test changes, the import-cycle note | Accepted | Sections 6, 7, 10 |
| Q1 | A flag on the command line (`--allow-downloads`, `--yes`) wins over `TALON_AUTO_INSTALL=no` (flag over environment). Add the L0 rows. | `required_want` row 2, 6 L0 rows, L2 runs 14, 15 |
| Q2, Q8 | One prompt per command (R-DL1), so D6 is rejected. `Consent.optional` is removed with its rows and its stub. It comes with its first producer (025b or 031), as a part of the one prompt. The prompt of 025a can show a count and a total. | `command_download` takes `{ id, count, size }`. Rows for a count of 2. |
| Q3 | Part 025b | Section 9 |
| Q4 | R-DL8 and R-DL4: the error names `TALON_AUTO_INSTALL=yes`, `--allow-downloads` and `tln roc install <id>`. Change the `no` text and the interactive No text. | `download_refused`, `command_declined` (section 12). L2 runs 3, 7, the old cases and L3. |
| Q5 | `Nothing was written.` is wrong after a download. Use a text that says no project file was written, in `verify` always. | `No project file was written.` in 15 L2 and 22 L3 lines (section 6) |
| Q6 | Accepted: the first compiler that Talon installs is the default (as `roc install`) | L3 part 4 |
| Q7 | `data.downloads` is the count of downloads that the command did. Show it in L3 part 7. | L3 part 7 (1), L2 run 16, L0 `report` (1 and 0) |
| Reference | Update it so all tests pass, run the mutations for the new rows, record them. Then delete `research/slice-025-revert/reference/` completely. | Section 14. The reference is deleted. `mutate.py` needs a green tree to run again. |

## 16. Code result (code agent)

`scripts/test.sh` exits 0: check 3.8 s, fmt 0.1 s, l0 6.5 s, l2 7.5 s, l3 9.2 s, selftest 4.0 s. `OPT=speed scripts/test.sh` exits 0 too (l2 74 s: the LLVM build of the test app). `MISSING=1 scripts/rules.sh` lists no id of section 1.

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Start.roc` (new) | 81 | `Start.run!`: the start of a ladder run (steps 0a to 0f of section 2), `Start.Downloads`, `Start.Started`. `Ladder.Downloads` is an alias. |
| `cli/lib/Common.roc` (new) | 37 | `shown_fx`, `failed!`, `nightly_of`, moved from `Install` (the import cycle of section 7). All callers use `Common.*`. |
| `cli/lib/Consent.roc` | 275 | The 6 bodies (`command_download`, `required_want`, `download_stop`, `download_refused`, `command_declined`, `auto_install`) |
| `cli/lib/Compiler.roc` | 243 | `find`. `require` is `find` with the refusal text (no copy of the rows) |
| `cli/lib/Ladder.roc` | 507 | `start!` and `Started` moved to `Start`. `downloads` in `Request` and `VerifyRequest`. `run!` and `verify!` give `{ notes, downloads }` |
| `cli/lib/ResolveBase.roc` | 541 | `ladder_downloads` |
| `cli/lib/InstallFlow.roc`, `RemoveFlow.roc`, `VerifyFlow.roc` | 519, 325, 134 | Pass `ResolveBase.ladder_downloads(request)`. Copy `done.downloads` to `Ran` |
| `cli/lib/Install.roc`, `Update.roc`, `Remove.roc`, `Verify.roc` | 244, 177, 97, 110 | `downloads` from `Consent.auto_install(env)` and the flags. `Verify` prints `No project file was written.` |
| `cli/lib/Opts.roc`, `Removal.roc`, `Report.roc` | 101, 102, 190 | The 2 flags are read. `Report.data` writes `downloads` |
| `cli/lib/Proxy.roc` | 465 | `Proxy.auto_install` removed. `Consent.auto_install` in its place |
| `cli/lib/RocInstall.roc`, `Ls.roc`, `Why.roc`, `Link`-users (`RocManage`, `RocLink`) | | `Common.*` in place of `Install.*`. `Ls` keeps the neutral `downloads` (it never probes) |
| `cli/lib/main.roc` | 95 | Exposes `Common`, `Start` |

Decisions of the code agent that the slice does not fix:

| # | Decision | Rejected |
| --- | --- | --- |
| K1 | The import cycle is solved with 2 modules: `Common` (the 3 helpers that `RocInstall` needs) and `Start` (the new start code, so `Ladder` stays under 600 lines: 507). | A copy of the helpers in `RocInstall`. A thin `Install.failed!` that calls `Common`. |
| K2 | `Start.run!` uses `offer.id` (the id of the list) for the prompt and for `command_declined`, and `run.held` for `download_refused`, as the proxy does. | The held text in all texts. |
| K3 | `Compiler.require` calls `Compiler.find`. A `Refuse` of `required_want` returns the failure of `require` (no second text function). | A public `Compiler.missing` text function. |
| K4 | The mode of the run is `request.prompt.mode`. `Start` asks the terminal once (`NeedTty`) and uses the new mode for the prompt. | A second `tty!` call inside `Prompt.ask!` (it does not happen: the mode is not `NeedsTty` any more). |

Disputes (from the code agent): none. No test, fixture or expected file was changed. Questions (TW17): none. No compiler bug found.

## 17. Verify results (revert check, TW12)

50 mutations, `research/slice-025-revert/code-mutate.py`. Results and reasons: `research/slice-025-revert/code-results.md`. Caught 46 of 50. `diff -r research/slice-025-revert/code-final/cli cli` shows no difference.

| Group | Mutations | Result |
| --- | --- | --- |
| `Consent` (C01 to C18) | rows of `required_want`, the texts, the default, `auto_install` | 17 of 17 caught by L0 `consent` |
| `Compiler.find`, `Opts`, `Removal` (K01, K02, O01 to O03) | the two rows, the flags | 5 of 5 caught (L0) |
| `Start` (S01 to S12) | the list, the stop size, the answer No, the prompt for a person, the refusal texts, the count, `--offline`, the terminal call | 11 of 12 caught by L2 `consent/`. S01 not caught (test gap) |
| `ResolveBase.ladder_downloads` (B01 to B05) | the 5 facts | 5 of 5 caught (L2) |
| Reports and commands (R01 to R04, T01, V01, V02, U01, U02, I01, I02, D01, D02, P01) | `data.downloads`, the verify line, the flag and the variable in each command | 13 of 16 caught. R04 equivalent. I02 test gap |
| `Common` (N01) | `TALON_NIGHTLY=true` | not caught (old test gap, moved function) |

Not caught: S01 (test gap, no case where the compiler comes between two lists), R04 (equivalent: `remove` has no `downloads` in its `data`), I02 (test gap: no `add` or `install` run with `TALON_AUTO_INSTALL`), N01 (old test gap).

## 18. Gap rows (test agent)

Two test gaps of section 17 are closed. S01 (a dir that appears between two lists) is a race and stays untested. R04 is equivalent. The code files are unchanged: after each hand mutation the files were restored and compared with `research/slice-025-revert/code-final/` (`cmp`, no difference).

| Gap | New test | Mutation (by hand) | Result |
| --- | --- | --- | --- |
| I02 (no `add` or `install` run sets `TALON_AUTO_INSTALL`) | L2 `consent/dl1-resolve` run 17: `env:CI=true env:TALON_AUTO_INSTALL=yes add acme/json@^2.1 --file u18/main.roc`. The pin of u18 is a new tag `nightly-2026-10-07-3f4e5d6` that is added to the fake list (72.0 MB). No person: the answer line, one download, the probes. | `Install.roc`: `auto: Consent.auto_install(env)` becomes `auto: Ask` | `tests/commands/run.sh consent/` fails (run 17 stops with exit 13) |
| N01 (no test sets `TALON_NIGHTLY=true`) | L0 `tests/unit/common.roc` (new, 1 `expect`, 9 rows): `0`, `false`, `1`, `true`, `TRUE`, `yes`, the empty text, no variable, no environment | `Common.roc`: the `"true"` case of `nightly_of` is removed | `roc test tests/unit/common.roc` fails (row `true`) |

`scripts/test.sh` exits 0 with no WARN (check 3.6 s, fmt 0.1 s, l0 6.5 s, l2 7.8 s, l3 9.3 s, selftest 4.4 s).

## Close (manager, 2026-10-23)

Part 025a is done. The code agent decisions are accepted (`Common` and `Start` break the import cycle with no copies). I02 and N01 are caught by the gap rows. S01 is a race and stays untested; R04 is equivalent. `scripts/test.sh` exits 0 with no WARN. Part 025b is its own row in PLAN-P1.md. Status: done.
