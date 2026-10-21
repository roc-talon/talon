app [main!] {
	http: "https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
	lib: "lib/main.roc",
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
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
import lib.Roots
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
## | `hint <owner>/<repo> <tag>` | `Github.hint!` | `hint <text>` or `no hint` |
## | `fetch [--offline] <url>...` | `Fetch.packages!` with `roc` on `PATH` | `present <url>` or `fetched <url>` for each URL. A failure prints its line to stderr. The exit code is the lowest code of the failures (`Exit.choose`). |
## | In all | The roots come from `Roots.from_env`, the settings from `Net.from_env`, the real clock from `Fx.clock!` | |
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
		["hint", name, tag] => finish!(fx, hint!(fx, name, tag))
		["fetch", .. as rest] => fetch!(fx, rest)
		_ => {
			fx.err!("usage: flowprobe record <file>... | releases | hint | fetch\n")
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

hint! : Fx, Str, Str => Try({}, Fail)
hint! = |fx, name, tag| {
	net = Net.from_env(fx.env_all!())
	(owner, repo) = match name.split_on("/") {
		[o, r] => (o, r)
		_ => return Err(Fail.new(Usage, "hint needs <owner>/<repo>"))
	}
	match Github.hint!(fx, { net, owner, repo, tag })? {
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
	results = Fetch.packages!(fx, { roots, urls, offline: words.contains("--offline"), roc: "roc", downloader: Net.from_env(env).downloader })
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
