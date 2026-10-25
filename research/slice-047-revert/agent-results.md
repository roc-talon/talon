# Slice 047 revert check (code agent)

Script: `research/slice-047-revert/agent-mutate.py`. Each mutation breaks `cli/lib` in one small way, runs only the test that must see it (L0 `l0-5` or L2 `tool/ti3-compiler` and `tool/ti4-nothing`), and puts the file back. After the run `sha256sum -c research/slice-047-revert/code-final.sha256` is OK (the code is the same as before the mutations).

| # | Mutation | Test that saw it | Result |
| --- | --- | --- | --- |
| 1 | the digest ignores the hashes of the header | L0 ToolCompilerTest 2 (l0-5) | caught |
| 2 | the evidence key has the target `any` | L0 ToolCompilerTest 2 and 3 (l0-5) | caught |
| 3 | D-E3: `--yes` wins over `--roc installed` | L0 ToolCompilerTest 5 (l0-5) | caught |
| 4 | D-E3: a flag removes the evidence pass | L2 ti3-compiler (runs 3 and 6) | caught |
| 5 | the checks run one by one (a `probes!` call each) | L2 ti3-compiler (`probes 4` lines) | caught |
| 6 | the builds go on after the first pass (no `break`) | L2 ti3-compiler run 2 (D is built) | caught |
| 7 | the prompt after option 2 offers option 2 again | L2 ti3-compiler run 4 | caught |
| 8 | no person after option 2: the cancel text, not the list | L2 ti3-compiler run 3, ti4-nothing run 2 | caught |
| 9 | the build row of a failed try is not written | L2 ti3-compiler runs 2, 3 (`db_write` calls) | caught |
| 10 | `tty!` is called at the start (not lazy) | L2 ti3-compiler, ti4-nothing (a `tty` line in `calls.log`) | caught |
| 11 | review 2 (C3): the platform line prints again after a failed option 2 and a download | L2 ti3-compiler run 7 | caught |

11 mutations, 11 caught, 0 not caught.
