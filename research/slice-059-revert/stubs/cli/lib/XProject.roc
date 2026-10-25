import Args
import Fail
import Fx
import Ref
import ToolsToml
import XCmd

## `tln x` of a project tool (slice 059, CLI 6.4: R-PT11, R-X4, R-PT8, R-PT9, R-PT12, CLI 1: R-PD9, R-PD16, R-RUN12). `tln x <key>` and `tln x owner/app` (no selector) run the project tool of `[tools]` when the `talon.toml` that the walk finds has it. Part A (`choose`, `note`)
## is pure (TESTING.md 2.2). Part C (`run!`) is direct style over `Fx`: it uses the walk of `tln run` (`RunFind` through `RunSteps.locate!`), the record of R-PD9 (`RunSteps.record_files!`) and the binary of a key (`RunTools.load!`, `bin!`).
## `XFlow.run!` calls `run!` first, and goes on with the global flow of slice 049 when it gives `Miss`.
##
## The calls of `run!`, in order (the L2 case `x/x3-project` fixes them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | A selector in the ref (`owner/app@sel`): `Miss`, no `Fx` call. The user asked for a version (R-PT11). | R-PT11 |
## | 2 | `env_all!`, `Roots.from_env`, `Clock.now!`, `cwd!`, `Project.scan!` (as step 2 and 3 of `RunFlow`). | R-PD2, R-PD3 |
## | 3 | The nearest `talon.toml` of the walk (`RunFind.find` with a file that always holds the name; a `Need` is one `read_files!`). No `talon.toml`: `Miss`. | R-PT11, R-RUN12, NC2, NC5 |
## | 4 | `RunTools.table` of the file of `[tools]` (`Found.tools_dir`). A failure is exit 19. `choose`: no hit is `Miss`. | R-PT11, R-PT1, OP4 |
## | 5 | A hit: R-PD9 (`RunSteps.record_files!`, `Known.record!`), the warnings of the table on stderr, the note for the form `owner/app`, `RunTools.load!`, `RunTools.bin!`, then `exec!` of `[<binary>] ++ <the words after -->`. | R-PD9, R-PT9, R-X4, R-E1 |
XProject :: [].{

	## The entry that `tln x` runs, and how it was named: `Key` (the operand is the key) or `App` (the operand is the app of the entry).
	Hit : { entry : ToolsToml.Entry, via : [Key, App] }

	## R-PT11: which entry of `[tools]` the operand names. The operand has no selector (`owner/app@sel` and `<key>@sel` ask for a version: `Err(None)`):
	##
	## | Operand (`ref.form`) | Hit |
	## | --- | --- |
	## | A short name that is a key of `[tools]` (`Bare`) | `Key`: that entry. A key is the whole name: `fmt` is no hit for the key `fmt2`, and the short name of an app (`fmt` for the key `format` of `acme/fmt`) is no key. |
	## | `owner/app` (`Full`) with the same app as the `ref` of an entry (`ToolsToml.app_of`) | `App`: that entry. 2 entries or more with that app: `Err(Many(keys))`, the keys in the order of their lines (review Q1) |
	## | `host/path` (`HostPath`), or any operand with a selector, or no entry | `Err(None)` |
	choose : { ref : Ref, tools : List(ToolsToml.Entry) } -> Try(XProject.Hit, [None, Many(List(Str))])
	choose = |_facts| crash "todo: slice 059"

	## R-PT11, review Q1: the failure for `Many`: kind `Usage` (exit 2), nothing is recorded, no child. The text is a proposal (TW24): `<name> is the app of <n> entries of [tools]: <key>, <key>. Use tln x <key>.`
	many : { name : Str, keys : List(Str) } -> Fail
	many = |_facts| crash "todo: slice 059"

	## R-PT11: the note for the form `owner/app` (the text of the design, on stderr): `project tool <key> <version> (talon.toml)`.
	note : { key : Str, version : Str } -> Str
	note = |_facts| crash "todo: slice 059"

	## Steps 1 to 5 (the table above). `Ok(Ok(code))`: the exit code of the app. `Ok(Err(Miss))`: no project tool, the global flow goes on. `Err(fail)`: exit 19 for a `[tools]` that is not valid, exit 14 for an entry with no `url`,
	## the failures of `RunTools.bin!`, and exit 18 when the binary does not start.
	run! : Fx, Args, XCmd.Plan => Try(Try(I32, [Miss]), Fail)
	run! = |_fx, _args, _plan| crash "todo: slice 059"
}
