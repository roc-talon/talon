# Smallest repro of roc-lang/roc#12903 (or-pattern arm emitted once per alternative)

Goal: make the repro of https://github.com/roc-lang/roc/issues/12903 as small as possible. Start: `../variants/mini2or` (3 files, about 500 lines, the Cloudflare Workers platform by URL, wasm32).

## Result

| Item | Finding |
| --- | --- |
| Final repro | `repro/or/main.roc`: one headerless file, 40 lines, no platform, native target. `repro/wild/main.roc` is the same match with a `_` arm. `repro/gen.py N M` writes the 2 files for N tags and M string arms. |
| What the compiler does | The arm `A \| B \| ... =>` is compiled as N copies of the arm body. The binary is byte-identical to the form with one arm for each tag and the same body (`or` = `arms` in each step below). |
| Where it is visible | `--opt=dev`: always, N copies. `--opt=speed` and `--opt=size`: when LLVM does not merge the copies again. LLVM merges a pure body (step h2) but not a body with effect calls (steps h3, h4), and not a body that calls a function that LLVM then inlines at each copy (the platform app). |
| What the trigger does not need | wasm32, the platform, its types, a closure in a record, `Try`, `Str.inspect`, a payload in the tags, a `_` arm after the or-pattern. |
| Newer nightlies | The same sizes with `nightly-2026-11-04-2622062` and `nightly-2026-11-06-34f137a` (the latest on 2026-11-07). |
| Issue | The body of #12903 was replaced with the final repro (text in `../upstream-issue.md`). |

Sizes of the final repro (`repro/measure.sh`, nightly-2026-10-31-f7bef6b, x86-64 Linux, M = 20). "bytes" is the size of the function of `main!` (`nm -S`). "copies" is the number of times that the 8 bytes `line 07 ` occur in that function (the literal is made from immediates in the code).

| N | `--opt` | or-pattern: bytes | copies | `_` arm: bytes | copies |
| --- | --- | --- | --- | --- | --- |
| 2 | dev | 16,447 | 2 | 8,587 | 1 |
| 2 | speed | 2,488 | 1 | 2,496 | 1 |
| 4 | dev | 32,245 | 4 | 8,665 | 1 |
| 4 | speed | 7,560 | 3 | 2,496 | 1 |
| 6 | dev | 48,043 | 6 | 8,743 | 1 |
| 6 | speed | 12,471 | 5 | 2,496 | 1 |
| 8 | dev | 63,841 | 8 | 8,821 | 1 |
| 8 | speed | 21,649 | 8 | 2,496 | 1 |

`--opt=size` gives the same sizes as `--opt=speed` (N = 6: 12,471 bytes, 5 copies).

## Reduction steps

Tools: `pair.sh DIR TEXT [opt]` (platform app, wasm32) writes `DIR/or`, `DIR/arms` (one arm for each alternative, same body) and `DIR/one` (the body once, in a `_` arm) from `DIR/main.roc` (the arm marked `#OR`) and builds them. `natpair.sh` does the same for a headerless app on the native target (`NOGEN=1` when a `gen.py` wrote the forms). `count.mjs` (wasm) and `countnat.py` (native) print the largest function and the copies of TEXT in each function.

wasm32 steps on the platform (0.0.7 by URL, `--opt=speed`). Sizes are of the largest function.

| Step | Change from the step before | or | arms | one | Copies of the marker (or / one) |
| --- | --- | --- | --- | --- | --- |
| r0 | copy of `mini2or` | 501,878 | 501,878 | - | 102 / - (`Unauthenticated`) |
| r0a | no `Route` module: `fetch!` calls `handle!` with an id from the method text | 246,002 | 246,002 | - | 6 / - (`handler 3 refused`) |
| r0b | 4 handlers in place of 17 | 115,430 | 115,430 | 68,964 | 6 / 1 |
| r0c | 2 handlers | 95,919 | 95,919 | 65,846 | 6 / 1 |
| r1 | 1 handler, no `handle!`, `run!`, `read_answer` | 76,883 | 76,883 | - | lost: `to_json` is not inlined |
| r3 | from r0c: no `Problem` module; `fetch!` reads a header and calls a large string match `big` | 75,731 | 75,731 | 79,395 | 6 / 1 (`own marker`) |
| r4 | `fetch!` gives a `Response`, not a `Try`; `own!` has no inner match | 72,673 | 72,673 | 78,628 | 6 / 1 |
| r5 | r3 with no `Str.inspect` | 74,171 | 74,171 | 79,131 | 6 / 1 |
| p1 | `fetch!` is pure (`big(req.method())`, no header read) | 69,975 | 69,975 | 112,038 (`p1wild`) | 1 / 1 |
| r4, `--opt=dev` | the dev backend | 1,885,293 code section | - | 1,566,600 code section | `event!` calls `own!` 6 times; `own!` is not inlined |

The `--opt=dev` build of r4 shows that the copies come before LLVM: the or-pattern arm `own!(e)` is 6 calls. With `--opt=speed`, LLVM inlines `own!` (and `fetch!`) at each of the 6 calls. In `mini2or` the inlined body has 17 sites of `problem_response`, so 6 x 17 = 102 copies.

Native steps (headerless, `main!` with `echo!`):

| Step | Program | or | one | Copies (or / one) |
| --- | --- | --- | --- | --- |
| r2 | r0c with local types for `Request`, `Response`, `Event` | text 37,588 | text 35,296 | 1 / 1: `own!` is not inlined |
| h1 | r4 with local types | text 36,924 | text 35,688 | 1 / 1: `own!` is not inlined |
| h2 | the arm body is a match of 40 strings that gives a `Str` (pure), in the arm itself | dev: 96,380; speed: 6,383 | dev: 16,375; speed: 4,367 | dev: 6 / 1; speed: 1 / 1 |
| h3 | as h2, each string arm calls `echo!` | speed: 32,223 | speed: 5,295 | 6 / 1 |
| h4 = repro | as h3, the tags have no payload, the tag comes from `args.len()`, all in `main!` | speed: 12,471 | speed: 2,496 | 5 / 1 |

In h2 the 6 copies are equal and pure, and LLVM merges them. With effect calls in the body (h3, h4) LLVM keeps them.

Not usable: a headerless app with `--target=wasm32` gives an archive, not a module. `hpair.sh` links it with `zig wasm-ld` (set `ZIG`). The compiler folds the args of the headerless wasm32 app, so h4 becomes 386 bytes of code in all forms.

Why the first native try (`../orpat/`) did not show it: its arm body is a call of a closure from a record (`own!(ev)`). The native build does not inline that call, so each copy is only a call.

## Files

| File | Purpose |
| --- | --- |
| `repro/gen.py`, `repro/measure.sh` | the final repro and its size table |
| `repro/or/main.roc`, `repro/wild/main.roc` | the final repro for N = 6, M = 20 |
| `pair.sh`, `build.sh`, `count.mjs` | wasm32 platform steps |
| `natpair.sh`, `countnat.py` | native steps |
| `hpair.sh` | headerless wasm32 (not usable, see above) |
| `r0` to `r5`, `p1*.roc` | the platform steps |
| `h1` to `h4` | the native steps (`h2` to `h4` have a `gen.py`) |
