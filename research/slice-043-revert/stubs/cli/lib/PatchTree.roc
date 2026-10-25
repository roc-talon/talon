import Diff
import Fail
import Fx

## The files of some trees on disk, for `tln patch --diff` (slice 042) and for the move of a patch (slice 043, `PatchApply`). Command code over `Fx` (part C). `PatchFlow` had these functions in slice 042: the code agent moves them here
## (the calls of `tln patch --diff` do not change).
PatchTree :: [].{

	## The files of each dir of `dirs`, level by level (one `list_dirs!` call for each level, with the dirs of all trees that have it, in the order of `dirs`), then one `read_files!` call for all files (the files of the first tree, then of the second, in byte order of the paths).
	## A file that `read_files!` cannot read as text is `Binary(sha256)` (`sha256_file!`, D11 of slice 042). The result has one list for each dir, in the order of `dirs`. `copy` is one of `dirs`: when its root is missing the failure is of kind `Usage`:
	## `<copy>/ is missing. Restore the copy, or remove the entry from [patch].` Any other dir that cannot be listed or read is a failure of kind `Environment`, `cannot read <path>`.
	read! : Fx, { dirs : List(Str), copy : Str } => Try(List(List(Diff.File)), Fail)
	read! = |_fx, _x| crash "todo: slice 043"
}
