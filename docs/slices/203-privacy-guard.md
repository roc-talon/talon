# 203 Privacy guard

Phase: P2 (CLI client). Status: done (closed by the manager, 2026-11-02).

Plan row 203 of `PLAN-P2-CLI.md`. The module is `cli/lib/PrivacyGuard.roc` (new, exposed in `cli/lib/main.roc`). It reuses `Github` (`index_dir`, `ask_gh!`, `rate_limit`, `rate_limit_failure`, `network_failure`, `status_failure`) and `Net` (`token`, `headers`). No change of the `Fx` record. No command calls it yet: slices 206, 208, 212 and 217 call `check!` before their first registry request. The L2 entry `registry` is in `tests/commands/L2Registry.roc` (shared with slice 202).

## Rules

R-RG3 (token rules and the test hook R-EV19 as they apply to this request), R-RG4, R-RG5, R-RG6, R-EC2 (the R-RG6 case), R-DI13 (the rate limit), R-DI12 (the network failure text).

## Public signatures (stubs, `crash "todo: slice 203"`)

| Name | Signature |
| --- | --- |
| `PrivacyGuard.Source` | `[Repo(Str), Group(Str), Url(Str), Short(Str)]`: the names that a request carries |
| `PrivacyGuard.repos_to_check` | `{ sources, offline, frozen } -> List({ owner, repo })`: the pure decision |
| `PrivacyGuard.repo_file` | `{ roots, owner, repo } -> Try(Str, [BadPart])`: `<index>/github/<owner>/<repo>/repo.json` |
| `PrivacyGuard.repo_url` | `{ api, owner, repo } -> Str`: `<api>/repos/<owner>/<repo>` |
| `PrivacyGuard.verdict` | `{ status, body } -> [Public, Refused, Other]` |
| `PrivacyGuard.refusal` | `{ owner, repo, token } -> Fail`: kind `Usage`, the 2 messages |
| `PrivacyGuard.check!` | `Fx, { net, roots, sources, offline, frozen } => Try({}, Fail)`. The doc has the table of the calls |

## Tests

| Layer | File and case | Rules |
| --- | --- | --- |
| L0 | `tests/unit/PrivacyTest.roc` (driver `l0-2.roc`), 4 `expect`s: `repos_to_check` (full name, group and URL of `github.com`, other hosts, `Short`, order, dedupe, `offline`, `frozen`); `repo_file` and `repo_url` (also the test hook base, an unsafe part); `verdict` (7 rows); `refusal` (kind and the 2 texts) | R-RG4, R-RG5, R-RG6, R-EC2 |
| L2 | `tests/commands/cases/registry/rg4-guard` (entry `registry`): 13 runs. Public with a token (one request, one write), the same again (a read, no request), private with a token (exit 2), 404 with no token (gh asked, no `Authorization`, exit 2), 404 with a token (exit 2), no call for `offline`, `frozen`, `short`, other hosts, 4 names for 3 repositories with one already kept, rate limit (exit 15), no answer (exit 15), the test hook (no token) | R-RG3, R-RG4, R-RG5, R-RG6, R-EC2, R-EV19, R-DI13, R-DI12 |

## Readings that the design implies (tested)

| # | Reading |
| --- | --- |
| 1 | A repository is a repository of `github.com` when its name comes from `Repo` (a typed full name), from a group `github.com/<o>/<r>/releases/download/...` or from a URL `https://github.com/<o>/<r>/releases/download/<tag>/<asset>`. |
| 2 | The 2 messages are chosen by the token of the request, not by the answer: with a token, both a `private: true` and a 404 give the first text. With no token only a 404 can come (GitHub never shows a private repository to a request with no token). |
| 3 | The files of all repositories are read with one `read_files!`. The token is asked once, before the first request. A repository with a file gets no request (R-RG5). |
| 4 | `TALON_GITHUB_API` (R-EV19) gives `Settings.token = Test`: no token and no `programs!` call, the URL base is that variable. The guard uses the same `Net.Settings` as the GitHub list. |
| 5 | A rate limit answer is R-DI13 (exit 15), a transport failure is R-DI12 (exit 15), as for the release list. Nothing is kept for them. |

## Output (proposed, TW24)

| Case | Kind | Message |
| --- | --- | --- |
| `Refused`, with a token | usage (2) | `GitHub repository <owner>/<repo> is private or does not exist. Private packages are not supported.` |
| `Refused`, no token | usage (2) | `GitHub repository <owner>/<repo>: not found, or private. Private packages are not supported. With no token GitHub answers 404 for a private repository: set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login), and run the command again.` |
| Rate limit, no answer, other status | network (15) | The texts of `Github.rate_limit_failure`, `network_failure` (for the URL `<api>/repos/<owner>/<repo>`) and `status_failure` |

## Out of scope

| Item | Reason |
| --- | --- |
| Which command sends which `Source` and when (before an ingest, `probe --share`, the closure) | Slices 206, 208, 212, 217. This slice gives the function. |
| R-MV3 (the guard checks the successor only) | The `tln move` slice, it chooses the sources |
| The order guard, ingest, closure again (R-AP28) | Slice 208 |
| The GitHub list that follows the guard (R-AD35 step 1) | Slice 212 |

## Questions (stop until answered)

| # | Question | State |
| --- | --- | --- |
| Q1 | Another form on `github.com` (a group `github.com/o/r/x`, `http://github.com`, `www.github.com`, a different case of the host), and a name that is not a safe path part (`..`, `a/b`): is it checked, skipped, or an error (`Github.bad_repo`, exit 2)? The reference skips all of them. No test names them. | Open, G-C39, untested |
| Q2 | A 200 answer with no `private` member, or a body that is not JSON: public, refused or an error? The reference treats it as refused. No test names it. | Open, G-C39, untested |
| Q3 | 2 or more repositories: the first is public, the second is private. Is the answer of the first kept? The reference writes each public answer at once. R-RG6 says only that the refused answer is never kept. No test names it. | Open, G-C40, untested |
| Q4 | The same repository in 2 cases (`Acme/Lib` and `acme/lib`): one check or 2 (GitHub names are case-insensitive, the dir name is the typed text). The reference compares the exact text. No test names it. | Open, G-C39, untested |

## Disputes (from the code agent)

None yet.

## Red result

L0: the 4 `PrivacyTest` `expect`s fail with `todo: slice 203` (see the log of slice 202). L2: `registry/rg4-guard` fails with `[ROC CRASHED] todo: slice 203`.

## Revert check

`research/slice-203-revert/before/` has the files that the slice changed and `NEW.txt`. `research/slice-203-revert/reference/PrivacyGuard.roc` is the private green reference. Mutations of the reference:

| # | Mutation | L0 | L2 |
| --- | --- | --- | --- |
| M1 | `offline` ignored by `repos_to_check` | fail | fail |
| M2 | A `Short` name is checked | fail | fail |
| M3 | A kept file does not stop the request | pass | fail |

## Verify results

Code agent, 2026-11-02: l0-2 all 71 pass, `registry/rg4-guard` passes. Revert check (TW12) not run by this agent. Decision: `check!` has no `now` in its facts. On a 403 or 429 answer with no `x-ratelimit-reset` header it calls `Fx.clock!` (for `retry-after`). With the header it makes no clock call, so the L2 log has no `clock` line.

## Close (manager, 2026-11-02)

| Check | Result |
| --- | --- |
| `sha256sum -c code-final.sha256` | OK |
| Tests (code agent) | l0-2 71 of 71. `registry/ap24-read-cache` and `registry/rg4-guard` pass. L2 242 pass. The 17 failures are `ptool/*` and `gc/gc6` (slices 092 and 093). Driver l0-4 does not compile because of the red `ToolbinlistTest.roc` of 092 and 093. |
| Expected exits (manager check) | Each exit other than 0 in the 2 cases is a rule (15: no answer or rate limit; 2: private or 404). |
| Revert check | Test step: 9 mutations caught. |
| Follow-up | 202b: Q218 to Q220 (G-C38 to G-C40). Some untested choices of this code differ from those answers (a 200 with no ETag, names in lower case, a body with no `private` member). |
