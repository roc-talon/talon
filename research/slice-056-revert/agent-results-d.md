# Slice 056d, mutations of the code agent

Script: `research/slice-056-revert/agent-mutate-d.py`. Each mutation changes one place of `cli/lib`, runs the one test that must see it, and puts the file back (checked with `cmp` against `code-final-d/` and `sha256sum -c code-final-d.sha256`).
Baseline: all tests pass (L0 `l0-8`, all L2 cases).

| # | Mutation | Test | Result |
| --- | --- | --- | --- |
| D1 | GC does not keep the package dirs that `[tools]` of a live project names | L2 `gc5-project-tools` | caught |
| D2 | GC does not keep the `x` entries that `[tools]` of a live project names | L2 `gc5-project-tools` | caught |
| D3 | `held_hashes`: the walk does not stop at the file with `[workspace]` | L0 `ToolsplanTest` 11 | caught |
| D4 | `held_hashes`: the walk stops at the first file that was read (a project that is no member keeps nothing above it) | L0 `ToolsplanTest` 11 | caught |
| D5 | `held_paths`: a path twice, not in byte order | L0 `ToolsplanTest` 11 | caught |
| D6 | the take-over always moves (NC3: no copy) | L2 `tk2-takeover-project` | caught |
| D7 | the take-over gets no held hash | L2 `tk2-takeover-project` | caught |
| D8, D8b | `Gc.projects`: a `talon.toml` entry is judged as a header (it goes) | L2 `gc5-project-tools`, L0 `ToolsplanTest` 15 | caught, caught |
| D9 | GC reads `[tools]` only when a package dir can go (an `x` entry alone does not start the read) | all L2 cases of `gc/` | NOT CAUGHT: every case with a live project has a package dir that can go too |
| D10 | GC reads `[tools]` of a project that is not live | L2 `gc5-project-tools` | caught |

11 mutations, 10 caught, 1 not caught (D9: a gap of the tests).
