# Slice 037 revert check (code agent)

Run: `python3 -I research/slice-037-revert/agent-mutate.py` from the repo root. Log: `agent-mutate.log`. 10 mutations, filtered runs only.

| Id | File | Change | Test | Result |
| --- | --- | --- | --- | --- |
| P1 | `cli/lib/ProbeRange.roc` | first round asks the oldest releases | L0 `proberange` | caught |
| P2 | `cli/lib/ProbeRange.roc` | picks are not the quartile places | L0 `proberange` | caught |
| P3 | `cli/lib/ProbeRange.roc` | a hang or a crash is asked again | L0 `proberange` | caught |
| P4 | `cli/lib/ProbeCmd.roc` | one unknown end gives no exit 12 | L0 `probecmd` | caught |
| P5 | `cli/lib/ProbeBundle.roc` | a bundle is unbundled when its dir is there | L2 `probe/pc1-targets` | caught |
| P6 | `cli/lib/ProbeSearch.roc` | the budget does not count started probes | L2 `probe/pc2-range` | caught |
| P7 | `cli/lib/ProbeSearch.roc` | a compiler that is not installed is asked | L2 `probe/pc2-range` | caught |
| P8 | `cli/lib/ProbeUnit.roc` | the build runs after a failed check | L2 `probe/pc1-targets` | caught |
| P9 | `cli/lib/ProbeUnit.roc` | a known fact is not replaced | L2 `probe/pc1-targets` | caught |
| P10 | `cli/lib/ProbeSearch.roc` | the known facts are not read | L2 `probe/pc2-range` | caught |

The first version of P8 gave a compile error (unused variable). It was written again and is counted once. After the run the 7 files equal `code-final.sha256`. No mutation survived.
