import Args
import Fx
import RocInstall

## `tln roc install --git <ref>` and `tln roc install @<sha>` (slice 045, CLI 6.6, R-R1 to R-R3, R-R5 to R-R7, R-R9 to R-R11, R-SE12, R-DA3, R-SO15). Direct style over `Fx`: it calls the pure functions of `GitRef` and
## `GitBuild`, and `Toolchain` for the output. The body is the work of the code agent. The stub forwards to `RocInstall.run!`, so the old tests pass. The contract (the order of the calls is checked by `calls.log` of
## `tests/commands/cases/roc/gi1-install` and `gi2-zig`):
##
## | Step | Rule | What |
## | --- | --- | --- |
## | 1 | R-R11 | `GitRef.read({ args, bare_sha: True })`. `NotGit`: `RocInstall.run!(fx, args)`, no other call. A failure: `Common.failed!`. |
## | 2 | R-EV19 | `env_all!`, `Roots.from_env`, `Net.settings` (`TALON_GITHUB_API`, `--offline`), one `clock!`, `platform!` for the host. |
## | 3 | R-DI12 | `--offline`: `GitRef.offline_failure`, no request. |
## | 4 | R-R1, R-R3 | one `http_get!` of `GitRef.commit_url` with `GitRef.commit_headers({ token })`, `GitRef.commit_of`. The token is resolved as `Github.releases!` does (review Q1): `Net.token` of `net.token` and, for `AskGh`, one `programs!(["gh"])` before the request (and `gh auth token` when `gh` is there). The id is `GitRef.sha_id`. |
## | 5 | R-SE12 | `list_dirs!` of the toolchains: the id is there: report as already installed (`Toolchain.report`), exit 0, no download. |
## | 6 | R-DA3 | `programs!(["curl", "wget"])`, `Download.choose`. Wget: `GitRef.needs_curl`, exit 18. |
## | 7 | R-R2 | best effort `Nightlies.list!`, `GitRef.nightly_note`: the note is on stderr with no prompt. A failed list gives no note. |
## | 8 | R-D4 | `GitRef.header_line`, a blank line, to stderr (hidden by `--quiet`). |
## | 9 | R-R3, R-R7 | scratch dir, curl job to the archive (limit 8) with the full sha, `sha256_file!`, tar job (limit 1), delete the archive. |
## | 10 | R-D1 to R-D4 | `Zig.minimum` of `build.zig.zon`, `ZigInstall.ensure!` (may ask before the lock). |
## | 11 | R-SE12 | `locked!`: check again, `zig build` (`GitBuild.build_command`), move the binary, compat check, `.talon.json` (`GitBuild.meta`), rename to the id. |
## | 12 | R-SO15 | the first compiler becomes the default (`RocInstall.first_default!`). |
## | 13 | R-R6 | delete the scratch dir (and the temp dir after a failure). |
GitInstall :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| RocInstall.run!(fx, args)
}
