import records.Account
import Args
import Common
import Db
import Fail
import Fx
import Item
import JsonDoc
import Net
import Out
import RocInstall
import Roots
import Share
import ShareJson
import Temp

## `tln share`, `tln share on` and `tln share off` (slice 213, CLI 1 R-CM23, R-SH1, R-SH5, R-SH6, R-SH8 local part, R-SH10; 6.1 R-LY3, R-TF1; 7.4 R-CC6, R-CC7). Direct style over `Fx`.
## `Run.tln!` calls `status!` for `["share"]`, `on!` for `["share", "on"]` and `off!` for `["share", "off"]`. `login`, `logout` and `forget` are slices 219 and 220.
## No new `Fx` call. The new `Db` variants `QueueCount` and `ClearQueue` go through `db_query!` and `db_write!`.
## The L2 cases `share/sh1-flow`, `share/sh2-direct` and `share/sh3-status` fix the calls.
##
## `on!` and `off!` (the same steps, with `value` true or false):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `env_all!`, `Roots.of_run!`. The path of `config.toml` is `Roots.item(roots, Config)`. | R-LY6 |
## | 2 | `Fx.locked!` on that path: `read_files!` (a missing file is the empty text), `Share.edit`. `Same`: no more calls. `Set(text)`: a second `read_files!`, and when the bytes differ from the first read `Share.edit` runs again on the new bytes (R-CC7). Then `write_atomic!` of that path. | R-SH1, R-CC6, R-CC7, R-LY3 |
## | 3 | `on` only: `Fx.locked!` on `Roots.item(roots, ShareJson)`: `read_files!`. Missing file: `random!` two times (the first is `high`), `ShareJson.id_of`, `write_atomic!` of `ShareJson.text(ShareJson.fresh(id))`, then `spawn_all!` (limit 1) of `Share.chmod_command` (`chmod 0600 <file>`; no call when `Fx.windows!` is true; a failed chmod is kind `Environment`: `cannot set the mode of <file>: <result>`). A file that is there: `ShareJson.read` (a failure stops with exit 19), and no write. | R-SH5, R-SH13, R-LY3, R-CC6, R-TF6 |
## | 4 | `off` only: `db_write!` with `Db.Open` of `Roots.item(roots, CompatDb)` and `ClearQueue`. An `Err` goes to `Share.clear_err`: `Stop(fail)` stops, `Warn(text)` is printed as `warning: <text>` on stderr and the command goes on. `share.json` is not read and not written. | R-SH4, R-SH6, R-CC8 |
## | 5 | `on` only: the registry of the run (`Net.registry`: `--registry`, `TALON_REGISTRY`, the key `registry` of the text of step 2, `Share.setting`). `sends` is false for `Direct`. | R-SH10 |
## | 6 | Output: `Share.on_lines` or `Share.off_lines` on stdout. With `--json`: only the envelope (`Share.on_data`, `Share.off_data`), no text. | R-OUT2, R-OUT4 |
##
## `status!`:
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `env_all!`, `Roots.of_run!` | |
## | 2 | `read_files!` of `config.toml` (a missing file is the empty text), `Share.setting`. `Net.registry` as in step 5 above. `Share.state` with `args.offline` and the environment. | R-SH2, R-SH8 |
## | 3 | `read_files!` of `share.json`, `ShareJson.read`. A missing file: Q2 of the slice file (stop). | R-SH8, R-SH13 |
## | 4 | `db_query!` with `QueueCount`. An `Err` goes to `Db.on_err`: `Stop` stops, `Warn` is printed and the count is 0. | R-SH8 |
## | 5 | Output: `Share.status_lines` or the envelope with `Share.status_data`. No lock, no write. | R-SH8, R-OUT2 |
ShareFlow :: [].{

	status! : Fx, Args => I32
	status! = |fx, args| match status_flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(lines_and_data) => {
			show!(fx, args, lines_and_data.lines, lines_and_data.data)
			0
		}
	}

	on! : Fx, Args => I32
	on! = |fx, args| match on_flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(sends) => {
			show!(fx, args, Share.on_lines({ sends: sends }), Share.on_data({ sends: sends }))
			0
		}
	}

	## Slice 214 (R-SH11): the write after the first-run answer. The steps 2 and 3 of `on!` for true, the step 2 of `off!` for false. The queue is not touched.
	record! : Fx, Roots, Bool => Try({}, Fail)
	record! = |fx, roots, value| {
		_ = set_share!(fx, Roots.item(roots, Item.Config), value)?
		if value ensure_id!(fx, Roots.item(roots, Item.ShareJson)) else Ok({})
	}

	## Slice 216 (Q452): `share.json` under its lock for the send: the file that is there (`ShareJson.read`), or a new file with a new id (the write of `tln share on`).
	ensure_doc! : Fx, Str => Try(ShareJson.Doc, Fail)
	ensure_doc! = |fx, path| fx.locked!(path, || make_id!(fx, path))

	## Slice 216 (R-SH6): the totals write. Under the lock: `read_files!`, `edit` of the doc that is there (a missing file is a new file with a new id), then the write of 213b (temp, `chmod 0600`, `rename`).
	totals_write! : Fx, Str, (ShareJson.Doc -> ShareJson.Doc) => Try({}, Fail)
	totals_write! = |fx, path, edit| fx.locked!(
		path,
		|| {
			doc = make_id!(fx, path)?
			_ = rewrite!(fx, path, ShareJson.text(edit(doc)))?
			Ok({})
		},
	)

	## Slice 220 (R-SH8, R-AP35): the account part of `tln share`, called by `status_flow!` only when `doc.token` is set (stub; with no JWT the flow uses `None` and makes no call, so `sh5` and the text runs of `sh3` stay green in the red state). The steps are in the slice file `docs/slices/220-share-logout-forget.md`.
	## `registry` and `offline` are the facts that the status already has. Gives `None` (no JWT; direct or `--offline`; or the GET failed: the warning is printed to stderr by this function and the JWT stays, Q478, Q479), the tracker to show, or `LoginNeeded` (the JWT was removed under the lock: a 401, or at or past its time).
	status_account! : Fx, { registry : Net.Registry, offline : Bool, path : Str, doc : ShareJson.Doc } => Try([None, Tracker(Account.Tracker), LoginNeeded], Fail)
	status_account! = |_fx, _facts| crash "todo: slice 220"

	off! : Fx, Args => I32
	off! = |fx, args| match off_flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok({}) => {
			show!(fx, args, Share.off_lines({}), Share.off_data({}))
			0
		}
	}
}

# Step 6: the text, or only the envelope with `--json`.
show! : Fx, Args, List(Str), JsonDoc => {}
show! = |fx, args, lines, data| if args.json {
	fx.out!(Out.json_ok({ command: args.typed, data }))
} else {
	for line in lines {
		fx.out!(line)
	}
}

# `read_files!` of one file: a missing file is `Err(Missing)`.
read_file! : Fx, Str => Try(Str, [Missing])
read_file! = |fx, path| match fx.read_files!([path]) {
	[Ok(text)] => Ok(text)
	_ => Err(Missing)
}

# Steps 1 to 5 of `on`.
on_flow! : Fx, Args => Try(Bool, Fail)
on_flow! = |fx, args| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	text = set_share!(fx, Roots.item(roots, Item.Config), Bool.True)?
	ensure_id!(fx, Roots.item(roots, Item.ShareJson))?
	config = Share.setting({ path: Roots.item(roots, Item.Config), text })?
	registry = Net.registry({ flag: args.registry, env: Net.from_env(env).registry, config: config.registry })
	Ok(registry != Direct)
}

# Steps 1, 2 and 4 of `off`.
off_flow! : Fx, Args => Try({}, Fail)
off_flow! = |fx, _args| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	_ = set_share!(fx, Roots.item(roots, Item.Config), Bool.False)?
	path = Roots.item(roots, Item.CompatDb)
	match fx.db_write!({ path, busy_ms: Db.busy_ms, format: Db.format }, ClearQueue) {
		Ok(_) => Ok({})
		Err(err) => match Share.clear_err({ err, path }) {
			Stop(fail) => Err(fail)
			Warn(text) => {
				fx.err!("warning: ${text}\n")
				Ok({})
			}
		}
	}
}

# Step 2: the edit of `config.toml` under its lock. The result is the text of the file after the edit.
set_share! : Fx, Str, Bool => Try(Str, Fail)
set_share! = |fx, path, value| fx.locked!(path, || write_share!(fx, path, value))

write_share! : Fx, Str, Bool => Try(Str, Fail)
write_share! = |fx, path, value| {
	first = RocInstall.read_text!(fx, path)?
	done = Share.edit({ path, text: first, value })?
	match done.edit {
		Same => Ok(first)
		Set(_) => {
			second = RocInstall.read_text!(fx, path)?
			last = if second == first done else Share.edit({ path, text: second, value })?
			match last.edit {
				Same => Ok(second)
				Set(content) => match fx.write_atomic!([{ path, content }]) {
					Ok(_) => Ok(content)
					Err({ path: failed, err }) => Err(Fail.new(Environment, "cannot write ${failed}: ${Str.inspect(err)}"))
				}
			}
		}
	}
}

# Step 3: `share.json` under its lock. A file that is there is read and checked, never written.
ensure_id! : Fx, Str => Try({}, Fail)
ensure_id! = |fx, path| {
	_ = fx.locked!(path, || make_id!(fx, path))?
	Ok({})
}

make_id! : Fx, Str => Try(ShareJson.Doc, Fail)
make_id! = |fx, path| match read_file!(fx, path) {
	Ok(text) => ShareJson.read({ path, text })
	Err(Missing) => {
		high = fx.random!()
		low = fx.random!()
		doc = ShareJson.fresh(ShareJson.id_of({ high, low }))
		_ = rewrite!(fx, path, ShareJson.text(doc))?
		Ok(doc)
	}
}

rewrite! : Fx, Str, Str => Try({}, Fail)
rewrite! = |fx, path, content| if fx.windows!() write_direct!(fx, path, content) else write_via_temp!(fx, path, content)

# Windows: R-CC1 makes the temp file and the rename inside `write_atomic!`. No chmod.
write_direct! : Fx, Str, Str => Try({}, Fail)
write_direct! = |fx, path, content| match fx.write_atomic!([{ path, content }]) {
	Ok(_) => Ok({})
	Err({ path: failed, err }) => Err(Fail.new(Environment, "cannot write ${failed}: ${Str.inspect(err)}"))
}

# Q213, R-CC1: a temp file, `chmod 0600` on the temp, then `rename`. A failure of the chmod or the rename deletes the temp.
write_via_temp! : Fx, Str, Str => Try({}, Fail)
write_via_temp! = |fx, path, content| {
	temp = Temp.name({ target: path, hex: Temp.hex(fx.random!()) })
	match fx.write_atomic!([{ path: temp, content }]) {
		Ok(_) => {}
		Err({ path: failed, err }) => return Err(Fail.new(Environment, "cannot write ${failed}: ${Str.inspect(err)}"))
	}
	match set_mode!(fx, temp, path) {
		Err(fail) => return drop_temp!(fx, temp, fail)
		Ok({}) => {}
	}
	match fx.rename!({ from: temp, to: path }) {
		Ok(_) => Ok({})
		Err(err) => drop_temp!(fx, temp, Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}"))
	}
}

drop_temp! : Fx, Str, Fail => Try({}, Fail)
drop_temp! = |fx, temp, fail| {
	_ = fx.delete!([temp])
	Err(fail)
}

# R-SH5, R-SE15: `chmod 0600` of the temp file of `share.json`. The text names `target`. None on Windows.
set_mode! : Fx, Str, Str => Try({}, Fail)
set_mode! = |fx, file, target| match Share.chmod_command({ windows: fx.windows!(), file }) {
	Err(NotNeeded) => Ok({})
	Ok(argv) => match fx.spawn_all!({ jobs: [{ argv, cwd: Err(Inherit) }], limit: 1 }) {
		[done] => match done.ended {
			Exited(0) => Ok({})
			other => Err(Fail.new(Environment, "cannot set the mode of ${target}: ${Str.inspect(other)}"))
		}
		_ => Err(Fail.new(Internal, "spawn_all! gave no result"))
	}
}

# Steps 1 to 5 of `status`.
status_flow! : Fx, Args => Try({ lines : List(Str), data : JsonDoc }, Fail)
status_flow! = |fx, args| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	config_path = Roots.item(roots, Item.Config)
	config = Share.setting({ path: config_path, text: RocInstall.read_text!(fx, config_path)? })?
	registry = Net.registry({ flag: args.registry, env: Net.from_env(env).registry, config: config.registry })
	state = Share.state({ share: config.share, registry, offline: args.offline, env })
	json_path = Roots.item(roots, Item.ShareJson)
	doc = match read_file!(fx, json_path) {
		Ok(text) => ShareJson.read({ path: json_path, text })?
		# Q213: a missing file shows the id `none`. Nothing is written.
		Err(Missing) => ShareJson.absent({})
	}
	path = Roots.item(roots, Item.CompatDb)
	queued = match fx.db_query!({ path, busy_ms: Db.busy_ms, format: Db.format }, QueueCount) {
		Ok(QueueCount(n)) => n
		Ok(_) => 0
		Err(err) => match Db.on_err({ err, what: Read, path }) {
			Stop(fail) => return Err(fail)
			Warn(text) => {
				fx.err!("warning: ${text}\n")
				0
			}
		}
	}
	match doc.token {
		Ok(_) => {
			_ = ShareFlow.status_account!(fx, { registry, offline: args.offline, path: json_path, doc })?
		}
		Err(Unset) => {}
	}
	Ok({ lines: Share.status_lines({ state, doc, queued }), data: Share.status_data({ state, doc, queued }) })
}
