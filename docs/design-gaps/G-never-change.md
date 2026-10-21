# G-never-change: what Talon may change in an entry that it does not manage

Status: proposal for the human review. Author: gap agent, 2026-10-21.

## 1. The gap

An unmanaged entry is a header entry that `Ident.of_url` cannot read as a release: a path entry, or a foreign URL (no version, no hash, 2 versions, `0.0.0`). The source archive of a git ref is a foreign URL: R-H3 and CLI 6.4 ("Project dependencies from git are out of scope") let no other form into a header.

| Rule | File, section | Says | Problem |
| --- | --- | --- | --- |
| R-H4 | Design 4.2 | "Talon never changes a path entry or a URL it cannot identify." | Absolute. No command is excepted. |
| R-H7 | Design 4.2 | A path entry "is not a variable ... Talon never changes it (R-H4)". | Repeats R-H4. Silent on the file that the path names. |
| R-RV5 | CLI 2, `tln remove` | Removes a path entry or a foreign URL. "It has no `talon.toml` key." | Conflicts with R-H4. Slice 008 D9 removes a key when there is one, so the second sentence is also wrong. |
| R-AD18, R-AD19 | CLI 2, aliases | An alias that is used stops `add`. `--as` must name a free alias. | No way to change a path entry into a release. The user must `remove --force` (R-RV2: the alias is imported), then `add`. |
| R-AD21, R-AD22 | CLI 2, entry in the header | No selector: prints `<name> <version>` and names `tln update`. Selector: "the same as `tln update`". | Silent for an unmanaged entry. It has no name and no version, and `tln update` refuses it (slice 009 Q8). |
| R-AD31 | CLI 2, `--platform` | Replaces the platform "under the same alias". | Silent when the platform is a path entry, and R-PA8 tells users to use one. R-RV3 forbids `remove` of the platform. So with a strict R-H4 a path platform can leave only by a hand edit. |
| R-PA1 | Resolution 7 | `tln patch` copies the cached package of the entry. | Silent for an unmanaged entry: a path has no cached package, a foreign URL has no `base` release for R-PA5. |
| R-I3 | Design 4.3 | A key for an alias that is in the header is a range constraint. | Silent when the entry of that alias is unmanaged. |

Interim answers in force: slice 007 Q1 and slice 008 ("R-RV5 wins for `remove` only", `Locked.edit` `Remove` accepts any row), slice 009 Q8 (`update <path alias>` is exit 2).

Code facts found:

| Fact | Where | Effect |
| --- | --- | --- |
| `add --platform` with a path platform gives `Replace`, and the flow applies it with `Set` | `cli/lib/Add.roc:237-243`, `cli/lib/Locked.roc:121-127`, `cli/lib/Locked.roc:150-153` | `check_row` refuses: exit 1 (`Internal`, a Talon fault) |
| `update` checks only `Path` rows for the R-H4 refusal | `cli/lib/PickFlow.roc:126-128` | A foreign URL named by `update` gets the lookup failure, not the R-H4 reason (slice 009 G3) |
| The `Taken` text says "used by another package" for a path entry | `cli/lib/Alias.roc:149`, `cli/lib/Alias.roc:154-162` | The user does not learn that `--as` can replace it |
| A `talon.toml` key of an unmanaged alias is no want and no range | `cli/lib/Vars.roc:112`, `cli/lib/Vars.roc:204-206` | Ignored, which is the behavior this file proposes. No test names it. |

## 2. Options

| # | Option | P0 cost | P1 and later | Users |
| --- | --- | --- | --- | --- |
| A | Strict R-H4. Delete R-RV5: `remove` refuses an unmanaged entry. `add --platform` refuses a path platform. | Revert the `Remove` change of slice 008, 2 refusals, tests | Simple rule. Every change of an unmanaged entry is a hand edit. | Bad. A local path platform or library can leave only by a hand edit. All other managers remove such entries. |
| B | Value or entry. Talon never writes the value of an unmanaged entry. Only `remove` takes the whole entry away (the interim answer, written into the design). | Doc only, plus the `add --platform` fault and the foreign case of `update` | `patch`, `upgrade` follow R-H4. The switch from a path to a release stays 2 commands. | Medium. Path to release: `tln remove util --force` (it skips the check), then `tln add owner/util --as util`. A path platform still has no way out. |
| C | Value or entry, by an explicit act. Talon never computes or writes a value for an unmanaged entry. A command that the user aims at the alias may remove the whole entry (`remove`) or replace it with a release (`add --as <alias>`, `add --platform`). Every other command keeps it byte for byte, and a command that would move it stops with exit 2. | B, plus a replace op in `Locked.edit`, a new `Alias.choose` result, `Add` rows, text changes. About 1 small slice. | One rule for all commands. `patch` and `upgrade` (P1) only need the refusal row. A registry changes nothing: an unmanaged entry is never sent as a variable. | Good. Path to release is one command with the check (`tln add owner/util --as util`). A path platform is replaced with `tln add --platform`. |
| D | C, plus Talon writes path entries (`tln add ../util/main.roc`, as `cargo add --path`, `uv add --editable`). | New ref form, R-H3 change, new tests | Larger surface. `[patch]` (Resolution 7) already covers "edit a dependency locally". | Small gain: a path entry is 1 line to type. |

Other managers, from what I know:

| Manager | Update or upgrade of a path or VCS dependency | Remove | Explicit add of a new source for the same name |
| --- | --- | --- | --- |
| cargo | `cargo update` never changes a path dependency | `cargo remove` removes it | `cargo add foo@1` rewrites the entry to a registry source |
| npm, bun | `npm update` skips `file:` and git specs | `npm uninstall` removes it | `npm install foo@^1` replaces a `file:` spec |
| uv | `uv lock --upgrade` keeps path sources | `uv remove` removes it | `uv add foo` replaces the source |
| Go modules | `go get -u` never edits a `replace` directive | `go mod edit -dropreplace` (explicit) | Explicit `go mod edit` |

All 4 do C: an update never touches the entry, an explicit act on the name may remove or replace it.

## 3. Decision

Option C. Reasons:

1. The real line is between "Talon computes a value" (update, upgrade, install, a host rewrite, `roc fmt`) and "the user names the entry and asks for a whole-entry act" (remove, replace). R-H4 protects the first, which is where Talon can do harm: it has no index, no version and no evidence for an unmanaged entry. The second is the user's own intent, and the result is again a managed entry or no entry.
2. It removes a deadlock that A and B keep: a path platform (R-PA8 suggests one) that `remove` refuses (R-RV3) and `add --platform` cannot replace.
3. It is what cargo, npm, bun, uv and Go do, so users meet no surprise.
4. It is phase free. P1 commands (`upgrade`, `patch`) get one refusal row. The registry never sees an unmanaged entry as a variable (R-H7 sends only the URL entries of a path file).
5. Talon still writes only release URLs (R-H3). D is not needed: a path entry is a hand edit, and `[patch]` is the managed way to edit a dependency.

The default alias never replaces (R-AD18 still stops): a replace needs the alias typed by the user (`--as`). A key in `talon.toml` for an unmanaged alias is kept and ignored, so a user can switch a release to a path for local work and back with no change to `talon.toml`.

## 4. Design edits

| # | File | Rule | Old text | New text |
| --- | --- | --- | --- | --- |
| E1 | DESIGN.md 4.2 | R-H4 | `\| R-H4 \| Talon never changes a path entry or a URL it cannot identify. It lists them as "foreign" in \`tln ls\`. \|` | `\| R-H4 \| An unmanaged entry is a path entry, or a foreign URL: a URL that is not a release URL of 4.1 (no version, no hash, 2 versions, \`0.0.0\`, for example the source archive of a git ref). Talon never writes the value of an unmanaged entry, never writes a new one (R-H3), and never edits the file that a path entry names. It changes an unmanaged entry only as a whole, and only when the user names its alias in a command that removes or replaces that entry (R-H9). A temp copy for a probe is not the project: there Talon rewrites path prefixes (Resolution 4, R-LD4). \`tln ls\` marks an unmanaged entry "foreign" (CLI 1, R-CM9). \|` |
| E2 | DESIGN.md 4.2 | R-H7 | `A path entry is not a variable: it has no index and no version, and Talon never changes it (R-H4). A path entry in that header follows the same rule.` | `A path entry is not a variable: it has no index and no version, so Talon never moves it (R-H4). A path entry in that header follows the same rule, and no command removes or replaces it: it is not an entry of the project header.` |
| E3 | DESIGN.md 4.2, after R-H8 | R-H9 (new) | none | The block below |
| E4 | DESIGN.md 5 | index | `\| R-H1 to R-H8 \| The header as lockfile \| 4.2 \|` | `\| R-H1 to R-H9 \| The header as lockfile \| 4.2 \|` |
| E5 | DESIGN.md 5 | index | `\| R-AD1 to R-AD37, R-RV1 to R-RV5 \|` | `\| R-AD1 to R-AD38, R-RV1 to R-RV5 \|` |
| E6 | DESIGN.md 5 | index | `\| R-PA1 to R-PA13 \| Patches \|` | `\| R-PA1 to R-PA14 \| Patches \|` |
| E7 | DESIGN-CLI.md 2 | R-AD18 | `\| R-AD18 \| 4 \| If the alias exists in the header for a different group, Talon stops. It asks for \`--as <alias>\`. It never adds a suffix. \|` | `\| R-AD18 \| 4 \| If the alias exists in the header for a different group or for an unmanaged entry (Design 4.2, R-H4), Talon stops. It asks for \`--as <alias>\`. It never adds a suffix. For an unmanaged entry, the message also says that \`--as <that alias>\` replaces it (R-AD38). \|` |
| E8 | DESIGN-CLI.md 2 | R-AD19 | `Talon still checks that the alias is a valid identifier and is free.` | `Talon still checks that the alias is a valid identifier, and that it is free or names an unmanaged entry (R-AD38).` |
| E9 | DESIGN-CLI.md 2 | R-AD21 | `\| R-AD21 \| No selector (\`tln add json\`) \| Changes nothing. Prints \`json: someone/roc-json 2.1.0 is in the header\` and names \`tln update json\`. Exit code 0. \|` | `\| R-AD21 \| No selector (\`tln add json\`) \| Changes nothing. Prints \`json: someone/roc-json 2.1.0 is in the header\` and names \`tln update json\`. Exit code 0. For an unmanaged entry (Design 4.2, R-H4), it prints the value as written and names no command. \|` |
| E10 | DESIGN-CLI.md 2 | R-AD22 | `\| R-AD22 \| A selector (\`tln add json@^3\`) \| The same as \`tln update json@^3\` (Resolution 9, 10): the entry moves inside the selector, also to a new series. Talon writes \`talon.toml\` as the table below gives for that selector. \|` | `\| R-AD22 \| A selector (\`tln add json@^3\`) \| The same as \`tln update json@^3\` (Resolution 9, 10): the entry moves inside the selector, also to a new series. Talon writes \`talon.toml\` as the table below gives for that selector. For an unmanaged entry, exit code 2, as \`tln update\` (Design 4.2, R-H9). \|` |
| E11 | DESIGN-CLI.md 2, after the R-AD20 table | R-AD38 (new) | none | `R-AD38: \`tln add <name>[@sel] --as <alias>\`, where \`<alias>\` is an unmanaged entry (Design 4.2, R-H4), replaces that whole entry under the same alias with the release that \`<name>[@sel]\` selects (R-H3). The resolve, the check and the build run as for a new entry. The keyword \`platform\` of the entry stays, and R-C4 and R-AD32 apply to it. \`talon.toml\` gets what the table "What \`tln add\` writes to \`talon.toml\`" gives. A key that the alias already has stays and is the range of the new entry (R-I3). The output names the old value, as the platform note of R-AD31 does.` |
| E12 | DESIGN-CLI.md 2 | R-AD31 | `Replaces it under the same alias, also when the new platform is another repo.` | `Replaces it under the same alias, also when the new platform is another repo, and also when the old entry is unmanaged (Design 4.2, R-H4).` |
| E13 | DESIGN-CLI.md 2 | R-RV5 | `\| R-RV5 \| A path entry or a foreign URL (R-H4) \| Removes the entry. It has no \`talon.toml\` key. \|` | `\| R-RV5 \| An unmanaged entry: a path entry or a foreign URL (Design 4.2, R-H4) \| Removes the whole entry as R-RV1 and R-RV2 give (the import scan and the check apply). Removes a \`talon.toml\` key and an \`[overrides]\` key of the alias when there is one. Never edits the file that a path entry names. \|` |
| E14 | DESIGN-RESOLUTION.md 7, after R-PA8 | R-PA14 (new) | none | `\| R-PA14 \| \`tln patch\` of an unmanaged entry (Design 4.2, R-H4) stops with exit code 2. A path entry is local code: the user edits its file. A foreign URL has no release, so R-PA4 and R-PA5 cannot hold or move it. \|` |

E3, the new block (a paragraph id that covers the table, Design 1):

```
R-H9: What each command does with an unmanaged entry (R-H4):

| Command | Talon does |
| --- | --- |
| `install`, `update`, `upgrade`, `verify` with no names | Keeps it byte for byte. It is no variable. The URL entries of a path file still join the closure and MVS (R-H7). A `talon.toml` or `[overrides]` key of its alias is no constraint and adds no entry (R-I5). The key applies again when the entry is a release. |
| `update X`, `upgrade X`, `add X@sel` (form 1), where X is its alias | Exit code 2 (CLI 3, R-EC2). The message says that Talon never changes it, and names `tln add <name> --as X`. |
| `add X` (form 1, no selector) | Changes nothing (CLI 2, R-AD21). Exit code 0. |
| `add <name>`, and the default alias is its alias | Stops (CLI 2, R-AD18). |
| `add <name> --as X`, `add --platform <name>` | Replaces the whole entry with a release URL (CLI 2, R-AD38, R-AD31). |
| `remove X` | Removes the whole entry (CLI 2, R-RV5). Not the platform (R-RV3). |
| `patch X` | Exit code 2 (Resolution 7, R-PA14). |
```

The R-EC2 list (CLI 3) already covers "bad ref". The case of E10 and R-H9 row 2 is a usage failure of that kind, so R-EC2 needs no edit.

## 5. Work that follows

New slice 013 "Unmanaged entries" (P0 for `install`, `add`, `remove`, `update`; R-PA14 and the `upgrade` row wait for the P1 slices of those commands, TW16).

| Area | Change | Test (red first) |
| --- | --- | --- |
| `cli/lib/Locked.roc` | A new op (for example `Replace({ alias, url })`): any row, the URL must pass R-H3, the keyword stays. `Set` still refuses an unmanaged row, so an update bug stays an `Internal` fault. Doc of `Remove` names R-RV5 and R-H4 (no "gives way"). | `tests/unit/locked.roc` expect 2: replace of a path row, a foreign row, a path platform row; replace with a foreign URL refused |
| `cli/lib/Alias.roc` | `choose`: with `--as` that names an unmanaged entry, a new result (for example `Unmanaged(alias)`). The default alias on an unmanaged entry stays `Taken`, with the new text of E7. | `tests/unit/alias.roc` 3: 4 rows (path and foreign, default and `--as`) |
| `cli/lib/Add.roc` | `decide`: `Unmanaged` gives `Replace`. `decide_alias` of an unmanaged row: `Keep` with no `tln update` line (R-AD21), and a usage failure with a selector (R-AD22). | `tests/unit/add.roc`: R-AD38, R-AD21, R-AD22, R-AD31 rows |
| `cli/lib/InstallFlow.roc` | `Replace` uses the new op for an unmanaged row (removes the exit 1 of `add --platform` on a path platform). | L3 `add/ad2-platform-json` or a new L3 case: path platform replaced; `add owner/util --as util` over a path entry |
| `cli/lib/PickFlow.roc` | The R-H4 refusal covers `Foreign` rows too, and names `tln add <name> --as X` (closes slice 009 G3). | L3 `update/up1-update-entries`: a run with a foreign URL |
| `cli/lib/Removal.roc` | Doc only: R-RV5 now agrees with R-H4. | `tests/unit/removal.roc`: rule comment only |
| `cli/lib/Vars.roc` | No change. | `tests/unit/vars.roc`: a key of a path alias and of a foreign alias is no want and no range (R-H9, row 1) |

Tests that name R-RV5 with the comment "R-RV5 wins" (`tests/unit/locked.roc`, `tests/scenarios/remove/rm1-remove-entries/cmd`) change the comment to R-H4 and R-H9. The test agent does these, not the code agent (TW18).

## 6. Questions for the human (TW17)

| # | Question | Default if no answer |
| --- | --- | --- |
| Q1 | Accept that `--as <alias>` replaces an unmanaged entry with no prompt? The user typed the alias, and the check runs. A prompt (CLI 4) would need a new R-NI row. | No prompt |
| Q2 | Option D (Talon writes path entries, `tln add ../util/main.roc`) is not in this decision. Do you want it as a later item? | No. Path entries stay hand edits. |
