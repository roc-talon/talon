// Shared helpers of the registry bench (research/bench/README.md): the line format, the summary table, the CSV rows.
import { readFileSync } from 'node:fs';

// Hosts that may get write requests: loopback, and the bench deployment (worker/wrangler.bench.toml). Any other host is a remote registry: read only.
export const BENCH_HOST = 'talon-registry-bench.bellup.workers.dev';
export const isLoopback = (base) => {
  const h = new URL(base).hostname.replace(/^\[|\]$/g, '');
  return h === 'localhost' || h === '127.0.0.1' || h === '::1' || h === '0.0.0.0' || h.endsWith('.localhost') || h === BENCH_HOST;
};
// A write changes state. POST /v1/closure is a query with a body (R-AP3, R-AP20): it is not a write.
export const isWrite = (method, path = '') => !(['GET', 'HEAD'].includes(String(method).toUpperCase()) || (String(method).toUpperCase() === 'POST' && /^\/v1\/closure(\?|$)/.test(path)));

export const readJsonl = (file) => readFileSync(file, 'utf8').split('\n').filter((l) => l.trim() !== '').map((l, i) => {
  try { return JSON.parse(l); } catch (e) { throw new Error(`${file}:${i + 1}: not JSON: ${e.message}`); }
});

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Nearest-rank percentile of an ascending array.
export const pct = (sorted, p) => (sorted.length === 0 ? NaN : sorted[Math.max(0, Math.ceil((p / 100) * sorted.length) - 1)]);

// One row for each scenario, in the order of first appearance: count, mismatches, status codes, p50, p90, max of client_ms.
export function summarize(lines) {
  const by = new Map();
  for (const l of lines) {
    if (!by.has(l.scenario)) by.set(l.scenario, []);
    by.get(l.scenario).push(l);
  }
  return [...by].map(([scenario, ls]) => {
    const ms = ls.map((l) => l.client_ms).sort((a, b) => a - b);
    const codes = {};
    for (const l of ls) codes[l.status] = (codes[l.status] ?? 0) + 1;
    return {
      scenario,
      count: ls.length,
      mismatches: ls.filter((l) => l.status !== l.expected_status).length,
      codes: Object.entries(codes).sort(([a], [b]) => a - b).map(([c, n]) => `${c}x${n}`).join(' '),
      p50: pct(ms, 50),
      p90: pct(ms, 90),
      max: ms.length ? ms[ms.length - 1] : NaN,
    };
  });
}

const f1 = (x) => (Number.isFinite(x) ? x.toFixed(1) : '-');
export function table(rows) {
  const head = ['scenario', 'count', 'mismatch', 'p50 ms', 'p90 ms', 'max ms', 'status codes'];
  const body = rows.map((r) => [r.scenario, String(r.count), String(r.mismatches), f1(r.p50), f1(r.p90), f1(r.max), r.codes]);
  const w = head.map((h, i) => Math.max(h.length, ...body.map((b) => b[i].length)));
  const fmt = (cells) => cells.map((c, i) => (i === 0 || i === 6 ? c.padEnd(w[i]) : c.padStart(w[i]))).join('  ').trimEnd();
  return [fmt(head), fmt(w.map((n) => '-'.repeat(n))), ...body.map(fmt)].join('\n');
}

export const csv = (rows) => ['scenario,count,mismatches,p50_ms,p90_ms,max_ms,status_codes',
  ...rows.map((r) => [r.scenario, r.count, r.mismatches, f1(r.p50), f1(r.p90), f1(r.max), `"${r.codes}"`].join(','))].join('\n') + '\n';
