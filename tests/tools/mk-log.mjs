// Slice 261c: the fake registry log of an L2 case (DESIGN-CLI 7.6, R-LV1 to R-LV12; Registry R-SG2, R-SG4, R-AP11).
// From the spec `<case>/mk-log.json` it writes the routes `fx/http/<host>/log/checkpoint[.n]` and `fx/http/<host>/log/tile/...` (binary, as the Worker serves them),
// and the kept copies of R-IX8 in `given/home/` (text). It prints the line `TALON_LOG_KEY=<verifier key>` for `fx/env`.
// node:crypto only. The keys are throwaway TEST keys made from fixed texts (fixed test seeds). The real signer (secrets/log-key-signer) is never read.
// Usage (repo root): node tests/tools/mk-log.mjs <case dir>
//
// Spec (all optional but `host`):
//   host       the host dir of the routes, decoded ("127.0.0.1:9"); the dir name in the repo is encoded (%3A, TESTING.md 3.1)
//   origin     the log origin = the key name (default "<host>/log")
//   index_dir  the <origin> dir name of R-IX1 (default "http_" + host with ":" as "_")
//   key        the seed text of the key of TALON_LOG_KEY (default "talon slice 261c test key L")
//   leaves     { "<log_index>": "<grp> <version> <hash> <time>" }: the entry at tlog index log_index - 1. Other leaves are filler entries.
//   serve      [ { "file": "checkpoint" | "checkpoint.<n>", "size": N, "key": "<seed>" (default: key), "meta": "<text of .meta>" } ]: the served checkpoints.
//              The tiles of each served size are served too (no tiles: "tiles": false on the item).
//   omit       [ "<tile path>" ]: a tile route that is not served (404)
//   tamper     [ { "path": "<tile path>", "byte": n } ]: one served tile with byte n changed (xor 0x01)
//   kept       { "size": N, "leaves": { ... } (another tree: a fork), "tiles": true|false, "home": "given/home" }: the kept checkpoint (and its tile copies) of R-IX8
import { createHash, createPrivateKey, createPublicKey, sign } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const sha = (...b) => createHash("sha256").update(Buffer.concat(b.map((x) => Buffer.from(x)))).digest();
const hex = (b) => Buffer.from(b).toString("hex");
const b64 = (b) => Buffer.from(b).toString("base64");
const leafHash = (e) => sha([0], e);
const nodeHash = (l, r) => sha([1], l, r);
const split = (n) => { let k = 1; while (k * 2 < n) k *= 2; return k; };
// RFC 6962 MTH of leaf hashes hs[a .. a + n - 1].
function mth(hs, a, n) {
  if (n === 0) return sha([]);
  if (n === 1) return hs[a];
  const k = split(n);
  return nodeHash(mth(hs, a, k), mth(hs, a + k, n - k));
}

// Keys (as research/slice-261-vectors/vectors.mjs).
const PKCS8_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");
const keyIdOf = (name, keyData) => sha(Buffer.from(name), [10], keyData).subarray(0, 4);
function keyOf(text, name) {
  const priv = createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, sha(text)]), format: "der", type: "pkcs8" });
  const pub = Buffer.from(createPublicKey(priv).export({ format: "jwk" }).x, "base64url");
  const data = Buffer.concat([Buffer.from([1]), pub]);
  const id = keyIdOf(name, data);
  return { name, priv, id, verifier: `${name}+${hex(id)}+${b64(data)}` };
}

// tlog-tiles paths.
function nPath(n) {
  let s = String(n);
  while (s.length % 3) s = "0" + s;
  const g = s.match(/.../g);
  return g.map((x, i) => (i < g.length - 1 ? "x" + x : x)).join("/");
}
const tilePath = (level, index, width) => (level === "E" ? "tile/entries/" : `tile/${level}/`) + nPath(index) + (width === 256 ? "" : `.p/${width}`);

const filler = (i) => `github.com/acme/filler/releases/download/{v}/ 0.${i}.0 11111111111111111111111111111111 1790000000000`;
function entriesOf(leaves, size) {
  const out = [];
  for (let i = 0; i < size; i++) out.push(Buffer.from(`${leaves[String(i + 1)] ?? filler(i)}\n`));
  return out;
}

// Every tile of the tree of `size`: { path, served (bytes), copy (text of R-IX8) }.
function tilesOf(entries, size) {
  const hs = entries.slice(0, size).map(leafHash);
  const out = [];
  for (let b = 0; b * 256 < size; b++) {
    const es = entries.slice(b * 256, Math.min(size, b * 256 + 256));
    const served = Buffer.concat(es.flatMap((e) => [Buffer.from([e.length >> 8, e.length & 255]), e]));
    out.push({ path: tilePath("E", b, es.length), served, copy: Buffer.concat(es) });
  }
  for (let L = 0, span = 1; Math.floor(size / span) > 0; L++, span *= 256) {
    const count = Math.floor(size / span);
    for (let t = 0; t * 256 < count; t++) {
      const w = Math.min(256, count - t * 256);
      const hashes = [];
      for (let p = t * 256; p < t * 256 + w; p++) hashes.push(mth(hs, p * span, span));
      out.push({ path: tilePath(L, t, w), served: Buffer.concat(hashes), copy: Buffer.from(hashes.map((h) => hex(h) + "\n").join("")) });
    }
  }
  return out;
}

function note(origin, entries, size, k) {
  const body = `${origin}\n${size}\n${b64(mth(entries.map(leafHash), 0, size))}\n`;
  return `${body}\n— ${k.name} ${b64(Buffer.concat([k.id, sign(null, Buffer.from(body), k.priv)]))}\n`;
}

const write = (path, data) => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, data); };
const enc = (s) => s.replace(/%/g, "%25").replace(/:/g, "%3A");

const dir = process.argv[2];
if (!dir) { console.error("usage: node tests/tools/mk-log.mjs <case dir>"); process.exit(2); }
const spec = JSON.parse(readFileSync(join(dir, "mk-log.json"), "utf8"));
const origin = spec.origin ?? `${spec.host}/log`;
const indexDir = spec.index_dir ?? `http_${spec.host.replace(/:/g, "_")}`;
const key = keyOf(spec.key ?? "talon slice 261c test key L", origin);
const leaves = spec.leaves ?? {};
const route = join(dir, "fx/http", enc(spec.host), "log");
const max = Math.max(0, ...(spec.serve ?? []).map((s) => s.size), spec.kept?.size ?? 0);
const entries = entriesOf(leaves, max);

const served = new Map();
for (const s of spec.serve ?? []) {
  const k = s.key ? keyOf(s.key, origin) : key;
  write(join(route, s.file), note(origin, entries, s.size, k));
  if (s.meta) write(join(route, `${s.file}.meta`), s.meta);
  if (s.tiles !== false) for (const t of tilesOf(entries, s.size)) served.set(t.path, Buffer.from(t.served));
}
for (const t of spec.tamper ?? []) {
  const b = served.get(t.path);
  if (!b) throw new Error(`tamper: no tile ${t.path}`);
  b[t.byte] ^= 1;
}
for (const p of spec.omit ?? []) if (!served.delete(p)) throw new Error(`omit: no tile ${p}`);
for (const [p, b] of served) write(join(route, p), b);

if (spec.kept) {
  const kl = spec.kept.leaves ? { ...leaves, ...spec.kept.leaves } : leaves;
  const ke = entriesOf(kl, spec.kept.size);
  const home = join(dir, spec.kept.home ?? "given/home");
  write(join(home, ".local/share/talon/log", indexDir, "checkpoint"), note(origin, ke, spec.kept.size, key));
  if (spec.kept.tiles !== false) {
    for (const t of tilesOf(ke, spec.kept.size)) write(join(home, ".cache/roc/talon/index/registry", indexDir, "log", t.path), t.copy);
  }
}
console.log(`TALON_LOG_KEY=${key.verifier}`);
