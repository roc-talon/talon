# 066 Split the L2 test app

Phase: P1. Status: done

Slice 066 splits `tests/commands/main.roc` (648 lines) into modules of at most 490 lines. It is test code only: no behavior, no file under `cases/`, no expected output changes. There is no code agent and no new test. The pre-slice copy of `main.roc` is in `research/slice-066-revert/before/` (with `NEW.txt`).

## 1. Scope

| Item | Decision |
| --- | --- |
| Moved parts | The entries `prompt`, `harness`, `resolve` and `db`, with their own helpers, and the shared helpers `words`, `file_lines!`, `report!` |
| Kept in `main.roc` | `main!` (the entry table), and the entries `project`, `locks`, `index`, `fetch`, `commands`, `zig` |
| Module style | A type module `Name :: [].{ ... }` with methods, as `FakeBase` and `FakeDb` |
| Renames | `prompt_entry!`, `resolve_entry!`, `db_entry!`, `harness_entry!` are now `entry!` in their module (`L2Prompt.entry!`, and so on). No other change of text or logic. |
| Scripts | `scripts/test.sh` and `scripts/rules.sh` need no change: `test.sh` builds `tests/commands/main.roc` only, and `roc fmt --check` finds files with `find`. |

## 2. Modules

| File | Lines | Holds |
| --- | --- | --- |
| `tests/commands/main.roc` | 337 | `main!`, entries `project`, `locks`, `index`, `fetch`, `commands`, `zig` |
| `tests/commands/L2Util.roc` | 22 | `words`, `file_lines!`, `report!` |
| `tests/commands/L2Prompt.roc` | 101 | entry `prompt`, `parse_line`, `show` |
| `tests/commands/L2Harness.roc` | 53 | entry `harness` |
| `tests/commands/L2Resolve.roc` | 111 | entry `resolve` |
| `tests/commands/L2Db.roc` | 65 | entry `db` |

## 3. Verify

| Check | Result |
| --- | --- |
| `roc check tests/commands/main.roc` | 0 errors, 0 warnings |
| `roc fmt --check` of the 6 files | exit 0 |
| `scripts/test.sh` (all layers) | pass: check, fmt, l0, l2, l3, selftest, l1 |

## Close (manager, 2026-10-25)

| Check | Result |
| --- | --- |
| `sha256sum -c research/slice-066-revert/code-final.sha256` | 7 files OK |
| Largest module in `tests/commands/` | 348 lines (`FakeFiles.roc`); `main.roc` 337 |
| `scripts/test.sh` | Passed (agent run, all layers) |
