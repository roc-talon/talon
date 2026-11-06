INSERT INTO names (id, kind, value) VALUES (-1248511669754774019, 3, 'taken/repo');
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-1248511669754774019, 4001, 41, 0, NULL, 1767000000000, 1767000000000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (-1248511669754774019, NULL, NULL, 1767003600000, 0, 0);
INSERT INTO repo_events (repo, seq, action, repository_id_before, repository_id_after, owner_id_before, owner_id_after, successor, claims, time) VALUES (-1248511669754774019, 1, 0, NULL, 4001, NULL, 41, NULL, NULL, 1767000000000);
INSERT INTO names (id, kind, value) VALUES (6701826065053429959, 1, X'0D03EA25F1B1D47E24AE0AAF3D4FD94C079449D85F40F629C3F95B09F7D2ED4A'), (564377156519933668, 2, 'github.com/taken/repo/releases/download/{v}/');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (6701826065053429959, 1, '["Alpha"]', NULL, NULL, 999);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/taken/repo/releases/download/{v}/', '1.0.0', 'somD3JV5MwWc6UKY7Xzrrp7fcdgUrqdAsB9ndsowg4H', 1767000000000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 564377156519933668, -9223090561877999617, '', 6701826065053429959, -1248511669754774019, 'https://github.com/taken/repo/releases/download/1.0.0/somD3JV5MwWc6UKY7Xzrrp7fcdgUrqdAsB9ndsowg4H.tar.zst', '1.0.0', NULL, 1792497600000, 0, NULL, NULL);
INSERT INTO provenance (release, via, claims, time) VALUES (1, 1, NULL, 1767000000000);
