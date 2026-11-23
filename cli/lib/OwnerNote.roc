import records.Closure as Wire
import JsonDoc
import Text

## Slice 254 (docs/slices/254-add-moved-owner-note.md, Registry R-PU30, R-SE14; Design Q634). The owner change note of `tln update`, `tln upgrade` and `tln outdated`. Pure (TESTING.md 2.2).
## The tests are `tests/unit/OwnerNoteTest.roc`.
OwnerNote :: [].{

	## One note: a header entry (`alias`, `name` of its value) whose `repos` item has `owner_changed` after the release of the header value (Q254-1, Q254-2).
	## `owner` is the owner part of the `successor` of the item for a `transfer` with a successor, else `Err(None)` (Q254-3).
	Note : { alias : Str, name : Str, action : [Transfer, Recreate], at : U64, owner : Try(Str, [None]) }

	## T3: `YYYY-MM-DD` of a time in ms (R-AP50), in UTC, rounded down to the day.
	date_text : U64 -> Str
	date_text = |ms| {
		# Civil date from days since 1970-01-01 (proleptic Gregorian). `z` counts from 0000-03-01.
		z = ms // 86400000 + 719468
		era = z // 146097
		doe = z - era * 146097
		yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
		doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
		mp = (5 * doy + 2) // 153
		day = doy - (153 * mp + 2) // 5 + 1
		month = if (mp < 10) mp + 3 else mp - 9
		year = yoe + era * 400 + (if (month <= 2) 1 else 0)
		"${year.to_str()}-${two(month)}-${two(day)}"
	}

	## R-PU30, Q254-1, Q254-2, Q254-7, Q254-8: the notes of the header entries. `entries` are the header entries before the command (the alias, the full name of the value, the hash of the value).
	## `releases` are the release rows of the answers (the hash and `published_at`). Names are compared in lower case. One note for each (alias, name) pair, sorted by alias (bytes).
	find : { entries : List({ alias : Str, name : Str, hash : Str }), repos : List(Wire.Repo), releases : List({ hash : Str, published_at : U64 }) } -> List(OwnerNote.Note)
	find = |facts| {
		var $found = []
		for e in facts.entries {
			name = e.name.with_ascii_lowercased()
			item = facts.repos.find_first(|r| r.name.with_ascii_lowercased() == name)
			seen = $found.any(|n| n.alias == e.alias and n.name == e.name)
			match (item, seen) {
				(Ok(repo), Bool.False) => match repo.owner_changed {
					Ok(o) => {
						before = match facts.releases.find_first(|r| r.hash == e.hash) {
							Ok(r) => o.at <= r.published_at
							Err(_) => Bool.False
						}
						if !before {
							owner = if o.action == Transfer {
								match repo.successor {
									Ok(s) => match s.split_first("/") {
										Ok({ before: who, .. }) => Ok(who)
										Err(_) => Err(None)
									}
									Err(None) => Err(None)
								}
							} else {
								Err(None)
							}
							$found = $found.append({ alias: e.alias, name: e.name, action: o.action, at: o.at, owner })
						}
					}
					Err(None) => {}
				}
				_ => {}
			}
		}
		$found.sort_with(|a, b| Text.compare(a.alias, b.alias))
	}

	## T4 to T6: the text of a note (with no `warning: ` prefix).
	text : OwnerNote.Note -> Str
	text = |n| match n.action {
		Recreate => "${n.alias}: the repository was made again by the same owner on ${OwnerNote.date_text(n.at)}"
		Transfer => "${n.alias}: transferred to ${n.owner ?? "another GitHub account"} on ${OwnerNote.date_text(n.at)}"
	}

	## T4 to T7: the item of `data.owner_changes`.
	doc : OwnerNote.Note -> JsonDoc
	doc = |n| Obj([
		("alias", Text(n.alias)),
		("name", Text(n.name)),
		("action", Text(if (n.action == Transfer) "transfer" else "recreate")),
		("at", Num(n.at.to_i64_wrap())),
		(
			"owner",
			match n.owner {
				Ok(o) => Text(o)
				Err(None) => Null
			},
		),
		("text", Text(OwnerNote.text(n))),
	])
}

two : U64 -> Str
two = |n| if (n < 10) "0${n.to_str()}" else n.to_str()
