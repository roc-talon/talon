import Clock
import Fail
import Item
import JsonDoc
import Nightlies
import Roots
import TalonFile
import Temp
import Text
import Toolchain

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

	## The result of `search`. `Missing(reason)`: no candidate fits. `reason` is the text of the `[ ]` line of the dependency list (R-D3). `Failed(fail)`: `ZIG` is set and its program does not run (R-D1, question Q1, answered by the manager).
	Search : [Found(Found), Missing(Str), Failed(Fail)]

	## The archive that the index gives for one version and one host (R-D2). `archive` is the last segment of `url`.
	Entry : { version : Str, url : Str, sha256 : Str, size : U64, archive : Str }

	## The paths of one install. All paths are absolute. `zig` ends with `/zig`, and with `/zig.exe` for a Windows host.
	Plan : { version : Str, item : Str, temp : Str, archive : Str, zig : Str, meta : Str }

	## R-EV11: the program that `ZIG` names. An empty value is the same as no value (as `Net.from_env`).
	env_zig : List((Str, Str)) -> Try(Str, [NotSet])
	env_zig = |env| var_of(env, "ZIG")

	## R-EV16, R-EV21: the URL of the Zig index: `TALON_ZIG_INDEX` when it is set (not empty), else `https://ziglang.org/download/index.json`. The archive URLs come from the answer, not from this URL.
	index_url : List((Str, Str)) -> Str
	index_url = |env| match var_of(env, "TALON_ZIG_INDEX") {
		Ok(url) => url
		Err(NotSet) => "https://ziglang.org/download/index.json"
	}

	## R-D4: the Zig version that a commit needs. `text` is the file `build.zig.zon`. The value is the text in the quotes of the key `.minimum_zig_version`: the key starts a line (white space before it is allowed),
	## and white space around `=` is allowed. A line that starts with `//` is a comment and is not read. The first line with the key gives the value. No such line: `Err(NoKey)` (question Q3: the caller does not know what to do).
	##
	## | Line | Result |
	## | --- | --- |
	## | `.minimum_zig_version = "0.15.2",` | `Ok("0.15.2")` |
	## | `.minimum_zig_version="0.17.0-dev.31+abc",` | `Ok("0.17.0-dev.31+abc")` |
	## | `// .minimum_zig_version = "0.1.0",` | not read |
	minimum : Str -> Try(Str, [NoKey])
	minimum = |text| text.split_on("\n").fold(
		Err(NoKey),
		|found, line| match found {
			Ok(value) => Ok(value)
			Err(NoKey) => key_value(line)
		},
	)

	## R-D4: the series of a version text. The text before the first `-` is split at `.`: the first 2 parts must be decimal numbers. The 3rd part and the suffixes (`-dev.31`, `+abc`) are not read.
	##
	## | Text | Result |
	## | --- | --- |
	## | `0.17.0`, `0.17.9`, `0.17.0-dev.31+abc` | `Ok({ major: 0, minor: 17 })` |
	## | `1.2.3` | `Ok({ major: 1, minor: 2 })` |
	## | the empty text, `0`, `a.b.c`, `0.x.1` | `Err(BadVersion)` |
	series : Str -> Try(Series, [BadVersion])
	series = |text| {
		core = match text.split_first("-") {
			Ok(parts) => parts.before
			Err(_) => text
		}
		match core.split_on(".") {
			[major, minor, ..] => match (number(major), number(minor)) {
				(Ok(a), Ok(b)) => Ok({ major: a, minor: b })
				_ => Err(BadVersion)
			}
			_ => Err(BadVersion)
		}
	}

	## The series of `need` as the dependency list and the messages write it: `0.17.0` gives `0.17.x`. A text that is no version stays as it is.
	wanted : Str -> Str
	wanted = |need| match Zig.series(need) {
		Ok(have) => "${have.major.to_str()}.${have.minor.to_str()}.x"
		Err(_) => need
	}

	## R-D1: the dirs of Talon that hold a Zig, as candidates with `source` `Installed`. `entries` is the list of `<cache>/toolchains` (`Fx.list_dirs!`). An entry counts when it is a dir and its name is `zig-<version>`
	## with a release version `X.Y.Z` (3 numbers). So a file `zig-0.17.1`, a temp dir `zig-0.17.0.<16hex>.tmp`, a lock dir `zig-0.17.0.lock`, a trash dir and any compiler dir are not Zig. `path` is `<item>/zig`
	## (`zig.exe` for a Windows host), `version` is `Ok(<version>)`. The result is in byte order of the names (the listing has no order, TW2). `search` chooses the newest version, so this order does not decide.
	installed : { roots : Roots, host : Nightlies.Host, entries : List({ name : Str, is_dir : Bool, mtime : U64 }) } -> List(Candidate)
	installed = |facts| {
		versions = facts.entries
			.keep_if(|e| e.is_dir and e.name.starts_with("zig-"))
			.map(|e| e.name.drop_prefix("zig-"))
			.keep_if(|v| is_release(v))
			|> Text.sorted
		versions.map(
			|v| {
				source: Installed,
				path: Text.join(Roots.item(facts.roots, Item.Zig(v)), Zig.exe(facts.host)),
				version: Ok(v),
			},
		)
	}

	## R-D1: the Zig that Talon uses. The order is `Env`, then `Path`, then `Installed`, whatever the order of `candidates`.
	##
	## | Case | Result |
	## | --- | --- |
	## | A candidate `Env` with `Ok(v)` | `Found` with that candidate, for any `v`. `ZIG` is the choice of the user: R-D1 asks for "a matching version" only for `zig` on `PATH`. This holds also when `Path` or `Installed` fits. |
	## | A candidate `Env` with `Err(Unknown)` (the program did not start, or `zig version` failed) | `Failed(Fail.new(Environment, "ZIG is set to <path>, but \"<path> version\" did not run"))`. Exit 18. `Path` and `Installed` are not read. |
	## | No `Env`: the first candidate of `Path`, then `Installed`, whose version has the series of `need` | `Found`. A candidate with `version` `Err(Unknown)` never fits. |
	## | Of 2 or more fitting `Installed` candidates | The newest version wins (the order of the numbers `X.Y.Z`: `0.17.10` is newer than `0.17.9`), whatever the order of `candidates`. |
	## | No candidate fits | `Missing(reason)`: the `describe` text of the first candidate of the order (`Env` is never in a `Missing`), else `zig not found`. A candidate with `version` `Err(Unknown)` counts as the first one too (its text says that the version is not known). |
	##
	## Not tested: a dev `minimum_zig_version` (design gap G1).
	search : { need : Str, candidates : List(Candidate) } -> Search
	search = |facts| {
		need = Zig.series(facts.need)
		match facts.candidates.find_first(|c| c.source == Env) {
			Ok(env) => match env.version {
				Ok(v) => Found({ source: Env, path: env.path, version: v })
				Err(Unknown) => Failed(Fail.new(Environment, "ZIG is set to ${env.path}, but \"${env.path} version\" did not run"))
			}
			Err(_) => {
				on_path = facts.candidates.keep_if(|c| c.source == Path)
				in_dirs = facts.candidates.keep_if(|c| c.source == Installed)
				match on_path.find_first(|c| fits(need, c)) {
					Ok(c) => Found({ source: Path, path: c.path, version: version_text(c) })
					Err(_) => match newest_fitting(need, in_dirs) {
						Ok(c) => Found({ source: Installed, path: c.path, version: version_text(c) })
						Err(_) => Missing(missing_reason(on_path.concat(in_dirs)))
					}
				}
			}
		}
	}

	## The words of a candidate in the dependency list (R-D3, a proposal, TW24):
	##
	## | Source | Version known | Text |
	## | --- | --- | --- |
	## | `Env` | `Ok(v)` | `found zig <v> in $ZIG` |
	## | `Env` | `Err(Unknown)` | not used: `search` gives `Failed` |
	## | `Path` | `Ok(v)` | `found zig <v> on PATH` |
	## | `Installed` | `Ok(v)` | `found zig <v> installed by Talon` |
	## | `Path` | `Err(Unknown)` | `found zig on PATH, its version is not known` |
	## | `Installed` | `Err(Unknown)` | `found zig installed by Talon, its version is not known` |
	describe : { source : Source, version : Try(Str, [Unknown]) } -> Str
	describe = |facts| match (facts.source, facts.version) {
		(Env, Ok(v)) => "found zig ${v} in $ZIG"
		(Env, Err(Unknown)) => "found zig in $ZIG, its version is not known"
		(Path, Ok(v)) => "found zig ${v} on PATH"
		(Path, Err(Unknown)) => "found zig on PATH, its version is not known"
		(Installed, Ok(v)) => "found zig ${v} installed by Talon"
		(Installed, Err(Unknown)) => "found zig installed by Talon, its version is not known"
	}

	## R-D2: the key of the Zig index for a host (the same hosts as `Toolchain.host`):
	##
	## | Host | Key |
	## | --- | --- |
	## | `LinuxX64`, `LinuxArm64` | `x86_64-linux`, `aarch64-linux` |
	## | `MacosX64`, `MacosApple` | `x86_64-macos`, `aarch64-macos` |
	## | `WindowsX64`, `WindowsArm64` | `x86_64-windows`, `aarch64-windows` |
	target : Nightlies.Host -> Str
	target = |host| match host {
		LinuxX64 => "x86_64-linux"
		LinuxArm64 => "aarch64-linux"
		MacosX64 => "x86_64-macos"
		MacosApple => "aarch64-macos"
		WindowsX64 => "x86_64-windows"
		WindowsArm64 => "aarch64-windows"
	}

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
	pick = |facts| {
		key = Zig.target(facts.host)
		pairs = match JsonDoc.parse(facts.index) {
			Ok(Obj(top)) => top
			_ => return Err(Fail.new(Network, "the Zig index is not a JSON object"))
		}
		release = match newest_release(pairs, Zig.series(facts.need)) {
			Ok(found) => found
			Err(_) => return Err(Fail.new(Environment, "the Zig index has no release of zig ${Zig.wanted(facts.need)}"))
		}
		no_archive = Fail.new(Environment, "the Zig index has no archive of zig ${release.version} for ${key}")
		target_pairs = match member(release.pairs, key) {
			Ok(Obj(inner)) => inner
			_ => return Err(no_archive)
		}
		url = match member(target_pairs, "tarball") {
			Ok(Text(text)) => text
			_ => return Err(no_archive)
		}
		sha256 = match member(target_pairs, "shasum") {
			Ok(Text(text)) if is_sha256(text) => text
			_ => return Err(Fail.new(Integrity, "the Zig index has no sha256 for zig ${release.version} (${key}). Talon does not install it."))
		}
		Ok({ version: release.version, url, sha256, size: size_of(member(target_pairs, "size")), archive: Text.last_segment(url) })
	}

	## The program of an installed Zig: `zig`, or `zig.exe` for a Windows host.
	exe : Nightlies.Host -> Str
	exe = |host| match host {
		WindowsX64 | WindowsArm64 => "zig.exe"
		_ => "zig"
	}

	## The paths of one install (the table at the top). `item` is `Roots.item(Zig(version))` (also the item of the lock: R-CC3 point 4, the lock dir is `<item>.lock`). `temp` is `Temp.name({ target: item, hex })`.
	## `archive` is `<temp>/<archive name>`, `zig` is `<temp>/<exe(host)>`, `meta` is `<temp>/.talon.json`.
	plan : { roots : Roots, host : Nightlies.Host, version : Str, archive : Str, hex : Str } -> Plan
	plan = |facts| {
		item = Roots.item(facts.roots, Item.Zig(facts.version))
		temp = Temp.name({ target: item, hex: facts.hex })
		{
			version: facts.version,
			item,
			temp,
			archive: Text.join(temp, facts.archive),
			zig: Text.join(temp, Zig.exe(facts.host)),
			meta: Text.join(temp, ".talon.json"),
		}
	}

	## R-EC18, R-HF5: does `tar` need `xz` for this archive? A `.tar.xz` on a Linux host needs it. macOS has a `tar` that reads `.tar.xz`, and a Windows host gets a `.zip`.
	##
	## | Host | Archive | Result |
	## | --- | --- | --- |
	## | `LinuxX64`, `LinuxArm64` | ends with `.tar.xz` | `True` |
	## | `LinuxX64` | any other end (`.zip`) | `False` |
	## | `MacosX64`, `MacosApple` | `.tar.xz` | `False` |
	## | `WindowsX64`, `WindowsArm64` | `.zip`, `.tar.xz` | `False` |
	needs_xz : { host : Nightlies.Host, archive : Str } -> Bool
	needs_xz = |facts| match facts.host {
		LinuxX64 | LinuxArm64 => facts.archive.ends_with(".tar.xz")
		_ => Bool.False
	}

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
	meta = |facts| TalonFile.render({
		format: 1,
		fields: [
			("id", JsonDoc.Text("zig-${facts.version}")),
			("url", JsonDoc.Text(facts.url)),
			("sha256", JsonDoc.Text(facts.sha256)),
			("sha256_source", JsonDoc.Text("zig-index")),
			("installed_at", JsonDoc.Text(Clock.format_utc(facts.now))),
		],
	})

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
	deps = |facts| {
		name = "zig ${Zig.wanted(facts.need)}"
		zig_row = match facts.search {
			Found(f) => row("x", name, Zig.describe({ source: f.source, version: Ok(f.version) }))
			Missing(reason) => row(" ", name, reason)
			Failed(fail) => row(" ", name, fail.message)
		}
		llvm_text = match facts.llvm.size {
			Ok(bytes) => "${facts.llvm.target}, ${Toolchain.size_text(bytes)}, zig gets it during the build"
			Err(Unknown) => "${facts.llvm.target}, zig gets it during the build"
		}
		"Dependencies:\n${zig_row}\n${row(" ", "LLVM bundle", llvm_text)}\n"
	}
}

# The value of an environment variable. An empty value is the same as no value (as `Net.from_env`).
var_of : List((Str, Str)), Str -> Try(Str, [NotSet])
var_of = |env, name| match env.find_first(|(key, _)| key == name) {
	Ok((_, value)) => if value.is_empty() Err(NotSet) else Ok(value)
	Err(_) => Err(NotSet)
}

# One line of `build.zig.zon`: the value of the key `.minimum_zig_version`, or no key. A comment line does not start with the key.
key_value : Str -> Try(Str, [NoKey])
key_value = |line| {
	trimmed = line.trim()
	key = ".minimum_zig_version"
	if !trimmed.starts_with(key) return Err(NoKey)
	rest = trimmed.drop_prefix(key).trim_start()
	if !rest.starts_with("=") return Err(NoKey)
	after = rest.drop_prefix("=").trim_start()
	if !after.starts_with("\"") return Err(NoKey)
	match after.drop_prefix("\"").split_first("\"") {
		Ok(parts) => Ok(parts.before)
		Err(_) => Err(NoKey)
	}
}

# Decimal digits only, at least one.
number : Str -> Try(U64, [BadVersion])
number = |text| if !text.is_empty() and text.to_utf8().all(|b| b >= 48 and b <= 57) {
	U64.from_str(text).map_err(|_| BadVersion)
} else {
	Err(BadVersion)
}

# A release version: 3 numbers.
triple : Str -> Try((U64, U64, U64), [BadVersion])
triple = |text| match text.split_on(".") {
	[a, b, c] => match (number(a), number(b), number(c)) {
		(Ok(x), Ok(y), Ok(z)) => Ok((x, y, z))
		_ => Err(BadVersion)
	}
	_ => Err(BadVersion)
}

is_release : Str -> Bool
is_release = |text| match triple(text) {
	Ok(_) => Bool.True
	Err(_) => Bool.False
}

# The numbers of a version, for the order. A version that is no release is the oldest.
order_key : Str -> (U64, U64, U64)
order_key = |text| match triple(text) {
	Ok(key) => key
	Err(_) => (0, 0, 0)
}

is_newer : (U64, U64, U64), (U64, U64, U64) -> Bool
is_newer = |a, b| a.0 > b.0 or (a.0 == b.0 and (a.1 > b.1 or (a.1 == b.1 and a.2 > b.2)))

# The series of a candidate is the series of `need`. A version that is not known never fits.
fits : Try({ major : U64, minor : U64 }, [BadVersion]), { source : [Env, Path, Installed], path : Str, version : Try(Str, [Unknown]) } -> Bool
fits = |need, c| match (need, c.version) {
	(Ok(want), Ok(v)) => match Zig.series(v) {
		Ok(have) => have == want
		Err(_) => Bool.False
	}
	_ => Bool.False
}

version_text : { source : [Env, Path, Installed], path : Str, version : Try(Str, [Unknown]) } -> Str
version_text = |c| match c.version {
	Ok(v) => v
	Err(Unknown) => ""
}

# R-D1: of the fitting installed dirs, the newest version.
newest_fitting : Try({ major : U64, minor : U64 }, [BadVersion]), List({ source : [Env, Path, Installed], path : Str, version : Try(Str, [Unknown]) }) -> Try({ source : [Env, Path, Installed], path : Str, version : Try(Str, [Unknown]) }, [NoneFits])
newest_fitting = |need, list| list.keep_if(|c| fits(need, c)).fold(
	Err(NoneFits),
	|best, c| match best {
		Err(NoneFits) => Ok(c)
		Ok(old) => if is_newer(order_key(version_text(c)), order_key(version_text(old))) Ok(c) else Ok(old)
	},
)

# R-D3: the `[ ]` text of a missing Zig is the first candidate that was looked at.
missing_reason : List({ source : [Env, Path, Installed], path : Str, version : Try(Str, [Unknown]) }) -> Str
missing_reason = |list| match list.first() {
	Ok(c) => Zig.describe({ source: c.source, version: c.version })
	Err(_) => "zig not found"
}

# The value of a key of a JSON object.
member : List((Str, JsonDoc)), Str -> Try(JsonDoc, [NoMember])
member = |pairs, name| match pairs.find_first(|(key, _)| key == name) {
	Ok((_, value)) => Ok(value)
	Err(_) => Err(NoMember)
}

# R-D2: the newest release of the series. A key is a release when it is 3 numbers. `master` and any other key are not.
newest_release : List((Str, JsonDoc)), Try({ major : U64, minor : U64 }, [BadVersion]) -> Try({ version : Str, pairs : List((Str, JsonDoc)) }, [NoRelease])
newest_release = |top, need| match need {
	Err(_) => Err(NoRelease)
	Ok(want) => top.fold(
		Err(NoRelease),
		|best, (key, doc)| match (doc, Zig.series(key), is_release(key)) {
			(Obj(inner), Ok(have), Bool.True) if have == want => match best {
				Ok(old) if !is_newer(order_key(key), order_key(old.version)) => Ok(old)
				_ => Ok({ version: key, pairs: inner })
			}
			_ => best
		},
	)
}

# D9 of slice 044: a valid `shasum` is 64 lower case hex digits.
is_sha256 : Str -> Bool
is_sha256 = |text| {
	bytes = text.to_utf8()
	bytes.len() == 64 and bytes.all(|b| (b >= 48 and b <= 57) or (b >= 97 and b <= 102))
}

# The `size` of an archive: a text of digits (as the real index) or a number. Any other value is 0.
size_of : Try(JsonDoc, [NoMember]) -> U64
size_of = |doc| match doc {
	Ok(Text(text)) => number(text) ?? 0
	Ok(Num(n)) if n >= 0 => n.to_u64_wrap()
	_ => 0
}

# One row of the dependency list: 2 spaces, the mark, the name padded to 22 characters, the text.
row : Str, Str, Str -> Str
row = |mark, name, text| {
	size = name.count_utf8_bytes()
	pad = " ".repeat(if size >= 22 0 else 22 - size)
	"  [${mark}] ${name}${pad}${text}"
}
