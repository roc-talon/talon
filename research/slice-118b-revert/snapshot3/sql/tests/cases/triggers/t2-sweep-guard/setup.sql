-- The index of research/bot-set/ B0, with the codes of R-IK7 (app 0, package 1, platform 2) and times in ms (1 day = 86400000).
-- Nightlies 1 to 4 are at the days 900 to 903, 5 at the day 300, 6 at the day 301, 7 and 8 at the day 900. Each has 2 rows in toolchains (R-RE4, R-MX16).
-- R-SG8: each toolchains row has its compiler leaf (log 1 to 16, in the order of the rows), and each release its leaf. A release n has log_index 16 + n.
INSERT INTO log (idx, grp, version, hash, time) VALUES
  (1, 'roc-lang/nightlies:linux_x86_64', 't1', 'sha256:s', 1790000000000),
  (2, 'roc-lang/nightlies:macos_arm64', 't1', 'sha256:s', 1790000000000),
  (3, 'roc-lang/nightlies:linux_x86_64', 't2', 'sha256:s', 1790000000000),
  (4, 'roc-lang/nightlies:macos_arm64', 't2', 'sha256:s', 1790000000000),
  (5, 'roc-lang/nightlies:linux_x86_64', 't3', 'sha256:s', 1790000000000),
  (6, 'roc-lang/nightlies:macos_arm64', 't3', 'sha256:s', 1790000000000),
  (7, 'roc-lang/nightlies:linux_x86_64', 't4', 'sha256:s', 1790000000000),
  (8, 'roc-lang/nightlies:macos_arm64', 't4', 'sha256:s', 1790000000000),
  (9, 'roc-lang/nightlies:linux_x86_64', 't5', 'sha256:s', 1790000000000),
  (10, 'roc-lang/nightlies:macos_arm64', 't5', 'sha256:s', 1790000000000),
  (11, 'roc-lang/nightlies:linux_x86_64', 't6', 'sha256:s', 1790000000000),
  (12, 'roc-lang/nightlies:macos_arm64', 't6', 'sha256:s', 1790000000000),
  (13, 'roc-lang/nightlies:linux_x86_64', 't7', 'sha256:s', 1790000000000),
  (14, 'roc-lang/nightlies:macos_arm64', 't7', 'sha256:s', 1790000000000),
  (15, 'roc-lang/nightlies:linux_x86_64', 't8', 'sha256:s', 1790000000000),
  (16, 'roc-lang/nightlies:macos_arm64', 't8', 'sha256:s', 1790000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES
  (1, 'linux_x86_64', 't1', 'a', 's', 1001, 77760000000, 1),
  (1, 'macos_arm64', 't1', 'a', 's', 1002, 77760000000, 2),
  (2, 'linux_x86_64', 't2', 'a', 's', 1003, 77846400000, 3),
  (2, 'macos_arm64', 't2', 'a', 's', 1004, 77846400000, 4),
  (3, 'linux_x86_64', 't3', 'a', 's', 1005, 77932800000, 5),
  (3, 'macos_arm64', 't3', 'a', 's', 1006, 77932800000, 6),
  (4, 'linux_x86_64', 't4', 'a', 's', 1007, 78019200000, 7),
  (4, 'macos_arm64', 't4', 'a', 's', 1008, 78019200000, 8),
  (5, 'linux_x86_64', 't5', 'a', 's', 1009, 25920000000, 9),
  (5, 'macos_arm64', 't5', 'a', 's', 1010, 25920000000, 10),
  (6, 'linux_x86_64', 't6', 'a', 's', 1011, 26006400000, 11),
  (6, 'macos_arm64', 't6', 'a', 's', 1012, 26006400000, 12),
  (7, 'linux_x86_64', 't7', 'a', 's', 1013, 77760000000, 13),
  (7, 'macos_arm64', 't7', 'a', 's', 1014, 77760000000, 14),
  (8, 'linux_x86_64', 't8', 'a', 's', 1015, 77760000000, 15),
  (8, 'macos_arm64', 't8', 'a', 's', 1016, 77760000000, 16);
INSERT INTO names (id, kind, value) VALUES (1, 2, 'g1'), (2, 2, 'g2'), (3, 2, 'g3'), (4, 2, 'g4'), (5, 2, 'g5'), (6, 2, 'g6'), (7, 2, 'g7'), (8, 2, 'g8');
-- Artifacts 1 to 6 and 10 to 16 are packages, 9 is a platform, 7 is an app.
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES
  (1, 1, '[]', NULL, NULL, 1),
  (2, 1, '[]', NULL, NULL, 1),
  (3, 1, '[]', NULL, NULL, 1),
  (4, 1, '[]', NULL, NULL, 1),
  (5, 1, '[]', NULL, NULL, 1),
  (6, 1, '[]', NULL, NULL, 1),
  (7, 0, '[]', NULL, NULL, 1),
  (9, 2, '[]', NULL, NULL, 1),
  (10, 1, '[]', NULL, NULL, 1),
  (11, 1, '[]', NULL, NULL, 1),
  (12, 1, '[]', NULL, NULL, 1),
  (13, 1, '[]', NULL, NULL, 1),
  (14, 1, '[]', NULL, NULL, 1),
  (15, 1, '[]', NULL, NULL, 1),
  (16, 1, '[]', NULL, NULL, 1);
-- The releases (n, form, version, artifact, published_at). The version keys are key XOR 2^63, as signed:
--   0.1.0 -9223372032559742977, 0.1.1 -9223372032559677441, 0.2.0 -9223372028264775681, 1.0.0 -9223090561877999617, 2.0.0 -9222809086901288961.
--   1  form 1  0.1.0  A1   day 800   (an older patch of the series 0.1: not a member)
--   2  form 1  0.1.1  A2   day 850   (the newest of the series 0.1: a member)
--   3  form 1  0.2.0  A3   day 870   (the newest of the series 0.2 until release 9: a member)
--   4  form 2  1.0.0  A4   day 100   (an old series, out of the window of nightly 1: not a member there)
--   5  form 2  2.0.0  A5   day 880   (a member)
--   6  form 3  1.0.0  A6   day 10    (out of the window, but the newest of its group: a member)
--   7  form 4  1.0.0  A7   day 890   (an app: never a member)
--   8  form 5  1.0.0  A9   day 895   (a platform: a member)
INSERT INTO log (idx, grp, version, hash, time) VALUES
  (17, 'g1', '0.1.0', 'H1', 1790000000000),
  (18, 'g1', '0.1.1', 'H2', 1790000000000),
  (19, 'g1', '0.2.0', 'H3', 1790000000000),
  (20, 'g2', '1.0.0', 'H4', 1790000000000),
  (21, 'g2', '2.0.0', 'H5', 1790000000000),
  (22, 'g3', '1.0.0', 'H6', 1790000000000),
  (23, 'g4', '1.0.0', 'H7', 1790000000000),
  (24, 'g5', '1.0.0', 'H9', 1790000000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES
  (17, 1, -9223372032559742977, '', 1, NULL, 'u', NULL, NULL, 69120000000, 0, NULL, NULL),
  (18, 1, -9223372032559677441, '', 2, NULL, 'u', NULL, NULL, 73440000000, 0, NULL, NULL),
  (19, 1, -9223372028264775681, '', 3, NULL, 'u', NULL, NULL, 75168000000, 0, NULL, NULL),
  (20, 2, -9223090561877999617, '', 4, NULL, 'u', NULL, NULL, 8640000000, 0, NULL, NULL),
  (21, 2, -9222809086901288961, '', 5, NULL, 'u', NULL, NULL, 76032000000, 0, NULL, NULL),
  (22, 3, -9223090561877999617, '', 6, NULL, 'u', NULL, NULL, 864000000, 0, NULL, NULL),
  (23, 4, -9223090561877999617, '', 7, NULL, 'u', NULL, NULL, 76896000000, 0, NULL, NULL),
  (24, 5, -9223090561877999617, '', 9, NULL, 'u', NULL, NULL, 77328000000, 0, NULL, NULL);
