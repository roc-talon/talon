# 068 The `.roc-version` hint cache

Phase: P1. Status: done

Slice 068 is the plan row 068 of `PLAN-P1.md` (section 2c), from the answer of the design agent to question Q1 of slice 032b (`DESIGN-GAPS-2026-10-25.md`): `Github.hint!` keeps each answer in a cache file (R-DI8), `tln why` shows rank 4 of R-EF1 from these files, and the calls.log of the cases that call `Github.hint!` change (TW21). The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files and the stubs are in `research/slice-068-revert/` (`before/NEW.txt` lists the new files).

## 1. Rules

| Id | Text (short) | Tested by |
| --- | --- | --- |
| R-DI8 (Design CLI 7.3) | One answer of the raw URL for each tag is kept in `talon/index/github/<owner>/<repo>/<tag>.roc-version`: the text of a 200, the empty file for a 404. No end of life: Talon never asks again. `--offline` uses the file, with no file there is no hint. `tln why` shows rank 4 from these files only. A request is made only when there is no file. | L0 `GithubTest` expects 6 and 7. L2 `index/di-list-flow` runs 10 to 17. L2 `evidence/ev1-why`. L3 `index/di1-github-pages` |
| R-EF1 rank 4, R-EF3 (rank 4 is a line only when it is the compiler of the block; the first line wins) | The command reads the file of each shown package that has a compiler and a GitHub release URL | L2 `ev1-why` runs 1 to 3, 6, 7, 9, 10, 12 (and the old L0 `evidence`, which does not change) |
| R-DI9 (no token for `.roc-version`) | The request has no token (old rows, kept) | L2 `di-list-flow` run 10 |
| R-DI1 (`why` makes no index call) | `why` reads the files and makes no request | `calls.log` of `ev1-why`: no `http_get` |
| R-GC12 (`cache clean` removes `talon/index/`) | The hint files are in that dir: no new code | none new (the old cases of `cache clean` cover the dir) |

`MISSING=1 scripts/rules.sh R-DI R-EF` lists no id after this slice that it listed before.

## 2. Flow (what the L2 cases fix)

`Github.hint!` (the signature has `roots` and `offline`, section 3):

| Step | Call | Rule |
| --- | --- | --- |
| 0 | `Github.hint_file` is `Err(BadPart)` (manager answer, section 10): `Ok(Err(NoHint))`, no call at all | R-DI8 |
| 1 | One `read_files!` of `[Github.hint_file]`. A file that is there (any text, also the empty text) is the answer: `Github.hint` of status 200 and that text. No more call. An unreadable file is no file | R-DI8 |
| 2 | No file and `offline`: `Ok(Err(NoHint))`. No more call | R-DI8, R-DI12 |
| 3 | No file, not offline: one `http_get!` of `hint_url` with `Net.headers` (no token, no ETag). A transport error is `network_failure`. A status that `hint_keep` does not keep (not 200 and not 404) is `status_failure` (exit 15), and nothing is written | R-DI9 |
| 4 | Status 200 or 404: one `write_atomic!` of `[{ path: hint_file, content: hint_keep }]`, then the answer of `Github.hint`. A failed write is a failure of kind `Environment`, `cannot write <path>` (as `releases!`) | R-DI8 |

`EvidenceFlow.blocks!`, new step 5 (it was "no call"): one `read_files!` of the `Github.hint_file` of each package that is shown with a compiler and has a `Github.hint_ref` (the same path once, in the order of the packages). It comes after the `db_query` (so a db that is too new stops the run before it) and before the scan of the used modules. No such package (a path entry, a foreign URL, no compiler): no call. The `hint` of `Evidence.of_pair` is `Github.hint({ status: 200, body: <file text> })`: `Ok(id)`, else `Err(None)` (no file, unreadable file, empty file, no id in the text). `Evidence.of_pair` shows the line only when `id` is the compiler of the block (`Pin.same_id`, D1 of slice 032b, no change). No request, ever.

## 3. Public signatures (the code agent keeps them)

| Function | Signature | Stub |
| --- | --- | --- |
| `Github.hint_file` | `{ roots : Roots, owner : Str, repo : Str, tag : Str } -> Try(Str, [BadPart])` (manager answer: an unsafe part gives `Err(BadPart)`, section 10) | `crash "todo: slice 068"` |
| `Github.hint_ref` | `Str -> Try({ owner : Str, repo : Str, tag : Str }, [NoRef])` | same |
| `Github.hint_keep` | `{ status : U16, body : Str } -> Try(Str, [NotKept])` | same |
| `Github.hint!` | `Fx, { net : Net.Settings, roots : Roots, owner : Str, repo : Str, tag : Str, offline : Bool } => Try(Try(Str, [NoHint]), Fail)` (was without `roots` and `offline`) | same |

Wiring that the test agent wrote (it is not a stub): `cli/flowprobe.roc` (`hint [--offline] <owner>/<repo> <tag>`) and `tests/commands/main.roc` (the `hint` line of the `index` entry has the word `offline`) pass `roots` and `offline`. The code agent writes: the 4 bodies, and the wiring of `EvidenceFlow.blocks!` (step 5, the stub has `hint: Err(None)`). No other module changes.

## 4. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/Github.roc` | 371 | 3 new stubs and the new signature of `hint!` (the table above is its doc) |
| `cli/lib/EvidenceFlow.roc`, `cli/lib/Evidence.roc` | 158 and 171 | Docs only (step 5, rank 4) |
| `cli/flowprobe.roc`, `tests/commands/main.roc` | n/a | Wiring (section 3) |
| `tests/unit/GithubTest.roc` | 215 (+52) | 2 new `expect`s, at the end |
| `tests/commands/cases/index/di-list-flow/` | 17 runs (+4) | 4 new runs, new expected files |
| `tests/commands/cases/evidence/ev1-why/` | 12 runs | 3 new given files (`index/github/acme/...`), `rules`, new expected files |
| `tests/scenarios/index/di1-github-pages/` | n/a | 8 new lines in `cmd`, new expected files |
| Old expected files | 3 L2 cases | Section 7 |

## 5. Tests

| Layer | File and case | Content | Rule ids |
| --- | --- | --- | --- |
| L0 | `GithubTest` expect 6 | `hint_file` (14 rows: the index dir, a tag with `v` and `-rc1`, dots inside a tag, and `BadPart` for a tag that is `..` or `.`, `a/../../x`, `a/b`, a backslash, a NUL byte, empty, an owner or a repo that is `..`, an owner with `/`, an empty repo) and `hint_ref` (16 rows: a release URL, a tag with a pre-release part, another host, `http`, 2 tag segments, no asset, empty tag, empty owner, not a download, a path, empty, and a tag that is `..`, an owner that is `..`, a repo that is `.`, a tag with a backslash or a NUL byte) | R-DI8 R-ID3 |
| L0 | `GithubTest` expect 7 | `hint_keep` (7 rows: 200 with an id, 200 with white space only, 200 empty, 404, 500, 403, 304) and the two round trips with `Github.hint` (an id comes back, the 404 file is no hint) | R-DI8 |
| L2 | `index/di-list-flow` runs 10 to 17 (runs 14 to 17 are new, runs 10 to 12 change) | The first request of a tag reads (no file), asks, writes (200: the text; 404: the empty file; 500: no write). Run 14: a tag with a file makes no request, also with no token. Run 15 (`offline`): the empty file is `no hint`. Run 16: the 500 was not kept, so the request is made again (exit 15). Run 17 (`offline`, no file): `no hint`, no request, no write | R-DI8 R-DI9 R-DI12 R-EV20 |
| L2 | `evidence/ev1-why` (12 runs, 3 given files) | Rank 4 line after the pin (runs 1, 2, 3, 6, 10), rank 4 alone wins (run 7 `--json`: `winner` true), a hint of another compiler is no line (run 9), an empty file (run 12) and no file (runs 4, 5) are no line, a path entry makes no read (run 8), a db that is too new stops before the read (run 11) | R-EF1 R-EF3 R-DI8 R-DI1 R-CM7 |
| L3 | `index/di1-github-pages` (8 new lines in `cmd`) | The real `Fx`: the file of the 200 (the tree diff has its text) and the empty file of the 404 are in the index dir. A second ask with a dead raw base gives the same answers (no request). `--offline` with no file: `no hint`, nothing written | R-DI8 R-DI12 R-EV20 |

L0 count: 2 new `expect`s in 1 file (`GithubTest`, driver `l0-2`). Deep cases: 2 L2 cases (4 new runs in one, 3 given files in the other), 1 L3 case with new lines.

## 6. Output (proposed, TW24, R-OUT2)

| Output | Text | Where |
| --- | --- | --- |
| `tln why` rank 4 line | `        4 roc-version: pass` (the format of slice 032b section 8, source word `roc-version`) | `ev1-why` |
| `why --json` | An item `{ "rank": 4, "source": "roc-version", "result": "pass", "modules": [], "winner": <bool> }` in `evidence` | `ev1-why` run 7 |
| The cache file | The text of the answer, as it came (a 200 with a final newline keeps it), or the empty text. No header, no meta file | proposal: the human may ask for a JSON file with the status |
| Failure of a 500 | `GitHub answered 500 for <hint url>` (old text, kind `network`, exit 15) | `di-list-flow` run 16 |

No new `data` field and no new human line of a command: the evidence of `why` has the new line only.

## 7. Changes of old tests (TW21)

The old expected files were copied to `research/slice-068-revert/before/` first. Each changed file was read (the diff of each file with its copy).

| Case | File | Change |
| --- | --- | --- |
| L2 `index/di-list-flow` | `calls.log`, `stdout`, `stderr`, `tree.diff` | Runs 10 to 12: a `read_files` before the request, a `write_atomic` after a 200 (2.1.0) and after a 404 (3.0.0), none after the 500 (4.0.0). The 4 new runs at the end. `tree.diff` has the file of 2.1.0 only: an empty file (3.0.0) has no line in a tree diff |
| L2 `evidence/ev1-why` | `calls.log`, `stdout` | One `read_files` of the hint files after each `db_query` (10 runs: not run 8, a path entry, and not run 11, a db that is too new). 5 runs with the new line, and run 7 (`--json`) has one item instead of `[]` |
| L2 `evidence/ev5-workspace` | `calls.log` | One `read_files` of the hint file of json 2.0.0 (no file there) after the `db_query` |
| L2 `closure/cl2-chain` | `calls.log` | The same line for the packages that `why` shows in 2 runs |
| L3 `index/di1-github-pages` | `stdout`, `tree.diff` | The new lines of `cmd`. `tree.diff` has the file of 2.1.0. `http.log` does not change (no new request) |

No other old case changes (the run of `scripts/test.sh` with the reference was green).

## 8. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The file holds the body of a 200 as it came, and the empty text for a 404 (R-DI8: "the file text, or an empty file"). `hint` reads the file as a 200 | The first line only (the body of a 200 can have lines that `hint` ignores: the same answer, but the file would not show the answer as it came) |
| D2 | A 200 with no hint line (white space only) is kept (a tag is fixed). Any other status (500, 403, 304) is not kept and the request fails (exit 15) | A 5xx kept as "no hint" (a server fault is no answer about the tag) |
| D3 | One `read_files!` for the file, no `list_dirs!` (the 2 calls of `releases!` are for the ETag and the page chain) | A listing of the repo dir |
| D4 | `offline` with no file is `Ok(Err(NoHint))` and not a failure (R-DI8: "there is no hint"). The command that calls `hint!` decides | Exit 15 as for a missing page (a hint only orders the search, R-EF2) |
| D5 | `why` reads the hint files after the `db_query` and before the scan (one call, the same path once) | In the same call as the pins (it changes the read of step 3 in 2 cases) |
| D6 | A failed write of the cache file is a failure of kind `Environment` (as `releases!`). No test: the fake `Fx` has no table for a failing write of one path | A warning and the answer (a cache that cannot be written would hide a full disk) |
| D7 | Only the form `https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>` has a hint (`hint_ref`). The raw base of R-DI8 is the host of GitHub | A hint for another host |

## 9. Out of scope

| Part | Reason |
| --- | --- |
| A command that calls `Github.hint!` in the solver ("only when the solver needs a hint for that candidate", R-DI8) | PLAN row 068 names the cache and `why`. No command calls `hint!` today (only `flowprobe`). The cache is written only by `hint!`, so `why` shows rank 4 only for a file that an earlier call wrote. The slice that wires the oracle to `hint!` is a follow-up (Q2) |
| The failing write of the cache file (D6) | See D6 |
| R-GC12 for the hint files | The files are in `talon/index/`: the old cases of `cache clean` cover the dir |

## 10. Questions and manager answers (2026-10-25)

Decisions D1 to D7 are accepted. Answers:

| # | Question | Answer |
| --- | --- | --- |
| Q1 | Which summary shows rank 4? | R-DI8 says "`tln why` and the evidence of a command". `EvidenceFlow.blocks!` has one caller, `Why.run!`. The summary of the other commands has only the rank 1 unit-fail notes (`Evidence.note`), never a block. So `ev1-why` is the only case that shows rank 4, and no new world is made. Out of scope |
| Q2 | Which command calls `Github.hint!` for the solver? | Out of scope. The manager adds a follow-up row: the solver calls `hint!` when it needs a hint (R-DI8: "only when the solver needs a hint") |
| Q3 | A tag with `/` or `..` | Must fix in this slice. The tag, owner and repo come from a URL in a header that anyone can write. A part that is empty, `.`, `..`, or has `/`, `\` or a NUL byte gives no cache path: `hint_file` is `Err(BadPart)`, `hint_ref` is `Err(NoRef)`, and `hint!` makes no call (no read, no request, no write). A tag such as `v1..2` is safe. L0 rows in `GithubTest` expect 6 (`..`, `.`, `a/../../x`, `a/b`, backslash, NUL, empty, owner and repo) and one mutation (m7, below) |

Report for the manager: the cache path of `releases!` has the same fault, and it is not fixed here. `Github.repo_dir` joins `owner` and `repo` with no check. `Ident.github_name` (R-ID3) takes them from the URL and checks only that they are not empty, so an owner `..` or a repo `..` in a header URL gives `<index>/github/../..` and `releases!` writes `1.json` and `1.meta` outside `talon/index/github/` (`..` for both: in `talon/`). A `\` is a path part on Windows. The manager adds a row.

## 11. Red output

Run with the stubs in the tree and the private reference away (redone after the manager review, with the reference of slice 070 in the tree so that only this slice is red).

| Step | Result |
| --- | --- |
| check, fmt | pass (the stubs compile) |
| l0 | FAIL (8.5 s): `GithubTest` (`l0-2`): the 2 new expects fail (`todo: slice 068`). All other files pass |
| l2 | FAIL (10.1 s): the 4 cases `index/di-list-flow` (`[ROC CRASHED] todo: slice 068`), `evidence/ev1-why`, `evidence/ev5-workspace`, `closure/cl2-chain` (the `read_files` of the hint files is missing in `calls.log`: a wrong value) |
| l3 | FAIL (10.1 s): `index/di1-github-pages` (`todo: slice 068`) |
| selftest, l1 | pass |

The old tests of section 7 are red on purpose (their expected files changed with the slice). All other old tests pass. With the reference in the tree `scripts/test.sh` exited 0.

## 12. Revert check (TW12)

7 changes of the private reference, one at a time, each compile-checked, with filtered runs only (L0 `l0`, L2 `index/di-list-flow evidence/ closure/`, L3 `index/di1`). The reference is put back after each change. All 7 are caught. The script, the logs and the reference are deleted (manager, 2026-10-25).

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | A 404 is not written (`hint_keep` has no 404) | L2 `di-list-flow` |
| m2 | `offline` with no file asks anyway | L2 `di-list-flow` run 17, L3 `di1` |
| m3 | `why` reads the hint files also with no path (an empty `read_files`) | L2 `ev1-why` (run 8) |
| m4 | `why` reads the hint files before the db | L2 `ev1-why` run 11 |
| m5 | A cached text is the answer as it is (no `hint` parse: the final newline is in the text) | L2 `di-list-flow` run 14 |
| m6 | The path has the owner and the repo swapped | L0 `GithubTest` |
| m7 | The guard of the path parts is removed (`safe_part` is always true) | L0 `GithubTest` expect 6 (`l0-2` fails) |

## 13. Next step

The manager reviewed the tests (section 10). Then the code agent writes the bodies of section 3 and the wiring of `EvidenceFlow.blocks!`. The review is applied (the answers in section 10); the private reference is deleted.

## 14. Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## 15. Verify results (code agent)

Code: `cli/lib/Github.roc` (the 4 bodies, the private `safe_part`, `kept_hint`, `ask_hint!`), `cli/lib/EvidenceFlow.roc` (step 5: `hints_of!`, `Active` has the new field `url`). `scripts/test.sh` exit 0. 4 mutations, one at a time, with filtered runs only. The code is the same as before the mutations (compared with `cmp`).

| Mutation | Result |
| --- | --- |
| The guard `safe_part` is always true | Caught: L0 `GithubTest` expect 6 (`l0-2`: 1 failed) |
| A 404 is not kept (`hint_keep` gives `NotKept`) | Caught: L2 `index/di-list-flow` |
| `offline` with no file asks anyway | Caught: L2 `index/di-list-flow` (run 17) |
| `why` makes a `read_files` call also with no path | Caught: L2 `evidence/ev1-why` (run 8) |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-068-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, both slices in) | Exit 0, all 7 steps, 177 L2 cases |
| Gap step | Skipped: 9 of 9 code-agent mutations caught, no new decision that needs a test |
