## The compat bot (slice 223, Registry R-MX1, R-MX15, R-MX17): the pure decisions (`Bot`) and the command code (`BotFlow`).
## It uses `lib` (the `Fx` record, `Registry`, `Publish`) and `records` (the bodies of R-AP10). The app `bot/main.roc` builds the real `Fx`.
package
	[
		Bot,
		BotFlow,
	]
	{
		lib: "../../cli/lib/main.roc",
		records: "../../packages/records/main.roc",
	}
