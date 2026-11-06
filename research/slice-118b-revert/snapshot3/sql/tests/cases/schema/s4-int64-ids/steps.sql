-- Cases K1, K3, K10, K11, K12 of research/d1-int-keys/ on the real tables. K2 (a BigInt parameter) is a fact of the D1 binding
-- and of the Worker platform, not of the schema; the runner passes JSON parameters and cannot send a BigInt (slice file, out of scope).
-- K7 and K8 (the id functions) have no database: slice 104 (W0).
-- R-IK2: a 64-bit id is bound as decimal text, stored as an INTEGER by the column affinity, and read with CAST(id AS TEXT).

-- K1: a 53-bit id as a Number parameter and inside a JSON parameter (json_each). Exact on both backends.
-- params: [9007199254740991, 9007199254740990]
INSERT INTO names (id, kind, value) VALUES (?, 2, 'k1-max'), (?, 2, 'k1-max-1');
-- params: ["[9007199254740989]"]
INSERT INTO names (id, kind, value) SELECT value, 2, 'k1-json' FROM json_each(?);

-- K3: 2^53 + 1 and 2^53 as text. They are two rows (a rounded read would join them).
-- params: ["9007199254740993", "9007199254740992"]
INSERT INTO names (id, kind, value) VALUES (?, 2, 'k3-odd'), (?, 2, 'k3-even');

-- The id of R-IK2 (case K8): name_id(2, "github.com/roc-lang/unicode/releases/download/{v}/"), and the ends of the i64 range.
-- params: ["-2687166099708853831", "9223372036854775807", "-9223372036854775807", "-9223372036854775808"]
INSERT INTO names (id, kind, value) VALUES (?, 2, 'k8-form'), (?, 3, 'k10-big'), (?, 3, 'k10-neg'), (?, 3, 'k10-min');

-- K10: where a text id meets a column, it becomes an integer.
-- params: ["9223372036854775807"]
INSERT INTO probe SELECT 'where', CAST(id AS TEXT) FROM names WHERE id = ?;
-- params: ["-9223372036854775808"]
INSERT INTO probe SELECT 'where_min', CAST(id AS TEXT) FROM names WHERE id = ?;
-- params: ["[9223372036854775807,-9223372036854775807]"]
INSERT INTO probe SELECT 'in_json', CAST(id AS TEXT) FROM names WHERE id IN (SELECT value FROM json_each(?));
-- params: ["9223372036854775807"]
WITH p(x) AS (VALUES (?)) INSERT INTO probe SELECT 'cte_join', CAST(id AS TEXT) FROM names JOIN p ON names.id = p.x;
-- params: ["9223372036854775807", "9223372036854775807"]
INSERT INTO probe SELECT 'param_eq', CAST(? = (SELECT id FROM names WHERE id = ?) AS TEXT);
-- Two parameters, or a parameter and an expression, are not converted: ? = ? + 0 is false.
-- params: ["9223372036854775807", "9223372036854775807"]
INSERT INTO probe SELECT 'two_params', CAST(? = ? + 0 AS TEXT);
-- params: ["9223372036854775807"]
INSERT INTO probe SELECT 'column_plus0', CAST(COUNT(*) AS TEXT) FROM names WHERE id = ? + 0;
-- params: ["9223372036854775807"]
INSERT INTO probe SELECT 'cast_param', CAST(COUNT(*) AS TEXT) FROM names WHERE id = CAST(? AS INTEGER);

-- R-IK2: the 64-bit columns of the other tables take a text id as an integer. One row in each table that has an id column.
-- params: ["9223372036854775807", "-9223372036854775807"]
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (?, 0, '[]', ?, NULL, 10);
-- params: ["-2687166099708853831", "-9223372036854775808", "9223372036854775807", "4611686018427387905"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (1, ?, ?, '', ?, ?, 'https://github.com/roc-lang/unicode/releases/download/0.1.0/x.tar.zst', '0.1.0', NULL, 1790000000000, 0, NULL, NULL);
-- params: ["9223372036854775807", "-9223372036854775807"]
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (?, 5000000000000, 0, 0, 0, NULL, 1790000000000, NULL), (?, 5000000000000, 0, 0, 1, 'abc', 1790000000000, 1);
-- params: ["4611686018427387905", "-9223372036854775807"]
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (?, 1, 2, 0, ?, 1790000000000, 1790000000000);
-- params: ["-9223372036854775808"]
INSERT INTO links (machine, contributor, time) VALUES (?, 583231, 1790000000000);
-- params: ["-9223372036854775807", "9223372036854775807"]
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (?, ?, 5000000000000, 0, 3, 262145, 1790000000000);
-- params: ["9223372036854775807", "-9223372036854775807", "-2687166099708853831", "-9223372036854775808"]
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (?, 'json', ?, ?, ?, NULL, 'https://github.com/roc-lang/json/releases/download/0.1.0/x.tar.zst');
-- params: ["9223372036854775807"]
INSERT INTO artifact_targets (artifact, target) VALUES (?, 9);
-- params: ["-9223372036854775807"]
INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time) VALUES (?, 5000000000000, 0, 262145, 1, 0, 0, 1790000000000, 1790000000000);

-- R-IK8, K12: STRICT. A text id that is not an integer, and an integer text out of the i64 range, are errors in a key column of
-- a WITHOUT ROWID table, in a column of a rowid table, in a rowid key (datatype mismatch), and in a time column.
-- expect-error: cannot store TEXT value in INTEGER column compat.artifact
-- params: ["abc"]
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (?, 1, 0, 0, 0, NULL, 1, NULL);
-- expect-error: cannot store REAL value in INTEGER column compat.artifact
-- params: ["9223372036854775808"]
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (?, 1, 0, 0, 0, NULL, 1, NULL);
-- expect-error: cannot store TEXT value in INTEGER column releases.version
-- params: ["abc"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (2, 1, ?, '', 1, NULL, 'u', NULL, NULL, 1, 0, NULL, NULL);
-- expect-error: cannot store REAL value in INTEGER column releases.version
-- params: ["9223372036854775808"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (2, 1, ?, '', 1, NULL, 'u', NULL, NULL, 1, 0, NULL, NULL);
-- expect-error: datatype mismatch
-- params: ["abc"]
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (?, 1, 2, 0, NULL, 1, 1);
-- expect-error: datatype mismatch
-- params: ["9223372036854775808"]
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (?, 1, 2, 0, NULL, 1, 1);
-- expect-error: cannot store TEXT value in INTEGER column log.time
-- params: ["2026-11-01T12:00:00Z"]
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/roc-lang/unicode/releases/download/{v}/', '0.1.0', 'h', ?);
