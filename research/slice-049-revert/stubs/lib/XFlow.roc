import Args
import Fx

## The command `tln x owner/app [-- args]` (slice 049, CLI 6.4: R-CM12, R-X1 to R-X5, R-B1 to R-B3, R-B5, R-B7 to R-B10, R-NI9, R-FL1, R-E1, R-SC4, R-AD7, R-C6). Direct style over `Fx` (TESTING.md 2.2 part C): `XCmd` and `XCache` decide, this module orders the calls. It builds as `tln tool install`
## does (the pieces of `ToolFlow` and `ToolBuild`), but writes an `x` cache entry (R-X2) and runs the binary (R-X4). `Run.run!` calls `run!` for the command `["x"]`. The calls, in order (the L2 cases `x/x1-run` and `x/x2-offline` and the L3 case `tools/x1-run` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `XCmd.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM12, R-FL1 |
## | 2 | `ToolFlow.machine_for!` (the steps 2 and 3 of `ToolFlow`: `args`, `env_all`, `clock`, `platform`, `tools.json`, `config.toml`), then `XCacheIo.entries!`. | R-LY2, R-X2 |
## | 3 | `Lookup.find` with the scope `X` and `XCache.entities` (the installed tools and the entries). A short name with no match: its failure (R-AD7, R-NM11), exit 2. A full name: itself. The binary name is the repo name (`Text.last_segment`). | R-SC4, R-AD7 |
## | 4 | With no `--offline`: `ToolFlow.release_list_for!` (the calls of step 6 of `ToolFlow`). A failure of the kind `Network` (no network) is the offline case of step 7, any other failure ends the command. | R-B3, R-B7 |
## | 5 online | `ToolInstall.pick`, the installed tool of the name (`ToolsJson.manifest` of step 2), `XCache.choose` with `Online`. `Installed(tool)`: step 8. `Cached(hit)`: `XCacheIo.touch!`, then step 8. `NoMatch`: step 6. For a build that is used: `note: <XCmd.no_data>`, then `XCmd.available` when it is older than the newest candidate. | R-B1 to R-B3, R-B5, R-C6 |
## | 6 | A build: `ToolFlow.notes_for!`, `ToolFlow.first_app_for!`, `ToolFlow.platform_for!`, `ToolFlow.choose_for!` (the compiler choice and the consent of slice 047, R-X1), `ToolBuild.built!` (the build, R-SE8: the platform line and the `building` line on stderr), `random!`, `XCacheIo.write!`, `delete!` of the temp dir of the build (also after a failure, R-CC2). No `ToolBuild.entry_verdict!`, no lock, no `tools.json`, no bin dir. | R-X1, R-X2, R-X3, R-CC11 |
## | 7 offline | (`--offline`, or step 4 gave the failure `Network`). `XCache.choose` with `Offline`. `Installed(tool)`: `note: <XCmd.offline_installed>`, step 8, no prompt (R-B8). `Cached(hit)`: `Prompt.ask!` with `XCmd.unchecked_prompt` (`Run`): `flag` `Ok(Yes)` for `--allow-unchecked`, `yes` is `--yes`; `No`: `XCmd.declined`; `Yes`: `XCacheIo.touch!`, step 8. `NoMatch`: the failure of step 4, or `XCmd.offline_no_build` for `--offline`. | R-B7, R-B8, R-NI9 |
## | 8 | `exec!` of `[<binary>] ++ <the words after -->` with no more variables. `Ok(code)`: the exit code of the run is `code`. `Err(NotStarted(text))`: `XCmd.start_failed`. The binary is `<data bin>/<key>` of the installed tool (R-B5: in place, no copy) or `<entry dir>/<file>`. | R-X3, R-X4, R-E1, R-HF6 |
XFlow :: [].{

	## Steps 1 to 8.
	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo: slice 049"
}
