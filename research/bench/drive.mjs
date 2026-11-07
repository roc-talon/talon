#!/usr/bin/env node
// Send the scenario requests to a registry and write one JSONL line for each request (format: research/bench/README.md).
//   node research/bench/drive.mjs --base <url> --scenario <name|a,b|all> [--repeat N] [--out <file.jsonl>] [--concurrency C]
//        [--min-gap-ms N] [--timeout-ms N] [--dir <scenario dir>] [--quiet]
// Sequential by default. A status that differs from expected_status is recorded (and counted in the summary), never a crash.
// A host that is not loopback is read only: a scenario with a write request is refused (`all` skips such scenarios), and the gap between 2 request starts is at least 100 ms.
// A request that gets no answer (network fault, timeout) is a line with status 0. The driver never sends a request again.
import { createWriteStream, existsSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isLoopback, isWrite, readJsonl, sleep, summarize, table } from './lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).reduce((a, x, i, all) => (x.startsWith('--') ? [...a, [x.slice(2), x.startsWith('--quiet') ? 'true' : all[i + 1]]] : a), []));
const die = (m) => { console.error(`drive: ${m}`); process.exit(2); };
if (!args.base || !args.scenario) die('usage: drive.mjs --base <url> --scenario <name|a,b|all> [--repeat N] [--out <file.jsonl>] [--concurrency C] [--min-gap-ms N] [--timeout-ms N]');
const base = args.base.replace(/\/$/, '');
const repeat = Number(args.repeat ?? 1);
const conc = Number(args.concurrency ?? 1);
const timeoutMs = Number(args['timeout-ms'] ?? 30000);
const dir = args.dir ?? join(here, 'scenarios');
const remote = !isLoopback(base);
const gap = Math.max(Number(args['min-gap-ms'] ?? 0), remote ? 100 : 0);
if (!(repeat >= 1) || !(conc >= 1)) die('--repeat and --concurrency are whole numbers of 1 or more');

const all = existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith('.jsonl')).map((f) => f.slice(0, -6)).sort() : [];
let names = args.scenario === 'all' ? all : args.scenario.split(',');
const loaded = new Map();
for (const n of names) {
  if (!existsSync(join(dir, `${n}.jsonl`))) die(`no scenario ${n} in ${dir} (have: ${all.join(', ') || 'none: run gen-scenarios.mjs'})`);
  loaded.set(n, readJsonl(join(dir, `${n}.jsonl`)));
}
const writes = (n) => loaded.get(n).some((l) => isWrite(l.method, l.path));
if (remote) {
  const bad = names.filter(writes);
  if (args.scenario === 'all') { if (bad.length) console.error(`drive: ${new URL(base).host} is a remote host (read only): skipped ${bad.join(', ')}`); names = names.filter((n) => !writes(n)); }
  else if (bad.length) die(`refused: ${bad.join(', ')} has write requests and ${new URL(base).host} is not a loopback host`);
}
if (names.length === 0) die('no scenario to run');

// {{uniq}}: 32 lower-case hex digits, new for each sent request: the run start time (ms) in the high digits, a counter in the low 8.
const runId = BigInt(Date.now());
let counter = 0n;
const uniq = () => ((runId << 32n) | counter++).toString(16).padStart(32, '0');
const fill = (s) => (typeof s === 'string' && s.includes('{{uniq}}') ? s.replaceAll('{{uniq}}', uniq()) : s);

const out = args.out ? createWriteStream(args.out) : null;
const lines = [];
let lastStart = 0;
const pace = async () => { // the next start is at least `gap` ms after the last one (a shared turn for all workers)
  const at = Math.max(Date.now(), lastStart + gap);
  lastStart = at;
  const wait = at - Date.now();
  if (wait > 0) await sleep(wait);
};

async function send(scenario, seq, line) {
  if (remote && isWrite(line.method, line.path)) throw new Error(`refused: ${line.method} ${line.path} to a remote host`); // second guard, per request
  const headers = { 'user-agent': 'tln-bench/0', accept: 'application/json', ...Object.fromEntries(Object.entries(line.headers ?? {}).map(([k, v]) => [k.toLowerCase(), fill(v)])) };
  let body;
  if (line.json !== undefined) { body = fill(JSON.stringify(line.json)); headers['content-type'] ??= 'application/json'; }
  else if (line.body !== undefined) body = fill(line.body);
  const ts = Date.now();
  const t0 = performance.now();
  let status = 0, cfRay = null, stats = null;
  try {
    const r = await fetch(base + line.path, { method: line.method, headers, body, redirect: 'manual', signal: AbortSignal.timeout(timeoutMs) });
    await r.arrayBuffer(); // to the last byte
    status = r.status;
    cfRay = r.headers.get('cf-ray');
    stats = r.headers.get('x-roc-stats');
  } catch { /* status 0 */ }
  const client_ms = Math.round((performance.now() - t0) * 1000) / 1000;
  const colo = cfRay ? cfRay.slice(cfRay.lastIndexOf('-') + 1) : null;
  const rec = { scenario, seq, method: line.method, path: line.path, status, expected_status: line.expected_status, client_ms, cf_ray: cfRay, colo, ts, stats };
  lines.push(rec);
  out?.write(`${JSON.stringify(rec)}\n`);
}

for (const name of names) {
  const reqs = loaded.get(name);
  const total = reqs.length * repeat;
  let next = 0;
  const worker = async () => {
    for (;;) {
      const i = next++; // seq: 0 based, in the order of start, across the repeats of one scenario
      if (i >= total) return;
      await pace();
      await send(name, i, reqs[i % reqs.length]);
    }
  };
  await Promise.all(Array.from({ length: Math.min(conc, total) }, worker));
}
if (out) await new Promise((r) => out.end(r));
if (!args.quiet) {
  console.log(`base ${base}  repeat ${repeat}  concurrency ${conc}  gap ${gap} ms${args.out ? `  out ${args.out}` : ''}`);
  console.log(table(summarize(lines)));
}
