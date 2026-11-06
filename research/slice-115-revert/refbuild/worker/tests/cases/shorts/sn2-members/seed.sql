INSERT OR IGNORE INTO names (id, kind, value) VALUES
  (8648082882343705571, 3, 'a/roc-yank'),
  (589881378150885101, 1, X'c51f9a638de263a4e40cf13f8e2686a00bcd2fccfb228bda99d87170e0fb6ed5'),
  (-288625097934535527, 2, 'github.com/a/roc-yank/releases/download/{v}/'),
  (2759663798354095486, 3, 'b/wd'),
  (389176617469831083, 1, X'8f969b63809a4588328dad59e9eb141c7b038a1e1859b0cf4a8620c39d364eee'),
  (-8923056560953909025, 2, 'github.com/b/wd/releases/download/{v}/'),
  (7215242505193377378, 3, 'c/ghost'),
  (-475686483915552227, 3, 'd/roc-roc-x'),
  (-4162710664704680015, 1, X'8f87ac64bc22602e441328b134e27de256d0f434e2c30e3db8f899e1899dbc92'),
  (185826375936192281, 2, 'github.com/d/roc-roc-x/releases/download/{v}/'),
  (2075613316528170171, 3, 'e/rocx'),
  (2657590585724417227, 1, X'3bc0a0228b7d8394746fd119115fbecceb2de4c2caa1b138abfe2819ae9db197'),
  (-2318870880428672048, 2, 'github.com/e/rocx/releases/download/{v}/'),
  (4198132712249940744, 3, 'f/multi'),
  (-5124133426376317812, 1, X'e38ad01a87e35155fc36e61e4959ef0340fac019ed430ef82805d16116a38d91'),
  (-350021633164908036, 2, 'github.com/f/multi/releases/download/{v}/'),
  (-3725434793876164920, 1, X'2c37c5af50d9f99e1941b9210f2b0c5421f2e29d7eeb4a6c1c7e96665424d8e8'),
  (3343545392565248770, 2, 'github.com/f/multi/releases/download/v{v}/'),
  (2309984245554277494, 3, 'g/roc-'),
  (-4987851195974544915, 1, X'92bbe5055fa7bbe5531375dea86bf6477191889e14c604b710cb864486ff532a'),
  (7712915073166325740, 2, 'github.com/g/roc-/releases/download/{v}/');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (589881378150885101, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (5, 'github.com/a/roc-yank/releases/download/{v}/', '1.5.0', 'EGVGT7pN3zRZhmkSjUCngpEXQDffTgC5PCA2H6KLpk4L', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (5, -288625097934535527, -9223090540403163137, '', 589881378150885101, 8648082882343705571, 'https://github.com/a/roc-yank/releases/download/1.5.0/EGVGT7pN3zRZhmkSjUCngpEXQDffTgC5PCA2H6KLpk4L.tar.zst', '1.5.0', NULL, 1700000000005, 1, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (8648082882343705571, 1955, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (389176617469831083, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (6, 'github.com/b/wd/releases/download/{v}/', '1.6.0', 'AfWVuVYEkEutBfqSyUqSADQiUHUHshmMRkdozrQPCVHf', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (6, -8923056560953909025, -9223090536108195841, '', 389176617469831083, 2759663798354095486, 'https://github.com/b/wd/releases/download/1.6.0/AfWVuVYEkEutBfqSyUqSADQiUHUHshmMRkdozrQPCVHf.tar.zst', '1.6.0', NULL, 1700000000006, 0, 'edited', 1767225599000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (2759663798354095486, 1371, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (7215242505193377378, 1702, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-4162710664704680015, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (7, 'github.com/d/roc-roc-x/releases/download/{v}/', '1.7.0', 'AfHHt366jXueHt837EUH3FMxFFuzbG9G3vn31FDkopqw', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (7, 185826375936192281, -9223090531813228545, '', -4162710664704680015, -475686483915552227, 'https://github.com/d/roc-roc-x/releases/download/1.7.0/AfHHt366jXueHt837EUH3FMxFFuzbG9G3vn31FDkopqw.tar.zst', '1.7.0', NULL, 1700000000007, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-475686483915552227, 2012, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (2657590585724417227, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (8, 'github.com/e/rocx/releases/download/{v}/', '1.8.0', '52FQxsb6sLSbLvSkz8ugTdnoGNT8xwpifW5wD6TTrvBQ', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (8, -2318870880428672048, -9223090527518261249, '', 2657590585724417227, 2075613316528170171, 'https://github.com/e/rocx/releases/download/1.8.0/52FQxsb6sLSbLvSkz8ugTdnoGNT8xwpifW5wD6TTrvBQ.tar.zst', '1.8.0', NULL, 1700000000008, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (2075613316528170171, 1599, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-5124133426376317812, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (9, 'github.com/f/multi/releases/download/{v}/', '1.9.0', 'GKEKE4ktULZmKEQ1T8qgfSEWdhZUKGQEkmye5eb9BkzC', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (9, -350021633164908036, -9223090523223293953, '', -5124133426376317812, 4198132712249940744, 'https://github.com/f/multi/releases/download/1.9.0/GKEKE4ktULZmKEQ1T8qgfSEWdhZUKGQEkmye5eb9BkzC.tar.zst', '1.9.0', NULL, 1700000000009, 0, NULL, NULL);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-3725434793876164920, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (3, 'github.com/f/multi/releases/download/v{v}/', '1.3.0', '3ycGJqeYfbbD4xN4LJu6FQQCfDEiL68Xt4nQVKtErnto', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (3, 3343545392565248770, -9223090548993097729, '', -3725434793876164920, 4198132712249940744, 'https://github.com/f/multi/releases/download/v1.3.0/3ycGJqeYfbbD4xN4LJu6FQQCfDEiL68Xt4nQVKtErnto.tar.zst', '1.3.0', NULL, 1700000000003, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (4198132712249940744, 1711, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-4987851195974544915, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (10, 'github.com/g/roc-/releases/download/{v}/', '1.10.0', 'AsnhXqUuWkyAqyJRK3zXo3nQwxQvgR2R67xunLKokVYV', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (10, 7712915073166325740, -9223090518928326657, '', -4987851195974544915, 2309984245554277494, 'https://github.com/g/roc-/releases/download/1.10.0/AsnhXqUuWkyAqyJRK3zXo3nQwxQvgR2R67xunLKokVYV.tar.zst', '1.10.0', NULL, 1700000000010, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (2309984245554277494, 1526, 2000, 0, NULL, 1699999000000, 1699999000000);
