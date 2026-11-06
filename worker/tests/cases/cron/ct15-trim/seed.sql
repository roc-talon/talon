-- R-CT15: the trim. Now is 1767225600000 (2026-01-01); a compiler is old below 1735689600000 (365 days before).
-- N1 9100 (published 1700000000000) is the oldest, N2 9050 (1720000000000) is second: the ids are NOT in the order of age, so 'oldest first' is not the id order.
-- N3 9200 has 2 targets: the smallest published_at (1730000000000) decides, so it is old. N4 9300 is at exactly 365 days: not old. N5 9400 is new.
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'roc-lang/nightlies:linux_x86_64', 'nightly-2023-11-14-aaaaaaa', 'sha256:1111111111111111111111111111111111111111111111111111111111111111', 1690000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (9100, 'linux_x86_64', 'nightly-2023-11-14-aaaaaaa', 'roc_nightly-linux_x86_64.tar.gz', '1111111111111111111111111111111111111111111111111111111111111111', 1000, 1700000000000, 1);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'roc-lang/nightlies:linux_x86_64', 'nightly-2024-07-03-bbbbbbb', 'sha256:2222222222222222222222222222222222222222222222222222222222222222', 1690000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (9050, 'linux_x86_64', 'nightly-2024-07-03-bbbbbbb', 'roc_nightly-linux_x86_64.tar.gz', '2222222222222222222222222222222222222222222222222222222222222222', 1000, 1720000000000, 2);
INSERT INTO log (idx, grp, version, hash, time) VALUES (3, 'roc-lang/nightlies:linux_x86_64', 'nightly-2024-10-27-ccccccc', 'sha256:3333333333333333333333333333333333333333333333333333333333333333', 1690000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (9200, 'linux_x86_64', 'nightly-2024-10-27-ccccccc', 'roc_nightly-linux_x86_64.tar.gz', '3333333333333333333333333333333333333333333333333333333333333333', 1000, 1730000000000, 3);
INSERT INTO log (idx, grp, version, hash, time) VALUES (4, 'roc-lang/nightlies:macos_arm64', 'nightly-2024-10-27-ccccccc', 'sha256:4444444444444444444444444444444444444444444444444444444444444444', 1690000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (9200, 'macos_arm64', 'nightly-2024-10-27-ccccccc', 'roc_nightly-macos_arm64.tar.gz', '4444444444444444444444444444444444444444444444444444444444444444', 1000, 1760000000000, 4);
INSERT INTO log (idx, grp, version, hash, time) VALUES (5, 'roc-lang/nightlies:linux_x86_64', 'nightly-2025-01-01-ddddddd', 'sha256:5555555555555555555555555555555555555555555555555555555555555555', 1690000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (9300, 'linux_x86_64', 'nightly-2025-01-01-ddddddd', 'roc_nightly-linux_x86_64.tar.gz', '5555555555555555555555555555555555555555555555555555555555555555', 1000, 1735689600000, 5);
INSERT INTO log (idx, grp, version, hash, time) VALUES (6, 'roc-lang/nightlies:linux_x86_64', 'nightly-2025-12-30-eeeeeee', 'sha256:6666666666666666666666666666666666666666666666666666666666666666', 1690000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (9400, 'linux_x86_64', 'nightly-2025-12-30-eeeeeee', 'roc_nightly-linux_x86_64.tar.gz', '6666666666666666666666666666666666666666666666666666666666666666', 1000, 1767000000000, 6);
-- A probe: the order of the DELETE of contributions is the order of the compilers.
CREATE TABLE probe (n INTEGER PRIMARY KEY, nightly INTEGER NOT NULL) STRICT;
CREATE TRIGGER probe_trim AFTER DELETE ON contributions BEGIN INSERT INTO probe (nightly) VALUES (OLD.nightly); END;
-- Contributors: 4242 (account, 1 machine, old totals), 77, and the machine -5 (no account). Result 0 pass, 1 fail, 3 crash.
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 101, 9100, 0, 0, 1, 1700000100000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (77, 101, 9100, 0, 1, 1, 1700000200000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 102, 9100, 0, 1, 1, 1700000400000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (-5, 103, 9100, 0, 0, 1, 1700000600000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 103, 9050, 8, 3, 1, 1720000100000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (77, 104, 9050, 0, 0, 1, 1720000200000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 105, 9200, 0, 0, 1, 1730000100000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 101, 9300, 0, 0, 1, 1735689700000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (4242, 102, 9400, 0, 0, 1, 1767224000000);
INSERT INTO contributions (contributor, artifact, nightly, target, result, talon_version, time) VALUES (77, 102, 9400, 0, 0, 1, 1767224000100);
-- bot rows (source 0) and one smoke row (source 1). The compat rows are never trimmed.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (101, 9100, 0, 0, 0, NULL, 1700000300000, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (103, 9050, 8, 0, 3, NULL, 1710000000000, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (105, 9200, 0, 0, 1, NULL, 1730000300000, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (102, 9100, 0, 1, 0, NULL, 1700000500000, NULL);
INSERT INTO contributors (contributor, login, tokens_after, first_time, last_time) VALUES (4242, 'someone', 0, 1767225000000, 1767225000000);
INSERT INTO links (machine, contributor, time) VALUES (-6890997442180345381, 4242, 1767225000000);
INSERT INTO contributor_totals (contributor, counted, first, agreed, disagreed, unconfirmed, first_time, last_time) VALUES (4242, 10, 4, 2, 1, 7, 1690000000000, 1700000150000);
INSERT INTO contributor_totals (contributor, counted, first, agreed, disagreed, unconfirmed, first_time, last_time) VALUES (88, 3, 1, 1, 1, 1, 1690000000100, 1690000000900);
