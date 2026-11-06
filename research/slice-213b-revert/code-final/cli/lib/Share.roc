import Db
import Fail
import JsonDoc
import Net
import ShareJson
import TomlKeys
import toml.Toml
import toml.Value

## The pure decisions of `tln share` (slice 213, CLI 1 R-SH1, R-SH2, R-SH8, R-SH10, R-CM23). The calls are in `ShareFlow`.
## Slice 215 uses `state` for the queue (R-SH2: "when a fact goes into the queue, and again before it sends").
Share :: [].{

	## The condition of R-SH2 that is false (the number is the row of the table): 1 `Share`, 2 `Registry`, 3 `Offline`, 4 `DoNotTrack`, 5 `Ci`.
	Reason : [Share, Registry, Offline, DoNotTrack, Ci]

	## R-SH2: `On` when the 5 conditions are true. Else `Off` with the first condition that is false, in the order of the table. The conditions:
	##
	## | # | Is true when | Rule |
	## | --- | --- | --- |
	## | 1 | `share` is `Ok(True)` | R-SH1 |
	## | 2 | `registry` is `Url(_)` | R-RG1 |
	## | 3 | `offline` is false | R-FL3 |
	## | 4 | `DO_NOT_TRACK` is not in `env`, or is empty, or is `0` | R-EV26 |
	## | 5 | `CI` is not `true` or `1` (any case), as the row `CI` of R-NM1. `TALON_INTERACTIVE`, `DEBIAN_FRONTEND`, `NONINTERACTIVE` and `--json` change nothing. | R-NM1 |
	state : { share : Try(Bool, [Unset]), registry : Net.Registry, offline : Bool, env : List((Str, Str)) } -> [On, Off(Share.Reason)]
	state = |facts| {
		env_value = |name| facts.env.find_first(|(key, _)| key == name).map_ok(|(_, value)| value)
		do_not_track = match env_value("DO_NOT_TRACK") {
			Ok(value) => value != "" and value != "0"
			Err(_) => Bool.False
		}
		ci = match env_value("CI") {
			Ok(value) => ["true", "1"].contains(value.with_ascii_lowercased())
			Err(_) => Bool.False
		}
		if facts.share != Ok(Bool.True) {
			Off(Share)
		} else if facts.registry == Direct {
			Off(Registry)
		} else if facts.offline {
			Off(Offline)
		} else if do_not_track {
			Off(DoNotTrack)
		} else if ci {
			Off(Ci)
		} else {
			On
		}
	}

	## R-SH1, R-TF4: the keys `share` and `registry` of the text of a `config.toml`. `share` that is not `true` or `false` is a failure of kind `Input` (exit 19):
	## `<path>:<line>: share: must be true or false`. Text that is not TOML: `<path>:<line>: not valid TOML`. `registry` is `Ok(text)` for a text, else `Unset`
	## (the check of its form is slice 224, R-RG7). Other keys are not read.
	setting : { path : Str, text : Str } -> Try({ share : Try(Bool, [Unset]), registry : Try(Str, [Unset]) }, Fail)
	setting = |facts| {
		doc = parse_toml(facts.path, facts.text)?
		share = share_of(facts.path, doc)?
		registry = match Toml.get(doc, ["registry"]) {
			Ok(Value.String(text)) => Ok(text)
			_ => Err(Unset)
		}
		Ok({ share, registry })
	}

	## R-SH1, R-CC6, R-CC7: the edit of `config.toml` for `tln share on` (`value` true) and `off` (`value` false), as `Manage.default_set` does it for `default-roc`.
	##
	## | `share` in the text | Result | `previous` |
	## | --- | --- | --- |
	## | The same boolean as `value` | `Same` | `Ok(value)` |
	## | The other boolean | `Set(<new text>)`: `Toml.replace`, every other byte stays | `Ok(<old>)` |
	## | Not there | `Set(<new text>)`: `Toml.insert` of the line `share = true` or `share = false` (the empty text gives the one line and a line end) | `Err(Unset)` |
	## | Not a boolean | a failure of kind `Input`, as `setting` | |
	##
	## Text that is not TOML: a failure of kind `Input`, as `setting`.
	edit : { path : Str, text : Str, value : Bool } -> Try({ previous : Try(Bool, [Unset]), edit : [Same, Set(Str)] }, Fail)
	edit = |facts| {
		doc = parse_toml(facts.path, facts.text)?
		previous = share_of(facts.path, doc)?
		value = Value.Boolean(facts.value)
		if previous == Ok(facts.value) {
			Ok({ previous, edit: Same })
		} else {
			done = match previous {
				Ok(_) => Toml.replace(doc, ["share"], value).map_err(|_| cannot_write(facts.path))?
				Err(Unset) => Toml.insert(doc, ["share"], value).map_err(|_| cannot_write(facts.path))?
			}
			Ok({ previous, edit: Set(done.to_str()) })
		}
	}

	## R-SH8 (proposal, TW24): the text of the condition that turns sharing off. `Share` is `share is not true in config.toml`, `Registry` is `the registry is direct`,
	## `Offline` is `--offline is set`, `DoNotTrack` is `DO_NOT_TRACK is set`, `Ci` is `CI is set`.
	reason_text : Share.Reason -> Str
	reason_text = |reason| match reason {
		Share => "share is not true in config.toml"
		Registry => "the registry is direct"
		Offline => "--offline is set"
		DoNotTrack => "DO_NOT_TRACK is set"
		Ci => "CI is set"
	}

	## R-SH8 (proposal, TW24): the word of the condition in `--json`: `share`, `registry`, `offline`, `do-not-track`, `ci`.
	reason_word : Share.Reason -> Str
	reason_word = |reason| match reason {
		Share => "share"
		Registry => "registry"
		Offline => "offline"
		DoNotTrack => "do-not-track"
		Ci => "ci"
	}

	## R-SH8, R-SH5, R-SH6 (the local part, proposal, TW24): the lines of `tln share`, each with a line end. `sharing: on`, or `sharing: off (<reason_text>)`; `id: <first 8 characters>`;
	## `sent: <n>`; `counted: <n>`; `first: <n>`; `first sent: <time>` and `last sent: <time>` only when the time is set; `queued: <n>`. The id is never printed whole (R-SH5, R-SE15).
	status_lines : { state : [On, Off(Share.Reason)], doc : ShareJson.Doc, queued : U64 } -> List(Str)
	status_lines = |facts| {
		doc = facts.doc
		head = match facts.state {
			On => "sharing: on\n"
			Off(reason) => "sharing: off (${Share.reason_text(reason)})\n"
		}
		time_line = |label, time| match time {
			Ok(text) => ["${label}: ${text}\n"]
			Err(Unset) => []
		}
		[head, "id: ${short_id(doc.id)}\n", "sent: ${doc.sent.to_str()}\n", "counted: ${doc.counted.to_str()}\n", "first: ${doc.first.to_str()}\n"]
			.concat(time_line("first sent", doc.first_sent_at))
			.concat(time_line("last sent", doc.last_sent_at))
			.concat(["queued: ${facts.queued.to_str()}\n"])
	}

	## R-SH8, R-OUT2 (proposal, TW24): the `data` of `tln share --json`: `{"on":<bool>,"reason":<word or null>,"id":<first 8 characters, or null when there is no share.json (Q217)>,"sent":<n>,"counted":<n>,"first":<n>,
	## "first_sent_at":<text or null>,"last_sent_at":<text or null>,"queued":<n>}`.
	status_data : { state : [On, Off(Share.Reason)], doc : ShareJson.Doc, queued : U64 } -> JsonDoc
	status_data = |facts| {
		doc = facts.doc
		reason = match facts.state {
			On => JsonDoc.Null
			Off(why) => JsonDoc.Text(Share.reason_word(why))
		}
		time_doc = |time| match time {
			Ok(text) => JsonDoc.Text(text)
			Err(Unset) => JsonDoc.Null
		}
		JsonDoc.Obj([
			("on", JsonDoc.Flag(facts.state == On)),
			("reason", reason),
			("id", if doc.id == "none" JsonDoc.Null else JsonDoc.Text(short_id(doc.id))),
			("sent", num(doc.sent)),
			("counted", num(doc.counted)),
			("first", num(doc.first)),
			("first_sent_at", time_doc(doc.first_sent_at)),
			("last_sent_at", time_doc(doc.last_sent_at)),
			("queued", num(facts.queued)),
		])
	}

	## R-SH10, R-SH1 (proposal, TW24): the lines of `tln share on`: `sharing: on`, and with `sends` false (the registry is `direct`) the second line `Talon shares nothing while the registry is direct.`.
	## Each line has a line end.
	on_lines : { sends : Bool } -> List(Str)
	on_lines = |facts| if facts.sends ["sharing: on\n"] else ["sharing: on\n", "Talon shares nothing while the registry is direct.\n"]

	## R-SH10 (proposal, TW24): the `data` of `tln share on --json`: `{"share":true,"sends":<bool>}`.
	on_data : { sends : Bool } -> JsonDoc
	on_data = |facts| JsonDoc.Obj([("share", JsonDoc.Flag(Bool.True)), ("sends", JsonDoc.Flag(facts.sends))])

	## R-SH4, R-SH1 (proposal, TW24): the line of `tln share off`: `sharing: off`, with a line end. The `data` is `{"share":false}`.
	off_lines : {} -> List(Str)
	off_lines = |{}| ["sharing: off\n"]

	off_data : {} -> JsonDoc
	off_data = |{}| JsonDoc.Obj([("share", JsonDoc.Flag(Bool.False))])

	## R-SH5, R-SE15 (Q1, answered by the manager 2026-11-02, as R-HF2 `Toolchain.chmod_command`): the command line that sets the mode of `share.json`: `chmod 0600 <file>`.
	## A Windows host needs none: `Err(NotNeeded)`. The flow runs it with `spawn_all!` (limit 1) after the write of the file, and takes `windows` from `Fx.windows!`.
	chmod_command : { windows : Bool, file : Str } -> Try(List(Str), [NotNeeded])
	chmod_command = |facts| if facts.windows Err(NotNeeded) else Ok(["chmod", "0600", facts.file])

	## D7 (proposal, TW24): what `tln share off` does with a failed `ClearQueue`. `TooNew` is `Db.on_err` for a write (exit 19). A busy file is the warning
	## `compat.db is busy: the share queue is not emptied`. Any other failure is `cannot use <path> (<text>): the share queue is not emptied`. (The text of `Db.on_err` says "the facts of this command" and is wrong here.)
	clear_err : { err : Db.Err, path : Str } -> [Stop(Fail), Warn(Str)]
	clear_err = |facts| match facts.err {
		TooNew(_) => match Db.on_err({ err: facts.err, what: Write, path: facts.path }) {
			Stop(fail) => Stop(fail)
			Warn(text) => Warn(text)
		}
		Busy => Warn("compat.db is busy: the share queue is not emptied")
		Failed(text) => Warn("cannot use ${facts.path} (${text}): the share queue is not emptied")
	}
}

# `<path>:<line>: not valid TOML`, as `Manage.default_set`.
parse_toml : Str, Str -> Try(Toml, Fail)
parse_toml = |path, text| match Toml.parse(text) {
	Ok(doc) => Ok(doc)
	Err(TomlErr(e)) => Err(Fail.new(Input, "${path}:${e.line.to_str()}: not valid TOML"))
}

# R-TF4: the key `share` is a boolean.
share_of : Str, Toml -> Try(Try(Bool, [Unset]), Fail)
share_of = |path, doc| match Toml.get(doc, ["share"]) {
	Err(NotFound) => Ok(Err(Unset))
	Ok(Value.Boolean(b)) => Ok(Ok(b))
	Ok(_) => Err(Fail.new(Input, "${path}:${TomlKeys.key_line(doc, ["share"]).to_str()}: share: must be true or false"))
}

cannot_write : Str -> Fail
cannot_write = |path| Fail.new(Internal, "${path}: cannot write share")

# R-SH5, R-SE15: only the first 8 characters of the id are shown.
short_id : Str -> Str
short_id = |id| Str.from_utf8_lossy(id.to_utf8().sublist({ start: 0, len: 8 }))

num : U64 -> JsonDoc
num = |n| JsonDoc.Num(n.to_i64_wrap())
