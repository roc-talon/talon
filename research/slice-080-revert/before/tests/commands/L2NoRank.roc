import pf.Path
import lib.Consent
import lib.Fx
import lib.Mode
import lib.NoRank
import lib.Roots
import L2Util

## The entry `norank` of the L2 test app (slice 072c): `NoRank.ensure!` called directly, with the installed compilers of the case and a fake probe for step (b) of R-SO14. A fetch flow never reaches steps (a) and (b)
## (`Fetch.unbundler` takes the newest installed compiler first, R-FE4), so this entry is the only place where they run at L2.
##
## Each line of `fx/runs` is `<words>`: `have:<id>,<id>` (the dirs of `<cache>/toolchains` of this run, as for `fetch`; `have:` alone: none, no word: the dirs stay as they are), `none:project:<hash>,<hash>` or `none:outside` (default `outside`),
## `home:<dir>` (the home of this run, a dir of the case dir, default `home`: the roots and the variable HOME), `probe:skip` (default) or `probe:max=<n>` (step (b) runs with `probe.max` = n), `pass:<id>,<id>` (the compilers that the fake probe passes,
## default none), `cost:<n>` (the probes that the fake ladder starts for a compiler, at most `left`, default 2), `yes`, `allow-downloads`, `offline`, `env:<NAME>=<value>`. The fake probe prints `probe <id> left=<n>` on stdout.
## After the run the entry prints `ok <id> installed=<ids>` or `exit <code>` (and the failure line on stderr), then `default-roc: <line>` (the line of `config.toml`, or `none`).
L2NoRank :: [].{

	entry! : Fx, Str => I32
	entry! = |fx, w| {
		base_env = fx.env_all!().keep_if(|(name, _)| name != "HOME")
		for line in L2Util.file_lines!("${w}/fx/runs").keep_if(|l| !l.starts_with("#")) {
			given = L2Util.words(line)
			fx.out!("== ${line}\n")
			extra = given.keep_if(|word| word.starts_with("env:")).map(
				|word| match word.drop_prefix("env:").split_on("=") {
					[name, .. as value] => (name, Str.join_with(value, "="))
					[] => ("", "")
				},
			)
			home = "${w}/${(given.find_first(|word| word.starts_with("home:")) ?? "home:home").drop_prefix("home:")}"
			cache = "${home}/.cache/roc"
			roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${home}/.config/talon", data: "${home}/.local/share/talon" }
			env = base_env.append(("HOME", home)).concat(extra)
			listed = match given.find_first(|word| word.starts_with("have:")) {
				Ok(word) => {
					ids = word.drop_prefix("have:").split_on(",").keep_if(|id| !id.is_empty())
					_ = Path.delete_all!(Path.utf8("${cache}/toolchains"))
					for id in ids {
						_ = Path.create_all!(Path.utf8("${cache}/toolchains/${id}"))
					}
					ids
				}
				Err(_) => []
			}
			scope_text = (given.find_first(|word| word.starts_with("none:")) ?? "none:outside").drop_prefix("none:")
			scope = if scope_text.starts_with("project:") {
				Project(scope_text.drop_prefix("project:").split_on(",").keep_if(|hash| !hash.is_empty()))
			} else {
				Outside
			}
			passing = (given.find_first(|word| word.starts_with("pass:")) ?? "pass:").drop_prefix("pass:").split_on(",")
			cost = U64.from_str((given.find_first(|word| word.starts_with("cost:")) ?? "cost:2").drop_prefix("cost:")) ?? 2
			one! = |req| {
				fx.out!("probe ${req.id} left=${req.left.to_str()}\n")
				Ok({ passed: passing.contains(req.id), probes: if cost < req.left cost else req.left })
			}
			probe = match given.find_first(|word| word.starts_with("probe:max=")) {
				Ok(word) => Run({ max: U64.from_str(word.drop_prefix("probe:max=")) ?? 0, one! })
				Err(_) => Skip
			}
			downloads = {
				auto: Consent.auto_install(env),
				allow: if given.contains("allow-downloads") Ok(Yes) else Err(NoFlag),
				yes: given.contains("yes"),
				mode: Mode.from_env({ env: Dict.from_list(env), json: Bool.False }),
				quiet: Bool.False,
				offline: given.contains("offline"),
				env,
			}
			match NoRank.ensure!(fx, { roots, run: { scope, downloads, probe }, listed }) {
				Ok(got) => fx.out!("ok ${got.id} installed=${Str.join_with(got.installed, ",")}\n")
				Err(fail) => L2Util.report!(fx, fail)
			}
			config = match Path.read_utf8!(Path.utf8("${home}/.config/talon/config.toml")) {
				Ok(text) => text.split_on("\n").keep_if(|l| l.starts_with("default-roc")).first() ?? "none"
				Err(_) => "none"
			}
			fx.out!("default-roc: ${config}\n")
		}
		0
	}
}
