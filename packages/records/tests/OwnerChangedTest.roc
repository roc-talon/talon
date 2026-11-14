import records.Closure
import records.Index

OwnerChangedTest :: [].{}

# W0 tests of the member `owner_changed` of a `repos` item (slice 247b, docs/slices/247-move.md section 10). The rules are R-AP32, R-PU30 (Design Q626), R-AP51 (the member is always written, `null` for none),
# R-AP44 (an unknown member is ignored, a missing member of an older answer is none), R-AP50 (`at` is milliseconds).

base : Closure.Repo
base = { name: "a/b", state: Active, successor: Err(None), state_at: 5, owner_changed: Err(None) }

xfer : Closure.Repo
xfer = { ..base, owner_changed: Ok({ action: Transfer, at: 1767225630000 }) }

again : Closure.Repo
again = { name: "c/d", state: Moved, successor: Ok("e/f"), state_at: 7, owner_changed: Ok({ action: Recreate, at: 1767100000000 }) }

js : Str -> Str
js = |t| t.replace_each("'", "\"")

# R-AP32, R-PU30: the member is `null` for none, and the object `{"action","at"}` for the last transfer or recreate. The members are in the order of the derived codec (alphabetical).
expect Closure.encode_repo(base) == js("{'name':'a/b','owner_changed':null,'state':'active','state_at':5,'successor':null}")
expect Closure.encode_repo(xfer) == js("{'name':'a/b','owner_changed':{'action':'transfer','at':1767225630000},'state':'active','state_at':5,'successor':null}")
expect Closure.encode_repo(again) == js("{'name':'c/d','owner_changed':{'action':'recreate','at':1767100000000},'state':'moved','state_at':7,'successor':'e/f'}")

# The round trip of the 3 items.
expect [base, xfer, again].all(|r| Closure.decode_repo(Closure.encode_repo(r)) == Ok(r))

# R-AP44: the answer of an older Worker has no member: it is none. `null` is none. An unknown member of the object is ignored.
expect Closure.decode_repo(js("{'name':'a/b','state':'active','state_at':5,'successor':null}")) == Ok(base)
expect Closure.decode_repo(js("{'name':'a/b','owner_changed':null,'state':'active','state_at':5,'successor':null}")) == Ok(base)
expect Closure.decode_repo(js("{'name':'a/b','owner_changed':{'action':'transfer','at':1767225630000,'by':'x'},'state':'active','state_at':5,'successor':null}")) == Ok(xfer)

# R-AP51: an `action` that is not `transfer` or `recreate`, a missing `at` or `action`, an `at` that is not a number, and a member that is not an object are `BadJson`.
expect {
	bad = |member| match Closure.decode_repo(js("{'name':'a/b','owner_changed':${member},'state':'active','state_at':5,'successor':null}")) {
		Err(BadJson(_)) => Bool.True
		Ok(_) => Bool.False
	}
	[
		bad("{'action':'rename','at':1}"),
		bad("{'action':'Transfer','at':1}"),
		bad("{'action':'transfer'}"),
		bad("{'at':1}"),
		bad("{'action':'transfer','at':'now'}"),
		bad("{'action':null,'at':1}"),
		bad("5"),
		bad("'transfer'"),
		bad("[]"),
	].all(|b| b)
}

# R-AP17: the closure answer has the member in each item of `repos`, and a decode of an older answer (no member) gives none for each.
expect {
	row : Closure.Answer
	row = { artifacts: [], releases: [], epochs: [], runs: [], nearest: [], hints: [], log_size: 3, unknown: [], checked: [], repos: [xfer, again, base] }
	text = Closure.encode_answer(row)
	older = text.replace_each(",\"owner_changed\":null", "").replace_each("\"owner_changed\":null,", "")
	[
		text.contains(js("'owner_changed':{'action':'transfer','at':1767225630000}")),
		text.contains(js("'owner_changed':{'action':'recreate','at':1767100000000}")),
		text.contains(js("'owner_changed':null")),
		Closure.decode_answer(text) == Ok(row),
		Closure.decode_answer(older) == Ok({ ..row, repos: [xfer, again, base] }),
	].all(|b| b)
}

# R-AP1, R-AP2, R-AP13, R-AP14: the 3 read answers of `Index` write and read the member in their `repos` items.
expect {
	releases = Index.encode_releases({ releases: [], checked: Err(None), repos: [xfer] })
	page = Index.encode_page({ releases: [], repos: [again, base] })
	[
		releases.contains(js("'repos':[{'name':'a/b','owner_changed':{'action':'transfer','at':1767225630000},'state':'active'")),
		page.contains(js("'owner_changed':{'action':'recreate','at':1767100000000}")),
		page.contains(js("'owner_changed':null")),
		Index.decode_releases(releases) == Ok({ releases: [], checked: Err(None), repos: [xfer] }),
		Index.decode_page(page) == Ok({ releases: [], repos: [again, base] }),
	].all(|b| b)
}
