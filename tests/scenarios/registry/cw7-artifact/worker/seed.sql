-- Made by worker/tests/tools/mk-l3w-seed.mjs (slice 224). Do not edit by hand: change the spec and make it again.
INSERT INTO names (id, kind, value) VALUES
  (6711355376540921208, 1, X'25db8179f8dbd1a4e8739feb9761cd3c7f66f65d0cc64f06633414dd0573e777'),
  (8865122489332289851, 2, 'github.com/pad/p1/releases/download/{v}/'),
  (57987218243483266, 3, 'pad/p1'),
  (1652830169315387557, 1, X'94a6730db13e381f22cde21c13a5274955ada7a23c6224f04c77766cc4dfb7e9'),
  (3851497233062284293, 2, 'github.com/pad/p2/releases/download/{v}/'),
  (-925109251146031142, 3, 'pad/p2'),
  (6637059302034951433, 1, X'2222222222222222222222222222222222222222222222222222222222222222'),
  (-8273415923550857927, 2, 'github.com/acme/json/releases/download/{v}/'),
  (-4825025842431960071, 3, 'acme/json');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (6711355376540921208, 1, '[]', NULL, NULL, 1000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/pad/p1/releases/download/{v}/', '1.0.0', '3YnDaRFjJ6px2w57yFHwnWDw4cBocmSfE3uRAgVHFgcW', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 8865122489332289851, -9223090561877999617, '', 6711355376540921208, 57987218243483266, 'https://github.com/pad/p1/releases/download/1.0.0/3YnDaRFjJ6px2w57yFHwnWDw4cBocmSfE3uRAgVHFgcW.tar.zst', '1.0.0', NULL, 1785585600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1792062000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1652830169315387557, 1, '[]', NULL, NULL, 1000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'github.com/pad/p2/releases/download/{v}/', '1.0.0', 'B1GYnRhmGHFa3XAzkbqCDDCfiFJvAtF5Rkefag2ZjzVW', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, 3851497233062284293, -9223090561877999617, '', 1652830169315387557, -925109251146031142, 'https://github.com/pad/p2/releases/download/1.0.0/B1GYnRhmGHFa3XAzkbqCDDCfiFJvAtF5Rkefag2ZjzVW.tar.zst', '1.0.0', NULL, 1785585600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (2, 3, NULL, 1792062000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (6637059302034951433, 1, '["Json"]', NULL, NULL, 222);
INSERT INTO log (idx, grp, version, hash, time) VALUES (3, 'github.com/acme/json/releases/download/{v}/', '2.1.0', '3JF3sEqM796hk5WFqA6EtmEwJQ9quALszsfJyvXNQKy3', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (3, -8273415923550857927, -9222809082606321665, '', 6637059302034951433, -4825025842431960071, 'https://github.com/acme/json/releases/download/2.1.0/3JF3sEqM796hk5WFqA6EtmEwJQ9quALszsfJyvXNQKy3.tar.zst', '2.1.0', NULL, 1792065600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (3, 3, NULL, 1792062000000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (57987218243483266, 101, 9002, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (57987218243483266, NULL, 1792062000000, 1792065600000, 0, 0);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-925109251146031142, 102, 9002, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-925109251146031142, NULL, 1792062000000, 1792065600000, 0, 0);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-4825025842431960071, 1, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-4825025842431960071, NULL, 1792062000000, 1792065600000, 0, 0);
