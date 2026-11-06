INSERT INTO names (id, kind, value) VALUES
  (5265119941757224538, 1, X'000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'),
  (5499626537489496528, 1, X'fffefdfcfbfaf9f8f7f6f5f4f3f2f1f0efeeedecebeae9e8e7e6e5e4e3e2e1e0'),
  (-3201922985822262901, 1, X'0707070707070707070707070707070707070707070707070707070707070707'),
  (-9216385313920979605, 1, X'0909090909090909090909090909090909090909090909090909090909090909'),
  (6050932919194431938, 1, X'c8c7c6c5c4c3c2c1c0bfbebdbcbbbab9b8b7b6b5b4b3b2b1b0afaeadacabaaa9'),
  (-2687166099708853831, 2, 'github.com/roc-lang/unicode/releases/download/{v}/'),
  (1924886514749142907, 2, 'github.com/roc-lang/unicode/releases/download/v{v}/'),
  (-6218357134827835138, 2, 'example.com/pkg/{v}/'),
  (-6689077047688997884, 2, 'github.com/roc-lang/other/releases/download/{v}/'),
  (-3025687567124958779, 3, 'roc-lang/unicode'),
  (4172983114642615821, 3, 'roc-lang/other'),
  (7823285000474088130, 3, 'roc-lang/moved');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (5265119941757224538, 1, '["Unicode","Utf"]', NULL, NULL, 12345);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (5499626537489496528, 1, '["Two"]', NULL, NULL, 222);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-3201922985822262901, 1, '["Three"]', NULL, NULL, 333);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-9216385313920979605, 2, '[]', NULL, 'nightly-2026-10-31-f7bef6b', 99);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (6050932919194431938, 0, '[]', -9216385313920979605, NULL, 7);
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (5265119941757224538, 'b', 5499626537489496528, 1924886514749142907, -9222246132652900353, '', 'https://github.com/roc-lang/unicode/releases/download/v4.1.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst');
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (5265119941757224538, 'a', -3201922985822262901, -2687166099708853831, -9223371929480462337, '', 'https://github.com/roc-lang/unicode/releases/download/0.25.1/US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx.tar.zst');
INSERT INTO artifact_targets (artifact, target) VALUES (-9216385313920979605, 9);
INSERT INTO artifact_targets (artifact, target) VALUES (-9216385313920979605, 34);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/roc-lang/unicode/releases/download/{v}/', '0.25.1', 'US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, -2687166099708853831, -9223371929480462337, '', -3201922985822262901, -3025687567124958779, 'https://github.com/roc-lang/unicode/releases/download/0.25.1/US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx.tar.zst', '0.25.1', NULL, 1700000000000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'github.com/roc-lang/unicode/releases/download/{v}/', '4.2.0', '1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, -2687166099708853831, -9222246128357933057, '', 5265119941757224538, -3025687567124958779, 'https://github.com/roc-lang/unicode/releases/download/4.2.0/1thX6LZfHDZZKUs92febYZhYRcXddmzfzF2NvTkPNE.tar.zst', '4.2.0', '0.1.0', 1700000100000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (3, 'github.com/roc-lang/unicode/releases/download/v{v}/', '4.1.0', 'JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (3, 1924886514749142907, -9222246132652900353, '', 5499626537489496528, -3025687567124958779, 'https://github.com/roc-lang/unicode/releases/download/v4.1.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst', 'v4.1.0', NULL, 1700000200000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (4, 'github.com/roc-lang/unicode/releases/download/{v}/', '4.3.0', 'JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (4, -2687166099708853831, -9222246124062965761, '', 5499626537489496528, -3025687567124958779, 'https://github.com/roc-lang/unicode/releases/download/4.3.0/JEJUoGfGEPTZ1XTwN39dYdFxYxDiDaSKVNy5qYWJmZt3.tar.zst', '4.3.0', NULL, 1700000300000, 0, 'edited', 1767225599000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (5, 'example.com/pkg/{v}/', '1.0.0', 'EWmDvi3hhz86LYi2NcD6YUp18DeeB5gDkwJzde3MgF9A', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (5, -6218357134827835138, -9223090561877999617, '', 6050932919194431938, NULL, 'https://example.com/pkg/1.0.0/EWmDvi3hhz86LYi2NcD6YUp18DeeB5gDkwJzde3MgF9A.tar.zst', NULL, NULL, 1700000400000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (6, 'github.com/roc-lang/other/releases/download/{v}/', '2.0.0', 'cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (6, -6689077047688997884, -9222809086901288961, '', -9216385313920979605, 4172983114642615821, 'https://github.com/roc-lang/other/releases/download/2.0.0/cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN.tar.zst', '2.0.0', NULL, 1700000500000, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-3025687567124958779, 1016, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-3025687567124958779, NULL, 1767222000000, 1767229200000, 0, 0);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (4172983114642615821, 1014, 2000, 2, 7823285000474088130, 1699999500000, 1699999500000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (4172983114642615821, NULL, NULL, 1767229200000, 0, 0);
-- Slice 122, R-AP49 `provenance`, R-RE9: the rows of the releases, inserted out of the order of strength.
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1767139200003), (2, 3, NULL, 1767139200003), (2, 0, NULL, 1767139200000), (3, 1, NULL, 1767139200001), (4, 3, NULL, 1767139200003), (4, 1, NULL, 1767139200001), (4, 2, NULL, 1767139200002), (5, 3, NULL, 1767139200003), (5, 2, NULL, 1767139200002), (5, 1, NULL, 1767139200001), (5, 0, NULL, 1767139200000), (6, 2, NULL, 1767139200002);
