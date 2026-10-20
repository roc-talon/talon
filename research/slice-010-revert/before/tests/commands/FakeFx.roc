import pf.Path
import lib.Fx
import lib.Lock
import lib.Probe

## The fake `Fx` of L2 (TESTING.md 2.4). It answers from files in the case work dir `<w>/fx/`,
## reads and writes real files in `<w>/project` and `<w>/home`, and appends each call to
## `<w>/out/calls.log`. Stdout and stderr go to `<w>/out/stdout` and `<w>/out/stderr`.
##
## | File in `<w>/fx/` | Gives | Default |
## | --- | --- | --- |
## | `args` | One argument for each line | no arguments |
## | `env` | `NAME=value`, one for each line | no variables |
## | `tty` | The lines `stdin=true`, `stderr=true` | both false |
## | `clock` | Seconds since the epoch | 1792065600 |
## | `answers` | The reply of the n-th `ask!`, one for each line. An empty line is the reply Enter. | end of input |
## | `random` | The number of `random!` | 81985529216486895 (`0123456789abcdef` as a temp name) |
## | `programs` | The names of the programs that are on `PATH`, one for each line | none |
## | `rename` | `exists <suffix>`, one for each line: a `rename!` whose target ends with `<suffix>` gives `Exists` and moves nothing (the loser of a race, R-FE3) | all renames work |
## | `mtimes` | `<path suffix> <seconds>`, one for each line: `list_dirs!` gives this time for an entry whose path ends with the suffix | the real modification time |
## | `jobs` | The answers of `spawn_all!`, see below | each job exits with 99 |
## | `http/` | The answers of `http_get!`, see below | every URL answers 404 |
## | `probes` | The answers of `probes!`, see below | each probe passes |
## | `probe-text` | Any content (slice 007): the log of a `check` probe in a temp copy (a dir with `/talon/tmp/` in its path) has the lines that show the copy, see below | no such lines |
## | `hooks` | A concurrent edit of a file (slice 007), see below | none |
## | `locks` | `busy <name>`, one for each line: a lock whose item path ends with `/<name>` is held by another process. `lock!` with `NoWait` gives `Busy`. With `Wait` it gives `Held` (the other process lets go). | no lock is held by another process |
##
## `http/` (slice 003): a route is the file `http/<host>/<path>` or, with a query, `http/<host>/<path>?<query>` (the query file first). The body is the
## file. `<file>.meta` has the lines `status <n>`, `header <Name>: <value>`, `error timeout` and `error failed <text>` (a transport error). A route that has a
## header `ETag` answers 304 with no body to a request with the same `If-None-Match`. No file: status 404 and the body `{"message":"Not Found"}`.
## The log has the line `http_get <url>` and then one line `  <Name>: <value>` for each header of the request, in order.
##
## `jobs` (slice 003): one rule for each line, with 5 fields split by a TAB: `needle`, `code`, `stdout`, `stderr_last`, `creates`. The first rule whose
## `needle` is in the arguments of the job (joined by one space) answers. `code` is `<n>` (exit), `signal:<n>`, or `notstarted:<text>`. `stdout` and
## `stderr_last` are texts (`-` for none). `creates` is a list split by `;`: `file:<path>` (a file with the text `fake`) or `dir:<path>` (a
## directory). In a path, `{cwd}` is the working directory of the job and `{w}` is the case work dir. Lines that start with `#` are comments.
## The log has `spawn_all limit=<n>` and then one line `  job <cwd> <arguments>` for each job (`-` is `Inherit`).
##
## `probes` (slice 006): one row for each probe, in the order in which the probes are called (the n-th probe of the case gets the n-th row), with 3 fields split by a TAB: `code`,
## `stdout`, `stderr`. `code` is `<n>` (exit), `signal:<n>`, `timeout` or `notstarted:<text>`. `stdout` and `stderr` are the names of files, relative to `fx/` (`-` for none): a case
## uses the real outputs of `tests/fixtures/check/out/` with `../fixtures/check/out/<case>.stdout` (the runner links `fixtures/` into the work dir). Lines that start with `#` are comments.
## A probe with no row passes: exit 0 and the text `No errors found in 0ms for <file>` for `check`, `0 errors and 0 warnings found in 0ms while successfully building:` and the
## output path for `build`. The log has `probes <n>` and then one line `  probe <dir> <compiler> <arguments> timeout=<s>` for each probe.
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
## Files and directories: `list_dirs!` and `canonical!` read the real files in the case dir. `canonical!` gives the path
## as it is when the path exists (no symbolic links in a case). `write_atomic!` creates the missing parent directories (a
## decision of slice 002, the real `Fx` does the same). `delete!` removes real files and directories.
##
## Locks (slice 002): the fake makes no lock directory. It logs each `lock!` as `lock <item> <wait|nowait>: <held|busy>`
## and each `unlock!` as `unlock <item>`. An `ask!` while a lock is held (more `held` lines than `unlock` lines) adds the line
## `VIOLATION ask while a lock is held` to `calls.log` before the `ask` line (R-CC3 point 5). The expected `calls.log` of a
## case has no such line, so the case fails.
FakeFx :: [].{

	make : Str -> Fx
	make = |w| Fx.{
		args!: || {
			log!(w, "args")
			lines(read_or_empty!("${w}/fx/args").replace_each("{w}", w))
		},
		env_all!: || {
			log!(w, "env_all")
			lines(read_or_empty!("${w}/fx/env").replace_each("{w}", w)).map(split_env)
		},
		cwd!: || {
			log!(w, "cwd")
			"${w}/project"
		},
		tty!: || {
			log!(w, "tty")
			text = read_or_empty!("${w}/fx/tty")
			{ stdin: lines(text).contains("stdin=true"), stderr: lines(text).contains("stderr=true") }
		},
		clock!: || {
			log!(w, "clock")
			match U64.from_str(read_or_empty!("${w}/fx/clock").trim()) {
				Ok(n) => n
				Err(_) => 1792065600
			}
		},
		read_files!: |paths| {
			log!(w, "read_files ${Str.join_with(paths, " ")}")
			var $results = []
			for p in paths {
				one = match Path.read_utf8!(Path.utf8(p)) {
					Ok(text) => Ok(text)
					Err(PathErr(NotFound, _)) => Err(NotFound)
					Err(PathErr(PermissionDenied, _)) => Err(Denied)
					Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
				}
				$results = $results.append(one)
			}
			$results
		},
		write_atomic!: |files| {
			log!(w, "write_atomic ${Str.join_with(files.map(|f| f.path), " ")}")
			var $failed = Err(NotYet)
			for file in files {
				match $failed {
					Err(NotYet) => match write_with_parents!(file.path, file.content) {
						Ok(_) => {}
						Err(PathErr(NotFound, _)) => {
							$failed = Ok({ path: file.path, err: NotFound })
						}
						Err(PathErr(PermissionDenied, _)) => {
							$failed = Ok({ path: file.path, err: Denied })
						}
						Err(PathErr(other, _)) => {
							$failed = Ok({ path: file.path, err: Other(Str.inspect(other)) })
						}
					}
					Ok(_) => {}
				}
			}
			match $failed {
				Err(NotYet) => Ok({})
				Ok(failure) => Err(failure)
			}
		},
		out!: |text| append!("${w}/out/stdout", text),
		err!: |text| append!("${w}/out/stderr", text),
		list_dirs!: |dirs| {
			log!(w, "list_dirs ${Str.join_with(dirs, " ")}")
			overrides = lines(read_or_empty!("${w}/fx/mtimes")).map(split_time)
			var $results = []
			for dir in dirs {
				$results = $results.append(list_one!(dir, overrides))
			}
			$results
		},
		delete!: |paths| {
			log!(w, "delete ${Str.join_with(paths, " ")}")
			var $results = []
			for p in paths {
				one = match Path.type!(Path.utf8(p)) {
					Err(PathErr(NotFound, _)) => Ok({})
					Err(PathErr(PermissionDenied, _)) => Err(Denied)
					Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
					Ok(IsDir) => match Path.delete_all!(Path.utf8(p)) {
						Ok(_) => Ok({})
						Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))
					}
					Ok(_) => match Path.delete!(Path.utf8(p)) {
						Ok(_) => Ok({})
						Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))
					}
				}
				$results = $results.append(one)
			}
			$results
		},
		canonical!: |paths| {
			log!(w, "canonical ${Str.join_with(paths, " ")}")
			var $results = []
			for p in paths {
				one = match Path.exists!(Path.utf8(p)) {
					Ok(Bool.True) => Ok(p)
					Ok(Bool.False) => Err(NotFound)
					Err(PathErr(PermissionDenied, _)) => Err(Denied)
					Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
				}
				$results = $results.append(one)
			}
			$results
		},
		lock!: |item, mode| {
			busy_names = lines(read_or_empty!("${w}/fx/locks")).keep_if(|l| l.starts_with("busy ")).map(|l| l.drop_prefix("busy "))
			other_holds = busy_names.any(|name| item.ends_with("/${name}"))
			text = match mode {
				Wait => "wait"
				NoWait => "nowait"
			}
			if other_holds and text == "nowait" {
				log!(w, "lock ${item} ${text}: busy")
				Busy
			} else {
				log!(w, "lock ${item} ${text}: held")
				Held(Lock.{ item, token: "fake" })
			}
		},
		unlock!: |lock| log!(w, "unlock ${lock.item}"),
		http_get!: |request| http_get!(w, request),
		programs!: |names| {
			log!(w, "programs ${Str.join_with(names, " ")}")
			have = lines(read_or_empty!("${w}/fx/programs"))
			names.map(|name| have.contains(name))
		},
		spawn_all!: |batch| spawn_all!(w, batch),
		rename!: |move| {
			log!(w, "rename ${move.from} ${move.to}")
			refused = lines(read_or_empty!("${w}/fx/rename")).keep_if(|l| l.starts_with("exists ")).map(|l| l.drop_prefix("exists "))
			if refused.any(|suffix| move.to.ends_with(suffix)) {
				Err(Exists)
			} else {
				match Path.rename!(Path.utf8(move.from), Path.utf8(move.to)) {
					Ok(_) => Ok({})
					Err(PathErr(AlreadyExists, _)) => Err(Exists)
					Err(PathErr(NotFound, _)) => Err(NotFound)
					Err(PathErr(PermissionDenied, _)) => Err(Denied)
					Err(PathErr(Other(text), _)) => if text.contains("not empty") Err(Exists) else Err(Other(text))
					Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
				}
			}
		},
		make_dirs!: |dirs| {
			log!(w, "make_dirs ${Str.join_with(dirs, " ")}")
			var $failure = Ok({})
			for dir in dirs {
				if $failure == Ok({}) {
					$failure = match Path.create_all!(Path.utf8(dir)) {
						Ok(_) => Ok({})
						Err(PathErr(PermissionDenied, _)) => Err(Denied)
						Err(PathErr(err, _)) => Err(Other(Str.inspect(err)))
					}
				}
			}
			$failure
		},
		random!: || {
			log!(w, "random")
			match U64.from_str(read_or_empty!("${w}/fx/random").trim()) {
				Ok(n) => n
				Err(_) => 81985529216486895
			}
		},
		probes!: |specs| probes!(w, specs),
		copy_tree!: |move| copy_tree!(w, move),
		ask!: |prompt| {
			asked = lines(read_or_empty!("${w}/out/calls.log")).keep_if(|l| l.starts_with("ask ")).len()
			log_lines = lines(read_or_empty!("${w}/out/calls.log"))
			held = log_lines.keep_if(|l| l.starts_with("lock ") and l.ends_with(": held")).len()
			released = log_lines.keep_if(|l| l.starts_with("unlock ")).len()
			if held > released log!(w, "VIOLATION ask while a lock is held")
			log!(w, "ask ${Str.inspect(prompt)}")
			match keep_empty(read_or_empty!("${w}/fx/answers")).get(asked) {
				Ok(reply) => Ok(reply)
				Err(_) => Err(EndOfInput)
			}
		},
	}
}

list_one! : Str, List((Str, U64)) => Try(List({ name : Str, is_dir : Bool, mtime : U64 }), [NotFound, Denied, Other(Str)])
list_one! = |dir, overrides| match Path.list!(Path.utf8(dir)) {
	Err(PathErr(NotFound, _)) => Err(NotFound)
	Err(PathErr(PermissionDenied, _)) => Err(Denied)
	Err(PathErr(other, _)) => Err(Other(Str.inspect(other)))
	Ok(paths) => {
		var $entries = []
		for p in paths {
			name = match Path.filename(p) {
				Ok(f) => f.display()
				Err(_) => p.display()
			}
			is_dir = match Path.is_dir!(p) {
				Ok(b) => b
				Err(_) => Bool.False
			}
			real = match Path.time_modified!(p) {
				Ok(ns) => (ns // 1_000_000_000).to_u64_wrap()
				Err(_) => 0
			}
			mtime = match overrides.find_first(|(suffix, _)| "${dir}/${name}".ends_with(suffix)) {
				Ok((_, seconds)) => seconds
				Err(_) => real
			}
			$entries = $entries.append({ name, is_dir, mtime })
		}
		Ok($entries)
	}
}

## A write that creates the missing parent directories first (a decision of slice 002).
write_with_parents! : Str, Str => Try({}, [PathErr(_, Path)])
write_with_parents! = |file_path, content| {
	parent = Str.join_with(file_path.split_on("/").drop_last(1), "/")
	if !parent.is_empty() {
		_ = Path.create_all!(Path.utf8(parent))
	}
	Path.write_utf8!(Path.utf8(file_path), content)
}

read_or_empty! : Str => Str
read_or_empty! = |path| match Path.read_utf8!(Path.utf8(path)) {
	Ok(text) => text
	Err(_) => ""
}

append! : Str, Str => {}
append! = |path, text| {
	_ = Path.write_utf8!(Path.utf8(path), "${read_or_empty!(path)}${text}")
}

log! : Str, Str => {}
log! = |w, line| append!("${w}/out/calls.log", "${line}\n")

## The lines of a text, with the empty ones (an empty line is an answer: Enter). A last newline ends the last line.
keep_empty : Str -> List(Str)
keep_empty = |text| {
	parts = text.split_on("\n")
	if parts.last() == Ok("") parts.drop_last(1) else parts
}

lines : Str -> List(Str)
lines = |text| text.split_on("\n").keep_if(|l| !l.is_empty())

split_env : Str -> (Str, Str)
split_env = |line| match line.split_on("=") {
	[name, .. as rest] => (name, Str.join_with(rest, "="))
	[] => ("", "")
}

## `<suffix> <seconds>`
split_time : Str -> (Str, U64)
split_time = |line| match line.split_on(" ") {
	[suffix, seconds] => (suffix, U64.from_str(seconds) ?? 0)
	_ => ("", 0)
}

exists! : Str => Bool
exists! = |path| match Path.exists!(Path.utf8(path)) {
	Ok(b) => b
	Err(_) => Bool.False
}

## The answer of the fake `http_get!` (see the table at the top). The route is `<host>/<path>[?<query>]` of the URL.
http_get! : Str, { url : Str, headers : List((Str, Str)) } => Try({ status : U16, headers : List((Str, Str)), body : Str }, [Timeout, Failed(Str)])
http_get! = |w, request| {
	log!(w, "http_get ${request.url}")
	for (name, value) in request.headers {
		log!(w, "  ${name}: ${value}")
	}
	rest = request.url.drop_prefix("https://").drop_prefix("http://")
	(path_part, query) = match rest.split_on("?") {
		[p] => (p, "")
		[p, .. as q] => (p, Str.join_with(q, "?"))
		[] => (rest, "")
	}
	with_query = "${w}/fx/http/${path_part}?${query}"
	plain = "${w}/fx/http/${path_part}"
	route = if !query.is_empty() and (exists!(with_query) or exists!("${with_query}.meta")) with_query else plain
	if !exists!(route) and !exists!("${route}.meta") {
		Ok({ status: 404, headers: [], body: "{\"message\":\"Not Found\"}" })
	} else {
		meta = lines(read_or_empty!("${route}.meta"))
		status = match meta.find_first(|l| l.starts_with("status ")) {
			Ok(l) => U16.from_str(l.drop_prefix("status ")) ?? 200
			Err(_) => 200
		}
		headers = meta.keep_if(|l| l.starts_with("header ")).map(
			|l| match l.drop_prefix("header ").split_on(":") {
				[name, .. as value] => (name.trim(), Str.join_with(value, ":").trim())
				[] => ("", "")
			},
		)
		fails = meta.find_first(|l| l.starts_with("error "))
		etag = headers.find_first(|(name, _)| name == "ETag")
		sent = request.headers.find_first(|(name, _)| name == "If-None-Match")
		match fails {
			Ok("error timeout") => Err(Timeout)
			Ok(l) => Err(Failed(l.drop_prefix("error failed ")))
			Err(_) => match (etag, sent) {
				(Ok((_, tag)), Ok((_, same))) if tag == same => Ok({ status: 304, headers, body: "" })
				_ => Ok({ status, headers, body: read_or_empty!(route) })
			}
		}
	}
}

## The answer of the fake `spawn_all!` (see the table at the top).
spawn_all! : Str, { jobs : List({ argv : List(Str), cwd : Try(Str, [Inherit]) }), limit : U64 } => List({ ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str })
spawn_all! = |w, batch| {
	log!(w, "spawn_all limit=${batch.limit.to_str()}")
	rules = lines(read_or_empty!("${w}/fx/jobs")).keep_if(|l| !l.starts_with("#")).map(|l| l.split_on("\t"))
	var $results = []
	for job in batch.jobs {
		text = Str.join_with(job.argv, " ")
		cwd = match job.cwd {
			Ok(dir) => dir
			Err(Inherit) => "${w}/project"
		}
		log!(
			w,
			"  job ${
				match job.cwd {
					Ok(dir) => dir
					Err(Inherit) => "-"
				}
			} ${text}",
		)
		rule = rules.find_first(
			|fields| match fields {
				[needle, ..] => text.contains(needle)
				_ => Bool.False
			},
		)
		one = match rule {
			Ok([_, code, out, err, made]) => {
				for item in made.split_on(";").keep_if(|m| m != "-" and !m.is_empty()) {
					create_item!(item.replace_each("{cwd}", cwd).replace_each("{w}", w))
				}
				{ ended: ended_of(code), stdout: if out == "-" "" else out, stderr_last: if err == "-" "" else err }
			}
			_ => { ended: Exited(99), stdout: "", stderr_last: "fake spawn_all: no rule for: ${text}" }
		}
		$results = $results.append(one)
	}
	$results
}

## `probe-text`: see the table at the top.
describe_copy! : Str, Probe.Spec => {}
describe_copy! = |w, spec| {
	if exists!("${w}/fx/probe-text") and spec.dir.contains("/talon/tmp/") and spec.args.first() == Ok("check") {
		var $names = []
		match Path.list!(Path.utf8(spec.dir)) {
			Ok(paths) => for p in paths {
				name = match Path.filename(p) {
					Ok(f) => f.display()
					Err(_) => p.display()
				}
				$names = $names.append(
					match Path.is_dir!(p) {
						Ok(Bool.True) => "${name}/"
						_ => name
					},
				)
			}
			Err(_) => {}
		}
		names = $names.sort_with(|a, b| compare_text(a, b))
		log!(w, "  copy-entries ${Str.join_with(names, " ")}")
		file = spec.args.get(1) ?? ""
		all = read_or_empty!("${spec.dir}/${file}").split_on("\n")
		for line in header_lines(all) {
			log!(w, "  | ${line}")
		}
		var $rels = []
		match Path.list!(Path.utf8(spec.dir)) {
			Ok(paths) => for p in paths {
				name = match Path.filename(p) {
					Ok(f) => f.display()
					Err(_) => p.display()
				}
				match Path.is_dir!(p) {
					Ok(Bool.True) => match Path.list!(p) {
						Ok(inner) => for q in inner {
							inner_name = match Path.filename(q) {
								Ok(f) => f.display()
								Err(_) => q.display()
							}
							$rels = $rels.append("${name}/${inner_name}")
						}
						Err(_) => {}
					}
					_ => {
						$rels = $rels.append(name)
					}
				}
			}
			Err(_) => {}
		}
		for rel in $rels.keep_if(|r| r.ends_with(".roc") and r != file).sort_with(|a, b| compare_text(a, b)) {
			for line in read_or_empty!("${spec.dir}/${rel}").split_on("\n").keep_if(|l| l.starts_with("import \"")) {
				log!(w, "  ~ ${rel}: ${line}")
			}
		}
	}
}

## The lines from the first to the first one that starts with `}`, that one included.
header_lines : List(Str) -> List(Str)
header_lines = |all| match all.find_first_index(|l| l.starts_with("}")) {
	Ok(i) => all.take_first(i + 1)
	Err(_) => all
}

compare_text : Str, Str -> [Before, Same, After]
compare_text = |a, b| bytes_before(Str.to_utf8(a), Str.to_utf8(b))

bytes_before : List(U8), List(U8) -> [Before, Same, After]
bytes_before = |a, b| match (a, b) {
	([], []) => Same
	([], _) => Before
	(_, []) => After
	([x, .. as ra], [y, .. as rb]) => if x < y Before else if x > y After else bytes_before(ra, rb)
}

## `hooks`: see the table at the top. `n` is the number of `probes` calls so far.
run_hooks! : Str, U64 => {}
run_hooks! = |w, n| {
	for rule in lines(read_or_empty!("${w}/fx/hooks")).map(|l| l.split_on("\t")) {
		match rule {
			["after-probes", count, file, from, to] => if U64.from_str(count) == Ok(n) {
				path = "${w}/${file}"
				text = read_or_empty!(path)
				_ = Path.write_utf8!(Path.utf8(path), text.replace_first(from.replace_each("\\n", "\n"), to.replace_each("\\n", "\n")))
				log!(w, "hook ${file}")
			}
			_ => {}
		}
	}
}

ended_of : Str -> [Exited(I32), Signaled(I32), NotStarted(Str)]
ended_of = |code| if code.starts_with("signal:") {
	Signaled(I32.from_str(code.drop_prefix("signal:")) ?? 9)
} else if code.starts_with("notstarted:") {
	NotStarted(code.drop_prefix("notstarted:"))
} else {
	Exited(I32.from_str(code) ?? 99)
}

## `file:<path>` or `dir:<path>`
create_item! : Str => {}
create_item! = |item| {
	if item.starts_with("dir:") {
		_ = Path.create_all!(Path.utf8(item.drop_prefix("dir:")))
	} else if item.starts_with("file:") {
		_ = write_with_parents!(item.drop_prefix("file:"), "fake")
	}
}

## The answer of the fake `probes!` (see the table at the top).
probes! : Str, List(Probe.Spec) => List(Probe.Output)
probes! = |w, specs| {
	log!(w, "probes ${specs.len().to_str()}")
	rows = lines(read_or_empty!("${w}/fx/probes")).keep_if(|l| !l.starts_with("#")).map(|l| l.split_on("\t"))
	var $results = []
	for spec in specs {
		index = lines(read_or_empty!("${w}/out/calls.log")).keep_if(|l| l.starts_with("  probe ")).len()
		log!(w, "  probe ${spec.dir} ${spec.compiler} ${Str.join_with(spec.args, " ")} timeout=${spec.timeout.to_str()}")
		describe_copy!(w, spec)
		one = match rows.get(index) {
			Ok([code, out, err]) => {
				text! = |name| if name == "-" "" else read_or_empty!("${w}/fx/${name}")
				{ ended: probe_ended(code), stdout: text!(out), stderr: text!(err) }
			}
			_ => default_probe(spec)
		}
		$results = $results.append(one)
	}
	run_hooks!(w, lines(read_or_empty!("${w}/out/calls.log")).keep_if(|l| l.starts_with("probes ")).len())
	$results
}

probe_ended : Str -> [Exited(I32), Signaled(I32), TimedOut, NotStarted(Str)]
probe_ended = |code| if code == "timeout" {
	TimedOut
} else if code.starts_with("signal:") {
	Signaled(I32.from_str(code.drop_prefix("signal:")) ?? 9)
} else if code.starts_with("notstarted:") {
	NotStarted(code.drop_prefix("notstarted:"))
} else {
	Exited(I32.from_str(code) ?? 99)
}

default_probe : Probe.Spec -> Probe.Output
default_probe = |spec| match spec.args {
	["build", _, output] => { ended: Exited(0), stdout: "0 errors and 0 warnings found in 0ms while successfully building:\n\n    ${output.drop_prefix("--output=")}\n", stderr: "" }
	[_, file, ..] => { ended: Exited(0), stdout: "No errors found in 0ms for ${file}\n", stderr: "" }
	_ => { ended: Exited(0), stdout: "", stderr: "" }
}

## The answer of the fake `copy_tree!` (see the table at the top).
copy_tree! : Str, { from : Str, to : Str, skip : List(Str) } => Try({}, [NotFound, Exists, Denied, Other(Str)])
copy_tree! = |w, move| {
	log!(w, "copy_tree ${move.from} ${move.to}")
	if exists!(move.to) {
		Err(Exists)
	} else if !exists!(move.from) {
		Err(NotFound)
	} else {
		copy_dir!(move.from, move.to, move.skip)
		Ok({})
	}
}

copy_dir! : Str, Str, List(Str) => {}
copy_dir! = |from, to, skip| {
	_ = Path.create_all!(Path.utf8(to))
	match Path.list!(Path.utf8(from)) {
		Err(_) => {}
		Ok(paths) => for p in paths {
			name = match Path.filename(p) {
				Ok(f) => f.display()
				Err(_) => p.display()
			}
			if !skip.contains(name) {
				match Path.is_dir!(p) {
					Ok(Bool.True) => copy_dir!("${from}/${name}", "${to}/${name}", skip)
					_ => match Path.read_bytes!(p) {
						Ok(bytes) => {
							_ = Path.write_bytes!(Path.utf8("${to}/${name}"), bytes)
						}
						Err(_) => {}
					}
				}
			}
		}
	}
}
