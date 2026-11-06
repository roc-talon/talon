import lib.Help
import lib.Net
import lib.PrivacyGuard
import lib.RegistryCache
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
				_ => fx.out!("bad line\n")
			}
		}
		0
	}
}
