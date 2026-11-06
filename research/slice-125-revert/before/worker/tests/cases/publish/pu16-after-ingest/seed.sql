INSERT INTO names (id, kind, value) VALUES (261373930947811203, 3, 'acme/lib');
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (261373930947811203, 900, 9100, 0, NULL, 1767000000000, 1767000000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (261373930947811203, NULL, NULL, 1767003600000, 0, 0);
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (261373930947811203, 1, 0, NULL, 900, NULL, 9100, NULL, NULL, 1767000000000);
INSERT INTO names (id, kind, value) VALUES (6019566045123923087, 1, X'27BB9B7FC8E61102606C617D5E55E352ECE3F891B8B2C4F9E4CFDB4D7675A4A7'), (1867293425818598420, 2, 'github.com/acme/lib/releases/download/{v}/');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (6019566045123923087, 1, '["Alpha"]', NULL, NULL, 999);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/acme/lib/releases/download/{v}/', '1.0.0', '3g6pdQ6Y66osX1c5BJXrWnGNJWpqTrXCLT3cSfANdbdg', 1767000000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 1867293425818598420, -9223090561877999617, '', 6019566045123923087, 261373930947811203, 'https://github.com/acme/lib/releases/download/1.0.0/3g6pdQ6Y66osX1c5BJXrWnGNJWpqTrXCLT3cSfANdbdg.tar.zst', '1.0.0', NULL, 1792497600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 3, NULL, 1767000000000);
