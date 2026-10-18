# The bounded bot set, its sweep guard and the transitions table (Registry 6, R-MX4, R-MX8, R-MX11, R-RE23)

Question: the compat bot cannot check every indexed hash on each new nightly, because the index only grows. Can the registry define a smaller set of hashes in SQL, guard a sweep on that set in the same transaction (as `research/d1-sweep/`), and keep the epoch rule of Resolution 4 (R-EP2, R-EP3) correct?

Answer: yes. The set is the newest release of each series of each group, for the series that had a release in the 18 months before the nightly, and always the newest series of each group (R-MX11). One SQL text gives the members to the guard triggers and to the work route of the bot. An `AFTER` trigger on `sweeps` writes one `transitions` row for each pair of adjacent swept nightlies, with the count of hashes compared and changed, so each client sees the boundaries that the bot found, not only the boundaries in its own closure.

## Run

| Command | What it does |
| --- | --- |
| `node test.mjs [sqlite] [states]` | The 13 cases below on local D1 (wrangler `getPlatformProxy`) and plain SQLite. `states` is the count of random indexes for B1 (default 300). Exit code 1 if a case fails. |
| `node test.mjs remote [states]` | Remote D1 only. Run `research/d1-remote/run.sh create` first and `delete` after. |
| `MUTATE=allhash node test.mjs sqlite` | The old rule: every hash up to the bound. B0, B1 and B3 to B6 fail, and the T cases after them. |
| `MUTATE=noseries node test.mjs sqlite` | Only the newest release of each group. B0, B1 and B5 fail. |
| `MUTATE=nowindow node test.mjs sqlite` | No age window. B0, B1 and B3 to B6 fail, and the T cases after them. |
| `MUTATE=faults node test.mjs sqlite` | Hangs and crashes count in a transition. T1 and T2 fail. |
| `node bench.mjs [groups] [releases]` | Time of the member query and of one sweep write, plain SQLite |
| `node boundaries.mjs` | The epoch boundaries (R-EP3) that all hashes, the bot set and a smaller set find in `conformance/compat-sweep/` |

`schema.mjs` builds the schema. The member condition (`memberSql`) is one function, used by both guard triggers and by the work route query (`missingSql`). SQLite does not allow a `WITH` clause in a trigger, so the condition uses correlated `NOT EXISTS` subqueries. Needs Node 22 or later and a global `wrangler` (4.151.0). Delete `.wrangler/` after a run.

## Results (2026-10-17)

Local D1 and plain SQLite: 13 of 13 pass. B1 also passes with 5,000 random indexes (10,646 members). Each mutation fails as the table above says.

| Case | What | Result |
| --- | --- | --- |
| B1 | The SQL members are equal to a reference written from the rule text, over random indexes: 4 groups, majors 0 to 2, yanks, withdrawals, apps, times over 1,000 days | Equal |
| B0 | A fixed index of 4 groups | The members are the newest patch of each series in the window, and the newest series of a group that is older than the window |
| B2 | No row for one member | `sweep-incomplete`. Nothing of the batch is written. |
| B3 | Rows for the members only | Complete. An older patch and an old series need no row. |
| B4 | The work route at the log size | Lists no hash outside the set |
| B5 | A yank of the newest patch between the read of the bot and its write | The patch before it is now a member: `sweep-incomplete`, and the route lists it |
| B6 | A release above the bound | Not needed at that bound. The route at the log size lists it. |
| B7 | An `author` row | Does not count |
| T0 to T2 | Transitions of adjacent swept nightlies | `compared` counts the hashes with a code result (pass or fail) on both. A crash is not compared (R-EP5). `changed` counts the different results. |
| T3, T4 | A nightly between two swept nightlies that is not swept yet | No transition row over it. Its later sweep writes both of its rows. |

Cost (`node bench.mjs`, plain SQLite in memory, 3 series for each group, all in the window):

| Releases | Members | Member query | Sweep write with the guard |
| --- | --- | --- | --- |
| 20,000 | 6,000 | 16 ms | 14 ms |
| 100,000 | 30,000 | 64 ms | 55 ms |

The `UNIQUE (form, version)` index of R-IK6 serves the subqueries: a second index on (form, version) changed nothing.

Boundaries (`node boundaries.mjs`, 46 hashes x 22 nightlies, measured 2026-10-13). The set is the newest labelled release of each series. A hash with no known label is not a member.

| Set | Hashes | Threshold 2 changed hashes | Threshold 1 |
| --- | --- | --- | --- |
| All hashes | 46 | 09-22, 09-24, 09-26, 10-02, 10-09 | The same 5 |
| The bot set (R-MX11) | 30 | 09-22, 09-26, 10-02, 10-09: misses 09-24 | The same 5 as all hashes |
| The newest series of each group only | 19 | 09-22, 10-09 | 09-22, 09-24, 10-02, 10-09: misses 09-26 |

At 09-24, roc-parser 2.0.0 is the one member that changed; the other change is a hash with no label. So the registry uses a threshold of 1 for the counts over the set (R-MX12, R-EP3 case a). The newest series alone is too small: it misses a boundary at each threshold. The sample is small (22 nightlies), so the threshold is a first guess.

The first run of B1 used a linear congruential generator in floating point (`seed * 1103515245` goes above 2^53), so `rnd(4)` always gave 0, and B1 passed with no real coverage. With mulberry32, B1 found one difference: the reference removed apps before it chose the newest release of a group. The rule chooses over the whole group, then keeps a package or a platform. `research/semver-key/` had the same generator; it now uses mulberry32 too, and its results still hold.

## What this does not prove

| Item | Status |
| --- | --- |
| Remote D1 | Tested (2026-10-18, `research/d1-remote/`): 13 of 13 cases pass. `MUTATE=faults` and `MUTATE=allhash` fail the same cases as on local D1. |
| D1 time of the guard at 100,000 releases | Measured on plain SQLite only. `research/d1-sweep/` found D1 `meta.duration` close to the SQLite time. |
| Saturated version keys (a part of 65535 or more, R-IK5) | Not in the domain of B1. The series of such a key can be wrong. A release with such a part is rare, and the Worker can read `version_text` for it. |
| That the set finds the same boundaries as all hashes on more data | Measured on 22 nightlies only (above). The compat bot can measure it again in P2: it has the rows of the set, and the old rows of the hashes that left it. |
