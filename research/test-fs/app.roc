app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.29.0/GrSTLEKd6yw8orQ5ByQQVY3Htg59vZYaoHBvQELueiMB.tar.zst" }

import pf.Stdout

main! = |_args| {
	Stdout.line!("hi")?
	Ok({})
}
