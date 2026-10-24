import Args
import Fx

## The command `tln roc use <ref>` (slice 026b, CLI 6.6: R-CS1, R-U1 to R-U6, R-WS13, R-RP1; Design 7 R-PH8). Direct style over `Fx` (TESTING.md 2.2 part C): `Manage` and `Pin` decide, `Ladder.use!` runs the probes,
## this module orders the calls. `Run.tln!` calls it for the command `["roc", "use"]`. The body is the work of the code agent. The calls, in order (the L2 cases `roc/us1-use`, `roc/us2-workspace` and the L3 case
## `compilers/us1-use` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Manage.read_use(args)`. A failure is printed with `Common.failed!` (no `Fx` call). `--no-check` never gets here: `Args.parse` stops it (R-U4). | R-CM15, R-U1, R-U4 |
## | 2 | `Install.begin!` (`env_all!`, `clock!`, the project), `Known.record!` (each member that the run reads: R-PD9, R-PD14), `Compiler.toolchain_of`, `Install.compiler!` (the `roc` on `PATH`) | R-PD1 to R-PD8, R-PD14 |
## | 3 | `ResolveBase.load!` (one `read_files!` of the members, the `talon.toml` files, `config.toml`, `.roc-version`), `ResolveBase.select!`, `ResolveBase.settings_of` | R-PD6, R-SO4 to R-SO7, R-NS8 to R-NS10 |
## | 4 | `Launch.toolchains!` (one `list_dirs!`). The operand names the compiler: a text that is not a step `@-N`, `@+N`, nor `@latest` goes to `Nightlies.pick` over the installed ids first (`roc default` does the same), then `RocInstall.offer!`. `Present` or `Download`. A step needs the base (`Base.selected!`, R-SL7, called by `offer!`). | R-U2, R-SL7, R-SC10 |
## | 5 | `Manage.use_pinnable(id)` (R-U1 for a prefix that named a local build), then `Pin.use_gate` with the range and the switch of step 3 (R-U5) and `times`: one `read_files!` of the `.talon.json` files (`Base.times!`, only with a range) and the `published_at` of the new compiler from the list. A refusal is exit 10 (`NoTuple`). No `talon.toml` is edited. | R-U1, R-U5 |
## | 6 | `Manage.use_plan` with the pins of the members and the compiler of a member with no pin (`ROC_TOOLCHAIN`, else the selected compiler). A member whose pin is the id has no edit and no probe. When no member has an edit, the command stops here with the line of `Manage.use_report` for no file (question Q7): no download, no probe, no write, exit 0. | R-CS1, R-WS13, R-BL1, R-SO14 |
## | 7 | The downloads: the new compiler (when step 4 gave `Download`) and each baseline compiler that is not installed and not the `roc` on `PATH` (`Compiler.find`; `RocInstall.offer!` for its size). A baseline that is not a nightly is `Compiler.require`. See the table below. | R-U2, R-U3, R-DL1 to R-DL5, R-NI5, R-NI6, Q4 |
## | 8 | `RocInstall.install_offer!` for each download, the new compiler first. | R-CC4 |
## | 9 | `Ladder.use!`: one `Ladder.UseMember` for each member with an edit, with its text and `ops` `[Pin(id)]`. The baseline check runs on the old pin, the candidate check and the build on the new compiler. A new error stops the command with exit 11 or 10 (R-H6): nothing is written. | R-U3, R-BL1, R-BL2, R-LD4, R-LD5, R-H6 |
## | 10 | Under no lock (R-CC7): one `read_files!` of the changed members, `Guard.check_all`, `Locked.edit`, one `write_atomic!` of the members (the writes come after all members passed). | R-H1, R-CC7, R-RP1 |
## | 11 | The output: `Manage.use_report` on stdout, and the note of `Manage.use_note` when `ROC_TOOLCHAIN` is set (R-U6). With `--json` the human text goes to stderr and stdout is the envelope with `Manage.use_data`. | R-OUT2, R-J3, R-U6 |
##
## The downloads of step 7 (answer of the review: Q4):
##
## | New compiler missing | Baseline compilers missing | Result |
## | --- | --- | --- |
## | yes | none | The prompt of `roc install` (`Consent.roc_install`, R-NI6): the command names it. A person: default yes. No person: no prompt, the download starts (R-DL4). `TALON_AUTO_INSTALL=no` does not refuse (answer Q2 of slice 026). |
## | any | 1 or more | One prompt for all (R-DL1): `Consent.use_download` (1 id or more, default Yes: `roc use` names its download, R-DL3). `Consent.required_want` decides as for the first probe of `install`: the answer flags, `--yes` and `TALON_AUTO_INSTALL=yes` answer it, a person is asked (default Yes), else exit 13 with `Consent.download_stop` (count, total size). `TALON_AUTO_INSTALL=no` is `Consent.download_refused` (exit 13). |
## | no | none | No prompt, no list request |
RocUse :: [].{

	## Steps 1 to 11 of `tln roc use`. The body is the work of the code agent.
	use! : Fx, Args => I32
	use! = |_fx, _args| crash "todo"
}
