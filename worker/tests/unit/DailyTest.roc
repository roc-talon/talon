import lib.Daily

DailyTest :: [].{}

# W0 tests of worker/lib/Daily.roc (slice 120, docs/slices/120-daily-crons.md). The SQL texts are pinned by key words; what they do on D1 is W2 (worker/tests/cases/cron/).

holds : Str, List(Str) -> Bool
holds = |text, words| words.all(|w| text.contains(w))

lacks : Str, List(Str) -> Bool
lacks = |text, words| words.all(|w| !text.contains(w))

# R-CT5, R-PU35 (cleanup), R-PU36: one DELETE of the hints whose pair has a `bot` row. The pair is artifact, nightly and target (no talon_version). Only `bot` (source 0). The contributions stay.
expect {
	h = Daily.hints_sql()
	one = h.split_on(";").len() == 1
	delete = holds(h, ["DELETE FROM compat_hints", "EXISTS", "FROM compat ", "source = 0", "artifact", "nightly", "target"])
	keeps = lacks(h, ["contributions", "OR ", "source = 1", "source <> 0"])
	one and delete and keeps
}

# R-RE6, R-RE24, R-PU35 (hint_days): one DELETE of the old days from the clock (?1, ms). The day is ms / 86400000. Strict comparison with a day number, no `counted` condition.
expect {
	d = Daily.days_sql()
	one = d.split_on(";").len() == 1
	delete = holds(d, ["DELETE FROM hint_days", "day <", "?1", "86400000", "- 2"])
	plain = lacks(d, ["counted", "<=", "OR "])
	one and delete and plain
}

# R-CT15, R-PU35 (trim): the due read. A compiler is a nightly of toolchains, its age is the smallest published_at, a compiler at exactly 365 days is not old (strict), only a compiler that has rows is due,
# the oldest first. The number is the same as the old-nightly skip of R-CT14 (Design Q174).
expect {
	q = Daily.due_sql()
	age = holds(q, ["FROM toolchains", "MIN(", "published_at", "31536000000", "?1"]) and lacks(q, ["<=", ">="])
	rows = holds(q, ["contributions", "compat_hints", "EXISTS"])
	order = holds(q, ["ORDER BY", "nightly"]) and q.split_on("ORDER BY").len() == 2
	text = q.contains("CAST(") and q.contains("nightly AS TEXT)")
	cap = Daily.old_ms == 31_536_000_000 and Daily.cron == "0 3 * * *"
	age and rows and order and text and cap
}

# R-CT15 steps 1 to 3, R-PU36: three statements in this order. Step 1 adds the classes to contributor_totals (ON CONFLICT, the smaller first_time, the larger last_time, never OR REPLACE) and reads the rows
# that step 2 deletes. Step 3 deletes the hints of the compiler. No statement changes `compat`. Each statement takes one value.
expect {
	t = Daily.trim_sqls()
	s1 = t.get(0) ?? ""
	s2 = t.get(1) ?? ""
	s3 = t.get(2) ?? ""
	upsert_part = match s1.split_on("DO UPDATE SET") {
		[_, after] => after
		_ => ""
	}
	a = t.len() == 3
	b = holds(s1, ["INSERT INTO contributor_totals", "FROM contributions", "FROM compat", "ON CONFLICT", "DO UPDATE SET", "nightly", "counted", "first", "agreed", "disagreed", "unconfirmed"]) and lacks(s1, ["DELETE", "OR REPLACE"])
	c = holds(upsert_part, ["MIN(", "MAX(", "first_time", "last_time", "counted"])
	d = holds(s2, ["DELETE FROM contributions", "nightly"]) and lacks(s2, ["compat_hints", "INSERT"])
	e = holds(s3, ["DELETE FROM compat_hints", "nightly"]) and lacks(s3, ["contributions", "INSERT", "EXISTS"])
	f = t.all(|s| s.contains("?1") and !s.contains("?2") and !s.contains("DELETE FROM compat ") and !s.contains("UPDATE compat"))
	a and b and c and d and e and f
}
