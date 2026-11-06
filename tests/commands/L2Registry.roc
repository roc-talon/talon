import lib.ClosureIndex
import lib.ClosureRequest
import lib.Gather
import lib.LogSnapshot
import lib.Help
import lib.Lookup
import lib.Mode
import lib.Net
import lib.Nightlies
import lib.PickIndex
import lib.PickLoop
import lib.PrivacyGuard
import lib.RegistryCache
import lib.RegistryToolchains
import lib.Report
import lib.ResolveBase
import lib.Ref
import lib.Scope
import lib.ShortNames
import lib.UnknownValues
import lib.Roots
import lib.Fx
import lib.FullName
import lib.Selector
import L2Util

## The entry `registry` of the L2 test app (slices 202 and 203). Each line of `fx/runs` is one run. The registry is `http://127.0.0.1:9` (its routes are `fx/http/127.0.0.1%3A9/...`). The roots are in the case dir (`home/.cache/roc`).
## One `env_all!` call at the start. A word `env:<NAME>=<value>` is added to the environment of that run (as for `index`).
##
## | Line | Runs | Prints |
## | --- | --- | --- |
## | `get <path> [now=<s>] [offline] [newest] [bookmark=<b>]` | `RegistryCache.get!` for the path and the query (`/v1/...`). `now` is the real clock (default 1792065600). | `status: <n>`, `source: live` or `source: copy <mtime>`, `body: <text>`. Or `no copy`. Or `exit <code>` and the failure line on stderr. |
## | `guard <source>... [offline] [frozen]` | `PrivacyGuard.check!`. A source is `repo:<owner>/<repo>`, `group:<text>`, `url:<text>` or `short:<name>`. | `ok`, or `exit <code>` and the failure line on stderr. |
## | `toolchains [offline] [log=<n>] [origin=<url>]` | `RegistryToolchains.list!` (slice 204), then `RegistryToolchains.visible` with `log=<n>`. `origin` is the registry of the run (default `http://127.0.0.1:9`: the routes are `fx/http/<host>/v1/toolchains?after=<n>`). | `source: live`, `source: cached <mtime>` or `source: missing`, then one line `row <log_index> <tag> <target> <asset_name> <sha256> <published_at> <size>` for each visible row. Or `exit <code>` and the failure line on stderr. |
## | `nightlies <target> [offline] [log=<n>] [origin=<url>]` | `Nightlies.list_registry!` (slice 204) for the host with the asset target `<target>` (`linux_x86_64`, `linux_arm64`, `macos_apple_silicon`, `macos_x86_64`, `windows_x86_64`, `windows_arm64`). | `source: ...` as above, then for each release `nightly <id> <published_at> <size> <sha256 or none> <url>`, or `nightly <id> <published_at> no asset`, then `changed <tag>` for each changed tag and `dropped <id>` for each dropped release. Or `exit <code>` and the failure line. |
## | `short <scope> <name>... [alias:<alias>]... [offline] [log=<n>] [origin=<url>]` | Slice 211. The scope is `install`, `tool` or `x`. Each name is parsed with `Ref.parse`. A name for which `Lookup.needs_registry` is true (the entities are one entity for each `alias:` word, with the full name `own/<alias>`) goes in the one `ShortNames.lookup!` (the clock is 1792065600). Then `Lookup.registry` for each of those names, in order. | For each name: `<name>: use <full name>` and, with a matched line, that line, or the block of the failure on stderr, `exit <code>` on stdout and the failure line on stderr. A name with no search: `<name>: no search`. A failure of `lookup!`: `exit <code>` and the line. |
## | `shorts <scope> <name>... [alias:<alias>]... [offline] [log=<n>] [origin=<url>]` | Slice 204b (Design Q223). As `short`, but the results of all asked names go in one `Lookup.registry_all`. | `no search` lines as for `short`. With no failing name, for each name: `use <full name>[@<selector>]` (the `ref` that goes on: the full name and the selector of the typed ref, as `Selector` text) and the matched line. A failure of `registry_all`: the block on stderr, `exit <code>` on stdout and the failure line on stderr, and no `use` line. A failure of `lookup!`: `exit <code>` and the line. |
## | `closure <word>...` | Slice 206. `ClosureIndex.query!` (origin `http://127.0.0.1:9`, the route `fx/http/127.0.0.1%3A9/v1/closure.POST`) with the groups of the words `group=<form>` or `group=<form>@<series>` (no range), the entries of the words `entry=<alias>=<url>` and the window `Held(<id>)` for `held=<id>`, `Free` with an empty list for `free-empty`, else `None`. With the answer as the index (`Answer`), in this order: `name=<owner/repo>` (all in one `PickIndex.index!`), `read=<url>` (all in one `ResolveBase.read_releases!`), `gather=<id>` (all in one `Gather.facts!`), `hint=<url>` (all in one `PickLoop.hints!`, the pairs with the nightly `n`), `checked=<name>` (`ClosureIndex.checked_of`), `walk` (`ResolveBase.closure!` of `<w>/project/main.roc` with the entries). | `log_size <n>`, `releases <n>`, `artifacts <n>`, `unknown <text>` for each, then `candidate <name> <version> <tag or -> <published_at> <size> <url>` (and `missing <name>` for a missing list), `fact <url> <kind> deps=<url,...>`, `record <id> <kind> deps=<url,...> targets=<name,...>` or `text <id> <path>`, `hint <id> <compiler>`, `checked <name> <checked_at or null> <stale>` or `checked <name> none`, `row <alias> <id> <version>` for each row of the walk. A failure: `exit <code>` and the line on stderr. |
## | `closure ... snapshot=<n> resolved then-group=<form>[@<series>] name2=<owner/repo>` | Slice 207. `snapshot=<n>`: `LogSnapshot.hide_above` on the answer before the index and the `releases` count with `keep` = the `hashes` of the first request (Q403; the lines `log_size`, `artifacts` and `unknown` show what the snapshot leaves, Q405). `then-group=` passes `keep` and `user` = the N of `snapshot=` (Q404). `resolved`: prints `Report.resolved_line` with `LogSnapshot.at_text(LogSnapshot.printed(..))` and 0 probes. `then-group=`: after the other words, `LogSnapshot.second!` (the route `closure.POST.2`) with the groups of these words and the `compilers` of the first request, `first` is the first answer. | `second log_size <n>`, `second releases <n>`, `second candidate <name> <version> <tag or -> <published_at> <size> <url>` for each `name2=`. A failure of the second query: `exit <code>` and the line. |
## | `settle entry=<url>... [snapshot-log]` | Slice 208 (R-AP28). `ClosureIndex.query!` (origin `http://127.0.0.1:9`, no groups, no window, the `hashes` of the entry URLs) as the first query. Then `UnknownValues.settle!` with `urls` = the entries, `snapshot` = the word `snapshot-log` (`--snapshot log:N`), the roots of the run. | `value <hash> <end>` for each value in the order of `UnknownValues.classify`: `end` is `indexed`, `archive`, `label` or `label other=<hash>`. Then `log_size <n>`, `releases <n>` and `unknown <text>` for each of the answer that `settle!` gives (the second one when it sent one). A failure: `exit <code>` and the line on stderr. The warnings of `settle!` are on stderr. |
## | `fullname <owner/repo> [sel=<text>] [log=<n>] [offline]` | Slice 212 (R-AD35 to R-AD37). `FullName.read!` with the registry `http://127.0.0.1:9`, the name, the selector `Selector.parse` of the text of `sel=` (no `sel=`: none), `--snapshot log:<n>` for `log=<n>`, no known URL, the clock 1792065600. The GitHub API is `https://api.github.com` unless the word `env:TALON_GITHUB_API=<url>` is given. | `releases <n>`, then `release <version> <hash>` for each release of the answer, in order. Or `no match` (the selector keeps no candidate), or `source build`. Or `exit <code>` and the failure line on stderr. |
## | `offline <word>...` | Slice 206 (R-IX6). `PickIndex.index!` with `--offline` and the index `Offline(http://127.0.0.1:9)` for the names of the words `name=<owner/repo>` and the known URLs of the words `known=<url>`, the clock 1792065600. Then `PickLoop.hints!` with the same index for the words `hint=<url>`. | `candidate ...` and `missing <name>` as for `closure`, then `missing-group <name> <form>` for each group of the name with no copy (Design Q391: `ResolveBase.Candidates.missing_forms`), then `hint ...`. The line `index: cached at <time>` is on stderr. A failure: `exit <code>` and the line. |
L2Registry :: [].{

	entry! : Fx, Str => I32
	entry! = |fx, w| {
		cache = "${w}/home/.cache/roc"
		roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
		base_env = fx.env_all!()
		for line in L2Util.file_lines!("${w}/fx/runs").keep_if(|l| !l.starts_with("#")) {
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
				["get", path, .. as rest] => {
					now = match rest.find_first(|word| word.starts_with("now=")) {
						Ok(word) => U64.from_str(word.drop_prefix("now=")) ?? 0
						Err(_) => 1792065600
					}
					bookmark = match rest.find_first(|word| word.starts_with("bookmark=")) {
						Ok(word) => Ok(word.drop_prefix("bookmark="))
						Err(_) => Err(None)
					}
					facts = { roots, origin: "http://127.0.0.1:9", version: Help.version, path, now, offline: rest.contains("offline"), newest: rest.contains("newest"), bookmark }
					match RegistryCache.get!(fx, facts) {
						Ok(Answer(answer)) => {
							fx.out!("status: ${answer.status.to_str()}\n")
							match answer.source {
								Live => fx.out!("source: live\n")
								Copy(t) => fx.out!("source: copy ${t.to_str()}\n")
							}
							fx.out!("body: ${answer.body}\n")
						}
						Ok(NoCopy) => fx.out!("no copy\n")
						Err(fail) => L2Util.report!(fx, fail)
					}
				}
				["guard", .. as rest] => {
					sources = rest.keep_oks(
						|word| match word.split_first(":") {
							Ok({ before: "repo", after }) => Ok(Repo(after))
							Ok({ before: "group", after }) => Ok(Group(after))
							Ok({ before: "url", after }) => Ok(Url(after))
							Ok({ before: "short", after }) => Ok(Short(after))
							_ => Err(NotSource)
						},
					)
					match PrivacyGuard.check!(fx, { net, roots, sources, offline: rest.contains("offline"), frozen: rest.contains("frozen") }) {
						Ok({}) => fx.out!("ok\n")
						Err(fail) => L2Util.report!(fx, fail)
					}
				}
				["toolchains", .. as rest] => {
					origin = origin_of(rest)
					log = log_of(rest)
					match RegistryToolchains.list!(fx, { roots, origin, version: Help.version, offline: rest.contains("offline") }) {
						Ok(got) => {
							fx.out!("source: ${source_text(got.source)}\n")
							for row in RegistryToolchains.visible({ rows: got.rows, log }) {
								fx.out!("row ${row.log_index.to_str()} ${row.tag} ${row.target} ${row.asset_name} ${row.sha256} ${row.published_at.to_str()} ${row.size.to_str()}\n")
							}
						}
						Err(fail) => L2Util.report!(fx, fail)
					}
				}
				["nightlies", target, .. as rest] => {
					hosts = [LinuxX64, LinuxArm64, MacosApple, MacosX64, WindowsX64, WindowsArm64]
					match hosts.find_first(|h| Nightlies.target(h) == target) {
						Err(_) => fx.out!("bad host\n")
						Ok(host) => match Nightlies.list_registry!(fx, { roots, origin: origin_of(rest), version: Help.version, offline: rest.contains("offline"), host, log: log_of(rest) }) {
							Ok(got) => {
								fx.out!("source: ${source_text(got.source)}\n")
								for r in got.releases {
									match r.asset {
										Ok(a) => {
											sha = match a.sha256 {
												Ok(s) => s
												Err(None) => "none"
											}
											fx.out!("nightly ${r.id} ${r.published_at.to_str()} ${a.size.to_str()} ${sha} ${a.url}\n")
										}
										Err(NoAsset) => fx.out!("nightly ${r.id} ${r.published_at.to_str()} no asset\n")
										Err(Several(n)) => fx.out!("nightly ${r.id} ${r.published_at.to_str()} ${n.to_str()} assets\n")
									}
								}
								for c in got.changed {
									fx.out!("changed ${c.now.tag}\n")
								}
								for d in got.dropped {
									fx.out!("dropped ${d.id}\n")
								}
							}
							Err(fail) => L2Util.report!(fx, fail)
						}
					}
				}
				["short", scope_word, .. as rest] => {
					scope = match scope_word {
						"tool" => Tool
						"x" => X
						_ => Install
					}
					entities = rest.keep_if(|word| word.starts_with("alias:")).map(|word| { alias: word.drop_prefix("alias:"), name: "own/${word.drop_prefix("alias:")}", series: "1", version: Ok("1.0.0"), note: "direct" })
					names = rest.keep_if(|word| !word.starts_with("alias:") and !word.starts_with("log=") and !word.starts_with("origin=") and word != "offline")
					refs = names.keep_oks(|name| Ref.parse(name, scope, Bool.False))
					asked = refs.keep_if(|r| Lookup.needs_registry(scope, r, entities))
					for r in refs.keep_if(|r| !Lookup.needs_registry(scope, r, entities)) {
						fx.out!("${r.name}: no search\n")
					}
					facts = { roots, origin: origin_of(rest), version: Help.version, now: 1792065600, offline: rest.contains("offline"), snapshot: log_of(rest), shorts: asked.map(|r| r.name) }
					match ShortNames.lookup!(fx, facts) {
						Err(fail) => L2Util.report!(fx, fail)
						Ok(found) => {
							for (r, f) in asked.map2(found, |r, f| (r, f)) {
								match Lookup.registry(scope, r, f) {
									Ok(done) => {
										match done.lookup {
											New(n) => fx.out!("${r.name}: use ${n}\n")
											Existing(e) => fx.out!("${r.name}: existing ${e.name}\n")
										}
										match done.matched {
											Ok(text) => fx.out!("${text}\n")
											Err(None) => {}
										}
									}
									Err(e) => {
										fx.err!(e.block)
										L2Util.report!(fx, e.fail)
									}
								}
							}
						}
					}
				}
				["shorts", scope_word, .. as rest] => {
					scope = match scope_word {
						"tool" => Tool
						"x" => X
						_ => Install
					}
					entities = rest.keep_if(|word| word.starts_with("alias:")).map(|word| { alias: word.drop_prefix("alias:"), name: "own/${word.drop_prefix("alias:")}", series: "1", version: Ok("1.0.0"), note: "direct" })
					names = rest.keep_if(|word| !word.starts_with("alias:") and !word.starts_with("log=") and !word.starts_with("origin=") and word != "offline")
					refs = names.keep_oks(|name| Ref.parse(name, scope, Bool.False))
					asked = refs.keep_if(|r| Lookup.needs_registry(scope, r, entities))
					for r in refs.keep_if(|r| !Lookup.needs_registry(scope, r, entities)) {
						fx.out!("${r.name}: no search\n")
					}
					facts = { roots, origin: origin_of(rest), version: Help.version, now: 1792065600, offline: rest.contains("offline"), snapshot: log_of(rest), shorts: asked.map(|r| r.name) }
					match ShortNames.lookup!(fx, facts) {
						Err(fail) => L2Util.report!(fx, fail)
						Ok(found) => match Lookup.registry_all(scope, asked.map2(found, |r, f| { ref: r, found: f })) {
							Ok(done) => {
								for d in done {
									sel = match d.ref.selector {
										Ok(Range(text)) => "@${text}"
										Ok(Exact(text)) => "@${text}"
										Ok(Latest) => "@latest"
										Ok(_) => "@?"
										Err(None) => ""
									}
									fx.out!("use ${d.ref.name}${sel}\n")
									match d.matched {
										Ok(text) => fx.out!("${text}\n")
										Err(None) => {}
									}
								}
							}
							Err(e) => {
								fx.err!(e.block)
								L2Util.report!(fx, e.fail)
							}
						}
					}
				}
				["closure", .. as rest] => {
					origin = "http://127.0.0.1:9"
					groups = rest.keep_oks(
						|word| if word.starts_with("group=") {
							text = word.drop_prefix("group=")
							match text.split_first("@") {
								Ok({ before, after }) => Ok({ group: before, series: Ok(after), range: Err(None) })
								Err(_) => Ok({ group: text, series: Err(None), range: Err(None) })
							}
						} else {
							Err(NotGroup)
						},
					)
					entries = rest.keep_oks(
						|word| if word.starts_with("entry=") {
							match word.drop_prefix("entry=").split_first("=") {
								Ok({ before, after }) => Ok({ alias: before, value: after, is_platform: Bool.False })
								Err(_) => Err(NotEntry)
							}
						} else {
							Err(NotEntry)
						},
					)
					window = match rest.find_first(|word| word.starts_with("held=")) {
						Ok(word) => Held(word.drop_prefix("held="))
						Err(_) => if rest.contains("free-empty") Free({ rows: [], nightly: Bool.True, req: Err(Unset), now: 1792065600, min_age: 0, exclude: [], snapshot: None }) else None
					}
					facts = { groups, entries: entries.map(|e| e.value), window }
					match ClosureIndex.query!(fx, { origin, version: Help.version, facts }) {
						Err(fail) => L2Util.report!(fx, fail)
						Ok(first) => {
							snapshot = snapshot_of(rest)
							keep = match ClosureRequest.request(facts) {
								Ok(r) => r.hashes
								Err(NoCompiler) => []
							}
							answer = match snapshot {
								Ok(n) => LogSnapshot.hide_above(first, { n, keep })
								Err(None) => first
							}
							fx.out!("log_size ${answer.log_size.to_str()}\n")
							fx.out!("releases ${answer.releases.len().to_str()}\n")
							fx.out!("artifacts ${answer.artifacts.len().to_str()}\n")
							for u in answer.unknown {
								fx.out!("unknown ${u}\n")
							}
							if rest.contains("resolved") {
								fx.out!("${Report.resolved_line({ at: LogSnapshot.at_text(LogSnapshot.printed({ snapshot, first })), log: Ok(LogSnapshot.printed({ snapshot, first })), probes: 0 })}\n")
							}
							request = request_of(w, roots, net, Answer({ origin, answer }), Bool.False)
							after_query!(fx, w, request, rest, entries, Answer({ origin, answer }))
							then = rest.keep_oks(
								|word| if word.starts_with("then-group=") {
									text = word.drop_prefix("then-group=")
									match text.split_first("@") {
										Ok({ before, after }) => Ok({ group: before, series: Ok(after), range: Err(None) })
										Err(_) => Ok({ group: text, series: Err(None), range: Err(None) })
									}
								} else {
									Err(NotGroup)
								},
							)
							if !then.is_empty() {
								compilers = match ClosureRequest.request(facts) {
									Ok(r) => r.compilers
									Err(NoCompiler) => Err(None)
								}
								match LogSnapshot.second!(fx, { origin, version: Help.version, first, compilers, groups: then, keep, user: snapshot }) {
									Err(fail) => L2Util.report!(fx, fail)
									Ok(second) => {
										fx.out!("second log_size ${second.log_size.to_str()}\n")
										fx.out!("second releases ${second.releases.len().to_str()}\n")
										for word in rest.keep_if(|word| word.starts_with("name2=")) {
											name = word.drop_prefix("name2=")
											for x in ClosureIndex.candidates({ releases: second.releases, artifacts: second.artifacts, name }) {
												tag = if x.tag.is_empty() "-" else x.tag
												fx.out!("second candidate ${name} ${x.ident.version} ${tag} ${x.published_at.to_str()} ${x.size.to_str()} ${x.url}\n")
											}
										}
									}
								}
							}
						}
					}
				}
				["settle", .. as rest] => {
					origin = "http://127.0.0.1:9"
					entries = rest.keep_oks(|word| if word.starts_with("entry=") Ok(word.drop_prefix("entry=")) else Err(NotEntry))
					facts = { groups: [], entries, window: None }
					match ClosureIndex.query!(fx, { origin, version: Help.version, facts }) {
						Err(fail) => L2Util.report!(fx, fail)
						Ok(first) => match UnknownValues.settle!(fx, { origin, version: Help.version, roots, facts, first, urls: entries, snapshot: rest.contains("snapshot-log") }) {
							Err(fail) => L2Util.report!(fx, fail)
							Ok(done) => {
								for v in done.values {
									fx.out!("value ${v.hash} ${end_text(v.end)}\n")
								}
								fx.out!("log_size ${done.answer.log_size.to_str()}\n")
								fx.out!("releases ${done.answer.releases.len().to_str()}\n")
								for u in done.answer.unknown {
									fx.out!("unknown ${u}\n")
								}
							}
						}
					}
				}
				["fullname", name, .. as rest] => {
					selector = match rest.find_first(|word| word.starts_with("sel=")) {
						Ok(word) => match Selector.parse(word.drop_prefix("sel="), Bool.False) {
							Ok(parsed) => Ok({ selector: parsed, text: word.drop_prefix("sel=") })
							Err(_) => Err(None)
						}
						Err(_) => Err(None)
					}
					facts = { net, roots, origin: "http://127.0.0.1:9", version: Help.version, now: 1792065600, offline: rest.contains("offline"), name, selector, snapshot: log_of(rest), known: [] }
					match FullName.read!(fx, facts) {
						Ok(Found(answer)) => {
							fx.out!("releases ${answer.releases.len().to_str()}\n")
							for r in answer.releases {
								fx.out!("release ${r.version} ${r.hash}\n")
							}
						}
						Ok(NoMatch) => fx.out!("no match\n")
						Ok(SourceBuild) => fx.out!("source build\n")
						Err(fail) => L2Util.report!(fx, fail)
					}
				}
				["offline", .. as rest] => {
					request = request_of(w, roots, net, Offline("http://127.0.0.1:9"), Bool.True)
					after_query!(fx, w, request, rest, [], Offline("http://127.0.0.1:9"))
				}
				_ => fx.out!("bad line\n")
			}
		}
		0
	}
}

# The registry of a run: the word `origin=<url>`, else the one of slices 202 and 203.
origin_of : List(Str) -> Str
origin_of = |words| match words.find_first(|word| word.starts_with("origin=")) {
	Ok(word) => word.drop_prefix("origin=")
	Err(_) => "http://127.0.0.1:9"
}

# The word `log=<n>`: `--snapshot log:<n>`.
log_of : List(Str) -> Try(U64, [None])
log_of = |words| match words.find_first(|word| word.starts_with("log=")) {
	Ok(word) => match U64.from_str(word.drop_prefix("log=")) {
		Ok(n) => Ok(n)
		Err(_) => Err(None)
	}
	Err(_) => Err(None)
}

# Slice 207: the word `snapshot=<n>` of a `closure` line: `--snapshot log:<n>` on the answer.
snapshot_of : List(Str) -> Try(U64, [None])
snapshot_of = |words| match words.find_first(|word| word.starts_with("snapshot=")) {
	Ok(word) => match U64.from_str(word.drop_prefix("snapshot=")) {
		Ok(n) => Ok(n)
		Err(_) => Err(None)
	}
	Err(_) => Err(None)
}

source_text : [Live, Cached(U64), Missing] -> Str
source_text = |source| match source {
	Live => "live"
	Cached(t) => "cached ${t.to_str()}"
	Missing => "missing"
}

# Slice 206: a resolve request with dummy values and the index of the run. Only `roots`, `net`, `now`, `offline`, `selected`, `none` and `index` are read by the functions of the lines.
request_of : Str, Roots, Net.Settings, ClosureIndex.Source, Bool -> ResolveBase.Request
request_of = |w, roots, net, index, offline| {
	command: Install,
	names: [],
	fixed: [],
	frozen: Bool.False,
	no_check: Bool.True,
	project: { file: Ok("${w}/project/main.roc"), workspace: Err(Standalone), toml: Err(NoToml), roc_version: Err(None) },
	roots,
	net,
	now: 1792065600,
	offline,
	strategy: Err(Unset),
	nightly: Err(Unset),
	compiler: Err(NoCompiler),
	selected: "",
	none: Stop,
	index,
	registry: Off,
	toolchain: Err(Unset),
	snapshot: Err(Unset),
	dry_run: Bool.False,
	add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
	prompt: { mode: Mode.from_env({ env: Dict.empty(), json: Bool.False }), yes: Bool.False, quiet: Bool.False, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
	downloads: { auto: No, allow: Err(NoFlag), probe: Err(NoFlag), env: [] },
	probe: { no_probe: Bool.True, slots: Err(Unset) },
}

# Slice 206: the words of a `closure` or `offline` line after the query, in the order of the doc table.
after_query! : Fx, Str, ResolveBase.Request, List(Str), List({ alias : Str, value : Str, is_platform : Bool }), ClosureIndex.Source => {}
after_query! = |fx, w, request, words, entries, index| {
	of = |prefix| words.keep_if(|word| word.starts_with(prefix)).map(|word| word.drop_prefix(prefix))
	names = of("name=")
	if !names.is_empty() {
		match PickIndex.index!(fx, request, names, of("known=")) {
			Err(fail) => L2Util.report!(fx, fail)
			Ok(found) => {
				for c in found {
					for x in c.list {
						tag = if x.tag.is_empty() "-" else x.tag
						fx.out!("candidate ${c.name} ${x.ident.version} ${tag} ${x.published_at.to_str()} ${x.size.to_str()} ${x.url}\n")
					}
					if c.missing {
						fx.out!("missing ${c.name}\n")
					}
					for form in c.missing_forms {
						fx.out!("missing-group ${c.name} ${form}\n")
					}
				}
			}
		}
	}
	reads = of("read=")
	if !reads.is_empty() {
		match ResolveBase.read_releases!(fx, request, reads) {
			Err(fail) => L2Util.report!(fx, fail)
			Ok(facts) => {
				for f in facts {
					fx.out!("fact ${f.url} ${kind_text(f.release.kind)} deps=${Str.join_with(f.release.deps, ",")}\n")
				}
			}
		}
	}
	gathers = of("gather=")
	if !gathers.is_empty() {
		match Gather.facts!(fx, { roots: request.roots, net: request.net, offline: request.offline, selected: "", none: Stop, index }, gathers) {
			Err(fail) => L2Util.report!(fx, fail)
			Ok(got) => {
				for g in got {
					match g {
						Record(r) => fx.out!("record ${r.id} ${kind_text(r.header.release.kind)} deps=${Str.join_with(r.header.release.deps, ",")} targets=${Str.join_with(r.header.target_names, ",")}\n")
						Text(t) => fx.out!("text ${t.id} ${t.path}\n")
					}
				}
			}
		}
	}
	hints = of("hint=")
	if !hints.is_empty() {
		for h in PickLoop.hints!(fx, { net: request.net, roots: request.roots, offline: request.offline, index }, hints.map(|id| { id, nightly: "n", is_platform: Bool.False })) {
			fx.out!("hint ${h.id} ${h.hint ?? "none"}\n")
		}
	}
	match index {
		Answer(a) => {
			for name in of("checked=") {
				match ClosureIndex.checked_of(a.answer, name) {
					Ok(c) => fx.out!("checked ${c.name} ${c.checked_at.map_ok(|t| t.to_str()) ?? "null"} ${if c.stale "stale" else "fresh"}\n")
					Err(None) => fx.out!("checked ${name} none\n")
				}
			}
		}
		_ => {}
	}
	if words.contains("walk") {
		match ResolveBase.closure!(fx, request, { members: [{ file: "${w}/project/main.roc", entries }], known: [] }) {
			Err(fail) => L2Util.report!(fx, fail)
			Ok(done) => {
				for d in done {
					for row in d.walked.rows {
						fx.out!("row ${row.alias} ${row.id} ${row.version}\n")
					}
				}
			}
		}
	}
}

kind_text : [App, Package, Platform] -> Str
kind_text = |kind| match kind {
	App => "app"
	Package => "package"
	Platform => "platform"
}

# Slice 208: the text of the end of an unknown value.
end_text : UnknownValues.End -> Str
end_text = |end| match end {
	Indexed => "indexed"
	Archive => "archive"
	Label({ other: Ok(h) }) => "label other=${h}"
	Label({ other: Err(None) }) => "label"
}
