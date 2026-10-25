# Mutations of 057c (code agent)

Script: `research/slice-057-revert/agent-mutate-c.py`. L0 = `roc test tests/unit/l0-7.roc`. L2 = `tests/commands/run.sh run/rn3`. L3 = `tests/run.sh run/rn1`. Each mutation is one exact replace, then the original text is put back (sha256 checked by the script). A mutation with a compiler error or warning is INVALID.

| Id | Mutation | Result | Failing test |
| --- | --- | --- | --- |
| c1 | a `.roc` word is checked before a `[tools]` key (order of the first word) | caught | L0 5 (RunscriptTest.roc:172) |
| c2 | a key with no `url` is kind `Internal`, not exit 14 | caught | L0 11 (324) |
| c3 | the consent stop keeps `--allow-downloads` (no `RunTools.stop`) | caught | L2 `rn3-tools` run 5 (stderr) |
| c4 | the `x` entry of the `url` is never found: every tool step builds (no reuse) | caught | L2 `rn3-tools` (Fx calls) |
| c5 | a build does not add its new entry to the known entries | caught | L2 `rn3-tools` |
| c6 | the `PATH` note is printed for a key that is not on `PATH` | caught | L2 `rn3-tools` run 9 |
| c7 | the args of a tool step are lost | caught | L2 `rn3-tools` (Fx calls) |
| c8 | the same as c4, seen by L3 `run/rn1` | NOT CAUGHT by L3 | `ToolsStep.ensure!` finds the entry itself, so the output of L3 does not change (only the calls of L2 differ). Caught by L2 (c4) |

Caught 7 of 8 mutations (c8 repeats c4 at another layer; c4 catches it). c5 was INVALID at the first try (a warning), then changed.
