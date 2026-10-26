# 074 Attestation in `tln tool update talon`

Phase: P1. Status: done

Slice 074 is the plan row 074 of `PLAN-P1.md` (section 2c). It closes Q-A1 of slice 050. R-S2 (design agent, 2026-10-25): `tln tool update talon` checks the attestation as R-IS3 does. When `gh` is installed and logged in, it runs `gh attestation verify <file> --repo roc-talon/talon` on the download before the first use. A failure is exit 16. With no `gh` it prints a note. The test agent wrote tests and stubs. A private reference (`research/slice-074-revert/reference/`, kept until the review is applied) passes all of them. All `gh` runs in L2 go through the fake `Fx`. In L3 the `gh` is a shell script of the case. No real `gh`, no network.

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-S2 | The check is in the prebuilt path of `tool update talon`. A failure is exit 16, the old `tln` stays | L0 `TalonUpdateTest` 13. L2 `tool/ts8-attest` runs 1 to 3 |
| R-IS3 | The same commands and the same repository as `install/install.sh` (line 148 to 152): `gh auth status`, then `gh attestation verify "$TMP" --repo "$REPO"` (`REPO` is `roc-talon/talon`). The note and the line `attestation ok` have the text of `install.sh` | L0 `TalonUpdateTest` 13. L2 `ts8-attest`. L3 `tools/ts1-update-talon` steps 1, 4 |
| R-SE13 | No file is renamed or run before the check. A failed check changes nothing | L2 `ts8-attest` run 2 (no `chmod`, no `--version`, no `rename`). L3 step 4 (the check is before `--version`) |

Other rule ids that the tests name: R-S1, R-S3, R-DA3, R-CC2, R-J2.

## 2. Public signatures (fixed by the L0 test)

| Function | Signature | Stub state |
| --- | --- | --- |
| `TalonUpdate.gh_state` | `{ found : Bool, auth : Try([Exited(I32), Signaled(I32), NotStarted(Str)], [NotAsked]) } -> [Ready, LoggedOut, Missing]` | `crash "todo: slice 074"` |
| `TalonUpdate.gh_auth_argv` | `List(Str)`: `gh auth status` | `[]` |
| `TalonUpdate.attest_argv` | `{ file : Str } -> List(Str)`: `gh attestation verify <file> --repo roc-talon/talon` | `crash` |
| `TalonUpdate.attestation_check` | `{ tag, asset, ended, last_line } -> Try({}, Fail)`: `Exited(0)` is `Ok`, any other end is kind `Integrity` (exit 16) | `crash` |
| `TalonUpdate.attestation_note` | `Str` | `"todo"` |
| `TalonUpdate.attestation_ok` | `Str` | `"todo"` |

Proposed structure of the flow (the `calls.log` files fix the calls, not the names): a private `attested!` in `TalonUpdateFlow`, called in `staged!` after `check_download` and before `made_executable!`. The reference is about 35 lines in `TalonUpdateFlow` (371 to 404) and 35 in `TalonUpdate` (396 to 412). `Job` gets a field `shown : Fx` for the line `attestation ok`.

The calls of the check, in order (step 8b of the flow): `programs ["gh"]`. A `gh` that is there: `spawn_all` (limit 1) of `gh auth status`. Logged in (exit 0): `spawn_all` (limit 1) of `gh attestation verify <data bin>/tln.<hex>.tmp --repo roc-talon/talon`, then the line `attestation ok`. Else the note on stderr and no more call.

## 3. Tests

| Layer | File and case | Content |
| --- | --- | --- |
| L0 | `tests/unit/TalonUpdateTest.roc` 13 | `gh_state` (7 rows), the 2 argument lists, the note, the ok line, `attestation_check` (ok, exit 1 with and without a last line, signal, not started, exit code 16) |
| L2 | `tool/ts8-attest` (new case, 23 files, copy of `ts2-stops`) | run 1 (v0.3.1): `gh` there, `gh auth status` exits 1: the note, no `verify`, the update is installed. Run 2 (v0.3.2): logged in, `verify` exits 1: exit 16, no `chmod`, no `--version`, no `rename`, the temp file and the scratch dir deleted. Run 3 (v0.3.4): `verify` exits 0: `attestation ok`, then `chmod`, `--version`, the install |
| L2 | `tool/ts1-update`, `ts2-stops`, `ts3-nostart`, `ts4-rocforeign`, `ts5-windows`, `ts5b-winfresh` (changed) | The runs that get to the downloaded file have one more call `programs gh` (no `gh` in `fx/programs`) and the note on stderr (TW21, section 3a) |
| L3 | `tools/ts1-update-talon` (changed) | `given/bin/gh` (a script, first on `PATH`: the host `gh` is never used). Step 1: not logged in, the note, `gh.log` has `auth status`. Step 4 (`GH_FAKE=ok`): `attestation ok` before the `--version` that fails, `gh.log` has `attestation verify $HOME/.local/share/talon/bin/tln.<hex>.tmp --repo roc-talon/talon` |
| Harness | `tests/commands/FakeJobs.roc`, `FakeFx.roc` (doc) | A job needle `@<n>|<text>` is for the n-th run of the case only (the runs are counted by the lines `args` of `calls.log`). A case needs it to answer `gh` in another way in each run. 9 lines |

The host of the test run has a real `gh` (`/usr/bin/gh`). Without `given/bin/gh` the L3 run would call it. The L3 `gh` script is the guard.

### 3a. TW21: old expected files that changed

| File | Change (all checked with `diff -r` against `research/slice-074-revert/before/`) |
| --- | --- |
| `ts1-update`, `ts3-nostart`, `ts4-rocforeign` `expect/calls.log` and `expect/stderr` | 1 line `programs gh`, 1 line of note |
| `ts2-stops` | the same for run 6 (the one run that gets to the file) |
| `ts5-windows`, `ts5b-winfresh` | the same. `expect/stderr` is new (the note) |
| `ts1-update-talon` (L3) | `expect/stderr` has the note, `expect/stdout` has the lines of the new `gh_calls` and `attestation ok` |
| `rules` of the 6 L2 cases | one paragraph that says so |

Counts: new L0 `expect` 1. New L2 case 1 (3 runs). 6 old L2 cases and 1 L3 case changed.

## 4. Output (proposed, R-OUT2, TW24)

| Output | Text |
| --- | --- |
| No `gh`, or `gh` not logged in (stderr, the update goes on) | `note: attestation not checked (needs gh, logged in)` (the text of `install.sh`) |
| Good check (stdout, with `--json` stderr, not with `--quiet`) | `attestation ok` (the text of `install.sh`) |
| Failed check (stderr, exit 16) | `attestation check failed for tln-x64musl of roc-talon/talon v0.3.2: gh exit 1: Error: no attestations found for the file. tln is not changed.` The part after `gh` is `exit <n>`, `signal <n>` or `not started: <text>`, then `: <last line of the stderr of gh>` when it is not empty |
| `--json` | no new `data` field: the outcome of `tool update` is as before |

## 5. Decisions that the design does not fix (the test agent chose)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The check is after the sha256 check and before `chmod` and `--version`: the first use of the file is the run of `--version` (R-S3) | After `chmod` (the file is not used by `chmod`, but a failed check should leave the file as it was) |
| D2 | 2 calls: `programs ["gh"]`, then `gh auth status` for a `gh` that is there | One call of `gh auth status` (a missing `gh` is `NotStarted`). The 2 calls are `command -v gh` and `gh auth status` of `install.sh` |
| D3 | No `gh` and a `gh` not logged in give the same note (as `install.sh`) | 2 notes |
| D4 | The note is on stderr, `attestation ok` goes through `Common.shown_fx` (stdout, stderr with `--json`, hidden by `--quiet`) | Both on stdout, as `install.sh` (`--json` needs a clean stdout) |
| D5 | `--from-source` has no check: it downloads a source archive, not a release binary, and the release workflow attests the binaries only (`.github/workflows/release.yml`) | A check of the source archive |
| D6 | The repository is `TalonUpdate.name` (`roc-talon/talon`). `TALON_REPO` of `install.sh` is a test hook of the script, not of `tln` | A new variable |
| D7 | A `gh` that starts and ends in a failure, a signal or no start of `attestation verify` is exit 16 | Exit 18 for a start that fails |
| D8 | The harness gets the needle `@<n>|` (section 3) | 3 L2 cases of one run each (about 60 files) |

## 6. Out of scope

| Item | Reason |
| --- | --- |
| A real `gh` and a real attestation | L4 needs a real release (the first release of the workflow of slice 052) |
| `tln setup` and `install.ps1` | `install.ps1` has the check (slice 052). `setup` downloads nothing |

## 7. Questions (TW17) and design gaps

| # | Question or gap | What the tests pin |
| --- | --- | --- |
| Q1 | A release that has no attestation (each release before the workflow of slice 052, a release that the maintainer made by hand) fails the check when the user has `gh` logged in: exit 16. The design gives no flag to skip the check (as `install.sh` has none) | Exit 16 (`ts8-attest` run 2). A way out is a design decision |
| Q2 | The note says "needs gh, logged in". `gh` can be installed with a token in `GH_TOKEN` and no `gh auth login`: `gh auth status` still exits with 0 for it. No question for the tests | `gh auth status` exit 0 is the only test of "logged in" (the text of `install.sh`) |
| Gap | `--quiet` and the note (as Q-Q1 of slice 050): the note is on stderr and is not hidden | Not tested |

## 8. Red run, revert check

Red run with the stubs (`research/slice-074-revert/red-all.log`; slice 073 as the reference):

| Step | Result |
| --- | --- |
| check, fmt, selftest | pass |
| l0 | 1 `expect` fails: `TalonUpdateTest` 13 (`todo: slice 074`) |
| l2 | 7 cases fail (a wrong `calls.log` or `stderr`: the flow is not wired): `ts1-update`, `ts2-stops`, `ts3-nostart`, `ts4-rocforeign`, `ts5-windows`, `ts5b-winfresh`, `ts8-attest` |
| l3 | 1 scenario fails: `tools/ts1-update-talon` (the note is missing) |

Green run with the reference (`research/slice-074-revert/green-all.log`): check, fmt, l0, l2, l3, selftest, l1 all pass.

Revert check (`research/slice-074-revert/mutate.py`, result in `mutants.log`, 6 hand mutations of the reference, filtered runs):

| # | Mutation | Caught by |
| --- | --- | --- |
| A1 | the check is after the use of the file (D1) | L2 `ts8-attest`, L3 |
| A2 | no login check: `gh` that is there is used | L0 13, L2 `ts8-attest` |
| A3 | a failed check is ignored | L2 `ts8-attest` run 2 |
| A4 | the note goes to stdout | L2 `ts8-attest` |
| A5 | no look for `gh` on `PATH` (`gh auth status` always runs) | L2 `ts1-update` |
| A6 | a failed check is exit 1, not 16 | L0 13, L2 `ts8-attest` |

6 mutations, 6 caught.

## 9. Compiler and tool limits met

| Limit | Handling |
| --- | --- |
| A mutation with `'''` inside a Python string failed to parse | the script writes the edits as strings with `\n` |
| A test run with a real `gh` on the host | `given/bin/gh` of the L3 case |

## 10. Notes for the code agent

| Topic | Note |
| --- | --- |
| Order | `TalonUpdate` (L0 13), then `TalonUpdateFlow` (L2 `tool/ts`, L3 `tests/run.sh ts1-update-talon`) |
| Files | `TalonUpdate` and `TalonUpdateFlow` stay under 490 lines |
| Tests | Do not edit tests (TW18). A wrong row goes back to the test agent |

## Review (manager, 2026-10-25)

Accepted with all decisions D1 to D8 and the `@<n>|` needle of `FakeJobs` as written. Manager answer for Q1: no Talon release exists yet, and the release workflow of slice 052 attests every binary from the first release on, so a release with no attestation does not happen in practice. Exit 16 stays and there is no skip flag.

The private reference, `mutate.py`, `mutants.log`, the logs and the switch scripts were deleted. `before/` and `stubs/` stay in `research/slice-074-revert/`.

## Code (code agent, 2026-10-25)

Disputes (from the code agent): none. No test, fixture or expected file was changed.

| Decision | Rejected |
| --- | --- |
| `attested!` and `gh!` are private in `TalonUpdateFlow`, called in `staged!` after `check_download` and before `made_executable!`. `Job` has `shown : Fx` for the line `attestation ok` | The check in `prebuilt!` |
| A `spawn_all!` that gives no result is kind `Internal` (as the other steps) | |

## Verify results

| # | Mutation | Caught by |
| --- | --- | --- |
| A1 | the check after `--version` | L2 `tool/ts8-attest` |
| A2 | `gh_state` takes any auth result as `Ready` | L0 `TalonUpdateTest` 13 |
| A3 | a failed check is ignored | L2 `tool/ts8-attest` |
| A4 | the note goes to stdout | L2 `tool/ts8-attest` |
| A5 | a failed check is kind `Environment` | L2 `tool/ts8-attest` |

5 mutations, 5 caught.

## Close (manager, 2026-10-26)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-074-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run, both slices in) | Exit 0, all 7 steps, 180 L2 cases |
| Session crash during the code step | The code agent re-read each changed file against `before/` and found no leftover mutation; the full run after the crash is clean |
| Gap step | Skipped: 12 of 12 code-agent mutations caught, no new decision that needs a test |
