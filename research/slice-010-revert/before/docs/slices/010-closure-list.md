# 010 Closure walk and `list`

Phase: P0. Status: scope

This is a stub of the scope. The scope agent of slice 009 split the first slice 009 into 009 (`update`, `update -i`, `verify`), 010 (this file) and 011 (`why`). The full scope of this slice is written by its own scope agent. This file keeps what slice 009 found, so nothing is lost. The manager review of the split is in `009-update-verify.md`, "Review of the scope". Q9 to Q15 have the defaults of that review. They can change when the slice is scoped.

## Rules (P0 parts)

| Group | Ids | Note |
| --- | --- | --- |
| Commands | R-CM9 (`list`, `ls`, `--tree`), R-CM2 ("fetch the closure" part of `install`), R-CM19 (`ls`) | |
| Closure | R-H4 (the `foreign` mark), R-H7 (a path entry joins the closure, its URL entries join MVS, its `import` lines join the scan of `remove`), R-SP21, R-AL2 (the walk part), R-FE1 (the hash check of the deeper packages), R-OV1 (the `raised` mark with an override) | The walk fetches level by level, then calls `Mvs.select` of `roc-app-header` (`Mvs.roc`, release 0.1.0). The `deps` function of `Mvs.select` is pure, so the effect part reads the headers first. |
| Constraints | R-C8 (a warning for 2 series of one package in the closure) | |
| Flags | R-FL7 (`list` rejects the resolve flags, tested by slice 001), R-FL6 (`--file`) | |

## Items that earlier slices moved here

| Item | From |
| --- | --- |
| R-H7: the `import` lines of a path entry join the scan of `remove` | Slice 008, "Out of scope" |
| R-C8 and the closure walk | Slices 005, 006, 007 |
| `Resolve.Request` entities of `update` and `why` do not hold transitive packages (`entities_of`, `cli/lib/Resolve.roc:620`) | Slice 004 (P6), slice 009 |
| `install` fetches the header URLs only (`frozen!`, `cli/lib/Resolve.roc:272`), R-CM2 says the closure | Slice 009 |
| The notes of Lookup (`via <alias>`, R-SC14) need the closure | Slice 004 |

## Questions of the split review (the answers are the defaults)

| # | Question | Default |
| --- | --- | --- |
| Q9 | The mark `raised` (R-CM9): a mark of the package or of the edge? | A mark of the package, with the lowest named version: `raised from 1.2.0` |
| Q10 | `list` with `--offline` and a package that is not in the cache | Exit 15 with the `Fetch` failure, no partial list |
| Q11 | Which commands print the R-C8 warning? | Each command that walks the closure (`install`, `update`, `verify`, `list`): one line on stderr for each package, no effect on the exit code. Text: `warning: <name> has 2 series in the closure: <series> via <alias>, <series> via <alias>. The types of the 2 series are different types.` |
| Q12 | The closure fetch of `install` with `--dry-run` | It runs (a fetch writes only the cache) |

## Size

About 360 lines of new code (the estimate of slice 009): `Closure` (pure, 150), the walk (70), `Listing` (120), the R-C8 line (20).

## Next step

The scope agent of this slice writes the full scope, the stubs and the tests (`docs/agents/BRIEF-tests.md`). Slice 009 adds `Probe.replace_args` and `Ladder.verify!`: they are not used here.
