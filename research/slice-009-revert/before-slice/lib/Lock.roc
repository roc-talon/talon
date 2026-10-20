import Text

## The pure decisions of a lock (CLI 7.4, R-CC3, R-CC5, R-CC12). The real `Fx` makes the lock directory and
## writes the files (`Fx.lock!`, `Fx.unlock!`). It calls these functions for each decision.
##
## | Item | Rule |
## | --- | --- |
## | The item | A path, for example `<cache>/talon/projects.json`. `Roots.item` gives it. |
## | The lock | The directory `<item>.lock/` (R-CC3 point 4, R-CC12). It holds the files `owner` and `beat`. |
## | `owner` | `Lock.owner_text`: the token and the start time |
## | `beat` | Written again every 2 s by the real `Fx`, inside its own waits. Its modification time is its age. |
## | Stale | The age is more than 30 s (R-CC12) |
## | Wait | `lock!` with `Wait` checks every 200 ms (R-CC12) |
##
## A `Lock` is the value that `Fx.lock!` gives and `Fx.unlock!` takes: the item and the token of the holder.
Lock := { item : Str, token : Str }.{
	is_eq : _

	## The lock directory of an item: the item path and `.lock` (R-CC3 point 4, R-LY3).
	## `/c/talon/projects.json` gives `/c/talon/projects.json.lock`.
	dir : Str -> Str
	dir = |item| "${item}.lock"

	## Live or stale (R-CC12). All times are seconds since the epoch. `now` is the real clock, never `TALON_NOW`
	## (R-EV22). `beat` is the modification time of `beat`, or `NoBeat` when the file does not exist (a crash between
	## `create_dir!` and the first write of `beat`). Then the age of the directory is used: `dir` is its modification time.
	## An age of more than 30 s is `Stale`. An age of exactly 30 s is `Live`. A time in the future (clock skew) is `Live`.
	state : { now : U64, beat : Try(U64, [NoBeat]), dir : U64 } -> [Live, Stale]
	state = |facts| {
		stamp = match facts.beat {
			Ok(beat) => beat
			Err(NoBeat) => facts.dir
		}
		if facts.now > stamp and facts.now - stamp > 30 Stale else Live
	}

	## The text of the file `owner` (R-CC12): the token, a newline, the start time in seconds, a newline.
	## The form is a proposal (the design names the content, not the form).
	owner_text : { token : Str, started : U64 } -> Str
	owner_text = |facts| "${facts.token}\n${facts.started.to_str()}\n"

	## Does the text of `owner` hold this token (R-CC12: `unlock!` deletes the directory only when `owner` holds its own
	## token)? True when the first line of `owner` equals the token. A missing or empty `owner` is false.
	owns : { owner : Str, token : Str } -> Bool
	owns = |facts| match facts.owner.split_on("\n") {
		[first, ..] => first == facts.token and !facts.token.is_empty()
		[] => Bool.False
	}

	## The name that `lock!` gives to a stale lock directory before it deletes it (R-CC12):
	## `<item>.lock.<hex>.stale`. `hex` is 16 hex digits.
	stale_name : { item : Str, hex : Str } -> Str
	stale_name = |facts| "${Lock.dir(facts.item)}.${facts.hex}.stale"

	## The line that a process prints once when it waits for a lock (R-CC5): `waiting for another tln: <name>\n`.
	## `<name>` is the last segment of the item path, as in the design example (`nightly-2026-10-13-91fa0c2`).
	## This is question Q1 of the slice file.
	waiting_line : Str -> Str
	waiting_line = |item| "waiting for another tln: ${Text.last_segment(item)}\n"
}
