app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.Stdout



Foo : U64

# a comment that moves the second declaration

Foo : Str

main! = |_args| {
	unused = 5
	Stdout.line!("a")
}
