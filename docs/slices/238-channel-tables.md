# 238 Channel tables

Phase: P2. Status: done (2026-11-09). Design Q613 answered the 10 Open questions. The user accepted the TW24 texts on 2026-11-09. Mutations: 14 of 14 caught (research/slice-238-revert/RESULT.md). Close run: check, fmt, selftest, l0, l2, l3 pass (TW20 budget warnings only).

## Rules

| Rule | What it says for this slice |
| --- | --- |
| R-CH1 (Design Q612 = G-C242, CLI 6.8) | A channel is a table: `name`, `shape`, `source`, and the parameters of its shape. A user cannot change a built-in table. Its name is reserved. |
| R-CH2 | The built-in `nightly` table: shape `github-release`, source `roc-lang/nightlies`, tag-prefix `nightly-`. |
| R-CH3 | Names: `[a-z][a-z0-9-]*`, 2 to 24 characters, no `-` at the end. Reserved: `nightly`, `stable`, `git`, `link`, `copy`, `zig`, `debug`, `local`, `compat`. |
| R-CH10 | A user channel is a `[channels.<name>]` table with all its parameters and no defaults, in `config.toml` and in the root `talon.toml`. A name in both files: equal tables, else exit 19. A reserved name: exit 19. Unknown `shape` word: exit 19 with the R-TF8 hint. Unknown key: warning. |
| R-CH17 | No format bump. An older tln reads `[channels]` as an unknown key (warning). This is a fact about the old code, not code here. The only duty of this slice is that the readers of the new tln do not break the old behavior of the other keys (guard tests). |
| R-TF4, R-TF8, R-EC19 | A value of a known key with a wrong form is exit 19 with the hint line `A newer tln may know this value. Update tln: tln tool update talon` (`Fail.with_hint`). |
| R-WS5 | Which tables a member file may hold. See Open Q3. |

Source: research/compiler-channels/PROPOSAL.md (revision 4), CLI 6.8 (the rules are in DESIGN-CLI.md now), row 238 of docs/slices/PLAN-P2-CLI.md.

Out of scope (later slices): the `github-release` shape code and ids (239), install and trust (240), selection (241), the `tln roc channel` commands (242), use, upgrade, GC (243). Not tested here.

## Scope

Facts found in the code (before any change):

| Question | Answer | Where |
| --- | --- | --- |
| How does `talon.toml` treat `[channels]` today? | `channels` is not in `known_tables`, so each `[channels.<name>]` gives the warning `<path>:<line>: unknown table [channels]` (once for each file, at the first header). No stop. | cli/lib/Intent.roc:174, :309 |
| How does `config.toml` treat `[channels]` today? | `channels` is not in `config_keys`: the warning `<path>:<line>: unknown key channels`. No stop. | cli/lib/ConfigToml.roc:104, :118 |
| Where is `talon.toml` read? | `Intent.read` with `{ path, text, role }`. One function for `Base`, `ResolveLoad`, `PathFlow`, `ToolsFlow`, so each project command and the `roc` proxy. | cli/lib/Intent.roc:102 |
| Where is `config.toml` read? | `ConfigToml.read` (`Intent.read_config` is the same function for unit tests). Callers: `Base.read_config` (Base.roc:407, used at :270 by the project commands and the proxy), `ResolveLoad.read_config!` (ResolveLoad.roc:162, prints the warnings to stderr), `RocInstall` (:287). `ConfigToml.read_lenient` (never fails, `(ignored)` warnings) is the read of `tool update talon` (RocInstall.roc:298). | cli/lib/ConfigToml.roc:21, :34 |
| How do unknown keys warn? | `talon.toml`: `unknown key <table>.<key>` (Intent) and `unknown table [<name>]`. `config.toml`: `unknown key <key>`. Both use `TomlKeys.Note` `{ line, message }` and are sorted by line. | Intent.roc:277, ConfigToml.roc:104 |
| How is an R-TF8 value fault made? | A `Note` in `issues`; the first issue by line becomes `Fail.new(Input, "<path>:<line>: <message>")`. `ConfigToml.read` always adds `Fail.with_hint`. `Intent.read` adds it except when the message starts with `the table [` (an R-WS5 table fault has no hint). The hint text is `Fail.newer_hint`. | Intent.roc:112, ConfigToml.roc:28 |
| How does a member file treat a table that only the root may hold? | A known table that is not in `member_tables` is a failure (exit 19, no hint): `<path>:<line>: the table [<name>] is not allowed in a workspace member file (it has only dependencies, overrides, patch and build)`. `channels` is not a known table yet, so it is only a warning in a member file. See Open Q3. | Intent.roc:178, :313 |
| Which commands read both files today? | The project commands and the `roc` proxy read the project files and `config.toml` in one `read_files` call (the `Base` load: `read_config` at Base.roc:270, `read_toml`). `ResolveLoad` reads both too. `tln install --frozen` shows it: `read_files <main.roc> <talon.toml> $HOME/.config/talon/config.toml`. `tln tool update talon` reads `config.toml` only (leniently). `tln run` reads `talon.toml` through `ScriptsToml.read`, with no `config.toml`. | Base.roc:270, tests/commands/cases/gate/tf10-install |
| Does the L2 command print the config warnings? | Yes. `tln install --frozen` prints the warnings of both files (`warning: $HOME/.config/talon/config.toml:1: unknown key channels`). | ResolveLoad.roc:164 |

Where the equality check can run: in the code that has both texts, that is the `Base` load and `ResolveLoad`. The design does not say which commands check. See Open Q4. The L2 case uses `install --frozen` only because it is a command that reads both files.

## Tests

The texts of all failures and warnings were proposals (TW24, see Output); the user accepted them on 2026-11-09. The line of a fault is the line of the key, and of the header for a reserved name.

| Layer | Test | Rules | State now |
| --- | --- | --- | --- |
| L0 | tests/unit/ChannelreadTest.roc, expect 1: a valid table gives no failure and no warning in `talon.toml` (Standalone, Root) and `config.toml`. | R-CH10 R-CH1 | red: the warning `unknown table [channels]` / `unknown key channels` |
| L0 | expect 2: two valid tables, one name with a digit and `-` (`my-fork2`): no fault. | R-CH10 R-CH3 | red: warnings |
| L0 | expect 3: each of the 9 reserved names is exit 19, in both files, `channels.<n>: '<n>' is a reserved channel name`, no hint line. | R-CH10 R-CH1 R-CH3 | red: warnings only |
| L0 | expect 4: `nightly` with the built-in values is still exit 19 (reserved, not equal-and-ok). | R-CH10 R-CH2 R-CH1 | red |
| L0 | expect 5: unknown `shape` word: exit 19, `channels.reify.shape: 'git-build' is not a channel shape`, hint line, line of the key, both files. | R-CH10 R-TF8 R-EC19 | red |
| L0 | expect 6: `shape = 5` and `source = 5`: exit 19, `must be a string`, hint line, both files. | R-CH10 R-TF4 R-TF8 | red |
| L0 | expect 7: an unknown key in a valid table is the warning `unknown key channels.reify.color` (line of the key), both files. | R-CH10 R-TF4 | red: the warning is `unknown table [channels]` |
| L0 | expect 8: two faults in one file: the first by line wins. | R-CH10 | red |
| L0 | expect 9: a file with no `[channels]` and an unknown table `[mystery]`: the old warning only. | R-CH17 R-TF4 | green (guard) |
| L0 | expect 10: an unknown key `mystery = 1` in `config.toml`: the old warning only. | R-CH17 R-TF4 | green (guard) |
| L0 | tests/unit/ChannelTest.roc: `Channel.name_check` (valid names, bad syntax names, the 9 reserved names, names that only contain a reserved word) and `Channel.builtin` (`nightly` table, no table for `reify`, `stable`, `git`, empty). 6 expects. | R-CH3 R-CH2 R-CH1 | red on purpose: the module `Channel` does not exist (compile error, as slice 236) |
| L2 | tests/commands/cases/channels/ch10-project: `install --frozen` of 8 projects with `talon.toml`: valid table, `nightly` (built-in values), `stable`, unknown shape, shape not a string, source not a string, unknown key, valid table in a workspace root file. | R-CH10 R-CH1 R-CH2 R-CH3 R-TF4 R-TF8 R-EC19 R-WS5 | red: all 8 runs exit 0 with the warning `unknown table [channels]` |
| L2 | ch10-config-reserved: `config.toml` has `[channels.nightly]`: exit 19. | R-CH10 R-CH1 R-CH2 R-EC19 | red: exit 0, warning |
| L2 | ch10-config-shape: `config.toml` has an unknown shape: exit 19 and the hint line. | R-CH10 R-TF8 | red |
| L2 | ch10-config-warn: `config.toml` has a valid table with an unknown key: exit 0, the warning that names `channels.reify.color`. | R-CH10 R-TF4 | red: the warning names `channels` |
| L2 | ch10-both-equal: the same table in both files (other key order and spaces): exit 0, no warning. | R-CH10 | red: two warnings |
| L2 | ch10-both-differ: the same name, another `source`: exit 19. | R-CH10 R-EC19 | red: exit 0, two warnings |

| L0 | ChannelreadTest expect 11 (Q613 item 1): a table with a missing key (`shape`, `source`, `tag-prefix`) is exit 19, `channels.<name>: missing key <key>`, line of the header, no hint line. Both files. | R-CH10 | red |
| L0 | expect 12 (Q613 item 2): a table name that R-CH3 refuses (`Reify`, `a`, 25 characters, `ab-`, `1ab`) is exit 19, `channels.<n>: '<n>' is not a channel name`, no hint line. | R-CH3 R-CH10 | red |
| L0 | expect 13 (Q613 item 3): `[channels]` in a Member file is exit 19, the table-not-allowed text of R-WS5, no hint line. | R-WS5 R-CH10 | green |
| L0 | expect 14 (Q613 item 7): `channels = 5` and `[channels] reify = "x"`: exit 19, `channels: must be a table` / `channels.reify: must be a table`, hint line. Both files. | R-CH10 R-TF4 R-TF8 | red |
| L0 | expect 15 (Q613 item 9): a channel fault (line 1) and a gate failure (line 7) in one `talon.toml`: the gate message. | R-TF10 R-CH10 | green |
| L0 | ChannelTest, `Channel.compare` (Q613 items 4, 5; the name is the one of the code agent): equal tables in another key order, an unknown key on one side, a name in one file only: no failure. | R-CH10 | green |
| L0 | ChannelTest, `Channel.compare`: a differing `tag-prefix` or `source`: exit 19, no hint line. | R-CH10 | green |
| L2 | channels/ch10-proxy-differ (Q613 item 4, mutant m11): the `roc` proxy `@roc check p1/main.roc` and `p2/main.roc` (not early: no `+<id>`, no ROC_TOOLCHAIN) with different `[channels.reify]` tables in `config.toml` and `talon.toml` (another `source`; another `tag-prefix`): exit 19, `channels.reify is not equal to channels.reify in <config>:1`, no compiler run. | R-CH10 R-EC19 | green |
| L2 | channels/ch10-update-skip (Q613 item 4): `tool update talon` with different tables in `config.toml` and in the `talon.toml` of the directory: no check, exit 0. | R-CH10 | green (guard: the command reads no `talon.toml`) |
| L2 | channels/ch10-update-bad (Q613 item 8): `tool update talon` with an unknown shape in `config.toml`: the warning `... channels.reify.shape: 'git-build' is not a channel shape (ignored)`, the update goes on, exit 0. | R-CH10 R-TF8 | green |
| L2 | channels/ch10-gate-first (Q613 item 9): `install --frozen`, `talon.toml` with `[channels.nightly]` and a `tln` range outside: the gate message. | R-TF10 R-CH10 | green |
| L2 | channels/ch10-both-fault (Q613 item 10): `install --frozen`, a fault in `config.toml` (shape) and another in `talon.toml` (reserved name): the message of `config.toml`. | R-CH10 | green |

Result of the runs (before any code change):

| Command | Result |
| --- | --- |
| `roc test tests/unit/l0-9.roc` (as the scripts run it) | 60 tests run: 46 pass, 8 fail (ChannelreadTest expects 1 to 8), 6 compiler errors, all in ChannelTest.roc (the module `lib.Channel` does not exist: red on purpose). The old tests of the driver still run and pass. |
| Same driver without ChannelTest (temporary driver, deleted after) | 10 tests of ChannelreadTest: 2 pass (the guards), 8 fail. 0 compiler errors. |
| `tests/commands/run.sh channels` | 6 cases, 0 pass, 6 fail. In `ch10-both-equal` and `ch10-config-warn` only stderr differs. In the others the exit code, stdout, stderr and the tail of `calls.log` differ, as the rows above say. |
| `tests/commands/run.sh` (all) | 567 pass. The 6 new cases fail. All old cases pass. |
| `MISSING=1 scripts/rules.sh R-CH1 R-CH2 R-CH3 R-CH10 R-CH17` | no rule of this slice without a test |

Runs after the code agent and Q613 (TMPDIR under `.tmp/tmp`, capped): `roc test tests/unit/l0-9.roc`: 67 tests, 64 pass, 3 fail (ChannelreadTest 11, 12, 14: the Q613 items 1, 2, 7). `tests/commands/run.sh` (all): 577 pass, 0 fail.

I added `import ChannelTest` and `import ChannelreadTest` to tests/unit/l0-9.roc (no new driver). No `scripts/test.sh` run: `roc test` of l0-9 exits 1 while `Channel` is missing.

The expected L2 files are written by hand from the old output (`UPDATE=1`, then edited). I read them after: the failing runs keep the project record step (as in slice 236), their `calls.log` ends after the `read_files` of the three files, and the file `expect/exit` is 0 (the `commands` entry always exits 0 and prints `exit N` to stdout).

### Mutation check (TW12)

The code agent runs these after the code is green.

| Id | Mutation | Caught by |
| --- | --- | --- |
| m1 | A reserved name is allowed in `config.toml` only (or in `talon.toml` only) | ChannelreadTest 3, ch10-project `res`, ch10-config-reserved |
| m2 | `nightly` with equal values is allowed | ChannelreadTest 4, ch10-project `res` |
| m3 | An unknown shape gives no hint line | ChannelreadTest 5, ch10-config-shape, ch10-project `shape` |
| m4 | An unknown key in a channel table is a failure, or is silent | ChannelreadTest 7, ch10-config-warn, ch10-project `warn` |
| m5 | The two files are not compared, or only the `source` is compared | ch10-both-differ |
| m6 | The comparison is on the text (key order counts) | ch10-both-equal |
| m7 | A name limit is off by one (24 or 25, 1 or 2 characters) | ChannelTest 1 and 2 |
| m8 | A reserved word is matched as a prefix | ChannelTest 4 |
| m9 | The read of a table breaks the warning of another key | ChannelreadTest 9 and 10 |

## Changed expectations

None. No existing case or test changes. The new cases are new directories; ChannelTest and ChannelreadTest are new files.

## Code proposal

| Item | Proposal |
| --- | --- |
| New module | `cli/lib/Channel.roc` (pure). `Channel.name_check : Str -> Try({}, [BadName, Reserved])`. `Channel.builtin : Str -> Try({ shape : Str, source : Str, tag_prefix : Str }, [NotBuiltIn])`. The record shape follows `github-release` (R-CH4); the code agent may change it with the test agent if shape 239 needs another form. |
| `Intent.read` | `channels` becomes a known table of the roles Standalone and Root. Each `[channels.<name>]` is checked by the same function as in `ConfigToml`. Faults go in `issues` (hint except for the reserved name). |
| `ConfigToml.read` | `channels` is added to `config_keys`; same function. |
| Equality | A pure function over the two read tables, called where both files are read (`Base` load, `ResolveLoad`). The place is Open Q4. |

## Output (proposed, TW24)

| Case | Text |
| --- | --- |
| Reserved name | `<path>:<line>: channels.<name>: '<name>' is a reserved channel name` (line of the table header, no hint line) |
| Unknown shape | `<path>:<line>: channels.<name>.shape: '<word>' is not a channel shape` then the hint line |
| Not a string | `<path>:<line>: channels.<name>.<key>: must be a string` then the hint line |
| Unknown key | `warning: <path>:<line>: unknown key channels.<name>.<key>` |
| Tables differ | `<talon.toml path>:<line>: channels.<name> is not equal to channels.<name> in <config.toml path>:<line>` (exit 19, no hint line) |
| `--json` | The error object has the kind `input` and the message. No `data` field. |

## Open

All 10 questions were answered by the user on 2026-11-09 (Design Q613, G-C243; CLI R-CH10 holds the details). The tests follow.

| Item | Answer (Q613) | Tests |
| --- | --- | --- |
| Q1. Missing key | Exit 19, `channels.<name>: missing key <key>`, no hint. | ChannelreadTest 11 |
| Q2. Bad name in a file | Exit 19, as a reserved name. | ChannelreadTest 12 |
| Q3. `[channels]` in a member file | Exit 19, as `[toolchain]` (R-WS5). | ChannelreadTest 13 |
| Q4. Which commands compare | Each command that reads both files. `tool update talon` does not. | ch10-both-differ, ch10-both-equal, ch10-proxy-differ, ch10-update-skip, ChannelTest compare |
| Q5. Equality | Known keys only. | ChannelTest compare |
| Q6. Forms of `source` and `tag-prefix` | Checked by the shape, slice 239. This slice checks only that they are strings. | ChannelreadTest 6 (strings) |
| Q7. `channels = 5`, `[channels] reify = "x"` | Exit 19 with the R-TF8 hint. | ChannelreadTest 14 |
| Q8. `tool update talon`, bad table in `config.toml` | A warning, the table is ignored. | ch10-update-bad |
| Q9. Gate and channel fault | The R-TF10 gate first. | ChannelreadTest 15, ch10-gate-first |
| Q10. Fault in both files | The fault of `config.toml` shows. | ch10-both-fault |

The texts of this slice (Output table, and the new messages `missing key`, `is not a channel name`, `must be a table`, the `(ignored)` warning, the `is not equal to` text) were accepted by the user on 2026-11-09 (TW24).

Why ch10-proxy-differ catches m11 (`channels_equal` in `Base.load!` off): `install --frozen` compares in `ResolveLoad` first, so the other L2 cases do not reach `Base`. `Base.load!` calls `channels_equal` for the source `Read` and one `talon.toml` (Base.roc:275, :418). The only caller with the source `Read` is the `roc` proxy for a run that is not early (Proxy.roc:222); the early runs (`+<id>`, `ROC_TOOLCHAIN`) use `Patches`, and `tln path` does not use `Base.load!` with `Read`. In the case, each file is valid alone, so no other check fails. With the check off, the proxy would go on to select a compiler (exit and `calls.log` differ from the exit 19 and the log that stops after the read of the three files). I did not run the mutant (no edit of cli/lib).

## Case changes outside this slice (tool rm sizes)

Five old cases, `tool/rm1-default`, `rm2-options`, `rm3-windows`, `rm5-win-path` and `rm7-stale-recorded`, failed when the work dir was not `/tmp/talon-l2/<case>`: the `.talon.json` of `link-mine` held `{w}/home/.../src/roc/zig-out/bin/roc`, and its size is in the size of the group `compilers` of `tool rm`. The size depended on the length of the path of the work dir.
Change: the `path` of each `link-mine` is the fixed text `/opt/user/src/roc/zig-out/bin/roc` (the commands only print it, they do not open it). The `kept link-mine: ...` lines and the tree diffs follow; the sizes are exact again (`986 B` for the group, was `1.0 KB`). The checks of the cases are the same. `link-system` keeps `{w}` because the command moves `roc.old` back to `roc` (its size is not in a group of these cases). `tests/commands/run.sh` also leaves out `list_dirs /` and the dirs after `$WORK` in a "Checked:" text when the work dir is not under `/tmp/talon-l2`.
