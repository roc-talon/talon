INSERT OR IGNORE INTO names (id, kind, value) VALUES
  (3202109884675247741, 3, 'lukewilliamboswell/roc-parser'),
  (4667256997483383312, 1, X'33ce38660209e4674de066eb165c51923e33860e0503bdb0542ca318ed750ae5'),
  (5337398488673146182, 2, 'github.com/lukewilliamboswell/roc-parser/releases/download/{v}/'),
  (8387972377103720004, 1, X'2fcd8cda490074a3a8d250c4cb433d808f7e8881b365b5f46bfd2887dde23f2f'),
  (-4748223885894794257, 3, 'lukewilliamboswell/roc-json'),
  (1863340736893885967, 1, X'59d6a31f861191bc19aecb9378f71aba067bd21e1e916661ec782ad60a63db13'),
  (-7629332208935722698, 2, 'github.com/lukewilliamboswell/roc-json/releases/download/{v}/');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (4667256997483383312, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (1, 'github.com/lukewilliamboswell/roc-parser/releases/download/{v}/', '1.1.0', '4VEB9GJFFPrJs8h8jiVmV5AFZZudyU4mxEwAPFNMJhSL', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (1, 5337398488673146182, -9223090557583032321, '', 4667256997483383312, 3202109884675247741, 'https://github.com/lukewilliamboswell/roc-parser/releases/download/1.1.0/4VEB9GJFFPrJs8h8jiVmV5AFZZudyU4mxEwAPFNMJhSL.tar.zst', '1.1.0', NULL, 1700000000001, 0, NULL, NULL);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (8387972377103720004, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (2, 'github.com/lukewilliamboswell/roc-parser/releases/download/{v}/', '1.2.0', '4DbxBe83tQS9eWEURfSatpVnoLnTH7rAi4nvQtPV1fYJ', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (2, 5337398488673146182, -9223090553288065025, '', 8387972377103720004, 3202109884675247741, 'https://github.com/lukewilliamboswell/roc-parser/releases/download/1.2.0/4DbxBe83tQS9eWEURfSatpVnoLnTH7rAi4nvQtPV1fYJ.tar.zst', '1.2.0', NULL, 1700000000002, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (3202109884675247741, 4015, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (1863340736893885967, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (3, 'github.com/lukewilliamboswell/roc-json/releases/download/{v}/', '1.3.0', '73h7TWVFr4i27fz37Wz5jPAZKnEYJs5YLrtxFrH5vE7U', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (3, -7629332208935722698, -9223090548993097729, '', 1863340736893885967, -4748223885894794257, 'https://github.com/lukewilliamboswell/roc-json/releases/download/1.3.0/73h7TWVFr4i27fz37Wz5jPAZKnEYJs5YLrtxFrH5vE7U.tar.zst', '1.3.0', NULL, 1700000000003, 0, NULL, NULL);
INSERT INTO repos (repo, repository_id, repository_owner_id, state, successor, state_at, time) VALUES (-4748223885894794257, 3804, 2000, 0, NULL, 1699999000000, 1699999000000);
INSERT OR IGNORE INTO names (id, kind, value) VALUES
  (-5404107198656989222, 3, '_x'),
  (-8951093441772107973, 1, X'5fbc7c7bae52056a64708bf9584ec7fe996ec468526630630b841ee4a4ff2fa5'),
  (-149272421779607608, 2, 'example.com/parser/{v}/'),
  (-3618795184716875458, 1, X'2a8e022a73eea3f21cfde09930c7bf0c1de2b44c8f70874ff9ceea92baae10b1'),
  (-763965403626801463, 2, 'gitlab.com/x/parser/{v}/');
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-8951093441772107973, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (4, 'example.com/parser/{v}/', '1.4.0', '7SiRupGMNagjLFf8oGuoAinsZkdpvxVoFm1RcF61Fzi8', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (4, -149272421779607608, -9223090544698130433, '', -8951093441772107973, NULL, 'https://example.com/parser/1.4.0/7SiRupGMNagjLFf8oGuoAinsZkdpvxVoFm1RcF61Fzi8.tar.zst', '1.4.0', NULL, 1700000000004, 0, NULL, NULL);
INSERT INTO artifacts (artifact, kind, exposes, platform, roc_pin, size) VALUES (-3618795184716875458, 1, '["M"]', NULL, NULL, 100);
INSERT INTO log (idx, grp, version, hash, time) VALUES (5, 'gitlab.com/x/parser/{v}/', '1.5.0', '3s7iYfKBVSm49h4bYFqRXLZM6FKsMPUEee7GkbbkiNwi', 1767139200000);
INSERT INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at) VALUES (5, -763965403626801463, -9223090540403163137, '', -3618795184716875458, NULL, 'https://gitlab.com/x/parser/1.5.0/3s7iYfKBVSm49h4bYFqRXLZM6FKsMPUEee7GkbbkiNwi.tar.zst', '1.5.0', NULL, 1700000000005, 0, NULL, NULL);
