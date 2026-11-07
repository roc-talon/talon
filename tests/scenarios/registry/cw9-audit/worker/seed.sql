-- Made by worker/tests/tools/mk-l3w-seed.mjs (slice 224). Do not edit by hand: change the spec and make it again.
INSERT INTO names (id, kind, value) VALUES
  (9041074906827287096, 1, X'6666666666666666666666666666666666666666666666666666666666666666'),
  (-8273415923550857927, 2, 'github.com/acme/json/releases/download/{v}/'),
  (-4825025842431960071, 3, 'acme/json'),
  (-4418864005132459968, 1, X'1111111111111111111111111111111111111111111111111111111111111111'),
  (-454434528586430400, 2, 'github.com/acme/yaml/releases/download/{v}/'),
  (-3011319763571348593, 3, 'acme/yaml');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (9041074906827287096, 1, '["Json"]', NULL, NULL, 222);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/acme/json/releases/download/{v}/', '2.1.0', '7tj9biW3KRJ7EEWmVUGigHiouCTXhV2dzcyvwma7Cyu7', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, -8273415923550857927, -9222809082606321665, '', 9041074906827287096, -4825025842431960071, 'https://github.com/acme/json/releases/download/2.1.0/7tj9biW3KRJ7EEWmVUGigHiouCTXhV2dzcyvwma7Cyu7.tar.zst', '2.1.0', NULL, 1792065600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1792062000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-4418864005132459968, 1, '["Yaml"]', NULL, NULL, 222);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'github.com/acme/yaml/releases/download/{v}/', '1.0.0', '29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, -454434528586430400, -9223090561877999617, '', -4418864005132459968, -3011319763571348593, 'https://github.com/acme/yaml/releases/download/1.0.0/29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2.tar.zst', '1.0.0', NULL, 1792065600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (2, 3, NULL, 1792062000000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-4825025842431960071, 1, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-4825025842431960071, NULL, 1792062000000, 1792065600000, 0, 0);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-3011319763571348593, 2, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-3011319763571348593, NULL, 1792062000000, 1792065600000, 0, 0);
-- A toolchain leaf (log index 3, toolchains_leaf_check) and 2 hint rows with no bot row (R-AP40). nightly = days * 2^28 + sha7 (R-IK4); target 0 is any (R-IK7). talon_version 1 is a code, not a text (R-IK8).
INSERT INTO log (idx, grp, version, hash, time) VALUES (3, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-10-20-bbbbbbb', 'sha256:0000000000000000000000000000000000000000000000000000000000000000', 1792062000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (5569158822843, 'linux_x86_64', 'nightly-2026-10-20-bbbbbbb', 'roc_nightly-linux_x86_64-2026-10-20-bbbbbbb.tar.gz', '0000000000000000000000000000000000000000000000000000000000000000', 123, 1792497600000, 3);
INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time) VALUES ((SELECT artifact FROM releases WHERE log_index = 1), 5569158822843, 0, 1, 5, 1, 0, 1792062000000, 1792062000000);
INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time) VALUES ((SELECT artifact FROM releases WHERE log_index = 2), 5569158822843, 0, 1, 0, 2, 1, 1792062000000, 1792062000000);
