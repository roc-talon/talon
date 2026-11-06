-- Slice 115b, case a1-audit. Artifacts: 1 package (hash 0x01), 2 platform (0x02), 3 app (0x03), 4 package (0x00). Nightlies: 1 and 2 have a toolchains row, 3 has none.
-- Targets: any 0, x64glibc 8 (from sql/0001_init.sql). Times are ms.
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'roc-lang/nightlies:linux_x86_64', 't1', 'sha256:a', 1790000000000), (2, 'roc-lang/nightlies:linux_x86_64', 't2', 'sha256:b', 1790000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (1, 'linux_x86_64', 't1', 'a', 'a', 1790000000000, 1), (2, 'linux_x86_64', 't2', 'a', 'b', 1790100000000, 2);
INSERT INTO names (id, kind, value) VALUES (11, 1, X'0101010101010101010101010101010101010101010101010101010101010101'), (12, 1, X'0202020202020202020202020202020202020202020202020202020202020202'),
  (13, 1, X'0303030303030303030303030303030303030303030303030303030303030303'), (14, 1, X'0000000000000000000000000000000000000000000000000000000000000000');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (11, 1, '[]', NULL, NULL, 1), (12, 2, '[]', NULL, NULL, 1), (13, 0, '[]', NULL, NULL, 1), (14, 1, '[]', NULL, NULL, 1);
-- The hints (artifact, nightly, target, talon_version, pass, fail, crash, first_time, last_time).
INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time) VALUES
  (11, 1, 0, 1, 3, 1, 0, 1, 1),
  (11, 1, 0, 2, 2, 0, 0, 1, 1),
  (11, 2, 0, 1, 1, 0, 0, 1, 1),
  (12, 1, 8, 2, 2, 2, 1, 1, 1),
  (12, 1, 0, 3, 0, 3, 0, 1, 1),
  (13, 1, 8, 1, 9, 9, 9, 1, 1),
  (11, 3, 0, 1, 9, 0, 0, 1, 1),
  (14, 1, 0, 1, 1, 1, 1, 1, 1);
-- A bot row on (11, nightly 2, any): its pair is out. An author row on (12, nightly 1, any) stays a pair.
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (11, 2, 0, 0, 0, NULL, 1790000000000, NULL), (12, 1, 0, 1, 1, NULL, 1790000000000, 1);
