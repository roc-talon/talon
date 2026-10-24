# 022 Selection ranks

Phase: P1. Status: done

Slice 022 makes the compiler selection of Resolution 13 for the `tln` commands: ranks 1, 2, 4, 5, 6, 7 over the installed compilers, `.roc-version` (rank 5), `default-roc` (rank 6), the held nightly of ranks 4 to 6, the R-SO18 warning in `install` and `ls`. Extra items: G1 of slice 020 (`Pin.admits` and `Pin.order` use `published_at`, R-NS1), Q5 of slice 020 (the empty-domain failure names the switch, R-NS2), T17 of slice 021 (`size_text`), and the harness (the `check` step runs in parallel). The manager accepted the split (see the review at the end): 022b (R-SO9, the launcher test) is not in this slice. Follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-022-revert/before/` (with `NEW.txt`).

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-SO1, R-SO2 (ranks 1, 2) | `Compiler.select` | L0 `select` |
| R-SO3 (rank 3, the header pin) | `Pin.decide` (slice 013), `compiler_from` only for no pin | L0 `decide` |
| R-SO4, R-NS7 (rank 4, newest installed in `[toolchain] roc`) | `Compiler.select`, `Pin.order` | L0 `select`, `order`. L2 `so1-ranks` r4, r4s |
| R-SO5, R-PD6 (rank 5, `.roc-version`, only with no `talon.toml`) | `Compiler.select`, `Project.roc_version` | L0 `select`, `roc_version`. L2 r5, r5t. L3 `so2-ranks` |
| R-SO6, R-TF4 (rank 6, `default-roc`) | `Intent.read_config`, `Compiler.select` | L0 `default-roc`, `select`. L2 r6. L3 |
| R-SO7, R-SO10 (rank 7, the PATH id counts as installed) | `Compiler.select` | L0 `select` |
| R-SO12 (a missing id) | `select` gives `Missing` | L0 `select` |
| R-SO13 (rank 4, none in range: refusal, exit 13, no fall through) | `Compiler.failure` | L0 `select`, `failure`. L2 r4n. L3 |
| R-SO14 (no rank: exit 18) | `Compiler.failure` | L0 `failure`. L2 `rs-no-compiler` |
| R-SO18 (`.roc-version` and the pin disagree) | `Compiler.roc_version_note`, `ResolveBase.roc_version_warnings` | L0 `roc_version_note`. L2 r18, r18b. L3 |
| R-SO19, R-EV5, R-PH6 (the held nightly of ranks 2, 4 to 7 and the gate) | `Pin.decide`, `Pin.gate` | L0 `gate`, `decide`. L2 r5, r6. L3 |
| R-NS1 (order of nightlies and releases) | `Pin.order`, `Pin.admits` | L0 `order`, `admits`. L2 r4 |
| R-NS2 (the switch off: the failure names the switch and its source) | `Toolchain.pick_failed`, `Pin.switch` | L0 `pick_failed`, `switch`. L3 |
| R-NS3, R-NS4, R-NS8 to R-NS11 (where the switch applies, its sources) | `Pin.switch`, `Toolchain.domain`, `select` | L0. L3 |
| R-NS6 (`git-`, `link-`, `copy-`: by name only, never checked) | `select`, `Pin.gate`, `Compiler.installed` | L0. L2 r8 |
| R-SC12, R-EC19 (a prefix is an error) | `Compiler.version_file`, `default-roc` | L0. L3 |
| R-CV1 (2 tag forms of one nightly) | `Pin.same_id` | L0 `same_id` |
| R-LY1, Q5 (`published_at` in `.talon.json`) | `Toolchain.meta`, `Compiler.times` | L0 `meta`, `times`. L2 `ri1-flow`. L3 `ri1`, `ri2` |
| T17 of slice 021 | `Toolchain.size_text` | L0 `size_text` |

Out of scope: R-SO1 from `roc +<id>` and R-SO8 (slice 023), R-SO9 (022b), R-SO12 and R-SO13 as a download (slice 025), R-SO15 (slice 021), R-SO20 to R-SO22 (slice 013), the probes on an installed compiler that is not on PATH (slice 023, manager answer Q2), the relative step base (slice 026, Q7). `MISSING=1 scripts/rules.sh R-SO R-NS R-EV R-PH` lists only R-SO8 and R-NS12 (both out of scope).

## 2. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Compiler.roc` | 161 (+87) | Stubs | New `Rank`, `Facts`, `select`, `installed`, `times`, `version_file`, `roc_version_note`, `failure`: `crash "todo"` |
| `cli/lib/Pin.roc` | 333 (+38) | Stubs | New `order`, `same_id`, `switch`: `crash "todo"`. `admits`, `gate`, `decide` have the new types and keep today's behavior. |
| `cli/lib/Intent.roc`, `Project.roc` | 493 (+1), 337 (+2) | Stubs | `Config.default_roc` is `Err(Unset)`. `Project.roc_version` is `Err(None)`. |
| `cli/lib/ResolveBase.roc` | 464 (+26) | Stubs | `Loaded.version_file`, `Loaded.selected`. New `select!`, `roc_version_warnings`: the stubs return the input and `[]`. |
| `cli/lib/InstallFlow.roc`, `RemoveFlow.roc`, `Ls.roc` | +7, +1, +6 | Stubs | Ripple edits and the `warning:` print for `roc_version_warnings` |
| `cli/lib/Toolchain.roc`, `RocInstall.roc` | 357 (+8), 317 (+0) | Stubs | New input fields `nightly`, `switch`, `published_at` (ignored by the stubs) |
| `tests/unit/pin.roc`, `compiler.roc`, `project.roc`, `intent.roc`, `toolchain.roc` | 274, 229, 340, 319, 336 | Test agent | 8 new `expect`s, rows added to old ones |
| `tests/commands/cases/roc/so1-ranks/` | 1 case | Test agent | L2, 9 runs |
| `tests/scenarios/compilers/so2-ranks/` | 1 case | Test agent | L3, 9 runs |
| `tests/selftest.sh` | 372 (+20) | Test agent | Fake `roc check`, 1 new row |
| `research/slice-022-revert/before/` | | Test agent | 36 copies, `NEW.txt` |

`scripts/test.sh` is not changed by the test agent. The code agent makes `step_check` parallel (see N1).

## 3. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Compiler.Rank` | `[Argument, Env, Range, VersionFile, Default, Path]` (rank 3 is `Pin.decide`) | R-SO1 to R-SO7 |
| `Compiler.Facts` | `{ argument, env : Try(Str, [Unset]), req : Try(Pin.Req, [Unset]), nightly, has_toml : Bool, version_file : Try(Str, [None]), default : Try(Str, [Unset]), path : Try(Str, [NoCompiler]), installed : List(Str), times : List({ id, published_at : U64 }) }` | R-SO1 to R-SO7 |
| `Compiler.select` | `Facts -> Try({ id, rank, state : [Installed, Missing] }, [NoCompiler, NoneInRange])` | R-SO1 to R-SO7, R-SO10, R-SO12 to R-SO14 |
| `Compiler.installed` | `List({ name, is_dir, mtime }) -> List(Str)`: sorted ids of compiler dirs | R-LY1, R-NS6 |
| `Compiler.times` | `List({ id, text : Try(Str, [NotFound, Denied, Other(Str)]) }) -> List({ id, published_at })`: a row with no usable `published_at` is dropped | R-NS1 |
| `Compiler.version_file` | `{ path, text } -> Try(Try(Str, [Empty]), Fail)` | R-SO5, R-SC12 |
| `Compiler.roc_version_note` | `{ pin : Try(Str, [NoPin]), version_file : Try(Str, [None]) } -> Try(Str, [None])` | R-SO18 |
| `Compiler.failure` | `[NoCompiler, NoneInRange(Str)] -> Fail` | R-SO13, R-SO14 |
| `Pin.order` | `{ a, b, times } -> [Before, Same, After]` | R-NS1 |
| `Pin.same_id` | `Str, Str -> Bool` | R-CV1 |
| `Pin.switch` | `{ env, toml, config : Try(Bool, [Unset]) } -> { nightly : Bool, source : Source }` | R-NS8 to R-NS11 |
| `Pin.admits` | input gets `times : List({ id, published_at })` | R-NS1, R-NS7 |
| `Pin.decide`, `Pin.gate` | `compiler_from : [Range, VersionFile, Default, Path]`. `held_from` has the same tags (the gate has no `Pin`). | R-SO19 |
| `Intent.Config.default_roc` | `Try(Str, [Unset])` | R-SO6 |
| `Project.roc_version` | `Try(Str, [None])`: the path of the nearest `.roc-version` | R-SO5 |
| `ResolveBase.Loaded` | new `version_file`, `selected : { id : Try(Str, [NoCompiler]), from : [Range, VersionFile, Default, Path] }` | R-SO19 |
| `Toolchain.domain`, `pick_failed`, `meta` | new fields `nightly`, `switch : { nightly, source }`, `published_at : U64` | R-NS3, R-NS2, Q5 |

`Request` has no new field (decision D1).

## 4. Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/pin.roc`: `order`, `admits`, `same_id` | The real pair of 2026-07-23 (fdd77c3 06:04 and 306abd6 11:30) ordered by `published_at`, releases, the other tag form | R-NS1, R-NS7, R-CV1 |
| L0 | same: `switch` (6 rows), `decide` with `compiler_from` (6 rows), `gate` rows | Sources of the switch. The rank that holds. Gate texts name the rank. `Range` is always `Ok`. A local build is not checked. | R-NS8 to R-NS11, R-SO19, R-NS6 |
| L0 | `tests/unit/compiler.roc`: `select` (29 rows) | Each rank alone, precedence, rank 4 newest by time, semver range, switch off, `has_toml`, `git-` never by rank 4, PATH id installed, `Missing`, `NoneInRange` does not fall through, `NoCompiler` | R-SO1 to R-SO7, R-SO10 to R-SO14, R-NS3, R-NS6 |
| L0 | same: facts (`installed`, `times`, `version_file`, `roc_version_note`), `failure` | Dirs that count, `times` round trip with `Toolchain.meta`, trim, prefix, empty, notes, kinds and texts | R-LY1, R-SC12, R-SO18, R-SO13, R-SO14, R-EC13, R-EC18 |
| L0 | `tests/unit/project.roc`: `roc_version` (7 rows) | The walk starts at the dir of the project file (G4) | R-SO5, R-PD2 |
| L0 | `tests/unit/intent.roc`: `default-roc` (11 rows) | Full ids, `git-`, `link-`, `copy-` with a name. A prefix, `debug-`, a number, empty, `git-` with no name: exit 19 | R-SO6, R-TF4, R-SC12 |
| L0 | `tests/unit/toolchain.roc` | `domain` with the switch, `pick_failed` names switch and source, `meta` has `published_at`, `size_text` 1549, 1550, 1951 | R-NS2, R-NS3, R-LY1, T17 |
| L2 | `roc/so1-ranks` (new, 9 runs) | r4 `*` picks the newest by `published_at`. r4s `0.1.*`. r4n none in range, exit 13. r5, r5t, r6 by gate (exit 10, the text names the rank). r8 `git-` build, no gate. r18, r18b warning or none. The `calls.log` fixes the listing and the `.talon.json` reads. | R-SO4 to R-SO6, R-SO13, R-SO18, R-NS1, R-NS6, R-NS7 |
| L3 | `compilers/so2-ranks` (new, 9 runs) | `ls` with the warning, `.roc-version` and the default by exit 10, the default loses to `.roc-version`, a range with none installed (13), a prefix in `.roc-version` (19), a bad `default-roc` (19), `roc install @latest` with the switch off by `TALON_NIGHTLY=0` and by `nightly = false` (10) | R-SO5, R-SO6, R-SO13, R-SO18, R-NS2, R-NS4, R-TF4, R-SC12 |
| selftest | row `check in parallel` | 57 `roc check` calls, also after a failure, `== check: FAIL`, each failure with its text and `^^^ roc check <file> (exit 1)`, 2 to 4 at one time | harness |

Budget: 8 new L0 `expect`s (pin 3, compiler 3, project 1, intent 1), 2 deep cases, 1 selftest row.

## 5. Old tests that changed

| File | Change | Why |
| --- | --- | --- |
| `tests/commands/cases/resolve/rs-no-compiler/expect/calls.log` | +1 line `list_dirs $HOME/.cache/roc/toolchains` | The range run lists the compilers |
| same, `expect/stderr` | R-SO14 text. The range run: the R-SO13 refusal text | G2 |
| `tests/commands/cases/roc/ri1-flow/expect/tree.diff` | 5 `.talon.json` lines get `,"published_at":"..."`: 2026-10-09T15:00:00Z, 10-11T15, 10-14T15, 10-15T15, 10-16T15 | Q5 |
| `tests/scenarios/compilers/ri1-install-flow/expect/tree.diff` | 5 lines: 2026-10-09T15:00:00Z, 10-12T15, 10-14T15, 10-21T18, 2026-07-31T11:56:54Z | Q5 |
| `tests/scenarios/compilers/ri2-refusals/expect/tree.diff` | 1 line: 2026-10-21T18:00:00Z | Q5 |
| `tests/unit/pin.roc` | `admits` gets `times: []`, `decide` gets `compiler_from: Path` | Types |
| `tests/unit/toolchain.roc` | `domain` gets `nightly`, `pick_failed` gets `switch`, `meta` gets `published_at` | Types |
| `tests/unit/compiler.roc` | 2 names `a1..a5`, `g1` added. `n1`, `n2` kept. | New rows |

## 6. Output proposals (TW24, for the review)

| Where | Proposal |
| --- | --- |
| R-SO18 | stderr: `warning: .roc-version names <a>, the header names <b>`. The claim of the scope text that `data.notes` has it with `--json` is not tested (question Q9). |
| R-SO14 | `no compiler is selected. Run: tln roc install @latest, then tln roc default <id>`. Kind `environment`, exit 18. |
| R-SO13 (G2) | `no installed compiler is in [toolchain] roc (<range>). This version of tln does not download a compiler for a run.` Kind `consent`, exit 13. Also with `--no-check` (D5). |
| Gate, rank 2, 5, 6 | `the compiler <id> from <ROC_TOOLCHAIN or .roc-version or the global default> is a nightly, and nightly is false (set by <source>). <fix>`. Kind `no_tuple`, exit 10. Outside the range: `... is outside [toolchain] roc (<range>). <fix>`. |
| Gate, rank 7 | The text names `the roc on PATH`. The switch: exit 10. The range: exit 13 (as in slice 012). |
| Prefix in `.roc-version` | `<path>: .roc-version is not a full compiler id: <text>`. Exit 19. |
| Bad `default-roc` | `<config path>:<line>: default-roc: must be a full compiler id`. Exit 19. |
| Q5 text | `no compiler release is known, and nightly is false (set by <source>)`. Kind `no_tuple`, exit 10. |

## 7. Decisions that the design does not fix

| # | Decision | Rejected options |
| --- | --- | --- |
| D1 | `Request` has no new field. `ResolveBase.select!` runs inside `prepared!` and `RemoveFlow`, and calls `Fx` only when a rank needs it (listing of `toolchains/` for rank 4, 5 or 6, the `.talon.json` reads for rank 4). | New `Request` fields `installed`, `version_file` (the scope plan): the L2 app and every caller would read files that most runs do not need. |
| D2 | The `.roc-version` text is read in the same `read_files!` call as the headers and the tomls. The config index is `files.len() + toml_paths.len()`. | A second `read_files!` call. |
| D3 | `published_at` in `.talon.json` is a UTC string (`Clock.format_utc`), the last key. `Pin.admits` and `Pin.order` match rows by `Pin.same_id`. | A number of seconds. Match by text. |
| D4 | Rank 4 reads the `.talon.json` of all installed ids in one `read_files!`, in sorted order. A missing field or file drops the row, and the order falls back to the tag text. | One read for each id. Fail on a missing field. |
| D5 | `NoneInRange` is exit 13 also with `--no-check`. | Skip with `--no-check`: the pin gate needs a compiler. |
| D6 | `default-roc` takes a nightly (either tag form), a release, `git-`, `link-`, `copy-` with a non-empty name. Not `debug-<sha>`, a prefix, a number, empty. | Any text. Only nightly and release. |
| D7 | The gate for `Range` is always `Ok` (rank 4 chooses inside the range). For ranks 2, 5, 6 exit 10. Rank 7 keeps exit 13 for the range. A local build is never checked. | The gate checks `Range` again. |
| D8 | The success paths of the deep cases show the selected id only when it is the fake PATH roc, because a probe on another installed compiler is refused (exit 13) until slice 023 (manager answer Q2). Ranks 5 and 6 are shown by the exit 10 gate with `nightly=false`. | Add a probe path for installed compilers to 022 (Q2). |

## 8. Revert check (TW12)

A private reference made all new tests pass, and was deleted (it is not in `research/`). 52 small mutations of it were run one by one, each with only the tests that should catch it. 52 of 52 were caught. One mutation was first not caught (`default-roc = "git-"` accepted): the row `git with no name` was added, and it is now caught.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `Pin`: order by time (2), kind (1), `same_id`, `admits` ignores time, switch source and priority (2), gate `Range`, gate text, `git-` checked, `held_from` | 11 | L0 `pin`, `compiler` |
| `Compiler`: rank order (3), fall through, `git-` by rank 4, switch off, PATH candidate, order (2), PATH installed, `times` key, `installed` (3), `version_file` (2), note, failure kinds (2) | 19 | L0 `compiler` |
| `ResolveBase`: `has_toml`, no `.talon.json` read, no listing for rank 5 and 6, range text, no warning, named toolchain, locked pin | 7 | L2 `so1-ranks`, `rs-no-compiler`, `ri1-flow` |
| `Intent`: `git-` refused, empty name, any text | 3 | L0 `intent` |
| `Project`: walk start, walk stop | 2 | L0 `project` |
| `Toolchain`, `RocInstall`: no `published_at`, `size_text`, switch text (3), switch ignored, `published_at` of the release | 7 | L0 `toolchain`, L2 `ri1-flow`, L3 `so2-ranks`, `ri1` |
| `scripts/test.sh`: serial `check`, no failure, no `^^^` line | 3 | selftest |

Not checked by a mutation: the order of the failure report of `check` (the selftest row sorts the `^^^` lines).

## 9. State on the stub tree (red)

`scripts/test.sh`: check pass (all files compile), fmt pass. l0: `compiler`, `intent`, `pin`, `project`, `toolchain` fail (todo crashes and wrong values), the other files pass. l2: 35 passed, 3 failed (`rs-no-compiler`, `ri1-flow`, `so1-ranks`). l3: 29 passed, 3 failed (`ri1-install-flow`, `ri2-refusals`, `so2-ranks`). selftest: 41 passed, 1 failed (`check in parallel`, max seen: 1). With the reference all steps passed.

## 10. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | `scripts/test.sh` `step_check` must run `roc check` in parallel (`xargs -P`, `parallel_jobs`), with per-file logs, and print the report in the order of `APPS` with `^^^ roc check <file> (exit <n>)`. Read the selftest row. |
| N2 | `calls.log` of `so1-ranks` fixes the `Fx` calls: one `list_dirs` of `toolchains/` only when rank 4, 5 or 6 can choose, and one `read_files` of the `.talon.json` of every installed id (sorted) only when a range is set. |
| N3 | The `Fx.probes!` of a compiler that is not on PATH stays refused (exit 13) until slice 023. |
| N4 | `roc install` writes `published_at` of the picked release in `.talon.json` (the last key), and reads the switch with `Pin.switch` (the environment, then `config.toml`). |
| N5 | `data.notes` for the R-SO18 warning is not tested. |

## 11. The 022b note

R-SO9: the launcher test (the first `roc` on PATH that is not the Talon launcher), `path-roc.json` (R-TF1, R-TF3), a new `Fx` call for the `roc` files on PATH (path, size, mtime) and the running `tln`, the pure `PathRoc`, the real `Fx` body and the fake. About 140 lines, one L3 case. It stays before slice 023. Not started.

## 12. Questions (TW17) and design gaps

| # | Text |
| --- | --- |
| Q9 | R-SO18 says the warning goes to `install` and `ls`. Does it go to `data.notes` with `--json`? The tests check stderr only. Default: stderr only. |
| G6 | R-SO19 has no text for the gate of rank 7 with a range failure. The slice keeps exit 13 (P0 text of slice 012). |
| G7 | R-LY1 does not say that a `.talon.json` without `published_at` (an install before this slice) is valid. The tests treat it as valid: the order falls back to the tag text. |

## Review of the scope (manager, 2026-10-22)

The split is accepted: 022 (this file, about 310 lines) and 022b (R-SO9: the launcher test, `path-roc.json`, the new `Fx` call, about 140 lines). Order: 022, 022b, 023. The decisions are accepted.

| # | Answer |
| --- | --- |
| Q1 | Yes |
| Q2 | Slice 023 (the proxy runs a selected compiler; the probes use the same path). |
| Q3 | Yes (R-SO5, R-PD6). |
| Q4 | The default. |
| Q5 | The cleaner option: `.talon.json` gets `published_at`, so rank 4 has a full order offline (R-NS1). The test agent changes the slice 021 expected files that show `.talon.json`, and records each one. G5 is closed by this answer. |
| Q6 | The default (exit 19; an empty file is no file). |
| Q7 | Slice 026. |
| Q8 | Accepted. |
| G2 | The proposed refusal text (exit 13) until slice 025. |
| G4 | The `.roc-version` walk starts at the dir of the project file (so `--file` and the walk agree). |

## Review of the tests (manager, 2026-10-22)

D1 to D8, the output proposals (TW24) and the changed old expected files are accepted. Q9: the default (the R-SO18 warning is on stderr only, as the other warnings; `data.notes` holds notes). G6: exit 13 stays. G7: a `.talon.json` with no `published_at` is valid, and the order falls back to the tag text. Status: code.

## Disputes (from the code agent)

None. No test, fixture or expected file was changed by the code agent.

## Code result (code agent, 2026-10-22)

`scripts/test.sh` exits 0 (fast set, OPT=dev): check 6.2 s, fmt 0.1 s, l0 4.0 s (all files pass), l2 38 passed 0.5 s, l3 32 passed and 1 skipped 9.2 s, selftest 42 passed 19.3 s. `OPT=speed scripts/test.sh` also exits 0.

| Item | Where | Decision |
| --- | --- | --- |
| N1 | `scripts/test.sh` `step_check` | `xargs -P` with `parallel_jobs`, a log and an rc file for each file in `$LOGS/check`, report in the order of `APPS`, `^^^ roc check <file> (exit <n>)` after the log of a failure |
| Rank 4 candidates | `Compiler.in_range` | The ids of `installed` and the PATH id (once) that `Pin.is_id`, `Pin.admits` (with `times`) and the switch accept. The newest by a fold of `Pin.order`. A tie keeps the first. |
| `AtLeast` | `Pin.at_least` | A bound admits only an id of its own kind (nightly with nightly, release with release), as the tests of slice 022 and the Q9 text of P0 say. Then `Pin.order` decides. |
| `Pin.order` | `Pin.order_of` | Day, kind, time, text. The text of 2 nightlies of one day is the sha (the date is equal, so the same order as the tag text in one tag form, and total across the 2 forms). |
| `select!` calls | `ResolveBase.choose!` | `list_dirs!` only when `req` is set, or `.roc-version` is set with no `talon.toml`, or `default-roc` is set (N2). The `.talon.json` read only for `req` and a non-empty listing. |
| `.roc-version` read | `ResolveBase.load!` | The path is the last entry of the one `read_files!` call (after the config). A missing file is `Err(None)`. A prefix is exit 19 (`Compiler.version_file`). |
| Rank to `from` | `ResolveBase.rank_from` | Rank 1 and 2 cannot come from `select` in a `tln` command, so they map to `Path` (never used). |
| `Project.roc_version` | `Project.nearest_version` | The walk starts at the dir of the project file (G4), or at the first dir with no current member, and checks the stop dir. |
| `default-roc` | `Intent.is_default_id` | D6: `Pin.is_id`, or `git-`, `link-`, `copy-` with a non-empty name. |
| `RocInstall` | `read_config!`, `published_of` | One config read gives `min-release-age` and `nightly`. The switch is `Pin.switch` (the `TALON_NIGHTLY` value, then `config.toml`). `.talon.json` gets the `published_at` of the picked release. |
| `Pin.gate` | `Pin.gate`, `rank_words` | `Range` and each non-id (git, link, copy, local build) are `Ok`. `Path` keeps the texts and exit codes of slice 012. The other ranks: exit 10, text from `rank_words`. |

Files: `cli/lib/Compiler.roc` 233, `Pin.roc` 429, `ResolveBase.roc` 526, `Toolchain.roc` 359, `RocInstall.roc` 327, `Intent.roc` 505, `Project.roc` 354, `scripts/test.sh` 132 lines.

## Verify results (code agent, TW12)

50 small mutations (`research/slice-022-revert/code-mutate.py`, results in `code-results.md`, a copy of the final code in `code-final/`). Caught 47 of 50. The files are the same as `code-final/` after the run (SAME).

| Not caught | Test gap |
| --- | --- |
| C10: `Compiler.installed` keeps a `<id>.<hex>.tmp` dir | No row with a `git-` or `link-` name that ends in `.tmp` or `.lock` (`Pin.is_id` hides the case for a nightly) |
| P6: `Pin.order`, arm `(Nightly, Release)` | The rows ask `order(release, nightly)` only |
| P12: `Pin.order`, 2 releases of one day | No row has 2 releases with a time on one day |

All the other mutations were caught by `l0:compiler`, `l0:pin`, `l0:intent`, `l0:project`, `l0:toolchain`, L2 `roc/so1-ranks`, `resolve/rs-no-compiler`, `roc/ri1-flow`, L3 `compilers/so2-ranks` and the selftest row `check in parallel`.

## Gap rows (test agent)

The code revert check (`research/slice-022-revert/code-results.md`) did not catch 3 mutations. The test agent added the smallest L0 rows. Each row was checked: the mutation was applied by hand to the code, the new row failed (the test file showed 1 failed), and the file was put back (`cmp` with `code-final/`: same). Only tests changed (TW18).

| Mutation | New row | Rules | Test file |
| --- | --- | --- | --- |
| P6: `(Nightly, Release) => Before` is `After` in `Pin.order` | `order(nightly, release)` of one day is `Before` (the other order of the old row) | R-NS1 | `tests/unit/pin.roc`, `order` |
| P12: `(Release, _) => by_version` is `Same` | 3 rows: 2 releases with times on one day, `0.1.0` and `0.2.0` in both orders, and `0.10.0` after `0.2.0` (the version, not the text) | R-NS1 | `tests/unit/pin.roc`, `order` |
| C10: `Compiler.installed` has no `.tmp` check | 3 dirs added: `link-dev.tmp`, `git-0123abcd.0123456789abcdef.tmp`, `copy-dev.lock`. A `git-` or `link-` name is a compiler by name, so only the suffix check drops them. | R-LY1, R-NS6 | `tests/unit/compiler.roc`, `installed` |
