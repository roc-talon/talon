# Slice 018b: revert check of the code (TW12)

Script: `research/slice-018b-revert/code-mutate.py`. Output: `code-run.txt`. The copy of the changed files before the mutations: `code-after/`.
The script restores from the copy before each mutation and after it. At the end the files are equal to the copy (content and mode): yes.

Result: caught 23 of 24.

| Id | Mutation | Caught by |
| --- | --- | --- |
| E1 | pin is another tag | ciscan pin |
| E2 | ROC has the tag text | ciscan pin |
| G1 | get-roc.sh shebang `#!/bin/bash` | ciscan pin |
| G2 | wrong Windows target name | ciscan pin |
| G3 | no sha256 check in get-roc.sh | not caught (static rows only read the word `sha256`). Checked by hand: a fake `gh` with a wrong digest gives exit 1 and `sha256 mismatch` |
| T1 | `bc` back in `over()` | ciscan portable |
| T2 | `over()` reversed | selftest row `budget` |
| T3 | test.sh shebang | ciscan portable |
| R1 | no skip of tag `net` in tests/run.sh | selftest row `net tag` |
| R2 | `NET` on by default | selftest row `net tag` |
| R3 | tests/commands/run.sh shebang | ciscan portable |
| C1 | Windows job runs all steps | ciscan fast |
| C2 | test step has no `shell: bash` | ciscan fast |
| C3 | no sysctl for bubblewrap | ciscan fast |
| C4 | `OPT: speed` in the fast job | ciscan fast |
| C5 | binary cache key without `runner.os` | ciscan pin |
| C6 | binary cache with `restore-keys` | ciscan pin |
| C7 | macOS step without diffutils | ciscan portable |
| C8 | `actions/checkout@main` | ciscan yaml |
| C9 | no get-roc step, a local path | ciscan pin |
| N1 | `NET: 0` in nightly | ciscan nightly |
| N2 | `push` trigger in nightly | ciscan nightly |
| N3 | `contents: write` | ciscan yaml |
| N4 | package cache in nightly | ciscan nightly |

Hand checks of `scripts/get-roc.sh` (real release `nightly-2026-10-14-38a3029`, 74 MB, 7 s): installs to `$WORK/nightlies/<tag>/roc`, prints the path, second run finds the file, `roc version` prints the tag. Unknown tag: exit 1 and `no release`. Wrong digest (fake gh): exit 1.
