import Args
import Fx

## The commands with `--tool` (slice 056, CLI 6.4: R-PT3, R-PT5, R-PT12, R-FL7, R-FL12): `tln add --tool owner/app[@sel] [--as <key>]`, `tln remove --tool <key>...`, `tln update --tool [<key>...]`, `tln upgrade --tool [<key>...]`.
## Direct style over `Fx` (TESTING.md 2.2 part C). `ToolsCmd` reads the line, `ToolsPlan` and `ToolsToml` decide, `ToolsStep` selects, builds and writes. `Run.tln!` calls `run!` when the line has `--tool` (`ToolsCmd.op_of`), before `check_refs`.
## The commands never read or write `tools.json`, never lock it, and make no bin dir entry (R-PT12). They run no resolve of the header: no probe, no ladder, no `on_path!`, no compiler gate.
##
## The calls, in order (the L2 cases `ptool/pt1-add` and `ptool/pt3-move` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolsCmd.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-FL7, R-FL12 |
## | 2 | `Install.begin!` (`env_all!`, `clock!`, `Project.find!`), `Known.record!` of the member files (as `install`: also a run that fails later). A workspace root with no current member is allowed (the file is the root file). | R-PD9, R-PT2 |
## | 3 | `ToolsPlan.home`, one `read_files!` of that `talon.toml` (a missing file is the empty text, R-PT3), `Intent.read` with the role `Root` (the warnings on stderr), `RocInstall.read_config!` (one `read_files!`: `min-release-age`, `probe.timeout`). | R-PT2, R-TF4, R-C7 |
## | 4 | `remove`: the keys must be in `[tools]` (`ToolsCmd.no_key`), then step 8. No build, no network. | R-PT3 |
## | 5 | `add`: `ToolsCmd.key_of`. A key that is in `[tools]` with the same app acts as `update <key>`, with another app it is `ToolsCmd.key_taken`. | R-PT3 |
## | 6 | `update` and `upgrade`: the keys must be in `[tools]`. `ToolsStep.run!` with the phase `Update` or `Upgrade` and the keys (`[]` is each entry). | R-PT5 |
## | 7 | `add` (a new key): `ToolsStep.machine!`, `XCacheIo.entries!`, `ToolsStep.pick!` (the release list, the pick), `ToolsStep.chosen!` (the bundle), `ToolsStep.ensure!` (the build), then the entry `ToolsPlan.add_ref`. | R-PT3, R-PT4, R-PT6 |
## | 8 | `ToolsStep.write!` (one write for all changes, none for `--dry-run`), the lines (`ToolsStep.print!`, `nothing to change` when no row changed), `dry run: nothing was written` for `--dry-run`, with `--json` the envelope `ToolsStep.data`. | R-CC7, R-LF4, R-J3 |
ToolsFlow :: [].{

	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo: slice 056"
}
