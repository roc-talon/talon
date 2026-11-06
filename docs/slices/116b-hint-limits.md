# 116b Client version and the rate limit of hints

Phase: P2. Status: review (scope and test agent, 2026-11-02). Model for the code: Sonnet high. Part 2 of slice 116 (split, TW19). 116a (`116a-user-hints.md`) is the hint path. 116b is two things that 116a does not need to be correct: the check of `User-Agent: tln/<version>` against the settings `MIN_TLN` and `MIN_TLN_WRITE` (R-AP45, R-AP48 row 3), and the rate limit per address for user hints (R-CT11, binding `RL_HINTS`).

This file is the only link between the test agent and the code agent (TW18). The code agent does not read `research/slice-116-revert/reference/` (the private reference).

## 1. Scope

| Part | Who | State |
| --- | --- | --- |
| `worker/lib/Client.roc`: `is_write`, `check`, `refusal_json`, `rate_key`, `rate_problem`, `limit_retry_after`. Every body is `crash "todo"` (except `limit_retry_after`) | Test agent (signatures), code agent (bodies) | Stubs |
| `worker/HintRoutes.roc`: step 4 of the flow (the rate limit) | Code agent | In the doc comment of the stub |
| `worker/main.roc`: the client check before the route, the binding `RL_HINTS` in `Worker.new` | Code agent | Missing (a reference is private) |
| `worker/wrangler.toml`: `[[ratelimits]]` `RL_HINTS` (30 a minute), `[vars]` `MIN_TLN` and `MIN_TLN_WRITE` (empty) | Code agent | Missing. `roc-cfw sync --check` needs the binding in both |
| `worker/tests/run.mjs`: the case file `ratelimits.json`; every case gets `RL_HINTS` (limit 1000) when it has no file | Test agent | Done (a copy of the file before is in `research/slice-116-revert/before/`) |
| `worker/lib/main.roc` (exposes `Client`), `w0.roc` | Test agent | Done |
| Tests: section 5 | Test agent | Red |

Size: about 170 code lines for the reference (section 1 of 116a).

## 2. Rules

| Rule | Text (short) | Checked by |
| --- | --- | --- |
| R-AP45 | `User-Agent: tln/<v>` with `v` lower than the setting is 400 `unsupported-client` with the member `minimum`. `MIN_TLN_WRITE` covers the write routes, `MIN_TLN` all routes. Another agent is not checked. Settings are empty by default | W0 `check`, `is_write`, `refusal_json`. W2 `ap45-client-version` |
| R-AP48 row 3 | The client version comes after the path (row 1) and the method (row 2), before the size (row 4) and the media type (row 5) | W2 `ap45-client-version` |
| R-CT11 | At most 30 requests a minute for each IPv4 address or IPv6 /64, with the rate limiting binding. Over the limit: 429 `rate-limited` with `Retry-After` (R-AP25) | W0 `rate_key`, `rate_problem`. W2 `ct11-rate-limit` |
| R-MX6 | User hints have the rate limit of R-CT11 | W2 `ct11-rate-limit` |
| R-WH14 | The names of the settings and of the binding (proposals) | W2 |

## 3. What the code agent writes

### 3.1 Files

| File | What |
| --- | --- |
| `worker/lib/Client.roc` | The bodies. The doc comments are the rules |
| `worker/HintRoutes.roc` | Step 4: `RateLimit.binding("RL_HINTS")`, `limit!` with `Client.rate_key(req.header("cf-connecting-ip"))`. `Err(RateLimited)` is the 429 `Client.rate_problem()` with `Retry-After: 60`, no D1 call. `Err(Infra)` is a fault |
| `worker/main.roc` | Before `Route.decide` gives the answer, ask `Route.decide` once with `has_body: Bool.False`. When it gives `Handle(id)` (the path is a route and the method is served), read `MIN_TLN` and `MIN_TLN_WRITE` with `Env.var!` (a missing variable is an empty text), call `Client.check` with `Client.is_write(id)`, and for `Err` answer 400 with `Client.refusal_json` and `application/problem+json`. A request that is a 404 or a 405 is not checked (rows 1 and 2 come first). Then the old flow. Add `HintRoutes.limiter.declare()` (or the same call for the binding) to `bindings` |

The way in `main.roc` is a proposal: any code that gives the order of R-AP48 and passes `ap45-client-version` is good.

### 3.2 The settings and the binding (R-WH14, proposals)

| Name | Kind | Use |
| --- | --- | --- |
| `MIN_TLN`, `MIN_TLN_WRITE` | Setting (`[vars]`), empty by default | R-AP45. A missing variable is the same as an empty one |
| `RL_HINTS` | Rate limit binding, `limit` 30, `period` 60 | R-CT11 |

## 4. Edits of files that other slices own

| File | Edit |
| --- | --- |
| `worker/main.roc`, `worker/wrangler.toml` | The code agent (section 3.1). Re-read the file before the edit: the ingest slice (112) changes the same files |
| `worker/tests/run.mjs` | Done by the test agent |

## 5. Tests

| Layer | Case | Rules |
| --- | --- | --- |
| W0 | `worker/tests/unit/ClientTest.roc`, 4 `expect`s: `check` (20 rows: write or read route, the equal version, `0.10.0` against `0.5.0`, a pre-release, two settings, empty and bad settings, other agents); the `detail`, `refusal_json` and `is_write` (13 routes); `rate_key` (22 rows: IPv4, IPv6 forms and one /64 in the text of Q168 such as `2001:db8:0:0::/64`, a mapped address, bad texts); `check` also reads the first product of the `User-Agent` (Q184: `tln/0.4.1 (linux)` is checked; `curl/8 tln/0.4.1`, `TLN/0.4.1`, `tln/dev` are not); `rate_problem` and `limit_retry_after` | R-AP45, R-AP21, R-CT11, R-AP25 |
| W2 | `hints/ap45-client-version`: settings `MIN_TLN_WRITE` 0.5.0, `MIN_TLN` 0.3.0. 12 requests: a hint from `tln/0.4.1` is 400 with `minimum`; `tln/0.5.0` (equal) and `tln/0.10.0` pass; `curl` and the runner agent pass; a read from `tln/0.4.1` passes (1 D1 call), from `tln/0.2.9` is 400 with `minimum` 0.3.0; the client check comes before the media type and the size; a 405 and a 404 come before it; a request with a token is checked before the token; `tln/0.4.1 (linux)` is refused, `tln/0.5.0 (linux)` passes (Q184) | R-AP45, R-AP48, R-AP21 |
| W2 | `hints/ct11-rate-limit`: `ratelimits.json` limit 3. IPv4: 3 pass, the 4th is 429 with `Retry-After` 60 and 0 D1 calls; another address passes; a mapped IPv6 address shares the IPv4 budget. IPv6: 3 addresses of one /64 pass, others of that /64 (also in capitals) are 429, another /64 passes. Requests that fail the id check or the decode do not use the budget (R-AP70, Q186). A request that gets to the limit counts whatever its answer: two empty bodies and a 400 of the read batch use 3, the 4th is 429 (Q186). No address header: one shared key `unknown` (Q185) | R-CT11, R-AP25, R-MX6 |

### 5.1 Red results (2026-11-02, the stubs)

| Step | Result |
| --- | --- |
| W0 | `ClientTest` 4 `expect`s, 0 pass (`todo`) |
| W2 | `ap45-client-version` and `ct11-rate-limit` fail (500 `trap unreachable`, and 200 for a request that must be 400) |

### 5.2 Private reference and revert check

With the reference: W0 4 of 4, W2 2 of 2.

| Mutation | What | Caught by |
| --- | --- | --- |
| `client-equal-refused` | A version equal to the minimum is refused | W0 `check` |
| `ipv6-full` | The key of an IPv6 client is the whole address | W0 `rate_key` |
| `client-after-media` | The client check uses the real body flag, so the media type comes first | W2 `ap45-client-version` (request 8) |
| `limit-first` | The rate limit before the id check | W2 `ct11-rate-limit` |
| `ua-whole` (new, Q184) | The whole `User-Agent` is the product | W0 `check` |

## 6. Output (proposed, TW24)

| Item | Proposal |
| --- | --- |
| 400 `unsupported-client` | The members of the problem and `minimum` (a text). `detail`: `tln <v> is older than the minimum version <minimum> that this registry accepts: update tln` |
| 429 of the limit | type `rate-limited`, `detail`: `too many user hint requests from this address: try again in a minute`, header `Retry-After: 60` |
| Key of the limit | The text of Q168 (`Client.rate_key`, shared with slice 112b): IPv4 as is, IPv6 as `2001:db8:0:0::/64`. Not visible to a client |

## 7. Requests to other slices

| # | To | Request |
| --- | --- | --- |
| RQ1 | Slice 112 (ingest) | `RL_INGEST` needs its own entry in `ratelimits.json` of its cases. Until then every case gets `RL_HINTS` only. A second binding in `run.mjs` is a change of `ratelimitsOf` |
| RQ2 | The manager | `docs/registry/PLAN.md` row 116 becomes two rows (116a, 116b) |

## 8. Out of scope

| Item | Reason |
| --- | --- |
| The limits of `POST /v1/tokens` and `DELETE /v1/contributors/me` (10 a minute) | Slice 117 |
| The ingest limits (R-PU34) | Slice 112b |
| The count of the Miniflare window (a limit that resets after 60 s) | The cases are shorter than the period |

## 9. Questions (all settled: see section 12; the marks `pending` are removed from the tests)

| Id | Question | Proposal | Pinned by |
| --- | --- | --- | --- |
| Q116-b1 | R-AP45: `MIN_TLN_WRITE` "write routes of R-AP41". Which routes does the Worker count? | `POST /v1/compat`, `POST /v1/releases` and `PUT /v1/toolchains/{tag}` (and the later write routes: tokens, delete). `POST /v1/closure` is a read | W0 `is_write` |
| Q116-b2 | A `tln/<v>` that is no semver, or a setting that is no semver? | Not checked (the request passes) | W0 `check` |
| Q116-b3 | R-CT11: a request with no `cf-connecting-ip` (not possible on the edge)? | One shared key `unknown` | W0 `rate_key`, W2 `ct11-rate-limit` |
| Q116-b4 | R-AP25 `Retry-After` of the limit of the binding? | 60 seconds, the period of the binding | W0 `limit_retry_after`, W2 `ct11-rate-limit` |
| Q116-b5 | Where is the rate limit in the order of the checks? | After the id check and the decode of the body (a refused request costs no budget), before every D1 call | W2 `ct11-rate-limit` (5 refused requests from one address, then 3 pass) |
| Q116-b6 | An IPv4-mapped IPv6 address? | The IPv4 address, else all mapped clients share one key | W0 `rate_key` |
| Q116-b7 | The text `User-Agent: tln/<v> (extra)` or a longer text? | Not specified: the tests use `tln/<v>` only | Nothing |

## 10. Disputes

None.

## 11. Verify results

See section 5.1 and 5.2 and `116a-user-hints.md` section 11. The Miniflare rate limit binding works as the reference expects (`ct11-rate-limit` passes with the reference: a rejected request does not need to count).

## 12. Answers (design agent, 2026-11-02)

All questions of section 9 are settled. The answers are in `DESIGN.md` 9 (Q182 to Q186) and `DESIGN-REGISTRY.md` (R-AP45, R-CT11, R-AP68, R-AP70). PLAN row 116 is now 116a and 116b.

| Question | Answer | Design | Rule |
| --- | --- | --- | --- |
| Q116-b1 | Taken. The list is the Write row of R-AP41 with the methods. `POST /v1/closure` is a read. | Q182 | R-AP45 |
| Q116-b2 | Taken | Q183 | R-AP45 |
| Q116-b3 | Taken, with the text of Q168 for the key | Q185 | R-CT11, R-AP68 |
| Q116-b4 | Taken | Q185 | R-CT11 |
| Q116-b5 | Taken: row 9 of R-AP70, after the values and before D1 call 1. A body with no row counts. | Q186 | R-AP70 |
| Q116-b6 | Taken | Q185 | R-CT11 |
| Q116-b7 | Decided: the first product of the header is read (the text up to the first space). | Q184 | R-AP45 |

### 12.1 Test changes (for the test agent)

| # | File | Change |
| --- | --- | --- |
| T1 | `ClientTest.roc`, `Client.roc` (doc comments) | Remove each mark `pending Q116-bn`. |
| T2 | W0 `rate_key`, and the doc comment of `Client.rate_key` | The IPv6 key has the text of Q168: the first 4 groups, each in lower-case hex with no leading zero, then `::/64`. Change the expected values: `2001:DB8::1`, `2001:db8:0:0:1:2:3:4`, `2001:db8::ffff:1:2` and `2001:0db8:0000:0000:ffff:ffff:ffff:ffff` give `2001:db8:0:0::/64`; `2001:db8:0:1::1` gives `2001:db8:0:1::/64`; `2001:0db8:85a3:0000:0000:8a2e:0370:7334` gives `2001:db8:85a3:0::/64`; `::1` and `::` give `0:0:0:0::/64`; `1::` gives `1:0:0:0::/64`. The IPv4, mapped and `unknown` rows do not change. The same key as slice 112b: that slice calls `Client.rate_key`. |
| T3 | W0 `check` | Add the rows of Q184: `tln/0.4.1 (linux)` and `tln/0.4.1 curl/8` against `0.5.0` are refused; `curl/8 tln/0.4.1`, `tln/` , `tln/dev` and `TLN/0.4.1` are not checked. |
| T4 | W2 `hints/ct11-rate-limit` | Add: a request with `rows: []` from one address uses one unit of the budget (Q172, Q186). |
| T5 | W2 `hints/ap45-client-version` | Add: `tln/0.4.1 (linux)` for a hint is 400 with `minimum` (Q184). |
| T6 | `is_write` (W0) | The 13 routes do not change. When the routes of slice 117 and the yank and move routes are in `Route.Id`, they are write routes (Q182). |

### 12.2 Request to slice 112b

`docs/slices/112b-ingest-limits.md` uses `Client.rate_key` and writes no second function. The test agent of 112b writes no own W0 case for the key. Whichever of 112b and 116b is coded first writes the body of `Client.rate_key` against `ClientTest`.

## 13. Code (code agent, 2026-11-02)

| File | What | Lines |
| --- | --- | --- |
| `worker/lib/Client.roc` | `is_write`, `check`, `refusal_json`, `rate_key`, `rate_problem` (and the helpers `refuses`, `larger`, `address_key`, `ipv4`, `prefix64`, `expand`, `side`, `group`, `strip_zeros`). The first product of the `User-Agent` is read (Q184). `refusal_json` parses `Problem.to_json` and writes it again with `minimum`, because `Problem` is opaque and `Problem.roc` is not in this slice. | 180 (file), about 125 new |
| `worker/main.roc` | `client_refusal!`: `Route.decide` with `has_body: Bool.False` first; only `Handle(id)` is checked (rows 1 and 2 come first). `Env.var!` of `MIN_TLN` and `MIN_TLN_WRITE` (`?? ""`). Then the old flow with the real `has_body`. Bindings: `HintRoutes.limiter.declare()` and `IngestRoutes.limiter.declare()`. | about 30 new |
| `worker/HintRoutes.roc` | `limiter` (`RL_HINTS`), `limited_response`, and the call after the decode of the body and before the empty-rows answer (a body with `rows: []` uses one unit, Q186) and before D1 call 1. `Infra` is a `Fault`. | about 15 new |
| `worker/wrangler.toml` | `[[ratelimits]]` `RL_HINTS` (30 a minute) and `RL_INGEST` (60 a minute), `[vars]` `MIN_TLN` and `MIN_TLN_WRITE` (empty). | 18 new |

Decision that the slice does not fix: the `namespace_id` values `1001` and `1002` are local numbers.

## 14. Green results (code agent, 2026-11-02)

| Step | Result |
| --- | --- |
| `scripts/test.sh w0` | `ClientTest` 4 of 4 and `IngestLimitsTest` 5 of 5 pass. The step still fails for `IdentityTest` (slice 113, stubs) only. |
| `scripts/test.sh wbuild w2` | `hints/` 8 of 8 (`ap45-client-version`, `ct11-rate-limit` included), `ingest/` 5 of 5, `ingest-limits/` 3 of 3. Whole run: 113 passed, 6 failed: 5 `identity/` cases (slice 113) and `compat/mx9-missing-100` (a 30 s time out while two builds ran at the same time; it passes alone in 10 s). |
| `scripts/test.sh check fmt w1` | pass, pass, pass |
