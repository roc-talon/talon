# 240 install from a channel

Phase: P2. Status: done (2026-11-10). Design Q612 (G-C242), Q613, Q614 (G-C244), Q615 (G-C245, the 8 answers below, accepted 2026-11-10). The user accepted the TW24 texts on 2026-11-10. Mutations: all caught after the fixes, except m16 (equivalent) (research/slice-240-revert/RESULT.md). Close run: check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only).

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CH11 (Design Q612 item 1, CLI 6.8) | A built-in channel needs no consent. Talon lists or downloads from a user channel only when `config.toml` has its table. When only the root `talon.toml` has the table: exit 19 before any request, `talon.toml uses compiler channel reify (github.com/<source>). Run: tln roc channel add reify`. `--yes` and `TALON_AUTO_INSTALL` do not give this consent. |
| R-CH13 | `.talon.json` and the R-CV6 first-seen row record `channel` and `source`. An installed build stays selectable by its id after its channel is removed. |
| R-CH16 | A user-channel build is local only: listed with `direct` also when a registry is set, no toolchain rows, no share. Probe results stay in `compat.db` under its id. |
| R-CV3, R-CV5, R-CV6 | The sha256 of a user channel is the GitHub `digest`. `.talon.json` holds `channel` and `source`. The first-seen row holds them too. |
| R-CH4 (Q614 item 8) | The download URL is `browser_download_url` of the answer, as it is. |
| R-CH8 | A bare `<name>` means `<name>@latest`. |
| R-NS4, R-SC10, R-SC13, R-CH5 | `tln roc install <id>` and `tln roc default <id>` name the compiler: no switch. A user id is the value of `default-roc`. |
| R-EC19 | Exit 19 for the stop of R-CH11. |

Source: research/compiler-channels/PROPOSAL.md, DESIGN-CLI.md 6.8, row 240 of docs/slices/PLAN-P2-CLI.md.

Out of scope (later slices, not tested here): selection and ranges (241), the `tln roc channel` commands (242; the tests put the table in `config.toml`), `roc use`, `upgrade`, `update <name>`, GC and the `roc list` marks (243).

## Scope

Facts found in the code and by the first runs of the new cases (before any change).

| Fact | Where | Consequence for the tests |
| --- | --- | --- |
| `tln roc install` reads `config.toml` only. It reads no `talon.toml` (R-PD16: no project). | `RocInstall.offer_noted!` (step 2) | The trust stop needs a new read of the project `talon.toml`. The read is the normal project search (as `tln install`), and only for a text that can be a user channel that `config.toml` has no table for. The existing cases must not get a new read (the calls.log of a nightly install stays). Design Q615 item 4. |
| Text `reify` or `reify-<date>-<sha>` goes to the nightly list today (`roc-lang/nightlies`). | `Toolchain.read`, `Nightlies.list_of!` | Red: the new cases get a request to `roc-lang/nightlies`. |
| `Nightlies.list!` has `roc-lang`, `nightlies` fixed. The index cache dir is `talon/index/github/<owner>/<repo>/`. | Nightlies.roc | The new cases expect `talon/index/github/Karakatiza666/roc-reify-nightlies/1.json` (accepted 2026-11-10). |
| `Toolchain.meta_from` has no `channel` or `source`. `Db.Pinned` has 4 fields. | Toolchain.roc, Db.roc | L0 test 3. The pinned row is only in L2 (compat.tsv). |
| `roc default <full user id>` works today (the id is installed). A user id in `default-roc` is refused when the config is read next time (`default-roc: must be a full compiler id`). A prefix of a user id goes to the nightly list. | Run of ch13 | Red for run 2 and 3 of ch13-default-by-id (R-CH5: the id is the value of `default-roc`). |
| Commands that can start a compiler install from a project: the `roc` proxy (R-PX4, auto-install of the pin), `tln install`, `tln run`, `tln x`, `tln tool install`, `tln roc update`. They select by a pin. A project holds a user-channel pin only as `[toolchain] roc = "=<id>"` (R-CH6, R-CH14), and `=<id>` with a user id is the range of slice 241 (R-CH7). | Intent.roc `[toolchain] roc` | The trust stop through these commands cannot be reached before 241. Only `tln roc install <channel>` reaches it in 240. Design Q615 item 2: the stop through a pin is tested in 241. |

## Proposed names (TW24, for the code agent)

A name that the design does not give is a proposal. Until the names exist, the L0 file does not compile: red on purpose (as slices 236, 238, 239).

| Name | Type | Rule |
| --- | --- | --- |
| `Channel.install_ref` | `{ text : Str, config : List(E), project : List(E) } -> [NotChannel, Latest(E), Build(E, Str), ProjectOnly(E)]`, `E = { name, source, tag_prefix }` | R-CH11, R-CH8, R-CH5 |
| `Channel.trust_text` | `{ name, source, .. } -> { message : Str, hint : Str }` | R-CH11 |
| `Channel.unknown_text` | `Str -> Try(Str, [NotChannelText])`: the exit 2 text for a name or an id of a name with no table (Q615 item 7) | R-CH11 |
| `Toolchain.meta_from` | the first argument gets the optional field `channel ?: { name : Str, source : Str }` | R-CV5, R-CH13 |
| `Nightlies.source_for` | `Nightlies.Source, Str -> Nightlies.Source` (the channel name) | R-CH16 |

## Tests

### L0 (ChannelinstallTest, new file, imported by the existing driver tests/unit/l0-9.roc)

| # | Test | Rules | State now |
| --- | --- | --- | --- |
| 1 | `Channel.install_ref`, 26 rows: bare name and id with a config table; both files (config wins); project only (bare name, id, another name in config); no table; the id of another channel; a name with `-` read from the right (`my` and `my-fork`); `gitfork`; a month name id; a nightly id; `nightly`; a sha prefix; `@latest`; a release; a git id; a prefix of a user id; a short sha; empty text. | R-CH11 R-CH8 R-CH5 | green |
| 2 | `Channel.trust_text` for `reify` and `my-fork`. | R-CH11 | green |
| 3 | `Toolchain.meta_from` with `channel`: the 2 keys after `published_at`. Guard: with no `channel` the text is that of `Toolchain.meta`, byte for byte, with no `channel` and no `source` key. | R-CV5 R-CH13 | green |
| 5 | `Channel.unknown_text`, 16 rows (5 added after mutant m13: all-hex texts `abcdef1`, `abc1234`, `dead`, `dd03c09e5f0a3b6c` give `NotChannelText`, and `abcdefg` is a name; open question 9 answered: R-CH5 and R-CH7 keep the old forms): a bare name, an id, a name with `-`; no text for a nightly id, `nightly`, a git id, `@latest`, a release, a month name id, a bad name, empty. | R-CH11 Q615-7 | green |
| 4 | `Nightlies.source_for`, 7 rows: `nightly` keeps `Registry` (also with a snapshot) and `Direct`; a user name (also `my-nightly`) gives `Direct`. | R-CH16 R-CV3 | green |

### L2 (tests/commands/cases/channels/)

The fake GitHub API is the harness base `api.github.com` (as `roc/ri1-flow`; `fx/http/api.github.com/repos/<owner>/<repo>/releases%3Fper_page=100`). The list of `Karakatiza666/roc-reify-nightlies` has 6 releases: a prerelease, a draft, a build with a Windows asset only, a `nightly-` tag of the nightly form, and 2 builds with a Linux asset (`reify-2026-11-03-1708298` with the GitHub URL form, `reify-2026-10-30-abc1234` with a URL on another host). `TALON_NOW` is 2026-11-10, so all builds are older than `min-release-age`.

| Case | Commands and what it checks | Rules | State now |
| --- | --- | --- | --- |
| ch11-install | `roc install reify --yes` (newest build: download, `.talon.json` with `channel` and `source`, the 2 pinned rows with `channel` and `source`, the default stays); `roc install reify-2026-10-30-abc1234 --yes` (cached list; the URL is `browser_download_url` as it is); `roc install reify-2026-11-03-1708298` (installed: no request). | R-CH11 R-CH13 R-CH4 R-CH5 R-CH8 R-CV3 R-CV5 R-CV6 | green |
| ch16-registry-set | A registry in `config.toml` with no fake answer. `roc install <id> --yes`: one GitHub list call, no registry call, no toolchain row, pinned source `github-digest`. | R-CH16 R-CV3 | green |
| ch11-project-only | The root `talon.toml` has `[channels.reify]`, `config.toml` has none. `roc install reify --yes`, the same with an id, with `TALON_AUTO_INSTALL=1`, and with `--offline`: exit 19, 2 stderr lines, no request, no write. Run 5: the command runs in `sub/` and the `talon.toml` is in the parent dir (the normal project search, Q615-4). | R-CH11 R-EC19 | green |
| ch11-switch-off | `nightly = false` in `config.toml`. `roc install reify --yes`: exit 10 (the switch applies to `@latest`, a user build counts as a nightly). `roc install <id> --yes`: installed (the id names the compiler). | R-CH8 R-CH9 R-NS2 R-NS3 R-NS4 Q615-5 | green |
| ch11-young | A build 1 day old is the newest. `roc install reify --yes` installs the older build (`min-release-age` uses `published_at`). `roc install <young id> --yes` installs the young build. | R-CH8 R-CH9 R-C7 R-NS4 Q615-5 | green |
| ch11-no-default | `config.toml` has only the table, nothing installed. `roc install reify --yes`: installed, no `is now the default compiler`, `config.toml` not changed, no lock of it. | R-CH15 R-SO24 Q615-6 | green |
| ch11-unknown | No table of the name in either file. `roc install reify --yes`, the id form, and the id of another name: exit 2, `unknown compiler channel <name>. Add it: tln roc channel add <name> <URL>`, no request. | R-CH11 Q615-7 | green |
| ch11-builtin-free | The same project-only table. `roc install nightly-2026-10-09-258ab27 --yes`: installed, exit 0; `.talon.json` and the pinned row have no `channel` and no `source` (guard). | R-CH11 R-CV1 | green (guard) |
| ch13-default-by-id | An installed user build whose channel has no table in `config.toml`. `roc default reify-2026-11-03` (a unique prefix), `roc default <full id>` again (already the default), `--json`. | R-CH13 R-CH16 R-CH5 R-SC10 R-NS4 | green |

Calls.log lines. A line that the design does not fix is a guess; the code agent may send a dispute (TW18) and the test agent bakes the real lines after review. The guesses: the lines of the project search in `ch11-project-only` and `ch11-unknown` (`cwd`, `list_dirs` of the dirs, `read_files $PROJECT/talon.toml`), the lines of `ch16-registry-set` (equal to the first download of `ch11-install`), the list lines before the exit 10 in `ch11-switch-off`, the missing config lock in `ch11-no-default`, the pinned rows of `ch11-young` (both listed builds), and runs 2 and 3 of `ch13-default-by-id`.

### Run results (TMPDIR in `.tmp/tmp`, capped scope `MemoryMax=16G`; nothing died at the cap)

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` | All (100) tests passed. |
| `tests/commands/run.sh` (all) | 587 passed, 0 failed. |
| `MISSING=1 scripts/rules.sh R-CH11 R-CH13 R-CH16 R-CV5 R-CV6 R-EC19 R-NS4` | no rule without a test (checked before the fixes; no rule id changed) |

### Fixes after the 5 disputes of the code agent (the manager accepted them)

| # | Fix | File |
| --- | --- | --- |
| 1 | A `?:` field is accepted only for a record literal: the guard of test 3 passes a literal without `channel` (the byte-for-byte check stays). | ChannelinstallTest |
| 2 | Q615 item 6: a user build never sets the default, so the 3 lines `lock`, `read_files`, `unlock` of `config.toml` before the rename are removed from ch11-install (runs 1, 2, 3), ch11-young (2 runs), ch11-switch-off (run 2) and ch16-registry-set. | calls.log |
| 3 | The project search takes the order of the code: `list_dirs <cache>/toolchains` before `cwd` (an installed id resolves before any project read, R-SC10, R-CH5), and `list_dirs $WORK` after `list_dirs $PROJECT` (the walk to the parent dir, no `main.roc` read). | calls.log of ch11-project-only, ch11-unknown |
| 4 | `share = true` in the `config.toml` of ch16-registry-set (as registry/cv1-roc-install-unread), so the share question is no `ask`. | given |
| 5 | ch13-default-by-id run 3 (`--json`): stderr has `reify-2026-11-03-1708298 is already the default compiler` (the `--json` rule, as roc/df1-default). | stderr |

I edited the expected files by hand (no `UPDATE=1`). After the edits every case passes, so the only differences from the code are these 5 points. No other difference was found.

### Mutation check (TW12)

The code agent runs these after the code is green (about 8 mutants).

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | The list of a user channel uses the registry when one is set | ch16-registry-set, ChannelinstallTest 4 |
| m2 | The trust check is made after the list request | ch11-project-only |
| m3 | `--yes` or `TALON_AUTO_INSTALL` skips the trust check | ch11-project-only |
| m4 | `ProjectOnly` also stops when `config.toml` has the table (config does not win) | ChannelinstallTest 1, ch11-install |
| m5 | The trust check stops a built-in channel or a nightly id | ch11-builtin-free, ChannelinstallTest 1 |
| m6 | The download URL is built from the tag, not `browser_download_url` | ch11-install (run 2) |
| m7 | `channel` and `source` are not written in `.talon.json`, or only in the pinned row | ch11-install, ChannelinstallTest 3 |
| m8 | A nightly gets `channel` and `source` (the guard) | ch11-builtin-free, all `roc/*` cases |
| m9 | The name is read from the left (`my` takes `my-fork-...`) | ChannelinstallTest 1 |
| m10 | An installed user build needs the table to be selected | ch13-default-by-id |
| m11 | The project search reads only the run dir | ch11-project-only (run 5) |
| m12 | The switch or `min-release-age` is not applied to a bare name, or is applied to an id | ch11-switch-off, ch11-young |
| m13 | The install of a user build sets the default when none is set | ch11-no-default |
| m14 | The project `talon.toml` is read when `config.toml` has the table, or for a nightly id | ch11-install, ch11-builtin-free (calls.log) |

## Changed expectations

None. No existing test, case or expected file changes. `l0-9.roc` gets one import.

## Answers (Design Q615, G-C245; accepted 2026-11-10)

| Q | Answer | Tests |
| --- | --- | --- |
| 1 | Only user-channel builds record `channel` and `source`. Nightly records do not change. | ch11-builtin-free, all `roc/*` cases |
| 2 | The trust stop through a pin goes to slice 241. In 240 only `tln roc install <channel>` is tested. | ch11-project-only |
| 3 | The first-seen row of a user build is keyed by the id. | ch11-install, ch16-registry-set |
| 4 | `tln roc install <name>` looks for the project `talon.toml` with the normal project search (as `tln install`), and only when `config.toml` has no table for the name. | ch11-project-only (run 5, parent dir), ch11-install (no project read) |
| 5 | A bare name is `<name>@latest`. The `nightly` switch and `min-release-age` apply. With `nightly = false`: exit 10. A build younger than the age is hidden. | ch11-switch-off, ch11-young |
| 6 | An install of a user build never sets the default, also when none is set. | ch11-no-default |
| 7 | No table in either file: exit 2, `unknown compiler channel <name>. Add it: tln roc channel add <name> <URL>`. | ch11-unknown, ChannelinstallTest 5 |
| 8 | The trust stop comes before `--offline`. | ch11-project-only (run 4) |

## Open questions (TW17)

9. (Answered: an all-hex text keeps its old form; the installed prefix wins.) A text that has the form of a channel name but no table, for example `reify-2026-11` (a prefix of an installed user id) or `abc1234`. R-SC10 says a unique prefix of an installed id gives the full id; Q615-7 says a name with no table is exit 2. The tests say: the prefix of an installed id wins (ch13-default-by-id, `roc default reify-2026-11`), and `Channel.unknown_text` only applies after that. Is that right? `Channel.unknown_text("abc1234")` is not tested.

## Output (TW24)

Texts and files that the design does not give. The user accepted all of them on 2026-11-10 (Design Q615), except the two marked new.

| Item | Proposal | Case |
| --- | --- | --- |
| Trust stop on stderr | Two lines: `tln: error[input]: talon.toml uses compiler channel reify (github.com/Karakatiza666/roc-reify-nightlies).` and `Run: tln roc channel add reify` (the text of R-CH11, in the 2 lines of the example in 6.8; the hint line is the second line, as other hints) | ch11-project-only, ChannelinstallTest 2 |
| Install output | As a nightly: `installed reify-2026-11-03-1708298` on stdout, `downloading reify-2026-11-03-1708298 (73.4 MB)` on stderr (with `--yes`), `<id> is already installed` | ch11-install |
| `.talon.json` | `channel` and `source` are the last two keys, after `published_at`: `..."published_at":"...","channel":"reify","source":"Karakatiza666/roc-reify-nightlies"}`. `typed` is the text of the user (`reify` for the bare name). `compat` is the sha of the compat dir. | ch11-install, ch16-registry-set, ChannelinstallTest 3 |
| `compat.tsv` | A pinned row of a user channel has 2 more columns: `pinned<TAB>reify-2026-11-03-1708298<TAB>linux_x86_64<TAB><sha256><TAB>github-digest<TAB>reify<TAB>Karakatiza666/roc-reify-nightlies`. A nightly row keeps 5 columns. Rows in the order of the id text. | ch11-install, ch16-registry-set |
| Index cache | `talon/index/github/<owner>/<repo>/1.json` with the `owner/repo` of the `source` as written | ch11-install |
| Names | See Proposed names | ChannelinstallTest |
| Exit 10 text (new, proposal) | `tln: error[no_tuple]: no build of channel reify is allowed, and nightly is false (set by nightly in config.toml)` (the form of R-NS2: the switch and its source) | ch11-switch-off |
| Exit 2 text | `tln: error[usage]: unknown compiler channel reify. Add it: tln roc channel add reify <URL>` (the text is Q615 item 7; the `tln: error[usage]:` prefix is the form of other errors) | ch11-unknown |

## Key of the first-seen row (Q615 item 3)

The row is keyed by the id, not the tag. The tests that check it: the `compat.tsv` part of the `tree.diff` of ch11-install (rows `pinned<TAB>reify-2026-10-30-abc1234...`, not `nightly-reify-...`), ch16-registry-set, ch11-young and ch11-no-default. A key by tag changes the file text, so these four cases fail.
