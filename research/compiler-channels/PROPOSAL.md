# Compiler channels: design proposal (revision 4)

Date: 2026-11-09. Status: proposal. The user answered section 5 on 2026-11-09. Read-only design agent; no code or design file changed.

User decisions so far: `nightly` and `stable` are built-in channels that use the same mechanism as user channels. Nothing is planned for `stable` beyond "a new built-in channel" (its shape is decided when roc publishes releases). `reify` is not built in: the user adds it with `tln roc channel add <name> <URL>`. The user always gives the name; Talon never derives a name from the URL (user decision 2026-11-09).

## 1 Facts found

### 1.1 The two GitHub sources (gh, read-only, 2026-11-09)

| Item | roc-lang/nightlies | Karakatiza666/roc-reify-nightlies |
| --- | --- | --- |
| Releases | about 1 per day | 1 (`nightly-reify-2026-11-03-1708298`) |
| Tag form | `nightly-<YYYY-MM-DD>-<sha7>` (older tags have an English month name) | `nightly-reify-<YYYY-MM-DD>-<sha7>` |
| Compiler asset | `roc_nightly-<target>-<date>-<sha>.tar.gz` (`.zip` on Windows) | `roc_nightly-reify-<target>-<date>-<sha>.tar.gz` (`.zip` on Windows) |
| Targets | linux_arm64, linux_x86_64, macos_apple_silicon, macos_x86_64, windows_x86_64 | the same 5 |
| Archive | one top dir with `roc`, `LICENSE`, `legal_details` | the same (`--strip-components=1` works) |
| `digest` | `sha256:<hex>` on each asset | the same (checked: linux_x86_64 matches) |
| prerelease / draft | false | false |
| Version in the binary | the tag | `nightly-reify-2026-11-03-1708298` |
| Extra | a daily `nightly-<date>-<sha>-safe` release; its `roc version` gives the plain tag | release notes name the base nightly |

The sources differ only in the repo and in the word `reify-`. For both, the asset prefix is `"roc_" + <tag prefix>`.

### 1.2 roc facts (roc source, reify branch)

| Fact | Source |
| --- | --- |
| roc reads 2 version forms in a `roc:` pin: a nightly tag and a release `X.Y.Z[-pre]`. | `src/base/roc_version.zig` `parse` |
| `roc: "nightly-reify-..."` does not parse: "Invalid Roc Version", severity `runtime_error`, so `roc check` fails. | `roc_version.zig` `parseNightly`; `src/parse/Parser.zig:1741-1747`; `src/parse/AST.zig:460,518` |
| A fork compiler gives no mismatch warning for an official pin (its own version does not parse). | `roc_version.zig` `isMismatch` |

### 1.3 Stable releases in the design today, and the mapping

The design separates nightlies from future compiler "releases" (it does not use the word "stable"):

| Place | Text |
| --- | --- |
| Design line 12 | "When the compiler has releases, the nightly can be a release (the `nightly` switch)." |
| Resolution R-NS1, R-NS2 | Nightlies and releases are one domain in date order; "Talon knows no source of compiler releases yet". |
| CLI R-CV1 | "A design change names the source when roc publishes its first release." |
| Resolution R-NS7; CLI R-SL3 | A semver range matches releases only. |
| Resolution R-C15 | The age name of a release is `roc-lang/roc`. |
| Design Q199, Q431; Registry R-AP57, R-AP74 row 6 | Registry rows are nightlies only in P2; release rows can come later. |

Mapping: the future releases of R-NS1, R-NS2, R-NS7, R-CV1 and R-C15 become the built-in channel `stable`. Its shape is decided when roc publishes them. No other rule for `stable`.

### 1.4 Code and rules that assume the one nightly source

| Place | Assumption |
| --- | --- |
| CLI R-CV1, R-CV2, R-CV7, R-CV8 | Source `roc-lang/nightlies`, asset prefix `roc_nightly-<target>-`. |
| cli/lib/Nightlies.roc (58, 78, 229-244, 347, 439) | `parts` reads the literal `nightly-`; asset prefix, list URL, download URL fixed. |
| `Pin.is_nightly` | Reads the nightly form only. |
| cli/lib/TalonRemove.roc:357 | `kind_of` uses `starts_with("nightly-")`. |
| cli/lib/Age.roc:56 | The age name is fixed. |
| CLI R-CV5, R-CV6 | Digest `github-digest` or `registry`; first-seen key (tag, target). |
| CLI R-LY1, R-GC5 | Dir kinds: nightly tag, release, `git-`, `link-`, `copy-`, `zig-`. Unknown form: not listed, not removed (Q607). |
| Registry R-RE4, R-SG3, R-IK4, R-MX1, R-MX15; bot/lib/BotFlow.roc:160 | Toolchain rows, leaves, Worker tag check, bot sweep: `roc-lang/nightlies` only. |
| CLI R-R10, R-R4 | Today a fork comes only from `--git` (`git-<sha8>`), never a pin, local results. |

## 2 The design

| Id | Rule |
| --- | --- |
| R-CH1 | A channel is a table: `name`, `shape`, `source`, and the parameters of its shape. Built-in tables (`nightly`, and later `stable`, 1.3) go through the same code as user tables. A user cannot change a built-in table. Its name is reserved. |
| R-CH2 | The built-in `nightly` table: shape `github-release`, source `roc-lang/nightlies`, tag-prefix `nightly-`. |
| R-CH3 | Names: `[a-z][a-z0-9-]*`, 2 to 24 characters, no `-` at the end. Reserved: `nightly`, `stable`, `git`, `link`, `copy`, `zig`, `debug`, `local`, `compat`. |
| R-CH4 | Shape `github-release`. Parameters: `source` (`owner/repo`) and `tag-prefix`. A build is a non-draft, non-prerelease release (R-DI3) whose tag is `<tag-prefix><date>-<sha>` (the form `parts` reads). Asset: R-CV2 with prefix `"roc_" + <tag-prefix> + <target> + "-"`. sha256: the GitHub `digest` (R-CV3 `direct`). URL: `https://github.com/<source>/releases/download/<tag>/<asset>`. |
| R-CH5 | Ids. A `github-release` id is `<name>-<date>-<sha>`, so a `nightly` id is the tag text, as today. Talon reads an id from the right (sha, day, month, year); the rest is the name. A user-channel id never parses as a nightly or release id. The id is the `toolchains/` dir name and the value in `roc +<id>`, `ROC_TOOLCHAIN`, `default-roc`, `[toolchain] roc`. R-SC10 to R-SC13 unchanged. |
| R-CH6 | Header pins. Talon writes an id into a `roc:` header only when roc reads that form (1.2). R-PH8, R-SO10, R-SO11 stay. A project on a user channel pins in its root `talon.toml` with `[toolchain] roc = "=<id>"` (in git, so it reaches other machines and CI). |
| R-CH7 | Ranges. `*`, semver ranges, and `=<id>` / `>=<id>` with a nightly id or a release keep their meaning (R-NS7). `=<id>` and `>=<id>` with a user-channel id are over that channel only. No other range form matches a user channel. |
| R-CH8 | Refs. `<name>@<selector>` selects in one channel (`reify@latest`, `reify@-1`, `nightly@latest`). A bare `<name>` means `<name>@latest`. A selector with no name works as today, or in the user channel of the selected compiler (R-SL7). |
| R-CH9 | Each user channel is ordered alone by R-NS1. A user-channel build counts as a nightly for the switch. `min-release-age` uses the release `published_at` (R-C7). The R-C15 name is the channel `source`. |
| R-CH10 | Declaration. A user channel is a `[channels.<name>]` table with all its parameters and no defaults, in `config.toml` (this machine) and in the root `talon.toml` (the project needs it). A project needs no table for a built-in channel. A name in both files: the tables must be equal, else exit 19. A reserved name: exit 19. Unknown `shape` word: exit 19 with the R-TF8 hint. Unknown key: warning. |
| R-CH11 | Trust. A built-in channel needs no consent. Talon lists or downloads from a user channel only when `config.toml` has its table. When only the project has it: exit 19 before any request, `talon.toml uses compiler channel reify (github.com/Karakatiza666/roc-reify-nightlies). Run: tln roc channel add reify`. `--yes` and `TALON_AUTO_INSTALL` do not give this consent. |
| R-CH12 | `tln roc channel add <name> <URL> [--tag-prefix <p>]`. The name is required and comes only from the user. A name that R-CH3 rejects: exit 2. Forms: `https://github.com/<owner>/<repo>` (optionally `/releases`, `/releases/tag/<tag>`, `/`) and `<owner>/<repo>`. Other forms: exit 2, `known channel sources: github.com/<owner>/<repo>`. The host gives the shape. Talon reads page 1 of the release list (`--offline`: exit 15). Tags that end with `<date>-<sha>` give the tag-prefix (the text before the date); 2 or more prefixes, or none: exit 2, listed, pass `--tag-prefix`. Checks R-CH3; exit 19 when installed ids of that name record another source. Writes the table to `config.toml`, prints it, the newest build, and whether it has an asset for this host. |
| R-CH13 | `tln roc channel add <name>` (no URL) copies the table from the project `talon.toml`, no network (the CI line). `tln roc channel rm <name>` changes no installed build. `tln roc channel list` shows built-in and user tables. `.talon.json` and the R-CV6 first-seen row record `channel` and `source`. An installed build stays selectable by its id after its channel is removed; `tln roc list` marks it `(channel removed)`. |
| R-CH14 | `tln roc use <id or ref>` on a user channel writes `[toolchain] roc = "=<id>"` and the `[channels.<name>]` table into the root `talon.toml`, and removes the header `roc:` entries. R-U2 to R-U6 apply. Back to `nightly`: header pin, and removes the `roc` key and an unused `[channels]` table. |
| R-CH15 | `tln upgrade roc` moves a user-channel pin to the newest build of that channel. `tln roc update [<name>]` installs the newest build of `<name>`; no name: the channel of `default-roc`, else as today. R-RU2, R-RR1 move the default only inside that channel. `tln init`, `tln setup`, R-SO14 never pick a user channel. |
| R-CH16 | A user-channel build is local only, as `git-*` (R-R4): listed with `direct` also when a registry is set, no toolchain rows, no leaves, no bot, not shared (R-IK4). Probe results stay in `compat.db` under its id. |
| R-CH17 | Older `tln` (Q607): `[channels]` is an unknown key (warning); `=reify-...` is exit 19 with the R-TF8 hint; a `reify-*` dir is an unknown form (R-GC5). No format bump. GC treats a user-channel build as a nightly. |

## 3 Examples

```text
$ tln roc channel add reify https://github.com/Karakatiza666/roc-reify-nightlies/releases
read 1 release of github.com/Karakatiza666/roc-reify-nightlies
added channel reify to ~/.config/talon/config.toml:
  [channels.reify]
  shape = "github-release"
  source = "Karakatiza666/roc-reify-nightlies"
  tag-prefix = "nightly-reify-"
newest: reify-2026-11-03-1708298 (has linux_x86_64). Install: tln roc install reify
$ tln roc channel add mine https://github.com/someone/roc-builds   # tags v1, v2
error: no release tag ends with <date>-<sha>. Pass --tag-prefix.   # exit 2
$ tln roc channel add https://github.com/someone/roc-builds
error: give the channel name: tln roc channel add <name> <URL>   # exit 2
$ tln roc channel list
nightly  github-release  roc-lang/nightlies                  built-in
reify    github-release  Karakatiza666/roc-reify-nightlies   config.toml
$ tln roc install reify && tln roc default reify-2026-11-03-1708298
$ tln roc use reify@latest     # writes [toolchain] roc = "=reify-..." and [channels.reify], removes header roc:
$ git clone .../app && cd app && roc check
error: talon.toml uses compiler channel reify (github.com/Karakatiza666/roc-reify-nightlies).
Run: tln roc channel add reify                                     # exit 19
```

```toml
# talon.toml of the project (no table is needed for nightly)
[toolchain]
roc = "=reify-2026-11-03-1708298"
[channels.reify]
shape = "github-release"
source = "Karakatiza666/roc-reify-nightlies"
tag-prefix = "nightly-reify-"
```

| Tag | Channel | Id |
| --- | --- | --- |
| `nightly-2026-11-09-9e85de7` | nightly | `nightly-2026-11-09-9e85de7` |
| `nightly-reify-2026-11-03-1708298` | reify | `reify-2026-11-03-1708298` |
| `nightly-2026-11-09-9e85de7-safe` | none | skipped |

Output texts are proposals (TW24).

## 4 Rejected options

| Option | Why rejected |
| --- | --- |
| Id = the tag text | Another fork can use the official tag form and collide; `starts_with("nightly-")` would count it as official. |
| Name derived from the URL or the tag | User decision: the user always names the channel. |
| Id has the owner | Too long; R-CH12 already stops a name collision. |
| Fork id in the header | roc fails with "Invalid Roc Version". |
| Defaults for table keys | `add` writes all keys: one form to read, no default rules. |
| A user may change a built-in table (mirror) | Marginal gain; trust and registry become unclear. |
| Facts of the base nightly for a fork | Wrong when the fork changes the compiler. |
| Registry rows and the bot for forks in P2 | Too large; needs Worker trust for any repo. |
| Silent use of a channel from a project | A cloned repo could run binaries from an unknown repository. |

## 5 Questions for the user (answered 2026-11-09: all (a))

Also decided: the channel name is a required argument of `add`; no name comes from the URL or the tags.

| # | Question | Options | Answer |
| --- | --- | --- | --- |
| 1 | Trust of a project-only channel | (a) exit 19 and `channel add <name>`; (b) a TTY prompt, `--yes` counts | (a) |
| 2 | Does `add <URL>` need the network? | (a) yes, it reads the tags; `add <name>` from the project needs none; (b) never, flags only | (a) |
| 3 | Do `*` and `>=nightly-...` include user channels? | (a) no (R-CH7); (b) yes | (a) |
| 4 | The official `-safe` releases | (a) defer; (b) a `tag-suffix` parameter now | (a) |
| 5 | A `PATH` roc that reports `nightly-reify-...` | (a) a local build (R-SO11); (b) map it to the channel id | (a) |

Later shapes (names only): the `stable` shape (1.3), `git-build`, `forgejo-release` / `gitlab-release`, `url-index`.

## 6 Work items

Ask TalonRegistry for the next free G-C, Q and slice ids first.

| Area | Slice | Rules | Size | Depends on |
| --- | --- | --- | --- | --- |
| Design | New CLI section "Channels" (R-CH1 to R-CH17), Q-rows, the 1.3 mapping line in R-CV1, edits to R-CV2/3/5/6/7, R-LY1, R-GC5, R-SL6/7, R-NS7, R-C15, R-U1, R-RU1/2, R-RR1, R-R4, `[channels]` in the config and talon.toml examples | all | M | answers |
| Design | Registry: one line in R-IK4, R-MX1, R-AP57 that user channels are out of scope | R-CH16 | S | design text |
| CLI | Channel tables: built-in `nightly`, parse `[channels]`, names, equality, R-TF8 | R-CH1 to R-CH3, R-CH10, R-CH17 | M | design |
| CLI | `github-release` shape over a table (generalize `Nightlies.roc`); id build and parse; `Pin.is_nightly`, `kind_of`, `Age.compiler_name` by channel | R-CH4, R-CH5, R-CH9 | M | tables |
| CLI | Install from a user channel: `direct` always, channel and source in `.talon.json` and R-CV6, trust check | R-CH11, R-CH13, R-CH16 | M | shape |
| CLI | Selection: per-channel ranges and refs | R-CH6 to R-CH8 | M | shape |
| CLI | `tln roc channel add/rm/list` | R-CH12, R-CH13 | M | tables |
| CLI | `roc use`, `upgrade roc`, `roc update [<name>]`, default moves, `roc list` marks | R-CH14, R-CH15 | L | selection |
| CLI | GC and remove for channel dirs; no share | R-CH16, R-CH17 | S | ids |
| Registry | None in P2 | R-CH16 | n/a | n/a |
