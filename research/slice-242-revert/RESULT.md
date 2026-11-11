# Slice 242 mutation check (TW12)

Script: `research/slice-242-revert/mutate.sh`. Log: `run.log`. Each mutant is a `sed` edit of a mirror of `cli/lib` under `.tmp/slice-242-mut/` (the working tree is not changed; the mirror is deleted at the end). Each run is capped (`MemoryMax=16G`, no swap, `timeout 600`), `TMPDIR` in `.tmp/tmp`. The L2 binary is built with `--opt=dev`. Tests run: the l0-9 driver, and `tests/commands/run.sh channels/ch12 channels/ch13` with the mutant binary. Baseline: l0-9 134 passed, L2 22 passed.

Result: 15 of 15 mutants caught. No test was added. No equivalent mutant.

| # | Mutant (place) | What it breaks | Caught by |
| --- | --- | --- | --- |
| m1 | `ChannelCmd.add_url_flow!`: the conflict (19) is skipped when `--offline` | order of the local checks: conflict before `--offline` (Q617-2) | L2 ch12-add-order |
| m2 | `add_url_flow!`: the `Same` arm does not return | same source is exit 0 "already added", no request (Q617-1) | L2 ch12-add-exists, ch12-add-json |
| m3 | `list_page!`: the prefix derivation counts drafts and prereleases | Q618, R-CH4 | L2 ch12-add-nobuild |
| m4 | `Channel.prefix_in_tag`: an invalid derived prefix counts | Q617-3 | L0 ChanneladdTest (1 row set). L2 does not reach it (the L2 lists have no tag with an invalid prefix); the L0 rows are the test |
| m5 | `list_page!`: `pages: 1` becomes 3 | `add` reads page 1 only | L2 ch12-add-page1 |
| m6 | `rm_flow!`: no refusal of `--tag-prefix` | option refused for `rm` | L2 ch12-flag |
| m7 | `list_flow!`: no refusal of `--tag-prefix` | option refused for `list` | L2 ch12-flag |
| m8 | `add_copy_flow!`: a different table is not exit 19 | R-CH13 (1), R-CH10 | L2 ch13-add-copy-errors |
| m9 | `rm_flow!`: `Builtin` goes on | `rm nightly` is exit 2 | L2 ch13-rm-errors |
| m10 | `rm_flow!`: `Missing` goes on | `rm` of an unknown or project-only name is exit 2 | L2 ch13-rm-errors |
| m11 | `Manage.table`: no `(channel removed)` mark | `roc list` mark (R-CH13) | L2 ch13-rm |
| m12 | `Channel.list_rows`: a project-only table is shown as added | `list` marks it not added (Q617-7) | L0 ChannelfileTest (2 expects), L2 ch13-list-project |
| m13 | `recorded_source`: the recorded source is not read | the conflict uses the recorded `source` (R-CH12) | L2 ch12-add-conflict, ch12-add-order |
| m14 | `add_url_flow!`: another source in config.toml is not refused | Q617-1 | L2 ch12-add-exists, ch12-add-order |
| m15 | `list_page!`: no stop when page 1 has no build | Q618 | L2 ch12-add-nobuild |

Notes. The 14 L0 runs for m1 to m3, m5 to m11 and m13 to m15 pass (these mutants are in the command module, not in a pure function), as expected: the behavior is tested at L2. The `rm` leaves the toolchain tree unchanged (no `.cache` line in the tree.diff of ch13-rm) is tested by the tree.diff of every `rm` run; a mutant for it needs a second code path in `rm_flow!` and was not made.
