# 202 Read cache

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 202 of `PLAN-P2-CLI.md`. The module is `cli/lib/RegistryCache.roc` (new, exposed in `cli/lib/main.roc`). It uses `Registry.headers` and `Registry.no_answer` of slice 201 and the `Fx` calls `list_dirs!`, `read_files!`, `http_get!`, `write_atomic!` (no change of the `Fx` record). No command calls it yet: slice 206 and later slices wire it. Layout: DESIGN.md Q200, DESIGN-CLI.md R-IX1 to R-IX3, R-IX6 (G-C1 is answered).

## Rules

R-AP24, R-AP43, R-AP54 (client side), R-AP55 (`no-cache`, `Talon-Bookmark`), R-AP41 row 5 (client side: the header), R-IX1, R-IX2, R-IX3, R-IX5 (the dir of one registry), R-IX6 (the copies at any age), R-LY1, R-RG3 (no token to a registry), R-AP45 (`User-Agent`).

## Public signatures (stubs, `crash "todo: slice 202"`)

| Name | Signature |
| --- | --- |
| `RegistryCache.origin_dir` | `{ roots, origin } -> Str`: `<index>/registry/<origin with :// and : as _>` (R-IX1) |
| `RegistryCache.key` | `{ origin, url } -> Str`: 32 hex digits, the first 16 bytes of SHA-256 of the path and query (R-IX2) |
| `RegistryCache.files` | `{ roots, origin, url } -> { dir, body, meta }`: `<dir>/<key>.json` and `.meta` in `<origin dir>/get` |
| `RegistryCache.meta_text`, `parse_meta` | The meta text (3 lines) and its reverse. `parse_meta` gives `Err(BadMeta)` with no etag line or no max-age number |
| `RegistryCache.max_age_of` | `List((Str, Str)) -> [MaxAge(U64), NoStore, NoMaxAge]`: header name and directive names in any case, `no-store` wins |
| `RegistryCache.keep` | `{ status, headers } -> Try({ etag, max_age }, [NotKept])`: only a 200 with an ETag and a max-age, not `no-store` |
| `RegistryCache.plan` | `{ cached, now, offline, newest } -> [Use, Revalidate(etag), Fetch, Missing]` |
| `RegistryCache.read_headers` | `{ version, etag, newest, bookmark } -> List((Str, Str))`: User-Agent, If-None-Match, Cache-Control, Talon-Bookmark |
| `RegistryCache.get!` | `Fx, { roots, origin, version, path, now, offline, newest, bookmark } => Try([Answer({ status, body, source : [Live, Copy(U64)] }), NoCopy], Fail)`. The doc of `get!` has the table of the calls |

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/RegcacheTest.roc` (driver `l0-2.roc`), 6 `expect`s: dir, key (the example of R-IX2) and files; meta round trip; `max_age_of` (12 rows); `keep` (7 rows); `plan` (14 rows); `read_headers` (5 rows) | R-IX1, R-IX2, R-IX3, R-IX5, R-IX6, R-AP24, R-AP43, R-AP54, R-AP55, R-AP41 |
| L2 | `tests/commands/cases/registry/ap24-read-cache` (entry `registry`, `tests/commands/L2Registry.roc`): 15 runs. Miss and write, use at age 30, revalidate at age 90 with a 304, `newest`, a bookmark with a fresh copy, a 404 twice (not kept), a `no-store` 200 twice (not kept), offline at any age, offline with no copy, no answer (exit 15), lower-case header names, a route with a query | R-AP24, R-AP43, R-AP54, R-AP55, R-AP41, R-IX1, R-IX2, R-IX3, R-IX6, R-LY1, R-RG3, R-AP45 |

## Readings that the design implies (tested)

| # | Reading |
| --- | --- |
| 1 | A copy is used when `now - mtime < max-age` (R-AP24 "younger than"). At exactly `max-age` it is revalidated. |
| 2 | A 304 gives the copy as `status` 200, and the meta is written again with the same ETag and max-age (R-IX2). The body file is not written. |
| 3 | A request with `no-cache` has no `If-None-Match` and reads no copy (R-AP43 "no local copy"). A bookmark alone gives `no-cache` (R-AP43 case 2). A 200 of such a read replaces the copy (R-IX3). |
| 4 | `--offline` wins over `newest`: it sends no request (R-IX6). A copy of any age is used. |
| 5 | The body file is written before the meta, in one `write_atomic!` (R-IX2). |
| 6 | The answer of `get!` for a non-200 live answer (404, a problem) is given as it is. The caller maps it with `Registry.refuse`. |
| 7 | The meta has a third line `max-age <seconds>` (Q1 below). |

## Output (proposed, TW24)

The failure for no answer is `Registry.no_answer` (slice 201): `the registry <origin> gave no answer: no answer in 20 s. Try again later.` The meta form is the one file form that this slice proposes: `url <path and query>`, `etag <ETag>`, `max-age <seconds>`. A failed write: `cannot write <path>` (kind `Environment`, as `Github.releases!`).

## Out of scope

| Item | Reason |
| --- | --- |
| `toolchains.json` (R-IX4) | Slice 204 |
| The GC of old pages and dirs (R-GC15), `tln cache clean` (R-GC12) | The cache slices (P1 `CacheGc`). R-IX5 here is only the dir of one registry. |
| The line `index: cached at <time>` (R-IX6), the choice between the R-AP13 copy and the R-AP1 copy, the archives and the facts offline | Slice 206 (the seam). `get!` gives `Copy(mtime)`. |
| The Worker side of R-AP54 and R-AP55 (ETag value, 304 shape, cache bypass) | W2 cases in `worker/tests/cases/` |
| The settings and the URL of the registry (`Registry.base`, exit 2 or 19) | Slice 201 and a flow slice |
| `Pragma: no-cache` | The design says `tln` sends `Cache-Control: no-cache` only |

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | R-AP24 says a copy is used when it is younger than "its `max-age`", but R-IX2 gives the meta only the lines `url` and `etag`. Where does the client get the `max-age` of a copy? Options: a third meta line `max-age <seconds>` (the tests use this), or a fixed value for each route (60 s for R-AP1, R-AP2, R-AP13, R-AP14, 300 s for R-AP5: the Worker values), or the `max-age` is read from no place and each copy is revalidated. The L0 meta rows and the `tree.diff` of the L2 case name the third line. | Proposal used (accepted by the manager), waits for G-C38. |
| Q2 | A 200 answer with no `ETag`, or with no `max-age` (and no `no-store`): is it kept, with which `max-age`? R-AP24 says each 200 has an `ETag`, so this is a fault of the registry. `keep` returns `Err(NotKept)` for it in the reference, but no test names it. | Open, G-C38, untested |
| Q3 | A `get!` with a registry that sends a 3xx, or a 304 to a request with no `If-None-Match`: no rule. | Open, G-C38, untested |

## Disputes (from the code agent)

None yet.

## Red result

L0 (`roc test tests/unit/l0-2.roc`): 61 pass, 10 fail. The 6 `RegcacheTest` `expect`s fail with `todo: slice 202`, and the 4 `PrivacyTest` ones with `todo: slice 203` (slice 203). The other 61 pass. L2 (`tests/commands/run.sh registry/`): `registry/ap24-read-cache` fails with `[ROC CRASHED] todo: slice 202`. Logs: `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red202-203.log` and `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red202-203-l2.log`.

## Revert check

`research/slice-202-revert/before/` has the files that the slice changed (`main.roc` of `cli/lib` and of `tests/commands`, `l0-2.roc`, `PLAN-P2-CLI.md`) and `NEW.txt`. `research/slice-202-revert/reference/RegistryCache.roc` is the private green reference (all 71 L0 and the 2 L2 cases pass with it). Mutations of the reference, each caught:

| # | Mutation | L0 | L2 |
| --- | --- | --- | --- |
| M1 | `age <= max_age` (the border) | fail | pass (no run at the border) |
| M2 | A bookmark does not give `no-cache` | fail | fail |
| M3 | `no-store` not read | fail | pass (the fixture has no max-age: the L0 row `max-age=60, NO-STORE` is the test) |
| M4 | A 304 does not write the meta again | pass | fail |
| M5 | A bookmark reads the copy (only `newest` skips it) | pass | fail |

## Verify results

Code agent, 2026-11-02: `roc test tests/unit/l0-2.roc --no-cache`: all 71 pass. `tests/commands/run.sh registry/`: 2 passed (ap24-read-cache, rg4-guard). Revert check (TW12) not run by this agent.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| Tests (code agent) | l0-2 71 of 71. `registry/ap24-read-cache` and `registry/rg4-guard` pass. L2 242 pass. The 17 failures are `ptool/*` and `gc/gc6` (slices 092 and 093). Driver l0-4 does not compile because of the red `ToolbinlistTest.roc` of 092 and 093. |
| Expected exits (manager check) | Each exit other than 0 in the 2 cases is a rule (15: no answer or rate limit; 2: private or 404). |
| Revert check | Test step: 9 mutations caught. |
| Follow-up | 202b: Q218 to Q220 (G-C38 to G-C40). Some untested choices of this code differ from those answers (a 200 with no ETag, names in lower case, a body with no `private` member). |
