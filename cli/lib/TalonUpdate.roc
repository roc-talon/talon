import Args
import Clock
import Fail
import GitRef
import JsonDoc
import Setup
import Text
import ToolGit
import ToolUpdate
import ToolsJson

## The pure decisions of `tln tool update talon` (slice 050, CLI 6.5: R-S2, R-S3, R-S1, R-T9, R-T22, R-ST9, R-ST10, R-SE13, R-IS2, R-FL12). Part A (TESTING.md 2.2). The command code is `TalonUpdateFlow` (part 050b, with `--from-source`). This module, `ToolsJson` and `ToolManage` are part 050a. The texts and the `data` fields are proposals (R-OUT2, TW24): the human accepts or changes them at the review.
##
## ```mermaid
## flowchart TD
##     A["releases of roc-talon/talon (GitHub list, R-DI2)"] --> B["releases: tag v<X.Y.Z>, no draft, no prerelease, the asset of this target and sha256sums.txt"]
##     B --> C["pick: newest release in min-release-age that has the asset (R-T9). Not newer than the installed: Current (no downgrade)"]
##     C -->|"Newer"| D["download tln-<target> and sha256sums.txt (R-DA3, R-DA4)"]
##     D --> E["check_download: sha256 of the file against sha256sums.txt (R-S1, R-SE13)"]
##     E --> F["chmod 0755 (R-HF2), run tln --version on the temp file: version_check (R-S3)"]
##     F --> G["under the lock of tools.json: entries (R-ST6, R-ST11), del_moves on Windows (R-ST10), rename over the old file, the bin dir entries tln and roc again (R-ST9), the talon entry"]
## ```
TalonUpdate :: [].{

	## The full name of Talon (CLI 6.5: `<releases>` is `https://github.com/roc-talon/talon/releases`) and the name of the entry in `tools.json` (R-IS6).
	name : Str
	name = "roc-talon/talon"

	## Is this the operand of `tool update talon`: exactly one operand, `talon` or `roc-talon/talon` (no selector: `talon@1` is a failure of `ToolManage.read`, R-CM19)?
	is_target : Args -> Bool
	is_target = |args| match args.operands {
		[one] => one == "talon" or one == "roc-talon/talon"
		_ => Bool.False
	}

	## One release of the list that is a candidate for this machine (R-IS2): `version` is the tag without the `v` (`0.3.2`), `published_at` is in seconds since the epoch (R-DI10). `bin` is the asset of the target (name `tln-x64musl`, `tln-x64win.exe`), `sums` is the URL of `sha256sums.txt`.
	Release : { version : Str, tag : Str, published_at : U64, bin : Try({ url : Str, size : U64 }, [NoAsset]), sums : Try(Str, [NoSums]) }

	## R-IS2: the name of the release asset for this machine: `tln-<target>`, with `.exe` on Windows. `target` is `BuildSkip.target` (`x64musl`, `arm64musl`, `x64mac`, `arm64mac`, `x64win`). Windows on ARM64 runs the x64 binary, so `platform!` says `X64` there.
	asset_name : { os : Setup.Os, target : Str } -> Str
	asset_name = |facts| if facts.os == Windows "tln-${facts.target}.exe" else "tln-${facts.target}"

	## R-DI3, R-DI10, R-IS2: the releases of the pages of the GitHub list, in the order of the pages. `asset` is `asset_name`. A release is left out when it is a draft or a prerelease, or when its tag is not `v` and 3 numbers (`v0.3.2`; `nightly`, `v0.3.2-rc1`, `0.3.2`).
	## A page that is not a JSON array of objects, a release with no text `tag_name`, and a release that is not left out and has no `published_at` that `Clock.parse_utc` reads, is `Err(BadPage(n))` (`n` is 1-based). `bin` and `sums` are the assets with exactly those names (a release with no such asset is still in the list: `pick` decides).
	releases : { pages : List(Str), asset : Str } -> Try(List(Release), [BadPage(U64)])
	releases = |facts| facts.pages.map_with_index(|text, i| (i + 1, text)).fold_try(
		[],
		|found, (n, text)| match JsonDoc.parse(text) {
			Ok(Arr(items)) => items.fold_try(found, |acc, item| read_release(facts.asset, acc, item).map_err(|_| BadPage(n)))
			_ => Err(BadPage(n))
		},
	)

	## R-T9, R-C7, R-S2: the release to install. `current` is the installed version (`current`). The first row that holds wins:
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | No release has the asset of this machine | Kind `Usage` (exit 2): `roc-talon/talon has no release with <asset>` |
	## | 2 | No release with the asset is old enough (`published_at + min_age <= now`, as `ToolInstall.pick`) | Kind `Usage`: `no release of roc-talon/talon is old enough for min-release-age` |
	## | 3 | The highest version of the old enough releases (numbers, `0.10.0` is above `0.9.0`; the first of a tie) is above `current` | `Newer(release)` |
	## | 4 | Any other (the same version, or a lower one: no downgrade, R-S4) | `Current(release)`: the newest old enough release (`--from-source` builds its tag) |
	pick : { list : List(Release), now : U64, min_age : U64, current : Str, asset : Str } -> Try([Newer(Release), Current(Release)], Fail)
	pick = |facts| {
		with_asset = facts.list.keep_if(|r| r.bin.is_ok())
		if with_asset.is_empty() {
			return Err(Fail.new(Usage, "${TalonUpdate.name} has no release with ${facts.asset}"))
		}
		old_enough = with_asset.keep_if(|r| r.published_at + facts.min_age <= facts.now)
		match old_enough.first() {
			Err(_) => Err(Fail.new(Usage, "no release of ${TalonUpdate.name} is old enough for min-release-age"))
			Ok(first) => {
				best = old_enough.fold(first, |top, r| if compare_versions(numbers(r.version), numbers(top.version)) == After r else top)
				if compare_versions(numbers(best.version), numbers(facts.current)) == After Ok(Newer(best)) else Ok(Current(best))
			}
		}
	}

	## The installed version: the version of the entry `talon` of `tools.json` (a prebuilt entry: its version; a source build: the version of its tag ref, `v0.3.2` is `0.3.2`), else `running` (`Help.version`: no entry, or a source build of another ref).
	current : { entry : Try(ToolsJson.Talon, [None]), running : Str } -> Str
	current = |facts| match facts.entry {
		Ok(talon) => match talon.source {
			Prebuilt(pre) => pre.version
			Git(git) => tag_version(git.ref) ?? facts.running
		}
		Err(None) => facts.running
	}

	## R-S1, R-SE13: the sha256 that `sha256sums.txt` gives for the file `name`. A line is `<64 lower case hex digits>`, white space, then the name, with `*` before it in the binary mode of `sha256sum`; a line end can be `\r\n`. The first line with that name wins; a line in another form is ignored.
	expected_sha : { sums : Str, name : Str } -> Try(Str, [NotListed])
	expected_sha = |facts| facts.sums.split_on("\n").fold(
		Err(NotListed),
		|found, line| match found {
			Ok(_) => found
			Err(NotListed) => match sum_line(line) {
				Ok(parsed) if parsed.name == facts.name => Ok(parsed.sha)
				_ => found
			}
		},
	)

	## R-S1, R-SE13, R-DA4: the file that was downloaded has the sha256 of the release. `want` is from `expected_sha`, `got` is `sha256_file!`. A difference is kind `Integrity` (exit 16): `<name> of roc-talon/talon <tag>: the sha256 is <got>, but sha256sums.txt says <want>. tln is not changed.`
	check_download : { tag : Str, name : Str, want : Str, got : Str } -> Try({}, Fail)
	check_download = |facts| if facts.got == facts.want {
		Ok({})
	} else {
		Err(Fail.new(Integrity, "${facts.name} of ${TalonUpdate.name} ${facts.tag}: the sha256 is ${facts.got}, but sha256sums.txt says ${facts.want}. tln is not changed."))
	}

	## R-S1, R-SE13: the failures for the checksum file, both kind `Integrity` (exit 16). `unlisted`: `sha256sums.txt of <tag> does not list <name>, so tln cannot check it. tln is not changed.` `missing`: `the release <tag> of roc-talon/talon has no sha256sums.txt, so tln cannot check <name>. tln is not changed.`
	unlisted : { tag : Str, name : Str } -> Fail
	unlisted = |facts| Fail.new(Integrity, "sha256sums.txt of ${facts.tag} does not list ${facts.name}, so tln cannot check it. tln is not changed.")

	missing : { tag : Str, name : Str } -> Fail
	missing = |facts| Fail.new(Integrity, "the release ${facts.tag} of ${TalonUpdate.name} has no sha256sums.txt, so tln cannot check ${facts.name}. tln is not changed.")

	## R-S3: `tln --version` on the temp file. `ended` is how the child ended (`spawn_all!`). `Exited(0)` is a binary that starts: `Ok`. Any other end is kind `Internal` (exit 1): `the new tln <version> does not start (<why>). The old tln stays.` with `<why>` `exit <n>`, `signal <n>` or `not started: <text>`. The output of the child is not read (question Q-V1).
	version_check : { version : Str, ended : [Exited(I32), Signaled(I32), NotStarted(Str)] } -> Try({}, Fail)
	version_check = |facts| match facts.ended {
		Exited(0) => Ok({})
		Exited(n) => Err(not_started(facts.version, "exit ${n.to_str()}"))
		Signaled(n) => Err(not_started(facts.version, "signal ${n.to_str()}"))
		NotStarted(why) => Err(not_started(facts.version, "not started: ${why}"))
	}

	## R-HF2: the command line that sets the executable bit of the temp file: `chmod 0755 <file>`. Windows needs none: `Err(NotNeeded)`.
	chmod_command : { os : Setup.Os, file : Str } -> Try(List(Str), [NotNeeded])
	chmod_command = |facts| if facts.os == Windows Err(NotNeeded) else Ok(["chmod", "0755", facts.file])

	## R-ST9, R-ST6, R-ST11: which bin dir entries the update makes again. `tln` and `roc` are 2 names for one file (R-ST13, R-ST14). `tln` and `roc` are the verdicts of `ToolInstall.verdict` for the entry (`Make`: no entry, or an entry with the sha256 of the file that is replaced; `Foreign`: any other file). `bin` is the bin dir.
	##
	## | `tln` | `roc` | Result |
	## | --- | --- | --- |
	## | `Foreign` | any | Kind `Usage` (exit 2): `ToolUpdate.foreign_failure` of the path of the `tln` entry. Nothing is downloaded. |
	## | `Make` | `Make` | `make` is `tln` and `roc` (with `.exe` on Windows), no warning |
	## | `Make` | `Foreign` | `make` is `tln`. `roc` is kept (R-ST6) with the warning of `kept_warning` (question Q-E1) |
	entries : { os : Setup.Os, bin : Str, tln : [Make, Foreign], roc : [Make, Foreign] } -> Try({ make : List(Str), warnings : List(Str) }, Fail)
	entries = |facts| {
		suffix = if facts.os == Windows ".exe" else ""
		tln = "tln${suffix}"
		roc = "roc${suffix}"
		if facts.tln == Foreign {
			return Err(ToolUpdate.foreign_failure("${facts.bin}/${tln}"))
		}
		match facts.roc {
			Make => Ok({ make: [tln, roc], warnings: [] })
			Foreign => Ok({ make: [tln], warnings: [TalonUpdate.kept_warning("${facts.bin}/${roc}")] })
		}
	}

	## R-ST6, R-ST2 (question Q-E1, proposal): the warning for a `roc` entry that tln did not write and keeps: `warning: <path> is not a file that tln wrote, so tln keeps it. Run: tln setup --replace-roc`.
	kept_warning : Str -> Str
	kept_warning = |path| "warning: ${path} is not a file that tln wrote, so tln keeps it. Run: tln setup --replace-roc"

	## R-ST10: the name that a running `.exe` is renamed to before it is replaced: the path without `.exe`, then `.<16hex>.del`, in the same dir (`/b/tln.exe` is `/b/tln.0123456789abcdef.del`, R-IS5). `hex` is `Temp.hex` of the random number of the run (one number for the temp name and the `.del` names). The path can have `/` or `\`.
	del_name : { path : Str, hex : Str } -> Str
	del_name = |facts| "${facts.path.drop_suffix(".exe")}.${facts.hex}.del"

	## R-ST10, R-S3: the renames before the new file goes in. `files` are the paths of the files that exist and are replaced (the data file, and each bin dir entry that `entries` makes). Windows: one rename of each file to its `del_name`, in the order of `files`. Linux and macOS: none (a `rename` over a running binary works).
	del_moves : { os : Setup.Os, hex : Str, files : List(Str) } -> List({ from : Str, to : Str })
	del_moves = |facts| if facts.os == Windows facts.files.map(|path| { from: path, to: TalonUpdate.del_name({ path, hex: facts.hex }) }) else []

	## R-ST10: is the name of a file that of a `.del` file: `<name>.<16 lower case hex digits>.del`, with a name that is not empty.
	is_del : Str -> Bool
	is_del = |file| if file.ends_with(".del") {
		bytes = file.drop_suffix(".del").to_utf8()
		size = bytes.len()
		size > 17 and bytes.drop_first(size - 17).take_first(1) == [46] and bytes.drop_first(size - 16).all(is_hex_digit)
	} else {
		Bool.False
	}

	## R-ST10: the `.del` files of a directory (`list_dirs!`): the full paths, in byte order, of the entries that are files and have a `.del` name. (Each start of `tln` deletes them: the call of this choice is not in this slice, question Q-W1.) `dir` is the dir that was listed.
	stale : { dir : Str, entries : List({ name : Str, is_dir : Bool, mtime : U64 }) } -> List(Str)
	stale = |facts| Text.sorted(facts.entries.keep_if(|e| !e.is_dir and TalonUpdate.is_del(e.name)).map(|e| "${facts.dir}/${e.name}"))

	## R-S3, R-OUT2 (proposal): the lines of the command. `talon <version> is up to date` (stdout). `updated talon <old> to <new> (roc-talon/talon)`; `<new>` is `ToolManage.source_text` of the new entry (`0.3.2`, or `git v0.3.2@dd03c09e` for a source build).
	up_to_date_text : Str -> Str
	up_to_date_text = |version| "talon ${version} is up to date"

	updated_text : { old : Str, new : Str } -> Str
	updated_text = |facts| "updated talon ${facts.old} to ${facts.new} (${TalonUpdate.name})"

	## R-DI12 (proposal): the failure of a `--offline` update that needs the download. Kind `Network` (exit 15): `tln <version> is not downloaded and --offline is set. Run the command without --offline.`
	offline_failure : Str -> Fail
	offline_failure = |version| Fail.new(Network, "tln ${version} is not downloaded and --offline is set. Run the command without --offline.")

	## R-J3, R-J4, R-OUT4 (proposal): the outcome for `ToolUpdate.data`. `old` is the installed version, `new` is the text after the update (the same as `old` when up to date). The `data` is that of `tool update`: `{"tools":[{"tool":"talon","name":"roc-talon/talon","how":"updated","from":"0.3.1","to":"0.3.2"}]}`.
	outcome : { old : Str, new : Str, how : [Updated, UpToDate] } -> ToolUpdate.Outcome
	outcome = |facts| match facts.how {
		Updated => { tool: "talon", name: TalonUpdate.name, how: Updated, from: Ok(facts.old), to: facts.new }
		UpToDate => { tool: "talon", name: TalonUpdate.name, how: UpToDate, from: Err(None), to: facts.new }
	}

	## R-S2, R-T4: the `talon` entry after a prebuilt update. The source is `Prebuilt` with the version and the URL of the asset (question Q-S1). `hashes` is `[]` and `nightly` is `""`: no compiler built it. `now` is the time of the run, `installed_at` is `Clock.format_utc` of it.
	prebuilt_entry : { release : Release, url : Str, sha256 : Str, target : Str, now : U64 } -> ToolsJson.Talon
	prebuilt_entry = |facts| {
		source: Prebuilt({ version: facts.release.version, url: facts.url }),
		hashes: [],
		nightly: "",
		target: facts.target,
		sha256: facts.sha256,
		libs: [],
		installed_at: Clock.format_utc(facts.now),
	}

	## R-S2 (question Q-F1): what `--from-source` builds: the source archive of the tag of the release, `roc-talon/talon` at `v<version>`, in the dir `cli` (the app `cli/main.roc`).
	source_of : Release -> { source : GitRef.Source, path : Try(Str, [None]) }
	source_of = |release| { source: { owner: "roc-talon", repo: "talon", ref: release.tag }, path: Ok("cli") }

	## R-S2: the text of the source of an entry, for the reports and `data.to`: `0.3.2` (prebuilt) or `git v0.3.2@dd03c09e` (`ToolGit.source_text`).
	source_text : ToolsJson.TalonSource -> Str
	source_text = |source| match source {
		Prebuilt(pre) => pre.version
		Git(git) => ToolGit.source_text({ ref: git.ref, sha: git.commit })
	}
}

# R-S3: the failure for a new file that does not start.
not_started : Str, Str -> Fail
not_started = |version, why| Fail.new(Internal, "the new tln ${version} does not start (${why}). The old tln stays.")

# The 3 numbers of `X.Y.Z` (each a non-empty run of digits), else `Err(NotVersion)`.
three_numbers : Str -> Try(List(U64), [NotVersion])
three_numbers = |text| match text.split_on(".") {
	[a, b, c] => {
		parts = [a, b, c]
		if parts.all(|part| !part.is_empty() and part.to_utf8().all(|byte| byte >= 48 and byte <= 57)) Ok(parts.map(|part| U64.from_str(part) ?? 0)) else Err(NotVersion)
	}
	_ => Err(NotVersion)
}

# `v0.3.2` is `0.3.2`. Any other text has no version.
tag_version : Str -> Try(Str, [NotVersion])
tag_version = |tag| if tag.starts_with("v") {
	rest = tag.drop_prefix("v")
	match three_numbers(rest) {
		Ok(_) => Ok(rest)
		Err(NotVersion) => Err(NotVersion)
	}
} else {
	Err(NotVersion)
}

numbers : Str -> List(U64)
numbers = |version| version.split_on(".").map(|part| U64.from_str(part) ?? 0)

compare_versions : List(U64), List(U64) -> [Before, Same, After]
compare_versions = |a, b| match (a, b) {
	([x, .. as xs], [y, .. as ys]) => if x < y Before else if x > y After else compare_versions(xs, ys)
	([], []) => Same
	([], _) => Before
	(_, []) => After
}

is_hex_digit : U8 -> Bool
is_hex_digit = |byte| (byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)

# One line of `sha256sums.txt`: 64 lower case hex digits, a space or a tab, then the name (with `*` in the binary mode). A line end `\r` is cut. Any other form is `Err(Skip)`.
sum_line : Str -> Try({ sha : Str, name : Str }, [Skip])
sum_line = |raw| {
	line = raw.drop_suffix("\r")
	bytes = line.to_utf8()
	sha_bytes = bytes.take_first(64)
	rest = Str.from_utf8_lossy(bytes.drop_first(64))
	if sha_bytes.len() == 64 and sha_bytes.all(is_hex_digit) and (rest.starts_with(" ") or rest.starts_with("\t")) {
		Ok({ sha: Str.from_utf8_lossy(sha_bytes), name: rest.trim().drop_prefix("*") })
	} else {
		Err(Skip)
	}
}

# A release of a page of the list. A draft, a prerelease and a tag that is not `v` and 3 numbers are left out. The other cases that `releases` says are `Err(Bad)`.
read_release : Str, List(TalonUpdate.Release), JsonDoc -> Try(List(TalonUpdate.Release), [Bad])
read_release = |asset, found, doc| match doc {
	Obj(pairs) => {
		tag = match field(pairs, "tag_name") {
			Ok(Text(text)) => text
			_ => return Err(Bad)
		}
		flagged = is_true(pairs, "draft") or is_true(pairs, "prerelease")
		match tag_version(tag) {
			Err(NotVersion) => Ok(found)
			Ok(version) => if flagged {
				Ok(found)
			} else {
				published_at = match field(pairs, "published_at") {
					Ok(Text(text)) => Clock.parse_utc(text).map_err(|BadTime| Bad)?
					_ => return Err(Bad)
				}
				assets = match field(pairs, "assets") {
					Ok(Arr(items)) => items.keep_oks(|item| asset_of(item))
					_ => []
				}
				bin = match assets.find_first(|a| a.name == asset) {
					Ok(a) => Ok({ url: a.url, size: a.size })
					Err(_) => Err(NoAsset)
				}
				sums = match assets.find_first(|a| a.name == "sha256sums.txt") {
					Ok(a) => Ok(a.url)
					Err(_) => Err(NoSums)
				}
				Ok(found.append({ version, tag, published_at, bin, sums }))
			}
		}
	}
	_ => Err(Bad)
}

asset_of : JsonDoc -> Try({ name : Str, url : Str, size : U64 }, [NotAsset])
asset_of = |doc| match doc {
	Obj(pairs) => match (field(pairs, "name"), field(pairs, "browser_download_url")) {
		(Ok(Text(name)), Ok(Text(url))) => Ok({
			name,
			url,
			size: match field(pairs, "size") {
				Ok(Num(n)) => if n < 0 0 else n.to_u64_wrap()
				_ => 0
			},
		})
		_ => Err(NotAsset)
	}
	_ => Err(NotAsset)
}

field : List((Str, JsonDoc)), Str -> Try(JsonDoc, [NotFound])
field = |pairs, key| match pairs.find_first(|(k, _)| k == key) {
	Ok((_, value)) => Ok(value)
	Err(_) => Err(NotFound)
}

is_true : List((Str, JsonDoc)), Str -> Bool
is_true = |pairs, key| match field(pairs, key) {
	Ok(Flag(b)) => b
	_ => Bool.False
}
