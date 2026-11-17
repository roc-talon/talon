import records.Closure as Wire

## Slice 252 (docs/slices/252-successor-follow.md, Registry R-PU28, R-TP14, R-SN8; Design Q632).
## The decisions of `tln update <alias>` that follows the successor of a moved package. Part A (TESTING.md 2.2): pure.
Successor :: [].{

	## R-TP14, R-SN8: the end of a chain of successors. `repos` are the `repos` items that the client has (the first answer, then the answer of each successor). The walk starts at `start`. It goes to the successor
	## while the current name is `Moved` and has a successor, fewer than 4 links are taken, and the successor is not yet on the walk (the start is on the walk). The names are compared in lower case.
	## `end` is the name where the walk stops (lower case), `state` its own state (`Unknown`: no item of `repos` has that name), `links` the links taken.
	## `stop`: `Reached` (the end is not `Moved`, or it is `Unknown`, or the start has no successor), `Cut` (4 links were taken and the end is still `Moved`), `Cycle` (the successor is on the walk).
	walk : { start : Str, repos : List(Wire.Repo) } -> { end : Str, state : [Active, Missing, Moved, Unknown], links : U64, stop : [Reached, Cut, Cycle] }
	walk = |facts| {
		find = |name| facts.repos.find_first(|p| p.name.with_ascii_lowercased() == name)
		var $current = facts.start.with_ascii_lowercased()
		var $seen = [$current]
		var $links = 0.U64
		var $result = { end: $current, state: Unknown, links: 0.U64, stop: Reached }
		var $go = Bool.True
		while $go {
			match find($current) {
				Err(_) => {
					$result = { end: $current, state: Unknown, links: $links, stop: Reached }
					$go = Bool.False
				}
				Ok(item) => {
					state = match item.state {
						Active => Active
						Missing => Missing
						Moved => Moved
					}
					match (item.state, item.successor) {
						(Moved, Ok(next_raw)) => {
							next = next_raw.with_ascii_lowercased()
							if $links >= 4 {
								$result = { end: $current, state, links: $links, stop: Cut }
								$go = Bool.False
							} else if $seen.contains(next) {
								$result = { end: $current, state, links: $links, stop: Cycle }
								$go = Bool.False
							} else {
								$seen = $seen.append(next)
								$links = $links + 1
								$current = next
							}
						}
						_ => {
							$result = { end: $current, state, links: $links, stop: Reached }
							$go = Bool.False
						}
					}
				}
			}
		}
		$result
	}

	## R-PU28 (the first sentence about `update` and `upgrade`): does the command follow the successor of a header entry? `named` is true when the user names the alias of the entry (`tln update json`, `tln upgrade json`).
	## `Follow(name)` only when `named` and the item has a successor (any state, Q252-4). A run with no names, or with other names, `Stay`s: the note of R-AU14 is printed instead.
	decide : { named : Bool, item : Try(Wire.Repo, [None]) } -> [Follow(Str), Stay]
	decide = |facts|
		if facts.named {
			match facts.item {
				Ok(item) =>
					match item.successor {
						Ok(name) => Follow(name)
						Err(_) => Stay
					}
				Err(_) => Stay
			}
		} else {
			Stay
		}

	## R-TP14 (the note of a cut chain and of a cycle; slice 252 section 7). `Err(None)` when `stop` is `Reached`.
	chain_note : { alias : Str, start : Str, end : Str, stop : [Reached, Cut, Cycle] } -> Try(Str, [None])
	chain_note = |facts|
		match facts.stop {
			Reached => Err(None)
			Cut => Ok("${facts.alias}: the successors of ${facts.start} have more than 4 links. Talon stops at ${facts.end}.")
			Cycle => Ok("${facts.alias}: the successors of ${facts.start} go in a circle. Talon stops at ${facts.end}.")
		}
}
