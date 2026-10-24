app [main!] {
	http: "https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
	lib: "lib/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import lib.Run
import RealFx

## `tln`. No Talon logic here (TW4): build the real `Fx`, run the command code, exit with its code.
main! = |args| {
	code = Run.run!(RealFx.make!(args.map(|a| a.display())))
	if code == 0 Ok({}) else Err(Exit(code))
}
