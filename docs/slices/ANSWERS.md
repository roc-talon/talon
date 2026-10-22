# Answers of the user

The user confirmed these answers on 2026-10-22. They replace "proposal of the manager, not confirmed" in the slice files and in `docs/design-gaps/APPLIED.md`.

| Topic | Answer | Where |
| --- | --- | --- |
| Held moves: target of a moved version | The nearest value that works | G-held-moves Q1, R-SP24 |
| `ROC_TOOLCHAIN` differs from the header pin | Keep the pin, probe on it, print the note | G-pin-gate H1, R-SO20, slice 013 |
| `--as` over an unmanaged entry | Replace with no prompt | G-never-change Q1, R-AD38 |
| `X@sel` in `why`, `remove`, `patch`, `probe` | Filter by version | G-tie-names Q1, R-SC16 |
| `list` with a registry | No closure query (R-DI1) | G-closure-fetch Q1 |
| Talon writes path entries | Never: hand edits only | G-never-change Q2, R-H4 |
| Tie hint `tln update <alias>@<sel>` | Yes | G-tie-names Q2, slice 014 |
| Stale key, non-interactive, no answer flag | Exit 13 | Slice 007 Q1, R-NI1 |
| No release matches the selector | `add`: exit 2, `update`: exit 10, both list 3 close versions | Slice 007 Q2, slice 009 Q5 |
| `verify` when nothing changes | The ladder always runs | Slice 009 Q4 |
| `--json --quiet` | The JSON envelope only | Slice 007 D4 |
| Bad `TALON_NIGHTLY` value | Counts as not set | Slice 012 Q31 |
| `remove`: a local module that cannot be read | The scan skips it | Slice 008 Q7 |
| `remove --force` with no import | The check runs | Slice 008 Q4 |
| Old duplicate rule ids | Renumber the later copies, fix references and the index | To do on resume |
| O1 (P2): releases of the movable groups with a registry | A second query, only when the first search fails | To do on resume: a design edit (Registry, R-DI1) |

The other proposals of the manager in slices 007 to 017 stay as written, and the user has not changed them.
