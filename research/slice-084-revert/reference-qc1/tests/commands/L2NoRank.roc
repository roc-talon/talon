import pf.Path
import lib.Consent
import lib.Fx
import lib.Mode
import lib.NoRank
import lib.Roots
import L2Util

## The entry `norank` of the L2 test app (slice 072c, changed by slice 080): `NoRank.ensure!` called directly. R-SO24 says that no compiler is selected only when nothing is installed, so each run starts with no toolchain and no `config.toml` in its home
## (the entry deletes `<cache>/toolchains` and `config.toml` first). The steps (a) and (b) of the old R-SO14 (installed compilers, a probe of them) are gone.
##
## Each line of `fx/runs` is `<words>`: `none:project:<hash>,<hash>` or `none:outside` (default `outside`), `home:<dir>` (the home of this run, a dir of the case dir, default `home`: the roots and the variable HOME), `config:<file>` (slice 084: the `config.toml` of the run, a file of the case dir), `exclude:<pattern>,<pattern>` (slice 084, Q-C1: the list `min-release-age-exclude` of `[resolution]` of the project, the field `exclude` of `NoRank.Run`), `yes`, `allow-downloads`, `offline`, `env:<NAME>=<value>`.
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
			# R-SO24: a run with no compiler selected starts with nothing installed and no default.
			_ = Path.delete_all!(Path.utf8("${cache}/toolchains"))
			_ = Path.delete!(Path.utf8("${home}/.config/talon/config.toml"))
			# Slice 084 (R-C11, R-C14): `config:<file>` writes the text of `<w>/<file>` as the `config.toml` of this run. The file has no `default-roc` (R-SO24: no default is set), so the key `min-release-age-exclude` can be tested. No word: no `config.toml`, as before.
			match given.find_first(|word| word.starts_with("config:")) {
				Ok(word) => {
					_ = Path.create_all!(Path.utf8("${home}/.config/talon"))
					text = Path.read_utf8!(Path.utf8("${w}/${word.drop_prefix("config:")}")) ?? ""
					_ = Path.write_utf8!(Path.utf8("${home}/.config/talon/config.toml"), text)
				}
				Err(_) => {}
			}
			scope_text = (given.find_first(|word| word.starts_with("none:")) ?? "none:outside").drop_prefix("none:")
			scope = if scope_text.starts_with("project:") {
				Project(scope_text.drop_prefix("project:").split_on(",").keep_if(|hash| !hash.is_empty()))
			} else {
				Outside
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
			# Slice 084 (Q-C1, R-C14): `exclude:<pattern>,...` is the list of `[resolution]` of the project. `NoRank.offer!` joins it with the list of `config.toml` (`Age.join`, project first).
			project_exclude = match given.find_first(|word| word.starts_with("exclude:")) {
				Ok(word) => word.drop_prefix("exclude:").split_on(",").keep_if(|p| !p.is_empty())
				Err(_) => []
			}
			match NoRank.ensure!(fx, { roots, run: { scope, exclude: project_exclude, downloads }, listed: [] }) {
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
