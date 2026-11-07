// Ingest the hash-named release assets of the roc-awesome list into the registry.
// Usage: node ingest.mjs   (re-runnable; a second run gives 200s)
import { execFileSync } from 'node:child_process';
import { writeFileSync, readFileSync, existsSync } from 'node:fs';

const REG = 'https://registry.roc-talon.org/v1/releases';
const HASH = /^[1-9A-HJ-NP-Za-km-z]{43,44}\.tar\.(zst|br|gz)$/;
const here = new URL('.', import.meta.url).pathname;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const gh = (args) => {
  for (let i = 0; ; i++) {
    try { return execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 1 << 28, stdio: ['ignore', 'pipe', 'pipe'] }); }
    catch (e) { if (i >= 2 || /HTTP 404/.test(String(e.stderr))) { console.error('gh failed:', args[1], String(e.stderr).slice(0, 200)); throw e; } Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 3000); }
  }
};

const sha = JSON.parse(gh(['api', 'repos/lukewilliamboswell/roc-awesome/commits/HEAD']));
const readme = gh(['api', 'repos/lukewilliamboswell/roc-awesome/contents/README.md', '-H', 'Accept: application/vnd.github.raw']);

// repos by section; github.io pages are mapped to owner/repo
const repos = []; const skipped = []; let kind = '';
for (const line of readme.split('\n')) {
  const h = line.match(/^## (.*)/); if (h) { kind = h[1]; continue; }
  const m = line.match(/^- (?:\S+ )?\[([^\]]+)\]\((https?:\/\/[^)]+)\)/); if (!m || !/Packages|Platforms|Tools|Applications/.test(kind)) continue;
  let u = m[2], r;
  if ((r = u.match(/^https:\/\/github\.com\/([^/]+)\/([^/#]+)/))) repos.push({ repo: `${r[1]}/${r[2]}`, kind });
  else if ((r = u.match(/^https:\/\/([^.]+)\.github\.io\/([^/]+)/))) repos.push({ repo: `${r[1]}/${r[2]}`, kind });
  else skipped.push({ repo: m[1], url: u, kind });
}

// resume: keep finished lines of an earlier partial run (set FRESH=1 to start over)
const prior = (existsSync(here + 'ingest.jsonl') && !process.env.FRESH) ? readFileSync(here + 'ingest.jsonl', 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)).filter((j) => j.status < 500) : [];
const done = new Set(prior.map((j) => j.url));
const rows = []; const noAsset = []; const perRepo = new Map(); const jsonl = prior.map((j) => JSON.stringify(j));
let n5xx = 0, total = 0;
async function post(url) {
  const t = Date.now();
  let res, body, retryAfter = 30;
  try { res = await fetch(REG, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ url, compat: null }) }); body = await res.json().catch(() => ({})); retryAfter = Number(res.headers.get('retry-after')) || 30; }
  catch (e) { return { status: 0, code: 'fetch_error:' + e.message, ms: Date.now() - t }; }
  const code = res.status >= 400 ? ((body.type || '').replace('/errors/', '') || JSON.stringify(body).slice(0, 120)) : null;
  return { status: res.status, retryAfter, code, detail: res.status >= 400 ? body.detail : undefined, log_index: body.release?.log_index ?? null, ms: Date.now() - t };
}

for (const { repo, kind } of repos) {
  let rels;
  try { rels = gh(['api', `repos/${repo}/releases`, '--paginate', '--jq', '.[] | {published_at, created_at, assets: [.assets[] | {name, browser_download_url}]}']).split('\n').filter(Boolean).map((l) => JSON.parse(l)); }
  catch (e) { perRepo.set(repo, { kind, assets: 0, counts: {}, note: 'releases not readable' }); noAsset.push(`${repo} (releases not readable)`); continue; }
  const assets = [];
  for (const r of rels.sort((a, b) => (a.published_at || a.created_at).localeCompare(b.published_at || b.created_at)))
    for (const a of r.assets) if (HASH.test(a.name)) assets.push(a.browser_download_url);
  const ent = { kind, assets: assets.length, counts: {} }; perRepo.set(repo, ent);
  if (!assets.length) noAsset.push(repo);
  for (const url of assets) {
    if (done.has(url)) { const j = prior.find((p) => p.url === url); const key = j.status < 400 ? String(j.status) : `${j.status} ${j.code}`; ent.counts[key] = (ent.counts[key] || 0) + 1; continue; }
    await sleep(1100);
    let r = await post(url);
    if (r.status === 503) { await sleep(5000); r = await post(url); r.retried = true; }
    for (let i = 0; r.status === 429 && r.retryAfter <= 120 && i < 3; i++) { await sleep((r.retryAfter + 1) * 1000); r = await post(url); r.retried = true; }
    delete r.retryAfter;
    total++; if (r.status >= 500 || r.status === 0) n5xx++;
    const key = r.status < 400 ? String(r.status) : `${r.status} ${r.code}`;
    ent.counts[key] = (ent.counts[key] || 0) + 1;
    jsonl.push(JSON.stringify({ repo, url, ...r }));
    if (total >= 20 && n5xx / total > 0.2) { console.error('ABORT: more than 20 percent 5xx'); writeFileSync(here + 'ingest.jsonl', jsonl.join('\n') + '\n'); process.exit(2); }
  }
  console.error(repo, ent.assets, JSON.stringify(ent.counts));
  writeFileSync(here + 'ingest.jsonl', jsonl.join('\n') + '\n');
}

// RESULT.md
const tot = {}; const errEx = {};
for (const l of jsonl) { const j = JSON.parse(l); const k = j.status < 400 ? String(j.status) : `${j.status} ${j.code}`; tot[k] = (tot[k] || 0) + 1; if (j.status >= 400 && !errEx[k]) errEx[k] = j.url; }
const fmt = (c) => Object.entries(c).map(([k, v]) => `${k} x${v}`).join(', ') || '-';
let md = `# roc-awesome ingest result\n\n| Item | Value |\n|---|---|\n| List commit | ${sha.sha} |\n| Commit date | ${sha.commit.committer.date} |\n| Registry | ${REG} |\n| Requests | ${total} |\n\n## Per repo\n\n| Repo | Kind | Assets | Results |\n|---|---|---|---|\n`;
for (const [r, e] of perRepo) if (e.assets) md += `| ${r} | ${e.kind} | ${e.assets} | ${fmt(e.counts)} |\n`;
md += `\n## Totals\n\n| Result | Count |\n|---|---|\n` + Object.entries(tot).map(([k, v]) => `| ${k} | ${v} |`).join('\n') + `\n\n## Distinct error codes\n\n| Result | Example URL |\n|---|---|\n` + (Object.entries(errEx).map(([k, v]) => `| ${k} | ${v} |`).join('\n') || '| none | |') + `\n\n## Repos with no hash-named asset\n\n` + noAsset.map((r) => `- ${r}`).join('\n') + `\n\n## List entries not on github.com (not scanned)\n\n` + skipped.map((s) => `- ${s.repo} (${s.url})`).join('\n') + '\n';
writeFileSync(here + 'RESULT.md', md);
