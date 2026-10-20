# Revert check of the code of slice 006b (TW12, code agent)

`code-mutate.py` makes each change in the real code (`cli/lib/`), runs the tests, and puts the file back. A compile error is not a catch. After the run, `cli/` was compared with a copy that was made before the run (`diff -r`): no difference.

Result: 26 of 27 caught. Not caught: C3.

| Id | Rule | Change | Result |
| --- | --- | --- | --- |
| P1 | R-RC4 | exit 128 plus a fault signal is a crash again | caught by l0:probe |
| G1 | R-LD4 | `*` crosses `/` | caught by l0:rebase |
| G2 | R-LD4 | `**/` needs one segment at least | caught by l0:rebase |
| G3 | R-LD4 | `?` matches `/` | caught by l0:rebase |
| G4 | R-LD4 | the glob ends and the path has more bytes: still a match | caught by l0:rebase |
| T1 | R-LD4 | a path that stays in the app dir is changed | caught by l0:rebase |
| T2 | R-LD4 | the prefix is not a whole segment | caught by l0:rebase |
| T3 | R-LD4 | out and in again: the target, not the place in the copy | caught by l0:rebase |
| T4 | R-LD4 | an absolute path is resolved | caught by l0:rebase (second run: the first mutation did not compile) |
| T6 | R-LD4 | the start depth of a file in `sub/` is 0 | caught by l0:rebase |
| F1 | R-LD4 | the glob is not used | caught by l0:rebase |
| F2 | R-H1 | an unchanged file is in the result | caught by l0:rebase |
| F3 | R-H1 | all rows of the header are rebased, not only `Path` | caught by l0:rebase |
| F4 | R-LD4 | `file_dir` of a file in `sub/` is the app dir | caught by l0:rebase |
| E1 | R-LD4 | an import line may be anywhere in a line | caught by l0:rebase |
| E2 | R-LD4 | the import file is rebased from the app dir, not from `file_dir` | caught by l0:rebase |
| E3 | R-LD4 | the import strings are changed on the old text, so the header change is lost | caught by l0:rebase |
| W1 | R-LD4 | the walk stops after the first level | caught by l2:install/in1-flow (install/in1-flow) |
| W2 | R-LD4 | the glob of the ladder is `*.roc` | caught by l2:install/in1-flow (install/in1-flow) |
| W3 | R-LD4 | the project file is read from the copy too | caught by l2:install/in1-flow (install/in1-flow) |
| W4 | R-LD4 | the other changed files are not written | caught by l2:install/in1-flow (install/in1-flow) |
| W5 | R-LD4 | the `.roc` files are not sorted | caught by l2:install/in1-flow (install/in1-flow) |
| W6 | R-LD4 | `from` is not the dir of the member file | caught by l2:install/in1-flow (install/in1-flow) |
| W7 | R-LD4 | `read_files!` is called also with no file | caught by l2:install/in1-flow (install/in1-flow) |
| W8 | R-H7 | the changed header of `Rebase.files` is not used | caught by l2:install/in1-flow (install/in1-flow) |
| C2 | R-AD32 R-AD33 | the kind comes from the first candidate, not the newest | caught by l2:install/in1-flow (second run: the first mutation had an unused variable) |
| C3 | R-AD32 R-AD33 | a tie takes the last candidate, not the first | NOT CAUGHT |

C3: no L2 case has two candidates of one URL form with the same `published_at`, so the rule "a tie keeps the first" is fixed by the tests of `Index.new_entry` (L0 `index`) only, not by the test of `Resolve.prepare!`. The slice has no row for it: it is a gap for the review (a new test is for the test agent, TW18).
