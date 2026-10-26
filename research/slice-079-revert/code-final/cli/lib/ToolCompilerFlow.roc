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

## The compiler choice of `tln tool install`, `x`, a project tool build and `tool --git` (slice 047, slice 079: CLI 6.4: R-T11 to R-T16, R-T29, R-T30, R-NI8, R-DL1 to R-DL5). Command code, direct style over `Fx`. `ToolCompiler` decides, `ToolTry` is the try of step 3 of R-T30.
## `ToolFlow.compile!` calls `choose!` (step 9). Slice 079 changes the order: the try of the installed releases runs BEFORE the prompt, with no question (R-T30), and the selected compiler is tried first. The calls, in order (the L2 cases `tool/ti3-compiler`, `ti4-nothing`, `tc1-order`, `tc2-nothing` and `ti2-refusals` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Launch.toolchains!` (one `list_dirs!`, also for a header with no pin: the calls of slice 046 stay) and `ToolInstall.compiler`. `NoPin`: `ToolInstall.no_pin` (exit 2, before any try and any prompt: Q-A2). `Use(id)`: the result, no more call (R-T12, R-T30 (1)). | R-T29, R-T11, R-T12, R-T30 |
## | 2 | The evidence pass, only when `ToolCompiler.evidence_keys` is not empty: one `Facts.load!` (one `db_query!`) with the keys of `ToolCompiler.candidates`. `ToolCompiler.evidence` gives a release: the line `ToolCompiler.built_line` on stderr, the result is that release (no prompt, no try). | R-T13, R-T17, R-T30 (2) |
## | 3 | The try: `ToolCompiler.try_order` (`run.selected` first when it is installed, then `candidates`; `[]` for `--roc pinned`). With a release in the list: the line `ToolCompiler.trying_line` on stderr, then `ToolTry.installed!` with that order. `Passed`: the line `built_line` on stderr, the result is that release and its attempt (no download, no default). `Failed(tried)`: step 4. An empty list: step 4 with `tried` empty. | R-T30 (3), R-T17 to R-T19, R-T21 |
## | 4 | `Mode.from_env` and `ToolCompiler.decide` (`NeedTty`: one `tty!`, `Mode.with_tty`, `decide` again: at most one `tty!` in the command, R-HF1). `Stop(fail)`: `ToolCompiler.after_try` (with `tried` empty: `fail` as it is). `Download`: `RocInstall.fetch_optional!` (it prints `downloading <id> (<size>)`), then, when `ToolCompiler.sets_default`, one `RocInstall.read_config!` before and `RocInstall.first_default!` after. `TryInstalled` (`--roc installed`): non-interactive: `ToolCompiler.all_failed` (exit 13); interactive: step 5. | R-T30 (4), R-T6, R-T16, R-DL1, R-SO15 |
## | 5 | `Ask`: `RocInstall.offer!` (the size of the pin; `Present`: the pin is the result), one `RocInstall.read_config!` when no compiler is selected (`becomes_default`), then `Prompt.ask!` with `ToolCompiler.prompt` (options 1 and 3, the list `tried`, the line `It becomes the default compiler.` when `becomes_default`). `ToolCompiler.allowed` false: ask again. Option 1: `RocInstall.install_offer!` and, with `becomes_default`, `RocInstall.first_default!`. Option 3: `ToolCompiler.declined`. | R-NI8, R-T14, R-T15, R-T20, R-SO15 |
##
## `first` of `Chosen` is false when an attempt of step 3 built the app (its `platform` line is printed, R-SE8). `ToolFlow.package_text!` (the fetch of the bundle and of the platform) passes `none: Download({ scope: Outside, ... })` in place of `Stop` (R-FE4: a tool has no fact before its bundle is unpacked, so the latest in the channel, and it becomes the default).
## The line of the answer of a prompt that a flag answered is printed on stderr (R-NM6): `--roc pinned`, `--yes` and `TALON_AUTO_INSTALL=yes` give the line of `RocInstall.fetch_optional!`, `--roc installed` gives `trying_line`. A person's answer prints no line.
## A command that is not `tool install` (`install --frozen`, `run`) rewrites the text of a consent stop that follows a try (`ToolsPlan.compiler_stop`, `RunTools.stop`: they must match the end of the message, as the code agent decides).
ToolCompilerFlow :: [].{

	## What `choose!` gives. `id` is the compiler of the build. `passed` is `Ok(layout)` when option 2 built the app with `id` already (the output is in `layout.output`, the attempt passed): the caller installs it and builds nothing. `Err(None)`: the caller builds with `id`. `first` is false when an attempt of option 2 built the app before (its `building` and `platform` lines are printed already, R-SE8: the platform line once for each command).
	Chosen : { id : Str, passed : Try(ToolInstall.Layout, [None]), first : Bool }

	## Steps 1 to 5 of the doc table. `build` is the build attempt of the caller (`ToolFlow.attempt!`): it runs `roc build` with the release `req.id`, and gives its class, its errors and its paths. `first` is true for the first attempt of the command.
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
		order = ToolCompiler.try_order({ ids, selected: run.selected, roc: run.roc })
		list = match tried!(fx, run, hooks, { order, pin })? {
			Passed(chosen) => return Ok(chosen)
			Failed(failed) => failed
		}
		download!(fx, { args, run, pin, list })
	}
}

# What the steps need after a failed try: the flags, the facts of the run, the pin, the releases that gave no build.
Ctx : { args : Args, run : ToolCompiler.Run, pin : Str, list : List(ToolCompiler.Tried) }

# The build uses the release `id` as it is (nothing was built yet).
own : Str -> ToolCompilerFlow.Chosen
own = |id| { id, passed: Err(None), first: Bool.True }

# Step 3 (R-T30): the try of the installed releases, with no prompt. An empty order (`--roc pinned`, no release) makes no call.
tried! : Fx, ToolCompiler.Run, { build : { id : Str, first : Bool } => Try(ToolCompiler.Attempt, Fail) }, { order : List(Str), pin : Str } => Try([Passed(ToolCompilerFlow.Chosen), Failed(List(ToolCompiler.Tried))], Fail)
tried! = |fx, run, hooks, step| {
	if step.order.is_empty() return Ok(Failed([]))
	fx.err!("${ToolCompiler.trying_line(step.order.len())}\n")
	match ToolTry.installed!(fx, run, { ids: step.order, build: hooks.build })? {
		Passed(done) => {
			fx.err!("${ToolCompiler.built_line({ id: done.id, pin: step.pin })}\n")
			Ok(Passed({ id: done.id, passed: Ok(done.layout), first: Bool.False }))
		}
		Failed(list) => Ok(Failed(list))
	}
}

# Step 4 (R-HF1: `tty!` only when `decide` says `NeedTty`, and only once).
download! : Fx, Ctx => Try(ToolCompilerFlow.Chosen, Fail)
download! = |fx, ctx| {
	mode = Mode.from_env({ env: Dict.from_list(ctx.run.env), json: ctx.args.json })
	ask = |at| ToolCompiler.decide({ id: ctx.pin, roc: ctx.run.roc, auto: Consent.auto_install(ctx.run.env), yes: ctx.args.yes, mode: at })
	(want, known) = match ask(mode) {
		NeedTty => {
			with_tty = Mode.with_tty(mode, fx.tty!())
			(ask(with_tty), with_tty)
		}
		decided => (decided, mode)
	}
	match want {
		Stop(fail) => Err(ToolCompiler.after_try({ fail, name: ctx.run.name, version: ctx.run.version, pin: ctx.pin, tried: ctx.list }))
		Download => {
			_ = RocInstall.fetch_optional!(fx, { id: ctx.pin, env: ctx.run.env, offline: ctx.args.offline })?
			_ = defaulted!(fx, ctx)?
			Ok(after(ctx))
		}
		TryInstalled => match known {
			NeedsTty => interactive!(fx, ctx, Mode.with_tty(known, fx.tty!()))
			_ => interactive!(fx, ctx, known)
		}
		Ask => asked!(fx, ctx)
		NeedTty => Err(Fail.new(Internal, "the mode of the run is not known"))
	}
}

# `--roc installed` after a failed try: a person gets the prompt of R-T20, no person gets the stop with the list.
interactive! : Fx, Ctx, Mode => Try(ToolCompilerFlow.Chosen, Fail)
interactive! = |fx, ctx, mode| match mode {
	Interactive => asked!(fx, ctx)
	_ => Err(ToolCompiler.all_failed({ name: ctx.run.name, version: ctx.run.version, pin: ctx.pin, tried: ctx.list }))
}

# Step 5: the prompt, with the size of the download, the list of the failed releases and the line about the default.
asked! : Fx, Ctx => Try(ToolCompilerFlow.Chosen, Fail)
asked! = |fx, ctx| {
	offer = RocInstall.offer!(fx, { id: ctx.pin, env: ctx.run.env, offline: ctx.args.offline })?
	match offer {
		Present(_) => Ok(own(ctx.pin))
		Download(found) => {
			becomes_default = ToolCompiler.sets_default({ selected: ctx.run.selected, default_now: default_now!(fx, ctx)? })
			prompt = ToolCompiler.prompt({ name: ctx.run.name, version: ctx.run.version, pin: ctx.pin, size: found.size, tried: ctx.list, becomes_default })
			match ask!(fx, ctx, prompt)? {
				Option(1) => {
					_ = RocInstall.install_offer!(fx, found)?
					if becomes_default {
						_ = RocInstall.first_default!(fx, ctx.run.roots, ctx.pin)?
					}
					Ok(after(ctx))
				}
				_ => Err(ToolCompiler.declined(ctx.pin))
			}
		}
	}
}

# Steps 4 and 5: ask until the answer is one of the options that the prompt shows (D-E4).
ask! : Fx, Ctx, Prompt => Try(Answer, Fail)
ask! = |fx, ctx, prompt| {
	got = Prompt.ask!(fx, prompt, { mode: Interactive, yes: ctx.args.yes, quiet: ctx.args.quiet, flag: Err(NoFlag) })?
	if ToolCompiler.allowed({ answer: got.answer }) Ok(got.answer) else ask!(fx, ctx, prompt)
}

# The `default-roc` of `config.toml` now (the unpack of the bundle can have set it, R-FE4). One read, and only when no compiler is selected: a selected compiler decides without it.
default_now! : Fx, Ctx => Try(Str, Fail)
default_now! = |fx, ctx| if ctx.run.selected.is_empty() {
	config = RocInstall.read_config!(fx, ctx.run.roots)?
	Ok(config.default_roc ?? "")
} else {
	Ok("")
}

# R-SO15, R-T30 (4): the pin that was downloaded becomes the default when no compiler is selected and no default is set now.
defaulted! : Fx, Ctx => Try({}, Fail)
defaulted! = |fx, ctx| {
	if ToolCompiler.sets_default({ selected: ctx.run.selected, default_now: default_now!(fx, ctx)? }) {
		_ = RocInstall.first_default!(fx, ctx.run.roots, ctx.pin)?
	}
	Ok({})
}

# The pin is the result. The platform line is printed already when a try built the app (R-SE8).
after : Ctx -> ToolCompilerFlow.Chosen
after = |ctx| { id: ctx.pin, passed: Err(None), first: !ctx.list.any(|t| built(t)) }

# Did the try build the app (a try that failed the check did not start a build)?
built : ToolCompiler.Tried -> Bool
built = |t| match t.stage {
	Build => Bool.True
	Check => Bool.False
}
