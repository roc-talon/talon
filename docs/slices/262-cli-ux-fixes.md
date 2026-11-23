# 262 CLI usability fixes (help, did-you-mean, repeated flags, pin texts, the `roc update` hint)

Phase: P2. Status: decided (the user approved all recommended answers Q262-1 to Q262-9 and all texts of section 6 on 2026-11-23, Design Q642). 262a: red tests written (test agent, 2026-11-23, section 11). 262b: red tests written (test agent, 2026-11-23, section 12).
Design ids (pending, the manager writes them): Design Q642, G-C272.
Source: the usability review `research/cli-ux-review/REVIEW.md` (findings) and `research/cli-ux-review/COMMANDS.md` (inventory). The user chose the fixes on 2026-11-23 (section 1).

Two sub-slices (TW19, section 10):

| Sub-slice | Findings | Layer of the code |
| --- | --- | --- |
| 262a | UX2, UX7, UX14, UX15, UX16 (help part) | The parse and help layer: `Help.roc`, `Args.roc`, `Run.roc`, the word check of `ChannelCmd.roc` |
| 262b | UX1, UX3, UX16 (message part) | The command texts: the `install` note, `Vars` held note, `outdated` cell, `roc update` hint, `XCmd`, `ToolGit`, `ToolManage` |

262a and 262b touch no common file. They can run in either order.

## 1. Scope (the decision of the user, 2026-11-23)

| Id | The user chose | Change type | Sub-slice |
| --- | --- | --- | --- |
| UX1 | `tln add json@1.2.3` and `tln update json@1.2.3` keep writing `=1.2.3` (no change of meaning). The command prints that it pinned exactly. `tln update`, `tln upgrade` and `tln outdated` show "pinned" for an entry that the pin holds back. | Code, new texts | 262b |
| UX2 | Help text only: `tln --help` names `tln tool update talon` as the update of tln itself, and says that `tln upgrade` changes the project. No new command. | Code (text) | 262a |
| UX3 | `tln roc update` in a project prints a project hint: does the project pin hold the project on its old compiler, and the command `tln upgrade roc` that moves the project. | Code, new text | 262b |
| UX7 | `tln <cmd> --help`, `tln <cmd> -h` and `tln help <cmd>` print the usage of that command (synopsis, arguments, flags). `tln --help` also names `run`, `path` and `roc channel`. | Code, design (new rule) | 262a |
| UX14 | The same flag 2 times on one command line: exit 2 with a clear message, for every flag. A flag that the design repeats on purpose: a question, not a break. | Code, design (new rule) | 262a |
| UX15 | An unknown command gives a "did you mean" hint with the closest command. `roc channel` also takes `remove` and `ls` (aliases of `rm` and `list`). | Code, design (small) | 262a |
| UX16 | The forms that answer "not built yet" (`tln x --git`, `--path`, `--resolve`, `tln tool install --resolve`, `tln tool rebuild talon`) are not in the help, and their message names the working alternative (`tool rebuild talon`: the text of R-S6). | Code (text) | 262a (help), 262b (messages) |

Not in scope: UX4 (`roc remove` guards) and all other findings of the review. `tln update roc` (a bad name, not an unknown command) keeps its text.

## 2. Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CM1 to R-CM25 (CLI 1) | The synopsis of each command. The source of the per-command usage lines (section 6.3). |
| R-CM19, R-CM20 | A long form and its other forms are one command at every level. Help and error text print the long form. 262a adds the `roc channel` level. |
| R-FL1 to R-FL6, R-FL12 | Global flags, and the command flags table. The per-command help lists the flags that `Args.allows` gives for the command. |
| R-FL7, R-FL13, R-FL14 | The resolve flags, `--frozen`, `--git`, `--resolve`. Unchanged; the help shows them where they are allowed. |
| R-AU9 | `--ignore <item>` "can occur more than once". A list flag (Q262-2). |
| R-PB10 detail (2), Design Q588 | "A `--target` given 2 times is one build", not exit 2. A list flag (Q262-2). |
| R-AD25, R-AD27, R-AD28 | `@1.2.3` is an anchor `=1.2.3`; `--no-pin` starts there with no pin. Unchanged. 262b adds a note. |
| R-UP1, R-UP10, R-UP11, R-UP5, R-VA5, R-SP23 (Resolution) | An anchor holds its variable unless named; `upgrade <name>` frees it and writes `=<new>`. Unchanged. 262b changes the held line. |
| R-CM6 | `tln outdated` table. 262b adds the pinned mark. |
| R-RU1 to R-RU3, R-CH15 | `tln roc update` moves only the global default; a pinned project keeps its pin; an unpinned project uses the new nightly at once. 262b adds the hint (new rule proposal R-RU5). |
| R-PD14, R-PD16, R-PD9 | `roc update` uses no project and records none. Q262-5. |
| R-SO2 to R-SO6 (Resolution 13) | The selection order that decides the hint of an unpinned project (Q262-6). |
| R-S6 | `tln tool rebuild talon` is not supported: exit 2, names `tln tool update talon --from-source`. |
| R-T1, R-X1 | `--resolve` of `tool install` and `x`. Not built: out of the help (UX16). |
| R-OUT1 to R-OUT5, R-J1 to R-J4 | New texts and `data` members are proposals (section 6). |
| R-E2, R-E4 | A usage failure is exit 2, `tln: error[usage]: <message>`. |

New rule ids proposed for the design (section 9, the TalonRegistry session confirms them): R-CM26 (per-command help, `-h`), R-CM27 (did you mean), R-FL15 (repeated flag), R-RU5 (the project hint of `roc update`).

## 3. Scope: where the code is today

| Fact | Where | Consequence |
| --- | --- | --- |
| `Help.route` gives `Help` when `--help` is anywhere before `--` or `help` is the first word. One text for all (`Help.usage`). | `Help.roc:19-32`, `Run.roc` `tln!` | Route must give the command words. |
| `-h` is no flag: `tln -h` gives `flag '-h' needs a command`, `tln install -h` gives `flag '-h' is not for 'install'`. | `Args.finish` | `-h` goes to `Help.route`, before the parse. |
| `Help.usage` has no line for `path`, `run`, the `roc` sub words, `--file`, `-h`, the self-update. | `Help.roc:36-69` | Text change (L3 `help/q7-help` expect changes). |
| An unknown word: `unknown command '<words>'`, no hint. `top_level`, `sub_words`, `long_form` hold all command words. | `Args.word_step`, `Args.unknown` | The suggestion is a pure function on these lists. |
| `roc channel` reads its word from `args.operands`: `add`, `rm`, `list`; other words: `tln roc channel <w> is not a command: use add, rm or list`. The envelope `command` is the fixed long form (`roc channel rm`). | `ChannelCmd.run!` | Add `remove`, `ls`; texts in long form (Q262-8). |
| Repeated flags: `apply` keeps the last `--registry` and `--file`; other flags go to `options`, and readers take the first (`find_first`: `Opts.value_of`, `Run.option_value`). | `Args.apply`, `Opts.roc:90`, `Run.roc` | One check in `Args.finish`. |
| L2 and L3 lines that repeat a flag today: only `probe --smoke ... --target a --target b` (cases `probe/*smoke*`). No other case repeats a flag. | grep of `tests/` | Q262-2. |
| `tln add X@1.2.3` writes `X = "=1.2.3"` and prints `<path>: X = "=1.2.3"`. No other line. `Report.Outcome.notes` are the `note:` lines and go to `data.notes[]`. `data.pinned` is the `roc:` id (a different fact). | `Report.roc`, `InstallFlow.roc` | The new note goes in `notes`; no new `data` member. |
| `upgrade` with no names prints `<alias>: anchor, held` (or `patched, held`) for a held anchor. `update` prints nothing for an anchor, named or not. | `Vars.scoped_one` (`Upgrade`, `Update` arms) | Text change and a new note in `update`. |
| `outdated` shows a row only for an entry that is behind. An anchor row has `wanted` = `current` (cases `od1-table` row `util`). The JSON item has the optional member `successor` (Design Q632). | `Lags.roc`, `OutdatedFlow.roc`, `Outdated` | One cell suffix and one optional member. Do not add a member to `Outdated.Row` (it breaks `OutdatedTest` literals, TW18; same as slice 252). |
| `roc update` reads no project. Its text: `installed <id>` or `<id> is the newest`, then the default line (`ManageUpdate.update_report`). `data`: `id`, `path`, `installed`, `previous`, `changed`. | `RocManage.update_flow!`, `ManageUpdate.roc` | A project read is new: new `Fx` calls in 8 L2 cases (section 7). |
| Not-built messages: `tln x <flag> is not built yet` (`XCmd.read` row 1), `'<sel>' in '<op>' is a git ref: a git ref needs --git (not built yet)` (`XCmd` row 5), `tln tool install --resolve is not built yet` (`ToolGit` row 1, `ToolInstall` row 1), `tln tool rebuild talon is not built yet` (`ToolManage.operand_ref`). `tool install owner/app@<sha>` is a git source already (`ToolGit`). | `XCmd.roc`, `ToolGit.roc`, `ToolInstall.roc`, `ToolManage.roc` | Text changes only. |
| `Run.dispatch!` has a branch for every command of `top_level` and `sub_words`. The last `else` (`is not built yet`, kind `Internal`) cannot be reached. | `Run.roc:198` | No change. |
| Other agents edit `ToolFlow`, `Init`, `FullName`, `PickIndex`, `Clock`, `ToolBuild`, `XFlow` now (slice 260). | git status | 262 changes none of these files. `XCmd` is read by `XFlow`; only its texts change. |

## 4. Behaviors

| # | Behavior | Rules | Sub |
| --- | --- | --- | --- |
| B1 | `tln --help`, `tln -h`, `tln help`: the general text (section 6.2), stdout, exit 0. | R-CM26 | a |
| B2 | `tln <cmd> --help`, `tln <cmd> -h`, `tln help <cmd>`, for each command key (a top-level command, or `roc`/`tool`/`cache`/`share` with a sub word): the text of that command (section 6.3), stdout, exit 0. An alias gives the text of its long form (`tln help rm` = `tln help remove`). Operands and other flags on the line are ignored, also bad flags (as today for `--help`). `--json` does not change it (help is text). Words after a bare `--` are not read (R-CM12). | R-CM26, R-CM19 | a |
| B3 | `tln roc --help` (a group with no sub word): the group text (sub commands). `tln share --help`: the `share` text, which lists its words. | R-CM26 | a |
| B4 | The command words of B2 are found as `Args` finds them: skip each flag and the value of a flag that takes one (`takes_value`). | R-CM26 | a |
| B5 | An unknown command word (top level, sub word, `roc channel` word): exit 2, and the message ends with the suggestion of Q262-1 when there is one. | R-CM27 | a |
| B6 | `tln roc channel remove <name>` = `rm`; `tln roc channel ls` = `list`. | R-CM19 | a |
| B7 | A flag given 2 or more times before a bare `--` (the same flag text, with or without `=value`): exit 2, `flag '<flag>' is given more than once`. Exceptions: Q262-2. The check comes after the command check and the "not for" check (Q262-9). `--help` wins over it (B2 comes first). | R-FL15 | a |
| B8 | The general text and the per-command texts name no not-built form: no `--git`, `--path`, `--resolve` for `x`; no `--resolve` for `tool install`; `tool rebuild` does not name `talon`. | UX16 | a |
| B9 | `tln add X@1.2.3`, `tln add --platform X@1.2.3`, `tln update X@1.2.3` (each line that writes or plans a `talon.toml` value `=<version>`): one `note:` line per such key (section 6.1 row 1). Also with `--dry-run`. Not with `--no-pin`. | R-AD25, R-AD28, R-UP11 | b |
| B10 | `tln update` with no names, and `tln update X` that names an anchor without a selector: one held line per anchor that the run holds (row 2). `tln upgrade` with no names: the held line replaces `anchor, held` (row 3). `patched, held` and the `fixed:` line do not change. | R-UP1, R-UP10, Q262-3, Q262-4 | b |
| B11 | `tln outdated`: the `wanted` cell of an anchor row ends with ` (pinned)`; the JSON item has `pinned` (row 4). | R-CM6 | b |
| B12 | `tln roc update` in a project: the hint of Q262-6 (rows 5 to 7). No project, or a project that does not read: no hint, no stop. | R-RU5, R-RU3 | b |
| B13 | The not-built messages name the working alternative (rows 9 to 13). Exit codes do not change (2). | R-S6, R-T1, R-X1 | b |

## 5. Questions (TW17): decided 2026-11-23, all recommended answers (Design Q642)

| Id | Question | Options | Recommendation and reason |
| --- | --- | --- | --- |
| Q262-1 | The "did you mean" rule (UX15: "pick a rule"). | (a) Edit distance only: optimal string alignment distance (a swap of 2 letters counts 1) from the typed word to each long form and each other form of that level; the best one when its distance is at most 1 for a word of 4 letters or less, at most 2 for a longer word; a tie: the first in the order of the general text; the hint prints the long form. (b) (a), and first a small fixed table of words from other tools: `uninstall`, `delete` -> `remove`; `tool upgrade`, `roc upgrade` -> `update`; `cache clear`, `cache purge` -> `cache clean`; `cache prune` -> `cache gc`; `self` -> `tool update talon`. (c) No hint at level 2. | (b). Reason: with (a) alone `uninstall` is distance 2 from `install` and suggests the opposite command. The table is 7 words and is in the review. `self` gives the UX2 command with no new command. |
| Q262-2 | UX14 says "every flag". `--ignore` (R-AU9: "can occur more than once") and `--target` (R-PB10 detail 2, Design Q588: a repeat is one build, "no exit 2") repeat on purpose. | (a) These 2 list flags stay repeatable; every other flag is exit 2. (b) Exit 2 for all, and Q588 changes. | (a). Reason: the design repeats them on purpose, and the bot repeats `--target` (Q588). The user said to ask, not to break. |
| Q262-3 | "Shows pinned for an entry that the pin holds back" in `update` and `upgrade`. | (a) The held line for every anchor that the run holds (as `upgrade` prints `anchor, held` today), with no check for a newer release. (b) Only when the index has a newer release that the command would take with no pin. | (a). Reason: (b) needs a release list of each held anchor group; R-DI1 lists no held group in `upgrade`, so (b) adds requests. In `outdated` the row exists only when the entry is behind, so its mark is (b) with no new read. |
| Q262-4 | `tln update json`, with json an anchor and no selector: today it moves nothing and says nothing. | (a) Print the held line (named or not). (b) Only for no names. | (a). Reason: the user named it and sees no change; this is the main case of UX1. |
| Q262-5 | How `roc update` finds "the project" (R-PD16: it uses no project). | (a) The walk of R-PD1 to R-PD6 from the current directory (no `--file`: R-PD16 rejects it). Any failure of the walk (no project file, 2 member files, a header that does not read, a bad `talon.toml`): no hint, no warning, exit code unchanged. No record in `projects.json` (R-PD9 does not apply: the command still uses no project). (b) As (a), and a failure is a warning. (c) Record the file. | (a). Reason: a hint must not stop or change an install; R-PD16 stays true. |
| Q262-6 | The cases of the hint. "Uses" is the selection of Resolution 13 for the project file. | (a) Pin (R-SO3) not the new id: line A. Pin = the new id: no line. No pin, no `ROC_TOOLCHAIN`, no `[toolchain] roc`, no `.roc-version`, and the default is now the new id (`Set`, `Moved`, `Same`): line B. Any other case (a priority 2, 4 or 5 source decides, or the default stays: `Stay`, `NoDefault`): no line. In a workspace: the pin of the current member; no current member: no line. (b) Only the pinned case (line A). (c) Run the full selection of the proxy and print the compiler that the project uses in each case. | (a). Reason: the user asked for the pinned case and the R-RU3 case; (a) needs only the header pin, 1 env var and the 2 files that the walk reads. (c) is more code for rare cases. |
| Q262-7 | `tln help frob`, `tln frob --help`, `tln roc frob -h` (no such command). | (a) Exit 2, the unknown-command text with the hint (B5), as without `--help`. (b) The general text, exit 0 (today). | (a). Reason: one answer for an unknown word; `tln help frob` with exit 0 hides the typo. |
| Q262-8 | The `--json` envelope `command` of `roc channel` with an alias, and the long form. | (a) `remove` and `list` are the long forms (R-CM19); human texts print them; the envelope `command` is the words as typed, as for every other command (`Args.typed`, the design example `"command": "add"`). (b) The envelope keeps a fixed form (`roc channel rm`) whatever was typed. | (a). Reason: one rule for all envelopes; a line typed with `rm` keeps `"roc channel rm"`, so the existing cases do not change. |
| Q262-9 | Which failure wins when a line has a repeated flag and another parse failure. | (a) The order of `Args.finish`: missing subcommand, then a flag "not for" the command, then the first repeated flag in line order. A value failure (`needs a value`) stops the walk first, as today. (b) The repeat first. | (a). Reason: "not for" is the larger fault; the order of the line decides the rest. |

## 6. Output (TW24, approved 2026-11-23)

### 6.1 New and changed lines (262b, and the parse texts of 262a)

| # | Case | Human text | `--json` |
| --- | --- | --- | --- |
| 1 | B9: a key written or planned as `=<v>` (`add`, `add --platform`, `update X@<v>`) | `note: json is pinned to =1.2.3: tln update keeps it there, and tln upgrade json moves it. To start at 1.2.3 with no pin, add --no-pin.` (on the stream of the other `note:` lines: stdout, stderr with `--json`; hidden by `--quiet`, R-FL4) | `data.notes[]` gets the text without `note: ` (the existing member; no new member) |
| 2 | B10, `update` held anchor | `json: pinned to =1.2.3, held (tln upgrade json moves it)` (where `upgrade` prints its held line today) | `data.notes[]` when the command puts the held line there today; else no member |
| 3 | B10, `upgrade` held anchor | `parser: pinned to =1.0.0, held (tln upgrade parser moves it)` (was `parser: anchor, held`). `patched, held` unchanged. | as today |
| 4 | B11, `outdated` anchor row | `  util     1.0.0    1.0.0 (pinned)   1.2.0   ...` (the `wanted` cell gets ` (pinned)`; columns widen) | optional member `"pinned": "=1.0.0"` (the range text) after `new_series`, only on an anchor row, as `successor` (Design Q632) |
| 5 | B12 line A: pin is not the new id | `note: the project <path of the project file> pins <pin id>, so it stays on that compiler. To move it with a check, run: tln upgrade roc` (stdout, after the default line) | new member `project` after `changed`: `{"file":"<path>","pin":"<pin id>","uses":"pin"}` |
| 6 | B12 line B: no pin, the default selects the new id | `note: the project <path> has no roc: pin, so it uses <new id> now, with no check. To check it and pin it, run: tln roc use <new id>` | `{"file":"<path>","pin":null,"uses":"new"}` |
| 7 | B12, other cases (pin = new id; another source) | no line | `{"file":"<path>","pin":<id or null>,"uses":"pin"}` or `"uses":"other"`; no project: `"project":null` (the catalog writes `null`, section 3) |
| 8 | B7 repeated flag | `tln: error[usage]: flag '--as' is given more than once` | envelope, kind `usage`, as each parse failure |
| 9 | B5 unknown command, with a hint | `tln: error[usage]: unknown command 'isntall' (did you mean 'tln install'?)`; level 2: `unknown command 'roc instal' (did you mean 'tln roc install'?)`; table word: `unknown command 'uninstall' (did you mean 'tln remove'?)`, `unknown command 'self' (did you mean 'tln tool update talon'?)`. No hint: the text of today. | envelope; no `details` member (the hint is text, R-OUT4 covers `data`) |
| 10 | B6 channel words | `tln roc channel needs a word: add, remove or list`; `tln roc channel <w> is not a command: use add, remove or list` and the hint of row 9 when there is one: `... (did you mean 'tln roc channel remove'?)` | as today |
| 11 | `tln x --git`, `tln x --path` | `tln x --git is not built yet. To build an app from a git ref, run: tln tool install --git <owner/app@ref> (with --path <dir> for an app in a subdirectory)` (the same text with `--path`) | envelope |
| 12 | `tln x --resolve`, `tln tool install --resolve` | `tln x --resolve is not built yet. tln x builds the app with the packages that its header names.` (`tln tool install --resolve ...` the same with `tln tool install`) | envelope |
| 13 | `tln x owner/app@<sha>` | `'<sha>' in '<operand>' is a git ref, and tln x does not build git refs yet. Run: tln tool install <operand>` | envelope |
| 14 | `tln tool rebuild talon` | `tln tool rebuild talon is not supported. To build tln from its source, run: tln tool update talon --from-source` (R-S6) | envelope |

### 6.2 The general text (`tln --help`, `tln -h`, `tln help`)

```text
Usage: tln [flags] <command> [words]
       tln help <command>    Show the usage of one command (also: tln <command> --help)

Commands:
  init      Make a new app or package
  install   Add packages, or fetch the closure of the header (also: add, i)
  remove    Remove a package (also: rm)
  update    Move the packages of this project within the ranges (also: up)
  upgrade   Move the packages and the compiler of this project to the newest releases
  outdated  Show the current, wanted and latest versions
  why       Show why a package is in the closure
  probe     Probe an entry on the selected compiler
  list      Show the closure (also: ls)
  patch     Edit a copy of a dependency
  verify    Resolve and probe, and write nothing
  path      Print the directory of a header entry
  run       Run a script of talon.toml
  x         Build a Roc app and run it once
  publish   Register a release
  audit     Report yanked and changed releases
  roc       Manage compilers: install, link, use, list, remove, default, update, channel
  tool      Manage global tools: install, list, update, rebuild, remove
  cache     Manage the cache: gc, clean, list, dir
  setup     Install the roc proxy and the PATH line
  yank      Yank a release
  move      Set the successor of a package name
  share     Show or change the sharing of probe results: on, off, login, logout, forget
  help      Show this text, or the usage of one command

To update tln itself, run: tln tool update talon
(tln upgrade changes the project, not tln.)

Flags for every command:
  --json  --yes  --offline  --quiet  --registry <url|direct>  --help (-h)  --version
  --file <path>  The project file, for a command that uses a project
```

### 6.3 Per-command text (sample of 3, and the rule for the rest)

Rule for each command key (pure: `Help.command(key) -> Try(Str, [Unknown])`):

| Part | Rule |
| --- | --- |
| `Usage:` lines | The synopsis lines of the key (table 6.4), each `tln <long form> <operands> [flags]` (`[flags]` only when the Flags block is not empty; for `x` and `run` it stands before `[-- <args>]`, because the words after `--` are not flags). The second and later lines indent under the first. |
| `Also:` line | Only for a key with other forms (R-CM19): `Also: tln add, tln i`. |
| Description | One line (table 6.4), then an empty line. |
| `Arguments:` block | One line for each placeholder of the synopsis, from table 6.5, in the order of first use. Left out when the synopsis has none. |
| `Flags:` block | Each flag `f` of the fixed order below with `Args.allows(key, f)`, minus the global flags and minus the not-built pairs (`x`: `--git`, `--path`, `--resolve`; `tool install`: `--resolve`). The text of each flag: table 6.6 (a per-command text wins). The flag column is as wide as the longest flag of the block plus 2 spaces. Left out when empty. |
| Last line | `Flags for every command: --json --yes --offline --quiet --registry <url\|direct> --help` (`x`: without `--json`, R-FL1). |
| Group (`roc`, `tool`, `cache`) | `Usage: tln roc <command> [words]`, the description, a `Commands:` block (each sub word, its description, `(also: ...)`), the line `Run tln roc <command> --help for the usage of one command.`, the last line. |

Fixed flag order (the order of `Args.allows`): `--file --frozen --no-probe --no-check --snapshot --strategy --dry-run --slots --as --no-pin --platform --ci --git --path --from-source -i --diff --tree --range --share --smoke --target --all --force --copy --rename-keys --allow-moves --probe-downloads --allow-downloads --roc --allow-unchecked --resolve --remove-tools --keep-all --replace-roc --no-modify-path --tag-prefix --reason --to --undo --ignore --tool --each --keep-going`.

Sample 1: `tln install --help` (also `tln add -h`, `tln help i`)

```text
Usage: tln install [<name>[@<sel>]...] [flags]
       tln install --platform <name>[@<sel>] [flags]
       tln install --tool <owner/app>[@<sel>] [flags]
Also: tln add, tln i

Add packages, or fetch the closure of the header.

Arguments:
  <name>[@<sel>]       A package: an alias, owner/repo, host/path or a short name, with an optional selector (@1.2.3, @^1.2, @latest)
  <owner/app>[@<sel>]  A Roc app on GitHub, with an optional selector

Flags:
  --file <path>              The project file
  --frozen                   Fetch the closure of the header, and change nothing (no names only)
  --no-probe                 Run no probe: use only known facts
  --no-check                 Do not check the result
  --snapshot <log:N|time>    Hide the releases after a registry log size or a time
  --strategy highest|lowest  Choose the highest or the lowest versions
  --dry-run                  Show the changes, and write nothing
  --slots <n>                Run at most <n> probes at the same time
  --as <alias>               The alias of the new entry (one name only)
  --no-pin                   With an exact version: start there, with no pin
  --platform                 The name is the platform of the app
  --rename-keys              Rename the stale keys of talon.toml with no prompt
  --allow-moves              Move held entries with no prompt
  --allow-downloads          Download the compilers that the command needs with no prompt
  --tool                     Add a project tool to [tools] of talon.toml

Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help
```

Sample 2: `tln roc update -h` (also `tln roc up --help`)

```text
Usage: tln roc update [<channel>]
Also: tln roc up

Install the newest compiler release, and move the global default to it.

Arguments:
  <channel>  The name of a user channel (tln roc channel list). With none: the nightlies

Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help
```

Sample 3: `tln roc --help` (also `tln help roc`)

```text
Usage: tln roc <command> [words]

Manage compilers.

Commands:
  install  Install a compiler: a nightly, a release or a git ref (also: add, i)
  link     Use a local roc build under a name
  use      Check the project on a compiler and write the roc: pin of the header
  list     Show the installed compilers (also: ls)
  remove   Remove one compiler (also: rm)
  default  Set the global default compiler
  update   Install the newest compiler and move the global default (also: up)
  channel  Add, remove or list compiler channels

Run tln roc <command> --help for the usage of one command.
Flags for every command: --json --yes --offline --quiet --registry <url|direct> --help
```

### 6.4 Synopsis and description of each key (source: COMMANDS.md section 1, R-CM table)

| Key | Usage lines (operands) | Description |
| --- | --- | --- |
| `init` | `[app\|package]` | Make a new app or package |
| `install` | sample 1 | Add packages, or fetch the closure of the header |
| `remove` | `<name>...`; `--tool <key>...` | Remove packages, or project tools |
| `update` | `[<name>[@<sel>]...]`; `-i`; `--tool [<key>...]` | Move the packages of this project within the ranges |
| `upgrade` | `[<name>...] [roc]`; `--tool [<key>...]` | Move the packages and the compiler of this project to the newest releases |
| `outdated` | none | Show the current, wanted and latest versions |
| `why` | `<name>` | Show why a package is in the closure |
| `list` | none | Show the closure |
| `patch` | `<alias>` | Edit a copy of a dependency |
| `verify` | none | Resolve and probe, and write nothing |
| `probe` | `[<alias>\|<bundle file>]`; `--smoke <alias>\|<release URL> [--target <target>]...` | Probe an entry on the selected compiler |
| `publish` | none | Register a release (in GitHub Actions) |
| `audit` | `[--ignore <item>]...` | Report yanked and changed releases |
| `path` | `<alias>` | Print the directory of a header entry |
| `run` | `[<script>] [-- <args>]`; `--each [<script>] [-- <args>]` | Run a script of talon.toml |
| `x` | `<owner/app>[@<sel>] [-- <args>]`; `<key> [-- <args>]` | Build a Roc app and run it once |
| `yank` | `<tag>` | Yank a release (in a workflow_dispatch job) |
| `move` | `<old-name>` | Set the successor of a package name (in a workflow_dispatch job) |
| `share` | `[on\|off\|login\|logout\|forget]` | Show or change the sharing of probe results |
| `share on`, `off`, `login`, `logout`, `forget` | none | Turn sharing on; Turn sharing off; Log in with GitHub; Log out; Remove the results of this machine (or account) |
| `roc install` | `<id>\|<ref>`; `--git <owner/repo@ref>\|@<ref>` | Install a compiler: a nightly, a release or a git ref |
| `roc link` | `<name> <path>` | Use a local roc build under a name |
| `roc use` | `<ref>` | Check the project on a compiler and write the roc: pin of the header |
| `roc list` | none | Show the installed compilers |
| `roc remove` | `<id>` | Remove one compiler |
| `roc default` | `<ref>`; `--git <owner/repo@ref>` | Set the global default compiler |
| `roc update` | sample 2 | Install the newest compiler release, and move the global default to it |
| `roc channel` | `add <name> [<URL>]`; `remove <name>`; `list` | Add, remove or list compiler channels |
| `tool install` | `<owner/app>[@<sel>]`; `--git <owner/app@ref>` | Build a Roc app and put it on PATH |
| `tool list` | none | Show the global tools |
| `tool update` | `[<tool>]`; `talon` | Move tools to their newest releases (talon: update tln itself) |
| `tool rebuild` | `[<tool>]` | Build tools again on the default compiler |
| `tool remove` | `<tool>`; `talon` | Remove a tool (talon: remove tln) |
| `cache gc` | none | Remove what no known project uses |
| `cache clean` | none | Remove cache files on request |
| `cache list` | none | Show the cache sizes |
| `cache dir` | none | Print the cache directory |
| `setup` | none | Install the roc proxy and the PATH line |

### 6.5 Placeholders (Arguments block)

| Placeholder | Text |
| --- | --- |
| `<name>[@<sel>]`, `<name>` | A package: an alias, owner/repo, host/path or a short name, with an optional selector (@1.2.3, @^1.2, @latest) |
| `<alias>` | An alias of the header |
| `<key>` | A key of [tools] in talon.toml |
| `<owner/app>[@<sel>]` | A Roc app on GitHub, with an optional selector |
| `<bundle file>`, `<release URL>` | A bundle file; a release URL https://.../<hash>.tar.zst |
| `<script>`, `<args>` | A key of [scripts] in talon.toml; Words that tln passes on as they are |
| `<owner/app@ref>` | A Roc app on GitHub at a git ref (a branch, a tag or a commit) |
| `<id>`, `<ref>` | A compiler id (tln roc list); a compiler: an id, nightly, latest, @-1 or a git ref |
| `<owner/repo@ref>`, `@<ref>` | A git ref of a repository (@<ref> is roc-lang/roc) |
| `<name> <path>` (roc link), `<channel>`, `<URL>` | A name and the path of a roc binary; a user channel; the GitHub repository of a channel |
| `<tool>`, `<tag>`, `<old-name>`, `<item>` | A tool name; a release tag of this repository; a full name owner/repo; owner/repo@version:reason |
| `[app\|package]`, `[roc]` | The template (default: app); the word roc frees the compiler |

### 6.6 Flag texts (Flags block)

| Flag | Text (per-command text after `;`) |
| --- | --- |
| `--file <path>` | The project file |
| `--frozen` | Fetch the closure of the header, and change nothing (no names only) |
| `--no-probe`, `--no-check` | Run no probe: use only known facts; Do not check the result |
| `--snapshot <log:N\|time>` | Hide the releases after a registry log size or a time |
| `--strategy highest\|lowest` | Choose the highest or the lowest versions |
| `--dry-run` | Show the changes, and write nothing; `cache gc`, `cache clean`, `tool remove`: Show what would be removed, and remove nothing |
| `--slots <n>` | Run at most <n> probes at the same time |
| `--as <alias>` | The alias of the new entry (one name only); `tool install`: `--as <name>` The binary name |
| `--no-pin` | With an exact version: start there, with no pin |
| `--platform` | The name is the platform of the app; `init`: `--platform <owner/repo>[@<version>]` The platform of the template |
| `--ci github\|none` | The CI file to make |
| `--git` | The operand is a git ref |
| `--path <dir>` | The directory of the app in the repository |
| `--from-source` | Build tln from its source (tln tool update talon) |
| `-i` | Pick the packages from a list |
| `--diff`, `--tree` | Print the patch against the original; Show the closure as a tree |
| `--range`, `--share`, `--smoke`, `--target <target>` | Find the compiler range; Send the facts to the registry once; Run the smoke build of a platform; A target of the smoke build (more than once for more targets) |
| `--all` | Also remove packages and build caches |
| `--force` | `remove`: Remove also when an app module imports it; `roc link`: Replace a copy with the same name |
| `--copy` | Copy the binary, not a link |
| `--rename-keys`, `--allow-moves`, `--probe-downloads`, `--allow-downloads` | Rename the stale keys of talon.toml with no prompt; Move held entries with no prompt; Download compilers for the search with no prompt; Download the compilers that the command needs with no prompt |
| `--roc pinned\|installed`, `--allow-unchecked` | Which compiler builds the app; Use a cached build that was not checked online |
| `--remove-tools`, `--keep-all` | Remove the tools too; Keep everything (only tln goes) |
| `--replace-roc`, `--no-modify-path` | Replace a roc that tln did not write; Do not add the PATH line |
| `--tag-prefix <p>` | The tag prefix of the channel releases |
| `--reason <text>`, `--to <new-name>`, `--undo` | The reason of the yank; The successor name; Remove the yank (or the successor) |
| `--ignore <item>` | Ignore one finding (more than once for more) |
| `--tool` | The operands are project tools of [tools] |
| `--each`, `--keep-going` | Run in each workspace directory; With --each, go on after a failure |

## 7. Tests (written in phase 2, after the answers)

| Layer | Case | Checks | Rules | Red state |
| --- | --- | --- | --- | --- |
| L0 (262a) | `tests/unit/HelpTest.roc` (new, driver `l0-5.roc` with `ArgsTest`): `Help.route` on `--help`, `-h`, `help`, `help rm`, `roc up -h`, `--json install --help`, `--registry x install -h`, `x app -- -h` (not help), `help frob` | B1 to B4, Q262-7 | R-CM26 | fails: no command words in the route |
| L0 (262a) | same file: `Help.command` exact text for the 3 samples; for each key: the Flags block = `allows` minus globals minus not-built pairs; no `--resolve` in `x` and `tool install`; `Help.usage` names `run`, `path`, `channel`, `tln tool update talon` | B2, B3, B8 | R-CM26, R-FL12 | fails: no `Help.command` (stub) |
| L0 (262a) | `ArgsTest.roc`: repeated flags (a bool, a value flag, `--registry`, `--file=a --file b`, a global before and after the command), `--target`/`--ignore` twice are allowed, a repeat after `--` is not counted, the order of Q262-9 | B7, Q262-2, Q262-9 | R-FL15 | fails: today the parse succeeds |
| L0 (262a) | `ArgsTest.roc`: the suggestion function (`isntall`, `instal`, `lst`, `y` with no hint, `uninstall`, `roc instal`, `cache clear`, `self`, a tie, no close word) | B5, Q262-1 | R-CM27 | fails: stub |
| L2 (262a) | `help/hp1-command-help` (new group): the samples via `Run.tln!`, `tln help rm` = `tln remove --help`, `tln help frob` exit 2, `tln install --bogus --help` exit 0 | B1 to B5 | R-CM26 | fails |
| L2 (262a) | `help/hp2-repeated`: `add a --as x --as y` exit 2, `--json` envelope, `probe --smoke ... --target a --target a` unchanged | B7 | R-FL15 | fails: exit 0 / other text |
| L2 (262a) | `help/hp3-did-you-mean`: `isntall`, `roc instal`, `uninstall`, `roc channel remov` | B5, B6 | R-CM27 | fails |
| L2 (262a) | `channels/ch12-usage` (expect changes: `add, remove or list`); `channels/ch13-*` one new run each with `remove` and `ls` | B6 | R-CM19, R-CH13 | fails |
| L3 (262a) | `help/q7-help`, `help/q7-no-command` expect: the new general text; one new line `tln -h` | B1 | R-CM26 | fails |
| L0 (262b) | `VarsTest.roc`: the `anchor, held` expects get the new text; a new expect for `Update` named and unnamed anchors | B10 | R-UP1, Q262-3, Q262-4 | fails |
| L0 (262b) | new pure functions with stubs: the anchor note of `install` (row 1), the outdated pinned list (not a member of `Outdated.Row`), `ManageUpdate.project_note` (rows 5 to 7, each case of Q262-6) | B9, B11, B12 | R-AD28, R-CM6, R-RU5 | fails: stubs |
| L2 (262b) | Existing expects that change: the 17 files with a `talon.toml: <k> = "=..."` line (for example `registry/rg2-example-add-short`, `resolve/rs-update-scope`, `moves/hm1-*`, `update/au7-direct-held-move`, `upgrade/ug1-flow`); `upgrade/ug1-flow`, `ug2-lag`, `ug4-hint-order` (held line); `outdated/od1-table` (util row); the 8 `roc update` cases (new `Fx` calls of the walk, `"project"` member): `roc/up1-update`, `roc/up2-exclude`, `channels/ch15-update*`, `registry/ix6-roc-update-offline`, `registry/rg9-toolchains-down`, `share/sh62-no-send-roc-update`; `tool/tg2-gitstops`, `tool/tr2-rebuildstops` | B9 to B13 | as above | fail |
| L2 (262b) | `update/up3-pinned`: `update json` (anchor) prints the held line, writes nothing; `add json@1.2.3 --dry-run` prints the note; `--no-pin` prints none | B9, B10 | R-AD28, Q262-4 | fails |
| L2 (262b) | `roc/up3-project-hint`: runs for line A, pin = new id, line B, `ROC_TOOLCHAIN` set (no line), no project, a bad `talon.toml` (no line, exit 0), `--json` | B12 | R-RU5, Q262-5, Q262-6 | fails |
| L3 (262b) | `exit/ex1-parser-basic-cli` expect (`anchor, held` line); `add/ad1-add-entries`, `add/ad2-platform-json` (note) | B9, B10 | | fails |

At each close: read the new expect files by hand (UPDATE=1 can bake a failure in), and run `scripts/test.sh l0 l2 l3`. Revert check: only the tricky behaviors (about 6): the repeat exceptions, the help flag filter, the tie rule, the held line for a named anchor, the Q262-6 case split, the null `project`.

## 8. Out of scope

| Item | Why |
| --- | --- |
| UX4 and every other finding of the review | The user's decision |
| A `self` command, building `x --git` or `--resolve` | UX2 and UX16 are text only |
| `tln update roc` text | Not an unknown command (bad name); not chosen |
| Completion scripts (R-CM18) from the help table | Not asked |
| Project tools with an exact `ref` in `outdated` | UX1 names header entries |

## 9. Design text changes (for TalonRegistry, Design Q642, after the answers)

| Spot | Old | New |
| --- | --- | --- |
| `DESIGN-CLI.md` section 1, after R-CM25 | none | R-CM26: `tln help`, `--help` and `-h` print the general text. `tln help <command>`, `tln <command> --help` and `tln <command> -h` print the usage of that command: the synopsis, the arguments, the flags that R-FL12 allows for it, on stdout, exit 0. An unknown command is exit 2 (R-CM27). Forms that are not built are not shown. The texts are a proposal (R-OUT2). |
| same, new | none | R-CM27: an unknown command word is exit 2. The message names the closest command by the rule of Q262-1 (the table and the distance). |
| R-CM19 table | 4 rows | Add: at the `roc channel` level, `remove` (`rm`) and `list` (`ls`). |
| R-CH13 | `tln roc channel rm <name>` ... `rm <name>` | `tln roc channel remove <name>` (also `rm`) ... |
| Global flags table (R-FL1 to R-FL6) | no `--help` row | A row: `--help`, `-h`: R-CM26. |
| After R-FL14 | none | R-FL15: a flag given more than once on one line stops with exit 2, except `--ignore` (R-AU9) and `--target` (R-PB10, Q588). The order of Q262-9. |
| R-AD28 | ends `... stops with exit code 2.` | Add: the command prints a note that the entry is pinned, and how `update`, `upgrade <name>` and `--no-pin` act (text: CLI 3, a proposal). |
| CLI 1 example (`tln add parser@2.0.0 ...`, TW16) | no note | Add the note line of row 1 after the `talon.toml` line. |
| `DESIGN-RESOLUTION.md` section 10 example | `~ parser: lukewilliamboswell/roc-parser 2.0.0 (anchor, held)` | `parser: pinned to =2.0.0, held (tln upgrade parser moves it)` |
| R-UP1 | `An anchor (=) holds its variable unless the user names it.` | Add: `update` and `upgrade` print one held line for each anchor that the run holds (Q262-3, Q262-4). |
| R-CM6 and the output catalog | no pin mark | The `wanted` cell of an anchor row ends with ` (pinned)`; the JSON item has the optional member `pinned` (the range text). |
| 6.6, after R-RU4 | none | R-RU5: in a project (the walk of R-PD1 to R-PD6, no record, a failure gives no hint), `roc update` prints the hint of Q262-6. `data.project`. R-PD16 stays. |
| Output catalog | no `roc update` row | `roc update`: `id`, `path`, `installed`, `previous`, `changed`, `project` (`null` or `{file, pin, uses}`). |
| `DESIGN.md` | none | `Q642 \| G-C272: CLI usability fixes (slice 262, Q262-1 to Q262-9)? \| Decided by the user, <date>: ...` |

## 10. Size and plan rows

| Sub-slice | Estimate of product code | Notes |
| --- | --- | --- |
| 262a | About 300 lines: the help tables (about 160, mostly data), the route and render (about 60), the suggestion (about 45), the repeat check (about 15), the channel words (about 10) | Under TW19 |
| 262b | About 170 lines: the anchor note (30), the held line (20), the outdated mark (30), the project hint with its read (80), the 5 texts (10) | Under TW19 |

Plan rows (for `docs/slices/PLAN-P2-CLI.md`, the manager adds them):

| 262a | Help per command, did you mean, repeated flags | Tests for R-CM26, R-CM27, R-FL15, R-CM19 (`roc channel`). `Help.route` with command words, `Help.command`, the general text, the suggestion, the repeat check in `Args.finish`. | R-CM19, R-CM26, R-CM27, R-FL12, R-FL15, R-AU9, R-PB10 | G-C272 (Design Q642) | none / none | 300 | Sonnet |
| 262b | Pinned texts and the `roc update` project hint | Tests for R-AD28, R-UP1, R-CM6, R-RU5, R-S6. The anchor note, the held line, the outdated mark, `ManageUpdate.project_note`, the not-built texts. | R-AD25, R-AD28, R-UP1, R-UP10, R-UP11, R-CM6, R-RU3, R-RU5, R-S6, R-T1, R-X1 | G-C272 (Design Q642) | none / none | 170 | Sonnet |

## 11. Sub-slice 262a: tests (test agent, 2026-11-23)

The expected help texts come from one writer, `research/slice-262-help/texts.py` (the rule of 6.3), so the L0 and L2 files agree. Three small changes against the approved samples, made when the rule was applied (for the review): the flag column of sample 1 is 2 spaces narrower (the rule: the longest flag plus 2); `[flags]` of `x` and `run` stands before `[-- <args>]`; `<args>` has the text `Words that tln passes on as they are`, and `<owner/app@ref>` (tool install) has its own text. The one product change is a stub: `Help.topic` and `Help.command` in `cli/lib/Help.roc` (`crash "todo"`).

API that the tests fix for the code agent:

| Function | Type | Meaning |
| --- | --- | --- |
| `Help.topic` | `List(Str) -> [NoHelp, General, Key(Str), Unknown(Str)]` | What help a line asks for (B1 to B4, Q262-7). `Unknown` has the words as typed (`roc frob`). `Run.tln!` uses it in place of `Help.route` for help. |
| `Help.command` | `Str -> Try(Str, [Unknown])` | The text of a long-form key (6.3, 6.4); an alias or another text is `Err(Unknown)`. |
| `Help.usage` | `Str` | The general text of 6.2 (changed). |
| `Args.parse` | as today | The did-you-mean hint (R-CM27) and the repeat check (R-FL15) are in its failure message. The suggestion and the repeat helpers are for the code agent to choose. "The first repeated flag" is the flag whose second use comes first in the line. |

| Layer | File or case | Checks | Rules | Red state |
| --- | --- | --- | --- | --- |
| L0 | `tests/unit/HelpTest.roc` (new, driver `l0-5.roc`), 8 expects: `Help.topic` (28 rows), the general text, the 3 samples, aliases have no text, the Flags block of each of 42 keys = the flags that `Args.parse` takes, in the fixed order, minus globals and not-built forms; `Usage: tln <key>` first and the global line last (`x` without `--json`); no not-built form in `x`, `tool install`, `tool rebuild`; the group texts | R-CM26, R-CM19, R-FL12, R-FL1, UX2, UX16, Q262-7 | 8 fail (7 crash on the stubs, the general text differs) |
| L0 | `tests/unit/ArgsTest.roc`, 4 new expects: the hints (20 rows), the repeats (11 rows), the order of Q262-9 and the envelope flag, the list flags `--ignore`, `--target` and the words after `--` stay accepted | R-CM27, R-FL15, Q262-1, Q262-2, Q262-9, R-AU9, R-PB10 | 3 fail; the last one passes (a guard) |
| L2 | `help/hp1-command-help` (new area `help`): 18 runs: `--help`, `-h`, `help`, `install --help`, `add -h`, `help i`, `--json install json --as j --help`, `install --bogus --help`, `roc up -h`, `help roc update`, `roc --help`, `x --help`, `tool install -h`, `tool rebuild --help`, `help frob`, `frob --help`, `help instal`, `roc frob -h`; the only Fx call of each run is `args` | R-CM26, R-CM27, R-CM19, R-FL1, UX16 | fails: one general text for all, exit 0 for unknown words |
| L2 | `help/hp2-repeated-flag`: 6 runs (`--as` 2 times, `--json` 2 times with the envelope, `--registry` before and after, `--file=` and `--file`, the second use first, "not for" wins) | R-FL15, Q262-9 | fails: the commands run (no project) |
| L2 | `help/hp3-did-you-mean`: 7 runs (`isntall`, `roc instal`, `uninstall`, `self update`, `cache prune`, `frobnicate`, `--json isntall`) | R-CM27, Q262-1 | fails: no hint |
| L2 | `channels/ch13-rm-alias` (new, the world of `ch13-rm`): `roc channel remove reify --json` (envelope `roc channel remove`), `roc channel ls`, `roc channel ls --json` (envelope `roc channel ls`) | R-CM19, R-CH13, Q262-8 | fails: `is not a command` |
| L2 | `channels/ch12-usage` (texts `add, remove or list`, `tln roc channel remove needs ...`, one new run `roc channel remov reify` with the hint), `ch12-flag` (`not for 'roc channel remove'`), `ch12-add-exists`, `ch12-add-order` (`run: tln roc channel remove <name>`) | R-CM19, R-CM27, Q262-8 | fail: the old texts |
| L3 | `help/q7-help` (the general text, `tln -h` gives the same text, `tln help roc up`), `help/q7-no-command` (the general text on stderr) | R-CM26, UX2, UX7 | fail: the old text |

Red results (2026-11-23, capped runs): `roc test tests/unit/l0-5.roc`: 137 passed, 11 failed (the 11 new expects above; every old expect passes). L2 filter `help/ channels/ch12 channels/ch13-rm`: 13 passed, 8 failed (the 8 cases above). L3 filter `help/`: 1 passed (`q7-version`), 2 failed. `scripts/test.sh check fmt`: pass.

Not in 262a (262b): the not-built messages (`tool/tg2-gitstops`, `tool/tr2-rebuildstops`, `XCmdTest`, `ToolManageTest`), the pinned texts, the `roc update` hint.

The ChannelCmd usage envelope (`"command":"roc channel"` for a bad word) is not changed by these tests.

## 12. Sub-slice 262b: tests (test agent, 2026-11-23)

Readings of the approved answers, made when the tests were written (for the review; none changes a decided fact):

| # | Reading | Source |
| --- | --- | --- |
| R1 | The anchor note (B9) is for `install`, `add` and `update` only. `upgrade <name>` that rewrites an anchor (`=1.0.0` to `=2.0.0`, R-UP5) prints no note: `upgrade` takes no `--no-pin` (R-FL12), and the user wrote that anchor before. | B9, R-FL12 |
| R2 | The note line comes right after the block of `talon.toml` lines, one line for each exact pin of the block, in its order, on the stream of those lines (stdout; stderr with `--json`). `--quiet` hides it (R-FL4). In `data.notes[]` it is the last item. | B9, 6.1 row 1 |
| R3 | The held line (B10) is printed for an anchor that holds the entry at its header value (the range `=<v>` and the header version `<v>`). An anchor that the header does not satisfy moves the entry to the pin in this run (R-SP20), so it holds nothing: no line (cases `target/tg1-ladder`, `tg3-constraint`). The `owner/repo@=<v>` form is an anchor (R-VA5). | Q262-3 |
| R4 | The held line is not in `data.notes[]`, as the `anchor, held` line of `upgrade` was not. It is printed where that line was: first, before the resolve, so also before an exit 10. | 6.1 rows 2 and 3 |
| R5 | `roc update`: the walk and the hint run on every run that ends with exit 0, also when nothing was installed (`<id> is the newest`). The walk calls come at the end of the run, after the edit of `config.toml`. Their order (cwd, `list_dirs` from the start dir up, `read_files` of `talon.toml`, then of `main.roc`; a `talon.toml` that does not parse stops the walk) is a guess from the walk of `roc use`: the code agent may dispute it. | Q262-5, R-PD1 to R-PD6 |
| R6 | `data.project` is always present in `roc update --json` (`null` with no project), as the catalog writes `null` for a value that does not exist. | 6.1 row 7 |
| R7 | The rows of `ToolInstall.read` for `--git`, `--path` and a sha selector without `--git` (`ToolTest`) cannot be reached from the command (`ToolGit` takes those lines first). Their texts do not change. | UX16 |

Stubs (the only product change): `Report.anchor_notes` (`cli/lib/Report.roc`) and `ManageUpdate.project_hint` (`cli/lib/ManageUpdate.roc`), `crash "todo"`.

| Layer | File or case | Checks | Rules | Red state |
| --- | --- | --- | --- | --- |
| L0 | `ReportTest.roc` (l0-5): `Report.anchor_notes`, 6 rows | B9, R1, R2 | R-AD28, R-UP11 | fails (stub) |
| L0 | `RocUpdateHintTest.roc` (new, l0-9): `ManageUpdate.project_hint`, 9 rows (each case of Q262-6) | B12 | R-RU5, R-RU3, R-SO2 to R-SO6 | fails (stub) |
| L0 | `VarsTest.roc` (l0-2): the `upgrade` held text, and a new expect of 7 rows (update with no names, named, a selector, another name, an anchor off its header value, the `@=` form in update and upgrade) | B10, R3 | R-UP1, R-UP10, R-UP11, R-VA5 | 2 expects fail; guard rows pass |
| L0 | `XCmdTest.roc` (l0-7), `ToolManageTest.roc` (l0-3), `ToolTest.roc` (l0-1), `ToolSourceTest.roc` (l0-4): the new texts of 6.1 rows 11 to 14 | B13 | R-X1, R-T1, R-S6 | see below |
| L2 | The anchor note added by hand (script `research/slice-262-help/anchor_note.py`, each line read): `probe/sc1-scan`, `moves/hm1-noninteractive`, `moves/hm2-interactive`, `registry/ap30-held-move-notes` (stdout, stderr, `data.notes`), `registry/of3-offline-held-yanked`, `registry/rg2-example-add-short` (the design example, stdout, stderr, `data.notes`), `registry/au7-held-move`, `registry/sp24-update-held-move`, `sp24-second-evidence`, `sp24-ingest-held-move`, `sp24-held-move-drop`, `resolve/rs-new-toml`, `resolve/rs-update-scope`, `update/au7-direct-held-move`; `upgrade/ug1-flow` run 3 has none (R1) | B9 | R-AD28, R-UP11 | fail: no note |
| L2 | The held line: `upgrade/ug1-flow` (run 2 and its `--json` run: new text; run 7 `update`: new line), `upgrade/ug2-lag`, `upgrade/ug4-hint-order` (new text), `workspace/ws1-closure-keys` (w4), `closure/cl2-chain` (p2, p5): new line before the exit 10 | B10 | R-UP1, R-UP10 | fail |
| L2 | `outdated/od1-table`, `outdated/od3-exclude`: the `util` row `1.0.0 (pinned)` (columns widen) and `"pinned":"=1.0.0"` (script `outdated_pinned.py`) | B11 | R-CM6 | fail |
| L2 | `roc update`: `roc/up1-update`, `roc/up2-exclude`, `share/sh62-no-send-roc-update` (pinned project: line A, `project`, the walk calls), `channels/ch15-update`, `registry/ix6-roc-update-offline`, `registry/rg9-toolchains-down` (no project: the walk calls, `"project":null`) (script `roc_update_hint.py`). `ch15-update-errors` and `ch15-update-switch` end with an error: no change. | B12, R5, R6 | R-RU5 | fail |
| L2 | `roc/up3-project-hint` (new): 8 runs: pin = new id (no line), no pin (line B), ROC_TOOLCHAIN, `[toolchain] roc`, a bad `talon.toml` (no line, exit 0), `--json` with an older pin (line A on stderr, `uses` `pin`), `--json` with no pin (`uses` `new`), no project (`null`). Written by hand (the L2 app did not build during the run: another agent's change was in progress). | B12, Q262-5, Q262-6 | R-RU5 | fails |
| L2 | `tool/tg2-gitstops`, `tool/tr2-rebuildstops`: the new texts | B13 | R-T1, R-S6 | fail |
| L3/L4 | `exit/ex1-parser-basic-cli` (tags real-roc, net: not in the fast set): the held line of `upgrade`; `add/ad1-add-entries`, `add/ad2-platform-json`: the anchor note | B9, B10 | R-UP1, R-AD28 | fail when run |

Not tested in L2: `update <alias>` of an anchor at its header value (Q262-4) has only the L0 row (no existing world has it; a new case needs a resolve fixture). `--no-pin` runs of existing cases stay without a note (guards: `add/ad1-add-entries` `tln i acme/pre@1.0.0 --no-pin`).

Red results (2026-11-23, capped runs, while other agents edit `cli/lib`): L0 `l0-1` 228/1 (ToolTest), `l0-2` 105/2 (VarsTest), `l0-3` 132/1 (ToolManageTest), `l0-4` 158/1 (ToolSourceTest), `l0-5` 148/1 (ReportTest), `l0-7` 136/1 (XCmdTest), `l0-9` 189/1 (RocUpdateHintTest): each failure is a 262b expect; the guard rows pass. L2 (the 262b cases and their neighbours by filter): 26 passed, 30 failed; each failed case differs only in the 262b lines (the note, the held line, the pinned cell and member, the hint, `project`, the walk calls, the 2 tool texts). L3 `add/ad1-add-entries`, `add/ad2-platform-json`: fail on the note only. `scripts/test.sh check fmt`: pass.

### 13. Disputes of the code agent (262b, 2026-11-23)

| # | Case | Fact | What the test agent must do |
| --- | --- | --- | --- |
| D1 | L2 `probe/dm1-domain` run 4 (`update json`, `--no-probe`) | The key `json = "acme/json@=2.1.0"` is in `[overrides]`. The range `=2.1.0` is an anchor to `Vars` (it does not know the table), so `update json` prints `json: pinned to =2.1.0, held (tln upgrade json moves it)` (Q262-4). The expect has no line. Decide: is an override an anchor for the held line? If not, the code agent needs the table in `Vars.Var`, or the case is changed. | Decide, then change the expect, or tell the code agent. |
| D2 | L3 `compilers/ru2-exclude-age` (5 runs of `roc update` in a project with the pin `nightly-2026-10-09-258ab27`) | Line A is new in each run (stdout; stderr with `--json` and `--quiet`: the `data.project` member too). This case is not in the list of section 12. | Change the expect of the 5 runs. |
| D3 | R5 (order of the walk calls) | The code uses `Project.find_source!` (new, one `search!`): `cwd`, `list_dirs` up, `read_files` of `talon.toml`, `read_files` of the project file. The L2 cases of 262b pass with it. | None. |
