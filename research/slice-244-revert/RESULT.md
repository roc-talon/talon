# Slice 244a mutation check (TW12)

Script: `research/slice-244-revert/mutate.sh [mutant names]`. Log: `run.log`. Each mutant is a `sed` edit of a mirror (`.tmp/slice-244-mut/`, deleted at the end; the working tree is not changed). Each test run is capped (`MemoryMax=16G`, no swap, `timeout 600`; the whole script ran in an outer 40G scope), `TMPDIR` in `.tmp/tmp`, one mutant at a time. L2 binary built with `--opt=dev`. Tests per mutant: the l0-9 driver and `tests/commands/run.sh audit/`. Baseline: l0-9 173 passed, L2 7 passed. No cap hit, no mutant looped.

Result: 20 mutants. 16 caught, 4 NOT caught (gaps: a2, a2b, a6b, plus a9 which is a bad mutant, see below). a3b is caught at L2 only.

| # | Mutant (place) | Behavior (slice list) | Caught by |
| --- | --- | --- | --- |
| a1 | `reason_of`: `state == Missing` loses to `release-missing` | 1 R-AU13 order | L0 (2 failed) |
| a1b | `reason_of`: `asset-replaced` wins over `yanked` | 1 | L0 (1 failed) |
| a2 | `state_of`: match by hash only | 2 | NOT caught (gap G1) |
| a2b | `state_of`: match by hash and version, not the group | 2 | NOT caught (gap G1) |
| a3a | `ignore`: the name is case-sensitive | 3 | L0 (1 failed) |
| a3b | `ignore`: the reason is not compared | 3 | L2 au9-ignore only. L0 passes (gap G2, weak) |
| a3c | `ignore`: the version is not compared | 3 | L0 (1 failed) |
| a4a | `code`: 21 also for an ignored failing finding | 4 | L0, L2 au9-ignore |
| a4b | `code`: 21 for a warning that is not ignored | 4 | L0 (2), L2 au3-warnings, au9-ignore |
| a5 | `closure_entry`: `via` is only the alias of the row | 5 | L0 (2), L2 au1-findings, au9-ignore |
| a6a | `entries`: a hash of 2 members is 2 entries | 6 | L0 (1 failed) |
| a6b | `ignore`: a repeated item is not made one | 6 | NOT caught (gap G3) |
| a7a | `AuditFlow`: the tool hash is not in the query | 7 | L2 au1-tool. L0 passes (flow code, by design) |
| a7b | `entries`: no tool entry is added | 7 | L0 (3), L2 au1-tool |
| a8 | `of_answer`: `checked` counts an unindexed entry | 8 | L0 (1), L2 au4-not-indexed |
| a9 | `AuditFlow`: `walk_loaded!` gets `notes = True` | 9 | NOT caught, but a bad mutant: that flag only prints `.roc-version` warnings. It is not the snapshot (see G4) |
| a10a | `AuditFlow`: the flags are read after `load_full!` | 10 | L2 au12-bad-items (calls.log) |
| a10b | `AuditFlow`: talon.toml items are read after the query | 10 | L2 au12-bad-items |
| a10c | `AuditFlow`: `--offline` is accepted | (Q-244-8) | L2 au4-not-indexed |
| a11 | `AuditFlow`: the talon.toml items are not read | R-AU12 | L2 au12-bad-items, au9-ignore |

Equivalent mutants: none found among the four.

## Gaps (not equivalent, not caught)

| # | Mutant | Why not caught | Suggested test |
| --- | --- | --- | --- |
| G1 | a2, a2b (`state_of` ignores the group, or the group and the hash only) | The decoy row (same hash, other group) in `AuditcheckTest.roc` `answer` comes AFTER `r_json`, and `find_first` finds the true row first. The "older release of json" decoy has another hash. | In the `state_of` test (L0 8) put the decoy row BEFORE `r_json` in `releases` (or use a second `answer` with the decoy first), plus a decoy with the same hash and group but another version. Expect `r_json` for `entry_of(h_json)`. |
| G2 | a3b (reason not compared in `ignore`) | The L0 `ignore` test has `acme/json@2.1.0:asset-replaced` as an item, but `f_json` is already ignored by the item `...:yanked`, and `find_first` takes the first item that matches; so a wrong-reason item matches nothing it needs to. Only L2 au9 run with a single wrong-reason item catches it. | L0: `ignore` with findings `[f_json]` and items `["acme/json@2.1.0:asset-replaced"]` only. Expect `f_json` not ignored and `unused` has the item. |
| G3 | a6b (a repeated unused item listed twice) | The repeated item in the L0 test (`acme/json@2.1.0:yanked` twice) is used, so it is never in `unused`. | L0: `ignore` with items `["a/b@1.0.0:yanked", "a/b@1.0.0:yanked"]` and no finding. Expect `unused == ["a/b@1.0.0:yanked"]` (R-AU11 "once each"). |
| G4 | behavior 9 (`[resolution] snapshot` hides no release) has no mutant | `AuditFlow` never passes a snapshot to the query (`ClosureIndex.query!` has no snapshot field), so no `sed` of the flow gives the wrong behavior; a mutant needs a new code line. au9 (parser and util at log index 7, 8) covers it for a future change. | None now. If a later slice sends the snapshot, keep au9 as the guard. |

Note: a7a and a10a to a10c are caught at L2 only. That is by design (command code over `Fx`, TESTING.md 2.2).

## Update: re-run

After the test agent added L0 tests for G1 to G3 (l0-9 is now 175 tests), `research/slice-244-revert/mutate2.sh` re-ran only a2, a2b, a3b and a6b (new mirror, baseline first, same filtered tests, same caps, no outer scope; log `run2.log`). Baseline: l0-9 175 passed, L2 7 passed. The mirror is deleted.

| Mutant | Before | After | Caught by |
| --- | --- | --- | --- |
| a2 (`state_of` by hash only) | NOT caught | caught | L0 (2 failed) |
| a2b (`state_of` without the group) | NOT caught | caught | L0 (2 failed) |
| a3b (`ignore` ignores the reason) | L2 only | caught | L0 (1 failed) and L2 au9-ignore |
| a6b (repeated unused item twice) | NOT caught | caught | L0 (1 failed) |

G1, G2 and G3 are closed. Of the 20 mutants, 19 are caught; the 20th (a9) is a bad mutant. G4 (behavior 9, no mutant possible without a new code line) stays open as a note; a9 was a bad mutant.
