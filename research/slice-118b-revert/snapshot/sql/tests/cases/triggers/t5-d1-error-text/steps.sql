-- expect-error: D1_ERROR: label-conflict: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
-- params: [1, "-9223090561877999617", "", 99, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT (SELECT MAX(idx) FROM log), ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- R-SG8: a release whose log_index names a leaf of another group (form 7 is the group 'a'; leaf 1 is a compiler leaf and no release has the index 1).
-- expect-error: D1_ERROR: leaf-missing: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
-- params: [7, "-9223090561877999617", "", 5, 1790000000000]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
SELECT 1, ?1, ?2, ?3, ?4, NULL, 'u', NULL, NULL, ?5, 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ?1 AND version = ?2 AND version_text = ?3 AND artifact = ?4);
-- expect-error: D1_ERROR: leaf-missing: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (2, 'macos_arm64', 't2', 'a', 'zz', 1002, 1000, 2);
-- expect-error: D1_ERROR: sweep-incomplete: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (1, 0, 2, 1000);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1, 1, 0, 0, 0, NULL, 1000, NULL);
-- expect-error: D1_ERROR: sweep-bound: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (1, 0, 9, 1000);
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (1, 0, 2, 1000);
-- expect-error: D1_ERROR: sweep-smaller: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
UPDATE sweeps SET upto_log_index = 0 WHERE nightly = 1 AND target = 0;
-- expect-error: D1_ERROR: hint-quota: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_TRIGGER)
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-5, 1, 1, 0, 0, 100, 1728000001000);
-- R-IK3: a collision of the primary key of names (the same id, another name). It is not a trigger text.
-- expect-error: D1_ERROR: UNIQUE constraint failed: names.id: SQLITE_CONSTRAINT (extended: SQLITE_CONSTRAINT_PRIMARYKEY)
INSERT INTO names (id, kind, value) VALUES (7, 2, 'b');
