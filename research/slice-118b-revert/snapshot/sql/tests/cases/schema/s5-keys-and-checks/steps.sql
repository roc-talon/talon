-- K6 (ported to R-IK5/R-IK6): the label of a release is UNIQUE (form, version, version_text). The old (major, minor, patch) columns are gone.
-- The values below are the stored keys (key XOR 2^63, as signed) of the versions in the comment. Bound as text (R-IK2).
-- 1.2.4, 70000.1.2 (a saturated key), 1.2.3, 0.9.0, 1.2.3-beta1. The log indexes are not in version order.
-- params: ["-9223090553287802881", "-2687166099708853831"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (1, ?2, ?1, '', 11, NULL, 'u1', NULL, NULL, 1790000000000, 0, NULL, NULL);
-- params: ["9223372036854775807", "-2687166099708853831"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (2, ?2, ?1, '70000.1.2', 12, NULL, 'u2', NULL, NULL, 1790000000001, 0, NULL, NULL);
-- params: ["-9223090553287868417", "-2687166099708853831"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (3, ?2, ?1, '', 13, NULL, 'u3', NULL, NULL, 1790000000002, 0, NULL, NULL);
-- params: ["-9223371998200004609", "-2687166099708853831"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (4, ?2, ?1, '', 14, NULL, 'u4', NULL, NULL, 1790000000003, 0, NULL, NULL);
-- params: ["-9223090553287927279", "-2687166099708853831"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (5, ?2, ?1, '', 15, NULL, 'u5', NULL, NULL, 1790000000004, 0, NULL, NULL);
-- The same (form, version) with another version_text is another label (two versions with one saturated key). Another form with a used version is another label.
-- params: ["9223372036854775807", "-2687166099708853831"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (6, ?2, ?1, '70001.0.0', 16, NULL, 'u6', NULL, NULL, 1790000000005, 0, NULL, NULL);
-- params: ["-9223090553287868417", "77"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (7, ?2, ?1, '', 17, NULL, 'u7', NULL, NULL, 1790000000006, 0, NULL, NULL);
-- K6: the same label again (it is 01.2.3 and 1.2.3 to roc: one key) is an error.
-- expect-error: UNIQUE constraint failed: releases.form, releases.version, releases.version_text
-- params: ["-9223090553287868417", "-2687166099708853831"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (8, ?2, ?1, '', 18, NULL, 'u8', NULL, NULL, 1790000000007, 0, NULL, NULL);
-- expect-error: UNIQUE constraint failed: releases.log_index
-- params: ["5", "88"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (5, ?2, ?1, '', 19, NULL, 'u9', NULL, NULL, 1790000000008, 0, NULL, NULL);
-- expect-error: NOT NULL constraint failed: releases.version_text
-- params: ["5", "88"]
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (9, ?2, ?1, NULL, 19, NULL, 'u9', NULL, NULL, 1790000000008, 0, NULL, NULL);
-- R-RE6: yanked, withdrawn and withdrawn_at are the columns of a release that change.
UPDATE releases SET yanked = 1 WHERE log_index = 1;
UPDATE releases SET withdrawn = 'repo-missing', withdrawn_at = 1790000009999 WHERE log_index = 2;
-- R-AP49, R-PU17: withdrawn is NULL or one of the 6 texts. Another text is an error.
-- expect-error: CHECK constraint failed
UPDATE releases SET withdrawn = 'gone' WHERE log_index = 3;

-- K9: compat is WITHOUT ROWID, and the first write of a key wins (the rule of the first write is slice 103; this slice has the key).
-- params: ["5000000000000000001"]
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (?, 5368709123456, 0, 0, 0, NULL, 1790000000000, NULL) ON CONFLICT DO NOTHING;
-- params: ["5000000000000000001"]
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (?, 5368709123456, 0, 0, 1, 'later', 1790000000001, NULL) ON CONFLICT DO NOTHING;
-- params: ["5000000000000000001"]
INSERT OR IGNORE INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (?, 5368709123456, 0, 0, 3, 'later', 1790000000002, NULL);
-- The author row of the same pair is another row (R-RE3), and it keeps the log index of its release.
-- params: ["5000000000000000001"]
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (?, 5368709123456, 0, 1, 1, 'author digest', 1790000000003, 3);
-- A plain insert of a used key is an error.
-- expect-error: UNIQUE constraint failed: compat.artifact, compat.nightly, compat.target, compat.source
-- params: ["5000000000000000001"]
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (?, 5368709123456, 0, 0, 2, NULL, 1790000000004, NULL);
-- The codes of R-IK7: source 0 or 1, result 0 to 3.
-- expect-error: CHECK constraint failed
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1, 1, 0, 2, 0, NULL, 1, NULL);
-- expect-error: CHECK constraint failed
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1, 1, 0, 0, 4, NULL, 1, NULL);
-- expect-error: CHECK constraint failed
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1, 1, 0, 0, -1, NULL, 1, NULL);
-- R-RE26: a time is an integer. A real is an error (the Worker converts RFC 3339 at the edge). s4 has the text case.
-- expect-error: cannot store REAL value in INTEGER column compat.time
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1, 1, 0, 0, 0, NULL, 1.5, NULL);

-- R-RE4, G11: one nightly, two targets (text, the asset target of CLI 6.2). The same pair twice is an error.
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
VALUES (5368709123456, 'linux_x86_64', 'nightly-2026-10-09-258ab27', 'roc-linux_x86_64-nightly.tar.gz', 'aa', 1001, 1790000000000, 1);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
VALUES (5368709123456, 'macos_apple_silicon', 'nightly-2026-10-09-258ab27', 'roc-macos_apple_silicon-nightly.tar.gz', 'bb', 1002, 1790000000000, 2);
-- expect-error: UNIQUE constraint failed: toolchains.nightly, toolchains.target
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
VALUES (5368709123456, 'linux_x86_64', 'nightly-2026-10-09-258ab27', 'roc-linux_x86_64-nightly.tar.gz', 'cc', 1003, 1790000000000, 3);
-- R-AP80, R-RE4: size is the byte size of the asset, above 0. 0, a negative number, NULL and a real are errors; a row never has an unknown size.
-- expect-error: CHECK constraint failed
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
VALUES (5368709123456, 'windows_x86_64', 'nightly-2026-10-09-258ab27', 'roc-windows_x86_64-nightly.zip', 'dd', 0, 1790000000000, 4);
-- expect-error: CHECK constraint failed
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
VALUES (5368709123456, 'windows_x86_64', 'nightly-2026-10-09-258ab27', 'roc-windows_x86_64-nightly.zip', 'dd', -5, 1790000000000, 4);
-- expect-error: NOT NULL constraint failed: toolchains.size
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
VALUES (5368709123456, 'windows_x86_64', 'nightly-2026-10-09-258ab27', 'roc-windows_x86_64-nightly.zip', 'dd', NULL, 1790000000000, 4);
-- expect-error: cannot store REAL value in INTEGER column toolchains.size
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index)
VALUES (5368709123456, 'windows_x86_64', 'nightly-2026-10-09-258ab27', 'roc-windows_x86_64-nightly.zip', 'dd', 12.5, 1790000000000, 4);

-- R-SG5, R-RE5: the log index is max + 1 in the statement of the transaction. A used index is an error.
-- params: ["github.com/roc-lang/unicode/releases/download/{v}/", "0.1.0", "hash-one", 1790000000000]
INSERT INTO log (idx, grp, version, hash, time) SELECT COALESCE(MAX(idx), 0) + 1, ?, ?, ?, ? FROM log;
-- params: ["github.com/roc-lang/unicode/releases/download/{v}/", "0.2.0", "hash-two", 1790000000001]
INSERT INTO log (idx, grp, version, hash, time) SELECT COALESCE(MAX(idx), 0) + 1, ?, ?, ?, ? FROM log;
-- params: ["roc-lang/nightlies:linux_x86_64", "nightly-2026-10-09-258ab27", "sha256:aa", 1790000000002]
INSERT INTO log (idx, grp, version, hash, time) SELECT COALESCE(MAX(idx), 0) + 1, ?, ?, ?, ? FROM log;
-- expect-error: UNIQUE constraint failed: log.idx
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'g', 'v', 'h', 1);

-- R-RE9, R-RE15: a rowid table with a composite key. A key column does not take NULL (SQLite makes the key columns of a STRICT table NOT NULL).
INSERT INTO provenance (release, via, claims, time) VALUES (1, 0, '{"run_id":"1"}', 1790000000000);
-- expect-error: NOT NULL constraint failed: provenance.release
INSERT INTO provenance (release, via, claims, time) VALUES (NULL, 1, NULL, 1790000000000);
-- expect-error: NOT NULL constraint failed: provenance.via
INSERT INTO provenance (release, via, claims, time) VALUES (1, NULL, NULL, 1790000000000);
-- expect-error: NOT NULL constraint failed: repo_events.repo
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (NULL, 1, 0, NULL, 1, NULL, 2, NULL, NULL, 1);
-- expect-error: NOT NULL constraint failed: repo_events.seq
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (1, NULL, 0, NULL, 1, NULL, 2, NULL, NULL, 1);

-- R-RE1, R-IK7: kind is app 0, package 1 or platform 2.
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1, 0, '[]', NULL, NULL, 10);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (2, 1, '["Json","Decode"]', NULL, 'nightly-2026-10-09-258ab27', 10);
-- expect-error: CHECK constraint failed
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (3, 3, '[]', NULL, NULL, 10);

-- R-RE16, R-IK7: pass 0, fail 1, crash 3 (the G11 code). A hang (2) is not a hint, and 4 is no code.
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-5, 1, 1, 0, 3, 0, 1790000000000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-5, 2, 1, 0, 0, 0, 1790000000000);
-- expect-error: CHECK constraint failed
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-5, 3, 1, 0, 2, 0, 1790000000000);
-- expect-error: CHECK constraint failed
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-5, 4, 1, 0, 4, 0, 1790000000000);

-- R-RE17, R-RE18, R-CT3: a GitHub account is above 0, a machine is below 0.
INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (583231, 'octocat', 1790000000000, 1790000000000, 1790000000000);
-- expect-error: CHECK constraint failed
INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (0, 'zero', 1, 1, 1);
-- expect-error: CHECK constraint failed
INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (-1, 'machine', 1, 1, 1);
-- expect-error: cannot store REAL value in INTEGER column contributors.tokens_after
INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (5, 'real', 1.5, 1, 1);
INSERT INTO links (machine, contributor, time) VALUES (-1, 583231, 1790000000000);
-- expect-error: CHECK constraint failed
INSERT INTO links (machine, contributor, time) VALUES (0, 583231, 1790000000000);
-- expect-error: CHECK constraint failed
INSERT INTO links (machine, contributor, time) VALUES (7, 583231, 1790000000000);

-- R-IK7, R-RE11, R-TP11: repos.state is active 0, missing 1, moved 2. R-RE9: via is oidc 0 to ingest 3. R-RE15: action is bind 0 to operator 9.
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (1, 1, 2, 2, NULL, 1790000000000, 1790000000000);
-- expect-error: CHECK constraint failed
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (2, 1, 2, 3, NULL, 1790000000000, 1790000000000);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1790000000000);
-- expect-error: CHECK constraint failed
INSERT INTO provenance (release, via, claims, time) VALUES (1, 4, NULL, 1790000000000);
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (1, 1, 9, NULL, 1, NULL, 2, NULL, NULL, 1);
-- expect-error: CHECK constraint failed
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (1, 2, 10, NULL, 1, NULL, 2, NULL, NULL, 1);
