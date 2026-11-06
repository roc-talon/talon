import Fail
import Fx
import Item
import Text

## The directory roots of one run (CLI 6.1, R-LY1 to R-LY3, R-LY5 to R-LY7, R-EV13, Design 2.2 R-CR1).
## Linux and macOS only: the Windows rows of R-LY5 to R-LY9 are P1 (Windows CI).
##
## | Field | Value | Rule |
## | --- | --- | --- |
## | `cache` | `$XDG_CACHE_HOME/roc`, else `$HOME/.cache/roc`. Holds `packages/`, `toolchains/`, `talon/`. | R-LY5, R-EV13 |
## | `pkgs` | `<cache>/packages`. It ignores `ROC_CACHE_DIR`. | R-CR1 |
## | `build` | `$ROC_CACHE_DIR` when it is set, else `cache`. It holds `compat-<id>/`. | R-CR1, R-LY1 |
## | `config` | `$XDG_CONFIG_HOME/talon`, else `$HOME/.config/talon` | R-LY6 |
## | `data` | `$XDG_DATA_HOME/talon`, else `$HOME/.local/share/talon` | R-LY7 |
Roots := {
	cache : Str,
	pkgs : Str,
	build : Str,
	config : Str,
	data : Str,
}.{
	is_eq : _

	## The roots from the environment of the run (`Fx.env_all!`: the pairs of name and value). A flag has no part here.
	## `HOME` is needed only for a root with no variable. When it is missing, the result is a failure of kind
	## `Environment` (exit 18). Not tested: the design does not say (question Q2 of the slice file), and the same holds
	## for a variable that is empty or not an absolute path.
	from_env : List((Str, Str)) -> Try(Roots, Fail)
	from_env = |env| {
		var_of = |name| match env.find_first(|(n, _)| n == name) {
			Ok((_, value)) => if value.is_empty() Err(Unset) else Ok(value)
			Err(_) => Err(Unset)
		}
		# An XDG variable that is empty or not an absolute path is ignored (XDG spec, Q2).
		xdg = |name| match var_of(name) {
			Ok(value) => if value.starts_with("/") Ok(value) else Err(Unset)
			Err(Unset) => Err(Unset)
		}
		home = var_of("HOME")
		under_home = |rest| match home {
			Ok(h) => Ok(Text.join(h, rest))
			Err(Unset) => Err(Fail.new(Environment, "HOME is not set"))
		}
		base = |name, rest| match xdg(name) {
			Ok(dir) => Ok(dir)
			Err(Unset) => under_home(rest)
		}
		cache = Text.join(base("XDG_CACHE_HOME", ".cache")?, "roc")
		Ok({
			cache,
			pkgs: Text.join(cache, "packages"),
			build: match var_of("ROC_CACHE_DIR") {
				Ok(dir) => dir
				Err(Unset) => cache
			},
			config: Text.join(base("XDG_CONFIG_HOME", ".config")?, "talon"),
			data: Text.join(base("XDG_DATA_HOME", ".local/share")?, "talon"),
		})
	}

	## Slice 088 (R-LY5 to R-LY7, 050c Q-D3): the roots of one run on a given system. `Windows` gives the Windows column of the design (CLI 6.1):
	## the cache is `%LOCALAPPDATA%\roc`, the config is `%APPDATA%\talon`, the data is `%LOCALAPPDATA%\talon`. A Windows path has `\` between its parts,
	## and a `\` at the end of the variable is dropped (as `Setup.bin_dir`, R-LY8). `HOME` is not read on Windows. `ROC_CACHE_DIR` works as on other systems (R-CR1).
	## Every other system gives the roots of `from_env`. The Windows rows that the design does not give are the questions Q-W1 to Q-W4 of the slice file (not tested).
	from_env_on : [Linux, Macos, Windows, Other(Str)], List((Str, Str)) -> Try(Roots, Fail)
	from_env_on = |os, env| match os {
		Windows => windows_roots(env)
		_ => Roots.from_env(env)
	}

	## Slice 088, Q-W5 (b): the roots of one run, with the system from `Fx.windows!` (not in `calls.log`). Linux and macOS have no change.
	of_run! : Fx, List((Str, Str)) => Try(Roots, Fail)
	of_run! = |fx, env| Roots.from_env_on(if fx.windows!() Windows else Linux, env)

	## The path of an item (the tables of `Item`). There is no `/` at the end of a path.
	item : Roots, Item -> Str
	item = |roots, item| match item {
		Package(hash) => Text.join(roots.pkgs, hash)
		PackageDeps(hash) => Text.join(roots.pkgs, "${hash}.deps.json")
		Compat(id) => Text.join(roots.build, "compat-${id}")
		Toolchain(id) => Text.join(roots.cache, "toolchains/${id}")
		ToolchainRoc(id) => Text.join(roots.cache, "toolchains/${id}/roc")
		ToolchainMeta(id) => Text.join(roots.cache, "toolchains/${id}/.talon.json")
		ToolchainLastUse(id) => Text.join(roots.cache, "toolchains/${id}/.last-use")
		Zig(version) => Text.join(roots.cache, "toolchains/zig-${version}")
		Index => Text.join(roots.cache, "talon/index")
		CompatDb => Text.join(roots.cache, "talon/compat.db")
		ProjectsJson => Text.join(roots.cache, "talon/projects.json")
		PathRocJson => Text.join(roots.cache, "talon/path-roc.json")
		TalonTmp(hex) => Text.join(roots.cache, "talon/tmp/${hex}")
		Gc => Text.join(roots.cache, "talon/gc")
		XBuild(digest) => Text.join(roots.cache, "talon/x/${digest}")
		Config => Text.join(roots.config, "config.toml")
		Bin => Text.join(roots.data, "bin")
		ToolsJson => Text.join(roots.data, "tools.json")
		ShareJson => Text.join(roots.data, "share.json")
	}
}

## The Windows roots (R-LY5 to R-LY7, R-CR1). The cache order is as roc: `XDG_CACHE_HOME`, `LOCALAPPDATA`, `HOME` (Q-W1, Q-W3, Q-W4).
## A root with no variable and no `HOME` is kind `Environment` (exit 18). The `HOME` form of config and data is a choice of the code agent (open questions Q-W2 to Q-W4).
windows_roots : List((Str, Str)) -> Try(Roots, Fail)
windows_roots = |env| {
	var_of = |name| match env.find_first(|(n, _)| n == name) {
		Ok((_, value)) => if value.is_empty() Err(Unset) else Ok(value.drop_suffix("\\"))
		Err(_) => Err(Unset)
	}
	# A root with no variable: the HOME form as roc does for the cache. The design does not give it for config and data (Q-W3, Q-W4).
	need = |name, rest| match var_of(name) {
		Ok(value) => Ok(value)
		Err(Unset) => match var_of("HOME") {
			Ok(home) => Ok("${home}\\${rest}")
			Err(Unset) => Err(Fail.new(Environment, "${name} is not set"))
		}
	}
	cache_base = match var_of("XDG_CACHE_HOME") {
		Ok(dir) => Ok(dir)
		Err(Unset) => match var_of("LOCALAPPDATA") {
			Ok(dir) => Ok(dir)
			Err(Unset) => match var_of("HOME") {
				Ok(home) => Ok("${home}\\.cache")
				Err(Unset) => Err(Fail.new(Environment, "LOCALAPPDATA is not set"))
			}
		}
	}
	cache = "${cache_base?}\\roc"
	Ok({
		cache,
		pkgs: "${cache}\\packages",
		build: match var_of("ROC_CACHE_DIR") {
			Ok(dir) => dir
			Err(Unset) => cache
		},
		config: "${need("APPDATA", ".config")?}\\talon",
		data: "${need("LOCALAPPDATA", ".local\\share")?}\\talon",
	})
}
