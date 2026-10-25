import Fail
import Text

## Which `talon.toml` holds the script (slice 057, CLI 1: R-RUN11, R-RUN12, R-PD2, R-PD3, R-PD5, R-PD6, R-PD9, Design 4.4 R-WS5, user answers NC2, NC4, NC5 of the draft D-TS). Part A (pure, TESTING.md 2.2). `RunFlow` collects the facts with `Project.scan!` and calls `find`.
##
## The walk goes up from the current directory (R-PD2), nearest directory first. For each directory that has a `talon.toml`, the file is one of 3 kinds:
##
## | Kind | The file | Rule |
## | --- | --- | --- |
## | `Root` | has a `[workspace]` table: the workspace root (R-PD3), the first one on the walk | R-WS5 |
## | `Member` | is a file of a workspace (a member file is in its directory, or below it up to the next directory with a `talon.toml`) and has no `[workspace]` table | R-WS5, NC4 |
## | `Standalone` | any other `talon.toml`: with no workspace, or inside a workspace directory with no member file of its own (the file of a standalone project, R-PD5, R-PD6) | NC2, NC4 |
##
## The walk stops after a `Root` file and after a `Standalone` file: the scripts of a file above them have no effect (NC5, R-RUN12). A `Member` file that has no such script gives the walk to the directory above it. The first file that has the name holds the script.
## With no name (R-RUN11, answer Q1 of the review of slice 057) the first file on the walk that has at least one script holds the list.
RunFind :: [].{

	## One directory of the walk: its path, and its `talon.toml` as `RunFlow` read it: `names` are the script names of its `[scripts]` table, `bad` is the first failure of the form of that table (`Ok(<path>:<line>: <message>>)`, R-RUN1).
	Dir : { dir : Str, toml : Try({ names : List(Str), bad : Try(Str, [None]) }, [None]) }

	## What the walk and the workspace tell: `walk` (nearest first), `root` (the workspace root directory of the walk, `Err(NoWorkspace)` for none), `members` (the absolute member files of the root, sorted), `probes` (the `talon.toml` files that a `Need` asked about: the path and whether it exists).
	Facts : { name : Try(Str, [None]), walk : List(RunFind.Dir), root : Try(Str, [NoWorkspace]), members : List(Str), probes : List({ path : Str, exists : Bool }) }

	## The file that holds the script: its directory, its kind, the directory whose `talon.toml` has the `[tools]` table (R-RUN3 point 2, OP4: the workspace root for `Root` and `Member`, the directory itself for `Standalone`), the member files of its node
	## (R-PD9: all members for `Root`, the members whose node it is for `Member`, none for `Standalone`), and the directory where the walk stopped (R-RUN8).
	Found : { dir : Str, kind : [Root, Member, Standalone], tools_dir : Str, members : List(Str), stop : Str }

	## R-RUN12: the choice. `Err(Need(<paths>))`: the caller must tell, for each path (a `talon.toml` that may exist), whether it exists (`probes`), and call again. A path is asked only when a member file is below a `talon.toml` directory of the walk and the kind of that file depends on the
	## directories between (NC4). `Err(Fail)`: kind `Usage` (exit 2) when no file has the name, with the files that the walk checked; kind `Input` (exit 19) when a file that the walk examined has a `[scripts]` table with a bad form (R-RUN1). The text is a proposal (TW24):
	##
	## | Case | Message |
	## | --- | --- |
	## | A name that no file has | `no script '<name>' in the talon.toml files that the walk checked: <file>, <file>.` (nearest first, the files that were examined; the text `none` for no file: `no talon.toml found. Checked: <dir>, <dir>.` lists the directories of the walk) |
	## | No name, and no file has a script | `no script in the talon.toml files that the walk checked: <file>, <file>.` or `no talon.toml found. Checked: <dir>, <dir>.` |
	find : RunFind.Facts -> Try(RunFind.Found, [Need(List(Str)), Stop(Fail)])
	find = |_facts| crash "todo: slice 057"
}
