import lib.Lock

LockTest :: [].{}

# R-CC12 R-CC3 R-HF3: a lock is stale when its `beat` is older than 30 s. With no `beat` the age of the directory counts.
# Times are seconds. The real clock is `now`. An age of exactly 30 s is live. A time in the future is live (no U64 underflow).
expect {
	now = 1000
	rows = [
		("fresh beat", { now, beat: Ok(990), dir: 0 }, Live),
		("30 s: live", { now, beat: Ok(970), dir: 0 }, Live),
		("31 s: stale", { now, beat: Ok(969), dir: 1000 }, Stale),
		("very old beat", { now, beat: Ok(0), dir: 1000 }, Stale),
		("beat in the future", { now, beat: Ok(2000), dir: 0 }, Live),
		("same second", { now, beat: Ok(1000), dir: 0 }, Live),
		("no beat, fresh directory", { now, beat: Err(NoBeat), dir: 995 }, Live),
		("no beat, directory 30 s", { now, beat: Err(NoBeat), dir: 970 }, Live),
		("no beat, directory 31 s", { now, beat: Err(NoBeat), dir: 969 }, Stale),
		("no beat, directory in the future", { now, beat: Err(NoBeat), dir: 5000 }, Live),
		("the beat wins over an old directory", { now, beat: Ok(990), dir: 0 }, Live),
	]
	bad = rows.keep_if(|(_, facts, want)| Lock.state(facts) != want).map(|(label, facts, want)| (label, want, Lock.state(facts)))
	dbg bad
	bad == []
}

# R-CC3 R-CC5 R-CC12 R-LY3: the names. The lock of an item is the directory `<item>.lock` (R-CC3 point 4). `owner` holds the
# token and the start time, and `unlock!` deletes only a lock whose `owner` has its own token. A stale directory is
# renamed to `<item>.lock.<hex>.stale`. The wait line names the item by its last path segment (question Q1).
expect {
	token = "0123456789abcdef"
	owner = Lock.owner_text({ token, started: 1792065600 })
	owns = [
		(Lock.owns({ owner, token }), Bool.True),
		(Lock.owns({ owner, token: "fedcba9876543210" }), Bool.False),
		(Lock.owns({ owner: "", token }), Bool.False),
		(Lock.owns({ owner: token, token }), Bool.True),
		(Lock.owns({ owner: "${token}0\n1\n", token }), Bool.False),
	]
	bad_owns = owns.keep_if(|(got, want)| got != want)
	texts = [
		(Lock.dir("/c/roc/talon/projects.json"), "/c/roc/talon/projects.json.lock"),
		(Lock.dir("/c/roc/toolchains/n1"), "/c/roc/toolchains/n1.lock"),
		(owner, "0123456789abcdef\n1792065600\n"),
		(Lock.stale_name({ item: "/c/roc/talon/projects.json", hex: "fedcba9876543210" }), "/c/roc/talon/projects.json.lock.fedcba9876543210.stale"),
		(Lock.waiting_line("/c/roc/toolchains/nightly-2026-10-13-91fa0c2"), "waiting for another tln: nightly-2026-10-13-91fa0c2\n"),
		(Lock.waiting_line("/c/roc/talon/projects.json"), "waiting for another tln: projects.json\n"),
	]
	bad_texts = texts.keep_if(|(got, want)| got != want)
	dbg (bad_owns, bad_texts)
	bad_owns == [] and bad_texts == []
}
