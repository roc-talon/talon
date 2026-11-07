// Read the corpus of a registry from its read API (Registry 4: R-AP5, R-AP14). Used by gen-scenarios.mjs and local.mjs.
// Request pace: a remote host gets one request in 100 ms at most. A 5xx or a network fault is tried again (up to 4 times):
// discovery is not a measurement. (The driver, drive.mjs, never tries again.)
import { isLoopback, sleep } from './lib.mjs';

export function client(base) {
  const gap = isLoopback(base) ? 0 : 100;
  let last = 0;
  let calls = 0;
  const get = async (path) => {
    for (let attempt = 0; ; attempt++) {
      const wait = last + gap - Date.now();
      if (wait > 0) await sleep(wait);
      last = Date.now();
      calls++;
      try {
        const r = await fetch(base + path, { headers: { 'user-agent': 'tln-bench/0', accept: 'application/json' } });
        if (r.status >= 500 && attempt < 4) { await r.arrayBuffer(); await sleep(300); continue; }
        if (r.status !== 200) throw new Error(`GET ${path}: status ${r.status}`);
        return await r.json();
      } catch (e) {
        if (attempt >= 4) throw e;
        if (String(e.message).startsWith('GET ')) throw e;
        await sleep(300);
      }
    }
  };
  return { get, calls: () => calls };
}

// Result: { toolchains: [rows of R-RE4], releases: [releases of R-RE2], repos: [R-AP32 items], log_size }.
export async function discover(base) {
  const c = client(base);
  const toolchains = [];
  for (let after = 0; ;) {
    const page = await c.get(`/v1/toolchains?after=${after}`);
    toolchains.push(...page.toolchains);
    if (!page.more || page.toolchains.length === 0) break;
    after = page.toolchains[page.toolchains.length - 1].log_index;
  }
  const releases = [];
  const repos = new Map();
  for (let after = 0; ;) {
    const page = await c.get(`/v1/releases?after=${after}`);
    releases.push(...page.releases);
    for (const r of page.repos) repos.set(r.name, r);
    if (page.releases.length === 0) break;
    after = page.releases[page.releases.length - 1].log_index;
  }
  return { toolchains, releases, repos: [...repos.values()], requests: c.calls() };
}
