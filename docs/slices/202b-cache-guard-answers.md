# 202b Cache and guard answers

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Follow-up of slices 202 (`cli/lib/RegistryCache.roc`) and 203 (`cli/lib/PrivacyGuard.roc`) for the design answers G-C38 (Design Q218), G-C39 (Q219) and G-C40 (Q220). The design text is CLI R-IX2, R-IX7 (new), R-RG4 (the table of 5 rows) and R-RG6. The slices 202 and 203 took other choices for some of these points, and no test named them. This slice changes the tests, and the stubs of the functions whose signature changes. The `Fx` record does not change. The code of 202 and 203 that is still right stays: `max_age_of`, `read_headers`, `repo_url`, `refusal`, and the old body of `repo_file`. The green code of the old slices is in `research/slice-202-revert/code-final/` and `research/slice-203-revert/code-final/`.

## Rules

R-IX2 (meta lines, a copy with no ETag or no max-age, only `max-age` and `no-store` are read), R-IX3, R-IX7, R-E6 (last row, exit 15), R-AP24, R-AP43, R-AP54, R-RG4 rows 1 to 5, R-RG5, R-RG6, R-EC2, R-AP28 (case 3).

## Design answers as tests

| Id | Answer | Test |
| --- | --- | --- |
| G-C38 a | The meta line `max-age <n>` is from the `Cache-Control` of the 200 answer | L0 `max_age_of`, `meta_text`, `keep`. L2 ap24 runs 16 to 18 |
| G-C38 b | A 200 with no ETag is kept. The meta has no `etag` line. The next request has no `If-None-Match` | L0 `meta_text`, `parse_meta`, `keep`, `plan`. L2 ap24 run 18 |
| G-C38 c | A copy with no max-age is kept and is never fresh (revalidated with its ETag, or fetched with no ETag, at any age, also at age 0). `--offline` still uses it | L0 `keep`, `plan`. L2 ap24 runs 19 to 21 |
| G-C38 d | Only `max-age` and `no-store` are read. `s-maxage` and `stale-while-revalidate` are not | L0 `max_age_of`, `keep`. L2 ap24 runs 16 to 21 (the answers have `s-maxage=600`) |
| G-C38 e | A 3xx, or a 304 to a request with no `If-None-Match`: exit 15, nothing is kept | L0 `unusable`. L2 ap24 runs 22 to 24 |
| G-C39 a | Each `github.com` text names a repository: a typed name, a URL with the host `github.com`, a group or URL with no scheme. The repository is the first 2 path parts, with any path after them | L0 `repos_to_check` (forms row). L2 rg4 run 15 |
| G-C39 b | One check for each name in lower case. The `repo.json` key is in lower case | L0 `repos_to_check`, `repo_file`. L2 rg4 run 14 |
| G-C39 c | An unsafe part in a typed name: exit 2. In a name from a header: no request, no error | L0 `repos_to_check` (BadName row). L2 rg4 runs 16 and 17 |
| G-C39 d | A 200 with no boolean `private`, or a body that is not JSON: exit 15, nothing kept | L0 `verdict`, `bad_body`. L2 rg4 runs 18 and 19 |
| G-C40 | A public answer, then a private one: the public answer stays in `repo.json` | L2 rg4 runs 20 and 21 |

## Public signatures (stubs, `crash "todo: slice 202b"`)

| Name | Signature | Change |
| --- | --- | --- |
| `RegistryCache.Cached` | `{ etag : Try(Str, [None]), max_age : Try(U64, [None]), mtime : U64 }` | `etag` and `max_age` are `Try` |
| `RegistryCache.meta_text` | `{ path, etag : Try(Str, [None]), max_age : Try(U64, [None]) } -> Str` | The `etag` line only for `Ok`, the `max-age` line only for `Ok` |
| `RegistryCache.parse_meta` | `Str -> Try({ etag : Try(Str, [None]), max_age : Try(U64, [None]) }, [BadMeta])` | A missing line gives `Err(None)`. `BadMeta`: no `url` line, or a `max-age` that is not a number (decision 1) |
| `RegistryCache.keep` | `{ status, headers } -> Try({ etag : Try(Str, [None]), max_age : Try(U64, [None]) }, [NotKept])` | Each 200 that is not `no-store` is kept (decision 2) |
| `RegistryCache.plan` | `{ cached : Try(Cached, [Missing]), now, offline, newest } -> Step` | `Step` is as before. A copy with no `etag` gives `Fetch` and never `Revalidate`. A copy with no `max_age` is never `Use`, except offline |
| `RegistryCache.unusable` | `{ origin : Str, path : Str, status : U16 } -> Fail` | New. Kind `Network` (15) |
| `RegistryCache.get!` | the same signature | A 3xx, and a 304 when the request has no `If-None-Match`, give `Err(unusable)`. See the doc table of `get!` (step 3b) |
| `PrivacyGuard.repos_to_check` | `{ sources, offline, frozen } -> Try(List({ owner, repo }), [BadName(Str)])` | `Try`. The names are in lower case. `BadName` has the typed text |
| `PrivacyGuard.repo_file` | same | The key is in lower case. The stub keeps the old body, so the L0 row fails by value |
| `PrivacyGuard.verdict` | `{ status, body } -> [Public, Refused, Other, BadBody]` | New tag `BadBody` |
| `PrivacyGuard.bad_body` | `{ url : Str } -> Fail` | New. Kind `Network` (15) |
| `PrivacyGuard.check!` | same | `BadName` gives `Github.bad_repo` with no call. `BadBody` gives `bad_body`. A public answer is written at once (G-C40) |

The private helpers of the two files (`load_copy!`, `fetch!`, `write!`, `repo_of`, `from_path`, `checked`) are removed from the stubs. The code agent writes the new helpers.

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/RegcacheTest.roc` (driver `l0-2.roc`), 7 `expect`s (4 changed, 1 new): meta round trip with the 4 forms (changed); `max_age_of` with `s-maxage` and `stale-while-revalidate` rows (4 rows added); `keep` (12 rows, was 7); `plan` (22 rows, was 14); `unusable` (new). The dir and key row and the `read_headers` row do not change | R-IX2, R-IX3, R-IX7, R-AP24, R-AP43, R-AP54 |
| L0 | `tests/unit/PrivacyTest.roc` (driver `l0-2.roc`), 7 `expect`s (3 changed, 3 new): `repos_to_check` (now `Try`); the forms, case and header rows (new); `BadName` (new); `repo_file` with a row in upper case; `verdict` with 7 `BadBody` rows added; `refusal` (no change); `bad_body` (new) | R-RG4, R-RG5, R-RG6, R-EC2, R-AP28 |
| L2 | `registry/ap24-read-cache`: runs 16 to 24 added (9 runs, 24 in all): `acme/noetag` (3 runs), `acme/noage` (3 runs), `acme/redir` (2 runs), `acme/nm304` (1 run) | R-IX2, R-IX7, R-AP24, R-AP54, R-E6 |
| L2 | `registry/rg4-guard`: runs 14 to 21 added (8 runs, 21 in all): case, forms, typed unsafe name, header unsafe names, `nobool`, `nojson`, public then private, then the read of the kept answer | R-RG4, R-RG5, R-RG6, R-EC2, R-AP28 |

No change of `tests/commands/L2Registry.roc`: the existing words `get` and `guard` are enough.

## Readings and decisions that the design does not fix (for the review)

| # | Decision | Rejected |
| --- | --- | --- |
| 1 | `parse_meta` gives `Err(BadMeta)` for a text with no `url` line, or a `max-age` that is not a number. Q218 does not say what a damaged meta is. The old test had `""` as `BadMeta`, so the empty text stays a bad meta | A meta that is never bad |
| 2 | "No `max-age`: never fresh" is read as: the copy is kept (the design says a copy with no `max-age` line exists, and R-IX6 uses copies at any age). So a 200 with no ETag and no max-age is kept too, as a file with the line `url` only. Only `no-store` stops a keep | Keep only a 200 with an ETag or a max-age |
| 3 | The `Source` variant `Repo` is the "typed name". `Group` and `Url` are the names from a header or a dependency. Only `Repo` gives exit 2 for an unsafe part | A typed group form with exit 2 |
| 4 | A `Url` or `Group` text is read with the prefix `https://github.com/` or `github.com/`. Other schemes and hosts (`http://github.com`, `www.github.com`, a host in another case) are not tested | Test them: the design says only "the host `github.com`" |
| 5 | A text with only 1 path part (`github.com/acme`), and a typed name that is not 2 parts, are not tested | Choose an exit code |
| 6 | The texts of `unusable` and `bad_body` (proposals, TW24, below) | A reuse of `Registry.no_answer` |
| 7 | `verdict` reads `private` only as a member of the top object. A nested `private` is not read (an L0 row) | A search in all levels |
| 8 | A 304 with the copy rewritten keeps the old ETag and the old max-age line (also when the 304 has a `Cache-Control`). This is the 202 behavior (R-IX2 "writes the meta again"), and it is not new | Read the 304 headers |

## Output (proposed, TW24)

| Case | Kind | Message |
| --- | --- | --- |
| 3xx, or a 304 to a request with no `If-None-Match` | network (15) | `the registry <origin> gave the answer <status> for <path and query>, and Talon cannot use it. Try again later.` |
| 200 with no boolean `private`, or not JSON | network (15) | `the answer of GitHub for <api>/repos/<owner>/<repo> is not a repository answer: it has no member private that is true or false. Try again later.` |
| Unsafe typed name | usage (2) | `'<owner>/<repo>' is not a GitHub repository name` (`Github.bad_repo`, slice 076) |

## Out of scope

| Item | Reason |
| --- | --- |
| Which command sends which `Source` | Slices 206, 208, 212, 217 |
| The case of the release pages dir (R-DI2 keeps its own dir) | Design Q219 row 2 says so, and no code of this slice reads it |
| A 3xx on the guard request to GitHub | `verdict` gives `Other` and `Github.status_failure`: the old row (301) stays |

## Questions (stop until answered)

None. The decisions above are for the review.

## Disputes (from the code agent)

None.

## Green result (code agent)

L0 l0-2: 75 pass. L2 registry/ap24-read-cache and registry/rg4-guard pass. `scripts/test.sh l2`: 242 pass, 17 fail (only ptool/* and gc/gc6). Code: `research/slice-202b-revert/code-final/`.

Choice not fixed by the slice: a typed `Repo` name that is not 2 parts is skipped (the old 203 behavior, decision 5), not `BadName`.

## Red result

| Layer | Result |
| --- | --- |
| L0 (`roc test tests/unit/l0-2.roc --no-cache`) | 75 expects: 65 pass, 10 fail. `RegcacheTest`: the meta, keep, plan and unusable rows fail with `todo: slice 202b`. `PrivacyTest`: `repos_to_check` (3 expects), `verdict`, `bad_body` fail with `todo: slice 202b`, and `repo_file` fails by value (no lower case). |
| L2 (`tests/commands/run.sh registry/`) | `registry/ap24-read-cache` and `registry/rg4-guard` fail with `[ROC CRASHED] todo: slice 202b`. The whole L2 run: 240 pass, 19 fail: these 2 and the 17 of slices 092 and 093 (`ptool/*`, `gc/gc6`) |

Logs: `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red202b-l0.log` and `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red202b-l2.log`.

## Revert check

A private green reference of the 2 modules passed all 75 L0 expects and both L2 cases (the expected files come from it). 6 mutations of it, each caught (the reference is deleted):

| # | Mutation | L0 | L2 |
| --- | --- | --- | --- |
| M1 | A copy with no ETag that is expired revalidates (`Revalidate("")`) | fail | fail |
| M2 | `s-maxage` is read as a max-age | fail | fail |
| M3 | The names are not lower case | fail | fail |
| M4 | A 200 with no `private` is `Refused` (the old 203 choice) | fail | fail |
| M5 | A 304 to a request with no `If-None-Match` is not an error | pass | fail |
| M6 | An unsafe part in a header name is an error (exit 2) | fail | fail |

`research/slice-202b-revert/before/` has the changed files (and the old cases) and `NEW.txt`.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo: slice 202b"` | None |
| Tests (code agent) | l0-2 75 of 75. `registry/ap24-read-cache` and `registry/rg4-guard` pass. L2 242 pass. The 17 failures are `ptool/*` and `gc/gc6` (slices 092 and 093). |
| Expected exits | Checked at the test step: all are rules (15 for a 3xx, an unasked 304, a body with no `private` or not JSON; 2 for a typed name with an unsafe part). |
| Revert check | Test step: M1 to M6 caught. |
| Open | A typed repo name that is not 2 parts is skipped (as in 203). Sent to the design agent as G-C41. |
