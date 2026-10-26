app [main!] {
	http: "https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
	lib: "lib/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0/GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t.tar.zst",
}

import lib.Clock
import lib.Fail
import lib.Exit
import lib.Fetch
import lib.Fx
import lib.Github
import lib.Index
import lib.Known
import lib.Net
import lib.Nightlies
import lib.Roots
import lib.ZigInstall
import RealFx

## A test tool, not part of `tln` (slice 002). It runs one Talon flow with the real `Fx`, so that an L3 case can check
## the flow on real files (TESTING.md 3). It is the stand-in for the P0 commands, which slice 007 builds.
## `flowprobe record <file>...`: `Known.record!` for the project files, with the roots from the environment
## (`Roots.from_env`) and the time of `Clock.now` (`TALON_NOW`, R-EV22). Prints `recorded <n>` on success. A failure prints
## its line (`Fail.line`) to stderr and exits with the code of its kind.
##
## Slice 003 adds three flows (the stand-ins of the commands that use the index and the store):
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `releases [--offline] [--known <url>]... <owner>/<repo>` | `Github.releases!`, then `Index.candidates` | stderr: `index: cached at <time>` (offline, from the cache), `warning: <text>` for each warning. stdout: `candidate <version> <published_at> <size> <url>` for each candidate, in the order of the pages, or `no cached page` (offline, no page 1). |
## | `hint [--offline] <owner>/<repo> <tag>` | `Github.hint!` (slice 068: it keeps the answer in `talon/index/github/<owner>/<repo>/<tag>.roc-version`, R-DI8) | `hint <text>` or `no hint` |
## | `fetch [--offline] <url>...` | `Fetch.packages!` with `roc` on `PATH` | `present <url>` or `fetched <url>` for each URL. A failure prints its line to stderr. The exit code is the lowest code of the failures (`Exit.choose`). |
## | In all | The roots come from `Roots.from_env`, the settings from `Net.from_env`, the real clock from `Fx.clock!` | |
##
## Slice 020 adds two flows (the stand-ins of `tln roc install`, `tln roc use` and the like, slice 021 and later). Both read the list of `roc-lang/nightlies`
## with `Nightlies.list!`. Options: `--offline`, `--host <target>` (an asset target of R-CV8, default `linux_x86_64`), `--min-age <seconds>` (default 0),
## `--snapshot <RFC 3339 time>` (default none). The time of the age is `TALON_NOW` (`Clock.now`), else the real clock.
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `nightlies [options]` | `Nightlies.list!`, then `Nightlies.visible` | stderr: `index: cached at <time>` (offline, from the cache). stdout: for each visible nightly in the order of R-NS1: `nightly <id> <published_at> <size> <sha256 or none> <url>`, or `nightly <id> <published_at> no asset`, or `nightly <id> <published_at> <n> assets`. `no cached page` (offline, no page 1). |
## | `compiler [options] [--base <id>] <text>` | `Nightlies.list!`, then `Nightlies.pick`. `named` is the id of each candidate on the host (`Nightlies.candidates`). `auto` is the visible candidates (the base is kept: R-C9). | `compiler <id>`, or the failure line on stderr and the exit code of its kind |
## Slice 044 adds one flow (the stand-in of `tln roc install --git`, slice 045, for its Zig step):
##
## | Call | Does | Prints |
## | --- | --- | --- |
## | `zig [--yes] [--quiet] [--offline] [--llvm <target>:<size>] <need>` | `ZigInstall.ensure!` with the environment of the process (`ZIG`, `TALON_ZIG_INDEX`, `CI`, ...). `<need>` is the text of `minimum_zig_version`. `--llvm` gives the LLVM line of the dependency list (`<size>` is a number of bytes or `?`, default `x86_64-linux-musl:45000000`). | stderr: the dependency list, the answer line, the wait line. stdout: `zig <version> <how> <path>` (`how` is `found-env`, `found-path`, `found-installed`, `installed` or `present`). A failure prints its line to stderr and exits with the code of its kind. |
main! = |args| {
	fx = RealFx.make!(args.map(|a| a.display()))
	match fx.args!() {
		["record", .. as files] => match record!(fx, files) {
			Ok({}) => {
				fx.out!("recorded ${files.len().to_str()}\n")
				Ok({})
			}
			Err(fail) => {
				fx.err!("${fail.line()}\n")
				Err(Exit(fail.kind.code()))
			}
		}
		["releases", .. as rest] => finish!(fx, releases!(fx, rest))
		["hint", .. as rest] => finish!(fx, hint!(fx, rest))
		["fetch", .. as rest] => fetch!(fx, rest)
		["nightlies", .. as rest] => finish!(fx, nightlies!(fx, rest))
		["compiler", .. as rest] => finish!(fx, compiler!(fx, rest))
		["zig", .. as rest] => finish!(fx, zig!(fx, rest))
		_ => {
			fx.err!("usage: flowprobe record <file>... | releases | hint | fetch | nightlies | compiler | zig\n")
			Err(Exit(99))
		}
	}
}

record! : Fx, List(Str) => Try({}, Fail)
record! = |fx, files| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	talon_now = match env.find_first(|(name, _)| name == "TALON_NOW") {
		Ok((_, text)) => Ok(text)
		Err(_) => Err(NotSet)
	}
	now = match Clock.now({ talon_now, real: fx.clock!() }) {
		Ok(t) => t
		Err(BadTime(text)) => return Err(Fail.new(Usage, "TALON_NOW is not a UTC time: ${text}"))
	}
	Known.record!(fx, { roots, files, now })
}

finish! : Fx, Try({}, Fail) => Try({}, [Exit(I32)])
finish! = |fx, result| match result {
	Ok({}) => Ok({})
	Err(fail) => {
		fx.err!("${fail.line()}\n")
		Err(Exit(fail.kind.code()))
	}
}

releases! : Fx, List(Str) => Try({}, Fail)
releases! = |fx, words| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	net = Net.from_env(env)
	known = known_urls(words)
	name = match words.keep_if(|w| !w.starts_with("--") and !known.contains(w)).last() {
		Ok(n) => n
		Err(_) => return Err(Fail.new(Usage, "releases needs <owner>/<repo>"))
	}
	(owner, repo) = match name.split_on("/") {
		[o, r] => (o, r)
		_ => return Err(Fail.new(Usage, "releases needs <owner>/<repo>"))
	}
	found = Github.releases!(fx, { net, roots, owner, repo, now: fx.clock!(), offline: words.contains("--offline") })?
	match found.source {
		Missing => fx.out!("no cached page\n")
		Cached(time) => {
			fx.err!("${Github.offline_line(time)}\n")
			show_candidates!(fx, owner, repo, found.pages, known)?
		}
		Live => show_candidates!(fx, owner, repo, found.pages, known)?
	}
	Ok({})
}

show_candidates! : Fx, Str, Str, List(Str), List(Str) => Try({}, Fail)
show_candidates! = |fx, owner, repo, pages, known| {
	found = match Index.candidates({ owner, repo, pages, known }) {
		Ok(f) => f
		Err(BadPage(n)) => return Err(Fail.new(Network, "page ${n.to_str()} of ${owner}/${repo} is not a release list"))
	}
	for warning in found.warnings {
		fx.err!("warning: ${warning}\n")
	}
	for c in found.list {
		fx.out!("candidate ${c.ident.version} ${Clock.format_utc(c.published_at)} ${c.size.to_str()} ${c.url}\n")
	}
	Ok({})
}

## The values after `--known`.
known_urls : List(Str) -> List(Str)
known_urls = |words| words.map2(words.drop_first(1), |a, b| (a, b)).keep_if(|(a, _)| a == "--known").map(|(_, b)| b)

hint! : Fx, List(Str) => Try({}, Fail)
hint! = |fx, words| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	net = Net.from_env(env)
	(name, tag) = match words.keep_if(|w| w != "--offline") {
		[n, t] => (n, t)
		_ => return Err(Fail.new(Usage, "hint needs <owner>/<repo> <tag>"))
	}
	(owner, repo) = match name.split_on("/") {
		[o, r] => (o, r)
		_ => return Err(Fail.new(Usage, "hint needs <owner>/<repo>"))
	}
	match Github.hint!(fx, { net, roots, owner, repo, tag, offline: words.contains("--offline") })? {
		Ok(text) => fx.out!("hint ${text}\n")
		Err(NoHint) => fx.out!("no hint\n")
	}
	Ok({})
}

fetch! : Fx, List(Str) => Try({}, [Exit(I32)])
fetch! = |fx, words| {
	env = fx.env_all!()
	roots = match Roots.from_env(env) {
		Ok(r) => r
		Err(fail) => return finish!(fx, Err(fail))
	}
	urls = words.keep_if(|w| w != "--offline")
	results = Fetch.packages!(fx, { roots, urls, offline: words.contains("--offline"), unbundler: Choose({ selected: "", none: Stop }), downloader: Net.from_env(env).downloader })
	var $failures = []
	for (url, result) in urls.map2(results, |u, r| (u, r)) {
		match result {
			Ok(Present) => fx.out!("present ${url}\n")
			Ok(Fetched) => fx.out!("fetched ${url}\n")
			Err(fail) => {
				fx.err!("${fail.line()}\n")
				$failures = $failures.append(fail)
			}
		}
	}
	code = Exit.choose({ failures: $failures, child: Err(NoChild) })
	if code == 0 Ok({}) else Err(Exit(code))
}

## The value after an option (`--host linux_x86_64`).
option_of : List(Str), Str -> Try(Str, [NotSet])
option_of = |words, name| match words.map2(words.drop_first(1), |a, b| (a, b)).find_first(|(a, _)| a == name) {
	Ok((_, value)) => Ok(value)
	Err(_) => Err(NotSet)
}

## The words that are no option and no value of an option.
plain_words : List(Str) -> List(Str)
plain_words = |words| {
	values = ["--host", "--min-age", "--snapshot", "--base"].keep_oks(|name| option_of(words, name))
	words.keep_if(|w| !w.starts_with("--") and !values.contains(w))
}

Listing : { releases : List(Nightlies.Release), source : [Live, Cached(U64), Missing], visible : List(Nightlies.Release) }

## The list of `roc-lang/nightlies` and the visible part of it, for the options of a flow.
listing! : Fx, List(Str) => Try(Listing, Fail)
listing! = |fx, words| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	net = Net.from_env(env)
	target = option_of(words, "--host") ?? "linux_x86_64"
	host = match [LinuxX64, LinuxArm64, MacosApple, MacosX64, WindowsX64, WindowsArm64].find_first(|h| Nightlies.target(h) == target) {
		Ok(h) => h
		Err(_) => return Err(Fail.new(Usage, "no such host: ${target}"))
	}
	talon_now = match env.find_first(|(name, _)| name == "TALON_NOW") {
		Ok((_, text)) => Ok(text)
		Err(_) => Err(NotSet)
	}
	now = match Clock.now({ talon_now, real: fx.clock!() }) {
		Ok(t) => t
		Err(BadTime(text)) => return Err(Fail.new(Usage, "TALON_NOW is not a UTC time: ${text}"))
	}
	min_age = match option_of(words, "--min-age") {
		Ok(text) => U64.from_str(text) ?? 0
		Err(NotSet) => 0
	}
	snapshot = match option_of(words, "--snapshot") {
		Ok(text) => match Clock.parse_utc(text) {
			Ok(t) => Ok(t)
			Err(BadTime) => return Err(Fail.new(Usage, "--snapshot is not a UTC time: ${text}"))
		}
		Err(NotSet) => Err(None)
	}
	keep = match option_of(words, "--base") {
		Ok(base) => [base]
		Err(NotSet) => []
	}
	found = Nightlies.list!(fx, { net, roots, now: fx.clock!(), offline: words.contains("--offline"), host })?
	Ok({ releases: found.releases, source: found.source, visible: Nightlies.visible({ list: found.releases, now, min_age, snapshot, keep }) })
}

nightlies! : Fx, List(Str) => Try({}, Fail)
nightlies! = |fx, words| {
	found = listing!(fx, words)?
	match found.source {
		Missing => fx.out!("no cached page\n")
		Cached(time) => {
			fx.err!("${Github.offline_line(time)}\n")
			show_nightlies!(fx, found.visible)
		}
		Live => show_nightlies!(fx, found.visible)
	}
	Ok({})
}

show_nightlies! : Fx, List(Nightlies.Release) => {}
show_nightlies! = |fx, list| {
	for r in list {
		head = "nightly ${r.id} ${Clock.format_utc(r.published_at)}"
		match r.asset {
			Ok(asset) => fx.out!("${head} ${asset.size.to_str()} ${asset.sha256 ?? "none"} ${asset.url}\n")
			Err(NoAsset) => fx.out!("${head} no asset\n")
			Err(Several(n)) => fx.out!("${head} ${n.to_str()} assets\n")
		}
	}
}

compiler! : Fx, List(Str) => Try({}, Fail)
compiler! = |fx, words| {
	text = match plain_words(words).last() {
		Ok(t) => t
		Err(_) => return Err(Fail.new(Usage, "compiler needs a text"))
	}
	found = listing!(fx, words)?
	base = match option_of(words, "--base") {
		Ok(id) => Ok(id)
		Err(NotSet) => Err(None)
	}
	named = Nightlies.candidates(found.releases).map(|r| r.id)
	auto = Nightlies.candidates(found.visible).map(|r| r.id)
	match Nightlies.pick({ text, named, auto, base }) {
		Ok(id) => fx.out!("compiler ${id}\n")
		Err(error) => return Err(Nightlies.failure(error))
	}
	Ok({})
}

zig! : Fx, List(Str) => Try({}, Fail)
zig! = |fx, words| {
	llvm_text = option_of(words, "--llvm") ?? "x86_64-linux-musl:45000000"
	llvm = match llvm_text.split_last(":") {
		Ok(parts) => { target: parts.before, size: U64.from_str(parts.after).map_err(|_| Unknown) }
		Err(_) => { target: llvm_text, size: Err(Unknown) }
	}
	need = match words.keep_if(|w| !w.starts_with("--") and w != llvm_text).last() {
		Ok(t) => t
		Err(_) => return Err(Fail.new(Usage, "zig needs the text of minimum_zig_version"))
	}
	done = ZigInstall.ensure!(
		fx,
		{ need, env: fx.env_all!(), yes: words.contains("--yes"), quiet: words.contains("--quiet"), json: Bool.False, offline: words.contains("--offline"), llvm },
	)?
	how = match done.how {
		Found(Env) => "found-env"
		Found(Path) => "found-path"
		Found(Installed) => "found-installed"
		Installed => "installed"
		Present => "present"
	}
	fx.out!("zig ${done.version} ${how} ${done.path}\n")
	Ok({})
}
