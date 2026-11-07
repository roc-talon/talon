-- The toolchain rows of the twin case dt3-update-range-log (nightly = days * 2^28 + sha7, R-IK4).
-- The twin has the log indexes 10, 20 and 40 for the rows, and releases at 20 and 40 too. One log has one leaf for each index (sql/0002_triggers.sql, toolchains_leaf_check),
-- so here the rows are at 10, 19 and 41 (a row at 10 and 19 is visible at log:30, the row at 41 is hidden, as the rows 10, 20 and 40 of the twin).
-- The 3 indexes are leaves of the toolchains: the seed made releases there, so extra.sql turns them into toolchain leaves.
DELETE FROM provenance WHERE release = 10;
DELETE FROM releases WHERE log_index = 10;
UPDATE log SET grp = 'roc-lang/nightlies:linux_x86_64', version = 'nightly-2026-10-11-1a2b3c4', hash = 'sha256:3e4ebcdac764d6259eb45a22f647754c94d15d36f0a04ede0cdd83f0ca28a703' WHERE idx = 10;
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (5566573491140, 'linux_x86_64', 'nightly-2026-10-11-1a2b3c4', 'roc_nightly-linux_x86_64-2026-10-11-1a2b3c4.tar.gz', '3e4ebcdac764d6259eb45a22f647754c94d15d36f0a04ede0cdd83f0ca28a703', 1010, 1791676800000, 10);
DELETE FROM provenance WHERE release = 19;
DELETE FROM releases WHERE log_index = 19;
UPDATE log SET grp = 'roc-lang/nightlies:linux_x86_64', version = 'nightly-2026-10-12-2664a27', hash = 'sha256:fc5fa5a2d050ea058f960436a9514119f70d405a8eb17adf3dac6855b127b4e4' WHERE idx = 19;
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (5566854744615, 'linux_x86_64', 'nightly-2026-10-12-2664a27', 'roc_nightly-linux_x86_64-2026-10-12-2664a27.tar.gz', 'fc5fa5a2d050ea058f960436a9514119f70d405a8eb17adf3dac6855b127b4e4', 1020, 1791763200000, 19);
DELETE FROM provenance WHERE release = 41;
DELETE FROM releases WHERE log_index = 41;
UPDATE log SET grp = 'roc-lang/nightlies:linux_x86_64', version = 'nightly-2026-10-13-5e6f7a8', hash = 'sha256:f0dfb6f8df6a855512b93e5fba9ae0c5a6986106908e9feb75698009a21e8a4e' WHERE idx = 41;
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (5567181944744, 'linux_x86_64', 'nightly-2026-10-13-5e6f7a8', 'roc_nightly-linux_x86_64-2026-10-13-5e6f7a8.tar.gz', 'f0dfb6f8df6a855512b93e5fba9ae0c5a6986106908e9feb75698009a21e8a4e', 1040, 1791849600000, 41);
-- The release at log index 37 is withdrawn (R-AP49), as in the fake answer.
UPDATE releases SET withdrawn = 'prereleased', withdrawn_at = 1792062000000 WHERE log_index = 37;
