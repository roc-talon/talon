import Args
import Clock
import Download
import Fail
import Item
import JsonDoc
import Nightlies
import Pin
import Roots
import TalonFile
import Temp
import Text
import toml.Toml
import toml.Value

## The pure decisions of `tln roc install <id>` (slice 021, CLI 6.2, 6.6, 7.4, 7.5): which compiler asset fits the machine, the paths and the commands of
## one install, the check of the sha256, the `.talon.json` text, the compat id, the global default, and the texts. The command code is `RocInstall`.
## The bodies are the work of the code agent. The contract is in the doc comments (tables). Texts and `data` fields are a proposal (R-OUT2, TW24).
##
## The layout of one install (R-CC4 step 6, R-LY1, R-DA4). `<item>` is `<cache>/toolchains/<id>`, `<hex>` is 16 hex digits (`Temp.hex(Fx.random!())`):
##
## | Path | Content |
## | --- | --- |
## | `<item>.<hex>.tmp/` | The temp dir (R-CC1). Only the lock holder writes it. `Temp.of_item` finds the stale ones (R-CC4 step 5). |
## | `<item>.<hex>.tmp/<asset name>` | The download (R-DA4). It is deleted after `tar` ran. |
## | `<item>.<hex>.tmp/roc` | The compiler (`roc.exe` for a Windows host). The real archive has one top dir `roc_nightly-<target>-<date>-<sha>/` with `LICENSE`, `legal_details` and `roc`, so `tar` runs with `--strip-components=1`. |
## | `<item>.<hex>.tmp/.talon.json` | Written last (R-CC4 step 6, R-LY1) |
## | `<cache>/talon/tmp/<hex>/empty.roc` | The empty file for the compat check (R-GC10). The dir `talon/tmp/<hex>` is deleted when the install ends (R-CC2). |
Toolchain :: [].{

	## The system of the machine (`Fx.platform!`).
	Platform : { os : [Linux, Macos, Windows, Other(Str)], arch : [X64, Arm64, Other(Str)] }

	## R-CV8: the host of a system. Linux x64 `LinuxX64`, Linux arm64 `LinuxArm64`, macOS arm64 `MacosApple`, macOS x64 `MacosX64`, Windows x64 `WindowsX64`, Windows arm64 `WindowsArm64`.
	## Any other system is a failure of kind `Environment` (exit 18): `no compiler asset exists for <os> <arch>`. The names are `linux`, `macos`, `windows`, `x64`, `arm64`, and the text of an `Other`.
	host : Platform -> Try(Nightlies.Host, Fail)
	host = |system| match (system.os, system.arch) {
		(Linux, X64) => Ok(LinuxX64)
		(Linux, Arm64) => Ok(LinuxArm64)
		(Macos, Arm64) => Ok(MacosApple)
		(Macos, X64) => Ok(MacosX64)
		(Windows, X64) => Ok(WindowsX64)
		(Windows, Arm64) => Ok(WindowsArm64)
		_ => Err(Fail.new(Environment, "no compiler asset exists for ${os_name(system.os)} ${arch_name(system.arch)}"))
	}

	## The operand of `tln roc install` (R-CM15, R-R8): the text that names the compiler, as typed (`nightly-2026-10-09-258ab27`, a prefix, `@latest`). The checks, in order:
	##
	## | # | Case | Failure (kind `Usage`, exit 2) |
	## | --- | --- | --- |
	## | 1 | No operand | `tln roc install needs one compiler: a full id, a prefix or @latest` |
	## | 2 | 2 operands or more | `tln roc install takes one compiler, got <n>` |
	##
	## `--git` is slice 045. `Args.parse` accepts it, and this function does not look at it.
	read : Args -> Try(Str, Fail)
	read = |args| match args.operands {
		[one] => Ok(one)
		[] => Err(Fail.new(Usage, "tln roc install needs one compiler: a full id, a prefix or @latest"))
		many => Err(Fail.new(Usage, "tln roc install takes one compiler, got ${many.len().to_str()}"))
	}

	## The 2 lists for `Nightlies.pick` from the list of the host (R-SC10, R-SL5, R-NS4, R-C7). `named` is the id of each candidate (`Nightlies.candidates`), in the list order: a name is not
	## limited by `min-release-age` (R-NS4). `auto` is the id of each candidate that `Nightlies.visible` keeps for `min_age` (no snapshot, no `keep` id), in the list order. `now` and
	## `min_age` are in seconds.
	##
	## Slice 022 (R-NS3, R-NS4, R-NS2): `nightly` is the value of the `nightly` switch (`Pin.switch`). With `nightly` false `auto` is empty (the domain is the releases only and there is none: R-NS2), and `named` is
	## the same (a name is not limited by the switch, R-NS4).
	domain : { releases : List(Nightlies.Release), now : U64, min_age : U64, nightly : Bool } -> { named : List(Str), auto : List(Str) }
	domain = |facts| {
		found = Nightlies.candidates(facts.releases)
		shown = Nightlies.visible({ list: found, now: facts.now, min_age: facts.min_age, snapshot: Err(None), keep: [] })
		{ named: found.map(|r| r.id), auto: if facts.nightly shown.map(|r| r.id) else [] }
	}

	## Why `pick` found no compiler (review of slice 021, Q6). It is `Nightlies.failure` of the error, with one change:
	##
	## | Error | Text |
	## | --- | --- |
	## | `NoMatch(text)` and `text` is the exact id of a release in `releases` that has no asset for the host (`Err(NoAsset)`) | `<id> has no asset for <target>` (`Usage`, exit 2), `<target>` is `Nightlies.target(host)` |
	## | `NoMatch(text)` of a prefix, of an id that is not in the list, or of a release with 2 assets (question Q10) | `no compiler matches <text>` |
	## | Any other error | `Nightlies.failure(error)` |
	##
	## Slice 022 (Q5 of slice 020, R-NS2): `Empty` with the switch off is kind `NoTuple` (exit 10) and names the switch and its source: `no compiler release is known, and nightly is false (set by <source text>)`.
	## `<source text>` is `Pin.source_text(switch.source)`. `Empty` with the switch on is `Nightlies.failure(Empty)` as before (a list that `min-release-age` or the cache empties). The other errors do not read `switch`.
	pick_failed : { error : Nightlies.PickError, releases : List(Nightlies.Release), host : Nightlies.Host, switch : { nightly : Bool, source : Pin.Source } } -> Fail
	pick_failed = |facts| match facts.error {
		Empty if !facts.switch.nightly => Fail.new(NoTuple, "no compiler release is known, and nightly is false (set by ${Pin.source_text(facts.switch.source)})")
		NoMatch(text) => if has_no_asset(facts.releases, text) {
			Fail.new(Usage, "${text} has no asset for ${Nightlies.target(facts.host)}")
		} else {
			Nightlies.failure(facts.error)
		}
		other => Nightlies.failure(other)
	}

	## The paths of one install. All paths are absolute. `asset` is the name of the asset (`Nightlies.Asset.name`). `roc` ends with `/roc`, and with `/roc.exe` for `WindowsX64` and `WindowsArm64`.
	##
	## | Field | Value |
	## | --- | --- |
	## | `id` | The id |
	## | `item` | `Roots.item(Toolchain(id))`. It is also the item of the lock (R-CC3 point 4: the lock dir is `<item>.lock`). |
	## | `temp` | `Temp.name({ target: item, hex })` |
	## | `archive` | `<temp>/<asset>` |
	## | `roc` | `<temp>/roc` or `<temp>/roc.exe` |
	## | `meta` | `<temp>/.talon.json` |
	## | `probe_dir` | `Roots.item(TalonTmp(hex))` |
	## | `probe_file` | `<probe_dir>/empty.roc` |
	Plan : { id : Str, item : Str, temp : Str, archive : Str, roc : Str, meta : Str, probe_dir : Str, probe_file : Str }
	plan : { roots : Roots, host : Nightlies.Host, id : Str, asset : Str, hex : Str } -> Plan
	plan = |facts| {
		dir = Roots.item(facts.roots, Item.Toolchain(facts.id))
		temp = Temp.name({ target: dir, hex: facts.hex })
		probe = Roots.item(facts.roots, Item.TalonTmp(facts.hex))
		program = match facts.host {
			WindowsX64 | WindowsArm64 => "roc.exe"
			_ => "roc"
		}
		{
			id: facts.id,
			item: dir,
			temp,
			archive: Text.join(temp, facts.asset),
			roc: Text.join(temp, program),
			meta: Text.join(temp, ".talon.json"),
			probe_dir: probe,
			probe_file: Text.join(probe, "empty.roc"),
		}
	}

	## R-HF5, R-SE9: the command line of the extract, as the program and its arguments, with no quoting: `tar -xf <archive> -C <dir> --strip-components=1`. The same line reads `.tar.gz` and
	## `.zip` (the Windows `tar` reads `.zip`). `tar` refuses a member name with `..` (R-SE9).
	tar_command : { archive : Str, dir : Str } -> List(Str)
	tar_command = |facts| ["tar", "-xf", facts.archive, "-C", facts.dir, "--strip-components=1"]

	## R-HF2: the command line that sets the executable bit: `chmod 0755 <file>`. A Windows host needs none: `Err(NotNeeded)`.
	chmod_command : { host : Nightlies.Host, file : Str } -> Try(List(Str), [NotNeeded])
	chmod_command = |facts| match facts.host {
		WindowsX64 | WindowsArm64 => Err(NotNeeded)
		_ => Ok(["chmod", "0755", facts.file])
	}

	## R-CV4: the sha256 of the asset before the download. A `Err(None)` digest (a missing digest, a null, or any other form: `Nightlies.Asset`) is a failure of kind `Integrity` (exit 16):
	## `the asset of <id> has no sha256 digest. Talon does not install it.` (question Q2). Else the 64 hex digits.
	require_digest : { id : Str, asset : Nightlies.Asset } -> Try(Str, Fail)
	require_digest = |facts| match facts.asset.sha256 {
		Ok(digits) => Ok(digits)
		Err(None) => Err(Fail.new(Integrity, "the asset of ${facts.id} has no sha256 digest. Talon does not install it."))
	}

	## R-CV4: the check of the file that the download wrote. `want` and `got` are 64 lower case hex digits. Equal: `Ok`. Else a failure of kind `Integrity` (exit 16):
	## `sha256 of <id> differs: expected <want>, got <got>. Talon deleted the download.` There is no override.
	check_download : { id : Str, want : Str, got : Str } -> Try({}, Fail)
	check_download = |facts| if facts.want == facts.got {
		Ok({})
	} else {
		Err(Fail.new(Integrity, "sha256 of ${facts.id} differs: expected ${facts.want}, got ${facts.got}. Talon deleted the download."))
	}

	## R-DA7: the failure of a download child that ended with an error (the form of `Fetch.download_failed`, with no hint about `tln audit`). `outcome` is `Download.outcome`.
	##
	## | Outcome | Kind and text |
	## | --- | --- |
	## | `Http(Ok(status))` | `Network`: `download of <id> failed: <status> (<url>)` |
	## | `Http(Err(Unknown))` | `Network`: `download of <id> failed: HTTP error (<url>)` |
	## | `Failed`, `NotStarted(text)` | `Environment` (exit 18): `cannot run <program>: <text>` (R-HF12). `<program>` is `curl` or `wget`. |
	## | `Failed`, another end | `Network`: `download of <id> failed: <last line> (<url>)`. With an empty last line: `<program> exited with code <n>`, or `<program> was stopped by signal <n>`, in its place. |
	download_failed : { id : Str, url : Str, program : Download.Program, ended : Download.Ended, outcome : [Http(Try(U16, [Unknown])), Failed], last_line : Str } -> Fail
	download_failed = |facts| {
		name = program_name(facts.program)
		match (facts.outcome, facts.ended) {
			(Http(Ok(status)), _) => Fail.new(Network, "download of ${facts.id} failed: ${status.to_str()} (${facts.url})")
			(Http(Err(Unknown)), _) => Fail.new(Network, "download of ${facts.id} failed: HTTP error (${facts.url})")
			(Failed, NotStarted(text)) => Fail.new(Environment, "cannot run ${name}: ${text}")
			(Failed, ended) => {
				why = if facts.last_line.is_empty() ended_text(name, ended) else facts.last_line
				Fail.new(Network, "download of ${facts.id} failed: ${why} (${facts.url})")
			}
		}
	}

	## R-SE9, R-HF5: the failure of `tar`. `NotStarted(text)`: kind `Environment` (exit 18), `cannot run tar: <text>`. Any other end: kind `Integrity` (exit 16, question Q3),
	## `tar rejected <id> (<url>): <last line>`, with `exit code <n>` or `tar was stopped by signal <n>` in place of an empty last line.
	tar_failed : { id : Str, url : Str, ended : Download.Ended, last_line : Str } -> Fail
	tar_failed = |facts| match facts.ended {
		NotStarted(text) => Fail.new(Environment, "cannot run tar: ${text}")
		ended => {
			why = if facts.last_line.is_empty() ended_text("tar", ended) else facts.last_line
			Fail.new(Integrity, "tar rejected ${facts.id} (${facts.url}): ${why}")
		}
	}

	## R-DI12 (question Q5): `--offline` and the compiler is not installed. Kind `Network` (exit 15): `<id> is not installed and --offline is set`.
	offline_missing : Str -> Fail
	offline_missing = |id| Fail.new(Network, "${id} is not installed and --offline is set")

	## R-DI12 (question Q5): `--offline`, the compiler is not installed, and no page of the list is cached. Kind `Network` (exit 15): `no cached list of compilers and --offline is set`.
	offline_no_list : {} -> Fail
	offline_no_list = |{}| Fail.new(Network, "no cached list of compilers and --offline is set")

	## R-GC10: the compat id. `before` and `after` are the lists of the build root (`Fx.list_dirs!` of `Roots.build`) before and after `roc check` of an empty file. An entry is touched when
	## it is a dir whose name starts with `compat-` and it is not in `before` (a new dir), or it is in `before` with a smaller `mtime`. One touched dir: `Ok(<name without compat->)`.
	## None: `Err(Unknown)`. 2 or more: `Err(Several(<names without compat->, in byte order>))`. `roc check` of an empty file exits 1 and still makes the dir (measured, 2026-10-22).
	learn_compat : { before : List({ name : Str, is_dir : Bool, mtime : U64 }), after : List({ name : Str, is_dir : Bool, mtime : U64 }) } -> Try(Str, [Unknown, Several(List(Str))])
	learn_compat = |facts| {
		touched = facts.after.keep_if(|e| e.is_dir and e.name.starts_with("compat-") and is_touched(facts.before, e))
		match Text.sorted(touched.map(|e| e.name.drop_prefix("compat-"))) {
			[] => Err(Unknown)
			[one] => Ok(one)
			many => Err(Several(many))
		}
	}

	## R-CV5, R-LY1, R-TF1: the text of `.talon.json`: `TalonFile.render` with `format` 1 and these fields, in this order (a proposal):
	##
	## | Key | Value |
	## | --- | --- |
	## | `id` | The id |
	## | `url` | The URL of the asset |
	## | `sha256` | The 64 digits |
	## | `sha256_source` | `github-digest` (`direct`). The registry form `registry` is P2. |
	## | `typed` | The text that the user typed (`@latest`, a prefix, the id) |
	## | `compat` | The compat id, or `null` for `Unknown` and `Several` |
	## | `installed_at` | `Clock.format_utc(now)` (the time of Talon, `TALON_NOW`) |
	## | `published_at` | Slice 022 (Q5 of the review): `Clock.format_utc(published_at)`, the GitHub `published_at` of the release (R-NS1). The last key. `Compiler.times` reads it, so rank 4 orders the installed compilers with no network. |
	meta : { id : Str, url : Str, sha256 : Str, typed : Str, compat : Try(Str, [Unknown, Several(List(Str))]), now : U64, published_at : U64 } -> Str
	meta = |facts| {
		compat = match facts.compat {
			Ok(id) => JsonDoc.Text(id)
			Err(_) => JsonDoc.Null
		}
		TalonFile.render({
			format: 1,
			fields: [
				("id", JsonDoc.Text(facts.id)),
				("url", JsonDoc.Text(facts.url)),
				("sha256", JsonDoc.Text(facts.sha256)),
				("sha256_source", JsonDoc.Text("github-digest")),
				("typed", JsonDoc.Text(facts.typed)),
				("compat", compat),
				("installed_at", JsonDoc.Text(Clock.format_utc(facts.now))),
				("published_at", JsonDoc.Text(Clock.format_utc(facts.published_at))),
			],
		})
	}

	## R-SO15, R-LY4: the edit of `config.toml` that makes the first compiler the global default. `text` is the file (the empty text when it does not exist). The key `default-roc` in any form
	## is "set": `Keep`, no write. Else `Set(<new text>)`: the new text has the line `default-roc = "<id>"` added by the span edit of `roc-toml` (`Toml.insert`): every other byte stays. The empty text gives
	## the one line and a line end. A text that is not TOML is a failure of kind `Input` (exit 19): `<path>:<line>: not valid TOML` (as `Intent.read_config`).
	default_edit : { path : Str, text : Str, id : Str } -> Try([Keep, Set(Str)], Fail)
	default_edit = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(doc) => match Toml.get(doc, ["default-roc"]) {
			Ok(_) => Ok(Keep)
			Err(NotFound) => match Toml.insert(doc, ["default-roc"], Value.String(facts.id)) {
				Ok(done) => Ok(Set(done.to_str()))
				Err(_) => Err(Fail.new(Internal, "${facts.path}: cannot add default-roc"))
			}
		}
	}

	## R-DA6, R-NR2: a size for a person: below 1000 `<n> B`, below 1000000 `<x.y> KB`, else `<x.y> MB` (decimal, one digit after the point, rounded to the nearest tenth).
	## 999 is `999 B`, 1000 is `1.0 KB`, 1500000 is `1.5 MB`, 73861067 is `73.9 MB`.
	size_text : U64 -> Str
	size_text = |bytes| if bytes < 1000 {
		"${bytes.to_str()} B"
	} else if bytes < 999_950 {
		"${tenths_text((bytes + 50) // 100)} KB"
	} else {
		"${tenths_text((bytes + 50_000) // 100_000)} MB"
	}

	## The text of a finished run (R-OUT2, a proposal). `how` is `Installed` (this run put the compiler there) or `Present` (it was there, step 1 or step 4 of R-CC4). `default` is `Set` when this run
	## wrote `default-roc` (R-SO15), else `Kept`. `compat` is the answer of `learn_compat` for an install, and `Err(Unknown)` for `Present`, which has no warning.
	##
	## | Line | Stream | When |
	## | --- | --- | --- |
	## | `installed <id>` | stdout | `Installed` |
	## | `<id> is already installed` | stdout | `Present` |
	## | `<id> is now the default compiler` | stdout | `Set` |
	## | `warning: the compat id of <id> is not known: roc check touched no compat dir` | stderr | `Installed` and `Unknown` |
	## | `warning: the compat id of <id> is not known: roc check touched <n> compat dirs (<a>, <b>)` | stderr | `Installed` and `Several` |
	##
	## Each line ends with `\n`. The stdout lines are `Info` for `--quiet` (R-FL4), the warning is not.
	report : { id : Str, how : [Installed, Present], default : [Set, Kept], compat : Try(Str, [Unknown, Several(List(Str))]) } -> { stdout : List(Str), stderr : List(Str) }
	report = |facts| {
		first = match facts.how {
			Installed => "installed ${facts.id}\n"
			Present => "${facts.id} is already installed\n"
		}
		now_default = match facts.default {
			Set => ["${facts.id} is now the default compiler\n"]
			Kept => []
		}
		warning = |why| "warning: the compat id of ${facts.id} is not known: ${why}\n"
		warnings = match (facts.how, facts.compat) {
			(Installed, Err(Unknown)) => [warning("roc check touched no compat dir")]
			(Installed, Err(Several(names))) => [warning("roc check touched ${names.len().to_str()} compat dirs (${Str.join_with(names, ", ")})")]
			_ => []
		}
		{ stdout: [first].concat(now_default), stderr: warnings }
	}

	## R-J3, R-J4, R-OUT4: the `data` of `--json`, the keys in this order: `id` (text), `path` (the install dir `item`), `installed` (true when this run installed it), `default` (true when this run set the default).
	data : { id : Str, item : Str, how : [Installed, Present], default : [Set, Kept] } -> JsonDoc
	data = |facts| JsonDoc.Obj([
		("id", JsonDoc.Text(facts.id)),
		("path", JsonDoc.Text(facts.item)),
		("installed", JsonDoc.Flag(facts.how == Installed)),
		("default", JsonDoc.Flag(facts.default == Set)),
	])
}

os_name : [Linux, Macos, Windows, Other(Str)] -> Str
os_name = |os| match os {
	Linux => "linux"
	Macos => "macos"
	Windows => "windows"
	Other(name) => name
}

arch_name : [X64, Arm64, Other(Str)] -> Str
arch_name = |arch| match arch {
	X64 => "x64"
	Arm64 => "arm64"
	Other(name) => name
}

program_name : Download.Program -> Str
program_name = |program| match program {
	Curl => "curl"
	Wget => "wget"
}

ended_text : Str, Download.Ended -> Str
ended_text = |program, ended| match ended {
	Exited(code) => "${program} exited with code ${code.to_str()}"
	Signaled(code) => "${program} was stopped by signal ${code.to_str()}"
	NotStarted(text) => "cannot run ${program}: ${text}"
}

# R-CV2: the id is a release of the list that has no asset for the host.
has_no_asset : List(Nightlies.Release), Str -> Bool
has_no_asset = |releases, text| releases.any(
	|r| match r.asset {
		Err(NoAsset) => r.id == text
		_ => Bool.False
	},
)

# R-GC10: a dir that is new, or that has a later time than before.
is_touched : List({ name : Str, is_dir : Bool, mtime : U64 }), { name : Str, is_dir : Bool, mtime : U64 } -> Bool
is_touched = |before, entry| match before.find_first(|b| b.name == entry.name) {
	Ok(old) => old.mtime < entry.mtime
	Err(NotFound) => Bool.True
}

# `<x>.<y>` for a number of tenths.
tenths_text : U64 -> Str
tenths_text = |tenths| "${(tenths // 10).to_str()}.${(tenths % 10).to_str()}"
