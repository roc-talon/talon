import Fail
import Index
import JsonDoc
import Selector
import ToolsToml
import XCache

## The pure decisions of the project tools (slice 056, CLI 6.4: R-PT2 to R-PT7, R-PT9, R-PT14, R-B4, R-UP5). Part A (TESTING.md 2.2). The command code is `ToolsFlow` (the commands with `--tool`) and `ToolsStep` (the steps that `install`, `update` and `upgrade` share).
## The texts and the `data` fields that the design does not give are proposals (R-OUT2, TW24): the human accepts or changes them at the review.
ToolsPlan :: [].{

	## What a command does with the `[tools]` entries: `Install` (`install` with no names: lock the entries with no `url`, build the entries with no binary), `Frozen` (`install --frozen`: build the entries with no binary, lock nothing),
	## `Update` (inside the `ref` range), `Upgrade` (the newest release, with the `ref` range changed to match).
	Phase : [Install, Frozen, Update, Upgrade]

	## R-PT2, NC2: the `talon.toml` that holds `[tools]`. A workspace has it in the root file (`<root>/talon.toml`, also for a member). A standalone project has it in its own directory (`<directory of the project file>/talon.toml`), also inside a workspace directory
	## (R-PD5: `workspace` is `Err(Standalone)` for it). `workspace` and `file` are the fields of `Project`. A standalone project with no project file cannot happen (`Project.find` stops it): it is a failure of kind `Usage` (`no project file found. Pass --file <path>.`).
	home : { workspace : Try({ root : Str, members : List(Str) }, [Standalone]), file : Try(Str, [NoCurrent]) } -> Try(Str, Fail)
	home = |_facts| crash "todo: slice 056"

	## R-PT5: the names of `update` and `upgrade` with no `--tool`. `command` is `update` or `upgrade` (for the message), `names` are the operands as typed, `keys` the keys of `[tools]`, `aliases` the aliases of the headers of the members.
	## A name is the text before the first `@`. A name with an `@` is never a tool (a selector is for a header entry, R-CM4: question Q2). Else:
	##
	## | The name is | Result |
	## | --- | --- |
	## | A key of `[tools]` and no alias | A tool |
	## | An alias and no key, or neither | For the header (the header flow gives its own failure for an unknown name) |
	## | An alias and a key | Failure of kind `Usage` (exit 2): `'<name>' is a header alias and a key of [tools]. For the tool, run: tln <command> --tool <name>` |
	##
	## The first name that is an alias and a key gives the failure. `header` and `tools` keep the order of the names.
	split : { command : Str, names : List(Str), keys : List(Str), aliases : List(Str) } -> Try({ header : List(Str), tools : List(Str) }, Fail)
	split = |_facts| crash "todo: slice 056"

	## R-LF1, R-PT7: the check of `install --frozen` for the entries of `[tools]` of the file `path`. Each finding, in the order of the entries (one finding for an entry, the first of this table):
	##
	## | # | Case | Finding |
	## | --- | --- | --- |
	## | 1 | The entry has no `url` | `tools.<key> has no url` |
	## | 2 | The version of the `url` is not in the range of the `ref` (`Ranges.admits` for a range, equal for an exact version, any for no selector and `latest`) | `tools.<key>: the url has the version <v>, which the ref <ref> does not admit` |
	## | 3 | The app of the `url` is not the app of the `ref` (the name `owner/repo` of `Ident.of_url`; a URL with no name is another app) | `tools.<key>: the url is of <owner/repo>, the ref is of <owner/app>` |
	##
	## No finding: `Ok({})`. Else a failure of kind `Frozen` (exit 14): `the [tools] of <path> are not locked: <finding>; <finding>`. A `ref` that does not parse is a finding of `Intent.read` before (exit 19), so it gives no finding here.
	frozen_check : { path : Str, tools : List(ToolsToml.Entry) } -> Try({}, Fail)
	frozen_check = |_facts| crash "todo: slice 056"

	## R-PT4, R-DT4: the candidates that a snapshot does not hide. `snapshot` is the time of `--snapshot` (`Intent.direct_snapshot`), `Err(None)` for no snapshot. A candidate published after the time is hidden, one published at the time stays.
	visible : { list : List(Index.Candidate), snapshot : Try(U64, [None]) } -> List(Index.Candidate)
	visible = |_facts| crash "todo: slice 056"

	## R-PT4: the selector that `ToolInstall.pick` gets. `Upgrade` takes every release of the app (`Err(None)`), the others the selector of the `ref` (a version, a range, `latest` or none).
	selector_for : { phase : [Install, Frozen, Update, Upgrade], ref : Str } -> Try(Selector, [None])
	selector_for = |_facts| crash "todo: slice 056"

	## R-PT3: the `ref` that `tln add --tool` writes. The selector that the user typed, as `talon.toml` gets it (`Selector.Range` has the `^` of R-SL15 already); with no selector `^<version>` (`^1.1.0`, as R-I4 for a header entry).
	## `name` is the full name `owner/app`, `version` the version of the release that was built.
	add_ref : { name : Str, selector : Try(Selector, [None]), version : Str } -> Str
	add_ref = |_facts| crash "todo: slice 056"

	## R-PT5, R-UP5: the `ref` after `tln upgrade` moved the tool to `version`. `ref` is the text now. No selector and `latest` admit every version: the `ref` stays. An exact version becomes the new version. A range that admits the version stays, else it has the form of `Ranges.rewrite` at the new version
	## (`^1` becomes `^2`). A range with no form (`Err(NoForm)`) is a note and the tool does not move (a `url` outside the `ref` would fail `install --frozen`).
	upgrade_ref : { ref : Str, version : Str } -> Try(Str, [NoForm])
	upgrade_ref = |_facts| crash "todo: slice 056"

	## R-PT5: the note of a range that `upgrade_ref` cannot move: `tools.<key>: the range <text> does not admit <version>, change it by hand`.
	stuck_note : { key : Str, ref : Str, version : Str } -> Str
	stuck_note = |_facts| crash "todo: slice 056"

	## R-PT6, R-PT9, R-B9: the `x` entry of a project tool: the entries whose binary is there (`has_bin`), whose bundle hash is `bundle` (the hash of the `url`), whose target is `target` and whose source is a release. The nightly, the dependency hashes and the version are not compared (the URL has
	## the version and the bundle hash fixes the source). With more than one: the one with the latest `last_run`, then the first dir in byte order. `Err(None)`: no entry.
	cached : { entries : List(XCache.Found), bundle : Str, target : Str } -> Try(XCache.Found, [None])
	cached = |_facts| crash "todo: slice 056"

	## R-PT14, R-B4 (NC3): the `talon.toml` files that GC and the take-over read for the known project files `files` (the paths of `projects.json`). A file whose name is `talon.toml` (an entry that `tln run` or `tln x <key>` made, R-PD9) is read itself.
	## Any other file gives the `talon.toml` of its directory and of each parent directory up to the root of the file system (the walk stops at the first one with `[workspace]` when it is read: `held_hashes`). The paths are in byte order, each once.
	held_paths : { files : List(Str) } -> List(Str)
	held_paths = |_facts| crash "todo: slice 056"

	## R-PT14, R-B4 (NC3): the hashes of the bundles that the `[tools]` of the known project files `files` name. `reads` are the texts of the files of `held_paths` that were found (a file that was not found is not in the list). For each file the candidates of `held_paths`
	## are walked nearest first. Each candidate that is in `reads` gives the hash of the `url` of each of its entries (`Ident.hash`). The walk stops after the first candidate that has a `[workspace]` table (the root: a `[tools]` table is in the root only, R-PT2).
	## A text that is not TOML, an entry with no `url` or a `url` that is no release URL gives no hash (GC never fails for it, R-PD13). So a hash is kept for a project that is not a member of the workspace above it: GC keeps more, never less (the design does not say how GC finds the root of a member: question Q4).
	## The result is in byte order, each hash once.
	held_hashes : { files : List(Str), reads : List({ path : Str, text : Str }) } -> List(Str)
	held_hashes = |_facts| crash "todo: slice 056"

	## R-PT3, R-OUT2 (a proposal): the line of a tool change on stdout. `added tool <key> <version> (<name>)`, `locked tool <key> <version> (<name>)` (`install` wrote a `url`), `moved tool <key> <old> to <new> (<name>)`, `built tool <key> <version> (<name>)` (`install` built a tool that has a `url`), `would build tool <key> <version> (<name>)` (`--dry-run`: the build that a real run would make, D8 of the review), `removed tool <key> (<name>)`.
	line : [Added({ key : Str, name : Str, version : Str }), Locked({ key : Str, name : Str, version : Str }), Moved({ key : Str, name : Str, old : Str, version : Str }), Built({ key : Str, name : Str, version : Str }), WouldBuild({ key : Str, name : Str, version : Str }), Removed({ key : Str, name : Str })] -> Str
	line = |_what| crash "todo: slice 056"

	## R-DL5, R-PT6 (D8 of the review): the environment of the build facts of a project tool. With `allow` (`--allow-downloads`) the pair `TALON_AUTO_INSTALL=yes` comes first, so the flag wins over the variable (flag over environment, as `Consent.required_want`) and `Consent.auto_install` reads `yes`. Else the environment as it is.
	build_env : { env : List((Str, Str)), allow : Bool } -> List((Str, Str))
	build_env = |_facts| crash "todo: slice 056"

	## R-DL4, R-DL7 (Q-A of the review): the stop of a build that needs a compiler download that nobody answered. `ToolInstall.consent_stop` names `--roc pinned`, a flag that `install`, `update` and `upgrade` do not take. For a project tool the text names the flags that the command takes: `the compiler <id> is not installed. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.` Any other failure stays as it is.
	compiler_stop : Fail -> Fail
	compiler_stop = |_fail| crash "todo: slice 056"

	## Q3 of the review: is this the failure of the search for a project file that found none (no `--file`, no app file and no workspace in the walk)? `Project.find` gives kind `Usage` and a text that starts with `no project file found. Checked:`. `add --tool` then makes `talon.toml` in the current directory. Any other failure stays a failure.
	no_project : Fail -> Bool
	no_project = |_fail| crash "todo: slice 056"

	## R-PT3, R-OUT2 (a proposal): the line of the file that changed, like the other writes of `talon.toml` (`<path>: <key> = "<value>"`): `<path>: tools.<key> = { ref = "<ref>", url = "<url>" }`, or `<path>: tools.<key> removed`.
	file_line : { path : Str, key : Str, entry : Try({ ref : Str, url : Str }, [Removed]) } -> Str
	file_line = |_facts| crash "todo: slice 056"

	## R-J3, R-OUT2 (a proposal): the `data` of `--json` of the commands with `--tool`: `{ "tools": [ <row>, ... ] }`. A row has the keys in this order: `key`, `name`, `action` (`added`, `locked`, `moved`, `built`, `removed`, `kept`), `ref`, `url`, `version`, `previous` (the old version for `moved`, else null), `file` (the `talon.toml`), `built` (true when the run built the binary).
	## `ref`, `url` and `version` are null for `removed`.
	data : List({ key : Str, name : Str, action : Str, ref : Try(Str, [None]), url : Try(Str, [None]), version : Try(Str, [None]), previous : Try(Str, [None]), file : Str, built : Bool, would_build : Bool }) -> JsonDoc
	data = |_rows| crash "todo: slice 056"
}
