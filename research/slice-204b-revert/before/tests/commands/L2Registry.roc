import lib.ClosureRequest
import lib.Help
import lib.Lookup
import lib.Net
import lib.Nightlies
import lib.PrivacyGuard
import lib.RegistryCache
import lib.RegistryToolchains
import lib.Ref
import lib.Scope
import lib.ShortNames
import lib.Roots
import lib.Fx
import L2Util

## The entry `registry` of the L2 test app (slices 202 and 203). Each line of `fx/runs` is one run. The registry is `http://127.0.0.1:9` (its routes are `fx/http/127.0.0.1%3A9/...`). The roots are in the case dir (`home/.cache/roc`).
## One `env_all!` call at the start. A word `env:<NAME>=<value>` is added to the environment of that run (as for `index`).
##
## | Line | Runs | Prints |
## | --- | --- | --- |
## | `get <path> [now=<s>] [offline] [newest] [bookmark=<b>]` | `RegistryCache.get!` for the path and the query (`/v1/...`). `now` is the real clock (default 1792065600). | `status: <n>`, `source: live` or `source: copy <mtime>`, `body: <text>`. Or `no copy`. Or `exit <code>` and the failure line on stderr. |
## | `guard <source>... [offline] [frozen]` | `PrivacyGuard.check!`. A source is `repo:<owner>/<repo>`, `group:<text>`, `url:<text>` or `short:<name>`. | `ok`, or `exit <code>` and the failure line on stderr. |
## | `toolchains [offline] [log=<n>] [origin=<url>]` | `RegistryToolchains.list!` (slice 204), then `RegistryToolchains.visible` with `log=<n>`. `origin` is the registry of the run (default `http://127.0.0.1:9`: the routes are `fx/http/<host>/v1/toolchains?after=<n>`). | `source: live`, `source: cached <mtime>` or `source: missing`, then one line `row <log_index> <tag> <target> <asset_name> <sha256> <published_at>` for each visible row. Or `exit <code>` and the failure line on stderr. |
## | `nightlies <target> [offline] [log=<n>] [origin=<url>]` | `Nightlies.list_registry!` (slice 204) for the host with the asset target `<target>` (`linux_x86_64`, `linux_arm64`, `macos_apple_silicon`, `macos_x86_64`, `windows_x86_64`, `windows_arm64`). | `source: ...` as above, then for each release `nightly <id> <published_at> <size> <sha256 or none> <url>`, or `nightly <id> <published_at> no asset`, then `changed <tag>` for each changed tag and `dropped <id>` for each dropped release. Or `exit <code>` and the failure line. |
## | `short <scope> <name>... [alias:<alias>]... [offline] [log=<n>] [origin=<url>]` | Slice 211. The scope is `install`, `tool` or `x`. Each name is parsed with `Ref.parse`. A name for which `Lookup.needs_registry` is true (the entities are one entity for each `alias:` word, with the full name `own/<alias>`) goes in the one `ShortNames.lookup!` (the clock is 1792065600). Then `Lookup.registry` for each of those names, in order. | For each name: `<name>: use <full name>` and, with a matched line, that line, or the block of the failure on stderr, `exit <code>` on stdout and the failure line on stderr. A name with no search: `<name>: no search`. A failure of `lookup!`: `exit <code>` and the line. |
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
								fx.out!("row ${row.log_index.to_str()} ${row.tag} ${row.target} ${row.asset_name} ${row.sha256} ${row.published_at.to_str()}\n")
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

source_text : [Live, Cached(U64), Missing] -> Str
source_text = |source| match source {
	Live => "live"
	Cached(t) => "cached ${t.to_str()}"
	Missing => "missing"
}
