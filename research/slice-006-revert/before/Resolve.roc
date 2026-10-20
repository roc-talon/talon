import Add
import Fail
import Fetch
import Frozen
import Fx
import Github
import Guard
import Ident
import Index
import Intent
import Ladder
import Item
import Locked
import Lookup
import Net
import Pick
import Pin
import Project
import Ref
import Release
import Roots
import Scope
import Selector
import Text
import Vars
import semver.Semver

## The resolve flow of the P0 commands that resolve, in direct style over `Fx` (TESTING.md 2.2, part C). Slice 007 builds `install` and `update` on it
## (arguments, `--json`, `--dry-run`, `add`, `remove`, the probe ladder of slice 006). This slice tests it through the L2 entry `resolve`.
Resolve :: [].{

	## One run. `names` are the operands of `update` as typed (`json`, `json@^3`, `roc-lang/json`): `Ref.parse` and `Lookup.find` read them (slice 004).
	## `strategy` is `--strategy`. `nightly` is `TALON_NIGHTLY` (R-NS8). `compiler` is the id of the `roc` on `PATH` (R-PH8). `now` is `Clock.now`.
	Request : {
		command : [Install, Update],
		names : List(Str),
		frozen : Bool,
		no_check : Bool,
		project : Project,
		roots : Roots,
		net : Net.Settings,
		now : U64,
		offline : Bool,
		strategy : Try([Highest, Lowest], [Unset]),
		nightly : Try(Bool, [Unset]),
		compiler : Try(Str, [NoCompiler]),
	}

	## See the slice file 005, "The flow of `Resolve.run!`".
	run! : Fx, Request => Try({}, Fail)
	run! = |fx, request| {
		loaded = load!(fx, request)?
		built = Vars.build({ members: loaded.members, priority: loaded.intent.resolution.priority })?
		settings = settings_of(request, loaded.intent)
		decision = Pin.decide({
			members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: Bool.False }),
			compiler: request.compiler,
			req: loaded.intent.toolchain.roc,
			nightly: settings.nightly,
			no_check: request.no_check,
		})?
		if request.frozen {
			frozen!(fx, request, loaded, built, decision)
		} else {
			resolve!(fx, request, loaded, built, decision)
		}
	}
}

Fact : { url : Str, release : Release }

Loaded : {
	members : List(Vars.Member),
	headers : List({ path : Str, text : Str }),
	tomls : List({ path : Str, text : Str }),
	intent : Intent,
}

Settings : { nightly : Bool, strategy : [Highest, Lowest], min_age : U64 }

# One planned change of a header, with its line of output (R-OUT2: the texts are a proposal).
Edit : { file : Str, op : Locked.Op, line : Str }

Pair : { path : Str, key : Str, value : Str }

Candidates : { name : Str, list : List(Index.Candidate), missing : Bool }

Asked : { names : List(Str), picks : List({ alias : Str, selector : Selector }) }

# `--frozen` (R-LF1): the pure check, then the hash check of the packages of the header. No index call, no write.
frozen! : Fx, Resolve.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision => Try({}, Fail)
frozen! = |fx, request, loaded, built, decision| {
	settings = settings_of(request, loaded.intent)
	scoped = Vars.scope({ command: Install, names: [], selectors: [], vars: built.vars })?
	Frozen.check({ scoped, wants: built.wants, outside: decision.outside, req_text: loaded.intent.toolchain.roc_text, nightly: settings.nightly })?
	urls = built.vars.join_map(|v| v.uses.map(|u| u.url)).fold([], |found, url| if found.contains(url) found else found.append(url))
	_ = read_releases!(fx, request, urls, Bool.False)?
	fx.out!("the header satisfies talon.toml\n")
	Ok({})
}

# `install` and `update`: the steps of the flow in the slice file.
resolve! : Fx, Resolve.Request, Loaded, { vars : List(Vars.Var), wants : List(Vars.Want) }, Pin.Decision => Try({}, Fail)
resolve! = |fx, request, loaded, built, decision| {
	settings = settings_of(request, loaded.intent)
	check_pin(loaded.intent, settings, decision)?
	snapshot = Intent.direct_snapshot(loaded.intent.resolution.snapshot)?
	asked = asked!(fx, request, built.vars)?
	scoped = Vars.scope({
		command: request.command,
		names: asked.names,
		selectors: asked.picks.keep_oks(|p| range_of_selector(p.selector).map_ok(|range| { alias: p.alias, range })),
		vars: built.vars,
	})?
	for s in scoped {
		match s.note {
			Ok(note) => fx.out!("${note}\n")
			Err(None) => {}
		}
	}
	wants = live_wants!(fx, built.wants)?
	free_names = scoped.keep_if(|s| s.free).keep_oks(|s| s.variable.name.map_err(|_| None))
	want_names = wants.keep_oks(|w| w.name.map_err(|_| None))
	known = built.vars.join_map(|v| v.uses.map(|u| u.url))
	repos = free_names.concat(want_names).fold(no_names, |found, name| if found.contains(name) found else found.append(name))
	found = index!(fx, request, repos, known)?
	input = slots_of(scoped, wants, found, asked, settings, snapshot)
	chosen = pick_loop!(fx, request, input, [])?
	finish!(fx, request, loaded, scoped, wants, asked, chosen)
}

settings_of : Resolve.Request, Intent -> Settings
settings_of = |request, intent| {
	strategy = match request.strategy {
		Ok(s) => s
		Err(Unset) => intent.resolution.strategy ?? Highest
	}
	{
		nightly: match request.nightly {
			Ok(b) => b
			Err(Unset) => intent.toolchain.nightly ?? Bool.True
		},
		strategy,
		min_age: intent.resolution.min_release_age ?? 172800,
	}
}

# R-RP2, R-NS5, Q3: a pin that stops the command, and the missing compiler.
check_pin : Intent, Settings, Pin.Decision -> Try({}, Fail)
check_pin = |intent, settings, decision| match decision.outside {
	Ok(pin) => Err(Pin.outside_failure({ pin, req_text: intent.toolchain.roc_text, nightly: settings.nightly }))
	Err(None) => match decision.held {
		Ok(_) => Ok({})
		Err(NoCompiler) => Err(Fail.new(Environment, "cannot select a compiler: there is no roc on PATH that Talon can identify, and the header has no roc pin"))
	}
}

# Step A of the flow: the member files and the `talon.toml` candidates in one `read_files!` call (R-PD6).
load! : Fx, Resolve.Request => Try(Loaded, Fail)
load! = |fx, request| {
	files = member_files(request.project)?
	root = match request.project.workspace {
		Ok(ws) => ws.root
		Err(Standalone) => files.first().map_ok(|f| Text.dir_of(f)) ?? ""
	}
	candidates = files.map(|f| Intent.paths({ member: f, root }))
	toml_paths = candidates.join_map(|c| c).fold([], |found, path| if found.contains(path) found else found.append(path))
	results = fx.read_files!(files.concat(toml_paths))
	headers = files.map2(results.take_first(files.len()), |path, result| (path, result))
	toml_results = toml_paths.map2(results.drop_first(files.len()), |path, result| (path, result))
	var $texts = no_texts
	for (path, result) in headers {
		match result {
			Ok(text) => {
				$texts = $texts.append({ path, text })
			}
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
	}
	var $tomls = no_texts
	for (path, result) in toml_results {
		match result {
			Ok(text) => {
				$tomls = $tomls.append({ path, text })
			}
			Err(NotFound) => {}
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
	}
	root_toml = Text.join(root, "talon.toml")
	var $intents = no_intents
	for t in $tomls {
		role = match request.project.workspace {
			Ok(_) => if t.path == root_toml Root else Member
			Err(Standalone) => Root
		}
		read = Intent.read({ path: t.path, text: t.text, role })?
		for w in read.warnings {
			fx.err!("warning: ${w}\n")
		}
		$intents = $intents.append({ path: t.path, intent: read.intent })
	}
	members = files.map2(
		candidates,
		|file, paths| {
			locked = match $texts.find_first(|t| t.path == file) {
				Ok(t) => Locked.read({ path: file, text: t.text })
				Err(_) => Err(Fail.new(Environment, "cannot read ${file}"))
			}
			toml = match paths.find_first(|p| $intents.any(|i| i.path == p)) {
				Ok(p) => match $intents.find_first(|i| i.path == p) {
					Ok(i) => Ok({ path: i.path, intent: i.intent })
					Err(_) => Err(NoToml)
				}
				Err(_) => Err(NoToml)
			}
			(file, locked, toml)
		},
	)
	checked = members.map_try(|(file, locked, toml)| locked.map_ok(|l| { file, locked: l, toml }))?
	settings_path = match request.project.workspace {
		Ok(_) => root_toml
		Err(Standalone) => files.first().map_ok(|f| Text.join(Text.dir_of(f), "talon.toml")) ?? ""
	}
	intent = match $intents.find_first(|i| i.path == settings_path) {
		Ok(i) => i.intent
		Err(_) => empty_intent({})?
	}
	Ok({ members: checked, headers: $texts, tomls: $tomls, intent })
}

no_texts : List({ path : Str, text : Str })
no_texts = []

no_intents : List({ path : Str, intent : Intent })
no_intents = []

# The intent of a missing `talon.toml`: the read of the empty text.
empty_intent : {} -> Try(Intent, Fail)
empty_intent = |_| Intent.read({ path: "talon.toml", text: "", role: Root }).map_ok(|r| r.intent)

# R-PD5: the members of a workspace, or the current file of a standalone project.
member_files : Project -> Try(List(Str), Fail)
member_files = |project| match project.workspace {
	Ok(ws) => if ws.members.is_empty() Err(Fail.new(Usage, "the workspace at ${ws.root} has no member files")) else Ok(ws.members)
	Err(Standalone) => match project.file {
		Ok(file) => Ok([file])
		Err(NoCurrent) => Err(Fail.new(Usage, "no project file found. Pass --file <path>."))
	}
}

# The names of `update` as aliases (slice 004: `Ref.parse`, `Lookup.find`). `install` takes no names here (R-SP18).
asked! : Fx, Resolve.Request, List(Vars.Var) => Try(Asked, Fail)
asked! = |fx, request, vars| {
	entities = entities_of(vars)
	var $names = no_names
	var $picks = no_picks
	for text in (if request.command == Update request.names else []) {
		ref = Ref.parse(text, Scope.Project, Bool.False)?
		found = match Lookup.find(Scope.Project, ref, entities) {
			Ok(f) => f
			Err({ fail, block }) => {
				if !block.is_empty() fx.err!(block)
				return Err(fail)
			}
		}
		alias = match found {
			Lookup.Existing({ alias: a, .. }) => a
			Lookup.New(name) => return Err(Fail.new(Usage, "'${name}' is not in the project"))
		}
		$names = $names.append(alias)
		match ref.selector {
			Ok(selector) => {
				$picks = $picks.append({ alias, selector })
			}
			Err(None) => {}
		}
	}
	Ok({ names: $names, picks: $picks })
}

no_names : List(Str)
no_names = []

no_picks : List({ alias : Str, selector : Selector })
no_picks = []

# The entities of the lookup: one for each header alias, the name with its series when 2 variables share a repo (R-SC15).
entities_of : List(Vars.Var) -> List({ alias : Str, name : Str, note : Str })
entities_of = |vars| {
	base = |v| v.name ?? v.group.form
	vars.join_map(
		|v| {
			shared = vars.keep_if(|o| base(o) == base(v)).len() >= 2
			name = if shared "${base(v)}@${v.group.series}" else base(v)
			v.uses
				.map(|u| { alias: u.alias, name, note: if v.is_platform "platform (${u.alias})" else "" })
				.fold([], |found, e| if found.any(|f| f.alias == e.alias) found else found.append(e))
		},
	)
}

# R-SL5, R-AD22: the range that a selector gives to its variable. `Latest` is any version.
range_of_selector : Selector -> Try(Str, [None])
range_of_selector = |selector| match selector {
	Exact(version) => Ok("=${version}")
	Range(text) => Ok(text)
	Latest => Ok("*")
	_ => Err(None)
}

# R-I5, R-I8: a stale key is a warning, and a key with a short name has no index (R-AD6).
live_wants! : Fx, List(Vars.Want) => Try(List(Vars.Want), Fail)
live_wants! = |fx, wants| {
	var $live = no_wants
	for w in wants {
		match w.stale {
			Ok(alias) => fx.err!("warning: ${w.from}: the key \"${w.key}\" names ${w.name ?? w.key}, which the header has as \"${alias}\"\n")
			Err(None) => match w.name {
				Err(Short(text)) => return Err(short_failure(w.from, text))
				Ok(_) => {
					$live = $live.append(w)
				}
			}
		}
	}
	Ok($live)
}

no_wants : List(Vars.Want)
no_wants = []

short_failure : Str, Str -> Fail
short_failure = |from, text| match Ref.parse(text, Scope.Install, Bool.False) {
	Err(fail) => Fail.new(fail.kind, "${from}: ${fail.message}")
	Ok(ref) => match Lookup.find(Scope.Install, ref, []) {
		Err({ fail, .. }) => Fail.new(fail.kind, "${from}: ${fail.message}")
		Ok(_) => Fail.new(Usage, "${from}: '${text}' is a short name, and GitHub has no index of short names. Use the full name (owner/repo).")
	}
}

# The pages of each repo that a free variable or a want needs (R-SP1: a held variable needs no index call), as candidates (R-DI3 to R-DI5).
index! : Fx, Resolve.Request, List(Str), List(Str) => Try(List(Candidates), Fail)
index! = |fx, request, names, known| {
	var $found = no_candidates
	var $oldest = Err(None)
	for name in names {
		(owner, repo) = match name.split_on("/") {
			[o, r] => (o, r)
			_ => return Err(Fail.new(Usage, "'${name}' is not on github.com: an index of other hosts needs a registry (--registry)"))
		}
		fetched = Github.releases!(fx, { net: request.net, roots: request.roots, owner, repo, now: request.now, offline: request.offline })?
		match fetched.source {
			Cached(t) => {
				$oldest = match $oldest {
					Ok(old) if old <= t => Ok(old)
					_ => Ok(t)
				}
			}
			_ => {}
		}
		match Index.candidates({ owner, repo, pages: fetched.pages, known }) {
			Ok({ list, warnings }) => {
				for w in warnings {
					fx.err!("warning: ${w}\n")
				}
				$found = $found.append({ name, list, missing: fetched.source == Missing })
			}
			Err(BadPage(n)) => return Err(Fail.new(Network, "the release list of ${name} (page ${n.to_str()}) is not a list of releases"))
		}
	}
	match $oldest {
		Ok(t) => fx.err!("${Github.offline_line(t)}\n")
		Err(None) => {}
	}
	Ok($found)
}

no_candidates : List(Candidates)
no_candidates = []

PickInput : {
	slots : List(Pick.Slot),
	strategy : [Highest, Lowest],
	min_age : U64,
	snapshot : Try(U64, [None]),
	want_slots : List({ key : Str, name : Str, urls : List(Str) }),
}

# The slots of `Pick.step`: the variables in order, then the wants (R-VA6).
slots_of : List(Vars.Scoped), List(Vars.Want), List(Candidates), Asked, Settings, Try(U64, [None]) -> PickInput
slots_of = |scoped, wants, found, asked, settings, snapshot| {
	candidates_of = |name| match found.find_first(|c| c.name == name) {
		Ok(c) => c
		Err(_) => { name, list: [], missing: Bool.True }
	}
	var_slots = scoped.map(
		|s| {
			v = s.variable
			cands = match v.name {
				Ok(name) => {
					c = candidates_of(name)
					group = if s.any_series c.list.keep_if(|x| x.ident.group.form == v.group.form) else Index.in_group({ list: c.list, group: v.group })
					{ list: group, missing: c.missing }
				}
				Err(NoName) => { list: [], missing: Bool.True }
			}
			named = asked.picks.find_first(|p| v.uses.any(|u| u.alias == p.alias)) ?? { alias: "", selector: Latest }
			{
				id: match v.uses.first() {
					Ok(u) => u.alias
					Err(_) => ""
				},
				is_platform: v.is_platform,
				ranges: v.ranges.map(|r| r.range),
				current: highest_use(v.uses),
				free: s.free and !cands.missing,
				named: match named.selector {
					Exact(version) if s.any_series => Ok(version)
					_ => Err(None)
				},
				candidates: cands.list,
			}
		},
	)
	want_slots = wants.map(
		|w| {
			name = w.name ?? w.key
			list = match Index.new_entry({ name, list: candidates_of(name).list }) {
				Ok(entry) => entry.list
				Err(NoCandidate) => []
			}
			{ id: w.key, is_platform: Bool.False, ranges: [w.range], current: Err(None), free: Bool.True, named: Err(None), candidates: list }
		},
	)
	{
		slots: var_slots.concat(want_slots),
		strategy: settings.strategy,
		min_age: settings.min_age,
		snapshot,
		want_slots: wants.map2(want_slots, |w, slot| { key: w.key, name: w.name ?? w.key, urls: slot.candidates.map(|c| c.url) }),
	}
}

# The use with the highest version: its URL is the value that the header holds now (R-C9).
highest_use : List({ file : Str, alias : Str, url : Str, version : Str }) -> Try(Str, [None])
highest_use = |uses| match uses {
	[] => Err(None)
	[first, .. as rest] => Ok(
		rest.fold(
			first,
			|best, u| match (Semver.parse(u.version), Semver.parse(best.version)) {
				(Ok(a), Ok(b)) => if a.order_relative_to(b) == After u else best
				_ => best
			},
		).url,
	)
}

# Step G of the flow: `Pick.step` until `Done` or `Fail`. A `Need` fetches the packages and reads their headers (`Release.read`).
pick_loop! : Fx, Resolve.Request, PickInput, List(Fact) => Try(List(Pick.Chosen), Fail)
pick_loop! = |fx, request, input, facts| match Pick.step({ slots: input.slots, strategy: input.strategy, now: request.now, min_age: input.min_age, snapshot: input.snapshot, facts }) {
	Done(chosen) => Ok(chosen)
	Fail(fail) => Err(fail)
	Need(urls) => {
		more = read_releases!(fx, request, urls, Bool.True)?
		all = facts.concat(more)
		platform_wants(input.want_slots, all)?
		pick_loop!(fx, request, input, all)
	}
}

# Q2, R-AD33: a key of `talon.toml` whose release is a platform is not added as a package.
platform_wants : List({ key : Str, name : Str, urls : List(Str) }), List(Fact) -> Try({}, Fail)
platform_wants = |wants, facts| {
	found = wants.join_map(|w| facts.keep_if(|f| f.release.kind == Platform and w.urls.contains(f.url)).map(|f| (w, f.url)))
	match found {
		[] => Ok({})
		[(w, url), ..] => match Add.decide({ selector: Err(None), chosen: { name: w.name, url, kind: Platform }, platform_flag: Bool.False, no_pin: Bool.False, as_alias: Ok(w.key), header: [] }) {
			Err(fail) => Err(fail)
			Ok(_) => Ok({})
		}
	}
}

# Fetches the packages of the URLs (R-FE1, the hash check) and, with `read`, reads the header of each `main.roc` (R-DI7).
read_releases! : Fx, Resolve.Request, List(Str), Bool => Try(List(Fact), Fail)
read_releases! = |fx, request, urls, read| {
	results = Fetch.packages!(fx, { roots: request.roots, urls, offline: request.offline, roc: "roc", downloader: request.net.downloader })
	for result in results {
		match result {
			Ok(_) => {}
			Err(fail) => return Err(fail)
		}
	}
	if !read {
		Ok([])
	} else {
		paths = urls.map(|url| main_of(request.roots, url))
		texts = fx.read_files!(paths)
		var $facts = no_facts
		for (url, path, text) in urls.map2(paths.map2(texts, |p, t| (p, t)), |u, (p, t)| (u, p, t)) {
			body = match text {
				Ok(t) => t
				Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
			}
			release = Release.read({ path, text: body })?
			$facts = $facts.append({ url, release })
		}
		Ok($facts)
	}
}

no_facts : List(Fact)
no_facts = []

main_of : Roots, Str -> Str
main_of = |roots, url| match Ident.of_url(url) {
	Ok(ident) => "${Roots.item(roots, Item.Package(ident.hash))}/main.roc"
	Err(Foreign) => url
}

# Steps H to J: the plan, the second read, the check of R-CC7, one `write_atomic!` call and the output.
finish! : Fx, Resolve.Request, Loaded, List(Vars.Scoped), List(Vars.Want), Asked, List(Pick.Chosen) => Try({}, Fail)
finish! = |fx, request, loaded, scoped, wants, asked, chosen| {
	count = scoped.len()
	var_chosen = chosen.take_first(count)
	want_chosen = chosen.drop_first(count)
	for c in chosen {
		match c.note {
			Ok(note) => fx.out!("note: ${note}\n")
			Err(None) => {}
		}
	}
	sets = scoped.map2(var_chosen, |s, c| (s, c)).join_map(|(s, c)| set_edits(s, c))
	adds = wants.map2(want_chosen, |w, c| (w, c)).map_try(|(w, c)| add_edit(loaded.members, w, c))?
	changes = sets.concat(adds.join_map(|a| a))
	decision = Pin.decide({
		members: loaded.members.map(|m| { file: m.file, pin: m.locked.roc, changes: changes.any(|e| e.file == m.file) }),
		compiler: request.compiler,
		req: loaded.intent.toolchain.roc,
		nightly: settings_of(request, loaded.intent).nightly,
		no_check: request.no_check,
	})?
	edits = changes.concat(decision.writes.map(|w| { file: w.file, op: Pin(w.id), line: "+ roc: ${w.id}" }))
	pairs = pairs_of(loaded.members, scoped, asked)?
	if !changes.is_empty() {
		ladder!(fx, request, loaded, { scoped, wants, chosen, changes, decision })?
	}
	write!(fx, loaded, edits, pairs)
}

# Slice 006: the place of the probe ladder in the flow (Resolution 4, R-LD4, R-LD5, R-PH9, R-PH10): after the choice and before the write, when a header changes (R-AL6).
# A stub: the code agent writes the body. `facts.changes` are the planned changes of the headers (the pin write is not a change that makes the ladder run). `facts.decision` is the `Pin.decide` of `finish!`.
#
# | Case | What the body does |
# | --- | --- |
# | `request.no_check` (R-BL6, R-LF3) | No `Fx` call. Prints `check: skipped` (a proposal, TW24) and returns `Ok({})`. A pin is not written (`Pin.decide`, R-H6). |
# | Else | Builds `Ladder.run!` input: one `Ladder.Member` for each member file in `facts.changes` (its `kind` and its text from `loaded`, its `ops` from the changes and from the pin write of `facts.decision.writes`), the `Ladder.Owner` of each hash of the candidate header (the uses of `facts.scoped` and the chosen URLs, with `Vars` names), `moved` (the chosen values that move: `Pick.Chosen.change` is `Move` and the wants), `path_roc` is `request.compiler`, `held` is `facts.decision.held`, `roots` is `request.roots`. Calls `Ladder.run!` and returns its result. |
ladder! : Fx, Resolve.Request, Loaded, { scoped : List(Vars.Scoped), wants : List(Vars.Want), chosen : List(Pick.Chosen), changes : List(Edit), decision : Pin.Decision } => Try({}, Fail)
ladder! = |fx, request, loaded, facts| {
	if request.no_check {
		fx.out!("check: skipped\n")
		Ok({})
	} else {
		count = facts.scoped.len()
		var_rows = facts.scoped.map2(facts.chosen.take_first(count), |s, c| (s.variable.name ?? s.variable.group.form, s.variable.is_platform, c, is_move(c)))
		want_rows = facts.wants.map2(facts.chosen.drop_first(count), |w, c| (w.name ?? w.key, Bool.False, c, Bool.True))
		rows = var_rows.concat(want_rows).keep_oks(|(name, is_platform, c, moved)| owner_of(name, is_platform, c).map_ok(|owner| { owner, moved }))
		files = facts.changes.map(|e| e.file).fold(no_names, |found, file| if found.contains(file) found else found.append(file))
		Ladder.run!(
			fx,
			{
				roots: request.roots,
				path_roc: request.compiler,
				held: facts.decision.held ?? "",
				members: files.keep_oks(|file| ladder_member(loaded, facts.changes, facts.decision, file)),
				owners: rows.map(|r| r.owner),
				moved: rows.keep_if(|r| r.moved).map(|r| r.owner),
			},
		)
	}
}

is_move : Pick.Chosen -> Bool
is_move = |c| match c.change {
	Move(_) => Bool.True
	Keep => Bool.False
}

# The owner of the hash of a chosen URL (R-PH13: the blame names `<name> <version>`).
owner_of : Str, Bool, Pick.Chosen -> Try(Ladder.Owner, [Foreign])
owner_of = |name, is_platform, c| Ident.of_url(c.url).map_ok(|ident| { hash: ident.hash, name, version: c.version, is_platform })

# A member file with its header text and the edits for the candidate: the planned changes, and the pin that the command writes after the check (R-RP3).
ladder_member : Loaded, List(Edit), Pin.Decision, Str -> Try(Ladder.Member, [NoMember])
ladder_member = |loaded, changes, decision, file| match loaded.members.find_first(|m| m.file == file) {
	Ok(m) => Ok({
		file,
		kind: m.locked.kind,
		text: loaded_text(loaded, file),
		ops: changes.keep_if(|e| e.file == file).map(|e| e.op).concat(decision.writes.keep_if(|w| w.file == file).map(|w| Pin(w.id))),
	})
	Err(_) => Err(NoMember)
}

# R-H1: a header entry moves to the URL that was chosen, for each use of the variable.
set_edits : Vars.Scoped, Pick.Chosen -> List(Edit)
set_edits = |s, c| s.variable.uses
	.keep_if(|u| u.url != c.url)
	.map(|u| { file: u.file, op: Set({ alias: u.alias, url: c.url }), line: "~ ${u.alias}: ${s.variable.name ?? s.variable.group.form} ${u.version} -> ${c.version}" })

# R-I5, R-I6: a key that no header has is added to the header of the one member under its `talon.toml` (the decision of `tln add`).
add_edit : List(Vars.Member), Vars.Want, Pick.Chosen -> Try(List(Edit), Fail)
add_edit = |members, w, c| match w.members {
	[file, ..] => {
		rows = match members.find_first(|m| m.file == file) {
			Ok(m) => m.locked.rows.map(|r| { alias: r.alias, url: r.value, is_platform: r.is_platform })
			Err(_) => []
		}
		name = w.name ?? w.key
		plan = Add.decide({ selector: Err(None), chosen: { name, url: c.url, kind: Package }, platform_flag: Bool.False, no_pin: Bool.False, as_alias: Ok(w.key), header: rows })?
		match plan.header {
			Insert => Ok([{ file, op: Add({ alias: plan.alias, url: c.url, is_platform: Bool.False }), line: "+ ${plan.alias}: ${name} ${c.version}" }])
			_ => Ok([])
		}
	}
	[] => Ok([])
}

# R-AD22, R-AD26, D10: the `talon.toml` key of an alias that `update X@sel` names, in the nearest `talon.toml` of its first use. Q1: a new file next to the member.
pairs_of : List(Vars.Member), List(Vars.Scoped), Asked -> Try(List(Pair), Fail)
pairs_of = |members, scoped, asked| asked.picks
	.keep_oks(
		|p| match scoped.find_first(|s| s.free and s.variable.uses.any(|u| u.alias == p.alias)) {
			Ok(s) => match s.variable.uses.find_first(|u| u.alias == p.alias) {
				Ok(u) => Ok((p, s, u))
				Err(_) => Err(NoPair)
			}
			Err(_) => Err(NoPair)
		},
	)
	.map_try(
		|(p, s, u)| {
			plan = Add.decide_alias({ alias: p.alias, selector: Ok(p.selector), no_pin: Bool.False, header: [{ alias: u.alias, url: u.url, is_platform: s.variable.is_platform }] })?
			path = match members.find_first(|m| m.file == u.file) {
				Ok({ toml: Ok(t), .. }) => t.path
				_ => Text.join(Text.dir_of(u.file), "talon.toml")
			}
			match plan.toml {
				Ok({ key, value }) => Ok([{ path, key, value }])
				Err(Nothing) => Ok([])
			}
		},
	)
	.map_ok(|lists| lists.join_map(|l| l))

# The second read, the check of R-CC7 and the write. Talon first, in the order of `Guard.check_all`.
write! : Fx, Loaded, List(Edit), List(Pair) => Try({}, Fail)
write! = |fx, loaded, edits, pairs| {
	header_files = loaded.members.keep_if(|m| edits.any(|e| e.file == m.file)).map(|m| m.file)
	toml_files = pairs.map(|p| p.path).fold([], |found, path| if found.contains(path) found else found.append(path))
	paths = header_files.concat(toml_files)
	if paths.is_empty() {
		fx.out!("nothing to change\n")
		return Ok({})
	}
	now_texts = paths.map2(fx.read_files!(paths), |path, result| (path, result))
	var $files = no_files
	var $edited = no_edited
	for (path, result) in now_texts {
		is_header = header_files.contains(path)
		read = loaded_text(loaded, path)
		now = match result {
			Ok(text) => text
			Err(NotFound) => if is_header return Err(Fail.new(Environment, "cannot read ${path}")) else ""
			Err(_) => return Err(Fail.new(Environment, "cannot read ${path}"))
		}
		ops = edits.keep_if(|e| e.file == path).map(|e| e.op)
		keys = pairs.keep_if(|p| p.path == path).map(|p| p.key)
		writes = pairs.keep_if(|p| p.path == path).map(|p| { key: p.key, value: p.value })
		spans_read = if is_header Locked.spans({ text: read, ops }) else Intent.spans({ text: read, keys })
		spans_now = if is_header Locked.spans({ text: now, ops }) else Intent.spans({ text: now, keys })
		new = if is_header Locked.edit({ path, text: now, ops })? else Intent.apply({ path, text: now, writes })?
		$files = $files.append({ path, read, now, spans_read, spans_now })
		$edited = $edited.append({ path, now, new })
	}
	ordered = Guard.check_all($files)?
	changed = ordered.keep_oks(|o| $edited.find_first(|e| e.path == o.path)).keep_if(|e| e.new != e.now)
	if changed.is_empty() {
		fx.out!("nothing to change\n")
		return Ok({})
	}
	match fx.write_atomic!(changed.map(|e| { path: e.path, content: e.new })) {
		Ok(_) => {}
		Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
	}
	for path in header_files {
		if changed.any(|e| e.path == path) {
			fx.out!("${path}\n")
			for e in edits.keep_if(|e| e.file == path) {
				fx.out!("  ${e.line}\n")
			}
		}
	}
	for p in pairs {
		if changed.any(|e| e.path == p.path) {
			fx.out!("${p.path}: ${p.key} = \"${p.value}\"\n")
		}
	}
	Ok({})
}

no_files : List({ path : Str, read : Str, now : Str, spans_read : List(Str), spans_now : List(Str) })
no_files = []

no_edited : List({ path : Str, now : Str, new : Str })
no_edited = []

# The text that the first read gave (`""` for a `talon.toml` that was not there).
loaded_text : Loaded, Str -> Str
loaded_text = |loaded, path| match loaded.headers.find_first(|t| t.path == path) {
	Ok(t) => t.text
	Err(_) => match loaded.tomls.find_first(|t| t.path == path) {
		Ok(t) => t.text
		Err(_) => ""
	}
}
