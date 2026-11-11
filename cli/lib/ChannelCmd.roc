import Args
import Channel
import Compiler
import ConfigToml
import Exit
import Fail
import Fx
import Github
import Item
import JsonDoc
import Net
import Nightlies
import Out
import RocInstall
import Roots
import Text
import Toolchain
import toml.Toml

## Slice 242 (R-CH12, R-CH13, R-CC6, R-CC7, R-OUT2): the commands `tln roc channel add`, `rm` and `list`. Direct style over `Fx` (TESTING.md 2.2 part C): `Channel` decides, this module orders the calls.
## `Run.dispatch!` calls `ChannelCmd.run!` for the command `["roc", "channel"]`. The word after `channel` and its operands are in `args.operands` (`add`, `rm`, `list`). The calls, in order (the L2 cases `channels/ch12-*` and `channels/ch13-*` fix them):
##
## | Command | Does |
## | --- | --- |
## | all | The usage checks first (the word, the count of operands), no call. |
## | `add <name> <URL>` | The name, the URL form and `--tag-prefix` (no call). Then `env_all!`, `clock!`, `platform!`, one `read_files!` of `config.toml`. The existing table (same source: exit 0, another: exit 2). `list_dirs!` of `toolchains/`, one `read_files!` of the `.talon.json` of the installed ids of that name (exit 19 for another source). `--offline`: exit 15. `Github.releases!` (page 1). The prefix (`--tag-prefix`, else the one of the tags). The lock of `config.toml`: `read_files!`, `write_atomic!`. |
## | `add <name>` | `env_all!`, one `read_files!` of `config.toml`, the project search (`cwd!`, `list_dirs!`, `read_files!` of `talon.toml`), `Channel.copy_check`. A copy takes the lock of `config.toml`: `read_files!`, `write_atomic!`. No request. |
## | `rm <name>` | `env_all!`, one `read_files!` of `config.toml`, `Channel.rm_check`, the lock of `config.toml`: `read_files!`, `write_atomic!`. |
## | `list` | `env_all!`, one `read_files!` of `config.toml`, the project search, `Channel.compare` (exit 19). |
ChannelCmd :: [].{

	## `tln roc channel <word> ...`.
	run! : Fx, Args => I32
	run! = |fx, args| match args.operands {
		[] => stopped!(fx, args, "roc channel", Fail.new(Usage, "tln roc channel needs a word: add, rm or list"))
		["add", .. as rest] => finished!(fx, args, "roc channel add", add_flow!(fx, args, rest))
		["rm", .. as rest] => finished!(fx, args, "roc channel rm", rm_flow!(fx, args, rest))
		["list", .. as rest] => finished!(fx, args, "roc channel list", list_flow!(fx, args, rest))
		[word, ..] => stopped!(fx, args, "roc channel", Fail.new(Usage, "tln roc channel ${word} is not a command: use add, rm or list"))
	}
}

# The exit code of a flow. The flow printed its own output.
finished! : Fx, Args, Str, Try({}, Fail) => I32
finished! = |fx, args, command, done| match done {
	Ok({}) => 0
	Err(fail) => stopped!(fx, args, command, fail)
}

# A failure: the line on stderr, the envelope on stdout with `--json`, and the code of the kind. `command` is the long form (`roc channel add`), whatever was typed.
stopped! : Fx, Args, Str, Fail => I32
stopped! = |fx, args, command, fail| {
	shown = Out.fail({ command, json: args.json, fail })
	if !shown.stdout.is_empty() fx.out!(shown.stdout)
	fx.err!(shown.stderr)
	Exit.choose({ failures: [fail], child: Err(NoChild) })
}

# A text and its hint as one message (the second line is the hint).
with_hint : { message : Str, hint : Str } -> Str
with_hint = |said| "${said.message}\n${said.hint}"

# What `add` decided from its operands.
AddOp : [Url({ name : Str, source : Str, given : Try(Str, [Unset]) }), Copy(Str)]

# R-CH12, R-CH3: the operands of `add`, before any call. The order: the count, the name, the URL form, the form of `--tag-prefix`.
read_add : Args, List(Str) -> Try(AddOp, Fail)
read_add = |args, rest| match rest {
	[] => Err(Fail.new(Usage, "tln roc channel add needs a channel name: tln roc channel add <name> [<URL>]"))
	[one] => match Channel.name_check(one) {
		Ok({}) => Ok(Copy(one))
		Err(why) => if Channel.source_of_url(one).is_ok() {
			Err(Fail.new(Usage, "give the channel name: tln roc channel add <name> <URL>"))
		} else {
			Err(name_fail(one, why))
		}
	}
	[name, url] => {
		match Channel.name_check(name) {
			Ok({}) => {}
			Err(why) => return Err(name_fail(name, why))
		}
		source = match Channel.source_of_url(url) {
			Ok(found) => found
			Err(BadUrl) => return Err(Fail.new(Usage, with_hint(Channel.url_text(url))))
		}
		given = match args.options.find_first(|(flag, _)| flag == "--tag-prefix") {
			Ok((_, value)) => value
			Err(_) => Err(Unset)
		}
		match given {
			Ok(prefix) => match Channel.prefix_given({ given: prefix, tags: [] }) {
				Err(BadPrefix) => return Err(Fail.new(Usage, Channel.given_text({ given: prefix, kind: BadPrefix, source })))
				_ => {}
			}
			Err(_) => {}
		}
		Ok(Url({ name, source, given }))
	}
	many => Err(Fail.new(Usage, "tln roc channel add takes a name and a URL, got ${many.len().to_str()} operands"))
}

name_fail : Str, [BadName, Reserved] -> Fail
name_fail = |name, why| match why {
	BadName => Fail.new(Usage, "${name} is not a channel name. A name is a-z, 0-9 and -, starts with a letter, has 2 to 24 characters and does not end with -.")
	Reserved => Fail.new(Usage, "${name} is a reserved channel name")
}

# The `config.toml` of the run: its path, its text and the config (the warnings of the read go to stderr).
read_config! : Fx, Roots => Try({ path : Str, text : Str, config : ConfigToml.Config }, Fail)
read_config! = |fx, roots| {
	path = Roots.item(roots, Item.Config)
	text = RocInstall.read_text!(fx, path)?
	read = ConfigToml.read({ path, text })?
	for w in read.warnings {
		fx.err!("warning: ${w}\n")
	}
	Ok({ path, text, config: read.config })
}

# R-CC6, R-CC7: the edit of `config.toml` under its lock. The text is read once, under the lock. `Same` writes nothing. The result is true when a write happened.
write_locked! : Fx, Str, (Str -> Try([Same, Set(Str)], Fail)) => Try(Bool, Fail)
write_locked! = |fx, path, decide| fx.locked!(
	path,
	|| {
		text = RocInstall.read_text!(fx, path)?
		match decide(text)? {
			Same => Ok(Bool.False)
			Set(content) => match fx.write_atomic!([{ path, content }]) {
				Ok(_) => Ok(Bool.True)
				Err({ path: failed, err }) => Err(Fail.new(Environment, "cannot write ${failed}: ${Str.inspect(err)}"))
			}
		}
	},
)

# The tables of a text of `talon.toml`. A text that is not TOML has none.
tables_of : Str -> List({ name : Str, source : Str, tag_prefix : Str })
tables_of = |text| match Toml.parse(text) {
	Ok(doc) => Channel.entries(Channel.read(doc, text).tables)
	Err(_) => []
}

# The data of `add` (R-J1 to R-J3): `read`, `target` and `newest` are `null` when no list was read.
add_data : { table : { name : Str, source : Str, tag_prefix : Str }, path : Str, changed : Bool, listed : Try({ read : U64, target : Str, newest : { id : Str, has_asset : Bool } }, [None]) } -> JsonDoc
add_data = |facts| {
	base = [
		("name", JsonDoc.Text(facts.table.name)),
		("shape", JsonDoc.Text("github-release")),
		("source", JsonDoc.Text(facts.table.source)),
		("tag_prefix", JsonDoc.Text(facts.table.tag_prefix)),
		("path", JsonDoc.Text(facts.path)),
		("changed", JsonDoc.Flag(facts.changed)),
	]
	more = match facts.listed {
		Ok(l) => [
			("read", JsonDoc.Num(l.read.to_i64_wrap())),
			("target", JsonDoc.Text(l.target)),
			("newest", JsonDoc.Obj([("id", JsonDoc.Text(l.newest.id)), ("has_asset", JsonDoc.Flag(l.newest.has_asset))])),
		]
		Err(None) => [("read", JsonDoc.Null), ("target", JsonDoc.Null), ("newest", JsonDoc.Null)]
	}
	JsonDoc.Obj(base.concat(more))
}

# The output of a command that has a text and a `data`: the envelope alone with `--json`, else the text (unless `--quiet`).
print! : Fx, Args, { command : Str, text : Str, data : JsonDoc } => {}
print! = |fx, args, out| if args.json {
	fx.out!(Out.json_ok({ command: out.command, data: out.data }))
} else if !args.quiet {
	fx.out!("${out.text}\n")
}

# `add`. Step 1: the operands. Then the URL form or the copy.
add_flow! : Fx, Args, List(Str) => Try({}, Fail)
add_flow! = |fx, args, rest| match read_add(args, rest)? {
	Url(op) => add_url_flow!(fx, args, op)
	Copy(name) => add_copy_flow!(fx, args, name)
}

# R-CH12: `add <name> <URL>`.
add_url_flow! : Fx, Args, { name : Str, source : Str, given : Try(Str, [Unset]) } => Try({}, Fail)
add_url_flow! = |fx, args, op| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	real = fx.clock!()
	system = Toolchain.host(fx.platform!())?
	cfg = read_config!(fx, roots)?
	# Design Q617 item 1: a table of the name is there already.
	match Channel.exists_check({ name: op.name, source: op.source, config: cfg.config.channels }) {
		Same => {
			table = cfg.config.channels.find_first(|t| t.name == op.name) ?? { name: op.name, source: op.source, tag_prefix: "" }
			print!(fx, args, { command: "roc channel add", text: Channel.already_text({ name: op.name, source: op.source }), data: add_data({ table, path: cfg.path, changed: Bool.False, listed: Err(None) }) })
			return Ok({})
		}
		Other(existing) => return Err(Fail.new(Usage, with_hint(Channel.exists_text({ name: op.name, source: op.source, existing }))))
		Absent => {}
	}
	# R-CH12 exit 19: an installed build of the name records another source.
	entries = RocInstall.toolchain_entries!(fx, Text.join(roots.cache, "toolchains"))
	ids = Compiler.installed_users(entries).keep_if(|id| Channel.user_parts(id).map_ok(|p| p.name == op.name) == Ok(Bool.True))
	reads = if ids.is_empty() [] else fx.read_files!(ids.map(|id| Roots.item(roots, Item.ToolchainMeta(id))))
	installed = ids.map2(reads, |id, read| { id, source: recorded_source(read) })
	match Channel.source_conflict({ name: op.name, source: op.source, installed }) {
		Err(Conflict(recorded)) => return Err(Fail.new(Input, with_hint(Channel.conflict_text({ name: op.name, source: op.source, recorded }))))
		Ok({}) => {}
	}
	if args.offline return Err(Fail.new(Network, "--offline is set and tln roc channel add needs the release list of github.com/${op.source}"))
	listed = list_page!(fx, { env, roots, real, source: op.source })?
	prefix = match op.given {
		Ok(given) => match Channel.prefix_given({ given, tags: listed.tags }) {
			Ok(p) => p
			Err(kind) => return Err(Fail.new(Usage, Channel.given_text({ given, kind, source: op.source })))
		}
		Err(_) => match Channel.prefix_of_tags(listed.tags) {
			Ok(p) => p
			Err(failure) => return Err(Fail.new(Usage, Channel.prefix_text(failure)))
		}
	}
	table = { name: op.name, source: op.source, tag_prefix: prefix }
	builds = match Nightlies.releases_of({ host: system, pages: [listed.page], channel: table }) {
		Ok(found) => found
		Err(BadPage(_)) => return Err(bad_page(op.source))
	}
	# The newest build of page 1 (R-CH4): no switch, no min-release-age (Design Q617 item 4).
	newest = match builds.last() {
		Ok(release) => { id: release.id, has_asset: release.asset.is_ok() }
		Err(_) => return Err(Fail.new(Usage, Channel.given_text({ given: prefix, kind: NoTag, source: op.source })))
	}
	target = Nightlies.target(system)
	changed = write_locked!(fx, cfg.path, |text| Channel.add_edit({ path: cfg.path, text, table }).map_ok(|content| Set(content)))?
	print!(
		fx,
		args,
		{
			command: "roc channel add",
			text: Channel.added_text({ path: cfg.path, table, read: listed.read, newest, target }),
			data: add_data({ table, path: cfg.path, changed, listed: Ok({ read: listed.read, target, newest }) }),
		},
	)
	Ok({})
}

# The `source` of a `.talon.json`, if it has one.
recorded_source : Try(Str, _) -> Try(Str, [Unset])
recorded_source = |read| match read {
	Ok(text) => match JsonDoc.parse(text) {
		Ok(JsonDoc.Obj(pairs)) => match pairs.find_first(|(key, _)| key == "source") {
			Ok((_, JsonDoc.Text(source))) => Ok(source)
			_ => Err(Unset)
		}
		_ => Err(Unset)
	}
	Err(_) => Err(Unset)
}

bad_page : Str -> Fail
bad_page = |source| Fail.new(Network, "page 1 of ${source} is not a release list")

# R-CH12: page 1 of the release list. `read` is the number of its entries, `tags` the `tag_name` of each one.
list_page! : Fx, { env : List((Str, Str)), roots : Roots, real : U64, source : Str } => Try({ page : Str, read : U64, tags : List(Str) }, Fail)
list_page! = |fx, run| {
	(owner, repo) = match run.source.split_on("/") {
		[o, r] => (o, r)
		_ => ("", "")
	}
	found = Github.releases!(fx, { net: Net.from_env(run.env), roots: run.roots, owner, repo, now: run.real, offline: Bool.False, pages: 1 })?
	page = match found.pages.first() {
		Ok(text) => text
		Err(_) => return Err(bad_page(run.source))
	}
	items = match JsonDoc.parse(page) {
		Ok(JsonDoc.Arr(list)) => list
		_ => return Err(bad_page(run.source))
	}
	# Design Q618: the prefix and the newest build come from builds only (a draft or a prerelease is not one, R-CH4, R-DI3).
	tag_of = |item| match item {
		JsonDoc.Obj(pairs) => match pairs.find_first(|(key, _)| key == "tag_name") {
			Ok((_, JsonDoc.Text(tag))) => Ok((tag, pairs.any(|(key, value)| (key == "draft" or key == "prerelease") and value == JsonDoc.Flag(Bool.True))))
			_ => Err(NoTag)
		}
		_ => Err(NoTag)
	}
	listed = items.keep_oks(tag_of)
	tags = listed.keep_if(|(_, skipped)| !skipped).map(|(tag, _)| tag)
	if Channel.prefix_of_tags(tags) == Err(NoPrefix) and Channel.prefix_of_tags(listed.map(|(tag, _)| tag)) != Err(NoPrefix) {
		return Err(Fail.new(Usage, Channel.no_build_text(run.source)))
	}
	Ok({ page, read: items.len(), tags })
}

# R-CH13: `add <name>`: the table comes from the project `talon.toml`. No request.
add_copy_flow! : Fx, Args, Str => Try({}, Fail)
add_copy_flow! = |fx, args, name| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	cfg = read_config!(fx, roots)?
	project = RocInstall.project_toml!(fx, env)
	tables = match project {
		Ok(found) => tables_of(found.text)
		Err(_) => []
	}
	give_url = "Give the URL: tln roc channel add ${name} <URL>"
	match Channel.copy_check({ name, config: cfg.config.channels, project: tables }) {
		NoTable => match project {
			Ok(found) => Err(Fail.new(Usage, "${found.path} has no [channels.${name}] table. ${give_url}"))
			Err(_) => Err(Fail.new(Usage, "no talon.toml found. ${give_url}"))
		}
		Equal => {
			table = tables.find_first(|t| t.name == name) ?? { name, source: "", tag_prefix: "" }
			print!(fx, args, { command: "roc channel add", text: Channel.already_text({ name, source: table.source }), data: add_data({ table, path: cfg.path, changed: Bool.False, listed: Err(None) }) })
			Ok({})
		}
		Differ => match project {
			Ok(found) => match Channel.compare({ talon: { path: found.path, text: found.text }, config: { path: cfg.path, text: cfg.text } }) {
				Err(fail) => Err(fail)
				Ok({}) => Err(Fail.new(Input, "${found.path}: channels.${name} is not equal to channels.${name} in ${cfg.path}"))
			}
			Err(_) => Err(Fail.new(Internal, "channels.${name} differs, but no talon.toml was found"))
		}
		Copy(table) => {
			from = match project {
				Ok(found) => found.path
				Err(_) => ""
			}
			changed = write_locked!(fx, cfg.path, |text| Channel.add_edit({ path: cfg.path, text, table }).map_ok(|content| Set(content)))?
			print!(fx, args, { command: "roc channel add", text: Channel.copied_text({ path: cfg.path, from, table }), data: add_data({ table, path: cfg.path, changed, listed: Err(None) }) })
			Ok({})
		}
	}
}

# Design Q618 item 3: `--tag-prefix` is for `add` only.
no_prefix_flag : Args, Str -> Try({}, Fail)
no_prefix_flag = |args, word| if args.options.any(|(flag, _)| flag == "--tag-prefix") {
	Err(Fail.new(Usage, "flag '--tag-prefix' is not for 'roc channel ${word}'"))
} else {
	Ok({})
}

# R-CH13: `rm <name>`. It changes `config.toml` only.
rm_flow! : Fx, Args, List(Str) => Try({}, Fail)
rm_flow! = |fx, args, rest| {
	no_prefix_flag(args, "rm")?
	name = match rest {
		[one] => one
		[] => return Err(Fail.new(Usage, "tln roc channel rm needs one channel name"))
		many => return Err(Fail.new(Usage, "tln roc channel rm takes one channel name, got ${many.len().to_str()}"))
	}
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	cfg = read_config!(fx, roots)?
	match Channel.rm_check({ name, config: cfg.config.channels }) {
		Builtin => return Err(Fail.new(Usage, Channel.rm_fail_text({ name, kind: Builtin, path: cfg.path })))
		Missing => return Err(Fail.new(Usage, Channel.rm_fail_text({ name, kind: Missing, path: cfg.path })))
		Found => {}
	}
	changed = write_locked!(fx, cfg.path, |text| Channel.remove_edit({ path: cfg.path, text, name }))?
	data = JsonDoc.Obj([("name", JsonDoc.Text(name)), ("path", JsonDoc.Text(cfg.path)), ("changed", JsonDoc.Flag(changed))])
	print!(fx, args, { command: "roc channel rm", text: Channel.removed_text({ path: cfg.path, name }), data })
	Ok({})
}

# R-CH13: `list`. The answer of the command: `--quiet` does not hide it. Unequal tables of the two files are exit 19 (R-CH10).
list_flow! : Fx, Args, List(Str) => Try({}, Fail)
list_flow! = |fx, args, rest| {
	no_prefix_flag(args, "list")?
	if !rest.is_empty() return Err(Fail.new(Usage, "tln roc channel list takes no operand, got ${rest.len().to_str()}"))
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	cfg = read_config!(fx, roots)?
	project = RocInstall.project_toml!(fx, env)
	tables = match project {
		Ok(found) => {
			Channel.compare({ talon: { path: found.path, text: found.text }, config: { path: cfg.path, text: cfg.text } })?
			tables_of(found.text)
		}
		Err(_) => []
	}
	facts = { config: cfg.config.channels, project: tables }
	if args.json {
		fx.out!(Out.json_ok({ command: "roc channel list", data: Channel.list_data(facts) }))
	} else {
		fx.out!("${Channel.list_text(facts)}\n")
	}
	Ok({})
}
