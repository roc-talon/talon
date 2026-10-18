// Q47: does one D1 batch of N statements count as 1 query or N toward the limit of D1 queries for each invocation?
// Each case runs in its own invocation: GET /?case=<name>. The answer is JSON: the calls that passed, the first error.
// The cron handler runs the loop cases too and logs them (read with `wrangler tail`).
const CASES = {
  // (a) single queries until the first error (at most 1,100)
  singles: (db) => loop(1100, (i) => db.prepare('SELECT ? AS i').bind(i).run(), 1),
  // (a) and (d) with all calls at the same time (for the cron, which has a short wall time)
  singlesPar: (db) => par(1100, (i) => db.prepare('SELECT ? AS i').bind(i).run()),
  batchesPar: (db) => par(1100, () => db.batch(sel(db, 20))),
  // (b) (c) one batch of N statements, read only
  batch60: (db) => once(() => db.batch(sel(db, 60)), 60),
  batch200: (db) => once(() => db.batch(sel(db, 200)), 200),
  batch1000: (db) => once(() => db.batch(sel(db, 1000)), 1000),
  batch5000: (db) => once(() => db.batch(sel(db, 5000)), 5000),
  // one batch of 200 writes (a row each), then the table is emptied in the same batch
  write200: (db) => once(() => db.batch([...ins(db, 200), db.prepare('DELETE FROM t')]), 201),
  // (d) batches of 20 statements until the first error: the total passes 50 at the 3rd batch
  batches20: (db) => loop(1100, () => db.batch(sel(db, 20)), 20),
  // 40 single queries, then one batch of 20: 60 statements, 41 calls
  mixed: async (db) => {
    const a = await loop(40, (i) => db.prepare('SELECT ? AS i').bind(i).run(), 1);
    const b = await once(() => db.batch(sel(db, 20)), 20);
    return { singles: a, batch: b };
  },
  // exec() with 60 statements in one string
  exec60: (db) => once(() => db.exec(Array.from({ length: 60 }, (_, i) => `SELECT ${i}`).join(';\n')), 60),
  // fetch subrequests until the first error: do they have their own limit (Free plan: 50)?
  fetches: () => loop(120, () => fetch('https://www.cloudflare.com/cdn-cgi/trace').then((r) => r.text()), 1),
  // 30 D1 queries, then fetches: one shared count, or 2 counts?
  d1ThenFetch: async (db) => {
    const a = await loop(30, (i) => db.prepare('SELECT ? AS i').bind(i).run(), 1);
    const b = await loop(60, () => fetch('https://www.cloudflare.com/cdn-cgi/trace').then((r) => r.text()), 1);
    return { d1: a, fetch: b };
  },
};

const sel = (db, n) => Array.from({ length: n }, (_, i) => db.prepare('SELECT ? AS i').bind(i));
const ins = (db, n) => Array.from({ length: n }, (_, i) => db.prepare('INSERT INTO t (v) VALUES (?)').bind(i));
const msg = (e) => String(e?.message ?? e) + (e?.cause ? ` (cause: ${e.cause?.message ?? e.cause})` : '');

// Runs f(i) up to n times, one after the other. Counts the calls that passed and the statements they had.
async function loop(n, f, perCall) {
  const t0 = Date.now();
  for (let i = 0; i < n; i++) {
    try { await f(i); } catch (e) {
      return { calls_ok: i, statements_ok: i * perCall, error_at_call: i + 1, error: msg(e), ms: Date.now() - t0 };
    }
  }
  return { calls_ok: n, statements_ok: n * perCall, error: null, ms: Date.now() - t0 };
}

// Starts n calls at the same time. Counts the calls that passed, and gives the distinct error texts.
async function par(n, f) {
  const t0 = Date.now();
  const r = await Promise.allSettled(Array.from({ length: n }, (_, i) => f(i)));
  const bad = r.filter((x) => x.status === 'rejected');
  return { calls: n, calls_ok: n - bad.length, errors: [...new Set(bad.map((x) => msg(x.reason)))], ms: Date.now() - t0 };
}

async function once(f, statements) {
  const t0 = Date.now();
  try {
    const r = await f();
    return { ok: true, statements, results: Array.isArray(r) ? r.length : r?.count, ms: Date.now() - t0 };
  } catch (e) {
    return { ok: false, statements, error: msg(e), ms: Date.now() - t0 };
  }
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const name = url.searchParams.get('case');
    if (name === 'setup') {
      await env.DB.prepare('CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY, v INTEGER)').run();
      await env.DB.prepare('CREATE TABLE IF NOT EXISTS log (id INTEGER PRIMARY KEY, body TEXT)').run();
      return Response.json({ ok: true });
    }
    // The cron reports here: its own D1 count can be used up, but a fetch has its own count.
    if (url.pathname === '/log' && req.method === 'POST') {
      await env.DB.prepare('INSERT INTO log (body) VALUES (?)').bind(await req.text()).run();
      return Response.json({ ok: true });
    }
    if (name === 'logs') return Response.json((await env.DB.prepare('SELECT body FROM log ORDER BY id').all()).results.map((r) => JSON.parse(r.body)));
    const c = CASES[name];
    if (!c) return Response.json({ cases: Object.keys(CASES) }, { status: 404 });
    const out = await c(env.DB);
    return Response.json({ case: name, colo: req.cf?.colo, out });
  },
  // One case for each run (the count is for each invocation, so 2 cases in one run would share it).
  async scheduled(ev, env) {
    const name = ['singlesPar', 'batchesPar', 'batch1000'][new Date(ev.scheduledTime).getUTCMinutes() % 3];
    const out = await CASES[name](env.DB);
    const body = JSON.stringify({ cron: ev.cron, at: new Date(ev.scheduledTime).toISOString(), case: name, out });
    console.log(body);
    await fetch('https://rocplat-test-q47.bellup.workers.dev/log', { method: 'POST', body });
  },
};
