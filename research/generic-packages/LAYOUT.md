# Generic package repository layout

The layout for the 4 generic packages (`roc-app-header`, `roc-semver`, `roc-base58`, `roc-toml`, R-GP1 to R-GP7) on the pinned compiler `nightly-2026-10-09-258ab27`.

| Item | Value |
| --- | --- |
| Date | 2026-10-16 |
| Compiler | `cloudflare-workers/.cache/nightlies/nightly-2026-10-09-258ab27/roc`, for every check here. The roc-syntax MCP `roc_check` has no `roc` on its PATH. Its corpus is checked against `nightly-2026-10-11-7d256b9` (its `corpus/language/UPSTREAM`). |
| Probe | `layout-probe/`: a package with 2 public modules (`Hex`, `Pair`), 1 hidden module, 1 URL dependency (roc-parser), 2 test apps, 2 fuzz targets. `layout-probe/run.sh [ROC]` does all checks of this file from an empty cache (13 s) and ends with `ALL AS EXPECTED`. |
| Cache | `run.sh` sets `XDG_CACHE_HOME` and `ROC_CACHE_DIR` to `layout-probe/.work/xdg`, an absolute path with no `..` (roc bug `PathOutsideWorkspace`). |

## 1. Layout

```text
roc-<name>/
  package/main.roc          package header: public modules, URL dependencies
  package/<Type>.roc        one public type module per file
  package/Internal/<T>.roc  hidden modules (not in the header)
  tests/<module>.roc        L0: one test app for each public module
  fuzz/<property>.roc       L1: one roc-fuzz target for each property
  fuzz/seeds/, fuzz/dictionaries/   optional roc-fuzz inputs
  examples/<name>.roc       optional, runnable apps
  scripts/all_tests.sh      check, fmt, L0, L1 fast, bundle
  .roc-version              nightly-2026-10-09-258ab27
  LICENSE, README.md
```

| Path | Writer (TW18) | In the bundle |
| --- | --- | --- |
| `package/**` | Code agent. The test agent writes the first stubs (`crash "todo"`) and the signatures. | Yes, when `main.roc` reaches it by imports |
| `tests/**` | Test agent only | No |
| `fuzz/**` | Test agent only | No |
| `examples/**`, `scripts/**` | Human or test agent | No |

The rule for TW18 is a rule of paths: a code agent changes nothing outside `package/`. The compiler does not enforce it.

Why `package/` and not the root or `src/`:

| Option | Evidence | Result |
| --- | --- | --- |
| `package/` | roc-lang/http, roc-lang/path, lukewilliamboswell/roc-parser, ageron/roc-package-template (all `package/main.roc`) | Chosen. Most real repos use it. |
| `src/` | roc-syntax MCP topic `write_package` | Works. Same bundle hash. |
| Root (`main.roc` next to `tests/`) | `run.sh` probe, `.work/bv/root` | Works. Same bundle hash (`ECKEjhWq...`), because the bundle has only the imported files. Code and tests are mixed in one directory, so the TW18 path rule is harder. |

## 2. Header templates

`package/main.roc`:

```roc
package
	[
		Hex,
		Pair,
	]
	{
		parser: "https://github.com/lukewilliamboswell/roc-parser/releases/download/2.0.0/7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW.tar.zst",
	}
```

| Rule | Evidence |
| --- | --- |
| The list names the public type modules. A module that is not in the list is hidden. | `tests/` app with `import pkg.Nibble`: "package module is private" (exit 1) |
| A dependency is a release URL. No path dependency to another package. | `roc bundle` with `parser: "../rp/main.roc"`: "outside the entry point directory" (`run.sh` step 5) |
| No `roc:` pin in the header | roc-syntax `write_package`. `.roc-version` holds the pin. |

`package/Hex.roc` (a public type module that imports a hidden module):

```roc
import Internal/Nibble as Nibble

## Lowercase hex text for bytes.
Hex :: [].{

	## Two lowercase hex digits for each byte.
	encode : List(U8) -> Str
	encode = |bytes| Str.from_utf8(bytes.fold([], |acc, b| acc.append(Nibble.to_ascii(b // 16)).append(Nibble.to_ascii(b % 16)))) ?? ""

	## The bytes of hex text. Stub from the test agent, body from the code agent.
	decode : Str -> Try(List(U8), [BadHex])
	decode = |_text| crash "todo"
}
```

`package/Pair.roc` (uses the dependency): `import parser.Parser` and `import parser.Utf8`. Do not write `exposing [Parser]`.

`tests/hex.roc` (L0 test app):

```roc
app [main!] { pkg: "../package/main.roc" }

import pkg.Hex

main! = |_args| Ok({})

# R-XX1: decode accepts both cases
expect Hex.decode("00fFaB") == Ok([0, 255, 171])
```

`main!` is necessary. With `app [] { ... }` and no `main!`, `roc test` passes but `roc check` gives 1 error.

`fuzz/hex-roundtrip.roc` (L1 target):

```roc
app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	pkg: "../package/main.roc",
}

import fuzz.Fuzz
import pkg.Hex

## decode(encode(b)) gives b back
target = Fuzz.target_with({
	name: "hex-roundtrip",
	generator: Fuzz.bytes,
	test: |bytes| if Hex.decode(Hex.encode(bytes)) == Ok(bytes) Fuzz.keep else crash "round trip failed",
	show: Str.inspect,
})
```

For several values, use a nominal input with `generator_for` and the `.Fuzz` record builder (`layout-probe/fuzz/pair-props.roc`: `{ text: Fuzz.str, n: Fuzz.u64 }.Fuzz`). Generators used here: `Fuzz.bytes`, `Fuzz.str`, `Fuzz.u64`. The relative path `../package/main.roc` is in the same repository. roc-parser does the same (`fuzz/csv-roundtrip.roc`: `parser: "../package/main.roc"`).

## 3. Commands

Run from the repository root. `ROC` is the pinned binary.

| Step | Command | Pass | Fail |
| --- | --- | --- | --- |
| Check | `roc check package/main.roc` | exit 0, "No errors found" | exit 1 (error), exit 2 (warnings only) |
| Format | `roc fmt --check package tests fuzz` | exit 0 | exit 1, names the files |
| L0 | `for f in tests/*.roc; do roc test "$f" --no-cache; done` | exit 0, `All (4) tests passed in 28.8 ms.` | exit 1, see below |
| L1 build | `roc build --fuzz fuzz/<p>.roc --output=.work/fuzz/<p>` | exit 0. 6.5 s cold (platform download), 0.5 s warm | |
| L1 run | `.work/fuzz/<p> run --runs=100000 --seed=1 --time=0 --artifact-dir=.work/fuzz/art-<p>` | exit 0, `Done 100000 runs in 0 second(s)` | exit 77 |
| L1 replay | `.work/fuzz/<p> replay <saved file>`, `.work/fuzz/<p> show <saved file>` | | replay exit 77. `show` prints the typed value (`[238]`). |
| Bundle | `mkdir -p dist && roc bundle package/main.roc --output-dir dist` | `Created: dist/<hash>.tar.zst` | The output dir must exist: "error.FileNotFound" |
| List bundle | `zstd -dc dist/*.tar.zst \| tar -t` | | |
| Docs | `roc docs package/main.roc --output=.work/docs` | exit 0. `index.html`, one `<Module>/index.html` for each public module | |
| Deps | `roc deps package/main.roc` | the tree, with transitive URL packages | |

`roc test` report when a test fails (stub `decode = |_text| crash "todo"`):

```text
── ✗ fail ──────────── .work/stub/tests/hex.roc:11:1
expect Hex.decode("00fFaB") == Ok([0, 255, 171])
Roc application crashed with this message:
	todo
Ran 4 tests in 21.9 ms.:
    1 passed
    3 failed
    0 compiler errors
```

| `roc test` fact | Evidence |
| --- | --- |
| One file for each call. It runs the file, the modules it imports, and the `expect`s of path dependencies (so also an `expect` in `package/`). Not the `expect`s of URL packages. | `roc test --help` |
| `--verbose` prints one `PASS: <file>:<line>` for each test | probe |
| Results are cached. `--no-cache` runs all again. | `roc test --help` |
| The stub compiles (check exit 0) and the tests are red (exit 1, "todo") | `run.sh` step 2 |
| A wrong value: exit 1, `3 passed, 1 failed` | probe, `.work/wrong` |
| `--runs` alone stops at the count. `--time` has a default of 60 s, so give `--time=0` too: then only the count stops it (TW6). | `<target> --help`, probe |

## 4. Dependency by release URL

| Item | Value |
| --- | --- |
| roc-parser 2.0.0 | `https://github.com/lukewilliamboswell/roc-parser/releases/download/2.0.0/7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW.tar.zst` (`gh release view 2.0.0 -R lukewilliamboswell/roc-parser`, published 2026-10-01, Latest) |
| Its dependency | `https://github.com/roc-lang/unicode/releases/download/4.2.0/4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w.tar.zst` (`roc deps`) |
| `roc check` cold | 3.0 s, downloads both, exit 0 |
| Newer | `2.1.0-rc.1` (prerelease, 2026-10-16). Not tested. |
| roc-fuzz 0.4.3 | `https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst` (Latest, 2026-10-05) |

## 5. Bundle and hash

| Fact | Evidence |
| --- | --- |
| Files: `main.roc` and each `.roc` file that `main.roc` reaches by imports, with their paths (`Internal/Nibble.roc`). A `.roc` file that nothing imports is not in the bundle. | probe bundle: `main.roc Hex.roc Internal/Nibble.roc Pair.roc` |
| A list of files (roc-lang/http `scripts/bundle.sh` style) gives the same bundle when the list has only imported modules | `.work/bv/d1`, same hash |
| A non-`.roc` file (LICENSE) is in the bundle only when it is in the command and inside `package/`. It changes the hash. | `4KhnmTiV...` with LICENSE. Outside `package/`: "outside the entry point directory" |
| Tar entries have mtime 0 and owner 0. The hash does not depend on the directory name or path. | Same `ECKEjhWqeHFcpCRx9RQ65Vvsq7sM5jCxCk1dUpZLJMgU` from `package/`, `.work/variants/package` (with test files in it) and a root layout |
| Hash = base58 (Bitcoin alphabet) of BLAKE3-256 of the bytes of the compressed `.tar.zst` file | `layout-probe/tools/bundle_hash.roc` gives the file name for the probe bundle and for the roc-parser 2.0.0 release asset |
| `--compression` (default 3) changes the bytes, so it changes the hash. Use the default. | `roc bundle --help` |

## 6. Hidden modules: an alternative test layout

A test app in `tests/` cannot import a hidden module. If a test must reach one, a headerless file in `package/tests/` works:

```roc
import /Hex
import /Internal/Nibble as Nibble

expect Nibble.to_ascii(10) == 'a'
```

| Command | Result |
| --- | --- |
| `roc test package/tests/all.roc --main=package/main.roc` | exit 0, 3 tests. `--main` resolves the URL dependencies. |
| The same with no `--main` | exit 1. `/Pair` is then read from the dir of the test file ("package/tests/Pair.roc: FileNotFound"). A file in `package/` with `import Pair` and no `--main` gives 1 compiler error: the URL dependency is not resolved. |
| `roc bundle package/main.roc` | Same hash: nothing imports the test file |
| `roc test package/main.roc` | Does not run it (not imported) |

Risk: a bundle made from a file list (`package/*.roc`) can include it. The recommended layout keeps `tests/` outside `package/` and tests hidden modules through the public functions.

## 7. Problems and open points

| Id | Point |
| --- | --- |
| LP1 | Hidden modules are not reachable from `tests/`. Recommendation: test them through the public API. Use section 6 only if a rule needs it. Human decision. |
| LP2 | `roc test` takes one file. `scripts/all_tests.sh` loops over `tests/*.roc`. |
| LP3 | A test app also runs each `expect` in `package/`. TW18 is a path rule, and a code agent that adds an `expect` in `package/` is not stopped by the tool. |
| LP4 | LICENSE in the bundle: not decided. It must be in `package/` and named in the `roc bundle` command, and it changes the hash. |
| LP5 | `roc check` of a stub gives exit 2 when a parameter is unused (`|text| crash "todo"`). Stubs use `_text`. |
| LP6 | `research/core-shape/README.md` says a fuzz target imports from its own dir. With a package path dependency (`pkg: "../package/main.roc"`) that is not a limit. |
| LP7 | The roc-syntax MCP `roc_check` has no compiler. Agents use the pinned binary, or run `roc-syntax-mcp roc use <pinned roc>`. |
