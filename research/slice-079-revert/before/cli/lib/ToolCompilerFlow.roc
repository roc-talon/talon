import Answer
import Args
import Consent
import Facts
import Fail
import Fx
import Launch
import Mode
import Prompt
import RocInstall
import ToolCompiler
import ToolInstall
import ToolTry

## The compiler choice of `tln tool install` (slice 047, CLI 6.4: R-T11 to R-T16, R-NI8, R-DL1 to R-DL5). Command code, direct style over `Fx`. `ToolCompiler` decides, `ToolTry` is option 2. `ToolFlow.compile!` calls `choose!` in place of the old
## `compiler_id!` (step 9). The calls, in order (the L2 cases `tool/ti3-compiler`, `ti4-nothing` and the changed `ti2-refusals` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Launch.toolchains!` (one `list_dirs!`, also for a header with no pin: the calls of slice 046 stay) and `ToolInstall.compiler`. `NoPin`: `ToolInstall.no_pin` (exit 2, D3 of slice 046, question Q-A). `Use(id)`: the result, no more call (R-T12). | R-T11, R-T12 |
## | 2 | The evidence pass, only when `ToolCompiler.evidence_keys` is not empty: one `Facts.load!` (one `db_query!`) with the keys of `ToolCompiler.candidates`. `ToolCompiler.evidence` gives a release: the line `ToolCompiler.built_line` on stderr, the result is that release (no prompt). | R-T13, R-T17 |
## | 3 | `Mode.from_env` and `ToolCompiler.decide`. `NeedTty`: one `tty!`, `Mode.with_tty`, `decide` again (at most one `tty!` in the command, R-HF1). | R-T14 to R-T16, R-NM2 |
## | 4 | `Stop(fail)`: the failure. `Download`: `RocInstall.fetch_optional!` (the line `downloading <id> (<size>)` is printed by it), the result is the pin. `TryInstalled`: the line `ToolCompiler.trying_line` on stderr (no line when no release is installed), then step 6. | R-T6, R-DL1, R-NM6 |
## | 5 | `Ask`: `RocInstall.offer!` (the size of the pin; `Present`: the pin is the result), then `Prompt.ask!` with `ToolCompiler.prompt` (`installed` is the number of `candidates`, `tried` is empty). `ToolCompiler.allowed` false: ask again. Option 1: `RocInstall.install_offer!`, the result is the pin. Option 2: step 6. Option 3: `ToolCompiler.declined`. | R-NI8, R-T14, R-T15 |
## | 6 | `ToolTry.installed!`. `Passed`: the line `ToolCompiler.built_line` on stderr, the result is that release and its attempt. `Failed(tried)`: step 7. | R-T17 to R-T19 |
## | 7 | A mode that is not interactive (one `tty!` call if the mode is still `NeedsTty`): `ToolCompiler.all_failed` (exit 13). Interactive: the prompt again with `installed` 0 and `tried`, `allowed` as in step 5. Option 1: download (`RocInstall.offer!` and `install_offer!`, with the size of the first offer), the result is the pin. Option 3: `ToolCompiler.declined`. | R-T20, R-T16 |
##
## The line of the answer of a prompt that a flag answered is printed on stderr (R-NM6): `--roc pinned`, `--yes` and `TALON_AUTO_INSTALL=yes` give the line of `RocInstall.fetch_optional!`, `--roc installed` gives `trying_line`. A person's answer prints no line.
ToolCompilerFlow :: [].{

	## What `choose!` gives. `id` is the compiler of the build. `passed` is `Ok(layout)` when option 2 built the app with `id` already (the output is in `layout.output`, the attempt passed): the caller installs it and builds nothing. `Err(None)`: the caller builds with `id`. `first` is false when an attempt of option 2 built the app before (its `building` and `platform` lines are printed already, R-SE8: the platform line once for each command).
	Chosen : { id : Str, passed : Try(ToolInstall.Layout, [None]), first : Bool }

	## Steps 1 to 7. `build` is the build attempt of the caller (`ToolFlow.attempt!`): it runs `roc build` with the release `req.id`, and gives its class, its errors and its paths. `first` is true for the first attempt of the command.
	choose! : Fx, Args, ToolCompiler.Run, { build : { id : Str, first : Bool } => Try(ToolCompiler.Attempt, Fail) } => Try(Chosen, Fail)
	choose! = |fx, args, run, hooks| {
		installed = Launch.toolchains!(fx, run.roots)
		pin = match ToolInstall.compiler({ pin: run.pin, installed }) {
			NoPin => return Err(ToolInstall.no_pin({ name: run.name, version: run.version }))
			Use(id) => return Ok(own(id))
			Missing(id) => id
		}
		ids = ToolCompiler.candidates(installed)
		facts = Facts.load!(fx, { roots: run.roots, keys: ToolCompiler.evidence_keys({ pf: run.pf, target: run.target, ids }) })?
		match ToolCompiler.evidence({ ids, pf: run.pf, target: run.target, digest: ToolCompiler.digest({ bundle: run.bundle, hashes: run.hashes }), facts }) {
			Ok(id) => {
				fx.err!("${ToolCompiler.built_line({ id, pin })}\n")
				return Ok(own(id))
			}
			Err(None) => {}
		}
		ctx = { args, run, hooks, pin, ids }
		decided = decide!(fx, ctx)
		match decided.want {
			Stop(fail) => Err(fail)
			Download => {
				_ = RocInstall.fetch_optional!(fx, { id: pin, env: run.env, offline: args.offline })?
				Ok(own(pin))
			}
			TryInstalled => {
				if !ids.is_empty() fx.err!("${ToolCompiler.trying_line(ids.len())}\n")
				tried!(fx, ctx, { mode: decided.mode, offered: Err(None) })
			}
			Ask => asked!(fx, ctx)
			NeedTty => Err(Fail.new(Internal, "the mode of the run is not known"))
		}
	}
}

# What the steps need: the flags, the facts of the run, the build of the caller, the pin, the releases that option 2 can try.
Ctx : { args : Args, run : ToolCompiler.Run, hooks : { build : { id : Str, first : Bool } => Try(ToolCompiler.Attempt, Fail) }, pin : Str, ids : List(Str) }

# The build uses the release `id` as it is (nothing was built yet).
own : Str -> ToolCompilerFlow.Chosen
own = |id| { id, passed: Err(None), first: Bool.True }

# Step 3 (R-HF1: `tty!` only when `decide` says `NeedTty`, and only once).
decide! : Fx, Ctx => { want : ToolCompiler.Want, mode : Mode }
decide! = |fx, ctx| {
	mode = Mode.from_env({ env: Dict.from_list(ctx.run.env), json: ctx.args.json })
	ask = |at| ToolCompiler.decide({ id: ctx.pin, roc: ctx.run.roc, auto: Consent.auto_install(ctx.run.env), yes: ctx.args.yes, mode: at })
	match ask(mode) {
		NeedTty => {
			with_tty = Mode.with_tty(mode, fx.tty!())
			{ want: ask(with_tty), mode: with_tty }
		}
		want => { want, mode }
	}
}

# Step 5: the first prompt, with the size of the download.
asked! : Fx, Ctx => Try(ToolCompilerFlow.Chosen, Fail)
asked! = |fx, ctx| {
	offer = RocInstall.offer!(fx, { id: ctx.pin, env: ctx.run.env, offline: ctx.args.offline })?
	match offer {
		Present(_) => Ok(own(ctx.pin))
		Download(found) => {
			prompt = ToolCompiler.prompt({ name: ctx.run.name, version: ctx.run.version, pin: ctx.pin, size: found.size, installed: ctx.ids.len(), tried: [] })
			match ask!(fx, ctx, { prompt, installed: ctx.ids.len() })? {
				Option(1) => downloaded!(fx, ctx, offer)
				Option(2) => tried!(fx, ctx, { mode: Interactive, offered: Ok(offer) })
				_ => Err(ToolCompiler.declined(ctx.pin))
			}
		}
	}
}

# Steps 5 and 7: ask until the answer is one of the options that the prompt shows (D-E4).
ask! : Fx, Ctx, { prompt : Prompt, installed : U64 } => Try(Answer, Fail)
ask! = |fx, ctx, shown| {
	got = Prompt.ask!(fx, shown.prompt, { mode: Interactive, yes: ctx.args.yes, quiet: ctx.args.quiet, flag: Err(NoFlag) })?
	if ToolCompiler.allowed({ answer: got.answer, installed: shown.installed }) Ok(got.answer) else ask!(fx, ctx, shown)
}

# Option 1: the download of the pin (`RocInstall.install_offer!`).
downloaded! : Fx, Ctx, RocInstall.Offer => Try(ToolCompilerFlow.Chosen, Fail)
downloaded! = |fx, ctx, offer| match offer {
	Present(_) => Ok(own(ctx.pin))
	Download(found) => {
		_ = RocInstall.install_offer!(fx, found)?
		Ok(own(ctx.pin))
	}
}

# Step 6, then step 7 when no release built the app.
tried! : Fx, Ctx, { mode : Mode, offered : Try(RocInstall.Offer, [None]) } => Try(ToolCompilerFlow.Chosen, Fail)
tried! = |fx, ctx, state| match ToolTry.installed!(fx, ctx.run, { ids: ctx.ids, build: ctx.hooks.build })? {
	Passed(done) => {
		fx.err!("${ToolCompiler.built_line({ id: done.id, pin: ctx.pin })}\n")
		Ok({ id: done.id, passed: Ok(done.layout), first: Bool.False })
	}
	Failed(list) => again!(fx, ctx, { mode: state.mode, offered: state.offered, list })
}

# Step 7 (R-T20): a person gets the prompt again with the list and options 1 and 3. No person: exit 13.
again! : Fx, Ctx, { mode : Mode, offered : Try(RocInstall.Offer, [None]), list : List(ToolCompiler.Tried) } => Try(ToolCompilerFlow.Chosen, Fail)
again! = |fx, ctx, state| {
	mode = match state.mode {
		NeedsTty => Mode.with_tty(state.mode, fx.tty!())
		known => known
	}
	match mode {
		Interactive => {
			offer = match state.offered {
				Ok(known) => known
				Err(None) => RocInstall.offer!(fx, { id: ctx.pin, env: ctx.run.env, offline: ctx.args.offline })?
			}
			match offer {
				Present(_) => Ok(own(ctx.pin))
				Download(found) => {
					prompt = ToolCompiler.prompt({ name: ctx.run.name, version: ctx.run.version, pin: ctx.pin, size: found.size, installed: 0, tried: state.list })
					match ask!(fx, ctx, { prompt, installed: 0 })? {
						Option(1) => {
							chosen = downloaded!(fx, ctx, offer)?
							Ok({ ..chosen, first: !state.list.any(|t| built(t)) })
						}
						_ => Err(ToolCompiler.declined(ctx.pin))
					}
				}
			}
		}
		_ => Err(ToolCompiler.all_failed({ name: ctx.run.name, version: ctx.run.version, pin: ctx.pin, tried: state.list }))
	}
}

# Did the try build the app (a try that failed the check did not start a build)?
built : ToolCompiler.Tried -> Bool
built = |t| match t.stage {
	Build => Bool.True
	Check => Bool.False
}
