# tln command inventory

Read-only inventory of every command form of `tln`, for a later consistency review. It holds raw facts and no judgement.

Sources and how to cite them:

| Short name | File |
| --- | --- |
| `CLI` | `DESIGN-CLI.md` (line numbers are from the read on 2026-11-23; the file is edited by another session, so use the rule id to find a row again) |
| `Args` | `cli/lib/Args.roc` (`allows` 231-272, `takes_value` 221-228, `top_level` 199-204, `sub_words` 207-214, `long_form` 189-196, `apply` 147-159, `finish` 162-186) |
| `Help` | `cli/lib/Help.roc` (usage text 36-69, `route` 19-32) |
| `Run` | `cli/lib/Run.roc` (`tln!` 74-103, `dispatch!` 108-199, `check_refs` 203-220) |

Words used: "header" = the `app`/`package`/`platform` header of the project `.roc` file. "lock" = Talon has no lock file; the header is the lock (Design G1), so the column "lock" is folded into "header". "Global" flags: see section 2.

---

## 1. Command forms

Common to every row unless the row says otherwise: `--yes`, `--offline`, `--quiet`, `--registry <url|direct>` are accepted by `Args.allows` (Args:237); `--json` is accepted except for `x` (Args:236); `--help` and `--version` are read before the parse (Help:25-28). See section 2 for the matrix.

Column "Code" gives the dispatch line in `Run.roc` first, then the module that does the work.

### 1.1 Project commands (header and `talon.toml`)

| # | Command | Form (synopsis) | Positional args | Flags (value, meaning in THIS command) | What it changes | Notable defaults / implicit behaviour | Rule ids | Code |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `init` | `tln init [app\|package] [--platform <owner/repo>[@<exact version>]] [--ci github\|none]` | 0 or 1: template word `app` (default) or `package`. More than 1: error. | `--platform <value>` (here it takes a value): platform of the template, exact 3-part version only. `--ci <github\|none>`: CI file or none. `--probe-downloads`, `--allow-downloads`: consent for compiler downloads. | Creates `main.roc` in the current directory and `.github/workflows/ci.yml`. No `talon.toml` (R-IN5). Downloads the newest nightly. Records the file in `projects.json`. Never overwrites; on a fail removes the files it made. | Template `app`, platform `roc-lang/basic-cli` newest release allowed by `min-release-age`; nightly pin chosen by the ladder; `--ci github`. `--platform` with `package` is an error. Does not search for a project; `--file` rejected. | R-CM1, R-IN1 to R-IN10, R-NI12, R-PD15 | CLI:11, CLI:994-1008; Run:111; `Init.roc` (read 60-90); Args:244,245,258,259 |
| 2 | `install` (`add`, `i`) | `tln install` (no names) | none | Resolve flags (section 2.2). `--tool` sends the line to the tool flow (row 5). | Fetches the closure into `packages/`; builds each project tool with no binary; changes only header entries that break `talon.toml`. With `--frozen` makes no index call. | "Keep the header" mode. Keeps the `roc:` pin. `--frozen` works here only. | R-CM2, R-FL13, R-SP18 | CLI:12; Run:113; `Install.roc`; `Opts.roc` (read 50-80) |
| 3 | `install` (`add`, `i`) | `tln install <name[@sel]>... [--as <alias>] [--no-pin] [--no-check] [--rename-keys] [--allow-moves]` | 1 or more refs. Shapes: header alias (`pf`), full name `owner/repo`, `host/path`, short name (`parser`, needs a registry), each with `@sel` (exact `@1.2.3`, range `@^1.2`, series `@1`, `@latest`). Not nightly tags, not `@+N`/`@-N` (compiler only). | `--as <alias>`: alias of the new entry (one name only). `--no-pin`: exact version with no `talon.toml` anchor. `--rename-keys`: answers prompt R-NI1. `--allow-moves`: answers R-NI3. `--no-check`: skip whole-app check. `--dry-run`: write nothing. `--snapshot`, `--strategy`, `--slots`, `--no-probe`, `--allow-downloads`. | Adds header entries; writes `talon.toml` anchor (`X = "=1.2.3"`) or range (`X = "^1.2"`) only when a selector is typed; may call the registry ingest (`POST /v1/releases`) for an unknown repo; queues share facts. | A name that is already a header alias is not added: no selector prints "is in the header"; a selector acts as `tln update X@sel`. Default alias from repo name (drop `roc-`, `-` to `_`). `--frozen` with names: exit 2. With 2+ names `--as` is exit 2. No selector = newest allowed by `strategy`. | R-CM2, R-AD1 to R-AD38, R-SL1 to R-SL16, R-SC2, R-NI1, R-NI3 | CLI:12, CLI:572-760; Run:113,203-220; `Install.roc`; `Add.roc`; Args:242-243,256-257 |
| 4 | `install` (`add`, `i`) | `tln install --platform <owner/repo>[@sel]` | exactly 1 ref: the platform. (0 or 2+ names: exit 2.) | `--platform` is a flag with no value here; the ref is the operand. `--as <alias>` names the entry. | Sets or replaces the platform entry (alias `pf`); may move other entries (prompt R-NI3). | Without `--platform`, a platform name is an error that names `--platform` (R-AD33). Replaces an unmanaged platform entry too. | R-AD29 to R-AD33, R-C3, R-C4 | CLI:742-750; `Opts.roc:50-55`; Args:244 |
| 5 | `install` / `add` | `tln install --tool <owner/app[@sel]> [--as <key>]` | exactly 1: full `owner/app` name with version, range or `latest` selector. Not short name, not git sha. | `--tool`: switch to project tools. `--as <key>`: here the value is a `[tools]` key (lower case, digits, `.`, `_`, `-`). Allowed only: `--tool --as --snapshot --dry-run --allow-downloads` (other flags: exit 2). | Adds a `[tools]` entry to `talon.toml` (with locked URL); builds the tool. | `--tool` anywhere on the line wins over the command word: dispatch goes to `ToolsFlow` before every other branch (Run:109). | R-CM2, R-PT3, R-FL12 | CLI:12, CLI:93; Run:109; `ToolsCmd.roc` 9-60, 105-130 |
| 6 | `remove` (`rm`) | `tln remove <name>... [--force] [--no-check]` | 1 or more refs: header alias, full name, short name, with optional `@sel` filter. Transitive packages are not names. | `--force`: remove even if an app module imports it, skip the check. `--no-check`, `--dry-run`, `--allow-downloads`, `--snapshot`, `--strategy`, `--slots`, `--no-probe`. `--frozen` parsed then rejected. | Removes header entry, its `talon.toml` key, `[overrides]` entry, `[patch]` entry (keeps files in `.talon/patches/<alias>/`). Runs whole-app check. | Platform entry: exit 2. Entry imported by app: exit 11 unless `--force`. New package-blame error: exit 10. | R-CM3, R-RV1 to R-RV5, R-SC1 | CLI:13, CLI:753-760; Run:115; `Remove.roc`; `Removal.roc:38`; Args:254 |
| 7 | `remove` (`rm`) | `tln remove --tool <key>...` | 1 or more `[tools]` keys (no `@sel`, no capitals). | `--tool`. Allowed only: `--tool --snapshot --dry-run --allow-downloads`. | Removes `[tools]` entries from `talon.toml`. | Operands are keys, not refs (dispatch at Run:109; `check_refs` skipped at Run:207). | R-CM3, R-PT3 | CLI:13; Run:109; `ToolsCmd.roc:35-60` |
| 8 | `update` (`up`) | `tln update [<pkg[@sel]>...] [--no-pin] [--no-check] [--allow-moves]` | 0 or more: header alias, full name, short name, optional `@sel`. `pkg@sel` moves to the selector, also a new series. No name = all. | `--no-pin`: with an exact version, no anchor. `--no-check`, `--dry-run`, `--allow-moves`, `--snapshot`, `--strategy`, `--slots`, `--no-probe`, `--allow-downloads`. `--frozen` parsed then rejected. | Moves header entries inside ranges; rewrites `talon.toml` anchor/range for a typed selector; moves project tools too; queues share facts. | The nightly does not move (R-RP1). A name that matches 2 series needs the alias (`tln update http1@3`). Follows a successor name (`moved`). | R-CM4, R-SC14, R-SC16, R-SP5, R-NI3 | CLI:14; Run:117; `Update.roc` (read 55-70); Args:243,257 |
| 9 | `update` (`up`) | `tln update -i` | none (names with `-i`: exit 2) | `-i`: interactive picker of packages. The only short flag of `tln`. Needs interactive mode (non-interactive: exit 2). | Same as row 8 for the picked packages. | `-i` is "the whole command", not a prompt. | R-CM4, R-NI2, R-NM7 | CLI:14,77; Run:117; `Update.roc:64-67`; Args:249 |
| 10 | `update` (`up`) | `tln update --tool [<key>...]` | 0 or more `[tools]` keys (none = each tool). | `--tool`, `--snapshot`, `--dry-run`, `--allow-downloads` only. | Moves `[tools]` locks in `talon.toml`; builds. | `--tool` sends the line to `ToolsFlow`. | R-CM4, R-PT5 | CLI:14; Run:109; `ToolsCmd.roc` |
| 11 | `upgrade` | `tln upgrade [<pkg>...] [--no-check]` | 0 or more names (no selector expected; `--strategy lowest` is rejected). | `--no-check` (rejected when the nightly is free: no names, or name `roc`). `--probe-downloads`: optional compiler downloads for the search. `--allow-moves`. `--dry-run`, `--snapshot`, `--slots`, `--no-probe`, `--allow-downloads`. `--frozen` parsed then rejected. | Moves entries to newest releases, also new series, and the nightly pin; rewrites `talon.toml` ranges; moves project tools. | Ignores package ranges. No name = packages and the nightly move. Names hold the nightly. | R-CM5, R-UP1 to R-UP9, R-NI4, R-NI12 | CLI:15; Run:119; `Upgrade.roc` (read 36-50); Args:257,258 |
| 12 | `upgrade` | `tln upgrade roc` | the literal word `roc` (not a package name here) | as row 11 | Moves only the compiler pin (the nightly). | `roc` frees the nightly; other names hold it. | R-CM5, R-RP1, R-UP6 | CLI:15; `Upgrade.roc` |
| 13 | `upgrade` | `tln upgrade --tool [<key>...]` | 0 or more `[tools]` keys | `--tool`, `--snapshot`, `--dry-run`, `--allow-downloads` only | Moves `[tools]` locks to newest releases | as row 10 | R-CM5, R-PT5 | CLI:15; Run:109 |
| 14 | `outdated` | `tln outdated` | none | globals only (`--file`) | Nothing written (records the project). Reads index. | Table current/wanted/latest/nightly; a row for each project tool; ` (moved to <successor>)` suffix. Exit 0 also when behind (R-E7). | R-CM6, R-E7, R-PU28 | CLI:16; Run:129; `OutdatedFlow.roc` |
| 15 | `why` | `tln why <name>` | 1: header alias, full name, short name, `owner/repo@series` (the package must be in the closure, any depth). | globals only (`--file`) | Nothing written. | Shows evidence and `raised from` mark. Series is part of the name when 2 series are in the closure. | R-CM7, R-SC1, R-SC14 to R-SC16 | CLI:17; Run:125; `Why.roc` |
| 16 | `list` (`ls`) | `tln list [--tree]` | none | `--tree`: show as tree (flat list otherwise). | Nothing written. | Marks: `direct`, `via`, `raised`, `foreign`, `patched`. | R-CM9 | CLI:19; Run:123; `Ls.roc`; `Listing.roc:52`; Args:251 |
| 17 | `patch` | `tln patch <alias> [--diff]` | exactly 1: header alias (a name or `@sel` that is a header entry; platform refused) | `--diff`: print the diff against the original, write nothing. | Copies the package to `.talon/patches/<alias>/`; writes a `[patch]` entry in `talon.toml`. | Platform entry: exit 2 (R-PA8). | R-CM10, R-PA1 to R-PA14 | CLI:20; Run:131; `PatchCmd.roc`, `PatchFlow.roc`; Args:250 |
| 18 | `verify` | `tln verify [--strategy highest\|lowest]` | none (a name: exit 2) | `--strategy`, `--snapshot`, `--no-check`, `--no-probe`, `--slots`, `--allow-downloads`. `--frozen` and `--dry-run` are parsed then rejected. | Writes no header and no `talon.toml`; adds facts to `compat.db`. | Resolves in memory; runs the probe ladder. | R-CM11, R-FL14, R-LF3 | CLI:21; Run:121; `Verify.roc` (read 44-58) |
| 19 | `probe` | `tln probe` (no operand) | none | `--slots`, `--allow-downloads`, `--probe-downloads`. | Writes nothing (results printed only, no fact written for the project file). | Probes the project file itself on the selected compiler. `--range` here: exit 2. | R-CM8, R-PB1 | CLI:18; Run:135; `ProbeCmd.roc` 19-46 |
| 20 | `probe` | `tln probe <alias\|bundle file> [--range] [--share]` | 1: header alias or name (`json`, `acme/json@2`), or a path ending `.tar.zst` (a bundle file). | `--range`: find the compiler range (searches many compilers). `--share`: send facts to the registry once, also when `share` is off (needs registry, a hash, no bundle file). `--slots`, `--probe-downloads`, `--allow-downloads`. | Adds facts to `compat.db`; with `--share` sends to the registry; a bundle file is copied into `packages/<hash>/`. | Operand shape is read by suffix: `.tar.zst` = bundle, else alias. Exit 12 when `--range` ends unknown. | R-CM8, R-PB1 to R-PB7, R-PB9 | CLI:18; Run:135; `ProbeCmd.roc`; Args:252 |
| 21 | `probe` | `tln probe --smoke <alias\|release URL> [--target <t>]...` | 1: header alias, or a URL starting `https://` or `http://`. A bundle file: exit 2. | `--smoke`: build the smoke app of a platform. `--target <t>` (value; only with `--smoke`; repeatable). `--range`, `--share` with `--smoke`: exit 2. | Adds smoke facts to `compat.db`; builds. | A URL operand uses no project, so `--file` with it is exit 2. Dispatch moves to `ProbeSmokeFlow` when `--smoke` OR `--target` is present (Run:133). | R-CM8, R-PB10, R-SM1 to R-SM7 | CLI:18; Run:133; `ProbeSmoke.roc` 10-40; Args:224,252 |
| 22 | `publish` | `tln publish` | none (operand: exit 2) | `--probe-downloads`, `--file` (names the package for the API check), `--registry` | Sends a publish request to the registry; reads GitHub; may run `roc bump`. Writes no file. | Reads `GITHUB_REPOSITORY`, `GITHUB_REF`, OIDC variables. Needs a registry (`direct`: exit 2) and the network (`--offline`: exit 15). Does not send the share queue. | R-CM13, R-PUB1 to R-PUB4 | CLI:23, CLI:426-436; Run:137; `PublishFlow.roc`; Args:258 |
| 23 | `audit` | `tln audit [--ignore <item>]...` | none | `--ignore <owner/repo@version:reason>` (value, repeatable): ignore one finding for this run. | Nothing written. Reads index. | `--offline` is exit 2. Exit 21 when a failing finding is not ignored. With `direct`, prints note `no-yank-data`. Items also come from `[audit] ignore` in `talon.toml`. | R-CM14, R-AU1 to R-AU15 | CLI:24, CLI:368-404; Run:127; `AuditFlow.roc`, `AuditCheck.roc:241`; Args:267 |
| 24 | `path` | `tln path <alias>` | exactly 1: header alias (not a full name, not a short name). | globals (`--file`). | Fetches `packages/<hash>/` when missing; writes no project file; records the project. | Prints one line: absolute dir. `--offline` with a missing dir: exit 15. Foreign URL: exit 2. | R-CM25, R-PTH1 to R-PTH5 | CLI:33, CLI:558-570; Run:169; `PathCmd.roc`, `PathFlow.roc` |
| 25 | `run` | `tln run` (no name) | none | `--json` allowed here only. | Nothing written. | Lists scripts of the nearest `talon.toml` that has `[scripts]`, with notes for `[tools]` keys that are also programs on PATH. | R-CM24, R-RUN11 | CLI:32, CLI:437-560; Run:167; `RunFlow.roc`, `RunCmd.roc` |
| 26 | `run` | `tln run <name> [-- <args>]` | 1: a script name `[a-z0-9][a-z0-9:_-]*`. Extra words need `--`. Words after `--` go to the last step. | none of its own. `--json`: exit 2 (parsed OK by Args, rejected by `RunCmd`). `--file`, resolve flags, `--allow-downloads`: exit 2. | Runs child programs; may build a project tool; records project files. No header change. | No shell. `roc` and `tln` in a step run this `tln`. Exit code = first failing step. Sets `TALON_SCRIPT`, `TALON_SCRIPT_DIR`. | R-CM24, R-RUN1 to R-RUN19 | CLI:32; Run:167-168; `RunCmd.roc` 4-16 |
| 27 | `run` | `tln run --each [<name>] [--keep-going] [-- <args>]` | 0 or 1 name. No name: print order and edges, run nothing. | `--each`: run in each workspace directory, in dependency order. `--keep-going` (only with `--each`): skip dependents of a failed node, go on. | as row 26, per node | One node at a time. `--keep-going` allowed by Args for `run` even without `--each` (Args:269). | R-RUN13, R-EA1 to R-EA8 | CLI:32,91-92; Args:269; `RunEach.roc`, `RunEachFlow.roc` |
| 28 | `x` | `tln x <owner/app[@sel]> [-- <args>]` | 1: full name `owner/app` (or installed tool / x-cache short name), optional `@sel`. After `--`: argv of the app. | `--roc pinned\|installed` (value): compiler choice. `--allow-unchecked`: use unchecked cached build. `--slots`. `--git`, `--path <dir>`, `--resolve`: see "Differences" (code answers "not built yet"). `--json`: exit 2. | Builds and caches a binary under `talon/x/<digest>/`; runs it in place of `tln`. Puts nothing on PATH. | Exit code is the exit code of the app. Prints platform URL and hash before the build. Short name does not search the registry (typosquat rule). | R-CM12, R-X1 to R-X5, R-AD7, R-NI8, R-NI9 | CLI:22, CLI:1321-1332; Run:185; `XFlow.roc`, `XCmd.roc` 13-50; Args:236,241,246,247,260 |
| 29 | `x` | `tln x <key> [-- <args>]` | 1: a `[tools]` key of the nearest `talon.toml`, or `owner/app` with no selector (runs the project tool). | as row 28 | Builds/uses the project tool; records project files. | In a project, key or app name with no selector runs the locked project tool. | R-CM12, R-PT11 | CLI:22; Run:185; `XProject.roc` |

### 1.2 Registry and CI commands

| # | Command | Form | Positional args | Flags | What it changes | Notable defaults / implicit behaviour | Rule ids | Code |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 30 | `yank` | `tln yank <tag> [--reason <text>] [--undo]` | 1: a release tag of the current repository (not a version, not a name). | `--reason <text>` (value): reason of the yank. `--undo`: remove the yank. | Writes to the registry (yank state). No local file. | Runs only in a GitHub Actions `workflow_dispatch` job; repository from `$GITHUB_REPOSITORY`. Registry `direct`: exit 2. `--offline`: exit 15. Tag with no indexed release: exit 2. | R-CM21, R-YK1 to R-YK7 | CLI:29; Run:141; `YankFlow.roc`, `YankCheck.roc`; Args:264,266 |
| 31 | `move` | `tln move <old-name> [--to <new-name>] [--undo]` | 1: full `github.com` name `owner/repo` (old name). | `--to <name>` (value): the new name (needed in a job of the old repo). `--undo`: remove the successor (not with `--to`). | Writes the successor to the registry. No header change. | Meaning depends on the job repository: in another repo it moves the old name to that repo; in the old repo `--to` makes an offer (202). Only `workflow_dispatch` job. | R-CM22, R-MV1 to R-MV5 | CLI:30, CLI:405-425; Run:139; `MoveFlow.roc`, `MoveCheck.roc`; Args:265,266 |
| 32 | `share` | `tln share` | none | globals | Nothing written except removing an expired JWT. May call `GET /v1/contributors/me`. | Prints on/off and the false condition of R-SH2, 8 chars of the id, totals, queue size. | R-CM23, R-SH8 | CLI:31, CLI:170-290; Run:171; `ShareFlow.roc` |
| 33 | `share on` / 34 `share off` | `tln share on`, `tln share off` | none | globals | Writes `share` in `config.toml`; `off` empties the queue. | With `direct` `on` writes the setting and warns nothing is shared. Sets no prompt. | R-SH1, R-SH10 | Run:173,175; `ShareFlow.roc` |
| 35 | `share login` | `tln share login` | none | globals | Writes the JWT to `share.json` (makes the file and an id if missing). Network to github.com and the registry. | GitHub device flow; prints a URL and a code on stderr (also with `--quiet`). Registry `direct`: exit 2. `--offline`: exit 15. Declined: exit 13. Does not turn sharing on. | R-SH7, R-SH12 | Run:177; `ShareLogin.roc` |
| 36 | `share logout` | `tln share logout` | none | globals | `DELETE /v1/tokens`; removes the JWT. | With no JWT: exit 0, no request. | R-SH9 | Run:179; `ShareAccountFlow.roc` |
| 37 | `share forget` | `tln share forget` | none | globals | `DELETE /v1/contributors/me`; new id, totals set to 0, JWT removed. | Expired JWT: exit 2; 401: exit 20. Does not change `share`. | R-SH9 | Run:181; `ShareAccountFlow.roc` |

### 1.3 `roc` (compiler manager)

All `roc` forms need a sub word (`Args.needs_sub`, Args:218). `tln roc` alone: "command 'roc' needs a subcommand".

| # | Command | Form | Positional args | Flags | What it changes | Notable defaults / implicit behaviour | Rule ids | Code |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 38 | `roc install` (`add`, `i`) | `tln roc install <id\|name[@sel]>` | 1: nightly tag, release id, `@sel` (short for `roc-lang/roc@sel`), `nightly`, a channel name `reify`, `reify@-1`. A bare word with no `@` is an id, never a sha. | none own. | Downloads a compiler to `<cache>/toolchains/<id>/`; may set `default-roc` when none is set. | The command is the consent for the download (prompt R-NI6, default yes). Prefix of an id is expanded. | R-CM15, R-R8, R-SC10, R-SL2 | CLI:25; Run:143-144; `RocInstall.roc` |
| 39 | `roc install --git` | `tln roc install --git <owner/repo@ref\|@ref>`; `tln roc install @<sha>` | 1: `owner/repo@ref` or `@ref` (= `roc-lang/roc`). A bare `@` plus 7+ hex digits is a sha and needs no `--git`. | `--git` (no value; ref is the operand): source build. | Builds a compiler from source into `toolchains/git-<sha8>/`; may install Zig. | Result id `git-<sha8>`. Branch or tag is fixed to a commit. A commit that is a nightly prints a note. | R-R9 to R-R11, R-R14, R-SL8 to R-SL12 | CLI:25, CLI 6.6 (R-R8 to R-R14); Run:143-144; `GitInstall.roc`, `GitRef.roc:44`; Args:246 |
| 40 | `roc link` | `tln roc link [--copy] [--force] <name> <path>` | 2: a name, a path to a `roc` binary. | `--copy`: copy the binary (id `copy-<name>`). `--force`: replace an existing item. | Writes `toolchains/link-<name>/.talon.json` (no copy) or `copy-<name>/`. | `link-*` and `copy-*` can never be pinned with `roc use`. GC never removes them. | R-CM15, R-R12, R-R13, R-LK1 to R-LK4 | CLI:25, CLI 6.6 (R-R12, R-R13, R-LK2); Run:145; `RocLink.roc`, `Link.roc:36-37`; Args:254,255 |
| 41 | `roc use` | `tln roc use <ref>` | 1: compiler ref: full id, id prefix, `@+N`/`@-N` (relative step), `@latest`, `<channel>@sel`. | `--allow-downloads` (answers R-NI5). Other command flags: none. `--no-check` and `--dry-run` are rejected at parse (R-U4). | Rewrites the header `roc:` pin of each member; for a user channel writes `[toolchain] roc` and `[channels.<n>]` in the root `talon.toml` and removes header `roc:`. May download. | Runs baseline and candidate check (ladder). `git-*`, `link-*`, `copy-*` ids are an error. | R-CM15, R-CS1, R-U1 to R-U6, R-SL7, R-CH14 | CLI:25, CLI 6.6 (R-CS1, R-U1 to R-U6); Run:155-156; `RocUse.roc`, `ManageUse.roc`; Args:238,259 |
| 42 | `roc list` (`ls`) | `tln roc list` | none | globals | Nothing written. | Shows the repo and typed ref of each `git-*` id. | R-CM15, R-R15 | Run:147-148; `RocManage.roc` list! |
| 43 | `roc remove` (`rm`) | `tln roc remove <id>` | 1: id or unique prefix | globals | Removes one compiler dir (never a Zig). | Prefix expanded; ambiguous prefix is an error that lists ids. | R-CM15, R-SC10 | Run:151-152; `RocManage.roc` remove! |
| 44 | `roc default` | `tln roc default <ref>` | 1: id, prefix, nightly, `@sel` | none | Writes `default-roc` in `config.toml` (full id). | Prefix is expanded and the full id stored. May download (command names it). | R-CS2, R-SC13 | Run:149-150; `RocManage.roc` default! |
| 45 | `roc default --git` | `tln roc default --git <owner/repo@ref>` | 1 | `--git`: pick the newest installed `git-*` build of that repo and ref | Writes `default-roc`. | Builds nothing; "none installed" is a failure. | R-R5 | Run:149-150; `GitDefault.roc` |
| 46 | `roc update` (`up`) | `tln roc update [<channel>]` | 0 or 1 channel name | globals | Installs the newest nightly (or newest of the channel); moves `default-roc`. | No project check; does not touch project pins. | R-CS3, R-RU1 to R-RU3, R-CH15 | Run:153-154; `RocManage.roc` update!, `ManageUpdate.roc` |
| 47 | `roc channel add` | `tln roc channel add <name> <URL> [--tag-prefix <p>]` | 2: name, URL (`https://github.com/<o>/<r>[/releases...]` or `<o>/<r>`). | `--tag-prefix <p>` (value; only here) | Writes `[channels.<name>]` to `config.toml`; reads one release list (not with `--offline`). | `add <name>` with no URL copies the table from the project `talon.toml`, no network. `--yes` does not give consent for a project-only channel. | R-CH12, R-CH13 | Run:157-158; `ChannelCmd.roc` 20-60 (the word is an operand, not a sub word) |
| 48 | `roc channel rm` | `tln roc channel rm <name>` | 1 | globals | Removes the table from `config.toml`; installed builds stay. | The word `remove` and `ls` are not accepted here (only `add`, `rm`, `list`). | R-CH13 | Run:157-158; `ChannelCmd.roc:38` |
| 49 | `roc channel list` | `tln roc channel list` | none | globals | Nothing written. | Exit 19 when the project and config disagree. | R-CH13 | `ChannelCmd.roc:39` |

### 1.4 `tool` (global tools)

| # | Command | Form | Positional args | Flags | What it changes | Notable defaults / implicit behaviour | Rule ids | Code |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | `tool install` (`add`, `i`) | `tln tool install <owner/app[@sel]> [--as <name>] [--roc pinned\|installed] [--allow-unchecked] [--slots <n>]` | 1: full name (or an installed tool name); selector: version, range, series, `latest`; a hex sha of 7+ digits (git, no `--git`). A short name must match an installed tool; the registry is not searched. | `--as <name>`: here it is the binary name (not an alias, not a key). `--roc`: compiler choice. `--allow-unchecked`: use a cached build not checked online. `--resolve`: see "Differences". | Builds a binary into `$XDG_DATA_HOME/talon/bin/`; hard link or copy in `~/.local/bin/`; writes `tools.json`. | No selector = "any version": reuse an installed or cached build first (R-B1). `@latest` forces a new build. App header with no `roc:` pin: exit 2. | R-CM16, R-T1 to R-T30, R-B1 to R-B9, R-NI8, R-NI9 | CLI:26, CLI:1221-1320; Run:187-188; `ToolGitFlow.roc`, `ToolFlow.roc`, `ToolInstall.roc`; Args:242,246,247,260 |
| 51 | `tool install --git` | `tln tool install --git <owner/app@ref> [--path <dir>]` | 1: `owner/app@<branch\|tag\|sha>` | `--git`: source build (ref is the operand). `--path <dir>` (value): the app is in a subdirectory. | Same as row 50; `tools.json` records commit and typed ref. | `--git` and `--path` share the code path of rows 50. | R-T23, R-SL8 | CLI 6.4 (R-T23); Run:187; `ToolGit.roc` 12-30, 220-232 |
| 52 | `tool list` (`ls`) | `tln tool list` | none | globals | Nothing written. | Shows libs of glibc builds. Does not show Talon itself. | R-CM16, R-S6 | Run:189-190; `ToolManageFlow.roc` list! |
| 53 | `tool update` (`up`) | `tln tool update [<tool>]` | 0 or 1: key, full name or short name of an installed tool; no selector. No name = all tools. | globals | Rebuilds to the newest release (release), new head (branch), nothing (commit: prints `pinned to commit`). | One prompt covers all downloads (R-NI17). Always builds new. | R-CM16, R-T24, R-T25 | Run:193-194; `ToolUpdateFlow.roc` update! |
| 54 | `tool update talon` | `tln tool update talon [--from-source]` | the word `talon` (or `roc-talon/talon`) | `--from-source`: build tag `v<version>` from source instead of the prebuilt binary | Replaces the `tln` binary and the bin dir entries (`tln`, `roc`); writes the `talon` entry of `tools.json`. | Allowed by Args for any `tool update`, used only for `talon`. No downgrade: prints `current`. Checks sha256 (exit 16). | R-S2 to R-S4, R-FL12 | CLI:76; Run:193-194; `TalonUpdateFlow.roc:97`; Args:248 |
| 55 | `tool rebuild` | `tln tool rebuild [<tool>]` | 0 or 1 tool. `talon`: error. | globals | Rebuilds from the manifest with the same build id. | `tool rebuild talon`: exit 2 (code text says "not built yet"; design names `tool update talon --from-source`). | R-T7, R-NI17, R-S6 | Run:195-196; `ToolUpdateFlow.roc` rebuild!; `ToolManage.roc:231-233` |
| 56 | `tool remove` (`rm`) | `tln tool remove <tool>` | 1: key, full name or short name; no selector. | `--dry-run`: print only. | Deletes the binary, bin dir entry and manifest row. | `--dry-run` here is a different flag from the resolve `--dry-run` (see 3.1). | R-CM16, R-ST11 | Run:191-192; `ToolManageFlow.roc` remove!; Args:240 |
| 57 | `tool remove talon` | `tln tool remove talon [--dry-run] [--remove-tools] [--keep-all]` | the word `talon` | `--remove-tools`: also remove tools (option 2). `--keep-all`: keep tools and compilers (option 3). `--dry-run`: print what it would remove. | Removes the compilers, tools, PATH line, Talon data, then the `tln` binary (4 options). | Non-interactive: option 1 (keep tools, remove the rest). Allowed by Args for any `tool remove`. | R-S5, R-RM1 to R-RM10, R-NI10 | CLI:89; Run:191-192; `TalonRemoveFlow.roc`, `TalonRemove.roc:55-65`; Args:261 |

### 1.5 `cache`, `setup`, help

| # | Command | Form | Positional args | Flags | What it changes | Notable defaults / implicit behaviour | Rule ids | Code |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 58 | `cache gc` | `tln cache gc [--dry-run]` | none | `--dry-run`: print what it would free | Deletes old toolchains, build caches, packages, temps; trims registry copies; takes a lock (busy: prints and exits 0). | Age from `gc-age` (default 30d). Keeps what known projects use. The only cache command that reads the registry setting (a bad value stops it). | R-CM17, R-GC1 to R-GC15 | CLI:27, CLI:1191-1220; Run:159-160; `CacheGc.roc`, `Gc.roc`; Args:240 |
| 59 | `cache clean` | `tln cache clean [--all] [--dry-run]` | none | `--all`: also `packages/` and the build caches. `--dry-run`: print only. | Deletes `talon/index/` and `talon/x/` (and with `--all` more). Never removes toolchains, tools, `compat.db`, `projects.json`. | Prompt R-NI7 (default yes); non-interactive removes with no prompt. | R-GC12 to R-GC14, R-NI7 | Run:161-162; `CacheClean.roc`, `Clean.roc:35`; Args:253 |
| 60 | `cache list` (`ls`) | `tln cache list` | none | globals | Nothing written. | Read only, takes no lock. | R-CM17 | Run:165-166; `CacheShow.roc` list! |
| 61 | `cache dir` | `tln cache dir` | none | globals | Nothing written. | Prints the cache root. | R-CM17 | Run:163-164; `CacheShow.roc` dir! |
| 62 | `setup` | `tln setup [--replace-roc] [--no-modify-path]` | none | `--replace-roc`: answer R-NI13 (replace a foreign `roc` in the bin dir). `--no-modify-path`: answer R-NI14 (do not edit the shell profile). | Makes bin dir entries `tln` and `roc`; edits the shell profile or `GITHUB_PATH`; writes the `talon` entry of `tools.json`; sets the first `default-roc`. | Run by `install.sh`. Safe to run again. No share prompt. | R-CM18, R-ST1 to R-ST16, R-NI13, R-NI14 | CLI:28, CLI:1627-1656 (6.7); Run:183-184; `SetupFlow.roc`, `Setup.roc:38`; Args:262 |
| 63 | `help` / `--help` | `tln help`, `tln --help`, `tln <anything> --help` | `help` as FIRST word; any other words ignored | `--help` anywhere before a bare `--` | Nothing. | Always prints the one general usage text on stdout, exit 0, also for a bad command. Before flag checks. | Q7 (Help.roc:1) | Help:16-32, 36-69; Run:77-81 |
| 64 | `--version` | `tln --version` | none | `--version` anywhere before `--` (after `--help` check) | Nothing. | Prints `tln 0.0.1` on stdout. | Q7 | Help:6, 27; Run:82-85 |
| 65 | (no command) | `tln` | none | globals | Nothing. | Usage on stderr, `error[usage]: no command`, exit 2. | Q7 | Run:88-92 |
| 66 | `roc` proxy | program name `roc` (not a `tln` form) | `roc [+<id>] <roc args>` | none from Talon. `-h`, `--help`, `-V`, `--version`, `version`, `help`, `install` have no target file. | Runs the selected compiler in place of itself; writes `.last-use`; may download (consent by `TALON_AUTO_INSTALL`). | Chosen when the program name is `roc` (Run:70). No Talon flags. | R-PX1 to R-PX7, R-ST8, R-SO1 | CLI:1134-1190; Run:70; `Proxy.roc` 74-75, 180-190 |

Count: 66 rows (65 forms of `tln` plus the `roc` proxy row). Rows 33/34 are one row with 2 spellings.

---

## 2. Flags

### 2.1 Global flags: command by flag matrix

`Y` = `Args.allows` accepts it. `-` = rejected at parse (exit 2, `flag '<f>' is not for '<cmd>'`). `Y*` = accepted at parse, rejected later by the command code. Source: Args:231-272.

| Command | `--json` | `--yes` | `--offline` | `--quiet` | `--registry` | `--file` |
| --- | --- | --- | --- | --- | --- | --- |
| `init` | Y | Y | Y | Y | Y | - |
| `install` / `add` / `i` | Y | Y | Y | Y | Y | Y |
| `remove` | Y | Y | Y | Y | Y | Y |
| `update` | Y | Y | Y | Y | Y | Y |
| `upgrade` | Y | Y | Y | Y | Y | Y |
| `outdated` | Y | Y | Y | Y | Y | Y |
| `why` | Y | Y | Y | Y | Y | Y |
| `probe` | Y | Y | Y | Y | Y | Y (not with a `--smoke` URL) |
| `list` | Y | Y | Y | Y | Y | Y |
| `patch` | Y | Y | Y | Y | Y | Y |
| `verify` | Y | Y | Y | Y | Y | Y |
| `audit` | Y | Y | Y* (exit 2: audit reads the index of now) | Y | Y | Y |
| `publish` | Y | Y | Y* (exit 15) | Y | Y | Y |
| `path` | Y | Y | Y | Y | Y | Y |
| `run` (no name) | Y | Y | Y | Y | Y | - |
| `run <name>` | Y* (exit 2) | Y | Y | Y | Y | - |
| `x` | - | Y | Y | Y | Y | - |
| `yank` | Y | Y | Y* (exit 15) | Y | Y | - |
| `move` | Y | Y | Y* (exit 15) | Y | Y | - |
| `share` | Y | Y | Y | Y | Y | - |
| `share on` / `off` | Y | Y | Y | Y | Y | - |
| `share login` / `logout` / `forget` | Y | Y | Y* (exit 15) | Y | Y* (`direct`: exit 2) | - |
| `roc use` | Y | Y | Y | Y | Y | Y |
| `roc install`, `link`, `list`, `remove`, `default`, `update`, `channel` | Y | Y | Y | Y | Y | - |
| `tool install`, `list`, `update`, `rebuild`, `remove` | Y | Y | Y | Y | Y | - |
| `cache gc`, `clean`, `list`, `dir` | Y | Y | Y | Y | Y | - |
| `setup` | Y | Y | Y | Y | Y | - |

Facts about the global group:
- `--yes`, `--offline`, `--quiet`, `--registry` are accepted by every command (Args:237), also by commands that never read them (the design says a command that uses no registry does not read or check `--registry`, R-RG7 row 6; `cache dir`, `list`, `path`, `tool list`). The parse does not tell the user that the flag was ignored.
- `--help` and `--version` are not in `allows`; `Help.route` reads them first (Help:25-28), so they bypass every flag check.
- `--registry` and `--file` are stored in dedicated fields; the later value wins (`apply`, Args:155-156). Other flags are in `options`, and the code reads them with `find_first`, so the first value wins (for example `Opts.roc:value_of`, `Run.roc:option_value`).
- `--json` is read from the whole line before the parse, also after the word that failed (Args:84-88). After a bare `--` it is not read.
- A flag value that starts with `-` is not taken as a value: `--reason -x` gives "needs a value" (Args:136, `is_flag`).
- `--name=value` is split only when the name starts with `--` (Args:130). `--platform=x` on `install` is "takes no value".
- Flags may stand before the command word: `tln --json list` is valid (Args:98-103); a flag with no command at all gives "flag '--x' needs a command" (Args:169).

### 2.2 Command flags: where each is allowed (from `Args.allows`)

`resolving` = `install`, `remove`, `update`, `upgrade`, `verify` (Args:234).

| Flag | Takes a value? (Args:221-228) | Commands that accept it at parse (Args line) | Parsed, then rejected later |
| --- | --- | --- | --- |
| `--frozen` | no | resolving (239) | all but `install` with no names (R-FL13): `remove`, `update`, `upgrade`, `verify`, and `install` with names |
| `--no-probe` | no | resolving (239) | |
| `--no-check` | no | resolving (239) | `upgrade` with a free nightly (R-UP9); `roc use` is rejected at parse because it is not in `resolving` |
| `--snapshot <log:N\|time>` | yes | resolving (239) | |
| `--strategy highest\|lowest` | yes | resolving (239) | `upgrade --strategy lowest` |
| `--dry-run` | no | resolving, `cache gc`, `cache clean`, `tool remove` (240) | `verify` |
| `--slots <n>` | yes | resolving, `probe`, `tool install`, `x` (241) | value not a whole number of 1 or more |
| `--as <x>` | yes | `install`, `tool install` (242) | `install` with 2+ names |
| `--no-pin` | no | `install`, `update` (243) | ignored when the selector is not an exact version |
| `--platform` | yes for `init` only; no for `install` (226) | `install`, `init` (244) | `install` with 0 or 2+ names; `init package` |
| `--ci <github\|none>` | yes | `init` (245) | other values |
| `--git` | no | `tool install`, `x`, `roc install`, `roc default` (246) | `x --git` ("not built yet") |
| `--path <dir>` | yes | `tool install`, `x` (247) | `x --path` ("not built yet") |
| `--from-source` | no | `tool update` (248) | |
| `-i` | no | `update` (249) | with names; non-interactive |
| `--diff` | no | `patch` (250) | |
| `--tree` | no | `list` (251) | |
| `--range`, `--share`, `--smoke` | no | `probe` (252) | `--smoke` with `--range` or `--share`; `--range` or `--share` with no operand |
| `--target <t>` | yes, `probe` only (224) | `probe` (252) | without `--smoke` |
| `--all` | no | `cache clean` (253) | |
| `--force` | no | `remove`, `roc link` (254) | |
| `--copy` | no | `roc link` (255) | |
| `--rename-keys` | no | `install` (256) | |
| `--allow-moves` | no | `install`, `update`, `upgrade` (257) | |
| `--probe-downloads` | no | `upgrade`, `probe`, `init`, `publish` (258) | |
| `--allow-downloads` | no | resolving, `probe`, `roc use`, `init` (259) | |
| `--roc <pinned\|installed>` | yes | `tool install`, `x` (260) | other values |
| `--allow-unchecked` | no | `tool install`, `x` (260) | |
| `--resolve` | no | `tool install`, `x` (260) | both: "not built yet" |
| `--remove-tools`, `--keep-all` | no | `tool remove` (261) | |
| `--replace-roc`, `--no-modify-path` | no | `setup` (262) | |
| `--tag-prefix <p>` | yes, `roc channel` only (225) | `roc channel` (263) | |
| `--reason <text>` | yes | `yank` (264) | |
| `--to <name>` | yes | `move` (265) | |
| `--undo` | no | `yank`, `move` (266) | `move` with `--to` |
| `--ignore <item>` | yes | `audit` (267) | bad item format |
| `--tool` | no | `install`, `remove`, `update`, `upgrade` (268) | `install --tool` with 0 or 2+ names; any flag outside `--tool --as --snapshot --dry-run --allow-downloads` |
| `--each`, `--keep-going` | no | `run` (269) | |

### 2.3 Same flag name or same operand shape, different meaning (raw facts)

Same flag name:

| Flag | Meanings |
| --- | --- |
| `--as <x>` | `install`: alias of a header entry (Roc identifier). `tool install`: binary name. `install --tool` (and `add --tool`): key of `[tools]`. |
| `--dry-run` | resolving commands: run all steps, write nothing, still queue and send share facts (R-SH4 item 12). `cache gc`, `cache clean`: print what would be removed. `tool remove` (`tool rm talon`): print what would be removed. `verify`: rejected. `init`, `publish`, `yank`, `move`, `share *`, `roc *` except none: rejected at parse. |
| `--force` | `remove`: remove an entry that app modules import, skip the check. `roc link`: replace an existing link or copy. |
| `--platform` | `install`: a flag with no value; the platform ref is the operand. `init`: a flag that takes a value. |
| `--git` | A flag with no value in `tool install`, `x`, `roc install`, `roc default`; the ref is the operand (`--git owner/app@main`). In the design table the ref reads like the value of `--git`. |
| `--path` | `tool install`, `x`: directory of the app inside a git source. (`--file` is the project file; `path` is also a command.) |
| `--roc <v>` | value `pinned` or `installed`. Also `roc` is a command word, a `tln upgrade roc` operand, and `roc:` in a header. |
| `--target <t>` | `probe --smoke` only. Not the `roc build --target`. |
| `--range` | `probe`: compiler range search. In `install` operands a range is a selector (`@^1.2`), not a flag. |
| `--snapshot` | `log:N` (registry only) or an RFC 3339 time. |
| `--all` | `cache clean` only. |
| `--keep-all`, `--remove-tools` | `tool remove talon` only. |
| `--undo` | `yank`: removes the yank. `move`: removes the successor. |
| `--to` | `move`: new name. |
| `--registry <url\|direct>` | global; accepted everywhere, read by some. |
| `--share` | `probe --share`: send facts now. `share` is also a command and a `config.toml` key. |
| `--tool` | flag on `install`, `remove`, `update`, `upgrade` that changes the operands from package refs to tool refs/keys. `tool` is also a command word. |
| `-i` | `update` only. It is the only short flag. `-h` is read only by the `roc` proxy; `tln -h` gives "flag '-h' needs a command". |
| `--version` | `tln --version` prints the version. In `install.sh` it chooses a release. In the `roc` proxy it goes to the compiler. |
| `--json` | rejected for `x`; for `run` rejected only with a script name; accepted everywhere else. |
| `--yes` | answers each prompt except the consent prompt R-NI16. For install scripts it is `-Yes`/`TALON_YES=1`. |

Same operand shape:

| Shape | Meanings |
| --- | --- |
| `owner/repo` | package in `install`/`update`/`remove`/`why`/`probe`; app in `tool install`, `x`; platform in `init --platform` and `install --platform`; repo in `roc install --git`; old name in `move`; contains the compiler repo in `roc ... @sel` short form. |
| `name` (no slash) | header alias, or short name (needs a registry for `install`; searches installed tools for `tool`, `x`), or key of `[tools]` (`x`, `--tool`), or a channel name (`roc install reify`), or a script name (`run`), or a template (`init app`). The scope decides (R-SC1 to R-SC5). |
| `@sel` | In `tln roc`, `@sel` alone is `roc-lang/roc@sel`. In packages it follows a name. `@-1`/`@+1` is a compiler step. |
| `@<7+ hex>` | git sha (no `--git`) when no release matches; a series of digits only reads as a series first. |
| a word `roc` | `upgrade roc` = free the nightly; `tln roc ...` = compiler manager; `roc` proxy. |
| `talon` | `tool update talon`, `tool remove talon`, `tool rebuild talon` have own rules; `tln` itself is `roc-talon/talon`. |
| `.tar.zst` path | `probe`: bundle file. `x`/`tool install`: not accepted. |
| URL | `probe --smoke`: release URL (starts `https://` or `http://`). `roc channel add`: GitHub URL. `--registry`: base URL. Not accepted as `install` operand (R-SL1 has no URL form). |
| `<tag>` | `yank` takes a release tag; `roc install` takes a nightly tag; `--tag-prefix` takes a prefix text. |
| a path | `roc link <name> <path>`: path to `roc`; `--file <path>` project file; `--path <dir>`; `probe <bundle file>`. |

Two flags or forms that do similar things:

| Pair | Fact |
| --- | --- |
| `--yes` and `--allow-downloads` and `TALON_AUTO_INSTALL=yes` | All answer a required compiler download; `--yes` answers all prompts, the other two only downloads. `--roc pinned` also counts as consent for the pinned download. |
| `--probe-downloads` and `--yes` | Both opt in to optional probe downloads. |
| `--no-check` and `--no-probe` | `--no-check` skips the whole-app check and the build; `--no-probe` is a resolve flag of Resolution 12 (read, "changes nothing in P0" per `Opts.roc:36`). |
| `--dry-run` and `verify` | `verify` is "resolve and print, write nothing" and rejects `--dry-run`. |
| `--frozen` and `--offline` | `--frozen` (install with no names): header is the truth, no index call. `--offline`: cache only. |
| `--force` and `--rename-keys` / `--allow-moves` | Each answers or skips a different prompt or check. |
| `tln install` (no names) and `tln install --frozen` | Both fetch the closure; only `--frozen` makes no index call. |
| `tln add X` and `tln update X@sel` | Same behaviour when X is a header alias and a selector is given (R-AD22). |
| `tln install --tool` and `tln tool install` | Project tool in `talon.toml` vs global tool in `tools.json`. |
| `tln x <app>` and `tln tool install <app>` | Same build; x leaves nothing on PATH. |
| `tln roc use` and `tln roc default` and `ROC_TOOLCHAIN` and `roc +<id>` | Project pin, global default, env, one-run argument. |
| `tln roc update` and `tln upgrade roc` | Newest compiler, global default and no check vs project pin with check. |
| `tln share on`/`off` and `config.toml share` and `DO_NOT_TRACK` and `probe --share` | The setting, the setting writer, an opt-out variable, a one-off send. |
| `tln cache gc` and `tln cache clean` | Age-based keep-what-is-used vs remove on request. |
| `tln remove` and `tln tool remove` and `tln roc remove` | Header entry, global tool, compiler. |
| `tln list`, `tln roc list`, `tln tool list`, `tln cache list` | Closure, compilers, tools, cache. |
| `tln probe` and `tln verify` | Both run probes; `probe` writes facts for a target, `verify` resolves a tuple. |
| `tln outdated` and `tln audit` and `tln why` | Read-only reports, all with registry reads. |

---

## 3. Aliases, short forms, hidden and deprecated forms

Source: `long_form` (Args:189-196), `top_level` (Args:199-204), `sub_words` (Args:207-214).

| Alias | Long form | Where it works | Notes |
| --- | --- | --- | --- |
| `rm` | `remove` | top level, `tool`, `roc` | `cache` has no `remove` |
| `ls` | `list` | top level, `tool`, `roc`, `cache` | Not in `share`. Not for `roc channel` (its words are `add`, `rm`, `list`). |
| `i` | `install` | top level, `tool`, `roc` | |
| `add` | `install` | top level, `tool`, `roc` | The design files call `install` "tln add" |
| `up` | `update` | top level, `tool`, `roc` | `upgrade` has no alias |
| `help` | (not a command in `top_level`) | first word only, handled by `Help.route` | Listed in the usage text. Not in the CLI R-CM table. |
| `-i` | (flag) | `update` | only short flag |
| `-h`, `-V` | | `roc` proxy only | `tln -h` is a usage error |
| `x` | (single letter command) | top level | `tln x`; no long form |
| `@sel` | `roc-lang/roc@sel` | `tln roc` scope | R-SL2 |
| `nightly-<date>-<sha>` | `roc-lang/roc@nightly-...` | `tln roc` scope | |
| `nightly` | `nightly@latest` | `tln roc` scope (R-SC10) | exact word, not a prefix |
| `<name>` | `<name>@latest` | channel refs (R-CH8) | |
| `X.x`, `2`, `0.25` | `^X`, `^2`, `^0.25` | selectors | R-SL15 |
| id prefix (`git-dd03`, `nightly-2026-10-09`) | full id | `tln roc ...` and `roc +<id>` by hand only | not in `ROC_TOOLCHAIN`, header pin, `.roc-version`, `talon.toml` |
| `tln add` / `tln i` | `tln install` | rule says one command, no rule for one spelling only (R-CM20) | |

Hidden or not documented in `--help`:
- `tln path` and `tln run` are real commands but are not in the usage text (Help:41-62).
- `roc channel add|rm|list` is a command, but `roc channel` appears in no `--help` line and not in the R-CM15 synopsis (it is in CLI 6.8).
- `tln roc channel <word>`: the word is an operand, not a sub word (Args does not know it).
- `--tool` on `install`, `remove`, `update`, `upgrade` changes the command meaning; the usage text does not show it.
- `tln share on|off|login|logout|forget`: the usage text shows only `share`.
- `--file` is not in the usage text's flag line (Help:65).
- Per-command flags are in no help text; there is no per-command help (`tln install --help` prints the one general text).
- The `roc` proxy form (program name `roc`) has no Talon flags.
- Test hooks (env): `TALON_GITHUB_API`, `TALON_GITHUB_RAW`, `TALON_GITHUB_WEB`, `TALON_ZIG_INDEX`, `TALON_NOW`.
- Deprecated forms: none are named in the design or the code. `.roc-version` is read as a hint but not written (R-IN4).

---

## 4. Environment variables that change command behaviour

CLI R-EV1 to R-EV29 (CLI:323-366). "Code" is the file in `cli/lib/` that reads the name (checked with grep). A flag wins over a variable (R-EV1).

| Variable | Value | Effect | Commands | Code |
| --- | --- | --- | --- | --- |
| `TALON_REGISTRY` | URL or `direct` | Registry, priority 2 after `--registry` | all that use a registry | `Registry.roc`, `Net.roc`, `Setting.roc` |
| `TALON_NIGHTLY` | `0`, `1` | The `nightly` switch | resolving, `roc` | `Intent.roc`, `ResolveSelect.roc` |
| `ROC_TOOLCHAIN` | full compiler id | Compiler selection (rank 2) | all that select a compiler, proxy | `Compiler.roc`, `Proxy.roc` |
| `TALON_AUTO_INSTALL` | `ask`, `yes`, `no` | Required compiler and Zig downloads: ask, accept, refuse (exit 13) | `add`/`update`/..., `tool install`, `x`, proxy | `Consent.roc`, `Proxy.roc` (89 uses) |
| `TALON_PROXY` | `0` | Proxy does no extra work | proxy | `Proxy.roc` |
| `TALON_IN_PROXY` | `1` | Set by the proxy for its child | proxy | `Proxy.roc` |
| `TALON_INTERACTIVE` | `1`, `0` | Overrides `CI`, `DEBIAN_FRONTEND`, `NONINTERACTIVE`; not the TTY test and not `--json` | prompts | `Mode.roc:22-29` |
| `CI` | `true`/`1` any case | Non-interactive; also turns off sharing | prompts, share | `Mode.roc:18`, `Share.roc:34` |
| `DEBIAN_FRONTEND` | `noninteractive` | Non-interactive | prompts | `Mode.roc` |
| `NONINTERACTIVE` | `1`, `true` | Non-interactive | prompts | `Mode.roc` |
| `NO_COLOR` | any | No color | all | `Mode.roc:43-46` |
| `DO_NOT_TRACK` | set, not empty, not `0` | No automatic sharing; `probe --share` still sends | share | `Share.roc` |
| `TALON_SHARE_ASKED` | exactly `1` | No first-run share prompt; set for children | all | `FirstRun.roc`, `Prompt.roc` |
| `GITHUB_TOKEN`, `GH_TOKEN` | token | GitHub API token (then `gh auth token`) | `direct`, `roc`, `publish`, ... | `Net.roc`, `Github.roc` |
| `GITHUB_REPOSITORY`, `GITHUB_REF`, `GITHUB_EVENT_NAME`, `GITHUB_SERVER_URL`, `ACTIONS_ID_TOKEN_REQUEST_URL`, `ACTIONS_ID_TOKEN_REQUEST_TOKEN` | CI values | Inputs of `publish`, `yank`, `move` | those 3 | `Publish.roc`, `YankCheck.roc`, `MoveCheck.roc` |
| `GITHUB_PATH` | file | `setup` appends the bin dir | `setup` | `SetupFlow.roc` |
| `TALON_DOWNLOADER` | `curl`, `wget` | Download program | downloads | `Download.roc` |
| `ZIG` | path | Zig for source builds | `roc install --git`, `tool install --git` | `Zig.roc:58` |
| `XDG_CACHE_HOME`, `ROC_CACHE_DIR`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `HOME` | paths | Directory roots | all | `Roots.roc` |
| `TALON_NOW` | RFC 3339 UTC | Test hook: clock for ages. Bad value: exit 2 | all with ages | `Clock.roc` (49 uses) |
| `TALON_GITHUB_API`, `TALON_GITHUB_RAW`, `TALON_GITHUB_WEB`, `TALON_ZIG_INDEX` | URL | Test hooks. `TALON_GITHUB_API` also turns off the GitHub token. | as named | `Net.roc`, `Zig.roc`, `ShareLogin.roc` |
| `TALON_SCRIPT`, `TALON_SCRIPT_DIR` | | Set by `tln run` for steps (written, not read) | `run` | `RunPlan.roc` |
| `TALON_YES` | `1` | Install script does not prompt | `install.sh`, `install.ps1` | scripts only |
| `TALON_DOWNLOAD_BASE`, `TALON_REPO` | URL, repo | Install script mirror | scripts | `install/` |
| `TALON_LOG_KEY` | key | Log verifier key (design only: 8 mentions in the design, none in `cli/lib/`) | | not found in code |
| `TALON_BIN_DIR`, `TALON_DEL_*` | | Internal: set for a PowerShell helper; Windows delete names | `setup`, Windows | `Setup.roc:211`, `DelFlow.roc` (not in the R-EV table) |

### config.toml keys (CLI 6.1, `ConfigToml.roc:124`)

| Key | Effect | Commands | In design? | In code `config_keys`? |
| --- | --- | --- | --- | --- |
| `default-roc` | global compiler (rank 6); written by `roc default` | compiler selection | yes | yes |
| `registry` | registry (priority 3) | registry commands | yes | yes |
| `nightly` | nightly switch; `talon.toml` wins | resolving, `roc` | yes | yes |
| `min-release-age` | default `2d`; `talon.toml [resolution]` wins | resolving, `roc install`, `tool install`, `x`, `init` | yes | yes |
| `min-release-age-exclude` | patterns that skip the age | same | yes | yes |
| `gc-age` | default `30d` | `cache gc` | yes | yes |
| `share` | `true`/`false`; not set = off; written by `share on/off` | share, first-run prompt, probes | yes | yes |
| `tool-binaries` | `false` = no prebuilt project-tool binary | `install`, `run`, `x` for project tools | yes | yes |
| `log-key` | log verifier key | log proofs | yes | no (not in `config_keys`) |
| `[channels.<name>]` (`shape`, `source`, `tag-prefix`) | user compiler channel; written by `roc channel add` | `roc *`, resolving | yes | yes (`channels`) |
| `[probe]` (`max`, `timeout`, `slots`, `max-toolchains`) | probe limits | probes | not in the 6.1 sample; "same keys as `[resolution] probe`" | yes (`probe`) |

`talon.toml` keys that change command behaviour (not config): `[toolchain] roc|nightly|tln`, `[resolution] priority|strategy|min-release-age|min-release-age-exclude|snapshot|probe`, `[audit] ignore`, `[dependencies]` ranges, `[overrides]`, `[patch]`, `[tools]`, `[scripts]`, `[run] after`, `[workspace] members`, `[channels]` (known tables at `Intent.roc:176`).

---

## 5. Differences between design and code

| # | Design says | Code does | Where |
| --- | --- | --- | --- |
| D1 | `tln --help` lists the commands | Usage text has no line for `path` (R-CM25) and `run` (R-CM24). It lists `help`, which is not in the R-CM table. | Help:41-62 |
| D2 | `--file` is a global flag (R-FL6) | The usage text names `--json --yes --offline --quiet --registry --help --version` only. `--file` is not named. No per-command flag is named. | Help:64-65 |
| D3 | R-FL12 `--probe-downloads`: `upgrade`, `probe`, `init` | Also `publish` (code accepts it; R-PUB4 mentions it in running text). | Args:258 |
| D4 | R-FL12 `--allow-downloads`: `install`, `add`, `remove`, `update`, `upgrade`, `verify`, `probe`, `init` | Also `roc use` (R-NI5 does list `roc use`; R-FL12 does not). | Args:259 |
| D5 | R-FL13/R-FL14: `--frozen` on a command other than `install` with no names is exit 2; `verify` rejects `--dry-run` | The same exit code 2, but at two layers: `Args.allows` accepts `--frozen` for `remove`, `update`, `upgrade`, `verify` and `--dry-run` for `verify`, then the command rejects it. The message differs (`works only for tln install with no names` vs `is not for '<cmd>'`). | Args:239-240; `Update.roc:60`, `Upgrade.roc:40`, `Verify.roc:49-54` |
| D6 | `--dry-run` is own-meaning flag of `cache gc`, `cache clean`, `tool rm talon` | Args accepts it on every `tool remove` (not only `talon`). | Args:240 |
| D7 | `--from-source` for `tool update talon` | Args accepts it on every `tool update`. | Args:248 |
| D8 | `--path <dir>` "with a git ref" | Args accepts it without `--git`. | Args:247 |
| D9 | `--keep-going` "with `--each`" | Args accepts `--keep-going` without `--each`. | Args:269 |
| D10 | `tln x` has `--git`, `--path`, `--resolve` (R-FL12, R-X1) | `x` answers `tln x <flag> is not built yet` for each of the three. `tool install --resolve` is "not built yet" too. | `XCmd.roc:30-32`; `ToolGit.roc:183` |
| D11 | `tln x <key>` runs a project tool (R-PT11) | `XFlow` tries `XProject.run!` first (a miss goes on to the normal path). `XCmd.read` still says `tln x needs one app: owner/app` when there is no operand. | `XFlow.roc:33,47`; `XCmd.roc:21` |
| D12 | `tln tool rebuild talon`: exit 2 and names `tln tool update talon --from-source` (R-S6) | exit 2 with `tln tool rebuild talon is not built yet`. | `ToolManage.roc:231-233` |
| D13 | R-CM15 synopsis: `tln roc install/link/use/list/remove/default/update` | `roc channel` exists (6.8, R-CH12) but is missing from the R-CM15 synopsis and from the usage text. Its words (`add`, `rm`, `list`) are checked in `ChannelCmd`, not in `sub_words`. | Args:209; `ChannelCmd.roc:34-38` |
| D14 | `--ignore <item>` repeatable: `[--ignore <item>]...`; `--json` listed in the audit synopsis | `--ignore` repeat is read; `--json` is global. | `AuditCheck.roc:241` |
| D15 | `TALON_LOG_KEY` and config `log-key` (CLI 7.6) | Not found in `cli/lib/`; `config_keys` has no `log-key`. | design 7.6; `ConfigToml.roc:124` |
| D16 | Env table R-EV has no `TALON_BIN_DIR`, `TALON_DEL_*`, `TALON_DOWNLOAD_BASE` | Code reads or sets them. | `Setup.roc:211`; `DelFlow.roc` |
| D17 | R-FL1: "Global flags work for every command" | `--json` is rejected for `x`; `--file` is rejected for 8 groups of commands (Args:238); `run <name>` rejects `--json` in `RunCmd`. R-FL6 says `--file` is rejected by other commands. | Args:236,238 |
| D18 | R-CM2: `[--platform] [--tool] [--as] [--no-pin] [--no-check]` | With `--tool` only `--tool --as --snapshot --dry-run --allow-downloads` are allowed; `--no-check`, `--no-pin`, `--platform` give exit 2. | `ToolsCmd.roc:105-125` |
| D19 | R-CM12 `tln x owner/app [-- args]` | The words after the bare `--` are in `Args.passthrough`. `--help`, `--version` and `--json` are read only before the `--`. `tln x app --help` shows the `tln` usage, not the app help. | Args:97; Help:21-28 |
| D20 | R-CM4: `[-i] [--no-pin] [--no-check] [--tool]` | Args also accepts every resolve flag for `update`. R-CM4 omits `--allow-moves`, `--dry-run`, `--snapshot`, `--strategy`. (They are in R-FL7/R-FL8.) | Args:234-241,257 |

---

## 6. Parse order and implicit rules (facts)

1. `Help.route` runs first: `--help` anywhere (before a bare `--`) or `help` as the first word prints the usage and exits 0; then `--version`. Flag errors never show.
2. `Args.parse`: flags and words are read left to right. The first word is the command. A second word is read as a sub word only for `roc`, `tool`, `cache`, `share` (Args:112-119). `share` has an optional second word.
3. A word that starts with `-` and is longer than 1 byte is a flag (Args:91). The word `-` alone is an operand.
4. A bare `--` ends the walk. Everything after it is `passthrough` (Args:97).
5. Checks run at the end (`finish`): missing sub command; then the first flag, in line order, that `allows` rejects.
6. `check_refs` (Run:203-220) parses the operands of `install`, `update`, `upgrade`, `remove`, `why`, `patch` as refs before the command runs, unless `--tool` is present.
7. `FirstRunFlow.before!` may show the share prompt (R-NI16) before the command, except for `share`, `setup`, `--help`, `--version`.
8. `dispatch!`: `--tool` anywhere wins (Run:109); then the command; `probe` with `--smoke` or `--target` goes to the smoke flow (Run:133).
9. A command that parses but has no branch gives exit 1: `command '<x>' is not built yet` (Run:198).
10. `tln` with a `Windows` host first deletes `.del` files (Run:69).
