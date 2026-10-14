app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.29.0/GrSTLEKd6yw8orQ5ByQQVY3Htg59vZYaoHBvQELueiMB.tar.zst" }

import pf.Stdout
import Inject

## Tests as a compiled app: direct-style effectful code, fake effects from a lookup table
main! = |_args| {
	files = Dict.from_list([("a", "x\ny")])
	fake = { read!: |p| files.get(p).map_err(|_| NotFound) }
	ok = Inject.count_lines!(fake, "a") == 2 and Inject.count_lines!(fake, "b") == 0
	Stdout.line!(if ok "pass" else "FAIL")?
	Ok({})
}
