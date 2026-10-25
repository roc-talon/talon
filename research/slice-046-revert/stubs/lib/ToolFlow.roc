import Args
import Fx

## The command `tln tool install owner/app` for a release (slice 046, CLI 6.4, R-CM16, R-T1 to R-T6, R-T8 to R-T12, R-T26 to R-T28, R-SE8, R-ST15, R-LY2, R-LY3, R-CC6). Direct style over `Fx` (TESTING.md 2.2 part C): `ToolInstall` and `ToolsJson` decide, this module
## orders the calls. `Run.run!` calls it for the command `["tool", "install"]`. The calls, in order (the L2 cases `tool/ti1-install` and `ti2-refusals` and the L3 case `tools/ti1-tool-install` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolInstall.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM16, R-T28 |
## | 2 | `env_all!`, `Roots.from_env`, `Net.from_env`, `Clock.now!` (one `clock!` call), `platform!`, `Setup.bin_dir`, `BuildSkip.target` (no target for the machine: kind `Environment`). | R-LY2, R-LY8, R-T8 |
## | 3 | One `read_files!` of `tools.json` (a missing file is no tool), `ToolsJson.read`. Then `RocInstall.read_config!` (one `read_files!` of `config.toml`: `min-release-age`, R-C7). | R-T4, R-T9 |
## | 4 | `Lookup.find` with the scope `Tool` and `ToolsJson.entities`: the full name (an installed tool with that name or short name, else the name as typed). A failure prints its block, then the failure. | R-SC3, R-AD7 |
## | 5 | `ToolInstall.key`, `ToolsJson.clash`: `Taken` and `Elsewhere` stop before any request (exit 2). | R-T28, R-NM11 |
## | 6 | The release list: `Github.releases!`, `Index.candidates`. `--offline` with no cached page: `Github.no_page_failure`. No candidate: `ToolInstall.no_candidate`, with one `http_get!` of `GET <api>/repos/<owner>/<repo>` (no request with `--offline`) for the default branch. | R-DI2, R-DI12, R-T10 |
## | 7 | `ToolInstall.pick`, `ToolInstall.reuse`: `Keep` ends the command (no build, R-T26). `young`: `ToolInstall.age_note` on stderr. | R-T9, R-T26 |
## | 7b | `entry_verdict!` (review of Q8, fail fast): `list_dirs!` of the bin dir, `SetupIo.have_of!`, `sha256_file!` of the data bin file, `ToolInstall.verdict`. `Foreign`: `ToolInstall.foreign_failure` (exit 2) before the download and the build. The same check runs again under the lock (step 12). | R-ST6, R-ST11 |
## | 8 | For each candidate in order: `Fetch.packages!` of its URL, one `read_files!` of `<pkgs>/<hash>/main.roc`, `Release.read`. A bundle that is not an app is dropped (R-T10). None left: `ToolInstall.no_candidate` with the newest tag. `Locked.read` gives the pin. | R-T10, R-T1, R-FE2 |
## | 8b | `check_platform!` (review of Q9): the platform of the app header, when it is a release URL (`Ident.of_url`): `Fetch.packages!` of it, one `read_files!` of `<pkgs>/<hash>/main.roc`, `BuildTarget.targets_of`, `ToolInstall.native`. `WasmOnly`: `ToolInstall.not_native` (exit 2). A path entry or a header with no `targets` is admitted (no call). | R-T2 |
## | 9 | `Launch.toolchains!` (one `list_dirs!`), `ToolInstall.compiler`. `Missing`: `ToolInstall.want`, then `RocInstall.offer!`, the line `Consent.optional_line` on stderr and `RocInstall.install_offer!` (R-T6). | R-T11, R-T12, R-T6, R-DL1 |
## | 10 | `random!`, `ToolInstall.layout`, `ToolInstall.header_lines` on stderr. `Launch.program!`, `Launch.touch!`, `Launch.child_env!`, `make_dirs!` of the temp dir, one `probes!` with `ToolInstall.build_spec`. A result that is not a pass: `ToolInstall.build_failed`. | R-SE8, R-T11, R-T8, R-T5, R-CC9, R-PX6 |
## | 11 | The lock of `tools.json` (`Fx.locked!` on `Roots.item(ToolsJson)`, `Wait`, R-CC3), for the last step only (R-CC6): `read_files!` and `ToolsJson.read` again, `ToolsJson.clash` again (`Taken`, `Elsewhere`), `list_dirs!` of the bin dir, `SetupIo.have_of!`, `sha256_file!` of the old binary, `ToolInstall.verdict` (`Foreign`: exit 2, nothing is written). | R-CC6, R-T28, R-ST6, R-ST11 |
## | 12 | Under the lock: the check of step 7b again (`entry_verdict!`: the file can appear during the build), then `make_dirs!` of the data bin dir and the bin dir, `copy_file!` of the output to the temp name, `rename!` (R-CC1), `sha256_file!` of the binary, `hard_link!` to the temp name of the entry (else `copy_file!`), `rename!`, then `write_atomic!` of `tools.json` (`ToolsJson.add`). | R-T3, R-T4, R-ST7, R-ST15, R-CC1 |
## | 13 | `delete!` of the temp dir (also after a failure, R-CC2). The output: `ToolInstall.report` (`--quiet` hides it, R-FL4). With `--json` the text goes to stderr and stdout is `Out.json_ok` with `ToolInstall.data`. | R-J1 to R-J4, R-OUT2 |
ToolFlow :: [].{

	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo: slice 046"
}
