# Slice 244c mutation check (TW12)

Script: `research/slice-244c-revert/mutate.sh [mutant names]`. Log: `run.log`. Each mutant is a `sed` edit of a mirror (`.tmp/slice-244c-mut/`, deleted at the end; the working tree is not changed). Each test run is capped (`MemoryMax=16G`, no swap, `timeout 600`), no outer scope, `TMPDIR` in `.tmp/tmp`, one mutant at a time. L2 binary built with `--opt=dev`. Tests per mutant: l0-9 and `tests/commands/run.sh audit/ registry/au7-install-warnings registry/fe10-install-404`; for c11 (hook leak) also `install/ update/ verify/`. Baseline: l0-9 186 passed, L2 22 passed (`audit/`, the 2 registry cases, `install/ update/ verify/`). No cap hit, no mutant looped.

Result: 11 mutants. 8 caught, 3 NOT caught (G1 to G3). No equivalent mutant found.

| # | Mutant (place) | Behavior | Caught by |
| --- | --- | --- | --- |
| c1 | `AuditResolve.warn!`: the first answer is searched before the second (held move) | 2 / Q-244c-2 | NOT caught (G1) |
| c2 | `AuditCheck.resolve_findings`: the last answer with the row wins | 2 | L0 c2 |
| c3a | `resolve_findings`: an ignored finding still gives a line | 3 | L0 c1 |
| c3b | `AuditResolve.warn!`: a bad `[audit] ignore` item drops all items (strict parse) | 3 | NOT caught (G2) |
| c4 | `resolve_line`: no R-PU28 line for `moved` of a header entry | 4 | L0 c4, L2 au7-install-warnings |
| c5 | `resolve_direct`: `asset-replaced` with a new hash gives a line | 5 | L0 c3 |
| c6 | `warn!`: the warnings go to stdout | 6 (stderr) | L2 au7-install-warnings only (L0 cannot: flow) |
| c7 | `download_failed`: the 404 text for any reason (a prerelease too) | 7 | L0 c6 |
| c8 | `fix`: a transitive entry with an unknown `via` gets a tool fix | 8 | L0 c6 |
| c9 | `fix`: `moved` gets a fix again | 9 | L0 (3 failed), L2 ad1-direct, au1-findings, au3-warnings, au9-ignore |
| c10 | `text`: the `fix:` line lists a finding that does not fail | 9 | L2 ad1-direct, au3-warnings (L0 passes) |
| c11 | `with_warnings`: `audit_warnings: []` is added to every `--json` run with closure answers | R-J6 (no output of today changes) | NOT caught (G3) |

Not mutated (by design): the exit code stays 0 with warnings and `--quiet` keeps them (`warn!` only prints; no code path changes the exit code). The `status == 404` guard of `download_failed` is not mutated: `AuditResolve.explain` passes the constant 404, so a mutant there is equivalent.

## Gaps (not equivalent, not caught)

| # | Mutant | Why not caught | Suggested test |
| --- | --- | --- | --- |
| G1 | c1 (second answer searched after the first) | L0 c2 tests `resolve_findings` with the answers in the order it is given; no test checks that `warn!` puts `[second, first]`. No L2 case has a held move with 2 answers. | L2 case: `update` or `install` that makes a held move where the first answer says json `active` and the second answer says json `missing` (or the reverse). Expect the warning of the second answer. |
| G2 | c3b (a bad item drops the good items) | A resolve with a `talon.toml` that has `[audit] ignore` is not in L2 (the u1 world has no `talon.toml`). L0 c1 tests `resolve_findings`, not the reading of the toml in `lenient_items`. | L0 on `AuditResolve.lenient_items` (make it public or test it through a small function): `ignore = ["acme/json@2.1.0:yanked", "bad", 3]` gives the first item only. Or an L2 install case with a `talon.toml` that has such a list and a yanked json: no line for json, exit 0, no stop. |
| G3 | c11 (`audit_warnings: []` on runs with no finding) | No L2 case of `install/ update/ verify/` has a closure answer (a registry) and `--json`; only `au7-install-warnings` does, and it has warnings. R-J6 is untested. | L2: copy `au7-install-warnings` with an answer where json and parser are `active`; `install --no-check --dry-run --json`. Expect `data` with no `audit_warnings` member. |

## Update: re-run of c1, c3b and c11 after the new tests

The test agent added the L2 cases registry/au7-held-move (G1), au7-ignore (G2) and au7-no-finding (G3). `TT="audit/ registry/au7 registry/fe10 install/ update/ verify/" mutate.sh c1 c3b c11`, then `mutate2.sh c11` (the same script with that list in `TX`, because c11 sets `TT="$TX"`). Same caps, no outer scope; log `run2.log`.

| Mutant | Before | After | Caught by |
| --- | --- | --- | --- |
| c1 (first answer searched before the second) | NOT caught | caught | L2 registry/au7-held-move |
| c3b (a bad ignore item drops all items) | NOT caught | caught | L2 registry/au7-ignore |
| c11 (`audit_warnings: []` on every --json run) | NOT caught | caught | L2 registry/au7-no-finding |

G1 to G3 are closed. All 11 mutants are caught.
