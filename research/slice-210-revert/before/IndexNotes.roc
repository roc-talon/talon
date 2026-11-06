import records.Closure as Wire
import JsonDoc

## The notes about the age of the registry index (slice 210; Registry R-AP29, R-AP30, R-AP64; CLI R-OUT2, R-FL4, R-J3).
## `tln update`, `tln outdated` and `tln add` print one note for each repository whose `checked` item of the closure answer is `stale`. The note does not change the exit code.
## The pure functions are L0 (`tests/unit/IndexnotesTest.roc`). The print of the notes in a whole command is slice 206b.
IndexNotes :: [].{

	## R-AP30 (proposal, TW24): the age in the note. Input: seconds. Output: whole days when the age is 86400 s or more (`3d`), else whole hours when it is 3600 s or more (`5h`), else whole minutes (`12m`, `0m` below one minute). Every unit rounds down.
	age_text : U64 -> Str
	age_text = |_seconds| crash "todo: slice 210"

	## R-AP29, R-AP30: the note of one `checked` item, with no `note: ` prefix.
	##
	## | # | Item | Result |
	## | --- | --- | --- |
	## | 1 | `stale` is false | `Err(Fresh)`: no note (also when `checked_at` is null: Talon follows `stale`, the Worker computes it, R-AP29) |
	## | 2 | `stale` is true, `checked_at` is a time | `index: <name> checked <age> ago`. `<name>` is the `name` of the item as it is. `<age>` is `age_text` of `now` minus `checked_at` / 1000 (R-AP50: milliseconds; `now` is in seconds). A time after `now` gives age 0 |
	## | 3 | `stale` is true, `checked_at` is null | `index: <name> not checked since its first ingest` |
	note : { now : U64, item : Wire.Checked } -> Try(Str, [Fresh])
	note = |_facts| crash "todo: slice 210"

	## R-AP30 (proposal, R-OUT2): the `--json` note, an element of `notes[]`: an object with the keys `kind` (`"index-stale"`), `name`, `checked_at` (the integer of the wire, in milliseconds, or null) and `text` (the text of `note`). `Err(Fresh)` as `note`.
	json_note : { now : U64, item : Wire.Checked } -> Try(JsonDoc, [Fresh])
	json_note = |_facts| crash "todo: slice 210"

	## R-AP30, Design Q408: the notes of the answers of one command (1 answer, or 2 for a held move, R-AP16), one for each repository, sorted by `name` (bytes). Per repository (the same `name` in `checked` of both answers) the item that counts is the stale one; with 2 stale items, the one with the older `checked_at`, and null is older than any time. A repository with no stale item gives no note. No item: none.
	notes : { now : U64, answers : List(Wire.Answer) } -> List(Str)
	notes = |_facts| crash "todo: slice 210"

	## R-AP30, Design Q408: the `--json` notes of the answers: `json_note` of the same items as `notes`, in the same order.
	json_notes : { now : U64, answers : List(Wire.Answer) } -> List(JsonDoc)
	json_notes = |_facts| crash "todo: slice 210"

	## R-AP30, Design Q407: the member `index_notes` of `data`: `Ok(Arr(json_notes))`, or `Err(None)` when there is no note (the member is left out). The place in `data` is slice 206b.
	index_notes : { now : U64, answers : List(Wire.Answer) } -> Try(JsonDoc, [None])
	index_notes = |_facts| crash "todo: slice 210"
}
