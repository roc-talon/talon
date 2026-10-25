import Fail
import Fx
import Zig

## The Zig dependency of a source build (slice 044, CLI 6.6, R-D1 to R-D4, R-NI6, R-DL1 to R-DL4). Direct style over `Fx` (TESTING.md 2.2 part C): `Zig` decides, this module orders the calls.
## There is no command in slice 044. Slice 045 (`tln roc install --git`) calls `ensure!` after it has read `build.zig.zon` of the source (`Zig.minimum`). The L2 entry `zig` (`tests/commands/main.roc`) and the test
## tool `flowprobe zig` (`cli/flowprobe.roc`) are the stand-ins for that command. The calls, in order (the L2 cases `zig/zs1-search`, `zig/zi1-install` and the L3 case `compilers/zi1-zig-install` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Roots.from_env(env)` and `Net.from_env(env)` (no call). `Fx.platform!` and `Toolchain.host`. A failure is kind `Environment` (exit 18) before any other call. | R-CV8 |
## | 2 | One `programs!(["zig"])`. One `list_dirs!([<cache>/toolchains])` (a missing dir is an empty list), and `Zig.installed`. Then the versions, with one `spawn_all!` (limit 2, `cwd: Err(Inherit)`): the job `[<path of ZIG>, "version"]` when `Zig.env_zig` gives a program, and the job `["zig", "version"]` when `programs!` says that `zig` is on `PATH`. No call when there is no job. The version is the first line of the stdout, trimmed, when the child ended with `Exited(0)` and the line is not empty. Any other end: `Err(Unknown)`. | R-D1, R-EV11 |
## | 3 | `Zig.search`, with the candidates `Env`, `Path`, `Installed`. Then `fx.err!(Zig.deps(...))` (hidden by `--quiet`, R-FL4). `Found`: the command ends with `how: Found(source)`. No request, no prompt, no lock. `Missing`: one more `fx.err!("\n")` (the empty line before the prompt), also hidden by `--quiet`. | R-D1, R-D3 |
## | 4 | `--offline`: the failure `Toolchain.offline_missing("zig <Zig.wanted(need)>")` (kind `Network`, exit 15). No request. | R-DI12 |
## | 5 | `Clock.now!(fx, env)` (one `clock!` call, `TALON_NOW`: R-EV22). | R-EV22 |
## | 6 | One `http_get!({ url: Zig.index_url(env), headers: [] })`. A transport error, a timeout or a status other than 200 is a failure of kind `Network` (exit 15): `cannot read the Zig index <url>: HTTP <status>`, `... : no answer in 20 s`, `... : <text>`. | R-D2, R-EV16, R-EV21 |
## | 7 | `Zig.pick({ index: <body>, need, host })`. A failure is the failure of the run. | R-D2 |
## | 8 | `Prompt.ask!(Consent.zig_install({ version, size }))` with the mode of `Mode.from_env`, `facts.yes`, `facts.quiet` and no answer flag. `No`: `Consent.zig_install_declined`. Before the lock (R-CC3 point 5). | R-NI6, R-DL1, R-DL3, R-DL4, R-CC4 step 2 |
## | 9 | `Fx.locked!` on `Roots.item(Zig(version))` (the line `waiting for another tln: ...` comes from `with_lock!`). Steps 10 to 12 run inside. | R-CC3, R-CC4 step 3, R-CC5 |
## | 10 | One `list_dirs!` of `<cache>/toolchains`. The dir `zig-<version>` is there now: `Present`, no more calls. Else `Temp.of_item` gives the stale temps, and one `delete!` removes them (no call when there are none). | R-CC4 steps 4, 5 |
## | 11 | One `random!`, `Zig.plan`. One `programs!(["curl", "wget", "xz"])` and `Download.choose` (a failure is kind `Environment`). `Zig.needs_xz` and no `xz`: kind `Environment` (exit 18), `xz is not on PATH: tar needs it to extract <archive name>` (R-EC18). `make_dirs!([temp])`. One `spawn_all!` (limit 8): `Download.command` with `dest: archive`. A failure: `Toolchain.download_failed` with the id `zig-<version>`. | R-DA2, R-DA3, R-DA4, R-HF4 |
## | 12 | `sha256_file!(archive)`, `Toolchain.check_download` with the id `zig-<version>` and the `sha256` of the index. A failure deletes the temp dir (kind `Integrity`, exit 16). Then one `spawn_all!` (limit 1): `Toolchain.tar_command`. A failure: `Toolchain.tar_failed`. Then `delete!([archive])`. Then one `spawn_all!` (limit 1) with `Toolchain.chmod_command` for `Zig.Plan.zig` (no call for a Windows host). Then `write_atomic!([meta])` (`Zig.meta`, last), then `rename!({ from: temp, to: item })`. `Err(Exists)` is `Installed` (the other process won, drop the temp, as R-FE3). Each failure after `make_dirs!` deletes the temp dir. | R-D2, R-CV4, R-HF2, R-HF5, R-SE9, R-CC4 step 6 |
## | 13 | The unlock is done by `with_lock!` (R-CC4 step 7). The result: `how` is `Installed`, or `Present` (step 10), `path` is `<item>/<Zig.exe(host)>`. | R-CC4 step 7 |
##
## The output is on stderr only: the dependency list, the answer line of the prompt (R-NM6) and the wait line. The command prints no line when the install ends. `--json` has no effect on the lines (the caller prints the envelope).
## A failure writes no file in the toolchains dir: no `zig-<version>` dir, no temp, no download (R-CC2).
ZigInstall :: [].{

	## What `ensure!` needs. `need` is the text of `minimum_zig_version` (`Zig.minimum`). `env` is the environment (`Fx.env_all!` of the caller). `yes`, `quiet`, `json` and `offline` are the flags of the command.
	## `llvm` is the LLVM line of the dependency list (question Q4: the caller finds the asset of `roc-lang/roc-bootstrap`).
	Facts : { need : Str, env : List((Str, Str)), yes : Bool, quiet : Bool, json : Bool, offline : Bool, llvm : { target : Str, size : Try(U64, [Unknown]) } }

	## The result. `how` is `Found(source)` (a Zig that was there: no install), `Installed` (this run installed it), or `Present` (another process installed it while this run waited for the lock, step 10).
	Done : { version : Str, path : Str, how : [Found(Zig.Source), Installed, Present] }

	## The steps of the table at the top.
	ensure! : Fx, ZigInstall.Facts => Try(ZigInstall.Done, Fail)
	ensure! = |_fx, _facts| crash "todo: slice 044"
}
