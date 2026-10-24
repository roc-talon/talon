# The roc object cache gives a bad build (slice 038, 2026-10-24)

Compiler: roc nightly-2026-10-14-38a3029, `--opt=dev`, the L2 test app `tests/commands/main.roc` (basic-cli 0.25.0), Linux x86_64, 24 cores.

## 1. Finding

The first note of slice 038 said: "the L2 app is bad after a source change". The repro shows a wider rule:

| Rule | Evidence |
| --- | --- |
| A `roc build --opt=dev` that reads objects (`objects-v7`) that an earlier build wrote gives a bad app. | `seq.sh`: build 1 (empty cache) passes, build 2 of the SAME sources with the same cache crashes in 33 cases |
| A source change is not needed. A comment edit, a dead function and a body edit give the same result. | `repro-l2.sh dead`, `body`, `comment`; `repro-l2.sh none` (no edit) |
| An object of ANOTHER app is enough. | `cross.sh cli/main.roc`: build `cli/main.roc` (tln) first, then the L2 app: it crashes. `cross.sh "cli/fxprobe.roc cli/flowprobe.roc"` first: the L2 app passes (they share no object with it) |
| It is not a race and not a thread count. | The same with `--jobs=1` (`BJOBS=1`) |
| Only the dev objects matter. | `CLEAR=dev` (remove `objects-v7/x64musl-dev`) fixes the next build. `CLEAR=comptime` and `CLEAR=none` do not |
| Cached modules (`can`, `mod`, `pair`) are not the cause. | They stay in the cache in every passing run below |

The old slice 038 steps (reference to stubs) are not needed. `CLEAR=half repro-l2.sh none` (build, build again with no edit: crash; remove every second dev object file; build: 85 pass) gave a good build once. This is one run: it does not show that `prune_roc_objects` is safe, and the fix does not rely on it.

## 2. Steps (no deleted reference)

```
research/roc-object-cache/seq.sh 2          # build the L2 app twice, same sources, one cache; run the 93 cases after each build
research/roc-object-cache/repro-l2.sh dead  # build A, add a dead function to cli/lib/Ranges.roc, build B (same cache), then B2 with objects-v7 removed
```

The scripts use `research/roc-object-cache/tree/` (a copy of `cli/`, `packages/resolve` and the L2 `.roc` files of the red state of slice 038) and a new cache in `tmp*/`. The package downloads are copied from `.work/cache/roc/packages`, so no network is needed. The cases run with the repo `tests/commands/run.sh` and `L2BIN`.

Result of `repro-l2.sh dead` (the numbers of `body` and `comment` are the same):

| Build | Time | Cases (93) | Crashes |
| --- | --- | --- | --- |
| A (empty cache) | 11.1 s | 85 pass, 8 fail | 0 |
| B (one dead function added, same cache) | 4.8 s | 53 pass, 40 fail | 34 (segmentation fault, exit 139) |
| B2 (`objects-v7` removed) | 8.0 s | 85 pass, 8 fail | 0 |

Note: 8 cases fail in the good run. They are the stubs of slice 038 (`todo`), `resolve/rs-new-toml` and cases that print the path of the case dir (the repro sets `TMPDIR` under `research/`, not `/tmp`). Compare the pass counts of the builds.

Result of `seq.sh 4`: build 1 85 pass; builds 2, 3, 4 (same sources) 48 pass, 45 fail each.

## 3. Which builds are hit

| Build | Hit? | Evidence |
| --- | --- | --- |
| `roc build --opt=dev` (test apps) | yes | above |
| `roc build --opt=speed` (LLVM) | no | `OPT=speed repro-l2.sh dead`: A 165.9 s, B 168.5 s, B2 179.5 s, all 85 pass. The 3 builds take the same time: it does not reuse objects |
| `roc check` | no | it writes no `objects-v7`; 0.8 s then 0.6 s warm, 0.5 s after the removal |
| `roc test` | no | it writes no `objects-v7` (it has its own `test` cache); `ranges`, `vars`, `frozen` give the same result before and after a source edit. `l0` uses `--no-cache` already |
| `roc build --fuzz --opt=speed` (l1) | not seen | LLVM, as `--opt=speed`. Not measured with a repro |

## 4. Small repro (not found)

`small.sh` and `small/`: a basic-cli app with 3 modules in a path package (`lib/A.roc`, `B.roc`, `C.roc`, `D.roc`), `sort_with` on records and on tags, 2 builds, a comment edit between them. No crash in about 12 builds of 6 module shapes (flat modules, a package, a leaf edit, an edit under `sort_with` users). The trigger is not found in the small shapes tried. The L2 app reproduces with no edit, so the full app is the repro.

## 5. Options (build times, 4 apps at the same time as `test.sh` does: L2, tln, fxprobe, flowprobe)

`measure-nocache.sh`. The first 2 columns are the number of seconds for all 4 builds together.

| Option | Default threads | `--jobs=1` (test.sh with l0) | Correct? |
| --- | --- | --- | --- |
| Baseline: warm cache, objects reused (the bug) | 3.2 | 4.5 | no (crashes) |
| Empty cache (cold) | 9.3 | 12.0 | the first build only |
| (a) clear `objects-v7` before each build (also when a source is newer than the stamp) | 8.6 | 11.0 | yes, but 4 builds in parallel can read each other's objects (the cross finding) |
| (b) one cache for each app, `objects-v7` cleared before each build | about 8.6 to 11 (same cost as (a): objects are written again) | | yes; needs a copy or links of `can`, `mod` and `pair` for each app (the `mod` dir of the shared cache is 32 GB) |
| (c) `roc build --no-cache` | 4.0 | 6.4 | yes: 3 builds in a row pass, nothing is written |
| (d) build, run, on a crash clear and build again | 3.2 + the L2 run that crashes + 8.6 | | yes, but every warm run crashes first (the bug is the normal case), and a crash in a real defect is hidden |

The idea of option (a) with a "last build stamp" does not work: the bug needs no source change.

Chosen: (c). It is the fastest correct option (+0.8 s default threads, +1.9 s with `--jobs=1` over the broken baseline), it has no state (no stamp, no parallel read problem), and it stops the growth of the cache by builds (a cache-writing build is slower than `--no-cache`).

## 6. Fix

`scripts/test.sh` `build_one`: `roc build <app> --no-cache --opt=... `. Selftest row `s_nocache` (`tests/selftest.sh`): all `roc build` calls of a `test.sh l2 l3` run (fake roc) have `--no-cache`. With the flag removed, the row fails ("0 of 4 builds have it").

Not changed (out of scope of this task, they need the owner): `tests/run.sh:137-142` and `tests/commands/run.sh:72` build without `--no-cache` when no `TLN` or `L2BIN` is given. A person who runs them alone with a warm cache gets the bug.

Step times of `scripts/test.sh` in the red state of slice 038, warm run, no source change (first run) and after `touch cli/lib/Ranges.roc` (second run):

| Step | Budget | Run 1 | Run 2 | Before the fix (red-run.log, objects-v7 removed first) |
| --- | --- | --- | --- | --- |
| check | 10 | 1.1 | 1.1 | 1.1 |
| fmt | 5 | 0.1 | 0.1 | 0.2 |
| l0 | 10 | 7.9 (FAIL, todo) | 7.3 (FAIL, todo) | 7.5 |
| l2 | 30 | 2.6 (FAIL: 4 cases) | 3.7 (FAIL: 4 cases) | 8.6 |
| l3 | 60 | 9.7 | 9.8 | 9.8 |
| selftest | 20 | 10.9 | 10.9 | 10.9 |
| l1 | 60 | 29.9 | 30.9 | 26.7 |

The failures are the ones of slice 038: `ranges.roc`, `vars.roc`, `upgrade.roc` (todo) and 4 L2 cases (`upgrade/ug1-flow`, `ug2-lag`, `ug3-move`, `resolve/rs-new-toml`), 89 of 93 pass, as in `research/slice-038-revert/red-run.log`. The cost of a source change is zero: `--no-cache` does not use the cache, so a run after an edit takes the same time as a run with no edit.

## 7. Text for a roc bug report (do not send)

```
roc nightly-2026-10-14-38a3029, Linux x86_64 (musl target), `roc build --opt=dev`.

A second `roc build --opt=dev` that reuses the object cache (ROC_CACHE_DIR/compat-*/objects-v7/x64musl-dev) gives a bad executable.
The sources do not need to change. The app is about 190 modules (a package of 134 modules, an app with 6 test modules, basic-cli 0.25.0).
Steps:
  1. Empty ROC_CACHE_DIR. `roc build main.roc --opt=dev --output=app1`. The app works.
  2. The same command with `--output=app2` and the same ROC_CACHE_DIR. The log says about 127 of 194 modules cached.
     app2 crashes with a segmentation fault (exit 139) in 33 of 93 runs of the test cases; the stack is in
     roc_boxy_list_sort_with, roc_builtins_str_to_utf8 or roc_builtins_list_decref_with, and one run printed
     "boxy runtime list comparator ordering layout failed".
  3. `rm -rf ROC_CACHE_DIR/compat-*/objects-v7/x64musl-dev` and build again: the app works.
Also bad: building app X, then app Y that imports the same package (the objects of X are reused in Y).
Not bad: `--opt=speed`, `roc check`, `roc test`, `roc build --no-cache` (also faster than a cache-writing build: 3.3 s against 8 s).
A small app (3 modules, sort_with on records) does not show it. A cached object seems to hold data that depends on the build (layout or lambda set ids), so it is wrong in another build.
```
