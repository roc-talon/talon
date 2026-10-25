# 045 Git install

Phase: P1. Status: done

Slice 045 is `tln roc install --git` (CLI 6.6, R-R1 to R-R3, R-R5 to R-R7, R-R9 to R-R11): Talon fixes a branch, tag or sha of a GitHub repo to a commit, gets the source archive, reads the Zig version from `build.zig.zon` (slice 044), runs `zig build`, and installs the result as `git-<sha8>`. It also has `tln roc default --git owner/repo@branch` (R-R5, the review row of slice 024b) and the nightly note (R-R2). One review row of slice 020 is in this slice: the `named.contains` branch of `Nightlies.by_name`. It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-045-revert/before/` (with `NEW.txt`). The private reference is deleted after the review (TW21; `restore.sh` puts the stubs back in `cli/lib`, which holds the stubs now).

Size (TW19): the private reference has 549 lines with comments and blank lines in 4 new modules (`GitRef.roc` 138, `GitBuild.roc` about 137, `GitInstall.roc` about 270, `GitDefault.roc` 31), plus 3 lines in `RocInstall.roc`, 13 in `RocManage.roc`, 4 in `Run.roc` and 4 in `main.roc`. The plan row says 200. No module has more than 450 lines, so no split is needed. `GitInstall.roc` copies `spawn_one!` and `learn_compat!` of `RocInstall.roc` (private there): the code agent can make them public in a helper module instead (note N3).

Live reads (2026-10-25, one time each, to check the fixtures): `GET /repos/roc-lang/roc/commits/main` gives JSON with a top-level `sha`. With `Accept: application/vnd.github.sha` it gives the 40 hex digits as plain text (also for a short sha). An unknown ref gives 422, an unknown repo 404. `GET /repos/roc-lang/roc/tarball/<short sha>` redirects (302) to `codeload.github.com/.../legacy.tar.gz`. The top dir of the archive is `roc-lang-roc-<sha7>`. The real `build.zig.zon` of roc has `.minimum_zig_version = "0.17.0",` (copy: `research/slice-045-revert/build.zig.zon.roc-cf42a74`).

## 1. Rules, and the tests that name them

| Rule | Content | Tested by |
| --- | --- | --- |
| R-R1 | id `git-<sha8>`. `.talon.json` has repo URL, full sha, the typed ref | L0 `GitTest` expects 2, 5, 6. L2 `gi1-install` runs 1, 3, 4. L3 runs 1, 3, 4 |
| R-R2 | The commit is a nightly: the note, no prompt, the build goes on | L0 `GitTest` expect 4. L2 `gi1-install` run 3. L3 run 4 |
| R-R3 | `GET <api>/repos/<o>/<r>/tarball/<sha>`, `zig build roc -Doptimize=ReleaseFast -Dcompiler-version=git-<sha8>` | L0 expects 2, 5. L2 runs 1, 3, 4, 6 of `gi1-install`, run 2 of `gi2-zig`. L3 runs 1 to 4, 7 |
| R-R5 | Selection like a nightly. `tln roc default --git owner/repo@branch` takes the newest installed build of that branch | L0 expects 1, 9. L2 `gi1-install` runs 8, 9, 10. L3 run 3 |
| R-R6 | A branch installed again builds the new head as a new id, the old one stays | L2 `gi1-install` runs 1, 2. L3 runs 1, 2, 3 |
| R-R7 | curl over https only, sha256 computed and recorded, tar extracts to a temp dir | L0 expects 6, 7. L2 `gi1-install` runs 1, 7. L3 runs 1, 5, 6 |
| R-R9, R-R10, R-R11 | `--git @main`, `--git Karakatiza666/roc@my-branch`, `@dd03c09e` (no `--git`) | L0 expect 1. L2 `gi1-install` runs 1, 3, 4. L3 runs 1, 4 |
| R-SE12 | A source archive has no published hash, so tar is the guard (`..`), and curl refuses a redirect to http | L2 `gi1-install` run 6 (as a failure). L3 runs 5, 6 |
| R-DA3 | wget: exit 18 that names curl | L0 expect 7. L2 `gi1-install` run 7 |
| R-SO15 (as used) | The first compiler is the default | L2 `gi2-zig` run 2. L3 run 1 |
| R-D1 to R-D4 (as used) | The Zig from `build.zig.zon`, the list, the prompt before the lock | L2 `gi2-zig` runs 1, 2. L3 run 1 |
| R-EV19, R-DI12, R-DI13, R-RG3 (as used) | `TALON_GITHUB_API`. `--offline` stops before a request. A rate limit. The token of the commit request (review Q1) | L0 expects 2, 3. L2 `gi1-install` runs 4, 5, 11 |
| R-CC2 to R-CC5 (as used) | temp dir, lock, check again under the lock, `.talon.json` last, rename | L2 `gi2-zig` runs 3, 4. L3 runs 1, 5, 6 |
| Review row 020 | `Nightlies.by_name`: `named.contains` for a non-nightly id that is the prefix of another id | L0 `NightliesTest` (the last `expect`) |

`MISSING=1 scripts/rules.sh R-R1 R-R2 R-R3 R-R5 R-R6 R-R7 R-R9 R-R10 R-R11 R-SE12 R-DA3` lists none (checked with the stubs in `cli/lib`).

## 2. Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/GitRef.roc` | 108 | Stubs from the test agent. Bodies from the code agent | New pure module. 12 signatures and the type `Source`, bodies `crash "todo: slice 045"`. The contract is in the doc comments |
| `cli/lib/GitBuild.roc` | 56 | Same | New pure module. 6 signatures and the type `Plan` |
| `cli/lib/GitInstall.roc` | 28 | Same | New command module. `run!` forwards to `RocInstall.run!` (so the old tests pass). The doc has the table of the 13 steps, in order |
| `cli/lib/GitDefault.roc` | 17 | Same | `run!` forwards to `RocManage.default!`. The doc has the 4 steps |
| `cli/lib/RocInstall.roc` | 411 (+4) | Test agent | The public `first_default!` (calls the private `set_default!`). Real code, 1 line |
| `cli/lib/RocManage.roc` | 367 (+5) | Stubs | `set_default!` : `crash "todo: slice 045"` |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | +4, +4 | Test agent | `["roc", "install"]` goes to `GitInstall.run!`, `["roc", "default"]` to `GitDefault.run!`. The 4 modules are in the exposes list |
| `tests/unit/GitTest.roc`, `tests/unit/l0-3.roc` | 291, +1 | Test agent | 9 `expect`s, red. The module is in the driver `l0-3` |
| `tests/unit/NightliesTest.roc` | +1 expect | Test agent | The gap row of slice 020, green on the old code |
| `tests/commands/cases/roc/gi1-install`, `gi2-zig` | 2 cases | Test agent | L2, 11 + 4 runs, red. Each has `rules` |
| `tests/commands/cases/roc/gi3-nozon` | 1 case, 1 run | Test agent (gap step) | L2, a copy of the fixture of `gi1-install` with a `build.zig.zon` that has no `minimum_zig_version` (the fake tar copies one file for all runs of a case, so it is a new case) |
| `tests/scenarios/compilers/gi1-git-install/` | 1 case | Test agent | L3, 7 commands, red |
| `tests/tools/mk-git.sh` | 59 | Test agent | The fake GitHub: commit routes and real `.tar.gz` source archives (made once, kept in `given/http/`) |
| `research/slice-045-revert/` | | Test agent | `before/` (7 changed files, with `ZigTest.roc`, `NEW.txt`), `stubs/`, `restore.sh`, `gen-git.py` (makes the `given/` and `fx/` files of the L2 cases and the L3 `given/`, no `expect/`), `mutants.py`, `mutants.log`, `red-*.log` |

## 3. Public signatures

| Item | Type | Rule |
| --- | --- | --- |
| `GitRef.Source` | `{ owner : Str, repo : Str, ref : Str }` (no stub) | R-R1 |
| `GitRef.read` | `{ args, bare_sha : Bool } -> Try(Try(Source, [NotGit]), Fail)` | R-R9 to R-R11, R-R5 |
| `GitRef.repo_url`, `name_text` | `Source -> Str` | R-R1 |
| `GitRef.commit_url`, `commit_headers`, `commit_of` | `{ api, source } -> Str`, `{} -> List((Str, Str))`, `{ source, url, now, status, headers, body } -> Try(Str, Fail)` | R-R1, R-R3, R-DI13 |
| `GitRef.sha_id`, `archive_url` | `Str -> Str`, `{ api, source, sha } -> Str` | R-R1, R-R3 |
| `GitRef.nightly_note` | `{ sha, releases } -> Try(Str, [None])` | R-R2 |
| `GitRef.header_line`, `llvm_target`, `needs_curl`, `offline_failure` | see the doc comments | R-D4, R-D3, R-DA3, R-DI12 |
| `GitBuild.Plan`, `plan`, `build_command` | the paths of one build, the `zig build` words | R-R3, R-CC1 |
| `GitBuild.meta` | `{ id, source, sha, sha256, compat, now } -> Str` (`.talon.json`) | R-R1, R-R7, R-TF1 |
| `GitBuild.build_failed`, `no_binary`, `none_installed` | the failures | R-R3, R-R5 |
| `GitBuild.newest` | `{ source, rows } -> Try(Str, [None])` | R-R5, R-R6 |
| `GitInstall.run!`, `GitDefault.run!` | `Fx, Args => I32` | R-R1 to R-R11 |
| `RocInstall.first_default!` | `Fx, Roots, Str => Try([Set, Kept], Fail)` | R-SO15 |
| `RocManage.set_default!` | `Fx, Args, { roots, id } => I32` | R-R5 |

## 4. Tests

L0 `GitTest` (9 `expect`s, each has table rows that print the wrong rows with `dbg`):

| # | Content | Rules |
| --- | --- | --- |
| 1 | `read`: 29 rows. `--git` with `@main`, `owner/repo@ref`, a sha, `latest`. A sha with no `--git` (`bare_sha`). A nightly tag, `@latest`, `@-1`, no operand, 2 operands: `NotGit` or a usage failure | R-R9 to R-R11, R-SL8, R-SL10, R-SL13, R-FL14, R-R5 |
| 2 | names, `repo_url`, `commit_url` (with the base of `TALON_GITHUB_API`), `commit_headers` (with and without a token, the sha media type), `archive_url` | R-R3, R-R1, R-R9, R-EV19, R-DA3, R-DI9 |
| 3 | `commit_of`: 13 rows (the sha with a line end, short, upper case, 41 digits, JSON, empty, 404, 422, rate limit, 500) | R-SE12, R-R3, R-DI13 |
| 4 | `nightly_note`: 10 rows (first nightly wins, no asset, 2 assets, 8 digit tag, the sha inside a commit but not at its start, empty list) | R-R2 |
| 5 | `llvm_target`: 6 hosts | R-D3 |
| 6 | `plan` and `build_command` | R-R1, R-R3, R-R7, R-CC1, R-CC4, R-LY1 |
| 7 | `meta`: the fields, their order, `compat` null | R-R1, R-R7, R-TF1, R-CV5, R-LY1 |
| 8 | the failures: `needs_curl`, `offline_failure`, `build_failed` (3 endings, with and without a last line), `no_binary`, `none_installed` | R-DA3, R-SE12, R-R3, R-CC2, R-NI6 |
| 9 | `newest`: 19 rows (another repo, another ref, the time and not the text order, unreadable rows, a row with no field; review Q6: a typed sha matches the full `sha` of a build: 7, 8 and 40 digits, a newer build of the same text, fewer than 7 digits, upper case, non-hex, another repo, no `sha` field) | R-R5, R-R1, R-R6 |

`NightliesTest`: one `expect` with `link-dev` and `link-dev2`, `copy-fix-1` and `copy-fix-10`: the exact id wins, a prefix of 2 ids is ambiguous (slice 020 review).

L2 `gi1-install` (11 runs) and `gi2-zig` (4 runs): the tables are in the `rules` file of each case. `gi1-install` has a branch that moved (the old build stays), the same head again, `@main` with the note, `@dd03c09e --json` with `TALON_GITHUB_API`, `--offline`, an unknown ref (422), wget, three `roc default --git` runs (the repo and the ref must both match), and a run with `GITHUB_TOKEN` (the commit request has the `Authorization` header). `gi2-zig` has Zig missing and declined, Zig installed and the first default, a `zig build` that exits 1, and a busy lock whose holder made the dir.

L3 `gi1-git-install` (7 commands, real curl and tar, fake GitHub, fake `zig`): a branch, the same head, a moved branch and `default --git`, `@main` with the note, an archive with a `..` member (exit 16), a redirect to `http://` (exit 15), an unknown ref (exit 2).

## 5. Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| stderr, first line of a build (`--quiet` hides it) | `Build roc from <owner>/<repo>@<ref> (<sha8>)`, then an empty line, then the dependency list of slice 044 (the design example of R-D4) |
| stderr, the note (R-R2, text from the design) | `<sha8> is <tag>. tln roc install <tag> downloads it.` It comes before the header line. `--quiet` hides it |
| stdout and stderr, the answer | The text of `Toolchain.report` (as `roc install <id>`): `installed git-<sha8>` or `git-<sha8> is already installed`, and `git-<sha8> is now the default compiler` for the first compiler. `--json`: the `Toolchain.data` envelope. No new text |
| `.talon.json` | One line: `{"format":1,"id","repo","sha","ref","sha256","sha256_source":"computed","compat","installed_at"}`. `repo` is `https://github.com/<owner>/<repo>`, `sha` is the full sha, `ref` is the typed text |
| LLVM target (R-D3) | `x86_64-linux-musl` (design), `aarch64-linux-musl`, `aarch64-macos`, `x86_64-macos`, `x86_64-windows`, `aarch64-windows` |
| Errors | `tln: error[usage]: no commit <ref> in <owner>/<repo>` (404, 422). `tln: error[network]: GitHub gave no commit sha for <o/r@ref> at <url>`. `tln: error[network]: <o/r@ref> needs a request to find its commit, and --offline is set` (exit 15). `tln: error[environment]: tln roc install --git needs curl, but the download program is wget: a source archive has no published hash, and only curl refuses a redirect to http:// (R-DA3)` (exit 18). `tln: error[internal]: zig build of <id> failed (exit 1): <last line>` and `zig build of <id> made no roc in zig-out/bin`. `tln: error[usage]: tln <typed> --git needs one ref: owner/repo@ref or @ref` and `... takes one ref, got <n>`. `tln: error[usage]: no build of <o/r@ref> is installed. Run: tln roc install --git <o/r@ref>`. A rate limit, a status, a download and a tar failure: the existing texts of `Github` and `Toolchain` |

## 6. Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The commit is found with `GET <api>/repos/<o>/<r>/commits/<ref>` and `Accept: application/vnd.github.sha` (the body is the 40 hex digits). The token is sent as for the release list (review Q1: R-DI9 excludes only an archive and `.roc-version`) | The JSON of the commit (large). `git ls-remote` (needs git) |
| D2 | The lookup is made also for a full 40 digit sha (one rule, and it checks that the commit exists). A short sha is made full by the same request | No request for a full sha |
| D3 | `--offline` fails before any request (exit 15): the commit cannot be known | Look in the installed builds for the ref |
| D4 | The source goes in `<cache>/talon/tmp/<hex>/` (archive, `src/`, the `empty.roc` of the compat check). It is extracted before the lock because the Zig prompt must not be inside a lock. The lock is `fx.locked!(toolchains/<id>)` for the build only | The source in the temp dir of the item (the build would run before the Zig prompt, or the lock would cover a prompt) |
| D5 | The note (R-R2) is best effort: a failed list gives no note, and the build goes on. | A failed list is an error. No note when `--offline` (the lookup already fails) |
| D6 | The first git install sets the default (R-SO15 says "the first compiler") | No default for a source build |
| D7 | A failed `zig build` is kind `Internal` (exit 1), text with the exit code and the last line of its stderr. The temp dir and the scratch dir are deleted (`delete!([temp, scratch])`). On success `delete!([scratch])` | A new kind. Keeping the build tree for a person to read |
| D8 | R-R6 "the old one stays": the id of a branch changes with its head. `tln roc default --git` picks by the `repo` and the `ref` text of `.talon.json` and by `installed_at` as time (not as text) | Pick by the directory name. Pick the newest by sha order |
| D9 | `--git` is a flag, the ref is the one operand (R-SL13). `owner/repo@ref` and `@ref` only. `roc install @dd03c09e` and `owner/repo@dd03c09e` need no `--git` (R-R11). Other bare words go to the old `roc install` | `--git` with a value |
| D10 | The wget check comes after the id check (an installed id needs no download program) and before the note and the header line | Check before the lookup |
| D11 | Calls in order: one `clock!`, `platform!`, the commit `http_get!`, `list_dirs!` (id), `programs!`, the nightly list, then the build. The `calls.log` of `gi1-install` and `gi2-zig` fixes this order | |
| D12 | `ZigInstall.ensure!` gets `llvm: { target, size: Err(Unknown) }`: no size in the LLVM line (slice 044 Q4 accepted) | A size request |

## 7. Out of scope

| Id | Reason |
| --- | --- |
| R-R4, R-LK3 | Done in slice 024b |
| R-DA6 (progress), a real source download, a real `zig build` | The progress is a terminal feature. No real network and no real `zig build` of roc in L0 to L3. The L3 case has a fake `zig` |
| A redirect to `https://` | The L3 fake server cannot serve https. R-SE12 is tested by the refusal of http |
| wget as a real run | Only the refusal of wget is tested (L2). The L3 host has curl |
| The Windows and the macOS L3 | No such host in the fast set. `llvm_target` is a L0 table |
| R-D2 second half (GC of Zig) | Question Q5 of slice 044: a follow-up for the GC code |
| `TALON_AUTO_INSTALL` for the Zig prompt | Slice 044 Q7: ignored, accepted |
| The other `--git` flags (`--git` with `roc run`, `roc link`) | Other slices |

## 8. Questions (TW17), answered in the review (section 13)

The tests did not depend on these answers (fixtures avoid them), except Q1 and Q6, which changed.

| # | Question | Reference (not tested) | Other option |
| --- | --- | --- | --- |
| Q1 | R-R3 says "a branch or tag is fixed to a commit at install time" and does not name the request, the header, or the token. D1 chooses the request | `commits/<ref>` with the sha media type, with the token as the release list (review) | The JSON of the commit with the token. `git/ref/heads/<ref>` |
| Q2 | `--git owner/repo` with no `@ref`, `--git roc-lang/roc` (the default branch?), `--git @`, a name that is not `owner/repo` (3 parts, a host), a ref with `/` | A usage failure with the text `--git takes a GitHub repository as owner/repo, not '<name>'` for a bad name. No row tests a no-ref operand | The default branch of the repo (one more request) |
| Q3 | `build.zig.zon` with no `minimum_zig_version` (slice 044 Q3: "out of scope, slice 045 reads the source tree"). No Zig version is known | `tln: error[input]: build.zig.zon of <o/r@ref> has no minimum_zig_version` (exit 19) | Use the Zig on `PATH` with no check. Use a fixed version |
| Q4 | A dev `minimum_zig_version` (`0.17.0-dev.31+abc`) (slice 044 Q2: a design gap). `Zig.series` and `Zig.wanted` read it as the series `0.17.x` | The series of the number before `-dev` | A failure. The index `master` |
| Q5 | The kind and the code of a failed `zig build`. The design has no code for it (D7) | `Internal`, exit 1 | A new kind (exit 20) |
| Q6 | `roc default --git owner/repo@ref` with no installed build of that ref, and with a sha selector (`--git @dd03c09e`): by the `ref` text of `.talon.json` only a typed `dd03c09e` matches. Should it install the build (as `roc default <id>` does not)? | `none_installed` failure (usage, exit 2). The sha selector matches the typed text only | Install, then set the default. Match `sha` by prefix |
| Q7 | Bare hex that is not a sha: `roc install @deadbee` is a sha selector by R-SL10, but it can be a nightly tag prefix. And `roc install deadbeef` (no `@`) | `@` and 7 or more hex digits is a sha. A word with no `@` is not (it goes to the old command) | A word that is all hex is a sha |
| Q8 | The size of the LLVM bundle and the target names of the other 5 hosts (slice 044 Q4) | No size. The names of section 5 | A request to `roc-lang/roc-bootstrap` |
| Q9 | R-SO15 "the first compiler becomes the default" for a git build: does a git build count as a compiler? (D6) | Yes | A source build is never made the default by itself |
| Q10 | The same repo and ref installed 2 times in one second by 2 processes: the lock of the id covers one head. Two heads at the same time are 2 ids and run in parallel (each runs a Zig build of many minutes) | No limit | One build at a time under a global lock |

## 9. Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-R3: the request that gives a commit, and the form of `<ref>` in it (Q1) |
| G2 | R-R9 to R-R11: `--git` with no `@ref`, and what a bare hex word is (Q2, Q7) |
| G3 | R-D4 against R-R3: where the source is extracted when the Zig prompt comes before the lock (D4). The design example shows the list after the archive is read, and R-DL1 asks for the prompt before the lock |
| G4 | R-R2: "if the commit is a nightly's commit" does not say how it knows the commit of a nightly. The tag has 7 or 8 digits of its commit, so a prefix test is all that is possible (the note text of `nightly_note`). A nightly with no asset for the host is not named |
| G5 | R-R5: "stores the full id" for `roc default --git`; the design does not say which `installed_at` the build has when 2 builds have the same time (the last one in the listing wins) |
| G6 | `build.zig.zon` without the key and the dev version (Q3, Q4) |
| G7 | R-R7: "tar extracts to temp": the archive has a top dir (`<owner>-<repo>-<sha7>`). `tar --strip-components=1` as for the nightlies (`Toolchain.tar_command`) |
| G8 | The `--git` ids are not shown by `tln roc list` with their ref. Not in this slice |

## 10. Compiler and tool limits met

| Limit | Effect | Workaround |
| --- | --- | --- |
| Reserved words (`packages`, `platform`, `app`, `in`, `has`, `imports`, `crash`, `with`, `package`, `var`, `where`, `requires`) | as in slices 044 and 055 | other names |
| `{ x }` alone is a block | a record with one field in a closure | `{ x: x }` or a name for the record |
| `roc build` exits 2 on a warning | an unused import in a stub would fail the build | the stubs have only used imports (checked with `roc build cli/main.roc --opt=dev`: 0 warnings) |
| A bare `Err(..)` in the init of a `fold` has no methods | `newest` in the reference | a `match` on the kept value |
| `keep_oks(...).first()` crashed | `newest` in the reference | `fold` |
| `.gitignore` has `.cache/` | the `given/home/.cache/...` files of the new L2 cases are ignored | `git add -f` |
| `sha256` of the fake archives | the fake curl writes the text `fake` | the same hash in all L2 runs (`b5d54c39...`) |

## 11. Notes for the code agent

| # | Note |
| --- | --- |
| N1 | Do not edit a test (TW18). `tests/commands/cases/roc/gi*/rules` and `fx/commands` have the text of each run. `research/slice-045-revert/gen-git.py` made the `given/` and `fx/` files (do not run it: it would write them again) |
| N2 | The calls of `GitInstall.run!` are the table in its doc (13 steps). The L2 `calls.log` fixes the order, the number of `list_dirs!` (2 in an install: before the download and in the lock), `clock!` (1) and `spawn_all!` |
| N3 | `RocInstall.roc` has the private `spawn_one!`, `learn_compat!` and `set_default!`. The reference copies the first two. `first_default!` (public) is in the stubs. Put the shared code in one module |
| N4 | Reuse `Toolchain.report`, `data`, `host`, `tar_command`, `download_failed`, `tar_failed`, `learn_compat`, `Download.choose`, `command`, `outcome`, `Zig.minimum`, `ZigInstall.ensure!`, `Nightlies.list!`, `candidates`, `parts`, `Github.rate_limit`, `rate_limit_failure`, `status_failure`, `network_failure`, `Temp`, `Clock.format_utc`, `parse_utc`, `TalonFile.render` |
| N5 | `ZigInstall.ensure!` may ask before the lock. The source is extracted before it. The lock of the item covers the build, the compat check, `.talon.json` and the rename |
| N6 | `Ref.parse(text, Scope.Roc, git)` gives `GitRef(text)` or `GitSha(text)` as the selector. `Args` is a transparent record: `args.options`, `args.operands`, `args.typed` |
| N7 | The stubs of `GitInstall` and `GitDefault` forward to the old commands, so the old L2 and L3 tests stay green. Remove the forward when the code is there (`GitRef.read` gives `NotGit` for the old words) |
| N8 | Compiler limits: section 10. `roc build` exits 2 on a warning |
| N9 | Review Q1: the token of the commit request is `Net.token({ plan: net.token, gh })`, with `gh` from `programs!(["gh"])` and `gh auth token` for `AskGh` only (the private `ask_gh!` of `Github.roc`: make it public or copy it). The call comes before the commit `http_get!`. Review Q6: `GitBuild.newest` matches a typed sha (7 to 40 lower case hex digits) also by the prefix of the `sha` field |

## 12. Red run, revert check

Red run with the stubs in `cli/lib` (logs in `research/slice-045-revert/red-*.log`):

| Step | Result |
| --- | --- |
| `roc check cli/lib/main.roc`, `roc build cli/main.roc --opt=dev`, `roc fmt --check` | pass, 0 warnings |
| `scripts/test.sh` | check pass, fmt pass, l0 FAIL, l2 FAIL, l3 FAIL, selftest pass, l1 pass |
| L0 `l0-3` | 75 tests: 66 passed, 9 failed. The 9 are the `expect`s of `GitTest`, all `todo: slice 045`. `NightliesTest` passes (green on the old code) |
| L2 | 116 passed, 2 failed (`roc/gi1-install`, `roc/gi2-zig`: wrong output of the old commands) |
| L3 | 67 passed, 1 failed (`compilers/gi1-git-install`), 1 skipped |

Green run with the reference (`apply.sh`): L0 `l0-3` all passed (75), L2 `roc/gi` 2 passed, L3 `compilers/gi1` 1 passed. The expected files of L2 and L3 were written with `UPDATE=1` from the reference, read by eye against the design, and the old files were compared with the new ones (TW21): only the files of this slice changed.

Revert check (`research/slice-045-revert/mutants.py`, 12 mutations of the reference, the result in `mutants.log`):

| # | Mutation | Caught by |
| --- | --- | --- |
| 1 | `Nightlies.by_name` has no exact-id branch (`named.contains`) | L0 `NightliesTest` |
| 2 | the commit request has no sha media type | L0 `GitTest` 2 |
| 3 | the nightly note accepts the commit sha anywhere in the tag | not caught at first. The row `00053495690...` was added to expect 4: now L0 `GitTest` 4 |
| 4 | the id has 7 characters | L0 `GitTest` |
| 5 | `newest` does not compare the repo | L0 `GitTest` 9 |
| 6 | `newest` ignores the time (the last row wins) | L0 `GitTest` 9 |
| 7 | `.talon.json` has the sha in `ref` | L0 `GitTest` 7 |
| 8 | wget is allowed | L2 `roc/gi` |
| 9 | the scratch dir stays after a failure | L2 `roc/gi` |
| 10 | no first default | L2 `roc/gi` |
| 11 | `--offline` does not stop before the request | L2 `roc/gi` |
| 12 | a 422 is not a usage failure | L0 `GitTest` 3 |

12 mutations, 12 caught after the new row. The reference was put back after each run (`diff -rq` against `cli/lib` after the run: equal), then `restore.sh` put the stubs back.

## 13. Review (manager, 2026-10-25)

The slice is accepted, no split. D1 to D12 and the TW24 texts are accepted. The test agent applied the changes with the reference (one hand mutation each, no sweep), re-ran the affected tests, and deleted the reference (TW21: the old files are in `research/slice-045-revert/before/`).

| Q | Answer | Change in the tests and the stubs |
| --- | --- | --- |
| Q1 | `commits/<ref>` with the sha media type: accepted. The token is the rule of the other GitHub API requests. `Github.releases!` sends it (`Net.token`: the variable, else `gh auth token`), so the commit request sends it too. R-DI9 excludes an archive and `.roc-version` only | `GitRef.commit_headers : { token : Try(Str, [None]) } -> List((Str, Str))`. `GitInstall` resolves the token before the request (`programs!(["gh"])` when no variable gives one). L0 expect 2 has a row with and without a token. L2: `programs gh` is new in `calls.log` before each commit request (5 runs of `gi1-install`, 4 of `gi2-zig`, nothing else changed), and the run 11 of `gi1-install` is new (`GITHUB_TOKEN=ghp_fake`: the header, no `gh` call). D1 and section 5 now say so |
| Q2, Q3, Q7, Q8, Q9, Q10 | Accepted as the reference does. Q2 and Q3 refuse (they do not guess) | None |
| Q4 | Accepted: a dev `minimum_zig_version` is the series of the number before `-dev`. If the index has no release of that series: the normal no-release failure | One L0 row in `ZigTest` (the second `pick` expect): `pick(no_release, "0.17.0-dev.31+abc", ...)` gives `the Zig index has no release of zig 0.17.x`. Green on the existing code (a gap row, no mutation) |
| Q5 | Accepted for now (exit 1). Design gap, recorded by the manager | None |
| Q6 | Change for the sha selector: `roc default --git @<hex>` also matches a build whose full `sha` in `.talon.json` starts with that hex. No installed build: `none_installed`, exit 2 | `GitBuild.newest` doc: the new rule. L0 expect 9 has 11 new rows (section 4). Not in L2 |
| G1 to G8 | Recorded by the manager | None |

Red check after the changes (stubs in `cli/lib`, `roc build cli/main.roc --opt=dev`: 0 errors, 0 warnings, `roc fmt --check` passes): `scripts/test.sh` gives check, fmt, selftest, l1 pass. L0: `l0-3` 66 passed, 9 failed (the 9 `GitTest` expects, `todo: slice 045`), the other drivers pass (`l0-6` 53 with the new `ZigTest` row). L2: 116 passed, 2 failed (`roc/gi1-install`, `roc/gi2-zig`). L3: 67 passed, 1 failed (`compilers/gi1-git-install`), 1 skipped.

Hand mutations of the reference after the changes (`mutants.py` 13 to 16; the reference is deleted now):

| # | Mutation | Caught by |
| --- | --- | --- |
| 13 | `newest` has no match by the full sha | L0 `GitTest` 9 |
| 14 | the sha text may have 1 digit (not 7 or more) | L0 `GitTest` 9 (the row with 6 digits) |
| 15 | the commit request sends no token | L2 `gi1-install` run 11 |
| 16 | `gh` is asked also when a variable gives the token | L2 `gi1-install` run 11 |

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | `RocInstall.spawn_one!` and `Github.ask_gh!` are public now (they moved into the type block, with a call site `RocInstall.spawn_one!` in 4 places). The old behavior is the same (old L2 and L3 tests pass). `GitInstall` shares both | A copy in `GitInstall` |
| C2 | `learn_compat!` is a small copy in `GitInstall` (not shared): the L2 `calls.log` has no `delete!` of the probe dir between the second `list_dirs!` and the `.talon.json` (the scratch dir is the probe dir, and the run deletes it at its end). The code of `RocInstall.learn_compat!` deletes the probe dir in that place | A parameter in `RocInstall.learn_compat!` that turns the delete off |
| C3 | The texts of Q2 (no tests): `--git` with a name that is not `owner/repo`: `--git takes a GitHub repository as owner/repo, not '<name>'` (usage). `--git` with a name and no `@ref`: `'<operand>' has no ref: use owner/repo@ref or @ref` (usage) | The default branch of the repo (one more request) |
| C4 | Q3 (no tests): `build.zig.zon` with no `minimum_zig_version`: kind `Input` (exit 19), `build.zig.zon of <o/r@ref> has no minimum_zig_version`. A `build.zig.zon` that cannot be read: kind `Input`, `cannot read build.zig.zon of <o/r@ref>: <why>` | Use the Zig on `PATH` with no check |
| C5 | A failure at any step after the scratch dir is made (also a declined Zig prompt) runs `delete!([temp, scratch])` after the lock ends. A success runs `delete!([scratch])`. Both are one call at the end of `GitInstall.flow!` (the order is fixed by `calls.log`) | One delete in each step |
| C6 | A bare sha selector (`roc install @dd03c09e`, `owner/repo@dd03c09e`) is a git source only with form `owner/repo` and a `GitSha` selector. Any other bare operand is `NotGit` (the old command prints its failure) | A failure from `GitRef.read` for a bad operand with no `--git` |

## Verify results

| Step | Result |
| --- | --- |
| `scripts/test.sh` (all steps) | exit 0: check 1.5 s, fmt 0.2, l0 6.5 (`l0-3`: 75 passed, the 9 `expect`s of `GitTest` and the one of `NightliesTest` green; `l0-6`: 53 passed), l2 7.7 (118 passed, 0 failed: `roc/gi1-install` 11 runs, `roc/gi2-zig` 4 runs), l3 9.9 (68 passed, 0 failed, 1 skipped: `compilers/gi1-git-install`), selftest 3.0, l1 36.7 |
| `roc check`, `roc build cli/main.roc --opt=dev --no-cache`, `roc fmt --check` | 0 errors, 0 warnings |
| `crash "todo` in `cli/`, `packages/` | none |
| Revert check | `research/slice-045-revert/agent-mutate.py`, results in `agent-results.md`: 12 mutations, 12 caught, 0 not caught |
| Code after the runs | same as `research/slice-045-revert/code-final/` (`sha256sum -c research/slice-045-revert/code-final.sha256` from the repo root: all OK) |

| Id | Mutation | Caught by |
| --- | --- | --- |
| G1 | the id has 7 characters | L0 `GitTest` |
| G2 | the commit request sends no token | L2 `gi1-install` (run 11) |
| G3 | `gh` is asked also when a variable or the test API gives the token | L2 `gi1-install` (runs 4, 11) |
| G4 | the nightly note accepts the tag sha anywhere in the commit | L0 `GitTest` 4 |
| G5 | `newest` ignores the time (the last row wins) | L0 `GitTest` 9 |
| G6 | `newest` has no match of a typed sha with the full `sha` | L0 `GitTest` 9 |
| G7 | wget is allowed for the source archive | L2 `gi1-install` (run 7) |
| G8 | the scratch dir stays after a failed build | L2 `gi2-zig` (run 3) |
| G9 | the first git build is not the default | L2 `gi2-zig` (run 2) |
| G10 | `--offline` stops after the commit request | L2 `gi1-install` (run 5) |
| G11 | a 422 is not a usage failure | L0 `GitTest` 3 |
| G12 | no check for the dir under the lock | L2 `gi2-zig` (run 4) |

## Gap tests

| Row | Test | Rule | Mutation |
| --- | --- | --- | --- |
| C3 | L0 `GitTest` expect 1 (`read`), 5 new rows: `--git foo@main` and `--git foo` (`--git takes a GitHub repository as owner/repo, not 'foo'`), `--git a/b/c@main` (the failure of `Ref.parse`), `--git Karakatiza666/roc` (`'Karakatiza666/roc' has no ref: use owner/repo@ref or @ref`), `--git Karakatiza666/roc@` (empty selector). The texts are the proposals of the code agent (TW24, Q2: the command refuses and does not guess) | R-SL13, R-R9, R-R10 (Q2) | `git_source` skips the owner/repo check (`if parsed.form != Full` becomes `if Bool.False`): `l0-3` 1 failed, 74 passed. Restored |
| C4 | L2 new case `roc/gi3-nozon`, 1 run: `build.zig.zon` with no `minimum_zig_version`: `tln: error[input]: build.zig.zon of Karakatiza666/roc@my-branch has no minimum_zig_version`, exit 19. The `calls.log` has no Zig call and no lock, and ends with `delete` of the temp dir and the scratch dir (the failure path of the flow). The unreadable `build.zig.zon` is not tested (the fake tar cannot fail for one run only) | R-D4, R-CC2 (Q3) | the failure kind is `Environment` (`Fail.new(Input, ...)` in `need!`): the run gives `exit 18` and fails. Restored |
| C2 | No test. Not a bug: the probe dir of `GitInstall.learn_compat!` is `p.scratch` (`talon/tmp/<hex>`, `cwd` of `roc check` and the dir of `empty.roc`). `GitInstall.flow!` deletes it after each run: `delete!([p.scratch])` after a success and `delete!([p.temp, p.scratch])` after a failure. The same line is in the expected files: `tests/commands/cases/roc/gi1-install/expect/calls.log` has `delete $HOME/.cache/roc/talon/tmp/0123456789abcdef` after the last step of each installing run (lines 49, 103, 147), and `tree.diff` of the case has no `talon/tmp` dir. The L3 case ends with `$HOME/.cache/roc/talon/tmp:` empty in `expect/stdout` (sections 1, 5 and 6). `roc check` writes its compat dir in the build root, not in the probe dir | R-GC10, R-R6 | none |
| C1, C5, C6 | No new row. C1 is not behavior. C5 is pinned by `gi2-zig` runs 1 and 3 (a declined prompt, a failed build) and by the new `gi3-nozon`. C6 is pinned by the `read` rows of expect 1 (a bare sha, and the other bare operands that give `NotGit`) | | |

After the rows: `sha256sum -c research/slice-045-revert/code-final.sha256` is OK for the 7 files (checked after each mutation).

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-045-revert/code-final.sha256` | OK, 7 lines |
| `crash "todo` in `cli/`, `packages/` | none |
| `scripts/test.sh` | exit 0: check 1.5, fmt 0.2, l0 7.3, l2 7.2, l3 9.9, selftest 3.0, l1 38.1 s |
| Gap tests | 5 L0 rows (C3), L2 case `roc/gi3-nozon` (C4), 2 hand mutations, all caught; no code bug |
| C2 probe dir | Not a leak: the probe dir is inside `scratch`, which the flow deletes after each run (pinned in `gi1-install` calls.log) |
