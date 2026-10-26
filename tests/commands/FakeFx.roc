import pf.Path
import lib.Fx
import lib.Lock
import FakeBase
import FakeDb
import FakeFiles
import FakeJobs

## The fake `Fx` of L2 (TESTING.md 2.4). It answers from files in the case work dir `<w>/fx/`,
## reads and writes real files in `<w>/project` and `<w>/home`, and appends each call to
## `<w>/out/calls.log`. Stdout and stderr go to `<w>/out/stdout` and `<w>/out/stderr`.
##
## | File in `<w>/fx/` | Gives | Default |
## | --- | --- | --- |
## | `args` | One argument for each line | no arguments |
## | `cwd` | Slice 041: the sub directory of `project/` that `cwd!` gives (one word, no `/` at the start) | `project/` |
## | `env` | `NAME=value`, one for each line | no variables |
## | `tty` | The lines `stdin=true`, `stderr=true` | both false |
## | `clock` | Seconds since the epoch | 1792065600 |
## | `answers` | The reply of the n-th `ask!`, one for each line. An empty line is the reply Enter. | end of input |
## | `random` | The number of `random!` | 81985529216486895 (`0123456789abcdef` as a temp name) |
## | `programs` | The names of the programs that are on `PATH`, one for each line | none |
## | `rename` | `exists <suffix>`, one for each line: a `rename!` whose target ends with `<suffix>` gives `Exists` and moves nothing (the loser of a race, R-FE3) | all renames work |
## | `mtimes` | `<path suffix> <seconds>`, one for each line: `list_dirs!` gives this time for an entry whose path ends with the suffix. `tree_info!` (slice 028b) gives it for a file, or for an empty directory, whose path ends with the suffix | the real modification time |
## | `jobs` | The answers of `spawn_all!`, see below | each job exits with 99 |
## | `http/` | The answers of `http_get!`, see below | every URL answers 404 |
## | `platform` | One row for each call of `platform!` (the n-th call gets the n-th row, the last row stays): the words `os=<linux, macos, windows or a name>` and `arch=<x64, arm64 or a name>` (slice 021). Slice 050c: `windows!` reads the row that the next `platform!` call gets (it counts no call, and the call is not in `calls.log`), so the sweep at the start of a run sees the system of the run | `os=linux arch=x64` |
## | `probes` | The answers of `probes!`, see below | each probe passes |
## | `units` | Slice 031: the answers of the unit probes (a `check main.roc` in a dir under `/packages/`), one row for each line with 4 fields split by a TAB: `<hash>` or `<hash>:<compiler id>`, then `code`, `stdout`, `stderr` as in `probes`. A row with the compiler wins. A unit probe is not counted for the rows of `probes`. Its log lines are the same as for other probes. Slice 036b (F1): a unit probe in a package dir that is not in the fake tree is `NotStarted("NotFound")`, as in the real `Fx`: the package must be fetched before its probe. | each unit probe passes |
## | `probe-text` | Any content (slice 007): the log of a `check` probe in a temp copy (a dir with `/talon/tmp/` in its path) has the lines that show the copy, see below | no such lines |
## | `hooks` | A concurrent edit of a file (slice 007), see below | none |
## | `path-roc` | The answer of `path_roc!` (slice 022b), see below | no `roc` file on `PATH` and an unknown running `tln` |
## | `program` | The program name of the process (slice 023, R-HF9): one word. The call `program_name!` is not in `calls.log` (each run calls it first). | `tln` |
## | `exec` | The answers of `exec!` (slice 023), `exec_in!` (slice 057) and `spawn_detached!` (slice 051), see below | each child exits with 0, and a detached child starts |
## | `hardlink` | `fail <suffix>`, one for each line: a `hard_link!` whose target ends with `<suffix>` gives `Other("cross-device link")` and makes nothing (the other file system, R-ST7: the copy fallback) (slice 027) | every hard link works |
## | `delete` | `denied <suffix>`, one for each line: a path of `delete!` that ends with `<suffix>` gives `Denied` and is not deleted (slice 029: `cache clean` exit 18) | every delete works |
## | `treeinfo` | `denied <suffix>`, one for each line: `tree_info!` gives `Err(Denied)` for a path that ends with `<suffix>` (an item that cannot be measured, slice 029) | every path is measured |
## | `db` | Errors of `db_query!` and `db_write!` (slice 030), see `FakeDb.roc`: one rule for each line, `<n>: busy`, `<n>: failed <text>` or `<n>: version <k>` | every call works |
## | `locks` | `busy <name>` or `busy <name> creates:<path>`, one for each line: a lock whose item path ends with `/<name>` is held by another process. `lock!` with `NoWait` gives `Busy`. With `Wait` it gives `Held` (the other process lets go). With `creates:<path>` the fake makes that directory first (`{w}` is the case dir): the other process finished its work (slice 021, R-CC4 step 4). | no lock is held by another process |
##
## `http/` (slice 003): a route is the file `http/<host>/<path>` or, with a query, `http/<host>/<path>?<query>` (the query file first). The body is the
## file (slice 046: when the route is a directory, the file `<dir>/@`, for a URL that is also the parent of other routes). `<file>.meta` has the lines `status <n>`, `header <Name>: <value>`, `error timeout` and `error failed <text>` (a transport error). A route that has a
## header `ETag` answers 304 with no body to a request with the same `If-None-Match`. No file: status 404 and the body `{"message":"Not Found"}`.
## The log has the line `http_get <url>` and then one line `  <Name>: <value>` for each header of the request, in order.
##
## `jobs` (slice 003): one rule for each line, with 5 fields split by a TAB: `needle`, `code`, `stdout`, `stderr_last`, `creates`. The first rule whose
## `needle` is in the arguments of the job (joined by one space) answers. `code` is `<n>` (exit), `signal:<n>`, or `notstarted:<text>`. `stdout` and
## `stderr_last` are texts (`-` for none). `creates` is a list split by `;`: `file:<path>` (a file with the text `fake`) or `dir:<path>` (a
## directory). In a path, `{cwd}` is the working directory of the job and `{w}` is the case work dir. Slice 021: `{out}` is the argument after `--output` (the file of a `curl` job) and
## `{dir}` is the argument after `-C` (the dir of a `tar` job), so one rule serves each download and each extract. Slice 074: a `needle` that starts with `@<n>|` (`@2|gh auth status`) is for the n-th run of the case only (the runs are counted by the lines `args` of `calls.log`), so a case can answer one job in another way in each run. Lines that start with `#` are comments.
## Slice 010: `copy:<dest>=<source>` is a file with the text of the file `<source>` (a package whose `main.roc` has a real header, for the closure walk).
## The log has `spawn_all limit=<n>` and then one line `  job <cwd> <arguments>` for each job (`-` is `Inherit`).
##
## `probes` (slice 006): one row for each probe, in the order in which the probes are called (the n-th probe of the case gets the n-th row), with 3 fields split by a TAB: `code`,
## `stdout`, `stderr`. `code` is `<n>` (exit), `signal:<n>`, `timeout` or `notstarted:<text>`. `stdout` and `stderr` are the names of files, relative to `fx/` (`-` for none): a case
## uses the real outputs of `tests/fixtures/check/out/` with `../fixtures/check/out/<case>.stdout` (the runner links `fixtures/` into the work dir). Lines that start with `#` are comments.
## Slice 046: a row can have a 4th field, a list split by `;` of the items that the probe makes: `file:<path>` (a file with the text `fake`) or `dir:<path>`; `{w}` is the case dir and `{out}` is the value of the argument `--output=` of the probe (the binary of a tool build). A probe with no row passes: exit 0 and the text `No errors found in 0ms for <file>` for `check`, `0 errors and 0 warnings found in 0ms while successfully building:` and the
## output path for `build`. The log has `probes <n>` and then one line `  probe <dir> <compiler> <program> <arguments> timeout=<s>` for each probe (slice 023c: `program` is the file that runs, `compiler` is the id that the command holds).
## A probe with a non-empty `env` has one more line, `    env <NAME>=<value> <NAME>=<value> ...` (4 spaces, the variables in the order of the spec, joined by one space), before the lines of `probe-text`. The fake runs nothing.
##
## `sha256_file!` (slice 021): the real sha256 of the bytes of the file, as `Crypto.SHA256` gives it. A file that does not exist is `NotFound`. The log line is `sha256_file <path>`.
## `platform!` (slice 021): see the table. The log line is `platform`. `windows!` (slice 050c, R-ST10): see the table. No log line (each start of `tln` calls it first, as `program_name!`), so a start on Linux or macOS has the same `calls.log` as before the slice.
##
## `path-roc` (slice 022b, R-SO9): one row for each file, with 4 words split by a space: `exe` or `file`, the path, the size and the mtime. The fake gives these numbers as they are and never looks at the file. `exe` is the running `tln` (no `exe` row: `Err(Unknown)`). `file` is a `roc` file on `PATH`, in the order of the rows. `{w}` is the case work dir. Lines that start with `#` are comments.
## The bytes of a file that `sha256_file!` hashes are the real bytes of the path, so a case makes real files in `{w}` for a path that is hashed. The log line is `path_roc`.
##
## `exec` (slice 023, R-HF6, R-E1): one rule for each line, with 2 fields split by a TAB: `needle` and `code`. The first rule whose `needle` is in the arguments of the child (joined by one space) answers.
## `code` is `<n>` (the exit code, the real `Fx` gives `128 + <signal>` for a signal, so the case writes that number) or `notstarted:<text>`. Lines that start with `#` are comments.
## The log has `exec <arguments>` (the program and its arguments, joined by one space) and then one line `  env <NAME>=<value>` for each variable of `env`, in the order of the call. The fake runs nothing.
## `exec_in!` (slice 057, R-RUN5, R-RUN8, R-RUN9): the same rules, the log line is `exec_in <cwd> <arguments>` (the working directory first) and then the same `  env` lines.
## `spawn_detached!` (slice 051, R-RM5): the same rules and `  env` lines, the log line is `spawn_detached <arguments>`. Only the code `notstarted:<text>` matters (the child could not start); any other code is a started child. The fake runs nothing.
##
## `{w}` (slice 007): in `args` and in `env`, the text `{w}` is the case work dir (so `HOME={w}/home` is a path of the case).
##
## `probe-text` (slice 007, R-LD4, R-CC2, Q4 of slice 006): the file `fx/probe-text` makes the fake describe the temp copy of each `check` probe in a dir with `/talon/tmp/` in it. After the line
## `  probe ...` the log gets `  copy-entries <names>` (the names in the dir, sorted, a directory with `/` at the end: a `.git` that was copied would show) and one line `  | <line>` for each line of
## the project file in the copy, from its first line to the first line that starts with `}` (the header). A test sees the candidate header text and its absolute path entries.
## Slice 006b (Q1): each `.roc` file of the copy (the top dir and its subdirs, not the project file), sorted by path, adds one line `  ~ <path>: <line>` for each of its lines that starts with `import "`.
##
## `hooks` (slice 007, R-CC7): one rule for each line, with 5 fields split by a TAB: `after-probes`, `<n>`, `<file>`, `<from>`, `<to>`. After the n-th `probes` call of the case (all runs of an entry count) the fake
## replaces the first `<from>` in the file `<w>/<file>` with `<to>` (`\n` in a field is a line end). It is a change that another process makes while the command probes. The log has `hook <file>`.
##
## `copy_tree!` (slice 006): copies the real files, skips the names of `skip` at any depth, makes the parent dirs of the target. `Exists` when the target is there, `NotFound`
## when the source is not. The log line is `copy_tree <from> <to>`.
##
## `copy_file!` (slice 024b, R-LK2): copies the real bytes of the file, and makes the parent dirs of the target. `Exists` when the target is there, `NotFound` when the source is not (a source that is a directory is `Other("is a directory")`). The fake keeps
## no permission bits. The log line is `copy_file <from> <to>`.
##
## `hard_link!` (slice 027, R-ST7): a real hard link (`Path.hard_link!`), so the case dir shows the same file twice. `Exists` when the target is there, `NotFound` when the source is not or the parent dir of the target is missing (the fake makes no parent dir), `Other("is a directory")` for a directory. A target that matches
## a `fail` line of `fx/hardlink` gives `Other("cross-device link")`. The log line is `hard_link <from> <to>`.
##
## `tree_info!` (slice 028b, R-GC3, R-GC4, R-GC11): walks the real files of each path, as the doc of `Fx.tree_info!` says: `newest` is the newest time of a file (the real time, or the line of `mtimes` whose suffix ends the path of the file),
## `size` is the sum of the real sizes of the files. A directory with no file has its own time and the size 0. A link is not followed and not counted. A path that is missing is `NotFound`. The log line is `tree_info <paths>`.
##
## Files and directories: `list_dirs!` and `canonical!` read the real files in the case dir. `canonical!` gives the path
## as it is when the path exists (no symbolic links in a case). `write_atomic!` creates the missing parent directories (a
## decision of slice 002, the real `Fx` does the same). `delete!` removes real files and directories (a path that matches a line of `fx/delete` is left, see the table).
##
## Locks (slice 002): the fake makes no lock directory. It logs each `lock!` as `lock <item> <wait|nowait>: <held|busy>`
## and each `unlock!` as `unlock <item>`. An `ask!` while a lock is held (more `held` lines than `unlock` lines) adds the line
## `VIOLATION ask while a lock is held` to `calls.log` before the `ask` line (R-CC3 point 5). The expected `calls.log` of a
## case has no such line, so the case fails.
##
## Modules (slice 029b: the old file had 868 lines)
##
## | Module | Calls |
## | --- | --- |
## | `FakeFx` | The record, the table above, and the small calls: `args!`, `env_all!`, `cwd!`, `tty!`, `clock!`, `out!`, `err!`, `lock!`, `unlock!`, `programs!`, `random!`, `platform!`, `path_roc!`, `program_name!`, `ask!` |
## | `FakeFiles` | `read_files!`, `write_atomic!`, `list_dirs!`, `tree_info!`, `delete!`, `canonical!`, `rename!`, `make_dirs!`, `copy_tree!`, `copy_file!`, `hard_link!`, `sha256_file!` |
## | `FakeJobs` | `http_get!`, `spawn_all!`, `probes!`, `exec!`, `exec_in!`, `spawn_detached!` |
## | `FakeDb` | `db_query!`, `db_write!` (slice 030): the store is the text file `compat.tsv` next to the db path |
## | `FakeBase` | The call log, `read_or_empty!`, `append!`, the text lines, `write_with_parents!`, `create_item!` |
FakeFx :: [].{

	make : Str -> Fx
	make = |w| Fx.{
		args!: || {
			FakeBase.log!(w, "args")
			FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/args").replace_each("{w}", w))
		},
		env_all!: || {
			FakeBase.log!(w, "env_all")
			FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/env").replace_each("{w}", w)).map(split_env)
		},
		cwd!: || {
			FakeBase.log!(w, "cwd")
			sub = FakeBase.read_or_empty!("${w}/fx/cwd").trim()
			if sub == "" "${w}/project" else "${w}/project/${sub}"
		},
		tty!: || {
			FakeBase.log!(w, "tty")
			text = FakeBase.read_or_empty!("${w}/fx/tty")
			{ stdin: FakeBase.lines(text).contains("stdin=true"), stderr: FakeBase.lines(text).contains("stderr=true") }
		},
		clock!: || {
			FakeBase.log!(w, "clock")
			match U64.from_str(FakeBase.read_or_empty!("${w}/fx/clock").trim()) {
				Ok(n) => n
				Err(_) => 1792065600
			}
		},
		read_files!: |paths| FakeFiles.read_files!(w, paths),
		write_atomic!: |files| FakeFiles.write_atomic!(w, files),
		out!: |text| FakeBase.append!("${w}/out/stdout", text),
		err!: |text| FakeBase.append!("${w}/out/stderr", text),
		list_dirs!: |dirs| FakeFiles.list_dirs!(w, dirs),
		tree_info!: |paths| FakeFiles.tree_info!(w, paths),
		delete!: |paths| FakeFiles.delete!(w, paths),
		canonical!: |paths| FakeFiles.canonical!(w, paths),
		lock!: |item, mode| {
			busy_rows = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/locks")).keep_if(|l| l.starts_with("busy ")).map(|l| l.drop_prefix("busy ").split_on(" "))
			busy_names = busy_rows.map(|row| row.first() ?? "")
			other_holds = busy_names.any(|name| item.ends_with("/${name}"))
			text = match mode {
				Wait => "wait"
				NoWait => "nowait"
			}
			if other_holds and text == "nowait" {
				FakeBase.log!(w, "lock ${item} ${text}: busy")
				Busy
			} else {
				if other_holds {
					for row in busy_rows.keep_if(|r| item.ends_with("/${r.first() ?? ""}")) {
						for word in row.drop_first(1).keep_if(|x| x.starts_with("creates:")) {
							FakeBase.create_item!("dir:${word.drop_prefix("creates:").replace_each("{w}", w)}")
						}
					}
				}
				FakeBase.log!(w, "lock ${item} ${text}: held")
				Held(Lock.{ item, token: "fake" })
			}
		},
		unlock!: |lock| FakeBase.log!(w, "unlock ${lock.item}"),
		http_get!: |request| FakeJobs.http_get!(w, request),
		programs!: |names| {
			FakeBase.log!(w, "programs ${Str.join_with(names, " ")}")
			have = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/programs"))
			names.map(|name| have.contains(name))
		},
		spawn_all!: |batch| FakeJobs.spawn_all!(w, batch),
		rename!: |move| FakeFiles.rename!(w, move),
		make_dirs!: |dirs| FakeFiles.make_dirs!(w, dirs),
		random!: || {
			FakeBase.log!(w, "random")
			match U64.from_str(FakeBase.read_or_empty!("${w}/fx/random").trim()) {
				Ok(n) => n
				Err(_) => 81985529216486895
			}
		},
		probes!: |round| FakeJobs.probes!(w, round),
		copy_tree!: |move| FakeFiles.copy_tree!(w, move),
		copy_file!: |move| FakeFiles.copy_file!(w, move),
		hard_link!: |move| FakeFiles.hard_link!(w, move),
		db_query!: |open, query| FakeDb.query!(w, open, query),
		db_write!: |open, write| FakeDb.write!(w, open, write),
		platform!: || {
			asked = FakeBase.lines(FakeBase.read_or_empty!("${w}/out/calls.log")).keep_if(|l| l == "platform").len()
			FakeBase.log!(w, "platform")
			rows = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/platform"))
			row = match rows.get(asked) {
				Ok(r) => r
				Err(_) => rows.last() ?? ""
			}
			words = row.split_on(" ")
			value = |key| match words.find_first(|word| word.starts_with("${key}=")) {
				Ok(word) => word.drop_prefix("${key}=")
				Err(_) => ""
			}
			{
				os: match value("os") {
					"linux" | "" => Linux
					"macos" => Macos
					"windows" => Windows
					other => Other(other)
				},
				arch: match value("arch") {
					"x64" | "" => X64
					"arm64" => Arm64
					other => Other(other)
				},
			}
		},
		windows!: || {
			asked = FakeBase.lines(FakeBase.read_or_empty!("${w}/out/calls.log")).keep_if(|l| l == "platform").len()
			rows = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/platform"))
			row = match rows.get(asked) {
				Ok(r) => r
				Err(_) => rows.last() ?? ""
			}
			row.split_on(" ").contains("os=windows")
		},
		path_roc!: || {
			FakeBase.log!(w, "path_roc")
			rows = FakeBase.lines(FakeBase.read_or_empty!("${w}/fx/path-roc").replace_each("{w}", w)).keep_if(|l| !l.starts_with("#")).map(|l| l.split_on(" "))
			file_of = |words| match words {
				[_, path, size, mtime] => Ok({ path, size: U64.from_str(size) ?? 0, mtime: U64.from_str(mtime) ?? 0 })
				_ => Err(BadRow)
			}
			exes = rows.keep_if(|words| words.first() == Ok("exe")).keep_oks(file_of)
			{
				exe: match exes {
					[first, ..] => Ok(first)
					_ => Err(Unknown)
				},
				found: rows.keep_if(|words| words.first() == Ok("file")).keep_oks(file_of),
			}
		},
		program_name!: || {
			name = FakeBase.read_or_empty!("${w}/fx/program").trim()
			if name.is_empty() "tln" else name
		},
		exec!: |run| FakeJobs.exec!(w, run),
		exec_in!: |run| FakeJobs.exec_in!(w, run),
		spawn_detached!: |run| FakeJobs.spawn_detached!(w, run),
		sha256_file!: |path| FakeFiles.sha256_file!(w, path),
		ask!: |prompt| {
			asked = FakeBase.lines(FakeBase.read_or_empty!("${w}/out/calls.log")).keep_if(|l| l.starts_with("ask ")).len()
			log_lines = FakeBase.lines(FakeBase.read_or_empty!("${w}/out/calls.log"))
			held = log_lines.keep_if(|l| l.starts_with("lock ") and l.ends_with(": held")).len()
			released = log_lines.keep_if(|l| l.starts_with("unlock ")).len()
			if held > released FakeBase.log!(w, "VIOLATION ask while a lock is held")
			FakeBase.log!(w, "ask ${Str.inspect(prompt)}")
			match FakeBase.keep_empty(FakeBase.read_or_empty!("${w}/fx/answers")).get(asked) {
				Ok(reply) => Ok(reply)
				Err(_) => Err(EndOfInput)
			}
		},
	}
}

split_env : Str -> (Str, Str)
split_env = |line| match line.split_on("=") {
	[name, .. as rest] => (name, Str.join_with(rest, "="))
	[] => ("", "")
}
