INSERT OR IGNORE INTO names (id, kind, value) VALUES
  (6917856169256204455, 3, 'o/s1'),
  (2362466365405466888, 1, X'015d43be2692718f527b8ddad7ab1c62394830169526fc2d310a058fbc86b923'),
  (1728850709866746680, 2, 'github.com/o/s1/releases/download/{v}/');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (2362466365405466888, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/o/s1/releases/download/{v}/', '1.1.0', '6KthfyCARZeQsDFxg2em4FzWS78pHznvTtNDNWLfiyp', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 1728850709866746680, -9223090557583032321, '', 2362466365405466888, 6917856169256204455, 'https://github.com/o/s1/releases/download/1.1.0/6KthfyCARZeQsDFxg2em4FzWS78pHznvTtNDNWLfiyp.tar.zst', '1.1.0', NULL, 1700000000001, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (6917856169256204455, 1323, 2000, 0, NULL, 1699999000000, 1699999000000);
