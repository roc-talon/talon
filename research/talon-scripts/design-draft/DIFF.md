# Design draft D-TS: project scripts, `tln path`, project tools, build target

Date: 2026-10-24. The draft of the design change that `research/talon-scripts/README.md` section 13 lists. The user approved the draft step. It is for the human review before a code slice starts. No commit.

| Item | Value |
| --- | --- |
| Decisions used | Study 12: Q-S1 to Q-S11 (Q-S11 option (a)). Q-S12 to Q-S15: the lean of study 12.1 |
| Files before the change | `before/DESIGN.md`, `before/DESIGN_OVERVIEW.md`, `before/DESIGN-CLI.md`, `before/DESIGN-RESOLUTION.md` |
| Full diff | `design.diff` (`diff -u before/<file> <file>`, 4 files) |
| Lines added / removed | `DESIGN.md` +29 / -13, `DESIGN_OVERVIEW.md` +4 / -2, `DESIGN-CLI.md` +205 / -22, `DESIGN-RESOLUTION.md` +26 / -6 (after the user answers of section 2) |
| Not changed | `DESIGN-REGISTRY.md`, `TESTING.md`, code, tests, `cloudflare-workers/` |
| Id check | `scripts/rules.sh` lists each new id once. No new id clashes. 5 duplicate ids existed before this change and are not touched: R-AP45, R-AP46, R-AP47, R-CF1, R-CR1 |

## 1. Changes

| # | File | Section | Rule ids | Change |
| --- | --- | --- | --- | --- |
| 1 | `DESIGN.md` | Status table | | A line for this draft change |
| 2 | `DESIGN.md` | 1 | G1, G2 | Q-S11 (a): the `url` of `[tools]` is the one lock value outside the header. No lock file. `talon.toml` holds intent and that lock |
| 3 | `DESIGN.md` | 4 (Core model) | | Intent row: scripts, build target, project tools |
| 4 | `DESIGN.md` | 4.3 | | Title "intent, and the lock of project tools". Example adds `[build]`, `[tools]`, `[scripts]` |
| 5 | `DESIGN.md` | 4.4 | R-WS5 | `[tools]` in the root file only. `[build]` and `[scripts]` where allowed. `[run]` in each file except the root |
| 6 | `DESIGN.md` | 5 | | Id rows: R-RUN, R-EA, R-HK1, R-PTH, R-PT, R-TG. Ranges R-CM1 to R-CM25, R-IN1 to R-IN8, R-C1 to R-C10, R-SE1 to R-SE17 |
| 7 | `DESIGN.md` | 7 | R-PH3, R-PH9, R-PH10 | `run`, `path` and project tools in P1. R-TG1 to R-TG6 in P0 (ladder step 3). R-C10 in the P0 search |
| 8 | `DESIGN.md` | 8 | R-SE17 (new) | `tln run` runs project commands: trust as `make`. Points to R-HK1, R-RUN2, R-PT8 |
| 9 | `DESIGN_OVERVIEW.md` | Components, Left to others | | CLI runs named scripts, no hooks. Toolchain manager builds project tools. Build graphs and caches: `make`, `just`. Deploy and dev servers: platform tools |
| 10 | `DESIGN-CLI.md` | 1 | R-CM24, R-CM25 (new), R-CM2 to R-CM6, R-CM12 | `tln run`, `tln path`. `--tool` on `install`, `remove`, `update`, `upgrade`. `outdated` rows for tools. `tln x <key>` |
| 11 | `DESIGN-CLI.md` | 1 | R-FL1, R-FL12 | `tln run <name>` rejects `--json`. Rows `--each`, `--keep-going`, `--tool` |
| 12 | `DESIGN-CLI.md` | 1 (The project) | R-PD14, R-PD16 | `path` uses a project. `run` uses none (walk of R-RUN12) |
| 13 | `DESIGN-CLI.md` | 1 (`tln audit`) | R-AU1 | The `[tools]` URL hashes join the audit list |
| 14 | `DESIGN-CLI.md` | 1, new subsection `tln run` | R-RUN1 to R-RUN17, R-EA1 to R-EA8, R-HK1 | Study 3, 3.4 and 4, with PROPOSED removed. Flow diagram, "not in `tln run`" table, limits table, hooks table |
| 15 | `DESIGN-CLI.md` | 1, new subsection `tln path` | R-PTH1 to R-PTH5 | Study 8.3 |
| 16 | `DESIGN-CLI.md` | 3 | R-E1, R-EC2, R-EC18 | `tln run` exit code (child), `--json` usage error, program of a step not on `PATH` |
| 17 | `DESIGN-CLI.md` | 5 | R-IN8 (new) | Study 8.4: the R-SM2 stub with `crash "write the app"` |
| 18 | `DESIGN-CLI.md` | 6.2 | R-DL7 | Adds `run` |
| 19 | `DESIGN-CLI.md` | 6.3 | R-GC4, R-GC7 | Keep the bundle and the binary of a project tool (R-PT14) |
| 20 | `DESIGN-CLI.md` | 6.4 | R-B9, R-X (text after R-X5) | Manifest holds the bundle hash. `tln x` in a project runs the project tool |
| 21 | `DESIGN-CLI.md` | 6.4, new subsection Project tools | R-PT1 to R-PT16 | Study 6.2, case table, lock diagram |
| 22 | `DESIGN-RESOLUTION.md` | 2 | R-C10 (new) | Hard constraint: the platform release has the build target (R-TG3) |
| 23 | `DESIGN-RESOLUTION.md` | 4 | R-LD5, new subsection Build target | `roc build --target=<build target>`. R-TG1 to R-TG6 (study 7) |
| 24 | `DESIGN-RESOLUTION.md` | 5 | R-AL3, diagram | R-C10 in step 3. Diagram node "build for the build target" |
| 25 | `DESIGN-RESOLUTION.md` | 9, 10 | (text, no id) | A project tool is not a variable. How `update`, `upgrade`, `install` move its `url` (R-PT5) |
| 26 | `DESIGN-RESOLUTION.md` | 12 | R-LF1 | `--frozen` also checks R-PT7 and builds tools with no binary (R-PT6) |

Small additions to the study text, for the review. Each one follows from a study decision or from the study text:

| Rule | Addition | From |
| --- | --- | --- |
| R-RUN8, R-EA3 | `after` has no effect on `in` steps | Q-S13 (a) |
| R-EA7, limits table | No parallel runs | Q-S12 (a) |
| R-PT5 | Talon builds the new release before it writes the `url` | Q-S14 (a), as R-PT3 |
| R-RUN11 | A note for a `[tools]` key that is also a program on `PATH` (text is a proposal) | Q-S15 (b) |
| R-RUN16 | "One exception": a project tool with no binary is fetched and built (R-PT9) | The study case table has network in `tln run` |
| R-RUN6 | "Talon has no script platform" | Study 5, option P4 |
| R-PT3 | Talon creates `talon.toml` when it is missing | `TRANSITION.md` 3.1, 7 (`tln add --tool` makes the file), as R-AD25 |
| R-PT5 | "With `--tool`, each name is a `[tools]` key" | R-PT5 names `--tool` in its error. See open point 5 |
| R-C10 | New id, not in the study | Study 13 asks for a constraint row in Resolution 2. See open point 7 |
| `tln run` table | Row "`tln run --dry-run`: No" | Q-S9 |

## 2. Open points for the user

Where the study and the design conflict, or the study leaves a point open that a code slice needs. The user answered all 10 on 2026-10-24, and accepted the small additions of section 1 (R-PT3 creates `talon.toml`, the R-RUN16 exception). The answers are in the design text.

| # | Point | Where | Options | User answer (2026-10-24) |
| --- | --- | --- | --- | --- |
| OP1 | `tln install --frozen` now builds project tools (R-PT6), so it needs a compiler and the consent rules. But Resolution R-SO14 and R-SO22 say that `install --frozen` needs no compiler and runs no probe, and R-DL7 lists `install` for compiler downloads only through probes | R-PT6, R-PT7, Resolution R-SO14, R-SO22, R-LF1 | (a) Change R-SO14 and R-SO22: `--frozen` needs a compiler when a tool has no binary. (b) `--frozen` only fetches the tool bundle, and the build waits for the first run | (a). Done: R-SO14, R-SO22, R-LF1, R-DL7 |
| OP2 | Phases. `install` and `install --frozen` are P0 (R-PH2), and `[tools]` is P1. In P0, R-TF4 gives a warning for the unknown tables `[tools]`, `[scripts]`, `[run]`. In P1, the same `install --frozen` can fail with 14 for a `[tools]` entry. R-PH1 says that a phase only adds steps | R-PH1, R-PH2, R-PH3, R-PT7, CLI R-TF4 | (a) Accept: P1 adds a step and a new failure. (b) P0 already checks the form of `[tools]` (R-PT1) and R-PT7 | (a). Done: a sentence in R-PH3 |
| OP3 | Known projects. `tln run` and `tln x <key>` use no project file (R-PD16), so they do not record a project (R-PD9). R-PT14 keeps a tool only for a known project that "was used in the GC age". A project that only runs `tln run` can lose its tool binary to GC | R-PT14, R-PD9, R-PD16, R-GC7 | (a) `run` and `tln x <key>` record the project files under the `talon.toml` that they read. (b) Record the `talon.toml` path in `projects.json`. (c) Accept: the next run builds again | (a). Done: R-PD9, R-PD16, R-PT14 |
| OP4 | Which `[tools]` table a step uses. R-RUN3 says "a key of `[tools]`" with no file. R-PT11 says "the root file in a workspace" for `tln x`. Also a standalone project inside a workspace directory (R-PD5): is its own `[tools]` "another file of the workspace" (R-PT2, exit 19)? And for an `in` step in another directory | R-RUN3, R-PT2, R-PT11, R-RUN8 | (a) The `[tools]` of the workspace root of the file that holds the script, else of that file (standalone). (b) Another rule | (a). Done: R-RUN3 (2) |
| OP5 | `--tool` on `update` and `upgrade`. R-PT5 names `--tool` in an error, but no study rule defines `update --tool` or `upgrade --tool`. I wrote: with `--tool`, each name is a `[tools]` key. Is `tln update --tool` with no names "only the tools"? | R-PT5, R-FL12, R-CM4, R-CM5 | Confirm, or give the meaning | With `--tool`, each name is a `[tools]` key. With `--tool` and no names, only the tools. Done: R-PT5 |
| OP6 | R-PT9 row 1 finds a global tool by its bundle hash. R-T4 (`tools.json`) has no bundle hash field. Study 13 adds the field to the manifest of R-B9 only, and R-B9 says that the manifest has the same fields as `tools.json` | R-PT9, R-T4, R-B9 | (a) Add the bundle hash to R-T4 too. (b) Drop row 1 of R-PT9 | First (a), then changed to (b): global and project tools stay separate. No bundle hash in R-T4. R-PT9 row 1 dropped: a project tool never runs a global binary, and its builds are only in `talon/x/`. Done: R-PT9, R-PT12, R-PT13 |
| OP7 | R-C10 is a new id that repeats the constraint of R-TG3 (two ids for one fact, two tests) | Resolution R-C10, R-TG3 | (a) Keep both. (b) R-TG3 keeps the value check only and points to R-C10 | (b). Done: R-TG3 has the value check only. R-C10 has the constraint and its reason |
| OP8 | R-IN8: a platform whose `requires` has a type that R-SM2 cannot fill ("Any other type: no smoke build"). What does `tln init --platform` write then? Also `--platform roc-lang/basic-cli` given by name: the basic-cli template of R-IN1, or the stub? | R-IN8, R-IN1, Resolution R-SM2 | (a) Exit code 2 with a message. (b) A header with no body. For basic-cli: (a) the template, (b) the stub | Exit code 2, nothing written, the message names the type. basic-cli by name: the R-IN1 template. Done: R-IN8 |
| OP9 | `tln run --each <name> -- <args>`: R-RUN10 does not say whether the args go to the last step of each node | R-RUN10, R-RUN13 | (a) Yes, each node. (b) Exit code 2 | (a). Done: R-RUN10 |
| OP10 | R-TG1 rule 1 names a target that the held platform does not have. R-TG3 makes the release no candidate. In `install` with no names, the platform is held (R-SP19): is that exit code 10 (`no_tuple`) or 2 before the resolve? | R-TG1, R-TG3, R-SP19 | (a) 10, as a hard constraint. (b) 2, a usage error found from the header | (a), exit code 10. Done: R-C10 |

### 2.1 New conflicts from the answers (not decided)

| # | Conflict | Where | User answer |
| --- | --- | --- | --- |
| NC1 | OP3: `tln run` records the project file of R-PD4 for a standalone `talon.toml`. A directory with a `talon.toml` and no `main.roc` (only scripts, or an app file with another name) gives no project file, so nothing is recorded and GC can still remove its project tool | R-PD9, R-PD4, R-PT14 | User answer: with no app file, record the `talon.toml` path itself. Done: R-PD9, R-PD12 (GC reads only its `[tools]`, R-RR2 ignores it), R-PD13, R-PT14 |
| NC2 | OP4: a standalone project in a workspace directory (R-PD5: the workspace has no effect on it) has a workspace root by the walk of R-PD3. So its steps use the `[tools]` of the root, and its own `[tools]` gives exit code 19 (R-PT2). This is an effect of the workspace on a standalone project | R-RUN3, R-PT2, R-PD5, R-PD6 | User answer: R-PD5 wins. A standalone project's `talon.toml` is its own root: its own `[tools]` is allowed and its steps use it. Done: R-PT2, R-RUN3 |

### 2.2 New conflicts from the second answers (not decided)

| # | Conflict | Where | User answer |
| --- | --- | --- | --- |
| NC3 | OP6 (b): R-B4 makes `tln tool install` take over (move) a matching `talon/x/` entry. When a project tool uses that entry, the move takes it away, and the next `tln run` builds it again (R-PT13 now says so). Options: accept the rebuild, or R-B4 copies or skips an entry that a known project tool uses | R-B4, R-PT13, R-PT14 | User answer: R-B4 copies the binary and keeps the entry when the `[tools]` of a known project uses it, else it moves it. Done: R-B4, the text before R-B9, R-PT13 |
| NC4 | NC2: the design has no test that tells a standalone `talon.toml` in a workspace directory from a workspace file. R-WS5 says "each other `talon.toml` in the workspace". A directory with only scripts (no member file and no project file below it) can be either. Also R-EA1 makes each directory of the workspace with a `talon.toml` a node of `--each`, so a standalone project in a workspace directory becomes a node | R-PD5, R-PD6, R-WS5, R-PT2, R-RUN3, R-EA1 | User answer: members decide. A `talon.toml` is a workspace file only when a member file is in its directory (or below it, up to the next `talon.toml`, as R-EA1 and R-PD6 do; the user confirmed this reading). Any other one is standalone and not a node of `--each`. Done: R-WS5, R-EA1, R-PT2, R-PT11 |

### 2.3 New conflict from the final read (not decided)

| # | Conflict | Where | User answer |
| --- | --- | --- | --- |
| NC5 | R-RUN12 walks up past the `talon.toml` of a standalone project to the workspace root, so `tln run <name>` in a standalone project inside a workspace directory can run a script of the root file (or of another `talon.toml` above it). R-PD6 says that a `talon.toml` in a parent directory is the intent of another project and has no effect, and NC4 made such a project standalone. Options: (a) the walk stops at the `talon.toml` of a standalone project; (b) keep the walk: scripts are not intent | R-RUN12, R-PD6, R-WS5 | User answer: (a). The walk stops at the `talon.toml` of a standalone project; root scripts have no effect there. Done: R-RUN12 |

Final read of `design.diff` (2026-10-24): each rule id that the added text names exists (`scripts/rules.sh`), each new id is unique, and the added text has no em-dash, no bold and no PROPOSED. One fix in this read: R-PT11 named "the root file in a workspace", now the table of R-RUN3. A defect that was there before is fixed with the consent of the user: R-SO14 named "CLI 2, R-LF1", now "section 12, R-LF1". The user confirmed again that R-PT9 row 1 stays dropped (OP6 (b)).

## 3. Parts of study 13 not done

| Study 13 row | State | Reason |
| --- | --- | --- |
| All 12 rows | Done | |
| Platform side (study 6, 8: the shim in the bundle, `roc-cfw`) | Not in the Talon design | Not a Talon rule. It is in `cloudflare-workers/research/talon-fit/TRANSITION.md`, which this task does not change |
| Study 11 (anti-patterns) and 10 (what stays external) | Not copied | Explanation, not rules. The design names `research/talon-scripts/` 11 where a rule gives its reason, and the overview row "Left to others" covers 10 |
