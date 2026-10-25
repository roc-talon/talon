import Fail
import Ident
import Index
import JsonDoc
import Ranges
import Selector
import Text
import ToolsJson
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
	home = |facts| match facts.workspace {
		Ok(ws) => Ok(Text.join(ws.root, "talon.toml"))
		Err(Standalone) => match facts.file {
			Ok(file) => Ok(Text.join(Text.dir_of(file), "talon.toml"))
			Err(NoCurrent) => Err(Fail.new(Usage, "no project file found. Pass --file <path>."))
		}
	}

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
	split = |facts| {
		var $header = []
		var $tools = []
		for name in facts.names {
			if name.contains("@") {
				$header = $header.append(name)
			} else {
				is_key = facts.keys.contains(name)
				is_alias = facts.aliases.contains(name)
				if is_key and is_alias {
					return Err(Fail.new(Usage, "'${name}' is a header alias and a key of [tools]. For the tool, run: tln ${facts.command} --tool ${name}"))
				}
				if is_key {
					$tools = $tools.append(name)
				} else {
					$header = $header.append(name)
				}
			}
		}
		Ok({ header: $header, tools: $tools })
	}

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
	frozen_check = |facts| {
		findings = facts.tools.keep_oks(|entry| finding(entry))
		if findings.is_empty() {
			Ok({})
		} else {
			Err(Fail.new(Frozen, "the [tools] of ${facts.path} are not locked: ${Str.join_with(findings, "; ")}"))
		}
	}

	## R-PT4, R-DT4: the candidates that a snapshot does not hide. `snapshot` is the time of `--snapshot` (`Intent.direct_snapshot`), `Err(None)` for no snapshot. A candidate published after the time is hidden, one published at the time stays.
	visible : { list : List(Index.Candidate), snapshot : Try(U64, [None]) } -> List(Index.Candidate)
	visible = |facts| match facts.snapshot {
		Ok(time) => facts.list.keep_if(|c| c.published_at <= time)
		Err(None) => facts.list
	}

	## R-PT4: the selector that `ToolInstall.pick` gets. `Upgrade` takes every release of the app (`Err(None)`), the others the selector of the `ref` (a version, a range, `latest` or none).
	selector_for : { phase : [Install, Frozen, Update, Upgrade], ref : Str } -> Try(Selector, [None])
	selector_for = |facts| match facts.phase {
		Upgrade => Err(None)
		_ => match facts.ref.split_first("@") {
			Ok({ after, .. }) => Selector.parse(after, Bool.False).map_err(|_| None)
			Err(_) => Err(None)
		}
	}

	## R-PT3: the `ref` that `tln add --tool` writes. The selector that the user typed, as `talon.toml` gets it (`Selector.Range` has the `^` of R-SL15 already); with no selector `^<version>` (`^1.1.0`, as R-I4 for a header entry).
	## `name` is the full name `owner/app`, `version` the version of the release that was built.
	add_ref : { name : Str, selector : Try(Selector, [None]), version : Str } -> Str
	add_ref = |facts| match facts.selector {
		Ok(Latest) => "${facts.name}@latest"
		Ok(Exact(text)) | Ok(Range(text)) => "${facts.name}@${text}"
		_ => "${facts.name}@^${facts.version}"
	}

	## R-PT5, R-UP5: the `ref` after `tln upgrade` moved the tool to `version`. `ref` is the text now. No selector and `latest` admit every version: the `ref` stays. An exact version becomes the new version. A range that admits the version stays, else it has the form of `Ranges.rewrite` at the new version
	## (`^1` becomes `^2`). A range with no form (`Err(NoForm)`) is a note and the tool does not move (a `url` outside the `ref` would fail `install --frozen`).
	upgrade_ref : { ref : Str, version : Str } -> Try(Str, [NoForm])
	upgrade_ref = |facts| {
		name = ToolsToml.app_of(facts.ref)
		match facts.ref.split_first("@") {
			Err(_) => Ok(facts.ref)
			Ok({ after, .. }) => match Selector.parse(after, Bool.False) {
				Ok(Latest) => Ok(facts.ref)
				Ok(Exact(_)) => Ok("${name}@${facts.version}")
				Ok(Range(_)) => Ranges.rewrite({ range: after, version: facts.version }).map_ok(|moved| "${name}@${moved}")
				_ => Err(NoForm)
			}
		}
	}

	## R-PT5: the note of a range that `upgrade_ref` cannot move: `tools.<key>: the range <text> does not admit <version>, change it by hand`.
	stuck_note : { key : Str, ref : Str, version : Str } -> Str
	stuck_note = |facts| {
		range = match facts.ref.split_first("@") {
			Ok({ after, .. }) => after
			Err(_) => facts.ref
		}
		"tools.${facts.key}: the range ${range} does not admit ${facts.version}, change it by hand"
	}

	## R-PT6, R-PT9, R-B9: the `x` entry of a project tool: the entries whose binary is there (`has_bin`), whose bundle hash is `bundle` (the hash of the `url`), whose target is `target` and whose source is a release. The nightly, the dependency hashes and the version are not compared (the URL has
	## the version and the bundle hash fixes the source). With more than one: the one with the latest `last_run`, then the first dir in byte order. `Err(None)`: no entry.
	cached : { entries : List(XCache.Found), bundle : Str, target : Str } -> Try(XCache.Found, [None])
	cached = |facts| {
		hits = facts.entries.keep_if(|f| f.has_bin and f.entry.bundle == facts.bundle and f.entry.target == facts.target and is_release(f.entry.source))
		match hits {
			[first, .. as rest] => Ok(rest.fold(first, |best, f| if later(f, best) f else best))
			[] => Err(None)
		}
	}

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
	line = |what| match what {
		Added(a) => "added tool ${a.key} ${a.version} (${a.name})"
		Locked(a) => "locked tool ${a.key} ${a.version} (${a.name})"
		Moved(a) => "moved tool ${a.key} ${a.old} to ${a.version} (${a.name})"
		Built(a) => "built tool ${a.key} ${a.version} (${a.name})"
		WouldBuild(a) => "would build tool ${a.key} ${a.version} (${a.name})"
		Removed(a) => "removed tool ${a.key} (${a.name})"
	}

	## R-DL5, R-PT6 (D8 of the review): the environment of the build facts of a project tool. With `allow` (`--allow-downloads`) the pair `TALON_AUTO_INSTALL=yes` comes first, so the flag wins over the variable (flag over environment, as `Consent.required_want`) and `Consent.auto_install` reads `yes`. Else the environment as it is.
	build_env : { env : List((Str, Str)), allow : Bool } -> List((Str, Str))
	build_env = |facts| if facts.allow facts.env.prepend(("TALON_AUTO_INSTALL", "yes")) else facts.env

	## R-DL4, R-DL7 (Q-A of the review): the stop of a build that needs a compiler download that nobody answered. `ToolInstall.consent_stop` names `--roc pinned`, a flag that `install`, `update` and `upgrade` do not take. For a project tool the text names the flags that the command takes: `the compiler <id> is not installed. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.` Any other failure stays as it is.
	compiler_stop : Fail -> Fail
	compiler_stop = |fail| {
		head = "the compiler "
		tail = " is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes. (--roc installed tries the installed compilers.)"
		if fail.kind == Consent and fail.message.starts_with(head) and fail.message.ends_with(tail) {
			id = fail.message.drop_prefix(head).drop_suffix(tail)
			Fail.new(Consent, "the compiler ${id} is not installed. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.")
		} else {
			fail
		}
	}

	## Q3 of the review: is this the failure of the search for a project file that found none (no `--file`, no app file and no workspace in the walk)? `Project.find` gives kind `Usage` and a text that starts with `no project file found. Checked:`. `add --tool` then makes `talon.toml` in the current directory. Any other failure stays a failure.
	no_project : Fail -> Bool
	no_project = |fail| fail.kind == Usage and fail.message.starts_with("no project file found. Checked:")

	## R-PT3, R-OUT2 (a proposal): the line of the file that changed, like the other writes of `talon.toml` (`<path>: <key> = "<value>"`): `<path>: tools.<key> = { ref = "<ref>", url = "<url>" }`, or `<path>: tools.<key> removed`.
	file_line : { path : Str, key : Str, entry : Try({ ref : Str, url : Str }, [Removed]) } -> Str
	file_line = |facts| match facts.entry {
		Ok(e) => "${facts.path}: tools.${facts.key} = { ref = \"${e.ref}\", url = \"${e.url}\" }"
		Err(Removed) => "${facts.path}: tools.${facts.key} removed"
	}

	## R-J3, R-OUT2 (a proposal): the `data` of `--json` of the commands with `--tool`: `{ "tools": [ <row>, ... ] }`. A row has the keys in this order: `key`, `name`, `action` (`added`, `locked`, `moved`, `built`, `removed`, `kept`), `ref`, `url`, `version`, `previous` (the old version for `moved`, else null), `file` (the `talon.toml`), `built` (true when the run built the binary).
	## `ref`, `url` and `version` are null for `removed`.
	data : List({ key : Str, name : Str, action : Str, ref : Try(Str, [None]), url : Try(Str, [None]), version : Try(Str, [None]), previous : Try(Str, [None]), file : Str, built : Bool, would_build : Bool }) -> JsonDoc
	data = |rows| {
		text = |t| match t {
			Ok(value) => Text(value)
			Err(None) => Null
		}
		Obj([("tools", Arr(rows.map(|r| Obj([("key", Text(r.key)), ("name", Text(r.name)), ("action", Text(r.action)), ("ref", text(r.ref)), ("url", text(r.url)), ("version", text(r.version)), ("previous", text(r.previous)), ("file", Text(r.file)), ("built", Flag(r.built)), ("would_build", Flag(r.would_build))]))))])
	}
}

# R-PT9: is the source of an `x` entry a release (not a git commit)?
is_release : ToolsJson.Source -> Bool
is_release = |source| match source {
	Release(_) => Bool.True
	Git(_) => Bool.False
}

# D9: the later `last_run` wins, and for the same time the first dir in byte order.
later : XCache.Found, XCache.Found -> Bool
later = |a, b| match Text.compare(a.entry.last_run, b.entry.last_run) {
	After => Bool.True
	Same => Text.compare(a.dir, b.dir) == Before
	Before => Bool.False
}

# R-PT7: the first finding of one entry, or `Err(Locked)`.
finding : ToolsToml.Entry -> Try(Str, [Locked])
finding = |entry| match entry.url {
	Err(Unset) => Ok("tools.${entry.key} has no url")
	Ok(url) => match Ident.of_url(url) {
		Err(Foreign) => Ok("tools.${entry.key}: the url is of ${url}, the ref is of ${ToolsToml.app_of(entry.ref)}")
		Ok(ident) => if !admits(entry.ref, ident.version) {
			Ok("tools.${entry.key}: the url has the version ${ident.version}, which the ref ${entry.ref} does not admit")
		} else if ident.name != Ok(ToolsToml.app_of(entry.ref)) {
			Ok("tools.${entry.key}: the url is of ${ident.name ?? url}, the ref is of ${ToolsToml.app_of(entry.ref)}")
		} else {
			Err(Locked)
		}
	}
}

# Does the selector of the `ref` admit the version? A range admits what it admits, an exact version only itself, `latest` and no selector every version.
admits : Str, Str -> Bool
admits = |ref, version| match ToolsPlan.selector_for({ phase: Frozen, ref }) {
	Ok(Range(text)) => Ranges.admits({ ranges: [text], version })
	Ok(Exact(wanted)) => wanted == version
	_ => Bool.True
}
