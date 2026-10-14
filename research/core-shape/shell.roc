app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.29.0/GrSTLEKd6yw8orQ5ByQQVY3Htg59vZYaoHBvQELueiMB.tar.zst" }

import pf.Stdout
import pf.Path
import Program
import Deep

## The real shell: runs each command with basic-cli effects.
run! : Program.Program(a) => a
run! = |start| {
	var $prog = start
	while Bool.True {
		match $prog {
			Done(v) => { return v }
			Read(p, k) => { $prog = k(Path.read_utf8!(Path.unix(p)).map_err(|_| NotFound)) }
			Write(p, t, rest) => {
				_ = Path.write_utf8!(Path.unix(p), t)
				$prog = rest
			}
			Probes(list, k) => { $prog = k(list.map(|_| Pass)) }
			Ask(_, k) => { $prog = k(Bool.True) }
		}
	}
	crash "unreachable"
}

main! = |_args| {
	a = run!(Deep.loop(0, 100000))
	b = run!(Deep.loop_then(0, 100000))
	Stdout.line!("loop ${a.to_str()}, loop_then ${b.to_str()}")?
	Ok({})
}
