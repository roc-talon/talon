# 245 The `--git` operand

Phase: P2 CLI (a P1 rule with no test: `MISSING=1 scripts/rules.sh R-R14`). Status: tests (red), reviewed. On 2026-11-13 the user approved Q-245-1 to Q-245-3 as recommended, and the new text for a nightly tag after `--git` (B10). The design ids for these answers are pending (TalonRegistry gives them). Test agent: 2026-11-13.

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-R14 | `--git` takes one operand: `owner/repo@ref` or `@ref` (`@ref` is `roc-lang/roc`). A name with no `@ref`, a name that is not `owner/repo`, or more than one operand: exit 2. Talon does not guess the default branch. A bare word with no `@` is not a sha: `tln roc install deadbeef` names a compiler id. `@` and 7 or more hex digits is a sha (R-SL10). |
| R-SL10 | Hex only, 7 or more characters, and no release matches: a git ref with no `--git`. |
| R-SL12 | None of rules 1 to 3, and no `--git`: an error that says `use --git for a branch or tag` (and "lists the close release versions": Q-245-1). |
| R-SL13 | `--git` skips rules 1 and 2: each selector is a git ref. |
| R-SL9 | Rule 1 comes first: 7 decimal digits read as a series, not a sha. |
| R-R5, R-R11, R-SC10 | `roc default --git` reads the operand in the same way. `@<sha>` needs no `--git`. A bare word is an id or a prefix of an id. |

Source: DESIGN-CLI.md 6.6 (R-R14, row 1527), section 2 (R-SL9 to R-SL13, R-SC9, R-SC10), section 3 (exit code 2 = usage). History: slice 045 question Q2 and gap row C3; DESIGN-GAPS-2026-10-25.md (R-R14 is the answer of Q2 and Q7).

## Scope (facts found in the code before any change)

| Fact | Where | Consequence |
| --- | --- | --- |
| `GitRef.read` reads the operand of `roc install` and `roc default`. With `--git`: 0 operands, 2 or more, a name that is not `owner/repo` (`Ref.form != Full`), no selector: each a `Usage` failure (exit 2). With no `--git`: only an `owner/repo@<GitSha>` operand is a git source; all else is `NotGit` and goes to `RocInstall`. | cli/lib/GitRef.roc (`read`, `git_source`, `sha_source`, `ref_of`) | Most of R-R14 is built (slice 045 C3). It had tests, but no test named R-R14. |
| `Selector.parse`: hex only and 7 or more characters is `GitSha`; a version, a range or a series comes first. | cli/lib/Selector.roc | R-SL9, R-SL10 are right. |
| `Ref.parse("@deadbe", Roc, False)` fails with `bad selector 'deadbe' in '@deadbe': use --git for a branch or tag`. But `GitRef.read` turns this failure into `NotGit`, and `RocInstall` then reads the nightly list and says `no compiler matches deadbe`. | GitRef.roc `sha_source`, RocInstall.roc | The one red behavior: R-SL12 text and no list request (case `roc/gi5-short-hex`). |
| `Args` allows `--git` for `tool install`, `x`, `roc install`, `roc default` (R-FL14). | cli/lib/Args.roc line 246 | R-R14 is a row of 6.6 (compilers), and `@ref` = `roc-lang/roc` is the `tln roc` scope. `tool install --git` has its own rows (ToolGit, R-T23) with the same refusals. Not in this slice. |

## Behaviors

| # | Behavior | Exit | Rules | State |
| --- | --- | --- | --- | --- |
| B1 | `--git owner/repo` with no `@ref` (also `roc-lang/roc`): stop, no commit request (no default branch guess) | 2 | R-R14 | green |
| B2 | `--git` with a name that is not `owner/repo`: a short name, a bare hex word, `host/path` | 2 | R-R14 | green |
| B10 | `--git` with a nightly tag and no `@`: exit 2, and the text names `tln roc install <tag>` (approved text) | 2 | R-R14, R-SL2 | **red** |
| B3 | `--git` with 0 operands, 2 or 3 operands; `--git @` (empty ref) | 2 | R-R14 | green |
| B4 | `roc default --git` refuses the same operands | 2 | R-R14, R-R5 | green |
| B5 | `@deadbee` (7 hex) is a sha with no `--git`: the git path (shown with `--offline`: exit 15, `roc-lang/roc@deadbee needs a request...`) | 15 | R-R14, R-SL10, R-R11 | green |
| B6 | `roc install deadbeef` (no `@`) names a compiler id: the nightly list, `no compiler matches deadbeef`, no commit request | 2 | R-R14, R-SC10 | green |
| B7 | `@deadbe` (6 hex) and `owner/repo@deadbe`: not a sha, so R-SL12: `bad selector ... use --git for a branch or tag`, no request | 2 | R-R14, R-SL10, R-SL12 | **red** |
| B8 | `--git @deadbe` is a git ref (R-SL13: `--git` skips rule 2) | n/a | R-R14, R-SL13 | green (L0) |
| B9 | `@1234567` is a series first, not a sha | n/a | R-SL9 | green (L0) |

## Tests

| Layer | Case | Checks | State |
| --- | --- | --- | --- |
| L0 | `tests/unit/GitTest.roc` (driver `l0-3`), new expect "R-R14 (slice 245)": 19 rows of `GitRef.read` (B1 to B6, B8 to B10) | R-R14, R-R5, R-SL10, R-SL13 | **red**: only the row of B10 (the new text) |
| L0 | `tests/unit/GitTest.roc`, new expect "R-R14 R-SL10 R-SL12 R-SL9": 7 rows of `Ref.parse(_, Scope.Roc, False)` (sha at 7 digits, bad selector at 6, `@mian`, `@1234567`, bare `deadbeef`) | R-R14, R-SL9, R-SL10, R-SL12 | green |
| L2 | `tests/commands/cases/roc/gi4-operand`: 13 runs (table in its `rules` file): B1 to B6, B10. calls.log shows no `commits/` request, no `spawn_all`, and one list request only in run 13 | R-R14, R-R5, R-R11, R-SL10, R-DI12, R-SC10 | **red**: only the stderr line of run 6 (B10). I changed that line by hand after the review; calls.log, stdout and exit stay as in the green run |
| L2 | `tests/commands/cases/roc/gi5-short-hex`: `roc install @deadbe`, `roc install Karakatiza666/roc@deadbe` (B7) | R-R14, R-SL10, R-SL12 | **red** |

The pure function exists: `GitRef.read : { args : Args, bare_sha : Bool } -> Try(Try(GitRef.Source, [NotGit]), Fail)`. No new unit module and no driver change. The L0 tests are green at once: R-R14 was built in slice 045 (C3). The expected files of `gi4-operand` come from a green run, and I read each line (TW21): every stop is exit 2 except run 12 (exit 15), stdout has no error, and no exit-0 run exists.

### Why gi5 is red (the work of the code agent)

Now: `GitRef.read` gives `NotGit` for `@deadbe`, and `RocInstall` reads the nightly list and prints `no compiler matches deadbe`. The design: `@deadbe` is a selector (it has `@`), it is not a sha (6 digits), not a nightly, a step, `latest` or a version, so R-SL12: an error that says `use --git for a branch or tag`. The exit code (2) is already right; the text and the calls are wrong.

**GUESS (calls.log of gi5):** the stop comes before any request, after the 4 calls that each run makes first: `args`, `env_all`, `tty`, `read_files $HOME/.config/talon/config.toml`. This holds if the check is in `GitRef.read` (`sha_source` keeps the `Ref.parse` failure of an `Unknown` selector) or at the start of `RocInstall`. If the answer of Q-245-1 is "list the close ids", the list request comes back and the calls change.

## Output (proposed, TW24)

| Case | Text | Origin |
| --- | --- | --- |
| No `@ref` | `tln: error[usage]: '<operand>' has no ref: use owner/repo@ref or @ref` | slice 045 C3 (exists) |
| Not `owner/repo` | `tln: error[usage]: --git takes a GitHub repository as owner/repo, not '<name>'` | slice 045 C3 (exists) |
| 0 operands | `tln: error[usage]: tln <typed> --git needs one ref: owner/repo@ref or @ref` | slice 045 (exists) |
| 2 or more | `tln: error[usage]: tln <typed> --git takes one ref, got <n>` | slice 045 (exists) |
| `--git @` | `tln: error[usage]: '@' has an empty selector after '@'` | slice 004 (exists) |
| `--git <nightly tag>` (a nightly tag with no `@`, B10) | `tln: error[usage]: --git takes owner/repo@ref or @ref; for a nightly use tln roc install <tag>`, with the typed tag in place of `<tag>` (for example `tln roc install nightly-2026-10-21-5349569`). Other names with no `@ref` keep `'<name>' has no ref: use owner/repo@ref or @ref`. | approved by the user, 2026-11-13 (new) |
| `@deadbe` with no `--git` (B7, new for `roc install`) | `tln: error[usage]: bad selector 'deadbe' in '@deadbe': use --git for a branch or tag` | `Ref.parse` text of slice 004 |

No `--json` `data` field changes.

## Questions (TW17)

All three were answered on 2026-11-13: the user approved each recommended answer. The design ids are pending (TalonRegistry gives them).

| Id | Question | Recommended answer |
| --- | --- | --- |
| Q-245-1 | R-SL12 says that Talon "lists the close release versions" for a bad selector. In the `tln roc` scope (`roc install @deadbe`, `@mian`), the releases are nightly tags, not versions. Must `roc install` read the nightly list to name close ids? | No. In the `tln roc` scope the error has no list: the `Ref.parse` text, exit 2, before any request (gi5 expects this). Close versions are for packages and tools (semver). |
| Q-245-2 | Upper case hex: `Selector.parse` takes `@DEADBEE` as a sha (`is_hex` has `A-F`). R-SL10 says "hex only". Is upper case a sha? | Yes, keep it (no test in this slice). The id comes from the 40 lower case digits that the API gives (R-R1, R-R3), so the id is the same. |
| Q-245-3 | Does R-R14 apply to `tool install --git` and `x --git`? Its row is in 6.6 (compilers), and `@ref` = `roc-lang/roc` is only for `tln roc`. | No new rule: `tool install` and `x` follow R-T23 and R-SL13, and `ToolGit` already refuses the same forms. R-R14 = `roc install` and `roc default`. |

## Tricky behaviors (for the revert check, TW12)

| # | Mutation | Test that must fail |
| --- | --- | --- |
| M1 | `git_source`: drop the `parsed.form != Full` check | GitTest R-R14 rows `deadbeef`, `github.com/...`, `roc@main`; gi4 runs 3 to 5 |
| M2 | `ref_of`: a name with no selector gets a default ref (`main`) | GitTest no-ref rows; gi4 runs 1, 2 (a `commits/main` request in calls.log) |
| M3 | `sha_source`: a bare hex word with no `@` is read as `@<word>` (a sha) | GitTest row `roc install deadbeef`; gi4 run 13 |
| M4 | `Selector.is_sha`: `>= 7` becomes `>= 6` or `> 7` | Ref rows `@deadbe`, `@deadbee`; gi4 run 12; gi5 |
| M5 | `GitRef.read`: the `many` arm takes the first operand | GitTest rows "got 2", "got 3"; gi4 runs 9, 11 |
| M6 | Revert the gi5 fix of the code agent | gi5 |
| M7 | Give every name with no `@ref` the nightly text, or give a nightly tag the old text | GitTest rows `Karakatiza666/roc` and `nightly-...`; gi4 runs 1 and 6 |

## Out of scope

`tool install --git` and `x --git` (Q-245-3). R-R15 (has slice 071). The build path of `--git` (slices 044, 045).

## Disputes (from the code agent)

## Verify results
