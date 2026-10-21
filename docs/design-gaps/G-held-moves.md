# G-held-moves: move a held variable (R-SP16, R-SP17, R-NI3, R-WS12)

## 1. The gap

| Rule | File, section | What it says | Problem |
| --- | --- | --- | --- |
| R-SP15 to R-SP17 | Resolution 9 | With no tuple when the held variables are fixed, Talon names "the variables that must move and why", asks R-NI3, and moves "the named variables" | No rule says how the solver finds that set. Freeing all held variables gives a tuple, but it can move many variables that did not need to move. "Must move" has no definition. |
| R-SP22, R-UP4, R-RP4 | Resolution 9, 10 | Install, upgrade use the same consent rows | Same gap |
| R-RP2 | Resolution 9 | The nightly never moves in `install`, `add`, `update`, `remove` | Clear. It limits the set. |
| R-SP6, R-PA4, R-DI11 | Resolution 9, 7, CLI 7.3 | Anchors (`=`), patched entries and fixed anchors are held in `upgrade` | Silent: can R-NI3 move them? |
| R-NI3, R-NM5 | CLI 4 | Required prompt, default No, non-interactive exit 13 | Silent: the exit code when the person answers No. Silent: when the prompt shows (before or after the ladder). |
| R-WS12 | Design 4.4 | A group of other members is held. "The move writes those members too" | Silent for `update`, `install` (R-WS11 covers only "a group that moves"). Silent on `talon.toml`. |
| R-PH10, R-PH9 | Design 7 | P0 has one tuple | Silent: is the second search of a move P0? |
| `--allow-moves` | CLI 1 table | "answers R-NI3" | Silent: does it widen the scope (free held variables to get a newer free one)? |
| R-WS6, R-I5 | Design 4.4, 4.3 | A `talon.toml` key in no header: "the key has no effect" until `tln install` | Slice 009 G2: `Vars.build` applies the R-WS6 stop to `update` too |

P0 today: `Pick.step` (`cli/lib/Pick.roc`) gives a held slot the one value `current`. With no tuple it fails with exit 10. `Add.check_held` (`cli/lib/Add.roc:149`, called from `cli/lib/PickFlow.roc:220`) stops `add` with exit 10 and the text "which this version of tln cannot ask". `--allow-moves` is read (`cli/lib/Opts.roc:69`) and changes nothing. `Consent.move_held` exists with no caller.

How other tools do it:

| Tool | A locked or held version must change | Consent |
| --- | --- | --- |
| Cargo | `cargo add`, `cargo update -p X`: lock entries are preferences. The resolver changes other entries when needed and prints `Updating`. | None |
| uv | Lock entries are preferences. `uv add` changes others when needed. | None |
| npm, Bun | `install X` changes other lock entries when needed | None |
| Go modules | `go get X@v` raises each other module to the minimum that MVS needs, and prints `go: upgraded Y v1 => v2` | None |
| Talon (design) | A held variable moves only with consent (R-NM5) | R-NI3 |

## 2. Options

| # | Option | Cost in P0 | P1 and later | Users |
| --- | --- | --- | --- | --- |
| A | No move ever. Remove R-NI3. The error names the command that frees the variables (`tln update json pf`). | Small: a hint text | PubGrub needs no second search | Two commands for one goal. `tln add` in a workspace (R-WS12) has no command that does it in one step. |
| B | Preferences, as Cargo and uv: a second search frees all held variables, ordered after the free ones, newest first. Moves silently, or asks R-NI3 for the set that differs. | Medium | One extra search | The set is large and changes with `priority`: a held variable can move only because a free one got its newest version. "Must move" is false. |
| C | Sticky second search: the movable held variables come first in the search order, each tries its current value first, then the nearest value. The variables whose value differs are the set. One prompt after the ladder. | Medium: one more `Pick.step` mode, one index fetch, the prompt, the multi-member write | One PubGrub run with a decision order and a value preference. No new loop. | Each moved variable is needed: it could not keep its value given the earlier ones. The move is the smallest step (Go). |
| D | Minimum set: try each subset of held variables by size until a tuple exists | Large | 2^n searches, each with probes (R-P5 budget) | Exact minimum, but slow and hard to explain |

## 3. Decision

Option C. Reasons:

| Reason | Detail |
| --- | --- |
| One search, deterministic | The second search is the same lexicographic search (R-VA6, R-DT2) with another order. PubGrub gets the same thing as a decision order and a version preference. |
| "Must move" has a meaning | A held variable keeps its value when any tuple exists with it and the earlier held variables at their values (greedy deletion filter in `priority` order). So each moved variable is irreducible in that order. Option D gives a smaller set only in rare cases, at an exponential cost. |
| Small, safe moves | R-RP1 says `update` is the small, safe move. A moved variable goes to the nearest value that works, not the newest. To get the newest, the user names it. |
| The prompt shows a checked result | The prompt comes after the ladder. In P1 a failed probe can change the set (R-AL5), so only the final tuple has the true set. The user consents to a diff that passed the check. |
| Same in both modes (R-NM3) | Non-interactive mode runs the same steps and stops at the prompt with exit 13 and the same report. The cost: a CI run without `--allow-moves` runs the ladder and then stops. |
| Consent stays | The design chose consent for moves the user did not name (R-NM5). Cargo, uv and npm move silently. Talon keeps the prompt but makes the moved set small and clear. |

What `--allow-moves` means: it answers R-NI3 Yes, and nothing more. It does not change the search, so its result is the interactive Yes. It never frees the nightly outside `upgrade` (R-RP2), an anchor, a patched entry or a fixed anchor. It does not free a held variable to get a newer version of a free one when a tuple already exists (R-SP15): then the user names both (`tln update json pf`).

P0: implement it now (new slice). R-NI3 is a P0 prompt (`TESTING.md` 317, R-NI1 to R-NI3), and the P0 search (R-C1 to R-C4) already gives the conflicts that make a move. It is still one tuple for the ladder (R-PH10).

Slice 009 G2 is not part of this decision, but it is near: R-I5 says a key in no header has no effect until `tln install`, so the R-WS6 stop applies only to `install`. A clarification of R-WS6 follows.

## 4. Design edits

### 4.1 DESIGN-RESOLUTION.md, section 9

R-SP16, old:
`| R-SP16 | No such tuple | Names the variables that must move and why, for example `json 2.2.0 needs pf >= 0.26.0`. Asks for consent to move them. Prompt R-NI3 (CLI 4), default no. |`

R-SP16, new:
`| R-SP16 | No such tuple | Runs the second search (R-SP24), then the ladder on its tuple (section 4). Then it names each held variable that moves, its old and new value, why (for example `json 2.2.0 needs pf >= 0.26.0`), and the member files that the move writes (R-SP25). Asks for consent to move them: prompt R-NI3 (CLI 4), default no. The prompt is the last step before the write. No: Talon writes nothing and stops with exit code 13 (`consent`). With no tuple in the second search, or a ladder that fails, Talon stops with exit code 10 as before, and asks nothing. |`

R-SP17, old:
`| R-SP17 | Non-interactive mode (CLI 4) and no `--yes` | Stops with the same report and exit code 13. Writes nothing. With `--allow-moves` or `--yes`, moves the named variables. |`

R-SP17, new:
`| R-SP17 | Non-interactive mode (CLI 4) and no `--yes` | Stops with the same report and exit code 13, after the same search and ladder. Writes nothing. With `--allow-moves` or `--yes`, moves the named variables, in both modes. `--allow-moves` only answers R-NI3: it does not change the search, the scope (R-SP2 to R-SP9) or the movable variables (R-SP23). |`

New rows after R-SP17 (ids R-SP23 to R-SP26 are free: `grep -o "R-SP2[3-6]" DESIGN*.md` finds nothing):

`R-SP23: A movable variable is a variable that the command holds only because the user did not name it: R-SP3, R-SP4, R-SP7, R-SP9, R-SP19, and a group of other members (Design 4.4, R-WS12). These are never movable: the nightly outside `tln upgrade` (R-RP2, R-RP4), an anchor (`=`, R-VA5), a patched entry (R-PA4), a fixed anchor (R-DI11). The user frees them by name. A moved variable keeps the constraints of a free variable of the command: R-C1 (its ranges; none in `upgrade`, R-UP1), R-C6, R-C7 and R-C9.`

`R-SP24: The second search is the search of section 5 with two changes. The order of the variables: the movable variables first, in `priority` order (section 1), then the free variables in `priority` order. The order of the values of a movable variable: its current value first, then the nearest values. With `strategy = "highest"`: the higher versions from low to high, then the lower versions from high to low. With `"lowest"`: the lower versions from high to low, then the higher versions from low to high. So a movable variable keeps its value when a tuple exists with it and the earlier movable variables, and else moves the smallest step. The moved variables are those whose value differs from the header.`

`R-SP25: A move writes each member that has an entry for the group of the moved variable (Design 4.4, R-WS1), with the same value. In `install`, `add` and `update` the new value is inside the ranges, so `talon.toml` does not change. In `upgrade`, R-UP5 applies to each moved variable.`

`R-SP26: `--dry-run` (R-LF4) does not ask R-NI3. It prints the report of R-SP16 and the header diff with the moves, writes nothing, and exits with code 0.`

### 4.2 DESIGN.md, 4.4 (R-WS12, R-WS6) and 7 (R-PH10)

R-WS12, old:
`A group that other members have is held at their version (Resolution 9). If that version must move, prompt R-NI3 asks, and the move writes those members too. |`

R-WS12, new:
`A group that other members have is held at their version (Resolution 9). The range of the new entry joins the ranges of that group (R-WS2). If that version must move, prompt R-NI3 asks, and the move writes those members too (Resolution 9, R-SP23 to R-SP25). |`

R-WS6, old:
`Else it stops with exit code 2 and names `tln add --file <member file>` (CLI 1, R-PD5). |`

R-WS6, new:
`Else it stops with exit code 2 and names `tln add --file <member file>` (CLI 1, R-PD5). Only `tln install` runs this check. `update`, `upgrade` and `verify` ignore the key (R-I5). |`

R-PH10, old:
`| R-PH10 | Search | One tuple: the best one by `priority` under R-C1 to R-C4, R-C6, R-C7 and R-C9 (Resolution 5 step 3). If the ladder fails on it, Talon stops with exit code 10 and the blame of the ladder. |`

R-PH10, new:
`| R-PH10 | Search | One tuple: the best one by `priority` under R-C1 to R-C4, R-C6, R-C7 and R-C9 (Resolution 5 step 3). With no tuple, the second search of a held move (Resolution 9, R-SP24) gives the one tuple. If the ladder fails on it, Talon stops with exit code 10 and the blame of the ladder. |`

(The P1 column of R-PH10 does not change.)

### 4.3 DESIGN-CLI.md, 3 (R-EC13)

R-EC13, old:
`Also: the person declined the GitHub login of `tln share login`, or its code expired (R-SH7). |`

R-EC13, new:
`Also: the person declined the GitHub login of `tln share login`, or its code expired (R-SH7), or the person answered No to a move of a held variable (R-NI3, Resolution 9, R-SP16). |`

R-NI3 row and the `--allow-moves` row of CLI 1: no change.

## 5. The work that follows

New slice (013, "held moves"). Order of TESTING.md 7: scope, tests (red), review, code, verify.

| Part | Change | Rule ids |
| --- | --- | --- |
| `cli/lib/Vars.roc` | `Scoped` gets `movable : Bool` (R-SP23). `build` no longer stops for R-WS6. The stop moves to the install path (slice 009 G2). | R-SP23, R-WS6 |
| `cli/lib/Pick.roc` | `Slot.free : Bool` becomes `hold : [Free, Held, Movable]`. `step` gets `second : Bool`. With it: the search order and the value order of R-SP24, and ranges and R-C7 apply to a `Movable` slot. The result order stays the slot order. New pure `Pick.moves`: for each moved slot, `{ id, from, to, why }`. `why` is the first conflict of R-C1, R-C2 or R-C3 that the current value has in the final tuple. | R-SP24, R-SP16 |
| `cli/lib/PickFlow.roc` | On `NoTuple` with a movable slot: fetch the index of the movable groups (P0 fetches only free names today), run `pick_loop!` with `second`. Remove the `Add.check_held` call; the R-WS12 entry goes in as a `Movable` slot with the new range. | R-SP16, R-WS12 |
| `cli/lib/Add.roc` | Remove `check_held` and its text | R-WS12 |
| `cli/lib/Consent.roc` | `move_held` gets `from`, `to` and `members` for the report | R-SP16, R-NI3 |
| Write path (`Resolve`, `InstallFlow`) | After the ladder, `Prompt.decide` with `Consent.move_held` and the `allow_moves` answer. Yes: write each member of R-SP25. No: exit 13. `--dry-run`: no prompt, exit 0. | R-SP16, R-SP17, R-SP25, R-SP26, R-EC13 |
| L0 tests | `Pick`: order of the second search, nearest values for both strategies, a non-movable slot stays, `moves` and `why` for R-C1, R-C2, R-C3. `Vars.scope`: `movable`. | R-SP23, R-SP24 |
| L2 tests | `add`, `update X@sel`, `install` (R-SP20 key): non-interactive stop (13, report), `--allow-moves`, `--yes`, interactive Yes and No (fake `Fx`), workspace `add` that writes 2 members, an anchor that cannot move (10), `--dry-run` (0). `update` on a 2-member workspace with a key in no header (slice 009 G2). | R-SP16, R-SP17, R-SP25, R-SP26, R-NI3, R-NM8, R-NM10, R-WS12, R-WS6 |
| Old tests (test agent, TW18) | `tests/unit/add.roc` expect of `check_held` goes. `install/in1-workspace-frozen-rename`: the held-group run changes from exit 10 to the R-SP16 flow. | R-WS12 |
| P1 | The second search is a PubGrub run with that decision order. Learned incompatibilities of the first search stay. R-NI3 asks once, after the oracle loop ends. The budget R-P5 covers both searches. `why` adds the evidence reasons of R-C5 in the form of R-UP2. | R-SP24, R-AL5 |

Output proposals for the human review (TW24): the report line `~ pf: roc-lang/basic-cli 0.25.0 -> 0.26.0 (held): json 2.2.0 needs pf >= 0.26.0`, then `  writes apps/a/main.roc, apps/b/main.roc`. With `--json` and exit 13: `error.details.moves[]` with `alias`, `name`, `from`, `to`, `why`, `members`.

## 6. Questions (TW17)

| # | Question | Proposal |
| --- | --- | --- |
| Q1 | A moved held variable goes to the nearest value that works (R-SP24), not to the newest in its range. Example: `tln add json` needs `pf >= 0.26.0`; pf moves 0.25.0 -> 0.26.0, also when 0.27.1 is in range. Is that the wanted user result? | Yes: the user did not name pf. `tln update pf` moves it further. |
