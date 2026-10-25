import Args
import Fail
import Fx
import Ident
import Net
import RocInstall
import Roots
import Setup
import Text
import TomlKeys
import ToolBuild
import ToolsPlan
import ToolsStep
import ToolsToml
import XCache
import XCacheIo
import toml.Toml

## The project tools of a `tln run` (slice 057, CLI 6.4 and 1: R-RUN3 point 2, R-PT8, R-PT9, R-PT10, R-PT12, R-DL7, Design G1). Command code over `Fx` (TESTING.md 2.2 part C) with one pure read (`table`). A step whose first word is a key of `[tools]` runs the binary of the locked release
## (`url`). It uses the pieces of slice 056 (`ToolsPlan.cached`, `ToolsStep.ensure!`) and never touches `tools.json`, the bin dir or the lock of `tools.json` (R-PT12). It makes no index call, no yank check and no prompt about a check online (R-PT8): the `url` is the lock.
## It adds no directory to `PATH` (R-PT10): `RunFlow` runs the binary by its path with the variables of R-RUN9 only.
##
## The calls of `load!` and `bin!`, in order. `load!` runs once for a run, at the first step that names a key:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | `load!` | `ToolsStep.machine!` (`platform!`), `XCacheIo.entries!` (its doc table: `list_dirs!` of `talon/x`, `read_files!` of the manifests, `list_dirs!` of the entries) | R-X2, R-B9 |
## | `bin!` 1 | `ToolsPlan.cached` for the bundle hash of the `url` and the target. A hit gives the binary: no more call (no `last_run` write: a design gap, Q4 of the review of slice 057) | R-PT9 (1) |
## | `bin!` 2 | No hit: `RocInstall.read_config!` (one `read_files!` of `config.toml`: the probe timeout), then `ToolsStep.ensure!` with a `Ctx` that has `allow: false`, `dry_run: false`, `args` of the run and the environment of the run: the bundle (fetched or in the cache), the platform check (R-PT16), the compiler and the consent (R-DL7: a required download, exit 13 with no consent), the build, the entry. `--offline` as in `ToolsStep.ensure!` (R-PT15) | R-PT9 (2), R-PT6, R-DL7 |
RunTools :: [].{

	## The `[tools]` table of the run: the entries (in the order of their lines) and the warnings (each one `<path>:<line>: <message>`).
	Table : { tools : List(ToolsToml.Entry), warnings : List(Str) }

	## R-RUN3 point 2, R-PT1, R-PT2, OP4: the entries of the table `[tools]` of the file `path` with the text `text` (the `talon.toml` of the workspace root, or of the standalone project, that holds the script). `ToolsToml.read_table`: the first issue by line is a failure of kind `Input` (exit 19):
	## `<path>:<line>: <message>`. Text that is not TOML: `<path>:<line>: not valid TOML`. No `[tools]` table: no entry. The other tables of the file are not read.
	table : { path : Str, text : Str } -> Try(RunTools.Table, Fail)
	table = |facts| match Toml.parse(facts.text) {
		Err(TomlErr(e)) => Err(Fail.new(Input, "${facts.path}:${e.line.to_str()}: not valid TOML"))
		Ok(doc) => {
			found = ToolsToml.read_table(doc)
			match found.issues.first() {
				Ok(issue) => Err(Fail.new(Input, "${facts.path}:${issue.line.to_str()}: ${issue.message}"))
				Err(_) => Ok({ tools: found.value, warnings: found.warnings.map(|w| "${facts.path}:${w.line.to_str()}: ${w.message}") })
			}
		}
	}

	## R-RUN3 point 2, R-PT7, Q2 of the review of slice 057: a `[tools]` key with no `url` in a step. It is not locked, so the failure is kind `Frozen` (exit 14), as `install --frozen` gives it (R-PT7), and the text names `tln install` (a proposal, TW24):
	## `the [tools] of <path> are not locked: tools.<key> has no url. Run tln install to lock them.`
	no_url : { path : Str, key : Str } -> Fail
	no_url = |facts| Fail.new(Frozen, "the [tools] of ${facts.path} are not locked: tools.${facts.key} has no url. Run tln install to lock them.")

	## R-DL7, Q6 of the review of slice 057: the consent stop of a build in `tln run` names only what `run` accepts. `ToolsPlan.compiler_stop` ends with `Pass --allow-downloads or set TALON_AUTO_INSTALL=yes.` (a flag that `run` refuses, R-FL12). Here that sentence is
	## `Pass --yes or set TALON_AUTO_INSTALL=yes.` (`--yes` is a global flag). Any other failure stays as it is.
	stop : Fail -> Fail
	stop = |fail| {
		head = "the compiler "
		tail = " is not installed. Pass --allow-downloads or set TALON_AUTO_INSTALL=yes."
		if fail.kind == Consent and fail.message.starts_with(head) and fail.message.ends_with(tail) {
			Fail.new(Consent, "${fail.message.drop_suffix(tail)} is not installed. Pass --yes or set TALON_AUTO_INSTALL=yes.")
		} else {
			fail
		}
	}

	## What `load!` gives: the system, the build target and the `x` entries as they are now.
	Know : { os : Setup.Os, target : Str, found : List(XCache.Found) }

	## What a run has: the environment, the roots, the network settings, the clock, the file of `[tools]` (its path and text) and its entries.
	Run : { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, path : Str, text : Str, tools : List(ToolsToml.Entry) }

	## `load!` (see the table above).
	load! : Fx, Roots => Try(RunTools.Know, Fail)
	load! = |fx, roots| {
		machine = ToolsStep.machine!(fx)?
		found = XCacheIo.entries!(fx, roots)?
		Ok({ os: machine.os, target: machine.target, found })
	}

	## `bin!` (see the table above): the binary of the entry, and the `Know` with the entry that a build made. An entry with no `url` is `no_url` (exit 14). A consent stop is `stop`. A `url` that is no release URL
	## is kind `Input`: `tools.<key>.url: '<url>' is not a release URL with a version and a hash`.
	bin! : Fx, Args, RunTools.Run, RunTools.Know, ToolsToml.Entry => Try({ bin : Str, know : RunTools.Know }, Fail)
	bin! = |fx, args, run, know, entry| {
		url = match entry.url {
			Ok(found) => found
			Err(Unset) => return Err(RunTools.no_url({ path: run.path, key: entry.key }))
		}
		ident = match Ident.of_url(url) {
			Ok(found) => found
			Err(Foreign) => return Err(Fail.new(Input, "tools.${entry.key}.url: '${url}' is not a release URL with a version and a hash"))
		}
		match ToolsPlan.cached({ entries: know.found, bundle: ident.hash, target: know.target }) {
			Ok(hit) => Ok({ bin: XCacheIo.bin_of({ found: hit, os: know.os }), know })
			Err(None) => build!(fx, args, run, know, { entry, url, ident })
		}
	}
}

# R-PT9 (2), R-PT6, R-DL7: no `x` entry for the bundle of the `url`: the build of `ToolsStep.ensure!`, with no consent flag (`allow: false`). The entry that it made is in the `Know` that is given back.
build! : Fx, Args, RunTools.Run, RunTools.Know, { entry : ToolsToml.Entry, url : Str, ident : Ident } => Try({ bin : Str, know : RunTools.Know }, Fail)
build! = |fx, args, run, know, what| {
	config = RocInstall.read_config!(fx, run.roots)?
	ctx = {
		args,
		env: run.env,
		roots: run.roots,
		net: run.net,
		now: run.now,
		min_age: config.min_release_age ?? 172800,
		probe_timeout: ToolBuild.probe_timeout(config),
		snapshot: Err(None),
		dry_run: Bool.False,
		allow: Bool.False,
		home: run.path,
		home_text: run.text,
		tools: run.tools,
	}
	facts = ToolsStep.facts_of(ctx, { os: know.os, target: know.target }, ToolsToml.app_of(what.entry.ref))
	rel = { version: what.ident.version, url: what.url, hash: what.ident.hash }
	ensured = match ToolsStep.ensure!(fx, ctx, { facts, rel, bundle: Err(Read), found: know.found }) {
		Ok(done) => done
		Err(fail) => return Err(RunTools.stop(fail))
	}
	found = know.found.concat(ensured.added)
	match ToolsPlan.cached({ entries: found, bundle: what.ident.hash, target: know.target }) {
		Ok(hit) => Ok({ bin: XCacheIo.bin_of({ found: hit, os: know.os }), know: { ..know, found } })
		Err(None) => Err(Fail.new(Internal, "the build of tools.${what.entry.key} made no entry"))
	}
}
