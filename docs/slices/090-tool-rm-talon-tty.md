# 090 `tln tool rm talon` prompt on a terminal (L3)

Phase: P1. Status: done (accepted by the manager, 2026-11-02). The case passes at once: the slice has no code step.

Source: `PLAN-P1.md` 5b, slice 053 F5 ("the prompt of `tln tool rm talon` has no L3 case on a tty"). The prompt has L0 (`TalonRemoveTest`), L2 (`tool/rm2-options` runs 3 and 4) and L3 `--dry-run` (`tools/rm1-remove-talon`) cases. No L3 case runs it with a pseudo terminal.

## 1. Rules

| Rule | Text (short) |
| --- | --- |
| R-NI10 | The prompt of `tool rm talon`: the default is option 1 (keep the tools, remove the rest) |
| R-NR2 | The prompt shows the screen of the design, with the default |
| R-S5 | `tool rm talon` asks what to remove, then removes it |
| R-RM3 | Option 1 keeps the tools and removes Talon, the compilers and the Talon data |
| R-RM5, R-RM6, R-RM7, R-RM9, R-RM10 | the same removal as option 1 of `tools/rm1-remove-talon` (same tree diff) |

## 2. Test

| Layer | Case | Rule ids |
| --- | --- | --- |
| L3 | `tests/scenarios/tools/rm3-remove-talon-tty` (new, tag `tty`). The home of `tools/rm1-remove-talon`. `given/answers` is `x`, then an empty line: the answer `x` is no option, so the prompt is asked again, then Enter takes the default, option 1. The screen shows twice. | R-NI10, R-NR2, R-S5, R-RM3, R-RM5, R-RM6, R-RM7, R-RM9, R-RM10 |

The pattern is `cache/cl2-prompt-tty`: stdout and stderr are one stream, so `expect/stdout` has the screen, the prompt line and the result. The typed text does not show. With a person there is no answer line (the line `removing Talon, the compilers and the data, keeping the tools` is for the run with no person, `tools/rm1-remove-talon` run 2).

## 3. Result

`tests/run.sh tools/rm3-remove-talon-tty`: `scenarios: 1 passed, 0 failed` on the first run. The expected files were made with `UPDATE=1` (a new case: the first run of the real `tln`), and each was then read against the design:

| File | Check against the design |
| --- | --- |
| `expect/stdout` | The screen is the example of CLI 6.5 (the 4 options, the default mark, the 3 groups with sizes, the text `they run without Talon`). The size column has the sizes of this home (81 B, 861 B, 124 B: the same as the `--dry-run` case). The prompt asks twice (the answer `x`). The result is the table of option 1 (`removed`, `kept`) and the move of `roc.old` |
| `expect/tree.diff` | The same file as `tools/rm1-remove-talon` (`cmp` says equal): option 1, the same removal |
| `expect/exit` | `0` |
| `expect/stderr` | none (the tty case has one stream) |

So no code step is needed: the prompt on a real terminal works as the design says.

## 4. Output

No new text. The expected output is the text that exists (the L2 and L0 cases).

## 5. Out of scope

| Item | Reason |
| --- | --- |
| The answer `4` (Cancel) on a terminal | L2 `tool/rm2-options` run 3 has it. The case keeps one command, so the tree diff is the one of `rm1-remove-talon` |
| The answers `2` and `3` | L2 `tool/rm2-options` runs 1 and 2 (flags) and the L0 `choice_of` table |

## 6. Questions

None.

## 7. Revert check

One hand mutation of the code, for this gap test: `TalonRemove.prompt` has `default: Option(3)` in place of `Option(1)` (Enter is "Talon only"). Result: the case fails (stdout: `Choose [1-4, default 3]`, the compilers and the Talon data are `kept`, 3 lines `kept <id>: <path>`). The mutation was built from a copy of `HEAD` (`cli/` and `packages/` in the scratchpad), because `cli/lib` of the working tree did not build at that time (the work of another agent in `Intent.roc`, `ToolBin.roc`). The working tree was not changed.

New files: `tests/scenarios/tools/rm3-remove-talon-tty/` (listed in `research/slice-090-revert/before/NEW.txt`). No file existed before.
