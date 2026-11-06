# 104 records

Phase: P2. Status: review (tests red on both nightlies, 2026-11-01, updated with the answers Q1 to Q7). Model for the code: Sonnet medium. Plan row: `docs/registry/PLAN.md` C.1, row 104. Gap: G16.

## 1. Scope

`packages/records` holds the API types of the registry that cross the wire, their JSON codecs, and three pure helpers (ids, codes, problem types). The CLI does not use it yet (G16, Design Q68): it has no `compat.db` rows. The package has no dependency (the wire carries versions as text, so it does not need `roc-semver`; the key columns are slice 105).

| Part | Who | State |
| --- | --- | --- |
| Frame: `main.roc`, the signatures and types of the 6 modules | Test agent | Done. The code agent does not change the header, the types or the signatures (TW18). |
| Bodies (`crash "todo"`) | Code agent | To do |
| Tests `packages/records/tests/` | Test agent | Red (section 6) |
| Step in `scripts/test.sh` | Manager | Request in section 7 |

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-PK7 | `records` builds and passes its tests on `ROC_TAG` and on `ROC_TAG_WORKER` | All tests, run with both compilers |
| R-AP15 | A group goes on the wire as `group` (URL form) and `series` | `WireTest` release, request, answer |
| R-AP16 | The closure request: `groups` (`series`, `range` optional), `hashes`, `compilers` (`from`, `to` optional) | `WireTest` request |
| R-AP17 | The answer: `artifacts`, `releases`, `epochs`, `runs`, `nearest`, `hints`, `log_size`, `unknown`, `checked` | `WireTest` answer |
| R-AP29, R-AP32 | `checked` and `repos` items, null when none | `WireTest` answer |
| R-AP21 | The 17 problem types, their status, the extra members | `ProblemTest` |
| R-AP44 | An unknown member is ignored | `ProblemTest`, `WireTest` request |
| R-RE1, R-RE2, R-RE19, R-RE20 | The artifact, release and dep records on the wire | `WireTest` release, artifact |
| R-IK1 | The wire has the text forms (hash base58, group URL form, version `X.Y.Z`, nightly tag) | `WireTest` |
| R-IK2 | `name_id` | `IdTest` |
| R-IK4 | The nightly id | `IdTest` |
| R-IK7 | The codes: `result`, `source`, the targets | `CodeTest` |

Design refs: Registry 4, 4.1, 4.2, 5, 5.1. Design 6.1 (R-PK7), `TESTING.md` 9 (TW31).

## 3. Findings on the pinned nightlies (probe: `research/slice-104-revert/probe/p2.roc`, same output on 2026-10-14-38a3029 and 2026-10-31-f7bef6b)

| Question | Result |
| --- | --- |
| SHA-256 in pure Roc? | Yes. `Crypto.SHA256.hash : List(U8) -> Digest` is a builtin on both nightlies. `.to_bytes()` gives the 32 bytes. Its hex for `[2] ++ "github.com/roc-lang/unicode/releases/download/{v}/"` starts with `dab544ab6661c1b9`, as the design says (R-IK2, K8). The design needs no question. |
| `\x02` in a Roc string? | Not a valid escape. Build the bytes with a `List(U8)`. |
| JSON | `Json.to_str` and `Json.parse` (builtin `Encoding.Json`) derive a codec for a structural record, list, `Bool`, `Str`, `U64`, `I64`. A big `I64` and `U64` (above 2^53) keep all digits. |
| Optional field `f ?: T` | Left out of the text when absent. A missing member decodes as absent. |
| `Try(T, [Missing])` field | Left out of the text on `Err`. A missing member decodes to `Err(Missing)`. A JSON `null` is an error (`InvalidJson`). So the derived codec cannot write or read the `null` that R-AP29, R-AP32 give. |
| An unknown member | Ignored by the derived parser. |
| Tag union | A tag with no payload is the text of the tag with its case (`"Null"`), so `Pass` is `"Pass"`, not `"pass"`. |
| Reserved words | `exposes`, `platform`, `targets` cannot be record fields (also `module`, `with`, `app`, `package`). `from`, `to`, `type`, `kind` are fine. |

### Codec choice (a proposal for the code agent, inside the signatures)

| Part | Form |
| --- | --- |
| Records with only `Str`, numbers, `Bool`, lists | The derived codec (`Json.to_str`, `Json.parse`) |
| Nullable member (`Try(T, [None])` in the public type) | A hand-written step on the Json primitives (`Json.encode_null`, `parse_null`), or a private nominal wrapper that has `parser_for` and `encoder_for`. Wire value: `null` when `Err(None)`. A missing member also reads as `Err(None)`. |
| Optional member of the request (`series`, `range`, `compilers`, `from`, `to`) | Left out of the text when `Err(None)` (R-AP16 "optional"). Read as `Err(None)` when missing. |
| Closed set (`result`, `source`, `side`, `state`) | Private mirror record with `Str`, converted by `Code.result_to_str` and its twins. An unknown value is `Err(BadJson(_))`. |

The code agent may use a different form if all tests pass.

## 4. Public signatures

All in the stubs. The error of each decoder is `[BadJson(Str)]`.

| Module | Items |
| --- | --- |
| `Id` | `name_id : U8, List(U8) -> I64`. `nightly_id : Str -> Try(I64, [NotANightly])` |
| `Code` | `Result`, `Source`, `Kind`, `kind_code`, `kind_from_code`, `result_code`, `result_from_code`, `source_code`, `source_from_code`, `result_to_str`, `result_from_str`, `target_code`, `target_name`, `is_new_target_name` |
| `Problem` | `Kind` (17 tags), `Extra`, `Body` (`type_text`), `type_uri`, `kind_from_uri`, `status`, `decode`, `encode` |
| `Release` | `Row` (`tag`, `yank_reason`, `withdrawn` nullable, ms times), `decode`, `encode` |
| `Artifact` | `Dep`, `Row` (`kind : Code.Kind`, `size`), `decode`, `encode` |
| `Closure` | `GroupQuery`, `Window`, `Request`, `Epoch`, `Run`, `Nearest`, `Hint`, `Checked`, `Repo`, `Answer`, `decode_request`, `encode_request`, `decode_answer`, `encode_answer` |

Sizes: the stubs have about 230 lines. A full body of the 6 modules is about 350 lines (the codec of the nullable member is the largest part). It fits TW19.

## 5. Wire form (settled in the design: Registry R-AP49 to R-AP52, R-IK4, R-IK7, R-RE1, R-RE26; Design Q70 to Q77)

| Rule | Effect in this package |
| --- | --- |
| R-AP49 | Members of release, artifact, dep as in the table. Release: `tag`, `roc_version`, `repo`, `yank_reason`, `withdrawn` are `Try(Str, [None])` and written as `null`. `withdrawn` is a text, not a Bool. Artifact: `kind` is `Code.Kind` (`app`, `package`, `platform`), `size : U64`, `deps` and `target_names` are sorted on encode. Dep: `series` and `version` are `null` together. |
| R-AP50 | Each time is a JSON integer in milliseconds: `published_at`, `checked_at`, `state_at`. |
| R-AP51 | A required member that is missing, `null`, of the wrong type, or outside its closed set is `BadJson`. A missing or `null` optional member is `Err(None)`. An unknown member is ignored. |
| R-AP52 | `Problem.Body.type_text` keeps the `type` as read. A body with no `type`, no `status`, or not JSON is `BadJson`. |
| R-IK4 | `nightly_id`: 7 lower-case hex digits, 2-digit day and month (or a month name with an upper-case first letter), a date that exists. |
| R-IK7 | `Code.target_code` has the 36 names (0 to 35). `Code.Kind` has the codes 0, 1, 2. |
| Names `exposed`, `platform_hash`, `target_names` | Reserved words in Roc, so the wire name is the field name (R-AP49). No rename in the codec. |

## 6. Tests

L0 here means W0 (`TESTING.md` 9): `roc test packages/records/tests/w0.roc`. 35 `expect`s in 4 modules. The count is over the budget of 20 because the wire has 6 record kinds. I merged the single-line cases of a topic with `and`.

| File | `expect`s | Case | Rules |
| --- | --- | --- | --- |
| `IdTest.roc` | 6 | `name_id` vectors (kinds 1, 2, 3; sign; empty bytes; kinds apart). `nightly_id`: both tag forms, leap days 2024 and 2028, date order and under 2^47, 16 bad texts (sha of 6 or 8 digits or upper case, 2026-02-30, 2027-02-29, 1-digit day or month, lower-case or capital month name) | R-IK2, R-IK4 |
| `CodeTest.roc` | 5 | `result` and `source` codes both ways, with the wire text. The 36 targets both ways (11 to 20 included). No code for a new name. `is_new_target_name`. `kind` codes | R-IK7, R-AP49 |
| `ProblemTest.roc` | 8 | The 17 types: URI, status, kind from URI. 5 bodies with the extra members. Round trip with 4 `detail` texts. Unknown type kept with status, title, detail (R-AP52). 4 bad bodies (not JSON, `[]`, no `type`, no `status`) | R-AP21, R-AP44, R-AP52 |
| `WireTest.roc` | 16 | Release decode (full row; null `tag`, `repo`, `withdrawn`; `yank_reason`; ms time), encode text. Artifact with deps (null series and version), sizes, kinds, sorted deps and targets on encode, unknown kind, missing and null required member, missing optional member. Request decode, minimal, absent members left out, unknown member. Answer decode (all members, `log_size` above 2^53), encode and round trip, unknown `result`. Missing required member in a request and in an answer, null required member, null optional member | R-AP15 to R-AP17, R-AP29, R-AP32, R-AP44, R-AP49 to R-AP51, R-RE1, R-RE2, R-RE19, R-IK1, R-IK7 |

Expected values: from the design text, and `name_id` and nightly ids from `hashlib` (python), computed apart from any code.

Red results (2026-11-01, `roc test packages/records/tests/w0.roc --no-cache`; `roc check` and `roc fmt --check` of `packages/records/*.roc` and `tests/*.roc` are clean on both):

| Compiler | Result |
| --- | --- |
| `ROC_TAG` nightly-2026-10-14-38a3029 | Ran 35 tests: 0 passed, 35 failed, all with `todo`, 0 compiler errors |
| `ROC_TAG_WORKER` nightly-2026-10-31-f7bef6b | The same |

## 7. Change for `scripts/test.sh` (the code agent of the script makes it; the test agent does not edit the script)

Cause of the failures of `fmt`, `l0` and the selftest "unit guard" row: `unit_files` of `tests/lib.sh` lists `packages/*/tests/*.roc`, so the l0 step runs `roc test` on each unit module of `packages/records/tests/` (they have no header, so they fail), and the unit guard row copies the tree with `packages/` linked. `roc fmt --check` passes on all files of `packages/records/` with both nightlies, so a `fmt` failure comes from another file or from the same l0 run. Check it again after the change.

| # | File | Change |
| --- | --- | --- |
| 1 | `tests/lib.sh`, `unit_files` | Replace `ls packages/*/tests/*.roc 2> /dev/null` with `ls packages/*/tests/*.roc 2> /dev/null \| grep -v '^packages/records/'`. Then the l0 step skips the dir, and `unit_modules_check` is not run on it by the l0 step. |
| 2 | `scripts/test.sh` | New function `step_records`: `for r in "$ROC" "$ROC_WORKER"; do "$r" fmt --check packages/records/*.roc packages/records/tests/*.roc \|\| rc=1; run_limited "$(limit_of w0)" "$r" test packages/records/tests/w0.roc --no-cache \|\| rc=1; done`. Call it at the end of `step_w0` (TW31: W0 runs `records` on both compilers), or as part of the `w0` budget. |
| 3 | `scripts/test.sh`, `step_fmt` | No change needed for `ROC_TAG` (the `find` covers `packages`). The fmt with `ROC_WORKER` is in `step_records`. |
| 4 | `tests/selftest.sh` | No change if row 1 is done: the unit guard tree has `tests/unit/` only as a unit dir. If `packages/records/tests/` still shows in `unit_files` output, a row must check that `unit_files` does not list it. |
| 5 | `step_check` (`APPS`) | `packages/records/main.roc` is in `APPS` by `ls packages/*/main.roc`. This is right: `roc check` of a package passes on `ROC_TAG`. |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| `compat.db` rows, `Facts`, `Evidence` | G16, Design Q68: a client track slice |
| `toolchains` rows (R-AP5), `compat` post body (R-AP10), `tokens`, `me`, sweeps, `compat_hints` list (R-AP39, R-AP40), short names (R-SN1) | Slices 106 and 110 need the closure, release and artifact records first. Later slices add the other records to this package. |
| Version keys (`to_key`, R-IK5) | Slice 105, with `roc-semver` 0.2.0 |
| `contributor` ids (HMAC with `CONTRIBUTOR_KEY`, R-IK2) | Needs HMAC and the Worker secret (R-CT3): slice 117 or later |
| Target codes 36 and up | The state of the registry (R-IK7), not of this package |
| Moving `worker/lib/Problem.roc` to `records.Problem` | Slice 101 is in progress. A later slice moves it. |
| A port of the 17 `title` texts | `Problem.Body` carries the `title` as read. The titles are a proposal of slice 101. |

## 9. Questions (answered 2026-11-01)

| # | Question | Effect | Answer |
| --- | --- | --- | --- |
| Q1 | R-IK7 says codes 11 to 20 are "the same with `x64v1`". What are the 10 names (`x64v1mac`, `x64v1win`, ... `x64v1elf`?). The text of `RocTarget` is not in the repo. | `CodeTest` has no row for 11 to 20. The code agent cannot write them. | Answered (Design Q72): Registry R-IK7 lists 11 `x64v1mac` to 20 `x64v1elf`, in the order of `RocTarget`. |
| Q2 | What are the values of `kind` of an artifact (R-RE1)? Today `Artifact.Row.kind` is text. | Slice 106 and 111 decide | Answered (Design Q73): `app`, `package`, `platform`, a closed set with codes 0, 1, 2 (Registry R-AP49, R-IK7). |
| Q3 | R-RE1 lists "sizes" for an artifact. Which sizes (archive bytes, unpacked bytes)? | `Artifact.Row` has no size member | Answered (Design Q74): one member `size`, the bytes of the `.tar.zst` asset (Registry R-AP49, R-RE1). |
| Q4 | What is the type of a time on the wire (R-RE26: seconds, or an ISO text)? | Proposal: seconds as a number | Answered (Design Q71): an integer, milliseconds since 1970-01-01 UTC, not seconds (Registry R-AP50). |
| Q5 | `nightly_id`: is a tag with a sha of other than 7 hex digits, an upper-case sha, or a date that does not exist (`2026-02-30`) an error? | The tests have no row for them. The code agent must not choose. | Answered (Design Q75): all 3 are `NotANightly`. Only 7 lower-case hex digits and a date that exists (Registry R-IK4, form table). |
| Q6 | When an answer or request misses a member that R-AP16 and R-AP17 do not call optional (`groups`, `artifacts`, `log_size`), is it an error or an empty value? | Today the derived parser gives `MissingRequiredField`, shown as `BadJson`. No test. | Answered (Design Q76): an error. 400 for a request, `BadJson` and exit 15 for an answer (Registry R-AP51, CLI R-E6). |
| Q7 | `Problem.decode` gives `BadJson` for an unknown `type`. Should a client keep an unknown type with its `detail` (a later registry)? | `Problem.kind_from_uri` gives `UnknownType`. The test only needs an error. | Answered (Design Q77): yes, keep the type text with `status`, `title`, `detail` (Registry R-AP52). |

## 104b. Items of `checked` and `repos` (from slice 106)

| Item | Text |
| --- | --- |
| N1 | `Closure.encode_checked`, `decode_checked`, `encode_repo`, `decode_repo` are public (stubs with `crash "todo"` in `Closure.roc`). They write one JSON object of R-AP29 or R-AP32. The route joins the items into the array. Members are in alphabetical order (the order of the derived codec), so the bytes of one state are fixed (R-AP24). `checked_at` and `successor` are `null` for none; a missing optional member also reads as none (R-AP51). A missing or null required member, a wrong type, or an unknown `state` is `BadJson`. |
| `Nullable` | Stays private. The 4 functions are enough for the read routes. A public `Nullable` would fix the helper of the code agent as API; the other records of later slices (`toolchains`, tokens) can add their own item functions. |
| N2 | The comments of `Closure.Checked` and `Closure.Repo` now say milliseconds (R-AP50). The test values of `state_at` are in ms. |
| Tests | 3 new `expect`s at the end of `WireTest.roc`: exact text and round trip of `Checked` (null and set `checked_at`); of `Repo` (3 states, null and set `successor`, exact text); BadJson cases. Rules: R-AP29, R-AP32, R-AP50, R-AP51, R-AP24. |
| Red | Total 38 tests on both nightlies: 35 pass, the 3 new ones fail with `todo`. |

## 10. Disputes (from the code agent)

| # | Dispute | State |
| --- | --- | --- |
| D1 | `WireTest.roc` expected `decode(encode(row))` to equal a row with unsorted `target_names` (`["x64linux", "wasm32"]`), but R-AP49 says that encode sorts them. | Resolved: accepted. The test row now has `["wasm32", "x64linux"]`. All 35 tests pass on both nightlies. |
| D2 | `WireTest.roc` removed `"version":null,` from a dep, but `version` is the last member of a dep (`"version":null}`), so nothing was removed. | Resolved: accepted. The test removes `,"version":null` and checks that the text changed. All 43 tests pass on both nightlies. |

## 11. Verify results

| Item | Result |
| --- | --- |
| `roc test packages/records/tests/w0.roc --no-cache`, nightly-2026-10-14-38a3029 | 34 passed, 1 failed (the dispute of section 10), 0 compiler errors |
| The same, nightly-2026-10-31-f7bef6b | 34 passed, 1 failed (the same), 0 compiler errors |
| `roc check packages/records/main.roc`, `roc fmt --check` of `packages/records/` | 0 errors on both nightlies |
| `scripts/test.sh check fmt l0 w0 selftest` | check, fmt, l0, selftest pass. w0 fails only on the disputed `expect`. l0 took 10.1 s against a budget of 10 s (the load of the machine; l0 skips `packages/records/`). |
| Code | Id 89, Code 96, Problem 114, Release 84, Artifact 97, Closure 201, Nullable 53 (new, private), main 13 lines. About 610 lines of code without comments and blank lines: over the 400 of TW19, because of the wire mirror records (section 3 codec choice). |
| Revert check (TW12) | Not done by this agent. |

Decisions: `Nullable(a)` is a private module (hand-written `parser_for` and `encoder_for` with `parse_null` and `encode_null`). It is `Nullable` and not `Nul` because `NUL` is a reserved file name on Windows (selftest TW29). Each wire record has a `Wire` mirror type (`Release.Wire`, `Artifact.Wire`, `Closure.*Wire`) with `to_wire` and `from_wire`. These are additions to the public items of the package.

## 104b. Verify results (code agent)

| Item | Result |
| --- | --- |
| `roc test packages/records/tests/w0.roc`, both nightlies | All 38 tests pass |
| `roc fmt --check packages/records/` | Clean on both nightlies |
| `scripts/test.sh w0` | The 38 records tests pass with both compilers. w0 is red only on `worker/tests/unit/ToolchainsTest.roc` (slices 106 and 109), as expected. |
| Code | `encode_checked`, `decode_checked`, `encode_repo`, `decode_repo` in `Closure.roc` use the private `Nullable`. |

## Revert check

Revert check (TW12) of the package `packages/records`. The script is `research/slice-104-revert-check/mutate.py`. The copy of the code is in `research/slice-104-revert-check/keep/`. The output of each run is in `research/slice-104-revert-check/out/`. Compiler: `cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc`. Command: `roc test packages/records/tests/w0.roc --no-cache`. The tests are `expect` with no name, so a test is shown as `file:line` of its `expect` block. After the last run, `cmp` shows that all 8 files of `packages/records/` are byte-identical to the copy.

| Id | Mutation | File:line | Caught by |
| --- | --- | --- | --- |
| M1 | A null is written as an absent member (`Nullable.write_opt` for `tag` of a release) | `Release.roc:49` | Not caught |
| M2 | A null is rejected on decode (the parser reads the inner value first) | `Nullable.roc:15` | `WireTest.roc:36` and others (11 tests fail) |
| M3 | `deps` are not sorted by alias | `Artifact.roc:61` | `WireTest.roc:135` |
| M4 | `target_names` are not sorted | `Artifact.roc:62` | `WireTest.roc:135` |
| M5 | An unknown `kind` is accepted as `app` | `Artifact.roc:71` | `WireTest.roc:142` |
| M6 | An upper-case sha is accepted in `nightly_id` | `Id.roc:54` | `IdTest.roc:42` |
| M7 | A 6-digit sha is accepted in `nightly_id` | `Id.roc:50` | `IdTest.roc:42` |
| M8 | 2026-02-30 is accepted (February has 30 days) | `Id.roc:70` | `IdTest.roc:42` |
| M9 | The target codes 11 to 20 are off by one | `Code.roc:79` | `CodeTest.roc:51` |
| M10 | An unknown problem `type` is rejected as `BadJson` (R-AP52) | `Problem.roc:89` | `ProblemTest.roc:71` |
| M11 | An unknown repo `state` is accepted as `active` (R-AP51) | `Closure.roc:125` | `WireTest.roc:185` |
| M12 | The `state_at` time is written times 1000 (R-AP50) | `Closure.roc:111` | `WireTest.roc:177` |
| M13 | A missing `title` of a problem reads as `"x"` and not `""` | `Problem.roc:96` | Not caught |

Result: 13 mutations, 11 caught, 2 not caught.

### Test gaps (not fixed)

| Id | Gap |
| --- | --- |
| M1 | No test checks the encoded text of a release with a null `tag`. A null must be written as `null` and not left out (R-AP51). The tests that run with `Err(None)` for `tag` do not fail when the member is absent. |
| M13 | No test checks that a problem body with no `title` (or no `detail`) reads as an empty text. The default value is not tested. |

## 104c. `error_digest` is text or null (Design Q114, Registry R-AP58)

| Item | Text |
| --- | --- |
| Types | `Closure.Run.error_digest` and `Closure.Nearest.error_digest` are `Try(Str, [None])`. `RunWire` and `NearestWire` take `Try(Nullable(Str), [Missing])`. The conversions in `Closure.roc` use `Nullable.read` and `Nullable.write` (the minimum to compile). |
| Wire | Text or `null`, a required member. The writer writes `null` for none. An empty text is a digest (R-AP58). |
| Tests | `WireTest.roc`: the answer values use `null` and `Ok("e1")`. Two new `expect`s at the end: encode and decode of a null, a text and an empty digest, in a run and in a nearest row (exact member text); a missing `error_digest` is `BadJson` in a run and in a nearest row. |
| Red | 42 tests, both nightlies: 41 pass, 1 fails (the missing member). The code agent must make it fail on a missing member. |
| Note for the code agent | `Try(Nullable(Str), [Missing])` accepts a missing member (R-AP51 reads it as none). The member is required here, so a missing one must be `BadJson`. One way: a wire type `Nullable(Str)` with no `Try` for these two fields (the derived parser then gives `MissingRequiredField`), with a `Nullable` helper to build and read it. The note applies to `Repo.successor` and `Checked.checked_at` too: today a test (104b) accepts a missing `successor`. The design (R-AP49, R-AP51) says that they are required. Q8 (answered): yes. Under R-AP51 a member that is required but may be null must be present: a missing one is `BadJson`, a null one is accepted. |

### Q8 answer: required nullable members

| Item | Text |
| --- | --- |
| Rule | Every "text or null" member of R-AP49 (release `tag`, `roc_version`, `repo`, `yank_reason`, `withdrawn`; artifact `platform_hash`, `roc_pin`; dep `series`, `version`), and `checked_at`, `successor`, `error_digest`: missing is `BadJson`, null is accepted. Only the optional members of R-AP16 (`series`, `range`, `compilers`, `from`, `to`) may be missing. |
| Tests changed | The 104b rows that accepted a missing `successor` or `checked_at` now send `null`. The release row without `roc_version` and the artifact row without `roc_pin` now send `null` or expect `BadJson`. |
| Tests added | In `WireTest.roc`: a missing member is `BadJson` for each of the 5 release members, 4 artifact and dep members, `checked_at` and `successor`. A new `expect` at the end checks the release members. |
| Red | 43 tests, both nightlies: 39 pass, 4 fail (artifact/dep, checked/repo, answer `error_digest`, release). They fail because the decoder accepts a missing member. The code agent changes the wire types to a required nullable form (see 104c note). |

## 104c. Verify results (code agent)

| Item | Result |
| --- | --- |
| Code | `Nullable.write` and `Nullable.read` now make a required nullable member (type `Nullable(a)`, no `Try`): a missing member is `BadJson`, `null` is none. `write_opt` and `read_opt` keep the optional form (`Try(Nullable(a), [Missing])`) for R-AP16 `series`, `range`, `compilers`, `from`, `to`. Used in `Release.Wire`, `Artifact.Wire`, `DepWire`, `RunWire`, `NearestWire`, `CheckedWire`, `RepoWire`. |
| `roc test packages/records/tests/w0.roc`, both nightlies | 42 passed, 1 failed (`WireTest.roc` line 142, dispute D2), 0 compiler errors |
| `roc fmt --check packages/records/` | Clean on both nightlies |
| Dispute D2 | In that `expect`, `replace_first("\"version\":null,", "")` never matches: `version` is the last member of a dep (alphabetical order), so it is followed by `}`. The text stays the same and the decode is Ok. The fix is in the test: remove `,"version":null` (or match `"version":null}`). I did not edit the test (TW18). |

## 104d. The request of `POST /v1/compat`, bot path (Design Q154, Registry R-AP10, R-AP66)

Written by the design agent on 2026-11-02 as the scope of a small slice. The test agent writes the stubs and the tests (red), then the code agent. It comes before the code of slice 115a (`docs/slices/115a-compat-post.md`). Model for the code: Sonnet medium. Size: about 60 lines of code, under the 400 of TW19.

| Item | Text |
| --- | --- |
| Why here | The request is an API type (Design R-PK7). The CLI (`tln probe --share`, the share queue of CLI 1, R-SH4) and the bot script send the same rows, so the type must not live only in `worker/`. A copy of `Nullable.roc` in `worker/lib/` would drift. `Nullable` stays private (as in 104b): `records` gives item functions, not the helper. `records` is a Talon package, not a generic package, so R-GP1 to R-GP7 do not apply, and the Worker already uses it by relative path. |
| File | `packages/records/Compat.roc`, exposed in `main.roc` (the `package` list gets `Compat`). The comment of `main.roc` ("The records of `compat.db` are not here") stays true: these are wire types. |
| Types | `Compat.Row : { hash : Str, nightly : Str, target : Str, result : Str, error_digest : Try(Str, [None]) }`. `Compat.Sweep : { nightly : Str, target : Str, upto_log_index : U64 }`. `Compat.Post : { rows : List(Compat.Row), sweep : Try(Compat.Sweep, [None]) }`. All ids and codes are text as sent: the checks of the values (R-AP66 check 6) come after the row limit (check 5), so the Worker makes them, not the decoder. |
| Wire types | `Compat.RowWire` with `error_digest : Nullable(Str)` (required, R-AP51, as 104c) and `source : Try(Nullable(Str), [Missing])`. `Compat.SweepWire`. `Compat.PostWire` with `rows : List(Compat.RowWire)`, `sweep : Try(Nullable(Compat.SweepWire), [Missing])` and `source : Try(Nullable(Str), [Missing])`. The `source` members exist only to find a `source` member. |
| Functions | `Compat.encode_post : Compat.Post -> Str`. `Compat.decode_post : Str -> Try(Compat.Post, [BadJson(Str)])`. |
| `encode_post` | Members in alphabetical order (the derived codec). `error_digest` is always written, `null` for none. `sweep` is left out for `Err(None)` (optional, R-AP51). It never writes `source`. |
| `decode_post` | `rows` is required (missing or `null` is `BadJson`). `sweep` missing or `null` is `Err(None)`. In a row, `hash`, `nightly`, `target`, `result` and `error_digest` are required: a missing one is `BadJson` and a `null` `error_digest` is `Err(None)`. An empty `error_digest` text is `Ok("")`. A `source` member, in the body or in a row, with any value (a text, `null`, a number, an object) or with an escaped key, is `BadJson`. A text that holds the word `source` as a value is not a member. `upto_log_index` that is negative or not an integer is `BadJson`. An unknown member (for example `talon_version`) is ignored (R-AP44). The `BadJson` text names the member. |
| Out of scope | The user hint row and `talon_version` (slice 116 adds its own types to `Compat.roc`). The `result` set and the id forms (the Worker checks them). The answer `{written}` (a one-member body, written by `Compat.written_body` in the Worker). |
| Tests | `packages/records/tests/WireTest.roc` (or a new `CompatTest.roc` in `w0.roc`): (1) exact text and round trip of a `Post` with rows with `null`, text and empty digests, and with and with no sweep; (2) the decode of a body with no sweep, with `"sweep":null`, with a sweep; (3) a missing `rows`, `"rows":null`, a missing `error_digest`, a missing `hash`, a `null` `hash`: `BadJson`; (4) `source` as a text, `null`, a number, an object, an escaped key, in the body and in a row: `BadJson` (12 cases); (5) `"error_digest":"source"` and a digest that holds `\"source\":` are `Ok`; (6) a negative and a fractional `upto_log_index`: `BadJson`; (7) an unknown member is ignored. Rules in the test names: R-AP10, R-AP44, R-AP51, R-AP58, R-MX5, R-PK7. Both nightlies (R-PK7). |
| Revert checks (TW12) | `source` found by a text search; `error_digest` as an optional member (a missing one accepted); `null` digest written as `""`; `sweep` written as `null` (instead of left out). |
| Effect on 115a | `Compat.parse_post` calls `Compat.decode_post` after the UTF-8 and size checks, maps `BadJson(text)` to a 400 whose `detail` names the member, then does the row limit and the value checks. The W0 tests of 115a (`parse_post`) do not change. |

### 104d. Tests and results (test agent, 2026-11-02)

| Item | Text |
| --- | --- |
| Files | `packages/records/Compat.roc` (types, wire types, stubs with `crash "todo"`), exposed in `main.roc`. `packages/records/tests/CompatTest.roc`, imported by `w0.roc`. |
| Tests | 7 `expect`s: exact text and round trip (null, text, empty digest; with and with no sweep); decode of no sweep, `"sweep":null`, a sweep; 9 bad bodies (missing or null `rows`, missing `error_digest`, missing or null `hash`, missing `nightly`, `target`, `result`, not JSON); 12 `source` cases (5 values in the body, 5 in a row, 2 escaped keys); `source` as a value and a digest that holds `"source":`; bad `upto_log_index` (-1, 1.5, text, null); an unknown member. Rules: R-AP10, R-AP44, R-AP51, R-AP58, R-AP66, R-MX5, R-PK7. |
| Red | 50 tests on both nightlies, 43 pass, 7 fail with `todo`. `roc fmt --check` clean on both. |
| Private reference | `research/slice-104d-revert/reference/Compat.roc` (the full code, 50 tests pass on both nightlies). It finds a `source` member with the wire field `source : Try(Nullable(Str), [Missing])` (a derived parse, so an escaped key and a number or object value work). |
| Revert checks | `research/slice-104d-revert/mutate.py`, against the reference: R1 `source` by a text search (also removes the row check), R2 `error_digest` optional, R3 null digest written as `""`, R4 `sweep` written as `null`. All 4 caught. The reference is restored byte for byte. |

### 104d. Code (code agent)

| Item | Result |
| --- | --- |
| Code | `Compat.encode_post` and `Compat.decode_post` in `packages/records/Compat.roc` (50 lines, 31 of code). `source` is found with the typed wire field (`Try(Nullable(Str), [Missing])`): any present value is `BadJson`. The wire value of `encode_post` is typed as `Compat.PostWire`, so the `Err(Missing)` members are left out. |
| `roc test packages/records/tests/w0.roc`, both nightlies | All 50 pass |
| `roc fmt --check packages/records/` | Clean on both nightlies |

## 104f. Publish and hint bodies (Design Q190, Q191, Registry R-AP71, R-AP72; CLI plan G-C3, G-C4)

Phase: P2. Status: review (tests red, 2026-11-02). Model for the code: Sonnet high. About 110 lines in `packages/records/Compat.roc`. It adds to the module of 104d; `Compat.Post` does not change.

| Type | Members | Functions |
| --- | --- | --- |
| `Compat.Fact` | `nightly`, `target`, `result`, `error_digest : Try(Str, [None])` (no `hash`) | |
| `Compat.Publish` | `url`, `compat : Try(List(Compat.Fact), [None])` (missing or null: `Err(None)`) | `encode_publish`, `decode_publish` |
| `Compat.HintRow` | `hash`, `nightly`, `target`, `result` (no `error_digest`) | |
| `Compat.HintPost` | `talon_version`, `rows` (both required) | `encode_hint_post`, `decode_hint_post` |
| `Compat.HintSkip` | `row : U64`, `reason : Str` | |
| `Compat.HintAnswer` | `written`, `first`, `skipped` | `encode_hint_answer`, `decode_hint_answer` |
| `Compat.Written` | `written` | `encode_written`, `decode_written` |

| Rule | Effect |
| --- | --- |
| R-AP71, R-MX5, Q176 | A fact with a member `hash` or `source` (any value, `null`, an escaped key) is `BadJson`. A fact member that is missing is `BadJson`. `compat` is left out when `Err(None)`; `Ok([])` is written as `[]`. The limit of 500 and the values are the Worker's checks, not the decoder's. |
| R-AP72, R-AP70 row 6 | `decode_hint_post` refuses `error_digest` in a row, `sweep`, `source` in the body or in a row, with any value. `encode_hint_post` writes `rows`, `talon_version`. |
| R-AP72, 116a section 6 | `encode_hint_answer` writes `written`, `first`, `skipped` (always) and an item `row`, `reason`: not the alphabetical order of the derived codec, so the encoder builds the text (the reason with `Json.to_str`). The bytes equal `Hints.answer_body` of the W0 case of 116a (same vector in the test). The decoder ignores the order, unknown members and any reason text. |

| Tests (`tests/CompatHintTest.roc`, imported by `w0.roc`) | Rules |
| --- | --- |
| 8 `expect`s: publish exact text and round trip (none, empty list, three facts); publish decode (missing or null `compat`, 9 bad bodies, `hash` and `source` as values are fine); fact members `hash`, `source` (10 forms); hint post exact text and round trip; hint post decode (14 bad bodies, unknown member ignored); answer exact bytes (116a vector, empty, quoted reason) and round trip; answer decode (reordered, unknown reason, 9 bad texts); `Written` | R-AP10, R-AP44, R-AP51, R-AP58, R-AP70, R-AP71, R-AP72, R-CT2, R-CT14, R-MX5, R-PK7 |

Red: 58 tests, both nightlies: 50 pass, 8 fail with `todo`. `roc fmt --check` is clean.

Private reference: `research/slice-104f-revert/reference/Compat.roc` (58 tests pass on both nightlies). Revert checks (`research/slice-104f-revert/mutate.py`): A answer members alphabetical, B `error_digest` accepted in a hint row, C item order `reason`, `row`, D `hash` accepted in a fact, E `compat:null` written for none, F `skipped` left out when empty, G `sweep` accepted in a hint post. All 7 caught. The reference is restored.

## 104e. Answer types (Design Q192, Registry R-AP73; CLI plan G-C5)

Phase: P2. Status: review (tests red, 2026-11-02). Model for the code: Sonnet high. Step 1 is this slice (records only). Step 2 (the Worker calls the encoders and drops `Reads.releases_body`, `page_body`, `artifact_body`, `Toolchains.row_text`, `put_body`, `page_body`, `Shorts.matches_body`, `search_body`) is a Worker slice. The W0 and W2 tests of 106, 107 and 109 do not change: they prove that the wire does not change. `Account` has no Worker code until 117. R-AP4, R-AP39, R-AP40 are not here.

| Module | Types | Functions | Bytes of today |
| --- | --- | --- | --- |
| `Index` | `Releases` (`releases`, `checked` item or null, `repos`), `Page` (`releases`, `repos`), `Detail` (`artifact`, `releases`, `repos`) | `encode_` and `decode_` of `releases`, `page`, `detail` | `Reads.releases_body`, `page_body`, `artifact_body`. The members in the order of the types (`Releases` is not alphabetical), no white space. The encoder writes the lists in the order given: the caller sorts (R-AP53). |
| `Toolchain` | `Row`, `Page` (`toolchains`, `more`), `Put` (`toolchains`) | `encode_row`, `decode_row`, `encode_page`, `decode_page`, `encode_put`, `decode_put` | `Toolchains.row_text`, `page_body`, `put_body`. A row: `tag`, `target`, `asset_name`, `sha256`, `published_at`, `log_index` (not alphabetical). |
| `Short` | `State`, `Item`, `Entry`, `Matches`, `Hit`, `Packages` | `encode_matches`, `decode_matches`, `encode_packages`, `decode_packages` | `Shorts.matches_body`, `search_body`. Alphabetical members; `moved_from` left out for none. |
| `Account` | `Who`, `Tracker`, `Token`, `Login` | `encode_` and `decode_` of `tracker`, `token`, `login` | None. Proposal (TW24): alphabetical members, the two tracker times required and null for an account with no row. |

| Decision | Text |
| --- | --- |
| Reserved word | `Short.Packages` has the field `found`, because `packages` is a reserved word in Roc. The wire member stays `packages` (R-SN6). The codec renames it. The reference parses into a `Dict(Str, List(HitWire))` and reads the key; that parse ignores an unknown member only when its value is a list of hits. No test needs more. A hand-written parser can ignore every unknown member. |
| Decoders | R-AP51: a required member that is missing or `null` is `BadJson` (`checked` is required and may be `null`; `moved_from` is optional). An unknown member is ignored. A bad nested record (a release, a repo) is `BadJson`. |
| Nested codecs | `Index` reuses `Release`, `Artifact`, `Closure.encode_repo` and `encode_checked`. The code agent may add a public helper for the wire form of a repo or a checked item to `Closure`; `Nullable` stays private. |

| Tests (`tests/AnswerTest.roc`, imported by `w0.roc`) | Rules |
| --- | --- |
| 9 `expect`s. The fixtures (30 bodies, made by `research/slice-104e-revert/gen.py` from `worker/tests/cases/*/expect/responses.jsonl`): `reads/ap1-body-etag-cache`, `ap13-group-series-after`, `ap2-artifact`, `toolchains/get-query`, `pu-new-tag`, `oidc/tp3-jwt-strict`, `shorts/sn1-table`, `ap33-moved`, `sn5-search`, and the page bodies cut from the ap2 bodies (R-AP14 has a JSON compare in W2, not a byte compare). Each fixture is decoded and encoded: the same bytes. Then exact text of small values, `null` and empty lists, unknown member ignored, missing or null member, bad nested value, bad state, negative or fractional numbers, the account types | R-AP73, R-AP53, R-AP54, R-AP1, R-AP2, R-AP5, R-AP6, R-AP7, R-AP13, R-AP14, R-AP33, R-AP35, R-AP37, R-AP44, R-AP49, R-AP50, R-AP51, R-SN6, R-CT10, R-PK7 |

Red: 67 tests on both nightlies (50 old, 8 of 104f, 9 of 104e): 50 pass, 17 fail with `todo`. `roc fmt --check` is clean.

Private reference: `research/slice-104e-revert/reference/` (4 files, 261 lines; 67 tests pass with it and the 104f reference). Stubs are copied in `research/slice-104e-revert/stubs/`. Revert checks (`research/slice-104e-revert/mutate.py`): M1 `checked` before `releases`, M2 toolchain row in alphabetical order, M3 `moved_from` written as `null`, M4 `checked` none written as `[]`, M5 tracker `last_time` optional, M6 unknown state read as `active`, M7 page members swapped. All 7 caught. Files restored.

### 104f and 104e. Code (code agent)

| Item | Result |
| --- | --- |
| 104f | `Compat.roc`: `encode_publish`, `decode_publish`, `encode_hint_post`, `decode_hint_post`, `encode_hint_answer` (text built by hand, the order `written`, `first`, `skipped`, item `row`, `reason`), `decode_hint_answer`, `encode_written`, `decode_written`. The refused members (`hash`, `source`, `error_digest`, `sweep`) are found with typed wire fields `Try(Nullable(Str), [Missing])`. The wire values of the encoders are typed, so the `Err(Missing)` members are left out. |
| 104e | `Index`, `Toolchain`, `Short`, `Account` filled. `Index` writes the text from `Release.encode`, `Artifact.encode`, `Closure.encode_repo` and `Closure.encode_checked`; it decodes with the wire records. `Toolchain` and `Account` use the derived codec (the row is built by hand, because its order is not alphabetical). `Short.Packages`: the encoder writes the member `packages`; the decoder parses a `Dict(Str, List(HitWire))` and reads `packages`. |
| New public items in `Closure` | `checked_to_wire`, `checked_from_wire`, `repo_to_wire`, `repo_from_wire` (the wire forms of one item; `Nullable` stays private). |
| Compiler notes | `join_with` is `Str.join_with(list, sep)`, not a method of a list (the wrong call made the 10-14 compiler crash with SIGSEGV). A record `{ found }` with one pun is a block in Roc: write `{ found: found }`. |
| Results | `roc test packages/records/tests/w0.roc`: all 67 pass on 2026-10-14-38a3029 and on 2026-10-31-f7bef6b. `roc fmt --check packages/records/` clean on both. |

## 104g. Optional problem members (Registry R-AP74 row 2, R-AP52; Design Q250, RFC 9457 3.1)

Phase: P2. Status: review (tests red, 2026-11-02). Model for the code: Sonnet medium. About 20 lines in `Problem.roc`.

| Item | Text |
| --- | --- |
| Fault | `Problem.decode` types the optional members as `Try(_, [Missing])`. A `null` or a wrong type (a number, an object, a list, a boolean) makes the derived parse fail, so the whole body is `BadJson` and `tln` exits 15 where R-AP74 row 2 says exit 1 (`minimum`). |
| Rule (Design Q250) | Each optional member, `title`, `detail`, `issues_url`, `minimum`, `field` and `limit`, is read as missing when it is `null` or has a wrong type. A member of the right type is kept. A missing `title` or `detail` is `""`. A bad `field` or a bad `limit` gives `Extra` `None` (they are read together). `type` and `status` stay strict: a missing, null or wrong-type `type` or `status`, or a body that is not JSON, is `BadJson` (R-AP52). |
| Test A | `tests/ProblemTest.roc`: 7 wrong forms for each of `title`, `detail`, `issues_url`, `minimum`, `field` (number, fraction, negative, boolean, null, object, list) and 7 for `limit` decode with an empty `title`, `detail` and `extra: None`; a wrong member keeps its valid neighbours (3 mixed bodies); the `unsupported-client` case of R-AP74 (number, object, null, list, missing: no minimum; text: kept). |
| Test B | `type` and `status` strict: 10 bodies (missing, null, number, object, text for `status`, negative, fraction, out of range) are `BadJson`, also with a `minimum` that is not text. |
| Red | 70 tests on both nightlies: 68 pass, 2 fail (tests A and the R-AP74 case: wrong value, `BadJson`). Test B passes today and stays as a guard. `roc fmt --check` is clean. |
| Reference | `research/slice-104g-revert/reference/Problem.roc`: `type` and `status` from a strict record, and each optional member from its own one-member parse (a failed parse is missing). 70 tests pass with it on both nightlies. |
| Revert checks | `research/slice-104g-revert/mutate.py`: M1 a `minimum` of a wrong type is `BadJson` (the original fault), M2 a text `minimum` is dropped, M3 a `title` of a wrong type is `BadJson`, M4 `field` and `limit` are not read together, M5 an `issues_url` of a wrong type is `BadJson`. All 5 caught. The package is restored. |

### 104g. Code (code agent)

| Item | Result |
| --- | --- |
| Code | `Problem.decode` reads `type` and `status` with a strict record (`Problem.Head`), and each optional member with its own one-member parse (`TitleOnly`, `DetailOnly`, `UrlOnly`, `MinimumOnly`, `FieldOnly`, `LimitOnly`). A failed parse is a missing member. `field` and `limit` are read together. `Problem.Wire` stays for the encoder. |
| Results | `roc test packages/records/tests/w0.roc`: all 70 pass on 2026-10-14-38a3029 and on 2026-10-31-f7bef6b. `roc fmt --check packages/records/` clean on both. |

## 104h. `size` in `Toolchain.Row` (Design Q340, Registry R-RE4, R-AP80)

Phase: P2. Status: review (tests red, 2026-11-02). Model for the code: Sonnet medium. About 3 lines in `Toolchain.roc`. The CLI slice 204 and the Worker slice 109b wait for it.

| Item | Text |
| --- | --- |
| Type | `Toolchain.Row` gets `size : U64` after `sha256` (done in the package, with the comment of the type). The members of a row on the wire: `tag`, `target`, `asset_name`, `sha256`, `size`, `published_at`, `log_index`. No `url` member: the client builds `https://github.com/roc-lang/nightlies/releases/download/<tag>/<asset_name>`. |
| Code | `encode_row` writes `"size":<n>` after `sha256`. `decode_row`, `decode_page`, `decode_put` require `size` (the derived parse does, once the type has it). Whether `size` is above 0 is the Worker's check (R-AP80), not the decoder's. |
| Fixtures | The 104e `AnswerTest.roc` toolchain fixtures (`toolchain_page_bodies`, `toolchain_put_bodies`) are the W2 bodies of 109 with `"size":1000000+log_index` inserted after `sha256` (the R-RE4 form; the Worker does not send `size` before 109b). `research/slice-104e-revert/gen.py` does the insert. The hand-written row tests carry `size`. |
| Tests | In `tests/AnswerTest.roc`: the fixtures and the row, page and put texts (exact bytes with `size` in place); one new `expect`: a missing, `null`, text, negative, fractional, object, list or boolean `size` is `BadJson` in a row, a page and a put; an unknown `url` is ignored; the row has no `url`. Rules: R-AP80, R-AP51, R-AP73, R-PK7. |
| Red | 71 tests on both nightlies: 69 pass, 2 fail (the two `expect`s that check the encoder bytes: the text has no `size`). The decode cases already pass because the derived parser requires the new field; they stay as guards. |
| Reference | `research/slice-104h-revert/reference/Toolchain.roc` (71 tests pass on both nightlies). Revert checks (`research/slice-104h-revert/mutate.py`): M1 `size` after `published_at`, M2 `size` written as text, M3 `size` written from `log_index`, M4 a `url` member written. All 4 caught. The package file is restored. |

### 104h. Code (code agent)

| Item | Result |
| --- | --- |
| Code | `Toolchain.encode_row` writes `"size":<n>` after `sha256`. `encode_page` and `encode_put` use `encode_row`. The decoder is derived and reads `size`. |
| Results | `roc test packages/records/tests/w0.roc`: all 71 pass on 2026-10-14-38a3029 and on 2026-10-31-f7bef6b. `roc fmt --check` clean on both. |
