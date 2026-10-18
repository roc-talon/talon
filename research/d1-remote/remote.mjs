// Remote mode of the D1 prototypes (`node test.mjs remote`): the D1 binding goes to the real database
// rocplat-test-d1-remote through wrangler remote bindings. run.sh makes the database and .state/wrangler.toml.
import { existsSync } from "node:fs";

export const REMOTE = process.argv[2] === "remote";
const toml = new URL(".state/wrangler.toml", import.meta.url).pathname;

// The config path for getPlatformProxy: the remote config in remote mode, else the local one of the prototype.
export function configPath(local) {
  if (!REMOTE) return local;
  if (!existsSync(toml)) throw new Error("no remote config: run research/d1-remote/run.sh create first");
  return toml;
}

// Remove each table, view and trigger of the remote database, so that each run starts empty.
export async function wipe(db) {
  if (!REMOTE) return;
  const { results } = await db.prepare(
    "SELECT type, name FROM sqlite_master WHERE type IN ('table', 'view', 'trigger') AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%'").all();
  const order = { trigger: 0, view: 1, table: 2 };
  const drops = results.sort((a, b) => order[a.type] - order[b.type]).map((r) => db.prepare(`DROP ${r.type.toUpperCase()} IF EXISTS "${r.name}"`));
  if (drops.length) await db.batch([db.prepare("PRAGMA defer_foreign_keys = on"), ...drops]);
}
