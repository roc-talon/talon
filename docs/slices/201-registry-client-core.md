# 201 Registry client core

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 201 of `PLAN-P2-CLI.md`. Pure, L0 only. The module is `cli/lib/Registry.roc`. It uses the wire types and codecs of the package `records` (R-PK7): `cli/lib/main.roc` has the new dependency `records: "../../packages/records/main.roc"` (a path entry to a Talon package is allowed, not to a generic package). `tests/commands/` needs no change: its app imports `lib`, and `lib` imports `records`. Name clash: `cli/lib/Closure.roc` and `records.Closure` have one name, so `Registry.roc` writes `import records.Closure as Wire`.

## Rules

R-E6, R-J7, R-AP21, R-AP22, R-AP45 (the `unsupported-client` message and the `User-Agent`), R-AP46 (the `too-large` message), R-AP51 (the reader), R-AP69 (the URL function), R-AP1, R-AP2, R-AP13 (the URLs), R-AP23 (media type), R-AP52 (unknown problem type), R-PK7 (CLI side), R-EC15, R-EC20.

## Public signatures (stubs, `crash "todo: slice 201"`)

| Name | Signature |
| --- | --- |
| `Registry.base` | `Str -> Try(Str, [BadRegistry])`: R-RG7 rows 1 to 3 and 6, the base URL form of a setting. The builders below take this form and add the route path (row 5) |
| `Registry.encode` | `Str -> Str`: R-AP69, each byte outside `A-Z a-z 0-9 - . _ ~` is `%` and 2 upper-case hex digits (UTF-8 bytes) |
| `Registry.releases_of_repo_url` | `{ origin, owner, repo } -> Str`: R-AP1, lower-case ASCII name |
| `Registry.artifact_url` | `{ origin, hash } -> Str`: R-AP2 |
| `Registry.releases_url` | `{ origin, group, series : Try(Str, [None]) } -> Str`: R-AP13, order group then series |
| `Registry.closure_url` | `Str -> Str`: R-AP16 |
| `Registry.headers` | `{ version, body : [None, Json] } -> List((Str, Str))` |
| `Registry.problem` | `Registry.Reply -> Try(Problem.Body, [NotProblem])` (`records.Problem.decode`) |
| `Registry.refuse` | `{ origin, version, method : [Get, Post, Put, Delete], reply : { status : U16, body : Str } } -> Fail` |
| `Registry.no_answer` | `{ origin, why } -> Fail` |
| `Registry.closure_answer` | `{ origin, body } -> Try(Wire.Answer, Fail)` (`records.Closure.decode_answer`) |

The types `Registry.Method` and `Registry.Reply` are aliases. The doc of each stub is the contract.

## Tests

| Layer | File and case (`tests/unit/RegistryTest.roc`, driver `l0-8.roc`) | Rules |
| --- | --- | --- |
| L0 | `base`: 10 good settings (upper case, default port, loopback, IPv6, trailing `/`) and 18 bad ones (`http` to another host, path, query, fragment, user info, bad port, `direct`, empty) | R-RG7 rows 1 to 3 and 6, R-RG8 |
| L0 | URLs: `encode` (space, `+`, `~`, UTF-8 `é`, `/`, `%`, `{`, `}`), the 3 read URLs with the real bytes of `worker/tests/cases/reads/ap13-group-series-after`, lower-case name, hash case kept, closure URL | R-AP1, R-AP2, R-AP13, R-AP69, R-AP16, R-PK7 |
| L0 | Headers: `User-Agent: tln/<v>`, `Content-Type` only with a body | R-AP45, R-AP23 |
| L0 | `problem`: known type with `minimum`, `too-large` with `field` and `limit`, unknown type kept, HTML body, body with no `status` | R-AP21, R-AP52, R-AP22 |
| L0 | The R-E6 table: 25 rows of (method, status, body) to the exit code | R-E6, R-EC15, R-EC20, R-AP22, R-AP52 |
| L0 | `error.details`: `status` and `type` as read, `status` only with no problem details, none for no answer | R-J7, R-AP52 |
| L0 | The texts (below) | R-E6, R-AP45, R-AP46 |
| L0 | The reader: a good answer with an unknown member, a missing member (the message names it), `null`, a wrong type, not JSON: exit 15, the message names the registry | R-AP51, R-E6, R-AP44, R-PK7 |

Red result: 8 `expect`s fail with `todo: slice 201` (log `/tmp/claude-1000/-home-george-dev-Karakatiza666-talon/50006c73-0c1a-496a-8ab0-5dde076210ac/scratchpad/red.log`). The L0 run also has the `todo: slice 205` fails of slice 205 and a compile error in `cli/lib/ToolBin.roc` of another agent.

Revert check (`research/slice-201-revert/before/`; the reference and `mutate.py` are deleted): reference green, then 6 mutations (and 3 of `base`: the default port, the loopback rule, the path check) each caught except one equal mutant (the path check of `base` is also done by the host check): M1 lower-case hex, M2 member order of R-AP13, M3 owner not lower-cased, M4 413 not exit 1, M5 a read counted as a write, M6 `details.type` missing.

## Output (proposed, R-OUT2, TW24)

| Case | Kind | Message |
| --- | --- | --- |
| 400 `unsupported-client` with `minimum` | internal | `tln <version> is too old for <origin>: update to <minimum> or later` (CLI 3) |
| 413 `too-large` | internal | `the registry <origin> refused the request: <field> is over the limit of <limit>` |
| 400, 405, 415, and other statuses of this row | internal | `the registry <origin> refused the request (<type>): <detail>. This is a fault of tln <version> or a version skew.` (no `detail`: the `title`) |
| 401, 403, 404, 409, 422 to a write | rejected | `<detail> (<type>). Fix the release or the workflow, then run the command again.` (the text of R-EC20) |
| 429, 5xx, a read refused, other | network | `the registry answered <status> (<type>). Try again later.` |
| Error answer that is not problem details | network | `<origin> answered <status> and the answer is not problem details. Check the registry setting.` |
| No answer | network | `the registry <origin> gave no answer: <why>. Try again later.` |
| 2xx that does not decode | network | `the answer of the registry <origin> is not a closure answer: <decoder text>` (the decoder text of `records` names the member, for example `MissingRequiredField("log_size")`) |

`--json` `error.details`: `{"status": <int>, "type": <text>}`; `{"status": <int>}` with no problem details (proposal).

## Readings that the design implies (tested)

| # | Reading |
| --- | --- |
| 1 | The exit code comes from the HTTP status, not from the type (R-AP52 "maps it by its HTTP status"). A body that is not problem details is 15 for each status. |
| 2 | The cache key of R-AP69 row 3 uses the lower-case name, and R-AP69 says `tln` builds its URLs with the same function, so `releases_of_repo_url` lower-cases owner and repo. |
| 3 | The only headers are the 2 of R-AP45 and R-AP23. No `Accept` (the design has none). |

## Out of scope

| Item | Reason |
| --- | --- |
| Answers of R-AP1, R-AP2, R-AP13, R-AP14, R-AP5, R-AP7 | `records` has no type for them (G-C5, slice 104e). The reader of the closure answer is in scope. |
| `Fx` calls, the media type of the real answer, the `User-Agent` on the wire, `http_send!` | Slice 200 (`Fx`) |
| `no-cache`, `Talon-Bookmark`, `If-None-Match`, the cache | Slice 202 |
| The retries of R-AP34 and their text (`4 times`) | Slice 221 |

## Questions

| # | Question | State |
| --- | --- | --- |
| Q1 | The base URL and the join with `/v1/...` | Answered (Design Q207, R-RG7, R-RG8): the RFC 6454 origin, no path, no trailing `/`. `Registry.base`, tested. |
| Q2 | `POST /v1/closure` refused with 401, 403, 404, 409, 422: exit 20 or 15 | Answered (Design Q194, R-AP74 row 1): a read, exit 15 (400 and 413 exit 1). Tested in slice 205b. |
| Q3 | `unsupported-client` with no `minimum` member | Answered (Design Q195, R-AP74 row 2): exit 1, text `tln <v> is too old for <origin>: update to the newest version`. Tested in slice 205b. |
| Q4 | The scheme of a registry setting | Answered (Design Q210, R-RG7 rows 1 and 6): `base` does the pure parse. The exit code from the source (2 for `--registry` and `TALON_REGISTRY`, 19 for `config.toml`) is a flow slice: `base` does not get the source. |

The closure-answer reader stays: it uses `records.Closure.Answer`, which exists.

## Disputes (from the code agent)

None yet.

## Verify results

Code agent: no mutation run yet (step 4 of the manager). L0 (`roc test tests/unit/l0-8.roc`): 106 passed. `roc check cli/main.roc` and `tests/commands/main.roc`: no errors. Code copy: `research/slice-NNN-revert/code-final/`.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| `crash "todo` of this slice | None |
| `roc test tests/unit/l0-8.roc --no-cache` | 106 pass, exit 0 (after the test agent renamed a local `groups` that gave a duplicate-definition warning, exit 2) |
| `roc check` of `cli/main.roc` and `tests/commands/main.roc` | No errors |
| Revert check | Test step: mutations caught, as listed in the test sections. The code step ran none (TW12). |
| Open | G-C24 to G-C29 (API design agent). The 2 or 19 exit code by the source of the setting goes to a flow slice. |
