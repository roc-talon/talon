import Args
import Fail
import GitRef
import Setup
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
	asset_name = |_facts| crash "todo: slice 050a"

	## R-DI3, R-DI10, R-IS2: the releases of the pages of the GitHub list, in the order of the pages. `asset` is `asset_name`. A release is left out when it is a draft or a prerelease, or when its tag is not `v` and 3 numbers (`v0.3.2`; `nightly`, `v0.3.2-rc1`, `0.3.2`).
	## A page that is not a JSON array of objects, a release with no text `tag_name`, and a release that is not left out and has no `published_at` that `Clock.parse_utc` reads, is `Err(BadPage(n))` (`n` is 1-based). `bin` and `sums` are the assets with exactly those names (a release with no such asset is still in the list: `pick` decides).
	releases : { pages : List(Str), asset : Str } -> Try(List(Release), [BadPage(U64)])
	releases = |_facts| crash "todo: slice 050a"

	## R-T9, R-C7, R-S2: the release to install. `current` is the installed version (`current`). The first row that holds wins:
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | No release has the asset of this machine | Kind `Usage` (exit 2): `roc-talon/talon has no release with <asset>` |
	## | 2 | No release with the asset is old enough (`published_at + min_age <= now`, as `ToolInstall.pick`) | Kind `Usage`: `no release of roc-talon/talon is old enough for min-release-age` |
	## | 3 | The highest version of the old enough releases (numbers, `0.10.0` is above `0.9.0`; the first of a tie) is above `current` | `Newer(release)` |
	## | 4 | Any other (the same version, or a lower one: no downgrade, R-S4) | `Current(release)`: the newest old enough release (`--from-source` builds its tag) |
	pick : { list : List(Release), now : U64, min_age : U64, current : Str, asset : Str } -> Try([Newer(Release), Current(Release)], Fail)
	pick = |_facts| crash "todo: slice 050a"

	## The installed version: the version of the entry `talon` of `tools.json` (a prebuilt entry: its version; a source build: the version of its tag ref, `v0.3.2` is `0.3.2`), else `running` (`Help.version`: no entry, or a source build of another ref).
	current : { entry : Try(ToolsJson.Talon, [None]), running : Str } -> Str
	current = |_facts| crash "todo: slice 050a"

	## R-S1, R-SE13: the sha256 that `sha256sums.txt` gives for the file `name`. A line is `<64 lower case hex digits>`, white space, then the name, with `*` before it in the binary mode of `sha256sum`; a line end can be `\r\n`. The first line with that name wins; a line in another form is ignored.
	expected_sha : { sums : Str, name : Str } -> Try(Str, [NotListed])
	expected_sha = |_facts| crash "todo: slice 050a"

	## R-S1, R-SE13, R-DA4: the file that was downloaded has the sha256 of the release. `want` is from `expected_sha`, `got` is `sha256_file!`. A difference is kind `Integrity` (exit 16): `<name> of roc-talon/talon <tag>: the sha256 is <got>, but sha256sums.txt says <want>. tln is not changed.`
	check_download : { tag : Str, name : Str, want : Str, got : Str } -> Try({}, Fail)
	check_download = |_facts| crash "todo: slice 050a"

	## R-S1, R-SE13: the failures for the checksum file, both kind `Integrity` (exit 16). `unlisted`: `sha256sums.txt of <tag> does not list <name>, so tln cannot check it. tln is not changed.` `missing`: `the release <tag> of roc-talon/talon has no sha256sums.txt, so tln cannot check <name>. tln is not changed.`
	unlisted : { tag : Str, name : Str } -> Fail
	unlisted = |_facts| crash "todo: slice 050a"

	missing : { tag : Str, name : Str } -> Fail
	missing = |_facts| crash "todo: slice 050a"

	## R-S3: `tln --version` on the temp file. `ended` is how the child ended (`spawn_all!`). `Exited(0)` is a binary that starts: `Ok`. Any other end is kind `Internal` (exit 1): `the new tln <version> does not start (<why>). The old tln stays.` with `<why>` `exit <n>`, `signal <n>` or `not started: <text>`. The output of the child is not read (question Q-V1).
	version_check : { version : Str, ended : [Exited(I32), Signaled(I32), NotStarted(Str)] } -> Try({}, Fail)
	version_check = |_facts| crash "todo: slice 050a"

	## R-HF2: the command line that sets the executable bit of the temp file: `chmod 0755 <file>`. Windows needs none: `Err(NotNeeded)`.
	chmod_command : { os : Setup.Os, file : Str } -> Try(List(Str), [NotNeeded])
	chmod_command = |_facts| crash "todo: slice 050a"

	## R-ST9, R-ST6, R-ST11: which bin dir entries the update makes again. `tln` and `roc` are 2 names for one file (R-ST13, R-ST14). `tln` and `roc` are the verdicts of `ToolInstall.verdict` for the entry (`Make`: no entry, or an entry with the sha256 of the file that is replaced; `Foreign`: any other file). `bin` is the bin dir.
	##
	## | `tln` | `roc` | Result |
	## | --- | --- | --- |
	## | `Foreign` | any | Kind `Usage` (exit 2): `ToolUpdate.foreign_failure` of the path of the `tln` entry. Nothing is downloaded. |
	## | `Make` | `Make` | `make` is `tln` and `roc` (with `.exe` on Windows), no warning |
	## | `Make` | `Foreign` | `make` is `tln`. `roc` is kept (R-ST6) with the warning of `kept_warning` (question Q-E1) |
	entries : { os : Setup.Os, bin : Str, tln : [Make, Foreign], roc : [Make, Foreign] } -> Try({ make : List(Str), warnings : List(Str) }, Fail)
	entries = |_facts| crash "todo: slice 050a"

	## R-ST6, R-ST2 (question Q-E1, proposal): the warning for a `roc` entry that tln did not write and keeps: `warning: <path> is not a file that tln wrote, so tln keeps it. Run: tln setup --replace-roc`.
	kept_warning : Str -> Str
	kept_warning = |_path| crash "todo: slice 050a"

	## R-ST10: the name that a running `.exe` is renamed to before it is replaced: the path without `.exe`, then `.<16hex>.del`, in the same dir (`/b/tln.exe` is `/b/tln.0123456789abcdef.del`, R-IS5). `hex` is `Temp.hex` of the random number of the run (one number for the temp name and the `.del` names). The path can have `/` or `\`.
	del_name : { path : Str, hex : Str } -> Str
	del_name = |_facts| crash "todo: slice 050a"

	## R-ST10, R-S3: the renames before the new file goes in. `files` are the paths of the files that exist and are replaced (the data file, and each bin dir entry that `entries` makes). Windows: one rename of each file to its `del_name`, in the order of `files`. Linux and macOS: none (a `rename` over a running binary works).
	del_moves : { os : Setup.Os, hex : Str, files : List(Str) } -> List({ from : Str, to : Str })
	del_moves = |_facts| crash "todo: slice 050a"

	## R-ST10: is the name of a file that of a `.del` file: `<name>.<16 lower case hex digits>.del`, with a name that is not empty.
	is_del : Str -> Bool
	is_del = |_file| crash "todo: slice 050a"

	## R-ST10: the `.del` files of a directory (`list_dirs!`): the full paths, in byte order, of the entries that are files and have a `.del` name. (Each start of `tln` deletes them: the call of this choice is not in this slice, question Q-W1.) `dir` is the dir that was listed.
	stale : { dir : Str, entries : List({ name : Str, is_dir : Bool, mtime : U64 }) } -> List(Str)
	stale = |_facts| crash "todo: slice 050a"

	## R-S3, R-OUT2 (proposal): the lines of the command. `talon <version> is up to date` (stdout). `updated talon <old> to <new> (roc-talon/talon)`; `<new>` is `ToolManage.source_text` of the new entry (`0.3.2`, or `git v0.3.2@dd03c09e` for a source build).
	up_to_date_text : Str -> Str
	up_to_date_text = |_version| crash "todo: slice 050a"

	updated_text : { old : Str, new : Str } -> Str
	updated_text = |_facts| crash "todo: slice 050a"

	## R-DI12 (proposal): the failure of a `--offline` update that needs the download. Kind `Network` (exit 15): `tln <version> is not downloaded and --offline is set. Run the command without --offline.`
	offline_failure : Str -> Fail
	offline_failure = |_version| crash "todo: slice 050a"

	## R-J3, R-J4, R-OUT4 (proposal): the outcome for `ToolUpdate.data`. `old` is the installed version, `new` is the text after the update (the same as `old` when up to date). The `data` is that of `tool update`: `{"tools":[{"tool":"talon","name":"roc-talon/talon","how":"updated","from":"0.3.1","to":"0.3.2"}]}`.
	outcome : { old : Str, new : Str, how : [Updated, UpToDate] } -> ToolUpdate.Outcome
	outcome = |_facts| crash "todo: slice 050a"

	## R-S2, R-T4: the `talon` entry after a prebuilt update. The source is `Prebuilt` with the version and the URL of the asset (question Q-S1). `hashes` is `[]` and `nightly` is `""`: no compiler built it. `now` is the time of the run, `installed_at` is `Clock.format_utc` of it.
	prebuilt_entry : { release : Release, url : Str, sha256 : Str, target : Str, now : U64 } -> ToolsJson.Talon
	prebuilt_entry = |_facts| crash "todo: slice 050a"

	## R-S2 (question Q-F1): what `--from-source` builds: the source archive of the tag of the release, `roc-talon/talon` at `v<version>`, in the dir `cli` (the app `cli/main.roc`).
	source_of : Release -> { source : GitRef.Source, path : Try(Str, [None]) }
	source_of = |_release| crash "todo: slice 050a"

	## R-S2: the text of the source of an entry, for the reports and `data.to`: `0.3.2` (prebuilt) or `git v0.3.2@dd03c09e` (`ToolGit.source_text`).
	source_text : ToolsJson.TalonSource -> Str
	source_text = |_source| crash "todo: slice 050a"
}
