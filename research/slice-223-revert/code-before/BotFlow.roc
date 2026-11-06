import lib.Fx

## The compat bot, part C (slice 223; Registry R-MX1, R-MX15, R-MX17): the command code. Direct style over `Fx`. The steps are in `docs/slices/223-compat-bot.md` (section "The flow").
## The exit codes are a proposal (question Q8): 0 done, 1 a hash has no fact or a sweep stays open, 2 usage (no registry, no OIDC variable, no `RUNNER_TEMP`, no tag), 15 and 20 as `tln publish`.
BotFlow :: [].{

	## One run of the bot. The operands are the nightly tags to sweep (question Q2). Then the hint audit (R-MX13).
	run! : Fx => I32
	run! = |_fx| crash "todo: slice 223"
}
