-- Nightly 1 (day 900). Members at bound 24: A2, A3, A5, A6, A9. A1 (an older patch), A4 (an old series out of the window) and A7 (an app) are not.
-- Rows for four members. A2 is the newest of the series 0.1: it has no row.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 1, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[3,5,6,9]');
-- R-MX8, R-MX11 row 2: incomplete. (A group has more than one series.)
-- expect-error: sweep-incomplete
-- params: [1, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- A2 gets its row. Nothing is needed for A1, A4 and A7.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 1, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[2]');
-- Complete: the row is written.
-- params: [1, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Nightly 4 (day 903): a bound above the log size (24) is sweep-bound. The rows are all there, so it is the only fault.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 4, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[2,3,5,6,9]');
-- expect-error: sweep-bound
-- params: [4, 0, 25]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Nightly 2: an author row does not count (R-RE8, R-MX4). A5 has an author row only.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 2, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[2,3,6,9]');
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 2, 0, 1, 0, NULL, 1790000000000, 3 FROM json_each('[5]');
-- expect-error: sweep-incomplete
-- params: [2, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- The bot row of A5 makes it complete.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 2, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[5]');
-- params: [2, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Nightly 3: A6 is out of the window, but it is the newest of its group. Without its row, incomplete.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 3, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[2,3,5,9]');
-- expect-error: sweep-incomplete
-- params: [3, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 3, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[6]');
-- R-MX11 row 1: a yank changes the set. A2 is yanked, so A1 is the newest live release of the series 0.1.
UPDATE releases SET yanked = 1 WHERE log_index = 18;
-- expect-error: sweep-incomplete
-- params: [3, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 3, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[1]');
-- params: [3, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
UPDATE releases SET yanked = 0 WHERE log_index = 18;
-- TC6 (Design Q83): the row of nightly 2 has the bound 24. A yank of release 5 gives A4 a place in the set at that bound, and A4 has no row on nightly 2.
-- The same sweep again, in a batch with a new row (A17): no error, the row keeps its bound, the row of A17 is written.
-- A smaller bound in a batch with a new row (A18): the same.
UPDATE releases SET yanked = 1 WHERE log_index = 21;
-- batch: 2
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 2, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[17]');
-- params: [2, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- batch: 2
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 2, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[18]');
-- params: [2, 0, 23]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
UPDATE releases SET yanked = 0 WHERE log_index = 21;
-- Release 9: 0.2.1 of form 1 (A10, day 899), with its leaf. The log size is 25. A10 is the newest of the series 0.2, so A3 is not a member at bound 25.
-- 0.2.1 is -9223372028264710145.
INSERT INTO log (idx, grp, version, hash, time) VALUES (25, 'g1', '0.2.1', 'H10', 1790000000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (25, 1, -9223372028264710145, '', 10, NULL, 'u', NULL, NULL, 77673600000, 0, NULL, NULL);
-- The BEFORE UPDATE trigger: the row of nightly 1 has the bound 24. A raise to 25 needs a row for A10.
-- expect-error: sweep-incomplete
-- params: [1, 0, 25]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 1, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[10]');
-- Complete: the row is raised to 25.
-- params: [1, 0, 25]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- A smaller bound by the upsert changes nothing and is no error (R-MX4). The row keeps 25.
-- params: [1, 0, 24]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- A direct UPDATE to a smaller bound is sweep-smaller. To a bound above the log size is sweep-bound (R-MX8).
-- expect-error: sweep-smaller
UPDATE sweeps SET upto_log_index = 5 WHERE nightly = 1 AND target = 0;
-- expect-error: sweep-bound
UPDATE sweeps SET upto_log_index = 26 WHERE nightly = 1 AND target = 0;
-- The BEFORE UPDATE trigger checks the set too, for a code path that does not use the upsert. Nightly 2 has the bound 24 and no row for A10.
-- expect-error: sweep-incomplete
UPDATE sweeps SET upto_log_index = 25 WHERE nightly = 2 AND target = 0;
-- Nightly 5 (day 300): the window is the 18 months before the published_at of the nightly, not before now. A4 (day 100) is in it.
-- The set at bound 25: A2, A10, A4, A5, A6, A9.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 5, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[2,5,6,9,10]');
-- expect-error: sweep-incomplete
-- params: [5, 0, 25]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 5, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[4]');
-- params: [5, 0, 25]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Nightly 6 (day 301): a withdrawn release is not live (R-PU17). A5 has no row, so incomplete. After the withdrawal of release 5, A4 is the newest of its group and A5 is not needed.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 6, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[2,4,6,9,10]');
-- expect-error: sweep-incomplete
-- params: [6, 0, 25]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
UPDATE releases SET withdrawn = 'deleted', withdrawn_at = 1790000000000 WHERE log_index = 21;
-- params: [6, 0, 25]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- TC5, the edge of the window (Design Q80, R-MX16). Nightly 7 and 8 are at the day 900: t = 77760000000, so the edge is t - 47347200000 = 30412800000.
--   forms 6 and 7 have two series each, forms 8 has two series too:
--   10 form 6 1.0.0 A11 published exactly at the edge: in the window, a member
--   11 form 6 2.0.0 A12 recent: a member
--   12 form 7 1.0.0 A13 published 1 ms before the edge, and not the newest of its group: not a member
--   13 form 7 2.0.0 A14 recent: a member
--   14 form 8 1.0.0 A15 published 1 ms after t: in the window, a member
--   15 form 8 2.0.0 A16 published 2 ms after t: a member
INSERT INTO log (idx, grp, version, hash, time) VALUES
  (26, 'g6', '1.0.0', 'H11', 1790000000000),
  (27, 'g6', '2.0.0', 'H12', 1790000000000),
  (28, 'g7', '1.0.0', 'H13', 1790000000000),
  (29, 'g7', '2.0.0', 'H14', 1790000000000),
  (30, 'g8', '1.0.0', 'H15', 1790000000000),
  (31, 'g8', '2.0.0', 'H16', 1790000000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES
  (26, 6, -9223090561877999617, '', 11, NULL, 'u', NULL, NULL, 30412800000, 0, NULL, NULL),
  (27, 6, -9222809086901288961, '', 12, NULL, 'u', NULL, NULL, 77000000000, 0, NULL, NULL),
  (28, 7, -9223090561877999617, '', 13, NULL, 'u', NULL, NULL, 30412799999, 0, NULL, NULL),
  (29, 7, -9222809086901288961, '', 14, NULL, 'u', NULL, NULL, 77000000000, 0, NULL, NULL),
  (30, 8, -9223090561877999617, '', 15, NULL, 'u', NULL, NULL, 77760000001, 0, NULL, NULL),
  (31, 8, -9222809086901288961, '', 16, NULL, 'u', NULL, NULL, 77760000002, 0, NULL, NULL);
-- Nightly 7: the rows of the members of the earlier forms and of A12, A14, A15, A16. A11 (at the edge) has no row: incomplete.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 7, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[2,4,6,9,10,12,14,15,16]');
-- expect-error: sweep-incomplete
-- params: [7, 0, 31]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- A11 gets its row. A13 (1 ms before the edge) needs none: complete.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 7, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[11]');
-- params: [7, 0, 31]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- Nightly 8: A15 (after t) has no row: incomplete. With its row: complete.
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 8, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[2,4,6,9,10,11,12,14,16]');
-- expect-error: sweep-incomplete
-- params: [8, 0, 31]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 8, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[15]');
-- params: [8, 0, 31]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
