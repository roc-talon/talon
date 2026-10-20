# Revert check of slice 006b (TW12)

Each row is one change of a private reference implementation (deleted after the run: `cli/lib/` has the stubs again). `mutate.py` is the record of the changes. A compile error is not a catch.
Result: 31 of 31 caught. Two runs: the first (20 rows, before the answer Q1) and the second (the rows E1 to E6 and W1 to W7 for the import strings and the walk, and all old rows again on the new reference). The first run of T4 was not caught (an absolute path with `..` was not in the rows): the row `/q/../x.roc` was added to `tests/unit/rebase.roc`, and T4 was caught after it.

| Id | Rule | Change | Caught by |
| --- | --- | --- | --- |
| P1 | Q1, R-RC4 | exit 128 plus a fault signal is a crash again | L0 `probe` |
| G1 | Q4 | `*` crosses `/` | L0 `rebase` |
| G2 | Q4 | `**/` needs at least one segment | L0 `rebase` |
| G3 | Q4 | `?` matches `/` | L0 `rebase` |
| G4 | Q4 | the glob ends and the path has more characters: still a match | L0 `rebase` |
| T1 | R-LD4 | a path that stays in the app dir is made absolute | L0 `rebase` |
| T2 | R-LD4 | the prefix is not a whole segment (`/p/app-two`) | L0 `rebase` |
| T3 | R-LD4 | out and in again: the target, not the place in the copy | L0 `rebase` |
| T4 | R-LD4 | an absolute path is normalized | L0 `rebase` (after the new row) |
| T5 | R-LD4 | leaving the app dir needs 2 steps up | L0 `rebase` |
| T6 | R-LD4 | the depth of `file_dir` below `from` is 0 | L0 `rebase` |
| F1 | R-LD4 | the glob is ignored | L0 `rebase` |
| F2 | R-H1 | the result has the files that did not change | L0 `rebase` |
| F3 | R-H1 | each header entry is changed, not only the path entries | L0 `rebase` |
| F4 | R-LD4 | `file_dir` of `sub/x.roc` is `from` | L0 `rebase` |
| E1 | R-LD4, Q1 | an import line is any line that has `import "` (an indented line, a comment) | L0 `rebase` |
| E2 | R-LD4, Q1 | the import file is not changed | L0 `rebase` |
| E3 | R-LD4, Q1 | the import file uses `from` as `file_dir` (a file in `sub/`) | L0 `rebase` |
| E4 | R-LD4, Q1 | `files` makes no import change | L0 `rebase` |
| E5 | R-LD4, Q1 | `files` makes the import change on the old text (the header change is lost) | L0 `rebase` |
| E6 | R-H1, Q1 | the text after the closing quote of an import line is lost | L0 `rebase` |
| W1 | R-LD4, Q1 | the walk of the copy has only the top dir | L2 `in1-flow` |
| W2 | R-LD4, Q1 | the glob of the ladder is `*.roc` | L2 `in1-flow` |
| W3 | R-LD4, Q1 | the ladder reads the project file of the copy too | L2 `in1-flow` |
| W4 | R-LD4, Q1 | the ladder writes only the header | L2 `in1-flow` |
| W5 | R-LD4, Q1 | the paths of the walk are not sorted | L2 `in1-flow` |
| W6 | R-LD4, Q4 | the ladder gives a wrong `from` | L2 `in1-flow` |
| W7 | R-LD4, Q1 | `read_files` with an empty list | L2 `in1-flow` |
| C2 | D6, C2 of 007 | the kind comes from the first candidate in page order | L2 `in1-flow` |
| M1 | R-LF3, R-BL6 | `--no-check` gives `check: Passed` in the outcome | L2 `in1-flow` (run 5) |
| M2 | R-LF3, R-BL6 | `--no-check` gives `build: Passed` in the outcome | L2 `in1-flow` (run 5) |
