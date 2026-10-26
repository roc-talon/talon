import pf.Path
import lib.Fx
import lib.Mode
import lib.Net
import lib.Project
import lib.Resolve
import lib.Roots
import L2Util

## The entry `resolve` of the L2 test app (slice 066, split from `main.roc`).
L2Resolve :: [].{

	## Slice 005. See the table in `main.roc` for the entry.
	entry! : Fx, Str => I32
	entry! = |fx, w| {
		cache = "${w}/home/.cache/roc"
		roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
		for dir in L2Util.file_lines!("${w}/fx/gitdirs") {
			_ = Path.create_all!(Path.utf8("${w}/project/${dir}/.git"))
		}
		env = fx.env_all!()
		net = Net.from_env(env)
		mode = Mode.from_env({ env: Dict.from_list(env), json: Bool.False })
		for line in L2Util.file_lines!("${w}/fx/runs") {
			given = L2Util.words(line)
			value = |name| given.find_first(|word| word.starts_with("${name}=")).map_ok(|word| word.drop_prefix("${name}="))
			fx.out!("== ${line}\n")
			command = if given.first() == Ok("update") Update else Install
			names = given.drop_first(1).keep_if(|word| !["compiler=", "toolchain=", "nightly=", "file=", "now=", "snapshot=", "as=", "auto-install=", "slots="].any(|key| word.starts_with(key)) and !["frozen", "no-check", "offline", "lowest", "dry-run", "platform", "no-pin", "yes", "quiet", "rename-keys", "allow-moves", "allow-downloads", "probe-downloads", "no-probe"].contains(word))
			file = match value("file") {
				Ok(f) => Ok(f)
				Err(_) => Err(Unset)
			}
			found = Project.find!(fx, { start: "${w}/project", file, home: "${w}/home" })
			result = match found {
				Err(fail) => Err(fail)
				Ok(project) => Resolve.run!(
					fx,
					{
						command,
						names,
						frozen: given.contains("frozen"),
						no_check: given.contains("no-check"),
						project,
						roots,
						net,
						now: U64.from_str(value("now") ?? "") ?? 1792065600,
						offline: given.contains("offline"),
						strategy: if given.contains("lowest") Ok(Lowest) else Err(Unset),
						nightly: match value("nightly") {
							Ok("true") => Ok(Bool.True)
							Ok("false") => Ok(Bool.False)
							_ => Err(Unset)
						},
						selected: "",
						compiler: match value("compiler") {
							Ok(id) => Ok({ id, path: "${w}/home/bin/roc" })
							Err(_) => Err(NoCompiler)
						},
						toolchain: match value("toolchain") {
							Ok(id) => Ok(id)
							Err(_) => Err(Unset)
						},
						snapshot: match value("snapshot") {
							Ok(text) => Ok(text)
							Err(_) => Err(Unset)
						},
						dry_run: given.contains("dry-run"),
						add: {
							as_platform: given.contains("platform"),
							as_alias: match value("as") {
								Ok(alias) => Ok(alias)
								Err(_) => Err(Unset)
							},
							no_pin: given.contains("no-pin"),
						},
						prompt: { mode, yes: given.contains("yes"), quiet: given.contains("quiet"), rename_keys: if given.contains("rename-keys") Ok(Yes) else Err(NoFlag), allow_moves: if given.contains("allow-moves") Ok(Yes) else Err(NoFlag) },
						downloads: {
							auto: match value("auto-install") {
								Ok("yes") => Yes
								Ok("no") => No
								_ => Ask
							},
							allow: if given.contains("allow-downloads") Ok(Yes) else Err(NoFlag),
							probe: if given.contains("probe-downloads") Ok(Yes) else Err(NoFlag),
							env,
						},
						probe: {
							no_probe: given.contains("no-probe"),
							slots: match value("slots") {
								Ok(text) => match U64.from_str(text) {
									Ok(n) => Ok(n)
									Err(_) => Err(Unset)
								}
								Err(_) => Err(Unset)
							},
						},
					},
				)
			}
			match result {
				Ok(_) => fx.out!("exit 0\n")
				Err(fail) => {
					fx.out!("exit ${fail.kind.code().to_str()}\n")
					fx.err!("${fail.line()}\n")
				}
			}
		}
		0
	}
}
