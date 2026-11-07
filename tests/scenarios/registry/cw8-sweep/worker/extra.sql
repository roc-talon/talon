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
