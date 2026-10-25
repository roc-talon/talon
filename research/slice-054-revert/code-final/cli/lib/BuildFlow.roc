import BuildSkip
import BuildTarget
import Facts
import Fail
import Fx
import Probe
import Text
import UnitFlow

## Command code (part C) of ladder step 3, the build skip (slice 032, R-BS1, R-BS2, R-ID6, R-P4). `Ladder.run!` and `Ladder.verify!` call it for each member that has a build, after step 2 passed. The pure decisions are in `BuildSkip`.
## The calls, in order (the L2 cases `ladder/bs1-build-skip`, `ladder/bs2-build-skip-verify` fix them):
##
## | Function | Calls | Rule |
## | --- | --- | --- |
## | `before!` | `BuildSkip.pf_hash` of the nodes of the member: `Err(NoPlatform)` (the platform is a path entry, or the member has no closure: `roc use`) gives `Build` with no id and no call. Else one `platform!` call, `BuildSkip.key`: `Err(Unknown)` gives `Build` with no id and no more call. Else the scan of the used modules (`UnitFlow.scan!`, one `read_files!` for each level) unless the verdict of step 1 did the scan already (it is never done twice for one member), `BuildSkip.digest`, one `db_query!` with `Facts([key])` (`Facts.load!`), `BuildSkip.decide`. | R-BS1, R-BS2, R-ID6, R-CC8 |
## | `after!` | The build ran (slice 032, manager review: every result is recorded): `Probe.classify` of the output, `Probe.errors` (for a fail), `BuildSkip.row`, and one `db_write!` with `Facts({ rows: [row], existing: Replace })` (`Facts.save!`). `NoFact` gives no row and no call. No id: no call. A busy or failed write is the warning of R-CC8 and the command goes on. | R-P4, R-P3, R-BS2, R-CC8 |
##
## A skipped build starts no probe, so it is not counted (R-PP4) and `.last-use` is not touched for it. It writes nothing.
##
## Wiring that the code agent writes (not stubs; the files stay as they are before the slice):
##
## | File | Change |
## | --- | --- |
## | `UnitFlow.verdict!` | The result is `{ used : Try(List({ hash : Str, path : Str }), [NotScanned]) }`: `Ok(used)` when the verdict did the scan (D6 of slice 031: only for a suspect), else `Err(NotScanned)` |
## | `Ladder.run!`, `Ladder.verify!` (`probe_in_copy!`, `probe_in_place!`) | After `LadderJudge.check` passed and `plan.build` is `Ok(spec)`: `BuildFlow.before!`. `skip`: the member gives the line `BuildSkip.skipped_line` after the line of the check, no probe, no `.last-use`. Else the build as before, then `BuildFlow.after!` with the output (before `LadderJudge.build`: a failed, hung or crashed build is recorded too, then the command stops as before), then `LadderJudge.build`. `Ran` and the result of `run!` and `verify!` get `skipped : U64` (the number of members that skipped). `Ladder.use!` is unchanged: it has no closure, so `before!` makes no call |
## | `InstallFlow`, `RemoveFlow`, `VerifyFlow` | `Report.Outcome.build` is `NotRun` with no app member, `Skipped` when every app member skipped, else `Passed` |
BuildFlow :: [].{

	## What step 3 does for one member. `skip` is true when the build does not run. `id` is the build id when the key is known, else `Err(NoId)` (no skip is possible, nothing is recorded).
	## Slice 054 (R-TG1, R-TG2): `target` is the build target of the member (`BuildTarget.pick`): the build probe gets it (`LadderPlan.with_target`), and the id has it in its key. `Unlisted` for a member with no id (no key, no platform hash).
	Plan : { skip : Bool, id : Try(BuildSkip.Id, [NoId]), target : BuildTarget.Chosen }

	## `used` is the result of the scan of the verdict of step 1 (`Ok`), or `Err(NotScanned)` when step 1 did no scan.
	before! : Fx, UnitFlow.Ctx, { used : Try(List(BuildSkip.Used), [NotScanned]) } => Try(BuildFlow.Plan, Fail)
	before! = |fx, ctx, run| {
		plain = { skip: Bool.False, id: Err(NoId), target: Unlisted }
		pf = match BuildSkip.pf_hash(ctx.nodes) {
			Ok(hash) => hash
			Err(NoPlatform) => return Ok(plain)
		}
		system = fx.platform!()
		listed = match fx.read_files!([Text.join(ctx.roots.pkgs, "${pf}/main.roc")]) {
			[Ok(text)] => BuildTarget.targets_of(text)
			_ => Err(NoSection)
		}
		chosen = BuildTarget.pick({ project: ctx.target, host: BuildTarget.host(system), found: listed, file: ctx.member.file })?
		key = match BuildTarget.key({ pf, nightly: ctx.started.id, chosen, system }) {
			Ok(found) => found
			Err(Unknown) => return Ok(plain)
		}
		used = match run.used {
			Ok(scanned) => scanned
			Err(NotScanned) => UnitFlow.scan!(fx, ctx)
		}
		digest = BuildSkip.digest(used)
		facts = Facts.load!(fx, { roots: ctx.roots, keys: [key] })?
		skip = match BuildSkip.decide({ facts, key, digest }) {
			Skip => Bool.True
			Build => Bool.False
		}
		Ok({ skip, id: Ok({ key, digest }), target: chosen })
	}

	## The record of the result of a build that ran (pass, fail, hang or crash). `output` is the output of the build probe, `dir` is the dir of the probe and `pkgs` is `Roots.pkgs` (for `Probe.errors`).
	after! : Fx, UnitFlow.Ctx, { id : Try(BuildSkip.Id, [NoId]), output : Probe.Output, dir : Str, pkgs : Str } => Try({}, Fail)
	after! = |fx, ctx, run| match run.id {
		Err(NoId) => Ok({})
		Ok(id) => {
			class = Probe.classify(run.output)
			errors = Probe.errors({ text: run.output.stderr, dir: run.dir, pkgs: run.pkgs })
			match BuildSkip.row({ key: id.key, digest: id.digest, class, errors }) {
				Err(NoFact) => Ok({})
				Ok(row) => {
					_ = Facts.save!(fx, { roots: ctx.roots, rows: [row], existing: Replace })?
					Ok({})
				}
			}
		}
	}
}
