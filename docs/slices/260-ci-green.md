# 260 CI green

Phase: P2 (ordered by the user on 2026-11-23). Status: 260a tests (G10 red for the code agent), human review. Design id: Q639. Plan id: G-C269. Slice number: 260.
Diagnosis: `research/ci-red-2026-11/RESULT.md` (groups G1 to G11). Part 260b (G6, the Roc bump) is a separate slice part. This part does not change `ROC_TAG`.

## 1. Groups, decisions and changes

The user decided each group on 2026-11-23. The user allowed edits to `scripts/test.sh`, `.github/workflows/ci.yml`, `.github/workflows/nightly.yml` and `tests/selftest.sh` for this slice only.

| G | Red step | Decision | Change (260a) | Files |
| --- | --- | --- | --- | --- |
| G1 | l2: 27 `channels/ch*`, 5 `gc/gc*` (CI ubuntu) | Compare `calls.log` always through `anc_filter`. Warn on `UPDATE=1` under another work root. | `run_case` compares the Fx calls through `anc_filter` (and drops `list_dirs /`) on each machine. The stderr compare is not changed (exact under `/tmp/talon-l2`). `UPDATE=1` with a work root that is not `/tmp/talon-l2` prints one `WARN` line: the stderr walk text and the sizes that hold the work dir path can still differ from CI. L2 no longer checks the walk up past the work dir. | `tests/commands/run.sh`, `tests/lib.sh` (comment) |
| G2 | l2: `tool/rm2-options`, `tool/rm7-stale-recorded` (`1.2 KB` / `1.1 KB`) | Change a fixture size. | `given/home/h2/.cache/roc/toolchains/link-system/.talon.json` is now pretty JSON (the same members, 21 more bytes). The `compilers` size is `1128 + <length of the work dir path>`, so the text is `1.2 KB` for each length from 22 to 121 (CI and macOS: 30, local: 71). The expected files do not change. | the 2 fixtures |
| G3 | l2: `registry/sn6-short-names`, `sn6-install-short` (macOS) | Escape upper-case letters in the fake HTTP names. | The case-safe form of a route name: an upper-case ASCII letter `X` is `^x`, `^` is `^^`. The fake HTTP of L2 (`FakeJobs.route_answer!`, `case_safe`) and of L3 (`tests/tools/fakehttp.py`, `case_safe`, the same route form) try the case-safe name first, then the plain name. So only a route that would collide needs the new name. The 2 cases: `packages%3Fshort=Parser` (and `.meta`) is now `packages%3Fshort=^parser`. | `tests/commands/FakeJobs.roc`, `tests/tools/fakehttp.py`, the 2 cases |
| G4 | l3: `fx/sq3-real-fx-smoke` (macOS) | Not depend on the host target order. | The second target of the case is `arm64glibc`, not `arm64mac`. `alias_in` and `alias_out` do not swap it, and it sorts before `x64musl` and before `arm64mac`, so the row order is the same on each host. (A sort in `cmd` does not help: the swap back is after the sort, and `facts.tsv` is made by the runner.) | `cmd`, `expect/stdout`, `expect/facts.tsv` |
| G5, G8 | l0 timeouts (macOS ci, nightly), selftest unit guard (macOS), nightly w1 at 45 s | `TEST_TIMEOUT` in the workflows. | `ci.yml`: the macOS matrix entry has `test_timeout: '120'`; the Test step has `TEST_TIMEOUT: ${{ matrix.test_timeout }}` (empty for ubuntu and windows: the default limits). `nightly.yml`: `TEST_TIMEOUT: 300`. | both workflows |
| G6 | nightly l2 build, selftest | Not in this part (slice 260b, the Roc bump). | none | none |
| G7 | w1 sqlite (CI ubuntu, nightly) | Pin an exact Node version. TalonRegistry fixed `sql/tests/run.mjs`. | `node-version: '26.7.0'` in both workflows. It is the local version (`node --version`), and `scripts/test.sh w1` passes with it (12.7 s). `actions/setup-node` installs any released version from nodejs.org. | both workflows |
| G9 | l3: `exit/ex1-parser-basic-cli` (nightly) | Add the `config.toml` hunk (R-SO24, R-SO15). | The hunk `home/.config/talon/config.toml` `+default-roc = "nightly-2026-10-12-2664a27"` is the first hunk of `expect/tree.diff` (the text of the nightly log). | `expect/tree.diff` |
| G10 | l3: `tools/tx1-x-run` (each run after 2026-11-20 12:00 UTC) | Q639: the age of a cached release list page uses the real clock. `TALON_NOW` stays for release ages and `min-release-age`. | The case sets the file time of the page on purpose, relative to the real time: `fresh` (`touch`, now) before steps 2, 4 and 5, so a slow runner gives the same requests, and `aged` (`touch -d @<now - 3600>`) before step 7. The text of step 7 says so. `expect/http.log` is not changed: it keeps the 4th request. | `cmd`, `expect/stdout` (the step 7 line) |
| G11 | selftest install (macOS, flaky) | Print the install output on a failure. | The row `install` prints the full output of each failing `install/test.sh` run, not only its `FAIL` lines. | `tests/selftest.sh` |

## 2. Code change for the code agent (G10, Q639)

| Item | Text |
| --- | --- |
| Rule | R-DI2 (with Q639): the age of a page in `talon/index/github/<owner>/<repo>/` is the real clock minus the file time of the page. `TALON_NOW` does not change it (R-EV22). The `Github.plan` doc says this already ("`now` is the real clock"). |
| Change | `ToolFlow` passes the real clock (not `facts.now`, which is `TALON_NOW`) as `now` to `Github.releases!` (`cli/lib/ToolFlow.roc` about line 259). `ChannelCmd` and `GitInstall` pass `run.real` already. |
| Check the other callers | `Init.roc` (about 226), `FullName.roc` (about 248), `PickIndex.roc` (about 78), and the paths through `PickLoop.releases!` / `ResolveBase.read_releases!` (`PickFlow`, `OutdatedFlow`). Each `now` that goes to `Github.releases!` or `Github.plan` is the real clock. `TALON_NOW` stays for `min-release-age` (R-C7), the release ages and the GC ages. |
| Red test | `tests/scenarios/tools/tx1-x-run`: today it fails with only the 4th request missing (`GET /api/repos/acme/app/releases?per_page=100 200`): step 7 has `TALON_NOW=2026-11-20T12:00:00Z`, and the page time (the real time minus one hour) is after it, so the age is 0. With the real clock the age is 3600 s, the page has no ETag, and step 7 sends the request. |
| Must not | Edit a test or a fixture (TW18). |

## 3. Design text (proposal for the lead, Q639)

| Where | Now | Proposal |
| --- | --- | --- |
| CLI R-DI2, after "A page younger than 60 s is used with no request, ..." | (no clock named) | "The age of a page is the real clock minus the file time of the page (Design Q639). `TALON_NOW` does not change it (R-EV22)." |
| CLI R-EV22, after the sentence about a lock heartbeat and a temp | (the list does not name the page cache) | "It does not change the age of a cached release list page (R-DI2, Design Q639): Talon uses the file time of the page and the real clock." |
| CLI R-DI12 | `index: cached at <time>` | No change. |
| Design 9 | (none) | "Q639 \| G-C269: which clock decides the age of a cached release list page (R-DI2, R-DI12, R-EV22)? Settled 2026-11-23: the real clock; `TALON_NOW` stays for release ages, `min-release-age` and GC ages (slice 260)." |
| TESTING 3.1 (the names table, for the human) | the `%XX` names only | One row: "`^x` (in a fake HTTP route name) \| the upper-case letter `X`; `^^` is `^` \| A case-blind file system (macOS) has one file for `short=Parser` and `short=parser`. The fake HTTP of L2 and L3 tries the case-safe name first, then the plain name (slice 260)." `decode_names` does not change it. |

## 4. Plan row (proposal for `docs/slices/PLAN-P2-CLI.md`)

| 260 | CI green | (status: tests, file 260-ci-green.md) 260a: the L2 compare of `calls.log` through `anc_filter` and the `UPDATE=1` warning (G1), the rm2/rm7 fixture size (G2), the case-safe fake HTTP names (G3), sq3 target `arm64glibc` (G4), `TEST_TIMEOUT` and Node 26.7.0 in the workflows (G5, G7, G8), the ex1 tree hunk (G9), tx1 ages its page with the real clock (G10, code: the real clock to `Github.releases!`), the selftest install output (G11). 260b: the Roc bump (G6). | R-DI2, R-DI12, R-EV22, R-SO15, R-SO24 | G-C269 (Design Q639) | none / none | 10 | Sonnet |

## 5. Local results (2026-11-23, TMPDIR=`<repo>/.tmp/tmp`, capped)

| Run | Result |
| --- | --- |
| `scripts/test.sh check fmt` | pass (3.0 s, 0.3 s) |
| `scripts/test.sh l0 l2` | pass (9.2 s, 25.6 s) |
| `tests/commands/run.sh tool/rm2 tool/rm7 registry/sn6` with a work dir path of 111 characters | 5 passed |
| `scripts/test.sh selftest` | pass (11.7 s) |
| `JOBS=1 scripts/test.sh l3` | 99 passed, 1 failed (`tools/tx1-x-run`: only the 4th request is missing, the red of section 2), 19 skipped. 84.7 s (JOBS=1). `fx/sq3-real-fx-smoke` passes. |
| `scripts/test.sh w1` (Node 26.7.0) | pass (12.7 s) |
| `tests/tools/ciscan.py yaml fast nightly pin portable .` | no FAIL line |

## 6. Only CI can confirm

| G | What |
| --- | --- |
| G1, G2 | L2 under `/tmp/talon-l2` (the machine rule forbids `/tmp` here). G2 by arithmetic: `1128 + 30 = 1158` gives `1.2 KB`. |
| G3, G4, G5, G11 | macOS: the case-blind file system, the host alias swap, the 120 s limit, and the install output of the next failure. |
| G7, G8 | Node 26.7.0 through `setup-node`; the nightly w1 with `SLOW=1` and the 300 s limit. |
| G9 | The nightly with `REAL_ROC=1 NET=1` (ex1 is skipped here). The nightly stays red on G6 until slice 260b. |
| G10 | Green only after the code change (section 2). |

## Questions (stop until answered)

None.

## Disputes (from the code agent)

### Dispute D-G10 (code agent, 2026-11-23): `tools/tx1-x-run` touches the wrong file

| Item | Text |
| --- | --- |
| Case | `tests/scenarios/tools/tx1-x-run/cmd`: `PAGE=$XDG_CACHE_HOME/roc/talon/index/github/acme/app/1.json` and `aged()` is `touch -d "@<now - 3600>" "$PAGE"`. |
| Expected | Step 7 has a 4th request (`GET /api/repos/acme/app/releases?per_page=100`). |
| Code (done) | `ToolFlow.release_list!` and `XFlow` pass the real clock (`Clock.times!`, `facts.?real`) to `Github.releases!`. |
| Reading | The file time of a page is the time of `<n>.meta`, not of `<n>.json`. `Github.cached_page!` takes `mtime` from the directory entry of the `.meta` file (`Github.page_files`: "Talon writes the body first, then the meta"; `Github.plan`: "`mtime` is the time of the last answer"). The L2 fixtures (`di-list-flow`, `od1-table`, `it1-app` and 7 more) set the time of the `.meta` file; when I read the time of `.json` instead, 10 L2 cases failed. |
| Evidence | A copy of the case with `PAGE=.../1.meta` passes (`SCENARIOS=<copy> tests/run.sh tools/tx1`: 1 passed). The real case, with `1.json`, still fails with only the 4th request missing. |
| Ask | Change `PAGE` in `cmd` to `1.meta` (or touch both files). No change of `expect/`. |
| Resolved (test agent, 2026-11-23) | Accepted. `fresh` and `aged` in `cmd` now touch both `1.json` and `1.meta` (the `.meta` time is the page time). No change of `expect/`. `JOBS=1 scripts/test.sh l3` with the code change: `tools/tx1-x-run` passes; 98 passed, 2 failed, 19 skipped. The 2 failures are `help/q7-help` and `help/q7-no-command`: they come from an uncommitted change of `cli/lib/Help.roc` in the working tree (the shorter command list), not from slice 260. |

## Verify results

### Mutation check (test agent, 2026-11-23)

`research/slice-260-revert/RESULT.md`: 6 mutants (ToolFlow, PickIndex, FullName.read_real!, NightlyFlow, Install.begin_loose!, AuditFlow), 6 killed. Only m1 was killed by the old tests (L3 tx1). New L2 gap cases (TALON_NOW and the fake real clock differ by one hour): `upgrade/ur10-real-clock-age`, `upgrade/ur11-real-clock-nightlies`, `audit/ad17-real-clock-age`, `registry/ad35-add-real-clock`. They pass with the code. Unrelated failure seen: `outdated/od1-table` (red slice 262 test).
