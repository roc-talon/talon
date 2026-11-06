-- One compiler leaf and its toolchains row (log 1), one release and its leaf (log 2), one nightly, and the day 20000 at the limit (counted 200000).
INSERT INTO names (id, kind, value) VALUES (1, 2, 'g1'), (7, 2, 'a');
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'roc-lang/nightlies:linux_x86_64', 't1', 'sha256:s', 1000), (2, 'g1', '1.0.0', 'H1', 1000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1, 1, '[]', NULL, NULL, 1);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (1, 'linux_x86_64', 't1', 'a', 's', 1000, 1);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
VALUES (2, 1, -9223090561877999617, '', 1, NULL, 'u', NULL, NULL, 1000, 0, NULL, NULL);
INSERT INTO hint_days (day, counted) VALUES (20000, 200000);
