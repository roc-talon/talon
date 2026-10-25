import Args
import Fail
import Fx
import ToolCompiler
import ToolInstall

## The compiler choice of `tln tool install` (slice 047, CLI 6.4: R-T11 to R-T16, R-NI8, R-DL1 to R-DL5). Command code, direct style over `Fx`. `ToolCompiler` decides, `ToolTry` is option 2. `ToolFlow.compile!` calls `choose!` in place of the old
## `compiler_id!` (step 9). The calls, in order (the L2 cases `tool/ti3-compiler`, `ti4-nothing` and the changed `ti2-refusals` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Launch.toolchains!` (one `list_dirs!`, also for a header with no pin: the calls of slice 046 stay) and `ToolInstall.compiler`. `NoPin`: `ToolInstall.no_pin` (exit 2, D3 of slice 046, question Q-A). `Use(id)`: the result, no more call (R-T12). | R-T11, R-T12 |
## | 2 | The evidence pass, only when `ToolCompiler.evidence_keys` is not empty: one `Facts.load!` (one `db_query!`) with the keys of `ToolCompiler.candidates`. `ToolCompiler.evidence` gives a release: the line `ToolCompiler.built_line` on stderr, the result is that release (no prompt). | R-T13, R-T17 |
## | 3 | `Mode.from_env` and `ToolCompiler.decide`. `NeedTty`: one `tty!`, `Mode.with_tty`, `decide` again (at most one `tty!` in the command, R-HF1). | R-T14 to R-T16, R-NM2 |
## | 4 | `Stop(fail)`: the failure. `Download`: `RocInstall.fetch_optional!` (the line `downloading <id> (<size>)` is printed by it), the result is the pin. `TryInstalled`: the line `ToolCompiler.trying_line` on stderr (no line when no release is installed), then step 6. | R-T6, R-DL1, R-NM6 |
## | 5 | `Ask`: `RocInstall.offer!` (the size of the pin; `Present`: the pin is the result), then `Prompt.ask!` with `ToolCompiler.prompt` (`installed` is the number of `candidates`, `tried` is empty). `ToolCompiler.allowed` false: ask again. Option 1: `RocInstall.install_offer!`, the result is the pin. Option 2: step 6. Option 3: `ToolCompiler.declined`. | R-NI8, R-T14, R-T15 |
## | 6 | `ToolTry.installed!`. `Passed`: the line `ToolCompiler.built_line` on stderr, the result is that release and its attempt. `Failed(tried)`: step 7. | R-T17 to R-T19 |
## | 7 | A mode that is not interactive (one `tty!` call if the mode is still `NeedsTty`): `ToolCompiler.all_failed` (exit 13). Interactive: the prompt again with `installed` 0 and `tried`, `allowed` as in step 5. Option 1: download (`RocInstall.offer!` and `install_offer!`, with the size of the first offer), the result is the pin. Option 3: `ToolCompiler.declined`. | R-T20, R-T16 |
##
## The line of the answer of a prompt that a flag answered is printed on stderr (R-NM6): `--roc pinned`, `--yes` and `TALON_AUTO_INSTALL=yes` give the line of `RocInstall.fetch_optional!`, `--roc installed` gives `trying_line`. A person's answer prints no line.
ToolCompilerFlow :: [].{

	## What `choose!` gives. `id` is the compiler of the build. `passed` is `Ok(layout)` when option 2 built the app with `id` already (the output is in `layout.output`, the attempt passed): the caller installs it and builds nothing. `Err(None)`: the caller builds with `id`.
	Chosen : { id : Str, passed : Try(ToolInstall.Layout, [None]) }

	## Steps 1 to 7. `build` is the build attempt of the caller (`ToolFlow.attempt!`): it runs `roc build` with the release `req.id`, and gives its class, its errors and its paths. `first` is true for the first attempt of the command.
	choose! : Fx, Args, ToolCompiler.Run, { build : { id : Str, first : Bool } => Try(ToolCompiler.Attempt, Fail) } => Try(Chosen, Fail)
	choose! = |_fx, _args, _run, _hooks| crash "todo: slice 047"
}
