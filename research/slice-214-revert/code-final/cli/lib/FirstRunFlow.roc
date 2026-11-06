import Args
import FirstRun
import Fail
import Fx
import Item
import Mode
import Net
import Prompt
import RocInstall
import Roots
import Share
import ShareFlow

## The first-run sharing prompt, the command code (slice 214, CLI 1 R-SH11, CLI 4 R-NI16, R-NM12, R-HF1). Direct style over `Fx`. No new `Fx` call.
## `Run.tln!` calls `before!` once for each command, after `Args.parse` and `check_refs` gave no failure, and before the dispatch. A parse failure and a usage failure never ask (the command does not run).
## `Run.run!` with the `roc` proxy never calls it (R-SH11 row 3). `--help`, `--version` and `help` end before it (`Help.route`).
## The L2 cases `share/sh4-first-run` and `share/sh5-first-skips` fix the calls.
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 0 | `FirstRun.of_command(args.command)`. `Skip`: return `fx` as it is, before any call (the `calls.log` of `tln share` and `tln setup` does not change). | R-SH11 |
## | 1 | `fx.env_all!()`. `FirstRun.gate({ env, json: args.json })`. `Skip`: return `fx` as it is (no more call). | R-SH11, R-NM1, R-NM2 |
## | 2 | `fx.tty!()`, once. `Mode.with_tty(Mode.from_env(..), tty)`. Not `Interactive`: return the `fx` of step 6 (no more call). | R-NR1, R-HF1 |
## | 3 | `Roots.of_run!`, `RocInstall.read_text!` of `config.toml` (a missing file is the empty text), `Share.setting`, `Net.registry` (the flag `--registry`, `TALON_REGISTRY`, the key `registry`). A failure of the setting stops the command (exit 19, R-TF4). | R-SH1, R-RG1 |
## | 4 | `FirstRun.need`. `Skip`: return the `fx` of step 6. | R-SH11 |
## | 5 | `Prompt.ask!(fx, FirstRun.prompt({}), { mode: Interactive, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) })`. `--yes` does not answer it (R-NM12, R-NM10): it is asked. It prints no answer line and no more text, as the other asked prompts. | R-NI16, R-NM12 |
## | 6 | `FirstRun.written`. `Write(value)`: the steps 2 and 3 of `ShareFlow.on!` (value true) or of `ShareFlow.off!` without the queue (value false): the edit of `config.toml` under its lock, and for true the `share.json` under its lock (the id, `chmod 0600`, R-SH5: the first time that sharing turns on). `Nothing`: no call. A failure of the write stops the command. | R-SH1, R-SH5, R-CC6, R-LY3 |
##
## The `Fx` that `before!` gives back is `fx` with `tty!` replaced by the answer of step 2 (`{ ..fx, tty!: || tty }`, as `Common.shown_fx` replaces `out!`). So the command code that calls `tty!` later
## makes no second call: one `tty` line in `calls.log` for a whole command (R-HF1). When step 1 skips, `tty!` was not called and `fx` is unchanged.
##
## `ShareFlow` keeps its private steps. The code agent exposes them in the way that it likes (for example `ShareFlow.set_share!` and `ShareFlow.ensure_id!`); `ShareFlow.on!` and `off!` stay as they are.
FirstRunFlow :: [].{

	before! : Fx, Args => Try(Fx, Fail)
	before! = |fx, args| match FirstRun.of_command(args.command) {
		Skip(_) => Ok(fx)
		Check => {
			env = fx.env_all!()
			match FirstRun.gate({ env, json: args.json }) {
				Skip(_) => Ok(fx)
				NeedTty => after_gate!(fx, args, env)
			}
		}
	}
}

# Steps 2 to 6. `tty!` is called once, and the `Fx` that goes on has this answer (R-HF1).
after_gate! : Fx, Args, List((Str, Str)) => Try(Fx, Fail)
after_gate! = |fx, args, env| {
	tty = fx.tty!()
	fixed = { ..fx, tty!: || tty }
	mode = Mode.with_tty(Mode.from_env({ env: Dict.from_list(env), json: args.json }), tty)
	if mode == Interactive {
		ask_once!(fixed, args, env)?
	}
	Ok(fixed)
}

# Steps 3 to 6.
ask_once! : Fx, Args, List((Str, Str)) => Try({}, Fail)
ask_once! = |fx, args, env| {
	roots = Roots.of_run!(fx, env)?
	path = Roots.item(roots, Item.Config)
	config = Share.setting({ path, text: RocInstall.read_text!(fx, path)? })?
	registry = Net.registry({ flag: args.registry, env: Net.from_env(env).registry, config: config.registry })
	match FirstRun.need({ share: config.share, registry }) {
		Skip(_) => Ok({})
		Ask => {
			asked = Prompt.ask!(fx, FirstRun.prompt({}), { mode: Interactive, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) })?
			match FirstRun.written({ answer: asked.answer, mode: asked.mode }) {
				Write(value) => ShareFlow.record!(fx, roots, value)
				Nothing => Ok({})
			}
		}
	}
}
