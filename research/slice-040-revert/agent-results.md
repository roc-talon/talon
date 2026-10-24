# Slice 040: revert check of the code agent

Method: `agent-mutate.py` restores `code-final/`, makes one small change, runs only the named tests (`roc test tests/unit/outdated.roc` for l0, `tests/commands/run.sh outdated` for l2), restores `code-final/`. Log: `agent-mutate.log`. At the end `sha256sum -c code-final.sha256` (from the repo root) is OK.

| Id | Mutation | Failed test | Result |
| --- | --- | --- | --- |
| M1 | `wanted` ignores the ranges | l0 expect 2, l2 `od2-edges` run 4 | caught |
| M2 | min-release-age 0 | l0 expect 2, l2 `od1-table` | caught |
| M3 | `latest` stays in the series of `current` | l0 expect 2, l2 `od1-table` | caught |
| M4 | `behind` ignores `latest` | l0 expect 4, l2 `od1-table` | caught |
| M5 | the compiler list and the db are read when no row is behind | l2 `od1-table` run 4 (`calls.log`) | caught |
| M6 | `Vars.build` over the shown members only (Q8) | l2 `od2-edges` run 4 (`wanted` 2.2.0 in place of 2.1.5) | caught |
| M7 | an end that is no real fact has no `?` | l0 expect 3, l2 `od1-table`, `od2-edges` | caught |
| M8 | the current member does not limit the members | l2 `od2-edges` (`calls.log`) | caught |
| M9 | the project is not recorded | l2 `od1-table`, `od2-edges` (`tree.diff`) | caught |
| M10 | the index is read for the groups of members that are not shown | l2 `od2-edges` runs 2, 3 (`calls.log`) | caught |
| M11 | a fixed host that 2 groups have is listed twice (no dedupe) | none | not caught: test gap |
| M12 | no real pass gives `-` in place of `none known` | l0 expect 3, l2 `od1-table` | caught |
| M13 | an empty compiler list gives `none known` in place of `-` | l0 expect 3, l2 `od1-table` run 6 | caught |
| M14 | the column padding is 1 space | l0 expect 4, l2 `od1-table` | caught |
| M15 | alias and `current` of the first use of any member, not of the member | none | not caught: test gap |

Two first tries did not compile (M6 used `named` before its definition, M8 left `named` unused: a warning). They were written again and run again; the table has the second runs.

Caught 13 of 15. No mutation that is an equivalent change.

| Id | Why a test gap | Test that would catch it |
| --- | --- | --- |
| M11 | No L2 case has 2 groups on one `Fixed` host in one member. `Outdated.text` gets the host list as given, so L0 cannot see it either. The design says "no repeat" (slice 040 section 3, rule 7). | An L2 case with 2 entries on `example.org` (2 packages, 2 groups) with the line `fixed: example.org ...` once |
| M15 | In `od2-edges` both members have `json` with the same alias and the same version, so the first use of the member and the first use of all members are equal. Rule 1 of section 3 says "of the first use in that member". | A workspace where member a has `json` 2.1.0 and member b has `json` 2.0.0 (or another alias): b must show its own `current` |
