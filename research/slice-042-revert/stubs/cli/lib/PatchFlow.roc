import Args
import Fx

## The command `tln patch` (R-CM10, R-PA1 to R-PA3, R-PA8, R-PA14, R-PD14; slice 042). Command code in direct style over `Fx` (TESTING.md 2.2, part C). The pure decisions are in `PatchCmd` and `Diff`.
## `calls.log` of `tests/commands/cases/patch/pa1-flow` is the contract of the order of the calls. The steps:
##
## | Step | Work | Calls and notes |
## | --- | --- | --- |
## | 1 | `PatchCmd.read(args)`. A failure is printed as the other commands print it (exit 2) | no `Fx` call |
## | 2 | The start of `tln install`: `Install.begin!` (the environment, the clock, the project, the record in `projects.json` R-PD9), the member check, the load of the project as `tln list` loads it (`Ls.request_of`, `ResolveLoad.load!`) | the first calls of each run in `calls.log` |
## | 3 | The member is the project file. `PatchCmd.entry` of the name and the rows of the member. A failure: its `block` (if not empty) on stderr, then the failure | no call |
## | 4 | The `talon.toml` of the member, or `<dir of the file>/talon.toml` when there is none | no call |
## | 5a | Without `--diff`: `list_dirs` of the copy dir (`PatchCmd.place`). It answers `Ok`: failure `PatchCmd.exists` (exit 2), nothing else. Then the fetch of the release by hash (`Fetch.packages!`, R-PA13: offline fails as any fetch), `copy_tree!` of `packages/<hash>` to the copy dir, `IntentEdit.add_patch`, one `write_atomic!` of `talon.toml`. Output: `PatchCmd.created` | `list_dirs`, `random` and `list_dirs` of the package dir (the fetch), `copy_tree`, `write_atomic` |
## | 5b | With `--diff`: the entry of `[patch]` (`Intent.patches` of the `talon.toml` of the member) whose key is the alias. None: failure kind `Usage`, `<alias> has no patch. Run tln patch <alias> first.` (answer Q1, run 13). A copy dir that is missing (the answer of `list_dirs` for the dir of the copy): failure kind `Usage`, `<dir>/ is missing. Restore the copy, or remove the entry from [patch].` (run 14). The base is the `base` of the entry: when it is the hash of the header entry the package is fetched as in 5a (it may be missing), else it must be in the cache. The 2 trees are read level by level (one `list_dirs` call for the 2 dirs of a level), then one `read_files` call for all files (a file that is not UTF-8 text: `sha256_file`). `Diff.make`, then `PatchCmd.shown`. Nothing is written | `list_dirs`, `read_files`, `sha256_file` |
## | 6 | Output: without `--diff`, the text goes through `Common.shown_fx` (stderr with `--json`), with `--diff` the diff goes to stdout (`--json`: the envelope only). `--json` prints the envelope with `command` `patch` (`args.typed`) and the `data` of `PatchCmd`. The `note` goes to stderr | `out`, `err` |
##
## A failure of the file system: kind `Environment` (`cannot copy <from> to <dir>`, `cannot write <path>`, `cannot read <path>`): no test (question Q7). Exit codes: R-EC2.
PatchFlow :: [].{

	run! : Fx, Args => I32
	run! = |_fx, _args| crash "todo: slice 042"
}
