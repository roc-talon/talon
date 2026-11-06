import Args
import Fx

## The command code of `tln probe --smoke` (slice 218b, R-PB10, Design Q579). Command code over `Fx` (TESTING.md 2.2 part C). The L2 cases `probe/sm1` to `sm5` fix the calls. The decisions are `ProbeSmoke` (part A) and `Smoke` (slice 218: `result`, `app_text`).
##
## | # | Step | Calls (`calls.log`) | Rule |
## | --- | --- | --- | --- |
## | 1 | `ProbeSmoke.read`: a failure is `Common.failed!`, no call after the prelude | `args`, `env_all`, `tty` | R-PB10, R-FL12 |
## | 2 | An alias operand: the prelude and the compiler of `tln probe` with no `--range` (`ProbeFlow.flow!`, `single!`): the project, `Known.record!`, the run compiler (`ROC_TOOLCHAIN` first), `ResolveLoad.prepared!`, the pin check, `HeldRoc.held!`, `Start.run!`; the calls are those of `probe/pc1-targets` up to `canonical <cache> <roc cache>`. A URL operand uses no project (Design Q591): `env_all`, `clock`, `RocInstall.read_config!` (one `read_files` of `config.toml`), `Compiler.toolchain_of`, `path_roc`, `Launch.toolchains!`, `Compiler.select` with no project (ranks 2, 6, 7), `Start.run!`: no `cwd`, no project search, no `projects.json` record (`probe/sm1`) | as `probe/pc1-targets` (alias), `probe/sm1` (URL) | R-PB10 (section 13), R-SO21, R-PD16 |
## | 3 | The platform: an alias is `ProbeCmd.entry` (a node that is not a platform is exit 2 here: no more call; the URL form was checked by `read`), a URL is `Ident.of_url` (read made sure that it works) | none | R-PB10 |
## | 4 | The platform is in `packages/<hash>/`: `Fetch.packages!` of the URL (the calls of `probe/pc1-targets` and `probe/sm3`: `random`, `list_dirs`, and with no dir `programs`, `make_dirs`, the download, the unbundle, `rename`, `delete`). The unbundle program is the held compiler. A failure is its code (16 for a wrong hash, R-FE2) | `random`, `list_dirs <pkgs>`, ... | R-PB10, R-FE1, R-FE2 |
## | 5 | One `read_files` of `<pkgs>/<hash>/main.roc`, then `ProbeSmoke.pick`: exit 2 in the order of Design Q586: not a platform, no target to build, a target that is not of the platform | `read_files` | R-PB10 |
## | 6 | For each target, in order: `Smoke.app_text` (the URL of step 3), `random`, `make_dirs` of `<cache>/talon/tmp/<hex>`, `write_atomic` of `<tmp>/main.roc` | `random`, `make_dirs`, `write_atomic` | R-SM1, R-SM2 |
## | 7 | One `probes!` round for all targets: `roc build --target=<t> main.roc --output=<tmp>/tln-probe.out --no-cache`, `timeout` of `probe.timeout`, the cwd is the temp dir. No budget, no `Smoke` query (the build always runs) | `probes <n>` | R-PB10, R-SM4, R-LD8 |
## | 8 | `Smoke.result` of each output. One `db_write!` `Smoke` with the rows of the `Row` results (any outcome, `hang` too; `Machine` and a result with no fact give none). No queue call. Then one `delete!` of the temp dirs | `db_write ... smoke=<n>`, `delete` | R-SM4, R-SM7 |
## | 9 | The text (stdout, or stderr with `--json`) and, with `--json`, the envelope with `ProbeSmoke.data`. Exit 0, or exit 1 with `data` null and `error.details.smoke` when an item is `no-fact` (Q590) | none | R-PB8, R-OUT4 |
ProbeSmokeFlow :: [].{

	## The command. Called by `Run.dispatch!` for a `probe` line that has `--smoke` or `--target`.
	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo: slice 218b"
}
