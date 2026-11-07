-- Made by worker/tests/tools/mk-l3w-seed.mjs (slice 224). Do not edit by hand: change the spec and make it again.
INSERT INTO names (id, kind, value) VALUES
  (925780742037623613, 1, X'4db4bb55a79b063713c0db6dc1c94449ab5ebfcc1f645be163e1e2e1f281542f'),
  (4721356375230720841, 2, 'github.com/acme/pfx/releases/download/{v}/'),
  (-7458353753673059558, 3, 'acme/pfx'),
  (4469800713240684981, 1, X'a35b62ef3e987b3ba45f11878b2975dd2ef45ecc4b5a7452392cdc711dbab2d1'),
  (-7163292474072844271, 2, 'github.com/Karakatiza666/roc-semver/releases/download/{v}/'),
  (-6778217992284227538, 3, 'karakatiza666/roc-semver');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (925780742037623613, 2, '[]', NULL, NULL, 1000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/acme/pfx/releases/download/{v}/', '0.1.0', '6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL', 1793530800000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 4721356375230720841, -9223372032559742977, '', 925780742037623613, -7458353753673059558, 'https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst', '0.1.0', NULL, 1782907200000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1793530800000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (4469800713240684981, 1, '["Semver"]', NULL, NULL, 1000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'github.com/Karakatiza666/roc-semver/releases/download/{v}/', '0.2.0', 'BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i', 1793530800000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, -7163292474072844271, -9223372028264775681, '', 4469800713240684981, -6778217992284227538, 'https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst', '0.2.0', NULL, 1785585600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (2, 3, NULL, 1793530800000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-7458353753673059558, 2, 9001, 0, NULL, 1793530800000, 1793530800000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-7458353753673059558, NULL, 1793530800000, 1793534400000, 0, 0);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-6778217992284227538, 3, 9003, 0, NULL, 1793530800000, 1793530800000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-6778217992284227538, NULL, 1793530800000, 1793534400000, 0, 0);
