-- Made by worker/tests/tools/mk-l3w-seed.mjs (slice 224). Do not edit by hand: change the spec and make it again.
INSERT INTO names (id, kind, value) VALUES
  (6637059302034951433, 1, X'2222222222222222222222222222222222222222222222222222222222222222'),
  (-8273415923550857927, 2, 'github.com/acme/json/releases/download/{v}/'),
  (-4825025842431960071, 3, 'acme/json'),
  (4652512588506025103, 1, X'3333333333333333333333333333333333333333333333333333333333333333'),
  (-454434528586430400, 2, 'github.com/acme/yaml/releases/download/{v}/'),
  (-3011319763571348593, 3, 'acme/yaml'),
  (9041074906827287096, 1, X'6666666666666666666666666666666666666666666666666666666666666666'),
  (-1611012400774957839, 2, 'github.com/acme/csv/releases/download/{v}/'),
  (-220142977263635327, 3, 'acme/csv');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (6637059302034951433, 1, '["Json"]', NULL, NULL, 222);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/acme/json/releases/download/{v}/', '2.1.0', '3JF3sEqM796hk5WFqA6EtmEwJQ9quALszsfJyvXNQKy3', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, -8273415923550857927, -9222809082606321665, '', 6637059302034951433, -4825025842431960071, 'https://github.com/acme/json/releases/download/2.1.0/3JF3sEqM796hk5WFqA6EtmEwJQ9quALszsfJyvXNQKy3.tar.zst', '2.1.0', NULL, 1792065600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1792062000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (4652512588506025103, 1, '["Yaml"]', NULL, NULL, 222);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'github.com/acme/yaml/releases/download/{v}/', '1.0.0', '4Ss5JMkXAD9Z7cktFEdrqeMuT6jGMF1pVozTyPHZ6zT4', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, -454434528586430400, -9223090561877999617, '', 4652512588506025103, -3011319763571348593, 'https://github.com/acme/yaml/releases/download/1.0.0/4Ss5JMkXAD9Z7cktFEdrqeMuT6jGMF1pVozTyPHZ6zT4.tar.zst', '1.0.0', NULL, 1792065600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (2, 3, NULL, 1792062000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (9041074906827287096, 1, '["Csv"]', NULL, NULL, 222);
INSERT INTO log (idx, grp, version, hash, time) VALUES (3, 'github.com/acme/csv/releases/download/{v}/', '1.0.0', '7tj9biW3KRJ7EEWmVUGigHiouCTXhV2dzcyvwma7Cyu7', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (3, -1611012400774957839, -9223090561877999617, '', 9041074906827287096, -220142977263635327, 'https://github.com/acme/csv/releases/download/1.0.0/7tj9biW3KRJ7EEWmVUGigHiouCTXhV2dzcyvwma7Cyu7.tar.zst', '1.0.0', NULL, 1792065600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (3, 3, NULL, 1792062000000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-4825025842431960071, 1, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-4825025842431960071, NULL, 1792062000000, 1792065600000, 0, 0);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-3011319763571348593, 2, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-3011319763571348593, NULL, 1792062000000, 1792065600000, 0, 0);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-220142977263635327, 3, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-220142977263635327, NULL, 1792062000000, 1792065600000, 0, 0);
-- Two toolchain leaves (log index 4 and 5, toolchains_leaf_check), the bot rows and one sweep row. nightly = days * 2^28 + sha7 (R-IK4); target 0 is any, source 0 is bot, result 0 is pass (R-IK7).
INSERT INTO log (idx, grp, version, hash, time) VALUES (4, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-10-29-aaaaaaa', 'sha256:0000000000000000000000000000000000000000000000000000000000000000', 1792062000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (5571556846250, 'linux_x86_64', 'nightly-2026-10-29-aaaaaaa', 'roc_nightly-linux_x86_64-2026-10-29-aaaaaaa.tar.gz', '0000000000000000000000000000000000000000000000000000000000000000', 123, 1793275200000, 4);
INSERT INTO log (idx, grp, version, hash, time) VALUES (5, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-10-30-ddddddd', 'sha256:0000000000000000000000000000000000000000000000000000000000000000', 1792062000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (5571878968797, 'linux_x86_64', 'nightly-2026-10-30-ddddddd', 'roc_nightly-linux_x86_64-2026-10-30-ddddddd.tar.gz', '0000000000000000000000000000000000000000000000000000000000000000', 123, 1793361600000, 5);
-- aaaaaaa: only the member at log index 3 has a bot row, so 2 members are missing.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES ((SELECT artifact FROM releases WHERE log_index = 3), 5571556846250, 0, 0, 0, NULL, 1792062000000, NULL);
-- ddddddd: each member has a bot row, and the sweep row (R-MX4) is up to log index 5.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES ((SELECT artifact FROM releases WHERE log_index = 1), 5571878968797, 0, 0, 0, NULL, 1792062000000, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES ((SELECT artifact FROM releases WHERE log_index = 2), 5571878968797, 0, 0, 0, NULL, 1792062000000, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES ((SELECT artifact FROM releases WHERE log_index = 3), 5571878968797, 0, 0, 0, NULL, 1792062000000, NULL);
INSERT INTO sweeps (nightly, target, upto_log_index, time) VALUES (5571878968797, 0, 5, 1792062000000);
