import Lock
import Probe

## The effect record (TESTING.md 2.3). Command code gets one `Fx`.
## The real `Fx` is `cli/RealFx.roc`. The fake `Fx` is `tests/commands/FakeFx.roc`.
## An `Fx` call is coarse (TW3) and has no Talon logic (TW4).
## Slice 001 has the first 10 calls. Slice 002 adds `list_dirs!`, `delete!`, `canonical!`, `lock!`, `unlock!` and
## the helper `with_lock!`. Slice 003 adds `http_get!`, `programs!`, `spawn_all!`, `rename!`, `make_dirs!` and `random!`.
## Slice 006 adds `probes!` and `copy_tree!`. Later slices add the rest.
##
## | Call | Does |
## | --- | --- |
## | `args!` | The arguments after the program name |
## | `env_all!` | All environment variables, as (name, value) pairs |
## | `cwd!` | The current directory, absolute |
## | `tty!` | Which of stdin and stderr are a terminal (R-HF1) |
## | `clock!` | The real time, in seconds since the Unix epoch (UTC). `TALON_NOW` is not applied here. |
## | `read_files!` | Reads each path as UTF-8 text, in the order of the list |
## | `write_atomic!` | Writes each file with a temp file and a rename (R-CC1). It stops at the first error. |
## | `out!`, `err!` | Write text to stdout or stderr with no added newline |
## | `ask!` | Writes a prompt to stderr, then reads one line from stdin |
## | `list_dirs!` | Lists each directory: the name, the kind and the modification time of each entry (slice 002) |
## | `delete!` | Deletes each file or directory (a directory with its content). A path that does not exist is not an error. |
## | `canonical!` | The canonical absolute path of each path (symbolic links resolved). R-PD9. |
## | `lock!`, `unlock!` | The lock interface of CLI 7.4 (R-CC3). The real `Fx` makes the lock directory (R-CC12). |
## | `with_lock!` | Not a field. Takes a lock, runs a body, and always releases the lock (R-CC3). |
## | `http_get!` | One small HTTP GET with a timeout of 20 s (CLI 7.5, R-DA1, R-CC12). Not for archives. |
## | `programs!` | Whether each program is on `PATH` |
## | `spawn_all!` | Runs child processes, up to `limit` at the same time, polls them and gives each result (CLI 7.5, R-DA5, R-HF4) |
## | `rename!` | Renames a file or a directory (R-FE3) |
## | `make_dirs!` | Makes each directory and its missing parents |
## | `random!` | A random number (TW2: the random part of a temp name, R-CC1) |
## | `probes!` | Runs probes (`roc check`, `roc build`) as child processes with a timeout and gives each result (slice 006, TESTING.md 2.3) |
## | `copy_tree!` | Copies a directory and its content to a new directory (slice 006, R-CC2: the temp copy of an app) |
Fx := {
	args! : () => List(Str),
	env_all! : () => List((Str, Str)),
	cwd! : () => Str,
	tty! : () => { stdin : Bool, stderr : Bool },
	clock! : () => U64,
	read_files! : List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)])),
	write_atomic! : List({ path : Str, content : Str }) => Try({}, { path : Str, err : [NotFound, Denied, Other(Str)] }),
	out! : Str => {},
	err! : Str => {},
	ask! : Str => Try(Str, [EndOfInput]),
	list_dirs! : List(Str) => List(Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)])),
	delete! : List(Str) => List(Try({}, [NotFound, Denied, Other(Str)])),
	canonical! : List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)])),
	lock! : Str, [Wait, NoWait] => [Held(Lock), Busy],
	unlock! : Lock => {},
	http_get! : { url : Str, headers : List((Str, Str)) } => Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)]),
	programs! : List(Str) => List(Bool),
	spawn_all! : { jobs : List({ argv : List(Str), cwd : Try(Str, [Inherit]) }), limit : U64 } => List({ ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str }),
	rename! : { from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)]),
	make_dirs! : List(Str) => Try({}, [Denied, Other(Str)]),
	random! : () => U64,
	probes! : List(Probe.Spec) => List(Probe.Output),
	copy_tree! : { from : Str, to : Str, skip : List(Str) } => Try({}, [NotFound, Exists, Denied, Other(Str)]),
}.{
	args! : Fx => List(Str)
	args! = |Fx.{ args!: f, .. }| f()

	env_all! : Fx => List((Str, Str))
	env_all! = |Fx.{ env_all!: f, .. }| f()

	cwd! : Fx => Str
	cwd! = |Fx.{ cwd!: f, .. }| f()

	tty! : Fx => { stdin : Bool, stderr : Bool }
	tty! = |Fx.{ tty!: f, .. }| f()

	clock! : Fx => U64
	clock! = |Fx.{ clock!: f, .. }| f()

	read_files! : Fx, List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)]))
	read_files! = |Fx.{ read_files!: f, .. }, paths| f(paths)

	write_atomic! : Fx, List({ path : Str, content : Str }) => Try({}, { path : Str, err : [NotFound, Denied, Other(Str)] })
	write_atomic! = |Fx.{ write_atomic!: f, .. }, files| f(files)

	out! : Fx, Str => {}
	out! = |Fx.{ out!: f, .. }, text| f(text)

	err! : Fx, Str => {}
	err! = |Fx.{ err!: f, .. }, text| f(text)

	ask! : Fx, Str => Try(Str, [EndOfInput])
	ask! = |Fx.{ ask!: f, .. }, prompt| f(prompt)

	## The directories in the list, in the order of the list. Each gives its entries, with no order (the caller
	## sorts: TW2). `.` and `..` are not entries. An entry that is a link to a directory has `is_dir` true.
	## `mtime` is the modification time in seconds since the epoch. A missing directory is `NotFound`.
	list_dirs! : Fx, List(Str) => List(Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)]))
	list_dirs! = |Fx.{ list_dirs!: f, .. }, dirs| f(dirs)

	delete! : Fx, List(Str) => List(Try({}, [NotFound, Denied, Other(Str)]))
	delete! = |Fx.{ delete!: f, .. }, paths| f(paths)

	canonical! : Fx, List(Str) => List(Try(Str, [NotFound, Denied, Other(Str)]))
	canonical! = |Fx.{ canonical!: f, .. }, paths| f(paths)

	## `Held(lock)` when the caller has the lock. `Busy` when `NoWait` finds the lock held by a live process.
	## With `Wait` the call gives only `Held`. The rules are R-CC3 and R-CC12 (the real `Fx` has the code).
	lock! : Fx, Str, [Wait, NoWait] => [Held(Lock), Busy]
	lock! = |Fx.{ lock!: f, .. }, item, mode| f(item, mode)

	unlock! : Fx, Lock => {}
	unlock! = |Fx.{ unlock!: f, .. }, lock| f(lock)

	## One GET request (the URL is `http://` or `https://`). The answer gives the status, the headers (names as the server sent them) and the body as
	## text. A status of 400 or more is an answer, not an error. `Timeout`: no answer in 20 s (R-CC12: a step that is not a wait ends in under 25 s).
	## `Failed(text)`: no answer for another reason (`network error`, `bad body`, `invalid URL`, or the text of the error).
	http_get! : Fx, { url : Str, headers : List((Str, Str)) } => Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])
	http_get! = |Fx.{ http_get!: f, .. }, request| f(request)

	## Whether each program is on `PATH`, in the order of the list.
	programs! : Fx, List(Str) => List(Bool)
	programs! = |Fx.{ programs!: f, .. }, names| f(names)

	## Starts the child processes of `jobs` in the order of the list, with at most `limit` running at the same time, and polls them with `try_wait!`
	## (R-DA5, R-HF3: the poll loop also writes the heartbeat of the locks that the process holds, R-CC12). `argv` is the program and its arguments, `cwd`
	## is its working directory (`Inherit`: the one of the process). The stdin of a child is closed. Each result is in the order of the jobs: `ended`,
	## the stdout as text, and the last line of the stderr that is not empty (the empty text when there is none). `NotStarted(text)` is a child that
	## could not start (the program is not on `PATH`, or `cwd` is missing).
	spawn_all! : Fx, { jobs : List({ argv : List(Str), cwd : Try(Str, [Inherit]) }), limit : U64 } => List({ ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str })
	spawn_all! = |Fx.{ spawn_all!: f, .. }, batch| f(batch)

	## `rename` of a file or a directory. `Exists`: the target is a directory that is not empty, or it exists and the system will not replace it (R-FE3: the
	## loser of a race gets this). `NotFound`: the source is missing.
	rename! : Fx, { from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])
	rename! = |Fx.{ rename!: f, .. }, move| f(move)

	## Makes each directory and its missing parents. A directory that exists is not an error.
	make_dirs! : Fx, List(Str) => Try({}, [Denied, Other(Str)])
	make_dirs! = |Fx.{ make_dirs!: f, .. }, dirs| f(dirs)

	## A random number (TW2). The real `Fx` draws it from the system.
	random! : Fx => U64
	random! = |Fx.{ random!: f, .. }| f()

	## Runs each probe (slice 006, R-LD1, R-PP3, R-PP5, R-RC3, R-P1): the program `roc` on `PATH` with `args`, in `dir`, with the stdin closed. It starts the probes of the list
	## at the same time (P0 has 2 at most: the pool of slots, R-PP6, is P1) and gives the results in the order of the list. The real `Fx` kills a child that has not ended in
	## `timeout` seconds and gives `TimedOut` (R-RC3). A child that a signal ended gives `Signaled(<signal number>)`, a child that cannot start `NotStarted(text)`. `stdout` and `stderr`
	## are the whole output as text (invalid UTF-8 is replaced). `compiler` is the id that the command holds: the real `Fx` of P0 does not look at it (R-PH6).
	## The real `Fx` has no Talon logic (TW4): it never reads the output.
	probes! : Fx, List(Probe.Spec) => List(Probe.Output)
	probes! = |Fx.{ probes!: f, .. }, specs| f(specs)

	## Copies the directory `from` and its content to `to` (slice 006, R-CC2: the temp copy of an app, `talon/tmp/<16hex>/`). It makes the parent dirs of `to`. A
	## file or a directory whose name is in `skip` is not copied (at any depth). `Exists`: `to` exists. `NotFound`: `from` is missing. A link is copied as the
	## file or the directory that it points to. The times of the files are not kept.
	copy_tree! : Fx, { from : Str, to : Str, skip : List(Str) } => Try({}, [NotFound, Exists, Denied, Other(Str)])
	copy_tree! = |Fx.{ copy_tree!: f, .. }, move| f(move)

	## R-CC3 and R-CC5: command code takes a lock only with this function. The steps:
	##
	## | Mode | Steps |
	## | --- | --- |
	## | `NoWait` | `lock!(item, NoWait)`. `Busy` gives `Err(Busy)`, and `body!` does not run. |
	## | `Wait` | `lock!(item, NoWait)`. On `Busy`: print `Lock.waiting_line(item)` to stderr once, then `lock!(item, Wait)`. |
	##
	## With the lock, run `body!`, then `unlock!`. `unlock!` runs also when `body!` gives an `Err`. The result is the
	## result of `body!`, or `Err(Busy)`.
	with_lock! : Fx, Str, [Wait, NoWait], (() => Try(ok, err)) => Try(ok, [Busy, Failed(err)])
	with_lock! = |fx, item, mode, body!| {
		taken = match mode {
			NoWait => fx.lock!(item, NoWait)
			Wait => match fx.lock!(item, NoWait) {
				Held(lock) => Held(lock)
				Busy => {
					fx.err!(Lock.waiting_line(item))
					fx.lock!(item, Wait)
				}
			}
		}
		match taken {
			Busy => Err(Busy)
			Held(lock) => {
				result = body!()
				fx.unlock!(lock)
				result.map_err(|e| Failed(e))
			}
		}
	}
}
