# Design gaps of PLAN-P1 section 5b and 6: decisions (2026-10-26)

The design agent applied the user answers A and B of 2026-10-26, decided the open questions U1 to U6 and the other open choices on best practice, and wrote the rules for the slice 076 manager answers. Method: as in `DESIGN-GAPS-2026-10-25.md`. Read the rule, prefer the reading that the code follows when it is sane, edit the design text, write one row here. A choice that the design cannot make goes to "Questions" (TW17).

Files changed: `DESIGN.md`, `DESIGN-CLI.md`, `DESIGN-RESOLUTION.md`, `PLAN-P1.md` (section 5b and 6 marks), `DESIGN-GAPS-2026-10-25.md` ("For the user" marks). No test, no code, no `TESTING.md`.

## A. The user answers A and B: a command with no compiler selected

| Id | Decision | Rule ids | Old text (short) | New text (short) | Why and reference | Code today |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | One table gives the project or package of each command and the order of choice | R-SO23 (new) | R-SO14 said "the project of the command context". A tool has no such project. No table. | R-SO23: rows for a fetch (R-FE4), the resolve and probe commands, the proxy, `run`, `init`, tool commands, `tool rebuild`, and a command with no project. The first step that gives a compiler wins. | The user asked for "one place". The rows for `run` and `init` are the manager recommendation (the project of the current dir), which the user did not object to. `init` has no project yet, so it takes the latest in the channel (R-IN2, R-NI12). | The 072b flows follow the rows of the resolve commands. `init`, `run`, tools: see A2 |
| A2 | A tool tries installed compilers first and downloads its pin last | R-T30 (new), R-X1, R-SO22 | R-T12 to R-T16 only: a pin download is the default of the prompt. R-SO14 gave a tool no rule. | R-T30, when no compiler is selected: (1) the pin if installed, (2) an installed release with a recorded pass for the closure, (3) the other installed releases tried one by one with no prompt (R-T17 to R-T19, facts R-T21), (4) only then the pin, downloaded under R-DL1 to R-DL6 with the R-NI8 prompt (options 1 and 3), and the compiler becomes the default. `--roc pinned` skips step 3. `--roc installed` ends after step 3. Applies to `tool install`, `x`, project tool builds, `tool update`. | The answer of the user. "Resolves for the tool" is read as a recorded pass for the closure (R-T13) or a pass of the try (R-T19). A try needs no download and no consent: a pass of check and build is the evidence that R-T6 asks for. | `ToolFlow.roc:292` passes `none: Stop`: exit code 18. R-T30 is not coded. Slice needed. |
| A3 | The default compiler after the download | R-SO15, R-SO14 | R-SO15 said a tool pin download never sets the default. | The exception is R-SO14: when no rank selects a compiler, the compiler that a command downloads becomes the default (when none is set), also for a tool (its pin). A release that a tool takes from the installed ones is no download and never becomes the default. | The user: "the downloaded compiler becomes the default when none is set". R-SO15 case (2) already said this for a project and outside a project. The answer of the user fits the old limit of R-SO15 (a): no rank selects a compiler. It does not answer the question (b) of "For the user" of 2026-10-25, which stays open. | With the 072b flows, yes. For tools: with A2 |
| A4 | `tool rebuild` has no choice | R-SO23, R-T30, R-NI17 | R-NI17: download the recorded compiler | The recorded compiler (R-T7), installed or downloaded. The downloaded one becomes the default when none is set. | `rebuild` builds the same build id (R-T4, R-T7). A free choice would change the build id. The user listed `rebuild` for the default rule only, I read. | With A2 |
| A5 | The unpack of a tool app bundle | R-FE4, R-SO23 | R-FE4 ended with "suits the project, or the latest outside a project". | A tool has no fact before its bundle is unpacked (the pin is inside), so R-FE4 takes the latest in the channel when nothing is installed. | The pin is only in the bundle (R-T10) and `roc unbundle` needs a compiler. The result on an empty machine: one download of the latest (the default) for the unpack, and a second one of the pin if no installed release passes (R-T30 step 3 tries the first one too). The user should know it. | With A2 |
| A6 | R-AL10 to R-AL12 | none | | none | These rules are the text of the explanation `no tuple works`. They do not choose a compiler. | none |
| B1 | A project with no pin | R-SO14 | "the compiler that suits that project", then evidence, then the latest | "a compiler that resolves for its platform and its packages": the newest compiler in the channel with a recorded pass for each header hash that has a fact (the platform and the packages), else the latest in the channel. No default is set before the download; the downloaded one becomes the default. | The answer B. The current text was the same in effect (evidence, else the latest). I kept evidence as the meaning of "resolves": before a compiler exists, no probe can run. The candidates are the compilers of the channel, as the old text said. | The code follows it (`NoRank.pick`). None |

## C. Decided on best practice

| Id | Decision | Rule ids | Old text (short) | New text (short) | Reference (one line) and why | Code today |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | Every `roc build` that Talon runs passes `--no-cache` | R-LD8 (new), R-T8, the note after R-TG6 | No rule. A note said the flag of a user script does not matter for step 3. | R-LD8: ladder step 3, the unit probe build, the smoke build, a tool build, `tln x`, a project tool, the option 2 try of R-T19, and the source build of Talon pass `--no-cache`. `roc check`, `roc test` and the proxy do not. R-T8 names the flag. | `cargo install` builds in a clean target dir, and Nix builds in a sandbox with no shared cache. A probe fact never expires (R-P4), and a tool is a release build: neither may depend on a warm cache that gives a bad `--opt=dev` build (`research/roc-object-cache/RESULTS.md`). The cost is small: `--opt=speed` reuses no object, and a dev build is 1.3 times slower. | No `--no-cache` in `Probe.roc:79`, `ProbeUnit`, `LadderPlan`, `ToolInstall.roc:249`, the smoke build. Slice needed. |
| C2 | U1: record the entries that Talon made | R-ST11, R-ST9, R-T4 | R-ST9 repairs a stale entry. R-ST11 makes a stale entry foreign. They differ. | (a): `tools.json` has a new optional field `bin` (name to sha256 of the file that Talon put in the bin dir). An entry is Talon's when its sha256 equals the data file or the recorded one. A stale entry is repaired by `tln setup`. An entry with neither is foreign and stays. `format` does not change (R-TF2). | Cargo keeps `.crates.toml` and Homebrew keeps its link record, and neither replaces a file that is not in it. This keeps R-ST6 and repairs R-ST9. | The code is (c) today: no record, a stale entry counts as foreign. Slice needed (`ToolsJson`, the writers of entries, `Setup`). |
| C3 | U2: GC keeps a toolchain by OR | R-GC5 | "keeps the default, and the toolchains that a known project pins and used in the GC age": AND or OR | OR: a toolchain stays when it is the default, or a known project pins it, or it was used in the GC age. | Nix GC roots: a root keeps what it names, whatever its age. An old nightly can leave the release list, so a removed pin may not download again. | The code is OR. None. |
| C4 | U3: `--no-check` runs no probe | R-BL6 | "Unit probes still run" | `--no-check` runs no probe at all, so it needs no compiler (R-SO22). Recorded facts still count. | A skip flag skips the work. R-SO22 and the P0 answers rely on it. | The code is (a). None. |
| C5 | U4: the union of the module sets | R-EP6 | "copies the set of failing modules of its source" | In case (b) the inferred fail has the union of the 2 sets. | No close reference (no tool infers module sets). The choice is on the safe side: more probes, never a skipped one. An inferred fact never decides alone (R-EP8). | The code is the union. None. |
| C6 | U5: one prompt, for the required download only | R-DL1 | "...the prompt does not list it" | Added: the prompt lists the required downloads only, one prompt covers them, and optional downloads need the opt-in flag. R-NI4 already says it. | `cargo` and `rustup` never fetch more than the command needs, unless a flag asks. | The code is (c). None. |
| C7 | U6: a report is exit 0 | R-E7 (new), R-PB8 (new), R-CM6 | No exit code for a failed probe target, a `--range` with no pass, or a row that is behind | `tln probe` exits 0 when its facts are printed, also for a fail, a hang, a crash or no pass. Exit 1 only with no fact. Budget stays 12. `tln outdated` exits 0 when a row is behind. `tln verify` is the CI gate. | `pip list --outdated`, `uv pip list --outdated` and `cargo outdated` exit 0 by default. `npm outdated` exits 1. A flag like `cargo outdated --exit-code` is not designed. | The code is (a). None. |
| C8 | `tln setup` "latest" uses `min-release-age`, and no release is no failure | R-ST16 | `min-release-age` was in the text and the question of the user was open. No rule for "list read, no release allowed". | `min-release-age` applies (the key of `config.toml`, else 2 days). A list that is read but has no allowed release gives the same as an unreadable list: no default, a note, exit 0. Exit code 10 comes at the first command that needs a compiler (R-SO14, R-NS2). | pnpm `minimumReleaseAge` and uv `exclude-newer` apply to the version that a command picks. Setup must not fail an install (R-IS7 passes its exit code on). | The code is this (072a Q1 (a), Q3). None. |

## D. Slice 076 manager answers and the safe path part

| Id | Decision | Rule ids | Old text (short) | New text (short) | Why | Code today |
| --- | --- | --- | --- | --- | --- | --- |
| D1 | `[patch] base` | R-PA15 (new) | none | One safe path part. Else exit 19, on the line of the key, before any read. | `base` names a cache dir (R-PA13). | Same (`Intent.read`). `PatchApply.base_check!` has exit 2 too, but `Intent.read` stops first. None. |
| D2 | `[patch] path` | R-PA16 (new) | none | The copy dir is strictly inside the repository (the workspace root, else the dir of the `talon.toml`), after the path is normalized. Outside or equal: exit 19, before any read, delete or write. | `install` and `update` delete and write that dir (R-PA5). It differs from R-RUN8 in two points, as slice 076 D6 and D7 say: the stop dir is the workspace root or the dir of the `talon.toml` (not the stop dir of R-PD2), and the equal dir is refused. R-RUN8 is for a dir that only runs a command. | Same (`Patched.check_inside`). None. |
| D3 | The safe-part rule, once | R-SE18 (new), R-ID3, R-ID5, R-DI2, R-DI8 | Each rule used its own words, or none | R-SE18: not empty, not `.`, not `..`, no `/`, no `\`, no NUL byte. A table gives the result for each part: owner and repo (a URL: no name; a typed name: exit 2), tag (no hint), hash (foreign; `[tools]` url exit 19; a fetch exit 2), `base` (19), `path` (19), Zig archive (18), nightly asset (not a candidate). The other rows name R-SE18. | The exit codes are those of the code (slice 076, D1 to D4). No conflict with an existing rule. | Same. None. |
| D4 | Zig archive name | R-D2 | none | An archive name that is not safe: exit 18, before any write, as a release with no archive. | The code uses the failure `no_archive` (Environment, exit 18). | Same. None. |
| D5 | Nightly asset name | R-CV2 | none | An asset with an unsafe name does not count. The release is then not a candidate on the host. A command that names it: exit 2, `<id> has no asset for <target>`. | The code gives `NoAsset` (`Nightlies.read_asset`), and `Toolchain` gives exit 2 for a named release. | Same. None. |

## Code that differs from the new text (slices for the manager)

| # | Place | What the code does | What the text says |
| --- | --- | --- | --- |
| 1 | `ToolFlow.roc:292` (`Fetch.packages!` with `none: Stop`), `ToolCompiler`, `ToolFlow`, `XFlow`, project tool builds, `ToolUpdate`, `ToolManage` (rebuild) | A tool command with no compiler fails with exit code 18 (`NoCompiler`) | R-T30, R-SO23, R-FE4: an unpack with the latest in the channel, the order 1 to 4, the default after the download (the 072c family) |
| 2 | `Probe.roc:79`, `ProbeUnit`, `LadderPlan`, `ToolInstall.roc:249`, the smoke build, the source build of Talon | `roc build` with no `--no-cache` | R-LD8, R-T8 |
| 3 | `ToolsJson`, the writers of bin dir entries, `Setup` | No `bin` record. A stale entry is foreign. | R-ST11 (2), R-ST9, R-T4 |
| 4 | `ToolCompiler` (`decide`: R-T14 gives the prompt with option 2), `ToolCompilerFlow` | With other installed releases and no evidence, the prompt shows with the try as option 2 | R-T14, R-T20, R-T30: the try runs first with no prompt, also when a compiler is selected. The prompt has options 1 and 3 only (Q-A1) |
| 5 | `NoRank.pick` (`auto` is the channel only), `NoRank.offer!` | No installed compiler is a candidate. It always downloads | R-SO14 (a) and (b): the newest installed compiler that resolves is used first, then the installed compilers are probed newest first (ladder of R-PB2, `probe.max`), all with no download and no default (Q-B1) |

The coded manager recommendations U2, U3, U4, U5, U6 (and the code of C8, D1 to D5) match the new text: no slice.

## Questions (TW17), all answered by the user on 2026-10-26

| Id | Question | Decided | Rule ids changed |
| --- | --- | --- | --- |
| Q-A1 | Does the order of R-T30 (try installed first) also apply when a compiler is selected? | Yes. When a compiler is selected but does not resolve for the tool, `tool` and `x` also try the other installed compilers (installed with a pass, then the try, the selected one first) before the prompt. The prompt (R-T14, R-T15, R-T20) then has options 1 and 3 only, and shows after the try. `--roc installed` still selects the try alone. The default is set only when no compiler is selected. | R-T30 (now for any compiler state), R-T14, R-T15, R-T16, R-T20, R-T21, R-T6, R-NI8 row, the prompt example of 6.4, R-X1, R-SO22, R-SO23 (tool row) |
| Q-B1 | A project with no pin: are installed compilers candidates first? | Yes. (a) The newest installed compiler that resolves (a recorded pass for each header hash that has a fact, at least one hash with a fact): used, no download, no default. (b) Else probe the installed compilers (see below). (c) Else the newest compiler in the channel that resolves: downloaded, default. (d) Else the latest in the channel: downloaded, default. The user then answered the case with no deciding fact: "Probe installed first". New step (b): probe the installed compilers, newest first, with the ladder of `tln probe` (R-PB2). The first pass is used, with no download and no default. A compiler with a recorded fail for a header hash is skipped (a fact never expires, R-P4). The cap is `probe.max` and `probe.timeout` (R-P5, R-PP4); `probe.max-toolchains` and R-DL6 do not apply (no download). A spent `probe.max` ends the step with no exit 12. `--no-probe` and `--no-check` skip it. The old steps (b) channel with a pass and (c) latest are now (c) and (d). | R-SO14 (new step (b)), R-SO23 (resolve row) |
| Q-A2 | R-T29 (a tool with no `roc:` pin: exit 2) before R-T30? | Keep it. No text change. | none |
| Q-A3 | `tool update` and step 3 of R-T30 | Skip step 3 for `tool update` (steps 1, 2, 4). The text names the user, not the question. | R-T30 |

The rows A2 and B1 above show the first version. The new text of R-T30, R-SO14 and R-SO23 is in the files.

## Questions of slices 072c and 079 (test step), decided 2026-10-26

| Id | Question | Decided | Why and reference | Rule ids |
| --- | --- | --- | --- | --- |
| 072c Q1 | Do `Hang` and `Crash` skip a compiler in R-SO14 (b)? | Yes. A recorded fail, hang or crash for a header hash skips the compiler. | A fact does not expire (R-P4), and R-P7 says a hang or a crash is a fault of that compiler on this code. A signal from outside gives no fact (R-P3), so a recorded one is real. | R-SO14 |
| 072c Q2 | A pin that is not installed (information, no edit) | The manager answer stands: R-DL2 downloads a pin. R-SO14 applies only with no pin. The R-SO14 trigger already says it. | | none |
| 072c Q3 | Are local builds candidates in R-SO14 (a) and (b)? | No. Only an installed nightly or release. | R-NS6: a local build is not a candidate. R-FE4 "newest" excludes it. A local build has no release to download again. | R-SO14 |
| 079 Q1 | Does `tool update` apply R-T30 step 2? | Yes. R-NI17 now agrees: its prompt counts a download only when steps 1 and 2 find no installed release. | Step 2 reads facts and builds nothing, so the plan stays pure (R-T25). It saves a download. | R-NI17, R-T30 |
| 079 Q2 | Can a selected local build be tried first? | No. | A tool needs a build id with a compiler that Talon can download again (R-T5, R-T7). R-NS6. | R-T30 |
| 079 Q3 | Does a `roc` on `PATH` count as selected for tools? | Yes, when its id is a nightly tag or a release (R-SO10). The selected compiler is the one of ranks 2, 6 and 7. A `PATH` `roc` with another id is a local build and is not tried. | R-SO10 says such a binary counts as an installed compiler with that id. A tool has no project, so ranks 3 to 5 do not apply (rank 3 is the pin of step 1). | R-T30 |
| 079 Q4 | `--roc installed`, a person, all failed: prompt or exit 13? | The prompt of R-T20 (options 1 and 3). With no person: exit 13. | The flag answers the try only (R-NM10) and gives no consent to a download. The person can still answer 3. | R-T30 |

Code that differs from this text: the 079 reference reads no evidence for `tool update` (Q1, option b). The tool flows ignore `PATH` (Q3). Slice 072c's `first` may count `Hang` and `Crash` as no skip (Q1): L0 has `Fail` rows only.

## Questions of slice 072d (test step), decided 2026-10-26

| Id | Question | Decided | Why and reference | Rule ids |
| --- | --- | --- | --- | --- |
| Q-D2 | When is the compiler picked for `install`, `update`, `add`, `upgrade`, `remove` with checks and no pin and none selected? | (b): before the index and before any write, only when a probe will run. A run with nothing to check picks nothing. The pick is an id; its download comes at the first probe. | R-SO22 says the download is at the first probe, not before. R-SO19 needs the held nightly before the index. A pick for a run with nothing to change would be a download for nothing. | R-SO19 |
| Q-D3 | Base of a relative selector with no compiler selected | (a): the R-SO14 pick as an id only, no download, no default, and without step (b) (no probe for an id). | R-SL7 counts from "the compiler that Resolution 13 selects". With none selected, the pick is the nearest meaning. A selector must not start probes or downloads. | R-SL7, R-SO14, R-SO23 |
| Q-D4 | Does the proxy run the hidden probes of step (b)? Where are the hashes? | No. The proxy has steps 1, 3 and 4 only. It gets the hashes from the header of the target file, which it reads already for the pin (rank 3). It prints no default line. | R-PX2 (cost target 5 ms) and the proxy stdout is the stdout of `roc` (R-PX3). A rustup proxy does not probe either. The proxy may still download under the consent rules. | R-PX4, R-SO14, R-SO23 |
| Q-D5 | `roc use` with the pick and the new compiler both missing | One prompt (R-DL1) for both. The pick (the baseline) downloads first and becomes the default (R-SO15). The new compiler downloads second. | R-U3 already puts the baseline in the same prompt as the new nightly. R-SO14 has the default rule. | R-U3 |
| Q-D6 | `init/it4-nocompiler` result | Not a design question (code cause). No edit. | | none |

Code that may differ: the 072d reference picks before the resolution (Q-D2) and gives the relative selector an id by a pick that may probe (Q-D3). The proxy needs a `hashes` field from the target header, and no step (b) (Q-D4). `roc use` needs one prompt with the pick first (Q-D5).

## Questions of slice 072e (test step), decided 2026-10-26

| Id | Question | Decided | Why | Rule ids |
| --- | --- | --- | --- | --- |
| Q-E1 | How does a plain `install` know before the index that it has nothing to change? | (a): a plain `install` with no name whose `--frozen` check passes (R-LF1: the header satisfies `talon.toml`) has nothing to change and picks nothing. Else it picks. | It uses a rule that exists, and it is pure and needs no index. A pick for no change would cost a list read and the facts. | R-SO19 |
| Q-E2 | `upgrade`, nightly free, no compiler selected: one download or two? | (a): one download and one prompt (R-NI12, default yes), when the pick is the newest nightly. The compiler is the held nightly and the candidate. It becomes the default, with the line `It becomes the default compiler.` When the pick is another compiler, one prompt lists both, the pick first. | The command names the newest nightly (R-UP6). One prompt per command (R-DL1), as R-U3. | R-UP6 |
| Q-E3 | Relative selector with a range and no installed compiler in it | (a): the base is the newest release in the range (R-SO13), as an id, with no download. | R-SO14 does not apply with a range, R-SO13 does. Exit 18 is P0 only (R-EC18). | R-SL7, R-SO23 |

Code that may differ: the reference always picks for a plain `install` with a `talon.toml` (Q-E1 c).

## Invariant: a compiler is always selected (user answer, 2026-10-26)

The user: there should be no state with installed compilers and none selected. The user deletes all compilers, then one is installed by an explicit act, or becomes the default when Talon downloads it while no other is installed.

New rule R-SO24: when at least one nightly or release is installed, `default-roc` is set. It names an installed compiler, or one that is not installed (selected but missing: a required download, R-SO12). So "no compiler selected" (R-SO14) means "nothing installed". Local builds (`link-*`, `copy-*`, `git-*`) do not count: R-NS6 says Talon never selects them. `tln roc link` sets no default (as `rustup toolchain link`). A user can name one as the default.

| Way into the forbidden state | How the rule closes it | Rule ids |
| --- | --- | --- |
| A download that R-SO15 said never sets the default (a probe, a pin, `upgrade`, `init`, `roc use`, a tool, `x`, the proxy) | Each install sets the default when none is set, under the `config.toml` lock, before the final rename. A set default is never changed. | R-SO24, R-SO15 |
| A crash between the default write and the rename | The default is selected but missing, which is allowed. The next command downloads it. | R-SO24 case 4 |
| `tln roc remove` of the default while others stay, and the switch filter of R-RR1 (the old text could leave the default unset with nightlies installed) | The default moves to the newest installed compiler that the switch admits, else (none admitted) to the newest installed nightly or release of any kind. Exit 10 comes only when nothing admitted is installed. (Manager review, 2026-10-26.) | R-RR1, R-SO24 |
| `default-roc` deleted by hand, or a deleted `config.toml` | Rank 6 gives the newest installed nightly or release for the run, with one note. No file is written on a read (the proxy stays fast). `tln setup` writes it. | R-SO24 case 3, R-ST16, R-SO6 |
| `default-roc` names a removed id | Selected but missing: R-SO12 downloads it on need. No repair on a read. | R-SO24 case 4 |
| `default-roc` of bad form | Exit 19 (R-TF4). | R-SO24 |
| GC | R-GC5 keeps the default. No change. | R-GC5 |
| `install.sh` and `tln setup` | With nothing installed: the latest in the channel, no download (selected but missing). With compilers installed and no default: the newest installed one. | R-ST16 |
| `tln tool rm talon` | Options 1 and 2 remove compilers and `config.toml` together. Option 3 keeps both. No change. | R-RM9, R-RM10 |
| Two processes | Each write is under the `config.toml` lock. | R-SO24 |

Simplified rules:

| Rule | Change |
| --- | --- |
| R-SO14 | Trigger: nothing installed. Steps (a) installed with a pass and (b) probe the installed ones are removed. The pick is the channel with a recorded pass, else the latest. A download makes the default. |
| R-SO23 | The resolve row has two steps. The proxy and the relative selector rows follow it. The R-SO24 table is added after it. |
| R-SO15 | One statement: an install sets the default only when none is set. The two-case text is gone. |
| R-T30 | Title "Always". The no-compiler branch text is one sentence: the step 4 download is the default only when none is set. The order for a selected compiler (Q-A1) is unchanged. |
| R-NI17, R-PX4, R-ST16, R-RR1, R-SO6 | Wording follows R-SO24. |
| R-SO19, R-SL7, R-U3, R-UP6 | Kept. They still apply when nothing is installed. |

Superseded earlier decisions of today:

| Decision | State |
| --- | --- |
| Q-B1 "installed first" and its follow-up "probe installed first" (R-SO14 steps (a), (b), the `probe.max` and skip text) | Superseded: no installed compiler without a selected default |
| 072c Q1 (`Hang` and `Crash` skip) and 072c Q3 (local builds in (a), (b)) | Moot: the steps are gone. The local build rule is R-SO24 |
| 072d Q-D2, Q-D3, Q-D5 | Kept for the nothing-installed case. The words "without step (b)" are moot |
| 072d Q-D4 | The proxy has no probe: kept. The "no step (b)" words are moot |
| 072e Q-E1, Q-E2, Q-E3 | Kept (nothing installed; Q-E3 is about a range, rank 4, so it is not changed) |
| A1 to A5, Q-A1 to Q-A3, 079 Q1 to Q4 | Kept. R-T30 steps 1 to 3 apply to the selected compiler |

Code that becomes dead or must change (for the manager): `NoRank.pick` steps (a) and (b) and `NoRank.Probing` (dead); `HeldRoc` (the pick before the resolution stays, for nothing installed); the 072c/072d/072e cases that show an installed-first pick or a probe of installed compilers (change or remove); the `ToolFlow` none branch (stays for nothing installed); `Proxy` (no probe: no change, and rank 6 must give the newest installed one when `default-roc` is unset, with a note); `RocRemove`/`RocManage` (R-RR1: newest admitted, else newest of any kind); every install path (`RocInstall`, `Probe` downloads, tool pins, `x`, proxy) must write the default when none is set, before the rename; `Setup` (write the newest installed one when no default and compilers are installed).

Questions: none. Review result (manager, 2026-10-26): R-SO24 accepted. R-RR1 prefers an admitted compiler and falls back to any installed one. `tln roc link` sets no default: accepted. `RocRemove` and `RocManage` code: prefer admitted, else newest of any kind.

## Notes

| Item | Note |
| --- | --- |
| Rules that name the changed ids | `DESIGN.md` index: R-LD8, R-PB8, R-SO23, R-E7, R-T30, R-ST16, R-PA16, R-SE18. |
| `scripts/rules.sh` | Lists the new ids R-SO23, R-T30, R-LD8, R-PB8, R-E7, R-PA15, R-PA16, R-SE18 with no test. |
| `TESTING.md` | Not changed. R-LD8 needs a line in its section on `--no-cache` (the test runners already pass it). |
