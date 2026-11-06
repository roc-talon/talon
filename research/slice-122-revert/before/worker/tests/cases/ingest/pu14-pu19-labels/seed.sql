INSERT INTO names (id, kind, value) VALUES (-2132199083618042159, 1, X'E936998F06017C640D2A6BAE70E058188621A8856221E1719FCDD9AFC2395FC3'), (1867293425818598420, 2, 'github.com/acme/lib/releases/download/{v}/'), (261373930947811203, 3, 'acme/lib');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-2132199083618042159, 1, '["Zeta","Alpha"]', NULL, NULL, 999);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/acme/lib/releases/download/{v}/', '1.0.0', 'GhNHMVJY6R442LVRqYF74FHPi7uW1AzN8WX36DuhYCuQ', 1767000000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 1867293425818598420, -9223090561877999617, '', -2132199083618042159, 261373930947811203, 'https://github.com/acme/lib/releases/download/1.0.0/GhNHMVJY6R442LVRqYF74FHPi7uW1AzN8WX36DuhYCuQ.tar.zst', '1.0.0', NULL, 1792497600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 1, NULL, 1767000000000);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (261373930947811203, 900, 9100, 0, NULL, 1767000000000, 1767000000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (261373930947811203, NULL, NULL, 1767003600000, 0, 1);
