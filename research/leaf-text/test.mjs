// Q103-1 prototype: the Worker binds the leaf text, the leaf statement comes before the release,
// and an AFTER INSERT trigger on releases (and on toolchains) checks that the leaf of NEW.log_index is there.
// Run: node test.mjs   (MUTATE=agg | release-first | no-check)
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
const M = process.env.MUTATE || '';
const db = new DatabaseSync(':memory:');
const init = readFileSync(new URL('../../sql/0001_init.sql', import.meta.url), 'utf8');
db.exec(init);
db.exec(`
CREATE TRIGGER releases_label_conflict BEFORE INSERT ON releases BEGIN
  SELECT RAISE(ABORT, 'label-conflict') WHERE EXISTS (SELECT 1 FROM releases
    WHERE form = NEW.form AND version = NEW.version AND version_text = NEW.version_text AND artifact <> NEW.artifact);
END;`);
if (M !== 'no-check') db.exec(`
CREATE TRIGGER releases_leaf_check AFTER INSERT ON releases BEGIN
  SELECT RAISE(ABORT, 'leaf-missing') WHERE NOT EXISTS (SELECT 1 FROM log
    WHERE idx = NEW.log_index AND grp = (SELECT value FROM names WHERE id = NEW.form AND kind = 2));
END;
CREATE TRIGGER toolchains_leaf_check AFTER INSERT ON toolchains BEGIN
  SELECT RAISE(ABORT, 'leaf-missing') WHERE NOT EXISTS (SELECT 1 FROM log
    WHERE idx = NEW.log_index AND grp = 'roc-lang/nightlies:' || NEW.target AND version = NEW.tag AND hash = 'sha256:' || NEW.sha256);
END;`);

const leafAgg = `INSERT INTO log (idx, grp, version, hash, time)
  SELECT COALESCE(MAX(idx), 0) + 1, ?, ?, ?, ? FROM log
  WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ? AND version = ? AND version_text = ?)`;
const leafOk = `INSERT INTO log (idx, grp, version, hash, time)
  SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?, ?, ?, ?
  WHERE NOT EXISTS (SELECT 1 FROM releases WHERE form = ? AND version = ? AND version_text = ?)`;
const leaf = M === 'agg' ? leafAgg : leafOk;
const rel = `INSERT OR IGNORE INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
  VALUES ((SELECT MAX(idx) FROM log), ?, ?, ?, ?, NULL, 'u', NULL, NULL, 1, 0, NULL, NULL)`;
const relFirst = `INSERT OR IGNORE INTO releases (log_index, form, version, version_text, artifact, repo, url, tag, roc_version, published_at, yanked, withdrawn, withdrawn_at)
  VALUES ((SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?, ?, ?, ?, NULL, 'u', NULL, NULL, 1, 0, NULL, NULL)`;
const K = '-9223090561877999617';
function batch(stmts) {
  db.exec('BEGIN');
  try { for (const [s, p] of stmts) db.prepare(s).run(...p); db.exec('COMMIT'); return 'ok'; }
  catch (e) { db.exec('ROLLBACK'); return e.message; }
}
function publish(form, grp, art, hash, text = '') {
  const names = [[`INSERT INTO names (id, kind, value) VALUES (?, 2, ?) ON CONFLICT (kind, value) DO NOTHING`, [form, grp]]];
  if (M === 'release-first') return batch([...names, [relFirst, [form, K, text, art]], [leaf.replace('(SELECT COALESCE(MAX(idx), 0) + 1 FROM log)', '(SELECT COALESCE(MAX(idx), 0) + 1 FROM log)'), [grp, '1.0.0', hash, 5, form, K, text]]]);
  return batch([...names, [leaf, [grp, '1.0.0', hash, 5, form, K, text]], [rel, [form, K, text, art]]]);
}
const count = (t) => db.prepare(`SELECT COUNT(*) AS n FROM ${t}`).get().n;
let fail = 0;
function check(name, got, want) { const ok = JSON.stringify(got) === JSON.stringify(want); if (!ok) fail++; console.log(`${ok ? 'pass' : 'FAIL'} ${name}: ${JSON.stringify(got)}${ok ? '' : ' want ' + JSON.stringify(want)}`); }

check('L1 new label', [publish(1, 'g1', 11, 'h11'), count('log'), count('releases')], ['ok', 1, 1]);
check('L2 same label, same artifact', [publish(1, 'g1', 11, 'h11'), count('log'), count('releases')], ['ok', 1, 1]);
check('L3 same label, other artifact', [publish(1, 'g1', 99, 'h99'), count('log'), count('releases')], ['label-conflict', 1, 1]);
check('L4 second label', [publish(2, 'g2', 12, 'h12'), db.prepare('SELECT log_index FROM releases WHERE form = 2').get()?.log_index], ['ok', 2]);
// L5: a compiler leaf and its toolchains row
const tc = batch([
  [`INSERT INTO log (idx, grp, version, hash, time) SELECT (SELECT COALESCE(MAX(idx), 0) + 1 FROM log), ?, ?, ?, ?
    WHERE NOT EXISTS (SELECT 1 FROM toolchains WHERE nightly = ? AND target = ?)`, ['roc-lang/nightlies:linux_x86_64', 'nightly-x', 'sha256:ab', 5, 7, 'linux_x86_64']],
  [`INSERT OR IGNORE INTO toolchains (nightly, target, tag, asset_name, sha256, published_at, log_index) VALUES (?, ?, ?, 'a', ?, 1, (SELECT MAX(idx) FROM log))`, [7, 'linux_x86_64', 'nightly-x', 'ab']]]);
check('L5 compiler leaf', [tc, count('log')], ['ok', 3]);
check('L6 same label after a compiler leaf', [publish(2, 'g2', 12, 'h12'), count('log'), count('releases')], ['ok', 3, 2]);
// L7: a release with no leaf statement (a Worker bug)
check('L7 release with no leaf', [batch([[rel.replace('(SELECT MAX(idx) FROM log)', '(SELECT MAX(idx) FROM log) + 1'), [3, K, '', 13]]]), count('releases')], ['leaf-missing', 2]);
// L8: a leaf with the wrong group text
check('L8 leaf of another group', [batch([[`INSERT INTO names (id, kind, value) VALUES (3, 2, 'g3')`, []], [leaf, ['gX', '1.0.0', 'h', 5, 3, K, '']], [rel, [3, K, '', 13]]]), count('log')], ['leaf-missing', 3]);
console.log(fail ? `${fail} failed` : 'all pass');
process.exit(fail ? 1 : 0);
