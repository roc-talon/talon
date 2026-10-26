app [main!] {
	http: "https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
	lib: "lib/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import lib.Db
import lib.Fx
import lib.Text
import RealFx

## A test tool, not part of `tln` (TESTING.md 2.3, TW4). It calls one real `Fx` function and prints what
## the function gave, so that an L3 case can check each job of the real `Fx`. It has no Talon logic.
## `fxprobe <call> [words...]`. Calls: args, env, cwd, read, write, out, err, tty, clock, ask, and from slice 002:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `list <dir>...` | `list_dirs!` | `entry <file or dir> <mtime> <name>` for each entry (the order of the file system: sort it), or `err <dir> <error>` |
## | `delete <path>...` | `delete!` | `deleted <path>` or `failed <path> <error>` |
## | `canonical <path>...` | `canonical!` | `ok <path>` or `err <path> <error>` |
## | `lock <wait or nowait> <item>` | `lock!`, then `unlock!` when it got the lock | `held <item>` then `unlocked <item>`, or `busy <item>` |
## | `lockseq <wait or nowait> <item>...` | `lock!` for each item in order, then `unlock!` in the reverse order | `held <item>` for each, `busy <item>` and a stop at the first busy, then `unlocked <item>` for each held lock |
##
## Slice 003 adds six calls:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `http <url> [<Name>: <value>]...` | `http_get!` with these headers | `status <n>`, `header <Name>: <value>` for each header of the answer, `body <text>`. Or `err <Timeout or Failed(text)>`. |
## | `programs <name>...` | `programs!` | `<name> yes` or `<name> no` |
## | `spawn <limit> <cwd or -> <argv words> [-- <argv words>]...` | `spawn_all!`: one job for each group of words. `-` is `Inherit`. | `job <i> <ended> stdout=<text> stderr_last=<text>` for each job, in the order of the jobs |
## | `rename <from> <to>` | `rename!` | `renamed` or `err <error>` |
## | `mkdirs <path>...` | `make_dirs!` | `made` or `err <error>` |
## | `random` | `random!` twice | `random ok` when the two numbers differ |
## | `lockspawn <item> <cwd or -> <argv words>` | `lock!` (`NoWait`) of the item, then `spawn_all!` with one job and limit 1, then `unlock!` | `held <item>`, the `job` line, `unlocked <item>`. Or `busy <item>`. The lock stays held during the child (R-CC3 point 3), and its heartbeat goes on in the poll loop (R-CC12). |
## Slice 006 adds two calls:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `probes <timeout> <dir> [program=<file>] [env:<NAME>=<value>]... <roc args> [-- <timeout> <dir> ...]...` | `probes!`: one probe for each group of words, with the compiler id `nightly-fake`. Slice 023c: the words `program=<file>` and `env:<NAME>=<value>` right after the dir are the `program` (default `roc`, the name on `PATH`) and one variable of `env` | `probe <i> <ended> stdout=<text> stderr=<text>` for each probe, in the order of the probes |
## | `copytree <from> <to> [<skip name>...]` | `copy_tree!` | `copied`, or `err <error>` |
## Slice 031 adds one call and one word:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `pool <slots> <timeout> <dir> [program=<file>] [weight=<n>] [env:<NAME>=<value>]... <roc args> [-- ...]...` | `probes!` with the pool of `<slots>` (R-PP6, R-PP7). `weight=<n>` is the `weight` of a probe (default 1). `probes` is `pool 12`. | the same lines as `probes` |
## Slice 021 adds two calls:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `platform` | `platform!` | `os <linux, macos, windows or the name>` and `arch <x64, arm64 or the name>` |
## | `sha256 <file>...` | `sha256_file!` for each file | `sha256 <hex> <file>`, or `err <file> <error>` |
## Slice 022b adds one call:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `path-roc` | `path_roc!` | `exe <path> <size> <mtime>` (or `exe unknown`), then `file <path> <size> <mtime>` for each `roc` file on `PATH`, in the order of `PATH` |
## Slice 023 adds two calls:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `program-name` | `program_name!` | `program <text>` |
## | `exec [<NAME>=<value>]... -- <argv words>` | `exec!` with these variables | `exec ok <code>` or `exec err <text>` (after the output of the child, which goes to the terminal of the process) |
## Slice 057 adds one call:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `exec-in <dir> [<NAME>=<value>]... -- <argv words>` | `exec_in!` with this directory and these variables | `exec-in ok <code>` or `exec-in err <text>` |
## Slice 051 adds one call:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `spawn-detached [<NAME>=<value>]... -- <argv words>` | `spawn_detached!` with these variables. The probe ends at once, the child goes on | `spawn-detached ok` or `spawn-detached err <text>` |
## Slice 024b adds one call:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `copyfile <from> <to>` | `copy_file!` | `copied`, or `err <error>` |
## Slice 027 adds one call:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `hardlink <from> <to>` | `hard_link!` | `linked`, or `err <error>` |
## Slice 028b adds one call:
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `tree <path>...` | `tree_info!` with all the paths in one call | `tree <newest> <size> <path>` for each path, or `err <path> <error>` |
## Slice 030 adds two calls (the db calls of the real `Fx`; `<busy_ms>` is the busy timeout of the call, and the format is `Db.format`):
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `db-query <path> <busy_ms> facts <hash:nightly:target>...` | `db_query!` with `Facts(keys)` | the `Db.fact_line` of each row, sorted by the line (no row: `none`), or `err <the error>` |
## | `db-query <path> <busy_ms> pinned <tag:target>...` | `db_query!` with `Pinned(keys)` | the `Db.pinned_line` of each row, sorted, or `none`, or `err <the error>` |
## | `db-write <path> <busy_ms> facts <replace or keep> <hash:nightly:target:outcome:modules:closure>...` | `db_write!` with `Facts` (`modules` are split at `,`) | `ok` or `err <the error>` |
## | `db-write <path> <busy_ms> pinned <tag:target:sha256:source>...` | `db_write!` with `Pinned` (`source` is `github-digest` or `registry`) | `ok` or `err <the error>` |
main! = |args| {
	fx = RealFx.make!(args.map(|a| a.display()))
	match fx.args!() {
		[call, .. as rest] => probe!(fx, call, rest)
		[] => fx.err!("usage: fxprobe <call> [words...]\n")
	}
	Ok({})
}

say! : Fx, Str => {}
say! = |fx, line| fx.out!("${line}\n")

probe! : Fx, Str, List(Str) => {}
probe! = |fx, call, rest| match (call, rest) {
	("args", _) => say!(fx, Str.inspect(fx.args!()))
	("env", _) => for (name, value) in fx.env_all!() {
		say!(fx, "${name}=${value}")
	}
	("cwd", _) => say!(fx, fx.cwd!())
	("read", paths) => {
		results = fx.read_files!(paths)
		for (path, result) in paths.map2(results, |p, r| (p, r)) {
			match result {
				Ok(text) => say!(fx, "ok ${path} ${Str.inspect(text)}")
				Err(err) => say!(fx, "err ${path} ${Str.inspect(err)}")
			}
		}
	}
	("write", [path, content]) => match fx.write_atomic!([{ path, content }]) {
		Ok(_) => say!(fx, "wrote ${path}")
		Err({ path: bad, err }) => say!(fx, "failed ${bad} ${Str.inspect(err)}")
	}
	("out", words) => fx.out!(Str.join_with(words, " "))
	("err", words) => fx.err!(Str.join_with(words, " "))
	("tty", _) => {
		tty = fx.tty!()
		say!(fx, "stdin=${Str.inspect(tty.stdin)} stderr=${Str.inspect(tty.stderr)}")
	}
	("clock", _) => say!(fx, Str.inspect(fx.clock!()))
	("ask", words) => match fx.ask!(Str.join_with(words, " ")) {
		Ok(line) => say!(fx, "got ${line}")
		Err(EndOfInput) => say!(fx, "end of input")
	}
	("list", dirs) => {
		results = fx.list_dirs!(dirs)
		for (dir, result) in dirs.map2(results, |d, r| (d, r)) {
			match result {
				Ok(entries) => for e in entries {
					say!(fx, "entry ${if e.is_dir "dir" else "file"} ${e.mtime.to_str()} ${e.name}")
				}
				Err(err) => say!(fx, "err ${dir} ${Str.inspect(err)}")
			}
		}
	}
	("delete", paths) => {
		results = fx.delete!(paths)
		for (path, result) in paths.map2(results, |p, r| (p, r)) {
			match result {
				Ok(_) => say!(fx, "deleted ${path}")
				Err(err) => say!(fx, "failed ${path} ${Str.inspect(err)}")
			}
		}
	}
	("canonical", paths) => {
		results = fx.canonical!(paths)
		for (path, result) in paths.map2(results, |p, r| (p, r)) {
			match result {
				Ok(real) => say!(fx, "ok ${real}")
				Err(err) => say!(fx, "err ${path} ${Str.inspect(err)}")
			}
		}
	}
	("lock", [mode, item]) => match fx.lock!(item, lock_mode(mode)) {
		Held(lock) => {
			say!(fx, "held ${item}")
			fx.unlock!(lock)
			say!(fx, "unlocked ${item}")
		}
		Busy => say!(fx, "busy ${item}")
	}
	("lockseq", [mode, .. as items]) => lockseq!(fx, lock_mode(mode), items)
	("http", [url, .. as header_words]) => {
		headers = header_words.map(
			|word| match word.split_on(":") {
				[name, .. as value] => (name, Str.join_with(value, ":").trim())
				[] => ("", "")
			},
		)
		match fx.http_get!({ url, headers }) {
			Ok(answer) => {
				say!(fx, "status ${answer.status.to_str()}")
				for (name, value) in answer.headers {
					say!(fx, "header ${name}: ${value}")
				}
				say!(fx, "body ${answer.body}")
			}
			Err(err) => say!(fx, "err ${Str.inspect(err)}")
		}
	}
	("programs", names) => {
		found = fx.programs!(names)
		for (name, here) in names.map2(found, |n, f| (n, f)) {
			say!(fx, "${name} ${if here "yes" else "no"}")
		}
	}
	("spawn", [limit, cwd, .. as words]) => {
		jobs = split_jobs(words).map(|argv| { argv, cwd: if cwd == "-" Err(Inherit) else Ok(cwd) })
		results = fx.spawn_all!({ jobs, limit: U64.from_str(limit) ?? 1 })
		for (i, result) in results.map_with_index(|r, i| (i, r)) {
			say!(fx, "job ${i.to_str()} ${Str.inspect(result.ended)} stdout=${Str.inspect(result.stdout)} stderr_last=${Str.inspect(result.stderr_last)}")
		}
	}
	("rename", [from, to]) => match fx.rename!({ from, to }) {
		Ok(_) => say!(fx, "renamed")
		Err(err) => say!(fx, "err ${Str.inspect(err)}")
	}
	("mkdirs", paths) => match fx.make_dirs!(paths) {
		Ok(_) => say!(fx, "made")
		Err(err) => say!(fx, "err ${Str.inspect(err)}")
	}
	("lockspawn", [item, cwd, .. as words]) => match fx.lock!(item, NoWait) {
		Held(lock) => {
			say!(fx, "held ${item}")
			results = fx.spawn_all!({ jobs: [{ argv: words, cwd: if cwd == "-" Err(Inherit) else Ok(cwd) }], limit: 1 })
			for result in results {
				say!(fx, "job 0 ${Str.inspect(result.ended)} stdout=${Str.inspect(result.stdout)} stderr_last=${Str.inspect(result.stderr_last)}")
			}
			fx.unlock!(lock)
			say!(fx, "unlocked ${item}")
		}
		Busy => say!(fx, "busy ${item}")
	}
	("probes", words) => show_probes!(fx, 12, words)
	("pool", [size, .. as words]) => show_probes!(fx, U64.from_str(size) ?? 12, words)
	("copytree", [from, to, .. as skip]) => match fx.copy_tree!({ from, to, skip }) {
		Ok(_) => say!(fx, "copied")
		Err(err) => say!(fx, "err ${Str.inspect(err)}")
	}
	("copyfile", [from, to]) => match fx.copy_file!({ from, to }) {
		Ok(_) => say!(fx, "copied")
		Err(err) => say!(fx, "err ${Str.inspect(err)}")
	}
	("tree", paths) => for (path, found) in paths.map2(fx.tree_info!(paths), |p, f| (p, f)) {
		match found {
			Ok(info) => say!(fx, "tree ${info.newest.to_str()} ${info.size.to_str()} ${path}")
			Err(err) => say!(fx, "err ${path} ${Str.inspect(err)}")
		}
	}
	("hardlink", [from, to]) => match fx.hard_link!({ from, to }) {
		Ok(_) => say!(fx, "linked")
		Err(err) => say!(fx, "err ${Str.inspect(err)}")
	}
	("platform", _) => {
		found = fx.platform!()
		say!(
			fx,
			"os ${
				match found.os {
					Linux => "linux"
					Macos => "macos"
					Windows => "windows"
					Other(name) => name
				}
			}",
		)
		say!(
			fx,
			"arch ${
				match found.arch {
					X64 => "x64"
					Arm64 => "arm64"
					Other(name) => name
				}
			}",
		)
	}
	("sha256", paths) => for path in paths {
		match fx.sha256_file!(path) {
			Ok(hex) => say!(fx, "sha256 ${hex} ${path}")
			Err(err) => say!(fx, "err ${path} ${Str.inspect(err)}")
		}
	}
	("path-roc", _) => {
		found = fx.path_roc!()
		match found.exe {
			Ok(exe) => say!(fx, "exe ${exe.path} ${exe.size.to_str()} ${exe.mtime.to_str()}")
			Err(Unknown) => say!(fx, "exe unknown")
		}
		for file in found.found {
			say!(fx, "file ${file.path} ${file.size.to_str()} ${file.mtime.to_str()}")
		}
	}
	("program-name", _) => say!(fx, "program ${fx.program_name!()}")
	("exec", words) => {
		sep = words.map_with_index(|w, i| (w, i)).find_first(|(w, _)| w == "--")
		match sep {
			Ok((_, at)) => {
				env = words.take_first(at).keep_oks(
					|w| match w.split_first("=") {
						Ok({ before, after }) => Ok((before, after))
						Err(_) => Err(NoEquals)
					},
				)
				match fx.exec!({ argv: words.drop_first(at + 1), env }) {
					Ok(code) => say!(fx, "exec ok ${code.to_str()}")
					Err(NotStarted(text)) => say!(fx, "exec err ${text}")
				}
			}
			Err(_) => fx.err!("usage: fxprobe exec [NAME=value]... -- <argv words>\n")
		}
	}
	("spawn-detached", words) => {
		sep = words.map_with_index(|w, i| (w, i)).find_first(|(w, _)| w == "--")
		match sep {
			Ok((_, at)) => {
				env = words.take_first(at).keep_oks(
					|w| match w.split_first("=") {
						Ok({ before, after }) => Ok((before, after))
						Err(_) => Err(NoEquals)
					},
				)
				match fx.spawn_detached!({ argv: words.drop_first(at + 1), env }) {
					Ok(_) => say!(fx, "spawn-detached ok")
					Err(NotStarted(text)) => say!(fx, "spawn-detached err ${text}")
				}
			}
			Err(_) => fx.err!("usage: fxprobe spawn-detached [NAME=value]... -- <argv words>\n")
		}
	}
	("exec-in", [dir, .. as words]) => {
		sep = words.map_with_index(|w, i| (w, i)).find_first(|(w, _)| w == "--")
		match sep {
			Ok((_, at)) => {
				env = words.take_first(at).keep_oks(
					|w| match w.split_first("=") {
						Ok({ before, after }) => Ok((before, after))
						Err(_) => Err(NoEquals)
					},
				)
				match fx.exec_in!({ argv: words.drop_first(at + 1), env, cwd: dir }) {
					Ok(code) => say!(fx, "exec-in ok ${code.to_str()}")
					Err(NotStarted(text)) => say!(fx, "exec-in err ${text}")
				}
			}
			Err(_) => fx.err!("usage: fxprobe exec-in <dir> [NAME=value]... -- <argv words>\n")
		}
	}
	("db-query", [path, busy, "facts", .. as specs]) => {
		keys = specs.keep_oks(
			|spec| match spec.split_on(":") {
				[hash, nightly, target] => Ok({ hash, nightly, target })
				_ => Err(BadSpec)
			},
		)
		match fx.db_query!({ path, busy_ms: U64.from_str(busy) ?? 0, format: Db.format }, Facts(keys)) {
			Ok(Facts(rows)) => lines_of!(fx, rows.map(Db.fact_line))
			Ok(Pinned(_)) => say!(fx, "err wrong answer")
			Err(err) => say!(fx, "err ${Str.inspect(err)}")
		}
	}
	("db-query", [path, busy, "pinned", .. as specs]) => {
		keys = specs.keep_oks(
			|spec| match spec.split_on(":") {
				[tag, target] => Ok({ tag, target })
				_ => Err(BadSpec)
			},
		)
		match fx.db_query!({ path, busy_ms: U64.from_str(busy) ?? 0, format: Db.format }, Pinned(keys)) {
			Ok(Pinned(rows)) => lines_of!(fx, rows.map(Db.pinned_line))
			Ok(Facts(_)) => say!(fx, "err wrong answer")
			Err(err) => say!(fx, "err ${Str.inspect(err)}")
		}
	}
	("db-write", [path, busy, "facts", mode, .. as specs]) => {
		rows = specs.keep_oks(
			|spec| match spec.split_on(":") {
				[hash, nightly, target, outcome, modules, closure] => match Db.outcome_of(outcome) {
					Ok(o) => Ok({ hash, nightly, target, outcome: o, modules: Db.modules_of(modules), closure })
					Err(_) => Err(BadSpec)
				}
				_ => Err(BadSpec)
			},
		)
		write = Facts({ rows, existing: if mode == "keep" Keep else Replace })
		match fx.db_write!({ path, busy_ms: U64.from_str(busy) ?? 0, format: Db.format }, write) {
			Ok(_) => say!(fx, "ok")
			Err(err) => say!(fx, "err ${Str.inspect(err)}")
		}
	}
	("db-write", [path, busy, "pinned", .. as specs]) => {
		rows = specs.keep_oks(
			|spec| match spec.split_on(":") {
				[tag, target, sha256, source] => match Db.source_of(source) {
					Ok(src) => Ok({ tag, target, sha256, source: src })
					Err(_) => Err(BadSpec)
				}
				_ => Err(BadSpec)
			},
		)
		match fx.db_write!({ path, busy_ms: U64.from_str(busy) ?? 0, format: Db.format }, Pinned(rows)) {
			Ok(_) => say!(fx, "ok")
			Err(err) => say!(fx, "err ${Str.inspect(err)}")
		}
	}
	("random", _) => if fx.random!() != fx.random!() say!(fx, "random ok") else say!(fx, "random same")
	_ => fx.err!("unknown call\n")
}

lock_mode : Str -> [Wait, NoWait]
lock_mode = |text| if text == "wait" Wait else NoWait

# Takes the items in order and then releases them in the reverse order. It stops at the first `Busy`.
lockseq! : Fx, [Wait, NoWait], List(Str) => {}
lockseq! = |fx, mode, items| match items {
	[] => {}
	[item, .. as rest] => match fx.lock!(item, mode) {
		Held(lock) => {
			say!(fx, "held ${item}")
			lockseq!(fx, mode, rest)
			fx.unlock!(lock)
			say!(fx, "unlocked ${item}")
		}
		Busy => say!(fx, "busy ${item}")
	}
}

# The groups of words between `--`.
split_jobs : List(Str) -> List(List(Str))
split_jobs = |words| words.fold(
	[[]],
	|groups, word| if word == "--" {
		groups.append([])
	} else {
		match groups.last() {
			Ok(current) => groups.drop_last(1).append(current.append(word))
			Err(_) => [[word]]
		}
	},
)

# One line for each text of the list, in byte order. No text: `none`.
lines_of! : Fx, List(Str) => {}
lines_of! = |fx, texts| if texts.is_empty() {
	say!(fx, "none")
} else {
	for text in Text.sorted(texts) {
		say!(fx, text)
	}
}

# The `probes` and `pool` calls: one probe for each group of words. `weight=<n>` is the weight of the probe (slice 031, default 1).
show_probes! : Fx, U64, List(Str) => {}
show_probes! = |fx, pool, words| {
	specs = split_jobs(words).keep_oks(
		|group| match group {
			[timeout, dir, .. as more] => {
				program = match more.keep_if(|word| word.starts_with("program=")).first() {
					Ok(word) => word.drop_prefix("program=")
					Err(_) => "roc"
				}
				weight = match more.keep_if(|word| word.starts_with("weight=")).first() {
					Ok(word) => U64.from_str(word.drop_prefix("weight=")) ?? 1
					Err(_) => 1
				}
				env = more.keep_if(|word| word.starts_with("env:")).map(|word| word.drop_prefix("env:").split_first("=")).keep_oks(|split| split.map_ok(|pair| (pair.before, pair.after)))
				args = more.keep_if(|word| !word.starts_with("program=") and !word.starts_with("env:") and !word.starts_with("weight="))
				Ok({ compiler: "nightly-fake", program, args, dir, env, timeout: U64.from_str(timeout) ?? 30, weight })
			}
			_ => Err(BadGroup)
		},
	)
	results = fx.probes!({ pool, specs })
	for (i, result) in results.map_with_index(|r, i| (i, r)) {
		say!(fx, "probe ${i.to_str()} ${Str.inspect(result.ended)} stdout=${Str.inspect(result.stdout)} stderr=${Str.inspect(result.stderr)}")
	}
}
