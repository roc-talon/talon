import Args
import Fx

## `tln share logout` and `tln share forget` (slice 220; CLI 1 R-SH9, R-SH10; Registry R-AP36, R-AP38). Direct style over `Fx`. The pure decisions are in `ShareAccount`. Stubs: `crash "todo: slice 220"`.
## The steps are in the slice file `docs/slices/220-share-logout-forget.md` (section The flow). The L2 cases are `share/sh33` to `share/sh36`.
ShareAccountFlow :: [].{

	## R-SH9, R-AP38, R-SH10. Returns the exit code.
	logout! : Fx, Args => I32
	logout! = |_fx, _args| crash "todo: slice 220"

	## R-SH9, R-AP36, R-SH10, R-SH5, R-SH13. Returns the exit code.
	forget! : Fx, Args => I32
	forget! = |_fx, _args| crash "todo: slice 220"
}
