# roc-semver: version parse, print, order, and the range forms

Phase: P0 (generic package, Design 7). Status: tests (review 1 done 2026-10-16: Q1 to Q11 settled, tests updated)

| Item | Value |
| --- | --- |
| Repository | `github.com/Karakatiza666/roc-semver` (not created). Local: `../roc-semver/` (`git init -b main`, no commit) |
| Compiler | `nightly-2026-10-14-38a3029` (`.roc-version`) for all checks and CI (human choice, 2026-10-16). roc-fuzz 0.4.3 fails on 10-15 (`../nightly-1015-check/README.md`). |
| Port source | `smores56/roc-semver` at `main` (pushed 2025-02-20, release `0.1.0` of 2024-06-11), R-GA6 |
| Run | `scripts/test.sh [ROC [FUZZ_ROC]]`: ROC (default `roc` on PATH) runs check, fmt, L0. FUZZ_ROC (default ROC) checks, builds and runs L1, `RUNS` (default 100000), `--seed=1 --time=0` |

## Rules

R-PK2, R-GA6, R-GP1, R-GP5 (Design 6.1, 6.2). R-I4, R-I7 (Design 4.3). R-ID1 (Design 4.1). R-SL15, R-AD25, R-AD26 (CLI 2). R-NS7, R-UP5 (Resolution 1, 10: only the forms that they name). The answers of review 1 (section Settled): npm and Cargo meaning for the range forms. R-TF4 (a range that does not parse is an error). Semantic Versioning 2.0.0 sections 2, 9, 10, 11 and the FAQ. TESTING.md 4 (L1 targets for semver).

## Public API

`package/main.roc` exposes 2 type modules. No dependencies. The bodies are `crash "todo"` (code agent).

| Module | Function | Signature | Source name |
| --- | --- | --- | --- |
| `Semver` | `new` | `U64, U64, U64 -> Semver` | new (D12) |
| | `parse` | `Str -> Try(Semver, [EmptySemver, InvalidMajorVersion(NumErr), NoPeriodAfterMajorVersion, InvalidMinorVersion(NumErr), NoPeriodAfterMinorVersion, InvalidPatchVersion(NumErr), InvalidPreRelease(IdErr), InvalidBuild(IdErr), UnexpectedSuffix(Str)])` | `Semver.parse` |
| | `parse_lazy` | `Str -> Try((Semver, Str), [the tags of parse except UnexpectedSuffix])` | `Semver.parse_lazy` |
| | `to_str` | `Semver -> Str` | `Semver.to_str` |
| | `order_relative_to` | `Semver, Semver -> [Before, Same, After]` | `Semver.compare` (D3) |
| | `major`, `minor`, `patch` | `Semver -> U64` | record fields (D2) |
| | `pre_release`, `build` | `Semver -> List(Str)` | record fields (D2) |
| | `is_eq`, `to_hash` | derived (`: _`) | structural `==` (D5) |
| `VersionReq` | `star` | `VersionReq` | `VersionReq.star` |
| | `parse` | `Str -> Try(VersionReq, [InvalidComparator({ index : U64, error : [InvalidMajorVersion(NumErr), InvalidMinorConstraint(NumErr), InvalidPatchConstraint(NumErr), InvalidPreReleaseConstraint(IdErr), BuildMetadataNotAllowed, UnexpectedSuffix(Str)] }), TooManyComparators, UnexpectedSuffix(Str)])` | `VersionReq.parse` |
| | `parse_lazy` | `Str -> Try((VersionReq, Str), [InvalidComparator(...), TooManyComparators])` | `VersionReq.parse_lazy` |
| | `to_str` | `VersionReq -> Str` | `VersionReq.to_str` |
| | `matches` | `VersionReq, Semver -> Bool` | `VersionReq.matches` |

`NumErr` = `[Empty, InvalidNumber, CannotStartWithZero]`, `IdErr` = `[EmptySegment, InvalidIdentifier]`. They are written inline (anonymous unions, roc-syntax `error_design`). `BuildMetadataNotAllowed` replaces the source tag `InvalidBuildConstraint(IdErr)` (Q8, proposal P1).

## Decisions

| # | Decision | Rejected options | Reason |
| --- | --- | --- | --- |
| D1 | 2 public modules: `Semver`, `VersionReq` | Keep the 5 public modules of the source (`Types`, `Error`, `Semver`, `VersionReq`, `Comparator`) | The new compiler puts the functions of a type in its type module. `Comparator`, `Compare`, `Parse`, `AsciiCode` become hidden modules of the code agent. |
| D2 | `Semver` is opaque (`::`). `new` and `parse` make a value. Accessors read the parts. | Structural record alias (source). Nominal `:=` with a visible record. | A type module needs a nominal type. With `:=`, a caller can make a value with an identifier that is not valid, so `parse(to_str(v)) == v` does not hold for each value. |
| D3 | `compare` becomes `order_relative_to`, result `[Before, Same, After]` | `compare` with `[LT, GT, EQ]` | Builtin name and tags (`U64.order_relative_to`). `List.sort_with` takes it with no adapter. |
| D4 | No `is_lt` (no `<` on `Semver`) | Operator methods with the precedence | `==` includes the build metadata, the precedence does not. Then `a <= b and b <= a` does not give `a == b`. |
| D5 | `is_eq` and `to_hash` are derived: `==` compares all parts, also the build metadata | `is_eq` by precedence | A `Dict` key and the round trip need an exact equality. The precedence is `order_relative_to`. |
| D6 | `VersionReq` is opaque. The form of a requirement is hidden. | A public `List(Comparator)` (source) | Q1 to Q9 can change the representation. Opaque keeps the signatures the same for each answer. |
| D7 | No `==` on `VersionReq` | Derived `is_eq` | `2.x`, `^2` and `2` match the same versions, but a structural `==` can say they differ. The tests compare `matches` and `to_str`. |
| D8 | Error tags of the source, inline. The error text functions (`invalid_semver_error_to_str` and 4 more) are not in 0.1.0. | A nested `Semver.ParseErr` type. Port the text functions. | roc-syntax `error_design`: anonymous unions. The text is output that the user of the package writes. A text function can come in a minor release. |
| D9 | Port changes: upper case letters are valid in identifiers (T-SV25). `1.2` means `^1.2` (T-VR21). | Keep the source behavior | The `is_letter` of `Parse.roc` tests `a..z` two times (bug, semver 9). The source reads `1.2` as `1.2.*`, R-SL15 says `^1.2`. |
| D10 | No dependency | roc-parser 2.0.0 | The source has no dependency. A byte parser is small. roc-parser adds 2 URL packages (roc-parser, unicode). |
| D11 | Keep `parse_lazy` (both modules) and `star` | Drop them | Source names. `parse_lazy` reads a version inside other text. |
| D12 | Add `Semver.new` | Only `parse` | A caller with 3 numbers (for example from a URL) makes a release version with no text and no `Try`. The fuzz targets use it. |
| D13 | `parse` of `VersionReq` keeps the source tags `TooManyComparators` and `InvalidComparator({ index, ... })` | Remove them | Comma lists stay (Q7). T-VR9 and T-VR42 use them. |
| D14 | The stub of `star` has a placeholder value, not `crash "todo"` | `crash "todo"` | A constant is evaluated at compile time: `roc check` fails with "compile time crash". Add this to LAYOUT.md point LP5. |
| D15 | 3 L1 targets: round trip, order, caret oracle | Only the 2 of TESTING.md 4 | The caret rule (R-I7) is the part that Talon depends on most, and a bounds oracle is simple. |

## Tests

L0: `tests/semver.roc` (99 `expect`s, ids T-SV1 to T-SV54), `tests/version_req.roc` (136 `expect`s, ids T-VR1 to T-VR52). Each id can have more than one `expect`. Each `expect` has a comment with its id and source.

Sources: "smores X" is the file X in `smores56/roc-semver`. "semver N" is section N of semver 2.0.0.

| Layer | File | Case | Source |
| --- | --- | --- | --- |
| L0 | semver | T-SV1 to T-SV11: errors: `""`, `"0"`, `"0."`, `"0.1"`, `"0.1."`, `"0.1.0."`, `"0.1.00"`, `"0.1.0-"`, `"0.1.0-?"`, `"0.1.0+"`, `"0.1.0+?"`, each with the exact source tag | smores Parse.roc (T-SV7 also semver 2) |
| L0 | semver | T-SV12 to T-SV16: parts of `0.1.0`, `0.1230.0-alpha.beta`, `+alpha.beta`, `-alpha-beta+gamma.delta`, `+alpha-beta` | smores Parse.roc |
| L0 | semver | T-SV17, T-SV18: `1.2.3-alpha.beta+build--`, `1.2.3-alpha+beta` | smores README.md, Semver.roc |
| L0 | semver | T-SV19, T-SV20: `parse_lazy` gives `" abc"` and `""` after the version | smores Semver.roc |
| L0 | semver | T-SV21 to T-SV23: leading zero in major and minor (exact tags), negative and letters, 2 or 4 numbers | semver 2 |
| L0 | semver | T-SV24 to T-SV29: the pre-release examples, upper case, `alpha.01`, `00`, `0a`, empty identifier, `_` | semver 9 |
| L0 | semver | T-SV30, T-SV31: the build examples (leading zero `001` is valid), empty build identifier | semver 10 |
| L0 | semver | T-SV32: `v1.2.3` is not valid | semver FAQ |
| L0 | semver | T-SV33: a space before or after | smores Semver.roc (parse takes the whole text) |
| L0 | semver | T-SV52: numbers above `U64` max are `InvalidNumber` errors, `U64` max is valid | Q10 settled |
| L0 | semver | T-SV53, T-SV54: a numeric pre-release identifier above `U64` max is valid, prints back, and compares as a number of any size | Q13 settled by slice proposal |
| L0 | semver | T-SV34 to T-SV36: `to_str` of `new(1,2,3)`, of `1.2.3-abc+def-.ghi`, and of 11 samples (also `U64` max) | smores Semver.roc, TESTING.md 4 |
| L0 | semver | T-SV37: `new(0, 25, 1) == parse("0.25.1")` | R-PK2, D12 |
| L0 | semver | T-SV38: `==` includes the build metadata | D5 |
| L0 | semver | T-SV39 to T-SV44: number order (`1.9 < 1.10`), pre-release before release, the chain of 11.4, Same on itself, build ignored, `sort_with` | semver 10, 11 |
| L0 | semver | T-SV45 to T-SV51: the compare cases of the source (major, minor, patch, pre-release, build, identifier rules) | smores Compare.roc, semver 11.4 |
| L0 | version_req | T-VR1 to T-VR5: `star` prints `*` and matches, `1.2.3` matches itself, `1.3.*` and `^2.5` print as written | smores VersionReq.roc |
| L0 | version_req | T-VR6 to T-VR12: `""` (exact tag), `*`, 1 to 3 parts and a pre-release parse, `2.x.3` (exact tag), `parse_lazy("4.x ?")`, `parse("4.x ?")` | smores Parse.roc |
| L0 | version_req | T-VR9 (changed): `+` in a requirement gives `BuildMetadataNotAllowed`, also in comparator 1 of a list | Q8 settled, P1 |
| L0 | version_req | T-VR13, T-VR14: `^2.1`, `^0.25.1` | R-I7 |
| L0 | version_req | T-VR15, T-VR16: implied `^0.25.0`, `^2.1.0` | R-I4 |
| L0 | version_req | T-VR17 to T-VR22: `2.x` = `^2` = `2`, `2.1.x`, `0.25` = `0.25.x` = `^0.25`, `0.x`, `1.2` = `^1.2`, 3 parts exact | R-SL15, R-AD26 |
| L0 | version_req | T-VR23: `=2.0.0` | Design 4.3, R-AD25 |
| L0 | version_req | T-VR24, T-VR25: `*`, `^1` | Design 4.3, R-NS7 |
| L0 | version_req | T-VR26: `0.25.*` = `0.25.x`, `0.1.*`. Reading: `*` in a part is `x` (R-PK2 names both, R-SL15 calls `x` the shell-safe form). Confirm at review. | Design 4.3, R-NS7, R-PK2 |
| L0 | version_req | T-VR27: the forms that R-UP5 writes parse | R-UP5 |
| L0 | version_req | T-VR28: `abc`, `^`, `=`, `1.2.3.4`, `1..2` do not parse | R-TF4 |
| L0 | version_req | T-VR29 to T-VR32: `^1.2.3`, `^0.2.3`, `^0.0.3` (<0.0.4), `^0.0` = `0.0` (<0.1.0), `^0` = `0` (<1.0.0) | Q1, Q2 settled |
| L0 | version_req | T-VR33, T-VR34: `2.x.x`, `1.*.*`, `X`, `1.X`, `1.2.X` | Q5 settled |
| L0 | version_req | T-VR35: `^1.x`, `^1.*`, `=1.*`, `=1.x`, `^0.x`, `^0.0.x`, `>=1.x`, `<=1.2.x` | Q3 settled |
| L0 | version_req | T-VR36: `=1.2`, `=1` | Q4 settled |
| L0 | version_req | T-VR37: each operator on 1.2.3 | smores Comparator.roc |
| L0 | version_req | T-VR38 to T-VR40: `> >= < <=` on full and partial versions, `~1.2.3`, `~1.2`, `~1`, `~0.2.3` | Q7 settled |
| L0 | version_req | T-VR41, T-VR42: comma lists (AND), the limit of 32 comparators | smores Parse.roc |
| L0 | version_req | T-VR43, T-VR44: spaces at the start, after an operator, after a comma. A list prints with `, `. | Q7 settled, smores VersionReq.roc |
| L0 | version_req | T-VR45, T-VR46: no match for a pre-release version (`*`, `^1.2`, `>=1.0.0`, `1.x`, `^1.2.3`, `>=1.2.3-alpha`). A pre-release bound is below its release. | Q6 settled, semver 11.3 |
| L0 | version_req | T-VR47: `to_str(parse(s)) == s` for 15 forms with no spaces | Q9 settled |
| L0 | version_req | T-VR50: no pre-release match also when a comparator has a pre-release on the same `M.m.p` (`=1.0.0-rc.1`, `>=1.2.3-alpha`, `^1.2.3-alpha`, the smores README case) | Q12 settled by slice proposal |
| L0 | version_req | T-VR51, T-VR52: `^* >=* ~* =* <=*` match each version, `>*` and `<*` match none. A space before a comma or at the end gives `UnexpectedSuffix` (exact tags). | Q14 settled by slice proposal |
| L0 | version_req | T-VR48, T-VR49: numbers above `U64` max are errors. A caret or `<=` upper bound past `U64` max does not crash. | Q10 settled |
| L1 | `fuzz/semver-roundtrip.roc` | Valid text from typed parts (`U64` numbers, identifiers from `[0-9A-Za-z-]`): `parse` accepts it, the parts are the same, `to_str` gives the text back, `parse(to_str(v)) == Ok(v)` | TESTING.md 4, semver 2, 9, 10 |
| L1 | `fuzz/semver-order.roc` | 3 versions from a small domain: Same on itself, antisymmetric, transitive, build ignored, pre-release before its release. 2 release versions with any `U64` parts: equal to the tuple compare. | TESTING.md 4, semver 10, 11 |
| L1 | `fuzz/req-caret.roc` | `^M.m.p`, `^M.m`, `M.m`, `^M.m.x`, `^M`, `M`, `M.x`, `^M.x` for each M, m, p in 0 to 3, against the npm and Cargo oracle (no change of the left-most part that is not zero). No reject. Release versions only (Q6). | Q1, Q2, Q3 settled, R-SL15 |

Red state (2026-10-16, `nightly-2026-10-14-38a3029`): `roc check` exit 0 with no warning for `package/main.roc` and each test and fuzz file. `roc fmt --check package tests fuzz` exit 0. `roc test`: 99 of 99 and 136 of 136 fail, each with "todo", 0 compiler errors. Each fuzz target builds and exits 77 with `[roc crashed] todo`.

Source tests not ported:

| Source test | Reason |
| --- | --- |
| Compare.roc `["10"]` against `["00"]`, `["0"]` against `["00"]` | `00` is not a valid numeric identifier (semver 9). T-SV49 uses 10 against 9. |
| Parse.roc `version_req("123")` gives `Exact(Major 123)` and the other structural results, the operator table of `parse_comparator_operator` | `VersionReq` is opaque (D6). T-VR8, T-VR37 to T-VR40 test the same through `matches`. |
| README.md `>=1.2.3-alpha.beta, <2` matches `1.2.3-alpha.beta+build--` | Reversed by Q12: T-VR50 expects no match (and build metadata is in the version, not in the range) |

## Output (proposed, R-OUT2)

None. The package has no human text and no `data` fields. The doc comments in `package/*.roc` are a proposal for the review.

## Out of scope

| Item | Where |
| --- | --- |
| Talon selectors: `latest`, nightly tags, git refs, `+N` and `-N` (R-SL5 to R-SL8), the `>=<nightly tag>` bound (R-NS7) | Talon |
| Nightly order (R-NS1), the series of a version as a value, the group key, the one `X.Y.Z` run in a URL (Design 2, R-DI5) | Talon, `roc-app-header` |
| The R-UP5 rewrite of a range at a new version | A later slice (Q9 settled) |
| Set operations on ranges (intersection, union, complement) | Not needed (Q11 settled) |
| Error text functions | D8 |
| `LICENSE` (R-GP7, table LIC), `README.md`, release workflow, `roc bundle` | Not in this step. `.roc-version` and `.gitignore` exist. |

## Settled (review 1, 2026-10-16)

| # | Question | Answer | Tests |
| --- | --- | --- | --- |
| Q1 | `^0.0.3` | npm and Cargo: no change of the left-most part that is not zero. `^1.2.3` <2.0.0, `^0.2.3` <0.3.0, `^0.0.3` <0.0.4. npm and Cargo also for `^0.0`, `^0.x` and the other caret edge forms. | T-VR29 to T-VR31, T-VR35, req-caret |
| Q2 | `^0`, bare `0` | `>=0.0.0, <1.0.0` for both | T-VR32 |
| Q3 | Operator with a wildcard | Valid, npm and Cargo meaning: the operator with the parts before the wildcard | T-VR35 |
| Q4 | `=1.2`, `=1` | Valid, Cargo meaning | T-VR36 |
| Q5 | `X`, `2.x.x` | Both valid. `2.x.3` stays an error (source, Cargo). | T-VR33, T-VR34, T-VR10 |
| Q6 | Pre-release versions | A range does not match a pre-release version | T-VR45, T-VR46. Edge case: Q12. |
| Q7 | Other operators, lists, spaces | Keep `> >= < <= ~`, comma lists and spaces | T-VR37 to T-VR44 |
| Q8 | Build metadata in a range | Not allowed: a parse error (P1) | T-VR9 |
| Q9 | `to_str` form, R-UP5 rewrite | The slice proposal: `to_str` keeps the written form. The rewrite (`bump_to` or a public view) is a later slice. | T-VR47 |
| Q10 | Numbers above `U64` max | The slice proposal: `InvalidNumber` error, no crash | T-SV52, T-VR48, T-VR49 |
| Q11 | Set operations for `resolve` | The slice proposal: no | None |

| # | Proposal from review 1 |
| --- | --- |
| P1 | Accepted (review 1). The error for build metadata in a requirement is `InvalidComparator({ index, error: BuildMetadataNotAllowed })`, for each text after `+` (valid or not). It replaces the source tag `InvalidBuildConstraint(IdErr)`. The slice had no proposal for this error. Rejected: top-level `UnexpectedSuffix("+b")` (it does not say why), keeping `InvalidBuildConstraint` with a new payload. |

## Settled by slice proposal, after review 1 (human to confirm)

The human answer: "for the rest of the questions, use the slice proposals".

| # | Question | Proposal (now the rule) | Difference from npm and Cargo | Tests |
| --- | --- | --- | --- | --- |
| Q12 | Q6 says "a range does not match a pre-release version". Also when a comparator has a pre-release on the same `M.m.p`? | Yes, also then. `matches` is false for each version with a pre-release. A pre-release in a comparator is only a bound for release versions (`>=1.2.3-alpha` matches `1.2.3`). This is the closest reading of the Q6 answer. | npm and Cargo (and smores) match a pre-release version when a comparator has a pre-release on the same `M.m.p`: `=1.0.0-rc.1` matches `1.0.0-rc.1`, `>=1.2.3-alpha` matches `1.2.3-beta`. roc-semver does not. So a user cannot select a pre-release with a range. | T-VR50, T-VR45 |
| Q13 | A numeric pre-release identifier above `U64` max | Valid (semver 9). It compares as a number of any size: first by the count of digits, then by the digits. It is kept as text. | None: Cargo and npm accept it. | T-SV53, T-SV54 |
| Q14 | `^*`, `>=*`, `>*`, `<*`, spaces before a comma or at the end | npm: `^*`, `>=*`, `~*`, `=*`, `<=*` are `*`. `>*` and `<*` match no version. A space before a comma or at the end is `UnexpectedSuffix(<rest>)`, as the source. | Cargo rejects some of the `*` forms with an operator. npm and Cargo allow a space before a comma or at the end. | T-VR51, T-VR52 |

## Questions (stop until answered)

None for the package. G2 is a Talon design point for the human.

## Design gaps

Changes that the answers of review 1 imply (Talon design files are not edited here):

| # | Row | Problem | Proposed change |
| --- | --- | --- | --- |
| G1 | DESIGN.md R-I7 | Q1: the caret is the npm and Cargo rule, not "each newer version in the series of v". For `0.0.z` they differ. | "A caret range `^v` allows each update that does not change the left-most part of v that is not zero (npm, Cargo). So `^2.1` is `>=2.1.0, <3.0.0`, `^0.25.1` is `>=0.25.1, <0.26.0`, and `^0.0.3` is `>=0.0.3, <0.0.4`. For `>=0.1` this is the series of v (4.1). For `0.0.z` it is smaller than the series `0.0`." |
| G2 | DESIGN.md R-I4 | The implied range `^<header version>` of a `0.0.z` header version is now `=0.0.z`, smaller than the series. The row says "the same series as the header version". | Add: "For `0.0.z`, `^0.0.z` is `=0.0.z` (R-I7), so `tln update` does not move a `0.0.z` entry." Or make the implied range of `0.0.z` the series `0.0` (`>=0.0.z, <0.1.0`). Human decision. |
| G3 | CLI R-SL4, R-SL15 | `@0.0` and `@0.0.x` mean `^0.0` (<0.1.0, Q1). `@0` means `^0` (<1.0.0, Q2). The rows name `0.25` only. | Add the `0.0` and `0` rows. Also: a caret range below `0.1` is not a series (R-SL4 says "a series"). |
| G4 | DESIGN.md R-PK2 | The form list is `^`, `=`, `*`, `x`, a major. Q3 to Q8 add `X`, `~`, `>`, `>=`, `<`, `<=`, comma lists, spaces, operators with wildcards, `=` with fewer parts. No pre-release match, no build metadata. | "The range forms of npm and Cargo: `^`, `~`, `=`, `>`, `>=`, `<`, `<=`, the wildcards `*`, `x`, `X`, a version with 1 to 3 parts, comma lists. A range does not match a pre-release version. Build metadata is not allowed. A version with 3 parts and no operator is exact (R-SL15)." Put the table of the `VersionReq` doc comment in 4.3. |
| G5 | Resolution R-UP5 | Q9: `to_str` keeps the form. The rewrite is not in R-PK2. | Name the function in R-PK2 when the later slice adds it. R-UP5 must also say the form for `^0.0.z` and `~` ranges. |
| G6 | Resolution R-NS7 | Q7 keeps `>=`. A release lower bound (`>=0.1.0`) is a semver range. | "A lower bound `>=<release version>` is a semver range (R-PK2). `>=<nightly tag>` is a Talon form." |
| G7 | TESTING.md 4, semver row | "Order is total": semver 10 makes `1.0.0+a` and `1.0.0+b` Same but not equal | "The order is a total preorder: versions that differ only in build metadata are Same (semver 10). It agrees with a tuple compare." |
| G8 | LAYOUT.md LP5 | A stub of a constant cannot be `crash "todo"` (D14) | Add: "A constant stub gets a placeholder value, because `roc check` evaluates constants." |
| G9 | LAYOUT.md, compiler row | The pinned nightly is 10-09. The human chose `nightly-2026-10-14-38a3029` for all checks and CI. roc-fuzz 0.4.3 fails on 10-15. | Change the pin in LAYOUT.md to 10-14 for the generic packages. `scripts/test.sh` keeps an optional FUZZ_ROC argument for a later split. |

## Proposed first version

`0.1.0`.

| Option | Result |
| --- | --- |
| `0.1.0` | Chosen. A new group (`Karakatiza666/roc-semver`, Design 2), so it does not continue the source `0.1.0`. Below 1.0 while the human has not confirmed Q12 to Q14 and Talon has not used the API: an answer can change `matches`. Each later break goes to `0.2.0`, a new series (R-ID1). |
| `1.0.0` | Rejected: the answers to Q12 to Q14 and the R-UP5 slice could need `2.0.0` soon after. |
| `0.0.1` | Rejected: with the Q1 answer, `^0.0.1` matches `0.0.1` only, so a user gets no fix release by a caret range. |

## Disputes (from the code agent)

## Verify results

Verify agent, 2026-10-16, `nightly-2026-10-14-38a3029`. Tool: `research/generic-packages/tools/mutate-roc-semver.py` (one mutation at a time, `roc check`, both L0 files, the 3 fuzz targets at 20000 runs, seed 1).

| Step | Result |
| --- | --- |
| 1 `scripts/test.sh` (clean `.work`) | Exit 0. `tests/semver.roc` 99 of 99 pass, `tests/version_req.roc` 136 of 136 pass. Fuzz: `req-caret`, `semver-order`, `semver-roundtrip` each 100000 runs, 0 failures. Check and fmt pass. |
| 2 `roc check package/main.roc` | 0 errors, 0 warnings |
| 3 `roc bundle` | `dist/KFKmXaroJeaPkQmAaqm83fTP9yhnEkTQwE97a5BtFSX.tar.zst` (6841 bytes). Files: `main.roc`, `Semver.roc`, `VersionReq.roc`, `Internal/Comparator.roc`, `Internal/Lex.roc`, `Internal/Precedence.roc`. Only package files. |
| 4 Mutations | 64 of 67 caught. 3 gaps (table below). |
| 5 R-GP1 grep (`talon`, `registry`, `probe`, `evidence`, `compat`) in `package/` | No match |
| LICENSE (R-GP7, table LIC) | Lines 1 and 2 are the 2 copyright lines of table LIC for `Karakatiza666/roc-semver` (exact). Lines 3 to 18 equal lines 2 to 17 of the Talon `LICENSE` (`diff` exit 0). |
| Restore | `diff -r package/ <step 0 copy>`: identical. `.roc-fuzz/corpus` put back to its state after step 1 (314 files). |

Gaps (mutation that no test catches):

| # | Rule | Mutation | Why no test fails | Proposed test (test agent) |
| --- | --- | --- | --- | --- |
| M12 | Q10 (U64 overflow is an error) | `times_try(10)` to `times_wrap(10)` in `to_u64` | T-SV52 and T-VR48 use only `18446744073709551616` (U64 max + 1). For that number the overflow is in the `plus`, not in the `times`. | Add a number where `n * 10` overflows, for example `99999999999999999999.0.0` and `184467440737095516150.0.0`: `InvalidMajorVersion(InvalidNumber)`. Same in a requirement. |
| M42 | Q5 (wildcards) | `x.x.x` / `*.*.*`: skip 1 `.x` part, not 2 | No test has a 3-part wildcard with a wildcard major (`x.x.x`, `*.*.*`, `X.X.X`). T-VR33 has `2.x.x` only. | `x.x.x`, `*.*.*` match each release version and `to_str` gives the text back. |
| M56 | semver 11.3 (a pre-release bound is below its release) | `next` of `M.m.p-pre` gives `M.m.(p+1)`, not `M.m.p` | T-VR46 tests `>=` and `<` with a pre-release. These use `floor`, not `next`. No test has `>`, `<=` or `=` with a pre-release. | `>1.2.3-alpha` matches `1.2.3`. `<=1.2.3-alpha` does not match `1.2.3`. `=1.2.3-alpha` matches no version. |

M50 (operator order) also gives a check warning (a redundant pattern), but L0 fails.

| # | Mutation | File and line (`package/`) | Failed tests |
| --- | --- | --- | --- |
| M1 | major order reversed | `Internal/Precedence.roc:9` | T-SV39, T-SV44, T-SV45, T-SV46; T-VR2, T-VR7, T-VR11, T-VR13, T-VR16, T-VR17 (+18 more); fuzz req-caret; fuzz semver-order |
| M2 | minor order reversed | `Internal/Precedence.roc:9` | T-SV39, T-SV44, T-SV45, T-SV46; T-VR11, T-VR13, T-VR14, T-VR15, T-VR16, T-VR17 (+22 more); fuzz req-caret; fuzz semver-order |
| M3 | patch order reversed | `Internal/Precedence.roc:9` | T-SV39, T-SV44, T-SV45, T-SV46; T-VR3, T-VR13, T-VR14, T-VR15, T-VR18, T-VR19 (+15 more); fuzz req-caret; fuzz semver-order |
| M4 | numeric identifier after alphanumeric | `Internal/Precedence.roc:45` | T-SV54, T-SV41, T-SV50; fuzz semver-order |
| M5 | numeric identifiers compare as text | `Internal/Precedence.roc:44` | T-SV54, T-SV41, T-SV44, T-SV49 |
| M6 | pre-release after its release | `Internal/Precedence.roc:16` | T-SV41, T-SV44; fuzz semver-order |
| M7 | build metadata used in order | `Semver.roc:88` | T-SV43, T-SV47; fuzz semver-order |
| M8 | more identifiers is before (11.4.4) | `Internal/Precedence.roc:32` | T-SV41, T-SV44, T-SV48 |
| M9 | alphanumeric compare reversed | `Internal/Precedence.roc:47` | T-SV41, T-SV44, T-SV51 |
| M10 | leading zero accepted in M.m.p | `Internal/Lex.roc:12` | T-SV7, T-SV21 |
| M11 | leading zero accepted in numeric pre-release | `Internal/Lex.roc:22` | T-SV26 |
| M12 | U64 overflow wraps (times) | `Internal/Lex.roc:55` | not caught |
| M13 | U64 overflow wraps (plus) | `Internal/Lex.roc:56` | T-SV52; T-VR48 |
| M14 | upper case letters not valid in identifiers | `Internal/Lex.roc:63` | T-SV25, T-SV30, T-SV36, T-SV50, T-SV51; fuzz semver-order; fuzz semver-roundtrip |
| M15 | empty first identifier is EmptySegment always | `Internal/Lex.roc:70` | T-SV9, T-SV11 |
| M16 | build rejects leading zero | `Internal/Lex.roc:26` | T-SV30, T-SV36, T-SV43; fuzz semver-roundtrip |
| M17 | new swaps minor and patch | `Semver.roc:24` | T-SV19, T-SV20, T-SV34, T-SV37; fuzz req-caret; fuzz semver-order |
| M18 | parse ignores suffix | `Semver.roc:43` | T-SV6, T-SV23, T-SV29, T-SV33 |
| M19 | parse_lazy drops the rest | `Semver.roc:72` | T-SV6, T-SV19, T-SV23, T-SV29, T-SV33 |
| M20 | empty text error tag | `Semver.roc:62` | T-SV1 |
| M21 | minor error tag is patch tag | `Semver.roc:67` | T-SV3, T-SV21, T-SV52 |
| M22 | to_str: build before pre-release | `Semver.roc:80` | T-SV35, T-SV36; fuzz semver-roundtrip |
| M23 | to_str: pre-release joined with - | `Semver.roc:78` | T-SV53, T-SV36, T-SV44; fuzz semver-roundtrip |
| M24 | major accessor gives minor | `Semver.roc:93` | T-SV12, T-SV13, T-SV14, T-SV15, T-SV16, T-SV17 (+7 more); T-VR3, T-VR11, T-VR13, T-VR14, T-VR15, T-VR16 (+23 more); fuzz req-caret; fuzz semver-roundtrip |
| M25 | minor accessor gives patch | `Semver.roc:96` | T-SV12, T-SV13, T-SV14, T-SV15, T-SV16, T-SV17 (+2 more); T-VR3, T-VR13, T-VR14, T-VR15, T-VR16, T-VR18 (+18 more); fuzz req-caret; fuzz semver-roundtrip |
| M26 | patch accessor gives major | `Semver.roc:99` | T-SV17, T-SV18, T-SV24, T-SV25, T-SV27, T-SV30 (+2 more); T-VR3, T-VR14, T-VR22, T-VR23, T-VR29, T-VR30 (+5 more); fuzz req-caret; fuzz semver-roundtrip |
| M27 | pre_release accessor gives build | `Semver.roc:103` | T-SV13, T-SV14, T-SV15, T-SV16, T-SV17, T-SV18 (+5 more); T-VR45, T-VR50 |
| M28 | build accessor gives pre_release | `Semver.roc:107` | T-SV13, T-SV14, T-SV15, T-SV16, T-SV17, T-SV18 (+5 more) |
| M29 | ^1.2.3 upper is <1.3.0 | `Internal/Comparator.roc:213` | T-VR16, T-VR29; fuzz req-caret |
| M30 | ^0.2.3 upper is <1.0.0 | `Internal/Comparator.roc:215` | T-VR14, T-VR15, T-VR29; fuzz req-caret |
| M31 | ^0.0.3 upper is <0.1.0 | `Internal/Comparator.roc:218` | T-VR30; fuzz req-caret |
| M32 | ^0 upper is <0.1.0 | `Internal/Comparator.roc:210` | T-VR32, T-VR35; fuzz req-caret |
| M33 | ^0.0 upper is <1.0.0 | `Internal/Comparator.roc:211` | T-VR31, T-VR35; fuzz req-caret |
| M34 | ^1.2 upper is <1.3.0 | `Internal/Comparator.roc:211` | T-VR13, T-VR21, T-VR43; fuzz req-caret |
| M35 | caret upper past U64 max not End | `Internal/Comparator.roc:224` | T-VR49 |
| M36 | bare 1.2 is exact (1.2.x) | `Internal/Comparator.roc:82` | T-VR21; fuzz req-caret |
| M37 | bare 3 parts is caret | `Internal/Comparator.roc:81` | T-VR22 |
| M38 | bare wildcard is caret | `Internal/Comparator.roc:82` | T-VR18, T-VR34 |
| M39 | X not a wildcard | `Internal/Comparator.roc:144` | T-VR34, T-VR47 |
| M40 | * not a wildcard | `Internal/Comparator.roc:144` | T-VR4, T-VR7, T-VR24, T-VR26, T-VR27, T-VR33 (+4 more) |
| M41 | 2.x.x: no skip of .x | `Internal/Comparator.roc:105` | T-VR33 |
| M42 | x.x.x: skip only one .x | `Internal/Comparator.roc:99` | not caught |
| M43 | = with fewer parts uses caret upper | `Internal/Comparator.roc:165` | T-VR18, T-VR22, T-VR23, T-VR34, T-VR36 |
| M44 | > is >= | `Internal/Comparator.roc:166` | T-VR37, T-VR38, T-VR39, T-VR49, T-VR51 |
| M45 | >= is > | `Internal/Comparator.roc:167` | T-VR35, T-VR37, T-VR39, T-VR41, T-VR51 |
| M46 | < is <= | `Internal/Comparator.roc:168` | T-VR37, T-VR38, T-VR39, T-VR41, T-VR43, T-VR51 |
| M47 | <= is < | `Internal/Comparator.roc:169` | T-VR35, T-VR37, T-VR38, T-VR39, T-VR49, T-VR51 |
| M48 | ~1.2.3 upper is <2.0.0 | `Internal/Comparator.roc:202` | T-VR40 |
| M49 | ~1 upper is <1.1.0 | `Internal/Comparator.roc:200` | T-VR40 |
| M50 | operator order: > before >= | `Internal/Comparator.roc:64` | T-VR9, T-VR35, T-VR37, T-VR39, T-VR41, T-VR45 (+4 more) |
| M51 | > on partial: next of minor is next major | `Internal/Comparator.roc:191` | T-VR18, T-VR19, T-VR26, T-VR34, T-VR35, T-VR36 (+1 more) |
| M52 | >* matches all (Any next is lowest) | `Internal/Comparator.roc:189` | T-VR7, T-VR24, T-VR34, T-VR51 |
| M53 | no space after operator | `Internal/Comparator.roc:33` | T-VR43 |
| M54 | no space at start | `Internal/Comparator.roc:31` | T-VR9, T-VR41, T-VR43, T-VR44, T-VR50 |
| M55 | pre-release versions can match | `VersionReq.roc:91` | T-VR45, T-VR50 |
| M56 | pre-release bound not below release | `Internal/Comparator.roc:192` | not caught |
| M57 | BuildMetadataNotAllowed check removed | `Internal/Comparator.roc:35` | T-VR9 |
| M58 | comma list is OR | `VersionReq.roc:91` | T-VR41, T-VR43 |
| M59 | limit 33 | `VersionReq.roc:96` | T-VR42 |
| M60 | limit check > (33 allowed) | `VersionReq.roc:102` | T-VR42 |
| M61 | comparator error index + 1 | `VersionReq.roc:105` | T-VR9 |
| M62 | star matches nothing above 1.0.0 | `Internal/Comparator.roc:16` | T-VR2 |
| M63 | VersionReq.parse ignores suffix | `VersionReq.roc:53` | T-VR10, T-VR12, T-VR28, T-VR52 |
| M64 | VersionReq.parse_lazy drops the rest | `VersionReq.roc:79` | T-VR10, T-VR11, T-VR12, T-VR28, T-VR52 |
| M65 | VersionReq.to_str joins with , | `VersionReq.roc:84` | T-VR44 |
| M66 | Comparator text drops the operator | `Internal/Comparator.roc:39` | T-VR5, T-VR44, T-VR47 |
| M67 | matches ignores lower bound | `Internal/Comparator.roc:50` | T-VR13, T-VR14, T-VR15, T-VR16, T-VR17, T-VR18 (+19 more); fuzz req-caret |
