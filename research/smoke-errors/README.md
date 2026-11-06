# Smoke errors: where `roc build` prints a machine error (Design Q548, Resolution R-SM7)

Question (G-C178): how does Talon find a machine error of R-SM7 in the output of a smoke build: stdout or stderr, a substring or an exact text?

Run: `./run.sh`. It builds the smoke apps of `research/smoke-app/apps/` with the compilers and the package cache of `conformance/host-link/` (canonical paths, Design Q15). It keeps stdout, stderr and the exit code of each build in `out/` (not for VCS).

## Results (2026-11-03, Linux x86_64)

| Case | Nightly | Exit | stdout | stderr, the lines after the headline |
| --- | --- | --- | --- | --- |
| basic-webserver 0.17.0, `x64win` | 10-06 | 1 | empty | headline `── ✗ linker failed ──...`, `The linker failed while building for target x64win.`, then the line `Error: WindowsSDKNotFound` |
| roc-ray 0.10.0, `x64win` | 10-06 | 1 | empty | a `roc version mismatch` report first, then the same 3 lines as above |
| basic-cli 0.29.0, `x64mac` | 10-12 | 1 | empty | `ld64.lld: error: library not found for -lSystem` and more `ld64.lld: error:` lines. No `Error: <name>` line. |
| basic-cli 0.29.0, `x64win` | 10-12 | 1 | empty | `lld-link: error: <root>: undefined symbol: mainCRTStartup` and more. No `Error: <name>` line. |
| basic-cli 0.29.0, `x64nonesuch` | 10-12 | 1 | empty | headline `invalid target`, then the list of valid targets |
| basic-cli 0.29.0, `arm64glibc` | 10-12 | 1 | empty | headline `unsupported target`, then the targets of the platform |

## Findings

| Finding | Effect on the design |
| --- | --- |
| The machine error is on stderr, on a line of its own: `Error: WindowsSDKNotFound`. stdout is empty in each fail. | R-SM7: Talon looks for a stderr line that is exactly `Error: <name>` for a name of the list. Not a substring: the text of a report can hold the name. |
| A report before the error (`roc version mismatch`) does not change the line | The line can be anywhere in stderr |
| The mac and win link errors of basic-cli are `ld64.lld: error:` and `lld-link: error:` lines, and they are platform faults (the files of the platform are missing), not machine errors | They are real `fail` results, as `research/smoke-app/` found |
| `invalid target` and `unsupported target` are faults of the target choice, not of the machine | Talon builds only a target of the platform (R-SM3 row 1), so they do not occur |

## Not tested here

| Item | Why |
| --- | --- |
| A missing system linker | roc links with its own `lld` (`research/smoke-app/`), so no system linker is needed and the case cannot be made on this machine |
| `WindowsSDKNotFound` on the pinned nightly `nightly-2026-10-14-38a3029` (`scripts/env.sh` `ROC_TAG`) | No platform in the cache of `conformance/host-link/` has an `x64win` host that needs the SDK and builds with that nightly. The 10-06 text is the only one measured. |
| A real Windows machine with an SDK | No such machine here |
