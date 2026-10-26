import Args
import Common
import Fail
import Fetch
import Fx
import Install
import Known
import Locked
import Net
import Out
import PathCmd
import Roots

## The command `tln path <alias>` (slice 055, R-CM25, R-PTH1 to R-PTH5, R-PD14, R-PD9): in direct style over `Fx` (TESTING.md 2.2, part C). `PathCmd` has the decisions. `Run.run!` calls it for the command `path`.
##
## The calls, in order (the L2 case `path/pt1-entry` fixes them):
##
## | # | Step | Rule |
## | --- | --- | --- |
## | 1 | `PathCmd.read(args)`. A failure is printed as `Common.failed!` does (no `Fx` call). | R-PTH1, R-EC2 |
## | 2 | `Install.begin!` (environment, time, project) | R-PD14, R-PD1 to R-PD8 |
## | 3 | A workspace root with no current member (answer Q1 of the review): `Install.check_member(Bool.True, project)`, as `add` and `remove`: exit 2 that lists the members. L2 `path/pt1-entry` run 9. | R-PD5, R-WS12 |
## | 4 | `canonical!` and `Known.record!` of the member files: the run records the project, also when it fails later | R-PTH4, R-PD9 |
## | 5 | One `read_files!` of the project file (`Install.begin!` read it before: the log has 2 reads, decision D1), `Locked.read`, `PathCmd.pick`. No other read: a file in the directory of the entry is never read. | R-PTH1, R-PTH3, R-PTH5 |
## | 6 | A release entry: `Fetch.packages!` for its URL (nothing is resolved, no project file is written). A failure is the failure of the run (`--offline` and a missing directory: exit 15). A path entry: no fetch. | R-PTH2, R-FE2, R-FE3, R-FE7 |
## | 7 | The output | R-PTH1, R-J1 to R-J6 |
##
## The output: stdout is the line of `PathCmd.text`, nothing else (also with `--quiet`: it is the answer, R-FL4). With `--json` stdout is the envelope `Out.json_ok({ command: args.typed, data: PathCmd.data(entry) })`. A failure is printed with `Common.failed!`.
PathFlow :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match PathCmd.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(want) => match flow!(fx, args, want.alias) {
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(entry) => {
				if args.json {
					fx.out!(Out.json_ok({ command: args.typed, data: PathCmd.data(entry) }))
				} else {
					fx.out!(PathCmd.text(entry))
				}
				0
			}
		}
	}
}

# Steps 2 to 6: the project, the record, the entry, and the fetch of a release entry.
flow! : Fx, Args, Str => Try(PathCmd.Entry, Fail)
flow! = |fx, args, alias| {
	start = Install.begin!(fx, args)?
	Install.check_member(Bool.True, start.project)?
	Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
	file = start.project.file ?? ""
	rows = rows_of!(fx, file)?
	entry = PathCmd.pick({ alias, rows, file, roots: start.roots })?
	match entry.source {
		Dir => {}
		Release(url) => fetch!(fx, { roots: start.roots, net: start.net, offline: args.offline, url })?
	}
	Ok(entry)
}

# Step 5: one read of the project file, and its header rows.
rows_of! : Fx, Str => Try(List(Locked.Row), Fail)
rows_of! = |fx, file| match fx.read_files!([file]) {
	[Ok(text)] => Ok(Locked.read({ path: file, text })?.rows)
	_ => Err(Fail.new(Environment, "cannot read ${file}"))
}

# Step 6, R-PTH2: the release is fetched when its directory is missing. The result is not read.
fetch! : Fx, { roots : Roots, net : Net.Settings, offline : Bool, url : Str } => Try({}, Fail)
fetch! = |fx, facts| match Fetch.packages!(fx, { roots: facts.roots, urls: [facts.url], offline: facts.offline, unbundler: Choose({ selected: "" }), downloader: facts.net.downloader }) {
	[Ok(_)] => Ok({})
	[Err(fail)] => Err(fail)
	_ => Err(Fail.new(Internal, "the fetch of ${facts.url} gave no answer"))
}
