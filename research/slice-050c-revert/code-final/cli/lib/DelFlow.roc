import Del
import Fail
import Fx
import Setup
import TalonUpdate
import Temp

## The command code of the `.del` files of Windows (slice 050c, CLI 6.7: R-ST10). Direct style over `Fx` (TESTING.md 2.2 part C): `Del` decides, this module orders the calls. `Run.run!` calls `sweep!` first in each start of `tln` when `Fx.windows!` is true (so Linux and macOS have no new call). `ToolBuild.install!` and `ToolManageFlow.remove_locked!` call `rename_away!` (the code agent adds those 2 calls). The bodies are the code agent's job (stubs).
## The calls of `sweep!`, in order (the L2 cases `tool/dl1-sweep` and `tool/dl1b-denied` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `env_all!`, `Del.dirs`. No dir: no more call. | R-ST10 |
## | 2 | One `list_dirs!` with the dirs (the bin dir, then the data bin dir), `Del.found`. No file: no more call. | R-ST10 |
## | 3 | One `delete!` with the files. Each result is ignored: a delete fails while the file runs, and the next start tries again. The sweep prints nothing and gives no exit code. | R-ST10 |
##
## The calls of `rename_away!` (the files come from `Del.replaced` or `Del.removed`): no file, or not Windows: no call. Else one `random!` (`Temp.hex`), then one `rename!` of each file to its `TalonUpdate.del_name`, in the order of the list. The first error is the failure (kind `Environment`, exit 18): `cannot move <from> to <to>: <error>` (as `TalonUpdateFlow`). The result is the new paths, which the caller can delete.
DelFlow :: [].{

	## R-ST10: the sweep at the start of `tln` (Windows only: the caller checks `Fx.windows!`).
	sweep! : Fx => {}
	sweep! = |fx| {
		dirs = Del.dirs(fx.env_all!())
		if !dirs.is_empty() {
			files = Del.found({ dirs, listed: fx.list_dirs!(dirs) })
			if !files.is_empty() {
				_ = fx.delete!(files)
			}
		}
	}

	## R-ST10: rename each file of `files` to `<name>.<16hex>.del`, before it is replaced or deleted. Windows only (`TalonUpdate.del_moves` gives no move on Linux and macOS). Gives the new paths.
	rename_away! : Fx, { os : Setup.Os, files : List(Str) } => Try(List(Str), Fail)
	rename_away! = |fx, facts| {
		if facts.os != Windows or facts.files.is_empty() {
			return Ok([])
		}
		hex = Temp.hex(fx.random!())
		moves = TalonUpdate.del_moves({ os: facts.os, hex, files: facts.files })
		for move in moves {
			match fx.rename!(move) {
				Ok(_) => {}
				Err(err) => return Err(Fail.new(Environment, "cannot move ${move.from} to ${move.to}: ${Str.inspect(err)}"))
			}
		}
		Ok(moves.map(|move| move.to))
	}
}
