-- Q27, R-SG8 row 3: a publish batch is names, leaf, release. Here: names form 2, leaf and release of a new label (form 2), then the leaf and the release of the label of release 1 with another artifact.
-- The leaf statement of that label writes nothing, and the release stops with label-conflict. The batch fails: no names row, no leaf, no release of form 2.
-- batch: 5
-- expect-error: label-conflict
INSERT INTO names (id, kind, value) VALUES (2, 2, 'g2')
ON CONFLICT (kind, value) DO NOTHING;
-- params: ["g2", "1.0.0", "H2", 1790000000001, 2, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [2, "-9223090561877999617", "", 2, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- params: ["g1", "1.0.0", "H99", 1790000000002, 1, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [1, "-9223090561877999617", "", 99, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- R-SG8 row 4: a release that fails a CHECK fails the batch (withdrawn = 'gone'). The leaf of the batch is not written either.
-- batch: 3
-- expect-error: CHECK constraint failed
INSERT INTO names (id, kind, value) VALUES (2, 2, 'g2')
ON CONFLICT (kind, value) DO NOTHING;
-- params: ["g2", "1.0.0", "H2", 1790000000004, 2, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [2, "-9223090561877999617", "", 2, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, 'gone', NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- The same batch with the new label only: written.
-- batch: 3
INSERT INTO names (id, kind, value) VALUES (2, 2, 'g2')
ON CONFLICT (kind, value) DO NOTHING;
-- params: ["g2", "1.0.0", "H2", 1790000000003, 2, "-9223090561877999617", ""]
INSERT INTO log (idx, grp, version, hash, time)
SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?1, ?2, ?3, ?4
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?5 AND version = ?6 AND version_text = ?7);
-- params: [2, "-9223090561877999617", "", 2, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- S2: a sweep batch. The bot row of A1 is missing in the request (a row of A5 is there), so the sweep is incomplete (bound 2: the members are A1). The row of A5 is not written.
-- batch: 2
-- expect-error: sweep-incomplete
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 1, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[5]');
-- params: [1, 0, 2]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- The same batch with the row of A1: complete. Both rows and the sweep are written.
-- batch: 3
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 1, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[5]');
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index)
SELECT value, 1, 0, 0, 0, NULL, 1790000000000, NULL FROM json_each('[1]');
-- params: [1, 0, 2]
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (?1, ?2, ?3, 1790000000000)
ON CONFLICT (nightly, target) DO UPDATE SET upto_log_index = excluded.upto_log_index, time = excluded.time
WHERE excluded.upto_log_index > sweeps.upto_log_index;
-- R-RE13 row 1: a batch with a used key (another result) and a new key. The first write wins: A1 keeps result 0. No error.
-- batch: 2
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1, 1, 0, 0, 1, 'later', 2000, NULL);
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (6, 1, 0, 0, 1, 'x', 2000, NULL);
-- Q1: a hint batch. The first row is allowed (counted 200000), the second is over the limit. The batch fails and the first row is not written.
-- batch: 2
-- expect-error: hint-quota
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-5, 1, 1, 0, 0, 100, 1728000001000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-6, 1, 1, 0, 0, 100, 1728000002000);
