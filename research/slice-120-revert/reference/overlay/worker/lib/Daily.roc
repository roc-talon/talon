Daily :: [].{

	cron : Str
	cron = "0 3 * * *"

	old_ms : U64
	old_ms = 31_536_000_000

	hints_sql : () -> Str
	hints_sql = || "DELETE FROM compat_hints WHERE EXISTS (SELECT 1 FROM compat b WHERE b.artifact = compat_hints.artifact AND b.nightly = compat_hints.nightly AND b.target = compat_hints.target AND b.source = 0)"

	days_sql : () -> Str
	days_sql = || "DELETE FROM hint_days WHERE day < CAST(?1 / 86400000 AS INTEGER) - 2"

	due_sql : () -> Str
	due_sql = || Str.join_with([
		"SELECT CAST(t.nightly AS TEXT) AS nightly FROM toolchains t GROUP BY t.nightly",
		"HAVING MIN(t.published_at) < ?1 - 31536000000",
		"AND (EXISTS (SELECT 1 FROM contributions c WHERE c.nightly = t.nightly) OR EXISTS (SELECT 1 FROM compat_hints h WHERE h.nightly = t.nightly))",
		"ORDER BY MIN(t.published_at), t.nightly",
	], " ")

	trim_sqls : () -> List(Str)
	trim_sqls = || [
		Str.join_with([
			"INSERT INTO contributor_totals (contributor, counted, first, agreed, disagreed, unconfirmed, first_time, last_time)",
			"SELECT m.contributor, COUNT(*), SUM(m.is_first), SUM(m.bot IS NOT NULL AND m.bot = m.result), SUM(m.bot IS NOT NULL AND m.bot <> m.result), SUM(m.bot IS NULL), MIN(m.time), MAX(m.time)",
			"FROM (SELECT c.contributor AS contributor, c.result AS result, c.time AS time,",
			"(NOT EXISTS (SELECT 1 FROM compat x WHERE x.artifact = c.artifact AND x.nightly = c.nightly AND x.target = c.target AND x.time < c.time)",
			"AND NOT EXISTS (SELECT 1 FROM contributions o WHERE o.artifact = c.artifact AND o.nightly = c.nightly AND o.target = c.target AND o.contributor <> c.contributor",
			"AND (o.time < c.time OR (o.time = c.time AND o.contributor < c.contributor)))) AS is_first,",
			"(SELECT b.result FROM compat b WHERE b.artifact = c.artifact AND b.nightly = c.nightly AND b.target = c.target AND b.source = 0) AS bot",
			"FROM contributions c WHERE c.nightly = CAST(?1 AS INTEGER)) m GROUP BY m.contributor",
			"ON CONFLICT (contributor) DO UPDATE SET counted = contributor_totals.counted + excluded.counted, first = contributor_totals.first + excluded.first,",
			"agreed = contributor_totals.agreed + excluded.agreed, disagreed = contributor_totals.disagreed + excluded.disagreed, unconfirmed = contributor_totals.unconfirmed + excluded.unconfirmed,",
			"first_time = MIN(contributor_totals.first_time, excluded.first_time), last_time = MAX(contributor_totals.last_time, excluded.last_time)",
		], " "),
		"DELETE FROM contributions WHERE nightly = CAST(?1 AS INTEGER)",
		"DELETE FROM compat_hints WHERE nightly = CAST(?1 AS INTEGER)",
	]
}
