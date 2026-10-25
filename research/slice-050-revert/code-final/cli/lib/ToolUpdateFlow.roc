import Args
import Common
import Consent
import DownloadAsk
import Fail
import Fx
import GitRef
import Launch
import Mode
import Out
import Prompt
import RocInstall
import Selector
import Text
import ToolBuild
import ToolFlow
import ToolGitFlow
import ToolInstall
import ToolManage
import ToolManageFlow
import ToolUpdate
import ToolsJson

## The commands `tln tool update [tool]` and `tln tool rebuild [tool]` (slice 048, CLI 6.4: R-T7, R-T24, R-T25, R-T5, R-T6, R-T9, R-T26, R-DL1 to R-DL5, R-CC6, R-CC2, R-B6). Direct style over `Fx` (TESTING.md 2.2 part C): `ToolUpdate` decides, `ToolBuild` builds and installs under the lock of `tools.json` (slice 046), the source steps of `ToolFlow` and `ToolGitFlow` are reused.
## `Run.run!` calls `update!` for `["tool", "update"]` and `rebuild!` for `["tool", "rebuild"]`. No operand: all tools of `tools.json`, in the order of the file. The calls, in order (the L2 cases `tool/tu1-update` and `tool/tr1-rebuild` and the L3 case `tools/ti3-tool-git` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolManage.read(args)` (a failure: `Common.failed!`, no `Fx` call). `ToolManageFlow.machine!` (the machine, `tools.json`, `config.toml`: one `clock!`, one `platform!`). One operand: `ToolManageFlow.find!` (the tool must be installed). No tool: the line of `ToolManage.ls_report`, exit 0. | R-T7, R-T25, R-SC3 |
## | 2 | Plan each tool, in order (no build yet). `update`, `ToolUpdate.way`: `Commit`: no call (`Pinned`). `Release`: `ToolFlow.release_list_for!`, `ToolInstall.pick` with `latest` and `ToolInstall.reuse`: `Keep` is `UpToDate`; else the notes, `entry_verdict!`, `first_app_for!` (the bundle of the newest release that is an app), `platform_for!`. `Branch`: `ToolGitFlow.head!` (the commit now), `ToolUpdate.moved`: `Same` is `UpToDate`; else `entry_verdict!`, `check_curl!`, `source!`, `platform_for!`. | R-T24, R-T9, R-T26 |
## | 2b | `rebuild`, `ToolUpdate.origin`: a release: `entry_verdict!`, `bundle_for!` (the bundle of the URL of the manifest), `platform_for!`. A git tool: `entry_verdict!`, `check_curl!`, `source!` with the commit of the manifest (no request for the commit), `platform_for!`. The compiler is the one of the manifest (R-T5). | R-T7, R-T5 |
## | 3 | The downloads of the command: `Launch.toolchains!`, `ToolUpdate.downloads` (the pins of the tools to build that no installed compiler covers). Not empty: one decision for the command (`Mode.from_env`, one `tty!` if `NeedsTty`, `ToolUpdate.want`). `Download`: `RocInstall.fetch_optional!` for each id. `Ask`: `RocInstall.offer!` for each id, one `Prompt.ask!` with `ToolUpdate.prompt`, then `RocInstall.install_offer!` for each. `Stop`: the failure (exit 13), nothing was changed. | R-T25, R-DL1 to R-DL5 |
## | 4 | For each tool in order: nothing to build: the line. Else `ToolBuild.finish!` with the compiler (no evidence, no option 2: the header pin of an update, the recorded compiler of a rebuild). The line of the tool is printed when it is done. A failure ends the command (question Q-U2): the tools done before stay changed. | R-T7, R-CC6, R-B6 |
## | 5 | `delete!` of the scratch dirs of the git sources (also after a failure, R-CC2). `--json`: one envelope with `ToolUpdate.data` (the text goes to stderr). | R-J1 to R-J4 |
ToolUpdateFlow :: [].{

	## `tln tool update`.
	update! : Fx, Args => I32
	update! = |fx, args| ended!(fx, args, Update)

	## `tln tool rebuild`.
	rebuild! : Fx, Args => I32
	rebuild! = |fx, args| ended!(fx, args, Rebuild)

	## Slice 050 (`TalonUpdateFlow`, `--from-source`, step 4e): the decision for the compilers `pins` that the build needs, as step 3 of `tool update`. No pin: no question.
	consent_for! : Fx, Args, ToolBuild.Facts, List(Str) => Try({}, Fail)
	consent_for! = |fx, args, base, pins| consent!(fx, args, base, pins)
}

# One tool that the command builds: the facts of the tool, its source (the bundle), the compiler of the build, and the scratch dir of a git source (R-CC2).
Job : { tool : ToolsJson.Tool, facts : ToolBuild.Facts, bundle : ToolBuild.Bundle, id : Str, temp : Try(Str, [None]) }

# One tool of the plan: nothing to build (the line and the outcome are known), or a build.
Item : [Skip({ line : Str, outcome : ToolUpdate.Outcome }), Build(Job)]

Kind : [Update, Rebuild]

# Both commands: read the line, run, print the envelope with `--json`, give the exit code.
ended! : Fx, Args, Kind => I32
ended! = |fx, args, kind| match ToolManage.read(args) {
	Err(fail) => Common.failed!(fx, args, fail)
	Ok(cmd) => match run!(fx, args, cmd, kind) {
		Ok(outcomes) => {
			if args.json {
				fx.out!(Out.json_ok({ command: args.typed, data: ToolUpdate.data(outcomes) }))
			}
			0
		}
		Err(fail) => Common.failed!(fx, args, fail)
	}
}

# Steps 1 to 5. The scratch dirs are deleted after a success and after a failure.
run! : Fx, Args, ToolManage.Cmd, Kind => Try(List(ToolUpdate.Outcome), Fail)
run! = |fx, args, cmd, kind| {
	machine = ToolManageFlow.machine!(fx)?
	tools = match cmd.ref {
		Ok(ref) => [ToolManageFlow.find!(fx, { ref, tools: machine.tools })?]
		Err(None) => machine.tools
	}
	if tools.is_empty() {
		shown = Common.shown_fx(fx, args)
		for line in ToolManage.ls_report([]).stdout {
			shown.out!(line)
		}
		return Ok([])
	}
	items = plan!(fx, args, machine.facts, tools, kind)?
	jobs = jobs_of(items)
	result = match consent!(fx, args, machine.facts, jobs.map(|j| j.id)) {
		Ok(_) => build_all!(fx, args, items, kind)
		Err(fail) => Err(fail)
	}
	clean!(fx, jobs)
	result
}

jobs_of : List(Item) -> List(Job)
jobs_of = |items| items.keep_oks(
	|item| match item {
		Build(job) => Ok(job)
		Skip(_) => Err(NoJob)
	},
)

# Step 2: each tool in order, with no build yet (D8). A failure deletes the scratch dirs that are made.
plan! : Fx, Args, ToolBuild.Facts, List(ToolsJson.Tool), Kind => Try(List(Item), Fail)
plan! = |fx, args, base, tools, kind| {
	var $items = []
	for tool in tools {
		facts = ToolManageFlow.facts_of(base, tool)
		planned = match kind {
			Rebuild => rebuild_item!(fx, args, facts, tool)
			Update => update_item!(fx, args, facts, tool)
		}
		match planned {
			Ok(item) => {
				$items = $items.append(item)
			}
			Err(fail) => {
				clean!(fx, jobs_of($items))
				return Err(fail)
			}
		}
	}
	Ok($items)
}

# Step 2b, `rebuild` (R-T7): the source of the manifest, the check of the bin dir entry, the platform. The compiler is the recorded one (R-T5). The checks that need no call come first.
rebuild_item! : Fx, Args, ToolBuild.Facts, ToolsJson.Tool => Try(Item, Fail)
rebuild_item! = |fx, args, facts, tool| {
	origin = ToolUpdate.origin(tool)?
	entry_check!(fx, facts)?
	(bundle, temp) = match origin {
		Bundle(rel) => {
			got = ToolFlow.bundle_for!(fx, args, facts, { version: ToolManage.source_text(tool), url: rel.url, hash: rel.hash })?
			match got {
				Ok(found) => (found, Err(None))
				Err(NotApp) => return Err(Fail.new(Input, "${tool.key}: the bundle at ${rel.url} is not an app, so tln cannot build it again"))
			}
		}
		Archive(arc) => {
			made = git_source!(fx, facts, tool, { owner: arc.owner, repo: arc.repo, sha: arc.commit })?
			(made.bundle, Ok(made.temp))
		}
	}
	platform_item!(fx, args, { tool, facts, bundle, id: tool.nightly, temp })
}

# Step 2a, `update` (R-T24): the way of the tool says what to ask.
update_item! : Fx, Args, ToolBuild.Facts, ToolsJson.Tool => Try(Item, Fail)
update_item! = |fx, args, facts, tool| match ToolUpdate.way(tool) {
	Commit => {
		commit = match tool.source {
			Git(git) => git.commit
			Release(_) => ""
		}
		Ok(skip(tool, Pinned, ToolUpdate.pinned_text({ key: tool.key, commit })))
	}
	Release => release_item!(fx, args, facts, tool)
	Branch => branch_item!(fx, args, facts, tool)
}

# A release tool: the newest release in `min-release-age`, as `tool install app@latest` (R-T9, R-B2, R-T26).
release_item! : Fx, Args, ToolBuild.Facts, ToolsJson.Tool => Try(Item, Fail)
release_item! = |fx, args, facts, tool| {
	list = ToolFlow.release_list_for!(fx, args, facts)?
	selector = Ok(Selector.Latest)
	picked = ToolInstall.pick({ name: facts.name, list, selector, now: facts.now, min_age: facts.min_age })?
	newest = match picked.order.first() {
		Ok(first) => first
		Err(_) => return Err(Fail.new(Internal, "no release was picked"))
	}
	match ToolInstall.reuse({ installed: Ok({ key: tool.key, name: tool.name, source: tool.source }), selector, first: newest.ident.version }) {
		Keep(_) => return Ok(skip(tool, UpToDate, ToolUpdate.up_to_date_text(tool)))
		Build => {}
	}
	ToolFlow.notes_for!(fx, facts, picked, newest)
	entry_check!(fx, facts)?
	bundle = ToolFlow.first_app_for!(fx, args, facts, picked.order)?
	id = pin_of(tool, bundle)?
	platform_item!(fx, args, { tool, facts, bundle, id, temp: Err(None) })
}

# A branch or a tag: the commit of the ref now. The same commit is up to date. Another commit is built from its source archive (R-T24).
branch_item! : Fx, Args, ToolBuild.Facts, ToolsJson.Tool => Try(Item, Fail)
branch_item! = |fx, args, facts, tool| {
	(owner, repo) = match ToolUpdate.origin(tool)? {
		Archive(arc) => (arc.owner, arc.repo)
		Bundle(_) => return Err(Fail.new(Internal, "${tool.key} has no source archive"))
	}
	ref = match tool.source {
		Git(git) => git.ref
		Release(_) => ""
	}
	if args.offline return Err(GitRef.offline_failure({ owner, repo, ref }))
	sha = ToolGitFlow.head!(fx, facts.net, { owner, repo, ref }, facts.now)?
	match ToolUpdate.moved({ tool, sha }) {
		Same => return Ok(skip(tool, UpToDate, ToolUpdate.up_to_date_text(tool)))
		Moved => {}
	}
	entry_check!(fx, facts)?
	made = git_source!(fx, facts, tool, { owner, repo, sha })?
	job = { tool, facts, bundle: made.bundle, id: "", temp: Ok(made.temp) }
	match pin_of(tool, made.bundle) {
		Ok(id) => platform_item!(fx, args, { ..job, id })
		Err(fail) => {
			clean!(fx, [job])
			Err(fail)
		}
	}
}

skip : ToolsJson.Tool, [Updated, UpToDate, Pinned, Rebuilt], Str -> Item
skip = |tool, how, line| Skip({ line, outcome: { tool: tool.key, name: tool.name, how, from: Err(None), to: ToolManage.source_text(tool) } })

# D11: the compiler of an update is the pin of the new header.
pin_of : ToolsJson.Tool, ToolBuild.Bundle -> Try(Str, Fail)
pin_of = |tool, bundle| match bundle.pin {
	Ok(id) => Ok(id)
	Err(NoPin) => Err(ToolInstall.no_pin({ name: tool.name, version: bundle.version }))
}

# R-ST6, R-ST11: the bin dir entry must be a file that tln wrote. The text has no `--as` (Q-U3).
entry_check! : Fx, ToolBuild.Facts => Try({}, Fail)
entry_check! = |fx, facts| match ToolBuild.entry_state!(fx, facts)? {
	Make => Ok({})
	Foreign => Err(ToolUpdate.foreign_failure(Text.join(facts.bin, facts.file)))
}

# The source archive of a commit, with the `--path` of the tool (R-T23). Only curl (R-DA3).
git_source! : Fx, ToolBuild.Facts, ToolsJson.Tool, { owner : Str, repo : Str, sha : Str } => Try({ bundle : ToolBuild.Bundle, temp : Str }, Fail)
git_source! = |fx, facts, tool, want| {
	ref = match tool.source {
		Git(git) => git.ref
		Release(_) => ""
	}
	ToolGitFlow.check_curl!(fx, facts.net)?
	ToolGitFlow.source!(fx, facts, { source: { owner: want.owner, repo: want.repo, ref }, sha: want.sha, path: tool.path })
}

# R-T2: the platform of the app. A failure deletes the scratch dir.
platform_item! : Fx, Args, Job => Try(Item, Fail)
platform_item! = |fx, args, job| match ToolFlow.platform_for!(fx, args, job.facts, job.bundle) {
	Ok(_) => Ok(Build(job))
	Err(fail) => {
		clean!(fx, [job])
		Err(fail)
	}
}

# Step 3 (R-T25, R-DL1 to R-DL5): the compilers that no installed release covers, one decision for the command. No build: no question.
consent! : Fx, Args, ToolBuild.Facts, List(Str) => Try({}, Fail)
consent! = |fx, args, base, pins| {
	if pins.is_empty() return Ok({})
	installed = Launch.toolchains!(fx, base.roots)
	ids = ToolUpdate.downloads({ pins, installed })
	if ids.is_empty() return Ok({})
	mode = Mode.from_env({ env: Dict.from_list(base.env), json: args.json })
	decide = |at| ToolUpdate.want({ ids, auto: Consent.auto_install(base.env), yes: args.yes, mode: at })
	(want, known) = match decide(mode) {
		NeedTty => {
			with_tty = Mode.with_tty(mode, fx.tty!())
			(decide(with_tty), with_tty)
		}
		other => (other, mode)
	}
	match want {
		Stop(fail) => Err(fail)
		Download => {
			for id in ids {
				_ = RocInstall.fetch_optional!(fx, { id, env: base.env, offline: args.offline })?
			}
			Ok({})
		}
		Ask => asked!(fx, args, base, { ids, mode: known })
		NeedTty => Err(Fail.new(Internal, "the mode of the run is not known"))
	}
}

# Step 3, `Ask`: the offers of all ids, one prompt, then the downloads.
asked! : Fx, Args, ToolBuild.Facts, { ids : List(Str), mode : Mode } => Try({}, Fail)
asked! = |fx, args, base, run| {
	var $offers = []
	for id in run.ids {
		$offers = $offers.append(RocInstall.offer!(fx, { id, env: base.env, offline: args.offline })?)
	}
	sum = DownloadAsk.totals($offers)
	if sum.ids.is_empty() return Ok({})
	asked = Prompt.ask!(fx, ToolUpdate.prompt(sum), { mode: run.mode, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) })?
	if asked.answer != Yes return Err(ToolUpdate.declined(run.ids))
	for offer in $offers {
		match offer {
			Download(found) => {
				_ = RocInstall.install_offer!(fx, found)?
			}
			Present(_) => {}
		}
	}
	Ok({})
}

# Step 4: the tools one by one, in the order of the plan. The line of a tool is printed when it is done. A failure ends the command, the tools done before stay changed (Q-U2).
build_all! : Fx, Args, List(Item), Kind => Try(List(ToolUpdate.Outcome), Fail)
build_all! = |fx, args, items, kind| {
	shown = Common.shown_fx(fx, args)
	var $outcomes = []
	for item in items {
		match item {
			Skip(done) => {
				shown.out!("${done.line}\n")
				$outcomes = $outcomes.append(done.outcome)
			}
			Build(job) => match ToolBuild.finish!(fx, args, job.facts, job.bundle, { id: job.id, passed: Err(None), first: Bool.True }) {
				Ok(_) => {
					done = built(job, kind)
					shown.out!("${done.line}\n")
					$outcomes = $outcomes.append(done.outcome)
				}
				Err(fail) => return Err(fail)
			}
		}
	}
	Ok($outcomes)
}

# The line and the outcome of a tool that was built.
built : Job, Kind -> { line : Str, outcome : ToolUpdate.Outcome }
built = |job, kind| match kind {
	Rebuild => {
		line: ToolUpdate.rebuilt_text({ tool: job.tool }),
		outcome: { tool: job.tool.key, name: job.tool.name, how: Rebuilt, from: Err(None), to: ToolManage.source_text(job.tool) },
	}
	Update => {
		line: ToolUpdate.updated_text({ tool: job.tool, new: job.bundle.version }),
		outcome: { tool: job.tool.key, name: job.tool.name, how: Updated, from: Ok(ToolManage.source_text(job.tool)), to: job.bundle.version },
	}
}

# Step 5 (R-CC2): the scratch dirs of the git sources.
clean! : Fx, List(Job) => {}
clean! = |fx, jobs| {
	temps = jobs.keep_oks(|j| j.temp)
	if !temps.is_empty() {
		_ = fx.delete!(temps)
	}
}
