-- Made by worker/tests/tools/mk-l3w-seed.mjs (slice 224). Do not edit by hand: change the spec and make it again.
INSERT INTO names (id, kind, value) VALUES
  (-2787512950907822140, 1, X'369befbdb4131bb3b399fa7b648dfb2eb18beede097d9c1ae41d2355b5057dba'),
  (-8273415923550857927, 2, 'github.com/acme/json/releases/download/{v}/'),
  (-4825025842431960071, 3, 'acme/json');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-2787512950907822140, 1, '["Json"]', NULL, NULL, 1000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/acme/json/releases/download/{v}/', '2.1.0', '4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, -8273415923550857927, -9222809082606321665, '', -2787512950907822140, -4825025842431960071, 'https://github.com/acme/json/releases/download/2.1.0/4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq.tar.zst', '2.1.0', NULL, 1790251200000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1792062000000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-4825025842431960071, 1, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-4825025842431960071, NULL, 1792062000000, 1792065600000, 0, 0);
-- The compiler of the hint (nightly-2026-10-14-38a3029) is a recorded toolchain at log index 2: the leaf is the log row (toolchains_leaf_check). nightly = days * 2^28 + sha7 (R-IK4).
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-10-14-38a3029', 'sha256:3e4ebcdac764d6259eb45a22f647754c94d15d36f0a04ede0cdd83f0ca28a703', 1792062000000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, size, published_at, log_index) VALUES (5567410745385, 'linux_x86_64', 'nightly-2026-10-14-38a3029', 'roc_nightly-linux_x86_64-2026-10-14-38a3029.tar.gz', '3e4ebcdac764d6259eb45a22f647754c94d15d36f0a04ede0cdd83f0ca28a703', 1010, 1791676800000, 2);
