app [main!] {
	bot: "lib/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst",
	real: "../cli/real.roc",
}

import bot.BotFlow
import real.RealFx

## The compat bot app (slice 223, Registry R-MX17): build the real `Fx`, run `BotFlow.run!`, exit with its code. No Talon logic here (TW4).
## `real` is the package `cli/real.roc`: one copy of the real `Fx`, shared with `tln` (an app cannot import a file outside its own directory, but it can use a package).
main! = |args| {
	code = BotFlow.run!(RealFx.make!(args.map(|a| a.display())))
	if code == 0 Ok({}) else Err(Exit(code))
}
