// Q49: the target Worker. Deployed 2 times (rocplat-test-q49-default, rocplat-test-q49-smart) with one D1 database.
// Routes (GET):
//   /setup            schema and seed: 50 groups x 20 versions = 1,000 releases. Group g (g % 5 != 4) depends on g + 1.
//   /closure          closure-like read: 1 batch (closure CTE of groups 0 and 5: 200 release rows, then log_size)
//   /chain3           3 dependent calls: log_size, then the releases of one group, then their deps
//   /publish          publish-like write: 1 read call (label check), then 1 write batch (R-AP41: at most 2 calls)
//   /closure_s, /chain3_s   the same reads in a session: withSession('first-unconstrained') (read replicas)
//   /where            no D1: the colo of the Worker, from a fetch of /cdn-cgi/trace
// Each answer: the ingress colo (request.cf.colo), the time of the D1 calls in the Worker (the clock moves at I/O), the rows,
// and where D1 served the call (meta.served_by_region, meta.served_by_primary).
const CLOSURE = `WITH RECURSIVE
  roots(a) AS (SELECT artifact FROM releases WHERE grp IN (SELECT value FROM json_each(?1))),
  clo(a) AS (SELECT a FROM roots UNION SELECT d.dep FROM deps d JOIN clo ON d.artifact = clo.a)
SELECT r.log_index, r.grp, r.version, r.artifact FROM releases r WHERE r.artifact IN (SELECT a FROM clo)
ORDER BY r.log_index LIMIT 200`;
const LOG_SIZE = 'SELECT v AS log_size FROM meta WHERE k = 1';

const SETUP = [
  'CREATE TABLE IF NOT EXISTS releases (log_index INTEGER PRIMARY KEY, grp INTEGER NOT NULL, version INTEGER NOT NULL, artifact INTEGER NOT NULL, UNIQUE (grp, version)) STRICT',
  'CREATE INDEX IF NOT EXISTS releases_artifact ON releases (artifact)',
  'CREATE TABLE IF NOT EXISTS deps (artifact INTEGER NOT NULL, dep INTEGER NOT NULL, PRIMARY KEY (artifact, dep)) STRICT, WITHOUT ROWID',
  'CREATE TABLE IF NOT EXISTS meta (k INTEGER PRIMARY KEY, v INTEGER NOT NULL) STRICT',
  `INSERT OR IGNORE INTO releases (log_index, grp, version, artifact)
     WITH RECURSIVE i(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM i WHERE x < 1000)
     SELECT x, (x - 1) / 20, (x - 1) % 20, x FROM i`,
  `INSERT OR IGNORE INTO deps (artifact, dep) SELECT artifact, artifact + 20 FROM releases WHERE grp < 50 AND grp % 5 != 4`,
  'INSERT OR IGNORE INTO meta (k, v) VALUES (1, 1000)',
];

const served = (r) => ({ region: r.meta?.served_by_region ?? null, primary: r.meta?.served_by_primary ?? null, colo: r.meta?.served_by_colo ?? null });

const ROUTES = {
  async closure(db) {
    const [rel, size] = await db.batch([db.prepare(CLOSURE).bind(JSON.stringify([0, 5])), db.prepare(LOG_SIZE)]);
    return { calls: 1, rows: rel.results.length, log_size: size.results[0]?.log_size, rows_read: rel.meta.rows_read + size.meta.rows_read, served: [served(rel)] };
  },
  async chain3(db) {
    const a = await db.prepare(LOG_SIZE).run();
    const n = a.results[0].log_size;
    const b = await db.prepare('SELECT artifact FROM releases WHERE grp = ? AND log_index <= ?').bind(3, n).run();
    const c = await db.prepare('SELECT dep FROM deps WHERE artifact IN (SELECT value FROM json_each(?))')
      .bind(JSON.stringify(b.results.map((r) => r.artifact))).run();
    return { calls: 3, rows: c.results.length, served: [a, b, c].map(served) };
  },
  async publish(db) {
    // A new group above the seed, so the reads of /closure do not change.
    const grp = 100000 + Math.floor(Math.random() * 1e9);
    const pre = await db.prepare('SELECT log_index FROM releases WHERE grp = ? AND version = ?').bind(grp, 0).run();
    if (pre.results.length) return { calls: 1, conflict: true };
    const [, , , ans] = await db.batch([
      db.prepare(`INSERT INTO releases (log_index, grp, version, artifact)
                  VALUES ((SELECT max(log_index) + 1 FROM releases), ?1, 0, (SELECT max(log_index) + 1 FROM releases))`).bind(grp),
      db.prepare('INSERT INTO deps (artifact, dep) VALUES ((SELECT max(log_index) FROM releases), 1)'),
      db.prepare('UPDATE meta SET v = v + 1 WHERE k = 1'),
      db.prepare('SELECT log_index FROM releases WHERE grp = ?').bind(grp),
    ]);
    return { calls: 2, rows: ans.results.length, served: [served(pre), served(ans)] };
  },
  closure_s: (db) => ROUTES.closure(db.withSession('first-unconstrained')),
  chain3_s: (db) => ROUTES.chain3(db.withSession('first-unconstrained')),
};

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const route = url.pathname.slice(1);
    const base = { worker: env.PLACEMENT, route, colo: req.cf?.colo ?? null };
    if (route === 'setup') {
      for (const s of SETUP) await env.DB.prepare(s).run();
      const n = await env.DB.prepare('SELECT count(*) AS n FROM releases').first('n');
      const c = await ROUTES.closure(env.DB);
      return Response.json({ ...base, releases: n, closure_rows: c.rows });
    }
    if (route === 'where') {
      const t = await (await fetch('https://www.cloudflare.com/cdn-cgi/trace')).text();
      return Response.json({ ...base, trace_colo: /colo=(\w+)/.exec(t)?.[1] ?? null });
    }
    const f = ROUTES[route];
    if (!f) return Response.json({ ...base, routes: Object.keys(ROUTES) }, { status: 404 });
    const t0 = Date.now();
    try {
      const out = await f(env.DB);
      return Response.json({ ...base, d1_ms: Date.now() - t0, ...out });
    } catch (e) {
      return Response.json({ ...base, d1_ms: Date.now() - t0, error: String(e?.message ?? e) }, { status: 500 });
    }
  },
};
