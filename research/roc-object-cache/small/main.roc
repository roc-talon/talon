app [main!] {
	lib: "lib/main.roc", pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst" }

import pf.Stdout
import lib.A
import lib.B
import lib.C
import lib.D

main! = |_args| {
	_ = Stdout.line!("a=${A.label(3)} b=${B.sorted_text(["pear", "apple", "fig"])} c=${C.run(["x", "yy", "z"])} d=${D.sorted_pairs(["a", "bbb", "cc"])}")
	Ok({})
}
