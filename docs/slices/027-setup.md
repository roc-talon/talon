# 027 Setup

Phase: P1. Status: done

Slice 027 makes `tln setup` (CLI 6.7, R-CM18, R-ST1 to R-ST15). The command connects Talon to the shell. It makes the bin dir entries `tln`, the `roc` launcher and one entry for each tool (a hard link of the file in the data bin dir, else a copy), moves a `roc` that Talon did not write to `roc.old` and links it as the compiler `link-system`, adds the bin dir to `PATH` (one profile line, or the file of `GITHUB_PATH`), and writes the shell completions. The Windows `Path` edit is a pure command line (L0). It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-027-revert/before/` (with `NEW.txt`).

This slice writes outside the project (the bin dir, the shell files). The L3 case runs with `HOME` set to the work dir of the runner and with a second `HOME` under `$TALON_TEST_DIR`. It never touches a real user file. The L2 cases use the fake `Fx` in the case dir.

## 0. Size and split proposal (for the manager)

| Item | Value |
| --- | --- |
| Plan row | 400 lines |
| The reference of the test agent (`research/slice-027-revert/reference/cli/lib/Setup.roc`) | 780 lines, of them 647 are not comment or blank. 62 lines are completion text and about 25 are the PowerShell text. About 500 lines are logic, with the output text (`report`, `data`). |
| Verdict | About 25 percent above "about 400" (TW19). It is not clearly too large, so all of it is tested. The tests of the PATH part are separate rows, so a split is still possible. |

Split, if the manager wants it (the rows are marked 027a or 027b in the test table):

| Part | Rules | Content |
| --- | --- | --- |
| 027a | R-CM18, R-ST1, R-ST2, R-ST6, R-ST7, R-ST8, R-ST11, R-ST13 to R-ST15, R-NI13, R-HF7, R-LY8 | Entries, launcher, `roc.old`, `link-system`, the `Fx.hard_link!` call, the ownership test |
| 027b | R-ST3, R-ST4, R-ST5, R-ST12 (the PATH and completion part), R-NI14, R-HF11, R-LY9 | `PATH` line, `GITHUB_PATH`, completions, Windows `Path` command, the shadow warning |

A split costs one more edit of `expect/` of the two L2 cases and of the L3 case (the PATH and completion lines are in the same runs). So the test agent does it, not the code agent.

## 1. Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-CM18 (`tln setup`) | `Setup.run!`, `Setup.read` | L0 `read`. L2 `st1-flow` (all runs). L3 `st1-setup-real` |
| R-ST1 (entries `tln`, `roc`, each tool, `.exe` on Windows) | `Setup.names` | L0 `names`. L2 `st1-flow` runs 1, 2. L3 parts 1, 2 |
| R-ST2 (a foreign `roc`: the prompt, `roc.old`, `link-system`, or the note) | `Setup.old_roc`, `Setup.run!`, `Consent.setup_replace_roc` | L0 `names`. L2 `st1-flow` runs 1, 2. L2 `st2-copy-fallback` run 1. L3 parts 4 to 6 |
| R-ST3 (the warning for a `roc` before the bin dir on `PATH`) | `Setup.shadow` | L0 `PATH`. L2 `st1-flow` runs 1 to 4. L3 part 9 (second run) |
| R-ST4 (the `PATH` line, the profile of the shell, `GITHUB_PATH`, `--no-modify-path`) | `Setup.on_path`, `shell_of`, `profile`, `path_line`, `profile_edit`, `github_edit` | L0 `PATH`, `shell`, `edit`. L2 `st1-flow` runs 5 to 12. L3 parts 1, 3, 8, 9 |
| R-ST5 (completions, no prompt) | `Setup.completion`, `completion_path` | L0 `shell`, `completion`. L2 `st1-flow` runs 1, 10, 12. L3 part 1 |
| R-ST6 (never overwrite a file that Talon did not write) | `Setup.judge` | L0 `judge`. L2 `st1-flow` (foo, roc). L3 parts 4, 7 |
| R-ST7 (hard link, else copy, temp and rename) | `Fx.hard_link!`, `Fx.copy_file!`, `Fx.rename!` in `Setup.run!` | L2 `st1-flow` run 1. L2 `st2-copy-fallback`. L3 part 1. L3 `fx/st1-real-fx-hard-link` |
| R-ST8 (`roc` is `tln` with another name) | the existing proxy test (slice 023) | L3 part 2 (the made launcher runs as the proxy, `tln` runs as `tln`) |
| R-ST9 | first sentence: slice 050. Second sentence (setup repairs a stale entry): question Q7, no test | L3 `fx/st1-real-fx-hard-link` shows the cause only (a `rename` over the source leaves the link on the old file) |
| R-ST10 (Windows `.del` files) | slice 050 | out of scope, section 8 |
| R-ST11 (ownership: same sha256 as the file in the data bin dir) | `Setup.judge`, the `sha256_file!` calls | L0 `judge`. L2 `st1-flow` (foo, roc, tln). L3 parts 4, 6, 7 |
| R-ST12 (setup runs again and changes only what is missing) | all `Keep` branches | L0 `judge`, `edit`, `completion`. L2 `st1-flow` runs 3, 7, 9. L2 `st2-copy-fallback` run 2. L3 parts 3, 8 |
| R-ST13, R-ST14, R-ST15 (`tln`, `roc`, `<tool>`: the file in the data bin dir) | `Setup.names` | L0 `names`. L2 `st1-flow` run 1, 2. L3 part 1 |
| R-NI13 (replace a `roc`: default No, `--replace-roc`, `--yes`) | `Consent.setup_replace_roc`, `Setup.run!` | L2 `st1-flow` runs 1, 2. L2 `st2-copy-fallback` (the answer y). L3 parts 4 to 6 |
| R-NI14 (add the bin dir to `PATH`: default Yes, `--no-modify-path`) | `Consent.setup_modify_path`, `Setup.run!` | L2 `st1-flow` runs 5, 6, 8, 12. L3 parts 1, 9 |
| R-HF7 (a bin dir entry is a hard link or a copy, never a symbolic link) | `Fx.hard_link!` | L2 `st2-copy-fallback`. L3 part 10 (no symbolic link). L3 `fx/st1-real-fx-hard-link` |
| R-HF11 (the Windows `Path` edit as a child) | `Setup.windows_path` | L0 `windows_path` |
| R-LY8 (bin dir: `~/.local/bin`, `%USERPROFILE%\.local\bin`) | `Setup.bin_dir` | L0 `bin_dir`. L3 part 1 |
| R-LY9 (`PATH`: one profile line, the user `Path` value on Windows) | `Setup.profile`, `path_line`, `windows_path` | L0 `shell`, `edit`, `windows_path`. L2 runs 5 to 12 |

Rules of other slices that the cases also touch: R-CC1 (temp and rename), R-CC3 (the lock of `link-system`, no prompt under a lock), R-LK4 (the `.talon.json` of `link-system`), R-NM4, R-NM6, R-NM8 (prompt kinds and the answer line), R-J3, R-OUT2, R-OUT4, R-FL12 (`--replace-roc` and `--no-modify-path` are flags of `setup`, `Args.allows` has them since slice 001), R-TF1 to R-TF3, R-TF6 (`tools.json` is read as a Talon file), R-PX1 (the launcher).

`MISSING=1 scripts/rules.sh R-CM R-ST R-NI R-HF R-LY` lists, for the ids of this slice, only R-ST10.

## 2. Flow of `tln setup` (the calls that the L2 cases fix)

The doc of `cli/lib/Setup.roc` has the same table. `<bin>` is `<HOME>/.local/bin`, `<data bin>` is `<data>/bin` (`Roots.item(Bin)`).

| Step | Calls | Rule |
| --- | --- | --- |
| 1 | `Setup.read(args)` (no `Fx` call). A failure: `Common.failed!`. | R-CM18 |
| 2 | `env_all`, `platform` (`Roots.from_env`, `Setup.bin_dir`) | R-LY8 |
| 3 | `read_files` of `tools.json` (`NotFound` is no tool), `Setup.tool_names`, `Setup.names` | R-ST1 |
| 4 | `list_dirs` with 2 dirs: `<data bin>`, `<bin>` (a missing dir is empty) | R-ST7 |
| 5 | `sha256_file` of each distinct source that the listing of `<data bin>` has, in the order of `names`. Then `sha256_file` of each entry that the listing of `<bin>` has as a file, in the order of `names`. `Setup.judge` for each entry. | R-ST11 |
| 6 | `path_roc`. Warnings on stderr: `Setup.shadow`, a foreign `tln` or tool entry, a tool with no file in `<data bin>` | R-ST3, R-ST6 |
| 7 | Only when `Setup.on_path` is false: `read_files` of the target (`GITHUB_PATH` when it is set, else the profile of `SHELL`). `github_edit` or `profile_edit`. A shell that is not bash, zsh or fish has no target. | R-ST4 |
| 8 | Only when `SHELL` is bash, zsh or fish: `read_files` of the completion file. The same text: no write. | R-ST5 |
| 9 | The prompts, before a write and before a lock: R-NI13 when `roc` is foreign, then R-NI14 when step 7 found a change to write | R-NI13, R-NI14 |
| 10 | The writes. `make_dirs` of `<bin>` (only when an entry is made). `Yes` to R-NI13: `rename` of `<bin>/roc` to `<bin>/roc.old`, then step 11. Each entry to make, in the order of `names`: `random`, `hard_link` to `<bin>/<entry>.<hex>.tmp`, else `copy_file` to it, then `rename` to `<bin>/<entry>`. Then `write_atomic` of the `PATH` target and of the completion file. | R-ST7, R-CC1 |
| 11 | `link-system`: `clock`, then the lock of `<cache>/toolchains/link-system` (`Fx.locked!`), `list_dirs` of `toolchains`, and when the item is not there `random`, `write_atomic` of `<item>.<hex>.tmp/.talon.json`, `rename` of the dir. | R-ST2, R-LK4 |
| 12 | The output (section 6) | R-OUT2, R-J3 |

The `PATH` check, the profile and the completions are for Linux and macOS. The Windows flow (names with `.exe`, the `Path` value, no profile) is the Windows CI job (section 8).

## 3. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Setup.roc` | 140 | Stubs from the test agent. Bodies from the code agent. | New module. 17 public functions and 4 types, all bodies `crash "todo"`. The docs have the contract and the table of the calls. |
| `cli/lib/Consent.roc` | +24 | Test agent, stub | `setup_replace_roc`, `setup_modify_path`: `crash "todo"`. The docs have the texts. |
| `cli/lib/Fx.roc`, `cli/RealFx.roc`, `cli/RealFiles.roc` | +13, +1, +4 | Test agent, stub | New `hard_link!`. In `RealFiles` it is `crash "todo"`. |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | +3, +1 | Test agent | The dispatch for `["setup"]`, and `Setup` in the exposes list |
| `cli/fxprobe.roc` | +9 | Test agent (test tool) | The call `hardlink <from> <to>` |
| `tests/commands/FakeFx.roc` | +29 | Test agent | `hard_link!` (a real hard link, `fx/hardlink` makes it fail by a suffix) |
| `tests/unit/setup.roc` | 240 | Test agent | 10 `expect`s, red |
| `tests/commands/cases/setup/st1-flow/` | 1 case | Test agent | L2, 13 runs |
| `tests/commands/cases/setup/st2-copy-fallback/` | 1 case | Test agent | L2, 2 runs |
| `tests/scenarios/setup/st1-setup-real/` | 1 case | Test agent | L3, 10 parts (80 lines of `cmd`) |
| `tests/scenarios/fx/st1-real-fx-hard-link/` | 1 case | Test agent | L3, the real `Fx` job |
| `research/slice-027-revert/` | | Test agent | `before/` (copies and `NEW.txt`), `reference/` and `stubs/` (3 files each), `swap.sh ref|stub`, `mutate.py`, `mutate-run.log`, `results.md`. The private reference stays until the manager says to delete it. |

`scripts/test.sh`, `tests/run.sh`, `tests/commands/run.sh`, `tests/commands/main.roc` and `tests/selftest.sh` are not changed.

## 4. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `Fx.hard_link!` | `{ from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])`: a new name for the same file (the same inode, bytes and bits). `NotFound`: `from` or the parent dir of `to` is missing. `Exists`: `to` is there. No parent dir, no temp file. A directory at `from` and another file system: `Other`. | R-ST7, R-HF7 |
| `Setup.Plan` | `{ replace_roc : Bool, no_modify_path : Bool }` | R-NI13, R-NI14 |
| `Setup.Os`, `Setup.Shell` | `[Linux, Macos, Windows, Other(Str)]`, `[Bash, Zsh, Fish]` | |
| `Setup.Entry` | `{ entry : Str, source : Str }` | R-ST13 to R-ST15 |
| `Setup.read` | `Args -> Try(Setup.Plan, Fail)` | R-CM18 |
| `Setup.names` | `{ os : Setup.Os, tools : List(Str) } -> List(Setup.Entry)` | R-ST1, R-ST13 to R-ST15 |
| `Setup.old_roc` | `Setup.Os -> Str` | R-ST2 |
| `Setup.bin_dir` | `{ os : Setup.Os, env : List((Str, Str)) } -> Try(Str, Fail)` | R-LY8 |
| `Setup.judge` | `{ source : [Missing, Sha(Str)], have : [Absent, Dir, Unreadable, Sha(Str)] } -> [NoSource, Make, Keep, Foreign]` | R-ST11, R-ST6 |
| `Setup.on_path` | `{ path : Str, dir : Str } -> Bool` | R-ST4 |
| `Setup.shadow` | `{ path : Str, dir : Str, found : List(Str) } -> Try(Str, [None])` | R-ST3 |
| `Setup.shell_of` | `Str -> Try(Setup.Shell, [Unknown])` | R-ST4 |
| `Setup.profile` | `{ home : Str, shell : Setup.Shell } -> Str` | R-ST4 |
| `Setup.path_line` | `{ shell : Setup.Shell, dir : Str } -> Str` | R-ST4 |
| `Setup.profile_edit` | `{ shell : Setup.Shell, dir : Str, existing : Try(Str, [NotFound]) } -> [Keep, Write(Str)]` | R-ST4, R-ST12 |
| `Setup.github_edit` | `{ dir : Str, existing : Try(Str, [NotFound]) } -> [Keep, Write(Str)]` | R-ST4 |
| `Setup.completion_path` | `{ home : Str, shell : Setup.Shell } -> Str` | R-ST5 |
| `Setup.completion` | `Setup.Shell -> Str` | R-ST5 |
| `Setup.windows_path` | `{ dir : Str, op : [Add, Remove] } -> { argv : List(Str), env : List((Str, Str)) }` | R-HF11 |
| `Setup.tool_names` | `{ path : Str, text : Str } -> Try(List(Str), Fail)` | R-ST1, R-ST11, R-TF1 |
| `Setup.run!` | `Fx, Args => I32` | R-CM18 |
| `Consent.setup_replace_roc` | `{ path : Str, old : Str } -> Prompt` | R-NI13 |
| `Consent.setup_modify_path` | `{ dir : Str, target : Str } -> Prompt` | R-NI14 |

The private parts of the reference (`Done`, `report`, `data`, the steps) are not fixed. The L2 `calls.log` and the expected output fix what the command does.

## 5. Tests

| Layer | File and case | What it checks | Rules | Part |
| --- | --- | --- | --- | --- |
| L0 | `tests/unit/setup.roc` 1 (`read`, 6 rows) | No flag, `--replace-roc`, `--no-modify-path`, both with the global flags. 1 and 2 operands are exit 2. | R-CM18, R-NI13, R-NI14 | a |
| L0 | 2 (`names`, 6 rows, and `old_roc`) | Order `tln`, `roc`, tools. `roc` has the source `tln`. `talon`, `tln`, `roc` and repeats are left out. `.exe` on Windows. Another system is a Unix. `roc.old.exe`. | R-ST1, R-ST2, R-ST13 to R-ST15 | a |
| L0 | 3 (`bin_dir`, 7 rows) | `~/.local/bin`, `\` and `/` at the end, `USERPROFILE` on Windows only, a missing or empty variable is exit 18 | R-LY8, R-ST1 | a |
| L0 | 4 (`judge`, 7 rows) | Absent: make. Same sha256: keep. Other content, a directory, an unreadable file: foreign. No source: no entry. | R-ST11, R-ST6, R-ST7, R-ST12 | a |
| L0 | 5 (`on_path` 7 rows, `shadow` 8 rows) | A part of `PATH` with `/` and empty parts. A `roc` before the bin dir, the first of two, none after it, none in the bin dir, `//`, the bin dir not on `PATH` (Q3). | R-ST4, R-ST3 | b |
| L0 | 6 (`shell_of` 8 rows, `profile`, `path_line`, `completion_path`) | bash, zsh, fish by the last part of `SHELL`. tcsh, sh, `mybash`, empty: unknown. The 3 profiles, the 3 lines with the marker, the 3 completion paths. | R-ST4, R-ST5, R-LY9 | b |
| L0 | 7 (`profile_edit` 9 rows, `github_edit` 6 rows) | No file, empty, a last line end or none, the marker is there (also with another dir), the dir without the marker, fish. `GITHUB_PATH`: the plain dir, a longer path is not the dir. | R-ST4, R-ST12, R-LY9 | b |
| L0 | 8 (`completion`) | Each of the 21 commands and the subcommands of `roc`, `tool`, `cache` is a word of each text. `complete -F`, `#compdef tln`, `complete -c tln`. The same text on each call. | R-ST5, R-ST12 | b |
| L0 | 9 (`windows_path`) | The 5 words of `argv`. The dir (with a space, a quote, `$`, `%`) is only in `TALON_BIN_DIR`. `DoNotExpandEnvironmentNames`, `ExpandString`, `WM_SETTINGCHANGE`, no `setx`. One script for each dir, 2 scripts for `Add` and `Remove`. | R-HF11, R-ST4, R-LY9 | b |
| L0 | 10 (`tool_names`, 10 rows) | The keys of `tools`, in order. No field: no tool. An unknown field is fine. Not JSON, an array, no `format`, a newer `format`, a `tools` that is no object: exit 19. | R-ST1, R-ST11, R-TF1 to R-TF3, R-TF6 | a |
| L2 | `setup/st1-flow` (13 runs, entry `commands`) | See the list below | R-ST1 to R-ST7, R-ST11 to R-ST15, R-NI13, R-NI14, R-LY9, R-J3 | a, b |
| L2 | `setup/st2-copy-fallback` (2 runs) | The hard link fails: a copy. The prompt in a terminal. A second run changes nothing. | R-ST7, R-HF7, R-ST13, R-ST14, R-NI13, R-ST2, R-ST12 | a |
| L3 | `setup/st1-setup-real` (10 parts) | The real binary, the real `Fx`, a temp HOME. See the list below. | R-CM18, R-ST1 to R-ST8, R-ST11 to R-ST15, R-NI13, R-NI14, R-LY8, R-LY9, R-HF7 | a, b |
| L3 | `fx/st1-real-fx-hard-link` | `hard_link!` of the real `Fx`: the same inode, the bits, a `rename` over the source, `Exists`, `NotFound`, no parent dir, a directory | R-ST7, R-HF7, R-ST9 (cause), TW4 | a |

L2 runs of `st1-flow` (`fx/commands` has the comments. `fx/env` has `CI=true`, `SHELL=/bin/bash` and a `PATH` with `/usr/local/bin` before the bin dir. `fx/path-roc` has `/usr/local/bin/roc`.):

| # | Run | Shows |
| --- | --- | --- |
| 1 | `setup` | `tln` and `baz` are made (hard link, temp, rename). `roc` is foreign: the answer No with no prompt text, no launcher. `foo` is foreign, `bar` has no file: warnings. `/usr/local/bin/roc` is before the bin dir: the warning. The bash completion is written. |
| 2 | `setup --replace-roc --json` | The answer Yes by the flag. `roc` goes to `roc.old`, `link-system` is made under its lock, the launcher is made. The envelope has `roc_old: true`. |
| 3 | `setup` | Only reads. The same warnings. No stdout line (an entry is skipped, so it is not "nothing to do"). |
| 4 | `setup --json` | The data of a run with kept and skipped entries, `path: on-path`, `completion: present` |
| 5 | `setup env:PATH=/usr/bin env:CI=false` | The bin dir is not on `PATH`. The profile has no line. `tty`, the prompt, the answer `n`: no write, the line is printed. |
| 6 | the same | The answer Enter: the default Yes. The line goes at the end of `.bashrc`, after a line end that the old text lacked. |
| 7 | `setup env:PATH=/usr/bin` | The marker is there: no prompt, nothing to do |
| 8, 9 | `... env:GITHUB_PATH=<file>` twice | The file is made with the plain dir, in place of a profile line. The second run writes nothing. |
| 10 | `... env:SHELL=/usr/bin/fish` | `conf.d/talon.fish` and the fish completion |
| 11 | `... env:SHELL=/bin/tcsh` | No profile, no completion. The line is printed (Q5). |
| 12 | `setup --no-modify-path env:SHELL=/bin/zsh` | The answer No by the flag. The line is printed. The zsh completion is written. |
| 13 | `setup now` | Exit 2, no call after `args` |

L3 parts of `st1-setup-real` (`cmd` has the comments):

| # | Part | Shows |
| --- | --- | --- |
| 1 | the first setup | `tln`, `roc` and `foo` are the same files (`-ef`) as in the data bin dir (`$TALON_TEST_DIR/data`, not under HOME). The profile gets the marker line. The completion is valid bash and completes `ro` to `roc` and the `roc` subcommands. |
| 2 | the entries run | The launcher `roc +<id> version` runs the fake compiler (the proxy). `tln --version` runs as `tln`. `foo a b` runs the tool. |
| 3 | setup again | "nothing to do". One marker line. |
| 4 | a foreign `roc` | The default No: the file stays, the note names `--replace-roc`, the old `roc` still runs |
| 5 | `--replace-roc` | `roc.old`, `link-system/.talon.json` with the path of `roc.old`, the launcher is `tln` again. `roc +link-system version` runs the old `roc`. |
| 6 | `--yes` with a later `TALON_NOW` | The same move. The `link-system` that exists keeps `installed_at` of part 5 (decision D6). |
| 7 | a foreign tool entry | The warning. The file stays. |
| 8 | `GITHUB_PATH` | The file has the dir. The second run changes nothing. The profile is not changed. |
| 9 | a second HOME, `--no-modify-path` | No profile. The entries are made in `h2`. A second run with `h2/.local/bin` on `PATH` after the fake `roc` of the runner: the R-ST3 warning, nothing else. |
| 10 | `setup now`, symbolic links | Exit 2. No symbolic link was made in HOME or h2 (R-HF7). |

Count: 10 new L0 `expect`s in one file, 2 L2 cases (15 runs), 2 L3 cases. No selftest row.

## 6. Output (proposed, R-OUT2, TW24)

stdout (`--quiet` hides it, `--json` moves it to stderr and the envelope is on stdout):

| Case | Text |
| --- | --- |
| An entry that is made | `made <bin>/<name> (hard link)` or `made <bin>/<name> (copy)` |
| `roc` moved | `moved <bin>/roc to <bin>/roc.old, linked as link-system` |
| The profile or the file of `GITHUB_PATH` changed | `PATH: added <bin> to <target>` |
| The answer to R-NI14 is No, with a known shell | `PATH: not changed. To add <bin>, put this line in <profile>: <line>` |
| An unknown shell | `PATH: not changed (the shell is not bash, zsh or fish). To add <bin>, put this line in your shell profile: <bash line>` |
| The completion file written | `completions: <path>` |
| Nothing was written and no entry was skipped | `nothing to do: the entries, the PATH line and the completions are in place` |

stderr (always shown):

| Case | Text |
| --- | --- |
| A `roc` before the bin dir on `PATH` (R-ST3) | `warning: <file> comes before <bin> on PATH, so it runs in place of the roc launcher. Talon changes nothing there.` |
| A foreign `tln` or tool entry (R-ST6) | `warning: <bin>/<name> is not a Talon file, so tln setup left it as it is.` |
| A tool with no file in the data bin dir | `warning: <data bin>/<file> is missing, so tln setup made no entry for <name>.` |
| R-NI13 answered No | the answer line `keeping <bin>/roc`, then `note: <bin>/roc is not a Talon file, so no roc launcher was installed. To replace it, run: tln setup --replace-roc` |
| R-NI13 answered Yes | the answer line `moving <bin>/roc to <bin>/roc.old` |
| R-NI14 answered | `adding <bin> to PATH in <target>` or `not adding <bin> to PATH` |
| Usage | `tln: error[usage]: tln setup takes no operand, got <n>` |

Prompts (`Consent`, in `Prompt.text` form, the interactive default in the brackets):

| Id | Text | Default |
| --- | --- | --- |
| `replace-roc` (R-NI13, kind Default) | `<bin>/roc is a roc that Talon did not write. Move it to <bin>/roc.old and install the roc launcher? [y/N]` | No |
| `modify-path` (R-NI14, kind Default) | `Add <bin> to PATH in <target>? [Y/n]` | Yes |

`--json` `data` (keys in this order): `bin_dir` (text), `entries` (an array of `{"name", "action", "form"}`: `action` is `made`, `kept` or `skipped`, `form` is `hard-link`, `copy` or `null`), `roc_old` (true when `roc` was moved), `path` (`on-path`, `present`, `added`, `declined`, `no-shell`), `completion` (`written`, `present`, `none`).

The line that puts the bin dir on `PATH` (the marker is the end of the line, CLI 6.5 finds it with it):

| Shell | Line |
| --- | --- |
| bash, zsh | `export PATH="<bin>:$PATH" # talon: added by tln setup` |
| fish | `fish_add_path "<bin>" # talon: added by tln setup` |

The completion files (Q6). The L2 cases compare these texts exactly, so the code agent writes them as they are:

bash, `<home>/.local/share/bash-completion/completions/tln`:

```text
# bash completion for tln. Made by tln setup.
_tln() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local words=""
	if [ "$COMP_CWORD" -eq 1 ]; then
		words="init install remove update upgrade outdated why probe list patch verify x publish audit roc tool cache setup yank move share"
	elif [ "$COMP_CWORD" -eq 2 ]; then
		case "${COMP_WORDS[1]}" in
			roc) words="install link use list remove default update" ;;
			tool) words="install list update rebuild remove" ;;
			cache) words="gc clean list dir" ;;
		esac
	fi
	COMPREPLY=($(compgen -W "$words" -- "$cur"))
}
complete -F _tln tln
```

zsh, `<home>/.local/share/zsh/site-functions/_tln`:

```text
#compdef tln
# zsh completion for tln. Made by tln setup.
_tln() {
	if (( CURRENT == 2 )); then
		compadd init install remove update upgrade outdated why probe list patch verify x publish audit roc tool cache setup yank move share
	elif (( CURRENT == 3 )); then
		case $words[2] in
			roc) compadd install link use list remove default update ;;
			tool) compadd install list update rebuild remove ;;
			cache) compadd gc clean list dir ;;
		esac
	fi
}
_tln "$@"
```

fish, `<home>/.config/fish/completions/tln.fish`:

```text
# fish completion for tln. Made by tln setup.
complete -c tln -f
complete -c tln -n '__fish_use_subcommand' -a 'init install remove update upgrade outdated why probe list patch verify x publish audit roc tool cache setup yank move share'
complete -c tln -n '__fish_seen_subcommand_from roc' -a 'install link use list remove default update'
complete -c tln -n '__fish_seen_subcommand_from tool' -a 'install list update rebuild remove'
complete -c tln -n '__fish_seen_subcommand_from cache' -a 'gc clean list dir'
```

The files above use a tab for each indent in bash and zsh.

`link-system/.talon.json` is `Link.meta({ id: "link-system", kind: Link, path: "<bin>/roc.old", now })`: `{"format":1,"id":"link-system","path":"<bin>/roc.old","installed_at":"<TALON_NOW>"}`.

The PowerShell script (`windows_path`) is not fixed by a test text. The L0 rows pin the properties of R-HF11 (section 5, row 9). The reference has a script that follows R-HF11 and that nobody ran: the Windows CI job must run it.

## 7. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | New module `Setup` (pure and command code) and a new call `Fx.hard_link!`. No new module for the output. | A call that makes the whole entry (a hard link or a copy, temp and rename) in the real `Fx`: it would hide the order of the steps, and R-ST7 puts the choice in Talon (TW3 allows a coarse call, but the fallback is a Talon rule). A `Path.hard_link!` in command code (no Fx). |
| D2 | The fallback is "any `Err` of `hard_link!`". The copy is `Fx.copy_file!` (it keeps the permission bits, slice 024b), so there is no `chmod` call. | A `chmod` call after the copy (R-ST7 and R-HF2: the source in the data bin dir is executable, so the copy is). A fallback only for a cross-device error (the platform text is not a stable value). |
| D3 | An entry is judged by the sha256 of the entry and of its source (R-ST11 as written): 2 `sha256_file` calls for each entry that exists. A source is hashed once, also for `tln` and `roc`. | The size and the mtime (R-ST11 says sha256). |
| D4 | The `PATH` test uses the `PATH` variable of the process, split on `:` (Linux and macOS). It is true when a part equals the bin dir (a `/` at the end does not count). | A test with `Fx.programs!` (it looks for a program, not for a dir). |
| D5 | The prompts come after all reads and before the first write. R-NI13 is asked before R-NI14 (the order of R-ST2 and R-ST4). The lock of `link-system` is taken after the prompts (R-CC3 point 5). | Ask each prompt at the step that needs it (the lock and the reads would be mixed with the asks). |
| D6 | A `link-system` that exists is kept as it is (no write, also with another `TALON_NOW`). Its path is always `<bin>/roc.old`, so the item is right. The lock is taken and the listing is read. | Replace it with `--force` semantics (a second write of the same text). Fail with exit 2 as `roc link` does. |
| D7 | `--no-modify-path` is the flag `Ok(No)` of R-NI14, so the answer line `not adding ...` and the printed line are the result. When no write is needed (the bin dir is on `PATH`, or the profile has the marker) there is no prompt and the flag does nothing. | Ask the prompt always (a prompt with nothing to decide). |
| D8 | `GITHUB_PATH` uses the same prompt (R-NI14) and the same flag as a profile. In CI the answer is the default Yes. `GITHUB_PATH` has the priority over the profile when it is set and not empty. The completion is written also with `GITHUB_PATH` when `SHELL` is known. | A file of `GITHUB_PATH` with no prompt. A profile line too. |
| D9 | The marker is the comment `# talon: added by tln setup` at the end of the line. A profile with a line that has the marker is `Keep`, also for another dir. A profile without the marker gets the line at the end, after a line end. A fish profile (`conf.d/talon.fish`) is handled as the other profiles (R-ST6: never overwrite, so append). | Replace the line of another dir (setup changes only what is missing). Delete and write the whole profile. |
| D10 | `bin_dir` and the profile files are under `HOME` as written in R-LY8 and R-ST4 (`~`), not under `XDG_CONFIG_HOME` or `XDG_DATA_HOME`. The data bin dir is `Roots.item(Bin)` (it follows `XDG_DATA_HOME`, R-LY7). The L3 case sets `XDG_DATA_HOME` outside HOME to show it. | `$XDG_CONFIG_HOME/fish`, `$XDG_DATA_HOME/bash-completion` (R-ST4 names `~/.config/fish/conf.d/talon.fish`). |
| D11 | The note of R-ST2 (answer No) is a stderr line after the answer line. Warnings are stderr lines, never hidden by `--quiet`. | stdout lines (they are advice, not the result). |
| D12 | The tool `talon` of `tools.json` has no entry of its own. A tool named `tln` or `roc` is left out. | An entry `talon` (the binary is `tln`). |
| D13 | A tool with no file in the data bin dir is a warning and no entry (exit 0). A missing `tln` file: question Q2. | Exit 18 for each missing file. |
| D14 | The `setup` of this slice writes no `tools.json` entry for Talon (R-IS6, first sentence). It only reads `tools.json`. | Write it here (the form of `tools.json` is open, Q1; slice 052 has R-IS6). |
| D15 | The first `rename` of a run is `roc` to `roc.old`, then `link-system`, then the launcher. A stop between them leaves no `roc`. The next run makes the launcher (the entry is absent), but not `link-system`. | `link-system` first (a dangling link while `roc.old` is not there). Both in one temp step (no such call). |

## 8. Out of scope

| Id | Reason |
| --- | --- |
| R-ST9, first sentence (the update commands make the entries again) | Slice 050 (`tool update talon`) and 046, 048 for the tools |
| R-ST9, second sentence (setup repairs a stale entry) | Question Q7 (a design gap). Not tested. |
| R-ST10 (the `.del` rule of Windows) | Slice 050 (its plan row has R-ST10). It needs the Windows job. |
| R-IS6, first sentence (`tln setup` writes the `talon` entry of `tools.json`) | Slice 052, with the form of `tools.json` (Q1) |
| R-RM5, R-RM6, R-RM8 (remove: the entries, `roc.old` moves back, the profile line) | Slice 051 (it uses the marker and the ownership test of this slice) |
| The Windows flow of `Setup.run!` (names with `.exe`, `%USERPROFILE%`, the `Path` child, no profile) | The Windows CI job (TESTING.md 5). The pure parts (`names`, `bin_dir`, `old_roc`, `windows_path`) have L0 rows. The reference stops with `tln setup on Windows is not built yet`. |
| The copy fallback on a real second file system | `TESTING.md` 3.1 tag `exdev` (two file systems). The fake `Fx` (`fx/hardlink`) tests the branch. |
| A `roc.old` that exists when the answer is Yes | Question Q4 (accepted, tested since the gap rows) |
| A missing `<data bin>/tln` | Question Q2 (accepted, tested since the gap rows) |
| The running of the PowerShell script | No Windows here |
| Telling the user to start a new shell or to run `hash -r` | Not in the design |

## 9. Questions (TW17) and design gaps

The reference has a default for each question. The named tests pin it, except where the table says "not tested".

| # | Question | Default of the tests and of the reference | Other option |
| --- | --- | --- | --- |
| Q1 | The form of `tools.json` (R-T4 names the fields, not the JSON). `setup` needs the tool names. | `{"format":1,"tools":{"<name>":{...}}}`. The key is the name of the bin dir entry. Pinned by L0 `tool_names` and the given `tools.json` of the cases. Slice 046 fixes the real form and then changes `Setup.tool_names` and its rows. | An array of objects with a `name` field. A tool whose binary name is not its tool name (an alias, R-T6) needs an extra field. |
| Q2 | `<data bin>/tln` is missing (Talon was not installed by a script, or it runs from a build dir) | Exit 18: `<data bin>/tln is missing. Install Talon with its install script.` Not tested. | Copy the running `tln` (`path_roc!` has `exe`) into the data bin dir. A warning and no entry. |
| Q3 | R-ST3 when the bin dir is not on `PATH` at all | No warning: nothing "comes before" it. Pinned by L0 `shadow`. The PATH line that setup adds puts the bin dir first. | Warn for each `roc` on `PATH` |
| Q4 | The answer to R-NI13 is Yes and `roc.old` exists already | Exit 17 `<bin>/roc.old exists. Talon does not replace it. Move it away, then run tln setup --replace-roc again.`, nothing is changed. Not tested. | Replace it. Number the old files. |
| Q5 | The shell is not bash, zsh or fish (also an empty `SHELL`). R-ST4 names 3 profiles. | No profile, no completion. The bash form of the line is printed (`PATH: not changed (the shell is not bash...`). Pinned by L0 `shell_of` and L2 run 11. The form of the line and its marker are a proposal. | Look at the files of the user (`.profile`). An exit code. |
| Q6 | R-ST5 says "the user completion dir of the shell" and gives no dir and no text. | bash `~/.local/share/bash-completion/completions/tln`, zsh `~/.local/share/zsh/site-functions/_tln` (it is not in `fpath` by default: the note of the doc), fish `~/.config/fish/completions/tln.fish`. The texts of section 6. A completion of the commands and of 3 subcommand groups only (no flags, no operands). | A `tln completion <shell>` command (CLI 1 has no such command). Complete flags too. |
| Q7 (design gap) | R-ST9 says that `tln setup` repairs the entries that a `rename` over the data file left on the old file (a hard link of the old inode). R-ST11 says an entry is Talon's only when its sha256 equals the data file. A stale entry has the old content, so by R-ST11 it is foreign (and by R-ST6 setup keeps it, and for `roc` asks R-NI13). The two rules do not fit. | The tests pin R-ST11 as written: a differing entry is foreign. L3 `fx/st1-real-fx-hard-link` shows the stale link. The repair is not tested. | (a) `tools.json` records the sha256 of the installed file (R-T4), and an entry with the sha256 of an earlier install of the same name is stale. (b) The names `tln`, `roc` and the tool names are Talon's names, so setup replaces a differing entry of these names with no prompt (R-ST6 would need the exception). (c) Drop the second sentence of R-ST9: the update commands always make the entries again (the first sentence), and `setup` only makes missing ones. |
| Q8 | R-ST12 says setup changes "what is out of date". Besides Q7, what else is out of date? | Only a missing entry, a missing profile line and a completion text that differs. | |

## 10. Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| A function that has a record parameter named `where` fails to parse: `where` is reserved (also as a variable) | The reference uses `place`. |
| `\$` is the escape for a `$` in a string, so `"\${x}"` is not an interpolation | The completion text of bash and zsh uses `\$` before `{`, and the profile line uses `\$PATH`. |
| `roc fmt` changes the indent of a block of `expect`s with spaces | The test file is formatted with `roc fmt`. |

## 11. Red output

`scripts/test.sh` with the stubs (2026-10-23). The old tests all pass.

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | The stubs compile. `roc fmt --check` passes. |
| L0 old files (59 files) | pass | |
| L0 `tests/unit/setup.roc` | red: 10 of 10 `expect`s fail | `Roc application crashed with this message: todo` |
| L2 old cases (60) | pass | |
| L2 `setup/st1-flow`, `setup/st2-copy-fallback` | red | `[ROC CRASHED] todo` (the test app writes no exit file) |
| L3 old cases (47, 1 skipped) | pass | |
| L3 `setup/st1-setup-real` | red | The first `tln setup` crashes with `[ROC CRASHED] todo`. The expected stdout, tree and stderr are missing. |
| L3 `fx/st1-real-fx-hard-link` | red | `[ROC CRASHED] todo` for the first `hardlink` call |
| selftest | pass | |

```text
tests/unit/setup.roc: FAILED   (10 failed: Roc application crashed with this message: todo)
FAIL setup/st1-flow           the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL setup/st2-copy-fallback  the test app wrote no exit file (exit 1): [ROC CRASHED] todo
FAIL fx/st1-real-fx-hard-link exit code differs (0 against 1), stderr has [ROC CRASHED] todo
FAIL setup/st1-setup-real     exit code differs (0 against 2), stdout stops after the first command line
```

Times on the stub tree: check 6.6 s, fmt 0.1 s, l0 6.7 s (60 files), l2 5.1 s, l3 9.5 s, selftest 3.8 s, no `WARN` line. With the reference: check 6.4 s, l0 6.9 s, l2 4.9 s, l3 9.4 s, selftest 3.7 s, exit 0, no `WARN` line.

## 12. Check against the design (TW21)

The expected files of the L2 cases, the L3 cases and the L0 rows were made by a private reference (`research/slice-027-revert/reference/`, kept until the manager says to delete it) and read by eye against the design. With the reference all 10 `expect`s of `setup.roc`, the 2 L2 cases and the 2 L3 cases pass.

| File | What was checked |
| --- | --- |
| `setup/st1-flow/expect/calls.log` | The order of the calls against the table of section 2. The reads come first, then the prompts (`tty`, `ask`), then the writes. The lock of `link-system` has `list_dirs` and the temp dir inside, and no `ask` call is between a `lock` and an `unlock` (the fake adds a `VIOLATION` line if it is). A run that changes nothing has no `make_dirs`, `random`, `rename` and `write_atomic`. |
| `setup/st1-flow/expect/tree.diff` | `.bashrc` gets the line after a line end. `link-system/.talon.json` has the path of `roc.old` and the time of `TALON_NOW`. No `.tmp` file is left (the tree diff leaves `*.tmp` out, so `calls.log` shows each `rename`). `roc.old` has the old text. |
| `setup/st1-flow/expect/stdout`, `stderr` | The texts of section 6. A run with a skipped entry has no "nothing to do" line. |
| `setup/st2-copy-fallback/expect/calls.log` | `hard_link` then `copy_file` to the same temp name, then `rename`. The second run has no write. |
| `setup/st1-setup-real/expect/stdout` | The inode checks, the proxy output of `roc +<id> version` (the same lines as the slice 023 case), the bash check of the completion, the note of R-ST2. |
| `fx/st1-real-fx-hard-link/expect/stdout` | The real `Path.hard_link!` gives `NotFound` for a missing parent dir of the target. |

## 13. Revert check (TW12)

Method: the private reference made all new tests pass. `research/slice-027-revert/mutate.py` applies one hand-made mutation at a time to the reference, runs only the layers that should catch it (the L0 file, the 2 L2 cases, the 2 L3 cases), and puts the file back. No full sweep. Result: 56 mutations, 56 caught. The first run caught 52 of 56. The 4 others were 3 wrong mutations and 1 test gap (M28, the tool order of the given `tools.json`: fixed in the given files of the L2 case and the L3 case). The table is in `research/slice-027-revert/results.md` (the first run is in `mutate-run.log`).

| Group | Mutations | Caught by |
| --- | --- | --- |
| `read`, `names`, `old_roc`, `bin_dir`, `judge` (the 3 `Foreign` cases, `Absent`, the source of `roc`, `.exe`, the dir) | M01 to M11, M53 | L0 (M01, M05, M07, M09, M11 also L2 or L3) |
| `on_path`, `shadow` (the order test, the bin dir not on `PATH`), `shell_of`, `profile`, `path_line` (the marker), `profile_edit`, `github_edit` | M12 to M20, M62 | L0 (M13, M15, M17, M18 also L2, L3) |
| `completion_path`, `completion` (3 texts), `windows_path` (the flags, the variable, `DoNotExpandEnvironmentNames`), `tool_names` | M21 to M28 | L0 (M21, M22, M28 also L2, L3) |
| `Setup.run!` steps: warnings (`foreign`, shadow), the distinct source hash, the flags and the answers of the prompts, `make_dirs`, the move of `roc`, the path of `link-system`, its keep, the hard link form, the copy fallback, the random temp name, the `PATH` step (`on_path`, `GITHUB_PATH`, the write), the completion write, the output (`moved`, the envelope, `roc_old`) | M30 to M52 | L2 and L3 (M31, M44, M45, M51, M52 only L2, M35, M41 only L3) |
| `Consent` (the 2 defaults, the answer line) | M55 to M57 | L2 and L3 |
| `RealFiles.hard_link!` (the `Exists` check) | M58 | L3 `fx/st1-real-fx-hard-link` |
| A missing `tools.json`, a missing dir | M64, M65 | L2 `st2` (M64), L3 (M65) |

Not mutated: the `NoSource` failure of `tln` (Q2) and the `roc.old` conflict (Q4): no test (questions). `RealFiles.hard_link!`: the missing source and the directory checks give the same result from `Path.hard_link!` (the case hides the text of `Other`, as in slice 024b M37).

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | The docs of `Setup`, `Fx.hard_link!`, `Consent.setup_replace_roc` and `Consent.setup_modify_path` have the contract. The L2 `calls.log` fixes the order of the calls. Section 6 has the texts. |
| N2 | The stub tree has `crash "todo"` in `Setup`, `Consent` (2 prompts) and `RealFiles.hard_link!`. `Run.roc` and `main.roc` are wired. `FakeFx`, `fxprobe` and the 4 test files are done (TW18: do not edit them). |
| N3 | `RealFiles.hard_link!` checks in this order: `from` missing (`NotFound`), `to` there (`Exists`), `from` is a directory (`Other("is a directory")`), then `Path.hard_link!` (a failure maps with `RealBase.file_err`). It makes no parent dir. |
| N4 | A function must not have the name of a method of its type module (slice 020 limit). The reference has the private helpers `flow!`, `apply!`, `make_entry!`, `link_system!`, `path_plan!`, `completion_plan!`, `judged!`, `tools!`, `listings!`, `warn_entries!`, `read_text!`, `report`, `data`, `print!`. |
| N5 | Reuse `Clock.now!`, `Fx.locked!`, `Launch.toolchains!`, `Link.meta`, `Temp`, `Common.shown_fx`, `Common.failed!`, `Prompt.ask!`, `Mode.from_env`, `TalonFile.open`. `Prompt.ask!` gives the answer line (R-NM6) and the mode for the next prompt. |
| N6 | The completion texts of section 6 are compared byte for byte (tab indents). `Setup.completion` must give them. |
| N7 | `Setup.windows_path`: the L0 row checks the properties only. The script must read `GetValue('Path', '', 'DoNotExpandEnvironmentNames')`, write `ExpandString` and send `WM_SETTINGCHANGE`, and must not use `setx` or the dir. |
| N8 | The Windows flow of `Setup.run!` is not tested. The code agent writes it from the pure parts (`names`, `bin_dir`, `old_roc`, `windows_path`) and `spawn_all!` (one job, limit 1), and says in the result that it ran on no Windows machine. |
| N9 | Do not edit a test (TW18). A question goes to the manager. |

## Review (manager, 2026-10-23)

| Item | Result |
| --- | --- |
| Split | No split. The slice stays one slice. |
| D1 to D15 | Accepted |
| Section 6 proposals (texts, `data` fields, prompts, completion texts) | Accepted |
| Q1 (the form of `tools.json`) | The default is accepted, but it is provisional. Slice 046 confirms the form. |
| Q2 (exit 18), Q3, Q4 (exit 17), Q5, Q6, Q8 | The defaults are accepted |
| Q7 (R-ST9 against R-ST11) | A real conflict. It goes to the user. The repair stays untested, and the code follows R-ST11 as written (the tests pin that). |
| Private reference | Deleted (`research/slice-027-revert/reference/`). `mutate.py` can not run again without it. |

## Code result (code agent)

Result of `scripts/test.sh`: exit 0, no WARN line. check 6.7 s, fmt 0.1 s, l0 7.0 s (60 files, `setup.roc` 10 of 10 `expect`s), l2 62 cases passed in 4.9 s, l3 49 cases passed and 1 skipped in 9.4 s, selftest 3.7 s. `OPT=speed scripts/test.sh`: exit 0 (l2 76.8 s). `roc check`: 0 errors, 0 warnings. `MISSING=1 scripts/rules.sh R-CM R-ST R-NI R-HF R-LY` lists, for the ids of this slice, only R-ST10 (slice 050).

| File | Lines | Change |
| --- | --- | --- |
| `cli/lib/Setup.roc` | 559 | The 17 pure functions, `run!`, and the steps as private functions: `flow!`, `gather!`, `judged!`, `warn!`, `path_step!`, `completion_step!`, `ask!`, `write_entries!`, `move_roc!`, `link_item!`, `make_entry!`, `write_path!`, `print!`, `act_of` |
| `cli/lib/SetupText.roc` | 225 | New (split, see below). The 3 completion texts, the PowerShell script, `report`, `data`, the types `Done`, `Act`, `Form`, `PathResult`, `Completion`, and the pure helpers `strip_end`, `clean_part`, `parts_of`, `appended`, `var_of` |
| `cli/lib/SetupIo.roc` | 67 | New (split). `read_text!`, `listings!` (with `entries_of`), `have_of!`, `write_file!`, `dropped!` |
| `cli/lib/Consent.roc` | 352 | `setup_replace_roc`, `setup_modify_path` |
| `cli/RealFiles.roc` | 305 | `hard_link!`: `NotFound`, `Exists`, `Other("is a directory")`, then `Path.hard_link!` (a failure maps with `copy_err`) |
| `cli/lib/main.roc` | | `SetupText` and `SetupIo` in the exposes list |

Split: `Setup.roc` with the stub docs and all steps was 642 lines. The text builders and the file helpers that need no `Setup` function moved out (a module that `Setup` imports cannot import `Setup`, so the steps stay in `Setup`). No module is over 600 lines. Reused: `Prompt.ask!`, `Mode.from_env`, `Common.shown_fx`, `Common.failed!`, `Out.json_ok`, `Clock.now!`, `Fx.locked!`, `Launch.toolchains!`, `Link.meta`, `Temp.hex`, `Temp.name`, `TalonFile.open`, `Roots`, `Fx.copy_file!`, `Fx.sha256_file!`. No code is copied.

Decisions that the slice does not fix:

| Decision | Chosen | Rejected |
| --- | --- | --- |
| The Windows `Path` child | `Fx.exec!` with the `env` of `Setup.windows_path` | `spawn_all!` (note N8): its job has no `env`, so `TALON_BIN_DIR` cannot be set |
| The Windows flow of `Setup.run!` | Names with `.exe`, `<USERPROFILE>\.local\bin`, no shadow test, no `PATH` split test, no completion. The `PATH` step is always pending: the prompt of R-NI14 with the target `the user Path`, then the child (`Add`). It ran on no Windows machine and no test shows it. | A stop with an error text |
| Step 5 for an entry with no source | An entry that the `<bin>` listing has as a file is hashed also when its source is missing (the call table says "each entry that the listing has as a file") | Skip the hash (the verdict is `NoSource` in any case) |
| A source that is a directory in `<data bin>` | It is not a source (`Missing`) | A failure |
| A `sha256_file!` error of a source other than `NotFound`, a `list_dirs!` error other than `NotFound`, a `read_files!` error other than `NotFound`, a failed write or rename | Kind `Environment` (exit 18) with the path and the error | Treat it as missing |
| The profile marker test | The marker is anywhere in the old text (`text.contains`) | The marker at the end of a line only |
| "nothing to do" | No stdout line and no skipped entry. A declined `roc` counts as skipped (L3 part 4 has no line). A `PATH` line that is printed (declined, unknown shell) is a line. | Only "nothing was written" |
| The line for a declined `GITHUB_PATH` | `PATH: not changed. To add <bin>, put this line in <file>: <bin>` (the plain dir, the form of that file) | The profile line of a shell |
| Failure of a temp file | `delete!` of the temp file or dir, then the failure (as `RocLink`) | Leave it for GC |
| Mode of the second prompt | The `mode` that the first prompt gave back, so `tty!` runs once (R-HF1) | A fresh mode |

Disputes (from the code agent): none. No test, fixture or expected file was changed.

Questions (TW17): none new. Q7 (R-ST9 against R-ST11): the code follows R-ST11 as written, with no repair. Not built, as the review says: the Windows `run!` flow is tested by no case (section 8), `Q2` (a missing `<data bin>/tln`, exit 18) and `Q4` (`roc.old` exists, exit 17) are in the code with the texts of the section 9 table and have no test. Compiler limits met: a local variable that has the name of a method of its type module (`completion`) is a duplicate definition, and a regex rename of `var_of` also hit a local with that name (my slip, found by `roc check`).

## Verify results (revert check, TW12)

`research/slice-027-revert/agent-mutate.py` puts `code-final/` back before each change, makes one change, runs `roc check`, then only the layers that should catch it (`agent-results.md`; each run has a timeout of 300 s). Result: caught 35 of 39 (A08 only by l0: the L2 and L3 layers that I listed for it cannot catch it, see below). The 4 others: 1 equal change (A36), 2 rules that the slice leaves untested (A37, A38) and 1 test gap (A39). The files in `cli/` equal `code-final/` after the run (`filecmp`, no difference). The test agent files `mutate.py`, `results.md` and `mutate-run.log` were not changed.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `read`, `names`, `bin_dir`, `judge` | A01 to A07 (the operand count, the `talon` name, the source of `roc`, the `bin` path, the 3 `judge` branches) | l0 (A01, A03, A04, A05, A07 also by l2, A03, A04, A05, A07 by l3) |
| `shadow`, `shell_of`, `path_line`, `profile_edit`, completion text | A08 to A12 | l0 (A09 to A12 also by l2 and l3) |
| `tool_names` | A13 (the `format` limit) | l0 |
| Warnings, hashes, prompts | A14 (a warning for `roc`), A15 (a source hashed twice), A16 to A18 (the 2 flags and `--yes`) | l2 (A14, A16, A17 also l3), A18 l3 only |
| Writes | A19 (`make_dirs`), A20 (the move of `roc`), A21 (the path of `link-system`), A22 (an existing `link-system`), A23 (the hard link form), A24 (the copy target), A25 (the random temp name) | l2 and l3 (A19, A24, A25 l2 only, A22 l3 only) |
| `PATH` and completion steps, output | A26 to A32 (the `PATH` test, `GITHUB_PATH`, the write, the completion compare, `moved`, the envelope stream, `roc_old`) | l2 (A26 to A30 also l3) |
| `Consent` | A33 to A35 (the 2 defaults, the answer line) | l2 and l3 |
| `RealFiles.hard_link!` | A36 (the `Exists` check) | not caught, see below |

Mutations that no test caught:

| Id | Change | Class | What a test needs |
| --- | --- | --- | --- |
| A08 | `shadow` counts the bin dir part itself (`len: at + 1`) | Not a gap. l0 catches it (row "the roc in the bin dir is no shadow"). My layers (`l0 l2 l3`) were wrong: the fake `path_roc` of the L2 and L3 cases has no `roc` in the bin dir. | none |
| A36 | `RealFiles.hard_link!` has no `Exists` check | Equal change: `Path.hard_link!` gives `AlreadyExists`, and `copy_err` maps it to `Exists`. The explicit check only saves the call. | none |
| A37 | The conflict of Q4 (`roc.old` exists, answer Yes) never fires | Untested rule (question Q4, "not tested" in section 8) | A case with a `roc.old` and `--replace-roc`: exit 17, no change |
| A38 | A missing `tln` file (Q2) is not a failure | Untested rule (question Q2) | A case with no `<data bin>/tln`: exit 18 |
| A39 | The second prompt uses a new `mode`, so `tty!` runs twice when both prompts are asked in a terminal | Test gap (R-HF1: one `tty!` call in a command) | An L2 run with a foreign `roc`, a profile without the line, `CI=false`, and no flag: calls.log has one `tty` |

The Windows flow and the PowerShell script were not run (no Windows machine here): the Windows CI job must run them (TESTING.md 5).

## Gap rows (test agent)

Tests only, no change in `cli/`. The mutations are the ones of `agent-mutate.py` (A37, A38, A39). Each was applied by hand to `cli/lib/Setup.roc`, the cases `setup/` were run, the new case failed, and the file was put back (`cmp` against `code-final/`: same). The accepted defaults of Q2 and Q4 are now pinned.

| Gap | New test | Mutation | Result |
| --- | --- | --- | --- |
| A37 (Q4) | L2 `setup/st3-gaps` run 1: foreign `roc`, `roc.old` exists, `--replace-roc`. Exit 17, the text names `roc.old` and `--replace-roc`. `calls.log` has reads only, and the case tree has no change. | the conflict test uses another name | `st3-gaps` fails |
| A38 (Q2) | L2 `setup/st4-no-tln` (1 run): no `<data bin>/tln`. Exit 18, `<data bin>/tln is missing. Install Talon with its install script.` Calls stop after `list_dirs`. | `NoSource` of the first entry is not a failure | `st4-no-tln` fails |
| A39 (R-HF1) | L2 `setup/st3-gaps` run 2: a terminal, no flag, a foreign `roc`, a profile with no line. Both prompts are asked (answers n, y). `calls.log` has one `tty`. | the second prompt gets the first `mode` of the run, not the mode that the first prompt gave back | `st3-gaps` fails |

Section 8 no longer lists Q2 and Q4 as not tested.

## Close (manager, 2026-10-23)

The code agent decisions are accepted (the split into SetupText and SetupIo, the minimal Windows flow, which the Windows CI job will be the first to run). A37, A38 and A39 are caught by the gap cases; A36 is equivalent. Q7 is open with the user (PLAN-P1.md section 6, U1). `scripts/test.sh` exits 0 with no WARN. Status: done.
