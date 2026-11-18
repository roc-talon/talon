import lib.OwnerNote
import lib.JsonDoc

OwnerNoteTest :: [].{}

# Slice 254 (docs/slices/254-add-moved-owner-note.md, Design Q634). Pure: the client part of Registry R-PU30 (the owner change note, R-SE14).
# Names for the code agent (`cli/lib/OwnerNote.roc` has the stubs):
#   `OwnerNote.date_text : U64 -> Str`
#   `OwnerNote.find : { entries : List({ alias, name, hash }), repos : List(Repo), releases : List({ hash, published_at }) } -> List(Note)`
#   `OwnerNote.text : Note -> Str`, `OwnerNote.doc : Note -> JsonDoc`
# Times: 1748736000000 is 2025-06-01 00:00 UTC (the release), 1767100000000 is 2025-12-30 13:06:40 UTC (a transfer), 1767200000000 is 2025-12-31 16:53:20 UTC (a recreate).

published = 1748736000000.U64

hash_a = "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21"

hash_b = "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq"

item = |name, state, successor, owner_changed| { name, state, successor, state_at: 1700000000000, owner_changed }

recreated = |name, at| item(name, Active, Err(None), Ok({ action: Recreate, at }))

transferred_to = |name, to, at| item(name, Moved, Ok(to), Ok({ action: Transfer, at }))

plain = |name| item(name, Active, Err(None), Err(None))

entry = |alias, name, hash| { alias, name, hash }

release = |hash, at| { hash, published_at: at }

note = |alias, name, action, at, owner| { alias, name, action, at, owner }

# T3 (Design Q634): `YYYY-MM-DD` in UTC.
expect OwnerNote.date_text(0) == "1970-01-01"

# T3: the time is 16:53 UTC. A local time zone of UTC+8 or more would give 2026-01-01: the date is the UTC date.
expect OwnerNote.date_text(1767200000000) == "2025-12-31"

# T3: the first ms of a day, and the last ms of the day before (rounded down, not to the nearest day).
expect OwnerNote.date_text(1767225600000) == "2026-01-01"

expect OwnerNote.date_text(1767225599999) == "2025-12-31"

# T3: a leap day, the day after it, and the day after the 400-year leap day of 2000 (two digits for the month and the day).
expect OwnerNote.date_text(1709164800000) == "2024-02-29"

expect OwnerNote.date_text(1709251200000) == "2024-03-01"

expect OwnerNote.date_text(951868800000) == "2000-03-01"

# R-PU30, Q254-1: a `recreate` after the release of the header value: one note. A recreate has no owner.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [recreated("someone/roc-json", 1767200000000)], releases: [release(hash_a, published)] }) == [note("json", "someone/roc-json", Recreate, 1767200000000, Err(None))]

# R-PU30, Q254-3 (a): a `transfer` after the release, the item is moved to acme/roc-json: the owner is the owner part of the successor.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [transferred_to("someone/roc-json", "acme/roc-json", 1767100000000)], releases: [release(hash_a, published)] }) == [note("json", "someone/roc-json", Transfer, 1767100000000, Ok("acme"))]

# Q254-3 (a): a `transfer` and the item has no successor (a new account with the old login): no owner.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [item("someone/roc-json", Active, Err(None), Ok({ action: Transfer, at: 1767100000000 }))], releases: [release(hash_a, published)] }) == [note("json", "someone/roc-json", Transfer, 1767100000000, Err(None))]

# R-PU30, Q254-1: the event is before the release: no note.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [recreated("someone/roc-json", published - 1000)], releases: [release(hash_a, published)] }) == []

# Q254-1 (a): the event at the same ms as the release is not "after": no note.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [recreated("someone/roc-json", published)], releases: [release(hash_a, published)] }) == []

# R-PU30, Design Q626 (12): `owner_changed` is null: no note.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [plain("someone/roc-json")], releases: [release(hash_a, published)] }) == []

# B6, Design Q406: no `repos` item for the name (direct, another host): no note.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [], releases: [release(hash_a, published)] }) == []

# R-AP56: the names are compared in lower case. The note keeps the name of the entry.
expect OwnerNote.find({ entries: [entry("json", "Someone/Roc-Json", hash_a)], repos: [recreated("someone/roc-json", 1767200000000)], releases: [release(hash_a, published)] }) == [note("json", "Someone/Roc-Json", Recreate, 1767200000000, Err(None))]

# Q254-2 (a): the header value is not in the answer (no `published_at`): the note is printed.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [recreated("someone/roc-json", 1767200000000)], releases: [release(hash_b, published)] }) == [note("json", "someone/roc-json", Recreate, 1767200000000, Err(None))]

# Q254-8 (a): two aliases of one repository: one note for each alias, sorted by alias (bytes).
expect OwnerNote.find({ entries: [entry("json2", "someone/roc-json", hash_a), entry("json", "someone/roc-json", hash_a)], repos: [recreated("someone/roc-json", 1767200000000)], releases: [release(hash_a, published)] }) == [note("json", "someone/roc-json", Recreate, 1767200000000, Err(None)), note("json2", "someone/roc-json", Recreate, 1767200000000, Err(None))]

# Q254-8 (a): the same alias and name in 2 members of a workspace: one note.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a), entry("json", "someone/roc-json", hash_a)], repos: [recreated("someone/roc-json", 1767200000000)], releases: [release(hash_a, published)] }) == [note("json", "someone/roc-json", Recreate, 1767200000000, Err(None))]

# R-PU30: each entry is compared with its own release and its own item. Only the entry of the changed repository gets a note.
expect OwnerNote.find({ entries: [entry("pf", "acme/pfx", hash_b), entry("json", "someone/roc-json", hash_a)], repos: [plain("acme/pfx"), recreated("someone/roc-json", 1767200000000)], releases: [release(hash_b, published), release(hash_a, published)] }) == [note("json", "someone/roc-json", Recreate, 1767200000000, Err(None))]

# Q254-7 (a): the release of the header value decides, not a newer release of the same repository in the answer.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [recreated("someone/roc-json", 1767200000000)], releases: [release(hash_a, published), release(hash_b, 1767300000000)] }) == [note("json", "someone/roc-json", Recreate, 1767200000000, Err(None))]

# T4 (Design Q634): the text of a recreate.
expect OwnerNote.text(note("json", "someone/roc-json", Recreate, 1767200000000, Err(None))) == "json: the repository was made again by the same owner on 2025-12-31"

# T5: the text of a transfer with an owner.
expect OwnerNote.text(note("json", "someone/roc-json", Transfer, 1767100000000, Ok("acme"))) == "json: transferred to acme on 2025-12-30"

# T6: the text of a transfer with no owner.
expect OwnerNote.text(note("json", "someone/roc-json", Transfer, 1767100000000, Err(None))) == "json: transferred to another GitHub account on 2025-12-30"

# T4, T7: the item of `data.owner_changes` (members in this order; `owner` is null for none).
expect OwnerNote.doc(note("json", "someone/roc-json", Recreate, 1767200000000, Err(None))).render() == "{\"alias\":\"json\",\"name\":\"someone/roc-json\",\"action\":\"recreate\",\"at\":1767200000000,\"owner\":null,\"text\":\"json: the repository was made again by the same owner on 2025-12-31\"}"

# T5, T7: a transfer has the owner text.
expect OwnerNote.doc(note("json", "someone/roc-json", Transfer, 1767100000000, Ok("acme"))).render() == "{\"alias\":\"json\",\"name\":\"someone/roc-json\",\"action\":\"transfer\",\"at\":1767100000000,\"owner\":\"acme\",\"text\":\"json: transferred to acme on 2025-12-30\"}"

# Q254-3 (a), mutation gap of slice 254 (m7): a recreate has no owner, also when the item is `moved` with a successor (a rename after the recreate, R-TP10). Only a transfer takes the owner of the successor.
expect OwnerNote.find({ entries: [entry("json", "someone/roc-json", hash_a)], repos: [item("someone/roc-json", Moved, Ok("acme/roc-json"), Ok({ action: Recreate, at: 1767200000000 }))], releases: [release(hash_a, published)] }) == [note("json", "someone/roc-json", Recreate, 1767200000000, Err(None))]
