# 123 The Worker on platform 0.0.3 and roc-tar 0.0.2

Phase: P2. Status: review (tests red, 2026-11-03). Model for the code: Sonnet high. Plan row: `docs/registry/PLAN.md` 123, A.1 (the 0.0.3 URL), G rows W1, W3, W4, W5.

The slice is big and has parts with different blockers. So it has 4 code parts and 1 test-only part. The order is in section 1.

## 1. Parts and order

| Part | Content | Who | Blocked by | Red tests that it turns green |
| --- | --- | --- | --- | --- |
| 123a | Headers (platform 0.0.3, roc-tar 0.0.2), `ArchiveRead` on `entry.type_byte`, the JWKS `Memo` bound | Code agent | none | The 97 W2 cases that fail with the new clock harness (section 4), `oidc/tp3-jwks-max-age` |
| 123b | `Request.query_all` in `ShortRoutes` and `Shorts.parse_query` | Code agent | 123a (the platform has `query_all` from 0.0.3) | `ShortsTest` (18 `expect`s) |
| 123c | `ZstdStream.feed!` loop in `Archive.read!`, `ArchiveRead.feed_bytes` | Code agent | 123a. The decoded size limit waits for Q441 | `archive/pu38-zero-run`, `ArchiveReadTest` `feed_bytes` |
| 123d | `on_trap` in `Worker.new` | Code agent | Q440 (a 503 problem type in R-AP21). Do not start | none yet (tests wait for the answer) |
| 123e | The W2 runner on the platform test helper (`startApp`, `app.reset()`) | Test agent | The human: go or no go (section 7, Q444) | none |

Order: 123a, then 123b and 123c (independent, they touch other files), then 123d when Q440 is answered. 123e is not on the path of 123a to 123d. Start 123a when no other slice code agent works in `worker/`. The test agent has done the test side of 123a to 123c (section 3). All W2 cases of earlier slices must pass with no change of their expected results, with one open exception: `hints/ct13-hint-quota` (Q443).

## 2. Changes of the code agent

TW18: the code agent does not edit tests. Each stub of the test agent is in the table.

| Part | File | Change | Stub of the test agent |
| --- | --- | --- | --- |
| 123a | `worker/main.roc`, `worker/archive-test.roc` | `pf:` URL to `https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.3/Bup7G6Xgk53Bot1YY9AKQP9e73JVGbWqUyqD24taUYRv.tar.zst`. `roc:` stays `nightly-2026-10-31-f7bef6b` (`ROC_TAG_WORKER` stays 10-31). `tar:` to `https://github.com/Karakatiza666/roc-tar/releases/download/0.0.2/ynGk61syE32Lobjgwd3ZNRURf78xPGxr8Nzi1bSuhUr.tar.zst` | none |
| 123a | `worker/lib/main.roc` | `tar:` to the 0.0.2 URL | none |
| 123a | `worker/tests/unit/w0.roc` | `tar:` to the 0.0.2 URL | done (test agent). W0 passes with `lib` still on 0.0.1 |
| 123a | `worker/lib/ArchiveRead.roc` | Use `entry.type_byte` (`'7'` gives `Other('7')`, R-PU38 row 12). Remove the fields `decoded` and `tail`, the functions `tail_of` and `type_byte`, and the argument `type_at` of `on_event` and `check_member`. Do not use `Tar.roc_accepts` for the kind check: it accepts a symbolic link whose target is safe, and row 12 refuses each symbolic link. The refusal order does not change (kind, then `Tar.check_portable_path`, then the duplicate and below-a-file checks). Change the comment of `NotAFile` (it names `entry.offset + 156`) | none |
| 123a | `worker/Auth.roc` | The JWKS `Memo` is only a bound above the rule of `Oidc.key_for`. On one clock a `Memo` of exactly 1 h expires at `age == 3_600_000` (the platform says "at the pin time plus the age, or later"), and `Oidc.key_for` reloads at `age > 3_600_000` (R-TP16: "older than 1 h"). Give the `Memo` `max_age_ms: 7_200_000` (any value above `Oidc.max_age_ms`). Fix the doc comment of `jwks` (it says that the `Memo` uses the shim clock, not the case clock) | none |
| 123a | `worker/lib/Oidc.roc` | No change. `key_for` stays: the 60 s rule for an unknown `kid` (R-TP16) needs `fetched_ms`, which `Memo` does not give. The "fetch-time workaround" of G row W1 is only the saturating `minus_saturated` for a clock that goes back. `OidcTest` rows `t - 5_000` and `t - 120_000` test it: keep it | none |
| 123b | `worker/lib/Shorts.roc` | Give `parse_query` its body (same checks and order as `parse_url`). Remove `parse_url`, `query_pairs`, `decode`, `hex` | `parse_query : List(Str), List(Str) -> Try(Shorts.Query, Shorts.Refusal)` with `crash "todo"`. Arguments: the values of `short`, the values of `q`, in request order |
| 123b | `worker/ShortRoutes.roc` | `Shorts.parse_query(req.query_all("short"), req.query_all("q"))`. Fix the doc comments that name `Shorts.parse_url` | none |
| 123c | `worker/lib/ArchiveRead.roc` | `feed_bytes` is 65536 | `feed_bytes = 0` |
| 123c | `worker/Archive.roc` | In the chunk loop, `z.feed!(input, ArchiveRead.feed_bytes)` in place of `z.push!(c)`. The first call gets the chunk, each next call gets `[]` while `more` is `Bool.True`. Each `out` goes to `$state.push`. Stop the inner loop when `$state.reading()` is false (the stream stays open, `close!` frees it; its `Truncated` is then a refusal that the state already holds, `unzip_failed` keeps the first). `feed!` has no `OutputLimit`; `close!` still has it, so `unzip_failed` and `Refusal.BadZstd` keep the tag. The `Body.chunk!` call does not change: since 0.0.3 it fills a chunk to 64 KiB (`Body.default_fill`) | none |
| 123c | Doc comments of `Archive.roc` | Step 4c and step 5 of the module comment name `push!` | none |
| 123d | `worker/main.roc` | `Worker.new({ fetch!: fetch!, on_trap: {...} })`. Written inline (nightly 10-31 refuses a named value with absent optional fields). The Roc field for `crash` is `crashed`. Content: Q440 | none yet |

## 3. Changes of the test agent (done)

Each changed file has a copy in `research/slice-123-revert/before/` (same path). New files are in the list `research/slice-123-revert/before/NEW.txt`.

| File | Change | Part |
| --- | --- | --- |
| `worker/tests/clock.js` | No `Date.now` override. It exports `now` (a function) and `setNow` | 123a |
| `worker/tests/worker-test.js` | `makeHandler(app, { now })`. `/__test/now` gives the case clock. The comment of the header | 123a |
| `worker/tests/unit/w0.roc` | `tar:` URL 0.0.2 | 123a |
| `worker/tests/unit/ArchiveReadTest.roc` | 3 new `expect`s (type 7 in 9 chunk sizes, type 7 and type 0 after a pax header, a symbolic link in 4 chunk sizes) and the row `feed_bytes == 65536` | 123a, 123c |
| `worker/tests/unit/ShortsTest.roc` | The `parse_url` rows are `parse_query` rows (18 `expect`s call it; the rows for 413 before the 400 checks and for the order of the 400 checks are new) | 123b |
| `worker/lib/ArchiveRead.roc` | Stub `feed_bytes = 0` and its doc comment | 123c |
| `worker/lib/Shorts.roc` | Stub `parse_query` | 123b |
| `worker/tests/cases/shorts/ap7-query-forms/` | New W2 case: the query forms that the platform parse decides (section 5) | 123b |
| `worker/tests/cases/archive/pu38-zero-run/` | New W2 case: 2 assets of 1.4 KB that unpack to 32 MiB of zeros | 123c |
| `worker/tests/tools/mk-zero-run.mjs` | The generator of `pu38-zero-run`. It writes only that case (do not run `mk-bundle.mjs` for it) | 123c |

No test makes its own `Tar.Entry` record, so no test needs the new field `type_byte`. The plan row expects one; there is none (checked in `worker/tests/unit/` and `worker/lib/`).

## 4. The clock (G row W1)

With `now` as the one clock, the harness change is the whole test change. Result (section 8): with the 0.0.2 build, 97 W2 cases fail (`Time.now_ms!` reads the real `Date.now()`, the cases expect the case clock). With the reference build on 0.0.3, 185 of 187 cases pass with no change of the cases. The 2 other cases show the one-clock effects:

| Case | What the one clock changes | Fix |
| --- | --- | --- |
| `oidc/tp3-jwks-max-age` | Request 2 is at exactly 1 h. The `Memo` expires at 1 h, the rule `age > 1 h` does not reload. So the `Memo` reads the JWKS one request early | Code: the `Memo` bound above the rule (123a, section 2). The case does not change |
| `hints/ct13-hint-quota` | The tag list `Memo` (1 h, R-CT12) now expires between request 2 and request 3, which is 12 h later in the case clock. The Worker reads the tag list 2 times, the case expects 1 (the comment of slice 116a: "the hour is not" on the shim clock) | Q443: the expected `github.log` has 2 lines. Not changed by the test agent |

Other places that use time and were checked on the reference: the `Cache API` `max-age` (real clock, as before), `Response.after` work (the clock does not move in a case, so no deadline is late), the cron and queue lines (the runner sets the clock first, as before). T7 of the platform README (a clock that jumps forward cancels the tasks in flight) did not show: the cases wait for the work after the response where it matters.

## 5. Query edge cases (G row W4, R-AP23)

R-AP23 is about media types of bodies. It does not speak of the query. The rules of the query of the routes are R-SN6, R-SN7, R-AP44, R-AP46 and R-AP48 row 6. The platform README lists 4 changes of `Request.query` (and `query_all`). Only `GET /v1/packages` (`Shorts.parse_url`) parses the query by hand; the other routes use `req.query(name)`, and they get the new parse in 123a with no code change.

| Edge case of 0.0.3 | Effect on `?short=` and `?q=` | Test |
| --- | --- | --- |
| 1. An empty part (`?a&&b`) is skipped | None. A part with no name never matches `short` or `q`. The hand parse and the platform give the same result | W2 `shorts/ap7-query-forms` requests 1, 4, 6 (green before and after). Also `?short` with no `=` is the empty value (request 5) |
| 2. Invalid UTF-8 (`%FF`) is U+FFFD, not the raw text `%FF` | The value that the answer repeats (`"short":"..."`) changes. The design is silent: R-SN6 says "percent-decoded" only | Q442. No test until the answer |
| 3. A `?` after `#` is in the fragment | Not reachable: a client does not send a fragment, and `%23` is data | None |
| 4. A tab, LF or CR in the query is removed | Not reachable: a request line cannot have them, and `%09` is data | None |

The decode rows of the old W0 tests (`%52`, `+`) moved to W2 `shorts/ap7-query-forms` (requests 2, 3, 4): the pure function does not decode any more. A bad escape (`50%`) stays as it is in both parses (request 4: green before and after).

## 6. Tests

| Layer | File and case | Rules | State |
| --- | --- | --- | --- |
| W0 | `ArchiveReadTest`: type 7 member in chunk sizes 1, 7, 100, 511, 512, 513, 1000, 4096 and whole: `NotAFile(Other('7'))` | R-PU38 rows 6, 12 | green before and after (the refactor must keep it) |
| W0 | `ArchiveReadTest`: a pax header with a path, then a type 7 member (`NotAFile` with the pax path) and a type 0 member (a file) | R-PU38 row 12 | green before and after |
| W0 | `ArchiveReadTest`: a symbolic link and a hard link in chunks of 1, 100, 513 bytes: the first refusal in stream order | R-PU38 rows 6, 9, 12 | green before and after |
| W0 | `ArchiveReadTest`: `ArchiveRead.feed_bytes == 65536` | R-PU38 (part 123c) | red: the stub is 0 |
| W0 | `ShortsTest`: 18 `expect`s on `parse_query` (the values, 50 and 51 values, the empty values, `short` with `q`, `q` twice, the order of the 400 checks, 413 before the 400 checks) | R-AP7, R-AP46, R-SN7, R-AP48 rows 4, 6 | red: `todo` |
| W2 | `shorts/ap7-query-forms`: 7 requests (empty parts, `%52` and `+`, `%26` and `%3D` in a value, `%25` and a bad escape, `short` with no value, no parameter, `q` twice with empty parts) | R-AP7, R-SN6, R-SN7, R-AP44, R-AP46, R-AP48 | green before and after (a pin for the change from the hand parse to `query_all`) |
| W2 | `archive/pu38-zero-run`: asset 1, a package with a member `data/zeros.bin` of 32 MiB of zeros (1430 bytes packed), and asset 2, a package then 32 MiB of zeros after the tar end (1396 bytes packed). Both: 200 with the package record | R-PU38 rows 3, 5, 10 | red: 422 "a block gives too many bytes" (`push!` stops one push at 16 MiB). Checked |
| W2 | The 187 cases of earlier slices, with the clock harness | R-WH4 (clock) | red on the 0.0.2 build (97 cases), green on 0.0.3 except `oidc/tp3-jwks-max-age` and `hints/ct13-hint-quota` |
| W2 | `selftest/*` and `runner/*` | R-WH4 | `runner/r-wh4-github-and-clock` and `selftest/wrong-clock` pass |

## 7. The test helper (G row W3, part 123e)

`startApp` of platform 0.0.3 makes its own test entry. The Talon entry `worker/tests/worker-test.js` is a subclass of the shim class, so the two cannot be mixed. To use `app.reset()` the runner must drop `worker-test.js` and give its work to `startApp` options and a `hooks` module:

| Work of `worker-test.js` or `run.mjs` | In `startApp` |
| --- | --- |
| D1 call count and ops (`x-d1-calls`, `x-d1-ops`) | `count: ['DB']`, `res.calls.DB.n`, `.ops` |
| `x-d1-session` | `res.sessions` |
| The clock (`x-test-now`) | `init.now`, `app.setNow` |
| The fake GitHub | `outbound` as a Node function (the unmatched answer is 599, as now) |
| Queue sends with body and delay (`queue_sent`), the count of `timingSafeEqual`, the `/__test/...` paths, the `__test` queues | A `hooks` module (`wrapEnv`, `fetch`). `calls` has no queue body |
| Rate limit bindings, `handleStructuredLogs`, the D1 persist | `miniflareOptions`, `app.logs` |
| The settings of a case (`bindings`), `ratelimits.json`, `app` = `archive` | These differ between cases, so one `startApp` serves only the cases with the same set. The runner needs a pool keyed by that set |

The gain is unknown. W2 is 69 s now (budget 45 s, TW20), with 187 `new Miniflare` per run. The probe `research/slice-123-revert/probe-helper/probe.mjs` was to measure a start, a request and a reset; it could not start the Worker (section 12). The change touches the whole runner (493 lines) and the 11 files of the cases that depend on the header names. Do it as a separate slice by the test agent, after 123a to 123c are green, and only if the human wants it (Q444).

## 8. Results

| Run (2026-11-03, `--opt=speed`) | Result |
| --- | --- |
| `scripts/test.sh fmt` | pass |
| `scripts/test.sh w0` (real tree) | 429 passed, 19 failed, 0 compiler errors. The 19: 18 `ShortsTest` (`todo` of `parse_query`) and `ArchiveReadTest` `feed_bytes == 65536` (the stub is 0). Each fails for the right reason |
| `node sql/tests/run.mjs` | w1: 53 passed, 0 failed |
| `scripts/test.sh wbuild w2` (real tree, 0.0.2 build, new clock harness) | 91 passed, 98 failed (189 cases). 97 fail because `Time.now_ms!` reads the real `Date.now()` (all areas that read the clock) and 1 is `archive/pu38-zero-run` (422 "a block gives too many bytes", checked with a probe case). `shorts/ap7-query-forms` passes (a pin). Run log: `research/slice-123-revert/run-real-w2-1.w2.log` |
| Reference (`research/slice-123-revert/ref.sh all`: 0.0.3 headers, type byte, `parse_query`, `feed!`, JWKS bound, with the file of Q443) | W0 448 passed. W2 189 passed, 0 failed. Log: `run-ref-all-3.log` |
| Reference with the old `ct13` `github.log` (`NOPROPOSED=1`), and without the JWKS bound | Not run as a whole. The first reference run (`run-ref-w2-2.log`, only the headers and the new harness) had exactly 2 failures: `hints/ct13-hint-quota` and `oidc/tp3-jwks-max-age` |
| Time of the W2 run on the real tree (0.0.2 build) | 69 s before this slice (`wbuild` warm), over the budget of 45 s (TW20). Mean case 2.1 s, a case with one request 1.3 to 1.7 s with 6 cases at the same time |

Mutants (private reference `research/slice-123-revert/reference/patch.py`, files `mutations/`, logs `mut-*.log`). Each is caught:

| Mutant | Change | Caught by |
| --- | --- | --- |
| m1 | A type 7 member is not refused (`kind = entry.kind`) | W0 `ArchiveReadTest` (3 `expect`s: the old row of row 12, and the 2 new rows with the chunk sizes and the pax header) |
| m2 | A symbolic link with a safe target is a file (the rule of `Tar.roc_accepts`) | W0 `ArchiveReadTest` (3 old `expect`s that use a link with the target `x`). The new link row uses an absolute target, so it does not catch m2 |
| m4 | `feed_bytes` is 4096 | W0 `feed_bytes == 65536` |
| m5 | The `feed!` loop does not call again while `more` is true | W2 `archive/pu38-zero-run`, `pu38-hash-and-end`, `pu38-paths-and-header`, `pu38-real-bundles` |
| m6 | The JWKS `Memo` bound is 1 h, the same as the rule | W2 `oidc/tp3-jwks-max-age` |

The reference does not cover `on_trap` (Q440) or the decoded limit (Q441).

The helper probe (`research/slice-123-revert/probe-helper/probe.mjs`) did not start the Worker: see section 12 (ratelimit bindings). So there is no measured cost of `startApp` and `reset()` for Q444.

## 9. Output (proposed, TW24)

None new. The 503 body of `on_trap` waits for Q440.

## 10. Out of scope

| Item | Reason |
| --- | --- |
| A W2 case for `on_trap` | Q440. Also: the Worker has no route that traps, so a W2 case cannot cause a trap. The proposal for 123d is a check of the manifest in Node (`manifestOf` of `.roc-cfw/manifest.js` on `app.wasm`: the `on_trap` table equals the expected table) in `scripts/test.sh wbuild`, and a W0 check of the body texts (`Problem.to_json`). Both after the answer |
| `Body.chunk_with!` | The default fill (64 KiB) is the wanted size. No code change |
| A test of the size of one `feed!` part | W2 cannot see it. W0 pins `feed_bytes` |
| Edge cases 3 and 4 of the query | Not reachable by a request (section 5) |
| `scheduled` and `queue` handlers in `on_trap` | The platform covers `fetch` only (G row W3) |
| The CLI nightly and `packages/records` | Not changed. `ROC_TAG_WORKER` stays 10-31 |
| R-WH13 text | It names 0.0.2 as an example of the release built with 10-31. 0.0.3 is built with the same nightly, so the rule holds. The human may change the example |

## 11. Questions (stop until answered)

| Id | Question | Proposal | Blocks |
| --- | --- | --- | --- |
| Q440 | R-AP21 has no 503 problem type. `on_trap` needs a fixed answer for `oom`, `shed`, `cpu`, `deadline` (G row W3). Which `type`, and what for `default` and `crashed`? | A new row `/errors/busy`, 503: "The Worker cannot serve the request now (memory, CPU or time budget, or load shed). The client may send it again." `default` and `crashed` use the existing `/errors/internal` (500) with the form of R-AP21 (`type`, `title`, `status`, `detail`). `alarm`, `cancelled`, `event`, `failed`: the platform default or `internal`. The shim adds `Retry-After: 1` to a 503 of `shed` and `oom`. `tln` maps a 503 to exit 15 (R-AP22) | 123d |
| Q441 | R-PU38 row 5 limits "the unpacked total" to 256 MiB, and `roc-tar` counts only the sizes of the members. Zero bytes after the tar end are accepted (rows 4, 6), and `push!` stopped one push at 16 MiB. With `feed!` nothing stops a long run of zeros after the tar end (100 MB packed can unpack to terabytes) except the CPU limit of the Worker. Which limit on the decoded bytes? | Count all decoded bytes (members, headers, padding and the zeros after the end). Over 256 MiB plus 16 MiB for headers and padding (`max_unpacked_bytes` + 16777216): 422 `not-a-candidate`, `detail` `the unpacked archive has more than <limit> bytes`. The read stops at once, the hash goes on (row 4). New refusal `TooLargeUnpacked(U64)` in `ArchiveRead.Refusal` | The limit part of 123c. The loop itself can be coded |
| Q442 | A query value with invalid UTF-8 (`?short=%FF`): the 0.0.3 parse gives U+FFFD, the hand parse gave the raw text `%FF`. The answer repeats the value (`"short":"..."`). R-SN6 says only "percent-decoded". | Accept it as the platform does (U+FFFD in the answer, 200, no match). A 400 would need a new rule and a check of the raw text | A W2 case in 123b (none written) |
| Q443 | `hints/ct13-hint-quota`: with one clock, the tag list `Memo` (R-CT12: read at most once an hour) is read again at request 3, which is 12 h after request 2. The case expects 1 read. The plan rule says that W2 expected results do not change. | Change `expect/github.log` of the case to 2 lines (the same line twice). R-CT12 and the Worker are right; the old result was an artefact of the two clocks. The proposed file is `research/slice-123-revert/proposed/ct13-hint-quota-github.log`. The reference run uses it | 123a green |
| Q444 | Do the helper (part 123e)? | Not now. The W2 run is over the budget (69 s of 45 s), but the gain of `reset()` is not measured against a pool of Miniflares by setting set. A fixed cost of 1.3 to 1.7 s for each case (start, migrations, one request) is most of the mean case time (2.1 s), so the gain can be large, but the reset repeats the migrations | 123e |

### Answers (Design Q440 to Q444, 2026-11-03)

| Q | Answer | Test change |
| --- | --- | --- |
| Q440 | A new `/errors/busy` 503 (Registry R-AP21, R-AP82). Table in R-AP82: `oom`, `shed`, `cpu`, `deadline`, `alarm`, `cancelled` are 503 `busy` with one `detail` each; `crashed`, `event`, `failed`, `default` are 500 `internal`; `application/problem+json`, `no-store`; `Retry-After: 1` only on `oom` and `shed` (the shim). | 123d starts after records 104j (`Problem.Kind` `Busy`). W0 `ProblemTest` in the Worker: the 7 body texts of `Problem.to_json` (and `type`, `status`). The Node check in `scripts/test.sh wbuild`: the `on_trap` table of `manifestOf` equals the R-AP82 table (status, content type, `cache-control`, body). No W2 case (no route traps) |
| Q441 | All decoded bytes count; the limit is 285,212,672 bytes (256 MiB + 16 MiB); 422 `the unpacked archive has more than 285212672 bytes`; decoding stops, the hash goes on; row 9 order (Registry R-PU38 row 5). | `ArchiveRead.Refusal` gets `TooLargeUnpacked(U64)`. W0 `ArchiveReadTest`: the count with members, padding and a zero run, the limit at the edge (equal passes, one more refuses), the detail text, the order against a hash mismatch (the hash wins). W2 `archive/pu38-zero-run`: a small zstd frame of zeros past the limit gives the 422 and a bounded CPU time |
| Q442 | `%FF` becomes U+FFFD, 200, no match, no new rule (Registry R-SN6). The plan row named R-AP23 and now names R-SN6, R-SN7, R-AP56. | 123b: one W2 case or one `ShortsTest` row: `?short=%FF` gives `{"matches":[{"matches":[],"short":"\uFFFD"}]}` as the answer text with the character. The 18 `expect`s stay |
| Q443 | 2 reads (Registry R-CT12: once an hour on the shim clock). The code stays. | Change `expect/github.log` of `hints/ct13-hint-quota` to the 2 lines of `research/slice-123-revert/proposed/ct13-hint-quota-github.log`. No other case changes |
| Q444 | Drop 123e for now. G19 in the registry plan. | None. Section 7 stays as a note. The W2 overshoot (69 s against 45 s) is known in G19 |
| Q463 | The title depends on the type only: `/errors/internal` is `Internal error` (as `Problem.title`), `/errors/busy` is `Busy` (Registry R-AP82). | `worker/tests/trap-table.mjs` line 17: `title: 'Internal error'` in place of `Internal Server Error`. The `busy` title `Busy` stays. 123d builds the bodies with `Problem.to_json` and the W0 test of the 7 body texts uses `Problem.title` |

## 12. Platform notes (for the platform session)

| Note | Detail |
| --- | --- |
| `Memo` expiry is `>=` | "At the pin time plus the age, or later" (MODULES.md 11). An app rule with `>` (R-TP16 "older than 1 h") is one ms apart. Not a fault, but the doc could say that an app rule on the same age needs a `Memo` bound above it |
| `Tar.roc_accepts` accepts symbolic links | By design (it follows `roc unbundle`). R-PU38 row 12 refuses each symbolic link, so the Worker cannot use it. A note in the doc of `roc_accepts` would save the next reader the same check |
| `startApp` and ratelimit bindings | The check in `test.mjs` (the loop over `m.bindings`) refuses a `ratelimit` binding: "has no local form in Miniflare", and `bindings` or `hooks` only silence the check, which then lets a missing binding through (with `bindings: { RL_HINTS: 'x' }` the shim says "env.RL_HINTS is ..." at load). With `hooks` and `miniflareOptions: { ratelimits: {...} }` (the same table as `worker/tests/run.mjs`) the Worker did not start: "Uncaught Error: internal error" (workerd). Repeat: `node research/slice-123-revert/probe-helper/probe.mjs <dir>` on a `ref.sh` build. The registry Worker has 3 ratelimit bindings, so it cannot use `startApp` until this works |
| `startApp` has no queue body in `calls` | `calls.list` has `op`, `session`, `kind`, `name`. A test that checks the body and delay of a queue send needs a `hooks` module |

## 13. Code results, part 123a (code agent, 2026-11-03)

| File | Change | Lines now |
| --- | --- | --- |
| `worker/main.roc`, `worker/archive-test.roc` | `pf:` 0.0.3 URL, `tar:` 0.0.2 URL. `roc:` stays `nightly-2026-10-31-f7bef6b` | no line count change |
| `worker/lib/main.roc` | `tar:` 0.0.2 URL | no line count change |
| `worker/lib/ArchiveRead.roc` | `check_member` uses `entry.type_byte == '7'` (`Other('7')`, no `Tar.roc_accepts`). Removed the fields `decoded` and `tail`, `tail_of`, `type_byte`, the argument `type_at` of `on_event` and `check_member`. Comment of `NotAFile` changed. `feed_bytes` is still the stub 0 (123c) | 11 lines fewer |
| `worker/Auth.roc` | `Memo` `max_age_ms: 7_200_000`. The doc comment of `jwks` says that the `Memo` is a bound above the rule of `Oidc.key_for` | 2 lines more |

Results (`--opt=speed`):

| Run | Result |
| --- | --- |
| `scripts/test.sh w0` | 429 passed, 19 failed: 18 `ShortsTest` (`todo`, 123b) and `ArchiveReadTest` `feed_bytes == 65536` (stub, 123c). 0 compiler errors |
| `node sql/tests/run.mjs` | w1: 53 passed, 0 failed |
| `scripts/test.sh wbuild w2` | 187 passed, 2 failed (189 cases). Time: wbuild 193.6 s (budget 90), w2 95.2 s (budget 45; two runs of `test.sh` were at the same time for part of it) |
| Worker `roc fmt --check` (10-31) on `Auth.roc`, `lib/ArchiveRead.roc`, the 3 headers | pass |
| `scripts/test.sh fmt` | fail on `tests/unit/QueuesendTest.roc` (parse error with 10-14). Not a file of this slice; not changed |

Red cases after 123a:

| Case | Reason | Part |
| --- | --- | --- |
| `ShortsTest` (18 `expect`s) | `Shorts.parse_query` is the `todo` stub | 123b |
| `ArchiveReadTest` `feed_bytes == 65536` | stub is 0 | 123c |
| `archive/pu38-zero-run` | 422 "a block gives too many bytes" (`push!` stops at 16 MiB) | 123c |
| `shorts/ap7-query-forms` request 8 | `?short=%FF` gives `%FF` from the hand parse of `Shorts.parse_url`; the test expects U+FFFD (the platform `query_all`). Turns green when 123b uses `query_all` | 123b |

`hints/ct13-hint-quota` and `oidc/tp3-jwks-max-age` pass. Of the 97 old W2 cases, all pass. No test or design file changed. No new platform UX issue (the notes of section 12 stay).

## 13. Tests after the answers Q440 to Q444 (test agent, 2026-11-03)

This section replaces the parts of sections 1, 6, 7 and 10 that it contradicts (123d is not blocked by a question any more; 123e is dropped; the decoded limit has tests). Only test files changed; copies of the old files are in `research/slice-123-revert/before/`.

| Q | Layer | File and case | Rules | Red now because |
| --- | --- | --- | --- | --- |
| Q443 | W2 | `hints/ct13-hint-quota/expect/github.log`: 2 lines (copy of `proposed/ct13-hint-quota-github.log`) | R-CT12 | Red on the 0.0.2 build and green on 0.0.3 only with the code of 123a (one clock). On the 0.0.2 build the whole W2 is red anyway (section 8) |
| Q441 | W0 | `ArchiveReadTest`: the state after the package tar and `limit - tar + 1` zero bytes (one list): not `reading`, the problem is 422 `the unpacked archive has more than 285212672 bytes`; with a wrong hash the hash refusal wins (row 8); a symbolic link refusal before a push of `limit` zeros stays. It uses no new tag (only `ArchiveRead.problem`), so the file compiles now | R-PU38 row 5, 8, 9; Q441 | The read has no decoded limit: it runs the 285 MB through the tar reader (the test takes 15 s while it is red; with the limit it is fast, because the crossing chunk never reaches the tar reader) and gives `Ok` |
| Q441 | W2 | `archive/pu38-zero-run`, 5 requests (`timeout` 60): 32 MiB zeros inside a member (200), 32 MiB zeros after the tar end (200), a total equal to the limit (200), the limit + 1 (422 with the detail), and a frame of 8 GiB of zeros in 262 KB packed (422, decoding must stop at the limit; with no limit the case runs into its timeout) | R-PU38 rows 3, 4, 5, 6, 10; Q441 | Requests 1 to 3: 422 "a block gives too many bytes" (`push!`). Requests 4 and 5: 422 with another detail |
| Q442 | W2 | `shorts/ap7-query-forms` request 8: `?short=%FF&short=a%C3%28b` gives `"short":"�"` and `"short":"a�(b"`, 200, no match, 1 D1 call (rule R-SN6 added to `rules`) | R-SN6, R-SN7, R-AP56 | The hand parse keeps the raw text `%FF` |
| Q440 | Node, step `wtrap` | `worker/tests/trap-table.mjs <build dir>`: reads the manifest of `app.wasm` and asks `trapResponse` of the shim for the 9 causes (`crash`, `alarm`, `cpu`, `oom`, `shed`, `deadline`, `cancelled`, `event`, `failed`) and checks `default`. Per cause: status, `application/problem+json`, `no-store`, the exact 4 members `type`, `title`, `status`, `detail` (the texts of R-AP82), no crash text, `retry-after: 1` only on `oom` and `shed`, and no `retry-after` in the table of the app on another cause. New step `wtrap` in `scripts/test.sh` (default list, after `w2`; it asks for `wbuild` as `w2` does; budget 5 s) | R-AP82, R-AP21, R-AP22 | The manifest has no `on_trap` table: `FAIL wtrap: the manifest of app.wasm has no on_trap table` |

Why no W2 case for Q440: no route of the Worker traps, so no case can make a `crashed`, `oom`, `shed`, `cpu` or `deadline` outcome. The check reads the table that the shim uses and runs the real `trapResponse`, so it covers the shim side (the `retry-after` of TR7) too.

What 123d needs from other slices:

| Need | Where |
| --- | --- |
| Records slice 104j: `Problem.Kind` `Busy` (type `/errors/busy`, status 503) | `packages/records`. The Node check does not need it |
| `Busy` in `worker/lib/Problem.roc` (its own `Kind`: `type_uri`, `kebab`, `status`, `title`) | 123d. Then apply `research/slice-123-revert/proposed/ProblemTest-busy.txt` (the W0 row for the 18th type). It cannot be in the tree now: the tag does not exist and W0 would not compile |
| A title conflict | R-AP82 gives the title "Internal Server Error" for the 500 of a trap. `Problem.title(Internal)` is "Internal error" (slice 101 proposal, checked by W2 cases). So the code agent writes the 500 body by hand (the texts of `trap-table.mjs`), not with `Problem.to_json(Problem.new(Internal, ...))`. The human may want one title for both: not changed here |

Reference and mutants (`research/slice-123-revert/reference/patch.py` stages S6 and S7, mutants `m7`, `m8`):

| Mutant | Change | Caught by |
| --- | --- | --- |
| m7 | The app gives `retry-after: 1` on the `cpu` answer | `wtrap` (`cpu: retry-after 1, expected none`; also the table check) |
| m8 | The decoded count is not kept between chunks | W0 `ArchiveReadTest` (the read after the package tar and the zeros), W2 `pu38-zero-run` |

## 14. Code results, parts 123b and 123c (code agent, 2026-11-03)

| File | Change | Lines now |
| --- | --- | --- |
| `worker/lib/Shorts.roc` | `parse_query` has its body (same checks and order as the old `parse_url`). Removed `parse_url`, `query_pairs`, `decode`, `hex`. Doc comments of `Query` and `parse_query` name `Request.query_all` and Q442 | 330 to 259 |
| `worker/ShortRoutes.roc` | `Shorts.parse_query(req.query_all("short"), req.query_all("q"))`. The module comment names it | 71 |
| `worker/lib/ArchiveRead.roc` | `feed_bytes = 65536`. New `max_decoded_bytes = 285212672` (Q441), new field `decoded` (kept between chunks), new refusal `TooLargeUnpacked(U64)` (the payload is the limit) with the detail `the unpacked archive has more than <limit> bytes`. `push` counts all decoded bytes first: a total over the limit keeps the refusal and the tar reader never gets the chunk; equal passes. The old `push` body is `tar_push` (the 512-byte retry calls `tar_push`, so a byte is never counted twice) | 491 |
| `worker/Archive.roc` | The chunk loop calls `z.feed!(input, ArchiveRead.feed_bytes)`: the chunk first, then `[]` while `more` is true and `reading` is true. Each `out` goes to `$state.push`. Module comment steps 4c and 5 changed | 112 |

Choices: the limit constant is `max_decoded_bytes` (a new name; `max_unpacked_bytes` and `tar_limits` do not change). `feed!` has no `OutputLimit`, so the loop has 4 zstd error arms plus `Fault` for `BadHandle` and `WrongTask`; `close!` keeps `OutputLimit`.

Results (`--opt=speed`):

| Run | Result |
| --- | --- |
| `scripts/test.sh w0` | 446 passed, 3 failed, 0 compiler errors. The 3: `ProblemTest` lines 31, 42, 45, because `Problem.Kind` `Busy` is the `crash "todo"` stub (part 123d, section 13 "What 123d needs"). Not touched |
| `node sql/tests/run.mjs` | w1: 53 passed, 0 failed |
| `scripts/test.sh wbuild w2` | w2: 189 passed, 0 failed. wbuild 279 s (budget 90), w2 107 s (budget 45; the machine was loaded) |
| `scripts/test.sh fmt` | pass. Worker `roc fmt --check` (10-31) on the 4 files: pass |

`wtrap` not run (123d). No test, design, sql, cli or packages file changed. No new platform UX issue.

## 15. Code results, part 123d (code agent, 2026-11-03)

| File | Change | Lines now |
| --- | --- | --- |
| `worker/lib/Problem.roc` | `Busy` rows: kebab `busy`, status 503, title `Busy`. New `Cause` tag union (9 causes) and pure `for_cause` (Busy for oom, shed, cpu, deadline, alarm, cancelled; Internal for crashed, event, failed; fixed `detail`, no crash text) | 154 |
| `worker/main.roc` | `trap_fixed` builds a `Worker.Fixed` from `Problem.for_cause` (`to_json`, headers `content-type: application/problem+json`, `cache-control: no-store`). `Worker.new` has `on_trap` as a literal (default = Failed) | 179 |

Results (`--opt=speed`): `scripts/test.sh w0 wbuild w2 wtrap`: all pass (w0 incl. ProblemTest, w2 189, wtrap 9 causes + default). `node sql/tests/run.mjs`: w1 53 passed. `fmt` pass; Worker `roc fmt --check` pass. No `retry-after` in the app table (the shim adds it on oom and shed). No new platform UX issue.

## 16. Revert check on the real code (TW12, test agent, 2026-11-03)

One mutation at a time on a build copy (`research/slice-123-revert/ref.sh` with `NOREF=1`, `MUTATE=mutations/real/<m>.py`; logs `real-<m>.w0.log`, `real-<m>.w2.log`; `--opt=speed`). `worker/` and the tests were not changed. Each mutation is caught.

| Mutant | Change | Caught by |
| --- | --- | --- |
| r1 | A type 7 member is not refused (`kind = entry.kind`) | W0 `ArchiveReadTest`: the type 7 row of rows 6, 12 (line 355), the type 7 in 9 chunk sizes (374), the pax header then a file (382) |
| r2 | A symbolic link with a safe target is a file (the rule of `Tar.roc_accepts`) | W0 `ArchiveReadTest`: the stream order of row 9 (532), the first refusal kept (538), the zstd error after a refusal (546), and the Q441 row (467) |
| r4 | `feed_bytes` is 4096 | W0 `ArchiveReadTest`: `feed_bytes == 65536` (122) |
| r5 | The `feed!` loop does not call again while `more` is true | W2 `archive/pu38-zero-run` and `archive/pu38-hash-and-end` |
| r6 | The JWKS `Memo` bound is 1 h | W2 `oidc/tp3-jwks-max-age` |
| r7 | The app gives `retry-after: 1` on the `cpu` answer | `wtrap`: `cpu: retry-after 1, expected none` and `the app gives retry-after` |
| r8 | The decoded count is not kept between chunks | W0 `ArchiveReadTest`: the Q441 row (467); W2 `archive/pu38-zero-run` (the case times out after 60 s: the 8 GiB frame is not stopped) |
| r9 | Q442: `%FF` stays raw (U+FFFD replaced by `%FF` in the route) | W2 `shorts/ap7-query-forms` request 8 (`expected U+FFFD, got %FF`) |
| r10 | Q463: the title of `Internal` is `Internal Server Error` | W0 `ProblemTest` (the types row, line 31); `wtrap` for `crash`, `event` and `failed` |

The first run of r9 did not apply (the text was also in a doc comment): the mutation script was fixed to match the code line, and r9 was run again.
