INSERT INTO names (id, kind, value) VALUES (261373930947811203, 3, 'acme/lib');
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (261373930947811203, 100, 10, 0, NULL, 1767000000000, 1767000000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (261373930947811203, NULL, NULL, 1767003600000, 0, 0);
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (261373930947811203, 1, 0, NULL, 100, NULL, 10, NULL, NULL, 1767000000000);
INSERT INTO names (id, kind, value) VALUES (-3091616050638104172, 1, X'42EFFDAC64BDAAAE565213D5F84460EA117B4DA35C1015E45E518527141E8FF6'), (1867293425818598420, 2, 'github.com/acme/lib/releases/download/{v}/');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-3091616050638104172, 1, '["Alpha"]', NULL, NULL, 999);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/acme/lib/releases/download/{v}/', '1.0.0', '5WJA7vhQDESe7SSuHxL9pqaSBZSNotXAefx6wEFgENeh', 1767000000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 1867293425818598420, -9223090561877999617, '', -3091616050638104172, 261373930947811203, 'https://github.com/acme/lib/releases/download/1.0.0/5WJA7vhQDESe7SSuHxL9pqaSBZSNotXAefx6wEFgENeh.tar.zst', '1.0.0', NULL, 1792497600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 1, NULL, 1767000000000);
