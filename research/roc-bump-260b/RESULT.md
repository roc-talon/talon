# Slice 260b research: move ROC_TAG to a nightly from 2026-11-02 or later

Date: 2026-11-23. Phase 1 only (research and plan). No tracked file outside this dir was changed. The runs used git worktrees under `.tmp/` (removed at the end) and caches under `.tmp/roc-bump/`.

Files in this dir:

| File | What |
| --- | --- |
| `RESULT.md` | this file |
| `mirror-a.diff` | the full diff that made candidate A green in the mirror (platform URL, 3 code fixes, 2 test fixes). It is a proposal, not the final code: the code agent and the test agent write the real changes. |
| `candidate-b-warnings.txt` | the 43 `duplicate definition` warning sites of candidate B (rejected) |

## 1. Recommendation

| Item | Value |
| --- | --- |
| New `ROC_TAG` | `nightly-2026-11-06-34f137a` (the same tag as `ROC_TAG_WORKER`) |
| Platform | basic-cli `0.26.0` must move to `0.27.0`: `https://github.com/roc-lang/basic-cli/releases/download/0.27.0/9yjxqdGTP4xSpSEmDazwTmRsehfRZzA19pwEKkR6fj1g.tar.zst` |
| Has the G6 fix? | Yes. In `~/dev/Karakatiza666/roc`, `git merge-base --is-ancestor 68b7453a1f 34f137a` is true. |
| Other packages | `http 1.0.0`, `roc-semver 0.2.0`, `roc-toml 0.1.0`, `roc-base58 0.1.0`, `roc-app-header 0.1.0`: no change. They check with no error and no warning. |
| Worker pin | Not changed. `worker/`, `packages/records` and `ROC_TAG_WORKER` stay as they are. |

## 2. Why this candidate

| Nightly | Has 68b7453a1f | basic-cli that fits | Result in the mirror |
| --- | --- | --- | --- |
| `nightly-2026-11-02-847b82c` | no (commit 19:16 +0100, the fix is 15:16 -0500, later) | - | rejected: no fix |
| `nightly-2026-11-03-34bd006` | yes (oldest with the fix) | not known: 0.26.0 fails on 34f137a (the `Stream.size_hint` rename, roc#12837) and was not tried on 34bd006; 0.27.0 says "requires 34f137a or newer" | not tried; no platform release is stated to fit it |
| **`nightly-2026-11-06-34f137a`** | yes | **0.27.0** (its release note: "Requires a Roc nightly of nightly-2026-11-06-34f137a or newer") | **all local steps green after 5 small fixes (section 4)** |
| `nightly-2026-11-13-03dce41` (candidate B) | yes | 0.28.1 ("Use nightly-2026-11-13-03dce41 or later") | rejected for now: a new warning `duplicate definition` (a local name that shadows a top-level name) gives 43 warning sites: 26 in Talon (about 20 files of `cli/lib`, 1 in `tests/`, 1 in `packages/`) and 17 in 3 generic packages (`roc-semver` 15, `roc-toml` 1, `roc-app-header` 1). The generic packages need new releases in their own repos (R-GP1 to R-GP7). check, l0, l2 and l3 all fail on these warnings. |

The brief said: the oldest at or after 2026-11-02 with the fix, unless a newer one is already used on this machine. 34bd006 is the oldest with the fix, but no basic-cli release supports it (0.26.0 breaks on the renamed `Stream.size_hint`, 0.27.0 asks for 34f137a or newer). 34f137a is already used here (the worker pin, and its binary is in `cloudflare-workers/.cache/nightlies/`). One compiler for both pins is also simpler (the TalonRegistry session asked for this too): CI downloads one nightly, and `packages/records` builds with one compiler.

The basic-cli versions were read with `gh release list/view -R roc-lang/basic-cli` (read only). The nightly list was read with `gh release list -R roc-lang/nightlies`. Candidate B's binary was downloaded into `.tmp/roc-bump/nightlies/` (sha256 checked against the release digest), it was not put in any shared cache.

## 3. How the tag is used (what moves with ROC_TAG)

| Place | Use | Change for 260b |
| --- | --- | --- |
| `scripts/env.sh` | `ROC_TAG=${ROC_TAG:-nightly-2026-10-14-38a3029}`; local `ROC=$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG/roc` | the tag; the comment can say that both tags are now the same |
| `scripts/get-roc.sh` | CI: `gh api repos/roc-lang/nightlies/releases/tags/$ROC_TAG`, checks the sha256 digest, installs to `$WORK/nightlies/$ROC_TAG` | none |
| `.github/workflows/ci.yml`, `nightly.yml` | source `env.sh`, put `ROC_TAG`/`ROC_TAG_WORKER` in `GITHUB_ENV`; `actions/cache` of `.work/nightlies` with key `roc-<os>-<arch>-<ROC_TAG>-<ROC_TAG_WORKER>`; `get-roc.sh` and `get-roc.sh worker` | none. The key changes by itself, so the first run downloads again. Both calls then find the same dir. |
| `.github/workflows/release.yml` | `ROC=$(scripts/get-roc.sh)`, then `roc build cli/main.roc --opt=speed --target=<t>` on ubuntu, macos and **windows** runners | none (see risk R1) |
| `.github/workflows/compat-bot.yml` | builds `cli/main.roc` and `bot/main.roc` with `ROC_TAG` | none |
| package cache key in ci.yml | hash of the `https://...tar.zst` URLs in the `.roc` headers | changes by itself (new basic-cli URL) |
| `TESTING.md` TW28, TW31 | "`ROC_TAG` for the CLI ... `ROC_TAG_WORKER` for worker/"; "`packages/records` runs W0 on both nightlies" | text still true. Optional: a note that the two tags are now equal (a human decision, TW17 if the design must say it) |
| `DESIGN-CLI.md` R-CV8 | `nightly-2026-10-14-38a3029` as an example of asset targets | none (an example of a real release, not the pin) |
| `tests/unit/*Test.roc`, `tests/tools/mk-tool.sh`, L2/L3 fixtures | `nightly-2026-10-14-38a3029` and basic-cli `0.25.0`/`0.26.0` as test data | none. They are data, not the pin. |
| `cli/` texts | no default compiler or tag in the code (only doc examples) | none |

## 4. Code changes needed (candidate A)

`scripts/test.sh check` with 34f137a and basic-cli 0.26.0: 16 errors in the platform (basic-cli `Stdin`, `File`, `Http`, `Tcp`, `UnixSocket`, `Sqlite`, `Path`, `OsStr`: `Stream.size_hint` does not exist, and `Unknown` where `Try(U64, [Unknown])` is needed) in every app that uses it, plus Talon's own 1 error and 2 warnings. With basic-cli 0.27.0 only Talon's own 3 remain.

| # | File | Kind | Why | Fix used in the mirror | Owner |
| --- | --- | --- | --- | --- | --- |
| C1 | `cli/main.roc`, `cli/fxprobe.roc`, `cli/flowprobe.roc`, `cli/real.roc`, `bot/main.roc`, `tests/commands/main.roc` | platform URL | basic-cli 0.26.0 does not compile on 34f137a | 0.26.0 URL to 0.27.0 URL (6 lines) | code agent (`tests/commands/main.roc`: test agent) |
| C2 | `cli/lib/AuditCheck.roc` 327 (`closure_entry`) | type error: "two incompatible `first` methods" | `rows` has no annotation. Two calls of `rows.first()` with different uses now give 2 constraints that do not unify. | reuse the binding `first` (already `rows.first().map_err(...)`) in the second `match` | code agent |
| C3 | `cli/lib/ShareLogin.roc` 357 (`poll_loop!`) | warning: unreachable code | `while Bool.True { ... }` never ends, so the last line `Err(Fail.new(Internal, "the poll loop ended"))` is now unreachable | remove the last line (check, l0, l2 pass; the loop only exits with `return`) | code agent |
| C4 | `cli/lib/Outdated.roc` 34 | warning: builtin type shadowed | the new builtins have a type `Range` | rename `Outdated.Range` to `Outdated.NightlyRange` (5 lines in the file; no other file uses it) | code agent |
| C5 | 320 files (cli/lib 222, cli 7, bot 2, packages/resolve 9, tests/unit 66, tests/commands 11, tests/fuzz 3) | `roc fmt` changed | the new `roc fmt` puts parentheses around each `if` condition (`if (x.is_empty()) a else b`) and breaks long `and` chains over lines | `roc fmt` on these files: 2535 lines change, about half are `if (`; all mechanical | code agent for cli/bot/packages, test agent for tests/ |

Test files (L0 compile errors, no failed `expect`):

| # | File | Kind | Why | Fix used in the mirror |
| --- | --- | --- | --- | --- |
| T1 | `tests/unit/AddTest.roc` (10 errors: 8, 79, 89, 123, 130, 147, 175, 331, 332) | type mismatch | The compiler now has a value restriction: a top-level value that is not a function has one type only (`value is not polymorphic`). `none = Err(None)` was used as `Try(Selector, [None])` and as `Try(Str, [None])`. The unannotated `url = \|repo, ver\| "...${repo}..."` also got one type. | `url : Str, Str -> Str`; replace each `none` with `Err(None)` |
| T2 | `tests/unit/ProberangeTest.roc` 165, 169 | missing method `is_eq` | `cell(id) == "pass"` and `i.outcome == Pass`: the type never resolves (string literals and tags are polymorphic now) | `cell : Str -> Str`; `match i.outcome { Pass => "pass", Fail => "ifail" }` |

Error count for the bump: **1 compile error + 2 warnings in cli/** (C2 to C4), **0 in packages/** (resolve and records check clean), **11 compile errors in 2 test files** (T1, T2), **16 errors in the old platform** (removed by C1), **320 files to re-format** (C5).

## 5. Test results in the mirror (candidate A, after section 4)

| Step | Result | Note |
| --- | --- | --- |
| check | pass (4.0 s) | |
| fmt | FAIL before C5 (320 files) | after `roc fmt` it is only format; not re-run in the mirror |
| l0 | pass, 0 failed tests (12.9 s, budget 10) | before T1/T2: l0-7 and l0-8 did not compile |
| l2 (OPT=dev) | **753 passed, 0 failed** | |
| l3 (OPT=dev) | 99 passed, 1 failed, 19 skipped | the 1 fail is `tools/tx1-x-run`, the known time bomb G10 (same diff: the 4th request is missing). Not the compiler. |
| l2 + l3, `OPT=speed SLOW=1` | l2 753 passed; l3 the same as dev | LLVM build time: tln 7 min 9 s and l2 7 min 59 s (at the same time). The old compiler, l2 alone with OPT=speed in a clean worktree: 12 min 44 s. The machine had other load, so this is no exact benchmark, but the new compiler is not slower. |
| w0 (ROC = ROC_WORKER = 34f137a) | pass (17.1 s, cold cache) | `packages/records` fmt and tests pass |
| wbuild | pass (177 s, cold cache) | |
| selftest | pass | |
| cross build `--opt=speed --target=x64win` and `arm64mac` | **not known**: each hit the 600 s cap (`timeout 600`) with no output | not a failure; the limit is the machine rule. CI builds each target on its own runner. |

**Expected-file changes: 0.** No L2 or L3 expected file changed. No expected file has a compiler message or a compiler version of the pinned roc: the test data names nightlies as fixed text, and the L2 app prints no roc output. The skipped L3 cases (tags `real-roc`, `net`, `worker`) use the compilers that `tln` downloads, not `ROC_TAG`, so the pin does not change them either. They were not run (no `REAL_ROC=1 NET=1`).

| Kind of change | Count | Samples |
| --- | --- | --- |
| compiler message text in expected files | 0 | - |
| version strings in expected files | 0 | - |
| other expected-file changes | 0 | - |
| test source changes (L0, compile only) | 2 files | T1, T2 |
| test source re-format (C5) | 80 files | `tests/unit/*.roc`, `tests/commands/*.roc`, `tests/fuzz/*.roc` |

## 6. Risks

| R | Risk | Likelihood | What to do |
| --- | --- | --- | --- |
| R1 | Windows: basic-cli issue #555 reports compile-time stack overflows on Windows when basic-cli 0.27.0/0.28.0 evaluate the quoted `Locale` values in its own `expect`s (seen with nightly 7679cc5, 2026-11-11). basic-cli 0.28.1 says the compiler fix (roc#12996) is in 03dce41. 34f137a is older, so the Windows CI job (`check fmt l0`) and the `x64win` release build can hit it. It cannot be tested on this Linux machine. | medium | Push the slice on a branch and look at the Windows job of ci.yml first. If it fails: candidate B (03dce41 + basic-cli 0.28.1) is the fallback, with its 43 warnings and 3 generic package releases. |
| R2 | The new compiler can have other behavior changes that the fast set does not see (the `real-roc` and `net` L3 cases, `OPT=speed` on macOS). | low | The merge run (nightly.yml, `workflow_dispatch`) before the merge. |
| R3 | Value restriction and polymorphic literals: other unannotated top-level values or `==` on literal-only types can fail in code that a later slice writes. | low (all current code checks) | The code agent knows the rule: annotate a top-level value, or make it a function. |
| R4 | The `roc fmt` change touches 320 files. Other sessions (TalonRegistry, the uncommitted slice 259 and 261 work in the same checkout) will get conflicts. | high, but only in format | Do C5 as the last step of the slice, in one commit, after the other sessions commit. Ask the coordinator for a time slot. |
| R5 | CI cache: the first CI run after the change downloads the nightly and all packages again (new keys). | certain, harmless | none |
| R6 | One compiler for CLI and Worker: a later move of one pin now also asks the question "move the other?" | low | TESTING.md TW28 already keeps 2 variables; keep them. |
| R7 | The G6 fix itself is only shown by source (the cleanup code is gone in 34f137a). The 5-minute race was not reproduced here (local LLVM builds share no cache with other roc runs in a 5-minute window). | low | The next nightly CI run is the proof. |

## 7. Step plan (slice 260b)

| Step | Who | Work | Size |
| --- | --- | --- | --- |
| 1 | scope agent | Slice file `docs/slices/260b-roc-bump.md` (ask the coordinator for the id). Rules: TW28 (one place of the tag), TW25. List C1 to C5 and T1, T2. Decide if TESTING.md TW28 gets a note "both tags are now the same". | S |
| 2 | test agent | T1, T2 (AddTest, ProberangeTest: annotations only, no new or changed `expect`), the platform URL in `tests/commands/main.roc`. These tests are red only by compile on the new compiler, and still green on the old one (the annotations are valid on both). | S (about 15 lines) |
| 3 | human review | | - |
| 4 | code agent | `scripts/env.sh` `ROC_TAG=nightly-2026-11-06-34f137a` (and its comment); C1 in `cli/main.roc`, `cli/fxprobe.roc`, `cli/flowprobe.roc`, `cli/real.roc`, `bot/main.roc`; C2 `AuditCheck.roc`; C3 `ShareLogin.roc`; C4 `Outdated.roc` | S (about 20 lines) |
| 5 | code agent + test agent | C5: `roc fmt` on the 240 code files (code agent) and the 80 test files (test agent), one commit, timed with the other sessions (R4) | M (mechanical, 2535 lines) |
| 6 | verify | `scripts/test.sh` (all fast steps) and `OPT=speed SLOW=1 scripts/test.sh l2 l3` in a capped scope; then CI on a branch: look at the Windows job (R1) and run nightly.yml by hand (merge run) to see G6 gone | M (wall time: about 1 h of CI) |
| 7 | fallback if R1 fails on Windows | candidate B: new releases of `roc-semver`, `roc-toml`, `roc-app-header` (rename the shadowing locals, in their own repos), then 26 renames in Talon (list in `candidate-b-warnings.txt`), basic-cli 0.28.1 | L |

Total for candidate A: small code and test edits (about 35 lines by hand) plus one mechanical re-format; 0 expected files to re-bake.

## 8. Notes on the runs

- All builds and test runs used `flock .tmp/heavy.lock systemd-run --user --scope -p MemoryMax=16G -p MemorySwapMax=0`, `TMPDIR=.tmp/tmp`, and a `WORK` dir of their own under `.tmp/roc-bump/` (so `XDG_CACHE_HOME` and `ROC_CACHE_DIR` were not the main `.work/cache`). No job hit the memory cap.
- Two `OPT=speed` runs used `timeout 900` in place of 600, because the LLVM builds of tln and l2 take 7 to 13 minutes on this machine (a deviation from the 600 s rule; both ended normally). The cross builds kept `timeout 600` and hit it.
- The mirror worktrees were made from HEAD `899f04c9` (not the uncommitted work of slices 259 and 261).
