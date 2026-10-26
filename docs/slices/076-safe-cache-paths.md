# 076 Safe cache paths from outside input

Phase: P1. Status: done

Slice 076 is the plan row 076 of `PLAN-P1.md` (section 2c). It is a security fix. The report of slice 068 found that `Github.repo_dir` joins the `owner` and the `repo` of a header URL with no check (`Ident.github_name` only checks that they are not empty). So an owner or a repo `..` makes `releases!` write `1.json` and `1.meta` outside `talon/index/github/`. Slice 068 added the guard `Github.safe_part` for the hint cache only. This slice (1) lists each place where a text from outside becomes part of a path (section 1), (2) moves the guard to `Ident.safe_part`, so that one guard serves every module, and (3) fixes the places that are not safe. The manager answered Q1 to Q3 (section 8), so A4, A5, A9 and A10 are fixed in this slice too. The slice follows `docs/agents/BRIEF-tests.md`. The copies of the changed files, the stubs and the private reference are in `research/slice-076-revert/`.

## 1. Audit: where outside input becomes part of a path

Outside input is: a part of a header URL (owner, repo, tag, hash), a typed name, a `talon.toml` value, a header alias, an id, a JSON answer of GitHub or of the Zig index, a name in a directory listing. "Fixed" means that this slice changes it. Each row was read in `cli/lib`.

| # | Place | Input | Source | Safe today | Why | State after the slice |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | `Github.repo_dir` (dir of the pages of `releases!`: `<index>/github/<owner>/<repo>`) | `owner`, `repo` | Header URL (`Ident.name`), typed name (`tln add ../..`, `tool install`, `x`, `init --platform`: `Ref.form_of` lets `..` through as a `Full` name) | No | `github_name` checks only "not empty". `..` as owner gives `talon/index/`, as repo `talon/index/github/`, both `talon/` | Fixed: `Github.index_dir`, `Github.bad_repo` (D1, D2) |
| A2 | `Github.hint_file`, `hint_ref` (cache file of the hint) | `owner`, `repo`, `tag` | Header URL | Tag: yes. Owner and repo: no | Slice 068 guards the 3 parts, but the dir came from `repo_dir` | Same guard (`Ident.safe_part`), through `index_dir` |
| A3 | `Fetch.plan` (`<pkgs>/<hash>`, `<pkgs>/<hash>.<hex>.tmp`), `Roots.item(Package(hash))` and `PackageDeps(hash)` in `ToolInstall.layout`, `ProbeBundle`, `ToolFlow`, `Init`, `Gather`, `PathCmd`, `PatchApply`, `Uses` | `hash` | The last segment of a release URL, less `.tar.zst` (header, `[tools]` `url`, a release asset URL) | No | `PackageUrl.parse` (generic package) checks only "not empty". A URL that ends `/...tar.zst` has the hash `..`: the item is `<pkgs>/..` (the cache dir) and the temp is `<pkgs>/...<hex>.tmp`. A backslash is a separator on Windows | Fixed in `Ident.of_url`: an unsafe hash is `Err(Foreign)` (D3) |
| A4 | `Patched.entry_of`, `PatchApply.base_check!` and `rebase_one!`: `Package(entry.base)` (list, read and copy-from) | `[patch] base` | `talon.toml` (a cloned repository) | No (read only) | The text is used as a hash with no check. `base = ".."` reads the whole cache. No write | Fixed (Q1): `Intent.read` gives exit 19 |
| A5 | `Patched.entry_of` `file`/`dir` from `[patch] path`: `PatchApply.finish!` does `delete!` and `copy_tree!` on `entry.dir` | `[patch] path` | `talon.toml` (a cloned repository) | No (delete and write outside the project) | `Text.resolve(dir_of(toml), path)` has no "inside the project" check. `path = "../../x/main.roc"` deletes and writes `../../x/` on `tln install` and `tln update` | Fixed (Q2): `Patched.check_inside`, exit 19 (D6, D7) |
| A6 | `PatchCmd` (`.talon/patches/<alias>/`), `PatchApply.build_all!` (`<root>/<alias>`) | alias | Header | Yes | A header alias is a word of `Lex.is_word_byte` (letters, digits, `_`, `!`), and a `[patch]` key counts only when it equals a header alias (`Patched.entry_of`) | None |
| A7 | `Roots.item` of `Toolchain(id)`, `ToolchainRoc`, `ToolchainMeta`, `ToolchainLastUse`, `Compat`, in `Launch`, `Proxy`, `RocInstall`, `RocManage`, `Gc`, `GitInstall`, `GitDefault`, `TalonRemove` | compiler id | `roc +<id>`, `ROC_TOOLCHAIN`, `.roc-version`, header `roc:`, `[toolchain] roc`, `default-roc`, `tln roc <id>`, the tag of a nightly release, the sha of a git ref | Yes | A nightly is `Selector.is_nightly_tag` (digits, a month name, a hex sha). A release is `Semver`. A named build is `git-`, `link-` or `copy-` and `Compiler.is_safe_name` (no `/`, no `\`, no white space), and `Link.read` checks the same. A git id is `git-` and 8 chars of `is_full_sha`. `roc +<id>` is not checked in `Proxy.split`, but an id that is not in `toolchains/` is `Missing` and `RocInstall.offer!` refuses it in `Nightlies.pick`. `default-roc` (`ConfigToml.is_default_id`) takes any text after `git-`, but it is the config of the user, not a project file | None |
| A8 | `Item.Zig(version)` (`toolchains/zig-<version>`) | `version` | Zig index key (network) | Yes | `Zig.pick` takes only keys `X.Y.Z` of digits. `Zig.candidates` lists only `zig-<X.Y.Z>` dirs | None |
| A9 | `Toolchain.plan` `archive` = `<temp>/<asset name>` | asset `name` | GitHub API (`roc-lang/nightlies`) | Yes in practice, not by construction | The name starts with `roc_nightly-<target>-` (never `.` or `..`) and GitHub asset names have no `/`. A `TALON_GITHUB_API` test hook could serve a `/` | Fixed (Q3): the asset does not count |
| A10 | `Zig.plan` `archive` = `<temp>/<last segment of the tarball URL>` | tarball URL | Zig index (`ziglang.org`, `TALON_ZIG_INDEX`) | No (low) | `Text.last_segment` has no `/`, but it can be `..`, `.`, empty or have a `\`. `curl --output <temp>/..` fails: it is a dir | Fixed (Q3): the failure "no archive" |
| A11 | `Compat(id)` | compat id | `.talon.json` of a compiler (a file of the cache) | Yes | Talon wrote the file. A cloned repository cannot write the cache | None |
| A12 | `XBuild(digest)`, `x/<digest>/<file>` | digest | `XCache.digest`: sha256, 64 hex digits | Yes | A computed value. `<file>` is the repo name (see A15) | None |
| A13 | `TalonTmp(hex)`, `Temp.name`, `.lock`, `.tmp` names | hex | `Fx.random!`, `Temp.hex` | Yes | 16 hex digits | None |
| A14 | `Github.page_files` (`<n>.json`, `<n>.meta`) | `n` | A counter. The `next` URL of a `Link` header is a URL only | Yes | A number | None |
| A15 | `ToolInstall.key`, `file_name`: `<data>/bin/<key>`, `x/<digest>/<file>`, `tools.json` | binary name | `--as` (checked: `is_binary_name`), `[tools]` key (checked: `ToolsToml.is_key`), default = the text after the last `/` of `owner/app` (not checked) | Yes after A1 | The default name has no `/`, and `owner/..` stops in `releases!` before any write (A1). `.hidden` is one part. `ToolInstall.foreign_failure` refuses a file that Talon did not write | None (A1 covers it) |
| A16 | `[scripts]` `in = "<dir>"` (R-RUN8) | dir | `talon.toml` | Yes | `RunPlan.inside` compares after `Text.resolve` removed `..`. A script name is a table key and never a path | None |
| A17 | Path entries (`lib: "lib/main.roc"`): `Closure`, `Scan`, `Gc`, `PathCmd` | relative path | Header | By design (R-H7) | Read only, relative to the header file. Talon never writes the file that a path entry names (R-H4) | None |
| A18 | `Link.read`: `link-<name>`, `copy-<name>`, the path | name, path | Typed | Yes | The name has no `/`, no `\`, no white space and does not end in `.lock` or `.tmp`. The path is the file of the user, by design | None |
| A19 | Archive members of `roc unbundle` and `tar -xf` | member names | Package, compiler and Zig archives | Not Talon code | R-SE9: `roc unbundle` checks the paths, `tar` refuses `..` | None (design) |
| A20 | `Gc`, `CacheGc`, `Trash`, `TalonRemove`, `Del`: paths made from the names of a `list_dirs!` of the cache | dir entry names | The file system | Yes | A name from the file system has no `/`. A compiler dir must pass `Compiler.is_compiler_dir` | None |
| A21 | `TalonUpdate.asset_name` (`tln-<target>`), the `Bin` file of `talon` | fixed text | The code | Yes | Fixed names | None |

Result: 5 places are not safe (A1, A3, A4, A5, A10) and 1 is not safe by construction (A9). All 6 are fixed here and have tests (A1 and A3 by the design rules, A4, A5, A9 and A10 by the manager answers Q1 to Q3).

## 2. Rules

| Id | Text (short) | Tested by |
| --- | --- | --- |
| R-ID3 (Design 4.1) | `owner/repo` is the name of a GitHub release URL. An owner or a repo that is not a safe path part gives no name (`Err(NoName)`, as for another host): no index call is made for it | L0 `IdentTest` expect 4. L2 `index/di-list-flow` runs 18 to 20 |
| R-ID5, R-H4 (Design 4.1, 4.2) | The content id is the hash of the URL. A URL whose hash is not a safe path part has no hash in the form of 4.1: it is foreign (R-H4). Talon never makes a path from it | L0 `IdentTest` expect 4, `FetchTest` expect 1, `ToolsplanTest` expect 2. L2 `fetch/fe-flow` run 19 |
| R-DI1 (CLI 7.3) | Talon lists releases only for a group that it can name (the foreign URL and the unsafe name have no listing) | L2 `di-list-flow` runs 18 to 20: no `list_dirs`, no request |
| R-DI2 (CLI 7.3) | The cache pages of a repository are in `talon/index/github/<owner>/<repo>/`: only for safe parts | L0 `GithubTest` expect 8 |
| R-EC2 (CLI 3) | A bad ref is exit code 2 | L0 `GithubTest` expect 8 (`bad_repo`), L2 `di-list-flow` runs 18 to 20 |
| R-EC19, R-PA12 (CLI 3, Resolution 7) | A `[patch] base` that is not a safe path part is a value of the wrong form: exit 19, before any read (Q1) | L0 `IntentTest` expect 2 (4 rows). L2 `patch/pa5-unsafe-patch` run 1 |
| R-PA9, R-RUN8, R-EC19 | The copy dir of a `[patch]` entry is strictly inside the repository, else exit 19 before any read, delete or write (Q2, D6, D7) | L0 `PatchedTest` expect 10 (13 rows). L2 `pa5-unsafe-patch` runs 2 and 3 |
| R-D2, R-CV2, R-SE9 | A Zig archive name or a nightly asset name that is not a safe path part is refused (Q3) | L0 `ZigTest` expect 12, `NightliesTest` expect 13 |
| R-RG6 (CLI 1, a name that GitHub does not know: exit 2, no registry request) | The same exit code and the same kind for an owner or a repo that GitHub cannot have | Same rows |

`MISSING=1 scripts/rules.sh R-ID R-DI R-H` lists no id after this slice that it listed before.

## 3. Flow

| Step | Call | Rule |
| --- | --- | --- |
| 1 | `Github.releases!` first calls `Github.index_dir`. `Err(BadPart)` returns `Err(Github.bad_repo(...))` at once: no `list_dirs!`, no `programs!`, no `http_get!`, no `write_atomic!` | R-DI2, R-EC2 |
| 2 | `Github.hint_file` uses `index_dir` (the owner and the repo) and `Ident.safe_part` (the tag). `Github.hint_ref` uses `Ident.safe_part` for the 3 parts | R-DI8 |
| 3 | `Ident.of_url`: a hash that is not `Ident.safe_part` is `Err(Foreign)`. An owner or a repo that is not `Ident.safe_part` gives `name: Err(NoName)` and `label: Err(NoName)`, and the other fields are as before | R-ID3, R-ID5, R-H4 |
| 4 | Each caller of `of_url` already handles `Foreign` (R-H4) and `NoName` (R-SC6): `Fetch.plan` gives exit 2 `<url> is not a package release URL`, `ToolsToml` gives the issue `tools.<key>.url: '<url>' is not a release URL with a version and a hash` (exit 19), a header entry is unmanaged | R-H4, R-EC19 |

Q1 to Q3 add these steps (the manager answers of section 8):

| Step | Call | Rule |
| --- | --- | --- |
| 5 | `Intent.read`: a `[patch]` entry with a string `base` that is not `Ident.safe_part` is an issue of kind `Input` (exit 19) on the line of the key: `patch.<key>.base: '<base>' is not a hash`. It comes before any read of a package | R-EC19, R-PA12 |
| 6 | `PatchApply.run!`, first step after `wanted`: for each member with a patch, `Patched.check_inside({ entries, stop: Patched.stop(...) })`. A failure is exit 19 before the first read, delete or write | R-PA9, R-RUN8, R-EC19 |
| 7 | `Zig.pick`: a tarball URL whose last segment is not `Ident.safe_part` is the failure `no_archive` (exit 18). `Nightlies.read_asset`: a name that is not `Ident.safe_part` is `NotAsset`, so the release has `NoAsset` | R-D2, R-CV2, R-SE9 |

## 4. Public signatures (the code agent keeps them)

| Function | Signature | Stub |
| --- | --- | --- |
| `Ident.safe_part` | `Str -> Bool`. True: not empty, not `.`, not `..`, no `/`, no backslash, no NUL byte | `crash "todo: slice 076"` |
| `Github.index_dir` | `{ roots : Roots, owner : Str, repo : Str } -> Try(Str, [BadPart])`. Replaces `Github.repo_dir` (the code agent removes `repo_dir` and the private `safe_part`) | same |
| `Github.bad_repo` | `{ owner : Str, repo : Str } -> Fail`. Kind `Usage`, text `'<owner>/<repo>' is not a GitHub repository name` | same |

| `Patched.stop` | `{ workspace : Try({ root : Str, members : List(Str) }, [Standalone]), toml : Str } -> Str`. The workspace root, else the dir of the `talon.toml` (D6) | same |
| `Patched.check_inside` | `{ entries : List(Patched.Entry), stop : Str } -> Try({}, Fail)`. Each `dir` strictly below `stop` (or `stop` is `/`), else kind `Input`, `patch.<alias>.path: '<path>' is outside the repository (<stop>)` | same |

The behavior changes of `Ident.of_url`, `Github.releases!`, `Github.hint_file` and `Github.hint_ref` have no new signature. The code agent writes the 5 bodies and the guard calls in these 4 functions, and in these places (all with a one-line change, no new signature): `Intent.read` (an issue for a bad `[patch] base`, in `read_tables`), `PatchApply.run!` (calls `Patched.stop` and `Patched.check_inside` for each member that has a patch, before its first read, as the first step after `wanted`), `Zig.pick` (a tarball URL whose last segment is not `Ident.safe_part` is the failure `no_archive`, before the sha256 check) and `Nightlies.read_asset` (a name that is not `Ident.safe_part` is `NotAsset`). Message of the `base` issue: `patch.<key>.base: '<base>' is not a hash` (line of the key). No other module changes.

## 5. Files

| Path | Lines | State |
| --- | --- | --- |
| `cli/lib/Ident.roc` | 69 | The stub `safe_part` (+6) |
| `cli/lib/Github.roc` | 430 (limit 490) | The stubs `index_dir` and `bad_repo` (+10) |
| `tests/unit/IdentTest.roc` | 124 (+64) | 2 new `expect`s (3 and 4) |
| `tests/unit/GithubTest.roc` | 267 (+32) | 1 new `expect` (8) and one changed line (section 7) |
| `tests/unit/FetchTest.roc`, `tests/unit/ToolsplanTest.roc` | +20, +3 | New rows in an old `expect` |
| `tests/commands/cases/index/di-list-flow/` | 20 runs (+3) | 3 new runs, 3 lure files in `fx/http/`, new expected files |
| `tests/commands/cases/fetch/fe-flow/` | 19 runs (+1) | 1 new run, new expected files |
| `cli/lib/Patched.roc` | 175 | The stubs `stop` and `check_inside` (+10) |
| `tests/unit/IntentTest.roc`, `PatchedTest.roc`, `ZigTest.roc`, `NightliesTest.roc` | +4 rows, +30, +20, +24 | Q1 to Q3: 4 rows in an old `expect`, and 3 new `expect`s (`PatchedTest` 10, `ZigTest` 12, `NightliesTest` 13) |
| `tests/commands/cases/patch/pa5-unsafe-patch/` | 3 runs (new case) | Q1 and Q2: 3 projects, an `outside` dir, `rules`, expected files |

## 6. Tests

| Layer | File and case | Content | Rule ids |
| --- | --- | --- | --- |
| L0 | `IdentTest` expect 3 | `Ident.safe_part`: 21 rows (8 safe: a name, a hash, `v1..2`, `a.b`, `.hidden`, `...`, `-x`, a space. 13 not safe: empty, `.`, `..`, `a/b`, `/a`, `a/`, `../x`, `x/..`, backslash inside, backslash only, `..\x`, NUL inside, NUL only) | R-ID3 R-H4 R-DI1 |
| L0 | `IdentTest` expect 4 | `Ident.of_url`, 15 rows: a safe URL, dots inside the 3 parts, an owner `..`, `.`, a repo `..`, `.`, both `..`, a backslash in owner and in repo, NUL (all: `name` and `label` are `Err(NoName)`, hash and version stay). A hash `..`, `.`, with a backslash, with NUL, and a hash `..` on another host (all: `Err(Foreign)`) | R-ID3 R-ID5 R-H4 R-DI1 |
| L0 | `GithubTest` expect 8 | `Github.index_dir`, 17 rows (a repository, dots and hyphens inside, and `Err(BadPart)` for an owner or a repo that is `..`, `.`, empty, with `/`, climbing, with a backslash or NUL) and `Github.bad_repo` (kind `Usage`, exit 2, the text) | R-DI2 R-ID3 R-EC2 |
| L0 | `FetchTest` expect 1 (3 new rows) | `Fetch.plan` of a URL with a hash `..`, `.` or with a backslash: exit 2, `<url> is not a package release URL` | R-ID5 R-H4 |
| L0 | `ToolsplanTest` expect 2 (2 new rows) | `[tools]` `url` with a hash `..` and with a backslash: exit 19 on the line of the key | R-ID5 R-H4 R-EC19 |
| L2 | `index/di-list-flow` runs 18 to 20 | `releases ../acme`, `releases acme/..`, `releases ../..`: exit 2, `'<owner>/<repo>' is not a GitHub repository name`, no call at all. The fake index has a 200 page at each path that the name would reach, so a missing guard writes `talon/index/acme/1.json`, `talon/index/github/1.json` and `talon/1.json` (the tree diff shows it) | R-ID3 R-DI1 R-DI2 R-EC2 |
| L2 | `fetch/fe-flow` run 19 | 2 URLs with a hash `..` and with a backslash: both exit 2 with the old text, and the only calls are `random` and `list_dirs` of `packages` (no download, no unbundle, no rename onto `<pkgs>/..`) | R-ID5 R-H4 |

| L0 | `IntentTest` expect 2 (4 new rows) | `Intent.read` of a `[patch] base` that is `..`, has a `/`, has a backslash (on line 3 after another entry) or is empty: exit 19, `patch.json.base: '<base>' is not a hash` (Q1) | R-EC19 R-PA12 |
| L0 | `PatchedTest` expect 10 | `Patched.check_inside` and `Patched.stop`, 13 rows: the default dir, a dir below the stop dir with `..`, an absolute path inside (all `Ok`), a path that climbs out, one that climbs out below the stop dir, an absolute path outside, a dir with the same start as the stop dir (`/p2` for `/p`), the stop dir itself (all exit 19), the stop `/`, no entry, the first bad entry, the stop of a workspace and of a standalone project (Q2) | R-PA9 R-RUN8 R-EC19 |
| L0 | `ZigTest` expect 12 | `Zig.pick`, 7 rows: a name and dots inside a name are archives. A last segment `..`, `.`, empty, with a backslash or a NUL byte gives the failure `no archive` (exit 18) (Q3) | R-D2 R-SE9 |
| L0 | `NightliesTest` expect 13 | `Nightlies.releases`: an asset name with `/`, `../..`, a backslash or a NUL byte is `NoAsset`, and a good asset of the same release still counts (Q3) | R-CV2 R-SE9 |
| L2 | `patch/pa5-unsafe-patch` runs 1 to 3 | `tln install` with a `[patch]` of base `..` (exit 19, line 2, before any read of a package), of path `../outside/main.roc` and of the absolute path `/elsewhere/main.roc` (exit 19, `patch.json.path: ... is outside the repository`). The dir `$PROJECT/outside` (2 files) has no call at all (no read, delete or copy) and no line in the tree diff | R-EC19 R-PA9 R-PA12 R-RUN8 |

L0 count (after Q1 to Q3): 6 new `expect`s (`IdentTest` 2, `GithubTest` 1, `PatchedTest` 1, `ZigTest` 1, `NightliesTest` 1) and 9 new rows in 3 old `expect`s, in 8 files (drivers `l0-1`, `l0-2`, `l0-3`, `l0-6`, `l0-8`). Deep cases: 3 L2 cases (4 new runs and the new case `pa5-unsafe-patch`).

Old count of the first version: 3 new `expect`s (`IdentTest` 2, `GithubTest` 1) and 5 new rows in 2 old `expect`s, in 4 files (drivers `l0-1`, `l0-2`, `l0-6`, `l0-8`). No new module. Deep cases: 2 L2 cases (4 new runs).

## 7. Changes of old tests (TW21)

The copies are in `research/slice-076-revert/before/`.

| Test | Change |
| --- | --- |
| `GithubTest` expect 1 | The line `dir = Github.repo_dir(...)` is `dir = Github.index_dir(...) ?? ""` (the code agent removes `repo_dir`). The expect is red until `index_dir` has a body |
| `di-list-flow` `expect/*` | New lines at the end for the runs 18 to 20. The old lines do not change. `rules` has a new paragraph |
| `fe-flow` `expect/*` | New lines at the end for run 19. `rules` has a new paragraph |

No other old test changes. The old L2 and L3 cases all pass with the stubs (175 L2 cases pass, 2 are red on purpose).

## 8. Questions (answered) and decisions for review

Manager answers of 2026-10-25 (the manager records them for a design edit). They are in this slice, because A5 can delete a dir outside the repository:

| # | Question | Answer | Tests |
| --- | --- | --- | --- |
| Q1 | A `[patch] base` that is not a safe path part (A4) | Exit 19 (R-EC19), before any read | L0 `IntentTest` expect 2, L2 `pa5-unsafe-patch` run 1 |
| Q2 | A `[patch] path` outside the repository (A5) | Yes, it must be inside, with the same check and exit as R-RUN8 (exit 19), before any delete or write | L0 `PatchedTest` expect 10, L2 `pa5-unsafe-patch` runs 2 and 3 (R-RUN8 takes an absolute path too: it is outside unless it is below the stop dir) |
| Q3 | A Zig archive name or a nightly asset name that is not a safe part (A9, A10) | Yes, refused before any write. The exit is the one of the existing failure: Zig `no archive` (exit 18), a nightly asset is `NoAsset` | L0 `ZigTest` expect 12, `NightliesTest` expect 13 |

Decisions of the test agent that the design does not fix (for review):

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | `releases!` with an unsafe owner or repo is `Usage`, exit 2 (R-EC2 "bad ref"; R-RG6 gives exit 2 for a repository that GitHub does not know), with no call. `bad_repo` names `'<owner>/<repo>'` | Exit 19 (the input is not a Talon file when it is typed). A failure with no message (a bad ref needs its text) |
| D2 | The guard is at the one place that makes the dir (`index_dir`), not in `Ref.form_of`: a typed `../..` is a legal `Full` name for the parser, and `Ref` has no `owner` rules. Each caller of `releases!` (`PickIndex`, `ToolFlow`, `Init`) is covered with no change | A check in each caller (3 places, and a 4th later) |
| D3 | An unsafe hash is `Err(Foreign)` in `Ident.of_url` (R-H4: "no hash in the form of 4.1"). So every caller that handles `Foreign` handles it, and no `Package(hash)` is made from it | A new error tag (each caller of `of_url` would change). A check only in `Fetch.plan` (the other 8 `Package(hash)` places would stay open) |
| D4 | An unsafe owner or repo gives `name: Err(NoName)` (R-ID3: "other URLs: `Err(NoName)`"), and the URL stays a release URL (the hash and the version are right) | `Err(Foreign)` for the whole URL (a header entry whose owner is odd but whose hash is fine would lose its version) |
| D6 | The repository of Q2 is the workspace root for a workspace, else the dir of the `talon.toml` (`Patched.stop`). `Request` has no stop dir of R-PD2 (the walk is not kept), and a new field would change each `Request` of the tests. A standalone project is its own repository (R-PD5, R-PD6). The effect: a patch dir of a standalone project must be below the dir of its `talon.toml` (the default `.talon/patches/<alias>/` is) | The stop dir of R-PD2 (it needs a new field or a second walk, with new calls in all the old L2 cases of the patches) |
| D7 | The check is strict: the copy dir must be below the stop dir, not equal to it (R-RUN8 allows `dir == stop` for an `in` dir, which only runs a command). A rebase deletes the copy dir, so `path = "./main.roc"` would delete the repository | The same check as `RunPlan.inside` |
| D8 | The check is in `PatchApply.run!` (the one place that deletes and writes a copy dir), not in `Intent.read`: the stop dir is not known there. The proxy only reads the path (`--replace-dep`) | A check in the proxy too (no write there) |
| D5 | `Ident.safe_part` is the one guard (a method of `Ident`, the module of the URL rules). `Github` imports `Ident`. The guard has no rule of the character set (a space is safe: one path part) | A new module (`Ident` has the callers already). A guard that also checks base58 (the hash charset is the decision of the generic package `roc-app-header`, R-GP) |

## 9. Out of scope

| Part | Reason |
| --- | --- |
| Windows rules (reserved names, `:`, trailing dots) | The slice guards the parts that climb out of a root. Windows names are a separate rule (P1, Windows CI) |
| A symbolic link inside the cache | An attacker that can write the cache has no need for a URL |
| `roc unbundle` and `tar` (A19) | R-SE9: not Talon code |
| `Ref.form_of` for `..` | D2 |

## 10. Red output

With the stubs in the tree (the private reference away; `Intent.roc`, `PatchApply.roc`, `Zig.roc` and `Nightlies.roc` are the old files, so their rows fail with a wrong value).

| Step | Result |
| --- | --- |
| check, fmt | pass. `roc fmt --check` of the changed `.roc` files: exit 0 |
| l0 | FAIL (7.1 s): `l0-1` `IdentTest` expects 3 and 4 and `PatchedTest` expect 10 (3 failed, `todo: slice 076`), `l0-2` `GithubTest` expects 1 and 8 (`todo: slice 076`), `l0-3` `IntentTest` expect 2 and `NightliesTest` expect 13 (wrong value), `l0-6` `FetchTest` expect 1 and `ZigTest` expect 12 (wrong value), `l0-8` `ToolsplanTest` expect 2 (wrong value) |
| l2 | FAIL (7.9 s), 3 cases red, 175 pass: `index/di-list-flow` (the calls `list_dirs`, `http_get`, `write_atomic` for the 3 names, and `talon/1.json`, `talon/index/acme/1.json`, `talon/index/github/1.json` in the tree diff), `fetch/fe-flow` (download, unbundle and rename calls for the 2 URLs), `patch/pa5-unsafe-patch` (the run goes on to the reads of the base and the copy) |
| l3, selftest | pass |

With the private reference in the tree, `scripts/test.sh` exited 0 (7 steps).

## 11. Revert check (TW12)

10 changes of the private reference, one at a time, with filtered runs (L0 `l0`, L2 `index/ fetch/ patch/`). All 10 are caught. The reference, its script and its hash file are deleted (manager, 2026-10-25); `before/` stays.

| Id | Change | Caught by |
| --- | --- | --- |
| m1 | `Ident.safe_part` is always true (no guard) | L0 `l0-1`, `l0-2`, `l0-6`, `l0-8`. L2 `di-list-flow`, `fe-flow` |
| m2 | `releases!` joins the dir by hand (no `index_dir` call) | L2 `di-list-flow` only (L0 passes: it is a wiring fault) |
| m3 | `Ident.of_url` keeps a hash that is not safe | L0 `l0-1`, `l0-6`, `l0-8`. L2 `fe-flow` |
| m4 | `github_name` checks only "not empty" (the old rule) | L0 `l0-1` (`IdentTest` expect 4) |
| m5 | `index_dir` checks the owner only | L0 `l0-2` (`GithubTest` expect 8). L2 `di-list-flow` |
| m6 (Q1) | `Intent.read` gives no issue for a bad `[patch] base` | L0 `l0-3` (`IntentTest` expect 2). L2 `pa5-unsafe-patch` |
| m7 (Q2) | `PatchApply.run!` does not call `check_inside` | L2 `pa5-unsafe-patch` only (L0 passes: wiring) |
| m8 (Q2) | `check_inside` lets the stop dir itself pass | L0 `l0-1` (`PatchedTest` expect 10) |
| m9 (Q3) | `Zig.pick` has no guard for the archive name | L0 `l0-6` (`ZigTest` expect 12) |
| m10 (Q3) | `Nightlies.read_asset` has no guard for the name | L0 `l0-3` (`NightliesTest` expect 13) |

## 12. Next step

The manager reviews the new tests (Q1 to Q3, D6 to D8). Then the code agent writes the 5 bodies of section 4 and the guard calls of section 3 (status `code`). The private reference is deleted; `research/slice-076-revert/before/` has the old files and `stubs/` the files with the stubs.

## 13. Verify results (code agent, 2026-10-25)

Code: `Ident.safe_part` and its use in `Ident.of_url` (hash) and `github_name` (owner, repo), `Github.index_dir` and `Github.bad_repo` (`repo_dir` and the private `safe_part` removed; `hint_file`, `hint_ref` and `releases!` use the guard), `Patched.stop`, `Patched.check_inside` (private `below`), `Intent.read` (private `patch_issues`), `PatchApply.run!` (private `check_all`), `Zig.pick`, `Nightlies.read_asset`. No dispute, no question, no decision beyond the slice. `scripts/test.sh` exit 0 (check, fmt, l0, l2 178 of 178, l3, selftest, l1). Filtered runs (l0, l2), one change at a time. The code is the same as before the mutations (`cmp` with `code-final/`).

| # | Mutation | Test that failed |
| --- | --- | --- |
| 1 | `releases!` joins the dir by hand | L2 `index/di-list-flow` |
| 2 | `Ident.of_url` keeps an unsafe hash | L0 `ToolsplanTest` expect 2 (and others) |
| 3 | `index_dir` checks the owner only | L0 `GithubTest` expect 8, L2 `di-list-flow` |
| 4 | `Intent.read` has no issue for a bad `base` | L0 `IntentTest` expect 2, L2 `patch/pa5-unsafe-patch` |
| 5 | `PatchApply.run!` does not call `check_inside` | L2 `patch/pa5-unsafe-patch` only |
| 6 | `check_inside` lets the stop dir pass (`starts_with(stop)`) | L0 `PatchedTest` expect 10 |
| 7 | `Zig.pick` has no archive guard | L0 `ZigTest` expect 12 |
| 8 | `Nightlies.read_asset` has no name guard | L0 `NightliesTest` expect 13 |
| 9 | `Ident.safe_part` lets `..` pass | L0 and L2 (`pa5-unsafe-patch`) |

Caught 9 of 9.

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-076-revert/code-final.sha256` | OK |
| `crash "todo` in cli/ and packages/ | None |
| `scripts/test.sh` (manager run) | Exit 0, all 7 steps, 178 L2 cases |
| Patch path check | `Patched.entry_of` makes `dir` with `Text.resolve`, which drops `.` and `..` parts first, so `sub/../../x` cannot pass the prefix check |
| Gap step | Skipped: 9 of 9 code-agent mutations caught (10 with the test agent's), no new decision that needs a test |
| Left open | Symlinks inside the repository or the cache (out of scope in the slice file) |
