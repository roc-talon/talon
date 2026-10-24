# 037d Optional downloads in the resolve commands

Phase: P1. Status: closed (stopped at the scope step: the design gives no producer, TW17)

Slice 037d is the plan row 037d of `PLAN-P1.md`. It needs 037c (done). The row says: a probe of other compilers of D for the R-RP2 hint ("the oldest nightly that works"), with the opt-in and cap of 037c, and the one prompt when the same command also has a required download (U5).

The test agent checked the design first (the order that the manager gave). Result: the design does not ask `add`, `update`, `install` or `verify` to download a compiler for the hint. The only commands where a resolve search has other compilers are `tln upgrade` with a free nightly (slice 039) and `tln probe --range` (037, 037c, done). So this slice has no test, no stub, no fixture and no change of an old file. The manager can close the row, or move it (Q1).

## 1. Evidence

| # | Source | Text (short) | What it shows |
| --- | --- | --- | --- |
| E1 | Resolution 9, R-RP2 | `install`, `add`, `update`, `remove` always hold the nightly. With no tuple: exit 10, nothing written. "The error names the oldest nightly that works, when a probe or the matrix knows it" | The hint is a fact that Talon may know. The text has no step that makes the fact. "when ... knows it" is a condition, not a duty to probe |
| E2 | Resolution 5, example of the failure | `checks on nightly 09-24 .. 10-01`, `checks on nightly 10-09 .. 10-12`, "measured ranges" | The ranges of the example are known facts (`compat.db`, matrix, epochs). No download is in the example |
| E3 | Resolution 13, R-SO19, R-SO20, R-SO21; Resolution 4 R-BL1 and the "Baseline check" rule R-BL3 | In a held-nightly command the probes run on the held nightly. The baseline compiler is the held nightly and "the candidate needs it too, so it adds no download" | A held-nightly command needs 1 compiler (required, R-DL2). No pair (hash, other compiler) is asked, so no optional download can start |
| E4 | Resolution 4, R-AL4, R-PP2 | "installed nightly first, then the strongest hint". The concurrent probes are "3 nightlies of a nightly range in a search" | Other compilers are in a search only when `roc` is a free variable (a range search) |
| E5 | Resolution 10, R-UP6 | "When the nightly is free, ... All other compiler downloads are optional probe downloads (R-NI4)" | The one place in the resolve commands where the design makes optional downloads: `tln upgrade` with a free nightly. It is slice 039 (R-UP6 is in its row) |
| E6 | Resolution 4, R-PB3, R-PB4 | `--range` has "compiler downloads are optional probe downloads (R-NI4, R-DL4, R-DL6)" | The other producer. Done in 037c |
| E7 | CLI R-NI4 (row of the prompt table) | Commands: `add`, `update`, `upgrade`, `install`, `probe`, `verify`. Default: no download. Flag `--probe-downloads`, `--yes` | A table row for all commands that resolve. It gives the answer, not the source of a download. With E3, in `add`, `update`, `install`, `verify` there is no source |
| E8 | CLI R-DL2 | "An optional download only widens a probe search (Resolution 4, R-P5)" | A download is optional only inside a probe search with a wider domain (E4, E5, E6) |
| E9 | Resolution 12, R-LF4 | `--dry-run`: "Talon answers No to optional downloads (R-NI4)" | The resolve flags apply to `upgrade` too (E5). It does not name a producer in a held-nightly command |
| E10 | Slice 036 Q5, 036c review | Q5 (a) "D with the cap" was a proposal of the manager. The 036c review accepted "R-RP2 reading: the hint comes from known facts" | The accepted reading of R-RP2 is known facts. It agrees with E1 and E2. The code of 036c (`Oracle.hint`) does that |
| E11 | CLI R-U3 (`upgrade roc`) and Resolution 10 R-UP6, with CLI R-DL1 | `upgrade roc`: the baseline compiler (R-NI5) is "in the same prompt as the new nightly" (R-NI12). Other compilers are optional (R-UP6) | The one prompt with a required and an optional download is a rule of `upgrade roc` (slice 039), not of the held-nightly commands |

Verdict: the row 037d as written has no design source. A producer that downloads compilers to find the hint would be a design change, not a test of a rule. It would also be a harm: a command that fails with exit 10 should be fast and should write nothing (R-RP2), and the default of R-NI4 is "no download".

## 2. What a producer for the hint would need (for Q1 option (a), as information)

The 037c review (Q8) said about 300 lines and a design question of its own. The test agent found these open points. The code and the tests would need an answer to each one.

| # | Open point | Why the design is silent |
| --- | --- | --- |
| 1 | Which compilers of D, in which order? | R-RP2 says "the oldest nightly that works". To find the oldest, a binary search over D needs a pass or fail for the whole tuple on each compiler (Done on n), not one unit probe. R-PB3 has a search for 1 hash only |
| 2 | Which facts make "works on n"? | The step is `Done` only with real facts for each pair of the tuple on n (R-EP8). The tuple is the held tuple (a failed one) or the best tuple on n. The design says neither |
| 3 | Does the search use the budget of the command? | R-P5 gives `probe.max` for the command. The 036b2 rule says that a spent budget gives exit 12 and no explanation. A hint search after exit 10 would need an exit rule: 10 or 12 |
| 4 | The result is not written. Is a download for a hint a download "for a probe that can start" (037c Q4)? | R-DL2 says an optional download widens a probe search. Here it widens a message |
| 5 | Which prompt? | R-NI4 has one default "No download". A person in a held-nightly failure would get a prompt after a failure, which R-DL1 does not describe ("the one prompt of the command shows before Talon takes a lock", CLI R-CC4 step 2) |

## 3. Questions (TW17)

| Id | Question | Options (the tested reading first) |
| --- | --- | --- |
| Q1 | The row 037d has no producer in the design (section 1). What does the manager do with it? | (a) Close the row with "no slice". R-RP2 is done by 036c (known facts). The producer of optional downloads for the resolve commands is the free-nightly search of `upgrade` (R-UP6, slice 039), which uses `Consent.optional_*` and `ProbeSearch` of 037c. The one prompt with a required download (R-U3, R-NI12 with R-NI4) is a test of 039. Recommended. (b) Move the row into 039: add the optional-download branch to its scope, with its own test agent split. (c) Keep 037d and ask the user for a design rule for the hint search (section 2, points 1 to 5). The test agent would then write the slice from that rule |
| Q2 | R-RP2 says "when a probe or the matrix knows it". Do you want a probe on other compilers to make the hint (the user, for the design)? | (a) No: known facts only (the accepted reading of 036c, recommended). A person who wants the answer runs `tln probe <alias> --range --probe-downloads` (R-PB3), which also fills `compat.db`, then runs the failed command again. The `fix:` text could name that command (a TW24 proposal for a later slice). (b) Yes: the user gives the rules of section 2 |
| Q3 | U5 (the prompt asks only for the required download) | No row of this slice depends on U5 now. The rows that would depend on it are the one-prompt runs of 039: one marked row for the prompt text and one for the answer. Reading (c) stays as the manager recommended in `PLAN-P1.md` section 6 |
| Q4 | Edit of the design text? | R-NI4 lists `add`, `update`, `install`, `verify` as commands with optional downloads. With E3 no such download exists in them. The text could say "commands that search more than one compiler (`upgrade`, `probe`)". The test agent does not edit the design. It is a gap for the human |

## 4. Design gaps

| Gap | Where |
| --- | --- |
| R-NI4 and the flag table (CLI, `--probe-downloads`: "Commands that resolve, and `probe`") list commands that have no source of optional downloads in the design: `add`, `update`, `install`, `verify` | CLI R-NI4, line 84 of the flag table |
| R-RP2 "when a probe or the matrix knows it" does not say whether "a probe" is a probe that the same command makes | Resolution 9 |
| `--probe-downloads` is parsed for all commands that resolve (`cli/lib/Args.roc:256`) and read by no code outside `probe`. A person who gives it to `tln update` gets no effect and no message | `cli/lib/Args.roc:256`, `cli/lib/Opts.roc:79` |

## 5. Tests, output, signatures

| Item | State |
| --- | --- |
| Rules R-RP2, R-DL1, R-NI4 | R-RP2 is tested in 036c (known facts). R-DL1 and R-NI4 are tested in 037c for `probe --range`. No new test |
| Public signatures | none |
| Output proposals (TW24) | none |
| Old L2 and L3 files that change (TW21) | none |
| Red run, green run, revert check | not run: no test and no code. No mutation. `scripts/test.sh` was not run (no file of the code changed) |
| Size of the row | If the manager keeps the row with option Q1 (c) and a design rule: the estimate of 037c Q8 is about 300 lines. This is under 450, so no split by size. The test agent would propose a split by topic: 037d1 the hint search, 037d2 the one prompt (the part that fits 039) |

## 6. Files

| File | Change |
| --- | --- |
| `docs/slices/037d-resolve-downloads.md` | new (this file) |
| `research/slice-037d-revert/before/NEW.txt` | new: lists the slice file |
| `cli/`, `tests/`, `packages/`, `scripts/`, the design files | none |

## Close (manager, 2026-10-24)

Q1 (a): the row is closed with no slice. R-RP2 is done by 036c from known facts (the 036c review), and the design has no producer of optional downloads in the held-nightly resolve commands (E1 to E11). Q2: known facts only, as 036c; the person runs `tln probe <alias> --range --probe-downloads`. Q3: the one prompt with a required and optional downloads moves to slice 039 (R-UP6), with U5. Q4 and the `--probe-downloads` gap: recorded in PLAN-P1.md 5b. Status: closed.
