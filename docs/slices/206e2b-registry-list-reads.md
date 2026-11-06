# 206e2b Registry list in every compiler read

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 206e2b of `PLAN-P2-CLI.md`. It repairs the defects D1 and D2 that the close of slice 206e2 found (`206e2-registry-compiler-list.md`, "Close" rows D1, D2, and "Code" note 2).

## Rules

R-CV1, R-IX4, R-IX6 (CLI 6.2, 7.3), Design Q467, Q489. As used: R-CV3, R-CV5, R-CV6, R-SO22, R-SO24, R-AP16, R-AD37, R-DI12, R-UP6, R-AP74.

## Scope

| In | Out |
| --- | --- |
| D1 (R-CV1, R-IX4): in a registry run, each compiler list read is `GET /v1/toolchains` (at most one for the command, the later reads use the kept rows), also when no pick read the list first: `PickLoop.releases!` (the domain D), the download offers (`RocInstall.offer!`, `NoRank.offer!`, `Start.Downloads`), the optional compilers (`PickOptional`). The GitHub list is not read in a registry run | `direct` (unchanged) |
| D2 (R-IX6): `--offline` with a registry: `HeldRoc`, `NightlyFlow`, `PickLoop` read the kept rows of `toolchains.json` (any age), no request, not the GitHub cache | The rule when no copy exists is Q489 (done in 206e2): bare `upgrade` keeps H with the note, a command that must choose fails with exit 15. No new case |

## Flow as read

| # | Run | Reading |
| --- | --- | --- |
| 1 | Registry, online, no earlier read (H installed or on PATH, or H pinned and not installed) | The first read of the list (here the domain D of the oracle loop) sends one `GET /v1/toolchains?after=<largest>`, writes `toolchains.json` when a row is new, and records the pins (source `registry`, R-CV6): `read_files` of the file, `http_get`, `write_atomic`, `db_query` and `db_write` of `pinned`. The command is then `listed`: each later read (the offer of the first probe, the optional compilers) reads the kept file: `read_files`, `list_dirs` of the registry dir, `db_query` of `pinned`, no request |
| 2 | Registry, `--offline`, a kept `toolchains.json` | Every read of the list is the kept file at any age. No request. The list is readable, so there is no note `the compiler list could not be read` and no exit 15 |
| 3 | Registry, `--offline`, no `toolchains.json` | As slice 206e2 (Q489). Not changed here |

## Tests

| Layer | Case | Rules |
| --- | --- | --- |
| L2 | `registry/sp24-held-move-drop` (changed, 1 run): the route `toolchains%3Fafter=0` is new (2 rows older than H, so D is [H] as before). `calls.log`: the GitHub read (`list_dirs` of the GitHub list dir, `programs gh`, `http_get api.github.com/...nightlies`) becomes the registry read (`read_files` of the file, `http_get .../v1/toolchains?after=0`, `write_atomic`, `db_query` and `db_write` of `pinned=2`). `tree.diff`: `toolchains.json` and 2 `pinned` rows with source `registry`. stdout, stderr, exit: unchanged | R-CV1, R-IX4, R-CV6 |
| L2 | `registry/cv1-held-offer` (new, 1 run): the header of `cv1-held-pick` with `roc: nightly-2026-10-13-5e6f7a8` (H), H not installed, no roc on PATH. No pick, so D is the first read: one `GET /v1/toolchains?after=0`; the offer of the first probe reads the kept file (no second GET). `.talon.json` has `sha256_source` `registry`. No `api.github.com` call | R-CV1, R-IX4, R-CV3, R-CV5, R-SO22, R-SO24 |
| L2 | `registry/ix6-offline-upgrade` (new, 1 run): `upgrade --dry-run --offline` with a registry, the offline world of `ix6-update-offline` and a kept `toolchains.json` (2 rows: 2026-10-12 and H). No request. `NightlyFlow.plan!` reads the kept rows: H is the newest allowed compiler, no note | R-IX6, R-IX4, R-CV1, R-AD37, R-UP6 |
| L0 | None. No pure decision changes: the source of a read (`ResolveBase.list_first`, `list_later`) is a function of the request, and the case calls show it. A new expect would pin a name that the code agent may choose again | |

The fixtures are made by `research/slice-206e2b-revert/mkcases.py`. `research/slice-206e2b-revert/before/` has the old `sp24-held-move-drop`. The expect files came from a private reference (a 2-function change of `ResolveBase.list_first` and `list_later` and of `PickLoop.releases!`, in a copy under `research/`, with its own test binary). The copy is deleted. Each line was read against the rules.

## Red result

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt l0 l3` | pass |
| `scripts/test.sh l2` | 346 pass, 3 fail |
| `registry/sp24-held-move-drop` | Calls: GitHub list read, no `toolchains.json`, no pins (the tree differs too) |
| `registry/cv1-held-offer` | Exit 2 `no GitHub repository roc-lang/nightlies`: D and the offer read the GitHub list (no route) |
| `registry/ix6-offline-upgrade` | The note `the compiler list could not be read; roc stays <H>` and a read of the GitHub cache dir, not of `toolchains.json` |

## Expected exits (read, TW21)

| Case | Exit | Reason |
| --- | --- | --- |
| `sp24-held-move-drop` | 0 | `--dry-run`, the moves of json (R-SP26), as before |
| `cv1-held-offer` | 0 | Dry run. stderr is the line `downloading nightly-2026-10-13-5e6f7a8 (1.0 KB)` |
| `ix6-offline-upgrade` | 0 | stderr is the one line `index: cached at 2026-10-14T15:00:00Z` |

## Output (proposed, R-OUT2)

No new text and no new `--json` field. The texts are those of 206e and 206d.

## Out of scope

`direct`, the closure query, the no-copy rule (Q489), `outdated` with an unreadable list (D3 of 206e2), `tln roc ...`, the proxy, `tool`, `setup`, `probe`.

## Questions (stop until answered)

| # | Question |
| --- | --- |
| Q1 (answered, Design Q490) | `--offline` with a registry and a kept `toolchains.json`: the line `index: cached at <time>` (R-IX6, R-DI12) has "the time of the oldest copy that it used". Does the kept `toolchains.json` count as a copy of that rule? The current code gives `Cached(mtime)` in the list read, but the line of `ix6-offline-upgrade` uses only the index pages (the mtime of the file is 0 in the fake, so a count would print 1970). The case does not fix it: it is written with the oldest page copy (the reading of today), and `toolchains.json` has no row in `fx/mtimes`. A design answer may change that line |
| Answer | Answered (Design Q490, CLI R-IX6): no, `toolchains.json` is not a copy for the `index: cached at` line, and has no time. The current reading is right. Test change: none for `ix6-offline-upgrade`; add an L2 case or a run: `--offline` with a registry, a kept `toolchains.json` and no index page copy: the command works from the list and prints no `index:` line; and the code of the list read does not return `Cached(mtime)` into the line (an L0 `expect` for that) |

## Round 2 (Design Q490)

Q1 is answered: `toolchains.json` is not a copy for the `index:` line, and a run that used only the compiler list prints no `index:` line. `ix6-offline-upgrade` stays.

| Layer | Case | Rules |
| --- | --- | --- |
| L2 | `registry/ix6-offline-list-only` (new, 1 run): `upgrade --dry-run --offline`, a kept `toolchains.json`, a header with only `pf` and `roc:`, no index page copy. stdout `pf: fixed: offline, no cached index`, `nothing to change`; no stderr (no `index:` line); exit 0. No existing case covered it: each offline case has page copies. No L0 expect: the line is command code (`PickIndex`), not a pure decision | R-IX6, R-IX4, R-CV1, R-DI12, Q490 |

The expect files were taken from a run of the current tree (the code agent's work in progress, already green for D2) and read line by line; the list lines match those of `ix6-offline-upgrade`. Against the code before the slice the case fails for the cause of D2 (the note and the GitHub read). The Q490 point alone is a guard: it fails if the list read puts its time in the `index:` line.

## Doubts (no test)

| # | Doubt |
| --- | --- |
| D1 | D2 names `HeldRoc`, `NightlyFlow` and `PickLoop`. Only `NightlyFlow` has a case offline (bare `upgrade`). `HeldRoc.picked!` and `PickLoop.releases!` offline have no own case: a third case would be a second `--offline` flow (no compiler installed with `update`, which must choose: `ix6-offline-range` has no kept rows). The reference fix changes the 3 reads in one place (`list_first` and `list_later` read `Offline(origin)` as a kept registry source), so one case sees the shared cause |
| D2 | Offline, the kept rows give a first-sighting write of `pinned` rows to `compat.db` (R-CV6, as for any registry list read). It is a write in an offline run. The design says "no request", not "no write", so the case keeps the write |
| D3 | `cv1-held-offer` covers the offer after D. The optional compilers (`PickOptional.fetch!`) and `NoRank.offer!` have no new case: they use the same `list_later` |

## Code

| File | Change |
| --- | --- |
| `cli/lib/ResolveBase.roc` | `list_first`: a `Read` gives the registry (kept when `listed`). `--offline` with a registry (`index: Offline(origin)`) gives the kept file (`kept: true`, any age, no request). Else `Direct`. `list_later`: a `Read` always gives the kept file (the first read of the command asked once), else `list_first` |
| `cli/lib/PickLoop.roc` | `releases!` uses `list_first` (D is the first read when no pick read the list) |

Review notes: the offers, `Start.Downloads` and `PickOptional` use `list_later` and need no change. Q490 (G-C124) agrees with the pinned `index: cached at` line. Doubt: `list_later` with a `Read` that is not `listed` reads only the kept file (no request), so a path with no first read would see no rows. No test hits it.

## Disputes (from the code agent)

## Verify results

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-206e2b-revert/code-final.sha256` | OK, 2 files |
| Expected exits and stderr (read) | `sp24-held-move-drop` 0 (output unchanged); `cv1-held-offer` 0, one download line; `ix6-offline-upgrade` 0, `index: cached at 2026-10-14T15:00:00Z` (Q490); `ix6-offline-list-only` 0, no stderr, so no `index:` line (Q490) |
| `ix6-offline-list-only` | Made with `UPDATE=1` on the tree with the code in progress. Read again at close: the `pf` offline note, `nothing to change`, the dry-run line, exit 0. Agrees with R-IX6, R-DI11, Q490 |
| `scripts/test.sh check l2 l3` | check pass. L2 and L3: only the slice 217 red tests fail (`probe/ps2` to `ps7`, L3 `fx/ps1-real-fx-facts-of`; test step in progress). `fmt` and `l0` fail only on slice 217 test files (code agent run) |
| Code doubt | `list_later` in a registry run with no earlier first read reads only the kept file and sends no request. No path reaches it today (each later read follows a first read). Note for 206e3: a new later read with no first read must call `list_first` |

