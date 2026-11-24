// Slice 261b: test vectors for the Tlog reader functions (packages/records/Tlog.roc) and the cli/lib parts (LogKey.roc, LogProof.roc).
// node:crypto only, not the code under test. The tiles, the proof tile lists and the roots come from their definition (RFC 6962 MTH of each subtree,
// C2SP tlog-tiles), not from an incremental build.
// The Ed25519 keys are throwaway test keys made from fixed texts (FIXED TEST SEEDS). They sign nothing outside the tests. The real signer is never read.
// The live checkpoint (checkpoint-386.txt) and the built-in verifier key are public data (live.mjs checks them).
// Usage (repo root): node research/slice-261-vectors/vectors.mjs records|cli   prints the Roc vector block for TlogTest.roc or for the cli tests.
import { createHash, createPrivateKey, createPublicKey, sign, verify } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const sha = (...b) => createHash("sha256").update(Buffer.concat(b.map((x) => Buffer.from(x)))).digest();
const hex = (b) => Buffer.from(b).toString("hex");
const b64 = (b) => Buffer.from(b).toString("base64");
const leafHash = (e) => sha([0], e);
const nodeHash = (l, r) => sha([1], l, r);
const split = (n) => { let k = 1; while (k * 2 < n) k *= 2; return k; };
const rocStr = (s) => JSON.stringify(s).replace(/\$\{/g, "\\${");

// --- tlog-tiles paths and tile lists (from the spec text) ---
function nPath(n) {
  let s = String(n);
  while (s.length % 3) s = "0" + s;
  const g = s.match(/.../g);
  return g.map((x, i) => (i < g.length - 1 ? "x" + x : x)).join("/");
}
const pathOf = (t) => (t.level === "E" ? "tile/entries/" : `tile/${t.level}/`) + nPath(t.index) + (t.width === 256 ? "" : `.p/${t.width}`);
const P = (e) => 256n ** BigInt(e);
// The tile of level L (a hash level) that holds position p of that level, for a tree of size n.
function tileAt(L, p, n) {
  const count = Number(BigInt(n) / P(L));
  const index = Math.floor(p / 256);
  return { level: L, index, width: Math.min(256, count - index * 256) };
}
// The hash tiles of size n with a width below 256, lowest level first (the hash part of Tlog.edge).
function edgeHashes(n) {
  const out = [];
  for (let L = 0, c = n; c > 0; L++, c = Math.floor(c / 256)) if (c % 256) out.push({ level: L, index: Math.floor(c / 256), width: c % 256 });
  return out;
}
// The chain from a tile up: each full tile, then the tile one level up that holds its MTH, until the first partial tile.
function chain(t, n) {
  const out = [t];
  let cur = t;
  while (cur.width === 256) {
    cur = tileAt(cur.level + 1, cur.index, n);
    out.push(cur);
  }
  return out;
}
const dedup = (ts) => { const seen = new Set(); return ts.filter((t) => { const p = pathOf(t); if (seen.has(p)) return false; seen.add(p); return true; }); };
// proof_tiles(i, n): the chain of the level 0 tile of i, then the other hash tiles of edge(n) in edge order. i >= n: none.
const proofTiles = (i, n) => (i >= n ? [] : dedup([...chain(tileAt(0, i, n), n), ...edgeHashes(n)]));
// consistency_tiles(m, n): a = min, b = max. a == b or a == 0: none. Else, for each hash tile of edge(a) (lowest level first): the tile of b at the same
// level and index, and its chain; then the other hash tiles of edge(b).
function consistencyTiles(m, n) {
  const a = Math.min(m, n), b = Math.max(m, n);
  if (a === b || a === 0) return [];
  return dedup([...edgeHashes(a).flatMap((t) => chain(tileAt(t.level, t.index * 256, b), b)), ...edgeHashes(b)]);
}
const entryTile = (i, n) => ({ level: "E", index: Math.floor(i / 256), width: Math.min(256, n - Math.floor(i / 256) * 256) });

// --- The "uniform" test tree: every leaf has the entry E, except the leaf s, which has the entry X. Its subtree hashes are cheap to compute. ---
const E = Buffer.from("github.com/acme/same/releases/download/{v}/ 1.0.0 6YbXkqTz7pUm2Ff8RcWvJ3s9Hd1LgAeNo4QxBiKt5uP 1763500000000\n");
const X = Buffer.from("github.com/acme/special/releases/download/{v}/ 2.0.0 BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i 1763500001000\n");
const memoU = new Map();
// MTH of len leaves that all have the entry E.
function U(len) {
  if (len === 0) return sha([]);
  if (len === 1) return leafHash(E);
  if (memoU.has(len)) return memoU.get(len);
  const k = split(len);
  const h = nodeHash(U(k), U(len - k));
  memoU.set(len, h);
  return h;
}
// MTH of the leaves start .. start + len - 1 of the tree with the special leaf s.
function R(start, len, s) {
  if (s < start || s >= start + len) return U(len);
  if (len === 1) return leafHash(X);
  const k = split(len);
  return nodeHash(R(start, k, s), R(start + k, len - k, s));
}
// P_L: the hash of a full subtree of height 8L with no special leaf. S_L: of the subtree of height 8L that holds s.
const plain = (L) => U(Number(P(L)));
const special = (L, s) => { const span = Number(P(L)); return R(Math.floor(s / span) * span, span, s); };

// --- The distinct-leaf tree of 257a (TlogTest vec_leaf): its roots are vec_roots in TlogTest. ---

// --- Ed25519 test keys ---
const PKCS8_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");
const SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");
function keyOf(text, name) {
  const seed = sha(text);
  const priv = createPrivateKey({ key: Buffer.concat([PKCS8_PREFIX, seed]), format: "der", type: "pkcs8" });
  const pub = Buffer.from(createPublicKey(priv).export({ format: "jwk" }).x, "base64url");
  const id = keyIdOf(name, Buffer.concat([Buffer.from([1]), pub]));
  return { name, priv, pub, id, verifier: `${name}+${hex(id)}+${b64(Buffer.concat([Buffer.from([1]), pub]))}` };
}
// signed-note: key id = SHA-256(name ‖ 0x0A ‖ key data)[:4], where the key data starts with the type byte.
const keyIdOf = (name, keyData) => sha(Buffer.from(name), [10], keyData).subarray(0, 4);
const sigLine = (name, id, sig) => `— ${name} ${b64(Buffer.concat([id, sig]))}\n`;
const signText = (k, text) => sign(null, Buffer.from(text), k.priv);
const noteOf = (text, lines) => `${text}\n${lines.join("")}`;
function checkVerify(pub, text, sig) {
  const key = createPublicKey({ key: Buffer.concat([SPKI_PREFIX, pub]), format: "der", type: "spki" });
  return verify(null, Buffer.from(text), key, sig);
}

const ORIGIN = "registry.roc-talon.org/log";
const kA = keyOf("talon slice 261b test key A", ORIGIN);
const kA2 = keyOf("talon slice 261b test key A2", ORIGIN); // same name as A, another key: another key id
const kB = keyOf("talon slice 261b test key B", "witness.example.org/w1");
const kC = keyOf("talon slice 261b test key C", "example.org/log");

// The body of size 7 (root of the 7 distinct test leaves of 257a, vec_roots in TlogTest).
const ROOT7 = Buffer.from("19f84ee93c2757858d772d7fe8a95515806ebbdcc893ef3649818a6dfb7b49ca", "hex");
const body = (origin, size, root) => `${origin}\n${size}\n${b64(root)}\n`;
const body7 = body(ORIGIN, 7, ROOT7);
const sigA7 = signText(kA, body7);
const lineA7 = sigLine(kA.name, kA.id, sigA7);
const lineB7 = sigLine(kB.name, kB.id, signText(kB, body7));
const flipped = Buffer.from(sigA7); flipped[63] ^= 1;
const root7x = Buffer.from(ROOT7); root7x[0] ^= 1;
const extBody = `${body7}extension line\n`;
const notes = {
  good: noteOf(body7, [lineA7]),
  extra_before: noteOf(body7, [lineB7, lineA7]),
  extra_after: noteOf(body7, [lineA7, lineB7]),
  only_other: noteOf(body7, [lineB7]),
  other_id: noteOf(body7, [sigLine(kA2.name, kA2.id, signText(kA2, body7))]),
  bad_sig: noteOf(body7, [sigLine(kA.name, kA.id, flipped)]),
  size_changed: noteOf(body(ORIGIN, 8, ROOT7), [lineA7]),
  root_changed: noteOf(body(ORIGIN, 7, root7x), [lineA7]),
  wrong_origin: noteOf(body7, [sigLine(kC.name, kC.id, signText(kC, body7))]),
  extension: noteOf(extBody, [sigLine(kA.name, kA.id, signText(kA, extBody))]),
  no_sig: `${body7}\n`,
};
// Self-checks of the note vectors with node:crypto.
if (!checkVerify(kA.pub, body7, sigA7) || checkVerify(kA.pub, body7, flipped)) throw new Error("note self-check");
if (hex(kA.id) === hex(kA2.id)) throw new Error("A and A2 have the same key id");

// Verifier key texts that are not keys (each with the key id that matches its name and data, so only the named fault is wrong).
const vt = (name, keyData) => `${name}+${hex(keyIdOf(name, keyData))}+${b64(keyData)}`;
const pubA = Buffer.concat([Buffer.from([1]), kA.pub]);
const nonPoint = Buffer.alloc(32); nonPoint[0] = 2; // y = 2: no x on the curve (roc-ed25519 tests/key.roc)
const badKeys = {
  alg2: vt(ORIGIN, Buffer.concat([Buffer.from([2]), kA.pub])),
  short31: vt(ORIGIN, pubA.subarray(0, 32)),
  long33: vt(ORIGIN, Buffer.concat([pubA, Buffer.from([0])])),
  no_type: vt(ORIGIN, kA.pub),
  non_point: vt(ORIGIN, Buffer.concat([Buffer.from([1]), nonPoint])),
  space_name: vt("a b/log", pubA),
  wrong_id: `${ORIGIN}+${hex(kB.id)}+${b64(pubA)}`,
};

const mode = process.argv[2];
if (mode === "records") {
  const live = readFileSync(join(HERE, "checkpoint-386.txt"), "utf8");
  const [liveBody, liveLine] = live.split("\n\n");
  const liveSig = Buffer.from(liveLine.match(/^— \S+ (\S+)\n$/)[1], "base64");
  const incl = [[0, 1], [0, 2], [1, 2], [2, 3], [0, 7], [3, 7], [6, 7], [0, 256], [128, 256], [255, 256], [0, 257], [256, 257], [100, 511], [510, 511],
    [0, 65536], [40000, 65536], [65535, 65536], [0, 65537], [65536, 65537], [40000, 70000], [69999, 70000], [0, 16777217], [16777216, 16777217], [7, 7], [8, 7]];
  const cons = [[1, 2], [3, 7], [7, 256], [256, 257], [7, 257], [257, 7], [255, 511], [255, 70000], [65536, 70000], [300, 65537], [16777216, 16777217], [5, 5], [0, 5]];
  const lines = [];
  lines.push("# --- vectors of slice 261b: generated by research/slice-261-vectors/vectors.mjs records, do not edit ---", "");
  lines.push("# The live checkpoint of 2026-11-23 (public data): the note, its text, the one signature line (name, key id, signature in hex).");
  lines.push("vec_live : { note : Str, text : Str, name : Str, key_id : Str, signature : Str }");
  lines.push(`vec_live = { note: ${rocStr(live)}, text: ${rocStr(liveBody + "\n")}, name: ${rocStr(ORIGIN)}, key_id: "${hex(liveSig.subarray(0, 4))}", signature: "${hex(liveSig.subarray(4))}" }`, "");
  lines.push("# (index, size, the paths of Tlog.proof_tiles(index, size)).");
  lines.push("vec_proof_tiles : List((U64, U64, List(Str)))");
  lines.push(`vec_proof_tiles = [${incl.map(([i, n]) => `(${i}, ${n}, [${proofTiles(i, n).map((t) => `"${pathOf(t)}"`).join(", ")}])`).join(", ")}]`, "");
  lines.push("# (index, size, the path of Tlog.entry_tile(index, size)).");
  lines.push("vec_entry_tiles : List((U64, U64, Str))");
  lines.push(`vec_entry_tiles = [${incl.filter(([i, n]) => i < n).map(([i, n]) => `(${i}, ${n}, "${pathOf(entryTile(i, n))}")`).join(", ")}]`, "");
  lines.push("# (m, n, the paths of Tlog.consistency_tiles(m, n)).");
  lines.push("vec_consistency_tiles : List((U64, U64, List(Str)))");
  lines.push(`vec_consistency_tiles = [${cons.map(([m, n]) => `(${m}, ${n}, [${consistencyTiles(m, n).map((t) => `"${pathOf(t)}"`).join(", ")}])`).join(", ")}]`, "");
  lines.push("# The uniform test tree: every leaf has the entry `same`, but the leaf `special_index` has the entry `special`. plain.L: the hash of a full subtree of");
  lines.push("# height 8L with no special leaf (L 0 to 3). special_hashes.L: the hash of the subtree of height 8L that holds the special leaf. Two special indexes: 40000 and 16777216.");
  lines.push("vec_uniform : { same : Str, special : Str, plain : List(Str), special_40000 : List(Str), special_16777216 : List(Str) }");
  lines.push(`vec_uniform = { same: ${rocStr(E.toString())}, special: ${rocStr(X.toString())}, plain: [${[0, 1, 2, 3].map((L) => `"${hex(plain(L))}"`).join(", ")}], special_40000: [${[0, 1, 2].map((L) => `"${hex(special(L, 40000))}"`).join(", ")}], special_16777216: [${[0, 1, 2, 3].map((L) => `"${hex(special(L, 16777216))}"`).join(", ")}] }`, "");
  const uSizes = [[40000, 255], [40000, 300], [40000, 65536], [40000, 65537], [40000, 70000], [16777216, 16777216], [16777216, 16777217]];
  lines.push("# (special index, size, the RFC 6962 root of the uniform tree of that size).");
  lines.push("vec_uniform_roots : List((U64, U64, Str))");
  lines.push(`vec_uniform_roots = [${uSizes.map(([s, n]) => `(${s}, ${n}, "${hex(R(0, n, s))}")`).join(", ")}]`, "");
  lines.push("# --- end of vectors of slice 261b ---");
  console.log(lines.join("\n"));
} else if (mode === "cli") {
  const lines = [];
  lines.push("# --- vectors: generated by research/slice-261-vectors/vectors.mjs cli, do not edit ---", "");
  lines.push("# Test keys (fixed test seeds): the verifier text, the 32-byte public key and the key id in hex. A and A2 have the name of the built-in key; B and C do not.");
  lines.push("vec_keys : { a : { verifier : Str, public : Str, key_id : Str }, a2 : { verifier : Str, public : Str, key_id : Str }, b : { verifier : Str, public : Str, key_id : Str }, c : { verifier : Str, public : Str, key_id : Str } }");
  const kr = (k) => `{ verifier: "${k.verifier}", public: "${hex(k.pub)}", key_id: "${hex(k.id)}" }`;
  lines.push(`vec_keys = { a: ${kr(kA)}, a2: ${kr(kA2)}, b: ${kr(kB)}, c: ${kr(kC)} }`, "");
  lines.push("# Key texts that are not verifier keys: type byte 2, 31 and 33 key bytes, no type byte, a key that is not a point (y = 2), a name with a space (each with its matching key id);");
  lines.push("# the key of A with the key id of B.");
  lines.push(`vec_bad_keys : { ${Object.keys(badKeys).map((k) => `${k} : Str`).join(", ")} }`);
  lines.push(`vec_bad_keys = { ${Object.entries(badKeys).map(([k, v]) => `${k}: "${v}"`).join(", ")} }`, "");
  lines.push("# Signed notes of the body of size 7 (root 19f84e...): signed by A; with an extra line of B before or after; only B; signed by A2 (the name of A, another key id);");
  lines.push("# a signature of A with a changed bit; the size or the root changed after the signature; signed by C (origin is not the name of C); an extension line signed by A; no signature line.");
  lines.push(`vec_notes : { ${Object.keys(notes).map((k) => `${k} : Str`).join(", ")} }`);
  lines.push(`vec_notes = { ${Object.entries(notes).map(([k, v]) => `${k}: ${rocStr(v)}`).join(", ")} }`, "");
  lines.push(`vec_root7 : Str`, `vec_root7 = "${hex(ROOT7)}"`, "");
  lines.push("# --- end of vectors ---");
  console.log(lines.join("\n"));
} else {
  console.error("usage: node research/slice-261-vectors/vectors.mjs records|cli");
  process.exit(2);
}

// Self-check (runs each time): the uniform tree roots equal the plain RFC 6962 MTH of all leaves for small sizes.
{
  const mth = (hs) => (hs.length === 0 ? sha([]) : hs.length === 1 ? hs[0] : nodeHash(mth(hs.slice(0, split(hs.length))), mth(hs.slice(split(hs.length)))));
  for (const [s, n] of [[0, 1], [3, 7], [100, 300], [299, 300], [256, 513]]) {
    const hs = Array.from({ length: n }, (_, i) => leafHash(i === s ? X : E));
    if (hex(mth(hs)) !== hex(R(0, n, s))) throw new Error(`uniform self-check ${s} ${n}`);
  }
}

// Self-check: a reference reader in JS proves each listed case of the uniform tree with ONLY the tiles of proof_tiles or consistency_tiles
// (the tile bytes come from their definition), so the lists are enough. Rule: R-LV3 (the chain of full tiles ends in an edge tile; the edge gives the root).
{
  const mth = (hs) => (hs.length === 0 ? sha([]) : hs.length === 1 ? hs[0] : nodeHash(mth(hs.slice(0, split(hs.length))), mth(hs.slice(split(hs.length)))));
  const hashesOf = (t, s) => { const span = Number(P(t.level)); return Array.from({ length: t.width }, (_, j) => R((t.index * 256 + j) * span, span, s)); };
  const get = (tiles, t) => { if (!tiles.some((x) => pathOf(x) === pathOf(t))) throw new Error(`missing ${pathOf(t)}`); return t; };
  // The root of size n from its edge, and the prefix root of size a from the tiles of b.
  function peaksRoot(n, s, tiles, b = n) {
    const peaks = [];
    for (let L = 63; L >= 0; L--) {
      const c = Number(BigInt(n) / P(L)), w = c % 256;
      if (c === 0 || w === 0) continue;
      const t = get(tiles, tileAt(L, Math.floor(c / 256) * 256, b));
      const hs = hashesOf(t, s).slice(0, w);
      let pos = 0;
      for (let bit = 128; bit >= 1; bit /= 2) if (w & bit) { peaks.push(mth(hs.slice(pos, pos + bit))); pos += bit; }
    }
    if (peaks.length === 0) return sha([]);
    return peaks.slice(0, -1).reduceRight((acc, p) => nodeHash(p, acc), peaks[peaks.length - 1]);
  }
  function chainOk(t, n, s, tiles) {
    let cur = get(tiles, t);
    while (cur.width === 256) {
      const up = get(tiles, tileAt(cur.level + 1, cur.index, n));
      if (hex(mth(hashesOf(cur, s))) !== hex(hashesOf(up, s)[cur.index % 256])) return false;
      cur = up;
    }
    return true;
  }
  for (const [i, n, s] of [[40000, 65536, 40000], [0, 65537, 40000], [40000, 70000, 40000], [69999, 70000, 40000], [0, 16777217, 16777216], [16777216, 16777217, 16777216], [100, 511, 100], [256, 257, 256]]) {
    const tiles = proofTiles(i, n);
    const t0 = get(tiles, tileAt(0, i, n));
    if (hex(hashesOf(t0, s)[i % 256]) !== hex(leafHash(i === s ? X : E))) throw new Error(`leaf ${i} ${n}`);
    if (!chainOk(t0, n, s, tiles) || hex(peaksRoot(n, s, tiles)) !== hex(R(0, n, s))) throw new Error(`inclusion self-check ${i} ${n}`);
  }
  for (const [a, b, s] of [[255, 70000, 40000], [65536, 70000, 40000], [300, 65537, 40000], [16777216, 16777217, 16777216], [7, 257, 3], [256, 257, 3], [255, 511, 3]]) {
    const tiles = consistencyTiles(a, b);
    for (const t of edgeHashes(a)) if (!chainOk(tileAt(t.level, t.index * 256, b), b, s, tiles)) throw new Error(`consistency chain ${a} ${b}`);
    if (hex(peaksRoot(a, s, tiles, b)) !== hex(R(0, a, s)) || hex(peaksRoot(b, s, tiles)) !== hex(R(0, b, s))) throw new Error(`consistency self-check ${a} ${b}`);
  }
}
