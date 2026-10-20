app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	local: "/tmp/talon-check-fixtures/project/lib-local/main.roc",
}




import pf.Stdout
import Util
import local.Local

main! = |_args| {
	Stdout.line!(Util.twice("a"))
	Stdout.line!(Local.name)
	Stdout.line!(5)
}
