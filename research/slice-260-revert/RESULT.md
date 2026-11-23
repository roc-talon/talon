# Slice 260 mutation check (TW12, Design Q639)

Date: 2026-11-23. Test agent. Script: `mutate.sh` (mirror under `.tmp/slice-260-mut`, capped 16G, flocked, TMPDIR set, timeout 600, `--opt=dev`). Logs: `run1.log` (first set of cases), `run2.log` (base, m3, m4 with all the gap cases).
Tests: L2 `upgrade/ur10 upgrade/ur11 audit/ad17 registry/ad35-add upgrade/ur3 upgrade/ur4 upgrade/ug6 outdated/od1 init/it1 tool/ts1 audit/ad1` (27 cases), L3 `tools/tx1-x-run`.

## Result: 6 mutants, 6 killed

| Mutant | File | Change | Killed by (before gap cases) | Killed by (with gap cases) |
| --- | --- | --- | --- | --- |
| m1 | ToolFlow.roc | the tool release list uses `facts.now` (TALON_NOW) | L3 `tools/tx1-x-run` | L3 `tools/tx1-x-run` |
| m2 | PickIndex.roc | the package lists use `request.now` | survived | L2 `upgrade/ur10-real-clock-age` (new) |
| m3 | FullName.roc | `read_real!` gives `now`, not `real`, to `Github.releases!` | survived | L2 `registry/ad35-add-real-clock` (new) |
| m4 | NightlyFlow.roc | the compiler list (`Nightlies.list_of!`) uses `request.now` | survived | L2 `upgrade/ur11-real-clock-nightlies` (new) |
| m5 | Install.roc | `begin_loose!` sets `real` to TALON_NOW | survived (no case had real != TALON_NOW) | L2 `upgrade/ur10-real-clock-age`, `audit/ad17-real-clock-age` (new) |
| m6 | AuditFlow.roc | `audit` (direct) uses `request.now` | survived | L2 `audit/ad17-real-clock-age` (new) |

Base (unchanged mirror): L2 26 passed, 1 failed; L3 1 passed. The failure in each run is `outdated/od1-table`: a red slice 262 test (the `(pinned)` text in `expect/stdout`, edited in the working tree by the 262 test agent), not slice 260.

## Gap cases (new, L2)

Each is a copy of an old case with 2 changes: `fx/clock` (the real clock of the fake Fx) is 1792069200, one hour after TALON_NOW (1792065600), and `fx/mtimes` gives a page `.meta` the time 1792065590. With TALON_NOW the page is 10 s old (used, no request); with the real clock it is 3610 s old (a new request). The expected files differ from the old case only in `calls.log` (the extra request lines), read line by line.

| Case | From | Extra calls (real clock) |
| --- | --- | --- |
| `upgrade/ur10-real-clock-age` | `upgrade/ur3-list` | runs 3 and 4 read `acme/json` again |
| `upgrade/ur11-real-clock-nightlies` | `upgrade/ur4-candidate` | run 2 reads `roc-lang/nightlies` and `acme/lib` again |
| `audit/ad17-real-clock-age` | `audit/ad1-direct` | run 2 reads `acme/json` again |
| `registry/ad35-add-real-clock` | `registry/ad35-add-ingest-429` (+ a cached page `acme/limit/1.json`, `1.meta` with etag "g1") | one request with `If-None-Match: "g1"`, 304, the meta is written again |

Why the old cases did not kill: in each old L2 case the fake clock and TALON_NOW are the same (1792065600), so `now` and `real` give the same age.
