import Args
import Common
import Consent
import DownloadAsk
import Fail
import Fx
import Launch
import Mode
import Out
import Prompt
import RocInstall
import Text
import ToolBuild
import ToolFlow
import ToolGitFlow
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
	update! = |_fx, _args| crash "todo: slice 048"

	## `tln tool rebuild`.
	rebuild! : Fx, Args => I32
	rebuild! = |fx, args| match ToolManage.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(cmd) => match rebuilt!(fx, args, cmd) {
			Ok(outcomes) => {
				if args.json {
					fx.out!(Out.json_ok({ command: args.typed, data: ToolUpdate.data(outcomes) }))
				}
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# One tool that the command builds: the facts of the tool, its source (the bundle), the compiler of the build, and the scratch dir of a git source (R-CC2).
Job : { tool : ToolsJson.Tool, facts : ToolBuild.Facts, bundle : ToolBuild.Bundle, id : Str, temp : Try(Str, [None]) }

# Steps 1 to 5 of `rebuild!`. The scratch dirs are deleted after a success and after a failure.
rebuilt! : Fx, Args, ToolManage.Cmd => Try(List(ToolUpdate.Outcome), Fail)
rebuilt! = |fx, args, cmd| {
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
	jobs = plan!(fx, args, machine.facts, tools)?
	result = match consent!(fx, args, machine.facts, jobs) {
		Ok(_) => build_all!(fx, args, jobs)
		Err(fail) => Err(fail)
	}
	clean!(fx, jobs)
	result
}

# Step 2b: each tool in order, with no build yet (D8). A failure deletes the scratch dirs that are made.
plan! : Fx, Args, ToolBuild.Facts, List(ToolsJson.Tool) => Try(List(Job), Fail)
plan! = |fx, args, base, tools| {
	var $jobs = []
	for tool in tools {
		match plan_one!(fx, args, base, tool) {
			Ok(job) => {
				$jobs = $jobs.append(job)
			}
			Err(fail) => {
				clean!(fx, $jobs)
				return Err(fail)
			}
		}
	}
	Ok($jobs)
}

# The source of the manifest (R-T7), the check of the bin dir entry, the platform. The compiler is the recorded one (R-T5). The checks that need no call come first.
plan_one! : Fx, Args, ToolBuild.Facts, ToolsJson.Tool => Try(Job, Fail)
plan_one! = |fx, args, base, tool| {
	facts = ToolManageFlow.facts_of(base, tool)
	origin = ToolUpdate.origin(tool)?
	match ToolBuild.entry_state!(fx, facts)? {
		Make => {}
		Foreign => return Err(ToolUpdate.foreign_failure(Text.join(facts.bin, facts.file)))
	}
	(bundle, temp) = match origin {
		Bundle(rel) => {
			got = ToolFlow.bundle_for!(fx, args, facts, { version: ToolManage.source_text(tool), url: rel.url, hash: rel.hash })?
			match got {
				Ok(found) => (found, Err(None))
				Err(NotApp) => return Err(Fail.new(Input, "${tool.key}: the bundle at ${rel.url} is not an app, so tln cannot build it again"))
			}
		}
		Archive(arc) => {
			ref = match tool.source {
				Git(git) => git.ref
				Release(_) => ""
			}
			ToolGitFlow.check_curl!(fx, facts.net)?
			made = ToolGitFlow.source!(fx, facts, { source: { owner: arc.owner, repo: arc.repo, ref }, sha: arc.commit, path: arc.path })?
			(made.bundle, Ok(made.temp))
		}
	}
	job = { tool, facts, bundle, id: tool.nightly, temp }
	match ToolFlow.platform_for!(fx, args, facts, bundle) {
		Ok(_) => Ok(job)
		Err(fail) => {
			clean!(fx, [job])
			Err(fail)
		}
	}
}

# Step 3 (R-T25, R-DL1 to R-DL5): the compilers that no installed release covers, one decision for the command.
consent! : Fx, Args, ToolBuild.Facts, List(Job) => Try({}, Fail)
consent! = |fx, args, base, jobs| {
	installed = Launch.toolchains!(fx, base.roots)
	ids = ToolUpdate.downloads({ pins: jobs.map(|j| j.id), installed })
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

# Step 4: the builds one by one. The line of a tool is printed when it is done. A failure ends the command, the tools done before stay changed (Q-U2).
build_all! : Fx, Args, List(Job) => Try(List(ToolUpdate.Outcome), Fail)
build_all! = |fx, args, jobs| {
	shown = Common.shown_fx(fx, args)
	var $outcomes = []
	for job in jobs {
		match ToolBuild.finish!(fx, args, job.facts, job.bundle, { id: job.id, passed: Err(None), first: Bool.True }) {
			Ok(_) => {
				shown.out!("${ToolUpdate.rebuilt_text({ tool: job.tool })}\n")
				$outcomes = $outcomes.append({ tool: job.tool.key, name: job.tool.name, how: Rebuilt, from: Err(None), to: ToolManage.source_text(job.tool) })
			}
			Err(fail) => return Err(fail)
		}
	}
	Ok($outcomes)
}

# Step 5 (R-CC2): the scratch dirs of the git sources.
clean! : Fx, List(Job) => {}
clean! = |fx, jobs| {
	temps = jobs.keep_oks(|j| j.temp)
	if !temps.is_empty() {
		_ = fx.delete!(temps)
	}
}
