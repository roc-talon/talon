app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst" }

import pf.Cmd
import pf.Env
import pf.Stdout

## Prototype for slice 023: what do `Env.program_name!`, `Cmd.exec_exit_code!` and `Cmd.run!` with inherited stdio give?
main! = |args| {
	match Env.program_name!() {
		Ok(name) => Stdout.line!("program_name: ${name.display()}") |> ignore
		Err(_) => Stdout.line!("program_name: error") |> ignore
	}
	match args.map(|a| a.display()) {
		[program, .. as rest] => {
			cmd = Cmd.new_str(program).args_str(rest).envs_str([("PROTO_X", "1")])
			match cmd.exec_exit_code!() {
				Ok(code) => Stdout.line!("exec_exit_code: ${code.to_str()}") |> ignore
				Err(e) => Stdout.line!("exec_exit_code err: ${Str.inspect(e)}") |> ignore
			}
			run = Cmd.new_str(program).args_str(rest).envs_str([("PROTO_X", "1")]).stdin(Inherit).stdout(Inherit).stderr(Inherit)
			match run.run!() {
				Ok(out) => Stdout.line!("run: ${Str.inspect(out.status)}") |> ignore
				Err(e) => Stdout.line!("run err: ${Str.inspect(e)}") |> ignore
			}
		}
		[] => {}
	}
	Ok({})
}

ignore : a -> {}
ignore = |_| {}
