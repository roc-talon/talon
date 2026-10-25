import Item
import JsonDoc
import Lookup
import Roots
import Selector
import TalonFile
import Temp
import Text
import ToolsJson

## The pure decisions of the `x` cache and of build reuse (slice 049, CLI 6.4: R-X2, R-B1 to R-B4, R-B9, R-B10, R-GC7, R-TF1, R-TF3, R-TF6, R-SC4, R-AD7). Part A (TESTING.md 2.2). The command code is `XCacheIo`, `XFlow` (`tln x`) and `XTake` (the take-over of `tln tool install`).
## The texts and the file forms are proposals (R-OUT2, TW24): the human accepts or changes them at the review.
##
## One `talon/x/<digest>/` dir holds one build:
##
## | File | Content |
## | --- | --- |
## | `<digest>/<file>` | The binary. `<file>` is the repo name of the full name, with `.exe` on Windows (`ToolInstall.file_name`). It does not depend on the binary name of a tool (`--as`). |
## | `<digest>/manifest.json` | The manifest (R-B9, R-TF1): one line, `format` 1, the fields of `Entry` in the order of `manifest_text` |
##
## ```mermaid
## flowchart TD
##     A["a request: full name, selector, target"] --> B["choose: the matching builds (R-B10), the version (R-B1, R-B2)"]
##     B --> C{"the winner is a candidate of the release list? (R-B3)"}
##     C -->|"no"| D["Build"]
##     C -->|"yes"| E["Installed: run in place (R-B5)  or  Cached: run (x) or take over (tool install, R-B4)"]
## ```
XCache :: [].{

	## One manifest of `talon/x/<digest>/` (R-B9). The fields of a `tools.json` entry (R-T4): `name` (the full name), `source` (`Release({ version, url })`, or `Git({ commit, ref })`), `hashes`, `nightly` and `target` (the build id), `sha256` (of the binary), `libs`. Then `bundle`
	## (the hash of the app bundle that the build used, R-B9; for a git build the commit) and `last_run` (`Clock.format_utc` of the time of Talon: the time of the build, then of each run, R-GC9).
	Entry : { name : Str, source : ToolsJson.Source, hashes : List(Str), nightly : Str, target : Str, sha256 : Str, libs : List(Str), bundle : Str, last_run : Str }

	## An entry that was read, with its dir `<cache>/talon/x/<digest>`. `has_bin` is false when the manifest names a binary (`<dir>/<file>`) that is not in the dir (a stop between the `rename` of a take-over and the delete of the dir, question Q-X3): such an entry is no match (`choose`), and a new build replaces it (`XCacheIo.write!`).
	## `entries_of` gives `has_bin` true (it reads manifests only), `XCacheIo.entries!` looks at the dirs.
	Found : { dir : Str, entry : Entry, has_bin : Bool }

	## What `choose` decides. `Installed(tool)`: run the tool binary in place (R-B5). `Cached(found)`: the `x` cache entry. `NoMatch`: no build is used (online: build the newest release, R-B3).
	Choice : [Installed(ToolsJson.Tool), Cached(Found), NoMatch]

	## R-X2: the digest of a build, the name of its dir. It is the sha256 (64 lower case hex digits, `Crypto.SHA256`) of the text `<name>\n<bundle>\n<hashes joined by ,>\n<nightly>\n<target>\n`. `name` is the full name, `bundle` the hash of the app bundle (R-B9, so two releases with the
	## same dependencies have two dirs), `hashes`, `nightly` and `target` are the build id (Design 4.1, R-ID6).
	digest : { name : Str, bundle : Str, hashes : List(Str), nightly : Str, target : Str } -> Str
	digest = |facts| {
		text = "${facts.name}\n${facts.bundle}\n${Str.join_with(facts.hashes, ",")}\n${facts.nightly}\n${facts.target}\n"
		Crypto.SHA256.hash(text.to_utf8()).to_hex()
	}

	## R-X2, R-CC1, R-CC11: the paths of one entry. `hex` is `Temp.hex(Fx.random!())`, `file` is `ToolInstall.file_name`.
	##
	## | Field | Path |
	## | --- | --- |
	## | `dir` | `<cache>/talon/x/<digest>` (`Roots.item`, `XBuild`) |
	## | `bin` | `<dir>/<file>` |
	## | `manifest` | `<dir>/manifest.json` |
	## | `temp` | `<dir>.<hex>.tmp` (`Temp.name`): the dir that a build writes, then renames to `dir` |
	## | `temp_bin`, `temp_manifest` | `<temp>/<file>` and `<temp>/manifest.json` |
	layout : { roots : Roots, digest : Str, hex : Str, file : Str } -> { dir : Str, bin : Str, manifest : Str, temp : Str, temp_bin : Str, temp_manifest : Str }
	layout = |facts| {
		dir = Roots.item(facts.roots, Item.XBuild(facts.digest))
		temp = Temp.name({ target: dir, hex: facts.hex })
		{
			dir,
			bin: Text.join(dir, facts.file),
			manifest: Text.join(dir, "manifest.json"),
			temp,
			temp_bin: Text.join(temp, facts.file),
			temp_manifest: Text.join(temp, "manifest.json"),
		}
	}

	## R-B9, R-TF1: the text of the manifest. `TalonFile.render` with `format` 1 and these fields, in this order: `name`, `source` (the object of `tools.json`: `{"kind":"release","version","url"}` or `{"kind":"git","commit","ref"}`), `build` (`{"hashes":[..],"nightly","target"}`), `sha256`, `libs`, `bundle`, `last_run`.
	manifest_text : Entry -> Str
	manifest_text = |entry| TalonFile.render({
		format: 1,
		fields: [
			("name", Text(entry.name)),
			("source", ToolsJson.source_json(entry.source)),
			("build", Obj([("hashes", strings(entry.hashes)), ("nightly", Text(entry.nightly)), ("target", Text(entry.target))])),
			("sha256", Text(entry.sha256)),
			("libs", strings(entry.libs)),
			("bundle", Text(entry.bundle)),
			("last_run", Text(entry.last_run)),
		],
	})

	## R-TF1, R-TF3, R-TF6, R-B9: reads the text of a manifest (`TalonFile.open` with `newest` 1 and `can_recreate` true: a manifest can be made again by a build).
	##
	## | Text | Result |
	## | --- | --- |
	## | `format` 1 or less, with a text `name`, a `source` that `ToolsJson` knows, a text `sha256`, `bundle` and `last_run`, and the lists `build.hashes` and `libs` (a missing text or list is the empty one, as for `ToolsJson.manifest`) | `Use(entry)` |
	## | A `format` above 1 | `Ignore` (R-TF3: no read, no write) |
	## | Not JSON, no integer `format`, or an object that lacks the `name`, the `source` or the `bundle` | `Delete(warning)`: the command deletes the entry dir and prints the warning (R-TF6). `warning` is `<path>: the content does not parse. Talon deletes it and makes it again.` |
	read : { path : Str, text : Str } -> [Use(Entry), Ignore, Delete(Str)]
	read = |facts| {
		bad = Delete("${facts.path}: the content does not parse. Talon deletes it and makes it again.")
		match TalonFile.open({ path: facts.path, text: facts.text, newest: 1, can_recreate: Bool.True }) {
			Ok(Use(file)) => match entry_of(file.fields) {
				Ok(entry) => Use(entry)
				Err(NoEntry) => bad
			}
			Ok(Ignore) => Ignore
			Ok(Recreate(warning)) => Delete(warning)
			Err(_) => bad
		}
	}

	## R-X2, R-TF3, R-TF6: the entries of the dirs of `talon/x`. `dirs` are the entry dirs (`dirs_of`), `reads` the answers of `Fx.read_files!` for `manifest_of(dir)`, in the same order. A manifest that cannot be read (`NotFound`, `Denied`, `Other`) gives no entry and
	## no message. `delete` are the dirs of the manifests that `read` gave `Delete` for, `warnings` their texts, both in the order of `dirs`. `found` are the `Use` entries in the order of `dirs`.
	entries_of : { dirs : List(Str), reads : List(Try(Str, [NotFound, Denied, Other(Str)])) } -> { found : List(Found), warnings : List(Str), delete : List(Str) }
	entries_of = |facts| {
		pairs = facts.dirs.map2(facts.reads, |dir, got| (dir, got))
		pairs.fold(
			{ found: [], warnings: [], delete: [] },
			|kept, (dir, got)| match got {
				Ok(text) => match XCache.read({ path: XCache.manifest_of(dir), text }) {
					Use(entry) => { ..kept, found: kept.found.append({ dir, entry, has_bin: Bool.True }) }
					Ignore => kept
					Delete(warning) => { ..kept, warnings: kept.warnings.append(warning), delete: kept.delete.append(dir) }
				}
				Err(_) => kept
			},
		)
	}

	## R-X2: the manifest of an entry dir: `<dir>/manifest.json`.
	manifest_of : Str -> Str
	manifest_of = |dir| Text.join(dir, "manifest.json")

	## R-GC7: the entry dirs in a listing. `entries` is `Gc.entries` of the listing of `talon/x` (`Gc.scan_dirs`). An entry dir is a directory, with the parent `<cache>/talon/x`, and a name with no `.` (so not `<digest>.<hex>.tmp`, a temp that `Temp.old` handles). Sorted by path, each once.
	dirs_of : { roots : Roots, entries : List({ path : Str, is_dir : Bool, mtime : U64 }) } -> List(Str)
	dirs_of = |facts| {
		parent = Text.join(facts.roots.cache, "talon/x")
		Text.sorted_unique(
			facts.entries
				.keep_if(|e| e.is_dir and Text.dir_of(e.path) == parent and !Text.last_segment(e.path).contains("."))
				.map(|e| e.path),
		)
	}

	## R-SC4, R-AD7 (`tln x`): the names that a short name can match: the installed tools and the `x` cache entries, as the entities of `Lookup.find` with the scope `X`. One entity for each full name, never more (so a full name that a tool and an entry both have is no tie): the installed tools first,
	## in the order of `tools` (`alias` is the key, `version` of a release tool is `Ok(version)`, of a git tool `Err(None)`), then each name of `entries` that no tool has and no earlier entry has (`alias` is `""`, `version` is the version of its release, `Err(None)` for a git build). `series` and `note` are `""`.
	entities : { tools : List(ToolsJson.Entry), entries : List(Found) } -> List(Lookup.Entity)
	entities = |facts| {
		tools = facts.tools.map(
			|t| {
				alias: t.key,
				name: t.name,
				series: "",
				version: match t.source {
					Release(rel) => Ok(rel.version)
					Git(_) => Err(None)
				},
				note: "",
			},
		)
		facts.entries.fold(
			tools,
			|kept, f| if kept.any(|e| e.name == f.entry.name) {
				kept
			} else {
				kept.append({
					alias: "",
					name: f.entry.name,
					series: "",
					version: match f.entry.source {
						Release(rel) => Ok(rel.version)
						Git(_) => Err(None)
					},
					note: "",
				})
			},
		)
	}

	## R-B1, R-B2, R-B3, R-B10: which build, if any, does a request use. The request is the full name `name`, the `selector` of the ref, and the `target` of this machine.
	##
	## The builds that match (R-B10): the installed tool `installed` (the tool of the name, `Err(None)` for none) and each entry of `entries`, when its binary is there (`has_bin`), the full name is `name`, the source is a release (a git build never satisfies a release request), and the target is `target`. The nightly is not compared.
	## `check` says how the version is checked:
	##
	## | `check` | A matching build is wanted when | Rule |
	## | --- | --- | --- |
	## | `Online({ first, listed })` | No selector: any. A selector (`@1.3.0`, `@latest`, `@^1.2`): its version is `first`, the version that the selector means (the first candidate of `ToolInstall.pick`: the newest release of the range, R-B2). `listed` are the versions of all candidates of the release list. | R-B1, R-B2 |
	## | `Offline` | No selector: any. `Exact(v)`: its version is `v`. Any other selector (`Latest`, a range): no build (question Q-O2: the design does not say) | R-B7, R-B8 |
	##
	## Among the wanted builds the highest version wins (R-B1, numbers: `1.10.0` is above `1.9.0`). With one version for an installed tool and an entry, the installed tool wins (R-B1). Online, the winner must be in `listed`
	## (R-B3: a version that is no candidate any more is yanked, deleted or a draft): else the result is `NoMatch`, and no other build is tried (the build of the newest release is the normal path).
	choose : { name : Str, target : Str, selector : Try(Selector, [None]), check : [Online({ first : Str, listed : List(Str) }), Offline], installed : Try(ToolsJson.Tool, [None]), entries : List(Found) } -> Choice
	choose = |_facts| crash "todo: slice 049"

	## R-B3: is the build `have` older than the release `newest` (numbers). It decides the note `<have> ... (<newest> is available ...)`: no note for the same or a newer version.
	is_older : { have : Str, newest : Str } -> Bool
	is_older = |_facts| crash "todo: slice 049"

	## R-B4 (NC3): how a take-over of an `x` entry gets the binary. `project_uses` is true when the `[tools]` of a known project uses the entry (its bundle hash is a `[tools]` URL, R-PT14). The decision of `project_uses` is slice 056 (the `[tools]` reader), so the command of slice 049 gives `Bool.False`.
	##
	## | `project_uses` | Result | The binary | The cache entry |
	## | --- | --- | --- | --- |
	## | false | `Move` | `rename` to the data bin dir. When the `rename` fails (another file system, a running `.exe`): copy, then the entry is deleted all the same | deleted after the take-over (one owner) |
	## | true | `Copy` | copy to the data bin dir (the project tool keeps its build, R-PT13) | stays |
	take_how : { project_uses : Bool } -> [Move, Copy]
	take_how = |_facts| crash "todo: slice 049"

	## R-GC7: the entry dirs that GC removes. `dirs` are the entry dirs (`dirs_of`), `reads` the answers of `Fx.read_files!` for their manifests (`manifest_of`), in the same order. `now` is the time of Talon (`TALON_NOW`, R-GC9), `age` is the GC age in seconds (`Gc.age`).
	## `kept` are the bundle hashes that a `[tools]` URL of a live known project names (R-PT14: slice 056 fills it, slice 049 gives `[]`).
	##
	## An entry goes when its manifest is `Use`, its `last_run` is a UTC time (`Clock.parse_utc`) and `now - last_run` is more than `age` (exactly `age` stays, a time in the future stays), and its `bundle` is not in `kept`.
	## Every other entry stays: a manifest that cannot be read, `Ignore`, `Delete` and a `last_run` that is no time (question Q-G1: the design gives no rule). The result is in the order of `dirs`.
	expired : { dirs : List(Str), reads : List(Try(Str, [NotFound, Denied, Other(Str)])), now : U64, age : U64, kept : List(Str) } -> List(Str)
	expired = |_facts| crash "todo: slice 049"
}

# A list of texts as JSON.
strings : List(Str) -> JsonDoc
strings = |items| Arr(items.map(|item| Text(item)))

# The entry of the fields of a manifest. No text `name`, no known `source` or no text `bundle` is `NoEntry` (R-TF6). The other texts and the lists may be missing: they are empty.
entry_of : List((Str, JsonDoc)) -> Try(XCache.Entry, [NoEntry])
entry_of = |fields| {
	name = ToolsJson.text_of(fields, "name").map_err(|Missing| NoEntry)?
	source = ToolsJson.source_in(fields).map_err(|Unknown| NoEntry)?
	bundle = ToolsJson.text_of(fields, "bundle").map_err(|Missing| NoEntry)?
	build = ToolsJson.object_of(fields, "build")
	Ok({
		name,
		source,
		hashes: ToolsJson.texts_of(build, "hashes"),
		nightly: ToolsJson.text_of(build, "nightly") ?? "",
		target: ToolsJson.text_of(build, "target") ?? "",
		sha256: ToolsJson.text_of(fields, "sha256") ?? "",
		libs: ToolsJson.texts_of(fields, "libs"),
		bundle,
		last_run: ToolsJson.text_of(fields, "last_run") ?? "",
	})
}
