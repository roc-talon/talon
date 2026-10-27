import Compiler
import Download
import Fail
import Fx
import Ident
import Item
import Launch
import NoRank
import OnPath
import Pin
import Roots
import Temp
import Text

## The package store and fetch (CLI 7.1, R-FE1 to R-FE10, R-DA4, R-DA7, R-HF4, R-HF5, R-CC11). The pure decisions are `plan` and
## the two failure texts. `packages!` is command code over `Fx` (TESTING.md 2.2, part C).
Fetch :: [].{

	## What `plan` decides for one URL. All paths are absolute.
	##
	## | Field | Value |
	## | --- | --- |
	## | `url` | The URL as given |
	## | `hash` | The hash of the URL (`Ident.of_url`) |
	## | `what` | The text that names the package in a message: `<owner>/<repo> <version>` for a GitHub release URL, else the URL form with the version in place of `{v}`, without the scheme and without the `/` at the end (question Q7) |
	## | `item` | `<pkgs>/<hash>` (`Roots.item`, `Item.Package`) |
	## | `temp` | `<pkgs>/<hash>.<hex>.tmp` (R-FE3, R-CC1) |
	## | `archive` | `<temp>/<hash>.tar.zst` (R-DA4: the temp file is in the target dir) |
	## | `extracted` | `<temp>/<hash>`: where `roc unbundle <hash>.tar.zst`, run in `temp`, puts the files (`research/roc-unbundle/`) |
	Plan : { url : Str, hash : Str, what : Str, item : Str, temp : Str, archive : Str, extracted : Str }

	## The plan for one URL. `hex` is 16 hex digits (`Temp.hex(Fx.random!())`, TW2). The URL must pass `Download.check_url`, and it must
	## have a hash and one version (`Ident.of_url`). A URL that does not is a failure of kind `Usage` (the text of `check_url`; for
	## a URL with no hash or no single version: `<url> is not a package release URL`, question Q8).
	plan : { roots : Roots, url : Str, hex : Str } -> Try(Plan, Fail)
	plan = |facts| {
		Download.check_url(facts.url)?
		ident = match Ident.of_url(facts.url) {
			Ok(found) => found
			Err(Foreign) => return Err(Fail.new(Usage, "${facts.url} is not a package release URL"))
		}
		temp = Text.join(facts.roots.pkgs, "${ident.hash}.${facts.hex}.tmp")
		Ok({
			url: facts.url,
			hash: ident.hash,
			what: name_of(ident),
			item: Roots.item(facts.roots, Item.Package(ident.hash)),
			temp,
			archive: "${temp}/${ident.hash}.tar.zst",
			extracted: "${temp}/${ident.hash}",
		})
	}

	## R-FE4: how `packages!` gets the program for `roc unbundle`. `Program` is a program that the command has already chosen. `Choose` makes `packages!` choose it (`Fetch.unbundler`), after the downloads, and only when a download ended with `Done`.
	## `selected` is the compiler that the run selects (Resolution 13), `""` for none (slice 060, question Q1). Slice 072b (R-SO14, R-LF1): `none` is what to do when no compiler is installed and none is on `PATH` (`Fetch.unbundler` gives `Err(NoCompiler)`):
	## `Stop` is the failure `Compiler.failure(NoCompiler)` (exit code 18: the flows of slice 072c), `Download` is `NoRank.ensure!` (the download and the default), then `Launch.program!` with the id and the installed list of its result.
	Unbundler : [Program(Str), Choose({ selected : Str, none : NoRank.Fallback })]

	## R-FE4, R-NS6 (slice 060, moved from `ProbeCmd.unbundler`, slice 037): the compiler that runs `roc unbundle`, as an id. The format of an archive does not depend on the nightly, so the rows, first match wins.
	## Only a nightly or a release counts as installed for row 2 (R-NS6: `git-`, `link-` and `copy-` builds are selected only by name). The newest is by `Pin.order` with no times: the day of the tag, then the tag text.
	##
	## | # | Case | Id |
	## | --- | --- | --- |
	## | 1 | `selected` is in `installed` (any kind of id) | `selected` |
	## | 2 | `installed` has a nightly or a release | the newest one |
	## | 3 | `path` is `Ok` | the id of the `roc` on `PATH` (rank 7) |
	## | 4 | none | `Err(NoCompiler)`: `program_of!` applies `none` of `Choose` (R-SO14, slice 072b: R-DL2, a required download) |
	##
	## `selected` is `""` when the run selects no compiler. The program of the id is `Launch.program!` (a `link-` build reads its `.talon.json`, R-LK4).
	unbundler : { selected : Str, installed : List(Str), path : Try({ id : Str, path : Str }, [NoCompiler]) } -> Try(Str, [NoCompiler])
	unbundler = |x| {
		newest = x.installed.keep_if(Pin.is_id).sort_with(|a, b| Pin.order({ a, b, times: [] })).last()
		if x.installed.contains(x.selected) {
			Ok(x.selected)
		} else {
			match (newest, x.path) {
				(Ok(id), _) => Ok(id)
				(Err(_), Ok(found)) => Ok(found.id)
				(Err(_), Err(NoCompiler)) => Err(NoCompiler)
			}
		}
	}

	## R-FE4, Resolution 13 (slice 060, question Q1): the compiler that a fetch calls "selected". `held` is the compiler that the command holds (`Pin.Decision.held`), `""` when the flow has no decision. `default` is `default-roc` of `config.toml`
	## (rank 6), `""` when it is not set or the flow does not know it. The held compiler wins. Else the default. Else `""`: no selected compiler.
	selected : { held : Str, default : Str } -> Str
	selected = |x| if x.held.is_empty() x.default else x.held

	## The failure of a download that ended with an error (R-DA7, R-FE6, R-FE10). `outcome` is `Download.outcome`. In P0 there is
	## no mirror (R-FE6), so an HTTP error answer is a failure of kind `Network` (exit 15):
	##
	## | Outcome | Text |
	## | --- | --- |
	## | `Http(Ok(status))` | `download of <what> failed: <status> (<url>). Run tln audit to see why.` (R-FE10, the text of the design) |
	## | `Http(Err(Unknown))` | `download of <what> failed: HTTP error (<url>). Run tln audit to see why.` (question Q3) |
	## | `Failed` | `download of <what> failed: <last line> (<url>)`. With an empty last line: `<program> exited with code <n>` in its place (`<program> was stopped by signal <n>` for a signal). `NotStarted(text)`: kind `Environment` (exit 18), `cannot run <program>: <text>` (R-HF12). |
	download_failed : { plan : Plan, program : Download.Program, ended : Download.Ended, outcome : [Http(Try(U16, [Unknown])), Failed], last_line : Str } -> Fail
	download_failed = |facts| {
		program = program_name(facts.program)
		p = facts.plan
		match (facts.outcome, facts.ended) {
			(Http(Ok(status)), _) => Fail.new(Network, "download of ${p.what} failed: ${status.to_str()} (${p.url}). Run tln audit to see why.")
			(Http(Err(Unknown)), _) => Fail.new(Network, "download of ${p.what} failed: HTTP error (${p.url}). Run tln audit to see why.")
			(Failed, NotStarted(text)) => Fail.new(Environment, "cannot run ${program}: ${text}")
			(Failed, ended) => {
				why = if facts.last_line.is_empty() ended_text(program, ended) else facts.last_line
				Fail.new(Network, "download of ${p.what} failed: ${why} (${p.url})")
			}
		}
	}

	## The failure of `roc unbundle` (R-FE2): kind `Integrity` (exit 16), `roc unbundle rejected <what> (<url>): <last line>`. The last
	## line is the last line of the stderr of roc, and `exit code <n>` when it is empty. `NotStarted(text)` is kind `Environment` (exit 18),
	## `cannot run roc: <text>` (R-HF12).
	unbundle_failed : { plan : Plan, ended : Download.Ended, last_line : Str } -> Fail
	unbundle_failed = |facts| match facts.ended {
		NotStarted(text) => Fail.new(Environment, "cannot run roc: ${text}")
		ended => {
			why = if facts.last_line.is_empty() {
				match ended {
					Exited(code) => "exit code ${code.to_str()}"
					_ => ended_text("roc", ended)
				}
			} else {
				facts.last_line
			}
			Fail.new(Integrity, "roc unbundle rejected ${facts.plan.what} (${facts.plan.url}): ${why}")
		}
	}

	## The failure of an offline run for a package that is not in the cache (R-FE7): kind `Network` (exit 15),
	## `<what> is not in the package cache and --offline is set (<url>)` (question Q9).
	offline_missing : Plan -> Fail
	offline_missing = |p| Fail.new(Network, "${p.what} is not in the package cache and --offline is set (${p.url})")

	## Fetches the packages of the URLs into `<pkgs>/<hash>/` (R-FE1 to R-FE3). The result has one entry for each URL, in the order
	## of the list: `Present` (the item was there, no call but the listing), `Fetched` (this call put it there, also when another
	## process won the rename: R-FE3, R-CC11). `unbundler` gives the program for `roc unbundle` (R-FE4, slice 060). `downloader` is `Settings.downloader` of `Net` (R-EV12).
	##
	## The calls, in order (the L2 case `fetch/fe-flow` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | One `random!` call. For each URL: `plan` with `hex: Temp.hex(<the number>)`, the same `hex` for all URLs (the hashes make the temp names differ). A failure of `plan` is the result of that URL, and the URL goes no further. |
	## | 2 | One `list_dirs!` of `<pkgs>`. A URL whose `<hash>` is a directory there is `Present`. A missing `<pkgs>` is an empty list. |
	## | 3 | The URLs that are left, with `offline`: each is `offline_missing`, and nothing else runs. |
	## | 4 | One `programs!(["curl", "wget"])`, then `Download.choose` with `want: downloader`. A failure is the result of each URL that is left. |
	## | 5 | For each URL that is left: `make_dirs!` of `temp` (one call). Then one `spawn_all!` with `limit: 8` (R-DA5) and one job for each URL: `Download.command` with `dest: archive`, `cwd: Err(Inherit)`. |
	## | 6 | Only when a download ended with `Done` (a run with no download, or with all downloads failed, makes none of the calls of this row). The program (`program_of!`, R-FE4, slice 060): `Program(p)` is `p`, no call. `Choose`: one `list_dirs!` of `<cache>/toolchains` (`Launch.toolchains!`), then `OnPath.file!` (the calls of slice 022b) only when the list has no nightly or release, then `Fetch.unbundler` (the id), then `Launch.program!` (a `link-` id: one `read_files!` of its `.talon.json`). `Err(NoCompiler)` is `Compiler.failure(NoCompiler)` (kind `Environment`, exit 18) for each URL that was downloaded: nothing is spawned, step 8 still deletes the temp dirs. Then one `spawn_all!` with `limit: 8` and one job for each URL that was downloaded: `[<program>, "unbundle", "<hash>.tar.zst"]` with `cwd: Ok(temp)`. `Exited(0)` is a success. Slice 072b (R-SO14): when `Fetch.unbundler` gives `Err(NoCompiler)` and `none` is `Download`, the calls of `NoRank.ensure!` come after the calls above, then `Launch.program!` (no call for a nightly id) with the id of its result. |
	## | 7 | For each unbundled URL: `rename!({ from: extracted, to: item })`. `Ok` is `Fetched`. `Err(Exists)` is `Fetched`: another process won, Talon drops its copy (R-FE3). Any other error is a failure of kind `Environment`, `cannot move <extracted> to <item>: <err>`. |
	## | 8 | One `delete!` of the `temp` of each URL that got a `temp` (success or failure, question Q10). |
	##
	## An index page or a package needs no lock (R-CC11). There is no `ask!`. A failed URL does not stop the others.
	packages! : Fx, { roots : Roots, urls : List(Str), offline : Bool, unbundler : Fetch.Unbundler, downloader : [Auto, Curl, Wget, Bad(Str)] } => List(Try([Present, Fetched], Fail))
	packages! = |fx, facts| {
		hex = Temp.hex(fx.random!())
		listing = match fx.list_dirs!([facts.roots.pkgs]) {
			[Ok(entries)] => entries
			_ => []
		}
		start = facts.urls.map(|url| start_state(Fetch.plan({ roots: facts.roots, url, hex }), listing, facts.offline))
		done = if pending_plans(start).is_empty() start else run!(fx, facts, start)
		done.map(final_result)
	}
}

# The state of one URL while `packages!` runs. `Pending` has the plan of a URL that still needs work.
State : [Failed(Fail), Present, Fetched, Pending(Fetch.Plan)]

program_name : Download.Program -> Str
program_name = |program| match program {
	Curl => "curl"
	Wget => "wget"
}

# `<owner>/<repo> <version>` for GitHub, else the URL form with the version, no scheme, no `/` at the end (Q7).
name_of : Ident -> Str
name_of = |ident| match ident.name {
	Ok(name) => "${name} ${ident.version}"
	Err(NoName) => ident.group.form.replace_each("{v}", ident.version).drop_suffix("/")
}

ended_text : Str, Download.Ended -> Str
ended_text = |program, ended| match ended {
	Exited(code) => "${program} exited with code ${code.to_str()}"
	Signaled(code) => "${program} was stopped by signal ${code.to_str()}"
	NotStarted(text) => "cannot run ${program}: ${text}"
}

start_state : Try(Fetch.Plan, Fail), List({ name : Str, is_dir : Bool, mtime : U64 }), Bool -> State
start_state = |planned, listing, offline| match planned {
	Err(fail) => Failed(fail)
	Ok(p) =>
		if listing.any(|e| e.is_dir and e.name == p.hash) {
			Present
		} else if offline {
			Failed(Fetch.offline_missing(p))
		} else {
			Pending(p)
		}
}

final_result : State -> Try([Present, Fetched], Fail)
final_result = |state| match state {
	Failed(fail) => Err(fail)
	Present => Ok(Present)
	Fetched => Ok(Fetched)
	Pending(_) => Ok(Fetched)
}

pending_plans : List(State) -> List(Fetch.Plan)
pending_plans = |states| states.keep_oks(
	|state| match state {
		Pending(p) => Ok(p)
		_ => Err(NotPending)
	},
)

# The new state of each `Pending` entry, in order. The other entries stay.
fill : List(State), List(State) -> List(State)
fill = |states, news| states.fold(
	{ out: [], rest: news },
	|acc, state| match state {
		Pending(_) => match acc.rest {
			[next, .. as later] => { out: acc.out.append(next), rest: later }
			[] => { out: acc.out.append(state), rest: [] }
		}
		_ => { out: acc.out.append(state), rest: acc.rest }
	},
).out

fail_pending : List(State), Fail -> List(State)
fail_pending = |states, fail| states.map(
	|state| match state {
		Pending(_) => Failed(fail)
		_ => state
	},
)

# Steps 4 to 8 of `packages!`: the program, the temp dirs, the downloads, the unbundles, the renames, the cleanup.
run! : Fx, { roots : Roots, urls : List(Str), offline : Bool, unbundler : Fetch.Unbundler, downloader : [Auto, Curl, Wget, Bad(Str)] }, List(State) => List(State)
run! = |fx, facts, states| {
	found = match fx.programs!(["curl", "wget"]) {
		[curl, wget] => { curl, wget }
		_ => { curl: Bool.False, wget: Bool.False }
	}
	match Download.choose({ want: facts.downloader, curl: found.curl, wget: found.wget }) {
		Err(fail) => fail_pending(states, fail)
		Ok(program) => {
			plans = pending_plans(states)
			result = match fx.make_dirs!(plans.map(|p| p.temp)) {
				Err(err) => fail_pending(states, Fail.new(Environment, "cannot make the temp dirs in ${facts.roots.pkgs}: ${Str.inspect(err)}"))
				Ok(_) => states |> download!(fx, program, plans) |> unbundle!(fx, { roots: facts.roots, unbundler: facts.unbundler }) |> rename!(fx)
			}
			_ = fx.delete!(plans.map(|p| p.temp))
			result
		}
	}
}

# Step 5: one `spawn_all!` with a job for each pending URL.
download! : List(State), Fx, Download.Program, List(Fetch.Plan) => List(State)
download! = |states, fx, program, plans| {
	jobs = plans.map(|p| { argv: Download.command({ program, url: p.url, dest: p.archive }), cwd: Err(Inherit) })
	results = fx.spawn_all!({ jobs, limit: 8 })
	news = plans.map2(
		results,
		|p, r| match Download.outcome({ program, ended: r.ended, last_line: r.stderr_last }) {
			Done => Pending(p)
			Http(status) => Failed(Fetch.download_failed({ plan: p, program, ended: r.ended, outcome: Http(status), last_line: r.stderr_last }))
			Failed => Failed(Fetch.download_failed({ plan: p, program, ended: r.ended, outcome: Failed, last_line: r.stderr_last }))
		},
	)
	fill(states, news)
}

# Step 6: the program (`Choose`: `Launch.toolchains!`, and only with no installed nightly or release `OnPath.file!`), then one `spawn_all!` with `roc unbundle` for each URL that was downloaded.
unbundle! : List(State), Fx, { roots : Roots, unbundler : Fetch.Unbundler } => List(State)
unbundle! = |states, fx, facts| {
	plans = pending_plans(states)
	if plans.is_empty() {
		states
	} else {
		match program_of!(fx, facts) {
			Err(fail) => fail_pending(states, fail)
			Ok(roc) => {
				jobs = plans.map(|p| { argv: [roc, "unbundle", "${p.hash}.tar.zst"], cwd: Ok(p.temp) })
				results = fx.spawn_all!({ jobs, limit: 8 })
				news = plans.map2(
					results,
					|p, r| match r.ended {
						Exited(0) => Pending(p)
						ended => Failed(Fetch.unbundle_failed({ plan: p, ended, last_line: r.stderr_last }))
					},
				)
				fill(states, news)
			}
		}
	}
}

# R-FE4 (slice 060): the program for `roc unbundle`. `Program` is the program as it is. `Choose` lists the installed compilers, looks at `PATH` only when no nightly or release is installed,
# chooses the id (`Fetch.unbundler`) and gives its program (`Launch.program!`: a `link-` id reads its `.talon.json`).
program_of! : Fx, { roots : Roots, unbundler : Fetch.Unbundler } => Try(Str, Fail)
program_of! = |fx, facts| match facts.unbundler {
	Program(roc) => Ok(roc)
	Choose({ selected, none }) => {
		installed = Launch.toolchains!(fx, facts.roots)
		path = if installed.any(Pin.is_id) Err(NoCompiler) else OnPath.file!(fx, facts.roots)
		match Fetch.unbundler({ selected, installed, path }) {
			Ok(id) => Launch.program!(fx, { roots: facts.roots, id, installed, path })
			Err(NoCompiler) => match none {
				Stop => Err(Compiler.failure(NoCompiler))
				Download(run) => {
					got = NoRank.ensure!(fx, { roots: facts.roots, run, listed: installed })?
					Launch.program!(fx, { roots: facts.roots, id: got.id, installed: got.installed, path })
				}
			}
		}
	}
}

# Step 7: the unbundled dir goes to `<pkgs>/<hash>`. `Exists`: another process won, and its copy is as good (R-FE3).
rename! : List(State), Fx => List(State)
rename! = |states, fx| {
	var $news = []
	for p in pending_plans(states) {
		moved = match fx.rename!({ from: p.extracted, to: p.item }) {
			Ok(_) => Fetched
			Err(Exists) => Fetched
			Err(err) => Failed(Fail.new(Environment, "cannot move ${p.extracted} to ${p.item}: ${Str.inspect(err)}"))
		}
		$news = $news.append(moved)
	}
	fill(states, $news)
}
