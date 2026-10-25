import Download
import Fail
import GitRef
import Manage
import Nightlies
import Roots

## The pure decisions of a source build (slice 045, CLI 6.6, R-R1, R-R3, R-R5 to R-R7, R-SE12): the paths, the `zig build` command, `.talon.json`, the failures and the choice of `roc default --git`.
## The bodies are the work of the code agent. The tests are `tests/unit/GitTest.roc`. Texts that the design does not give are a proposal (TW24): `docs/slices/045-git-install.md`, section "Output".
GitBuild :: [].{

	## The paths of one build. `item` is the toolchain dir (`Roots.item(roots, Toolchain(id))`). `temp` is `Temp.name({ target: item, hex })`. `scratch` is `Roots.item(roots, TalonTmp(hex))`, the dir of the archive and the source.
	## The dir is not in the toolchain dir, so a failed build leaves nothing for `roc list`.
	Plan : { id : Str, item : Str, temp : Str, scratch : Str, archive : Str, src : Str, zon : Str, built : Str, roc : Str, meta : Str, probe_file : Str }

	## The paths. `hex` is the random text of this run (`fx.random!`).
	##
	## | Field | Text |
	## | --- | --- |
	## | `archive` | `<scratch>/source.tar.gz` |
	## | `src` | `<scratch>/src` (tar extracts here, the top dir of the archive is cut) |
	## | `zon` | `<src>/build.zig.zon` |
	## | `built` | `<src>/zig-out/bin/roc` (`roc.exe` on `WindowsX64` and `WindowsArm64`) |
	## | `roc`, `meta` | `<temp>/roc` (`roc.exe`), `<temp>/.talon.json` |
	## | `probe_file` | `<scratch>/empty.roc` (the file for the compat check, R-SE9) |
	plan : { roots : Roots, host : Nightlies.Host, id : Str, hex : Str } -> GitBuild.Plan
	plan = |_facts| crash "todo: slice 045"

	## R-R3: `[zig, "build", "roc", "-Doptimize=ReleaseFast", "-Dcompiler-version=<id>"]` (`zig` is the path of the Zig binary).
	build_command : { zig : Str, id : Str } -> List(Str)
	build_command = |_facts| crash "todo: slice 045"

	## R-R1, R-R7: the text of `.talon.json` (`TalonFile.render`, format 1). The fields in this order: `id`, `repo` (`GitRef.repo_url`), `sha` (full), `ref` (as typed), `sha256` (of the archive),
	## `sha256_source` (`"computed"`), `compat` (a text, or null for `Unknown` or `Several`), `installed_at` (`Clock.format_utc`).
	meta : { id : Str, source : GitRef.Source, sha : Str, sha256 : Str, compat : Try(Str, [Unknown, Several(List(Str))]), now : U64 } -> Str
	meta = |_facts| crash "todo: slice 045"

	## The failure of `zig build`: kind `Internal` (exit 1). Text: `zig build of <id> failed (<how>)` and `: <last line>` when the last line of the output is not empty.
	## `how` is `exit <n>`, `signal <n>`, or `did not start: <why>`.
	build_failed : { id : Str, ended : Download.Ended, last_line : Str } -> Fail
	build_failed = |_facts| crash "todo: slice 045"

	## `zig build` ended with 0 and there is no roc in `zig-out/bin`: kind `Internal`: `zig build of <id> made no roc in zig-out/bin`.
	no_binary : Str -> Fail
	no_binary = |_id| crash "todo: slice 045"

	## R-R5, R-R6: the newest installed build of one repo and ref, from the `.talon.json` texts of the `git-*` toolchains. A row counts when the text is JSON with text fields `repo` equal to `GitRef.repo_url(source)`,
	## `ref` equal to the typed ref, and an `installed_at` that `Clock.parse_utc` reads. Review Q6: when the typed ref is 7 to 40 lower case hex digits, a row also counts when its `sha` field starts with the typed ref
	## (so `roc default --git @dd03c09e` finds the build of the branch `main` that was made at that commit). The latest `installed_at` wins by time (not by text). The same time: the last row. A row that is unreadable, not JSON, or has
	## no such field is skipped. No row: `Err(None)`.
	newest : { source : GitRef.Source, rows : List({ id : Str, text : Manage.Read }) } -> Try(Str, [None])
	newest = |_facts| crash "todo: slice 045"

	## R-R5: no build of that repo and ref: kind `Usage`: `no build of <owner>/<repo>@<ref> is installed. Run: tln roc install --git <owner>/<repo>@<ref>`.
	none_installed : GitRef.Source -> Fail
	none_installed = |_source| crash "todo: slice 045"
}
