# 081 The key `min-release-age-exclude`: patterns, the union, the note

Phase: P1. Status: done (code agent, 2026-10-27). Dispute D1 is closed (the test agent regenerated the two cases; they pass).

Slice 081 is the plan row 081 of `PLAN-P1.md` (section 2d). Source: Decision 1 of the user (2026-10-27), recorded in `DESIGN-GAPS-2026-10-27.md` (part A). The design is R-C11 to R-C16 (`DESIGN-RESOLUTION.md`, section 2, "The exclude list of `min-release-age`"), R-SE19 (`DESIGN.md`, section 8) and R-TF4.
This slice makes the key and its pure decisions. It wires the key into no command: the slices 082 to 085 do that. Test agent output first. The code agent makes the tests green (TW18: it does not edit them).

## 1. Rules

| Rule | Text (short) | Tests |
| --- | --- | --- |
| R-C11 | The key `min-release-age-exclude`: a list of patterns, in `config.toml` and in `[resolution]` of `talon.toml`. Not set: the empty list. A member `talon.toml` of a workspace cannot have it (the table `[resolution]` is a root table). | L0 `IntentTest` (read, absent, root and member) |
| R-C12 | A pattern is `owner/repo` or `owner/*`. The compare is ASCII case-insensitive on both parts. A release with no name matches nothing. The characters and the bad forms. | L0 `AgeTest` `check`, `matches` |
| R-C13 | A bad pattern, or a value that is not a list of texts: exit 19, on the line of the key, before any package or list is read. | L0 `IntentTest` (both files), L2 `resolve/rs-exclude-bad` |
| R-C14 | The list that applies is the union of the two lists. A text in both counts once. The order is `talon.toml` first. | L0 `AgeTest` `join` |
| R-C16 | The text of the note, and when it exists. | L0 `AgeTest` `note` |
| R-C7 | The age test is one function: `Age.hides`. `Age.seen` gives the time for the solver, which has its own age test (082). A release at exactly `min_age` seconds is visible. `min_age` 0 hides nothing. | L0 `AgeTest` `hides` |
| R-TF4 | The key is known: no warning `unknown key`. A wrong type or form is exit 19. | L0 `IntentTest` |
| R-WS5 | A key of `[resolution]` in a member file is exit 19 (the existing check), also for this key. | L0 `IntentTest` |
| R-LY4 | The union is the one exception to "talon.toml has priority". Doc only. | none |

## 2. Public signatures (stubs `crash "todo: slice 081"`)

New module `cli/lib/Age.roc` (listed in `cli/lib/main.roc`). It has pure functions only (TESTING.md 2.2, part A).

| Function | Signature | Result |
| --- | --- | --- |
| `Age.check` | `Str -> Try({}, [BadPattern])` | `Ok` for `owner/repo` and `owner/*`. Each part: not empty, ASCII letters, digits, `-`, `_`, `.`, and not `.` or `..`. `*` only as the whole repo part. `Err(BadPattern)` for the rest (R-C12 row 4). |
| `Age.matches` | `{ pattern : Str, name : Try(Str, [NoName]) } -> Bool` | True when the pattern is valid, the name is `Ok`, and the owner (and the repo, for `owner/repo`) are equal in ASCII case-insensitive compare. `acme/plat` does not match `acme/platform` (no prefix). `acme/*` does not match `acme-x/y`. A bad pattern gives False. |
| `Age.first_match` | `{ patterns : List(Str), name : Try(Str, [NoName]) } -> Try(Str, [None])` | The first pattern of the list that matches, as written. |
| `Age.join` | `{ project : List(Str), user : List(Str) } -> List(Str)` | `project` then `user`, each text once (equal texts, first place kept). |
| `Age.hides` | `{ now : U64, min_age : U64, published_at : U64, exclude : List(Str), name : Try(Str, [NoName]) } -> Bool` | True when `min_age > 0` and `published_at + min_age > now` and no pattern of `exclude` matches `name`. The guard `min_age > 0` keeps the old rule of `Nightlies.visible`: `min-release-age = "0d"` hides nothing, also a release dated after `now` (found by the test agent of slice 084; test row in `AgeTest` `hides`). |
| `Age.seen` | `{ published_at : U64, snapshot : Try(U64, [None]), exclude : List(Str), name : Try(Str, [NoName]) } -> U64` | The time that the solver sees (slice 082, section 2). `0` when a pattern matches `name` and the release is not after the snapshot (`published_at <= snapshot`, or no snapshot). Else `published_at`. |
| `Age.note` | `{ id : Str, version : Str, now : U64, min_age : U64, published_at : U64, exclude : List(Str), name : Try(Str, [NoName]) } -> Try(Str, [None])` | `Ok(text)` only when the release is younger than `min_age` and a pattern matches (R-C16). The text is in section 5. An empty `version` (a compiler) leaves out the version and its space. A caller does not call it for a version that the user names. |

Changed types (the stubs have them):

| Type | Change |
| --- | --- |
| `ConfigToml.Config` | New field `min_release_age_exclude : List(Str)` (empty when not set) |
| `Intent` `resolution` record (and `Intent.read_resolution`) | New field `min_release_age_exclude : List(Str)` |
| The "no config" and "empty intent" values (`Base.no_config`, `ResolveLoad` not-found value, the empty values in `Intent`) | The new field, empty |

## 3. Where the code changes (for the code agent)

| # | Place | Change |
| --- | --- | --- |
| 1 | `Age.roc` (new), `main.roc` | The seven functions. `matches` and `check` share one parser of the pattern. |
| 2 | `ConfigToml.read` | The key `min-release-age-exclude` through `config_field`: a list of texts, each passes `Age.check`. Add it to `config_keys` (no `unknown key` warning). Failure kind `Input` (exit 19): `<path>:<line>: min-release-age-exclude: '<pattern>' must be owner/repo or owner/*`. A value that is not a list of texts: `<path>:<line>: min-release-age-exclude: must be a list of owner/repo or owner/* patterns`. |
| 3 | `Intent.read_resolution` | The same key with `field(doc, "resolution", "min-release-age-exclude", ...)`. Add it to the `unknown_keys` list of `resolution`. The messages have the prefix `resolution.` like the other keys. A member role refuses the table already (R-WS5): no new code. |
| 4 | The literals of the record types | `Base.no_config`, `ResolveLoad` (the `NotFound` branch), any empty `Intent` value |

## 4. Tests

Layers: L0 pure (`roc test`), L2 command cases (`tests/commands/cases`). L3 is in slice 082.

| Layer | File or case | What | Rule ids |
| --- | --- | --- | --- |
| L0 | `tests/unit/AgeTest.roc` (new; one driver `l0-N.roc` imports it) `check` | Ok: `acme/platform`, `acme/*`, `Acme/Platform`, `a.b/c_d-e`, `roc-lang/roc`. Bad: `*`, `*/repo`, `*/*`, `ow*/repo`, `owner/re*`, `owner/**`, `owner/repo@1.0.0`, `github.com/owner/repo`, `acme/`, `/repo`, `a/b/c`, `acme/..`, `./repo`, `acme/re po`, empty | R-C12 |
| L0 | `AgeTest` `matches` | case-insensitive on owner and on repo; `acme/*` matches `Acme/x`; no prefix match (`acme/plat`, `acme/*` against `acme-x/y`); `NoName` matches nothing, also `acme/*`; a bad pattern matches nothing | R-C12 |
| L0 | `AgeTest` `first_match` | the first match in list order; none gives `Err(None)`; the text is returned as written (`Acme/*`) | R-C12, R-C16 |
| L0 | `AgeTest` `join` | project first; equal text once; empty and empty; a text in both lists | R-C14 |
| L0 | `AgeTest` `hides` | young and no pattern: True. Young and a pattern: False. Old: False. Exactly `min_age` old: False. One second younger: True. `min_age` 0: False, also when `published_at` is after `now`. `published_at` after `now` (clock skew): True with `min_age` > 0. `NoName` young: True | R-C7, R-C12 |
| L0 | `AgeTest` `seen` | A match and no snapshot: 0. A match and a snapshot after the release: 0. A match and the release after the snapshot: the original time (the snapshot still hides it). A match and the release exactly at the snapshot: 0. No match: the original time. `NoName`: the original time | R-C15, R-DT4 |
| L0 | `AgeTest` `note` | young and a pattern: the text with whole days (`0d` for 3 hours, `1d` for 36 hours), `min-release-age 2d`, the first matching pattern. An empty `version`: `<id> is 0d old ...` with one space. Old: `Err(None)`. Young and no pattern: `Err(None)`. `min_age` 0: `Err(None)` | R-C16 |
| L0 | `IntentTest` (rows added) | `[resolution] min-release-age-exclude = ["acme/*", "Roc-Lang/basic-cli"]` gives the list as written. Absent: `[]`. A bad pattern: `tln: error[input]: /p/talon.toml:2: resolution.min-release-age-exclude: 'acme/*/x' must be owner/repo or owner/*`. `= "acme/*"` (not a list), `= [1]`: exit 19. No `unknown key` warning for the key. A `Member` role file with `[resolution] min-release-age-exclude = [...]`: the same failure as for `strategy` (R-WS5) | R-C11, R-C13, R-TF4, R-WS5 |
| L0 | `IntentTest` config rows (the `ConfigToml.read` test near the `min_release_age` row) | `config.toml` with the key: the list. Bad pattern: `<path>:<line>: min-release-age-exclude: ...`. A list of 2 and a second key after it: the line is the line of the key | R-C11, R-C13, R-TF4 |
| L2 | `resolve/rs-exclude-bad` (new, 2 runs) | Run 1: `install` with the bad pattern `acme/*/x` in `[resolution]` of `talon.toml`: exit 19, `...talon.toml:2: resolution.min-release-age-exclude: 'acme/*/x' must be owner/repo or owner/*`, no index call, no `http_get`, no write. Run 2: the value is a text, not a list: exit 19, `...: must be a list of owner/repo or owner/* patterns`, line 3 (the line of the key) | R-C13, R-C11, R-TF4, R-EC19 |
| L2 | `resolve/rs-exclude-bad-config` (new, 1 run) | `install` with `*/*` after a good pattern in `config.toml` (line 3): exit 19 with the path of `config.toml`, no table name in the key, no index call | R-C13, R-TF4, R-EC19 |
| L2 | `tool/ti7-exclude-bad-config` (new, 1 run) | `tool install acme/foo` with `acme/*/x` in `config.toml`: exit 19 right after the read of `config.toml`, no `list_dirs` of the index, no `http_get` | R-C13, R-TF4, R-EC19 |

Edits of old tests (TW21): the record literals of `Config` and of the `resolution` record in `tests/unit/*.roc` and in `tests/commands/` get `min_release_age_exclude: []`. This is mechanical. No expected file changes. The test agent finds them by the compile errors.

## 5. Output (proposed, TW24)

| Text | Proposal |
| --- | --- |
| Bad pattern in `config.toml` | `tln: error[input]: <path>:<line>: min-release-age-exclude: '<pattern>' must be owner/repo or owner/*`, exit 19 |
| Bad pattern in `talon.toml` | the same with the key `resolution.min-release-age-exclude` |
| Not a list | `...: min-release-age-exclude: must be a list of owner/repo or owner/* patterns` |
| The note (R-C16) | The text of `Age.note` is `<id> <version> is <n>d old (min-release-age <m>d), not hidden by min-release-age-exclude: <pattern>`. `<n>` and `<m>` are whole days (floor). A command prints it as `note: <text>` in the place of the R-C7 note of that command (slices 082 to 085). `Age.note` returns the text without the prefix. |

## 6. Out of scope

| Item | Where |
| --- | --- |
| Use of the list in a command | 082 (project), 083 (tools), 084 (compilers), 085 (`init`) |
| `Age.compiler_name` | 084 |
| A flag or a variable for the key | not designed (R-C11) |

## 7. Questions (TW17)

None that stops the slice. For the review:

| No | Point |
| --- | --- |
| N1 | `Age.note` for `min_age` 0 and a release dated after `now`: the design does not say. The test has no row for it. The reference gives `Err(None)` (same guard as `hides`). |
| N2 | R-SE19 (security text) and R-LY4 (doc only) have no 081 test. R-SE19 is named by the tests that check that no command writes the key (the `tree.diff` of the install and init cases of slices 082 and 085). | See `DESIGN-GAPS-2026-10-27.md` part C for the two points that the human can change at the review.

## 8. Disputes (from the code agent)

| No | Test | Problem | Design source | State |
| --- | --- | --- | --- | --- |
| D1 | L2 `resolve/rs-exclude-bad`, `resolve/rs-exclude-bad-config` | The expected files are broken. `rs-exclude-bad`: `expect/stdout`, `stderr` and `calls.log` have the 2 runs twice (4 runs, `fx/runs` has 2), and `expect/tree.diff` shows the given files as deleted. `rs-exclude-bad-config`: `expect/` has only `exit` (0) and an empty `tree.diff`, no stdout, stderr or calls. Probable cause: an `UPDATE=1` run with the filter `rs-exclude-bad`, which also matches `rs-exclude-bad-config`, so two runs wrote the same files. The private reference `l2bin` of this slice fails the two cases in the same way. The actual output of the code is the design output: exit 19, `$PROJECT/a/talon.toml:2: resolution.min-release-age-exclude: 'acme/*/x' must be owner/repo or owner/*`, `$PROJECT/b/talon.toml:3: ...: must be a list of owner/repo or owner/* patterns`, `$HOME/.config/talon/config.toml:3: min-release-age-exclude: '*/*' must be owner/repo or owner/*`, no index call, no `http_get`, no write. | R-C13, R-TF4 | Not edited (code agent rule). The test agent must regenerate `expect/` of each case alone (`UPDATE=1 tests/commands/run.sh resolve/rs-exclude-bad-config`, then the other with a filter that matches only it) and read the diffs. | **Fixed by the test agent (2026-10-27):** the cause was as guessed (a filter that matched both cases). Each case was regenerated alone (`CASES=<one dir>`) with the current code, and every file was read: `rs-exclude-bad` has 2 runs, exit 19 in stdout, the two R-C13 messages in stderr, a `calls.log` with no index call and no `http_get`, and an empty `tree.diff` (no write). `rs-exclude-bad-config` has 1 run, exit 19, the message with the path of `config.toml` and line 3, the same calls, an empty `tree.diff`. Both pass with the current code.

## 9. Revert check (TW12), planned: 8 mutations

Run only the tests that must see each one (no sweep).

| No | Mutation | Test that must fail |
| --- | --- | --- |
| m1 | `matches` compares case-sensitive | `AgeTest` `matches` |
| m2 | `acme/*` matches by prefix of the owner (`acme-x/y`) | `AgeTest` `matches` |
| m3 | `check` accepts `*/*` | `AgeTest` `check` |
| m4 | `join` gives the project list only | `AgeTest` `join` |
| m5 | `hides` uses `>=` (a release at the limit is hidden) | `AgeTest` `hides` |
| m6 | `matches` accepts a `NoName` for `owner/*` | `AgeTest` `matches` |
| m8 | `seen` gives 0 for a release after the snapshot | `AgeTest` `seen` |
| m7 | `Intent.read_resolution` does not check the patterns | `IntentTest`, L2 `rs-exclude-bad` run 1 |

## 10. Red output (test agent, 2026-10-27)

| Check | Result |
| --- | --- |
| Files | `tests/unit/AgeTest.roc` (new, 7 `expect`s incl. `seen` since the review of 2026-10-27, driver `l0-4.roc`), `tests/unit/IntentTest.roc` (one literal changed: `min_release_age_exclude: []`; 2 new `expect`s: `talon.toml` 17 rows, `config.toml` 13 rows), L2: 3 new case dirs (4 runs) |
| Repo, `roc test tests/unit/l0-4.roc` | Fails to compile: `lib.Age` is not a public module, `Age.check`, `Age.matches`, `Age.first_match`, `Age.join`, `Age.hides`, `Age.note` do not exist |
| Repo, `roc test tests/unit/l0-3.roc` | Fails to compile: `done.config.min_release_age_exclude` and `intent.resolution.min_release_age_exclude` do not exist |
| Repo, L2 | `resolve/rs-exclude-bad`, `rs-exclude-bad-config`, `tool/ti7-exclude-bad-config` fail on the wrong output: the old code warns `unknown key ...min-release-age-exclude` and goes on (exit 18 or 2, an index call) |
| Overlay (`research/slice-081-revert/reference/`: `Age.roc`, the key in `ConfigToml` and `Intent`, 3 literals) | The 7 `AgeTest` and the 2 new `IntentTest` `expect`s pass (21 tests with the old `IntentTest` ones). The 3 L2 cases pass with an L2 app built from the overlay (`l2bin`). |
| Hand mutations (overlay) | m1 case-sensitive compare: 4 fail. m2 owner prefix: 4 fail. m3 `*` as owner: 3 fail. m4 `join` gives the project list only: 1 fail. m5 `hides` with `>=`: 1 fail. m6 `owner/*` ignored: 4 fail. m7 `Intent` does not check the patterns: `IntentTest` fails. m8 (review) `seen` gives 0 for a release after the snapshot: 1 fails |

The overlay is a private reference. It is not the answer: the code agent may write another form. The tests of the slices 082 to 085 use it as the base of their overlays.

## 11. Verify results

Code agent, 2026-10-27.

| File | Change |
| --- | --- |
| `cli/lib/Age.roc` (new, 95 lines) | `check`, `matches`, `first_match`, `join`, `hides`, `seen`, `note` (and from 084 `compiler_name`). One parser `parse` for `check` and `matches`. `read_list` reads the value of the key for both files (one place of the two messages). |
| `cli/lib/main.roc` | `Age` exposed |
| `cli/lib/ConfigToml.roc`, `cli/lib/Intent.roc` | The key through `config_field` / `field` with `Age.read_list`; the key in the lists of known keys |
| `cli/lib/Base.roc`, `cli/lib/ResolveLoad.roc` | The literals get `min_release_age_exclude: []` |

| Check | Result |
| --- | --- |
| L0 `AgeTest`, `IntentTest` (one driver) | 21 tests pass |
| L2 `rs-exclude-bad`, `rs-exclude-bad-config`, `tool/ti7-exclude-bad-config` | `ti7` passes. The other two fail on broken expected files (D1). |
| Full suite | `scripts/test.sh` (all steps, as `.github/workflows/ci.yml` for Linux), run twice at the end (code of 081 to 085 together), with the default locale (`en_US.UTF-8`) and with `LC_ALL=C`: check, fmt, l0, l1, l3 and selftest pass; l2 had 232 passed and 2 failed (D1). After the D1 fix and Q-C1 (2026-10-27): every step passes, l2 234 passed. l0 takes 16 to 18 s (over the budget of 10 s: a WARN, not a failure). |

Revert check: 8 of 8 caught (each run once on `AgeTest` or `IntentTest`, the code put back, `diff -r` against a copy: the same).

| No | Mutation | Result |
| --- | --- | --- |
| m1 | `matches` case-sensitive | `AgeTest`: 5 fail |
| m2 | `owner/*` matches an owner prefix | `AgeTest`: 1 fails |
| m3 | `check` accepts `*` as owner | `AgeTest`: 1 fails |
| m4 | `join` gives the project list only | `AgeTest`: 1 fails |
| m5 | the age test with `>=` | `AgeTest`: 2 fail |
| m6 | `owner/*` matches `NoName` | `AgeTest`: 5 fail |
| m7 | `Intent` does not check the patterns | `IntentTest`: 1 fails |
| m8 | `seen` gives 0 after the snapshot | `AgeTest`: 1 fails |
