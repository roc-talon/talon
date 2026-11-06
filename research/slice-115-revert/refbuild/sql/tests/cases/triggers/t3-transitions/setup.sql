-- Seven nightlies, with 2 rows in toolchains each (R-RE4). The order of R-MX16 is the date (nightly >> 28), then t (published_at), then the id:
--   date 0: 100 (t 1000), 300 (2000), 200 (3000), 400 (4000), 500 (4000). The order of the ids is 100, 200, 300, 400, 500: it is not the order.
--   date 1: 268435461 (t 8000). date 2: 536870919 (t 7000). The t of the date 2 is below the t of the date 1: the date comes first.
-- R-SG8: each toolchains row has its compiler leaf (log 1 to 14), each release its leaf (15 and 16).
INSERT INTO log (idx, grp, version, hash, time) VALUES
  (1, 'roc-lang/nightlies:linux_x86_64', 't100', 'sha256:s', 1790000000000),
  (2, 'roc-lang/nightlies:macos_arm64', 't100', 'sha256:s', 1790000000000),
  (3, 'roc-lang/nightlies:linux_x86_64', 't300', 'sha256:s', 1790000000000),
  (4, 'roc-lang/nightlies:macos_arm64', 't300', 'sha256:s', 1790000000000),
  (5, 'roc-lang/nightlies:linux_x86_64', 't200', 'sha256:s', 1790000000000),
  (6, 'roc-lang/nightlies:macos_arm64', 't200', 'sha256:s', 1790000000000),
  (7, 'roc-lang/nightlies:linux_x86_64', 't400', 'sha256:s', 1790000000000),
  (8, 'roc-lang/nightlies:macos_arm64', 't400', 'sha256:s', 1790000000000),
  (9, 'roc-lang/nightlies:linux_x86_64', 't500', 'sha256:s', 1790000000000),
  (10, 'roc-lang/nightlies:macos_arm64', 't500', 'sha256:s', 1790000000000),
  (11, 'roc-lang/nightlies:linux_x86_64', 't268435461', 'sha256:s', 1790000000000),
  (12, 'roc-lang/nightlies:macos_arm64', 't268435461', 'sha256:s', 1790000000000),
  (13, 'roc-lang/nightlies:linux_x86_64', 't536870919', 'sha256:s', 1790000000000),
  (14, 'roc-lang/nightlies:macos_arm64', 't536870919', 'sha256:s', 1790000000000),
  (15, 'g1', '1.0.0', 'H1', 1790000000000),
  (16, 'g1', '1.0.1', 'H11', 1790000000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES
  (100, 'linux_x86_64', 't100', 'a', 's', 1000, 1),
  (100, 'macos_arm64', 't100', 'a', 's', 1000, 2),
  (300, 'linux_x86_64', 't300', 'a', 's', 2000, 3),
  (300, 'macos_arm64', 't300', 'a', 's', 2000, 4),
  (200, 'linux_x86_64', 't200', 'a', 's', 3000, 5),
  (200, 'macos_arm64', 't200', 'a', 's', 3000, 6),
  (400, 'linux_x86_64', 't400', 'a', 's', 4000, 7),
  (400, 'macos_arm64', 't400', 'a', 's', 4000, 8),
  (500, 'linux_x86_64', 't500', 'a', 's', 4000, 9),
  (500, 'macos_arm64', 't500', 'a', 's', 4000, 10),
  (268435461, 'linux_x86_64', 't268435461', 'a', 's', 8000, 11),
  (268435461, 'macos_arm64', 't268435461', 'a', 's', 8000, 12),
  (536870919, 'linux_x86_64', 't536870919', 'a', 's', 7000, 13),
  (536870919, 'macos_arm64', 't536870919', 'a', 's', 7000, 14);
-- Artifacts 1 and 11 are packages with a release each (1.0.0 and 1.0.1 of form 1, log 15 and 16). The bot set at bound 15 is A1. A2 to A9 are not indexed: they are outside the set.
INSERT INTO names (id, kind, value) VALUES (1, 2, 'g1');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1, 1, '[]', NULL, NULL, 1), (11, 1, '[]', NULL, NULL, 1);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES
  (15, 1, -9223090561877999617, '', 1, NULL, 'u', NULL, NULL, 100, 0, NULL, NULL),
  (16, 1, -9223090561877934081, '', 11, NULL, 'u', NULL, NULL, 100, 0, NULL, NULL);
