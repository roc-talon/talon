# Mutations of 057b (code agent)

Script: `research/slice-057-revert/agent-mutate-b.py`. L0 = `roc test tests/unit/l0-7.roc`. L2 = `tests/commands/run.sh run/rn1 run/rn2`. Each mutation is one exact replace, then the original text is put back (sha256 checked by the script). A mutation that gives a compiler error or warning is INVALID (the script says so). In L0 the expect 11 is red until 057c, so "caught" there means that a row of 8, 9 or 10 fails too.

| Id | Mutation | Result | Failing test |
| --- | --- | --- | --- |
| b1 | the walk does not stop at a root or a standalone file (NC5) | caught | L0 8 (RunscriptTest.roc:257) |
| b2 | no NC4 probe (`Need` is never asked) | caught | L0 8 (257) |
| b3 | the R-PD9 record is not made | caught | L2 `rn1-scripts`, `rn2-words` (calls and `projects.json`) |
| b4 | a standalone file records its `talon.toml`, never its `main.roc` (NC1) | caught | L2 `rn1-scripts`, `rn2-words` |
| b5 | the list (no name) takes the first file, also with no script | caught | L0 8 (257) |
| b6 | a `roc` step loses its args | caught | L2 `rn2-words` |
| b7 | a failing step does not stop the run | caught | L2 `rn1-scripts`, `rn2-words` |
| b8 | a member file has its own `[tools]` table (not the root's, OP4) | caught | L0 8 (257) |
| b9 | `tln run -- words` with no name is accepted | caught | L2 `rn1-scripts` run 34 |

Caught 9 of 9. The first run of b4 had an unused variable (INVALID): the mutation was changed, then caught.
