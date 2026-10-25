import Fail
import Nightlies
import Roots

## The pure decisions of the Zig dependency of a source build (slice 044, CLI 6.6, R-D1 to R-D4, R-EV11, R-EV16, R-EV21): which Zig fits a commit, where Talon finds it, which archive of the Zig index
## it installs, the paths and the text of one install, and the text of the dependency list. The command code is `ZigInstall`. The bodies are the work of the code agent. The contract is in the doc
## comments (tables). Texts and `.talon.json` fields that the design does not give are a proposal (R-OUT2, TW24): `docs/slices/044-zig.md`, section "Output".
##
## What `minimum_zig_version` and the index give (R-D4, R-D2):
##
## | Text | Form | Example |
## | --- | --- | --- |
## | `need` | The text of `minimum_zig_version` in `build.zig.zon`. A release `X.Y.Z`, or a dev version `X.Y.Z-dev.<n>+<hash>`. | `0.17.0` |
## | series | The `major.minor` of a version. Zig changes its API between minor versions, so a Zig fits when its series is the series of `need` (R-D4). The patch and the suffix do not count. | `0.17` |
## | index | `https://ziglang.org/download/index.json`: one JSON object. A key is `master` or a release `X.Y.Z`. A release has the keys `date`, `docs`, `src` and one object for each target (`x86_64-linux`, `aarch64-macos`, `x86_64-windows`, ...) with `tarball` (URL), `shasum` (sha256, 64 hex digits) and `size` (a text of digits). | `"0.17.0": { "x86_64-linux": { "tarball": "https://ziglang.org/download/0.17.0/zig-x86_64-linux-0.17.0.tar.xz", "shasum": "ab12...", "size": "54227812" } }` |
##
## The layout of one install (R-CC4 steps 5 and 6, R-LY1: the same steps as a compiler). `<item>` is `<cache>/toolchains/zig-<version>`, `<hex>` is 16 hex digits (`Temp.hex(Fx.random!())`):
##
## | Path | Content |
## | --- | --- |
## | `<item>.<hex>.tmp/` | The temp dir (R-CC1). Only the lock holder writes it. `Temp.of_item` finds the stale ones. |
## | `<item>.<hex>.tmp/<archive name>` | The download (R-DA4). It is deleted after `tar` ran. |
## | `<item>.<hex>.tmp/zig` | The Zig program (`zig.exe` for a Windows host). The real archive has one top dir `zig-<target>-<version>/` with `zig`, `lib/`, `doc/` and `LICENSE`, so `tar` runs with `--strip-components=1`. |
## | `<item>.<hex>.tmp/.talon.json` | Written last (R-CC4 step 6) |
Zig :: [].{

	## The series of a version (R-D4).
	Series : { major : U64, minor : U64 }

	## Where a Zig was found (R-D1): `Env` is the program that `ZIG` names, `Path` is `zig` on `PATH`, `Installed` is a dir `zig-<version>` of Talon in `toolchains/`.
	Source : [Env, Path, Installed]

	## A Zig that Talon looked at. `version` is the text that `zig version` printed (first line, trimmed), or the version of the dir name for `Installed`. `Err(Unknown)`: the program did not run, or it exited with an error.
	Candidate : { source : Source, path : Str, version : Try(Str, [Unknown]) }

	## The Zig that the search chose.
	Found : { source : Source, path : Str, version : Str }

	## The result of `search`. `Missing(reason)`: no candidate fits. `reason` is the text of the `[ ]` line of the dependency list (R-D3).
	Search : [Found(Found), Missing(Str)]

	## The archive that the index gives for one version and one host (R-D2). `archive` is the last segment of `url`.
	Entry : { version : Str, url : Str, sha256 : Str, size : U64, archive : Str }

	## The paths of one install. All paths are absolute. `zig` ends with `/zig`, and with `/zig.exe` for a Windows host.
	Plan : { version : Str, item : Str, temp : Str, archive : Str, zig : Str, meta : Str }

	## R-EV11: the program that `ZIG` names. An empty value is the same as no value (as `Net.from_env`).
	env_zig : List((Str, Str)) -> Try(Str, [NotSet])
	env_zig = |_env| crash "todo: slice 044"

	## R-EV16, R-EV21: the URL of the Zig index: `TALON_ZIG_INDEX` when it is set (not empty), else `https://ziglang.org/download/index.json`. The archive URLs come from the answer, not from this URL.
	index_url : List((Str, Str)) -> Str
	index_url = |_env| crash "todo: slice 044"

	## R-D4: the Zig version that a commit needs. `text` is the file `build.zig.zon`. The value is the text in the quotes of the key `.minimum_zig_version`: the key starts a line (white space before it is allowed),
	## and white space around `=` is allowed. A line that starts with `//` is a comment and is not read. The first line with the key gives the value. No such line: `Err(NoKey)` (question Q3: the caller does not know what to do).
	##
	## | Line | Result |
	## | --- | --- |
	## | `.minimum_zig_version = "0.15.2",` | `Ok("0.15.2")` |
	## | `.minimum_zig_version="0.17.0-dev.31+abc",` | `Ok("0.17.0-dev.31+abc")` |
	## | `// .minimum_zig_version = "0.1.0",` | not read |
	minimum : Str -> Try(Str, [NoKey])
	minimum = |_text| crash "todo: slice 044"

	## R-D4: the series of a version text. The text before the first `-` is split at `.`: the first 2 parts must be decimal numbers. The 3rd part and the suffixes (`-dev.31`, `+abc`) are not read.
	##
	## | Text | Result |
	## | --- | --- |
	## | `0.17.0`, `0.17.9`, `0.17.0-dev.31+abc` | `Ok({ major: 0, minor: 17 })` |
	## | `1.2.3` | `Ok({ major: 1, minor: 2 })` |
	## | the empty text, `0`, `a.b.c`, `0.x.1` | `Err(BadVersion)` |
	series : Str -> Try(Series, [BadVersion])
	series = |_text| crash "todo: slice 044"

	## The series of `need` as the dependency list and the messages write it: `0.17.0` gives `0.17.x`. A text that is no version stays as it is.
	wanted : Str -> Str
	wanted = |_need| crash "todo: slice 044"

	## R-D1: the dirs of Talon that hold a Zig, as candidates with `source` `Installed`. `entries` is the list of `<cache>/toolchains` (`Fx.list_dirs!`). An entry counts when it is a dir and its name is `zig-<version>`
	## with a release version `X.Y.Z` (3 numbers). So a file `zig-0.17.1`, a temp dir `zig-0.17.0.<16hex>.tmp`, a lock dir `zig-0.17.0.lock`, a trash dir and any compiler dir are not Zig. `path` is `<item>/zig`
	## (`zig.exe` for a Windows host), `version` is `Ok(<version>)`. The result is in byte order of the names (the listing has no order, TW2).
	installed : { roots : Roots, host : Nightlies.Host, entries : List({ name : Str, is_dir : Bool, mtime : U64 }) } -> List(Candidate)
	installed = |_facts| crash "todo: slice 044"

	## R-D1: the Zig that Talon uses. The order is `Env`, then `Path`, then `Installed`, whatever the order of `candidates`. The first candidate of that order whose version has the series of `need` is `Found`.
	## A candidate with `version` `Err(Unknown)` never fits. The candidates of one source keep the order of `candidates`. Of 2 fitting candidates of one source (installed dirs only), the first one wins: question Q2 (is the newest wanted?),
	## the tests give at most one fitting candidate for each source.
	## `Missing(reason)`: the `describe` text of the first candidate of the order, else `zig not found`. A candidate with `version` `Err(Unknown)` counts as the first one too (its text says that the version is not known).
	##
	## Question Q1 (not tested): an `Env` candidate whose version does not fit. R-D1 says "a matching version" only for `PATH`.
	search : { need : Str, candidates : List(Candidate) } -> Search
	search = |_facts| crash "todo: slice 044"

	## The words of a candidate in the dependency list (R-D3, a proposal, TW24):
	##
	## | Source | Version known | Text |
	## | --- | --- | --- |
	## | `Env` | `Ok(v)` | `found zig <v> in $ZIG` |
	## | `Path` | `Ok(v)` | `found zig <v> on PATH` |
	## | `Installed` | `Ok(v)` | `found zig <v> installed by Talon` |
	## | `Env` | `Err(Unknown)` | `found zig in $ZIG, its version is not known` |
	## | `Path` | `Err(Unknown)` | `found zig on PATH, its version is not known` |
	## | `Installed` | `Err(Unknown)` | `found zig installed by Talon, its version is not known` |
	describe : { source : Source, version : Try(Str, [Unknown]) } -> Str
	describe = |_facts| crash "todo: slice 044"

	## R-D2: the key of the Zig index for a host (the same hosts as `Toolchain.host`):
	##
	## | Host | Key |
	## | --- | --- |
	## | `LinuxX64`, `LinuxArm64` | `x86_64-linux`, `aarch64-linux` |
	## | `MacosX64`, `MacosApple` | `x86_64-macos`, `aarch64-macos` |
	## | `WindowsX64`, `WindowsArm64` | `x86_64-windows`, `aarch64-windows` |
	target : Nightlies.Host -> Str
	target = |_host| crash "todo: slice 044"

	## R-D2: the archive of the release that fits `need`, for `host`, from the text of the index. The releases that count are the keys `X.Y.Z` (3 numbers) with the series of `need`. The key `master` never counts, also
	## when its `version` has the series of `need`. With 2 or more such releases the choice is question Q2 (the tests give one). Then the object of `target(host)` gives `tarball`, `shasum` and `size`.
	## The failures (the kinds and the texts are a proposal, TW24). `<series>` is `wanted(need)`, `<key>` is `target(host)`:
	##
	## | Case | Failure |
	## | --- | --- |
	## | The text is not JSON, or not an object | `Network` (15): `the Zig index is not a JSON object` |
	## | No key is a release of the series | `Environment` (18): `the Zig index has no release of zig <series>` |
	## | The release has no object for `<key>`, or the object has no `tarball` | `Environment` (18): `the Zig index has no archive of zig <version> for <key>` |
	## | `shasum` is missing, or it is not 64 lower case hex digits | `Integrity` (16): `the Zig index has no sha256 for zig <version> (<key>). Talon does not install it.` (R-CV4, R-D2: no sha256, no install) |
	##
	## `size` is the value of `size` as a number: a text of digits (as the real index gives it) or a number. Any other value gives 0.
	pick : { index : Str, need : Str, host : Nightlies.Host } -> Try(Entry, Fail)
	pick = |_facts| crash "todo: slice 044"

	## The program of an installed Zig: `zig`, or `zig.exe` for a Windows host.
	exe : Nightlies.Host -> Str
	exe = |_host| crash "todo: slice 044"

	## The paths of one install (the table at the top). `item` is `Roots.item(Zig(version))` (also the item of the lock: R-CC3 point 4, the lock dir is `<item>.lock`). `temp` is `Temp.name({ target: item, hex })`.
	## `archive` is `<temp>/<archive name>`, `zig` is `<temp>/<exe(host)>`, `meta` is `<temp>/.talon.json`.
	plan : { roots : Roots, host : Nightlies.Host, version : Str, archive : Str, hex : Str } -> Plan
	plan = |_facts| crash "todo: slice 044"

	## R-EC18, R-HF5: does `tar` need `xz` for this archive? A `.tar.xz` on a Linux host needs it. macOS has a `tar` that reads `.tar.xz`, and a Windows host gets a `.zip`.
	##
	## | Host | Archive | Result |
	## | --- | --- | --- |
	## | `LinuxX64`, `LinuxArm64` | ends with `.tar.xz` | `True` |
	## | `LinuxX64` | any other end (`.zip`) | `False` |
	## | `MacosX64`, `MacosApple` | `.tar.xz` | `False` |
	## | `WindowsX64`, `WindowsArm64` | `.zip`, `.tar.xz` | `False` |
	needs_xz : { host : Nightlies.Host, archive : Str } -> Bool
	needs_xz = |_facts| crash "todo: slice 044"

	## R-CC4 step 6, R-TF1: the text of `.talon.json` of a Zig: `TalonFile.render` with `format` 1 and these fields, in this order (a proposal, TW24):
	##
	## | Key | Value |
	## | --- | --- |
	## | `id` | `zig-<version>` (the name of the dir) |
	## | `url` | The URL of the archive |
	## | `sha256` | The 64 digits of the index |
	## | `sha256_source` | `zig-index` |
	## | `installed_at` | `Clock.format_utc(now)` (the time of Talon, `TALON_NOW`) |
	meta : { version : Str, url : Str, sha256 : Str, now : U64 } -> Str
	meta = |_facts| crash "todo: slice 044"

	## R-D3: the dependency list that a source build prints to stderr, before the prompt (a proposal for the exact layout, TW24). The text starts with `Dependencies:` and every line ends with a line end.
	## A row is 2 spaces, `[x]` (found) or `[ ]` (missing), a space, the name padded with spaces to 22 characters, and the text:
	##
	## | Row | Name | Text |
	## | --- | --- | --- |
	## | Zig, `search` is `Found(f)` | `zig <series>` (`zig 0.17.x`: `wanted(need)`) | `describe` of `f` |
	## | Zig, `search` is `Missing(reason)` | the same | `reason` |
	## | LLVM bundle | `LLVM bundle`, always `[ ]` | `<target>, <size>, zig gets it during the build`. `size` is `Toolchain.size_text`. With `Err(Unknown)` there is no size and no second comma: `<target>, zig gets it during the build`. |
	##
	## The LLVM line gives the size of the `roc-lang/roc-bootstrap` asset for the host (R-D3). Where `llvm.target` and `llvm.size` come from is question Q4: the caller gives them.
	deps : { need : Str, search : Search, llvm : { target : Str, size : Try(U64, [Unknown]) } } -> Str
	deps = |_facts| crash "todo: slice 044"
}
