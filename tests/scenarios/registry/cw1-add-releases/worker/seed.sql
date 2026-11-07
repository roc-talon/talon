-- Made by worker/tests/tools/mk-l3w-seed.mjs (slice 224). Do not edit by hand: change the spec and make it again.
INSERT INTO names (id, kind, value) VALUES
  (1832954897013332689, 1, X'ebf60a543db374acf202c977b30d367c40e0bce8cbe68845930271130172aadd'),
  (1867293425818598420, 2, 'github.com/acme/lib/releases/download/{v}/'),
  (261373930947811203, 3, 'acme/lib'),
  (925780742037623613, 1, X'4db4bb55a79b063713c0db6dc1c94449ab5ebfcc1f645be163e1e2e1f281542f'),
  (4721356375230720841, 2, 'github.com/acme/pfx/releases/download/{v}/'),
  (-7458353753673059558, 3, 'acme/pfx');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1832954897013332689, 1, '["Lib"]', NULL, NULL, 1000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/acme/lib/releases/download/{v}/', '1.0.0', 'Gt6QgYBLhpiVZhWCzVSujEvg9njznzjZKjEMpZTLbCEY', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 1867293425818598420, -9223090561877999617, '', 1832954897013332689, 261373930947811203, 'https://github.com/acme/lib/releases/download/1.0.0/Gt6QgYBLhpiVZhWCzVSujEvg9njznzjZKjEMpZTLbCEY.tar.zst', '1.0.0', NULL, 1780315200000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1792062000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (925780742037623613, 2, '[]', NULL, NULL, 1000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'github.com/acme/pfx/releases/download/{v}/', '0.1.0', '6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL', 1792062000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, 4721356375230720841, -9223372032559742977, '', 925780742037623613, -7458353753673059558, 'https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst', '0.1.0', NULL, 1782907200000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (2, 3, NULL, 1792062000000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (261373930947811203, 1, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (261373930947811203, NULL, 1792062000000, 1792065600000, 0, 0);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-7458353753673059558, 2, 9001, 0, NULL, 1792062000000, 1792062000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-7458353753673059558, NULL, 1792062000000, 1792065600000, 0, 0);
