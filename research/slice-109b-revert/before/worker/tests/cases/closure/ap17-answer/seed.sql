-- Made by research/slice-110-revert/gen/gen_w2.py. The closure: a series bound (A2 2.0.0 is out), a dep with no version, a dep that is not indexed, a cycle (E, F), an app with its platform.
-- The compilers of R-MX16 (5 nightlies, one with 2 rows) and a nightly P with compat rows and no toolchains row. The transition row of N3 names N0, not the adjacent N2.
INSERT INTO names (id, kind, value) VALUES
  (1807398750255624514, 1, X'0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a'),
  (8502969869573817109, 1, X'1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a'),
  (6580728695008348076, 1, X'0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b'),
  (2009264365081504623, 1, X'0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c'),
  (9178290834928761901, 1, X'0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e'),
  (-8457509357986643541, 1, X'0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f'),
  (-1914621620958626863, 1, X'4747474747474747474747474747474747474747474747474747474747474747'),
  (-7992398287468051663, 1, X'6363636363636363636363636363636363636363636363636363636363636363'),
  (996414784089826786, 1, X'3131313131313131313131313131313131313131313131313131313131313131'),
  (2259660601948445915, 1, X'3232323232323232323232323232323232323232323232323232323232323232'),
  (4652512588506025103, 1, X'3333333333333333333333333333333333333333333333333333333333333333'),
  (-3692541221064081259, 2, 'github.com/o/a/releases/download/{v}/'),
  (-6243123884266634966, 2, 'github.com/o/b/releases/download/{v}/'),
  (6788748434313465012, 2, 'github.com/o/e/releases/download/{v}/'),
  (-6694716967130615478, 2, 'example.com/g/{v}/'),
  (8087440601071283561, 2, 'github.com/o/r/releases/download/{v}/'),
  (262079342519281161, 3, 'o/a'),
  (4669029856192390978, 3, 'o/b'),
  (3113970550421931234, 3, 'o/b2'),
  (7803318870520653138, 3, 'o/e'),
  (7286584460945255079, 3, 'o/r');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1807398750255624514, 1, '["A"]', NULL, NULL, 10);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (8502969869573817109, 1, '["A"]', NULL, NULL, 11);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (6580728695008348076, 1, '["B"]', NULL, 'nightly-2026-01-01-0000001', 20);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (2009264365081504623, 2, '["Pf"]', NULL, NULL, 30);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (9178290834928761901, 1, '["E"]', NULL, NULL, 50);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-8457509357986643541, 1, '[]', NULL, NULL, 60);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-1914621620958626863, 0, '[]', 2009264365081504623, NULL, 70);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (996414784089826786, 1, '[]', NULL, NULL, 1);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (2259660601948445915, 1, '[]', NULL, NULL, 1);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (4652512588506025103, 1, '[]', NULL, NULL, 1);
INSERT INTO artifact_targets (artifact, target) VALUES (2009264365081504623, 7), (2009264365081504623, 24);
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (1807398750255624514, 'b', 6580728695008348076, -6243123884266634966, -9223090561877999617, '', 'https://github.com/o/b/releases/download/1.0.0/k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn.tar.zst');
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (1807398750255624514, 'c', 2009264365081504623, NULL, NULL, NULL, 'https://example.com/c/p2Yicb86aZig616Eav2VWG9vuXR5mEqhtzshZYBxzsV.tar.zst');
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (1807398750255624514, 'x', -7992398287468051663, NULL, NULL, NULL, 'https://example.com/x/x.tar.zst');
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (9178290834928761901, 'f', -8457509357986643541, 6788748434313465012, -9223372019674841089, '', 'https://github.com/o/e/releases/download/0.4.0/21nS9Wz9sUTQ6MkcYUtnN8aSfPA26xJJP7zqshfzCzqc.tar.zst');
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (-8457509357986643541, 'e', 9178290834928761901, 6788748434313465012, -9223372023969808385, '', 'https://github.com/o/e/releases/download/0.3.0/ws91DX9HBAAxGW77BZs5FogRDwpRtcUpiLBpKdPTfWu.tar.zst');
INSERT INTO deps (artifact, alias, dep, form, version, version_text, url) VALUES (-1914621620958626863, 'pf', 2009264365081504623, NULL, NULL, NULL, 'https://example.com/c/p2Yicb86aZig616Eav2VWG9vuXR5mEqhtzshZYBxzsV.tar.zst');
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/o/a/releases/download/{v}/', '1.0.0', 'gBxS1f6uyyGPuW5MzGBukidSb71jdsCb5fZaoSzULE5', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, -3692541221064081259, -9223090561877999617, '', 1807398750255624514, 262079342519281161, 'https://github.com/o/a/releases/download/1.0.0/gBxS1f6uyyGPuW5MzGBukidSb71jdsCb5fZaoSzULE5.tar.zst', '1.0.0', '0.1', 1700000001000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'github.com/o/a/releases/download/{v}/', '2.0.0', '2ktgiq7GNkitdMWCLmUtZm4qM8UEWerKXcL4WtAaRfPP', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, -3692541221064081259, -9222809086901288961, '', 8502969869573817109, 262079342519281161, 'https://github.com/o/a/releases/download/2.0.0/2ktgiq7GNkitdMWCLmUtZm4qM8UEWerKXcL4WtAaRfPP.tar.zst', '2.0.0', NULL, 1700000002000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (3, 'github.com/o/b/releases/download/{v}/', '1.0.0', 'k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (3, -6243123884266634966, -9223090561877999617, '', 6580728695008348076, 4669029856192390978, 'https://github.com/o/b/releases/download/1.0.0/k7FaK87WHGVXzkaoHb7CdVPgkKDQhZ29VLDeBVbDfYn.tar.zst', '1.0.0', NULL, 1700000003000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (4, 'github.com/o/e/releases/download/{v}/', '0.3.0', 'ws91DX9HBAAxGW77BZs5FogRDwpRtcUpiLBpKdPTfWu', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (4, 6788748434313465012, -9223372023969808385, '', 9178290834928761901, 7803318870520653138, 'https://github.com/o/e/releases/download/0.3.0/ws91DX9HBAAxGW77BZs5FogRDwpRtcUpiLBpKdPTfWu.tar.zst', '0.3.0', NULL, 1700000004000, 0, 'deleted', 1767139200000);
INSERT INTO log (idx, grp, version, hash, time) VALUES (5, 'example.com/g/{v}/', '0.1.0', '5oEzAP4izB65uRm2yDAEf9oALGwHpWkDfyKb8zBY3euC', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (5, -6694716967130615478, -9223372032559742977, '', -1914621620958626863, NULL, 'https://example.com/g/0.1.0/5oEzAP4izB65uRm2yDAEf9oALGwHpWkDfyKb8zBY3euC.tar.zst', NULL, NULL, 1700000005000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (6, 'github.com/o/r/releases/download/{v}/', '1.2.0', '4K2V1kpVycZ6qSFsNdz2FtpNxnJs17eBNzf9rdCMcKoe', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (6, 8087440601071283561, -9223090553288065025, '', 996414784089826786, 7286584460945255079, 'https://github.com/o/r/releases/download/1.2.0/4K2V1kpVycZ6qSFsNdz2FtpNxnJs17eBNzf9rdCMcKoe.tar.zst', '1.2.0', NULL, 1700000006000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (7, 'github.com/o/r/releases/download/{v}/', '1.3.0', '4NwnA4HWZurKyXWNowJwYmb9CwX4gBKzwQKov1ExMf8M', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (7, 8087440601071283561, -9223090548993097729, '', 2259660601948445915, 7286584460945255079, 'https://github.com/o/r/releases/download/1.3.0/4NwnA4HWZurKyXWNowJwYmb9CwX4gBKzwQKov1ExMf8M.tar.zst', '1.3.0', NULL, 1700000007000, 0, NULL, NULL);
INSERT INTO log (idx, grp, version, hash, time) VALUES (8, 'github.com/o/r/releases/download/{v}/', '1.4.0', '4Ss5JMkXAD9Z7cktFEdrqeMuT6jGMF1pVozTyPHZ6zT4', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (8, 8087440601071283561, -9223090544698130433, '', 4652512588506025103, 7286584460945255079, 'https://github.com/o/r/releases/download/1.4.0/4Ss5JMkXAD9Z7cktFEdrqeMuT6jGMF1pVozTyPHZ6zT4.tar.zst', '1.4.0', NULL, 1700000008000, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (262079342519281161, 1, 2, 0, NULL, 1000, 1000), (4669029856192390978, 3, 4, 2, 3113970550421931234, 2000, 2000), (7803318870520653138, 5, 6, 0, NULL, 3000, 3000), (7286584460945255079, 7, 8, 0, NULL, 4000, 4000);
INSERT INTO repo_checks (repo, etag, checked_at, next_check_at, fail_count, app_installed) VALUES (262079342519281161, NULL, 1767222000000, 1767225600000, 0, 0);
INSERT INTO log (idx, grp, version, hash, time) VALUES (9, 'roc-lang/nightlies:linux_x86_64', 'nightly-2025-12-31-0000009', 'sha256:abababababababababababababababababababababababababababababababab', 1767139200000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (5490310381577, 'linux_x86_64', 'nightly-2025-12-31-0000009', 'roc_nightly-linux_x86_64-x.tar.gz', 'abababababababababababababababababababababababababababababababab', 5000, 9);
INSERT INTO log (idx, grp, version, hash, time) VALUES (10, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-01-01-0000002', 'sha256:abababababababababababababababababababababababababababababababab', 1767139200000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (5490578817026, 'linux_x86_64', 'nightly-2026-01-01-0000002', 'roc_nightly-linux_x86_64-x.tar.gz', 'abababababababababababababababababababababababababababababababab', 500, 10);
INSERT INTO log (idx, grp, version, hash, time) VALUES (11, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-01-01-0000003', 'sha256:abababababababababababababababababababababababababababababababab', 1767139200000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (5490578817027, 'linux_x86_64', 'nightly-2026-01-01-0000003', 'roc_nightly-linux_x86_64-x.tar.gz', 'abababababababababababababababababababababababababababababababab', 500, 11);
INSERT INTO log (idx, grp, version, hash, time) VALUES (12, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-01-01-0000001', 'sha256:abababababababababababababababababababababababababababababababab', 1767139200000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (5490578817025, 'linux_x86_64', 'nightly-2026-01-01-0000001', 'roc_nightly-linux_x86_64-x.tar.gz', 'abababababababababababababababababababababababababababababababab', 1000, 12);
INSERT INTO log (idx, grp, version, hash, time) VALUES (13, 'roc-lang/nightlies:macos_apple_silicon', 'nightly-2026-01-01-0000001', 'sha256:abababababababababababababababababababababababababababababababab', 1767139200000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (5490578817025, 'macos_apple_silicon', 'nightly-2026-01-01-0000001', 'roc_nightly-macos_apple_silicon-x.tar.gz', 'abababababababababababababababababababababababababababababababab', 1000, 13);
INSERT INTO log (idx, grp, version, hash, time) VALUES (14, 'roc-lang/nightlies:linux_x86_64', 'nightly-2026-01-02-0000004', 'sha256:abababababababababababababababababababababababababababababababab', 1767139200000);
INSERT INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (5490847252484, 'linux_x86_64', 'nightly-2026-01-02-0000004', 'roc_nightly-linux_x86_64-x.tar.gz', 'abababababababababababababababababababababababababababababababab', 100, 14);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1807398750255624514, 5490310381577, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1807398750255624514, 5490578817026, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1807398750255624514, 5490578817027, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1807398750255624514, 5490578817025, 0, 0, 1, 'd1', 1, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1807398750255624514, 5490847252484, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (1807398750255624514, 5490578817029, 0, 0, 1, 'dp', 1, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (6580728695008348076, 5490578817026, 0, 1, 0, NULL, 1, 1);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (6580728695008348076, 5490578817026, 0, 0, 2, NULL, 1, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (6580728695008348076, 5490310381577, 0, 1, 1, 'e1', 1, 1);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (6580728695008348076, 5490578817025, 0, 0, 0, NULL, 1, NULL);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (6580728695008348076, 5490847252484, 0, 1, 0, NULL, 1, 1);
INSERT INTO compat (artifact, nightly, target, source, result, error_digest, time, log_index) VALUES (6580728695008348076, 5490847252484, 0, 0, 3, NULL, 1, NULL);
INSERT INTO transitions (nightly, target, previous, compared, changed) VALUES (5490578817025, 0, 5490578817027, 2, 0), (5490578817027, 0, 5490310381577, 2, 0), (5490847252484, 0, 5490578817025, 2, 1);
INSERT INTO compat_hints (artifact, nightly, target, talon_version, pass_count, fail_count, crash_count, first_time, last_time) VALUES (1807398750255624514, 5490578817027, 0, 1, 1, 0, 0, 1, 1), (1807398750255624514, 5490578817027, 0, 2, 2, 1, 0, 1, 1), (1807398750255624514, 5490578817025, 0, 1, 0, 0, 1, 1, 1), (1807398750255624514, 5490578817029, 0, 1, 9, 0, 0, 1, 1);
