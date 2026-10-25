# Revert check of slice 043 (code agent)

| Id | Mutation | Result |
| --- | --- | --- |
| A1 | update with no names frees a patched entry | caught (exit 1) by test tests/unit/l0-2.roc |
| A2 | a held patched entry is movable | caught (exit 1) by test tests/unit/l0-2.roc |
| A3 | tln install does not rebase a stale patch (Patched.need) | caught (exit 1) by test tests/unit/l0-1.roc |
| A4 | a diff that does not apply is no failure | caught (exit 1) by test tests/unit/l0-1.roc |
| A5 | install --frozen has no stale check (exit 14) | caught (exit 1) by scripts/test.sh l2 |
| A6 | the proxy does not stop on a stale patch | caught (exit 1) by scripts/test.sh l2 |
| A6b | the proxy does not stop on a stale patch (real launcher) | caught (exit 1) by scripts/test.sh l3 |
| A7 | TALON_PROXY=0 checks a stale patch | caught (exit 1) by scripts/test.sh l2 |
| A8 | the baseline check gets the pairs of the candidate | caught (exit 1) by test tests/unit/l0-1.roc |
| A9 | the proxy flags go after -- | caught (exit 1) by test tests/unit/l0-1.roc |
| A10 | the Guard of the base write has no span of the [patch] entry | caught (exit 1) by scripts/test.sh l2 |
| A11 | --dry-run replaces the copy | caught (exit 1) by scripts/test.sh l2 |
| A12 | the diff is made against the new release, not the base | caught (exit 1) by scripts/test.sh l2 |
| A13 | base is not set to the new hash | caught (exit 1) by scripts/test.sh l2 |
| A14 | the candidate probes get the copy, not the temp tree | caught (exit 1) by scripts/test.sh l2 |
| A15 | the temp root is not deleted | caught (exit 1) by scripts/test.sh l2 |

Code after the runs: same as code-final (sha256sum -c: all OK)
