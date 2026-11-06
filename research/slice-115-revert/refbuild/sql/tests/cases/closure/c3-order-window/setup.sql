-- Made by research/slice-110-revert/gen/mk_w1.py. R-MX16 order: N0 (an earlier date, the latest t), N2 and N3 (one date, one t: by id), N1 (the same date, a later t),
-- N4 (a later date, the earliest t). P has compat rows and no toolchains row. The transition row of N3 names N0 as previous, but N2 is adjacent:
-- it does not make N2 to N3 flat. N1 has 2 toolchains rows.
INSERT INTO toolchains VALUES (5490310381577, 'linux_x86_64', 'nightly-2025-12-31-0000009', 'roc_nightly-linux_x86_64.tar.gz', 'abababababababababababababababababababababababababababababababab', 5000, 1);
INSERT INTO toolchains VALUES (5490578817026, 'linux_x86_64', 'nightly-2026-01-01-0000002', 'roc_nightly-linux_x86_64.tar.gz', 'abababababababababababababababababababababababababababababababab', 500, 2);
INSERT INTO toolchains VALUES (5490578817027, 'linux_x86_64', 'nightly-2026-01-01-0000003', 'roc_nightly-linux_x86_64.tar.gz', 'abababababababababababababababababababababababababababababababab', 500, 3);
INSERT INTO toolchains VALUES (5490578817025, 'linux_x86_64', 'nightly-2026-01-01-0000001', 'roc_nightly-linux_x86_64.tar.gz', 'abababababababababababababababababababababababababababababababab', 1000, 4);
INSERT INTO toolchains VALUES (5490578817025, 'macos_apple_silicon', 'nightly-2026-01-01-0000001', 'roc_nightly-macos_apple_silicon.tar.gz', 'abababababababababababababababababababababababababababababababab', 1000, 5);
INSERT INTO toolchains VALUES (5490847252484, 'linux_x86_64', 'nightly-2026-01-02-0000004', 'roc_nightly-linux_x86_64.tar.gz', 'abababababababababababababababababababababababababababababababab', 100, 6);
INSERT INTO names VALUES (10, 1, x'0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A'), (11, 1, x'0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B');
INSERT INTO artifacts VALUES (10, 1, '[]', NULL, NULL, 1), (11, 1, '[]', NULL, NULL, 1);
INSERT INTO compat VALUES (10, 5490310381577, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat VALUES (10, 5490578817026, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat VALUES (10, 5490578817027, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat VALUES (10, 5490578817025, 0, 0, 1, 'd1', 1, NULL);
INSERT INTO compat VALUES (10, 5490847252484, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat VALUES (10, 5490578817029, 0, 0, 1, 'dp', 1, NULL);
INSERT INTO compat VALUES (11, 5490578817026, 0, 1, 0, NULL, 1, 3);
INSERT INTO compat VALUES (11, 5490578817026, 0, 0, 2, NULL, 1, NULL);
INSERT INTO compat VALUES (11, 5490310381577, 0, 1, 1, 'e1', 1, 3);
INSERT INTO compat VALUES (11, 5490578817025, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat VALUES (11, 5490847252484, 0, 1, 0, NULL, 1, 3);
INSERT INTO compat VALUES (11, 5490847252484, 0, 0, 3, NULL, 1, NULL);
INSERT INTO transitions VALUES (5490578817025, 0, 5490578817027, 2, 0), (5490578817027, 0, 5490310381577, 2, 0), (5490847252484, 0, 5490578817025, 2, 1);
INSERT INTO compat_hints VALUES (10, 5490578817027, 0, 1, 1, 0, 0, 1, 1), (10, 5490578817027, 0, 2, 2, 1, 0, 1, 1), (10, 5490578817025, 0, 1, 0, 0, 1, 1, 1), (10, 5490578817029, 0, 1, 9, 0, 0, 1, 1);
