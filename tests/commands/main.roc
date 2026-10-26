app [main!] {
	lib: "../../cli/lib/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.Path
import FakeFx
import L2Db
import L2Harness
import L2NoRank
import L2Prompt
import L2Resolve
import L2Util
import lib.Consent
import lib.Fetch
import lib.Fx
import lib.Github
import lib.Net
import lib.Known
import lib.Mode
import lib.Project
import lib.Roots
import lib.Run
import lib.ZigInstall

## The L2 test app (TESTING.md 2.4). `l2 <work dir> <entry>` runs one case with the fake `Fx`.
## It writes the exit code to `<work dir>/out/exit`. The runner (`tests/commands/run.sh`) compares the files.
##
## | Entry | Runs |
## | --- | --- |
## | `run` | `Run.run!` (the whole command code) with `fx/args` as the arguments |
## | `prompt` | `Prompt.ask!` for each line of `fx/prompts`, in order, with the mode of `Mode.from_env` (`--json` is the variable `TEST_JSON=1` in `fx/env`). It prints `<id>: <answer>` to stdout after each answer. At the first `Err` it prints `Fail.line` to stderr and stops, with no file. Else it writes `project/result.txt`. |
## | `project` | `Project.find!` for each line of `fx/searches` (slice 002). A line is the words `start=<dir>`, `file=<path>` and `home=<dir>` (all optional, relative to `project/`, `start` default `.`, `home` default `<work dir>/home`). Before the first search it makes an empty `.git` directory in each dir that `fx/gitdirs` lists, because git cannot hold a `.git` name in the case tree. It prints `== <line>` and then `file:`, `workspace:`, `toml:` to stdout, or `exit <code>` to stdout and the failure line to stderr. Exit code 0. |
## | `locks` | `Fx.with_lock!` and `Known.record!` in a fixed script (slice 002): 4 `with_lock!` runs (a body that works, a body that fails, `NoWait` on a busy item, `Wait` on a busy item), then 3 `Known.record!` runs. It prints `<n> <result>` for each run. Exit code 0. |
## | `index` | `Github.releases!` and `Github.hint!` for each line of `fx/runs` (slice 003). The line is `releases <owner>/<repo> [offline] [now=<seconds>] [env:<NAME>=<value>]...` or `hint <owner>/<repo> <tag> [offline] [env:<NAME>=<value>]...` (slice 068: `Github.hint!` keeps the answer in the index dir; `offline` is `--offline`). `now` is the real clock (default 1792065600). The environment is `fx/env` and the `env:` words (one `env_all!` call at the start). It prints `== <line>`, then for `releases`: `source: <live, cached <seconds>, missing>` and `pages: <byte count of each page>`, for `hint`: `hint: <text>` or `no hint`; or `exit <code>` and the failure line on stderr. A page that was found offline prints `offline_line` once, as a command does. Exit code 0. |
## | `fetch` | `Fetch.packages!` for each line of `fx/runs` (slice 003). The line is `fetch [offline] [env:<NAME>=<value>]... <url>...` (one `env_all!` call at the start, the `env:` words are added to the environment, as for `index`). The roots are in the case dir (`home/.cache/roc`). Slice 060: the program for `roc unbundle` is `Fetch.unbundler` (`Choose`); the words `have:<id>,<id>` (the installed compilers of the run: the dirs of `toolchains`; a `link-` id gets a `.talon.json` with the path `/fake/bin/<id>-roc`), `path:<file>` or `path:none` (the `roc` on `PATH`, `fx/path-roc`) and `select:<id>` (the selected compiler) set its facts. Slice 072b (R-SO14): `none:stop` (exit 18), `none:outside` (the default of the entry) and `none:project:<hash>,<hash>` set what to do with no compiler; the words `yes` and `allow-downloads` are the answers, `offline` is `--offline`, `env:TALON_AUTO_INSTALL=yes` (or `no`) and `env:CI=true` set the consent facts. It prints `== <line>`, then one line for each URL: `<url>: present`, `<url>: fetched`, or `<url>: exit <code>` with the failure line on stderr. Exit code 0. |
## | `norank` | `NoRank.ensure!` for each line of `fx/runs` (slice 072c): the installed compilers, the facts of the project, a fake probe for step (b) of R-SO14. The words are in the doc of `L2NoRank.roc`. |
## | `resolve` | `Project.find!` and `Resolve.run!` for each line of `fx/runs` (slice 005). The line is `<install or update> [<name>...] [frozen] [no-check] [offline] [lowest] [dry-run] [platform] [no-pin] [yes] [quiet] [rename-keys] [allow-moves] [allow-downloads] [probe-downloads] [auto-install=<yes or no>] [as=<alias>] [snapshot=<text>] [nightly=<true or false>] [compiler=<id>] [toolchain=<id>] [file=<path>] [now=<seconds>]`. The start dir is `project/`, the roots are in the case dir as for `fetch`. Before the first run it makes an empty `.git` directory in each dir that `fx/gitdirs` lists (as `project` does). It prints `== <line>`, the output of the run on stdout, `exit <code>` on stdout and the failure line on stderr. Exit code 0. Slice 023c: `compiler=<id>` is the `roc` on `PATH` with that id, and its file is `<work dir>/home/bin/roc` (the file that a probe runs when the id is not installed). Slice 025: `allow-downloads` and `probe-downloads` are the answer flags, `auto-install=<yes or no>` is `TALON_AUTO_INSTALL` (`Request.downloads`; no word is `Ask`), `env` is the environment of the fake. The entry has one mode for all runs (`Mode.from_env` of `fx/env`), so the cases of slice 025 use the entry `commands`. |
## | `commands` | `Run.run!` (the whole command code) for each line of `fx/commands` (slice 007). The line is the words after `tln`. Before the first run it makes an empty `.git` directory in each dir that `fx/gitdirs` lists (as `project` does). For each line it writes the words to `fx/args`, prints `== <line>`, runs, and prints `exit <code>` (stdout). Use `{w}` in `fx/env` for the paths of the case (`HOME={w}/home`). Slice 023: a line that starts with `@roc` runs as the `roc` proxy (`fx/program` is `roc` for this run, the other words are the arguments of `roc`). A word `env:<NAME>=<value>` (before or after `@roc`, not an argument) sets the variable for this run only (it replaces a line of `fx/env` with the same name). Slice 041: a word `cwd:<dir>` (not an argument) sets the current directory of this run to `project/<dir>` (the fake `cwd!` reads `fx/cwd`; no word is `project`). |
## | `db` | `Facts.load!`, `Facts.save!` and `Facts.pin!` for each line of `fx/runs` (slice 030). The line is `load <hash>:<nightly>:<target>...`, `save <replace or keep> <hash>:<nightly>:<target>:<outcome>:<modules>:<closure>...` (`modules` are split with `,`, both `modules` and `closure` can be empty) or `pin <tag>:<target>:<sha256>:<github-digest or registry>`. The roots are the dirs of the case (`<w>/home/.cache/roc`). It prints `== <line>`, then for a `load` each fact as a line of `Db.fact_line` (2 spaces first) or `  none`, for a `save` `Saved` or `Kept`, for a `pin` `New` or `Same`. A failure prints `exit <code>` to stdout and the line of the failure to stderr. The exit code of the entry is 0. |
## | `zig` | `ZigInstall.ensure!` for each line of `fx/runs` (slice 044). The line is `<need> [yes] [quiet] [json] [offline] [llvm=<target>:<size>] [env:<NAME>=<value>]...`: `need` is the text of `minimum_zig_version` (`0.17.0`), `llvm` is the LLVM line of the dependency list (`<size>` is a number of bytes, or `?` for an unknown size; default `x86_64-linux-musl:45000000`), a word `env:<NAME>=<value>` sets the variable for this run only (it replaces a line of `fx/env` with the same name, as for `commands`). It prints `== <line>`, then `zig <version> <how> <path>` (`how` is `found-env`, `found-path`, `found-installed`, `installed` or `present`) and `exit 0` on stdout, or the failure line on stderr and `exit <code>` on stdout. The entry calls `env_all!` once for each line (it is in `calls.log`). Exit code 0. |
## | `harness` | Calls each `Fx` function once. It tests the fake and the runner, not Talon. Exit code 3. |
main! = |args| {
	match args.map(|a| a.display()) {
		[w, entry] => {
			fx = FakeFx.make(w)
			code = match entry {
				"run" => Run.run!(fx)
				"prompt" => L2Prompt.entry!(fx, w)
				"project" => project_entry!(fx, w)
				"locks" => locks_entry!(fx, w)
				"index" => index_entry!(fx, w)
				"fetch" => fetch_entry!(fx, w)
				"norank" => L2NoRank.entry!(fx, w)
				"resolve" => L2Resolve.entry!(fx, w)
				"commands" => commands_entry!(fx, w)
				"zig" => zig_entry!(fx, w)
				"db" => L2Db.entry!(fx, w)
				"harness" => L2Harness.entry!(fx)
				_ => {
					fx.err!("unknown entry ${entry}\n")
					99
				}
			}
			_ = Path.write_utf8!(Path.utf8("${w}/out/exit"), "${code.to_str()}\n")
			Ok({})
		}
		_ => Err(Exit(98))
	}
}

project_entry! : Fx, Str => I32
project_entry! = |fx, w| {
	root = "${w}/project"
	for dir in L2Util.file_lines!("${w}/fx/gitdirs") {
		_ = Path.create_all!(Path.utf8("${root}/${dir}/.git"))
	}
	for line in L2Util.file_lines!("${w}/fx/searches") {
		given = L2Util.words(line).map(
			|word| match word.split_on("=") {
				[k, .. as v] => (k, Str.join_with(v, "="))
				[] => ("", "")
			},
		)
		value = |name| given.find_first(|(k, _)| k == name).map_ok(|(_, v)| v)
		under = |rel| if rel == "." root else "${root}/${rel}"
		start = under(value("start") ?? ".")
		home = match value("home") {
			Ok(rel) => under(rel)
			Err(_) => "${w}/home"
		}
		file = match value("file") {
			Ok(f) => Ok(f)
			Err(_) => Err(Unset)
		}
		fx.out!("== ${line}\n")
		match Project.find!(fx, { start, file, home }) {
			Ok(p) => {
				fx.out!("file: ${p.file.map_ok(|f| f).map_err(|_| "none") ?? "none"}\n")
				fx.out!("workspace: ${workspace_text(p.workspace)}\n")
				fx.out!("toml: ${p.toml ?? "none"}\n")
			}
			Err(fail) => {
				fx.out!("exit ${fail.kind.code().to_str()}\n")
				fx.err!("${fail.line()}\n")
			}
		}
	}
	0
}

workspace_text : Try({ root : Str, members : List(Str) }, [Standalone]) -> Str
workspace_text = |workspace| match workspace {
	Ok(ws) => "${ws.root} (${ws.members.len().to_str()} members)"
	Err(Standalone) => "standalone"
}

locks_entry! : Fx, Str => I32
locks_entry! = |fx, w| {
	item = "${w}/home/lk/a"
	busy = "${w}/home/lk/busy"
	read_body! = || {
		_ = fx.read_files!(["${w}/project/in.txt"])
		Ok("done")
	}
	fail_body! = || {
		_ = fx.read_files!(["${w}/project/in.txt"])
		Err(Boom)
	}
	fx.out!("1 ${Str.inspect(fx.with_lock!(item, NoWait, read_body!))}\n")
	fx.out!("2 ${Str.inspect(fx.with_lock!(item, NoWait, fail_body!))}\n")
	fx.out!("3 ${Str.inspect(fx.with_lock!(busy, NoWait, read_body!))}\n")
	fx.out!("4 ${Str.inspect(fx.with_lock!(busy, Wait, read_body!))}\n")
	cache = "${w}/home/.cache/roc"
	roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
	main_file = "${w}/project/app/main.roc"
	copy = "${cache}/talon/tmp/0123456789abcdef/main.roc"
	fx.out!("5 ${Str.inspect(Known.record!(fx, { roots, files: [main_file, copy], now: 1792065600 }).map_err(|f| f.line()))}\n")
	fx.out!("6 ${Str.inspect(Known.record!(fx, { roots, files: [], now: 1792065700 }).map_err(|f| f.line()))}\n")
	fx.out!("7 ${Str.inspect(Known.record!(fx, { roots, files: [copy], now: 1792065800 }).map_err(|f| f.line()))}\n")
	0
}

## Slice 003. See the table at the top for the entry.
index_entry! : Fx, Str => I32
index_entry! = |fx, w| {
	cache = "${w}/home/.cache/roc"
	roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
	base_env = fx.env_all!()
	for line in L2Util.file_lines!("${w}/fx/runs") {
		given = L2Util.words(line)
		extra = given.keep_if(|word| word.starts_with("env:")).map(
			|word| match word.drop_prefix("env:").split_on("=") {
				[name, .. as value] => (name, Str.join_with(value, "="))
				[] => ("", "")
			},
		)
		net = Net.from_env(base_env.concat(extra))
		fx.out!("== ${line}\n")
		match given {
			["releases", name, .. as rest] => {
				(owner, repo) = split_name(name)
				now = match rest.find_first(|word| word.starts_with("now=")) {
					Ok(word) => U64.from_str(word.drop_prefix("now=")) ?? 0
					Err(_) => 1792065600
				}
				match Github.releases!(fx, { net, roots, owner, repo, now, offline: rest.contains("offline") }) {
					Ok(found) => {
						source = match found.source {
							Live => "live"
							Cached(t) => "cached ${t.to_str()}"
							Missing => "missing"
						}
						match found.source {
							Cached(t) => fx.err!("${Github.offline_line(t)}\n")
							_ => {}
						}
						fx.out!("source: ${source}\n")
						fx.out!("pages: ${Str.inspect(found.pages.map(|page| page.count_utf8_bytes()))}\n")
					}
					Err(fail) => {
						fx.out!("exit ${fail.kind.code().to_str()}\n")
						fx.err!("${fail.line()}\n")
					}
				}
			}
			["hint", name, tag, .. as tag_rest] => {
				(owner, repo) = split_name(name)
				match Github.hint!(fx, { net, roots, owner, repo, tag, offline: tag_rest.contains("offline") }) {
					Ok(Ok(text)) => fx.out!("hint: ${text}\n")
					Ok(Err(NoHint)) => fx.out!("no hint\n")
					Err(fail) => {
						fx.out!("exit ${fail.kind.code().to_str()}\n")
						fx.err!("${fail.line()}\n")
					}
				}
			}
			_ => fx.out!("bad line\n")
		}
	}
	0
}

split_name : Str -> (Str, Str)
split_name = |name| match name.split_on("/") {
	[owner, repo] => (owner, repo)
	_ => (name, "")
}

fetch_entry! : Fx, Str => I32
fetch_entry! = |fx, w| {
	base_env = fx.env_all!()
	cache = "${w}/home/.cache/roc"
	roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
	for line in L2Util.file_lines!("${w}/fx/runs") {
		given = L2Util.words(line)
		extra = given.keep_if(|word| word.starts_with("env:")).map(
			|word| match word.drop_prefix("env:").split_on("=") {
				[name, .. as value] => (name, Str.join_with(value, "="))
				[] => ("", "")
			},
		)
		fx.out!("== ${line}\n")
		# Slice 060: `have:<id>,<id>` makes these the installed compilers of this run (the dirs of `toolchains`; `have:` alone: none). `path:<file>` is the `roc` on PATH, `path:none` is no `roc` on PATH. `select:<id>` is the selected compiler.
		have = given.find_first(|word| word.starts_with("have:"))
		match have {
			Ok(word) => {
				ids = word.drop_prefix("have:").split_on(",").keep_if(|id| !id.is_empty())
				_ = Path.delete_all!(Path.utf8("${cache}/toolchains"))
				for id in ids {
					_ = Path.create_all!(Path.utf8("${cache}/toolchains/${id}"))
					if id.starts_with("link-") {
						_ = Path.write_utf8!(Path.utf8("${cache}/toolchains/${id}/.talon.json"), "{\"format\":1,\"id\":\"${id}\",\"path\":\"/fake/bin/${id}-roc\",\"installed_at\":\"2026-10-21T09:30:00Z\"}")
					}
				}
			}
			Err(_) => {}
		}
		on_path = given.find_first(|word| word.starts_with("path:"))
		match on_path {
			Ok(word) => {
				file = word.drop_prefix("path:")
				_ = Path.write_utf8!(Path.utf8("${w}/fx/path-roc"), if file == "none" "" else "exe /fake/bin/tln 5000 1700000000\nfile ${file} 1000 1700000000\n")
			}
			Err(_) => {}
		}
		selected = (given.find_first(|word| word.starts_with("select:")) ?? "select:").drop_prefix("select:")
		plain = |word| !["offline", "yes", "allow-downloads"].contains(word) and !word.starts_with("env:") and !word.starts_with("have:") and !word.starts_with("path:") and !word.starts_with("select:") and !word.starts_with("none:")
		urls = given.drop_first(1).keep_if(plain)
		env = base_env.concat(extra)
		net = Net.from_env(env)
		# Slice 072b (R-SO14): `none:stop`, `none:outside` (no word is this) and `none:project:<hash>,<hash>` are the `none` of `Choose`. The consent facts come from the words `yes`, `allow-downloads`, `offline` and from `env` (`TALON_AUTO_INSTALL`, the mode).
		downloads = {
			auto: Consent.auto_install(env),
			allow: if given.contains("allow-downloads") Ok(Yes) else Err(NoFlag),
			yes: given.contains("yes"),
			mode: Mode.from_env({ env: Dict.from_list(env), json: Bool.False }),
			quiet: Bool.False,
			offline: given.contains("offline"),
			env,
		}
		none_text = (given.find_first(|word| word.starts_with("none:")) ?? "none:outside").drop_prefix("none:")
		none = if none_text == "stop" {
			Stop
		} else if none_text.starts_with("project:") {
			Download({ scope: Project(none_text.drop_prefix("project:").split_on(",").keep_if(|hash| !hash.is_empty())), downloads })
		} else {
			Download({ scope: Outside, downloads })
		}
		results = Fetch.packages!(fx, { roots, urls, offline: given.contains("offline"), unbundler: Choose({ selected: selected, none: none }), downloader: net.downloader })
		for (url, result) in urls.map2(results, |u, r| (u, r)) {
			match result {
				Ok(Present) => fx.out!("${url}: present\n")
				Ok(Fetched) => fx.out!("${url}: fetched\n")
				Err(fail) => {
					fx.out!("${url}: exit ${fail.kind.code().to_str()}\n")
					fx.err!("${fail.line()}\n")
				}
			}
		}
	}
	0
}

## Slice 007. See the table at the top for the entry.
commands_entry! : Fx, Str => I32
commands_entry! = |fx, w| {
	for dir in L2Util.file_lines!("${w}/fx/gitdirs") {
		_ = Path.create_all!(Path.utf8("${w}/project/${dir}/.git"))
	}
	base_env = match Path.read_utf8!(Path.utf8("${w}/fx/env")) {
		Ok(text) => text.trim_end()
		Err(_) => ""
	}
	for line in L2Util.file_lines!("${w}/fx/commands").keep_if(|l| !l.starts_with("#")) {
		fx.out!("== ${line}\n")
		all = L2Util.words(line)
		extra = all.keep_if(|word| word.starts_with("env:")).map(|word| word.drop_prefix("env:"))
		rest = all.keep_if(|word| !word.starts_with("env:") and !word.starts_with("cwd:"))
		cwd = (all.find_first(|word| word.starts_with("cwd:")) ?? "cwd:").drop_prefix("cwd:")
		_ = Path.write_utf8!(Path.utf8("${w}/fx/cwd"), cwd)
		proxy = rest.first() == Ok("@roc")
		_ = Path.write_utf8!(Path.utf8("${w}/fx/args"), Str.join_with(if proxy rest.drop_first(1) else rest, "\n"))
		_ = Path.write_utf8!(Path.utf8("${w}/fx/program"), if proxy "roc" else "tln")
		names = extra.map(|pair| pair.split_on("=").first() ?? "")
		kept = base_env.split_on("\n").keep_if(|row| !row.is_empty() and !names.contains(row.split_on("=").first() ?? ""))
		_ = Path.write_utf8!(Path.utf8("${w}/fx/env"), Str.join_with(kept.concat(extra), "\n"))
		code = Run.run!(fx)
		fx.out!("exit ${code.to_str()}\n")
	}
	0
}

## Slice 044. See the table at the top for the entry.
zig_entry! : Fx, Str => I32
zig_entry! = |fx, w| {
	base_env = match Path.read_utf8!(Path.utf8("${w}/fx/env")) {
		Ok(text) => text.trim_end()
		Err(_) => ""
	}
	for line in L2Util.file_lines!("${w}/fx/runs").keep_if(|l| !l.starts_with("#")) {
		fx.out!("== ${line}\n")
		all = L2Util.words(line)
		extra = all.keep_if(|word| word.starts_with("env:")).map(|word| word.drop_prefix("env:"))
		names = extra.map(|pair| pair.split_on("=").first() ?? "")
		kept = base_env.split_on("\n").keep_if(|row| !row.is_empty() and !names.contains(row.split_on("=").first() ?? ""))
		_ = Path.write_utf8!(Path.utf8("${w}/fx/env"), Str.join_with(kept.concat(extra), "\n"))
		llvm_word = (all.find_first(|word| word.starts_with("llvm=")) ?? "llvm=x86_64-linux-musl:45000000").drop_prefix("llvm=")
		llvm = match llvm_word.split_last(":") {
			Ok(parts) => { target: parts.before, size: U64.from_str(parts.after).map_err(|_| Unknown) }
			Err(_) => { target: llvm_word, size: Err(Unknown) }
		}
		facts = {
			need: all.first() ?? "",
			env: fx.env_all!(),
			yes: all.contains("yes"),
			quiet: all.contains("quiet"),
			json: all.contains("json"),
			offline: all.contains("offline"),
			llvm,
		}
		match ZigInstall.ensure!(fx, facts) {
			Ok(done) => {
				how = match done.how {
					Found(Env) => "found-env"
					Found(Path) => "found-path"
					Found(Installed) => "found-installed"
					Installed => "installed"
					Present => "present"
				}
				fx.out!("zig ${done.version} ${how} ${done.path}\n")
				fx.out!("exit 0\n")
			}
			Err(fail) => {
				fx.err!("${fail.line()}\n")
				fx.out!("exit ${fail.kind.code().to_str()}\n")
			}
		}
	}
	0
}
