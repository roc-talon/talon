import lib.Successor

SuccessorTest :: [].{}

# Slice 252 (docs/slices/252-successor-follow.md, Design Q632). Pure: the client part of Registry R-PU28 (`tln update <alias>` follows a successor), the chain of R-TP14 and R-SN8.
# Names for the code agent (a proposal, TW24; `cli/lib/Successor.roc` has the stubs):
#   `Successor.walk : { start : Str, repos : List(Repo) } -> { end : Str, state : [Active, Missing, Moved, Unknown], links : U64, stop : [Reached, Cut, Cycle] }`
#   `Successor.decide : { named : Bool, item : Try(Repo, [None]) } -> [Follow(Str), Stay]`
#   `Successor.chain_note : { alias : Str, start : Str, end : Str, stop : [Reached, Cut, Cycle] } -> Try(Str, [None])`
# R-PU30 (owner_changed) and R-PU29 (`tln add`) stay P3 and have no test here.

active = |name| { name, state: Active, successor: Err(None), state_at: 1700000000000, owner_changed: Err(None) }

missing = |name| { name, state: Missing, successor: Err(None), state_at: 1700000000000, owner_changed: Err(None) }

moved = |name, to| { name, state: Moved, successor: Ok(to), state_at: 1700000000000, owner_changed: Err(None) }

ends = |facts| {
	w = Successor.walk(facts)
	(w.end, w.state, w.links, w.stop)
}

# R-TP14, R-SN8 row 1: A moved to B, B active: the end is B, one link.
expect ends({ start: "someone/a", repos: [moved("someone/a", "acme/b"), active("acme/b")] }) == ("acme/b", Active, 1, Reached)

# R-SN8 row 2: A to B, B missing: the end is B, state missing (R-PU28 does not look at the state of the end here: see Q252-5).
expect ends({ start: "someone/a", repos: [moved("someone/a", "acme/b"), missing("acme/b")] }) == ("acme/b", Missing, 1, Reached)

# R-SN8 (step 1): a name that is not `moved` is its own end, no link.
expect ends({ start: "acme/b", repos: [active("acme/b")] }) == ("acme/b", Active, 0, Reached)

# R-SN8 row 3: 4 links, the fifth name is active: the end is the fifth name.
expect ends({ start: "o/a", repos: [moved("o/a", "o/b"), moved("o/b", "o/c"), moved("o/c", "o/d"), moved("o/d", "o/e"), active("o/e")] }) == ("o/e", Active, 4, Reached)

# R-SN8 row 4, R-TP14 ("up to 4 links"): 5 links or more: the chain is cut after 4 links. The end is the name after 4 links, still `moved`.
expect ends({ start: "o/a", repos: [moved("o/a", "o/b"), moved("o/b", "o/c"), moved("o/c", "o/d"), moved("o/d", "o/e"), moved("o/e", "o/f"), active("o/f")] }) == ("o/e", Moved, 4, Cut)

# R-SN8 row 5, R-TP14 ("a cycle stops the chain"): A to B to A. The walk stops before the name that is on the walk: the end is B, state moved.
expect ends({ start: "o/a", repos: [moved("o/a", "o/b"), moved("o/b", "o/a")] }) == ("o/b", Moved, 1, Cycle)

# R-SN8 row 6: A to B to C to A: the end is C.
expect ends({ start: "o/a", repos: [moved("o/a", "o/b"), moved("o/b", "o/c"), moved("o/c", "o/a")] }) == ("o/c", Moved, 2, Cycle)

# R-AP32, R-AP1 (any case): the names of `repos` and of the walk are compared in lower case, as `AuditCheck.state_of` does.
expect ends({ start: "Someone/A", repos: [moved("someone/a", "Acme/B"), active("acme/b")] }) == ("acme/b", Active, 1, Reached)

# R-SN8 (mutation gap G1): the item names and the successor name are in any case too. Start `Acme/Json`, the item `acme/json` is moved with the successor `Acme/Roc-Json`, the item `acme/roc-json` is active: the end is `acme/roc-json`.
expect ends({ start: "Acme/Json", repos: [moved("acme/json", "Acme/Roc-Json"), active("acme/roc-json")] }) == ("acme/roc-json", Active, 1, Reached)

# R-SN8 (mutation gap G1): the items of `repos` have upper case names (the wire keeps the name of the row), the start is lower case.
expect ends({ start: "acme/json", repos: [moved("Acme/Json", "acme/roc-json"), active("Acme/Roc-Json")] }) == ("acme/roc-json", Active, 1, Reached)

# R-PU28 sentence 2: `tln update` and `tln upgrade` with no names do not follow. The item with a successor gives `Stay` (the note of R-AU14 is printed).
expect Successor.decide({ named: Bool.False, item: Ok(moved("someone/json", "acme/json")) }) == Stay

# R-PU28 sentence 3: `tln update <alias>` and `tln upgrade <alias>` follow the successor of the repository of the named alias.
expect Successor.decide({ named: Bool.True, item: Ok(moved("someone/json", "acme/json")) }) == Follow("acme/json")

# R-AU8 (slice 249): the fix of a finding of any reason, when the name has a successor, is `tln update <alias>`, so the command follows a successor whatever the state of the old name is (Q252-4). A `missing` item that has a successor follows too.
expect Successor.decide({ named: Bool.True, item: Ok({ name: "someone/json", state: Missing, successor: Ok("acme/json"), state_at: 1700000000000, owner_changed: Err(None) }) }) == Follow("acme/json")

# R-PU28: a named alias whose repository has no successor is a normal update.
expect Successor.decide({ named: Bool.True, item: Ok(active("someone/json")) }) == Stay

# R-PU28: a named alias whose answer has no `repos` item (a name that is not `github.com`, R-DI11, or `direct`: no `repos` data) is a normal update.
expect Successor.decide({ named: Bool.True, item: Err(None) }) == Stay

# R-TP14 ("a cycle stops the chain, and the client prints a note"): the note names the alias, the start and the end (a proposal, TW24, section 7).
expect Successor.chain_note({ alias: "json", start: "o/a", end: "o/b", stop: Cycle }) == Ok("json: the successors of o/a go in a circle. Talon stops at o/b.")

# R-TP14 ("up to 4 links"): the note of a cut chain (a proposal, TW24).
expect Successor.chain_note({ alias: "json", start: "o/a", end: "o/e", stop: Cut }) == Ok("json: the successors of o/a have more than 4 links. Talon stops at o/e.")

# R-TP14: a chain that ends has no note.
expect Successor.chain_note({ alias: "json", start: "o/a", end: "o/b", stop: Reached }) == Err(None)
