# Design decisions of 2026-10-27: the exclude list of `min-release-age`, and `tln init --platform owner/repo@<version>`

The design agent applied two decisions of the user (2026-10-27). Method: as in `DESIGN-GAPS-2026-10-26.md`. Read the rules, take the user's intent, write the rule, write the reason. Output text and `--json` fields that the design does not give are a proposal for the human review (TW24, CLI R-OUT1 to R-OUT5), not a question.

Files changed: `DESIGN.md`, `DESIGN-CLI.md`, `DESIGN-RESOLUTION.md`, `docs/slices/PLAN-P1.md` (section 2d), and the slice files 081 to 085. No test, no code, no `TESTING.md`.

## A. Decision 1: `min-release-age-exclude`

The user: Talon trusts a release only after `min-release-age` (default 2d). An owner who releases several repositories in lockstep (a platform, its helper tool, its packages), and its users, want to skip the wait for chosen owners.

References: pnpm `minimumReleaseAgeExclude`, Bun `minimumReleaseAgeExcludes` (`bunfig.toml`, `[install]`), uv `exclude-newer-package`. The three name packages that skip the age or date rule. Talon names owners with patterns, because a lockstep release has many repositories.

| Id | Decision | Rule ids | Why |
| --- | --- | --- | --- |
| A1 | The key `min-release-age-exclude`, a list of patterns, in `config.toml` and in `talon.toml` `[resolution]`. Not set: the empty list. No flag, no environment variable. Talon writes the key nowhere. In a workspace it is a root key (`[resolution]` is a root table). | R-C11, R-WS5 | `min-release-age` has no flag. The root rule already covers every key of `[resolution]`, so no new rule is needed there. |
| A2 | Pattern forms: `owner/repo` and `owner/*`. Compare: ASCII case-insensitive on both parts. A release with no name (other host, unsafe part) matches nothing. | R-C12 | GitHub names are case-insensitive, and the registry keeps lower-case names (Registry R-SN1, R-TP5). R-ID2 (the group key) is a byte compare of a URL; it is for identity, not for trust, and it does not change. R-ID3 says the name is for display and search; this is a search-like use of it. |
| A3 | Bad patterns: `*`, `*/repo`, `*/*`, `ow*/repo`, `owner/re*`, a version, a host, a space, an empty text. A bad pattern, or a value that is not a list of texts: exit 19. | R-C12, R-C13, R-TF4, R-EC19 | `*/*` would be a hidden `0d`; the user writes `min-release-age = "0d"` for that. The exit code is the existing input error. The check runs when the file is read, before any package or list. |
| A4 | The two sources are joined by union. `min-release-age` is different: `talon.toml` replaces `config.toml`. | R-C14, R-C7, R-LY4 | See the table in B1. |
| A5 | Where it applies: every place that `min-release-age` applies (resolve, `add`, `update`, `upgrade`, `outdated`, `[tools]`, `tool install`, `x`, `tool update`, `tool update talon`, `init`, the compilers of R-NS3). | R-C15 | The user asked for the same places. One table in R-C15 lists them with the name that a pattern compares. |
| A6 | Compilers: not a special case. `roc-lang/nightlies` (a nightly), `roc-lang/roc` (a release) and `roc-lang/*` skip the age for compilers. | R-C15 | One rule for each place. And the lockstep case needs it: a platform release often needs a compiler younger than 2 days. If only the platform skipped the age, no tuple would exist (exit 10). The risk (`roc-lang/*` also trusts the compilers) is written in R-SE19, with the advice to write `owner/repo`. |
| A7 | What the list does not change: `snapshot` (time and log), the `nightly` switch, the `[toolchain] roc` range, yank, draft and prerelease, a named version, the header value, a transitive package, the install scripts, `install --frozen`. | R-C15 | A snapshot repeats a past state. The switch and the range state which compilers the team can use. A pattern states trust in an owner, not in a bad release. The rest is not hidden by the age already, or is not a choice of Talon. |
| A8 | The note: when Talon newly selects a release that is younger than `min-release-age` and only a pattern keeps it visible, it prints one note `note: <id> <version> is <n>d old (min-release-age <m>d), not hidden by min-release-age-exclude: <pattern>`. It goes where the R-C7 note goes for that command (changed by the review of 2026-10-27, part C): a `note:` line in the human output, an entry of `data.notes` with `--json`; the tool, compiler and setup commands print it on stderr with the prefix. No note when nothing changes (a kept header value, an installed tool that stays, `Current`, a pin that already equals the compiler). A release that is old enough: no note. A named version: the R-C7 note only. `outdated` and the search of `probe`: no note. | R-C16 | The user trusts the owner, but a young release in a lockfile change should stay visible; the cost is one line. No new `--json` field: it is one more entry of the existing notes. |
| A9 | Security text. | R-SE19, R-SE3 | The publisher cannot set the key: Talon reads no `talon.toml` of a dependency (R-I1), the key is in the project file and the user file only, and no command writes it. A cloned repository can already set `min-release-age = "0d"`, so its list gives no new power. What stays: `owner/*` trusts later repositories, and a taken-over account (R-SE14) publishes there with no wait. |

### B1. The two sources

| Key | Two sources | Reason |
| --- | --- | --- |
| `min-release-age` | `talon.toml` replaces `config.toml` (R-C7) | One number. Two numbers cannot hold together. |
| `min-release-age-exclude` | Union | The user states the owners that the user trusts, in all projects. A project states its own owners (its lockstep release). A project must not cancel the trust of the user, and the user must not copy a personal list into each project. An empty list in `talon.toml` removes nothing. |

Other points of the union:

| Point | Decision |
| --- | --- |
| A project with `min-release-age = "7d"` and a user list `acme/*` | The list still applies. The list is the trust of the user, not a number. |
| `min-release-age = "0d"` | Nothing is hidden. The list has no effect and gives no warning. |
| A command with no project in scope | `config.toml` only, as for `min-release-age`. |
| The same text in both lists | It counts once. The order is `talon.toml` first, then `config.toml`. The note names the first match in this order. |
| CI | A CI job runs `tln install --frozen`, which chooses nothing. It needs no list. |

### B2. Code that will change (for the slices)

| Place | Today | After |
| --- | --- | --- |
| The age check | 7 age tests: `Pick.too_young` (used by `Pick.is_hidden` and `Pick.chosen_for`), `Nightlies.visible` (used by every `Toolchain` and `NightlyPlan` function), `ToolInstall.pick`, `TalonUpdate.pick`, `Init.start`, and the solver rule `Domain.hidden` in `packages/resolve` (rule 4). The other modules only pass `min_age` on. | One pure function `Age.hides` (new module `cli/lib/Age.roc`) replaces the six CLI tests. Each place passes `exclude : List(Str)` next to `min_age`. The solver is not changed: `OracleRequest.solver_slot` gives it `Age.seen` as the time of each candidate (see C3). |
| `ConfigToml.Config`, `Intent` `resolution` | No exclude key. `unknown_keys` warns on it. | A field `min_release_age_exclude : List(Str)`. The key is known. A bad pattern is exit 19. |
| `ResolveBase.settings_of`, `ToolsFlow`, `ToolFlow`, `ToolManageFlow`, `RunTools`, `Base`, `RocInstall`, `NoRank`, `Init.start_url!` | `min_age: ... ?? 172800` | the same, plus `exclude: Age.join(...)` |

Slices: 081 (key, readers, `Age`), 082 (the project resolve), 083 (tools), 084 (compilers), 085 (`tln init`, and Decision 2).

## B. Decision 2: `tln init --platform owner/repo@<version>`

The user: `--platform` takes an exact version. Today it takes `owner/repo` only (the message `'<name>' is not a platform name: use owner/repo`). An exact version is a release that the user names, so `min-release-age` does not apply, and Talon prints its age (as R-T9 and R-NS4).

| Id | Decision | Rule ids | Why |
| --- | --- | --- | --- |
| B1 | Only an exact version of 3 parts is allowed (R-SL3, R-SL15). A range, a series, `latest`, a nightly tag, a relative step, a git ref and an empty text are exit 2. | R-IN9 | A range, a series, `latest` and no selector all mean "the newest release that the age allows", and `owner/repo` already gives that. The only new meaning is that the user names a release. A range would need rules for how far the resolve may move the platform (R-AD31), and `init` writes no `talon.toml` that could keep a range (R-IN5). A later change can add ranges with no break. |
| B2 | The version must be in the release list, not yanked, not a draft, not a prerelease. Else exit 2: `owner/repo has no release <version>`. | R-IN9, R-C6, R-DI3 | The same as `tln tool install` (R-T10). |
| B3 | Age: neither `min-release-age` nor the exclude list applies. When the release is younger than `min-release-age`, one note on stderr, with the form of R-T9: `<owner/repo> <version> was released at <time>, less than min-release-age ago. It is used because the version is named.` | R-IN9, R-C7, R-C9, R-T9 | The release is named by the user. |
| B4 | The resolve of `init` is the flow of `tln upgrade roc` (R-SP8): the platform is held, no package is free, the nightly is free. The platform is not movable: the second search (R-SP24) does not move a release that the user named. No nightly passes: exit 10 with the blame, and R-IN7 removes the files of the run. | R-IN10, R-SP8, R-SP23, R-UP6 | The user named the release. Today `init` runs `tln upgrade` with no names, and the platform is free (R-UP12). |
| B5 | The `roc:` pin is the newest nightly that passes the ladder with that platform (R-IN4). It can be older than the newest nightly. | R-IN10 | A named older platform often needs an older nightly. The ladder finds it. |
| B6 | The template text follows the repository, not the version. A named basic-cli version gets the basic-cli template, which is written for the newest release. An older release can fail the baseline: the ladder then decides (exit 10). No special case. | R-IN10, R-IN1, R-IN8 | A rule that reads the version would need a template for each version. The ladder is the test (Resolution 4). |
| B7 | The CI file does not change. | R-IN6, R-IN10 | It names no platform. It runs `tln install --frozen`. |
| B8 | The start release of an app (no version) uses the exclude list: a platform of an excluded owner is not hidden by the age. | R-C15, R-IN2 | The init row of R-C15. |

## C. Questions (TW17), and the answers of the review

None stops a slice. The user answered Q1 and Q2 on 2026-10-27: Q1 yes (one rule for packages, tools and compilers), Q2 yes (an exact version only).

| Id | Point | Decision taken | Alternative |
| --- | --- | --- | --- |
| Q1 | A pattern such as `roc-lang/*` also lifts the age for the compilers (A6). | Yes, with the warning in R-SE19. | Compilers never match a wildcard, only the exact repo names `roc-lang/nightlies` and `roc-lang/roc`. One more rule and one more test row; safer for a user who writes `roc-lang/*` for packages only. |
| Q2 | `init --platform` takes an exact version only (B1). | Yes. | The ranges of `tln add --platform owner/repo[@sel]` (R-AD29). Needs the rules of B1 for the move of the platform. |

### C1. Human review of the tests (2026-10-27)

The test agent wrote the tests of slices 081 to 085 and raised points. The user decided:

| Id | Point | Decision | Rules and slices |
| --- | --- | --- | --- |
| C1 | Where the R-C16 note goes | Where the R-C7 note goes: a `note:` line in the human output (stdout for the resolve commands) and an entry of `data.notes` with `--json`, in the R-C7 form. The bare stderr text of the first draft is gone. The tool commands (R-T9 place), the compiler commands and `tln setup` (the place of the rank 6 note) print `note: <text>` on stderr. `init` adds the start note to the notes of the flow. The expected files of slices 082 to 085 change. | R-C16; slices 082, 083, 084, 085 |
| C2 | How the list reaches the solver | By a filter before the solver. The age test of the real flow is also in `packages/resolve/Domain.roc` (`hidden`, rule 4): a seventh age test, found by the test agent. `packages/resolve` stays unchanged. `OracleRequest.solver_slot` maps the time of each candidate with the pure `Age.seen`: 0 for a candidate that a pattern matches and that is not after the snapshot, the real time otherwise. Why: `Domain.Rules` is one record for the whole request and a candidate has no owner or repo, so `exclude` in the solver would put names and patterns into the solver package and change its tests and `tests/fuzz/pubgrub.roc`; `Domain.with_header` already uses time 0 for a value with no known time; the solver reads the time for rule 4 only; a candidate after the snapshot keeps its time, so the snapshot still hides it (the hack of the private reference, which ignored the snapshot, is not the design); `chosen_for` reads the real time from the slot for the note. | R-C15, R-DT4; slices 081 (`Age.seen`), 082 |
| C3 | `--snapshot` for `tool install`, `x`, `tool update` | It stays a usage error (out of scope). The old run 6 of `ti6-exclude` is dropped. Snapshot against a pattern is tested through the `[tools]` entries only (`ptool/pt5c-exclude-hidden`). | R-C15, R-PT4; slice 083 |
| C4 | When the note prints | When Talon newly selects a young release that only a pattern keeps visible, also from a range pick (rank 4) and from `roc use @latest`, `@+N`, `@-N` (also when the compiler is installed, because `roc use` writes a pin). No note when nothing changes: a kept header value, an installed tool that stays, `tool update talon` with `Current`, a pin that already equals the compiler. R-C16 has the table. The test agent adds these rows: `tool update talon` with `Current` (`ts10c`); `tool update` and `tool install` with `Keep` (`tu4c`); a second `[tools]` install with the `url` in place (`pt5b` run 3); `roc use @latest` of an installed young compiler, and the same again (`us6-exclude-steps`); the rank 4 range pick in a project (the `[toolchain] roc` range, no pin); `NoRank.pick` of R-SO14 in a project command (`norank/nr2-exclude`); `init` where the resolve moves the start release (`it6-exclude` x4). | R-C16; slices 083, 084, 085 |

### C2. Other points of the test agent, settled

| Id | Point | Decision |
| --- | --- | --- |
| Q3 | `Age.hides` with `min_age` 0 and a `published_at` after `now` | `Age.hides` is False for `min_age` 0, also for a future time (R-C7: `"0d"` hides nothing). It is a row in slice 081 (`AgeTest` `hides`) and in slice 084 (Q-T4). `Age.note` is `Err(None)` for `min_age` 0, with the same guard. |
| Q7 | The name check of `init --platform` (slice 085, T2) | The test agent's reading is the rule: the whole text is read; the part before the first `@` is exactly two non-empty parts at one `/`; at most one `@`. So `acme/pfx@1.2.0/x`, `acme/@1.2.0`, `a/b/c@^1` and `acme/pfx@1.2.0@x` are name errors (`is not a platform name: use owner/repo or owner/repo@1.2.3`), and `acme/pfx@` is a version error. The text of section 2 of slice 085 says so. |

## D. Rules changed or added

| Rule | File | Change |
| --- | --- | --- |
| R-C7 | Resolution 2 | One sentence: the exclude list skips the age for chosen owners. |
| R-C11 to R-C16 | Resolution 2 (new block "The exclude list of `min-release-age`") | The key, the pattern, the bad pattern, the union, the places, the note. |
| R-NS3, R-UP1 | Resolution 1, 10 | A pointer to R-C15. |
| R-LY4, the `config.toml` listing | CLI 6.1 | The union is the one exception. The key in the listing. |
| R-T9, R-PT4, R-RU1, R-ST16, R-DI10 | CLI | A pointer to R-C15. |
| R-CM1, the flag table, R-IN1, R-IN2, R-IN8 | CLI 1, 5 | `--platform <owner/repo>[@<version>]`. |
| R-IN9, R-IN10 (new) | CLI 5 | The exact version, and the use of the named release. |
| R-SE3, R-SE19 (new) | Design 8 | The security text. |
| Design 4.2 sample, the index of rule ids | Design | The key in the sample. R-C1 to R-C16, R-IN1 to R-IN10, R-SE1 to R-SE19. |

`scripts/rules.sh` lists the new ids R-C11 to R-C16, R-IN9, R-IN10 and R-SE19 with no test.
