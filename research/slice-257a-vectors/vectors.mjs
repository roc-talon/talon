// Slice 257a: test vectors for packages/records/Tlog.roc, made with node:crypto only (not with the code under test).
// The formats are from the spec text (c2sp.org/tlog-tiles, c2sp.org/tlog-checkpoint, c2sp.org/signed-note, RFC 6962, golang.org/x/mod/sumdb/note),
// read on 2026-11-19. The tiles are made from their definition (each hash of a tile is the RFC 6962 hash of its subtree), not by an incremental build.
// Usage (repo root): node research/slice-257a-vectors/vectors.mjs [--write]
//   prints the checks of the published Go example key and writes vectors.json next to this file.
//   --write also replaces the generated block of packages/records/tests/TlogTest.roc.
// The Ed25519 key is a throwaway test key made from a fixed text. It signs nothing outside the tests.
import { createHash, createPrivateKey, createPublicKey, sign, verify } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");
const sha = (...b) => createHash("sha256").update(Buffer.concat(b.map((x) => Buffer.from(x)))).digest();
const hex = (b) => Buffer.from(b).toString("hex");
const b64 = (b) => Buffer.from(b).toString("base64");
const leafHash = (e) => sha([0], e);
const nodeHash = (l, r) => sha([1], l, r);
// RFC 6962 MTH: split at the largest power of 2 smaller than n.
function mth(hs) {
  if (hs.length === 0) return sha([]);
  if (hs.length === 1) return hs[0];
  let k = 1;
  while (k * 2 < hs.length) k *= 2;
  return nodeHash(mth(hs.slice(0, k)), mth(hs.slice(k)));
}

// R-SG2: `<grp> <version> <hash> <time>\n`. The test leaves: leaf i (tlog index i).
const leaf = (i) => ({ grp: "github.com/acme/pkg/releases/download/{v}/", version: `1.0.${i}`, hash: "6YbXkqTz7pUm2Ff8RcWvJ3s9Hd1LgAeNo4QxBiKt5uP", time: 1763500000000 + i * 1000 });
const entryOf = (l) => Buffer.from(`${l.grp} ${l.version} ${l.hash} ${l.time}\n`, "utf8");
const MAXLEAVES = 600;
const entries = Array.from({ length: MAXLEAVES }, (_, i) => entryOf(leaf(i)));
const hashes = entries.map(leafHash);

// tlog-tiles: the N path elements: zero-padded 3-digit groups, `x` before each group but the last.
function nPath(n) {
  let s = String(n);
  while (s.length % 3) s = "0" + s;
  const g = s.match(/.../g);
  return g.map((x, i) => (i < g.length - 1 ? "x" + x : x)).join("/");
}
const pathOf = (t) => (t.level === "E" ? "tile/entries/" : `tile/${t.level}/`) + nPath(t.index) + (t.width === 256 ? "" : `.p/${t.width}`);
// All tiles of a tree of size s: at level L the count of hashes is floor(s / 256^L); full tiles and one partial tile.
// The entry bundles have the indexes of the level 0 tiles. Order: entry bundles, then levels 0, 1, ...; index order in each.
function tilesOf(s) {
  const out = [];
  const add = (level, count) => {
    for (let n = 0; n < Math.floor(count / 256); n++) out.push({ level, index: n, width: 256 });
    if (count % 256) out.push({ level, index: Math.floor(count / 256), width: count % 256 });
  };
  add("E", s);
  for (let L = 0, c = s; c > 0; L++, c = Math.floor(c / 256)) add(L, c);
  return out;
}
const growth = (S, N) => {
  const old = new Set(tilesOf(S).map(pathOf));
  return tilesOf(N).filter((t) => !old.has(pathOf(t)));
};
const edge = (S) => tilesOf(S).filter((t) => t.width !== 256);
// The bytes of a tile, from its definition. A hash at level L, position k is the MTH of the leaves k*256^L to (k+1)*256^L - 1.
function tileBytes(t) {
  if (t.level === "E") return bundle(entries.slice(t.index * 256, t.index * 256 + t.width));
  const span = 256 ** t.level;
  const out = [];
  for (let k = t.index * 256; k < t.index * 256 + t.width; k++) out.push(mth(hashes.slice(k * span, (k + 1) * span)));
  return Buffer.concat(out);
}
function bundle(es) {
  return Buffer.concat(es.flatMap((e) => { const p = Buffer.alloc(2); p.writeUInt16BE(e.length); return [p, e]; }));
}

// Ed25519 (RFC 8032) keys: PKCS#8 is a fixed 16-byte prefix and the 32-byte seed.
const PKCS8_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");
function keyOfSeed(seed) {
  const priv = createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, seed]), format: "der", type: "pkcs8" });
  const pub = Buffer.from(createPublicKey(priv).export({ format: "jwk" }).x, "base64url");
  const pkcs8 = priv.export({ format: "der", type: "pkcs8" });
  return { priv, pub, pkcs8 };
}
// signed-note: key ID = SHA-256(key name || 0x0A || 0x01 || 32-byte public key)[:4]
const keyId = (name, pub) => sha(Buffer.from(name, "utf8"), [0x0a, 0x01], pub).subarray(0, 4);
const signerText = (name, id, seed) => `PRIVATE+KEY+${name}+${hex(id)}+${b64(Buffer.concat([Buffer.from([1]), seed]))}`;
const verifierText = (name, id, pub) => `${name}+${hex(id)}+${b64(Buffer.concat([Buffer.from([1]), pub]))}`;
const noteOf = (text, name, id, sig) => `${text}\n— ${name} ${b64(Buffer.concat([id, sig]))}\n`;

// --- Cross-check 1: the published example of golang.org/x/mod/sumdb/note (PeterNeumann). It checks the key id formula, the seed form of the
// signer key text and the note form against an independent source.
const go = {
  signer: "PRIVATE+KEY+PeterNeumann+c74f20a3+AYEKFALVFGyNhPJEMzD1QIDr+Y7hfZx09iUvxdXHKDFz",
  verifier: "PeterNeumann+c74f20a3+ARpc2QcUPDhMQegwxbzhKqiBfsVkmqq/LDE4izWy10TW",
  text: "If you think cryptography is the answer to your problem,\nthen you don't know what your problem is.\n",
  sigLine: "— PeterNeumann x08go/ZJkuBS9UG/SffcvIAQxVBtiFupLLr8pAcElZInNIuGUgYN1FFYC2pZSNXgKvqfqdngotpRZb6KE6RyyBwJnAM=\n",
};
{
  const kd = Buffer.from(go.signer.split("+").slice(4).join("+"), "base64"); // the key data is base64: it can hold a "+"
  const seed = kd.subarray(1);
  const k = keyOfSeed(seed);
  const id = keyId("PeterNeumann", k.pub);
  const sig = sign(null, Buffer.from(go.text), k.priv);
  const checks = [
    ["signer key data is 0x01 || 32-byte seed", kd.length === 33 && kd[0] === 1],
    ["key id c74f20a3", hex(id) === "c74f20a3"],
    ["verifier key text", verifierText("PeterNeumann", id, k.pub) === go.verifier],
    ["signer key text round trip", signerText("PeterNeumann", id, seed) === go.signer],
    ["note signature line", noteOf(go.text, "PeterNeumann", id, sig) === go.text + "\n" + go.sigLine],
  ];
  for (const [n, ok] of checks) console.log(`go-example: ${n}: ${ok ? "ok" : "FAIL"}`);
  if (checks.some(([, ok]) => !ok)) process.exit(1);
  go.seed = seed; go.pub = k.pub; go.sig = sig;
}
// --- Cross-check 2: RFC 6962 has no published vectors for this leaf form; the Go tlog package is not installed (no `go`). The MTH here is checked
// against an incremental build (the stack of complete subtrees, as RFC 9162 2.1.4) for each size 0 to MAXLEAVES.
{
  let bad = 0;
  for (let n = 0; n <= MAXLEAVES; n++) {
    const stack = [];
    for (let i = 0; i < n; i++) {
      let h = hashes[i], size = 1;
      while (stack.length && stack[stack.length - 1].size === size) { const l = stack.pop(); h = nodeHash(l.h, h); size *= 2; }
      stack.push({ h, size });
    }
    let r = n === 0 ? sha([]) : stack[stack.length - 1].h;
    for (let j = stack.length - 2; j >= 0; j--) r = nodeHash(stack[j].h, r);
    if (!r.equals(mth(hashes.slice(0, n)))) bad++;
  }
  console.log(`mth vs incremental, sizes 0 to ${MAXLEAVES}: ${bad ? "FAIL " + bad : "ok"}`);
  if (bad) process.exit(1);
}
// --- Cross-check 3: the tile bytes give the root: the root of N is the MTH of the hashes of the top partial tile... checked here by the
// definition only (tileBytes uses mth of the leaves), and by the spec example: size 256 is a full level 0 tile and a partial level 1 tile of width 1.
if (tilesOf(256).filter((t) => t.level !== "E").map(pathOf).join(" ") !== "tile/0/000 tile/1/000.p/1") { console.log("spec example size 256: FAIL"); process.exit(1); }
console.log("spec example size 256: ok");

// --- The test key and the checkpoint.
const ORIGIN = "registry.roc-talon.org/log";
const seed = sha(Buffer.from("talon slice 257a throwaway test key, never used outside the tests"));
const key = keyOfSeed(seed);
const id = keyId(ORIGIN, key.pub);
const ckSize = 257;
const ckRoot = mth(hashes.slice(0, ckSize));
const body = `${ORIGIN}\n${ckSize}\n${b64(ckRoot)}\n`;
const sig = sign(null, Buffer.from(body), key.priv);
const note = noteOf(body, ORIGIN, id, sig);
if (!verify(null, Buffer.from(body), createPublicKey(key.priv), sig)) process.exit(1);

const compilerLeaf = { grp: "roc-lang/nightlies:x86_64-linux", version: "nightly-2026-10-14-38a3029", hash: "sha256:" + hex(sha(Buffer.from("roc"))), time: 1760400000000 };

const ROOT_SIZES = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 255, 256, 257, 511, 512, 513, 600];
const PATHS = [
  { level: 0, index: 0, width: 256 }, { level: 0, index: 999, width: 256 }, { level: 0, index: 1000, width: 256 },
  { level: 0, index: 1234067, width: 256 }, { level: 0, index: 1000000, width: 256 }, { level: 0, index: 1234, width: 7 },
  { level: 2, index: 5, width: 1 }, { level: 1, index: 0, width: 255 }, { level: 63, index: 0, width: 1 },
  { level: "E", index: 0, width: 256 }, { level: "E", index: 1234, width: 7 }, { level: "E", index: 1234067, width: 255 },
];
const GROWTH = [[0, 0], [5, 5], [0, 1], [1, 2], [2, 3], [3, 7], [0, 8], [0, 256], [255, 256], [256, 257], [255, 257], [0, 257], [257, 513], [65535, 65536], [65536, 65537], [65535, 65537]];
const BIG_GROWTH = [[0, 65537], [1000, 70000], [16777215, 16777217]];
const EDGES = [0, 1, 3, 255, 256, 257, 511, 512, 65535, 65536, 65537, 70000, 16777216, 16777217];
const GROW = [[0, 0], [0, 1], [0, 3], [3, 7], [0, 7], [0, 256], [255, 256], [256, 257], [0, 257], [7, 257], [257, 513], [0, 513], [513, 600], [0, 600]];

const roc = [];
const L = (s) => roc.push(s);
const rTile = (t) => `{ level: ${t.level === "E" ? "Entries" : `Hashes(${t.level})`}, index: ${t.index}, width: ${t.width} }`;
const rStrs = (xs) => `[${xs.map((x) => JSON.stringify(x)).join(", ")}]`;

L("# The leaf i of the vectors (tlog index i), as research/slice-257a-vectors/vectors.mjs makes it.");
L("vec_leaf : U64 -> Tlog.Leaf");
L(`vec_leaf = |i| { grp: ${JSON.stringify(leaf(0).grp)}, version: "1.0.\${i.to_str()}", hash: ${JSON.stringify(leaf(0).hash)}, time: 1763500000000 + i.to_i64_wrap() * 1000 }`);
L("");
L("vec_entry0 : Str");
L(`vec_entry0 = ${JSON.stringify(entries[0].toString())}`);
L("");
L("vec_compiler_leaf : Tlog.Leaf");
L(`vec_compiler_leaf = { grp: ${JSON.stringify(compilerLeaf.grp)}, version: ${JSON.stringify(compilerLeaf.version)}, hash: ${JSON.stringify(compilerLeaf.hash)}, time: ${compilerLeaf.time} }`);
L("");
L("vec_compiler_entry : Str");
L(`vec_compiler_entry = ${JSON.stringify(entryOf(compilerLeaf).toString())}`);
L("");
L("# SHA-256(0x00 || entry) of leaf 0, of the compiler leaf; SHA-256(0x01 || h0 || h1).");
L("vec_leaf_hashes : { leaf0 : Str, compiler : Str, node01 : Str, empty : Str }");
L(`vec_leaf_hashes = { leaf0: "${hex(hashes[0])}", compiler: "${hex(leafHash(entryOf(compilerLeaf)))}", node01: "${hex(nodeHash(hashes[0], hashes[1]))}", empty: "${hex(sha([]))}" }`);
L("");
L("# (size, MTH of the first size leaves).");
L("vec_roots : List((U64, Str))");
L(`vec_roots = [${ROOT_SIZES.map((n) => `(${n}, "${hex(mth(hashes.slice(0, n)))}")`).join(", ")}]`);
L("");
L("vec_paths : List((Tlog.Tile, Str))");
L(`vec_paths = [${PATHS.map((t) => `(${rTile(t)}, ${JSON.stringify(pathOf(t))})`).join(", ")}]`);
L("");
L("# (S, N, the paths of the new tiles in the order of Tlog.growth).");
L("vec_growth : List((U64, U64, List(Str)))");
L(`vec_growth = [${GROWTH.map(([s, n]) => `(${s}, ${n}, ${rStrs(growth(s, n).map(pathOf))})`).join(", ")}]`);
L("");
L("# (S, N, count of the new tiles, SHA-256 hex of the paths joined with a newline after each path).");
L("vec_big_growth : List((U64, U64, U64, Str))");
L(`vec_big_growth = [${BIG_GROWTH.map(([s, n]) => { const p = growth(s, n).map(pathOf); return `(${s}, ${n}, ${p.length}, "${hex(sha(Buffer.from(p.map((x) => x + "\n").join(""))))}")`; }).join(", ")}]`);
L("");
L("# (S, the paths of the partial tiles of size S, in the order of Tlog.edge).");
L("vec_edges : List((U64, List(Str)))");
L(`vec_edges = [${EDGES.map((s) => `(${s}, ${rStrs(edge(s).map(pathOf))})`).join(", ")}]`);
L("");
L("# (S, N, MTH of S, MTH of N, the new tiles: (path, SHA-256 hex of the tile bytes)).");
L("vec_grow : List((U64, U64, Str, Str, List((Str, Str))))");
L(`vec_grow = [${GROW.map(([s, n]) => `(${s}, ${n}, "${hex(mth(hashes.slice(0, s)))}", "${hex(mth(hashes.slice(0, n)))}", [${growth(s, n).map((t) => `(${JSON.stringify(pathOf(t))}, "${hex(sha(tileBytes(t)))}")`).join(", ")}])`).join(", ")}]`);
L("");
L("# The bytes of the 2 partial tiles of size 3, in hex: tile/0/000.p/3 and tile/entries/000.p/3.");
L("vec_tiles3 : { hashes : Str, entries : Str }");
L(`vec_tiles3 = { hashes: "${hex(tileBytes({ level: 0, index: 0, width: 3 }))}", entries: "${hex(tileBytes({ level: "E", index: 0, width: 3 }))}" }`);
L("");
L("vec_origin : Str");
L(`vec_origin = ${JSON.stringify(ORIGIN)}`);
L("");
L("# The throwaway test key: the seed, the public key, the key id, PKCS#8, the signer and verifier key texts.");
L("vec_key : { seed : Str, public : Str, key_id : Str, pkcs8 : Str, signer : Str, verifier : Str }");
L(`vec_key = { seed: "${hex(seed)}", public: "${hex(key.pub)}", key_id: "${hex(id)}", pkcs8: "${hex(key.pkcs8)}", signer: ${JSON.stringify(signerText(ORIGIN, id, seed))}, verifier: ${JSON.stringify(verifierText(ORIGIN, id, key.pub))} }`);
L("");
L("# Key data that is not 0x01 || 32-byte seed: type byte 0x02 with the test seed; the test seed alone (32 bytes, no type byte).");
L("vec_bad_key_data : { alg2 : Str, short : Str }");
L(`vec_bad_key_data = { alg2: "${b64(Buffer.concat([Buffer.from([2]), seed]))}", short: "${b64(seed)}" }`);
L("");
L("# The checkpoint of size 257 (root of the 257 test leaves), its Ed25519 signature by the test key (hex), and the signed note.");
L("vec_checkpoint : { size : U64, root : Str, body : Str, signature : Str, note : Str }");
L(`vec_checkpoint = { size: ${ckSize}, root: "${hex(ckRoot)}", body: ${JSON.stringify(body)}, signature: "${hex(sig)}", note: ${JSON.stringify(note)} }`);
L("");
L("# The published example of golang.org/x/mod/sumdb/note: seed, public key, signature (hex), the note text, the signed note, the signer key text.");
L("vec_go : { seed : Str, public : Str, signature : Str, text : Str, note : Str, signer : Str }");
L(`vec_go = { seed: "${hex(go.seed)}", public: "${hex(go.pub)}", signature: "${hex(go.sig)}", text: ${JSON.stringify(go.text)}, note: ${JSON.stringify(go.text + "\n" + go.sigLine)}, signer: ${JSON.stringify(go.signer)} }`);

const text = roc.join("\n").replaceAll("\\u2014", "—");
writeFileSync(join(HERE, "vectors.roc.txt"), text + "\n");
writeFileSync(join(HERE, "vectors.json"), JSON.stringify({ origin: ORIGIN, seed: hex(seed), public: hex(key.pub), key_id: hex(id), note, roots: ROOT_SIZES.map((n) => [n, hex(mth(hashes.slice(0, n)))]), growth: GROWTH.map(([s, n]) => [s, n, growth(s, n).map(pathOf)]), edges: EDGES.map((s) => [s, edge(s).map(pathOf)]) }, null, 1) + "\n");
console.log(`wrote ${join(HERE, "vectors.roc.txt")} and vectors.json`);
if (process.argv.includes("--write")) {
  const f = join(ROOT, "packages/records/tests/TlogTest.roc");
  const src = readFileSync(f, "utf8");
  const a = "# --- vectors: generated by research/slice-257a-vectors/vectors.mjs, do not edit ---\n";
  const b = "# --- end of vectors ---\n";
  const i = src.indexOf(a), j = src.indexOf(b);
  if (i < 0 || j < i) { console.log("TlogTest.roc has no vector block"); process.exit(1); }
  writeFileSync(f, src.slice(0, i + a.length) + "\n" + text + "\n\n" + src.slice(j));
  console.log(`wrote the vector block of ${f}`);
}
