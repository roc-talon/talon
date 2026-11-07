# Slice 227: one `read_answer` site in the Worker

Phase: P2 (registry). Status: verify. Code only, no tests changed (TW18).

## Why

`research/bigfn/README.md` (section 2, "Second cause"): the code of the problem answer (`problem_response`, `Problem.to_json`) was inlined at each of the 38 `read_answer(...)` and `Err(Refuse(..))` sites. The entry function of `worker/app.wasm` (wasm function 185, 1,246,912 bytes) held 228 copies of the title table. This slice is change B of that report. Change A (our `event!` handles `Fetch`) is not done: platform 0.0.8 fixes its cause (the or-pattern in `Worker.event!`).

## Scope

| Item | State |
| --- | --- |
| Files | `worker/main.roc` only. No `worker/lib` module changes: the type `ReadRoutes.Error` already exists and `read_answer` already takes it. |
| Rules | No rule changes. |
| Responses | No response changes: status, headers and body stay the same, byte for byte. |
| Not changed | `event!`, `Worker.new`, `worker/app.wasm`, `worker/.roc-cfw/`, all tests and fixtures. |
| Measure | Code section size and the 3 largest functions of `app.wasm`. Title-table copies in the largest function (`research/bigfn/titles.mjs`). |

## Plan

| Step | Change in `worker/main.roc` |
| --- | --- |
| 1 | `run!` returns `Try(Response, ReadRoutes.Error)`. Its arms call the route handler and no longer call `read_answer`. |
| 2 | The `PutToolchain` arm gives `Err(Refuse(problem))` when `Auth.bot!` fails (it gave `Ok(problem_response(problem))`). |
| 3 | `handle!` does `match read_answer(run!(id, req))` once. Its `Err(_)` arm (the `Internal` answer for a `Fault`) stays. |

Why the answers do not change: before, each arm gave `read_answer(r)` and `handle!` mapped the `Err(Fault)` to the `Internal` problem. Now `handle!` applies the same `read_answer` to the same `r`, then the same match. The `PutToolchain` bot failure goes by `Refuse(problem)` to `problem_response(problem)`, the same call as before.

## Results

### Checks

`scripts/test.sh check fmt w0 wbuild w2 l3w`: all pass.

| Step | Result | Seconds | Budget |
| --- | --- | --- | --- |
| check | pass | 3.1 | 10 |
| fmt | pass | 0.4 | 5 |
| w0 | pass | 11.2 | 10 (WARN) |
| wbuild | pass | 181.8 | 90 (WARN) |
| w2 | pass | 35.1 | 45 |
| l3w | pass | 4.3 | 15 |

The budget warnings are the cost of the speed build and a loaded machine (TW26). They are not from this change.

### Size

New build: `.work/worker/1830131956-564510/app.wasm`. Base: `worker/app.wasm`. Tool: `research/deploy-121/startup/funcsizes.mjs`.

| Item | Base | Slice 227 | Change |
| --- | --- | --- | --- |
| Code section (bytes) | 6,270,963 | 5,609,619 | -661,344 |
| Largest function, entry (bytes) | 1,246,912 | 585,568 | -661,344 |
| 2nd largest (bytes) | 242,991 | 242,991 | 0 |
| 3rd largest (bytes) | 167,086 | 167,086 | 0 |
| Title-table copies in the entry function | 228 | 12 | -216 |

The change of the entry function equals the change of the code section: no other function changed.

The 12 copies are 6 copies of the arm of `Worker.event!` (the or-pattern, change A and platform 0.0.8) times 2 answer sites (`fetch!` for `Route.decide`, and `handle!`). With platform 0.0.8 the report expects the entry function at about 178 KB (the build `bpone` of the report, A and B).

### Revert check (TW12)

Mutants: `research/slice-227-revert/mutate.sh`. Each is a copy of `worker/` with one `sed` change, a private build, and `worker/tests/run.mjs` on it (with the archive test app, so the base run is 189 of 189). The lists of failing cases are in `research/slice-227-revert/f-<mutant>.txt`.

| Mutant | Change | w2 result (189 cases) | First cases that fail |
| --- | --- | --- | --- |
| base | none | 189 passed, 0 failed | none |
| m1 | `PutToolchain`: a failed bot check gives `Err(Fault("x"))` | 8 failed | `oidc/tp3-*`, `oidc/tp7-bot-token-pass` (the bot check) |
| m2 | `read_answer`: each `Refuse` gives the problem `Internal` | 55 failed | `account/ap45-write-routes`, `account/ct11-login-limit`, ... |
| m3 | `PostWebhook` runs `LoginRoutes.get_me!` | 4 failed | `webhook/ap12-empty-secret`, `webhook/ap12-no-secret`, `webhook/ap12-signature`, `webhook/pu11-events` |
| m4 | the `Internal` detail text in `handle!` changed | 2 failed | `router/r-ap21-handler-err-internal`, `githubtoken/pu25-missing-key` |

4 of 4 caught. The mutant build dirs were deleted after the run (`mutate.sh` makes them again).

## Close

| Item | State |
| --- | --- |
| Diff | `worker/main.roc`: `run!` type and arms, `handle!` match, one doc comment. About 40 lines, no new function. |
| Responses | Same: w2 (189 cases) and l3w pass. |
| `worker/app.wasm`, `worker/.roc-cfw/` | Not changed. The prod build is a separate step (the human). |
| Next | Change A and platform 0.0.8: the entry function is expected at about 178 KB (`research/bigfn/README.md`, section 3). |
