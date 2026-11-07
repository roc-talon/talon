-- Test data for check.sh local-seed. It uses 64-bit ids above 2^53, a blob name, a text with quotes and a newline,
-- NULLs, and rows that triggers also write (compat_hints, hint_days, transitions). Run it on a database with the migrations.
INSERT INTO names (id, kind, value) VALUES
  (-7163292474072844001, 2, 'roc-lang/foo'),
  (9007199254740993, 3, 'it''s a "name"' || char(10) || 'line two'),
  (-9223372036854775807, 1, X'00FF10AB'),
  (9223372036854775807, 3, 'repo-x');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES
  (-4611686018427387905, 1, '[]', NULL, NULL, 1234),
  (4611686018427387903, 2, '["a"]', -7163292474072844001, 'abc', 99);
INSERT INTO log (idx, grp, version, hash, time) VALUES
  (1, 'roc-lang/foo', '1.0.0', 'sha256:aa', 1700000000000),
  (2, 'roc-lang/nightlies:linux_x86_64', 'nightly-1', 'sha256:bb', 1700000001000),
  (3, 'roc-lang/nightlies:linux_x86_64', 'nightly-2', 'sha256:cc', 1700000002000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES
  (9223372036854775807, 1434744226, 5572595, 0, NULL, 1700000000000, 1700000000000);
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES
  (9223372036854775807, 1, 0, NULL, 1434744226, NULL, 5572595, NULL, '{"a":"b\"c"}', 1700000000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed, repo_etag) VALUES
  (9223372036854775807, 'W/"x"', NULL, 1700000100000, 0, 1, NULL);
INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (1434744226, 'octo', 5, 1, 2);
INSERT INTO links (machine, contributor, time) VALUES (-8070450532247928833, 1434744226, 3);
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url, platform) VALUES
  (-4611686018427387905, 'p', 4611686018427387903, -7163292474072844001, -9223372036854775807, '', 'https://x/y', 1),
  (-4611686018427387905, 'q', 4611686018427387903, NULL, NULL, NULL, 'https://x/z', 0);
INSERT INTO artifact_targets (artifact, target) VALUES (4611686018427387903, 9), (4611686018427387903, 34);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES
  (1, -7163292474072844001, -9223372036854775807, '', -4611686018427387905, 9223372036854775807, 'https://github.com/roc-lang/foo/x.tar', 'v1.0.0', NULL, 1700000000000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 0, '{"k":"v"}', 1700000000000), (1, 2, NULL, 1700000000001);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES
  (-1152921504606846977, 'linux_x86_64', 'nightly-1', 'roc.tar.gz', 'bb', 10, 1700000001000, 2),
  (1152921504606846975, 'linux_x86_64', 'nightly-2', 'roc.tar.gz', 'cc', 10, 1700000002000, 3);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES
  (-4611686018427387905, -1152921504606846977, 9, 0, 0, NULL, 1700000003000, NULL),
  (-4611686018427387905, 1152921504606846975, 9, 0, 1, 'dig', 1700000004000, 1);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES
  (1434744226, -4611686018427387905, -1152921504606846977, 9, 0, 7, 1700000005000),
  (-8070450532247928833, -4611686018427387905, -1152921504606846977, 9, 0, 7, 1700000006000);
INSERT INTO contributor_totals (contributor, counted, first, agreed, disagreed, unconfirmed, first_time, last_time) VALUES (1434744226, 2, 1, 1, 0, 1, 1, 2);
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES
  (-1152921504606846977, 9, 3, 1700000007000),
  (1152921504606846975, 9, 3, 1700000008000);
-- The trimmed totals differ from what the triggers sum, so the dump must write them with INSERT OR REPLACE.
UPDATE compat_hints SET pass_count = 5 WHERE talon_version = 7;
UPDATE hint_days SET counted = 77;
UPDATE transitions SET changed = 3 WHERE changed = 0;
