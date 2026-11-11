# 242 channel commands

Phase: P2. Status: done (2026-11-11). Design Q612 (G-C242), Q614, Q615, Q617 (G-C247), Q618 (G-C248). The user accepted the tests and the TW24 texts on 2026-11-11, and the extra `tln roc list --json` fields `channel`, `source`, `channel_removed` with the commit approval. 3 calls.log disputes of the code agent were accepted and re-baked from the real run. Mutations: 15 of 15 caught (research/slice-242-revert/RESULT.md). Close run: check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only).

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CH12 | `tln roc channel add <name> <URL> [--tag-prefix <p>]`. The name is required and comes only from the user. A name that R-CH3 rejects: exit 2. Forms: `https://github.com/<owner>/<repo>` (with `/`, `/releases` or `/releases/tag/<tag>` at the end) and `<owner>/<repo>`. Other forms: exit 2, `known channel sources: github.com/<owner>/<repo>`. Page 1 of the release list is read (`--offline`: exit 15). Tags that end with `<date>-<sha>` give the tag-prefix. 2 or more prefixes, or none: exit 2, listed, pass `--tag-prefix`. Exit 19 when installed ids of that name record another source. Writes the table to `config.toml`, prints it, the newest build, and whether it has an asset for this host. |
| R-CH13 | `add <name>` (no URL) copies the table from the project `talon.toml`, no network. `rm <name>` changes no installed build. `list` shows built-in and user tables. An installed build stays selectable by its id after its channel is removed; `tln roc list` marks it `(channel removed)`. |
| R-CH3, R-CH4 | The name and the forms of `source` and `tag-prefix` (checks that exist: `Channel.name_check`, `source_check`, `tag_prefix_check`). |
| R-CH10 | The table in `config.toml` has all its keys: `shape`, `source`, `tag-prefix`. |
| R-CH11 | The text of the trust stop already says `Run: tln roc channel add <name>`: this command is the consent. |
| R-CC6, R-CC7 | A write of `config.toml` is under the lock (`Fx.with_lock!`, `Wait` not used by the guess below: `nowait: held` as `roc default`). |
| R-OUT1 to R-OUT5 | The text of the new output is a proposal (TW24); the design examples (CLI 6.8 section 3) are fixed. |

Source: DESIGN-CLI.md 6.8, research/compiler-channels/PROPOSAL.md (revision 4), row 242 of docs/slices/PLAN-P2-CLI.md.

Out of scope (slice 243): `roc use`, `upgrade roc`, `roc update <name>`, GC. Also out of scope: the selection of a build by its id after `rm` (tested in slice 240, case `ch13-default-by-id`, where the config has no table).

## Behaviors

| # | Behavior | Exit | Rules |
| --- | --- | --- | --- |
| B1 | `add reify <URL>`: reads page 1, derives the prefix, appends the table to config.toml, prints `read`, `added`, the table, `newest`. | 0 | R-CH12 |
| B2 | The 4 URL forms are the same source. The name is the operand, never the repo name. | 0 | R-CH12 |
| B3 | A bad name, a reserved name, no name (only a URL), a URL that is no form: before any request. | 2 | R-CH12, R-CH3 |
| B4 | `--offline`: no request, no write. | 15 | R-CH12, R-DI12 |
| B5 | No tag ends with `<date>-<sha>`, or 2 prefixes: the text lists them. `--tag-prefix` gives the prefix; the tags of other prefixes do not count. | 2 / 0 | R-CH12, R-CH4 |
| B6 | An installed id of the name records another source. Same source or no record: no conflict. | 19 / 0 | R-CH12, R-CH13 |
| B7 | `add reify` (no URL): copies the table from the project talon.toml, no request. | 0 | R-CH13 |
| B8 | `rm reify`: removes the table (and the blank line before it) from config.toml. No toolchain file changes. | 0 | R-CH13 |
| B9 | `list`: the built-in row, then the tables of config.toml in file order. | 0 | R-CH13 |
| B11 | `add reify <URL>` when config.toml has the table: same source exit 0 "already added", no change, no request; another source exit 2 with the hint to `rm` first. | 0 / 2 | R-CH12 Q617-1 |
| B12 | Order of the checks: name, URL form, existing table, conflict (19), `--offline` (15), request. `--offline` is exit 15 also with a cached list. | 2 / 19 / 15 | R-CH12 Q617-2 |
| B13 | `--tag-prefix`: bad form exit 2 (no request); no tag on page 1 with it exit 2. A derived prefix that breaks R-CH4 (also empty) does not count. | 2 | R-CH12 Q617-3 |
| B14 | `add reify` (no URL): no project, no talon.toml or no table exit 2; equal table in config.toml exit 0; different table exit 19. | 2 / 0 / 19 | R-CH13 Q617 |
| B15 | `rm` of an unknown, built-in or project-only name: exit 2, no file changes. | 2 | R-CH13 Q617 |
| B16 | The newest build that `add` prints is the newest R-CH4 build of page 1 (no switch, no min-release-age); it says when there is no asset for the host. | 0 | R-CH12 Q617-4 |
| B17 | `list` shows a project-only table marked as not added; unequal tables exit 19. | 0 / 19 | R-CH13 Q617 |
| B19 | `add` reads page 1 only: a `Link: next` header does not cause a request for page 2. | 0 | R-CH12 |
| B20 | `--tag-prefix` with `rm` or `list` is a usage error. | 2 | R-OUT2 |
| B21 | Page 1 has no build (all tags are drafts or prereleases): exit 2, nothing written. The prefix derivation reads builds only. | 2 / 0 | R-CH12 Q618 |
| B18 | `--json` for `add`, `rm`, `list`; the usage texts of `roc channel` (TW24). | 0 / 2 | R-OUT2 |
| B10 | After `rm`, `roc list` shows the installed build with `(channel removed)`. Before `rm` it shows the source with no mark. | 0 | R-CH13 |

## Answers (Design Q617, 2026-11-11)

| Answer | What it says | Tested by |
| --- | --- | --- |
| R-CH12 (1) | Existing table: same source exit 0 "already added", no change, no request; another source exit 2 with a hint to `tln roc channel rm <name>` first. | L0 `exists_check`, `already_text`, `exists_text`; L2 ch12-add-exists |
| R-CH12 (2) | Order: name (2), URL (2), existing table, conflict (19), `--offline` (15), request. Always exit 15 with `--offline`, also with a cached list. | L2 ch12-add-order (4 runs) |
| R-CH12 (3) | Bad `--tag-prefix` form: exit 2. No tag on page 1 with it: exit 2. A derived prefix that breaks R-CH4, also empty, does not count. | L0 `prefix_given`, `given_text`, 6 new rows of `prefix_of_tags`; L2 ch12-add-given |
| R-CH12 (4) | The printed newest build is the newest R-CH4 build of page 1; no switch, no min-release-age; says when it has no asset. | L2 ch12-add-noasset (draft, prerelease, 1 day old Windows build, `nightly = false`) |
| R-CH13 (1) | `add <name>`, no URL: no project, no talon.toml or no table exit 2; equal table exit 0; different table exit 19. | L0 `copy_check`; L2 ch13-add-copy-errors |
| R-CH13 (2) | `rm` of an unknown, built-in or project-only name: exit 2; edits only config.toml. | L0 `rm_check`, `rm_fail_text`; L2 ch13-rm-errors |
| R-CH13 (3) | `list` shows a project-only table, marked as not added; unequal tables exit 19. | L0 `list_text`; L2 ch13-list-project |
| R-CH13 (4) | The `(channel removed)` row of `roc list` is in this slice; the default marks are in 243. | L2 ch13-rm (4 runs) |

## Proposed names (TW24, for the code agent)

Until the names exist, ChanneladdTest and ChannelfileTest do not compile: the driver `l0-9` is red on purpose. `E = { name : Str, source : Str, tag_prefix : Str }`. All in `Channel`. The types are in the header of each test file.

| Name | Type | Rule |
| --- | --- | --- |
| `source_of_url`, `url_text` | `Str -> Try(Str, [BadUrl])`, `Str -> { message, hint }` | R-CH12 |
| `prefix_of_tags`, `prefix_text` | `List(Str) -> Try(Str, [NoPrefix, Prefixes(List(Str))])`, `[..] -> Str` | R-CH12 |
| `prefix_given`, `given_text` | `{ given, tags } -> Try(Str, [BadPrefix, NoTag])`, `{ given, kind, source } -> Str` | Q617-3 |
| `exists_check`, `already_text`, `exists_text` | `{ name, source, config } -> [Absent, Same, Other(Str)]`, ... | Q617-1 |
| `source_conflict`, `conflict_text` | `{ name, source, installed } -> Try({}, [Conflict(Str)])`, ... | R-CH12 |
| `copy_check` | `{ name, config, project } -> [NoTable, Copy(E), Equal, Differ]` | R-CH13 (1) |
| `rm_check`, `rm_fail_text` | `{ name, config } -> [Found, Builtin, Missing]`, `{ name, kind, path } -> Str` | R-CH13 (2) |
| `table_text`, `add_edit`, `remove_edit` | text and edits of config.toml | R-CH12, R-CH13 |
| `list_text`, `list_data` | `{ config, project } -> Str`, `-> JsonDoc` | R-CH13 (3) |
| `added_text`, `copied_text`, `removed_text` | the prints | R-CH12, R-CH13 |

Not pure, so not in L0 (the code agent decides): the router entry `["roc", "channel", ...]` in `Run.roc` (today: `unknown command 'roc channel'`), the Args words, and the `roc list` rows for a user build.

## Tests

### L0 (new files, imported by tests/unit/l0-9.roc)

| # | File | Test | Rules | State now |
| --- | --- | --- | --- | --- |
| 1 | ChanneladdTest | `source_of_url`, 18 rows: the 5 forms, case and dots kept; http, other host, subdomain, no scheme, 1 part, empty, issues page, 3 parts, `.git`, a dot at the start, a bad character. | R-CH12 R-CH4 | red (no name) |
| 2 | ChanneladdTest | `url_text`: message and the hint of the design. | R-CH12 | red |
| 3 | ChanneladdTest | `prefix_of_tags`, 11 rows: one prefix, a stray tag, none, empty, month name, short sha, non-hex sha, text after the sha, 2 prefixes sorted, no double. | R-CH12 R-CH4 | red |
| 4 | ChanneladdTest | `prefix_text`: the design text for none; 2 and 3 prefixes. | R-CH12 | red |
| 5 | ChanneladdTest | `source_conflict`, 9 rows: other source, same, no record, other name, nightly id, `my` and `my-fork` (read from the right), 2 ids, none. | R-CH12 R-CH5 | red |
| 6 | ChanneladdTest | `conflict_text`; `added_text` (singular, plural, no asset); `copied_text`; `removed_text`. | R-CH12 R-CH13 | red |
| 7 | ChannelfileTest | `table_text`: the 4 lines of the design example. | R-CH12 | red |
| 8 | ChannelfileTest | `add_edit`, 7 rows: empty, key, no line end, blank line at the end, comment, another table, another channel; not TOML is exit 19. | R-CH12 R-CC6 | red |
| 9 | ChannelfileTest | `remove_edit`, 7 rows: only table, after a key, between tables, `reify2` stays, no table, empty, only `reify2`; not TOML is exit 19. | R-CH13 R-CC6 | red |
| 10 | ChannelfileTest | `list_text`, 6 rows (header, gaps, project-only, both files); `list_data` (`--json`). | R-CH13 Q617-7 | red |
| 11 | ChanneladdTest | `prefix_of_tags` 6 new rows (upper case, empty, 41 and 40 characters); `prefix_given` 9 rows; `given_text`. | R-CH12 Q617-3 | red |
| 12 | ChanneladdTest | `exists_check` 5 rows; `already_text`, `exists_text`. | R-CH12 Q617-1 | red |
| 13 | ChanneladdTest | `copy_check` 8 rows; `rm_check` 5 rows; `rm_fail_text`. | R-CH13 Q617 | red |

### L2 (tests/commands/cases/channels/)

All use the `commands` entry (`exit N` is printed), fake hosts, `TALON_NOW=2026-11-10`. No real token.

| Case | Runs | Rules | State now |
| --- | --- | --- | --- |
| ch12-add | add with `/releases` (3 builds), then `list` | R-CH12 R-CH13 | red (`unknown command 'roc channel'`) |
| ch12-add-forms | `owner/repo`; `.../` ; `.../releases/tag/<tag>` | R-CH12 | red |
| ch12-add-errors | 7 exit 2 runs: bad name, reserved, `git-` name, URL only, other host, http, issues page | R-CH12 R-CH3 | red |
| ch12-add-offline | `--offline`: exit 15 | R-CH12 | red |
| ch12-add-prefix | no prefix; 2 prefixes; `--tag-prefix` picks one | R-CH12 R-CH4 | red |
| ch12-add-conflict | installed id of another source: exit 19; same source: written | R-CH12 R-CH13 | red |
| ch13-add-copy | `add reify --offline` copies from the project; `list` | R-CH13 | red |
| ch13-list | 2 user tables; no config.toml | R-CH13 | red |
| ch13-rm | `roc list`; `rm reify`; `list`; `roc list` | R-CH13 | red |
| ch12-add-exists | same source (also with `--tag-prefix`): exit 0; another source: exit 2 | R-CH12 Q617-1 | red |
| ch12-add-order | conflict + `--offline` = 19; existing table before conflict = 2; URL = 2; cached list + `--offline` = 15 | R-CH12 Q617-2 | red |
| ch12-add-given | `--tag-prefix Bad_` (no request); `--tag-prefix zzz-` (after the request) | R-CH12 Q617-3 | red |
| ch12-add-noasset | draft, prerelease, 1 day old Windows build as newest; `nightly = false` | R-CH12 Q617-4 | red |
| ch13-add-copy-errors | no project; no table; equal table (exit 0); different table (19) | R-CH13 Q617 | red |
| ch13-rm-errors | unknown, built-in, project-only: exit 2 | R-CH13 Q617 | red |
| ch13-list-project | project-only table; `--json`; unequal tables (19) | R-CH13 Q617 | red |
| ch12-add-json | `--json` of add, add (exists), rm | R-OUT2 | red |
| ch12-usage | 7 usage stops | R-OUT2 | red |
| ch12-add-page1 | page 1 has `Link: next`; page 2 would change the prefix and the newest build; only page 1 is requested | R-CH12 | red (code requests page 2; 2.json, 2.meta in the tree) |
| ch12-flag | `rm ... --tag-prefix`, `list --tag-prefix`: exit 2 `flag '--tag-prefix' is not for 'roc channel rm'` | R-OUT2 | red (the commands run) |
| ch12-add-nobuild | all tags draft or prerelease: exit 2 (Q618); a draft of another prefix is ignored | R-CH12 Q618 | red |

The cases ch12-add, ch12-add-forms, ch12-add-prefix, ch12-add-conflict, ch13-add-copy, ch13-list and ch13-rm keep their runs; `list` runs now print the Q617 format and the project search lines.

All 18 cases fail with `unknown command 'roc channel'` (stderr) and the missing stdout. The ch13-rm run also shows that today `roc list` skips a `reify-*` dir (R-CH17 "unknown form"), so its rows are red for that reason too.

### Run results (TMPDIR in `.tmp/tmp`, capped scope `MemoryMax=16G`; nothing died at the cap)

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` | Does not compile: 30 "does not exist" (22 new names) and 4 "type not determined" that follow from them. No other error. |
| `tests/commands/run.sh channels/ch12 channels/ch13` | 18 failed (the new cases; 58 `unknown command 'roc channel'` lines), 1 passed (ch13-default-by-id, slice 240). |

### Round 3 (after the code, 2026-11-11)

| Change | Detail |
| --- | --- |
| calls.log of 10 cases | Taken from the real run (`UPDATE=1`, then read): D1 (`env_all` and one `read_files config` after the start; `add <URL>`: `env_all`, `clock`, `platform`, `read_files`), D2 (`--json` runs have no `tty` and no first-run read), D3 (the project scan lists each dir up to the stop dir, then reads all talon.toml in one `read_files`). Checked against the design: no request before the local checks (Q617-2), one read under the lock. The lines `list_dirs <ancestor of the work dir>` were removed (the runner filters them). stdout, stderr and tree.diff did not change. |
| ch12-add-page1 | calls.log is the real flow with the request for page 2 removed; tree.diff is made by `tree_diff` with `1.meta` (`next <URL>`) and with no `2.json`/`2.meta`. |
| ch12-flag | The option text is the existing form. The calls are the start only. |
| ch12-add-nobuild, L0 `no_build_text` | Design Q618: `github.com/<source> has no build on page 1 (drafts and prereleases do not count)`, kind usage (exit 2), nothing written. |

## How the expected files were made (read this for the review)

| File | Source |
| --- | --- |
| `expect/tree.diff` | Made by `tree_diff` (tests/lib.sh) over a copy of the start tree and the expected final tree (config.toml text from the rules of L0 tests 8 and 9; the cache file is the fake answer). No hunk was edited by hand. |
| `expect/stdout`, `stderr` | Written from the design examples and the TW24 texts below. Exit-0 cases have an empty stderr. The exit N runs are in cases whose other runs have stderr text only for those runs. |
| `expect/calls.log` | Guessed (see below). No real run of the new commands was possible. |

### Guessed calls.log lines (the code agent may send a dispute, TW18)

| Part | Guess |
| --- | --- |
| Start of every channel command | `args`, `env_all`, `tty`, `read_files config.toml`. |
| `add` with a URL, after the checks of the name and the URL | `env_all`, `clock`, `platform`, `read_files config.toml`, `list_dirs toolchains` (the installed ids), then one `read_files <id>/.talon.json` for each id of that name (Q2), then the list read as in `roc install` (`list_dirs index/..`, `programs gh`, `http_get`, `write_atomic 1.json 1.meta`). No `db_query` and no `db_write` (nothing is installed). |
| Write of config.toml | `lock config nowait: held`, `read_files config`, `write_atomic config`, `unlock config` (one read; `roc default` has two). |
| `--offline` | stops after `list_dirs toolchains`. |
| `add <name>` (copy) | `env_all`, `cwd`, `list_dirs $PROJECT`, `list_dirs $WORK`, `read_files $PROJECT/talon.toml`, then the write. |
| `rm` | the start, then the write. |
| `list` | the start, then the project search (`env_all`, `cwd`, `list_dirs $PROJECT`, `list_dirs $WORK`, and `read_files $PROJECT/talon.toml` when it exists) because it shows project tables (Q617-7). |
| `add <name>` (copy), existing table (exit 0 or 19) | the start, `env_all`, `cwd`, `list_dirs <dir>`, `read_files <dir>/talon.toml`. |
| Exit 2 checks before the request (name, URL, existing table, bad prefix, usage) | the start only. |
| `--offline` with the conflict check | `list_dirs toolchains` and the `.talon.json` of the ids of that name, then the stop. |
| `roc list` | the lines of `roc/ls1-list` (run 3 of the first run: `args env_all tty read_files env_all read_files list_dirs read_files <ids>`), with the user build in the id list. |

## TW24 text proposals (all output text that the design does not give)

The design examples (CLI 6.8 section 3) are fixed and marked (D). Everything else is for the human review. Conventions used: real paths as `would remove $HOME/...` (not `~`); usage texts as `roc default`, `roc remove`, `roc update`; list with a header and gaps of 2 as `roc list`; `--json` envelope and snake_case keys as `roc list --json`.

| Where | Text |
| --- | --- |
| `add` stdout (D, except the path) | `read 3 releases of github.com/<source>` (`release` for 1); `added channel <name> to $HOME/.config/talon/config.toml:`; the table with 2 spaces of indent; `newest: <id> (has <target>). Install: tln roc install <name>`. The example shows `~/...`; the tests use the real path (other commands print `$HOME/...`). |
| Newest build with no asset | `newest: <id> (no asset for <target>)`, no `Install:` part. |
| `add <name> <URL>`, same source | `channel <name> is already added (github.com/<source>)`, exit 0 (also used by `add <name>` with an equal table). |
| `add <name> <URL>`, another source (exit 2) | `channel <name> is added with the source <old>, not <new>`; hint `To replace it, run: tln roc channel rm <name>` |
| `add <name>` (copy) stdout | `copied channel <name> from <path of talon.toml> to $HOME/.config/talon/config.toml:` and the table. |
| `add <name>`, no project (exit 2) | `no talon.toml found. Give the URL: tln roc channel add <name> <URL>` |
| `add <name>`, no table in talon.toml (exit 2) | `<path of talon.toml> has no [channels.<name>] table. Give the URL: tln roc channel add <name> <URL>` |
| `add <name>`, different table (exit 19) | The text of the R-CH10 equality check: `<talon.toml>:<line>: channels.<name> is not equal to channels.<name> in <config.toml>:<line>` (exists). |
| `rm` stdout | `removed channel <name> from $HOME/.config/talon/config.toml` |
| `rm`, unknown or project-only (exit 2) | `no channel <name> in $HOME/.config/talon/config.toml` |
| `rm nightly` (exit 2) | `nightly is a built-in channel and cannot be removed` |
| `list` stdout | A header `NAME  SHAPE  SOURCE  FROM`, then `nightly ... built-in`, the tables of config.toml (`config.toml`), then the project-only tables (`talon.toml (not added)`). Each gap is the widest cell and 2 spaces; the last column has no padding. The design example has no header and 3 spaces in the last gap (Q5 of the first round: the example is read as a drawing). |
| Exit 2, bad name | `<name> is not a channel name. A name is a-z, 0-9 and -, starts with a letter, has 2 to 24 characters and does not end with -.` |
| Exit 2, reserved | `<name> is a reserved channel name` |
| Exit 2, no name (D) | `give the channel name: tln roc channel add <name> <URL>` |
| Exit 2, URL | `<url> is not a channel source`; hint `known channel sources: github.com/<owner>/<repo>` (D) |
| Exit 2, prefix | None (D): `no release tag ends with <date>-<sha>. Pass --tag-prefix.` Many: `release tags have 2 prefixes: fork-a-, fork-b-. Pass --tag-prefix.` |
| Exit 2, `--tag-prefix` | Bad form: `<p> is not a tag prefix. A tag prefix has 1 to 40 characters of a-z, 0-9, . _ and -, and ends with -.` No tag: `no release tag on page 1 of github.com/<source> starts with <p> and ends with <date>-<sha>` |
| Exit 15 | `--offline is set and tln roc channel add needs the release list of github.com/<source>` |
| Exit 19, conflict | `channel <name>: installed builds record the source <recorded>, not <new>`; hint `Remove them with tln roc remove <id>, or use another name.` |
| Exit 2, no build (Q618, approved) | `github.com/<source> has no build on page 1 (drafts and prereleases do not count)` |
| Option not for the command (exit 2) | `flag '--tag-prefix' is not for 'roc channel rm'` (and `'roc channel list'`), the form of `roc use` |
| Usage (exit 2) | `tln roc channel needs a word: add, rm or list`; `tln roc channel frob is not a command: use add, rm or list`; `tln roc channel add needs a channel name: tln roc channel add <name> [<URL>]`; `tln roc channel add takes a name and a URL, got 3 operands`; `tln roc channel rm needs one channel name`; `tln roc channel rm takes one channel name, got 2`; `tln roc channel list takes no operand, got 1` |
| `roc list`, user build | KIND is the channel name. The SOURCE column (shown when a row has a source) holds the source, and `<source> (channel removed)` when the channel has no table in config.toml. |
| `--json` of `list` | `data: {"channels":[{"name","shape","source","tag_prefix","origin":"built-in"\|"config"\|"project","added":bool}]}`; command `roc channel list`. |
| `--json` of `add` | `data: {"name","shape","source","tag_prefix","path","changed","read","target","newest":{"id","has_asset"}}`; for "already added": `changed` false and `read`, `target`, `newest` null. Command `roc channel add`. |
| `--json` of `rm` | `data: {"name","path","changed"}`. Command `roc channel rm`. |
| File format | The table is appended at the end of config.toml, after a blank line (none for an empty file). `rm` removes the header, its keys and the blank lines before it. |

## Remaining guesses (not design questions)

| # | Guess | Where |
| --- | --- | --- |
| G1 | `read N releases` counts all entries of page 1 (drafts and prereleases too). | ch12-add-noasset, ch12-add-json |
| G2 | `rm stable` (reserved, no table) is `Missing` (exit 2 with the "no channel" text), not `Builtin`. | L0 `rm_check` |
| G3 | "Same source" compares the text of `source` exactly (case kept). | L0 `exists_check` |
| G4 | An installed id with no recorded source is no conflict. | L0 `source_conflict` |
| G5 | `list` and `add <name>` search the project from the current dir; a project table is shown as project-only only when config.toml has no table of that name. | ch13-list-project |
| G6 | The calls.log lines of the cases that were not run by the code yet (page1, flag, nobuild) are the real flow of `ch12-add` and the usage start. | the 3 round 3 cases |
