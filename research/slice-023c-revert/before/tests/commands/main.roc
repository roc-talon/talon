app [main!] {
	lib: "../../cli/lib/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.Path
import FakeFx
import lib.Answer
import lib.Fail
import lib.Fetch
import lib.Fx
import lib.Github
import lib.Kind
import lib.Known
import lib.Mode
import lib.Net
import lib.Project
import lib.Prompt
import lib.Resolve
import lib.Roots
import lib.Run

## The L2 test app (TESTING.md 2.4). `l2 <work dir> <entry>` runs one case with the fake `Fx`.
## It writes the exit code to `<work dir>/out/exit`. The runner (`tests/commands/run.sh`) compares the files.
##
## | Entry | Runs |
## | --- | --- |
## | `run` | `Run.run!` (the whole command code) with `fx/args` as the arguments |
## | `prompt` | `Prompt.ask!` for each line of `fx/prompts`, in order, with the mode of `Mode.from_env` (`--json` is the variable `TEST_JSON=1` in `fx/env`). It prints `<id>: <answer>` to stdout after each answer. At the first `Err` it prints `Fail.line` to stderr and stops, with no file. Else it writes `project/result.txt`. |
## | `project` | `Project.find!` for each line of `fx/searches` (slice 002). A line is the words `start=<dir>`, `file=<path>` and `home=<dir>` (all optional, relative to `project/`, `start` default `.`, `home` default `<work dir>/home`). Before the first search it makes an empty `.git` directory in each dir that `fx/gitdirs` lists, because git cannot hold a `.git` name in the case tree. It prints `== <line>` and then `file:`, `workspace:`, `toml:` to stdout, or `exit <code>` to stdout and the failure line to stderr. Exit code 0. |
## | `locks` | `Fx.with_lock!` and `Known.record!` in a fixed script (slice 002): 4 `with_lock!` runs (a body that works, a body that fails, `NoWait` on a busy item, `Wait` on a busy item), then 3 `Known.record!` runs. It prints `<n> <result>` for each run. Exit code 0. |
## | `index` | `Github.releases!` and `Github.hint!` for each line of `fx/runs` (slice 003). The line is `releases <owner>/<repo> [offline] [now=<seconds>] [env:<NAME>=<value>]...` or `hint <owner>/<repo> <tag> [env:<NAME>=<value>]...`. `now` is the real clock (default 1792065600). The environment is `fx/env` and the `env:` words (one `env_all!` call at the start). It prints `== <line>`, then for `releases`: `source: <live, cached <seconds>, missing>` and `pages: <byte count of each page>`, for `hint`: `hint: <text>` or `no hint`; or `exit <code>` and the failure line on stderr. A page that was found offline prints `offline_line` once, as a command does. Exit code 0. |
## | `fetch` | `Fetch.packages!` for each line of `fx/runs` (slice 003). The line is `fetch [offline] [env:<NAME>=<value>]... <url>...` (one `env_all!` call at the start, the `env:` words are added to the environment, as for `index`). The roots are in the case dir (`home/.cache/roc`), the `roc` program is `roc`. It prints `== <line>`, then one line for each URL: `<url>: present`, `<url>: fetched`, or `<url>: exit <code>` with the failure line on stderr. Exit code 0. |
## | `resolve` | `Project.find!` and `Resolve.run!` for each line of `fx/runs` (slice 005). The line is `<install or update> [<name>...] [frozen] [no-check] [offline] [lowest] [dry-run] [platform] [no-pin] [yes] [quiet] [rename-keys] [allow-moves] [as=<alias>] [snapshot=<text>] [nightly=<true or false>] [compiler=<id>] [toolchain=<id>] [file=<path>] [now=<seconds>]`. The start dir is `project/`, the roots are in the case dir as for `fetch`. Before the first run it makes an empty `.git` directory in each dir that `fx/gitdirs` lists (as `project` does). It prints `== <line>`, the output of the run on stdout, `exit <code>` on stdout and the failure line on stderr. Exit code 0. |
## | `commands` | `Run.run!` (the whole command code) for each line of `fx/commands` (slice 007). The line is the words after `tln`. Before the first run it makes an empty `.git` directory in each dir that `fx/gitdirs` lists (as `project` does). For each line it writes the words to `fx/args`, prints `== <line>`, runs, and prints `exit <code>` (stdout). Use `{w}` in `fx/env` for the paths of the case (`HOME={w}/home`). Slice 023: a line that starts with `@roc` runs as the `roc` proxy (`fx/program` is `roc` for this run, the other words are the arguments of `roc`). A word `env:<NAME>=<value>` (before or after `@roc`, not an argument) sets the variable for this run only (it replaces a line of `fx/env` with the same name). |
## | `harness` | Calls each `Fx` function once. It tests the fake and the runner, not Talon. Exit code 3. |
main! = |args| {
	match args.map(|a| a.display()) {
		[w, entry] => {
			fx = FakeFx.make(w)
			code = match entry {
				"run" => Run.run!(fx)
				"prompt" => prompt_entry!(fx, w)
				"project" => project_entry!(fx, w)
				"locks" => locks_entry!(fx, w)
				"index" => index_entry!(fx, w)
				"fetch" => fetch_entry!(fx, w)
				"resolve" => resolve_entry!(fx, w)
				"commands" => commands_entry!(fx, w)
				"harness" => harness_entry!(fx)
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

harness_entry! : Fx => I32
harness_entry! = |fx| {
	cwd = fx.cwd!()
	tty = fx.tty!()
	fx.out!("env variables: ${fx.env_all!().len().to_str()}\n")
	fx.out!("tty: stdin=${Str.inspect(tty.stdin)} stderr=${Str.inspect(tty.stderr)}\n")
	fx.out!("clock: ${fx.clock!().to_str()}\n")
	fx.out!("args: ${Str.inspect(fx.args!())}\n")
	for result in fx.read_files!(["${cwd}/in.txt", "${cwd}/missing.txt"]) {
		fx.out!("read: ${Str.inspect(result)}\n")
	}
	match fx.write_atomic!([{ path: "${cwd}/out.txt", content: "written" }]) {
		Ok(_) => fx.out!("write: ok\n")
		Err(_) => fx.out!("write: failed\n")
	}
	fx.err!("stderr line\n")
	listed = fx.list_dirs!([cwd, "${cwd}/missing"]).map(|r| r.map_ok(|entries| entries.map(|e| "${e.name} ${Str.inspect(e.is_dir)}").sort_by(|n| n.count_utf8_bytes())))
	fx.out!("list_dirs: ${Str.inspect(listed)}\n")
	fx.out!("canonical: ${Str.inspect(fx.canonical!(["${cwd}/in.txt", "${cwd}/missing.txt"]))}\n")
	fx.out!("delete: ${Str.inspect(fx.delete!(["${cwd}/gone.txt", "${cwd}/missing.txt"]))}\n")
	match fx.lock!("${cwd}/item", NoWait) {
		Held(lock) => {
			fx.out!("lock: held\n")
			# R-CC3 point 5: this ask is under a lock. The fake logs a VIOLATION line before it.
			_ = fx.ask!("Under lock? ")
			fx.unlock!(lock)
		}
		Busy => fx.out!("lock: busy\n")
	}
	match fx.lock!("${cwd}/other", Wait) {
		Held(lock) => fx.unlock!(lock)
		Busy => fx.out!("lock: busy\n")
	}
	match fx.ask!("Name? ") {
		Ok(reply) => fx.out!("ask: ${reply}\n")
		Err(EndOfInput) => fx.out!("ask: end of input\n")
	}
	# Slice 003
	fx.out!("http_get: ${Str.inspect(fx.http_get!({ url: "https://api.example.com/x?page=2", headers: [("A", "1")] }))}\n")
	fx.out!("programs: ${Str.inspect(fx.programs!(["curl", "wget"]))}\n")
	fx.out!("spawn_all: ${Str.inspect(fx.spawn_all!({ jobs: [{ argv: ["tool", "a"], cwd: Err(Inherit) }, { argv: ["other"], cwd: Ok(cwd) }], limit: 8 }))}\n")
	fx.out!("rename: ${Str.inspect(fx.rename!({ from: "${cwd}/in.txt", to: "${cwd}/renamed.txt" }))}\n")
	fx.out!("rename refused: ${Str.inspect(fx.rename!({ from: "${cwd}/renamed.txt", to: "${cwd}/refused" }))}\n")
	fx.out!("make_dirs: ${Str.inspect(fx.make_dirs!(["${cwd}/new/deep"]))}\n")
	fx.out!("random: ${fx.random!().to_str()}\n")
	3
}

prompt_entry! : Fx, Str => I32
prompt_entry! = |fx, w| {
	env = Dict.from_list(fx.env_all!())
	text = match Path.read_utf8!(Path.utf8("${w}/fx/prompts")) {
		Ok(t) => t
		Err(_) => ""
	}
	specs = text.split_on("\n").keep_if(|l| !l.trim().is_empty())
	json = env.get("TEST_JSON") == Ok("1")
	mode = Mode.from_env({ env, json })
	match run_prompts!(fx, mode, specs) {
		Ok(_) => {
			# A command writes its result after its prompts. A stop writes nothing (R-NM5).
			_ = fx.write_atomic!([{ path: "${fx.cwd!()}/result.txt", content: "done\n" }])
			0
		}
		Err(fail) => {
			fx.err!("${fail.line()}\n")
			fail.kind.code()
		}
	}
}

run_prompts! : Fx, Mode, List(Str) => Try({}, Fail)
run_prompts! = |fx, mode, specs| match specs {
	[] => Ok({})
	[line, .. as rest] => {
		(facts, prompt) = parse_line(line)
		done = Prompt.ask!(fx, prompt, { mode, yes: facts.yes, quiet: facts.quiet, flag: facts.flag })?
		fx.out!("${prompt.id}: ${show(done.answer)}\n")
		run_prompts!(fx, done.mode, rest)
	}
}

show : Answer -> Str
show = |answer| match answer {
	Yes => "yes"
	No => "no"
	Option(n) => "option ${n.to_str()}"
}

parse_answer : Str -> Answer
parse_answer = |text| match text {
	"yes" => Yes
	"no" => No
	other => Option(U64.from_str(other) ?? 1)
}

## A line of `fx/prompts`: `<flags> | <spec>`.
## Flags: `--yes`, `--quiet`, `--answer=<yes|no|n>`.
## Spec: `id=<id> kind=<default|consent|required:<flag>,<flag>> shape=<yesno|options:<n>> default=<yes|no|n> question=<words> subject=<words>`. In `question` and `subject`, `_` is a space.
parse_line : Str -> ({ yes : Bool, quiet : Bool, flag : Try(Answer, [NoFlag]) }, Prompt)
parse_line = |line| {
	(flag_part, spec_part) = match line.split_on("|") {
		[a, b] => (a, b)
		_ => ("", line)
	}
	flags = words(flag_part)
	spec = words(spec_part).map(
		|w| match w.split_on("=") {
			[k, .. as v] => (k, Str.join_with(v, "="))
			[] => ("", "")
		},
	)
	field = |name| match spec.find_first(|(k, _)| k == name) {
		Ok((_, v)) => v
		Err(_) => ""
	}
	answer_flag = match flags.find_first(|f| f.starts_with("--answer=")) {
		Ok(f) => Ok(parse_answer(f.drop_prefix("--answer=")))
		Err(_) => Err(NoFlag)
	}
	id = field("id")
	kind_text = field("kind")
	prompt : Prompt
	prompt = {
		id,
		kind: if kind_text == "consent" Consent else if kind_text.starts_with("required:") Required(kind_text.drop_prefix("required:").split_on(",")) else Default,
		shape: if field("shape").starts_with("options:") Options(U64.from_str(field("shape").drop_prefix("options:")) ?? 1) else YesNo,
		default: parse_answer(field("default")),
		question: field("question").replace_each("_", " "),
		subject: field("subject").replace_each("_", " "),
		answer_line: |a| "answer ${id}: ${show(a)}",
	}
	(
		{ yes: flags.contains("--yes"), quiet: flags.contains("--quiet"), flag: answer_flag },
		prompt,
	)
}

words : Str -> List(Str)
words = |text| text.split_on(" ").keep_if(|w| !w.is_empty())

project_entry! : Fx, Str => I32
project_entry! = |fx, w| {
	root = "${w}/project"
	for dir in file_lines!("${w}/fx/gitdirs") {
		_ = Path.create_all!(Path.utf8("${root}/${dir}/.git"))
	}
	for line in file_lines!("${w}/fx/searches") {
		given = words(line).map(
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

file_lines! : Str => List(Str)
file_lines! = |path| match Path.read_utf8!(Path.utf8(path)) {
	Ok(text) => text.split_on("\n").keep_if(|l| !l.trim().is_empty())
	Err(_) => []
}

## Slice 003. See the table at the top for the entry.
index_entry! : Fx, Str => I32
index_entry! = |fx, w| {
	cache = "${w}/home/.cache/roc"
	roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
	base_env = fx.env_all!()
	for line in file_lines!("${w}/fx/runs") {
		given = words(line)
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
			["hint", name, tag, ..] => {
				(owner, repo) = split_name(name)
				match Github.hint!(fx, { net, owner, repo, tag }) {
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
	for line in file_lines!("${w}/fx/runs") {
		given = words(line)
		extra = given.keep_if(|word| word.starts_with("env:")).map(
			|word| match word.drop_prefix("env:").split_on("=") {
				[name, .. as value] => (name, Str.join_with(value, "="))
				[] => ("", "")
			},
		)
		fx.out!("== ${line}\n")
		urls = given.drop_first(1).keep_if(|word| word != "offline" and !word.starts_with("env:"))
		net = Net.from_env(base_env.concat(extra))
		results = Fetch.packages!(fx, { roots, urls, offline: given.contains("offline"), roc: "roc", downloader: net.downloader })
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
	for dir in file_lines!("${w}/fx/gitdirs") {
		_ = Path.create_all!(Path.utf8("${w}/project/${dir}/.git"))
	}
	base_env = match Path.read_utf8!(Path.utf8("${w}/fx/env")) {
		Ok(text) => text.trim_end()
		Err(_) => ""
	}
	for line in file_lines!("${w}/fx/commands").keep_if(|l| !l.starts_with("#")) {
		fx.out!("== ${line}\n")
		all = words(line)
		extra = all.keep_if(|word| word.starts_with("env:")).map(|word| word.drop_prefix("env:"))
		rest = all.keep_if(|word| !word.starts_with("env:"))
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

## Slice 005. See the table at the top for the entry.
resolve_entry! : Fx, Str => I32
resolve_entry! = |fx, w| {
	cache = "${w}/home/.cache/roc"
	roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
	for dir in file_lines!("${w}/fx/gitdirs") {
		_ = Path.create_all!(Path.utf8("${w}/project/${dir}/.git"))
	}
	env = fx.env_all!()
	net = Net.from_env(env)
	mode = Mode.from_env({ env: Dict.from_list(env), json: Bool.False })
	for line in file_lines!("${w}/fx/runs") {
		given = words(line)
		value = |name| given.find_first(|word| word.starts_with("${name}=")).map_ok(|word| word.drop_prefix("${name}="))
		fx.out!("== ${line}\n")
		command = if given.first() == Ok("update") Update else Install
		names = given.drop_first(1).keep_if(|word| !["compiler=", "toolchain=", "nightly=", "file=", "now=", "snapshot=", "as="].any(|key| word.starts_with(key)) and !["frozen", "no-check", "offline", "lowest", "dry-run", "platform", "no-pin", "yes", "quiet", "rename-keys", "allow-moves"].contains(word))
		file = match value("file") {
			Ok(f) => Ok(f)
			Err(_) => Err(Unset)
		}
		found = Project.find!(fx, { start: "${w}/project", file, home: "${w}/home" })
		result = match found {
			Err(fail) => Err(fail)
			Ok(project) => Resolve.run!(
				fx,
				{
					command,
					names,
					frozen: given.contains("frozen"),
					no_check: given.contains("no-check"),
					project,
					roots,
					net,
					now: U64.from_str(value("now") ?? "") ?? 1792065600,
					offline: given.contains("offline"),
					strategy: if given.contains("lowest") Ok(Lowest) else Err(Unset),
					nightly: match value("nightly") {
						Ok("true") => Ok(Bool.True)
						Ok("false") => Ok(Bool.False)
						_ => Err(Unset)
					},
					compiler: match value("compiler") {
						Ok(id) => Ok(id)
						Err(_) => Err(NoCompiler)
					},
					toolchain: match value("toolchain") {
						Ok(id) => Ok(id)
						Err(_) => Err(Unset)
					},
					snapshot: match value("snapshot") {
						Ok(text) => Ok(text)
						Err(_) => Err(Unset)
					},
					dry_run: given.contains("dry-run"),
					add: {
						as_platform: given.contains("platform"),
						as_alias: match value("as") {
							Ok(alias) => Ok(alias)
							Err(_) => Err(Unset)
						},
						no_pin: given.contains("no-pin"),
					},
					prompt: { mode, yes: given.contains("yes"), quiet: given.contains("quiet"), rename_keys: if given.contains("rename-keys") Ok(Yes) else Err(NoFlag), allow_moves: if given.contains("allow-moves") Ok(Yes) else Err(NoFlag) },
				},
			)
		}
		match result {
			Ok(_) => fx.out!("exit 0\n")
			Err(fail) => {
				fx.out!("exit ${fail.kind.code().to_str()}\n")
				fx.err!("${fail.line()}\n")
			}
		}
	}
	0
}
