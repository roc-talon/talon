# P1 slice plan

The order of the P1 slices of the `tln` CLI (Design 7, `TESTING.md` 7.4). The manager keeps this file. It continues `docs/slices/PLAN.md` (P0, slices 001 to 017, all done). Each slice has its own file `docs/slices/NNN-<name>.md` (`TESTING.md` 7.2).

| Item | Value |
| --- | --- |
| Status | Draft 1, 2026-10-22. Not reviewed by the human. |
| Compiler, platform, generic packages | As in `docs/slices/PLAN.md` (nightly `nightly-2026-10-14-38a3029`, basic-cli 0.25.0) |
| P1 scope (Design 7) | Toolchain manager, `roc` proxy, `tln cache gc`, local probes and the PubGrub oracle, `tln tool` (CLI 6.4), `install.sh`, `install.ps1` and prebuilt Talon binaries (CLI 6.5) |
| P1 exit criteria (Design 7) | Talon finds a working tuple for parser 2.0.0 + basic-cli without help. GC frees the legacy dirs. |
| Commands (R-PH3) | `upgrade`, `init`, `outdated`, `probe`, `patch`, `x`, `tool ...`, `roc ...`, `cache ...`, `setup`, the `roc` proxy |
| Open P0 and P1 ids today | `MISSING=1 scripts/rules.sh` on the P0 groups lists 143 ids, on the P1-only groups 198 ids (2026-10-22). Section 1 gives each id a slice or a later phase. |

## 1. Scope

### 1.1 Rule groups by component, and the R-PH row that moves each into P1

| Component | Rule ids | R-PH row or phase source | Slices |
| --- | --- | --- | --- |
| Compiler list | R-CV1 to R-CV8 (direct branches), R-NS1, R-SC10, R-SC11, R-SC13, R-C7 for compilers | R-PH6 (installed compilers, downloads), R-PH3 (`roc ...`) | 020 |
| Compiler install | R-R8, R-CV4, R-CV5, R-HF2, R-HF4 (compilers), R-HF5 (`tar`), R-SE9 (`tar` part), R-SE11, R-CC4, R-GC10, R-SO15, R-NI6, R-TF1 (`.talon.json`) | R-PH6, R-PH7 | 021 |
| Selection ranks | R-SO1 to R-SO15, R-SO18, R-SO19 (ranks 4 to 6), R-NS2 to R-NS4, R-NS6, R-EV5 (P1 part) | R-PH6 ("ranks 1 to 6") | 022 |
| The `roc` proxy | R-PX1 to R-PX4, R-PX6, R-PX7, R-HF6, R-HF9, R-ST8, R-PD7, R-PD16, R-PD17, R-EV6, R-EV7, R-EV17, R-CC9, R-DL8 to R-DL10 | R-PH3 (the proxy) | 023 |
| Compiler commands | R-CM15, R-CS1 to R-CS3, R-U1 to R-U6, R-RU1 to R-RU4, R-RR1 to R-RR3, R-LK1 to R-LK4, R-R12, R-R13, R-WS13 | R-PH3 (`roc ...`), R-PH8 (`roc use`) | 024, 026 |
| Download consent | R-DL1 to R-DL7, R-NI4, R-NI5, R-SO12, R-SO13, R-SO22, R-BL3, R-P5 (`max-toolchains`) | R-PH7 ("the consent rules R-DL1 to R-DL6") | 025 |
| Setup | R-CM18, R-ST1 to R-ST15, R-NI13, R-NI14, R-HF7, R-HF11, R-LY8, R-LY9 | R-PH3 (`setup`) | 027 |
| GC and cache | R-CM17, R-GC1 to R-GC14, R-CC10, R-CC2 (GC part), R-NI7, R-NR3 | R-PH3 (`cache ...`) | 028, 029 |
| `compat.db` | R-CC8, R-P4, R-PP4, R-CV6, R-EF1 (rank 1), R-NS12, R-PK7 (`compat.db` rows), R-TF1 to R-TF3 (`compat.db`) | R-PH9 ("Unit probes, `compat.db`, the build skip") | 030 |
| Unit probes, slots | R-LD2, R-LD3, R-UM1, R-AL4, R-PP1 to R-PP7, R-P2 to R-P5, R-P8, R-FL11 | R-PH9 | 031 |
| Build skip, evidence | R-BS1, R-BS2 (with `compat.db`), R-ID6, R-EF2, R-EF3 (ranks 1, 3, 4, 5), R-CM7 (evidence) | R-PH9, R-PH12 ("The evidence for each version") | 032 |
| Epochs | R-EP1, R-EP4 to R-EP14 (direct: R-EP4 gives one epoch per release, only case (b) of R-EP6 infers) | R-PH10 (the oracle loop needs inferred facts) | 033 |
| PubGrub oracle | R-PK6, R-GP6, R-AL3, R-AL5 to R-AL7, R-EP7 to R-EP9, R-LF2, R-OV2 (free variable), R-UP7 (budget, exit 12), R-SP24 (as a decision order), R-PH13 | R-PH10 ("The PubGrub oracle loop") | 034, 035, 036 |
| `tln probe` | R-CM8, R-PB1 to R-PB4, R-PB7, R-LB3 | R-PH3 | 037 |
| `tln upgrade` | R-CM5, R-SP6 to R-SP9, R-SP12, R-SP13, R-UP1 to R-UP13, R-RP1 (upgrade part), R-RP4, R-NI12 | R-PH3, R-PH8 (`upgrade roc`) | 038, 039 |
| `tln outdated` | R-CM6 | R-PH3 | 040 |
| `tln init` | R-CM1, R-IN1 to R-IN7, R-PD15, R-SO16 (init part) | R-PH3 | 041 |
| Patches | R-CM10, R-PA1 to R-PA14, R-PX5, R-CM9 (`patched` mark) | R-PH3 (`patch`) | 042, 043 |
| Source builds, Zig | R-R1 to R-R11, R-D1 to R-D4, R-EV11, R-EV16, R-EV21, R-SE12 | R-PH3 (`roc ...`) | 044, 045 |
| Global tools, `tln x` | R-CM12, R-CM16, R-T1 to R-T21, R-T23 to R-T28, R-X1 to R-X5, R-B1 to R-B10, R-NI8, R-NI9, R-SE8, R-LY2, R-LY3 (`tools.json`), R-CC6 (`tools.json`), R-GC7 | R-PH3 (`x`, `tool ...`) | 046 to 049 |
| Talon as a tool | R-S1 to R-S5, R-T22 (Talon only), R-RM1 to R-RM10, R-NI10, R-IS1 to R-IS8, R-HF10, R-SE13, R-EV10, R-NI15 | Design 7 P1 ("`install.sh`, `install.ps1` and prebuilt Talon binaries") | 050, 051, 052 |
| Exit criteria | Design 7 P1 exit row, TW16 design examples that need P1 (the failure output of Resolution 5) | Design 7 | 053 |

The P1 parts of mixed groups: R-CM (the R-PH3 commands), R-FL (the answer flags of R-FL12 for the P1 prompts, `--slots`, `--git`, `--path`, `--range`, `--all`, `--diff`), R-EV (R-EV5 to R-EV7, R-EV11, R-EV16, R-EV17, R-EV21), R-NI (R-NI4 to R-NI15), R-HF (R-HF2, R-HF6, R-HF9 to R-HF11). Each slice names the exact ids.

### 1.2 What stays for P2 and later

| Phase | Ids | Reason |
| --- | --- | --- |
| P2 | Registry: R-RL, R-SG, R-AP, R-RE, R-IK, R-MX, R-CT, R-PU, R-TP, R-SN, R-WH, R-OT, R-PL2, R-GA2. Sharing and smoke builds: R-SH, R-SM, R-NI16, R-CM23, R-EV26. `publish`, `probe --share`: R-CM13, R-PB5, R-PB6. Registry parts of P0 and P1 groups: R-AD3 to R-AD5, R-AD34 to R-AD36, R-RG4 to R-RG6, R-E6, R-J7, R-ID7, R-DT3 (`log:` snapshot), R-EP2, R-EP3 case (a), R-EF1 ranks 2 and 6, the registry branches of R-CV1 and R-CV3, R-SE2, R-SE5, R-SE6, R-SE10, R-SE14 to R-SE16. | R-PH4, R-PH11. Needs the `cloudflare-workers` platform. |
| P3 | R-AU, R-YK, R-MV, R-CM14, R-CM21, R-CM22, R-C6 (yank and advisory data), R-B3 (yank part), R-T22 (prebuilt binaries of other tools) | R-PH5, Design 7 P3 |
| P4 | Upstream: compat id in `roc version --verbose` (R-GC10), a roc lock on `packages/` (R-CC10) | Design 7 P4 |
| Not testable here | R-CF1, R-FE9 (L5), R-GA1, R-GA3 to R-GA7, R-HF8, R-PK1 to R-PK5, R-PL1, R-PH1, R-PH2, R-OUT3, R-NI11 (removed) | As in the slice 012 audit |

## 2. Slices

Order: the first slices give value early. After 023 a user can run `tln roc install <id>` and `roc` through the proxy. After 029 the toolchain manager is complete. Then `compat.db`, unit probes and PubGrub, which the exit criteria need. The tools come last, because no other P1 slice needs them.

```mermaid
flowchart LR
    S018["018 test speed"] --> S020["020 compiler list"] --> S021["021 roc install"] --> S022["022 selection"] --> S023["023 proxy"]
    S023 --> S024["024 roc ls, default, rm, link"] --> S026["026 roc use, update"]
    S022 --> S025["025 consent"] --> S026
    S023 --> S027["027 setup"]
    S024 --> S028["028 cache gc"] --> S029["029 cache clean"]
    S025 --> S030["030 compat.db"] --> S031["031 unit probes"] --> S032["032 build skip"]
    S030 --> S033["033 epochs"] --> S034["034 PubGrub core"] --> S035["035 conflicts"] --> S036["036 oracle loop"]
    S031 --> S036
    S036 --> S037["037 probe"]
    S036 --> S038["038 upgrade"] --> S039["039 upgrade roc"] --> S041["041 init"]
    S036 --> S040["040 outdated"]
    S023 --> S042["042 patch"] --> S043["043 patches in resolve"]
    S036 --> S043
    S021 --> S044["044 zig"] --> S045["045 roc install --git"]
    S032 --> S046["046 tool install"] --> S047["047 tool compiler choice"] --> S048["048 tool ls, update, rm"] --> S049["049 x"]
    S045 --> S048
    S027 --> S050["050 tool update talon"] --> S051["051 tool rm talon"] --> S052["052 release, scripts"]
    S039 --> S053["053 P1 exit"]
    S028 --> S053
```

| # | Slice | Content | Rule groups | Depends on | New code (lines, estimate) |
| --- | --- | --- | --- | --- | --- |
| 018 (done) | Test speed | Test binaries with `--opt=dev`, L0 files in parallel, a `slow` tag and a step budget (section 3.4). No Talon code. | TW20 | none | 60 (shell) |
| 018b (done) | CI jobs | GitHub Actions: Linux, macOS and Windows jobs that run the fast set, and a nightly job with `OPT=speed`, `slow` and `net` (the user's answer 2). The release workflow stays in 052. | TW20 | 018 | 100 (YAML and shell) |
| 019 (done) | P0 leftovers | The P0 items with no owner (section 4): 2-member workspace runs of `verify` (F5, F12 of slice 009). | R-SE7, R-CM11 | 018 | 30 |
| 020 (done) | Compiler list | List the releases of `roc-lang/nightlies` (R-DI2 list call), nightly tag forms and order, the asset for a host, the sha256 from `digest`, prefix expansion and `@latest`, `@+N`, `@-N` in the `tln roc` scope. Pure, plus one fetch. The fake nightly release tools (section 3.2). | R-CV1 to R-CV3, R-CV7, R-CV8, R-NS1, R-SC10, R-SC11, R-SC13, R-C7 (compilers) | 018 | 350 |
| 021 (done) | `tln roc install <id>` | Download with the adapter, sha256 check before extract (exit 16), `tar` extract into a temp, `chmod`, `.talon.json` written last, the install lock, compat id (R-GC10), the first install is the default. `roc i` alias. Also (slice 020 review): the TW26 budget warnings apply to the fast set (`OPT=dev`) only. | R-R8, R-CV4, R-CV5, R-HF2, R-HF4, R-HF5, R-SE9 (`tar`), R-SE11, R-CC4, R-GC10, R-SO15, R-NI6, R-CM19 | 020 | 400 |
| 022 (done) | Selection ranks | `Compiler.select` with ranks 1 to 7 over installed compilers, `.roc-version` (rank 5), the global default (rank 6), `path-roc.json` and the launcher test, the held nightly of ranks 4 to 6, the R-SO18 warning in `install` and `ls`. Also slice 020 G1: `Pin.admits` and `Exactly` order 2 nightlies of one date by `published_at` (R-NS1). And slice 020 Q5: the empty-domain failure names the switch and its source (R-NS2). And slice 021 T17: an L0 row where the KB value of `Toolchain.size_text` rounds (`1550` gives `1.6 KB`). And the harness: the `check` step runs its `roc check` calls in parallel, as l0 does (it is at 8.2 s of its 10 s budget). | R-SO1 to R-SO15, R-SO18, R-SO19, R-NS2 to R-NS4, R-NS6, R-EV5, R-PH6 (P1 column) | 021 | 350 |
| 022b (done) | Launcher test | R-SO9: the launcher test, `path-roc.json`, a new `Fx` call for the `roc` files on `PATH`, the real and the fake `Fx`, an L3 job (split from 022). | R-SO9 | 022 | 140 |
| 023 (done) | The `roc` proxy | Split in the 023 review (2026-10-23). Dispatch by program name, `+<id>`, the target file, selection in the proxy, `.last-use`, the R-PD10 record, cache variables, `TALON_PROXY=0`, `TALON_IN_PROXY`, refusal of a missing compiler, `Fx.program_name!` and `Fx.exec!`. Also G1: `ROC_TOOLCHAIN` accepts git-, link- and copy- ids. | R-PX1 to R-PX3, R-PX6, R-PX7, R-HF6, R-HF9, R-ST8, R-PD7, R-PD10, R-PD16, R-PD17, R-EV7, R-EV17, R-CC9, R-SO1, R-SO2, R-SO8, R-SO9 (proxy), R-E1, R-TF5 (proxy), R-DL8, R-DL10, R-NI5 (exit 13) | 022b | 380 |
| 023b (done) | Install in the proxy | R-PX4, the prompt, `TALON_AUTO_INSTALL`, the install lock, `RocInstall` as a function. L3: 3 proxies, 1 download (R-CC4). | R-PX4, R-DL1 (proxy), R-DL8 (prompt), R-DL9, R-EV6, R-NI5, R-CC4 (proxy) | 023 | 200 |
| 023c (done) | Probes by path | Probes run the selected compiler by its path: `Probe.Spec` gets `program` and `env`, `Compiler.require` accepts an installed compiler, `.last-use` and cache variables for probes. | R-PX6 (probes), R-CC9 (probes), R-SO22, R-PH7 | 023 | 150 |
| 024 (done) | `tln roc ls`, `default`, `rm` | Split in the 024 review (2026-10-23). List, set the global default (full id), remove (the default moves, pinned projects listed, the item lock wait). | R-CS2, R-RR1 to R-RR3, R-RM2, R-CM15, R-CM19, R-GC3 (`roc rm`) | 023 | 350 |
| 024b (done) | `tln roc link` | `link` and `link --copy`: a new `Fx` call to copy a file, the proxy runs the link target, the `--copy` flag (and the R-FL12 gap G4 of slice 024). | R-R4, R-R5 (link and copy ids; `default --git` is in 045), R-R12, R-R13, R-LK1 to R-LK4 | 024 | 200 |
| 025 (done) | Download consent in resolve commands | Split in the 025 review (2026-10-23); this row is 025a. The P0 refusal (R-PH7) becomes the consent rules: one prompt per command, required and optional downloads, `--probe-downloads`, `--allow-downloads`, `TALON_AUTO_INSTALL`, the cap. The baseline compiler download. The FD gap of slice 013. Also (023b Q5): the R-SO13 text "does not download a compiler for a run" is wrong after 023b; fix it. | R-DL1 to R-DL7, R-NI4, R-NI5, R-SO12, R-SO13, R-SO22, R-BL3, R-P5 (cap), R-PH7 (P1 column), R-FL12 | 022 | 350 |
| 025b (done) | Rank 4 download and optional downloads | R-SO13: a `[toolchain] roc` range with no installed compiler downloads the newest allowed release in the range (the `nightly` switch), in the commands and the proxy, and the `NoneInRange` text fix (023b Q5). `--no-check` with a rank 4 range (025 Q3). The optional download moved to 036 (025b review). | R-SO13, R-DL1 to R-DL5, R-DL8, R-DL10 | 025 | 250 |
| 026 (done) | `tln roc update`, the `@+N` base | Split in the 026 review (2026-10-23); this row is 026a. `update`: newest allowed release, move the default (also when the newest is installed already). The base of `@+N`/`@-N` for `tln roc` commands (Base, OnPath). The second form of `Pin.toolchain_note` (024b G2). | R-CS3, R-RU1 to R-RU4, R-SL7, R-PD16 | 024, 025 | 300 |
| 026b (done) | `tln roc use` | Check with the baseline and the ladder, then the pin edit (also each member). Open from 026a: Q4 (the prompt for the baseline plus the new nightly), Q5 (a check for the workspace or for each member). | R-CS1, R-U1 to R-U6, R-WS13, R-RP1 (`roc use`), R-PH8 (`roc use`) | 026 | 300 |
| 027 (done) | `tln setup` | Bin dir entries (hard link, else copy), the launcher, `roc.old` and `link-system`, the `PATH` line, `GITHUB_PATH`, completions, R-ST11 ownership test. The Windows `Path` edit as a pure command line (L0). | R-CM18, R-ST1 to R-ST15, R-NI13, R-NI14, R-HF7, R-HF11, R-LY8, R-LY9 | 023 | 400 |
| 028 (done) | `tln cache gc` | Split in the 028 review (2026-10-23); this row is 028a. Toolchains (R-GC5 read as: the default, or pinned by a known project, or used in the GC age), the GC lock, toolchain locks, last-use, `.trash`, stale temps and `talon/tmp/<token>.locks`, `projects.json` pruning, `gc-age`, `--dry-run`. | R-GC1 to R-GC11, R-CC10, R-CC2 (GC), R-EV22 (GC ages) | 024 | 400 |
| 028b (done) | `tln cache gc`: build caches and sizes | Build-cache dirs, `packages/`, the sizes in the report and the dry run, a new `Fx.tree_info!` call, the age rule of R-GC1. R-GC7 (the `x` entries) is in 049. | R-GC1 (age), R-GC2, R-GC3 (second sentence), R-GC4 | 028 | 250 |
| 029 (done) | `tln cache clean` | `clean`, `clean --all`, the prompt, `--dry-run`, the sizes, the `talon/gc` lock (Wait). `list` and `dir` moved to 029b (029 review). | R-GC12 to R-GC14, R-NI7, R-NR3 | 028 | 200 |
| 029b (done) | `tln cache list`, `tln cache dir` | R-CM17 names them and no rule says what they print. Proposal of the 029 test agent: `dir` prints the cache root; `list` prints what `clean --all` would remove, with sizes. | R-CM17 | 029 | 80 |
| 030 (done) | `compat.db` | Split in the 030 review (2026-10-23); this row is 030a: the store. New `Fx` call for SQLite (basic-cli `Sqlite`), the schema with `PRAGMA user_version`, WAL and busy timeout, facts per (hash, nightly, target), the R-CV6 first-seen sha256, `expect/facts.tsv` in the L3 runner. First a spike in `research/compat-db/`: basic-cli `Sqlite` on the pinned nightly, and two processes in WAL. | R-CC8, R-P4, R-PP4, R-CV6, R-EF1 (rank 1), R-NS12, R-PK7 (rows), R-TF1 to R-TF3 | 025 | 350 |
| 030b (done) | R-CV6 wiring | Record every (tag, target) sha256 that a compiler list gives (both sources). A later different value: the tag is no candidate; a command that names the tag (`roc install`, `roc default`, `roc use`, a pin) stops with exit 16. An installed compiler stays in use. A busy or failing compat.db: the R-CC8 warning, no record, go on. | R-CV6, R-CV3, R-CC8 | 030 | 150 |
| 031 (done) | Unit probes and slots | Ladder step 1 (unit and platform probes), the used-module scan, the slot pool (checks 1, builds 4), `--slots`, budget, hang and crash as facts, the temp dirs of probes. L3: 13 fake probes, at most 12 at once. Also (025b review): the `[probe]` keys, with `probe.max-toolchains` (R-P5). | R-LD2, R-LD3, R-UM1, R-AL4, R-PP1 to R-PP7, R-P2 to R-P5, R-P8, R-FL11, R-CC9 (probes) | 030 | 400 |
| 031b (done) | Module split | Five modules near the limit of 600 lines are split by topic, so slice 032 and later add code to short files. No behavior change: no test, fixture or expected file changes. See `031b-module-split.md`. | none | 031 | 0 |
| 032 (done) | Build skip | Split in the 032 review (2026-10-23). The build skip with the used-closure digest; one fact row per (key, digest); pass, fail, hang and crash are recorded, and a fail blocks the skip. | R-BS1, R-BS2, R-ID6, R-EF2, R-PH9 | 031 | 300 |
| 032b (done) | Evidence lines | The evidence lines of `why` and of the summary. Open questions E1 to E6 of the 032 slice file (section 12): the compiler `why` uses, whether `why` reads compat.db, which evidence ranks P1 shows, the unit-fail note text, where it prints, the line format. | R-EF1, R-EF3, R-CM7 (evidence), R-PH12 (P1 columns) | 032 | 200 |
| 033 (done) | Epochs | `epochs : List(Release), Facts -> { epochs, inferred }` (pure). First L1 target and the `l1` step of `scripts/test.sh`. | R-EP1, R-EP4 to R-EP14 | 030 | 250 |
| 034 (done) | PubGrub core | New package `packages/resolve`: terms, incompatibilities, unit propagation, decisions by `priority` and `strategy`, the solver step `Need`, `Done`, `Fail` (`TESTING.md` 2.2 B). L0, and L1 against brute force on small graphs. | R-PK6, R-GP6, R-C1 to R-C4, R-C6, R-C7, R-C9, R-VA6 | 033 | 400 |
| 035 (done) | PubGrub conflicts | Conflict resolution, learned incompatibilities from probe facts (`not (h and roc in [a, b])`), the explanation of a failure (Resolution 5 example), the `inferred` marks. | R-EP7 to R-EP9, R-AL5 | 034 | 400 |
| 036 (done) | The oracle loop (part a, split in review) | The commands that resolve call the solver step in a loop with probe rounds, in place of the one-tuple pick of P0. The held-move second search as a decision order (slice 017 item). The budget covers both searches. `--no-probe`. Exit 12. Also (025b review): the first optional download: the optional list, the cap (R-DL6), the `skipped N compiler downloads` line, and the one prompt for required and optional downloads (R-NI4, R-DL1). Open point: how a person accepts the required download and refuses the optional ones in one prompt. | R-AL3, R-AL6, R-AL7, R-SP24, R-LF2, R-UP7, R-OV2, R-PH10, R-PH13 | 031, 035 | 400 |
| 036b (done) | Probe rounds | Split in the 036 review (2026-10-24). The facts and the used-module scan in the loop, probe rounds, `--no-probe`, the budget (R-P5) for both searches, exit 12 (R-UP7, 035 Q2), the ladder facts, a ladder failure fed back as a conflict. Questions Q1 to Q3 of `036-oracle-loop.md`. Split the scan from the rounds if over 450 lines. | R-AL6, R-AL7, R-LF2, R-OV2, R-UP7, R-EP8, R-EP9 (wiring) | 036 | 400 |
| 036b2 (done) | Used-module scan in the loop | Split in the 036b review (2026-10-24). The used-module scan (R-UM1) after `Done`: chosen releases with a known unit fail and no used-module result get a scan, then the step runs again (036 Q3). Also one run that sets `probe.max` for a held-move second search (036b gap). Also from the 036b close: B10 (a case with two free groups and a failing imported module, so the named blame differs from the whole-tuple blame) and Q7 (the pre-ladder lines print again after a dropped tuple: propose the rule, TW24). | R-UM1 (loop), R-AL4, R-P5 (held moves) | 036b | 100 |
| 036b3 (done) | Module split and l0 time | Added by the manager (2026-10-24) before 036c. No behavior change: no test, fixture or expected file changes (as 031b). `cli/lib/InstallFlow.roc` (576 lines) and other modules near 600 lines are split by topic. The l0 step (8.8 s of 10 s) is made faster, or its unit files are rebalanced, so 036c has room. | none | 036b2 | 0 |
| 036c (done) | Epochs and fix lines (optional downloads moved to 037 in review) | Split in the 036 review. The Epochs wiring and the domain D, the first optional download (R-DL6 cap, the `skipped N compiler downloads` line, one prompt: R-NI4, R-DL1), the explanation text and `fix:` lines (035 Q1, TW24), the R-RP2 hint. Questions Q4 and Q5 of `036-oracle-loop.md`. Revisit 036b D2 (the value a header has now is an assumed pass): it holds only while D is the held compiler; with more compilers in D, a current value on another compiler needs a probe. | R-DL1, R-DL6, R-NI4, R-RP2, R-EP10 (wiring) | 036b | 350 |
| 037 (done) | `tln probe` | Target forms, the ladder on the selected compiler, `--range` with rounds of 3, the cap, exit 12 with `unknown` ends. Also (036c review): the first optional download: D with the cap R-DL6, the opt-in of U5, the `skipped N compiler downloads` line (R-DL4), `max-toolchains = 0`, one prompt (R-NI4, R-DL1). See the proposal in `036c-epochs-downloads.md`. | R-CM8, R-PB1 to R-PB4, R-PB7, R-LB3, R-DL1, R-DL4, R-DL6, R-NI4 | 036 | 300 |
| 037c (done) | Optional probe downloads | Split in the 037 review (2026-10-24). The download branch of R-NI4 (`--probe-downloads`, `--yes` inside the cap R-DL6), D with the cap, the `skipped N compiler downloads` line (R-DL4), `max-toolchains = 0`, one prompt with a required download (U5). Used by `probe --range` and the resolve commands. | R-DL1, R-DL4, R-DL6, R-NI4 (download branch) | 037 | 250 |
| 037d (closed, no slice) | Optional downloads in resolve | Split in the 037c review (2026-10-24). The producer of optional downloads for the resolve commands: a probe of other compilers of D for the R-RP2 hint ("the oldest nightly that works"), with the opt-in and cap of 037c, and the one prompt when the same command also has a required download (U5). | R-RP2 (downloads), R-DL1, R-NI4 | 037c | 300 |
| 038 | `tln upgrade` (packages) | Free variables, the domain with no range, new series as a replace, the range rewrite, `lowest` is an error, the report of what did not get its newest release. | R-CM5, R-SP6, R-SP7, R-UP1 to R-UP5, R-UP8, R-UP10 to R-UP13 | 036 | 380 |
| 039 | `tln upgrade roc` | The free nightly, the newest nightly as a named download, the extra baseline download, `--no-check` error, held moves with the nightly. Also (037d close): the one prompt for a required and optional downloads (U5, R-NI12 with R-NI4, R-UP6), reusing `Consent.optional_*` and `ProbeSearch` of 037c. | R-SP8, R-SP9, R-SP12, R-SP13, R-RP1, R-RP4, R-UP6, R-UP9, R-NI12, R-BL3, R-PH8, R-DL1, R-NI4 (one prompt) | 038 | 300 |
| 040 | `tln outdated` | The table: current, wanted, latest, nightly range (from known facts) | R-CM6 | 036 | 250 |
| 041 | `tln init` | The templates, resolve as `upgrade`, the `roc:` pin, the CI file, never overwrite | R-CM1, R-IN1 to R-IN7, R-PD15, R-SO16, R-NI12 | 039 | 300 |
| 042 | `tln patch` | The copy, the `[patch]` entry, `--diff`, the unified diff and its apply (pure, L1 round trip), the refusals (platform, unmanaged entry), the `patched` mark of `list` | R-CM10, R-PA1 to R-PA3, R-PA7 to R-PA9, R-PA11 to R-PA14, R-CM9 (`patched`) | 023 | 400 |
| 043 | Patches in resolve and the proxy | A patched entry is an anchor, a move applies the diff, a stale patch (exit 14), `--replace-dep` in the proxy and probes | R-PA4 to R-PA6, R-PA10, R-PX5 | 036, 042 | 300 |
| 044 | Zig | The Zig search order, the install from the Zig index with sha256, the dependency list and its prompt | R-D1 to R-D4, R-EV11, R-EV16, R-EV21, R-NI6 (Zig) | 021 | 300 |
| 045 | `tln roc install --git` | Source archive of a ref, `zig build`, `git-<sha8>`, the nightly note, a branch again gives a new id Also (slice 020 review): a row for a non-nightly id that prefixes another id (the `named.contains` branch of `Nightlies.by_name`). Also (024b review): R-R5 `tln roc default --git`. | R-R1 to R-R3, R-R5 to R-R7, R-R9 to R-R11, R-SE12, R-DA3 | 044 | 380 |
| 046 | `tln tool install` (release) | Release online, app bundle, build with the pinned compiler, bin dir, `tools.json` under its lock, binary name clash, `--as` Also (028b review): GC protects the packages that installed tools use (tool roots in `Gc.protected`), once the `tools.json` form is fixed. | R-CM16, R-T1 to R-T6, R-T8 to R-T12, R-T26 to R-T28, R-SE8, R-ST15, R-LY2, R-LY3, R-CC6 (`tools.json`) | 032, 027 | 400 |
| 047 | Compiler choice of a tool | Evidence pass, the R-NI8 prompt, option 2 in parallel, the record of each try | R-T13 to R-T21, R-NI8, R-PP2 (option 2) | 046 | 350 |
| 048 | `tln tool ls`, `update`, `rebuild`, `rm`, `--git` | The manifest-based commands and the git source | R-T7, R-T23 to R-T25, R-B6 | 047, 045 | 350 |
| 049 | `tln x` and build reuse | The `x` cache, the match by manifest, the take-over, offline rules, `--json` refused Also (028 review): R-GC7. | R-CM12, R-X1 to R-X5, R-B1 to R-B10, R-NI9, R-GC7, R-FL1 (`x`) | 048 | 400 |
| 050 | `tln tool update talon` | The prebuilt binary, `--from-source`, temp, `chmod`, `--version` check, `rename`, the bin dir entries again, the Windows `.del` rule (pure) | R-S2, R-S3, R-T22 (Talon), R-ST9, R-ST10, R-SE13 | 027, 046 | 300 |
| 051 | `tln tool rm talon` | The prompt with 4 options, the groups, `--dry-run`, the order of removal, the profile line | R-S5, R-RM1, R-RM3 to R-RM10, R-NI10 | 050 | 350 |
| 052 | Release and install scripts | The release workflow for the 5 targets and `sha256sums.txt` (Q2), the ids in `install/test.sh` | R-S1, R-S4, R-IS1 to R-IS8, R-HF10, R-NI15, R-EV10 | 051 | 150 |
| 053 | P1 exit | L4: parser 2.0.0 + basic-cli resolves with no help (Q1), GC frees the legacy dirs on a copy of a real cache, the failure output of Resolution 5 as a case | Design 7 P1 exit, TW16 | 039, 028 | 50 |

Sum: about 10,300 lines over 36 slices. The P0 slices had about 700 lines each (12,077 lines in `cli/lib/` for 17 slices). So the manager splits a slice at the scope step when the test agent finds more than about 400 lines (TW19), as in P0.

## 3. Test strategy

### 3.1 Layers per part

| Part | L0 | L1 (roc-fuzz) | L2 (fake `Fx`) | L3 (real processes, fake HTTP) | L4 (real `roc`) |
| --- | --- | --- | --- | --- | --- |
| Compiler list, asset, prefixes (020) | Yes: tag forms, order, asset pick, digest | | | One list on the fake API | |
| Install (021, 044, 045) | `.talon.json`, Zig search order | | The flow, the lock calls | Download, bad digest (exit 16), slow body, `curl` and `wget`, no `curl` (exit 18), `tar`, `chmod`, Ctrl-C and SIGKILL leave no item | |
| Selection, proxy (022, 023) | All ranks, `path-roc.json` key | | | Exit code passes through, `TALON_IN_PROXY`, 3 proxies and 1 download | The proxy runs the pinned `roc` from `toolchains/` |
| Consent (025) | The answer of each prompt in each mode | | Each command with each answer | One TTY case | |
| Setup, tools, Talon as a tool (027, 046 to 052) | Bin dir plans, reuse match, removal plan | | Flows | Hard link, copy fallback (tag `exdev`), `tools.json` race | One `tool install` of a small app (build) |
| GC (028, 029) | The selection | | The flow | GC during a fake build (R-CC10), old `beat` | GC on a copy of a real cache with legacy dirs (053) |
| `compat.db` (030) | Row encode and decode | | Fake `db` call: rows in `fx/db.tsv`, writes in the tree | WAL with 2 processes, busy timeout | |
| Probes, slots (031, 032) | Classes, used modules, digest | | Round order | 13 probes at most 12, hang kill with `probe.timeout = 1` | Unit probe and build of a real package |
| Epochs, PubGrub (033 to 036) | Yes, most tests | Epochs (properties of R-EP5, R-EP6), PubGrub against brute force, `upgrade` with fake `Fx` (`TESTING.md` 4) | The loop with fake probe results | | |
| Patches (042, 043) | Diff and apply | `apply(diff(a, b), a) == b` | Flows | Proxy with a stale patch (exit 14) | |

### 3.2 Fakes to make

| Fake | Where | Slice | How |
| --- | --- | --- | --- |
| Fake compiler release server | `tests/tools/mk-nightly.sh`, routes in `given/http/` | 020, 021 | The script makes a `.tar.gz` of a fake `roc` with fixed bytes (`tar --sort=name --mtime=@0 --owner=0`, `gzip -n`), and writes the release list JSON of `roc-lang/nightlies` with `digest` and loopback asset URLs. `fakehttp.py` serves it, also a slow body and a 404. |
| Fake toolchains dir | `tests/tools/mk-toolchain.sh` | 021, 022 | Writes `toolchains/<id>/roc` (a copy of `tests/fakes/roc`) and `.talon.json` into `given/home/` |
| Fake `roc` with an id | `tests/fakes/roc` | 021 | Gives `Roc compiler version <id>` from its dir name, and writes the id before the argv in `roc.log`. So a case sees which compiler ran. |
| Fake Zig index, fake `zig` | `given/http/`, `tests/fakes/zig` | 044, 045 | `TALON_ZIG_INDEX`. The fake `zig build` writes a fake `roc` to `zig-out/bin/`. |
| Fake source archive route | `given/http/` | 045 | `<api>/repos/<o>/<r>/tarball/<sha>` with a redirect to a loopback URL |
| Fake app bundle and release | `tests/fixtures/` | 046 | A small app bundle, made once with the real `roc bundle` and kept as a fixture |
| Fake `db` in L2 | `tests/commands/FakeFx.roc` | 030 | Rows from `fx/db.tsv`. Writes go to a file in the case dir, so `tree.diff` shows them. |
| Fake exec in L2 | `tests/commands/FakeFx.roc` | 023 | The exit code from a table. The call goes to `calls.log`. |
| Fake Talon release | `install/test.sh` (exists) | 050, 052 | As today |

### 3.3 Measured time today (2026-10-22, this machine)

| Step | Time | Where the time goes |
| --- | --- | --- |
| `scripts/test.sh` all | about 114 s | |
| l2 | 80 s | The `roc build` of `tests/commands/main.roc`: 98 s with the default `--opt=speed` (LLVM). It starts at the start of the run, so the step waits about 80 s. The 35 cases take 0.5 s. |
| l3 | 9 s | The cases. The `tln` build (87 s, `--opt=speed`) runs at the same time as l2. |
| l0 | 14 s | 50 `roc test` runs, one after the other |
| `roc build tests/commands/main.roc --opt=dev` | 5.1 s | Dev backend. All 35 L2 cases pass with this binary (0.5 s). |
| `roc build cli/main.roc --opt=dev` | 1.9 s | All 26 L3 cases pass with this binary (9 s, 1 skipped as today). |

So the time is in LLVM code generation, not in the tests. Each P1 slice adds code to both apps, so with `--opt=speed` the fast set goes past 180 s in a few slices.

### 3.4 Proposal: slice 018 (test speed)

| # | Change | Effect |
| --- | --- | --- |
| 1 | `scripts/test.sh`, `tests/run.sh`, `tests/commands/run.sh` build the test binaries (`l2`, `tln`, `fxprobe`, `flowprobe`) with `--opt=dev`. A variable `OPT=speed` gives the LLVM build. | Builds go from about 98 s to about 5 s. Fast set about 25 s. |
| 2 | A full run with `OPT=speed scripts/test.sh` before each merge and each night (with L4). | The dev backend and LLVM can differ. This run finds such a difference. A difference is a roc bug to report, and the case keeps the LLVM result. |
| 3 | The l0 step runs the `roc test` files in parallel (`xargs -P`, as l2 and l3 do) | 14 s to about 3 s |
| 4 | L3 cases with a real wait (a timeout, a slow body) set small limits (`probe.timeout = 1` in `config.toml`). A case that still takes more than 2 s gets the tag `slow`. The fast set skips `slow`. The merge run includes it. | L3 stays under 60 s |
| 5 | `scripts/test.sh` prints a warning when a step passes its share: l0 10 s, l1 60 s, l2 30 s, l3 60 s (`TESTING.md` 1) | The manager sees growth at once, not after 10 slices |

Budget for the end of P1, with the change: build 10 s, l0 10 s, l1 40 s (4 targets with a fixed `--runs`), l2 5 s (about 120 cases), l3 40 s (about 100 cases), all in parallel where possible: under 90 s.

## 4. Open P0 items and where they go

| Item | Source | Goes to |
| --- | --- | --- |
| R-SO5 (`.roc-version` rank 5), R-SO18 (the warning in `install` and `ls`) | Slice 012 Q30, manager answer: P1 | 022 |
| R-SO1, R-SO6, R-SO8, R-SO12, R-SO15, R-RP4, R-SP6, R-SP8, R-SP9, R-SP12, R-SP13, R-UP1 to R-UP13, R-WS13, R-SC10, R-SC11, R-SC13, R-PD7, R-PD15 to R-PD17, R-NS6, R-NS12, R-ID6, R-NR3, R-LB3, R-P4, R-P5, R-P8, R-PP1, R-PP2, R-PP4, R-PP6, R-PP7, R-AL4, R-AL5, R-LD2, R-LD3, R-CC8 to R-CC10, R-EV6, R-EV7, R-EV11, R-EV16, R-EV17, R-EV21, R-HF2, R-HF6, R-HF9 to R-HF11 | Ids of P0 groups with no test, marked P1 in the audits of slices 011 and 012 | The slice of section 2 that names the id |
| FD: `InstallFlow.finish!` calls `Pin.decide` with `toolchain: Err(Unset)`. Equal in P0, not with downloads. | Slice 013 code review | 025 (a run where the held nightly is a download) |
| `talon/tmp/<token>.locks` of a crashed process: GC must remove it | Slice 002 code review | 028 |
| The second search as a PubGrub decision order, R-AL5 (a failed probe changes the set), R-P5 (the budget covers both searches) | Slice 017 out of scope | 036 |
| R-PA4, R-PA14 (a patched entry never moves) | Slice 017 out of scope | 042, 043 |
| R-SC1 for `patch`, `probe`, `upgrade`. The selector filter for the scopes `Tool` and `X` (D5) | Slice 014 | 037, 038, 042, 046, 049 |
| R-PH12, R-CM7: the evidence for each version in `why` | Slice 011 out of scope | 032 |
| F5 (R-SE7: a repeated platform note in 2 members), F12 (R-CM11: `replace` made unique in 2 members) | Slice 009 code review, "accepted as gaps for P0". No later slice names them. | 019 |
| The stale take-over race of 3 processes | Slice 002 review: the limit that R-CC12 accepts | No slice (accepted) |

The other "moved to slice N" items of the reviews of slices 006 to 016 were taken by the named slice (checked in the slice files and in `tests/unit/`: the gaps of slices 003 and 005 have rows today).

## 5. Questions for the human (TW17)

| # | Question | Why it changes the plan | Proposal (not a decision) |
| --- | --- | --- | --- |
| Q1 | The P1 exit criterion "Talon finds a working tuple for parser 2.0.0 + basic-cli without help" needs the real GitHub index and real nightly downloads. All test layers run with no network (`TESTING.md` 3.2, TW15). How is the criterion checked? | Slice 053: a new tag `net` (a manual and nightly run, never in the fast set or the merge run), or a human run that the slice file records | A tag `net`, nightly only, with a pinned `--snapshot` time so the result is fixed |
| Q2 | No CI exists in the repository (no `.github/`). Is a CI with Linux, macOS and Windows jobs part of P1? | The Windows rules (R-HF11, R-ST10, R-RM5, R-S3, R-LY5 to R-LY9, `install.ps1`), the macOS case-insensitive names (`TESTING.md` 5), and the release workflow of the 5 prebuilt targets (R-IS2, slice 052) need it. Without it these get L0 tests only, and slice 052 has no release. | Yes: one small slice before 050 that adds the CI jobs and the release workflow |
| Q3 | Slice 018: do you accept `--opt=dev` test binaries in the fast set, with the `--opt=speed` run only before a merge and each night? | TW20 says the fast set runs before each hand-off. With `--opt=speed` only, the fast set passes 180 s early in P1, and slices must split for time, not for review size. | Yes (section 3.4) |

## Answers of the user (2026-10-22)

| Question | Answer | Effect on the plan |
| --- | --- | --- |
| 1, the network exit criterion | A nightly test with the tag `net`, with a fixed `--snapshot` time | Slice 053 |
| 2, CI | Add CI in P1: Linux, macOS and Windows jobs (the fast set, and the speed set each night), and the release workflow | New slice 018b after 018: the CI jobs. Slice 052 keeps the release workflow. |
| 3, `--opt=dev` | Yes: `--opt=dev` in the fast set, `OPT=speed` before a merge and each night. TESTING.md changes in slice 018. | Slice 018 |
| 2026-10-22 | Slice 022 split into 022 and 022b | TW19: about 450 lines |

## 5b. Follow-up items (manager)

| Item | Found in | What to do |
| --- | --- | --- |
| The `check` step is near its 10 s budget (10.3 s once, 2026-10-23). `roc check` runs on about 60 apps, most of them `tests/unit/*.roc`, which `l0` also compiles. `cli/main.roc` alone takes 2.5 s. | 023c close | Done (2026-10-23). `roc test` fails on the same errors and warnings as `roc check` (exit 1 and 2, `research/check-speed/RESULTS.md`), so `APPS` in `scripts/test.sh` has no unit file and `step_check` runs `cli/main.roc` first, then the other 4 apps in parallel (cold cache: 6.6 to 10 s before, 4.8 to 5.6 s after; warm: 0.3 s). Selftest row `s_unit_guard` (real roc: a warning and a type error in a unit file fail l0); `s_chk_par` updated. Budget not changed. |
| One `scripts/test.sh` run used 48 GB at peak, and several runs at the same time gave a global out-of-memory kill (2026-10-23). `roc check cli/main.roc` took 14 GB and 3.7 s with a warm cache. | Test-infrastructure task, 2026-10-23 | Done (2026-10-23). Cause: `roc check` and `roc build` read all files of the roc object cache (`objects-v7`, 11 GB after many edits of `cli/lib`) into memory. `prune_roc_objects` (`tests/lib.sh`) keeps the 3 newest files per dir. Memory rule: `TEST_MEM_GB`, `jobs_for`. Full run: 48 GB to 5 GB peak, 33 s to 24 s, `OPT=speed` 7 GB. Selftest row `s_mem`. Budgets not changed. `mod/` cache (14 GB disk) not pruned. Report the roc read-all behaviour. Numbers: `research/test-memory/RESULTS.md`. |
| Build facts are one row per (hash, nightly, target, closure digest), not per (hash, nightly, target) (032 review). `compat.db` stays at format 1, because no Talon with the old key was released. | 032 | When the design files are next edited: R-P4 and the `compat.db` schema text say the digest is part of the key of a build fact. |
| R-EF1 rank 4 (the `.roc-version` hint at the release tag) has no cache, so no command shows it in P1 (032b review Q1). The pure ranking has it. | 032b | A slice that caches `Github.hint!` results (proposed path `talon/index/github/<owner>/<repo>/<tag>.roc-version`) and passes them to `Evidence`. |
| The l1 step builds with `--opt=speed` only (roc: "`--fuzz` requires the LLVM backend"), and TESTING.md section 4 has no `epochs` row in its target table (033 G2). R-EP10 `epochs : List(Release), Facts` has no input for the registry matrix that R-EP2 to R-EP4 need (033 G1); `Epochs.infer` takes intervals for P2. | 033 | When the design files are next edited: add both notes to TESTING.md 4, and the matrix input to R-EP10. |
| Slice 034 design gaps: Resolution 5 has no data model for the solver step (G1). TESTING.md 2.2 gives `Need(List(Probe))`, but the step also asks for R-AL8 header facts (`Ask : [Header(Str)]`, G2). The TESTING.md 4 `pubgrub` row names the failure explanation, which is slice 035 (G4). R-AL3 lists R-C2 and R-C3 as step constraints, but both read the closure of R-AL9 (G5). R-C7 names only `min-release-age` for a named version, but P0 (slice 005 D7) and 034 also let it pass the snapshot. | 034 | When the design files are next edited: the solver data model in Resolution 5, the `Need` type in TESTING.md 2.2, the 035 note in TESTING.md 4, and the R-C7 sentence. |
| Slice 035 design gaps: no data model for the explanation (G1). `Need(List(Probe))` in TESTING.md 2.2 should be `Need(List(Ask))` (G2, same as 034 G2). R-EP7 does not say if a run of inferred-only fails gives an incompatibility (G3; 035 says yes, inferred). R-EP8 does not name the A/B form of the second pass (G4). R-EP9 does not say that a spent budget and `--no-probe` are one solver input (G5). The Resolution 5 example's "checks on" ranges are the complement of the fail runs, and `fix:` lines have no rule (G6). | 035 | When the design files are next edited: R-EP7 to R-EP9 text, the explanation data model, and a `fix:` rule (or slice 036 proposes the text, TW24). |
| With `OPT=speed`, the `l2` step takes 73 to 84 s (budget 30 s), because LLVM builds the L2 test app. The WARN shows only in dev mode, so nothing reports it (033 and 034 code agents). | 034 | Decide if `OPT=speed` needs its own l2 budget, or if the nightly run accepts it. TESTING.md 1 lists `OPT=speed` for the nightly run only. |
| `scripts/test.sh` has no time limit for a test. A solver bug that makes the search not end hangs the `l0` or `l1` step (035 gap m01, 034 and 035 mutations). | 035 | Done (2026-10-24). `scripts/test.sh` puts a time limit on each test process with `timeout -k 5` (`run_limited`): a `roc test` file (l0), a fuzz run (l1), a start of the L2 test app for one case (l2, through a wrapper app), and an L3 case (l3, `CASE_TIMEOUT` of `tests/run.sh`, which had 120 s before). One variable, `TEST_TIMEOUT=<s>`; default is 3 times the budget of the step (`limit_of`): l0 30, l1 180, l2 90, l3 180. A process over the limit fails its step with `l0: <file>: timed out after <s> s`, `l1: <file>: timed out after <s> s (seed, runs)` or `l2: case <name>: timed out after <s> s`; l3 shows exit code 124 of the case. The builds have no limit. Selftest rows `s_limit_l0`, `s_limit_l1`, `s_limit_l2`, `s_limit_l3` (a fake process hangs, the limit is 1 s, and a control run passes); each fails when its `timeout` is removed (one hand mutation each). The rows add no measurable time to the selftest (8.8 s, as before). `test.sh` takes GNU `timeout` first (`gnutimeout`, `gtimeout`): the `timeout` of uutils coreutils waits 0.1 s on each call, which made the selftest row `mem` (60 fake l0 files, one at a time) 5.6 s slower (14.2 s) in the first version. Not limited: the tty cases of l3 (`ptyrun.py` has its own 60 s idle limit) and the selftest step itself. Copies before the change: `research/test-timeout/before/`. |
| R-EP9: "When the budget is spent, the explanation can use inferred facts." P1 exits 12 at once with the `probe.max` error and no explanation (036b Q3, 036c Q2). | 036c | A later slice: after a spent budget, one `Off` step; on `Fail`, print its explanation with the `inferred` marks after the budget error, exit 12. |
| R-NI4 and the `--probe-downloads` flag table list `add`, `update`, `install` and `verify`, but those commands have no source of optional downloads (037d Q4). `--probe-downloads` is parsed for them (`cli/lib/Args.roc:256`, `cli/lib/Opts.roc:79`) and has no effect and no message. | 037d | When the design files are next edited: drop those commands from R-NI4 and the flag table, or give them a source. Until then, consider a note when the flag has no effect. |
| The selftest row `s_unit_guard` runs the real roc, which fetches `roc-semver` by URL (the `packages/resolve` header). One run failed with `DownloadFailed` (2026-10-24). TESTING.md needs the `TEST_TIMEOUT` line (default 3 times the step budget; builds have no limit) and the `CASE_TIMEOUT` default of 180 s through `test.sh`. | Time-limit task | Done (2026-10-24). Cause: each run of the row used a new `WORK` dir, so a new `ROC_CACHE_DIR` and a new package cache, and roc downloaded `roc-semver` 3 times. The row now links `$WORK/cache/roc/packages` of the row into the package cache of the run (the one that the l0 step fills), so a warm cache needs no network. With a cold cache and no network, roc prints `package download failed`: the row then prints `SELFTEST SKIP: unit guard: ... <reason>` and is not counted as passed or failed (the summary says `, N skipped`). Shown: 3 runs with the network (8.9 to 9.1 s, 63 passed), a warm cache with the network blocked (`bwrap --unshare-net`, 63 passed), a cold cache with the network blocked (62 passed, 1 skipped). Mutation: without the link the row skips with a warm cache and no network. TESTING.md still needs the 2 lines at the next edit (`TEST_TIMEOUT`, `CASE_TIMEOUT` default 180 s), and one line: a selftest row can say SKIP when a real-network need is missing. |

## 6. Open questions for the user

| # | From | Question | Options | Recommended |
| --- | --- | --- | --- | --- |
| U1 | 027 Q7 | R-ST9 says `tln setup` repairs a bin dir entry that a `rename` over the data file left on the old file. R-ST11 says an entry is Talon's only when its sha256 equals the data file, so such a stale entry counts as foreign, and setup keeps it. | (a) `tools.json` records the sha256 of each entry that Talon made; an entry with a recorded sha256 is Talon's, also when it is stale. (b) The names `tln`, `roc` and the tool names are always Talon's: replace a differing entry with no prompt. (c) Drop the second sentence of R-ST9: the update commands always make the entries again, and `setup` only makes missing ones. | (a): no foreign file is ever replaced, and a stale entry is repaired. It changes R-ST11 and the `tools.json` form (slice 046). |
| U2 | 028 Q1 | R-GC5 "keeps the default, and the toolchains that a known project pins and used in the GC age" can be read as AND or OR. | (a) OR: keep the default, every pinned toolchain, and every toolchain used in the GC age. (b) AND: keep a pinned toolchain only when it was also used in the GC age. | (a), applied in 028 by the manager: an old nightly can leave the release list, so a removed pin may not download again. Change it if you want (b). |
| U3 | 031 Q4 | R-BL6 says unit probes still run with `--no-check`. R-SO22 says `--no-check` runs no probe, so it needs no compiler. | (a) R-SO22 wins: `--no-check` runs no probe at all, and needs no compiler. Drop the "Unit probes still run" sentence of R-BL6. (b) R-BL6 wins: unit probes run with `--no-check`, so a missing compiler is a required download; change R-SO22. | (a): `--no-check` is the fast path that needs no compiler (the user answers of P0 rely on it), and unit facts come back at the next checked run. Slice 031 tests (a) until you answer. |
| U4 | 033 Q1 | R-EP6: "An inferred `fail` copies the set of failing modules of its source." In case (b) (between) there are 2 sources, and their module sets can differ. | (a) The union of the 2 sets. (b) The intersection. (c) The set of the nearer source. | (a), applied in 033 by the manager: an inferred fact never decides (R-EP8), and the union makes R-EP7 probe in place of skipping a used module. Change it if you want (b) or (c). |
| U5 | 036 Q4 | R-NI4 and R-DL1: one prompt for a command that needs a required compiler download (the held or pinned compiler is missing) and could also make optional downloads (other nightlies to probe, R-DL6 cap). How does the person accept the required one and refuse the optional ones? (037 review: R-NI4 already names the opt-in, `--probe-downloads` or `--yes` inside the cap; only the one-prompt question is open.) | (a) The one prompt lists both, and one answer covers both. (b) Two prompts. (c) The prompt asks only for the required download; optional downloads happen only with a flag `--probe-downloads` (or a config key). | (c): the R-NI4 default for optional downloads is "No download", so a plain run never downloads more than it needs, and one prompt stays one prompt. Slice 039 (`upgrade roc`, R-UP6) tests (c) until you answer; 037d found that only `probe --range` and the free-nightly `upgrade` make optional downloads. |
| U6 | 037 | R-EC has no exit code for `tln probe` when the target fails, hangs or crashes (the probe itself worked), or when `--range` finds no pass. | (a) Exit 0: the fact is the result; exit 1 only when there is no fact (R-P3). (b) Exit 10 (`no_tuple`) for a hash fail, and 11 (`app_error`) for a project-file fail, so CI sees it. | (a), tested in 037: `probe` is a measurement, and its facts and text show the fail. CI uses `tln verify` for a pass or fail gate. |
