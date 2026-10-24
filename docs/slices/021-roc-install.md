# 021 Roc install

Phase: P1. Status: done

Slice 021 makes `tln roc install <id>` (aliases `roc i`, `roc add`) for `direct` mode. The command picks the id with `Nightlies` (slice 020), downloads the archive with the download adapter, checks the sha256 before the extract (exit 16), extracts with `tar` into a temp dir, sets the executable bit, learns the compat id, writes `.talon.json` last, and renames the temp dir. The first installed compiler becomes the global default. It follows `docs/agents/BRIEF-tests.md`. The pre-slice copies of the changed files are in `research/slice-021-revert/before/` (with `NEW.txt`).

Size (TW19): the private reference has about 436 lines of code (without comments and blank lines): `Toolchain.roc` 200 (pure) and `RocInstall.roc` 236 (the command). It is a little over 400. See question Q9 (a split line exists, but each half has no green test alone).

## Rules

| Id | Where | Tested by |
| --- | --- | --- |
| R-R8, R-CM15, R-CM19 (the command, the alias `i`, the alias `add`, one operand) | CLI 2, CLI 6 | L0 `read`. L2 `ri1-flow`. L3 `ri1`, `ri2` |
| R-CV4 (sha256 before use, no digest: exit 16 before any download) | CLI 6.2 | L0 `require_digest`, `check_download`. L2 run 10. L3 `ri2` runs 1, 2 |
| R-CV5 (`.talon.json` last) | CLI 6.2 | L0 `meta`. L2 `calls.log`. L3 `ri1` (tree) |
| R-HF2 (executable bit), R-HF4 (download), R-HF5 (extract, strip of the top dir) | CLI 6.2 | L0 `tar_command`, `chmod_command`, `plan`. L2 runs 1, 4. L3 `ri1` |
| R-SE9 (tar refuses `..`), R-SE11 (the hash check) | CLI 6.2 | L0 `tar_failed`. L3 `ri2` runs 1, 3 |
| R-CC4 (the 7 steps of an install), R-CC2 (no half install), R-CC3, R-CC5 (lock, wait) | Resolution | L2 runs 1, 6, 7, 10. L3 `ri1` run 6 (2 runs at the same time), `ri2` |
| R-GC10 (the compat id from `roc check` of an empty file) | CLI 6.2 | L0 `learn_compat`. L2 runs 1, 9. L3 `ri1` |
| R-SO15, R-LY4, R-CC6, R-CC7, R-TF4 (the first install is the default, config.toml edit) | CLI 6 | L0 `default_edit`. L2 runs 1, 2. L3 `ri1` run 1, `ri2` run 9 |
| R-NI6 (the consent prompt of the download) | CLI 6.2 | L0 `Consent.roc_install`. L2 runs 1, 5 |
| R-CV8 (the host from the system), R-DA4, R-DI12, R-NS2, R-NS4, R-C7, R-SC10 to R-SC13, R-J3, R-J5, R-FL4, R-OUT2 | | L0 `host`, `domain`, `report`. L2. L3 |
| The TW26 budget warnings apply to `OPT=dev` only (PLAN-P1 row 020 review, slice scope) | TESTING.md TW26 | selftest row `budget with OPT=speed` |

`MISSING=1 scripts/rules.sh R-R8 R-CV4 R-CV5 R-HF2 R-HF4 R-HF5 R-SE9 R-SE11 R-CC4 R-GC10 R-SO15 R-NI6 R-CM19` lists no rule without a test.

## Files

| Path | Lines | Writer | State |
| --- | --- | --- | --- |
| `cli/lib/Toolchain.roc` | 166 | Stubs from the test agent. Bodies from the code agent. | New pure module. 20 signatures, all bodies `crash "todo"`. The contract is in the doc comments. |
| `cli/lib/RocInstall.roc` | 29 | Same | New command module. `run!` is `crash "todo"`. The doc has the table of the calls, in order (13 steps). |
| `cli/lib/Consent.roc` | 142 (+16) | Stubs | `roc_install`, `roc_install_declined`: `crash "todo"` |
| `cli/lib/Fx.roc` | 199 (+15) | Test agent (the record) | 2 new fields: `platform!`, `sha256_file!` |
| `cli/RealFx.roc` | 752 (+10) | Stubs | The 2 fields are wired, the bodies are `crash "todo"` |
| `cli/lib/Run.roc`, `cli/lib/main.roc` | 107, 87 (+3, +2) | Test agent | The dispatch for `["roc", "install"]`. `Nightlies`, `RocInstall`, `Toolchain` are in the exposes list. |
| `cli/fxprobe.roc` | 257 (+36) | Test agent (test tool) | New calls `platform`, `sha256 <file>...` |
| `tests/commands/FakeFx.roc` | 679 (+60) | Test agent | `platform!` (rows of `fx/platform`), `sha256_file!` (the real hash of the bytes), `busy <name> creates:<path>` in `fx/locks`, `{out}` and `{dir}` in `fx/jobs` |
| `tests/tools/mk-nightly.sh` | 100 (+32) | Test agent | `ARCHIVE=real` (the real archive layout and a fake `roc` that makes `compat-<sha256 of the tag>` for `check` and exits 1), and the spec suffixes `+evil` (a member `<top>/../../evil.txt`) and `+noasset` (an empty `assets` list, no archive). The default output is unchanged (checked with `cmp` against the `cl2` archive). |
| `tests/unit/toolchain.roc` | 324 | Test agent | 12 `expect`s, red |
| `tests/commands/cases/roc/ri1-flow/` | 1 case | Test agent | L2, 11 runs, red |
| `tests/scenarios/compilers/ri1-install-flow/`, `ri2-refusals/`, `tests/scenarios/fx/ri-real-fx-jobs/` | 3 cases | Test agent | L3, red |
| `tests/selftest.sh` | 352 (+10) | Test agent | 1 new row (see Tests) |
| `research/slice-021-revert/before/` | | Test agent | 9 changed files, `NEW.txt` |

`scripts/test.sh` needs one change by the code agent (see N1): the `WARN` lines only for `OPT=dev`.

## Public signatures (`cli/lib/Toolchain.roc`)

| Item | Type | Rule |
| --- | --- | --- |
| `Platform` | `{ os : [Linux, Macos, Windows, Other(Str)], arch : [X64, Arm64, Other(Str)] }` | R-CV8 |
| `host` | `Platform -> Try(Nightlies.Host, Fail)` (`Environment` for any other system: exit 18) | R-CV8 |
| `read` | `Args -> Try(Str, Fail)` (`Usage`: 0 or 2 or more operands) | R-CM15 |
| `domain` | `{ releases, now, min_age } -> { named : List(Str), auto : List(Str) }` | R-NS4, R-C7 |
| `pick_failed` | `{ error : Nightlies.PickError, releases, host } -> Fail`. `NoMatch` of the exact id of a nightly with no asset (`Err(NoAsset)`): `<id> has no asset for <target>` (`Usage`, exit 2). All else: `Nightlies.failure`. | R-CV2, R-SC10 |
| `plan` | `{ roots, host, id, asset, hex } -> Plan` (`Plan` has `id, item, temp, archive, roc, meta, probe_dir, probe_file`) | R-CC1, R-CC4 |
| `tar_command` | `{ archive, dir } -> List(Str)` | R-HF5, R-SE9 |
| `chmod_command` | `{ host, file } -> Try(List(Str), [NotNeeded])` | R-HF2 |
| `require_digest` | `{ id, asset } -> Try(Str, Fail)` | R-CV4 |
| `check_download` | `{ id, want, got } -> Try({}, Fail)` | R-CV4, R-SE11 |
| `download_failed`, `tar_failed` | `{ id, url, ... } -> Fail` | R-DA7, R-SE9 |
| `offline_missing`, `offline_no_list` | `Str -> Fail`, `{} -> Fail` | R-DI12 |
| `learn_compat` | `{ before, after } -> Try(Str, [Unknown, Several(List(Str))])` | R-GC10 |
| `meta` | `{ id, url, sha256, typed, compat, now } -> Str` | R-CV5 |
| `default_edit` | `{ path, text, id } -> Try([Keep, Set(Str)], Fail)` | R-SO15, R-CC6 |
| `size_text` | `U64 -> Str` | R-NI6 |
| `report`, `data` | `{ id, how, default, compat } -> { stdout, stderr }`, `{ id, item, how, default } -> JsonDoc` | R-OUT2, R-J3 |
| `RocInstall.run!` | `Fx, Args => I32` | R-R8 |
| `Fx.platform!`, `Fx.sha256_file!` | `{} => Platform`-like record, `Str => Try(Str, [NotFound, Denied, Other(Str)])` | R-CV8, R-DA4 |
| `Consent.roc_install`, `roc_install_declined` | `{ id, size } -> Prompt`, `Str -> Fail` | R-NI6 |

## Tests

| Layer | File and case | What it checks | Rules |
| --- | --- | --- | --- |
| L0 | `tests/unit/toolchain.roc` 1 (`host`) | The 6 supported systems. Other os and other cpu: kind `Environment`, exit 18. | R-CV8 |
| L0 | 2 (`read`) | One operand as typed. None and 2 or more: `Usage`. | R-CM15, R-R8 |
| L0 | 3 (`domain`) | `named` has each candidate, `auto` has the candidates at least `min_age` old (exactly the age is visible). A nightly with no asset or 2 assets is in neither. | R-NS4, R-C7, R-CV2 |
| L0 | 4 (`plan`) | The paths of one install. The archive is in the temp dir. Windows has `roc.exe`. | R-CC1, R-CC4 |
| L0 | 5 (`tar_command`, `chmod_command`) | The same tar line for `.tar.gz` and `.zip`, with `--strip-components=1`. No chmod on Windows. | R-HF5, R-SE9, R-HF2 |
| L0 | 6 (digest and failures) | No digest, a wrong digest (kind `Integrity`, exit 16), the failures of curl and tar with their kinds (15, 15, 18). | R-CV4, R-SE11, R-DA7, R-DI12 |
| L0 | 7 (`learn_compat`) | A new `compat-` dir, one with a later time, none, several (a sorted list). | R-GC10 |
| L0 | 8 (`meta`) | One line, `format` first, the field order, `null` for an unknown compat id. | R-CV5, R-TF1, R-TF2 |
| L0 | 9 (`default_edit`) | The key in any form: `Keep`. Else one line at the end of the top-level keys (before the first table), all other bytes stay. A TOML error: kind `Input` with the line. | R-SO15, R-LY4, R-CC6 |
| L0 | 10 (`size_text`, consent) | `B`, `KB`, `MB` with one digit (rounded). The prompt, the answer lines, the 4 modes, and the declined failure (exit 13). | R-NI6, R-DL1, R-DL3, R-DL4 |
| L0 | 11 (`report`, `data`) | The text and the `data` of a run. The compat warning only for a new install. | R-OUT2, R-J3, R-FL4, R-GC10 |
| L0 | 12 (`pick_failed`) | The exact id of a nightly with no asset names the host (`<id> has no asset for linux_x86_64`, also `windows_arm64`, exit 2). A prefix of that id, an id that is not in the list, and an id with an asset give `no compiler matches <text>`. `Ambiguous` and `Empty` are `Nightlies.failure`. | R-CV2, R-SC10, R-NS2 |
| L2 | `roc/ri1-flow` (11 runs) | 1 fresh install, the whole order of the calls, and the default. 2 present: early exit, no request. 3 `--offline` and not installed. 4 Windows (`.zip`, `roc.exe`, no chmod). 5 the prompt declined (exit 13, no lock). 6 a busy lock whose holder makes the dir (step 9 finds it). 7 stale temps deleted. 8 `--json`. 9 compat `Several` (null, a warning). 10 a wrong digest (temp deleted, exit 16). 11 a platform that is not supported (exit 18, before any call). | R-CC4, R-CC3, R-CC5, R-CV4, R-HF2, R-NI6, R-GC10, R-CV8, R-J3 |
| L3 | `compilers/ri1-install-flow` | The real `Fx`, curl and tar, 5 fake nightlies with the real archive layout. A full id (first default). `@latest` (a young nightly is hidden) and the alias `i`. An installed id. A prefix of a hidden nightly with `--json` and the alias `add`. The other tag form. 2 runs at the same time: one download. The store has no temp, lock or probe dir. | R-CV1, R-CV5, R-CV7, R-HF2, R-HF4, R-HF5, R-CC4, R-GC10, R-SO15, R-NS4, R-C7, R-CM19 |
| L3 | `compilers/ri2-refusals` | The wrong digest (also `--json`). No digest. An archive with a `..` member (nothing written outside the temp). 404. The 5 usage errors, the exact id of a nightly with no asset for the host (`has no asset for linux_x86_64`, the release is made with `+noasset`), and a prefix of it (`no compiler matches`). `@latest` with an empty list (exit 10). `--offline` with and without a cached list. A bad `config.toml` (exit 19, before any request). `min-release-age = "0d"` and the default inserted, other bytes stay. After each refusal: no compiler, no temp, no lock, no probe dir, no config. | R-CV4, R-SE9, R-SE11, R-DA7, R-NS2, R-DI12, R-TF4, R-SO15, R-SC10 to R-SC13, R-J5 |
| L3 | `fx/ri-real-fx-jobs` | The real `platform!` against `uname`, the real `sha256_file!` for a small, an empty and a 5 MB file, and a missing file. | R-CV8, R-DA4 |
| selftest | `tests/selftest.sh`, row `budget with OPT=speed` | With `OPT=speed` the table of results has no `WARN` line even when `fmt` and the total are over budget (exit 0). With `OPT=dev`: `WARN fmt` and `WARN total`. | TW26 |

Count: 12 L0 `expect`s, 1 L2 case (11 runs), 3 L3 cases, 1 selftest row.

## Output (proposed, R-OUT2, TW24)

| Where | Text |
| --- | --- |
| stdout, new install | `installed <id>`, then `<id> is now the default compiler` (only for the first, R-SO15) |
| stdout, present | `<id> is already installed` |
| stderr, the prompt answer (the line of `answer_line`) | `downloading <id> (<size>)` |
| Prompt | `Download 1 compiler, <size>: <id>? [Y/n] ` (id `roc-install`, kind Default). A decline: `tln: error[consent]: <id> is not installed. Nothing was downloaded.` (exit 13) |
| Size | `<n> B`, `<x.y> KB`, `<x.y> MB` (decimal units, rounded to one digit) |
| stderr, compat unknown | `warning: the compat id of <id> is not known: roc check touched no compat dir`, or `... touched <n> compat dirs (<a>, <b>)` |
| `.talon.json` | One line: `{"format":1,"id","url","sha256","sha256_source":"github-digest","typed","compat","installed_at"}`. `typed` is the text of the user. `compat` is a string or `null`. |
| `--json` `data` | `{"id","path","installed","default"}` (the 2 flags are booleans). `command` is the typed command (`roc install`, `roc add`). The human text goes to stderr. |
| Errors | `tln: error[integrity]: sha256 of <id> differs: expected <a>, got <b>. Talon deleted the download.` `tln: error[integrity]: the asset of <id> has no sha256 digest. Talon does not install it.` `tln: error[integrity]: tar rejected <id> (<url>): <tar message>` `tln: error[network]: download of <id> failed: 404 (<url>)` `tln: error[network]: <id> is not installed and --offline is set` `tln: error[network]: no cached list of compilers and --offline is set` `tln: error[environment]: no compiler asset exists for <os> <cpu>` `tln: error[usage]: <id> has no asset for <target>` (the exact id of a nightly with no asset for the host, `<target>` as in the asset name, `linux_x86_64`) `tln: error[usage]: tln roc install needs one compiler: a full id, a prefix or @latest` `... takes one compiler, got <n>` |

## Decisions that the design does not fix (the test agent chose, for review)

| # | Decision | Rejected |
| --- | --- | --- |
| D1 | The archive is downloaded into the temp dir (`<temp>/<asset name>`) and deleted after the extract. `tar -xf <archive> -C <temp> --strip-components=1` cuts the top dir of the real archive (`LICENSE`, `legal_details`, `roc`). The same line works for `.zip` (bsdtar). | A second temp dir for the archive. A tar that streams from curl (no digest check before the extract, against R-CV4). |
| D2 | An id that is already a dir in `toolchains/` ends the command at once (step 3), with no request and no lock. The list is read once for a name. After the pick, the id is checked again, and again under the lock (R-CC4 step 4). | No early exit: `tln roc install <installed id>` would need the network. |
| D3 | `pick` gets `base: Err(None)`: the relative steps `@-N`, `@+N` have no base in this slice. They give `NoBase` (exit 2, text of slice 020). | A base from the default compiler. This is slice 022. |
| D4 | The switch of R-NS3 is not read. `auto` is always the list of `min-release-age`. | |
| D5 | `min-release-age` comes from `config.toml` only (`Intent.read_config`), default 2 days. A project file is not read (R-PD16: no project). | `talon.toml` of the project |
| D6 | One `clock!` call. `TALON_NOW` gives the time of the filter and of `installed_at`. The real clock gives the cache age of the list. | 2 calls |
| D7 | The warnings of `Intent.read_config` go to stderr, one line each, before any request. | Hidden |
| D8 | The limits of `spawn_all!`: 8 for the download, 1 for tar, chmod and `roc check`. | |
| D9 | Failure kinds: a digest that differs, a missing digest and a tar that refuses the archive are `Integrity` (16). A curl failure and a 404 are `Network` (15). An unsupported system is `Environment` (18). A decline is `Consent` (13). | `Network` for the digest |
| D10 | The compat id is the `compat-` dir of the build root that `roc check` of an empty file touched (new, or a later mtime). The exit code of `roc check` (1) is not read. None or several: the compat is `null` and a warning. The command does not fail. | A failure when unknown. A hash computed by Talon. |
| D11 | The default is set after the unlock of the item, for `Installed` only, under the lock of `config.toml` (R-CC6) with a re-read (R-CC7). A `Present` result never sets the default. | The default also for `Present` (a repeat of the command would change a choice). |
| D12 | With `--json` the human lines go to stderr and stdout is only the envelope. `--quiet` hides the stdout lines. | |
| D13 | `Err(Exists)` from the rename is a success (`Installed`): the other process won, and the temp dir is deleted (as R-FE3). | An error |
| D14 | A temp dir that the command makes, and the probe dir (`<talon tmp>/<hex>`), are deleted after any failure after step 10. | |

## Out of scope

| Id | Reason |
| --- | --- |
| R-DA6 (progress line), R-NM4, R-NM6 | The progress is a terminal feature. The tests run with no tty. |
| R-NS3 (the switch), relative steps `@-N`, `@+N` | Slice 022 |
| `--git` builds | Slice 045 |
| R-SC12 (a prefix in a pin) | Slice 012 |
| The scheme text of R-DA3 for compilers (the default scheme text names packages) | Question Q7. The tests use the generic `curl` line. |
| The claim of R-SE9 that tar "strips absolute paths" | Measured: GNU tar strips a leading `/` of a member (a warning), and refuses `..`. Only `..` is tested. |
| `TALON_AUTO_INSTALL` | A later slice (the auto install of a missing compiler) |
| The text of TESTING.md TW26 | The manager decides (Q8) |
| R-CV6 (first sha256 seen, `compat.db`) | Slice 030 |
| Registry branches of R-CV1, R-CV3 | P2 |
| `tln roc install` with `--git`, `--timeout`, rate limit | Slices 003, 045 |

## Questions (TW17)

| # | Question | Tested default | Other option |
| --- | --- | --- | --- |
| Q1 | A compat id that `roc check` does not show (none or several dirs): fail the install, or warn? | A warning, compat `null` (L0 7, 11. L2 run 9) | Exit 18 |
| Q2 | The first default: is a `default-roc` in `config.toml` the only sign of "no default"? A user who removed the key by hand gets the next install as the default. | Yes (L0 9) | A state file |
| Q3 | `--json` and a decline or an error: the envelope has the error as in R-J5. The text of `data` for `Present` has `installed: false`. | Yes (L3 `ri2` run 1) | |
| Q4 | The default is set after the unlock of the item (own lock on `config.toml`, R-CC6), not under the lock of the item. | After (L2 run 1 `calls.log`) | Inside the item lock |
| Q5 | The prompt is `Default` (no flag, `--yes` and non-interactive give Yes). R-NI6 names "download of the compiler that the command names". | Default, answer Yes (L0 10) | Required (`--yes` is needed) |
| Q6 | A nightly with no asset for the host: the text. (Answered by the review: the exact full id gives `<id> has no asset for <target>`, a name or a prefix gives `no compiler matches <text>`.) | Tested: L0 12, L3 `ri2` run 5 | |
| Q7 | The curl scheme of R-DA3 for a compiler URL (`--proto =https`?). The fake server is `http`. | The `Download.command` line as is | A `https` only line for the real use |
| Q8 | TESTING.md TW26: its text says the budgets warn always. The slice makes them warn for `OPT=dev`. Change the text? | Behavior only (selftest row) | Also change the text |
| Q9 | TW19: the reference is about 436 lines. Split at `Toolchain` (pure) and `RocInstall` (command)? | No split | Slice 021a (pure part and `Fx` fields) and 021b (command and L2, L3) |
| Q10 | The exact id of a nightly with 2 assets for the host (`Several`): the text of Q6 is only for `NoAsset`. The tests do not fix the text for `Several`. | `no compiler matches <id>` (the reference, not tested) | `<id> has 2 assets for <target>` |

## Design gaps found

| # | Gap |
| --- | --- |
| G1 | R-SE9 says tar strips absolute paths. Tested with GNU tar: it strips a leading `/` and warns, but only `..` makes it refuse. The wording "refuses" covers only `..`. |
| G2 | R-GC10 gives no rule for the case where `roc check` makes no compat dir or several dirs (Q1). |
| G3 | R-CC4 does not say that the early `Present` check (D2) comes before the list fetch. Without it `tln roc install <id>` needs the network. |
| G4 | R-SO15 does not say how "no default" is read when `config.toml` is missing or has no `default-roc` (D11, Q2). |
| G5 | The real nightly archive has a top dir (`roc_nightly-linux_x86_64-<date>-<sha>/`). The design (R-HF5) does not give `--strip-components=1`. |
| G6 | `roc check` of an empty file exits 1 and still creates `compat-<hash>/` (measured on the pinned nightly). R-GC10 does not say that exit code 1 is normal. |

## Compiler and syntax limits found

| Limit | Effect |
| --- | --- |
| `a ?? b ?? ""` with a `Try` does not compile | Use a `match` |
| `roc check` exits 2 on a warning (an unused branch from `crash` in a `match`) and `scripts/test.sh` fails on it | In tests, build `Roots` with a record literal, not a `match` with `crash` |
| `read = ...` that calls an effect needs the name `read!` | Name effectful functions with `!` |

## Red output

`scripts/test.sh` with the stubs (2026-10-22):

| Step | Result | Reason |
| --- | --- | --- |
| check, fmt | pass | |
| L0 old files (51 files) | pass | |
| L0 `tests/unit/toolchain.roc` | red: 0 passed, 12 failed | `Roc application crashed ... todo` |
| L2 old cases (36) | pass | |
| L2 `roc/ri1-flow` | red | `[ROC CRASHED] todo` |
| L3 old cases (28, 1 skipped) | pass | |
| L3 `compilers/ri1-install-flow`, `ri2-refusals`, `fx/ri-real-fx-jobs` | red | `[ROC CRASHED] todo`, the stdout, the exit code, the tree and the `http.log` differ |
| selftest (39 of 40) | red: 1 failed | The row `budget with OPT=speed`: the current script prints `WARN` for `OPT=speed` |

## Check against the design (TW21)

The expected files were made by a private reference (deleted, TW18) and read by eye against the design. With the reference the 12 `expect`s, the L2 case, the 3 L3 cases and all selftest rows pass, and `scripts/test.sh` exits 0.

Revert check (TW12), on the reference: 45 mutations of the code, each in one small way, run with the filtered tests only (the script was private and is deleted). 45 of 45 are caught. 7 mutations did not compile at first. 6 were rewritten, and 1 (a prompt inside the lock) was dropped. Each result is a test failure, not a compile error.

| Group | Mutations | Caught by |
| --- | --- | --- |
| `host` (2), `read`, `plan` (archive path), `learn_compat` (mtime), `default_edit` (2), `size_text`, `report` | 9 | L0 only |
| `plan` (Windows `roc.exe`), `chmod_command` (Windows), `learn_compat` (several), `Consent` (default answer) | 4 | L0 and L2 |
| `domain` (2), `require_digest`, `download_failed` kind, `tar_failed` kind | 5 | L0 and L3 |
| `tar_command` (no strip), `check_download` (always ok), `meta` (2), `data`, `Consent` (kind) | 6 | L0, L2 and L3 |
| `RocInstall`: no recheck under the lock, no lock, stale temps kept, chmod skipped, `.talon.json` before the extract, no early `Present` (L2 only), default set for `Present` (L2 only) | 7 | L2 |
| `RocInstall`: no `check_download` call, default never set, decline ignored (L2 only), temp kept on a failure, compat check skipped, offline check removed, archive kept, probe dir kept, `--json` envelope always | 9 | L2 and L3 (decline: L2 only) |
| `min-release-age` fixed | 1 | L3 `ri1` |
| `RealFx` (sha256 of other bytes, arch, os) | 3 | L3 `ri-real-fx-jobs` |
| selftest: the budget warns for `OPT=speed` | 1 | selftest row |
| After the review (Q6): `pick_failed` never names the host, a prefix names it, any asset state names it (caught by the row with an id that has an asset), a fixed target, always names the host | 5 | L0 (4 also L3 `ri2`) |

Known gaps: the `Consent` decline is checked only in L2 (L3 runs have no tty, so no prompt). A prompt inside the lock was not mutated: the order of the calls in `calls.log` fixes it.

## Notes for the code agent

| # | Note |
| --- | --- |
| N1 | `scripts/test.sh`: print the `WARN` lines of TW20 only when `OPT=dev` (the selftest row). |
| N2 | `Fx.platform!` of `RealFx`: use `Env.platform!`. `sha256_file!`: read the bytes with `Path.read_bytes!` and use `Crypto.SHA256`. |
| N3 | The table in the doc of `RocInstall` has the order of the calls. The `calls.log` of the L2 case fixes it, including the number of `list_dirs!`, `read_files!` and `clock!` calls. |
| N4 | `RocInstall` must end with `Install.failed!` for a failure (the exit code and the text), as `Install.run!` does. |
| N5 | A local name must not equal a method name of its type module (slice 020 limit). |
| N6 | Do not edit a test (TW18). A question goes to the manager. |

## Review (manager, 2026-10-22)

D1 to D14 are accepted. No split (Q9): about 436 lines is close to TW19.

| # | Answer |
| --- | --- |
| Q1 | A warning, compat `null` (the default). G2 is closed by this answer. |
| Q2 | Yes: the `default-roc` key of `config.toml` is the one source (no state file). |
| Q3, Q4 | The defaults. |
| Q5 | `Default` (the column of R-NI6): the command that names the compiler is the consent. |
| Q6 | The default text `no compiler matches <id>` stays for a name or a prefix. For an exact full id of a nightly with no asset for the host, the text names the host: `<id> has no asset for <target>` (exit 2). The test agent changes the row. |
| Q7 | `Download.command` as is: R-DA3 has `--proto =https,http`. |
| Q8 | Yes: the code agent changes the TW26 text in TESTING.md (budgets warn in `OPT=dev` only). |
| G1 | Fixed in the design (R-HF5, R-SE9): `tar` removes a leading `/` and refuses `..`; the sha256 check is the main guard. |
| G3, G5, G6 | Accepted as the slice decisions (D2, D1, D10). No design edit. |

## Test change after the review (test agent, 2026-10-22)

Q6 is applied. New: `Toolchain.pick_failed` (stub, doc table), L0 row 12, 3 lines in L3 `ri2-refusals` run 5 (`given/http` list has one more release, `nightly-2026-10-08-0badc0d`, made with the new `+noasset` suffix of `mk-nightly.sh`). Checked with a private reference (deleted): 12 of 12 `expect`s, `ri2` and `scripts/test.sh` pass; 5 mutations of `pick_failed` are caught. New question Q10 (a nightly with 2 assets). The status is not changed.
Q6 change accepted. Q10: the default (`no compiler matches`) for an exact id with 2 assets for the host; no test (the case is rare, and slice 020 D1 counts it as no candidate).

## Disputes (from the code agent)

None. No test, fixture or expected file was changed.

## Decisions of the code agent (not fixed by the slice)

| # | Decision | Rejected |
| --- | --- | --- |
| C1 | The check order of step 6 is as the doc table: the digest first, then `--offline`. | `--offline` first |
| C2 | A failed `chmod` is kind `Environment`: `cannot set the executable bit of <file>: <ended>`. A failed write of `empty.roc` or `.talon.json`, a failed `make_dirs!`, a failed `sha256_file!` and a failed rename (not `Exists`) are also `Environment`. The design has no text for them. | `Integrity` |
| C3 | `Err(Exists)` from the rename deletes only the temp dir (the probe dir is gone already). Any other failure after step 10 deletes the temp dir and the probe dir in one `delete!` call. A failure of `Download.choose` or `make_dirs!` calls no `delete!` (nothing was made yet, as `Fetch.packages!`). | Delete in each case |
| C4 | The cache age of the list uses the real clock (`fx.clock!()`, D6). The filter and `installed_at` use `Clock.now` (`TALON_NOW`). | `TALON_NOW` for both |
| C5 | `NotStarted` of `roc check` is not read (D10): the compat is `null` with a warning. | A failure of kind `Environment` |
| C6 | `RealFx.platform!` maps `X86` to `Other("x86")` and `ARM` to `Other("arm")`. | `Arm64` for `ARM` |
| N1 | `scripts/test.sh` prints the `WARN` lines only for `OPT=dev`. TW26 text in `TESTING.md` says so (Q8, only that sentence). | |

## Verify results (code agent, TW12)

45 mutations of the code (`research/slice-021-revert/code-mutate.py`, results in `code-results.md`), filtered runs only. Caught 43 of 45. Files are the same as before the mutations (`code-final/`, compared by the script and by `cmp`).

| Not caught | Why |
| --- | --- |
| T17: `size_text` cuts the KB value, no rounding | No row of L0 10 has a KB value that differs (1000, 1500, 999949). The MB form is caught (T17b). A row such as `1550` to `1.6 KB` closes it. Test agent. |
| X1: `RealFx.platform!` maps `AARCH64` to `X64` | The machine is x86_64: no CPU other than x64 can show. Only the CPU of the host is tested. |

Final run: `scripts/test.sh` exit 0 (check 7.6 s, fmt 0.1, l0 3.4 with 52 files, l2 0.5 with 37 cases, l3 9.2 with 31 passed and 1 skipped, selftest 15.3, total about 36 s). `OPT=speed scripts/test.sh` exit 0, no `WARN` line.

## Review of the code (manager, 2026-10-22)

`scripts/test.sh` passes (manager run); `OPT=speed` passes with no `WARN` line (code agent run). The revert check caught 43 of 45. C1 to C6 are accepted. T17 (the KB value of `size_text` is cut, not rounded) moves to slice 022: one L0 row such as `1550` gives `1.6 KB`. X1 (the arm64 map of `RealFx.platform!`) cannot show on an x86_64 host: it waits for the CI macOS arm64 job (slice 018b). Note: `cli/RealFx.roc` has 772 lines; a later slice that adds an `Fx` field splits it by area.
