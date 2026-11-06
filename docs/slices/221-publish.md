# 221 Publish

Phase: P2 (CLI client). Status: done (closed 2026-11-03).

Plan row 221 of `PLAN-P2-CLI.md`. `tln publish` (R-CM13): the release of the tag of the job, the OIDC token, the request `POST /v1/releases` with `{url, compat}`, the retries of R-AP34, the exit codes of R-E6. Not in this slice: the API check with `roc bump` (slice 222, R-PU39).

## Rules

R-CM13, R-TP2, R-TP17 (the audience), R-AP8 (client), R-AP26, R-AP27, R-AP34, R-AP71, R-PB5, R-PU2, R-PU5, R-PUB1, R-PUB2, R-PUB3, R-EC2 (publish cases), R-E6, R-J7. Named also: R-DI3 to R-DI5, R-DI13, R-RG3, R-EV19, R-TF3, R-DA9, R-AP22, R-AP51, R-OUT2, R-OUT4.
Design: CLI 1 (`tln publish`: R-PUB1 to R-PUB3), CLI 3 (R-E6 and its example); Registry 4 (R-AP8, R-AP26, R-AP27, R-AP34, R-AP71), 7.1 (R-TP2, R-TP17); Resolution 4 (R-PB5); Design Q32, Q190, Q202, Q203.
Gaps of the plan: G-C3 is answered (Q190, R-AP71), G-C6 is answered (Q202, R-PUB1, R-PUB2), G-C7 is answered (Q203, R-PUB3), G-C11 is answered (R-TP17: the audience is the base URL form). Questions Q1 to Q13 are answered (Design Q507 to Q520, CLI R-PUB4).

## Reuse (no second copy)

| Need | Reused | New |
| --- | --- | --- |
| Headers, refusal, the kind and `details` of an answer, no answer | `Registry.headers`, `Registry.refuse` (`method: Post`), `Registry.no_answer`, `Registry.retry_after_of` | `Publish.failure` changes only the 3 texts of the CLI 3 example and adds `<n> times` |
| The candidate of the release (R-DI3 to R-DI5) | `Index` (the private asset reader may become public), `Ident.of_url` | `Publish.asset` (the cases that name the stop) |
| GitHub rate limit and status | `Github.rate_limit`, `Github.rate_limit_failure`, `Github.status_failure`, `Net.headers`, `Net.token` | none |
| The wire | `records.Compat.encode_publish`, `records.Release.decode` | none |
| The facts of a hash | `Db.Query` `FactsOf` (slice 217), `Db.on_err` | `Publish.facts` (which rows go) |
| The wait | `Fx.sleep!` | `Publish.next` (the schedule) |
| The registry setting | `ShareAccountFlow.start!` steps (`Roots.of_run!`, `Share.setting`, `Net.registry`) | none |

## Public signatures (stubs, `crash "todo: slice 221"`)

| Name | Signature | Rule |
| --- | --- | --- |
| `Publish.job` | `List((Str, Str)) -> Try(Publish.Job, Fail)` | R-PUB1, R-AP27 |
| `Publish.oidc` | `List((Str, Str)) -> Try(Publish.Oidc, Fail)` | R-AP27, R-TP2 |
| `Publish.release_url` | `{ api, owner, repo, tag } -> Str` | R-PUB2 |
| `Publish.asset` | `{ api, owner, repo, tag, now, reply } -> Try(Str, Fail)` | R-PUB2, R-DI3 to R-DI5, R-DI13 |
| `Publish.token_request`, `Publish.token` | `{ oidc, origin } -> Publish.Request`, `Publish.Reply -> Try(Str, Fail)` | R-TP2, R-TP17 |
| `Publish.facts` | `{ hash, stored : List(Db.Fact) } -> List(Publish.Fact)` | R-PU5, R-PB5, R-AP71 |
| `Publish.request`, `Publish.no_facts` | `{ origin, version, token, url, facts } -> Publish.Request`, `Str -> Str` | R-AP8, R-AP26, R-AP71, R-PUB3 |
| `Publish.next` | `{ retries, renewed, reply } -> [Done, Renew, Wait(U64), Stop]` | R-AP34 |
| `Publish.failure` | `{ origin, version, tries, reply } -> Fail` | R-E6, R-AP22, R-J7 |
| `Publish.answer`, `lines`, `data`, `direct` | see the doc of `cli/lib/Publish.roc` | R-AP8, R-AP51, R-OUT2, R-OUT4, Q32 |
| `PublishFlow.run!` | `Fx, Args => I32` | R-CM13 |

Edits to existing files (copies in `research/slice-221-revert/before/`): `cli/lib/main.roc` (2 exposes), `cli/lib/Run.roc` (the import and the branch `["publish"]`), `tests/unit/l0-6.roc` (1 import). New: `cli/lib/Publish.roc`, `cli/lib/PublishFlow.roc`, `tests/unit/PublishTest.roc`, `tests/tools/mk-publish.sh` (makes the 9 L2 cases), `tests/commands/cases/publish/pu1` to `pu9`. No L2 harness change (the entry `commands` has `env:` words for each run). No file of the 206e3b agent was edited.
The code agent must also do (no test can reach it before the code): `Opts.reads_registry` gets `["publish"]` (R-FL5: the flag `--registry <url>` is not refused; the L2 cases use `TALON_REGISTRY`, so no test needs it). It needs a change in `Opts.roc`: not done, the manager decides.

## The flow (my reading, for the review)

Steps in the doc of `PublishFlow.roc`. Order of calls in `calls.log` (the L2 cases fix it): `args`, `env_all` (the first-run gate: `CI=true` skips it), `env_all`, `read_files config.toml`, `http_get` of the release, `db_query facts_of=<hash>`, `http_send GET` (the token), `http_send POST` (the publish), then `sleep` and the same POST for a retry, or the token request again for a 401.

| Reading | Why |
| --- | --- |
| All checks without a request (registry, `GITHUB_REPOSITORY`, `GITHUB_REF`, the OIDC variables) come before the first request, in this order | R-AP27 "sends no request when it has no OIDC token", R-PUB1 "before any request". Only one fault at a time is tested (Q1). |
| The facts query comes before the token request | The token lives a few minutes: it is fetched as late as possible |
| The retry reuses the token. Only a 401 gets a new one, once | R-AP34 |
| A good answer must decode as a release (`Release.decode`) | R-AP51, R-E6 |

## Tests

| Layer | Where | Rules |
| --- | --- | --- |
| L0 | `tests/unit/PublishTest.roc` (driver `l0-6`) expect 1: `job` | R-PUB1, R-AP27, R-EC2 |
| L0 | expect 2: `oidc` | R-AP27, R-TP2 |
| L0 | expect 3 to 6: `release_url`, `asset` (good, 404, draft, prerelease, no asset, 2 assets, no version, 5xx, no answer, rate limit) | R-PUB2, R-DI3 to R-DI5, R-DI13 |
| L0 | expect 7, 8: `token_request`, `token` | R-TP2, R-TP17 |
| L0 | expect 9: `facts` (4 outcomes, build row, target, other hash) | R-PU5, R-PB5, R-AP71 |
| L0 | expect 10, 11: `request` (body exact, with and without `compat`), `no_facts` | R-AP8, R-AP26, R-AP71, R-PUB3 |
| L0 | expect 12, 13: `next` (schedule, `Retry-After`, 60 s, renew, stop) | R-AP34 |
| L0 | expect 14 to 16: `failure` (the 3 CLI 3 texts, the codes 20, 1, 15, `details`, no answer) | R-E6, R-AP22, R-J7 |
| L0 | expect 17 to 19: `answer`, `lines`, `data`, `direct` | R-AP8, R-AP51, R-OUT2, R-OUT4, Q32 |
| L2 | `publish/pu1-publish-ok`: 201, 200, `--json`; the 4 facts; the calls | R-CM13, R-PB5, R-PU2, R-PU5, R-TP2, R-TP17, R-AP8, R-AP26, R-AP71 |
| L2 | `pu2-no-facts`: no `compat` member, the warning | R-PUB3 |
| L2 | `pu3-usage-stops`: direct, empty repository, branch ref, no OIDC URL: exit 2, no request | R-EC2, R-PUB1, R-AP27 |
| L2 | `pu4-no-release`: 404, exit 2, no token request | R-PUB2 |
| L2 | `pu5-compat-too-new`: exit 19 before the token request | R-TF3 |
| L2 | `pu6-retries`: 429 with `Retry-After: 7`, 503, no answer, then 201: 3 sleeps | R-AP34, R-AP82 |
| L2 | `pu7-retries-exhausted`: 4 times 502, exit 15, `4 times` | R-AP34, R-AP22, R-E6 |
| L2 | `pu8-renew-401`: a new token, no sleep | R-AP34, R-TP2 |
| L2 | `pu9-refused`: 409 and 403: exit 20, the first 2 texts of the CLI 3 example | R-E6, R-J7 |

The expected files were written by hand (`tests/tools/mk-publish.sh`); no reference implementation was built, so the L2 expected files have not run against code. Not tested: the third text of the example is L0 and `pu7`.

## Output (proposed, R-OUT2, TW24)

| Text | Form |
| --- | --- |
| 201 | `published <owner>/<repo> <tag>: <hash>, <n> facts sent` (`1 fact`, `no facts sent`) |
| 200 | `<owner>/<repo> <tag> is published already: <hash>, <n> facts sent` |
| `data` | `{"publish":{"repository","tag","hash","created","facts"}}` |
| No fact | stderr `warning: no probe facts for <hash>: run tln probe --range <bundle file> before tln publish` (the text of R-PUB3, the `warning: ` prefix is mine) |
| `direct` | `tln publish needs a registry, and the registry is direct. Set --registry, TALON_REGISTRY or registry in config.toml.` |
| Variables | `GITHUB_REPOSITORY is not set or is empty. tln publish runs in a GitHub Actions job.` (also `GITHUB_REF`), `GITHUB_REF is <ref>, not a tag. The job must run on a tag: tln publish registers the release of the tag.` |
| No OIDC | `tln publish needs an OIDC token, and <NAME> is not set. In a GitHub Actions job, set permissions: id-token: write.` |
| The release | the 404, draft, prerelease, no asset, 2 assets, no version texts of the doc of `Publish.asset` |
| Refused | the 3 texts of CLI 3 (label-conflict, forbidden, 502 `4 times`); another refusal keeps the text of `Registry.refuse` |
| No answer | `the registry <origin> gave no answer 4 times: <why>. Try again later.` |

## Out of scope

| Item | Why |
| --- | --- |
| `roc bump` and the warning | Slice 222 |
| The queue send (R-SH4) at the end of `tln publish` | Q12 |
| `tln yank`, `tln move` | P3. They will reuse `Publish.next` and `Publish.failure`. |

## Questions (stop until answered)

Manager (2026-11-03): Q1 to Q13 went to TalonRegistry as G-C140 to G-C152 (in this order); G-C153 asks for `publish` in `Opts.reads_registry`. The code step waits for the answers.

| # | Question | Why it is open | What is not tested or is a reading | Answer and test change |
| --- | --- | --- | --- | --- |
| Q1 | The order of the exit-2 stops when 2 are true (for example no OIDC variable and a branch ref), and the order of the OIDC variable check against the release read (R-PUB2 says the release stops come "before the OIDC token is read"; R-AP27 says no request without a token) | R-PUB1, R-PUB2, R-AP27 | Reading: variables first, then the release read. `pu3` has one fault in each run. Only `Publish.job` (repository first) is fixed in L0. | Answered (Q507, R-PUB4 item 1): as the reading. Test change: add an L2 case with 2 faults (no OIDC variable and a branch ref: the ref first); one with a missing permission and no release: the permission first |
| Q2 | `--offline`, an operand, `--file` with `publish` | Not in R-CM13 | Untested | Answered (Q508, Q520): `--offline` exit 15, operand exit 2, `--file` accepted, `--registry <url>` read. Test change: 3 L2 runs; `Opts.reads_registry` gets `publish` (G-C153) |
| Q3 | The `error_digest` of each fact: `compat.db` has the failing modules, no digest (R-AP58) | R-AP71 wants a required member, text or null | Reading: `null`. Pinned in L0 `facts` and `pu1`. | Answered (Q509): `null`. No test change |
| Q4 | More than 500 facts for one hash (R-AP71, R-AP46 limit): send the first 500 (which), or stop | Not given | Untested | Answered (Q510): the 500 newest facts and a warning. Test change: an L0 `expect` with 501 facts (500 sent, the oldest nightly dropped); an L2 run with the warning |
| Q5 | The timeout of `POST /v1/releases`: the Worker reads the archive (CPU up to 5 s, R-PU38) and GitHub | R-DA9 gives 20 s for a small request | Reading: 20 s. Pinned in the `calls.log` lines `timeout=20`. | Answered (Q511): 20 s. No test change; the last text says that the publish may be done |
| Q6 | A `GITHUB_REPOSITORY` that is not `owner/repo` | Not in R-PUB1 | Untested | Answered (Q512): exit 2 for a form that is not `owner/repo`. Test change: an L0 `expect` for `a`, `a/b/c`, `/b`, `a/` and a space; an L2 run |
| Q7 | The `audience` in the token URL: as the text B (reading), or percent-encoded (R-AP69 `Registry.encode`) | R-TP2 writes `&audience=<registry base URL>`, no encoding rule | Reading: as it is. Pinned in L0 `token_request` and the `http_send GET` line of each L2 case. | Answered (Q513): percent-encoded. Test change: L0 `token_request` and the `http_send GET` line of each L2 case change to `audience=https%3A%2F%2F<host>` |
| Q8 | The tag in the path of the release request (a tag with `/` or a space) | R-PUB2 | Reading: as it is. Untested (the tags are `2.1.0`). | Answered (Q514): a tag that is not one safe path part is exit 2 before any request. Test change: an L0 `expect` for `pkg/v1`, `v 1` and `v%1`; the tags of the cases (`2.1.0`) stay |
| Q9 | The token answer: GitHub gives `{"count":1,"value":"<JWT>"}` (not in the design). The exit code of a failed token request (no answer, 403, no `value`) | R-TP2 | Reading: member `value`; failure is 15. L0 `token` only. | Answered (Q515): `value`; no answer, 5xx, 429, no `value`: exit 15; 401 or 403: exit 2 with the permission text. Test change: L0 `token` rows for 403 (exit 2), no `value` (15), no answer (15); an L2 run with a 403 |
| Q10 | The text of the 429 and of the 503 `/errors/busy` after 4 requests, and of a 401 after a new token | CLI 3 gives the 502 text only | Reading: the 429 end is `Registry.refuse`, busy is as `Registry.refuse`. Untested. | Answered (Q516): `Registry.refuse` texts with `after 4 requests`; a 401 after the new token is exit 20 with the new-token words. Test change: L2 runs for 429 x4, 503 x4 and 401 x2: the stderr text and the exit |
| Q11 | A `Busy` or `Failed` read of `compat.db` (R-CC8): the reading of slice 217 is a warning and no facts, then the publish goes with no `compat` | R-PUB3 covers no fact, not a failed read | Untested (`pu5` is `TooNew`: exit 19, R-TF3) | Answered (Q517): a warning and no `compat` member. Test change: an L2 run with a busy `compat.db`: the warning, a body with no `compat`; `pu5` (newer format, exit 19) stays |
| Q12 | Does `tln publish` run the queue send (R-SH4: "a command that sent a registry request")? In a job `CI` turns sharing off (R-SH2 condition 5) | R-SH4 | No test | Answered (Q518): no queue send. Test change: an L2 run with a non-empty `share_queue`: no second request after the publish |
| Q13 | A `Retry-After` that is not a whole number (an HTTP date) or is above 60 s: reading is the schedule for a text and 60 s for a number above 60 (R-AP34 "at most 60 s"); `0` | R-AP34 | L0 `next` pins both readings (`soon` gives 2000, `120` gives 60000) | Answered (Q519): the readings agree. No test change (L0 `next` pins `soon` 2000, `120` 60000); add `0` gives 0 |

## Disputes (from the code agent)

None. The 3 fake `Fx` cases that the test agent doubted (`env:NAME=` empty, `fx/db` rule `1: busy`, `error timeout` in `.POST.3`) and the `pu14` call list all work. No test, fixture or expected file was changed.

## Code

| File | Change |
| --- | --- |
| `cli/lib/Publish.roc` | All pure decisions. Reuse: `Registry.headers`, `refuse`, `problem`, `wait_text`, `no_answer`, `retry_after_of`, `encode`; `Github.rate_limit`, `rate_limit_failure`, `status_failure`; `Compat.encode_publish`; `Release.decode`; `Ident.of_url`; `Db.outcome_word`; `Index.assets_of`; `ProbeShare.by_text`. New private helpers in the block: `max_facts`, `env_var`, `safe_name`, `no_oidc`, `unreachable`, `flag`, `download_url`, `wait`, `no_reply`. |
| `cli/lib/PublishFlow.roc` | Direct-style flow, steps 1 to 8 of its doc. `post!` is recursive: `Wait` is `sleep!` and the same request, `Renew` fetches a new token once. |
| `cli/lib/Index.roc` | New public `assets_of` (a wrapper of the private `package_assets`), 4 lines. |
| `cli/lib/ProbeShare.roc` | New public `by_text` (a wrapper of the private `text_order`), 4 lines. |
| `cli/lib/Opts.roc` | `["publish"] => Bool.True` in `reads_registry` (Q520). |

Review notes:

- `job` checks: repository missing, repository form, ref missing, ref not a tag, tag safe. This puts a bad repository before the ref, as the doc says. The table in the doc of `Publish.job` lists the form check after the ref check: the two orders differ only for a run with 2 faults, and no test has that.
- The clock: `fx.clock!` is read only for a 403 or 429 answer of the release read (for `Github.rate_limit`). The L2 `calls.log` files have no `clock` line, so the call must not be made on a good run.
- The `gh auth token` source is asked (`Github.ask_gh!`) only when `TALON_GITHUB_API` is not set and no `GITHUB_TOKEN`/`GH_TOKEN` exists (as `Github.releases!`).
- `Publish.token` treats an empty `value` as no token.
- A body of the release read that is not an object, or an asset with no `browser_download_url`, is `Github.status_failure` (15).
- `Ident.of_url` of an asset URL that was accepted by `Publish.asset` cannot fail; the flow maps `Foreign` to an `Internal` failure for completeness.

## Verify results

Code agent run, 2026-11-03: `roc test tests/unit/l0-6.roc` 117 passed (23 expects of PublishTest). L2 `publish/pu1` to `pu15` all pass. `scripts/test.sh check fmt l0 l2 l3`: check, fmt, l0, l3 pass; l2 has 1 failure, `registry/cm7-why-pin-unset` (the Why code of the slice 206e3b agent, mid-work; its `list_dirs` call is not mine). TW20 warning: l0 13.2 s over 10 s.

Red state: see the report of the test agent.

## Round 2 (answers Q507 to Q520, CLI R-PUB4)

All 13 questions are answered (see the column "Answer and test change" above, added by the design owner). Test changes made:

| Answer | Change | Where |
| --- | --- | --- |
| Q513 | The audience is percent-encoded: `audience=http%3A%2F%2F127.0.0.1%3A9` | L0 `token_request`; the `http_send GET` line of each L2 case |
| Q515 | `Publish.token`: 401 and 403 are `Usage` with the `id-token: write` text; 429, 5xx, no answer, no `value`, a body that is not JSON are 15 | L0 `token`; L2 `pu11-token-refused` |
| Q507, Q508 | Order: direct, `--offline` (15), operand (2), repository and ref, OIDC variables, release. New `Publish.offline`, `Publish.operand` | L0; L2 `pu3` (11 runs, one fault or two) |
| Q512, Q514 | `Publish.job` checks the form of the repository and a safe tag | L0 `job`; L2 `pu3` (`acme/json/x`) |
| Q510 | `Publish.facts` gives `{ list, warning }`: the 500 newest nightlies and one warning | L0 (501 facts, 500 facts); L2 `pu15-over-500` |
| Q511 | A cut request is sent again (L0 `next` had it); the last text says the publish may be done: `the registry <origin> gave no answer 4 times: <why>. The publish may be done. Run the command again.` | L0 `failure` |
| Q516 | `Publish.failure` has the member `renewed`. 429 and busy 503 after the retries: `after 4 requests`. A 401 after the new token: exit 20, `<detail> (<type>): the registry refused the new token too.` | L0 `failure`; L2 `pu12-renew-twice` |
| Q517 | `Publish.unread(cause)`: one warning, no `compat`, no `no probe facts` line | L0; L2 `pu13-db-busy` (`fx/db` rule `1: busy`) |
| Q518 | No queue send | L2 `pu14-no-queue-send` (share on, a queue row, `CI` empty: `tty` call, no queue calls) |
| Q519 | A date is ignored, 0 is 0 | L0 `next` |
| Q520 | `publish` in `Opts.reads_registry` and `--file` accepted | L2 `pu10-flags` (`--file p/main.roc`; `--registry http://127.0.0.1:9` with an empty `TALON_REGISTRY`). The code agent edits `Opts.roc` (not me: 206e3b works in it). |
| Q509, Q511 (20 s) | No change | |

New proposals (R-OUT2): `tln publish needs the network: --offline sends no request`; `tln publish takes no argument: '<operand>'`; `GITHUB_REPOSITORY is <value>, not of the form owner/repo.`; the unsafe tag text `the tag <tag> is not one safe part of an asset URL: use letters, digits, . _ - + ~. Name the tag with a version.`; the token refused text `the GitHub OIDC token request was refused (<status>). The job needs permissions: id-token: write.`; the 500 cap warning (R-PUB4 item 4); `compat.db could not be read (<cause>): publishing with no probe facts`; the `after <n> requests` texts and the new-token text.

Readings (no design text): the tag check text (R-PUB4 item 8 says "the message of R-PUB2 for a URL that R-DI5 refuses", but no URL exists yet, so the text names the tag); the cap warning comes with `warning: ` on stderr; the warning of a busy `compat.db` replaces the `no probe facts` line; `--registry direct --offline` is exit 2 (direct first); an unsafe tag is tested in L0 only.

Expected exits (read): `pu1` 0 x3; `pu2` 0; `pu3` 2, 2, 15, 15, 2, 2, 2, 2, 2, 2, 2 (rules R-EC2, R-PUB1, R-PUB4, R-AP27; the 15 is `--offline`, R-PUB4 item 1); `pu4` 2 (R-PUB2); `pu5` 19 (R-TF3); `pu6` 0; `pu7` 15 (R-E6, R-AP34); `pu8` 0; `pu9` 20, 20 (R-E6); `pu10` 0, 0; `pu11` 2 (Q515); `pu12` 20 (Q516); `pu13` 0; `pu14` 0; `pu15` 0.

## Close (manager, 2026-11-03)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-221-revert/code-final.sha256` | OK, 5 files |
| `grep "todo: slice 221" cli/` | nothing |
| Expected exits (read) | pu3 2, 2, 15, 15, 2 x7 (Q507, Q508, Q512, R-PUB1, R-PUB2); pu4 2; pu5 19 (R-TF3); pu7 15 (R-AP34); pu9 20, 20 (R-E6); pu11 2 (Q515); pu12 20 (Q516); the others 0. Each non-zero exit is the rule of its run |
| L2 `publish/pu1` to `pu15` | 15 pass (manager run) |
| `scripts/test.sh check fmt l0 l2 l3` (code agent) | all pass except `registry/cm7-why-pin-unset` (slice 206e3b round 2, code in progress). The manager runs the full set again at the 206e3b close |
| Hand-written expected files | never run before the code; all passed with no dispute, including the 3 fake `Fx` forms the test agent doubted |
| Code doubts | Accepted: the `Publish.job` order (repository form before the ref; one fault per test); `clock` only after a 403 or 429; an empty token `value` is no token; a bad release body is exit 15. Wrappers `Index.assets_of` and `ProbeShare.by_text` reuse private code |
| For the human review | The proposed texts and `data.publish` (sections Output and Round 2) |

