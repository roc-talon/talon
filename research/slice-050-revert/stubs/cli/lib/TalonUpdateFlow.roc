import Args
import Fx

## The command `tln tool update talon [--from-source]` (slice 050, CLI 6.5: R-S2, R-S3, R-S1, R-T9, R-T22, R-ST9, R-ST10, R-SE13, R-DA2 to R-DA4, R-HF2, R-CC1, R-CC2, R-CC6, R-J1 to R-J4). Direct style over `Fx` (TESTING.md 2.2 part C): `TalonUpdate` decides, this module orders the calls.
## `Run.run!` calls `update!` for `["tool", "update"]` when `TalonUpdate.is_target(args)` (one operand, `talon` or `roc-talon/talon`), else `ToolUpdateFlow.update!`. The calls, in order (the L2 cases `tool/ts1-update` to `ts6-source` and the L3 case `tools/ts1-update-talon` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolManage.read(args)` (a failure: `Common.failed!`, no `Fx` call). `ToolManageFlow.machine!`: `env_all!`, `clock!`, `platform!`, one `read_files!` of `tools.json` (the entry `talon` is read from the same text), one `read_files!` of `config.toml`. | R-CM16, R-FL12 |
## | 2 | The release list of `roc-talon/talon`: `Github.releases!` (the cache page of R-DI2: `list_dirs!`, `http_get!`, `write_atomic!`; with `--offline` the cached page, the line `index: cached at <time>`, or `Github.no_page_failure`), then `TalonUpdate.releases` with the asset name (`TalonUpdate.asset_name`). A page that is not a release list: kind `Network`. | R-DI2, R-DI12, R-IS2 |
## | 3 | `TalonUpdate.current` (the entry, else `Help.version`), `TalonUpdate.pick`. A failure ends the command. `Current`: `TalonUpdate.up_to_date_text`, exit 0, nothing is downloaded or changed. | R-T9, R-C7, R-S4 |
## | 4 | `--from-source`: `source!` (part b, steps 4b to 4g below). No flag: steps 5 to 12. | R-S2 |
## | 4b | `--offline`: `GitRef.offline_failure` (exit 15, no call). One `http_get!` of the commit of the tag (`ToolGitFlow.head!`, as `tool update` of a branch). The entry is a source build of that commit: `TalonUpdate.up_to_date_text` with the text of the source, exit 0. | R-T24, R-DI12 |
## | 4c | The entries (step 6): `Foreign` `tln` is exit 2 before the download. | R-ST6, R-ST11 |
## | 4d | `ToolGitFlow.check_curl!` and `ToolGitFlow.source!` (the source archive of the commit, `main.roc` of the dir `cli`: the app). `ToolFlow.platform_for!` (R-T2). | R-S2, R-T23, R-R3, R-R7 |
## | 4e | `ToolUpdateFlow.consent_for!` (one decision for the compiler of the pin of the app: R-DL1 to R-DL5, as step 3 of `tool update`). An app with no pin: `ToolInstall.no_pin`. | R-DL1, R-T11 |
## | 4f | `ToolBuild.finish!` with the key `talon`, the file `tln` and the name `roc-talon/talon`: the build in the source, the install under the lock of `tools.json` (the entry `talon` is a git tool with the `path` `cli`), the entry `tln`. The build has no `--version` check: it is the build of `tool install` (R-T22 names the check for the prebuilt file only; question Q-F2). | R-S2, R-T4, R-T5 |
## | 4g | The entry `roc` again (if `entries` makes it, `ToolBuild.link_entry!`). `delete!` of the scratch dir of the source (also after a failure, R-CC2). The line `TalonUpdate.updated_text` with `TalonUpdate.source_text` of the new entry. | R-ST9, R-CC2 |
## | 5 | `--offline`: `TalonUpdate.offline_failure` (exit 15, no call). A release with no `sha256sums.txt`: `TalonUpdate.missing` (exit 16, no call). | R-DI12, R-S1 |
## | 6 | The entries (`states!`, `TalonUpdate.entries`): `list_dirs!` of the bin dir, `sha256_file!` of the file `tln` in the data bin dir, then `SetupIo.have_of!` for `tln` and for `roc` (one `sha256_file!` for each entry that is there), `ToolInstall.verdict` for each. `Foreign` `tln`: exit 2, before the download. | R-ST6, R-ST11, R-ST9 |
## | 7 | One `random!` (the hex of the temp names and of the `.del` names). `programs!(["curl", "wget"])` and `Download.choose`. `make_dirs!` of the data bin dir and of `<cache>/talon/tmp/<hex>`. One `spawn_all!` (limit 8) with 2 jobs: `Download.command` for the binary to `<data bin>/tln.<hex>.tmp` (`Temp.name`), then for `sha256sums.txt` to `<cache>/talon/tmp/<hex>/sha256sums.txt`. A failed job: `Toolchain.download_failed` with the id `talon <version>`. | R-DA2 to R-DA4, R-HF4 |
## | 8 | `sha256_file!` of the temp file, one `read_files!` of `sha256sums.txt`, `TalonUpdate.expected_sha` (`NotListed`: `TalonUpdate.unlisted`), `TalonUpdate.check_download` (exit 16). | R-S1, R-SE13 |
## | 9 | `TalonUpdate.chmod_command`: one `spawn_all!` (limit 1) of `chmod 0755 <temp>` (none on Windows). One `spawn_all!` (limit 1) of `<temp> --version`, `TalonUpdate.version_check`. | R-HF2, R-S3 |
## | 10 | `Fx.locked!` on `Roots.item(ToolsJson)` (`Wait`, R-CC3) for the last step only (R-CC6): one `read_files!` of `tools.json`, step 6 again (the entries can change during the download), `TalonUpdate.del_moves` (Windows: one `rename!` of each existing file to its `.del` name), one `rename!` of the temp file over the file `tln` of the data bin dir, then for each name of `make` (`tln`, `roc`): `ToolBuild.link_entry!` (`hard_link!` to a temp name, else `copy_file!`, then `rename!`, R-ST7), then one `write_atomic!` of `tools.json` (`ToolsJson.put_talon`). | R-S3, R-ST9, R-ST10, R-CC1, R-CC6 |
## | 11 | One `delete!` of the temp file and of `<cache>/talon/tmp/<hex>`, after a success and after a failure (R-CC2). | R-CC2 |
## | 12 | The warnings of `TalonUpdate.entries` on stderr. The line `TalonUpdate.updated_text` on stdout (`--quiet` hides it). With `--json` the text goes to stderr and stdout is `Out.json_ok` with `ToolUpdate.data` of `TalonUpdate.outcome`. | R-J1 to R-J4, R-OUT2 |
## Part 050b (this module): the prebuilt path (steps 1 to 3 and 5 to 12) and `--from-source` (steps 4 and 4b to 4g: the private `source!` and `built!`, the public `ToolUpdateFlow.consent_for!`, the layout key of `ToolBuild.attempt!`). Part 050a (`TalonUpdate`, `ToolsJson`, `ToolManage`, `ToolManageFlow`) comes first.
TalonUpdateFlow :: [].{

	## `tln tool update talon`.
	update! : Fx, Args => I32
	update! = |_fx, _args| crash "todo: slice 050b"
}
