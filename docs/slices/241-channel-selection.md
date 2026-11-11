# 241 channel selection

Phase: P2. Status: done (2026-11-11). Design Q612 (G-C242), Q615 (G-C245 items 2 and 3), Q616 (G-C246, the 8 answers below, 2026-11-10). The user accepted the tests and the TW24 texts on 2026-11-11 (the `@<user id>` refusal text went in with the commit approval). 7 test disputes of the code agent were accepted and fixed; cases A to C were added from R-CH7, R-CH11, R-SL7 and Q615 note 2. Mutations: 13 of 14 caught, m2 equivalent (research/slice-241-revert/RESULT.md). Close run: check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only).

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CH7 (CLI 6.8, Design Q612 item 3) | Ranges. `*`, semver ranges, and `=<id>` / `>=<id>` with a nightly id or a release keep their meaning. `=<id>` and `>=<id>` with a user-channel id are over that channel only. No other range form matches a user channel: `*` and `>=nightly-...` never include user builds. |
| R-CH8 | Refs. `<name>@<selector>` selects in one channel (`reify@latest`, `reify@-1`, `nightly@latest`). A bare `<name>` means `<name>@latest`. A selector with no name works as today, or in the user channel of the selected compiler (R-SL7). No table for `<name>` in either file: exit 2 (Design Q615 item 7). |
| R-SL6, R-SL7 | A tag of a user channel is not a ref: use `<name>@<selector>`. A relative step `@-N` is inside the user channel when the selected compiler is a user-channel build. |
| R-CH6, R-R4 | A project on a user channel pins in the root `talon.toml` with `[toolchain] roc = "=<id>"`. Talon never writes a user id into a header `roc:` pin. |
| R-CH9 | Each user channel is ordered alone by R-NS1. A user-channel build counts as a nightly for the `nightly` switch only. |
| R-CH5 | The id of a build is the value of `ROC_TOOLCHAIN`, `[toolchain] roc` (and `roc +<id>`, `default-roc`). |
| R-CH11 (Design Q615 item 2) | The trust stop is part of this slice: a project pins or selects a user build whose table is only in the project `talon.toml`: exit 19 before any request and before `--offline`. `--yes` and `TALON_AUTO_INSTALL` do not give the consent. |
| R-CH13 | An installed build stays selectable by its id after its channel is removed. |
| R-CH16, R-R4 (Design Q615 item 3) | A user build is local only. Probe results for it stay local, in `compat.db` under its id. |
| R-EC19 | Exit 19 for the stop. |

Source: research/compiler-channels/PROPOSAL.md (revision 4), DESIGN-CLI.md 6.8, row 241 of docs/slices/PLAN-P2-CLI.md.

Out of scope (later slices, not tested here): `tln roc channel add/rm/list` (242; the tests put the table in `config.toml`), `roc use`, `upgrade roc`, `update <name>`, GC and the `roc list` marks (243).

## Scope

Facts found in the code and by the first runs of the new cases (before any change).

| Fact | Where | Consequence for the tests |
| --- | --- | --- |
| `Pin.parse_req` reads `=<id>` and `>=<id>` only for a nightly tag or a release (`is_compiler_id`). A user id is `Err(BadReq)`, so a `talon.toml` with `roc = "=reify-..."` stops with exit 19 and the R-TF8 hint `A newer tln may know this value`. | Pin.roc | Red: ChannelrangeTest 1, ch06-pin-trust (stderr), ch07-pin-exact, ch07-pin-atleast. |
| `Pin.admits` with `Any` admits every id, and `Pin.order` gives `Same` for a user id (`id_kind` is `Other`). | Pin.roc, PinOrder.roc | Red: ChannelrangeTest 2 and 3. `Compiler.select` is green for `*` today only because of its `Pin.is_id` filter (guards). |
| `Compiler.select` rank 4 keeps only `Pin.is_id` ids, so a user build is never a candidate. | Compiler.roc `in_range` | Red: ChannelrangeTest 4 (rows with `=<user id>` and `>=<user id>`). |
| `Compiler.toolchain_of` refuses a user id (`ROC_TOOLCHAIN is not a full compiler id`). | Compiler.roc | Red: ChannelrangeTest 5. |
| `Nightlies.pick` drops one `@`, then looks the text up by name. So `@reify-2026-11-03-1708298` names the build today. | Nightlies.roc | Red: ChannelrangeTest 8 (R-SL6). |
| `tln roc install reify@latest` and `nightly@latest` get `no compiler matches reify@latest` (exit 2). `@-1` with a user build as the selected compiler goes to the `roc-lang/nightlies` list. | RocInstall.offer_noted! | Red: ch08-named-latest, ch08-step. |
| `Pin.decide` writes a header pin only for an id that `is_compiler_id` accepts. A user id is not one. | Pin.roc | Guard: ChannelrangeTest 6 is green (R-R4). |
| `Compiler.kind` of a user id is `Local`. `ProbeShare` shares only `Nightly`. So a probe result of a user build is not shared today. | Compiler.roc, ProbeShare.roc | Guard: ChannelrangeTest 7 is green. |
| The pin stop must be reached from `Resolve.run!` (the commands that select a compiler by a range: `install`, `update`, `verify`, `run`, `x`, the `roc` proxy). One command is tested here (`install`, the `resolve` entry). | Resolve | The other commands share the function `Channel.pin_trust`; the code agent calls it in the shared place (see Coverage gaps). |

## Proposed names (TW24, for the code agent)

A name that the design does not give is a proposal. Until the names exist, the file ChannelrefTest does not compile: the whole driver `l0-9` is red on purpose (as slices 236, 238, 239, 240).

| Name | Type | Rule |
| --- | --- | --- |
| `Channel.named_ref` | `{ text : Str, config : List(E), project : List(E) } -> [NotNamed, Builtin(Str), User(E, Str), ProjectOnly(E), NoTable(Str), BadSelector(Str)]`, `E = { name, source, tag_prefix }` | R-CH8 |
| `Channel.bad_selector_text` | `{ name : Str, selector : Str } -> { message : Str, hint : Str }` (Q616 item 3) | R-CH8 |
| `Channel.pin_warning` | `{ text : Str, config : List(E), project : List(E) } -> Try(Str, [None])` (Q616 item 8) | R-CH6 |
| `Channel.pin_trust` | `{ text : Str, installed : List(Str), times : List({ id, published_at }), config : List(E), project : List(E) } -> [NoChannel, Free, Stop(E), NoTable(Str)]` | R-CH11, R-CH7, R-CH13 |

How they work:

| Function | Result |
| --- | --- |
| `named_ref` | `<name>@latest` and `<name>@<step>` (`@-1`, `@+2`, `@-10`) give the table and the text for `Nightlies.pick` (`@latest`, `@-1`). `nightly@...` is `Builtin` (no table, no consent, R-CH2). A table of `config.toml` wins: `User`. The project only: `ProjectOnly` (exit 19). No table: `NoTable(name)` (exit 2, the text of `Channel.unknown_text`). The word `nightly` alone is `Builtin("@latest")` (Q616 item 4). After a name only `latest` and a step are allowed: `reify@abc1234`, `reify@2026-11-03`, `reify@<id>`, `nightly@<tag>` give `BadSelector(selector)` (Q616 item 3; a project-only table gives `ProjectOnly` first). Any other text, also a bare name of a user channel, `@latest`, `@-1`, `acme/json@1.0.0`, `reify@`, a bad name, an id: `NotNamed`. The name is read to the first `@`, so `my-fork@latest` is channel `my-fork`. |
| `pin_trust` | `text` is the text of `[toolchain] roc`. A range that names no user build (`*`, a semver range, `=<nightly>`, `>=<nightly>`, a release, a text that is not a range): `NoChannel`. `=<user id>` or `>=<user id>`: the table in `config.toml` is `Free`. The project only is `Stop(table)`, unless an installed id is in the range (`Pin.admits`): then no list is needed and the result is `Free` (R-CH13). The channel is read from the right (R-CH5), so `=my-fork-...` is the table `my-fork`, not `my`. No table in either file and no installed build in range: `NoTable(name)` (Q616 item 1, exit 2). |
| `pin_warning` | `Ok(message)` when the pin names a user build, the table is in `config.toml` and not in the project `talon.toml` (Q616 item 8). `Err(None)` in every other case (both files; the project only is the stop; no table is exit 2; a range with no user build). |

Existing functions that change (no new name): `Pin.parse_req`, `Pin.admits`, `Pin.order` (or `PinOrder.order_of`), `Compiler.select` (`in_range`), `Compiler.toolchain_of`, `Nightlies.pick` (refuses `@<user id>`).

## Tests

### L0 (new files, imported by the existing driver tests/unit/l0-9.roc)

ChannelrangeTest compiles today. Its failing rows are red for missing behavior. ChannelrefTest needs the new names.

| # | File | Test | Rules | State now |
| --- | --- | --- | --- | --- |
| 1 | ChannelrangeTest | `Pin.parse_req`, 14 rows: `=<user id>` and `>=<user id>` (also a name with `-`) are `Exactly` and `AtLeast`; a prefix, a bare name, a short sha, a month name id and a `git-` id are `BadReq`; guards for a nightly, a release, `*` and a semver range. | R-CH7 R-NS7 R-R4 | red (4 rows) |
| 2 | ChannelrangeTest | `Pin.admits`, 33 rows: `*`, a semver range, `>=<nightly>` and `=<nightly>` never admit a user build (also a newer one, also one of a later year); `=<user id>` admits that id only; `>=<user id>` admits the builds of that channel at or after the bound (month, year, same day by `published_at`) and no nightly, release or other channel; `my-fork` is not `my`. | R-CH7 R-CH9 R-NS1 | red (8 rows) |
| 3 | ChannelrangeTest | `Pin.order` for two ids of one user channel, 9 rows: date, month, year over month, same day with and without `published_at`, a name with `-`. | R-CH9 R-NS1 | red (8 rows) |
| 4 | ChannelrangeTest | `Compiler.select` rank 4, 14 rows: `=<user id>` selects that build (also over the default); `>=<user id>` the newest build of the channel, not the newer nightly; none installed is `NoneInRange`; with `nightly` false a user build is no candidate; guards: `*`, `>=<nightly>`, a semver range never take a user build, and rank 6 with a user default. | R-CH7 R-CH9 R-SO4 R-SO13 R-CH5 | red (4 rows) |
| 5 | ChannelrangeTest | `Compiler.toolchain_of`: a user id is a value of `ROC_TOOLCHAIN` (also a name with `-`); a prefix, a bare name, a month name id and a short sha are refused. | R-CH5 | red (2 rows) |
| 6 | ChannelrangeTest | `Pin.decide`, 4 rows: a held user build gives no header write (with and without a range); the write of a nightly is as before; a header pin outside `=<user id>` is `outside`. | R-CH6 R-R4 R-RP2 | green (guard) |
| 7 | ChannelrangeTest | `Compiler.kind` of a user id is `Local` (so ProbeShare does not share it); `Pin.counts_as_nightly` is true and `Pin.is_nightly` false. | R-CH16 R-R4 R-CH9 | green (guard) |
| 8 | ChannelrangeTest | `Nightlies.pick`: `@<user id>` is refused (R-SL6); the id with no `@`, a prefix with one match, `@latest` and `@-1` from a base keep their meaning (guards). | R-SL6 R-CH5 R-SL7 | red (2 rows) |
| 9 | ChannelrefTest | `Channel.named_ref`, 37 rows (see How they work), with the rows for the bare `nightly` and the bad selectors. | R-CH8 R-CH11 | red (does not compile) |
| 10 | ChannelrefTest | `Channel.pin_trust`, 22 rows (2 rows `NoTable`, Q616 item 1): no stop for a range with no user build, also with an unused project table; `Free` with a config table; `Stop` for the project only; `Free` when an installed build is in the range (`=<id>` and `>=<id>`); `my-fork` and `my`. | R-CH11 R-CH6 R-CH7 R-CH13 | red (does not compile) |
| 11 | ChannelrefTest | `Channel.trust_text` for `my-fork` (the stop of a pin is the stop of 240). | R-CH11 | red (does not compile) |
| 12 | ChannelrefTest | `Channel.bad_selector_text` for `reify@abc1234`. | R-CH8 | red (does not compile) |
| 13 | ChannelrefTest | `Channel.pin_warning`, 10 rows (Q616 item 8). | R-CH6 | red (does not compile) |

Q616 item 5 (no order across channels): ChannelrangeTest 2 has 3 more rows (a range never mixes channels: `=reify-...` does not admit `my-fork-...`; `>=my-fork-...` does not admit a later reify build and the reverse). `Pin.order` has no result for "no order" (`Same` means equal), so it is tested for builds of one channel only. Item 6 (an installed pinned build with a project-only table is `Free`): rows 12, 16 and 17 of test 10, kept.

### L2 (tests/commands/cases/channels/)

The fake hosts are the harness base `api.github.com` and the `resolve` and `commands` entries. `TALON_NOW` is 2026-11-10 (`commands` cases) and 2026-10-15 (the `resolve` entry).

| Case | Entry | Commands and what it checks | Rules | State now |
| --- | --- | --- | --- | --- |
| ch06-pin-trust | resolve | Runs 5 and 6 are new (Q616): run 5 `nightly=false` with a project-only table: exit 19 (the stop before exit 10); run 6 the pin names `reify` and no file has a table: exit 2, `unknown compiler channel reify. Add it: tln roc channel add reify <URL>`. Runs 1 to 4: The project has `[toolchain] roc = "=reify-2026-11-03-1708298"` (runs 1, 3, 4) or `">=reify-2026-11-01-0000000"` (run 2) and `[channels.reify]`; `config.toml` has no table; the build is not installed. `install file=...`: exit 19, the 2 lines of R-CH11, no request. Run 3 `offline`: exit 19, not 15. Run 4 `auto-install=yes yes`: no consent. | R-CH6 R-CH7 R-CH11 R-EC19 | red (stderr is the R-TF8 hint of the old fault; the calls.log differ) |
| ch07-pin-exact | resolve | `roc = "=reify-2026-11-03-1708298"`; 2 reify builds and 2 nightlies installed, the build is newer than the nightlies. `update json`: the probes run on the reify build, the facts are in `compat.tsv` under its id, and no `roc:` pin is written (no `+ roc:` line, `main.roc` has no `roc:` entry). | R-CH6 R-CH7 R-R4 R-CH16 | red (exit 19) |
| ch07-pin-atleast | resolve | `roc = ">=reify-2026-10-30-abc1234"`: rank 4 selects reify-2026-11-03-1708298, the newest build of the channel, not the nightly that is newer. No header write. | R-CH7 R-R4 | red (exit 19) |
| ch07-pin-warn | resolve | As ch07-pin-exact, but the project `talon.toml` has the pin and no `[channels.reify]` table (config.toml has it, the build is installed). One warning line on stderr, then the same run, output and tree as ch07-pin-exact. | R-CH6 R-R4 Q616-8 | red (exit 19) |
| ch07-no-user | resolve | Guard. Same installed set. `roc = "*"` and `">=nightly-2026-10-14-38a3029"` select nightly-2026-10-20-bbbbbbb. | R-CH7 R-CH9 | green (guard) |
| ch08-named-latest | commands | `[channels.reify]` in `config.toml`. Run 1 `roc install reify@latest --yes`: as the bare name (the same calls as ch11-install run 1). Run 2 `roc install nightly@latest --yes`: the newest nightly that `min-release-age` allows (a 1 day old nightly is hidden), the default stays. Run 3 `foo@latest --yes`: exit 2, `unknown compiler channel foo. Add it: tln roc channel add foo <URL>`, no request. Run 4 `reify@latest`: installed, no request. | R-CH8 R-CH9 R-NS3 R-C7 Q615-5 Q615-7 | red (`no compiler matches reify@latest`) |
| ch08-step-name | commands | `default-roc` is an installed nightly, no reify build installed. `reify@-1 --yes` installs reify-2026-10-30-abc1234, the second newest, with no base read; `reify@+1 --yes` exit 2 (`no compiler is 1 step newer than reify-2026-11-03-1708298`); `reify@-1` again: installed. | R-CH8 R-SL7 Q616-2 | red (no match) |
| ch08-bad-selector | commands | `reify@abc1234`, `reify@2026-11-03`, `reify@<full id>`, `nightly@abc1234`: exit 2, message and hint, no request. | R-CH8 R-SL6 Q616-3 | red |
| ch08-bare-nightly | commands | `roc install nightly --yes` installs the newest allowed nightly (the same as `nightly@latest`). | R-CH8 R-SC10 Q616-4 | red (ambiguous prefix) |
| ch08-step | commands | `default-roc` is the installed build reify-2026-11-03-1708298, the newest of the channel (the list has a prerelease). Run 1 `roc install @-1 --yes`: installs reify-2026-10-30-abc1234 (the step is inside the channel of the selected compiler), the default does not move. Run 2 `@+1 --yes`: exit 2, `no compiler is 1 step newer than reify-2026-11-03-1708298`. Run 3 `reify@-1`: installed, no install. | R-SL7 R-CH8 R-CH11 R-CH13 R-CH16 Q615-6 | red (the nightlies list is read) |

Where the expected files come from. The test agent had no code to bake from, so the files of the success cases are the real run of the same case with the ids of nightlies, with the ids changed (a "twin" run, then a sed):

| Case | Change from the twin run |
| --- | --- |
| ch07-pin-warn | The files of ch07-pin-exact, with the warning line on stderr. |
| ch08-step-name | The files of ch08-step with the base lines (`cwd`, `canonical $PROJECT/main.roc`, `read_files`) removed and the commands with the name. |
| ch08-bare-nightly | The real run with `@latest`. |
| ch07-pin-exact, ch07-pin-atleast | `nightly-2026-11-03-1708298` and `nightly-2026-10-30-abc1234` become `reify-...`; the line `+ roc: ...` of stdout and the `roc:` line (and the hunk size) of the `main.roc` diff are removed (R-R4). |
| ch08-step | The repo, the asset names and the ids become those of `Karakatiza666/roc-reify-nightlies`; the 3 lines `lock`, `read_files`, `unlock` of `config.toml` (the default) are removed (Q615 item 6); the pinned rows get the 2 columns `reify` and the source; `.talon.json` gets `channel` and `source` (as in ch11-install). |
| ch08-named-latest | The real run with the old forms (`reify`, `@latest`, `foo`, `reify`). |

Calls.log lines. A line that the design does not fix is a guess; the code agent may send a dispute (TW18) and the test agent bakes the real lines after review. The guesses: all lines of ch06-pin-trust after the read of the three files (the `list_dirs` of `toolchains` and the read of its `.talon.json` come after the config read; the stop comes before any list), the lines of ch07-pin-exact and ch07-pin-atleast (the flow of an installed compiler selected by rank 4; the read of `config.toml` is the same as before), the base lines of ch08-step (`cwd`, `canonical $PROJECT/main.roc`, `read_files` with no path: the flow of `Base.selected!`), and the calls of ch08-step run 3.

### Run results (TMPDIR in `.tmp/tmp`, capped scope `MemoryMax=16G`; nothing died at the cap)

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` | Does not compile: `Channel.named_ref`, `Channel.pin_trust`, `Channel.bad_selector_text` and `Channel.pin_warning` do not exist (red on purpose). |
| ChannelrangeTest alone (a temporary driver) | 2 passed (tests 6 and 7), 6 failed (tests 1 to 5 and 8): the failing rows are listed in the table above. |
| `tests/commands/run.sh channels/` | 21 passed, 9 failed (ch06-pin-trust, ch07-pin-atleast, ch07-pin-exact, ch07-pin-warn, ch08-bad-selector, ch08-bare-nightly, ch08-named-latest, ch08-step, ch08-step-name). ch07-no-user is green (guard). |
| `MISSING=1 scripts/rules.sh R-CH6 R-CH7 R-CH8 R-CH9 R-SL7 R-R4 R-CH11 R-CH13 R-CH16` | no rule without a test |

## Disputes of the code agent (accepted by the manager, 2026-11-11)

| # | Dispute | Fix |
| --- | --- | --- |
| 1 | ch07-pin-exact and ch07-pin-atleast: `expect/stderr` held the old failure of the red run. Exit 0 and a success stdout need an empty stderr. | The file is removed (empty). Rule: no case with exit 0 has an error on stderr. |
| 2 | ch07-pin-exact, ch07-pin-atleast, ch07-pin-warn: the hunk of `project/p1/main.roc` in `tree.diff` was edited by hand. | Taken from the real diff: `@@ -1,6 +1,6 @@`, no trailing context line. |
| 3 | ch08-step, calls.log run 3 (`reify@-1`): had the lines `cwd`, `canonical $PROJECT/main.roc`, `read_files `. A named step reads no base (Q616 item 2). | The 3 lines are removed (as in ch08-step-name). |
| 4 | `.talon.json` `typed` is the ref as the user typed it (DESIGN-CLI R-R1). | `nightly` (ch08-bare-nightly), `reify@latest` and `nightly@latest` (ch08-named-latest), `reify@-1` (ch08-step-name). |

I took each changed line from the real binary output and kept it only when it agrees with the design. After the fix all old cases pass.

### Disputes of the second round (accepted by the manager, 2026-11-11)

| # | Dispute | Fix |
| --- | --- | --- |
| 5 | ch07-pin-download and ch07-pin-download-atleast: the calls.log had the lines `lock`, `read_files`, `unlock` of `config.toml`. They are the set-default step of the nightly twin run; a user build never sets the default (Q615 item 6). The `main.roc` hunk of `tree.diff` was the hand-edited one. | The 3 lines are removed. The hunk is the real `@@ -1,6 +1,6 @@` with no trailing context line. |
| 6 | ch08-step-trust and ch08-step-unknown: the header of `given/project/main.roc` had `roc: "nightly-2026-10-14-38a3029"`. Rank 3 then selects that nightly, so the case did not test a user-build base. | The header entry is removed. The calls.log tail has the project search of R-CH11 (`cwd`, `list_dirs $PROJECT`, `list_dirs $WORK`, and `read_files $PROJECT/talon.toml` for the trust case) in place of `path_roc`. |
| 7 | ch07-proxy-warn, calls.log after `list_dirs toolchains`: the times read of the pinned build and the PATH-roc check of a Range rank were missing. | Added: `read_files .../reify-2026-11-03-1708298/.talon.json` (R-NS1), then `path_roc`, `read_files talon/path-roc.json`, `spawn_all limit=1` with `$WORK/bin/roc version`, `write_atomic path-roc.json`. Then `.last-use` and the exec, as before. |

Each changed line was taken from the real binary output and kept because it agrees with the design.

## Cases A to C (new, 2026-11-11)

They are derived from R-CH7, R-CH11, R-SL7 and Design Q615 note 2 (the code agent asked about them). They are red now: the code reads `roc-lang/nightlies` for a user build.

| Case | Entry | What it checks | Rules | State now |
| --- | --- | --- | --- | --- |
| A: ch07-pin-download | resolve | `roc = "=reify-2026-11-03-1708298"`, the table in config.toml and in the project talon.toml (so no warning), the build is not installed. `update json ... allow-downloads`: Talon lists `Karakatiza666/roc-reify-nightlies` (direct), downloads the build, runs the probes on it, writes no `roc:` pin. No request to roc-lang/nightlies, none to a registry. The expected files are a twin run with nightlies, changed as in ch07-pin-exact (the repo, ids, `channel` and `source`, the pinned columns; the file order of `tree.diff` is by byte order). `typed` is the id of the pin (guess). | R-CH6 R-CH7 R-CH16 R-CV3 R-R4 | red (`no GitHub repository roc-lang/nightlies`) |
| A: ch07-pin-download-atleast | resolve | The same with `>=reify-2026-10-30-abc1234`: the newest build of the channel, the same files. | R-CH7 R-CH16 | red |
| B: ch08-step-trust | commands | `@-1` with no name, `default-roc` is the installed user build reify-2026-11-03-1708298, config.toml has no table, only the project talon.toml has it: exit 19, the 2 lines of R-CH11. No fallback to the nightlies list. | R-SL7 R-CH8 R-CH11 R-EC19 | red (reads roc-lang/nightlies) |
| B: ch08-step-unknown | commands | The same, no file has the table: exit 2, `unknown compiler channel reify. Add it: tln roc channel add reify <URL>`. | R-SL7 R-CH8 Q615-7 | red |
| C: ch07-proxy-trust | commands | The roc proxy (`@roc check p1/main.roc`) in a project that pins `=reify-2026-11-03-1708298`, the table only in the project, the build not installed: exit 19 before any request. Run 2 with `TALON_AUTO_INSTALL=yes` and CI: the same. | R-CH6 R-CH11 R-EC19 | red (reads roc-lang/nightlies, exit 2) |
| C: ch07-proxy-warn | commands | The table only in config.toml, the build installed, no project table: the pin warning on stderr, then the build runs (`.last-use`, `exec` of toolchains/reify-2026-11-03-1708298/roc). | R-CH6 R-CH13 R-R4 | red |

The calls.log lines of the new cases are guesses (TW18): the place of the stop after the project search in B and C, the `projects.json` writes, and the lines of the exec in ch07-proxy-warn (from proxy/px2-install).

Result: `tests/commands/run.sh channels/` 30 passed, 6 failed (exactly the 6 new cases).

## Coverage gaps (not questions)

| Gap | Why |
| --- | --- |
| The stop of a pin is tested through `install` (the `resolve` entry) only. | `update`, `verify`, `run`, `x`, `tool install` and the `roc` proxy reach rank 4 through the same code. The L0 function `Channel.pin_trust` decides for all. The code agent calls it in the shared place. A command that skips the call is not caught by this slice. |
| `roc +<id>` (rank 1) with a user id. | R-CH5. `ROC_TOOLCHAIN` (rank 2) is tested at L0 (`Compiler.toolchain_of`). The proxy argument has no case. |
| `reify@latest` with `nightly = false` or a young build. | The bare name is tested in 240 (ch11-switch-off, ch11-young). `reify@latest` is the same function; the code agent shares the path. |

## Mutation check (TW12)

The code agent runs these after the code is green (about 10 mutants, the most tricky).

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | `Pin.admits` with `Any` or a semver range admits a user build | ChannelrangeTest 2 |
| m2 | `AtLeast(<user id>)` ignores the channel name (admits `other-...`) | ChannelrangeTest 2 |
| m3 | `AtLeast(<nightly>)` admits a user build (Q612 item 3) | ChannelrangeTest 2 and 4 |
| m4 | The name of an id is read from the left (`my` takes `my-fork-...`) | ChannelrangeTest 2, ChannelrefTest 9 and 10 |
| m5 | The same day is ordered by the tag text, not by `published_at` | ChannelrangeTest 2, 3 and 4 |
| m6 | A user build ignores the `nightly` switch in rank 4 | ChannelrangeTest 4 |
| m7 | `Pin.decide` or the header edit writes a user id (R-R4) | ChannelrangeTest 6, ch07-pin-exact |
| m8 | `pin_trust` stops when the build is installed | ChannelrefTest 10 |
| m9 | The pin stop comes after the list request, or after `--offline`, or `--yes` skips it | ch06-pin-trust (runs 1 to 4) |
| m10 | `@-1` with a user build as the base steps in the nightly list | ch08-step |
| m11 | `nightly@latest` goes to the channel code, or needs a table | ch08-named-latest (run 2), ChannelrefTest 9 |
| m12 | `@<user id>` is accepted as a ref | ChannelrangeTest 8 |
| m13 | A probe result of a user build is shared (`Compiler.kind` is `Nightly`) | ChannelrangeTest 7 |

## Changed expectations

None. No existing test, case or expected file changes. `l0-9.roc` gets two imports (ChannelrangeTest, ChannelrefTest).

## Open questions (TW17)

All 8 were answered on 2026-11-10 (Design Q616, G-C246; DESIGN-CLI.md R-CH6, R-CH7, R-CH8, R-CH11, R-SC10).

| # | Question | Answered | Tests |
| --- | --- | --- | --- |
| 1 | A pin `=<user id>` or `>=<user id>`, the build not installed, no table in either file | Answered: exit 2, `unknown compiler channel <name>. Add it: tln roc channel add <name> <URL>` (as R-CH8). | ChannelrefTest 10 (2 rows), ch06-pin-trust run 6 |
| 2 | `<name>@-N` and `<name>@+N` when the selected compiler is not in the channel | Answered: they count from `<name>@latest` (the newest allowed build, after the switch and `min-release-age`), whatever the selected compiler is. `reify@-1` is the second newest. A step with no name keeps R-SL7. | ch08-step-name (default is a nightly), ch08-step (no name) |
| 3 | A selector after a name other than `latest` and a step | Answered: exit 2 (usage) with a hint to use the full id. | ChannelrefTest 9 and 12, ch08-bad-selector |
| 4 | The bare word `nightly` | Answered: it is `nightly@latest`, and replaces the ambiguous-prefix error of R-SC10 for that exact word. | ChannelrefTest 9, ch08-bare-nightly |
| 5 | The order of builds across channels | Answered: there is no order across channels. A range never mixes channels. | ChannelrangeTest 2 (3 rows) |
| 6 | The pin stop when the build is installed and the table is only in the project | Answered: confirmed: `Free`, no stop (R-CH13). | ChannelrefTest 10 (rows 12, 16, 17) |
| 7 | `nightly = false` with a pin and a project-only table | Answered: exit 19 first (the trust stop), not exit 10. | ch06-pin-trust run 5 |
| 8 | A pin whose table is only in `config.toml` | Answered: a warning, not a stop, then the normal run. The text is a TW24 proposal. | ChannelrefTest 13, ch07-pin-warn |

## Output (TW24)

Texts and files that the design does not give. They are proposals for the human review.

| Item | Proposal | Case |
| --- | --- | --- |
| Trust stop of a pin, on stderr | The 2 lines of 240: `tln: error[input]: talon.toml uses compiler channel reify (github.com/Karakatiza666/roc-reify-nightlies).` and `Run: tln roc channel add reify` | ch06-pin-trust, ChannelrefTest 11 |
| Header after a user build is selected | No `+ roc:` line, no note, and no `roc:` entry in the header (as for a `git-` build, R-R4). | ch07-pin-warn | The files of ch07-pin-exact, with the warning line on stderr. |
| ch08-step-name | The files of ch08-step with the base lines (`cwd`, `canonical $PROJECT/main.roc`, `read_files`) removed and the commands with the name. |
| ch08-bare-nightly | The real run with `@latest`. |
| ch07-pin-exact, ch07-pin-atleast |
| Facts of a user build | `compat.tsv` has the `fact` rows under the id `reify-2026-11-03-1708298`, like any other compiler id. | ch07-pin-exact |
| Unknown channel in a ref | `tln: error[usage]: unknown compiler channel foo. Add it: tln roc channel add foo <URL>` (the text of Q615 item 7 for `foo@latest`) | ch08-named-latest |
| Step past the newest build | `tln: error[usage]: no compiler is 1 step newer than reify-2026-11-03-1708298` (`Nightlies.failure`, `OutOfRange`) | ch08-step |
| Install output of a step | As 240: `installed reify-2026-10-30-abc1234`, `downloading reify-2026-10-30-abc1234 (73.1 MB)` on stderr, `<id> is already installed` | ch08-step |
| Refusal of `@<user id>` | The text is not fixed by a test (the L0 row checks only that it is an error). Proposal, kind `Usage` (exit 2): `@reify-2026-11-03-1708298 is a user-channel tag, not a ref. Use reify@latest or reify@-1`. | ChannelrangeTest 8 |
| Bad selector (Q616 item 3), exit 2, kind Usage | Two lines. Message: `reify@abc1234: only latest or a step (-1, +1) can follow a channel name`. Hint: `To name one build, use its full id: tln roc install reify-<date>-<sha>`. | ch08-bad-selector, ChannelrefTest 12 |
| Warning for a pin without a project table (Q616 item 8), one line on stderr | `warning: talon.toml pins roc "=reify-2026-11-03-1708298", but it has no [channels.reify] table. Other machines and CI cannot resolve the pin. Copy the table from config.toml to talon.toml.` (for a range the pin text is as written, for example `">=reify-2026-10-30-abc1234"`) | ch07-pin-warn, ChannelrefTest 13 |
| No table for a pin (Q616 item 1) | `tln: error[usage]: unknown compiler channel reify. Add it: tln roc channel add reify <URL>` | ch06-pin-trust run 6 |
| Names | See Proposed names | ChannelrefTest |
