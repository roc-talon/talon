// Slice 257b probe: does the local R2 of Miniflare (the W2 runner) obey the conditions of the checkpoint write (R-SG7 row 4)?
//   etagMatches with the right etag: written; with an old etag: not written (null).
//   etagDoesNotMatch "*" (R2.absent): written when the key is absent; not written when it is there.
// Usage (repo root): TMPDIR=.tmp/tmp node research/slice-257b-r2/probe-cond.mjs
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';

const mfDir = process.env.MINIFLARE ?? join(dirname(dirname(process.execPath)), 'lib/node_modules/wrangler/node_modules/miniflare');
const { Miniflare, convertV4MiniflareOptions } = createRequire(import.meta.url)(mfDir);
const script = `export default { async fetch(req, env) {
  const out = {};
  const b = env.LOG;
  out.absentNew = (await b.put('k', 'one', { onlyIf: { etagDoesNotMatch: '*' } })) !== null;
  out.absentThere = (await b.put('k', 'two', { onlyIf: { etagDoesNotMatch: '*' } })) !== null;
  const cur = await b.head('k');
  out.matchRight = (await b.put('k', 'three', { onlyIf: { etagMatches: cur.etag } })) !== null;
  out.matchOld = (await b.put('k', 'four', { onlyIf: { etagMatches: cur.etag } })) !== null;
  out.final = await (await b.get('k')).text();
  return Response.json(out);
} }`;
const v4 = { modules: true, script, r2Buckets: ['LOG'], compatibilityDate: '2026-10-01' };
const mf = new Miniflare(convertV4MiniflareOptions ? convertV4MiniflareOptions(v4) : v4);
const res = await mf.dispatchFetch('http://localhost/');
const got = await res.json();
await mf.dispose();
const want = { absentNew: true, absentThere: false, matchRight: true, matchOld: false, final: 'three' };
console.log(JSON.stringify(got));
console.log(JSON.stringify(got) === JSON.stringify(want) ? 'ok: Miniflare R2 obeys etagMatches and etagDoesNotMatch "*"' : 'DIFFERENT from the edge rules');
