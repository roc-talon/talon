// Test entry (registry plan W2 proposal): wrap env.DB so each D1 call (prepare().all/run/first/raw, batch, exec,
// withSession) adds a line to a count that GET /__d1count gives. Not for production.
import app from './app.wasm';
import { makeHandler } from './.roc-cfw/index.js';

const inner = makeHandler(app);
let calls = [];
const wrapStmt = (s) => new Proxy(s, { get(t, k) {
  const v = t[k];
  if (k === 'bind') return (...a) => wrapStmt(v.apply(t, a));
  if (['all', 'run', 'first', 'raw'].includes(k)) return (...a) => { calls.push(k); return v.apply(t, a); };
  return typeof v === 'function' ? v.bind(t) : v;
} });
const wrapDb = (db) => new Proxy(db, { get(t, k) {
  const v = t[k];
  if (k === 'prepare') return (...a) => wrapStmt(v.apply(t, a));
  if (k === 'batch' || k === 'exec') return (...a) => { calls.push(k); return v.apply(t, a); };
  if (k === 'withSession') return (...a) => wrapDb(v.apply(t, a));
  return typeof v === 'function' ? v.bind(t) : v;
} });
// makeHandler gives a WorkerEntrypoint class that reads this.env, so a subclass swaps env.DB.
export default class Counted extends inner {
  constructor(ctx, env) { super(ctx, { ...env, DB: wrapDb(env.DB) }); }
  async fetch(req) {
    if (new URL(req.url).pathname === '/__d1count') { const r = JSON.stringify(calls); calls = []; return new Response(r); }
    return super.fetch(req);
  }
}
