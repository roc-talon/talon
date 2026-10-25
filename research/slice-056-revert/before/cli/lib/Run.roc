import Add
import Args
import CacheClean
import CacheGc
import CacheShow
import Exit
import Fail
import Fx
import GitDefault
import GitInstall
import Help
import Init
import Install
import Kind
import Ls
import Out
import OutdatedFlow
import PatchFlow
import PathFlow
import ProbeFlow
import Proxy
import Ref
import Remove
import RocInstall
import RocLink
import RocManage
import RocUse
import Scope
import SetupFlow
import ToolGitFlow
import ToolManageFlow
import ToolUpdateFlow
import Update
import Upgrade
import Verify
import Why
import XFlow

## The command code of `tln` (direct style, TESTING.md 2.2 part C).
Run :: [].{

	## Runs one `tln` call and gives the exit code. It reads the arguments and the environment from `fx`,
	## parses them (`Args.parse`), prints with `Out`, and chooses the code with `Exit.choose`.
	## Slice 001 has no command that works: a known command prints a failure of kind `Internal`
	## (proposal: `command '<name>' is not built yet`). A parse failure prints with `Out.fail`.
	## `--help`, `help` and `--version` print on stdout with code 0. No command prints the usage on stderr
	## with code 2 (Q7).
	run! : Fx => I32
	run! = |fx| if Proxy.is_proxy(fx.program_name!()) Proxy.run!(fx) else Run.tln!(fx)

	## The commands of `tln` (the program name is not `roc`, R-ST8).
	tln! : Fx => I32
	tln! = |fx| {
		words = fx.args!()
		match Help.route(words) {
			Help => {
				fx.out!(Help.usage)
				0
			}
			Version => {
				fx.out!("tln ${Help.version}\n")
				0
			}
			Command => match Args.parse(words) {
				Err(stop) => fail!(fx, { command: stop.typed, json: stop.json, fail: stop.fail })
				Ok(args) => if args.command.is_empty() {
					fx.err!(Help.usage)
					fx.err!("${Fail.new(Usage, "no command").line()}\n")
					Kind.code(Usage)
				} else {
					match check_refs(args) {
						Err(failure) => fail!(fx, { command: args.typed, json: args.json, fail: failure })
						Ok({}) => if args.command == ["init"] {
							Init.run!(fx, args)
						} else if args.command == ["install"] {
							Install.run!(fx, args)
						} else if args.command == ["remove"] {
							Remove.run!(fx, args)
						} else if args.command == ["update"] {
							Update.run!(fx, args)
						} else if args.command == ["upgrade"] {
							Upgrade.run!(fx, args)
						} else if args.command == ["verify"] {
							Verify.run!(fx, args)
						} else if args.command == ["list"] {
							Ls.run!(fx, args)
						} else if args.command == ["why"] {
							Why.run!(fx, args)
						} else if args.command == ["outdated"] {
							OutdatedFlow.run!(fx, args)
						} else if args.command == ["patch"] {
							PatchFlow.run!(fx, args)
						} else if args.command == ["probe"] {
							ProbeFlow.run!(fx, args)
						} else if args.command == ["roc", "install"] {
							GitInstall.run!(fx, args)
						} else if args.command == ["roc", "link"] {
							RocLink.link!(fx, args)
						} else if args.command == ["roc", "list"] {
							RocManage.list!(fx, args)
						} else if args.command == ["roc", "default"] {
							GitDefault.run!(fx, args)
						} else if args.command == ["roc", "remove"] {
							RocManage.remove!(fx, args)
						} else if args.command == ["roc", "update"] {
							RocManage.update!(fx, args)
						} else if args.command == ["roc", "use"] {
							RocUse.use!(fx, args)
						} else if args.command == ["cache", "gc"] {
							CacheGc.run!(fx, args)
						} else if args.command == ["cache", "clean"] {
							CacheClean.run!(fx, args)
						} else if args.command == ["cache", "dir"] {
							CacheShow.dir!(fx, args)
						} else if args.command == ["cache", "list"] {
							CacheShow.list!(fx, args)
						} else if args.command == ["path"] {
							PathFlow.run!(fx, args)
						} else if args.command == ["setup"] {
							SetupFlow.run!(fx, args)
						} else if args.command == ["x"] {
							XFlow.run!(fx, args)
						} else if args.command == ["tool", "install"] {
							ToolGitFlow.run!(fx, args)
						} else if args.command == ["tool", "list"] {
							ToolManageFlow.list!(fx, args)
						} else if args.command == ["tool", "remove"] {
							ToolManageFlow.remove!(fx, args)
						} else if args.command == ["tool", "update"] {
							ToolUpdateFlow.update!(fx, args)
						} else if args.command == ["tool", "rebuild"] {
							ToolUpdateFlow.rebuild!(fx, args)
						} else {
							fail!(fx, { command: args.typed, json: args.json, fail: Fail.new(Internal, "command '${args.typed}' is not built yet") })
						}
					}
				}
			}
		}
	}
}

# W1 to W4: the checks of the operands that need no file and no index (R-SL13). `probe` is not here (R-SC1:
# its operand can be a path), and `tool`, `x` and `roc` are P1.
check_refs : Args -> Try({}, Fail)
check_refs = |args| {
	commands = ["install", "update", "upgrade", "remove", "why", "patch"]
	if !commands.contains(Str.join_with(args.command, " ")) {
		return Ok({})
	}
	scope = Scope.of_command(args.command) ? |_| Fail.new(Internal, "no scope for '${args.typed}'")
	git = args.options.any(|(flag, _)| flag == "--git")
	for operand in args.operands {
		_ = Ref.parse(operand, scope, git)?
	}
	if args.command == ["install"] {
		Add.check_names({ names: args.operands.len(), as_alias: option_value(args, "--as") })
	} else {
		Ok({})
	}
}

# The value of a flag that has one, or `Unset`.
option_value : Args, Str -> Try(Str, [Unset])
option_value = |args, name| match args.options.find_first(|(flag, _)| flag == name) {
	Ok((_, value)) => value
	Err(NotFound) => Err(Unset)
}

# Print a failure with `Out.fail` and give its exit code.
fail! : Fx, { command : Str, json : Bool, fail : Fail } => I32
fail! = |fx, run| {
	shown = Out.fail(run)
	if !shown.stdout.is_empty() fx.out!(shown.stdout)
	fx.err!(shown.stderr)
	Exit.choose({ failures: [run.fail], child: Err(NoChild) })
}
