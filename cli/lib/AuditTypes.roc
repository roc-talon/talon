## The types of `tln audit` (slice 244, R-AU1 to R-AU3, R-AU13, R-OUT2). `AuditCheck` has the decisions, `AuditReport` has the text and the `--json` data.
## They are in this module so that the two modules do not import each other.
AuditTypes :: [].{

	## The reason of a finding (R-AU2). `Other` is a `withdrawn` value that this tln does not know (Q-244-3).
	Reason : [Yanked, AssetReplaced, RepoMissing, ReleaseMissing, Prerelease, Moved, Other(Str)]

	## One hash that is checked (R-AU1). `edge` is the alias of the first edge that names it (the key of `[tools]` for a tool). `via` are the header aliases that need it (`[]` for a header entry).
	## `tool` is the key of `[tools]` when the hash is the hash of a tool URL. `members` are the member files that have it. `why` is the name of R-SC15 for `tln why`.
	Entry : { url : Str, name : Str, group : Str, version : Str, hash : Str, alias : Try(Str, [None]), edge : Str, via : List(Str), tool : Try(Str, [None]), members : List(Str), why : Str }

	## One finding (R-AU2). `ignored` is the item as written. `since` is in milliseconds.
	Finding : { entry : AuditTypes.Entry, reason : AuditTypes.Reason, ignored : Try(Str, [None]), since : Try(U64, [None]), yank_reason : Try(Str, [None]), new_hash : Try(Str, [None]), successor : Try(Str, [None]) }

	## What the output shows (R-OUT2). `unindexed` are the hashes with no release in the answer (Q-244-4).
	Report : { index : [Registry, Direct], checked : U64, findings : List(AuditTypes.Finding), unused : List(Str), no_yank_data : Bool, unindexed : List({ name : Str, version : Str, hash : Str }) }
}
