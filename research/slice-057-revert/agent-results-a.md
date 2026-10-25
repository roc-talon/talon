# Mutations of 057a (code agent)

Script: `research/slice-057-revert/agent-mutate-a.py`. Test: `roc test tests/unit/l0-7.roc` (RunscriptTest), and `tests/run.sh fx/px2` for the last row. Each mutation is one exact replace, then the original text is put back (sha256 checked by the script).

| Id | Mutation | Result | Failing test |
| --- | --- | --- | --- |
| a1 | a quote splits a word (`a"b c"d`) | caught | L0 3 (RunscriptTest.roc:75) |
| a2 | an unclosed quote is accepted | caught | L0 3 (75), L0 2 plan unc row (139) |
| a3 | args of `--` go to every step | caught | L0 4 (139) |
| a4 | the cycle check is off | caught | L0 4 (139) |
| a5 | `.roc` word with no `--` | caught | L0 5 (172) |
| a6 | a `[tools]` key does not shadow `roc` (order of the first word) | caught | L0 5 (172) |
| a7 | `exec_in!`: a signal gives n, not 128 + n | caught | L3 `fx/px2-real-fx-exec-in` |

Caught 7 of 7. Rows 257, 296, 315, 324 of RunscriptTest (L0 8 to 11) are red before and after: they belong to 057b and 057c.
