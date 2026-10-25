# 042 `tln patch`

Phase: P1. Status: done

Slice 042 is the plan row 042 of `PLAN-P1.md`. It needs 023 (done). `tln patch <alias>` copies a cached package to `.talon/patches/<alias>/` and writes a `[patch]` entry. `tln patch <alias> --diff` prints the unified diff of the copy against the base package. The unified diff and its apply are pure (`Diff`, an L1 round trip). `list` shows the mark `patched`.

The private reference has about 630 lines of code without comments and empty lines: `Diff` 318, `PatchCmd` 110, `PatchFlow` 199, and 59 lines in `Intent`, `IntentEdit`, `Listing`, `Ls` (and the wiring in `Run`, `main`). The row said 400. No module is over 450 lines (`Diff` has 359 lines with its comments), so no split is needed. The 3 new modules keep the three jobs apart: `Diff` (text), `PatchCmd` (decisions and output), `PatchFlow` (calls).

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-CM10 | `tln patch <alias> [--diff]` | L0 `removal.roc` expect `patch_line` (10 rows). L2 `pa1-flow` all runs |
| R-PA1 | The copy of `packages/<hash>/` goes to `<dir of talon.toml>/.talon/patches/<alias>/`. The `[patch]` entry is written. A new `talon.toml` is made when there is none. The dir exists: exit 2 | L0 `removal.roc` expect `place` (rows `place`, `exists`, `created`), `intent.roc` expect `add_patch`. L2 runs 1, 2, 7, 8, 12 |
| R-PA2 | No `--commit`, no diff file | L0 `removal.roc` `patch_line` rows (`--commit`, `--dry-run` fail in `Args.parse`). L2 runs 1, 7, 8 (`tree.diff`: no other file than the copy and `talon.toml`) |
| R-PA3 | `--diff` prints the diff of the copy against `packages/<base>/` and writes nothing | L0 `removal.roc` (`shown`, `copy_dir`), `diff.roc`. L2 runs 9, 10, 11 (`calls.log` has no `write_atomic` and no `copy_tree`; `tree.diff` is empty for them) |
| R-PA7 | The unified diff: 3 lines of context, file by file. `make` and `apply` are pure. A hunk applies when its context and old lines match exactly at one place, at any offset, no fuzz. Added and deleted files. A file that is not UTF-8 text is replaced whole and applies only when the target has the bytes of the base | L0 `diff.roc` expects 1, 2, 3. L1 `tests/fuzz/diff.roc`. L2 run 10 |
| R-PA8 | A platform entry: exit 2 | L0 `removal.roc` expect `entry`. L2 run 3. Mutation P9 |
| R-PA9 | The `[patch]` entry is `json = { path = "./.talon/patches/json/main.roc", base = "<hash>" }` | L0 `intent.roc` expect `add_patch`, `removal.roc` `place`. L2 runs 1, 7, 8, 12 (`tree.diff`). Mutation P12 |
| R-PA11 | The copy is a normal dir of the project (it is in VCS) | L2 `tree.diff` of runs 1, 7, 8, 12: the copy is a plain tree next to `talon.toml` |
| R-PA12 | `talon.toml` has the entry. The `[patch]` table is read | L0 `intent.roc` expect `Intent.read` of `[patch]`. L2 run 6, 10 |
| R-PA13 | The package is fetched by hash when it is not in the cache | L2 run 7 (`parser` is not in the cache: the fake fetch puts it there) |
| R-PA14 | An entry that Talon does not manage (a path entry, a foreign URL): exit 2 | L0 `removal.roc` expect `entry`. L2 runs 4, 5. Mutation P10 |
| R-CM9 (`patched`) | `list` marks a patched entry: flat list, tree, `--json` | L0 `listing.roc` expect `patched`. L2 run 6. L3 `list/ls1-list` (the key `patched` in `--json`). Mutation P13 |
| R-EC2 | A refusal or a bad line is exit 2 | L0 `removal.roc`. L2 runs 2 to 5. Mutation P10 |
| R-SC1, R-SC6 to R-SC8, R-SC16 | The name of the entry: alias, full name, short name, `@sel`. Only header entries | L0 `removal.roc` expect `entry` (11 rows) |
| R-OUT2, R-OUT4 | Output text and `data` (proposals, TW24) | Section 5 |

## 2. Public signatures (stubs in `cli/lib/`, `crash "todo: slice 042"`)

| Name | Signature | File |
| --- | --- | --- |
| `Diff.Content` | `[Utf8(Str), Binary(Str)]` (`Binary` holds the sha256) | `cli/lib/Diff.roc` |
| `Diff.File` | `{ path : Str, content : Diff.Content }` | same |
| `Diff.Line`, `Diff.Hunk` | `[Keep(Str), Del(Str), Ins(Str)]`, `{ old_start, old_len, new_start, new_len, lines }` (all `U64` and `List(Diff.Line)`) | same |
| `Diff.Change` | `[Edit({ path, hunks }), Add(File), Delete(File), Replace({ path, base, copy })]` | same |
| `Diff.Applied` | `{ path : Str, what : [Write(Str), FromCopy, Remove] }` | same |
| `Diff.make` | `{ base : List(Diff.File), copy : List(Diff.File) } -> List(Diff.Change)` | same |
| `Diff.render` | `List(Diff.Change) -> Str` | same |
| `Diff.apply` | `{ changes : List(Diff.Change), target : List(Diff.File) } -> { done : List(Diff.Applied), failed : List(Str) }` | same |
| `PatchCmd.Target` | `{ alias, name, version, url, hash }` (all `Str`) | `cli/lib/PatchCmd.roc` |
| `PatchCmd.read` | `Args -> Try({ name : Str, diff : Bool }, Fail)` | same |
| `PatchCmd.entry` | `{ text : Str, rows : List(Locked.Row) } -> Try(PatchCmd.Target, { fail : Fail, block : Str })` | same |
| `PatchCmd.place` | `{ toml : Str, alias : Str } -> { dir : Str, entry_path : Str }` | same |
| `PatchCmd.copy_dir` | `{ toml : Str, path : Str } -> Str` | same |
| `PatchCmd.exists` | `Str -> Fail` | same |
| `PatchCmd.created` | `{ target, dir, toml, toml_created } -> { text : Str, data : JsonDoc }` | same |
| `PatchCmd.shown` | `{ alias, base, dir, changes } -> { text : Str, note : Str, data : JsonDoc }` | same |
| `PatchFlow.run!` | `Fx, Args => I32` | `cli/lib/PatchFlow.roc` |
| `IntentEdit.add_patch` | `{ path, text, alias, entry, base } -> Try(Str, Fail)` | `cli/lib/IntentEdit.roc` |
| `Intent.PatchEntry`, field `Intent.patches` | `{ key, path, base }`, `List(PatchEntry)` (new field of the `Intent` record; the stub gives `[]`) | `cli/lib/Intent.roc` |
| `Listing.text`, `tree`, `data` | each record has a new field `patched : List(Str)` (the keys of the `[patch]` table of the member). The stub ignores it | `cli/lib/Listing.roc` |
| `Ls.run!` | the stub gives `patched: []`. The code agent gives each member the keys of its `[patch]` table | `cli/lib/Ls.roc` |

Wired already (the code agent leaves them): `Run.roc` calls `PatchFlow.run!` for the command `patch`. `main.roc` has `Diff`, `PatchCmd`, `PatchFlow` in its module list. `Args.roc` is not changed (`--diff` is accepted for `patch`, `--commit` is refused). The doc of each stub is the contract (rule tables in `Diff`, refusal texts in `PatchCmd`, a step table in `PatchFlow`).

## 3. The tested reading (the rules of the command)

| # | Rule | Source |
| --- | --- | --- |
| 1 | `patch` takes one name, and `--diff`. No name or 2 names: exit 2. The name is read as `why` and `remove` read it (alias, full name, short name, `@sel`) in the scope of the project | R-CM10, R-SC1 |
| 2 | The platform, a path entry and a foreign URL are refused (exit 2, nothing written, no fetch) | R-PA8, R-PA14 |
| 3 | The copy dir exists: exit 2, one `list_dirs` call after the load, nothing else | R-PA1 |
| 4 | The copy: fetch by hash, `copy_tree` of the package, one `write_atomic` of `talon.toml`. The entry is an inline table, `path` first, then `base` (R-PA9). The first entry of a new file: `[patch]` and the entry. Other bytes of `talon.toml` stay | R-PA1, R-PA9, R-H1 |
| 5 | `--diff`: the 2 trees are read, `Diff.make`, the text is stdout and nothing else. No change: stdout empty, a note on stderr, exit 0 | R-PA3 |
| 6 | The diff: 3 lines of context; 6 kept lines or fewer between 2 runs of changes make one hunk; the script is the shortest; deleted lines of a run come before the inserted ones | R-PA7 |
| 7 | `apply`: a hunk applies at any offset when its old side is in the text exactly. A file with one failed hunk is not written, and all failed files are listed | R-PA7 |
| 8 | `list`: the mark `patched` is the last mark of a direct row whose alias is a key of the `[patch]` table of the member | R-CM9 |

## 4. Tests

| Layer | File and case | Content | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/diff.roc` expect 1 (15 rows) | The diff of one text: context, an add at the top, a final line end added or removed, no final line end on both sides, one line with no line end, an empty file that gets lines, becomes empty, gets one line with no line end, 6 and 7 kept lines between changes, a change of the last line, a run of 2 changes, same texts | R-PA7 R-PA3 |
| L0 | same, expect 2 (4 checks) | The files of a diff: byte order of the paths, add, delete, edit, a binary file (`Binary files ... differ`), no change, an empty file added or deleted (no hunk) | R-PA7 R-PA3 |
| L0 | same, expect 3 (29 rows) | `apply`: round trips, moved hunks (offsets), a changed line that no hunk touches stays, a changed context or old line fails with no partial write, line-end mismatches, the kinds `Write`, `FromCopy`, `Remove`, an edit of a missing or binary target, 2 files with one failure, the empty diff, a hunk at 2 places (the nearest, a tie takes the first: Q2), `Add` on a path that exists and `Delete` on a missing path, on other text, on other bytes (Q4) | R-PA7 R-PA5 |
| L0 | `tests/unit/removal.roc` expect `patch_line` (10 rows) | `PatchCmd.read`: one name, `--diff`, no name, 2 names, `--commit`, `--dry-run`, `--registry`, `--diff` on `list` | R-CM10 R-PA2 R-PA3 R-FL5 R-EC2 |
| L0 | same, expect `entry` (11 rows) | `PatchCmd.entry`: alias, full name, short name, selectors, the platform by alias and by full name, a path entry, a foreign URL, a name that is not in the header, a selector that no entry satisfies | R-PA8 R-PA14 R-SC1 R-SC6 R-SC7 R-SC8 R-SC16 R-PA9 |
| L0 | same, expect `place` (15 rows) | `place`, `copy_dir`, `exists`, `created` (also with a new file), `shown` (text, note, `data`) | R-PA1 R-PA9 R-PA11 R-PA12 R-PA3 R-OUT2 R-OUT4 |
| L0 | `tests/unit/intent.roc` expect `[patch]` (5 rows) | `Intent.read` of the table: the order of the lines, a member role, none, empty, an entry that is not an inline table with a string `path` and `base` is not read | R-PA12 R-PA9 R-CM9 |
| L0 | same, expect `add_patch` (7 rows) | the edit: new file, a key that is in the table already (replaced, Q3), a table at the end after a blank line, the entry in an existing table, comments stay, a text with no final line end, not TOML | R-PA1 R-PA9 R-PA12 R-H1 |
| L0 | `tests/unit/listing.roc` expect `patched` (new) and the old expect (changed) | the mark in the flat list, the tree, `--json`; a key that no row has; a package that no header names; `object_of` has no `patched` | R-CM9 R-PA12 R-OUT2 |
| L1 | `tests/fuzz/diff.roc` (`# l1-runs: 20000`) | A random text and a random edit (keep, delete, replace, insert after, swap, lines at the top, final line ends): `apply(make(a, b))` gives `b`; same texts give no change; numbers and counts of hunks; 3 lines of context; no 2 hunks that could be one; deleted lines before inserted lines; the script is the shortest (an own LCS oracle) | R-PA7 |
| L2 | `patch/pa1-flow` run 1 | `patch json`, no `talon.toml`: the copy, a new `talon.toml` with `[patch]` and the entry | R-PA1 R-PA9 R-PA11 R-PA12 R-CM10 |
| L2 | same, run 2 | the same again: the copy dir exists, exit 2, no change | R-PA1 R-EC2 |
| L2 | same, runs 3 to 5 | the platform, a path entry, a foreign URL: exit 2 | R-PA8 R-PA14 R-EC2 |
| L2 | same, run 6 | `list`: the mark `patched` on `json` | R-CM9 |
| L2 | same, runs 7, 8 | a package that is not in the cache (fetch by hash); a `talon.toml` with comments keeps its text; the second key in the same table | R-PA1 R-PA9 R-PA13 |
| L2 | same, run 9 | `--diff` with no change: stdout empty, the note on stderr, exit 0, no write | R-PA3 |
| L2 | same, runs 10, 11 | `--diff` on a copy with many edits (text, `--json`): the diff text, the `data` | R-PA3 R-PA7 R-OUT4 |
| L2 | same, run 12 | `--json` of the copy into a `talon.toml` that exists | R-PA1 R-PA9 R-OUT4 |
| L2 | same, run 13 | `--diff` on an entry with no `[patch]` key: exit 2 (Q1) | R-PA3 R-EC2 |
| L2 | same, run 14 | `--diff` on an entry whose copy dir is missing: exit 2 (Q1) | R-PA3 R-EC2 |
| L3 | `list/ls1-list` (changed) | `list --json` has the key `patched` (false) for each package | R-CM9 |

Deep case: one (`pa1-flow`, 14 runs). The world is `research/slice-042-revert/gen-pa.py` (`acme/json 2.1.0`, `acme/parser 1.0.0`; the files of the json package have text, empty, no final line end, binary and nested dirs). L3: no new scenario (the fake fetch is the one of the other L2 cases, and the real `Fx` calls are the ones of `install` and `list`). L0: 1 new file (187 lines, 0.4 s) and 9 new expects in 3 old files. L1: 1 target (224 lines, builds in 2 s, 20000 runs in 0.8 s).

## 5. Output proposals (TW24, for the human review)

| Output | Text | In the test |
| --- | --- | --- |
| `patch` lines | `copied: <dir> (<name> <version>)`, `<toml>: + [patch] <alias>` (` (new file)` when `talon.toml` is new), `edit the copy, then commit it and talon.toml. Review it with: tln patch <alias> --diff` | runs 1, 7, 8, 12 |
| `patch --json` data | `alias`, `name`, `version`, `base`, `dir`, `toml`, `toml_created` (in this order) | run 12 |
| `--diff` stdout | the unified diff only (so `patch -p1` can read it): `--- a/<path>`, `+++ b/<path>`, `@@ -<s>,<n> +<s>,<n> @@` (the count is always written), `\ No newline at end of file` after a line with no line end, `/dev/null` for a missing side, `Binary files a/<path> and b/<path> differ` | run 10 |
| `--diff` no change | stdout empty, stderr `<alias>: no changes against <base>`, exit 0 | run 9 |
| `--diff --json` data | `alias`, `base`, `dir`, `changes` (a list of `{ path, change }` with `change` one of `modified`, `added`, `deleted`, `replaced`), `diff` (the text) | run 11 |
| Platform | `<alias> is the platform of the app. tln patch does not copy a platform: its archive holds host binaries. Use a fork and its release, or a path entry.` | run 3, L0 |
| Path entry | `<alias> is a path entry. It is local code: edit its file.` | run 4, L0 |
| Foreign URL | `<alias> is a foreign URL. It has no release, so tln patch cannot copy it.` | run 5, L0 |
| Copy dir exists | `<dir> exists already. Edit the copy, or remove it to start again.` | run 2, L0 |
| No name, 2 names | `tln patch takes one name` | L0 |
| Name not found | `'<x>' is not in the project` | L0 |
| `list` mark | `patched`, the last mark (`direct; patched`); `--json`: the last key `patched` of a package (true or false) | run 6, L0, L3 |

## 6. Decisions that the design does not fix (D, for the review)

| Id | Decision | Rejected |
| --- | --- | --- |
| D1 | A line carries its own `\n`. The last line of a text with no final `\n` has no `\n`, so a change of the final line end changes the last line. `\ No newline at end of file` follows such a line | a flag of the file (a second state to apply), a line without `\n` and a flag for the text |
| D2 | The side of a hunk that has no line has the number of the line before it (`0` at the top), as `diff -u` does. The count is always written (`-1,1`, not `-1`) | the number `1` for an empty side; a count that is dropped when it is 1 (2 forms to parse) |
| D3 | The script is the shortest (an LCS). In a run of changed lines all deleted lines come before the inserted ones | the greedy script of a plain diff (a longer diff for some inputs), mixed order |
| D4 | 6 kept lines or fewer between 2 runs of changes make one hunk (2 times the context, as `diff -u`) | no merge |
| D5 | The headers are the ones of `diff -u` with `a/` and `b/`, `/dev/null` for a missing side. A binary change is one line `Binary files ... differ` | headers with no prefix; a header that names the alias |
| D6 | `apply` never stops at the first failure and never writes a file with a failed hunk. `failed` lists all files in the order of the changes | stop at the first failure; a partial write |
| D7 | `--diff` reads only. When there is no change, stdout is empty and stderr has a note | no note; a message on stdout |
| D8 | `patched` is a mark of a direct row whose alias is a key of the `[patch]` table of the member. The `--json` key is always there (true or false), as `foreign` is | the key only when it is true (the old outputs stay, but the schema has 2 shapes) |
| D9 | The `[patch]` entry is an inline table (R-PA9). The first entry of an empty file gives `[patch]` and the entry, not `[patch.json]` | the form `[patch.json]` |
| D10 | `Intent.patches` reads inline tables with a string `path` and a string `base` only (question Q5) | a failure for another form |
| D11 | A file that `read_files` cannot read as text is `Binary(sha256)`, the hash comes from `sha256_file` | read the bytes (no `Fx` call gives bytes) |

## 7. Out of scope, questions (TW17)

| Id | Item | Reason |
| --- | --- | --- |
| Out 1 | R-PA4 (a patched entry is an anchor) | Slice 043 |
| Out 2 | R-PA5 (the diff applied to a new release), R-PA6, R-PA10, R-PX5, and the proxy and `install` use of the copy | Slice 043. `Diff.apply` is tested here, because it is pure |
| Out 3 | R-PA14, the held part (an entry that is patched and held) | Slice 043 (it needs R-PA4) |
| Out 4 | R-PA2, no `--commit` at the command level | `Args.parse` refuses it (L0 `patch_line` rows). The command does not see it |
| Out 5 | R-PA13 in the case that the fetch fails (offline, no net) | The fetch is the code of `install` (tested there) |
| Out 6 | A failure of the file system (a failed copy, a failed write) | No fake fails `copy_tree!` or `write_atomic!` for it (question Q7) |
| Out 8 | Q6: `--diff` when the `base` of the entry is not the hash of the header entry (a stale patch) | Slice 043 (the reference fetches the package of the header entry only when it is the base) |
| Out 7 | A tie of names (R-SC14: `"<name>" matches <n> packages. Use a name from the list.`) | No row: the code is `Lookup.find`, tested in slice 023. The text of the stub doc is the same |

| Id | Question | Options (tested reading first) |
| --- | --- | --- |
| Q1 | Answered (review): exit 2 for both (runs 13, 14). Question: `--diff` on an entry that has no `[patch]` key, or whose copy dir is missing. The design does not say | (a) exit 2 `<alias> has no patch. Run tln patch <alias> first.` (the reference: no test), (b) the diff of an empty copy (every file deleted), (c) exit 18 |
| Q2 | Answered (review): the nearest place wins, a tie takes the first (`diff.roc`). Question: A hunk that fits at 2 places or more in `apply`. R-PA7 says "at one place" and does not say what happens at 2 | (a) the place nearest to `old_start` wins (the reference: no test), (b) the file fails, (c) the first place wins |
| Q3 | Answered (review): `add_patch` replaces the entry (`intent.roc`). Question: `add_patch` when the key is in `[patch]` already. The copy dir check does not see an entry with no dir | (a) failure kind `Usage` (no test), (b) replace the entry, (c) 2 keys (not TOML) |
| Q4 | Answered (review): the change fails for that file, it is in `failed` (`diff.roc`). Question: `apply` of `Add` on a path that the target has, of `Delete` on a path that the target does not have or has with other content | (a) the change fails and is in `failed` (the reference: no test), (b) `Add` overwrites, `Delete` removes whatever is there |
| Q5 | Answered (review): as tested. Question: A `[patch]` entry that is not an inline table with a string `path` and a string `base` (for example `[patch.json]`, a string value) | (a) not read: no mark, no failure (the reference, tested in `intent.roc`), (b) a failure of kind `Input` |
| Q6 | Answered (review): out of scope, slice 043 (stale patch). Question: `--diff` when the `base` of the entry is not the hash of the header entry now (the header moved after the patch). The base package may not be in the cache | (a) the cache must have `packages/<base>/`, else the fetch by the hash of the `base` (the reference fetches only when the base is the hash of the header entry), (b) always the fetch by hash |
| Q7 | Answered (review): kind `Environment` as in other commands, no test. Question: A failure of the file system in `patch` (copy, write, read) | exit 11 `Environment` (the reference: no test) |

Design gaps (for the human, no design file is changed here):

| Gap | Where |
| --- | --- |
| R-PA7 says "a hunk applies when the context and old lines match exactly at one place" and does not say what happens at 2 places, and does not say what `apply` does with a file-level conflict (Q2, Q4) | Resolution R-PA7 |
| R-PA3 does not say what `--diff` does with no `[patch]` entry or no copy dir (Q1) | Resolution R-PA3 |
| R-PA9 shows one entry. It does not say what the file looks like when the table exists as `[patch.json]` (Q5) | Resolution R-PA9 |
| R-CM9 names the mark `patched` and does not say that an indirect package is never patched (D8) | CLI R-CM9 |

## 8. Compiler and tool limits met (for the manager and the code agent)

| Id | Limit | Effect | Workaround |
| --- | --- | --- | --- |
| C1 | `var $x : I64 = 0` is a parse error | the reference of `Diff.apply_hunks` | `var $shift = 0.I64` |
| C2 | `Dec` defaulting is a warning, and a warning fails `roc check` (exit 2) | the L1 target | write the type of a number (`0.U64`) |
| C3 | `keep_oks(...).first()` crashed the app | the first version of the reference | a nested `match` |
| C4 | `roc test` segfaults when an `Err` record has a `Bool` field | the first form of `PatchCmd.entry` | a record with a `Str` field only |
| C5 | A record parameter does not take a wider record | the wiring of `Listing` | build the record at the call |
| C6 | `U64` has no `to_i64`: use `to_i64_wrap` | the hunk offsets | `to_i64_wrap` |

## 9. Notes for the code agent

| Topic | Note (the reference was not seen by you: these notes describe it) |
| --- | --- |
| Tests | Do not edit a test (TW18). `tests/commands/cases/patch/pa1-flow/rules` has the text of each run. `research/slice-042-revert/gen-pa.py` made the case (do not run it) |
| `Diff.make` | Lines of both texts, the common start and end are cut, an LCS table does the middle. The hunks follow section 3 rule 6 |
| `Diff.apply` | One `Edit` is applied hunk by hunk from the top: the old side is searched from the end of the last hunk, the place nearest to `old_start` plus the shift of the hunks before wins (Q2). The text is written only when all hunks fit |
| `PatchFlow.run!` | The step table in the doc of the stub. `calls.log` of `pa1-flow` is the order. `Common.shown_fx`, `Install.begin!`, `Known.record!`, `Ls.request_of`, `ResolveLoad.load!`, `Fetch.packages!`, `IntentEdit.add_patch` |
| `Ls` | `walk_full!` gives the `Loaded` of each member: the keys of its `[patch]` table (`Intent.patches`) are the `patched` list of `Listing` |
| `Intent` | `read_tables` reads `[patch]` into `patches` (inline tables only) |
| Size | About 630 lines of code (`Diff` about 320, `PatchCmd` about 110, `PatchFlow` about 200) and about 60 lines in the 4 old modules |

## 10. Changed old tests (TW21)

Copies before are in `research/slice-042-revert/before/`. `NEW.txt` lists the new files.

| File | Change | Reason |
| --- | --- | --- |
| `tests/unit/listing.roc` | the old calls of `Listing.text`, `tree`, `data` have `patched: []`. The old expect of the package JSON has `"patched":false` | R-CM9 (`patched`): the record has a field and the JSON has a key. The old expect fails in the red state |
| `tests/scenarios/list/ls1-list/expect/stdout` | `"patched":false` is added at the end of each package object of `list --json` (9 objects) | the same. The other lines are not changed (checked with a diff of the 2 files). Red in the red state, green with the reference |
| `tests/unit/intent.roc`, `tests/unit/removal.roc` | new expects and imports only | |

No other old expected file changes. `why` does not show `patched` (`object_of`).

## 11. Red run, green run, revert check

| Run | Result |
| --- | --- |
| Reference (`research/slice-042-revert/reference-run.log`, after the review) | all pass: check 1.2, fmt 0.2, l0 10.7 (6.6 s on a warm cache; `diff.roc` takes 0.4 s, the rows are in existing expects), l2 3.0, l3 9.9, selftest 11.7, l1 36.7 |
| Red, with the stubs (`red-run.log`) | check, fmt, selftest pass. l0 FAIL: `diff.roc` 3 of 3 expects crash `todo: slice 042`, `removal.roc` 3 of 7 fail, `intent.roc` 2 of 11 fail, `listing.roc` 2 of 5 fail (the `add_patch` expect fails on the stub) (the old expect: no key `patched`; the new expect). l2 FAIL: `patch/pa1-flow` (the test app crashes with `todo: slice 042`; 14 runs); 102 other cases pass. l3 FAIL: `list/ls1-list` only (the key `patched`); 62 pass. l1 FAIL: `tests/fuzz/diff.roc` (`todo: slice 042`); the other targets pass |

Revert check (`research/slice-042-revert/mutate.py`, the reference in the tree, filtered runs only, `mutate.log`): 14 mutations before the review (13 caught, P6 open by Q4) and 8 after it (P15 to P22, all caught; P21 is P6 again). P6, P7 and P9 did not compile at first (an unused variable): the text of the mutation was changed. The first P22 hit another arm: its text was changed.

| Id | Mutation | Caught by |
| --- | --- | --- |
| P1 | 7 kept lines between 2 runs of changes are one hunk | `diff.roc` |
| P2 | no `\ No newline at end of file` marker | `diff.roc` |
| P3 | an empty new side has the number of a line | `diff.roc` |
| P4 | a hunk applies only at its own place (no offset) | `diff.roc` |
| P5 | a hunk that does not fit is skipped (a partial write) | `diff.roc` |
| P6 | a changed file is deleted (Q4) | not caught before the review (open). P21 after it |
| P7 | a binary file is replaced when the target has other bytes | `diff.roc` |
| P8 | 2 lines of context after a change | `diff.roc` |
| P9 | the platform is copied | `removal.roc` |
| P10 | a refusal has another exit kind | `removal.roc` |
| P11 | an existing copy is overwritten | `pa1-flow` |
| P12 | the first entry of a new file is `[patch.json]` | `intent.roc` |
| P13 | a package that no header names has the mark | `listing.roc` |
| P14 | the `base` of the entry is not the hash | `pa1-flow` |
| P15 | `--diff` with no `[patch]` key is not exit 2 (Q1) | `pa1-flow` (run 13) |
| P16 | `--diff` with no copy dir is not exit 2 (Q1) | `pa1-flow` (run 14) |
| P17 | 2 places at the same distance: the last one (Q2) | `diff.roc` |
| P18 | the nearest place does not win (Q2) | `diff.roc` |
| P19 | a key that is there is not replaced (Q3) | `intent.roc` |
| P20 | an `Add` overwrites a file that the target has (Q4) | `diff.roc` |
| P21 | a `Delete` removes a file with other content (Q4) | `diff.roc` |
| P22 | a `Delete` of a missing file is done (Q4) | `diff.roc` |

After the runs the reference was compared with the tree, and the tree was put back to the stubs (all 7 files and `Run.roc`, `main.roc` are the stubs). `research/slice-042-revert/reference/` was deleted after the review.

## 12. Files

| File | State |
| --- | --- |
| `docs/slices/042-patch.md` | new (this file) |
| `cli/lib/Diff.roc`, `cli/lib/PatchCmd.roc`, `cli/lib/PatchFlow.roc` | new, stubs |
| `cli/lib/Intent.roc`, `cli/lib/IntentEdit.roc`, `cli/lib/Listing.roc`, `cli/lib/Ls.roc` | new types and fields, new stub `add_patch` (the stubs compile and behave as before) |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | wired (the dispatch of `patch`, the module list) |
| `tests/unit/diff.roc` | new, 187 lines |
| `tests/unit/removal.roc`, `tests/unit/intent.roc`, `tests/unit/listing.roc` | new expects (and the changes of section 10) |
| `tests/fuzz/diff.roc` | new, 224 lines |
| `tests/commands/cases/patch/pa1-flow/` | new (14 runs, `rules`) |
| `tests/scenarios/list/ls1-list/expect/stdout` | changed (section 10) |
| `research/slice-042-revert/` | `before/` (with `NEW.txt`), `stubs/`, `proto/`, `gen-pa.py`, `swap.sh`, `mutate.py`, `mutate.log`, `reference-run.log`, `red-run.log` |

## Review (manager, 2026-10-24)

Accepted, no split (no module over 450 lines). D1 to D11 and the TW24 texts accepted. The test agent made the changes below with the reference (one hand mutation each, section 11), then deleted `research/slice-042-revert/reference/`.

| Item | Answer | Change |
| --- | --- | --- |
| Q1 | `--diff` with no `[patch]` key or a missing copy dir: exit 2 | L2 runs 13, 14 (p5, p6). The reference: the missing dir is a `Usage` failure (text `<dir>/ is missing. Restore the copy, or remove the entry from [patch].`, a proposal) |
| Q2 | A hunk that fits at 2 places: the nearest to its line number wins (as `patch`), a tie takes the first | 3 rows in `diff.roc` expect 3 |
| Q3 | `add_patch` replaces an entry that is there (the command refuses an existing copy dir before) | 1 row in `intent.roc`. The reference uses `Toml.replace` for a key that is there |
| Q4 | `Add` on a path that exists, `Delete` on a missing file or on other text: the change fails for that file (D6) | 4 rows in `diff.roc` expect 3. P6 is caught now (P21) |
| Q5 | As tested | |
| Q6 | Out of scope, slice 043 (stale patch) | Out 8 |
| Q7 | `Environment` failure as in other commands, no test | |
| Design gaps | Recorded by the manager | |

Changes to the stubs: the docs of `Diff` (2 places, Add, Delete), `IntentEdit.add_patch` (replace), `PatchFlow` (the 2 `--diff` failures). Old files changed in this step: none (`tests/unit/diff.roc` and `intent.roc` have new rows only; `before/tests/unit/intent.roc` is the file before the slice).

## Verify results (code agent, 2026-10-24)

`scripts/test.sh` exits 0: check pass, fmt pass, l0 pass (86 files; 9.1 s warm, 11.5 s on a run right after the mutation builds: over the budget of 10 s, the infra slice is next), l1 pass (`diff` 20000 runs in 0 s; 37.9 s all), l2 pass (103 cases, `patch/pa1-flow` 14 runs), l3 pass (63 passed, 1 skipped; `list/ls1-list` green), selftest pass (67).

Files of the code: `Diff` 432 lines, `PatchCmd` 159, `PatchFlow` 212 (with comments); new code in `Intent` (`read_patches`), `IntentEdit` (`add_patch`, `patch_edit`), `Listing` (the mark and the key `patched`), `Ls` (`patched_keys`, `run!` uses `walk_full!`). No module is over 500 lines. No test was changed (no dispute rows). No public signature was changed.

Decisions that the slice does not fix:

| Topic | Decision | Rejected |
| --- | --- | --- |
| `Diff.make` order of a run | The back walk of the LCS table takes an inserted line when the 2 ways are equal. This gives all `Del` before `Ins` with no second pass (proof in the doc of `middle`). A separate `deleted_first` pass was written first and removed: no test or fuzz run can see it (it never changes the result) | a second pass over each run |
| `Diff.apply` | A hunk is searched from the end of the one before it, to the end of the text. The scan stops at the first fit at or after the wanted line (the next fits are farther) | a scan of the whole text for each hunk |
| `Intent.patches` | An entry of the form `[patch.json]` with a string `path` and a string `base` is read like the inline table (the TOML value is the same table). D10 says inline only. The tests do not tell the 2 forms apart. Question for the human (TW17): is it wanted? | a check of the source line of the key |
| `add_patch` of the empty text | `[patch]` and the entry are written by hand (`Toml.insert` on an empty text gives `[patch.json]`) | `Toml.print` |
| `PatchFlow` base of `--diff` | The base is fetched (`Fetch.packages!`) as the target of the header. A `base` that is not the hash of the header entry is read from the cache without a fetch (Out 8, slice 043). A missing base dir is an `Environment` failure | the fetch by the hash of the `base` |
| `Ls.run!` | Uses `walk_full!` and `Ls.patched_keys` (the `[patch]` keys of the nearest `talon.toml` of the member). `walk!` is not changed | |

Revert check (`research/slice-042-revert/agent-mutate.py`, results in `agent-results.md`): caught 14 of 14 runs (13 mutations, P8 run in 2 layers). Filtered runs only (one `roc test` file, `scripts/test.sh l1` or `l2`).

| Id | Mutation | Caught by |
| --- | --- | --- |
| P1 | 7 kept lines between 2 runs of changes are one hunk | `diff.roc` |
| P2 | 2 lines of context after the last change | `diff.roc` |
| P3 | 2 places at the same distance: the last one wins | `diff.roc` |
| P4 | the first place wins, not the nearest | `diff.roc` |
| P5 | a hunk that does not fit is skipped, the file is written | `diff.roc` |
| P6 | no marker after a line with no line end | `diff.roc` |
| P7 | an `Add` overwrites a file that the target has | `diff.roc` |
| P8 | inserted lines come before deleted lines of a run | `diff.roc` and L1 `diff` |
| P9 | an existing copy dir is overwritten | `pa1-flow` (l2) |
| P10 | the platform is copied | `removal.roc` |
| P11 | a package that no header names has the mark `patched` | `listing.roc` |
| P12 | the base of the entry is not the hash | `pa1-flow` (l2) |
| P13 | the first entry of a new file is `[patch.json]` | `intent.roc` |

The code after the runs is the same as `research/slice-042-revert/code-final/` (`sha256sum -c research/slice-042-revert/code-final.sha256` from the repo root: 7 files OK).

## Gap tests (test agent)

The code agent's decisions that were visible behavior with no test. Tests only, no code changed. Rows went into existing expects (no new unit file). `pa1-flow` has 15 runs now (runs 1 to 14 have the same output as before: the new lines in the expected files are all after run 14).

| Gap | New test | Hand mutation (`gap-mutate.py`, `gap-mutate.log`) | Result |
| --- | --- | --- | --- |
| Q2: the nearest place wins when the nearest is before the line of the hunk and a far one is after it. The code stops the scan at the first fit at or after the wanted line | `diff.roc` expect 3: 2 rows (nearer before, far after; one before, a nearer one after) | G1: a fit before the wanted line is ignored. G2: the first fit wins | both caught by `diff.roc`. The code passes both rows: no code bug |
| D10: `Intent.patches` reads the table form `[patch.json]` (manager decision: accepted, a lenient read) | `intent.roc` expect `[patch]`: 1 row | G3: the table form is not read | caught by `intent.roc` |
| `--diff` with a missing base dir: `Environment` failure, exit 18 | `pa1-flow` run 15 (p7: the `base` of the entry is a hash that is not in the cache and not the hash of the header entry) | G4: the failure is a `Usage` failure (exit 2) | caught by `pa1-flow` |

After each mutation the file was put back, and `sha256sum -c research/slice-042-revert/code-final.sha256` (from the repo root) is OK for all 7 files.

## Close (manager, 2026-10-24)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-042-revert/code-final.sha256` | OK, 7 lines |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.2, fmt 0.2, l0 9.2, l2 4.6, l3 9.8, selftest 11.6, l1 32.1 s |
| Gap tests | 3 rows, 4 hand mutations, all caught; no code bug |
| Proposal for the user (TW24) | the text of a missing copy dir: `<dir>/ is missing. Restore the copy, or remove the entry from [patch].` |
